# Feature Specification: Rediseño visual de Ajustes + grupos de unidades de medida

**Feature Branch**: `137-rediseno-ajustes`

**Created**: 2026-10-26

**Status**: Draft

**Input**: User description: "necesito que rediseñes la vista de ajustes actual y usando la skill de frontend-design vas a implementar el diseño design/ajustes.html — antes de analizar el diseño vas a verificar que si hay alguna funcionalidad nueva o ajuste en el modelo de datos que requiera decisión y me vas a preguntar antes de tomar acción"

## Contexto y alcance

Esta spec cubre dos cosas distintas que aparecen juntas en `design/ajustes.html`:

1. **Rediseño puramente visual** de las pestañas "Información básica", "Métodos de pago" y "Grupos de opciones": mismos campos, mismas reglas de negocio, mismos endpoints — solo cambia la presentación (layout, tipografía, componentes) siguiendo el nuevo diseño.
2. **Funcionalidad nueva** en la pestaña "Unidades de medida": el diseño agrupa las unidades en "grupos" con una "unidad base" fija, algo que el modelo actual del backend no soporta explícitamente (hoy `dimension` es un texto libre por unidad, sin unidad base designada). Tras análisis y decisión del usuario, esta spec formaliza esos grupos como entidad propia.

Explícitamente **fuera de alcance** (decisión del usuario):

- Historial de cambios de factor consolidado por grupo (tabla "Historial de cambios" del diseño) — no se implementa en esta spec.
- Borrado físico ("hard delete") de unidades de medida — se mantiene el comportamiento actual de solo desactivar (soft-delete). El ícono de eliminar del diseño se mapea a la acción de desactivar ya existente.
- Cualquier cambio a la lógica de conversión de unidades en compras (spec 134) distinta de la que surge de formalizar el grupo — `app/core/units.py::convert()` sigue funcionando igual (misma `dimension`, mismo `factor_to_base`).

## Clarifications

### Session 2026-10-26

- Q: Al reasignar cuál unidad es la base de un grupo, ¿el sistema debe bloquear esa reasignación si alguna unidad del grupo ya está en uso por un insumo o una compra, o debe permitirla siempre? → A: Se bloquea si alguna unidad del grupo está en uso (igual que el diseño); el administrador debe resolver primero el uso antes de poder reasignar la base.
- Q: ¿El nombre (y la abreviatura) de una unidad de medida debe ser único solo dentro de su grupo, o único en todo el tenant como hoy? → A: Único en todo el tenant, igual que hoy — ningún nombre/abreviatura se repite entre unidades sin importar el grupo.
- Q: El formulario de unidades del diseño solo muestra "Nombre de la unidad" (sin campo de abreviatura); ¿se mantiene `abreviatura` como campo propio en el formulario nuevo, o se elimina/oculta? → A: Se mantiene `abreviatura` como campo propio y visible en el formulario de crear/editar unidad, aunque el diseño de referencia no lo muestre explícitamente.
- Q: ¿Se debe bloquear el renombrar una unidad (no base) mientras esté en uso por un insumo o una compra, o se permite renombrarla siempre como hoy? → A: Se bloquea mientras esté en uso (igual que el diseño); el sistema explica que está en uso en compras y no se puede renombrar.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ajustes con el nuevo diseño visual (Priority: P1)

Como administrador del negocio, al entrar a Ajustes veo la información básica, los métodos de pago y los grupos de opciones con el nuevo diseño visual, sin que cambie ningún dato ni comportamiento que ya usaba.

**Why this priority**: Es el pedido principal del usuario y no implica riesgo de datos — es la base visual sobre la que se apoya todo lo demás.

**Independent Test**: Abrir cada pestaña rediseñada (Información básica, Métodos de pago, Grupos de opciones), confirmar que los mismos campos/acciones de hoy siguen funcionando (guardar logo, mensaje de recibo, ancho de rollo, activar método de pago, crear/editar grupo de opciones) con la apariencia nueva.

**Acceptance Scenarios**:

1. **Given** un tenant con logo, mensaje de recibo y conversión de unidades configurados, **When** el administrador abre "Información básica" rediseñada, **Then** ve los mismos valores guardados y puede editarlos igual que antes.
2. **Given** métodos de pago ya activados, **When** el administrador abre "Métodos de pago" rediseñada, **Then** puede activar/editar/desactivar un método sin que cambien los datos ni las reglas de validación existentes.
3. **Given** grupos de opciones existentes, **When** el administrador abre "Grupos de opciones" rediseñada, **Then** puede crear, editar, activar/desactivar y eliminar definitivamente un grupo u opción igual que antes.

---

### User Story 2 - Agrupar unidades de medida con una unidad base (Priority: P1)

Como administrador, quiero organizar las unidades de medida en grupos (ej. "Masa": gramos, kilogramos) y que cada grupo tenga una unidad base clara que no se pueda editar ni eliminar por accidente, para que la conversión de unidades en compras (spec 134) sea confiable y fácil de auditar visualmente.

