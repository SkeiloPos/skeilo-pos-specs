# Feature Specification: Rediseño del módulo Dashboard según el prototipo

**Feature Branch**: `122-rediseno-dashboard`

**Created**: 2026-10-16

**Status**: Draft

**Input**: User description: "necesito que actualices el diseño del mondulo dashboard actual en implementes el diseño que se encuentra en @\"desing/SkeiloPOS App.dc.html\" si tienes alguna pregunta o dudo me la haces antes de continuar, el diseño debe ser fiel al del prototipo"

## Clarifications

### Session 2026-10-16

- Q: El diseño de referencia no muestra las tarjetas de "Usuarios" y "Productos", ni la lista "Órdenes recientes" (la tarjeta de "Órdenes activas" sí tiene lugar: se incorpora al nuevo grupo de 4 indicadores). ¿Qué hacemos con esas 3 piezas? → A: Conservarlas además de las secciones nuevas del diseño.
- Q: La sección "Ingresos por método de pago" (total por método + gráfico día a día de varios días + filtros) requiere una consulta nueva en el backend que no existe hoy. ¿Versión completa o una más simple? → A: Versión completa — se autoriza el trabajo de backend nuevo.
- Q: El saludo personalizado necesita el nombre real de quien inició sesión, que el backend no expone hoy en el token de sesión. ¿Cómo se resuelve? → A: Agregar el nombre real (cambio pequeño de backend: exponerlo en el token de sesión).
- Q: El prototipo adapta la granularidad del gráfico de "Ingresos por método de pago" al período elegido (por hora en turno/día, diaria en semana, semanal en mes, diaria en rango personalizado) en vez de usar una ventana fija de 7 días. ¿Fidelidad completa o una versión simple de ventana fija? → A: Fidelidad completa — granularidad adaptativa según el período elegido.

### Session 2026-10-16 (revisión posterior a la primera entrega)

- Q: Las tarjetas "Usuarios" y "Productos" se conservaron (FR-009) según la decisión de arriba, pero cada una depende de una consulta HTTP propia e independiente (`UsersService.loadUsers()`, `ProductService.loadProducts()`) que no comparte datos con ninguna otra sección del Dashboard. El negocio pidió retirarlas. → A: Eliminar ambas tarjetas **y** las dos llamadas HTTP que solo alimentaban sus valores — no quedan huérfanas en el componente. La lista "Órdenes recientes" (ya retirada antes de esta feature, research.md §6) y la tarjeta "Órdenes activas" (que sí sigue el período, FR-003) no se ven afectadas: `DiningSessionService.listOrders()` se conserva porque alimenta `activeOrdersCount`, un dato que sí se muestra en la fila de 4 indicadores.
- Q: research.md §5 documentó explícitamente conservar `ShareBarChartComponent` (barra apilada horizontal) para "Ventas por categoría" en vez de un gráfico circular, precisamente para que el negocio pudiera objetar si la fidelidad visual importaba más que la accesibilidad ya lograda. El negocio objetó. → A: Cambiar "Ventas por categoría" a un gráfico circular (dona), conservando la misma leyenda con color/nombre/%/monto que ya tenía la barra apilada (componente nuevo `PieChartComponent`, no se toca `ShareBarChartComponent`: ese componente lo siguen usando el módulo de Informes y `ShiftSalesReportCardComponent`).
- Q: "Estadísticas de ventas" (FR-004) especificaba un gráfico de barras. El negocio pidió un gráfico de líneas para esa misma tendencia. → A: Cambiar a un gráfico de líneas (componente nuevo `LineChartComponent`, no se toca `BarsChartComponent`: lo sigue usando el módulo de Informes). El resto de FR-004 (pestañas Ventas/Órdenes/Ticket promedio, ventana fija de días recientes, tooltip con fecha y valor exacto al pasar el cursor) no cambia.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ver el saludo, los accesos rápidos y los indicadores del turno con el nuevo diseño (Priority: P1)

