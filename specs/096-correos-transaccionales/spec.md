# Feature Specification: Correos transaccionales de acceso con la marca de SkeiloPOS

**Feature Branch**: `feat/096-transactional-email-templates`

**Created**: 2026-10-06

**Status**: Draft

**Input**: User description: implementar los tres diseños aprobados de la carpeta `SkeiloPOS App diseñada` —`Invitacion usuario.dc.html`, `Restablecer contraseña.dc.html` y `Contraseña cambiada.dc.html`— como plantillas reales de correo (HTML y texto plano) con datos dinámicos, fieles al diseño en lo visual, reusando los disparadores que ya existen.

Usuarios:

- **Usuario invitado de un tenant**: persona a la que un administrador le da acceso al sistema de su negocio y que recibe sus datos de ingreso por correo.
- **Administrador de Tenant**: dueño o gestor de la heladería que invita y reenvía invitaciones a su personal.
- **Super Admin**: cuenta de plataforma, sin negocio asignado, que administra el sistema desde `admin.skeilopos.com`.

## Contexto y Encuadre

Esta spec es **un rediseño de superficie sobre un flujo que ya funciona**. Los cuatro correos del
sistema ya se envían hoy, con disparadores probados por specs anteriores (031, 037, 091), pero su
contenido es HTML plano sin marca: una tabla con borde, un `<h2>` y un párrafo rojo. Lo que falta no
es el envío, es la **presentación**.

Antes de redactar los requisitos se verificó el estado real del código:

| Capacidad | Estado actual verificado | Qué cambia en esta spec |
|---|---|---|
| Correo de invitación | `invitation_email_body()` en `app/core/mail.py`, disparado síncronamente desde `POST /invitations` y `POST /invitations/{id}/resend` | Solo la plantilla, el asunto y el texto plano |
| Correo de alta de negocio | `welcome_email_body()`, disparado por Celery desde el alta de negocios del Super Admin, con el mismo contenido pero otra maqueta | Pasa a reusar la plantilla de invitación (D9) |
| Correo de restablecimiento | `password_reset_email_body()`, disparado por Celery desde `POST /auth/forgot-password`; enlace de un solo uso de **30 minutos** | Solo la plantilla, el asunto y el texto plano |
| Correo de contraseña cambiada | `password_changed_email_body()`, disparado por Celery tras `POST /auth/reset-password` y `POST /auth/change-password` | Plantilla, asunto, hora de Colombia (D4), fila de negocio (D5) y variante de Super Admin (D6) |
| Servicio de envío | `POST {EMAIL_API_URL}/api/email/send` con `{from, to, subject, htmlBody}`; microservicio externo que **no vive en ninguno de los cuatro repositorios** | No cambia; se le añade el cuerpo en texto plano (D7) |
| Remitente | `MAIL_FROM_NAME` = "Mi app", `MAIL_FROM` = dominio de pruebas del proveedor | Solo el nombre visible pasa a "SkeiloPOS" (D8) |
| Escape de contenido dinámico | `invitation_email_body()` escapa **únicamente** el nombre de la persona; el nombre del negocio, el correo, la contraseña y la URL se interpolan sin escapar | Se escapan todos los valores dinámicos (FR-040) |
| Vencimiento de la contraseña temporal | **No existe**: `UserInvitation` guarda `sent_at` pero el login no valida antigüedad alguna | No cambia; por eso el correo no promete un vencimiento (D10) |
| Restablecimiento de Super Admin | **No existe**: `POST /auth/forgot-password` resuelve el negocio por el host y filtra las cuentas por `tenant_id` | No cambia; queda fuera de alcance |
| Saludo sin nombre | Resuelto por la spec 091: dice "Hola:" y nunca el correo | Se conserva la regla; cambia la redacción al integrarse en el párrafo (D11) |

Conforme al Principio II de la constitución, cada requisito de esta spec que altere un
comportamiento ya protegido queda marcado explícitamente y exige su registro en
`specs/000-reconocimiento/registro-de-anomalias.md` **antes** de implementarse. La lista completa
está en la sección *Decisiones que exigen registro*.

## Clarifications

### Session 2026-10-06

- Q: ¿La spec cubre también los comportamientos nuevos que pide el pedido (vencimiento de 72 horas, estado "Invitación no enviada" con reintentos, restablecimiento de Super Admin, suprimir el aviso en el primer cambio obligatorio)? → A: **No**. El alcance se limita a las plantillas; esos cuatro comportamientos quedan documentados en *Fuera de Alcance* (D1).
- Q: ¿Se cambia el servicio de envío o se migra a la API del proveedor? → A: **Se conserva el microservicio actual** y los mensajes se adaptan a la forma en que él los recibe (D2).
- Q: Cuando el diseño aprobado contradice al pedido, ¿qué manda? → A: **El diseño manda en lo visual** (estructura, color, espaciado, tipografía) y **el pedido manda en el contenido** (D3).
- Q: El diseño muestra "skeilorest", que es el identificador del subdominio. ¿Es dato de muestra o valor literal? → A: **Dato de muestra**: la variable se resuelve con el nombre comercial del negocio, como ya hace el código.
- Q: El diseño muestra "02/10/2026 · 21:06 UTC". ¿Qué hora se muestra? → A: **Hora de Colombia**, con el formato "02/10/2026 · 04:06 p. m. (hora de Colombia)" (D4).
- Q: El servicio de envío solo tiene documentado el cuerpo HTML. ¿Qué se hace con la versión en texto plano? → A: **Se genera y se envía igual**, y se verifica con un envío real; si el servicio la ignora, el HTML sale intacto (D7).
- Q: El logo del diseño apunta a una ruta local. ¿Dónde se hospeda? → A: **En el almacenamiento de objetos del producto**, servido bajo el dominio de recursos que ya existe (D12).
- Q: El pie del diseño muestra una dirección de contacto distinta de la que nombra el pedido, y el dominio del remitente no está verificado. ¿Qué se usa? → A: **Se conserva el remitente actual** y el pie del diseño; solo el nombre visible del remitente pasa a "SkeiloPOS" (D8).
- Q: El diseño de "Contraseña cambiada" no tiene fila de negocio, pero el pedido la exige. ¿Se añade? → A: **Sí**, con la misma tipografía y espaciado que la fila de cuenta (D5).
- Q: El pedido exige un aviso distinto para el Super Admin, y no hay diseño para esa variante. ¿Se implementa? → A: **Sí**, misma tarjeta y colores, solo cambia la frase y se omite la fila de negocio (D6).
- Q: ¿Qué se hace con el cuarto correo, el del alta de un negocio nuevo, que no tiene diseño propio? → A: **Reusa la plantilla de invitación**, porque lleva exactamente el mismo contenido (D9).
- Q: ¿Se adoptan los asuntos que nombra el pedido? → A: **Sí**, los tres literales, aunque eso cambie el asunto que hoy reciben los invitados (D13).
- Q: ¿En qué clientes de correo se verifica realmente la fidelidad visual, y qué se hace con los que no se puedan abrir aquí? → A: **Verificación real en Gmail web y Gmail Android**; Outlook web, Outlook de escritorio y Apple Mail quedan como **verificación diferida** declarada, cubiertos por conformidad de construcción conforme a FR-005 (D14).
- Q: ¿Dónde se publica el archivo del logo y a qué URL apuntan los correos en cada entorno? → A: **Clave fija en el bucket de producción**, `brand/logo-horizontal-claro-1200.png` servida por `assets.skeilopos.com`, subida una sola vez a mano antes de implementar; **todos** los entornos apuntan a esa misma URL (D12).
- Q: ¿Se corrige en esta spec que desarrollo envíe por el servicio de producción (A-120)? → A: **No se corrige el entorno**; se añade una salvaguarda de destinatarios y marcado de datos de prueba (FR-061), y A-120 queda como hallazgo abierto para una spec de entorno (D15).
- Q: Cuando FR-041 impida generar el correo por un valor obligatorio faltante, ¿qué pasa con la invitación? → A: **La invitación falla y no se crea**, igual que cuando el servicio de correo no responde; el cambio de comportamiento exige una entrada nueva en el registro (A-121, D16).
- Q: ¿A qué dirección debe escribir un Super Admin cuando recibe el aviso de contraseña cambiada y no fue él? → A: **`skeilo.tech@gmail.com`**, la misma dirección que el pie de los tres diseños aprobados (FR-013, FR-038).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Entrar al sistema con los datos que llegan por correo (Priority: P1)

