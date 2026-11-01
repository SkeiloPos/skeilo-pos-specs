# Quickstart: validar export/import masivo de la carta

Asume que `data-model.md`/`contracts/api.md` ya están aplicados.

## Prerrequisitos

- `pos-backend`: migración aplicada (columna `products.code` backfillada + tabla
  `product_import_jobs`); un tenant con productos, categorías, presentaciones, al menos un
  producto con receta (insumo ya existente en inventario) y al menos un producto marcado
  `is_topping=true` para probar adiciones.
- Un worker Celery corriendo contra el mismo Redis que ya usa `import_inventory_task`, o el script
  de verificación invocando la tarea en modo síncrono (`.apply()` en vez de `.delay()`).

## 1. Backend — script autoejecutable

```bash
cd ../pos-backend
./env/bin/python -m app.scripts.test_products_bulk_excel
```

Debe cubrir, como mínimo (mapeado a las historias del spec):

1. Exportar una carta con productos con y sin receta/adiciones → el archivo trae las 4 hojas con
   las cabeceras exactas de `data-model.md`, en ese orden; un producto sin receta ni adiciones
   aparece en Productos y en Presentaciones y precios, sin filas en Receta ni Adiciones (Historia
   1, escenarios 1-2). Una carta vacía exporta las 4 hojas con encabezados, sin filas (Historia 1,
   escenario 3).
2. Tomar ese mismo archivo exportado, re-subirlo sin editar nada → el import no reporta ninguna
   fila fallida, todas las filas se tratan como actualización (mismo código) sin crear duplicados.
3. Editar una fila de la hoja Presentaciones y precios (cambiar Precio) y re-subirlo → la variante
   correspondiente queda con el nuevo precio, `updated_count` sube en 1 y el resto del producto
   permanece sin cambios (Historia 2, escenario 1).
4. Agregar una fila nueva en la hoja Productos con Código vacío → se crea un producto nuevo con un
   código asignado automáticamente (Historia 2, escenario 2).
5. Un archivo con una fila de Receta que referencia un insumo inexistente → esa fila falla con un
   motivo claro, sin afectar las demás filas válidas (Historia 2, escenario 3; FR-008).
6. Un archivo con una fila de Adiciones que referencia como producto-adición un producto que existe
   pero no tiene `is_topping=true` → esa fila falla con un motivo claro, el resto se sigue
   procesando (Historia 2, escenario 4; FR-009).
7. Una importación en curso sobre un archivo de varios cientos de filas → `GET
   /products/import/{id}` refleja el avance (creados/actualizados/fallidos) antes de terminar
   (Historia 2, escenario 5).
8. Una importación con filas en error → el reporte descargable identifica hoja, fila y motivo de
   cada una (Historia 2, escenario 6).
9. Reimportar un archivo previo donde algunas filas de productos fallaron y luego se corrigieron
   → los productos ya creados no se duplican (identificados por código) y las filas corregidas se
   aplican correctamente (Historia 3, escenario único; FR-014).
10. Dos códigos de producto repetidos dentro del mismo archivo → ambas filas fallan (edge case del
    spec).
11. Una fila de Presentaciones que referencia un código de producto inexistente (ni en el archivo
    ni en el sistema) → falla con el motivo correspondiente (edge case del spec).
12. Una fila de Adiciones donde el producto-adición es el mismo código del producto que lo ofrece
    → falla (edge case del spec).
13. Un producto con presentaciones/receta/adiciones ya configuradas, reimportado con un archivo que
    ya no trae alguna de esas filas → esas filas permanecen intactas, no se eliminan ni desactivan
    (FR-005a).
14. Un archivo con hojas faltantes, renombradas o columnas en orden distinto → `POST
    /products/import` responde `422` sin crear ningún job (edge case del spec).
15. Un archivo con solo la hoja Productos (sin Receta ni Adiciones) → caso válido, solo se procesa
    la hoja presente (edge case del spec).
16. Con un job `procesando` vigente (simulado sin marcarlo `finalizado`), un segundo `POST
    /products/import` responde `409` (FR-012a).

## 2. Backend — regresión obligatoria

```bash
./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'
```

Debe seguir en verde — ningún characterization test existente cubre export/import de la carta
(funcionalidad enteramente nueva), así que no se espera ningún cambio sobre tests protegidos.

## 3. Frontend — specs Vitest + uso manual

```bash
cd ../pos-heladeria
npx ng test --watch=false --include='src/app/modules/products/**/*.spec.ts'
```

Uso manual (`ng serve`):

1. En la pantalla de Productos, aparecen "Exportar carta" e "Importar Excel".
2. Exportar, editar el archivo (cambiar un precio, agregar una fila de producto sin código) y
   subirlo con "Importar Excel" → la pantalla confirma de inmediato que quedó en proceso, sin
   bloquear el resto de la interfaz.
3. Navegar a otra pantalla y volver a Productos mientras el import corre → se sigue mostrando el
   progreso (vía sondeo con `startVisibleInterval`) hasta que termina.
4. Al terminar, el resumen muestra creados/actualizados/fallidos; si hay fallidos, aparece el botón
   de descarga del reporte de errores; si no hay ninguno, no aparece ese botón.
5. Subir un archivo con la estructura de hojas/columnas alterada → error inmediato de estructura,
   sin llegar a mostrar una barra de progreso.

## Criterio de éxito

Los 16 puntos del script backend pasan, la regresión de characterization sigue en verde, las specs
Vitest de `products` pasan, y los 5 pasos manuales del frontend se comportan como se describe — en
particular, el flujo completo de ida y vuelta (exportar → editar → importar) nunca produce un error
de estructura, y reimportar el mismo archivo sin editarlo nunca duplica nada (SC-005).
