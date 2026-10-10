# Feature Specification: Comprar en la presentación real, no en la unidad base

**Feature Branch**: `107-compra-presentacion-conversion`

**Created**: 2026-10-09

**Status**: Draft

**Input**: User description: "Como administrador de la heladería, quiero que al registrar una
compra pueda indicar en qué presentación la compré (la que ya tengo guardada en la relación
proveedor-insumo, p. ej. 'Bolsa x 500 g' o 'Libra') y cuántas presentaciones compré, para que el
sistema calcule solo cuántas unidades base entraron al inventario — sin que yo tenga que
convertir manualmente." Es la Estrategia A de `analisis-conversion-unidades-compras.md` (raíz del
repo): conecta `SupplierItem.presentation`/`conversion_factor`, ya construido por la spec
[106](../106-relacion-proveedor-insumo/spec.md), a los 3 flujos de compra — el trabajo que esa
spec dejó pendiente y documentó como "HU-05" (RN-15). La conversión genérica entre unidades de
medida distintas (Estrategia B del mismo análisis, anomalía A-31 de la spec
[005](../005-kardex-compras-conversion/spec.md)) queda explícitamente fuera de esta spec.

## Clarifications

### Session 2026-10-09

- Q: ¿el costo que se captura al elegir una presentación es el de una sola presentación o el
  total de la línea completa? → A: Opción A — el costo de **una sola presentación** (p. ej.
  "$4.000 la bolsa"); el total de la línea se calcula como cantidad × costo (FR-002, FR-005).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Comprar indicando la presentación real, no la unidad base (Priority: P1)

Un administrador registra una compra directa (recibida de inmediato) contra un proveedor con el
que ya tiene una relación proveedor-insumo activa (p. ej. "Distribuidora Norte" le vende
"Azúcar" en "Bolsa x 500 g"). En vez de escribir la cantidad en gramos, elige la presentación,
indica cuántas bolsas compró y cuánto le costó cada una — el sistema calcula solo cuántos gramos
entraron al inventario y a qué costo por gramo.

**Why this priority**: es el dolor concreto que origina esta spec — sin esto, el administrador
sigue calculando a mano cada compra, exactamente como hoy.

**Independent Test**: se puede probar por completo registrando una compra directa con una
presentación ya existente, sin depender de las otras historias.

**Acceptance Scenarios**:

1. **Given** que "Distribuidora Norte" vende "Azúcar" en "Bolsa x 500 g" (factor 500, insumo en
   gramos), **When** un administrador registra una compra directa a "Distribuidora Norte"
   eligiendo esa presentación, 1 bolsa, a $4.000, **Then** el stock de "Azúcar" sube en 500 g, el
   costo por gramo del insumo queda en $8 (4.000 ÷ 500), y la compra registrada muestra un total
   de línea de $4.000 (no un valor con redondeo distinto).
2. **Given** la misma relación, **When** el administrador compra 3 bolsas a $4.000 cada una,
   **Then** el stock sube en 1.500 g (3 × 500) y el total de esa línea es $12.000.
3. **Given** un insumo y proveedor sin ninguna relación proveedor-insumo activa, o una compra
   contra el proveedor de sistema "Compra ocasional", **When** el administrador registra la
   compra, **Then** no se le ofrece ninguna presentación — captura la cantidad directamente en la
   unidad base del insumo, exactamente como hoy.
4. **Given** una presentación con factor de conversión, **When** la compra registrada contra
   ella, **Then** el administrador puede ver después, en el historial de esa compra, tanto la
   presentación y la cantidad que realmente compró (p. ej. "3 Bolsa x 500 g") como su
   equivalencia en unidad base — no solo el valor ya convertido.

---

### User Story 2 - El último costo del proveedor se actualiza solo al comprarle (Priority: P1)

Cada vez que una compra se registra contra una presentación, la relación proveedor-insumo
correspondiente (pestaña "Proveedores" del insumo, spec 106) refleja el costo y la fecha de esa
compra sin que el administrador tenga que ir a actualizarla a mano.

**Why this priority**: es RN-15, ya anticipada y dejada pendiente explícitamente por la spec 106
— sin esto, la pestaña "Proveedores" muestra un costo desactualizado tan pronto como se vuelve a
comprar, contradiciendo lo que la propia compra acaba de registrar.

**Independent Test**: se puede probar registrando una compra contra una presentación y
verificando, inmediatamente después, que el último costo y la fecha de esa relación cambiaron sin
ninguna acción manual adicional.

**Acceptance Scenarios**:

1. **Given** que la relación "Distribuidora Norte"–"Azúcar"–"Bolsa x 500 g" tiene
   `último_costo = $3.800` desde la última compra, **When** se registra una nueva compra contra
   esa presentación a $4.000 la bolsa, **Then** el último costo de esa relación queda en $4.000 y
   su fecha de último costo queda con la fecha y hora de esta compra.
