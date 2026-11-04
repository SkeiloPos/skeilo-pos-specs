# Fase 1 — Data Model: Envío de pedido confirmado y pagado a cocina

Ver decisiones técnicas en [research.md](./research.md), en particular las Decisiones 0-2 (qué
significa "confirmada", por qué son columnas nuevas y por qué sin `CheckConstraint`) y la
Decisión 8 (índice de la cola). Todo lo de abajo aplica sobre `pos-backend`, esquema `tenant` (una
copia por tenant, vía `@for_each_tenant_schema`), salvo donde se indique lo contrario.

## Pedido — `tenant.customer_orders` (modelo `CustomerOrder`, modificado)

| Campo | Tipo | Notas |
|---|---|---|
| **`kitchen_status`** | `String`, nullable, sin `server_default` (nace `NULL`) | Nueva. `NULL` = nunca enviado a cocina; cualquier valor no nulo = ya enviado (research.md Decisión 2). Esta spec solo escribe el literal `"SIN_PREPARAR"` al enviar — no hay más transiciones de esta columna en esta spec. **Sin `CheckConstraint`** a propósito (clarificación 4 de `spec.md`): un valor futuro no nulo distinto de `"SIN_PREPARAR"` debe seguir leyéndose como "ya enviado" sin romper nada aquí. |
| **`sent_to_kitchen_at`** | `DateTime` (sin zona, UTC naive — mismo patrón que el resto de timestamps de servidor del proyecto, ej. `app.core.timezone.utc_now_naive`), nullable, sin `server_default` | Nueva. `NULL` hasta el primer envío exitoso; una vez fijado, ninguna operación de esta spec lo vuelve a escribir (FR-007: un segundo intento se rechaza antes de llegar a esta asignación). |

**Campos existentes relevantes, sin cambio de esquema** (ya presentes, solo leídos por esta spec):

- `status` (`'pendiente' | 'confirmado' | 'entregada' | 'cancelada'`) — la condición de
  elegibilidad usa `status != 'cancelada'` (research.md Decisión 0), nunca compara contra
  `'confirmado'` como único valor válido.
- `payment_status` (`'UNPAID' | 'PAID'`) — elegibilidad exige `'PAID'` exactamente (FR-001/FR-006).
- `channel` / `order_type` — no se leen en la lógica de elegibilidad (research.md Decisión 7); se
  siguen devolviendo en `OrderResponse` sin cambios.

**Transición nueva de `kitchen_status`** (FR-003/FR-007/FR-008):

```
NULL ──(send_to_kitchen exitoso)──► "SIN_PREPARAR"
 │                                        │
 └── cualquier reintento posterior ───────┘
     (rechazado con 409 ALREADY_IN_KITCHEN,
      no vuelve a escribir sent_to_kitchen_at)
```

No existe transición de salida de `"SIN_PREPARAR"` en esta spec (ninguna reversión — ver
"Assumptions" de `spec.md`).

**Validación de la acción `send_to_kitchen`** (orden determinístico, research.md Decisión 6):

1. Pedido no existe → 404.
2. `status == 'cancelada'` → 409 `ORDER_NOT_CONFIRMED`.
3. `kitchen_status IS NOT NULL` → 409 `ALREADY_IN_KITCHEN`.
4. `payment_status != 'PAID'` → 409 `ORDER_NOT_PAID`.
5. Éxito → `kitchen_status = 'SIN_PREPARAR'`, `sent_to_kitchen_at = utc_now_naive()`.

El `SELECT ... FOR UPDATE` sobre la fila (mismo patrón que `receive_order`/`deliver_order`)
serializa dos invocaciones casi simultáneas: la segunda, al tomar el lock después del commit de
la primera, ve `kitchen_status IS NOT NULL` y cae en el paso 3 (FR-008/SC-003).

## Cola de preparación (sin tabla ni entidad propia)

