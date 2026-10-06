# Feature Specification: Rediseño unificado de inicio de sesión y recuperación de contraseña

**Feature Branch**: `style/095-auth-screens-redesign`

**Created**: 2026-10-05

**Status**: Draft

**Input**: User description: rediseñar y unificar la experiencia de autenticación (inicio de sesión y recuperación de contraseña) de SkeiloPOS a partir de las vistas `Login.dc.html` y `Nueva contrasena.dc.html`, con layout de dos columnas, etiqueta de negocio dinámica según subdominio, respuestas genéricas de seguridad, bloqueo de reenvío y accesibilidad WCAG AA.

## Contexto y Encuadre

Esta spec es **un rediseño de superficie**: el comportamiento funcional de autenticación y
recuperación de contraseña ya existe y está protegido por specs anteriores, y el negocio decidió en
D2 no abrir ninguna superficie pública nueva. No hay cambios en el servidor. Antes de redactar los
requisitos se verificó el estado real del código en ambos repositorios:

| Capacidad | Estado actual verificado | Qué cambia en esta spec |
|---|---|---|
| Inicio de sesión | `POST /api/v1/auth/login` recibe `email` (`EmailStr`) + `password` (spec 001) | Solo presentación (ver D1 para el identificador) |
| Solicitud de enlace | `POST /api/v1/auth/forgot-password`, respuesta genérica ya implementada (spec 031, FR-004) | Solo presentación |
| Validación de enlace | `GET /api/v1/auth/reset-password/validate`, sin efecto secundario (spec 031, FR-007) | Solo presentación |
| Nueva contraseña | `POST /api/v1/auth/reset-password`, token de un solo uso, 30 min, cierra todas las sesiones (spec 031, FR-009) | Solo presentación |
| Límite de solicitudes | Ventana deslizante de **3 solicitudes / 900 s** por tenant+correo (spec 031) | Se conserva; se corrige el supuesto de "1 hora" del pedido |
| Política de contraseña | **8 a 12 caracteres**, sin exigir mayúsculas, números ni símbolos (spec 031, FR-019) | Se conserva; el mockup se ajusta a ella (ver D4) |
| Host no reconocido | Resuelto en cliente sin llamar al API (spec 091, FR-005/FR-006) | Solo textos y presentación |
| Subdominio no **registrado** | **Indetectable sin preguntar al servidor**: cualquier subdominio no reservado se trata como tenant válido y muestra el formulario | No cambia: limitación conocida y aceptada (D12) |
| Etiqueta del negocio | Se muestra el **slug** del subdominio; el nombre comercial vive tras `GET /api/v1/tenant`, que exige sesión | No cambia: se conserva el slug, sin exponer nada (D2) |
| Sesión extendida | **No existe**: vida de token fija (acceso 1 día, refresco 7 días) | No cambia; se añade el control inerte en la interfaz (D3) |

Las pantallas vigentes a rediseñar son `login.component.ts`, `forgot-password.component.ts` y
`reset-password.component.ts` en `pos-heladeria`. **Ninguna parte de esta spec toca
`pos-backend`.**

Conforme al Principio II de la constitución, cualquier requisito de esta spec que altere un
comportamiento ya protegido queda marcado explícitamente y exige registro en
`specs/000-reconocimiento/registro-de-anomalias.md` antes de implementarse.

## Clarifications

### Session 2026-10-05

- Q: ¿Qué origen debe tener el nombre del negocio que muestra la etiqueta? (D2, FR-007) → A: El identificador del subdominio; no se expone ningún dato del negocio sin autenticación.
- Q: ¿Cómo debe presentarse el identificador del subdominio en la etiqueta? (FR-007) → A: Tal cual aparece en la dirección, sin retoques de formato.

> **Corrección de esta sesión**: D2 se había resuelto inicialmente autorizando una consulta pública
> de identidad del negocio, y de esa decisión derivaron tres clarificaciones —qué datos expondría,
> con qué límite de solicitudes y con qué registro de consultas fallidas—. Al corregirse D2 a "sin
> exposición pública", esas tres preguntas quedaron sin objeto y se retiraron junto con los
> requisitos que habían generado, para no dejar en la spec requisitos sobre un endpoint que no
> existirá.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Entrar al sistema desde el subdominio del negocio (Priority: P1)

Un cajero, mesero o administrador abre la dirección de su negocio, reconoce de inmediato que
está en la puerta correcta porque ve la marca de SkeiloPOS y la etiqueta de su negocio, escribe
sus credenciales y entra a la pantalla que le corresponde por su rol.

**Why this priority**: es la pantalla de entrada obligatoria de todos los usuarios del sistema;
si se degrada, nadie puede trabajar. Es también la única pantalla que todo usuario ve todos los
días, así que es donde el rediseño rinde más.

**Independent Test**: se puede probar por completo abriendo el subdominio de un tenant, enviando
credenciales válidas y confirmando que el usuario llega a su pantalla de destino con la nueva
presentación, sin tocar el flujo de recuperación.

**Acceptance Scenarios**:

1. **Given** que abro la dirección de inicio de sesión de un subdominio de tenant registrado,
   **When** carga la pantalla, **Then** veo la marca de SkeiloPOS, la etiqueta con el identificador
   del negocio, el título "Bienvenido de nuevo.", el campo de correo electrónico, el campo de
   contraseña, el control "Mantener sesión iniciada", el enlace "¿Olvidaste tu contraseña?", el
   botón "Iniciar sesión" y un pie con el año de copyright actual y el enlace a la Política de
   privacidad.
1b. **Given** que abro cualquiera de las tres pantallas, **When** termina de cargar, **Then** la
   etiqueta ya muestra su texto definitivo, sin estado de carga intermedio y sin que su contenido
   cambie después.
2. **Given** que abro la dirección de inicio de sesión del subdominio de administración de la
   plataforma, **When** carga la pantalla, **Then** la etiqueta dice "Administración de la
   plataforma" y no aparece ningún nombre ni slug de negocio.
