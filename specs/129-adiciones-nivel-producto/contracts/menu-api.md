# Contrato: `menu` API (menú QR) — exclusión de adiciones y selector de personalización

Extiende `app/api/v1/menu/router.py` (`_build_menu`) y `app/api/v1/menu/schemas.py`. Sin rutas
nuevas: `GET /menu` y `GET /menu/qr-token/{token}` cambian de forma (FR-008/FR-009), no de firma.

## Filtro de productos visibles (FR-008, FR-010, FR-012)

`_build_menu(..., only_visible_en_qr=True)` (único caller: el flujo firmado del comensal,
`menu_by_signed_qr`, igual que hoy filtra por `Category.visible_en_qr`) agrega la condición de
producto:

```text
Category.active AND Category.visible_en_qr
  AND Product.active AND Product.available AND Product.visible_en_qr
```

Efecto: una adición (`is_topping=true`), con `visible_en_qr=false` por defecto desde que se crea
(research.md D6), nunca aparece como tarjeta ni como resultado de búsqueda del menú QR — sin
necesitar ninguna condición específica sobre `is_topping` en el propio filtro: el filtro ya
existente sobre `visible_en_qr` es suficiente porque el default se calculó así al crearla.

El caller sin firmar (`menu`, catálogo genérico del local, `only_visible_en_qr=False`) no cambia:
sigue mostrando todo lo activo, exactamente como antes de esta spec, porque no es el flujo que
limita lo que un comensal puede pedir por su cuenta.

## Selector de adiciones disponibles al personalizar (FR-009, FR-018)

`MenuProductResponse` (`app/api/v1/menu/schemas.py`) gana un campo nuevo, hermano de
`option_groups` (que sigue existiendo sin cambios, para sabores):

```jsonc
{
  "id": "...",
  "name": "Granizado",
  "variants": [ /* sin cambios */ ],
  "option_groups": [ /* grupos de sabores existentes, sin cambios — research.md D1 */ ],
  "toppings": [
    {
      "id": "<product_id de la adición>",
      "name": "Gomitas",
      "unit_price": "2000.00",
      "available": true
    }
  ]
}
```

- `toppings`: lista derivada de `ProductTopping` para ese producto, uniendo con el producto-
  adición y su variante principal (research.md D5) para `name`/`unit_price`.
- `unit_price`: precio de catálogo de la variante principal de la adición (FR-017 — nunca un
  recargo propio del producto que la ofrece).
- `available`: `false` si la adición está `active=false`, `available=false` (agotada), o su stock
  de receta no alcanza — mismo criterio de disponibilidad ya aplicado a cualquier producto/opción
  del menú (`_option_availability`/chequeo de `check_availability`), reutilizado tal cual sobre la
  variante principal de la adición.
- No se incluye ningún campo de cantidad máxima nueva: el comensal elige cuántas unidades agregar
  (FR-018) sin tope propio de esta spec — un tope, si el negocio lo pide, sería una spec futura
  (consistente con que `ProductTopping` no tiene columnas de límite, data-model.md).

## Envío del pedido / validación de carrito (Edge case, FR-014)

Al consolidar el carrito (`cart/service.py`, mismo paso que hoy rechaza un producto de una
categoría oculta en QR — spec 128, US2), se agrega la misma validación para
`CartItemTopping.topping_product_variant_id`: si el `product_id` de esa variante ya no aparece en
`ProductTopping` para el `product_id` de la línea a la que está adjunta, se quita esa adición del
carrito y se informa al comensal, sin bloquear el resto del pedido — mismo mensaje y mismo patrón
de respuesta que spec 128.
