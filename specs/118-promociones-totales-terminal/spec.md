# Feature Specification: Consistencia de promociones en el detalle de la orden y en las tarjetas de la terminal

**Feature Branch**: `118-promociones-totales-terminal`

**Created**: 2026-10-14

**Status**: Draft

**Naturaleza de esta spec**: **corrección de comportamiento** (Principio II de la
[Constitución](../../.specify/memory/constitution.md)). No introduce una promoción nueva ni un
tipo de descuento nuevo: corrige tres superficies que hoy no reflejan correctamente las promociones
por volumen ya vigentes en el sistema — el detalle de la orden (renderizado visual, panel de la
terminal POS), las tarjetas de resumen de la terminal (cálculo del `TOTAL`) y el panel "Pagos por
confirmar" (validación del monto en pedidos QR). Si la implementación confirma que alguna de las
correcciones cambia un comportamiento ya protegido por un characterization test, la decisión de
negocio correspondiente se registra en `specs/000-reconocimiento/registro-de-anomalias.md` antes de
implementarla, conforme al Principio II.

**Input**: User description: "Ajustar la lógica de cálculo y el renderizado visual de las órdenes
cuando se incluyen productos con promociones por volumen (ej. 2 unidades por $12.000). Problema 1:
cuando un cliente pide un producto por partes (primero 1 unidad y luego otra de la misma
presentación en momentos distintos), el backend aplica el precio promocional correctamente, pero la
interfaz de detalle no agrupa ni muestra de forma visual la etiqueta y el formato de promoción de
manera consistente. Problema 2: las tarjetas de resumen en la terminal de operación (Mesas,
Domicilios y Para llevar) muestran el TOTAL sumando precios estándar sin descontar las promociones
vigentes, generando discrepancias con el monto real que el cajero debe cobrar."

## Clarifications

### Session 2026-10-14

- Q: ¿El panel "Pagos por confirmar" (donde el cajero aprueba un comprobante o confirma el efectivo recibido para pedidos QR) debe quedar incluido en esta corrección de consistencia del TOTAL, o se considera explícitamente fuera de alcance? → A: Incluirlo en el alcance — ese panel valida el monto a cobrar de forma independiente del detalle/cobro estándar y debe reflejar el mismo total con promociones aplicadas.
- Q: ¿A cuál pantalla se refiere "el detalle de la orden" de la Historia 2 (FR-005 a FR-008): al panel/carrito de pedido de la terminal POS, o a la pantalla "Detalle de Orden" del panel administrativo? → A: Al panel de pedido de la terminal POS (el carrito/orden que ve el cajero desde Mesas, Domicilios y Para llevar) — es la pantalla que hoy ya muestra, para una sola adición, la etiqueta de promoción, el precio tachado y el monto fusionado. La pantalla "Detalle de Orden" del panel administrativo queda fuera de alcance de esta spec: hoy no muestra ningún precio promocional por línea (solo un descuento agregado a nivel de todo el pedido) y ese comportamiento está protegido por characterization tests; no se modifica aquí.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - El TOTAL de la tarjeta de terminal coincide con lo que realmente se cobra (Priority: P1)

Un cajero recorre las vistas de **Mesas**, **Domicilios** y **Para llevar** en la terminal de
operación para decidir qué cuenta atender. Cada tarjeta de resumen muestra un `TOTAL`. Hoy ese
`TOTAL` se calcula sumando los precios estándar de las líneas, sin descontar las promociones por
volumen vigentes, de modo que puede mostrar un monto mayor al que el cajero efectivamente cobrará
al abrir el detalle o el módulo de cobro de esa misma orden.

**Why this priority**: es el problema con mayor impacto de negocio — una discrepancia entre lo que
la tarjeta anuncia y lo que el módulo de cobro termina cobrando puede llevar a cobrar de más o de
menos, o a que el cajero pierda confianza en el número que ve en la pantalla principal de la
terminal.

