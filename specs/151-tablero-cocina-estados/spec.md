# Feature Specification: Tablero de cocina en tres columnas con movimiento de pedidos

**Feature Branch**: `151-tablero-cocina-estados`

**Created**: 2026-11-04

**Status**: Draft

**Input**: User description: "Como usuario de cocina, quiero ver los pedidos en tres columnas y moverlos entre estados, para preparar en orden de llegada y saber qué está listo."

## Clarifications

### Session 2026-11-04

- Q: ¿Qué rol(es) de usuario deben poder ver el tablero de cocina y mover tarjetas entre columnas? → A: Rol nuevo `KITCHEN`.
- Q: ¿Cómo debe actualizarse el tablero para que un usuario vea, sin recargar, los cambios hechos por otro usuario? → A: Conexión en tiempo real (WebSocket/SSE).
- Q: ¿ADMIN y CASHIER también deben poder ver y mover tarjetas, o el tablero queda exclusivo del rol KITCHEN? → A: ADMIN y CASHIER pueden ver el tablero, pero solo KITCHEN puede ver y mover las tarjetas.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ver los pedidos en orden de llegada por columna (Priority: P1)

Como usuario de cocina, quiero ver todos los pedidos enviados a cocina
organizados en tres columnas ("SIN PREPARAR", "EN PROGRESO", "LISTO"), cada una
ordenada por el momento en que el pedido llegó a cocina, para saber qué
preparar primero sin tener que calcularlo yo mismo.

**Why this priority**: Es la base de todo el tablero — sin una vista correcta y
ordenada de los pedidos, mover tarjetas entre columnas no tiene ningún valor.
Es el primer requisito para que cocina pueda operar con el tablero.

**Independent Test**: Se envían a cocina dos pedidos pagados con
`sent_to_kitchen_at` distinto, se abre el tablero, y se verifica que ambos
aparecen en la columna "SIN PREPARAR" ordenados del más antiguo al más
reciente, sin posibilidad de arrastrarlos para cambiar ese orden dentro de la
misma columna.

**Acceptance Scenarios**:

1. **Given** la orden A se envió a cocina a las 10:00 y la orden B a las 10:02,
   **When** el usuario abre el tablero, **Then** A aparece antes que B en la
   columna "SIN PREPARAR".
2. **Given** dos pedidos con el mismo `sent_to_kitchen_at`, **When** el usuario
   abre el tablero, **Then** el de menor `id` aparece primero dentro de la
   columna.
3. **Given** el tablero abierto con varios pedidos en una columna, **When** el
   usuario intenta reordenar manualmente las tarjetas dentro de esa columna,
   **Then** el sistema no permite el reordenamiento y el orden FIFO se
   mantiene.

---

### User Story 2 - Mover un pedido entre columnas (Priority: P1)

Como usuario de cocina, quiero mover un pedido de una columna a otra (incluso
hacia atrás, para corregir un error), para reflejar en qué etapa de
preparación se encuentra realmente, sin afectar el estado de la orden ni el de
su pago.

**Why this priority**: Es la acción central del tablero — sin poder mover
pedidos entre columnas, el tablero es solo una vista de solo lectura y no
cumple el objetivo de que cocina sepa qué está listo.

**Independent Test**: Se mueve un pedido pagado de "SIN PREPARAR" a "EN
PROGRESO", y se verifica que su `kitchen_status` cambia a "EN_PROGRESO", que
el estado de la orden y el de pago no se modifican, y que la tarjeta se ubica
en su nueva columna según su `sent_to_kitchen_at`.

**Acceptance Scenarios**:

1. **Given** una orden pagada está en la columna "SIN PREPARAR", **When** el
   usuario la mueve a "EN PROGRESO", **Then** su `kitchen_status` cambia a
   "EN_PROGRESO", el estado de la orden y el estado de pago no cambian, y la
   tarjeta se ubica según su `sent_to_kitchen_at` dentro de la columna.
2. **Given** una orden está en "LISTO", **When** el usuario la mueve de vuelta
   a "EN PROGRESO" para corregir un error, **Then** el sistema acepta la
   transición siempre que el pago siga "PAID" y la orden no esté cancelada ni
   cerrada y el módulo esté activo.
