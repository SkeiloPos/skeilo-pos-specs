# Feature Specification: Pago antes de cocina para pedidos de mesa (QR) con módulo de cocina activo

**Feature Branch**: `153-cobro-previo-cocina-qr`

**Created**: 2026-11-05

**Status**: Draft

**Input**: User description: "necesito que ajustes el flujo de pedido por qr, cuando un tenant pide un producto desde la mesa, y este tiene activado el modulo de cocina, encontre varios fallos el primero, es que el boton de entregar deberia de aparecer cuando el estado de la cocina esta en listo, cuando voy a cobrar me sale entregar y cobrar, lo cual no deberia ser asi, porque cuando el estado de la cocina es listo, necesito que el flujo sea igual a la creacion del pedido manual, siempre y cuando el tenant tenga activado el modulo de cocina, si no lo tiene este debe seguir funcionando tal cual"

## Clarifications

### Session 2026-11-05

- Q: Cuando el módulo de cocina está activo, ¿qué debe pasar con "Cobrar" ANTES de que el pedido se entregue? → A: Cobrar y enviar a cocina en un solo paso (como pedido manual) — se cobra el pedido ANTES de que cocina empiece a prepararlo, igual que ya ocurre hoy con un pedido creado manualmente en el mostrador.
- Q: Si un pedido de mesa por QR se paga en partes (función "dividir cuenta"), ¿en qué momento se envía ese pedido a cocina? → A: Solo al completar el 100% del pago — mientras quede alguna parte de la cuenta dividida sin cobrar, el pedido no se envía a cocina.
- Q: Si un cliente agrega productos nuevos desde el QR a una mesa cuyo pedido ya fue cobrado y enviado a cocina, ¿qué pasa con esos productos nuevos? → A: Fuera de alcance de este ajuste — el comportamiento actual para productos agregados después del cobro inicial no se modifica aquí.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Cobrar el pedido de mesa antes de que cocina lo prepare (Priority: P1)

Un cliente hace un pedido desde la mesa escaneando el código QR. El negocio tiene el módulo de Cocina activo. El cajero/mesero revisa el pedido y lo cobra: en esa misma acción, el pedido queda pagado y se envía a la cocina para que lo preparen. Antes de ese cobro, la cocina no recibe el pedido ni empieza a prepararlo.

**Why this priority**: Es el comportamiento raíz que corrige el reporte del usuario — hoy el pedido de mesa por QR permite intentar cobrar y, al mismo tiempo, ofrece "Entregar", generando confusión y una secuencia de acciones distinta a la de un pedido creado manualmente. Igualar ambos flujos (cobrar → enviar a cocina → entregar) es la base de todo lo demás.

**Independent Test**: Con el módulo de Cocina activo, crear un pedido desde el menú QR de una mesa, recibirlo, y cobrarlo. Confirmar que: (a) antes de cobrar, la cocina no tiene ningún ticket de ese pedido; (b) al cobrar, el pedido se marca como pagado y aparece de inmediato en el tablero de cocina.

**Acceptance Scenarios**:

1. **Given** un pedido de mesa recibido desde el menú QR, sin cobrar, en un negocio con el módulo de Cocina activo, **When** el cajero abre el pedido en el panel de la mesa, **Then** la única acción de cobro disponible paga el pedido y lo envía a cocina en un mismo paso; no existe un botón de "Entregar" activo en ese momento.
2. **Given** un pedido de mesa por QR que aún no ha sido cobrado, **When** se revisa el tablero de Cocina, **Then** ese pedido no aparece todavía en ninguna columna del tablero.
3. **Given** un pedido de mesa por QR recién cobrado (y por tanto recién enviado a cocina), **When** el cajero vuelve a abrir el panel de esa mesa, **Then** el pedido se muestra como ya pagado (comprobante de solo lectura), sin una acción de cobro pendiente.

---

### User Story 2 - Entregar solo cuando cocina marca "Listo" (Priority: P2)

Una vez que un pedido de mesa por QR fue cobrado y enviado a cocina, el cajero/mesero debe poder entregarlo únicamente cuando el personal de cocina lo marque como "Listo" en el tablero de Cocina — nunca antes, y nunca a la vez que una acción de cobro activa.

**Why this priority**: Es la segunda mitad del reporte original: el botón "Entregar" debe depender del estado real de la cocina, y nunca convivir con un cobro pendiente. Depende de que la Historia 1 ya exista (el pedido debe poder llegar a cocina primero).

**Independent Test**: Con un pedido de mesa por QR ya cobrado y enviado a cocina, mover su estado en el tablero de Cocina a "Listo" y confirmar que "Entregar" aparece; confirmar que mientras el estado es distinto de "Listo" no aparece ninguna acción de cobro ni de entrega activa a la vez.

**Acceptance Scenarios**:

1. **Given** un pedido de mesa por QR ya cobrado y enviado a cocina, con estado de cocina "Sin preparar" o "En progreso", **When** el cajero abre el panel de esa mesa, **Then** no se ofrece ninguna acción de "Entregar" todavía, y tampoco se ofrece una acción de cobro (el pedido ya está pagado).
2. **Given** ese mismo pedido, **When** el personal de cocina lo marca como "Listo" en el tablero de Cocina, **Then** el botón "Entregar" pasa a estar disponible en el panel de la mesa.
3. **Given** un pedido de mesa por QR con estado de cocina "Listo", **When** el cajero mira el panel de esa mesa, **Then** ve el botón "Entregar" pero no ve ninguna acción de cobro activa al mismo tiempo.

---

### User Story 3 - Sin módulo de Cocina, todo sigue igual (Priority: P1)

Un negocio que NO tiene el módulo de Cocina activo sigue viendo exactamente el mismo comportamiento de hoy al atender pedidos de mesa por QR: puede cobrar el pedido en cuanto existe, sin esperar nada, y "Entregar" sigue dependiendo únicamente de si los productos del pedido ya fueron marcados como entregados.

**Why this priority**: Es una condición explícita e innegociable del usuario ("si no lo tiene este debe seguir funcionando tal cual"). Tiene la misma prioridad que la Historia 1 porque un regreso accidental a este comportamiento en un negocio sin Cocina sería, en sí mismo, un defecto grave de esta funcionalidad.

**Independent Test**: Repetir los pasos de la Historia 1 y la Historia 2 en un negocio sin el módulo de Cocina activo y confirmar que el resultado es idéntico al comportamiento actual documentado antes de este cambio (cobro disponible de inmediato, entrega gobernada por el estado de cada producto del pedido).

**Acceptance Scenarios**:

1. **Given** un pedido de mesa por QR en un negocio sin el módulo de Cocina, **When** el cajero abre el panel de esa mesa, **Then** la acción de cobro está disponible de inmediato, sin esperar ningún otro paso.
2. **Given** ese mismo pedido, **When** alguno de sus productos todavía no fue marcado como entregado, **Then** el botón "Entregar" sigue apareciendo igual que hoy, de forma independiente a la acción de cobro.

---

### Edge Cases

- ¿Qué pasa con un pedido de mesa por QR que ya estaba cobrado y enviado a cocina antes de este cambio? Sigue su curso normal: espera a que cocina lo marque "Listo" y luego se entrega, sin ninguna interrupción.
- ¿Qué pasa si el cajero intenta cobrar un pedido de mesa por QR que ya fue cobrado bajo este nuevo flujo? No se ofrece una segunda acción de cobro; el pedido se muestra como ya pagado, igual que cualquier otro pedido ya liquidado.
- ¿Qué pasa si el negocio desactiva el módulo de Cocina mientras hay pedidos de mesa por QR entre el cobro y la entrega? El comportamiento de cada pedido se evalúa según el estado del módulo en el momento en que se consulta, igual que ya ocurre hoy con el resto de reglas que dependen de este módulo (ver Assumptions).
- ¿Qué pasa con pedidos de mostrador/domicilio (sin mesa asociada)? No cambian: ya cobran y envían a cocina en un solo paso, que es precisamente el comportamiento que este ajuste extiende a los pedidos de mesa por QR.
- ¿Qué pasa si un pedido de mesa por QR se paga mediante "dividir cuenta"? El pedido solo se envía a cocina cuando el 100% de la cuenta dividida ya fue cobrado; mientras quede alguna parte pendiente de pago, no se envía a cocina (ver FR-002).
- ¿Qué pasa si el cliente agrega productos nuevos desde el QR a una mesa cuyo pedido ya fue cobrado y enviado a cocina? Fuera de alcance de este ajuste: el comportamiento actual para productos agregados después del cobro inicial no se modifica aquí.
- ¿Sigue disponible "Rechazar pedido" antes del cobro? Sí, sin cambios: un pedido de mesa por QR todavía sin cobrar puede rechazarse igual que hoy.
- ¿Sigue existiendo el paso de "Recibir" el pedido hecho desde el QR antes de cobrarlo? Sí, sin cambios: ese paso de confirmación por parte del mesero/cajero se mantiene igual que hoy, antes de la acción de cobro descrita en la Historia 1.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Cuando el módulo de Cocina está activo para el negocio, el sistema DEBE cobrar un pedido de mesa (hecho desde el menú QR) y enviarlo a cocina como una sola acción, de modo que el pedido quede pagado y a la vez disponible para que cocina lo prepare.
- **FR-002**: Cuando el módulo de Cocina está activo, el sistema NO DEBE enviar un pedido de mesa a cocina para su preparación antes de que ese pedido haya sido cobrado. Si el pedido se paga mediante la función de "dividir cuenta", el envío a cocina ocurre únicamente cuando el 100% de la cuenta dividida ya fue cobrado; mientras quede alguna parte pendiente, el pedido no se envía a cocina.
- **FR-003**: Cuando el módulo de Cocina está activo, el sistema NO DEBE ofrecer al mismo tiempo una acción de cobro activa y una acción de "Entregar" activa para el mismo pedido de mesa.
- **FR-004**: Cuando el módulo de Cocina está activo, el sistema DEBE habilitar la acción "Entregar" de un pedido de mesa únicamente a partir de que cocina marque ese pedido como "Listo".
- **FR-005**: Una vez cobrado un pedido de mesa bajo FR-001, el sistema DEBE mostrarlo como un pedido ya liquidado (sin una acción de cobro pendiente) hasta que sea entregado.
- **FR-006**: Cuando el módulo de Cocina NO está activo para el negocio, el sistema DEBE mantener sin cambios el comportamiento actual de los pedidos de mesa por QR: la acción de cobro disponible de inmediato (sin esperar ningún otro paso) y la acción "Entregar" gobernada por si los productos del pedido ya fueron marcados como entregados.
- **FR-007**: El sistema DEBE mantener sin cambios el paso de "Recibir" un pedido de mesa hecho desde el menú QR, como confirmación previa a cualquiera de los flujos de cobro descritos arriba.
- **FR-008**: El sistema DEBE mantener sin cambios la posibilidad de rechazar un pedido de mesa por QR que todavía no ha sido cobrado.
- **FR-009**: Este ajuste aplica únicamente a pedidos asociados a una mesa (hechos desde el menú QR); los pedidos de mostrador o domicilio, que ya cobran y envían a cocina en un solo paso, no deben verse afectados.

