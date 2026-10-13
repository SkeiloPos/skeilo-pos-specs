---

description: "Tareas de la spec 117 — cantidad de adiciones como total de línea, no multiplicador por producto (US1–US4)"
---

# Tasks: Cantidad de adiciones como total de línea, no multiplicador por producto

**Input**: Documentos de diseño de `/specs/117-adiciones-cantidad-total-linea/`
**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md) (D1–D8), [data-model.md](./data-model.md), [contracts/](./contracts/) (`line-pricing-per-line-cantidad.md`, `option-selection-validation.md`, `cart-item-auto-adjust.md`), [quickstart.md](./quickstart.md)

**Tests**: el proyecto usa *characterization tests* (`app/characterization_tests/`, `python -m unittest`, sesiones SQLite en memoria vía `fixtures.py`/`orders_fixtures.py`/`cart_fixtures.py::new_session`) como árbitro de comportamiento (Principio III); `pos-heladeria` usa `ng test` (Vitest). Las tareas de prueba de **backend** van antes de la implementación de cada historia y deben fallar contra el código actual. En **frontend** cada tarea incluye su `.spec.ts`. Los tests que hoy congelan el *bug* se actualizan **en el mismo commit que la corrección**, citando **A-126** (ver T001), nunca en silencio (Principio III).

**Organización**: las tareas se agrupan por historia de usuario en el orden de prioridad de `spec.md` (US1 P1 → US2 P1 → US3 P2 → US4 P2). Todas las rutas y números de línea fueron verificados contra el código real de `pos-backend` y `pos-heladeria` (rama `develop`, árbol limpio) el 2026-10-13 — **no** contra una lectura de `plan.md`/`research.md` en abstracto (Principio III).

## Hallazgos de esta fase que corrigen `research.md`/`plan.md` (verificados contra el código, no se reabre la fase de planeación por esto — son detalle de implementación, Principio XI)

1. **Hay 7 call-sites de escritura, no 6/4**: `plan.md` ("Scale/Scope") lista 4 call-sites "folded" (`consolidation.py`, `orders/service.py`, `sales/service.py`, `kitchen.py`) y `research.md` D2 lista 6 call-sites de `load_valid_options` (los mismos 4 + `cart/service.py::add_item`/`::update_item`). Ambos **omiten** `orders/checkout.py::compute_draft_preview` (línea 418-452): construye su propio `SaleLine` con `unit_price=compute_line_price(...)` "folded" (sin `addons_total`) para el total que `manual-order-page.component.ts` muestra como **"total real"** antes de crear un pedido manual (`pos-terminal.store.ts:88`, `loadDraftPreview()`) — es un séptimo call-site que necesita exactamente el mismo recableo que los otros 4, o el borrador y el pedido real divergirían para una línea "cantidad" fuera del Menú QR (T022). También le falta el parámetro `quantity` de D2 para los topes escalados (sí estaba en la lista de D2, pero sin el recableo de D1 el bug persiste).
2. **`orders/kitchen.py` (reemplazo) también necesita `quantity` para los topes (D2)**: `research.md` D2 no lo lista entre los 6 call-sites de `load_valid_options`, pero el reemplazo de un ítem anulado (línea 129-131) valida la selección del ítem nuevo con su propia cantidad (`data.replacement.quantity`) — mismo caso que los demás (T021).
3. **La lista final de "tests de characterization afectados" de `research.md` apunta a dos archivos que no necesitan cambios y a uno equivocado**: `test_catalog_line_pricing.py` (clase `AddonsPerLineTests`) y `test_catalog_consumption_plan.py` (clase `AddonsPerLineConsumptionTests`) ya cubren `compute_unit_price`/`compute_addons_total`/`line_total`/`plan_line_consumption` para `ChosenOption(per_line=True)` **de forma abstracta**, sin que `core.py`/`consumption.py` sepan nada de `selection_mode` — no necesitan casos nuevos (T016). El archivo real donde viven los topes fijos de `max_quantity_per_option`/`max_total_quantity` es `test_catalog_option_groups_quantity.py` (clase `QuantityCapsTests`, líneas 203-243), **no** `test_catalog_option_groups_selection_mode.py` (ese archivo solo prueba CRUD del grupo, sin tocar `validate_option_selection`) — ver T007.
4. **De los tres tests que `research.md` dice que "documentan el bug"**, solo dos lo hacen de verdad: `test_confirmar_una_orden_completa_descuenta_el_total_multiplicado` y `test_cobrar_una_venta_de_mostrador_completa_descuenta_el_total_multiplicado` (ambos en `test_catalog_option_groups_quantity.py`) ejercitan `create_order`/un snapshot de venta con la multiplicación real por cantidad de producto. `test_precio_de_linea_multiplica_extra_price_por_cantidad` (línea 134, mismo archivo) prueba `compute_line_price` con la cantidad **propia de la opción** (FR-002, no afectada por esta spec) — su nombre es engañoso pero su aserción sigue siendo correcta; no se modifica (T016).

---

## Formato: `[ID] [P?] [Story] Descripción`

- **[P]**: puede ejecutarse en paralelo (archivo distinto, sin dependencia de una tarea sin terminar)
- **[Story]**: a qué historia de usuario pertenece (US1–US4)
- Cada tarea incluye la ruta exacta del archivo, relativa a `../pos-backend`, `../pos-heladeria` o `pos-specs` (esta carpeta) según corresponda

## Convenciones de ruta

- `../pos-backend/app/...` — API FastAPI + SQLAlchemy (Python 3.14). Tests: `python -m unittest discover -s app/characterization_tests -p 'test_*.py'` desde `../pos-backend`; un módulo suelto con `python -m unittest app.characterization_tests.<modulo> -v`.
- `../pos-heladeria/src/app/...` — SPA Angular 21 (TypeScript); `npx ng test --watch=false --browsers=ChromeHeadless --include='<glob>'`. Abreviatura: `tables/` = `../pos-heladeria/src/app/modules/tables/`.
- Sin prefijo — archivo dentro de este repo (`pos-specs`).

