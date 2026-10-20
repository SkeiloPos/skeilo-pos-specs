# Feature Specification: Rediseño visual del Menú QR con pago mixto y bloqueo de salida con pago pendiente

**Feature Branch**: `130-rediseno-menu-qr`

**Created**: 2026-10-20

**Status**: Draft

**Naturaleza de esta spec**: combina **rediseño visual** (sin cambio de comportamiento) de todo el
Menú QR del comensal con dos **cambios de regla de negocio puntuales** dentro del mismo alcance.
Se construye sobre [spec 007](../007-menu-carrito-qr/spec.md) (menú, carrito y ciclo de vida de la
sesión del comensal), [spec 004](../004-validacion-grupos-opciones/spec.md) (motor de grupos de
opciones), [spec 025](../025-revision-pago-antes-envio/spec.md) y
[spec 034](../034-checkout-qr-vista-pasos/spec.md) (revisión y pago en vista de pasos),
[spec 032](../032-catalogo-metodos-pago/spec.md) (catálogo de métodos de pago por tenant) y
[spec 128](../128-categoria-visible-menu-qr/spec.md) (visibilidad de categorías). Ninguna otra
regla de negocio vigente de esas specs cambia salvo las dos indicadas abajo.

**Input**: User description: "necesito que rediseñes el menu del codigo qr usando el archivo
design/Bienvenida QR v1.dc.html mantendras lo que funciona actualmente a excepcion de 2 cosas,
incluiras el pago mixto como dentro del alcance y los otro es que modificaras la regla de negocio
que permite cerrar la sesion, si hay una orden pendiente de pago, no deberas permitir al usuario
cerrar sesion, lo otro es que en el diseño los toping usa un checkbox, esa parte no la modificaras
dejaras como funciona actualmente solo cambiaras el estilo visual en en lo que se ve en el detalle
del pedido, si ves que falta algo o que el diseño no cumple con algo que existe hoy en el menu qr
me preguntas, para saber que decicion tomar"

## Clarifications

### Session 2026-10-20

- Q1: ¿Qué estados de pedido cuentan como "pago pendiente" para bloquear la salida? → A: cualquier
  pago no confirmado — efectivo pendiente de cobrar en caja, **o** comprobante de transferencia
  (completo, o la porción por transferencia de un pago mixto) todavía en verificación. El diseño de
  referencia solo bloqueaba para efectivo/mixto y dejaba salir con un pedido 100% por transferencia
  en verificación; esa inconsistencia se corrige en esta spec.
- Q2: ¿El bloqueo de salida aplica solo al comensal con el pedido pendiente, o a todos los
  comensales activos de la mesa mientras exista cualquier pedido pendiente en ella? → A: solo al
  comensal con el pedido pendiente propio; otros comensales de la misma mesa sin pedidos pendientes
  pueden salir con normalidad (mantiene el modelo de sesión por comensal de spec 007).
- Q3: ¿"Pago mixto" en el Menú QR necesita una activación propia en el catálogo de métodos de pago
  del tenant, o aparece automáticamente cuando el tenant ya tiene habilitados efectivo y al menos
  un método de transferencia? → A: activación explícita — el tenant debe habilitar "Pago mixto"
  como una opción propia en su catálogo de métodos de pago (spec 032), igual que hoy habilita cada
  método por separado.
- Q4: Cuando el tenant tiene más de un método de transferencia habilitado (ej. Nequi y
  Bancolombia), ¿quién decide cuál de ellos recibe el resto del pago mixto? → A: lo elige el
  comensal — después de indicar el monto en efectivo, elige entre los métodos de transferencia
  activos del tenant cuál recibe el resto, igual que ya elige hoy un método de transferencia para
  un pago 100% por transferencia.
- Q5: ¿Habilitar "Pago mixto" en el catálogo del tenant (FR-004) exige que el tenant ya tenga
  habilitados efectivo y al menos un método de transferencia, o puede habilitarse de forma
  independiente? → A: exige ambos — el sistema solo permite habilitar "Pago mixto" si el tenant ya
  tiene efectivo y al menos un método de transferencia activos, porque el pago mixto los compone.
