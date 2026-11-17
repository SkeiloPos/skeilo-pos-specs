# Feature Specification: Gestión global de usuarios en el panel Super Admin

**Feature Branch**: `159-gestion-global-usuarios-super-admin`

**Created**: 2026-11-16

**Status**: Draft

**Input**: User description: "Rediseñar un módulo completo de gestión global de usuarios para el panel Super Admin de Skeilo (plataforma SaaS POS multi-tenant), usando como referencia visual `design/SkeiloPOS Super Admin - Usuarios.dc.html`. El Super Admin debe poder consultar, administrar y supervisar todos los usuarios registrados en la plataforma, sin importar el negocio al que pertenezcan: listado centralizado con indicadores, filtros y búsqueda; ficha individual con información general, actividad, seguridad y negocios asociados; administración (editar, cambiar rol, activar/reactivar, suspender con motivo, enviar recuperación de contraseña, revocar sesiones, eliminar/anonimizar); seguridad y control de acceso (accesos, intentos fallidos, sesiones); una sección de auditoría administrativa que distinga acciones de administradores de eventos automáticos del sistema; los estados Activo/Suspendido/Bloqueado/Pendiente de activación/Invitación pendiente/Sin actividad reciente; y conservando la navegación y módulos existentes del panel Super Admin (Tenants, Usuarios, Métodos de pago, Planes), incorporando la nueva sección de auditoría."

## Clarifications

### Session 2026-11-16

- Q: El archivo de diseño solo implementa "Anonimizar" (borra nombre/correo, conserva historial de ventas sin datos personales) y no incluye una acción de eliminación permanente. ¿La eliminación de cuentas significa únicamente anonimización, o debe incluir también un borrado permanente e irreversible? → A: Anonimizar + borrado permanente — además de anonimizar, se ofrece una acción separada de borrado físico e irreversible del usuario y sus datos, sujeta a políticas de retención legal.
- Q: El estado "Bloqueado por seguridad" se activa tras varios intentos fallidos de inicio de sesión consecutivos. ¿Esta spec debe definir y construir la lógica de conteo/bloqueo automático, o asume que ya existe en el sistema de autenticación? → A: Ya existe, solo se consulta — el conteo de intentos fallidos y el bloqueo automático son responsabilidad del sistema de autenticación existente; este módulo únicamente consulta y muestra ese estado e historial, y permite desbloquear manualmente.
- Q: FR-031/SC-008 listan seis estados distinguibles visualmente (Activo, Suspendido, Bloqueado por seguridad, Pendiente de activación, Invitación pendiente, Sin actividad reciente) pero no incluyen "Anonimizado", aunque Key Entities sí lo define como estado posible. ¿"Anonimizado" debe tratarse formalmente como un estado más de esa lista? → A: Es un estado más — se agrega "Anonimizado" a la lista formal de estados distinguibles visualmente en FR-031 y SC-008, igual que los otros seis.
- Q: ¿Cuál es la diferencia entre los estados "Pendiente de activación" e "Invitación pendiente"? → A: Invitado a negocio vs. creado directo — "Invitación pendiente" aplica a un usuario invitado a un negocio (tenant) que aún no ha aceptado la invitación; "Pendiente de activación" aplica a una cuenta ya existente (p. ej. creada directamente) cuyo usuario aún no confirma su correo ni establece contraseña.
- Q: FR-036 no incluye "negocio (tenant)" como criterio de filtro de auditoría, aunque cada registro lo muestra (FR-034). ¿Debe agregarse como filtro combinable? → A: Sí, agregar filtro por negocio — se agrega "negocio (tenant)" a FR-036 como un criterio de filtro combinable más, igual que usuario, administrador, tipo de acción y fecha.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Consultar el listado centralizado de usuarios de toda la plataforma (Priority: P1)

El Super Admin abre el módulo de Usuarios y necesita ver, en una sola vista, a todas las personas registradas en Skeilo —sin importar a qué negocio pertenecen—, con su nombre, correo, rol, negocio(s) asociado(s), plan, estado y último acceso, para poder ubicar rápidamente a cualquier usuario y entender su situación general.

**Why this priority**: Es la base de todo el módulo. Sin un listado centralizado, confiable y navegable, ninguna otra capacidad (ficha de detalle, administración, auditoría) tiene desde dónde partir. Es también el valor que el negocio pidió primero: control centralizado sobre cuentas de toda la plataforma.

**Independent Test**: Puede probarse abriendo el módulo de Usuarios con datos sembrados de varios negocios y roles, y verificando que la tabla muestra correctamente nombre, correo, rol, negocio, plan, estado y último acceso de cada usuario, que la búsqueda por nombre/correo/negocio filtra la lista en tiempo real, que los filtros por estado/rol/plan/fecha de registro se combinan correctamente, que las columnas ordenables cambian el orden al hacer clic, que la paginación navega entre páginas, y que los usuarios sin negocio o con varios negocios se identifican visualmente sin necesidad de abrir su ficha.

**Acceptance Scenarios**:

1. **Given** que el Super Admin abre el módulo de Usuarios, **When** la lista termina de cargar, **Then** se muestra una tabla con todos los usuarios registrados en la plataforma (de cualquier negocio), cada fila mostrando nombre, correo, rol, negocio asociado, plan, estado y último acceso.
2. **Given** un usuario que pertenece a más de un negocio, **When** el Super Admin ve su fila en la tabla, **Then** se identifica visualmente que tiene múltiples negocios asociados (p. ej. un indicador de "+N"), sin necesidad de abrir su ficha para saberlo.
3. **Given** un usuario sin ningún negocio asignado, **When** el Super Admin ve su fila en la tabla, **Then** la columna de negocio/plan indica claramente la ausencia de negocio asociado, en vez de mostrarse vacía o con un error.
4. **Given** que el Super Admin escribe un término en el buscador, **When** el término coincide con el nombre, correo o negocio de uno o más usuarios, **Then** la tabla se actualiza mostrando únicamente los usuarios que coinciden, sin recargar la página completa.
5. **Given** que el Super Admin aplica uno o más filtros (estado, rol, plan, fecha de registro), **When** los filtros se combinan con una búsqueda activa, **Then** la tabla muestra solo los usuarios que cumplen todos los criterios aplicados simultáneamente, y el Super Admin puede limpiar todos los filtros con una sola acción.
6. **Given** que el Super Admin hace clic en el encabezado de una columna ordenable, **When** la tabla se reordena, **Then** el orden (ascendente/descendente) se refleja visualmente en el encabezado y los resultados se reordenan en consecuencia, manteniendo los filtros y la búsqueda activos.
7. **Given** una lista con más usuarios de los que caben en una página, **When** el Super Admin navega entre páginas, **Then** la tabla muestra el subconjunto correspondiente y conserva los filtros, la búsqueda y el orden activos.

---

### User Story 2 - Consultar los indicadores generales de usuarios de la plataforma (Priority: P1)

El Super Admin necesita ver, de un vistazo y sin tener que contar manualmente, cuántos usuarios hay en total, cuántos están activos, cuántos suspendidos y cuántos se registraron durante el mes en curso, para evaluar rápidamente la salud general de la base de usuarios de la plataforma.

**Why this priority**: Los indicadores dan contexto inmediato antes de interactuar con el listado detallado; es un requisito explícito del negocio y de bajo costo de implementación relativo a su valor, por lo que se entrega junto con el listado como parte del mismo MVP.

**Independent Test**: Puede probarse cargando el módulo con un conjunto de usuarios de distintos estados y fechas de registro, y verificando que los cuatro indicadores (total, activos, suspendidos, nuevos del mes) reflejan los conteos correctos y se actualizan si cambian los datos subyacentes (p. ej. tras suspender un usuario).

**Acceptance Scenarios**:

1. **Given** que el Super Admin abre el módulo de Usuarios, **When** los indicadores terminan de cargar, **Then** se muestran cuatro valores resumidos: total de usuarios, usuarios activos, usuarios suspendidos y nuevos usuarios registrados en el mes en curso.
2. **Given** que el Super Admin suspende o reactiva un usuario desde el módulo, **When** la acción se completa, **Then** los indicadores de activos/suspendidos reflejan el cambio sin requerir que el Super Admin recargue manualmente la página.

---

### User Story 3 - Consultar la ficha individual de un usuario (Priority: P1)

El Super Admin necesita abrir la ficha de un usuario específico y revisar, organizada en secciones, su información general, su historial de actividad, su situación de seguridad (sesiones, dispositivos, intentos fallidos) y los negocios a los que pertenece junto con el rol que desempeña en cada uno, para entender completamente la situación de esa persona en la plataforma antes de tomar cualquier decisión administrativa sobre ella.

**Why this priority**: Es el segundo pilar del módulo: sin la ficha de detalle, el Super Admin no tiene suficiente contexto para administrar con responsabilidad a un usuario (no puede, por ejemplo, decidir si suspenderlo sin ver antes su actividad reciente). Depende de que exista el listado (User Story 1) para llegar hasta ella.

**Independent Test**: Puede probarse abriendo la ficha de un usuario desde el listado y navegando entre sus pestañas (información general, actividad, seguridad, negocios asociados), verificando que cada sección muestra los datos correctos y específicos de ese usuario, incluyendo el caso de un usuario con varios negocios y roles distintos en cada uno.

**Acceptance Scenarios**:

1. **Given** que el Super Admin hace clic en un usuario del listado, **When** la ficha se abre, **Then** se muestra la sección de información general con sus datos personales, correo, fecha de registro, estado actual y último acceso.
2. **Given** que el Super Admin cambia a la pestaña de Actividad de la ficha, **When** la sección carga, **Then** se muestra un historial cronológico de acciones y eventos relevantes del usuario (p. ej. inicios de sesión, cambios de contraseña, cambios administrativos realizados sobre él), del más reciente al más antiguo.
3. **Given** que el Super Admin cambia a la pestaña de Seguridad de la ficha, **When** la sección carga, **Then** se muestran sus sesiones activas (con dispositivo, navegador e IP), un resumen de intentos fallidos de acceso recientes, y un control para revocar todas sus sesiones activas.
4. **Given** un usuario que pertenece a varios negocios con roles distintos en cada uno, **When** el Super Admin abre la pestaña de Negocios asociados, **Then** se listan todos los negocios (tenants) a los que pertenece, mostrando para cada uno el nombre del negocio, el plan contratado por ese negocio y el rol específico que el usuario desempeña en él.
5. **Given** un usuario sin ningún negocio asociado, **When** el Super Admin abre la pestaña de Negocios asociados, **Then** se muestra un estado vacío explicando la ausencia de negocio y ofreciendo la acción para asignarle uno.
6. **Given** un usuario sin sesiones activas, **When** el Super Admin abre la pestaña de Seguridad, **Then** se muestra un estado vacío indicando que no hay sesiones activas, y el control de revocar sesiones aparece deshabilitado.

