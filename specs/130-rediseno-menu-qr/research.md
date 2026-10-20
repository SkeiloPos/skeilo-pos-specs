# Fase 0 — Research: Rediseño visual del Menú QR con pago mixto y bloqueo de salida

Resuelve las decisiones técnicas necesarias para implementar `spec.md`. No repite las reglas de
negocio ya definidas allí (FR-001 a FR-012) — solo el "cómo" sobre el código real de
`pos-backend` y `pos-heladeria` (hallazgos de exploración confirmados contra el código el
2026-10-20).

## Decisión 1 — Dónde vive hoy cada pantalla del Menú QR (para el rediseño visual)

**Decisión**: el rediseño visual (FR-001/FR-002/FR-003, Historia 1 y 4) se aplica sobre los
componentes ya existentes, sin reestructurar el árbol de componentes salvo donde se indica abajo.

- `pages/public-menu.component.ts` (≈1750 líneas): bienvenida (formulario de nombre), menú con
  categorías/búsqueda/banner de promociones, pestaña "Mis pedidos", carrito (vía
  `components/cart.component.ts`), navegación inferior con "Salir" (`confirmExit()` / `exit()`).
- `components/product-select.component.ts`: hoja de detalle de producto — presentación
  (`role="radiogroup"`) y grupos de opciones/toppings (`toggleOption()`, ya renderizados como
  `<input type="checkbox">` dentro de una tarjeta).
- `components/cart-item-options.component.ts`: listado de solo lectura de opciones elegidas
  (carrito, revisión, "Mis pedidos").
- `pages/checkout/`: `review-step.component.ts`, `payment-method-step.component.ts`,
  `transfer-details-step.component.ts`, `confirmation-step.component.ts`,
  `checkout-step-indicator.component.ts`, `checkout-order-summary.component.ts`,
  `checkout-progress.store.ts` (persistencia de progreso en `localStorage`, spec 034).
- La pantalla de despedida (`isBye` del diseño de referencia) no tiene componente propio hoy:
  vive inline dentro de `public-menu.component.ts`/`diner-shell.component.ts`, en la rama de
  sesión expirada/cerrada (`expireSession('closed')`).

**Alternativa considerada**: dividir `public-menu.component.ts` en subcomponentes por pantalla
(bienvenida, menú, pedidos) antes de restylar. **Rechazada**: el rediseño es explícitamente "sin
cambio de comportamiento" (FR-001) — romper un componente de 1750 líneas en varios es una
refactorización no relacionada con esta funcionalidad (Principio V de la constitución) y
multiplica el riesgo de alterar comportamiento que debe quedar intacto. Se restyla in situ; una
división del componente, si se quiere, es trabajo independiente futuro.

## Decisión 2 — Los toppings ya son checkboxes funcionalmente (Historia 4 / FR visual)

**Hallazgo**: `product-select.component.ts:321-324` ya usa `<input type="checkbox">` dentro de
una tarjeta (`toggleOption()`), no un radio ni un chip. El alcance de la Historia 4 es
exclusivamente visual: igualar el estilo de fila con casillero + nombre + precio del diseño de
referencia, sin tocar `toggleOption()`, las reglas de mínimo/máximo (spec 004) ni la validación
de inventario. **No hay cambio de comportamiento que registrar aquí** — es un ajuste de CSS/
plantilla sobre un control que ya es un checkbox.

## Decisión 3 — Modelo de datos para el pago mixto del comensal

**Problema**: `OrderPaymentAttempt` (`app/models/order_payment_attempt.py`) modela hoy **un**
método de pago por intento (`payment_method_id`), con campos exclusivos de efectivo
(`amount_received`, `change_amount`) o de transferencia (`receipt_file_url`, un único archivo por
intento), y un índice único parcial que permite **a lo sumo un intento `pendiente` por orden a la
vez** (`idx_pending_payment_attempt_per_order`, FR-015a de spec 024).

