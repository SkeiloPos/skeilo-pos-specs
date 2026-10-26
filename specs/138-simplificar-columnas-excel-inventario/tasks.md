---

description: "Task list template for feature implementation"
---

> **Notas post-implementación (2026-10-26)**: tras completar las tareas abajo, el usuario hizo dos
> correcciones de alcance:
>
> 1. FR-001/FR-002/FR-004 -- la columna `Proveedor preferido` (solo el nombre) debía conservarse
>    en export/import, no eliminarse junto con presentación/factor/último costo. Se ajustó
>    `schemas.py` (header), `export.py`/`router.py` (vuelve a exportar el nombre), `import_.py`
>    (nuevo `_apply_preferred_supplier`), y los tests/fixtures en `test_inventory_export.py` y
>    `test_inventory_bulk_excel.py`.
> 2. El proveedor nombrado en esa columna SÍ debe crearse si no existe (igual que ya hacía la
>    spec 109 para proveedores) -- no solo vincular uno ya existente. Como la plantilla ya no
>    trae presentación/factor, la relación nueva creada por esta vía queda con esos dos campos en
>    `NULL`: requirió una migración (`c5815ab62693`) y el cambio de modelo correspondiente en
>    `app/models/supplier_item.py` (`presentation`/`conversion_factor` ahora nullable), más un
>    guard en `service.py::_resolve_purchase_line` para rechazar con 422 (no crashear) el uso de
>    una relación incompleta en una compra. Aceptado explícitamente por el solicitante como
>    estado intermedio a refinar en una spec futura.
>
> `spec.md`/`data-model.md`/`contracts/plantilla-excel-inventario.md`/`quickstart.md` ya reflejan
> ambas correcciones. Todas las tareas siguen marcadas `[X]` porque el trabajo original (retiro de
> presentación/factor/último costo, vinculación de unidad) sigue vigente sin cambios.

# Tasks: Simplificar columnas de proveedor en Excel de inventario y vincular unidad a unidades de medida reales

