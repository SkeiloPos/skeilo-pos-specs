---

description: "Task list for: Filtro buscable de proveedor, exportación filtrada y vinculación de unidades de compra por Excel"
---

# Tasks: Filtro buscable de proveedor, exportación filtrada y vinculación de unidades de compra por Excel

**Input**: Design documents from `/specs/142-mejoras-filtros-excel-inventario/`
**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [data-model.md](./data-model.md), [research.md](./research.md), [contracts/plantilla-excel-inventario.md](./contracts/plantilla-excel-inventario.md), [quickstart.md](./quickstart.md)

**Tests**: Incluidas como tareas explícitas porque la Constitution (Principio III/X) exige actualizar characterization tests existentes y porque `plan.md` ya identifica suites concretas que quedan desincronizadas por este cambio (`test_inventory_export.py`, `test_inventory_bulk_excel.py`). No son tests nuevos de TDD "a ciegas": actualizan comportamiento ya cubierto.

**Organization**: Las tres historias son independientes entre sí (confirmado por plan.md/spec.md); se agrupan por historia en el orden de prioridad P1 → P2 → P3. Historia 1 es solo frontend (`pos-heladeria`); Historias 2 y 3 son backend (`pos-backend`) con una porción frontend menor en Historia 2.

## Path Conventions

Repos hermanos, fuera de este repo de specs:
- Backend: `../pos-backend/app/...`
- Frontend: `../pos-heladeria/src/app/...`

## Phase 1: Setup

- [X] T001 Crear la rama `feat/142-inventory-filters-excel-improvements` en `../pos-backend` y en `../pos-heladeria` (Principio XIV de la constitución) antes de tocar cualquier archivo de código.
- [X] T002 Confirmar que el entorno de pruebas está disponible: `cd ../pos-backend && source env/bin/activate && docker compose up -d postgres redis && alembic upgrade head` (memoria `how-to-run-sibling-repo-tests`); verificar que el head de Alembic no cambia (esta spec no agrega migración).

---

## Phase 2: Foundational

No hay prerrequisitos bloqueantes compartidos entre historias: ninguna introduce entidad, columna o migración nueva (data-model.md), y cada historia toca archivos propios sin superposición de código entre sí salvo la plantilla de columnas (`schemas.py`/`import_.py`/`export.py`), que Historia 3 posee por completo. Se omite esta fase y se procede directo a las historias de usuario.

---

## Phase 3: User Story 1 - Buscar dentro del filtro de proveedor en Insumos (Priority: P1) 🎯 MVP

**Goal**: El filtro de proveedor de la pestaña "Insumos" permite escribir texto para reducir las opciones, igual que el selector de insumo de "Movimientos".

**Independent Test**: Abrir el filtro de proveedor con varios proveedores registrados, escribir parte del nombre de uno y verificar que solo las coincidencias parciales (sin distinguir mayúsculas/minúsculas) quedan visibles, que "Todos los proveedores" sigue disponible con texto vacío, y que un texto sin coincidencias no rompe la pantalla.

### Implementation for User Story 1

- [X] T003 [US1] En `../pos-heladeria/src/app/modules/inventory/pages/inventory-page.component.ts`, agregar un `computed()` `supplierFilterOptions()` que mapee `suppliersService.suppliers()` a `{id, label}` y antepone la opción `{id: '', label: 'Todos los proveedores'}`, siguiendo el mismo patrón que `movementItemOptions()` (línea ~889).
- [X] T004 [US1] En el mismo archivo, reemplazar el `<select>` nativo de proveedor (líneas ~208-218) por `<app-searchable-select [options]="supplierFilterOptions()" [ngModel]="service.itemsSupplierId()" (ngModelChange)="onSupplierFilterChange($event)" placeholder="Todos los proveedores" />`, en modo local (sin el input `search`), sin modificar `onSupplierFilterChange()` ni `service.setItemsSupplierId()`.
- [X] T005 [US1] Ejecutar `cd ../pos-heladeria && npm test -- --include='**/inventory-page.component.spec.ts'` y comparar por archivo contra la baseline conocida (memoria `how-to-run-sibling-repo-tests`); ajustar specs existentes que todavía busquen el `<select>` nativo de proveedor por un selector equivalente a `app-searchable-select`.

