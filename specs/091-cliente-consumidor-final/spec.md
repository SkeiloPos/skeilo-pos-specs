# Feature Specification: Cliente "Consumidor final" por defecto en Mesa y Para llevar

**Feature Branch**: `091-cliente-consumidor-final`

**Created**: 2026-10-01

**Status**: Implemented

**Input**: User description: "Como personal del tenant que registra pedidos en la Terminal de
mesas, quiero que el campo \"Cliente\" aparezca precargado con \"Consumidor final\" y que pueda
editarlo, para crear pedidos de mesa y para llevar más rápido sin pedirle el nombre a cada
cliente. Situación actual: el campo \"Cliente\" de \"Nueva orden\" aparece vacío con el placeholder
\"Ej: Juan Pérez\". En horas pico, el cajero pierde tiempo escribiendo un nombre que a veces no
importa. [alcance, reglas de negocio y 10 escenarios de aceptación, ver Clarifications y
secciones siguientes]"

## Contexto y relación con specs anteriores

La spec [087 — Fix caja, mesas, menú y ventas](../087-fix-caja-mesas-menu-ventas/spec.md) convirtió
el nombre del cliente en **obligatorio** para crear cualquier pedido nuevo, incluidos Mesa
(`DINE_IN`) y Para llevar (`TAKEAWAY`) — antes de esa spec, esos dos tipos sí autocompletaban
"Consumidor final" y lo dejaban editable; spec 087 retiró ese autocompletado y bloqueó "Crear
pedido" sin un nombre escrito a mano, igual que ya exigía Domicilio (`DELIVERY`). Esa decisión
quedó registrada como **A-88** en
[`registro-de-anomalias.md`](../000-reconocimiento/registro-de-anomalias.md): "identificar al
cliente por su nombre real... mejora la operación en mesa/para llevar".

Esta spec **reabre parcialmente A-88**: para Mesa y Para llevar, vuelve a precargar "Consumidor
final" y deja de bloquear la creación del pedido por falta de nombre (el valor por defecto lo
reemplaza). Domicilio **no cambia**: sigue exigiendo un nombre real, dirección y valor del
domicilio, exactamente como A-88 lo dejó. El pedido del negocio, documentado como motivo de esta
spec, es que en horas pico pedir un nombre real para una mesa o un pedido para llevar frena la
operación más de lo que aporta valor; identificar al cliente real sigue importando para
Domicilio, donde sí hace falta para la entrega. Por tratarse de una reversión parcial de una
decisión de negocio ya registrada, esta spec exige una nueva entrada en
`registro-de-anomalias.md` (próximo número libre tras la última entrada registrada) antes de
implementar, según el Principio II de la Constitución.

Esta spec **no toca** el menú QR (`channel QR_MENU`): ahí el comensal ya escribe su propio nombre
al unirse a la mesa (`SessionParticipant.display_name`, obligatorio desde ese flujo), por lo que
nunca llega vacío a la creación del pedido y esta funcionalidad no tiene ningún efecto práctico
sobre ese canal.

## Clarifications

Ninguna pendiente: el pedido original ya trae alcance, reglas de negocio y 10 escenarios de
aceptación completos y sin ambigüedad relevante. Las dos decisiones de menor impacto que no
especificaba (qué pasa si el cajero escribe literalmente "Consumidor final" a mano, y si el
campo selecciona su texto completo también con un nombre personalizado) se resolvieron con
valores por defecto razonables, documentados en Assumptions.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Crear un pedido de Mesa o Para llevar sin escribir el nombre (Priority: P1)

El cajero abre "Nueva orden" en la Terminal de mesas. En las pestañas "Mesa" y "Para llevar", el
campo "Cliente" ya trae escrito "Consumidor final". Si el pedido es genérico, el cajero arma el
carrito y presiona "Crear pedido" sin tocar ese campo; el pedido queda creado con el cliente
"Consumidor final".

**Why this priority**: es el pedido central — el cajero deja de perder tiempo escribiendo un
nombre que la mayoría de las veces no importa, en el momento de mayor presión (horas pico).

**Independent Test**: abrir "Nueva orden", seleccionar "Mesa", agregar un producto al carrito sin
tocar el campo "Cliente", y crear el pedido; verificar que el pedido queda registrado con el
cliente "Consumidor final". Repetir para "Para llevar".