Como persona recién invitada a un negocio, abro el correo de invitación, reconozco de inmediato que
viene de SkeiloPOS y del negocio que me invitó, y encuentro sin buscar mi dirección de ingreso, mi
usuario y mi contraseña temporal.

**Why this priority**: es el primer contacto de un empleado con el producto y hoy llega como un
correo sin marca que parece spam. Si no se entiende o no se confía en él, la persona no entra y el
administrador tiene que explicárselo a mano.

**Independent Test**: invitar a una persona desde la página de usuarios, abrir el correo recibido y
comprobar que muestra la marca, el nombre comercial del negocio, el saludo con el nombre, la URL de
ingreso, el usuario, la contraseña temporal y el aviso de cambio obligatorio; después entrar con
esos datos.

**Acceptance Scenarios**:

1. **Given** un administrador invita a "María Pérez" con el correo "maria@correo.com" en el negocio
   "Granizados Del Sol", **When** se crea la invitación, **Then** María recibe un correo con el
   asunto "Te invitaron a unirte a Granizados Del Sol en SkeiloPOS", con el logo del producto, la
   etiqueta "INVITACIÓN · GRANIZADOS DEL SOL", el título "Te invitaron a unirte a Granizados Del
   Sol.", el saludo con su nombre, la URL de ingreso de su negocio, su usuario y su contraseña
   temporal destacada. *(Escenario 1 del pedido, sin la mención de vencimiento — D10)*
2. **Given** la invitación no capturó nombre, **When** la persona recibe el correo, **Then** el
   párrafo abre con "Hola." y sigue con el resto de la frase, sin "null", sin "None", sin dos
   espacios seguidos y sin mostrar su correo como si fuera su nombre. *(Escenario 2)*
3. **Given** el negocio tiene identificador de subdominio "skeilorest" y nombre comercial
   "Skeilorest Granizados", **When** se genera el correo, **Then** la etiqueta, el título, el
   párrafo y el pie usan el nombre comercial, no el identificador. *(Escenario 3)*
4. **Given** recibo la invitación, **When** miro la URL de ingreso, **Then** el texto visible y el
   destino del enlace coinciden carácter por carácter, el destino es el subdominio de mi propio
   negocio y en producción usa HTTPS. *(Escenario 4)*
5. **Given** recibo la invitación, **When** pulso "Iniciar sesión", **Then** llego al ingreso de mi
   negocio y nunca al de otro ni al de la plataforma. *(Escenario 4)*
6. **Given** un administrador reenvía mi invitación, **When** llega el correo nuevo, **Then** tiene
   la misma presentación y asunto que el original y trae la contraseña temporal nueva.
   *(Escenario 7, parte de correo)*
7. **Given** el correo de invitación en cualquiera de sus dos orígenes, **When** se inspecciona el
   asunto y el texto de vista previa, **Then** ninguno de los dos contiene la contraseña temporal.

---

### User Story 2 - Recuperar el acceso cuando olvidé la contraseña (Priority: P1)

Como usuario que olvidó su contraseña, recibo un correo con la marca del producto, entiendo en un
vistazo qué tengo que hacer, cuánto tiempo tengo y qué pasa si no fui yo quien lo pidió.

**Why this priority**: es el correo que desbloquea a alguien que está afuera del sistema. Un correo
que no se entiende o del que se desconfía se traduce en una llamada al administrador.

**Independent Test**: pedir un enlace desde la pantalla de recuperación, abrir el correo recibido y
comprobar la marca, el botón, la vigencia, el aviso de un solo uso y el enlace en texto visible;
después usar el enlace y fijar una contraseña nueva.

**Acceptance Scenarios**:

1. **Given** solicito restablecer la contraseña de una cuenta existente, **When** llega el correo,
   **Then** tiene el asunto "Restablece tu contraseña de SkeiloPOS", la etiqueta "SEGURIDAD DE LA
   CUENTA", el botón "Restablecer contraseña", el aviso "Válido por 30 minutos. El enlace solo
   puede usarse una vez." y la frase de que si no lo pedí mi contraseña sigue funcionando.
   *(Escenario 8)*
2. **Given** mi cliente de correo no muestra el botón, **When** leo el correo, **Then** encuentro el
   enlace completo en texto visible y puedo copiarlo. *(Escenario 8)*
3. **Given** solicito restablecer la contraseña de una cuenta que no existe, **When** el sistema
   procesa la solicitud, **Then** no se envía ningún correo y la pantalla muestra exactamente el
   mismo mensaje que para una cuenta existente. *(Escenario 9, ya implementado: se verifica que no
   se rompió)*
4. **Given** el correo de restablecimiento, **When** se inspecciona su contenido, **Then** no
   menciona ningún negocio distinto del mío ni enlaza a ningún otro subdominio.

---

### User Story 3 - Enterarme de que mi contraseña cambió (Priority: P2)

Como titular de una cuenta, cuando mi contraseña cambia recibo un aviso que me dice qué cuenta, de
qué negocio, cuándo —en la hora que yo uso— y qué hacer si no fui yo.

**Why this priority**: es el único correo de detección: si alguien más cambia mi contraseña, este
aviso es la señal. Pero depende de los otros dos flujos, así que se entrega después.

**Independent Test**: cambiar la contraseña desde la aplicación y desde el enlace de
restablecimiento, y comprobar en cada caso el contenido del correo recibido.

**Acceptance Scenarios**:

1. **Given** restablecí mi contraseña a las 16:06 hora de Colombia del 2 de octubre de 2026,
   **When** termina el cambio, **Then** recibo un correo con el asunto "Tu contraseña de SkeiloPOS
   fue cambiada", la etiqueta "CONTRASEÑA ACTUALIZADA", mi cuenta, mi negocio y
   "02/10/2026 · 04:06 p. m. (hora de Colombia)". *(Escenario 11)*
