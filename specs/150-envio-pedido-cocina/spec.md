# Feature Specification: Envío de pedido confirmado y pagado a cocina

**Feature Branch**: `150-envio-pedido-cocina`

**Created**: 2026-11-04

**Status**: Draft

**Input**: User description: "Como cajero, quiero enviar a cocina un pedido confirmado y pagado, para que entre a la cola de preparación en el orden en que lo despaché."

## Clarifications

### Session 2026-11-04

- Q: ¿La "posición en la cola" de una orden enviada a cocina (FR-009, SC-003) debe ser un valor almacenado explícitamente en la orden, o se calcula dinámicamente ordenando las órdenes por `sent_to_kitchen_at`? → A: Se calcula dinámicamente ordenando por `sent_to_kitchen_at`; no se almacena un campo de posición independiente.
- Q: ¿Qué debe ver el cajero en la interfaz cuando su solicitud de "Enviar a cocina" es rechazada por el backend con `ALREADY_IN_KITCHEN` (doble clic o reintento de red)? → A: Comportamiento silencioso — la UI refresca el estado de la orden y el botón desaparece, sin mostrar mensaje de error.
- Q: ¿El envío a cocina debe restringirse a usuarios con un rol específico, o cualquier usuario autenticado con acceso al módulo de órdenes puede ejecutarlo? → A: Restringido a los roles "cajero" y "admin"; el backend debe validar que el usuario tenga uno de estos roles antes de aceptar el envío.
- Q: ¿El `kitchen_status` manejado por esta funcionalidad admite únicamente los valores nulo y "SIN_PREPARAR", o existen otros estados posteriores (ej. "PREPARANDO", "LISTO") con los que este flujo debe ser compatible? → A: Solo dos valores relevantes aquí (nulo y "SIN_PREPARAR"); cualquier valor no nulo se trata igual (ya enviado), sin asumir estados adicionales.
- Q: ¿El sistema debe registrar qué usuario (cajero o admin) ejecutó el envío a cocina de cada orden, además del momento (`sent_to_kitchen_at`)? → A: No es necesario; solo se registra el momento del envío, no se requiere identificar al usuario que lo ejecutó.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - El cajero envía un pedido pagado a cocina (Priority: P1)

Como cajero, cuando una orden de cualquier origen (manual, mesa o domicilio) está
confirmada y su pago está completo, quiero presionar "Enviar a cocina" para que
el pedido entre a la cola de preparación en el momento exacto en que lo despacho,
sin depender de la hora de mi dispositivo.

**Why this priority**: Es el flujo central de la funcionalidad — sin esta acción
no existe forma de que un pedido pagado llegue a la cola de cocina. Todo lo demás
(restricciones de visibilidad e idempotencia) protege este flujo.

**Independent Test**: Se confirma una orden con pago "PAID" y `kitchen_status`
nulo, se presiona "Enviar a cocina", y se verifica que la orden queda con
`kitchen_status` "SIN_PREPARAR", con `sent_to_kitchen_at` registrado con la hora
del servidor, y que el botón deja de mostrarse para esa orden.

**Acceptance Scenarios**:

1. **Given** una orden confirmada con pago "PAID" y `kitchen_status` nulo,
   **When** el cajero presiona "Enviar a cocina", **Then** la orden queda con
   `kitchen_status` "SIN_PREPARAR", se registra `sent_to_kitchen_at` con la hora
   del servidor, y el botón deja de mostrarse para esa orden.
2. **Given** el módulo de cocina está activo para el tenant, **When** se evalúa
   una orden confirmada con pago "PAID" y `kitchen_status` nulo proveniente de
   cualquiera de los tres orígenes (manual, mesa o domicilio), **Then** el botón
   "Enviar a cocina" se muestra de forma consistente sin importar el origen.

---

### User Story 2 - El sistema impide enviar a cocina pedidos no pagados (Priority: P1)

Como cajero, no quiero poder enviar a cocina un pedido cuyo pago aún no se
completó, para evitar que cocina prepare algo que podría cancelarse o
modificarse antes de cobrarse.

**Why this priority**: Es una condición de negocio crítica — permitir el envío
de pedidos no pagados rompe la garantía de que cocina solo prepara lo que ya fue
cobrado, con impacto directo en pérdida de inventario y confusión operativa.

**Independent Test**: Se visualiza una orden confirmada con pago "UNPAID" y se
verifica que el botón "Enviar a cocina" no aparece; al invocar el endpoint
directamente, el backend responde 409 con el código `ORDER_NOT_PAID`.

**Acceptance Scenarios**:

1. **Given** una orden confirmada cuyo pago es "UNPAID", **When** el cajero
   visualiza la orden, **Then** el botón "Enviar a cocina" no se muestra.
2. **Given** una orden confirmada cuyo pago es "UNPAID", **When** se invoca el
   endpoint de envío a cocina directamente (sin pasar por el botón), **Then** el
   backend responde con estado 409 y código `ORDER_NOT_PAID`.

---

### User Story 3 - El sistema protege la cola ante envíos duplicados (Priority: P2)

Como cajero, si por error o por un reintento de red presiono "Enviar a cocina"
más de una vez sobre el mismo pedido, quiero que el sistema no duplique el
pedido en la cola ni altere la posición que ya tiene, para que cocina conserve
el orden real de despacho.

**Why this priority**: Protege la integridad de la cola de preparación una vez
que el envío ya ocurrió; depende de que el envío exitoso (User Story 1) ya esté
implementado, por lo que es un refuerzo sobre el flujo principal más que un
flujo independiente de valor por sí solo.

**Independent Test**: Se envía una orden a cocina exitosamente (queda en
`kitchen_status` "SIN_PREPARAR"), se invoca el envío una segunda vez sobre la
misma orden, y se verifica que el backend responde 409 con `ALREADY_IN_KITCHEN`
y que la posición de la orden en la cola no cambia.

**Acceptance Scenarios**:

1. **Given** una orden cuyo `kitchen_status` ya es "SIN_PREPARAR", **When** se
   vuelve a invocar el envío a cocina sobre esa misma orden, **Then** el backend
   responde con estado 409 y código `ALREADY_IN_KITCHEN`, y la posición de la
   orden en la cola no cambia.
2. **Given** una orden ya enviada a cocina, **When** el cajero visualiza esa
   orden, **Then** el botón "Enviar a cocina" ya no se muestra (consistente con
   User Story 1, escenario 1).

---

### Edge Cases

- ¿Qué ocurre si el módulo de cocina no está activo para el tenant (deshabilitado
  por plan) pero la orden cumple el resto de condiciones (confirmada, pagada,
  `kitchen_status` nulo)? El botón no debe mostrarse y el endpoint debe rechazar
  el envío, ya que el acceso al flujo de cocina está condicionado a que el módulo
  esté activo.
- ¿Qué ocurre si una orden confirmada y pagada se cancela antes de ser enviada a
  cocina? El botón "Enviar a cocina" no debe mostrarse para órdenes canceladas,
  y el endpoint debe rechazar el envío sobre una orden en ese estado.
- ¿Qué ocurre si el pago de una orden pasa de "PAID" a un estado parcial o se
  revierte después de haber sido enviada a cocina? El envío ya realizado
  (`kitchen_status` "SIN_PREPARAR") no se revierte automáticamente por un cambio
  posterior en el estado de pago; la reversión de pedidos ya enviados a cocina
  está fuera de alcance de esta funcionalidad.
- ¿Qué ocurre si dos solicitudes de envío llegan casi simultáneamente para la
  misma orden (doble clic o reintento de red concurrente)? Solo una debe
  completar el envío exitosamente; la(s) otra(s) deben recibir 409
  `ALREADY_IN_KITCHEN` sin afectar la posición en la cola. Ante esta respuesta,
  la interfaz del cajero se comporta de forma silenciosa: refresca el estado de
  la orden (el botón "Enviar a cocina" desaparece) sin mostrar ningún mensaje de
  error, ya que el pedido ya se encuentra correctamente en la cola.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST mostrar el botón "Enviar a cocina" sobre una orden
  únicamente cuando se cumplen las tres condiciones simultáneamente: el módulo de
  cocina está activo para el tenant, la orden está confirmada con estado de pago
  "PAID", y su `kitchen_status` es nulo.
- **FR-002**: El sistema MUST aplicar la condición de visibilidad del botón de
  forma idéntica a los tres orígenes de orden soportados: manual, mesa y
  domicilio.
- **FR-003**: Al presionar "Enviar a cocina" sobre una orden elegible, el sistema
  MUST registrar `kitchen_status` como "SIN_PREPARAR" sobre esa orden.
- **FR-004**: Al presionar "Enviar a cocina", el sistema MUST registrar
  `sent_to_kitchen_at` usando la hora del servidor en el momento del envío, nunca
  la hora reportada por el dispositivo del cajero.
- **FR-005**: Una vez que una orden queda con `kitchen_status` "SIN_PREPARAR", el
  sistema MUST dejar de mostrar el botón "Enviar a cocina" para esa orden.
- **FR-006**: El sistema MUST rechazar un intento de envío a cocina sobre una
  orden cuyo estado de pago no es "PAID", respondiendo con estado 409 y código de
  error `ORDER_NOT_PAID`, sin alterar el `kitchen_status` de la orden.
