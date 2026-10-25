# Feature Specification: Bloqueo de la Traducción Automática del Navegador y Aviso de Página Alterada

**Feature Branch**: `134-bloqueo-traduccion-automatica`

**Created**: 2026-10-24

**Status**: Draft

**Input**: User description: "Corrección: bloquear la traducción automática del navegador en toda la
app (menú QR del comensal, checkout, panel /dashboard, /super-admin, login y recuperación de
contraseña) y detectar cuando una traducción o extensión igualmente altera la página, porque
traducirla deja la interfaz desfasada del estado real (cantidades, totales, contador y textos de
botones). Alcance: SOLO la app web del POS (menú QR y panel). Quedan FUERA el landing y los correos
transaccionales."

**Contexto**: Cuando un comensal o una persona del personal usa la traducción automática del
navegador (por ejemplo "Traducir página" de Chrome), lo que ve en pantalla deja de coincidir con lo
que la aplicación tiene realmente. Las acciones siguen ejecutándose, pero su efecto ya no se
refleja en pantalla, de modo que la persona actúa a ciegas: puede agregar más unidades de las que
cree, enviar un pedido sin ver el total correcto, o un administrador puede leer cifras equivocadas.
La decisión de producto ya está tomada: la traducción automática se **bloquea** en toda la
aplicación; no se busca que la aplicación funcione traducida, y se acepta que un comensal que no
lee español vea el menú solo en español. Como el bloqueo depende de que el navegador lo respete (y
algunas extensiones lo ignoran), esta spec añade una red de seguridad: detectar que la página fue
alterada, avisar a la persona y proteger las acciones que mueven dinero o pedidos hasta que
recargue. Un tercer frente es el despliegue: la aplicación instalada en el dispositivo sigue
sirviendo la versión anterior hasta que se actualiza, así que el arreglo debe poder llegar solo a
las pestañas que llevan días abiertas (terminales POS).

**Alcance**: menú QR del comensal (`/menu/t/:token` y todos los pasos de `/checkout`), panel del
personal (`/dashboard`), `/super-admin` y las pantallas públicas de inicio de sesión, recuperación y
cambio de contraseña. **Fuera de alcance**: el sitio de presentación (landing), los correos
transaccionales y cualquier traducción real del contenido (internacionalización).

## Evidencia de la reproducción (2026-10-24)

La causa raíz se reprodujo en el menú QR y en el panel simulando lo que hace un traductor: cada
texto de la pantalla se sustituye por una copia y el original queda desconectado de la página. La
traducción real de Chrome no se puede disparar desde automatización, por eso la confirmación con
traducción real y con los demás navegadores queda como verificación manual.

- **El fallo dominante es silencioso**: no hay errores ni congelamiento. La pantalla simplemente
  queda desfasada. Se midieron cero errores en unas 25 interacciones del menú QR y en 9
  navegaciones del panel.
- **Menú QR**: el modal de producto mostraba *Cantidad 1* y *Agregar $ 4.000* cuando lo real era
  3 unidades y $ 12.000; la línea del carrito mostraba *3* y *TOTAL $ 12.000* cuando lo guardado
  era 4 × $ 4.000; el paso "Revisar" (pantalla recién creada) sí mostraba bien *4×* y *$ 16.000*.
  El comensal cree agregar una unidad por $ 4.000 y agrega tres por $ 12.000.
- **Botón "Enviar pedido"**: al alternar su estado quedaba escrito *"Enviando pedido… Enviar pedido
  Enviar pedido"* cuando el estado real era "no se está enviando".
- **Panel**: la tarjeta "Estadísticas de ventas" mostraba $ 367.500 para las tres métricas cuando
  sin traducir muestra Órdenes = 10 y Ticket promedio = $ 36.750; el filtro del Terminal de Mesas
  decía "Todas · 0" cuando lo real es "Todas · 2"; el título del encabezado quedó fijo en
  "Terminal de Mesas" durante 9 navegaciones; el modal del POS mostraba *1* y *$ 4.000* cuando lo
  real era 3 y $ 12.000.
