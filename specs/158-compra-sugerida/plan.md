# Implementation Plan: Compra Sugerida de Insumos

**Branch**: `feat/158-compra-sugerida` | **Date**: 2026-11-15 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/158-compra-sugerida/spec.md`

## Summary

Nueva pantalla "Compra Sugerida" en el módulo de inventario: lista, en una sola vista
paginada, los insumos activos cuyo stock está en el mínimo o por debajo, precargados con
su proveedor preferido, unidad de compra y precio; permite ajustar cantidad/proveedor/precio
por fila; y genera, en una sola solicitud idempotente, una orden de compra en borrador por
cada proveedor distinto entre las filas seleccionadas, todo dentro de una única transacción
(todo o nada). Se construye reutilizando al máximo lo que ya existe en `pos-backend`
(`InventoryItem.min_stock`/`current_stock`, `SupplierItem` preferido/alternos,
`Purchase`/`PurchaseItem` en estado `draft`, el endpoint `/items/low-stock` como precedente
de la consulta) y en `pos-heladeria` (patrón de `purchase-view.component.ts`, `InventoryService`,
`SupplierItemsService`, paginación `Page`/`injectPagedQuery`). Los dos huecos reales son: (1)
un endpoint nuevo que agrupa por proveedor y crea N órdenes en una sola transacción —hoy
`create_purchase_order` comitea una orden a la vez—, y (2) una tabla nueva de claves de
idempotencia, porque no existe un mecanismo genérico reutilizable de ese tipo en el backend.

## Technical Context

**Language/Version**: Python 3.14 (backend, FastAPI 0.136), TypeScript/Angular 21 (frontend, standalone components + signals)

**Primary Dependencies**: FastAPI, SQLAlchemy 2.0, Pydantic 2, Alembic (backend); Angular 21, `@tanstack/angular-query-experimental` (`injectPagedQuery`), Angular CDK (ya en el proyecto, sin usarse para virtual-scroll todavía) (frontend)

**Storage**: PostgreSQL 16, schema-per-tenant (schema `tenant`), vía SQLAlchemy ORM

**Testing**: `unittest` characterization tests (`pos-backend/app/characterization_tests/`, SQLite in-memory) + nuevos tests de la funcionalidad en el mismo directorio; Vitest vía `ng test` en `pos-heladeria` para los componentes/servicios nuevos

**Target Platform**: Servidor Linux (API) + SPA Angular servida al navegador

**Project Type**: Web application (backend + frontend, dos repos hermanos)

**Performance Goals**: pantalla usable con hasta ~100+ filas bajo mínimo sin bloquear el hilo principal (paginación de servidor, no carga completa); generación de hasta 20 insumos / 5 proveedores en una sola solicitud en menos de 2 s de proceso en servidor (SC-002 es una cota de UX extremo a extremo, no solo de servidor)

**Constraints**: toda la generación de órdenes corre en una única transacción de base de datos (FR-009); ninguna escritura de esta funcionalidad modifica `InventoryItem.current_stock` (FR-013) ni `SupplierItem.last_cost` (FR-007); reintentos con la misma clave de idempotencia no deben duplicar órdenes (FR-010/SC-005)

**Scale/Scope**: una pantalla nueva + un endpoint de lectura nuevo + un endpoint de escritura nuevo + una tabla nueva (claves de idempotencia) + un refactor interno mínimo y acotado de `service.py` (ver Complexity Tracking)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principio I (nace de un spec)**: ✅ `specs/158-compra-sugerida/spec.md` ya existe y está aprobado (clarificaciones resueltas 2026-11-15).
- **Principio II (comportamiento existente protegido)**: ✅ no se modifica ningún comportamiento existente de `/inventory/items/low-stock`, `/inventory/purchases`, `/inventory/purchases/order` ni de `SupplierItem.last_cost`; todo lo nuevo vive en rutas y columnas nuevas. El único punto sensible —`_resolve_purchase_line` siempre llama a `apply_purchase_cost` cuando hay `supplier_item_id`— se resuelve con un parámetro nuevo con default que preserva el comportamiento actual para todo llamador existente (ver research.md D5); no es una decisión de negocio que cambie comportamiento, es una extensión aditiva.
- **Principio III (characterization tests)**: ✅ ningún test `"CONGELA comportamiento actual:"` se toca; los characterization tests de `create_purchase`/`create_purchase_order` existentes siguen pasando sin cambios porque su ruta de llamada no pasa el nuevo parámetro (usa su default).
- **Principio V (sin refactors oportunistas)**: ⚠️ ver Complexity Tracking — se extrae una función interna no-commiteadora de `create_purchase_order` para poder reusarla en el nuevo flujo multi-proveedor transaccional. Es refactor necesario para la funcionalidad (no cosmético), documentado y acotado a `app/api/v1/inventory/service.py`.
- **Principio VI (evolución incremental)**: ✅ un solo spec, una sola área funcional (compras por insumos bajo mínimo); no se mezcla con migraciones de datos no relacionadas ni con cambios de arquitectura.
- **Principio VII (datos históricos)**: ✅ no se toca ninguna factura ni compra ya confirmada/recibida; solo se crean compras nuevas en `draft`.
- **Principio VIII (evolución del modelo de datos)**: ✅ ver data-model.md — una tabla nueva (`purchase_generation_requests`) con estrategia de migración y rollback documentada.
- **Principio IX (dependencias nuevas)**: ✅ no se introduce ninguna dependencia nueva en ningún repo.
- **Principio XIV/XV (ramas y commits)**: se seguirá al implementar (`feat/158-compra-sugerida`), fuera del alcance de este comando de planeación.

No hay violaciones sin justificar; la única entrada de Complexity Tracking está justificada arriba y abajo.

## Project Structure

### Documentation (this feature)

```text
specs/158-compra-sugerida/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   └── suggested-purchases-api.md
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
../pos-backend/
├── app/
│   ├── models/
│   │   └── purchase_generation_request.py      # NUEVO (idempotencia, data-model.md)
│   ├── api/v1/inventory/
│   │   ├── router.py                            # + 2 endpoints nuevos bajo /inventory/purchases/suggested
│   │   ├── schemas.py                           # + DTOs nuevos (request/response de lo sugerido)
│   │   ├── service.py                           # + generate_suggested_purchases(); refactor interno de _resolve_purchase_line/create_purchase_order (research.md D5)
│   │   └── supplier_items.py                    # + función de precarga (proveedor preferido + alternos + unidad + precio) reusando preferred_relations_by_item/list_for_item
│   └── characterization_tests/
│       └── test_suggested_purchases.py          # NUEVO
└── alembic/versions/
    └── <rev>_add_purchase_generation_requests.py # NUEVO

