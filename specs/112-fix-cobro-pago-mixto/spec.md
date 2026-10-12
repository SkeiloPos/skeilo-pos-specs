# Feature Specification: Cobro de pedido con múltiples métodos de pago

**Feature Branch**: `112-fix-cobro-pago-mixto`

**Created**: 2026-10-11

**Status**: Draft

**Naturaleza de esta spec**: **spec de corrección que revierte, de forma explícita y acotada, una
decisión de negocio anterior**. La spec [046](../046-dividir-cuenta-pago-pendiente/spec.md)
(FR-006/FR-007) eliminó por completo la capacidad de combinar métodos de pago en un mismo cobro
(introducida por la spec [011](../011-venta-mostrador-constructor-factura/spec.md)), como decisión
escalada del dueño del producto el 2026-08-28. Esta spec 112 **reintroduce esa capacidad**, ahora
acotada con reglas que spec 046 no tenía: máximo 3 líneas de pago (RN3), suma exacta contra el
total incluyendo cargos adicionales (RN1, RN10), vuelto calculado solo sobre la porción en
efectivo (RN2), y referencia opcional por línea no efectivo (RN5). No reabre "Dividir la cuenta
entre varias personas" (spec 010/036/046), que permanece eliminada.

**Autorización de negocio (Principio I y Principio II de la
[Constitución](../../.specify/memory/constitution.md))**: solicitado directamente por el
dueño/desarrollador del proyecto el 2026-10-11, confirmando explícitamente que la reversión de la
decisión de spec 046 es intencional. Registrado como
[`A-124` en `registro-de-anomalias.md`](../000-reconocimiento/registro-de-anomalias.md) con el
detalle de qué cambia, por qué, y qué queda sin afectar (el modelo `Payment`/`Sale`, el catálogo
de métodos por tenant de spec 032, el cierre de caja de spec 006 y el comprobante del pedido ya
soportaban varias líneas de pago y no requieren cambio).

**Input**: User description: "Como cajero de la heladería, quiero registrar el cobro de un pedido repartiendo el total entre varios métodos de pago, como efectivo y transferencia, para cobrar cuando el cliente no puede o no quiere pagar todo con un solo medio, y que el cierre de caja refleje cuánto entró por cada método. Hoy el panel 'Cobrar pedido' solo permite un método, lo que deja datos falsos en caja cuando el cliente paga con dos medios. Se trata como un fix sobre el flujo de cobro existente (Mesa, Para llevar, Domicilio)."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Cobrar un pedido repartiendo el pago entre varios métodos (Priority: P1)

Un cajero atiende a un cliente que quiere pagar parte en efectivo y parte por transferencia. El cajero agrega una línea de pago por cada método, asigna el monto que corresponde a cada una, y confirma el cobro una sola vez. El sistema solo acepta el cobro cuando la suma de los montos asignados coincide exactamente con el total del pedido (incluyendo domicilio u otros cargos), y registra todos los pagos juntos, con el usuario que los confirmó y la fecha/hora.

**Why this priority**: Es el problema que origina el fix: hoy no existe forma de registrar un cobro dividido, y el cajero termina registrando montos que no reflejan lo que realmente entró en caja por cada medio.

**Independent Test**: Puede probarse abriendo el detalle de un pedido con total conocido, asignando dos líneas de pago (efectivo y transferencia) que sumen el total, y confirmando que el pedido queda "Pagado" con dos pagos registrados que suman el total.

**Acceptance Scenarios**:

