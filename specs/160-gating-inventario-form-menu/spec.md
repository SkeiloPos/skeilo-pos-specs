# Feature Specification: Ocultar sección de Inventario en el formulario de carta según el plan

**Feature Branch**: `160-gating-inventario-form-menu`

**Created**: 2026-11-17

**Status**: Draft

**Input**: User description: "necesito que valides que si un usuario pertenece a un plan, y este no tiene modulo de inventario activo, entonces no se deberia mostrar la seccion de inventario en el formulario de la carta del menu caso contario si se debe mostrar la seccion"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Plan sin módulo de Inventario: la sección no aparece (Priority: P1)

Un usuario administrador de un tenant cuyo plan NO incluye el módulo de Inventario abre el formulario de creación/edición de un producto o tamaño en la carta del menú. Como su plan no incluye ese módulo, no debe ver ninguna referencia a la sección "Inventario" (ni el interruptor "Maneja inventario", ni su contenido, ni mensajes invitando a activarlo).

**Why this priority**: Es el caso reportado como defecto: actualmente la sección se muestra deshabilitada con un mensaje de upsell ("Tu plan actual no incluye el módulo de inventario") en vez de desaparecer, lo cual contradice el patrón ya establecido en el resto del producto para módulos no incluidos en el plan.

**Independent Test**: Con un tenant cuyo plan tiene el módulo de Inventario desactivado, abrir el formulario de producto/tamaño de la carta y confirmar que la sección "Inventario" no se renderiza en absoluto.

**Acceptance Scenarios**:

1. **Given** un tenant cuyo plan tiene el módulo de Inventario inactivo, **When** el usuario abre el formulario para crear un nuevo producto en la carta, **Then** el formulario no muestra la sección "Inventario" en ninguno de los tamaños/presentaciones del producto.
2. **Given** un tenant cuyo plan tiene el módulo de Inventario inactivo, **When** el usuario abre el formulario para editar un producto existente que ya tenía insumos/inventario configurado antes de perder el acceso, **Then** la sección "Inventario" no se muestra, pero la configuración de inventario existente del producto no se elimina ni se modifica.

---

### User Story 2 - Plan con módulo de Inventario: la sección se muestra y funciona (Priority: P1)

Un usuario administrador de un tenant cuyo plan SÍ incluye el módulo de Inventario abre el formulario de creación/edición de un producto o tamaño en la carta del menú. Debe ver la sección "Inventario" completa y poder activarla/configurarla con normalidad.

**Why this priority**: Es el comportamiento contrario que debe seguir garantizado; valida que el cambio no oculte la sección para quienes sí tienen derecho a usarla.

**Independent Test**: Con un tenant cuyo plan tiene el módulo de Inventario activo, abrir el formulario de producto/tamaño de la carta y confirmar que la sección "Inventario" se muestra y permite activar el interruptor "Maneja inventario" y configurar insumos normalmente.

**Acceptance Scenarios**:

1. **Given** un tenant cuyo plan tiene el módulo de Inventario activo, **When** el usuario abre el formulario de un tamaño/presentación de producto, **Then** la sección "Inventario" se muestra con su interruptor "Maneja inventario" habilitado.
2. **Given** un tenant cuyo plan tiene el módulo de Inventario activo, **When** el usuario activa "Maneja inventario" en un tamaño y configura insumos, **Then** el formulario permite guardar esa configuración sin restricciones adicionales.

---

### User Story 3 - El plan del tenant cambia mientras el formulario está en uso (Priority: P2)

Si durante la sesión del usuario el plan del tenant cambia (se le quita o se le agrega el módulo de Inventario, por ejemplo por una actualización de suscripción), la próxima vez que el formulario de carta se abra debe reflejar el estado vigente del plan, no el que tenía al iniciar sesión.

**Why this priority**: Evita inconsistencias donde el usuario ve una sección que ya no debería tener o no ve una que ya debería tener, por depender de información de plan obsoleta.

**Independent Test**: Cambiar el módulo de Inventario del plan de un tenant de prueba, recargar/reabrir el formulario de carta y confirmar que la visibilidad de la sección corresponde al estado actualizado del plan.

**Acceptance Scenarios**:

1. **Given** un tenant cuyo plan inicialmente no incluye Inventario, **When** el plan se actualiza para incluir el módulo y el usuario vuelve a abrir el formulario de carta, **Then** la sección "Inventario" aparece disponible.
2. **Given** un tenant cuyo plan inicialmente incluye Inventario, **When** el módulo se retira del plan y el usuario vuelve a abrir el formulario de carta, **Then** la sección "Inventario" deja de mostrarse.

---

### Edge Cases