## Nota sobre gobernanza (Principios II/III/XI) y ramas

- **A-126 se registra en T001** (número confirmado con el `grep` de T001 al momento de ejecutarla; A-125 es la última hoy).
- **Rama (Principio XIV)**: una sola rama por repo, `feat/117-addons-quantity-line-total`, desde `develop` en `../pos-backend` **y** `../pos-heladeria` — las cuatro historias comparten los mismos archivos de pricing (`plan.md`, fila XIV).
- **Sin migración de Alembic** (`data-model.md`): todo el trabajo de backend es de comportamiento, no de esquema — no hay un commit de migración que aislar del resto (a diferencia de la spec 089).
- **Commits**: solo cuando el usuario lo pida (Principio XV); pequeños por unidad (motor de marcado `per_line`/topes; recableo de cada call-site; algoritmo de reducción automática + contrato de respuesta; frontend), en inglés, Conventional Commits, sin marca de IA.

---

## Phase 1: Setup

**Propósito**: gobernanza, rama y línea base antes de tocar código.

- [X] T001 Registrar **A-126** en `specs/000-reconocimiento/registro-de-anomalias.md` (confirmar el número vigente con `grep -oE "^### A-[0-9]+" specs/000-reconocimiento/registro-de-anomalias.md | sort -t- -k2 -n | tail -1` al momento de ejecutar; hoy sería A-126), mismo formato `### A-126 — [DECISIÓN DE NEGOCIO — spec 117] ...` que A-94 (research.md D8): **qué cambia** (se reabre `RN-CAT-01`, spec 002, exclusivamente para grupos de opciones `selection_mode = 'cantidad'`, spec 065 — la cantidad de una adición de ese modo deja de multiplicarse por la cantidad de producto de la línea, en todo canal, no solo en el Menú QR como ya hacía la spec 089 para `pricing_type = 'con_recargo'`); **por qué** (reporte del negocio: "2 granizados + 1 porción de gomitas cobra 2 gomitas", sesión de Clarifications 2026-10-13); **quién y cuándo** (usuario/negocio, 2026-10-13, respuestas 1-2 y 6 de esa sesión); **funcionalidades afectadas** (pricing de línea y validación de topes en `pos-backend`: carrito, consolidación de mesero, alta directa de comanda, venta de mostrador, reemplazo de ítem anulado, borrador de pedido manual; comanda de cocina; carrito/selector de `pos-heladeria`; nunca el modo "Conteo" — FR-013 — ni pedidos/ventas ya confirmados — FR-012)
- [X] T002 Crear en `../pos-backend` y en `../pos-heladeria` (ambos en `develop`, árbol limpio: verificar con `git status`) la rama `feat/117-addons-quantity-line-total` desde `develop` (Principio XIV; una sola rama por repo, `plan.md` fila XIV)
- [X] T003 Línea base: correr las suites completas de ambos repos **sin cambios** (`python -m unittest discover -s app/characterization_tests -p 'test_*.py'` en `../pos-backend`; `npx ng test --watch=false --browsers=ChromeHeadless` en `../pos-heladeria`) y crear `specs/117-adiciones-cantidad-total-linea/implementation-notes.md` con el número de tests y el resultado de cada suite (evidencia exigida por el Principio III para actualizar los tests que hoy congelan el bug, ver hallazgo 4 de arriba)

**Checkpoint**: A-126 registrada, rama creada, línea base verde documentada.

---

## Phase 2: Foundational (motor de pricing compartido; bloquea las 4 historias)

**Propósito**: los dos cambios de `catalog_engine/pricing.py` que **todo** call-site de escritura necesita (D1, D2) — sin tocar `catalog_engine/core.py` ni `consumption.py` (ya correctos para `per_line = True`, research.md D1/D7).

**⚠️ CRITICAL**: ninguna historia puede completarse sin esta fase (todas dependen de poder marcar `per_line` por `selection_mode` y de escalar los topes).

- [X] T004 [P] En `../pos-backend/app/catalog_engine/pricing.py::validate_option_selection` (línea 105-107): añadir parámetro `quantity: int = 1`; en el bloque de `cantidad_por_grupo` (línea 201-215), comparar `qty`/`total` contra `group.max_quantity_per_option * quantity` / `group.max_total_quantity * quantity` en vez del valor fijo (contracts/option-selection-validation.md). El default `1` reproduce el tope fijo de hoy para cualquier llamador que no lo pase (solo tests aislados de la función, research.md D2) — ningún camino de producción queda en ese caso tras T017-T022
- [X] T005 [P] En `../pos-backend/app/catalog_engine/pricing.py::load_valid_options` (línea 37-39): añadir parámetro `quantity: int = 1`, reenviado a `validate_option_selection` en la llamada de la línea 63 (solo cuando `variant is not None`, igual que hoy). Depende de T004 (mismo archivo)
- [X] T006 [P] En `../pos-backend/app/catalog_engine/pricing.py`: crear una función compartida (p. ej. `mark_per_line(db, options, *, qr_addons_per_line=False) -> list[ChosenOption]`) que decida `per_line` por la unión D1: `per_line = (qr_addons_per_line AND group.pricing_type == 'con_recargo') OR (group.selection_mode == 'cantidad')`, consultando `OptionGroup.pricing_type`/`.selection_mode` para los grupos de las opciones recibidas (mismo patrón de consulta que `_mark_addons` de `cart/service.py:230-244`, que esta función generaliza). `cart/service.py::_mark_addons` pasa a ser un envoltorio de una línea que llama a esta función con `qr_addons_per_line=settings.QR_ADDONS_PER_LINE` (preserva el comportamiento de la bandera de reversa de la spec 089 para su propio eje; la regla nueva de `selection_mode` nunca se apaga con esa bandera, research.md D1)
- [X] T007 [P] Tests nuevos en `../pos-backend/app/characterization_tests/test_catalog_option_groups_quantity.py` (clase `QuantityCapsTests`, D2; **no** `test_catalog_option_groups_selection_mode.py` — ver hallazgo 3): pasando `quantity=2` a `validate_option_selection`, un grupo con `max_quantity_per_option=3` acepta `4` (tope escalado `3×2=6`) y sigue rechazando `7`; con `max_total_quantity=5` y `quantity=2` (tope escalado `10`), dos opciones de `3` c/u (`total=6`) ya no se rechazan. Verificar explícitamente que los tres tests ya existentes de esta clase (líneas 203-243, que no pasan `quantity`) siguen en verde sin modificarlos — usan el default `1`, mismo tope que hoy
- [X] T008 [P] Tests nuevos para T006 (la función de marcado compartida), en una clase nueva de `test_catalog_option_groups_quantity.py` (o archivo nuevo si se prefiere aislarlo, p. ej. `test_catalog_engine_mark_per_line.py`): grupo `selection_mode='cantidad'` + `pricing_type='incluido'` con `qr_addons_per_line=False` → `per_line=True` (eje nuevo, antes siempre `False` fuera del Menú QR); grupo `selection_mode='conteo'` + `pricing_type='con_recargo'` con `qr_addons_per_line=False` → `per_line=False` (protegido, FR-013); grupo `selection_mode='conteo'` + `pricing_type='con_recargo'` con `qr_addons_per_line=True` → `per_line=True` (regla 089 intacta, sin cambios); grupo `selection_mode='cantidad'` + `pricing_type='con_recargo'` con `qr_addons_per_line=True` → `per_line=True` (ambas reglas coinciden)
- [X] T009 Checkpoint Foundational: correr `test_catalog_option_groups_quantity.py` (y el archivo/clase de T008) y confirmar T007/T008 en verde junto con los tests ya existentes sin modificar