3. **Given** una orden en "EN PROGRESO" cuyo pago ya no es "PAID", **When** el
   usuario intenta moverla a otra columna, **Then** el backend responde 409
   con código `PAYMENT_NOT_PAID` y la tarjeta vuelve a su columna original con
   un mensaje de error visible para el usuario.

---

### User Story 3 - La tarjeta siempre muestra la información necesaria para preparar el pedido (Priority: P2)

Como usuario de cocina, quiero que cada tarjeta muestre el número de orden, el
origen, el cliente o la mesa, los productos con cantidades, las adiciones, las
notas y el tiempo transcurrido desde el envío, para preparar el pedido
correctamente sin tener que consultar otra pantalla.

**Why this priority**: Mejora la utilidad operativa del tablero, pero depende
de que las columnas y el movimiento (User Stories 1 y 2) ya existan; sin esta
información la tarjeta sigue siendo funcional para mover pedidos, solo menos
útil para prepararlos.

**Independent Test**: Se abre el tablero con un pedido que tiene productos,
adiciones y notas, y se verifica que la tarjeta muestra el número de orden, el
origen (mesa, caja o domicilio), el cliente o la mesa, cada producto con su
cantidad, las adiciones, las notas, y el tiempo transcurrido desde
`sent_to_kitchen_at`.

**Acceptance Scenarios**:

1. **Given** un pedido de origen "mesa" con dos productos, una adición y una
   nota, **When** se visualiza su tarjeta en el tablero, **Then** se muestran
   el número de orden, la mesa, ambos productos con sus cantidades, la
   adición, la nota y el tiempo transcurrido desde el envío a cocina.
2. **Given** un pedido de origen "domicilio", **When** se visualiza su
   tarjeta, **Then** se muestra el cliente en lugar de una mesa, junto con el
   resto de la información de la tarjeta.

---

### User Story 4 - El tablero refleja solo pedidos activos para cocina (Priority: P2)

Como usuario de cocina, quiero que una tarjeta desaparezca del tablero en
cuanto el pedido llega a su estado final del flujo actual o se cancela, para
no seguir viendo ni moviendo pedidos que ya no requieren mi atención.

**Why this priority**: Evita que el tablero se llene de pedidos obsoletos y
previene movimientos sobre órdenes que ya no deberían aceptarlos; depende de
que el tablero y las reglas de transición (User Stories 1 y 2) ya existan.

**Independent Test**: Se cancela una orden que está en "EN PROGRESO" y se
verifica que su tarjeta desaparece del tablero inmediatamente, sin requerir
ninguna acción adicional del usuario de cocina.

**Acceptance Scenarios**:

1. **Given** una orden está en "EN PROGRESO", **When** el cliente o el staff
   cancela la orden, **Then** la tarjeta desaparece del tablero.
2. **Given** una orden llega a su estado final del flujo actual (por ejemplo,
   se cierra o se entrega) estando en cualquiera de las tres columnas, **When**
   ese cambio ocurre, **Then** la tarjeta desaparece del tablero.

---

### Edge Cases

- ¿Qué ocurre si dos usuarios de cocina mueven la misma tarjeta casi al mismo
  tiempo hacia columnas distintas? Solo se aplica la primera transición que
  llega al backend; el segundo usuario recibe 409 con código
  `KITCHEN_STATUS_CONFLICT` y su vista se actualiza para mostrar el estado
  vigente de la orden, en lugar de aplicar su movimiento sobre un estado ya
  obsoleto.
- ¿Qué ocurre si el módulo de cocina se desactiva mientras el tablero está
  abierto? Cualquier intento de mover una tarjeta después de la desactivación
  es rechazado por el backend, ya que el módulo activo es una de las tres
  condiciones obligatorias para aceptar la transición.
- ¿Qué ocurre si una orden es movida a una columna y en ese mismo instante su
  pago deja de ser "PAID" (por ejemplo, se revierte)? El movimiento se
  rechaza con 409 `PAYMENT_NOT_PAID` y la tarjeta permanece en su columna
  original.
