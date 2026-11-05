# Data Model: Tablero de cocina en tres columnas con movimiento de pedidos

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**:
[research.md](./research.md)

## Resumen de cambios de esquema

| Repositorio | Cambio | Tipo |
|---|---|---|
| `pos-backend` | Fila `KITCHEN` en `shared.roles` | Migración de datos (sin DDL) |
| `pos-backend` | Ninguna columna/índice nuevo sobre `tenant.customer_orders` | — |

Ninguna tabla nueva. Ninguna columna nueva. El único cambio de datos es sembrar el rol
`KITCHEN`, igual que spec 075 sembró `MESERO`.

## Entidades

### Rol `KITCHEN` (`shared.roles`)

Fila nueva en el catálogo de roles compartido entre tenants (`shared.roles`, ya existente,
`id UUID`, `name TEXT UNIQUE`, `active BOOLEAN`, `created_at`). Sembrada por migración de
datos (research.md Decisión 1), idéntica en forma a la migración `8421e9a2b45a` de `MESERO`:
idempotente por `name`, `downgrade()` borra la fila solo si ningún `User`/`UserInvitation` la
referencia todavía.

Además, `app/core/db.py::ROLE_NAMES` gana `"KITCHEN"` para que una base de datos *nueva* (nunca
inicializada) la siembre directamente sin necesitar la migración — mismo patrón que `MESERO`
en esa misma tupla.

### `CustomerOrder` (sin cambios de esquema, campos reutilizados)

Campos ya existentes que este tablero consume, sin agregar ninguno:

| Campo | Tipo | Origen | Uso en esta spec |
|---|---|---|---|
| `kitchen_status` | `String`, nullable, sin `CheckConstraint` | spec 150 | Columna del tablero (`NULL` = no visible). Valores válidos a nivel de API (Pydantic `Literal`, no DB): `SIN_PREPARAR`, `EN_PROGRESO`, `LISTO`. |
| `sent_to_kitchen_at` | `DateTime`, nullable | spec 150 | Criterio de orden FIFO (FR-003), ascendente. |
| `version` | `Integer`, `server_default="0"` | preexistente | Detección de conflicto de concurrencia (FR-008): se incrementa en cada transición de `kitchen_status` exitosa (research.md Decisión 3b). |
| `status` | `String` | preexistente | `cancelada`/`entregada` excluyen la orden del tablero (FR-011, research.md Decisión 6). |
| `payment_status` | `String` | preexistente | Debe ser `PAID` para aceptar una transición (FR-006/FR-007). |
| `order_type` | `String`, nullable, `DINE_IN`/`TAKEAWAY`/`DELIVERY` | preexistente | Origen de la tarjeta (FR-012): `DINE_IN`→"mesa", `TAKEAWAY`→"caja", `DELIVERY`→"domicilio". |
| `dining_table_id` / `customer_name` / `delivery_address` | — | preexistente | Mesa o cliente a mostrar en la tarjeta (FR-012), según `order_type`. |
| `notes` | `String`, nullable | preexistente | Notas del pedido (FR-012). |
| `items` (relación a `OrderItem`) | — | preexistente | Productos, cantidades y adiciones (FR-012), vía `OrderItemResponse` ya serializado por `_load_order`. |

No se requiere ninguna migración DDL sobre `customer_orders` — spec 150 ya cubrió columnas e
índice parcial (`idx_customer_orders_kitchen_queue`, `WHERE kitchen_status IS NOT NULL`), y esta
spec reutiliza exactamente esa condición (research.md Decisión 5).

## Reglas de transición de `kitchen_status` (FR-005/FR-006/FR-007/FR-008)

```text
Estado previo requerido: kitchen_status IS NOT NULL (si es NULL → 409 NOT_IN_KITCHEN)

Transición aceptada SOLO SI, simultáneamente:
  - version recibido == order.version vigente        (si no → 409 KITCHEN_STATUS_CONFLICT)
  - payment_status == 'PAID'                          (si no → 409 PAYMENT_NOT_PAID)
  - status NOT IN ('cancelada', 'entregada')          (si no → 409, FR-006)
  - módulo de plan "cocina" activo para el tenant      (si no → 409, FR-006, require_module_access)

Destinos permitidos: cualquiera de {SIN_PREPARAR, EN_PROGRESO, LISTO}, incluyendo retrocesos
(FR-005) — no hay máquina de estados direccional, cualquier valor del conjunto es válido
mientras las condiciones de arriba se cumplan.

Efecto en éxito:
  kitchen_status = nuevo_valor
  version += 1
  (sent_to_kitchen_at NO cambia — FR-002: la tarjeta se reubica en su nueva columna según el
   sent_to_kitchen_at YA existente, no según el momento del movimiento)
```

## Vista del tablero (agregación de lectura, FR-001/FR-002/FR-003/FR-011)

```sql
-- Equivalente conceptual (implementado como 1 SELECT + agrupación en Python,
-- no 3 queries):
SELECT *
FROM tenant.customer_orders
WHERE kitchen_status IS NOT NULL
  AND status NOT IN ('cancelada', 'entregada')
ORDER BY sent_to_kitchen_at ASC, id ASC;
-- luego se agrupa en memoria por kitchen_status en las tres columnas de respuesta.
```

Usa `idx_customer_orders_kitchen_queue` (spec 150) para el filtro parcial; el `ORDER BY`
adicional (`id` como desempate) no requiere índice nuevo dado el volumen bajo esperado de
pedidos activos en cocina simultáneamente (research.md spec 150).

## Evento realtime nuevo (FR-015, research.md Decisión 0)

`events.order_kitchen_status_changed(tenant_id, *, order_id, table_session_id, kitchen_status,
version)` — mismo molde que `events.order_sent_to_kitchen`, publicado en el canal `CH_STAFF` ya
existente (igual visibilidad que cualquier otro evento de staff: todo el tenant, sin
segmentación adicional). Tipo de evento: `"order.kitchen_status_changed"`.

Eventos ya existentes reutilizados sin cambios para el retiro de tarjetas (FR-011, research.md
Decisión 6):
- `order.cancelled` (`events.order_cancelled`, ya emitido al cancelar una orden).
- `order.delivered` (`events.order_delivered`, ya emitido al entregar una orden — "estado final
  del flujo actual" según Assumptions de `spec.md`).

El frontend del tablero escucha los tres tipos (`order.kitchen_status_changed`,
`order.cancelled`, `order.delivered`) sobre la misma suscripción SSE que ya consumen
`ADMIN`/`CASHIER` desde `pos-terminal.store.ts`.

## Estrategia de migración y rollback

- **Upgrade**: `INSERT` idempotente de la fila `KITCHEN` en `shared.roles` (no toca
  `ROLE_NAMES` en producción — esa tupla solo siembra en una DB nueva). Sin backfill sobre
  `customer_orders` (ninguna columna nueva).
- **Downgrade**: `DELETE` de la fila `KITCHEN` solo si ningún `User`/`UserInvitation` la
  referencia (mismo guard que `MESERO`, evita `role_id` huérfano en `shared.users`).
- **Riesgo**: nulo sobre datos existentes — ningún pedido histórico cambia de valor en
  ninguna columna; el rol nuevo no se asigna a ningún usuario existente automáticamente (un
  admin de tenant debe asignarlo explícitamente vía `PATCH /users/{id}/role` reutilizando el
  endpoint ya existente, ahora con `KITCHEN` como valor aceptado en `RoleName`).
