# Data Model: Exportación e importación masiva de la carta en Excel

## `products` — columna nueva

| Campo | Tipo | Regla |
|---|---|---|
| `code` | `String(20)` | `NOT NULL`, única por tenant (índice único, mismo patrón que `InventoryItem.code`, spec 109). Generada automáticamente (secuencial con cero a la izquierda) cuando no se especifica; editable por el administrador. |

**Backfill (Principio VIII)**: todo producto existente recibe un `code` en la misma migración que
agrega la columna. Orden de asignación: alfabético por `name` (criterio determinístico, igual que
el backfill de `InventoryItem.code`), para que sea repetible en cualquier ambiente.

**Estrategia de migración**: 1) agregar la columna como `NULL`; 2) backfillear con un secuencial
por tenant (`ROW_NUMBER() OVER (ORDER BY name)`, formateado a 4 dígitos); 3) alterar a `NOT NULL`;
4) agregar el índice único. Las 4 operaciones corren en la misma migración, dentro del mismo
`@for_each_tenant_schema` que ya usa `42dc063d8185_inventory_code_import_jobs.py` — cada esquema se
procesa de punta a punta antes de pasar al siguiente, sin ventana intermedia donde `code` exista
sin backfillear en un esquema y sí en otro.

**Estrategia de rollback**: quitar el índice único y la columna — no hay pérdida de datos de
negocio al revertir, porque `code` no reemplaza ni deriva de ningún campo existente (`name` sigue
siendo como el resto del sistema identifica un producto hoy, incluido el Menú QR y el formulario de
producto).

## `product_import_jobs` — tabla nueva

Misma forma que `inventory_import_jobs` (spec 109), aplicada al dominio de la carta:

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID (PK) | |
| `status` | `String(20)` | `procesando` \| `finalizado` \| `interrumpido` (research.md D7) |
| `file_name` | `String(255)` | nombre original del archivo subido |
| `started_by_user_id` | UUID | referencia blanda a `shared.users.id`, igual patrón que `InventoryImportJob.started_by_user_id` |
| `started_at` | `DateTime` | |
| `finished_at` | `DateTime`, nullable | se llena al terminar (finalizado o interrumpido) |
| `total_rows` | `int` | suma de filas de datos de las 4 hojas presentes en el archivo (sin contar encabezados) |
| `created_count` | `int`, default 0 | productos + presentaciones + ítems de receta + adiciones creados, agregados |
| `updated_count` | `int`, default 0 | ídem, actualizados |
| `failed_count` | `int`, default 0 | ídem, fallidos |
| `errors` | `JSONB`, default `[]` | lista de `{hoja, fila, codigo, motivo}` — un campo más que `inventory_import_jobs.errors` (`hoja`), porque aquí el error puede venir de cualquiera de las 4 hojas (FR-013) |

**Reglas**:
- A lo sumo una fila con `status = 'procesando'` por tenant que no haya superado el tiempo límite
  de vencimiento (research.md D7) — se valida en el endpoint antes de encolar (FR-012a).
- `errors` solo tiene contenido cuando `failed_count > 0`; con `failed_count = 0` el frontend no
  ofrece la descarga del reporte.
- Sin relación de borrado en cascada con `products`/`product_variants`/`recipe_items`/
  `product_toppings`: un job finalizado es un registro histórico de lo que pasó en ese momento, no
  una vista en vivo de la carta.
- Sin historial permanente ni política de purga explícita — mismo criterio que
  `inventory_import_jobs` (no es un requisito de este spec).

## Plantilla de columnas por hoja (compartida por export e import)

Definidas en un solo lugar (research.md D8), cada una en este orden:

### Hoja "Productos"

| # | Columna | Origen/destino | Tipo esperado |
|---|---|---|---|
| 1 | Código | `products.code` | texto, vacío = "asignar uno nuevo" al crear |
| 2 | Nombre | `products.name` | texto, obligatorio |
| 3 | Categoría | `categories.name`, buscar o crear case-insensitive (research.md D5) | texto, obligatorio |
| 4 | Tipo de preparación | `products.preparation_type` (`Preparado` \| `Empacado`, mismas etiquetas que `products-page.component.ts`) | texto, uno de los dos valores |
| 5 | Descripción | `products.description` | texto, opcional |
| 6 | Activo | `products.active` | booleano |
| 7 | Disponible | `products.available` | booleano |
| 8 | Rastrea inventario | `products.tracks_inventory` | booleano |
| 9 | Es adición | `products.is_topping` | booleano |
| 10 | Visible en menú QR | `products.visible_en_qr` | booleano |

### Hoja "Presentaciones y precios"

