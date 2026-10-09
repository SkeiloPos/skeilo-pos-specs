# Contrato: `GET /products/{id}` — receta y grupos de opciones embebidos por variante

Ámbito: `pos-backend`, endpoint **ya existente**
(`app/api/v1/products/router.py:61-66`, función `get_product`) — este documento fija su forma
**ampliada**, no un endpoint nuevo. Mismo path, mismo método, misma autenticación
(`Depends(get_current_user)`, sin cambios).

## Petición

```text
GET /products/{id}
```

Sin parámetros nuevos. El campo que determina el contenido de `recipe` es el **rol de quien hace
la petición**, no un query param (research.md D3).

## Respuesta — forma ampliada

Mismo `ProductDetailResponse` de siempre, con `variants[]` ahora en forma `VariantDetailResponse`
(ver `data-model.md`):

```jsonc
{
  "id": "...", "category_id": "...", "category_name": "Postres fríos", "name": "Cono doble",
  "description": null, "preparation_type": "prepared", "image_url": null,
  "active": true, "available": true, "available_changed_at": null, "available_changed_by_name": null,
  "tracks_inventory": true, "created_at": "...", "updated_at": null,
  "variants": [
    {
      "id": "v1", "product_id": "...", "sku": null, "price": "8000.00", "active": true,
      "presentation_id": "p-grande", "presentation_name": "Grande", "name": "", "display_name": "Grande",
      "recipe": [
        { "id": "r1", "inventory_item_id": "i1", "quantity": "1.000" }
      ],
      "option_groups": [
        { "id": "og1", "product_variant_id": "v1", "option_group_id": "sabores", "min_select": 1, "max_select": 1, "quantity_per_option": "0.000" }
      ]
    }
  ],
  "deactivated": [
    { "id": "v9", "product_id": "...", "sku": null, "price": "7000.00", "active": false,
      "presentation_id": "p-mediano", "presentation_name": "Mediano", "name": "", "display_name": "Mediano" }
  ]
}
```

`deactivated` (ajuste posterior — research.md D6, 2026-10-08): mismo `VariantResponse` de
siempre, **sin** `recipe`/`option_groups` (una variante desactivada no los necesita mientras
siga desactivada — se piden por separado solo si se restaura, ver Escenario 5 de
`quickstart.md`). Reemplaza, para `getProductDraft()`, la necesidad de llamar a `GET
/products/{id}/variants` solo para esto.

## Respuesta para rol Cajero — `recipe` siempre vacío, `option_groups` sin cambios

```jsonc
{
  "...": "... (igual que arriba) ...",
  "variants": [
    {
      "...": "... (igual que arriba) ...",
      "recipe": [],
      "option_groups": [
        { "id": "og1", "product_variant_id": "v1", "option_group_id": "sabores", "min_select": 1, "max_select": 1, "quantity_per_option": "0.000" }
      ]
    }
  ]
}
```

| Rol de quien pide | `recipe` | `option_groups` |
|---|---|---|
| Admin | Poblado (igual que `GET /variants/{id}/recipe` para esa variante) | Poblado |
| Mesero (o cualquier otro rol que no sea Cajero) | Poblado | Poblado |
| Cajero | `[]`, siempre | Poblado (igual que hoy en `GET /variants/{id}/option-groups`) |

## Lo que NO cambia

- El router, la autenticación (`get_current_user`) y el status code — cero cambios de contrato
  para quien hoy solo lee los campos que `ProductDetailResponse` ya tenía antes de esta spec
  (`category_name`, `tracks_inventory`, etc.) ni para `variants[].{id,product_id,sku,price,active,
  presentation_id,presentation_name,name,display_name}` — los campos nuevos son **aditivos**.
- `GET /variants/{id}/recipe` y `GET /variants/{id}/option-groups`
  (`app/api/v1/catalog/router.py:189-222`) — siguen existiendo, mismas reglas de autorización
  (`forbid_cashier` / `get_current_user`), mismo shape de respuesta. Los reutiliza
  `restoreVariant()` del frontend para una sola variante puntual (spec 102, FR-006 de esta spec).
- `GET /products/{id}/variants` (sin filtro `active`) — el endpoint en sí sigue sin cambios: sigue
  sin incluir receta ni grupos de opciones. Lo que sí cambió (D6) es que `getProductDraft()` **ya
  no lo llama** para listar las desactivadas — usa el nuevo campo `deactivated` de esta misma
  respuesta. El endpoint sigue existiendo para otros consumidores que necesiten refrescar la lista
  completa de variantes sin volver a pedir el detalle del producto entero.
- `GET /menu` — sin cambios; nunca ha expuesto receta ni se le agrega ahora.
