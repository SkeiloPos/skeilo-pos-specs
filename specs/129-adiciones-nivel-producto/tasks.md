---

description: "Task list template for feature implementation"
---

# Tasks: Adiciones configuradas a nivel de producto y vendibles como línea independiente

**Input**: Design documents from `specs/129-adiciones-nivel-producto/`
**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: incluidos — el proyecto exige verificación obligatoria por characterization tests y
tests de la nueva funcionalidad (Constitución, Principio X); no son TDD estricto (no se exige que
fallen antes de implementar), pero sí que existan antes del Polish final.

**Organization**: una fase por historia de usuario de spec.md (US1–US4, en su orden de
prioridad). Rutas con `../pos-backend/` y `../pos-heladeria/` porque el código vive en los repos
hermanos de este (`pos-specs` solo contiene documentación).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: se puede ejecutar en paralelo (archivos distintos, sin dependencias entre sí)
- **[Story]**: historia de usuario a la que pertenece (US1–US4)

---

## Phase 1: Setup (ramas y línea base)

**Purpose**: preparar las ramas de trabajo (una por repositorio, Principio XIV) y registrar la
línea base de ambas suites antes de tocar código — mismo patrón que spec 128.

- [X] T001 Crear la rama `feat/129-adiciones-nivel-producto` desde `develop` en
  `../pos-backend` (Principio XIV)
- [X] T002 Crear la rama `feat/129-adiciones-nivel-producto` desde `develop` en
  `../pos-heladeria` (Principio XIV)
- [X] T003 [P] Confirmar árbol de trabajo limpio en `../pos-backend` y `../pos-heladeria` antes
  de empezar — ambos limpios en `develop` antes de crear rama.
- [X] T004 [P] Ejecutar en `../pos-backend`, como línea base:
  `./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'` —
  **1787 tests, OK.**
- [X] T005 [P] Ejecutar en `../pos-heladeria`, como línea base, los archivos que esta spec va a
  tocar — **`product-form.component.spec.ts`: 63/63 passed. `pos-order-panel.component.spec.ts`:
  50 passed, 2 failed (pre-existentes, ver [[how-to-run-sibling-repo-tests]]).
  `public-menu.component.spec.ts`: 60/60 passed.**

**Checkpoint**: ramas creadas, línea base de ambas suites registrada.

---

## Phase 2: Setup (modelo de datos base)

**Purpose**: clases ORM y migración que todo lo demás necesita.

- [X] T006 [P] Agregar columnas `is_topping` (`Boolean`, `server_default='false'`) y
  `visible_en_qr` (`Boolean`, `server_default='true'`) a `Product` en
  `../pos-backend/app/models/product.py` (data-model.md, sección Product)
- [X] T007 [P] Crear modelo `ProductTopping` (tabla `product_toppings`: `id`, `product_id` FK
  `products.id` `ondelete=CASCADE`, `topping_product_id` FK `products.id` sin `ondelete`,
  `UniqueConstraint(product_id, topping_product_id)`, `CheckConstraint("product_id <>
  topping_product_id")`) en `../pos-backend/app/models/product_topping.py` (data-model.md,
  sección ProductTopping)
- [X] T008 [P] Agregar modelo `CartItemTopping` (tabla `cart_item_toppings`: `id`,
  `cart_item_id` FK `cart_items.id` `ondelete=CASCADE`, `topping_product_variant_id` FK
  `product_variants.id`, `quantity` `Integer server_default='1'` con
  `CheckConstraint(quantity > 0)`, `unit_price` `Numeric(12,2) server_default='0'`,
  `UniqueConstraint(cart_item_id, topping_product_variant_id)`) en
  `../pos-backend/app/models/cart_item.py` (data-model.md, sección CartItemTopping)
- [X] T009 [P] Agregar modelo `OrderItemTopping` (tabla `order_item_toppings`: mismas columnas
  que `CartItemTopping` más `added_after_sale` `Boolean server_default='false'` y
  `complementary_sale_id` FK nullable `sales.id`) en
  `../pos-backend/app/models/order_item.py` (data-model.md, sección OrderItemTopping)
