# Feature Specification: Rediseño visual de la Terminal de Mesas (grilla y detalle de pedido)

**Feature Branch**: `131-rediseno-terminal-mesas`

**Created**: 2026-10-22

**Status**: Draft

**Input**: User description: "necesito que rediseñes la vista actual del de la terminal de mesas usando implementando exactamente el mismo diseño que aparece en @design/SkeiloPOS.html, pero teniendo en cuenta las siguientes consideraciones: el alcance del diseño sera la vista principal del modulo de terminal de mesas y el detalle de cada pedido (mesa, para llevar, domicilio) cuando el cajero selecciona una mesa u orden. se deben mantener las funcionalidades actuales considerandolas con el diseño, si el diseño original ya no tiene algo que tenia el diseño legacy entonces me preguntas para decidir si se elimina o no. deberas tener el cuenta que el diseño sea responsive y se adapte a cualquier tipo de pantalla. usa componentes del diseño de referencia, si no existen entonces crealos pero todo debe ser fiel al diseño de referencia incluyendo la distribucion del layout y modelo de caja. si hay alguna inconsistencia o funcionalidad que requiera crear un nuevo endpoint me preguntas."

## Clarifications

### Session 2026-10-22

- Q1: El detalle de pedido tiene hoy la acción "Agregar adición" por línea (spec 123,
  agregar una opción extra a un producto ya facturado) con su badge "Modificada"; el diseño
  de referencia no tiene ningún componente equivalente. ¿Qué hacer? → A: se elimina — se
  retira el selector dedicado "Agregar adición" y el badge "Modificada"; agregar algo a una
  línea ya facturada pasa a cubrirse agregando un producto/línea nueva vía el catálogo
  embebido normal ("Agregar producto"). Es un cambio de comportamiento explícito sobre spec
  123.
