# Implementation Plan: Rediseño visual de Ajustes + grupos de unidades de medida

**Branch**: `137-rediseno-ajustes` | **Date**: 2026-10-26 | **Spec**: `specs/137-rediseno-ajustes/spec.md`

**Input**: Feature specification from `/specs/137-rediseno-ajustes/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Rediseñar visualmente las pestañas "Información básica", "Métodos de pago" y "Grupos de
opciones" de Ajustes sin tocar endpoints ni reglas de negocio (solo presentación), y
formalizar una nueva entidad `UnitMeasureGroup` en `pos-backend` que reemplaza el texto
libre `UnitMeasure.dimension` por una relación real con una unidad base explícita por
grupo, preservando exactamente la fórmula de conversión de spec 134
(`app/core/units.py::convert()`). Se migran automáticamente los `dimension` existentes a
grupos reales (un grupo por valor distinto de `dimension`, base = `factor_to_base == 1` más
antigua, o la más antigua si hay ambigüedad). El frontend (`pos-heladeria`, Angular 21)
gana la pestaña "Unidades de medida" agrupada con gestión de grupos y reutiliza el nuevo
diseño (`design/ajustes.html` / `design/Ajustes-standalone-src.dc.html`) para las tres
pestañas existentes.

## Technical Context

**Language/Version**: Python 3.14 (`pos-backend`, FastAPI) + TypeScript 5.9 / Angular 21 standalone components (`pos-heladeria`)

**Primary Dependencies**: FastAPI 0.136, SQLAlchemy 2.0 (ORM declarativo con `Mapped`/`mapped_column`), Alembic 1.18, Pydantic v2 (backend); Angular 21 (`@angular/build:unit-test`), RxJS, signals (frontend). Sin dependencias nuevas (Principio IX): la nueva entidad y endpoints reutilizan el mismo stack ya usado por `unit_measures`/`option_groups`.

**Storage**: PostgreSQL 16, schema-per-tenant (todas las tablas nuevas y modificadas viven en el schema `tenant`, igual que `unit_measures` hoy).

**Testing**: `pytest` (backend, venv de `pos-backend` — ver memoria "How to run sibling-repo tests"); `ng test` / `@angular/build:unit-test` (frontend). Se agregan characterization tests nuevos para las reglas de "unidad/grupo en uso" y para la migración de `dimension` → grupos; no se tocan characterization tests existentes de spec 134 porque `convert()` no cambia de comportamiento.

**Target Platform**: Linux server (API) + SPA en navegador (frontend), igual que el resto del sistema.

**Project Type**: Web application — dos repos (backend + frontend), consistente con "Option 2: Web application" de la plantilla.

**Performance Goals**: Sin metas específicas nuevas — pantallas administrativas de bajo volumen (decenas de unidades/grupos por tenant), igual perfil que "Grupos de opciones" hoy.

**Constraints**:
- El rediseño visual de Información básica / Métodos de pago / Grupos de opciones NO puede crear ni modificar endpoints (Assumptions del spec) — solo plantillas/estilos Angular.
- `app/core/units.py::convert()` y su fórmula (`qty * from.factor_to_base / to.factor_to_base`, misma dimensión) deben seguir funcionando igual para spec 134 (Principio VII no aplica a facturas, pero sí aplica el contrato de no-regresión de FR-010).
- La migración de `dimension` → `UnitMeasureGroup` se ejecuta una sola vez, es forward-only con estrategia de rollback explícita (Principio VIII), y no debe alterar ningún `factor_to_base`, nombre, abreviatura o estado activo existente (FR-012).
- Unicidad de nombre/abreviatura de unidad sigue siendo a nivel de tenant completo, no por grupo (clarificación de spec).
- Reasignar la unidad base o eliminar un grupo/unidad se bloquea si cualquier unidad del grupo está "en uso" por `InventoryItem.unit_measure_id` o `Purchase.unit_measure_id` (activo o inactivo) — mismo patrón 409 que `catalog/service.py::_raise_presentation_conflict`.

**Scale/Scope**: 2 repos, 1 entidad nueva (`UnitMeasureGroup`) + 1 migración de datos + ajustes a `UnitMeasure`, 1 migración Alembic, ~4 pestañas de Ajustes rediseñadas visualmente, 1 pestaña con funcionalidad nueva (grupos de unidades).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Evaluado contra los quince principios de `.specify/memory/constitution.md` (v4.0.0):

- **I. Nace de un spec** — PASA. `specs/137-rediseno-ajustes/spec.md` existe, aprobado, con clarificaciones resueltas (sesión 2026-10-26) antes de este plan.
- **II. Comportamiento existente protegido** — PASA con nota. El cambio de `dimension` (texto libre) a `UnitMeasureGroup` (entidad) es un cambio de modelo de datos explícito y autorizado por el propio spec (FR-005 a FR-014); no es un cambio de comportamiento oculto. No se requiere entrada en `registro-de-anomalias.md` porque el spec mismo es la autorización explícita de esta evolución funcional (Principio IV) — no hay conflicto con comportamiento heredado protegido, solo una entidad nueva. Se documenta igual en `data-model.md` por trazabilidad.
- **III. Characterization tests** — PASA. No se modifica ningún test `"CONGELA comportamiento actual:"`; `convert()` y sus tests existentes de spec 134 quedan intactos (FR-010).
- **IV. Nuevos specs pueden introducir comportamiento nuevo** — PASA. Los grupos de unidades son comportamiento nuevo definido y aprobado por este spec.
- **V. Sin refactors oportunistas** — PASA. El rediseño visual de las otras 3 pestañas se limita a plantillas/estilos (FR-001 a FR-003); no se tocan sus endpoints ni servicios.
- **VI. Evolución incremental** — PASA. El spec separa explícitamente "rediseño visual" (sin riesgo de datos) de "grupos de unidades" (con migración); ambas unidades de trabajo son verificables por separado y así se reflejan en `tasks.md` cuando se generen.
- **VII. Datos históricos** — N/A directo (no hay facturas involucradas), pero se extiende el espíritu: compras ya registradas (`Purchase.unit_measure_id`) no se reescriben ni recalculan por la migración (FR-012, Assumptions).
- **VIII. Evolución del modelo de datos** — PASA, se detalla en `data-model.md`: entidad nueva, campo nuevo (`UnitMeasure.group_id`, `UnitMeasure.is_base`), compatibilidad (cada `UnitMeasure` existente gana un grupo), estrategia de migración (data migration dentro de la misma revisión Alembic) y rollback (downgrade recompone `dimension` desde `UnitMeasureGroup.name` antes de borrar la tabla/columnas nuevas).
- **IX. Dependencias nuevas** — PASA. No se añade ninguna dependencia; se reutiliza FastAPI/SQLAlchemy/Alembic/Angular ya presentes.
- **X. Verificación obligatoria** — PASA (gate de proceso, se cumple en `/speckit-tasks` + implementación): se exige pytest del backend, `ng test` del frontend, y los criterios de aceptación del spec como tests de aceptación.
- **XI. Decisiones de negocio vs técnicas** — PASA. Las 4 decisiones de negocio (bloqueo de reasignación/renombrado si está en uso, unicidad por tenant, campo `abreviatura` visible) ya están resueltas en la sección Clarifications del spec, citadas aquí, no reinterpretadas.
- **XII. Trazabilidad** — PASA. Cadena Necesidad (pedido de rediseño) → Spec 137 → Decisión (clarificaciones) → este plan → tasks.md (siguiente comando) → implementación → tests.
- **XIII. Español de Colombia** — PASA. Todos los artefactos de este plan se escriben en español de Colombia.
- **XIV. Ramas Git** — Pendiente de ejecución, no de este comando: antes de tocar código en `pos-backend`/`pos-heladeria` se debe crear `feat/137-rediseno-ajustes` desde la rama actual de cada repo (el repo `pos-specs` no está sujeto a este principio porque no es código de producto).
- **XV. Commits** — Pendiente de ejecución: commits solo bajo pedido explícito del usuario, en inglés, sin firma de IA.

**Resultado**: ninguna violación que requiera `Complexity Tracking`. Gate PASA sin excepciones.

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
../pos-backend/                                  # repo hermano, API FastAPI
├── app/
│   ├── models/
│   │   ├── unit_measure.py                      # se ajusta: +group_id, +is_base
│   │   ├── unit_measure_group.py                # NUEVO: entidad Grupo de unidades
│   │   └── unit_measure_factor_change.py        # sin cambios (spec 134)
│   ├── api/v1/
│   │   ├── unit_measures/
│   │   │   ├── router.py                        # se ajusta: valida grupo/base/en-uso
│   │   │   └── schemas.py                        # se ajusta: group_id en vez de dimension
│   │   └── unit_measure_groups/                  # NUEVO: router + schemas del grupo
│   ├── core/
│   │   └── units.py                              # SIN CAMBIOS (misma fórmula, FR-010)
│   └── alembic/versions/
│       └── <rev>_137_unit_measure_groups.py      # NUEVA migración (schema + data migration)
└── tests/
    ├── unit/test_unit_measure_groups.py          # NUEVO
    ├── unit/test_unit_measures_in_use.py         # NUEVO (bloqueos FR-008/009/011/014)
    └── integration/test_units_conversion.py      # existente (spec 134) — debe seguir en verde

../pos-heladeria/                                 # repo hermano, SPA Angular
└── src/app/
    ├── modules/settings/pages/
    │   ├── settings-page.component.ts            # rediseño visual (tabs), sin cambio de lógica
    │   └── tenant-info.component.ts               # rediseño visual (FR-001)
    ├── modules/unit-measures/
    │   ├── pages/unit-measures-page.component.ts  # se rediseña + agrupa por UnitMeasureGroup
    │   └── components/
    │       ├── unit-measure-form.component.ts     # se ajusta: selección de grupo, flag base
    │       └── unit-measure-group-form.component.ts  # NUEVO: crear/editar grupo + unidad base
    └── core/
        ├── interfaces/
        │   ├── unit-measure.interface.ts          # se ajusta: group_id/is_base
        │   └── unit-measure-group.interface.ts    # NUEVO
        └── services/
            ├── unit-measure.service.ts            # se ajusta: endpoints de grupo
            └── unit-measure-group.service.ts       # NUEVO
```

