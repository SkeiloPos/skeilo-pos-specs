# Implementation Plan: Búsqueda por Nombre o Código y Filtro por Proveedor en Inventario

**Branch**: `feat/133-search-filter-inventory` | **Date**: 2026-10-23 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/133-busqueda-filtro-inventario/spec.md`

## Summary

Amplía el buscador existente de la pestaña "Insumos" de Inventario para que compare el texto
ingresado contra `name` **o** `code` del insumo (hoy solo compara contra `name`), y agrega un
nuevo filtro de selección única por proveedor que se combina (intersección) con el buscador y
con los filtros ya existentes de tipo y estado. El filtro por proveedor solo considera
`SupplierItem.active = true` (relación activa, spec 106). Enfoque técnico: ampliar
`list_items_query()` en el backend con un `OR` sobre `code.ilike()` y, cuando se recibe
`supplier_id`, una subconsulta `EXISTS`/`IN` contra `supplier_items` filtrada por
`supplier_id` + `active = true`; en el frontend, agregar una señal de estado
`itemsSupplierId` y un `<select>` de proveedor junto a los filtros de tipo/estado, siguiendo
exactamente el mismo patrón de reset-a-página-1 que ya usan `setItemsType`/`setItemsActive`.
No se requiere un índice nuevo para el texto (mismo `ILIKE %texto%` sin trigram que ya usa
`name`, aceptado como limitación existente a esta escala); sí se agrega un índice compuesto
`(supplier_id, active)` sobre `supplier_items` para que el filtro por proveedor no dependa de
un filtro en memoria sobre `active` tras usar el índice de un solo columna ya existente.

## Technical Context

**Language/Version**: Python 3.11 (FastAPI backend), TypeScript/Angular (frontend, standalone
components + signals + TanStack Angular Query)

**Primary Dependencies**: FastAPI, SQLAlchemy 2.x, Alembic, PostgreSQL 16 (backend);
Angular, `@tanstack/angular-query-experimental` (frontend) — ninguna dependencia nueva

**Storage**: PostgreSQL 16, schema-per-tenant (`tenant.inventory_items`,
`tenant.supplier_items`)

**Testing**: `python -m unittest discover -s app/characterization_tests -p 'test_*.py' -v`
(backend, venv en `pos-backend/env/`, Postgres local vía `docker compose up -d postgres redis`
+ `alembic upgrade head`); suite de Angular existente en `pos-heladeria` (baseline conocida
como flaky/no determinística — comparar por archivo, no por conteo total de la suite)

**Target Platform**: Servidor Linux (API) + navegador (SPA Angular) — sin cambios de
plataforma

**Project Type**: Web application (backend `pos-backend` + frontend `pos-heladeria`, repos
hermanos)

**Performance Goals**: Resultados de búsqueda/filtro en menos de 1 segundo percibido (SC-003)
para catálogos de hasta 5,000 insumos

**Constraints**: Sin regresión en la búsqueda por nombre existente (FR-010); el filtro por
proveedor únicamente sobre relaciones activas (FR-005); paginación debe reiniciar a página 1
ante cualquier cambio de búsqueda o filtro (FR-007, ya implementado para tipo/estado, debe
extenderse a proveedor)

**Scale/Scope**: 500–5,000 insumos por tenant (escala típica de PyME, confirmado en
Clarifications); cambio acotado a un endpoint (`GET /inventory/items`), su query builder, y la
pestaña "Insumos" del frontend — no toca "Compras" ni "Movimientos"

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principio I (nace de un spec)**: PASA — spec.md ya existe y está clarificado antes de este
  plan.
- **Principio II (comportamiento existente protegido)**: PASA — la búsqueda por nombre no
  cambia su comportamiento (sigue siendo `ILIKE` parcial insensible a mayúsculas); solo se le
  agrega una condición `OR` adicional sobre `code`. No se requiere registrar nada en
  `registro-de-anomalias.md` porque no se modifica ningún comportamiento ya existente, solo se
  amplía (FR-002/FR-003) y se agrega uno nuevo (filtro de proveedor).
- **Principio III (characterization tests)**: PASA — no hay characterization tests sobre
  `list_items_query`/`GET /inventory/items` identificados en la investigación; si research.md
  encuentra alguno al revisar `app/characterization_tests/`, se revalida antes de implementar.
- **Principio V/VI (sin refactors oportunistas, evolución incremental)**: PASA — el cambio se
  limita a extender `list_items_query()`, el endpoint, el service de frontend y el template de
  la pestaña Insumos; no se reestructura paginación, no se tocan otras pestañas de Inventario.
- **Principio VII (datos históricos)**: N/A — no hay facturas ni datos históricos involucrados.
- **Principio VIII (evolución del modelo de datos)**: Aplica de forma mínima — se agrega un
  índice compuesto nuevo sobre `supplier_items(supplier_id, active)` vía Alembic; no se agregan
  columnas ni se cambia el significado de datos existentes. Ver Phase 1 / data-model.md para
  la migración y su estrategia de rollback (`downgrade` elimina el índice).
- **Principio IX (dependencias nuevas)**: PASA — no se introduce ninguna dependencia nueva.
- **Principio XIV (rama antes de tocar código)**: Pendiente de ejecutar al iniciar la
  implementación — rama `feat/133-search-filter-inventory` en ambos repos antes de cualquier
  cambio de código (no en este repo de specs).

Sin violaciones que requieran `Complexity Tracking`.

## Project Structure

### Documentation (this feature)

```text
specs/133-busqueda-filtro-inventario/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   └── inventory-items-list.md
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
# Option 2: Web application (repos hermanos, ya existentes)
../pos-backend/
├── app/
│   ├── models/
│   │   ├── inventory_item.py        # InventoryItem (name, code ya indexados/únicos)
│   │   └── supplier_item.py         # SupplierItem (supplier_id, inventory_item_id, active)
│   ├── api/v1/inventory/
│   │   ├── router.py                 # GET /inventory/items — agrega query param supplier_id
│   │   ├── service.py                # list_items_query() — agrega OR code + filtro proveedor
│   │   └── supplier_items.py         # list_for_supplier() — patrón de referencia a adaptar
│   ├── alembic/versions/
│   │   └── <nueva_revision>_supplier_items_supplier_active_index.py
│   └── app/characterization_tests/   # posible test nuevo de regresión sobre list_items_query
└── (venv en env/, Postgres 16 local vía docker compose)

../pos-heladeria/
└── src/app/modules/inventory/
    ├── pages/inventory-page.component.ts   # agrega <select> de proveedor junto a tipo/estado
    └── services/inventory.service.ts       # agrega señal itemsSupplierId + setter + queryKey
```

**Structure Decision**: Web application existente de dos repos hermanos (`pos-backend` +
`pos-heladeria`); no se crea ningún proyecto ni carpeta nueva. El cambio se concentra en el
módulo `inventory` de ambos repos, reutilizando los archivos y patrones ya identificados en la
investigación de código (router/service/modelo en backend; componente/servicio en frontend).

## Complexity Tracking

*Sin violaciones de la Constitution Check que requieran justificación.*