- Q2: El diseño de referencia tiene pestañas "Cuentas" (Cuenta A, Cuenta B + "Nueva
  cuenta") pensadas para dividir la cuenta por comensal — modelo que el negocio retiró en
  spec 046. Hoy la terminal usa pestañas "Pedido N" para varios pedidos en paralelo sobre la
  misma mesa, más un botón "+ Crear pedido nuevo" en la sub-barra superior que sigue visible
  también dentro de la vista de detalle (spec 087/126). ¿Cómo tratar ese bloque visual? → A:
  se reutiliza visualmente como las pestañas "Pedido N" (sin reintroducir división por
  comensal), **y además** el botón "+ Crear pedido nuevo" de la sub-barra deja de estar
  disponible mientras se está dentro de la vista de detalle de una mesa con pestañas "Pedido
  N" — esa capacidad (crear un pedido nuevo en paralelo sobre la misma mesa) pasa a vivir
  exclusivamente en el botón "Nueva cuenta" de ese bloque de pestañas, dentro del detalle.
  Alcance de este cambio: solo aplica al detalle de **mesa** (donde existen pestañas "Pedido
  N"); en el detalle de un pedido de Domicilio o Para llevar (que no agrupa varios pedidos
  bajo pestañas) el botón "+ Crear pedido nuevo" de la sub-barra se mantiene visible igual
  que hoy, porque no hay un botón "Nueva cuenta" equivalente que lo reemplace ahí.
- Q3: Las tarjetas de mesa del mockup muestran una "zona" (ej. "Mesa 3 · Terraza · Libre");
  el modelo de datos actual de Mesa no tiene ningún campo de zona/sección. ¿Qué hacer con ese
  dato? → A: se omite — la tarjeta de mesa adopta el estilo del mockup sin el segmento de
  zona, porque ese dato no existe hoy; introducir zonas como concepto de datos (campo nuevo,
  administración de zonas) queda fuera de alcance de este spec, documentado para evaluarse
  aparte si el negocio lo pide.
- Q4: El "pago mixto" del Menú QR (efectivo + transferencia combinados, panel `tdQ3On` del
  mockup) todavía no existe en producción — depende de columnas nuevas (`cash_amount`,
  `transfer_amount`, `transfer_method_id`) y del tipo de método `'mixed'` definidos en el
  spec 130, que sigue en estado Draft. ¿Este spec debe incluir el panel de validación de pago
  mixto QR dentro de su alcance visual, aunque dependa de que el spec 130 se implemente antes
  de poder probarse en producción, o debe limitarse por ahora solo a los dos casos que sí
  existen hoy (efectivo y transferencia por separado)? → A: se incluyen los tres — este spec
  construye el panel visual de pago mixto QR (`tdQ3On`) junto con los otros dos, pero queda
  registrado que su activación/prueba real con datos reales depende de que el spec 130 esté
  implementado primero; no es una funcionalidad nueva que este spec agregue por su cuenta,
  sino la reutilización visual de un dato que otro spec todavía no expone.
- Q5: El QR del Menú siempre está ligado a una mesa (el token firma `table_id`, ver
  `specs/000-reconocimiento/flujo-pedido-qr.md`); no existe un QR equivalente para pedidos de
  Domicilio o Para llevar. ¿Los tres paneles de validación de pago QR (efectivo,
  transferencia, mixto) aplican únicamente al detalle de pedidos de **mesa**, o también deben
  contemplarse en el detalle de Domicilio/Para llevar? → A: solo detalle de mesa — los tres
  paneles de validación de pago QR solo aplican dentro del detalle de un pedido de mesa; el
  detalle de Domicilio/Para llevar no cambia por esta clarificación.

## Resumen

Este spec cubre el rediseño **visual** (layout, distribución, componentes, estilos) de dos
pantallas del módulo "Terminal de Mesas": la **vista principal** (grilla de mesas /
domicilios / para llevar) y la **vista de detalle de un pedido** (mesa, para llevar o
domicilio) que se abre al seleccionar una tarjeta. El nuevo diseño debe ser fiel al mockup
de referencia `design/SkeiloPOS.html` (pantalla "Terminal de Mesas", sección `isTerminal`,
`tDetOn`/`tcOn`), reproduciendo su distribución de layout y su "modelo de caja" (bordes,
radios, espaciados, tipografía, iconografía).

Este rediseño es **principalmente visual**: casi todas las funcionalidades que hoy existen
en la terminal (filtros, búsqueda, pestañas de tipo de pedido, carrito, cobro, pagos
mixtos, validación de pagos QR/transferencia, impresión, liberar mesa, etc.) se conservan
sin cambios de comportamiento — solo cambia su presentación visual y su distribución en
pantalla. Dos excepciones puntuales, decididas con el usuario de negocio (ver
"Clarifications"), sí cambian comportamiento: el retiro de "Agregar adición" (FR-023) y la
reubicación de "+ Crear pedido nuevo" hacia "Nueva cuenta" dentro del detalle de mesa
(FR-022b). Ninguna funcionalidad identificada en el análisis de este spec requiere un
endpoint nuevo: todo lo que hoy se consume de la API se sigue consumiendo igual; el
rediseño es exclusivamente de frontend.

El rediseño del detalle de pedido también cubre los tres casos de un pedido recibido por el
canal del Menú QR con un pago pendiente de revisión: efectivo (`tdQrOn`), transferencia/Nequi
(`tdQ2On`) y pago mixto efectivo+transferencia (`tdQ3On`) — ver FR-014. Los tres paneles solo
aplican al detalle de **mesa**, porque el canal QR siempre crea pedidos ligados a una mesa
(Clarifications, Q5). El panel de pago mixto (`tdQ3On`) depende de una capacidad que todavía
no existe en producción (desglose `cash_amount`/`transfer_amount`, tipo de método `'mixed'`),
definida en el spec 130 (estado Draft); este spec la incluye en su alcance visual pero su
funcionamiento real con datos reales queda bloqueado por esa dependencia (Clarifications, Q4).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ver la grilla principal con el nuevo diseño (Priority: P1)

Como cajero, al entrar a la Terminal de Mesas veo la grilla de mesas (o de domicilios/para
llevar, según la pestaña activa) con la distribución visual del mockup de referencia:
cabecera de estado de turno/conexión, barra de búsqueda y pestañas de tipo de pedido,
indicador de caja abierta, botón "Crear pedido nuevo", filtro de estado y una grilla de
tarjetas con el estado, resumen y total de cada mesa/pedido — conservando los mismos
filtros, atajos de teclado y conteos que existen hoy.

**Why this priority**: es la pantalla de entrada del módulo y la que más tiempo tiene
abierta el cajero durante el turno; sin ella rediseñada primero no hay forma de validar que
el resto del flujo (detalle, cobro) encaje visualmente.

**Independent Test**: se puede probar por separado abriendo la Terminal de Mesas sin
seleccionar ninguna mesa — se verifica que la grilla, los filtros, la búsqueda y las
pestañas se vean y funcionen igual que antes, con el nuevo diseño.

**Acceptance Scenarios**:

1. **Given** el cajero abre la Terminal de Mesas con la pestaña "Mesas" activa, **When** la
   pantalla carga, **Then** ve la cabecera de turno/conexión/caja, la barra de
   búsqueda+pestañas+filtro de estado y la grilla de tarjetas de mesa, todo con la
   distribución y el "modelo de caja" (bordes, radios, tipografía) del diseño de
   referencia.
2. **Given** el cajero escribe en el buscador o pulsa `F2`, **When** teclea el número o
   nombre de una mesa, **Then** la grilla se filtra igual que hoy, sin perder el resto de
   filtros activos.
3. **Given** el cajero cambia a la pestaña "Domicilios" o "Para llevar", **When** existen
   pedidos pendientes de cobro de ese tipo, **Then** ve una grilla de tarjetas equivalente
   (mismo "modelo de caja" que las mesas) con el estado y el total de cada pedido; si no
   hay ninguno, ve el mensaje de estado vacío correspondiente.
4. **Given** el cajero aplica el filtro de estado (Todas/Libres/Ocupadas/Pendientes),
   **When** selecciona una opción, **Then** la grilla y el conteo de cada opción se
   actualizan igual que en el comportamiento actual.
5. **Given** no hay ninguna mesa libre, **When** el cajero está en la pestaña "Mesas",
   **Then** el botón "Crear pedido nuevo" aparece deshabilitado con el mismo mensaje
   explicativo que hoy.

---

### User Story 2 - Ver y editar el detalle de un pedido con el nuevo diseño (Priority: P2)

Como cajero, al seleccionar una mesa ocupada, un pedido de domicilio o uno para llevar, veo
la vista de detalle con la distribución del mockup de referencia (cabecera con número/
nombre y estado del pedido, pestañas de "Pedido N" cuando la mesa tiene más de un pedido,
lista de líneas con sus acciones de preparación, y botón para agregar productos), sin
perder ninguna acción que hoy tengo disponible sobre el pedido (salvo los dos cambios
explícitos de FR-022b y FR-023).

**Why this priority**: es el núcleo operativo del día a día del cajero/mesero — tomar y
preparar el pedido — y depende del rediseño de la grilla (US1) para ser alcanzable.

**Independent Test**: se puede probar seleccionando una mesa con un pedido en curso y
verificando que todas las acciones sobre las líneas (marcar listo, anular, agregar
producto nuevo) siguen disponibles y funcionan igual que antes, con el nuevo diseño.

**Acceptance Scenarios**:

1. **Given** el cajero selecciona una mesa ocupada con un pedido en curso, **When** se abre
   el detalle, **Then** ve la cabecera con el número de mesa, el nombre del cliente y el
   estado del pedido, y la lista de líneas con cantidad, variante, opciones elegidas, nota,
   precio y (si aplica) la promoción vigente — igual que en el comportamiento actual, con
   el layout del diseño de referencia.
2. **Given** la mesa tiene más de un pedido abierto, **When** el cajero cambia entre las
   pestañas "Pedido N", **Then** el detalle enfoca ese pedido sin perder el estado de los
   demás, igual que hoy.
3. **Given** el pedido sigue en armado (no enviado a cocina), **When** el cajero pulsa
   "Agregar producto", **Then** se abre el catálogo embebido con buscador, categorías y
   promociones, y al confirmar los productos elegidos se agregan al pedido igual que hoy.
4. **Given** una línea del pedido sigue pendiente de preparar, **When** el cajero pulsa
   "Marcar listo" o "Anular", **Then** el sistema actualiza el estado de la línea igual que
   en el comportamiento actual.
5. **Given** el pedido seleccionado es de Domicilio o Para llevar (sin mesa asociada),
   **When** se abre su detalle, **Then** el cajero sigue viendo la dirección, el teléfono y
   el valor del domicilio (cuando aplique) con la misma información que hoy, adaptada al
   layout de referencia.
6. **Given** una línea ya facturada necesita sumar algo que antes se cubría con "Agregar
   adición" (spec 123), **When** el cajero quiere sumarlo, **Then** lo hace agregando un
   producto/línea nueva vía "Agregar producto" (FR-023) — la acción dedicada "Agregar
   adición" y el badge "Modificada" ya no existen.

---

### User Story 3 - Cobrar el pedido con el nuevo diseño (Priority: P3)

Como cajero, desde la vista de detalle puedo cobrar el pedido o la cuenta completa de la
mesa (pago único, pago mixto hasta 3 métodos, saldo pendiente por adiciones posteriores, o
validar un pago QR/transferencia pendiente de aprobación) con la misma distribución visual
del panel de cobro del mockup de referencia, sin perder ninguna de las reglas de cobro
actuales.

**Why this priority**: es el paso que cierra la operación y mueve dinero/inventario; debe
construirse sobre la vista de detalle ya rediseñada (US2).

**Independent Test**: se puede probar cobrando un pedido de mostrador con un único método,
uno con métodos combinados, y validando un pago QR pendiente — verificando que el resultado
(venta registrada, inventario descontado, mesa liberada cuando corresponde) es el mismo que
hoy.

**Acceptance Scenarios**:

1. **Given** un pedido de mostrador sin cobrar, **When** el cajero elige un método de pago
   y pulsa "Cobrar", **Then** el sistema registra la venta igual que hoy, mostrando el
   mismo desglose (subtotal, domicilio si aplica, total) calculado por el backend.
2. **Given** el cajero decide combinar métodos de pago, **When** agrega hasta 3 líneas de
   pago con sus montos, **Then** el sistema valida y cobra igual que en el comportamiento
   actual.
3. **Given** un pedido de **mesa** llegó por el canal del Menú QR con un pago pendiente de
   revisión, **When** el cajero abre su detalle, **Then** ve el panel de validación que
   corresponde al método elegido por el comensal — efectivo (confirmar monto recibido),
   transferencia/Nequi (ver comprobante, aprobar/rechazar) o pago mixto efectivo+transferencia
   (validar las dos partes) — con el mismo comportamiento que hoy, en el layout de referencia
   (ver FR-014). El panel de pago mixto depende de que el spec 130 esté implementado
   (Clarifications, Q4); mientras no lo esté, este caso no tiene datos reales que validar.
4. **Given** una mesa ya pagada tiene un saldo pendiente por adiciones agregadas después del
   cobro, **When** el cajero lo cobra, **Then** el sistema lo registra como un cobro
   adicional, igual que en el comportamiento actual.
5. **Given** el pedido ya está completamente pagado y sin pagos QR pendientes de validar,
   **When** el cajero lo necesita, **Then** puede imprimir la factura y liberar la mesa,
   igual que hoy.

---

### User Story 4 - Experiencia responsive en cualquier tamaño de pantalla (Priority: P2)

Como cajero que usa la terminal en distintos dispositivos (tablet en el salón, monitor de
escritorio en caja), necesito que tanto la grilla principal como el detalle de pedido se
adapten al ancho disponible sin perder información ni acciones, manteniendo siempre
accesible la acción de volver y el cobro.

**Why this priority**: la terminal se usa hoy en anchos muy distintos (según los
comentarios del código actual) y es una condición explícita del pedido del usuario, al
mismo nivel que la fidelidad visual.

**Independent Test**: se puede probar abriendo la terminal en al menos tres anchos de
referencia (móvil, tablet, escritorio ancho) y verificando que ninguna acción quede
inaccesible ni recortada, y que el scroll se comporte de forma predecible (una sola región
de scroll por columna, no cajas anidadas scrolleando por separado).

**Acceptance Scenarios**:

1. **Given** una pantalla angosta (móvil), **When** el cajero selecciona una mesa, **Then**
   ve solo la columna de detalle a pantalla completa, con un botón para volver a la grilla,
   igual que en el comportamiento actual.
2. **Given** una pantalla ancha (escritorio), **When** el cajero abre el detalle,
   **Then** ve el pedido y el cobro distribuidos según la proporción del diseño de
   referencia, sin que ninguno de los dos quede ilegible por falta de espacio.
3. **Given** cualquier ancho de pantalla, **When** el contenido de una columna excede el
   alto disponible, **Then** solo esa columna scrollea — nunca aparece scroll horizontal de
   página ni más de un scroll independiente dentro de la misma columna.

---

### Edge Cases

- ¿Qué pasa cuando no hay ninguna mesa, ni pedido de domicilio/para llevar, que coincida con
  el filtro o la búsqueda activa? → se mantiene el mensaje de estado vacío actual, con la
  presentación visual del diseño de referencia.
- ¿Qué pasa cuando el cajero cambia de pestaña mientras tiene el catálogo de "Agregar
  producto" abierto? → se mantiene el comportamiento actual (el catálogo embebido se cierra
  o se ignora según corresponda, sin perder lo ya seleccionado en el pedido).