---

### User Story 4 - Administrar el estado y los datos de un usuario (Priority: P2)

El Super Admin necesita poder modificar la información de un usuario, cambiar su rol, suspenderlo indicando un motivo, reactivarlo o activarlo manualmente, enviarle una solicitud de recuperación de contraseña, y revocar todas sus sesiones activas —todo con las confirmaciones adecuadas para evitar errores en operaciones sensibles—, para poder responder a incidentes y solicitudes de soporte sin depender de otro sistema.

**Why this priority**: Es el núcleo de la capacidad de "administración" pedida por el negocio, pero depende de que existan el listado y la ficha de detalle (User Stories 1 y 3) para ubicar y entender al usuario antes de actuar sobre él. Se prioriza después de la consulta porque sin poder ver no hay nada que decidir con criterio, pero antes que la eliminación/anonimización por ser las acciones de uso más frecuente.

**Independent Test**: Puede probarse editando el rol de un usuario, suspendiéndolo con un motivo obligatorio, reactivándolo, enviándole una recuperación de contraseña y revocando sus sesiones desde la ficha o desde el listado, verificando en cada caso que aparece una confirmación antes de ejecutar la acción, que el estado del usuario se refleja de inmediato, y que la acción queda registrada en su historial de actividad.

**Acceptance Scenarios**:

1. **Given** que el Super Admin abre la edición de un usuario, **When** modifica su rol y guarda los cambios, **Then** el nuevo rol se refleja de inmediato en el listado y en la ficha, y la acción queda registrada como un cambio administrativo en el historial del usuario.
2. **Given** que el Super Admin elige suspender a un usuario activo, **When** se le solicita indicar un motivo de suspensión, **Then** el sistema exige seleccionar o escribir un motivo antes de poder confirmar la suspensión, y permite opcionalmente cerrar de inmediato sus sesiones activas como parte de la misma acción.
3. **Given** un usuario suspendido, bloqueado o pendiente de activación, **When** el Super Admin elige reactivarlo o activarlo manualmente, **Then** el usuario recupera el estado Activo y puede volver a iniciar sesión, y la acción queda registrada en su historial.
4. **Given** que el Super Admin elige enviar una recuperación de contraseña a un usuario, **When** confirma la acción, **Then** el sistema dispara el envío de la solicitud de recuperación y confirma al Super Admin que fue enviada, dejando constancia en el historial del usuario.
5. **Given** un usuario con una o más sesiones activas, **When** el Super Admin confirma la revocación de todas sus sesiones, **Then** todas sus sesiones activas se cierran de inmediato, el usuario deberá iniciar sesión nuevamente, y la acción queda registrada en su historial.
6. **Given** que el Super Admin intenta suspender, revocar sesiones o anonimizar/eliminar un usuario, **When** inicia la acción, **Then** el sistema le presenta una confirmación explícita (incluyendo, para la eliminación/anonimización, escribir un dato de verificación como el correo del usuario) antes de ejecutarla, evitando que una acción sensible se dispare por error.
7. **Given** que el Super Admin consulta el historial de cambios de un usuario, **When** abre su pestaña de actividad, **Then** puede ver quién realizó cada cambio administrativo sobre ese usuario y cuándo, además de los eventos propios del usuario.

---

### User Story 5 - Anonimizar o eliminar permanentemente la cuenta de un usuario (Priority: P3)

El Super Admin necesita, cuando corresponda (por ejemplo, una solicitud de derecho al olvido o el cierre definitivo de una cuenta), anonimizar los datos personales de un usuario conservando su historial transaccional sin datos identificables, o bien eliminar permanentemente su registro y datos asociados cuando la política de retención lo permita, con las confirmaciones y controles adecuados dado el carácter irreversible de ambas acciones.

**Why this priority**: Es una capacidad necesaria para cumplir políticas de datos y cerrar casos de soporte, pero de uso mucho menos frecuente que las acciones de la User Story 4, y de mayor riesgo (irreversibilidad), por lo que se prioriza al final y se entrega con el mayor nivel de fricción deliberada (confirmaciones) de todo el módulo.

**Independent Test**: Puede probarse eligiendo anonimizar un usuario de prueba y verificando que se exige escribir su correo como confirmación antes de ejecutar, que tras confirmar su nombre y correo quedan anonimizados pero su historial de ventas permanece sin datos personales, y por separado probando la eliminación permanente verificando que exige una confirmación equivalente y que, tras ejecutarse, el usuario deja de existir como registro administrable en el listado.

**Acceptance Scenarios**:

1. **Given** que el Super Admin elige anonimizar a un usuario, **When** escribe el correo del usuario como confirmación y confirma la acción, **Then** el nombre y correo del usuario se reemplazan de forma irreversible por datos anonimizados, su acceso a la plataforma queda cerrado, su historial transaccional se conserva sin datos personales identificables, y la acción queda registrada en la auditoría administrativa.
2. **Given** que el Super Admin elige eliminar permanentemente a un usuario, **When** la política de retención de ese usuario lo permite y confirma la acción con el control de verificación requerido, **Then** el registro del usuario y sus datos personales asociados se eliminan de forma permanente e irreversible del sistema, y la acción queda registrada en la auditoría administrativa (incluyendo quién la ejecutó y cuándo) de forma independiente al registro eliminado.
3. **Given** que el Super Admin intenta eliminar permanentemente a un usuario cuyos datos deben conservarse por una obligación de retención vigente (p. ej. registros transaccionales o fiscales todavía requeridos), **When** inicia la acción, **Then** el sistema le impide completar el borrado permanente y le explica el motivo, ofreciendo la anonimización como alternativa disponible.
4. **Given** un usuario ya anonimizado, **When** el Super Admin lo ve en el listado o intenta abrir su ficha, **Then** el usuario se identifica claramente como anonimizado y las acciones administrativas que ya no aplican (editar datos personales, restablecer contraseña, etc.) quedan deshabilitadas o no se ofrecen.

---

### User Story 6 - Supervisar los últimos accesos, intentos fallidos y sesiones de seguridad (Priority: P2)

El Super Admin necesita, desde la ficha de un usuario, consultar sus últimos accesos, ver un resumen de intentos fallidos de autenticación recientes, revisar sus sesiones activas con su dispositivo/IP, y revocarlas si es necesario, para responder a incidentes de seguridad o solicitudes de soporte relacionadas con el acceso de ese usuario.

**Why this priority**: Es parte central del valor de "supervisar" pedido por el negocio y depende de la ficha de usuario (User Story 3), pero se separa como historia propia porque agrupa específicamente las capacidades de seguridad que pueden evolucionar de forma independiente del resto de la administración (por ejemplo, si se conecta más adelante con un sistema de autenticación más sofisticado).

**Independent Test**: Puede probarse abriendo la pestaña de Seguridad de varios usuarios con distinta cantidad de sesiones activas e intentos fallidos recientes, verificando que la información mostrada coincide con los datos esperados y que la revocación de sesiones funciona de forma aislada a cualquier otra acción administrativa.

**Acceptance Scenarios**:

1. **Given** un usuario con intentos fallidos de autenticación recientes, **When** el Super Admin abre su pestaña de Seguridad, **Then** se muestra un resumen con la cantidad de intentos fallidos recientes, de forma consistente con el estado "Bloqueado por seguridad" cuando el sistema de autenticación ya haya bloqueado la cuenta por esa causa.
2. **Given** un usuario bloqueado automáticamente por intentos fallidos, **When** el Super Admin revisa su ficha, **Then** el estado "Bloqueado por seguridad" es visible de forma clara y diferenciada de "Suspendido", y el Super Admin puede desbloquearlo manualmente (equivalente a reactivar su acceso).
3. **Given** que el Super Admin revoca todas las sesiones activas de un usuario desde la pestaña de Seguridad, **When** la acción se confirma, **Then** la lista de sesiones activas queda vacía de inmediato y el evento se agrega al historial de actividad del usuario y a la auditoría administrativa.

---

### User Story 7 - Consultar la auditoría administrativa de la plataforma (Priority: P2)

El Super Admin necesita una sección centralizada donde consultar todas las operaciones administrativas realizadas sobre los usuarios de la plataforma —quién las hizo, sobre qué usuario, en qué negocio, qué tipo de operación, cuándo y desde qué dirección IP—, diferenciando las acciones hechas por administradores de los eventos generados automáticamente por el sistema, para mantener trazabilidad y poder investigar incidentes.

**Why this priority**: Es un requisito explícito de cumplimiento y trazabilidad del negocio, y depende de que existan acciones administrativas que auditar (User Stories 4, 5 y 6), pero es independientemente valiosa y consultable incluso si se entrega en una iteración posterior a la administración básica.

**Independent Test**: Puede probarse realizando varias acciones administrativas (cambiar rol, suspender, revocar sesiones) y verificando que cada una aparece en la sección de auditoría con el administrador que la ejecutó, el usuario afectado, el negocio relacionado, el tipo de operación, la fecha/hora y la IP; y por separado, verificando que un evento generado automáticamente por el sistema (p. ej. un bloqueo por intentos fallidos) aparece diferenciado visualmente como originado por el sistema y no por un administrador.

**Acceptance Scenarios**:

1. **Given** que el Super Admin abre la sección de Auditoría y actividad, **When** la lista carga, **Then** se muestra un registro cronológico de operaciones administrativas, cada una indicando quién la realizó, el usuario afectado, el negocio (tenant) relacionado, el tipo de operación, la fecha y hora, y la dirección IP de origen.
2. **Given** un evento generado automáticamente por el sistema (sin intervención de un administrador), **When** aparece en la lista de auditoría, **Then** se distingue visualmente de las acciones realizadas por un administrador humano (p. ej. con una etiqueta o ícono de "Sistema" frente a "Administrador").
3. **Given** que el Super Admin filtra la auditoría por usuario, administrador, negocio (tenant), tipo de acción o un rango de fechas, **When** aplica uno o más filtros, **Then** la lista muestra únicamente los registros que cumplen los criterios seleccionados, combinables entre sí.
4. **Given** que el Super Admin hace clic en el usuario afectado de un registro de auditoría, **When** la acción se ejecuta, **Then** se abre la ficha de ese usuario, permitiendo pasar de la auditoría al detalle sin perder el contexto de la búsqueda.
5. **Given** una consulta de auditoría sin registros que coincidan con los filtros aplicados, **When** se muestran los resultados, **Then** aparece un estado vacío explicando que ningún registro coincide con esos filtros.

