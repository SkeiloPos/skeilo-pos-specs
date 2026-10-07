# Feature Specification: Carga agregada (bootstrap) del panel de staff al iniciar sesión

**Feature Branch**: `100-bootstrap-dashboard-staff`

**Created**: 2026-10-07

**Status**: Draft

**Input**: User description: "Optimizar el tiempo de carga percibido (Performance / UX) del panel
de staff al iniciar sesión, reduciendo la cantidad de viajes de ida y vuelta (round-trips) al
servidor. Actualmente, el inicio dispara múltiples peticiones HTTP en paralelo (`tenant`, `plan`,
`notifications`), penalizando fuertemente la experiencia en conexiones lentas o inestables.
Prioridad: P2. Usuarios: el Usuario de Tenant (Staff/Administrador) requiere que el panel esté
operativo lo más rápido posible tras el login; el Super Admin inicia sesión sin depender de un
tenant y no debe sufrir bloqueos si los datos de negocio no aplican. Requisitos técnicos citados en
el ticket original: nuevo endpoint agregador `GET /bootstrap` (o similar) que retorne
`{ tenant, plan, notifications }`; refactor de `DashboardLayoutComponent.ngOnInit`
(`dashboard-layout.component.ts:124-131`) y de `notification-center.service.ts` (`:71-88`) para
consumirlo; las rutas individuales de tenant, plan y notificaciones deben seguir existiendo
intactas para refrescos puntuales (p. ej. tras editar en Ajustes); el ticket de tiempo
real/WebSockets (`POST /realtime/ticket`) queda excluido del agregador por ser de un solo uso y
pedirse justo antes de abrir la conexión. Reglas de negocio: si el endpoint de arranque falla, el
panel debe degradarse con los valores por defecto actuales (esquema vacío) sin dejar de ser
usable; la agregación no debe fallar cuando el usuario autenticado es Super Admin sin `tenant` ni
`plan`, debiendo devolver esos nodos en null/vacío."

## Clarifications

### Session 2026-10-07

- Q: Cuando `/bootstrap` falla por completo (timeout, 500, caída de red), ¿qué debe hacer el
  panel? → A: Mostrar únicamente los valores por defecto actuales (esquema vacío), sin reintentar
  automáticamente las peticiones individuales de tenant/plan/notifications dentro de esa misma
  carga.
- Q: Si una sola fuente interna del arranque (p. ej. notificaciones) falla pero las otras dos
  responden bien, ¿el agregador debe degradarse de forma granular o fallar por completo? → A:
  Degradación parcial granular — el agregador responde 200 con los bloques disponibles completos y
  deja en null/vacío únicamente el bloque que falló.
- Q: ¿Qué debe incluir el bloque de notificaciones dentro del payload del arranque? → A: La misma
  lista de notificaciones recientes que hoy entrega la primera carga de notificaciones al iniciar
  sesión, no solo un conteo de no leídas.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Arranque del panel en una sola petición para staff y administradores de un tenant (Priority: P1)

Un miembro del staff o un administrador de un tenant inicia sesión y entra al panel. Hoy el panel
dispara tres peticiones independientes (negocio, plan, notificaciones) en paralelo para poder
pintarse; con esta funcionalidad, esa misma información llega mediante una única petición al
servidor, reduciendo los viajes de ida y vuelta necesarios para que el panel quede operativo,
especialmente notorio en conexiones lentas o inestables.

**Por qué esta prioridad**: es el escenario que vive el 100% de los inicios de sesión del panel y
el que concentra el beneficio de performance que motiva todo el ticket; sin esto no hay
funcionalidad que entregar.

**Prueba independiente**: puede probarse iniciando sesión como staff/administrador de un tenant,
revisando el panel de red del navegador y confirmando que la información de negocio, plan y
notificaciones recientes llega en una sola petición HTTP en vez de en tres o cuatro llamadas
independientes, y que el panel se pinta igual de completo que hoy.

**Acceptance Scenarios**:

1. **Given** un usuario de staff/administrador con credenciales válidas de un tenant, **When**
   inicia sesión y entra al panel, **Then** el panel queda operativo con la información de
   negocio, plan y notificaciones recientes obtenida mediante una única petición HTTP al servidor.
2. **Given** que el panel ya inició exitosamente mediante la petición de arranque agregada,
   **When** el usuario abre "Ajustes" y edita un dato de negocio (o cualquier dato cubierto hoy por
   tenant/plan/notificaciones), **Then** el refresco de esos datos sigue haciéndose mediante la
   petición individual correspondiente (tenant, plan o notificaciones), sin pasar de nuevo por el
   arranque.