- ¿Qué pasa cuando un pedido de mesa tiene un pago mixto QR (Nequi/transferencia + efectivo)
  pendiente de revisión? → se usa el panel `tdQ3On` del diseño de referencia (ver FR-014c),
  validando las dos partes en dos pasos; esta capacidad depende de que el spec 130 (Draft)
  esté implementado — ver Clarifications Q4 y Assumptions.
- ¿Qué pasa con un pedido de Domicilio/Para llevar de un cliente externo sin mesa asignada?
  → se preserva la información de dirección/teléfono/valor de domicilio existente,
  adaptándola al layout del mockup (ver FR-024).
- ¿Qué pasa si la cuenta de la mesa cambió desde que se abrió (otro usuario agregó un
  producto)? → se conserva el aviso "La cuenta cambió" / "El total cambió" con su botón de
  actualizar, igual que hoy.
- ¿Qué pasa con el botón "Bloquear terminal" del encabezado actual, que hoy no tiene
  funcionalidad real (solo muestra un aviso de "todavía no disponible")? → se mantiene como
  está (ver Assumptions): el diseño de referencia no incluye un botón equivalente dentro de
  la pantalla de Terminal, así que se conserva en la cabecera como hoy, sin alterar su
  comportamiento no funcional.

## Requirements *(mandatory)*