1. **Given** un pedido de tipo Mesa, Para llevar o Domicilio con un total definido, **When** el cajero asigna "Efectivo" por una parte y "Transferencia" por el resto, y pulsa "Cobrar", **Then** el pedido queda en estado "Pagado" y quedan registrados dos pagos cuya suma es igual al total del pedido.
2. **Given** un pedido de Domicilio cuyo total incluye productos más costo de envío, **When** el cajero asigna montos que solo cubren el valor de los productos, **Then** el sistema muestra "Faltan $[monto] por asignar" (la diferencia contra el total con envío) y el botón "Cobrar" permanece deshabilitado.
3. **Given** que el cajero ya tiene una línea de pago en efectivo por una parte del total, **When** pulsa "Agregar otro método", **Then** se crea una segunda línea de pago precargada con el saldo pendiente, y el cajero puede elegir el método de esa línea.
4. **Given** que los montos asignados no cubren el total del pedido, **Then** el sistema muestra "Faltan $[monto] por asignar" y el botón "Cobrar" permanece deshabilitado hasta que la suma sea exacta.
5. **Given** que ya hay un monto asignado a efectivo que cubre parte del total, **When** el cajero asigna a una línea de transferencia un monto mayor al saldo pendiente, **Then** el sistema muestra "La transferencia no puede superar el saldo pendiente ($[saldo])" y el botón "Cobrar" permanece deshabilitado.
6. **Given** que el cajero tiene dos o más líneas de pago agregadas, **When** elimina una de ellas, **Then** el saldo pendiente se recalcula de inmediato y se muestra actualizado ("Faltan $[monto] por asignar" si ya no cubre el total).
7. **Given** que el cajero asignó montos en dos o más métodos y pulsa "Cobrar", **When** el servidor responde con un error al registrar el cobro, **Then** el pedido permanece "Sin cobrar", no queda registrado ningún pago, y las líneas de pago que el cajero ingresó se conservan en pantalla para reintentar.

---

### User Story 2 - Cobrar con un solo método sin pasos adicionales (Priority: P1)

Un cajero que recibe el pago completo en un solo medio (por ejemplo, todo en efectivo) debe poder cobrar con la misma rapidez que antes del cambio: elige el método, el monto se precarga con el total del pedido, y confirma. El flujo de pago mixto no debe introducir pasos ni fricción cuando solo se usa un método.

**Why this priority**: El pago con un solo método es el caso más frecuente en el día a día de la heladería; si se vuelve más lento o confuso, el fix introduce un regreso neto para el negocio aunque resuelva el caso de pago mixto.

**Independent Test**: Puede probarse eligiendo un único método de pago en el panel de cobro sin agregar líneas adicionales, confirmando que el monto se precarga con el total y que "Cobrar" registra un único pago por el total completo.

**Acceptance Scenarios**:

1. **Given** que el cajero abre el panel "Cobrar pedido" y elige "Efectivo" sin agregar otro método, **When** la línea se precarga con el total del pedido y el cajero pulsa "Cobrar", **Then** el pedido queda "Pagado" con un único pago en efectivo por el total completo, sin pasos adicionales respecto al flujo actual.
2. **Given** cualquier tipo de pedido (Mesa, Para llevar, Domicilio), **When** se cobra con un solo método, **Then** el comportamiento del panel de cobro es el mismo en los tres tipos de pedido.

---

### User Story 3 - Calcular el vuelto solo sobre la porción en efectivo (Priority: P2)

Cuando una de las líneas de pago es en efectivo, el cajero puede indicar con cuánto dinero paga el cliente para esa porción. El sistema calcula el cambio únicamente sobre el monto asignado a efectivo, nunca sobre el total del pedido ni sobre otros métodos, y el cierre de caja registra el monto neto que efectivamente entró en efectivo (sin el vuelto entregado).

**Why this priority**: Es la regla que evita que el cierre de caja quede inflado o descuadrado cuando hay vuelto de por medio en un cobro mixto; depende de que la Historia 1 ya exista.

**Independent Test**: Puede probarse creando un cobro mixto con una línea de efectivo y una de transferencia, ingresando en la línea de efectivo un monto "con cuánto paga" mayor al asignado, y verificando que el cambio mostrado corresponde solo a esa diferencia y que el cierre de caja registra el monto neto de efectivo.

**Acceptance Scenarios**:

1. **Given** una línea de transferencia y una línea de efectivo ya asignadas, **When** el cajero escribe en "Con cuánto paga" de la línea de efectivo un monto mayor al asignado a esa línea, **Then** el sistema muestra "Cambio: $[diferencia]" calculado solo sobre la porción en efectivo.
2. **Given** el escenario anterior, **Then** el cierre de caja registra como ingreso en efectivo el monto asignado a esa línea (neto, sin el vuelto), no el monto con el que pagó el cliente.
3. **Given** una línea de transferencia, **When** el cajero intenta asignarle un monto mayor al saldo pendiente, **Then** el sistema lo rechaza, ya que únicamente el efectivo admite recibir más dinero del asignado.

