# Research: Ciclo de Vida Simplificado del Pedido y Control Manual de Mesas

El spec no dejó ningún `NEEDS CLARIFICATION` (todas las ambigüedades se resolvieron en la
sesión de clarificaciones del 2026-11-01). Las entradas de abajo documentan decisiones
*técnicas* necesarias para implementar lo ya decidido, apoyadas en patrones existentes del
código, no en nueva clarificación de negocio.

## R1 — Migración de datos: reutilizar el patrón de la migración precedente (spec 146)

- **Decision**: la migración Alembic de este spec sigue el mismo patrón que
  `alembic/versions/e967f9848848_rename_recibida_to_pendiente_add_payment_status.py`:
  decorador `@for_each_tenant_schema`, `_has_table` como guardia, `op.drop_constraint(...,
  type_="check", schema=schema)` con el **nombre completo** del constraint antes de
  reescribirlo, `op.execute(text(f'UPDATE "{schema}"....'))` para los `UPDATE` de datos (sin
  `:param::cast` dentro de `text()` — ver memoria de sesión "Alembic constraint naming
  gotcha"), y `op.create_check_constraint(...)` (que antepone el prefijo automáticamente,
  así que el nombre pasado ahí NO debe incluir el esquema) para recrear el CHECK.
- **Rationale**: es el precedente más reciente sobre la misma tabla (`customer_orders`) y el
  mismo tipo de cambio (reescribir valores de un `CHECK` de estado); reutilizar la forma
  exacta minimiza sorpresas de la trampa de Alembic ya documentada en memoria de sesión.
- **Alternatives considered**: migrar a un `sa.Enum` nativo de Postgres en vez de
  `String` + `CHECK` — rechazado porque ninguna de las columnas afectadas (`status`,
  `payment_status`, `estado_cocina`, `dining_tables.status`) usa hoy un tipo `ENUM` nativo
  (todas son `String(N)` + `CheckConstraint`); introducir un tipo nuevo sería una
  refactorización no pedida por el spec (Principio V) y complicaría innecesariamente el
  rollback.

## R2 — Orden exacto de los pasos dentro de una misma migración

- **Decision**: por cada esquema de tenant, en este orden: (1) drop de los tres CHECK
  afectados (`ck_customer_order_status`, `ck_customer_order_payment_status`,
  `ck_order_item_estado_cocina`); (2) `UPDATE` de `customer_orders.status` aplicando primero
  el mapeo de FR-023 (`abierta`→`pendiente`, `bloqueada`→`entregada`, `pagada`→`entregada`);
  (3) `UPDATE` de `customer_orders.payment_status` (`PARTIAL`→`UNPAID`; toda fila que venía
  de `pagada` ya se marcó `PAID` por la migración `e967f9848848` previa, eso no cambia); (4)
  `UPDATE` de `order_items.estado_cocina` aplicando el mapeo ítem (`en_preparacion`→
  `pendiente`, `listo`→`entregado`, `anulado`→`cancelado`); (5) el `UPDATE` de **forzado**
  que exige FR-023 in fine: para cada pedido ya migrado a `entregada`, forzar todos sus
  ítems no `cancelado` a `entregado`; para cada pedido migrado a `cancelada`, forzar todos
  sus ítems a `cancelado`; (6) recrear los tres CHECK con los nuevos conjuntos de valores.
- **Rationale**: el forzado (paso 5) tiene que ocurrir **después** de que el pedido ya tenga
  su estado final (paso 2) y después del mapeo ítem por ítem (paso 4), porque su regla es
  "el estado final del pedido prevalece sobre el mapeo individual del ítem" — aplicarlo antes
  no tendría aún el valor final del pedido contra el que comparar.
- **Alternatives considered**: hacer el forzado en Python iterando filas en vez de un
  `UPDATE` masivo en SQL — rechazado por volumen (podría haber miles de pedidos por tenant)
  y porque el patrón ya existente (`e967f9848848`) resuelve todo en SQL puro dentro de la
  misma transacción de la migración.

## R3 — Entrega como acción idempotente por pedido (FR-001, FR-011, SC-006)