**Decisión**: extender `OrderPaymentAttempt` con columnas nuevas, nullable, en vez de permitir dos
intentos simultáneos por orden:
- `cash_amount: Numeric(12,2)` — monto en efectivo del pago mixto (NULL si el intento no es mixto).
- `transfer_amount: Numeric(12,2)` — resto a transferir, calculado y persistido al crear el
  intento (`total - cash_amount`), para no recalcularlo contra un total de orden que podría
  cambiar más adelante por motivos ajenos al pago (ninguno hoy, pero evita acoplar el desglose
  histórico al total vigente).
- `transfer_method_id: UUID FK → payment_methods`, nullable — el método de transferencia real
  (ej. Nequi) elegido por el comensal para recibir el resto (FR-005), porque `payment_method_id`
  del intento pasa a apuntar al método "Pago mixto" del catálogo del tenant, que no tiene cuenta
  ni código QR propio — los datos de la transferencia a mostrar (FR-007) se leen de
  `transfer_method_id.payment_info`, no de `payment_method_id.payment_info`.
- `cash_confirmed_at: DateTime`, nullable — cuándo el cajero confirmó haber cobrado la porción en
  efectivo del pago mixto (ver Decisión 4). `NULL` en intentos no mixtos y en el mixto hasta que
  se cobra.

`status` (`pendiente|confirmado|rechazado`) se conserva sin cambiar su contrato para intentos
100% efectivo o 100% transferencia. Para un intento mixto, pasa a representar específicamente la
verificación de la **porción por transferencia** (igual mecanismo que hoy: `receipt_file_url` +
`approve_payment_attempt`/`reject_payment_attempt`); la confirmación de la porción en efectivo se
rastrea aparte con `cash_confirmed_at` (Decisión 4).

**Alternativas consideradas**:
1. **Dos intentos simultáneos por orden** (uno `cash`, uno `transfer`, ambos `pendiente`).
   Rechazada: exige relajar `idx_pending_payment_attempt_per_order` (comportamiento protegido de
   spec 024, Principio III/XI) y complica cada consulta que hoy asume "el intento vigente" como
   una sola fila (`CustomerOrder.current_payment_attempt`, listados de "Mis pedidos", el gate de
   `_confirm_order_impl`) — tendría que convertirse en "los intentos vigentes" en todos esos
   puntos sin necesidad real, ya que el pago mixto del comensal siempre combina exactamente un
   efectivo con una transferencia (Assumptions de `spec.md`).
2. **Una tabla nueva `OrderPaymentAttemptSplit`** (uno-a-muchos). Rechazada por sobre-ingeniería:
   el pago mixto del comensal nunca combina más de dos partes (Assumptions de `spec.md`), así que
   dos columnas nullables en la fila existente cubren el caso completo sin una tabla ni un join
   adicional en cada lectura.

## Decisión 4 — Confirmación de las dos partes de un pago mixto (impacto en Terminal de Mesas)

**Hallazgo**: una orden QR solo avanza de `recibida` a `abierta`/cocina cuando existe un
`OrderPaymentAttempt` con `status='confirmado'` (`_confirm_order_impl`, FR-017 de spec 024);
`confirm_cash_payment_attempt` y `approve_payment_attempt` (`app/api/v1/orders/checkout.py`,
acciones del cajero en la Terminal de Mesas) son los únicos dos lugares que hoy fijan
`status='confirmado'`, cada uno disparando esa transición como efecto colateral.

**Decisión**: para un intento mixto, ninguna de las dos acciones de cajero flipa `status` a
`confirmado` por sí sola:
- `confirm_cash_payment_attempt` sobre un intento mixto fija `cash_confirmed_at`
  (en vez de `status`) y, si `status` ya es `confirmado` (la transferencia ya estaba verificada),
  recién ahí se considera el pago mixto completo.
- `approve_payment_attempt` sobre un intento mixto sigue fijando `status='confirmado'` igual que
  hoy (verificación de la porción por transferencia), pero el pedido solo avanza a cocina cuando
  **además** `cash_confirmed_at` ya tiene valor.
- El gate de `_confirm_order_impl` se extiende: para un intento mixto, "pago confirmado" exige
  `status='confirmado' AND cash_confirmed_at IS NOT NULL`; para un intento no mixto, sigue siendo
  solo `status='confirmado'` (sin cambio de comportamiento, Principio II).

