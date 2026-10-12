# Feature Specification: Exportación e Importación Masiva de Inventario en Excel

**Feature Branch**: `109-inventario-excel-masivo`

**Created**: 2026-10-10

**Status**: Draft

**Supersede**: esta spec reemplaza y absorbe a la spec 086 (`086-exportacion-excel-inventario`,
exportación básica de 7 columnas, ya implementada) — ver Assumptions. La 086 queda marcada como
superada en su propio documento, sin reescribirla.

**Input**: User description: "Como administrador de un negocio en el sistema multi-tenant, quiero
poder exportar mi inventario actual en un formato de Excel idéntico al de la plantilla de
importación, para facilitar la actualización masiva de precios, stock o datos de productos
mediante un flujo de ida y vuelta (exportar, editar y volver a importar) sin errores de
estructura. Debe validar estructura y campos al importar, reportar errores por fila, permitir
actualizar productos existentes (por SKU/código) y crear nuevos, procesar archivos grandes en
segundo plano sin bloquear la aplicación, aislar estrictamente por negocio (tenant), y mostrar al
finalizar un resumen de creados/actualizados/fallidos con reporte de errores descargable."

## Aclaraciones previas (resueltas antes de escribir esta spec)

Antes de redactar, se verificó contra el código real y se resolvieron 3 decisiones con el
solicitante (no quedan como `[NEEDS CLARIFICATION]`):

1. **Identificador para upsert**: hoy el insumo de inventario no tiene ningún campo tipo
   SKU/código — se decidió **agregar un atributo nuevo "código"** al insumo (ver Key Entities y
   FR-003), en vez de usar el UUID interno (ilegible para edición manual) o el nombre (ambiguo y
   frágil ante renombres).
2. **Relación con la spec 086**: esta spec **reemplaza y absorbe** la exportación básica ya
   implementada en la spec 086, en vez de mantener dos exportaciones de inventario distintas o
   editar el documento de la 086 directamente.
3. **Alcance de columnas**: la plantilla única incluye, además de los campos base del insumo, los
   datos del **proveedor preferido** del insumo (presentación, factor de conversión, último costo
   pagado — spec 106/107), no solo los 7 campos básicos que ya exportaba la spec 086.

## Clarifications

### Session 2026-10-10

- Q: ¿Qué tan grande debe asumir el sistema que será un archivo de importación de inventario, en
  número de filas? → A: hasta unas pocas centenas de filas (≈500), tamaño típico de un negocio
  pequeño/mediano como el de este sistema (ej. spec 086 ya usaba 120 insumos como ejemplo de
  trabajo).
- Q: Si el trabajo de importación se interrumpe a mitad de camino (falla o reinicio del servidor)
  después de aplicar algunas filas pero antes de terminar el archivo completo, ¿qué pasa con las
  filas ya aplicadas? → A: quedan aplicadas tal cual; el resumen final refleja solo lo que se
  alcanzó a procesar, y el resto queda marcado como no procesado para que el administrador
  reintente subiendo el mismo archivo (las filas ya aplicadas se actualizan de forma idéntica, sin
  duplicarse, porque el emparejamiento es por código).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Exportar el inventario en el mismo formato que se usará para importar (Priority: P1)

Como administrador, quiero descargar mi inventario actual en un archivo Excel cuyas columnas,
nombres de cabecera y orden sean exactamente los mismos que usaré para volver a subirlo, para
poder editarlo (precios, stock, datos de producto) y reimportarlo sin encontrarme con errores de
estructura por una diferencia entre "lo que bajé" y "lo que el sistema espera recibir".

**Why this priority**: sin esta simetría, cualquier intento de editar y reimportar falla por
desajuste de columnas antes de llegar siquiera a validar los datos — es el cimiento de todo el
flujo de ida y vuelta.

**Independent Test**: puede probarse exportando el inventario, abriendo el archivo y confirmando
que sus columnas (nombre, orden) son idénticas a las de la plantilla/archivo que el sistema acepta
para importar, sin necesidad de llegar a subir nada todavía.

**Acceptance Scenarios**:

1. **Given** el administrador está en el módulo de Inventario con insumos registrados, **When**
   solicita la exportación a Excel, **Then** el sistema genera un archivo `.xlsx` cuya fila de
   encabezados usa exactamente los mismos nombres de columna, en el mismo orden, que el archivo
   que el sistema acepta para importar.
