# Feature Specification: Gestión de documentos legales de plataforma, plantilla de tenant y consentimiento del cliente final

**Feature Branch**: `162-gestion-documentos-legales`

**Created**: 2026-11-18

**Status**: Draft

**Input**: User description: "Como super admin de la plataforma, quiero administrar las políticas de privacidad y los términos y condiciones de la plataforma, y una plantilla legal que cada tenant personaliza, para que todo documento legal tenga versión, vigencia y evidencia de aceptación, y que la landing y el flujo del menú QR consuman siempre el texto vigente."

## Clarifications

### Session 2026-11-18

- Q: When a customer taps "continue" after seeing the notice (and before typing their name), what identifies them for the consent record, since no name has been captured yet? → A: "Continue" is a single action that both submits the name and registers acceptance; the identifier is the client/order record created by that same submission.
- Q: How is the tenant's own acceptance of the platform's legal documents (FR-019) triggered — what moment in the tenant admin's experience requires them to accept? → A: The tenant admin panel blocks access with a modal the tenant admin must accept, shown on first login and again whenever the platform publishes a new version of its Privacy Policy or Terms, until accepted.
- Q: When a tenant admin sees the "template update pending" notice (FR-015) because the super admin published a newer master template version, where should that notice appear? → A: A persistent in-panel banner in the tenant's legal-documents section, plus an email sent to the tenant's contact address when the new template version is published.
- Q: For the public endpoint serving current legal documents (FR-005), roughly what request volume should it sustain per client, to size the rate limit? → A: Defer the exact numeric threshold to the planning phase; the spec only requires a reasonable rate limit that prevents abuse without affecting normal landing/menu traffic.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Super admin publica y versiona los documentos legales de la plataforma (Priority: P1)

El super admin crea y edita en borrador la Política de Privacidad y los Términos y Condiciones de la plataforma (contenido en Markdown), y cuando está conforme los publica. Publicar deja fijada esa versión como vigente; la versión anterior (si existía) pasa a estar superada. La landing pública siempre puede consultar el texto vigente de cada tipo de documento sin autenticarse.

**Why this priority**: Es el cimiento legal de toda la plataforma: sin esto no hay evidencia de qué política regía en cada momento ni una fuente confiable para que la landing muestre el texto correcto.

**Independent Test**: Como super admin, crear un borrador de Términos y Condiciones, publicarlo, confirmar que aparece como versión vigente y que un cliente no autenticado puede leerlo; luego editar y publicar una segunda versión y confirmar que la primera queda marcada como superada y la segunda es la única vigente.

**Acceptance Scenarios**:

1. **Given** no existe ninguna versión publicada de un tipo de documento, **When** el super admin crea un borrador y lo publica, **Then** el documento queda en estado publicado, con número de versión y fecha de vigencia, y es la única versión vigente de ese tipo.
2. **Given** existe una versión publicada de un tipo de documento, **When** el super admin publica una nueva versión del mismo tipo, **Then** la versión anterior cambia a estado "superada", la nueva queda como la única vigente, y el contenido de la versión superada permanece intacto y consultable en el historial.
3. **Given** una versión ya fue publicada, **When** se intenta modificar su contenido directamente, **Then** el sistema rechaza la edición; la única forma de cambiar el texto vigente es crear y publicar una nueva versión.
4. **Given** una versión de un documento está publicada, **When** cualquier visitante (sin iniciar sesión) consulta el texto vigente de ese tipo de documento, **Then** recibe el contenido, el número de versión y la fecha de vigencia correspondientes a la versión publicada más reciente.
5. **Given** un usuario sin rol de super admin, **When** intenta crear, editar o publicar un documento de plataforma, **Then** la acción es rechazada.
6. **Given** el super admin publica una nueva versión vigente de un documento de plataforma, **When** un administrador de tenant que ya había aceptado la versión anterior vuelve a iniciar sesión en el panel del tenant, **Then** el sistema bloquea el acceso al panel con un aviso que exige aceptar la nueva versión antes de continuar.
7. **Given** un administrador de tenant inicia sesión por primera vez, **When** aún no existe un registro de aceptación suyo de los documentos de plataforma vigentes, **Then** el sistema bloquea el acceso al panel con el mismo aviso de aceptación hasta que acepte.

---

