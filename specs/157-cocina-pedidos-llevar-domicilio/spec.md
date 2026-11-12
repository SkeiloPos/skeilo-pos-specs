# Feature Specification: Envío a Cocina de Pedidos Para Llevar y Domicilio

**Feature Branch**: `157-cocina-pedidos-llevar-domicilio`

**Created**: 2026-11-11

**Status**: Draft

**Input**: User description: "actualmente, cuando tengo el modulo de cocina activo, y creo un pedido para llevar o a domicilio, este no me deja enviar el pedido a cocina, necesito que analizes el flujo y me propongas la mejor forma de darle tratamiento a esos pedido teniendo en cuenta las dos modalidades de cobro pago despues de recibir y pago antes de recibir, los pedidos de mesas no hacen parte de este alcance y solo aplica cuando esta activo el modulo de cocina"

## Clarifications

### Session 2026-11-11

- Q: ¿De dónde debe salir la modalidad de cobro (pago antes/después de recibir) que gobierna el envío a cocina de pedidos para llevar/domicilio? → A: Reusar la modalidad del plan ya definida por el Super Admin para el menú QR (spec 154 - PAY_AFTER_RECEIVING / PAY_BEFORE_RECEIVING), extendiendo su efecto para que también gobierne el flujo operativo de mostrador y domicilio.
- Q: Para la modalidad "pago antes de recibir" (prepago), ¿cómo debe comportarse el envío a cocina? → A: Cobrar y enviar a cocina en un solo paso, igual al patrón ya construido para mesas por QR (spec 153).
- Q: Para la modalidad "pago después de recibir" (pospago), ¿cómo debe comportarse el envío a cocina? → A: Enviar a cocina sin exigir pago previo, relajando la condición de pago obligatorio solo para este caso; el cobro se registra después, al entregar/recoger el pedido.
- Q: ¿El tratamiento debe ser idéntico para pedidos para llevar (TAKEAWAY) y a domicilio (DELIVERY), o hay diferencias entre ambos? → A: Idéntico para ambos, sin distinción adicional por tipo de orden.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Cobro y envío a cocina en un solo paso para tenants con pago antes de recibir (Priority: P1)

Como cajero de un negocio cuyo plan está configurado con la modalidad "Pago antes de recibir"
y que tiene el módulo de Cocina activo, quiero que al cobrar un pedido para llevar o a
domicilio, este se envíe automáticamente a cocina en el mismo acto, para no tener que
realizar dos pasos separados ni arriesgarme a olvidar enviarlo.

**Why this priority**: Sin esto, los pedidos para llevar/domicilio de estos tenants quedan
atascados sin poder prepararse, que es exactamente el problema reportado. Es el bloqueador
principal a resolver.

**Independent Test**: Puede probarse creando un pedido TAKEAWAY o DELIVERY en un tenant con
módulo de Cocina activo y plan en modalidad "Pago antes de recibir", cobrándolo por completo,
y verificando que aparece de inmediato en el tablero de cocina (columna "Sin preparar") sin
ninguna acción adicional.

**Acceptance Scenarios**:

1. **Given** un tenant con módulo de Cocina activo y plan en modalidad "Pago antes de
   recibir", y un pedido TAKEAWAY recién creado y confirmado, **When** el cajero cobra el
   pedido por completo, **Then** el pedido pasa automáticamente a `kitchen_status = SIN_PREPARAR`
   en el mismo acto, sin requerir un botón adicional de "Enviar a cocina".
2. **Given** las mismas condiciones anteriores pero con un pedido DELIVERY, **When** el
   cajero cobra el pedido por completo, **Then** el comportamiento es idéntico al de un
   pedido TAKEAWAY: se envía a cocina automáticamente al cobrar.
3. **Given** un pedido TAKEAWAY/DELIVERY de un tenant en esta modalidad que aún no ha sido
   cobrado, **When** el cajero busca una forma de enviarlo a cocina sin cobrar, **Then** el
   sistema no ofrece ningún botón manual de "Enviar a cocina" para ese pedido; el único
   camino para que llegue a cocina es completar el cobro.

