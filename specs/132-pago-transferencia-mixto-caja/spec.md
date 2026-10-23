# Feature Specification: Pago por transferencia y pago mixto sin subida de comprobante, con verificación del cajero

**Feature Branch**: `[132-pago-transferencia-mixto-caja]`

**Created**: 2026-10-23

**Status**: Draft

**Input**: User description: "Hoy no existe soporte para validar comprobantes bancarios. Permitir que el comensal suba un comprobante desde el QR agrega fricción y un control que no protege (una imagen subida no se puede validar). Objetivo: que el comensal pueda pagar por transferencia o con pago mixto (efectivo + transferencia) desde el QR sin subir ningún comprobante, y que la verificación de la transferencia la haga el cajero en persona, igual que en el flujo manual actual. Este spec elimina la subida de comprobante por el comensal en ambos métodos y unifica la verificación en caja."

## Clarifications

### Session 2026-10-23

- Q: Cuando el sistema verifica si "el mismo cliente o mesa" acumula un segundo rechazo de pago en el mismo día (FR-020), ¿cómo identifica a ese cliente o mesa, dado que los pedidos desde el QR no requieren login ni cuenta de cliente? → A: Por mesa (identificador físico de la mesa) únicamente; se cuentan los rechazos por mesa y día.
- Q: Cuando el cajero adjunta la foto opcional del comprobante al confirmar un pago (FR-012), ¿el sistema debe almacenar el archivo de imagen, o basta con un indicador booleano ("comprobante revisado") quedando la foto real solo en el chat de WhatsApp del negocio? → A: El sistema almacena el archivo de la foto como evidencia opcional en el registro del pago.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Comensal paga 100% por transferencia desde el QR (Priority: P1)

Un comensal arma su pedido desde el QR y elige pagar el total por transferencia bancaria. El sistema le muestra el monto exacto a transferir y una instrucción de referencia (mesa/pedido) para incluir en el mensaje de la transferencia, junto con el aviso de que debe mostrar el comprobante desde la app de su banco al cajero cuando le entreguen el pedido. El comensal confirma el pedido sin subir ningún archivo, y el pedido pasa a preparación de inmediato.

**Why this priority**: Es el caso más simple y el que elimina de forma más directa la fricción actual (subida de imagen) y el falso control de seguridad que no protege al negocio. Sin esta historia no hay forma de validar el cambio central del spec.

**Independent Test**: Se puede probar completamente creando un pedido en el QR, seleccionando "Transferencia", confirmando sin adjuntar ningún archivo, y verificando que el pedido queda en estado de espera de pago con un único registro de pago por el total.

**Acceptance Scenarios**:

1. **Given** un comensal con un pedido armado de total $50.000, **When** elige "Transferencia" y confirma el pedido, **Then** el sistema muestra "Transfiere $50.000" junto con la instrucción de referencia, no solicita ningún archivo, y el pedido pasa a preparación.
2. **Given** un pedido confirmado por transferencia, **When** se consulta su estado de pago, **Then** existe un único registro de pago con método transferencia, monto esperado igual al total, y estado "pendiente de verificación".

---

### User Story 2 - Comensal paga con pago mixto (efectivo + transferencia) desde el QR (Priority: P1)

Un comensal arma su pedido desde el QR y elige pago mixto. Ingresa cuánto pagará en efectivo; el sistema calcula automáticamente el monto restante a transferir y muestra ambos montos junto con la instrucción de referencia y el aviso de mostrar el comprobante al cajero. El comensal confirma el pedido sin subir ningún archivo.

**Why this priority**: El pago mixto es un caso de uso real y frecuente (comensales que no tienen el efectivo completo). Comparte toda la mecánica de verificación con la Historia 1, por lo que tiene la misma prioridad crítica para validar el flujo central.

**Independent Test**: Se puede probar completamente ingresando un monto de efectivo válido (mayor que $0 y menor que el total) en un pedido con pago mixto, confirmando sin adjuntar archivos, y verificando que se crean dos registros de pago (efectivo y transferencia) cuya suma es igual al total.

