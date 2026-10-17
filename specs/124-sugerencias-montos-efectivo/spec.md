# Feature Specification: Sugerencias de Montos para Pago en Efectivo

**Feature Branch**: `124-sugerencias-montos-efectivo`

**Created**: 2026-10-17

**Status**: Draft

**Input**: User description: "Como cajero, quiero ver botones con montos sugeridos según los
billetes más probables, para registrar con un toque con cuánto paga el cliente, sin digitarlo.

Contexto / Reglas de negocio

Se muestran hasta 5 sugerencias: el monto exacto más los redondeos hacia arriba a 5.000, 10.000,
50.000 y 100.000. También el redondeo a 1.000 si el monto no es múltiplo de 1.000. Los duplicados
se eliminan y la lista se ordena de menor a mayor.

Ejemplo con $22.000: Exacto · $25.000 · $30.000 · $50.000 · $100.000.

Ejemplo con $47.500: Exacto · $48.000 · $50.000 · $100.000.

Las denominaciones de redondeo se configuran según la moneda del tenant. Por defecto se usan las
de COP.

Si hay varios métodos de pago ("Agregar otro método"), las sugerencias se calculan sobre la
porción en efectivo pendiente, no sobre el total.

Aplica igual para pedidos de mesa, manuales y a domicilio. En domicilio se mantiene la regla de
preguntar siempre con cuánto paga el cliente.

[Probable] En tu captura, el campo "Con cuánto paga" ya viene con 22.000. Si se rellena
automáticamente con el total, el botón "Exacto" queda redundante y además se pierde la
verificación del monto recibido. Recomiendo que el campo arranque vacío y que el cajero elija con
un botón.

Escenario: Seleccionar un monto sugerido
  Dado que el total a cobrar es $22.000 y el método es "Efectivo"
  Cuando el cajero toca la sugerencia "$50.000"
  Entonces el campo "Con cuánto paga" muestra $50.000
  Y se muestra "Vuelto: $28.000"
  Y el botón "Cobrar" se habilita

Escenario: Pago combinado con efectivo
  Dado que el total es $22.000
  Y el cajero registró $10.000 por Nequi
  Cuando selecciona "Efectivo" como segundo método
  Entonces las sugerencias se calculan sobre $12.000: "Exacto, $15.000, $20.000, $50.000,
$100.000"

Escenario: Monto ingresado menor al saldo
  Dado que el total es $22.000
  Cuando el cajero escribe a mano $20.000 en "Con cuánto paga"
  Entonces se muestra "Faltan $2.000"
  Y el botón "Cobrar" queda deshabilitado

Escenario: Las sugerencias no aplican a otros métodos
  Dado que el método seleccionado es "Bancolombia"
  Entonces no se muestran sugerencias de billetes"

## Contexto y comportamiento actual

**Esta funcionalidad se apoya en un flujo de cobro que ya existe y ya funciona; no parte de
cero.** El campo "Con cuánto paga", el cálculo de "Vuelto", el botón "Cobrar" y el flujo de pago
mixto ("Agregar otro método") ya existen y están descritos en las specs
[057](../057-cobro-mesa-importe-y-cliente/spec.md),
[073](../073-fix-descuento-cobro-terminal/spec.md) y
[112](../112-fix-cobro-pago-mixto/spec.md). Hoy el sistema ya hace lo siguiente:

- **El campo de importe se precarga automáticamente al elegir un método.** Al seleccionar
  cualquier método de pago para una línea (incluido "Efectivo"), el campo "Con cuánto paga" se
  llena de inmediato con el monto exacto que esa línea debe cubrir: el total del pedido si es el
  único método, o el saldo pendiente de asignar si ya hay otras líneas (spec 112, FR-014). Para
  métodos distintos a efectivo el campo queda además no editable (spec 057, spec 073 FR-006).
- **El pago mixto ya calcula un "saldo pendiente".** Al agregar una segunda línea de pago con
  "Agregar otro método", esa línea nace precargada con el saldo pendiente de asignar, y ese saldo
  se recalcula de inmediato si se agrega, edita o elimina otra línea (spec 112, FR-003/FR-010).
