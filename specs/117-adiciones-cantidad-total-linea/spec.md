# Feature Specification: Cantidad de adiciones como total de línea, no multiplicador por producto

**Feature Branch**: `117-adiciones-cantidad-total-linea`

**Created**: 2026-10-13

**Status**: Draft

**Naturaleza de esta spec**: **corrección de comportamiento** (Principio II de la
[Constitución](../../.specify/memory/constitution.md); decisión de negocio documentada en esta
spec). Reabre, exclusivamente para grupos de opciones en modo "Por cantidad"
([spec 065](../065-opciones-por-cantidad/spec.md), `FR-004`), la fórmula de precio de línea de
[spec 002](../002-catalogo-productos-variantes-y-precios/spec.md) (`RN-CAT-01`): hoy el recargo de
una adición "Por cantidad" se multiplica implícitamente por la cantidad de producto de la línea (al
formar parte del "precio unitario" que luego se multiplica por esa cantidad); esta spec separa el
subtotal de adiciones del subtotal de producto, de forma que la cantidad de adición ingresada sea
el total absoluto para toda la línea. No reabre ni modifica el cálculo para grupos en modo "Conteo"
(spec 004), que sigue funcionando exactamente igual que hoy.

**Input**: User description: "Modificar la lógica de cobro y gestión de adiciones (toppings/extras)
para que su cantidad represente el total para toda la línea de producto, evitando la
multiplicación automática por la cantidad de unidades del producto principal (ej. pedir 2
granizados con 1 porción de gomitas debe cobrar 1 sola porción de gomitas y no 2). El objetivo es
alinear el cobro con la realidad operativa del negocio y asegurar consistencia tanto en caja como
en los pedidos por menú QR."

## Clarifications

### Session 2026-10-13

- Q: La fórmula nueva (RN2) dice que la adición no se multiplica por la cantidad de producto. Hoy
  existen dos modos de grupo de opciones (spec 065): "Conteo" (marcar/desmarcar, sin selector de
  cantidad propio) y "Por cantidad" (selector de unidades por opción, como "gomitas" en los
  ejemplos). ¿A cuáles modos aplica esta corrección? → A: Solo al modo "Por cantidad". En "Conteo",
  el recargo de una opción marcada se sigue multiplicando por la cantidad de producto de la línea,
  igual que hoy — sin cambios para ese modo.
- Q: Si al reducir la cantidad de producto el nuevo límite del grupo queda por debajo de la suma de
  varias adiciones distintas ya seleccionadas, ¿cómo decide el sistema qué reducir? → A: Reducción
  automática determinista (sin intervención del cajero en el momento del ajuste), mostrando el
  aviso informativo correspondiente.
- Q: Cuando el cajero sí marca que quiere reembolsar adiciones en una devolución parcial, ¿cómo se
  determina la cantidad a reembolsar de cada adición? → A: El cajero la ingresa manualmente en el
  desglose de la devolución, hasta el total disponible en la línea remanente.
- Q: Además del carrito POS, el menú QR y la comanda de cocina, ¿qué otras superficies quedan en
  alcance? → A: La pantalla "Pagos por confirmar" (revisión de pago QR por el cajero), el
  recibo/factura impresa, y el detalle de la orden / "Mis pedidos". Los reportes de ventas e
  inventario quedan fuera de alcance de esta spec.
- Q: ¿La "devolución parcial de una línea" de la Historia de Usuario 5 (FR-008 a FR-010 original)
  ya existe hoy en el sistema, o esta spec tendría que construirla por primera vez? → A: No existe
  hoy en ningún repositorio (confirmado por búsqueda de código: la única anulación existente,
  `void_item`, es exclusivamente pre-pago y de ítem completo, nunca un reembolso parcial post-pago).
  Se retira la Historia de Usuario 5 — junto con sus FR-008, FR-009, FR-010 originales y la entidad
  "Desglose de devolución parcial de línea" — del alcance de esta spec 117, dejándola para una spec
  futura dedicada a devoluciones/reembolsos. Spec 117 queda enfocada exclusivamente en las
  Historias 1 a 4 (el problema de multiplicación de adiciones reportado por el negocio).