**Checkpoint**: Historia 1 funcional y verificable de forma independiente — búsqueda, opción "Todos", texto sin coincidencias, selección aplicando el mismo filtro de siempre (quickstart.md, pasos 1-5).

---

## Phase 4: User Story 2 - Elegir qué exportar del inventario (Priority: P2)

**Goal**: `GET /inventory/items/export` acepta `supplier_id`/`type_` opcionales (intersección); el frontend ofrece elegirlos antes de exportar, con "todos" como default.

**Independent Test**: Exportar tres veces — sin filtro (todos los insumos, igual que hoy), filtrando solo por proveedor, y filtrando solo por tipo — y verificar en cada caso el subconjunto exacto; exportar con proveedor+tipo a la vez y verificar la intersección; exportar con una combinación sin coincidencias y verificar que el archivo se genera con encabezados y sin filas.

### Implementation for User Story 2

- [X] T006 [US2] En `../pos-backend/app/api/v1/inventory/router.py`, modificar `export_items()` (línea ~81) para aceptar `supplier_id: UUID | None = Query(None)` y `type_: InventoryItemType | None = Query(None, alias="type_")`, y construir `items = db.execute(service.list_items_query(type_=type_.value if type_ is not None else None, supplier_id=supplier_id)).scalars().all()` en vez de `service.list_all_items_for_export(db)`.
- [X] T007 [US2] En `../pos-backend/app/api/v1/inventory/service.py`, eliminar `list_all_items_for_export()` (línea ~104) tras confirmar por `grep -rn "list_all_items_for_export" app/` que T006 fue su único invocador.
- [X] T008 [US2] En `../pos-heladeria/src/app/modules/inventory/services/inventory.service.ts`, modificar `exportItems()` (línea ~352) para aceptar parámetros opcionales `supplierId?: string` y `type?: string` y pasarlos como query params (`supplier_id`, `type_`) solo cuando vienen definidos, sin cambiar `responseType`/`observe`.
- [X] T009 [US2] En `../pos-heladeria/src/app/modules/inventory/pages/inventory-page.component.ts`, agregar un selector de filtros de exportación (proveedor vía `app-searchable-select` reutilizando `supplierFilterOptions()` de T003, y tipo vía un `<select>` con las mismas dos opciones ya usadas por el filtro de tipo del listado) antes de invocar `exportInventory()` (línea ~1000), con "todos" como estado inicial; `exportInventory()` pasa los valores elegidos a `service.exportItems(supplierId, type)`.
- [X] T010 [P] [US2] Actualizar `../pos-backend/app/characterization_tests/test_inventory_export.py`: ajustar las suites que hoy asumen que `export_items` llama a `list_all_items_for_export` sin filtros (`ExportEndpointTests`, `ExportColumnsTests`) para que sigan pasando con `list_items_query`, y agregar casos nuevos que verifiquen `supplier_id`/`type_` por separado y en intersección, y que una combinación sin coincidencias devuelve solo encabezados (Acceptance Scenarios 1-5 de la Historia 2), citando esta spec en los comentarios de los tests nuevos.
- [X] T011 [US2] Ejecutar `cd ../pos-backend && python -m unittest app.characterization_tests.test_inventory_export -v` y confirmar que pasa.
- [X] T012 [US2] Validación manual siguiendo quickstart.md Historia 2: exportar sin filtro, por proveedor, por tipo, por ambos, y con una combinación sin coincidencias; confirmar con `curl` contra `GET /inventory/items/export?supplier_id=...&type_=raw_material` (ver quickstart.md sección "Verificación directa del endpoint").