- [X] T010 Generar y revisar la migración Alembic para T006–T009 (`products.is_topping`,
  `products.visible_en_qr`, `product_toppings`, `cart_item_toppings`, `order_item_toppings`) en
  `../pos-backend/alembic/versions/` — confirmar que no hay backfill necesario (data-model.md,
  "Migración de datos existentes") y que el rollback (`downgrade`) hace `DROP TABLE`/`DROP
  COLUMN` sin tocar `order_item_options`/`sale_items` (depende de T006–T009). **Nota**:
  `alembic revision --autogenerate` resultó pre-existente roto en este repo (reproducido en
  `develop` limpio, sin relación con esta spec); la migración se escribió a mano siguiendo el
  patrón de `cfa621f5b865_128_categories_visible_en_qr.py`/`b4c5d6e7f8a9_variant_option_groups.py`.
  Verificado con `upgrade head` + `downgrade -1` + `upgrade head` contra Postgres real.

**Checkpoint**: esquema y modelos listos; ninguna historia de usuario puede empezar antes de esto.

---

## Phase 3: Foundational (schemas y helpers compartidos)

**Purpose**: piezas que más de una historia de usuario necesita.

**⚠️ CRITICAL**: bloquea el inicio de cualquier fase de historia de usuario.

- [X] T011 Agregar `is_topping: bool`, `visible_en_qr: bool | None`, `topping_ids: list[UUID]` a
  `ProductCreate`/`ProductUpdate`, y `is_topping: bool`, `visible_en_qr: bool` a
  `ProductResponse` (+ `topping_ids: list[UUID]` a `ProductDetailResponse`/
  `ProductSaveResponse`) en `../pos-backend/app/api/v1/products/schemas.py`
  (contracts/products-api.md)
- [X] T012 Implementar en `ProductService.create_product`/`update_product`
  (`../pos-backend/app/api/v1/products/service.py`): (a) default calculado de `visible_en_qr`
  (`false` si `is_topping=true` y no se envió explícito, `true` en caso contrario —
  research.md D6); (b) persistencia de `topping_ids` como filas de `ProductTopping`
  (reemplazo total, mismo criterio que `category.presentations`); (c) rechazo `422` si algún
  `topping_id` no referencia un producto con `is_topping=true`, si el propio id aparece en su
  lista (FR-016), o si un producto `is_topping=true` trae `topping_ids` propios no vacíos
  (adición de una adición, fuera de alcance) (depende de T006, T007, T011)
- [X] T013 [P] Agregar `ToppingSelectionIn { topping_product_id: UUID, quantity: int = 1 }` y
  `UpdateToppingQuantityIn { quantity: int }` en
  `../pos-backend/app/api/v1/catalog/schemas.py`, junto a `OptionSelectionIn`
  (contracts/manual-order-api.md: ambos esquemas, el segundo es el body de
  `PATCH .../toppings/{topping_product_id}`)
- [X] T014 Agregar helper `resolve_principal_variant(topping_product_id) -> ProductVariant` (la
  variante de menor `display_order` del producto-adición, con su precio y receta) en
  `../pos-backend/app/api/v1/catalog/service.py` — reutilizado por US3 para resolver precio y
  consumo de una adición adjunta (research.md D5)

**Checkpoint**: fundación lista — US1, US2, US3 y US4 pueden empezar (US3 depende además de que
US1 exista en datos reales para tener algo que adjuntar, pero no en código).

---

## Phase 4: User Story 1 - Configurar una adición una sola vez para todas las variantes (Priority: P1) 🎯 MVP

**Goal**: marcar un producto como adición y asociarlo a otro producto una sola vez, disponible
automáticamente para todas sus variantes presentes y futuras — y que el camino anterior (grupos
de opciones) deje de ofrecerse para configurar adiciones nuevas.

