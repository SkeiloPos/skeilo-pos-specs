# Feature Specification: División automática de cuenta por ítem

**Feature Branch**: `164-division-automatica-cuenta`

**Created**: 2026-11-21

**Status**: Draft

**Input**: User description: "quisiera que luego de crearse una orden, apareciera un boton de dividir cuenta, su funcionalidad es que divida de forma automatica cada item y lo asigne en una orden de tal forma que se pueda cobrar una orden de forma independiente en la misma mesa, cuando esta funcionalidad este activa, se podra mover un item de una orden a otra, si una orden por casualidad llega a quedar con item en 0 entonces esta orden no debera existir en la base de datos, si una orden tiene 2 items, debo tener la opcion de crear una cuenta nueva en ese item para asociarlo a esa nueva orden"

## Clarifications

### Session 2026-11-21

- Q: Cuando un ítem de una línea tiene cantidad mayor a 1 (ej. 2x ojo de diablo), ¿se puede mover o asignar a una cuenta nueva solo una parte de esa cantidad (ej. 1 de las 2 unidades), o siempre se mueve/crea la línea completa como una unidad indivisible? → A: Se permite fraccionar la cantidad: el cajero puede mover o asignar a una cuenta nueva solo una parte de las unidades de una línea, dejando el resto en la orden de origen.
- Q: ¿Qué roles de usuario pueden ejecutar las acciones de dividir cuenta, mover ítem y crear cuenta nueva? → A: Los mismos roles que ya tienen permiso para cobrar/gestionar órdenes en la terminal de mesas; no se introduce un permiso ni una restricción de rol adicional para esta funcionalidad.
- Q: Si al mover un ítem (o una cantidad parcial de él) la orden destino ya tiene una línea del mismo producto y variante, ¿el sistema debe fusionar las cantidades en una sola línea, o debe mantenerlas como dos líneas separadas? → A: Se fusionan: si la orden destino ya tiene una línea del mismo producto/variante/precio, la cantidad movida se suma a esa línea existente en vez de crear una línea duplicada.
- Q: Si la línea que se fusionaría en la orden destino tiene un estado de entrega distinto al de la cantidad movida, ¿aun así se fusionan en una sola línea, o se mantienen separadas? → A: Se mantienen separadas: la fusión en una sola línea solo ocurre cuando producto, variante, precio y estado de entrega coinciden; si el estado de entrega difiere, quedan como líneas independientes en la orden destino.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Dividir automáticamente una orden en cuentas por producto (Priority: P1)

Un comensal envía un pedido con varios productos distintos (ej. "ojo de diablo 12 onz", "ojo de diablo 8 onz", "fresa boom 8 onz") y, al momento de pagar, varios comensales de la mesa quieren dividir la cuenta para pagar cada quien lo suyo. El cajero presiona el botón "Dividir cuenta" sobre la orden y el sistema separa automáticamente cada línea de producto de esa orden en una cuenta (orden) independiente, de modo que cada una pueda cobrarse por separado sin afectar a las demás.

**Why this priority**: Es el valor central solicitado: permitir dividir una cuenta ya enviada sin que el cajero tenga que recrear manualmente cada línea en una orden nueva.

**Independent Test**: Se puede probar enviando una orden con 3 líneas de producto distintas, presionando "Dividir cuenta", y verificando que el sistema crea una orden independiente por cada línea, cada una cobrable por separado y visible en la mesa.

**Acceptance Scenarios**:

1. **Given** una orden con 3 líneas de producto distintas y sin ningún pago registrado, **When** el cajero presiona "Dividir cuenta", **Then** el sistema crea una orden nueva por cada línea de producto, cada una con su propio total, y la orden original deja de existir como tal.
2. **Given** una orden con una sola línea de producto, **When** el cajero presiona "Dividir cuenta", **Then** el sistema no realiza ninguna división (no tiene sentido dividir una orden de un solo ítem) y la orden permanece igual.
3. **Given** una orden donde una línea de producto tiene cantidad mayor a 1 (ej. "2x ojo de diablo"), **When** se divide la cuenta, **Then** esa línea completa (con su cantidad) queda junta en una sola orden nueva; no se separa por unidad.

