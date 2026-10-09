# Implementation Plan: Gestión de la relación proveedor–insumo

**Branch**: `106-relacion-proveedor-insumo` | **Date**: 2026-10-09 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/106-relacion-proveedor-insumo/spec.md`

## Summary

Modelar la relación N:M `SupplierItem` entre `Supplier` (proveedor) e `InventoryItem` (insumo)
en `pos-backend`, con presentación, factor de conversión (decimal > 0) y último costo, aplicando
las reglas de negocio RN-16 (un solo preferido activo por insumo, protegido con
`SELECT ... FOR UPDATE` sobre el insumo + un índice parcial no diferible) y RN-17 (el proveedor
de sistema "Compra ocasional", nuevo atributo `Supplier.is_system`, nunca se vincula ni es
preferido). La unicidad por (proveedor, insumo, presentación) se fuerza con un índice único por
expresión sobre `lower(trim(presentation))` para que la comparación sea insensible a mayúsculas y
espacios. En `pos-heladeria` se agregan dos vistas de detalle nuevas (insumo y proveedor), cada
una con una pestaña que lista/gestiona estas relaciones desde su lado — primera vez que el
proyecto necesita un componente de pestañas, construido sin nuevas dependencias.

## Technical Context

**Language/Version**: Python 3.14 (`pos-backend`, entorno en `./env`) + TypeScript 5.9 /
Angular 21 (`pos-heladeria`)

**Primary Dependencies**: FastAPI 0.136, SQLAlchemy 2.0, Pydantic 2.13, Alembic 1.18, psycopg 3
(`pos-backend`); Angular 21, `@angular/cdk`, `@tanstack/angular-query-experimental`, Tailwind 4
(`pos-heladeria`) — todas ya en uso, ninguna dependencia nueva (Principio IX)

**Storage**: PostgreSQL 16, un esquema por tenant (`__table_args__ = {"schema": "tenant"}` es un
placeholder que el runner de Alembic sustituye por cada esquema real vía `@for_each_tenant_schema`)

**Testing**: `pos-backend` no usa pytest — scripts autoejecutables bajo `app/scripts/test_*.py`
contra un tenant real (`python -m app.scripts.test_supplier_items`), más la suite de
characterization (`./env/bin/python -m unittest discover -s app/characterization_tests`) que
corre contra SQLite en memoria, donde **`FOR UPDATE` es un no-op** — el candado real de RN-16
solo puede verificarse de verdad contra Postgres, no en esa suite. `pos-heladeria` usa
`npx ng test --watch=false` (Vitest)

**Target Platform**: servidor Linux (API) + SPA Angular en navegador

**Project Type**: aplicación web existente de dos repositorios (`pos-backend` + `pos-heladeria`),
ambos en producción

**Performance Goals**: sin objetivo propio — son pantallas administrativas de bajo volumen (un
tenant tiene, como mucho, decenas de insumos y proveedores); se mantiene la paginación estándar
(`Page[...]`) ya usada en `/inventory/items` por consistencia, no por necesidad de escala

**Constraints**: el índice parcial `ux_preferido` NO puede declararse `DEFERRABLE` (solo las
constraints lo admiten, no los índices) — el swap de preferido depende de bloquear primero la
fila del insumo (`SELECT ... FOR UPDATE`), desmarcar y marcar, en ese orden, dentro de la misma
transacción, para no violarlo nunca a mitad de camino

**Scale/Scope**: 2 endpoints `GET` simétricos, 1 `POST` (alta/reactivación), 1 `PATCH` (edición,
preferido, activar/desactivar) en el backend; 2 páginas de detalle nuevas + 1 componente de
pestañas + 1 formulario de relación en el frontend

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Evaluación |
|---|---|
| I. Nace de un spec | PASS — `specs/106-relacion-proveedor-insumo/spec.md`, clarificado |
| II. Comportamiento existente protegido | PASS — pura adición; no cambia el comportamiento de `Supplier`/`InventoryItem`/`Purchase` ya existente, solo agrega columnas/tabla nuevas con default seguro |
| III. Characterization tests | PASS — ningún test `"CONGELA comportamiento actual:"` toca `suppliers`, `inventory_items` ni `purchases`; no hay nada que actualizar |
| IV. Nuevos specs introducen comportamiento nuevo | PASS — es exactamente ese caso |
| V. Sin refactors oportunistas | PASS — se reutiliza el router único de `inventory` (`router.py`/`schemas.py`) agregando una sección nueva, igual que `export.py`/`stock.py`; no se reorganiza nada existente |
| VI. Evolución incremental | Ver **Complexity Tracking** — esta spec combina tres piezas de modelo de datos en un mismo incremento (`Supplier.is_system`+seed, tabla `supplier_items`, columna `purchase_items.supplier_item_id`); justificado abajo |
| VII. Datos históricos | PASS — no se toca ninguna factura ni compra histórica; `purchase_items.supplier_item_id` nace `NULL` y nadie la popula todavía (la llena HU-05) |
| VIII. Evolución del modelo de datos | PASS, ver `data-model.md` — entidades/columnas nuevas, defaults, compatibilidad y estrategia de rollback documentadas explícitamente |
| IX. Dependencias nuevas | PASS — cero dependencias nuevas en ambos repos |
| X. Verificación obligatoria | PASS, ver `quickstart.md` — script `test_supplier_items.py` + specs Vitest de los componentes nuevos |
| XI. Negocio vs técnico | PASS — RN-16/RN-17 y las 3 clarificaciones son decisiones de negocio ya registradas en el spec; esta plan solo decide el *cómo* |
| XII. Trazabilidad | PASS — spec 106 → este plan → tasks.md → implementación → `test_supplier_items.py`/specs Angular |
| XIII. Español de Colombia | Aplicado en este documento y en los artefactos de esta fase; identificadores de código en inglés, igual que el resto del repositorio (ver `data-model.md`) |
| XIV. Rama Git | Pendiente de la fase de implementación: `feat/106-supplier-item-relation` en `pos-backend` y en `pos-heladeria`, creada antes de tocar código en cada repo (nombre de rama en inglés, Principio XIV; el directorio de la spec sigue en español — son independientes) |
| XV. Commits | Pendiente de la fase de implementación: solo bajo pedido explícito del usuario, en inglés, sin marca de IA |

**Re-chequeo post-diseño (Fase 1)**: sin cambios — `data-model.md` y `contracts/api.md` no
introdujeron ninguna pieza adicional de modelo de datos ni ninguna dependencia nueva respecto a lo
evaluado arriba.

## Project Structure

### Documentation (this feature)

```text
specs/106-relacion-proveedor-insumo/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/
│   └── api.md           # Phase 1 output (/speckit-plan command)
└── tasks.md              # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (sibling repositories, fuera de `pos-specs`)

