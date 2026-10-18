# Quickstart: validar Confirmación Única de Pago

**Spec**: [spec.md](spec.md) | **Contratos**: [contracts/](contracts/)

Guía para comprobar, de punta a punta, que la funcionalidad cumple los escenarios de aceptación
de la spec. No repite código de implementación — solo pasos y resultados esperados.

## Prerrequisitos

- Backend: `cd ../pos-backend && uvicorn app.main:app --reload`.
- Frontend: `cd ../pos-heladeria && ng serve`.
- Dos pestañas/navegadores con sesión de cajero del **mismo tenant** (terminal A y terminal B),
  con un turno de caja abierto en ambas.
- Un pedido de mostrador o de mesa listo para cobrar (creado con `hold_for_payment=true`, o una
  mesa con consumo registrado).

## 1. Cobro exitoso con una sola confirmación (Historia 1, SC-001/SC-002)

1. En la terminal A, cobrar un pedido de $22.000 en efectivo con $50.000 recibidos.
2. **Esperado**: aparece un único modal "Pago registrado" con el monto, el cliente
   ("Consumidor Final" si no se indicó otro), el método de pago ("Efectivo") y el vuelto
   ("Vuelto $ 28.000"). Ningún toast adicional aparece en la terminal A (ni "Pago recibido...", ni
   "Pedido cobrado, facturado y enviado a cocina").
3. Repetir cobrando con un método distinto a efectivo (p. ej. tarjeta): el modal muestra monto,
   cliente y método, **sin** ninguna línea de vuelto.

## 2. Otra terminal sigue notificada en tiempo real, con el formato correcto (Historia 2, SC-003)

1. Con la terminal B abierta en otra sección del POS (no necesariamente Terminal de Mesas),
   cobrar desde la terminal A un pedido de $22.000.
2. **Esperado**: en la terminal B aparece, en pocos segundos, el toast "Pago recibido · $ 22.000"
   (con el espacio y el punto de miles correctos) — y la terminal A no muestra ese mismo toast
   (solo su modal del paso 1).
3. Verificar en la pestaña de red de la terminal A que el evento SSE `notification.created` de
   ese cobro sí llega (`GET /realtime/stream`), pero no genera toast — confirma que el
   silenciamiento ocurre en el frontend por comparación de `origin_client_id`, no porque el
   backend deje de emitirlo.

## 3. Fallo al registrar el pago (Historia 3, SC-004)

1. Provocar un error del backend al cobrar (p. ej. desconectar la red justo antes de confirmar, o
   cobrar con `version` desactualizado para forzar un `409`).
2. **Esperado**: no aparece el modal "Pago registrado"; aparece un único mensaje de error con el
   motivo; los campos ya diligenciados en el formulario de cobro (método, monto recibido, cliente)
   siguen ahí, listos para reintentar sin volver a escribirlos.

## 4. Imprimir o cerrar desde la confirmación (Historia 4)

1. Con el modal "Pago registrado" visible tras un cobro de un solo comprobante, seleccionar
   "Imprimir Factura".
2. **Esperado**: se abre el diálogo de impresión del navegador con la factura del cobro recién
   registrado, y el modal se cierra.
3. Repetir el cobro y, en su lugar, seleccionar "Cerrar": el modal se cierra sin abrir ningún
   diálogo de impresión.

## 5. Regresión: cuenta dividida y pago mixto no se rompen

1. Cobrar una mesa con "Dividir la cuenta" (varios comensales): el modal sigue mostrando el
   resumen agregado y el botón "Imprimir todos" (sin cambios de esta spec).
2. Cobrar un pedido con dos métodos de pago (efectivo + transferencia, spec 112): el modal
   muestra el método de pago como "Efectivo + Transferencia" (unión de ambos), y el vuelto solo
   si la porción en efectivo generó vuelto.
3. Cobrar el saldo pendiente de un pago complementario (spec 123, "Cobrar saldo"): sigue
   mostrando únicamente su toast propio "Saldo pendiente cobrado" — esta spec no le cambia nada
   (research.md R4).