**Acceptance Scenarios**:

1. **Given** un pedido de total $50.000, **When** el comensal elige pago mixto e ingresa $20.000 en efectivo, **Then** el sistema muestra "Transfiere $30.000" junto con la instrucción de referencia, y permite confirmar sin subir archivos.
2. **Given** un pedido de total $50.000, **When** el comensal intenta ingresar $0 o $50.000 como efectivo en pago mixto, **Then** el sistema rechaza el valor con un mensaje claro que indica usar "Efectivo" o "Transferencia" en su lugar.
3. **Given** un pedido confirmado con pago mixto ($20.000 efectivo / $30.000 transferencia), **When** se consulta su estado de pago, **Then** existen dos registros de pago (uno por método) cuya suma de montos esperados es igual al total del pedido.

---

### User Story 3 - El cajero verifica la transferencia en la mesa y confirma el pago antes de entregar (Priority: P1)

Cuando el pedido está listo, el cajero lo lleva a la mesa. Antes de entregarlo, verifica en persona que el cliente tiene la app de su banco abierta (no solo una imagen), que el monto coincide con lo esperado y, si hay referencia en el mensaje, que corresponde a la mesa/pedido. El cajero puede tomar una foto del comprobante para el chat de WhatsApp del negocio, pero subirla al sistema es opcional y nunca bloquea la confirmación. Al presionar "Confirmar pago" en caja, el pedido pasa a pagado y solo entonces se entrega.

**Why this priority**: Es el corazón del spec: unifica en caja la responsabilidad de verificación que hoy intenta (sin éxito) delegarse en una subida de imagen. Sin esta historia, las Historias 1 y 2 solo crean pedidos pendientes de pago sin forma de cerrarlos.

**Independent Test**: Se puede probar completamente tomando un pedido con pagos pendientes (de transferencia o mixto), confirmando el pago desde caja sin adjuntar foto, y verificando que el pedido pasa a pagado y queda habilitado para entrega.

**Acceptance Scenarios**:

1. **Given** un pedido con un pago de transferencia pendiente, **When** el cajero presiona "Confirmar pago" sin adjuntar foto, **Then** el pago pasa a confirmado, el pedido pasa a pagado, y la ausencia de foto no genera ningún error ni advertencia bloqueante.
2. **Given** un pedido con pago mixto pendiente, **When** el cajero confirma el pago, **Then** ambos registros de pago (efectivo y transferencia) pasan a confirmados y el pedido pasa a pagado.
3. **Given** un pedido que aún tiene pagos pendientes, **When** se intenta marcar el pedido como entregado, **Then** el sistema no permite la entrega hasta que el cajero haya confirmado el pago.

---

### User Story 4 - El cajero ajusta la división de pago al confirmar (Priority: P2)

Si el comensal declaró un monto de efectivo que no tiene al momento de pagar, o decide pagar de forma distinta a lo declarado en el QR, el cajero puede reajustar la división entre efectivo y transferencia al momento de confirmar, siempre que la suma de ambos sea igual al total del pedido. Esto aplica también a pedidos declarados como transferencia total, que el cajero puede convertir en mixto o en efectivo total. El pedido no se cancela por este ajuste, y el cambio queda registrado con los valores originales y finales.

**Why this priority**: Resuelve una situación real y frecuente en el mostrador, pero el flujo base (Historias 1-3) puede operar y entregarse sin esta capacidad en una primera iteración; por eso es P2 y no P1.

**Independent Test**: Se puede probar completamente tomando un pedido de transferencia total, reajustándolo a mixto con un nuevo monto de efectivo en el momento de la confirmación, y verificando que el pedido queda pagado con la nueva división y que el ajuste quedó registrado en auditoría con los valores previos y finales.

**Acceptance Scenarios**:

1. **Given** un pedido declarado como transferencia total de $50.000, **When** el comensal paga $20.000 en efectivo en la mesa, **Then** el cajero reajusta la división a $20.000 efectivo / $30.000 transferencia, confirma, y el pedido pasa a pagado con esa nueva división.
2. **Given** un reajuste de división, **When** se consulta el historial del pedido, **Then** queda registrado qué montos se declararon originalmente y cuáles fueron los montos finales confirmados, junto con el cajero y la hora.
3. **Given** un intento de reajuste donde efectivo + transferencia no es igual al total, **When** el cajero intenta confirmar, **Then** el sistema rechaza el ajuste con un mensaje claro.

---

### User Story 5 - El cajero rechaza la verificación y resuelve la situación (Priority: P2)

Si en la mesa el cajero no puede verificar la transferencia (el cliente no muestra la app del banco, el monto no coincide, la transferencia falló, el cliente se niega a mostrar el comprobante, o el comprobante parece sospechoso), el cajero rechaza el pago indicando un motivo obligatorio. El pedido no se entrega y queda pendiente de pago. El cajero ofrece entonces, en orden, pagar el total en efectivo en el momento, o corregir y reintentar la transferencia una sola vez. Si ninguna opción funciona, el cajero cancela el pedido como impago, lo que lo registra como merma.

**Why this priority**: Cubre el camino de excepción necesario para que el flujo sea operable en el mundo real, pero depende de que el camino feliz (Historias 1-3) ya exista; por eso es P2.

**Independent Test**: Se puede probar completamente rechazando un pago de transferencia con un motivo, verificando que el pedido queda pendiente de pago y no se puede entregar, y luego resolviendo por cada una de las tres salidas (efectivo total, reintento, cancelación por impago) en pruebas separadas.

**Acceptance Scenarios**:

1. **Given** un pago de transferencia pendiente, **When** el cajero lo rechaza sin indicar motivo, **Then** el sistema no permite el rechazo hasta que se seleccione un motivo de la lista definida.
2. **Given** un pago de transferencia rechazado, **When** el cliente paga el total en efectivo en el momento, **Then** el cajero anula el pago de transferencia, ajusta o crea el pago en efectivo por el total, confirma, y el pedido pasa a pagado y se entrega.
3. **Given** un pago de transferencia rechazado, **When** el cliente corrige y reintenta la transferencia y el cajero la verifica, **Then** el pago se confirma y el pedido se entrega.
4. **Given** un pago de transferencia rechazado y ninguna de las dos salidas anteriores funciona, **When** el cajero cancela el pedido por impago, **Then** los pagos quedan anulados, el pedido queda marcado como cancelado por impago, y se registra como merma.
5. **Given** una misma mesa que acumula un segundo rechazo en el mismo día, **When** ocurre ese segundo rechazo, **Then** el sistema lo marca para revisión del administrador del negocio, sin bloquear el flujo.
6. **Given** cualquier rechazo y su resolución, **When** se consulta el historial del pedido, **Then** queda registrado el motivo, el cajero y la hora de cada evento.

---

### Edge Cases