- Q: Cuando un cajero agrega el mismo producto con las mismas adiciones "Por cantidad" a una línea
  que ya existe en una orden abierta, ¿cómo debe tratar el sistema la cantidad de producto y la
  cantidad de adición combinadas? → A: El sistema fusiona la línea sumando la cantidad de producto
  a la ya existente, pero obliga al cajero a confirmar o reingresar la cantidad total de adición
  para la nueva cantidad combinada — nunca suma automáticamente las cantidades de adición
  ingresadas en cada acción de agregar por separado.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - El total de la línea refleja la cantidad de adición como total, no multiplicada (Priority: P1)

Un cajero arma una línea con varias unidades del mismo producto (ej. 2 granizados) y agrega una
adición de un grupo "Por cantidad" (ej. 1 porción de gomitas). El sistema cobra el producto por su
cantidad normal, y la adición exactamente por la cantidad ingresada — sin duplicarla por tratarse
de una línea con más de una unidad de producto. Si en cambio el cajero quiere una adición por cada
unidad de producto, la ingresa explícitamente igual a la cantidad de producto.

**Why this priority**: es el problema central reportado por el negocio — hoy cobrar 2 granizados
con 1 porción de gomitas termina cobrando 2 porciones, lo que no corresponde a lo que el cliente
pidió ni a lo que el cajero entregó.

**Independent Test**: se puede probar armando una línea de cantidad 2 con una adición "Por
cantidad" de cantidad 1, verificando que el total solo incluye 1 unidad de esa adición; y, por
separado, armando la misma línea con la adición en cantidad 2, verificando que el total incluye las
2 unidades.

**Acceptance Scenarios**:

1. **Given** el cajero selecciona "Ojo de diablo – Extra grande 20 onz" ($18.000) con cantidad 2,
   **When** agrega 1 porción de "gomitas" ($1.000) de un grupo "Por cantidad", **Then** el botón de
   acción muestra "Agregar • $37.000" (2×$18.000 + 1×$1.000) y la línea guarda el producto ×2 y las
   gomitas ×1 como total de la línea.
2. **Given** la misma presentación con cantidad de producto 2, **When** el cajero agrega
   explícitamente 2 porciones de "gomitas" (una por cada granizado), **Then** el total se calcula
   como 2×$18.000 + 2×$1.000 = $38.000.
3. **Given** una línea de cantidad de producto 1 con una adición "Por cantidad" de cantidad 3,
   **When** se calcula el total, **Then** el subtotal de esa adición es exactamente 3×su precio,
   sin verse afectado por la cantidad de producto (que en este caso es 1).

---

### User Story 2 - Todas las superficies de cobro calculan y muestran el mismo total (Priority: P1)

Un cliente arma el mismo pedido desde el menú QR que un cajero podría armar en el POS. El backend
recalcula el total de forma independiente (nunca confía en el total enviado por el cliente) y ese
mismo monto se refleja de forma consistente en el carrito del POS, el menú QR, la pantalla "Pagos
por confirmar" (donde el cajero aprueba comprobantes o confirma efectivo de pedidos QR), el
recibo/factura impresa y el detalle de la orden ("Mis pedidos").

**Why this priority**: sin una revalidación consistente en backend y en las superficies donde se
confirma o se aprueba un cobro, la Historia 1 podría implementarse solo en la pantalla donde se
arma el pedido y quedar desalineada en la pantalla donde efectivamente se aprueba el pago — dejando
una vía para cobrar o aceptar un monto incorrecto.

**Independent Test**: se puede probar confirmando desde el menú QR un pedido con una adición "Por
cantidad" que no sea 1:1 con la cantidad de producto, y verificando que el monto que calcula el
backend al validar/aprobar el pago (incluida la pantalla "Pagos por confirmar") coincide
exactamente con el mostrado en el menú QR, en el recibo y en el detalle de la orden.

**Acceptance Scenarios**:

1. **Given** un cliente arma desde el menú QR "2 × Ojo de diablo" con 1 "gomitas", **When**
   confirma el pedido, **Then** el total reflejado en el menú QR es $37.000 y el servidor valida y
   recalcula exactamente ese mismo monto en backend, sin aceptar un total distinto enviado por el
   cliente.
