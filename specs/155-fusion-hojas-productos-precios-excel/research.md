# Research: Fusión de las hojas Productos y Presentaciones/precios en el Excel de la carta

No hay `NEEDS CLARIFICATION` en el Technical Context — las tres preguntas que quedaron abiertas
tras `/speckit-specify` (qué hacer ante inconsistencia entre filas del mismo código, si una fila
puede representar un producto sin presentación, si el formato de 4 hojas de la spec 143 sigue
siendo válido) ya están resueltas en las Clarifications del spec. Esta spec es una evolución
puntual de la 143 (mismo módulo, mismo patrón Celery/openpyxl, Principio IX — cero dependencias
nuevas): lo que queda aquí son las decisiones de diseño necesarias para fusionar dos hojas en una
sin reabrir decisiones que la 143 ya tomó y que esta spec no toca (D1/D2/D3/D6/D7/D8 de
`143-exportacion-importacion-carta-menu/research.md` siguen vigentes sin cambios — resolución
buscar-o-crear de Categoría/Presentación, insumo/adición por resolución estricta, bloqueo de un
import concurrente, permisos, plantilla única compartida export/import).

## D1 — Las dos hojas se fusionan combinando sus columnas en el orden: producto, luego presentación

**Decisión**: la hoja nueva "Productos y precios" tiene, en este orden, las 10 columnas que hoy
tiene "Productos" (Código, Nombre, Categoría, Tipo de preparación, Descripción, Activo,
Disponible, Rastrea inventario, Es adición, Visible en menú QR) seguidas de las 6 columnas que hoy
tiene "Presentaciones y precios" salvo su propia columna "Código de producto" (que se fusiona con
la columna "Código" de Productos, una sola vez por fila): Presentación, SKU, Nombre comercial,
Precio, Orden, Activo de la presentación. 15 columnas en total (10 + 6 − 1 de código duplicado).

**Columna "Activo" duplicada**: ambas hojas originales tienen una columna llamada "Activo" (una
para `products.active`, otra para `product_variants.active`), que en la hoja fusionada no pueden
coexistir con el mismo encabezado sin ambigüedad para quien edita el archivo a mano. Se renombra la
de la presentación a **"Activo de la presentación"**; la del producto conserva el nombre "Activo"
sin cambios (es la que ya existía primero, y es la que un administrador que solo edita precios va a
tocar con menos frecuencia).