2. **Given** el archivo exportado, **When** el administrador lo edita (p. ej. cambia un costo o un
   stock) sin alterar las columnas, **Then** ese mismo archivo puede subirse directamente al flujo
   de importación sin ningún error de estructura.
3. **Given** un insumo sin proveedor preferido asignado, **When** se exporta, **Then** las columnas
   de proveedor preferido (presentación, factor de conversión, último costo) quedan en blanco para
   esa fila, sin que eso sea un error.

---

### User Story 2 - Importar el archivo con validación por fila y creación/actualización por código (Priority: P1)

Como administrador, quiero subir un archivo Excel (exportado por el sistema o basado en la
plantilla oficial) para crear insumos nuevos o actualizar los existentes de forma masiva, y que el
sistema me diga exactamente qué fila tiene un problema y por qué, para poder corregirla sin tener
que adivinar ni perder el resto de los cambios válidos del mismo archivo.

**Why this priority**: es el otro extremo del flujo de ida y vuelta — sin esto, exportar un
archivo simétrico (Historia 1) no tiene ningún beneficio práctico. Junto con la Historia 1 ya
conforma el producto mínimo viable.

**Independent Test**: puede probarse subiendo un archivo con una mezcla de filas válidas,
filas que actualizan insumos existentes (con su código), filas que crean insumos nuevos, y filas
con errores deliberados (texto donde se espera un número, un campo obligatorio vacío, un tipo que
no es "Materia prima" ni "Empacado") — y verificando que las filas válidas se aplican y las
inválidas se reportan individualmente, sin perder las válidas.

**Acceptance Scenarios**:

1. **Given** una fila del archivo cuyo código coincide con un insumo ya registrado, **When** se
   importa, **Then** ese insumo se actualiza con los valores de la fila (no se crea un duplicado).
2. **Given** una fila del archivo cuyo código no coincide con ningún insumo existente, **When** se
   importa, **Then** se crea un insumo nuevo con esos valores.
3. **Given** una fila con un campo obligatorio vacío, un precio no numérico, o un tipo que no es
   "Materia prima" ni "Empacado", **When** se importa el archivo, **Then** esa fila específica se
   reporta como fallida con un motivo entendible, y el resto de las filas válidas del mismo
   archivo se procesan igual.
4. **Given** un archivo con la estructura de columnas alterada (columna faltante, renombrada o
   fuera de orden), **When** se intenta importar, **Then** el sistema rechaza el archivo completo
   antes de procesar ninguna fila, indicando el problema de estructura.

---

### User Story 3 - Importar archivos grandes sin bloquear la aplicación (Priority: P2)

Como administrador, quiero poder subir un archivo con muchos insumos sin que la pantalla se
congele ni tenga que esperar con la ventana abierta hasta que termine, para poder seguir usando el
sistema mientras la importación se procesa.

**Why this priority**: mejora la experiencia para el caso de archivos grandes, pero el valor
central del flujo (Historias 1 y 2) ya funciona sin esto para archivos pequeños — es una mejora de
robustez y escala, no el núcleo de la funcionalidad.

**Independent Test**: puede probarse subiendo un archivo con una cantidad considerable de filas y
confirmando que la interfaz queda libre para seguir navegando mientras la importación se procesa
en segundo plano, hasta que el resultado queda disponible.

**Acceptance Scenarios**:

1. **Given** el administrador sube un archivo para importar, **When** el sistema recibe el
   archivo, **Then** confirma de inmediato que la importación quedó en proceso, sin obligar al
   administrador a mantener la pantalla abierta esperando una respuesta síncrona.
2. **Given** una importación en curso, **When** el administrador navega a otra pantalla del
   sistema o cierra y vuelve a abrir la pantalla de Inventario, **Then** puede seguir usando el
   sistema con normalidad y, al volver, encuentra el resultado de la importación (en curso o ya
   finalizada).
3. **Given** que ya hay una importación en curso para el mismo negocio, **When** el administrador
   intenta subir un segundo archivo antes de que termine la primera, **Then** el sistema le indica
   que ya hay una importación en curso y no permite iniciar una segunda en paralelo sobre el mismo
   inventario.

---

### User Story 4 - Ver el resultado de la importación y descargar el reporte de errores (Priority: P2)