- ¿Qué ocurre si no hay pedidos en una columna? La columna se muestra vacía,
  sin pedidos de ejemplo ni mensajes de error.
- ¿Qué ocurre si una orden no tiene mesa ni cliente asociado (por ejemplo, un
  pedido de caja sin nombre de cliente)? La tarjeta muestra el origen "caja"
  sin un nombre de cliente o mesa específico, sin que esto sea un error.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST mostrar un tablero con exactamente tres
  columnas: "SIN PREPARAR", "EN PROGRESO" y "LISTO".
- **FR-002**: El sistema MUST ubicar cada pedido enviado a cocina en la
  columna correspondiente a su `kitchen_status` vigente.
- **FR-003**: Dentro de cada columna, el sistema MUST ordenar los pedidos por
  `sent_to_kitchen_at` ascendente, usando el `id` de la orden como criterio de
  desempate cuando el `sent_to_kitchen_at` coincide.
- **FR-004**: El sistema MUST impedir que el usuario reordene manualmente las
  tarjetas dentro de una misma columna; el único orden válido dentro de una
  columna es el FIFO definido en FR-003.
- **FR-005**: El sistema MUST permitir mover una tarjeta entre cualquiera de
  las tres columnas, incluyendo movimientos hacia columnas anteriores en el
  flujo, para permitir correcciones.
- **FR-006**: El backend MUST aceptar una transición de `kitchen_status`
  únicamente cuando se cumplen simultáneamente las tres condiciones: el pago
  de la orden es "PAID", la orden no está cancelada ni cerrada, y el módulo de
  cocina está activo para el tenant.
- **FR-007**: El backend MUST rechazar con estado 409 y código
  `PAYMENT_NOT_PAID` una transición sobre una orden cuyo pago no es "PAID", sin
  modificar su `kitchen_status`.
- **FR-008**: El sistema MUST aplicar como máximo una transición de
  `kitchen_status` cuando dos solicitudes concurrentes intentan mover la misma
  tarjeta; la primera que llega al backend se aplica, y el backend MUST
  rechazar con estado 409 y código `KITCHEN_STATUS_CONFLICT` cualquier
  solicitud posterior basada en un estado de la orden que ya quedó obsoleto.
- **FR-009**: Cuando la interfaz recibe un 409 `PAYMENT_NOT_PAID` o
  `KITCHEN_STATUS_CONFLICT` al intentar mover una tarjeta, el sistema MUST
  devolver visualmente la tarjeta a su columna de origen y mostrar un mensaje
  de error al usuario; en el caso de `KITCHEN_STATUS_CONFLICT`, el sistema
  MUST además reflejar el `kitchen_status` vigente de la orden.
- **FR-010**: Mover una tarjeta entre columnas MUST únicamente modificar el
  `kitchen_status` de la orden; el estado de confirmación/cancelación de la
  orden y su estado de pago MUST permanecer sin cambios como resultado directo
  de ese movimiento.
- **FR-011**: El sistema MUST retirar del tablero toda tarjeta cuya orden
  llegue a su estado final del flujo actual (por ejemplo, cierre o entrega) o
  sea cancelada, sin importar en qué columna se encontraba.
- **FR-012**: Cada tarjeta MUST mostrar el número de orden, el origen de la
  orden (mesa, caja o domicilio), el cliente o la mesa asociada, los productos
  del pedido con sus cantidades, las adiciones de esos productos, las notas
  del pedido, y el tiempo transcurrido desde `sent_to_kitchen_at`.
- **FR-013**: El sistema MUST aplicar las mismas reglas de columnas, orden
  FIFO, visibilidad de información y condiciones de transición
  independientemente del origen de la orden (mesa, caja o domicilio).
- **FR-014**: El sistema MUST permitir visualizar el tablero a los roles
  `ADMIN`, `CASHIER` y `KITCHEN`; MUST restringir el movimiento de tarjetas
  entre columnas exclusivamente al rol `KITCHEN`, de modo que `ADMIN` y
  `CASHIER` puedan ver el tablero pero no muevan tarjetas.