---

### User Story 2 - Mover un ítem de una orden a otra dentro de la misma mesa (Priority: P1)

Después de dividir la cuenta (o cuando la mesa ya tiene varias órdenes activas), el cajero necesita reorganizar los ítems: por ejemplo, un comensal decide pagar algo que había quedado en la cuenta de otro. El cajero debe poder mover un ítem de una orden a otra orden existente de la misma mesa.

**Why this priority**: Sin esta capacidad, la división automática es rígida y no sirve para los casos reales donde los comensales reorganizan lo que cada uno va a pagar.

**Independent Test**: Se puede probar teniendo dos órdenes activas en la misma mesa, moviendo un ítem de una a la otra, y verificando que el ítem aparece en la orden destino con el total recalculado en ambas órdenes.

**Acceptance Scenarios**:

1. **Given** dos órdenes activas en la misma mesa, cada una con al menos un ítem, **When** el cajero mueve un ítem de la orden A a la orden B, **Then** el ítem desaparece de la orden A, aparece en la orden B, y los totales de ambas órdenes se recalculan correctamente.
2. **Given** un ítem que ya fue marcado como "entregado", **When** el cajero lo mueve a otra orden, **Then** el ítem conserva su estado de entrega en la orden destino.
3. **Given** una orden con un único ítem, **When** ese ítem se mueve a otra orden, **Then** la orden de origen, al quedar sin ítems, deja de existir en el sistema.
4. **Given** una línea de producto con cantidad mayor a 1 (ej. "2x ojo de diablo") en la orden A, **When** el cajero mueve solo una parte de esa cantidad (ej. 1 de 2) hacia la orden B, **Then** la orden B queda con una línea de ese producto con la cantidad movida, la orden A conserva una línea del mismo producto con la cantidad restante, y los totales de ambas órdenes se recalculan según la cantidad resultante en cada una.
5. **Given** una línea de producto con cantidad mayor a 1, **When** el cajero mueve una cantidad parcial que deja la línea de origen en cantidad 0, **Then** esa línea desaparece de la orden de origen (y si era la única línea de esa orden, la orden de origen deja de existir, según FR-007).
6. **Given** la orden B ya tiene una línea del mismo producto, variante, precio y estado de entrega que el ítem que se va a mover desde la orden A, **When** el cajero mueve ese ítem (total o parcial), **Then** el sistema suma la cantidad movida a la línea existente en la orden B en vez de crear una línea duplicada.
7. **Given** la orden B ya tiene una línea del mismo producto y variante pero con estado de entrega distinto al del ítem que se va a mover desde la orden A, **When** el cajero mueve ese ítem, **Then** el sistema crea una línea independiente en la orden B en vez de fusionarla con la línea existente.

---

### User Story 3 - Crear una cuenta nueva a partir de un ítem específico (Priority: P2)

Dentro de una orden con varios ítems, el cajero quiere separar solo uno de ellos en una cuenta completamente nueva (no mover a una orden ya existente, sino crear una), por ejemplo porque un comensal adicional se suma y quiere pagar solo ese producto.

**Why this priority**: Complementa la división automática para el caso en que el cajero quiere control manual sobre un ítem puntual, sin tener que dividir toda la orden.

**Independent Test**: Se puede probar en una orden con 2 ítems, seleccionando la opción "crear cuenta nueva" sobre uno de ellos, y verificando que se crea una orden nueva que contiene únicamente ese ítem, mientras el resto permanece en la orden original.

**Acceptance Scenarios**:

1. **Given** una orden con 2 ítems, **When** el cajero selecciona "crear cuenta nueva" sobre uno de los ítems, **Then** el sistema crea una orden nueva que contiene solo ese ítem y la orden original conserva el ítem restante.
2. **Given** una orden con 2 ítems, **When** el cajero crea una cuenta nueva a partir de uno de ellos y ese era el único ítem restante en la orden original tras la operación, **Then** la orden original deja de existir en el sistema.
3. **Given** una orden con una línea de producto con cantidad mayor a 1 (ej. "2x ojo de diablo"), **When** el cajero selecciona "crear cuenta nueva" indicando solo una parte de esa cantidad (ej. 1 de 2), **Then** el sistema crea una orden nueva con una línea de ese producto con la cantidad indicada, y la orden original conserva una línea del mismo producto con la cantidad restante.

---

### Edge Cases

- Si el cajero intenta dividir una cuenta o mover un ítem de una orden que ya tiene un pago registrado (total o parcial), el sistema impide la acción y advierte que la orden ya fue cobrada.
- Si tras mover un ítem o dividir la cuenta una orden queda con cero ítems, esa orden se elimina del sistema (no queda un registro vacío ni visible en la mesa).
- Si el cajero intenta mover el único ítem restante de una orden hacia otra orden, el sistema permite la acción y, como consecuencia, la orden de origen desaparece (ver User Story 2, escenario 3).
- Si se intenta crear una cuenta nueva a partir del único ítem de una orden que ya tiene un solo ítem, el sistema no permite la acción porque no genera ningún cambio real (ya es una cuenta independiente). Esta restricción aplica incluso si la cantidad de ese único ítem es mayor a 1: solo se bloquea cuando se intenta mover/asignar la totalidad de la cantidad de la única línea restante; mover o asignar una cantidad parcial de esa línea sí está permitido, porque deja una línea con cantidad mayor a 0 en la orden original.
- Al mover o crear una cuenta nueva con una cantidad parcial de una línea (cantidad mayor a 1), el sistema exige que la cantidad indicada sea mayor a 0 y menor a la cantidad total de la línea de origen; la línea de origen conserva la cantidad restante y la línea nueva (en la orden destino) se crea con la cantidad movida, ambas al mismo precio unitario y con el mismo estado de entrega que tenía la línea original.
- Si la mesa solo tiene una orden con un único ítem, el botón "Dividir cuenta" no tiene efecto útil y el sistema lo mantiene deshabilitado o sin acción.
- El estado de entrega (pendiente/entregado) de un ítem es independiente de a qué orden pertenece, por lo que puede moverse entre órdenes sin restricción mientras la orden de destino u origen no estén pagadas.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST mostrar un botón "Dividir cuenta" en cada orden visible en la terminal de mesas, disponible mientras esa orden no tenga ningún pago registrado y tenga más de un ítem.
- **FR-002**: Al presionar "Dividir cuenta", el sistema MUST crear automáticamente una orden independiente por cada línea de producto de la orden original, conservando producto, variante, cantidad, precio y estado de entrega de cada línea.
- **FR-003**: El sistema MUST eliminar la orden original de la base de datos inmediatamente después de completarse la división en las nuevas órdenes, de forma que no queden registros duplicados ni huérfanos.
- **FR-004**: El sistema MUST permitir mover un ítem desde su orden actual hacia otra orden existente de la misma mesa, siempre que ninguna de las dos órdenes tenga pagos registrados. Cuando la línea del ítem tiene cantidad mayor a 1, el sistema MUST permitir mover solo una parte de esa cantidad, dejando en la orden de origen una línea con la cantidad restante y creando o incrementando en la orden destino una línea del mismo producto con la cantidad movida. Si la orden destino ya tiene una línea con el mismo producto, variante, precio y estado de entrega que la cantidad movida, el sistema MUST fusionarlas sumando la cantidad en esa línea existente en vez de crear una línea duplicada; si el estado de entrega difiere, el sistema MUST mantenerlas como líneas separadas en la orden destino.
- **FR-005**: El sistema MUST recalcular el total de ambas órdenes (origen y destino) inmediatamente después de mover un ítem, incluyendo el caso de movimiento de cantidad parcial de una línea.
- **FR-006**: El sistema MUST permitir, para cualquier ítem dentro de una orden con 2 o más ítems, la acción de "crear cuenta nueva" que genera una orden nueva en la misma mesa conteniendo únicamente ese ítem. Cuando la línea del ítem tiene cantidad mayor a 1, el sistema MUST permitir indicar solo una parte de esa cantidad para la cuenta nueva, dejando en la orden original una línea del mismo producto con la cantidad restante.
- **FR-007**: El sistema MUST eliminar automáticamente de la base de datos cualquier orden que, como resultado de mover o reasignar sus ítems, quede con cero ítems.
- **FR-008**: El sistema MUST impedir dividir, mover ítems o crear cuentas nuevas sobre una orden que ya tiene un pago (total o parcial) registrado, mostrando un aviso al cajero.
- **FR-009**: El sistema MUST mantener el vínculo de todas las órdenes resultantes de una división o de un movimiento de ítems con la misma mesa de origen.
- **FR-010**: El sistema MUST permitir repetir la división automática o mover ítems tantas veces como sea necesario sobre las órdenes de una mesa, mientras ninguna de las órdenes involucradas tenga pagos registrados.

