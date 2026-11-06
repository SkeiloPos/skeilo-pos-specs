# Feature Specification: Instrucciones de Pago del Menú QR por Modalidad del Plan

**Feature Branch**: `154-instrucciones-pago-menu-qr`

**Created**: 2026-11-06

**Status**: Draft

**Input**: User description: "Como Superadministrador de la plataforma SaaS, quiero configurar desde la administración de planes la modalidad de pago del servicio que utilizarán los tenants suscritos a cada plan, para controlar las instrucciones que se muestran a los clientes en el menú QR después de enviar una orden, de acuerdo con el flujo de servicio establecido para cada tenant. Se contemplan dos modalidades: PAY_AFTER_RECEIVING (el cliente recibe su pedido y luego paga) y PAY_BEFORE_RECEIVING (el cliente debe acercarse a caja a pagar antes de recibir su pedido). La modalidad la define exclusivamente el Super Admin desde el plan; el tenant la hereda sin poder modificarla. La configuración solo afecta el mensaje informativo mostrado al comensal en el menú QR tras enviar su orden, según el método de pago elegido (efectivo, Nequi o mixto); no modifica el flujo operativo de las órdenes, los estados de pago, los métodos de pago habilitados, ni las interfaces de POS, caja, terminal de mesas o cocina."

## Clarifications

### Session 2026-11-06

- Q: ¿El texto exacto que verá el comensal para la modalidad PAY_AFTER_RECEIVING (efectivo, Nequi y mixto) debe ser el mismo texto que hoy ya muestra el sistema, o se debe escribir un texto nuevo que mencione explícitamente "Nequi"? → A: Usar el texto actual tal cual, sin cambios; el caso Nequi sigue mostrando el mensaje genérico de transferencia ya existente, sin mencionar "Nequi" explícitamente.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - El Super Admin define la modalidad de pago del plan (Priority: P1)

Como Super Admin, quiero definir en la configuración de cada plan si sus tenants operan con
la modalidad "Pago después de recibir" o "Pago antes de recibir", para que el mensaje que
ven los comensales en el menú QR sea coherente con el flujo de servicio real del negocio.

**Why this priority**: Es la base de toda la funcionalidad. Sin esta configuración en el
plan no existe ninguna fuente de verdad sobre qué instrucción mostrar a los comensales.

**Independent Test**: Puede probarse por completo sin que ningún comensal participe: el
Super Admin entra a la administración de planes, en un plan existente o nuevo selecciona
"Instrucciones de pago del menú QR" como PAY_AFTER_RECEIVING o PAY_BEFORE_RECEIVING, guarda,
y verifica que el plan queda con exactamente esa modalidad seleccionada.

**Acceptance Scenarios**:

1. **Given** el Super Admin está creando o editando un plan, **When** selecciona una de las
   dos modalidades ("Pago después de recibir" o "Pago antes de recibir") en "Instrucciones
   de pago del menú QR", **Then** el plan queda registrado con esa única modalidad.
2. **Given** un plan ya tiene una modalidad configurada, **When** el Super Admin la cambia
   por la otra, **Then** el cambio reemplaza por completo la modalidad anterior (nunca
   coexisten ambas) y queda disponible de inmediato para los tenants de ese plan.
3. **Given** un administrador de un tenant inicia sesión en su propia administración,
   **When** busca la configuración de modalidad de pago del menú QR, **Then** no encuentra
   ninguna opción para definirla o modificarla, porque es exclusiva del Super Admin.

---

### User Story 2 - El comensal ve la instrucción correcta según la modalidad del plan de su tenant (Priority: P1)

Como comensal que acaba de enviar mi orden desde el menú QR de una mesa, quiero ver un
mensaje claro sobre qué debo hacer a continuación según el método de pago que elegí, para
saber si debo esperar en la mesa o acercarme a caja.

**Why this priority**: Es el valor final visible para el usuario del negocio (el comensal);
sin esto, la configuración del plan no tiene ningún efecto observable.

**Independent Test**: Puede probarse de forma aislada fijando la modalidad de un plan y
enviando una orden desde el menú QR con cada método de pago habilitado (efectivo, Nequi,
mixto), verificando que el mensaje mostrado en la confirmación corresponde exactamente a la
combinación modalidad + método de pago.