- **La validación de monto insuficiente en efectivo ya existe.** Cuando el monto escrito en "Con
  cuánto paga" es menor al monto que esa línea debe cubrir, el sistema ya muestra un mensaje de
  faltante (patrón "Faltan $[monto] para cubrir la cuenta.", spec 073) y mantiene deshabilitado
  "Cobrar"; cuando alcanza o supera ese monto, calcula y muestra el "Vuelto".
- **Ya existe un catálogo de denominaciones por tenant, pero para otro propósito.** La spec
  [121](../121-desglose-denominaciones-cierre/spec.md) introduce, para el arqueo de cierre de
  caja, un catálogo de denominaciones expuesto por el backend por tenant (COP por defecto, solo
  lectura, sin pantalla de administración). Esa lista sirve para contar efectivo físico (billetes
  y monedas) y es distinta de las denominaciones de redondeo de esta spec (ver Clarifications):
  esta funcionalidad no la reutiliza ni depende de ella.
- **El tenant no tiene hoy ningún concepto de "moneda" distinta de COP.** Todos los montos del
  sistema son pesos colombianos enteros sin decimales (spec 073, Assumptions).
- **También existe un campo de monto recibido fuera de los paneles de cobro de la Terminal.** El
  panel "Pagos por confirmar" (spec 073, `PaymentAttemptReviewPanelComponent`) es donde el cajero
  revisa un pago en efectivo que el cliente declaró al pagar por QR: registra "el efectivo
  recibido" y pulsa "Confirmar efectivo". Es el mismo tipo de campo que "Con cuánto paga", sobre
  el monto total de ese pedido.

### Decisión de negocio que cambia comportamiento existente