2. **Given** ese mismo pedido QR con pago pendiente de validación, **When** el cajero lo revisa en
   la pantalla "Pagos por confirmar" para aprobar el comprobante o confirmar el efectivo, **Then**
   el monto que el sistema valida contra lo recibido es $37.000 — el mismo cálculo de la Historia 1,
   no el monto que resultaría de multiplicar la adición por la cantidad de producto.
3. **Given** un pedido ya pagado con una adición "Por cantidad" no multiplicada, **When** se
   imprime el recibo o se consulta el detalle de la orden / "Mis pedidos", **Then** ambas
   superficies muestran la misma cantidad de adición y el mismo total que se cobró.

---

### User Story 3 - Reducir la cantidad de producto ajusta automáticamente las adiciones que excedan el nuevo límite (Priority: P2)

Un cajero reduce la cantidad de producto de una línea que ya tiene adiciones de un grupo "Por
cantidad" con un máximo configurado por unidad. Si las adiciones ya seleccionadas superan el nuevo
límite (máximo por unidad × nueva cantidad de producto), el sistema las reduce automáticamente
hasta cumplirlo, avisa visualmente del ajuste, y recalcula el total.

**Why this priority**: sin este ajuste, una línea podría quedar en un estado inconsistente (más
adición de la que el límite del grupo permite para esa cantidad de producto) tras reducir la
cantidad — es una protección necesaria pero secundaria a que el cálculo básico (Historias 1 y 2)
exista primero.

**Independent Test**: se puede probar configurando un grupo con máximo 1 unidad por producto,
armando una línea de cantidad 2 con 2 unidades de una adición, reduciendo la cantidad de producto a
1, y verificando que la adición baja automáticamente a 1, se muestra un aviso, y el total se
recalcula.

**Acceptance Scenarios**:

1. **Given** el grupo "toppings" permite un máximo de 1 unidad por producto y la línea tiene
   cantidad de producto 2 con 2 "gomitas" (dentro del límite de 2×1=2), **When** el cajero reduce
   la cantidad de producto a 1, **Then** "gomitas" se ajusta automáticamente a 1 (nuevo límite
   1×1=1), el sistema muestra un aviso informativo del ajuste, y el total se recalcula a $19.000.
2. **Given** una línea con dos adiciones distintas de un mismo grupo "Por cantidad" (ej. 2
   "gomitas" + 1 "chocolate") sobre un límite total del grupo que, tras reducir la cantidad de
   producto, queda por debajo de esa suma, **When** el cajero confirma la reducción, **Then** el
   sistema aplica un criterio determinista y reproducible para decidir qué adición(es) reducir
   primero, sin esperar una decisión manual del cajero en ese momento, y muestra el aviso
   correspondiente.
3. **Given** un grupo "Por cantidad" sin ningún máximo configurado, **When** el cajero reduce la
   cantidad de producto, **Then** no se aplica ningún ajuste automático de adiciones por este
   motivo — el único límite que podría aplicar es el de stock disponible, ya vigente (spec 003).

---

### User Story 4 - La comanda de cocina muestra la cantidad total de cada adición de la línea (Priority: P2)

Un cocinero que recibe la comanda de una línea con adiciones "Por cantidad" ve la cantidad total de
cada adición para esa línea completa, no una cantidad que deba multiplicar mentalmente por el
número de unidades de producto.

**Why this priority**: sin esto, el cálculo interno (Historia 1) puede ser correcto pero el punto
de preparación sigue expuesto a errores humanos de interpretación — es de menor prioridad porque no
bloquea la venta, pero sí la calidad operativa.

**Independent Test**: se puede probar enviando a cocina una línea de cantidad 2 con una adición de
cantidad total 1, y verificando que la comanda indica la cantidad de adición como 1 para toda la
línea, junto con la cantidad de producto.

**Acceptance Scenarios**:

1. **Given** una línea con "2 × Ojo de diablo" y "gomitas ×1" (total de línea), **When** se envía
   la comanda a producción, **Then** se visualiza en cocina algo equivalente a "2 × Ojo de diablo –
   Extra grande · Adiciones: gomitas ×1 (total)", sin que el cocinero deba inferir si esa cantidad
   aplica por unidad o por línea.

