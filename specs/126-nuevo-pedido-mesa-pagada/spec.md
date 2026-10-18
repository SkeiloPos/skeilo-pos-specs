# Feature Specification: Nuevo Pedido en Mesa con Cuenta Pagada

**Feature Branch**: `126-nuevo-pedido-mesa-pagada`

**Created**: 2026-10-17

**Status**: Draft

**Input**: User description: "Como cajero, quiero iniciar un nuevo pedido desde una mesa cuya
cuenta ya está pagada, para atender una segunda ronda sin liberar la mesa ni perder el pedido que
sigue en cocina. Ya está definido que una mesa puede recibir varios pedidos durante una misma
visita; esta historia lo habilita desde la Terminal de Mesas. 'Nuevo pedido' solo está disponible
si todos los pedidos de la mesa están pagados o anulados, y no hay saldos pendientes. El nuevo
pedido es independiente: tiene su propia cuenta, su propio pago y su propia factura. El pedido
anterior sigue su flujo en cocina sin cambios. 'Liberar Mesa' cierra la sesión de la mesa
completa."

**Naturaleza de esta spec**: investigación directa del código actual (`pos-heladeria`) durante la
primera sesión de `/speckit-clarify` encontró que la capacidad de "iniciar un segundo pedido en
paralelo sobre una mesa ya ocupada" **ya existe y ya está implementada**, a través del CTA "+
Crear pedido nuevo" (`table-sessions.component.ts`, barra superior; rama "Pedido de mostrador" de
`pos-checkout-panel.component.ts`), resuelto por `store.newOrderTableId()`
(`pos-terminal.store.ts:793`) — mismo mecanismo documentado en la spec
[087](../087-fix-caja-mesas-menu-ventas/spec.md) (Clarifications, FR-007), que **a propósito** lo
dejó disponible sin ninguna restricción de estado de cobro: "incluso si la mesa ya tiene un
pedido abierto [sin pagar]".

