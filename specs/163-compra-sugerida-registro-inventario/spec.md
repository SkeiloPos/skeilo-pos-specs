# Feature Specification: Registro Automático de Inventario al Generar Compra Sugerida

**Feature Branch**: `[163-compra-sugerida-registro-inventario]`

**Created**: 2026-11-21

**Status**: Draft

**Input**: User description: "quisiera cambiar el flujo de la creación de orden de compra sugerida, actualmente pasa que se crean las órdenes pero no se registran los movimientos en el inventario, quisiera cuando se crea la orden automáticamente se registrara los movimientos de cada ítem en el inventario"

## Clarifications

### Session 2026-11-21

- Q: Después de generar una orden y aumentar el stock de sus insumos, ¿la pantalla de compra sugerida debe quitar de inmediato esos insumos ya repuestos de la lista de "bajo mínimo", o debe dejar la lista como estaba hasta que el usuario la recargue manualmente? → A: La pantalla quita de inmediato los insumos ya repuestos de la lista tras una generación exitosa, para evitar que el administrador los vuelva a seleccionar y genere una compra duplicada.
- Q: Las órdenes que ya quedaron creadas en estado "borrador" antes de este cambio, ¿deben migrarse/retroactivarse a "recibida" con su stock y movimientos, o deben dejarse tal cual, recibiéndose solo por el flujo manual existente? → A: Se dejan tal cual; solo las órdenes generadas desde compra sugerida a partir de este cambio usan el nuevo comportamiento. Las órdenes en borrador existentes siguen su recepción manual como hasta ahora.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Generar la orden deja el inventario actualizado de inmediato (Priority: P1)

Como administrador del tenant, cuando genero las órdenes de compra desde la pantalla de
compra sugerida, quiero que cada insumo incluido quede con su stock aumentado y su
movimiento de inventario registrado en el mismo momento en que se crea la orden, sin tener
que ir después a "recibir" cada orden manualmente, porque en este flujo la mercancía ya se
da por recibida al momento de generar la compra.

**Why this priority**: Es el cambio central solicitado: hoy las órdenes generadas desde
compra sugerida quedan en borrador sin afectar el inventario, obligando a un paso manual de
recepción que hoy no se está haciendo y que genera descuadres de stock. Sin este cambio no
existe la funcionalidad.

**Independent Test**: Se puede probar generando una orden para un insumo conocido con stock
y proveedor configurados, y verificando que, inmediatamente después de la generación, el
stock del insumo aumentó en la cantidad comprada (convertida a unidad de inventario) y que
aparece un nuevo movimiento de entrada asociado a esa orden, sin ejecutar ninguna acción de
recepción.

**Acceptance Scenarios**:

1. **Given** ALMENDRAS tiene stock 10 g y el administrador deja seleccionada una compra de
   1 bolsa x 500 g a $8.000 con AGRO SUR, **When** el administrador genera las órdenes de
   compra, **Then** la orden de AGRO SUR queda creada con ALMENDRAS en estado "recibida",
   el stock de ALMENDRAS pasa a 510 g, y se registra un movimiento de entrada de 500 g para
   ALMENDRAS asociado a esa orden.
2. **Given** el administrador selecciona insumos de 2 proveedores distintos y genera las
   órdenes, **When** la generación termina exitosamente, **Then** se crean 2 órdenes, ambas
   en estado "recibida", y cada insumo de cada orden muestra su movimiento de entrada y su
   stock ya actualizado.
3. **Given** dos insumos seleccionados comparten el mismo proveedor, **When** se genera la
   orden de ese proveedor, **Then** esa única orden registra un movimiento de entrada
   independiente por cada uno de los dos insumos, y el stock de ambos queda actualizado.
4. **Given** la generación de órdenes terminó exitosamente, **When** la pantalla de compra
   sugerida se actualiza, **Then** los insumos que acaban de recibir stock desaparecen de la
   lista de "bajo mínimo" sin que el administrador tenga que recargar la pantalla
   manualmente.

---

### User Story 2 - Verificar el resultado en el historial del insumo (Priority: P2)

Como administrador del tenant, quiero poder ver en el historial de movimientos de cada
insumo el movimiento generado por una compra sugerida, identificado como proveniente de esa
orden, para confiar en que el aumento de stock que veo corresponde a una compra concreta y
poder rastrearlo si algo no coincide.

