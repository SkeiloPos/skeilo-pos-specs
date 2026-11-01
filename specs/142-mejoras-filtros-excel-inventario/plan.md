# Implementation Plan: Filtro buscable de proveedor, exportación filtrada y vinculación de unidades de compra por Excel

**Branch**: `142-mejoras-filtros-excel-inventario` | **Date**: 2026-10-28 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/142-mejoras-filtros-excel-inventario/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Tres ajustes independientes a la pestaña "Insumos" de Inventario y a su exportación/importación
por Excel, en los repos hermanos `pos-backend` (FastAPI) y `pos-heladeria` (Angular):

1. **Filtro de proveedor buscable (Historia 1, solo frontend)**: reemplazar el `<select>` nativo
   del filtro de proveedor en `inventory-page.component.ts` por el componente ya existente
   `app-searchable-select` (`shared/searchable-select/`), en modo local, siguiendo exactamente el
   mismo patrón que ya usa el selector de insumo de "Movimientos" (`movementItemOptions()`). Sin
   cambios de backend ni de contrato — `onSupplierFilterChange()`/`setItemsSupplierId()` no
   cambian.

2. **Exportación filtrada (Historia 2, backend + frontend)**: el endpoint
   `GET /inventory/items/export` deja de llamar a `service.list_all_items_for_export(db)` (sin
   filtros) y pasa a construir el `Select` con `service.list_items_query(type_=type_,
   supplier_id=supplier_id)` (la misma función que ya usa `GET /inventory/items`, dejando
   `active=None` para seguir exportando activos e inactivos como hoy), ejecutándolo sin paginar.
   El router gana dos query params opcionales (`supplier_id`, `type_`); el frontend
   (`inventory.service.ts::exportItems()`) pasa a aceptarlos y un pequeño diálogo/selector en
   `inventory-page.component.ts` los recoge antes de llamar a `exportInventory()`, con "todos" como
   default si no se elige nada.

3. **Grupo de unidad base y unidad de compra por proveedor vía Excel (Historia 3, solo
   backend)**: dos columnas nuevas en la plantilla de import/export (`Grupo` y, para el proveedor
   preferido, `Unidad de compra` + `Factor de conversión`). Se modifica `_resolve_unit()` en
   `import_.py` para aceptar un nombre de grupo explícito (crear o reutilizar `UnitMeasureGroup`
   por nombre, en vez de crear siempre un grupo propio nuevo) y se agrega una función nueva
   `_resolve_purchase_unit()` que resuelve/crea una `UnitMeasure` dentro del **mismo grupo** que
   la unidad base del insumo — reutilizando el modo `unit_measure_id` de `SupplierItem` que ya
   introdujo la spec 140 (antes de esta spec esa vía solo estaba disponible desde el módulo de
   proveedores, nunca desde Excel). `_apply_preferred_supplier()` pasa a construir la relación
   con `unit_measure_id` resuelto en vez de dejar `presentation`/`conversion_factor` en `NULL`.
   Sin cambios de esquema: todas las columnas y relaciones usadas (`UnitMeasureGroup.name`,
   `UnitMeasure.group_id/abbreviation/factor_to_base`, `SupplierItem.unit_measure_id`) ya existen
   desde las specs 137/140.

## Technical Context

**Language/Version**: Python 3.14 (`pos-backend`, venv del proyecto); TypeScript/Angular 21
(`pos-heladeria`, standalone components + signals, sin NgRx)

**Primary Dependencies**: FastAPI 0.136.3, SQLAlchemy 2.0.50, Alembic 1.18.4 (sin migración
nueva — ver Constitution Check / data-model.md), Pydantic 2.13.4, openpyxl 3.1.5, Celery 5.6.3
(el import corre en `import_inventory_task`), psycopg3 (backend); RxJS `HttpClient`,
`app-searchable-select` (componente propio, sin librería externa) (frontend) — ninguna
dependencia nueva en ningún repo

**Storage**: PostgreSQL 16, schema-per-tenant. Sin cambios de esquema: Historia 2 solo agrega
condiciones `WHERE` a una consulta ya existente; Historia 3 reutiliza columnas y relaciones ya
creadas por las specs 137 (`unit_measure_groups`, `unit_measures.group_id/is_base`) y 140
(`supplier_items.unit_measure_id`)

**Testing**: `python -m unittest discover -s app/characterization_tests -p 'test_*.py' -v`
(backend, venv en `pos-backend/env/`, Postgres local vía `docker compose up -d postgres redis` +
`alembic upgrade head` — ver memoria `[[how-to-run-sibling-repo-tests]]`) +
`python -m app.scripts.test_inventory_bulk_excel` contra Postgres real para el flujo de
importación completo de Historia 3 (mismo script que ya ejercitó el gap de `group_id` en la spec
139); suite de Angular existente en `pos-heladeria` para Historias 1 y 2 (baseline conocida como
flaky/no determinística — comparar por archivo, no por conteo total)

**Target Platform**: Servidor Linux (API en producción) + navegador (SPA Angular)