**Checkpoint**: Historias 1 y 2 funcionan de forma independiente — exportar sin filtro sigue siendo idéntico al comportamiento actual (sin regresión, FR-005).

---

## Phase 5: User Story 3 - Definir el grupo de la unidad base y la unidad de compra por proveedor desde el Excel (Priority: P3)

**Goal**: La plantilla de Excel gana las columnas `Grupo`, `Unidad de compra` y `Factor de conversión (compra)`; al crear un insumo nuevo por importación, la unidad base se vincula/crea en el grupo indicado, y la unidad de compra del proveedor preferido se resuelve como una `UnitMeasure` real del mismo grupo.

**Independent Test**: Importar un archivo con insumos nuevos que incluyen columna de grupo para la unidad base y columnas de unidad de compra/factor para el proveedor preferido, y verificar: (a) la unidad base queda en el grupo indicado (creándolo si no existía); (b) la relación con el proveedor preferido queda con la unidad de compra y el factor indicados como una `UnitMeasure` real del mismo grupo; (c) los casos de conflicto/ambigüedad/datos faltantes fallan la fila sin modificar nada ya existente.

### Implementation for User Story 3

- [X] T013 [US3] En `../pos-backend/app/api/v1/inventory/schemas.py`, extender `INVENTORY_TEMPLATE_HEADERS` (línea ~19) a 10 columnas insertando `"Grupo"` después de `"Unidad"` y agregando `"Unidad de compra"`, `"Factor de conversión (compra)"` al final, según el contrato en `contracts/plantilla-excel-inventario.md`.
- [X] T014 [US3] En `../pos-backend/app/api/v1/inventory/import_.py`, actualizar `_LEGACY_TEMPLATE_HEADERS` y `validar_estructura()` (líneas ~42-72) para seguir aceptando como estructuralmente válidos, además del nuevo formato de 10 columnas: el formato de 8 columnas de la spec 139 (igual al `INVENTORY_TEMPLATE_HEADERS` previo a T013) y el legado de 11 columnas de la spec 109, sin romper la detección de "columnas faltantes/de más/fuera de orden" para cualquier otro conjunto.
- [X] T015 [US3] En el mismo archivo, actualizar los índices de columna (línea ~35, `_CODE, _NAME, _TYPE, _UNIT, _STOCK, ...`) para reflejar las 10 columnas del formato vigente (`_CODE, _NAME, _TYPE, _UNIT, _GROUP, _STOCK, _MIN, _COST, _SUPPLIER, _PURCHASE_UNIT, _PURCHASE_FACTOR`), ajustando `validar_y_aplicar_fila()` para leer estos índices según el formato de encabezado detectado (8, 10 u 11 columnas) sin asumir siempre 10.
- [X] T016 [US3] En el mismo archivo, modificar `_resolve_unit(db, nombre_unidad, nombre_grupo=None)` (línea ~87) para: si `nombre_grupo` viene vacío, conservar el comportamiento actual (crea grupo propio nuevo); si viene con texto, normalizarlo (mayúsculas, espacios recortados) y buscar un `UnitMeasureGroup` existente por `name` case-insensitive — reutilizarlo si existe o crearlo si no — y resolver/crear la `UnitMeasure` dentro de ese grupo. Si el nombre de unidad ya existe en el negocio en un grupo **distinto** al resuelto, lanzar `ValueError` de ambigüedad de grupo (FR-012) sin crear ni modificar nada.
- [X] T017 [US3] En el mismo archivo, agregar una función nueva `_resolve_purchase_unit(db, group_id, nombre_unidad, factor)` que implemente el algoritmo de research.md D7: busca una `UnitMeasure` activa en `group_id` por `abbreviation`/`name` case-insensitive; si coincide y el factor de la fila está vacío o es igual al `factor_to_base` vigente, reutiliza esa unidad; si coincide y el factor difiere, lanza `ValueError` de conflicto de factor (FR-016); si coincide por nombre en otro grupo, lanza `ValueError` de ambigüedad (FR-017); si no coincide y hay factor, crea una `UnitMeasure` nueva en ese grupo (`is_base=False`, `factor_to_base=factor`); si no coincide y no hay factor, lanza `ValueError` de dato obligatorio faltante (FR-018).
- [X] T018 [US3] En el mismo archivo, modificar `_apply_preferred_supplier(db, item, fila)` (línea ~178) para: si la fila trae `Unidad de compra` y/o `Factor de conversión (compra)` pero **no** trae `Proveedor preferido`, lanzar `ValueError` antes de cualquier otra operación (FR-020a); si trae proveedor preferido y unidad de compra, resolver la `UnitMeasure` con `_resolve_purchase_unit()` usando el `group_id` de la unidad base ya resuelta del insumo, y construir la relación `SupplierItem` nueva con `unit_measure_id=<resuelta>, presentation=None, conversion_factor=None` en vez de ambos campos legados en `NULL`; si no trae unidad de compra, conservar el comportamiento actual (ambos campos legados en `NULL`).
- [X] T019 [US3] En el mismo archivo, confirmar en `validar_y_aplicar_fila()` (línea ~229) que, al **actualizar** un insumo existente (código ya registrado), las columnas `Grupo`, `Unidad de compra` y `Factor de conversión (compra)` se ignoran por completo —no se llama a `_resolve_unit` con grupo ni a `_resolve_purchase_unit`— preservando el criterio ya vigente de FR-007/FR-013/FR-021.
- [X] T020 [US3] En `../pos-backend/app/api/v1/inventory/export.py`, modificar `build_inventory_excel()` (línea ~22) para escribir las 3 columnas nuevas por fila: `Grupo` = `unit.group.name` de la unidad base del insumo; `Unidad de compra`/`Factor de conversión (compra)` = la abreviatura y el `factor_to_base` de `SupplierItem.unit_measure_id` de la relación preferida si está en modo `unit_measure_id`, o vacías si no tiene proveedor preferido o si su relación preferida está en modo legado (`presentation`/`conversion_factor`).
- [X] T021 [P] [US3] Actualizar `../pos-backend/app/characterization_tests/test_inventory_export.py`: ajustar `ExportColumnsTests`/`ExportLabelsTests` para las 10 columnas nuevas (orden de encabezados, `Grupo` exportado, `Unidad de compra`/`Factor de conversión (compra)` en blanco sin proveedor preferido en modo `unit_measure_id`); ajustar `ImportUnitLinkingTests` y los tests de `_apply_preferred_supplier`/`_resolve_unit` para los nuevos escenarios de grupo explícito, conflicto de factor, ambigüedad de grupo y unidad de compra sin proveedor (Acceptance Scenarios 1-11 de la Historia 3), citando esta spec.
- [X] T022 [US3] Ejecutar `cd ../pos-backend && python -m unittest app.characterization_tests.test_inventory_export -v` y confirmar que pasa, incluidos los casos nuevos de T021.
- [X] T023 [US3] Extender `../pos-backend/app/scripts/test_inventory_bulk_excel.py` con los 6 escenarios de quickstart.md Historia 3 contra Postgres real: grupo nuevo, grupo existente reutilizado, conflicto de factor, unidad de compra sin proveedor, ambigüedad de grupo en unidad base, y actualización que ignora las columnas nuevas.
- [X] T024 [US3] Ejecutar `cd ../pos-backend && python -m app.scripts.test_inventory_bulk_excel` contra Postgres local y confirmar los 6 escenarios de T023, más verificación manual en Ajustes → Unidades de medida (grupo "Masa" con "g" como base y "KG" como unidad adicional) y en Proveedores (relación con "Molino XYZ" ya con unidad de compra y factor) según quickstart.md.

