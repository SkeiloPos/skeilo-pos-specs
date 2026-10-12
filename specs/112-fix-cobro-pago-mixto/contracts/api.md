# Contratos: Cobro de pedido con múltiples métodos de pago

No hay endpoints nuevos. Los tres endpoints de cobro ya existentes aceptan `payments` como lista
desde spec 011; este fix solo acota esa lista a un máximo de 3 elementos. El frontend ya no tiene
que cambiar de endpoint ni de forma de invocarlo — solo manda más de un elemento en `payments`.

## `POST /orders/{order_id}/pay` (mesa/mostrador, pedido ya bloqueado)

`pos-backend/app/api/v1/orders/router.py:469` → `checkout.pay_order` → `builder.build_sale`.

**Body (`PayIn`, cambio resaltado)**:

```python
class PayIn(BaseModel):
    cash_shift_id: UUID
    discount: Decimal = Field(0, ge=0, max_digits=12, decimal_places=2)
    tax: Decimal = Field(0, ge=0, max_digits=12, decimal_places=2)
    tip: Decimal = Field(0, ge=0, max_digits=12, decimal_places=2)
    payments: list[PaymentIn] = Field(..., min_length=1, max_length=3)  # ← max_length nuevo
```

**Ejemplo de request con pago mixto** (reemplaza al único `{payment_method_id, amount}` de hoy):

```json
{
  "cash_shift_id": "…",
  "payments": [
    { "payment_method_id": "…efectivo…", "amount": 10000 },
    { "payment_method_id": "…transferencia…", "amount": 6000, "reference": "4821" }
  ]
}
```

Con `total = 14000`: la línea de efectivo manda `amount = 10000` (lo recibido, no los 8000
asignados — ver `data-model.md` D3), la de transferencia manda `amount = 6000` (asignado = recibido,
porque RN2 no permite que una transferencia exceda el saldo pendiente). El servidor sigue
calculando `change_given = Σamount − total = 16000 − 14000 = 2000` sin ningún cambio de lógica.

**Response**: `SaleResponse` sin cambios — `payments` en la respuesta ya es una lista
(`Sale.payments`), por lo que un cliente que ya renderice esa lista (el recibo) no necesita tocarse.

**Errores sin cambio de contrato** (ya existían, solo se vuelven alcanzables desde la UI):

| Status | Causa | Mensaje |
|---|---|---|
| 422 | `Σ amount < total` | `El pago ({paid}) no cubre el total ({total})` |
| 422 | `Σ amount no-efectivo > total` | `Los pagos que no son en efectivo ({no_efectivo}) no pueden superar el total ({total}): el vuelto solo sale del efectivo.` |
| 422 (nuevo, por el `max_length`) | más de 3 líneas en `payments` | error de validación estándar de Pydantic/FastAPI (422, detalle `"List should have at most 3 items"`) |
| 404 | `payment_method_id` no existe | `Payment method not found` |

## `POST /orders/{order_id}/checkout-and-send` (comanda `hold_for_payment`)

`pos-backend/app/api/v1/orders/router.py:502` → `checkout.checkout_and_send` → mismo `build_sale`.
`CheckoutAndSendIn.payments` gana el mismo `max_length=3`. Mismo formato de `payments`/errores que
arriba, más `version` (lock optimista) y `billing_customer_name`, sin relación con este fix.

## `POST /sales` (mostrador directo)

`pos-backend/app/api/v1/sales/router.py:119` → `sales/service.checkout` → mismo `build_sale`.
`SaleCreate.payments` gana el mismo `max_length=3`. Mismo formato/errores. Fuera del alcance
funcional de esta spec (el mostrador no es uno de los tres tipos de pedido de la spec), pero
comparte el mismo schema `PaymentIn` y el mismo `build_sale`, así que el tope se aplica aquí
también por consistencia (research.md D7) — no introduce ningún comportamiento nuevo en el
mostrador, solo el mismo tope de 3 líneas.

## Catálogo de métodos de pago (sin cambios, ya consumido)

`GET /sales/payment-methods?available=true` (`pos-backend/app/api/v1/sales/router.py:59-82`) —
el frontend ya lo consume (`pos-heladeria/src/app/modules/sales/services/payment-method.service.ts:45`)
para poblar `methods` en `PaymentInputComponent`. Sin cambios: cada `PaymentMethodCheckoutOption`
ya trae `is_cash`, que es el único dato que la UI de pago mixto necesita para decidir si una línea
admite vuelto.

## Frontend: contrato del componente de pago (sin cambios en su interfaz pública)

`PaymentInputComponent` (o su sucesor) conserva el mismo contrato que usa
`PosCheckoutPanelComponent` hoy (`pos-checkout-panel.component.ts:334-338`), para no propagar el
cambio a su contenedor:

```ts
@Input() total = 0;
@Input() methods: PaymentMethodCheckoutOption[] = [];
@Output() changed = new EventEmitter<PaymentDraft>(); // PaymentDraft ahora es PaymentLineDraft[]
```

`paymentLines(draft: PaymentDraft, methods: PaymentMethodCheckoutOption[]): PaymentLine[]` pasa de
devolver siempre un array de 1 elemento a devolver de 1 a 3 — es la función que
`PosCheckoutPanelComponent.checkout()` ya llama al pulsar "Cobrar" (línea 588); no cambia su firma
de uso en el call site más allá de que ahora puede requerir `methods` para decidir qué campo mandar
por línea (ver `data-model.md` D3).