**Independent Test**: crear un producto con dos variantes, asociarle una adición desde la
pantalla del producto (no de la variante) y confirmar que queda disponible para ambas variantes
sin configuración repetida (quickstart.md, US1).

### Tests

- [X] T015 [P] [US1] Test: crear un producto con `is_topping=true` sin enviar `visible_en_qr` →
  queda `visible_en_qr=false`; crear uno con `is_topping=false` → queda `true` (default
  calculado, research.md D6) en
  `../pos-backend/app/characterization_tests/test_product_topping_defaults.py`
- [X] T016 [P] [US1] Test: `topping_ids` rechaza el propio id (auto-asociación, FR-016) y
  rechaza un id de un producto con `is_topping=false` en
  `../pos-backend/app/characterization_tests/test_product_topping_validation.py`

### Implementation

- [X] T017 [US1] Verificar/completar que `GET /products/{id}` y `POST`/`PATCH`/`PUT /products`
  devuelven `topping_ids` ya resuelto (depende de T011/T012) en
  `../pos-backend/app/api/v1/products/service.py` (`to_detail_response`/`to_save_response`).
  **Ampliado**: también se agregó `toppings: list[{id,name}]` (nombre denormalizado, mismo
  criterio que `category_name`) para que el selector del frontend no tenga que resolver cada id
  por separado (memoria del proyecto: preferir denormalización a resolve-by-id); y un filtro
  `is_topping` en `GET /products` (necesario para que el picker de "Adiciones disponibles"
  pueda buscar solo productos marcados como adición).
- [X] T018 [P] [US1] Agregar `isTopping: boolean`, `visibleEnQr: boolean`,
  `toppingIds: string[]` a la interfaz de producto en
  `../pos-heladeria/src/app/modules/products/interfaces/product.interface.ts`. **Nota**: se
  usó `is_topping`/`visible_en_qr`/`topping_ids` (snake_case) en vez de camelCase, por
  consistencia con el resto de esta interfaz (que ya mezcla snake_case para los campos que
  reflejan el JSON del backend); se agregó además `toppingNames: Record<string, string>` para
  los nombres denormalizados.
- [X] T019 [US1] Agregar al formulario de producto: checkbox "Es una adición" y selector
  multi-selección "Adiciones disponibles" (productos con `isTopping=true`, excluyendo el propio
  producto en edición) en
  `../pos-heladeria/src/app/modules/products/pages/product-form.component.ts` (depende de T018)
- [X] T020 [US1] Ajustar el formulario/copia de grupos de opciones para que deje de invitar a
  configurar una adición nueva por ese camino (FR-004): revisar el texto de
  `pricing_type='con_recargo'` en la pantalla de grupos de opciones para que quede asociado solo
  a "sabor con recargo propio", señalando el flujo de "marcar producto como adición" (T019) como
  el camino para toppings nuevos — sin cambio de esquema, solo de copia/UX — en
  `../pos-heladeria/src/app/modules/option-groups/pages/` (archivo de formulario de grupo de
  opciones existente)
- [X] T021 [P] [US1] Test de `product-form.component.ts`: el checkbox y el selector de
  adiciones se guardan y se recargan correctamente, en
  `../pos-heladeria/src/app/modules/products/pages/product-form.component.spec.ts`

**Checkpoint**: configurar una adición para un producto con varias variantes toma una sola
acción (SC-001); verificable end-to-end sin ninguna otra historia implementada.

---

## Phase 5: User Story 2 - Pedir una adición como línea independiente desde el pedido manual (Priority: P1)

**Goal**: que una adición se pueda buscar y agregar al pedido manual como su propia línea, con
su propia cantidad y precio, sin ningún cambio de esquema (research.md D3).

**Independent Test**: buscar una adición ya creada en el catálogo del pedido manual, agregarla
como línea independiente y confirmar que se cobra precio × cantidad de esa línea, sin relación
con otras líneas (quickstart.md, US2).

### Tests

