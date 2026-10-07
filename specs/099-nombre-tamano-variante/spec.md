# Feature Specification: Nombre comercial propio para los tamaños de un producto

**Feature Branch**: `099-nombre-tamano-variante`

**Created**: 2026-10-06

**Status**: Draft

**Input**: User description (verbatim, resumen): "Como administrador de un tenant, quiero ponerle un
nombre propio a cada tamaño de un producto, sin que sea obligatorio, para que mis clientes vean
nombres comerciales como 'Para compartir' y que, si no lo escribo, sigan viendo el nombre de la
presentación." Incluye 18 escenarios de aceptación detallados por el solicitante, cubiertos en su
totalidad en las historias de usuario y requisitos de abajo.

---

## Clarifications

### Session 2026-10-06

- Q: Al validar que no haya dos tamaños del mismo producto con la misma etiqueta visible (FR-008),
  ¿la comparación debe incluir también los tamaños desactivados (soft-deleted) de ese producto, o
  solo los tamaños activos? → A: Solo los tamaños activos; un nombre puede repetirse si la única
  variante que lo tenía está desactivada.
- Q: Para detectar nombres duplicados dentro de un mismo producto (FR-008), ¿dos etiquetas que solo
  difieren en mayúsculas/minúsculas ("Para compartir" vs. "para COMPARTIR") deben contarse como el
  mismo tamaño, o como tamaños distintos? → A: Mismo tamaño; la comparación es insensible a
  mayúsculas y minúsculas.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - El comensal ve el nombre comercial del tamaño, no uno vacío (Priority: P1)

Un comensal que navega el menú público de un tenant (detalle del producto, carrito y resumen del
checkout) ve, para cada tamaño, su nombre comercial cuando el administrador le puso uno propio (por
ejemplo "Para compartir"), o el nombre de la presentación (por ejemplo "Pequeño 8 onz") cuando el
administrador no le puso ninguno. En ningún caso ve una etiqueta vacía.

