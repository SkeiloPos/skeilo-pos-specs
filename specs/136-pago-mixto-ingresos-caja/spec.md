# Feature Specification: Métodos distintos en pago mixto e ingresos de caja por método de pago

**Feature Branch**: `[136-pago-mixto-ingresos-caja]`

**Created**: 2026-10-25

**Status**: Draft

**Input**: User description: "Necesito que implementes algunas características. La primera es que agregues una validación para registrar las órdenes con pagos mixtos: no se debe permitir registrar un pago mixto donde, por ejemplo, ambas líneas sean por efectivo o ambas sean por Nequi. La segunda es que permitas registrar movimientos de ingresos en la caja por método de pago; actualmente solo se permite ingresar todo en efectivo, pero no se permite registrar un ingreso por transferencia. Los ingresos también pueden ser mixtos, por ejemplo que un ingreso sea en efectivo y otro en Nequi, pero nunca del mismo tipo."

## Clarifications

### Session 2026-10-25

- Q: El pago mixto de un pedido hoy permite explícitamente repetir el mismo método en varias líneas (comportamiento vigente desde una spec previa de este mismo sistema, que permite por ejemplo dos pagos en Nequi en el mismo cobro), con hasta 3 líneas por cobro. ¿Se debe revertir esa regla para todo pago mixto de pedidos? → A: Sí, revertir totalmente — en cualquier pago mixto de un pedido (hasta 3 líneas), ninguna línea puede repetir el método de otra línea.
- Q: Para los nuevos ingresos de caja con método distinto a efectivo (ej. un ingreso en Nequi), ¿ese ingreso debe sumar al efectivo físico esperado en el arqueo, o solo debe quedar registrado para el desglose de ese método? → A: Solo afecta su propio método — un ingreso en Nequi aparece en el desglose de Nequi del arqueo, pero no altera el cálculo de efectivo esperado en caja (que sigue siendo solo billetes/monedas).
- Q: ¿Cuántas líneas de método debe permitir un ingreso mixto de caja? → A: Hasta 2 líneas únicamente, cada una con un método distinto.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - El cajero no puede registrar un pago de pedido con el mismo método repetido (Priority: P1)

Un cajero está cobrando un pedido y decide dividir el cobro en varias líneas de pago (por ejemplo, porque el cliente paga parte en un método y parte en otro). Al intentar agregar una segunda línea con el mismo método de pago que ya usó en otra línea del mismo cobro (por ejemplo, Efectivo y Efectivo, o Nequi y Nequi), el sistema le impide guardar el cobro y le indica claramente que cada línea debe usar un método distinto.

**Why this priority**: Es el núcleo del cambio solicitado: evita que se registren pagos "mixtos" que en realidad no combinan métodos distintos, lo cual genera confusión en el arqueo y en los reportes por método de pago. Sin esta historia, el resto del spec no tiene efecto.

**Independent Test**: Se puede probar completamente intentando registrar un cobro con dos líneas que usan el mismo método de pago (por ejemplo, dos líneas de Nequi) y verificando que el sistema rechaza el guardado con un mensaje claro, mientras que un cobro con líneas de métodos distintos (por ejemplo, Efectivo y Nequi) se guarda sin problema.

**Acceptance Scenarios**:

1. **Given** un cajero cobrando un pedido de $100.000, **When** agrega una línea de $60.000 en Nequi y luego otra línea de $40.000 también en Nequi, **Then** el sistema rechaza el intento de guardar el cobro con un mensaje indicando que no puede repetir el mismo método en dos líneas.
2. **Given** un cajero cobrando un pedido de $100.000, **When** agrega una línea de $60.000 en Efectivo y otra línea de $40.000 en Nequi, **Then** el sistema permite guardar el cobro normalmente.
3. **Given** un cajero cobrando un pedido con hasta 3 líneas de pago permitidas, **When** intenta usar el mismo método en dos de las tres líneas (incluso si la tercera línea usa un método distinto), **Then** el sistema rechaza el cobro hasta que las 3 líneas tengan métodos distintos entre sí.
4. **Given** un cajero que ya seleccionó un método en una línea, **When** abre el selector de método para otra línea del mismo cobro, **Then** el sistema no permite seleccionar un método ya usado en otra línea de ese mismo cobro (o, si lo permite seleccionar, rechaza el guardado con el mismo mensaje de error).

