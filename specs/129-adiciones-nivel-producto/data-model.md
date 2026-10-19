# Data Model: Adiciones configuradas a nivel de producto y vendibles como línea independiente

Las decisiones detrás de cada elección están en [research.md](./research.md); este documento se
limita a columnas, restricciones, relaciones y la estrategia de migración.

## Product (`products`, schema `tenant`) — MODIFICADA

Columnas nuevas:

| Columna | Tipo | Nulable | Default (ORM/BD) | Notas |
|---|---|---|---|---|
| `is_topping` | `Boolean` | No | `False` / `server_default='false'` | Marca el producto como adición (FR-001). No excluye ninguna capacidad normal de producto (precio, receta, variantes, activo/disponible, categoría). |
| `visible_en_qr` | `Boolean` | No | `True` / `server_default='true'` a nivel de columna; **default de negocio calculado en servicio** (research.md D6): `false` si `is_topping=true`, `true` en caso contrario, al crear (FR-010/FR-011). |

Columnas sin cambio: `id`, `category_id`, `name`, `description`, `preparation_type`, `image_url`,
`active`, `available`, `tracks_inventory`, `available_changed_at`, `available_changed_by_name`,
`variants`.

`CheckConstraint` nuevo: ninguno a nivel de columna — la regla "una adición no puede asociarse a
sí misma" (FR-016) se valida en servicio, porque involucra dos filas de `product_toppings`, no
una condición de una sola fila de `products`.

## `ProductTopping` (`product_toppings`, schema `tenant`) — NUEVA

Declara qué adiciones ofrece un producto, a nivel de producto (no de variante) — FR-002/FR-003.

| Columna | Tipo | Nulable | Notas |
|---|---|---|---|
| `id` | UUID (PK) | No | `UUIDPrimaryKeyMixin`, igual que el resto del catálogo. |
| `product_id` | UUID (FK → `products.id`, `ondelete=CASCADE`) | No | El producto que ofrece la adición. Si se borra el producto, se borra la asociación (no el producto-adición). |
| `topping_product_id` | UUID (FK → `products.id`, sin `ondelete`) | No | El producto marcado `is_topping=true`. Sin `ondelete`: una adición referenciada no puede borrarse físicamente — se retira por `active=false`, igual que ya ocurre con `option_group_id` en `VariantOptionGroup`. |

`__table_args__`:
- `UniqueConstraint(product_id, topping_product_id)` — una adición se asocia una sola vez por
  producto.
- `CheckConstraint("product_id <> topping_product_id")` — rechaza a nivel de base de datos que un
  producto se asocie a sí mismo como su propia adición (FR-016; defensa en profundidad además de
  la validación en servicio).

Validación en servicio (no expresable en `CHECK` de una tabla): `topping_product_id` MUST
referenciar un producto con `is_topping=true` — un producto regular no puede ofrecerse como
adición de otro. Rechazar con `422` si no se cumple.

## `CartItemTopping` (`cart_item_toppings`, schema `tenant`) — NUEVA

Adición adjunta a una línea de carrito (research.md D4) — espejo de `CartItemOption`.

| Columna | Tipo | Nulable | Default | Notas |
|---|---|---|---|---|
| `id` | UUID (PK) | No | — | |
| `cart_item_id` | UUID (FK → `cart_items.id`, `ondelete=CASCADE`) | No | — | La línea a la que se adjunta. |
| `topping_product_variant_id` | UUID (FK → `product_variants.id`) | No | — | La variante "principal" (menor `display_order`) del producto-adición (research.md D5). |
| `quantity` | `Integer` | No | `server_default='1'` | Unidades elegidas (FR-018). `CheckConstraint(quantity > 0)`. |
| `unit_price` | `Numeric(12,2)` | No | `server_default='0'` | Snapshot del precio de catálogo de la adición al agregarla (FR-017: siempre su precio de catálogo; se snapshotea igual que `CartItem.unit_price`, por si el precio de catálogo cambia mientras el carrito sigue abierto). |

`__table_args__`:
- `UniqueConstraint(cart_item_id, topping_product_variant_id)` — como máximo una fila por
  (línea, adición); la cantidad vive en esa fila (mismo criterio que `CartItemOption`).
- `CheckConstraint("quantity > 0")`.

## `OrderItemTopping` (`order_item_toppings`, schema `tenant`) — NUEVA

Mismo propósito que `CartItemTopping`, para una línea de pedido ya confirmada — espejo de
`OrderItemOption`, incluido el mecanismo de spec 123 para una adición agregada después de emitida
la venta.

| Columna | Tipo | Nulable | Default | Notas |
|---|---|---|---|---|
| `id` | UUID (PK) | No | — | |
| `order_item_id` | UUID (FK → `order_items.id`, `ondelete=CASCADE`) | No | — | |
| `topping_product_variant_id` | UUID (FK → `product_variants.id`) | No | — | |
| `quantity` | `Integer` | No | `server_default='1'` | `CheckConstraint(quantity > 0)`. |
| `unit_price` | `Numeric(12,2)` | No | `server_default='0'` | Snapshot copiado del carrito al confirmar (nunca recalculado — mismo criterio que el resto de `order_items`). |
| `added_after_sale` | `Boolean` | No | `server_default='false'` | Igual que `OrderItemOption.added_after_sale` (spec 123): `true` si, al insertarse esta fila, el pedido ya tenía una `Sale` emitida. |
| `complementary_sale_id` | UUID (FK → `sales.id`), nulable | Sí | `NULL` | Igual que `OrderItemOption.complementary_sale_id`: se fija una sola vez al cobrarse el pago complementario que liquida esta adición. |

