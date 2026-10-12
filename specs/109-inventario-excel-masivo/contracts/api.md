# Contrato de API: export/import masivo de inventario

Todas las rutas son relativas a `/api/v1/inventory`, protegidas igual que hoy
(`require_tenant_admin`, mismo rol que ya controla el acceso a la tabla de Inventario — FR-014).

## `GET /items/export` (ya existente, spec 086 — mismo path, columnas nuevas)

Sin cambio de ruta ni de forma de respuesta (sigue siendo un `.xlsx` descargable). Cambia el
contenido: cabeceras y filas según la plantilla de `data-model.md` (código, proveedor preferido
agregados; "Estado" retirado). Sigue incluyendo activos e inactivos, sin importar filtros en
pantalla (FR-004, sin cambios respecto a la 086).

## `POST /items/import` (nuevo)

Recibe el archivo `.xlsx` como `multipart/form-data`.

1. Valida la estructura (cabeceras/orden contra la plantilla, FR-005) **de forma síncrona**, antes
   de tocar cualquier fila o encolar nada. Si no corresponde → `422` inmediato, con el detalle de
   qué columna falta/no corresponde. No se crea ningún job.
2. Si la estructura es válida, verifica que no haya ya un job `procesando` vigente para este
   tenant (FR-010, research.md D5) → si lo hay, `409` con el id del job en curso.
3. Crea la fila de `inventory_import_jobs` (`status = 'procesando'`, `total_rows` = filas de
   datos del archivo) y encola `import_inventory_task(tenant_schema, job_id, contenido_archivo)`.
4. Responde `202 Accepted` con el `job_id` recién creado — el administrador no espera el
   procesamiento (FR-009).

La tarea Celery, ya en segundo plano, valida y aplica cada fila de forma independiente
(`data-model.md`, reglas de validación), actualizando `created_count`/`updated_count`/
`failed_count`/`errors` en la misma fila de `inventory_import_jobs`, y la deja en
`status = 'finalizado'` con `finished_at` al terminar.

## `GET /items/import/current` (nuevo)

Devuelve el job más reciente del tenant (en curso o ya finalizado) — null si nunca se ha corrido
ninguno. Es lo que el frontend sondea mientras hay uno `procesando` (Historia 3, escenario 2: el
administrador puede cerrar y volver a abrir la pantalla y encontrar el resultado sin recordar
ningún id).

## `GET /items/import/{job_id}` (nuevo)

Mismo contenido que arriba, por id explícito — útil para revisar un job anterior puntual.

Respuesta (ambos GET), forma común:

```json
{
  "id": "...",
  "status": "procesando | finalizado | interrumpido",
  "file_name": "inventario_editado.xlsx",
  "started_at": "...",
  "finished_at": null,
  "total_rows": 120,
  "created_count": 0,
  "updated_count": 0,
  "failed_count": 0,
  "has_errors": false
}
```

`has_errors` es `failed_count > 0` — el frontend lo usa para decidir si ofrece el botón de
descarga (Historia 4, escenario 3); el detalle de errores no viaja en esta respuesta (ver abajo).

## `GET /items/import/{job_id}/errors` (nuevo)

Devuelve un archivo descargable (`.xlsx`, mismas convenciones que el export) con una fila por
cada fila fallida: número de fila original, código (si lo trajo), y el motivo del fallo.
`404` si el job no tiene ninguna fila fallida (FR-012: solo existe cuando hay al menos un error).

## Errores comunes

| Código | Cuándo |
|---|---|
| 422 | estructura del archivo no corresponde a la plantilla (`POST /items/import`); el archivo no es un `.xlsx` válido |
| 409 | ya hay un job `procesando` vigente para este tenant (`POST /items/import`) |
| 404 | `job_id` no existe para este tenant, o (`.../errors`) el job no tiene filas fallidas |
| 403 | usuario sin el rol autorizado — igual criterio que hoy para `/items/export` y el resto del módulo |

Los errores *de fila* (dentro de un import ya aceptado) nunca son códigos HTTP — viajan en
`inventory_import_jobs.errors`, consultables vía `GET /items/import/{job_id}` y descargables vía
`GET /items/import/{job_id}/errors` (FR-008, FR-012).
