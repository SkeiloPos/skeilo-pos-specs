---

description: "Task list template for feature implementation"
---

# Tasks: Exportación e importación masiva de la carta de productos vía Excel

**Input**: Design documents from `/specs/143-exportacion-importacion-carta-menu/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/api.md, quickstart.md

**Tests**: El spec no pide TDD explícito; la verificación obligatoria (Principio X) es el script
autoejecutable `app/scripts/test_products_bulk_excel.py` (mismo patrón que spec 109) + la
regresión de characterization tests + specs Vitest de `products`. No se generan tareas de test
unitario aisladas aparte de ese script y esas specs.

**Organization**: Tareas agrupadas por historia de usuario (US1 export, US2 import, US3
reintento), según `spec.md`. Todas las rutas son relativas a `../pos-backend/` o
`../pos-heladeria/` (repos hermanos de `pos-specs`).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Puede ejecutarse en paralelo (archivos distintos, sin dependencias)
- **[Story]**: US1 (exportar), US2 (importar), US3 (reintentar sin duplicar)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Rama de trabajo, sin inicialización de proyecto (ambos repos ya existen y están en
producción).

- [X] T001 Crear rama `feat/143-exportacion-importacion-carta-menu` en `../pos-backend` y en
      `../pos-heladeria`, partiendo de la rama actual en cada repo (Principio XIV)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Modelo de datos y plantilla de columnas compartida — bloquea toda historia porque
export e import (US1/US2/US3) dependen de `products.code`, `ProductImportJob` y las constantes de
cabeceras.

**⚠️ CRITICAL**: Ninguna historia puede empezar hasta que esta fase esté completa.

- [X] T002 Agregar `code: Mapped[str]` a `Product` en `../pos-backend/app/models/product.py`
      (`String(20)`, `NOT NULL`, índice único por tenant) — mismo patrón que
      `InventoryItem.code` (spec 109)
- [X] T003 [P] Crear modelo `ProductImportJob` en
      `../pos-backend/app/models/product_import_job.py` (columnas según `data-model.md`:
      `id`, `status`, `file_name`, `started_by_user_id`, `started_at`, `finished_at`,
      `total_rows`, `created_count`, `updated_count`, `failed_count`, `errors` JSONB) — misma
      forma que `InventoryImportJob`, con `errors` incluyendo `hoja` además de `fila`/`codigo`/
      `motivo`
- [X] T004 Crear migración Alembic `<hash>_product_code_import_jobs.py` en
      `../pos-backend/alembic/versions/`, vía `@for_each_tenant_schema` (mismo patrón que
      `42dc063d8185_inventory_code_import_jobs.py`): 1) agregar `products.code` como `NULL`;
      2) backfillear con secuencial por tenant ordenado alfabéticamente por `name`
      (`ROW_NUMBER() OVER (ORDER BY name)`, formato 4 dígitos); 3) alterar a `NOT NULL`;
      4) agregar índice único; 5) crear tabla `product_import_jobs`. Rollback: quitar índice
      único y columna `code`, dropear la tabla
      (depende de T002, T003)
- [X] T005 [P] Agregar `PRODUCT_TEMPLATE_HEADERS`, `VARIANT_TEMPLATE_HEADERS`,
      `RECIPE_TEMPLATE_HEADERS`, `TOPPING_TEMPLATE_HEADERS` en
      `../pos-backend/app/api/v1/products/schemas.py` — una constante por hoja, con el orden y
      nombres de columna exactos de `data-model.md` (research.md D8); fuente única que
      `export.py` e `import_.py` importan, ninguno repite su propia lista
- [X] T006 [P] Agregar `code: str` a `ProductCreate`/`ProductResponse` (y los esquemas de
      `ProductImportJob`/reporte de errores: `ProductImportJobResponse` con `has_errors`) en
      `../pos-backend/app/api/v1/products/schemas.py`
- [X] T007 [P] Agregar `generate_next_product_code()` en
      `../pos-backend/app/api/v1/products/service.py` — secuencial con cero a la izquierda,
      único por tenant, mismo patrón que el generador de código de `InventoryItem` (spec 109)

**Checkpoint**: Modelo de datos y plantilla de columnas listos — US1 puede empezar.

---

## Phase 3: User Story 1 - Exportar la carta completa a Excel (Priority: P1) 🎯 MVP

**Goal**: Un administrador descarga un `.xlsx` con 4 hojas (Productos, Presentaciones y precios,
Receta, Adiciones) reflejando fielmente la carta configurada.

**Independent Test**: Exportar la carta de un negocio con productos, variantes, receta y
adiciones ya configurados y verificar que el archivo descargado contiene esa información
distribuida correctamente en las 4 hojas, sin que exista aún ninguna ruta de import.

### Implementation for User Story 1

- [X] T008 [US1] Implementar `build_products_excel(session)` en
      `../pos-backend/app/api/v1/products/export.py` — genera el `Workbook` en memoria con las 4
      hojas usando las constantes de T005, en el orden Productos → Presentaciones y precios →
      Receta → Adiciones; incluye todos los productos del tenant (activos e inactivos); un
      producto sin receta/adiciones solo genera filas en Productos y en Presentaciones y precios
      (Historia 1, escenario 2); una carta vacía entrega las 4 hojas con encabezados sin filas
      (Historia 1, escenario 3) (depende de T002, T005)
- [X] T009 [US1] Agregar `GET /products/export` en
      `../pos-backend/app/api/v1/products/router.py` — protegido con `require_tenant_admin`
      (FR-016), responde el `.xlsx` de T008 como descarga (depende de T008)
- [X] T010 [P] [US1] Crear `../pos-backend/app/scripts/test_products_bulk_excel.py` (mismo
      patrón que `test_inventory_bulk_excel.py`) cubriendo los puntos 1 del quickstart.md
      (exportar carta con y sin receta/adiciones, carta vacía)
- [X] T011 [P] [US1] Agregar `code` a `ProductInterface` en
      `../pos-heladeria/src/app/modules/products/interfaces/product.interface.ts`
- [X] T012 [US1] Agregar `exportProducts()` en
      `../pos-heladeria/src/app/modules/products/services/product.service.ts` — descarga el
      `.xlsx` de `GET /products/export` (depende de T011)
- [X] T013 [US1] Agregar botón "Exportar carta" en
      `../pos-heladeria/src/app/modules/products/pages/products-page.component.ts`, visible solo
      para el permiso administrativo de carta (depende de T012)

**Checkpoint**: La exportación es completamente funcional e independientemente verificable
(script backend punto 1 + uso manual del botón).

---

## Phase 4: User Story 2 - Importar cambios masivos a la carta desde Excel (Priority: P2)

**Goal**: Un administrador sube un `.xlsx` (exportado o editado) y el sistema crea/actualiza
productos, presentaciones/precios, receta y adiciones, fila por fila, con seguimiento de progreso
y reporte de errores descargable.

**Independent Test**: Tomar un archivo exportado (US1), modificar algunas filas (precio, nueva
fila de producto, nueva fila de receta), subirlo, y verificar que los cambios se reflejan sin
afectar lo que no se tocó.

### Implementation for User Story 2

- [X] T014 [US2] Implementar `validar_estructura(workbook)` en
      `../pos-backend/app/api/v1/products/import_.py` — valida que cada hoja presente (de las 4,
      un subconjunto también es válido) corresponda en cabeceras y orden de columnas a las
      constantes de T005; lanza el detalle de qué hoja/columna no corresponde (FR-010, edge case
      de hojas faltantes/renombradas/columnas reordenadas) (depende de T005)
- [X] T015 [US2] Implementar `resolve_or_create_category(session, nombre)` y
      `resolve_or_create_presentation(session, nombre)` en
      `../pos-backend/app/api/v1/products/import_.py` — búsqueda case-insensitive contra
      `categories.name`/`presentations.name` del tenant sin normalizar a mayúscula, crea si no
      hay coincidencia (con el texto exacto del archivo), reactiva si la coincidencia está
      inactiva, falla la fila si hay más de una coincidencia (research.md D5)
- [X] T016 [US2] Implementar `validar_y_aplicar_fila_producto(session, fila, codigos_del_archivo)`
      en `../pos-backend/app/api/v1/products/import_.py` — resuelve creación (código vacío o
      nuevo, vía T007) vs. actualización (código existente) directamente sobre `Product` (no vía
      `ProductService`, research.md D1); valida Nombre y Categoría obligatorios (usa T015), Tipo
      de preparación en {Preparado, Empacado}; en actualización, una columna booleana vacía
      conserva el valor existente (nunca infiere `false`); detecta código duplicado dentro del
      mismo archivo → todas las filas afectadas fallan (FR-011) (depende de T002, T007, T015)
- [X] T017 [US2] Implementar `validar_y_aplicar_fila_presentacion(session, fila, productos_del_archivo)`
      en `../pos-backend/app/api/v1/products/import_.py` — resuelve Código de producto contra
      productos ya creados en esta importación (hoja Productos, mismo archivo) o ya existentes en
      el sistema, falla si no existe en ninguno (edge case); resuelve Presentación vía T015;
      combinación producto+presentación identifica variante existente (actualiza SKU/Nombre
      comercial/Precio/Orden/Activo) o crea una nueva directamente sobre `ProductVariant`; valida
      Precio numérico ≥ 0 (falla si no); reasigna Orden en colisión igual que
      `_assign_display_orders` en vez de fallar la fila (depende de T015, T016)
- [X] T018 [US2] Implementar `validar_y_aplicar_fila_receta(session, fila, variantes_del_archivo)`
      en `../pos-backend/app/api/v1/products/import_.py` — resuelve Código de producto +
      Presentación contra variantes creadas en esta importación (hoja Presentaciones, mismo
      archivo) o ya existentes, falla si no existe (edge case); resuelve Insumo por nombre o
      código contra el inventario **ya existente** del tenant, nunca crea uno nuevo, falla si no
      existe (FR-008); valida Cantidad numérica > 0; combinación variante+insumo identifica ítem
      de receta existente (actualiza cantidad) o crea uno nuevo directamente sobre `RecipeItem`
      (depende de T017)
- [X] T019 [US2] Implementar `validar_y_aplicar_fila_adicion(session, fila, productos_del_archivo)`
      en `../pos-backend/app/api/v1/products/import_.py` — resuelve ambos códigos de producto
      contra productos creados en esta importación (hoja Productos, mismo archivo) o ya
      existentes, falla si alguno no existe (edge case); valida que el producto adición tenga
      `is_topping=true` (FR-009) y que no sea el mismo código del producto que lo ofrece (edge
      case); combinación producto+producto-adición identifica relación existente o crea una
      nueva directamente sobre `ProductTopping` (depende de T016)
- [X] T020 [US2] Implementar `import_products_task(tenant_schema, job_id, contenido_archivo)` en
      `../pos-backend/app/celery_task.py` — dentro del `schema_translate_map` del tenant, procesa
      las hojas presentes en el orden Productos → Presentaciones y precios → Receta → Adiciones
      (FR-007) invocando T016-T019 fila por fila con commit independiente por fila (nunca
      transacción de archivo completo); actualiza `created_count`/`updated_count`/`failed_count`/
      `errors` (con `hoja`/`fila`/`codigo`/`motivo`) en `ProductImportJob` conforme avanza; marca
      `status='finalizado'` y `finished_at` al terminar, o `status='interrumpido'` si se detiene a
      mitad de proceso dejando lo ya aplicado intacto (edge case de interrupción) (depende de
      T014, T016, T017, T018, T019)
- [X] T021 [US2] Agregar `POST /products/import` en
      `../pos-backend/app/api/v1/products/router.py` — protegido con `require_tenant_admin`;
      recibe `.xlsx` como `multipart/form-data`; valida estructura de forma síncrona vía T014
      (422 inmediato sin crear job si falla); verifica que no haya un job `procesando` vigente no
      vencido (FR-012a, research.md D7, mismo `IMPORT_JOB_TIMEOUT` que inventario) → 409 con el id
      del job en curso si lo hay, marcando el vencido como `interrumpido` si corresponde; crea la
      fila de `ProductImportJob` (`total_rows` = suma de filas de hojas presentes) y encola T020;
      responde `202` con `job_id` (depende de T014, T020)
- [X] T022 [P] [US2] Agregar `GET /products/import/current` y `GET /products/import/{job_id}` en
      `../pos-backend/app/api/v1/products/router.py` — devuelve el job más reciente del tenant (o
      por id), forma de respuesta con `has_errors = failed_count > 0` (contracts/api.md); `null`
      si nunca se ha corrido ninguno; 404 si el `job_id` no existe para el tenant (depende de T003)
- [X] T023 [P] [US2] Agregar `GET /products/import/{job_id}/errors` en
      `../pos-backend/app/api/v1/products/router.py` — genera y descarga un `.xlsx` con una fila
      por cada fila fallida (hoja, fila original, código, motivo); 404 si el job no tiene filas
      fallidas (FR-013) (depende de T003)
- [X] T024 [US2] Extender `../pos-backend/app/scripts/test_products_bulk_excel.py` con los puntos
      2-8, 10, 11, 12, 14, 15, 16 del quickstart.md (reimportar sin editar no duplica; editar
      precio actualiza; fila nueva sin código crea; insumo inexistente falla sin afectar el resto;
      producto-adición sin `is_topping` falla; progreso consultable durante el proceso; reporte de
      errores descargable; códigos duplicados en el archivo fallan ambas filas; presentación con
      código de producto inexistente falla; adición con el mismo código del producto que la ofrece
      falla; archivo con estructura inválida → 422 sin job; archivo con solo hoja Productos es
      válido; segundo import con uno `procesando` vigente → 409) (depende de T021, T022, T023)
- [X] T025 [P] [US2] Agregar `ProductImportJob`/`ImportRowError` a
      `../pos-heladeria/src/app/modules/products/interfaces/product.interface.ts`
- [X] T026 [US2] Agregar `importProducts()`, `getCurrentImportJob()`, `downloadImportErrors()` en
      `../pos-heladeria/src/app/modules/products/services/product.service.ts` (depende de T025)
- [X] T027 [US2] Crear `../pos-heladeria/src/app/modules/products/components/product-import-modal.component.ts`
      — subir archivo, sondeo de progreso reutilizando `startVisibleInterval`
      (`app/core/realtime/visible-interval.ts`, mismo patrón que
      `inventory-import-modal.component.ts`), resumen final (creados/actualizados/fallidos,
      adaptado a 4 hojas) con botón de descarga de errores visible solo si `has_errors` es
      verdadero (depende de T026)
- [X] T028 [US2] Agregar botón "Importar Excel" en
      `../pos-heladeria/src/app/modules/products/pages/products-page.component.ts`, que abre T027,
      visible solo para el mismo permiso administrativo que "Exportar carta" (FR-016) (depende de
      T013, T027)

**Checkpoint**: Export + import funcionan de punta a punta; US1 y US2 son verificables juntas vía
el script backend completo y el flujo manual exportar → editar → importar.

---

## Phase 5: User Story 3 - Corregir y reintentar una importación con errores (Priority: P3)

**Goal**: Reimportar un archivo corregido sin duplicar lo ya aplicado en un intento anterior.

**Independent Test**: Realizar una importación con algunas filas inválidas, corregir únicamente
esas filas en el archivo y reimportar, verificando que lo ya aplicado no se duplica ni se altera.

**Nota**: esta historia no requiere código nuevo — la idempotencia por código (T016, T017, T018,
T019 ya resuelven por código/combinación existente antes de crear) es la que la garantiza. La
única tarea restante es verificarlo explícitamente.

### Implementation for User Story 3

- [X] T029 [US3] Extender `../pos-backend/app/scripts/test_products_bulk_excel.py` con el punto 9
      del quickstart.md: una importación previa con filas de producto creadas correctamente y
      otras fallidas, reimportar el mismo archivo con las filas corregidas → los productos ya
      creados no se duplican (identificados por código) y las filas corregidas se aplican
      (FR-014) (depende de T024)

**Checkpoint**: Las 3 historias de usuario son verificables de forma independiente.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Verificación final obligatoria (Principio X) y regresión de lo no relacionado.

- [X] T030 Correr `./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`
      desde `../pos-backend` y confirmar que sigue en verde (sin cambios esperados — funcionalidad
      enteramente nueva) — 2034/2034 en verde
- [X] T031 [P] Correr `npx ng test --watch=false --include='src/app/modules/products/**/*.spec.ts'`
      desde `../pos-heladeria` y confirmar que pasa — 107/107 en verde; `npx tsc --noEmit` sin
      errores en todo el proyecto. La corrida completa de `ng test` (todos los módulos) muestra 9
      archivos fallando en `tables`/`pos-terminal.store`, no tocados por esta spec — coincide con
      la flakiness ya documentada de la suite completa (no por módulo)
- [~] T032 Ejecutar los 5 pasos manuales de uso del frontend descritos en `quickstart.md`
      (exportar/editar/importar, progreso visible al navegar y volver, resumen con/sin botón de
      errores, error inmediato de estructura) contra `ng serve` — NO ejecutado interactivamente en
      este entorno (agente sin navegador); verificado en su lugar a nivel de contrato HTTP
      (`validar_estructura`, `procesar_archivo_importacion`, registro de rutas sin colisión) vía
      `test_products_bulk_excel.py`. Pendiente de una pasada manual real en `ng serve` antes de
      considerar la Historia 2 completamente verificada en el navegador.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias — puede empezar de inmediato
- **Foundational (Phase 2)**: depende de Setup — bloquea todas las historias
- **US1 (Phase 3)**: depende de Foundational — sin dependencia de otras historias
- **US2 (Phase 4)**: depende de Foundational; reutiliza el botón "Exportar carta" de T013 como
  referencia de ubicación en pantalla, pero sus endpoints/tarea Celery no dependen del código de
  US1
- **US3 (Phase 5)**: depende de US2 (T024) — reusa el mismo script de verificación
- **Polish (Phase 6)**: depende de que US1, US2 y US3 estén completas

### Within Each User Story

- Modelos/constantes antes de lógica de validación de fila
- Lógica de validación de fila antes de la tarea Celery que la orquesta
- Tarea Celery antes del endpoint que la encola
- Backend antes de los cambios de frontend que lo consumen

### Parallel Opportunities

- T003 y T002 en paralelo (archivos distintos); T004 depende de ambos
- T005, T006, T007 en paralelo entre sí (archivos/funciones distintas dentro de Foundational)
- T010, T011 en paralelo dentro de US1
- T022, T023 en paralelo entre sí dentro de US2 (ambos son rutas nuevas en `router.py` sin
  dependencia mutua, aunque compartan archivo conviene revisarlos en la misma sesión de edición)
- T025 en paralelo con el resto de US2 backend

---

## Parallel Example: Foundational

```bash
# Lanzar juntas (archivos/funciones distintas):
Task: "Agregar code a Product en app/models/product.py"
Task: "Crear modelo ProductImportJob en app/models/product_import_job.py"
Task: "Agregar PRODUCT_TEMPLATE_HEADERS/VARIANT_TEMPLATE_HEADERS/RECIPE_TEMPLATE_HEADERS/TOPPING_TEMPLATE_HEADERS en schemas.py"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Completar Phase 1: Setup
2. Completar Phase 2: Foundational (bloquea todo)
3. Completar Phase 3: US1 (exportar)
4. **Validar**: correr el script backend punto 1 + probar el botón "Exportar carta" manualmente
5. Esto ya entrega valor (respaldo/auditoría de la carta) aunque US2 no exista todavía

### Incremental Delivery

1. Setup + Foundational → base lista
2. US1 → exportar funcionando → demo (MVP)
3. US2 → importar funcionando (depende del formato de US1 ya validado) → demo
4. US3 → reintento sin duplicar verificado → demo
5. Polish → regresión completa + validación manual final

## Notes

- [P] = archivos o funciones distintas, sin dependencia entre sí
- Cada fila de import hace su propio commit independiente (FR-005a, interrupción segura) — ya
  reflejado en T020
- El import nunca reutiliza `ProductService` (research.md D1) — T016-T019 operan directamente
  sobre los modelos
- Commits solo bajo pedido explícito del usuario, en inglés, sin marca de autoría de IA
  (Principio XV)
