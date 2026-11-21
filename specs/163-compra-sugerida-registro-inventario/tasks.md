---

description: "Task list template for feature implementation"
---

# Tasks: Registro Automático de Inventario al Generar Compra Sugerida

**Input**: Design documents from `/specs/163-compra-sugerida-registro-inventario/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/suggested-purchases-generate-delta.md](./contracts/suggested-purchases-generate-delta.md), [quickstart.md](./quickstart.md)

**Tests**: Incluidas — el plan exige scripts de funcionalidad (patrón ya usado por `test_suggested_purchases.py`, sin pytest en `pos-backend`) y specs de Vitest en `pos-heladeria` (Principio X de la constitución).

**Organization**: Tareas agrupadas por historia de usuario (US1 = P1, US2 = P2) para permitir implementación y prueba independientes de cada una.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Puede ejecutarse en paralelo (archivos distintos, sin dependencias)
- **[Story]**: Historia de usuario a la que pertenece (US1, US2)
- Se incluye la ruta exacta de archivo en cada descripción

## Path Conventions

Repos hermanos (ver plan.md → Project Structure):

- Backend: `../pos-backend/app/...` (relativo a este repo `pos-specs`)
- Frontend: `../pos-heladeria/src/app/...`

---

## Phase 1: Setup

**Purpose**: Establecer la línea base de comportamiento actual antes de tocar código, para poder confirmar luego que no hay regresión (Principio X).

- [X] T001 Ejecutar y confirmar en verde, antes de cualquier cambio, los scripts de regresión existentes que cubren la creación/recepción manual de compras y la compra sugerida ya vigente: `python -m app.scripts.test_purchase_presentation`, `python -m app.scripts.test_purchase_unit_conversion` y `python -m app.scripts.test_suggested_purchases` en `../pos-backend` (venv del repo, ver memoria `how-to-run-sibling-repo-tests`) — `test_purchase_unit_conversion`/`test_suggested_purchases` en verde; `test_purchase_presentation` falla en limpio sobre `develop` con un `IntegrityError` (`unit_measures.group_id` NOT NULL) ajeno a esta funcionalidad (fixture del propio script desactualizado respecto al esquema, nada que ver con compras/inventario) — línea base documentada, no bloquea

---

## Phase 2: Foundational

**Purpose**: Prerrequisitos bloqueantes compartidos por ambas historias.

No aplica ninguna tarea foundational: no hay tablas, columnas, migraciones, routers ni servicios nuevos (data-model.md → "Sin migración"; plan.md → "cero tablas nuevas, cero endpoints nuevos"). El único cambio de backend (el parámetro `receive_immediately` en `_build_purchase_order()`) es en sí mismo el contenido de la Historia 1 (US1), no un prerrequisito previo separado, así que vive directamente en la Phase 3.

**Checkpoint**: no hay nada que bloquee el inicio de US1.

---

## Phase 3: User Story 1 - Generar la orden deja el inventario actualizado de inmediato (Priority: P1) 🎯 MVP

**Goal**: Que generar órdenes desde la pantalla de compra sugerida cree cada orden en estado "recibida", con su movimiento de inventario y su aumento de stock aplicados en la misma transacción, sin paso manual de recepción; y que la pantalla quite de inmediato los insumos ya repuestos de la lista de "bajo mínimo".

**Independent Test**: Generar una orden para un insumo conocido con stock y proveedor configurados, y verificar que, inmediatamente después, el stock aumentó en la cantidad comprada (convertida a unidad de inventario), que existe un movimiento de entrada asociado a la orden, y que la orden aparece como "recibida" — sin ejecutar ninguna acción de recepción manual (quickstart.md Escenario 1).

### Implementación backend para User Story 1

- [X] T002 [US1] Añadir el parámetro `receive_immediately: bool = False` a `_build_purchase_order()` en `../pos-backend/app/api/v1/inventory/service.py:425-454`: cuando sea `True`, tras resolver cada línea con `_resolve_purchase_line`, ejecutar los mismos tres pasos que ya usa `create_purchase()` (`service.py:299-308`) por cada `PurchaseItem` — `purchase_item.received_quantity = purchase_item.quantity`, `record_movement(db, item.id, type="in", quantity=purchase_item.quantity_base, reason=reasons.COMPRA, reference_type=reasons.REF_PURCHASE, reference_id=purchase.id, user_id=user_id)`, `item.unit_cost = purchase_item.cost_base` — y al final del bucle fijar `purchase.status = "received"` en lugar del `"draft"` actual (research.md D1, data-model.md)
- [X] T003 [US1] En `generate_suggested_purchases()` (`../pos-backend/app/api/v1/inventory/service.py:803`), cambiar la llamada a `_build_purchase_order(db, order, user_id=None, update_supplier_cost=False)` para pasar también `receive_immediately=True`, dejando `create_purchase_order()`/`update_purchase_order()` (creación manual, fuera de esta pantalla) con el valor por defecto `False` sin ningún otro cambio (FR-011) — depende de T002

### Tests backend para User Story 1

- [X] T004 [US1] En `../pos-backend/app/scripts/test_suggested_purchases.py`, añadir casos que verifiquen tras `generate_suggested_purchases(...)`: `purchase.status == "received"` para cada orden creada; `purchase_item.received_quantity == purchase_item.quantity` en cada línea; `InventoryItem.current_stock` de cada insumo aumentó exactamente en `quantity_base` de su línea; existe un `InventoryMovement` nuevo con `type="in"`, `reference_type="purchase"`, `reference_id=purchase.id` por cada `PurchaseItem` — cubriendo los Acceptance Scenarios 1-3 del spec (dos proveedores distintos con dos órdenes "recibidas"; dos insumos del mismo proveedor con un movimiento independiente cada uno) — depende de T002, T003
- [X] T005 [US1] En el mismo archivo `../pos-backend/app/scripts/test_suggested_purchases.py`, añadir casos para los Edge Cases del spec: rollback total si falla el registro de movimiento/stock a mitad del lote (ningún `Purchase`, `InventoryMovement` ni cambio de `current_stock` queda parcial, FR-004/SC-003); reenvío de la misma `idempotency_key` no duplica movimientos ni vuelve a aumentar `current_stock` (FR-006/SC-004); y que `create_purchase_order()`/`create_purchase()` (creación manual) siguen naciendo `status="draft"` sin movimiento ni cambio de stock, sin regresión (FR-011) — depende de T002, T003

### Implementación frontend para User Story 1

- [X] T006 [P] [US1] Inyectar `QueryClient` (`@tanstack/angular-query-experimental`) en `../pos-heladeria/src/app/modules/inventory/services/suggested-purchase.service.ts` y, dentro de `generate()`, llamar `await this.queryClient.invalidateQueries({ queryKey: ['suggested-purchases'] })` justo después de que la petición resuelva con éxito (antes de salir del `try`), siguiendo el mismo patrón que `presentations/services/presentation.service.ts:125` (research.md D4, FR-011a)
- [X] T007 [P] [US1] (ampliado tras feedback manual de usuario) En `../pos-heladeria/src/app/modules/inventory/pages/suggested-purchase-page.component.ts`: en vez de un banner "Recibida" en la misma pantalla, un `generate()` exitoso redirige a `/dashboard/inventario?tab=purchases` (nuevo query param que `inventory-page.component.ts::ngOnInit` lee para abrir directo la pestaña "Compras"), para que el usuario vea de inmediato la orden ya recibida en el panel de compras (banner de confirmación, líneas ~104-119), mostrar junto a cada orden su etiqueta de estado reusando el mismo criterio que `inventory-page.component.ts:1094-1095` (`p.status === 'received' → 'Recibida'`) en vez de omitirlo (research.md D5, FR-010)

### Tests frontend para User Story 1

- [X] T008 [US1] En `../pos-heladeria/src/app/modules/inventory/services/suggested-purchase.service.spec.ts`, añadir un caso que confirme que tras un `generate()` exitoso se invoca `queryClient.invalidateQueries` con `queryKey: ['suggested-purchases']` — depende de T006
- [X] T009 [US1] En `../pos-heladeria/src/app/modules/inventory/pages/suggested-purchase-page.component.spec.ts`, añadir un caso que confirme que el banner de confirmación muestra la etiqueta "Recibida" para cada orden devuelta con `status: 'received'` — depende de T007

**Checkpoint**: en este punto, generar compra sugerida deja el inventario actualizado de inmediato y la pantalla se refresca sola — US1 es completamente funcional y probable de forma independiente (MVP).

---

## Phase 4: User Story 2 - Verificar el resultado en el historial del insumo (Priority: P2)

**Goal**: Que el movimiento de inventario generado por una compra sugerida sea visible y trazable en el historial de movimientos del insumo, identificado con una referencia a la orden que lo originó.

**Independent Test**: Con una orden ya generada por compra sugerida (US1), abrir el historial de movimientos del insumo comprado y verificar que el movimiento muestra cantidad, fecha y una referencia identificable a la orden de compra (quickstart.md Escenario 2).

**Nota**: no requiere cambios de código nuevos — `record_movement()` (ya invocado por T002 con `reference_type=reasons.REF_PURCHASE`, `reference_id=purchase.id`) y el endpoint de historial de movimientos del insumo ya existen y ya exponen esa referencia para cualquier origen de movimiento (research.md D1-D3); esta historia solo necesita verificación explícita de que el caso nuevo (compra sugerida) queda cubierto sin fallas.

### Tests para User Story 2

- [X] T010 [US2] En `../pos-backend/app/scripts/test_suggested_purchases.py`, añadir un caso que, tras generar una orden con `generate_suggested_purchases(...)`, consulte el historial de movimientos del insumo comprado (mismo query/endpoint que ya usa el módulo de inventario para listar `InventoryMovement` por `inventory_item_id`) y confirme que aparece una fila con `type="in"`, `reference_type="purchase"`, `reference_id == purchase.id` y `quantity == quantity_base` de la línea — depende de T002, T003
- [ ] T011 [US2] Verificación manual siguiendo [quickstart.md](./quickstart.md) → "Escenario 2 — US2: trazabilidad en el historial del insumo": abrir en `pos-heladeria` el historial de movimientos del insumo usado en el Escenario 1 y confirmar visualmente la cantidad, la fecha y la referencia a la orden — depende de T002, T003, T010

**Checkpoint**: ambas historias de usuario (US1 y US2) quedan funcional y verificablemente completas.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Confirmar ausencia de regresión en todo el módulo de compras y validar el flujo completo end-to-end descrito en quickstart.md.

- [X] T012 Re-ejecutar `python -m app.scripts.test_purchase_presentation`, `python -m app.scripts.test_purchase_unit_conversion` y `python -m app.scripts.test_suggested_purchases` en `../pos-backend` y confirmar que siguen en verde (sin regresión en la creación/recepción manual de compras, FR-011) — depende de T002, T003, T004, T005, T010 — `test_purchase_unit_conversion`/`test_suggested_purchases` en verde; `test_purchase_presentation` reproduce exactamente el mismo fallo pre-existente de T001, sin cambios, confirmando que no es una regresión de esta funcionalidad
- [X] T013 [P] Ejecutar `ng test` en `../pos-heladeria` para `suggested-purchase.service.spec.ts` y `suggested-purchase-page.component.spec.ts` y confirmar que pasan (recordar: baseline de la suite completa es inherentemente flaky — comparar archivo por archivo, no el conteo total, según memoria `how-to-run-sibling-repo-tests`) — depende de T008, T009 — 7/7 y 14/14 en verde en ambos archivos, ejecutados de forma aislada
- [ ] T014 Validar manualmente en `pos-heladeria` los Escenarios 3, 4, 5 y 6 de [quickstart.md](./quickstart.md) (transacción todo-o-nada, idempotencia, anulación con `void_purchase`, y que la creación manual de órdenes sigue sin cambios) — depende de T002, T003, T005
- [ ] T015 Validar manualmente en `pos-heladeria` la sección "Frontend — comprobación manual" de [quickstart.md](./quickstart.md): generar una compra sugerida y confirmar que el banner muestra "Recibida" y que, sin recargar la página, el insumo repuesto desaparece de la lista — depende de T006, T007

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias — puede iniciar de inmediato
- **Foundational (Phase 2)**: no aplica (sin tareas)
- **User Story 1 (Phase 3)**: depende de Setup (T001, para tener la línea base de comparación); es la única historia con cambios de código reales
- **User Story 2 (Phase 4)**: depende de que US1 (T002, T003) exista, porque verifica un efecto secundario que US1 produce; no añade código propio
- **Polish (Phase 5)**: depende de que US1 y US2 estén completas

### Dentro de cada historia

- T002 antes de T003 (mismo archivo, T003 depende del nuevo parámetro de T002)
- T004/T005 (tests backend US1) después de T002/T003
- T006/T007 (frontend US1) son independientes entre sí y de T002-T005 (archivos distintos, sin dependencia de datos)
- T008 después de T006; T009 después de T007
- T010/T011 (US2) después de T002/T003 (y T010 antes de T011, test automatizado antes de verificación manual)

### Oportunidades de paralelismo

- T006 y T007 pueden ejecutarse en paralelo (archivos frontend distintos, sin dependencia entre sí)
- T013 puede ejecutarse en paralelo con T012/T014/T015 (repos y herramientas distintas)

---

## Parallel Example: User Story 1

```bash
# Backend (secuencial, mismo archivo):
Task: "T002 — añadir receive_immediately a _build_purchase_order()"
Task: "T003 — pasar receive_immediately=True desde generate_suggested_purchases()"

