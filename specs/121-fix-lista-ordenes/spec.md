# Feature Specification: Correcciones visuales y funcionales de la lista de Órdenes

**Feature Branch**: `121-fix-lista-ordenes`

**Created**: 2026-10-16

**Status**: Draft

**Input**: User description: "necesito que arregles dos cosas en el modulo de ventas en la del registro, hace falta mostrar el total, y los badges no son 100 redondeados como se ve en el diseño, el otro ajuste es que en el filtro de fecha si selecciono una fecha especifica en el calendario, esta se queda siempre de forma visual con la fecha de hoy, en el input de entrada, dando la sensacion de que no he cambiado la fecha y lo otro es que te falto incluir el paginador tal como el el diseño original"

## Clarifications

### Session 2026-10-16

- Q: Should the order's total shown on each card be the exact final amount (with discounts and delivery fee applied), even if that requires extending the orders-list API to return it — or is an approximate total computed from the items already in the list response acceptable? → A: Exact final total (discounts + delivery fee included) — requires extending the list API response with that value.
- Q: Should the pagination fix change the shared pagination component reused by other screens, or build a paginator specific to this Órdenes list? → A: Dedicated paginator for the Órdenes list only — the shared component and other screens stay untouched.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ver el total de cada orden sin abrir su detalle (Priority: P1)

El personal necesita ver cuánto vale cada orden directamente en la tarjeta de la lista, sin tener que entrar al detalle de cada una para saberlo.

**Why this priority**: Es información del negocio (dinero) que hoy falta por completo en la tarjeta; es el impacto más alto porque afecta a cada orden visible, todo el tiempo.

**Independent Test**: Puede probarse por separado abriendo la lista de Órdenes y verificando que cada tarjeta muestra un monto total, y que ese monto coincide con el total que se ve al abrir el detalle de esa misma orden.

**Acceptance Scenarios**:

1. **Given** la lista de Órdenes con resultados, **When** el usuario la visualiza, **Then** cada tarjeta muestra el monto total de esa orden.
2. **Given** una tarjeta de la lista con su total visible, **When** el usuario abre el detalle de esa misma orden, **Then** el total mostrado en la tarjeta coincide con el total mostrado en el detalle (mismo valor final, con descuentos y domicilio ya aplicados cuando corresponda).
3. **Given** una orden sin ítems todavía, **When** se muestra su tarjeta, **Then** el total se presenta como el valor real ($0), nunca omitido ni con un valor inventado.

---

### User Story 2 - Confiar en la fecha que muestra el filtro tras elegir un día (Priority: P2)

El personal necesita que, al elegir una fecha puntual en el calendario del filtro, el campo visible del filtro muestre esa fecha elegida, no la de hoy, para no dudar de si el cambio realmente se aplicó.

**Why this priority**: Es un defecto de confianza/usabilidad que puede llevar a leer datos del día equivocado creyendo que se está viendo otro día; impacta cada vez que se usa el filtro de fecha, aunque la lista por debajo sí filtre correctamente.

**Independent Test**: Puede probarse por separado abriendo el filtro de fecha, eligiendo un día distinto de hoy en el calendario, cerrando el calendario y verificando que el texto del campo/control de fecha muestra ese día elegido (no "Hoy").

**Acceptance Scenarios**:

1. **Given** el filtro de fecha cerrado mostrando "Hoy", **When** el usuario abre el calendario y elige un día distinto (pasado), **Then** el campo/control del filtro pasa a mostrar la fecha elegida (p. ej. "14 oct 2026"), no "Hoy".
2. **Given** una fecha específica ya elegida y el filtro cerrado, **When** la lista de órdenes vuelve a cargar con esos resultados, **Then** el campo del filtro sigue mostrando la misma fecha elegida (no vuelve a "Hoy" por sí solo).
3. **Given** una fecha específica ya elegida, **When** el usuario vuelve a abrir el calendario y presiona el atajo "Hoy", **Then** el campo vuelve a mostrar "Hoy" y la lista muestra las órdenes del día actual.

---

### User Story 3 - Navegar la lista de órdenes con el paginador del diseño original (Priority: P3)