### User Story 2 - Super admin administra la plantilla legal maestra para tenants (Priority: P1)

El super admin redacta y versiona una plantilla legal maestra que usan todos los tenants para generar su propio aviso de privacidad y términos y condiciones. La plantilla usa variables de una lista cerrada (nombre del negocio, identificación legal, dirección, ciudad, correo y teléfono de contacto). Publicar una nueva versión de la plantilla no altera lo que los tenants ya publicaron ni lo que sus clientes ya aceptaron.

**Why this priority**: Es el mecanismo que permite escalar documentos legales a todos los tenants sin que cada uno redacte su propio texto legal, manteniendo control centralizado sobre las cláusulas obligatorias.

**Independent Test**: Como super admin, editar la plantilla maestra usando solo variables permitidas y publicarla; confirmar que se puede consultar su contenido y versión. Luego intentar guardar una plantilla con una variable no permitida y confirmar que el sistema la rechaza señalando cuál variable no es válida.

**Acceptance Scenarios**:

1. **Given** el super admin redacta una plantilla usando únicamente variables de la lista cerrada permitida, **When** guarda la plantilla, **Then** el sistema la acepta y permite publicarla como una nueva versión.
2. **Given** el super admin redacta una plantilla que incluye una o más variables fuera de la lista cerrada, **When** intenta guardar, **Then** el sistema rechaza el guardado e indica exactamente cuáles variables no están permitidas.
3. **Given** ya existen tenants con un documento publicado basado en una versión anterior de la plantilla, **When** el super admin publica una nueva versión de la plantilla, **Then** los documentos ya publicados de esos tenants no cambian su contenido ni se re-generan automáticamente.

---

### User Story 3 - Tenant completa sus datos y publica su propio documento legal (Priority: P1)

El administrador del tenant completa en el panel sus datos legales (razón social, identificación legal, dirección, ciudad, contacto, días de retención). El sistema exige todos los datos antes de permitir generar el documento, y muestra una vista previa del texto resultante antes de publicar. Al publicar, se guarda una copia fija (snapshot) del texto ya combinado con los datos del tenant, junto con la versión de plantilla usada y una huella de verificación del contenido. Esa copia fija es lo que verán los clientes finales, nunca una versión recalculada en el momento.

**Why this priority**: Sin un documento propio publicado, el tenant no tiene base legal para capturar datos de clientes en el menú QR; es el requisito habilitante del flujo de consentimiento (User Story 4).

**Independent Test**: Como administrador de un tenant, completar todos los datos legales requeridos, ver la vista previa del documento renderizado, publicarlo y confirmar que queda disponible un snapshot con hash de contenido y versión de plantilla asociada. Confirmar también que si el super admin publica después una nueva versión de la plantilla, el tenant ve un aviso de actualización pendiente pero su documento publicado no cambia hasta que el propio tenant decida regenerarlo y publicarlo de nuevo.

**Acceptance Scenarios**:

1. **Given** el tenant no ha completado todos los datos legales obligatorios, **When** intenta generar o publicar su documento, **Then** el sistema lo impide y señala los datos faltantes.
2. **Given** el tenant completó todos los datos obligatorios, **When** solicita la vista previa, **Then** el sistema muestra el texto final con los datos ya sustituidos en la plantilla, sin guardar todavía nada como definitivo.
3. **Given** el tenant aprueba la vista previa, **When** publica el documento, **Then** el sistema guarda un snapshot inmutable con el texto renderizado, la versión de plantilla usada, una huella de verificación del contenido y la fecha de publicación.
4. **Given** el tenant tiene un documento publicado basado en la versión N de la plantilla, **When** el super admin publica la versión N+1 de la plantilla, **Then** el tenant ve un banner persistente en la sección de documentos legales del panel y recibe un correo a su dirección de contacto avisando que hay una actualización de plantilla pendiente de revisión, pero su documento publicado sigue siendo el mismo hasta que decida generar y publicar uno nuevo.
5. **Given** un tenant no tiene ningún documento legal publicado, **When** intenta activar la captura de nombre en el menú QR, **Then** el sistema no permite activar esa función hasta que exista un documento publicado.

---

### User Story 4 - Cliente final acepta el aviso antes de dejar su nombre en el menú QR (Priority: P1)