**Structure Decision**: Web application con dos repos existentes y ya estructurados
(`pos-backend` por capas `models/api/core`, `pos-heladeria` por módulos Angular con
`pages/components/services`). No se introduce ninguna carpeta ni capa nueva más allá de
`unit_measure_groups` (backend) y `unit-measure-group-form`/`unit-measure-group.service`
(frontend), siguiendo el mismo patrón que `option_groups` ya usa en ambos repos.

## Constitution Check (post Phase 1)

Re-evaluado tras generar `data-model.md`, `contracts/` y `quickstart.md`:

- El diseño de `UnitMeasureGroup` + `is_base` (D1) no cambia `convert()` ni su fórmula
  (Principio VII/FR-010 siguen intactos) — confirmado en `contracts/unit-measures-api.md`.
- La migración documentada en `data-model.md`/`research.md` D4 cumple Principio VIII:
  entidades/campos nuevos, compatibilidad, estrategia de migración y de rollback, los
  tres explícitos.
- Los tres endpoints de escritura ajustados (`POST`/`PATCH`/`DELETE /unit-measures`) y los
  cinco nuevos de `/unit-measure-groups` quedan documentados en `contracts/`, sin tocar
  los endpoints de lectura de spec 134 ni el historial de factor changes.
- Ningún gate pasa a estado de violación tras el diseño detallado. Se mantiene: **PASA
  sin excepciones**.

## Complexity Tracking

No aplica — el Constitution Check (inicial y post Phase 1) no registró ninguna
violación que requiera justificar.
