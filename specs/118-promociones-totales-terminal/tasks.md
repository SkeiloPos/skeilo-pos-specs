---

description: "Task list template for feature implementation"
---

# Tasks: Consistencia de promociones en el detalle de la orden y en las tarjetas de la terminal

**Input**: Documentos de diseño de `/specs/118-promociones-totales-terminal/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: no fueron solicitados como TDD explícito; se incluyen como tests de
characterization/regresión (Principio III) porque `research.md` ya los exige como parte del
alcance de cada historia — se añaden junto a (no antes de) la implementación que verifican, que es
el patrón ya usado en specs anteriores de este repo (073/089/117).

**Organization**: 2 historias de usuario (US1 P1, US2 P2) + 1 cobertura de regresión sin código
nuevo (Escenario 4/FR-004, dentro de US1) + edge cases transversales (Polish).

## Formato: `[ID] [P?] [Story] Descripción`

- **[P]**: puede ejecutarse en paralelo (archivos distintos, sin dependencias)
- **[Story]**: historia de usuario a la que pertenece la tarea (US1, US2)
- Cada tarea incluye la ruta exacta del archivo

## Convenciones de rutas

- `pos-backend`: `../pos-backend/app/...` (repo hermano de `pos-specs`)
- `pos-heladeria`: `../pos-heladeria/src/app/...` (repo hermano de `pos-specs`)
- Sin cambios en `pos-specs` más allá de este `tasks.md` (ver plan.md: sin entrada nueva en
  `registro-de-anomalias.md`, research.md D6)

---

## Phase 1: Setup

**Propósito**: abrir las ramas de trabajo (Principio XIV). Sin inicialización de proyecto ni
dependencias nuevas — reutiliza infraestructura existente (plan.md Technical Context).

- [X] T001 [P] Crear, desde `develop`, la rama `fix/118-promo-totals-consistency` en el repo
  `pos-backend` (`../pos-backend`)
- [X] T002 [P] Crear, desde `develop`, la rama `fix/118-promo-totals-consistency` en el repo
  `pos-heladeria` (`../pos-heladeria`)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Nota**: esta spec no tiene infraestructura compartida que bloquee a la vez a US1 y US2 — US1 es
backend puro (`pos-backend`), US2 es frontend puro (`pos-heladeria`), y ambos repos son
independientes entre sí (plan.md Scale/Scope). No hay tareas en esta fase; el prerequisito interno
de US1 (relocalizar `line_discount_snapshot`) vive dentro de la Fase 3 porque solo bloquea tareas de
US1, no de US2.

**Checkpoint**: no aplica — continuar directo a la Fase 3.

---

## Phase 3: User Story 1 - El TOTAL de la tarjeta de terminal coincide con lo que realmente se cobra (Priority: P1) 🎯 MVP

**Goal**: las tarjetas de resumen de Mesas/Domicilios/Para llevar, el detalle de la orden, el módulo
de cobro y "Pagos por confirmar" muestran el mismo `TOTAL` con promociones aplicadas, para cualquier
orden abierta con al menos una promoción vigente (FR-001 a FR-004).

**Independent Test**: abrir una orden con una línea en promoción por volumen en cada una de las tres
vistas (Mesas, Domicilios, Para llevar) y comparar el `TOTAL` de la tarjeta contra el total del
detalle y del módulo de cobro de esa misma orden, sin completar el cobro (spec.md, Historia 1).

### Implementación para la Historia 1

- [X] T003 [US1] Relocalizar `_cart_line_discount` (`../pos-backend/app/api/v1/cart/service.py`,
  líneas ~302-320) a `../pos-backend/app/api/v1/orders/checkout.py` como función pública
  `line_discount_snapshot(result, index: int, line_total: Decimal, quantity: int, addons_total:
  Decimal = Decimal(0))`, junto a `order_sale_lines`/`promo_lines_for`/`auto_discount`/
  `promotion_evaluation_instant` (misma fórmula, mismo docstring). Actualizar
  `cart/service.py::submit_cart` para importar `line_discount_snapshot` desde
  `app.api.v1.orders.checkout` en vez de definirla localmente — sin cambio de comportamiento para el
  canal QR (research.md D2)

- [X] T004 [US1] Implementar `refresh_order_item_discounts(db: Session, order: CustomerOrder) ->
  None` en `../pos-backend/app/api/v1/orders/checkout.py` (depende de T003): cargar `lines =
  order_sale_lines(db, order.id)`, calcular `instant = promotion_evaluation_instant([order],
  now=datetime.now(timezone.utc))`, evaluar `result = evaluate_variant_sets(db,
  promo_lines_for(db, lines), instant)` y, para cada `(idx, line)` de `lines`, calcular
  `line_discount_snapshot(result, idx, line.line_total, line.quantity, line.addons_total)` y
  sobrescribir `OrderItem[line.line_id].discounted_unit_price`/`.discounted_line_total` —
  incluido escribir `(None, None)` cuando la línea ya no califica (contracts/order-item-discount-
  snapshot.md, research.md D3)

- [X] T005 [P] [US1] Actualizar el import en
  `../pos-backend/app/characterization_tests/test_cart_service.py` para referenciar
  `line_discount_snapshot` desde `app.api.v1.orders.checkout` en vez de `_cart_line_discount` de
  `cart/service.py` (sin caso nuevo, sin cambio de comportamiento esperado — research.md D2)

- [X] T006 [P] [US1] Llamar `refresh_order_item_discounts(db, order)` dentro de `create_order`
  (`../pos-backend/app/api/v1/orders/service.py`, ~línea 664, tras insertar todos los `entries` y
  antes de `db.commit()` en ~línea 666), con un import diferido
  (`from app.api.v1.orders.checkout import refresh_order_item_discounts`) dentro de la función para
  evitar el ciclo `service.py ↔ checkout.py` (research.md D2; depende de T004)

- [X] T007 [P] [US1] Llamar `refresh_order_item_discounts(db, order)` dentro de `consolidate_table`
  (`../pos-backend/app/api/v1/orders/consolidation.py`, ~línea 180, antes de `db.commit()`) y dentro
  de `add_item_to_order` (mismo archivo, ~línea 253, antes de `db.commit()`), ambas tras insertar sus
  líneas nuevas y con import diferido dentro de cada función (depende de T004)

- [X] T008 [P] [US1] Llamar `refresh_order_item_discounts(db, order)` dentro de `void_item`
  (`../pos-backend/app/api/v1/orders/kitchen.py`, ~línea 174, antes de `db.commit()`), tras marcar
  `estado_cocina = "anulado"` en el ítem anulado y tras insertar el reemplazo si `data.replacement`
  viene, con import diferido dentro de la función (depende de T004)

### Tests de characterization/regresión para la Historia 1

- [X] T009 [P] [US1] Añadir tests en
  `../pos-backend/app/characterization_tests/test_orders_service.py`: (a) `create_order` con 2
  líneas de la misma presentación (misma llamada) que alcanzan el umbral de una promoción por
  volumen (`package_price`) deja ambas filas `OrderItem` con `discounted_unit_price`/
  `discounted_line_total` poblados y coherentes; (b) idem con una regla `percent` vigente sobre la
  misma presentación, confirmando que `evaluate_variant_sets` persiste el descuento porcentual por
  línea igual que el de volumen (research.md D1; FR-001) (depende de T006)

- [X] T010 [P] [US1] Añadir tests en
  `../pos-backend/app/characterization_tests/test_orders_consolidation.py`: (a) dos llamadas
  sucesivas a `add_item_to_order` (1 unidad cada vez) sobre la misma presentación dejan **ambas**
  filas con `discounted_unit_price`/`discounted_line_total` poblados tras la segunda llamada,
  coherentes con `compute_checkout_preview` del pedido completo (Historia 2, Escenario 1 del
  spec); (b) `consolidate_table` con carritos de dos comensales distintos sobre la misma
  presentación produce el mismo resultado (depende de T007)

- [X] T011 [P] [US1] Añadir test en
  `../pos-backend/app/characterization_tests/test_orders_kitchen.py`: `void_item` sobre una de dos
  filas con descuento ya persistido deja la fila restante con `discounted_unit_price`/
  `discounted_line_total = None` cuando la cantidad restante cae bajo el umbral (FR-006; depende de
  T008)

- [X] T012 [P] [US1] Añadir test en
  `../pos-backend/app/characterization_tests/test_orders_payment_gate.py` que reproduzca el Edge
  Case de canales mixtos (FR-004, Acceptance Scenario 4 de Historia 1): un pedido QR con 1 unidad
  recibe una segunda unidad de la misma presentación vía `add_item_to_order` (mesero) antes de que
  `confirm_cash_payment_attempt` se llame; verificar que el monto validado ya incluye el descuento
  combinado — sin cambio de código en `confirm_cash_payment_attempt`/`approve_payment_attempt`, solo
  cobertura nueva (research.md D5; depende de T007)

- [X] T013 [US1] Ejecutar `python -m unittest discover -s app/characterization_tests -p
  'test_*.py'` en `../pos-backend`; confirmar que pasan T005/T009/T010/T011/T012 y que no se rompe
  `test_orders_billing_summary.py` (`billing=null` en el listado, spec 094 D3, sin cambios)

- [ ] T014 [US1] Verificación manual — quickstart.md Escenario 1 (TOTAL de tarjeta de Mesas,
  Domicilios y Para llevar coincide con detalle y módulo de cobro) y Escenario 3 ("Pagos por
  confirmar" con adiciones sucesivas por canales distintos)

**Checkpoint**: en este punto, el `TOTAL` de las tarjetas de Terminal y el panel "Pagos por
confirmar" quedan correctos para cualquier orden abierta con promociones — Historia 1 es
funcional e independientemente verificable (sin requerir ningún cambio de Historia 2).

---

## Phase 4: User Story 2 - El detalle de la orden refleja la promoción al completarse por partes (Priority: P2)

**Goal**: cuando dos o más líneas `OrderItem` de la misma presentación+opciones+notas coexisten en
una orden abierta por haberse agregado en momentos distintos y su cantidad combinada alcanza el
umbral de una promoción por volumen, el detalle de la orden (panel/carrito de la Terminal POS) las
presenta agrupadas en una sola card con etiqueta, tachado y monto ajustado (FR-005 a FR-008).

**Independent Test**: agregar 1 unidad de una presentación con promoción por volumen a una orden
abierta, agregar otro ítem de por medio, y luego agregar una segunda unidad de la misma
presentación; verificar que el detalle muestre la etiqueta de promoción, el precio tachado y el
monto ajustado igual que si ambas unidades se hubieran agregado juntas (spec.md, Historia 2).

### Implementación para la Historia 2

- [X] T015 [US2] En
  `../pos-heladeria/src/app/modules/tables/services/pos-terminal.store.ts`, añadir una función de
  agrupamiento para ítems "planos" (sin `combo_id`) análoga a `groupByCombo()` (~línea 1929): clave
  `(product_variant_id, notes, firma_de_opciones)`, donde `firma_de_opciones` es la lista `(option_id,
  quantity)` de cada opción elegida, ordenada por `option_id` y serializada a string (contracts/
  detail-panel-line-grouping.md; depende de T002)

- [X] T016 [US2] Generalizar `persistedLinePromo()` (mismo archivo, ~línea 542) para que reciba
  `rows: DiningOrderItem[]` en vez de los campos escalares de una sola fila, siguiendo exactamente la
  fórmula de research.md D4: `totalQty = Σ rows[i].quantity`; `originalAmount = Σ (unit_price × qty +
  addons_total)`; si alguna fila tiene `discounted_unit_price != null`, `discountedAmount = Σ
  itemLineTotal(rows[i])` y la insignia es `-${percent}%`; si no, caer a la estimación por catálogo
  (`packagePrice(unitPrice, catalogPromo, totalQty)`) evaluada sobre `totalQty` del grupo en vez de la
  cantidad de una sola fila — debe producir el mismo resultado que la versión anterior para un grupo
  de 1 fila (FR-007; depende de T015)

- [X] T017 [US2] Actualizar `persistedItemsView()` (mismo archivo, ~línea 1030) para agrupar
  `plainItems` con la clave de T015 antes de mapearlas a cards: `qty` = suma de `quantity` del
  grupo, `subtotal` = suma de `itemLineTotal(row)` del grupo, `promo` = `persistedLinePromo(rows,
  catalogPromo)` generalizada (T016), `pendingItemIds`/`ready`/`kitchenStatus` con el mismo patrón
  que ya usa `persistedCombos` (`leastAdvanced`, `KITCHEN_NOT_READY`), y un `key` estable del grupo
  (ej. `` `plain:${product_variant_id}:${notes}:${firma_de_opciones}` ``) en vez del `id` de una sola
  fila (contracts/detail-panel-line-grouping.md; depende de T015, T016)

### Tests para la Historia 2

- [X] T018 [P] [US2] Añadir casos en
  `../pos-heladeria/src/app/modules/tables/services/pos-terminal.store.spec.ts`: dos
  `DiningOrderItem` planos de la misma presentación+opciones+notas, agregados en mutaciones
  separadas, se agrupan en una sola card con `qty`/`subtotal`/insignia correctos
  (research.md D4, ejemplo con `discountedAmount=12000` sobre `originalAmount=14000`); anular una de
  las dos filas revierte el grupo a una sola card sin insignia (FR-006). Confirmar además que el
  grupo expone los `id` de ambas filas `OrderItem` subyacentes sin fusionarlas (FR-008): el `id`
  usado para anular sigue siendo el de cada fila original, no un id sintético del grupo. Confirmar
  que los bloques existentes de `tablesView`/`ordersByType` y el test que verifica que no se dispara
  `checkout-preview` por tarjeta siguen pasando (depende de T017)

- [X] T019 [P] [US2] Añadir caso en
  `../pos-heladeria/src/app/modules/tables/components/pos-order-panel.component.spec.ts`: dos
  adiciones sucesivas de la misma presentación que alcanzan el umbral de una promoción por volumen
  renderizan **una sola card** (no dos), con el mismo formato de insignia/tachado/monto ajustado que
  ya usa una card de una sola adición (FR-007; depende de T017)

- [X] T020 [US2] Ejecutar `npx ng test --watch=false` en `../pos-heladeria`; confirmar que pasan
  T018/T019 y que no aumentan los fallos preexistentes de la suite frontend (memoria
  `reference_pos_suite_frontend_fallos_preexistentes`)

- [ ] T021 [US2] Verificación manual — quickstart.md Escenario 2 (adiciones sucesivas agrupan
  visualmente en una sola card, la agrupación persiste tras recargar `GET /orders/{id}`, y revierte
  al anular una unidad)

**Checkpoint**: Historia 1 y Historia 2 funcionan de forma independiente; el detalle de la orden
agrupa visualmente las adiciones sucesivas sin fusionar ningún `OrderItem` subyacente (FR-008).

---

## Phase 5: Polish & Cross-Cutting Concerns

**Propósito**: cobertura de edge cases transversales del spec, limpieza de documentación
desactualizada y la decisión de negocio opcional de research.md D7.

- [ ] T022 [P] Verificación manual — quickstart.md Escenario 4 (edge cases): promociones mixtas en
  la misma orden (volumen + porcentual) descuentan ambas en el `TOTAL` de la tarjeta (FR-001);
  una promoción que deja de estar vigente entre agregar y cobrar se refleja correctamente en las
  tres superficies; una orden con combo + línea plana con promoción por volumen no genera
  interferencia entre ambos mecanismos

- [X] T023 Corregir el comentario desactualizado sobre `persistedLinePromo()` en
  `../pos-heladeria/src/app/modules/tables/services/pos-terminal.store.ts` (~línea 528-535, ubicada
  antes en el archivo que la sección que edita T017) que describe `checkout_and_send` como el punto
  donde "el backend resuelve y congela
  `discounted_unit_price`" — corregirlo para describir los nuevos write-paths de
  `refresh_order_item_discounts` (`create_order`, `consolidate_table`, `add_item_to_order`,
  `void_item`) como el punto real de persistencia por línea, y `cart.service.submit_cart` como el
  único punto previo a esta spec (research.md D1; depende de T017 para no pisar esa edición)

- [ ] T024 [P] (Opcional — requiere decisión de negocio, research.md D7) Si el negocio pide cerrar
  de inmediato la ventana transitoria de pedidos abiertos creados antes del despliegue (en vez de
  aceptar que se corrijan en su próxima mutación), implementar un script único de backfill en
  `../pos-backend/scripts/backfill_order_item_discounts.py` que invoque
  `refresh_order_item_discounts(db, order)` sobre cada `CustomerOrder` no terminal existente al
  momento de ejecutarlo. Sin esa decisión explícita, no ejecutar esta tarea (Principio XI)

---

## Dependencies & Execution Order

### Dependencias de fase

- **Setup (Fase 1)**: sin dependencias — puede iniciar de inmediato
- **Foundational (Fase 2)**: vacía — no bloquea nada
- **Historia 1 (Fase 3)**: depende de T001 (rama `pos-backend`) — independiente de la Fase 4
- **Historia 2 (Fase 4)**: depende de T002 (rama `pos-heladeria`) — independiente de la Fase 3
  (puede implementarse y probarse con mocks de `discounted_unit_price` sin que la Fase 3 esté
  desplegada, aunque la verificación manual end-to-end de T021 es más representativa si la Fase 3
  ya corre)
- **Polish (Fase 5)**: T022 depende de que Fase 3 y Fase 4 estén completas; T023 depende de T017;
  T024 es independiente y opcional

### Dentro de la Historia 1

T003 → T004 → {T006, T007, T008 en paralelo} → {T009, T010, T011, T012 en paralelo, cada uno
depende de su call-site correspondiente} → T013 → T014. T005 depende solo de T003 y puede correr en
paralelo con T004-T012.

### Dentro de la Historia 2

T015 → T016 → T017 (las tres editan el mismo archivo, por eso van secuenciales, sin `[P]`) →
{T018, T019 en paralelo, archivos distintos} → T020 → T021.

### Oportunidades de paralelismo

- T001 y T002 (repos distintos)
- T006, T007, T008 (archivos distintos de `pos-backend`, todos dependen solo de T004)
- T009, T010, T011 (archivos de test distintos); T012 depende específicamente de T007
- T018 y T019 (archivos distintos de `pos-heladeria`, ambos dependen de T017)
- T022 y T024 (sin dependencias cruzadas con el resto de Polish)

---

## Parallel Example: Historia 1 — wiring de los 3 write-paths

```bash
# Tras completar T004 (refresh_order_item_discounts ya existe en checkout.py):
Task: "Llamar refresh_order_item_discounts en create_order (orders/service.py)"
Task: "Llamar refresh_order_item_discounts en consolidate_table/add_item_to_order (orders/consolidation.py)"
Task: "Llamar refresh_order_item_discounts en void_item (orders/kitchen.py)"
```

## Parallel Example: Historia 2 — tests tras el agrupamiento

```bash
# Tras completar T017 (persistedItemsView ya agrupa líneas planas):
Task: "Casos de agrupamiento/reversión en pos-terminal.store.spec.ts"
Task: "Caso de una sola card renderizada en pos-order-panel.component.spec.ts"
```

---

## Implementation Strategy

### MVP primero (Historia 1 únicamente)

1. Fase 1: Setup (T001-T002)
2. Fase 3: Historia 1 completa (T003-T014) — resuelve el problema de mayor impacto de negocio (el
   `TOTAL` que el cajero ve vs. el que realmente cobra)
3. **Detener y validar**: quickstart.md Escenario 1 y 3 antes de continuar
4. Desplegar si el negocio solo necesita cerrar la discrepancia de cobro de inmediato

### Entrega incremental

1. Setup → Historia 1 (backend, `pos-backend`) → validar y, si se desea, desplegar (MVP)
2. Historia 2 (frontend, `pos-heladeria`) → validar independientemente → desplegar
3. Polish (edge cases transversales + decisión opcional de backfill D7)

### Nota sobre independencia real entre historias

A diferencia del patrón típico donde la Historia 2 "integra con" la Historia 1, aquí ambas
historias son **genuinamente independientes en código** (research.md, plan.md Scale/Scope):
Historia 1 es 100% `pos-backend`, Historia 2 es 100% `pos-heladeria`. Pueden implementarse en
cualquier orden o en paralelo por dos personas distintas sin coordinación de archivos.