### Key Entities

- **Orden (cuenta)**: Conjunto de ítems de productos enviados o reorganizados dentro de una mesa, con su propio total y estado de pago independiente. Puede originarse por el envío de un pedido o por una división/reasignación de ítems de otra orden.
- **Ítem de orden**: Línea de producto dentro de una orden (producto, variante, cantidad, precio, estado de entrega). Es la unidad que se mueve o reasigna entre órdenes; cuando su cantidad es mayor a 1, puede fraccionarse en dos líneas (una por cada orden involucrada) al moverse o asignarse parcialmente a una cuenta nueva, conservando ambas el mismo producto, variante, precio unitario y estado de entrega de la línea original.
- **Mesa**: Agrupa todas las órdenes activas generadas o derivadas de sus comensales; permanece abierta mientras existan órdenes con pagos pendientes.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El cajero puede dividir automáticamente una orden de 3 o más productos distintos en cuentas independientes en menos de 5 segundos.
- **SC-002**: El 100% de las órdenes que quedan con cero ítems tras una división o movimiento desaparecen del sistema sin intervención manual adicional.
- **SC-003**: El cajero puede mover un ítem de una orden a otra y ver el total recalculado de ambas órdenes en menos de 3 segundos.
- **SC-004**: El cajero puede crear una cuenta nueva a partir de un ítem específico de una orden con 2 o más ítems en menos de 10 segundos, sin perder los demás ítems de la orden original.

## Assumptions

- La división automática ("Dividir cuenta") separa por línea de producto (no por unidad individual dentro de una misma línea); una línea con cantidad mayor a 1 permanece junta en la orden resultante, según lo confirmado por el usuario. Esta restricción aplica solo a la división automática: las acciones manuales de mover ítem y crear cuenta nueva sí permiten fraccionar la cantidad de una línea entre dos órdenes (ver Clarifications).
- El botón "Dividir cuenta" y las acciones de mover ítem / crear cuenta nueva solo están disponibles mientras la orden involucrada no tenga ningún pago (total o parcial) registrado; una vez cobrada, la orden queda bloqueada para estas operaciones, según lo confirmado por el usuario.
- Un ítem puede moverse entre órdenes sin importar su estado de entrega (pendiente o entregado), según lo confirmado por el usuario.
- Esta funcionalidad opera dentro del alcance ya existente de cobro independiente por orden en una misma mesa (ver feature de cobro independiente de pedidos por mesa); no reemplaza ni modifica ese comportamiento, solo agrega la capacidad de dividir y reorganizar ítems entre órdenes antes de cobrarlas.
- No se requiere una acción explícita de "deshacer división" o "fusionar cuentas de vuelta en una sola"; si se necesita revertir, se logra moviendo manualmente los ítems de vuelta a una misma orden.
- No se introduce un permiso ni rol nuevo para esta funcionalidad: puede usarla cualquier usuario que ya tenga permiso para cobrar/gestionar órdenes en la terminal de mesas, según lo confirmado por el usuario.