---

### User Story 4 - Ver el desglose por método en el cierre de caja y el comprobante (Priority: P2)

El responsable del cierre de caja y el cliente que recibe el comprobante necesitan ver cuánto entró por cada método de pago, no solo el total cobrado. Esto aplica a pedidos cobrados con un solo método y a pedidos con pago mixto.

**Why this priority**: Sin este desglose, el cierre de caja sigue mostrando datos agregados que no permiten arquear cada medio de pago por separado, que es el problema original reportado.

**Independent Test**: Puede probarse cobrando un pedido con pago mixto y verificando que tanto el comprobante del pedido como el cierre de caja del turno muestran los montos separados por método, cuya suma coincide con el total cobrado.

**Acceptance Scenarios**:

1. **Given** un pedido cobrado con dos o más métodos de pago, **When** se genera el comprobante del pedido, **Then** el comprobante muestra el monto cobrado por cada método.
2. **Given** uno o más pedidos cobrados con pago mixto dentro de un turno, **When** se realiza el cierre de caja de ese turno, **Then** el cierre muestra el total recibido por cada método de pago, sumando correctamente los montos de todos los pedidos del turno.

---

### User Story 5 - Mantener el momento correcto de cobro en Domicilio y la liberación de Mesa (Priority: P3)

En pedidos de Domicilio, el pedido permanece "Sin cobrar" hasta que el pago (en cualquier combinación de métodos) quede efectivamente registrado, incluso si el pedido ya fue despachado. En pedidos de Mesa, al completarse el cobro (de uno o varios métodos) la mesa vuelve a estado "Libre" en la terminal, igual que ocurre hoy con un solo método.

**Why this priority**: Preserva reglas de negocio existentes (estado de cobro de Domicilio y liberación de Mesa) que no deben romperse al introducir el pago mixto; es una validación de no regresión más que una capacidad nueva.

**Independent Test**: Puede probarse despachando un pedido de Domicilio sin registrar pago y verificando que sigue "Sin cobrar" y fuera del cierre de caja; y cobrando un pedido de Mesa con pago mixto y verificando que la mesa queda "Libre" y el contador de mesas ocupadas disminuye.

**Acceptance Scenarios**:

1. **Given** un pedido de Domicilio en estado "Despachado" sin ningún pago registrado, **Then** el pedido aparece como "Sin cobrar" en la pestaña de Domicilios y su monto no se incluye en el cierre de caja.
2. **Given** un pedido de Mesa cobrado con pago mixto (por ejemplo, efectivo y transferencia), **When** se vuelve a la terminal en la pestaña de Mesas, **Then** la mesa correspondiente aparece como "Libre" y el contador de mesas ocupadas disminuye en 1.

---

### Edge Cases