2. **Given** recibo ese correo como usuario de un tenant, **When** leo el aviso destacado, **Then**
   me dice que contacte de inmediato a un administrador de mi negocio, y el botón "Iniciar sesión"
   lleva al ingreso de mi negocio. *(Escenarios 11 y 12)*
3. **Given** recibo ese correo como Super Admin, **When** leo el correo, **Then** el aviso me dice
   que escriba a `skeilo.tech@gmail.com`, no aparece ninguna fila de negocio, el pie no menciona
   ningún negocio y el botón lleva al ingreso de la plataforma. *(Escenarios 10 y 12)*
4. **Given** cambié mi contraseña, **When** reviso el correo, **Then** no aparece en ninguna parte
   la contraseña nueva ni la anterior.

---

### User Story 4 - Leer los correos en mi cliente y en mi teléfono (Priority: P2)

Como destinatario cualquiera, abro estos correos en el cliente que uso —web o teléfono— y los veo
completos, legibles y con la marca, sin tener que desplazarme de lado.

**Why this priority**: un correo transaccional que se rompe en Outlook o se sale de la pantalla en
el teléfono no cumple su función aunque el contenido sea correcto. La mayoría de los empleados de
mostrador lo abrirá en el teléfono.

**Independent Test**: enviarse los tres correos y abrirlos en Gmail web y Gmail Android, incluyendo
una ventana de 360 px de ancho. Outlook y Apple Mail son verificación diferida (FR-052, D14).

**Acceptance Scenarios**:

1. **Given** abro cualquiera de los tres correos en Gmail web o Gmail Android, **When** comparo con
   el diseño aprobado, **Then** el logo, el botón, las tarjetas, los colores y la jerarquía se ven
   como en el diseño. *(Escenario 16, vía de verificación real de FR-052)*
2. **Given** abro el correo en una ventana de 360 px de ancho, **When** lo recorro, **Then** todo el
   contenido cabe sin desplazamiento horizontal y ningún texto queda cortado. *(Escenario 16)*
3. **Given** mi cliente solo muestra texto plano, **When** abro el correo, **Then** recibo el mismo
   contenido útil, con los enlaces escritos completos y legibles. *(Escenario 17)*
4. **Given** mi cliente bloquea las imágenes, **When** abro el correo, **Then** el texto alternativo
   del logo identifica al producto y el correo sigue siendo utilizable.

---

### User Story 5 - El alta de un negocio nuevo recibe el mismo correo (Priority: P3)

Como dueño de un negocio recién creado por el Super Admin, recibo mis datos de acceso con la misma
presentación con que los recibe cualquier otro usuario invitado.

**Why this priority**: es el correo de menor volumen —solo ocurre al dar de alta un negocio— pero es
el primero que ve un cliente que acaba de pagar, y hoy es el único que seguiría llegando sin marca.

**Independent Test**: crear un negocio con su dueño desde el panel de plataforma y comprobar que el
correo recibido es idéntico en presentación al de una invitación normal.

**Acceptance Scenarios**:

1. **Given** el Super Admin crea el negocio "Granizados Del Sol" con su cuenta de dueño, **When**
   llega el correo, **Then** tiene la misma presentación, el mismo asunto y los mismos campos que
   el correo de invitación de un usuario de tenant.
2. **Given** ese correo, **When** se inspecciona el aviso destacado, **Then** dice lo mismo que el
   de invitación sobre fijar la propia contraseña al primer ingreso.

---

### Edge Cases

- **Nombre comercial largo**: un negocio llamado "Heladería y Fuente de Soda Los Tres Hermanos de
  la Esquina" desborda la etiqueta superior, que va en mayúsculas y con separación de letras. Se
  acota en FR-012.
- **Nombre comercial con HTML**: un negocio llamado `<b>x</b>` o `Ñandú & Cía` tiene que leerse tal
  cual, sin interpretarse y sin mostrar entidades crudas al usuario. FR-040.
- **Nombre de persona con apóstrofo**: "O'Brien" ya se escapa hoy y debe seguir viéndose como
  "O'Brien" y no como `O&#x27;Brien`. FR-040.
- **Invitación sin nombre**: el párrafo no puede quedar con "Hola, ." ni con doble espacio. FR-015.
- **Falta una variable obligatoria**: si el negocio, el correo, la URL o la contraseña llegan vacíos
  o nulos, el correo no sale y, en el caso de la invitación, la invitación tampoco queda creada.
  FR-041, A-121.
- **Cuenta sin negocio en el aviso de cambio**: un Super Admin no tiene negocio; el correo no puede
  mostrar una fila vacía ni la palabra "None". FR-033.
- **Cliente que bloquea imágenes**: el logo es una imagen remota; el correo tiene que seguir
  entendiéndose sin ella. FR-007.
- **Cliente que ignora el texto de vista previa**: el texto oculto no puede aparecer como primera
  línea visible del cuerpo. FR-009.
- **Entorno de desarrollo**: las URL locales no usan HTTPS; la exigencia de HTTPS aplica a
  producción. FR-019.

## Requirements *(mandatory)*

### Requisitos comunes de las tres plantillas

- **FR-001**: Las tres plantillas MUST reproducir la estructura del diseño aprobado: fondo de
  página, logo arriba a la izquierda, tarjeta blanca con esquinas redondeadas y barra superior de
  acento, etiqueta en forma de píldora, título, párrafo de entrada, bloques de contenido propios de
  cada correo, y pie centrado fuera de la tarjeta.
- **FR-002**: Las tres plantillas MUST usar los valores visuales del diseño, verificables uno a uno:

  | Elemento | Valor exigido |
  |---|---|
  | Fondo de página | `#EEF1F6` |
  | Ancho máximo del contenido | 600 px, centrado, con 40 px arriba y abajo y 16 px a los lados |
  | Tarjeta | fondo `#FFFFFF`, borde 1 px `#E2E8F0`, radio 16 px |
  | Barra de acento superior | 4 px, `#7C3AED` |
  | Etiqueta (píldora) | fondo `#EDE9FE`, texto `#5B21B6`, radio 999 px, 12 px, negrita, mayúsculas, separación de letras 0.08em |
  | Título | 28/34 px, negrita, `#090D16`, separación de letras −0.02em |
  | Párrafo | 16/24 px, `#475569` |
  | Tarjeta de datos | fondo `#F8FAFC`, borde 1 px `#E2E8F0`, radio 12 px |
  | Etiqueta de dato | 11/16 px, negrita, `#64748B`, mayúsculas, separación 0.08em |
  | Valor de dato | 15/22 px, `#090D16` |
  | Botón | fondo `#7C3AED`, radio 8 px, texto blanco 16/20 px negrita, 14 px por 28 px de relleno |
  | Aviso de atención | fondo `#FFF1F2`, borde `#FECDD3`, texto `#9F1239`, radio 12 px |
  | Aviso informativo | fondo `#F8FAFC`, borde `#E2E8F0`, texto `#475569`, radio 12 px |
  | Enlaces | `#6D28D9` |
  | Pie | 13/20 px, `#64748B`, centrado |

