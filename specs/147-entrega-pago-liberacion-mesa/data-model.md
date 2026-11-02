# Data Model: Ciclo de Vida Simplificado del Pedido y Control Manual de Mesas

No se crean entidades nuevas. Se reduce el conjunto de valores válidos de tres campos ya
existentes y se ajusta el criterio de una regla de negocio (liberación de mesa) que lee dos
de esos campos. Todo lo de abajo aplica sobre `pos-backend`, esquema `tenant` (una copia por
tenant, vía `@for_each_tenant_schema`).

## Pedido — `tenant.customer_orders` (modelo `CustomerOrder`)

| Campo | Antes | Después | Notas |
|---|---|---|---|
| `status` | `'pendiente' \| 'abierta' \| 'bloqueada' \| 'pagada' \| 'cancelada'` | `'pendiente' \| 'entregada' \| 'cancelada'` | `CheckConstraint ck_customer_order_status` reescrito (FR-021). |
| `payment_status` | `'UNPAID' \| 'PAID' \| 'PARTIAL'` | `'UNPAID' \| 'PAID'` | `CheckConstraint ck_customer_order_payment_status` reescrito. |
| `version` | — | sin cambio | ya no se usa para la transición de entrega (ver `research.md` R3); sigue vigente para lo que ya la use en cobro si aplica. |

**Transiciones válidas de `status`** (FR-021): `pendiente → entregada`, `pendiente →
cancelada`, `entregada → cancelada` (solo si `payment_status == 'UNPAID'` y con `motivo`
obligatorio vía `OrderCancelLog`, FR-007/FR-008/FR-009). Ninguna transición sale de
`cancelada` (FR-010).

**Independencia de ejes** (FR-003/FR-004): `payment_status` pasa de `UNPAID` a `PAID` en
cualquier `status` salvo `cancelada`, sin que ese cambio toque `status`; y viceversa, pasar
`status` a `entregada` nunca toca `payment_status`.