**Independent Test**: se puede probar abriendo una orden con al menos una línea en promoción por
volumen en cada una de las tres vistas (Mesas, Domicilios, Para llevar) y comparando el `TOTAL` de
la tarjeta de resumen contra el total que el detalle de esa misma orden y el módulo de cobro
calculan, sin necesidad de completar el cobro.

**Acceptance Scenarios**:

1. **Given** una orden en "Mesa 1" con 2 × "Fresa boom" en promoción (`2 x $12.000`) y 1 ×
   "Ensalada de frutas" ($14.000) a precio regular, cuyo total real es $26.000, **When** el cajero
   consulta la vista general de la terminal de Mesas, **Then** la tarjeta de la Mesa 1 muestra un
   `TOTAL` de exactamente $26.000, no $30.000 (la suma de precios sin descuento).
2. **Given** órdenes activas con al menos una línea en promoción por volumen en las modalidades de
   Domicilios o Para llevar, **When** el operador visualiza el panel general de esas pestañas,
   **Then** el `TOTAL` de cada tarjeta incluye el descuento de la promoción vigente aplicada a sus
   líneas.
3. **Given** una orden cuyo `TOTAL` ya se corrigió en la tarjeta de la terminal, **When** el cajero
   abre el detalle de esa orden o el módulo de cobro, **Then** el monto coincide exactamente con el
   que mostraba la tarjeta, sin ningún desfase.
4. **Given** una orden QR con al menos una línea en promoción por volumen, pendiente de aprobación
   de pago, **When** el cajero abre el panel "Pagos por confirmar" para aprobar el comprobante o
   confirmar el efectivo recibido, **Then** el monto que ese panel valida coincide exactamente con
   el `TOTAL` con la promoción aplicada que muestran la tarjeta de resumen y el detalle de la orden,
   sin desfase.

---

### User Story 2 - El detalle de la orden refleja la promoción al completarse por partes (Priority: P2)

Un cliente pide una unidad de una presentación en promoción por volumen y, más adelante, mientras la
orden sigue abierta, pide otra unidad de esa misma presentación en un momento distinto. El backend
ya calcula el precio promocional correctamente al llegar al umbral, pero el detalle de la orden —es
decir, el panel/carrito de pedido de la terminal POS que el cajero abre desde Mesas, Domicilios o
Para llevar, no la pantalla "Detalle de Orden" del panel administrativo— no lo refleja de forma
visual consistente: no siempre muestra la etiqueta de la promoción, el precio original tachado y el
monto ajustado de la misma manera en que ya lo hace cuando la promoción se alcanza en una sola
adición.

**Why this priority**: es un problema de visualización, no de cobro — el monto que finalmente se
cobra ya es correcto hoy (según el enunciado del problema). Su prioridad es menor que la Historia 1
porque no genera un cobro equivocado, pero sí genera confusión y desconfianza en el cajero al leer
el detalle.

**Independent Test**: se puede probar agregando 1 unidad de una presentación con promoción por
volumen a una orden abierta, esperando o agregando otro ítem de por medio, y luego agregando una
segunda unidad de la misma presentación; se verifica que el detalle muestre la etiqueta de
promoción, el precio tachado y el monto ajustado tal como lo muestra hoy cuando ambas unidades se
agregan juntas en una sola acción.

**Acceptance Scenarios**:

1. **Given** que un cliente pide 1 "Fresa boom" a precio unitario y la orden queda en espera en la
   mesa, **When** posteriormente se agrega otra unidad de la misma presentación alcanzando la regla
   de promoción (`2 x $12.000`), **Then** el detalle muestra visualmente la etiqueta de la
   promoción, el precio anterior tachado y el valor ajustado a $12.000, igual que si ambas unidades
   se hubieran pedido juntas desde el principio.
2. **Given** una línea del detalle que ya muestra la etiqueta de promoción por haber alcanzado el
   umbral mediante adiciones sucesivas, **When** se retira una de esas unidades y la cantidad
   restante queda por debajo del umbral, **Then** el detalle deja de mostrar la etiqueta de
   promoción y vuelve a mostrar el precio regular, consistente con el nuevo cálculo del backend.

---

### Edge Cases

