# Feature Specification: Ciclo de Vida Simplificado del Pedido y Control Manual de Mesas

**Feature Branch**: `147-entrega-pago-liberacion-mesa`

**Created**: 2026-11-01

**Status**: Draft

**Input**: User description: "Como cajero o encargado de barra quiero entregar un pedido con un solo clic, ver por separado si ya está pagado y decidir yo cuándo liberar una mesa, para despachar rápido en un negocio donde preparar y entregar ocurre en minutos, sin perder el control de lo que falta por cobrar ni de la ocupación de las mesas."

## Clarifications

### Session 2026-11-01

- Q: ¿Puede un cajero seguir agregando ítems a un pedido después de que ya quedó en estado "Entregada"? → A: Sí, se puede seguir agregando; los ítems nuevos nacen en "Pendiente" y conviven con los ya "Entregados" dentro del mismo pedido.
- Q: Los pedidos existentes usan hoy 5 estados de orden (pendiente, abierta, bloqueada, pagada, cancelada); el nuevo modelo solo admite 3 (Pendiente, Entregada, Cancelada). ¿Cómo mapear "abierta" y "bloqueada" al migrar? → A: "abierta" → Pendiente, "bloqueada" → Entregada.
- Q: El sistema actual tiene un estado de pago "PARTIAL" además de "UNPAID" y "PAID"; el nuevo modelo solo admite "Sin pagar" y "Pagado". ¿A cuál se migra "PARTIAL"? → A: "PARTIAL" → Sin pagar.
- Q: Los ítems de pedido usan hoy 4 estados de cocina (pendiente, en_preparacion, listo, anulado); el nuevo modelo solo admite 3 (Pendiente, Entregado, Cancelado). ¿Cómo mapear "en_preparacion" y "listo" al migrar? → A: "en_preparacion" → Pendiente, "listo" → Entregado.
- Q: FR-022 exige que el estado de cada ítem siempre refleje el de su pedido; si tras el mapeo individual un pedido migrado a "Entregada" tuviera un ítem mapeado a "Pendiente" (o viceversa), ¿qué prevalece? → A: El estado final del pedido fuerza el de todos sus ítems (se migran a Entregado si el pedido quedó Entregada, a Cancelado si quedó Cancelada).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Entregar un pedido completo con un solo clic (Priority: P1)

El cajero o encargado de barra, al tener listo un pedido (de mesa, mostrador o domicilio),
lo marca como entregado con una sola acción, sin tener que marcar ítem por ítem. Esto
aplica sin importar el canal de origen: QR (creado por el comensal), mostrador, mesa o
domicilio (creados por el cajero).

**Why this priority**: Es el dolor principal reportado: marcar ítems uno por uno es tedioso
en pedidos grandes y no refleja cómo opera el negocio (preparar y entregar ocurren en
minutos, casi simultáneamente). Sin esto no hay valor entregado.

**Independent Test**: Se puede probar completamente creando un pedido con varios ítems en
estado "Pendiente" y presionando el botón "Entregar"; el pedido completo y todos sus ítems
deben pasar a "Entregado" en una sola operación, verificable sin que exista aún la
funcionalidad de pago separado o liberación de mesa.

**Acceptance Scenarios**:

1. **Given** una orden en estado "Pendiente" con pago "Sin pagar" y 6 ítems en "Pendiente",
   **When** el encargado presiona "Entregar", **Then** la orden pasa a "Entregada" y sus 6
   ítems pasan a "Entregado", y el pago sigue en "Sin pagar".
2. **Given** una orden en estado "Pendiente", **When** el encargado presiona "Entregar",
   **Then** no existe ninguna acción para marcar ítems individuales como entregados.
3. **Given** una orden ya en estado "Entregada", **When** dos usuarios presionan "Entregar"
   sobre la misma orden casi al mismo tiempo (doble clic o dos sesiones), **Then** la orden
   cambia a "Entregada" una sola vez y ambas peticiones terminan en éxito sin generar un
   segundo evento de cambio de estado.