**Impacto declarado en Terminal de Mesas (spec 112, fuera del alcance de UI de esta spec)**: el
cajero necesita poder confirmar cada porción de un pago mixto por separado desde la Terminal. Esta
spec (130) solo define el contrato de backend (las dos columnas y el gate extendido) porque
`FR-008` exige que el desglose exista y se reporte al comensal; **la UI de la Terminal para que el
cajero ejecute esas dos confirmaciones no es parte de esta spec** — ya existen los dos endpoints
(`POST /payment-attempts/{id}/confirm-cash`, `POST /payment-attempts/{id}/approve`) y seguirán
funcionando sobre un intento mixto sin cambios de firma; falta solamente que la UI de la Terminal
muestre ambas acciones cuando el intento es mixto, lo cual queda como trabajo de seguimiento
natural de spec 112, no de esta spec (Principio V/VI — evita mezclar una funcionalidad de staff no
pedida por el negocio dentro de un rediseño del Menú QR del comensal).

## Decisión 5 — Catálogo: "Pago mixto" como método propio (FR-004)

**Decisión**: agregar `'mixed'` al `CHECK` de `PaymentMethodCatalog.type` (hoy
`'cash'|'card'|'transfer'|'other'`, `app/models/payment_method_catalog.py`), para que "Pago mixto"
sea una fila de catálogo distinguible por tipo (igual tratamiento que efectivo/transferencia), no
una sobrecarga de `'other'`. El endpoint de activación de métodos por tenant (spec 032,
`app/api/v1/payment_methods/` — a confirmar ruta exacta en `/speckit-tasks`) agrega la validación
de FR-004: solo permite activar una fila de catálogo `type='mixed'` si el tenant ya tiene activos
al menos un `PaymentMethod` con `type='cash'` y al menos uno con `type='transfer'`.

**Alternativa considerada**: activar "Pago mixto" automáticamente cuando el tenant ya tiene
efectivo y una transferencia activos, sin fila de catálogo propia. **Rechazada explícitamente por
el negocio** (Clarificación Q3/Q5 de `spec.md`) — el tenant debe habilitarlo a propósito.

## Decisión 6 — Esquema del envío del pedido (`POST /cart/submit`) para pago mixto

**Decisión**: extender `SubmitCartIn` (`app/api/v1/cart/schemas.py`) con dos campos nuevos,
opcionales, válidos solo cuando `payment_method_id` apunta al método `type='mixed'` del tenant:
`cash_amount: Decimal | None` y `transfer_method_id: UUID | None`. `submit_cart`
(`app/api/v1/cart/service.py`) valida (FR-006): `cash_amount > 0` y `cash_amount < total del
pedido`; si el tenant tiene más de un método de transferencia activo, `transfer_method_id` es
obligatorio (FR-005); si solo tiene uno, se puede omitir y el servicio lo resuelve solo. El
`receipt_file_url` sigue siendo el de la porción por transferencia (mismo campo ya existente,
mismo flujo de `presign`+`upload` de spec 025/034).

**Invalidación del comprobante al cambiar el monto en efectivo (FR-007, Clarificación Q6)**: no
requiere ningún endpoint nuevo. El comprobante se sube (presign + upload a storage) **antes** de
`submit_cart` — nada queda persistido en `OrderPaymentAttempt` hasta que `submit_cart` crea la
orden y el intento en una sola transacción. La invalidación es, por lo tanto, un comportamiento
puramente del lado del cliente: `CheckoutProgressStore` (`checkout-progress.store.ts`) debe borrar
`receipt_file_url` de su registro en `localStorage` cada vez que el comensal modifica `cash_amount`
después de haber completado la subida, forzando que el paso de transferencia vuelva a pedir el
archivo antes de habilitar "Enviar pedido" — ver Decisión 8.

## Decisión 7 — Bloqueo de "Salir" con pago pendiente (FR-009 a FR-012)

**Hallazgo**: `POST /cart/leave` (`app/api/v1/cart/router.py:111-134`) → `leave_session`
(`app/api/v1/cart/service.py:720-733`) está documentado explícitamente como **idempotente y que
nunca falla** — cierra al participante y libera la mesa si quedó vacía, sin ninguna validación.

