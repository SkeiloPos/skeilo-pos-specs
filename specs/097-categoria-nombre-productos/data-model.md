# Data Model: Corrección — el nombre de categoría de un producto no depende de la paginación de `GET /categories`

Sin cambios de esquema: no se agrega ninguna columna, tabla ni migración. Las dos entidades
involucradas ya existen; esta spec solo agrega un dato **derivado** (no persistido) a la respuesta
de una de ellas.

## Producto (`Product`, `app/models/product.py`)

Sin cambios en columnas. Gana una propiedad Python de solo lectura:

| Propiedad | Tipo | Origen |
|---|---|---|
| `category_name` | `str \| None` | `self.category.name if self.category else None` — lee la relación `many-to-one` ya existente `Product.category` (línea 22) |

- No se persiste: se recalcula en cada lectura, por lo que un renombrado de categoría se refleja de
  inmediato (criterio de aceptación 3 del spec) sin ningún mecanismo de invalidación de caché.
- `None` solo es alcanzable si `self.category` no resuelve (dato inconsistente de un fixture de
  test sin FK real, ver research.md D4); en producción, con la FK `NOT NULL` de PostgreSQL, siempre
  hay un valor.

## Categoría (`Category`, `app/models/category.py`)

Sin cambios. Sigue siendo la fuente de verdad de `name`; `GET /categories` y su paginación
(tope 100) no se tocan (FR-005).

## Contrato de respuesta (`ProductResponse`, `app/api/v1/products/schemas.py`)

| Campo | Tipo | Nuevo/Existente | Notas |
|---|---|---|---|
| `category_id` | `UUID` | Existente | Sin cambios |
| `category_name` | `str \| None` | **Nuevo** | Default `None`; ver research.md D3/D4. Heredado por `ProductListResponse`, `ProductDetailResponse`, `ProductSaveResponse` |

No hay transiciones de estado ni reglas de validación nuevas: `category_name` es puramente de
lectura, nunca se envía en `ProductCreate`/`ProductUpdate`/`ProductAvailabilityUpdate`.
