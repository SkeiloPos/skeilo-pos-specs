# Implementation Plan: Exportación e importación masiva de la carta de productos vía Excel

**Branch**: `143-exportacion-importacion-carta-menu` | **Date**: 2026-10-29 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/143-exportacion-importacion-carta-menu/spec.md`

## Summary

Se extiende el patrón ya validado para inventario (specs 086/109/139/142) al dominio de la
carta: un export/import de 4 hojas relacionadas (Productos, Presentaciones y precios, Receta,
Adiciones) en `../pos-backend/app/api/v1/products/`, reutilizando Celery (ya configurado, hoy
usado por inventario y correo) para el import asíncrono, y una tabla nueva por tenant
(`product_import_jobs`) con la misma forma que `inventory_import_jobs` para el seguimiento del
job. `Product` gana una columna `code` (mismo patrón que `InventoryItem.code`, spec 109):
secuencial autogenerado, único por tenant, editable por un administrador, identificador de
referencia cruzada entre las 4 hojas. El import procesa las hojas en el orden Productos →
Presentaciones y precios → Receta → Adiciones (FR-007) y nunca elimina una fila existente por su
ausencia en el archivo (FR-005a) — la validación/aplicación de cada fila vive fuera del flujo
normal de `ProductService` (que hoy reemplaza receta/variantes por completo en cada guardado),
igual que el import de inventario ya opera sobre los modelos directamente en vez de reutilizar
`InventoryService.update_item`.

## Technical Context

**Language/Version**: Python 3.14 (`pos-backend`, vía `./env/bin/python`) + TypeScript 5.9 /
Angular 21 (`pos-heladeria`).

**Primary Dependencies**: FastAPI + SQLAlchemy 2.0 + `openpyxl` (ya usado por inventario, specs
086/109) + Celery (ya existente, hoy usado por `send_email_task` e `import_inventory_task`) +
Redis (ya usado como broker/result backend) — `pos-backend`. Angular 21 + `startVisibleInterval`
(`app/core/realtime/visible-interval.ts`, ya existente) — `pos-heladeria`. **Ninguna dependencia
nueva** (Principio IX): toda la infraestructura (worker Celery, Redis, openpyxl, el patrón de
polling del frontend) ya existe y ya se usa exactamente para este mismo tipo de flujo en
inventario.

**Storage**: PostgreSQL 16, un esquema por tenant. Cambios de esquema, todos vía migración
`@for_each_tenant_schema` (mismo patrón que `42dc063d8185_inventory_code_import_jobs.py`, spec
109): 1 columna nueva (`products.code`, con backfill) y 1 tabla nueva
(`product_import_jobs`) — ver `data-model.md`. Ningún cambio a `product_variants`,
`recipe_items`, `product_toppings` ni `presentations` (sus columnas ya alcanzan para lo que
exige el spec).

**Testing**: `pos-backend` — script autoejecutable `app/scripts/test_products_bulk_excel.py`
(mismo patrón que `test_inventory_bulk_excel.py`, spec 109) + regresión de
`./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`. No existe
hoy ningún export/import de la carta, así que no hay ningún characterization test que esta spec
reabra (Principio III no aplica — es comportamiento enteramente nuevo). `pos-heladeria` —
`npx ng test --watch=false --include='src/app/modules/products/**/*.spec.ts'` (Vitest).

**Target Platform**: servidor Linux (API) + worker Celery (mismo proceso/infra ya usado por
inventario y correo) + SPA Angular en navegador.

**Project Type**: aplicación web existente de dos repositorios, ambos en producción, más un
worker en segundo plano ya presente.

**Performance Goals**: sin objetivo de throughput propio — SC-001 pide exportar hasta "varios
cientos de productos" en menos de 30 segundos; a esa escala, un worker Celery resuelve un import
completo en segundos, igual que ya ocurre con inventario (spec 109, ≈500 filas).

**Constraints**: cada fila de import hace su propio commit independiente (nunca una transacción
de todo el archivo) — es lo que permite que FR-005a (no eliminar por omisión) y el edge case de
interrupción a mitad de proceso se cumplan sin ningún mecanismo de rollback especial, y lo que
hace seguro reintentar resubiendo el mismo archivo (Historia 3). Las hojas se procesan en el
orden de dependencia declarado por FR-007 (Productos → Presentaciones y precios → Receta →
Adiciones) dentro de la misma tarea Celery, para que una fila de una hoja posterior pueda
referenciar una fila creada en una hoja anterior del mismo archivo. El procesamiento de un import
siempre corre dentro del `schema_translate_map` del tenant que lo inició, nunca cruza esquemas.

**Scale/Scope**: 1 columna nueva (`products.code`) + 1 tabla nueva (`product_import_jobs`); 1
endpoint de export nuevo (4 hojas en un solo archivo); 4 endpoints nuevos de import (subir
archivo, consultar job vigente, consultar un job por id, descargar reporte de errores) — mismo
conjunto que inventario, sin el endpoint de cancelación explícita porque el spec no lo pide (el
de inventario sí lo tiene, pero es una extensión posterior no exigida aquí; se evalúa en
`research.md` D2); 1 tarea Celery nueva; en frontend: botones "Exportar carta"/"Importar Excel"
en la pantalla de Productos, reutilizando el mismo componente de modal de progreso que inventario
(adaptado a 4 hojas en el resumen).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Evaluación |
|---|---|
| I. Nace de un spec | PASS — `specs/143-exportacion-importacion-carta-menu/spec.md`, ya clarificada y con checklist en verde |
| II. Comportamiento existente protegido | PASS — no existe hoy ningún export/import de la carta; no hay comportamiento previo que esta spec modifique. `products.code` es una columna nueva, no reemplaza ni deriva de `name` (que sigue siendo como el resto del sistema identifica un producto hoy). No requiere entrada en `registro-de-anomalias.md` |
| III. Characterization tests | PASS, no aplica — no hay ningún test `"CONGELA comportamiento actual:"` sobre export/import de productos, porque la funcionalidad no existe antes de esta spec |
| IV. Nuevos specs introducen comportamiento nuevo | PASS — todo el flujo (código de producto, export, import) es comportamiento enteramente nuevo |
| V. Sin refactors oportunistas | PASS — se crea un submódulo nuevo dentro de `app/api/v1/products/` (export.py/import_.py) sin tocar `ProductService`, `catalog/service.py` ni los routers de `menu`/`categories`/`presentations`, que no tienen relación funcional con esta spec |
| VI. Evolución incremental | PASS — dos piezas de modelo de datos nuevas (1 columna, 1 tabla), ambas acotadas a este flujo; no mezcla con otra clase de cambio. No requiere Complexity Tracking |
| VII. Datos históricos | PASS — ninguna factura ni orden ya registrada se toca; el import solo crea/actualiza catálogo (producto, variante, receta, adición), nunca ventas ni facturación |
| VIII. Evolución del modelo de datos | PASS, ver `data-model.md` — columna y tabla nuevas, defaults, compatibilidad, estrategia de backfill y de rollback documentados explícitamente |
| IX. Dependencias nuevas | PASS — cero. Se reutiliza Celery + openpyxl + Redis + `startVisibleInterval`, todos ya presentes y usados por el mismo tipo de flujo (inventario) |
| X. Verificación obligatoria | PASS, ver `quickstart.md` — script dedicado + specs Vitest de `products` |
| XI. Negocio vs técnico | PASS — las decisiones de negocio (alcance, identificador persistente y editable, política de no-eliminar, bloqueo de imports concurrentes, permiso único) ya están en el spec (incluidas sus Clarifications); este plan solo decide el *cómo* (reutilizar Celery/tabla propia, mismo molde de inventario, resolución de categoría/presentación por nombre analogada a la de spec 109 D7 — ver `research.md`) |
| XII. Trazabilidad | PASS — necesidad (ticket + patrón ya validado de inventario) → spec 143 → este plan → `tasks.md` → implementación → script de verificación/specs Angular |
| XIII. Español de Colombia | Aplicado en este documento y en el resto de artefactos de esta fase |
| XIV. Rama Git | Pendiente de implementación: crear `feat/143-exportacion-importacion-carta-menu` en `pos-backend` y en `pos-heladeria`, desde la rama actual |
| XV. Commits | Pendiente de implementación: solo bajo pedido explícito del usuario, en inglés, sin marca de autoría de IA |

**Re-chequeo post-diseño (Fase 1)**: sin cambios — `data-model.md` y `contracts/api.md` no
introducen ninguna pieza de modelo de datos ni dependencia adicional respecto a lo evaluado
arriba.

## Project Structure

### Documentation (this feature)

```text
specs/143-exportacion-importacion-carta-menu/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── api.md
└── tasks.md              # /speckit-tasks, no este comando
```

### Source Code (sibling repositories, fuera de `pos-specs`)

```text
../pos-backend/
├── app/models/
│   ├── product.py                  # += code: str (único por tenant, mismo patrón que
│   │                                 #   InventoryItem.code, spec 109)
│   └── product_import_job.py       # NUEVO: ProductImportJob (status, conteos, errors JSONB)
│                                     #   -- mismas columnas que InventoryImportJob
├── app/api/v1/products/
│   ├── export.py                   # NUEVO: build_products_excel() -- 4 hojas en un solo
│   │                                 #   Workbook (Productos, Presentaciones y precios,
│   │                                 #   Receta, Adiciones), mismo patrón que
│   │                                 #   inventory/export.py (openpyxl en memoria)
│   ├── import_.py                   # NUEVO: validar_estructura (4 hojas, headers/orden),
│   │                                 #   validar_y_aplicar_fila por hoja (en el orden FR-007),
│   │                                 #   resolución buscar-o-crear de Categoría/Presentación
│   │                                 #   por nombre case-insensitive (research.md), resolución
│   │                                 #   estricta por código de Producto/Insumo/Producto-
│   │                                 #   adición (nunca crea insumos, FR-008)
│   ├── schemas.py                   # += PRODUCT_TEMPLATE_HEADERS (uno por hoja); +=
│   │                                 #   ProductCreate/Response.code; + esquemas de
│   │                                 #   ProductImportJob y su reporte de errores
│   ├── service.py                   # += generate_next_product_code / resolve_or_create_
│   │                                 #   by_code (upsert de Product por code, análogo a
│   │                                 #   inventory/service.py)
│   └── router.py                    # + GET /products/export, POST /products/import,
│                                     #   GET /products/import/current,
│                                     #   GET /products/import/{id},
│                                     #   GET /products/import/{id}/errors
├── app/celery_task.py                # + import_products_task(tenant_schema, job_id, hojas)
├── alembic/versions/
│   └── <hash>_product_code_import_jobs.py   # NUEVO, vía @for_each_tenant_schema
└── app/scripts/
    └── test_products_bulk_excel.py   # NUEVO