Como administrador, quiero ver un resumen claro de cuántos insumos se crearon, cuántos se
actualizaron y cuántos fallaron al terminar una importación, y poder descargar el detalle de los
que fallaron, para saber si necesito corregir algo y volver a intentarlo solo con esas filas.

**Why this priority**: cierra el ciclo de confianza del flujo asíncrono (Historia 3) — sin esto, el
administrador no tiene forma de saber si su importación realmente funcionó. Depende de que la
importación ya exista (Historias 2 y 3).

**Independent Test**: puede probarse completando una importación con una mezcla de filas exitosas
y fallidas, y verificando que el resumen en pantalla muestra los tres conteos correctos y que el
reporte de errores descargable contiene exactamente las filas que fallaron con su motivo.

**Acceptance Scenarios**:

1. **Given** una importación que termina de procesarse, **When** el administrador consulta su
   resultado, **Then** ve un resumen con la cantidad de insumos creados, actualizados y fallidos.
2. **Given** una importación con al menos una fila fallida, **When** el administrador lo revisa,
   **Then** puede descargar un archivo con el detalle de cada fila fallida y el motivo del fallo.
3. **Given** una importación sin ninguna fila fallida, **When** el administrador lo revisa,
   **Then** el resumen lo indica claramente y no se ofrece un reporte de errores vacío.

---

### Edge Cases

- Inventario vacío: la exportación sigue entregando un archivo válido solo con encabezados (igual
  que el comportamiento ya existente de la spec 086).
- Archivo de importación vacío (solo encabezados, sin filas de datos): se acepta y no crea ni
  actualiza nada; el resumen muestra 0/0/0.
- Fila con código duplicado dentro del mismo archivo de importación: se reporta como fila fallida
  (ambigüedad sobre cuál de las dos aplicar), sin aplicar ninguna de las dos.
- Fila con un nombre de unidad de medida o de proveedor preferido que no existe para el negocio:
  **no se reporta como fallida** — el sistema lo consolida creando la unidad o el proveedor que
  falte, comparando y guardando siempre en MAYÚSCULA (sin distinguir cómo venía escrito en el
  Excel), para que "kg"/"Kg"/"KG" no terminen como tres registros distintos por error de tipeo.
  Un proveedor existente pero inactivo que coincida se reactiva en vez de duplicarse. Sigue siendo
  fallida si el texto coincide, sin distinguir mayúsculas, con más de un registro ya existente
  (dato ambiguo que el administrador debe resolver a mano) — research.md D7.
- Un insumo existente sin proveedor preferido asignado: si la fila de importación correspondiente
  trae datos de proveedor preferido, se usan para asignarlo o actualizarlo; si los trae en blanco,
  el insumo simplemente no tiene o conserva el que ya tenía (no se borra un proveedor preferido
  existente solo porque la fila llegó sin esos datos, salvo que el administrador los borre
  explícitamente en el archivo con un valor reconocible como "ninguno" — el comportamiento exacto
  de borrado explícito queda para la fase de planeación).
- Un usuario sin el rol autorizado para el módulo de Inventario no puede exportar ni importar,
  igual que hoy no puede ver la tabla de Inventario.
- Insumos inactivos (dados de baja): se incluyen en la exportación igual que los activos (mismo
  comportamiento ya validado por la spec 086); importar una fila sobre un insumo inactivo lo
  actualiza sin reactivarlo automáticamente, salvo que la fila incluya explícitamente un cambio de
  estado activo/inactivo.
- Caracteres especiales (tildes, eñes, comillas) en nombres de insumo o proveedor: se exportan e
  importan sin corrupción, igual que el comportamiento ya validado por la spec 086.
- Si la importación falla por completo antes de procesar cualquier fila (p. ej. el archivo no es
  un Excel válido), el sistema lo informa de inmediato, sin dejar una importación "en proceso" que
  nunca termine.
- Si el proceso en segundo plano se interrumpe a mitad de camino (falla o reinicio del servidor)
  después de aplicar algunas filas, esas filas quedan aplicadas tal cual; el resumen final refleja
  solo lo procesado hasta ese punto, y el resto del archivo queda marcado como no procesado — no
  como fallido por un motivo de datos — para que el administrador pueda reintentarlo resubiendo el
  mismo archivo sin duplicar lo que ya se aplicó (el emparejamiento por código lo vuelve a
  actualizar, no a crear de nuevo).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST generar el archivo de exportación de inventario con exactamente la
  misma estructura de columnas (nombres de cabecera y orden) que el sistema exige para el archivo
  de importación — una sola definición de plantilla para ambos sentidos.
