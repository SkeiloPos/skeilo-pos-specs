# Feature Specification: Migrar vista del módulo de Órdenes al nuevo diseño

**Feature Branch**: `120-migrar-vista-ordenes`

**Created**: 2026-10-15

**Status**: Draft

**Input**: User description: "necesito que uses de referencia el diseño que se encuentra en @\"desing/SkeiloPOS App.dc.html\" de ese diseño unicamente vas a migrar la vista del modulo de ordenes al modulo actual, si tienes alguna duda me preguntas"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Explorar y filtrar la lista de órdenes con el nuevo diseño (Priority: P1)

El personal del local necesita encontrar rápidamente una orden dentro de la operación del día filtrando por estado, tipo de pedido, fecha o buscando por cliente/número de orden, viendo cada orden como una tarjeta con su información esencial a simple vista.

**Why this priority**: Es la pantalla de entrada al módulo; sin una lista clara y filtrable el resto de las funciones (ver detalle, crear orden) no tienen desde dónde partir.

**Independent Test**: Puede probarse por separado abriendo el módulo de Órdenes, aplicando combinaciones de los filtros de estado, tipo, fecha y búsqueda, y verificando que la lista de tarjetas y el conteo de resultados se actualizan de forma consistente.

**Acceptance Scenarios**:

1. **Given** el módulo de Órdenes con operación del día, **When** el usuario entra a la pantalla, **Then** ve las órdenes del día actual como tarjetas, cada una con cliente, número de orden, hora, cantidad de ítems, ubicación/tipo, estado de pago y estado de la orden.
2. **Given** la lista de órdenes visible, **When** el usuario escribe en el buscador el nombre de un cliente o un número de orden, **Then** la lista se filtra a las órdenes coincidentes y el conteo de resultados se actualiza.
3. **Given** la lista de órdenes visible, **When** el usuario selecciona un estado en el filtro de estado y/o un tipo en el filtro de tipo, **Then** solo se muestran las órdenes que cumplen ambos filtros a la vez.
4. **Given** la lista de órdenes visible, **When** el usuario abre el selector de fecha y elige "Ayer" o un día del calendario, **Then** la lista muestra únicamente las órdenes de esa fecha (no se permite elegir fechas futuras).
5. **Given** una combinación de filtros sin resultados, **When** se aplican, **Then** se muestra un estado vacío indicando que no hay órdenes con esos filtros.
6. **Given** más órdenes que las que caben en una página, **When** el usuario cambia el tamaño de página o navega entre páginas, **Then** la lista y el indicador de rango ("X–Y de Z") se actualizan de forma correspondiente.

---

### User Story 2 - Ver el detalle de una orden con la información agrupada del nuevo diseño (Priority: P2)

El personal necesita abrir una orden puntual y ver, en un solo lugar y agrupada por tema, la información de la orden (tipo, ubicación, hora), del cliente, de domicilio (cuando aplica) y de la factura (referencia, fecha, método y estado de pago), junto con el detalle de ítems y el resumen de totales.

**Why this priority**: Es la acción posterior más común a la lista (abrir una orden para resolver una duda, verificar un cobro o atender un reclamo); depende de que la lista (US1) exista para llegar hasta aquí.

**Independent Test**: Puede probarse por separado entrando al detalle de una orden ya existente (por ejemplo desde su URL/identificador) y verificando que la información agrupada, el detalle de ítems y los totales se muestran completos y coherentes con los datos reales de esa orden.

**Acceptance Scenarios**:

1. **Given** una orden en mesa, **When** el usuario abre su detalle, **Then** ve agrupada la información de la orden (tipo "En mesa", mesa/ubicación, hora), la del cliente (nombre y, si existe, identificación) y la de factura (referencia, fecha y hora, método y estado de pago), sin bloque de domicilio.
2. **Given** una orden a domicilio, **When** el usuario abre su detalle, **Then** además de lo anterior ve el bloque de datos de domicilio (teléfono y dirección).
3. **Given** el detalle de una orden, **When** el usuario revisa el resumen de la orden, **Then** ve cada ítem con su cantidad, precio unitario y subtotal, y debajo el desglose de totales (subtotal, domicilio si aplica, descuento, total, pagado) consistente con la información ya calculada por el sistema.
4. **Given** el botón "Volver a órdenes" en el detalle, **When** el usuario lo presiona, **Then** regresa a la lista de órdenes conservando los filtros que tenía antes de entrar al detalle.
5. **Given** un dato no disponible para esa orden (p. ej. identificación del cliente o método de pago cuando aún no se ha cobrado), **When** se renderiza el detalle, **Then** esa fila se omite en vez de mostrarse vacía, con un guion, o con un valor inventado.

---

### User Story 3 - Iniciar una nueva orden desde el módulo de Órdenes (Priority: P3)