Al entrar al Dashboard, el personal administrativo ve un saludo personalizado, los accesos rápidos a los módulos más usados justo debajo del saludo, y los indicadores clave del reporte operativo (ventas totales, órdenes, ticket promedio y órdenes activas) presentados como una fila de 4 tarjetas, igual que en el diseño de referencia.

**Why this priority**: Es lo primero que se ve al entrar al sistema cada día; define la primera impresión del nuevo diseño y es la base sobre la que se apoyan las demás secciones (todas dependen del mismo selector de período).

**Independent Test**: Puede probarse por separado entrando al Dashboard y verificando que el saludo, los accesos rápidos y las 4 tarjetas de indicadores se ven con el estilo del diseño de referencia, y que cambiar el período del reporte actualiza esas 4 tarjetas.

**Acceptance Scenarios**:

1. **Given** el Dashboard recién cargado, **When** el usuario lo ve, **Then** aparece un saludo según la hora del día (p. ej. "Buenos días"/"Buenas tardes"/"Buenas noches") seguido del nombre del usuario, y debajo "Esto es lo que pasa hoy en tu negocio.".
2. **Given** el Dashboard, **When** el usuario lo ve, **Then** los accesos rápidos a los módulos (Terminal de mesas, Ventas, Caja, Carta del menú, Mesas) aparecen inmediatamente debajo del saludo, antes del reporte operativo.
3. **Given** el selector de período del reporte operativo, **When** el usuario elige un período distinto, **Then** las 4 tarjetas de indicadores (ventas totales, órdenes, ticket promedio, órdenes activas) se actualizan con los valores de ese período.
4. **Given** un período sin ventas, **When** se muestran los indicadores, **Then** cada tarjeta muestra su valor real en cero, nunca un espacio vacío ni un guion.

---

### User Story 2 - Ver la tendencia reciente de ventas, órdenes o ticket promedio en el nuevo gráfico interactivo (Priority: P2)

El personal administrativo necesita ver, en un gráfico de líneas, cómo se comportó un indicador (ventas, número de órdenes o ticket promedio) día a día en los días más recientes, pudiendo alternar entre los tres indicadores, con el total destacado arriba y el detalle de cada punto visible al pasar el cursor (revisión posterior a la primera entrega: el diseño de referencia usaba barras).

**Why this priority**: Es la sección de análisis más usada después de los indicadores; es independiente del período elegido en la Historia 1 (siempre muestra la tendencia diaria más reciente, sin importar qué período esté seleccionado arriba), así que aporta valor por sí sola, pero es el siguiente nivel de detalle que el negocio consulta después de ver los indicadores.

**Independent Test**: Puede probarse por separado abriendo el Dashboard, verificando que el panel "Estadísticas de ventas" muestra el total del indicador elegido y un gráfico de líneas día a día, que alternar entre Ventas/Órdenes/Ticket promedio cambia lo que se grafica, y que pasar el cursor sobre la línea muestra su fecha y su valor exacto.

**Acceptance Scenarios**:

1. **Given** el panel "Estadísticas de ventas", **When** se muestra, **Then** aparece el total del indicador elegido (Ventas, Órdenes o Ticket promedio) de los días más recientes en grande, con su etiqueta debajo, y un gráfico de líneas con el detalle día a día.
2. **Given** las pestañas "Ventas"/"Órdenes"/"Ticket promedio", **When** el usuario elige una distinta, **Then** el total grande y el gráfico de líneas cambian para reflejar ese indicador, sin que el período elegido en la Historia 1 se vea afectado (son independientes).
3. **Given** el gráfico de líneas, **When** el usuario pasa el cursor (o toca, en pantallas táctiles) sobre un punto, **Then** aparece la fecha exacta y el valor de ese punto.
4. **Given** días recientes sin datos de ventas, **When** se muestra el panel, **Then** el gráfico se presenta vacío de forma clara, sin datos inventados.

---

### User Story 3 - Ver los productos más vendidos y las ventas por categoría con el nuevo diseño visual (Priority: P3)

El personal administrativo necesita ver qué productos se venden más (pudiendo alternar entre verlo por cantidad vendida o por ingresos) y cómo se reparten las ventas entre categorías, con la presentación visual del diseño de referencia.