**Checkpoint**: Las tres historias funcionan de forma independiente y sin regresión — un archivo exportado antes de esta spec (8 u 11 columnas) sigue siendo importable sin cambios.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias — puede iniciar de inmediato.
- **Foundational (Phase 2)**: omitida — no hay prerrequisito bloqueante compartido.
- **Historia 1 (Phase 3)**: puede iniciar tras Setup; sin dependencia de Historia 2 ni 3.
- **Historia 2 (Phase 4)**: puede iniciar tras Setup; T009 (frontend) puede reutilizar `supplierFilterOptions()` de T003 si Historia 1 ya se implementó, pero puede definir su propio `computed()` local si se implementa antes — no es un bloqueo real, solo una oportunidad de reuso.
- **Historia 3 (Phase 5)**: puede iniciar tras Setup; sin dependencia de Historia 1 ni 2. T013-T020 son secuenciales dentro del mismo archivo (`import_.py`/`schemas.py`/`export.py`); T021-T024 (tests) dependen de que T013-T020 estén completos.

### Dentro de cada historia

- Historia 1: T003 antes de T004 (la opción depende del `computed()`); T005 al final.
- Historia 2: T006-T007 (backend) y T008-T009 (frontend) pueden avanzar en paralelo entre sí; T010-T012 (tests/validación) al final, después de T006-T009.
- Historia 3: T013 → T014 → T015 → T016 → T017 → T018 → T019 (mismo archivo, cambios incrementales) → T020 (export, puede ir en paralelo con T016-T019 ya que es un archivo distinto) → T021-T024 (tests, al final).

