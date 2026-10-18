# Feature Specification: Confirmación Única de Pago

**Feature Branch**: `125-confirmacion-pago-unica`

**Created**: 2026-10-17

**Status**: Draft

**Input**: User description: "Como cajero, quiero ver una única confirmación cuando registro un
pago, para no tener que cerrar varias alertas repetidas y seguir atendiendo más rápido. Hoy un
cobro dispara tres avisos: el modal 'Pago registrado', el toast 'Pago recibido · $22000.00' y el
toast 'Pedido cobrado, facturado y enviado a cocina'. Además, el segundo toast no respeta el
formato de moneda: muestra $22000.00 en lugar de $ 22.000. La duplicación viene probablemente de
mezclar la respuesta HTTP del cobro con el evento SSE de pago, que también recibe la misma
terminal que originó el cobro. Debe quedar un solo modal 'Pago registrado' con el monto, el
cliente, el método de pago, el vuelto si el pago fue en efectivo, y las acciones 'Imprimir
factura' y 'Cerrar'. Las demás terminales del tenant sí deben seguir recibiendo la notificación en
tiempo real; solo se silencia en la sesión que hizo el cobro."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Confirmación única en la terminal que cobra (Priority: P1)

Cuando un cajero registra un cobro exitoso, ve una sola confirmación: el modal "Pago registrado"
con el monto, el cliente, el método de pago y el vuelto (si fue en efectivo). No aparece ningún
toast adicional sobre ese mismo cobro en su propia terminal.

**Why this priority**: es el problema reportado — hoy el cajero debe cerrar tres avisos repetidos
por cada cobro, lo que le resta velocidad de atención. Sin esta corrección no hay valor de negocio
que entregar.

**Independent Test**: se puede probar cobrando un pedido en efectivo y verificando que solo
aparece el modal "Pago registrado", con ningún toast adicional visible en esa misma terminal.

**Acceptance Scenarios**:

1. **Given** el cajero cobra $22.000 en efectivo con $50.000, **When** el pago se registra
   correctamente, **Then** se muestra un único modal "Pago registrado" que indica "$ 22.000 ·
   Consumidor Final · Efectivo · Vuelto $ 28.000", y no se muestra ningún toast adicional en esa
   terminal.
2. **Given** el cajero cobra con un método distinto a efectivo (p. ej. tarjeta o transferencia),
   **When** el pago se registra correctamente, **Then** el modal muestra el monto, el cliente y el
   método de pago, sin ninguna línea de vuelto, y tampoco se muestra ningún toast adicional en esa
   terminal.

---

### User Story 2 - Otras terminales del tenant siguen notificadas en tiempo real (Priority: P1)

Las demás terminales del mismo tenant que no originaron el cobro deben seguir recibiendo, en
tiempo real, la notificación del pago — ahora con el monto correctamente formateado. Solo se
silencia la notificación repetida en la sesión que hizo el cobro.

**Why this priority**: es la otra mitad de la misma regla de negocio — eliminar la duplicación en
la terminal de origen no puede significar que el resto del tenant deje de enterarse del cobro en
tiempo real (spec 077).

**Independent Test**: se puede probar abriendo dos terminales del mismo tenant, cobrando desde una
de ellas, y verificando que solo la otra terminal muestra la notificación, con el monto bien
formateado.

**Acceptance Scenarios**:

1. **Given** hay dos terminales abiertas en el mismo tenant, **When** la terminal A registra un
   pago, **Then** la terminal B muestra una notificación "Pago recibido · Mesa 1 · $ 22.000" (con
   el formato de moneda correcto), y la terminal A no muestra esa notificación.

---

### User Story 3 - Fallo al registrar el pago (Priority: P2)

Si el backend responde con error al intentar cobrar, el cajero ve un único mensaje de error con el
motivo, nunca el modal de éxito, y el formulario de cobro conserva los datos que ya había
ingresado para poder corregir y reintentar sin volver a escribir todo.

**Why this priority**: evita que el cajero pierda el trabajo ya hecho (monto recibido, cliente,
método) ante un error transitorio, y evita que una falla parcial muestre una confirmación de éxito
incorrecta.

**Independent Test**: se puede probar simulando un error del backend al cobrar y verificando que
no aparece el modal de éxito, que aparece un único mensaje de error, y que los campos del
formulario de cobro mantienen los valores ingresados.

**Acceptance Scenarios**:

1. **Given** el backend responde con error al cobrar, **When** el cajero intenta registrar el
   pago, **Then** no se muestra el modal de éxito, se muestra un único mensaje de error con el
   motivo, y el formulario de cobro conserva los datos ingresados.

---

### User Story 4 - Imprimir o cerrar desde la confirmación (Priority: P3)

Desde el modal "Pago registrado", el cajero puede imprimir la factura del cobro recién registrado
o simplemente cerrar la confirmación, sin tener que buscar la acción de impresión en otra parte
de la pantalla.

**Why this priority**: es la acción de seguimiento natural tras confirmar el cobro, pero depende
de que el modal único (Historia 1) ya exista; no bloquea el valor central de esta funcionalidad.

**Decisión de negocio que cambia comportamiento existente**: para un cobro de un solo comprobante
(no cuenta dividida), el modal "Pago registrado" hoy **no** tiene botón de impresión — la spec
[029](../029-correccion-cobro-cierre-mesa/spec.md) lo retiró a propósito para no duplicar el
botón "Imprimir Factura" ya existente en el panel lateral de cobro. Esta spec reintroduce el
botón "Imprimir Factura" dentro del modal para ese caso, para que la confirmación quede
autocontenida. Conforme al Principio II de la
[Constitución](../../.specify/memory/constitution.md), este cambio quedó registrado como
[A-136](../000-reconocimiento/registro-de-anomalias.md#a-136--decisión-de-negocio--spec-125-se-revierte-el-retiro-de-imprimir-factura-del-modal-de-éxito-en-pagos-de-un-solo-comprobante-hecho-por-la-spec-029)
en `specs/000-reconocimiento/registro-de-anomalias.md`. El botón del panel lateral no se retira:
sigue disponible para reimpresiones posteriores al cerrar el modal.

**Independent Test**: se puede probar mostrando el modal "Pago registrado" y verificando que
"Imprimir factura" envía la factura a impresión y cierra el modal, y que "Cerrar" lo cierra sin
imprimir nada.

**Acceptance Scenarios**:

1. **Given** se muestra el modal "Pago registrado", **When** el cajero selecciona "Imprimir
   factura", **Then** se envía la factura a impresión y el modal se cierra.
2. **Given** se muestra el modal "Pago registrado", **When** el cajero selecciona "Cerrar",
   **Then** el modal se cierra sin enviar nada a impresión.

---

### Edge Cases

- **La terminal que cobra recibe el evento en tiempo real del mismo pago casi al mismo tiempo que
  la respuesta de su propio cobro** (condición de carrera): solo debe quedar el modal mostrado por
  la respuesta del cobro; el evento en tiempo real de ese mismo pago nunca debe generar un toast
  adicional en esa terminal, sin importar el orden de llegada.
- **El pago en efectivo es exacto** (sin vuelto, vuelto = $0): el modal sigue mostrando la línea de
  vuelto como "$ 0", por consistencia con el resto de los pagos en efectivo.
- **El mismo cajero tiene varias pestañas o dispositivos abiertos con su sesión**: solo se silencia
  la pestaña/dispositivo que ejecutó la acción de cobro; cualquier otra pestaña o dispositivo,
  aunque sea del mismo usuario, se comporta como "otra terminal" y sí recibe la notificación en
  tiempo real.
- **El cobro corresponde a un pago complementario sobre saldo pendiente** (spec 123): queda **fuera
  de alcance** de esta spec — hoy ese flujo ya muestra una única confirmación (un toast propio, sin
  modal) y no emite ninguna notificación en tiempo real a otras terminales, por lo que no presenta
  el problema de duplicación que esta spec corrige. No se le agrega ni se le quita nada aquí.
- **Pedidos o cobros ya registrados antes de esta funcionalidad**: no se re-notifican ni generan
  ninguna confirmación retroactiva.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Cuando un cobro se registra exitosamente, el sistema DEBE mostrar, en la terminal que
  originó el cobro, un único modal "Pago registrado", sin mostrar ningún otro aviso (toast u otra
  notificación) relacionado con ese mismo cobro en esa terminal.
- **FR-002**: El modal "Pago registrado" DEBE incluir el título "Pago registrado", el monto
  cobrado, el nombre del cliente y el método de pago. Esto amplía el contenido actual del modal
  (hoy solo muestra el monto y el cliente en un texto narrativo, sin el método de pago).
- **FR-003**: El modal "Pago registrado" DEBE incluir el vuelto únicamente cuando el método de
  pago sea efectivo; para cualquier otro método, el modal NO DEBE mostrar ninguna línea de vuelto.
  El vuelto es un dato nuevo en este modal: hoy no se calcula ni se muestra ahí.
- **FR-004**: El modal "Pago registrado" DEBE ofrecer las acciones "Imprimir factura" y "Cerrar",
  incluso cuando el cobro corresponda a un solo comprobante (ver "Decisión de negocio que cambia
  comportamiento existente" en la Historia 4, que reintroduce este botón para ese caso).
- **FR-005**: Todo monto mostrado en relación con un cobro (en el modal de la terminal de origen y
  en la notificación de las demás terminales) DEBE usar el formato de moneda estándar del sistema
  (símbolo "$", espacio, separador de miles con punto, sin decimales), nunca el formato crudo del
  valor numérico.
- **FR-006**: El sistema DEBE seguir emitiendo, para las demás terminales conectadas del mismo
  tenant, la notificación en tiempo real de un pago registrado (spec 077), con el formato de
  moneda correcto.
- **FR-007**: El sistema NO DEBE mostrar, en la terminal/sesión que originó el cobro, la
  notificación en tiempo real de ese mismo pago, para evitar duplicarla con el modal ya mostrado.
  Este silenciamiento DEBE limitarse a esa sesión/terminal específica, sin afectar la entrega de la
  notificación a cualquier otra sesión del mismo tenant, incluidas otras sesiones del mismo
  usuario.
- **FR-008**: Si el backend responde con error al intentar registrar el cobro, el sistema NO DEBE
  mostrar el modal "Pago registrado", DEBE mostrar un único mensaje de error indicando el motivo, y
  DEBE conservar los datos ya ingresados en el formulario de cobro.
- **FR-009**: Al seleccionar "Imprimir factura" en el modal, el sistema DEBE enviar la factura del
  cobro a impresión y cerrar el modal.
- **FR-010**: Al seleccionar "Cerrar" en el modal, el sistema DEBE cerrar el modal sin enviar nada
  a impresión.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Tras un cobro exitoso, el cajero ve exactamente una confirmación (el modal) y ningún
  aviso adicional sobre ese mismo cobro en su terminal, en el 100% de los cobros.
- **SC-002**: El monto mostrado en cualquier aviso de pago (modal en la terminal de origen o
  notificación en otra terminal) respeta el formato de moneda estándar del sistema en el 100% de
  los casos.
- **SC-003**: Las terminales del tenant que no originaron el cobro siguen recibiendo la
  notificación en tiempo real del pago, sin degradación respecto al comportamiento ya validado en
  la spec 077.
- **SC-004**: Ante un error al cobrar, el cajero conserva el 100% de los datos ya ingresados en el
  formulario y ve un único mensaje de error, sin necesidad de reescribir el cobro para reintentar.

## Assumptions

- La fuente de verdad del resultado del cobro para la terminal que lo origina es la respuesta HTTP
  de la operación de cobro; el evento en tiempo real (SSE) de ese mismo pago se sigue emitiendo
  para el tenant, pero se ignora específicamente en la sesión que hizo la petición de cobro.
  (spec 077 ya define el canal de notificación en tiempo real; esta spec solo ajusta en qué sesión
  se entrega).
- "Terminal" o "sesión" se refiere a la conexión autenticada (pestaña/dispositivo) que ejecutó la
  acción de cobro; otra pestaña o dispositivo del mismo cajero se trata igual que la terminal de
  cualquier otro usuario del tenant.
- El mensaje hoy existente "Pedido cobrado, facturado y enviado a cocina" queda cubierto por el
  nuevo modal único; no se requiere un aviso adicional fuera de él para confirmar el envío a
  cocina. El envío a cocina en sí no cambia de comportamiento, solo deja de generar un aviso propio
  duplicado.
- Esta spec no modifica el contenido, los montos ni la mecánica de los pagos mixtos o
  complementarios (specs 112, 123); solo aplica la deduplicación de confirmaciones y la
  corrección de formato de moneda descritas aquí.
- El formato de moneda de referencia es el ya establecido por la spec 035
  (estado-pagado-formato-moneda).
- Hoy el sistema no tiene ningún concepto de "identificador de terminal/sesión" que distinga una
  pestaña/dispositivo conectado de otro dentro del mismo tenant; esta spec requiere introducir uno
  (nuevo, mínimo) para poder silenciar la notificación en tiempo real únicamente en la sesión que
  originó el cobro — el diseño concreto de ese identificador se define en la fase de planificación
  técnica, no en esta spec.