2. **Given** la misma relación, **When** se consulta la pestaña "Proveedores" del insumo
   inmediatamente después de registrar la compra, **Then** la equivalencia mostrada ya refleja el
   nuevo costo, sin recargar nada manualmente.

---

### User Story 3 - Orden de compra y recepción parcial en presentación (Priority: P2)

Un administrador crea una orden de compra (sin dar alta de stock todavía) indicando la
presentación pactada con el proveedor, y la recibe — total o parcialmente, en uno o varios
envíos — más adelante. La presentación y su factor quedan fijados desde que se crea la orden; la
recepción nunca los cambia.

**Why this priority**: cubre el segundo camino real de entrada de stock del sistema (orden +
recepción), no solo la compra directa de la Historia 1 — sin esto, el administrador solo
resolvería el problema para compras que recibe de inmediato.

**Independent Test**: se puede probar creando una orden contra una presentación y haciendo dos
recepciones parciales sucesivas, verificando que ambas usan el mismo factor pactado al crear la
orden.

**Acceptance Scenarios**:

1. **Given** una orden de compra creada contra "Bolsa x 500 g" por 10 bolsas, **When** se recibe
   la mitad (5 bolsas) y después la otra mitad, **Then** cada recepción suma 2.500 g (5 × 500) al
   stock, usando el mismo factor 500 en ambas — nunca uno distinto.
2. **Given** la misma orden, **When** se consulta después de recibirla por completo, **Then** el
   costo aplicado a cada recepción es el pactado al crear la orden, no uno recalculado al recibir
   (RN-INV-22, protegida).

---

### Edge Cases

- Una línea de compra con presentación inactiva, o que no corresponde exactamente al proveedor y
  al insumo ya elegidos en esa misma línea, no debe ofrecerse ni aceptarse.
- Comprar contra el proveedor de sistema "Compra ocasional" nunca ofrece selector de
  presentación (RN-17: ese proveedor no puede tener relaciones proveedor-insumo).
- Dos líneas de la misma compra pueden combinarse libremente — una contra una presentación y
  otra directo en unidad base (p. ej. un insumo sin relación con ese proveedor) — cada línea se
  resuelve de forma independiente.
- Si el insumo y proveedor elegidos tienen más de una presentación activa, se ofrecen todas,
  ordenadas con la preferida primero — mismo orden que ya usa la spec 106.
- Una compra registrada contra una presentación deja esa presentación "usada en una compra" —
  de ahí en adelante, su factor de conversión no se puede editar (FR-014 de la spec 106, ya
  implementada); esta spec es la que produce ese primer uso real.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Al registrar una línea de compra (alta directa, creación de orden, o recepción)
  contra un insumo y un proveedor que tengan al menos una relación proveedor-insumo activa, el
  sistema DEBE permitir elegir una de esas presentaciones en lugar de capturar la cantidad
  directamente en la unidad base del insumo.