### Functional Requirements

**Vista principal (grilla)**

- **FR-001**: El sistema DEBE mostrar la cabecera de la terminal (estado de conexión/
  sincronización, turno activo, reloj/fecha, indicador de caja abierta) con la distribución
  visual del diseño de referencia, sin cambiar la información que hoy expone.
- **FR-002**: El sistema DEBE mostrar las pestañas de tipo de pedido (Mesas / Domicilios /
  Para llevar) y el buscador (con atajo `F2`) en la misma franja, igual que en el
  comportamiento actual, con la distribución del diseño de referencia.
- **FR-003**: El sistema DEBE mostrar el filtro de estado de mesa (Todas/Libres/Ocupadas/
  Pendientes) con su conteo por opción, igual que hoy.
- **FR-004**: El sistema DEBE mostrar una grilla de tarjetas (mesas, o pedidos de domicilio/
  para llevar según la pestaña) que se reacomoda según el ancho disponible, conservando el
  estado, el resumen (ítems/tiempo transcurrido) y el total de cada una.
- **FR-005**: El sistema DEBE mostrar el botón "Crear pedido nuevo" (con atajo `F3`),
  habilitado/deshabilitado con el mismo criterio que hoy según la pestaña activa y la
  disponibilidad de mesas libres.
- **FR-006**: El sistema DEBE mostrar el mensaje de estado vacío correspondiente cuando el
  filtro, la búsqueda o la pestaña activa no tengan ningún resultado.