Secuencia calculada bajo demanda: `SELECT ... FROM customer_orders WHERE kitchen_status IS NOT
NULL ORDER BY sent_to_kitchen_at ASC`. No se persiste ninguna posición (research.md Decisión 8,
clarificación 1 de `spec.md`). Esta spec no define ningún endpoint que exponga esta consulta — el
consumo de la cola (tablero de cocina) queda fuera de alcance (ver "Assumptions" de `spec.md`);
esta sección documenta únicamente el criterio de orden para que una spec futura lo reutilice sin
reinterpretar `sent_to_kitchen_at`.

**Índice nuevo** (research.md Decisión 8, optimización, no requisito funcional):

```python
Index(
    "idx_customer_orders_kitchen_queue",
    "sent_to_kitchen_at",
    postgresql_where=text("kitchen_status IS NOT NULL"),
)
```

Mismo patrón de índice parcial que `idx_active_order_per_participant` ya existente en el mismo
modelo.

## Esquema de respuesta — `OrderResponse` (`app/api/v1/orders/schemas.py`, modificado)

Gana dos campos, mismo patrón mecánico que cualquier otro campo ya expuesto de `CustomerOrder`:

| Campo | Tipo | Notas |
|---|---|---|
| `kitchen_status` | `Optional[str]` | `None` si nunca se envió. |
| `sent_to_kitchen_at` | `Optional[datetime]` | `None` si nunca se envió; serializado ISO 8601 por FastAPI/Pydantic, igual que cualquier otro `datetime` de este esquema. |

## Interfaz TypeScript — `DiningOrder` (frontend, modificada)

```ts
interface DiningOrder {
  // ...campos existentes...
  kitchen_status: string | null;
  sent_to_kitchen_at: string | null; // ISO 8601
}
```

## Evento de dominio — `events.order_sent_to_kitchen` (nuevo, `app/core/events.py`)

Mismo molde que `order_delivered` (research.md Decisión 6): publicado post-commit a
`CH_STAFF` + el canal de la sesión de mesa (si aplica), payload
`{"order_id", "table_session_id", "kitchen_status": "SIN_PREPARAR"}`. No lleva identidad del
usuario que ejecutó el envío (clarificación 5 de `spec.md`: no se registra autoría).

## Migración de datos (Alembic)

Una sola migración nueva, encadenada sobre el head actual, aplicada a cada esquema de tenant vía
`@for_each_tenant_schema` (mismo patrón que `c5d6e7f8a9b0_simplify_kitchen_status.py`):

1. **Agregar columnas**: `tenant.customer_orders.kitchen_status` (`String`, nullable, sin
   default) y `tenant.customer_orders.sent_to_kitchen_at` (`DateTime`, nullable, sin default).
   Todo pedido existente (de cualquier tenant) queda con ambas columnas en `NULL` — ningún dato
   histórico se reinterpreta ni se backfillea (ningún pedido ya entregado/cobrado "nace" enviado a
   cocina retroactivamente).
2. **Agregar índice parcial** `idx_customer_orders_kitchen_queue` (ver arriba).
3. **Verificación** (quickstart.md): tras el `upgrade`, todo pedido existente tiene
   `kitchen_status IS NULL` — ningún tenant ve un pedido histórico aparecer "ya en cocina" sin
   haber ejecutado la acción nueva (Principio II: no hay comportamiento de cocina en producción
   que esta migración esté alterando, igual que spec 149 Decisión 0).
4. **Rollback**: `downgrade()` ejecuta `op.drop_index(...)` seguido de
   `op.drop_column("customer_orders", "sent_to_kitchen_at", schema=schema)` y
   `op.drop_column("customer_orders", "kitchen_status", schema=schema)` — pérdida de dato
   aceptable como procedimiento de emergencia inmediatamente posterior al despliegue (mismo
   criterio ya aceptado en migraciones previas de este repositorio, ej. spec 149 Decisión 4);
   ningún pedido enviado a cocina deja de poder entregarse/cobrarse si se revierte (esas dos
   columnas no son leídas por ningún otro flujo).

## Relaciones

Sin cambios — `kitchen_status`/`sent_to_kitchen_at` son dos columnas más de
`tenant.customer_orders`, sin relación/FK nueva, sin tabla nueva.