**Rationale**: es la fusión literal que pide el Input del spec ("una sola hoja... donde cada fila
corresponde a una presentación y contiene tanto los datos del producto como los de esa
presentación", FR-002) — ningún campo se agrega ni se quita respecto a la 143, solo cambia su
disposición en una sola hoja en vez de dos. Poner primero las columnas de producto y después las de
presentación respeta el orden de lectura natural (lo que identifica la fila al humano, luego lo que
va a editar: el precio) y es el mismo orden en que ya aparecían ambos bloques en la 143 (hoja
Productos antes que hoja Presentaciones).

**Alternatives considered**:
- *Intercalar columnas de producto y presentación por relevancia (p. ej. Nombre, Presentación,
  Precio primero, resto después)*: rechazada — reordenar campos ya conocidos por el usuario (que ya
  usaba el archivo de la 143) sin necesidad introduce más fricción de la que resuelve; el pedido del
  usuario es eliminar la navegación entre hojas, no reordenar columnas.

## D2 — Consistencia entre filas del mismo código: pre-escaneo de la hoja completa antes de aplicar cualquier fila

**Decisión**: antes de aplicar cualquier fila de "Productos y precios", se agrupan todas las filas
de la hoja por su columna Código (columna 1), **solo considerando códigos no vacíos** (ver D3 para
código vacío). Para cada grupo con más de una fila, se comparan los valores de las 10 columnas de
producto entre todas las filas del grupo (comparación por texto, tras el mismo *trim*/normalización
que ya aplica cada parser de columna — p. ej. "Sí"/"sí" se tratan como iguales, no solo "Sí"
exactamente igual). Si alguna columna difiere entre dos filas del mismo grupo, **todas** las filas
de ese grupo se marcan como fila fallida (`failed_count`), con un motivo que identifica la
columna(s) que difiere y ninguna de ellas se aplica. Si el grupo es consistente, cada fila se
procesa de forma independiente en el orden en que aparece en el archivo (ver D4): el producto se
crea o actualiza en la primera fila del grupo y las filas siguientes del mismo grupo simplemente lo
vuelven a actualizar con los mismos valores (ya consistentes por construcción, por lo tanto un
no-op funcional) antes de crear/actualizar su propia presentación — evita necesitar una noción
explícita de "primera fila de un grupo" en el código de aplicación.

**Rationale**: es exactamente FR-005 y la Clarification de la sesión 2026-11-09 ("marcar como error
todas las filas afectadas... sin aplicar ninguna de ellas"). Hacerlo como un pre-escaneo completo
de la hoja (no fila por fila a medida que se procesa) es necesario porque la inconsistencia solo es
detectable comparando **todas** las filas del código antes de decidir si alguna se aplica — procesar
la primera fila del grupo antes de ver que la segunda difiere aplicaría datos que luego habría que
revertir, violando la garantía de "ninguna de ellas se aplica". Reaplicar el producto en cada fila
del grupo (en vez de aplicarlo solo en la primera y saltarlo en las siguientes) es deliberadamente
más simple de implementar y es seguro porque la consistencia ya fue garantizada por el pre-escaneo:
no hay ningún valor que pueda "retroceder" entre la fila 1 y la fila 2 del mismo grupo.

**Alternatives considered**:
- *Aplicar el producto solo en la primera fila del grupo y las siguientes solo la presentación*:
  rechazada — exige que el código de aplicación sepa distinguir "primera fila de un grupo ya visto
  en este archivo" de una fila normal, más estado mutable durante el recorrido, sin ganar nada
  sobre simplemente reaplicar (ya probado seguro por la consistencia garantizada).
- *Detectar la inconsistencia de forma incremental (comparar cada fila solo contra la anterior del
  mismo código ya aplicada)*: rechazada — permitiría que la primera fila de un grupo inconsistente
  ya quedara aplicada antes de detectar el problema en una fila posterior, violando la Clarification
  ("sin aplicar ninguna de ellas").

## D3 — Código vacío: cada fila sin código es un producto nuevo independiente, no un grupo

**Decisión**: una fila con la columna Código vacía no participa de ningún agrupamiento de
consistencia (D2) — siempre crea un producto nuevo con código autogenerado (mismo criterio que ya
tenía la hoja "Productos" de la 143) junto con su propia presentación. Un producto nuevo que
necesita varias presentaciones en el mismo archivo **debe** traer el mismo código explícito (no
vacío) en todas sus filas — p. ej. un código provisional elegido por el administrador, o el flujo
normal de "exportar primero, luego añadir filas nuevas copiando el código ya asignado". Esto no es
un requisito nuevo de esta spec: ya era así en la 143 para la hoja "Presentaciones y precios" (su
columna "Código de producto" siempre debía existir, en el archivo o en el sistema) — la única
diferencia aquí es que ahora un producto nuevo con una sola presentación puede, igual que antes,
dejar el código vacío en su única fila.

**Rationale**: ninguna de las dos spec (143 ni esta) pide una forma de decirle al sistema "estas N
filas sin código son el mismo producto nuevo" sin un identificador compartido explícito — inventar
uno (p. ej. agrupar por nombre+categoría cuando el código está vacío) sería una regla no pedida por
ningún FR ni edge case, y ambigua en el caso real de dos productos nuevos distintos que
coincidencialmente comparten nombre y categoría. Mantener el criterio ya usado por la 143 (código
vacío = asignar uno nuevo, siempre) evita ese problema sin agregar ninguna regla nueva.

**Alternatives considered**:
- *Agrupar filas sin código por la combinación de columnas de producto*: rechazada — no está
  pedida por el spec, es ambigua (dos productos nuevos distintos pueden coincidir en nombre y
  categoría) y agrega una regla de negocio que nadie pidió (Principio V).

## D4 — Orden de procesamiento: Productos y precios → Receta → Adiciones (3 hojas)

**Decisión**: la tarea Celery procesa las hojas presentes en este orden fijo (FR-007 actualizado),
cada una completa antes de pasar a la siguiente — mismo criterio que D4 de la 143, con una hoja
menos. Las filas dentro de "Productos y precios" se procesan en el orden en que aparecen en el
archivo (D2).

**Rationale**: FR-007 explícito; es la adaptación directa de D4 de la 143 al nuevo formato de 3
hojas.

**Alternatives considered**: ninguna — mismo razonamiento que D4 de la 143.

## D5 — Rechazo del formato anterior de 4 hojas: efecto natural de `validar_estructura`, sin código especial de detección de formato legado

**Decisión**: no se agrega ninguna lógica dedicada a "detectar un archivo de la spec 143 y
rechazarlo con un mensaje especial". Al renombrar, en la plantilla compartida de
`schemas.PRODUCT_IMPORT_SHEETS`, las claves "Productos" y "Presentaciones y precios" por la única
clave "Productos y precios" (con las 15 columnas de D1), un archivo exportado bajo la spec 143 que
siga teniendo hojas llamadas "Productos" y "Presentaciones y precios" activa, sin cambios
adicionales, la rama ya existente de `validar_estructura` que trata una hoja presente cuyo nombre no
corresponde a ninguna de las hojas esperadas como "hoja desconocida" — exactamente el mismo
tratamiento que ya recibía cualquier hoja renombrada o con encabezados que no coinciden (FR-008,
igual criterio que hoy ante hojas o encabezados que no coinciden). El archivo se rechaza completo
con `422` antes de aplicar cualquier fila, igual que cualquier otro problema de estructura.

**Rationale**: es la Clarification de la sesión 2026-11-09 ("corte directo... un archivo con el
formato anterior ya no es válido") y el edge case correspondiente, que además pide explícitamente
"igual que ya ocurre hoy ante hojas o encabezados que no coinciden" — es decir, el spec mismo pide
reutilizar el mecanismo existente, no construir uno nuevo. Construir una detección dedicada del
formato de 4 hojas violaría el Principio V (funcionalidad no solicitada: el spec no pide un mensaje
distinto para "este archivo es de la spec 143 vieja" frente a "este archivo tiene una hoja que no
reconozco", son el mismo caso para el usuario).

**Alternatives considered**:
- *Detectar específicamente las hojas "Productos"/"Presentaciones y precios" y devolver un mensaje
  dedicado ("este archivo usa el formato anterior, vuelve a exportar")*: rechazada por el Principio V
  arriba — el spec pide expresamente el mismo tratamiento que un archivo con hojas/encabezados que
  no coinciden, no uno diferenciado.

## D6 — Sin cambios de modelo de datos ni de dependencias

**Decisión**: esta spec no agrega ninguna columna, tabla ni dependencia nueva. `products.code` y
`product_import_jobs` (spec 143) se reutilizan sin cambios; el único efecto visible en los datos ya
persistidos es que el valor de `product_import_jobs.errors[].hoja` que antes podía ser "Productos" o
"Presentaciones y precios" ahora es "Productos y precios" para los jobs ejecutados después de este
despliegue — es un valor de texto libre dentro de un JSONB, no una migración de esquema.

**Rationale**: la fusión es un cambio de formato de archivo y de lógica de validación, no un
cambio de lo que el sistema persiste — el producto y la presentación siguen siendo exactamente las
mismas dos entidades, con los mismos campos, que la spec 143 ya modela. Principio IX/VI: ningún
requisito de esta spec exige tocar el modelo de datos.

**Alternatives considered**: ninguna — no hay ninguna necesidad de modelo de datos que esta spec
introduzca.