- **FR-003**: Las tres plantillas MUST declarar las familias tipográficas del diseño con su cadena
  de reserva: títulos con Sora y el resto con Figtree, ambas seguidas de Arial y Helvetica.
- **FR-004**: El sistema MUST asumir que esas dos tipografías no se cargan en la mayoría de
  clientes de correo y MUST garantizar que la jerarquía —tamaño, peso, color, espaciado— se
  sostiene con la tipografía de reserva.
- **FR-005**: Las tres plantillas MUST construirse con una técnica de maquetación que los clientes
  de correo rendericen de forma equivalente, sin depender de capacidades que Outlook de escritorio
  no soporta para la estructura.
- **FR-006**: Las tres plantillas MUST mostrar el logo horizontal del producto sobre fondo claro, a
  150 px de ancho, referenciado por la URL absoluta y pública
  `https://assets.skeilopos.com/brand/logo-horizontal-claro-1200.png`. Esa URL MUST ser la misma en
  todos los entornos, de modo que un correo de desarrollo muestre el mismo logo que uno de
  producción. *(D12)*
- **FR-007**: El logo MUST llevar texto alternativo "SkeiloPOS", de modo que un cliente que bloquee
  imágenes siga identificando el origen del correo.
- **FR-008**: Las tres plantillas MUST llevar un texto de vista previa oculto, propio de cada
  correo, con el contenido que el diseño define para cada uno. Donde ese texto nombre un valor que
  el sistema calcula —la vigencia del enlace, el nombre comercial del negocio, la fecha del
  cambio— MUST tomarlo de la misma fuente que el cuerpo, nunca de un literal copiado del diseño: en
  particular, los minutos de vigencia salen de la configuración vigente (FR-030) y el negocio del
  nombre comercial (FR-014).
- **FR-009**: El texto de vista previa MUST permanecer invisible en el cuerpo del correo en los
  clientes que no lo interpreten como tal.
- **FR-010**: Los tres asuntos MUST ser exactamente: "Te invitaron a unirte a {negocio} en
  SkeiloPOS", "Restablece tu contraseña de SkeiloPOS" y "Tu contraseña de SkeiloPOS fue cambiada".
  *(Cambia el asunto actual de los tres correos — exige registro, A-113)*
- **FR-011**: El nombre visible del remitente MUST ser "SkeiloPOS". *(Cambia el valor actual —
  exige registro, A-114)*
- **FR-012**: Cuando el nombre comercial del negocio exceda el ancho disponible de la etiqueta
  superior, esta MUST seguir legible en una sola línea o romper en dos sin desbordar la tarjeta, y
  MUST conservar el nombre completo sin truncarlo con puntos suspensivos.
- **FR-013**: El pie de las tres plantillas MUST ser el del diseño, con la dirección de contacto que
  el diseño muestra —`skeilo.tech@gmail.com`— y, solo en el correo de invitación, la mención del
  negocio en cuyo nombre se envía.

### Requisitos del correo de invitación

- **FR-014**: El correo MUST mostrar la etiqueta "INVITACIÓN · {NEGOCIO}" en mayúsculas y el título
  "Te invitaron a unirte a {negocio}.", resolviendo `{negocio}` con el **nombre comercial** del
  negocio y nunca con el identificador del subdominio.
- **FR-015**: El párrafo de entrada MUST abrir con "Hola, {nombre}." cuando la invitación tiene
  nombre y con "Hola." cuando no lo tiene, sin dejar coma suelta, doble espacio, "null", "None" ni
  el correo en lugar del nombre.
- **FR-016**: El correo MUST mostrar una tarjeta de datos con tres filas, en este orden y con estas
  etiquetas: "URL DE INICIO DE SESIÓN", "USUARIO" y "CONTRASEÑA TEMPORAL".
- **FR-017**: La contraseña temporal MUST presentarse en su caja propia, con borde discontinuo de
  acento, tipografía monoespaciada de 18/24 px y separación de letras de 0.06em, tal como el diseño.
- **FR-018**: La URL de ingreso MUST mostrarse como enlace cuyo texto visible coincide exactamente
  con su destino.
- **FR-019**: En producción, la URL de ingreso y el destino del botón MUST usar HTTPS y apuntar al
  subdominio del negocio del destinatario. En desarrollo conservan el esquema y el puerto locales.
- **FR-020**: El correo MUST incluir el botón "Iniciar sesión" apuntando al mismo destino que la URL
  de la tarjeta.
- **FR-021**: El correo MUST cerrar con el aviso de atención del diseño: en negrita "Antes de
  continuar." y después la frase de que al iniciar sesión por primera vez deberá fijar su propia
  contraseña.
- **FR-022**: El correo MUST NOT afirmar ningún plazo de vencimiento de la contraseña temporal
  mientras el sistema no lo aplique. *(D10)*
- **FR-023**: La contraseña temporal MUST NOT aparecer en el asunto ni en el texto de vista previa.
- **FR-024**: La contraseña temporal MUST NOT escribirse en los registros del sistema al generar ni
  al enviar el correo.
- **FR-025**: El correo del reenvío MUST ser idéntico en presentación y asunto al de la invitación
  original, con la contraseña temporal nueva.
- **FR-026**: El correo del alta de un negocio nuevo MUST usar esta misma plantilla, con los mismos
  campos y el mismo asunto. *(Retira la plantilla propia de ese correo — exige registro, A-115)*

### Requisitos del correo de restablecimiento

- **FR-027**: El correo MUST mostrar la etiqueta "SEGURIDAD DE LA CUENTA", el título "Restablece tu
  contraseña." y el párrafo de entrada del diseño.
- **FR-028**: El correo MUST incluir el botón "Restablecer contraseña" apuntando al enlace de un
  solo uso de la solicitud.
- **FR-029**: El correo MUST mostrar el aviso informativo del diseño con la vigencia real del
  enlace y la advertencia de un solo uso: "Válido por 30 minutos. El enlace solo puede usarse una
  vez."
- **FR-030**: La vigencia que el correo anuncia MUST provenir de la configuración vigente del
  sistema, de modo que no pueda quedar desalineada si ese plazo cambia.
- **FR-031**: El correo MUST incluir, además del botón, el enlace completo en texto visible y
  seleccionable, para quien no pueda usar el botón. *(Añade un elemento que el diseño no tiene —
  exige registro, A-116)*
- **FR-032**: El correo MUST cerrar con la frase del diseño sobre que, si no solicitó el cambio,
  puede ignorarlo porque su contraseña actual sigue funcionando.

### Requisitos del correo de contraseña cambiada

- **FR-033**: El correo MUST mostrar la etiqueta "CONTRASEÑA ACTUALIZADA", el título "Tu contraseña
  fue cambiada." y el párrafo de entrada del diseño.
- **FR-034**: Para un usuario de tenant, la tarjeta de datos MUST tener tres filas, en este orden:
  "CUENTA", "NEGOCIO" y "FECHA Y HORA". La fila de negocio usa el nombre comercial y la misma
  tipografía, color y espaciado que la de cuenta. *(Añade una fila que el diseño no tiene — exige
  registro, A-117)*