- Q6: Si el comensal ya cargó el comprobante de transferencia del resto de un pago mixto y luego
  cambia el monto en efectivo (cambiando el resto a transferir), ¿qué pasa con ese comprobante ya
  cargado? → A: se invalida y exige volver a cargarlo — al cambiar el monto en efectivo el
  comprobante ya cargado deja de corresponder al nuevo resto y el sistema exige un nuevo comprobante
  para el monto actualizado.
- Q7: ¿El estilo visual de los toppings/adiciones debe cambiar a la apariencia de casilla de
  verificación (checkbox) del diseño de referencia, o debe mantenerse exactamente como se ve hoy?
  → A: se mantiene exactamente como se ve hoy — el rediseño no toca en absoluto la apariencia de
  los toppings/adiciones (ni el control de selección en el detalle de producto, ni su listado en
  carrito/revisión/"Mis pedidos"); corrige la lectura inicial de que el estilo de checkbox del
  diseño de referencia debía adoptarse ahí.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - El comensal recorre el Menú QR rediseñado sin perder nada de lo que ya funciona (Priority: P1)

Un comensal escanea el código QR de su mesa, escribe su nombre, navega el menú por categorías
(incluida la pestaña de búsqueda), agrega productos con presentación y toppings, revisa su carrito,
consulta la pestaña "Mis pedidos" y envía su pedido — todo con la apariencia visual del diseño de
referencia (`design/Bienvenida QR v1.dc.html`: bienvenida, menú con categorías y promociones,
detalle de producto, carrito, revisión en pasos, confirmación, despedida), pero con exactamente el
mismo comportamiento subyacente que tiene hoy el Menú QR (specs 007, 004, 025, 032, 034, 128).

**Why this priority**: es la base de todo el trabajo — un rediseño que cambiara comportamiento sin
que nadie lo pidiera sería un defecto, no una mejora. Todo lo demás en esta spec son las únicas
excepciones explícitas a esta regla.

**Independent Test**: recorrer el flujo completo (bienvenida → menú → agregar producto con
presentación y toppings → carrito → pestaña "Mis pedidos" → enviar pedido) sobre la nueva interfaz
y verificar que cada resultado (precios, promociones aplicadas, validaciones de grupos de opciones,
persistencia de progreso ante recarga, mensajes de error) coincide con el comportamiento vigente
documentado en las specs base.

**Acceptance Scenarios**:

1. **Given** un comensal que abre el enlace de su mesa por primera vez, **When** completa la
   pantalla de bienvenida con su nombre, **Then** ve el menú con el nuevo estilo visual, con las
   mismas categorías, promociones y productos que vería hoy.
2. **Given** un comensal agregando un producto con presentaciones y un grupo de opciones (hoy
   mostrado como "toppings"), **When** abre el detalle del producto, **Then** las reglas de
   selección (obligatorio/opcional, mínimos/máximos por grupo, inventario) se siguen validando
   exactamente igual que hoy (spec 004) — solo cambia la apariencia de las opciones.
3. **Given** un comensal en cualquier paso de la revisión y pago previo a que el pedido exista,
   **When** recarga la página, **Then** recupera su progreso exactamente como lo hace hoy
   (spec 034), con la apariencia del nuevo diseño.
4. **Given** un comensal en la pestaña "Mis pedidos", **When** la consulta, **Then** ve sus pedidos
   anteriores de la sesión con el mismo contenido e información que ve hoy, con el nuevo estilo.

---

### User Story 2 - El comensal puede pagar su pedido combinando efectivo y transferencia (Priority: P1)

Un comensal cuyo pedido no quiere pagar completamente en efectivo ni completamente por
transferencia elige "Pago mixto" al revisar su pedido: indica cuánto paga en efectivo, el sistema
calcula el resto a transferir, le muestra los datos de la transferencia (número de cuenta y/o
código QR del método elegido) para ese resto, y le exige subir el comprobante de esa transferencia
antes de enviar el pedido — igual que ya ocurre hoy para un pago 100% por transferencia, pero con
un monto en efectivo descontado del total a transferir.

**Why this priority**: es el primer cambio de alcance explícito que pidió el negocio — hoy el
comensal del Menú QR solo puede elegir efectivo **o** transferencia, nunca ambos (spec 025,
FR-004/FR-005); el pago mixto solo existía para el cobro que hace el cajero en la Terminal de Mesas
(spec 112), nunca para el comensal.

