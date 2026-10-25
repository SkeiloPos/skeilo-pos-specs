---

description: "Task list template for feature implementation"
---

# Tasks: Compra de Insumos con Conversión a Unidad Base

**Input**: Design documents from `/specs/134-conversion-unidades-compra/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/api-changes.md, quickstart.md (todos presentes)

**Tests**: No se pidieron tests explícitamente en la spec, pero el proyecto usa
characterization tests + scripts autoejecutables como patrón establecido
(`test_purchase_presentation.py`, `test_supplier_items.py`) — se incluyen tareas de test
porque research.md y quickstart.md ya los dan por hecho como parte del cambio (actualizar
`test_core_units.py`, crear `test_purchase_unit_conversion.py`), no como añadido fuera de
alcance.

**Organización**: Las tareas están agrupadas por user story (US1/US2/US3) para permitir
implementación y prueba independiente de cada una. Rutas relativas a
`/home/deimer/Documents/projects/inventario/` (repos hermanos `pos-backend/`,
`pos-heladeria/`).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Puede ejecutarse en paralelo (archivos distintos, sin dependencias)
- **[Story]**: User story a la que pertenece (US1, US2, US3)
- Rutas de archivo exactas en cada descripción

---

## Phase 1: Setup

**Purpose**: Preparar la migración aditiva y los puntos de entrada que todas las historias usarán.

- [X] T001 Crear archivo de migración Alembic nuevo en `pos-backend/alembic/versions/<rev>_134_unit_conversion_compras.py` (usar `alembic revision -m "134_unit_conversion_compras"` desde el venv de `pos-backend`), con `down_revision` apuntando a la head actual (`a76b5f12a85b_133_supplier_items_supplier_active_index.py`)

**Checkpoint**: Hay un archivo de migración vacío listo para recibir los cambios de esquema de la Fase 2.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Cambios de esquema y de modelo que **todas** las user stories necesitan antes de poder implementarse. Ninguna historia puede avanzar hasta que esta fase esté completa.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T002 Añadir columnas `dimension: String(100) NOT NULL` y `factor_to_base: Numeric(18,6) NOT NULL DEFAULT 1` a `UnitMeasure` en `pos-backend/app/models/unit_measure.py` (research.md D1/D2)
- [X] T003 [P] Crear modelo `UnitMeasureFactorChange` (tabla `unit_measure_factor_changes`, esquema `tenant`: `id`, `unit_measure_id` FK, `old_factor`, `new_factor`, `changed_by`, `changed_at`) en nuevo archivo `pos-backend/app/models/unit_measure_factor_change.py` (data-model.md)
- [X] T004 [P] Ensanchar `InventoryItem.current_stock` → `Numeric(18,6)` y `InventoryItem.unit_cost` → `Numeric(18,6)` en `pos-backend/app/models/inventory_item.py` (research.md D4)
- [X] T005 [P] Ensanchar `InventoryMovement.quantity` → `Numeric(18,6)` en `pos-backend/app/models/inventory_movement.py` (research.md D4)
- [X] T006 [P] Añadir `voided_at: datetime | None` y `voided_by: UUID | None` a `Purchase` en `pos-backend/app/models/purchase.py`
- [X] T007 [US-shared] Añadir a `PurchaseItem` en `pos-backend/app/models/purchase.py`: `unit_measure_id` (FK `unit_measures.id`, NOT NULL tras backfill), `conversion_factor_applied` (`Numeric(18,6)` NOT NULL DEFAULT 1), `quantity_base` (`Numeric(18,6)` NOT NULL), `cost_base` (`Numeric(18,6)` NOT NULL) (depende de T002; data-model.md)
- [X] T008 [P] Añadir `REF_PURCHASE_VOID = "purchase_void"` a `pos-backend/app/core/inventory_reasons.py`, junto a `REF_ORDER_VOID`
- [X] T009 [P] Añadir `Tenant.unit_conversion_enabled: bool NOT NULL DEFAULT true` (esquema `shared`) en `pos-backend/app/core/models.py` (research.md D8)
- [X] T010 Completar la migración `pos-backend/alembic/versions/<rev>_134_unit_conversion_compras.py` (T001) con: `add_column` para T002–T009, `create_table` para `unit_measure_factor_changes` (T003), backfill SQL para `unit_measures.dimension='general'`/`factor_to_base=1` en filas existentes, backfill SQL para `purchase_items` (`unit_measure_id = inventory_items.unit_measure_id` vía join, `conversion_factor_applied=1`, `quantity_base=quantity`, `cost_base=unit_cost`) por cada tenant schema, y los `NOT NULL`/FK finales después del backfill (depende de T002–T009; research.md D2/D5, data-model.md)
- [X] T011 Actualizar `test_rn_cat_41_unit_measure_real_no_tiene_dimension_attributeerror` y `test_rn_cat_41_unit_measure_no_declara_esas_columnas_en_absoluto` en `pos-backend/app/characterization_tests/test_core_units.py` para reflejar que `UnitMeasure` ya declara `dimension`/`factor_to_base` (citar spec 134 en el comentario), sin tocar `ConvertWithDuckTypedUnitsTests` (depende de T002; research.md D2)
- [X] T012 Aplicar la migración con `alembic upgrade head` desde el venv de `pos-backend` y verificar que no falla sobre el Postgres local (depende de T010)

**Checkpoint**: Esquema listo; `convert()` ya no lanza `AttributeError` contra el modelo real; el resto del código de aplicación aún no usa las columnas nuevas.

---

## Phase 3: User Story 1 - Registrar una compra en la unidad del proveedor (Priority: P1) 🎯 MVP

**Goal**: El encargado puede capturar una línea de compra en KG/LB/etc. y el sistema calcula y persiste la cantidad/costo en unidad base del insumo al confirmar, sin tocar el stock antes de confirmar.

**Independent Test**: Registrar y confirmar una compra de un insumo en una unidad distinta a su base y verificar que el stock aumentó en la cantidad base correcta y el costo unitario base es el esperado (quickstart.md Escenario 1 y 3).

### Implementation for User Story 1

- [X] T013 [US1] Añadir `unit_measure_id: UUID | None` y `Field(gt=0)` en `quantity`/`unit_cost` para el nuevo modo, a `PurchaseItemIn` en `pos-backend/app/api/v1/inventory/schemas.py` (contracts/api-changes.md, research.md D11)
- [X] T014 [US1] Añadir `unit_measure_id`, `conversion_factor_applied`, `quantity_base`, `cost_base` a `PurchaseItemResponse` en `pos-backend/app/api/v1/inventory/schemas.py`
- [X] T015 [US1] En `_resolve_purchase_line` (`pos-backend/app/api/v1/inventory/service.py:164`), añadir la rama nueva: cuando `unit_measure_id` viene en la línea (mutuamente excluyente con `supplier_item_id`), cargar la `UnitMeasure` elegida y la unidad base del insumo, llamar `app.core.units.convert()` para resolver `conversion_factor_applied` y validar la dimensión (422 si no coincide, reutilizando el error de `convert()` — RN-CAT-40), calcular `quantity_base = quantity * conversion_factor_applied` y `cost_base = unit_cost / conversion_factor_applied` (depende de T007, T013; research.md D5/D7)
- [X] T016 [US1] En la misma función, para las dos rutas existentes (directa y `supplier_item_id`), fijar `quantity_base = quantity` y `cost_base = unit_cost` (unidad base ya resuelta hoy), y `unit_measure_id = <unidad base del insumo>`, `conversion_factor_applied = 1` explícitamente (depende de T015; research.md D5)
- [X] T017 [US1] Actualizar `create_purchase`/`create_purchase_order`/`receive_purchase` en `pos-backend/app/api/v1/inventory/service.py` para que `record_movement()` reciba `quantity_base` (no `quantity`) y la actualización de `item.unit_cost` use `cost_base` (no `unit_cost`) (depende de T015, T016; research.md D5/D6, FR-006/FR-007)
- [X] T018 [US1] Validar `quantity > 0` y `unit_cost > 0` en la nueva rama de `_resolve_purchase_line`, devolviendo 422 con el mensaje "La cantidad debe ser mayor que cero" cuando corresponda (depende de T015; FR-015)
- [X] T019 [P] [US1] Añadir campos equivalentes (`unit_measure_id?`, `conversion_factor_applied?`, `quantity_base?`, `cost_base?`) a la interfaz `PurchaseItem`/`PurchaseLineForm` en `pos-heladeria/src/app/modules/inventory/interfaces/inventory.interface.ts`
- [X] T020 [US1] En `pos-heladeria/src/app/modules/inventory/components/purchase-form.component.ts`, añadir un segundo selector de unidad por línea (poblado vía `unit-measure.service.ts`), mutuamente excluyente con el selector de presentación de proveedor ya existente, con vista previa de equivalencia en texto ("= 2.000 g") calculada en cliente con el `factor_to_base` ya cargado, sin llamada al servidor por tecla (depende de T019; FR-014)
- [X] T021 [US1] Crear script autoejecutable `pos-backend/app/scripts/test_purchase_unit_conversion.py`, mismo patrón que `test_purchase_presentation.py`: cubre acceptance scenarios 1-4 de US1 (compra en KG con factor exacto, compra en LB sin pérdida de precisión, cantidad/costo ≤0 rechazados) contra un tenant real con datos desechables (depende de T012, T015–T018; quickstart.md Escenarios 1 y 3)

**Checkpoint**: User Story 1 funciona de punta a punta — se puede demostrar de forma independiente.

---

## Phase 4: User Story 2 - Elegir solo unidades válidas para el insumo (Priority: P2)

**Goal**: El selector de unidad de una línea de compra solo ofrece unidades activas del mismo grupo de medida que la unidad base del insumo, y el servidor rechaza cualquier línea que no cumpla esto, incluso si viene por fuera del selector.

**Independent Test**: Abrir el selector de unidad de dos insumos de distinto grupo y verificar que cada uno solo ofrece las unidades de su propio grupo; desactivar una unidad y verificar que desaparece del selector (quickstart.md Escenario 4).

### Implementation for User Story 2

- [X] T022 [US2] Añadir query param `dimension: str | None` a `GET /unit-measures` en `pos-backend/app/api/v1/unit_measures/router.py`, filtrando por `UnitMeasure.dimension == dimension` además del filtro `active` ya existente (depende de T002; contracts/api-changes.md)
- [X] T023 [US2] Añadir `dimension`/`factor_to_base` a `UnitMeasureCreate` (obligatorios, `factor_to_base > 0`) y a `UnitMeasureResponse` en `pos-backend/app/api/v1/unit_measures/schemas.py` (depende de T002; contracts/api-changes.md)
- [X] T024 [US2] Añadir `Tenant.unit_conversion_enabled` a `_resolve_purchase_line` (`pos-backend/app/api/v1/inventory/service.py`): si es `false`, rechazar con 422 cualquier `unit_measure_id` en la línea que no sea igual al `unit_measure_id` del insumo (depende de T009, T015; FR-016)
- [X] T025 [P] [US2] Añadir `dimension`/`factor_to_base` a la interfaz de unidades y método de filtro por `dimension` en `pos-heladeria/src/app/core/services/unit-measure.service.ts`
- [X] T026 [US2] En `purchase-form.component.ts`, pedir `GET /unit-measures?dimension=<dimension del insumo>&active=true` para poblar el selector de unidad de cada línea (depende de T020, T022, T025; research.md D7/D12)
- [X] T027 [P] [US2] Añadir toggle `unit_conversion_enabled` (editable solo por ADMIN) a `pos-heladeria/src/app/modules/settings/pages/tenant-info.component.ts`, junto a los demás ajustes del tenant (depende de T009)
- [X] T028 [US2] Extender `pos-backend/app/scripts/test_purchase_unit_conversion.py` (T021) con los acceptance scenarios de US2: selector filtrado por dimensión, 422 por dimensión incompatible aunque no pase por el selector, unidad desactivada deja de aparecer, `unit_conversion_enabled=false` restringe a la unidad base (depende de T021, T022, T024; quickstart.md Escenario 4)

**Checkpoint**: User Stories 1 y 2 funcionan juntas, de forma independiente.

---

## Phase 5: User Story 3 - Conservar el historial de compras frente a cambios posteriores (Priority: P3)

**Goal**: Las líneas de compra confirmadas conservan su unidad/factor/cantidades originales aunque el factor de la unidad cambie después; anular una compra revierte el stock usando esos valores guardados, y un cambio de factor exige rol ADMIN y queda auditado.

**Independent Test**: Confirmar una compra, cambiar el factor de la unidad usada, y verificar que la compra conserva su factor y cantidad base originales; anular una compra confirmada y verificar que el stock se revierte exactamente en la cantidad base guardada (quickstart.md Escenario 5).

### Implementation for User Story 3

- [X] T029 [US3] Añadir `dimension`/`factor_to_base` opcionales a `UnitMeasureUpdate` en `pos-backend/app/api/v1/unit_measures/schemas.py`; crear `FactorChangeResponse` (`id`, `unit_measure_id`, `old_factor`, `new_factor`, `changed_by`, `changed_at`) (depende de T023; contracts/api-changes.md)
- [X] T030 [US3] En `PATCH /unit-measures/{id}` (`pos-backend/app/api/v1/unit_measures/router.py`), cuando el body trae `factor_to_base` distinto del actual: exigir `require_tenant_admin` (403 para otros roles) e insertar una fila en `unit_measure_factor_changes` con `old_factor`/`new_factor`/`changed_by`/`changed_at`; los demás campos (`name`, `abbreviation`, `active`, `dimension`) no requieren ese rol (depende de T003, T029; research.md D10, FR-011/FR-011a)
- [X] T031 [US3] Nuevo endpoint `GET /unit-measures/{id}/factor-changes` en `pos-backend/app/api/v1/unit_measures/router.py`, devuelve el historial ordenado por `changed_at` (depende de T003, T029; FR-011)
- [X] T032 [US3] Añadir `voided_at`/`voided_by` a `PurchaseResponse` en `pos-backend/app/api/v1/inventory/schemas.py` (depende de T006)
- [X] T033 [US3] Nueva función `void_purchase(db, purchase_id, user_id)` en `pos-backend/app/api/v1/inventory/service.py`: 404 si no existe, 409 si `voided_at` ya está puesto, y por cada `PurchaseItem` llamar `record_movement(type="out", quantity=pi.quantity_base, reason=AJUSTE, reference_type=REF_PURCHASE_VOID, reference_id=purchase.id)` dentro de la misma transacción `with_for_update()` que ya usa `record_movement()`, luego marcar `voided_at`/`voided_by` (depende de T006, T008, T017; research.md D9, FR-012/FR-013)
- [X] T034 [US3] Nuevo endpoint `POST /inventory/purchases/{id}/void` en `pos-backend/app/api/v1/inventory/router.py`, llama a `void_purchase()` y devuelve `PurchaseResponse` (depende de T032, T033; contracts/api-changes.md)
- [X] T035 [US3] En `pos-backend/app/api/v1/inventory/router.py`, `PATCH /items/{item_id}`: si `body.unit_measure_id` viene y difiere del actual, y existe al menos un `InventoryMovement` para ese insumo → 409 "No se puede cambiar la unidad base de un insumo con movimientos registrados" (depende de T012; research.md D3, FR-002)
- [X] T036 [P] [US3] Añadir `voidPurchase(purchaseId)` a `pos-heladeria/src/app/modules/inventory/services/inventory.service.ts`
- [X] T037 [US3] Extender `pos-backend/app/scripts/test_purchase_unit_conversion.py` (T021/T028) con los acceptance scenarios de US3: cambio de factor por no-ADMIN (403) y por ADMIN (200 + historial), compra confirmada conserva factor/cantidad base tras el cambio, anulación revierte stock exacto, doble anulación rechazada (409) (depende de T021, T030, T031, T033, T034; quickstart.md Escenario 5)

**Checkpoint**: Las tres user stories funcionan juntas de forma independiente; el historial es confiable frente a cambios de factor y anulaciones.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Verificación final de regresión y limpieza menor que atraviesa las tres historias.

- [X] T038 Correr la suite completa de `app/characterization_tests/` (`pos-backend`) y confirmar que solo cambian las aserciones de `test_core_units.py` tocadas en T011; ningún otro characterization test se ve afectado
- [X] T039 [P] Correr `app/scripts/test_purchase_presentation.py` y `app/scripts/test_supplier_items.py` sin modificarlos, para confirmar que la ruta `supplier_item_id` (spec 106/107) sigue pasando igual (research.md D5, Principio II)
- [X] T040 Confirmar manualmente en el frontend (`pos-heladeria`) que el flujo de presentaciones de proveedor en `purchase-form.component.ts` sigue funcionando igual y coexiste sin mezclarse con el nuevo selector de unidad (T020/T026)
- [X] T041 Ejecutar los 5 escenarios de `quickstart.md` de punta a punta contra el Postgres local, confirmando los valores exactos esperados en cada paso (depende de T012–T037)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias — puede iniciar de inmediato.
- **Foundational (Phase 2)**: depende de Setup (T001) — bloquea todas las user stories.
- **User Story 1 (Phase 3)**: depende de Foundational completo (en particular T007, T012).
- **User Story 2 (Phase 4)**: depende de Foundational; se apoya en el endpoint/selector de US1 (T015, T020) pero es independientemente verificable.
- **User Story 3 (Phase 5)**: depende de Foundational (T003, T006, T008) y de `record_movement`/`_resolve_purchase_line` de US1 (T017).
- **Polish (Phase 6)**: depende de que las tres user stories estén completas.

### User Story Dependencies

- **US1 (P1)**: ninguna dependencia de otra historia.
- **US2 (P2)**: usa el selector/endpoint de compra que US1 introduce (T015, T020), pero es probable e independientemente testeable una vez existen.
- **US3 (P3)**: usa `quantity_base`/`record_movement()` de US1 (T015–T017) para `void_purchase`.

### Within Each User Story

- Modelos/schemas antes de lógica de servicio.
- Lógica de servicio antes de endpoints/router.
- Backend antes de frontend (el frontend consume contratos ya definidos en contracts/api-changes.md, no bloquea al backend).
- Script de test de la historia al final de su propia fase.

### Parallel Opportunities

- T003, T004, T005, T006 (Fase 2) son archivos de modelo distintos — en paralelo.
- T008, T009 (Fase 2) son archivos distintos de los anteriores — en paralelo.
- T019 (interfaz frontend) puede avanzar en paralelo con T013–T018 (backend) una vez se conoce el contrato de contracts/api-changes.md.
- T025, T027 (frontend US2) son archivos distintos — en paralelo entre sí y con T022–T024 (backend US2).
- T036 (frontend US3) en paralelo con T029–T035 (backend US3).
- T039 (Fase 6) en paralelo con T038.

---

## Parallel Example: Foundational Phase

```bash
# Modelos independientes en paralelo tras T002:
Task: "Crear modelo UnitMeasureFactorChange en pos-backend/app/models/unit_measure_factor_change.py"
Task: "Ensanchar InventoryItem.current_stock/unit_cost en pos-backend/app/models/inventory_item.py"
Task: "Ensanchar InventoryMovement.quantity en pos-backend/app/models/inventory_movement.py"
Task: "Añadir voided_at/voided_by a Purchase en pos-backend/app/models/purchase.py"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Completar Fase 1: Setup (T001).
2. Completar Fase 2: Foundational (T002–T012) — bloquea todo lo demás.
3. Completar Fase 3: User Story 1 (T013–T021).
4. **PARAR y VALIDAR**: correr `test_purchase_unit_conversion.py` y el Escenario 1/3 de quickstart.md de forma independiente.
5. Demostrar/entregar si está listo — ya resuelve el núcleo del problema de negocio (conversión sin cálculo manual).

### Incremental Delivery

1. Setup + Foundational → base lista.
2. Añadir US1 → validar independientemente → demo (MVP).
3. Añadir US2 → validar independientemente → demo (selector seguro).
4. Añadir US3 → validar independientemente → demo (historial confiable + anulación).
5. Fase 6 (Polish) cierra con la verificación de regresión completa.

### Notes

- [P] = archivos distintos, sin dependencias entre sí.
- No hay tests de contrato/integración separados porque el proyecto no usa pytest para
  este tipo de flujo: el patrón establecido es un script autoejecutable por feature
  (T021, extendido en T028/T037), igual que `test_purchase_presentation.py`.
- Ninguna tarea toca la ruta `supplier_item_id` existente (spec 106/107) ni introduce
  media ponderada de costo — por diseño (research.md D5/D6, Principio V).