3. **Given** que abro el dominio raíz, un identificador reservado o un host ajeno, **When** carga
   la pantalla, **Then** veo el mensaje "No encontramos este negocio" con un enlace al sitio
   principal, el formulario no se renderiza y no se emite ninguna petición.
3b. **Given** que abro un subdominio con forma válida cuyo negocio no está registrado, **When**
   carga la pantalla, **Then** la pantalla de inicio de sesión se renderiza con normalidad, y al
   enviar cualquier credencial recibo "Credenciales inválidas" sin que se me revele que ese negocio
   no existe (limitación conocida, D12).
4. **Given** que envío credenciales válidas, **When** el sistema las acepta, **Then** soy
   redirigido a la pantalla de destino que intentaba abrir, o a la pantalla inicial de mi rol si
   no venía de ninguna.
5. **Given** que envío credenciales que no corresponden a ninguna cuenta activa de este
   subdominio, **When** el sistema las rechaza, **Then** veo el error "Credenciales inválidas",
   el campo de contraseña queda vacío y con el foco, y el identificador que escribí se conserva.
6. **Given** que envío el formulario con algún campo obligatorio vacío, **When** intento enviar,
   **Then** veo el error de obligatoriedad del campo correspondiente y no se emite ninguna
   petición de autenticación.
7. **Given** que ya envié el formulario y el sistema aún no responde, **When** vuelvo a pulsar el
   botón de envío, **Then** el botón está deshabilitado, muestra un indicador de progreso y no se
   emite una segunda petición.
8. **Given** que el campo de contraseña está oculto, **When** pulso el control de visibilidad,
   **Then** el contenido se vuelve legible, el control anuncia su nueva acción a las ayudas
   técnicas, y al pulsarlo de nuevo vuelve a ocultarse.
9. **Given** que uso un gestor de contraseñas, **When** enfoco los campos, **Then** el gestor
   ofrece el autocompletado de correo y de contraseña actual en el inicio de sesión, y de
   contraseña nueva en la pantalla de creación.
9b. **Given** que marco el control "Mantener sesión iniciada", **When** inicio sesión, **Then** la
   duración de mi sesión es exactamente la misma que si no lo hubiera marcado, y no se almacena
   en el navegador ninguna contraseña ni ningún dato derivado de ella.
10. **Given** cualquier rol existente (super administrador de plataforma, administrador de tenant,
    cajero, mesero), **When** inicia sesión tras el rediseño, **Then** llega a la misma pantalla
    inicial y conserva exactamente los mismos permisos que antes del rediseño.

---

### User Story 2 - Recuperar el acceso cuando olvidé la contraseña (Priority: P2)

Un usuario que no recuerda su contraseña pide un enlace de recuperación desde la pantalla de
inicio de sesión de su negocio, recibe confirmación de que el envío se procesó y entiende cuánto
tiempo tiene para usarlo, sin que la pantalla le revele si esa cuenta existe o no.

**Why this priority**: sin este flujo un usuario bloqueado depende de que un administrador
intervenga, pero el usuario puede trabajar con normalidad mientras recuerde su contraseña, así que
no bloquea la operación diaria como la Historia 1.

**Independent Test**: se puede probar por completo pidiendo un enlace desde la pantalla de
solicitud y verificando el mensaje genérico, la cuenta regresiva de reenvío y el mensaje de
límite excedido, sin ejecutar el cambio de contraseña.

**Acceptance Scenarios**:

1. **Given** que estoy en la pantalla de inicio de sesión, **When** pulso "¿Olvidaste tu
   contraseña?", **Then** llego a la pantalla de solicitud con el título "Restablece tu
   contraseña.", el campo de identificación y el botón "Enviar enlace".
2. **Given** que envío una identificación cualquiera —exista o no la cuenta—, **When** el sistema
   procesa la solicitud, **Then** veo siempre el mismo mensaje de confirmación genérico, que
   indica que si la cuenta existe se envió un enlace al correo registrado y que el enlace caduca
   en 30 minutos.
3. **Given** que acabo de solicitar un enlace, **When** la pantalla muestra la confirmación,
   **Then** el control de reenvío permanece deshabilitado durante 60 segundos mostrando una cuenta
   regresiva visible, y se habilita al terminar.
4. **Given** que supero el límite de solicitudes permitido para la misma cuenta dentro de su
   ventana de tiempo, **When** envío otra solicitud, **Then** veo un mensaje que indica que hubo
   demasiados intentos y que debo intentarlo más tarde, sin revelar si la cuenta existe.
5. **Given** que estoy en la pantalla de solicitud o en la de confirmación de envío, **When** pulso
   "Volver a iniciar sesión", **Then** regreso a la pantalla de inicio de sesión del mismo
   subdominio en el que estoy.

---

### User Story 3 - Crear una contraseña nueva desde el enlace recibido (Priority: P2)

El usuario abre el enlace que recibió por correo, ve con claridad qué requisitos debe cumplir su
contraseña nueva, la crea, y queda informado de que sus sesiones anteriores se cerraron.

**Why this priority**: completa la Historia 2 —un enlace que no se puede consumir no recupera
nada—, pero es la segunda mitad del mismo recorrido y se prueba después de ella.

**Independent Test**: se puede probar por completo abriendo la pantalla con un enlace válido,
creando una contraseña que cumpla la política y confirmando que se llega al inicio de sesión con
el aviso de éxito; y repitiendo con un enlace vencido o ya usado.

**Acceptance Scenarios**:

1. **Given** un enlace de recuperación vigente y no usado, **When** abro la pantalla, **Then** veo
   el título "Crea tu nueva contraseña.", los campos "Nueva contraseña" y "Confirmar contraseña",
   y la lista de requisitos de la política vigente.
2. **Given** que escribo una contraseña en el campo "Nueva contraseña", **When** cambia su
   contenido, **Then** cada requisito de la lista indica visualmente si se cumple o no, y ese
   estado se anuncia también a las ayudas técnicas sin depender solo del color.