Antes de pedirle el nombre, el menú QR de un tenant con documento legal publicado le muestra al cliente un aviso breve con un enlace al documento vigente del tenant, indicando que al continuar acepta sus términos y aviso de privacidad (sin necesidad de marcar una casilla). Cada vez que un cliente continúa tras ver el aviso, el sistema registra la evidencia de esa aceptación.

**Why this priority**: Es el objetivo final de negocio de la funcionalidad: contar con evidencia de que el cliente fue informado y aceptó antes de que sus datos personales (el nombre) fueran capturados.

**Independent Test**: En el menú QR de un tenant con documento publicado, iniciar el flujo de captura de nombre, confirmar que se muestra el aviso con enlace al documento vigente del tenant antes de pedir el nombre, continuar, y verificar que se registró una aceptación asociada a ese cliente y a esa versión exacta del documento (snapshot).

**Acceptance Scenarios**:

1. **Given** un tenant tiene un documento legal publicado, **When** un cliente final llega al paso de ingresar su nombre en el menú QR, **Then** el sistema muestra primero el aviso breve con enlace al documento vigente del tenant, y el campo para ingresar el nombre junto con la acción de continuar, antes de que exista ningún registro del cliente.
2. **Given** el cliente ve el aviso y escribe su nombre, **When** confirma y continúa el flujo en una sola acción (sin necesidad de marcar ninguna casilla adicional), **Then** el sistema crea el registro del cliente con el nombre ingresado y, en la misma operación, registra la aceptación usando ese registro como identificador del cliente, junto con identificador del tenant, referencia al snapshot del documento aceptado, fecha y hora, y una huella no reversible de la dirección IP (nunca la IP en texto claro).
3. **Given** un tenant no tiene ningún documento legal publicado, **When** se intenta iniciar el flujo de captura de nombre en su menú QR, **Then** el sistema no permite capturar el nombre hasta que el tenant tenga un documento publicado.

---

### Edge Cases

