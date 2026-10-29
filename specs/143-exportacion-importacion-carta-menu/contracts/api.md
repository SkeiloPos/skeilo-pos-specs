# Contrato de API: export/import masivo de la carta

Todas las rutas son relativas a `/api/v1/products`, protegidas con `require_tenant_admin`
(`app/core/dependencies.py`) — un único permiso administrativo habilita exportar e importar, sin
distinción entre ambas acciones (FR-016, igual criterio que inventario).

## `GET /products/export` (nuevo)

Devuelve un `.xlsx` descargable con 4 hojas (Productos, Presentaciones y precios, Receta,
Adiciones), cabeceras y filas según la plantilla de `data-model.md` (FR-001, FR-002). Incluye
todos los productos del tenant, activos e inactivos, sin importar filtros en pantalla — mismo
criterio que el export de inventario. Un producto sin receta ni adiciones configuradas aparece en
las hojas Productos y Presentaciones y precios, y simplemente no genera filas en Receta ni
Adiciones (Historia 1, escenario 2). Una carta sin ningún producto entrega las 4 hojas con sus
encabezados, sin filas de datos (Historia 1, escenario 3).

## `POST /products/import` (nuevo)

Recibe el archivo `.xlsx` como `multipart/form-data`.

1. Valida la estructura (las 4 hojas esperadas — o un subconjunto de ellas, ver abajo —, sus
   cabeceras y su orden de columnas contra la plantilla, FR-010) **de forma síncrona**, antes de
   tocar cualquier fila o encolar nada. Si alguna hoja presente no corresponde a la plantilla →
   `422` inmediato, con el detalle de qué hoja/columna falta o no corresponde. No se crea ningún
   job. Un archivo que solo trae algunas de las 4 hojas (p. ej. solo Productos) es válido — solo se
   procesan las hojas presentes (edge case del spec).
2. Si la estructura es válida, verifica que no haya ya un job `procesando` vigente para este
   tenant (FR-012a, research.md D7) → si lo hay, `409` con el id del job en curso.
3. Crea la fila de `product_import_jobs` (`status = 'procesando'`, `total_rows` = suma de filas de
   datos de las hojas presentes) y encola
   `import_products_task(tenant_schema, job_id, contenido_archivo)`.
4. Responde `202 Accepted` con el `job_id` recién creado — el administrador no espera el
   procesamiento.

La tarea Celery, ya en segundo plano, procesa las hojas presentes en el orden Productos →
Presentaciones y precios → Receta → Adiciones (FR-007, research.md D4), valida y aplica cada fila
de forma independiente (`data-model.md`, reglas de validación), actualizando
`created_count`/`updated_count`/`failed_count`/`errors` en la misma fila de `product_import_jobs`,
y la deja en `status = 'finalizado'` con `finished_at` al terminar. Si se interrumpe a mitad de
proceso, las filas ya aplicadas permanecen aplicadas; las restantes no se procesan y el job queda
en `interrumpido` (edge case del spec).

## `GET /products/import/current` (nuevo)

Devuelve el job más reciente del tenant (en curso o ya finalizado) — `null` si nunca se ha corrido
ninguno. Es lo que el frontend sondea mientras hay uno `procesando` (mismo patrón que
`GET /items/import/current` de inventario, vía `startVisibleInterval`).

## `GET /products/import/{job_id}` (nuevo)

Mismo contenido que arriba, por id explícito.

Respuesta (ambos GET), forma común:

```json
{
  "id": "...",
  "status": "procesando | finalizado | interrumpido",
  "file_name": "carta_editada.xlsx",
  "started_at": "...",
  "finished_at": null,
  "total_rows": 340,
  "created_count": 0,
  "updated_count": 0,
  "failed_count": 0,
  "has_errors": false
}
```

`has_errors` es `failed_count > 0` — el frontend lo usa para decidir si ofrece el botón de
descarga del reporte de errores (Historia 2, escenario 6); el detalle de errores no viaja en esta
respuesta.

## `GET /products/import/{job_id}/errors` (nuevo)

Devuelve un archivo descargable (`.xlsx`, mismas convenciones que el export) con una fila por cada
fila fallida: hoja de origen, número de fila original, código (si lo trajo), y el motivo del fallo
(FR-013). `404` si el job no tiene ninguna fila fallida.

## Errores comunes

| Código | Cuándo |
|---|---|
| 422 | estructura del archivo no corresponde a la plantilla en alguna de sus hojas presentes (`POST /products/import`); el archivo no es un `.xlsx` válido |
| 409 | ya hay un job `procesando` vigente para este tenant (`POST /products/import`) |
| 404 | `job_id` no existe para este tenant, o (`.../errors`) el job no tiene filas fallidas |
| 403 | usuario sin el rol administrativo requerido (FR-016) |

Los errores *de fila* (dentro de un import ya aceptado) nunca son códigos HTTP — viajan en
`product_import_jobs.errors`, consultables vía `GET /products/import/{job_id}` y descargables vía
`GET /products/import/{job_id}/errors` (FR-008, FR-009, FR-013).
