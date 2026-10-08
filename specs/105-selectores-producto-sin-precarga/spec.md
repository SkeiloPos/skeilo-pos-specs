# Feature Specification: Quitar la precarga de catálogos completos en los selectores del formulario de producto (categoría, insumos, presentación)

**Feature Branch**: `105-selectores-producto-sin-precarga`

**Created**: 2026-10-08

**Status**: Draft

**Naturaleza de esta spec**: **spec de corrección/mejora de rendimiento**, continuación directa de
las specs [102](../102-fix-formulario-producto-catalogos/spec.md) (agregó búsqueda del lado del
servidor sin tope fijo a los selectores de insumos, categoría y presentación) y
[103](../103-detalle-producto-consolidado/spec.md) (consolidó receta y grupos de opciones —y ya
antes incluía nombre de categoría y de presentación— en una sola respuesta del detalle de
producto). Esta spec retira las tres peticiones de precarga de catálogo completo que **todavía**
se disparan al abrir el formulario de crear/editar producto, apoyándose en que: (a) el detalle de
producto (spec 103 y, para categoría, spec 097) ya trae el nombre real de la categoría y de la
presentación ya seleccionadas sin necesitar el catálogo completo, y (b) la búsqueda remota (spec
102) ya permite encontrar y elegir cualquier registro activo del catálogo sin depender de esa
precarga. No reabre ninguna regla de negocio sobre qué insumos, categorías o presentaciones son
válidos para un producto, ni cambia la forma en que se guarda: el alcance es exclusivamente cómo
se cargan y se muestran las opciones de los tres selectores dentro del formulario de producto.

**Autorización de negocio (Principio I y Principio II de la
[Constitución](../../.specify/memory/constitution.md))**: reportado directamente por el
dueño/desarrollador del proyecto el 2026-10-08, con una captura del panel de red del navegador
mostrando las tres peticiones de precarga descritas en el Input. No aplica entrada en
`registro-de-anomalias.md`: ninguno de los puntos reabre una regla de negocio ya decidida sobre
qué insumos, categorías o presentaciones son válidos para un producto, ni sobre cómo se guarda —
solo corrige cómo se **cargan** las opciones de los selectores.

**Input**: User description (verbatim): "quiero remover el llamado de estos endpoint para
precargar valores en los selectores, el selector se debe llenar tal con la informacion que
devuelva el endpoint de obtener detalle del producto, y cada selector debera ejecutar su
respectivo endpoint de busqueda y mostrar los resultados en las opciones tal como venia haciendo".
Adjuntó una captura del panel de red del navegador mostrando, al abrir el formulario de producto,
tres peticiones: `categories?size=100`, `items?size=100` y `presentations?size=100`.

**Causa raíz (confirmada leyendo el código real de `pos-heladeria`)**: al abrir el formulario de
crear/editar producto, además de pedir el detalle del producto (si se está editando), el
formulario sigue disparando tres peticiones adicionales para precargar hasta 100 registros
activos de categorías, insumos y presentaciones — el mismo patrón de precarga ("`wantsAll`") que
la spec 102 ya dejó documentado y cuya búsqueda sin tope (Historia 3 de esa spec) resolvió, pero
sin retirar la precarga original que la acompañaba. El mecanismo que hoy resuelve el nombre real
del valor **ya seleccionado** en cada selector no depende en realidad de esa precarga: la
categoría y la presentación ya seleccionadas se resuelven con el nombre que trae el propio detalle
de producto (spec 097 y spec 103), y el insumo ya seleccionado en una fila de receta o de consumo
de opción se resuelve por su id puntual cuando no aparece en la lista precargada (fix de la spec
102, Historia 1). Es decir: la precarga de catálogo completo ya es, hoy, puramente redundante para
mostrar el valor seleccionado — su único efecto observable restante es ofrecer hasta 100 opciones
"por defecto" en el desplegable antes de que el usuario escriba algo a buscar, lo cual añade tres
peticiones de red innecesarias a la apertura del formulario sin las cuales la búsqueda remota
(spec 102) sigue funcionando exactamente igual.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Abrir el formulario de producto no dispara peticiones de catálogo completo (Priority: P1)

Un Administrador que abre el formulario para crear o editar un producto ya no genera, como parte
de esa apertura, ninguna petición que traiga hasta 100 registros activos de categorías, insumos o
presentaciones — esas tres peticiones dejan de dispararse por completo al abrir el formulario.