---

### Edge Cases

- **El cajero sube de nuevo la cantidad de producto después de un ajuste automático previo
  (Historia 3)**: el límite máximo permitido se recalcula hacia arriba, pero las cantidades de
  adición que fueron reducidas automáticamente no suben solas — el cajero debe volver a
  ingresarlas si las quiere mayores. Un ajuste automático nunca "revive" una cantidad que el
  sistema redujo.
- **La cantidad de producto baja a 0 (se elimina la línea completa)**: se elimina toda la línea,
  incluidas sus adiciones; no aplica el ajuste parcial de la Historia 3.
- **Un grupo "Por cantidad" sin ningún máximo configurado** (spec 065 permite máximos opcionales):
  no hay ajuste automático por límite de grupo al reducir la cantidad de producto; solo podría
  limitar la cantidad el stock disponible del insumo, si el grupo maneja inventario (spec 003,
  `RN-CAT-24`), sin cambios de esta spec.
- **Una línea con adiciones de grupos en modo "Conteo" y modo "Por cantidad" combinados**: el
  recargo de las opciones "Conteo" se sigue multiplicando por la cantidad de producto (sin cambios);
  solo el subtotal de las opciones "Por cantidad" queda excluido de esa multiplicación.
- **El cajero agrega el mismo producto con las mismas adiciones "Por cantidad" a una línea que ya
  existe en una orden abierta** (ej. una mesa que ya tiene ese producto en la cuenta): el sistema
  fusiona la línea sumando la cantidad de producto a la ya existente, pero no suma automáticamente
  las cantidades de adición de ambas acciones — exige que el cajero confirme o reingrese
  explícitamente la cantidad total de adición que corresponde a la nueva cantidad de producto
  combinada (FR-014), evitando que la fusión reintroduzca una multiplicación o suma implícita no
  deseada.
- **Pedidos o ventas ya confirmados antes de esta funcionalidad**: su precio, cantidades de
  adición y consumo de inventario ya registrados no se recalculan retroactivamente (Principio VII
  de la Constitución).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Para un grupo de opciones en modo "Por cantidad" (spec 065), el sistema DEBE
  interpretar la cantidad de cada adición seleccionada o ingresada como el total absoluto para toda
  la línea de pedido, nunca como un multiplicador por cada unidad de producto principal.
- **FR-002**: El sistema DEBE calcular el total de una línea de pedido que incluya adiciones de un
  grupo "Por cantidad" mediante la fórmula: `Total Línea = (Cantidad Producto × Precio
  Presentación) + Σ(Cantidad Adición × Precio Adición)`, sin multiplicar el componente de adiciones
  por la cantidad de producto.
- **FR-003**: El sistema DEBE permitir al cajero o al cliente ingresar una cantidad de adición
  igual a la cantidad de producto cuando desee una unidad de adición por cada unidad de producto
  (ej. una porción por cada vaso); esa igualdad es siempre una elección explícita de quien arma el
  pedido, nunca un cálculo automático del sistema.
- **FR-004**: Cuando un grupo de adiciones "Por cantidad" tenga un máximo configurado por unidad de
  producto (spec 065, `FR-008`), el sistema DEBE calcular el límite máximo permitido para esa línea
  como `Máximo por unidad × Cantidad de Producto`.
- **FR-005**: Cuando el cajero reduzca la cantidad de producto de una línea y la cantidad total de
  una o más adiciones ya seleccionadas supere el nuevo límite máximo permitido (FR-004), el sistema
  DEBE reducir automáticamente esas cantidades de adición hasta cumplir el nuevo límite, mostrar un
  aviso informativo del ajuste realizado, y recalcular el total de la línea (FR-002).
- **FR-006**: Cuando existan varias adiciones distintas dentro del mismo grupo cuya suma, tras una
  reducción de cantidad de producto, supere el nuevo límite total del grupo, el sistema DEBE aplicar
  un criterio determinista y reproducible para decidir qué adición o adiciones reducir primero, sin
  requerir una decisión manual del cajero en el momento del ajuste.