El personal necesita moverse entre páginas de resultados y ver cuántas órdenes está viendo del total, con el paginador tal como aparece en el diseño de referencia (selector de cantidad por página, rango visible y total, y controles de anterior/siguiente).

**Why this priority**: Afecta sobre todo cuando hay más órdenes que las que caben en una página; sin el rango visible el personal no sabe cuántas órdenes hay en total ni en qué parte del listado está.

**Independent Test**: Puede probarse por separado generando más órdenes que el tamaño de página elegido y verificando que aparece el paginador con el rango ("X–Y de Z"), el selector de cantidad por página y los controles para cambiar de página.

**Acceptance Scenarios**:

1. **Given** más órdenes que las que caben en una página, **When** el usuario ve la lista, **Then** aparece, al pie de la lista, un paginador con el rango de resultados visibles y el total ("X–Y de Z"), igual que en el diseño de referencia.
2. **Given** el paginador visible, **When** el usuario cambia la cantidad de órdenes por página, **Then** la lista y el rango mostrado se actualizan de forma correspondiente.
3. **Given** el paginador visible con más de una página, **When** el usuario navega a la página siguiente o anterior, **Then** la lista y el rango mostrado avanzan o retroceden de forma correspondiente, y los controles se deshabilitan en la primera y última página según corresponda.

---

### User Story 4 - Ver los estados como píldoras completamente redondeadas (Priority: P4)

El personal necesita que las etiquetas de estado de pago y de estado de la orden en cada tarjeta se vean como píldoras totalmente redondeadas, igual que en el diseño de referencia, en vez de con esquinas apenas curvas.

**Why this priority**: Es una corrección puramente visual/de consistencia de marca; no cambia ninguna información ni bloquea ninguna tarea, por lo que es la de menor impacto entre las cuatro.

**Independent Test**: Puede probarse por separado comparando visualmente las etiquetas de estado de cualquier tarjeta de la lista contra el diseño de referencia, confirmando que el borde es un óvalo/píldora completo y no un rectángulo con esquinas levemente curvas.

**Acceptance Scenarios**:

1. **Given** cualquier tarjeta de la lista de Órdenes, **When** se muestra su etiqueta de estado de pago y su etiqueta de estado de la orden, **Then** ambas se ven con esquinas completamente redondeadas (forma de píldora), igual que en el diseño de referencia.
2. **Given** una etiqueta con un texto de estado largo (p. ej. "En preparación"), **When** se renderiza, **Then** conserva la forma de píldora completamente redondeada sin romperse en un rectángulo de esquinas apenas curvas.

---

### Edge Cases