- **FR-007**: El sistema MUST rechazar un segundo intento de envío a cocina sobre
  una orden cuyo `kitchen_status` ya no es nulo, respondiendo con estado 409 y
  código de error `ALREADY_IN_KITCHEN`, sin duplicar el pedido ni modificar su
  posición en la cola de preparación ni su `sent_to_kitchen_at` original.
- **FR-008**: El sistema MUST garantizar que el envío a cocina sea idempotente
  ante múltiples invocaciones concurrentes o repetidas sobre la misma orden: como
  máximo una invocación tiene efecto (fija `kitchen_status` y
  `sent_to_kitchen_at`), y todas las demás son rechazadas sin efectos
  secundarios.
- **FR-009**: El sistema MUST preservar el orden de despacho de las órdenes en la
  cola de preparación según el momento (`sent_to_kitchen_at`) en que cada una fue
  enviada exitosamente por primera vez.
- **FR-010**: El sistema MUST rechazar un intento de envío a cocina sobre una
  orden que no está confirmada (por ejemplo, cancelada), independientemente de
  su estado de pago o de su `kitchen_status`.
- **FR-011**: El sistema MUST restringir la acción de envío a cocina a usuarios
  con rol "cajero" o "admin"; el botón no debe mostrarse a usuarios con otros
  roles, y el endpoint MUST rechazar con estado 403 un intento de envío
  realizado por un usuario sin uno de estos dos roles.

### Key Entities *(include if feature involves data)*

- **Orden (Order)**: Pedido de un cliente, de origen manual, mesa o domicilio.
  Para esta funcionalidad son relevantes su estado de confirmación, su estado de
  pago, su `kitchen_status` (nulo o "SIN_PREPARAR" al completar este flujo; esta
  funcionalidad solo distingue entre nulo y no nulo, sin asumir ni gestionar
  estados posteriores que puedan existir en el modelo de datos) y su
  `sent_to_kitchen_at` (momento de envío exitoso a cocina, hora del servidor).
- **Cola de preparación**: Secuencia ordenada de órdenes enviadas a cocina,
  calculada dinámicamente ordenando por `sent_to_kitchen_at` (no se almacena un
  campo de posición independiente); al no modificarse `sent_to_kitchen_at` en
  reintentos posteriores, la posición resultante de la orden permanece estable.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100% de las órdenes confirmadas con pago "PAID" y
  `kitchen_status` nulo muestran el botón "Enviar a cocina", sin importar su
  origen (manual, mesa o domicilio).
- **SC-002**: El 0% de las órdenes con pago distinto de "PAID" permiten
  completar un envío a cocina, ya sea por el botón (que no se muestra) o por
  invocación directa del endpoint (rechazada con 409 `ORDER_NOT_PAID`).
- **SC-003**: Ante cualquier número de invocaciones repetidas de envío a cocina
  sobre una misma orden, la orden aparece exactamente una vez en la cola de
  preparación y conserva la posición que obtuvo en su primer envío exitoso.
- **SC-004**: El tiempo registrado en `sent_to_kitchen_at` coincide con la hora
  del servidor en el momento del envío exitoso, con una desviación nula respecto
  a la hora del cliente que originó la solicitud.

## Assumptions

- El módulo de cocina y la noción de "módulo activo" para un tenant ya existen
  como mecanismo de gating (definidos en la spec de catálogo de módulos por
  plan); esta funcionalidad únicamente consume esa condición como uno de los tres
  requisitos de visibilidad del botón, sin redefinir cómo se activa o desactiva
  el módulo.
- Los conceptos de orden confirmada, estado de pago "PAID"/"UNPAID" y los tres
  orígenes de orden (manual, mesa, domicilio) ya existen en el sistema y se
  reutilizan sin cambios en esta funcionalidad.
- El tablero o vista de cocina que consume la cola de preparación (ordenada por
  `sent_to_kitchen_at`) está fuera de alcance de esta funcionalidad; aquí solo se
  especifica la acción de envío y las reglas que la gobiernan.
- La reversión de un envío a cocina ya realizado (por ejemplo, si el pago de una
  orden se revierte después de enviarse) está fuera de alcance; no se define un
  mecanismo para deshacer `kitchen_status` o `sent_to_kitchen_at` una vez fijados
  por un envío exitoso.
- No es necesario registrar qué usuario (cajero o admin) ejecutó el envío a
  cocina; esta funcionalidad únicamente registra el momento del envío
  (`sent_to_kitchen_at`), sin un campo de autoría del envío.
