# Contrato: Pago mixto del comensal (FR-004 a FR-008)

Extiende los endpoints ya existentes del Menú QR (spec 025/032/034) — ningún endpoint nuevo.

## `GET /cart/payment-methods`

Sin cambio de forma. "Pago mixto" aparece en la lista de `DinerPaymentMethod` cuando el tenant lo
activó (ver data-model.md) — el comensal lo distingue de los demás por un campo de tipo ya
presente en el payload (a confirmar nombre exacto en `/speckit-tasks`: hoy el frontend decide el
ícono con `m.is_cash`; para "Pago mixto" ninguna de las dos banderas binarias actuales basta, así
que el payload necesita exponer el `type` del catálogo, o una tercera bandera `is_mixed`, no solo
`is_cash`).

## `POST /cart/submit`

**Request (`SubmitCartIn`) — campos nuevos, opcionales**:

```json
{
  "payment_method_id": "<uuid del método 'Pago mixto' del tenant>",
  "receipt_file_url": "<url del comprobante de la porción por transferencia>",
  "cash_amount": "<decimal > 0 y < total>",
  "transfer_method_id": "<uuid del método de transferencia real elegido, obligatorio si el tenant tiene más de uno activo>"
}
```

- Si `payment_method_id` no apunta a un método `type='mixed'`: `cash_amount`/`transfer_method_id`
  deben venir `null` (o ausentes) — comportamiento exactamente igual al actual para efectivo/
  transferencia puros, sin cambios.
- Si `payment_method_id` apunta a `type='mixed'`:
  - `cash_amount` es obligatorio; `422` si es `null`, `<= 0`, o `>=` el total del pedido (FR-006,
    con el mensaje orientando a elegir "Efectivo").
  - `receipt_file_url` es obligatorio (mismo requisito que hoy para transferencia pura, FR-007).
  - `transfer_method_id` es obligatorio solo si el tenant tiene más de un método de transferencia
    activo; si tiene exactamente uno, se resuelve automáticamente si se omite (FR-005).

**Response**: sin cambio de forma — el pedido creado expone su `current_payment_attempt` con el
desglose (ver `OrderResponse`/`PaymentAttemptResponse`, a extender en `/speckit-tasks` con
`cash_amount`, `transfer_amount`, `cash_confirmed_at` para que "Mis pedidos" y la confirmación
(FR-008) puedan mostrarlos).

## `POST /payment-attempts/{id}/confirm-cash` (cajero, Terminal de Mesas)

Sin cambio de firma. Nuevo comportamiento condicional (research.md Decisión 4): si el intento es
mixto (`cash_amount IS NOT NULL`), esta llamada fija `cash_confirmed_at` en vez de `status`; la
orden solo avanza a cocina si, además, `status` ya es `confirmado`. Si el intento no es mixto,
comportamiento idéntico al actual (fija `status='confirmado'` y dispara el despacho a cocina).

## `POST /payment-attempts/{id}/approve` (cajero, Terminal de Mesas)

Sin cambio de firma. Nuevo comportamiento condicional: si el intento es mixto, fija
`status='confirmado'` pero la orden solo avanza a cocina si, además, `cash_confirmed_at` ya tiene
valor. Si el intento no es mixto, comportamiento idéntico al actual.

**Fuera de alcance de esta spec**: la UI de la Terminal de Mesas que permite al cajero ejecutar
estas dos acciones sobre un intento mixto (research.md Decisión 4) — los endpoints cambian de
comportamiento, pero su exposición en pantalla es seguimiento de spec 112.

## Activación de "Pago mixto" en el catálogo del tenant (spec 032)

Endpoint existente de activación por tenant (ruta exacta a confirmar en `/speckit-tasks`, módulo
`payment_methods` de spec 032). Nueva validación (FR-004): rechaza con `409`/`422` si
`catalog.type == 'mixed'` y el tenant no tiene ya activos al menos un método `type='cash'` y al
menos uno `type='transfer'`, con un mensaje que explique ambos requisitos.
