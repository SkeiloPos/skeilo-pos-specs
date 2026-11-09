---

description: "Task list template for feature implementation"
---

# Tasks: Fusión de las hojas Productos y Presentaciones/precios en el Excel de la carta

**Input**: Design documents from `/specs/155-fusion-hojas-productos-precios-excel/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/api.md, quickstart.md (todos presentes)

**Tests**: Se incluyen — quickstart.md define un script autoejecutable con casos explícitos por historia (Principio X, verificación obligatoria).

**Organization**: Tasks agrupadas por historia de usuario. Todas las tareas tocan únicamente `../pos-backend/app/api/v1/products/{schemas.py,export.py,import_.py}`, `../pos-backend/app/scripts/test_products_bulk_excel.py` y `../pos-heladeria/src/app/modules/products/components/product-import-modal.component.ts` (plan.md, Structure Decision) — ningún archivo nuevo.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Puede ejecutarse en paralelo (archivos distintos, sin dependencias)
- **[Story]**: Historia de usuario a la que pertenece (US1, US2, US3)

## Path Conventions

Rutas relativas a `pos-specs/` (repos hermanos): `../pos-backend/...`, `../pos-heladeria/...`.

---

## Phase 1: Setup

**Purpose**: Preparación de rama de trabajo (Principio XIV)

- [X] T001 Crear la rama `feat/155-fusion-hojas-productos-precios-excel` en `../pos-backend` y en `../pos-heladeria`, desde la rama actual

**Checkpoint**: Rama lista en ambos repositorios.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Plantilla de columnas fusionada y mapa de hojas esperadas — bloquea export e import (research.md D1/D5)

**⚠️ CRITICAL**: Ninguna historia puede implementarse antes de completar esta fase.

- [X] T002 En `../pos-backend/app/api/v1/products/schemas.py`, eliminar `PRODUCT_TEMPLATE_HEADERS` y `VARIANT_TEMPLATE_HEADERS` y reemplazarlos por una sola constante `PRODUCT_AND_VARIANT_TEMPLATE_HEADERS` con las 16 columnas en el orden de `data-model.md` (10 de producto + 6 de presentación, renombrando la séptima a "Activo de la presentación" para evitar colisión con la columna 6 "Activo", research.md D1)
- [X] T003 En `../pos-backend/app/api/v1/products/schemas.py`, actualizar `PRODUCT_IMPORT_SHEETS` a 3 claves en orden: `"Productos y precios"` → `PRODUCT_AND_VARIANT_TEMPLATE_HEADERS`, `"Receta"` → `RECIPE_TEMPLATE_HEADERS` (sin cambios), `"Adiciones"` → `TOPPING_TEMPLATE_HEADERS` (sin cambios) — depende de T002

**Checkpoint**: La plantilla fusionada y el mapa de hojas esperadas existen; `validar_estructura` (sin tocar su código) ya rechazará por sí sola cualquier archivo con hojas "Productos"/"Presentaciones y precios" (FR-008, research.md D5) en cuanto las historias de import se implementen.

---

## Phase 3: User Story 1 - Asignar precios sin cambiar de hoja (Priority: P1) 🎯 MVP

**Goal**: El archivo exportado trae una sola hoja "Productos y precios" con los datos de producto y de cada presentación en la misma fila.

**Independent Test**: Exportar la carta de un negocio con varios productos/presentaciones y verificar que el archivo tiene 3 hojas, con "Productos y precios" fusionada, sin necesitar que el import ya funcione.

### Tests for User Story 1

- [X] T004 [P] [US1] En `../pos-backend/app/scripts/test_products_bulk_excel.py`, reescribir `test_export_incluye_las_4_hojas_con_y_sin_receta` (y renombrarlo a `test_export_incluye_las_3_hojas_con_y_sin_receta`) para verificar `wb.sheetnames == ["Productos y precios", "Receta", "Adiciones"]`, que un producto con tres presentaciones genera tres filas en esa hoja con los datos de producto repetidos en cada una, y que las 16 columnas de `data-model.md` están presentes en ese orden
- [X] T005 [P] [US1] En `../pos-backend/app/scripts/test_products_bulk_excel.py`, reescribir `test_export_carta_vacia_entrega_4_hojas_sin_filas` (renombrar a `..._3_hojas_sin_filas`) para verificar las 3 hojas con encabezados y sin filas de datos cuando el tenant no tiene productos

### Implementation for User Story 1

- [X] T006 [US1] En `../pos-backend/app/api/v1/products/export.py`, reescribir `build_products_excel`: crear una sola hoja `"Productos y precios"` (en vez de `"Productos"` + `"Presentaciones y precios"`) usando `PRODUCT_AND_VARIANT_TEMPLATE_HEADERS`; por cada `product.variants`, escribir una fila con las 10 columnas de producto seguidas de las 6 de esa variante (SKU, Nombre comercial, Precio, Orden, Activo de la presentación); mantener las hojas "Receta" y "Adiciones" sin cambios, en ese orden — depende de T002 (Foundational)
- [X] T007 [US1] Actualizar el import de `export.py` para traer `PRODUCT_AND_VARIANT_TEMPLATE_HEADERS` en vez de `PRODUCT_TEMPLATE_HEADERS`/`VARIANT_TEMPLATE_HEADERS` desde `schemas.py` — depende de T006

**Checkpoint**: `GET /products/export` entrega un `.xlsx` de 3 hojas con "Productos y precios" fusionada; verificable de forma independiente del import.

---

## Phase 4: User Story 2 - Editar precios masivamente desde la hoja fusionada (Priority: P2)

**Goal**: Reimportar la hoja fusionada actualiza precios de presentaciones existentes y crea productos nuevos junto con su presentación en una sola fila, sin reabrir la detección de inconsistencia (US3).

**Independent Test**: Tomar un archivo exportado con el nuevo formato, editar el precio de varias filas, reimportar y verificar que se actualiza sin afectar el resto; también verificar que una fila con código inexistente crea el producto y su presentación juntos.

### Tests for User Story 2

- [X] T008 [P] [US2] En `../pos-backend/app/scripts/test_products_bulk_excel.py`, actualizar los helpers `_fila_producto`/`_fila_variante` (fusionarlos en un único `_fila_producto_y_precio(producto, categoria_nombre, variante, presentacion_nombre)` que devuelva las 16 columnas) y todos los llamadores existentes (`test_reimportar_sin_editar_no_duplica`, `test_editar_precio_actualiza_la_variante`, `test_fila_producto_codigo_vacio_crea_con_codigo_automatico`, `test_filas_ausentes_del_archivo_no_se_eliminan`) para usar la hoja única `"Productos y precios"` con filas de 16 columnas
- [X] T009 [P] [US2] En `../pos-backend/app/scripts/test_products_bulk_excel.py`, añadir `test_fila_con_codigo_inexistente_crea_producto_y_presentacion` (Historia 2, escenario 2: una fila con código nuevo crea producto + presentación + precio en una sola operación)
- [X] T010 [P] [US2] En `../pos-backend/app/scripts/test_products_bulk_excel.py`, eliminar `test_codigos_duplicados_en_el_archivo_fallan_ambas` (ya no aplica: varias filas con el mismo código es ahora el caso normal de varias presentaciones, no un error) y `test_presentacion_con_codigo_inexistente_falla` (se fusiona con la validación de fila única; cubierto por T008) — ajustar `main()` en consecuencia
- [X] T011 [P] [US2] En `../pos-backend/app/scripts/test_products_bulk_excel.py`, reescribir `test_estructura_alterada_no_crea_job`, `test_columnas_en_orden_distinto_falla_estructura` y `test_archivo_con_solo_hoja_productos_es_valido` (renombrar a `..._solo_hoja_productos_y_precios_es_valido`) contra `PRODUCT_AND_VARIANT_TEMPLATE_HEADERS`/`"Productos y precios"`, y añadir `test_archivo_formato_4_hojas_no_es_valido` que pasa `{"Productos": [...], "Presentaciones y precios": [...]}` a `validar_estructura` y verifica que devuelve problemas (SC-004, research.md D5)

### Implementation for User Story 2

- [X] T012 [US2] En `../pos-backend/app/api/v1/products/import_.py`, actualizar `_ORDEN_HOJAS` a `("Productos y precios", "Receta", "Adiciones")` — depende de T003 (Foundational)
- [X] T013 [US2] En `../pos-backend/app/api/v1/products/import_.py`, fusionar `validar_y_aplicar_fila_producto` y `validar_y_aplicar_fila_presentacion` en una sola función `validar_y_aplicar_fila_producto_y_presentacion(db, fila)` que: valide y cree/actualice el producto con las columnas 1-10 (mismo criterio de cada una ya existente, incluyendo conservar booleanos vacíos en actualización), luego valide que Presentación (col. 11) y Precio (col. 14) no estén vacíos (FR-004; error explícito si falta alguno) y cree/actualice la variante con las columnas 11-16, todo dentro del mismo `try/except ValueError` con un único `db.commit()`/`db.rollback()` por fila — depende de T012
- [X] T014 [US2] En `../pos-backend/app/api/v1/products/import_.py`, actualizar `_VALIDADORES` a `{"Productos y precios": validar_y_aplicar_fila_producto_y_presentacion, "Receta": validar_y_aplicar_fila_receta, "Adiciones": validar_y_aplicar_fila_adicion}` — depende de T013
- [X] T015 [US2] En `../pos-backend/app/api/v1/products/import_.py`, eliminar de `procesar_archivo_importacion` el bloque de detección de `duplicados` específico de la antigua hoja `"Productos"` (ya no es un error que dos filas compartan código; ver US3 para la nueva regla de consistencia) — depende de T014

**Checkpoint**: Reimportar la hoja fusionada actualiza precios y crea productos+presentación en una fila, con el archivo de 4 hojas de la 143 ya rechazado por estructura (T012-T014 reutilizan T002/T003).

---

## Phase 5: User Story 3 - Detectar datos de producto inconsistentes entre filas (Priority: P3)

**Goal**: Si dos filas del mismo código de producto difieren en algún dato de producto, todas las filas de ese código se reportan como error y ninguna se aplica.

**Independent Test**: Armar un archivo con dos filas del mismo código que difieren en el nombre y verificar que ambas se reportan como error, mientras otras filas sin ese problema se aplican con normalidad.

### Tests for User Story 3

- [X] T016 [P] [US3] En `../pos-backend/app/scripts/test_products_bulk_excel.py`, añadir `test_filas_mismo_codigo_con_datos_de_producto_distintos_fallan_todas` (Historia 3, escenario 1: dos filas del mismo código con `Nombre` distinto → ambas en `job.errors` con motivo de inconsistencia, `job.created_count == job.updated_count == 0` para ese código, y una fila de otro producto sin ese problema se aplica con normalidad)
- [X] T017 [P] [US3] En `../pos-backend/app/scripts/test_products_bulk_excel.py`, añadir `test_filas_mismo_codigo_corregidas_se_aplican` (Historia 3, escenario 2: las mismas filas con los datos de producto ya coincidentes se aplican sin error)
- [X] T018 [P] [US3] En `../pos-backend/app/scripts/test_products_bulk_excel.py`, añadir `test_fila_con_presentacion_o_precio_vacio_falla` (edge case FR-004: datos de producto completos pero Presentación o Precio vacíos → fila fallida, no se crea el producto)
- [X] T019 [P] [US3] En `../pos-backend/app/scripts/test_products_bulk_excel.py`, añadir `test_reimportar_archivo_recien_exportado_no_duplica` (SC-005: exportar, reimportar sin cambios, verificar cero filas fallidas y cero duplicados) y actualizar `main()` para incluir todos los casos nuevos de T004-T019

### Implementation for User Story 3

- [X] T020 [US3] En `../pos-backend/app/api/v1/products/import_.py`, añadir una función `_detectar_inconsistencias(filas: list[list[Any]]) -> dict[str, str]` que agrupe las filas de `"Productos y precios"` por código (columna 1, ignorando código vacío, research.md D3), compare entre todas las filas de cada grupo con más de una fila los valores normalizados (mismo *trim*/lower que ya usan `_parse_bool`/los parsers de columna) de las columnas 2-10, y devuelva un `dict` de `código -> motivo` (identificando la(s) columna(s) que difiere(n)) para cada grupo inconsistente — depende de T003 (Foundational)
- [X] T021 [US3] En `../pos-backend/app/api/v1/products/import_.py`, dentro de `procesar_archivo_importacion`, antes de iterar las filas de `"Productos y precios"`, llamar a `_detectar_inconsistencias` sobre esa hoja; para cada fila cuyo código esté en el resultado, registrar directamente un error en `job.errors`/`job.failed_count` con el motivo devuelto (sin invocar `validar_y_aplicar_fila_producto_y_precios`) y continuar con la siguiente fila — depende de T015 (US2) y T020

**Checkpoint**: Las tres historias completas y verificables de forma independiente; FR-001 a FR-010 cubiertos.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Ajustes finales que no pertenecen a una sola historia

- [X] T022 [P] En `../pos-heladeria/src/app/modules/products/components/product-import-modal.component.ts`, actualizar el comentario que referencia "las 4 hojas" para reflejar las 3 hojas nuevas
- [X] T023 Ejecutar `./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'` en `../pos-backend` y confirmar que sigue en verde (no se espera ningún cambio, Principio III)
- [X] T024 Ejecutar `./env/bin/python -m app.scripts.test_products_bulk_excel` en `../pos-backend` y confirmar que los 8 casos de `quickstart.md` (más los heredados de la 143 que no cambian) pasan en verde
- [X] T025 [P] Ejecutar `npx ng test --watch=false --include='src/app/modules/products/**/*.spec.ts'` en `../pos-heladeria` y confirmar que sigue en verde
- [ ] T026 Validar manualmente contra `quickstart.md` §3 (uso manual con `ng serve`): exportar desde la pantalla de Productos trae 3 hojas, editar precio en la hoja fusionada sin consultar otra hoja (SC-001/SC-002), y subir un archivo de 4 hojas de la 143 muestra el mismo error de estructura que cualquier archivo con hojas/columnas que no corresponden (SC-004)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias
- **Foundational (Phase 2)**: depende de Setup — BLOQUEA las 3 historias
- **US1 (Phase 3)**: depende de Foundational; sin dependencia de US2/US3
- **US2 (Phase 4)**: depende de Foundational; no depende de US1 en código (export e import son módulos distintos), aunque probar el flujo completo manualmente requiere ambos
- **US3 (Phase 5)**: depende de US2 (T015 elimina la lógica de duplicados que T020/T021 reemplazan; T021 llama a la función fusionada de T013 indirectamente a través de `procesar_archivo_importacion`)
- **Polish (Phase 6)**: depende de que US1, US2 y US3 estén completas