- ¿Qué pasa si el comensal cierra la app del QR después de confirmar el pedido y antes de transferir? El pedido ya quedó creado con el pago pendiente; la verificación ocurre igual en la mesa cuando se entrega.
- ¿Qué pasa si el cajero confirma el pago sin haber verificado realmente al cliente? El sistema no tiene control técnico para impedirlo; la integridad depende de la disciplina del cajero (riesgo aceptado, ver Assumptions).
- ¿Qué pasa si un pedido mixto o de transferencia se cancela antes de que el cajero verifique algo? Los pagos asociados quedan anulados junto con el pedido.
- ¿Qué pasa si el cajero intenta confirmar un pago cuyo pedido pertenece a otro negocio (tenant)? El sistema lo impide; un cajero solo puede ver y modificar pagos de su propio negocio.
- ¿Qué pasa si se intenta un segundo reintento después de que el primer reintento también fue rechazado? El flujo definido solo contempla un reintento; si vuelve a fallar, el cajero continúa con la salida de cancelación por impago.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST permitir que el comensal, desde el flujo QR, elija pagar el 100% del pedido por transferencia, sin exigir la subida de ningún archivo o imagen.
- **FR-002**: El sistema MUST permitir que el comensal, desde el flujo QR, elija pago mixto e ingrese el monto que pagará en efectivo, sin exigir la subida de ningún archivo o imagen.
- **FR-003**: En pago mixto, el sistema MUST calcular el monto a transferir como el total del pedido menos el efectivo declarado, y mostrarlo junto con una instrucción de referencia (mesa y número de pedido) para incluir en el mensaje de la transferencia.
- **FR-004**: En pago 100% por transferencia, el sistema MUST mostrar el monto total a transferir junto con la misma instrucción de referencia.
- **FR-005**: El sistema MUST validar que, en pago mixto, el efectivo declarado sea mayor que cero y menor que el total del pedido, rechazando con un mensaje claro cualquier valor fuera de ese rango y orientando al comensal hacia "Efectivo" (si el valor es igual al total) o "Transferencia" (si el valor es cero).
- **FR-006**: El sistema MUST aceptar únicamente valores enteros en pesos colombianos (sin decimales) para los montos de efectivo y transferencia.
- **FR-007**: El sistema MUST permitir que el comensal confirme su pedido (pasando a preparación) sin rastrear si la transferencia bancaria ya se realizó o no.
- **FR-008**: El sistema MUST mostrar al comensal, en ambos métodos (transferencia y mixto), el aviso de mostrar el comprobante desde la app de su banco al cajero en el momento de la entrega.
- **FR-009**: El sistema MUST mostrar al cajero, en el punto de venta, el desglose esperado de cada pedido con pago mixto o por transferencia (monto esperado en efectivo, si aplica, y monto esperado en transferencia).
- **FR-010**: El sistema MUST impedir que un pedido pase a estado pagado mientras existan pagos pendientes o rechazados sin resolver; el pedido solo pasa a pagado cuando el cajero confirma explícitamente todos los pagos activos.
- **FR-011**: El sistema MUST impedir la entrega de un pedido con pagos pendientes de verificación; la confirmación del pago y la habilitación de entrega ocurren en el mismo momento.
- **FR-012**: El sistema MUST permitir que el cajero adjunte opcionalmente una foto del comprobante al confirmar el pago, almacenando el archivo de la foto como evidencia junto al registro del pago, y MUST permitir confirmar el pago sin esa foto, sin generar error ni advertencia bloqueante por su ausencia.
- **FR-013**: El sistema MUST permitir que el cajero reajuste la división entre efectivo y transferencia de un pedido al momento de confirmar el pago (incluyendo convertir un pedido de transferencia total en mixto o en efectivo total), siempre que la suma de los montos ajustados sea igual al total del pedido, y rechazando el ajuste si esa suma no coincide.
- **FR-014**: El sistema MUST registrar cada reajuste de división con los montos originales y los montos finales, el cajero responsable y la hora del cambio.
- **FR-015**: El sistema MUST permitir que el cajero rechace un pago de transferencia únicamente indicando un motivo obligatorio, de entre un conjunto cerrado de motivos (cliente no muestra la app del banco, monto no coincide, transferencia no se completó, cliente se niega a mostrar el comprobante, comprobante sospechoso).
- **FR-016**: Cuando un pago de transferencia es rechazado, el sistema MUST dejar el pedido en estado de espera de pago y MUST impedir su entrega hasta resolver el rechazo.
- **FR-017**: El sistema MUST permitir resolver un rechazo mediante exactamente una de estas tres vías: pago del total en efectivo en el momento (con el reajuste correspondiente), un único reintento de verificación de transferencia, o cancelación del pedido por impago.
- **FR-018**: Al cancelar un pedido por impago, el sistema MUST anular los pagos asociados y MUST registrar el pedido como merma para efectos de control de inventario y costos.
- **FR-019**: El sistema MUST registrar en un historial de auditoría, solo de inserción, cada cambio de estado de un pago (creación, confirmación, rechazo con motivo, anulación) junto con el actor responsable, la hora, y los valores relevantes antes y después del cambio.
- **FR-020**: El sistema MUST marcar para revisión del administrador del negocio, sin bloquear el flujo, cualquier caso en que una misma mesa (identificada por su identificador físico de mesa) acumule un segundo rechazo de pago en el mismo día.
- **FR-021**: El sistema MUST restringir el acceso y la modificación de los registros de pago exclusivamente a usuarios del mismo negocio (tenant) al que pertenece el pedido.
- **FR-022**: El sistema MUST mantener, para cada pedido con pago mixto o por transferencia, la invariante de que la suma de los montos esperados de los pagos activos es igual al total del pedido.
- **FR-023**: El sistema MUST eliminar, en ambos métodos de pago (transferencia y mixto), la opción de que el comensal suba un comprobante desde el flujo QR.

