# Quickstart: validar la fusión de hojas en el export/import de la carta

Asume que `data-model.md`/`contracts/api.md` de esta spec, y la infraestructura de la spec 143
(`products.code`, tabla `product_import_jobs`, tarea Celery), ya están aplicados. Reemplaza, para
este flujo, el script/checklist de `143-exportacion-importacion-carta-menu/quickstart.md` — los
puntos 5, 6, 7, 8, 9, 13, 16 de ese quickstart siguen aplicando sin cambios (no dependen del número
de hojas) y no se repiten aquí.

## Prerrequisitos

Mismos que `143-exportacion-importacion-carta-menu/quickstart.md`: un tenant con productos,
categorías, presentaciones, al menos un producto con receta y uno marcado `is_topping=true`; worker
Celery (o invocación síncrona de la tarea) disponible.

## 1. Backend — script autoejecutable

```bash
cd ../pos-backend
./env/bin/python -m app.scripts.test_products_bulk_excel
```

Casos específicos de esta spec, además de los heredados de la 143 (estructura/receta/adiciones/
concurrencia/reintento, sin cambios):

1. Exportar una carta con un producto de tres presentaciones → el archivo trae **3 hojas**
   ("Productos y precios", "Receta", "Adiciones"), con las 16 columnas exactas de `data-model.md`
   en "Productos y precios"; ese producto genera 3 filas, cada una con los mismos datos de producto
   repetidos (Historia 1, escenarios 1-2).
2. Editar el Precio en varias filas del archivo exportado y reimportarlo → cada variante queda con
   su nuevo precio; el resto de datos de esos productos y de sus otras presentaciones no cambia
   (Historia 2, escenario 1).
3. Una fila con un código de producto que no existe en el sistema → crea el producto junto con su
   presentación y precio en una sola operación (Historia 2, escenario 2).
4. Varias filas que comparten el mismo código de producto explícito y los mismos valores en las
   columnas de producto, con presentaciones distintas → el producto se crea/actualiza una sola vez
   (efectivamente) y cada fila crea/actualiza su propia presentación (Historia 2, escenario 3).
5. Dos filas del mismo código de producto que difieren en el Nombre (o cualquier otra columna de
   producto) → **ambas** filas se reportan como error de inconsistencia y **ninguna** se aplica;
   otras filas de productos sin ese problema se aplican con normalidad (Historia 3, escenarios 1-2;
   FR-005).
6. Una fila con los datos de producto completos pero Presentación o Precio vacíos → falla como
   error de validación, nunca se crea un producto sin presentación por esta vía (FR-004, edge case
   del spec).
7. Reimportar, sin editar nada, un archivo recién exportado con el nuevo formato → ninguna fila
   falla, ningún dato se duplica (SC-005).
8. Reintentar la importación de un archivo de la spec 143 (4 hojas, con "Productos" y
   "Presentaciones y precios" por separado) → `POST /products/import` responde `422` de estructura,
   sin crear ningún job (SC-004, research.md D5).

## 2. Backend — regresión obligatoria

```bash
./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'
```

Debe seguir en verde. Ningún characterization test cubre hoy el export/import de la carta (es
funcionalidad de la spec 143, sin tests `"CONGELA comportamiento actual:"` propios) — no se espera
ningún cambio sobre tests protegidos.

## 3. Frontend — specs Vitest + uso manual

```bash
cd ../pos-heladeria
npx ng test --watch=false --include='src/app/modules/products/**/*.spec.ts'
```

Uso manual (`ng serve`): mismos pasos que
`143-exportacion-importacion-carta-menu/quickstart.md` §3, con dos verificaciones adicionales:

1. El archivo exportado desde la pantalla de Productos trae 3 hojas, no 4; la hoja fusionada
   permite editar el precio de una presentación sin consultar ninguna otra hoja (SC-001, SC-002).
2. Subir un archivo exportado antes de este despliegue (formato de 4 hojas) muestra el mismo error
   de estructura que cualquier archivo con hojas/columnas que no corresponden, sin un mensaje
   distinto para "formato anterior" (SC-004).

## Criterio de éxito

Los puntos del script backend (los 8 propios de esta spec + los heredados de la 143 que no cambian)
pasan, la regresión de characterization sigue en verde, las specs Vitest de `products` pasan, y los
pasos manuales del frontend se comportan como se describe — en particular, SC-001 a SC-005 del spec
quedan verificados: edición sin cambiar de hoja, reducción real de pasos frente al flujo de dos
hojas, 100% de las filas inconsistentes reportadas sin afectar al resto, rechazo íntegro del formato
anterior, y cero duplicados al reimportar sin cambios.