**Checkpoint**: motor de topes escalados y de marcado `per_line` listo; ningún call-site todavía lo usa.

---

## Phase 3: User Story 1 — El total de la línea refleja la cantidad de adición como total, no multiplicada (Priority: P1) 🎯 MVP

**Goal**: en **todo** canal (no solo Menú QR), una línea con una adición de un grupo "Por cantidad" cobra `(Cantidad Producto × Precio Presentación) + Σ(Cantidad Adición × Precio Adición)` — 2 granizados + 1 gomitas = $37.000, no $38.000 (FR-001 a FR-003, FR-007, FR-009).

**Independent Test**: armar una línea de cantidad 2 con una adición "Por cantidad" de cantidad 1 desde cada uno de los 7 call-sites de escritura (carrito QR, mesero, alta directa, mostrador, reemplazo de ítem, borrador de pedido manual, Terminal POS vía `PosTerminalStore`) y verificar que el total solo incluye 1 unidad de la adición; repetir con la adición en cantidad 2 y verificar que el total incluye las 2 (spec.md, Historia 1, Escenarios 1-3).

### Tests para User Story 1 (escribir primero; deben fallar contra el código actual) ⚠️

- [X] T010 [P] [US1] Ampliar `../pos-backend/app/characterization_tests/test_cart_service.py` (clase `TestQrAddonsPerLine`, citar **A-126**): un grupo `selection_mode='cantidad'` + `pricing_type='incluido'` agregado vía `add_item` en el carrito QR marca `per_line=True` igual que uno `con_recargo` (antes solo marcaba por `pricing_type`); con `settings.QR_ADDONS_PER_LINE=False` la regla nueva de `selection_mode` **sigue** marcando `per_line=True` (a diferencia de la regla 089, que si se desactiva con la bandera no marca nada) — la bandera de reversa de la spec 089 solo gobierna su propio eje
- [X] T011 [P] [US1] Ampliar `../pos-backend/app/characterization_tests/test_orders_consolidation.py` (citar **A-126**; la clase `TestConsolidationAddonsPerLine`, línea 459+, solo cubre hoy `consolidate_table` copiando desde el carrito — ningún test existente ejercita `add_item_to_order` con `per_line`): nuevos tests en una clase para `add_item_to_order` (mesero, canal no-QR): un grupo `selection_mode='cantidad'` separa `unit_price`/`addons_total` en el `OrderItem` y persiste `per_line=True` en su `OrderItemOption`; un grupo `selection_mode='conteo'` con recargo sigue con `per_line=False` (protegido, FR-013); una selección que excede un tope `max_quantity_per_option` escalado por la cantidad de producto se acepta (antes rechazada con tope fijo)
- [X] T012 [P] [US1] Ampliar `../pos-backend/app/characterization_tests/test_orders_service.py` (clase `TestOrderLinesWithAddonsPerLine`, citar **A-126**; sibling de `test_create_order_de_la_terminal_pos_sigue_por_unidad`, línea 936, que usa un grupo "conteo" y queda intacto): nuevo test que llama `create_order` **real** (no el fixture manual `_item()` de la clase) con un grupo `selection_mode='cantidad'` y confirma `item.addons_total` separado y `item.options[0].per_line == True`
- [X] T013 [P] [US1] Crear `../pos-backend/app/characterization_tests/test_sales_service_checkout.py` (no existe hoy ningún characterization test que ejercite el camino de precio de `sales/service.py::checkout` — los archivos `test_sales_payment_methods*.py` solo cubren disponibilidad de métodos de pago): venta de mostrador (`service.checkout`) con una opción de un grupo `selection_mode='cantidad'` separa `unit_price`/`addons_total` en el `SaleLine`/`SaleItem` persistido, y el snapshot JSONB `SaleItem.options` incluye `"per_line": true` (mismo patrón que ya usa `order_sale_lines` en `orders/checkout.py:295`); un grupo "conteo" con recargo sigue folded (protegido)
- [X] T014 [P] [US1] Ampliar `../pos-backend/app/characterization_tests/test_orders_kitchen.py` (citar **A-126**; sibling de `test_void_item_anula_y_reemplaza_con_reversa_y_nuevo_descuento`, línea 172, que usa `replacement` sin opciones): nuevo test con `replacement.options` de un grupo `selection_mode='cantidad'` — el ítem de reemplazo separa `unit_price`/`addons_total` y persiste `per_line=True` en su `OrderItemOption`
- [X] T015 [P] [US1] Ampliar `../pos-backend/app/characterization_tests/test_orders_draft_preview_parity.py` (hallazgo 1 de arriba: `compute_draft_preview` es un 7º call-site, no listado en `plan.md`/`research.md`): nuevo test de **paridad** (el propósito explícito de este archivo, A-90) — un `DraftPreviewIn.items` con una opción de un grupo `selection_mode='cantidad'` produce el mismo subtotal que `create_order` con el mismo `OrderItemIn` seguido de `compute_checkout_preview`; hoy divergen porque `compute_draft_preview` sigue usando `compute_line_price` "folded" (línea 451)
- [X] T016 [P] [US1] Verificación **sin cambio de código** (hallazgo 3 de arriba): confirmar que `AddonsPerLineTests` (`test_catalog_line_pricing.py`, línea 265+) y `AddonsPerLineConsumptionTests` (`test_catalog_consumption_plan.py`, línea 313+) no necesitan ningún caso nuevo — ya cubren `compute_unit_price`/`compute_addons_total`/`line_total`/`plan_line_consumption` para `ChosenOption(per_line=True)` de forma abstracta, sin que `core.py`/`consumption.py` sepan nada de `selection_mode`. Dejar constancia en `implementation-notes.md` (Principio III: no se toca un test que sigue siendo cierto)