3. **Given** una contraseña que cumple la política y una confirmación idéntica, **When** envío el
   formulario, **Then** la contraseña queda cambiada, mis sesiones activas anteriores se cierran,
   y llego al inicio de sesión con el mensaje "Contraseña actualizada".
4. **Given** una contraseña que cumple la política pero una confirmación distinta, **When** envío
   el formulario, **Then** veo el error de que las contraseñas no coinciden y no se envía la
   petición de cambio.
5. **Given** una contraseña que no cumple la política, **When** envío el formulario, **Then** veo
   el error correspondiente y no se envía la petición de cambio.
6. **Given** un enlace vencido, ya usado o invalidado por una solicitud posterior, **When** abro la
   pantalla, **Then** veo "Este enlace ya no es válido", un botón "Solicitar un enlace nuevo", y
   el formulario de creación no se renderiza.
7. **Given** que la contraseña nueva es idéntica a mi contraseña actual, **When** envío el
   formulario, **Then** veo el error que indica que debe ser distinta de la actual y la contraseña
   no cambia.

---

### User Story 4 - Usar las pantallas de autenticación en cualquier dispositivo (Priority: P3)

Un usuario que entra desde el celular del negocio o desde una tableta ve el formulario ocupando
todo el ancho disponible, sin desplazamiento horizontal y sin esperar la descarga de recursos
decorativos que no va a ver.

**Why this priority**: mejora la experiencia en los dispositivos donde más se usa el punto de
venta, pero las tres historias anteriores ya entregan un sistema funcional en escritorio.

**Independent Test**: se puede probar por completo redimensionando cada una de las tres pantallas
entre 360 px y escritorio, y auditando la carga de recursos y la accesibilidad por teclado.

**Acceptance Scenarios**:

1. **Given** una resolución de 1024 px o más, **When** abro cualquiera de las tres pantallas,
   **Then** veo el layout de dos columnas, con el formulario a la izquierda y el panel de marca a
   la derecha mostrando el lema "Tu negocio. Más rápido." y la vista previa del sistema.
2. **Given** una resolución menor a 1024 px, **When** abro cualquiera de las tres pantallas,
   **Then** el panel de marca no se muestra, su imagen de vista previa no se descarga, y el
   formulario ocupa el ancho completo.
3. **Given** una resolución de 360 px de ancho, **When** abro cualquiera de las tres pantallas,
   **Then** no hay desplazamiento horizontal y todo el contenido del formulario y del pie queda
   alcanzable.
4. **Given** que navego solo con el teclado, **When** recorro cualquiera de las tres pantallas,
   **Then** el orden de tabulación sigue el orden visual, cada elemento enfocado muestra un
   indicador de foco visible, y puedo activar todos los controles sin usar el apuntador.
5. **Given** que uso un lector de pantalla, **When** recorro cualquiera de las tres pantallas,
   **Then** cada campo anuncia su etiqueta, los mensajes de error y de estado se anuncian al
   aparecer, y el control de visibilidad de contraseña anuncia su acción.

---

### Edge Cases

- **Pie de página al cambiar de año**: el año del copyright se toma de la fecha del momento de
  carga, no de un valor escrito a mano, de modo que no quede obsoleto el 1 de enero.
- **Enlace de recuperación abierto en otro subdominio**: un enlace emitido para un tenant que se
  abre en el subdominio de otro tenant, o en el de administración, **sigue funcionando** y fija la
  contraseña de su cuenta de origen. Limitación conocida y aceptada (D13, FR-037, A-111).
- **Enlace de recuperación abierto sin parámetro de token**: la pantalla se comporta igual que con
  un enlace no válido, mostrando la opción de solicitar uno nuevo.
- **Reenvío con la pestaña en segundo plano**: la cuenta regresiva de 60 segundos se calcula sobre
  tiempo transcurrido real, no sobre ciclos de temporizador, para que no se alargue si el
  navegador los pausa.
- **Recarga durante la cuenta regresiva**: al recargar la pantalla de confirmación, el bloqueo de
  reenvío no se puede eludir reiniciándolo a cero por el solo hecho de recargar.
- **Pérdida de conexión durante el envío**: el botón sale del estado de carga y aparece un mensaje
  que permite reintentar, sin dejar el formulario bloqueado de forma permanente.
- **Varias solicitudes de enlace para la misma cuenta**: la emisión de un enlace nuevo invalida de
  inmediato el anterior, de modo que solo el último recibido funciona.
- **Cuenta desactivada**: una cuenta inactiva recibe exactamente el mismo trato que una
  inexistente, tanto al iniciar sesión como al solicitar un enlace.
- **Autocompletado del navegador al cargar**: si el navegador rellena los campos por su cuenta, el
  botón de envío queda habilitado y la validación no marca los campos como vacíos.
- **Imagen del panel de marca no disponible**: el panel conserva el lema y el texto legibles, sin
  dejar un hueco roto ni romper el layout.
- **Identificador de subdominio muy largo**: la etiqueta no desborda su contenedor ni empuja el
  formulario, y se recorta de forma legible en lugar de romper el layout.
- **Negocio con plan vencido**: la pantalla se comporta exactamente igual que con cualquier otro
  negocio registrado; el estado de la suscripción no se refleja en la etiqueta ni en el formulario,
  y se resuelve, como hoy, al intentar iniciar sesión.
- **Subdominio con forma válida pero no registrado**: la pantalla se renderiza con normalidad y el
  intento de autenticación falla con el mensaje genérico, sin revelar que el negocio no existe
  (D12).

## Requirements *(mandatory)*

### Requisitos de Layout y Marca

- **FR-001**: Las tres pantallas de autenticación (inicio de sesión, solicitud de enlace y
  creación de contraseña nueva) DEBEN compartir el mismo layout base de dos columnas, de modo que
  el usuario perciba un único sistema al moverse entre ellas.