El personal necesita un acceso directo ("Nueva orden") desde la lista de órdenes para comenzar a armar un pedido sin tener que navegar primero a Mesas o Terminal.

**Why this priority**: Es un atajo de conveniencia sobre un flujo de creación que ya existe en el sistema; aporta valor pero el módulo es funcional sin él si US1 y US2 ya están resueltas.

**Independent Test**: Puede probarse por separado presionando "Nueva orden" desde la lista y verificando que lleva al flujo de creación de pedido ya existente en el sistema.

**Acceptance Scenarios**:

1. **Given** la lista de órdenes, **When** el usuario presiona "Nueva orden", **Then** es llevado al flujo existente de creación de pedido manual para comenzar a armarlo.

---

### Edge Cases

- ¿Qué ocurre cuando no hay ninguna orden registrada para el día seleccionado (aunque sí existan en otras fechas)? Debe mostrarse el estado vacío, no un error.
- ¿Qué ocurre si la búsqueda no coincide con ningún cliente ni número de orden? Debe mostrarse el estado vacío manteniendo los demás filtros aplicados.
- ¿Cómo se comporta el filtro de tipo para una orden histórica sin tipo clasificado? Debe quedar fuera al filtrar por un tipo concreto, igual que hoy.
- ¿Qué pasa con nombres de cliente, direcciones o notas muy largos en la tarjeta o en el detalle? Deben truncarse o ajustarse de línea sin romper el layout ni perder la información al abrir el detalle completo.
- ¿Qué se muestra cuando una orden no tiene todavía ítems (recién creada)? El resumen de ítems debe indicar que no hay ítems, sin tabla vacía confusa.
- ¿Qué pasa con una orden anulada/cancelada? Debe seguir siendo visible en la lista e ingresable a su detalle, mostrando su estado como cancelada y sin inventar un total de pago.
- ¿Qué ocurre si la última página de resultados tiene menos órdenes que el tamaño de página elegido? El indicador de rango y los controles de paginación deben reflejarlo correctamente (p. ej. "9–10 de 10").

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST mostrar la lista de órdenes como tarjetas (una cuadrícula adaptable), cada una con: nombre del cliente, número/identificador de la orden, hora de creación, cantidad de ítems, ubicación o tipo de atención, estado de pago y estado de la orden con color e icono distintivo.
- **FR-002**: El sistema MUST permitir filtrar la lista por estado de la orden mediante un selector, usando los estados reales ya existentes en el sistema (por confirmar, abierta, bloqueada, pagada, cancelada).
- **FR-003**: El sistema MUST permitir filtrar la lista por tipo de atención (en mesa, para llevar, domicilio) mediante un control de opciones segmentadas, combinable con el filtro de estado.
- **FR-004**: El sistema MUST permitir buscar por nombre de cliente o por número/identificador de orden mediante un campo de búsqueda de texto libre, combinable con los demás filtros.
- **FR-005**: El sistema MUST permitir elegir una fecha (con atajos "Hoy"/"Ayer" y un calendario) para ver solo las órdenes de ese día, sin permitir seleccionar fechas futuras.
- **FR-006**: El sistema MUST mostrar, de forma visible y actualizada con los filtros vigentes, cuántas órdenes cumplen los criterios actuales.
- **FR-007**: El sistema MUST mostrar un estado vacío con mensaje claro cuando ningún resultado cumple los filtros vigentes.
- **FR-008**: El sistema MUST paginar la lista permitiendo elegir cuántas órdenes se muestran por página y navegar entre páginas, indicando el rango visible y el total.
- **FR-009**: El sistema MUST permitir abrir el detalle de cualquier orden de la lista al seleccionarla.
- **FR-010**: El sistema MUST mostrar un acceso directo "Nueva orden" desde la lista que lleve al flujo existente de creación de pedido manual.
- **FR-011**: El sistema MUST mostrar en el detalle de la orden un encabezado con el identificador de la orden, su estado (color e icono) y un botón para volver a la lista de órdenes conservando los filtros previos.
- **FR-012**: El sistema MUST agrupar la información del detalle de la orden en bloques: información de la orden (tipo, ubicación y hora), información del cliente (nombre e identificación cuando esté disponible) e información de factura (referencia, fecha y hora, método de pago cuando esté disponible, y estado de pago). La "ubicación" MUST mostrar la mesa cuando la orden es en mesa, o "Mostrador" cuando es para llevar (mismo criterio ya usado hoy en la lista); para domicilio, este bloque se omite y su lugar lo ocupa el bloque de datos de domicilio (FR-013).
- **FR-013**: El sistema MUST mostrar el bloque de información de domicilio (teléfono y dirección) únicamente cuando la orden sea de tipo domicilio.
- **FR-014**: El sistema MUST mostrar, dentro del detalle, la lista de ítems de la orden con cantidad, precio unitario y subtotal por línea, preservando las particularidades ya existentes (notas del ítem, adicionales, ítems anulados) dentro del nuevo formato visual de tabla.
- **FR-015**: El sistema MUST mostrar, debajo del detalle de ítems, el desglose de totales de la orden (subtotal, valor de domicilio cuando aplique, descuento, total y monto pagado) reutilizando los montos y reglas ya calculadas por el sistema.
- **FR-016**: El sistema MUST omitir cualquier dato no disponible para una orden (identificación del cliente, método de pago, etc.) en vez de mostrarlo vacío, con un marcador de relleno o con un valor inventado.
- **FR-017**: El sistema MUST conservar, en texto, el significado real de cada estado y tipo ya existente en el sistema; el nuevo diseño visual MUST NOT introducir estados o tipos de orden que no existan hoy en los datos.

