# Research: Estado inicial PENDIENTE para órdenes e ítems, sin traducción en frontend

**Feature**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md)

## 1. Mapeo de terminología del spec al código real

**Decision**: El spec usa "RECIBIDA"/"PENDIENTE" en mayúsculas como nombres conceptuales de
negocio. El código real usa valores en minúscula, en español, como literales de un `CHECK
constraint` sobre una columna `VARCHAR`:

- Orden (`CustomerOrder.status`, `app/models/customer_order.py:79`): `recibida`, `abierta`,
  `bloqueada`, `pagada`, `cancelada`.
- Ítem (`OrderItem.estado_cocina`, `app/models/order_item.py:72-74`): `pendiente`,
  `en_preparacion`, `listo`, `anulado`.

**Rationale**: "RECIBIDA" del spec = `status == 'recibida'` a nivel de orden. "PENDIENTE" del
spec = el nuevo valor objetivo `status == 'pendiente'` a nivel de orden — un valor nuevo para
esa columna (no confundir con `estado_cocina == 'pendiente'`, que es una columna distinta, sin
colisión real porque pertenecen a constraints y tablas distintas).

**Alternatives considered**: Usar un valor distinto a `'pendiente'` para evitar la coincidencia
visual con `estado_cocina`. Rechazado: el spec nombra explícitamente "PENDIENTE" como el estado
resultante; introducir un sinónimo distinto solo por evitar una coincidencia de nombre entre dos
columnas no relacionadas reintroduce la ambigüedad que el spec busca eliminar.

## 2. `OrderItem` no tiene un estado "recibida" que migrar

**Decision**: FR-003 ("ítems nacen en PENDIENTE") ya se cumple hoy: `estado_cocina` nace en
`'pendiente'` por defecto (`app/models/order_item.py:72-74`) para todo ítem nuevo,
independientemente del canal o del estado de la orden padre. No se requiere cambio de modelo
ni de migración de datos para ítems.

**Rationale**: El spec asume (Key Entities) que el ítem tiene un "estado propio", y lo
describe como ya alineado con PENDIENTE — la investigación confirma que esa descripción ya es
cierta en el código actual.

**Alternatives considered**: Ninguna — se documenta como hallazgo de verificación, no como
decisión de diseño. La única acción pendiente es un characterization test explícito que fije
este comportamiento (para que un cambio futuro no lo rompa en silencio), no un cambio de
código.

## 3. Columna `payment_status` nueva (decisión de usuario, ver plan.md)

**Decision**: Se añade `payment_status: Mapped[str]` a `CustomerOrder`, con `CHECK constraint`
propio (`ck_customer_order_payment_status`), valores `UNPAID | PAID | PARTIAL`,
`server_default="UNPAID"`, no nulo.

**Rationale**: No existe ningún campo de pago explícito en el modelo actual — el pago se
infiere de `status == 'pagada'` y de `OrderPaymentAttempt.status` (que es específico del flujo
de comprobante de transferencia QR, no un estado de pago general de la orden). FR-002 exige que
el "estado de pago" sea una propiedad consultable y reportada por la API de forma explícita;
derivarlo solo en la capa de respuesta deja sin resolver el caso de pago parcial/mixto (edge
case del spec) sin un lugar donde guardarlo.

**Alternatives considered**:
- *Derivar `payment_status` en el serializer de la API, sin columna nueva*: más simple, cero
  migración. Rechazada por decisión explícita del usuario: el pago parcial/mixto no tiene hoy
  ningún campo que lo represente, así que "derivarlo" en realidad requeriría inventar el mismo
  dato en otro lugar (por ejemplo, un campo transitorio `monto_pagado`), sin ganar nada sobre
  una columna real, y perdiendo la posibilidad de indexar/filtrar por estado de pago.
- *Reutilizar `OrderPaymentAttempt.status` como fuente de verdad*: rechazada porque esa tabla
  modela intentos de pago (puede haber varios, incluidos rechazados) del flujo de comprobante
  QR específicamente, no el estado de pago consolidado de la orden en todos los canales
  (caja/mostrador no pasa por `OrderPaymentAttempt`).

**Migration/rollback strategy** (Principio VIII): ver `data-model.md`. Backfill: toda orden
existente con `status == 'pagada'` → `payment_status = 'PAID'`; todo lo demás →
`payment_status = 'UNPAID'` (no hay forma de reconstruir retroactivamente pagos parciales
históricos porque no existía el concepto; se documenta como limitación conocida, no se inventa
el dato). Rollback: eliminar la columna `payment_status` (operación reversible porque ningún
otro dato depende de ella todavía al momento de este plan).

## 4. Caja/mostrador y domicilio empiezan a nacer en `pendiente` (decisión de usuario)

