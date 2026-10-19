# Research: Adiciones configuradas a nivel de producto y vendibles como línea independiente

Este documento resuelve, antes del diseño de datos (`data-model.md`), los puntos técnicos que el
spec deja abiertos o que la exploración del código existente obligó a revisar.

## D1. Los grupos de opciones para sabores NO se mueven a nivel de producto

**Hallazgo durante este plan**: `VariantOptionGroup` (`app/models/variant_option_group.py`)
documenta explícitamente, en su propio docstring, que vive en la variante *a propósito*: el
mínimo/máximo de sabores a elegir y el insumo que descuenta cada uno cambian con el tamaño ("la
ensalada pequeña elige 1 sabor y descuenta 60 g; la mediana elige 2 y descuenta 120 g de cada
uno"). La primera versión de spec.md generalizaba "mover la configuración a nivel de producto" a
sabores también (FR-005 original), lo que habría eliminado esa flexibilidad sin que el usuario la
hubiera pedido — su queja original era exclusivamente sobre adiciones ("me obliga a configurar un
topping por cada variante").

- **Decision**: revertir esa generalización. `VariantOptionGroup` no cambia: sigue siendo el
  enlace variante → grupo de opciones, con su propio `min_select`/`max_select`/
  `quantity_per_option` por variante. El spec se corrigió (FR-005) para reflejar esto antes de
  completar este plan.
- **Rationale**: es exactamente lo que el usuario pidió (resolver la duplicación para
  *adiciones*) sin tocar un comportamiento deliberado y ya en producción para *sabores*.
- **Alternatives considered**: mover también el enlace de sabores a producto, aceptando perder la
  variación por tamaño — descartado porque ningún requisito de negocio lo pedía y habría sido una
  regresión no autorizada (Principio II de la constitución).

## D2. Cómo se exponen las "adiciones disponibles" de un producto

**Decision**: tabla puente nueva `product_toppings` (`product_id` → el producto que ofrece la
adición, `topping_product_id` → el producto marcado `is_topping=true`). Reemplaza, para
adiciones, al enlace `VariantOptionGroup`; no reutiliza `OptionGroup`/`Option` en absoluto.

**Rationale**: una adición ya es un producto completo (FR-001); no tiene sentido envolverla otra
vez en una `Option` (que es "un valor dentro de un grupo", pensado para sabores) solo para
declarar la relación. Una tabla puente simple, directa entre dos productos, es el modelo más
cercano a "este producto ofrece esta adición".

**Alternatives considered**: reutilizar `OptionGroup`/`Option` con un `pricing_type` nuevo que
apunte a un producto en vez de tener su propio precio — descartado en la decisión de modelado del
spec (ver spec.md, "Decisión de modelado"), porque mantenía la dependencia de Option/OptionGroup
que el usuario pidió eliminar para adiciones.

## D3. Cómo se vende una adición como línea independiente (US2)

**Decision**: ningún cambio de esquema. Una adición es un producto con al menos una variante
(mismo patrón `ensure_default_variant`/"Presentación única" que ya aplica a cualquier producto
sin tamaños, spec 083/084). Vender una adición suelta es exactamente crear un `CartItem`/
`OrderItem` con `product_variant_id` apuntando a la variante de la adición — la misma ruta que ya
usa cualquier producto del catálogo.

**Rationale**: es la consecuencia directa de que "un topping también es un producto" (spec.md).
El catálogo de búsqueda del pedido manual (`GET /products?search=...`) ya no filtra por ningún
indicador especial, así que una adición aparece ahí sin cambios en ese endpoint.

**Alternatives considered**: ninguna — introducir un tipo de línea distinto para "producto
vendido suelto" habría sido una complejidad no justificada por el spec.

## D4. Cómo se adjunta una adición a OTRA línea (US1/US3, el "+ Gomitas" de un Granizado)

**Decision**: dos tablas espejo nuevas, `cart_item_toppings` y `order_item_toppings`, paralelas a
`cart_item_options`/`order_item_options` pero con `topping_product_variant_id` (FK a
`product_variants`, de la variante de la adición) en vez de `option_id`. Columnas: `quantity`
(FR-018, cantidad libre), `unit_price` (snapshot al agregarla — ver D5), y, en la tabla de
`order_item_toppings`, `added_after_sale`/`complementary_sale_id`, replicando exactamente el
mecanismo ya existente de `OrderItemOption` (spec 123) para que una adición agregada después de
emitida la venta siga pudiendo liquidarse con un pago complementario.

**Rationale**: la adición adjunta sigue comportándose, de cara al cobro y al recibo, igual que
una adición "con_recargo" de hoy (FR-007/Assumptions: cobro total de línea, no multiplicado por la
cantidad del producto principal — regla de spec 117 que esta spec no reabre). Replicar la
estructura ya validada de `OrderItemOption`/`CartItemOption` — en vez de generalizarla con una
columna `product_variant_id` opcional sobre la misma tabla — evita condicionar la lectura de cada
fila existente a "¿esto es una opción o un producto?" y mantiene los dos mecanismos
(opción-adjunta para sabores, producto-adjunto para adiciones) auditables por separado.

**Alternatives considered**: (a) agregar una columna `topping_product_variant_id` nullable
directamente en `cart_item_options`/`order_item_options`, alternativa a `option_id` — descartada
porque mezclaría dos conceptos distintos (opción de grupo vs. producto adjunto) en la misma fila,
obligando a un `CHECK` de "exactamente una de las dos" y a que todo lector existente de esa tabla
aprenda a ignorar la columna nueva; (b) no soportar adjuntar una adición en absoluto, solo venderla
suelta — descartada porque habría sido una regresión frente al "+ Gomitas" que el negocio ya
ofrece hoy (confirmado con el usuario, clarificación de spec.md sobre el selector de
personalización en QR).

`addons_total` (ya existente en `CartItem`/`OrderItem`, spec 089) se calcula sumando tanto las
filas `per_line=true` de `*_item_options` (adiciones heredadas del mecanismo anterior, mientras no
se migren) como el total de `*_item_toppings` — ningún cambio de fórmula, solo una fuente más que
sumar.

## D5. Qué precio y qué receta usa una adición cuando se adjunta a otra línea

El spec (FR-017) ya fijó que el precio de una adición es siempre su precio de catálogo, nunca un
recargo distinto por producto. Queda abierto qué pasa si la adición tiene más de una variante
(presentación) — el spec permite explícitamente que una adición tenga sus propias variantes
(Edge Cases, Assumptions).

- **Decision**: cuando se adjunta una adición a otra línea (selector de personalización en QR,
  selector equivalente en pedido manual), se usa la variante de **menor `display_order`** de esa
  adición (su variante "principal") para el precio y para la receta de insumos a consumir. Si la
  adición necesita distintas presentaciones vendibles por separado con precios distintos, el
  camino es venderla como línea independiente (US2), donde quien atiende elige la variante
  explícitamente — igual que con cualquier producto.
- **Rationale**: evita bloquear la implementación por un caso (adición con variantes) que el spec
  no pidió resolver para el flujo "adjunta"; es consistente con el patrón ya existente
  (`ensure_default_variant`/`display_order`) para resolver "la" variante de un producto cuando
  solo hace falta una.
- **Alternatives considered**: exponer un selector de variante dentro del selector de adiciones
  (elegir "Gomitas - grande" como adjunta) — descartado como alcance adicional no pedido; puede
  revisitarse en una spec futura si el negocio necesita adiciones con presentaciones distintas
  ofrecidas como adjuntas.

Consumo de insumos de una adición adjunta: se reutiliza `load_recipe`/`plan_line_consumption`
(`app.catalog_engine`) sobre la variante principal de la adición, escalado por la `quantity`
elegida — exactamente la misma función que ya calcula el consumo de cualquier producto vendido,
sin necesidad de lógica nueva en el motor.

## D6. Visibilidad en menú QR a nivel de producto (US4) y default para adiciones (US3)

**Decision**: columna `products.visible_en_qr` (Boolean, mismo tipo y patrón que
`categories.visible_en_qr`, spec 128). A diferencia de esa columna (que tiene
`server_default="true"` fijo), el valor por defecto de `visible_en_qr` para un producto nuevo se
calcula en `ProductService`/`ProductCreate` según `is_topping`: `false` si `is_topping=true`,
`true` en caso contrario — igual que el precedente ya documentado para `OptionGroupCreate.
selection_mode` (spec 065: "sí existe un valor de negocio razonable por defecto").
`server_default` a nivel de columna queda en `"true"` (protege cualquier INSERT que no pase por
el servicio, p. ej. fixtures/scripts) — el servicio es quien aplica el default condicionado.

El filtro del menú público (`_build_menu`, `app/api/v1/menu/router.py`) ya combina
`Category.active AND Category.visible_en_qr` cuando `only_visible_en_qr=True`; se extiende a
`AND Product.active AND Product.available AND Product.visible_en_qr`, preservando que la
visibilidad de categoría manda (FR-012): si la categoría está oculta, no importa el valor del
producto.

**Rationale**: reutilizar el patrón ya construido y probado en spec 128 en vez de inventar uno
nuevo; el cálculo de default en servicio (no en columna) es el mismo patrón ya usado para
`selection_mode` cuando el valor por defecto depende de otro campo de la misma creación.

## D7. Migración de datos existentes

Ninguna automática (ya documentado en spec.md, Assumptions). La migración de Alembic solo:
- agrega `products.is_topping` (`server_default='false'`) y `products.visible_en_qr`
  (`server_default='true'`) — toda fila existente queda como producto regular visible en QR, sin
  cambio de comportamiento (Principio VII);
- crea `product_toppings`, `cart_item_toppings`, `order_item_toppings` vacías.

**Rollback**: `DROP TABLE` de las tres tablas nuevas (aditivas, sin dependientes) y `DROP COLUMN`
de `is_topping`/`visible_en_qr` — ninguna de las dos pérdidas afecta datos de pedidos/ventas ya
confirmados, que viven en `order_item_options`/`sale_items` sin tocar.
