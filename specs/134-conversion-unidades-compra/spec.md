# Feature Specification: Compra de Insumos con Conversión a Unidad Base

**Feature Branch**: `[134-conversion-unidades-compra]`

**Created**: 2026-10-24

**Status**: Draft

**Input**: User description: "Como encargado de compras o inventario de un negocio, quiero registrar cada insumo en la unidad en que me lo factura el proveedor (KG, LB, etc.), para que el sistema actualice el stock y el costo en la unidad base del insumo sin que yo tenga que hacer cálculos manuales ni cometer errores de conversión."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Registrar una compra en la unidad del proveedor (Priority: P1)

Como encargado de compras, al registrar una línea de compra de un insumo quiero elegir la
unidad en que el proveedor me factura (por ejemplo KG o LB) e ingresar la cantidad y el
costo en esa unidad, para que el sistema calcule automáticamente cuánto stock entra y a qué
costo unitario queda valorado el insumo en su unidad base (por ejemplo gramos), sin que yo
tenga que hacer la conversión a mano.

**Why this priority**: Es el núcleo del problema de negocio descrito: hoy la conversión
manual expone al encargado a errores de cálculo que descuadran el stock y el costo
promedio del insumo. Sin esta capacidad no hay funcionalidad que entregar.

**Independent Test**: Se puede probar registrando y confirmando una compra de un insumo en
una unidad distinta a su unidad base, y verificando que el stock del insumo aumentó en la
cantidad correcta expresada en unidad base, y que el costo unitario base calculado es el
esperado.

**Acceptance Scenarios**:

1. **Given** el insumo "Azúcar" tiene unidad base "g" (grupo "Masa"), la unidad "KG" está
   activa en ese grupo con factor 1000, y el stock actual es 500 g, **When** el encargado
   registra una compra de 2 KG a $8.000 por KG y confirma el documento, **Then** el stock de
   "Azúcar" queda en 2.500 g, la línea de compra guarda unidad "KG", factor 1000, cantidad
   2, cantidad base 2000, y el costo unitario base calculado es $8 por g.
2. **Given** la unidad "LB" está activa en el grupo "Masa" con factor 453,592 y el stock de
   "Azúcar" es 0 g, **When** el encargado registra y confirma una compra de 3 LB, **Then**
   el stock de "Azúcar" queda en 1.360,776 g, sin pérdida de precisión por redondeo en la
   cantidad almacenada.
3. **Given** el encargado está registrando una línea de compra, **When** selecciona la
   unidad "KG" e ingresa la cantidad 2 antes de confirmar, **Then** ve junto a la línea el
   texto "= 2.000 g" como vista previa de la equivalencia, y el stock del insumo no cambia
   hasta que confirme el documento.
4. **Given** el encargado ingresa una cantidad de 0 o negativa en una línea con unidad
   "KG", **When** intenta confirmar el documento, **Then** el sistema muestra el mensaje
   "La cantidad debe ser mayor que cero" y no permite confirmar el documento.

---

### User Story 2 - Elegir solo unidades válidas para el insumo (Priority: P2)

Como encargado de compras, al abrir el selector de unidad en una línea de compra quiero ver
únicamente las unidades que pertenecen al mismo grupo de medida que la unidad base del
insumo y que están activas, para no poder seleccionar por error una unidad incompatible
(por ejemplo volumen para un insumo que se mide en masa) ni una unidad que el negocio ya
dejó de usar.

**Why this priority**: Previene errores de captura que generarían cantidades y costos sin
sentido en el stock. Depende de que exista la funcionalidad de compra (US1), pero es
necesaria para que esa funcionalidad sea segura de usar.

**Independent Test**: Se puede probar abriendo el selector de unidad de dos insumos con
unidades base de distinto grupo y verificando que cada uno solo ofrece las unidades de su
propio grupo; y desactivando una unidad y verificando que deja de aparecer en el selector.

**Acceptance Scenarios**:

1. **Given** el insumo "Leche" tiene unidad base "ml" del grupo "Volumen", **When** el
   encargado abre el selector de unidad en su línea de compra, **Then** no aparecen "KG" ni
   "LB" (unidades del grupo "Masa").
2. **Given** una solicitud de compra llega con una unidad que pertenece a un grupo distinto
   al de la unidad base del insumo, **When** el sistema valida la línea, **Then** responde
   con un error de validación y no registra la línea, incluso si la solicitud no pasó por la
   pantalla de selección.
3. **Given** la unidad "LB" fue desactivada, **When** el encargado registra una nueva compra
   de "Azúcar", **Then** "LB" no aparece en el selector de unidades disponibles.
4. **Given** el negocio tiene la conversión de unidades desactivada, **When** el encargado
   registra una compra de "Azúcar", **Then** la única unidad disponible es la unidad base
   del insumo, "g".

---

### User Story 3 - Conservar el historial de compras frente a cambios posteriores (Priority: P3)

Como encargado de compras o como auditor del negocio, quiero que cada línea de compra
conserve exactamente la unidad, el factor y las cantidades con que fue registrada, y que al
anular una compra el stock se revierta usando esos mismos valores guardados, para que el
historial de movimientos sea confiable incluso si más adelante alguien cambia el factor de
conversión de una unidad.

**Why this priority**: Es una garantía de integridad de datos a lo largo del tiempo. No
bloquea el uso básico de la funcionalidad (US1 y US2 ya entregan valor por sí solas), pero
es indispensable antes de que el negocio pueda confiar en su kardex histórico.

**Independent Test**: Se puede probar confirmando una compra, cambiando después el factor de
la unidad usada, y verificando que la compra ya confirmada conserva su factor y cantidad
base originales; y anulando una compra confirmada y verificando que el stock se revierte
exactamente en la cantidad base que esa compra tenía guardada.

**Acceptance Scenarios**:

1. **Given** existe una compra confirmada de 2 KG de "Azúcar" con factor 1000 (cantidad base
   2000 g), **When** un administrador cambia el factor de conversión de "KG", **Then** la
   compra existente conserva factor 1000 y cantidad base 2000, y queda registro de quién
   cambió el factor y cuándo.
2. **Given** existe una compra confirmada de 2 KG (2000 g) de "Azúcar" y el stock actual es
   2.500 g, **When** el encargado anula esa compra, **Then** el stock queda en 500 g,
   calculado restando la cantidad base que la línea tenía guardada, sin recalcular con el
   factor vigente en ese momento.

---

### Edge Cases

- ¿Qué pasa si el insumo todavía no tiene ninguna unidad activa configurada en su grupo
  además de la unidad base? El selector solo debe ofrecer la unidad base.
- ¿Qué pasa si se intenta cambiar la unidad base de un insumo que ya tiene movimientos de
  compra registrados? La operación debe rechazarse (RN1).
- ¿Qué pasa si dos compras del mismo insumo se confirman simultáneamente? El aumento de
  stock y el recálculo de costo promedio deben quedar correctos para ambas sin que una
  sobrescriba el efecto de la otra (actualización atómica).
- ¿Qué pasa si se anula una compra dos veces o se anula una compra que ya fue anulada? La
  segunda anulación debe rechazarse para no revertir el stock dos veces.
- ¿Qué pasa si el costo de compra ingresado es 0 o negativo? Debe tratarse como entrada
  inválida de la misma forma que una cantidad inválida.
- ¿Qué pasa con unidades o grupos de un negocio cuando se consultan desde otro negocio? No
  deben ser visibles ni seleccionables (RN8, aislamiento por negocio).

## Clarifications

### Session 2026-10-24

- Q: ¿Con cuántos decimales se debe almacenar la cantidad en unidad base y el costo en
  unidad base para que no se pierda precisión por redondeo (como exige SC-001)? → A: 6
  decimales.
- Q: ¿Qué debe pasar con las líneas de compra registradas antes de que existieran los
  campos de unidad, factor y cantidad base? → A: Se les asigna por defecto la unidad base
  del insumo con factor 1 y cantidad base igual a la cantidad original ya registrada,
  preservando el stock existente sin alterarlo.