### Key Entities *(include if feature involves data)*

- **Pago**: Representa un registro de pago asociado a un pedido y a un negocio (tenant). Tiene un método (efectivo o transferencia), un monto esperado, un monto confirmado, un estado (pendiente, confirmado, rechazado, anulado), evidencia opcional (foto y/o referencia de texto), y datos de quién y cuándo lo confirmó o rechazó (incluyendo el motivo de rechazo cuando aplica). Un pedido puede tener uno o más pagos; la suma de los montos esperados de los pagos activos siempre es igual al total del pedido.
- **Evento de pago**: Representa un registro de auditoría, solo de inserción, de cada cambio de estado ocurrido sobre un pago (quién lo hizo, cuándo, y los valores relevantes antes y después).
- **Pedido**: La entidad existente de pedido se extiende conceptualmente con un estado de pago derivado de sus pagos asociados (pendiente de pago mientras tenga pagos sin resolver, pagado cuando todos sus pagos activos están confirmados) y con la posibilidad de quedar marcado como cancelado por impago, lo que lo registra como merma.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100% de los pedidos pagados por transferencia o pago mixto desde el QR se confirman sin que el comensal suba ningún archivo o imagen.
- **SC-002**: El cajero puede confirmar o rechazar la verificación de un pago en menos de 30 segundos desde que recibe el pedido en caja, sin que el sistema le exija pasos adicionales no relacionados con la verificación en persona.
- **SC-003**: Ningún pedido con pago mixto o por transferencia llega a estado de entregado sin que exista una confirmación explícita del cajero sobre ese pago.
- **SC-004**: El 100% de los rechazos de pago quedan resueltos (por efectivo total, reintento exitoso, o cancelación por impago) y registrados en el historial de auditoría con motivo, cajero y hora.
- **SC-005**: El 100% de los reajustes de división realizados por el cajero preservan la igualdad entre la suma de los montos ajustados y el total del pedido; ningún ajuste que no cumpla esta igualdad es aceptado por el sistema.
- **SC-006**: Ningún usuario de un negocio puede ver ni modificar los pagos de un pedido perteneciente a otro negocio.

## Assumptions

- La verificación de la transferencia depende de la atención y buen juicio del cajero; el sistema no incorpora ningún control técnico (OCR, validación automática, integración con pasarelas) que impida confirmar un pago sin haberlo revisado realmente. Este es un riesgo aceptado del negocio, no un defecto a resolver en este spec.
- La foto del comprobante que el cajero puede adjuntar es evidencia de auditoría, no un mecanismo de validación; su ausencia nunca bloquea la confirmación del pago.
- La evidencia principal del comprobante puede quedar únicamente en el chat de WhatsApp del negocio, sin un vínculo automático con el pedido en el sistema; esa asociación automática (por ejemplo, vía una integración posterior) queda fuera del alcance de este spec.
- Este spec no incluye integración con pasarelas de pago ni con soluciones de validación automática de transferencias (por ejemplo, Nequi Negocios o Bre-B); esas integraciones son una fase posterior.
- Se asume que el negocio opera con al menos un cajero disponible para verificar transferencias en la mesa en el momento de la entrega; si solo hay un dispositivo o persona disponible para esta tarea, pueden generarse colas en horas de alta demanda, lo cual se acepta como riesgo operativo y no como un defecto del sistema.
- El efectivo y el monto a transferir siempre se expresan en pesos colombianos (COP) como valores enteros, sin decimales.