**Why this priority**: sin esto no se cumple el alcance pedido explícitamente por el negocio para
este rediseño.

**Independent Test**: en la pantalla "¿Cómo vas a pagar?", elegir "Pago mixto", ingresar un monto
en efectivo menor al total, verificar que el resto a transferir se calcula correctamente, que se
exige comprobante solo por ese resto, y que el pedido queda registrado con el desglose de ambos
montos.

**Acceptance Scenarios**:

1. **Given** un comensal en el paso "¿Cómo vas a pagar?", **When** elige "Pago mixto", **Then** ve
   un campo para indicar cuánto paga en efectivo y el sistema muestra en vivo cuánto queda por
   transferir.
2. **Given** un comensal que ingresó un monto en efectivo igual o mayor al total, **When** intenta
   continuar, **Then** el sistema lo bloquea con un mensaje indicando que para pagar todo en
   efectivo debe elegir esa opción en su lugar — el pago mixto exige un resto por transferir mayor
   a cero.
3. **Given** un comensal que ya definió el monto en efectivo de su pago mixto y el tenant tiene más
   de un método de transferencia activo, **When** avanza, **Then** el sistema le pide elegir cuál
   de esos métodos de transferencia recibe el resto, igual que ya elige hoy un método de
   transferencia para un pago 100% por transferencia.
4. **Given** un comensal que ya definió el monto en efectivo y el método de transferencia (cuando
   aplica) de su pago mixto, **When** avanza, **Then** ve los datos de la transferencia (cuenta y/o
   código QR) por el monto restante, claramente etiquetado como "más {monto} en efectivo al recibir
   el pedido", y debe subir su comprobante por ese resto antes de poder enviar el pedido.
5. **Given** un comensal que ya cargó el comprobante de la transferencia de su pago mixto, **When**
   vuelve a cambiar el monto en efectivo (cambiando el resto a transferir), **Then** el sistema
   invalida el comprobante ya cargado y le exige cargar uno nuevo correspondiente al resto
   actualizado antes de poder enviar el pedido.
6. **Given** un pedido enviado con pago mixto, **When** el comensal lo consulta en "Mis pedidos" o
   ve la confirmación, **Then** ve el desglose de cuánto pagó en efectivo (pendiente al recibir) y
   cuánto por transferencia (en verificación), igual que hoy distingue entre "pago pendiente en
   efectivo" y "comprobante en verificación" para los otros métodos.

---

### User Story 3 - El comensal no puede cerrar su sesión mientras tenga un pedido con pago pendiente (Priority: P1)

Un comensal que ya envió al menos un pedido cuyo pago todavía no está confirmado (pendiente de
cobrar en efectivo en caja, o con comprobante de transferencia en verificación) intenta pulsar
"Salir" del Menú QR. El sistema no le permite cerrar su sesión: le muestra un aviso explicando que
tiene un pago pendiente y que debe dirigirse a la caja, y su sesión permanece activa.

**Why this priority**: es el segundo cambio de alcance explícito del negocio — hoy "salir" nunca
falla, sin importar pagos pendientes (spec 007, Historia de Usuario 9, `RN-CART-15`/`RN-CART-16`,
`FR-035`); esta spec invierte esa garantía para el caso de pago pendiente.

**Independent Test**: enviar un pedido con pago en efectivo (o con transferencia sin comprobante
aún verificado) y, sin que el pago se confirme, intentar pulsar "Salir"; verificar que el sistema lo
bloquea con el aviso correspondiente y que la sesión del comensal sigue activa después del intento.

**Acceptance Scenarios**:

1. **Given** un comensal con un pedido enviado en efectivo aún no cobrado en caja, **When** pulsa
   "Salir", **Then** el sistema muestra el aviso de pago pendiente y no cierra su sesión.
2. **Given** un comensal con un pedido enviado por transferencia cuyo comprobante ya fue verificado
   y confirmado como pagado, **When** pulsa "Salir", **Then** el sistema lo permite con normalidad
   (ya no tiene nada pendiente).
3. **Given** un comensal sin ningún pedido enviado (solo navegando el menú o con productos en el
   carrito sin enviar), **When** pulsa "Salir", **Then** el sistema lo permite con normalidad — el
   bloqueo solo aplica a pedidos ya enviados con pago pendiente, nunca al carrito sin enviar.