- **FR-035**: Para un Super Admin, la tarjeta MUST omitir la fila de negocio por completo, sin
  dejar espacio vacío ni mostrar texto de relleno.
- **FR-036**: La fecha y hora MUST mostrarse en hora de Colombia con el formato
  "dd/mm/aaaa · hh:mm a. m./p. m. (hora de Colombia)", con hora de 12 y cero inicial, por ejemplo
  "02/10/2026 · 04:06 p. m. (hora de Colombia)". *(Cambia el formato actual en UTC — exige
  registro, A-118)*
- **FR-037**: El correo MUST incluir el botón "Iniciar sesión" apuntando al subdominio del negocio
  del destinatario, o al subdominio de la plataforma cuando el destinatario es un Super Admin.
- **FR-038**: El aviso de atención MUST decir, para un usuario de tenant, que contacte de inmediato
  a un administrador de su negocio; y para un Super Admin, que escriba a `skeilo.tech@gmail.com`, la
  misma dirección del pie (FR-013). La tarjeta, sus colores y su posición no cambian entre las dos
  variantes.
- **FR-039**: El correo MUST NOT contener la contraseña nueva ni la anterior, ni ningún fragmento
  de ellas.

### Requisitos de seguridad del contenido dinámico

- **FR-040**: Todos los valores dinámicos que entren en las plantillas —nombre de la persona,
  nombre comercial del negocio, correo, contraseña temporal y URL— MUST escaparse antes de
  insertarse, de modo que un valor con marcado se muestre como texto y no se interprete, y de modo
  que el usuario lea el carácter original y no su entidad.
- **FR-041**: Cuando falte un valor obligatorio de una plantilla —vacío o nulo— el sistema MUST
  fallar la generación del correo, registrar el error con suficiente contexto para identificar el
  caso, y MUST NOT enviar un correo con huecos, "None", "null" ni valores de relleno. En el flujo de
  invitación ese fallo MUST propagarse como fallo de la operación, exactamente igual que cuando el
  servicio de correo no responde (FR-057): la invitación no queda creada. *(Hoy el valor vacío se
  interpola, el correo sale con el hueco y la invitación queda creada — exige registro, A-121)*
- **FR-042**: El fallo de FR-041 MUST NOT exponer la contraseña temporal en el mensaje de error ni
  en los registros.
- **FR-043**: Ningún correo MUST incluir datos, nombres o enlaces de un negocio distinto del
  negocio del destinatario.

### Requisitos de la versión en texto plano

- **FR-044**: Las tres plantillas MUST producir, además del HTML, una versión en texto plano con el
  mismo contenido útil: título, cuerpo, datos, avisos y pie.
- **FR-045**: En la versión en texto plano, cada enlace MUST escribirse completo y en una línea
  propia, de modo que pueda copiarse sin ambigüedad.
- **FR-046**: La versión en texto plano MUST respetar las mismas reglas de contenido que el HTML:
  sin contraseña en la vista previa, sin datos de otro negocio, misma hora de Colombia y mismo
  aviso según el rol.
- **FR-047**: El mensaje enviado al servicio de correo MUST incluir el cuerpo en texto plano además
  del HTML, sin alterar la forma en que ese servicio recibe hoy el resto de los campos.
- **FR-048**: Si el servicio de correo ignora el cuerpo en texto plano, el HTML MUST seguir
  enviándose y mostrándose intacto. Esta condición se verifica con un envío real.

### Requisitos de privacidad y seguimiento

- **FR-049**: Las plantillas MUST NOT incluir ninguna imagen de seguimiento de apertura, ni visible
  ni de un píxel.
- **FR-050**: Los enlaces de los correos MUST apuntar directamente a su destino final, sin pasar
  por ningún servicio de redirección ni de conteo de clics.
- **FR-051**: Las plantillas MUST NOT cargar recursos externos distintos del logo alojado en el
  dominio de recursos del propio producto.

### Requisitos de compatibilidad

- **FR-052**: Los tres correos MUST verse correctos y legibles en Gmail web, Gmail Android, Outlook
  web, Outlook de escritorio y Apple Mail. La conformidad se demuestra por dos vías distintas: por
  **verificación real** en Gmail web y Gmail Android, que son los clientes con acceso en esta
  entrega; y por **conformidad de construcción** en Outlook web, Outlook de escritorio y Apple Mail,
  garantizada por la técnica de maquetación que exige FR-005. Estos tres últimos quedan como
  **verificación diferida** declarada —no como criterio incumplido— y no condicionan el cierre de
  esta spec. *(D14)*
- **FR-053**: Los tres correos MUST caber en un ancho de 360 px sin desplazamiento horizontal y sin
  texto cortado.
- **FR-054**: El contenido MUST conservar su jerarquía cuando el cliente aplique su propio tema
  oscuro, sin que ningún texto quede del mismo color que su fondo.

### Requisitos de no regresión

- **FR-055**: La respuesta genérica de la solicitud de restablecimiento MUST seguir siendo idéntica
  para una cuenta que existe y para una que no, y MUST seguir sin enviarse correo alguno cuando la
  cuenta no existe.
- **FR-056**: El vencimiento de 30 minutos, el uso único del enlace y el cierre de sesiones al
  cambiar la contraseña MUST permanecer exactamente como están.
- **FR-057**: El comportamiento de envío de cada disparador MUST permanecer como está: la
  invitación falla la operación si el correo no sale, y los otros tres no rompen su respuesta si el
  envío falla. El fallo de generación de FR-041 MUST tratarse como un caso más de "el correo no
  sale", sin inventar una vía de error distinta (A-121).
- **FR-058**: La regla de la spec 091 de no usar nunca el correo como nombre en el saludo MUST
  conservarse.
- **FR-059**: Los tests existentes que afirman el contenido de estos correos MUST actualizarse de
  forma explícita, citando en el mismo cambio la decisión que lo autoriza. Son, como mínimo:
  `test_invitation_email_greeting.py` (saludo y escape), `test_invitations_resend_cancel.py` (saludo
  del reenvío), `test_auth_change_password.py` y `test_auth_reset_password.py` (asuntos).
- **FR-060**: La extracción del token desde el cuerpo del correo que hacen
  `test_auth_forgot_password.py` y `test_auth_reset_password.py` MUST seguir funcionando con la
  plantilla nueva, incluido el enlace visible que añade FR-031.
- **FR-061**: Como las verificaciones con envío real salen por el servicio de producción (A-120),
  toda prueba manual de esta spec MUST dirigirse únicamente a casillas del propio equipo, y los
  negocios, usuarios e invitaciones que se creen para probar MUST quedar marcados de forma
  reconocible como datos de prueba. Ninguna verificación MUST provocar el envío de un correo a una
  dirección de un cliente real. *(D15)*

### Key Entities

- **Plantilla de correo**: la pieza que combina la maqueta aprobada con los datos de un envío
  concreto y produce dos salidas equivalentes, una en HTML y otra en texto plano.