**Input**: Design documents from `/specs/138-simplificar-columnas-excel-inventario/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/plantilla-excel-inventario.md, quickstart.md

**Tests**: se incluyen tareas de test porque el plan señala explícitamente (Principio III) que
`test_inventory_export.py` tiene suites que hoy aseveran la presencia de las columnas de
proveedor retiradas — deben actualizarse de forma explícita, no en silencio. Además, el gap de
`group_id` NOT NULL (Historia 2) solo se expone contra Postgres real, por lo que se incluye una
verificación explícita contra el script de importación masiva.

**Organización**: cambio exclusivo de `../pos-backend` (confirmado en research.md §6 que
`pos-heladeria` no requiere cambios). No hay migración de esquema, así que la fase Foundational
se limita a preparar los fixtures de test compartidos que varias historias reutilizan, en vez de
bloquear por cambios de modelo/BD como en otras specs.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: se puede ejecutar en paralelo (archivos distintos, sin dependencias)
- **[Story]**: a qué historia de usuario del spec pertenece (US1, US2, US3)
- Rutas de archivo relativas a `../pos-backend`

## Phase 1: Setup

**Purpose**: preparar la rama de trabajo en el único repositorio afectado.

- [X] T001 Crear rama `feat/138-inventory-excel-unit-link` en `pos-backend` desde la rama actual (Principio XIV de la constitución)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: preparar los fixtures de test compartidos que las tres historias reutilizan, para no
duplicar factories locales como hace hoy `test_inventory_export.py` (research.md §5).

**⚠️ CRITICAL**: las tareas de test de las fases 3-5 asumen que `fixtures.py` ya expone
`make_unit`, `make_inventory_item`, `make_supplier`, `make_supplier_item` listas para usar; si
`test_inventory_export.py` todavía define factories locales equivalentes, esta tarea debe
completarse primero para evitar duplicación.

- [X] T002 Revisar `app/characterization_tests/fixtures.py` y `test_inventory_export.py` en `../pos-backend`; si `test_inventory_export.py` define factories locales duplicadas (`make_unit`/`make_inventory_item`/`make_supplier`/`make_supplier_item`), migrarlas a usar las de `fixtures.py` sin cambiar ninguna aserción existente todavía

**Checkpoint**: los tests de las fases siguientes pueden apoyarse en fixtures compartidas sin
duplicar factories.

---

## Phase 3: User Story 1 - Exportar e importar sin las columnas de datos del proveedor preferido (Priority: P1) 🎯 MVP

**Goal**: el archivo de Excel de inventario deja de incluir las columnas de presentación, factor
de conversión, último costo y proveedor preferido; un archivo legado con esas columnas se sigue
aceptando pero su contenido se ignora por completo.

**Independent Test**: exportar el inventario y confirmar que el archivo no trae esas columnas;
importar un archivo legado de 11 columnas con datos de proveedor preferido y confirmar que el
`SupplierItem` del insumo no cambia.

### Tests for User Story 1 ⚠️

> Actualizar/agregar estos tests PRIMERO y confirmar que fallan contra el código aún no migrado.

- [X] T003 [US1] Actualizar la suite `ExportColumnsTests` en `../pos-backend/app/characterization_tests/test_inventory_export.py` para esperar exactamente 7 encabezados (`Código, Nombre, Tipo, Unidad, Stock, Mínimo, Costo`), sin las 4 columnas de proveedor preferido, citando esta spec en el cambio (Principio III)
- [X] T004 [US1] [P] Agregar un test en `../pos-backend/app/characterization_tests/test_inventory_export.py` que importe un archivo con el encabezado legado de 11 columnas (incluyendo valores no vacíos de Presentación/Factor de conversión/Último costo para una fila que actualiza un insumo con proveedor preferido ya asignado) y confirme que el job termina sin error de estructura y que el `SupplierItem` preferido no cambia

### Implementation for User Story 1

- [X] T005 [US1] Quitar `Proveedor preferido`, `Presentación`, `Factor de conversión` y `Último costo` de `INVENTORY_TEMPLATE_HEADERS` en `../pos-backend/app/api/v1/inventory/schemas.py` (líneas ~19-31)
- [X] T006 [US1] [P] Dejar de escribir esas 4 celdas en `build_inventory_excel` en `../pos-backend/app/api/v1/inventory/export.py`, y quitar el uso de `preferred_relations_by_item` si queda sin otro uso en ese archivo
- [X] T007 [US1] Actualizar `validar_estructura()` en `../pos-backend/app/api/v1/inventory/import_.py` (líneas ~36-54) para aceptar tanto el encabezado nuevo (7 columnas) como el legado (11 columnas, con las 4 finales en su posición original) sin reportar error de estructura
- [X] T008 [US1] Quitar la llamada a `_apply_preferred_supplier` y toda lectura de `Presentación`/`Factor de conversión`/`Último costo`/`Proveedor preferido` del flujo de importación en `../pos-backend/app/api/v1/inventory/import_.py` (líneas ~146-197), de modo que esas columnas, si están presentes, se detecten solo para validar estructura y nunca se procesen
- [X] T009 [US1] Eliminar `_apply_preferred_supplier` y `_resolve_supplier` de `../pos-backend/app/api/v1/inventory/supplier_items.py` si, tras T008, no les queda ningún otro llamador en el repo (código muerto, Principio V); si tienen otro llamador, documentar por qué se conservan
- [X] T010 [US1] Ejecutar `python -m unittest app.characterization_tests.test_inventory_export -v` en `../pos-backend` y confirmar que los tests de T003-T004 ahora pasan contra la implementación

**Checkpoint**: exportación e importación ya no tocan datos de proveedor preferido; un archivo
legado sigue siendo aceptado. User Story 1 queda verificable de forma independiente.

---

## Phase 4: User Story 2 - La unidad del producto se vincula a una unidad de medida real al crear un insumo nuevo (Priority: P1)

**Goal**: al crear un insumo nuevo por importación, la columna Unidad se vincula a una
`UnitMeasure` existente (case-insensitive por `abbreviation`) o crea una nueva completa
(`group_id`, `is_base=True`, `factor_to_base=1`), cerrando el gap de `group_id` NOT NULL que hoy
rompe esta ruta contra Postgres real.

**Independent Test**: importar insumos nuevos con unidades que ya existen (distinta capitalización)
y unidades que no existen todavía, y confirmar que se vinculan/crean correctamente sin duplicar ni
lanzar `IntegrityError`, visibles luego en Ajustes.

### Tests for User Story 2 ⚠️

> Actualizar/agregar estos tests PRIMERO; el de T012 debe fallar contra el `_resolve_unit()` actual
> (gap de `group_id` sin asignar) antes de implementar el fix.

- [X] T011 [US2] [P] Agregar test de characterization en `../pos-backend/app/characterization_tests/test_inventory_export.py` (reutilizando `fixtures.make_unit`) para una fila nueva con columna Unidad en minúsculas que coincide con una `UnitMeasure.abbreviation` existente en mayúsculas; confirmar que se usa la unidad existente sin crear una duplicada
- [X] T012 [US2] Agregar test de characterization para una fila nueva con columna Unidad que no coincide con ninguna `UnitMeasure` existente; confirmar que se crea un `UnitMeasureGroup` nuevo y una `UnitMeasure` nueva con `group_id` asignado, `is_base=True`, `factor_to_base=1` — este test debe fallar contra el código actual (gap de `group_id`, research.md §3)
- [X] T013 [US2] [P] Agregar test de characterization para FR-008: dos `UnitMeasure` activas que coinciden sin distinguir mayúsculas/minúsculas (p. ej. `"Gal"` y `"GAL"`) y una fila nueva con columna Unidad `"gal"`; confirmar que la fila se reporta como fallida por ambigüedad en vez de elegir una arbitrariamente
- [X] T014 [US2] [P] Agregar test de characterization para FR-009: fila nueva con columna Unidad vacía; confirmar que se reporta como fallida por campo obligatorio faltante, sin intentar crear ninguna `UnitMeasure`

### Implementation for User Story 2

- [X] T015 [US2] Corregir `_resolve_unit()` en `../pos-backend/app/api/v1/inventory/import_.py` (líneas ~69-102) para que, al autocrear una unidad, cree primero un `UnitMeasureGroup(name=normalizado)` con `flush()`, y luego la `UnitMeasure(name=normalizado, abbreviation=normalizado, group_id=group.id, is_base=True, factor_to_base=1, dimension=group.name, active=True)`, replicando el patrón de `create_unit_measure_group()` en `../pos-backend/app/api/v1/unit_measure_groups/router.py` (líneas ~75-98)
- [X] T016 [US2] Agregar en `_resolve_unit()` la comprobación de ambigüedad: si la consulta case-insensitive contra `UnitMeasure.abbreviation` devuelve más de una fila activa, reportar la fila como fallida (FR-008), con el mismo criterio que `_resolve_supplier` ya aplica para proveedores
- [X] T017 [US2] Confirmar que una columna Unidad vacía en una fila nueva se reporta como campo obligatorio faltante antes de llegar a `_resolve_unit()` (FR-009); ajustar el orden de validación en `import_.py` si hoy no es así
- [X] T018 [US2] Ejecutar `python -m app.scripts.test_inventory_bulk_excel` en `../pos-backend` contra Postgres local y confirmar que la creación automática de una unidad nueva ya no lanza `IntegrityError` por `group_id` NOT NULL (cierra el gap de research.md §3)
- [X] T019 [US2] Ejecutar `python -m unittest app.characterization_tests.test_inventory_export -v` en `../pos-backend` y confirmar que los tests de T011-T014 ahora pasan contra la implementación

**Checkpoint**: crear insumos nuevos por Excel vincula o crea unidades de medida reales sin
duplicar ni romper contra Postgres. User Story 2 queda verificable de forma independiente.

---

## Phase 5: User Story 3 - La unidad de una fila de actualización no cambia la unidad del insumo existente (Priority: P2)

**Goal**: al actualizar un insumo existente por importación, la columna Unidad se ignora por
completo: no cambia `unit_measure_id` ni crea ninguna `UnitMeasure`/`UnitMeasureGroup` nueva, sin
importar su contenido.

**Independent Test**: actualizar, vía importación, un insumo existente con un valor de unidad
distinto al actual (o vacío, o inexistente) y confirmar que su unidad no cambia, que no se crea
ninguna unidad nueva, y que el resto de campos de la fila sí se actualiza.

### Tests for User Story 3 ⚠️

> Actualizar/agregar este test PRIMERO y confirmar que falla si `resolve_or_create_by_code` hoy
> sobrescribe `unit_measure_id` también en la rama de actualización (research.md §4).

- [X] T020 [US3] Agregar test de characterization en `../pos-backend/app/characterization_tests/test_inventory_export.py` con 3 variantes de una fila que actualiza un insumo existente (columna Unidad distinta a la actual, vacía, y con texto que no existe como unidad): en los 3 casos, confirmar que `unit_measure_id` del insumo no cambia, que el resto de campos de la fila sí se actualiza, y que no se crea ninguna `UnitMeasure`/`UnitMeasureGroup` nueva

### Implementation for User Story 3

- [X] T021 [US3] En `../pos-backend/app/api/v1/inventory/import_.py`, al detectar que una fila actualiza un insumo existente (código coincide), evitar llamar a `_resolve_unit()` para esa fila y no pasar ningún `unit_measure_id` resuelto a `resolve_or_create_by_code`
- [X] T022 [US3] Confirmar en `resolve_or_create_by_code()` (`../pos-backend/app/api/v1/inventory/service.py`, líneas ~127-164) que la rama de actualización no sobrescribe `unit_measure_id` cuando ese campo no se pasa en `**fields`; ajustar la función si hoy lo hace
- [X] T023 [US3] Ejecutar `python -m unittest app.characterization_tests.test_inventory_export -v` en `../pos-backend` y confirmar que el test de T020 ahora pasa contra la implementación

**Checkpoint**: actualizar insumos existentes por Excel nunca altera su unidad ni crea unidades
como efecto secundario. User Story 3 queda verificable de forma independiente.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: verificación final de regresión y del flujo completo documentado en quickstart.md.

- [X] T024 [P] Ejecutar `python -m unittest discover -s app/characterization_tests -p 'test_*.py' -v` completo en `../pos-backend` y confirmar que ningún test existente pasa a fallar salvo los actualizados explícitamente en T003-T004/T020
- [X] T025 [P] Ejecutar `grep -rn "_apply_preferred_supplier\|_resolve_supplier" app/ --include="*.py"` en `../pos-backend` y confirmar que no quedan llamadores fuera de donde se decidió conservarlos en T009
- [X] T026 Ejecutar el flujo completo de `quickstart.md` (7 escenarios) contra Postgres local y confirmar todos los resultados esperados, incluyendo el Escenario 4 (gap de `group_id`) y el Escenario 7 (ambigüedad FR-008)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias — puede iniciar de inmediato.
- **Foundational (Phase 2)**: depende de Setup. No bloquea el código de producción de ninguna
  historia (no hay cambio de esquema), pero T002 debe completarse antes de T004/T011/T013/T014/
  T020 si estas van a reutilizar `fixtures.py` sin duplicar factories.
- **User Stories (Phase 3-5)**: todas dependen de Foundational. US1 y US2 son P1 y pueden
  trabajarse en paralelo; US3 depende conceptualmente de que US2 ya defina cómo se resuelve la
  unidad al crear (para distinguirlo del caso de actualización), pero no bloquea técnicamente —
  ambas tocan funciones distintas de `import_.py`.
- **Polish (Phase 6)**: depende de que las tres historias de usuario estén completas.

### User Story Dependencies

- **US1 (P1)**: puede iniciar apenas termina Foundational. Sin dependencia de US2/US3.
- **US2 (P1)**: puede iniciar apenas termina Foundational, en paralelo con US1. Sin dependencia de
  US1/US3, salvo que ambas tocan `import_.py` — coordinar para no pisar las mismas líneas si se
  trabajan en paralelo.
- **US3 (P2)**: puede iniciar apenas termina Foundational. Comparte `import_.py` y
  `service.py` con US2; T021 (US3) decide no llamar a `_resolve_unit()` en filas de actualización,
  lo cual es independiente de cómo T015 (US2) implemente `_resolve_unit()` para filas de creación.

### Parallel Opportunities

- T004, T011, T013, T014 (tests de distintas historias, mismo archivo pero bloques de test
  distintos) pueden escribirse en la misma sesión sin bloquearse entre sí.
- T006 (export.py) puede hacerse en paralelo con T005 (schemas.py) dentro de US1.
- US1 y US2 pueden trabajarse en paralelo por personas distintas una vez completada Foundational,
  coordinando los puntos compartidos de `import_.py` señalados arriba.
- T024 y T025 (Polish) son independientes entre sí y pueden correr en paralelo.

---

## Implementation Strategy

### MVP First (User Story 1 + User Story 2)

Ambas son P1: el MVP real de esta spec es completar Foundational + US1 + US2 — retirar las
columnas de proveedor del contrato y cerrar el gap de `group_id` que hoy rompe la creación
automática de unidades contra Postgres real. US3 (proteger la unidad de un insumo existente al
actualizar) es P2: corrige un riesgo real pero no bloquea el valor principal pedido por el
administrador.

### Incremental Delivery

1. Setup + Foundational → fixtures de test listas para reutilizar.
2. US1 → archivo de Excel sin columnas de proveedor, compatible con archivos legados. Desplegable
   de forma independiente (no depende de US2/US3).
3. US2 → creación de insumos nuevos por Excel vincula/crea unidades de medida reales sin romper
   contra Postgres. Desplegable de forma independiente.
4. US3 → actualizar insumos existentes por Excel deja de poder alterar su unidad por accidente.
5. Polish → regresión completa + quickstart.md.

A diferencia de specs que eliminan una columna de modelo, aquí no hay una ventana de código roto
entre fases: cada historia es un cambio de comportamiento aislado dentro de `import_.py`/
`export.py`/`schemas.py`/`service.py`, por lo que US1, US2 y US3 pueden desplegarse de forma
incremental e independiente, en cualquier orden, tras Foundational.