- **Decision**: la nueva acción "Entregar" es un `POST /orders/{order_id}/deliver` (nombre
  a confirmar en `/speckit-tasks`) que, dentro de una transacción con
  `SELECT ... FOR UPDATE` sobre la fila de `CustomerOrder` (mismo patrón que
  `app/api/v1/orders/checkout.py:155` y `:677`), hace: si `status == 'cancelada'` → rechaza
  (409, transición inválida, FR-010); si `status == 'entregada'` → no es un error: promueve
  igual cualquier ítem `pendiente` a `entregado` (soporta FR-002a, re-entrega tras agregar
  ítems nuevos) y responde éxito sin emitir un segundo evento si no hubo ítems que cambiar;
  si `status == 'pendiente'` → pasa la orden a `entregada` y todos sus ítems `pendiente` a
  `entregado`, en la misma transacción.
- **Rationale**: el lock de fila ya es el mecanismo que usa el código existente para
  serializar transiciones concurrentes sobre la misma orden (ver `checkout.py`); no hace
  falta inventar un mecanismo nuevo de idempotencia. Tratar "entregar una orden ya
  entregada" como éxito (no 409) es lo que exige el Acceptance Scenario 3 de la Historia 1 y
  FR-002a a la vez: ambos casos conviven en la misma rama del código ("ya está entregada,
  ¿hay ítems pendientes que promover?").
- **Alternatives considered**: columna `version` optimista (ya existe en `CustomerOrder`,
  usada para la transición `abierta→bloqueada` del cobro) — rechazada aquí porque un 409 por
  conflicto de versión en un doble clic violaría FR-011 ("ambas peticiones terminan en
  éxito"); el lock pesimista (`FOR UPDATE`) sí permite que la segunda petición espere y
  luego progrese sin error.

## R4 — Retirar la acción por ítem (FR-002)

- **Decision**: se retira el endpoint `POST /orders/items/{item_id}/kitchen`
  (`app/api/v1/orders/router.py:384`, `app/api/v1/orders/kitchen.py:transition_kitchen`) y su
  tabla de transiciones `_ALLOWED`. El resto de `kitchen.py` que no es la transición manual
  por ítem (p. ej. `accept_order_for_kitchen`/`mark_order_ready`, si se usan para otra cosa
  que la cocina ítem-por-ítem) se revisa en `/speckit-tasks` para decidir si sobrevive como
  parte interna de la nueva acción de pedido completo o se retira también.
- **Rationale**: FR-002 es explícito — "MUST NOT ofrecer ninguna acción para marcar ítems
  individuales". Dejar el endpoint vivo (aunque la UI no lo llame) deja una puerta trasera
  que contradice el requisito.
- **Alternatives considered**: dejar el endpoint pero deshabilitarlo solo en el frontend —
  rechazado: el requisito es del sistema, no solo de la interfaz, y un endpoint vivo sin uso
  es superficie de ataque/inconsistencia sin beneficio.

## R5 — Liberación manual de mesa: extender `release_paid_session`, no crear un endpoint nuevo

- **Decision**: `app/api/v1/table_sessions/service.py:release_paid_session` (expuesto en
  `router.py:152` como `POST .../release`, spec 028) ya es la acción manual de "Liberar
  mesa"; se adapta su condición de rechazo de `has_billable_orders`/`has_pending_balance`
  (criterio actual: "¿queda algo por facturar?") al nuevo criterio de FR-016: "¿existe alguna
  orden de la sesión en `pendiente`, o en `entregada` con `payment_status='UNPAID'`?". Si
  existe alguna, se rechaza devolviendo la lista de esas órdenes abiertas (FR-017, SC-004) en
  vez del mensaje genérico actual.
- **Rationale**: ya existe el endpoint, ya está enganchado a la UI de liberar mesa, y ya
  tiene el lock (`_load(..., lock=True)`) sobre `TableSession`; cambiar su criterio de cierre
  es un cambio acotado (Principio V) en vez de duplicar la función con otro nombre.
- **Alternatives considered**: mantener `release_paid_session` intacto y agregar un segundo
  endpoint nuevo — rechazado porque dejaría dos caminos para "liberar la mesa" con criterios
  distintos, confuso para el frontend y violando evolución incremental limpia (Principio VI).

## R6 — `try_release_if_empty` (barrido por TTL) no es el mecanismo que FR-015 prohíbe

- **Decision**: el barrido existente de sesiones huérfanas
  (`app/scripts/sweep_sessions.py` + `app/core/scheduler.py`, controlado por
  `EMPTY_SESSION_TTL_MINUTES`) permanece **sin cambios**. Solo libera una mesa cuando **no
  queda ningún comensal activo** (`SessionParticipant.status == 'open'`) **y** no hay nada
  billable — es decir, ya exige ausencia de ocupación real, no solo transcurso de tiempo
  sobre una mesa con gente. FR-015/Historia 3 hablan de una mesa *ocupada* que el cajero debe
  liberar a propósito; el barrido cubre el caso distinto de una sesión abandonada (el
  comensal se fue sin que nadie la cerrase), que ningún Acceptance Scenario de este spec
  menciona.
- **Rationale**: la sección "Assumptions" del spec dice explícitamente que, más allá de
  validar ausencia de órdenes abiertas y mostrar tiempo de ocupación, "no se introducen
  otros cambios al flujo general de apertura o gestión de sesiones de mesa" — el barrido de
  huérfanas es justamente ese flujo general, no la liberación manual que este spec rediseña.
- **Alternatives considered**: tratar el barrido como una violación de FR-015 y
  desactivarlo — rechazado: rompería un comportamiento ya protegido (Principio II) sin
  decisión de negocio que lo autorice, y el propio spec (Assumptions) indica lo contrario.
  Si el negocio quisiera eliminar también el barrido de huérfanas, eso requeriría su propia
  decisión registrada en `registro-de-anomalias.md`, fuera del alcance aprobado aquí.

## R7 — Puntos de lectura del estado de orden/ítem a inventariar antes de implementar

- **Decision**: antes de tocar el modelo de estados, `/speckit-tasks` debe listar (no
  resolver aquí) cada lugar que hoy lee `CustomerOrder.status`/`payment_status` o
  `OrderItem.estado_cocina` fuera de los archivos ya identificados en este plan — al menos:
  `_NON_TERMINAL_ORDER_STATUSES` y `ESTADOS_MOSTRADOS_ORDENES` (`orders/service.py:72,504`),
  `has_billable_orders`/`has_pending_balance` (`table_sessions/service.py`), el índice
  parcial `idx_active_order_per_participant` (`customer_order.py:209`, predicado
  `status NOT IN ('pagada','cancelada')` — debe pasar a `status != 'cancelada'`, ya que
  "pagada" deja de existir), y los filtros de reportes de caja que hoy agrupan por
  `payment_status IN ('UNPAID','PAID','PARTIAL')`.
- **Rationale**: el CHECK constraint solo impide valores inválidos en escritura; una
  condición SQL o Python que siga comparando contra `'pagada'`/`'bloqueada'`/`'PARTIAL'`
  después de la migración queda silenciosamente muerta (nunca verdadera) en vez de fallar
  ruidosamente, lo que es peor que un error — Principio III exige no dejar comportamiento
  protegido roto en silencio.
- **Alternatives considered**: ninguna — este punto es un recordatorio de alcance para la
  fase de tareas, no una decisión técnica con alternativas.

## R8 — Evento de tiempo real nuevo para "entregada" (FR-020)

- **Decision**: `app/core/events.py` ya tiene `order_confirmed`, `order_cancelled`,
  `payment_completed`, pero ningún evento para la transición a `entregada`. Se añade una
  función `order_delivered(tenant_id, *, order_id, table_session_id)` siguiendo la misma
  forma que `order_confirmed`/`order_cancelled` (mismo canal `session:{id}` + `staff`), y el
  nuevo endpoint de entrega la invoca después del commit (mismo cuidado que
  `notify_sessions_closed`: nunca antes del commit, para no anunciar un cambio que puede
  revertirse).
- **Rationale**: FR-020 exige que el comensal QR reciba la actualización en tiempo real
  específicamente de "entregada"; el canal SSE ya existe (`realtime/router.py`), solo falta
  el tipo de evento. Cobrar (`payment_completed`) ya tiene su propio evento y no necesita
  cambios.
- **Alternatives considered**: reusar `order_confirmed` para también significar "entregada"
  — rechazado: colapsaría dos eventos semánticamente distintos (confirmar vs. entregar) que
  un cliente SSE ya suscrito podría necesitar distinguir, y el patrón del resto del archivo
  es un evento por transición significativa.