**Acceptance Scenarios**:

1. **Given** el tenant está en un plan con modalidad PAY_AFTER_RECEIVING, **When** el
   comensal envía su orden pagando en efectivo, **Then** ve el mismo mensaje que el sistema
   ya muestra hoy: "Te llevaremos tu pedido a la mesa. Paga al recibirlo.".
2. **Given** el tenant está en un plan con modalidad PAY_AFTER_RECEIVING, **When** el
   comensal envía su orden pagando con Nequi, **Then** ve el mismo mensaje genérico de
   transferencia que el sistema ya muestra hoy, sin mencionar "Nequi" explícitamente:
   "Muestra el comprobante de tu banco al cajero cuando recibas tu pedido.".
3. **Given** el tenant está en un plan con modalidad PAY_AFTER_RECEIVING, **When** el
   comensal envía su orden con pago mixto, **Then** ve el mismo mensaje que el sistema ya
   muestra hoy: "Al recibir tu pedido, muestra el comprobante de la transferencia al
   cajero. El efectivo lo pagas al recibirlo.".
4. **Given** el tenant está en un plan con modalidad PAY_BEFORE_RECEIVING, **When** el
   comensal envía su orden pagando en efectivo, **Then** ve el mensaje "Dirígete a la caja
   para realizar el pago. ¡Llevaremos tu pedido hasta tu mesa!".
5. **Given** el tenant está en un plan con modalidad PAY_BEFORE_RECEIVING, **When** el
   comensal envía su orden pagando con Nequi, **Then** ve el mensaje "Acércate a la caja y
   muestra el comprobante de tu transferencia para validar el pago. ¡Llevaremos tu pedido
   hasta tu mesa!".
6. **Given** el tenant está en un plan con modalidad PAY_BEFORE_RECEIVING, **When** el
   comensal envía su orden con pago mixto, **Then** ve el mensaje "Acércate a la caja,
   presenta el comprobante de tu transferencia por Nequi y realiza el pago restante en
   efectivo. ¡Llevaremos tu pedido hasta tu mesa!".

---

### User Story 3 - El cambio de modalidad del Super Admin se refleja de inmediato en los tenants del plan (Priority: P2)

Como Super Admin, quiero que al cambiar la modalidad de un plan, todos los tenants
suscritos a ese plan vean el nuevo mensaje de inmediato en sus próximas órdenes, sin que
cada tenant deba hacer nada.

**Why this priority**: Garantiza que la configuración centralizada en el plan realmente
gobierne a todos sus tenants sin pasos manuales adicionales ni desincronización.

**Independent Test**: Con dos tenants en el mismo plan, cambiar la modalidad una sola vez
desde el plan y verificar que ambos tenants, en órdenes nuevas enviadas después del cambio,
ven el mensaje correspondiente a la nueva modalidad, sin ninguna acción propia.

**Acceptance Scenarios**:

1. **Given** dos tenants están suscritos al mismo plan, **When** el Super Admin cambia la
   modalidad de ese plan, **Then** ambos tenants ven el nuevo mensaje en las órdenes que sus
   comensales envíen desde ese momento en adelante.
2. **Given** un tenant está suscrito a un plan distinto del que fue modificado, **When** el
   Super Admin cambia la modalidad de otro plan, **Then** el mensaje que ven los comensales
   de ese tenant no cambia.
3. **Given** una orden fue enviada y confirmada antes de un cambio de modalidad, **When** el
   Super Admin cambia la modalidad después, **Then** la instrucción ya mostrada para esa
   orden pasada no se altera retroactivamente.

### Edge Cases

- ¿Qué pasa si el método de pago que el comensal eligió no es efectivo, Nequi ni mixto (por
  ejemplo, otro método del catálogo de pagos que el tenant tenga habilitado)? El sistema no
  muestra una instrucción específica para esa combinación; esta especificación solo define
  mensajes para efectivo, Nequi y mixto (ver Supuestos).