**Detalle de pedido (mesa, domicilio o para llevar)**

- **FR-007**: El sistema DEBE mostrar, al seleccionar una mesa ocupada o un pedido de
  domicilio/para llevar, una vista de detalle con cabecera (identificador, nombre de
  cliente, estado), pestañas de "Pedido N" cuando existan varios pedidos en la misma mesa, y
  la lista de líneas del pedido seleccionado.
- **FR-008**: El sistema DEBE mantener, en cada línea del pedido, toda la información y
  acciones que expone hoy: cantidad, variante, opciones elegidas, nota, precio unitario,
  promoción aplicada (si existe), estado de preparación, "Marcar listo" y "Anular", con la
  misma lógica de habilitación/deshabilitación que hoy. La acción "Agregar adición" se retira
  (ver FR-023).
- **FR-009**: El sistema DEBE permitir agregar productos al pedido mediante un catálogo
  embebido (buscador, categorías, promociones) con el mismo comportamiento que hoy.
- **FR-010**: El sistema DEBE ofrecer un único punto de "Volver a mesas/pedidos" siempre
  visible mientras se está en la vista de detalle, igual que en el comportamiento actual.
- **FR-011**: El sistema DEBE mostrar la información propia de un pedido de Domicilio
  (dirección, teléfono, valor del domicilio) cuando corresponda, igual que hoy.

