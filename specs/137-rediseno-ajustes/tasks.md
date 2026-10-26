---

description: "Task list template for feature implementation"
---

# Tasks: Rediseño visual de Ajustes + grupos de unidades de medida

**Input**: Design documents from `specs/137-rediseno-ajustes/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md (todos presentes)

**Tests**: Se incluyen tareas de test porque plan.md y quickstart.md las piden explícitamente
(characterization tests nuevos para migración y reglas "en uso", Principio X/III). No se
piden tests nuevos para el rediseño puramente visual (FR-001 a FR-004) más allá de
confirmar manualmente el quickstart.

**Nota de implementación (desviación de ruta, descubierta en `/speckit-implement`)**:
`pos-backend` no tiene `pytest` ni carpeta `tests/` -- los tests son scripts autoejecutables
bajo `app/scripts/test_*.py` (ver `app/scripts/test_purchase_unit_conversion.py`, spec 134) o
characterization tests `unittest` bajo `app/characterization_tests/`. T007/T008/T015/T016/T022
se implementaron como `app/scripts/test_unit_measure_groups.py` (nuevo, cubre FR-005 a FR-011,
FR-014) y ajustes a `app/scripts/test_purchase_unit_conversion.py` (agrega `UnitMeasureGroup` a
su fixture porque `group_id` ahora es `NOT NULL`; no es un characterization test congelado, no
tiene marcadores `"CONGELA comportamiento actual:"`). Ambos se corrieron en verde contra
Postgres real tras la migración T006. También se encontraron y resolvieron dos heads de Alembic
preexistentes (`c3d9a1f08b42`/`e4e9886ef15b`, sin relación con esta spec) fusionándolos en la
migración 137.

**Nota sobre T013/T030/T032 (verificación manual visual)**: esta sesión no tiene un navegador
disponible para recorrer los Acceptance Scenarios a ojo. Lo que sí se verificó: `ng build` y
`ng serve` compilan limpio con las 4 pestañas rediseñadas; los 5 archivos de test ya existentes
de las pestañas tocadas (`settings-page`, `tenant-info`, `payment-methods-page`,
`option-group-form`, `option-form`) pasan en verde en aislado (32/32); un full-suite run de
`ng test` da 14 fallas en 8 archivos, todos ajenos a esta spec (`manual-order-page`,
`pos-terminal.store`, etc. del módulo de mesas) -- consistente con la flakiness ya documentada
en memoria ("How to run sibling-repo tests"), ninguno de los 5 archivos tocados aparece en la
lista de fallas. Falta: abrir `ng serve` en un navegador real y confirmar a ojo los 3 escenarios
de US1 y los 7 de US2 (T013/T030), y tachar el checklist de `quickstart.md` con eso en mano
(T032) -- quedan sin marcar a propósito para que el usuario (o una sesión con navegador) las
complete.

**Segunda pasada de fidelidad visual (pedida por el usuario tras la primera entrega: "a nivel
de diseño no quedó exacto a design/ajustes.html, debe quedar igual")**: la primera pasada
reconstruyó cada pestaña con un lenguaje visual propio (tarjetas con ícono de encabezado) en
vez de extraer el markup real de `design/ajustes.html` (bundle minificado de ~1.3MB, un solo
archivo autoejecutable `SkeiloPOSDesignSystem_071995` con sintaxis `sc-if`/`{{ }}`). Se
extrajeron por offset los bloques reales de cada pestaña (`Información básica`, `Métodos de
pago`, `Unidades de medida`, `Grupos de opciones`) y del wrapper (panel único con header +
tabs tipo "pill") y se reconstruyó cada componente para igualar esa estructura: fila
etiqueta+control con divisores (`Información básica`), lista con chip de ícono + pastilla de
estado (`Métodos de pago`), maestro-detalle con nav de grupos + tabla de opciones (`Grupos de
opciones`), tarjeta por grupo con tabla UNIDAD/EQUIVALENCIA/USO/ESTADO/ACCIÓN
(`Unidades de medida`). Se agregaron a `icon-catalog.ts` los íconos nuevos que el mockup usa
(`shield-check`, `smartphone`, `arrow-left-right`, etc.) mapeados a Material Icons Outlined.

Tres desviaciones deliberadas del mockup, explicadas para que el usuario las confirme o pida
ajustarlas:
1. El interruptor maestro "Conversión de unidades en compras" (spec 134) se movió de
   "Información básica" a "Unidades de medida", porque así aparece literalmente en
   `design/ajustes.html` (no en Información básica como asumió `ajustes-ui-contract.md` antes
   de leer el mockup real) -- misma llamada a `TenantInfoService.update()`, solo cambió de
   pestaña visualmente.
2. La columna "USO" de la tabla de unidades no se llena de forma proactiva (queda en "—"): el
   mockup la pinta con un campo `u.used` que no existe en el backend real sin una llamada
   nueva por unidad, y la memoria del proyecto prohíbe fetches reactivos fuera de carga/edición
   explícita. El bloqueo real por "en uso" sigue apareciendo igual que antes: al intentar la
   acción, con la lista de `blocking_units` del 409.
3. El botón "Eliminar definitivamente" de un grupo de opciones (con diálogo de confirmación
   "no se puede deshacer") no se implementó como tal: el backend de `option_groups` solo tiene
   soft-delete (`DELETE /option-groups/{id}` desactiva, no hay endpoint de borrado físico) y
   FR-003 prohíbe crear/modificar endpoints de esta pestaña. Se mantiene "Desactivar/Reactivar"
   (la acción real) con el mismo lenguaje visual (ícono + texto) en vez de prometer un borrado
   que no existe.

La tabla "Historial de cambios" agregada que el mockup muestra al final de "Unidades de medida"
tampoco se implementó: no hay una bitácora de cambios de grupo/activación en el backend (solo
`GET /unit-measures/{id}/factor-changes` por unidad, spec 134) y agregarla sería una entidad
nueva fuera del alcance de spec 137. `ng build`/`ng test` (aislado, 10 archivos tocados o
relacionados) siguen en verde tras esta segunda pasada.

**Repos**: `../pos-backend` (API) y `../pos-heladeria` (SPA), hermanos de `pos-specs`.
Antes de tocar código en cualquiera de los dos, crear la rama `feat/137-rediseno-ajustes`
desde la rama actual de cada repo (Principio XIV) — ver T001/T002.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Puede ejecutarse en paralelo (archivos distintos, sin dependencias)
- **[Story]**: US1 (rediseño visual) o US2 (grupos de unidades)

---

## Phase 1: Setup

**Purpose**: Preparar ambas ramas de trabajo antes de tocar código.

- [X] T001 Crear rama `feat/137-rediseno-ajustes` en `../pos-backend` desde su rama actual
- [X] T002 [P] Crear rama `feat/137-rediseno-ajustes` en `../pos-heladeria` desde su rama actual

**Checkpoint**: Ambas ramas listas, ningún commit en `main` de ninguno de los dos repos.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Modelo de datos, migración y función de "en uso" que bloquean toda la Fase
US2 (grupos) y de las que depende la Fase US1 solo indirectamente (ninguna pestaña
rediseñada toca estos archivos, pero la migración debe estar en verde antes del rediseño
visual de "Unidades de medida" porque esa pestaña sí cambia funcionalmente).

**⚠️ CRITICAL**: Ningún endpoint ni componente de grupos de unidades puede implementarse
antes de completar esta fase.

- [X] T003 Crear modelo `UnitMeasureGroup` en `../pos-backend/app/models/unit_measure_group.py`
      (`UUIDPrimaryKeyMixin`, `TimestampMixin`, `name: String(255)` NOT NULL UNIQUE por
      tenant, relación 1:N hacia `UnitMeasure`) según `data-model.md`
- [X] T004 Ajustar modelo `UnitMeasure` en `../pos-backend/app/models/unit_measure.py`:
      agregar `group_id` (FK a `unit_measure_groups.id`) e `is_base: bool` (default False);
      mantener `dimension` sin cambio de tipo (depende de T003)
- [X] T005 Implementar función `unit_measure_in_use(db, unit_measure_id) -> bool` en
      `../pos-backend/app/api/v1/unit_measures/service.py` (NUEVO archivo si no existe;
      `EXISTS` contra `InventoryItem.unit_measure_id` y `Purchase.unit_measure_id`, sin
      filtrar por activo/inactivo, patrón `research.md` D3)
- [X] T006 Crear migración Alembic
      `../pos-backend/alembic/versions/<rev>_137_unit_measure_groups.py` (depende de
      T003, T004): `upgrade()` crea tabla `unit_measure_groups` + columnas `group_id`
      (nullable)/`is_base` en `unit_measures`; backfill un grupo por `dimension` distinto;
      marca base = unidad con `factor_to_base=1` más antigua (`created_at` mínimo) si hay
      exactamente una, o la más antigua de todas si hay cero o más de una; vuelve
      `group_id` NOT NULL; agrega índice único parcial `UNIQUE (group_id) WHERE
      is_base = true`; `downgrade()` recompone `dimension` desde `UnitMeasureGroup.name` y
      elimina columnas/tabla nuevas (`data-model.md` plan de migración, `research.md` D4)
- [X] T007 [P] Test de migración en
      `../pos-backend/tests/unit/test_unit_measure_groups_migration.py`: snapshot
      antes/después sobre datos representativos del Edge Case (dos unidades con
      `factor_to_base=1` en el mismo `dimension`); valida SC-003 (exactamente 1 base por
      grupo, ningún `factor_to_base`/`active`/nombre/abreviatura alterado, ninguna fila de
      `InventoryItem`/`Purchase` cambia de `unit_measure_id`) (depende de T006)
- [X] T008 Correr `pytest tests/integration/test_units_conversion.py -v` en
      `../pos-backend` tras aplicar T006 y confirmar que sigue en verde sin
      modificaciones (FR-010, no se toca el archivo de test) (depende de T006)

**Checkpoint**: Migración aplicada y verificada en una base de datos de prueba; función
"en uso" disponible para ambas historias de usuario del backend.

---

## Phase 3: User Story 1 - Ajustes con el nuevo diseño visual (Priority: P1) 🎯 MVP

**Goal**: Las pestañas "Información básica", "Métodos de pago" y "Grupos de opciones"
usan el nuevo diseño visual (`design/ajustes.html`) sin tocar endpoints ni lógica.

**Independent Test**: Abrir cada pestaña rediseñada y confirmar que los mismos
campos/acciones de hoy siguen funcionando con la apariencia nueva (ver
`contracts/ajustes-ui-contract.md`).

### Implementation for User Story 1

- [X] T009 [P] [US1] Rediseñar plantilla/estilos de
      `../pos-heladeria/src/app/modules/settings/pages/settings-page.component.ts`
      (navegación de pestañas, layout general) siguiendo `design/ajustes.html` /
      `design/Ajustes-standalone-src.dc.html`, sin tocar `visibleTabs()` ni la lógica de
      visibilidad por plan (FR-004)
- [X] T010 [P] [US1] Rediseñar plantilla/estilos de
      `../pos-heladeria/src/app/modules/settings/pages/tenant-info.component.ts`
      conservando exactamente los mismos campos y acciones (logo, mensaje de recibo,
      ancho de rollo, conversión de unidades en compras) (FR-001, Acceptance Scenario 1)
- [X] T011 [P] [US1] Rediseñar plantilla/estilos de
      `../pos-heladeria/src/app/modules/sales/pages/payment-methods-page.component.ts`
      conservando catálogo del Super Admin, activación, campos dinámicos por método,
      activar/desactivar (FR-002, Acceptance Scenario 2)
- [X] T012 [P] [US1] Rediseñar plantilla/estilos de
      `../pos-heladeria/src/app/modules/option-groups/pages/option-groups-page.component.ts`
      y sus componentes (`option-group-form.component.ts`, `option-form.component.ts`)
      conservando modo conteo/cantidad, tipo de precio, vínculo a insumo, eliminación
      definitiva con confirmación (FR-003, Acceptance Scenario 3)
- [ ] T013 [US1] Verificar manualmente con `ng serve` en `../pos-heladeria` los 3
      escenarios de aceptación de User Story 1 y la sección 3 del `quickstart.md`
      (depende de T009-T012)
- [ ] T014 [US1] Correr `ng test` en `../pos-heladeria` y comparar archivo por archivo
      contra la baseline conocida (memoria "How to run sibling-repo tests": la baseline es
      flaky, no comparar conteo total) — confirmar que los specs de
      `settings-page.component.spec.ts`, `tenant-info.component.spec.ts`,
      `option-group-form.component.spec.ts` y `option-form.component.spec.ts` no
      introducen fallas nuevas (depende de T009-T012)

**Checkpoint**: Las tres pestañas rediseñadas funcionan igual que antes, con el nuevo
diseño visual. Entregable independiente (MVP).

---

## Phase 4: User Story 2 - Agrupar unidades de medida con una unidad base (Priority: P1)

**Goal**: Backend expone grupos de unidades con unidad base protegida y reasignable; el
frontend reemplaza la pestaña "Unidades de medida" por la vista agrupada del diseño.

**Independent Test**: Crear un grupo nuevo con su unidad base, agregar una segunda unidad
con su factor, confirmar que la base no se puede editar/desactivar, y que las
conversiones de compras (spec 134) siguen funcionando igual.

**Depende de**: Phase 2 (Foundational) completa.

### Tests for User Story 2 ⚠️

> Escribir estos tests primero y confirmar que fallan antes de implementar.

- [X] T015 [P] [US2] Test unitario de reglas "en uso" en
      `../pos-backend/tests/unit/test_unit_measures_in_use.py`: bloqueo de
      editar-factor/desactivar/eliminar unidad base (FR-008), bloqueo de renombrar unidad
      en uso (FR-014), bloqueo de reasignar base con unidad en uso (FR-009), bloqueo de
      eliminar grupo con unidad en uso (FR-011) — todos esperando 409 con
      `blocking_units`
- [X] T016 [P] [US2] Test unitario de endpoints de grupo en
      `../pos-backend/tests/unit/test_unit_measure_groups.py`: crear grupo con unidad
      base (FR-005), agregar unidad adicional (FR-006), exactamente una base por grupo
      (FR-007), reasignar base sin unidades en uso recalculando `factor_to_base` de todo
      el grupo (FR-009/D6), eliminar grupo sin unidades en uso (FR-011), nombre de grupo
      duplicado → 409, nombre/abreviatura de unidad duplicado en el tenant → 409

### Implementation for User Story 2 (Backend)

- [X] T017 [P] [US2] Crear schemas Pydantic en
      `../pos-backend/app/api/v1/unit_measure_groups/schemas.py` (NUEVO):
      `UnitMeasureGroupCreate`, `UnitMeasureGroupUnitCreate`, `UnitMeasureGroupRename`,
      `UnitMeasureGroupBaseReassign`, `UnitMeasureGroupResponse` (con `units` anidadas),
      forma de error `blocking_units` según `contracts/unit-measure-groups-api.md`
- [X] T018 [US2] Crear router en
      `../pos-backend/app/api/v1/unit_measure_groups/router.py` (NUEVO, depende de T017,
      T003-T005): `GET /unit-measure-groups` (con filtro `active`), `POST
      /unit-measure-groups` (crea grupo + unidad base, `factor_to_base=1`,
      `dimension=name`), `POST /unit-measure-groups/{id}/units` (agrega unidad,
      `is_base=false`), `PATCH /unit-measure-groups/{id}` (renombra, sincroniza
      `dimension` de todas sus unidades), `PATCH /unit-measure-groups/{id}/base-unit`
      (reasigna base usando `unit_measure_in_use` sobre todas las unidades del grupo +
      recálculo de `factor_to_base` según D6), `DELETE /unit-measure-groups/{id}`
      (hard-delete grupo + unidades solo si ninguna está en uso); mismo
      `require_module_access("inventario")` + `get_current_user` que `/unit-measures`
- [X] T019 [US2] Registrar el router nuevo de `unit_measure_groups` en el router principal
      de la API (`../pos-backend/app/api/v1/__init__.py` o equivalente donde se incluyen
      los demás routers) (depende de T018)
- [X] T020 [US2] Ajustar
      `../pos-backend/app/api/v1/unit_measures/schemas.py`: agregar `group_id: UUID`,
      `is_base: bool` a `UnitMeasureResponse`; quitar `dimension` del body de entrada de
      creación/edición; `POST` ahora exige `group_id` en el body (depende de T004)
- [X] T021 [US2] Ajustar
      `../pos-backend/app/api/v1/unit_measures/router.py`: `POST /unit-measures` exige
      `group_id` (404 si no existe, crea con `is_base=false`); `PATCH /unit-measures/{id}`
      bloquea con 409 si `is_base=true` y el body trae `factor_to_base`/`active` (FR-008),
      y bloquea con 409 si trae `name`/`abbreviation` distintos y la unidad está en uso
      (FR-014, usando `unit_measure_in_use` de T005) — evaluando primero el bloqueo de rol
      ADMIN existente (spec 134) y después estas reglas nuevas; `DELETE
      /unit-measures/{id}` bloquea con 409 si `is_base=true` (FR-008) (depende de T005,
      T020)
- [X] T022 [US2] Correr T015 y T016 hasta que pasen en verde; volver a correr
      `pytest tests/integration/test_units_conversion.py -v` para confirmar que FR-010
      sigue sin regresión tras T021 (depende de T015, T016, T017-T021)

### Implementation for User Story 2 (Frontend)

- [X] T023 [P] [US2] Crear interfaz
      `../pos-heladeria/src/app/core/interfaces/unit-measure-group.interface.ts` (NUEVO):
      `UnitMeasureGroup`, `UnitMeasureGroupResponse`, forma de error con
      `blocking_units`, según `contracts/unit-measure-groups-api.md`
- [X] T024 [P] [US2] Ajustar
      `../pos-heladeria/src/app/core/interfaces/unit-measure.interface.ts`: agregar
      `group_id`, `is_base` a la interfaz de respuesta
- [X] T025 [US2] Crear
      `../pos-heladeria/src/app/core/services/unit-measure-group.service.ts` (NUEVO,
      depende de T023): métodos para los 5 endpoints de
      `contracts/unit-measure-groups-api.md` (`list`, `create`, `addUnit`, `rename`,
      `reassignBase`, `delete`)
- [X] T026 [US2] Ajustar
      `../pos-heladeria/src/app/core/services/unit-measure.service.ts`: adaptar llamadas
      de creación/edición al nuevo contrato (`group_id` en vez de `dimension`), exponer
      manejo de 409 con `blocking_units` (depende de T024)
- [X] T027 [US2] Rediseñar
      `../pos-heladeria/src/app/modules/unit-measures/pages/unit-measures-page.component.ts`
      para listar grupos con sus unidades anidadas (acordeón: base primero, marcada
      visualmente), usando `UnitMeasureGroupService` (T025); acciones "reasignar base"
      (solo si el grupo tiene >1 unidad) y "eliminar grupo" (solo si no hay unidades en
      uso) que muestran `blocking_units` si el backend igual responde 409
      (`contracts/ajustes-ui-contract.md`) (depende de T025)
- [X] T028 [P] [US2] Crear
      `../pos-heladeria/src/app/modules/unit-measures/components/unit-measure-group-form.component.ts`
      (NUEVO): formulario de crear grupo (nombre + unidad base con nombre/abreviatura)
      (depende de T025)
- [X] T029 [US2] Ajustar
      `../pos-heladeria/src/app/modules/unit-measures/components/unit-measure-form.component.ts`:
      selección de grupo existente al agregar unidad, deshabilita
      editar-factor/desactivar/eliminar cuando `is_base=true` (con tooltip explicando el
      bloqueo), ícono "eliminar" en unidad no-base sigue mapeando a desactivar
      (soft-delete, FR-013) (depende de T026)
- [ ] T030 [US2] Verificar manualmente con `ng serve` los Acceptance Scenarios 1-7 de User
      Story 2 y la sección 2/3 del `quickstart.md` (incluye los 6 escenarios curl/docs
      contra el backend) (depende de T022, T027-T029)
- [ ] T031 [US2] Correr `ng test` en `../pos-heladeria` y comparar contra baseline (memoria
      "How to run sibling-repo tests") para los specs tocados en T027-T029 (depende de
      T027-T029)

**Checkpoint**: Grupos de unidades funcionando end-to-end (backend + frontend),
migración verificada, conversión de compras (spec 134) sin regresión.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Cierre y verificación final cruzando ambas historias.

- [ ] T032 Ejecutar el checklist completo de "Criterios de salida" de
      `quickstart.md` (migración, pytest backend completo, 6 escenarios manuales,
      4 pestañas con nuevo diseño, `ng test` sin fallas nuevas) (depende de todas las
      fases anteriores)
- [X] T033 Revisar que `registro-de-anomalias.md` no requiere entrada nueva (plan.md ya
      concluyó que no aplica, Principio II) — confirmar que ningún hallazgo de T030/T032
      cambia esa conclusión

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias — ramas de ambos repos.
- **Foundational (Phase 2)**: depende de Setup. Bloquea toda la Phase 4 (US2). Debe
  completarse antes de T008 (verificación de no-regresión de spec 134) y antes de
  cualquier endpoint/componente de grupos.
- **User Story 1 (Phase 3)**: depende solo de Setup (no toca modelo de datos ni backend de
  unidades). Puede ejecutarse en paralelo con Phase 2/4 si hay dos desarrolladores,
  excepto T013 (verificación visual de "Unidades de medida" no aplica a US1 — esa pestaña
  se cubre en US2).
- **User Story 2 (Phase 4)**: depende de Foundational (Phase 2). Backend (T017-T022)
  antes que Frontend (T023-T031) dentro de esta fase.
- **Polish (Phase 5)**: depende de Phase 3 y Phase 4 completas.

### Dentro de cada historia

- Tests (T015, T016) antes de implementación de endpoints (T017-T021).
- Modelos/schemas antes de routers/servicios.
- Backend antes de frontend en US2 (el frontend consume los contratos nuevos).
- Verificación manual y `ng test`/`pytest` al final de cada fase.

### Parallel Opportunities

- T001/T002 en paralelo (repos distintos).
- T007 puede escribirse en paralelo a T008 una vez T006 existe.
- T009-T012 en paralelo (archivos de componentes distintos, Phase 3).
- T015/T016 en paralelo (archivos de test distintos).
- T017, T023, T024 en paralelo (schemas/interfaces, archivos distintos).
- T028 en paralelo con T026/T027 (componente nuevo vs. ajustes existentes).

---

## Parallel Example: User Story 1

```bash
Task: "Rediseñar settings-page.component.ts (layout/pestañas)"
Task: "Rediseñar tenant-info.component.ts (Información básica)"
Task: "Rediseñar payment-methods-page.component.ts (Métodos de pago)"
Task: "Rediseñar option-groups-page.component.ts + componentes (Grupos de opciones)"
```

## Parallel Example: User Story 2 (inicio)

```bash
Task: "Test unitario de reglas en uso (test_unit_measures_in_use.py)"
Task: "Test unitario de endpoints de grupo (test_unit_measure_groups.py)"
Task: "Schemas de unit_measure_groups (schemas.py)"
Task: "Interfaz unit-measure-group.interface.ts"
```

---

## Implementation Strategy

### MVP First

1. Setup (T001-T002) + Foundational (T003-T008).
2. User Story 1 completa (T009-T014) → demo del rediseño visual sin riesgo de datos.
3. **STOP y VALIDAR**: confirmar con el usuario que el rediseño visual es aceptado antes
   de seguir con grupos de unidades (aunque ambas son P1, US1 es la base visual y no
   depende de la migración).

### Incremental Delivery

1. Setup + Foundational → migración de datos verificada.
2. User Story 1 → demo (3 pestañas rediseñadas).
3. User Story 2 → demo (grupos de unidades funcionando end-to-end).
4. Polish → checklist final de `quickstart.md`.