- ¿Qué pasa si una orden combina varias líneas con distintos tipos de promoción vigente (por
  volumen en un producto, porcentual en otro)? El `TOTAL` de la tarjeta de terminal debe incluir el
  descuento de cada promoción aplicable a cada línea, no solo el de las promociones por volumen.
- ¿Qué pasa si la cantidad combinada de una misma presentación se completa agregando unidades desde
  canales distintos de la misma orden (p. ej. una unidad agregada por el cajero en el POS y otra
  desde el menú QR de la mesa, antes de cerrar la cuenta)? El umbral de la promoción se evalúa sobre
  la cantidad total de la orden, sin importar desde qué canal se agregó cada unidad.
- ¿Qué pasa si, tras completar el umbral de la promoción, la promoción deja de estar vigente (p.
  ej. por cambio de horario) antes de que la orden se cobre? El detalle, la tarjeta y el panel
  "Pagos por confirmar" deben reflejar el estado de vigencia vigente en cada momento, igual que ya
  hace el motor de promociones hoy; esta spec no modifica la evaluación de vigencia.
- ¿Qué pasa con una orden ya cobrada y facturada? Queda fuera de alcance: los datos históricos de
  facturación son inmutables (Principio VII de la Constitución) y esta corrección aplica únicamente
  a órdenes abiertas, antes del cobro.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST calcular el `TOTAL` mostrado en cada tarjeta de resumen de la
  terminal (Mesas, Domicilios y Para llevar) aplicando los mismos descuentos y precios
  promocionales vigentes que ya aplican el detalle de la orden y el módulo de cobro para esa misma
  orden, para cualquier tipo de promoción vigente evaluable hoy por el motor de promociones
  (`percent` y `package_price`/por volumen, spec 063) y para el mecanismo de precio de combo
  (independiente del motor de promociones). El tipo `fixed` ("monto fijo") fue retirado en la
  migración 063d y ninguna promoción activa puede tenerlo hoy; queda fuera del alcance verificable
  de esta spec.
- **FR-002**: El sistema MUST mantener el `TOTAL` de la tarjeta de terminal sin desfase frente al
  total que reflejan el detalle de la orden, el módulo de cobro y el panel "Pagos por confirmar",
  en cualquier momento mientras la orden permanezca abierta.
- **FR-003**: La corrección del cálculo del `TOTAL` de la tarjeta de terminal MUST aplicar de forma
  transversal a las tres vistas de servicio: Mesas, Domicilios y Para llevar.
- **FR-004**: El panel "Pagos por confirmar" (revisión de pago QR del cajero, donde se aprueba un
  comprobante o se confirma el efectivo recibido) MUST validar el monto a cobrar contra el mismo
  total con promociones vigentes aplicadas que usan la tarjeta de resumen de la terminal, el
  detalle de la orden y el módulo de cobro, para cualquier pedido QR con líneas en promoción.
- **FR-005**: Cuando varias líneas de pedido de la misma presentación (con las mismas adiciones o
  modificadores, cuando aplique) coexistan en una orden abierta por haberse agregado en momentos
  distintos, y su cantidad combinada alcance el umbral de una promoción por volumen vigente, el
  detalle de la orden MUST presentarlas visualmente agrupadas como una sola línea, mostrando la
  etiqueta de la promoción, el precio original tachado y el monto final ajustado.
- **FR-006**: El sistema MUST revertir la presentación visual de promoción de una línea del detalle
  (etiqueta, tachado y monto ajustado) cuando, tras retirar unidades, la cantidad restante deje de
  alcanzar el umbral de la promoción.
- **FR-007**: El formato visual de la etiqueta de promoción, el precio tachado y el monto ajustado
  que se muestra cuando la promoción se completa por adiciones sucesivas MUST ser el mismo formato
  ya usado hoy cuando la promoción se alcanza en una sola adición.
- **FR-008**: El agrupamiento visual descrito en FR-005 MUST limitarse a la presentación en el
  detalle de la orden; no implica fusionar los registros de línea de pedido subyacentes, ni alterar
  su historial individual de creación, edición o envío a cocina.