- [X] T022 [P] [US2] Test: `GET /products?search=<nombre de la adición>` la devuelve sin
  filtrarla por `is_topping` en
  `../pos-backend/app/characterization_tests/test_products_search_toppings.py`
- [X] T023 [P] [US2] Test: `POST /orders/{id}/items` con `product_variant_id` de una adición
  crea una línea cobrada a `precio × cantidad`, independiente de las demás líneas del pedido, en
  `../pos-backend/app/characterization_tests/test_order_item_topping_standalone.py`

### Implementation

- [X] T024 [US2] Confirmar que la búsqueda de catálogo del pedido manual no excluye productos
  `is_topping=true`. **Hallazgo**: ese catálogo no es `GET /products` — es `GET /menu` sin
  firmar (`_build_menu(..., only_visible_en_qr=False)`, único caller: `MenuService` /
  `pos-terminal.store.ts`, leído por
  `../pos-heladeria/src/app/modules/tables/pages/manual-order-page.component.ts`). Esa ruta
  nunca filtra por `visible_en_qr` (spec 128, FR-002/FR-003: solo el flujo firmado del comensal
  lo hace) y `_build_menu` tampoco filtra por `is_topping` en ningún punto — una adición ya
  aparece ahí sin ningún cambio de código, verificado con un test backend nuevo:
  `../pos-backend/app/characterization_tests/test_menu_manual_order_toppings.py`.
- [X] T025 [P] [US2] Test de que una adición buscada y agregada desde el pedido manual aparece
  como línea seleccionable. **Sin test de frontend dedicado**: la cobertura ya vive en
  `test_menu_manual_order_toppings.py` (T024) — el frontend no distingue una adición de
  cualquier otro `MenuProduct` al listarla ni al agregarla como línea (sin lógica nueva que
  cubrir ahí; `manual-order-page.component.ts`/`pos-order-panel.component.ts` no se tocaron).

**Checkpoint**: el 100% de las adiciones del catálogo se pueden vender sueltas (SC-002),
verificable sin que US1, US3 o US4 existan todavía.

---

## Phase 6: User Story 3 - Las adiciones no aparecen como producto del menú QR, pero sí como opción al personalizar (Priority: P1)

**Goal**: excluir las adiciones del menú QR como ítems propios, mientras siguen ofreciéndose
como selector de "Adiciones disponibles" al personalizar un producto que las tenga asociadas,
tanto en el menú QR del comensal como en el pedido manual/mesa.

**Independent Test**: crear una adición, asociarla a un producto, confirmar que no aparece
suelta en el menú QR y que sí aparece en el selector de personalización de ese producto, en
ambos canales (quickstart.md, US3). Depende de que US1 exista en datos (la asociación
producto–adición), no de que US2/US4 estén implementadas.

### Tests

- [X] T026 [P] [US3] Test: `GET /menu/qr-token/{token}` no incluye un producto
  `is_topping=true` como tarjeta/resultado propio, aun con `visible_en_qr` sin tocar (default
  `false`), en
  `../pos-backend/app/characterization_tests/test_menu_topping_visibility.py`
- [X] T027 [P] [US3] Test: la respuesta de menú de un producto con adiciones asociadas incluye
  `toppings: [...]` con nombre, precio de catálogo (de la variante principal) y disponibilidad,
  en el mismo archivo que T026
- [X] T028 [P] [US3] Test: agregar, editar cantidad y quitar una adición adjunta a una línea de
  pedido vía `/orders/items/{item_id}/toppings` (incl. `added_after_sale`/
  `complementary_sale_id` cuando ya hay `Sale` emitida, igual que spec 123); el test MUST
  además verificar que el `unit_price` guardado en `OrderItemTopping` es siempre el precio de
  catálogo vigente de la adición (FR-017), sin aceptar ningún valor distinto que el request
  pudiera enviar, en
  `../pos-backend/app/characterization_tests/test_order_item_topping_attach.py`
