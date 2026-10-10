---

description: "Task list for feature implementation"
---

# Tasks: Comprar en la presentación real, no en la unidad base

**Input**: Design documents from `/specs/107-compra-presentacion-conversion/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/api.md,
quickstart.md (todos presentes)

**Tests**: incluidas — mismo criterio que la spec 106 (Principio X de la constitución). Un
script autoejecutable `pos-backend/app/scripts/test_purchase_presentation.py` (sin pytest en
este repo), extendido incrementalmente por historia, más la regresión obligatoria de las dos
suites que esta spec promete no romper (characterization de spec 005, `test_supplier_items.py`
de spec 106).

**Organization**: tareas agrupadas por historia de usuario (spec.md).

## Path Conventions

`../pos-backend/app/...` (FastAPI) y `../pos-heladeria/src/app/...` (Angular) — igual que spec
106.

---

## Phase 1: Setup

- [X] T001 [P] Crear la rama `feat/107-compra-presentacion-conversion` en `../pos-backend`.
- [X] T002 [P] Crear la rama `feat/107-compra-presentacion-conversion` en `../pos-heladeria`.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: modelo de datos, esquemas y lectura compartida que las tres historias necesitan.

**⚠️ CRITICAL**: ninguna historia de usuario empieza antes de que esta fase termine.

- [X] T003 Crear la migración Alembic en `../pos-backend/alembic/versions/` (vía
  `@for_each_tenant_schema`, mismo patrón que la de spec 106): `op.add_column`
  `purchase_items.presentation_quantity NUMERIC(12,3) NULL` y
  `purchase_items.presentation_label VARCHAR(100) NULL` — ver `data-model.md` § Migración.
- [X] T004 [P] Agregar `presentation_quantity: Mapped[Optional[Decimal]]` y
  `presentation_label: Mapped[Optional[str]]` a `PurchaseItem` en
  `../pos-backend/app/models/purchase.py`.
- [X] T005 [P] Extender `PurchaseItemIn` en
  `../pos-backend/app/api/v1/inventory/schemas.py`: `quantity`/`unit_cost` pasan a opcionales
  (el segundo con su default actual), + `supplier_item_id`, `presentation_quantity`,
  `presentation_unit_cost`; agregar el `model_validator` "exactamente un modo" (data-model.md §
  `PurchaseItemIn`).
- [X] T006 [P] Extender `PurchaseReceiveItemIn` en `schemas.py`: `quantity` pasa a opcional +
  `presentation_quantity` nuevo; agregar su `model_validator` "exactamente uno de los dos"
  (data-model.md § `PurchaseReceiveItemIn`).
- [X] T007 Extender `PurchaseItemResponse` en `schemas.py` con `supplier_item_id`,
  `presentation_quantity`, `presentation_label` y `conversion_factor` (este último
  denormalizado, no una columna de `PurchaseItem` — ver T008) (depende de T004).
- [X] T008 [P] Crear `supplier_items.attach_conversion_factors(db, purchase_items)` en
  `../pos-backend/app/api/v1/inventory/supplier_items.py`: una sola consulta por lote que fija
  `item.conversion_factor` (atributo transitorio) en cada `PurchaseItem` cuyo
  `supplier_item_id` no sea `NULL`, leyendo `SupplierItem.conversion_factor` — mismo patrón que
  `attach_preferred_supplier_names` (spec 106).
- [X] T009 [P] Crear `supplier_items.apply_purchase_cost(db, relation, cost_per_presentation)`
  en `supplier_items.py`: fija `relation.last_cost`/`last_cost_at` (RN-15), sin `commit()`
  propio — mismo patrón que `_apply_preferred_swap` (spec 106, research.md D3).
- [X] T010 Llamar a `supplier_items.attach_conversion_factors` en los 4 puntos de
  `../pos-backend/app/api/v1/inventory/router.py` que devuelven `PurchaseResponse`/
  `Page[PurchaseResponse]` (`list_purchases`, `create_purchase`, `create_purchase_order`,
  `receive_purchase`) sobre los items de cada compra devuelta (depende de T007, T008).
- [X] T011 Correr `./env/bin/python -m unittest discover -s app/characterization_tests` en
  `../pos-backend` y confirmar que la migración/esquemas de T003–T007 no rompen ningún test
  `"CONGELA comportamiento actual:"` (Principio III).

**Checkpoint**: modelo, esquemas y lectura con `conversion_factor` listos — ninguna historia
empieza antes de este punto.

---

## Phase 3: User Story 1 - Comprar indicando la presentación real, no la unidad base (Priority: P1) 🎯 MVP

**Goal**: en una compra directa, elegir una presentación ya guardada en vez de teclear la
cantidad en unidad base; el sistema calcula y guarda la conversión, conservando lo que el
administrador realmente compró.

**Independent Test**: registrar una compra directa contra una presentación existente y
verificar que el stock, el costo y el historial de la línea quedan correctos, sin depender de
las otras historias.

### Tests for User Story 1 ⚠️

> Escribir primero; deben FALLAR antes de la implementación.

- [X] T012 [P] [US1] Escribir los escenarios 1–3 de la Historia 1 (alta directa de 1 bolsa,
  alta de 3 bolsas, compra sin relación o contra "Compra ocasional" sin cambios) en
  `../pos-backend/app/scripts/test_purchase_presentation.py`.

### Implementation for User Story 1

- [X] T013 [US1] Implementar en `create_purchase`
  (`../pos-backend/app/api/v1/inventory/service.py`) la rama "con presentación": cargar la
  relación (`get_or_404`), validar que `relation.active` y que corresponde al
  `inventory_item_id` de la línea y al `supplier_id` de la compra (422 si no, FR-009), calcular
  `quantity = presentation_quantity × relation.conversion_factor` (FR-003) y
  `unit_cost = round(presentation_unit_cost ÷ relation.conversion_factor, 2)` (FR-004) (depende
  de T005, T009).
- [X] T014 [US1] En el mismo flujo, guardar `supplier_item_id`, `presentation_quantity` y
  `presentation_label = relation.presentation` (snapshot, research.md D1) en el `PurchaseItem`
  creado; calcular el total de esa línea con los valores originales
  (`presentation_quantity × presentation_unit_cost`, FR-005), no con los derivados (depende de
  T013).
- [X] T015 [US1] Confirmar que la rama "sin presentación" de `create_purchase` sigue intacta —
  mismo código que hoy, sin ningún cálculo nuevo (FR-007).
- [X] T016 [US1] Correr `./env/bin/python -m app.scripts.test_purchase_presentation` y
  confirmar que los escenarios 1–3 de T012 pasan (depende de T013, T014, T015).
- [X] T017 [P] [US1] Frontend: extender `PurchaseLineForm`/`PurchaseItemPayload` en
  `../pos-heladeria/src/app/modules/inventory/interfaces/inventory.interface.ts` con
  `supplier_item_id?`, `presentation_quantity?`, `presentation_unit_cost?`.
- [X] T018 [US1] Frontend: `InventoryService.createPurchase`/`createPurchaseOrder` en
  `../pos-heladeria/src/app/modules/inventory/services/inventory.service.ts` envían los campos
  nuevos de una línea cuando tiene presentación elegida, y los de siempre (`quantity`/
  `unit_cost`) cuando no (depende de T017).
- [X] T019 [US1] Frontend: en
  `../pos-heladeria/src/app/modules/inventory/components/purchase-form.component.ts`, tras
  elegir insumo en una fila, resolver las presentaciones disponibles con
  `SupplierItemsService.listForItem(itemId, false)` (ya existe, spec 106) filtradas por el
  `supplier_id` ya elegido para toda la compra; si hay alguna, mostrar un selector por fila
  ("Unidad base" vs cada presentación) con la etiqueta dinámica y la equivalencia en vivo (mismo
  patrón que `SupplierItemFormComponent`, spec 106) (depende de T017, T018).
- [X] T020 [US1] Frontend: en la tabla de líneas de compra ya expandida dentro de la pestaña
  "Compras" de
  `../pos-heladeria/src/app/modules/inventory/pages/inventory-page.component.ts`, mostrar
  "{presentation_quantity} {presentation_label}" en vez de (o junto a) la cantidad en unidad
  base, cuando la línea tenga presentación (FR-011).
- [X] T021 [P] [US1] Escribir/extender
  `../pos-heladeria/src/app/modules/inventory/components/purchase-form.component.spec.ts` para
  cubrir el selector de presentación nuevo (aparece solo si hay relaciones para ese insumo+
  proveedor; "Unidad base" por defecto si no hay ninguna).

**Checkpoint**: Historia 1 funcional de punta a punta — comprar en presentación, ver el stock y
el costo correctos, y ver después qué se compró realmente.

---

## Phase 4: User Story 2 - El último costo del proveedor se actualiza solo al comprarle (Priority: P1)

**Goal**: cada compra directa contra una presentación deja el último costo de esa relación
actualizado, sin ninguna acción manual.

**Independent Test**: registrar una compra contra una presentación y verificar, inmediatamente
después, que `SupplierItem.last_cost`/`last_cost_at` cambiaron.

### Tests for User Story 2 ⚠️

- [X] T022 [P] [US2] Escribir el escenario de la Historia 2 (último costo y fecha actualizados
  tras una compra directa) en `test_purchase_presentation.py`.

### Implementation for User Story 2

- [X] T023 [US2] Invocar `supplier_items.apply_purchase_cost(db, relation,
  presentation_unit_cost)` desde `create_purchase`, en la misma transacción que T013/T014, antes
  del `commit()` final (RN-15, research.md D3) (depende de T009, T013).
- [X] T024 [US2] Correr `./env/bin/python -m app.scripts.test_purchase_presentation` y
  confirmar que el escenario de T022 pasa (depende de T023).

**Checkpoint**: Historias 1 y 2 juntas — comprar en presentación deja todo (stock, costo del
insumo, último costo del proveedor) consistente en una sola operación.

---

## Phase 5: User Story 3 - Orden de compra y recepción parcial en presentación (Priority: P2)

**Goal**: el mismo mecanismo de las Historias 1 y 2, aplicado a crear una orden de compra y a
recibirla — parcial o totalmente — más adelante, sin que el factor pueda cambiar entre medio.

**Independent Test**: crear una orden contra una presentación y recibirla en dos partes,
verificando que ambas recepciones usan el mismo factor.

### Tests for User Story 3 ⚠️

- [X] T025 [P] [US3] Escribir los escenarios de la Historia 3 (orden de 10 bolsas, recepción de
  5 + 5, costo pactado sin recalcular al recibir) en `test_purchase_presentation.py`.

### Implementation for User Story 3

- [X] T026 [US3] Extraer de `create_purchase` (T013/T014) una función compartida — p. ej.
  `_resolve_purchase_line(db, purchase, it)` en `service.py` — que calcule
  `quantity`/`unit_cost`/`presentation_quantity`/`presentation_label` para una línea, con o sin
  presentación; usarla también en `create_purchase_order`, para no duplicar la lógica entre los
  dos flujos (depende de T013, T014).
- [X] T027 [US3] Invocar `supplier_items.apply_purchase_cost` desde `create_purchase_order`
  también (RN-15 aplica igual al pactar precio en una orden, research.md D3) (depende de T009,
  T026).
- [X] T028 [US3] Implementar en `receive_purchase` (`service.py`) la rama "con presentación":
  si el `PurchaseItem` recibido tiene `supplier_item_id`, exigir `presentation_quantity` en el
  request (422 si no), leer `SupplierItem.conversion_factor` **en ese momento** (nunca del
  request, research.md D4) y convertir a unidad base antes de validar contra lo pendiente
  (RN-INV-20, sin cambios) y de llamar a `record_movement` (depende de T006).
- [X] T029 [US3] Confirmar que `receive_purchase` **no** vuelve a llamar a
  `apply_purchase_cost` — el último costo del proveedor ya quedó fijado al crear la orden
  (T027), no se repite en cada recepción (research.md D3).
- [X] T030 [US3] Correr `./env/bin/python -m app.scripts.test_purchase_presentation` y
  confirmar que los escenarios de T025 pasan (depende de T026, T027, T028, T029).
- [X] T031 [P] [US3] Frontend: en el modal de recepción de
  `../pos-heladeria/src/app/modules/inventory/pages/inventory-page.component.ts`
  (`receivePurchase`/`receiveRows`), cuando una fila tenga `presentation_label` (ya expuesto por
  T007/T010), mostrar "Pendiente: X de Y {presentation_label}" usando `conversion_factor` para
  convertir, y enviar `presentation_quantity` en vez de `quantity` al confirmar (depende de
  T007, T010).

**Checkpoint**: las 3 historias conviven — compra directa, orden y recepción parcial, todas en
presentación cuando aplica, con el mismo costo pactado sin recalcular.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T032 Correr `./env/bin/python -m app.scripts.test_supplier_items` (spec 106) y confirmar
  que sigue en verde — esta spec no debería afectarlo, pero es la suite que protege las reglas
  (factor > 0, proveedor de sistema, factor inmutable) que esta spec reutiliza sin reabrir.
- [X] T033 Correr `./env/bin/python -m unittest discover -s app/characterization_tests` una vez
  más, ya con las 3 historias implementadas, y confirmar 0 regresiones (RN-INV-16/17/22/23).
- [X] T034 [P] En `../pos-heladeria`, correr `npx ng test --watch=false` con
  `--include='src/app/modules/inventory/**/*.spec.ts'`; comparar contra la lista base conocida
  de fallos preexistentes (memoria de sesión) y confirmar que no se agregó ninguno nuevo.
- [ ] T035 Ejecutar el recorrido manual de `quickstart.md` § 3 (4 pasos de UI) contra
  `ng serve` en `../pos-heladeria`.
- [X] T036 Revisar que todo comentario, mensaje de error y docstring nuevo esté en español de
  Colombia (Principio XIII), y que las ramas/commits de esta implementación sigan los
  Principios XIV/XV antes de reportar la funcionalidad como completa.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Fase 1)**: sin dependencias.
- **Foundational (Fase 2)**: depende de Setup — bloquea las tres historias.
- **Historias (Fase 3-5)**: todas dependen de Foundational. US1 es la base que US2 extiende
  directamente (misma función `create_purchase`) y que US3 reutiliza (extraída a
  `_resolve_purchase_line`, T026) para no duplicarla en `create_purchase_order`/
  `receive_purchase`. Orden recomendado: **secuencial por prioridad** (US1 → US2 → US3), igual
  que en spec 106 — no son independientes a nivel de código entre sí.
- **Polish (Fase 6)**: depende de que las tres historias estén completas.

### Parallel Opportunities

- Fase 1: T001, T002.
- Fase 2: T004, T005, T006, T008, T009 en paralelo (archivos/funciones distintas); T003
  (migración) y T007 (depende de T004) conviene cerrarlos primero; T010 y T011 al final.
- Dentro de cada historia, la tarea de test ([P]) puede escribirse en paralelo con tareas de
  otra historia que no dependan de ella; las tareas de implementación son mayormente
  secuenciales (mismo archivo `service.py`/`purchase-form.component.ts`).

---

## Parallel Example: Foundational (Fase 2)

```bash
Task: "Agregar presentation_quantity/presentation_label a app/models/purchase.py"   # T004
Task: "Extender PurchaseItemIn en schemas.py"                                        # T005
Task: "Extender PurchaseReceiveItemIn en schemas.py"                                 # T006
Task: "Crear attach_conversion_factors en supplier_items.py"                         # T008
Task: "Crear apply_purchase_cost en supplier_items.py"                               # T009
```

---

## Implementation Strategy

### MVP First (Historia 1 solamente)

1. Completar Fase 1 (Setup) y Fase 2 (Foundational).
2. Completar Fase 3 (Historia 1).
3. **Detener y validar**: `quickstart.md` § 1, escenarios 1–3, y el paso manual 1 de § 3.
4. Ya resuelve el dolor principal: comprar en presentación sin calcular a mano — sin el
   auto-upsert del último costo (Historia 2) ni órdenes/recepción (Historia 3) todavía.

### Entrega incremental

1. Setup + Foundational → base lista.
2. + Historia 1 → comprar en presentación (MVP, demostrable).
3. + Historia 2 → último costo del proveedor siempre al día.
4. + Historia 3 → órdenes y recepción parcial cubiertas también.
5. + Polish → regresión de las dos suites protegidas verificada, frontend sin regresiones.

---

## Notes

- `[P]` = archivos distintos, sin dependencia pendiente dentro de la misma fase.
- Las "Tests" de cada historia viven en el mismo script (`test_purchase_presentation.py`),
  extendido incrementalmente — mismo patrón que `test_supplier_items.py` de spec 106.
- No se alcanza ningún checkpoint saltándose su tarea de verificación (T016, T024, T030).
- Evitar: duplicar el cálculo de conversión entre `create_purchase` y `create_purchase_order`
  (por eso T026 lo extrae a una función compartida antes de que US3 lo necesite dos veces).
