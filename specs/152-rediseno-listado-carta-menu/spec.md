# Feature Specification: Rediseño del listado de la Carta del menú

**Feature Branch**: `152-rediseno-listado-carta-menu`

**Created**: 2026-11-05

**Status**: Draft

**Input**: User description: "necesito que rediseñes la vista del modulo de la carta del menu usando el archivo @\"design/SkeiloPOS App - Carta del menu offline.html\" si hay alguna funcionalidad nueva que requiera endpoint me avisas, y limitate a optimizar y traer solo la data que se muestra en el listado, no traigas informacion innesearia, si tienes alguna pregunta me la haces antes de continuar y el diseño debe ser exacto y responsive"

## Clarifications

### Session 2026-11-05

- Q: ¿Debe el listado mostrar precio por producto, dado que hoy no lo incluye? → A: Sí. Mostrar el precio único si el producto tiene una sola variante, o "Desde $X" (el precio más bajo) si tiene varias.
- Q: ¿Se agrega filtro por categoría al listado? → A: Sí, filtro server-side por categoría, igual a los demás filtros existentes (búsqueda, activo/inactivo, disponible/agotado).
- Q: ¿El nuevo diseño de tarjetas reemplaza la tabla en todos los tamaños de pantalla? → A: No. Tarjetas en móvil/tablet; se conserva la tabla en escritorio.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Explorar la carta del menú desde el móvil (Priority: P1)

Un usuario del punto de venta (administrador o cajero) abre el módulo "Carta del menú" desde un teléfono o tablet y necesita ver rápidamente sus productos: imagen, nombre, categoría, precio y disponibilidad, sin desplazarse por una tabla incómoda en pantalla pequeña.

**Why this priority**: Es el punto de entrada principal del módulo y hoy la experiencia en móvil es deficiente (tabla con columnas ocultas). Sin esto no hay valor entregado por el rediseño.

**Independent Test**: Abrir el módulo en un viewport móvil y confirmar que los productos se muestran como tarjetas legibles con imagen, nombre, precio y estado de disponibilidad, sin scroll horizontal.

**Acceptance Scenarios**:

1. **Given** el usuario abre "Carta del menú" en un dispositivo móvil (ancho < 768px), **When** la lista de productos carga, **Then** cada producto se muestra como una tarjeta con imagen (o marcador "Sin imagen"), nombre, categoría, precio y estado (Activo/Inactivo, Disponible/Agotado).
2. **Given** el usuario abre "Carta del menú" en un dispositivo de escritorio (ancho ≥ 1024px), **When** la lista de productos carga, **Then** se mantiene el layout de tabla actual con las mismas columnas y acciones.
3. **Given** un producto no tiene imagen cargada, **When** se renderiza su tarjeta o fila, **Then** se muestra un marcador visual de "Sin imagen" en vez de un espacio roto o vacío.

---

### User Story 2 - Filtrar productos por categoría (Priority: P2)

Un usuario con un catálogo grande necesita ver solo los productos de una categoría específica (p. ej. "Sabores de helado") para encontrar lo que busca más rápido, tanto en el listado móvil como en el de escritorio.

**Why this priority**: El diseño de referencia incorpora chips de categoría como mecanismo principal de navegación del catálogo; sin este filtro la nueva vista no cumple su propósito de optimizar la búsqueda.

**Independent Test**: Seleccionar una categoría específica y confirmar que el listado (tarjetas o tabla) muestra únicamente productos de esa categoría, y que al limpiar el filtro vuelven a verse todos.

**Acceptance Scenarios**:

1. **Given** el usuario está en el listado de productos, **When** selecciona una categoría del filtro, **Then** el listado se actualiza para mostrar solo productos de esa categoría, combinando correctamente con cualquier búsqueda por nombre y filtros de estado/disponibilidad ya aplicados.
2. **Given** el usuario tiene un filtro de categoría activo, **When** selecciona "Todas las categorías", **Then** el filtro se limpia y el listado vuelve a mostrar productos de todas las categorías (respetando los demás filtros activos).
3. **Given** una categoría filtrada no tiene productos que coincidan con los demás filtros activos, **When** se aplican esos filtros, **Then** se muestra un mensaje de "sin resultados" en lugar de una lista vacía sin explicación.

---

### User Story 3 - Ver el precio del producto directamente en el listado (Priority: P2)

Un usuario necesita saber el precio de un producto sin tener que abrir su detalle, para responder preguntas de clientes o revisar el catálogo rápidamente.

**Why this priority**: El diseño de referencia muestra el precio en cada tarjeta/fila; es información de alto valor para el flujo de consulta rápida del catálogo, aunque no bloquea el valor base de la navegación (P1).

**Independent Test**: Abrir el listado y verificar que cada producto muestra su precio (o "Desde $X" si tiene varias variantes), sin tener que entrar al detalle del producto.

**Acceptance Scenarios**:

1. **Given** un producto tiene una sola variante con precio definido, **When** se muestra en el listado, **Then** se visualiza su precio exacto (p. ej. "$12.000").
2. **Given** un producto tiene varias variantes (tamaños) con precios distintos, **When** se muestra en el listado, **Then** se visualiza el precio más bajo precedido de "Desde" (p. ej. "Desde $9.000").
3. **Given** un producto no tiene ninguna variante con precio configurado, **When** se muestra en el listado, **Then** se visualiza un indicador de "Sin precio" en lugar de un valor vacío o "$0".

---

### Edge Cases