---

### User Story 2 - El cajero registra un ingreso de caja en un método distinto a efectivo (Priority: P1)

Un cajero necesita registrar en el turno de caja un ingreso de dinero que no es efectivo físico (por ejemplo, alguien transfiere dinero a la cuenta Nequi del negocio como aporte o préstamo para el turno). Hoy el sistema solo permite registrar ingresos en efectivo. El cajero elige el tipo de movimiento "ingreso", selecciona el método de pago (cualquiera del catálogo del negocio, no solo efectivo), indica el monto y una descripción, y el sistema guarda el movimiento asociado a ese método.

**Why this priority**: Es el segundo pilar del spec: sin esta capacidad, el sistema sigue sin reflejar ingresos que no son efectivo, que es la limitación actual que el negocio necesita resolver. Tiene la misma prioridad crítica que la Historia 1 porque ambas son necesarias para que el spec cumpla su objetivo.

**Independent Test**: Se puede probar completamente registrando un ingreso de caja seleccionando un método distinto a efectivo (por ejemplo, Nequi) con un monto y descripción, y verificando que el movimiento queda guardado con ese método, visible en el historial de movimientos del turno y en el desglose por método del arqueo, sin alterar el efectivo físico esperado del turno.

**Acceptance Scenarios**:

1. **Given** un turno de caja abierto, **When** el cajero registra un ingreso de $50.000 en Nequi con una descripción, **Then** el movimiento queda guardado con método Nequi, aparece en el historial de movimientos del turno, y el efectivo esperado en caja (el que se cuenta en billetes/monedas al cierre) no cambia.
2. **Given** un turno de caja abierto, **When** el cajero registra un ingreso de $50.000 en Efectivo, **Then** el movimiento se comporta igual que hoy: queda guardado, aparece en el historial, y sí incrementa el efectivo esperado en caja.
3. **Given** un turno de caja cerrado, **When** se intenta registrar un ingreso con cualquier método, **Then** el sistema lo impide, igual que ya ocurre hoy para los ingresos en efectivo.
4. **Given** el reporte de arqueo de un turno con ingresos en varios métodos, **When** el cajero o administrador lo consulta, **Then** el desglose por método de pago muestra, para cada método, el total de ingresos registrados en ese método junto con el total de ventas en ese método.

---

### User Story 3 - El cajero registra un ingreso mixto en dos métodos distintos (Priority: P2)

Un cajero recibe un único aporte o ingreso que en realidad se compone de dos pagos distintos (por ejemplo, parte en efectivo y parte en Nequi) y quiere registrarlo como un solo evento de ingreso con dos líneas, una por cada método, en lugar de crear dos movimientos separados sin relación entre sí. El sistema exige que las dos líneas usen métodos distintos entre sí.

**Why this priority**: Aporta valor adicional y cobertura más completa del caso real descrito por el negocio, pero el sistema ya es funcional y resuelve el problema principal con la Historia 2 (ingresos en un solo método no-efectivo) sin esta historia; por eso es P2.

**Independent Test**: Se puede probar completamente registrando un ingreso con dos líneas (por ejemplo, $20.000 en Efectivo y $30.000 en Nequi) y verificando que ambas líneas quedan asociadas al mismo evento de ingreso, que el efectivo esperado en caja solo se incrementa en $20.000, y que un intento de registrar las dos líneas con el mismo método es rechazado.

**Acceptance Scenarios**:

1. **Given** un turno de caja abierto, **When** el cajero registra un ingreso mixto con una línea de $20.000 en Efectivo y otra de $30.000 en Nequi, **Then** el sistema guarda ambas líneas asociadas al mismo evento de ingreso, incrementa el efectivo esperado en caja solo en $20.000, y refleja $30.000 adicionales en el desglose de Nequi del arqueo.
2. **Given** un cajero registrando un ingreso mixto, **When** intenta usar el mismo método en ambas líneas (por ejemplo, Efectivo y Efectivo, o Nequi y Nequi), **Then** el sistema rechaza el guardado con un mensaje indicando que las líneas deben usar métodos distintos.
3. **Given** un cajero registrando un ingreso mixto, **When** intenta agregar una tercera línea, **Then** el sistema no lo permite; un ingreso admite como máximo 2 líneas.
4. **Given** un ingreso mixto ya guardado, **When** se consulta el historial de movimientos del turno, **Then** se puede identificar que ambas líneas corresponden a un mismo evento de ingreso (por ejemplo, mediante la misma hora, descripción y un identificador de grupo visibles juntos).

---

### Edge Cases

- ¿Qué pasa si el cajero intenta registrar un pago mixto de pedido o un ingreso mixto con una sola línea después de haber agregado una segunda? Debe tratarse igual que cualquier pago/ingreso de un solo método; la validación de métodos distintos solo aplica cuando hay 2 o más líneas.
- ¿Qué pasa si el negocio (tenant) solo tiene configurado un único método de pago activo en su catálogo? El sistema no puede ofrecer un pago mixto ni un ingreso mixto en ese caso (no hay un segundo método distinto disponible); el selector de un segundo método debe quedar vacío o deshabilitado, y el sistema no debe permitir forzar una segunda línea sin un método distinto real disponible.
- ¿Qué pasa si un método de pago se desactiva en el catálogo después de haber sido usado en una línea de un pago o ingreso mixto ya guardado? El registro histórico no se modifica; la restricción de "métodos distintos" solo aplica al momento de crear o editar el pago/ingreso, no retroactivamente.
- ¿Qué pasa con los movimientos de egreso o retiro de caja? Quedan fuera de alcance de este spec; siguen funcionando únicamente en efectivo como hoy.
- ¿Qué pasa si el cajero intenta editar un pago de pedido o un ingreso de caja ya guardado y, al editarlo, el resultado quedaría con dos líneas del mismo método? El sistema aplica la misma validación al guardar la edición que al crear el registro por primera vez.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST impedir que se guarde un cobro de pedido con dos o más líneas de pago cuyo método de pago sea el mismo, exigiendo que cada línea de un mismo cobro use un método distinto a las demás líneas de ese cobro.
- **FR-002**: El sistema MUST mostrar un mensaje claro cuando se rechace el guardado de un cobro por repetir el mismo método en más de una línea, indicando cuál método está repetido.
- **FR-003**: La validación de métodos distintos en FR-001 MUST aplicar sin importar el número de líneas del cobro (2 o 3 líneas, según el máximo vigente del flujo de pago mixto de pedidos).
- **FR-004**: El sistema MUST permitir que el cajero registre un movimiento de ingreso de caja usando cualquier método de pago activo del catálogo del negocio, no solo efectivo.
- **FR-005**: El sistema MUST permitir que un movimiento de ingreso de caja se componga de hasta 2 líneas, cada una con su propio método de pago y su propio monto.
- **FR-006**: El sistema MUST impedir que se guarde un ingreso mixto cuyas 2 líneas usen el mismo método de pago, exigiendo que ambas líneas usen métodos distintos, con el mismo criterio de rechazo y mensaje claro que FR-001/FR-002.
- **FR-007**: El sistema MUST calcular el efectivo esperado en caja (el que se cuenta en billetes y monedas al cierre del turno) sumando únicamente los ingresos cuya línea use el método de tipo efectivo, sin incluir ingresos registrados en otros métodos de pago.
- **FR-008**: El sistema MUST incluir los ingresos registrados en métodos distintos a efectivo en el desglose por método de pago del reporte de arqueo del turno, junto con las ventas de ese mismo método.
- **FR-009**: El sistema MUST mantener, sin cambios, el comportamiento actual de los ingresos registrados en efectivo: siguen incrementando el efectivo esperado en caja y siguen apareciendo en el historial de movimientos del turno.
- **FR-010**: El sistema MUST permitir registrar un ingreso de caja (de un solo método o mixto) únicamente mientras el turno de caja esté abierto, igual que ya ocurre hoy para los ingresos en efectivo.
- **FR-011**: El sistema MUST registrar, para cada línea de un ingreso de caja, el método de pago usado, el monto, la hora y el usuario responsable, y MUST permitir identificar que dos o más líneas pertenecen al mismo evento de ingreso cuando el ingreso es mixto.
- **FR-012**: El sistema MUST dejar fuera de esta validación y de esta capacidad a los movimientos de egreso y retiro de caja, que continúan registrándose únicamente en efectivo.
- **FR-013**: El sistema MUST deshabilitar o impedir que el cajero intente agregar una segunda línea de pago o de ingreso mixto cuando el negocio no tenga disponible ningún método de pago activo distinto al ya usado en la primera línea.
- **FR-014**: El sistema MUST restringir el registro y la consulta de movimientos de ingreso por método de pago exclusivamente a usuarios del mismo negocio (tenant) al que pertenece el turno de caja.

