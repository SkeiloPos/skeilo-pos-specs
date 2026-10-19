# Contrato: `products` API — marcar adiciones, asociarlas, controlar visibilidad en QR

Extiende los endpoints ya existentes de `app/api/v1/products/` (`router.py`/`schemas.py`). No se
agregan verbos ni rutas nuevas para esto — solo campos nuevos en los payloads ya existentes.

## `POST /products`, `PATCH /products/{id}`, `PUT /products/{id}`

**`ProductCreate`/`ProductUpdate` — campos nuevos**:

| Campo | Tipo | Default | Notas |
|---|---|---|---|
| `is_topping` | `bool` | `False` (solo en `ProductCreate`; en `ProductUpdate`, `None` = no tocar) | FR-001. Inmutable una vez creado si el producto ya está asociado como adición de algún otro (ver reglas abajo) — en caso contrario, se permite cambiarlo. |
| `visible_en_qr` | `bool \| None` | `None` en ambos esquemas = "usar el default calculado" (research.md D6): `false` si `is_topping=true`, `true` si no. Un valor explícito siempre gana sobre el default. | FR-010/FR-011. |
| `topping_ids` | `list[UUID]` | `[]` | Adiciones que este producto ofrece (FR-002). Reemplazo total en cada guardado, mismo criterio que `category.presentations` (spec 083) — no hay columnas propias en la tabla puente que preservar. |

**Validaciones nuevas (servicio, no solo Pydantic)**:
- Cada id de `topping_ids` MUST referenciar un producto existente con `is_topping=true` → `422`
  si no, con el nombre del producto que falló.
- `topping_ids` MUST NOT contener el propio id del producto que se está guardando (FR-016) → `422`.
- Si `is_topping=true` y el producto ya tiene `topping_ids` propios no vacíos (una adición que a
  su vez tendría adiciones) → `422` (spec.md, Assumptions: fuera de alcance).

**Respuesta** (`ProductResponse` y descendientes: `ProductListResponse`, `ProductDetailResponse`,
`ProductSaveResponse`) — campos nuevos:

| Campo | Tipo | Notas |
|---|---|---|
| `is_topping` | `bool` | |
| `visible_en_qr` | `bool` | Valor ya resuelto (nunca `null`). |
| `topping_ids` | `list[UUID]` | Solo en `ProductDetailResponse`/`ProductSaveResponse` (igual criterio que `variants`: la lista completa no viaja en el listado paginado). |

## `GET /products`

Sin cambios de firma. `search` ya no distingue productos regulares de adiciones — una adición
aparece en los resultados igual que cualquier producto (research.md D3), lo que de por sí
satisface FR-006 (catálogo del pedido manual). Se agrega `is_topping` al `ProductListResponse`
para que el frontend pueda, si quiere, distinguir visualmente una adición en una lista mixta de
resultados (no es un requisito del spec, pero el campo ya viaja en la respuesta por defecto).

## Permisos

Sin cambios de dependencia: `create_product`/`update_product`/`replace_product` ya requieren
`require_tenant_admin` (ver `router.py` existente) — cubre FR-013 (solo rol administrativo puede
marcar/asociar adiciones o cambiar visibilidad en QR) sin tocar `app/core/dependencies.py`.