**Decisión**: `leave_session` gana una validación nueva, antes de `close_participant`: si el
participante tiene al menos un `CustomerOrder` propio (`participant_id`) en estado no terminal
(`status NOT IN ('cancelada',)`, usando el mismo conjunto `_NON_TERMINAL_ORDER_STATUSES` ya
definido en ese módulo) cuyo `current_payment_attempt` no está completamente confirmado —
`status != 'confirmado'`, o (intento mixto) `status='confirmado' AND cash_confirmed_at IS NULL` —
se lanza una excepción nueva (`PendingPaymentExit` o similar) que el router traduce a
`409 Conflict` con un cuerpo que el frontend usa para el aviso de FR-010. Esto **reemplaza
explícitamente** el contrato "nunca falla" para este único caso — es el cambio de comportamiento
autorizado por la Historia 3 de `spec.md` (y por las Clarificaciones Q1/Q2), y debe registrarse en
`specs/000-reconocimiento/registro-de-anomalias.md` antes de implementarlo (Principio II de la
constitución): qué cambia (`POST /cart/leave` deja de ser infalible), por qué (pedido explícito
del negocio, `spec.md` Historia 3), quién y cuándo (a completar con el usuario al iniciar
`/speckit-tasks` o la implementación), qué se ve afectado (`leave_session`, el botón "Salir" del
Menú QR, y cualquier otro llamador de `leave_session`/`POST /cart/leave` que hoy asuma que nunca
falla — a inventariar en `/speckit-tasks`).

**Alternativa considerada**: bloquear solo del lado del frontend (como hace el mock de diseño,
revisando `s.orders` ya cargado en el cliente) sin tocar el backend. Rechazada como única defensa:
el frontend puede tener datos desactualizados (otra pestaña, otro dispositivo, una confirmación de
pago que llegó por SSE después de cargar la pantalla); el backend es la fuente de verdad y debe
rechazar la operación igual. Sí se mantiene una validación también en el cliente (Decisión 8) para
dar el aviso instantáneo sin esperar un round-trip cuando los datos ya están disponibles.

## Decisión 8 — Frontend: diálogo de bloqueo y reactivo de pago pendiente

**Decisión**: `confirmExit()`/`exit()` (`public-menu.component.ts`) dejan de usar el `confirm()`
nativo del navegador. Nuevo flujo:
1. Antes de llamar a `api.leave()`, se revisa el estado de pedidos ya cargado (pestaña "Mis
   pedidos") por si alguno es propio, no cancelado, y con pago no confirmado — si lo hay, se
   muestra directamente el diálogo de bloqueo (equivalente a `exitBlock` del diseño de referencia:
   título, texto fijo, botón único "Entendido") sin llamar al backend.
2. Si el cliente no detecta nada pendiente (o el estado está desactualizado), se llama a
   `api.leave()`; si el backend responde `409` (Decisión 7), se muestra el mismo diálogo de
   bloqueo en vez del `catch` silencioso actual.
3. Solo si `api.leave()` resuelve con éxito se ejecuta `exit()` (cierre real de sesión y pantalla
   de despedida).

`diner.service.ts::leave()` deja de tragarse todos los errores: debe distinguir `409` (pago
pendiente) de otros errores de red (donde sí puede seguir siendo best-effort, igual que hoy).

Para la invalidación del comprobante (Decisión 6), `checkout-progress.store.ts` gana un `effect`/
método que, al escribir un `cash_amount` nuevo distinto del guardado, borra `receipt_file_url` del
mismo registro si existía.

## Decisión 9 — Mapeo de íconos del diseño de referencia

**Decisión**: se reutiliza el precedente ya sentado en spec 034 (Assumptions de `spec.md`): los
íconos Lucide del archivo `design/Bienvenida QR v1.dc.html` se mapean 1:1 al set de íconos interno
ya usado por `pos-heladeria` (mismo componente/sistema de íconos de los pasos de checkout
existentes), sin agregar una librería nueva (Principio IX).