### Key Entities *(include if feature involves data)*

- **Línea de pago de pedido**: Representa una parte del cobro de un pedido, con un método de pago del catálogo del negocio y un monto. Varias líneas pertenecen al mismo cobro cuando el pago es mixto; dentro de un mismo cobro, ninguna línea puede repetir el método de otra.
- **Movimiento de ingreso de caja**: Representa un ingreso manual de dinero dentro de un turno de caja abierto. Puede tener una o dos líneas, cada una con su propio método de pago y monto; cuando tiene dos líneas, ambas deben usar métodos distintos entre sí. Solo la porción registrada en el método de tipo efectivo afecta el efectivo esperado en caja; el resto se refleja en el desglose por método del arqueo.
- **Método de pago**: Entrada del catálogo de métodos de pago del negocio (por ejemplo Efectivo, Nequi, Bancolombia, Tarjeta), usada tanto para identificar el método de una línea de pago de pedido como de una línea de ingreso de caja.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100% de los intentos de guardar un cobro de pedido o un ingreso de caja con dos líneas del mismo método de pago son rechazados antes de guardarse, con un mensaje que identifica el método repetido.
- **SC-002**: El 100% de los ingresos de caja registrados en un método distinto a efectivo quedan visibles en el desglose por método del arqueo del turno, sin alterar el efectivo esperado en caja.
- **SC-003**: Un cajero puede registrar un ingreso de caja en cualquier método activo del negocio (de un solo método o mixto en 2 métodos distintos) en menos de 30 segundos, sin pasos adicionales a los que ya usa hoy para un ingreso en efectivo.
- **SC-004**: Cero movimientos de egreso o retiro de caja se ven afectados por este cambio; su comportamiento y su restricción a efectivo permanecen idénticos a los existentes antes de esta implementación.

## Assumptions

- El máximo de líneas vigente para el pago mixto de un pedido (hasta 3 líneas) no cambia con este spec; solo se agrega la exigencia de que esas líneas usen métodos distintos entre sí.
- La identificación de "método" para efectos de la validación de "no repetir" es la entrada específica del catálogo del negocio (por ejemplo, "Nequi" y "Bancolombia" cuentan como métodos distintos entre sí aunque ambos sean de tipo transferencia), no la categoría genérica (efectivo/transferencia/tarjeta/otro).
- Los movimientos de egreso y retiro de caja quedan explícitamente fuera de alcance de este spec y continúan operando solo en efectivo, ya que el pedido del usuario se limitó a pagos de pedidos e ingresos.
- Un ingreso mixto de caja se trata como un solo evento con hasta 2 líneas relacionadas (no como dos movimientos independientes sin relación entre sí), de forma análoga a como un pago mixto de pedido agrupa varias líneas en un mismo cobro.
- Esta spec no introduce nuevos métodos de pago ni cambia el catálogo de métodos del negocio (spec existente de catálogo de métodos de pago); solo cambia las reglas de validación de combinación de métodos en pagos de pedidos e ingresos de caja.