**Cobro**

- **FR-012**: El sistema DEBE mostrar el panel de cobro con el desglose de subtotal/
  domicilio/total calculado por el backend, el campo "Facturar a nombre de", el selector de
  método de pago y el botón "Cobrar", igual que en el comportamiento actual.
- **FR-013**: El sistema DEBE permitir combinar hasta 3 métodos de pago en un mismo cobro,
  igual que hoy.
- **FR-014**: El sistema DEBE mostrar, en el detalle de un pedido de **mesa** recibido por el
  canal del Menú QR con un pago pendiente de revisión, el panel de validación que corresponde
  al método elegido por el comensal, reutilizando el componente visual del diseño de
  referencia que le corresponde, con el mismo comportamiento que hoy en cada caso:
  - **FR-014a** (efectivo, `tdQrOn`): monto recibido y "Confirmar efectivo".
  - **FR-014b** (transferencia/Nequi, `tdQ2On`): ver comprobante, aprobar, rechazar.
  - **FR-014c** (pago mixto efectivo+transferencia, `tdQ3On`): validar las dos partes
    (aprobar comprobante de la porción por transferencia, confirmar el monto en efectivo) y
    "Confirmar pago mixto". Esta capacidad depende de que el spec 130 (estado Draft) esté
    implementado — sin él no existen los datos (`cash_amount`, `transfer_amount`,
    `transfer_method_id`) que este panel necesita mostrar; mientras tanto, el panel se
    construye visualmente pero no puede probarse con datos reales (Clarifications, Q4).

  Estos tres paneles no aplican al detalle de un pedido de Domicilio o Para llevar, porque el
  canal del Menú QR siempre crea pedidos ligados a una mesa (Clarifications, Q5).
- **FR-015**: El sistema DEBE mostrar el cobro de saldo pendiente por adiciones posteriores
  al pago original, igual que en el comportamiento actual.
- **FR-016**: El sistema DEBE ofrecer "Imprimir Factura" y "Liberar Mesa" únicamente cuando
  el pedido/mesa ya no tenga ningún cobro pendiente, igual que hoy.
- **FR-017**: El sistema DEBE mostrar el diálogo de confirmación de pago (con impresión de
  uno o varios comprobantes, según si la venta se dividió) igual que en el comportamiento
  actual.

**Responsive**

- **FR-018**: El sistema DEBE adaptar tanto la grilla principal como el detalle de pedido a
  anchos de pantalla móvil, tablet y escritorio, sin ocultar ninguna acción descrita en los
  requisitos anteriores.
- **FR-019**: El sistema DEBE limitar el scroll a una única región por columna visible —
  nunca scroll horizontal de página ni más de un contenedor de scroll anidado dentro de la
  misma columna.

**Fidelidad al diseño de referencia**

- **FR-020**: El sistema DEBE reutilizar, para ambas vistas, los componentes visuales ya
  definidos en el diseño de referencia (tarjetas, pestañas, badges, campos de
  pago, etc.); cuando un componente equivalente no exista todavía en el proyecto, el sistema
  DEBE crearse siguiendo fielmente su apariencia y comportamiento en el mockup.