### Key Entities

- **Orden (cuenta abierta)**: pedido activo de una mesa, un domicilio o un pedido para llevar,
  compuesto por una o más líneas de pedido y un total a cobrar.
- **Detalle de la orden**: en el alcance de esta spec, es el panel/carrito de pedido de la terminal
  POS (compartido por Mesas, Domicilios y Para llevar) donde el cajero ve y agrega las líneas de una
  orden abierta. No incluye la pantalla "Detalle de Orden" del panel administrativo, que queda fuera
  de alcance.
- **Línea de pedido**: registro de una presentación agregada a la orden, con su cantidad, precio
  unitario y, cuando corresponde, el descuento de la promoción vigente que le aplica.
- **Promoción por volumen**: regla vigente que ajusta el precio de una presentación cuando la
  cantidad acumulada en la orden alcanza un umbral determinado (ej. `2 x $12.000`).
- **Tarjeta de resumen de terminal**: elemento visual de las vistas de Mesas, Domicilios y Para
  llevar que resume una orden activa, incluyendo su `TOTAL` a cobrar.
- **Panel "Pagos por confirmar"**: pantalla de revisión de pago QR del cajero donde se aprueba un
  comprobante o se confirma el efectivo recibido para un pedido QR, validando el monto a cobrar de
  forma independiente del detalle y del módulo de cobro estándar.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100% de las tarjetas de resumen de Mesas, Domicilios y Para llevar muestran un
  `TOTAL` idéntico al total que valida el módulo de cobro y, cuando aplique, el panel "Pagos por
  confirmar", al cerrar esa misma orden, en órdenes con al menos una promoción vigente aplicada.
- **SC-002**: Un cajero que atiende Mesas, Domicilios o Para llevar puede decidir y anunciar el
  monto a cobrar leyendo únicamente la tarjeta de resumen, sin necesitar abrir el detalle de la
  orden como paso manual de doble chequeo — eliminando ese paso adicional que hoy reportan los
  cajeros en órdenes con promociones.
- **SC-003**: El 100% de las líneas de pedido que alcanzan el umbral de una promoción por volumen
  mediante adiciones sucesivas en momentos distintos muestran la etiqueta de promoción y el precio
  ajustado, igualando la tasa que ya se obtiene hoy cuando la promoción se alcanza en una sola
  adición.
- **SC-004**: Las incidencias reportadas por discrepancia entre el `TOTAL` de la terminal y el monto
  realmente cobrado, en órdenes con promociones activas, se reducen a cero tras el despliegue de
  esta corrección.

## Assumptions

- El motor de evaluación de vigencia y cálculo de promociones (`percent` y `package_price`/por
  volumen, spec 063) y el mecanismo de precio de combo (independiente de ese motor) ya funcionan
  correctamente a nivel de backend; esta spec corrige únicamente que el `TOTAL` de la tarjeta de
  terminal reutilice ese mismo cálculo, y que el detalle de la orden lo represente visualmente de
  forma consistente. No se modifica la lógica de qué promoción aplica, cuándo está vigente, o
  cuánto descuenta. El tipo `fixed` ("monto fijo") fue retirado en la migración 063d y no tiene
  promociones activas hoy, por lo que no aplica a este supuesto.
- El agrupamiento visual de líneas de la misma presentación en el detalle (FR-005) es un cambio de
  presentación, no de datos: no requiere fusionar ni migrar los registros de línea de pedido ya
  existentes, consistente con que el objetivo declarado de esta spec es "ajustar la lógica de
  cálculo y el renderizado visual", no el modelo de datos de la orden.
- Esta corrección aplica únicamente a órdenes abiertas (no cobradas ni facturadas); las facturas ya
  emitidas no se recalculan ni se les aplica esta corrección de forma retroactiva (Principio VII).
- La pantalla de detalle de la orden es compartida por los tres canales de servicio (Mesas,
  Domicilios y Para llevar), por lo que la corrección de la Historia 2 aplica sin distinción de
  canal, igual que la de la Historia 1.
