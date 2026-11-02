# Data Model: Estado inicial PENDIENTE para órdenes e ítems, sin traducción en frontend

**Feature**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md) · **Research**: [research.md](./research.md)

## Entidad: `CustomerOrder` (orden)

Archivo: `app/models/customer_order.py` (pos-backend).

### Campos afectados

| Campo | Tipo actual | Cambio | Nota |
|---|---|---|---|
| `status` | `VARCHAR(12)`, `CHECK` en `('recibida','abierta','bloqueada','pagada','cancelada')` | El CHECK pasa a `('pendiente','abierta','bloqueada','pagada','cancelada')` — se quita `'recibida'`, se agrega `'pendiente'` | No cambia el tipo de columna ni su longitud (ambos valores tienen ≤12 caracteres) |
| `payment_status` | **No existe** | Columna nueva: `VARCHAR(10)`, `nullable=False`, `server_default='UNPAID'`, `CHECK` en `('UNPAID','PAID','PARTIAL')` | Nombre de constraint: `ck_customer_order_payment_status` |

### Valores y semántica de `status` (post-cambio)

- `pendiente` — estado inicial único para toda orden nueva, de cualquier canal. Reemplaza a
  `recibida`.
- `abierta` — orden confirmada, en curso (sin cambios de semántica).
- `bloqueada` — sin cambios de semántica.
- `pagada` — sin cambios de semántica.
- `cancelada` — sin cambios de semántica.

### Valores y semántica de `payment_status` (nuevo)

- `UNPAID` — valor por defecto al crear la orden; no hay pago confirmado en el acto de
  creación.
- `PAID` — el pago se confirmó por completo en el mismo acto de creación (p. ej. venta de
  mostrador pagada de inmediato).
- `PARTIAL` — el pago se confirmó parcialmente en el mismo acto de creación (pago
  mixto/parcial, edge case del spec).

`payment_status` es independiente de `status`: una orden puede estar en `status='pendiente'`
con `payment_status='PAID'` si el pago ya se confirmó aunque la orden aún no haya sido
atendida/confirmada operativamente.

### Validación / reglas de negocio

- Toda orden nueva: `status = 'pendiente'` siempre (FR-001), sin excepción por canal.
- Toda orden nueva: `payment_status = 'UNPAID'` salvo que el pago se confirme en el mismo acto
  de creación, en cuyo caso `payment_status` refleja `'PAID'` o `'PARTIAL'` según corresponda
  (FR-002).
- Ningún código de aplicación ni escritura directa puede persistir `status = 'recibida'`
  después de la migración — rechazado por el `CHECK constraint` en cada esquema (FR-007).

### Transiciones de estado afectadas

- `pendiente → abierta`: la transición que hoy ejecuta `confirm_order`/`checkout_and_send`
  para `recibida → abierta` (QR) se generaliza para todo canal, incluyendo caja/domicilio
  (que hoy no pasan por esta transición porque nacen directamente en `abierta`).
- El descuento de inventario que hoy ocurre en la creación de caja/domicilio (porque nacen en
  `abierta`) debe moverse al punto de esta transición, igual que ya ocurre para QR — ver
  research.md sección 4 para el impacto a registrar en `registro-de-anomalias.md`.

## Entidad: `OrderItem` (ítem de orden)

Archivo: `app/models/order_item.py` (pos-backend).

**Sin cambios de modelo.** `estado_cocina` ya nace en `'pendiente'` por defecto
(`app/models/order_item.py:72-74`) para todo ítem nuevo; FR-003 ya se cumple. Se añade
únicamente un characterization test que fije explícitamente este comportamiento (ver
research.md sección 2 y 8).

## Entidad: Catálogo de estados (backend, autoritativo)

No es una tabla nueva — es el conjunto de valores válidos definido por el enum Python
`OrderStatus` (`app/api/v1/orders/schemas.py:34-41`, se renombra el miembro `RECIBIDA` a
`PENDIENTE` con valor `"pendiente"`) y por el `CHECK constraint` correspondiente en cada
esquema. Es la única fuente autoritativa (FR-010); no se expone como endpoint de catálogo
dinámico.