3. **Given** que el panel inició exitosamente mediante la petición de arranque agregada, **When**
   el sistema necesita abrir la conexión de eventos en tiempo real del staff, **Then** el ticket de
   tiempo real se sigue pidiendo como una petición individual y de un solo uso, justo antes de
   abrir esa conexión, y el panel sigue recibiendo avisos en vivo con normalidad.

---

### User Story 2 - Arranque sin fallos para Super Admin sin tenant ni plan asignados (Priority: P2)

Un Super Admin inicia sesión en el panel de administración global, un rol que no tiene un tenant ni
un plan de suscripción asociados. El arranque agregado debe completarse con éxito para este rol tal
como hoy lo hacen, cada una por su lado, las peticiones individuales de negocio y plan cuando se
usan con un Super Admin.

**Por qué esta prioridad**: sin esta garantía, la optimización de performance para el staff de
tenant rompería el acceso de un rol que ya usa el mismo panel hoy; es una condición de no regresión
tan importante como el beneficio principal, pero acotada a un solo rol.

**Prueba independiente**: puede probarse iniciando sesión como Super Admin y confirmando que el
panel carga sin error, sin pantalla en blanco ni bloqueo, con los bloques de negocio y plan vacíos.

**Acceptance Scenarios**:

1. **Given** un Super Admin autenticado sin `tenant` ni `plan` asignados, **When** el endpoint de
   arranque resuelve la petición, **Then** la respuesta es exitosa (HTTP 200) con los bloques de
   negocio y plan en null/vacío, y el panel termina de cargar sin caerse.

---

### User Story 3 - Continuidad del panel cuando el arranque falla total o parcialmente (Priority: P2)

Si la petición de arranque falla por completo (por ejemplo, una caída temporal de red) o si solo
una de sus tres fuentes internas falla mientras las otras responden bien, el panel debe seguir
siendo usable: no se bloquea ni deja al usuario sin interfaz, y aprovecha toda la información que sí
llegó a tiempo.

**Por qué esta prioridad**: la resiliencia ante fallos de red es una condición explícita del
ticket (hoy, si una de las tres peticiones individuales falla, el panel sigue siendo usable con esa
parte en su valor por defecto); agregar las tres peticiones en una no puede empeorar esa tolerancia
a fallos.

**Prueba independiente**: puede probarse simulando la caída completa del endpoint de arranque y, en
otro caso, simulando que solo una de sus tres fuentes internas falla, confirmando en ambos casos
que el panel permanece usable.

**Acceptance Scenarios**:

1. **Given** que la petición de arranque falla por completo (error de red, tiempo de espera
   agotado o error del servidor), **When** el panel termina de cargar, **Then** el panel sigue
   siendo usable mostrando los mismos valores por defecto actuales (esquema vacío) que usa hoy,
   sin quedar bloqueado ni reintentar automáticamente las peticiones individuales dentro de esa
   misma carga.
2. **Given** que, dentro del arranque, únicamente una de las tres fuentes internas (negocio, plan o
   notificaciones) falla mientras las otras dos responden correctamente, **When** el endpoint de
   arranque resuelve la petición, **Then** la respuesta es exitosa (HTTP 200) con los bloques que sí
   respondieron completos, y únicamente el bloque que falló queda en null/vacío.

---

### Edge Cases

- Si el usuario recarga la página inmediatamente después de un arranque fallido, el panel vuelve a
  intentar el arranque agregado desde cero en esa nueva carga (no se retiene ningún estado de
  reintento entre cargas de página).
- Si dos o las tres fuentes internas del arranque fallan a la vez, cada bloque se evalúa de forma
  independiente: los que respondieron se entregan completos y los que fallaron quedan en
  null/vacío, sin que el fallo de una fuente provoque el fallo de las demás ni el de la petición
  completa.
- Un fallo total o parcial del arranque no afecta el flujo del ticket de tiempo real: al no
  depender del payload del arranque, ese ticket se sigue pidiendo de forma individual justo antes
  de abrir la conexión en vivo, sin importar si el arranque tuvo éxito, se degradó parcialmente o
  falló del todo.
- Esta funcionalidad no cambia qué datos contiene cada bloque (negocio, plan, notificaciones) ni
  sus reglas de negocio propias; solo cambia cuántas peticiones hacen falta para obtenerlos al
  iniciar sesión.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema DEBE exponer un único punto de entrada de arranque que, en una sola
  petición HTTP, entregue la información de negocio (tenant), plan de suscripción y notificaciones
  recientes necesarias para pintar el panel de staff al iniciar sesión.