**Why this priority**: Es información que el negocio ya consulta hoy (existe en el Dashboard actual); esta historia solo actualiza cómo se ve y añade la forma de alternar entre cantidad e ingresos, sin depender de datos nuevos.

**Independent Test**: Puede probarse por separado verificando que la sección "Más vendidos" permite alternar entre "cantidad" e "ingresos", y que "Ventas por categoría" muestra el reparto por categoría con el estilo visual del diseño de referencia.

**Acceptance Scenarios**:

1. **Given** la sección "Más vendidos", **When** el usuario alterna entre ver por cantidad o por ingresos, **Then** el orden y las barras de los productos se recalculan según el criterio elegido.
2. **Given** la sección "Ventas por categoría", **When** se muestra, **Then** aparece el reparto de ventas entre categorías con su porcentaje de participación, en un gráfico circular con su leyenda (revisión posterior a la primera entrega: antes era una barra apilada horizontal).
3. **Given** un período sin ventas de productos o sin categorías con ventas, **When** se muestran estas secciones, **Then** cada una indica con claridad que no hay datos, sin inventar productos ni porcentajes.

---

### User Story 4 - Ver los ingresos por método de pago (Priority: P4)

El personal administrativo necesita ver cuánto ha entrado por cada método de pago (efectivo, tarjeta, transferencia, etc.) a lo largo del período elegido en el reporte operativo, pudiendo filtrar por método, igual que en el diseño de referencia.

**Why this priority**: Es contenido completamente nuevo en el Dashboard (no existe hoy en ninguna forma); aporta valor por sí solo pero no es indispensable para las demás secciones, que ya funcionan sin él.

**Independent Test**: Puede probarse por separado verificando que la sección "Ingresos por método de pago" muestra el total de cada método y un gráfico con la unidad de tiempo correspondiente al período elegido, y que seleccionar/deseleccionar un método en los filtros actualiza lo que se ve.

**Acceptance Scenarios**:

1. **Given** la sección "Ingresos por método de pago", **When** se muestra, **Then** aparece el total de ingresos de cada método de pago y un gráfico con su detalle en la unidad de tiempo que corresponda al período elegido (por hora, día o semana).
2. **Given** los filtros de método de pago, **When** el usuario desactiva uno, **Then** ese método desaparece del total y del gráfico, dejando los demás visibles.
3. **Given** un período sin ningún pago registrado, **When** se muestra la sección, **Then** se indica con claridad que no hay ingresos en ese período, sin inventar montos.

---

### User Story 5 - Ver la alerta de stock bajo (Priority: P5)

El personal administrativo necesita ver, sin salir del Dashboard, qué insumos están por debajo de su stock mínimo, para decidir si hace falta reabastecer.

**Why this priority**: Es contenido nuevo pero de menor urgencia que las demás historias: el personal ya puede consultar el stock bajo entrando al módulo de Inventario; esta historia solo lo adelanta a la pantalla de entrada.

**Independent Test**: Puede probarse por separado verificando que la sección "Stock bajo" lista los insumos por debajo de su mínimo, con un enlace para ir al inventario completo.

**Acceptance Scenarios**:

1. **Given** insumos con existencia por debajo de su stock mínimo, **When** se muestra el Dashboard, **Then** aparece la sección "Stock bajo" listando cada uno con su cantidad restante.
2. **Given** la sección "Stock bajo", **When** el usuario presiona "Ver inventario", **Then** es llevado al módulo de Inventario.
3. **Given** ningún insumo por debajo de su mínimo, **When** se muestra el Dashboard, **Then** la sección indica claramente que no hay alertas de stock, o se omite, sin mostrar una lista vacía confusa.

---

### Edge Cases