- ¿Qué pasa si un plan no tiene ninguna modalidad configurada explícitamente (por ejemplo,
  un plan creado antes de esta funcionalidad)? Se aplica el valor por defecto
  PAY_AFTER_RECEIVING, igual al comportamiento actual del sistema (ver Supuestos).
- ¿Qué pasa si el tenant cambia de plan (migra a uno con la otra modalidad) mientras hay
  órdenes abiertas sin cobrar? Las órdenes abiertas no se modifican; la nueva modalidad
  aplica únicamente a los mensajes mostrados en órdenes enviadas desde el menú QR después
  del cambio de plan.
- ¿Qué pasa si un tenant administrador intenta acceder por API o URL directa a la
  configuración de modalidad de otro plan o de otro tenant? El sistema deniega el acceso
  igual que ante cualquier otro intento de acceso cruzado entre tenants.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema DEBE permitir al Super Admin seleccionar, para cada plan, una
  "Instrucción de pago del menú QR" con exactamente uno de dos valores: PAY_AFTER_RECEIVING
  (pago después de recibir) o PAY_BEFORE_RECEIVING (pago antes de recibir).
- **FR-002**: El sistema DEBE impedir que un plan tenga más de una modalidad seleccionada o
  ninguna modalidad válida una vez configurada explícitamente.
- **FR-003**: El sistema DEBE aplicar automáticamente la modalidad configurada en el plan a
  todos los tenants suscritos a ese plan, sin que el tenant deba realizar ninguna acción.
- **FR-004**: El sistema NO DEBE permitir que ningún rol de administración del tenant
  consulte, edite o sobrescriba la modalidad de pago del menú QR; esta solo es editable
  desde la administración de planes por el Super Admin.
- **FR-005**: El sistema DEBE determinar la modalidad aplicable a una orden usando
  únicamente el plan vigente del tenant propietario de esa orden, sin considerar planes de
  otros tenants.
- **FR-006**: El sistema DEBE mostrar, en la pantalla de confirmación del menú QR
  inmediatamente después de que el comensal envía su orden, un mensaje de instrucción
  determinado por la combinación de la modalidad del plan del tenant y el método de pago
  elegido por el comensal (efectivo, Nequi o mixto).
- **FR-007**: Cuando la modalidad del plan sea PAY_AFTER_RECEIVING, el sistema DEBE mostrar
  textualmente el mismo mensaje que ya muestra hoy, sin modificarlo: (a) para efectivo,
  "Te llevaremos tu pedido a la mesa. Paga al recibirlo."; (b) para Nequi, el mensaje
  genérico de transferencia ya existente, "Muestra el comprobante de tu banco al cajero
  cuando recibas tu pedido." (sin mencionar "Nequi" explícitamente, igual que el
  comportamiento actual, que trata Nequi como un método de transferencia genérico); (c) para
  mixto, "Al recibir tu pedido, muestra el comprobante de la transferencia al cajero. El
  efectivo lo pagas al recibirlo.".
- **FR-008**: Cuando la modalidad del plan sea PAY_BEFORE_RECEIVING, el sistema DEBE mostrar
  textualmente: (a) para efectivo, "Dirígete a la caja para realizar el pago. ¡Llevaremos tu
  pedido hasta tu mesa!"; (b) para Nequi, "Acércate a la caja y muestra el comprobante de tu
  transferencia para validar el pago. ¡Llevaremos tu pedido hasta tu mesa!"; (c) para mixto,
  "Acércate a la caja, presenta el comprobante de tu transferencia por Nequi y realiza el
  pago restante en efectivo. ¡Llevaremos tu pedido hasta tu mesa!".
- **FR-009**: El sistema NO DEBE mostrar una instrucción para un método de pago que no esté
  habilitado para el tenant que recibe la orden.
- **FR-010**: Esta funcionalidad DEBE limitarse a determinar el mensaje informativo
  mostrado en el menú QR tras enviar la orden; NO DEBE modificar el flujo de creación o
  procesamiento de órdenes, los estados de las órdenes, los estados de pago, los estados de
  los productos, ni los métodos de pago habilitados para el tenant.
- **FR-011**: El sistema NO DEBE realizar ninguna validación o confirmación automática de
  pagos ni de comprobantes de transferencia como parte de esta funcionalidad; esa validación
  sigue siendo responsabilidad del personal de caja.
