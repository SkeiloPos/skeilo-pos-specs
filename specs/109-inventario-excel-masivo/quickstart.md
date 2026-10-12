# Quickstart: validar export/import masivo de inventario

Asume que `data-model.md`/`contracts/api.md` ya están aplicados.

## Prerrequisitos

- `pos-backend`: migración aplicada (columna `code` backfillada + tabla `inventory_import_jobs`);
  un tenant con insumos, al menos una relación proveedor-insumo preferida (spec 106) y al menos
  un proveedor normal (no "Compra ocasional").
- Un worker Celery corriendo contra el mismo Redis que ya usa `send_email_task`, o el script de
  verificación invocando la tarea en modo síncrono (`.apply()` en vez de `.delay()`) para no
  depender de tener un worker levantado durante la verificación.

## 1. Backend — script autoejecutable

```bash
cd ../pos-backend
./env/bin/python -m app.scripts.test_inventory_bulk_excel
```

Debe cubrir, como mínimo (mapeado a las historias del spec):

1. Exportar un inventario con insumos con y sin proveedor preferido → las cabeceras son
   exactamente las 11 columnas de `data-model.md`, en ese orden; un insumo sin proveedor preferido
   trae las columnas 8-11 en blanco, sin error (Historia 1).
2. Tomar ese mismo archivo exportado, re-subirlo sin editar nada → el import no reporta ninguna
   fila fallida y todas las filas se tratan como actualización (mismo código) sin crear
   duplicados (Historia 1, escenario 2).
3. Editar una fila del archivo exportado (cambiar Costo) y re-subirlo → el insumo correspondiente
   queda con el nuevo costo, `updated_count == 1` (Historia 2, escenario 1).
4. Agregar una fila nueva con Código vacío → se crea un insumo nuevo con un código asignado
   automáticamente, `created_count` sube en 1 (Historia 2, escenario 2).
5. Un archivo con una fila con Costo no numérico, una con Tipo inválido, y una con Factor de
   conversión ≤ 0 (cuando sí hay proveedor) → las 3 fallan individualmente con un motivo distinto
   cada una, y el resto del archivo se procesa igual (Historia 2, escenario 3; `failed_count ==
   3`).
6. Un archivo con una columna fuera de orden o renombrada → `POST /items/import` responde `422`
   sin crear ningún job (Historia 2, escenario 4).
7. Dos códigos repetidos dentro del mismo archivo → ambas filas fallan, ninguna se aplica (Edge
   case del spec).
7a. Una fila con una Unidad o un Proveedor preferido que no existen (research.md D7) → se
   consolidan creándolos automáticamente, en MAYÚSCULA, sin fallar la fila; si el Excel trae
   "kg"/"Kg"/"KG" en filas distintas, las tres deben resolver a la misma unidad ya creada (no tres
   unidades distintas). Un proveedor existente pero inactivo que coincida (ignorando mayúsculas)
   se reactiva en vez de duplicarse.
8. Con un job `procesando` vigente (simulado sin marcarlo `finalizado`), un segundo
   `POST /items/import` responde `409` (Historia 3, escenario 3; FR-010).
9. Simular una interrupción a mitad de archivo (invocar la función de procesamiento de fila por
   fila y detenerse a la mitad) → las filas ya aplicadas antes del corte permanecen aplicadas,
   `GET /items/import/{id}` refleja solo lo procesado hasta ahí (research.md D5, FR-015).

## 2. Backend — regresión obligatoria

```bash
./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'
```

Debe seguir en verde, **incluyendo** `test_inventory_export.py` ya actualizado con las nuevas
columnas (no es `CONGELA`, se actualiza como parte de esta spec — ver plan.md, Constitution
Check).

## 3. Frontend — specs Vitest + uso manual

```bash
cd ../pos-heladeria
npx ng test --watch=false --include='src/app/modules/inventory/**/*.spec.ts'
```

Uso manual (`ng serve`):

1. En la pantalla de Inventario, junto a "Exportar Inventario", aparece "Importar Excel".
2. Exportar, editar el archivo (cambiar un costo, agregar una fila sin código) y subirlo con
   "Importar Excel" → la pantalla confirma de inmediato que quedó en proceso, sin bloquear el
   resto de la interfaz (Historia 3, escenario 1).
3. Navegar a otra pantalla y volver a Inventario mientras el import corre → se sigue mostrando el
   progreso (vía sondeo con `startVisibleInterval`) hasta que termina.
4. Al terminar, el resumen muestra creados/actualizados/fallidos (Historia 4, escenario 1); si hay
   fallidos, aparece el botón de descarga del reporte de errores (Historia 4, escenario 2); si no
   hay ninguno, no aparece ese botón (Historia 4, escenario 3).
5. Subir un archivo con la estructura de columnas alterada → error inmediato de estructura, sin
   llegar a mostrar una barra de progreso.

## Criterio de éxito

Los 9 puntos del script backend pasan, la regresión de characterization sigue en verde
(`test_inventory_export.py` incluido, ya actualizado), las specs Vitest de `inventory` pasan, y
los 5 pasos manuales del frontend se comportan como se describe — en particular, el flujo completo
de ida y vuelta (exportar → editar → importar) nunca produce un error de estructura.