4. **Given** una orden en estado "Cancelada", **When** se intenta entregarla, **Then** la
   acción es rechazada y el estado no cambia.

---

### User Story 2 - Ver el estado de pago separado del estado del pedido (Priority: P1)

El cajero o encargado de barra necesita saber, con solo mirar el pedido o la Terminal de
Mesas, si un pedido ya se entregó y, por separado, si ya se cobró. Son dos preguntas
distintas que hoy se confunden en un solo estado.

**Why this priority**: Es condición necesaria para operar con confianza la entrega con un
clic: si entregar no distingue el pago, el cajero pierde el control de lo que falta por
cobrar, que es justo lo que el negocio no puede perder.

**Independent Test**: Se puede probar mostrando una orden "Entregada" con pago "Sin pagar"
y otra "Entregada" con pago "Pagado" en la Terminal de Mesas y en el detalle del pedido, y
verificando que ambos indicadores se muestran por separado y de forma distinguible,
independientemente de si ya existe o no la funcionalidad de liberación de mesa.

**Acceptance Scenarios**:

1. **Given** un pedido nuevo recién creado por cualquier canal, **When** se guarda,
   **Then** queda en estado "Pendiente" con pago "Sin pagar", y ambos se muestran como
   indicadores separados.
2. **Given** una orden "Entregada" con pago "Sin pagar", **When** el cajero registra el
   cobro, **Then** el pago pasa a "Pagado" y la orden permanece en "Entregada": cobrar no
   cambia el estado de la orden, y entregar no cambia el estado del pago.
3. **Given** una orden "Entregada" con pago "Sin pagar", **Then** la orden aparece en un
   filtro de "Entregadas sin cobrar"; una vez el pago pasa a "Pagado", sale de ese filtro.
4. **Given** un pedido QR cuyo pago ya fue confirmado por el cajero antes de entregarse,
   **When** el encargado presiona "Entregar", **Then** la orden queda "Entregada" con pago
   "Pagado" y se considera cerrada, y el comensal recibe la actualización en tiempo real.

---

### User Story 3 - Decidir cuándo liberar una mesa (Priority: P2)

El cajero decide manualmente cuándo una mesa queda disponible de nuevo, en lugar de que el
sistema la libere solo por haber pasado un tiempo determinado.

**Why this priority**: Resuelve la segunda queja del negocio (pérdida de control sobre la
ocupación de mesas), pero depende conceptualmente de que el pedido y el pago ya se manejen
como estados separados (Historias 1 y 2), por lo que se entrega después.

**Independent Test**: Se puede probar ocupando una mesa, cerrando todas sus órdenes
(entregadas y pagadas, o canceladas) y verificando que la mesa permanece ocupada hasta que
el cajero presiona explícitamente "Liberar mesa", sin que exista ningún temporizador que la
libere antes.

**Acceptance Scenarios**:

1. **Given** la mesa 4 con una sola orden "Entregada" y pago "Sin pagar", **When** el
   cajero registra el cobro, **Then** la orden se considera cerrada pero la mesa 4 sigue
   ocupada, y el comensal puede crear una nueva orden en la misma visita.
2. **Given** todas las órdenes de la mesa 4 cerradas (entregadas y pagadas) o canceladas,
   **When** el cajero presiona "Liberar mesa", **Then** la mesa 4 queda disponible y la
   sesión de mesa se cierra.
3. **Given** la mesa 4 con una orden "Entregada" y pago "Sin pagar" (orden abierta),
   **When** el cajero presiona "Liberar mesa", **Then** el sistema rechaza la acción y
   muestra las órdenes abiertas que debe cobrar o cancelar primero.
4. **Given** la mesa 4 lleva 7 horas ocupada sin que el cajero la libere, **When** pasa el
   tiempo, **Then** la mesa sigue ocupada (no existe liberación automática) y la Terminal
   muestra, solo de forma informativa, el tiempo que lleva ocupada.