- **FR-012**: El sistema NO DEBE integrar ninguna API o servicio automático de Nequi como
  parte de esta funcionalidad.
- **FR-013**: El sistema NO DEBE mostrar ni modificar esta instrucción en las interfaces de
  POS, terminal de mesas, caja o cocina; aplica exclusivamente a la experiencia del
  comensal en el menú QR.
- **FR-014**: Un cambio de modalidad realizado por el Super Admin DEBE reflejarse en las
  órdenes enviadas desde ese momento en adelante, sin alterar instrucciones ya mostradas
  para órdenes enviadas antes del cambio.

### Key Entities

- **Plan**: Catálogo de características administradas por el Super Admin (ver
  especificación de planes de suscripción existente). Se le incorpora una nueva
  característica, "Instrucción de pago del menú QR", con exactamente uno de los valores
  PAY_AFTER_RECEIVING o PAY_BEFORE_RECEIVING. Es la única fuente de verdad de esta
  modalidad; el tenant no almacena una copia propia.
- **Tenant**: Negocio suscrito a un plan vigente. Hereda la modalidad de pago del menú QR
  del plan al que está suscrito; no posee configuración propia de esta característica.
- **Orden (menú QR)**: Pedido enviado por un comensal desde el menú QR de una mesa, con un
  método de pago elegido (efectivo, Nequi o mixto). Pertenece a un tenant y es el contexto
  en el que se determina y muestra la instrucción de pago correspondiente.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El Super Admin puede configurar o cambiar la modalidad de pago del menú QR de
  un plan en menos de 1 minuto, sin necesitar soporte técnico.
- **SC-002**: El 100% de los comensales que envían una orden desde el menú QR ven una
  instrucción de pago coherente con la modalidad vigente del plan de ese tenant y con el
  método de pago que eligieron.
- **SC-003**: El 100% de los tenants suscritos a un mismo plan muestran exactamente la misma
  instrucción de pago a sus comensales para una misma combinación de modalidad y método de
  pago, sin excepciones por tenant.
- **SC-004**: Ningún administrador de tenant logra modificar la modalidad de pago del menú
  QR heredada de su plan, en el 100% de los intentos.
- **SC-005**: Un cambio de modalidad hecho por el Super Admin se refleja en los mensajes
  mostrados a los comensales de los tenants afectados sin requerir ninguna acción del tenant
  ni reprocesar órdenes existentes.

## Assumptions

- Esta funcionalidad extiende el modelo de características de planes ya existente (ver
  especificación de planes de suscripción por tenant); no crea un sistema de configuración
  independiente.
- Un plan creado antes de esta funcionalidad, o que no tenga la modalidad configurada
  explícitamente, se trata por defecto como PAY_AFTER_RECEIVING, porque es el
  comportamiento actual del sistema (el comensal recibe su pedido y paga después) y así se
  preserva la experiencia existente sin cambios no solicitados.
- Las instrucciones definidas en esta especificación cubren únicamente los tres métodos de
  pago mencionados por el negocio: efectivo, Nequi y mixto (efectivo + Nequi). Otros métodos
  de pago del catálogo que un tenant pueda tener habilitados (ej. otra transferencia
  bancaria) no tienen un mensaje específico definido en esta fase y quedan fuera de alcance.
- El punto de aparición de la instrucción es la pantalla de confirmación del menú QR que ya
  existe hoy inmediatamente después de enviar la orden (la misma pantalla donde hoy se
  muestra el desglose de pago), no una pantalla nueva.
- La modalidad del plan se evalúa en el momento en que se muestra la instrucción al
  comensal (justo después de enviar la orden), usando el plan vigente del tenant en ese
  momento.

## Out of Scope

- Modificación del flujo de creación y procesamiento de órdenes.
- Modificación de estados de pago o estados operativos de la orden o de los productos.
- Validación automática de comprobantes de transferencia.
- Integración con cualquier API de Nequi.
- Cambios en las interfaces de POS, caja, terminal de mesas o cocina.
- Configuración individual de la modalidad de pago del menú QR por parte del tenant.
