# Feature Specification: Eliminar columna `dimension` en unidades de medida

**Feature Branch**: `139-eliminar-dimension-unit-measures`

**Created**: 2026-10-26

**Status**: Draft

**Input**: User description: "Eliminar la columna `dimension` (texto libre) de la tabla `unit_measures`, dejando `group_id` → `unit_measure_groups` como única fuente de verdad para el grupo/dimensión de una unidad de medida. La spec 135 introdujo `dimension` como columna plana. La spec 137 creó `UnitMeasureGroup` como relación real (`group_id`), pero mantuvo `dimension` como columna espejo sincronizada en cada escritura, solo para no modificar `convert()`. Esta spec cierra esa deuda técnica aceptada: `convert()` deja de comparar `.dimension` y pasa a comparar `group_id`; se elimina la columna `dimension` vía migración (con downgrade que la recompone desde `group.name`); se elimina el campo `dimension` de la respuesta de la API y el query param `?dimension=`; se eliminan los 4 puntos de escritura/sincronización en el backend; y en el frontend se actualiza el único consumidor real (`purchase-form.component.ts`) para comparar por `group_id` en vez de `dimension`. Fuera de alcance: cambios al modelo `UnitMeasureGroup` en sí."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Renombrar un grupo de medida sin inconsistencias (Priority: P1)

Como administrador del catálogo, cuando renombro un grupo de unidades de medida (p. ej. de "Masa" a "Peso"), espero que esa sea la única fuente de verdad del sistema: no debe quedar ningún campo residual en las unidades individuales que conserve el nombre anterior o que dependa de una sincronización manual/automática independiente para reflejar el cambio.

**Why this priority**: Es la causa raíz del problema reportado: hoy existen dos lugares (`dimension` en la unidad y `name` en el grupo) que almacenan el mismo dato y deben mantenerse sincronizados en cada escritura, lo cual es una fuente de inconsistencia y de código muerto.

**Independent Test**: Renombrar un grupo de medida vía la API/UI de administración y confirmar que ninguna unidad de medida expone un campo `dimension` divergente del nombre del grupo (porque el campo deja de existir).

**Acceptance Scenarios**:

1. **Given** un grupo de medida "Masa" con varias unidades asociadas, **When** se renombra el grupo a "Peso", **Then** el sistema no requiere actualizar ningún campo adicional en las unidades miembro porque el nombre del grupo vive en un único lugar.
2. **Given** la respuesta de la API de unidades de medida, **When** se consulta una unidad, **Then** la respuesta ya no incluye un campo de texto libre redundante con el nombre de su grupo; el grupo se identifica por su relación (`group_id`).

---

### User Story 2 - Conversión entre unidades sigue validando compatibilidad (Priority: P1)

Como usuario que registra una compra con una unidad distinta a la unidad base de un insumo, espero que el sistema siga impidiendo conversiones entre unidades de grupos incompatibles (p. ej. convertir litros a gramos), exactamente igual que antes del cambio.

**Why this priority**: Es la única lógica de negocio real que depende del dato eliminado; si se rompe, se pierde una validación crítica de integridad de inventario.

**Independent Test**: Intentar convertir una cantidad entre dos unidades de grupos distintos y confirmar que el sistema rechaza la operación con un mensaje claro, igual que en el comportamiento actual.

**Acceptance Scenarios**:

1. **Given** dos unidades de medida que pertenecen a grupos distintos (p. ej. "Volumen" y "Masa"), **When** se intenta convertir una cantidad de una a otra, **Then** el sistema rechaza la operación indicando que las unidades son incompatibles.
2. **Given** dos unidades de medida que pertenecen al mismo grupo, **When** se convierte una cantidad entre ellas, **Then** el resultado es idéntico al que producía el sistema antes de este cambio.

---

### User Story 3 - Filtrar unidades de medida por grupo (Priority: P2)

Como usuario que gestiona unidades de medida, al buscar o filtrar unidades necesito poder acotarlas por su grupo de medida, usando el identificador del grupo en lugar de un texto libre que podía quedar desincronizado.

**Why this priority**: Preserva una funcionalidad existente de filtrado, pero consolidada en el mecanismo correcto (ya disponible y en uso) en vez del mecanismo redundante.

**Independent Test**: Filtrar la lista de unidades de medida por grupo usando el identificador del grupo y confirmar que devuelve el mismo conjunto de resultados que antes se obtenía filtrando por el nombre de dimensión.

**Acceptance Scenarios**:

1. **Given** varias unidades de medida repartidas en distintos grupos, **When** se filtra la lista por el identificador de un grupo, **Then** se obtienen únicamente las unidades de ese grupo.
2. **Given** un cliente externo que antes filtraba por el nombre de dimensión (texto libre), **When** intenta usar ese filtro tras este cambio, **Then** el sistema ya no lo soporta y la documentación de la API refleja este cambio de forma explícita.

### Edge Cases

- ¿Qué pasa con integraciones o reportes externos que todavía leen el campo de texto libre eliminado de la respuesta de la API? → Se documenta como cambio incompatible (breaking change) sin reemplazo por nombre; los consumidores deben migrar a usar el identificador del grupo.
- ¿Qué pasa si se revierte (rollback) el cambio en un entorno donde ya se crearon o renombraron grupos después de aplicarlo? → El proceso de reversión debe reconstruir el campo de texto libre a partir del nombre de grupo vigente en ese momento, para dejar los datos en un estado consistente con el comportamiento anterior.
- ¿Qué pasa con una unidad de medida que no tiene grupo asignado? → No es un caso válido: toda unidad de medida pertenece a exactamente un grupo desde la introducción de `UnitMeasureGroup`; este cambio no introduce ni modifica esa regla.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST dejar de exponer, en la respuesta de una unidad de medida, el campo de texto libre que duplicaba el nombre de su grupo.
- **FR-002**: El sistema MUST validar la compatibilidad entre dos unidades de medida (p. ej. al convertir cantidades) usando exclusivamente la relación con su grupo de medida, sin depender de ningún campo de texto libre adicional.
- **FR-003**: El sistema MUST permitir filtrar unidades de medida por el identificador de su grupo (capacidad que ya existe hoy y debe conservarse sin cambios).
- **FR-004**: El sistema MUST dejar de aceptar el filtro de unidades de medida basado en el nombre de dimensión como texto libre.
- **FR-005**: Cuando se crea una unidad de medida nueva o se renombra un grupo de medida, el sistema MUST dejar de escribir o sincronizar ningún campo de texto libre redundante en las unidades afectadas.
- **FR-006**: El sistema MUST seguir produciendo, ante una conversión entre unidades de grupos incompatibles, un rechazo con un mensaje que identifique los grupos involucrados por su nombre.
- **FR-007**: El proceso de reversión del cambio de datos MUST reconstruir el campo de texto libre eliminado a partir del nombre del grupo vigente en cada unidad, de forma que un entorno revertido quede en un estado equivalente al anterior al cambio.
- **FR-008**: La documentación de la API MUST declarar explícitamente la eliminación del campo y del filtro de texto libre como un cambio incompatible (breaking change), sin ofrecer un reemplazo por nombre.

### Key Entities

- **Unidad de medida (`UnitMeasure`)**: Representa una unidad (p. ej. gramo, litro, unidad) usada para medir inventario. Pertenece a exactamente un grupo de medida. Pierde el atributo de texto libre que duplicaba el nombre de su grupo; su grupo se identifica únicamente por la relación existente.
- **Grupo de medida (`UnitMeasureGroup`)**: Representa una familia de unidades compatibles entre sí (p. ej. "Masa", "Volumen", "Conteo"), con un nombre único, y es la única fuente de verdad sobre a qué familia pertenece cada unidad. No sufre cambios estructurales en esta spec.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Renombrar un grupo de medida deja de requerir ninguna escritura adicional sobre las unidades miembro para mantener la consistencia de nombres (0 campos redundantes a sincronizar, frente a los 4 puntos de sincronización existentes hoy).
- **SC-002**: El 100% de las validaciones de conversión entre unidades de medida que se rechazaban antes del cambio (por pertenecer a grupos distintos) se siguen rechazando después del cambio, sin alterar el resultado de ninguna conversión válida existente.
- **SC-003**: El 100% de los filtros de listado de unidades de medida que antes se resolvían por grupo (vía identificador) se siguen resolviendo igual después del cambio.
- **SC-004**: La respuesta de la API de unidades de medida y su documentación quedan libres de cualquier referencia al campo de texto libre eliminado.

## Assumptions

- No existen consumidores externos (fuera de los repositorios de este sistema) con una dependencia contractual formal sobre el campo o el filtro de texto libre eliminados; el único consumidor interno identificado se actualiza como parte de este cambio.
- El dato de grupo de medida (`UnitMeasureGroup`) introducido previamente es correcto y completo para todas las unidades existentes; esta spec no corrige ni migra datos de grupos, solo elimina el campo redundante.
- Se acepta que eliminar el filtro de búsqueda por nombre de dimensión es un cambio incompatible (breaking change) sin período de transición, dado que ya existe un mecanismo equivalente (filtrar por identificador de grupo) desde la introducción de los grupos de medida.
