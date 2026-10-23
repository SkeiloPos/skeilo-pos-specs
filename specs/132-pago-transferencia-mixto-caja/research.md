# Research: Pago por transferencia y pago mixto sin subida de comprobante

**Spec**: [spec.md](./spec.md) | **Fecha**: 2026-10-23

Todos los puntos de este documento provienen de inspeccionar el código real de
`pos-backend` y `pos-heladeria` (no hay NEEDS CLARIFICATION pendientes en el Technical
Context: el stack, el modelo de pagos y los patrones de auditoría ya existen y se
reutilizan).

## Decisión 1 — Relajar `receipt_file_url` de requerido a evidencia opcional del cajero

**Decisión**: `approve_payment_attempt` (`app/api/v1/orders/checkout.py`) deja de exigir
`attempt.receipt_file_url` para aprobar un intento de transferencia. El campo se mantiene en
el modelo, pero pasa a ser escrito únicamente por el cajero (adjunto opcional al confirmar,
FR-012), nunca por el comensal desde el QR.

**Racional**: FR-001/FR-002/FR-023 eliminan la subida de comprobante por el comensal; el
chequeo actual (`if not attempt.receipt_file_url: raise 409`) es exactamente el control que
el spec retira porque "una imagen subida no se puede validar" (Input del spec). Mantener el
campo evita una migración de esquema (no hay backfill ni pérdida de datos históricos,
Principio VII) y preserva el caso de uso real que sí queda: el cajero puede adjuntar una foto
para el chat de WhatsApp del negocio.

**Alternativas consideradas**:
- Eliminar `receipt_file_url` por completo → rechazada: pierde la evidencia opcional que
  FR-012 exige poder almacenar.
- Añadir un segundo campo `cashier_receipt_file_url` distinto del existente → rechazada:
  duplica el concepto sin necesidad; el campo existente nunca tuvo otro significado que "la
  imagen del comprobante de este intento", y ahora simplemente la escribe otro actor.

**Decisión de negocio a registrar** (Principio II, antes de implementar): este es un cambio
de comportamiento sobre spec 024/130 (quién puede/debe adjuntar comprobante y si bloquea la
aprobación). Se registra en `specs/000-reconocimiento/registro-de-anomalias.md`: qué cambia
(gate de `receipt_file_url` en `approve_payment_attempt`), por qué (el spec 132 lo autoriza
explícitamente, Input + FR-001/002/012/023), quién (autor del spec 132), cuándo (fecha de esta
sesión), y qué funcionalidades se ven afectadas (flujo QR de checkout por transferencia/mixto,
panel de revisión de pagos en caja).

## Decisión 2 — Conjunto cerrado de motivos de rechazo

**Decisión**: El motivo de rechazo (FR-015) se valida en el límite de la API (`schemas.py`,
`PaymentAttemptRejectIn.reason` como `Enum`/`Literal` con los 5 valores del spec) y además se
refuerza con un `CheckConstraint` en `order_payment_attempts.rejection_reason` a nivel de base
de datos (defensa en profundidad, mismo patrón que `ck_order_payment_attempt_status`). La
columna sigue siendo `String`, no se normaliza a una tabla de referencia aparte.

**Racional**: FR-015 exige "un conjunto cerrado" explícito; validar solo en frontend no es
suficiente porque la API de caja puede recibir llamadas directas. Una tabla de referencia
separada sería sobre-ingeniería para 5 valores fijos que no cambian por tenant.

**Alternativas consideradas**: tabla `rejection_reasons` configurable por tenant → rechazada,
el spec no pide personalización por negocio y agregaría una entidad sin necesidad
(Principio IX, dependencias/entidades nuevas solo con justificación).

## Decisión 3 — Historial de auditoría consultable: `AuditLog` (RF-076), no el canal solo-Sentry de spec 074

**Decisión**: Cada cambio de estado de un pago (creación, confirmación, rechazo, anulación,
reajuste de división) se registra con `record_audit` (`app/core/audit.py`) hacia la tabla
`tenant.audit_logs`, además de — no en lugar de — los eventos `record_order_audit_event` de
spec 074 que ya existen para observabilidad en Sentry.

**Racional**: FR-019 exige un "historial de auditoría, solo de inserción", y las historias de
usuario (US4 Acceptance Scenario 2, US5 Acceptance Scenario 6) exigen poder *consultar* ese
historial desde el propio pedido. `record_order_audit_event` (spec 074) está documentado como
"nunca persiste en DB; emite solo cuando `ENVIRONMENT == 'prod'`" — no es consultable desde la
aplicación y no cumpliría FR-019 en ambientes no-prod ni en una pantalla de back-office.
`AuditLog` ya es exactamente insert-only, persistida en el schema del tenant, indexada por
`entity`/`entity_id`, y ya se usa para el caso análogo de pérdidas por cancelación
(`action="order.cancel.loss"`).

**Alternativas consideradas**:
- Nueva tabla `payment_events` dedicada → rechazada: `AuditLog` ya cubre el contrato
  (actor, hora, payload con valores antes/después) sin introducir una entidad nueva
  (Principio IX).
- Solo `record_order_audit_event` (spec 074) → rechazada: no persiste en DB fuera de prod y no
  es consultable por la aplicación, incumpliendo el "se consulta el historial del pedido" de
  las historias de usuario.

## Decisión 4 — Reajuste de división efectivo/transferencia (FR-013/014) sin columnas nuevas