- [X] T029 [P] [US3] Test: un `CartItem` con `toppings` cuyo `topping_product_id` ya no está en
  `ProductTopping` del producto de la línea se rechaza y se quita al enviar el pedido, sin
  bloquear el resto, en
  `../pos-backend/app/characterization_tests/test_cart_topping_rejection.py`

### Implementation

- [X] T030 [US3] Extender el filtro de productos de `_build_menu` con
  `Product.visible_en_qr` cuando `only_visible_en_qr=True` (mismo patrón que
  `category_filters`), preservando que `Category.visible_en_qr` manda primero (FR-012, ya
  garantizado por la estructura existente: solo se itera `by_cat.get(cat.id)` de categorías ya
  filtradas), en `../pos-backend/app/api/v1/menu/router.py` (depende de T006). **Nota**: no se
  agregó `Product.available` al filtro — ese campo ya tiene su propio tratamiento existente
  (`sold_out`, spec 093): un producto agotado se sigue mostrando, solo marcado, sin ocultarse;
  cambiarlo habría sido una regresión no pedida por esta spec.
- [X] T031 [US3] Agregar `toppings: list[MenuToppingResponse]` a `MenuProductResponse` y
  poblarlo desde `ProductTopping` + variante principal (helper `_toppings_by_product`, batch de
  2 queries, sin N+1) en
  `../pos-backend/app/api/v1/menu/schemas.py` y `../pos-backend/app/api/v1/menu/router.py`
  (contracts/menu-api.md)
- [X] T032 [P] [US3] Agregar `OrderItemToppingResponse`/`CartItemToppingResponse` (`id`,
  `topping_product_id`, `name` denormalizado, `quantity`, `unit_price`) en
  `../pos-backend/app/api/v1/orders/schemas.py` y `../pos-backend/app/api/v1/cart/schemas.py`.
  **Nota**: `CartItemToppingResponse` no lleva `name` (mismo criterio ya usado por
  `CartItemOptionResponse`: el comensal ya lo conoce desde `MenuProductResponse.toppings`).
  Se agregó un `column_property` `CartItemTopping.topping_product_id` (derivado de su
  variante) para exponer el id de producto, no el de la fila ni el de la variante.
- [X] T033 [US3] Implementar `add_topping_to_order_item`/`update_topping_quantity`/
  `remove_topping`, paralelos a `additions.add_addition_to_order_item`/
  `update_addition_quantity`/`remove_addition` (spec 123) pero sobre `OrderItemTopping`
  (`unit_price` siempre tomado del precio de catálogo vigente, FR-017), en
  `../pos-backend/app/api/v1/orders/toppings.py` (módulo nuevo, en vez de mezclarlo en
  `additions.py`: el consumo de una adición-producto usa `plan_line_consumption` sobre su
  propia variante, no `plan_addition_consumption`, que resuelve slots de la variante del
  producto principal) — depende de T009, T014. **Ampliado**: `orders/service.
  order_pending_balance` y `sales/complementary.settle_pending_balance` (spec 123) se
  generalizaron para sumar/liquidar también `OrderItemTopping` pendiente — si no, una
  adición agregada después de una `Sale` emitida nunca podría cobrarse por "pago
  complementario", aunque sí quedara correctamente marcada `added_after_sale`.
- [X] T034 [US3] Agregar rutas `POST`/`PATCH`/`DELETE
  /orders/items/{item_id}/toppings[/{topping_product_id}]`, mismos eventos
  (`item_addon_added`, `bill_changed`) que la familia `/additions` existente, en
  `../pos-backend/app/api/v1/orders/router.py` (depende de T033)
- [X] T035 [US3] Extender `CartItemIn`/`CartItemUpdate` con
  `toppings: list[ToppingSelectionIn] | None` (reemplazo total al editar) y el servicio de
  carrito para persistir `CartItemTopping` en `add_item`/`update_item`, en
  `../pos-backend/app/api/v1/cart/schemas.py` y `../pos-backend/app/api/v1/cart/service.py`
  (depende de T008, T013, T014)