4. **Given** un comensal bloqueado para salir por pago pendiente, **When** el pago se confirma
   (cobrado en caja o comprobante aprobado) mientras su sesión sigue abierta, **Then** un nuevo
   intento de "Salir" ya lo permite.

---

### User Story 4 - Los toppings quedan fuera del rediseño visual, ni apariencia ni funcionamiento cambian (Priority: P3)

En el detalle del producto y en todo lugar donde se muestran los toppings/adiciones seleccionados de
un pedido (detalle de producto, carrito, revisión, "Mis pedidos"), la apariencia se mantiene
exactamente como se ve hoy — el rediseño **no** adopta el estilo de casilla de verificación
(checkbox) del diseño de referencia para esta parte — y tampoco se altera ninguna regla de
selección vigente (grupos de opciones, mínimos/máximos, validación de inventario de spec 004).

**Why this priority**: el negocio fue explícito en que esta parte del diseño queda excluida del
rediseño, tanto en comportamiento como en apariencia (Clarificación Q7) — es la única pantalla/
control del Menú QR que el rediseño visual no toca.

**Independent Test**: comparar, antes y después del rediseño, que las mismas combinaciones de
selección de opciones producen las mismas validaciones, precios y resultados, y que el control de
toppings y su listado se ven exactamente igual que antes (ningún cambio de estilo).

**Acceptance Scenarios**:

1. **Given** un grupo de opciones obligatorio con mínimo y máximo definidos, **When** el comensal
   intenta continuar sin cumplir esa regla, **Then** el sistema sigue bloqueando el avance con el
   mismo mensaje y motivo que hoy, mostrado sobre el mismo estilo visual vigente (sin adoptar el
   estilo de checkbox del diseño de referencia).
2. **Given** un pedido con toppings ya seleccionados, **When** se muestra en el carrito, la revisión
   o "Mis pedidos", **Then** la lista de toppings elegidos se ve exactamente igual que hoy, sin
   ningún cambio de estilo, y contiene exactamente la misma información que hoy.

---

### Edge Cases

- ¿Qué pasa si un comensal tiene varios pedidos enviados y solo uno de ellos tiene pago pendiente?
  El bloqueo de salida debe activarse igual — basta que exista **un** pedido pendiente de pago
  propio del comensal para bloquear su salida (ver User Story 3).
- ¿Qué pasa si otro comensal de la misma mesa (ej. Luis) tiene un pedido con pago pendiente pero el
  comensal que intenta salir (ej. Ana) no tiene ninguno propio? El bloqueo evalúa solo los pedidos
  propios de quien intenta salir (Clarificación Q2) — Ana puede salir con normalidad aunque el
  pedido de Luis siga pendiente; la mesa, de todos modos, seguirá `ocupada` hasta que se cumplan las
  dos condiciones de `RN-CART-15` (ver FR-012).
- ¿Qué pasa si el comensal cierra la pestaña del navegador en vez de pulsar "Salir" dentro de la
  app? Esta spec solo puede bloquear la acción explícita "Salir" dentro de la interfaz; cerrar o
  perder la pestaña sin usar ese botón sigue comportándose según las reglas ya vigentes de expiración
  de sesión (spec 007, Historia 10) — no es posible impedir técnicamente el cierre del navegador.
- ¿Qué pasa si el comensal elige "Pago mixto" e ingresa $0 en efectivo? Debe tratarse igual que
  elegir "Transferencia" directamente — el sistema debe guiarlo a elegir esa opción en vez de
  mixto cuando el monto en efectivo es cero (ver User Story 2, escenario 2 en sentido inverso).
- ¿Qué pasa si el comprobante de la porción por transferencia del pago mixto es rechazado por el
  staff? Debe seguir el mismo tratamiento que ya existe hoy para un comprobante de transferencia
  rechazado (fuera de alcance de esta spec, gobernado por las reglas vigentes de verificación de
  pagos).
- ¿Qué pasa si el comensal ya cargó el comprobante del resto por transferencia y luego regresa a
  cambiar el monto en efectivo? El comprobante ya cargado queda invalidado porque ya no corresponde
  al nuevo resto; el sistema exige cargar un nuevo comprobante por el monto actualizado antes de
  poder enviar el pedido (Clarificación Q6).
