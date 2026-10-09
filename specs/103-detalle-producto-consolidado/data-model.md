# Data Model: Consolidar receta y grupos de opciones en el detalle de producto

Sin cambios de esquema de base de datos: `Product`, `ProductVariant`, `RecipeItem`,
`VariantOptionGroup`, `OptionGroup`, `Option` (`pos-backend/app/models/`) ya existen y no ganan
columnas, tablas ni relaciones nuevas. Esta spec solo cambia **cómo se consulta** (carga ansiosa,
research.md D2) y **qué forma tiene la respuesta HTTP** de un endpoint ya existente (D1, D3).

## `VariantDetailResponse` (nuevo, `pos-backend/app/api/v1/products/schemas.py`)

Extiende `VariantResponse` (sin cambios, `catalog/schemas.py:54-67`) agregando dos campos:

| Campo nuevo | Tipo | Notas |
|---|---|---|
| `recipe` | `list[RecipeItemResponse]` (default `[]`) | Reutiliza el tipo ya existente (`catalog/schemas.py:85-90`: `id`, `inventory_item_id`, `quantity`) sin cambios de forma. Vacío si la variante no tiene insumos fijos, **o** si quien pide el detalle tiene rol Cajero (research.md D3) |
| `option_groups` | `list[VariantOptionGroupResponse]` (default `[]`) | Reutiliza el tipo ya existente (`catalog/schemas.py:115-123`: `id`, `product_variant_id`, `option_group_id`, `min_select`, `max_select`, `quantity_per_option`) sin cambios de forma. Se puebla para **todos** los roles (D3) |

`ProductDetailResponse.variants` (`products/schemas.py:114-120`) pasa de `list[VariantResponse]` a
`list[VariantDetailResponse]`. El resto de `ProductDetailResponse`/`ProductResponse` no cambia.

## `ProductDetailResponse.deactivated` (nuevo, ajuste posterior — research.md D6, 2026-10-08)

| Campo nuevo | Tipo | Notas |
|---|---|---|
| `deactivated` | `list[VariantResponse]` (default `[]`) | Mismo tipo ya existente (sin `recipe`/`option_groups` — una variante desactivada no los necesita mientras siga desactivada, FR-006), poblado con `[v for v in product.variants if not v.active]` — la misma relación ya precargada por D2, filtrada al revés de `variants` |

Este campo reemplaza, para `getProductDraft()`, la necesidad de llamar a `GET
/products/{id}/variants` solo para listar las desactivadas (research.md D6). El endpoint
`GET /products/{id}/variants` en sí **no se elimina** — sigue existiendo para otros consumidores
(ver `contracts/products-detail-embedded.md`, "Lo que NO cambia").

## Transición de la consulta de detalle (research.md D2)

```text
GET /products/{id}
        │
        ▼
select(Product).where(Product.id == id).options(
  selectinload(Product.variants).selectinload(ProductVariant.recipe_items),
  selectinload(Product.variants).selectinload(ProductVariant.option_groups),
)
        │
        ▼
to_detail_response(product, user)
        │
   ┌────┴─────┐
 variante     variante
 activa       activa
   │             │
   ▼             ▼
VariantDetailResponse       VariantDetailResponse
  recipe: user.role != CASHIER ? [...] : []
  option_groups: [...] (siempre)
```

Las variantes **inactivas** del producto no entran en `product.variants` filtrado por
`to_detail_response` (`if v.active`, ya existente) — sin cambios: siguen sin aparecer en esta
respuesta, igual que antes de esta spec.

## Transición de `getProductDraft()` en el frontend (research.md D4, ajustado por D6)

```text
getProductDraft(id)
        │
        └──> GET /products/{id}   (incluye variants[] activas, con recipe/option_groups;
                                    incluye deactivated[] — D6)
                     │
                     ▼
        draft.variants = variants[] (ya con recipe/option_groups embebidos)
        draft.deactivated = deactivated[] (D6 — sin petición adicional)
```

Una sola petición total, sin importar cuántos tamaños tenga el producto ni cuántos estén
desactivados (antes de D4: `2 + 2N`, con N = número de tamaños activos; tras D4 y antes de D6:
2 peticiones fijas). `ProductService.loadVariants()`/`loadDeactivated()` siguen existiendo sin
cambios — dejan de ser llamados por `getProductDraft()`, pero quedan disponibles para otros
puntos del formulario que necesiten refrescar la lista completa de variantes. El flujo de
restaurar una variante (`ProductFormComponent.restoreVariant()`, que llama a
`service.getVariantRecipe()`/`service.getVariantOptionGroups()` — envoltorios de
`fetchVariantRecipeRaw`/`fetchVariantOptionGroupsRaw`) no cambia: sigue pidiendo receta/grupos de
una sola variante puntual al restaurarla (FR-006), sin relación con `loadVariants()`.

## Qué se retira (research.md D5)

| Elemento | Dónde vivía | Por qué se retira |
|---|---|---|
| `VariantDraft.loadError` | `product.interface.ts` | Ningún camino de código puede volver a ponerlo en `true` tras D4 |
| `ProductFormComponent.retryVariantLoad()` | `product-form.component.ts` | Sin `loadError`, el control que invocaba nunca aparece |
| Control "Reintentar" por tamaño (plantilla) | `product-form.component.ts` | Depende de `v.loadError` |
| `ProductService.retryVariant()` | `product.service.ts` | Único llamador era `retryVariantLoad()` |

No afecta el contrato de guardado: ninguno de estos cuatro elementos participaba en el payload que
construyen los métodos de guardado existentes (`toProductPayload`, `RecipeSetPayload`,
`VariantOptionGroupSetPayload`), que no cambian.