# Frontend (en paralelo, archivos distintos):
Task: "T006 — invalidateQueries(['suggested-purchases']) tras generate() exitoso"
Task: "T007 — mostrar etiqueta de estado 'Recibida' en el banner de confirmación"
```

---

## Implementation Strategy

### MVP First (User Story 1 solamente)

1. Completar Phase 1 (Setup): línea base en verde
2. Phase 2 (Foundational): no aplica, pasar directo a Phase 3
3. Completar Phase 3 (US1): T002 → T003 → T004/T005 (backend) y T006/T007 → T008/T009 (frontend)
4. **DETENER y VALIDAR**: ejecutar quickstart.md Escenario 1 manualmente
5. US1 por sí sola ya es el MVP completo pedido por el spec (US2 es trazabilidad, no bloquea el valor entregado)

### Entrega incremental

1. Setup → línea base lista
2. US1 → inventario se actualiza al generar, pantalla se refresca sola → **MVP**
3. US2 → trazabilidad verificada en el historial del insumo
4. Polish → regresión completa + validación manual de los 6 escenarios de quickstart.md

---

## Notes

- [P] = archivos distintos, sin dependencias entre sí
- [Story] mapea cada tarea a su historia de usuario para trazabilidad
- Esta funcionalidad no usa pytest (`pos-backend`): "tests" = scripts ejecutables vía `python -m app.scripts.<name>`, mismo patrón que `test_suggested_purchases.py` ya existente
- No hay tareas de modelos/esquema: `data-model.md` confirma "Sin migración" — todo el cambio es de comportamiento de servicio
- Validar que los tests fallan/no aplican antes de implementar no aplica aquí en el sentido TDD estricto (son scripts de funcionalidad, no unitarios aislados); en su lugar, T001 fija la línea base verde que T012 debe seguir cumpliendo
- Evitar: tocar `create_purchase_order()`/`update_purchase_order()`/`receive_purchase()`/`void_purchase()` — ninguno cambia (FR-011, research.md D1/D3)