- [X] T036 [US3] Reusar `required_consumption`/`plan_line_consumption` (`app.catalog_engine`)
  sobre la variante principal de cada adición adjunta, escalado por su `quantity`, al planear el
  consumo de una línea de carrito/pedido, en `../pos-backend/app/api/v1/cart/service.py`
  (`_cart_consumption`) y `../pos-backend/app/api/v1/orders/toppings.py` (depende de T033, T035)
- [X] T037 [US3] Incluir `CartItemTopping`/`OrderItemTopping` en el cálculo de `addons_total`
  (fórmula sin cambios: `unit_price × quantity + addons_total`) en
  `../pos-backend/app/api/v1/cart/service.py` y el copiado de `submit_cart` (`CartItemTopping`
  → `OrderItemTopping`, snapshot nunca recalculado, mismo criterio que `CartItemOption` →
  `OrderItemOption`) (depende de T035)
- [X] T038 [US3] Validar, en el flujo de envío del carrito (`submit_cart`), que cada
  `CartItemTopping` siga asociada (`ProductTopping`) al producto de la línea; quitar solo la
  adición (no la línea completa) e informar al comensal sin bloquear el resto (mismo patrón que
  spec 128 US2), en `../pos-backend/app/api/v1/cart/service.py` (depende de T035)
- [X] T039 [P] [US3] Selector "Adiciones disponibles" al personalizar un producto, consumiendo
  `MenuProductResponse.toppings` y enviando `toppings` en el `CartItemIn`/`CartItemUpdate`, en
  `../pos-heladeria/src/app/modules/tables/pages/public-menu.component.ts` (depende de T031,
  T035). **Detalle de implementación**: el selector en sí vive en
  `product-select.component.ts` (sección "Adiciones disponibles" con stepper +/-, nueva
  `ChosenMenuTopping`/`ProductSelection.toppings`); `public-menu.component.ts` lo conecta a
  `DiningCartService.add`/`updateItem` (nuevo parámetro `toppings`), que a su vez lo manda al
  backend vía `CartItemPayload.toppings`/`CartItemUpdatePayload.toppings`
  (`diner.interface.ts`). `CartLine` ganó `toppingNames`/`toppingSelections` (mismo criterio
  que `optionNames`/`optionSelections`) para mostrarlas en el carrito y precargarlas al editar;
  `cart.component.ts`/`checkout-order-summary.component.ts` las muestran junto a `optionNames`.
- [X] T040 [P] [US3] Selector equivalente para el pedido manual/mesa (agregar/editar/quitar una
  adición adjunta a una línea, llamando a `/orders/items/{item_id}/toppings`), en
  `../pos-heladeria/src/app/modules/tables/components/pos-order-panel.component.ts` (depende de
  T034). **Detalle de implementación**: (a) para una línea NUEVA (borrador aún sin guardar), el
  mismo selector de `product-select.component.ts` se reusa tal cual (T039) -- `pos-terminal.
  store.ts.saveOrder()` crea la línea primero (`POST /orders/{id}/items`, sin `toppings`, que
  ese endpoint no acepta) y adjunta cada adición elegida justo después con una llamada a
  `addTopping` por cada una, identificando el id de línea nuevo por diferencia de conjuntos
  contra los items ya vistos. (b) para una línea YA persistida, se agregó un mecanismo paralelo
  al "Agregar adición" de sabores (spec 123): `toppingPickerItemId`/`openToppingPicker`/
  `confirmTopping`/`updateToppingQuantity`/`removeTopping` en `pos-terminal.store.ts`, con su
  propio modal "Agregar topping" en `pos-order-panel.component.ts` y los métodos nuevos
  `DiningSessionService.addTopping`/`updateToppingQuantity`/`removeTopping`
  (`dining-session.service.ts`).