---

### User Story 2 - Envío a cocina sin exigir pago previo para tenants con pago después de recibir (Priority: P1)

Como cajero de un negocio cuyo plan está configurado con la modalidad "Pago después de
recibir" y que tiene el módulo de Cocina activo, quiero poder enviar un pedido para llevar o
a domicilio a cocina apenas lo confirmo, sin tener que cobrarlo primero, para que la cocina
empiece a prepararlo mientras el cobro se resuelve al momento de la entrega o recogida.

**Why this priority**: Es el otro bloqueador directo del problema reportado: en esta
modalidad, exigir pago antes de cocinar contradice el flujo de negocio real (el cliente paga
al recibir), por lo que hoy el pedido nunca llega a estar "pagado" a tiempo y se queda sin
poder enviarse.

**Independent Test**: Puede probarse creando un pedido TAKEAWAY o DELIVERY en un tenant con
módulo de Cocina activo y plan en modalidad "Pago después de recibir", confirmándolo sin
cobrarlo, y verificando que puede enviarse a cocina de inmediato; luego verificando que el
cobro puede completarse después, al entregar o recoger el pedido, sin afectar su estado de
cocina.

**Acceptance Scenarios**:

1. **Given** un tenant con módulo de Cocina activo y plan en modalidad "Pago después de
   recibir", y un pedido TAKEAWAY recién confirmado y sin pagar, **When** el cajero envía el
   pedido a cocina, **Then** el sistema lo permite y el pedido pasa a `kitchen_status =
   SIN_PREPARAR` aunque `payment_status` siga `UNPAID`.
2. **Given** las mismas condiciones anteriores pero con un pedido DELIVERY, **When** el
   cajero envía el pedido a cocina sin haberlo cobrado, **Then** el comportamiento es
   idéntico al de un pedido TAKEAWAY.
3. **Given** un pedido TAKEAWAY/DELIVERY ya enviado a cocina sin pagar bajo esta modalidad,
   **When** el pedido está listo para entregar o recoger, **Then** el cajero puede cobrarlo
   con el flujo de cobro existente, y ese cobro actualiza `payment_status` sin alterar el
   `kitchen_status` ya alcanzado.

---

### User Story 3 - Sin cambios cuando el módulo de Cocina está inactivo (Priority: P3)

Como cajero de un negocio que no tiene el módulo de Cocina activo, quiero que la creación y
cobro de pedidos para llevar o a domicilio siga funcionando exactamente igual que hoy, sin
que esta funcionalidad introduzca ningún paso ni validación nueva.

**Why this priority**: Confirma que la corrección queda acotada al módulo de Cocina y no
genera una regresión en los tenants que no lo tienen contratado.

**Independent Test**: Puede probarse en un tenant sin el módulo de Cocina activo, creando y
cobrando pedidos TAKEAWAY y DELIVERY, y verificando que el comportamiento (y la ausencia de
cualquier campo o acción relacionada con cocina) es idéntico al actual.

**Acceptance Scenarios**:

1. **Given** un tenant sin el módulo de Cocina activo, **When** se crea y cobra un pedido
   TAKEAWAY o DELIVERY, **Then** el flujo de venta y descuento de inventario ocurre como hoy,
   sin ningún `kitchen_status` ni opción de "Enviar a cocina" visible, sin importar la
   modalidad de pago del plan.

---

### Edge Cases

- ¿Qué pasa si el plan de un tenant no tiene ninguna modalidad de cobro configurada
  explícitamente? El sistema la trata como "Pago después de recibir" por defecto, igual al
  comportamiento genérico que ya existía antes de esta funcionalidad.
- ¿Qué pasa si el Super Admin cambia la modalidad del plan mientras hay pedidos
  TAKEAWAY/DELIVERY en curso? El cambio solo afecta las acciones de cobro/envío a cocina que
  ocurran después del cambio; los pedidos que ya alcanzaron un `kitchen_status` previamente no
  se revierten ni se reevalúan retroactivamente.
