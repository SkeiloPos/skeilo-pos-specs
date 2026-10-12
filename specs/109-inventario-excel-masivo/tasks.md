---

description: "Task list for feature implementation"
---

# Tasks: Exportación e Importación Masiva de Inventario en Excel

**Input**: Design documents from `/specs/109-inventario-excel-masivo/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/api.md,
quickstart.md (todos presentes)

**Tests**: incluidas de forma liviana — un script autoejecutable
`pos-backend/app/scripts/test_inventory_bulk_excel.py` (sin pytest en este repo, mismo patrón que
la spec 107/108), más la actualización explícita de `test_inventory_export.py` (spec 086, no es
`CONGELA`) y la regresión obligatoria de la suite de characterization y de las specs Vitest de
`inventory`.

**Organization**: tareas agrupadas por historia de usuario (spec.md).

## Path Conventions

`../pos-backend/app/...` (FastAPI) y `../pos-heladeria/src/app/...` (Angular) — dos repositorios
en producción, ambos sobre la rama `develop`. `pos-specs/` es este repositorio (rama
`109-inventario-excel-masivo`), donde viven la spec y el registro de anomalías.

---

## Phase 1: Setup

### Puerta G1 — Registro de anomalías (bloquea escribir código, Principio II)

- [X] T001 Escribir la entrada **A-123** en
  `pos-specs/specs/000-reconocimiento/registro-de-anomalias.md`: el archivo exportado/importado de
  inventario cambia de columnas (agrega código del insumo y datos del proveedor preferido; retira
  "Estado", que era calculado) respecto al export básico de la spec 086, que esta spec
  reemplaza/absorbe — clasificación DECISIÓN, origen FR-001/FR-002/FR-003 de esta spec y las 3
  "Aclaraciones previas" del propio `spec.md`, con la evidencia de
  `pos-backend/app/api/v1/inventory/export.py` (HEADERS actuales) y
  `pos-backend/app/characterization_tests/test_inventory_export.py` (headers esperados, se
  actualiza en US1). Aclarar que `test_inventory_export.py` no es un test `CONGELA` (su propio
  docstring lo dice) y que esta spec lo actualiza directamente, sin reabrir el Principio III.

### Ramas (Principio XIV)

- [X] T002 [P] Crear la rama `feat/109-inventario-excel-masivo` en `../pos-backend`, a partir de
  `develop`.
- [X] T003 [P] Crear la rama `feat/109-inventario-excel-masivo` en `../pos-heladeria`, a partir de
  `develop`.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: el modelo de datos y la definición de plantilla que las 4 historias necesitan antes
de poder construir nada encima.

**⚠️ CRITICAL**: ninguna historia de usuario empieza antes de que esta fase termine.

- [X] T004 Migración `inventory_code_import_jobs` en
  `../pos-backend/alembic/versions/<hash>_inventory_code_import_jobs.py`, vía
  `@for_each_tenant_schema` (mismo patrón que `d57a9f54de14_purchase_items_presentacion.py`, spec
  107): (1) agregar `inventory_items.code` como `VARCHAR(20)` nullable; (2) backfillear con un
  secuencial de 4 dígitos (`"0001"`, ...) ordenado por `name`, vía SQL (`ROW_NUMBER() OVER (ORDER
  BY name)`); (3) alterar `code` a `NOT NULL`; (4) agregar índice único sobre `code`; (5) crear la
  tabla `inventory_import_jobs` (columnas de `data-model.md`: id, status, file_name,
  started_by_user_id, started_at, finished_at, total_rows, created_count, updated_count,
  failed_count, errors JSONB). `downgrade()` revierte las 5 operaciones en orden inverso.
  Verificado contra Postgres real (no solo SQLite): 107 insumos reales de un tenant
  (`heladeria3`) recibieron código único (0001-0107); `upgrade`/`downgrade`/`upgrade` ida y
  vuelta limpios, sin pérdida de filas.
- [X] T005 [P] Modelo `InventoryImportJob` en
  `../pos-backend/app/models/inventory_import_job.py` (mapea la tabla de T004; `errors` como
  columna `JSONB`, default `[]`).
- [X] T006 [P] Agregar el atributo mapeado `code: Mapped[str]` a `InventoryItem` en
  `../pos-backend/app/models/inventory_item.py` (mismo patrón `unique=True, index=True` que ya
  tiene `name`).
- [X] T007 Definir la plantilla única de las 11 columnas (nombre de cabecera, orden, origen/tipo
  esperado — `data-model.md`) como una constante/estructura compartida en
  `../pos-backend/app/api/v1/inventory/schemas.py`, de forma que `export.py` e `import_.py` (US1 y
  US2) la importen en vez de repetir la lista de cabeceras cada uno por su lado (research.md D6).
- [X] T008 [P] Agregar `code: str | None` a `InventoryItemCreate`/`InventoryItemUpdate` y
  `code: str` a `InventoryItemResponse` en
  `../pos-backend/app/api/v1/inventory/schemas.py`. También se expuso `code` en
  `POST /items`/`PATCH /items/{id}` (router.py) con generación automática
  (`service.generate_next_code`) cuando no se especifica — natural desde que la columna es
  `NOT NULL`, no solo para el import masivo.
- [X] T009 En `../pos-backend/app/api/v1/inventory/supplier_items.py`, agregar un helper batch
  (análogo a `attach_preferred_supplier_names`, spec 106) que trae presentación, factor de
  conversión y último costo pagado de la relación preferida de cada insumo recibido, en una sola
  consulta para todo el lote (research.md D4) — sin modificar `attach_preferred_supplier_names`
  existente ni el contrato de `InventoryItemResponse.preferred_supplier_name`.
  (`preferred_relations_by_item`).
- [X] T010 Corrido `./env/bin/python -m unittest discover -s app/characterization_tests -p
  'test_*.py'` en `../pos-backend` tras T004-T009: **1477 OK, 0 fallas nuevas** (mismo baseline
  que tras la spec 108). Se agregó `code` por defecto en `fixtures.make_inventory_item` y en los
  7 scripts sueltos (`app/scripts/test_*.py`, `e2e_qr_flow.py`) que construían `InventoryItem`
  directamente, para que sigan funcionando con la columna ahora `NOT NULL`.

**Checkpoint**: modelo de datos y plantilla listos — las 4 historias pueden empezar.

---

## Phase 3: User Story 1 - Exportar el inventario en el mismo formato que se usará para importar (Priority: P1) 🎯 MVP

**Goal**: la exportación de inventario usa la plantilla única de 11 columnas (T007), con los datos
del proveedor preferido cuando existan, sin la columna "Estado".

**Independent Test**: exportar un inventario con insumos con y sin proveedor preferido asignado;
confirmar que las cabeceras son exactamente las 11 columnas de `data-model.md`, en ese orden, y
que un insumo sin proveedor preferido trae esas columnas en blanco sin error.

### Implementación para User Story 1

- [X] T011 [US1] Actualizar `build_inventory_excel()` en
  `../pos-backend/app/api/v1/inventory/export.py`: usar la plantilla de T007 (código primero,
  proveedor preferido al final, sin "Estado"), llenando las columnas de proveedor con el helper de
  T009; mantener el resto del comportamiento ya existente (todos los insumos activos e inactivos,
  nombre de archivo con fecha, valores numéricos nativos). `router.py::export_items` actualizado
  para pasarle `preferred_relations_by_item(...)`.
- [X] T012 [US1] Actualizado
  `../pos-backend/app/characterization_tests/test_inventory_export.py`: `ExportColumnsTests` ahora
  espera las 11 cabeceras nuevas (sin "Estado", índices de columna corridos +1 por el nuevo
  "Código"); se agregó `test_insumo_con_proveedor_preferido_exporta_...` y
  `test_insumo_sin_proveedor_preferido_deja_esas_columnas_en_blanco` (requirió extender
  `_TABLE_NAMES`/fixtures locales con `suppliers`/`supplier_items`, antes no estaban en el harness
  de este módulo). Docstring del módulo cita esta spec y A-123.
- [X] T013 [US1] Creado `../pos-backend/app/scripts/test_inventory_bulk_excel.py` (mismo patrón
  que `test_purchase_presentation.py`, spec 107). Terminó cubriendo también T021 (ver ahí) —se
  escribió de una sola vez contra Postgres real (`heladeria3`, 107 insumos reales).
- [X] T014 [US1] Corrido `./env/bin/python -m app.scripts.test_inventory_bulk_excel` (7/7 OK) y la
  suite de characterization completa (**1484 OK**, creció de 1477→1479 por T012 y luego a 1484 por
  los tests de `POST /items/import` que terminaron adelantados a T020/T021 — ver ahí). 0 fallas.

**Checkpoint**: la exportación ya usa la plantilla única — desplegable por sí sola (mejora visible
aunque el import todavía no exista).

---

## Phase 4: User Story 2 - Importar el archivo con validación por fila y creación/actualización por código (Priority: P1)

**Goal**: subir un archivo Excel crea/actualiza insumos por código, valida cada fila de forma
independiente y reporta los fallos — funcional de punta a punta a nivel de backend, invocable sin
necesitar la interfaz todavía (igual que el script de verificación lo hace).

**Independent Test**: invocar la tarea de importación (en modo síncrono, sin necesitar un worker
Celery corriendo) con un archivo que mezcla filas que actualizan insumos existentes, filas que
crean insumos nuevos y filas con errores deliberados; confirmar que las válidas se aplican, las
inválidas quedan reportadas individualmente, y nada se pierde.

### Implementación para User Story 2

- [X] T015 [US2] Creado `../pos-backend/app/api/v1/inventory/import_.py` con
  `validar_estructura(headers) -> list[str] | None`: compara las cabeceras del archivo subido
  contra la plantilla de T007 (nombres y orden exactos); devuelve la lista de problemas o `None`
  si corresponde (FR-005).
- [X] T016 [US2] En `import_.py`, `validar_y_aplicar_fila(db, fila) -> dict`: aplica las reglas de
  `data-model.md` (código/nombre/tipo/unidad/stock/mínimo/costo obligatorios y con el tipo
  esperado; proveedor preferido opcional pero completo si se indica). Para el proveedor, en vez de
  llamar `create_or_reactivate` a ciegas (que responde 409 si la fila describe una relación que ya
  existe activa — el caso normal al reimportar el propio export), primero busca la relación
  existente por (proveedor, insumo, presentación) y la actualiza con `supplier_items.update(...,
  preferred=True)`; solo crea una nueva si no hay ninguna. Devuelve `{ok, accion, motivo}`. Cada
  fila hace su propio `db.commit()`/`db.rollback()` — nunca una transacción de todo el archivo
  (FR-006/FR-015).
  **Ajuste post-implementación (FR-006a, research.md D7, pedido por el usuario tras probar la
  primera versión)**: `_resolve_unit`/`_resolve_supplier` ya no fallan la fila cuando la unidad o
  el proveedor no existen — los consolidan creándolos en MAYÚSCULA, buscando siempre sin
  distinguir mayúsculas primero; un proveedor inactivo que coincida se reactiva en vez de
  duplicarse (`Supplier.name` no es único en el modelo). Sigue fallando si hay más de una
  coincidencia ambigua ignorando mayúsculas. `data-model.md`/`spec.md`/`quickstart.md`
  actualizados para reflejar esta decisión.
- [X] T017 [US2] En `../pos-backend/app/api/v1/inventory/service.py`, `generate_next_code(db)` +
  `resolve_or_create_by_code(db, code, **fields)`: si `code` coincide con un insumo existente del
  tenant, lo actualiza; si no coincide o viene vacío, crea uno nuevo asignándole un código
  secuencial automático cuando no se especificó (research.md D3). También se expuso
  `generate_next_code` desde `POST /items`/`PATCH /items/{id}` (ver T008) — no solo desde el
  import.
- [X] T018 [US2] En `import_.py` (no en `service.py` como se había bocetado — evita un import
  circular `service↔import_`, ver nota en plan.md/Structure Decision), `procesar_archivo_importacion(db,
  job, filas)`: pre-escanea códigos duplicados *dentro del mismo archivo* (ambas filas fallan,
  Edge case del spec — si no se detecta antes, la segunda fila se vería como una actualización
  legítima de la primera, ya committeada), recorre las filas con T016, acumula
  `created_count`/`updated_count`/`failed_count`/`errors` en el `job` y lo deja `finalizado` con
  `finished_at` al terminar.
- [X] T019 [US2] En `../pos-backend/app/celery_task.py`, `import_inventory_task(tenant_schema,
  job_id, filas)`: abre `with_db(tenant_schema)`, carga el job por id y llama a
  `procesar_archivo_importacion` (T018) — mismo patrón que `send_email_task`. Recibe `filas` ya
  parseadas (listas de valores planos), no el archivo binario, para que el argumento sea
  JSON-serializable (el serializador por defecto de Celery en este proyecto).
- [X] T020 [US2] En `../pos-backend/app/api/v1/inventory/router.py`, `POST /items/import`: parsea
  el `.xlsx` con `openpyxl` (síncrono), valida estructura (T015, `422` si falla, sin crear job); si
  ya hay un `InventoryImportJob` con `status='procesando'`, `409` (candado básico, sin vencimiento
  todavía — eso es T023); si no, crea el job (`total_rows` = filas de datos) y encola
  `import_inventory_task.delay(...)` (T019); responde `202` con el job (`InventoryImportJobResponse`,
  agregado a `schemas.py`).
- [X] T021 [US2] `../pos-backend/app/scripts/test_inventory_bulk_excel.py` ya cubre los puntos 2-7
  de `quickstart.md` §1 (invocando `procesar_archivo_importacion` directamente, sin `.delay()`,
  12 pruebas contra Postgres real tras el ajuste FR-006a): reimportar el mismo archivo exportado
  sin cambios → sin fallos, todo actualización; editar un costo → `updated_count == 1`; fila
  nueva con código vacío → `created_count` sube y se le asigna un código; 3 filas con errores
  distintos (costo no numérico, tipo inválido, factor ≤ 0) → 3 fallos con motivos distintos;
  estructura alterada → `422` sin crear job; dos códigos repetidos → ambas fallan; unidad/proveedor
  inexistentes se consolidan creándolos en MAYÚSCULA (4 pruebas nuevas, incluida la reactivación
  de un proveedor inactivo y el reconocimiento sin distinguir mayúsculas de la unidad del
  fixture). Además se agregó `ImportEndpointTests` (5 tests) en
  `test_inventory_export.py`, ejercitando `POST /items/import` de punta a punta vía `TestClient`
  con `import_inventory_task` mockeado (mismo patrón que `send_email_task` en
  `test_auth_forgot_password.py`): estructura válida → `202` + job creado + `.delay()` llamado;
  estructura alterada → `422` sin job; archivo vacío → `422`; candado básico → `409`; sin rol admin
  → `403`.
- [X] T022 [US2] Corrido el script (7/7 OK) y la suite de characterization completa
  (**1484 OK**, 0 fallas nuevas) tras T015-T021.

**Checkpoint**: el import funciona de punta a punta a nivel de backend — US1+US2 ya son el flujo
de ida y vuelta completo, aunque todavía sin interfaz ni sondeo de progreso.

---

## Phase 5: User Story 3 - Importar archivos grandes sin bloquear la aplicación (Priority: P2)

**Goal**: la interfaz confirma de inmediato que la importación quedó en proceso y queda libre
para seguir usándose; un segundo intento mientras hay una importación vigente se rechaza, incluso
si la anterior quedó "procesando" por una caída del worker.

**Independent Test**: subir un archivo desde la interfaz, confirmar que no bloquea la pantalla,
navegar a otra sección y volver, e intentar subir un segundo archivo mientras el primero sigue
"procesando" para confirmar el rechazo.

### Implementación para User Story 3

- [X] T023 [US3] En `service.py` (`find_blocking_import_job`), afinado el candado de T020 con el
  vencimiento de research.md D5: un job `procesando` con `started_at` de más de 30 minutos
  (`IMPORT_JOB_TIMEOUT`) se considera abandonado — se permite la nueva importación y el anterior
  se marca `interrumpido`. Encontrado y corregido un bug real al escribir el test: comparar
  `utc_now()` (aware) contra `started_at` (naive, columna `DateTime` sin timezone) lanzaba
  `TypeError` → 500 — se corrigió con `.replace(tzinfo=None)`, mismo patrón ya usado en
  `qr_context.py`/`plan_limits.py` para esta misma clase de columna.
- [X] T024 [US3] En `router.py`, `GET /items/import/current`: devuelve el job más reciente del
  tenant (o `null`), en la forma de respuesta de `contracts/api.md` (status, conteos,
  `has_errors`).
- [X] T025 [US3] Ampliado `test_inventory_bulk_excel.py` (quickstart.md §1 punto 9: interrupción a
  mitad de archivo, conserva lo aplicado — 8/8 OK) y `ImportEndpointTests` en
  `test_inventory_export.py` con el punto 8 (candado con vencimiento: job vencido no bloquea y
  queda `interrumpido`; `GET /items/import/current` devuelve el job correcto). Suite de
  characterization completa: **1486 OK**, 0 fallas nuevas.
- [X] T026 [P] [US3] En `../pos-heladeria/.../interfaces/inventory.interface.ts`, agregado
  `InventoryImportJob` (+ `code` en `InventoryItem`, espejo del backend); en
  `services/inventory.service.ts`, agregado `importItems(file)` (`POST /items/import`),
  `getCurrentImportJob()`, y (adelantados de T031 por ser triviales/simétricos)
  `getImportJob(id)`/`downloadImportErrors(id)`.
- [X] T027 [US3] Creado
  `../pos-heladeria/.../components/inventory-import-modal.component.ts`: selector de archivo,
  llama `importItems()`, muestra "en proceso" de inmediato sin bloquear, sondea con
  `startVisibleInterval` hasta que `status` deja de ser `procesando`, y (adelantado de T032) ya
  muestra el resumen final + botón de descarga de errores si `has_errors`.
- [X] T028 [US3] En `.../pages/inventory-page.component.ts`, agregado el botón "Importar Excel"
  junto a "Exportar Inventario"; se agregó `InventoryService.refreshItems()` (público, reutiliza
  la misma invalidación de query que ya usaba `submit()` internamente) para refrescar la tabla
  tras un import. Verificado: `ng build` de producción sin errores de tipos, `ng test` del módulo
  `inventory` 33/33 OK, suite Angular completa 1599 OK con las mismas 10 fallas en los mismos 6
  archivos ya documentados como baseline pre-existente (spec 084) — ninguna en `inventory` ni
  `cash-register`.

**Checkpoint**: subir un archivo grande no bloquea la pantalla y el candado resiste un worker
caído — US1+US2+US3 ya cubren el flujo completo con una UX robusta. El resumen final y la
descarga de errores (nominalmente US4) ya quedaron implementados aquí porque el modal los
necesitaba para ser útil por sí solo; US4 abajo solo agrega el endpoint `GET /items/import/{id}`
puntual que faltaba.

---

## Phase 6: User Story 4 - Ver el resultado de la importación y descargar el reporte de errores (Priority: P2)

**Goal**: al terminar una importación, el administrador ve cuántos insumos se crearon,
actualizaron y fallaron, y puede descargar el detalle de los fallidos.

**Independent Test**: completar una importación con una mezcla de filas exitosas y fallidas;
confirmar que el resumen en pantalla muestra los tres conteos correctos y que el archivo
descargable de errores contiene exactamente las filas que fallaron con su motivo.

### Implementación para User Story 4

- [X] T029 [US4] En `router.py`, `GET /items/import/{job_id}`: misma forma de respuesta que
  `GET /items/import/current` (T024), por id explícito; `404` si el job no existe para este
  tenant (`_get_import_job_or_404`, reutilizado también por T030).
- [X] T030 [US4] En `export.py`, `build_import_errors_excel(errors)`: reporte `.xlsx` con columnas
  Fila/Código/Motivo a partir de `InventoryImportJob.errors`; en `router.py`,
  `GET /items/import/{job_id}/errors` (`404` si `failed_count == 0`, sin llegar a generar el
  archivo).
- [X] T031 [P] [US4] Ya hecho en T026 (adelantado): `getImportJob(id)`/`downloadImportErrors(id)`
  en `inventory.service.ts`.
- [X] T032 [US4] Ya hecho en T027 (adelantado): el resumen final y el botón de descarga de
  errores ya estaban en `inventory-import-modal.component.ts` desde que se construyó el modal
  (era necesario para que US3 fuera un incremento útil por sí solo). Se agregaron 4 tests nuevos
  a `ImportEndpointTests` cubriendo `GET /items/import/{id}` (200 y 404) y
  `GET /items/import/{id}/errors` (200 con contenido correcto, y 404 sin filas fallidas).
  Suite de characterization completa: **1489 OK**, script backend **8/8 OK**, specs Angular de
  `inventory` **33/33 OK** — 0 fallas nuevas en ningún caso.

**Checkpoint**: las 4 historias completas — el flujo de ida y vuelta (exportar → editar →
importar) es simétrico, asíncrono, resiliente y con retroalimentación clara.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [ ] T033 Ejecutar `quickstart.md` completo de punta a punta: **parcial** — los 8 puntos del
  script backend, la regresión de characterization (**1489 OK**) y las specs Vitest de
  `inventory` (**33/33 OK**) ya están en verde (corridos repetidamente durante T011-T032, contra
  Postgres real, no solo SQLite); los 5 pasos manuales del frontend (`ng serve`, navegador real)
  siguen pendientes de este entorno sin GUI — mismo bloqueo ya documentado en la spec 108
  (T012/T015 de esa spec).
- [X] T034 [P] Verificado el invariante de `data-model.md` sin necesitar una prueba nueva — ya
  está cubierto por evidencia existente: `code` único **por tenant** (no global) se confirmó
  directamente en Postgres real — `pg_indexes` muestra `ux__inventory_items__code` creado dentro
  del esquema `heladeria3` específicamente (vía `@for_each_tenant_schema`, T004), exactamente el
  mismo mecanismo que ya aísla `inventory_items.name` entre tenants hoy, sin ninguna columna
  `tenant_id` explícita. `errors` solo tiene contenido cuando `failed_count > 0` ya lo confirman
  `test_descarga_de_errores_404_sin_filas_fallidas` (vacío → 404) y
  `test_descarga_de_errores_contiene_fila_codigo_y_motivo` (con contenido → 200 con el detalle).
- [X] T035 [P] Corrido `npx ng test --watch=false --include='src/app/modules/inventory/**/*.spec.ts'`
  en `../pos-heladeria` tras T026-T032: **33/33 OK**. También corrida la suite Angular completa:
  **1599 OK**, con las mismas 10 fallas en los mismos 6 archivos ya documentados como baseline
  pre-existente (spec 084) — ninguna en `inventory`.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias. T001 (registro de anomalías) **bloquea** toda
  implementación de código (Puerta G1, Principio II); T002/T003 (ramas) bloquean tocar código en
  cada repo (Principio XIV).
- **Foundational (Phase 2)**: depende de Phase 1. **Bloquea** las 4 historias — todas necesitan la
  columna `code`, la tabla de jobs y/o la plantilla compartida de T007.
- **User Stories (Phase 3-6)**: todas dependen de Phase 2 completa. Entre ellas:
  - US1 (T011-T014) no depende de US2/US3/US4 en código — es desplegable sola.
  - US2 (T015-T022) no depende de US1 en código, pero sí de T007/T009 (Foundational).
  - US3 (T023-T028) depende de US2: el candado que afina (T023) y el `GET /items/import/current`
    que sondea (T024) solo tienen sentido sobre el `POST /items/import` y el `InventoryImportJob`
    que US2 ya construyó.
  - US4 (T029-T032) depende de US2 (el job) y reutiliza la forma de respuesta que US3 ya definió
    en T024 — en la práctica se implementa después de US3, aunque su valor de negocio es
    independiente.
- **Polish (Phase 7)**: depende de que las 4 historias estén completas.

### Parallel Opportunities

- T002 y T003 en paralelo (repos distintos).
- T005 y T006 en paralelo (archivos de modelo distintos); ambos pueden ir en paralelo con T007-T009
  si dos personas trabajan la fase Foundational.
- T008 en paralelo con T007 (mismo archivo `schemas.py` pero secciones independientes — en la
  práctica, un solo desarrollador las hace en la misma sesión de edición).
- T026 en paralelo con el trabajo de backend de US3 (T023-T025) — interfaces/servicio del frontend
  no dependen de la implementación interna del candado.
- T031 en paralelo con T029/T030 (mismo motivo que T026).
- T033, T034, T035 en paralelo entre sí al final.

---

## Parallel Example: Foundational

```bash
# T005 y T006 tocan archivos de modelo distintos:
Task: "Crear InventoryImportJob en ../pos-backend/app/models/inventory_import_job.py"
Task: "Agregar `code` a InventoryItem en ../pos-backend/app/models/inventory_item.py"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Completar Phase 1 (Puerta G1 — sin la entrada A-123 no se puede avanzar) y Phase 2
   (Foundational — modelo de datos y plantilla).