- **FR-002**: La plantilla única de columnas MUST incluir, como mínimo: código del insumo, nombre,
  tipo, unidad, stock, stock mínimo, costo, y — cuando el insumo tenga un proveedor preferido
  asignado — su presentación, factor de conversión y último costo pagado a ese proveedor.
- **FR-003**: El sistema MUST incorporar un atributo "código" al insumo de inventario, único por
  negocio (tenant), que no existe hoy. Todo insumo ya existente MUST recibir un código asignado
  automáticamente como parte de esta funcionalidad (no queda ningún insumo sin código), y todo
  insumo nuevo MUST recibir uno automáticamente si no se especifica uno al crearlo.
- **FR-004**: La exportación MUST incluir el total de insumos registrados del negocio autenticado,
  activos e inactivos, sin importar filtros o búsquedas activas en pantalla — mismo criterio ya
  vigente en la spec 086.
- **FR-005**: Antes de procesar cualquier fila, el sistema MUST validar que la estructura del
  archivo subido (columnas, nombres, orden) corresponda a la plantilla definida en FR-001/FR-002,
  rechazando el archivo completo si no corresponde.
- **FR-006**: Superada la validación de estructura, el sistema MUST validar cada fila de forma
  independiente (campos obligatorios presentes, precios y cantidades numéricos) y continuar
  procesando el resto del archivo aunque una fila falle.
- **FR-006a**: Cuando la unidad o el proveedor preferido de una fila no coincide (sin distinguir
  mayúsculas/minúsculas) con ninguno ya existente para ese negocio, el sistema MUST consolidarlo
  creándolo automáticamente — nunca reportar la fila como fallida solo por eso. El texto se
  compara y se guarda siempre en MAYÚSCULA, sin importar cómo venía escrito en el Excel. Si
  coincide con un proveedor existente pero inactivo, el sistema MUST reactivarlo en vez de crear
  un duplicado. Sigue siendo fila fallida cuando el texto coincide, ignorando mayúsculas, con más
  de un registro ya existente (research.md D7).
- **FR-007**: Cuando el código de una fila coincide con un insumo ya existente del mismo negocio,
  el sistema MUST actualizar ese insumo; cuando no coincide con ninguno, MUST crear un insumo
  nuevo con ese código (o uno asignado automáticamente si la fila lo deja en blanco).
- **FR-008**: El sistema MUST reportar cada fila fallida con un motivo entendible (qué campo, qué
  problema), sin detener el procesamiento de las demás filas del mismo archivo.
- **FR-009**: El procesamiento de un archivo de importación MUST ejecutarse en segundo plano, de
  forma que el administrador reciba confirmación de que quedó en proceso sin tener que esperar una
  respuesta síncrona ni mantener la pantalla abierta.
- **FR-010**: El sistema MUST impedir que un mismo negocio tenga más de una importación de
  inventario en curso al mismo tiempo.
- **FR-011**: Al finalizar una importación, el sistema MUST mostrar un resumen con la cantidad de
  insumos creados, actualizados y fallidos.
- **FR-012**: Cuando una importación tenga al menos una fila fallida, el sistema MUST permitir
  descargar un reporte con el detalle de cada fila fallida y su motivo.
- **FR-013**: Tanto la exportación como la importación MUST operar exclusivamente sobre los datos
  del negocio (tenant) del usuario autenticado — ningún dato de otro negocio puede leerse, crearse
  ni modificarse a través de estas dos operaciones.
- **FR-014**: El acceso a exportar e importar inventario MUST restringirse al mismo rol que hoy
  tiene acceso a ver y editar la tabla de Inventario — mismo criterio ya vigente en la spec 086.
- **FR-015**: Si el procesamiento en segundo plano se interrumpe antes de terminar el archivo
  completo, el sistema MUST NOT revertir las filas ya aplicadas; el resumen final MUST reflejar
  únicamente lo procesado hasta la interrupción, dejando el resto del archivo como no procesado
  para que el administrador lo reintente resubiendo el mismo archivo, sin que eso duplique las
  filas que ya se habían aplicado.