- ¿Qué pasa si se intenta cobrar un pedido TAKEAWAY/DELIVERY con pago mixto (efectivo +
  transferencia) bajo la modalidad "Pago antes de recibir"? El envío automático a cocina solo
  se dispara cuando el pedido alcanza `payment_status = PAID` en su totalidad, sin importar
  cuántos métodos de pago se combinaron para llegar ahí.
- ¿Qué pasa si se cancela un pedido TAKEAWAY/DELIVERY que ya fue enviado a cocina sin pagar
  (modalidad "Pago después de recibir")? Se reutilizan las reglas de cancelación ya
  existentes para pedidos enviados a cocina; esta funcionalidad no introduce un tratamiento
  de cancelación distinto.
- ¿Qué pasa si el módulo de Cocina se desactiva para un tenant que tiene pedidos
  TAKEAWAY/DELIVERY ya enviados a cocina (pagados o no)? Se reutiliza el comportamiento ya
  existente de desactivación del módulo (spec 149): el tablero de cocina deja de estar
  accesible, pero el flujo de cobro/entrega de esos pedidos no se bloquea.
- Esta funcionalidad no aplica a pedidos de mesa (`DINE_IN`), cuyo tratamiento de cobro y
  envío a cocina ya está resuelto por una funcionalidad anterior y queda fuera de este
  alcance.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema DEBE determinar el tratamiento de "enviar a cocina" para cada
  pedido TAKEAWAY o DELIVERY según la modalidad de cobro configurada en el plan del tenant
  ("Pago antes de recibir" o "Pago después de recibir"), y únicamente cuando el módulo de
  Cocina está activo para ese tenant.
- **FR-002**: Cuando la modalidad del plan sea "Pago antes de recibir", el sistema DEBE
  enviar el pedido TAKEAWAY/DELIVERY a cocina automáticamente, en el mismo acto en que se
  completa su cobro (`payment_status = PAID`), sin exponer un botón manual separado de
  "Enviar a cocina" para esos pedidos.