- Q: ¿Qué rol debe estar autorizado para cambiar el factor de conversión de una unidad? →
  A: Solo el administrador del negocio (tenant).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST permitir asignar a cada insumo una única unidad base,
  perteneciente a un grupo de medida (p. ej. "Masa", "Volumen").
- **FR-002**: El sistema MUST impedir cambiar la unidad base de un insumo una vez que el
  insumo tiene al menos un movimiento de inventario registrado.
- **FR-003**: El sistema MUST ofrecer, en el selector de unidad de una línea de compra,
  únicamente las unidades activas que pertenezcan al mismo grupo de medida que la unidad
  base del insumo.
- **FR-004**: El sistema MUST rechazar, con un error de validación, cualquier línea de
  compra cuya unidad no pertenezca al mismo grupo que la unidad base del insumo, sin
  registrar esa línea.
- **FR-005**: El sistema MUST excluir del selector de unidades cualquier unidad que haya
  sido desactivada, sin afectar las compras ya registradas que la usaron.
- **FR-006**: El sistema MUST calcular la cantidad en unidad base de cada línea de compra
  como el producto de la cantidad ingresada por el factor de conversión de la unidad
  elegida, y aumentar el stock del insumo exactamente en esa cantidad base al confirmar el
  documento.
- **FR-007**: El sistema MUST calcular el costo unitario en unidad base de cada línea como
  el costo unitario de compra dividido entre el factor de conversión, y usar ese costo base
  para recalcular el costo promedio del insumo.
- **FR-008**: El sistema MUST resolver el factor de conversión a partir de la unidad
  seleccionada en el servidor al momento de confirmar, sin aceptar un factor provisto
  externamente en la solicitud.
- **FR-009**: El sistema MUST guardar en cada línea de compra, de forma inmutable una vez
  confirmada, al menos: la unidad de compra, el factor aplicado, la cantidad original
  ingresada, la cantidad en unidad base resultante, el costo unitario original y el costo
  unitario en unidad base. La cantidad en unidad base y el costo en unidad base se
  almacenan con precisión de 6 decimales, de modo que no se pierda precisión por redondeo
  (SC-001).
- **FR-010**: El sistema MUST mantener sin alteración las líneas de compra ya confirmadas
  cuando el factor de conversión de una unidad cambie después, de modo que el historial
  conserve el factor y las cantidades con que se registró cada compra.
- **FR-011**: El sistema MUST registrar quién cambió el factor de conversión de una unidad
  y cuándo, de forma consultable.
- **FR-011a**: El sistema MUST permitir cambiar el factor de conversión de una unidad
  únicamente al administrador del negocio (tenant), rechazando el intento de cualquier otro
  rol.
- **FR-012**: El sistema MUST, al anular una compra confirmada, disminuir el stock del
  insumo exactamente en la cantidad base que esa línea tenía guardada, sin recalcular esa
  cantidad con el factor de conversión vigente al momento de la anulación.
- **FR-013**: El sistema MUST impedir anular una misma compra más de una vez.
- **FR-014**: El sistema MUST mostrar, antes de confirmar el documento, una vista previa de
  la equivalencia en unidad base y del costo resultante por unidad base para cada línea de
  compra, sin modificar el stock hasta que el documento se confirme.
- **FR-015**: El sistema MUST rechazar, con un mensaje de error indicando que la cantidad
  debe ser mayor que cero, cualquier línea de compra con cantidad igual o menor a cero, e
  impedir confirmar el documento mientras exista una línea así.
- **FR-016**: El sistema MUST, cuando el negocio tenga desactivada la conversión de
  unidades, restringir la unidad seleccionable en toda línea de compra a la unidad base del
  insumo.
- **FR-017**: El sistema MUST mantener los grupos de medida, las unidades y sus factores de
  conversión aislados por negocio, de modo que las unidades y factores de un negocio nunca
  sean visibles ni utilizables por otro.
