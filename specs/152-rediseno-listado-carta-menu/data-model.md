# Data Model: Rediseño del listado de la Carta del menú

**Feature**: `152-rediseno-listado-carta-menu` | **Date**: 2026-11-05

No se crean tablas ni columnas nuevas. Las entidades `Product`, `ProductVariant` y
`Category` (`pos-backend/app/models/`) no cambian de esquema. Este documento describe
la **representación derivada** que el listado expone (`ProductListResponse`) y las
reglas de cómputo del precio resumido — no una migración.

## Entidad: Producto (listado) — `ProductListResponse`

Representación resumida de un `Product` para `GET /products`, recortada a los campos
que la tarjeta (móvil/tablet) o la fila de tabla (escritorio) despliegan (FR-008).

| Campo | Tipo | Origen | Uso en listado |
|---|---|---|---|
| `id` | UUID | `Product.id` | Identidad de fila/tarjeta, acciones |
| `category_id` | UUID | `Product.category_id` | Valor seleccionado al editar; no se muestra, se conserva para resaltar el filtro activo en el cliente |
| `category_name` | string \| null | `Product.category_name` (propiedad resuelta, spec 097) | Columna "Categoría" / línea de categoría en tarjeta. `null` → se muestra "Sin categoría" (edge case) |
| `name` | string | `Product.name` | Nombre visible |
| `image_url` | URL \| null | `Product.image_url` (ensamblada contra `ASSETS_BASE_URL`, spec 080) | Imagen o marcador "Sin imagen" si `null` |
| `preparation_type` | enum (`prepared`\|`packaged`) | `Product.preparation_type` | Badge "Preparado"/"Empacado" |
| `active` | bool | `Product.active` | Badge Activo/Inactivo |
| `available` | bool | `Product.available` | Badge Disponible/Agotado |
| `available_changed_at` | datetime \| null | `Product.available_changed_at` | Texto relativo junto al badge "Agotado" (spec 093) |
| `created_at` | datetime | `Product.created_at` | Columna "Creación" (tabla; el diseño de referencia la agrega) |
| `updated_at` | datetime \| null | `Product.updated_at` | Columna "Actualización" (tabla) |
| `price_display` | Decimal \| null | **Derivado** (ver regla abajo) | "$X" o, si `price_from=true`, antecedido de "Desde" en el cliente. `null` → "Sin precio" |
| `price_from` | bool | **Derivado** | `true` si hay ≥2 variantes activas con precio > 0 |

### Campos excluidos de `ProductListResponse` (FR-008)

`code`, `description`, `tracks_inventory`, `is_topping`, `visible_en_qr`,
`available_changed_by_name` — presentes en `Product`/`ProductResponse` pero no
desplegados en ninguna de las dos vistas del listado; siguen disponibles únicamente en
`ProductDetailResponse` (vista de detalle/edición, fuera de alcance de este feature).

### Regla de cómputo de `price_display` / `price_from`

Entrada: el conjunto de `ProductVariant` del producto donde `active = true`.

1. Filtrar esas variantes a las que además tienen `price > 0` (precio configurado).
2. Si el conjunto resultante está vacío → `price_display = null`, `price_from = false`.
3. Si tiene exactamente 1 elemento → `price_display = esa price`, `price_from = false`.
4. Si tiene 2 o más → `price_display = min(price de esas variantes)`, `price_from =
   true`.

Nota: una variante `active = false` nunca participa del cómputo, igual que el resto del
listado ignora variantes desactivadas (coherente con `ProductDetailResponse.deactivated`,
que ya las separa aparte).

## Entidad: Categoría (filtro)

No se agrega ninguna entidad nueva. El filtro reutiliza `Category` tal como la expone
hoy `GET /categories` (id, `name`, `active`). El selector de categoría del listado se
puebla con esa misma lista; "Sin categoría" es un valor de UI (no una fila de la tabla
`categories`) que agrupa productos cuyo `category_name` resuelto es `null` — caso
defensivo, dado que `Product.category_id` es `NOT NULL` con FK y no existe endpoint de
borrado de `Category` (ver research.md D3 y Edge Cases del spec).

## Parámetros de consulta añadidos — `GET /products`

| Parámetro | Tipo | Obligatorio | Efecto |
|---|---|---|---|
| `category_id` | UUID | No | `Product.category_id == category_id`, combinado con AND a los filtros existentes (`active`, `available`, `search`, `is_topping`) |

Sin cambios en los parámetros existentes (`page`, `size`, `active`, `available`,
`search`, `is_topping`) ni en su semántica.

## Estados / transiciones

No aplica — este feature no introduce nuevos estados ni transiciones de negocio;
`active`/`available` siguen gobernados por los endpoints y reglas ya existentes
(`PATCH /products/{id}/availability`, toggle de `active`), sin cambios funcionales
(FR-011).
