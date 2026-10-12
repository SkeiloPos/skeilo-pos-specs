# Data Model: Pestaña dedicada de Promociones en el catálogo de la orden manual

No hay cambios al modelo de datos del backend: ni nuevas entidades, ni nuevos campos persistidos, ni migraciones. El modelo de promociones (`Promotion` → `PromotionRule` → `PromotionVariant`) y el endpoint `GET /menu` se reutilizan sin modificación (ver `research.md`, Decisión 1 y 2). Lo que sigue es exclusivamente estado y tipos de **frontend**, todos en memoria, nunca enviados al backend salvo la cantidad final ya existente.

## Entidades conceptuales (del spec, sin esquema propio)

### Producto en promoción
Criterio ya existente en el modelo de promociones del backend, expuesto en `MenuVariant.promotion: MenuVariantPromotion | null` (ver `product.interface.ts`). Un producto (`MenuProduct`) "está en promoción" cuando `product.variants.some(v => v.promotion != null)`. No es una entidad nueva — es el criterio que la nueva función compartida `hasPromotion()` encapsula (ver abajo).

### Cantidad mínima de la regla
Ya existente en `MenuVariantPromotion.min_qty` (poblado por el backend, `menu_variant_promotion()`). Esta feature solo lo **lee** para decidir el paso de incremento/decremento; no lo modifica ni lo recalcula.

## Cambios de tipos y estado en el frontend (`pos-heladeria`)

### `hasPromotion(product: MenuProduct): boolean` — nueva función exportada

- **Ubicación**: `pos-heladeria/src/app/modules/promotions/services/promotion-pricing.util.ts` (nueva, extraída de `public-menu.component.ts`).
- **Firma**: `(product: MenuProduct) => boolean`.
- **Regla**: `true` si al menos una variante de `product.variants` tiene `promotion != null`.
- **Consumidores**: `public-menu.component.ts` (reemplaza su copia privada), `pos-terminal.store.ts` (nuevo, para `catalogProductsPromotionsFiltered`).

### `ProductDraftLine` — SIN campo `step` (revertido, A-126)

Esta sección documentaba un campo `step?: number` que llegó a implementarse y luego se revirtió
por completo en la misma sesión (decisión de negocio A-126, `registro-de-anomalias.md`): el
control +/- de una línea ya agregada al pedido vuelve a avanzar siempre de 1 en 1, sin importar su
promoción — a diferencia del menú QR. `ProductDraftLine` no gana ningún campo nuevo por esta spec.
Lo único que persiste de la decisión original es el comportamiento del **primer agregado** desde
"Promociones" (entra con la cantidad mínima de la regla), que vive enteramente en el modal
(`ProductSelectComponent`, sin cambios de esta spec) y en `configuringProductFromPromotions` (ver
abajo) — nunca en la línea de borrador en sí.

### `PosTerminalStore` — nuevo estado y computed

| Símbolo | Tipo | Descripción |
|---|---|---|
| `configuringProductFromPromotions` | `Signal<boolean>` (nuevo) | `true` cuando el modal de selección actualmente abierto (`configuringProduct`) se abrió desde la pestaña "Promociones". Se fija en `openConfig(product, fromPromotions)` y se resetea en `closeConfig()`/`addDraftFromSelection()`. Irrelevante en modo edición (`openConfigForEdit`), que no lo toca — ver `research.md` Decisión 4. |
| `catalogProductsPromotionsFiltered` | `computed<MenuProduct[]>` (nuevo) | Análogo a `catalogProductsAllFiltered`: junta todas las categorías, filtra por `hasPromotion(p)`, y aplica el mismo filtro de texto de `catalogSearchText()` que las demás vistas del catálogo. |

### `PosTerminalStore.openConfig()` — firma extendida

- **Antes**: `openConfig(product: MenuProduct): void`
- **Después**: `openConfig(product: MenuProduct, fromPromotions = false): void` — parámetro nuevo, opcional con default `false`, por lo que ningún llamador existente (si quedara alguno sin actualizar) cambia de comportamiento.

### `PosTerminalStore.incDraft()` / `decDraft()` — SIN cambios (revertido, A-126)

Se evaluó (y llegó a implementarse) un paso de `x.step` aquí; A-126 lo revirtió por completo.
`incDraft`/`decDraft` siguen siendo `quantity + 1` / `quantity - 1` (filtrando `quantity > 0` en
`decDraft`), exactamente igual que antes de esta spec, sin importar si la línea está en
promoción.

### `ManualOrderPageComponent` — nuevo estado local

| Símbolo | Tipo | Descripción |
|---|---|---|
| `showingPromotions` | `Signal<boolean>` (nuevo) | Análogo a `showingAllCategories`. `true` cuando la pestaña "Promociones" está activa. Mutuamente excluyente con `showingAllCategories` y con tener una categoría seleccionada — igual que ya son mutuamente excluyentes "Todos" y una categoría. Por defecto `false` (FR-013: "Todos" sigue siendo la vista inicial). |
| `selectPromotions()` | método (nuevo) | Activa `showingPromotions`, desactiva `showingAllCategories` y no deja ninguna categoría marcada como activa — mismo patrón que `selectAllCategories()`/`selectCategory(id)`. |
| `catalogProducts` (computed local) | sin cambio de tipo, lógica extendida | Pasa a elegir entre tres fuentes según el modo activo: `store.catalogProductsPromotionsFiltered()` (si `showingPromotions()`), `store.catalogProductsAllFiltered()` (si `showingAllCategories()`), o `store.catalogProductsFiltered()` (categoría específica) — antes solo alternaba entre las dos últimas. |

No se agrega ningún estado de "selección automática" (FR-013 es, precisamente, la ausencia de ese comportamiento): no hay ningún `effect()` que fije `showingPromotions` al cargar, a diferencia de `public-menu.component.ts:1004-1008`.

### `PosCatalogDrawerComponent` — nuevo estado local (FR-014)

| Símbolo | Tipo | Descripción |
|---|---|---|
| `showingPromotions` | `Signal<boolean>` (nuevo) | Mismo patrón que en `ManualOrderPageComponent`, pero sin equivalente a "Todos": la alternativa a "Promociones" aquí es simplemente tener una categoría de `store.categories()` seleccionada. Por defecto `false`. |
| `selectPromotions()` | método (nuevo) | Activa `showingPromotions`; al seleccionar una categoría (`store.setCatalogCategory(id)`) se desactiva. |
| Grilla de productos | lógica extendida | Usa `store.catalogProductsPromotionsFiltered()` en vez de `store.catalogProductsFiltered()` cuando `showingPromotions()` es `true`, con el mismo estado vacío ("No hay promociones activas en este momento.") en lugar del estado vacío por categoría/búsqueda ya existente. |
| Click de tarjeta | comportamiento extendido | Pasa de `store.openConfig(p)` a `store.openConfig(p, showingPromotions())`. |
| `<app-product-select>` | binding nuevo | Agrega `[fromPromotions]="store.configuringProductFromPromotions()"`. |

## Resumen de compatibilidad

- Ningún campo ni tipo existente cambia de significado; todo lo nuevo es aditivo y opcional (parámetro `fromPromotions = false` con default en `openConfig`). `ProductDraftLine` no gana ningún campo nuevo (el campo `step` que se había agregado se revirtió por completo, A-126).
- Ninguna migración de datos: todo el estado nuevo vive en memoria del navegador y se descarta junto con el resto del borrador de la orden manual.
- El modelo de promociones del backend (`Promotion`/`PromotionRule`/`PromotionVariant`, `MenuVariantPromotion` en la respuesta de `GET /menu`) no cambia.