---

### User Story 4 - Cancelar un pedido entregado que no se pudo cobrar (Priority: P3)

El cajero necesita poder cancelar, con un motivo obligatorio, un pedido que ya salió de
barra pero que finalmente no se pudo cobrar (por ejemplo, un domicilio fallido o un cliente
que se fue sin pagar), para poder destrabar la mesa o cerrar el pedido correctamente.

**Why this priority**: Es un caso de excepción dentro del ciclo de vida, no el flujo
principal; depende de que existan los dos estados separados (orden y pago) de las
Historias 1 y 2.

**Independent Test**: Se puede probar llevando una orden a "Entregada" con pago "Sin
pagar", cancelándola con un motivo, y verificando que la orden y sus ítems quedan
"Cancelados" y que no bloquea la liberación de la mesa.

**Acceptance Scenarios**:

1. **Given** una orden de domicilio "Entregada" con pago "Sin pagar", **When** el cajero la
   cancela con el motivo "Cliente no contestó", **Then** la orden queda "Cancelada" con el
   motivo registrado, sus ítems quedan "Cancelados" y no se genera ningún movimiento de
   caja.
2. **Given** una orden "Entregada" con pago "Sin pagar", **When** se intenta cancelarla sin
   indicar un motivo, **Then** la acción es rechazada indicando que el motivo es
   obligatorio.
3. **Given** una orden "Entregada" con pago "Pagado", **When** se intenta cancelarla,
   **Then** la acción es rechazada indicando que ese caso requiere un proceso de reembolso
   (fuera de alcance de esta funcionalidad).
4. **Given** una orden "Cancelada", **When** se intenta entregarla o registrar su cobro,
   **Then** la acción es rechazada por tratarse de una transición de estado inválida y
   ningún estado cambia.

---

### Edge Cases

- ¿Qué pasa si se presiona "Entregar" dos veces consecutivas o desde dos sesiones distintas
  sobre la misma orden? La orden cambia una sola vez y ambas peticiones responden con éxito,
  sin duplicar la notificación de cambio.
- ¿Qué pasa si se intenta cobrar o entregar una orden que ya está "Cancelada"? La acción se
  rechaza como transición inválida y el estado no cambia.
- ¿Qué pasa si se intenta cancelar una orden "Entregada" sin motivo, o una orden "Entregada"
  ya pagada? Ambos casos se rechazan explícitamente (motivo obligatorio en el primero,
  proceso de reembolso fuera de alcance en el segundo).
- ¿Qué pasa si una mesa tiene varias órdenes en la misma visita y todas quedan cerradas o
  canceladas? La mesa no se libera sola; sigue ocupada hasta que el cajero lo decida.
- ¿Qué pasa si el cajero intenta liberar una mesa que todavía tiene una orden "Pendiente" o
  "Entregada y sin pagar"? Se rechaza la liberación y se le muestran esas órdenes abiertas
  para que las cobre o cancele.
- ¿Qué pasa con una mesa que lleva muchas horas ocupada sin actividad? Permanece ocupada
  indefinidamente; el tiempo ocupado es solo informativo y nunca libera la mesa por sí
  mismo.
- ¿Qué pasa con el estado de un pedido QR ya pagado antes de que se prepare? Al entregarse,
  queda "Entregada" y "Pagada" en el mismo paso, se considera cerrada, y el comensal ve el
  cambio reflejado en tiempo real en su propia vista.
- ¿Qué pasa si se agrega un nuevo ítem a un pedido que ya está "Entregada"? El ítem nuevo
  nace "Pendiente" y convive con los ítems ya "Entregados" del mismo pedido; el pedido
  permanece "Entregada" hasta que el cajero vuelve a presionar "Entregar" sobre ese mismo
  pedido, lo que lleva ese ítem nuevo (y cualquier otro "Pendiente") a "Entregado".

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST permitir marcar un pedido completo como entregado mediante
  una sola acción ("Entregar"), que lleva la orden al estado "Entregada" y todos sus ítems
  en estado "Pendiente" al estado "Entregado" en la misma operación.