- ¿Qué pasa si el super admin intenta publicar un documento de plataforma o una plantilla sin haber definido fecha de entrada en vigencia? El sistema debe exigir una fecha de vigencia válida antes de permitir la publicación.
- ¿Qué pasa si dos solicitudes de publicación del mismo tipo de documento (o de la misma plantilla) llegan casi al mismo tiempo? Solo una puede quedar como la versión vigente; el sistema debe garantizar que nunca existan dos versiones vigentes simultáneas del mismo tipo.
- ¿Qué pasa si el tenant cambia uno de sus datos legales (por ejemplo, el correo de contacto) después de tener un documento publicado? El documento publicado existente no cambia automáticamente; el tenant debe generar y publicar una nueva versión para que el cambio se refleje en lo que ven los clientes.
- ¿Qué pasa si el super admin despublica o elimina el acceso de un tenant mientras existen aceptaciones de clientes ya registradas sobre su documento? Las aceptaciones y los snapshots ya guardados deben permanecer intactos y consultables como evidencia histórica.
- ¿Qué pasa si se intenta consultar el documento vigente de la plataforma desde un dominio distinto al de la landing autorizada? La solicitud debe ser rechazada por la política de acceso entre dominios.
- ¿Qué pasa si un cliente final cierra el menú QR justo después de ver el aviso pero antes de continuar? No debe registrarse ninguna aceptación; solo se registra evidencia cuando el cliente efectivamente continúa el flujo.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST permitir que únicamente usuarios con rol de super admin creen, editen (en borrador) y publiquen documentos legales de la plataforma de tipo Política de Privacidad y Términos y Condiciones, con contenido en formato Markdown.
- **FR-002**: El sistema MUST mantener para cada documento legal de plataforma un estado (borrador, publicado o superado) y una fecha de entrada en vigencia.
- **FR-003**: El sistema MUST impedir la edición del contenido de una versión ya publicada; cualquier cambio posterior requiere crear y publicar una nueva versión, momento en el cual la versión anterior pasa automáticamente a estado "superada".
- **FR-004**: El sistema MUST garantizar que en todo momento exista como máximo una versión vigente (publicada y no superada) por cada tipo de documento de plataforma.
- **FR-005**: El sistema MUST exponer una consulta pública de solo lectura del documento vigente por tipo (contenido, número de versión y fecha de vigencia) que no requiera autenticación, limite el acceso entre dominios al dominio autorizado de la landing, aplique un límite razonable de frecuencia de solicitudes que prevenga abuso sin afectar el tráfico normal de la landing y del menú QR (el umbral numérico exacto se define en la fase de planificación), y permita el cacheo eficiente de la respuesta (incluyendo una marca de verificación de contenido que cambie cuando el contenido cambie).
- **FR-006**: El sistema MUST restringir todas las operaciones de creación, edición y publicación de documentos de plataforma y de la plantilla maestra al rol de super admin, y estas operaciones no deben estar disponibles desde el panel del tenant.
- **FR-007**: El sistema MUST permitir al super admin consultar el historial completo de versiones (incluyendo las superadas) de cada tipo de documento de plataforma.
- **FR-008**: El sistema MUST permitir al super admin editar y versionar una plantilla legal maestra que contenga únicamente variables de una lista cerrada predefinida (nombre del negocio, identificación legal, dirección legal, ciudad, correo de contacto, teléfono de contacto).
- **FR-009**: El sistema MUST validar, al guardar la plantilla maestra, que no contenga variables fuera de la lista cerrada permitida, y MUST rechazar el guardado señalando explícitamente cuáles variables no son válidas si las encuentra.
- **FR-010**: El sistema MUST versionar la plantilla maestra de forma que publicar una nueva versión no modifique ni invalide los documentos de tenant ya publicados ni las aceptaciones de clientes ya registradas sobre versiones anteriores.
- **FR-011**: El sistema MUST generar el texto final de cada documento de tenant mediante sustitución literal de texto de las variables permitidas sobre la plantilla, sin evaluar código ni expresiones, y MUST escapar el contenido sustituido para evitar que se interprete como marcado o código ejecutable.
- **FR-012**: El sistema MUST permitir que un administrador del tenant complete su perfil legal (razón social, identificación legal, dirección legal, ciudad, correo de contacto, teléfono de contacto), y MUST exigir que todos estos datos estén completos antes de permitir generar o publicar su documento legal.
- **FR-013**: El sistema MUST ofrecer una vista previa del documento renderizado con los datos del tenant antes de que este decida publicarlo.
- **FR-014**: El sistema MUST, al publicar un documento de tenant, guardar un snapshot inmutable que incluya el texto ya renderizado, la versión de plantilla utilizada, una huella de verificación del contenido y la fecha de publicación; el contenido mostrado a los clientes finales MUST provenir siempre de ese snapshot y nunca de una re-renderización posterior.
- **FR-015**: El sistema MUST notificar al tenant cuando exista una versión más reciente de la plantilla maestra que la usada en su documento publicado, mediante un aviso persistente (banner) en la sección de documentos legales del panel del tenant y un correo electrónico a la dirección de contacto del tenant en el momento en que se publica la nueva versión de la plantilla, sin regenerar ni republicar automáticamente el documento del tenant.
- **FR-016**: El sistema MUST impedir que un tenant sin ningún documento legal publicado active la función de captura de nombre en el menú QR.
- **FR-017**: El sistema MUST mostrar, en el flujo del menú QR de un tenant con documento publicado, un aviso breve con enlace al documento vigente del tenant junto con el campo de ingreso del nombre y la acción de continuar, indicando que confirmar implica la aceptación de los términos y el aviso de privacidad, sin requerir una casilla de confirmación explícita.
- **FR-018**: El sistema MUST, en una sola operación atómica, crear el registro del cliente final con el nombre ingresado y registrar la evidencia de aceptación asociada a ese mismo registro cuando el cliente confirma y continúa tras ver el aviso; la evidencia MUST incluir identificador del tenant, identificador del cliente (el registro recién creado), referencia al snapshot del documento aceptado, fecha y hora, y una huella no reversible de la dirección IP del cliente (la dirección IP en texto claro no debe almacenarse).
- **FR-019**: El sistema MUST bloquear el acceso al panel del administrador del tenant con un aviso que exija aceptar los documentos de plataforma vigentes, mostrado en el primer inicio de sesión y nuevamente cada vez que el super admin publique una nueva versión de la Política de Privacidad o los Términos y Condiciones de plataforma que el tenant aún no haya aceptado, hasta que el administrador del tenant acepte; el sistema MUST mantener este registro de aceptación (quién los aceptó y cuándo, y sobre qué versión) de forma separada a las aceptaciones de clientes finales.
- **FR-020**: El sistema MUST aislar completamente los datos legales, snapshots y evidencias de aceptación entre tenants, de forma que ningún tenant pueda consultar o verse afectado por los datos legales de otro.

