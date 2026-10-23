# Contrato de API: Intentos de pago (`/orders/...`)

**Spec**: [spec.md](./spec.md) | **Base existente**: spec 024/130, `app/api/v1/orders/router.py`

Todos los endpoints requieren usuario autenticado del tenant (cajero/staff), salvo donde se
indique lo contrario. Los montos son enteros en COP (FR-006).

## Endpoints existentes, con comportamiento modificado

### `POST /orders/payment-attempts/{attempt_id}/approve`

Sin cambio de firma. **Cambio de comportamiento** (FR-012, Decisión 1): ya no exige
`receipt_file_url`. Sigue retornando `409` si el intento no está `pendiente` o si el método es
efectivo (debe usarse `confirm-cash`).

### `POST /orders/payment-attempts/{attempt_id}/reject`

```json
// Request body (PaymentAttemptRejectIn)
{
  "reason": "cliente_no_muestra_app"  // enum cerrado, FR-015
}
```

**Cambio de comportamiento**: `reason` deja de ser texto libre; valores aceptados:
`cliente_no_muestra_app`, `monto_no_coincide`, `transferencia_no_completada`,
`cliente_se_niega_a_mostrar`, `comprobante_sospechoso`. `422` si el valor no pertenece al
conjunto. Efecto adicional (FR-020): si es el segundo rechazo del día para la misma mesa,
escribe también un `AuditLog(action="payment.table_repeat_rejection")` — no cambia la
respuesta ni el código de estado.

### `POST /orders/payment-attempts/{attempt_id}/confirm-cash`

Sin cambio de firma ni comportamiento (ya existente, spec 024/130).

## Endpoint nuevo

### `POST /orders/payment-attempts/{attempt_id}/adjust-split`

Reajusta la división efectivo/transferencia de un intento `pendiente` al momento de
confirmar (FR-013/014), incluyendo convertir un intento 100% transferencia en mixto o en 100%
efectivo, y viceversa.

**Request**:
```json
{
  "cash_amount": 20000,            // entero COP, >= 0
  "transfer_amount": 30000,        // entero COP, >= 0
  "transfer_method_id": "uuid",    // requerido si transfer_amount > 0
  "payment_method_id": "uuid"      // opcional; solo si cambia el método primario del intento
}
```

**Reglas de validación**:
- `cash_amount + transfer_amount == total del pedido` del que depende este intento (FR-013);
  si no, `409` con mensaje claro ("La suma de efectivo y transferencia no coincide con el
  total del pedido").
- Solo permitido si `attempt.status == 'pendiente'`; si no, `409` ("El intento ya fue
  resuelto").
- Si `cash_amount == 0`, equivale a transferencia total: `transfer_method_id` requerido,
  `transfer_amount == total`.
- Si `transfer_amount == 0`, equivale a efectivo total: el intento pasa a confirmarse
  únicamente vía `confirm-cash` después de este ajuste.

**Efectos**:
- Actualiza `cash_amount`, `transfer_amount`, `transfer_method_id` y, si se envía,
  `payment_method_id` del intento.
- Escribe `AuditLog(action="payment_attempt.split_adjusted", entity="order_payment_attempts",
  entity_id=attempt.id, user=<cajero>, payload={cash_amount_antes, transfer_amount_antes,
  cash_amount_despues, transfer_amount_despues})` (FR-014).
- No cambia `status`; la confirmación sigue requiriendo `approve` y/o `confirm-cash` según la
  nueva división.

**Response**: `PaymentAttemptResponse` (mismo esquema de serialización ya existente).

## Endpoint nuevo (consulta)

### `GET /orders/{order_id}/payment-events`

Historial de auditoría consultable del pedido (FR-019; US4/US5 Acceptance Scenarios de
consulta de historial). Devuelve las filas de `AuditLog` donde
`entity IN ('order_payment_attempts', 'customer_orders')` y `entity_id` corresponde a algún
intento de pago de esa orden o a la orden misma, ordenadas por `at` ascendente.

```json
[
  {
    "action": "payment_attempt.rejected",
    "entity": "order_payment_attempts",
    "entity_id": "uuid",
    "user_name": "Cajero Juan",
    "at": "2026-10-23T14:05:00Z",
    "payload": {"motivo": "monto_no_coincide"}
  }
]
```

## Flujo de QR del comensal: contrato eliminado

**FR-023**: se elimina del flujo del comensal cualquier endpoint de presign/upload de
comprobante asociado a la creación de un intento de transferencia o mixto desde el QR. La
creación del intento (`POST /orders/{order_id}/payment-attempts` o equivalente ya existente en
`checkout.py`) deja de requerir ni aceptar `receipt_file_url` en el body cuando el actor es el
comensal; ese campo solo puede llegar a través de los endpoints de cajero (`approve`,
`adjust-split`) descritos arriba.