- **FR-007**: El descuento de inventario de una adición de un grupo "Por cantidad" DEBE calcularse
  estrictamente según su cantidad total vigente en la línea (ya resuelta por FR-001 y, si aplica,
  FR-005), sin multiplicar por la cantidad de producto principal.
- **FR-008**: La comanda de producción enviada a cocina DEBE mostrar, para cada adición de un grupo
  "Por cantidad" de la línea, su cantidad total vigente (no multiplicada por la cantidad de
  producto), usando el mismo formato de cantidad ya definido para este modo (spec 065, `FR-010`).
- **FR-009**: El servidor (backend) DEBE recalcular y validar de forma independiente el total de
  cada línea de pedido con adiciones "Por cantidad" aplicando la fórmula de FR-002, sin confiar en
  el total enviado por el cliente desde el menú QR ni por el cajero desde el POS.
- **FR-010**: El carrito/panel de cobro del POS, el menú autogestionado QR, la comanda de cocina, el
  recibo/factura impresa, el detalle de la orden ("Mis pedidos") y la pantalla "Pagos por confirmar"
  (revisión de pago QR por el cajero) DEBEN mostrar el mismo total y el mismo desglose de cantidad
  de adición para una misma línea de pedido.
- **FR-011**: El pre-chequeo de total usado por la pantalla "Pagos por confirmar" antes de aprobar
  un comprobante o confirmar efectivo de un pedido QR DEBE aplicar la misma fórmula de FR-002, de
  forma que un pedido con adiciones "Por cantidad" se valide contra el monto correcto.
- **FR-012**: El sistema NO DEBE modificar el precio, las cantidades de adición, ni el consumo de
  inventario ya registrados en pedidos o ventas confirmados antes de esta funcionalidad (Principio
  VII de la Constitución).
- **FR-013**: El cálculo de precio y de consumo de inventario para grupos de opciones en modo
  "Conteo" (spec 004) NO DEBE cambiar — el recargo de una opción de ese modo se sigue calculando
  exactamente como hoy, multiplicado por la cantidad de producto de la línea.
- **FR-014**: Cuando el cajero agregue el mismo producto con las mismas adiciones de un grupo "Por
  cantidad" a una línea ya existente en una orden (fusionando la cantidad de producto con la ya
  existente), el sistema DEBE exigir que el cajero confirme o reingrese explícitamente la cantidad
  total de adición correspondiente a la nueva cantidad de producto combinada, sin sumar
  automáticamente las cantidades de adición ingresadas en cada acción de agregar por separado.

### Key Entities *(include if feature involves data)*

- **Línea de pedido / línea de venta**: distingue ahora, para efectos de cálculo, el subtotal del
  producto (`Precio Presentación × Cantidad Producto`) del subtotal de adiciones de grupos "Por
  cantidad" (`Σ Cantidad Adición × Precio Adición`) — ambos se suman, pero el segundo ya no se
  multiplica por la cantidad de producto. El subtotal de adiciones de grupos "Conteo" sigue
  formando parte del precio unitario que se multiplica por la cantidad de producto, sin cambios.
- **Grupo de opciones "Por cantidad" (spec 065)**: su tope máximo por opción individual, al
  aplicarse a una línea concreta, se escala ahora explícitamente por la cantidad de producto de esa
  línea (`Máximo por unidad × Cantidad de Producto`), en vez de aplicarse como un tope fijo
  independiente de la cantidad de producto.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: En el 100% de las líneas con una adición "Por cantidad", el total cobrado es
  exactamente `Cantidad Producto × Precio Presentación + Cantidad Adición × Precio Adición`,
  verificable comparando el monto final contra ese cálculo para cantidades de producto y de
  adición distintas entre sí.
- **SC-002**: El 100% de las reducciones de cantidad de producto que dejan a una o más adiciones
  por encima del nuevo límite del grupo quedan ajustadas automáticamente y notificadas al cajero
  antes de continuar, sin que el cajero deba detectarlo ni corregirlo manualmente.
- **SC-003**: El total calculado y mostrado en el menú QR coincide, para el 100% de los pedidos con
  adiciones "Por cantidad", con el recalculado por el backend y con el mostrado en la pantalla
  "Pagos por confirmar", el recibo impreso y el detalle de la orden — cero discrepancias entre
  superficies.