**Why this priority**: es el defecto reportado directamente y la causa de la latencia innecesaria
observada en el panel de red; es la base de la que dependen las otras dos historias.

**Independent Test**: con las herramientas de red del navegador abiertas, abrir el formulario de
crear un producto nuevo y el de editar uno existente, y verificar que no se dispara ninguna
petición que traiga la lista paginada completa de categorías, insumos o presentaciones en ninguno
de los dos casos.

**Acceptance Scenarios**:

1. **Given** el formulario de producto está cerrado, **When** un Administrador abre el formulario
   para crear un producto nuevo, **Then** no se dispara ninguna petición que traiga el catálogo
   completo (paginado) de categorías, insumos ni presentaciones.
2. **Given** el formulario de producto está cerrado, **When** un Administrador abre el formulario
   para editar un producto existente, **Then** tampoco se dispara ninguna de esas tres peticiones,
   más allá de la petición que trae el detalle del producto que se está editando.
3. **Given** el Administrador ya tiene el formulario abierto, **When** agrega una fila nueva de
   receta o abre cualquiera de los tres selectores sin escribir texto de búsqueda, **Then**
   tampoco se dispara ninguna petición de catálogo completo solo por abrir el desplegable.

---

### User Story 2 - Un valor ya seleccionado siempre muestra su nombre real, usando el detalle del producto (Priority: P1)

Un Administrador que abre para editar un producto ve, en cada uno de los tres selectores
(categoría, presentación de cada tamaño, insumos de la receta y del consumo de opción), el nombre
real del valor ya guardado — usando exclusivamente la información que devuelve el detalle del
producto que se está editando, sin necesitar que ese valor esté presente en ningún catálogo
precargado.

**Why this priority**: es **P1** junto con la Historia 1 porque sin esta garantía, quitar la
precarga (Historia 1) volvería a introducir el defecto que la spec 102 ya corrigió (el selector
mostrando un texto genérico en vez del nombre real del valor ya guardado).

**Independent Test**: editar un producto que tenga una categoría, una presentación y al menos un
insumo de receta ya guardados, y verificar que los tres selectores muestran el nombre real de cada
valor ya seleccionado apenas se abre el formulario, sin que el Administrador tenga que buscar nada.

**Acceptance Scenarios**:

1. **Given** un producto tiene una categoría ya guardada, **When** abro su formulario de edición,
   **Then** el selector de categoría muestra el nombre real de esa categoría de inmediato.
2. **Given** un tamaño del producto tiene una presentación ya guardada, **When** abro el
   formulario de edición, **Then** el selector de presentación de ese tamaño muestra el nombre
   real de esa presentación de inmediato.
3. **Given** una fila de receta o de consumo de opción tiene un insumo ya guardado, **When** abro
   el formulario de edición, **Then** el selector de ese insumo muestra su nombre real de
   inmediato, sin mostrar nunca un texto genérico tipo "Insumo…".
4. **Given** la categoría, presentación o insumo ya seleccionados fueron desactivados después de
   guardarse, **When** abro el formulario de edición, **Then** su nombre real se sigue mostrando
   igual (no se pierde la trazabilidad de lo ya guardado), aunque ya no aparezcan como opción
   seleccionable para un valor nuevo.
5. **Given** estoy creando un producto nuevo (sin ningún valor guardado todavía), **When** abro el
   formulario, **Then** los tres selectores aparecen vacíos (sin ningún valor preseleccionado),
   listos para que el Administrador busque y elija.

---

### User Story 3 - Buscar en cualquiera de los tres selectores sigue funcionando exactamente igual que antes (Priority: P2)

Un Administrador que escribe texto en el selector de categoría, insumos o presentación sigue
encontrando y pudiendo elegir cualquier registro activo que coincida con lo escrito, con el mismo
comportamiento de búsqueda que ya existía antes de esta corrección (spec 102): insensible a
mayúsculas/minúsculas y tildes, sin tope fijo de cantidad, excluyendo siempre los registros
inactivos.

**Why this priority**: es **P2** porque no es el defecto reportado en sí, sino la garantía
explícita de que quitar la precarga (Historia 1) no afecta ni degrada la búsqueda que ya
funcionaba — es una condición de "no regresión" más que una mejora nueva.

**Independent Test**: en un selector de cada tipo, escribir el nombre (o parte del nombre) de un
registro activo existente y verificar que aparece como opción seleccionable, con el mismo
comportamiento (mayúsculas/minúsculas, tildes, exclusión de inactivos) documentado en la spec 102.

