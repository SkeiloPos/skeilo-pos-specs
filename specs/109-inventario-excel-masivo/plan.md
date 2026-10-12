# Implementation Plan: Exportación e Importación Masiva de Inventario en Excel

**Branch**: `109-inventario-excel-masivo` | **Date**: 2026-10-10 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/109-inventario-excel-masivo/spec.md`

## Summary

Esta spec reemplaza el export básico de la spec 086 (`app/api/v1/inventory/export.py`, 7
columnas) por una plantilla única compartida con un import nuevo: agrega una columna "código"
(nueva, única por insumo), las columnas del proveedor preferido (presentación, factor de
conversión, último costo — spec 106/107) y retira "Estado" (es un valor calculado, no editable).
El import se procesa siempre en segundo plano reutilizando Celery (ya existente en el proyecto,
hoy solo para correo) y persiste su resultado en una tabla nueva de Postgres por tenant —no en el
result backend de Celery—, para que el resumen y el reporte de errores sobrevivan un reinicio del
worker y sean consultables por tenant sin depender de que el navegador recuerde un id de tarea.

## Technical Context

**Language/Version**: Python 3.14 (`pos-backend`, vía `./env/bin/python`) + TypeScript 5.9 /
Angular 21 (`pos-heladeria`).

**Primary Dependencies**: FastAPI 0.136 + SQLAlchemy 2.0 + `openpyxl` (ya usado por la spec 086) +
Celery 5.6 (ya existente, hoy solo para `send_email_task`) + Redis (ya usado como broker/result
backend de Celery y como bus de eventos SSE de otro módulo) — `pos-backend`. Angular 21 +
`startVisibleInterval` (`app/core/realtime/visible-interval.ts`, ya existente) — `pos-heladeria`.
**Ninguna dependencia nueva** (Principio IX): el ticket original mencionaba BullMQ/exceljs (stack
Node), pero este backend ya tiene el equivalente de cada pieza en Python/Celery/openpyxl.

**Storage**: PostgreSQL 16, un esquema por tenant. Dos cambios de esquema, ambos vía migración
`@for_each_tenant_schema` (mismo patrón que `d57a9f54de14_purchase_items_presentacion.py`, spec
107): 1 columna nueva (`inventory_items.code`) y 1 tabla nueva (`inventory_import_jobs`) — ver
`data-model.md`.

**Testing**: `pos-backend` — script autoejecutable `app/scripts/test_inventory_bulk_excel.py`
(mismo patrón que `test_purchase_presentation.py`, spec 107) + regresión de
`./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`. El archivo
`test_inventory_export.py` (spec 086) **se actualiza directamente** como parte de esta spec: su
docstring ya aclara "No son characterization tests" (el endpoint no existía antes de la 086), así
que no aplica la protección del Principio III (`"CONGELA comportamiento actual:"`) — es una
actualización normal de los tests de una funcionalidad que esta spec reemplaza, no una reapertura
de un invariante protegido. `pos-heladeria` — `npx ng test --watch=false
--include='src/app/modules/inventory/**/*.spec.ts'` (Vitest).

**Target Platform**: servidor Linux (API) + worker Celery (mismo proceso/infra que ya corre para
correo, se reutiliza sin cambios de despliegue) + SPA Angular en navegador.

**Project Type**: aplicación web existente de dos repositorios, ambos en producción, más un
worker en segundo plano ya presente.

**Performance Goals**: sin objetivo de throughput propio — la escala acordada (Clarifications,
≈500 filas) es trivial para un worker Celery: se espera que un import completo tome segundos, no
minutos. No se diseña para catálogos de miles de insumos (ver spec.md, Assumptions).

**Constraints**: cada fila de import hace su propio commit independiente (nunca una transacción
de todo el archivo) — es lo que permite que FR-015 (no revertir lo ya aplicado si el proceso se
interrumpe) se cumpla sin ningún mecanismo de rollback especial, y lo que hace seguro reintentar
resubiendo el mismo archivo. El procesamiento de un import siempre corre dentro del
`schema_translate_map` del tenant que lo inició (igual que cualquier request), nunca cruza
esquemas.

**Scale/Scope**: 1 columna nueva (`code`) + 1 tabla nueva (`inventory_import_jobs`); 1 endpoint de
export extendido (mismas rutas); 4 endpoints nuevos (subir archivo, consultar job vigente,
consultar un job por id, descargar reporte de errores); 1 tarea Celery nueva; en frontend: botón
"Importar Excel" junto al ya existente "Exportar Inventario", un indicador de progreso que
reutiliza `startVisibleInterval` para sondear el job vigente, y una vista de resumen con descarga
de errores.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Evaluación |
|---|---|
| I. Nace de un spec | PASS — `specs/109-inventario-excel-masivo/spec.md`, ya clarificada |
| II. Comportamiento existente protegido | PASS CON ACCIÓN — el archivo exportado cambia de columnas (agrega código y datos de proveedor preferido, retira "Estado"); es un cambio de negocio ya decidido interactivamente con el usuario en `/speckit-specify` (ver "Aclaraciones previas" del spec), pero falta registrarlo formalmente en `specs/000-reconocimiento/registro-de-anomalias.md` (próxima entrada: **A-123**) antes de implementar — queda como primera tarea de `tasks.md`, mismo patrón que A-122 (spec 108) |
| III. Characterization tests | PASS — `test_inventory_export.py` (spec 086) se declara a sí mismo "No son characterization tests" en su docstring; no hay ningún test `CONGELA comportamiento actual:` sobre exportación/importación de inventario. Se actualiza directamente, citando esta spec, sin necesitar la autorización especial del Principio III |
| IV. Nuevos specs introducen comportamiento nuevo | PASS — el import es comportamiento enteramente nuevo; el export cambia con autorización explícita (ver II) |
| V. Sin refactors oportunistas | PASS — se extiende `export.py`/`supplier_items.py`/`service.py` ya existentes; no se reorganiza el módulo de inventario ni se tocan compras/recetas, que no tienen relación con esta spec |
| VI. Evolución incremental | PASS — dos piezas de modelo de datos nuevas (1 columna, 1 tabla), ambas acotadas a este flujo; no mezcla con otra clase de cambio. No requiere Complexity Tracking |
| VII. Datos históricos | PASS — ninguna factura ni compra ya registrada se toca. La columna `code` se backfillea para insumos existentes (dato nuevo, no reescribe ningún dato ya existente: nombre/stock/costo no cambian) |
| VIII. Evolución del modelo de datos | PASS, ver `data-model.md` — columna y tabla nuevas, defaults, compatibilidad, estrategia de backfill y de rollback documentados explícitamente |
| IX. Dependencias nuevas | PASS — cero. El ticket original pedía BullMQ/exceljs (Node); se reutiliza Celery + openpyxl, ya presentes |
| X. Verificación obligatoria | PASS, ver `quickstart.md` — script dedicado + actualización de `test_inventory_export.py` + specs Angular de `inventory` |
| XI. Negocio vs técnico | PASS — las 3 decisiones de alcance (identificador, relación con la 086, columnas de proveedor) y las 2 de las Clarifications (escala, interrupción) ya están en el spec; este plan solo decide el *cómo* (Celery + tabla propia en vez de depender del result backend) |
| XII. Trazabilidad | PASS — necesidad (ticket + spec 086 ya limitada) → spec 109 → decisión de negocio (pendiente de registrar, ver II) → este plan → `tasks.md` → implementación → script de verificación/specs Angular |
| XIII. Español de Colombia | Aplicado en este documento y en el resto de artefactos de esta fase |
| XIV. Rama Git | Pendiente de implementación: crear `feat/109-inventario-excel-masivo` en `pos-backend` y en `pos-heladeria`, desde `develop` |
| XV. Commits | Pendiente de implementación: solo bajo pedido explícito del usuario, en inglés, sin marca de autoría de IA |

**Re-chequeo post-diseño (Fase 1)**: sin cambios — `data-model.md` y `contracts/api.md` no
introdujeron ninguna pieza de modelo de datos ni dependencia adicional respecto a lo evaluado
arriba. La acción pendiente del gate II (registrar A-123) se traslada a `tasks.md` como su primera
tarea, igual que con A-122 en la spec 108.

## Project Structure

### Documentation (this feature)

```text
specs/109-inventario-excel-masivo/
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
│   ├── inventory_item.py          # += code: str (único por tenant, igual patrón que `name`)
│   └── inventory_import_job.py    # NUEVO: InventoryImportJob (status, conteos, errors JSONB)
├── app/api/v1/inventory/
│   ├── export.py                  # HEADERS += código, presentación/factor/último costo;
│   │                               #   retira "Estado"; lee el proveedor preferido vía el
│   │                               #   helper nuevo de supplier_items.py
│   ├── import_.py                 # NUEVO: parseo/validación de estructura (síncrono) +
│   │                               #   validación y upsert por fila (llamado por la tarea
│   │                               #   Celery, nunca directamente desde el router)
│   ├── supplier_items.py          # + helper batch análogo a `attach_preferred_supplier_names`
│   │                               #   pero con presentación/factor/último costo, reutilizado
│   │                               #   por export.py y por el detalle de insumo
│   ├── schemas.py                 # InventoryItemCreate/Update/Response += code; + esquemas de
│   │                               #   InventoryImportJob y su reporte de errores
│   ├── service.py                 # + create_import_job / get_current_job / resolve_or_create
│   │                               #   (upsert por code) — reutiliza supplier_items.py para la
│   │                               #   parte de proveedor preferido de cada fila
│   └── router.py                  # export sin cambio de ruta; + POST /items/import,
│                                   #   GET /items/import/current, GET /items/import/{id},
│                                   #   GET /items/import/{id}/errors
├── app/celery_task.py              # + import_inventory_task(tenant_schema, job_id, file_bytes)
├── alembic/versions/
│   └── <hash>_inventory_code_import_jobs.py   # NUEVO, vía @for_each_tenant_schema
├── app/characterization_tests/
│   └── test_inventory_export.py   # se actualiza (headers/celdas nuevas) — no es CONGELA, ver
│                                   #   Constitution Check
└── app/scripts/
    └── test_inventory_bulk_excel.py   # NUEVO