**Acceptance Scenarios**:

1. **Given** el cajero está en "Nueva orden" de la Terminal de mesas, **When** selecciona la
   pestaña "Mesa", **Then** el campo "Cliente" muestra "Consumidor final" como valor real (no
   como placeholder).
2. **Given** el cajero está en "Nueva orden" de la Terminal de mesas, **When** selecciona la
   pestaña "Para llevar", **Then** el campo "Cliente" muestra "Consumidor final".
3. **Given** el campo "Cliente" quedó vacío (el cajero borró su contenido) en una orden de Mesa o
   Para llevar, **When** presiona "Crear pedido", **Then** el pedido se guarda con el cliente
   "Consumidor final".
4. **Given** se crea un pedido de Mesa o Para llevar desde la Terminal sin nombre de cliente en la
   petición, **When** el backend lo procesa, **Then** guarda el pedido con el cliente "Consumidor
   final", y un pedido de Domicilio sin nombre mantiene su validación actual (se rechaza).

---

### User Story 2 - Reemplazar el valor por defecto con el nombre real del cliente (Priority: P1)

El cajero quiere identificar a un cliente real (por ejemplo, para un pedido para llevar que alguien
reclamará por su nombre). Hace clic en el campo "Cliente" — que muestra "Consumidor final" — y
escribe el nombre; el texto por defecto se reemplaza por completo y el pedido se crea con el
nombre escrito.

**Why this priority**: sin esto, la funcionalidad quitaría la posibilidad de capturar un nombre
real cuando sí importa (p. ej. varios pedidos para llevar esperando en el mostrador a la vez) —
tiene la misma prioridad que la historia 1 porque ambas deben cumplirse para que el cambio sea
seguro.

**Independent Test**: en "Nueva orden", pestaña "Mesa" o "Para llevar", hacer clic en el campo
"Cliente" (que muestra "Consumidor final"), escribir "María Pérez" y crear el pedido; verificar
que el campo no concatenó ni dejó restos del valor anterior y que el pedido quedó con el cliente
"María Pérez".

**Acceptance Scenarios**:

1. **Given** el campo "Cliente" muestra "Consumidor final", **When** el cajero hace clic en el
   campo, **Then** el texto queda seleccionado por completo.
2. **Given** el texto está seleccionado por completo, **When** el cajero escribe "María Pérez",
   **Then** reemplaza el valor por defecto (no lo antecede ni lo deja como resto).
3. **Given** el campo "Cliente" muestra "María Pérez", **When** el cajero presiona "Crear pedido",
   **Then** el pedido se guarda con el cliente "María Pérez".

---

### User Story 3 - El valor por defecto no se filtra a Domicilio ni se pierde un nombre real al cambiar de pestaña (Priority: P2)

El cajero cambia entre las pestañas "Mesa", "Para llevar" y "Domicilio" mientras arma un pedido.
Si no había escrito ningún nombre (el campo seguía en "Consumidor final"), Domicilio lo recibe
vacío con su placeholder de siempre — nunca con "Consumidor final" escrito, porque ahí sí hace
falta un nombre real. Si ya había escrito un nombre propio, ese nombre se conserva sin importar a
qué pestaña cambie, y vuelve a ofrecerse "Consumidor final" en Mesa/Para llevar si el campo quedó
vacío al volver.

**Why this priority**: evita dos riesgos de la historia 1: que "Consumidor final" se cuele como
nombre real de una entrega a domicilio, y que cambiar de pestaña por error le borre al cajero un
nombre que ya había escrito. No bloquea la entrega del valor central (historias 1 y 2), pero sin
esto el cambio introduciría errores nuevos.

**Independent Test**: con el campo "Cliente" en su valor por defecto, cambiar a "Domicilio" y
verificar que queda vacío con su placeholder; escribir "Carlos Ruiz" en cualquier pestaña y
cambiar entre las tres, verificando que el nombre se conserva en todas; vaciar el campo en
Domicilio y volver a "Mesa" o "Para llevar", verificando que vuelve a mostrar "Consumidor final".

**Acceptance Scenarios**:

1. **Given** el cajero está en "Mesa" o "Para llevar" y no ha editado el campo "Cliente" (sigue en
   "Consumidor final"), **When** selecciona la pestaña "Domicilio", **Then** el campo "Cliente"
   queda vacío con su placeholder original, y las validaciones actuales de Domicilio no cambian.
2. **Given** el cajero escribió "Carlos Ruiz" en el campo "Cliente", **When** cambia entre las
   pestañas "Mesa", "Para llevar" o "Domicilio", **Then** el campo conserva "Carlos Ruiz" en las
   tres.
3. **Given** el cajero está en "Domicilio" con el campo "Cliente" vacío, **When** selecciona
   "Mesa" o "Para llevar", **Then** el campo "Cliente" vuelve a mostrar "Consumidor final".
4. **Given** el cajero creó un pedido con el cliente "María Pérez", **When** el formulario se
   reinicia para la siguiente orden de Mesa o Para llevar, **Then** el campo "Cliente" vuelve a
   mostrar "Consumidor final" (no conserva el nombre del pedido anterior).

---

### Edge Cases

- **Campo con solo espacios en blanco**: se trata igual que un campo vacío — el pedido se guarda
  con "Consumidor final" (misma regla que un campo totalmente vacío).
- **El cajero escribe literalmente "Consumidor final" a mano**: se guarda tal cual, sin ninguna
  marca que lo distinga del valor por defecto automático — mismo resultado final de cualquier
  forma, así que no hay ninguna diferencia observable que proteger.
- **El cajero reabre "Nueva orden" para una mesa que ya tiene un pedido activo con un cliente
  distinto**: este comportamiento no cambia — seguir mostrando el nombre de ese pedido ya
  existente no es parte de esta spec (la precarga de "Consumidor final" aplica al armar un pedido
  nuevo, no al mostrar uno ya creado).
- **Pedidos de Domicilio**: sin ningún cambio — siguen exigiendo nombre, dirección y valor del
  domicilio para crearse, tanto desde la Terminal como directamente contra el backend.
- **Pedidos ya existentes**: no se migran ni se modifican; se siguen mostrando en Órdenes y Ventas
  exactamente como quedaron guardados, tengan o no un nombre de cliente.
- **Canal menú QR**: fuera de alcance — el comensal ya aporta su propio nombre al unirse a la
  mesa, por lo que la petición de creación de su pedido nunca llega sin nombre.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Al abrir "Nueva orden" en la Terminal de mesas y mostrar la pestaña "Mesa" o "Para
  llevar", el sistema MUST precargar el campo "Cliente" con el valor "Consumidor final", mostrado
  como contenido real del campo (no como placeholder).
- **FR-002**: El campo "Cliente" MUST seguir siendo editable en las pestañas "Mesa" y "Para
  llevar": el cajero MUST poder reemplazar "Consumidor final" por cualquier otro nombre, y ese
  nombre MUST ser el que se guarde al crear el pedido.
- **FR-003**: Al enfocar el campo "Cliente" (clic o navegación por teclado) en las pestañas "Mesa"
  o "Para llevar", el sistema MUST seleccionar su contenido completo, de modo que escribir
  reemplace el valor existente en vez de insertarse en medio o al final.
- **FR-004**: Si, al presionar "Crear pedido" para una orden de Mesa o Para llevar, el campo
  "Cliente" está vacío o contiene solo espacios en blanco, el sistema MUST guardar el pedido con
  el cliente "Consumidor final", sin bloquear la creación ni exigir que el cajero escriba un
  nombre.
- **FR-005**: El sistema MUST NOT bloquear ni mostrar un error de "nombre obligatorio" para las
  pestañas "Mesa" o "Para llevar" por tener el campo "Cliente" vacío; esa validación se sustituye
  por el valor por defecto de FR-004.
- **FR-006**: Al crear un pedido de tipo Mesa o Para llevar desde la Terminal de mesas sin nombre
  de cliente en la petición (vacío, ausente o solo espacios), el sistema MUST guardarlo con el
  cliente "Consumidor final", sin rechazar la petición.
- **FR-007**: Un pedido de Domicilio sin nombre de cliente, sea desde la Terminal o directamente
  contra el sistema, MUST seguir rechazándose exactamente como hoy (A-88, spec 087): el valor por
  defecto de esta spec no aplica a Domicilio.
