# Contrato — Regla de pricing/consumo para grupos "Por cantidad" (D1, D7)

**Afecta a**: todo endpoint que arma o lee una línea con opciones elegidas. No cambia la **forma**
de ningún request/response (ningún campo nuevo, ningún campo eliminado); cambia el **valor** que
esos campos devuelven cuando la línea tiene adiciones de un grupo `selection_mode = 'cantidad'`.

## Regla

```
per_line(chosen_option) =
    (option_group.pricing_type == 'con_recargo' AND canal == carrito_QR AND QR_ADDONS_PER_LINE)
    OR (option_group.selection_mode == 'cantidad')
```

`per_line = True` para una opción ⇒ su `extra_price × quantity` entra en `addons_total` de la
línea (no en `unit_price`) y su consumo de inventario es `per_unit × quantity` (no
`per_unit × quantity_producto × quantity`). Ningún otro componente de la fórmula cambia:

```
unit_price   = precio_presentación + Σ(extra_price × quantity)   [opciones con per_line = False]
addons_total = Σ(extra_price × quantity)                          [opciones con per_line = True]
line_total   = unit_price × quantity_producto + addons_total
consumo      = per_unit × quantity_producto × quantity            [per_line = False]
             = per_unit × quantity                                 [per_line = True]
```

## Endpoints cuyo valor cambia (ninguno cambia de forma)

| Endpoint | Función | Qué cambia |
|---|---|---|
| `POST /cart/items` | `cart/service.py::add_item` | Adición "cantidad" fuera de QR ya existía antes de spec 089 sin tocar; ahora también separa `unit_price`/`addons_total` para ella. |
| `PATCH /cart/items/{id}` | `cart/service.py::update_item` | Igual, al reemplazar `options`. |
| `POST /orders` (alta directa de comanda) | `orders/service.py::create_order` | Pasa de `compute_line_price` "folded" a `compute_unit_price` + `compute_addons_total` por separado. |
| `POST /orders/{id}/items` (mesero agrega ítem) | `orders/consolidation.py::add_item_to_order` | Idem. |
| `POST /sales/checkout` (venta de mostrador) | `sales/service.py::checkout` | Idem; `SaleLine`/`SaleItem.line_total` reflejan el total correcto desde el momento del cobro (no hay recálculo posterior). |
| Reemplazo de ítem anulado | `orders/kitchen.py` (`void_item` con `replacement`) | Idem. |
| `GET /orders/{id}/checkout-preview` | `orders/checkout.py::compute_checkout_preview` | Lee el snapshot ya corregido (sin cambio de código en este endpoint: consumidor de los anteriores). |
| `POST /orders/{id}/payment-attempts/{attempt_id}/confirm-cash` y `.../approve` | `confirm_cash_payment_attempt`, `approve_payment_attempt` | Validan contra el total ya corregido — esta es la superficie "Pagos por confirmar" (`FR-011`). |

## Qué NO cambia

- Ninguna línea con solo opciones `selection_mode = 'conteo'` cambia de resultado en ningún canal
  (`FR-013`) — la condición 089 (pricing_type/canal QR) sigue intacta y sin modificar.
- Ninguna línea histórica (creada antes del despliegue) se recalcula — sus columnas `per_line` ya
  persistidas no se reescriben (Principio VII).
- La forma de `CartItemResponse`, `OrderItemResponse`, `SaleLine`, el JSONB `SaleItem.options` no
  gana ni pierde ningún campo por este contrato (sí por el de
  [cart-item-auto-adjust.md](./cart-item-auto-adjust.md), que es un contrato distinto).

## Ejemplo (Historia 1, Escenario 1)

`POST /cart/items` con `{"product_variant_id": "...", "quantity": 2, "options": [{"option_id":
"<gomitas>", "quantity": 1}]}`, donde "gomitas" pertenece a un grupo `selection_mode = 'cantidad'`
y su presentación cuesta `$18.000`, la opción `$1.000`:

Antes de esta spec (bug): `unit_price = 18.000 + 1.000 = 19.000`, `line_total = 19.000 × 2 =
38.000`.

Después de esta spec: `unit_price = 18.000`, `addons_total = 1.000`, `line_total = 18.000 × 2 +
1.000 = 37.000`.