- Un producto tiene múltiples tamaños/presentaciones: la sección "Inventario" debe ocultarse o mostrarse de forma consistente en todos los tamaños del mismo formulario, según el plan vigente del tenant, no por tamaño individual.
- Un producto ya tenía insumos de inventario configurados (guardados previamente) y el plan pierde el módulo: los datos de inventario existentes se conservan en el sistema (no se borran) aunque la sección deje de mostrarse, y vuelven a estar visibles y editables si el módulo se reactiva.
- Si el usuario intenta guardar el formulario mientras la sección está oculta por no tener el módulo, el guardado no debe alterar ni limpiar la configuración de inventario existente del producto.
- Un plan en periodo de prueba o transición (si existiera) se evalúa igual que cualquier otro plan: lo relevante es si el módulo de Inventario está activo o no en ese momento, sin importar el motivo.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST determinar la visibilidad de la sección "Inventario" en el formulario de producto/tamaño de la carta del menú en función de si el plan vigente del tenant tiene activo el módulo de Inventario.
- **FR-002**: Si el plan vigente del tenant NO tiene activo el módulo de Inventario, el formulario MUST omitir por completo la sección "Inventario" (interruptor, descripción y contenido asociado) para todos los tamaños/presentaciones del producto, en lugar de mostrarla deshabilitada o con un mensaje de upsell.
- **FR-003**: Si el plan vigente del tenant SÍ tiene activo el módulo de Inventario, el formulario MUST mostrar la sección "Inventario" en estado funcional (interruptor habilitado y, al activarlo, acceso a la configuración de insumos).
- **FR-004**: La verificación de si el módulo de Inventario está activo para el tenant MUST basarse en el estado actual del plan al momento de cargar el formulario, no en un valor cacheado obsoleto de una sesión previa.
- **FR-005**: Ocultar la sección "Inventario" por falta del módulo en el plan MUST NOT eliminar, limpiar ni modificar ninguna configuración de inventario (insumos, cantidades, "maneja inventario") previamente guardada para ese producto o tamaño.
- **FR-006**: Si el plan del tenant recupera el módulo de Inventario después de haberlo perdido, el formulario MUST volver a mostrar la sección "Inventario" con la configuración previamente guardada intacta.
- **FR-007**: La validación de acceso al módulo de Inventario para efectos de esta sección del formulario MUST ser consistente con la regla ya aplicada a otras superficies dependientes de Inventario (p. ej. ajustes y reportes relacionados), de modo que el comportamiento de ocultar-completamente-sin-pérdida-de-datos sea uniforme en todo el sistema.

### Key Entities

- **Plan**: Define, entre otros atributos, si el módulo de Inventario está incluido/activo para los tenants que lo tienen asignado.
- **Tenant**: Está asociado a un plan vigente; ese plan determina si el tenant tiene acceso al módulo de Inventario.
- **Producto / Tamaño (presentación)**: Entidad de la carta del menú cuyo formulario incluye, entre otras, una sección de configuración de inventario (insumos que descuenta).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100% de los tenants cuyo plan no incluye el módulo de Inventario dejan de ver la sección "Inventario" en el formulario de carta del menú, en cualquier tamaño/presentación del producto.
- **SC-002**: El 100% de los tenants cuyo plan sí incluye el módulo de Inventario continúan viendo y pudiendo usar la sección "Inventario" sin cambios respecto al comportamiento actual.
- **SC-003**: Ningún producto pierde su configuración de inventario previamente guardada como resultado de que su tenant pierda o recupere el acceso al módulo de Inventario.
- **SC-004**: Tras un cambio de plan (ganar o perder el módulo de Inventario), la siguiente vez que se abre el formulario de carta la visibilidad de la sección refleja el plan vigente, sin requerir pasos manuales adicionales del usuario distintos a recargar/reabrir el formulario.

## Assumptions

- El concepto de "módulo de Inventario" en el plan es el mismo módulo unificado ya usado para controlar el acceso a Proveedores, Compras e Inventario en el resto del sistema, no un flag nuevo o distinto.
- La fuente de verdad sobre si el módulo de Inventario está activo es la información de plan del tenant ya expuesta al front-end (no se introduce un nuevo mecanismo de consulta de plan); esta especificación solo cubre que el formulario de carta respete esa información de forma consistente.
- El patrón de "ocultar completamente, sin perder datos, y restaurar al recuperar el acceso" ya validado para otras secciones dependientes de Inventario (ajustes, reportes) aplica igual para esta sección del formulario de carta.
- No se requiere ningún mensaje o indicación de upsell en el formulario cuando la sección está oculta; simplemente no aparece, igual que otras secciones gateadas por plan en el producto.