---

### User Story 8 - Navegar el módulo manteniendo la identidad y estructura actuales del panel Super Admin (Priority: P1)

El Super Admin necesita que el nuevo módulo de Usuarios (y la nueva sección de Auditoría) convivan de forma coherente con los módulos existentes del panel (Tenants, Métodos de pago, Planes), sin perder la navegación, identidad visual ni accesos que ya tenía.

**Why this priority**: Es una condición transversal del negocio ("mantener la estructura visual y navegación actual... conservando su identidad visual") y de alto riesgo si se rompe (bloquearía el acceso a módulos existentes); se entrega junto con el resto del MVP porque todas las demás historias dependen de que el layout del panel siga funcionando.

**Independent Test**: Puede probarse navegando entre Tenants, Usuarios, Métodos de pago, Planes y la nueva sección de Auditoría desde el sidebar del panel Super Admin, verificando que todos los módulos existentes siguen siendo accesibles sin cambios de comportamiento, y que el nuevo módulo de Usuarios y la sección de Auditoría se integran visualmente (misma tipografía, colores, estructura de sidebar/navbar) con el resto del panel.

**Acceptance Scenarios**:

1. **Given** que el Super Admin abre el panel, **When** revisa la navegación lateral, **Then** encuentra, sin cambios de comportamiento, los módulos existentes de Tenants, Usuarios, Métodos de pago y Planes, además de la nueva sección de Auditoría y actividad.
2. **Given** que el Super Admin navega del módulo de Usuarios a cualquier otro módulo existente del panel, **When** la nueva vista carga, **Then** la estructura general (sidebar, navbar, identidad visual) se mantiene consistente, sin discontinuidad perceptible respecto al resto del panel.

---

### Edge Cases

- ¿Qué pasa si el Super Admin intenta suspender, bloquear, anonimizar o eliminar a otro Super Admin? El sistema debe impedir dejar la plataforma sin ningún Super Admin activo con esa acción, y advertir al Super Admin ejecutante de esa condición antes de permitir continuar (si existe más de un Super Admin activo, la acción se permite).
- ¿Qué pasa si el Super Admin intenta revocar sus propias sesiones activas mientras está usando una de ellas? El sistema debe advertirle explícitamente que su propia sesión actual también será cerrada antes de confirmar.
- ¿Qué pasa si el estado de un usuario cambia (p. ej. queda bloqueado automáticamente por intentos fallidos) mientras el Super Admin tiene su ficha abierta? El sistema debe reflejar el nuevo estado la próxima vez que el Super Admin interactúe con la ficha o la refresque, sin dejar visible un estado desactualizado como base para una decisión administrativa.
- ¿Qué pasa si el listado o la ficha de un usuario fallan al cargar (error de red o del servidor)? El sistema debe mostrar un estado de error claro con una opción de reintentar, sin dejar al Super Admin ante una pantalla en blanco o un error técnico críptico.
- ¿Qué pasa si una búsqueda o combinación de filtros no produce ningún resultado? El sistema debe distinguir este caso ("sin resultados de búsqueda/filtros") del caso en que la plataforma aún no tiene ningún usuario registrado ("sin datos"), con un mensaje y una acción apropiados para cada uno.
- ¿Qué pasa con un usuario cuyo último acceso ocurrió hace mucho tiempo pero cuyo estado sigue siendo "Activo"? El sistema debe señalarlo como "Sin actividad reciente" de forma visible en el listado y en su ficha, sin cambiar automáticamente su estado formal.
- ¿Qué pasa si el Super Admin intenta anonimizar o eliminar un usuario que todavía tiene sesiones activas? El sistema debe cerrar automáticamente cualquier sesión activa como parte de la misma operación, para que el usuario no pueda seguir operando tras ser anonimizado o eliminado.
- ¿Qué pasa si un usuario pertenece a un negocio (tenant) que a su vez fue suspendido o dado de baja? La ficha del usuario debe reflejar el estado real de ese negocio en la pestaña de Negocios asociados, sin ocultar la membresía ni mostrarla como si el negocio estuviera activo.
- ¿Qué pasa si el Super Admin intenta eliminar permanentemente a un usuario con una obligación de retención vigente? La acción debe bloquearse con una explicación del motivo, ofreciendo la anonimización como alternativa (ver User Story 5, Acceptance Scenario 3).
- ¿Qué pasa si dos Super Admin intentan modificar al mismo usuario (p. ej. cambiar su rol) casi al mismo tiempo? El sistema debe aplicar el último cambio confirmado y reflejarlo correctamente, sin dejar el registro del usuario en un estado inconsistente.

## Requirements *(mandatory)*

### Functional Requirements

**Listado y consulta**