../pos-heladeria/
├── src/app/modules/
│   ├── inventory/
│   │   ├── pages/
│   │   │   └── suggested-purchase-page.component.ts   # NUEVO (+ .spec.ts)
│   │   ├── services/
│   │   │   └── suggested-purchase.service.ts          # NUEVO (+ .spec.ts)
│   │   └── interfaces/
│   │       └── inventory.interface.ts                 # + interfaces nuevas (SuggestedPurchaseLine, etc.)
│   └── dashboard/
│       └── routes.ts                                   # + ruta 'inventario/compra-sugerida'
```

**Structure Decision**: aplicación web existente de dos repos (backend FastAPI + frontend
Angular). No se introduce ningún proyecto ni carpeta de alto nivel nueva; la funcionalidad
vive íntegramente dentro del módulo `inventory` que ya existe en ambos repos, como una
pantalla y un par de endpoints más del mismo router/módulo (mismo patrón que
`purchase-view.component.ts` y `/inventory/purchases/order` ya siguen para "Nueva compra").

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|---------------------------------------|
| Refactor interno de `create_purchase_order`/`_resolve_purchase_line` en `service.py` (extraer una variante que no comitea y que puede omitir `apply_purchase_cost`) | FR-008/FR-009 exigen crear **N** órdenes (una por proveedor) dentro de **una sola transacción** todo-o-nada, y FR-007 exige que el precio editado en pantalla **no** actualice `SupplierItem.last_cost`. La función existente hace ambas cosas (commit por orden, y siempre actualiza `last_cost` en modo `supplier_item_id`) porque hoy solo se usa para crear una orden a la vez con el precio real del proveedor. | Llamar a `create_purchase_order()` tal cual, una vez por proveedor: cada llamada comitea su propia transacción, así que un fallo en la segunda orden dejaría la primera ya creada — viola FR-009 directamente. Duplicar toda la lógica de `_resolve_purchase_line` en un archivo nuevo en vez de parametrizarla: duplica ~70 líneas de reglas de conversión/validación ya probadas (factor efectivo, chequeo de unidad/proveedor) con alto riesgo de que ambas copias diverjan con el tiempo. |