- **FR-002**: La columna del formulario DEBE contener, en este orden: la marca de SkeiloPOS, la
  etiqueta de contexto del acceso, el contenido propio de la pantalla, y un pie de página.
- **FR-003**: El pie de página DEBE mostrar el año de copyright correspondiente a la fecha actual
  del momento de carga y un enlace a la Política de privacidad publicada en el sitio público de
  SkeiloPOS.
- **FR-003a**: El enlace a la Política de privacidad y el enlace al sitio principal de la vista de
  host no reconocido (FR-009) DEBEN apuntar a páginas que existen y responden; esta spec no crea
  páginas nuevas en el sitio público.
- **FR-004**: La columna de marca DEBE mostrar el lema "Tu negocio. Más rápido.", su texto de
  apoyo y la vista previa del sistema.
- **FR-005**: Por debajo de 1024 px de ancho de viewport, la columna de marca NO DEBE mostrarse y
  su imagen de vista previa NO DEBE descargarse.
- **FR-006**: Desde 360 px de ancho de viewport, ninguna de las tres pantallas DEBE producir
  desplazamiento horizontal.

### Requisitos de Etiqueta Dinámica por Subdominio

- **FR-007**: En un subdominio de tenant registrado, la etiqueta de contexto DEBE mostrar el
  **identificador del subdominio** del negocio al que pertenece ese subdominio, **tal cual aparece
  en la dirección**: sin capitalizar, sin separar palabras y sin ninguna otra transformación de
  formato, para que coincida exactamente con lo que el usuario tecleó para llegar.
- **FR-007a**: La etiqueta DEBE resolverse **sin consultar al servidor**, a partir de lo que el
  propio subdominio ya proporciona, de modo que la pantalla no dependa de ninguna petición para
  mostrarse completa.
- **FR-007b**: El sistema NO DEBE exponer sin autenticación ningún dato del negocio —nombre
  comercial, logotipo, contacto, plan, configuración, facturación ni usuarios—. La pantalla de
  inicio de sesión se construye únicamente con lo que el subdominio ya revela por sí mismo.
- **FR-007c**: La etiqueta DEBE renderizarse de inmediato al cargar la pantalla, sin estados
  intermedios de carga ni cambios de texto posteriores.
- **FR-007d**: La identidad visual de la pantalla DEBE ser la de SkeiloPOS: la etiqueta acompaña el
  identificador del negocio con un distintivo genérico, no con el logotipo del negocio.
- **FR-008**: En el subdominio de administración de la plataforma, la etiqueta de contexto DEBE
  decir "Administración de la plataforma" y NO DEBE mostrar ningún identificador de negocio.
- **FR-009**: En un host que no corresponde a ningún acceso —el dominio raíz, un identificador
  reservado o un host ajeno—, el sistema DEBE mostrar "No encontramos este negocio" con un enlace
  al sitio principal, NO DEBE renderizar ningún formulario y NO DEBE emitir ninguna petición.
- **FR-009a**: En un subdominio con forma válida cuyo negocio **no está registrado**, el sistema
  DEBE renderizar la pantalla de inicio de sesión con normalidad, y el intento de autenticación
  DEBE fallar con el mensaje genérico "Credenciales inválidas" (FR-012), sin revelar que ese
  negocio no existe. Es una limitación conocida y aceptada, documentada en D12: distinguir ese
  caso exigiría preguntar al servidor, y D2 decidió no abrir esa consulta.
- **FR-010**: La clasificación del tipo de host DEBE seguir usando el mecanismo ya existente
  (spec 091), sin introducir una segunda fuente de verdad sobre qué host es de administración,
  cuál es de tenant y cuál no es ninguno de los dos, y sin emitir ninguna petición para decidirlo.

### Requisitos del Inicio de Sesión

- **FR-011**: La pantalla de inicio de sesión DEBE ofrecer un campo de correo electrónico, un campo
  de contraseña con control de visibilidad, el control "Mantener sesión iniciada", el enlace a la
  recuperación de contraseña y un botón de envío.
- **FR-011a**: La identificación de la cuenta DEBE seguir siendo exclusivamente el correo
  electrónico, y la etiqueta del campo DEBE decir "Correo electrónico", sin ofrecer ni insinuar un
  nombre de usuario alternativo que el sistema no reconoce.
- **FR-012**: Un intento de inicio de sesión fallido DEBE mostrar siempre el mismo mensaje
  "Credenciales inválidas", sin distinguir entre identificación inexistente, contraseña incorrecta
  y cuenta desactivada.
- **FR-013**: Tras un intento fallido, el sistema DEBE limpiar el campo de contraseña, darle el
  foco, y conservar el valor del campo de correo electrónico.
- **FR-014**: El envío con campos obligatorios vacíos DEBE mostrar el error de obligatoriedad del
  campo correspondiente sin emitir ninguna petición.
- **FR-015**: Mientras una petición de inicio de sesión está en curso, el botón de envío DEBE
  quedar deshabilitado con un indicador de progreso visible, y el sistema NO DEBE emitir peticiones
  adicionales del mismo formulario.
- **FR-016**: El control de visibilidad de la contraseña DEBE alternar entre contenido oculto y
  legible, y DEBE anunciar a las ayudas técnicas la acción que ejecutará al pulsarse.
- **FR-017**: Los campos DEBEN declarar sus tipos de autocompletado estándar de forma que un gestor
  de contraseñas ofrezca correo y contraseña actual en el inicio de sesión, y contraseña nueva en
  la pantalla de creación.
- **FR-018**: Un inicio de sesión exitoso DEBE llevar al usuario a la pantalla de destino que
  intentaba abrir, o a la pantalla inicial de su rol cuando no haya destino previo.
- **FR-019**: Todos los roles existentes DEBEN conservar, tras el rediseño, la misma pantalla
  inicial y los mismos permisos que antes.