**Acceptance Scenarios**:

1. **Given** un tenant tiene registros activos de categorías, insumos y presentaciones, **When**
   escribo parte del nombre de uno de ellos en su selector correspondiente, **Then** el selector lo
   encuentra y permite seleccionarlo, sin importar cuántos registros activos tenga ese catálogo.
2. **Given** abro cualquiera de los tres selectores sin escribir ningún texto de búsqueda, **When**
   reviso las opciones mostradas, **Then** no veo una lista por defecto de hasta 100 registros del
   catálogo (ese comportamiento se retira); veo únicamente el valor ya seleccionado (si lo hay) y
   un mensaje que invita a escribir para buscar.
3. **Given** estoy escribiendo en cualquiera de los tres selectores, **When** la búsqueda está en
   curso, **Then** el selector indica que está cargando y no muestra "Sin resultados" antes de
   tiempo — mismo comportamiento que ya existía.
4. **Given** un insumo, categoría o presentación está inactivo, **When** lo busco en su selector
   correspondiente, **Then** no aparece como opción para seleccionarse de nuevo — mismo
   comportamiento que ya existía.

---

### Edge Cases

- ¿Qué pasa si falla por red la petición del detalle del producto al abrir el formulario de
  edición? El formulario debe comportarse igual que hoy ante ese mismo fallo; ningún selector
  queda con un valor a medio resolver.
- ¿Qué pasa si falla por red una búsqueda en curso en cualquiera de los tres selectores? Debe
  mostrarse un error distinto de "sin resultados", con opción de reintentar, igual que ya definía
  la spec 102.
- ¿Qué pasa con una receta o un detalle de opción guardados con varios insumos a la vez? Cada uno
  debe mostrar su nombre real apenas se abre el formulario, sin que el número de insumos ya
  guardados introduzca una demora perceptible adicional frente al comportamiento actual.
- ¿Qué pasa si el Administrador abre un selector, no encuentra lo que busca y cierra el
  desplegable sin elegir nada? El valor ya seleccionado (si lo había) se mantiene sin cambios.
- ¿Qué pasa con las otras pantallas del sistema que también usan el catálogo completo de
  categorías, insumos o presentaciones (por ejemplo: páginas de Categorías, Presentaciones,
  Inventario, Compras, Grupos de opciones y Promociones)? No deben verse afectadas por este
  cambio: siguen cargando el catálogo que necesitan de la misma forma que hoy; el alcance de esta
  spec es exclusivamente la apertura del formulario de crear/editar producto.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Abrir el formulario de crear un producto NO DEBE disparar ninguna petición que traiga
  el catálogo completo (paginado) de categorías, insumos ni presentaciones.
- **FR-002**: Abrir el formulario de editar un producto existente NO DEBE disparar ninguna petición
  que traiga el catálogo completo (paginado) de categorías, insumos ni presentaciones, más allá de
  la petición que trae el detalle del producto que se está editando.
- **FR-003**: Cada uno de los tres selectores del formulario de producto (categoría, presentación,
  insumos) DEBE mostrar el nombre real de su valor ya seleccionado usando exclusivamente la
  información que devuelve el detalle del producto que se está editando, sin depender de que ese
  valor esté incluido en ningún catálogo precargado.
- **FR-004**: Al crear un producto nuevo (sin ningún valor guardado todavía), los tres selectores
  DEBEN aparecer sin ningún valor preseleccionado.
- **FR-005**: Cada uno de los tres selectores DEBE seguir permitiendo buscar por texto parcial y
  encontrar cualquier registro activo del catálogo correspondiente, ejecutando su propio mecanismo
  de búsqueda remota (el mismo ya definido por la spec 102), sin ningún cambio observable en ese
  comportamiento de búsqueda.
- **FR-006**: Abrir cualquiera de los tres selectores sin escribir texto de búsqueda NO DEBE
  mostrar una lista por defecto de registros del catálogo; debe mostrar únicamente el valor ya
  seleccionado (si lo hay).
- **FR-007**: Un valor ya seleccionado (categoría, presentación o insumo) que haya sido desactivado
  después de guardarse DEBE seguir mostrando su nombre real al reabrir el formulario de edición,
  aunque ya no sea seleccionable como valor nuevo — mismo comportamiento ya vigente (spec 102).