- **FR-001**: El sistema DEBE mostrar un listado centralizado de todos los usuarios registrados en la plataforma, sin importar a qué negocio (tenant) pertenezcan.
- **FR-002**: El sistema DEBE mostrar, para cada usuario del listado, su nombre, correo electrónico, rol, negocio(s) asociado(s), plan del negocio, estado y fecha/hora de último acceso.
- **FR-003**: El sistema DEBE identificar visualmente, para cada usuario, a qué negocio (tenant) pertenece, incluyendo un identificador único de ese negocio.
- **FR-004**: El sistema DEBE permitir buscar usuarios por coincidencia de texto en nombre, correo electrónico o nombre del negocio asociado.
- **FR-005**: El sistema DEBE permitir filtrar el listado por estado, rol, plan y rango de fecha de registro, de forma combinable entre sí y con la búsqueda por texto.
- **FR-006**: El sistema DEBE permitir ordenar el listado por las columnas que tengan sentido de orden (p. ej. nombre, último acceso, fecha de registro) y paginar los resultados cuando excedan el tamaño de una página.
- **FR-007**: El sistema DEBE identificar visualmente a los usuarios que pertenecen a más de un negocio, y a los usuarios que no tienen ningún negocio asignado.

**Indicadores generales**

- **FR-008**: El sistema DEBE mostrar indicadores resumidos de: total de usuarios registrados en la plataforma, total de usuarios activos, total de usuarios suspendidos, y total de usuarios nuevos registrados durante el mes calendario en curso.
- **FR-009**: El sistema DEBE mantener los indicadores generales consistentes con el estado real de los usuarios tras cualquier acción administrativa que lo afecte (p. ej. suspender o reactivar).

**Ficha individual del usuario**

- **FR-010**: El sistema DEBE permitir abrir una ficha individual de cada usuario con, al menos, las secciones: información general, actividad, seguridad y negocios asociados.
- **FR-011**: La sección de información general DEBE mostrar los datos personales del usuario, su correo electrónico, su fecha de registro, su estado actual y su último acceso.
- **FR-012**: La sección de actividad DEBE mostrar un historial cronológico de acciones y eventos relevantes del usuario, incluyendo tanto eventos propios del usuario (inicios de sesión, cambios de contraseña) como cambios administrativos realizados sobre él, indicando quién los realizó.
- **FR-013**: La sección de seguridad DEBE mostrar las sesiones activas del usuario (dispositivo, navegador e IP), un resumen de intentos fallidos de acceso recientes, y un control para revocar todas sus sesiones activas.
- **FR-014**: La sección de negocios asociados DEBE listar todos los tenants a los que pertenece el usuario, mostrando para cada uno el nombre del negocio, el plan contratado por ese negocio y el rol específico que el usuario desempeña en él — reflejando que un mismo usuario puede pertenecer a varios negocios con roles distintos en cada uno.
- **FR-015**: El sistema DEBE mostrar un estado vacío apropiado en la sección de negocios asociados cuando el usuario no tenga ningún negocio asignado, y en la sección de seguridad cuando no tenga sesiones activas.

**Administración de usuarios**

- **FR-016**: El sistema DEBE permitir modificar la información editable de un usuario (p. ej. nombre, rol, negocio asociado cuando corresponda).
- **FR-017**: El sistema DEBE permitir cambiar el rol de un usuario, reflejando el cambio de inmediato en el listado y en su ficha, y registrándolo en su historial de actividad y en la auditoría administrativa.
- **FR-018**: El sistema DEBE permitir activar manualmente una cuenta pendiente de activación, y reactivar una cuenta suspendida o desbloquear una cuenta bloqueada por seguridad, devolviéndola al estado Activo.
- **FR-019**: El sistema DEBE permitir suspender a un usuario, exigiendo que el Super Admin indique un motivo de suspensión antes de poder confirmar la acción, y permitiendo opcionalmente cerrar sus sesiones activas como parte de la misma acción.
- **FR-020**: El sistema DEBE permitir consultar el historial de cambios administrativos realizados sobre un usuario (quién, qué cambió y cuándo), accesible desde su ficha.
- **FR-021**: El sistema DEBE permitir enviar una solicitud de recuperación de contraseña a un usuario, confirmando al Super Admin que la solicitud fue enviada y registrando la acción en el historial del usuario.
- **FR-022**: El sistema DEBE permitir revocar todas las sesiones activas de un usuario con una sola acción, cerrándolas de inmediato.
- **FR-023**: El sistema DEBE permitir anonimizar la cuenta de un usuario, reemplazando de forma irreversible sus datos personales identificables (nombre, correo) por datos anonimizados, cerrando su acceso a la plataforma, y conservando su historial transaccional sin datos personales identificables.
- **FR-024**: El sistema DEBE permitir eliminar permanentemente la cuenta de un usuario y sus datos personales asociados, de forma irreversible, únicamente cuando no exista una obligación de retención vigente sobre ese usuario; si existe una obligación de retención, el sistema DEBE impedir el borrado permanente, explicar el motivo y ofrecer la anonimización como alternativa.
- **FR-025**: El sistema DEBE exigir una confirmación explícita antes de ejecutar cualquier operación sensible (suspender, revocar sesiones, anonimizar, eliminar permanentemente), y DEBE exigir adicionalmente que el Super Admin escriba un dato de verificación (p. ej. el correo del usuario) antes de confirmar la anonimización o la eliminación permanente.
- **FR-026**: El sistema DEBE impedir que una acción administrativa (suspender, bloquear, anonimizar o eliminar) deje a la plataforma sin ningún Super Admin activo, advirtiendo de esa condición antes de permitir continuar.
- **FR-027**: El sistema DEBE deshabilitar u ocultar, en la ficha de un usuario ya anonimizado o cuya cuenta ya no exista, las acciones administrativas que dejan de tener sentido sobre él (p. ej. editar datos personales, enviar recuperación de contraseña).