### User Story Dependencies

- **US1 (P1)**: solo Foundational
- **US2 (P2)**: solo Foundational (independiente de US1)
- **US3 (P3)**: Foundational + US2 (research.md D2 construye sobre la función de fila fusionada de US2 y reemplaza su lógica de duplicados)

### Within Each User Story

- Tests antes de implementación (deben fallar primero, luego pasar)
- Foundational (schemas) antes que export/import
- Dentro de US2: `_ORDEN_HOJAS` (T012) → función fusionada (T013) → `_VALIDADORES` (T014) → limpieza de duplicados (T015)
- Dentro de US3: detección (T020) antes de integrarla en el loop (T021)

### Parallel Opportunities

- T002 puede ejecutarse junto a la preparación de T001 solo después de que la rama exista; T003 depende de T002 (mismo archivo, secuencial)
- T004/T005 (tests US1) en paralelo entre sí
- T008/T009/T010/T011 (tests US2) tocan el mismo archivo (`test_products_bulk_excel.py`) — aplicar en secuencia aunque estén marcados [P] por historia, para evitar conflictos de edición simultánea sobre el mismo archivo
- T016-T019 (tests US3) mismo caso: mismo archivo, aplicar en secuencia
- T022 (frontend) y T023/T025 (regresión) pueden correr en paralelo entre sí una vez completas las historias