### Implementación de User Story 1 — backend

- [X] T017 [US1] En `../pos-backend/app/api/v1/cart/service.py`: `_mark_addons` (línea 230-244) pasa a envolver la función de T006; `add_item` (línea 392) pasa `quantity=data.quantity` a `load_valid_options`; `update_item` (línea 440) pasa `quantity=new_qty` (ya calculado en la línea 434). Hace pasar T010. Depende de T004-T006
- [X] T018 [US1] En `../pos-backend/app/api/v1/orders/consolidation.py::add_item_to_order` (línea 219-245): llamar a `load_valid_options(db, data.options, variant=variant, quantity=data.quantity)`, marcar las opciones con la función de T006 (`qr_addons_per_line=False` — nunca es el carrito QR); reemplazar `lines = [(..., compute_line_price(variant, options), None)]` (línea 224) por `unit_price=compute_unit_price(variant, options)` + `addons_total=compute_addons_total(options)` en el `OrderItem` (línea 229-238); persistir `per_line=chosen.per_line` en cada `OrderItemOption` (línea 242-244). Hace pasar T011. Depende de T006
- [X] T019 [US1] En `../pos-backend/app/api/v1/orders/service.py::create_order` (línea 613-648): mismo tratamiento que T018 — `load_valid_options(..., quantity=line.quantity)` (línea 630), marcar con T006 (`qr_addons_per_line=False`), `item.unit_price = compute_unit_price(...)` + `item.addons_total = compute_addons_total(...)` (reemplaza la línea 647), persistir `per_line` en cada `OrderItemOption` (línea 643-645). Hace pasar T012. Depende de T006
- [X] T020 [US1] En `../pos-backend/app/api/v1/sales/service.py::checkout` (línea 314-341): mismo tratamiento — `load_valid_options(..., quantity=line.quantity)` (línea 323), marcar con T006 (`qr_addons_per_line=False`), `unit_price=compute_unit_price(...)` + `addons_total=compute_addons_total(...)` pasados al `SaleLine` (línea 335-341, que ya soporta `addons_total`, spec 089); añadir `**({"per_line": True} if chosen.per_line else {})` al diccionario de `options_snapshot` (línea 325-333), igual que ya hace `order_sale_lines` (`orders/checkout.py:295`). Hace pasar T013. Depende de T006
- [X] T021 [US1] En `../pos-backend/app/api/v1/orders/kitchen.py` (reemplazo, línea 119-163): `load_valid_options(db, data.replacement.options, variant=repl_variant, quantity=data.replacement.quantity)` (línea 129-131), marcar `repl_options` con T006 (`qr_addons_per_line=False`); `new_item.unit_price = compute_unit_price(...)` + `new_item.addons_total = compute_addons_total(...)` (reemplaza la línea 153); persistir `per_line=chosen.per_line` en cada `OrderItemOption` del reemplazo (línea 161-163). Hace pasar T014. Depende de T006
- [X] T022 [US1] En `../pos-backend/app/api/v1/orders/checkout.py::compute_draft_preview` (línea 418-452; hallazgo 1 — 7º call-site no listado en `plan.md`): mismo tratamiento — `load_valid_options(db, item.options, variant=variant, quantity=item.quantity)` (línea 439), marcar con T006 (`qr_addons_per_line=False` — el borrador de pedido manual nunca es canal QR), construir el `SaleLine` (línea 442-452) con `unit_price=compute_unit_price(...)` + `addons_total=compute_addons_total(...)` en vez de `unit_price=compute_line_price(...)` (línea 451; `SaleLine` ya soporta `addons_total`, spec 089, sin cambio de `builder.py`). Hace pasar T015. Depende de T006
- [X] T023 [US1] Checkpoint de backend: correr la suite completa de `../pos-backend`; `grep -rnE "compute_line_price\(" ../pos-backend/app --include=*.py` para confirmar que de los call-sites tocados (T018, T019, T020, T021, T022) ninguno sigue llamándolo (puede seguir existiendo como función pura con sus propios tests, research.md D1 — solo deja de usarse para construir el precio final de una línea real); anotar resultado en `implementation-notes.md`

### Implementación de User Story 1 — frontend