`__table_args__`:
- `UniqueConstraint(order_item_id, topping_product_variant_id)`.
- `CheckConstraint("quantity > 0")`.

## `OptionGroup` / `Option` / `VariantOptionGroup` — SIN CAMBIO DE ESQUEMA

Research.md D1: el enlace variante→grupo de opciones no se mueve de nivel. Cambio puramente de
uso/documentación (FR-004): el flujo de creación de grupos deja de ofrecerse para configurar
adiciones nuevas (`pricing_type='con_recargo'` con intención de adición); sigue disponible para
sabores (`pricing_type='incluido'` o `'con_recargo'` cuando el sabor tiene costo propio). Ninguna
fila ni columna existente cambia de significado — los grupos ya configurados como adiciones antes
de esta spec siguen funcionando exactamente igual hasta que el negocio los recree manualmente
como productos-adición (spec.md, Assumptions).

## `CartItem` / `OrderItem` — SIN CAMBIO DE ESQUEMA

Vender una adición como línea independiente (US2) no requiere ninguna columna nueva: es una fila
de `cart_items`/`order_items` con `product_variant_id` apuntando a la variante de la adición,
exactamente igual que la de cualquier producto (research.md D3). `addons_total` gana una fuente
más al calcularse (`CartItemTopping`/`OrderItemTopping`), sin cambiar su fórmula
(`unit_price × quantity + addons_total`, spec 089).

## Migración de datos existentes

```text
products.is_topping         = false  para toda fila existente (server_default)
products.visible_en_qr      = true   para toda fila existente (server_default)
product_toppings            = tabla vacía
cart_item_toppings          = tabla vacía
order_item_toppings         = tabla vacía
```

Sin consulta `EXISTS`/`CASE` de backfill: todo producto existente antes de esta spec es, por
definición, un producto regular visible en QR (el único estado posible antes de que existiera
`is_topping`) — mismo criterio que la migración de spec 065 (`selection_mode`).

**Rollback**: `DROP TABLE order_item_toppings, cart_item_toppings, product_toppings;` seguido de
`ALTER TABLE products DROP COLUMN is_topping, DROP COLUMN visible_en_qr;`. Las tres tablas son
aditivas y sin dependientes externos; las dos columnas no participan en ningún cálculo de
`sale_items`/facturación histórica — su eliminación no altera ningún dato ya confirmado
(Principio VII).

## Relaciones (resumen)

```text
Product 1──* ProductTopping *──1 Product (is_topping=true)
Product 1──* ProductVariant
ProductVariant 1──* VariantOptionGroup *──1 OptionGroup 1──* Option   (sabores, sin cambio)

CartItem ── product_variant_id ──> ProductVariant            (línea suelta de adición: sin cambio)
CartItem 1──* CartItemOption *──1 Option                      (sabores adjuntos, sin cambio)
CartItem 1──* CartItemTopping ── topping_product_variant_id ──> ProductVariant   (NUEVA: adición adjunta)

OrderItem (mismo patrón que CartItem, con OrderItemTopping análoga)
```

## Reglas de validación (resumen por historia de usuario)

| Regla | Dónde se aplica | Historia |
|---|---|---|
| Marcar producto como adición (`is_topping`) | `ProductCreate`/`ProductUpdate` (Pydantic) | US1 |
| Asociar adiciones a un producto, a nivel de producto | `ProductTopping`, `ProductService` | US1 |
| Nueva variante hereda adiciones del producto (no hay nada que copiar: la asociación ya es por producto) | Sin cambio adicional — consecuencia directa del modelo | US1 |
| Rechazar auto-asociación | `CheckConstraint` en `product_toppings` + validación en servicio | US1, FR-016 |
| Adición sellable como línea suelta | Ningún cambio — ruta de creación de `CartItem`/`OrderItem` ya existente | US2, FR-006/FR-007 |
| Precio de línea suelta = precio × cantidad de esa línea | Fórmula existente de `CartItem`/`OrderItem`, sin `addons_total` | US2 |
| Adición excluida del menú QR como ítem propio | `_build_menu` (filtro `Product.visible_en_qr`) | US3, FR-008 |
| Default `visible_en_qr=false` al crear una adición | `ProductService.create` (default calculado, no de columna) | US3, FR-010 |
| Selector de adiciones disponibles al personalizar en QR | `MenuProductResponse.toppings` (desde `ProductTopping`) | US3, FR-009 |
| Cantidad libre de una adición adjunta | `CartItemTopping.quantity`/`OrderItemTopping.quantity` | US3, FR-018 |
| Precio de adición siempre el de catálogo (variante principal) | Servicio de carrito/pedido al insertar `*ItemTopping` (research.md D5) | US3, FR-017 |
| Visibilidad en QR por producto (mostrar/ocultar) | `products.visible_en_qr` + endpoint existente de edición de producto | US4, FR-011 |
| Visibilidad de categoría manda sobre la de producto | `_build_menu` (`AND` de ambos flags) | US4, FR-012 |
| Solo roles administrativos cambian visibilidad/asocian adiciones | Dependencias ya existentes (`require_tenant_admin`) | US1/US4, FR-013 |
| Rechazar en el envío de pedido una adición ya no asociada | Validación de carrito al consolidar (mismo patrón que spec 128 US2 para categoría oculta) | Edge case, FR-014 |
| Pedidos/ventas confirmados no se alteran | Sin migración de `order_item_options`/`sale_items` | FR-015 |
