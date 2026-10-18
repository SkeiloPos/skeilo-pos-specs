# Research: Confirmación Única de Pago

## R1 — Dónde viven hoy los tres avisos y por qué se duplican

**Hallazgo** (investigación de código, `pos-heladeria` y `pos-backend`):

- El modal "Pago registrado" (`table-sessions.component.ts:274-330`) lo abre
  `PosTerminalStore` desde dos caminos:
  - `onCharged()` (cierre completo de sesión de mesa, llamado desde
    `SessionBillPanelComponent.charge()` → `pos-checkout-panel.component.ts:193`).
  - `checkoutAndSend()` (cobro de mostrador/pedido individual,
    `pos-terminal.store.ts:2904-2934`), que **además** dispara
    `this.toast.success('Pedido cobrado, facturado y enviado a cocina')` justo después de abrir el
    modal, en el mismo bloque `try` de la respuesta HTTP exitosa. Este es el segundo aviso (#3 de
    la spec) — es local, síncrono, no viene de SSE.
- El toast "Pago recibido · $<monto>" (#2 de la spec) viene de
  `NotificationCenterService.onNotificationCreated()` (`notification-center.service.ts`), que
  escucha el evento SSE genérico `notification.created` (spec 077) y llama
  `this.toast.info(ev.summary)` cuando la pestaña tiene foco. El backend publica ese evento en el
  canal `staff` del tenant (`CH_STAFF`, `app/core/events.py`) **sin ninguna distinción de quién lo
  originó** — todo terminal conectada del tenant lo recibe por igual, incluida la que acaba de
  cobrar.

**Decisión**: tratar los avisos #2 y #3 como dos problemas de origen distinto, no uno solo:
- #3 se **elimina** (es una simple llamada a `toast.success()` redundante con el modal que se abre
  en la misma función).
- #2 se **silencia solo en la terminal de origen**, sin dejar de emitirse para el resto del tenant
  (RF explícito de la spec) — requiere un identificador de origen (ver R3).

**Alternativa considerada y descartada**: eliminar también el toast #2 globalmente. Se descarta
porque rompería la notificación en tiempo real para las demás terminales (User Story 2 de la
spec, y el objetivo central de la spec 077).

## R2 — Formato de moneda roto en el toast SSE

**Hallazgo**: el texto del toast #2 no lo construye el frontend — llega ya armado del backend en
`ev.summary`, generado por `summarize()` (`app/core/notifications/summary.py`):

```python
if event.event_type == "payment.completed":
    total = payload.get("total")
    return f"Pago recibido · ${total}" if total is not None else "Pago recibido"
```

`total` es un `Decimal` serializado a texto crudo (p. ej. `"22000"`), de ahí "$22000.00" /
"$22000" sin separador de miles ni el espacio que exige el formato estándar del producto
(`$ 22.000`, spec 035). El frontend nunca reformatea `summary`: lo muestra tal cual llega. Existe
un bug gemelo, no cubierto por esta spec, en la rama `order.created` del mismo `summarize()` y en
el fallback `summarize()` de `notification.model.ts` (usado solo al hidratar notificaciones viejas
vía REST, no en el toast en vivo).

**Decisión**: agregar un formateador mínimo y dedicado dentro de `summary.py`
(`_formato_pesos_espacio(valor) -> "$ 22.000"`, sin decimales, punto de miles, espacio tras el
"$"), y usarlo únicamente en la rama `payment.completed`. Se replica también en la rama
`payment.completed` del fallback de `notification.model.ts`, usando el `formatMoney()` ya
existente en `src/app/shared/money.ts` (no se duplica lógica en TS: ya hay una función
compartida ahí).

**Alternativas consideradas**:
- *Reusar `format_pesos()` de `app/api/v1/cash/denominations.py`*: descartada — ese formateador
  no lleva espacio tras el "$" (`"$3.000"`, no `"$ 3.000"`) y admite decimales con coma, un
  formato distinto al que exige esta spec y al que ya usa el modal (`formatMoney()` del
  frontend). Cambiarlo afectaría las pantallas de arqueo de caja que ya lo usan, fuera de alcance.
- *Dejar de mandar `summary` ya formado y mandar `total` crudo para que el frontend lo formatee
  con `formatMoney()`*: más "correcto" a largo plazo (una sola fuente de formato), pero cambia el
  contrato de `NotificationCreatedEvent.summary` para **todos** los tipos de evento (afecta
  también `order.created` y el bell/dropdown de notificaciones), lo que excede el alcance de esta
  spec (Principio V/VI: cambio incremental, sin mezclar refactors no pedidos). Se deja como mejora
  futura, no se implementa aquí.
- *Fijar también el bug gemelo de `order.created`*: descartado por la misma razón — no está en el
  alcance de la declaración de esta spec ("montos... en relación con un cobro").

## R3 — Identificador de terminal/sesión para silenciar el aviso de origen