- **FR-002**: Al elegir una presentación, el administrador DEBE indicar cuántas presentaciones
  compra (estrictamente mayor que cero) y el costo de **una sola presentación** (p. ej. "$4.000
  la bolsa", no el total de la línea) — mismo criterio que `SupplierItem.last_cost` (spec 106).
- **FR-003**: El sistema DEBE calcular automáticamente la cantidad en unidad base (cantidad de
  presentaciones × factor de conversión de la presentación elegida) y usar siempre ese valor
  calculado — nunca uno capturado directamente — para dar alta de stock.
- **FR-004**: El sistema DEBE calcular automáticamente el costo por unidad base a partir del
  costo capturado en la presentación, redondeado a 2 decimales (mismo criterio que la spec 106,
  FR-007), y usar ese valor para el costo unitario del insumo y de la línea de compra.
- **FR-005**: El total de cada línea de compra registrada contra una presentación DEBE calcularse
  con los valores originalmente capturados por el administrador (cantidad de presentaciones y su
  costo), no con los valores ya convertidos a unidad base — para no acumular error de redondeo.
- **FR-006**: Al registrar o recibir una compra contra una presentación, el sistema DEBE
  actualizar, en la misma operación, el último costo y la fecha de último costo de esa relación
  proveedor-insumo (RN-15) — reutilizando las validaciones de esa relación ya existentes, sin
  reabrirlas.
- **FR-007**: Si una línea de compra no elige ninguna presentación — incluida cualquier compra
  contra el proveedor de sistema "Compra ocasional", que nunca tiene relaciones proveedor-insumo
  — el sistema DEBE capturar la cantidad y el costo directamente en la unidad base del insumo,
  exactamente como hoy, sin ningún cálculo nuevo.
- **FR-008**: Al crear una orden de compra contra una presentación, el sistema DEBE fijar esa
  presentación y su factor de conversión en ese momento; cada recepción posterior (parcial o
  total) de esa orden DEBE aplicar el mismo factor fijado al crearla (RN-INV-22, protegida).
- **FR-009**: El selector de presentación de una línea de compra NO DEBE ofrecer presentaciones
  inactivas, ni presentaciones de un proveedor o insumo distinto al ya elegido en esa misma
  línea.
- **FR-010**: La cantidad de presentaciones DEBE ser estrictamente mayor que cero y el costo
  asociado DEBE ser mayor o igual a cero, de forma consistente en los 3 flujos de compra (alta
  directa, creación de orden, recepción) — mismo criterio que ya exige RN-INV-23 para la captura
  en unidad base.
- **FR-011**: El historial de una línea de compra registrada contra una presentación DEBE
  conservar, además de la cantidad y el costo ya convertidos a unidad base, qué presentación se
  eligió y cuántas se capturó originalmente — para que el administrador pueda ver después qué
  compró en realidad, no solo su equivalencia.
- **FR-012**: Esta funcionalidad NO DEBE requerir ni construir ninguna conversión entre unidades
  de medida distintas de la unidad base (p. ej. libra↔gramo) fuera de una relación
  proveedor-insumo ya guardada — ver Out of Scope.

### Key Entities *(include if feature involves data)*

- **Relación Proveedor-Insumo**: ya existe (spec 106). Esta spec no cambia su modelo — solo
  empieza a leerla desde el registro de compras y a escribir en ella (último costo y fecha) desde
  ahí.
- **Línea de compra**: ya existe. Gana dos atributos de trazabilidad: la presentación elegida (si
  aplica) y la cantidad de presentaciones originalmente capturada — la cantidad y el costo que ya
  tenía siguen existiendo, pero ahora pueden ser valores *derivados* en vez de *capturados*
  directamente.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un administrador puede registrar una línea de compra indicando la presentación y
  cuántas compró, sin calcular manualmente a cuántas unidades base equivale, en menos de 1 minuto
  por línea.
- **SC-002**: El 100% de las compras registradas contra una presentación deja el stock del
  insumo exactamente igual, en unidad base, al que resultaría de calcular la conversión a mano —
  sin diferencia perceptible por redondeo en el total de la línea.
- **SC-003**: El 100% de las compras registradas contra una relación proveedor-insumo deja su
  último costo y fecha actualizados, sin ninguna acción manual adicional del administrador.
- **SC-004**: El 100% de las compras contra el proveedor de sistema "Compra ocasional", o contra
  una combinación proveedor-insumo sin presentaciones guardadas, sigue comportándose exactamente
  igual que antes de esta funcionalidad.
- **SC-005**: Un administrador puede, revisando una compra ya registrada, identificar en qué
  presentación y cantidad compró realmente cada línea, no solo su equivalencia en unidad base.

## Out of Scope

- **Conversión genérica entre unidades de medida de distinta naturaleza a la presentación** (p.
  ej. libra↔gramo como una conversión universal, independiente del proveedor) — es la
  Estrategia B de `analisis-conversion-unidades-compras.md`, que además exige completar la
  anomalía A-31 de la spec 005. Cualquier compra sin una relación proveedor-insumo que ya cubra
  la presentación necesaria sigue requiriendo cálculo manual, igual que hoy.
- **Crear o editar relaciones proveedor-insumo desde el formulario de compra**: si la
  presentación que se necesita todavía no existe, se crea antes desde la pestaña
  "Proveedores"/"Insumos que vende" (spec 106) — esta spec no agrega un acceso directo para
  crearla desde el formulario de compra.
- **Cambiar qué significa el último costo del insumo** (RN-INV-16/17 de la spec 005: se
  sobrescribe con la compra más reciente, nunca se promedia) — esta spec no cambia esa regla,
  solo cambia de dónde puede venir el valor que la aplica.

## Assumptions

- **El redondeo del costo por unidad base usa el mismo criterio que la spec 106** (2 decimales,
  redondeo estándar) para que la equivalencia que se ve en "Proveedores" y el costo que de verdad
  se aplicó en la compra nunca se vean distintos.
- **No se agrega ninguna presentación nueva desde el formulario de compra**: si la combinación
  proveedor+insumo+presentación que se necesita no existe todavía, el administrador la crea antes
  desde la pestaña correspondiente (spec 106) — esta spec solo la consume, no la gestiona.
- **Permisos**: misma regla que la spec 106 — gestionar compras requiere el mismo nivel de
  permiso que el resto de la administración de inventario (administrador o rol equivalente).