### Requisitos del Control "Mantener sesión iniciada" (sin efecto en esta spec)

> Este bloque describe un control deliberadamente inerte. La capacidad de sesión extendida se
> especificará aparte (D3); aquí solo se maqueta su presencia, y estos requisitos existen para
> acotar qué **no** debe hacer mientras no exista.

- **FR-019a**: La pantalla de inicio de sesión DEBE incluir el control "Mantener sesión iniciada",
  marcable y desmarcable, con su etiqueta asociada y alcanzable por teclado como cualquier otro
  control del formulario.
- **FR-019b**: El estado del control NO DEBE alterar en ninguna medida la duración de la sesión: un
  inicio de sesión con el control marcado y otro sin marcar DEBEN producir sesiones de la misma
  duración.
- **FR-019c**: El estado del control NO DEBE enviarse al servidor, de modo que no se introduzca un
  parámetro de autenticación que ninguna parte del sistema interpreta.
- **FR-019d**: El sistema NO DEBE almacenar, ni en el navegador ni en ningún otro lugar, la
  contraseña del usuario ni ningún dato derivado de ella, con el control marcado o sin marcar.
- **FR-019e**: La etiqueta del control NO DEBE afirmar que se recuerda o se guarda la contraseña,
  porque el sistema no lo hace.

### Requisitos de la Solicitud de Enlace

- **FR-020**: La solicitud de un enlace de recuperación DEBE responder siempre con el mismo mensaje
  genérico, que indique que si la cuenta existe se envió un enlace al correo registrado **y que ese
  enlace caduca en 30 minutos**, sin revelar si la cuenta existe, está desactivada o pertenece a
  otro negocio.
- **FR-021**: Tras una solicitud, el control de reenvío DEBE permanecer deshabilitado durante 60
  segundos, mostrando una cuenta regresiva visible, y habilitarse al terminar.
- **FR-022**: La cuenta regresiva de reenvío DEBE calcularse sobre tiempo transcurrido real, de
  modo que no se alargue si el navegador pausa sus temporizadores, y NO DEBE poder eludirse
  recargando la pantalla. Su alcance es la pestaña: abrir otra, o limpiar el almacenamiento, lo
  reinicia, y eso es aceptable porque FR-024 lo subordina al límite del servidor.
- **FR-023**: Cuando el sistema rechaza la solicitud por exceso de intentos, la pantalla DEBE
  mostrar un mensaje que indique que hubo demasiados intentos y que se debe intentar más tarde, sin
  revelar si la cuenta existe.
- **FR-024**: El bloqueo de reenvío del punto FR-021 es una protección de la interfaz y NO
  sustituye al límite de solicitudes del servidor, que DEBE seguir aplicándose con su
  configuración vigente (3 solicitudes por ventana de 900 segundos, por negocio y cuenta).
- **FR-025**: Desde la pantalla de solicitud y desde la de confirmación de envío, el control
  "Volver a iniciar sesión" DEBE regresar al inicio de sesión del mismo subdominio actual.

### Requisitos de la Creación de Contraseña Nueva

- **FR-026**: La pantalla de creación DEBE ofrecer los campos "Nueva contraseña" y "Confirmar
  contraseña", cada uno con su propio control de visibilidad.
- **FR-027**: La pantalla DEBE mostrar la lista de requisitos de la política de contraseñas
  vigente, indicando para cada uno si la contraseña escrita lo cumple.
- **FR-028**: El estado de cumplimiento de cada requisito NO DEBE comunicarse únicamente por color;
  DEBE acompañarse de un indicador perceptible sin distinguir colores y anunciarse a las ayudas
  técnicas.
- **FR-029**: La validación de la contraseña nueva DEBE aplicar la política vigente definida en
  spec 031 (FR-019): entre 8 y 12 caracteres, sin exigir combinaciones obligatorias de mayúsculas,
  números ni símbolos.
- **FR-030**: Un envío cuya confirmación no coincida con la contraseña nueva DEBE mostrar el error
  de no coincidencia sin emitir la petición de cambio.
- **FR-031**: Un cambio exitoso DEBE llevar al inicio de sesión con el mensaje "Contraseña
  actualizada".
- **FR-032**: Cuando el enlace está vencido, ya fue usado o fue invalidado por una solicitud
  posterior, la pantalla DEBE mostrar "Este enlace ya no es válido" y un botón "Solicitar un enlace
  nuevo", y NO DEBE renderizar el formulario de creación.
- **FR-033**: El sistema DEBE conservar sin cambios las garantías de seguridad ya implementadas en
  spec 031: el enlace es de un solo uso, caduca a los 30 minutos, el cambio cierra todas las
  sesiones activas anteriores de la cuenta, y la contraseña nueva debe ser distinta de la actual.
- **FR-034**: La validación del enlace al cargar la pantalla NO DEBE consumirlo, de modo que el
  usuario pueda escribir su contraseña y enviarla con el mismo enlace.

### Requisitos de Aislamiento Multitenant y Super Admin

- **FR-035**: Las credenciales y las solicitudes de recuperación DEBEN resolverse únicamente contra
  las cuentas del negocio al que corresponde el subdominio de origen; el mismo correo en otro
  negocio es una cuenta distinta.
- **FR-036**: Un super administrador de plataforma DEBE poder **solicitar** la recuperación de su
  contraseña únicamente desde el subdominio de administración. La **ejecución** del enlace no está
  atada al subdominio, por la misma limitación de FR-037 y D13.
- **FR-037**: Un enlace de recuperación se resuelve **únicamente por su token**, sin atarse al
  subdominio de origen: abierto en el subdominio de otro negocio o en el de administración, el
  enlace **sigue siendo válido** y permite fijar la contraseña de la cuenta para la que se emitió.
  Es una limitación conocida y aceptada, documentada en D13: atar el enlace al negocio exigiría
  modificar dos endpoints de autenticación, y FR-044 lo prohíbe en esta misma spec. El aislamiento
  de la **cuenta** no se rompe —el enlace solo cambia la contraseña de su propio dueño—; lo que no
  es hermético es el aislamiento del **subdominio**.