- ¿Qué pasa si el tenant tiene "Pago mixto" habilitado y luego desactiva efectivo o su único método
  de transferencia? Esta spec no define ese caso — FR-004 solo exige que ambos estén habilitados en
  el momento de habilitar "Pago mixto"; el comportamiento posterior al desactivar uno de los dos
  queda fuera de alcance.

## Requirements *(mandatory)*

### Functional Requirements

**Rediseño visual (sin cambio de comportamiento)**

- **FR-001**: El sistema DEBE presentar la pantalla de bienvenida, el menú (categorías, búsqueda,
  banner de promociones, tarjetas de producto), el detalle de producto (salvo el control de
  toppings/adiciones, ver FR-002), el carrito, la pestaña "Mis pedidos", la revisión y pago en
  pasos, la confirmación y la pantalla de despedida con la apariencia visual del diseño de
  referencia (`design/Bienvenida QR v1.dc.html`), sin alterar la información mostrada ni el
  comportamiento subyacente de ninguna de esas pantallas respecto a lo vigente hoy (specs 007, 004,
  025, 032, 034, 128), salvo los cambios descritos en FR-004 a FR-012.
- **FR-002**: El sistema DEBE seguir usando el motor de grupos de opciones vigente (spec 004) para
  la selección de presentación y adiciones de producto. El rediseño puede cambiar la apariencia del
  control de **presentación**, pero el control de **toppings/adiciones** (en el detalle de producto
  y en todo lugar donde se muestre su selección — carrito, revisión, "Mis pedidos") queda
  explícitamente **fuera del rediseño visual**: mantiene exactamente la apariencia vigente hoy, sin
  adoptar el estilo de checkbox del diseño de referencia (Clarificación Q7, Historia 4). En ningún
  caso el rediseño altera las reglas de mínimo/máximo, obligatoriedad o validación de inventario de
  ningún control de selección.
- **FR-003**: El sistema DEBE seguir recuperando el progreso de la revisión y pago ante una recarga
  de página exactamente con las mismas garantías ya vigentes (spec 034), con la apariencia del
  nuevo diseño.

**Pago mixto para el comensal (nuevo alcance)**

- **FR-004**: El sistema DEBE permitir al comensal elegir "Pago mixto" como método de pago de su
  pedido, además de efectivo y transferencia, únicamente cuando el tenant lo haya habilitado de
  forma explícita como un método propio en su catálogo de métodos de pago (spec 032) — no se
  activa de forma automática por tener efectivo y una transferencia habilitados por separado. El
  sistema DEBE impedir habilitar "Pago mixto" en el catálogo del tenant si este no tiene ya
  habilitados efectivo y al menos un método de transferencia (el pago mixto compone ambos).
- **FR-005**: Al elegir pago mixto, el sistema DEBE permitir al comensal indicar el monto que paga
  en efectivo y DEBE calcular automáticamente el monto restante a pagar por transferencia. Si el
  tenant tiene más de un método de transferencia activo, el sistema DEBE permitir al comensal
  elegir cuál de ellos recibe ese resto, con el mismo paso de selección que ya usa hoy un pago 100%
  por transferencia.
- **FR-006**: El sistema DEBE exigir que el monto en efectivo del pago mixto sea mayor a cero y
  estrictamente menor al total del pedido; si el comensal indica un monto igual o mayor al total,
  el sistema DEBE impedir continuar y orientarlo a elegir "Efectivo" en su lugar.
- **FR-007**: El sistema DEBE mostrar los datos de la transferencia (número de cuenta y/o código QR
  configurado por el tenant) por el monto restante a transferir del pago mixto, y DEBE exigir que el
  comensal cargue el comprobante de esa transferencia antes de poder enviar el pedido — con las
  mismas reglas de carga y validación de comprobante ya vigentes para un pago 100% por
  transferencia (spec 025, spec 034). Si el comensal modifica el monto en efectivo después de haber
  cargado ese comprobante, el sistema DEBE invalidar el comprobante ya cargado y exigir uno nuevo
  correspondiente al resto actualizado antes de permitir el envío del pedido.
- **FR-008**: El sistema DEBE registrar el pedido con pago mixto conservando el desglose de cuánto
  se pagó en efectivo (pendiente de cobrar al recibir el pedido) y cuánto por transferencia (sujeto
  a verificación, incluyendo a cuál método de transferencia corresponde), y DEBE mostrar ese
  desglose en la confirmación del pedido y en "Mis pedidos".