- **FR-015**: El backend MUST propagar en tiempo real, mediante una conexión
  WebSocket/SSE, todo cambio de `kitchen_status` y toda remoción de tarjeta
  (FR-011) a los tableros abiertos del mismo tenant, para que un usuario vea
  el estado vigente de una orden sin recargar la página.

### Key Entities *(include if feature involves data)*

- **Orden (Order)**: Pedido ya enviado a cocina. Para este tablero son
  relevantes su `kitchen_status` ("SIN_PREPARAR", "EN_PROGRESO" o "LISTO"), su
  `sent_to_kitchen_at` (usado para el orden FIFO), su estado de pago, su
  estado de confirmación/cancelación, su origen (mesa, caja o domicilio), el
  cliente o la mesa asociada, los productos con cantidades y adiciones, y las
  notas del pedido.
- **Tablero de cocina**: Vista de las órdenes con `kitchen_status` no nulo,
  agrupadas en tres columnas fijas según ese estado y ordenadas dentro de cada
  columna por `sent_to_kitchen_at` ascendente (desempate por `id`).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100% de los pedidos enviados a cocina aparecen en la columna
  correspondiente a su `kitchen_status`, ordenados por `sent_to_kitchen_at`
  ascendente dentro de esa columna.
- **SC-002**: El 0% de los intentos de mover un pedido cuyo pago no es "PAID"
  logran cambiar su `kitchen_status`; todos son rechazados con 409
  `PAYMENT_NOT_PAID` y la tarjeta se mantiene en su columna original.
- **SC-003**: Cuando dos movimientos concurrentes afectan la misma tarjeta,
  exactamente uno se aplica; el usuario cuyo movimiento no se aplicó ve el
  `kitchen_status` vigente de la orden en menos de un refresco de pantalla.
- **SC-004**: El 100% de las tarjetas correspondientes a órdenes canceladas o
  que alcanzan su estado final del flujo actual desaparecen del tablero sin
  intervención manual del usuario de cocina.
- **SC-005**: Un usuario de cocina puede identificar, sin consultar otra
  pantalla, los productos, cantidades, adiciones y notas de cualquier pedido
  visible en el tablero.

## Assumptions

- El módulo de cocina y su mecanismo de activación por tenant ya existen
  (definidos en la especificación del catálogo de módulos por plan) y en esta
  funcionalidad solo se consumen como una de las tres condiciones de
  transición; no se redefine cómo se activa o desactiva el módulo.
- El envío inicial de un pedido a cocina (lo que fija `sent_to_kitchen_at` y el
  primer `kitchen_status`, "SIN_PREPARAR") ya existe como funcionalidad previa;
  este tablero consume órdenes que ya fueron enviadas a cocina, sin redefinir
  cómo llegan a ese primer estado.
- "Estado final del flujo actual" se refiere al estado final de la orden en su
  ciclo de vida general (por ejemplo, cerrada o entregada), no a "LISTO" como
  columna del tablero; una orden puede permanecer en "LISTO" visible en el
  tablero hasta que su flujo general concluya o se cancele.
- Los conceptos de estado de pago "PAID", orden cancelada/cerrada, y los tres
  orígenes de orden (mesa, caja, domicilio) ya existen en el sistema y se
  reutilizan sin cambios.
- El tiempo transcurrido desde el envío (FR-012) se calcula a partir de
  `sent_to_kitchen_at` y se actualiza mientras el usuario mantiene el tablero
  abierto, sin requerir que el usuario recargue la página manualmente.
- No se requiere un historial o auditoría de los movimientos entre columnas
  más allá del `kitchen_status` vigente de cada orden.
- El rol `KITCHEN` es un rol nuevo que esta funcionalidad introduce (no existe
  hoy en el sistema); los roles `ADMIN` y `CASHIER` ya existentes solo
  obtienen acceso de visualización sobre este tablero, sin cambios en sus
  permisos sobre el resto del sistema.
- La propagación en tiempo real (FR-015) es una conexión nueva de
  WebSocket/SSE para este tablero; no se reutiliza ni se modifica ningún
  mecanismo de tiempo real existente, porque no hay uno en el sistema hoy.