../pos-heladeria/
└── src/app/modules/inventory/
    ├── interfaces/inventory.interface.ts   # += code; + InventoryImportJob/ImportRowError
    ├── services/inventory.service.ts       # exportItems() sin cambio de firma; + importItems(),
    │                                        #   getCurrentImportJob(), downloadImportErrors()
    ├── pages/inventory-page.component.ts    # + botón "Importar Excel" junto al de exportar
    └── components/
        └── inventory-import-modal.component.ts   # NUEVO: subir archivo, mostrar progreso
                                                    #   (reutiliza `startVisibleInterval` para
                                                    #   sondear el job vigente) y el resumen final
                                                    #   con descarga de errores
```

**Structure Decision**: se extiende el módulo `inventory` ya existente (`export.py`,
`supplier_items.py`, `service.py`, `router.py`) en vez de crear un módulo paralelo de
"import/export" — mismo patrón que las specs 106/107 extendieron `inventory`/`supplier_items.py`
sin fragmentar el dominio. El import vive en un archivo propio (`import_.py`) dentro del mismo
módulo, separado de `export.py`, porque son dos flujos con validación y dependencias distintas
(el import depende de Celery y de la tabla de jobs; el export no depende de ninguno de los dos) —
mezclarlos en el mismo archivo solo complicaría la lectura sin compartir código real más allá de
la definición de columnas (que vive en `schemas.py`, ya compartida por ambos).

## Complexity Tracking

*Sin violaciones que requieran justificación — ver Constitution Check arriba. La única acción de
cumplimiento pendiente (registro de anomalías, Principio II) se trata como tarea, no como
excepción.*
