# Feature Specification: Cobro independiente de pedidos por mesa

**Feature Branch**: `156-cobro-independiente-pedidos-mesa`

**Created**: 2026-11-10

**Status**: Draft

**Input**: User description: "cuando dos comensales escanea una mesa y cada uno envia el pedido, hoy no se puede cobrar el pedido de forma independiente, si no que se cobra el pedido de toda la mesa, me gustaria que el cajero pudiera cobrar el pedido de forma independiente"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Cobrar un pedido individual de la mesa (Priority: P1)

Dos comensales escanean el código QR de la misma mesa y cada uno envía su propio pedido por separado (ej. "Pedido 41" y "Pedido 42"). Uno de los comensales quiere pagar y retirarse antes que el otro. El cajero necesita poder cobrar únicamente el pedido de ese comensal, sin verse obligado a cobrar también el pedido del resto de comensales de la misma mesa.

**Why this priority**: Es el problema central reportado: hoy el cobro agrupa obligatoriamente todos los pedidos de la mesa, lo que impide atender a comensales que terminan y pagan en momentos distintos. Sin esto no hay valor entregado.

**Independent Test**: Se puede probar generando dos pedidos distintos sobre la misma mesa, cobrando solo uno de ellos, y verificando que el pedido cobrado queda marcado como pagado mientras el otro permanece pendiente y la mesa no se libera.

**Acceptance Scenarios**:

1. **Given** una mesa con dos pedidos enviados ("Pedido 41" pendiente de pago, "Pedido 42" pendiente de pago), **When** el cajero selecciona "Pedido 42" y confirma el cobro, **Then** el sistema registra el pago únicamente sobre "Pedido 42", este queda marcado como pagado, y "Pedido 41" permanece sin cobrar.
2. **Given** un pedido ya cobrado de forma independiente, **When** el cajero visualiza la cuenta de la mesa, **Then** el monto a cobrar y el total mostrado corresponden solo a los pedidos aún pendientes de pago, no al total histórico de la mesa.
3. **Given** una mesa con todos sus pedidos pagados excepto uno, **When** se cobra el último pedido pendiente, **Then** la mesa queda con todos los pedidos marcados como pagados pero permanece abierta hasta que el cajero la libere explícitamente.

---

### User Story 2 - Cobrar varios pedidos de la mesa en una sola transacción (Priority: P2)

El cajero también debe poder seguir cobrando, en una sola operación, varios o todos los pedidos pendientes de una misma mesa cuando los comensales deciden pagar juntos (por ejemplo, la cuenta completa de la mesa).

**Why this priority**: Preserva el flujo actual que ya funciona para el caso en que los comensales sí quieren pagar junto, evitando una regresión funcional al resolver el cobro independiente.

**Independent Test**: Se puede probar seleccionando dos o más pedidos pendientes de una mesa y confirmando que el cobro los marca a todos como pagados en una sola transacción.

**Acceptance Scenarios**:

1. **Given** una mesa con dos pedidos pendientes de pago, **When** el cajero selecciona ambos pedidos y confirma el cobro conjunto, **Then** ambos pedidos quedan marcados como pagados en una única transacción de cobro.
2. **Given** una mesa con tres pedidos pendientes, **When** el cajero selecciona solo dos de ellos para cobro conjunto, **Then** el pedido no seleccionado permanece pendiente de pago.

---

### User Story 3 - Visualizar el estado de pago de cada pedido de la mesa (Priority: P2)

El cajero necesita distinguir, dentro de la terminal de mesas, qué pedidos de una mesa ya están pagados y cuáles siguen pendientes, para decidir cuál cobrar y cuándo liberar la mesa.

**Why this priority**: Es el soporte visual indispensable para que el cobro independiente (User Story 1) sea utilizable; sin esta visibilidad el cajero no puede operar con confianza.

**Independent Test**: Se puede probar abriendo una mesa con pedidos en distintos estados de pago y verificando que la interfaz identifica claramente cuáles están pagados y cuáles pendientes.

**Acceptance Scenarios**:

1. **Given** una mesa con "Pedido 41" pagado y "Pedido 42" pendiente, **When** el cajero abre la cuenta de la mesa, **Then** el sistema muestra de forma diferenciada el estado de pago de cada pedido.
2. **Given** una mesa con todos los pedidos pagados, **When** el cajero visualiza la mesa, **Then** el sistema indica que no quedan pedidos pendientes de cobro y habilita la acción de liberar la mesa.

---

### Edge Cases