- **Datos del correo de invitación**: nombre comercial del negocio, nombre de la persona
  (opcional), correo, contraseña temporal y URL de ingreso del negocio.
- **Datos del correo de restablecimiento**: enlace de un solo uso y vigencia en minutos.
- **Datos del correo de contraseña cambiada**: correo de la cuenta, nombre comercial del negocio
  (ausente para un Super Admin), momento del cambio y destino de ingreso según el rol.
- **Recurso de marca**: el logo horizontal sobre fondo claro, publicado una sola vez bajo la clave
  `brand/logo-horizontal-claro-1200.png` del dominio de recursos del producto, al que las tres
  plantillas apuntan desde cualquier entorno.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Los tres correos se ven como el diseño aprobado en Gmail web y Gmail Android —los dos
  clientes de verificación real de FR-052—, sin ninguna diferencia visible de estructura, color o
  jerarquía, salvo las tipografías de reserva. Los tres clientes de verificación diferida de FR-052
  no condicionan este criterio.
- **SC-002**: Los tres correos se leen completos a 360 px de ancho sin desplazamiento horizontal.
- **SC-003**: Una persona recién invitada encuentra su dirección de ingreso, su usuario y su
  contraseña temporal en el primer vistazo, sin desplazarse en el teléfono.
- **SC-004**: El 100% de los valores dinámicos insertados en los tres correos se muestran como
  texto, incluso cuando contienen marcado, símbolos o letras acentuadas.
- **SC-005**: Ningún correo generado con una variable obligatoria faltante llega al destinatario: la
  generación falla y queda registrada.
- **SC-006**: La contraseña temporal no aparece en el asunto, en el texto de vista previa ni en
  ningún registro del sistema, verificado sobre un envío real.
- **SC-007**: Los enlaces que recibe el destinatario son idénticos a los que el sistema generó: sin
  redirecciones intermedias, sin parámetros añadidos y sin imagen de seguimiento, verificado sobre
  los encabezados y el cuerpo de un correo real.
- **SC-008**: El correo de contraseña cambiada muestra la hora que el usuario reconoce: la hora de
  Colombia del momento del cambio, con el formato de FR-036.
- **SC-009**: Un destinatario con cliente de solo texto recibe el mismo contenido útil y puede
  completar la acción copiando el enlace.
- **SC-010**: Los cuatro disparadores siguen funcionando con sus mismos resultados: ningún flujo de
  invitación, restablecimiento o cambio de contraseña cambia su comportamiento observable.
- **SC-011**: La suite del backend queda en verde, con las únicas actualizaciones de test que FR-059
  autoriza y ninguna más.

## Decisiones Tomadas

Las cuatro primeras rondas de decisiones las resolvió el negocio el 2026-10-06, con las alternativas
y su impacto a la vista. El resto se resolvió durante la redacción con la información verificada en
el código. Todas quedan documentadas para que no se reabran durante la implementación.

- **D1 — El alcance es solo de plantillas** *(decidido por el negocio, 2026-10-06)*. El pedido
  original trae diecinueve escenarios, de los cuales cuatro exigen comportamiento que hoy no
  existe: el vencimiento de 72 horas de la contraseña temporal, el estado "Invitación no enviada"
  con reintentos, el restablecimiento de contraseña del Super Admin y la supresión del aviso en el
  primer cambio obligatorio. El negocio decidió entregar primero la presentación, que es lo que hoy
  perjudica la experiencia, y dejar esos cuatro para specs propias. Consecuencia aceptada: los
  escenarios 5, 6, 10, 13 y 18 del pedido quedan sin cubrir y están listados en *Fuera de Alcance*.
- **D2 — El servicio de envío no se cambia** *(decidido por el negocio, 2026-10-06)*. Los correos
  salen hoy por un microservicio externo que no vive en ninguno de los cuatro repositorios del
  producto y del que solo se conoce la forma del mensaje que ya recibe. Se descartó migrar el envío
  a la API del proveedor dentro del backend, porque eso convierte una spec de presentación en una
  de infraestructura. Consecuencia aceptada: lo que el servicio no soporte —empezando por el cuerpo
  en texto plano— no puede garantizarse desde aquí, y se verifica empíricamente (D7).
- **D3 — El diseño manda en lo visual, el pedido manda en el contenido** *(decidido por el negocio,
  2026-10-06)*. El diseño y el pedido se contradicen en cuatro puntos. La regla de arbitraje es que
  la estructura, los colores, el espaciado y la tipografía se toman del diseño sin discusión, y el
  texto y los datos se toman del pedido. De esa regla salen D4, D5, D6 y D11.
- **D4 — La hora se muestra en hora de Colombia, no en UTC** *(decidido por el negocio,
  2026-10-06)*. El diseño muestra "21:06 UTC" y el código actual también envía UTC. Un empleado de
  mostrador no sabe convertir UTC, y el propósito de este correo es que reconozca si el cambio fue
  suyo: una hora que no reconoce vuelve inútil el aviso. Se adopta el formato del pedido
  (FR-036). Consecuencia: cambia el contenido de un correo que ya se envía, y eso exige registro
  (A-118).
- **D5 — El correo de contraseña cambiada gana una fila de negocio** *(decidido por el negocio,
  2026-10-06)*. El diseño tiene dos filas, cuenta y fecha; el pedido exige también el negocio. Se
  añade como tercera fila con el mismo estilo, porque una misma persona puede tener cuenta en más
  de un negocio y sin ese dato no sabe cuál cambió. Consecuencia: es un elemento que el diseño no
  contempla, y eso exige registro (A-117).
- **D6 — Hay una variante de Super Admin del aviso de cambio** *(decidido por el negocio,
  2026-10-06)*. El aviso del diseño le dice al destinatario que contacte a un administrador de su
  negocio, pero un Super Admin no tiene negocio ni administrador por encima. Como el cambio de
  contraseña desde la aplicación ya funciona hoy para cuentas de plataforma, ese correo ya se envía
  con un consejo que no aplica. La variante cambia solo la frase y omite la fila de negocio.
- **D7 — El texto plano se envía aunque no se sepa si el servicio lo acepta** *(decidido por el
  negocio, 2026-10-06)*. Como el servicio de envío es opaco (D2), hay dos caminos: no entregar
  texto plano, o generarlo, enviarlo y comprobar el resultado en un correo real. Se eligió el
  segundo porque el costo de intentarlo es nulo —si el campo se ignora, el HTML sale igual— y el
  beneficio es cubrir el escenario 17. La verificación con envío real es parte del trabajo, no
  opcional (FR-048).
- **D8 — El remitente no cambia; sí cambia su nombre visible** *(decidido por el negocio,
  2026-10-06)*. El pedido nombra una dirección de remitente en el dominio del producto, pero ese
  dominio no está verificado ante el proveedor de correo y la autenticación del dominio quedó fuera
  de alcance. Cambiar la dirección ahora dejaría de enviar correos por completo. Se cambia solo el
  nombre visible, que hoy dice "Mi app" y es lo primero que el destinatario lee. El pie conserva la
  dirección de contacto del diseño. Consecuencia: el remitente real sigue siendo el dominio de
  pruebas del proveedor hasta que exista la spec de entregabilidad.
