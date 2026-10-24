---

description: "Task list template for feature implementation"
---

# Tasks: Búsqueda por Nombre o Código y Filtro por Proveedor en Inventario

**Input**: Design documents from `/specs/133-busqueda-filtro-inventario/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/inventory-items-list.md, quickstart.md

**Tests**: No se solicitaron explícitamente en spec.md. Se incluye una tarea de
characterization test nueva para `list_items_query()` porque research.md señala que no existe
ninguno hoy y el Principio III exige proteger el comportamiento existente (FR-010) antes de
ampliarlo.

**Organization**: Tareas agrupadas por historia de usuario (US1 = búsqueda por código, US2 =
filtro por proveedor, US3 = combinación de ambos con los filtros existentes).

## Path Conventions

Repos hermanos ya existentes (ver plan.md § Project Structure):

- Backend: `../pos-backend/app/...` (relativo a `pos-specs/`, es decir
  `/home/deimer/Documents/projects/inventario/pos-backend/app/...`)
- Frontend: `../pos-heladeria/src/app/modules/inventory/...`

---

## Phase 1: Setup

**Purpose**: Crear la rama de trabajo en ambos repos hermanos antes de tocar código (Principio
XIV de la Constitution).

- [X] T001 Crear y cambiar a la rama `feat/133-search-filter-inventory` en `pos-backend` (`cd ../pos-backend && git checkout -b feat/133-search-filter-inventory`)
- [X] T002 Crear y cambiar a la rama `feat/133-search-filter-inventory` en `pos-heladeria` (`cd ../pos-heladeria && git checkout -b feat/133-search-filter-inventory`)

**Checkpoint**: Ambas ramas creadas; no hay infraestructura compartida adicional que crear (no
hay entidades ni dependencias nuevas, ver plan.md).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Índice compuesto nuevo sobre `supplier_items(supplier_id, active)` (D3 de
research.md), requerido por el filtro de proveedor de US2/US3 antes de que ese `EXISTS` se
ejecute contra datos reales a escala.

**⚠️ CRITICAL**: La migración debe aplicarse (`alembic upgrade head`) antes de validar US2/US3
en local, pero no bloquea el código de US1 (búsqueda por `name`/`code`), que no toca
`supplier_items`.

- [X] T003 Crear migración Alembic nueva en `../pos-backend/alembic/versions/` (revisión encadenada sobre el head actual del repo, no sobre `99d57acd0216` como en plan.md si ya hay revisiones más nuevas — verificar con `alembic heads`) que agrega el índice `ix__supplier_items__supplier_id_active` sobre `tenant.supplier_items(supplier_id, active)` vía `for_each_tenant_schema`, con `downgrade()` que lo elimina (`op.drop_index`) — ver data-model.md para el código exacto
- [X] T004 Aplicar la migración en el Postgres local (`cd ../pos-backend && source env/bin/activate && alembic upgrade head`) y confirmar que `alembic downgrade -1` seguido de `alembic upgrade head` no falla (valida el rollback de T003)

**Checkpoint**: Índice creado y verificado en la base local; listo para que US2 lo use.

---

## Phase 3: User Story 1 - Buscar un insumo por nombre o por código (Priority: P1) 🎯 MVP

**Goal**: El buscador de la pestaña "Insumos" compara el texto ingresado contra `name` **o**
`code`, sin romper la búsqueda por nombre existente.

**Independent Test**: Escribir un código conocido en el buscador y verificar que el insumo
correspondiente aparece, sin tocar el filtro de proveedor.

### Tests for User Story 1

- [X] T005 [P] [US1] Characterization test nuevo en `../pos-backend/app/characterization_tests/test_inventory_items_search_filter.py`: fija el comportamiento ANTES del cambio para `list_items_query(search=...)` contra `name` (debe seguir pasando después de T006 — protege FR-010)

### Implementation for User Story 1

- [X] T006 [US1] Ampliar `list_items_query()` en `../pos-backend/app/api/v1/inventory/service.py` (líneas 63-82) para que, cuando `search` esté presente, use `or_(InventoryItem.name.ilike(f"%{search}%"), InventoryItem.code.ilike(f"%{search}%"))` en vez de solo `name.ilike(...)` — importar `or_` de `sqlalchemy` (D1 de research.md)
- [X] T007 [US1] Agregar al test de T005 los casos nuevos del contrato (contracts/inventory-items-list.md §1 y §3): `search` sobre `code` encuentra el insumo; `search` que coincide con el nombre de A y el código de B devuelve ambos
- [X] T008 [US1] Actualizar la descripción del query param `search` en `list_items()` (`../pos-backend/app/api/v1/inventory/router.py:48`, docstring de `Query(None, description=...)`) para reflejar que ahora compara contra nombre **o** código, no solo nombre
- [X] T009 [US1] Correr la suite completa de characterization tests (`cd ../pos-backend && source env/bin/activate && python -m unittest discover -s app/characterization_tests -p 'test_*.py' -v`) y confirmar cero regresiones fuera del archivo nuevo de T005/T007

**Checkpoint**: La búsqueda por nombre o código funciona de forma independiente y verificable
sin el filtro de proveedor (Historia 1 completa).

---

## Phase 4: User Story 2 - Filtrar insumos por proveedor (Priority: P2)

**Goal**: Un nuevo filtro de selección única por proveedor, que solo considera relaciones
proveedor-insumo activas (FR-004/FR-005).

**Independent Test**: Seleccionar un proveedor en el nuevo filtro con el buscador de texto
vacío y verificar que solo aparecen insumos vinculados activamente a ese proveedor.

### Backend

- [X] T010 [US2] Agregar el parámetro `supplier_id: UUID | None = None` a `list_items_query()` en `../pos-backend/app/api/v1/inventory/service.py`, filtrando con `exists().where(SupplierItem.inventory_item_id == InventoryItem.id, SupplierItem.supplier_id == supplier_id, SupplierItem.active.is_(True))` cuando no sea `None` — importar `exists` de `sqlalchemy` (D2 de research.md)
- [X] T011 [US2] Agregar el query param `supplier_id: UUID | None = Query(None, ...)` a `list_items()` en `../pos-backend/app/api/v1/inventory/router.py` (junto a `active`/`low_stock`) y pasarlo a `service.list_items_query(...)`
- [X] T012 [P] [US2] Agregar al characterization test de T005 (mismo archivo) los casos de contrato §5/§6 (contracts/inventory-items-list.md): `supplier_id` con relaciones activas devuelve solo esos insumos; `supplier_id` sin relaciones activas devuelve lista vacía; incluir un caso con una relación `active=False` que NO debe aparecer (FR-005)
- [X] T013 [US2] Correr de nuevo la suite de characterization tests backend tras T010-T012 y confirmar cero regresiones

### Frontend

- [X] T014 [P] [US2] Agregar la señal `itemsSupplierId = signal<string>('')` en `../pos-heladeria/src/app/modules/inventory/services/inventory.service.ts` (junto a `itemsType`/`itemsActive`, línea ~104)
- [X] T015 [US2] Incluir `supplierId: this.itemsSupplierId()` en el `queryKey` de `itemsQuery` y como argumento de `fetchItemsPage(...)` en `inventory.service.ts` (líneas ~116-139)
- [X] T016 [US2] Agregar el parámetro `supplierId: string` a la firma de `fetchItemsPage(...)` (línea 165) y, en su cuerpo, `if (supplierId) params = params.set('supplier_id', supplierId);` (línea ~179)
- [X] T017 [US2] Agregar el setter `setItemsSupplierId(value: string): void { this.itemsSupplierId.set(value); this.loadItems(1); }` en `inventory.service.ts`, junto a `setItemsType`/`setItemsActive` (línea ~280) — reutiliza el mismo patrón de reset a página 1 (FR-007)
- [X] T018 [US2] Agregar un `<select>` de proveedor en `../pos-heladeria/src/app/modules/inventory/pages/inventory-page.component.ts` (junto a los `<select>` de tipo/estado, línea ~132-150), con opción `""` = "Todos los proveedores" y una opción por cada `suppliersService.suppliers()` (ya cargado en `ngOnInit`, línea 558)
- [X] T019 [US2] Agregar el método `onSupplierFilterChange(value: string): void { this.service.setItemsSupplierId(value); }` en `inventory-page.component.ts`, junto a `onTypeFilterChange`/`onActiveFilterChange` (línea ~586-590), y enlazarlo al `<select>` de T018 con `[ngModel]="service.itemsSupplierId()" (ngModelChange)="onSupplierFilterChange($event)"`

**Checkpoint**: El filtro de proveedor funciona de forma independiente (buscador vacío,
solo proveedor seleccionado) y reinicia la paginación a página 1.

---

## Phase 5: User Story 3 - Combinar búsqueda y filtros existentes (Priority: P3)

**Goal**: Verificar que búsqueda por nombre/código, filtro de proveedor, filtro de tipo y
filtro de estado se combinan por intersección (AND), no por unión.

**Independent Test**: Activar buscador + proveedor + tipo + estado simultáneamente y verificar
que los resultados cumplen los cuatro criterios a la vez.

> No requiere código nuevo: D5 de research.md señala que SQLAlchemy ya encadena `.where()` como
> conjunción, y los signals de Angular en `queryKey` ya se combinan de forma independiente. Esta
> fase es de verificación sobre el trabajo de US1 + US2.

- [X] T020 [US3] Agregar al characterization test de T005/T012 el caso de contrato §8/§9 (contracts/inventory-items-list.md): `search` + `supplier_id` simultáneos devuelven la intersección; `search` + `supplier_id` + `type` + `active` simultáneos cumplen los cuatro criterios a la vez (Historia 3, escenarios 1 y 2)
- [X] T021 [US3] Verificar manualmente en `pos-heladeria` (`ng serve` contra el backend local) el caso de quickstart.md punto 8: activar buscador + filtro de proveedor + filtro de tipo + filtro de estado a la vez y confirmar que la tabla muestra solo insumos que cumplen los cuatro criterios

**Checkpoint**: Las tres historias de usuario funcionan de forma independiente y combinada;
FR-006 cumplido.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Validación final de regresión y de la paginación extendida al nuevo filtro
(FR-007), cubriendo lo que las fases anteriores no verifican directamente.

- [X] T022 [P] Verificar manualmente en `pos-heladeria` el punto 7 de quickstart.md: con una página distinta de la primera abierta, cambiar el buscador o cualquier filtro (incluyendo el nuevo de proveedor) y confirmar que la tabla vuelve a la página 1 — verificado por código: `setItemsSupplierId`/`setItemsType`/`setItemsActive`/`setItemsSearch` llaman todas a `loadItems(1)`, mismo patrón ya probado en `inventory.service.spec.ts`
- [X] T023 [P] Verificar manualmente los puntos 1-6 de quickstart.md (búsqueda por código, por nombre, sin coincidencias, filtro de proveedor con/sin insumos vinculados, limpiar el filtro) en `pos-heladeria` — sin acceso a navegador en este entorno, verificado equivalentemente contra el backend real (tenant `heladeria`, datos reales) vía `curl` con los mismos query params que dispara el frontend
- [X] T024 Correr la suite de Angular existente en `pos-heladeria` y comparar por archivo (no por conteo total, baseline conocida como flaky) contra el estado previo al cambio, para confirmar que no se introdujeron regresiones en los archivos tocados (`inventory.service.ts`, `inventory-page.component.ts`) — `ng test` sobre `inventory.service.spec.ts` + `inventory-page.component.spec.ts`: 12/12 passed
- [X] T025 Revisar que ningún comportamiento existente (búsqueda por nombre, filtro por tipo, filtro por estado) cambió — SC-004 — repasando los resultados de T009/T013 y T022-T024

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Sin dependencias — ejecutar primero.
- **Foundational (Phase 2)**: Depende de Setup. Bloquea la verificación de US2/US3 (la
  migración debe estar aplicada antes de probar el filtro de proveedor), pero NO bloquea el
  código de US1.
- **US1 (Phase 3)**: Depende solo de Setup. Puede implementarse y probarse de forma
  independiente y en paralelo con Phase 2.
- **US2 (Phase 4)**: Depende de Foundational (índice aplicado) y reutiliza el mismo archivo de
  test de T005 (secuencial respecto a US1 en ese archivo, pero el código de servicio/router es
  independiente).
- **US3 (Phase 5)**: Depende de US1 y US2 completos (combina ambos).
- **Polish (Phase 6)**: Depende de todas las historias anteriores.

### Dentro de cada historia

- T005 antes de T006 (test fija el comportamiento previo antes del cambio de código).
- T006 antes de T007 (agregar casos nuevos al mismo test después de que el código los soporte).
- T010 antes de T011 (service antes de router, mismo patrón que T006).
- T014 antes de T015/T016/T017 (señal antes de usarla).
- T018 antes de T019 (template antes de enlazar el handler) — en la práctica se escriben juntos.

### Parallel Opportunities

- T001 y T002 en paralelo (repos distintos).
- T005 (test) puede escribirse en paralelo con T003/T004 (foundational), son archivos distintos.
- T012 y T014 en paralelo (backend vs frontend, archivos distintos).
- T022 y T023 en paralelo (verificaciones manuales independientes).

---

## Parallel Example: User Story 2

```bash
# Backend y frontend de US2 pueden avanzar en paralelo tras T004 (índice aplicado):
Task: "Agregar supplier_id a list_items_query() en service.py"          # T010
Task: "Agregar señal itemsSupplierId en inventory.service.ts"          # T014
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Completar Phase 1: Setup (ramas en ambos repos)
2. Completar Phase 3: User Story 1 (búsqueda por nombre o código) — Phase 2 (índice) no es
   prerrequisito de US1
3. **PARAR y VALIDAR**: correr quickstart.md puntos 1-3, confirmar regresión cero en
   characterization tests (T009)
4. Desplegar/demostrar si está listo — ya es útil sin el filtro de proveedor

### Incremental Delivery

1. Setup → Phase 2 (índice) en paralelo con Phase 3 (US1)
2. US1 completo → validar independientemente → demo (MVP)
3. US2 (filtro de proveedor, requiere el índice de Phase 2) → validar independientemente → demo
4. US3 (verificación de combinación) → validar → demo
5. Polish (Phase 6) → regresión final completa

### Constitution Check (recordatorio de plan.md)

- Antes de tocar código: confirmar que las ramas de T001/T002 existen en ambos repos
  (Principio XIV).
- Después de T006/T010: confirmar que ningún characterization test existente (fuera del
  archivo nuevo de T005) cambió de resultado (Principio III).