- ¿Qué sucede si un producto pertenece a una categoría que fue eliminada o quedó sin nombre? → Debe agruparse/mostrarse bajo una categoría "Sin categoría" en el filtro y en la tarjeta/fila.
- ¿Qué pasa si la búsqueda por nombre y el filtro de categoría no tienen coincidencias combinadas? → Mostrar el mensaje de "sin resultados" existente, no una lista vacía ambigua.
- ¿Qué pasa con productos marcados como topping (`is_topping`)? → Mantienen el comportamiento de filtrado actual; no se alteran por este rediseño.
- ¿Qué sucede en un dispositivo de ancho intermedio (tablet, ~768–1023px)? → Se mantiene la vista de tarjetas (igual que móvil) hasta el punto de quiebre de escritorio definido para la tabla.
- ¿Qué pasa si el usuario cambia el tamaño de la ventana en vivo (de escritorio a móvil o viceversa)? → El listado debe alternar entre tabla y tarjetas sin perder los filtros ni la posición de paginación actual.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema DEBE mostrar el listado de productos como tarjetas (imagen, nombre, categoría, precio, estado de activo/inactivo y disponible/agotado) en anchos de pantalla menores al punto de quiebre de escritorio, replicando fielmente la disposición visual del diseño de referencia.
- **FR-002**: El sistema DEBE conservar el listado en formato de tabla, con sus columnas y acciones actuales, en anchos de pantalla de escritorio.
- **FR-003**: El sistema DEBE permitir filtrar el listado por categoría mediante un control de selección (chip o similar), incluyendo una opción para ver "Todas las categorías".
- **FR-004**: El filtro de categoría DEBE combinarse correctamente con los filtros existentes (búsqueda por nombre, activo/inactivo, disponible/agotado) sin que se excluyan entre sí.
- **FR-005**: El sistema DEBE mostrar, por cada producto del listado, el precio único si tiene una sola variante con precio, o el precio más bajo con el prefijo "Desde" si tiene varias variantes con precios distintos.
- **FR-006**: El sistema DEBE mostrar un indicador de "Sin precio" cuando ningún precio esté configurado para el producto, en lugar de omitir el campo o mostrar un valor igual a cero.
- **FR-007**: El sistema DEBE mostrar un marcador visual de "Sin imagen" para productos sin imagen cargada, tanto en la vista de tarjetas como en la de tabla.
- **FR-008**: El sistema NO DEBE solicitar ni transportar en la respuesta del listado datos del producto que no se muestran en ninguna de las dos vistas (tarjeta o tabla), tales como recetas, grupos de opciones completos, variantes detalladas distintas del precio resumido, o metadatos de auditoría no visibles en pantalla.
- **FR-009**: El sistema DEBE mantener la paginación y los demás filtros existentes al alternar entre la vista de tarjetas y la vista de tabla (p. ej. al redimensionar la ventana).
- **FR-010**: El sistema DEBE mostrar un mensaje de "sin resultados" cuando la combinación de filtros (categoría, búsqueda, estado, disponibilidad) no arroje productos, igual en ambas vistas.
- **FR-011**: Las acciones disponibles por producto (editar, activar/desactivar, marcar disponible/agotado) y las restricciones por rol de usuario DEBEN preservarse sin cambios funcionales en ambas vistas.

### Key Entities *(include if feature involves data)*

- **Producto (listado)**: Representación resumida de un producto para el listado de la carta: identificador, código, nombre, categoría, imagen, tipo de preparación, estado activo/inactivo, estado disponible/agotado (y quién/cuándo lo cambió), y ahora un precio resumen (precio único o "desde el más bajo") derivado de sus variantes. No incluye receta, grupos de opciones ni detalle completo de variantes — esa información pertenece únicamente a la vista de detalle del producto.
- **Categoría**: Agrupación de productos usada tanto para mostrar la categoría de cada producto como para el nuevo filtro por categoría del listado.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: En dispositivos con ancho menor al punto de quiebre de escritorio, el 100% de los productos del listado se visualizan sin necesidad de desplazamiento horizontal.
- **SC-002**: Un usuario puede identificar el precio de cualquier producto visible en el listado sin abrir su detalle, en el 100% de los casos.
- **SC-003**: Un usuario puede filtrar el catálogo a una categoría específica y obtener el resultado esperado en menos de 2 interacciones (seleccionar categoría y, opcionalmente, limpiar otros filtros).
- **SC-004**: La respuesta del listado no transporta ningún campo que no se despliegue visualmente en la tarjeta o la fila de tabla (verificable por inspección del payload vs. los campos renderizados).
- **SC-005**: El diseño de tarjetas en móvil/tablet coincide visualmente (disposición, jerarquía de información y elementos mostrados) con el archivo de referencia `design/SkeiloPOS App - Carta del menu offline.html`.

## Assumptions

- El módulo afectado es la "Carta del menú" interna del POS (gestión/listado de productos para administradores y cajeros), no el menú público por QR, que es una funcionalidad independiente y no se modifica en este feature.
- El punto de quiebre entre vista de tarjetas (móvil/tablet) y vista de tabla (escritorio) sigue el estándar ya usado en el resto de la aplicación para transiciones responsive equivalentes.
- Los roles, permisos y acciones disponibles por producto (crear, editar, activar/desactivar, marcar disponible/agotado, exportar/importar) no cambian con este rediseño; solo cambia la presentación del listado y los datos mínimos que viaja en la respuesta.
- El precio mostrado en el listado es informativo (precio único o "desde"); el detalle completo de precios por variante sigue consultándose únicamente en la vista de detalle/edición del producto.
- Agregar el precio resumido y el filtro por categoría al endpoint de listado de productos requiere cambios en el backend (nuevo campo de precio calculado y nuevo parámetro de filtro `category_id` en el endpoint de listado); esto fue confirmado con el usuario antes de continuar.