- **D9 — El correo del alta de negocio reusa la plantilla de invitación** *(decidido por el
  negocio, 2026-10-06)*. Son dos correos con contenido idéntico —URL, usuario, contraseña
  temporal— y maquetas distintas, lo que dejaría a un cliente nuevo recibiendo la versión sin
  marca. Se unifica la presentación sin tocar el flujo que lo dispara.
- **D10 — El correo de invitación no menciona ningún vencimiento**. El escenario 1 del pedido pide
  anunciar que la contraseña temporal vence en 72 horas, pero el vencimiento no existe en el
  sistema (está en *Fuera de Alcance* por D1) y el diseño tampoco lo menciona. Anunciar un plazo
  que el sistema no aplica es una afirmación falsa que, además, induce a pedir una invitación nueva
  sin necesidad. El correo calla sobre el plazo hasta que el plazo exista; cuando la spec del
  vencimiento se implemente, esta frase es lo primero que debe añadirse.
- **D11 — El saludo se integra en el párrafo, con la regla de la spec 091 intacta**. El diseño abre
  el párrafo con "Hola, Deimer Hernandez." y continúa en la misma frase, mientras el código actual
  usa "Hola, {nombre}:" en una línea propia. Se adopta la forma del diseño, y sin nombre el párrafo
  abre con "Hola." La regla de fondo de la spec 091 —nunca mostrar el correo como si fuera el
  nombre— se conserva literalmente (FR-058).
- **D12 — El logo se publica en el dominio de recursos del producto**. El diseño lo referencia por
  una ruta local, inservible en un correo. Se descartó incrustarlo en el mensaje porque los
  clientes mayoritarios bloquean ese tipo de imagen y el logo no se vería. Se publica en el
  almacenamiento de objetos que el producto ya usa para imágenes, servido por el dominio de
  recursos que las specs 080 y 088 dejaron en funcionamiento, con una **clave fija del bucket de
  producción**: `brand/logo-horizontal-claro-1200.png` bajo `assets.skeilopos.com`. El archivo de
  origen es `logo-horizontal-violeta-fondo-claro-1200px.png` del sistema de diseño, y se sube una
  sola vez a mano antes de implementar. Todos los entornos apuntan a esa misma URL: se descartó
  replicar el logo por entorno porque es un recurso de marca y no un dato de un negocio —así que no
  entra en el modelo de claves por tenant— y porque una URL por entorno dejaría los correos de
  prueba con el logo roto, que es justo lo que esta spec viene a arreglar.