### Requisitos de Accesibilidad

- **FR-038**: Cada campo de formulario DEBE tener una etiqueta visible asociada de forma
  programática a su control.
- **FR-039**: El orden de tabulación DEBE corresponder al orden visual de los elementos, y cada
  elemento enfocable DEBE mostrar un indicador de foco visible.
- **FR-040**: Todos los controles DEBEN poder activarse únicamente con el teclado.
- **FR-041**: Los mensajes de error y de estado DEBEN anunciarse a las ayudas técnicas en el
  momento en que aparecen.
- **FR-042**: El texto, los bordes de los campos y los textos de ayuda DEBEN cumplir las relaciones
  de contraste exigidas por WCAG 2.1 nivel AA.
- **FR-043**: Los controles interactivos —botones, enlaces de acción, casilla y control de
  visibilidad— DEBEN ofrecer un área de activación efectiva de **al menos 44 × 44 px**. Es el
  umbral de WCAG 2.1 criterio 2.5.5, que es nivel AAA: se adopta como mínimo de diseño propio,
  más estricto que el AA que exige FR-042, porque estas pantallas se usan a diario desde el
  celular del negocio.

### Requisitos de No Regresión

- **FR-044**: Esta spec NO DEBE modificar ni añadir ningún endpoint: el servidor queda exactamente
  como está, y todo el trabajo ocurre en las pantallas.
- **FR-045**: Los characterization tests de autenticación y recuperación existentes DEBEN seguir
  pasando sin modificarse, salvo que una decisión registrada en el registro de anomalías lo
  autorice.

### Key Entities

- **Contexto del acceso**: lo que el subdominio de origen determina sobre la pantalla —si es el
  acceso de un negocio, el de administración de la plataforma, o ninguno de los dos— y, cuando es
  de un negocio, el identificador que se muestra como etiqueta. Se resuelve por completo en el
  cliente, sin consultar al servidor. Gobierna FR-007 a FR-010.
- **Enlace de recuperación**: la autorización temporal para fijar una contraseña nueva de una
  cuenta concreta. Tiene un estado observable por la pantalla (vigente, vencido, ya usado,
  invalidado, inexistente) que decide qué se renderiza. Ya existe; esta spec solo consume su
  estado.
- **Política de contraseñas**: el conjunto de reglas que una contraseña nueva debe cumplir, que la
  pantalla de creación debe reflejar como lista verificable. Ya existe; esta spec la expone, no la
  redefine.
- **Bloqueo de reenvío**: el periodo durante el cual el usuario no puede volver a pedir un enlace
  desde la interfaz, con su instante de inicio y su duración restante.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un usuario que conoce sus credenciales completa el inicio de sesión en menos de 20
  segundos desde que la pantalla termina de cargar, en escritorio y en móvil.
- **SC-002**: Un usuario que olvidó su contraseña recorre el flujo completo —solicitar el enlace,
  abrirlo, crear la contraseña nueva y volver a entrar— sin necesitar ayuda de un administrador.
- **SC-003**: Ningún mensaje visible en las tres pantallas permite determinar si una cuenta existe,
  está desactivada o pertenece a otro negocio, verificado comparando las respuestas de una cuenta
  real y de una inexistente en los flujos de inicio de sesión y de solicitud de enlace.
- **SC-004**: Las tres pantallas se usan por completo con solo el teclado, de principio a fin de
  cada flujo, sin quedar atrapado en ningún control ni perder el rastro del foco.
- **SC-005**: Las tres pantallas no presentan incumplimientos de contraste ni de etiquetado de
  campos en una auditoría automática de accesibilidad de nivel WCAG 2.1 AA.
- **SC-006**: Las tres pantallas se muestran sin desplazamiento horizontal ni contenido cortado en
  todo el rango de 360 px a 1920 px de ancho.
- **SC-007**: Por debajo de 1024 px, el peso total descargado por cada pantalla no incluye la
  imagen de vista previa del panel de marca.
- **SC-008**: Los cuatro roles existentes inician sesión tras el rediseño y llegan a la misma
  pantalla inicial que antes, con los mismos permisos.
- **SC-009**: Un usuario que pulsa el botón de envío varias veces seguidas genera exactamente un
  intento de autenticación.
- **SC-010**: Un enlace de recuperación vencido, ya usado o invalidado por una solicitud posterior
  nunca permite fijar una contraseña nueva. El enlace abierto en otro subdominio **queda fuera de
  este criterio** por D13; su comportamiento real se documenta en A-111.
- **SC-011**: Un usuario que abre el subdominio de su negocio ve la pantalla completa, etiqueta
  incluida, sin esperar ninguna petición de red.
- **SC-012**: Ninguna petición emitida por las tres pantallas antes de autenticarse devuelve dato
  alguno del negocio, verificado revisando el tráfico de red de cada pantalla al cargar.
- **SC-013**: Un inicio de sesión con el control "Mantener sesión iniciada" marcado produce una
  sesión de la misma duración que uno sin marcar, y ninguna contraseña queda almacenada en el
  navegador en ninguno de los dos casos.

## Decisiones Tomadas

Las tres primeras las resolvió el negocio el 2026-10-05, tras plantearse las alternativas con su
impacto. El resto se resolvió durante la redacción con la información verificada en el código.
Todas quedan documentadas para que no se reabran durante la implementación.

- **D1 — El inicio de sesión sigue siendo solo por correo electrónico** *(decidido por el negocio,
  2026-10-05)*. El diseño muestra el campo como "Usuario o correo", pero el endpoint vigente acepta
  exclusivamente un correo y las cuentas no tienen un nombre de usuario alternativo. Se ajusta el
  diseño al sistema: la etiqueta dice "Correo electrónico" (FR-011a). Aceptar un nombre de usuario
  exigiría un identificador nuevo en las cuentas, su migración y un cambio del contrato de
  autenticación — es una feature propia, no parte de un rediseño. Consecuencia: el campo conserva
  la validación de formato de correo que ya existe, y el Escenario 17 del pedido se cumple con el
  autocompletado de correo en lugar de nombre de usuario.