**Why this priority**: es el valor final que el negocio pidió ("que mis clientes vean nombres
comerciales") y el que justifica toda la funcionalidad. Sin esta historia, nombrar un tamaño desde
el formulario no tendría ningún efecto observable.

**Independent Test**: con un producto que tiene una variante con nombre propio y otra sin nombre,
abrir el detalle del producto en el menú público y verificar que cada una muestra el texto
correcto; elegir el tamaño con nombre propio y verificar que el carrito y el resumen del checkout
muestran ese mismo nombre.

**Acceptance Scenarios**:

1. **Given** una variante tiene `name` = "Para compartir" y presentación "Grande 16 onz", **When**
   un comensal abre el detalle del producto, **Then** ve "Para compartir" como nombre del tamaño.
2. **Given** una variante tiene `name` = '' y presentación "Pequeño 8 onz", **When** un comensal
   abre el detalle del producto, **Then** ve "Pequeño 8 onz".
3. **Given** el comensal eligió el tamaño "Para compartir", **When** revisa el carrito y el resumen
   del checkout, **Then** ambos muestran "Para compartir".
4. **Given** `name` = '' y el dato de presentación no está disponible, **When** se calcula la
   etiqueta que ve el comensal, **Then** se devuelve "Tamaño" (nunca una etiqueta vacía) y se
   registra una advertencia técnica con el id de la variante afectada.
5. **Given** un nombre contiene HTML, como `<b>x</b>`, **When** se muestra en el menú público,
   **Then** se escapa y no se interpreta como HTML.

---

### User Story 2 - El administrador le pone, cambia o quita el nombre a un tamaño desde el formulario (Priority: P1)

Un administrador de tenant, en el formulario "Tamaños del producto", ve junto a la presentación de
cada fila un campo "Nombre (opcional)". Puede escribir un nombre comercial, dejarlo vacío, o borrar
uno que ya existía — en todos los casos puede guardar sin error, y el nombre que quede se refleja
de inmediato en lo que ve el comensal (User Story 1).

**Why this priority**: sin esta historia no hay forma de que el administrador produzca el dato que
la primera historia necesita mostrar; ambas son P1 porque ninguna por sí sola entrega valor sin la
otra, pero esta es la que el administrador opera directamente.

**Independent Test**: en "Tamaños del producto", escribir un nombre, guardarlo, y verificar que
persiste al recargar el formulario; borrar ese nombre, guardar, y verificar que la variante vuelve a
mostrar la presentación; intentar guardar un nombre de 61 caracteres o un nombre repetido dentro del
mismo producto y verificar que el sistema lo rechaza con un mensaje claro y no guarda el producto.

**Acceptance Scenarios**:

1. **Given** estoy en "Tamaños del producto", **Then** cada fila tiene el campo "Nombre
   (opcional)" junto a la presentación, puedo dejarlo vacío y guardar sin error, y al borrar un
   nombre existente y guardar, la variante vuelve a mostrar la presentación.
2. **Given** elegí la presentación "Pequeño 8 onz" y dejé el nombre vacío, **Then** el placeholder
   del campo dice "Se mostrará: Pequeño 8 onz"; **Given** aún no elegí presentación, **Then** el
   placeholder dice "Se mostrará la presentación".
3. **Given** escribo "   " (solo espacios) en el nombre de una variante y guardo, **Then** se
   guarda como '' y el menú público muestra el nombre de la presentación.
4. **Given** escribo "  Para   compartir  " y guardo, **Then** se guarda "Para compartir" (espacios
   al inicio y al final recortados, espacios repetidos colapsados a uno).
5. **Given** escribo 61 caracteres en el nombre, **Then** veo "El nombre admite hasta 60
   caracteres" y no se guarda el producto.
6. **Given** un producto tiene una variante que se muestra "Pequeño 8 onz", **When** le pongo ese
   mismo nombre a otra variante del mismo producto, o repito un nombre propio en dos variantes,
   **Then** veo "Ya existe un tamaño con ese nombre en este producto" y no se guarda.
7. **Given** un nombre contiene HTML, como `<b>x</b>`, **When** se muestra en el formulario,
   **Then** se escapa y no se interpreta como HTML.

---

### User Story 3 - Los datos y los clientes existentes no se rompen con el cambio (Priority: P2)

Las variantes ya creadas antes de esta funcionalidad siguen comportándose exactamente igual que
antes — mismo nombre mostrado, mismo precio, mismo orden — y los sistemas que ya consumen el menú
público o el historial de pedidos (frontends en caché, Órdenes, Ventas) siguen funcionando sin
errores ni cambios visibles, aunque no se hayan actualizado al mismo tiempo que el backend.

**Why this priority**: no agrega valor nuevo por sí sola, pero es la condición para que las
historias 1 y 2 puedan desplegarse en un sistema en producción sin romper nada que ya funciona; se
marca P2 porque, a diferencia de 1 y 2, no es observable para el administrador en su uso diario —
es una garantía de no regresión.

**Independent Test**: ejecutar la migración sobre datos existentes y verificar que ninguna variante
cambia su presentación, precio, orden o cantidad, y que el menú público las muestra igual que antes;
por separado, simular una petición de API que no envía el campo `name` (o lo envía como `null`) y
verificar que no hay error; y simular un cliente de menú QR con la versión anterior consultando el
endpoint público, verificando que sigue recibiendo los campos que ya conocía con el mismo
significado.

**Acceptance Scenarios**:

1. **Given** existen variantes en producción sin nombre, **When** se ejecuta la migración,
   **Then** todas quedan con `name` = '', su presentación, precio, orden y cantidad no cambian, y
   el menú público las muestra exactamente igual que antes.
2. **Given** existen pedidos creados antes del cambio, **When** se consultan en Órdenes o Ventas,
   **Then** se muestran sin modificaciones.
3. **Given** una petición de crear o editar variante no incluye `name`, o lo envía como `null`,
   **Then** el sistema lo trata como '' y no devuelve error.
4. **Given** un menú QR con la versión anterior del frontend sigue en caché, **When** consulta el
   endpoint público, **Then** recibe los campos que ya conoce con el mismo significado y sigue
   mostrando la presentación sin errores.
5. **Given** se necesita revertir el despliegue, **When** se ejecuta el downgrade de la migración,
   **Then** se elimina la columna agregada sin afectar presentaciones, precios ni pedidos.

---

### User Story 4 - Renombrar una presentación no toca los nombres propios ya puestos (Priority: P3)

Cuando el administrador renombra una presentación del catálogo (por ejemplo de "Pequeño 8 onz" a
"Pequeño 250 ml"), las variantes que no tienen nombre propio adoptan el nuevo nombre de inmediato,
mientras que las variantes que sí tienen nombre propio conservan el suyo sin cambios.

**Why this priority**: es un caso de interacción entre esta funcionalidad y el catálogo de
presentaciones ya existente; importante para la coherencia del dato, pero de impacto acotado a un
caso de uso administrativo específico, no al recorrido principal del comensal.

**Independent Test**: con dos variantes del mismo producto usando la misma presentación — una sin
nombre propio y otra con nombre propio — renombrar la presentación y verificar que solo la primera
cambia su etiqueta visible.

**Acceptance Scenarios**:

1. **Given** una variante sin nombre usa la presentación "Pequeño 8 onz" y otra variante del mismo
   producto tiene nombre propio, **When** el administrador renombra la presentación a "Pequeño 250
   ml", **Then** la primera muestra "Pequeño 250 ml" y la segunda conserva su nombre.

---

### Edge Cases

- ¿Qué pasa si el nombre queda vacío tras recortar espacios y colapsar los repetidos (por ejemplo,
  el usuario escribió solo espacios)? Se guarda como '' y la variante muestra la presentación — ver
  User Story 2, escenario 3.
- ¿Qué pasa si no hay ni nombre propio ni dato de presentación disponible (por ejemplo, un dato
  corrupto o una referencia rota)? Se devuelve "Tamaño" como etiqueta y se registra una advertencia
  técnica con el id de la variante — nunca se muestra una etiqueta vacía al comensal.
- ¿Qué pasa si dos variantes **activas** del mismo producto terminarían mostrando la misma etiqueta
  (por nombre propio repetido, o porque un nombre propio coincide con la presentación que ya usa
  otra variante sin nombre)? Se rechaza el guardado con un mensaje claro; no se permite ambigüedad
  dentro de un mismo producto.
- ¿Qué pasa si la variante que ya tiene esa etiqueta está desactivada? No bloquea: una variante
  desactivada no cuenta para la validación de duplicados (FR-008); su etiqueta queda libre para
  reutilizarse mientras permanezca desactivada.
- ¿Qué pasa con un nombre que contiene marcado HTML o scripts? Se escapa en toda pantalla donde se
  muestre (formulario administrativo y menú público); nunca se interpreta como HTML.
- ¿Qué pasa si un tenant tiene muchos productos y variantes en su menú público? El número de
  consultas a base de datos para resolver las etiquetas no crece con la cantidad de variantes, y
  solo se devuelven datos del tenant correspondiente al subdominio consultado.
- ¿Qué pasa con pedidos y variantes que existían antes de este cambio? No se modifican; conservan su
  presentación, precio, orden y representación histórica tal como estaban.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST permitir asociar a cada variante (tamaño) de un producto un nombre
  propio opcional, de 0 a 60 caracteres.
- **FR-002**: Al guardar el nombre, el sistema MUST recortar los espacios al inicio y al final, y
  MUST colapsar los espacios repetidos internos a uno solo.
- **FR-003**: Un nombre que, tras la normalización de FR-002, quede vacío MUST guardarse como
  cadena vacía (''), nunca como valor nulo.
- **FR-004**: El sistema MUST calcular la etiqueta visible del tamaño ("display_name") como el
  nombre propio normalizado cuando no esté vacío, o como el nombre de la presentación asociada
  cuando el nombre propio esté vacío.
- **FR-005**: Cuando el nombre propio esté vacío y el dato de la presentación asociada no esté
  disponible, el sistema MUST devolver "Tamaño" como etiqueta visible y MUST registrar una
  advertencia técnica que incluya el id de la variante afectada.
- **FR-006**: El menú público (detalle del producto, carrito y resumen del checkout) MUST mostrar
  la etiqueta visible del tamaño calculada según FR-004/FR-005 como el nombre que ve el comensal;
  esa etiqueta nunca MUST quedar vacía.
- **FR-007**: El sistema MUST rechazar, sin guardar el producto, un nombre propio que supere los 60
  caracteres, mostrando el mensaje "El nombre admite hasta 60 caracteres".
- **FR-008**: El sistema MUST rechazar, sin guardar el producto, que dos variantes **activas** del
  mismo producto resuelvan a la misma etiqueta visible (ya sea por nombre propio repetido entre
  ellas, o porque un nombre propio coincide con la etiqueta que ya muestra otra variante activa del
  mismo producto), mostrando el mensaje "Ya existe un tamaño con ese nombre en este producto". La
  comparación es insensible a mayúsculas y minúsculas. Una variante desactivada no cuenta para esta
  validación: su etiqueta puede reutilizarse libremente mientras permanezca desactivada.
- **FR-009**: El formulario "Tamaños del producto" MUST mostrar, junto a la presentación de cada
  fila, un campo "Nombre (opcional)" que permita dejarse vacío y guardarse sin error; al borrar un
  nombre existente y guardar, la variante MUST volver a mostrar el nombre de la presentación.
- **FR-010**: El campo de nombre del formulario MUST mostrar como texto de ayuda (placeholder) "Se
  mostrará: {nombre de la presentación elegida}" cuando ya se eligió una presentación y el nombre
  está vacío, o "Se mostrará la presentación" cuando todavía no se ha elegido ninguna presentación.
- **FR-011**: El sistema MUST escapar cualquier contenido HTML o script dentro del nombre al
  mostrarlo, tanto en el formulario administrativo como en el menú público, de forma que nunca se
  interprete como HTML.
- **FR-012**: El sistema MUST aceptar peticiones para crear o editar una variante que no incluyan el
  nombre, o que lo envíen como valor nulo, tratándolas como '' sin devolver error.
- **FR-013**: El endpoint público del menú MUST seguir devolviendo los campos que ya conocen los
  clientes existentes (incluido el nombre de la presentación) con el mismo significado que tienen
  hoy, de forma que un frontend en caché de una versión anterior siga funcionando sin errores.
- **FR-014**: La migración de datos existentes MUST dejar el nombre propio como '' en todas las
  variantes ya existentes, sin modificar su presentación, precio, orden ni cantidad, y sin alterar
  lo que el menú público ya mostraba antes del cambio.
- **FR-015**: El sistema MUST permitir revertir la migración (downgrade), eliminando la columna
  agregada sin afectar presentaciones, precios ni pedidos existentes.
- **FR-016**: Cuando se renombra una presentación, las variantes sin nombre propio MUST reflejar el
  nuevo nombre de la presentación de inmediato, y las variantes con nombre propio MUST conservar su
  nombre sin cambios.
- **FR-017**: Los pedidos (Órdenes, Ventas) ya creados antes de este cambio MUST mostrarse sin
  modificaciones al consultarse después del despliegue.
- **FR-018**: El cálculo y el uso de la etiqueta visible en el menú público MUST resolverse sin que
  el número de consultas a base de datos crezca con la cantidad de variantes del menú, y MUST
  devolver únicamente datos del tenant correspondiente al subdominio consultado.
- **FR-019**: El orden, el precio y la presentación asociada de cada variante MUST permanecer sin
  cambios como consecuencia de esta funcionalidad.

### Key Entities *(include if feature involves data)*

- **Variante de producto (tamaño)**: entidad ya existente que representa un tamaño de un producto,
  con su presentación asociada, precio y orden. Gana un atributo nuevo y opcional, el nombre propio
  (0 a 60 caracteres, normalizado al guardar, nunca nulo), y un dato calculado de solo lectura, la
  etiqueta visible, que resulta de ese nombre propio o, en su defecto, del nombre de la presentación
  asociada.
- **Presentación**: catálogo ya existente de nombres de tamaño reutilizables (por ejemplo "Pequeño 8
  onz"). Esta funcionalidad no le agrega ni le quita atributos; sigue siendo la fuente de la
  etiqueta visible para cualquier variante sin nombre propio.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100% de las variantes existentes antes de esta funcionalidad muestran, en el menú
  público, exactamente el mismo texto que mostraban antes, inmediatamente después de aplicar el
  cambio.
- **SC-002**: El comensal nunca ve una etiqueta de tamaño vacía: el 100% de las variantes
  consultadas en detalle del producto, carrito y resumen del checkout muestran un texto no vacío.
- **SC-003**: Un administrador puede ponerle, cambiarle o quitarle el nombre propio a un tamaño
  desde "Tamaños del producto", y ese cambio se refleja en el menú público sin ninguna intervención
  técnica adicional.
- **SC-004**: El 100% de los intentos de guardar un nombre de más de 60 caracteres, o un nombre que
  produciría una etiqueta duplicada dentro del mismo producto, son rechazados con un mensaje claro,
  sin alterar los datos guardados previamente.
- **SC-005**: El tiempo de respuesta del menú público no se degrada de forma perceptible al
  aumentar la cantidad de variantes por producto.
- **SC-006**: El 100% de los pedidos creados antes de este cambio se siguen consultando en Órdenes
  y Ventas sin ninguna alteración visible.
- **SC-007**: Ningún nombre con contenido HTML se interpreta como HTML en ninguna pantalla donde se
  muestre, administrativa o pública.

## Assumptions

- El límite de 60 caracteres (FR-007) se valida sobre el texto tal como se escribe en el formulario,
  de forma consistente con el escenario de negocio que prueba el límite con 61 caracteres sin
  normalizar previamente.
- El nombre propio es un atributo exclusivo de la variante de producto; esta funcionalidad no
  permite renombrar una Presentación del catálogo desde este formulario ni modifica su contrato
  existente.
- La advertencia técnica registrada cuando no hay nombre propio ni dato de presentación disponible
  (FR-005) es un registro interno para diagnóstico; no es visible para el comensal ni para el
  administrador del tenant.
- Las pantallas de Órdenes y Ventas, al no estar dentro del alcance declarado por el negocio, no se
  modifican para mostrar el nombre propio de tamaños en pedidos ya facturados; sus pedidos
  existentes se consultan tal como se registraron (FR-017).
- El diseño técnico concreto de cómo se evita que el número de consultas a base de datos crezca con
  la cantidad de variantes (FR-018) se decide en la fase de planeación; esta especificación fija el
  contrato observable, no la implementación.
