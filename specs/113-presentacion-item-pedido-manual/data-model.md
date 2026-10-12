# Data Model: Mostrar presentación elegida en la línea del ítem de la orden manual

No se crean entidades nuevas ni se modifica el esquema de datos del backend. Este documento describe los tipos/estructuras ya existentes en el frontend (`../pos-heladeria`) que participan en el defecto y en su corrección, para que la fase de tareas tenga claro qué tocar y qué dejar intacto.

## Entidades existentes involucradas

### `MenuVariant` (sin cambios)

Ubicación: `pos-heladeria/src/app/modules/products/interfaces/product.interface.ts`

Representa una presentación/variante de un producto (p. ej. "8 oz", "12 oz", "16 oz"). Atributos relevantes:

| Campo | Tipo | Nota |
|---|---|---|
| `id` | `string` | Identificador de la variante |
| `name` | `string` | Nombre de la presentación (es el texto que debe mostrarse) |
| `price` | `number` | Precio base de esa presentación |
| `discounted_price` | `number \| null` | Precio con descuento, si aplica |

### `ProductDraftLine` (sin cambios)

Ubicación: `pos-heladeria/src/app/modules/tables/services/pos-terminal.store.ts`

Representa un ítem recién agregado al carrito de una orden (mesa, para llevar o domicilio) que todavía no se ha guardado/enviado. Ya conserva la variante elegida en su totalidad:

| Campo | Tipo | Nota |
|---|---|---|
| `kind` | `'product'` | Discriminador de unión |
| `key` | `string` | Clave única de la línea en el carrito |
| `product` | `MenuProduct` | Producto base |
| `variant` | `MenuVariant` | **Presentación elegida — ya presente, no se pierde aquí** |
| `options` | `ChosenMenuOption[]` | Toppings/adicionales elegidos |
| `quantity` | `number` | Cantidad |
| `notes` | `string \| null` | Instrucciones especiales |
| `unitPrice` | `number` | Precio unitario ya resuelto con la variante |

### Fila de `cartView()` (computed de solo lectura — CAMBIO AQUÍ)

Ubicación: `pos-heladeria/src/app/modules/tables/services/pos-terminal.store.ts`, `cartView` computed.

Es la proyección de solo lectura que consumen las plantillas de `manual-order-page.component.ts` y `pos-order-panel.component.ts`. Combina líneas persistidas (`persistedItemsView()`) y líneas de borrador (`draftLines()`) en una forma común.

Estado actual (defecto):

| Campo | Líneas persistidas | Líneas de borrador (defecto) |
|---|---|---|
| `name` | `lk.variantLabel(product_variant_id)` → `"Producto · Variante"` cuando el producto tiene >1 presentación, o solo `"Producto"` si tiene 1 | `l.product.name` únicamente — **ignora `l.variant.name`** |

Estado corregido (este plan):

| Campo | Líneas persistidas | Líneas de borrador (corregido) |
|---|---|---|
| `name` | `lk.variantLabel(product_variant_id)` (sin cambios) | `lk.variantLabel(l.product.id, l.variant.id)` (o equivalente) → mismo formato "Producto · Variante" que las persistidas |

No se agrega un campo nuevo a esta fila en este cambio (ver Decisión 2 en `research.md`: se reutiliza el formato de string combinado ya consumido por `splitVariantLabel()`, en vez de introducir un campo `variantName` separado, para mantener el alcance acotado al defecto reportado).

## Reglas de visualización (ya existentes, reutilizadas sin modificar)

- `menu-lookup.ts::variantLabel(productId, variantId)`: antepone el nombre de la variante solo si `product.variants.length > 1`; si el producto tiene una única presentación configurada, devuelve solo el nombre del producto. Esta regla ya gobierna las líneas persistidas y, tras este fix, también las de borrador — cumple FR-003 del spec (no mostrar texto de presentación cuando el producto no tiene presentaciones reales entre las que elegir).
- `menu-lookup.ts::splitVariantLabel(label)`: separa un string combinado `"Producto · Variante"` en `{ product, variant }` para que la plantilla pueda renderizar el nombre del producto y el pill de la variante por separado. Ya usado por `pos-order-panel.component.ts`; se reutiliza también en `manual-order-page.component.ts` (nuevo consumidor, sin cambios en el helper).

## Transiciones de estado

No aplica — este cambio no introduce ni modifica transiciones de estado. La variante de un ítem de carrito se fija una vez al agregarlo (o al editarlo explícitamente vía el modal de personalización, FR-004 del spec) y no cambia por ningún otro evento del sistema.