2. Completar Phase 3 (User Story 1): la exportación ya usa la plantilla única.
3. **Detenerse y validar**: correr T014 de forma independiente.
4. Esto ya entrega valor (una exportación más completa y lista para servir de plantilla), aunque
   el import todavía no exista.

### Incremental Delivery

1. Setup + Foundational → modelo de datos y plantilla listos.
2. User Story 1 → exportación con la plantilla única → validar independientemente.
3. User Story 2 → import funcional de punta a punta a nivel de backend → validar
   independientemente (ya es el flujo de ida y vuelta completo, aunque sin interfaz todavía).
4. User Story 3 → no bloquea la interfaz + candado resiliente → validar independientemente.
5. User Story 4 → resumen en pantalla + descarga de errores → validar independientemente.
6. Polish → `quickstart.md` de punta a punta.

## Notes

- El orden sugerido arriba (P1 → P1 → P2 → P2) es también el orden de implementación recomendado
  para un solo desarrollador — cada fase deja un incremento desplegable y verificable por sí
  solo, sin necesitar revertir ningún contrato de API ya entregado por una fase anterior (el
  `POST /items/import` responde `202` con `job_id` desde US2, igual que en `contracts/api.md` —
  US3/US4 no cambian esa forma, solo agregan los `GET` que faltaban).
- Los commits se hacen solo bajo pedido explícito del usuario, en unidades pequeñas y lógicas, en
  inglés, sin ninguna marca de autoría de IA (Principio XV) — aplica a `pos-backend` y
  `pos-heladeria`, no a este repositorio de specs.