- **FR-002**: El sistema MUST NOT ofrecer ninguna acción para marcar ítems individuales como
  entregados por separado; la entrega siempre es a nivel de pedido completo.
- **FR-002a**: El sistema MUST permitir agregar nuevos ítems a un pedido que ya está en
  estado "Entregada"; dichos ítems nuevos nacen en estado "Pendiente" y conviven con los
  ítems ya "Entregados" del mismo pedido, sin que esto cambie el estado "Entregada" del
  pedido ni reactive la acción de entrega individual por ítem (FR-002). El sistema MUST
  permitir volver a presionar "Entregar" sobre ese mismo pedido para llevar esos nuevos
  ítems "Pendientes" a "Entregado"; esa repetición de "Entregar" no cambia el estado del
  pedido (que ya está "Entregada") ni su estado de pago.
- **FR-003**: El sistema MUST mantener el estado de la orden (Pendiente, Entregada,
  Cancelada) y el estado del pago (Sin pagar, Pagado) como dos valores independientes que
  evolucionan por separado: entregar un pedido no cambia su estado de pago, y registrar un
  cobro no cambia su estado de orden.
- **FR-004**: El sistema MUST permitir registrar el cobro de un pedido (pasar su pago de
  "Sin pagar" a "Pagado") en cualquier estado de la orden excepto "Cancelada", sin importar
  si el pedido ya fue entregado o todavía no.
- **FR-005**: Todo pedido nuevo, sin importar su canal de origen (QR creado por el
  comensal, mostrador, mesa o domicilio creados por el cajero), MUST nacer en estado
  "Pendiente" con pago "Sin pagar" y todos sus ítems en "Pendiente".
- **FR-006**: El sistema MUST considerar un pedido "cerrado" únicamente cuando su estado es
  "Entregada" y su pago es "Pagado". Un pedido cerrado MUST NOT liberar automáticamente la
  mesa a la que pertenece.
- **FR-007**: El sistema MUST permitir cancelar, con un motivo obligatorio, un pedido que
  esté en estado "Entregada" y con pago "Sin pagar" (por ejemplo, domicilio fallido o
  cliente que se fue sin pagar). Al cancelarse, el pedido y todos sus ítems MUST quedar en
  estado "Cancelado" y no MUST generar ningún movimiento de caja.
- **FR-008**: El sistema MUST rechazar la cancelación de un pedido "Entregada" sin motivo
  indicado, informando que el motivo es obligatorio.
- **FR-009**: El sistema MUST rechazar la cancelación de un pedido que esté "Entregada" y
  con pago "Pagado", informando que ese caso requiere un proceso de reembolso (fuera de
  alcance de esta funcionalidad).
- **FR-010**: El sistema MUST rechazar cualquier intento de entregar o cobrar un pedido que
  ya esté en estado "Cancelada", sin modificar ningún estado, e informando que es una
  transición inválida.
- **FR-011**: El sistema MUST garantizar que, si dos solicitudes de entrega llegan casi al
  mismo tiempo para el mismo pedido (doble clic o dos usuarios), el pedido cambie a
  "Entregada" una sola vez, y que la segunda solicitud también reciba una respuesta exitosa
  sin que se genere una segunda notificación de cambio de estado.
- **FR-012**: El sistema MUST mostrar, tanto en el detalle del pedido como en la tarjeta de
  cada mesa en la Terminal de Mesas, dos indicadores visualmente separados: el estado del
  pedido y el estado del pago.
- **FR-013**: La interfaz MUST mostrar únicamente los estados y etiquetas que entrega el
  sistema, sin traducir, renombrar ni inferir un estado adicional (por ejemplo, no debe
  existir un estado visual de "En preparación" que ya no exista en el modelo de estados).