Conforme al Principio II de la [Constitución](../../.specify/memory/constitution.md), este cambio
quedó registrado como
[A-135](../000-reconocimiento/registro-de-anomalias.md#a-135--decisión-de-negocio--spec-124-el-campo-con-cuánto-paga-deja-de-precargarse-automáticamente-cuando-el-método-de-la-línea-es-efectivo)
en `specs/000-reconocimiento/registro-de-anomalias.md`, durante la planificación de esta spec
(2026-10-17). Fue solicitado directamente por quien reportó esta funcionalidad, a partir de la
observación de que el precargado actual vuelve redundante el botón "Exacto" y oculta la
verificación real del monto recibido.

| Comportamiento que cambia | Hoy | Desde esta spec | Funcionalidades afectadas |
|---|---|---|---|
| Precargado inicial de "Con cuánto paga" cuando el método de la línea es Efectivo | Se precarga automáticamente con el monto que la línea debe cubrir (total o saldo pendiente), spec 112 FR-014 | Nace vacío; el cajero lo llena tocando una sugerencia o escribiéndolo | Panel de cobro de mesa, pedido manual, pedido a domicilio; pago con un solo método y pago mixto |

Este cambio aplica **solo** a líneas en Efectivo. Las líneas con un método distinto a efectivo
siguen precargándose con el monto exacto a asignar y permanecen no editables, sin ningún cambio.

## Clarifications

### Session 2026-10-17

- Q: ¿Las denominaciones de redondeo son una lista fija propia de esta funcionalidad, o se
  derivan del catálogo de denominaciones por tenant de la spec 121? → A: Lista fija propia,
  independiente del catálogo de la spec 121: **8.000, 10.000, 20.000, 50.000 y 100.000**
  (reemplaza la lista del enunciado original, 1.000/5.000/10.000/50.000/100.000). El "monto
  exacto" ya no se agrega como un sexto candidato aparte; la lista de sugerencias son siempre los
  redondeos hacia arriba a esas 5 denominaciones. Cuando uno de esos redondeos coincide con el
  saldo pendiente (porque ya era múltiplo exacto de esa denominación), ese botón se etiqueta
  "Exacto" en vez de mostrar el valor repetido.
- Q: ¿Deben mostrarse también en el panel "Pagos por confirmar" (revisión del cajero de un pago en
  efectivo que el cliente declaró al pagar por QR, spec 073)? → A: Sí. Las sugerencias aplican
  igual ahí: el saldo pendiente a cubrir es el total de ese pedido (spec 073 no introduce pago
  mixto en este panel), y el cajero puede tocar una sugerencia en vez de escribir el monto que el
  cliente dijo entregar.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Registrar con un toque con cuánto paga el cliente (Priority: P1)

Un cajero está cobrando un pedido en efectivo. En vez de escribir el monto que el cliente entrega,
el sistema le muestra hasta 5 botones con los montos más probables (el monto exacto y los
redondeos a los billetes de uso común), y al tocar uno el campo "Con cuánto paga" se llena de
inmediato, mostrando el vuelto correspondiente.

**Why this priority**: es la capacidad central de esta funcionalidad — sin ella no hay nada que
sugerir ni que tocar; el resto de historias son extensiones o restricciones de esta base.

**Independent Test**: puede probarse por completo cobrando un pedido en efectivo con un único
método de pago, tocando una de las sugerencias mostradas, y verificando que el campo se llena, que
el vuelto se calcula correctamente y que "Cobrar" se habilita.

**Acceptance Scenarios**:

1. **Given** un pedido con total $22.000 y el cajero selecciona "Efectivo" como método de pago,
   **When** se muestra el panel de cobro, **Then** el campo "Con cuánto paga" aparece vacío (no
   precargado con el total) y se muestran las sugerencias "$24.000", "$30.000", "$40.000",
   "$50.000" y "$100.000", en ese orden (ninguna etiquetada "Exacto", porque $22.000 no coincide
   con ningún redondeo).
2. **Given** ese mismo pedido, **When** el cajero toca la sugerencia "$50.000", **Then** el campo
   "Con cuánto paga" muestra $50.000, se muestra "Vuelto: $28.000" y el botón "Cobrar" se habilita.
3. **Given** un pedido con total $47.500, **When** se muestra el panel de cobro en efectivo,
   **Then** las sugerencias mostradas son "$48.000", "$50.000", "$60.000" y "$100.000" (4 botones,
   el redondeo a 10.000 y a 50.000 coinciden en $50.000 y se eliminan los duplicados).
4. **Given** el cajero tocó una sugerencia, **When** vuelve a tocar otra sugerencia distinta antes
   de cobrar, **Then** el campo "Con cuánto paga" se actualiza con el nuevo valor y el vuelto se
   recalcula de inmediato.

---

### User Story 2 - Sugerencias correctas en pago combinado con efectivo (Priority: P2)

Un cajero está dividiendo el cobro de un pedido entre varios métodos de pago ("Agregar otro
método"). Cuando la línea en curso es Efectivo, las sugerencias deben calcularse sobre lo que
falta por cubrir en esa línea (el saldo pendiente), nunca sobre el total completo del pedido.

**Why this priority**: sin este ajuste, las sugerencias de la Historia 1 serían incorrectas en
cualquier cobro con más de un método, ofreciendo montos mayores a lo que el cliente realmente debe
pagar en efectivo — es una extensión necesaria, pero depende de que la Historia 1 ya exista.

**Independent Test**: puede probarse registrando primero un pago parcial con un método distinto a
efectivo, agregando luego una línea de Efectivo, y verificando que las sugerencias mostradas
corresponden al saldo pendiente y no al total original.

**Acceptance Scenarios**:

1. **Given** un pedido con total $22.000 donde el cajero ya registró $10.000 por Nequi, **When**
   selecciona "Efectivo" como segundo método, **Then** las sugerencias se calculan sobre el saldo
   pendiente de $12.000 y muestran "$16.000", "$20.000", "$50.000" y "$100.000" (4 botones; el
   redondeo a 10.000 y a 20.000 coinciden en $20.000 y se elimina el duplicado).
2. **Given** esa misma línea de efectivo con sugerencias ya mostradas, **When** el cajero elimina
   la línea de Nequi o cambia su monto, **Then** las sugerencias de la línea de efectivo se
   recalculan de inmediato sobre el nuevo saldo pendiente.

---

### User Story 3 - El sistema sigue bloqueando el cobro si el monto recibido no alcanza (Priority: P3)

Un cajero escribe manualmente en "Con cuánto paga" un valor menor al que la línea de efectivo debe
cubrir, en vez de tocar una sugerencia. El sistema debe seguir mostrando el faltante y bloqueando
"Cobrar", igual que lo hace hoy, pero comparando siempre contra el saldo que esa línea debe cubrir
(no contra el total del pedido cuando hay pago mixto).

**Why this priority**: preserva una protección que ya existe en el sistema (spec 073); esta
historia solo confirma que sigue vigente y que usa el saldo correcto una vez el campo deja de
precargarse automáticamente.

**Independent Test**: puede probarse escribiendo a mano, en el campo "Con cuánto paga", un valor
menor al saldo que la línea de efectivo debe cubrir, y verificando que aparece el mensaje de
faltante y que "Cobrar" permanece deshabilitado.

**Acceptance Scenarios**:

1. **Given** un pedido con total $22.000 y método Efectivo, **When** el cajero escribe a mano
   $20.000 en "Con cuánto paga", **Then** se muestra "Faltan $2.000 para cubrir la cuenta." y el
   botón "Cobrar" queda deshabilitado.
2. **Given** ese mismo campo con $20.000 escritos, **When** el cajero corrige el valor a $25.000 (o
   toca una sugerencia que lo cubra), **Then** el mensaje de faltante desaparece, se muestra el
   vuelto correspondiente y "Cobrar" se habilita.

---

### User Story 4 - Sin sugerencias de billetes para métodos distintos a efectivo (Priority: P3)

Un cajero selecciona un método de pago que no es efectivo (por ejemplo, "Bancolombia" o "Nequi").
El sistema no debe mostrarle botones de montos sugeridos, ya que esos métodos no manejan vuelto ni
billetes físicos.

**Why this priority**: delimita el alcance de la funcionalidad y evita sugerencias sin sentido en
métodos donde no aplican; es una restricción simple, independiente de las demás historias.

**Independent Test**: puede probarse seleccionando un método distinto a efectivo en una línea de
pago y verificando que no aparece ningún botón de sugerencia.

**Acceptance Scenarios**:

1. **Given** el cajero selecciona "Bancolombia" como método de pago de una línea, **When** observa
   el panel de cobro, **Then** no se muestra ningún botón de monto sugerido para esa línea.

---

### User Story 5 - Confirmar con un toque un pago en efectivo declarado por QR (Priority: P2)

Un cliente pagó por QR y declaró que pagaría en efectivo. El cajero abre "Pagos por confirmar"
para registrar cuánto recibió y pulsar "Confirmar efectivo". En vez de escribirlo, el cajero
también puede tocar una sugerencia de monto, igual que en el panel de cobro de mesa, manual o
domicilio.

**Why this priority**: extiende el mismo valor de la Historia 1 a una superficie distinta donde
hoy existe el mismo tipo de campo de monto recibido (spec 073); depende de que la lógica de
sugerencias ya exista.

**Independent Test**: puede probarse abriendo "Pagos por confirmar" para un pedido de comensal
por QR con pago en efectivo declarado, tocando una sugerencia, y verificando que el campo se
llena y que "Confirmar efectivo" se habilita igual que si el monto se hubiera escrito a mano.

**Acceptance Scenarios**:

1. **Given** un pedido de comensal por QR con total $16.000 y pago en efectivo declarado, **When**
   el cajero abre "Pagos por confirmar", **Then** ve hasta 5 botones de monto sugerido calculados
   sobre los $16.000, además del campo de monto recibido vacío.
2. **Given** ese mismo panel, **When** el cajero toca una de las sugerencias, **Then** el campo de
   monto recibido se llena con ese valor y "Confirmar efectivo" se habilita si el valor cubre el
   total.

---

### Edge Cases

- ¿Qué pasa si el saldo pendiente en efectivo de una línea es $0 (ya cubierto totalmente por otras
  líneas)? No se muestran sugerencias ni campo "Con cuánto paga" para esa línea, igual que el
  comportamiento ya existente para montos pendientes en $0.
- ¿Qué pasa si varios redondeos coinciden entre sí, o con el saldo pendiente (por ejemplo, un
  saldo de exactamente $100.000)? El redondeo a 8.000 da $104.000, y los redondeos a 10.000,
  20.000, 50.000 y 100.000 dan los cuatro $100.000 (ya era múltiplo exacto de todos ellos). Tras
  eliminar duplicados solo quedan 2 botones: "Exacto" ($100.000, porque coincide con el saldo
  pendiente) y "$104.000".
- ¿Qué pasa si, después de tocar una sugerencia, el saldo pendiente de esa línea cambia por agregar
  o quitar otra línea de pago? Las sugerencias se recalculan sobre el nuevo saldo; el valor que ya
  estaba en "Con cuánto paga" no queda validado automáticamente contra un saldo que ya no existe,
  y el sistema vuelve a evaluar si alcanza o falta.
- ¿Qué pasa en un pedido a domicilio? Se aplican las mismas reglas que en mesa y mostrador; el
  sistema sigue exigiendo siempre registrar con cuánto paga el cliente en efectivo, sin omitir el
  paso aunque el monto ya se conozca de antemano.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Cuando el método de pago seleccionado para una línea de cobro sea "Efectivo", el
  sistema MUST mostrar hasta 5 botones de montos sugeridos, calculados sobre el saldo pendiente
  que esa línea debe cubrir en ese momento (no sobre el total del pedido).
- **FR-002**: El conjunto de sugerencias MUST ser el resultado de redondear el saldo pendiente
  hacia arriba (o mantenerlo igual si ya es múltiplo exacto) a cada una de las denominaciones de
  redondeo configuradas (por defecto en COP: 8.000, 10.000, 20.000, 50.000 y 100.000); el monto
  exacto pendiente MUST NOT agregarse como un sexto candidato aparte.
- **FR-003**: El sistema MUST eliminar los valores duplicados que resulten del cálculo de
  redondeos y MUST mostrar la lista final ordenada de menor a mayor, con un máximo de 5 botones
  (uno por denominación configurada, menos los que se eliminen por duplicado).
- **FR-004**: Las denominaciones usadas para calcular los redondeos MUST configurarse según la
  moneda del tenant; mientras el tenant no tenga una configuración propia, el sistema MUST usar
  por defecto las denominaciones de peso colombiano (COP) listadas en FR-002. Esta configuración
  es independiente del catálogo de denominaciones de arqueo de caja de la spec 121.
- **FR-005**: Al tocar un botón de monto sugerido, el sistema MUST llenar el campo "Con cuánto
  paga" de esa línea con el valor tocado, sin requerir que el cajero lo digite.
- **FR-006**: El sistema MUST mostrar "Vuelto: $[monto]" de inmediato cuando el valor registrado
  en "Con cuánto paga" (por botón o escrito a mano) sea mayor o igual al saldo pendiente de la
  línea, y MUST habilitar el botón "Cobrar" para esa línea en ese caso (sujeto a que el resto de
  líneas de pago, si existen, también estén completas).
- **FR-007**: El sistema MUST mostrar "Faltan $[monto] para cubrir la cuenta." y MUST mantener
  deshabilitado el botón "Cobrar" cuando el valor registrado en "Con cuánto paga" sea menor al
  saldo pendiente de la línea, sin importar si ese valor se llenó con una sugerencia o se escribió
  a mano.
- **FR-008**: Cuando el método de pago de una línea sea distinto de "Efectivo", el sistema MUST
  NOT mostrar botones de montos sugeridos para esa línea.
- **FR-009**: Cuando existan varias líneas de pago (pago mixto, "Agregar otro método") y una de
  ellas sea "Efectivo", las sugerencias de esa línea MUST calcularse sobre el saldo pendiente de
  asignar vigente al momento de mostrarse, y MUST recalcularse de inmediato si ese saldo cambia
  (por agregar, editar o eliminar otra línea).
- **FR-010**: El campo "Con cuánto paga" de una línea en Efectivo MUST iniciar vacío al
  seleccionarse "Efectivo" como método de esa línea (ya no se precarga automáticamente con el
  total ni con el saldo pendiente); el cajero MUST llenarlo tocando una sugerencia o escribiéndolo
  antes de que "Cobrar" pueda habilitarse para esa línea. Las líneas con un método distinto a
  efectivo conservan su comportamiento actual (precargadas con el monto exacto a asignar, no
  editables).
- **FR-011**: Esta funcionalidad MUST aplicar de forma idéntica a pedidos de mesa, pedidos
  manuales (mostrador) y pedidos a domicilio; en pedidos a domicilio el sistema MUST seguir
  exigiendo siempre el registro de "Con cuánto paga" el cliente en efectivo, sin omitir el paso.
- **FR-012**: Cuando uno de los montos sugeridos coincida con el saldo pendiente (porque éste ya
  era múltiplo exacto de esa denominación), el sistema MUST mostrar ese botón etiquetado "Exacto"
  en vez de repetir el valor numérico ya presente en otro botón.
- **FR-013**: El panel "Pagos por confirmar" (revisión del cajero de un pago en efectivo
  declarado por el cliente al pagar por QR, spec 073) MUST mostrar también hasta 5 botones de
  monto sugerido, calculados sobre el total del pedido, siguiendo las mismas reglas FR-001 a
  FR-004 y FR-012.

### Key Entities *(include if feature involves data)*

- **Línea de pago en efectivo**: la línea de pago (ya existente, spec 112) cuyo método es
  "Efectivo", o el campo equivalente de monto recibido del panel "Pagos por confirmar" (spec 073).
  Para esta funcionalidad importan su saldo pendiente a cubrir (total del pedido si es la única
  línea, o lo que falte por asignar si hay pago mixto) y el monto que el cajero registra en "Con
  cuánto paga", del cual se derivan las sugerencias, el vuelto y el mensaje de faltante.
- **Denominaciones de redondeo del tenant**: la lista ordenada de valores monetarios usados para
  calcular las sugerencias de monto (por defecto en COP: 8.000, 10.000, 20.000, 50.000 y
  100.000), configurada según la moneda del tenant. Es una configuración propia de esta
  funcionalidad, independiente del catálogo de denominaciones para el arqueo de caja de la spec
  121.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El cajero puede registrar el monto con el que paga el cliente en efectivo tocando
  un solo botón, sin usar el teclado, en cualquier cobro donde el cliente paga con un billete igual
  o mayor al saldo pendiente.
- **SC-002**: El vuelto o el mensaje de faltante se actualiza en menos de 1 segundo después de
  tocar una sugerencia o de modificar el monto escrito.
- **SC-003**: En el 100% de los cobros con pago mixto, las sugerencias mostradas para la línea de
  efectivo corresponden al saldo pendiente vigente en ese momento, nunca al total original del
  pedido.
- **SC-004**: El botón "Cobrar" nunca queda habilitado mientras el monto registrado en efectivo
  sea menor al saldo pendiente de esa línea, en el 100% de los casos.
- **SC-005**: En pedidos con saldo pendiente en efectivo, la lista de sugerencias nunca muestra
  valores duplicados ni más de 5 botones.
- **SC-006**: El cajero puede confirmar con un toque, sin digitarlo, un pago en efectivo
  declarado por el cliente al pagar por QR, desde el panel "Pagos por confirmar".

## Assumptions

- El campo "Con cuánto paga", el cálculo de "Vuelto"/mensaje de faltante, el botón "Cobrar" y el
  flujo de pago mixto ("Agregar otro método", "saldo pendiente") ya existen (specs 057, 073, 112);
  esta funcionalidad agrega los botones de sugerencia sobre ese flujo y ajusta únicamente el
  precargado inicial del campo en efectivo (FR-010), sin rediseñar el resto del panel de cobro.
- Las "denominaciones de redondeo" de esta spec son una configuración propia (ver Clarifications),
  independiente del catálogo de denominaciones de arqueo de caja de la spec 121; no se crea una
  pantalla de administración nueva para ninguna de las dos.
- Todos los tenants operan hoy en pesos colombianos (COP), enteros y sin decimales (spec 073); por
  eso el valor por defecto de las denominaciones de redondeo es el único vigente en la práctica
  actual, aunque el sistema las modele como configurables por moneda del tenant.
- Esta spec no modifica el catálogo de métodos de pago (spec 032, qué métodos existen y si admiten
  vuelto); solo cambia el comportamiento del campo de monto cuando el método ya identificado como
  efectivo está seleccionado.
- El cambio de comportamiento sobre la precarga del campo "Con cuánto paga" en efectivo (FR-010)
  quedó registrado como A-135 en `specs/000-reconocimiento/registro-de-anomalias.md`, conforme al
  Principio II de la Constitución (ver "Decisión de negocio que cambia comportamiento existente"
  arriba).