- **FR-021**: El sistema DEBE conservar la distribución de layout y el "modelo de caja"
  (bordes, radios, espaciados) del diseño de referencia en ambas vistas.
- **FR-022**: El bloque de pestañas "Cuentas" del diseño de referencia (ej. "Cuenta A",
  "Cuenta B", "Nueva cuenta") DEBE reutilizarse como el componente visual de las pestañas
  "Pedido N" que ya existen hoy para navegar entre los distintos pedidos abiertos de una
  misma mesa — ajustando únicamente los textos/copys a lo que corresponda ("Pedido 1",
  "Pedido 2", etc.), sin reintroducir la división de la cuenta por comensal/cuenta que el
  negocio retiró en spec 046 (el cobro sigue siendo siempre por pedido completo o por cierre
  unificado de la mesa). El botón "Nueva cuenta" del mockup DEBE disparar exactamente el
  mismo comportamiento que hoy dispara "+ Crear pedido nuevo" desde dentro del detalle de
  una mesa (crear un pedido nuevo en paralelo sobre la misma mesa, spec 087) — no crea
  ninguna cuenta/división nueva.
- **FR-022b**: Mientras el cajero está dentro de la vista de detalle de una **mesa** (donde
  aplican las pestañas "Pedido N"/"Cuentas" de FR-022), el botón "+ Crear pedido nuevo" de la
  sub-barra superior DEJA de mostrarse — esa capacidad vive exclusivamente en el botón "Nueva
  cuenta" dentro del detalle. En la vista de detalle de un pedido de Domicilio o Para llevar
  (sin pestañas "Pedido N", porque esos tipos no agrupan varios pedidos bajo una misma
  mesa) el botón "+ Crear pedido nuevo" de la sub-barra se sigue mostrando igual que hoy.
  Fuera de la vista de detalle (en la grilla principal) el botón no cambia. Es un cambio de
  comportamiento explícito sobre spec 087/126, decidido por el usuario de negocio el
  2026-10-22, que debe registrarse en `specs/000-reconocimiento/registro-de-anomalias.md`
  antes de implementarse (Principio II de la constitución).
- **FR-023**: La acción "Agregar adición" por línea y el badge "Modificada" (spec 123) se
  retiran del detalle de pedido: agregar una opción extra a un producto ya facturado deja de
  hacerse mediante ese selector dedicado y pasa a cubrirse agregando la adición como un
  producto/línea nueva del pedido, a través del flujo normal de "Agregar producto" del
  catálogo embebido. Es un cambio de comportamiento explícito, decidido por el usuario del
  negocio el 2026-10-22, que debe registrarse en
  `specs/000-reconocimiento/registro-de-anomalias.md` antes de implementarse (Principio II
  de la constitución).
- **FR-024**: La cabecera del detalle de un pedido de Domicilio o Para llevar (sin mesa
  asociada) DEBE conservar la fila compacta de dirección/teléfono/valor de domicilio debajo
  de la cabecera principal, igual que en el comportamiento actual — la insignia y el título
  de la cabecera se adaptan (p. ej. ícono de tipo de pedido en vez de número de mesa) pero la
  fila con esos datos no se elimina ni se fusiona dentro del título.

### Key Entities *(include if feature involves data)*

Este spec no introduce ni modifica entidades de datos: reutiliza las entidades existentes
(Mesa, Sesión de mesa, Pedido, Línea de pedido, Cuenta de mesa/Bill, Intento de pago,
Turno de caja) tal como ya las expone la API actual. No se identificó ninguna
funcionalidad que requiera un endpoint nuevo.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100% de las acciones hoy disponibles en la terminal de mesas (filtros,
  búsqueda, pestañas, cobro, validación de pagos, impresión, liberar mesa) siguen siendo
  accesibles y funcionan igual después del rediseño, salvo los dos cambios de comportamiento
  explícitos de este spec (FR-022b, FR-023) — verificado por los characterization tests
  existentes del módulo, actualizados para esos dos casos.