- **FR-002**: El panel de staff DEBE obtener esa información a través del punto de entrada de
  arranque al iniciar sesión, en lugar de lanzar las peticiones de negocio, plan y notificaciones
  por separado.
- **FR-003**: Las peticiones individuales de negocio, plan y notificaciones DEBEN seguir existiendo
  y funcionando sin cambios para refrescos puntuales posteriores al arranque (por ejemplo, después
  de editar datos en "Ajustes").
- **FR-004**: El flujo para solicitar el ticket de conexión en tiempo real DEBE seguir siendo una
  petición individual y de un solo uso, solicitada justo antes de abrir la conexión en vivo, y NO
  DEBE incluirse dentro del arranque agregado.
- **FR-005**: Si el arranque falla por completo (error de red, tiempo de espera agotado o error del
  servidor), el panel DEBE seguir siendo usable mostrando los mismos valores por defecto actuales
  (esquema vacío) que usa hoy, sin reintentar automáticamente las peticiones individuales dentro de
  esa misma carga.
- **FR-006**: Si únicamente una de las tres fuentes internas del arranque falla mientras las otras
  responden correctamente, el arranque DEBE responder exitosamente entregando completos los
  bloques que sí respondieron y dejando en null/vacío únicamente el bloque que falló.
- **FR-007**: Cuando el usuario autenticado es Super Admin (sin `tenant` ni `plan` asignados), el
  arranque DEBE responder exitosamente (HTTP 200) con los bloques de negocio, plan y notificaciones
  en null/vacío (este último porque es una fuente igualmente dependiente del tenant, ver
  Assumptions), sin provocar una caída en la carga del panel.
- **FR-008**: El bloque de notificaciones del arranque DEBE incluir la misma lista de
  notificaciones recientes que hoy entrega la primera carga de notificaciones al iniciar sesión, no
  únicamente un conteo de no leídas.
- **FR-009**: El panel DEBE seguir recibiendo avisos en tiempo real con normalidad después de un
  arranque exitoso, parcialmente degradado o fallido mediante el punto de entrada agregado.

### Key Entities

- **Arranque del panel (bootstrap)**: agrupación, calculada en el momento de la petición, de tres
  bloques independientes entre sí — negocio (tenant), plan de suscripción y notificaciones
  recientes — que hoy se obtienen por separado. No introduce datos nuevos ni persistentes: es una
  forma de entregar en una sola respuesta datos que ya existen y que conservan su propio contenido
  y reglas de negocio.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El número de peticiones HTTP necesarias para obtener la información de negocio, plan
  y notificaciones recientes al iniciar sesión en el panel se reduce de tres (o más) a una.
- **SC-002**: El panel permanece usable (sin pantalla en blanco ni bloqueo) en el 100% de los casos
  en que el arranque agregado falla por completo o se degrada parcialmente.
- **SC-003**: El 100% de los inicios de sesión de Super Admin sin tenant ni plan asignados
  completan la carga del panel sin error.
- **SC-004**: El 100% de los refrescos puntuales de negocio, plan o notificaciones realizados fuera
  del arranque (por ejemplo, tras editar en "Ajustes") siguen funcionando sin cambios perceptibles
  para el usuario.

## Assumptions

- El punto de entrada de arranque reutiliza el mismo mecanismo de autenticación/sesión que ya
  protege hoy las peticiones individuales de negocio, plan y notificaciones; esta spec no introduce
  un esquema de autenticación nuevo.
- El arranque consulta datos frescos en el momento de la petición; no se asume ningún cacheo
  adicional más allá del que ya pudiera existir hoy en las fuentes individuales.
- Para Super Admin, el bloque de notificaciones del arranque conserva el mismo comportamiento que
  tiene hoy la carga individual de notificaciones para ese rol; el ticket original no describe un
  cambio ahí, solo lo hace explícito para los bloques de negocio y plan.
- El contenido y el formato de cada bloque (negocio, plan, notificaciones) dentro del arranque es
  equivalente al que hoy entregan sus peticiones individuales; esta spec cambia cuántas peticiones
  hacen falta para obtenerlos al iniciar sesión, no qué información contiene cada uno.
- El nombre exacto de la ruta del nuevo punto de entrada y los detalles de su contrato técnico
  (forma exacta del payload, códigos de error, etc.) se definen en la fase de planeación técnica;
  esta spec solo exige que exista un único punto de entrada agregador con el comportamiento aquí
  descrito.