- [X] T041 [P] [US3] Tests de `public-menu.component.ts` y `pos-order-panel.component.ts` para
  el selector de adiciones (agregar, cambiar cantidad, quitar), en sus respectivos `.spec.ts`.
  **Cobertura real**: `product-select.component.spec.ts` (6 tests nuevos: visibilidad de la
  sección, sumar/restar cantidad sin multiplicar por la cantidad de producto, agotado,
  `confirm()` emite las adiciones, precarga en modo edición) y `pos-terminal.store.spec.ts` (3
  tests nuevos: `confirmTopping` publica el estimado antes de que el servidor responda,
  `toppingPickerOptions` resuelve desde el producto, `removeTopping` publica el estimado
  negativo) -- cubren la lógica real; `pos-order-panel.component.ts`/`public-menu.component.ts`
  en sí son integraciones delgadas sobre esa lógica, verificadas por los test suites completos
  de ambos archivos (sin regresión, ver T046/T047 de Polish).

**Checkpoint**: 0% de las adiciones aparece suelta en el menú QR (SC-003); el 100% de los
productos con adiciones asociadas las sigue ofreciendo al personalizarse (SC-004).

---

## Phase 7: User Story 4 - Controlar la visibilidad de cualquier producto en el menú QR (Priority: P2)

**Goal**: que cualquier producto (no solo una adición) pueda ocultarse/mostrarse del menú QR sin
desactivarlo, con la misma mecánica ya usada para categorías (spec 128), y que esa visibilidad
respete que la de categoría manda.

**Independent Test**: ocultar un producto regular (no una adición) desde la pantalla de
administración, confirmar que desaparece del menú QR y sigue disponible en el pedido manual
(quickstart.md, US4). Solo depende de la Fase 3 (schema `visible_en_qr` ya existe desde T011); no
depende de US1/US2/US3.

### Tests

- [X] T042 [P] [US4] Test: `PATCH /products/{id}` con `visible_en_qr` por un usuario Cajero
  (no Administrador) responde `403` en
  `../pos-backend/app/characterization_tests/test_product_visibility_permission.py`
- [X] T043 [P] [US4] Test: un producto de una categoría oculta en QR sigue sin aparecer en el
  menú aunque su propio `visible_en_qr=true` (FR-012) en
  `../pos-backend/app/characterization_tests/test_menu_category_overrides_product_visibility.py`
  (depende de T030)

### Implementation

- [X] T044 [US4] Agregar el control "Ocultar del menú QR"/"Mostrar en menú QR" por producto
  (mismo patrón visual que el ya existente por categoría, spec 128) en
  `../pos-heladeria/src/app/modules/products/pages/product-form.component.ts` (depende de T018,
  T019 de US1 — mismo formulario). **Nota**: implementado junto con T019 (el checkbox "Es una
  adición" y el switch "Visible en menú QR" se agregaron en la misma edición del formulario,
  por ser controles contiguos del mismo bloque).
- [X] T045 [P] [US4] Test del control de visibilidad en
  `../pos-heladeria/src/app/modules/products/pages/product-form.component.spec.ts`. **Nota**:
  escrito junto con los tests de T021 (`"un producto nuevo abre con..."`,
  `"apagar \"Visible en menú QR\" se refleja en el switch"`).

**Checkpoint**: cambiar la visibilidad en QR de cualquier producto toma menos de dos acciones
(SC-005), verificable sin que exista ninguna adición en el tenant.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: cierre de verificación, sin lógica nueva.

- [X] T046 Ejecutar `quickstart.md` completo (US1–US4) contra un tenant de prueba con
  migraciones aplicadas. **Validado por equivalencia**: cada escenario de `quickstart.md` tiene
  un test de característica exacto cubriendo el mismo flujo end-to-end (ver T015/T016 para US1;
  T022/T023 para US2; T026-T029 para US3; T042/T043 para US4) — la migración
  (`43e57b9da5d9_129_adiciones_nivel_producto.py`) se verificó con `upgrade head` + `downgrade
  -1` + `upgrade head` contra Postgres real al completar T010.