- **D13 — Se adoptan los tres asuntos del pedido**. El asunto actual de la invitación ("Bienvenido
  a {negocio}") no dice que se trate de una invitación ni nombra el producto, y los otros dos no
  nombran el producto. Los tres pasan a los literales del pedido. Consecuencia: dos tests existentes
  afirman los asuntos actuales y deben actualizarse (FR-059), y el cambio exige registro (A-113).
- **D14 — La fidelidad visual se verifica en Gmail; Outlook y Apple Mail son verificación
  diferida**. FR-052 nombra cinco clientes, pero en esta entrega solo hay acceso real a Gmail web y
  Gmail Android. Se descartó exigir los cinco con cuentas reales, porque dejaría SC-001 imposible de
  cerrar y la spec terminaría con verificaciones pendientes indefinidamente; y se descartó recortar
  el requisito a Gmail, porque Outlook de escritorio es exactamente el cliente que rompe las
  maquetas modernas y renunciar a él invitaría a construir el correo con técnicas que allí fallan.
  La conformidad en esos tres clientes se obtiene por construcción —la técnica de maquetación que
  exige FR-005— y su comprobación queda declarada como diferida. Consecuencia aceptada: si más
  adelante aparece un defecto en Outlook o Apple Mail, es un defecto nuevo y no una regresión de
  esta spec.
- **D15 — El entorno de desarrollo no se arregla aquí; se añade una salvaguarda de
  destinatarios**. A-120 dejó al descubierto que desarrollo envía por el servicio de producción, así
  que cualquier prueba manda correo real. Se descartó corregir la duplicidad del archivo de entorno
  dentro de esta spec por dos razones: los envíos reales no son un efecto colateral de este trabajo
  sino un requisito suyo —FR-048 solo se puede verificar empíricamente, y FR-052, SC-006 y SC-007
  también exigen un correo real—, y arreglar la configuración de entornos es trabajo de
  infraestructura, no de plantillas (Principio V). El riesgo que queda es equivocarse de
  destinatario, y eso lo acota FR-061. Consecuencia aceptada: A-120 sigue abierta y cualquier
  descuido durante la implementación llega a un buzón de verdad.
- **D16 — Un valor obligatorio faltante hace fallar la invitación completa**. FR-041 impide generar
  un correo con huecos, y FR-057 conserva la regla de que la invitación falla si el correo no sale:
  juntos cambian lo que el administrador ve hoy, porque hoy el valor vacío se interpola, el correo
  llega con "None" y la invitación queda creada. Se descartó crear la invitación y fallar solo el
  correo, porque dejaría una invitación aparentemente válida cuya persona no puede entrar —el mismo
  agujero que la spec 037 cerró deliberadamente—, y se descartó exceptuar la invitación de FR-041,
  porque es precisamente el correo que lleva la contraseña temporal. Consecuencia: es un cambio de
  comportamiento observable y exige registro, ya escrito como A-121 el 2026-10-06.

## Decisiones que exigen registro en el registro de anomalías

El Principio II obliga a registrar en `specs/000-reconocimiento/registro-de-anomalias.md`, **antes
de implementar**, todo cambio de comportamiento existente. Esta spec cambia siete comportamientos ya
en producción y descubrió dos hallazgos.

**Las nueve entradas quedaron registradas el 2026-10-06**, a continuación de A-112, con el
identificador que esta tabla les asigna. Siete están en estado "REGISTRADA, pendiente de
implementar"; A-119 queda pendiente de corregirse con la implementación y A-120 sin corrección
prevista en esta spec. A-121 surgió en la clarificación, se escribió después de A-120 y con ella
queda cerrada la compuerta del Principio II que bloqueaba FR-041:

| Id | Tipo | Qué cambia o qué se halló |
|---|---|---|
| A-113 | Decisión de negocio | Los tres asuntos cambian a los literales del pedido; la invitación deja de decir "Bienvenido a {negocio}" (D13, FR-010) |
| A-114 | Decisión de negocio | El nombre visible del remitente pasa de "Mi app" a "SkeiloPOS", y la dirección sigue siendo la del dominio de pruebas del proveedor hasta la spec de entregabilidad (D8, FR-011) |
| A-115 | Decisión de negocio | El correo del alta de un negocio pierde su plantilla propia y reusa la de invitación (D9, FR-026) |
| A-116 | Decisión de negocio | El correo de restablecimiento añade el enlace en texto visible, que el diseño no contempla (FR-031) |
| A-117 | Decisión de negocio | El correo de contraseña cambiada añade la fila de negocio, que el diseño no contempla (D5, FR-034) |
| A-118 | Decisión de negocio | El correo de contraseña cambiada pasa de UTC a hora de Colombia (D4, FR-036) |
| A-119 | Hallazgo | La plantilla de invitación escapa únicamente el nombre de la persona: el nombre del negocio, el correo, la contraseña y la URL se interpolan sin escapar, de modo que un nombre comercial con marcado hoy se interpretaría (FR-040) |
| A-120 | Hallazgo | El archivo de entorno del backend define la dirección del servicio de correo dos veces y gana la última: en desarrollo los correos salen por el servicio de producción, así que cualquier prueba manual envía correo real |
| A-121 | Decisión de negocio | Un valor obligatorio vacío o nulo pasa a impedir la creación de la invitación. Hoy se interpola, el correo sale con el hueco y la invitación queda creada (D16, FR-041, FR-057) |

## Fuera de Alcance

Los siguientes escenarios del pedido original **no** se cubren aquí. No se descartan: quedan
identificados para sus propias specs.

- **Vencimiento de la contraseña temporal a las 72 horas** *(escenarios 5 y la parte de vencimiento
  del 7)*. Hoy la invitación guarda la fecha de envío pero el ingreso no valida antigüedad alguna:
  una contraseña temporal de hace seis meses sigue sirviendo. Exige un campo nuevo, su validación en
  el ingreso, el mensaje de rechazo y el cálculo del plazo al reenviar.
- **Estado "Invitación no enviada" y reintentos de envío** *(escenario 6)*. Hoy un fallo del
  servicio de correo revierte la invitación y devuelve un error al administrador: la invitación no
  queda registrada, así que no hay nada que reenviar. Exige un estado nuevo, política de reintentos
  y cambios en la página de usuarios.
- **Restablecimiento de contraseña del Super Admin** *(escenario 10)*. Hoy la solicitud de enlace
  resuelve el negocio por el host y busca la cuenta dentro de ese negocio, así que una cuenta de
  plataforma no puede pedir un enlace. Exige abrir ese flujo en el subdominio de la plataforma. La
  variante de Super Admin del aviso de cambio (D6) sí entra aquí, porque ese correo ya se envía hoy.
- **No avisar en el primer cambio obligatorio** *(escenario 13)*. Hoy el aviso de contraseña
  cambiada se dispara en todo cambio exitoso, incluido el primero obligatorio. Suprimirlo es un
  cambio de disparador, no de plantilla.
- **Autenticación del dominio: SPF, DKIM y DMARC** *(escenario 18)*. Es trabajo de infraestructura
  sobre el DNS y la verificación del dominio ante el proveedor de correo, y es condición previa para
  poder enviar desde una dirección del dominio del producto (D8).
- **Correos promocionales, de marketing y cualquier notificación ajena al flujo de acceso**, como
  ya excluía el pedido.

## Assumptions

- **Fuente de verdad del diseño**: los tres archivos de la carpeta `SkeiloPOS App diseñada` se
  toman como referencia de intención visual y de contenido. Están escritos para visualizarse en un
  navegador, no para enviarse por correo, así que la equivalencia se evalúa sobre el resultado
  percibido en un cliente de correo real y no sobre su marcado.
- **Tema visual**: el diseño se entrega en tema claro y esta spec asume únicamente tema claro, con
  la salvedad de FR-054 para los clientes que imponen su propio tema oscuro.
- **Idioma**: los tres correos se entregan únicamente en español, como el resto del sistema.
- **Alcance por repositorio**: la totalidad del trabajo es de `pos-backend`, más la publicación del
  logo en el almacenamiento de objetos. `pos-heladeria` no se toca.
- **Disparadores**: los cuatro puntos desde los que se envían estos correos ya funcionan y se
  conservan tal cual, incluida la diferencia de que la invitación se envía de forma síncrona y los
  demás en segundo plano.
- **Datos disponibles en el envío**: el aviso de contraseña cambiada necesita el nombre comercial
  del negocio y el rol del destinatario, que hoy no recibe. Se asume que ambos son obtenibles desde
  la cuenta en el momento del envío, sin consultas nuevas al usuario ni cambios de modelo de datos.
- **Verificación con envío real**: se asume que el usuario facilita una casilla de Gmail, abrible en
  web y en Android, para las verificaciones de FR-048, FR-052 y SC-007, y que acepta que esas
  pruebas salen por el servicio de producción (A-120). No se asume acceso a Outlook de escritorio ni
  a Apple Mail (D14).
- **Comportamiento protegido**: ningún requisito de esta spec cambia la lógica de los flujos de
  acceso, con una única excepción ya identificada y decidida: el fallo de generación de FR-041 hace
  fallar la creación de la invitación (D16, A-121). Si la implementación descubre cualquier otra, se
  detiene y se registra la decisión antes de continuar (Principio II).

## Dependencias

- **Spec 031 (recuperación y cambio de contraseña)**: define el enlace de un solo uso de 30 minutos,
  el límite de solicitudes, la respuesta genérica que previene la enumeración de cuentas y el
  disparo del aviso de cambio. Esta spec rediseña sus dos correos sin cambiar su comportamiento, y
  actualiza dos de sus tests por el cambio de asunto (FR-059).
- **Spec 037 (invitación de usuarios de tenant)**: define la invitación, el reenvío con contraseña
  nueva y la regla de no confirmar una invitación cuyo correo no salió. Esta spec rediseña su correo
  y conserva esa regla (FR-057).
- **Spec 091 (admin aislado y nombre completo en invitaciones)**: define el saludo por el nombre, el
  escape del nombre, la regla de no usar el correo como nombre, y el subdominio de la plataforma como
  único acceso del Super Admin. Esta spec conserva la regla, cambia la redacción del saludo (D11) y
  usa ese subdominio como destino de la variante de Super Admin (FR-037).
- **Specs 080 y 088 (imágenes por clave relativa e integridad de referencias)**: dejaron en
  funcionamiento el almacenamiento de objetos y el dominio de recursos donde se publica el logo
  (D12). El logo es un recurso de marca, no de un negocio, así que no entra en el modelo de claves
  por tenant de esas specs.
- **Sistema de diseño de SkeiloPOS**: aporta los dos archivos de logo y los valores de color y
  tipografía que FR-002 exige.
- **Microservicio de correo** *(externo, sin repositorio conocido)*: recibe el mensaje y lo entrega
  al proveedor. Es la dependencia de mayor riesgo de esta spec: no se puede inspeccionar, su
  contrato solo se conoce por lo que el código ya le envía, y de él dependen FR-047, FR-048 y los
  requisitos de no seguimiento (FR-049 a FR-051).
- **Spec posterior de entregabilidad (aún no creada)**: deberá verificar el dominio ante el
  proveedor, configurar SPF, DKIM y DMARC, y cambiar la dirección del remitente a la del dominio del
  producto (D8, escenario 18 del pedido).
- **Spec posterior de vencimiento de invitaciones (aún no creada)**: deberá implementar el plazo de
  72 horas y, al hacerlo, añadir al correo de invitación la frase que D10 deja deliberadamente
  fuera.