**Pedido cerrado** (FR-006): `status == 'entregada' AND payment_status == 'PAID'`. Es una
condición derivada, leída en varios sitios (liberación de mesa, filtro "entregadas sin
cobrar") — no es un tercer campo nuevo.

**Índice afectado**: `idx_active_order_per_participant`
(`customer_order.py:209-214`), hoy `postgresql_where=text("status NOT IN ('pagada',
'cancelada')")`, pasa a `postgresql_where=text("status = 'pendiente' OR (status = 'entregada'
AND payment_status = 'UNPAID')")` — el mismo criterio de "orden abierta" que FR-016 usa para
la liberación de mesa, en vez del `status != 'cancelada'` originalmente propuesto aquí.

**Corrección post-implementación (2026-11-01, decisión técnica)**: la primera redacción de
este documento proponía `status != 'cancelada'`, verificada durante `/speckit-implement` como
incompatible con datos reales — un participante con dos pedidos históricos ya
`'entregada'`+`'PAID'` (secuenciales, cada uno cobrado y cerrado antes de iniciar el
siguiente) viola esa unicidad porque ningún `'entregada'` queda nunca excluido. El criterio
corregido excluye un pedido `'entregada'`+`'PAID'` (cerrado, FR-006) de la cuenta de "activo",
permitiendo que el mismo participante abra un pedido nuevo después de que el anterior ya se
cobró — consistente con FR-016 y sin reabrir el conflicto de unicidad sobre datos existentes.
Decisión técnica (no de negocio): no cambia ningún comportamiento observable nuevo más allá de
lo que FR-016 ya define, solo corrige una inconsistencia entre dos lugares que debían usar el
mismo criterio de "abierta".

## Ítem de pedido — `tenant.order_items` (modelo `OrderItem`)

| Campo | Antes | Después | Notas |
|---|---|---|---|
| `estado_cocina` | `'pendiente' \| 'en_preparacion' \| 'listo' \| 'anulado'` | `'pendiente' \| 'entregado' \| 'cancelado'` | `CheckConstraint ck_order_item_estado_cocina` reescrito (FR-022). Se mantiene el nombre de columna `estado_cocina` (sin renombrar) — renombrarla sería una refactorización no exigida por el spec. |
| `EN_CURSO` (constante Python, `order_item.py:15`) | `("pendiente", "en_preparacion")` | `("pendiente",)` | único valor no terminal ahora. |

**Regla de dependencia** (FR-022): un ítem no tiene acción propia de cambio de estado; sigue
siempre el de su pedido, con la única excepción de un ítem agregado después de que el
pedido ya está `entregada` (FR-002a): nace `pendiente` y convive con ítems `entregado` del
mismo pedido hasta la siguiente acción "Entregar".

## Mesa — `tenant.dining_tables` (modelo `DiningTable`)

Sin cambios de esquema. `status` (`'libre' \| 'ocupada' \| 'reservada' \| 'pendiente_pago'`)
y su `CheckConstraint` no se tocan: el spec no introduce un estado de mesa nuevo, solo
cambia **cuándo** el sistema puede ponerla en `'libre'` (siempre manual, FR-015), lo que es
un cambio de regla de negocio en `table_sessions/service.py`, no de modelo de datos.

## Sesión de mesa — `tenant.table_sessions` (modelo `TableSession`)

Sin cambios de esquema. `opened_at` ya existe y es la base del indicador informativo de
tiempo ocupado (FR-019) — se expone en el response de la Terminal de Mesas, no se persiste
un campo derivado nuevo.

## Registro de cancelación — `tenant.order_cancel_logs` (modelo `OrderCancelLog`)

Sin cambios de esquema. Ya tiene `motivo: str` `NOT NULL` — FR-007/FR-008 (motivo
obligatorio al cancelar una orden `entregada`) se satisfacen reusando esta tabla tal cual,
sin ningún campo nuevo.

## Migración de datos (FR-023, SC-007)

Una sola migración Alembic nueva (ver `research.md` R1/R2 para el patrón y el orden exacto
de pasos), aplicada a cada esquema de tenant:

1. `customer_orders.status`: `'abierta' → 'pendiente'`; `'bloqueada' → 'entregada'`;
   `'pagada' → 'entregada'` (con `payment_status` ya en `'PAID'` desde la migración
   `e967f9848848` precedente — no se re-deriva aquí).
2. `customer_orders.payment_status`: `'PARTIAL' → 'UNPAID'`.
3. `order_items.estado_cocina`: `'en_preparacion' → 'pendiente'`; `'listo' → 'entregado'`;
   `'anulado' → 'cancelado'`.
4. Forzado final (FR-023 in fine): para toda orden cuyo `status` quedó `'entregada'`, todo
   ítem suyo cuyo `estado_cocina` no sea `'cancelado'` se fuerza a `'entregado'`; para toda
   orden cuyo `status` quedó `'cancelada'`, todo ítem suyo se fuerza a `'cancelado'`.
5. Recrear los tres `CHECK` con los conjuntos de valores finales.

**Rollback**: siguiendo el mismo criterio documentado en `e967f9848848` — el downgrade
revierte agregadamente (`'entregada' → 'bloqueada'`, etc.) sin poder distinguir
retroactivamente qué fila vino de dónde; aceptable solo como procedimiento de emergencia
inmediatamente posterior al despliegue, nunca como operación normal. El forzado del paso 4
no es reversible de forma exacta (se perdió la distinción entre un ítem que ya estaba
`entregado`/`cancelado` y uno que se forzó) — se documenta como limitación conocida, igual
que la limitación de `PARTIAL` ya aceptada en la migración precedente.

**Verificación post-migración** (SC-007): un `SELECT` de control sin filas esperado —
`SELECT count(*) FROM customer_orders WHERE status NOT IN ('pendiente','entregada',
'cancelada') OR payment_status NOT IN ('UNPAID','PAID')` y el equivalente para
`order_items.estado_cocina` — a incluir como parte de la verificación de
`/speckit-tasks`, no solo confiar en el `CHECK` constraint (que solo protege escritura
futura, no certifica el estado tras el propio `UPDATE` de la migración).