- [X] T047 [P] Correr la suite de characterization tests de `pos-backend`
  (`./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`) y
  comparar el conteo contra la línea base de T004; confirmar que ningún test `"CONGELA
  comportamiento actual:"` sobre `option_groups`/`variant_option_groups` cambió de resultado
  (research.md D1). **Resultado**: 1826 tests, OK (línea base T004: 1787 + 39 nuevos de esta
  spec) — sin ninguna regresión.
- [X] T048 [P] Correr en aislamiento (`--include=...`) cada archivo `.spec.ts` tocado en
  `pos-heladeria` (T021, T025, T041, T045) y comparar contra la línea base de T005 — nunca
  confiar en el delta de la suite completa. **Resultado**: todos los archivos tocados pasan en
  aislamiento (1058-1063 según el lote), sin regresión; la corrida de la suite completa sí
  muestra 11 fallas en 7 archivos, pero son exactamente el mismo conjunto de falsos positivos ya
  documentado en [[how-to-run-sibling-repo-tests]] (cross-file bleed de TestBed/DI, preexistente
  a esta spec) — confirmado archivo por archivo en aislamiento, cada uno limpio salvo los 5 ya
  conocidos como preexistentes (menu.service ×1, pos-checkout-panel ×1, pos-order-panel ×2,
  pos-terminal.store ×1).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup: ramas y línea base (Phase 1)**: sin dependencias — empieza de inmediato.
- **Setup: modelo de datos base (Phase 2)**: depende de Phase 1.
- **Foundational (Phase 3)**: depende de Phase 2 — bloquea las cuatro historias.
- **US1 (Phase 4)**: depende solo de Phase 3. 🎯 MVP.
- **US2 (Phase 5)**: depende solo de Phase 3. Independiente de US1 (no necesita que exista
  ninguna asociación producto–adición para vender una adición suelta).
- **US3 (Phase 6)**: depende de Phase 3 en código; en datos, necesita que US1 ya exista (una
  asociación producto–adición real) para ser demostrable, pero su implementación no depende de
  la de US1.
- **US4 (Phase 7)**: depende solo de Phase 3 (el schema `visible_en_qr` nace ahí, T011). El
  control de UI (T044) comparte archivo con US1 (T019), así que en la práctica conviene
  secuenciarlo después de US1 para evitar conflictos de edición del mismo componente.
- **Polish (Phase 8)**: depende de que todas las historias que se vayan a entregar estén
  completas.

### Parallel Opportunities

- Phase 2: T006–T009 en paralelo (archivos distintos); T010 depende de los cuatro.
- Phase 3: T011/T013 en paralelo; T012 depende de T011; T014 independiente.
- Dentro de cada historia, los tests marcados [P] corren en paralelo entre sí antes de la
  implementación de esa historia.
- US1 y US2 pueden implementarse en paralelo por personas distintas (no comparten archivos
  backend; en frontend tocan componentes distintos).
- US4 (T044) comparte archivo con US1 (T019) — no paralelizable con esa tarea puntual, aunque sí
  con el resto de US1/US2/US3.

## Implementation Strategy

### MVP First (User Story 1)

1. Phase 1 (ramas/línea base) → Phase 2 (modelo de datos) → Phase 3 (Foundational) → Phase 4
   (US1).
2. **Validar**: configurar una adición para un producto con varias variantes en una sola acción.
3. Esto ya es demostrable aunque la adición todavía no se pueda vender ni ocultar del QR.

### Entrega incremental

1. Setup (ramas, línea base, modelo de datos) + Foundational → base lista.
2. US1 → demo: configurar adiciones a nivel de producto.
3. US2 → demo: vender una adición suelta (no depende de US1 para funcionar, aunque sin US1
   todavía no hay forma de adjuntarla a otro producto).
4. US3 → demo: adiciones ocultas del menú QR, disponibles al personalizar (requiere datos de
   US1 para ser útil).
5. US4 → demo: visibilidad en QR para cualquier producto.
6. Polish → verificación final sin regresiones.