- **FR-008**: Esta corrección NO DEBE cambiar el comportamiento de ninguna otra pantalla que
  también use el catálogo completo de categorías, insumos o presentaciones (por ejemplo: páginas
  de Categorías, Presentaciones, Inventario, Compras, Grupos de opciones y Promociones); el alcance
  es exclusivamente el formulario de crear/editar producto.
- **FR-009**: Esta corrección NO DEBE cambiar la forma en que se guarda el producto: crear y editar
  un producto siguen guardando toda la información en una sola petición, sin cambios en ese
  contrato.
- **FR-010**: Mostrar el nombre real de los valores ya seleccionados (FR-003) al abrir el
  formulario de edición NO DEBE introducir una demora perceptible adicional frente al
  comportamiento actual, sin importar cuántos insumos tenga la receta o el consumo de opciones del
  producto.

### Key Entities *(include if feature involves data)*

- **Categoría, Insumo (Inventory Item), Presentación**: catálogos del tenant que el formulario de
  producto consume como opciones de selección. Ya existen y no cambian su modelo de datos; esta
  corrección solo cambia qué petición trae el nombre del valor ya seleccionado (el detalle del
  producto, en vez del catálogo completo) y cuándo se dispara la búsqueda de cada selector (solo
  cuando el usuario escribe, nunca al abrir el formulario).
- **Producto / Variante (tamaño) / Receta / Grupo de opciones**: ya existen (ver specs 102 y 103);
  esta corrección no cambia su modelo de datos ni su contenido, solo reutiliza la información que
  el detalle del producto ya devuelve para resolver los nombres mostrados en los tres selectores.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Abrir el formulario de crear o editar un producto genera cero peticiones de red que
  traigan el catálogo completo (paginado) de categorías, insumos o presentaciones.
- **SC-002**: El 100% de las categorías, presentaciones e insumos ya guardados en un producto
  muestran su nombre real al abrir el formulario de edición, verificado en al menos un tenant con
  más de 100 registros activos en cada uno de los tres catálogos.
- **SC-003**: El 100% de los insumos, categorías y presentaciones activas de un tenant siguen
  siendo encontrables desde su selector correspondiente mediante búsqueda por texto parcial, sin
  cambio respecto al comportamiento medido en la spec 102.
- **SC-004**: El número de peticiones de red necesarias para dejar el formulario de producto listo
  para usarse se reduce en tres frente al comportamiento anterior a esta corrección, sin aumentar
  en ningún otro escenario.
- **SC-005**: Ninguna otra pantalla del sistema que dependa del catálogo completo de categorías,
  insumos o presentaciones (Categorías, Presentaciones, Inventario, Compras, Grupos de opciones,
  Promociones) presenta cambios de comportamiento verificables tras esta corrección.

## Assumptions

- Se asume que "la información que devuelva el endpoint de obtener detalle del producto" (Input)
  se refiere al mismo endpoint de detalle de producto ya consolidado por la spec 103 (incluye
  nombre de categoría, nombre de presentación por tamaño, y los ids de insumo de receta/consumo de
  opción), y no a un endpoint nuevo — esta spec no agrega ningún campo nuevo a esa respuesta.
- Se asume que la resolución del nombre real de un insumo ya seleccionado que no viene embebido
  por nombre en el detalle del producto (solo su id, ver spec 103) sigue el mismo mecanismo de
  resolución puntual por id ya introducido por la spec 102 (Historia 1), ahora usado como único
  camino en vez de como respaldo de la precarga — sin introducir un mecanismo de resolución nuevo
  o distinto.
- Se asume que "tal como venia haciendo" (Input) significa que el mecanismo de búsqueda remota de
  cada selector (spec 102: insensible a mayúsculas/tildes, sin tope fijo, excluyendo inactivos) no
  cambia en absoluto; lo único que cambia es que ya no hay una lista por defecto visible antes de
  escribir.
- Se asume que al abrir cualquiera de los tres selectores sin texto de búsqueda, mostrar un mensaje
  que invite a escribir (en vez de una lista vacía sin explicación) es un detalle de presentación
  razonable, no una decisión de negocio que requiera confirmación aparte.
- Se asume que esta corrección no afecta a ninguna otra pantalla fuera del formulario de
  crear/editar producto: los demás consumidores del catálogo completo de categorías, insumos y
  presentaciones (páginas de Categorías, Presentaciones, Inventario, Compras, Grupos de opciones,
  Promociones) siguen cargando su propio catálogo de forma independiente, sin cambios.