| # | Columna | Origen/destino | Tipo esperado |
|---|---|---|---|
| 1 | Código de producto | `product_variants.product_id` (vía `products.code`) | texto, debe existir (en el archivo o ya en el sistema) |
| 2 | Presentación | `presentations.name` (vía `product_variants.presentation_id`), buscar o crear case-insensitive (research.md D5) | texto, obligatorio |
| 3 | SKU | `product_variants.sku` | texto, opcional, único |
| 4 | Nombre comercial | `product_variants.name` | texto, opcional |
| 5 | Precio | `product_variants.price` | numérico, ≥ 0 |
| 6 | Orden | `product_variants.display_order` | numérico, entero ≥ 0 |
| 7 | Activo | `product_variants.active` | booleano |

### Hoja "Receta"

| # | Columna | Origen/destino | Tipo esperado |
|---|---|---|---|
| 1 | Código de producto | `recipe_items.product_variant_id` (vía producto+presentación) | texto, debe existir |
| 2 | Presentación | ídem, combinado con la columna 1 para resolver la variante exacta | texto, obligatorio |
| 3 | Insumo | `recipe_items.inventory_item_id`, resuelto por nombre o código contra el inventario **existente** (research.md D6, FR-008) — nunca se crea | texto, obligatorio, debe existir |
| 4 | Cantidad | `recipe_items.quantity` | numérico, > 0 |

### Hoja "Adiciones"

| # | Columna | Origen/destino | Tipo esperado |
|---|---|---|---|
| 1 | Código de producto | `product_toppings.product_id` (vía `products.code`) | texto, debe existir |
| 2 | Código de producto adición | `product_toppings.topping_product_id` (vía `products.code`), debe ser un producto con `is_topping=true` y distinto del de la columna 1 (research.md D6, FR-009) | texto, debe existir |

## Reglas de validación del import (por fila, FR-006)

Orden de procesamiento de hojas: Productos → Presentaciones y precios → Receta → Adiciones
(FR-007, research.md D4). Cada hoja se procesa completa antes de pasar a la siguiente.

- **Productos**: **Código** (columna 1) resuelve actualización (coincide con un producto
  existente) o creación (no coincide, o viene vacío → código asignado automáticamente). Duplicado
  dentro del mismo archivo → todas las filas afectadas fallan (edge case del spec). **Nombre** y
  **Categoría** obligatorios; Categoría se busca/crea case-insensitive (research.md D5). **Tipo de
  preparación** debe ser `Preparado` o `Empacado`. Las 5 columnas booleanas (6-10) aceptan los
  mismos valores que ya usa el export/import de inventario para sus columnas booleanas; si falta
  una columna booleana en una fila de actualización, conserva el valor que el producto ya tenía
  (nunca se infiere `false` por omisión — FR-005a aplica también dentro de la propia fila de
  Productos, no solo entre hojas).
- **Presentaciones y precios**: **Código de producto** (columna 1) debe existir — en una fila
  anterior de la hoja Productos del mismo archivo, o ya en el sistema; si no existe en ninguno de
  los dos, la fila falla (edge case del spec). **Presentación** se busca/crea case-insensitive
  (research.md D5); la combinación producto+presentación identifica una variante existente
  (actualiza: SKU, Nombre comercial, Precio, Orden, Activo) o crea una nueva. **Precio** debe ser
  numérico ≥ 0; valor negativo o no numérico → fila fallida (edge case del spec). **Orden** debe
  ser un entero ≥ 0; si coincide con el de otra variante del mismo producto, se resuelve igual que
  ya hace `_assign_display_orders` (reasignación determinística, no fila fallida).
- **Receta**: **Código de producto + Presentación** (columnas 1-2) deben resolver a una variante
  existente — creada en una fila anterior de la hoja Presentaciones del mismo archivo, o ya en el
  sistema; si no, la fila falla (edge case del spec). **Insumo** (columna 3) se resuelve por nombre
  o código contra el inventario **ya existente** del tenant — nunca se crea un insumo nuevo
  (research.md D6, Assumptions del spec); si no existe, la fila falla (FR-008). **Cantidad** debe
  ser numérica > 0. La combinación variante+insumo identifica un ítem de receta existente
  (actualiza cantidad) o crea uno nuevo.
- **Adiciones**: **Código de producto** y **Código de producto adición** (columnas 1-2) deben
  existir ambos — en el sistema o en una fila anterior de la hoja Productos del mismo archivo; si
  alguno no existe, la fila falla. El producto adición debe tener `is_topping=true`; si existe pero
  no está marcado como adición, la fila falla con un motivo claro (FR-009). Si ambos códigos son
  iguales, la fila falla (un producto no puede ser adición de sí mismo, edge case del spec). La
  combinación producto+producto-adición identifica una relación existente (sin campos adicionales
  que actualizar) o crea una nueva.
- **Ninguna hoja elimina ni desactiva una fila existente por su ausencia en el archivo** (FR-005a):
  una presentación, ítem de receta o adición que el producto ya tenía y que el archivo reimportado
  ya no incluye permanece intacta.