**Why this priority**: El diseño ya asume esta estructura; sin ella la pestaña "Unidades de medida" no se puede implementar fielmente y el concepto de "unidad base" quedaría ambiguo (riesgo de que alguien edite o desactive la unidad equivocada y rompa conversiones ya usadas en compras).

**Independent Test**: Crear un grupo nuevo con su unidad base, agregar una segunda unidad al grupo con su factor de conversión, confirmar que la unidad base no se puede editar ni desactivar, y que las conversiones de compras (spec 134) siguen funcionando igual.

**Acceptance Scenarios**:

1. **Given** no existe el grupo "Volumen", **When** el administrador crea el grupo indicando nombre y unidad base (ej. "Mililitro"), **Then** el sistema crea la unidad base con `factor_to_base = 1` marcada como base, y el grupo aparece en la lista con esa única unidad.
2. **Given** el grupo "Volumen" con unidad base "Mililitro", **When** el administrador agrega la unidad "Litro" con factor 1000, **Then** la nueva unidad queda asociada al mismo grupo, no marcada como base, y disponible para comprar insumos en esa presentación.
3. **Given** una unidad marcada como base, **When** el administrador intenta editar su factor o desactivarla/eliminarla, **Then** el sistema lo impide y explica que primero debe elegir otra unidad base del grupo.
4. **Given** un grupo con más de una unidad y ninguna de ellas en uso por un insumo o una compra, **When** el administrador reasigna cuál unidad es la base, **Then** la unidad anterior deja de ser base (y vuelve a ser editable/desactivable) y la nueva unidad base pasa a tener las restricciones del punto 3.
5. **Given** un grupo donde al menos una unidad (base o no) está en uso por un insumo o una compra, **When** el administrador intenta reasignar la base del grupo, **Then** el sistema lo impide y explica qué unidades están en uso y bloquean el cambio.
6. **Given** un grupo con una sola unidad (la base), **When** el administrador intenta eliminar el grupo completo, **Then** el sistema lo permite solo si ninguna de sus unidades está en uso por un insumo o una compra existente; si está en uso, explica cuáles unidades lo bloquean.
7. **Given** unidades de medida creadas antes de esta spec (con `dimension` como texto libre), **When** se despliega esta funcionalidad, **Then** cada valor distinto de `dimension` se migra automáticamente a un grupo con ese nombre, y la unidad con `factor_to_base = 1` de cada grupo (o la primera por antigüedad si hay más de una o ninguna con factor 1) queda marcada como base.

---

### Edge Cases

- ¿Qué pasa si dos unidades del mismo grupo migrado tenían `factor_to_base = 1` antes de esta spec? Se marca como base la más antigua (`created_at` menor); queda registrado en el plan de migración para que el administrador pueda revisarlo.
- ¿Qué pasa si un grupo se queda sin unidades activas? El grupo sigue existiendo (solo se oculta si todas sus unidades están desactivadas), ya que insumos existentes pueden seguir referenciando una unidad inactiva.
- ¿Qué pasa si el administrador intenta crear un grupo con un nombre que ya existe? Se bloquea con un mensaje de error (nombre de grupo único en todo el tenant).
- ¿Qué pasa si el administrador intenta crear o renombrar una unidad con un nombre o abreviatura que ya usa otra unidad, sin importar a qué grupo pertenezca? Se bloquea con un mensaje de error — el nombre y la abreviatura de una unidad de medida son únicos en todo el tenant, igual que hoy, no solo dentro de su grupo.
- ¿Qué pasa si se intenta desactivar (no eliminar) la unidad base? Mismo bloqueo que para editar su factor o eliminarla — la unidad base no se puede desactivar mientras siga siendo la base del grupo.
- ¿Qué pasa si se intenta renombrar una unidad (base o no) que ya está en uso por un insumo o una compra? Se bloquea con un mensaje que explica que la unidad está en uso en compras y por eso no se puede renombrar.

## Requirements *(mandatory)*

### Functional Requirements

**Rediseño visual (Información básica, Métodos de pago, Grupos de opciones)**

- **FR-001**: El sistema DEBE mantener exactamente los mismos campos, validaciones y acciones que existen hoy en "Información básica" (logo, mensaje de recibo, ancho de rollo de impresión, conversión de unidades en compras), solo con la presentación visual del nuevo diseño.
- **FR-002**: El sistema DEBE mantener el flujo actual de "Métodos de pago" (catálogo del Super Admin, activación, campos dinámicos por método, activar/desactivar) sin cambios funcionales, solo con la presentación visual del nuevo diseño.
- **FR-003**: El sistema DEBE mantener el flujo actual de "Grupos de opciones" (modo conteo/cantidad, tipo de precio incluido/con recargo, vínculo a insumo, eliminación definitiva con confirmación) sin cambios funcionales, solo con la presentación visual del nuevo diseño.
- **FR-004**: La navegación entre pestañas de Ajustes DEBE seguir respetando la visibilidad por plan del tenant que ya existe hoy (p. ej. "Unidades de medida" oculta si el módulo Inventario no está incluido en el plan).