---

## Parallel Example: User Story 1

```bash
# Tests de User Story 1 (archivos de test, antes de implementación):
Task: "Reescribir test_export_incluye_las_4_hojas_con_y_sin_receta a 3 hojas en test_products_bulk_excel.py"
Task: "Reescribir test_export_carta_vacia_entrega_4_hojas_sin_filas a 3 hojas en test_products_bulk_excel.py"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Setup (T001) + Foundational (T002-T003)
2. US1 completa (T004-T007): export entrega la hoja fusionada
3. **STOP and VALIDATE**: exportar la carta y verificar las 3 hojas manualmente
4. Esto ya resuelve SC-001 para el usuario, aunque reimportar todavía no esté implementado

### Incremental Delivery

1. Setup + Foundational → plantilla fusionada lista
2. US1 → exportar trae la hoja fusionada (MVP de lectura)
3. US2 → reimportar edita precios y crea productos nuevos (valor principal, SC-002)
4. US3 → protección contra datos de producto inconsistentes entre filas (SC-003)
5. Polish → comentario de frontend, regresión completa, validación manual end-to-end (SC-004, SC-005)

### Notes

- No hay equipo paralelo real (un solo módulo `app/api/v1/products/`); el orden sugerido de ejecución es secuencial: Setup → Foundational → US1 → US2 → US3 → Polish
- Cada tarea de implementación hace commit propio por tarea o grupo lógico, según el flujo normal del repositorio (sin instrucción de commitear en este documento)