**Hallazgo**: ni el frontend ni el backend tienen hoy ningún concepto de "qué pestaña/terminal
está conectada" reutilizable para este fin:
- El ticket de conexión SSE (`POST /realtime/ticket`, `RealtimeService.connectStaff()`) es de un
  solo uso por reconexión — no es un identificador estable de "esta pestaña".
- `resolve_staff()` (`app/api/v1/realtime/auth.py`) ni siquiera conserva `user_id` en el
  `Subscriber`, y el payload de `payment.completed`/`notification.created` no incluye ningún
  `actor_id` u origen.
- El único `crypto.randomUUID()` existente en el store (`pendingCreateRequestId`,
  `pos-terminal.store.ts:1736`) es una clave de idempotencia para creación de pedidos, de vida
  corta (se limpia tras usarse) — no sirve como identidad estable de "esta terminal".

**Decisión**: introducir un identificador nuevo y mínimo, **por pestaña** (no por usuario ni por
dispositivo): `RealtimeService.clientId`, un `crypto.randomUUID()` generado una vez y persistido
en `sessionStorage` (no `localStorage`, para no compartirlo entre pestañas del mismo navegador —
cada pestaña es una "terminal" distinta a efectos de esta spec). Se envía como campo opcional
`origin_client_id` en el cuerpo de las peticiones de cobro (`CheckoutAndSendIn`, `CloseSessionIn`,
`PayIn`), se persiste dentro del JSON ya existente de `NotificationEvent.payload`, y se reenvía en
el payload del evento SSE `notification.created` (`InAppChannel.send()`) para que
`NotificationCenterService` pueda compararlo contra su propio `clientId` y, si coincide, omitir el
toast y el sonido (pero igual mezclar el ítem en la lista de notificaciones — mismo criterio que
ya usa ese servicio para el caso de pestaña sin foco).

**Alternativas consideradas**:
- *Usar el `user_id` del cajero autenticado*: descartado — silenciaría también otras pestañas del
  mismo cajero, violando explícitamente la regla de negocio ("otra terminal" incluye otra pestaña
  del mismo usuario, Edge Case de la spec).
- *Generar el id en el backend al emitir el ticket SSE y devolverlo al frontend*: descartado por
  innecesariamente más complejo — el frontend ya puede generar y persistir su propio UUID sin
  depender de una respuesta del servidor, y es el mismo patrón que ya usa
  `pendingCreateRequestId`.
- *Cabecera HTTP (`X-Client-Id`) en vez de campo del body*: descartado por consistencia — el
  patrón ya establecido en este backend para identificadores de origen enviados por el cliente es
  un campo del body (`client_request_id` en `OrderCreatePayload`/`CustomerOrder`), no una cabecera
  nueva.

## R4 — Alcance del pago complementario (spec 123)

**Hallazgo**: el cobro de saldo pendiente (`settlePendingBalance()`,
`pos-terminal.store.ts:2473-2492`) no abre el modal "Pago registrado" ni dispara el toast #3 — ya
muestra un único toast propio ("Saldo pendiente cobrado"). Tampoco llama a
`notify_payment_completed()` en el backend (`app/api/v1/.../settle_complementary_payment` no está
entre los 3 call-sites existentes) — hoy ese flujo no emite ninguna notificación en tiempo real a
otras terminales.

**Decisión**: queda explícitamente fuera de alcance. No se le agrega notificación en tiempo real
(sería una funcionalidad nueva, no un bug de esta spec) ni se le toca su toast único existente.

## R5 — Puntos exactos de emisión de `payment.completed` / `notify_payment_completed`

Confirmados por lectura directa del código (no requieren más investigación):

1. `app/api/v1/orders/router.py:608-623` — `pay_order()` (`POST /orders/{id}/pay`).
2. `app/api/v1/orders/router.py:644-660` — `checkout_and_send()`
   (`POST /orders/{id}/checkout-and-send`).
3. `app/api/v1/table_sessions/service.py:375-390` — `close_session()` (una llamada por venta
   emitida; en cobro dividido, una por comensal, todas dentro de la misma petición de cierre).

Los tres reciben ya el cuerpo de la petición (`body`/`data`) en el mismo scope donde llaman a
`notify_payment_completed()`, así que agregar `origin_client_id=body.origin_client_id` (o
`data.origin_client_id` en el servicio) a cada llamada no requiere cambiar ninguna firma de
función intermedia más allá de la propia `notify_payment_completed()`.

## R6 — Decisión de negocio A-136 (botón "Imprimir Factura" en el modal)

Ver [spec.md, Historia 4](./spec.md) y
[A-136](../000-reconocimiento/registro-de-anomalias.md#a-136) — confirmada explícitamente con el
usuario durante esta sesión de planificación, no es una decisión técnica unilateral. Se reutiliza
la misma acción de impresión ya existente (`store.printReceipt()` / `store.printOrderInvoice()`),
sin crear una ruta de impresión nueva.