- **FR-014**: El sistema MUST ofrecer un filtro o vista de "Entregadas sin cobrar" que
  incluya todo pedido en estado "Entregada" con pago "Sin pagar", y que excluya un pedido
  en cuanto su pago pase a "Pagado".
- **FR-015**: La liberación de una mesa MUST ser siempre una acción manual que ejecuta el
  cajero; el sistema MUST NOT liberar ninguna mesa automáticamente por el solo transcurso
  del tiempo.
- **FR-016**: El sistema MUST permitir liberar una mesa únicamente cuando ninguna de sus
  órdenes esté "abierta", entendiendo por orden abierta aquella en estado "Pendiente" o en
  estado "Entregada" con pago "Sin pagar". Las órdenes "Canceladas" MUST NOT impedir la
  liberación.
- **FR-017**: Cuando se intenta liberar una mesa que tiene órdenes abiertas, el sistema
  MUST rechazar la acción e informar cuáles son esas órdenes abiertas, de modo que el
  cajero pueda cobrarlas o cancelarlas.
- **FR-018**: El sistema MUST permitir que una mesa reciba varias órdenes dentro de la misma
  visita, y que el cierre de todas ellas (entregadas y pagadas, o canceladas) no cambie por
  sí solo el estado de ocupación de la mesa.
- **FR-019**: La Terminal de Mesas MUST mostrar, para cada mesa ocupada, el tiempo que lleva
  ocupada, de forma puramente informativa: ese indicador MUST NOT disparar ninguna acción
  automática sobre la mesa ni sobre sus órdenes.
- **FR-020**: Cuando un pedido de origen QR cambia de estado de orden o de pago, el
  comensal que lo originó MUST recibir esa actualización en tiempo real en su propia vista
  del pedido.
- **FR-021**: El modelo de estados de pedido MUST admitir únicamente los valores
  "Pendiente", "Entregada" y "Cancelada", y las únicas transiciones permitidas MUST ser
  Pendiente → Entregada, Pendiente → Cancelada, y Entregada → Cancelada (esta última solo
  con pago "Sin pagar" y motivo obligatorio).
- **FR-022**: El modelo de estados de los ítems de un pedido MUST admitir únicamente los
  valores "Pendiente", "Entregado" y "Cancelado", y MUST seguir siempre el estado de su
  pedido: los ítems no tienen una acción propia de cambio de estado independiente de la
  orden. La única excepción es un ítem agregado después de que el pedido ya quedó
  "Entregada" (FR-002a): ese ítem nace "Pendiente" y puede convivir temporalmente con
  ítems "Entregados" del mismo pedido, hasta que una nueva acción "Entregar" sobre ese
  pedido lo lleve también a "Entregado".
- **FR-023**: Cualquier registro existente que, antes de esta funcionalidad, tuviera un
  estado de pedido o de ítem fuera de los conjuntos definidos en FR-021 y FR-022 (por
  ejemplo, estados intermedios de "listo" o "en preparación") MUST quedar convertido a uno
  de los estados válidos, sin dejar ningún registro en un estado fuera de ese conjunto, de
  acuerdo con el siguiente mapeo:
  - Estado de pedido "abierta" → "Pendiente".
  - Estado de pedido "bloqueada" → "Entregada".
  - Estado de pedido "pagada" → "Entregada" (con pago "Pagado").
  - Estado de pago "PARTIAL" → "Sin pagar".
  - Estado de ítem "en_preparacion" → "Pendiente".
  - Estado de ítem "listo" → "Entregado".
  - Si el mapeo anterior produce, para un mismo pedido, un estado de ítem distinto del
    estado final ya asignado al pedido (por ejemplo, un pedido migrado a "Entregada" con
    algún ítem mapeado a "Pendiente", o un pedido migrado a "Cancelada" con algún ítem no
    mapeado a "Cancelado"), el estado final del pedido MUST prevalecer y forzar el de
    todos sus ítems, de modo que ningún pedido quede, tras la migración, en un estado que
    contradiga el estado de sus propios ítems (FR-022).

