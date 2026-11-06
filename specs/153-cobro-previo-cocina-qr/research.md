# Research: Pago antes de cocina para pedidos de mesa (QR) con módulo de cocina activo

**Feature**: 153-cobro-previo-cocina-qr | **Fecha**: 2026-11-05

Este documento resuelve los puntos sin resolver de la investigación de código (NEEDS
CLARIFICATION técnico) necesarios antes de diseñar `data-model.md` y `contracts/`. El
spec.md ya no tiene preguntas de negocio abiertas (todas resueltas en la sesión de
Clarifications 2026-11-05); lo que sigue es exclusivamente investigación de implementación.

## 1. Dónde se dispara hoy el cobro de un pedido de mesa por QR

**Decisión**: El punto de entrada real es `SessionBillPanelComponent.charge()`
(`pos-heladeria/src/app/modules/tables/components/session-bill-panel.component.ts:300`),
que llama a `TableSessionService.charge()`/`.close()`
(`table-session.service.ts:63-82`) → backend `charge_session`/`close_session` →
`_charge_session` (`pos-backend/app/api/v1/table_sessions/service.py:328`). **No** es
`pay_order` (`checkout.py:550`): ese endpoint existe pero no tiene ningún punto de llamada
confirmado desde el panel de mesa por QR.

**Razón**: Es el único camino que el usuario reportado usa realmente para cobrar una mesa
(incluida la del menú QR); diseñar el fix sobre `pay_order` no resolvería el bug reportado.

**Alternativas consideradas**: Interceptar en `pay_order` — descartado porque no está en la
ruta de ejecución real del bug.

## 2. Causa raíz exacta del bug "sale Entregar y Cobrar a la vez"

**Decisión**: La causa es `ensureReadyToCharge` (`pos-terminal.store.ts:2954-2984`),
invocado como `beforeCharge` por `session-bill-panel.component.ts` antes de `charge()`.
Esta función busca ítems con `estado_cocina==='pendiente'` (regla *pre-cocina*, spec 147),
sin mirar `kitchen_status` ni el flag de módulo de Cocina, y si encuentra alguno muestra un
diálogo de confirmación cuyo botón dice **"Entregar y cobrar"**; al confirmar, llama a
`deliverOrder()` para cada pedido pendiente y luego cobra. Esto reproduce exactamente el
síntoma reportado: una sola interacción ofrece "entregar" y "cobrar" a la vez, sin relación
con el estado real de cocina.

