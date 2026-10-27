# Implementation Plan: Simplificar columnas de proveedor en Excel de inventario y vincular unidad a unidades de medida reales

**Branch**: `139-simplificar-columnas-excel-inventario` | **Date**: 2026-10-26 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/139-simplificar-columnas-excel-inventario/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Retirar del contrato de exportación/importación de inventario (spec 109, `pos-backend`) las tres
columnas de datos del proveedor preferido (presentación, factor de conversión, último costo),
dejándolas fuera del export y aceptadas-pero-ignoradas en import para no romper archivos legados.
En paralelo, corregir y completar el comportamiento ya parcialmente implementado de la columna
Unidad: al **crear** un insumo nuevo, vincularla a una `UnitMeasure` existente del negocio
(comparando por `abbreviation` sin distinguir mayúsculas/minúsculas) o crear una `UnitMeasure`
nueva en un `UnitMeasureGroup` nuevo propio (base, factor 1) si no existe — cerrando un gap real
ya detectado (`group_id` NOT NULL sin asignar en la autocreación actual, que rompe contra
Postgres real desde que la spec 137 añadió esa restricción). Al **actualizar** un insumo
existente, la columna Unidad se ignora por completo: no cambia la unidad del insumo ni crea
unidades nuevas como efecto secundario. Cambio exclusivo de `pos-backend`; `pos-heladeria` no
requiere modificaciones (confirmado por exploración: no duplica ni la lista de columnas ni la
lógica de creación de unidades).

## Technical Context

**Language/Version**: Python 3.14 (repo `pos-backend`, venv del proyecto — no el pytest de
Anaconda del sistema).

**Primary Dependencies**: FastAPI 0.136.3, SQLAlchemy 2.0.50, Alembic 1.18.4 (sin migración
nueva: no hay cambio de esquema, ver `data-model.md`), Pydantic 2.13.4, openpyxl 3.1.5 (lectura/
escritura de `.xlsx`), Celery 5.6.3 (el import corre en `import_inventory_task`), psycopg3/
psycopg2-binary, Starlette (TestClient de los characterization tests).

**Storage**: PostgreSQL 16, schema-per-tenant (`pos-backend` estándar). Esta funcionalidad no
agrega tablas ni columnas; solo corrige datos (`group_id`) que la autocreación de unidades debía
completar desde la spec 137 y no lo hacía.

**Testing**: `unittest` puro (no pytest) vía
`python -m unittest discover -s app/characterization_tests -p 'test_*.py' -v`, sobre SQLite en
memoria para los characterization tests HTTP-level, y `python -m app.scripts.test_inventory_bulk_excel`
como script standalone contra Postgres real para el flujo de importación completo (el único que
hoy ejercería — y expondría — el gap de `group_id` NOT NULL). Postgres local está disponible para
correr ese script durante la implementación (ver memoria `[[how-to-run-sibling-repo-tests]]`).

**Target Platform**: Servidor Linux (API en producción, `pos-backend`).

**Project Type**: Web service (API FastAPI) consumido por un frontend Angular que no requiere
cambios para esta spec.

**Performance Goals**: N/A — no cambia volumen ni frecuencia del flujo de import/export existente
(spec 109); el único trabajo adicional por fila es, como máximo, un `INSERT` de grupo + unidad
cuando la unidad no existe aún, operación ya equivalente en costo a la creación manual desde
Ajustes.

**Constraints**: Preservar el comportamiento ya vigente de la spec 109 para todos los campos no
mencionados por esta spec (código, nombre, tipo, stock, mínimo, costo, upsert por código) —
Principio V/VI de la constitución: no mezclar refactorización no relacionada. No debe ejecutarse
ninguna migración de esquema (no hay cambio de modelo, solo de lógica de aplicación) — Principio
VIII no aplica por ausencia de cambio de esquema, pero sí aplica el Principio VII: ningún dato
histórico de factura se ve afectado (este cambio no toca facturación).