### Key Entities

- **Pedido (Orden)**: Representa una comanda de un cliente, sin importar el canal (QR,
  mostrador, mesa, domicilio). Tiene un estado de pedido (Pendiente, Entregada, Cancelada),
  un estado de pago independiente (Sin pagar, Pagado), un motivo de cancelación (solo
  cuando se cancela estando entregada) y pertenece a una mesa cuando aplica.
- **Ítem de pedido**: Cada línea de producto dentro de un pedido. Su estado (Pendiente,
  Entregado, Cancelado) siempre refleja el estado del pedido al que pertenece; no cambia de
  forma independiente.
- **Mesa / Sesión de mesa**: Representa la ocupación de una mesa física durante una visita,
  que puede contener varios pedidos. Tiene un estado de ocupación (ocupada/disponible) y un
  momento de apertura usado para calcular, de forma informativa, el tiempo que lleva
  ocupada. Se libera únicamente por acción manual del cajero.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El cajero puede marcar un pedido completo (sin importar su número de ítems)
  como entregado con una sola acción, en menos de 2 segundos de interacción.
- **SC-002**: El 100% de los pedidos nuevos, sin importar su canal de origen, queda visible
  con sus dos estados (pedido y pago) mostrados por separado desde el momento en que se
  crean.
- **SC-003**: El cajero puede identificar, sin abrir el detalle de cada pedido, cuáles
  pedidos de una mesa están "entregados pero sin cobrar" consultando un único filtro o
  vista.
- **SC-004**: El cajero puede intentar liberar una mesa con órdenes abiertas y recibir, en
  el mismo intento, la lista de las órdenes que debe resolver, sin tener que buscarlas por
  separado.
- **SC-005**: Ninguna mesa queda liberada automáticamente por el paso del tiempo: el 100%
  de las liberaciones de mesa ocurren por una acción explícita del cajero.
- **SC-006**: Dos solicitudes de entrega simultáneas sobre el mismo pedido producen un único
  cambio de estado efectivo, verificable en el 100% de los casos de prueba de concurrencia.
- **SC-007**: Tras la migración de datos de esta funcionalidad, el 100% de los pedidos e
  ítems existentes queda con un valor de estado dentro del conjunto final admitido, sin
  excepciones.

## Assumptions

- La separación "listo" vs. "entregado" por ítem ya no aporta valor en este negocio, dado
  que el tiempo de preparación y despacho es del orden de minutos; por eso esta
  funcionalidad colapsa ambos conceptos en una sola acción de entrega a nivel de pedido.
- "Entregada" significa que el pedido salió de la barra hacia su destino (mesa, cliente de
  mostrador o domiciliario); en el caso de domicilios, no implica que el cliente final ya
  lo haya recibido, ya que el seguimiento "en camino / recibido" queda fuera de alcance.
- Cancelar un pedido ya entregado no revierte ningún consumo de inventario ya generado,
  porque el producto ya fue preparado; el ajuste de inventario por cancelaciones queda
  fuera de alcance de esta funcionalidad.
- El reembolso de pedidos "Entregada + Pagado" (por ejemplo, por una devolución) es un
  proceso distinto y queda explícitamente fuera de alcance.
- El seguimiento detallado del estado de un domicilio ("en camino", "recibido por el
  cliente"), así como la asignación de domicilios a un domiciliario específico y el cuadre
  de caja por domiciliario, quedan fuera de alcance de esta funcionalidad.
- Más allá de validar que no existan órdenes abiertas y de mostrar el tiempo de ocupación,
  no se introducen otros cambios al flujo general de apertura o gestión de sesiones de
  mesa.
- El tiempo que lleva ocupada una mesa es información de apoyo para el cajero y no
  condiciona ninguna regla de negocio ni dispara ninguna acción automática.