- [X] T024 [P] [US1] En `tables/components/product-select.component.ts` (+ `product-select.component.spec.ts`): `ChosenMenuOption` (línea 27-34) gana `selectionMode: OptionGroupSelectionMode`, poblado en `selectedOptions()` (línea 545-554) desde `group.selection_mode`; `lineTotal()` (línea 618-630) deja de aplicar `(this.addonsPerLine ? 1 : quantity)` a la suma completa de `extra` y en su lugar separa por opción: las de `selectionMode === 'cantidad'` nunca se multiplican por `quantity` (sin importar `addonsPerLine`, D6); las demás conservan exactamente el cálculo actual (eje 089 intacto). Pruebas: cantidad de producto 2 + 1 "gomitas" (`cantidad`) fuera del Menú QR (`addonsPerLine=false`) → no se multiplica; grupo "conteo" con recargo sigue multiplicándose igual que hoy
- [X] T025 [P] [US1] En `tables/services/pos-terminal.store.ts` (+ `pos-terminal.store.spec.ts`): `ProductDraftLine` (línea 52-61) gana `addonsTotal: number`; `addDraftFromSelection()` (línea 1823-1836) separa, por `selectionMode` de cada opción elegida (T024), `unitPrice` (presentación + opciones "conteo") de `addonsTotal` (Σ opciones "cantidad"), en vez de sumar todas las opciones dentro de `unitPrice` (línea 1824-1825); `cartView()` (línea 1140-1142 y 1180-1182) usa `l.addonsTotal` real en `addonsTotal`/`subtotal` en vez de hardcodear `addonsTotal: 0`; el estimado local de `saveOrder()` (línea 1992) suma `l.addonsTotal` además de `l.unitPrice * l.quantity`. Pruebas: línea draft con 2 unidades de producto + 1 "gomitas" (`cantidad`) → `subtotal` no multiplica la adición; línea con solo opciones "conteo" no cambia. Depende de T024 (mismo tipo `ChosenMenuOption`)
- [X] T026 [US1] Checkpoint de frontend: `ng test` completo de `../pos-heladeria` en verde; recorrido manual de quickstart §1 y §2 (pasos 1-6: Terminal POS, pedido manual y Menú QR coinciden en $37.000/$38.000)

**Checkpoint**: US1 completa y verificable por sí sola en los 7 call-sites de escritura.

---

## Phase 3b: FR-014 — Confirmación de cantidad de adición al fusionar una línea existente
**(gap detectado en /speckit-analyze — depende de T024/T025)**

**Goal**: cuando el cajero agrega el mismo producto con las mismas adiciones "Por cantidad" a una
línea draft que ya existe (Terminal POS / pedido manual), el sistema nunca debe heredar
silenciosamente la cantidad de adición de la acción anterior para la cantidad de producto
combinada — debe exigir que el cajero confirme o reingrese esa cantidad (FR-014).

- [X] T050 [P] [US1] Test nuevo en `tables/services/pos-terminal.store.spec.ts`: dos llamadas a
  `addDraftFromSelection()` con la misma identidad (`productIdentityKey`, mismo
  `variantId`+`options`+`notes`) deben, tras fusionarse (`existing.quantity + sel.quantity`),
  dejar la línea en un estado que exija confirmación explícita del cajero sobre la cantidad total
  de adición resultante — nunca debe quedar la línea con la cantidad de adición de la primera
  acción aplicada tácitamente a la cantidad de producto combinada. Debe fallar contra el código
  actual (`pos-terminal.store.ts` L1873-1877, que hoy hace exactamente eso).
- [X] T051 [US1] En `tables/services/pos-terminal.store.ts::addDraftFromSelection` (L1848-1877):
  cuando se detecta fusión (`lastIdx !== -1`, rama "fusiona como siempre", L1873-1877) y la línea
  existente tiene al menos una opción de un grupo `selection_mode='cantidad'`, en vez de aplicar
  `{...existing, quantity: existing.quantity + sel.quantity}` directamente, reabrir
  `product-select.component` en modo edición con la cantidad de producto ya combinada, forzando al
  cajero a confirmar/reingresar la cantidad de cada adición "cantidad" antes de aplicar la fusión
  (reutiliza el flujo ya existente de `editingDraftKey`, en vez de uno nuevo). Depende de
  T024/T025 (mismo archivo/tipos) y de T050.
- [X] T052 [US1] Verificar si `cart/service.py::add_item` (carrito QR) o algún otro call-site del
  cajero tiene un comportamiento de fusión equivalente que también deba corregirse (confirmado por
  análisis: `add_item`/`add_item_to_order` NO fusionan hoy, siempre crean una fila nueva — si eso
  se mantiene así, FR-014 no aplica a esos endpoints; dejar constancia en
  `implementation-notes.md`).

**Nota de diseño pendiente**: FR-014 exige "confirmar o reingresar", sin definir la UX exacta
(mismo nivel de detalle que el aviso de FR-005, delegado a planeación) — T051 necesita que el
usuario/negocio apruebe el patrón de interacción (reabrir el modal vs. un diálogo de confirmación
simple) antes de implementarse.

**Checkpoint**: FR-014 cubierto por tests y, si T052 confirma que aplica, por implementación.

---

## Phase 4: User Story 2 — Todas las superficies de cobro calculan y muestran el mismo total (Priority: P1)

**Goal**: "Pagos por confirmar", el recibo/factura impresa y el detalle de la orden ("Mis pedidos") coinciden exactamente con el total ya corregido por US1 (FR-009 a FR-011).

**Independent Test**: confirmar desde el Menú QR un pedido con una adición "Por cantidad" no 1:1 con la cantidad de producto, y verificar que el monto que calcula el backend al validar/aprobar el pago (incluida "Pagos por confirmar") coincide exactamente con el mostrado en el Menú QR, en el recibo y en el detalle de la orden (spec.md, Historia 2).

**Dependencias**: depende de US1 — estas superficies son **consumidoras** de `unit_price`/`addons_total`/`per_line` ya persistidos (contracts/line-pricing-per-line-cantidad.md: `compute_checkout_preview`, `approve_payment_attempt`, `confirm_cash_payment_attempt` no cambian de código, solo de resultado una vez US1 persiste bien los datos).

### Tests para User Story 2 ⚠️