Esa primera sesión de clarificación concluyó, de forma provisional, que esta spec debía
**restringir** esa capacidad agregando una condición de "sin saldo pendiente" — registrado como
decisión de negocio
[A-137](../000-reconocimiento/registro-de-anomalias.md#a-137--decisión-de-negocio--spec-126-crear-pedido-nuevo-deja-de-estar-disponible-para-una-mesa-con-saldo-pendiente-cerrando-la-brecha-abierta-por-spec-087).
Una **segunda sesión de `/speckit-clarify`**, el mismo día, trajo un conjunto más amplio de
reglas de negocio para todo el dominio mesa/pedido/cuenta/pago — cuya Regla 1/3 contradecía
directamente A-137 (permitir crear un pedido nuevo aunque existan pedidos pendientes de pago, en
vez de bloquearlo). Preguntado explícitamente, el dueño del proyecto **revirtió A-137** mediante
[A-138](../000-reconocimiento/registro-de-anomalias.md#a-138--decisión-de-negocio--spec-126-se-revierte-a-137-crear-pedido-nuevo-vuelve-a-estar-disponible-con-saldo-pendiente):
"+ Crear pedido nuevo" **vuelve a estar disponible sin ninguna condición de saldo**, exactamente
como lo dejó spec 087 — la mesa puede acumular varias cuentas sin resolver en paralelo, cada una
independiente y sin fusionarse automáticamente. La única salvaguarda de integridad financiera es
la ya existente desde antes de A-137: "Liberar Mesa" sigue bloqueada mientras exista algo por
cobrar (`has_billable_orders`/`has_pending_balance`, spec 123, Historia 5) — eso no cambia. Se
confirmó además que **no** se introduce ninguna acción de "consolidar cuentas": cada pedido se
cobra por separado, sin fusionar facturas ni pagos ya registrados (ver Clarifications).

Esta spec queda, por tanto, como el lugar donde se **formaliza y documenta explícitamente** el
modelo de mesa/pedido/cuenta/pago que ya rige el sistema (multi-pedido sin bloqueo, saldos
independientes, cobro por separado sin consolidación, liberación como único punto de control),
más las reglas que la segunda sesión de clarificación todavía está resolviendo (procedimiento de
excepción para liberar con saldo, invariantes de concurrencia) — ver Clarifications para el
estado de cada una. `plan.md`/`tasks.md`, generados contra la versión anterior (A-137), quedan
desactualizados y requieren un nuevo `/speckit-plan` una vez cerrada esta clarificación.

## Clarifications

### Session 2026-10-17

- Q: ¿"Nuevo pedido" debe navegar a la pantalla de creación de orden manual ya existente (con la
  mesa preseleccionada), o debe abrir el pedido vacío directamente dentro del panel de la cuenta
  de la Terminal de Mesas, sin salir de esa pantalla? → A: Navega a la pantalla de creación de
  orden manual ya existente (spec 045/052), con la Mesa 1 preseleccionada; "volver a la vista de
  mesas" es el botón "← Volver a la Terminal" de esa pantalla.
- Q: ¿Cuándo debe quedar persistido en el backend el pedido vacío que abre "Nuevo pedido": de
  inmediato al seleccionar la acción, o solo cuando el cajero agrega el primer producto? → A: Nada
  se persiste en el backend hasta que el cajero agregue el primer producto; "pedido vacío" es solo
  un estado local del formulario de creación de orden manual (carrito en memoria, igual que el
  patrón ya usado antes de "Confirmar y Enviar" en spec 052), nunca llega a existir como registro.
- Q: Hoy "+ Crear pedido nuevo" (`newOrderTableId()`) ya permite un segundo pedido en paralelo
  sobre una mesa con un pedido abierto sin pagar (spec 087, FR-007, decisión intencional). Esta
  spec pide bloquear "Nuevo pedido" precisamente en ese caso (saldo pendiente). ¿Cómo deben
  convivir ambas reglas? → A: Se unifica el criterio — el CTA existente pasa a exigir también "sin
  saldo pendiente" para mesas, cerrando la brecha que permitía dos cuentas abiertas sin pagar
  sobre la misma mesa. Se registra como cambio de comportamiento de spec 087 (Principio II,
  A-137).

### Session 2026-10-17 (segunda sesión — revisión del dominio completo mesa/pedido/cuenta/pago)

- Q: La spec 126 ya decidió (A-137) bloquear "+ Crear pedido nuevo" mientras haya saldo
  pendiente. Las Reglas 1 y 3 de la revisión de dominio dicen lo contrario: permitir crear un
  pedido nuevo aunque existan pedidos pendientes de pago, manteniendo cada cuenta independiente
  sin fusionar. ¿Cuál de las dos reglas debe regir? → A: Se revierte A-137
  ([A-138](../000-reconocimiento/registro-de-anomalias.md#a-138--decisión-de-negocio--spec-126-se-revierte-a-137-crear-pedido-nuevo-vuelve-a-estar-disponible-con-saldo-pendiente)):
  "+ Crear pedido nuevo" vuelve a estar disponible sin ninguna condición de saldo (comportamiento
  original de spec 087); la mesa puede tener varias cuentas sin resolver en paralelo, cada una
  independiente; la única salvaguarda sigue siendo el bloqueo de "Liberar Mesa" con saldo
  pendiente (spec 123, sin cambios).
- Q: ¿Se necesita que el cajero pueda consolidar explícitamente varias cuentas de la misma mesa
  (ya pagadas y/o pendientes) en un solo cobro o una sola factura, o basta con que cada una se
  cobre por separado como ya funciona hoy? → A: No se introduce consolidación explícita. Cada
  pedido/cuenta se cobra por separado, sin ningún mecanismo de fusión; evita alterar
  retroactivamente facturas o pagos ya registrados (Principio VII).
- Q: Cuando el cajero no puede cobrar un saldo pendiente y necesita liberar la mesa igual
  (cliente se fue sin pagar, error irrecuperable), ¿el procedimiento autorizado es anular el
  pedido sin pagar (ya existe hoy), o se necesita un mecanismo nuevo de liberación forzada que
  preserve el saldo como pérdida registrada? → A: Anular el pedido sin pagar es el procedimiento
  autorizado y suficiente; no se agrega ningún mecanismo de liberación forzada ni de registro de
  pérdida — es una decisión ya cubierta por la capacidad de anulación existente
  (`cancel_order`).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Iniciar una segunda ronda en una mesa ya pagada (Priority: P1)

El cajero atiende una mesa que ya pagó su pedido (por ejemplo, porque los comensales pidieron la
cuenta antes del postre, o porque pagaron por adelantado). Los comensales siguen en la mesa y
piden algo más. Desde la Terminal de Mesas, el cajero usa "+ Crear pedido nuevo" y el sistema
navega a la pantalla de creación de orden manual ya existente (spec 045/052) con la Mesa 1
preseleccionada y un pedido vacío listo para armar, sin tocar el pedido anterior ni la sesión de
la mesa.

**Comportamiento ya existente**: esta ruta (mesa seleccionada → "+ Crear pedido nuevo" →
`manual-order-page.component.ts` con esa mesa preseleccionada, vía `newOrderTableId()`) **ya
funciona hoy** para cualquier mesa, pagada o no (spec 087). Esta historia no construye esa
navegación: la confirma y la documenta explícitamente como el comportamiento vigente (A-138) —
no hay ninguna restricción que añadir sobre este camino.

**Why this priority**: es el problema de negocio que motiva esta spec — atender una segunda
ronda sin liberar la mesa ni interferir con el pedido anterior. Tras A-138, este camino aplica
siempre, sin condición de saldo; la Historia 2 documenta cómo conviven varias cuentas sin
resolver en paralelo, en vez de bloquear este camino.

**Independent Test**: se puede probar completamente llevando un pedido de mesa al estado "Pagada",
usando "+ Crear pedido nuevo" con esa mesa seleccionada, y verificando que el sistema navega a la
pantalla de creación de orden manual con esa mesa preseleccionada, con el pedido anterior intacto y
visible en la Terminal de Mesas.

**Acceptance Scenarios**:

1. **Given** la Mesa 1 tiene un pedido pagado en estado "En preparación" (sin saldo pendiente),
   **When** el cajero selecciona la Mesa 1 y usa "+ Crear pedido nuevo", **Then** el sistema
   navega a la pantalla de creación de orden manual con la Mesa 1 preseleccionada y un pedido
   vacío listo para armar, el pedido anterior sigue visible en la Terminal de Mesas agrupado como
   "Pedido 1", y la cocina sigue mostrando el pedido anterior sin ningún cambio.
2. **Given** el nuevo pedido abierto sobre la Mesa 1, **When** el cajero agrega productos y lo
   cobra, **Then** ese cobro genera su propia factura, independiente de la factura ya emitida para
   el "Pedido 1", y ambos pedidos quedan identificados por separado en la mesa como pestañas
   "Pedido 1", "Pedido 2" (comportamiento ya existente, spec 087, FR-006/FR-009).
3. **Given** una mesa con dos pedidos previos, uno pagado y otro anulado, **When** el cajero
   selecciona esa mesa, **Then** "+ Crear pedido nuevo" está habilitado — como lo está siempre
   que haya al menos una mesa seleccionada o libre (A-138, sin condición de saldo).

---

### User Story 2 - Varias cuentas sin resolver conviven en la misma mesa, cada una independiente (Priority: P1)

**Tras A-138, esta es la historia central de la spec** (ver "Naturaleza de esta spec"): el
cajero puede abrir un segundo (o tercer, o N-ésimo) pedido sobre una mesa aunque exista un pedido
anterior sin pagar o con saldo pendiente — comportamiento intencional de spec 087, confirmado de
nuevo por A-138. Cada pedido conserva su propio saldo, su propio ciclo de cobro y su propia
factura; ninguno se fusiona, se recalcula ni se oculta por la existencia de otro sin resolver. El
cajero puede cobrar cada cuenta por separado, en el orden que prefiera.

**Why this priority**: es la regla de negocio central que define cómo coexisten varias rondas
sin resolver en la misma mesa — sin ella, Historia 1 por sí sola no explica qué pasa con los
saldos de los pedidos anteriores al crear uno nuevo.

**Independent Test**: se puede probar dejando un pedido de mesa con saldo pendiente (total o
parcial) o sin pagar, usando "+ Crear pedido nuevo" sobre esa misma mesa, y verificando que el
segundo pedido se crea sin tocar el saldo ni el estado del primero, y que ambos pueden cobrarse
por separado, cada uno con su propia factura.

**Acceptance Scenarios**:

1. **Given** la Mesa 1 tiene un pedido con saldo pendiente (`pending_balance > 0`) o sin pagar en
   absoluto, **When** el cajero la selecciona en la Terminal de Mesas, **Then** "+ Crear pedido
   nuevo" sigue habilitado para esa mesa (sin condición de saldo), y la acción "Cobrar saldo"/el
   cobro normal del pedido existente también sigue disponible para resolverlo cuando el cajero lo
   decida — ambas acciones conviven, sin que una excluya a la otra.
2. **Given** el cajero crea ese segundo pedido, **When** lo mira en la Terminal de Mesas,
   **Then** ambos pedidos quedan identificados por separado ("Pedido 1", "Pedido 2"), cada uno
   con su propio saldo/estado de cobro, sin que agregar el segundo modifique el saldo pendiente
   ni el estado del primero.
3. **Given** ambos pedidos sin resolver, **When** el cajero cobra cualquiera de los dos primero
   (en el orden que elija), **Then** ese cobro genera su propia factura y no afecta el saldo ni
   el estado del otro pedido, que sigue esperando su propio cobro.

---

### User Story 3 - Abandonar un pedido nuevo vacío (Priority: P3)

Si el cajero abre "+ Crear pedido nuevo" por error o cambia de intención antes de agregar ningún
producto, puede volver a la vista de mesas sin dejar ningún pedido ni registro colgando sobre la
mesa — el carrito vacío del formulario de creación de orden manual nunca llegó a persistirse en
el backend (ver Clarifications), así que no hay nada que limpiar ni borrar explícitamente.

**Comportamiento ya existente**: `manual-order-page.component.ts` ya arma el pedido como un
carrito en memoria (`draftLines()`) que solo se persiste al confirmar (`confirm()`); "←
Volver a la Terminal" (`backToTerminal()`) simplemente navega de vuelta sin ningún paso de
guardado. Esta historia no introduce ningún mecanismo de descarte nuevo: confirma que ese
comportamiento ya existente sigue aplicando igual para el caso nuevo habilitado por la Historia 1.

**Why this priority**: es la de menor riesgo de las tres — no depende de código nuevo, solo de
confirmar que el comportamiento ya existente de descarte de carritos vacíos sigue aplicando sin
cambios, sin importar cuántas cuentas sin resolver tenga ya la mesa (Historia 2).

**Independent Test**: se puede probar usando "+ Crear pedido nuevo" en cualquier mesa (pagada,
con saldo pendiente o sin pagar), sin agregar productos, volviendo a la vista de mesas, y
verificando que la mesa vuelve a mostrar únicamente sus pedidos previos, sin rastro del pedido
vacío.

**Acceptance Scenarios**:

1. **Given** el cajero abrió "+ Crear pedido nuevo" sobre la Mesa 1 y no agregó productos,
   **When** pulsa "← Volver a la Terminal", **Then** no se crea ningún registro de pedido en el
   backend y la Mesa 1 conserva exactamente los pedidos que tenía antes de abrir "+ Crear pedido
   nuevo" (pagados, con saldo pendiente o sin pagar, sin cambios).
2. **Given** el cajero agregó al menos un producto al carrito del nuevo pedido, **When** pulsa
   "← Volver a la Terminal" sin pulsar "Confirmar y Enviar", **Then** el comportamiento es el mismo
   ya existente para el formulario de creación de orden manual con productos sin confirmar (el
   carrito con productos no se persiste como pedido hasta confirmarse) — esta spec no modifica ese
   comportamiento ya vigente.

---

### Edge Cases

- **"Cobrar saldo"/el cobro normal y "+ Crear pedido nuevo" aparecen disponibles a la vez**: con
  la Mesa 1 seleccionada y con saldo pendiente o un pedido sin pagar, el cajero ve simultáneamente
  la acción de cobro de ese pedido (ya existente) y "+ Crear pedido nuevo" habilitado en la barra
  superior — esto es **intencional** tras A-138 (Historia 2): ambas acciones conviven, y el
  cajero decide en qué orden cobrar o seguir agregando rondas.
- **Todos los pedidos previos de la mesa están anulados (ninguno pagado)**: "+ Crear pedido
  nuevo" sigue disponible — como siempre, sin condición de saldo (A-138).
- **Pedido previo en "pago pendiente de confirmar"** (p. ej. canal QR aún no confirmado): no
  bloquea "+ Crear pedido nuevo" (A-138); esa cuenta sigue su propio tratamiento ya existente
  (bloque de "Pagos por confirmar") en paralelo a cualquier otro pedido que se cree.
- **El cajero abre "+ Crear pedido nuevo" sobre la Mesa 1, no agrega productos, y navega a otra
  pantalla distinta de "← Volver a la Terminal"** (p. ej. cierra sesión, cambia de pestaña, pierde
  conexión): como ningún registro llegó a crearse en el backend (ver Clarifications), la Mesa 1
  sigue mostrando únicamente sus pedidos ya resueltos, sin ninguna acción de limpieza adicional —
  no hay nada que descartar (comportamiento ya existente, sin cambios).
- **El cajero pulsa "Liberar Mesa" desde la Terminal mientras tiene abierto, en otra pestaña o
  ventana, un "+ Crear pedido nuevo" vacío sin confirmar sobre esa misma mesa**: la liberación de
  la mesa procede igual que hoy (ningún pedido real existe todavía); si luego el cajero intenta
  continuar armando ese carrito y confirmarlo, el sistema debe tratarlo como una mesa recién
  liberada (nueva sesión), no como la sesión anterior.
- **Tercer pedido o más sobre la misma mesa en la misma visita**: sin límite de cantidad — "+
  Crear pedido nuevo" está siempre disponible para una mesa seleccionada, sin importar cuántas
  cuentas sin resolver ya tenga (A-138).
- **"Liberar Mesa" con varias cuentas sin resolver acumuladas** (N pedidos, algunos pagados,
  algunos con saldo pendiente, alguno sin pagar): bloqueada mientras exista **cualquiera** sin
  resolver — regla ya existente (spec 123, Historia 5; `has_billable_orders`/
  `has_pending_balance`), sin cambios. El procedimiento autorizado para destrabarla sin cobrar es
  anular el/los pedidos sin pagar (`cancel_order`, ya existente); esta spec no agrega ningún
  mecanismo de liberación forzada ni de registro de pérdida (Clarifications).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001** [YA EXISTE, confirmado por A-138, sin cambios]: El sistema DEBE mantener habilitado
  "+ Crear pedido nuevo" (`newOrderTableId()`) para una mesa seleccionada **sin ninguna condición
  sobre el estado de cobro de sus pedidos existentes** — pagados, anulados, con saldo pendiente o
  sin pagar en absoluto. Confirma el comportamiento ya implementado por spec 087 (FR-007),
  revirtiendo la restricción que había propuesto la primera sesión de clarificación de esta spec
  (A-137, revertida por A-138).
- **FR-002** [YA EXISTE, confirmado por A-138, sin cambios]: El sistema NO DEBE fusionar,
  recalcular ni ocultar el saldo pendiente o el estado de cobro de un pedido existente al crear
  un nuevo pedido sobre la misma mesa; cada pedido mantiene su propia cuenta, saldo y estado de
  forma independiente, y puede cobrarse en cualquier orden.
- **FR-003** [YA EXISTE, sin cambios]: Al usar "+ Crear pedido nuevo" con una mesa habilitada, el
  sistema navega a la pantalla de creación de orden manual ya existente (spec 045/052,
  `manual-order-page.component.ts`), con la mesa preseleccionada y un pedido vacío listo para
  armar, sin modificar el estado, los ítems ni el flujo de cocina de ningún pedido anterior de esa
  mesa.
- **FR-004** [YA EXISTE, sin cambios]: El nuevo pedido es independiente de los pedidos anteriores
  de la mesa: su propio ciclo de cobro, su propio pago y su propia factura, sin compartir ni
  recalcular montos con pedidos previos.
- **FR-005** [YA EXISTE, sin cambios]: La Terminal de Mesas muestra cada pedido activo de la mesa
  identificado por separado (pestañas "Pedido 1", "Pedido 2", …, spec 087 FR-006/FR-009) junto con
  su propio estado, para que el cajero distinga entre rondas sin ambigüedad; el formato visual
  exacto (etiqueta combinada vs. pestaña + estado por tarjeta) es el que ya existe hoy (spec 049),
  sin cambios de esta spec.
- **FR-006** [YA EXISTE, sin cambios]: La cocina sigue mostrando cualquier pedido anterior de la
  mesa exactamente como antes de crear el nuevo pedido — crear un nuevo pedido no agrega, quita ni
  reordena nada en la vista de cocina para pedidos ya enviados.
- **FR-007** [YA EXISTE, sin cambios]: El sistema NO crea ningún registro de pedido en el backend
  mientras el carrito del formulario de creación de orden manual no tenga ningún producto
  agregado; si el cajero vuelve a la vista de mesas (o libera la mesa) sin haber agregado
  productos, la mesa conserva únicamente sus pedidos previos ya resueltos, sin ningún rastro del
  intento.
- **FR-008** [YA EXISTE, sin cambios]: En cuanto el cajero agregue al menos un producto al carrito
  del nuevo pedido, el sistema sigue el mismo comportamiento ya existente para el formulario de
  creación de orden manual con productos sin confirmar (spec 052): ese pedido no se descarta
  automáticamente al salir de la pantalla, y permanece sin cobrar hasta que se confirme/envíe, se
  cobre o se anule explícitamente.
- **FR-009** [YA EXISTE, sin cambios]: "Liberar Mesa" sigue cerrando la sesión completa de la mesa
  (todos sus pedidos) y es el **único** punto donde el sistema exige que no quede ningún pedido
  sin pagar ni saldo pendiente en la mesa (`has_billable_orders`/`has_pending_balance`, spec 123
  Historia 5), incluido cualquier nuevo pedido creado por esta funcionalidad — ninguna otra
  acción (ni "+ Crear pedido nuevo", ni cobrar una cuenta) impone esa condición sobre las demás.
- **FR-010** [YA EXISTE, sin cambios]: El sistema NO DEBE ofrecer ninguna acción de "consolidar
  cuentas" que fusione el cobro o la factura de varios pedidos de la misma mesa en una sola
  operación; cada pedido se cobra siempre por separado, sin importar cuántos otros pedidos sin
  resolver tenga la misma mesa (Clarifications).
- **FR-011** [YA EXISTE, sin cambios]: Cuando un pedido sin pagar no puede cobrarse y bloquea
  "Liberar Mesa", el único procedimiento autorizado para destrabarla es anular ese pedido
  (`cancel_order`, ya existente); el sistema NO DEBE ofrecer ninguna liberación forzada que deje
  la mesa libre sin resolver (cobrada o anulada) cada uno de sus pedidos (Clarifications).

### Key Entities *(include if feature involves data)*

Regla 2 de la revisión de dominio pide separar explícitamente el estado de la mesa, del pedido y
del pago/cuenta. Investigación directa del código confirma que **ya son tres conceptos
independientes**, sin solaparse — esta spec los documenta, no introduce ninguno nuevo:

- **Mesa (Table)**: estado operativo propio (`libre` | `ocupada` | `reservada`) — refleja si hay
  una sesión de servicio abierta sobre la mesa, no el estado de ningún pedido individual. La
  Terminal de Mesas también calcula un **estado visual derivado** por mesa (`deriveTableStatus`:
  `por_confirmar` | `pago_pendiente` | `en_preparacion` | `listo` | `ocupada` | `reservada` |
  `libre`) a partir de los pedidos vivos de la mesa — es presentación, no un estado adicional
  persistido. No existe (ni se introduce) un estado "pendiente de liberar" propio de la mesa: la
  condición de bloqueo vive en el pedido/saldo, no en la mesa.
- **Pedido (Order)**: estado operativo propio (`recibida` | `abierta` | `bloqueada` | `pagada` |
  `cancelada`, backend `OrderStatus`), independiente del estado financiero. El estado de cocina
  (`pendiente` | `en_preparacion` | `listo` | `anulado`) es, a su vez, independiente y por **ítem**
  dentro del pedido, no por pedido completo. Una misma mesa ya puede acumular varios pedidos
  durante una sola visita (spec 087), cada uno identificado por su `table_order_number`.
- **Estado financiero del pedido/cuenta**: **no es un campo almacenado** — se deriva siempre de
  los pagos reales: `paid` (computado: existe una `Sale` para el pedido) y `pending_balance`
  (computado: saldo por adiciones posteriores a la factura, spec 123). Un pedido puede estar
  `cancelada` (operativo) sin haber generado nunca saldo; puede estar `pagada`/`paid=true`
  (financiero resuelto) con ítems todavía `en_preparacion` (operativo/cocina sin terminar) — son
  ejes independientes, exactamente como pide la Regla 2 ("un pedido entregado puede continuar
  pendiente de pago"). No se introduce un tercer estado almacenado "pendiente de pago" /
  "parcialmente pagado" / "pagado": se deriva siempre de `paid` + `pending_balance` para evitar
  la inconsistencia entre estado guardado y movimientos reales que la propia Regla 2 advierte.
- **Sesión de mesa (Table Session)**: agrupa todos los pedidos de una mesa durante una visita.
  Permanece abierta mientras no se pulse "Liberar Mesa", sin importar cuántos pedidos se hayan
  pagado o cuántas cuentas sin resolver tenga en paralelo (A-138) dentro de ella. Determina a qué
  sesión pertenece un pedido nuevo: todo pedido creado mientras la sesión está abierta pertenece
  a esa misma sesión; solo "Liberar Mesa" la cierra y la siguiente visita abre una sesión nueva
  (spec 010).
- **Cuenta (Account)**: la cuenta de cobro de un pedido individual — cada pedido de la mesa ya
  tiene su propia cuenta, su propio pago y su propia factura (sin cambios de esta spec). Varias
  cuentas de la misma mesa pueden quedar sin resolver en paralelo (A-138); ninguna se fusiona ni
  se consolida automática ni explícitamente — se cobran siempre por separado (Clarifications).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El cajero puede abrir un nuevo pedido sobre una mesa ya pagada y empezar a agregar
  productos en menos de 10 segundos, sin pasos adicionales como liberar y volver a asignar la
  mesa (comportamiento ya existente, verificado sin regresión).
- **SC-002**: 100% de los intentos de usar "+ Crear pedido nuevo" sobre una mesa con saldo
  pendiente o un pedido sin pagar tienen éxito, sin bloquearse, y el saldo/estado de los pedidos
  previos de esa mesa permanece exactamente igual después de crear el nuevo (A-138).
- **SC-003**: 0% de los pedidos ya enviados a cocina cambian de estado, ítems o posición en la
  vista de cocina como consecuencia de crear un nuevo pedido en la misma mesa.
- **SC-004**: 100% de los intentos de "+ Crear pedido nuevo" abandonados sin agregar productos no
  generan ningún registro de pedido visible en la mesa ni en reportes de pedidos (comportamiento
  ya existente, verificado sin regresión).

## Assumptions

- La capacidad de que una mesa reciba varios pedidos durante la misma visita ya existe, construida
  e implementada por la spec [087](../087-fix-caja-mesas-menu-ventas/spec.md) (`newOrderTableId()`,
  `table_order_number`, pestañas "Pedido N"); esta spec confirma y documenta ese comportamiento
  explícitamente, sin restringirlo (A-138 revierte el intento de restricción de A-137).
- El enunciado original de esta spec ("nunca hay dos cuentas abiertas sin pagar en la misma
  mesa") queda **superado** por A-138: el modelo de negocio correcto es permitir varias cuentas
  sin resolver en paralelo, protegidas únicamente por el bloqueo de "Liberar Mesa" con saldo
  pendiente (spec 123), no por un bloqueo al crear. La referencia del usuario a "HU-01" pasa a
  interpretarse como "la mesa no se libera con saldos sin gestionar", no como "nunca hay más de
  un saldo sin pagar a la vez" — el concepto de "saldo pendiente" (`pending_balance`) y la acción
  "Cobrar saldo" siguen siendo los ya definidos e implementados por la spec
  [123](../123-adiciones-pago-complementario/spec.md), sin redefinirlos.
- "Anulado" se refiere a un pedido cancelado antes de cobrarse (estado ya existente en el
  sistema); un pedido anulado no genera saldo pendiente.
- El "descarte" de un pedido vacío (Historia 3) no requiere ninguna operación de limpieza en el
  backend ni un temporizador: como el carrito sin productos nunca se persiste (ver Clarifications),
  basta con que el cajero navegue fuera del formulario de creación de orden manual ("← Volver a la
  Terminal" o liberar la mesa) para que no quede ningún rastro — comportamiento ya existente, no
  construido por esta spec.
- Esta spec no modifica cómo se calcula, divide o cobra el saldo pendiente de un pedido
  individual (spec 123), el reparto de cuenta entre comensales (spec 010), ni el criterio de
  habilitación de "+ Crear pedido nuevo" para "Para Llevar"/"Domicilio" (sin mesa) — todos quedan
  exactamente como están.
- Tras A-138, esta spec **no** necesita ningún cómputo agregado nuevo de "¿tiene esta mesa algo
  sin resolver?" para decidir si se habilita "+ Crear pedido nuevo" (ya no depende de eso); el
  único cómputo agregado que sigue existiendo, sin cambios, es el que ya usa "Liberar Mesa"
  (`has_billable_orders`/`has_pending_balance`, spec 123).
- El procedimiento autorizado para liberar una mesa sin poder cobrar un saldo pendiente es anular
  el/los pedidos sin pagar (`cancel_order`, ya existente) — no se introduce ninguna liberación
  forzada ni registro de pérdida nuevo (Clarifications).
- **Concurrencia (Regla 5)**: de los 5 riesgos planteados, 3 dejan de ser riesgos tras A-138 (dos
  cajeros creando pedidos a la vez, un pedido cobrándose mientras se crea otro, un pago parcial
  seguido de un intento de consolidar — ya no hay bloqueo ni consolidación que proteger). Los
  otros 2 ya están cubiertos por invariantes existentes, verificados en el código durante esta
  sesión, sin necesidad de ningún mecanismo nuevo: reintentos de red en la creación de un pedido
  se deduplican por `client_request_id` (`orders/service.py:617-619`); "Liberar Mesa"/cerrar
  sesión toman `FOR UPDATE` sobre la fila de la sesión (`table_sessions/service.py:325,437`) y
  el cobro de un pedido individual toma `FOR UPDATE` sobre su propia fila
  (`orders/checkout.py:153,640,735`), por lo que una liberación y un cobro en curso sobre la
  misma mesa nunca leen un estado a medio escribir. Esta spec no introduce ningún mecanismo de
  concurrencia nuevo.
- No se introduce ninguna acción de "consolidar cuentas" (ver Clarifications): cobrar pedidos
  distintos de la misma mesa en una sola operación/factura queda explícitamente fuera de alcance,
  para no abrir riesgo de duplicidad o alteración retroactiva de movimientos de caja ya
  registrados (Principio VII).