### Key Entities *(include if feature involves data)*

- **Pedido (de mesa/QR)**: Representa lo que un cliente pidió desde una mesa escaneando el QR. Tiene un estado de cobro (pagado/no pagado), un estado de entrega, y — cuando ya fue enviado a cocina — un estado de preparación en cocina (sin preparar / en progreso / listo). Este ajuste cambia **cuándo** el pedido pasa a tener un estado de cocina (solo después de cobrarse) y **cuándo** se habilita su entrega (solo cuando ese estado de cocina es "Listo").
- **Negocio (tenant)**: Tiene o no tiene activo el módulo de Cocina en su plan. Esa condición determina cuál de los dos flujos (el nuevo, igualado al de pedidos manuales, o el actual, sin cambios) aplica a sus pedidos de mesa por QR.
- **Pedido manual (de mostrador)**: El flujo de referencia que ya cobra y envía a cocina en un solo paso. No se modifica; es el comportamiento que este ajuste extiende a los pedidos de mesa por QR cuando el módulo de Cocina está activo.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: En negocios con el módulo de Cocina activo, el personal nunca ve al mismo tiempo una acción de cobro activa y una acción de "Entregar" activa para un mismo pedido de mesa.
- **SC-002**: En negocios con el módulo de Cocina activo, el 100% de los pedidos de mesa por QR llegan a cocina ya cobrados — ninguno llega a la cocina estando pendiente de pago.
- **SC-003**: En negocios sin el módulo de Cocina activo, el comportamiento de cobro y entrega de pedidos de mesa por QR no presenta ningún cambio observable respecto al existente antes de este ajuste.
- **SC-004**: Al abrir el panel de cualquier mesa con un pedido por QR, el personal puede saber en un solo vistazo si ese pedido todavía necesita cobrarse o si ya está pagado y en curso hacia cocina/entrega, sin que ambas situaciones se muestren a la vez.

## Assumptions

- "Módulo de Cocina activo" se refiere a la misma bandera de plan que ya usan hoy el tablero de Cocina y la regla actual de "Entregar" (spec 149/150/151) — no se introduce ninguna bandera nueva.
- "Cobrar y enviar a cocina en un solo paso" reutiliza el mismo comportamiento que ya existe hoy para pedidos creados manualmente en el mostrador, en vez de crear un mecanismo de pago nuevo.
- El paso de "Recibir" un pedido del menú QR (confirmación del mesero/cajero antes de cualquier cobro) y la posibilidad de "Rechazar" un pedido no cobrado no son parte del defecto reportado y se mantienen exactamente como están hoy.
- Este ajuste solo cambia pedidos asociados a una mesa (canal del menú QR); los pedidos de mostrador o domicilio no se modifican porque ya siguen el flujo que aquí se extiende a mesas.
- Los pedidos que, al momento de implementarse este ajuste, ya estén cobrados y en curso hacia cocina/entrega bajo el flujo actual no requieren ninguna migración: siguen su curso con la misma regla de "Entregar solo cuando cocina marca Listo" que ya aplican hoy cuando el módulo está activo.
