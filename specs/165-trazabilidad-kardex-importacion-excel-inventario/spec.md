# Feature Specification: Trazabilidad de kardex en la importación masiva de Excel de inventario

**Feature Branch**: `165-trazabilidad-kardex-importacion-excel-inventario`

**Created**: 2026-11-24

**Status**: Draft

**Input**: Análisis de falencias de inventario (`analisis-falencias-inventario.md`, sección 2.10): la importación masiva de Excel de inventario (specs 109/139/142) sobrescribe `current_stock` y `unit_cost` directamente al crear o actualizar un insumo, sin pasar por el kardex (`record_movement`/`apply_adjustment`, spec 005), que es la única vía documentada como legítima para mutar stock. Esta spec cierra esa laguna solo para el Stock; el Costo queda explícitamente fuera de alcance (ver sección "Relación con specs existentes").

## Relación con specs existentes

Esta spec **no reemplaza** ninguna de las siguientes; todos sus requisitos siguen vigentes salvo lo que se precisa aquí:

- **`005-kardex-compras-conversion`**: se extiende el catálogo de motivos canónicos de RN-INV-13 con un séptimo motivo, `importacion_masiva`, aplicable únicamente a movimientos `in` y `ajuste` (nunca `out`). No se requiere `CheckConstraint` en base de datos, consistente con RN-INV-12 (el catálogo ya es una convención de capa de aplicación, no una restricción de esquema).
- **`109-inventario-excel-masivo`**: se precisa FR-007 (creación/actualización de insumos por código coincidente/no coincidente). A partir de esta spec, tanto la creación como la actualización deben originar el cambio de stock a través de un movimiento de kardex, nunca mediante escritura directa de `current_stock`.
- **`139-simplificar-columnas-excel-inventario`** y **`142-mejoras-filtros-excel-inventario`**: sin cambios. El comportamiento de la columna Costo que estas specs documentan (sobrescritura directa de `unit_cost`, tanto en creación como en actualización) se mantiene exactamente igual; se reafirma explícitamente en el FR-009 de esta spec para que no quede ambigüedad.
- **`163-compra-sugerida-registro-inventario`**: precedente directo de redacción — esa spec corrigió el mismo tipo de laguna (una vía de entrada de stock, la compra sugerida, que no generaba movimiento de kardex) y esta spec sigue el mismo patrón: el stock nunca se escribe directo, siempre es el efecto de un movimiento con referencia identificable a su origen.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Stock inicial de un insumo nuevo creado por Excel (Priority: P1)

Al importar un Excel que crea un insumo nuevo con una cantidad de Stock, ese stock inicial debe quedar registrado como un movimiento de entrada en el kardex del insumo, con el mismo nivel de trazabilidad que cualquier otra entrada de stock del sistema.

**Why this priority**: es el caso más frecuente de uso del flujo (alta inicial de catálogo) y el de mayor impacto si queda sin trazabilidad — un insumo nuevo "aparece" con stock sin ningún movimiento que lo explique.

**Independent Test**: importar un Excel con un insumo de código no existente y Stock = 50; verificar que el insumo queda creado con `current_stock = 50` **y** que existe un movimiento de kardex tipo `in`, cantidad 50, motivo `importacion_masiva`, referenciado al job de importación.

**Acceptance Scenarios**:

1. **Given** un Excel con una fila de código nuevo y Stock = 50, **When** se procesa esa fila del job de importación, **Then** se crea el insumo y se registra un movimiento `in` de cantidad 50, motivo `importacion_masiva`, con referencia al job de importación.
2. **Given** un Excel con una fila de código nuevo y Stock = 0, **When** se procesa esa fila, **Then** se crea el insumo con `current_stock = 0` y **no** se registra ningún movimiento de kardex (evitar movimientos de magnitud cero).

---

### User Story 2 - Ajuste de stock al actualizar un insumo existente por Excel (Priority: P1)

Al importar un Excel que actualiza un insumo ya existente (código coincidente) y la columna Stock trae un valor distinto al stock actual, la diferencia debe quedar registrada como un ajuste de kardex, no como una sobrescritura directa.

**Why this priority**: es el caso de la laguna original detectada — sin esto, reimportar un Excel desactualizado puede pisar el stock real sin dejar rastro, generando descuadres irrastreables entre "stock según kardex" y "stock según el último Excel subido".

**Independent Test**: con un insumo existente con `current_stock = 30`, importar un Excel con el mismo código y Stock = 45; verificar que el stock resultante es 45 y que existe un movimiento `ajuste` de +15, motivo `importacion_masiva`, referenciado al job.

**Acceptance Scenarios**:

1. **Given** un insumo existente con `current_stock = 30`, **When** se procesa una fila con el mismo código y Stock = 45, **Then** se registra un ajuste de +15 (tipo `ajuste`, motivo `importacion_masiva`, referencia al job), y el stock resultante del insumo es 45.
2. **Given** un insumo existente con `current_stock = 30`, **When** se procesa una fila con el mismo código y Stock = 30 (sin cambio), **Then** no se registra ningún movimiento de kardex para ese insumo.
3. **Given** un insumo existente con `current_stock = 30`, **When** se procesa una fila con el mismo código y Stock = 10, **Then** se registra un ajuste de -20 (tipo `ajuste`, motivo `importacion_masiva`, referencia al job), y el stock resultante del insumo es 10.

---

### User Story 3 - Fila rechazada cuando el ajuste dejaría stock negativo (Priority: P2)

Si el ajuste calculado a partir del Excel dejaría el stock resultante en negativo, la fila debe rechazarse de forma individual (como cualquier otra fila inválida del job), sin bloquear el resto de la importación.