**Bloqueo de salida con pago pendiente (nuevo alcance)**

- **FR-009**: El sistema DEBE impedir que un comensal cierre su sesión ("Salir") mientras tenga al
  menos un pedido propio ya enviado cuyo pago no esté confirmado — ya sea pendiente de cobrar en
  efectivo en caja, o con comprobante de transferencia (completo, o la porción por transferencia de
  un pago mixto) todavía en verificación. Este bloqueo evalúa únicamente los pedidos del comensal
  que intenta salir, no los de otros comensales de la misma mesa (ver FR-011).
- **FR-010**: Al intentar cerrar sesión con un pedido en esas condiciones, el sistema DEBE mostrar
  al comensal un aviso explicando que tiene un pago pendiente y que debe dirigirse a la caja, y DEBE
  mantener su sesión activa (no debe marcarla como cerrada ni invalidar su acceso).
- **FR-011**: El sistema DEBE permitir cerrar sesión con normalidad a un comensal que no tiene
  ningún pedido propio enviado con pago pendiente — ya sea porque nunca envió un pedido, porque
  todos sus pedidos fueron cancelados, porque todos sus pagos ya fueron confirmados, o porque el
  pedido pendiente pertenece a otro comensal de la misma mesa.
- **FR-012**: Este bloqueo no DEBE alterar la regla vigente sobre cuándo se libera la mesa completa
  (`RN-CART-15`, spec 007): la mesa sigue liberándose solo cuando nadie permanece activo y no queda
  nada por cobrar.

### Key Entities *(include if feature involves data)*

- **Pedido (Order)**: conserva su estado de pago vigente; para pago mixto agrega el desglose de
  monto pagado en efectivo y monto pagado por transferencia, cada uno con su propio estado de
  confirmación.
- **SessionParticipant**: su acción de "salir" (`POST /cart/leave`) pasa de ser siempre exitosa a
  poder rechazarse cuando el participante tiene un pedido propio con pago pendiente, según se
  resuelva en la Clarificación Q2.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% de las pantallas del Menú QR (bienvenida, menú, detalle de producto, carrito,
  "Mis pedidos", revisión y pago, confirmación, despedida) usan la apariencia del nuevo diseño —
  excepto el control de toppings/adiciones, que mantiene su apariencia vigente (FR-002,
  Clarificación Q7) — sin que ningún comportamiento documentado en las specs base (007, 004, 025,
  032, 034, 128) cambie, salvo los descritos en esta spec.
- **SC-002**: Un comensal puede completar un pago mixto (efectivo + transferencia) de inicio a fin
  —elegir el método, definir el monto en efectivo, ver el resto a transferir, cargar el
  comprobante y enviar el pedido— sin errores ni pasos adicionales a los descritos en esta spec.
- **SC-003**: 0% de los intentos de "Salir" con un pedido propio de pago pendiente logran cerrar la
  sesión del comensal; 100% de los intentos de "Salir" sin pedidos pendientes la cierran con
  normalidad.
- **SC-004**: 0% de las interacciones con la selección de toppings/adiciones producen un resultado
  de validación, precio o inventario distinto al que producían antes del rediseño visual.

## Assumptions

- El bloqueo de "Salir" solo puede aplicarse a la acción explícita dentro de la interfaz del Menú
  QR; no es técnicamente posible impedir que un comensal cierre la pestaña o el navegador sin usar
  ese botón, por lo que el comportamiento de expiración de sesión vigente (spec 007, Historia 10)
  sigue gobernando ese caso.
- Los íconos del diseño de referencia (set de Lucide) se consideran equivalentes al set de íconos ya
  usado en la aplicación (ver precedente en spec 034); se mapean al set interno existente sin
  introducir una librería de íconos nueva.
- El pago mixto del comensal solo combina efectivo con **un** método de transferencia a la vez
  (igual que en el diseño de referencia), no múltiples métodos de transferencia simultáneos.
- Las reglas de verificación/rechazo de comprobantes de transferencia ya vigentes se aplican sin
  cambios a la porción por transferencia de un pago mixto; esta spec no modifica ese flujo.