- ¿Qué pasa si el cajero intenta agregar una cuarta línea de pago? El sistema debe impedirlo, ya que el máximo son 3 líneas por pedido.
- ¿Qué pasa si el cajero asigna el mismo método dos veces (por ejemplo, dos transferencias de personas distintas)? Debe permitirse, siempre que la suma total siga siendo exacta.
- ¿Qué pasa si el cajero no indica "Con cuánto paga" en la línea de efectivo? Se asume que paga exactamente el monto asignado a esa línea, sin cambio.
- ¿Qué pasa si el cajero cambia el método de una línea después de haber escrito un monto? El saldo pendiente debe recalcularse según el nuevo método (por ejemplo, un monto que antes permitía vuelto en efectivo ya no lo permite si la línea pasa a transferencia).
- ¿Qué pasa si el cajero elimina todas las líneas de pago? El saldo pendiente vuelve a ser el total completo del pedido y el botón "Cobrar" permanece deshabilitado.
- ¿Qué pasa si los métodos de pago configurados para el tenant cambian (se agrega o elimina uno) mientras el cajero tiene el panel abierto? El panel debe reflejar los métodos vigentes de la configuración del tenant, no una lista fija.
- ¿Qué pasa con un pedido que ya fue cobrado antes de este cambio, con el modelo de un solo método? Debe seguir siendo consultable y mostrar su único pago, sin necesidad de migración retroactiva a múltiples líneas.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST permitir registrar el cobro de un pedido mediante una o varias líneas de pago, cada una con un método y un monto.
- **FR-002**: El sistema MUST exigir que la suma de los montos asignados en todas las líneas de pago sea exactamente igual al total a cobrar del pedido (incluyendo costo de domicilio y otros cargos) antes de permitir confirmar el cobro.
- **FR-003**: El sistema MUST mostrar al cajero el saldo pendiente de asignar ("Faltan $[monto] por asignar") mientras la suma de las líneas no alcance el total, y MUST mantener deshabilitado el botón "Cobrar" en ese caso.
- **FR-004**: El sistema MUST permitir hasta un máximo de 3 líneas de pago por pedido, y MUST impedir agregar una línea adicional al llegar a ese límite.
- **FR-005**: El sistema MUST permitir que un mismo método de pago se use en más de una línea dentro del mismo cobro (por ejemplo, dos transferencias distintas).
- **FR-006**: El sistema MUST permitir que, únicamente en una línea de efectivo, el monto con el que paga el cliente sea mayor al monto asignado a esa línea, y MUST calcular el cambio solo sobre esa diferencia.
- **FR-007**: El sistema MUST impedir que una línea de un método distinto a efectivo (por ejemplo, transferencia) tenga un monto mayor al saldo pendiente en el momento de asignarla, mostrando el error "La transferencia no puede superar el saldo pendiente ($[saldo])" (u el nombre del método correspondiente) y manteniendo deshabilitado el botón "Cobrar".
- **FR-008**: El sistema MUST registrar, para el cierre de caja, el monto neto recibido en efectivo (el monto asignado a la línea, sin el vuelto entregado), no el monto con el que pagó el cliente.
- **FR-009**: El sistema MUST registrar todos los pagos de un cobro de forma conjunta al confirmar "Cobrar": si el registro falla, el sistema MUST dejar el pedido en su estado anterior ("Sin cobrar") sin registrar ningún pago parcial, y MUST conservar en pantalla las líneas de pago ingresadas para que el cajero pueda reintentar.
- **FR-010**: El sistema MUST permitir eliminar una línea de pago ya agregada y MUST recalcular de inmediato el saldo pendiente tras la eliminación.
- **FR-011**: Para líneas de pago con un método distinto a efectivo, el sistema MUST ofrecer un campo opcional de referencia (por ejemplo, últimos 4 dígitos o número de comprobante de una transferencia), sin exigirlo para poder cobrar.
- **FR-012**: El sistema MUST registrar, para cada pago confirmado, el usuario que lo confirmó y la fecha y hora en que se confirmó.
- **FR-013**: El sistema MUST obtener la lista de métodos de pago disponibles desde la configuración del tenant, de forma que agregar, quitar o renombrar un método no requiera un cambio de código.
- **FR-014**: El sistema MUST permitir cobrar con un único método de pago con la misma rapidez que el flujo actual: al elegir un método sin agregar otro, el monto de esa línea MUST precargarse con el total del pedido.
- **FR-015**: El panel de cobro MUST comportarse de forma idéntica para pedidos de Mesa, Para llevar y Domicilio (mismas reglas de validación, límites y mensajes), sin variaciones específicas por tipo de pedido.
- **FR-016**: El total a cubrir en el panel de cobro MUST incluir el valor de los productos más cualquier cargo adicional del pedido (por ejemplo, costo de domicilio), y la validación de suma exacta (FR-002) MUST aplicarse sobre ese total completo.
- **FR-017**: Para pedidos de Domicilio, el sistema MUST mantener el pedido en estado "Sin cobrar" mientras no se haya registrado el cobro completo, incluso si el pedido ya está en estado "Despachado", y MUST excluir su monto del cierre de caja hasta que el cobro quede registrado.
- **FR-018**: Para pedidos de Mesa, al confirmarse el cobro (de uno o varios métodos) el sistema MUST liberar la mesa asociada a estado "Libre", igual que ocurre hoy al cobrar con un solo método.
- **FR-019**: El cierre de caja MUST mostrar el monto total recibido por cada método de pago, sumando los montos de todos los pedidos cobrados dentro del turno.
- **FR-020**: El comprobante de un pedido cobrado con más de un método MUST mostrar el desglose de montos por método de pago.