**Grupos de unidades de medida (nueva funcionalidad)**

- **FR-005**: El sistema DEBE permitir crear un grupo de unidades con un nombre único, designando una unidad de medida (con su nombre y abreviatura, ambos únicos en todo el tenant) como su unidad base en el mismo paso.
- **FR-006**: El sistema DEBE permitir agregar unidades adicionales a un grupo existente, cada una con su propio nombre y abreviatura (únicos en todo el tenant) y su propio factor de conversión hacia la unidad base del grupo.
- **FR-007**: El sistema DEBE marcar exactamente una unidad como base por grupo en todo momento.
- **FR-008**: El sistema DEBE impedir editar el factor de conversión, desactivar o eliminar la unidad marcada como base de un grupo.
- **FR-009**: El sistema DEBE permitir reasignar cuál unidad de un grupo es la base, liberando las restricciones de la unidad anterior, únicamente cuando ninguna unidad del grupo (base o no) esté en uso por un insumo o una compra existente; de lo contrario DEBE impedir la reasignación e informar cuáles unidades la bloquean.
- **FR-010**: El sistema DEBE seguir calculando conversiones entre unidades del mismo grupo con la misma fórmula que usa hoy (`factor_to_base` relativo a la base), sin cambiar su comportamiento para funcionalidad ya existente (spec 134).
- **FR-011**: El sistema DEBE permitir eliminar un grupo completo solo cuando ninguna de sus unidades esté en uso por un insumo (`InventoryItem`) o una línea de compra (`Purchase`) existente, e informar cuáles unidades lo bloquean cuando no se pueda.
- **FR-012**: El sistema DEBE migrar los valores de `dimension` existentes a grupos reales al desplegar esta funcionalidad, preservando todas las unidades, sus factores y su estado (activa/inactiva) actuales.
- **FR-013**: El sistema DEBE mantener el borrado de una unidad individual (no base) como una desactivación (soft-delete), igual que hoy — no se agrega borrado físico en esta spec.
- **FR-014**: El sistema DEBE impedir renombrar una unidad (base o no) mientras esté en uso por un insumo o una compra existente, e informar que está en uso y por eso no se puede renombrar.

### Key Entities *(include if feature involves data)*

- **Grupo de unidades (nueva entidad)**: agrupa unidades de medida convertibles entre sí (reemplaza el texto libre `dimension`). Atributos: nombre único, unidad base.
- **Unidad de medida** (existente, se ajusta): pertenece a un grupo; conserva nombre, abreviatura, factor de conversión hacia la base del grupo, estado activo/inactivo. Gana un indicador de "es la unidad base de su grupo".
- **Insumo / línea de compra** (existentes, sin cambios de esquema): siguen referenciando una unidad de medida; se usan para determinar si una unidad o grupo están "en uso" al intentar eliminarlos.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un administrador puede completar cualquier tarea que ya hacía en Ajustes (editar info básica, activar un método de pago, crear un grupo de opciones) con el nuevo diseño sin necesitar explicación adicional ni perder datos previamente guardados.
- **SC-002**: Un administrador puede crear un grupo de unidades con su unidad base y agregar al menos una unidad adicional en menos de 1 minuto, sin ayuda externa.
- **SC-003**: El 100% de las unidades de medida existentes antes del despliegue quedan correctamente agrupadas y con exactamente una unidad base por grupo tras la migración, sin que ninguna compra o insumo existente cambie de valor.
- **SC-004**: Ningún intento de editar, desactivar o eliminar la unidad base de un grupo tiene éxito mientras siga siendo la base — el sistema siempre explica por qué se bloqueó la acción.

## Assumptions

- El rediseño visual reutiliza los mismos endpoints/servicios ya existentes para Información básica, Métodos de pago y Grupos de opciones; no se crean ni modifican endpoints para esas tres pestañas.
- "En uso" para una unidad o grupo significa: referenciada por al menos un `InventoryItem.unit_measure_id` o `Purchase.unit_measure_id` existente (activo o inactivo, ya que el histórico de compras no se reescribe).
- El historial de cambios de factor por unidad individual (`GET /unit-measures/{id}/factor-changes`, spec 134) sigue existiendo tal cual; solo queda fuera de esta spec la vista consolidada por grupo que mostraba el diseño.
- La migración de `dimension` (texto libre) a grupos reales se ejecuta una sola vez al desplegar esta spec; no se requiere una herramienta de administración de migraciones aparte.
- Las reglas de acceso actuales (solo ADMIN cambia `factor_to_base`, el módulo "Unidades de medida" requiere plan con Inventario) se mantienen igual para la gestión de grupos.