**Seguridad y control de acceso**

- **FR-028**: El sistema DEBE permitir consultar, para cada usuario, su historial de últimos accesos.
- **FR-029**: El sistema DEBE mostrar, para cada usuario, un resumen de sus intentos fallidos de autenticación recientes, consultando esa información del sistema de autenticación existente de la plataforma (este módulo no define ni calcula el umbral de bloqueo automático).
- **FR-030**: El sistema DEBE permitir consultar las sesiones activas de un usuario y revocarlas, de forma individual o en conjunto.
- **FR-031**: El sistema DEBE distinguir visualmente, tanto en el listado como en la ficha, los estados Activo, Suspendido, Bloqueado por seguridad, Pendiente de activación, Invitación pendiente, Sin actividad reciente y Anonimizado.
- **FR-032**: El sistema DEBE restringir el acceso a este módulo y a todas sus operaciones administrativas exclusivamente a usuarios con el rol de Super Admin de la plataforma.

**Auditoría administrativa**

- **FR-033**: El sistema DEBE proveer una sección de auditoría y actividad que centralice el registro de las operaciones administrativas realizadas sobre los usuarios de la plataforma.
- **FR-034**: Cada registro de auditoría DEBE indicar quién realizó la acción (administrador o sistema), el usuario afectado, el negocio (tenant) relacionado cuando aplique, el tipo de operación realizada, la fecha y hora, y la dirección IP de origen cuando la acción provenga de un administrador.
- **FR-035**: El sistema DEBE diferenciar visualmente, en el registro de auditoría, las acciones realizadas por un administrador humano de los eventos generados automáticamente por el sistema.
- **FR-036**: El sistema DEBE permitir filtrar el registro de auditoría por usuario afectado, administrador, negocio (tenant), tipo de acción y rango de fechas, de forma combinable.
- **FR-037**: El sistema DEBE permitir navegar desde un registro de auditoría hasta la ficha del usuario afectado por esa operación.
- **FR-038**: El sistema DEBE registrar en la auditoría administrativa toda acción de anonimización o eliminación permanente de un usuario, incluyendo quién la ejecutó y cuándo, de forma independiente al registro del usuario (de modo que el registro de auditoría sobreviva a la eliminación del usuario al que hace referencia).

**Estados y experiencia de usuario**

- **FR-039**: El sistema DEBE mostrar un estado de carga (placeholders) mientras el listado, la ficha de un usuario o la auditoría están obteniendo datos.
- **FR-040**: El sistema DEBE mostrar un estado de error con opción de reintentar cuando el listado, la ficha de un usuario o la auditoría no puedan cargarse.
- **FR-041**: El sistema DEBE distinguir, en el listado y en la auditoría, el caso de "aún no hay usuarios/registros" (plataforma sin datos) del caso de "sin resultados" (búsqueda o filtros sin coincidencias), mostrando un mensaje y una acción apropiados para cada uno.

**Navegación e integración**

- **FR-042**: El sistema DEBE mantener accesibles, sin cambios de comportamiento, los módulos existentes del panel Super Admin: Tenants, Métodos de pago y Planes.
- **FR-043**: El sistema DEBE incorporar la nueva sección de Auditoría y actividad a la navegación del panel Super Admin, junto a los módulos existentes.
- **FR-044**: El sistema DEBE presentar el módulo de Usuarios y la sección de Auditoría con la misma estructura visual, navegación (sidebar/navbar) e identidad visual que el resto del panel Super Admin.

### Key Entities