- **FR-018**: El sistema MUST mostrar el stock del insumo en inventario siempre expresado en
  su unidad base.
- **FR-019**: El sistema MUST permitir desactivar una unidad que ya fue usada en al menos
  una línea de compra, pero MUST impedir eliminarla mientras tenga uso registrado.
- **FR-020**: El sistema MUST actualizar el stock de forma que compras simultáneas del mismo
  insumo no se pisen entre sí (cada aumento de stock se aplica de forma completa e
  independiente de los demás).
- **FR-021**: El sistema MUST asignar, a toda línea de compra registrada antes de que
  existieran los campos de unidad, factor y cantidad base de esta especificación, la
  unidad base del insumo con factor 1 y una cantidad base igual a la cantidad original ya
  registrada, sin alterar el stock ya existente.

### Key Entities *(include if feature involves data)*

- **Grupo de medida**: Agrupa unidades que son convertibles entre sí (p. ej. "Masa",
  "Volumen"). Pertenece a un único negocio.
- **Unidad**: Unidad de medida concreta (p. ej. "g", "KG", "LB"), perteneciente a un grupo
  de medida y a un negocio, con un factor de conversión hacia la unidad base de su grupo y
  un estado activo/inactivo. Puede desactivarse pero no eliminarse si ya tiene uso
  registrado.
- **Insumo**: Artículo de inventario con una unidad base única, perteneciente a un grupo de
  medida, y un stock y costo promedio expresados siempre en esa unidad base.
- **Línea de compra**: Registro de la compra de un insumo en una unidad y cantidad
  determinadas. Guarda de forma inmutable la unidad, el factor aplicado, la cantidad
  original, la cantidad en unidad base, el costo original y el costo en unidad base.
  Pertenece a un documento de compra y a un negocio.
- **Cambio de factor**: Registro histórico de modificaciones al factor de conversión de una
  unidad, con quién lo hizo y cuándo.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100% de las compras registradas en una unidad distinta a la unidad base
  del insumo reflejan en el stock la cantidad en unidad base correcta, sin ninguna
  diferencia atribuible a redondeo.
- **SC-002**: El encargado de compras puede registrar y confirmar una compra con conversión
  de unidad sin realizar ningún cálculo manual de cantidad o costo fuera del sistema.
- **SC-003**: El 100% de las líneas de compra confirmadas conservan, meses después y aunque
  el factor de conversión de la unidad usada haya cambiado, exactamente la cantidad base y
  el costo base con que fueron registradas originalmente.
- **SC-004**: El 100% de las anulaciones de compras con conversión revierten el stock a la
  cifra exacta previa a la compra, sin desviaciones.
- **SC-005**: El selector de unidad nunca ofrece al encargado una unidad incompatible con el
  insumo que está comprando, eliminando por diseño la clase de error de "unidad
  equivocada".

## Assumptions

- La configuración de grupos de medida y de unidades (nombres, factores, estado
  activo/inactivo) ya existe o se gestiona como parte de otra funcionalidad de catálogo; esta
  especificación asume que esas entidades están disponibles y se enfoca en su uso durante el
  registro y anulación de compras.
- El indicador de "conversión de unidades activa/desactivada" es una configuración a nivel
  de negocio (tenant) que ya existe o se gestiona por fuera de esta especificación.
- "Confirmar el documento" se refiere al paso que vuelve definitiva una compra y dispara la
  actualización de stock y costo; los estados previos (borrador, vista previa) no afectan
  inventario.
- El formato de presentación numérica (separador de miles con punto, decimales con coma,
  p. ej. "453,592 g") es una convención de visualización y no altera los valores
  almacenados internamente.
- La precarga de la última unidad usada por insumo y proveedor, mencionada como posible
  mejora de UX, queda fuera del alcance de esta especificación por no tener aún validación
  con usuarios reales; puede abordarse en una iteración posterior si el negocio lo decide.
- Mostrar el stock en una unidad alternativa a la unidad base (p. ej. "2,5 KG") en pantallas
  de inventario queda fuera de alcance de esta especificación.