- ¿Qué pasa con el total cuando una orden tiene descuento o cargo de domicilio aplicado? El total de la tarjeta debe reflejar el valor final, no una suma simple de línea × cantidad que ignore esos ajustes.
- ¿Qué pasa si el usuario abre el calendario, elige una fecha y luego la cierra haciendo clic afuera sin confirmar nada más? La fecha ya elegida debe quedar mostrada; no debe volver a "Hoy" por sí sola.
- ¿Qué pasa si la última página de resultados tiene menos órdenes que el tamaño de página elegido? El rango mostrado por el paginador debe reflejarlo correctamente (p. ej. "9–10 de 10"), igual que ya se definió para esta lista.
- ¿Qué pasa si solo hay una página de resultados? El paginador puede seguir mostrando el selector de cantidad por página y el rango, pero sin controles de anterior/siguiente habilitados (no hay a dónde navegar).
- ¿Qué pasa con una orden cancelada? Su total debe seguir mostrándose igual que para cualquier otra orden, sin inventar ni ocultar el valor.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST mostrar, en cada tarjeta de la lista de Órdenes, el monto total de esa orden.
- **FR-002**: El total mostrado en la tarjeta MUST coincidir con el total final de la orden (incluyendo descuentos y cargo de domicilio ya aplicados cuando corresponda), el mismo valor que se ve al abrir el detalle de esa orden — nunca una suma aproximada que ignore esos ajustes. Si la fuente de datos del listado no provee hoy ese total final, MUST extenderse para proveerlo (no se acepta un total aproximado calculado solo a partir de los ítems visibles en el listado).
- **FR-003**: El sistema MUST actualizar visualmente, de inmediato, el texto del filtro de fecha para que muestre exactamente la fecha elegida (por calendario o por los atajos "Hoy"/"Ayer") cada vez que el usuario cambia la selección.
- **FR-004**: El texto del filtro de fecha MUST seguir mostrando la fecha elegida después de que la lista recargue sus resultados con ese filtro, sin volver a "Hoy" por sí solo.
- **FR-005**: El sistema MUST mostrar, al pie de la lista de Órdenes, un paginador propio de esta pantalla (sin modificar el componente de paginación compartido con otras pantallas) con: selector de cantidad de órdenes por página, indicador del rango de resultados visibles y el total ("X–Y de Z"), y controles para ir a la página anterior/siguiente.
- **FR-006**: El paginador MUST actualizar el rango mostrado y los resultados de la lista al cambiar de página o de cantidad por página, y MUST deshabilitar el control de página anterior en la primera página y el de página siguiente en la última.
- **FR-007**: El sistema MUST mostrar la etiqueta de estado de pago y la etiqueta de estado de la orden, en cada tarjeta de la lista, con esquinas completamente redondeadas (forma de píldora), para cualquier longitud de texto de estado.
- **FR-008**: Estas correcciones MUST NOT alterar el comportamiento ya existente de los filtros de estado, tipo, búsqueda y fecha, ni la navegación al detalle de una orden desde la lista.

### Key Entities

- **Orden (Order)**: Igual que hoy; para esta corrección interesa en particular su total final (ya con descuentos y domicilio aplicados).
- **Filtro de fecha vigente**: La fecha actualmente elegida para la lista (o "Hoy" por defecto) y su representación visual en el control del filtro.
- **Paginación vigente**: Página actual, cantidad de órdenes por página, rango de resultados visibles y total de resultados que cumplen los filtros.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El personal ve el total de cualquier orden directamente en su tarjeta, en el 100% de las tarjetas de la lista, sin necesidad de abrir el detalle.
- **SC-002**: Después de elegir cualquier fecha distinta a hoy en el filtro, el texto del filtro coincide con la fecha elegida en el 100% de los casos probados, sin necesidad de recargar la página completa.
- **SC-003**: El 100% de las etiquetas de estado de pago y de estado de la orden en la lista se ven como píldoras completamente redondeadas, igual que en el diseño de referencia.
- **SC-004**: Con más órdenes que las que caben en una página, el personal identifica cuántas órdenes está viendo del total (rango "X–Y de Z") y puede cambiar de página en un solo clic.
- **SC-005**: Los filtros de estado, tipo, búsqueda y fecha, y la navegación al detalle de una orden, siguen funcionando exactamente igual que antes de esta corrección (cero regresiones).

## Assumptions

- El total mostrado en la tarjeta es el mismo valor final que ya calcula y usa el sistema para el detalle de la orden (el mismo que vería el negocio en la factura); esta corrección no introduce una nueva regla de cálculo de totales, descuentos ni domicilio. Como esa fuente de datos del listado hoy no incluye ese total, se asume que esta corrección puede requerir extender la respuesta del listado de órdenes (backend) para incluirlo, además del cambio visual en la tarjeta (frontend).
- El paginador a mostrar replica el mismo diseño de referencia ya usado para migrar esta lista de Órdenes (spec 120): selector de cantidad por página, rango "X–Y de Z" y controles de anterior/siguiente. Es un paginador propio de esta pantalla, no una modificación del componente de paginación compartido que usan otras pantallas; esas otras pantallas conservan su paginador actual sin cambios.
- Estas correcciones aplican a la vista de lista de Órdenes migrada en spec 120; no se extienden a otras pantallas, ni siquiera a las que comparten componentes visuales con ella.
- No se requiere ningún cambio en los estados, tipos de orden o reglas de negocio existentes; el ajuste es sobre qué se muestra y cómo se actualiza visualmente, no sobre los datos en sí.
