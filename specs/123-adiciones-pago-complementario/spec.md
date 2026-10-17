# Feature Specification: Adiciones a Línea de Pedido Existente con Pago Complementario

**Feature Branch**: `123-adiciones-pago-complementario`

**Created**: 2026-10-17

**Status**: Draft

**Input**: User description: "Como cajero, quiero agregar adiciones a un producto de un pedido ya
creado, para atender lo que el cliente pide después sin anular y volver a crear el producto. Hoy
cada línea del pedido solo permite 'Marcar listo' o 'Anular'. Se pueden agregar adiciones solo si
la línea está en estado Pendiente o En preparación. Si el pedido no está pagado, el total se
recalcula y se cobra normalmente. Si el pedido ya está pagado, la adición genera un saldo
pendiente que se cobra como un pago complementario, con su propia factura vinculada al pedido
original sin modificar la factura original. El descuento de inventario y el movimiento de caja de
la adición ocurren cuando se cobra el complemento. La cocina recibe en tiempo real que la línea
cambió."

## Clarifications

### Session 2026-10-17

- Q: Si al cobrar el pago complementario una de varias adiciones incluidas en el saldo pendiente
  ya no tiene stock suficiente de su insumo, ¿el sistema debe rechazar todo el cobro complementario,
  o cobrar solo las adiciones con stock disponible y dejar el resto pendiente? → A: Rechazar todo el
  cobro complementario (atómico), siempre y cuando el tenant tenga habilitado el módulo de
  inventario en su plan de suscripción (spec 033); si el tenant no tiene ese módulo habilitado, no
  se valida stock para ninguna adición.
- Q: Después de que un pedido liquida por completo su saldo pendiente (queda "Pagado" sin nada por
  cobrar), ¿puede agregarse más adelante una nueva adición a ese mismo pedido, generando un segundo
  ciclo de saldo pendiente y una segunda factura complementaria? → A: Sí, el ciclo puede repetirse
  tantas veces como sea necesario sobre el mismo pedido.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Agregar adición a una línea de un pedido aún no pagado (Priority: P1)