**Decision**: Se modifica `app/api/v1/orders/service.py::create_order` (línea 784) para que
toda orden nueva (caja, domicilio) nazca con `status="pendiente"`, salvo que el pago se
confirme en el mismo acto de creación, en cuyo caso `payment_status` refleja esa confirmación
pero `status` sigue siendo `"pendiente"` (FR-001/FR-002 — el estado de la orden y el estado de
pago son independientes). El flujo `hold_for_payment` deja de ser el único camino hacia
`"recibida"`/`"pendiente"`: pasa a ser el comportamiento por defecto para todo canal.

**Rationale**: Es exactamente lo que exige FR-001 del spec aprobado, aplicado literalmente
("Toda orden nueva... se crea en PENDIENTE... salvo pago confirmado en el mismo acto de
creación"). La alternativa de no tocar caja/domicilio dejaría el mismo problema de
inconsistencia entre canales que el spec busca resolver (User Story 1, "Why this priority").

**Alternatives considered**: Limitar el alcance a QR únicamente y dejar caja/domicilio como
están hoy. Rechazada por decisión explícita del usuario — contradice directamente FR-001 y el
"Why this priority" de la User Story 1 del spec, que existe precisamente para unificar el
criterio entre canales.

**Impacto identificado a validar en implementación**: El descuento de inventario hoy ocurre al
crear la orden cuando `status == "abierta"` (ver comentarios en
`app/api/v1/orders/service.py:1-15`). Si la creación pasa a `"pendiente"` por defecto, ese
descuento de inventario inmediato debe moverse al punto de confirmación (`confirm_order` /
transición `pendiente → abierta`), igual que ya ocurre hoy para QR. Este efecto colateral debe
quedar explícito en `registro-de-anomalias.md` junto con el cambio de estado, porque afecta el
momento en que el inventario se descuenta para ventas de mostrador — un comportamiento visible
para el negocio, no un detalle de implementación interno.

## 5. Mecanismo de migración multi-tenant

**Decision**: Se usa el patrón ya existente `for_each_tenant_schema`
(`app/scripts/tenant.py:9-19`), igual que la migración de referencia
`alembic/versions/c9d0e1f2a3b4_table_sessions_participants.py`. La nueva migración:

1. Para cada esquema (`tenant_default` + cada fila de `shared.tenants`):
   - `UPDATE customer_order SET status = 'pendiente' WHERE status = 'recibida'`
   - `ALTER TABLE customer_order ADD COLUMN payment_status ...` + backfill (ver sección 3)
   - `DROP CONSTRAINT ck_customer_order_status` / `CREATE CHECK constraint` sin `'recibida'`,
     con `'pendiente'` en su lugar.
2. `downgrade()` espejo: recrea el CHECK con `'recibida'`, revierte `status` donde aplique
   (ver limitación: no se puede distinguir retroactivamente qué filas en `'pendiente'` eran
   originalmente `'recibida'` vs. nuevas órdenes creadas ya en `'pendiente'` tras el upgrade —
   se documenta como limitación de rollback, no se bloquea el downgrade por eso), y elimina la
   columna `payment_status`.

**Rationale**: Es el mecanismo estándar y ya probado del proyecto para migraciones
multi-schema; reutilizarlo cumple FR-005 (migración automática durante `alembic upgrade head`,
sin paso manual) sin introducir un mecanismo nuevo.

**Alternatives considered**: Script independiente fuera de Alembic. Rechazada por decisión de
negocio ya tomada en el spec (clarificación de sesión 2026-11-01): la migración debe ser
automática, parte de la herramienta estándar de migración de esquema.

**Nota sobre "esquema público"**: El spec habla de "esquema público"; en este proyecto no existe
un esquema de negocio llamado `public` — el equivalente es `tenant_default` (esquema por
defecto/semilla) más el esquema `shared` (cross-tenant, contiene `shared.tenants`). La migración
cubre `tenant_default` + todos los esquemas de `shared.tenants`. `shared` en sí no tiene tablas
`customer_order`/`order_item`, por lo que no requiere el UPDATE/CHECK, solo es la fuente de la
lista de esquemas a recorrer.

## 6. Enforcement a nivel de base de datos

**Decision**: Se mantiene el mecanismo existente — `VARCHAR` + `CHECK constraint` (no se migra
a un ENUM nativo de Postgres). El nuevo CHECK de `status` simplemente ya no incluye
`'recibida'` en su lista de valores permitidos.

**Rationale**: Es exactamente el mecanismo que ya usa el proyecto para esta columna
(consistencia con el patrón existente) y satisface FR-007 (rechazo a nivel de base de datos)
sin introducir un tipo de dato nuevo (ENUM nativo) que complicaría los `ALTER TYPE` futuros
sobre una base multi-schema.

**Alternatives considered**: Migrar a un ENUM nativo de Postgres (`CREATE TYPE order_status AS
ENUM (...)`). Rechazada: un ENUM nativo de Postgres no se puede alterar dentro de una
transacción en versiones de Postgres anteriores a la 12 sin trucos, y aquí ya hay un patrón de
CHECK constraint funcionando igual en todos los esquemas; cambiar el tipo de columna sería un
cambio de arquitectura no solicitado por el spec (violaría Principio V — no mezclar
refactorización no relacionada con la funcionalidad).

## 7. Frontend: eliminar inferencia sin romper la vista agregada de mesa

**Decision**:
- `order-status.util.ts`: `ORDER_STATUS`/`KITCHEN_STATUS` dejan de usarse para mostrar una
  "etiqueta traducida" como la salida principal; en su lugar se expone una lista estática de
  estados conocidos (`KNOWN_ORDER_STATUSES`, `KNOWN_KITCHEN_STATUSES`) usada solo para detectar
  valores no mapeados vía `console.error`. El valor mostrado es siempre el string crudo
  recibido de la API.
- `displayOrderStatus()` se elimina: ningún componente debe sustituir `order.status` por
  `'pagada'` basándose en `order.paid`.
- `deriveTableStatus()` (`pos-terminal.store.ts`) se conserva **solo** como heurística de
  ocupación de la tarjeta de mesa agregada (varias órdenes → un estado de mesa sintético, que
  nunca pretendió ser "el" estado de una orden). Deja de alimentar el `statusLabel` de las
  tarjetas de **orden individual** dentro del panel de mesas (`OrderSummaryCardView`): esas
  tarjetas pasan a mostrar el `status` crudo de esa orden específica, igual que la lista de
  órdenes y el detalle de pedido.

**Rationale**: FR-008 exige que "toda pantalla que presente el estado de una orden o de un
ítem" muestre el valor crudo. Una tarjeta de **mesa** (no de una orden específica) no presenta
el estado de una orden — presenta un agregado operativo distinto (¿está ocupada la mesa?), por
lo que mantenerla fuera de alcance no viola el requisito, siempre que deje de ser la fuente del
estado mostrado para una orden individual.

**Alternatives considered**: Eliminar `deriveTableStatus` por completo y no mostrar ningún
indicador agregado en la tarjeta de mesa. Rechazada: el spec no pide eliminar la vista de
ocupación de mesa (fuera de alcance de FR-008, que habla de estado de orden/ítem, no de
ocupación de mesa), y hacerlo sería una refactorización no solicitada (Principio V).

## 8. Characterization tests y archivos a actualizar explícitamente

**Decision**: Antes de implementar, correr:
- Backend: `grep -rn "recibida" app/characterization_tests app/scripts` para el listado
  completo exacto (la investigación identificó como probables `test_orders_service.py`,
  `test_orders_checkout.py`, `test_cart_single_active_order.py`,
  `test_orders_payment_gate.py`, `test_cash_close_active_orders.py`, y los scripts
  `test_receta_obligatoria.py`, `test_variant_option_groups.py`, `e2e_qr_flow.py`,
  `test_cancel_inventory.py`).
- Frontend: specs que referencian `'recibida'` como fixture — confirmados:
  `order-status.util.spec.ts`, `pos-terminal.store.spec.ts`,
  `pos-order-panel.component.spec.ts`, `order-summary-card.component.spec.ts`,
  `payment-attempt-review-panel.component.spec.ts`, `pos-checkout-panel.component.spec.ts`,
  `orders-page.component.spec.ts`, `order-detail.component.spec.ts`,
  `table-sessions.component.spec.ts`, `public-menu.component.spec.ts`,
  `diner.service.spec.ts`, `dining-session.service.spec.ts`,
  `cash-arqueo-modal.component.spec.ts`, `cash-session.store.spec.ts`,
  `manual-order-page.component.spec.ts`.

**Rationale**: Principio III exige que ningún characterization test se modifique solo para
hacer pasar el código nuevo sin cita explícita de la decisión que lo autoriza; este listado es
el insumo para que `/speckit-tasks` genere tareas de actualización explícita, no silenciosa.

**Alternatives considered**: N/A — es un paso de preparación, no una decisión de diseño.

## Resumen de incógnitas resueltas

Ninguna marca `NEEDS CLARIFICATION` queda abierta. Las dos incógnitas que no estaban resueltas
por el spec (existencia de `payment_status`, alcance real de "todo canal nace en PENDIENTE"
frente al comportamiento actual de caja/domicilio) se resolvieron con el usuario durante esta
sesión de planificación (ver "Clarifications de planificación" en `plan.md`) y quedan
documentadas en las secciones 3 y 4 de este archivo.