../pos-heladeria/
└── src/app/modules/products/
    ├── interfaces/product.interface.ts   # += code; + ProductImportJob/ImportRowError
    ├── services/product.service.ts       # + exportProducts(), importProducts(),
    │                                      #   getCurrentImportJob(), downloadImportErrors()
    ├── pages/products-page.component.ts   # + botones "Exportar carta"/"Importar Excel"
    └── components/
        └── product-import-modal.component.ts   # NUEVO: subir archivo, progreso (reutiliza
                                                  #   `startVisibleInterval`, mismo patrón que
                                                  #   inventory-import-modal.component.ts) y
                                                  #   resumen final con descarga de errores
```

**Structure Decision**: se extiende el módulo `products` ya existente (`service.py`,
`schemas.py`, `router.py`) en vez de crear un módulo paralelo de "carta" o "menu-import" — mismo
criterio que la spec 109 extendió `inventory` sin fragmentar el dominio. El export y el import
viven en archivos propios (`export.py`/`import_.py`), separados de `service.py`, porque el import
no reutiliza las operaciones de `ProductService` (que reemplazan receta/variantes por completo en
cada guardado desde la UI, research.md D1) — mezclarlos complicaría la lectura sin compartir
código real más allá de la definición de columnas (que vive en `schemas.py`, compartida por
ambos).

## Complexity Tracking

*Sin violaciones que requieran justificación — ver Constitution Check arriba.*