### Parallel Opportunities

- T010 y T021 (ambos en `test_inventory_export.py`) no son paralelos entre sí si tocan el mismo archivo en la misma historia, pero si Historia 2 y 3 se implementan por desarrolladores distintos, conviene coordinarlos como un solo cambio incremental al archivo en vez de dos ramas separadas sobre el mismo archivo.
- T020 (export.py, Historia 3) puede avanzar en paralelo con T016-T019 (import_.py, Historia 3) — archivos distintos.
- T008-T009 (frontend, Historia 2) pueden avanzar en paralelo con T006-T007 (backend, Historia 2) — archivos y repos distintos, pero T009 no puede probarse end-to-end hasta que T006 esté desplegado.

---

## Parallel Example: Historia 2

```bash
# Backend y frontend de Historia 2 en paralelo (repos distintos):
Task: "Modificar export_items() en pos-backend/app/api/v1/inventory/router.py (T006)"
Task: "Modificar exportItems() en pos-heladeria/src/app/modules/inventory/services/inventory.service.ts (T008)"
```

---

## Implementation Strategy

### MVP First (Historia 1 únicamente)

1. Completar Phase 1: Setup.
2. Completar Phase 3: Historia 1 (T003-T005).
3. **Detener y validar**: probar Historia 1 de forma independiente (quickstart.md).
4. Entregar/demostrar si está lista — es la mejora de menor riesgo y mayor independencia.

### Incremental Delivery

1. Setup → listo para empezar cualquier historia.
2. Historia 1 (P1) → validar → entregar (MVP).
3. Historia 2 (P2) → validar → entregar.
4. Historia 3 (P3) → validar → entregar.
5. Cada historia agrega valor sin romper las anteriores (confirmado por Constitution Check del plan: las tres son aditivas).

---

## Notes

- `[P]` = diferente archivo o tarea independiente dentro de la misma historia, sin bloqueo entre sí.
- `[Story]` mapea cada tarea a US1/US2/US3 para trazabilidad.
- No crear una migración: ninguna historia cambia el esquema (data-model.md).
- No modificar `supplier_items.py` (`_resolve_unit_for_item`) ni el componente `searchable-select` en su modo remoto — se reutilizan tal cual (Principio V, plan.md).
- Commits solo bajo pedido explícito del usuario, en inglés, Conventional Commits, uno por historia es razonable dado que son independientes (Principio XV).