### Key Entities *(include if feature involves data)*

- **Insumo de Inventario**: entidad ya existente (nombre, tipo, unidad, stock, stock mínimo, costo,
  activo); esta funcionalidad le agrega el atributo nuevo **código**, único por negocio, usado
  como identificador estable para el upsert de importación.
- **Relación Proveedor-Insumo (preferida)**: entidad ya existente (spec 106/107): presentación,
  factor de conversión, último costo pagado. Para esta funcionalidad solo interesa la relación
  marcada como preferida de cada insumo (como mucho una por insumo); el resto de proveedores
  vinculados a un insumo no viaja en el archivo de export/import.
- **Plantilla de Inventario**: la definición única y compartida de columnas (nombres, orden, tipo
  de dato esperado por columna) que usan tanto la exportación como la importación — es el contrato
  que hace posible el flujo de ida y vuelta sin errores de estructura.
- **Resultado de Importación**: el seguimiento de un proceso de importación del negocio —su
  estado (en proceso / finalizado), y al finalizar, cuántas filas se crearon, actualizaron o
  fallaron, más el detalle de las fallidas para el reporte descargable.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un administrador puede actualizar precios o stock de todo su inventario exportando,
  editando en una hoja de cálculo y reimportando el mismo archivo, sin encontrarse con ningún
  error de estructura y sin tener que volver a escribir manualmente ningún insumo que ya existía.
- **SC-002**: El 100% de las filas inválidas de un archivo de importación se reportan
  individualmente con un motivo entendible, sin impedir que las filas válidas del mismo archivo se
  apliquen.
- **SC-003**: Subir un archivo de importación de hasta aproximadamente 500 filas (el tamaño
  esperado del inventario de un negocio en este sistema) no impide que el administrador siga
  usando el resto del sistema mientras se procesa.
- **SC-004**: Ningún negocio puede, a través de la exportación o la importación, leer o modificar
  el inventario de otro negocio — verificable en el 100% de los intentos.
- **SC-005**: Al finalizar una importación, el administrador conoce cuántos insumos se crearon,
  actualizaron y fallaron sin necesitar ayuda externa para interpretarlo, y puede descargar el
  detalle de los fallidos cuando los hay.

## Assumptions

- **Supersede la spec 086**: la exportación básica de 7 columnas ya implementada por la spec 086
  queda absorbida por la plantilla única de esta spec (FR-001/FR-002), que la amplía con el código
  del insumo y los datos del proveedor preferido. La columna "Estado" (Normal/Stock bajo/Agotado)
  de la spec 086 es un valor calculado, no un dato editable, así que no forma parte de la plantilla
  compartida de export/import — el administrador sigue viéndolo en la pantalla de Inventario como
  hoy, fuera de este archivo.
- El código del insumo es un identificador de negocio, no necesariamente visible/editable salvo a
  través de este flujo o de la ficha del insumo; su formato exacto (numérico, alfanumérico, con
  prefijo) queda a criterio de la fase de planeación, siempre que sea único por negocio.
- Todas las importaciones se procesan en segundo plano, sin distinguir un camino síncrono para
  archivos pequeños y uno asíncrono para archivos grandes — un solo mecanismo para cualquier
  tamaño, para no mantener dos caminos de código distintos para el mismo resultado.
- El aislamiento por negocio (tenant) de los datos de inventario ya está garantizado
  estructuralmente por cómo el sistema separa los datos de cada negocio a nivel de base de datos;
  esta funcionalidad no introduce un mecanismo de aislamiento nuevo, solo opera dentro de esa
  garantía ya existente.
- El resultado de una importación (resumen y reporte de errores) queda disponible para
  consultarlo mientras sea relevante para el administrador que la inició; esta funcionalidad no
  requiere un historial permanente de importaciones pasadas.
- Actualizar una fila sobre un insumo existente no reactiva ni desactiva el insumo por sí solo,
  salvo que la fila incluya explícitamente ese cambio — evita que una actualización masiva de
  precios reactive por accidente insumos dados de baja intencionalmente.
- El tamaño esperado de un archivo de importación es de hasta aproximadamente 500 filas (ver
  Clarifications) — el diseño de la fase de planeación no necesita optimizar para catálogos de
  miles o decenas de miles de insumos; esta funcionalidad no está pensada para negocios de ese
  tamaño.