- [X] T027 [P] [US2] Nuevo test de integración en `../pos-backend/app/characterization_tests/test_orders_checkout.py` (citar **A-126**): tras crear, vía `add_item_to_order` o `create_order` (T018/T019), una línea con una opción `selection_mode='cantidad'` no 1:1, `compute_checkout_preview` y `approve_payment_attempt`/`confirm_cash_payment_attempt` ("Pagos por confirmar", FR-011) validan exactamente el total de FR-002 — cierra el lazo end-to-end para esta superficie específica, que hoy solo tiene cobertura con fixtures manuales (`per_line` fijado a mano, no derivado de `selection_mode`)
- [X] T028 [P] [US2] Nuevo test en `tables/services/dining-cart.service.spec.ts`: `CartLine.lineTotal`/`addonsTotal` (ya leídos de `CartItemResponse.addons_total`/`.line_total`, `dining-cart.service.ts:239-246`) reflejan correctamente una línea con `selection_mode='cantidad'` fuera del eje 089 — verificación de lectura, sin cambio de código esperado (ya corregido por el backend de US1)

### Implementación de User Story 2

- [X] T029 [US2] Si T027 o T028 revelan algo que corregir (poco probable dado que son consumidores puros, contracts/line-pricing-per-line-cantidad.md), aplicar el ajuste mínimo aquí; si pasan sin cambios, dejar constancia en `implementation-notes.md` (igual que hizo la spec 089 con T051 cuando un test pasaba sin tocar código)
- [X] T030 [US2] Checkpoint de US2: recorrido manual de quickstart §2 completo (Menú QR → "Pagos por confirmar" → recibo impreso → detalle de la orden / "Mis pedidos") con una línea "cantidad" no 1:1, confirmando cero discrepancias (SC-003). Anotar en `implementation-notes.md`

**Checkpoint**: US1 y US2 (las dos P1) funcionan y se prueban de forma independiente.

---

## Phase 5: User Story 3 — Reducir la cantidad de producto ajusta automáticamente las adiciones que excedan el nuevo límite (Priority: P2)

**Goal**: al reducir la cantidad de producto de una línea con adiciones "Por cantidad" ya elegidas, si superan el nuevo límite escalado (FR-004), el sistema las reduce automáticamente con un criterio determinista (FR-006), avisa, y recalcula el total (FR-005).

**Independent Test**: grupo con máximo 1 unidad por producto, línea de cantidad 2 con 2 unidades de una adición, reducir la cantidad de producto a 1 → la adición baja automáticamente a 1, se muestra un aviso, el total se recalcula (spec.md, Historia 3, Escenario 1).

**Dependencias**: depende de Foundational (T004, topes escalados) y de US1 (T017, para que `update_item` recalcule `unit_price`/`addons_total` ya separados tras el ajuste). Único camino de backend donde esto es posible hoy: `cart/service.py::update_item` cuando el `PATCH` trae solo `quantity` (research.md D3) — Terminal POS y el modal de selección resuelven el caso equivalente **enteramente en el frontend**, antes de que la línea exista en el backend.

### Tests para User Story 3 (escribir primero; deben fallar contra el código actual) ⚠️

- [X] T031 [P] [US3] Ampliar `../pos-backend/app/characterization_tests/test_cart_service.py` (citar **A-126**; research.md D3: hoy `update_item` con solo `quantity` —sin `options`— no revalida nada, línea 441-446): nuevo test que agrega una línea con cantidad de producto 2 y 2 unidades de una adición de un grupo con `max_quantity_per_option=1` (válida: tope escalado `1×2=2`), reduce la cantidad a 1 vía `PATCH` con solo `{"quantity": 1}`, y espera: la opción queda en cantidad 1, `unit_price`/`addons_total`/`line_total` recalculados (`19.000`), y la respuesta incluye `adjusted_options == [{"option_name": ..., "previous_quantity": 2, "new_quantity": 1}]` (contracts/cart-item-auto-adjust.md). Segundo test con dos adiciones del mismo grupo (`max_total_quantity`) verificando el criterio determinista D4 (orden alfabético descendente por `Option.name`, ver ejemplo del contrato: "Gomitas" se reduce antes que "Chocolate"). Tercer test: un grupo "cantidad" sin ningún tope configurado nunca dispara el ajuste al reducir la cantidad (edge case de la spec)
- [X] T032 [P] [US3] Ampliar `../pos-backend/app/characterization_tests/test_cart_service.py`: `GET /cart` tras un ajuste (o un `PATCH` posterior sin disparar uno nuevo) **no** repite `adjusted_options` — queda `[]`, solo `options[].quantity` refleja el estado ya ajustado (contracts/cart-item-auto-adjust.md: "nunca reaparece en cada lectura posterior")

### Implementación de User Story 3

- [X] T033 [US3] En `../pos-backend/app/api/v1/cart/schemas.py`: `AdjustedOptionOut` (`option_id`, `option_name`, `previous_quantity`, `new_quantity`) y `CartItemResponse.adjusted_options: list[AdjustedOptionOut] = Field(default_factory=list)` (data-model.md, aditivo, sin romper ningún cliente que lo ignore)
- [X] T034 [US3] En `../pos-backend/app/api/v1/cart/service.py::update_item` (línea 426-475, rama `data.options is None`, línea 441-446): cuando `new_qty < item.quantity`, revalidar contra los topes escalados con la **nueva** cantidad (T004); para cada opción de un grupo `selection_mode='cantidad'` que exceda su tope individual escalado, reducirla hasta ese tope; si la suma del grupo sigue excediendo el tope total escalado, ordenar por `Option.name` descendente (desempate `option_id`) y reducir de una unidad a la vez la primera opción de ese orden hasta cumplirlo (algoritmo D4, contracts/cart-item-auto-adjust.md); acumular cada reducción efectiva en una lista local; recalcular `item.unit_price`/`item.addons_total` con T017 ya en vigor. Hace pasar T031. Depende de T004, T017, T033
- [X] T035 [US3] En `../pos-backend/app/api/v1/cart/service.py::update_item`: devolver `CartItemResponse.adjusted_options` poblado **solo** en la respuesta de este `PATCH` (nunca en `get_cart`/`serialize_cart`, que no tienen de dónde leerlo — confirma T032). Depende de T034
- [X] T036 [US3] Checkpoint de backend US3: suite completa de `../pos-backend`; recorrido manual de quickstart §3 pasos 1-3 y 5 (ajuste simple, criterio determinista con dos adiciones)