- **SC-002**: Un cajero puede completar el ciclo "seleccionar mesa → agregar producto →
  cobrar → liberar mesa" sin que ninguna pantalla intermedia quede recortada o requiera
  scroll horizontal, en los tres anchos de referencia (móvil, tablet, escritorio).
- **SC-003**: La distribución visual (bordes, radios, tipografía, espaciados) de ambas
  vistas coincide con el diseño de referencia en una revisión visual lado a lado.
- **SC-004**: Cero endpoints nuevos se crean como consecuencia de este rediseño.

## Assumptions

- El alcance de este spec es exclusivamente visual (layout, componentes, estilos,
  responsive) de la vista principal de la terminal y de la vista de detalle de pedido; no
  cubre el rediseño del catálogo de producto ("Agregar producto") más allá de encajarlo en
  la nueva distribución, ni la vista dedicada de "Pedido manual" (`manual-order-page.component.ts`),
  que ya tiene su propio spec de referencia visual (fuera de este alcance salvo que
  comparta componentes de cabecera).
- El botón "Bloquear terminal" del encabezado actual se mantiene igual (sin funcionalidad
  real, mostrando el mismo aviso de "todavía no disponible"), ya que el diseño de
  referencia no define una alternativa visual para él dentro de esta pantalla.
- La iconografía del diseño de referencia (set de íconos tipo "lucide") reemplaza a la
  iconografía Material actual (`app-mi-icon`) en los dos flujos rediseñados, por fidelidad
  visual — cualquier ícono del mockup sin equivalente exacto en el set actual se agrega
  como un ícono nuevo del mismo estilo.
- No se requiere ninguna migración de datos ni cambio de modelo de datos: este spec es
  puramente de presentación y reutiliza los datos ya expuestos por la API.
- Los characterization tests existentes sobre el comportamiento funcional de la terminal
  (filtros, cobro, validación de pagos, etc.) siguen siendo la referencia de que el
  comportamiento no cambió; se actualizan solo los tests que dependan de selectores/
  estructura visual específica del diseño anterior.
- El retiro de "Agregar adición" (FR-023) y la reubicación de "+ Crear pedido nuevo" hacia
  "Nueva cuenta" dentro del detalle de mesa (FR-022b) son las dos únicas decisiones de
  negocio de este spec que cambian comportamiento existente; antes de implementarlas deben
  quedar registradas en `specs/000-reconocimiento/registro-de-anomalias.md` (quién: el
  usuario de negocio; cuándo: 2026-10-22; qué cambia: (1) se retira el selector dedicado
  "Agregar adición" y el badge "Modificada" — la misma necesidad queda cubierta agregando la
  adición como una línea/producto normal del pedido (afecta spec 123); (2) el botón "+ Crear
  pedido nuevo" deja de mostrarse en la sub-barra mientras se está dentro del detalle de una
  mesa — esa capacidad pasa a vivir solo en "Nueva cuenta" dentro del detalle (afecta spec
  087/126); el botón de la sub-barra no cambia fuera del detalle de mesa, ni en el detalle de
  Domicilio/Para llevar).
- La "zona" de mesa que muestra el diseño de referencia (ej. "Terraza") se omite de las
  tarjetas: el modelo de datos actual de Mesa no tiene ese campo y agregarlo queda fuera de
  alcance de este spec (sin cambios de datos ni endpoints nuevos).
- El panel de validación de pago mixto QR (FR-014c, `tdQ3On`) depende de una capacidad que
  todavía no existe en producción: las columnas `cash_amount`/`transfer_amount`/
  `transfer_method_id` y el tipo de método `'mixed'` se definen en el spec 130
  (`specs/130-rediseno-menu-qr`), que sigue en estado Draft. Este spec 131 no crea ese
  endpoint ni ese modelo de datos (sigue cumpliéndose SC-004: cero endpoints nuevos como
  consecuencia de *este* rediseño) — solo construye y reutiliza el componente visual que los
  mostrará una vez que el spec 130 esté implementado. Hasta entonces, el caso de pago mixto
  QR no puede verificarse con datos reales en characterization tests; los casos de efectivo
  (FR-014a) y transferencia (FR-014b) sí existen hoy y deben seguir cubiertos por los
  characterization tests existentes.
