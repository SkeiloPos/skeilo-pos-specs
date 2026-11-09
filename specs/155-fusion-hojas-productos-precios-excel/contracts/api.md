# Contrato de API: export/import masivo de la carta (hoja fusionada)

Mismas rutas, mismos métodos y mismo permiso (`require_tenant_admin`) que
`143-exportacion-importacion-carta-menu/contracts/api.md` — esta spec no agrega ni elimina
endpoints, solo cambia el contenido del archivo que exportan/importan. Se documentan aquí solo los
cambios; todo lo demás (bloqueo de import concurrente FR-012a, `202`/`409`/`403`, polling de
`GET /products/import/current`, descarga de reporte de errores) sigue igual.

## `GET /products/export` (sin cambios de ruta/método)

Devuelve un `.xlsx` descargable con **3 hojas** (Productos y precios, Receta, Adiciones) en vez de
4 — cabeceras y filas según la plantilla de `data-model.md` (FR-001, FR-002). Incluye todos los
productos del tenant, activos e inactivos. Un producto con varias presentaciones genera varias
filas en "Productos y precios", cada una con los datos de producto repetidos (Historia 1, escenario
2). Una carta sin ningún producto entrega las 3 hojas con sus encabezados, sin filas de datos.

## `POST /products/import` (sin cambios de ruta/método)

Recibe el archivo `.xlsx` como `multipart/form-data`. Mismo flujo que la 143 (validar estructura
síncrona → `422` si no corresponde → verificar que no haya job `procesando` vigente → `409` si lo
hay → crear `product_import_jobs` y encolar `import_products_task` → `202` con el `job_id`), con dos
diferencias:

1. La validación de estructura (FR-010 de la 143, FR-008 de esta spec) ahora compara contra las 3
   hojas esperadas ("Productos y precios", "Receta", "Adiciones"). Un archivo exportado bajo el
   formato anterior de 4 hojas de la spec 143 (con hojas "Productos" y "Presentaciones y precios")
   se rechaza íntegramente con `422` por esta misma vía — las hojas "Productos" y "Presentaciones y
   precios" no corresponden a ninguna de las 3 esperadas y se reportan como hoja desconocida,
   exactamente igual que cualquier otra hoja con nombre o columnas que no coinciden (research.md
   D5, SC-004). No existe un mensaje de error diferenciado para "formato anterior" — es el mismo
   `422` de estructura inválida que ya existía en la 143.
2. Un archivo que solo trae un subconjunto de las 3 hojas sigue siendo válido (edge case heredado
   de la 143); solo se procesan las hojas presentes.

La tarea Celery procesa las hojas presentes en el orden **Productos y precios → Receta → Adiciones**
(FR-007 actualizado, research.md D4) — una hoja menos que la 143, mismo criterio de commit
independiente por fila y de reporte de progreso en `product_import_jobs`.

## `GET /products/import/current` y `GET /products/import/{job_id}` (sin cambios)

Mismo contrato de respuesta que la 143 — `ProductImportJobResponse` no cambia de forma; solo el
contenido de `errors[].hoja` (cuando se descarga el reporte) refleja los nuevos nombres de hoja.

## `GET /products/import/{job_id}/errors` (sin cambios de ruta/método)

Mismo archivo descargable que la 143 (hoja, fila, código, motivo por cada fila fallida). El valor
de "Hoja" para un error de producto o de presentación es ahora "Productos y precios" en vez de
"Productos" o "Presentaciones y precios" por separado (Key Entities del spec); el motivo de una
inconsistencia detectada en la pasada 1 (research.md D2) identifica el código y la columna que
difiere entre las filas del grupo.

## Errores comunes

Sin cambios respecto a la 143 (`422` estructura, `409` import en curso, `404` job/sin errores,
`403` sin rol administrativo) — ver esa tabla en
`143-exportacion-importacion-carta-menu/contracts/api.md`.