- **FR-003**: Cuando la modalidad del plan sea "Pago después de recibir", el sistema DEBE
  permitir enviar el pedido TAKEAWAY/DELIVERY a cocina en cuanto esté confirmado (no
  cancelado), sin exigir `payment_status = PAID`, relajando esa condición únicamente para
  esta combinación (TAKEAWAY/DELIVERY + módulo de Cocina activo + modalidad "Pago después de
  recibir").
- **FR-004**: El sistema DEBE seguir exigiendo `payment_status = PAID` antes de enviar a
  cocina en cualquier otro caso: pedidos TAKEAWAY/DELIVERY bajo modalidad "Pago antes de
  recibir" (FR-002) y pedidos de mesa (`DINE_IN`), que mantienen sus reglas actuales sin
  cambios.
- **FR-005**: El sistema DEBE aplicar el tratamiento de las modalidades de cobro de forma
  idéntica a pedidos TAKEAWAY y DELIVERY, sin ninguna distinción adicional entre ambos tipos
  de orden.
- **FR-006**: Para pedidos TAKEAWAY/DELIVERY enviados a cocina sin pagar bajo la modalidad
  "Pago después de recibir", el sistema DEBE permitir cobrar el pedido después (al momento de
  la entrega o recogida) mediante el flujo de cobro existente, actualizando `payment_status`
  sin alterar el `kitchen_status` ya alcanzado.
- **FR-007**: Cuando el módulo de Cocina NO esté activo para el tenant, los pedidos
  TAKEAWAY y DELIVERY DEBEN mantener su comportamiento actual (sin `kitchen_status` ni flujo
  de cocina), sin importar la modalidad de cobro del plan.
- **FR-008**: Cuando el plan de un tenant no tenga una modalidad de cobro configurada
  explícitamente, el sistema DEBE tratarlo como "Pago después de recibir" para efectos de
  esta funcionalidad.
- **FR-009**: El sistema DEBE reflejar la transición de `kitchen_status` a `SIN_PREPARAR` en
  el tablero de cocina para pedidos TAKEAWAY/DELIVERY enviados bajo cualquiera de las dos
  modalidades, de forma consistente con el tratamiento ya existente para pedidos de mesa.

### Key Entities *(include if feature involves data)*

- **CustomerOrder (pedido TAKEAWAY/DELIVERY)**: conserva sus campos actuales (`order_type`,
  `payment_status`, `kitchen_status`, `sent_to_kitchen_at`); el momento en que
  `kitchen_status` pasa de `NULL` a `SIN_PREPARAR` ahora depende también de la modalidad de
  cobro del plan de su tenant, además de los campos propios del pedido.
- **Modalidad de cobro del plan**: configuración existente a nivel de plan
  (`PAY_AFTER_RECEIVING` / `PAY_BEFORE_RECEIVING`), definida exclusivamente por el Super
  Admin. Esta funcionalidad extiende su efecto: además de determinar el mensaje mostrado en
  el menú QR, ahora también determina cuándo se dispara el envío a cocina para pedidos
  TAKEAWAY/DELIVERY de mostrador.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100% de los pedidos TAKEAWAY/DELIVERY nuevos en tenants con el módulo de
  Cocina activo pueden llegar a cocina sin necesidad de pasos manuales alternativos ni
  bloqueos, sin importar la modalidad de cobro del plan.
- **SC-002**: En tenants con modalidad "Pago antes de recibir", el 100% de los pedidos
  TAKEAWAY/DELIVERY cobrados por completo aparecen en el tablero de cocina en el mismo acto
  del cobro, sin acción manual adicional.
- **SC-003**: En tenants con modalidad "Pago después de recibir", los cajeros pueden enviar
  un pedido TAKEAWAY/DELIVERY a cocina inmediatamente después de confirmarlo, sin tener que
  cobrarlo primero, en el 100% de los casos.
- **SC-004**: Los pedidos de mesa (`DINE_IN`) y los tenants sin el módulo de Cocina activo no
  presentan ningún cambio de comportamiento observable tras esta funcionalidad.

## Assumptions

- Se reutiliza la modalidad de cobro definida a nivel de plan por el Super Admin (spec 154:
  `PAY_AFTER_RECEIVING` / `PAY_BEFORE_RECEIVING`), extendiendo su efecto más allá del mensaje
  del menú QR para que también gobierne el momento de envío a cocina de pedidos
  TAKEAWAY/DELIVERY; esta extensión de alcance fue confirmada explícitamente por el usuario.
- Si el plan no tiene la modalidad configurada, se asume "Pago después de recibir" por
  defecto, por ser el comportamiento genérico ya existente antes de esta funcionalidad.
- TAKEAWAY y DELIVERY reciben un tratamiento idéntico; no se modela ninguna distinción por el
  hecho de que, en la práctica, un domicilio pueda cobrarse a través del mensajero en el
  momento de la entrega en lugar de en caja — esa diferencia operativa queda fuera de alcance.
- Los pedidos de mesa (`DINE_IN`) quedan explícitamente fuera de este alcance; su tratamiento
  de cobro y envío a cocina ya fue resuelto por una funcionalidad anterior (spec 153).
- Esta funcionalidad solo aplica cuando el módulo de Cocina está activo para el tenant (spec
  149); cuando está inactivo, el flujo actual de venta/descuento de inventario para
  TAKEAWAY/DELIVERY permanece sin cambios.
- "Pago antes de recibir" (`PAY_BEFORE_RECEIVING`) para pedidos TAKEAWAY/DELIVERY requiere
  que el pedido alcance el pago completo (`payment_status = PAID`); pagos parciales o mixtos
  solo disparan el envío automático a cocina una vez se completa la totalidad del cobro.