**Project Type**: Web application — dos repos hermanos (`pos-backend` + `pos-heladeria`)

**Performance Goals**: Sin objetivos nuevos — Historia 1 es un filtrado en memoria sobre una
lista de proveedores ya cargada (misma escala que hoy); Historia 2 agrega como mucho dos
condiciones `WHERE`/`EXISTS` indexadas a una consulta ya usada por el listado; Historia 3 agrega
como máximo una consulta y un posible `INSERT` de unidad por fila de importación, mismo orden de
magnitud que la creación de unidad ya existente desde la spec 139.

**Constraints**: Preservar el comportamiento ya vigente de la spec 133 (filtrado del listado por
proveedor) y de la spec 139 (contrato de columnas, gap de `group_id` cerrado, no tocar relaciones
ya existentes en actualización) — Principio V/VI de la constitución: no mezclar refactorización
no relacionada. Ninguna migración de esquema. Ningún dato histórico de factura o compra se ve
afectado (Principio VII) — Historia 3 solo agrega una relación/unidad nueva cuando se crea un
insumo nuevo, nunca modifica una relación o unidad ya existente (FR-021, FR-013).

**Scale/Scope**: Dos repositorios. `pos-heladeria`: 1 componente (filtro de proveedor) + 1
servicio + 1 diálogo/selector nuevo para filtros de exportación (~3 archivos). `pos-backend`: 1
router (+2 query params), `service.py` (reutilizar `list_items_query`, posiblemente retirar
`list_all_items_for_export`), `import_.py` (extender `_resolve_unit`, nueva
`_resolve_purchase_unit`, extender `_apply_preferred_supplier`), `schemas.py` (nuevas columnas de
plantilla) + tests en `app/characterization_tests/` y en
`app/scripts/test_inventory_bulk_excel.py` (~5 archivos de producción).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Evaluación |
|---|---|
| I. Nace de un spec | ✅ `spec.md` existe, clarificado (2 preguntas resueltas) antes de este plan. |
| II. Comportamiento existente protegido | ✅ Los tres ajustes son aditivos: Historia 1 no cambia el resultado del filtrado (FR-003), solo cómo se elige la opción; Historia 2 preserva "sin filtro = todo" como comportamiento por defecto (FR-005); Historia 3 preserva el comportamiento de la spec 139 cuando las columnas nuevas vienen vacías (FR-011, FR-020). No se identifica un cambio de comportamiento que requiera registro en `registro-de-anomalias.md` — las dos clarificaciones ya resueltas en el propio spec cubren las únicas decisiones de negocio nuevas (reabrir y redefinir cómo se resuelve la unidad de compra, y qué pasa si falta el proveedor). |
| III. Characterization tests | ⚠️ Atención en implementación: `test_inventory_export.py` tiene suites que hoy asumen que el export no recibe filtros y que `_apply_preferred_supplier` deja `presentation`/`conversion_factor` en `NULL` — deben actualizarse explícitamente citando esta spec, no "ajustarse a ciegas". No se tocan characterization tests de otros campos (código/nombre/tipo/stock/costo). |
| IV. Nuevas specs introducen comportamiento nuevo | ✅ Aplica a las tres historias, cada una con sus FR. |
| V. No mezclar refactorización oportunista | ✅ El plan no toca `_resolve_unit_for_item`/`create_or_reactivate` de `supplier_items.py` (lógica del módulo de proveedores, spec 140); solo agrega una vía de entrada nueva desde `import_.py` que construye el mismo tipo de relación. No se retoca el componente `searchable-select` ni su modo remoto (spec 098) — se usa tal cual, en modo local. |
| VI. Evolución incremental | ✅ Tres unidades de cambio claramente separables en el propio spec (P1/P2/P3); cada una puede implementarse y verificarse por separado sin depender de las otras (confirmado por "Independent Test" de cada historia en `spec.md`). |
| VII. Compatibilidad con datos históricos | ✅ Ninguna factura, compra ni movimiento histórico se recalcula. Historia 3 solo crea entidades nuevas (grupo/unidad/relación) cuando el insumo mismo es nuevo; nunca modifica una `UnitMeasure`, `UnitMeasureGroup` o `SupplierItem` ya existente (FR-016 explícitamente prohíbe sobrescribir un factor ya vigente). |
| VIII. Evolución del modelo de datos | N/A — sin migración; todas las columnas y relaciones usadas (`unit_measure_groups`, `unit_measures.group_id`, `supplier_items.unit_measure_id`) ya existen desde las specs 137 y 140. |
| IX. Dependencias nuevas | N/A — ninguna dependencia nueva en ningún repo. |
| X. Verificación obligatoria | ✅ Ver `quickstart.md` (11 escenarios, uno por historia + casos de Historia 3) + characterization tests actualizados + `test_inventory_bulk_excel.py` extendido para el flujo de grupo/unidad de compra contra Postgres real. |
| XI. Negocio vs. técnico | ✅ Las decisiones de negocio de Historia 3 (cómo se resuelve la unidad de compra; qué pasa sin proveedor preferido) ya están citadas y resueltas en la sección "Clarifications" del spec, con su respuesta explícita — no son criterio técnico de implementación. |
| XII. Trazabilidad | ✅ Necesidad (tres ajustes pedidos por el usuario) → spec 142 (con contexto de specs 106/109/133/135/137/139 citado) → clarificaciones → este plan → tests → quickstart. |
| XIII. Español de Colombia | ✅ Todos los artefactos de esta fase en español de Colombia; nombres de rama/commits en inglés (XIV/XV). |
| XIV. Rama Git | ⚠️ Pendiente al iniciar implementación: crear rama con nombre en inglés (p. ej. `feat/142-inventory-filters-excel-improvements`) en cada repo que se toque, antes de cualquier cambio de código — este plan no modifica código. |
| XV. Commits | ⚠️ Pendiente: commits solo bajo pedido explícito del usuario, en unidades pequeñas (una por historia es razonable dado que son independientes), en inglés, Conventional Commits, sin marca de autoría de IA. No aplica a esta fase de planeación. |