- **D2 — No se expone ningún dato del negocio sin autenticación; la etiqueta usa el identificador
  del subdominio** *(decidido por el negocio, 2026-10-05)*. El diseño muestra el nombre comercial
  ("Granizados Del Sol"), pero obtenerlo antes de autenticar exigiría publicar un dato que hoy
  requiere sesión, y eso permitiría a cualquiera recorrer subdominios para levantar la lista de
  negocios de la plataforma y sus nombres. El negocio evaluó esa exposición y decidió **no
  asumirla**: la etiqueta muestra el identificador del subdominio, que el visitante ya conoce
  porque lo tecleó para llegar (FR-007, FR-007a). Consecuencias aceptadas: (1) la insignia dirá
  `granizadosdelsol` y no "Granizados Del Sol", que es una pérdida de fidelidad visual frente al
  mockup; (2) esta spec vuelve a ser **exclusivamente de frontend**, sin cambios en `pos-backend`;
  (3) el Escenario 3 del pedido queda parcialmente fuera de alcance (ver D12). A cambio, la
  superficie pública del sistema no crece y la pantalla no depende de ninguna petición para
  mostrarse completa.

- **D3 — El control "Mantener sesión iniciada" se maqueta sin efecto** *(decidido por el negocio,
  2026-10-05)*. El control aparece en la interfaz tal como lo muestra el diseño, pero no altera la
  duración de la sesión, porque la capacidad de sesión extendida no existe y se especificará en
  una spec posterior. Se planteó la objeción de que un control de seguridad visible y sin efecto
  puede hacer creer al usuario que su sesión se comporta de un modo en que no se comporta; el
  negocio decidió incluirlo de todas formas para no volver a tocar la pantalla cuando llegue esa
  spec. FR-019a a FR-019e acotan la decisión: el control existe, es accesible, y está obligado a
  no hacer nada — ni enviar un parámetro que nadie interpreta, ni guardar contraseñas, ni prometer
  en su texto algo falso. Cuando se implemente la sesión extendida, esta spec es el punto de
  partida al que esa spec deberá volver.
- **D3a — El control se llama "Mantener sesión iniciada", no "Recordar contraseña"**: el diseño lo
  etiqueta "Recordar contraseña"; el pedido lo llama "Mantener sesión iniciada". Se adopta el texto
  del pedido, por dos razones: "Recordar contraseña" afirma que el sistema guarda la contraseña, lo
  cual es falso, y el propio pedido prohíbe explícitamente almacenar contraseñas (Escenario 9,
  recogido en FR-019d). Mantener el texto del diseño sería describir al usuario un comportamiento
  que la misma spec prohíbe.

- **D4 — La política de contraseñas vigente prevalece sobre la del mockup**: el diseño lista como
  requisitos "mínimo 8 caracteres", "una letra mayúscula" y "un número", y no menciona ningún
  máximo. La política vigente (spec 031, FR-019) exige entre 8 y 12 caracteres y **no** exige
  mayúsculas ni números. Como el pedido indica explícitamente validar "según la política actual",
  prevalece la política vigente y la lista de requisitos de la pantalla se ajusta a ella,
  incluyendo el máximo de 12 caracteres, que el mockup omite y que sin mostrarse produciría un
  rechazo inexplicable. Endurecer la política sería un cambio de comportamiento que requiere su
  propia decisión de negocio y está fuera del alcance de un rediseño.
- **D5 — El límite de solicitudes es el vigente, no el del pedido**: el pedido describe un
  rate-limit "por hora"; el implementado es de 3 solicitudes por ventana de 900 segundos, por
  negocio y cuenta. Se conserva el vigente, porque cambiarlo es una decisión de seguridad
  independiente del rediseño. El mensaje de la interfaz se redacta sin citar una ventana de tiempo
  concreta para que siga siendo correcto si la configuración cambia.
- **D6 — El bloqueo de 60 segundos es solo de interfaz**: el bloqueo de reenvío pedido no sustituye
  ni duplica el límite del servidor. Es una ayuda para que el usuario no gaste sus intentos
  disponibles con pulsaciones repetidas, y por eso FR-024 lo declara explícitamente subordinado al
  límite del servidor.
- **D7 — El texto del subdominio no reconocido se alinea al pedido**: la pantalla vigente (spec
  091) muestra "Esta dirección no corresponde a ningún acceso"; esta spec adopta "No encontramos
  este negocio" con enlace al sitio principal, por ser el texto solicitado. Es un cambio de
  redacción visible, no de comportamiento: se conserva intacta la regla de spec 091 de no
  renderizar formulario ni llamar al API.
- **D8 — La etiqueta del super administrador se alinea al pedido**: la pantalla vigente muestra
  "Acceso Super Admin"; esta spec adopta "Administración de la plataforma". Igual que D7, es
  redacción, no comportamiento.
- **D9 — Se rediseñan tres pantallas, no dos**: el pedido nombra dos archivos de diseño, pero
  `Login.dc.html` contiene tres estados (inicio de sesión, solicitud de enlace y confirmación de
  envío) que en el sistema real son dos pantallas distintas con rutas propias. El alcance son las
  tres pantallas de autenticación existentes más el estado de confirmación de envío.
- **D10 — El cambio de contraseña desde el perfil queda fuera de alcance**: existe una cuarta
  pantalla de contraseña (cambio voluntario desde el perfil, ya autenticado) que no aparece en los
  diseños entregados ni en el pedido. No se toca, para no mezclar en un mismo incremento el
  rediseño pedido con uno no solicitado (Principio V).
