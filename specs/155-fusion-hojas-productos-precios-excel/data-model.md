# Data Model: Fusión de las hojas Productos y Presentaciones/precios en el Excel de la carta

Sin cambios de esquema (research.md D6): se reutilizan sin modificación `products.code` y la tabla
`product_import_jobs`, ambas de la spec 143. Este documento solo describe la plantilla de columnas
nueva de la hoja fusionada y las reglas de validación que cambian respecto a
`143-exportacion-importacion-carta-menu/data-model.md`.

## `products` y `product_import_jobs`

Sin cambios — ver `143-exportacion-importacion-carta-menu/data-model.md`. El único efecto visible
es de contenido, no de esquema: `product_import_jobs.errors[].hoja` pasa a poder valer "Productos y
precios", "Receta" o "Adiciones" (antes: "Productos", "Presentaciones y precios", "Receta" o
"Adiciones").

## Plantilla de columnas de la hoja fusionada "Productos y precios" (research.md D1)

Reemplaza, en el archivo de export/import, a las antiguas hojas "Productos" y "Presentaciones y
precios" de la spec 143. Una fila por presentación/variante (igual que la antigua hoja
"Presentaciones y precios"); los datos de producto se repiten en cada fila de ese producto.

| # | Columna | Origen/destino | Tipo esperado |
|---|---|---|---|
| 1 | Código | `products.code` | texto; vacío = producto nuevo con código autogenerado (research.md D3) |
| 2 | Nombre | `products.name` | texto, obligatorio |
| 3 | Categoría | `categories.name`, buscar o crear case-insensitive (143 research.md D5) | texto, obligatorio |
| 4 | Tipo de preparación | `products.preparation_type` (`Preparado` \| `Empacado`) | texto, uno de los dos valores |
| 5 | Descripción | `products.description` | texto, opcional |
| 6 | Activo | `products.active` | booleano |
| 7 | Disponible | `products.available` | booleano |
| 8 | Rastrea inventario | `products.tracks_inventory` | booleano |
| 9 | Es adición | `products.is_topping` | booleano |
| 10 | Visible en menú QR | `products.visible_en_qr` | booleano |
| 11 | Presentación | `presentations.name` (vía `product_variants.presentation_id`), buscar o crear case-insensitive (143 research.md D5) | texto, **obligatorio** (FR-004) |
| 12 | SKU | `product_variants.sku` | texto, opcional, único |
| 13 | Nombre comercial | `product_variants.name` | texto, opcional |
| 14 | Precio | `product_variants.price` | numérico, ≥ 0, **obligatorio** (FR-004) |
| 15 | Orden | `product_variants.display_order` | numérico, entero ≥ 0 |
| 16 | Activo de la presentación | `product_variants.active` | booleano — renombrada respecto a la "Activo" de la antigua hoja de presentaciones para no colisionar con la columna 6 (research.md D1) |

Las hojas "Receta" y "Adiciones" **no cambian** respecto a `143-exportacion-importacion-carta-menu/data-model.md` (mismas columnas, mismo origen/destino, mismo tipo esperado).

## Reglas de validación del import (por fila, FR-004 a FR-007)

Orden de procesamiento de hojas: Productos y precios → Receta → Adiciones (FR-007,
research.md D4). La hoja "Productos y precios" se procesa en dos pasadas:

**Pasada 1 — consistencia entre filas del mismo código (FR-005, research.md D2)**: se agrupan
todas las filas de la hoja por la columna Código (1), ignorando las filas con código vacío
(research.md D3). Para cada grupo con más de una fila, se comparan los valores de las columnas
2-10 (los campos de producto) entre todas sus filas. Si alguna difiere, **todas** las filas de ese
grupo se marcan como fallidas con un motivo que identifica el código y la(s) columna(s) que
difiere(n); ninguna de ellas pasa a la pasada 2.

**Pasada 2 — validación y aplicación por fila (FR-004, FR-006)**, para las filas que superaron la
pasada 1:
- **Nombre** y **Categoría** (columnas 2 y 3) obligatorios; Categoría se busca/crea case-insensitive
  (143 research.md D5). **Tipo de preparación** (columna 4) debe ser `Preparado` o `Empacado`. Las
  5 columnas booleanas de producto (6-10) conservan, en una actualización, el valor que el producto
  ya tenía si vienen vacías (nunca se infiere `false` por omisión, igual que en la 143); al crear,
  usan el default de creación.
- **Presentación** (columna 11) y **Precio** (columna 14) son obligatorios en **toda** fila — una
  fila que traiga completos los datos de producto pero deje vacía la presentación o el precio se
  marca como error (FR-004, edge case del spec); no existe una forma de representar, por esta vía,
  un producto sin ninguna presentación.
- **Código** (columna 1) resuelve actualización (coincide con un producto existente) o creación (no
  coincide, o viene vacío). El producto se crea o actualiza con los datos de las columnas 2-10,
  igual criterio que la antigua hoja "Productos" de la 143 — cuando la fila pertenece a un grupo de
  varias filas del mismo código (ya validado consistente en la pasada 1), esta operación se repite
  en cada fila del grupo con los mismos valores, lo cual es un no-op funcional a partir de la
  segunda fila del grupo (research.md D2).
- **Presentación** se busca/crea case-insensitive (143 research.md D5); la combinación
  producto+presentación identifica una variante existente (actualiza SKU, Nombre comercial, Precio,
  Orden, Activo de la presentación) o crea una nueva. **Precio** debe ser numérico ≥ 0; valor
  negativo o no numérico → fila fallida. **Orden** debe ser un entero ≥ 0; si coincide con el de
  otra variante del mismo producto, se resuelve igual que ya hace `_assign_variant_display_order`
  (reasignación determinística, no fila fallida).
- **Ninguna fila elimina ni desactiva una presentación existente que el producto ya tenía y que el
  archivo reimportado no incluye** (mismo criterio FR-005a de la 143, no modificado por esta spec).

**Receta** y **Adiciones**: sin cambios — mismas reglas que
`143-exportacion-importacion-carta-menu/data-model.md` (resolución estricta de insumo/adición,
nunca se crean).

## Rechazo del formato anterior (FR-008, research.md D5)

Un archivo con hojas llamadas "Productos" y/o "Presentaciones y precios" (formato de la spec 143)
no corresponde a ninguna de las 3 hojas esperadas por esta spec ("Productos y precios", "Receta",
"Adiciones") — `validar_estructura` lo trata como hoja desconocida y rechaza la importación
completa con `422`, antes de aplicar cualquier fila, sin código de detección dedicado (research.md
D5).