## Entidad: Catálogo de estados conocidos (frontend, espejo estático)

No es un modelo de datos — es una constante de código
(`KNOWN_ORDER_STATUSES`/`KNOWN_KITCHEN_STATUSES` en `order-status.util.ts`) que refleja
manualmente el catálogo autoritativo del backend, usada solo para detectar y loguear (consola)
valores no reconocidos (FR-009/FR-010). No sustituye ningún valor por una etiqueta "por
defecto".

## Migración de datos (Alembic, multi-tenant)

Archivo nuevo: `alembic/versions/<revision>_rename_recibida_to_pendiente_add_payment_status.py`

**Patrón**: decorar `upgrade(schema: str)`/`downgrade(schema: str)` con
`@for_each_tenant_schema` (`app/scripts/tenant.py:9-19`), igual que
`c9d0e1f2a3b4_table_sessions_participants.py`.

### `upgrade(schema)` — por cada esquema (`tenant_default` + cada tenant de `shared.tenants`)

1. `ALTER TABLE {schema}.customer_order DROP CONSTRAINT ck_customer_order_status`
2. `UPDATE {schema}.customer_order SET status = 'pendiente' WHERE status = 'recibida'`
3. `ALTER TABLE {schema}.customer_order ADD CONSTRAINT ck_customer_order_status CHECK (status IN ('pendiente','abierta','bloqueada','pagada','cancelada'))`
4. `ALTER TABLE {schema}.customer_order ADD COLUMN payment_status VARCHAR(10) NOT NULL DEFAULT 'UNPAID'`
5. `UPDATE {schema}.customer_order SET payment_status = 'PAID' WHERE status = 'pagada'`
6. `ALTER TABLE {schema}.customer_order ADD CONSTRAINT ck_customer_order_payment_status CHECK (payment_status IN ('UNPAID','PAID','PARTIAL'))`

### `downgrade(schema)` — espejo, por cada esquema

1. `ALTER TABLE {schema}.customer_order DROP CONSTRAINT ck_customer_order_payment_status`
2. `ALTER TABLE {schema}.customer_order DROP COLUMN payment_status`
3. `ALTER TABLE {schema}.customer_order DROP CONSTRAINT ck_customer_order_status`
4. `UPDATE {schema}.customer_order SET status = 'recibida' WHERE status = 'pendiente'`
5. `ALTER TABLE {schema}.customer_order ADD CONSTRAINT ck_customer_order_status CHECK (status IN ('recibida','abierta','bloqueada','pagada','cancelada'))`

**Limitación de rollback documentada** (Principio VIII exige declararla, no evitarla): el paso
4 del downgrade revierte *todas* las filas en `'pendiente'` a `'recibida'`, incluidas las
creadas después del upgrade que nunca fueron `'recibida'` originalmente (p. ej. nuevas órdenes
de caja/domicilio creadas ya bajo el comportamiento nuevo). No existe manera de distinguir
retroactivamente el origen de una fila en `'pendiente'`. Esto es aceptable porque un rollback de
esta migración solo tiene sentido como procedimiento de emergencia inmediatamente después del
despliegue, no como operación rutinaria sobre datos ya operados bajo el nuevo esquema.

### Riesgo de bloqueo (`ALTER TABLE ... ADD COLUMN ... NOT NULL DEFAULT`)

En PostgreSQL 11+ (el proyecto usa PostgreSQL 16), `ADD COLUMN ... NOT NULL DEFAULT <literal>`
no reescribe la tabla ni toma un lock exclusivo prolongado — es seguro de ejecutar dentro de la
migración estándar sin pasos adicionales de "añadir nullable, backfill, luego poner NOT NULL".

## Resumen de impacto en Key Entities del spec

- **Orden**: gana `payment_status`; `status` cambia su valor inicial posible de `recibida` a
  `pendiente`.
- **Ítem de orden**: sin cambios de modelo (ya cumplía el requisito).
- **Tenant / esquema**: la migración recorre `tenant_default` + todos los esquemas listados en
  `shared.tenants` (ver research.md sección 5 sobre la ausencia de un esquema `public` de
  negocio en este proyecto).