- **Usuario de plataforma**: Persona registrada en Skeilo que puede iniciar sesión; tiene nombre, correo electrónico, fecha de registro, estado (Activo, Suspendido, Bloqueado por seguridad, Pendiente de activación, Invitación pendiente, Anonimizado), fecha de último acceso, y puede pertenecer a cero, uno o varios negocios (tenants) a la vez. "Invitación pendiente" aplica cuando el usuario fue invitado a un negocio y aún no acepta esa invitación; "Pendiente de activación" aplica cuando la cuenta ya existe (p. ej. creada directamente) pero el usuario aún no confirma su correo ni establece contraseña.
- **Membresía de negocio**: Relación entre un usuario y un negocio (tenant) específico; incluye el rol que el usuario desempeña en ese negocio y la fecha desde la que pertenece a él. Un mismo usuario puede tener varias membresías, cada una con un rol distinto.
- **Negocio (tenant)**: Empresa registrada en la plataforma; tiene un identificador único, un nombre, un plan de suscripción contratado y un estado propio (independiente del estado de sus usuarios).
- **Sesión activa**: Instancia de acceso vigente de un usuario; incluye dispositivo, navegador e IP de origen, y puede revocarse individualmente o en conjunto.
- **Intento fallido de autenticación**: Evento registrado por el sistema de autenticación cuando un intento de inicio de sesión no es exitoso; este módulo consulta y muestra ese resumen, sin definir la lógica de conteo o bloqueo.
- **Evento de actividad**: Entrada del historial cronológico de un usuario (p. ej. inicio de sesión, cambio de contraseña, cambio administrativo), con fecha/hora y, cuando aplica, quién lo originó.
- **Registro de auditoría administrativa**: Entrada que documenta una operación administrativa realizada sobre un usuario de la plataforma; incluye quién la realizó (administrador o sistema), el usuario afectado, el negocio relacionado, el tipo de operación, la fecha/hora y la IP de origen; persiste de forma independiente al usuario al que hace referencia.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El Super Admin puede localizar cualquier usuario específico de la plataforma (por nombre, correo o negocio) en menos de 10 segundos desde que abre el módulo de Usuarios.
- **SC-002**: El 100% de los usuarios mostrados en el listado exhiben correctamente su nombre, correo, rol, negocio(s), plan, estado y último acceso, verificable contra los datos de origen.
- **SC-003**: El 100% de los usuarios con más de un negocio asociado, y el 100% de los usuarios sin negocio asignado, se identifican visualmente en el listado sin necesidad de abrir su ficha.
- **SC-004**: El Super Admin puede completar una operación administrativa sensible (suspender, revocar sesiones, anonimizar o eliminar) de principio a fin, incluyendo su confirmación, en menos de 1 minuto.
- **SC-005**: El 100% de las operaciones administrativas sensibles ejecutadas quedan reflejadas en la auditoría administrativa, consultables por usuario, administrador, acción y período.
- **SC-006**: El 100% de las acciones generadas automáticamente por el sistema se distinguen visualmente, sin ambigüedad, de las acciones realizadas por un administrador humano en la auditoría.
- **SC-007**: El 0% de las acciones administrativas sensibles se ejecutan sin una confirmación previa del Super Admin.
- **SC-008**: El 100% de los estados definidos (Activo, Suspendido, Bloqueado por seguridad, Pendiente de activación, Invitación pendiente, Sin actividad reciente, Anonimizado) se distinguen visualmente entre sí en el listado y en la ficha del usuario.
- **SC-009**: El 100% de los módulos existentes del panel Super Admin (Tenants, Métodos de pago, Planes) permanecen accesibles y funcionalmente sin cambios tras incorporar el nuevo módulo de Usuarios y la sección de Auditoría.
- **SC-010**: El listado de usuarios, la ficha de detalle y la auditoría administrativa responden de forma utilizable (listos para interacción o mostrando un estado de carga claro) en menos de 2 segundos bajo condiciones normales de red, incluso con cientos de negocios y miles de usuarios registrados.
- **SC-011**: El 100% de las búsquedas o combinaciones de filtros sin coincidencias muestran un estado de "sin resultados" distinto del estado de "sin datos" de la plataforma.

## Assumptions

- El archivo de diseño `design/SkeiloPOS Super Admin - Usuarios.dc.html` es la fuente de verdad visual y de interacción de referencia para este módulo (estructura de listado, indicadores, filtros, ficha con pestañas, modales de edición/suspensión/revocación/anonimización, y sección de auditoría), adaptada a la base tecnológica real del panel.
- Este módulo es exclusivo del panel aislado de Super Admin/plataforma (spec 091); no forma parte del panel de Administrador de Tenant/Cajero/Staff cubierto por la spec 116, que lo excluye explícitamente de su alcance.
- Los módulos existentes de Tenants (negocios, con su plan — spec 033) y Métodos de pago (spec 032) ya proveen la información de negocio y plan que este módulo consume para mostrarla en el listado y en la ficha de usuario; esta spec no redefine esos módulos, solo los referencia.
- La detección y el conteo de intentos fallidos de autenticación, así como el disparo automático del estado "Bloqueado por seguridad", son responsabilidad del sistema de autenticación existente de la plataforma; este módulo únicamente consulta y presenta esa información, y ofrece el desbloqueo manual como acción administrativa.
- "Nuevos usuarios registrados durante el mes" se calcula sobre el mes calendario en curso (desde el día 1 hasta la fecha actual), según la zona horaria de la plataforma.
- La eliminación permanente de un usuario está sujeta a las políticas de retención de información que ya aplican a otros datos de la plataforma (p. ej. registros transaccionales o fiscales); cuando una obligación de retención impide el borrado físico, la anonimización queda disponible como alternativa que sí puede ejecutarse de inmediato.
- Los registros de auditoría administrativa se conservan de forma indefinida y de forma independiente a los usuarios a los que hacen referencia, de modo que la eliminación permanente de un usuario no elimina el rastro de las operaciones realizadas sobre él.
- Las acciones de "Crear usuario" e invitación de un nuevo usuario a un negocio, visibles en el diseño de referencia, se consideran parte de la gestión ya existente de usuarios por negocio y se conservan en este módulo global como punto de entrada adicional, sin redefinir el flujo de invitación/alta ya establecido en la plataforma (spec 037).
- El envío de la solicitud de recuperación de contraseña reutiliza el mecanismo de correo transaccional ya existente en la plataforma (spec 096), sin requerir un nuevo canal de comunicación.