- Si un comensal intenta agregar productos a un pedido que ya fue cobrado de forma independiente, el sistema no permite modificarlo; cualquier producto adicional debe registrarse en una nueva cuenta/pedido dentro de la misma mesa.
- Si el cajero intenta liberar la mesa mientras existen pedidos pendientes de pago, el sistema debe impedir la liberación y advertir cuáles pedidos siguen pendientes.
- Si se rechaza un pedido pendiente mientras otros pedidos de la misma mesa ya están pagados, el rechazo solo afecta al pedido seleccionado.
- Si todos los pedidos de una mesa quedan pagados, la mesa no se libera automáticamente: permanece visible con todos sus pedidos marcados como pagados hasta que el cajero presione explícitamente el botón de liberar mesa.
- Si solo existe un único pedido en la mesa (caso actual sin división), el comportamiento de cobro individual coincide con el cobro total existente, sin cambios visibles para el cajero.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST permitir al cajero cobrar un único pedido de una mesa de forma independiente, sin requerir que se cobren los demás pedidos pendientes de la misma mesa.
- **FR-002**: El sistema MUST permitir al cajero seleccionar dos o más pedidos pendientes de una misma mesa y cobrarlos juntos en una sola transacción.
- **FR-003**: El sistema MUST calcular el monto a cobrar en cada transacción únicamente en base a los pedidos seleccionados (uno o varios), y no sobre el total histórico de todos los pedidos de la mesa.
- **FR-004**: El sistema MUST registrar y mostrar el estado de pago (pagado / pendiente de pago) de cada pedido de la mesa de manera individual.
- **FR-005**: El sistema MUST mantener la mesa en estado abierto mientras existan uno o más pedidos pendientes de pago, independientemente de cuántos pedidos ya se hayan cobrado.
- **FR-006**: El sistema MUST mantener la mesa abierta, aunque todos sus pedidos estén pagados, hasta que el cajero ejecute explícitamente la acción de liberar la mesa.
- **FR-007**: El sistema MUST impedir que se agreguen o modifiquen productos en un pedido que ya fue cobrado; cualquier producto adicional del mismo comensal debe registrarse en un nuevo pedido/cuenta dentro de la mesa.
- **FR-008**: El sistema MUST permitir rechazar un pedido pendiente de pago de forma individual sin afectar el estado de pago de los demás pedidos de la mesa.
- **FR-009**: El sistema MUST reflejar en la interfaz de cobro, para cada pedido o grupo de pedidos seleccionado, el método de pago y el monto recibido de forma independiente a otros pedidos de la mesa.

### Key Entities

- **Mesa**: Representa una mesa física del establecimiento; agrupa uno o varios pedidos generados por los comensales que la escanean. Tiene un estado general (pendiente/liberada) que depende del estado de pago de sus pedidos.
- **Pedido**: Unidad de consumo enviada por un comensal (o grupo de comensales que comparten pedido) a través del escaneo de la mesa. Tiene su propio estado de pago (pagado / pendiente) y su propio detalle de productos y total.
- **Cobro/Transacción de pago**: Registro de un pago realizado por el cajero, asociado a uno o varios pedidos de una misma mesa, con su método de pago y monto.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El cajero puede cobrar el pedido de un comensal en menos de 30 segundos sin necesidad de esperar a que los demás comensales de la mesa terminen o paguen.
- **SC-002**: El 100% de los pedidos cobrados de forma independiente quedan correctamente reflejados como pagados sin alterar el estado de pago de los demás pedidos de la misma mesa.
- **SC-003**: Las mesas con múltiples comensales ya no requieren que todos paguen al mismo tiempo para que alguno pueda retirarse, eliminando el cuello de botella reportado hoy.
- **SC-004**: El cajero puede identificar visualmente el estado de pago de cada pedido de una mesa en menos de 5 segundos al abrir la cuenta de la mesa.

## Assumptions

- Cada pedido enviado desde el escaneo QR de una mesa (identificado como "Pedido N" en la terminal de mesas) es la unidad mínima de cobro; no se requiere dividir un mismo pedido en partes más pequeñas (ej. por producto o por comensal dentro de un mismo pedido).
- Se mantiene la opción de cobro conjunto de varios pedidos de la mesa existente hoy, además de habilitar el cobro individual, según lo confirmado por el usuario.
- Un pedido ya pagado queda bloqueado para nuevas modificaciones; cualquier consumo adicional se gestiona como un nuevo pedido/cuenta dentro de la misma mesa, según lo confirmado por el usuario.
- La liberación de la mesa sigue siendo una acción explícita del cajero (botón "Liberar"), independiente de que todos los pedidos estén pagados, consistente con el comportamiento ya existente en la terminal de mesas.
- No se modifican los métodos de pago disponibles ni el flujo de selección de método de pago; el cambio se limita al alcance (uno o varios pedidos) sobre el cual se aplica el cobro.
