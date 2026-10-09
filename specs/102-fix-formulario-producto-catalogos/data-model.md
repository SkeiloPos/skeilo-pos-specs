# Data Model: Corrección y mejora de rendimiento del formulario de crear/editar producto

Sin cambios de esquema de base de datos ni de contrato persistido: `Producto`, `Variante`,
`Receta de producto/Insumo fijo`, `Grupo de opciones/Opción`, `Insumo`, `Categoría` y
`Presentación` (spec, "Key Entities") ya existen y no ganan columnas, tablas ni relaciones nuevas.
Esta corrección solo introduce **estado transitorio de UI** (no persistido) en el frontend
(`pos-heladeria`) y extiende, sin romper su forma, dos métodos de servicio ya existentes.

## Estado transitorio nuevo en `VariantDraft` (`product.interface.ts:372` y alrededores)

| Campo nuevo | Tipo | Vive mientras... | Notas |
|---|---|---|---|
| `loadError` | `boolean` (opcional, default `false`/ausente) | el formulario de edición está abierto | Nuevo (research.md D2). `true` cuando la carga en paralelo de la receta o los grupos de opciones de esa variante específica falló; se limpia al reintentar con éxito (`retryVariantLoad`). No se envía nunca al backend — se descarta al construir el payload de guardado (`RecipeSetPayload`/equivalente), igual que los demás campos transitorios del draft (p. ej. `localId`) |

No afecta el contrato de guardado: `FR-015` (esta corrección no cambia cómo se guarda el producto)
se cumple porque `loadError` nunca se incluye en el payload que construyen los métodos de guardado
existentes.

## Campo nuevo en `ProductDraft` (`product.interface.ts:393` y alrededores)

| Campo nuevo | Tipo | Vive mientras... | Notas |
|---|---|---|---|
| `category_name` | `string` (opcional, default `''`/ausente) | el formulario está abierto | Nuevo (research.md D4). Se puebla en `getProductDraft()` desde `product.category_name`, ya resuelto por el backend (spec 097) — no requiere ninguna petición nueva. Mismo rol que `presentationName` en `VariantDraft`: permite al selector de categoría mostrar el nombre real de la categoría ya elegida aunque haya quedado fuera de `allCategories()`. No se envía al backend: el payload de guardado sigue enviando solo `category_id` |

## Estado transitorio nuevo en `InventoryService` (`inventory.service.ts`)

| Campo (signal) | Tipo | Vive mientras... | Notas |
|---|---|---|---|
| `resolvedExtraItems` | `InventoryItem[]` (signal, inicia `[]`) | la sesión del formulario que lo pobló permanece abierta | Nuevo (research.md D1). Insumos resueltos por id (`GET /items/{id}`) porque un `inventory_item_id` ya referenciado por una receta u opción no estaba en `allItems()`. Se combina con `allItems()` en el consumidor (`ProductFormComponent`), nunca se mezcla dentro de `allItems()` mismo |

Transición (una sola vez por apertura del formulario de edición, después de que `getProductDraft`
resuelve — research.md D1/D2):

```text
getProductDraft() resuelve (todas las variantes, en paralelo)
        │
        ▼
recolectar inventory_item_id de receta + desglose de opciones de TODAS las variantes
        │
        ▼
filtrar los que ya están en allItems()  ──(ninguno falta)──> resolvedExtraItems sigue []
        │
   (algunos faltan)
        ▼
InventoryService.resolveMissingItems(idsFaltantes) ── Promise.all GET /items/{id} ──> resolvedExtraItems += resultados
```

`inventoryOptions()` y `unitLookup` (`product-form.component.ts`) leen `[...allItems(),
...resolvedExtraItems()]` (deduplicado por `id`) en vez de `allItems()` sola — ver research.md D1.

## Transición de carga de variantes (research.md D2)

```text
abrir formulario de edición
        │
        ▼
getProductDraft(productId)
        │
        ▼
Promise.allSettled([  // TODAS las variantes activas, al mismo tiempo
  variante 1: Promise.all([getVariantRecipe, getVariantOptionGroups]),
  variante 2: Promise.all([getVariantRecipe, getVariantOptionGroups]),
  …
  variante N: Promise.all([getVariantRecipe, getVariantOptionGroups]),
])
        │
   ┌────┴─────┐
 resuelve    rechaza
   │             │
VariantDraft   VariantDraft { recipe: [], optionGroups: [], loadError: true }
normal                │
                  (usuario pulsa "Reintentar" en esa variante)
                       │
                       ▼
              retryVariantLoad(variantId) ── repite solo esa variante ──> éxito: loadError=false
```

## `InventoryService.resolveMissingItems(ids)` (nuevo método, research.md D1)

No introduce un tipo nuevo: reutiliza `InventoryItem` (ya existente). Firma:

| Entrada | Tipo | Notas |
|---|---|---|
| `ids` | `string[]` | Ids de insumo ya referenciados por una fila existente que no están en `allItems()` ni ya en `resolvedExtraItems()` |

| Salida | Tipo | Notas |
|---|---|---|
| `Promise<void>` | — | Efecto secundario: agrega a `resolvedExtraItems`. Sin resultado directo — los consumidores leen el signal, no el valor de retorno |

## `CategoryService.searchActiveCategories(query)` / `PresentationService.searchActivePresentations(query)` (nuevos métodos, research.md D3)

Misma forma que `InventoryService.searchActiveItems(query)` (ya existente, spec 098): reutilizan
`Category`/`Presentation` (interfaces ya existentes), sin tipos nuevos.

| Entrada | Tipo | Notas |
|---|---|---|
| `query` | `string` | Texto tal cual lo escribió el usuario; se recorta (`.trim()`) antes de enviarse como `search` |

| Salida | Tipo | Notas |
|---|---|---|
| `Promise<Category[]>` / `Promise<Presentation[]>` | — | Siempre `active=true`, `page=1`, `size=20` (research.md D3), sin campos nuevos |

No hay reglas de validación nuevas ni transiciones de estado de dominio: las tres son lecturas de
solo consulta sobre catálogos cuyo ciclo de vida no cambia con esta corrección.