**Resultado**: sin violaciones que requieran justificación en Complexity Tracking. Las filas ⚠️
son recordatorios operativos para `/speckit-implement`, no gates bloqueados en esta fase.

## Project Structure

### Documentation (this feature)

```text
specs/142-mejoras-filtros-excel-inventario/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   └── plantilla-excel-inventario.md
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repositorios hermanos, fuera de este repositorio de specs)

```text
../pos-backend/
├── app/
│   ├── api/v1/inventory/
│   │   ├── router.py          # GET /inventory/items/export: agrega query params
│   │   │                      # supplier_id, type_ (Historia 2)
│   │   ├── service.py         # list_items_query() ya soporta type_/supplier_id (spec 133);
│   │   │                      # se reutiliza desde el export. list_all_items_for_export()
│   │   │                      # se retira si queda sin uso.
│   │   ├── schemas.py         # INVENTORY_TEMPLATE_HEADERS: agrega columnas Grupo, Unidad
│   │   │                      # de compra, Factor de conversión (compra) (Historia 3)
│   │   ├── export.py          # build_inventory_excel: escribe las columnas nuevas
│   │   ├── import_.py         # _resolve_unit (acepta nombre de grupo explícito),
│   │   │                      # _resolve_purchase_unit (nueva, resuelve/crea unidad de
│   │   │                      # compra en el grupo de la unidad base),
│   │   │                      # _apply_preferred_supplier (usa unit_measure_id resuelto)
│   │   └── supplier_items.py  # _resolve_unit_for_item: referencia de patrón reutilizado
│   │                          # (validación de mismo grupo), sin cambios
│   ├── models/
│   │   ├── unit_measure.py          # sin cambios de esquema
│   │   ├── unit_measure_group.py    # sin cambios de esquema
│   │   └── supplier_item.py         # sin cambios de esquema (unit_measure_id ya existe)
│   ├── api/v1/unit_measure_groups/
│   │   └── router.py          # create_unit_measure_group/add_unit_to_group: patrón de
│   │                          # referencia para crear grupo/unidad, no se modifica
│   ├── characterization_tests/
│   │   ├── test_inventory_export.py   # actualizar suites de export sin filtros y de
│   │   │                              # _apply_preferred_supplier con NULL
│   │   └── fixtures.py                # reutilizar make_unit/make_inventory_item/
│   │                                  # make_supplier_item/make_unit_measure_group
│   └── scripts/
│       └── test_inventory_bulk_excel.py  # agregar escenarios de grupo explícito y unidad
│                                          # de compra contra Postgres real

../pos-heladeria/
└── src/app/modules/inventory/
    ├── pages/inventory-page.component.ts
    │   # Historia 1: reemplaza el <select> de proveedor (líneas 208-218) por
    │   # <app-searchable-select>, mismo patrón que movementItemOptions() (línea 889)
    │   # Historia 2: agrega selector/diálogo de filtros de exportación antes de
    │   # exportInventory() (línea 1000); pasa supplier_id/type_ a exportItems()
    └── services/inventory.service.ts
        # exportItems() (línea 352): agrega parámetros opcionales supplierId/type_
        # como query params de la petición GET
```

**Structure Decision**: Web application existente de dos repos hermanos (`pos-backend` +
`pos-heladeria`); no se crea ningún proyecto ni carpeta nueva. Historia 1 y la mitad frontend de
Historia 2 se concentran en `inventory-page.component.ts`/`inventory.service.ts`; Historia 3 y la
mitad backend de Historia 2 se concentran en el módulo `app/api/v1/inventory/` de `pos-backend`,
reutilizando en todos los casos componentes/funciones ya existentes identificados en la
investigación de código (`app-searchable-select`, `list_items_query`, el modo `unit_measure_id`
de `SupplierItem` de la spec 140) en vez de construir mecanismos nuevos.

## Complexity Tracking

*Sin violaciones de la Constitution Check que requieran justificación — tabla omitida.*