### Implementación de User Story 3 — frontend (Terminal POS y modal, 100% client-side — research.md D3)

- [X] T037 [P] [US3] En `tables/components/product-select.component.ts` (+ spec): `canIncrement()` (línea 927-937) escala `group.max_quantity_per_option`/`group.max_total_quantity` por `this.quantity()` (equivalente frontend de T004) en vez de compararlos fijos
- [X] T038 [US3] En `tables/components/product-select.component.ts` (+ spec): nuevo efecto (o lógica dentro de `dec()`, línea 977-979) que, al reducir `this.quantity()`, aplica sobre `this.selected()` el mismo algoritmo D4 de T034 (orden alfabético descendente por `opt.name`, desempate `opt.id`) para cada grupo `selection_mode='cantidad'` que exceda su nuevo tope escalado (T037) — antes de que el cajero pueda pulsar "Agregar" (`confirm()`, línea 981-993). Depende de T037
- [X] T039 [P] [US3] En `tables/services/pos-terminal.store.ts::decDraft` (línea 1956+): mismo criterio D4 aplicado a `ProductDraftLine.options` al reducir `line.quantity`, antes de que la línea se envíe al backend (`createManualOrderFromDraft`/`saveOrder`). Depende de T025 (mismo archivo, `ProductDraftLine.addonsTotal` ya separado)
- [X] T040 [US3] En `tables/services/dining-cart.service.ts::setQuantity` (línea 185-188, + spec): propagar `adjusted_options` de la respuesta del `PATCH` (p. ej. devolviendo `{adjustedOptions}` o un signal nuevo) para que la pantalla pueda avisar. Depende de T035
- [X] T041 [US3] En `tables/pages/public-menu.component.ts::changeQuantity` (línea 1234-1241, + spec): tras una reducción que devuelve `adjusted_options` no vacío (T040), mostrar un aviso informativo visible y no bloqueante (reusar el patrón ya existente de `orderError` como señal simple, sin diseñar un componente nuevo — el diseño visual concreto queda fuera de alcance de esta spec, "Out of Scope"). Depende de T040
- [X] T042 [US3] Checkpoint de frontend US3: `ng test` completo; recorrido manual completo de quickstart §3 (pasos 1-6, incluido "el cajero sube de nuevo la cantidad y la adición reducida NO revive sola" — edge case de la spec)

**Checkpoint**: US1, US2 y US3 funcionan de forma independiente.

---

## Phase 6: User Story 4 — La comanda de cocina muestra la cantidad total de cada adición de la línea (Priority: P2)

**Goal**: la comanda muestra la cantidad total vigente de cada adición "Por cantidad" de la línea completa, no una cantidad que el cocinero deba multiplicar mentalmente (FR-008).

**Independent Test**: enviar a cocina una línea de cantidad 2 con una adición de cantidad total 1, y verificar que la comanda indica la cantidad de adición como 1 para toda la línea (spec.md, Historia 4).

**Dependencias**: depende de US1 (la cantidad ya persistida en `OrderItemOption.quantity` es, por diseño, siempre la cantidad total elegida — spec 065 FR-010 — nunca se multiplica al guardarse ni al leerse; `plan.md` confirma que **no cambia código de formato**, solo se verifica).

- [X] T043 [US4] Nuevo test en `../pos-backend/app/characterization_tests/test_orders_service.py` (clase `TestOrderLinesWithAddonsPerLine`, sibling de `test_order_item_response_expone_addons_total_line_total_y_la_cantidad_del_adicional`, línea 915, que hoy fija `per_line` a mano en el fixture): crear una línea **real** vía `create_order`/`add_item_to_order` (T019/T018) con un grupo `selection_mode='cantidad'`, y confirmar que `OrderItemResponse.options[0].quantity` expone la cantidad TOTAL vigente de la adición (la que alimenta la comanda), no una cantidad multiplicada por la cantidad de producto — cierra el lazo de FR-008 con un camino real, no solo con el fixture manual `_item()`
- [X] T044 [US4] Recorrido manual de quickstart §4 y §5 (regresión "Conteo", FR-013): enviar a cocina una línea de cantidad 2 con "Gomitas ×1" (total) y verificar el formato ya definido por spec 065 FR-010; repetir con un grupo "Conteo" con recargo y confirmar que el total sigue siendo `2×(precio + recargo)`, sin cambios. Anotar en `implementation-notes.md`

**Checkpoint**: las cuatro historias completas.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Propósito**: verificación final y documentación (Principio X).

- [X] T045 Suite completa de `../pos-backend` (`python -m unittest discover -s app/characterization_tests -p 'test_*.py'`) en verde y comparada con la línea base de T003 (solo suben los tests nuevos; ningún test que "congela" comportamiento heredado cambió sin citar A-126)
- [X] T046 Suite completa de `../pos-heladeria` (`npx ng test --watch=false --browsers=ChromeHeadless`) en verde y comparada con la línea base de T003; `npx ng build` sin errores de tipos
- [X] T047 Recorrido completo de [quickstart.md](./quickstart.md) §1-§5 y comprobar la tabla de criterios de salida (SC-001…SC-005, incluida la regresión de datos históricos SC-005); listar en `implementation-notes.md` los recorridos manuales que queden pendientes y por qué
- [X] T048 Completar `specs/117-adiciones-cantidad-total-linea/implementation-notes.md`: decisiones tomadas y su porqué, los 4 hallazgos de corrección a `research.md`/`plan.md` listados al inicio de este archivo (con su resolución), y cualquier desviación respecto al plan
- [X] T049 Verificación de trazabilidad (Principio XII): `grep -n "A-126" specs/000-reconocimiento/registro-de-anomalias.md` encuentra la entrada; `grep -rn "A-126" ../pos-backend/app/characterization_tests` confirma que todo test modificado para congelar el nuevo comportamiento la cita; `git status` en `pos-specs`, `../pos-backend` y `../pos-heladeria` — **no commitear** salvo que el usuario lo pida (Principio XV)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias.
- **Foundational (Phase 2)**: depende del Setup; **bloquea las 4 historias** (motor de topes escalados y de marcado `per_line` compartido).
- **US1 (Phase 3)**: depende de Foundational. Sin dependencia de otras historias — es el MVP.
- **US2 (Phase 4)**: depende de US1 (consume datos que US1 persiste correctamente).
- **US3 (Phase 5)**: depende de Foundational (topes escalados) y de US1 (`update_item` ya separa `unit_price`/`addons_total`).
- **US4 (Phase 6)**: depende de US1 (la comanda lee `OrderItemOption.quantity` ya persistida correctamente por `create_order`/`add_item_to_order`).
- **Polish (Phase 7)**: depende de las cuatro historias.