**Why this priority**: No cambia el resultado de la Historia 1, pero sin trazabilidad
visible el administrador no puede confiar en el nuevo comportamiento ni auditar los
aumentos de stock que antes no existían en este flujo.

**Independent Test**: Con una orden ya generada por compra sugerida, se puede abrir el
historial de movimientos del insumo comprado y verificar que el movimiento muestra la
cantidad, la fecha y una referencia identificable a la orden de compra que lo originó.

**Acceptance Scenarios**:

1. **Given** se generó una orden de compra sugerida que incluyó a ALMENDRAS, **When** el
   administrador abre el historial de movimientos de ALMENDRAS, **Then** ve un movimiento
   de entrada con la cantidad, la fecha de generación y una referencia a la orden de compra
   correspondiente.

---

### Edge Cases

- ¿Qué pasa si, dentro de un mismo lote de generación, falla el registro del movimiento o
  el aumento de stock de algún insumo de alguna de las órdenes? No se crea ninguna orden, ni
  se registra ningún movimiento, ni se modifica el stock de ningún insumo de ese lote
  completo (igual que la regla transaccional ya existente para la creación de las órdenes).
- ¿Qué pasa si el administrador reintenta la generación tras un error de red sin saber si la
  petición anterior se procesó? La misma clave de idempotencia ya usada para no duplicar
  órdenes también evita duplicar movimientos de inventario y aumentos de stock.
- ¿Qué pasa si el administrador necesita deshacer una orden generada por error (cantidad o
  insumo equivocado)? Usa el mecanismo de anulación de órdenes ya existente para órdenes con
  stock dado de alta, que revierte el stock y registra el movimiento de reversión
  correspondiente; esta funcionalidad no cambia ese mecanismo.
- ¿Qué pasa con la creación manual de órdenes de compra fuera de la pantalla de compra
  sugerida? Sigue comportándose igual que hoy: la orden queda en borrador, sin movimientos
  de inventario ni cambios de stock, hasta que se reciba manualmente. Este cambio aplica
  únicamente a las órdenes generadas desde la pantalla de compra sugerida.
- ¿Qué pasa si dos administradores generan compras sugeridas al mismo tiempo sobre el mismo
  insumo desde sesiones distintas? Cada generación registra su propio movimiento y aumenta
  el stock de forma independiente, igual que ya ocurre hoy con otros movimientos
  concurrentes de inventario.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Al generar órdenes de compra desde la pantalla de compra sugerida, el sistema
  MUST crear cada orden directamente en estado "recibida", en lugar de "borrador", sin
  requerir una acción posterior de recepción para que el inventario quede actualizado.
- **FR-002**: El sistema MUST registrar, para cada insumo incluido en una orden generada
  desde la compra sugerida, un movimiento de inventario de entrada por la cantidad comprada,
  convertida a la unidad de inventario del insumo, asociado como referencia a la orden de
  compra que lo originó.
- **FR-003**: El sistema MUST aumentar el stock actual de cada insumo incluido en la
  cantidad registrada en su movimiento de inventario, en el mismo momento en que se genera
  la orden, sin esperar una acción adicional de recepción.
- **FR-004**: El sistema MUST ejecutar, para cada lote de generación, la creación de todas
  las órdenes, el registro de todos sus movimientos de inventario y el aumento de todos los
  stocks correspondientes dentro de una sola operación atómica: si falla cualquier paso para
  cualquier insumo u orden del lote, el sistema MUST no crear ninguna orden, movimiento, ni
  cambio de stock de ese lote completo.
- **FR-005**: El sistema MUST mantener, antes de generar la orden, el movimiento y el
  aumento de stock, la validación en el servidor de que cada insumo seleccionado tenga
  proveedor, unidad de compra y precio mayor a 0, y cantidad mayor o igual a 1.
- **FR-006**: El sistema MUST mantener la aceptación de una clave de idempotencia en la
  solicitud de generación, de forma que reenvíos con la misma clave no dupliquen órdenes,
  movimientos de inventario, ni aumentos de stock.
- **FR-007**: El sistema MUST mostrar el movimiento registrado por esta vía en el historial
  de movimientos del insumo correspondiente, junto con los demás movimientos del insumo, con
  una referencia identificable a la orden de compra que lo originó.
- **FR-008**: El sistema MUST actualizar el costo o precio de referencia de cada insumo con
  el precio de la orden generada, de forma consistente con el comportamiento ya existente
  cuando una orden de compra se recibe o se da de alta directamente.