**Decisión**: Nuevo endpoint `POST /payment-attempts/{attempt_id}/adjust-split` que, sobre un
intento `pendiente`, permite mutar `cash_amount`, `transfer_amount`, `transfer_method_id` y,
si corresponde, `payment_method_id` (para convertir transferencia total ↔ mixto ↔ efectivo
total). Antes de mutar, valida `cash_amount + transfer_amount == total del pedido` (409 si no
coincide, FR-013/Acceptance Scenario 3) y escribe en `AuditLog` un payload con los valores
`antes` y `después` (Decisión 3) — no se agregan columnas `declared_*` al modelo.

**Racional**: el valor que el comensal declaró en el QR nunca se sobrescribe sin dejar rastro
porque el snapshot "antes" se captura en el payload de auditoría en el mismo momento de la
mutación, dentro de la misma transacción — exactamente el nivel de trazabilidad que pide
FR-014 ("quedan registrados los montos originales y los finales, el cajero y la hora"), sin
necesidad de persistir el valor declarado en una columna separada que viviría sin uso el resto
del ciclo de vida del intento.

**Alternativas consideradas**: columnas `declared_cash_amount`/`declared_transfer_amount` en
`order_payment_attempts` → rechazada: redundante con lo que ya captura el payload de auditoría
y añade una migración de esquema sin beneficio adicional (Principio VIII, evitar cambios de
esquema no necesarios).

## Decisión 5 — Un único reintento (FR-017) sin columna de contador

**Decisión**: El límite de "un único reintento" se calcula contando, en el momento de crear un
nuevo intento de transferencia tras un rechazo, cuántos intentos `rechazado` con método no
efectivo ya existen para esa orden (`list_payment_attempts` ya expone este historial). Si ya
hay uno, el endpoint de creación de un nuevo intento de transferencia lo rechaza con 409 y un
mensaje que orienta a las otras dos salidas (efectivo total o cancelación por impago).

**Racional**: los intentos de pago de una orden ya son un historial completo y ordenado
(`order_payment_attempts.order_id` + `created_at`); contar los `rechazado` existentes es
suficiente y evita un contador redundante que podría desincronizarse del historial real.

## Decisión 6 — Cancelación por impago (FR-018): reutilizar `cancel_order`, no crear `Merma`

**Decisión**: La salida "cancelar el pedido como impago" (US5, FR-017/018) reutiliza el
endpoint de cancelación de pedido ya existente (`checkout.py`, cerca de la línea 900-985), que
ya anula el intento de pago `pendiente` del pedido y ya registra las pérdidas de inventario
como `AuditLog(action="order.cancel.loss", ...)` cuando hay ítems ya consumidos. Se usa un
`motivo` distintivo (p. ej. `"impago_transferencia_rechazada"`) para que el reporte de mermas
pueda distinguir esta causa de una cancelación ordinaria.

**Racional**: no existe hoy un modelo `Merma` dedicado — las pérdidas de inventario por
cancelación ya se tratan como un registro de auditoría informativo, sin movimiento de
inventario adicional (el descuento ya ocurrió al confirmar la orden). Crear una entidad nueva
solo para este spec iría contra el Principio IX (dependencias/entidades nuevas solo con
justificación fuerte) cuando el patrón existente ya cumple "se registra como merma" (FR-018)
en los mismos términos que el resto del sistema.

**Alternativas consideradas**: modelo `Merma` dedicado con su propia tabla → rechazada por
sobre-alcance frente al patrón ya establecido; el spec no pide un módulo de mermas, solo que
la cancelación por impago "se registre como merma para efectos de control de inventario y
costos", lo que el `AuditLog` ya existente satisface igual que para cualquier otra
cancelación con ítems consumidos.

## Decisión 7 — Aviso de segunda mesa rechazada en el día (FR-020) vía conteo, sin columna de flag

**Decisión**: Al confirmar un rechazo, se cuenta cuántos `OrderPaymentAttempt.status ==
'rechazado'` existen para órdenes de la misma `dining_table_id`, con `created_at` dentro del
día calendario actual (zona horaria del negocio). Si el conteo llega a 2 o más, se escribe un
`AuditLog(action="payment.table_repeat_rejection", entity="dining_tables", entity_id=<mesa>,
payload={...})` adicional, que una pantalla de back-office (fuera de alcance de este spec)
puede listar para revisión del administrador. No se agrega una columna `flagged_for_review` a
`CustomerOrder` ni a `DiningTable`.

**Racional**: FR-020 exige "marcar para revisión", no bloquear ni notificar en tiempo real; un
registro de auditoría adicional, consultable por `entity`/`entity_id`, cumple el requisito sin
mutar el modelo de mesas o pedidos. El conteo se basa en `order_payment_attempts`, que ya es
persistente y no depende del canal solo-Sentry de spec 074 (Decisión 3).

**Alternativas consideradas**: columna booleana en `CustomerOrder`/`DiningTable` → rechazada,
innecesaria cuando el conteo sobre una tabla ya existente resuelve el requisito sin cambios de
esquema.

## Resumen de impacto en Technical Context

No quedan `NEEDS CLARIFICATION`. Todas las decisiones anteriores reutilizan infraestructura
existente de `pos-backend` (modelos, endpoints, patrón de auditoría) y de `pos-heladeria`
(componentes de checkout QR y de revisión de pagos en caja), conforme al Principio V/VI de la
constitución (evolución incremental, sin refactor oportunista ni entidades nuevas no
justificadas).
