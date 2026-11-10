# Data Model: Cobro independiente de pedidos por mesa

No se introducen entidades ni campos nuevos. Esta feature reutiliza el modelo de
datos existente (ya descrito en detalle en `specs/147-entrega-pago-liberacion-mesa/data-model.md`);
este documento solo señala los campos existentes de los que depende el nuevo
comportamiento.

## Entidades existentes relevantes

### `TableSession` (tabla `table_sessions`) — "Mesa" (sesión activa)
- `id`, `dining_table_id` (FK a `DiningTable`), `status` (`'active'|'closed'`),
  `billing_mode` (`'unified'|'split'`, se fija al cobrar/cerrar).
- Sin cambios. El estado de la sesión no distingue cobro parcial vs. total: eso se
  deriva de `CustomerOrder.payment_status` de sus pedidos, no de un campo propio.

### `CustomerOrder` (tabla `customer_orders`) — "Pedido"
- `table_session_id` (FK), `dining_table_id` (FK), `participant_id` (FK).
- `status` (`'pendiente'|'confirmado'|'entregada'|'cancelada'`): ciclo de vida
  operativo (cocina/entrega). **No cambia** con esta feature.
- `payment_status` (`'UNPAID'|'PAID'`): **ya existe y ya es independiente de
  `status`** — es el campo que esta feature lee/escribe de forma selectiva (por
  pedido) en lugar de siempre sobre el conjunto completo de pedidos facturables de
  la sesión.
- `table_order_number`: número visible ("Pedido 41", "Pedido 42") usado para que el
  cajero identifique qué pedido seleccionar. Sin cambios.
- `merged_group_id`, `version`: sin cambios; `version` sigue siendo el lock
  optimista que ya protege contra cobros concurrentes del mismo pedido.

### `Sale` (tabla `sales`) — "Cobro/Transacción de pago"
- `customer_order_id` (FK nullable): ya soporta tanto una venta atada a un solo
  pedido (cobro individual) como una venta sin pedido único (`NULL`, cobro conjunto
  de varios pedidos en una sola `Sale`, modo `unified` actual). Sin cambios de
  esquema: el cobro individual de un pedido ya es representable hoy con
  `customer_order_id` apuntando a ese pedido.
- `table_session_id`, `dining_table_id`, `participant_id`: sin cambios.

### `DiningTable` (tabla `dining_tables`) — "Mesa" (física)
- `status` (`'libre'|'ocupada'|'reservada'|'pendiente_pago'`): sin cambios; sigue
  sin tocarse por `charge_session`, y solo `release_paid_session` la pone en
  `'libre'` (Principio ya vigente desde spec 147, reutilizado sin modificación por
  FR-005/FR-006 de esta feature).

## Relaciones y reglas de negocio (sin cambios de esquema)

- Una `TableSession` agrupa 1..N `CustomerOrder`.
- Cada `CustomerOrder` tiene su propio `payment_status`, consultado individualmente
  por `_billable_orders` para decidir qué entra en una operación de cobro.
- Una operación de cobro (`_charge_session`) puede ahora operar sobre un
  subconjunto explícito de los `CustomerOrder` facturables de la sesión (en vez de
  siempre el conjunto completo), produciendo 1 o más `Sale` igual que hoy
  (`_close_unified` → 1 `Sale`; `_close_split` → 1 `Sale` por comensal), y marcando
  `payment_status='PAID'` solo en los pedidos efectivamente cobrados.
- La liberación de la mesa (`release_paid_session`) sigue validando el 100% de los
  pedidos de la sesión (no solo el subconjunto cobrado en la última transacción),
  por lo que un cobro parcial nunca libera la mesa — esto ya es el comportamiento
  actual, sin cambios.

## Validaciones nuevas (a nivel de servicio, no de esquema)

- Al recibir una lista explícita de `order_ids` para cobrar o para previsualizar
  (`compute_bill`), cada id debe:
  1. Pertenecer a la `table_session_id` indicada.
  2. Estar actualmente en `_billable_orders` (no cancelado, no `PAID`, sin `Sale`
     ya emitida).
  - Si alguno falla, `409 Conflict` con el detalle de qué ids son inválidos (mismo
    patrón que usa hoy `release_paid_session` para listar pedidos pendientes).