**Why this priority**: protege la invariante ya vigente de que el stock nunca queda negativo (spec 005, `apply_adjustment` nunca lo permite), extendiéndola correctamente al nuevo camino de entrada que agrega esta spec.

**Independent Test**: con un insumo existente con `current_stock = 5`, importar un Excel con el mismo código y Stock = -3 (o cualquier valor que, combinado con otra regla, produjera un ajuste que dejara el stock negativo); verificar que la fila se reporta como fallida en el resumen de errores y que el stock del insumo no cambia.

**Acceptance Scenarios**:

1. **Given** un insumo existente con `current_stock = 5`, **When** se procesa una fila cuyo ajuste resultante dejaría el stock en negativo, **Then** la fila se reporta como fallida en el resumen de errores del job, el insumo no se modifica, y el resto de las filas del Excel se sigue procesando con normalidad.

---

### Edge Cases

- Un insumo creado y actualizado por la **misma fila** en el mismo job (no aplica: cada fila de código distinto es una entidad distinta; una fila solo crea o solo actualiza, nunca ambas).
- Reintento de una importación tras interrupción: si el mismo archivo se reimporta y el ajuste ya fue aplicado (stock ya coincide con el Excel), la segunda pasada no debe generar un ajuste duplicado — se resuelve de forma natural por la regla "delta = 0 → sin movimiento" (User Story 2, escenario 2).
- Varias filas de insumos distintos en el mismo job: cada ajuste/movimiento se calcula y registra de forma independiente por fila, consistente con el procesamiento fila-a-fila ya vigente en la spec 109.
- Columna Stock vacía o no numérica en una fila de actualización: sigue la validación ya vigente de la spec 109 (fila fallida por dato inválido); no se intenta ningún ajuste.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST registrar, para cada insumo **creado** mediante la importación masiva de Excel con un valor de Stock mayor a 0, un movimiento de inventario tipo `in` por esa cantidad, con motivo `importacion_masiva` y una referencia (tipo y valor) al job de importación que lo originó.
- **FR-002**: El sistema MUST NOT registrar ningún movimiento de inventario cuando el insumo se crea con Stock = 0.
- **FR-003**: El sistema MUST calcular, para cada insumo **actualizado** (código coincidente con uno existente) mediante la importación masiva, la diferencia entre el valor de Stock de la fila del Excel y el stock actual del insumo en el momento de procesar esa fila.
- **FR-004**: Si esa diferencia es distinta de cero, el sistema MUST registrar un movimiento de inventario tipo `ajuste` por el valor de esa diferencia (con signo), con motivo `importacion_masiva` y referencia al job de importación, usando el mismo mecanismo (`apply_adjustment`) que gobierna cualquier otro ajuste manual de stock del sistema — nunca mediante escritura directa de `current_stock`.
- **FR-005**: El sistema MUST NOT registrar ningún movimiento cuando la diferencia calculada en FR-003 es cero.
- **FR-006**: Si el ajuste calculado en FR-004 dejaría el stock resultante del insumo en negativo, el sistema MUST rechazar esa fila específica, reportándola como fallida en el resumen de errores del job, sin modificar el insumo y sin bloquear el procesamiento de las demás filas — consistente con la validación fila a fila ya vigente (spec 109).
- **FR-007**: El sistema MUST extender el catálogo de motivos canónicos de la spec 005 agregando `importacion_masiva` como un séptimo motivo válido, restringido a movimientos de tipo `in` o `ajuste` (nunca `out`).
- **FR-008**: El sistema MUST mostrar estos movimientos (los de FR-001 y FR-004) en el historial de movimientos del insumo correspondiente, igual que cualquier otro movimiento, de forma que se pueda distinguir que su origen fue una importación masiva (vía el motivo `importacion_masiva` y la referencia al job).
- **FR-009**: El sistema MUST mantener sin cambios el comportamiento ya vigente de la columna Costo: en creación y en actualización, el valor de Costo de la fila del Excel sigue sobrescribiendo directamente el `unit_cost` del insumo, sin generar ningún movimiento de kardex — el costo es un atributo del insumo, no una cantidad de stock, y por tanto no pasa por el mecanismo de movimientos.

### Key Entities

- **Movimiento de inventario** (entidad ya existente, spec 005): se reutiliza sin cambios de forma; esta spec solo agrega un valor válido nuevo a su campo `reason` (`importacion_masiva`) y usa su mecanismo de referencia ya existente (tipo + id) para apuntar al job de importación en lugar de a una orden de compra o una venta.
- **Job de importación** (entidad ya existente, spec 109): sin cambios; pasa a ser también el origen citado en la referencia de los movimientos que genera.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100% de los insumos creados o actualizados por una importación masiva de Excel con un cambio real de stock (delta ≠ 0) quedan con un movimiento de kardex rastreable que explica ese cambio.
- **SC-002**: El 0% de las filas sin cambio de stock (delta = 0, o Stock = 0 en creación) genera un movimiento de kardex espurio.
- **SC-003**: El 100% de los ajustes que dejarían el stock en negativo se rechazan a nivel de fila individual, sin afectar el resto del job.

## Assumptions

- El mecanismo de referencia (tipo + id) de los movimientos de inventario, ya usado para vincular movimientos a órdenes de compra (spec 163), admite agregar el job de importación como un tipo de origen más, sin requerir una migración de esquema distinta a agregar el valor del motivo.
- El alcance de esta spec es exclusivamente la importación de **inventario de insumos** (specs 109/139/142); no aplica a la exportación/importación de **carta/menú** (specs 143/155), que no maneja stock ni kardex.
- La columna Costo queda fuera de alcance de forma deliberada (FR-009): no se le exige ningún registro histórico ni trazabilidad adicional en esta spec.