- **SC-004**: Un cocinero puede identificar, directamente desde la comanda y sin realizar ningún
  cálculo mental, la cantidad total de cada adición de una línea.
- **SC-005**: El 100% de los pedidos y ventas confirmados antes de esta funcionalidad, al
  consultarse después, muestran exactamente el mismo precio, las mismas cantidades de adición y el
  mismo consumo de inventario que mostraban antes — cero regresiones sobre datos históricos.

## Out of Scope

- **Devolución parcial de una línea con reembolso de adiciones**: no existe hoy ninguna
  funcionalidad de reembolso post-pago en el sistema (la única anulación existente, `void_item`, es
  pre-pago y de ítem completo). Construir esa capacidad — incluyendo su interacción con facturas ya
  emitidas (Principio VII) — queda fuera de esta spec y se define en una spec futura dedicada a
  devoluciones/reembolsos (decisión de la sesión de Clarifications de esta spec).
- Cambiar el cálculo de precio o de consumo de inventario para grupos de opciones en modo "Conteo"
  (spec 004) — sigue vigente sin ninguna modificación.
- Modificar el comportamiento de los topes de cantidad por opción individual o por grupo definidos
  en spec 065 (`FR-008`/`FR-009`) más allá de escalar el tope por unidad según la cantidad de
  producto de la línea (FR-004 de esta spec).
- Cambios al motor de promociones y combos (specs 012/013) más allá de que sigan operando sobre el
  precio de línea ya calculado por esta spec.
- Recalcular retroactivamente pedidos o ventas confirmados antes de esta funcionalidad.
- Reportes de ventas e inventario que desglosen o analicen específicamente por cantidad de adición
  — esta spec solo exige que el dato quede conservado y sea consistente entre las superficies
  listadas en FR-010, no que se construya un reporte nuevo.
- Definir el diseño visual concreto del aviso informativo de ajuste automático (FR-005) — esta
  especificación define su comportamiento; el diseño concreto se resuelve en la fase de
  planeación.

## Assumptions

- **Solo el modo "Por cantidad" (spec 065) cambia de comportamiento**: decisión explícita tomada en
  la sesión de Clarifications de esta spec — el modo "Conteo" (spec 004) sigue multiplicando su
  recargo por la cantidad de producto, sin ningún cambio.
- **El criterio determinista de reducción automática (FR-006) se define en detalle durante la fase
  de planeación**: esta spec exige que exista un criterio reproducible y consistente para decidir
  qué adición reducir primero cuando hay varias en conflicto, pero no fija cuál es ese criterio
  (ej. última modificada primero, orden de creación, u otro) — es una decisión de diseño, no de
  negocio.
- **"Pagos por confirmar" es una superficie en alcance explícito**: confirmado por el usuario en la
  sesión de Clarifications, dado que esta pantalla ya tiene un pre-chequeo de total en backend
  (`_order_total`) que debe aplicar la misma fórmula — es, según la experiencia previa del negocio,
  la superficie que con más frecuencia queda desalineada en specs de precios anteriores.
- **Los reportes de ventas e inventario quedan fuera de alcance**: el usuario no los marcó como
  requeridos en la sesión de Clarifications; seguirán mostrando los datos ya conservados (cantidad
  y precio por adición) sin un reporte nuevo específico sobre esta regla.
- **Las ventas/pedidos confirmados antes de esta funcionalidad no se recalculan**: por Principio VII
  de la Constitución, ningún dato histórico se modifica retroactivamente al entrar en vigor esta
  corrección.
- **La devolución parcial de una línea con reembolso de adiciones queda fuera de esta spec**:
  decisión explícita tomada en la sesión de Clarifications, tras confirmar por código que ninguna
  funcionalidad de reembolso post-pago existe hoy en el sistema. Construirla desde cero dentro de
  una spec de "corrección de comportamiento" mezclaría una funcionalidad nueva con la corrección
  reportada por el negocio (Principios I, V y VI de la Constitución); se deja para una spec futura
  dedicada a devoluciones/reembolsos.