- **D11 — Las plantillas de correo entregadas quedan fuera de alcance**: el directorio de diseño
  incluye además plantillas de correo ("Restablecer contraseña", "Contraseña cambiada",
  "Invitación usuario") que el pedido no menciona. Son un entregable distinto, con su propia
  verificación en clientes de correo, y no forman parte de esta spec.
- **D12 — El Escenario 3 del pedido solo se cumple para hosts no reconocidos, no para subdominios
  no registrados**: se verificó que el mecanismo de spec 091 clasifica como tenant válido
  **cualquier** subdominio que no sea el dominio raíz, el de administración ni uno reservado. Por
  tanto un subdominio inventado con forma válida muestra el formulario con normalidad, y el usuario
  solo descubre que ese negocio no existe cuando su inicio de sesión falla con "Credenciales
  inválidas". Distinguir ese caso exigiría preguntarle al servidor si el negocio existe —
  exactamente la consulta que D2 decidió no abrir. **Es una limitación conocida y aceptada**,
  recogida en FR-009a. Nota de seguridad: esta limitación es también la razón por la que el sistema
  no se convierte en un verificador de existencia de negocios, que es justo lo que D2 quiso evitar;
  las dos caras son la misma decisión. Si el negocio quisiera después cumplir ese escenario, tendría
  que reabrir D2 y aceptar su exposición.
- **D13 — FR-037 queda fuera de alcance; el enlace no se ata al subdominio** *(decidido por
  Leonardo Gómez, 2026-10-05)*. FR-037 pedía invalidar el enlace de recuperación abierto en el
  subdominio de otro negocio. Se verificó que el enlace se resuelve solo por el hash de su token,
  sin mirar el host, de modo que hoy funciona desde cualquier subdominio. Cerrarlo exige modificar
  dos endpoints de autenticación, que FR-044 prohíbe en esta misma spec: **los dos requisitos eran
  incompatibles y la decisión resuelve el conflicto a favor de FR-044**, por las mismas razones que
  sostuvieron D2. Se ponderó el riesgo: el enlace solo cambia la contraseña de la cuenta para la
  que se emitió, así que lo que falla es la hermeticidad del aislamiento por subdominio, no la
  seguridad de la cuenta; y quien tiene el enlace ya tiene acceso al correo de esa cuenta.
  Consecuencias aceptadas: (1) FR-037 se reformula como limitación documentada y no como requisito
  entregable; (2) SC-010 pierde su cláusula de subdominio; (3) FR-036 conserva el "únicamente"
  solo para la solicitud, no para la ejecución. El comportamiento observado queda asentado en
  A-111, y cerrarlo exigiría una spec propia de `pos-backend`, que esta decisión **no** abre.

## Assumptions

- **Fuente de verdad del diseño**: los archivos `Login.dc.html` y `Nueva contrasena.dc.html` del
  directorio de diseño se toman como referencia de intención visual —jerarquía, textos, estados,
  orden de los elementos—, no como código a trasladar: están escritos sobre un sistema de
  componentes y un motor de plantillas ajenos al frontend real, que es Angular con utilidades de
  CSS. La equivalencia se evalúa sobre el resultado percibido, no sobre el marcado.
- **Tema visual**: el diseño se entrega en tema claro y esta spec asume únicamente tema claro para
  las tres pantallas, como el sistema hoy.
- **Idioma**: las tres pantallas se entregan únicamente en español, como el resto del sistema.
- **Infraestructura de correo**: el envío de los correos de recuperación ya funciona y no se
  modifica; esta spec consume ese flujo.
- **Resolución del subdominio**: el mecanismo vigente (spec 091) distingue correctamente los tres
  tipos de host sin consultar al API, y se reutiliza tal cual.
- **Comportamiento protegido**: ningún requisito de esta spec cambia comportamiento cubierto por
  characterization tests —D1 conserva el contrato de login, D2 no añade ninguna consulta, y D3 no
  altera la emisión de sesiones—; si la implementación descubre que sí, se detiene y se registra la
  decisión antes de continuar (Principio II).
- **Alcance por repositorio**: la totalidad del trabajo es de `pos-heladeria`. `pos-backend` no se
  toca.
- **Legibilidad del identificador del subdominio**: se asume que el identificador que el negocio
  usa en su dirección es suficientemente reconocible para sus propios empleados, que son quienes
  teclean esa dirección a diario.

## Dependencias

- **Spec 001 (auth y personal)**: define el inicio de sesión, el aislamiento por tenant
  (`RN-AUTH-05`) y el rechazo de cuentas desactivadas (`RN-AUTH-04`). Esta spec no los altera.
- **Spec 031 (recuperación y cambio de contraseña)**: define el flujo completo de recuperación, la
  política de contraseñas de 8 a 12 caracteres (FR-019), el enlace de un solo uso de 30 minutos, el
  cierre de sesiones al cambiar la contraseña (FR-017), y el límite de solicitudes. Esta spec
  rediseña su superficie sin cambiar su comportamiento.
- **Spec 091 (admin aislado)**: define la resolución del host en los tres tipos de acceso y la
  regla de no renderizar formulario ni llamar al API en un host no reconocido (FR-005/FR-006).
  Esta spec cambia los textos de esa pantalla (D7, D8), conserva su comportamiento, y añade sobre
  ella la limitación conocida sobre subdominios con forma válida no registrados (D12, FR-009a).
- **Spec posterior de sesión extendida (aún no creada)**: deberá dar comportamiento al control que
  esta spec deja deliberadamente inerte (D3, FR-019a a FR-019e), y es el punto en el que habrá que
  decidir la duración de la sesión extendida y su riesgo en un dispositivo compartido de mostrador.
- **Sitio principal de SkeiloPOS**: el enlace del mensaje de host no reconocido y el de la Política
  de privacidad del pie apuntan al sitio público, que vive en el repositorio `skeilo-pos-landing`.
  Se verificó que ambas páginas ya existen allí (`/privacidad` y la portada), así que esta spec solo
  las enlaza; no hay que crearlas.