- **Alcance del patrón**: alrededor de 917 textos dinámicos en unas 115 pantallas/componentes, 47
  bloques cuyo contenido alterna entre textos sueltos (entre ellos el botón "Agregar", "Enviar
  pedido", "Iniciar sesión" y "Reenviar enlace en N s") y unos 146 usos de íconos que son texto
  traducible.
- **Hipótesis descartada**: la sospecha inicial de que la interfaz "se congelaba" por errores al
  quitar o insertar elementos no se confirmó. Esto condiciona el diseño del aviso: no puede
  depender de capturar errores, porque en el caso dominante no hay ninguno.

## Clarifications

### Session 2026-10-24

Decisiones tomadas por el dueño del producto (Leonardo Gómez) el 2026-10-24, al aceptar las
recomendaciones propuestas tras la reproducción:

- Q: ¿El aviso debe aparecer solo ante errores de la aplicación, o también cuando se detecte que el
  navegador alteró la página? → A: También cuando se detecte la alteración, con un criterio
  estricto que evite falsos positivos. Esto sustituye el supuesto original del brief (aviso solo
  ante errores).
- Q: Mientras la página esté alterada, ¿solo se avisa o también se bloquean acciones? → A: Se
  avisa **y** se bloquean el envío de pedido y el pago (y sus equivalentes en el POS), porque la
  persona puede estar ordenando algo distinto de lo que ve.
- Q: ¿Entra en alcance que la aplicación detecte y aplique versiones nuevas por sí sola? → A: Sí,
  en versión mínima, para que el arreglo llegue a terminales POS con pestañas abiertas durante días.
- Q: ¿"Recargar" lleva siempre al menú o recarga donde estaba la persona? → A: Recarga la dirección
  actual, que ya devuelve a la persona al paso correcto conservando lo confirmado.
- Q: ¿Qué queda fuera de alcance? → A: El landing y los correos transaccionales. El alcance es solo
  el menú QR y el panel (incluidos super-admin y las pantallas públicas de acceso).
- Sin respuesta (se asume y se declara en Assumptions): idioma del teléfono del caso reportado
  originalmente, y dispositivos reales disponibles para la verificación en otros navegadores.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - El comensal pide y paga sin que el navegador traduzca la página (Priority: P1)

Un comensal con el celular en inglés (o en cualquier idioma distinto del español) escanea el QR de
su mesa, abre el menú y hace su pedido. El navegador no le ofrece traducir la página ni la traduce
por su cuenta; si intenta traducirla a mano desde el menú del navegador, el texto del menú no
cambia (o el navegador le indica que no puede traducirla). Elige un producto, ajusta opciones y
cantidad, lo agrega, envía el pedido y paga viendo siempre el total correcto.

**Why this priority**: Es la raíz del problema y el flujo que genera ingresos. Hoy un comensal que
traduce la página puede pedir cantidades distintas de las que ve. Bloquear la traducción evita el
problema de raíz en la gran mayoría de los casos, sin depender de que nadie reaccione a un aviso.

**Independent Test**: Se prueba por sí sola abriendo el menú QR con el idioma del sistema en inglés
y verificando que no se ofrece traducir, que un intento manual no cambia el texto, y que el flujo
completo (producto → carrito → envío → pago) termina con el mismo total en pantalla y en el pedido.

**Acceptance Scenarios**:

1. **Given** un navegador con el idioma del sistema en inglés, **When** el comensal abre el menú QR,
   **Then** el navegador no ofrece traducir la página ni la traduce automáticamente.
2. **Given** el menú QR abierto, **When** el comensal intenta traducir la página manualmente desde el
   menú del navegador, **Then** el texto del menú no cambia (o el navegador indica que la página no
   se puede traducir) y la página sigue funcionando en español.
3. **Given** un producto de $ 12.000 con una adición de $ 3.000, **When** el comensal fija cantidad
   3 y agrega, **Then** el botón muestra "Agregar · $ 45.000" y el pedido enviado es de $ 45.000
   (la regla de negocio: el valor cobrado es el del estado de la aplicación y coincide con lo que la
   persona vio antes de confirmar).
4. **Given** el flujo de checkout (revisión, método de pago, transferencia o efectivo, confirmación),
   **When** el comensal avanza paso por paso con el idioma del sistema en inglés, **Then** ninguna
   pantalla ofrece traducción y todos los totales mostrados coinciden con el del pedido.

---

### User Story 2 - Si la página igual es alterada, la persona se entera y queda protegida (Priority: P1)

Algunas extensiones de traducción ignoran el bloqueo. Cuando la página es alterada por el navegador
o por una extensión, la aplicación lo detecta por sí sola, muestra un aviso claro en español con el
botón "Recargar" y, mientras la página siga alterada, deja bloqueadas las acciones que comprometen
dinero o pedidos. Al recargar, la persona vuelve a donde estaba y conserva lo ya confirmado.

**Why this priority**: El bloqueo preventivo no es infalible (extensiones, navegadores que no lo
respetan). Como el fallo es silencioso, sin esta red de seguridad la persona seguiría operando a
ciegas sin saberlo. Es P1 porque el daño potencial es económico: pedidos o cobros con datos que la
persona no ve bien.

**Independent Test**: Se prueba por sí sola alterando a propósito los textos de la página como lo
hace un traductor (sin necesidad de un traductor real): debe aparecer el aviso, deben quedar
bloqueados "Enviar pedido" y el pago, y al pulsar "Recargar" el comensal debe ver su mesa con los
pedidos ya enviados y sus totales intactos.

**Acceptance Scenarios**:

1. **Given** el menú QR abierto con la página sin alterar, **When** una extensión o el navegador
   altera los textos de la página, **Then** aparece un aviso en español con el botón "Recargar" sin
   que la persona haga nada más.
2. **Given** el aviso visible, **When** la persona intenta enviar el pedido o pagar, **Then** esas
   acciones están bloqueadas y la persona entiende por qué (el motivo es visible) y qué hacer
   (recargar).
3. **Given** el aviso visible y un comensal con pedidos ya enviados y productos en su carrito
   confirmado, **When** pulsa "Recargar", **Then** vuelve a la pantalla donde estaba, "Mis pedidos"
   muestra los pedidos ya enviados con sus totales intactos y su carrito conserva lo que tenía.
4. **Given** una página alterada **antes** de que la aplicación termine de cargar (la traducción se
   aplicó al abrir), **When** la aplicación arranca, **Then** el aviso también aparece, sin esperar
   a que la persona interactúe.
5. **Given** el uso normal sin traductor (incluidos errores comunes de red, validaciones y mensajes
   de error de la propia aplicación), **When** la persona navega y opera durante una sesión completa,
   **Then** el aviso nunca aparece.
6. **Given** el aviso visible y un envío de pedido que ya estaba en curso cuando se detectó la
   alteración, **When** el envío termina, **Then** no se cancela ni se duplica, y las acciones nuevas
   quedan bloqueadas hasta recargar.
7. **Given** que el navegador vuelve a traducir la página tras recargar, **When** la aplicación
   arranca, **Then** el aviso reaparece y la persona decide; la aplicación nunca recarga sola en
   bucle.

---

### User Story 3 - El personal usa el panel y las pantallas de acceso sin traducción (Priority: P2)

Una cajera, un mesero o un administrador con el navegador en otro idioma entra a la pantalla de
inicio de sesión, usa el panel (terminal de mesas, órdenes, caja, inventario, reportes, ajustes) o,
en el caso del equipo de plataforma, el área de super-admin. El navegador no ofrece traducir, ninguna
acción se bloquea y los íconos se ven como íconos, no como palabras.

**Why this priority**: El panel tiene los mismos defectos que el menú QR (las cifras del tablero, los
contadores, las etiquetas de botones y el total del modal del POS quedaron desfasados en la
reproducción) y es donde se cobra. Se prioriza P2 porque el personal está capacitado, usa la
aplicación a diario y es menos probable que active la traducción que un comensal ocasional.

**Independent Test**: Se prueba por sí sola entrando al panel con el idioma del sistema en inglés:
no se ofrece traducción, el recorrido por las pantallas principales no muestra texto traducido ni
íconos convertidos en palabras, y las cifras de las tarjetas coinciden con las de una sesión sin
traductor.

**Acceptance Scenarios**:

1. **Given** el navegador con idioma del sistema distinto de español, **When** una persona del
   personal abre el inicio de sesión, la recuperación de contraseña o el panel, **Then** no se
   ofrece traducir la página.
2. **Given** el panel abierto, **When** la persona navega por el menú lateral y usa las acciones de
   cada pantalla, **Then** todos los íconos del menú lateral y de las acciones se ven como íconos.
3. **Given** el panel de administración, **When** el administrador alterna las métricas de la
   tarjeta "Estadísticas de ventas", **Then** las cifras mostradas coinciden con las de una sesión
   sin traductor (Órdenes y Ticket promedio se ven distintos de Ventas).
4. **Given** una página del panel alterada por una extensión, **When** la alteración se detecta,
   **Then** el aviso aparece también en el panel y quedan bloqueadas las acciones equivalentes de
   cobro y creación de pedido en el POS hasta recargar.

---

### User Story 4 - El arreglo llega solo a las pestañas que llevan días abiertas (Priority: P2)

Un terminal POS lleva una pestaña abierta varios días. Cuando se publica una versión nueva, la
aplicación la detecta por sí sola y la aplica en un momento seguro, sin que alguien tenga que
adivinar que debe recargar. Quien ya tenía la aplicación instalada en el dispositivo también pasa
a la versión nueva sin intervención manual.

**Why this priority**: Sin esto, el arreglo (y cualquier arreglo futuro) no llega a quienes ya
tienen la aplicación instalada: hoy esas personas ven la versión anterior una visita más después de
cada despliegue y las pestañas largas, como los terminales POS, hasta que alguien recargue. Es P2
porque depende de las historias 1 y 2 para tener algo útil que desplegar, pero es necesaria para
que el arreglo sea efectivo en producción.

**Independent Test**: Se prueba por sí sola publicando una versión nueva con una pestaña abierta con
la versión anterior: la pestaña debe pasar a la versión nueva en un plazo acotado, solo en un
momento seguro, y sin perder el estado confirmado.

**Acceptance Scenarios**:

1. **Given** una pestaña con la versión anterior abierta y una versión nueva publicada, **When** la
   persona vuelve a la pestaña (o la aplicación revisa al arrancar), **Then** la aplicación detecta
   la versión nueva y la aplica dentro del plazo acordado en Success Criteria.
2. **Given** una versión nueva detectada mientras la persona está en medio de una operación (por
   ejemplo, con un modal de producto abierto, un pago o un envío en curso, o un formulario con datos
   sin guardar), **When** la aplicación intenta aplicar la versión, **Then** espera a un momento
   seguro y no interrumpe la operación.
3. **Given** una versión nueva aplicada, **When** la pantalla se recarga, **Then** la persona conserva
   su sesión y todo lo ya confirmado (sesión de mesa, pedidos enviados, carrito confirmado, sesión
   del panel).
4. **Given** una persona que abre la aplicación por primera vez (sin versión instalada previa),
   **When** carga la página, **Then** recibe directamente la versión más reciente sin pasos
   adicionales.

---

### User Story 5 - Las etiquetas que cambian de estado nunca muestran textos acumulados (Priority: P3)

Los botones y etiquetas que alternan entre dos textos (por ejemplo "Enviar pedido" ↔ "Enviando
pedido…", "Elige una presentación" ↔ "Agregar · $ 4.000", "Iniciar sesión" ↔ "Ingresando…",
"Reenviar enlace en N s" ↔ "Reenviar enlace") muestran siempre solo el texto del estado actual,
nunca una mezcla de estados anteriores y el actual.

**Why this priority**: Es una defensa adicional para el breve intervalo entre que la página es
alterada y la aplicación lo detecta, y para extensiones que evaden la detección. No sustituye al
bloqueo ni al aviso (US1 y US2), por eso es P3.

**Independent Test**: Se prueba por sí sola con la misma alteración simulada de los textos:
alternando varias veces el estado de las etiquetas identificadas, cada una debe mostrar únicamente
el texto del estado actual.

**Acceptance Scenarios**:

1. **Given** la página con los textos alterados, **When** el botón de envío de pedido alterna varias
   veces entre "enviando" y "listo para enviar", **Then** muestra únicamente el texto del estado
   actual.
2. **Given** la página con los textos alterados, **When** el botón "Agregar" alterna entre la
   etiqueta de lo que falta elegir y "Agregar · total", **Then** muestra únicamente el texto del
   estado actual.
3. **Given** el uso normal sin traductor, **When** las mismas etiquetas alternan de estado, **Then**
   el comportamiento visible es idéntico al de hoy.

---

### Edge Cases

- **Falsos positivos**: extensiones no relacionadas con traducción (administradores de contraseñas,
  correctores ortográficos, bloqueadores de anuncios) que modifican partes de la página no deben
  disparar el aviso. El criterio de detección se limita a señales de que el contenido de la
  aplicación fue reescrito o traducido.
- **Errores normales de la aplicación** (red caída, validación de formulario, sesión vencida,
  respuesta 4xx/5xx del servidor) nunca disparan el aviso por sí solos.
- **Traducción aplicada antes de cargar la aplicación**: el aviso debe aparecer igual (ver US2,
  escenario 4).
- **Traducción que revierte**: si la persona vuelve al idioma original y la página queda íntegra, el
  aviso desaparece y se desbloquean las acciones; no obliga a recargar si ya no hay alteración. Si
  la alteración deja textos huérfanos que no se pueden restablecer, o ya produjo un error de DOM atribuible (FR-011), se mantiene el
  aviso hasta recargar.
- **Alteración detectada con un modal de producto abierto**: lo que la persona había seleccionado
  sin confirmar (cantidad u opciones aún no agregadas) se pierde al recargar; es aceptable y el
  aviso lo deja claro. Lo confirmado nunca se pierde.
- **Alteración detectada con un envío o pago en vuelo**: la operación en curso no se cancela ni se
  duplica; solo se bloquean las acciones nuevas.
- **Versión nueva con alteración activa a la vez**: el aviso de alteración tiene prioridad; la
  recarga por versión nueva sigue las mismas reglas de momento seguro.
- **Navegadores que no respetan el bloqueo** (por ejemplo Firefox, fuera de los navegadores
  mínimos): la red de seguridad (aviso y bloqueo de acciones) es la única protección y debe
  funcionar igual.
- **Primera visita**: quien nunca abrió la aplicación recibe la versión más reciente directamente;
  quien ya la tenía instalada puede ver la versión anterior durante una visita después del
  despliegue hasta que la actualización automática la reemplace (ver US4).
- **Impresión y reportes** (por ejemplo el reporte de caja al imprimir) no deben quedar afectados
  por el cambio de idioma declarado ni por el bloqueo.
- **Un comensal que no lee español** verá el menú solo en español. Es una consecuencia aceptada de
  la decisión de producto, no un defecto.

## Requirements *(mandatory)*

### Functional Requirements

**Bloqueo preventivo de la traducción**

- **FR-001**: El sistema MUST declarar en todas sus pantallas que el idioma del contenido es el
  español.
- **FR-002**: El sistema MUST entregar la declaración de idioma español (FR-001) **únicamente junto
  con** el bloqueo de traducción de FR-003; nunca debe desplegarse la una sin el otro, porque
  declarar español sin bloquear podría aumentar las ofertas de traducir en teléfonos en inglés.
- **FR-003**: El sistema MUST bloquear la traducción automática del navegador en todas las pantallas
  del alcance —menú QR, todos los pasos del checkout, panel, super-admin, inicio de sesión,
  recuperación y cambio de contraseña—, incluyendo diálogos y capas superpuestas, usando los
  mecanismos estándar que respetan los navegadores.
- **FR-004**: Con el idioma del sistema distinto de español, el sistema MUST lograr que el navegador
  no ofrezca traducir ni traduzca automáticamente la página, en los navegadores mínimos.
- **FR-005**: Si la persona intenta traducir manualmente desde el menú del navegador, el sistema MUST
  lograr que el texto de la aplicación no cambie (o que el navegador indique que no se puede
  traducir).
- **FR-006**: Los íconos de la aplicación MUST NOT ser traducidos ni mostrarse como palabras en
  ninguna pantalla del alcance.

**Detección de página alterada y aviso**

- **FR-007**: El sistema MUST detectar que el navegador o una extensión alteró el contenido de la
  página, sin depender de que ocurra un error, tanto si la alteración ocurre antes de que la
  aplicación termine de cargar como durante el uso.
- **FR-008**: El criterio de detección MUST ser estricto: solo se activa ante señales de que el
  contenido de la aplicación fue traducido o reescrito (por ejemplo, marcas que dejan los
  traductores), y MUST NOT activarse por errores normales de la aplicación ni por extensiones que
  no reescriben el contenido. Cero falsos positivos en uso normal.
- **FR-009**: Al detectar una alteración, el sistema MUST mostrar un aviso en español, claro y
  visible, con un botón "Recargar". El aviso permanece mientras la página siga alterada y la
  persona no puede descartarlo sin recargar.
- **FR-010**: Si la alteración desaparece por sí sola (la persona restablece el idioma original y la
  página queda íntegra), el sistema MUST retirar el aviso y desbloquear las acciones, salvo que la
  alteración ya haya producido un error de DOM atribuible (FR-011): en ese caso la página puede
  estar inconsistente y el aviso se mantiene hasta recargar.
- **FR-011**: Un error de la aplicación atribuible a la modificación externa de la página MUST
  tratarse igual que una alteración detectada (mismo aviso y mismo bloqueo).

**Protección de acciones**

- **FR-012**: Mientras la página esté alterada, el sistema MUST bloquear las acciones que
  comprometen dinero o pedidos: en el menú QR, el envío del pedido y el pago; en el panel, las
  acciones equivalentes que crean un pedido, cobran, confirman o aprueban un pago, o registran un
  movimiento de dinero (confirmar un pedido sin cobrarlo no entra). El plan enumerará con precisión cada acción siguiendo este criterio.
- **FR-013**: Una acción bloqueada MUST dejar claro a la persona por qué no está disponible y qué
  debe hacer (recargar); no puede quedar como un botón deshabilitado sin explicación.
- **FR-014**: El bloqueo MUST NOT cancelar, duplicar ni corromper una operación que ya estaba en
  curso cuando se detectó la alteración.

**Recuperación**

- **FR-015**: El botón "Recargar" MUST recargar la dirección actual y devolver a la persona al lugar
  donde estaba, conservando lo ya confirmado: sesión de mesa, pedidos enviados y carrito confirmado
  del comensal, y la sesión del personal en el panel.
- **FR-016**: Lo que la persona había seleccionado sin confirmar (por ejemplo, cantidad u opciones de
  un producto que no alcanzó a agregar) puede perderse al recargar; el sistema MUST NOT perder nada
  de lo confirmado.
- **FR-017**: La recarga MUST ser siempre una acción de la persona; el sistema MUST NOT recargar por
  su cuenta cuando detecta una alteración.

**Actualización de versión**

- **FR-018**: El sistema MUST comprobar si hay una versión nueva de la aplicación al arrancar y cada
  vez que la pestaña vuelve a primer plano.
- **FR-019**: Al detectar una versión nueva, el sistema MUST aplicarla recargando la aplicación
  únicamente en un momento seguro: sin un modal de selección de producto abierto, sin un envío o
  pago en curso y sin formularios con datos sin guardar. Si no es un momento seguro, MUST esperar
  sin interrumpir.
- **FR-020**: Al aplicar una versión nueva, el sistema MUST conservar la sesión y todo lo ya
  confirmado (mismo criterio de FR-015).

**Etiquetas que alternan estados y no regresión**

- **FR-021**: Las etiquetas y botones que alternan entre textos de distinto estado (al menos las 47
  identificadas, entre ellas "Agregar"/"Elige…", "Enviar pedido"/"Enviando pedido…", "Iniciar
  sesión", "Reenviar enlace en N s") MUST mostrar solo el texto del estado actual, incluso con la
  página alterada.
- **FR-022**: En uso normal sin traductor, el sistema MUST comportarse igual que hoy: sin aviso, sin
  bloqueos adicionales y sin cambios visibles (incluido lo que alterna de estado).
- **FR-023**: El valor cobrado y enviado al servidor MUST ser siempre el del estado de la aplicación
  (nunca el texto mostrado en pantalla), y el valor que la persona ve antes de confirmar MUST
  coincidir con ese valor.

### Key Entities *(include if feature involves data)*

- **Estado de integridad de la página**: indica si el contenido que ve la persona es el que la
  aplicación escribió (íntegra) o si el navegador/extensión lo alteró (alterada). Es transitorio, no
  se guarda en el servidor, y gobierna la visibilidad del aviso y el bloqueo de acciones.
- **Aviso de página alterada**: mensaje en español con el botón "Recargar", visible mientras el
  estado sea "alterada".
- **Acción protegida**: acción que crea un pedido, cobra, confirma o aprueba un pago o registra un
  movimiento de dinero; queda bloqueada mientras el estado sea "alterada".
- **Versión de la aplicación (instalada y disponible)**: la que el dispositivo está sirviendo y la
  más reciente publicada; su diferencia dispara la actualización en un momento seguro.

## Impacto y compatibilidad

- **Datos existentes**: ninguno. No hay cambios al modelo de datos, a pedidos, facturas ni
  históricos; el estado de integridad de la página no se persiste. La inmutabilidad de lo ya emitido
  no se ve afectada.
- **Comportamiento existente que cambia (decisión de negocio, a registrar en el libro de
  anomalías durante la fase de plan)**: (a) con la página alterada, "Enviar pedido", el pago y las
  acciones equivalentes del POS quedan bloqueados hasta recargar (antes se podía operar); (b) la
  aplicación puede recargarse sola, en un momento seguro, al detectar una versión nueva (antes
  esperaba a que la persona recargara); (c) un comensal que no lee español ya no puede traducir el
  menú (antes podía, con los fallos descritos). Sin traductor, nada cambia para el usuario.
- **Interacción con otras funcionalidades**: la recuperación tras recargar reutiliza la
  rehidratación de sesión y carrito del checkout que ya existe (spec 034); los pasos de pago por
  transferencia y mixto (specs 125 y 132) y el rediseño del menú QR y del Terminal de Mesas (specs
  130 y 131) son superficies que este cambio toca solo para proteger sus acciones y estabilizar sus
  etiquetas, sin alterar su flujo.
- **Despliegue**: FR-002 obliga a entregar juntos el idioma declarado y el bloqueo. Quien ya tiene la
  aplicación instalada recibe el arreglo una visita después del despliegue; FR-018 a FR-020 acortan
  esa espera para pestañas largas.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: En los cinco navegadores mínimos (Chrome Android, Safari iOS, Chrome escritorio, Edge
  escritorio y Samsung Internet), con el idioma del sistema en inglés, el 100% de las aperturas del
  menú QR, del panel y del inicio de sesión no muestran la oferta de traducir, y el 100% de los
  intentos de traducción manual dejan el texto sin cambios o el navegador indica que no se puede
  traducir. *(Verificación manual en dispositivos reales; ver Assumptions.)*
- **SC-002**: Un comensal con el idioma del sistema en inglés completa el flujo elegir producto →
  ajustar opciones y cantidad → agregar → enviar pedido → pagar sin errores, y en el 100% de las
  pruebas el total mostrado coincide con el total del pedido enviado.
- **SC-003**: Al alterar los textos de la página como lo hace un traductor, el aviso con "Recargar"
  aparece en menos de 3 segundos en el 100% de las pruebas, en cada una de las pantallas
  reproducidas: modal de producto (menú QR y POS), línea de carrito, botón "Enviar pedido", tarjeta
  "Estadísticas de ventas", filtro del Terminal de Mesas y título del encabezado.
- **SC-004**: Con el aviso visible, el 100% de los intentos de enviar el pedido, pagar o ejecutar
  una acción protegida del POS son rechazados con una explicación visible, y 0 operaciones en curso
  se cancelan o duplican.
- **SC-005**: Tras pulsar "Recargar", el 100% de los pedidos ya enviados y del carrito confirmado
  siguen visibles con sus totales idénticos a los de antes de recargar.
- **SC-006**: Durante un recorrido completo sin traductor (menú QR, checkout y las pantallas
  principales del panel, con extensiones habituales no relacionadas con traducción), el aviso
  aparece 0 veces y el 100% de las pruebas existentes de las pantallas tocadas siguen pasando.
- **SC-007**: Con los textos alterados, las etiquetas que alternan estados identificadas muestran
  solo el texto del estado actual en el 100% de las alternancias probadas (0 apariciones de textos
  acumulados como "Enviar pedido Enviar pedido").
- **SC-008**: Una pestaña con la versión anterior abierta pasa a la versión nueva sin intervención
  manual dentro de los 5 minutos siguientes a volver a primer plano, y en ningún caso se recarga
  durante un modal de producto abierto, un envío o un pago en curso. *(El plazo de 5 minutos es el
  valor propuesto; el plan puede ajustarlo con justificación.)*
- **SC-009**: En el panel, los íconos del menú lateral y de las acciones se ven como íconos en el
  100% de las pantallas revisadas, en los navegadores mínimos.

## Assumptions

- **Idioma del teléfono del caso reportado**: se desconoce (inglés o español). La spec cubre
  celulares con el idioma del sistema en inglés y en español: el bloqueo y la red de seguridad
  funcionan igual en ambos casos. Con la declaración actual de idioma inglés, es posible que los
  usuarios con celular en español sean hoy quienes reciben la oferta de traducir; no se verificó.
- **Verificación en dispositivos reales**: en el entorno de desarrollo solo se puede automatizar
  Chrome de escritorio, y solo con una alteración simulada (no con el traductor real). Los
  criterios con traducción real y en Safari iOS, Samsung Internet, Edge y Chrome Android se
  declaran como **verificación manual diferida** en dispositivos reales; no se conoce qué
  dispositivos hay disponibles.
- **Navegadores mínimos**: Chrome Android, Safari iOS, Chrome escritorio, Edge escritorio y Samsung
  Internet. Firefox queda fuera: no respeta el bloqueo estándar de traducción, por lo que ahí solo
  actúa la red de seguridad. El soporte del bloqueo en Safari iOS y Samsung Internet no está
  confirmado con fuentes; los servicios de traducción de Google y Microsoft sí lo respetan.
- **Criterio de "acción protegida"**: cualquier acción que cree un pedido, cobre, confirme o apruebe
  un pago, o registre un movimiento de dinero de caja (confirmar un pedido sin cobrarlo no entra). Si negocio prefiere un conjunto menor
  (solo cobro y creación de pedido), se ajusta en el plan. Superficies conocidas a cubrir: panel de
  cobro de la Terminal, cuenta de sesión de mesa, armado de orden manual y revisión de "Pagos por
  confirmar" del cajero.
- **Aviso no descartable**: mientras la página siga alterada, el aviso no se puede cerrar, solo
  recargar. Lo demás de la pantalla puede seguir visible (con datos posiblemente desfasados); el
  aviso y el bloqueo de acciones protegidas son la garantía, no la exactitud de lo mostrado.
- **Momento seguro** para aplicar una versión nueva: sin modal de producto abierto, sin pago ni envío
  en curso y sin formularios con datos sin guardar. El plan fija la lista definitiva de pantallas.
- **Recarga**: la aplicación ya conserva la sesión de mesa (en el dispositivo), el carrito (en el
  servidor) y los pedidos enviados (en el servidor), y devuelve a la persona al paso correcto del
  checkout. No hay que construir persistencia nueva para esos datos.
- **Hechos verificados del despliegue** (2026-10-24, producción y código): la aplicación se sirve
  como aplicación instalable con service worker; la navegación sirve primero la versión ya
  instalada y revisa si hay una nueva después, en reposo; hoy la aplicación no comprueba
  versiones nuevas por sí sola (solo gestiona notificaciones push); la página principal y el
  manifiesto de versión se sirven siempre revalidados. El comensal de primera visita no tiene
  versión instalada y recibe directamente la página más reciente.
- **Fuera de alcance**: el landing (que ya declara español), los correos transaccionales, la
  traducción real del contenido (internacionalización) y cualquier cambio de diseño visual más allá
  del aviso.
- **Registro de decisiones de negocio**: las tres decisiones de comportamiento descritas en
  "Impacto y compatibilidad" se registran en `specs/000-reconocimiento/registro-de-anomalias.md`
  durante la fase de plan, con quién (el dueño del producto) y cuándo (2026-10-24).