```text
../pos-backend/
├── app/models/
│   ├── supplier.py              # + columna is_system (bool, default false)
│   └── supplier_item.py         # NUEVO: modelo SupplierItem (tabla supplier_items)
├── app/models/purchase.py       # + columna purchase_items.supplier_item_id (UUID NULL, FK)
├── app/api/v1/inventory/
│   ├── router.py                # + 4 rutas nuevas (GET x2, POST, PATCH), mismo router único
│   ├── schemas.py                # + SupplierItemCreate/Update/Response
│   └── supplier_items.py        # NUEVO: lógica de negocio (crear/reactivar, candado de
│                                 #   preferido, validación de factor inmutable, exclusión
│                                 #   de proveedores de sistema) — mismo patrón que stock.py/
│                                 #   export.py: archivo propio, importado por router.py
├── alembic/versions/
│   └── <hash>_supplier_items_y_proveedor_sistema.py   # NUEVO, vía @for_each_tenant_schema
└── app/scripts/
    └── test_supplier_items.py   # NUEVO: script autoejecutable (patrón test_cancel_inventory.py)

../pos-heladeria/
├── src/app/modules/inventory/
│   └── pages/
│       └── inventory-item-detail-page.component.ts   # NUEVO: detalle de insumo con pestañas
├── src/app/modules/suppliers/
│   └── pages/
│       └── supplier-detail-page.component.ts         # NUEVO: detalle de proveedor con pestañas
├── src/app/shared/components/
│   └── tabs/                     # NUEVO: componente de pestañas genérico (CDK + Tailwind,
│                                 #   sin librería nueva — primer uso de pestañas en el proyecto)
└── src/app/modules/supplier-items/   # NUEVO módulo compartido (lo consumen ambas páginas)
    ├── components/
    │   └── supplier-item-form.component.ts   # alta/edición + estrella de preferido
    ├── interfaces/supplier-item.interface.ts
    └── services/supplier-items.service.ts
```

**Structure Decision**: se reutiliza el router único de `app/api/v1/inventory` (igual que
`stock.py`/`export.py`, que ya conviven ahí sin ser el propio `router.py`) en vez de crear un
módulo API nuevo — la relación es un sub-recurso de insumos y proveedores, ambos ya servidos por
ese router. En el frontend, el nuevo módulo `supplier-items` es compartido porque la pestaña se
consume simétricamente desde dos páginas de detalle distintas (`inventory` y `suppliers`), que
hoy no existen como "detalle" (solo como lista+modal) y se agregan como páginas nuevas en sus
módulos respectivos — no se reestructura lo que ya existe en ninguno de los dos módulos.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|---------------------------------------|
| Principio VI: un mismo incremento toca 3 piezas de modelo de datos (`Supplier.is_system`+seed, tabla `supplier_items` nueva, `purchase_items.supplier_item_id` nullable) | Las tres son prerrequisito directo entre sí: sin `is_system` no se puede excluir a "Compra ocasional" (FR-012/FR-013); sin `supplier_items` no hay relación que proteger; sin la columna en `purchase_items` el bloqueo de factor usado-en-compra (FR-014) no tiene nada que inspeccionar. Decisión ya confirmada en el spec (Clarifications, Sesión 2026-10-09, pregunta 1) | Dividir en specs separadas bloquearía esta spec en cascada sin que ninguna de las tres partes entregue valor de negocio por sí sola — "Compra ocasional" sin relaciones que excluir, o una tabla `supplier_items` sin saber si ya se usó en una compra, no son entregables independientes |
