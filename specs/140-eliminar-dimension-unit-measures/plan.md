# Implementation Plan: Eliminar columna `dimension` en unidades de medida

**Branch**: `140-eliminar-dimension-unit-measures` | **Date**: 2026-10-26 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/140-eliminar-dimension-unit-measures/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Cierra la deuda técnica aceptada explícitamente en la spec 137: `unit_measures.dimension`
deja de existir como columna espejo; `group_id` → `unit_measure_groups` pasa a ser la única
fuente de verdad. `app/core/units.py::convert()` valida compatibilidad comparando `group_id`
en vez de `.dimension`; se elimina el campo `dimension` de la respuesta de la API y el filtro
`?dimension=` (ya existe `group_id` como filtro equivalente); se eliminan los 4 puntos de
escritura/sincronización en `pos-backend`; y se actualiza el único consumidor real en
`pos-heladeria` (`purchase-form.component.ts`) para comparar por `group_id`.

## Technical Context

**Language/Version**: Python 3.11 (FastAPI, backend) + TypeScript/Angular (frontend)

**Primary Dependencies**: FastAPI, SQLAlchemy 2.x, Alembic (pos-backend); Angular, RxJS (pos-heladeria) — sin dependencias nuevas

**Storage**: PostgreSQL 16, esquema por tenant (`pos-backend`)

**Testing**: pytest / unittest (`app/characterization_tests/`), script de integración manual `app/scripts/test_purchase_unit_conversion.py` (pos-backend); suite de specs de Angular (pos-heladeria)

**Target Platform**: servidor Linux (API) + navegador (frontend Angular)

**Project Type**: web application (backend API + frontend Angular, dos repositorios independientes)

**Performance Goals**: N/A — cambio de modelo de datos y validación, sin requisitos de rendimiento nuevos

**Constraints**: ninguna migración puede alterar el significado histórico de los datos existentes (Principio VIII); el downgrade de la migración debe recomponer `dimension` desde `group.name` para dejar un entorno revertido en estado equivalente al anterior

**Scale/Scope**: 2 repositorios (`pos-backend`, `pos-heladeria`); 1 columna de BD, 1 función de validación, 2 endpoints de API, 4 puntos de escritura, 1 componente de frontend, tests asociados

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principio I (nace de un spec)**: ✅ este cambio nace de `specs/140-eliminar-dimension-unit-measures/spec.md`.
- **Principio II (comportamiento existente protegido / decisión de negocio)**: el comportamiento de negocio observable (qué conversiones son válidas, qué unidades son compatibles) **no cambia** — solo se retira un campo/filtro de API que la propia spec 137 ya documentó como deuda técnica temporal, sin consumidores externos conocidos (ver Assumptions del spec). Por tanto no se trata de una decisión de negocio nueva que requiera entrada en `registro-de-anomalias.md`; es la ejecución de una decisión ya registrada en `specs/137-rediseno-ajustes/research.md` (D2). Se deja constancia de este razonamiento en `research.md` de esta spec para trazabilidad (Principio XII). **PASA**.
- **Principio III (characterization tests)**: los tests `"CONGELA comportamiento actual:"` en `test_core_units.py` que fijan la forma actual de `convert()` se actualizan explícitamente como parte de esta spec (no se tocan en silencio); el assert `assertIn("dimension", ...)` se invierte a `assertNotIn` porque el spec autoriza explícitamente la eliminación de la columna. **PASA**.
- **Principio V/VI (sin refactors sueltos, evolución incremental)**: el alcance se limita estrictamente a eliminar `dimension` y sus usos; no se toca el modelo de `UnitMeasureGroup` ni ninguna otra funcionalidad. Es un único incremento coherente (una columna redundante y sus 6 puntos de uso), no una mezcla de clases de cambio distintas. **PASA**.
- **Principio VII (datos históricos)**: no aplica — `unit_measures` no es un dato de facturación histórica. **PASA**.
- **Principio VIII (evolución del modelo de datos)**: la migración de eliminación y su estrategia de rollback (recomponer `dimension` desde `group.name`) se especifican en `data-model.md`. **PASA**.
- **Principio IX (dependencias nuevas)**: ninguna dependencia nueva. **N/A**.
- **Principio X (verificación)**: se verifica con characterization tests actualizados, el script de integración de conversión de compras, y build/typecheck del frontend — detallado en `quickstart.md`. **PASA**.

No hay violaciones que requieran `Complexity Tracking`.

## Project Structure

### Documentation (this feature)

```text
specs/140-eliminar-dimension-unit-measures/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
../pos-backend/
├── app/
│   ├── models/
│   │   └── unit_measure.py                  # quita columna `dimension`
│   ├── core/
│   │   └── units.py                         # convert() compara group_id en vez de dimension
│   ├── api/v1/
│   │   ├── unit_measures/
│   │   │   ├── schemas.py                   # quita UnitMeasureResponse.dimension
│   │   │   └── router.py                    # quita query param dimension + escritura al crear
│   │   └── unit_measure_groups/
│   │       └── router.py                    # quita escrituras de dimension (crear/agregar/renombrar)
│   ├── characterization_tests/
│   │   └── test_core_units.py               # actualiza fixtures y asserts protegidos
│   └── scripts/
│       └── test_purchase_unit_conversion.py # actualiza construcción y llamada al router
└── alembic/versions/
    └── <rev>_139_remove_unit_measure_dimension.py  # nueva migración (upgrade dropea, downgrade recompone)

../pos-heladeria/
└── src/app/
    ├── core/
    │   ├── interfaces/unit-measure.interface.ts   # quita campo dimension
    │   └── services/unit-measure.service.ts       # quita loadUnitMeasuresByDimension (código muerto)
    └── modules/inventory/components/
        └── purchase-form.component.ts              # unitsForRow() compara groupId en vez de dimension
```

**Structure Decision**: aplicación web con dos repositorios independientes ya existentes
(backend FastAPI + frontend Angular), según el Alcance del Proyecto de la constitución. No se
introduce ninguna carpeta ni módulo nuevo: todos los cambios son ediciones puntuales sobre
archivos ya identificados en la exploración previa, más una migración Alembic nueva siguiendo
el patrón de las migraciones 134/137 existentes.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

Ninguna violación que justificar — todos los gates de la Constitution Check pasan sin excepciones.