### Key Entities

- **Documento legal de plataforma**: Representa una versión de la Política de Privacidad o de los Términos y Condiciones de la plataforma. Tiene tipo, número de versión, contenido en Markdown, estado (borrador/publicado/superado), fecha de vigencia y quién/cuándo lo publicó.
- **Plantilla legal maestra**: Representa una versión del texto base que usan los tenants para generar su propio documento legal, con variables de la lista cerrada permitida, número de versión, estado y fecha de vigencia.
- **Perfil legal del tenant**: Los datos propios de cada tenant (razón social, identificación legal, dirección, ciudad, contacto, días de retención) usados para rellenar la plantilla maestra.
- **Documento legal del tenant**: El resultado publicado y congelado (snapshot) del perfil legal del tenant combinado con una versión específica de la plantilla maestra; incluye el texto renderizado, la versión de plantilla usada, una huella de verificación del contenido y la fecha de publicación.
- **Aceptación de la plataforma por el tenant**: Evidencia de que un responsable del tenant aceptó los documentos legales vigentes de la plataforma, con fecha y hora.
- **Consentimiento del cliente final**: Evidencia de que un cliente final aceptó el documento legal vigente del tenant antes de que se capturara su nombre, con referencia al snapshot aceptado, fecha, hora y huella no reversible de su IP.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El super admin puede publicar una nueva versión vigente de cualquier documento de plataforma o de la plantilla maestra en menos de 5 minutos desde el panel, sin intervención técnica.
- **SC-002**: El 100% de las versiones publicadas de documentos de plataforma, plantilla maestra y documentos de tenant permanecen inalterables después de su publicación; cualquier cambio posterior queda siempre como una nueva versión identificable y consultable en el historial.
- **SC-003**: El 100% de los intentos de guardar una plantilla con variables fuera de la lista permitida son rechazados, indicando con precisión cuáles variables causaron el rechazo.
- **SC-004**: El 100% de las aceptaciones de clientes finales registradas conservan evidencia suficiente (tenant, cliente, documento exacto aceptado, fecha/hora, huella de IP) para sustentar una auditoría o reclamo legal posterior.
- **SC-005**: Ningún tenant puede activar la captura de nombre en su menú QR sin tener un documento legal propio publicado; esta restricción se cumple en el 100% de los casos verificados.
- **SC-006**: La landing y el menú QR siempre muestran el documento legal vigente (nunca uno superado o en borrador) en el 100% de las consultas realizadas tras una publicación.
- **SC-007**: Cuando el super admin publica una nueva versión de la plantilla maestra, el 100% de los documentos de tenant ya publicados permanecen sin cambios hasta que el propio tenant decide regenerarlos y publicarlos de nuevo.

## Assumptions

- "Super admin" es un rol único a nivel de plataforma, distinto y con mayor alcance que el rol de administrador de un tenant; ya existe en el sistema un mecanismo de roles que permite distinguirlo (ver gestión global de usuarios de super admin ya implementada).
- El "dominio de la landing" autorizado para consumir el endpoint público de documentos de plataforma es un valor configurable conocido por el equipo de plataforma; no se definen aquí los dominios concretos.
- Los datos personales de un cliente final capturados en el menú QR se limitan al nombre en el alcance de esta funcionalidad; cualquier otro dato personal queda fuera de alcance.
- La huella no reversible de la dirección IP se calcula de forma que no permita recuperar la IP original, pero sí permita comparar si dos aceptaciones provienen de la misma dirección si fuera necesario para una investigación.
- La revisión legal del contenido de la primera versión de los documentos de plataforma y de la plantilla maestra por parte de un abogado es un paso de proceso previo a la publicación en producción, y no una validación que el sistema deba imponer automáticamente.
- Quedan fuera de alcance de esta funcionalidad: la edición del texto de la plantilla por parte del tenant (solo puede rellenar variables), soporte multi-idioma, firma electrónica, y el ejercicio de derechos de acceso/rectificación/supresión de datos personales (se tratará en una funcionalidad separada).