**Scale/Scope**: Backend-only, 1 repositorio (`pos-backend`), ~4 archivos de producción
(`schemas.py`, `export.py`, `import_.py`, posiblemente `service.py` si el upsert necesita un
parámetro para omitir `unit_measure_id` en actualización) + tests nuevos/actualizados en
`app/characterization_tests/` y en `app/scripts/test_inventory_bulk_excel.py`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Evaluación |
|---|---|
| I. Nace de un spec | ✅ Cumple — spec.md existe y aprobado antes de este plan. |
| II. Comportamiento existente protegido | ✅ El cambio de comportamiento (retirar columnas, cambiar efecto de la columna Unidad) está explícitamente documentado en el spec (FR-001 a FR-009), no es una decisión técnica encubierta. No se identificó una decisión de negocio adicional que requiera registro en `registro-de-anomalias.md` más allá de lo ya resuelto en la sección "Aclaraciones previas" del propio spec. |
| III. Characterization tests | ⚠️ Atención en implementación: `test_inventory_export.py` tiene suites (`ExportColumnsTests`, parte de `ImportEndpointTests`) que hoy aseveran la presencia de las 4 columnas retiradas — esos tests **deben actualizarse explícitamente** citando esta spec en el commit, no "ajustarse a ciegas" para pasar. No se tocan characterization tests de otros campos (código/nombre/tipo/stock/costo). |
| IV. Nuevos specs pueden introducir comportamiento nuevo | ✅ Aplica — el nuevo comportamiento de vinculación de unidad está definido por FR-006/007/008/009. |
| V. No mezclar refactorización oportunista | ✅ El plan limita el alcance a los archivos de `app/api/v1/inventory/` y, si aplica, un parámetro puntual en `service.py`; no se toca `_resolve_supplier`/`supplier_items.py` salvo para dejar de invocarlos desde import (retiro de una llamada, no refactor de esos módulos). |
| VI. Evolución incremental | ✅ Una sola unidad de cambio: columnas de export/import + comportamiento de la columna Unidad, ambas ya acopladas en el mismo spec y en los mismos archivos (`import_.py`/`export.py`/`schemas.py`). No se mezcla con migraciones de datos ni cambios de arquitectura. |
| VII. Compatibilidad con datos históricos | ✅ No afecta facturación ni datos de ventas. FR-004 explícitamente protege los datos de proveedor preferido ya existentes de cualquier insumo. |
| VIII. Evolución del modelo de datos | N/A — no hay cambio de esquema; el "gap" de `group_id` se cierra en la lógica de aplicación (asignarlo siempre al crear), no en el modelo ni en una migración. |
| IX. Dependencias nuevas | N/A — no se añade ninguna dependencia. |
| X. Verificación obligatoria | ✅ Ver `quickstart.md` (7 escenarios) + characterization tests actualizados + script de importación masiva corrido contra Postgres real para confirmar el cierre del gap de `group_id`. |
| XI. Negocio vs. técnico | ✅ Las dos decisiones de negocio (qué pasa si la unidad no existe al crear; qué pasa con la columna unidad al actualizar) ya están resueltas y citadas en la sección "Aclaraciones previas" del spec, no son criterio técnico de implementación. |
| XII. Trazabilidad | ✅ Cadena completa: Necesidad (spec 109 generaba confusión tras spec 137) → spec 139 → decisiones ya registradas en el propio spec → este plan → tests → quickstart. |
| XIII. Español de Colombia | ✅ Todos los artefactos de esta fase (plan, research, data-model, contratos, quickstart) en español de Colombia; nombres de rama/commits en inglés (ver XIV/XV). |
| XIV. Rama Git | ⚠️ Pendiente al iniciar implementación: crear rama en `pos-backend` con nombre `feat/138-inventory-excel-unit-link` (o equivalente) **antes** de tocar código — este plan no modifica código, por lo que no se crea rama en esta fase. |
| XV. Commits | ⚠️ Pendiente: commits solo bajo pedido explícito del usuario durante la implementación, en inglés, Conventional Commits, sin marca de autoría de IA. No aplica a esta fase de planeación (no se generan commits aquí). |

**Resultado**: sin violaciones que requieran justificación en Complexity Tracking. Las filas ⚠️
son recordatorios operativos para la fase de implementación (`/speckit-implement`), no gates
bloqueados en esta fase de planeación.

## Project Structure

### Documentation (this feature)

```text
specs/139-simplificar-columnas-excel-inventario/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   └── plantilla-excel-inventario.md
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository: `../pos-backend`, fuera de este repositorio de specs)

```text
pos-backend/
├── app/
│   ├── api/v1/inventory/
│   │   ├── schemas.py        # INVENTORY_TEMPLATE_HEADERS: retira 4 columnas de proveedor
│   │   ├── export.py         # build_inventory_excel: deja de escribir esas 4 celdas
│   │   ├── import_.py        # validar_estructura (acepta ambos formatos), _resolve_unit
│   │   │                     # (asigna group_id al autocrear), elimina la llamada a
│   │   │                     # _apply_preferred_supplier/_resolve_supplier desde el import,
│   │   │                     # y evita resolver/crear unidad en filas de actualización
│   │   ├── service.py        # resolve_or_create_by_code: confirma y, si aplica, ajusta para
│   │   │                     # no sobrescribir unit_measure_id en la rama de actualización
│   │   └── supplier_items.py # sin cambios de comportamiento; solo deja de ser invocado
│   │                         # desde import_.py/export.py
│   ├── models/
│   │   ├── unit_measure.py          # sin cambios de esquema
│   │   └── unit_measure_group.py    # sin cambios de esquema
│   ├── api/v1/unit_measure_groups/
│   │   └── router.py         # referencia de patrón (create_unit_measure_group) a replicar
│   │                         # dentro de import_.py, no se modifica
│   ├── characterization_tests/
│   │   ├── test_inventory_export.py   # actualizar suites que asumen las 4 columnas retiradas
│   │   └── fixtures.py                # reutilizar make_unit/make_inventory_item/make_supplier_item
│   └── scripts/
│       └── test_inventory_bulk_excel.py  # agregar escenario del gap de group_id contra Postgres real
```

**Structure Decision**: cambio contenido en el módulo `app/api/v1/inventory/` de `pos-backend`
(FastAPI monolito por dominio, estructura ya existente — no se introduce una nueva capa ni
proyecto). No se toca `pos-heladeria` (confirmado sin dependencias de frontend sobre este
contrato). No aplica ninguna de las opciones genéricas de plantilla (single project / mobile+API)
— se documenta la estructura real del repositorio existente.

## Complexity Tracking

*Sin violaciones de la Constitution Check que requieran justificación — tabla omitida.*