- **FR-009**: El sistema MUST permitir anular una orden generada por esta vía mediante el
  mecanismo de anulación de órdenes ya existente para órdenes con stock dado de alta,
  revirtiendo el stock aumentado y registrando el movimiento de reversión correspondiente.
- **FR-010**: El sistema MUST mostrar, en la confirmación de una generación exitosa, que las
  órdenes creadas quedaron en estado "recibida", junto con el enlace a cada orden.
- **FR-011a**: El sistema MUST quitar de la lista de "bajo mínimo" de la pantalla de compra
  sugerida, inmediatamente después de una generación exitosa, cada insumo cuyo stock quedó
  por encima de su mínimo como resultado de esa generación, sin requerir que el
  administrador recargue manualmente la pantalla.
- **FR-011**: Este cambio de comportamiento MUST aplicar únicamente a las órdenes generadas
  desde la pantalla de compra sugerida; la creación manual de órdenes de compra por fuera de
  ese flujo MUST seguir quedando en estado "borrador", sin movimientos de inventario ni
  cambios de stock hasta su recepción manual.

### Key Entities

- **Orden de Compra**: documento que agrupa una o más líneas de compra de un único
  proveedor. Las órdenes generadas desde compra sugerida ahora quedan creadas directamente
  en estado "recibida" en lugar de "borrador".
- **Línea de Orden de Compra**: insumo, cantidad en unidad de compra, precio y subtotal
  dentro de una orden de compra. Cada línea de una orden generada por compra sugerida ahora
  origina un movimiento de inventario y un aumento de stock al momento de crearse la orden.
- **Movimiento de Inventario**: registro de entrada de stock para un insumo, con cantidad,
  fecha y referencia a su documento de origen. Esta funcionalidad agrega un nuevo origen
  posible para estos movimientos: la generación de órdenes desde la pantalla de compra
  sugerida.
- **Insumo**: materia prima o producto de inventario cuyo stock actual se incrementa de
  inmediato al generarse una orden de compra sugerida que lo incluya.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Después de generar órdenes desde la compra sugerida, el 100% de los insumos
  incluidos muestran su stock aumentado y un movimiento de entrada visible en su historial,
  sin que el usuario realice ninguna acción adicional de recepción.
- **SC-002**: Un administrador puede verificar que el stock de cada insumo comprado ya
  refleja la cantidad generada en menos de 1 minuto después de que la generación termina.
- **SC-003**: El 100% de los intentos de generación donde falla el registro de algún
  movimiento o algún aumento de stock terminan sin crear ninguna orden, movimiento ni cambio
  de stock parcial del lote.
- **SC-004**: Reenviar la misma solicitud de generación nunca duplica movimientos de
  inventario ni incrementos de stock.

## Assumptions

- Este cambio reemplaza, únicamente para el flujo de compra sugerida, la regla previa de
  que las órdenes de compra generadas quedan en borrador sin afectar el inventario hasta su
  recepción (definida en la especificación de Compra Sugerida de Insumos); el resto de reglas
  de esa especificación (agrupación por proveedor, validaciones de precio/cantidad,
  idempotencia, transaccionalidad del lote) se mantienen y se extienden para cubrir también
  el movimiento de inventario y el aumento de stock.
- Las órdenes generadas por esta vía se consideran siempre recibidas en su totalidad; no
  aplica el concepto de recepción parcial para este flujo.
- La lógica de conversión entre unidad de compra y unidad de inventario, y la actualización
  del costo del insumo, ya existen en el sistema (se usan hoy al recibir o dar de alta una
  orden de compra) y esta funcionalidad las reutiliza sin cambiarlas.
- El mecanismo para anular o revertir una orden con stock ya dado de alta ya existe en el
  sistema y esta funcionalidad lo reutiliza sin modificarlo.
- La creación manual de órdenes de compra fuera de la pantalla de compra sugerida no forma
  parte del alcance de este cambio y conserva su comportamiento actual (borrador hasta
  recepción manual).
- Las órdenes que ya existían en estado "borrador" antes de este cambio (generadas por
  compra sugerida o manualmente) no se migran ni se retroactivan: siguen recibiéndose por el
  flujo manual de recepción ya existente. El nuevo comportamiento (estado "recibida",
  movimiento y aumento de stock automáticos) aplica únicamente a las órdenes generadas desde
  compra sugerida a partir de la entrada en vigor de este cambio.