**Razón de la causa**: Cuando se introdujo el módulo de Cocina (specs 149-151), este
camino de cobro de sesión no fue actualizado para distinguir tenants con el módulo activo
de los que no lo tienen; siguió aplicando la regla vieja ("todo debe entregarse antes de
cobrar") sin excepción.

**Fix**: `ensureReadyToCharge` debe consultar si el tenant tiene el módulo de Cocina activo
(mismo flag que ya usa `canDeliverOrder`/`canSendToKitchen`, `has_module_access`/
`cocinaAccess`). Si lo tiene, **no** debe disparar el diálogo "Entregar y cobrar" ni llamar
a `deliverOrder` antes de cobrar — el cobro debe proceder directamente (FR-001, FR-003). Si
no lo tiene, el comportamiento actual se mantiene sin cambios (FR-006).

## 3. Dónde insertar el envío automático a cocina tras el cobro

**Decisión**: El envío a cocina se dispara en el backend, dentro de (o inmediatamente
después de, en la misma transacción lógica de) `_charge_session`
(`table_sessions/service.py:328`), tras confirmar que el pago deja el pedido/sesión en
`payment_status=='PAID'` **y** que el tenant tiene el módulo de Cocina activo. Para cada
pedido de la sesión recién liquidado y asociado a una mesa, se invoca el mismo mecanismo
que ya usa `send_to_kitchen` (`app/api/v1/orders/kitchen.py:145`) — validar
`kitchen_status IS NULL` (idempotencia) y `payment_status=='PAID'`, luego fijar
`kitchen_status='SIN_PREPARAR'` y `sent_to_kitchen_at`.

**Razón**: `send_to_kitchen` ya implementa exactamente la transición de estado que FR-001
necesita (incluida la idempotencia que evita duplicar el ticket si ya fue enviado); no se
necesita un mecanismo nuevo, solo invocar el existente desde el punto correcto, gateado por
el módulo activo.

**Alternativas consideradas**:
- Exponer esto solo como un paso manual adicional del frontend (llamar a `charge()` y
  luego, por separado, al endpoint `send-to-kitchen`) — descartado: rompe la atomicidad
  exigida por FR-001 ("una sola acción") y deja una ventana donde un pedido pagado aún no
  está en cocina si el segundo request falla o el usuario cierra la pantalla.
- Reutilizar literalmente `checkout_and_send` (la ruta de pedidos manuales de mostrador) —
  descartado: esa función solo encadena venta + descuento de inventario; **no** encadena
  pago + envío a cocina ni siquiera para pedidos manuales con mesa (confirmado en la
  investigación: para pedidos con mesa, `checkout_and_send` deja `kitchen_status=NULL`).
  Por tanto no hay una función existente de "pagar pedido de mesa + enviar a cocina" para
  copiar; se construye como una extensión de `_charge_session`.

## 4. Cómo determinar "100% pagado" para cuenta dividida antes de enviar a cocina

**Decisión**: Se usa el estado de pago ya persistido por `OrderPaymentAttempt`
(`checkout.py:1351 approve_payment_attempt`, `:1858 confirm_cash_payment_attempt`) que
determina `payment_status` del pedido/sesión. El envío a cocina (paso 3) solo se dispara
cuando, tras procesar el cobro que acaba de completarse, **todos** los pedidos de la sesión
alcanzan `payment_status=='PAID'` — no hay que construir un cálculo nuevo de "porcentaje
pagado": basta con el mismo chequeo de `payment_status` por pedido que ya usa
`send_to_kitchen` individualmente, aplicado a cada pedido de la sesión en el momento del
cobro.

**Razón**: El spec (clarification 2) exige que, mientras quede alguna parte de la cuenta
dividida sin cobrar, ningún pedido se envíe a cocina. Como `send_to_kitchen` ya rechaza
pedidos que no estén en `PAID` (409 `ORDER_NOT_PAID`), aplicar la misma llamada a cada
pedido de la sesión después de cada cobro parcial es automáticamente seguro: los pedidos
aún no pagados simplemente no se envían (o la llamada se omite para ellos), y los que sí
alcanzan `PAID` se envían exactamente cuando corresponde.

**Nota de implementación frontend**: `session-bill-panel.component.ts` hoy hardcodea
`billing_mode: 'unified'` (el split por comensal fue retirado en spec 046); el flujo real
de "cuenta dividida" para pedidos QR corre por `OrderPaymentAttempt` (pagos parciales desde
la app del cliente), no por este componente. El frontend no necesita calcular "100%
pagado": solo recarga el estado del pedido/sesión tras cada aprobación de pago, y el
backend decide cuándo enviar a cocina.

## 5. Guard de `kitchen_status==='LISTO'` en `deliver_order` (backend)

**Decisión**: Añadir a `deliver_order` (`kitchen.py:89-141`) la misma validación que ya
aplica `canDeliverOrder` en el frontend (`order-status.util.ts:281`): si el tenant tiene el
módulo de Cocina activo y el pedido tiene `dining_table_id`, exigir
`kitchen_status=='LISTO'` antes de permitir la entrega (409 si no lo está). Si el tenant no
tiene el módulo activo, no se exige nada nuevo (se mantiene la validación actual, solo
`status != 'cancelada'`).

**Razón**: FR-004 exige esta regla; hoy solo existe en el frontend, lo que la hace evitable
por cualquier otro cliente de la API o por una condición de carrera. La constitución
(Principio X, Verificación Obligatoria) exige que el criterio de aceptación se cumpla de
forma verificable, no solo en la UI.

**Alternativas consideradas**: Dejarlo solo en el frontend (status quo) — descartado por el
motivo anterior; es defensa en profundidad de bajo costo que ya tiene la lógica equivalente
escrita y probada en TypeScript, solo se traslada al backend.
