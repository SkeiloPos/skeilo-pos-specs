# Contracts: Métodos distintos en pago mixto e ingresos de caja por método de pago

**Spec**: [spec.md](./../spec.md) | **Data model**: [data-model.md](./../data-model.md)

Todos los endpoints ya existen (`pos-backend/app/api/v1/sales/`, `app/api/v1/orders/`,
`app/api/v1/cash/`); esta spec no agrega rutas nuevas, solo cambia la validación y la respuesta de
las que ya hay.

## US1 — Cobro de pedido / venta de mostrador (sin cambio de ruta ni de forma del body)

Afecta por igual a:

- `POST /sales` (`SaleCreate.payments`)
- `POST /orders/{order_id}/pay` (`PayIn.payments`)
- `POST /orders/{order_id}/checkout-and-send` (`CheckoutAndSendIn.payments`)

**Body**: sin cambios de forma — sigue siendo `payments: list[PaymentIn]` (`max_length=3`,
`PaymentIn = {payment_method_id, amount, reference?}`).

**Cambio de comportamiento**: si dos o más elementos de `payments` tienen el mismo
`payment_method_id`, la respuesta pasa de `200/201` (válida, spec 112/A-124) a:

```
422 Unprocessable Entity
{
  "detail": "El método de pago «Nequi» no puede usarse en más de una línea de este cobro."
}
```

Ningún `Payment`, `Sale`, `SaleItem` ni factura se crea cuando esto ocurre (mismo comportamiento
transaccional que el resto de rechazos de `build_sale`, p. ej. "El pago no cubre el total").

**Sin cambios**: el rechazo por exceder 3 líneas (`max_length=3`, `422` de Pydantic, sin llegar a
`build_sale`), la suma exacta contra el total, el cálculo de vuelto solo-efectivo, la referencia
opcional por línea no efectivo.

## US2/US3 — Movimientos de caja

### `POST /cash/shifts/{shift_id}/movements`

**Body — compatibilidad (sin cambio respecto a hoy)**:

```json
{ "kind": "ingreso", "amount": 50000, "category": "Aporte turno", "description": "..." }
```

Se interpreta como 1 línea en efectivo — comportamiento idéntico al actual (FR-009). Igual para
`kind` `egreso`/`retiro` (sin cambio alguno, FR-012).

**Body — nuevo, solo para `kind: "ingreso"`**:

```json
{
  "kind": "ingreso",
  "category": "Aporte turno",
  "description": "Préstamo del dueño",
  "lines": [
    { "payment_method_id": "<uuid-nequi>", "amount": 30000 },
    { "payment_method_id": "<uuid-efectivo>", "amount": 20000 }
  ]
}
```

- `lines` acepta 1 o 2 elementos. Con 1 elemento, el método puede ser cualquiera activo del
  tenant (no solo efectivo) — es el caso de US2.
- Con 2 elementos, ambos `payment_method_id` deben ser distintos — es el caso de US3.
- `amount`/`lines` son mutuamente excluyentes; falta ambos o sobran los dos → `422` de schema.
- `kind` `egreso`/`retiro` con `lines` presente → `422` ("Los egresos y retiros solo admiten
  efectivo.") — FR-012.
- `lines` con 2 elementos y el mismo `payment_method_id` en ambos → `422` ("El método de pago
  «Efectivo» no puede usarse en más de una línea de este ingreso.") — FR-006, mismo criterio de
  mensaje que US1.
- Cualquier `payment_method_id` que no exista o no esté `active` en el tenant → `422` (ya es el
  comportamiento de `get_or_404`/validación existente para FKs de método de pago en otras rutas).
- Turno cerrado (`shift.status != "open"`) → `409`, sin cambios (FR-010).

**Respuesta — cambio de forma**:

Antes: un objeto `CashMovementResponse`. Ahora: `list[CashMovementResponse]` (1 elemento para el
caso de 1 línea o para egreso/retiro; 2 elementos, con el mismo `group_id`, para un ingreso
mixto):

```json
[
  { "id": "...", "cash_shift_id": "...", "kind": "ingreso", "amount": 30000,
    "payment_method_id": "<uuid-nequi>", "group_id": "<uuid-evento>",
    "category": "Aporte turno", "description": "Préstamo del dueño",
    "user_name": "Ana", "occurred_at": "2026-10-25T18:03:00Z" },
  { "id": "...", "cash_shift_id": "...", "kind": "ingreso", "amount": 20000,
    "payment_method_id": "<uuid-efectivo>", "group_id": "<uuid-evento>",
    "category": "Aporte turno", "description": "Préstamo del dueño",
    "user_name": "Ana", "occurred_at": "2026-10-25T18:03:00Z" }
]
```

### `GET /cash/shifts/{shift_id}/movements`

Sin cambio de ruta ni de cardinalidad (ya devolvía una lista). Cada `CashMovementResponse` gana
`payment_method_id` y `group_id` (ver data-model.md). Dos filas del historial con el mismo
`group_id` corresponden al mismo evento de ingreso mixto (FR-011) — el frontend las agrupa
visualmente por ese campo, sin necesidad de un endpoint nuevo.

### `GET /cash/shifts/{shift_id}/reconcile` (y cualquier otra ruta que exponga
`ReconciliationResponse`: cierre de turno, reporte de cierre)

**Cambio de comportamiento**: `ingresos` (el término que entra en `expected`) ya no incluye
ingresos registrados en un método distinto a efectivo (FR-007) — `expected` para un turno con
ingresos mixtos puede ser menor que antes de esta spec si ese turno tuviera ingresos no-efectivo
(antes todos sumaban; imposible antes de esta spec, porque no existía el campo de método).

**Cambio de forma**: nuevo campo `ingresos_by_method: list[SalesByMethod]` (mismo DTO que
`sales_by_method`: `method_id, method_name, method_type, total, count`) — una fila por método
`is_cash=False` con al menos un ingreso en el turno (FR-008). Sin ceros rellenados (a diferencia
de `sales_by_method`).

### `GET /sales/payment-methods?available=true` (reutilizado, sin cambios)

El modal de movimientos de caja (`pos-heladeria`) reutiliza este endpoint ya existente (el mismo
que alimenta `PaymentInputComponent.methods`) para poblar el selector de método del formulario de
"Registrar ingreso" — no se agrega un endpoint de catálogo nuevo.