Un cajero necesita atender un pedido adicional del cliente (ej. "ahora sí quiero leche
condensada") sobre un producto que ya está en el pedido, sin anular la línea existente ni crear un
producto nuevo. Si el pedido todavía no se ha cobrado, el sistema simplemente recalcula el total de
la línea y del pedido con la adición incluida, y se cobra normalmente en el momento del cobro.

**Why this priority**: es la capacidad base que hoy no existe en ninguna parte del sistema — hoy
una línea de pedido solo admite "Marcar listo" o "Anular", nunca modificarse para incorporar una
adición nueva. Sin esta capacidad no hay nada sobre lo cual construir el caso de pedido ya pagado.

**Independent Test**: se puede probar agregando una adición a una línea "Pendiente" de un pedido
sin cobrar todavía, y verificando que el total de la línea y del pedido se recalculan de inmediato
y que el cobro posterior exige exactamente ese nuevo total.

**Acceptance Scenarios**:

1. **Given** un pedido sin pagar con una línea "Pendiente", **When** el cajero selecciona "Agregar
   adición" en esa línea, elige una adición y confirma, **Then** la línea muestra la adición
   agregada y el total del pedido se recalcula incluyéndola.
2. **Given** ese mismo pedido con el total ya recalculado, **When** el cajero cobra el pedido,
   **Then** el monto exigido es el total recalculado (incluida la adición), sin ningún mecanismo de
   saldo pendiente ni pago complementario de por medio.

---

### User Story 2 - Agregar adición a una línea de un pedido ya pagado genera saldo pendiente (Priority: P1)

Un cajero necesita atender un pedido adicional del cliente sobre un producto que ya está en un
pedido **que ya fue cobrado y facturado**. El sistema permite agregar la adición sin tocar la
factura ya emitida, y en su lugar registra la diferencia como un saldo pendiente del pedido,
visible en el panel de cuenta junto con la acción para cobrarlo.

**Why this priority**: es el escenario central reportado por el negocio y el que requiere la
mecánica nueva (saldo pendiente + pago complementario) — sin él, la Historia 1 por sí sola no
resuelve el caso real que más le ocurre al cajero: el cliente pide algo más después de pagar.

**Independent Test**: se puede probar agregando una adición a una línea "Pendiente" de un pedido ya
pagado, y verificando que la factura original no cambia de monto, que aparece un saldo pendiente
igual al valor de la adición, y que aparece la acción para cobrarlo.

**Acceptance Scenarios**:

1. **Given** la Mesa 1 tiene un pedido pagado por $22.000 y la línea "Fresa boom" está en estado
   "Pendiente", **When** el cajero selecciona "Agregar adición" en esa línea, elige "Leche
   condensada" ($2.000) con cantidad 1, y confirma, **Then** la línea muestra la adición y su
   subtotal pasa a $10.000, el panel de cuenta muestra "Saldo pendiente: $2.000", aparece la acción
   "Cobrar saldo" por $2.000, y la factura original de $22.000 no se modifica.
2. **Given** ese mismo pedido con saldo pendiente, **When** se consulta la factura ya emitida,
   **Then** su monto, sus líneas y su representación siguen siendo exactamente las que se emitieron
   al momento del cobro original (Principio VII de la Constitución).

---

### User Story 3 - Cobrar el saldo pendiente como pago complementario (Priority: P1)

Un cajero necesita liquidar el saldo pendiente generado por una o más adiciones agregadas después
del cobro original. El sistema lo cobra como un pago independiente, vinculado al pedido original,
que genera su propia factura y dispara en ese momento el descuento de inventario y el movimiento de
caja correspondientes.

**Why this priority**: sin esta capacidad, la Historia 2 deja al pedido con un saldo que nunca se
puede saldar formalmente — el ciclo de venta (cobro → factura → inventario → caja) quedaría
incompleto para la adición agregada después del pago.

**Independent Test**: se puede probar cobrando en efectivo el saldo pendiente de un pedido y
verificando que se genera una factura independiente, que el insumo de la adición se descuenta del
inventario, y que el pedido vuelve a reflejarse como completamente pagado.

**Acceptance Scenarios**:

1. **Given** el pedido tiene un saldo pendiente de $2.000, **When** el cajero cobra el saldo en
   efectivo, **Then** se registra un pago complementario de $2.000 vinculado al pedido, se genera
   una factura independiente por $2.000, se descuenta del inventario el insumo de la adición, y el
   pedido vuelve a estado "Pagado" sin saldo pendiente restante.
2. **Given** un pedido con varias adiciones agregadas después del pago sobre distintas líneas,
   **When** el cajero cobra el saldo pendiente, **Then** todas esas adiciones quedan cubiertas por
   un único pago complementario y una única factura independiente, sin requerir un cobro por cada
   adición.
3. **Given** un pedido con saldo pendiente cuyo tenant tiene habilitado el módulo de inventario, y
   el insumo de una de las adiciones incluidas en ese saldo ya no tiene stock suficiente, **When**
   el cajero intenta cobrar el saldo pendiente, **Then** el sistema rechaza el cobro completo del
   pago complementario con el mensaje "Stock insuficiente de [insumo]", sin cobrar ninguna parte del
   saldo ni generar ninguna factura complementaria.
4. **Given** un pedido que ya liquidó un pago complementario anterior y quedó completamente pagado,
   **When** el cajero agrega una nueva adición a una línea de ese mismo pedido que sigue "Pendiente"
   o "En preparación", **Then** se inicia un segundo ciclo independiente de saldo pendiente que, al
   cobrarse, genera una nueva factura complementaria independiente de la anterior.

---

### User Story 4 - Restricciones de estado de línea y validación de stock al agregar una adición (Priority: P2)

Un cajero solo puede agregar una adición mientras la línea sigue en un estado donde cocina todavía
puede incorporarla a la preparación ("Pendiente" o "En preparación"), y solo si hay stock
suficiente del insumo de la adición. En cualquier otro caso, el sistema bloquea la operación con un
mensaje claro, sin alterar la línea ni el total del pedido.

**Why this priority**: protege la integridad operativa (cocina no puede modificar algo que ya
entregó o que ya no existe) y la integridad de inventario — es una validación necesaria pero
secundaria a que la capacidad básica (Historias 1-3) ya exista.

**Independent Test**: se puede probar intentando agregar una adición a una línea en estado "Listo"
y verificando que la acción no está disponible; y, por separado, intentando agregar una adición
cuyo insumo no tiene stock suficiente y verificando el rechazo sin cambios en la línea ni en el
total.

**Acceptance Scenarios**:

1. **Given** la línea "Ensalada de frutas grande" está en estado "Listo", **When** el cajero revisa
   las acciones de esa línea, **Then** la acción "Agregar adición" no está disponible y un texto de
   ayuda indica "Producto ya preparado: agrega un producto nuevo".
2. **Given** el insumo de la adición "Chispas" no tiene stock suficiente, **When** el cajero intenta
   agregarla, **Then** el sistema rechaza la operación con el mensaje "Stock insuficiente de
   Chispas", y la línea y el total del pedido no cambian.

---

### User Story 5 - Bloqueo de "Liberar Mesa" mientras exista saldo pendiente (Priority: P2)

Un cajero no puede liberar una mesa mientras su pedido tenga saldo pendiente por cobrar, para
evitar que el pago complementario de una adición quede sin cobrarse al cerrar la mesa.

**Why this priority**: sin este bloqueo, el saldo generado por la Historia 2 podría perderse
operativamente al cerrarse la mesa — es una protección necesaria pero depende de que el saldo
pendiente (Historia 2) ya exista como concepto.

**Independent Test**: se puede probar generando un saldo pendiente en un pedido de mesa e
intentando liberar esa mesa, verificando que el sistema lo bloquea con el mensaje correspondiente.

**Acceptance Scenarios**:

1. **Given** el pedido tiene un saldo pendiente, **When** el cajero intenta "Liberar Mesa",
   **Then** el sistema lo bloquea con el mensaje "Hay un saldo pendiente por cobrar".
2. **Given** ese mismo pedido, **When** el cajero cobra el saldo pendiente en su totalidad (Historia
   3) y vuelve a intentar "Liberar Mesa", **Then** la mesa se libera normalmente, sin el bloqueo
   anterior.

---

### User Story 6 - Cocina ve en tiempo real que la línea cambió (Priority: P3)

Cuando se agrega una adición a una línea, el personal de cocina lo ve reflejado de inmediato, sin
necesidad de recargar la pantalla, con la línea marcada como modificada junto con el detalle de la
adición agregada.

**Why this priority**: mejora la calidad operativa de preparación, pero no bloquea el cobro ni el
registro de la venta — las Historias 1-3 ya entregan el valor de negocio central aunque esta
notificación llegue después.

**Independent Test**: se puede probar agregando una adición a una línea desde la terminal y
verificando, en otra sesión del POS conectada, que la línea aparece marcada como modificada con la
adición, sin recargar manualmente.

**Acceptance Scenarios**:

1. **Given** la línea "Fresa boom" está en estado "Pendiente", **When** el cajero agrega "Leche
   condensada" y confirma, **Then** la cocina ve la línea marcada como "Modificada" con la adición,
   en tiempo real.

---

### Edge Cases

- **Varias adiciones agregadas a distintas líneas de un mismo pedido ya pagado antes de cobrar el
  saldo**: todas se acumulan en un único saldo pendiente del pedido, cobrado con un único pago
  complementario (Historia 3, Escenario 2) — el cajero no está obligado a cobrar cada adición por
  separado apenas la agrega.
- **El cajero anula una línea que tiene una adición ya agregada pero cuyo saldo todavía no se ha
  cobrado** (la línea sigue en estado "Pendiente" o "En preparación", por lo que la anulación sigue
  permitida por las reglas vigentes): el saldo pendiente del pedido se recalcula retirando la
  porción correspondiente a esa adición; como esa adición nunca llegó a descontar inventario (el
  descuento solo ocurre al cobrar el complemento, FR-012), no hay reversa de inventario que hacer
  por ella.
- **El stock del insumo de una adición ya agregada deja de ser suficiente entre el momento en que se
  agregó y el momento en que se cobra el pago complementario** (en tenants con el módulo de
  inventario habilitado, spec 033): el sistema revalida la disponibilidad al momento del cobro y,
  si el insumo de cualquiera de las adiciones incluidas en el saldo pendiente ya no alcanza,
  rechaza el cobro completo del pago complementario (FR-020) — nunca cobra una parte del saldo ni
  genera una factura complementaria parcial. La factura original nunca se ve afectada por este
  rechazo.
- **El tenant no tiene habilitado el módulo de inventario (spec 033)**: el sistema no valida ni
  descuenta stock para ninguna adición de esta funcionalidad (FR-021); el flujo de agregar
  adición, generar saldo pendiente y cobrar el pago complementario funciona igual, solo que sin el
  paso de validación/descuento de insumo.
- **Un pedido ya liquidó un pago complementario anterior y quedó completamente pagado**: nada
  impide agregar una nueva adición más adelante sobre una línea que siga "Pendiente" o "En
  preparación", iniciando un segundo ciclo independiente de saldo pendiente y factura
  complementaria (FR-022).
- **Todas las líneas con saldo pendiente de un pedido terminan anuladas antes de cobrar el
  complemento**: el saldo pendiente se recalcula a cero y el bloqueo de "Liberar Mesa" (Historia 5)
  se levanta automáticamente.
- **Un pedido de canal mostrador o domicilio (no de mesa) acumula saldo pendiente**: el bloqueo
  equivalente al de "Liberar Mesa" aplica a la acción de cierre/entrega de ese pedido en su propio
  canal, con el mismo mensaje "Hay un saldo pendiente por cobrar".
- **Pedidos o ventas confirmados antes de esta funcionalidad**: su precio, sus facturas y su
  consumo de inventario ya registrados no se recalculan retroactivamente (Principio VII de la
  Constitución).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema DEBE permitir al cajero agregar una adición a una línea de pedido ya
  creada, sin exigir anular la línea ni crear un producto nuevo.
- **FR-002**: El sistema DEBE permitir agregar una adición únicamente cuando el estado de
  preparación de la línea sea "Pendiente" o "En preparación"; para cualquier otro estado (incluido
  "Listo" y "Anulado") la acción "Agregar adición" NO DEBE estar disponible.
- **FR-003**: Cuando la acción "Agregar adición" no esté disponible por el estado de la línea, el
  sistema DEBE mostrar un texto de ayuda equivalente a "Producto ya preparado: agrega un producto
  nuevo".
- **FR-004**: Para una adición de un grupo en modo "Por cantidad" (spec 065/117), la cantidad
  agregada a una línea existente DEBE interpretarse como el total para toda la línea, no como un
  multiplicador por unidad de producto. Para una adición de un grupo en modo "Conteo" (spec 004),
  el recargo sigue multiplicándose por la cantidad de producto de la línea, sin cambios (spec 117,
  FR-013) — esta spec no reabre esa regla.
- **FR-005**: Si el pedido no está pagado al momento de agregar la adición, el sistema DEBE
  recalcular de inmediato el total de la línea y del pedido, de forma que se cobre normalmente en
  el cobro pendiente del pedido, sin que se active ningún mecanismo de saldo pendiente. El
  descuento de inventario del insumo de esa adición, cuando el tenant tenga el módulo de
  inventario habilitado, DEBE ocurrir de inmediato al agregarse — igual que para cualquier línea
  nueva del pedido (spec 003) — y no se diferirá al momento del cobro.
- **FR-006**: Si el pedido ya tiene una factura emitida al momento de agregar la adición, el
  sistema DEBE: (a) incorporar la adición a la línea sin modificar la factura ya emitida, (b)
  incrementar el saldo pendiente del pedido por el valor de la adición, y (c) mostrar el saldo
  pendiente vigente junto con la acción "Cobrar saldo" en el panel de cuenta del pedido.
- **FR-007**: El sistema NO DEBE modificar, recalcular, reemitir ni alterar de ninguna forma la
  factura ya emitida de un pedido al agregarle una adición posterior (Principio VII de la
  Constitución).
- **FR-008**: El sistema DEBE validar la disponibilidad de stock del insumo de la adición en el
  momento en que el cajero intenta agregarla, antes de confirmar la operación.
- **FR-009**: Si el insumo de la adición no tiene stock suficiente, el sistema DEBE rechazar la
  operación con un mensaje "Stock insuficiente de [insumo]", y NO DEBE modificar la línea ni el
  total del pedido.
- **FR-010**: El sistema DEBE permitir al cajero cobrar el saldo pendiente de un pedido como un pago
  complementario, independiente del cobro original del pedido.
- **FR-011**: Al cobrarse el saldo pendiente, el sistema DEBE generar una factura independiente,
  vinculada al pedido original, distinta de la factura original y sin alterarla.
- **FR-012**: El descuento de inventario del insumo de cada adición agregada a un pedido ya pagado
  DEBE ocurrir en el momento en que se cobra el pago complementario correspondiente, nunca en el
  momento en que se agrega la adición.
- **FR-013**: El movimiento de caja del pago complementario DEBE registrarse en el momento en que
  se cobra dicho pago complementario, cumpliendo la regla vigente de que toda venta genera salida
  de inventario y movimiento de caja.
- **FR-014**: Una vez cobrado íntegramente el saldo pendiente de un pedido, el sistema DEBE volver a
  reflejarlo como completamente pagado, sin saldo pendiente restante.
- **FR-015**: El sistema DEBE acumular en un único saldo pendiente del pedido todas las adiciones
  agregadas a cualquiera de sus líneas después de que el pedido tiene factura emitida, hasta que
  dicho saldo se cobre íntegramente mediante un pago complementario.
- **FR-016**: El sistema DEBE bloquear la acción "Liberar Mesa" (y su equivalente de cierre/entrega
  en otros canales de pedido) mientras el pedido tenga saldo pendiente, mostrando el mensaje "Hay
  un saldo pendiente por cobrar".
- **FR-017**: El sistema DEBE notificar en tiempo real al personal conectado del tenant cuando una
  línea de pedido cambie por la adición de una nueva adición, identificando la línea como
  modificada junto con el detalle de la adición agregada.
- **FR-018**: El pago complementario DEBE cobrarse por el monto exacto del saldo pendiente vigente,
  con un único método de pago por cobro, sin combinar métodos ni dividirlo en varios cobros
  parciales (regla vigente, spec 046).
- **FR-019**: El sistema NO DEBE modificar el precio, las adiciones, las facturas ni el consumo de
  inventario ya registrados en pedidos o ventas confirmados antes de esta funcionalidad (Principio
  VII de la Constitución).
- **FR-020**: Al cobrar el pago complementario, si el tenant tiene habilitado el módulo de
  inventario (spec 033) y el insumo de alguna de las adiciones incluidas en el saldo pendiente ya
  no tiene stock suficiente, el sistema DEBE rechazar el cobro completo del pago complementario
  —sin cobrar ninguna parte ni generar ninguna factura complementaria— mostrando el mensaje "Stock
  insuficiente de [insumo]".
- **FR-021**: Cuando el tenant NO tenga habilitado el módulo de inventario (spec 033), el sistema
  NO DEBE aplicar ninguna validación ni descuento de stock al agregar una adición ni al cobrar el
  pago complementario; en ese caso, FR-008, FR-009, FR-012 y FR-020 no aplican para ese tenant.
- **FR-022**: El sistema DEBE permitir que el ciclo de saldo pendiente y pago complementario se
  repita tantas veces como sea necesario sobre el mismo pedido: cada vez que se agregue una adición
  a un pedido con factura emitida —incluso uno que ya tuvo un pago complementario anterior y quedó
  completamente pagado— se genera un nuevo saldo pendiente independiente que, al cobrarse, produce
  una nueva factura complementaria independiente.

### Key Entities *(include if feature involves data)*

- **Línea de pedido**: entidad existente; gana la capacidad de recibir adiciones después de su
  creación, mientras su estado de preparación sea "Pendiente" o "En preparación". Cada adición
  agregada queda registrada con su insumo, cantidad total de línea, precio, y si su valor ya quedó
  cubierto por la factura original o sigue pendiente de cobro.
- **Saldo pendiente del pedido**: monto acumulado de las adiciones agregadas a cualquiera de las
  líneas de un pedido después de que este ya tiene una factura emitida, aún no cobrado. Existe por
  pedido, no por adición individual, y se reduce a cero al cobrarse íntegramente.
- **Pago complementario**: cobro independiente del cobro original del pedido, vinculado al mismo
  pedido, que liquida su saldo pendiente vigente. Es atómico: si el tenant tiene el módulo de
  inventario habilitado y el insumo de alguna adición cubierta no tiene stock suficiente, no se
  cobra ninguna parte del saldo (FR-020). Al cobrarse con éxito, dispara en ese momento el
  descuento de inventario del insumo de cada adición cubierta (cuando aplique, FR-021) y el
  movimiento de caja correspondiente. Un mismo pedido puede tener varios pagos complementarios
  independientes a lo largo de su vida, uno por cada ciclo de saldo pendiente que se liquide
  (FR-022).
- **Factura complementaria**: documento de venta nuevo e independiente, generado al cobrarse con
  éxito un pago complementario, vinculado al pedido original. Nunca modifica, reemplaza ni se
  fusiona con la factura original ya emitida de ese pedido ni con ninguna otra factura
  complementaria previa del mismo pedido.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100% de las adiciones agregadas a una línea en estado "Pendiente" o "En
  preparación" de un pedido sin pagar recalculan el total del pedido sin que el cajero necesite
  anular ni recrear el producto.
- **SC-002**: El 100% de las adiciones agregadas a un pedido con factura ya emitida generan un
  saldo pendiente exactamente igual al valor de la adición, sin que el monto de la factura original
  cambie en ningún caso.
- **SC-003**: El 100% de los pagos complementarios cobrados generan una factura independiente
  vinculada al pedido original, descuentan el insumo correspondiente del inventario, registran el
  movimiento de caja, y dejan el pedido completamente pagado sin saldo pendiente restante.
- **SC-004**: El 100% de los intentos de agregar una adición sobre una línea en un estado distinto a
  "Pendiente" o "En preparación" son bloqueados, mostrando siempre el texto de ayuda
  correspondiente.
- **SC-005**: El 100% de los intentos de agregar una adición sin stock suficiente del insumo son
  rechazados con el mensaje correspondiente, sin dejar ningún cambio en la línea ni en el total del
  pedido.
- **SC-006**: El 100% de los intentos de liberar una mesa (o cerrar un pedido de otro canal) con
  saldo pendiente son bloqueados hasta que dicho saldo se cobre íntegramente.
- **SC-007**: El personal conectado al POS, incluido el punto donde se prepara el pedido, ve
  reflejado el cambio de una línea modificada por adición en cuestión de segundos, sin necesidad de
  recargar manualmente la pantalla.
- **SC-008**: El 100% de los intentos de cobrar un pago complementario cuyo saldo incluye una
  adición sin stock suficiente (en tenants con el módulo de inventario habilitado) son rechazados
  en su totalidad, sin cobrar ninguna parte del saldo ni generar ninguna factura complementaria
  parcial.
- **SC-009**: El 100% de los pedidos que ya liquidaron un pago complementario anterior pueden
  iniciar un nuevo ciclo independiente de saldo pendiente y factura complementaria si se les
  agrega una adición posterior, sin límite en la cantidad de ciclos.

## Assumptions

- **El rol habilitado para "Agregar adición" y "Cobrar saldo" es el mismo que hoy gestiona líneas de
  pedido y cobros (cajero)**: extender esta capacidad a otros roles (ej. mesero, spec 075) queda
  fuera de esta spec, salvo que ese rol ya tenga hoy el permiso equivalente de gestionar líneas y
  cobrar.
- **Todas las adiciones agregadas a un pedido ya facturado se acumulan en un único saldo pendiente
  del pedido**, cobrado con un único pago complementario cuando el cajero decide cobrarlo — no se
  exige un cobro independiente por cada adición agregada.
- **El pago complementario reutiliza el flujo de cobro ya existente** (selección de método de pago,
  cálculo de cambio en efectivo), con la misma restricción vigente de un único método de pago por
  cobro, sin combinar ni dividir en varios pagos parciales (spec 046, Principio II de la
  Constitución: comportamiento existente protegido salvo decisión explícita).
- **El estado de línea "Entregada" mencionado en el contexto de negocio no existe hoy como estado
  independiente del sistema**: los estados de preparación vigentes son "Pendiente", "En
  preparación", "Listo" y "Anulado" (spec 009). Esta spec bloquea la acción sobre "Listo" y
  "Anulado"; si en el futuro se introduce un estado "Entregada" adicional, la misma restricción
  debe extenderse a él sin requerir una nueva decisión de negocio.
- **El mecanismo de notificación en tiempo real ya construido para el POS (spec 077) se extiende con
  un nuevo tipo de evento para "línea modificada por adición"**, reutilizando su despachador
  existente en vez de construir un canal nuevo, consistente con el punto de extensión ya previsto
  en esa spec.
- **La validación de stock al agregar una adición es preventiva, no reserva ni descuenta el
  insumo** (igual que el resto del catálogo, spec 003, RN-CAT-26), y solo aplica cuando el tenant
  tiene habilitado el módulo de inventario (spec 033, FR-021); el descuento real ocurre al
  cobrarse con éxito el pago complementario (o, si el pedido no estaba pagado, al cobrarse el
  pedido completo).
- **El bloqueo de "Liberar Mesa" por saldo pendiente se extiende, por consistencia, a la acción
  equivalente de cierre/entrega de pedidos de otros canales** (mostrador, domicilio) cuando también
  acumulen saldo pendiente, con el mismo mensaje.

## Out of Scope

- Editar o quitar una adición ya agregada a una línea antes de que su saldo se cobre: si el cajero
  se equivoca, la vía existente sigue siendo anular la línea completa (mientras su estado lo
  permita) y rehacerla.
- Reembolsos o devoluciones parciales de adiciones ya cobradas — no existe hoy ninguna
  funcionalidad de reembolso post-pago en el sistema (confirmado también en spec 117); queda para
  una spec futura dedicada a devoluciones/reembolsos.
- Dividir el saldo pendiente de un pedido en varios pagos complementarios parciales, o combinar
  varios métodos de pago dentro de un mismo cobro complementario — sigue vigente la restricción de
  spec 046.
- Modificar el cálculo de precio de adiciones en modo "Conteo" (spec 004) o "Por cantidad" (spec
  065/117): esta spec solo habilita agregar adiciones a una línea ya existente, reutilizando el
  cálculo de precio ya definido por esas specs.
- Construir una pantalla dedicada de cocina (KDS) distinta de la terminal POS actual — spec 009
  confirma que hoy la misma terminal cumple esa función; esta spec solo agrega un nuevo evento de
  notificación sobre la infraestructura ya existente (spec 077).
- Extender esta capacidad a roles distintos de cajero (ver Assumptions).