- **FR-008**: Mientras el campo "Cliente" conserve exactamente el valor por defecto "Consumidor
  final" sin que el cajero lo haya modificado, cambiar a la pestaña "Domicilio" MUST vaciar el
  campo y mostrar su placeholder original ("Ej: Juan Pérez"), en vez de llevarse "Consumidor
  final" a Domicilio.
- **FR-009**: Si el cajero escribió un nombre propio en el campo "Cliente" (distinto del valor por
  defecto), cambiar entre las pestañas "Mesa", "Para llevar" y "Domicilio" MUST conservar ese
  nombre sin alterarlo, en cualquier dirección de cambio.
- **FR-010**: Al volver a la pestaña "Mesa" o "Para llevar" con el campo "Cliente" vacío (por
  ejemplo, tras pasar por "Domicilio" sin escribir nada), el sistema MUST volver a mostrar
  "Consumidor final".
- **FR-011**: Después de crear un pedido de Mesa o Para llevar, al armar la siguiente orden de
  Mesa o Para llevar el campo "Cliente" MUST mostrar de nuevo "Consumidor final", sin conservar el
  nombre usado en el pedido recién creado.
- **FR-012**: Los pedidos creados antes de esta funcionalidad MUST seguir mostrándose en Órdenes y
  Ventas exactamente como están guardados hoy; esta spec MUST NOT incluir ninguna migración ni
  modificación de datos existentes.
- **FR-013**: Esta spec MUST NOT modificar ningún comportamiento del menú QR (`channel QR_MENU`,
  donde el comensal escribe su propio nombre al unirse a la mesa) ni del canal Domicilio.

### Key Entities

- **Pedido (Orden)**: incluye, entre otros datos, el nombre del cliente que se le asocia; esta
  spec cambia únicamente qué valor recibe ese nombre cuando el cajero no escribe ninguno, para
  pedidos de Mesa y Para llevar creados desde la Terminal de mesas.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100% de los pedidos de Mesa o Para llevar creados desde la Terminal sin que el
  cajero escriba un nombre quedan registrados con el cliente "Consumidor final", sin ningún
  rechazo ni mensaje de error por nombre faltante.
- **SC-002**: El 100% de los pedidos de Domicilio sin nombre de cliente se siguen rechazando,
  igual que antes de esta spec.
- **SC-003**: El cajero completa un pedido genérico de Mesa o Para llevar sin necesitar ninguna
  pulsación de teclado en el campo "Cliente".
- **SC-004**: El 100% de los nombres propios escritos por el cajero se conservan sin alteración al
  cambiar entre las pestañas Mesa, Para llevar y Domicilio, verificado en cualquier secuencia de
  cambios de pestaña antes de crear el pedido.
- **SC-005**: El 100% de los pedidos ya existentes antes de desplegar esta funcionalidad se siguen
  mostrando sin ningún cambio en Órdenes y Ventas.

## Assumptions

- Si el cajero escribe literalmente "Consumidor final" a mano en el campo, el sistema lo trata
  igual que el valor por defecto (incluida la posibilidad de que se vacíe al cambiar a Domicilio,
  edge case de bajísimo impacto): el resultado final guardado es el mismo texto en ambos casos, así
  que no hay ninguna diferencia que el cajero pueda notar.
- La selección completa del texto al enfocar el campo (FR-003) aplica siempre que el campo esté en
  las pestañas Mesa o Para llevar, tenga el valor por defecto o un nombre ya escrito — no solo
  cuando muestra "Consumidor final" — para mantener un único comportamiento simple y predecible del
  campo.
- El alcance de FR-006/FR-007 (comportamiento del backend) es la creación de pedidos desde la
  Terminal de mesas (canal del personal del tenant); el canal del menú QR no se ve afectado en la
  práctica porque el nombre del comensal ya es obligatorio antes de llegar a ese punto (ver
  Contexto); ningún otro canal de creación de pedidos cambia su comportamiento.
- No se requiere ninguna migración de datos: el cambio solo afecta pedidos creados desde que se
  despliegue esta funcionalidad en adelante.
- Esta spec requiere registrar una nueva decisión de negocio en `registro-de-anomalias.md` antes
  de implementar (Principio II de la Constitución), por reabrir parcialmente la decisión A-88 de
  la spec 087; se deja como tarea de la fase de planificación/tareas, no de esta especificación.