### Key Entities

- **Orden (Order)**: Un pedido de la operación; tiene identificador, tipo de atención, estado de facturación, estado de pago, cliente, fecha/hora de creación, ítems y, si aplica, datos de domicilio.
- **Ítem de orden**: Una línea de producto dentro de una orden, con cantidad, precio unitario, subtotal y, opcionalmente, notas o adicionales.
- **Cliente de la orden**: Nombre y, cuando esté disponible, identificación asociados a una orden puntual (no un perfil de cliente persistente).
- **Filtro de órdenes**: Combinación vigente de estado, tipo, fecha y texto de búsqueda que determina qué órdenes se listan.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El personal encuentra una orden específica por nombre de cliente o número de orden entre más de 50 órdenes del día en menos de 10 segundos.
- **SC-002**: El personal puede combinar estado, tipo, fecha y búsqueda y ver la lista y el conteo de resultados actualizados sin recargar la página completa.
- **SC-003**: El 100% de las órdenes visibles para el personal se presentan en el nuevo formato de tarjeta tanto en pantallas de escritorio como en pantallas angostas (tablet/móvil), sin información cortada u oculta sin acceso.
- **SC-004**: El personal identifica, sin salir del detalle de una orden, su estado, su cliente, sus ítems y su total.
- **SC-005**: Cero casos de datos inventados (por ejemplo, un "$0" o un guion de relleno) en campos que el sistema no tiene capturados para esa orden; el campo simplemente no aparece.
- **SC-006**: El personal inicia la creación de una nueva orden desde la lista de órdenes en un solo clic.

## Assumptions

- "Nueva orden" reutiliza el flujo de creación de pedido manual que ya existe en el sistema; esta migración MUST NOT construir una pantalla de creación nueva.
- Los filtros de "Estado" y "Tipo" y el badge de "Estado de pago" se mapean a los valores reales que ya maneja el sistema (estados de facturación de la orden y tipos de atención), no a las etiquetas de ejemplo del diseño de referencia (que usa nombres de un flujo de cocina distinto).
- La "Referencia" de factura mostrada en el detalle MUST ser la factura real registrada en el sistema cuando la orden ya la tiene (mismo número que vería el negocio en Ventas); solo mientras la orden no se ha cobrado todavía (sin factura posible) se respalda con el identificador interno de la orden, para no dejar la fila vacía. *(Corrección post-implementación: la primera versión reutilizaba siempre el identificador interno como "Referencia", y el negocio reportó que no coincidía con la factura real — ver data-model.md "Valores derivados".)*
- El "Método de pago" se resuelve del pago real registrado contra la orden (no solo del intento de pago por QR, que no existe para los pedidos cobrados por mostrador); solo se omite cuando la orden todavía no tiene ningún pago registrado, y el estado de pago se muestra como pendiente en ese caso. *(Corrección post-implementación: la primera versión solo miraba el intento de pago QR, dejando esta fila vacía para la mayoría de las órdenes pagadas por mostrador.)*
- La identificación del cliente solo se muestra cuando ya fue capturada en el pedido; si no existe, la fila se omite en vez de mostrar un valor de relleno.
- El filtro de fecha por defecto muestra el día actual; el calendario permite navegar a fechas pasadas y no permite seleccionar fechas futuras.
- Esta migración cubre únicamente la vista del módulo de Órdenes (lista y detalle) y el acceso directo de creación; no incluye cambios al resto de módulos (Mesas, Terminal, Ventas) más allá de los puntos de entrada/salida ya existentes hacia/desde Órdenes.
- La "ubicación" de una orden para llevar se muestra como "Mostrador", reutilizando el mismo criterio que ya aplica hoy la lista de órdenes para pedidos sin mesa asignada.
- El filtro de fecha (FR-005) y la búsqueda por cliente/orden (FR-004) MUST aplicar sobre el total de órdenes del negocio, no solo sobre las ya cargadas en la página visible; esto requiere que la consulta de órdenes del sistema acepte fecha y texto de búsqueda como criterios, siguiendo el mismo patrón que ya existe para la búsqueda y el filtrado por fecha en el módulo de Ventas.