- ¿Qué pasa si el nombre del usuario que inició sesión no está disponible (p. ej. un registro histórico sin nombre configurado)? El saludo debe degradar con elegancia (usando el nombre derivado del correo, igual que hoy) en vez de mostrar un espacio vacío o un error.
- ¿Qué pasa con los accesos rápidos en una pantalla angosta (tablet/móvil)? Deben apilarse o ajustar su cuadrícula sin cortar texto ni iconos.
- ¿Qué pasa si el usuario cambia el período del reporte mientras el gráfico de "Ingresos por método de pago" todavía está cargando? La sección debe mostrar su propio estado de carga sin bloquear el resto del Dashboard.
- ¿Qué pasa con un insumo cuyo stock mínimo es cero o no está configurado? Nunca debe aparecer en "Stock bajo" como si tuviera una alerta inventada.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST mostrar, al entrar al Dashboard, un saludo según la hora del día seguido del nombre de la persona que inició sesión, y el subtítulo "Esto es lo que pasa hoy en tu negocio.", reemplazando el saludo genérico actual.
- **FR-002**: El sistema MUST mostrar los accesos rápidos a los módulos inmediatamente debajo del saludo, antes del reporte operativo (reordenando su posición actual).
- **FR-003**: El sistema MUST mostrar los indicadores del reporte operativo vigente (ventas totales, número de órdenes, ticket promedio y órdenes activas) como una fila de 4 tarjetas separadas por una línea divisoria, cada una con su etiqueta, su valor y un texto secundario descriptivo (p. ej. "Total del período", "Por orden"), con el mismo selector de período ya existente (turno actual, turno específico, día, semana, mes, rango personalizado).
- **FR-004**: El sistema MUST mostrar un panel "Estadísticas de ventas" con pestañas para alternar entre Ventas, Órdenes y Ticket promedio; el indicador elegido se muestra en grande junto con un gráfico de líneas de su evolución día a día en los días más recientes, independiente del período elegido en el reporte operativo (FR-003), donde pasar el cursor (o tocar) sobre un punto muestra su fecha y su valor exacto. (Revisión posterior a la primera entrega: el diseño de referencia y la primera versión de este FR especificaban un gráfico de barras.)
- **FR-005**: El sistema MUST permitir alternar la sección "Más vendidos" entre verla por cantidad vendida y por ingresos.
- **FR-006**: El sistema MUST mostrar "Ventas por categoría" con el reparto de ventas entre categorías y su porcentaje de participación, en un gráfico circular con su leyenda de color/nombre/%/monto. (Revisión posterior a la primera entrega: research.md §5 documentó conservar la barra apilada horizontal ya existente; el negocio pidió la forma circular en su lugar.)
- **FR-007**: El sistema MUST mostrar una sección "Ingresos por método de pago" con el total de cada método de pago y un gráfico de su detalle a lo largo del tiempo, con filtros para incluir/excluir cada método. La unidad de tiempo del gráfico MUST adaptarse al período elegido en el reporte operativo (FR-003): por hora cuando el período es un turno (actual o específico) o un día, diaria cuando es una semana, semanal cuando es un mes, y diaria sobre el rango cuando es un rango personalizado — igual que el diseño de referencia. Esto requiere una fuente de datos nueva en el backend con varias agregaciones (ninguna existente agrupa ingresos por método de pago en estas unidades de tiempo); autorizado explícitamente (Clarifications).
- **FR-008**: El sistema MUST mostrar una sección "Stock bajo" listando los insumos con existencia por debajo de su stock mínimo configurado, con su cantidad restante y un enlace al módulo de Inventario.
- **FR-009**: El sistema MUST NOT mostrar ya las tarjetas "Usuarios" y "Productos" (la lista "Órdenes recientes" ya se había retirado antes de esta feature, research.md §6) — se retiran junto con las dos llamadas HTTP independientes (`UsersService.loadUsers()`, `ProductService.loadProducts()`) que solo alimentaban sus valores, sin dejar peticiones huérfanas. (Revisión posterior a la primera entrega: la Clarification original de este FR pedía conservarlas; el negocio pidió retirarlas después de ver la primera versión del rediseño.)
- **FR-010**: El sistema MUST mostrar, en el saludo (FR-001), el nombre real de la persona que inició sesión, expuesto por el backend en el token/datos de sesión (hoy el frontend solo deriva un nombre a partir del correo). Si ese nombre no está disponible para un usuario puntual, el saludo MUST degradar con elegancia (p. ej. usando el nombre derivado del correo como respaldo) en vez de mostrar un espacio vacío.
- **FR-011**: Las secciones ya existentes que el diseño de referencia conserva (reporte operativo, más vendidos, ventas por categoría) MUST seguir usando los mismos datos y reglas de negocio ya calculados por el sistema; este rediseño no cambia cómo se calculan las ventas, los tickets promedio ni las categorías.
- **FR-012**: El rediseño MUST NOT alterar el comportamiento de los accesos rápidos, del selector de período, ni de ninguna otra pantalla a la que el Dashboard enlaza.

