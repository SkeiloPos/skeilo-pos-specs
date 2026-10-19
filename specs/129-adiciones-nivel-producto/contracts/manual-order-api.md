# Contrato: carrito (`cart`) y pedido manual (`orders`) — vender/adjuntar una adición

## Vender una adición como línea independiente (US2) — sin cambios de contrato

`POST /orders/{order_id}/items` (`add_order_item`, `OrderItemIn`) y `POST /cart/items`
(`add_item`, `CartItemIn`) ya aceptan cualquier `product_variant_id`. Agregar una adición suelta
es la misma llamada que agregar cualquier producto — el `product_variant_id` enviado es, en este
caso, el de la variante principal (o la que elija el usuario, si la adición tiene varias) del
producto marcado `is_topping=true`. El catálogo de búsqueda que alimenta este flujo
(`GET /products?search=...`) ya la incluye sin cambios (research.md D3).

## Adjuntar una adición a OTRA línea ya existente (US1/US3)

### Pedido manual / mesa (`orders`)

Nueva familia de endpoints, paralela a la ya existente `/items/{item_id}/additions` (spec 123,
que sigue intacta para adiciones configuradas con el mecanismo anterior — `OptionSelectionIn`/
`option_id`):

```text
POST   /orders/items/{item_id}/toppings
PATCH  /orders/items/{item_id}/toppings/{topping_product_id}
DELETE /orders/items/{item_id}/toppings/{topping_product_id}
```

**`ToppingSelectionIn`** (body de `POST`):

```jsonc
{ "topping_product_id": "<uuid del producto-adición>", "quantity": 2 }
```

- El servicio resuelve `topping_product_id` → su `product_variants` principal (research.md D5),
  valida que esté en `ProductTopping` para el `product_id` de la línea destino (si no, `404`), y
  crea/actualiza la fila de `OrderItemTopping` correspondiente (`unit_price` tomado del precio de
  catálogo vigente de esa variante en ese instante — snapshot, FR-017).
- `PATCH .../toppings/{topping_product_id}` (`UpdateToppingQuantityIn { quantity: int }`): mismo
  criterio que `PATCH .../additions/{option_id}` — edita solo la cantidad.
- `DELETE .../toppings/{topping_product_id}`: quita del todo la fila.
- Mismos eventos (`events.item_addon_added`, `events.bill_changed`) que la familia `additions`
  existente — el frontend solo los usa como señal de recarga.
- Mismas reglas de `added_after_sale`/`complementary_sale_id` que `additions` (spec 123): si el
  pedido ya tiene una `Sale` emitida al agregar la adición, queda marcada para pago
  complementario, reutilizando el mecanismo existente (`pay_complementary_balance`) sin tocarlo.

**Respuesta**: `OrderResponse` (igual que la familia `additions`); cada `OrderItem` expone
`toppings: list[OrderItemToppingResponse]` (hermano de `options: list[OrderItemOptionResponse]`),
con `id`, `topping_product_id`, `name` (denormalizado, mismo criterio que `OrderItemOption.name`),
`quantity`, `unit_price`.

### Carrito del comensal (`cart`, menú QR)

No se agrega una sub-ruta nueva — el carrito ya edita el árbol completo de una línea en una sola
llamada (`CartItemIn`/`CartItemUpdate`), a diferencia de `orders`. Se agrega un campo hermano de
`options`:

```jsonc
// CartItemIn / CartItemUpdate
{
  "product_variant_id": "...",
  "quantity": 1,
  "options": [ /* sabores, sin cambios */ ],
  "toppings": [
    { "topping_product_id": "<uuid>", "quantity": 2 }
  ],
  "notes": null
}
```

- `toppings: list[ToppingSelectionIn]`, mismo criterio de reemplazo total que `options` al
  editar (`CartItemUpdate.toppings: list[ToppingSelectionIn] | None` — `None` = no tocar,
  presente = reemplazo total de `CartItemTopping` para esa línea).
- Validación: cada `topping_product_id` MUST estar en `ProductTopping` del `product_id` de la
  variante de la línea → `422` en el momento de agregar/editar, `404`-equivalente en el patrón de
  carrito (consistente con cómo hoy se rechaza un `option_id` que no pertenece al grupo de la
  variante).
- `CartItemResponse` gana `toppings: list[CartItemToppingResponse]`, hermano de
  `options: list[CartItemOptionResponse]`.

### Rechazo al enviar el pedido (Edge case, FR-014)

`submit_cart` (consolidación carrito → pedido) ya valida, antes de esta spec, que las opciones de
una línea sigan siendo válidas. Se agrega la misma validación para `CartItemTopping`: si el
`topping_product_id` ya no está en `ProductTopping` del producto de la línea (lo desasoció el
administrador mientras el comensal tenía el carrito abierto), esa adición se quita de la línea y
se informa al comensal — mismo patrón de respuesta que spec 128 (categoría oculta en QR), sin
bloquear el resto del pedido.