### User Story Dependencies

- **US1 (P1)**: tras Foundational. Es el MVP; ninguna otra historia puede completarse sin ella.
- **US2 (P1)**: tras US1.
- **US3 (P2)**: tras Foundational y US1.
- **US4 (P2)**: tras US1.

### Within Each User Story

- Tests de backend primero y fallando; después motor/validación → servicio → esquemas → frontend.
- Cada historia se cierra con su checkpoint manual antes de pasar a la siguiente prioridad.

### Parallel Opportunities

- Setup: T001 y T002 en paralelo; T003 tras T002.
- Foundational: T004 y T005 son secuenciales (mismo archivo, T005 depende de T004); T006, T007 y T008 en paralelo con ellos.
- US1 tests T010-T016 (archivos distintos) todos en paralelo; implementación T018-T022 en paralelo entre sí (archivos distintos, todos dependen solo de T006), T017 en paralelo con ellos; frontend T024 primero, T025 depende de T024.
- US2: T027 y T028 en paralelo.
- US3: T031 y T032 en paralelo; frontend T037 antes de T038; T039 en paralelo con T037-T038 (archivo distinto); T040 antes de T041.
- US4: T043 independiente de todo lo demás salvo US1.
- Con dos personas: una lleva Foundational → US1 → US2 (misma rama, mismos archivos de pricing) y otra espera a que Foundational esté lista para encargarse de US3 (topes + ajuste automático) en paralelo con la cola de US1/US2; US4 es la más pequeña y puede ir al final o en cualquier hueco libre tras US1.

---

## Parallel Example: Foundational + User Story 1

```bash
# Foundational (archivos del mismo módulo pero funciones distintas):
Task: "pricing.py: validate_option_selection + quantity, topes escalados (D2)"
Task: "pricing.py: función compartida de marcado per_line (D1)"
Task: "Tests nuevos de topes escalados en test_catalog_option_groups_quantity.py"
Task: "Tests nuevos de la función de marcado compartida"

# Tests de backend de US1 (archivos distintos), juntos:
Task: "Ampliar test_cart_service.py con selection_mode='cantidad' fuera del eje 089 (A-126)"
Task: "Ampliar test_orders_consolidation.py con add_item_to_order real (A-126)"
Task: "Ampliar test_orders_service.py con create_order real (A-126)"
Task: "Crear test_sales_service_checkout.py (A-126)"
Task: "Ampliar test_orders_kitchen.py con reemplazo + opciones cantidad (A-126)"
Task: "Ampliar test_orders_draft_preview_parity.py con paridad cantidad"

# Implementación de los 5 call-sites "folded" (todos dependen solo de T006, archivos distintos):
Task: "orders/consolidation.py::add_item_to_order: separar unit_price/addons_total"
Task: "orders/service.py::create_order: separar unit_price/addons_total"
Task: "sales/service.py::checkout: separar unit_price/addons_total + snapshot per_line"
Task: "orders/kitchen.py (reemplazo): separar unit_price/addons_total"
Task: "orders/checkout.py::compute_draft_preview: separar unit_price/addons_total"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Completar Phase 1: Setup
2. Completar Phase 2: Foundational (CRÍTICO — bloquea las 4 historias)
3. Completar Phase 3: User Story 1 (7 call-sites de escritura + frontend)
4. **DETENER y VALIDAR**: probar User Story 1 de forma independiente (quickstart §1)
5. Desplegar/demo si está listo — resuelve ya el problema central reportado por el negocio

### Incremental Delivery

1. Setup + Foundational → base lista
2. Agregar US1 → probar independientemente → desplegar/demo (¡MVP!)
3. Agregar US2 → probar independientemente → desplegar/demo (consistencia entre superficies)
4. Agregar US3 → probar independientemente → desplegar/demo (ajuste automático al reducir cantidad)
5. Agregar US4 → probar independientemente → desplegar/demo (comanda, solo verificación)

### Parallel Team Strategy

Con dos personas: una completa Setup + Foundational + US1 + US2 en secuencia (mismos archivos de pricing); otra, tras el checkpoint de Foundational, se encarga de US3 (topes + algoritmo de reducción) en paralelo; US4 (la más pequeña, solo verificación) la hace quien quede libre primero.

---

## Notes

- **[P]** tareas = archivos distintos, sin dependencias entre ellas
- **[Story]** mapea cada tarea a su historia de usuario para trazabilidad
- Verificar que los tests fallan antes de implementar
- Commits solo cuando el usuario lo pida (Principio XV)
- Detenerse en cada checkpoint para validar la historia de forma independiente
- Los 4 hallazgos de esta fase (ver encabezado) corrigen `research.md`/`plan.md` contra el código real — no reabren la fase de planeación (son detalle de implementación, Principio XI), pero `implementation-notes.md` (T048) debe dejarlos documentados para que la Fase 1 de una spec futura que reutilice estos mismos call-sites no repita la misma omisión