### Key Entities

- **Pago (línea de pago)**: Un monto asignado a un método de pago dentro del cobro de un pedido. Atributos: método, monto asignado, monto recibido (solo aplica a efectivo, para calcular el cambio), referencia opcional (métodos distintos a efectivo), usuario que confirmó, fecha y hora de confirmación. Varios pagos pertenecen a un mismo cobro de pedido.
- **Cobro de pedido**: El conjunto de pagos (una o varias líneas) que se registran juntos al confirmar "Cobrar" para un pedido. Tiene un total exigido (igual al total del pedido) y solo se confirma de forma atómica: todos los pagos quedan registrados o ninguno.
- **Método de pago**: Una forma de pago configurada por el tenant (por ejemplo, Efectivo, Transferencia Nequi, Transferencia Daviplata). Define si admite recibir más dinero del asignado (vuelto) y si ofrece un campo de referencia opcional.
- **Pedido**: La orden de Mesa, Para llevar o Domicilio que se está cobrando. Tiene un total a cubrir que incluye productos y cargos adicionales (como domicilio), y un estado de cobro ("Sin cobrar" / "Pagado") independiente de su estado operativo (por ejemplo, "Despachado").
- **Cierre de caja**: El resumen de un turno que agrega los montos recibidos por método de pago a partir de los cobros registrados en ese turno.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100% de los intentos de cobro cuya suma de líneas de pago no coincide exactamente con el total del pedido son rechazados antes de registrar ningún pago.
- **SC-002**: El cierre de caja de un turno con pagos mixtos refleja, para cada método de pago, exactamente la suma de los montos netos (sin vueltos) registrados en ese turno, con 0 discrepancias frente a los pagos individuales.
- **SC-003**: Un cajero puede completar un cobro de un solo método en la misma cantidad de pasos que antes del cambio (elegir método, monto precargado, confirmar).
- **SC-004**: El 100% de los pedidos de Domicilio despachados sin pago registrado continúan mostrándose como "Sin cobrar" y quedan excluidos del cierre de caja hasta que el pago se registre.
- **SC-005**: El 100% de los cobros de Mesa (con uno o varios métodos de pago) liberan la mesa a estado "Libre" inmediatamente después de confirmarse.
- **SC-006**: Ante una falla del servidor durante el cobro, el 100% de los intentos dejan el pedido en "Sin cobrar" sin pagos parciales registrados, y el cajero puede reintentar sin volver a escribir las líneas de pago.

## Assumptions

- Los métodos de pago disponibles (efectivo, transferencia y sus variantes como Nequi, Daviplata, Bancolombia) ya existen o se gestionan en la configuración de métodos de pago por tenant; este fix reutiliza ese catálogo y no introduce una pantalla nueva de administración de métodos.
- El límite de 3 líneas de pago por pedido es un valor razonable para los casos reales de la heladería; es ajustable si el negocio indica otro número, pero no bloquea el alcance de este fix.
- El sistema ya identifica al usuario autenticado (cajero) que realiza las acciones en la terminal, por lo que registrar "quién confirmó el pago" reutiliza esa identidad existente, sin requerir un paso de autenticación adicional.
- No se introduce un estado "parcialmente pagado" ni un flujo de pagos parciales persistidos entre visitas del cajero al panel: mientras no se confirme "Cobrar", las líneas de pago son solo un borrador en pantalla (ver FR-009).
- Los pedidos ya cobrados antes de este fix, con el modelo de un solo método de pago, permanecen consultables con su único pago tal como quedaron registrados, sin necesidad de migrarlos a múltiples líneas.
- La liberación de la mesa al cobrar (hoy ligada al método único) se preserva como comportamiento existente y se adapta para dispararse al completar el cobro, sin importar si el cobro fue de uno o varios métodos.
