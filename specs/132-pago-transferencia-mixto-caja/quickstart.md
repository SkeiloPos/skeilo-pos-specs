# Quickstart: Pago por transferencia y pago mixto sin subida de comprobante

**Spec**: [spec.md](./spec.md) | **Contratos**: [contracts/payment-attempts-api.md](./contracts/payment-attempts-api.md)

Guía de validación end-to-end de las 5 historias de usuario del spec. No sustituye los tests
automatizados; es el recorrido manual/semi-manual para confirmar que el comportamiento
descrito en el spec funciona de punta a punta sobre los dos repositorios.

## Prerrequisitos

- `pos-backend`: venv activo (`source env/bin/activate`), Postgres local disponible, API
  corriendo (`uvicorn app.main:app --reload` o el comando habitual del repo).
- `pos-heladeria`: `ng serve` corriendo contra esa API.
- Un tenant de prueba con al menos un método de pago en efectivo y uno de transferencia
  configurados (`payment_methods`), y una mesa con QR activo.
- Un usuario cajero autenticado en la terminal POS.

## Escenario 1 — Transferencia 100% desde el QR (US1)

1. Desde el QR de una mesa, armar un pedido con total $50.000.
2. Elegir "Transferencia" y confirmar.
3. **Verificar**: la pantalla muestra "Transfiere $50.000" + instrucción de referencia
   (mesa/pedido), **sin ningún campo de subida de archivo**.
4. **Verificar vía API**: `GET /orders/{order_id}/payment-attempts` devuelve un único intento,
   `payment_method` = transferencia, `status = "pendiente"`, monto esperado = 50000.
5. El pedido pasa a preparación de inmediato (sin esperar la transferencia).

## Escenario 2 — Pago mixto desde el QR (US2)

1. Mismo pedido ($50.000); elegir "Pago mixto", ingresar $20.000 de efectivo.
2. **Verificar**: la pantalla muestra "Transfiere $30.000" + instrucción de referencia; sin
   subida de archivo.
3. Repetir con $0 y con $50.000 de efectivo: **verificar** que el sistema rechaza ambos con
   mensaje claro orientando a "Efectivo" o "Transferencia" (FR-005).
4. Confirmar con $20.000/$30.000. **Verificar vía API**: dos intentos (o un intento mixto con
   `cash_amount=20000`, `transfer_amount=30000` según la forma de serialización vigente) cuya
   suma de montos esperados es 50000.

## Escenario 3 — Cajero verifica y confirma en la mesa (US3)

1. Con el pedido del Escenario 1 listo, en la terminal POS, abrir el panel de revisión de
   pagos del pedido.
2. Presionar "Confirmar pago" **sin adjuntar foto**. **Verificar**: no hay error ni
   advertencia bloqueante; el intento pasa a `confirmado`; el pedido pasa a `pagada`.
3. Intentar marcar el pedido como entregado **antes** de confirmar el pago en un pedido nuevo:
   **verificar** que el sistema lo impide (FR-011).
4. Repetir con un pedido mixto: confirmar la porción transferencia (`approve`) y la porción
   efectivo (`confirm-cash`); **verificar** que el pedido solo pasa a `pagada` cuando ambas
   están confirmadas.

## Escenario 4 — Reajuste de división al confirmar (US4)

1. Tomar un pedido declarado 100% transferencia ($50.000).
2. Llamar `POST /payment-attempts/{id}/adjust-split` con `cash_amount=20000,
   transfer_amount=30000`.
3. **Verificar**: `200`, el intento queda con la nueva división; `GET
   /orders/{order_id}/payment-events` incluye un evento `payment_attempt.split_adjusted` con
   los montos antes ($0/$50000) y después ($20000/$30000).
4. Confirmar ambas porciones; **verificar** que el pedido pasa a `pagada` con la nueva
   división.
5. Repetir el ajuste con `cash_amount=10000, transfer_amount=10000` (suma ≠ total):
   **verificar** `409`.

## Escenario 5 — Rechazo y resolución (US5)

1. Rechazar un intento de transferencia sin `reason`: **verificar** `422`.
2. Rechazar con `reason="monto_no_coincide"`: **verificar** `200`, intento `rechazado`,
   pedido no entregable.
3. **Salida A (efectivo total)**: `adjust-split` a `cash_amount=total, transfer_amount=0`,
   luego `confirm-cash`. **Verificar**: pedido pasa a `pagada` y es entregable.
4. **Salida B (reintento)**: crear un nuevo intento de transferencia para la misma orden,
   aprobarlo. **Verificar**: éxito. Intentar un **segundo** reintento tras un segundo rechazo:
   **verificar** `409` orientando a las otras dos salidas (FR-017, Decisión 5).
5. **Salida C (cancelación por impago)**: cancelar el pedido con el flujo de
   `cancel_order` existente. **Verificar**: el intento pendiente queda anulado, el pedido
   queda `cancelada`, y hay un registro de auditoría (`order.cancel.loss` o equivalente) con
   el motivo distintivo de impago.
6. **Doble rechazo en la misma mesa, mismo día**: provocar un segundo rechazo sobre la misma
   mesa. **Verificar**: `GET` de auditoría muestra un evento adicional
   `payment.table_repeat_rejection`, sin que el flujo se bloquee (FR-020).
7. Para cada paso anterior, **verificar** vía `GET /orders/{order_id}/payment-events` que
   motivo, cajero y hora quedan registrados (FR-019, SC-004).

## Verificación automatizada

- Backend: `python -m unittest discover -s app/characterization_tests -p 'test_*.py' -v`
  dentro del venv — confirmar que no hay regresión en characterization tests existentes de
  spec 024/130, y agregar los tests nuevos de este spec bajo el mismo runner.
- Frontend: `ng test` — dado el baseline flaky conocido, comparar el diff de archivos
  afectados (`transfer-details-step.component`, `payment-attempt-review-panel.component`,
  `diner.service`) en vez del conteo total de la suite.