### Key Entities

- **Reporte operativo**: Igual que hoy (spec 119): período elegido, caja, ventas totales, número de órdenes, ticket promedio, productos más vendidos, ventas por categoría.
- **Indicador del Dashboard (KPI)**: Una de las 4 tarjetas del reporte operativo: etiqueta, valor y texto secundario descriptivo.
- **Ingreso por método de pago**: Monto total por método de pago (efectivo, tarjeta, transferencia, etc.) y su detalle en la unidad de tiempo (hora, día o semana) que corresponda al período elegido en el reporte operativo.
- **Alerta de stock bajo**: Un insumo cuya existencia actual está por debajo de su stock mínimo configurado, con el nombre del insumo y la cantidad restante.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El personal administrativo identifica, sin instrucciones adicionales, el saludo, los accesos rápidos y los 4 indicadores del turno en los primeros 5 segundos de entrar al Dashboard.
- **SC-002**: El 100% de las secciones que vienen del diseño de referencia (saludo, accesos rápidos, indicadores, tendencia de ventas, más vendidos, ventas por categoría, ingresos por método de pago, stock bajo) usan su estilo visual, tanto en pantallas de escritorio como en pantallas angostas; las tarjetas "Usuarios"/"Productos" ya no están en el Dashboard (FR-009).
- **SC-003**: El personal identifica cuánto ha entrado por cada método de pago en el período que esté viendo, sin salir del Dashboard ni abrir el módulo de Ventas.
- **SC-004**: El personal identifica qué insumos necesitan reabastecerse sin salir del Dashboard ni abrir el módulo de Inventario.
- **SC-005**: Cero regresiones: el selector de período, los accesos rápidos y la navegación a otros módulos desde el Dashboard siguen funcionando exactamente igual que antes del rediseño.

## Assumptions

- Las "pestañas de tendencia" del diseño de referencia (encima del gráfico de "Estadísticas de ventas") alternan QUÉ indicador se grafica (Ventas, Órdenes o Ticket promedio), no la unidad de tiempo: el gráfico siempre es día a día sobre los días más recientes, con una ventana propia e independiente del período elegido en el reporte operativo (FR-003) — las dos selecciones no se afectan entre sí.
- El cuarto indicador del reporte operativo (junto a ventas totales, órdenes y ticket promedio) es "Órdenes activas en cocina" — mismo dato que calculaba la antigua tarjeta "Órdenes activas" (ya retirada), incorporado a la cuadrícula de 4 del reporte operativo, que sí sigue el período elegido.
- La sección "Ingresos por método de pago" reutiliza los métodos de pago ya configurados en el sistema y el mismo período elegido en el reporte operativo (FR-003) para decidir la unidad de tiempo del gráfico (FR-007). La nueva fuente de datos que esto requiere en el backend (Clarifications) se limita a esa consulta/agregación; no cambia cómo se registran ni se calculan los pagos ya existentes.
- "Stock bajo" reutiliza el umbral de stock mínimo que cada insumo ya tiene configurado en Inventario; este rediseño no introduce una nueva regla para definir qué es "stock bajo".
- El nombre real de la persona que inició sesión (Clarifications) se expone a través del mismo mecanismo de sesión ya existente (backend); esto no cambia cómo se autentican los usuarios ni qué pueden hacer, solo qué dato de perfil queda disponible para mostrarlo.
- El rediseño aplica únicamente a la vista principal del Dashboard (`/dashboard`); no se extiende a otras pantallas que puedan compartir componentes visuales con ella.
