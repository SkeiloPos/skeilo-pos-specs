# Feature Specification: Reportes operativos por turno de caja

**Feature Branch**: `119-reportes-ventas-turno`

**Created**: 2026-10-15

**Status**: US1–US5 implementadas (falta el recorrido manual T036); US6 planificada y con tareas, sin código

**Input**: User description: "Implementar un sistema de reportes operativos basado en turnos de
caja (`opened_at` a `closed_at`) en lugar de depender exclusivamente de cortes por fecha
calendario. El objetivo es permitir a los administradores y dueños de la heladería auditar con
exactitud las ventas, órdenes, pedidos activos, ticket promedio, productos más vendidos y ventas
por categoría por cada turno, garantizando que los turnos nocturnos que cruzan la medianoche no
contaminen los reportes de días distintos y reflejen fielmente el dinero ingresado. RN1
(vinculación de pago): toda orden y todo pago quedan vinculados al turno que estaba abierto en el
momento exacto del cobro. RN2 (atribución temporal): una venta se atribuye al turno donde se
registró el pago, no donde se creó la orden. RN3 (delimitación del turno): el reporte de turno
cubre todo lo registrado entre `opened_at` y `closed_at`, aunque cruce la medianoche. RN4 (fecha
operativa y filtros): el reporte 'del día' suma los turnos cuya fecha de apertura (zona horaria
del tenant) corresponde a ese día; semana/mes/rango se filtran por la fecha operativa del turno,
no por la hora individual de cada venta. RN5 (cierre seguro): no se permite cerrar un turno si
existen pedidos activos; el sistema bloquea la acción y exige cobrar o anular esos pedidos. RN6
(independencia por caja y multi-tenant): cada caja gestiona sus turnos de forma independiente; los
reportes se pueden filtrar por caja específica, con aislamiento multi-tenant absoluto."

## Contexto y comportamiento actual

**Esta funcionalidad cambia comportamiento existente en dos puntos concretos.** A diferencia del
resto de esta spec (que describe el comportamiento deseado en términos de negocio), esta sección
sí nombra archivos y mecanismos concretos del código actual — es la evidencia que sustenta,
conforme al Principio II de la [Constitución](../../.specify/memory/constitution.md), que estos
dos cambios son decisiones de negocio explícitas y no vacíos accidentales:

1. **La tarjeta "Ingresos hoy" del panel de inicio hoy corta por fecha calendario, no por
   turno.** En `pos-heladeria`, `admin-dashboard.component.ts` calcula `todayRevenue`/`todayCount`
   filtrando `salesService.sales()` con `new Date(s.sold_at).toDateString() === today` (fecha
   calendario del navegador, basada en el momento de cada venta individual). Esta spec reemplaza
   esa lógica por la atribución por turno que exige RN4: el corte "del día" pasa a sumar los
   turnos cuya fecha de **apertura** cae en ese día, sin importar la hora de cada venta
   individual dentro del turno.
2. **El cierre de un turno hoy no verifica pedidos activos.** `specs/006-turnos-caja-arqueo`
   (ingeniería inversa de `pos-backend/app/api/v1/cash/service.py::close_shift`) documenta las
   reglas `RN-CASH-01` a `RN-CASH-18` vigentes sobre el cierre de turno, y ninguna de ellas
   bloquea el cierre por la existencia de pedidos sin cobrar — hoy es posible cerrar un turno con
   pedidos pendientes de pago. RN5 de esta spec introduce esa restricción como un comportamiento
   nuevo.

Por lo anterior, conforme al Principio II de la constitución del proyecto, ambos cambios deben
quedar registrados como decisión de negocio en
`specs/000-reconocimiento/registro-de-anomalias.md` antes de implementarse (ver FR-016).

## Clarifications

### Session 2026-10-15

- Q: ¿Dónde debe mostrarse este reporte operativo respecto al "resumen de caja" (arqueo de
  efectivo) que ya existe por turno? → A: No se crea una pantalla nueva de reportes ni se amplía
  el resumen de arqueo de cierre de turno — el reporte operativo (ventas totales, órdenes, ticket
  promedio, top de productos, ventas por categoría, pedidos activos) se muestra en la pantalla de
  inicio del panel de administración (`admin-dashboard.component.ts`), con selector de período
  (turno actual, turno específico, día, semana, mes, rango personalizado) y de caja.
- Q: ¿Qué cuenta exactamente como "pedido activo" para la validación de cierre seguro (RN5)? → A:
  Únicamente los pedidos (de mesa, para llevar o domicilio) que todavía no se han cobrado por
  completo (pendientes o con pago parcial). Un pedido ya pagado que sigue en preparación/cocina
  **no** cuenta como "activo" para efectos de esta validación — no bloquea el cierre.
- Q: El planteamiento original ofrecía "Cobrar", "Anular" o "Transferir al siguiente turno" como
  acciones ante pedidos activos al cerrar. ¿Qué pasa si el turno siguiente aún no existe? → A: La
  acción "Transferir al siguiente turno" **no se implementa**. Mientras existan pedidos activos
  (sin cobrar), el cierre del turno queda bloqueado sin excepción; el cajero solo puede elegir
  entre **cobrar** o **anular** cada pedido activo para poder cerrar. No existe ninguna vía para
  cerrar un turno con pedidos activos pendientes.
- Q: Para un turno ya cerrado, ¿el reporte operativo debe recalcularse siempre en vivo o quedar
  congelado al momento del cierre? → A: Se congela (snapshot inmutable) al cerrar el turno, igual
  que ya exige `specs/006-turnos-caja-arqueo` (`RN-CASH-17`) para el arqueo de efectivo. Si una
  venta de un turno ya cerrado se anula después, el reporte operativo de ese turno no cambia.
- Q: ¿Qué debe pasar con la pantalla ya existente `/dashboard/reports` ("Reportes", separada de la
  pantalla de inicio, que ya calcula ventas/top de productos/ventas por categoría pero por fecha
  calendario de cada venta individual) una vez implementado este reporte por turno en la pantalla
  de inicio? → A: Esa pantalla queda intacta, sin ningún cambio (sigue por fecha calendario); el
  reporte por turno de esta spec vive únicamente en la tarjeta de inicio del panel de
  administración. Ambas vistas coexisten con criterios de atribución distintos — es un
  comportamiento esperado, no una inconsistencia, que puedan mostrar cifras distintas para "hoy".
- Q: Si el tenant tiene varias cajas con turno abierto al mismo tiempo y el administrador elige la
  opción de período "Turno actual" sin filtrar por caja, ¿qué debe mostrar el reporte? → A: Agrega
  (suma en tiempo real) todos los turnos actualmente abiertos de todas las cajas del tenant, con el
  mismo criterio de agregación sin filtro de caja que ya aplica al reporte "del día" (US2).
- Q: Cuando el reporte agrega varios turnos (semana/mes/rango), ¿el snapshot de cada turno debe
  guardar el desglose completo de ventas por producto/categoría, o basta con guardar solo su propio
  top-N ya recortado? → A: El snapshot de cada turno guarda el desglose COMPLETO de ventas por
  producto y por categoría (no solo el top-N visible); los reportes de período se recalculan
  sumando esos desgloses completos, dando un top-N exacto a nivel de período — consistente con la
  meta explícita de "auditar con exactitud" del planteamiento original.
- Q: El supuesto original de esta spec dejaba "semana"/"mes" condicionados a un estándar previo en
  el código; la investigación de `research.md` (D4) encontró que el único precedente real
  (`/dashboard/reports`) usa una ventana móvil de 7/30 días, no semana calendario — ¿se confirma esa
  ventana móvil o se usa semana/mes calendario? → A: Semana/mes **calendario**: "semana" cubre de
  lunes a domingo de la semana a la que pertenece la fecha operativa consultada; "mes" cubre del
  día 1 al último día del mes calendario correspondiente — no la ventana móvil de 7/30 días que usa
  `/dashboard/reports` para su propio criterio de atribución por fecha de venta individual, criterio
  que esta spec no reutiliza para el reporte por turno.

### Session 2026-10-15 (ampliación US6 — rendimiento de reportes de período)

- Q: Hoy, en un empate exacto de ingresos, el orden del top de productos y de las categorías
  depende del orden accidental en que se recorren los turnos y las filas — no es determinista.
  ¿Se replica ese orden o se fija un criterio explícito? → A: Se fija un criterio explícito y
  estable: ingreso descendente; en empate, nombre ascendente; en empate de nombre, identificador
  ascendente. Se acepta que, solo en empates exactos, el orden pueda diferir del actual (que era
  accidental). Además se **conserva** la regla actual del nombre mostrado de cada producto: dentro
  de un turno, el mayor valor de su descripción registrada; en la agregación de un período, el
  nombre del turno más antiguo (por fecha/hora de apertura) en que aparece esa variante.
- Q: ¿La spec exige cambiar cómo se almacena el desglose congelado de cada turno para poder
  recombinarlo en la base de datos? → A: No. La spec solo exige que la recombinación y el recorte
  al top-N se resuelvan en la base de datos (FR-019); la forma de almacenamiento se decide en
  `plan.md`.
- Q: ¿Se genera un snapshot retroactivo para los turnos cerrados antes de esta spec (D8)? → A: No.
  Siguen calculándose en vivo como hoy, pero en lote junto con los demás turnos del período, nunca
  uno por uno.
- Q: ¿Cómo se verifica que el costo no crece con el número de turnos? → A: La compuerta automática
  es un test que cuenta consultas (1 turno frente a 186 turnos: mismo número fijo). Los umbrales de
  tiempo y la verificación de uso de índices se hacen como verificación manual en `quickstart.md`,
  sobre un tenant desechable con datos de volumen que se elimina al terminar.
- Q: ¿El cierre de turno solo necesita un índice, o también dejar de traer todos los pedidos
  activos para contarlos? → A: Ambas cosas: el contador de pedidos activos se obtiene contando en
  la base de datos, y la lista completa solo se obtiene cuando el cierre queda bloqueado y hay que
  mostrarla. El resultado visible no cambia.
- Q: ¿Se impone un tope al rango personalizado? → A: No, sin tope (sería un cambio de
  comportamiento visible).
- Q: Para bloquear el cierre de un turno, ¿qué pedidos activos se cuentan: los de todo el negocio o
  solo los asociados a ese turno/caja? → A: Los de **todo el negocio** (tenant): cualquier pedido
  sin cobrar, de cualquier caja y canal, bloquea el cierre de cualquier turno (`research.md` D1, ya
  implementado). El modelo de datos actual no liga un pedido para llevar/domicilio a ninguna caja.
- Q: En producción, ¿los índices nuevos de FR-021 deben crearse sin bloquear el cobro mientras se
  construyen? → A: Sí, obligatorio: se crean sin bloquear escrituras sobre ventas, turnos ni
  pedidos; la migración se puede repetir sin fallar y `quickstart.md` verifica que cada índice quedó
  válido.
- Q: Si se crea un pedido justo entre el conteo de pedidos activos y el guardado del cierre, ¿el
  sistema debe garantizar que ese cierre se rechace? → A: No (mejor esfuerzo): se acepta esa
  ventana de milisegundos, sin coordinar el cierre con la creación de pedidos; el pedido sigue
  activo y bloquea el cierre del siguiente turno. SC-002 se precisa a los pedidos existentes al
  confirmar el cierre.

### Session 2026-10-15 (resultado de `/speckit-analyze`)

- Q: FR-008 decía "ofreciendo únicamente las acciones Cobrar o Anular sobre cada uno", pero la
  interfaz implementada lista cada pedido con un enlace a su detalle y la indicación de resolverlo
  desde las pantallas existentes, sin botones propios. ¿Cuál es el comportamiento correcto? → A: El
  implementado: la lista enlaza cada pedido a su detalle y exige cobrarlo o anularlo desde las
  pantallas de pedidos existentes; no hay botones propios de cobro o anulación (cobrar implica el
  flujo de pago completo). Se ajustan FR-008 y el escenario 1 de US3 a esa redacción.
- Q: El contador de pedidos activos que acompaña al reporte de un turno abierto (FR-012), ¿es de la
  caja filtrada o de todo el tenant? → A: De todo el tenant, con el mismo alcance que el bloqueo de
  cierre (FR-007), porque un pedido no está ligado a una caja. En "Turno actual" el cliente lo
  obtiene de la lista de pedidos activos (no viaja en la respuesta del reporte de período, para no
  cambiar los contratos de US6).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Reporte exacto de un turno que cruza la medianoche (Priority: P1)

Un administrador consulta el reporte operativo de un turno específico (por ejemplo, el turno
nocturno de una caja que abrió a las 17:00 y cerró a las 02:00 del día siguiente) y ve las ventas
totales, el número de órdenes, el ticket promedio, el top de productos y las ventas por categoría
calculados exclusivamente con las órdenes cobradas dentro de ese turno — sin que la fecha
calendario de cada venta individual afecte el resultado.

**Why this priority**: es el comportamiento central que motiva todo el spec — sin atribución
correcta por turno, cualquier otro reporte derivado (del día, de la semana, del mes) hereda el
mismo error de fondo.

**Independent Test**: se puede probar abriendo un turno a las 17:00, registrando ventas antes y
después de la medianoche, cerrándolo a las 02:00, y consultando el reporte de ese turno por su
identificador.

**Acceptance Scenarios**:

1. **Given** un turno de "Caja 1" abierto el 12/10 a las 17:00 que registró ventas por $300.000
   antes de las 23:59 y $150.000 entre las 00:00 y las 01:50 del 13/10, cerrado a las 02:00,
   **When** el administrador consulta el reporte de ese turno, **Then** visualiza ventas totales
   de $450.000, con el ticket promedio, el top de productos y las ventas por categoría calculados
   exclusivamente con las órdenes cobradas en esa sesión.
2. **Given** ese mismo turno, **When** el administrador lo consulta filtrando además por la
   "Caja 1", **Then** el resultado no cambia respecto al escenario 1 — el filtro de caja es
   coherente con el turno consultado.

---

### User Story 2 - Reporte "del día" libre de contaminación nocturna (Priority: P1)

Un administrador consulta, desde la pantalla de inicio, el reporte operativo del día. El sistema
suma únicamente los turnos cuya fecha de **apertura** (en la zona horaria del tenant) corresponde
a ese día — un turno nocturno que abrió el día anterior y cerró de madrugada se reporta íntegro en
el día en que abrió, nunca repartido entre dos días.

**Why this priority**: es el escenario de uso diario más frecuente del administrador (la vista por
defecto de la pantalla de inicio) y el que verifica que RN3/RN4 se cumplen de extremo a extremo,
no solo para un turno aislado.

**Independent Test**: se puede probar con dos turnos de la misma caja — uno abierto el día 12 a
las 17:00 y cerrado el día 13 a las 02:00, y otro abierto el día 13 a las 17:00 — consultando el
reporte del día 13 y verificando qué turnos incluye.

**Acceptance Scenarios**:

1. **Given** un turno de "Caja 1" abierto el 12/10 a las 17:00 y cerrado el 13/10 a las 02:00, y
   otro turno de la misma caja abierto el 13/10 a las 17:00, **When** el administrador consulta el
   reporte del día 13/10 desde la pantalla de inicio, **Then** solo se incluye el turno abierto el
   13/10 — las ventas registradas entre las 00:00 y las 02:00 del 13/10 se contabilizan en el
   reporte del día 12/10, como parte del turno que las originó.
2. **Given** un tenant con varias cajas con turnos abiertos el mismo día, **When** se consulta el
   reporte del día sin filtrar por caja, **Then** el resultado agrega los turnos de todas las
   cajas cuya fecha de apertura cae en ese día.
3. **Given** el mismo reporte, **When** el administrador cambia el período a semana, mes o un
   rango de fechas personalizado, **Then** el sistema filtra los turnos incluidos por su fecha
   operativa de apertura (no por la hora de cada venta individual), aplicando el mismo criterio de
   atribución que en el escenario 1.

---

### User Story 3 - Cierre de turno bloqueado mientras existan pedidos activos (Priority: P1)

Un cajero intenta cerrar un turno que todavía tiene pedidos sin cobrar. El sistema bloquea la
operación, muestra la lista de esos pedidos activos y exige que el cajero los cobre o los anule
uno por uno antes de poder cerrar — no existe ninguna otra vía para completar el cierre.

**Why this priority**: es la garantía operativa que impide que dinero pendiente de cobro
desaparezca del arqueo del turno en el que ocurrió; sin ella, los reportes de ventas y de efectivo
de ambas US1/US2 pueden quedar incompletos de forma silenciosa.

**Independent Test**: se puede probar creando un pedido sin cobrar sobre un turno abierto e
intentando cerrarlo; luego cobrando o anulando ese pedido y repitiendo el cierre.

**Acceptance Scenarios**:

1. **Given** un turno abierto y 2 pedidos activos (sin cobrar) en el tenant, **When** el cajero intenta
   cerrar el turno, **Then** el sistema bloquea la operación y muestra la lista de esos 2 pedidos,
   enlazando cada uno a su detalle y exigiendo resolverlo —cobrándolo o anulándolo desde las
   pantallas de pedidos existentes— antes de reintentar el cierre; no ofrece ninguna otra vía.
2. **Given** el mismo turno, **When** el cajero cobra o anula ambos pedidos activos, **Then** el
   cierre de turno puede completarse con normalidad, sin pedidos pendientes.
3. **Given** un turno sin ningún pedido activo, **When** el cajero intenta cerrarlo, **Then** el
   sistema no presenta ningún bloqueo relacionado con pedidos — se comporta igual que hoy respecto
   al resto de las reglas de cierre (`specs/006-turnos-caja-arqueo`).

---

### User Story 4 - Reporte en tiempo real de un turno en curso (Priority: P2)

Un administrador consulta el reporte operativo de un turno que todavía está abierto. El sistema
muestra las métricas acumuladas hasta ese momento, etiqueta claramente el reporte como "Turno en
curso" y muestra el número de pedidos activos pendientes de cobro en ese momento.

**Why this priority**: da visibilidad operativa durante el día sin esperar al cierre, pero depende
de que US1 ya calcule correctamente las métricas por turno — por eso es P2 y no P1.

**Independent Test**: se puede probar abriendo un turno, registrando algunas ventas y dejando un
pedido sin cobrar, y consultando su reporte mientras sigue abierto.

**Acceptance Scenarios**:

1. **Given** un turno actualmente abierto con ventas registradas, **When** el administrador
   consulta su reporte operativo, **Then** visualiza las métricas acumuladas hasta ese instante,
   una etiqueta visible "Turno en curso" y el contador de pedidos activos actuales.
2. **Given** ese mismo turno, **When** se cierra posteriormente, **Then** el reporte deja de
   mostrar la etiqueta "Turno en curso" y sus métricas quedan congeladas con los valores del
   momento del cierre (ver Assumptions, snapshot inmutable).

---

### User Story 5 - Reporte limpio para un turno sin ventas (Priority: P3)

Un administrador consulta el reporte de un turno que se abrió y cerró sin registrar ninguna orden
pagada. El sistema no genera ningún error: muestra ventas, órdenes y ticket promedio en cero, y
presenta el top de productos y las ventas por categoría como un estado vacío claro.

**Why this priority**: es un caso borde de baja frecuencia (turno abierto por error o jornada sin
movimiento), pero necesario para que el reporte nunca se rompa ante datos insuficientes.

**Independent Test**: se puede probar abriendo un turno y cerrándolo de inmediato sin registrar
ninguna venta, y consultando su reporte.

**Acceptance Scenarios**:

1. **Given** un turno abierto y cerrado sin ninguna orden pagada, **When** el administrador
   consulta su reporte, **Then** las ventas totales, el número de órdenes y el ticket promedio se
   muestran en `0`, y el top de productos y las ventas por categoría se presentan como un estado
   vacío, sin excepciones ni mensajes de error.

---

### User Story 6 - Reportes de período rápidos sin importar cuántos turnos contienen (Priority: P2)

Un administrador consulta el reporte de un mes o de un rango largo y obtiene exactamente los mismos
números que hoy, en un tiempo que no aumenta de forma notable aunque el período contenga cientos de
turnos. De igual forma, un cajero que intenta cerrar su turno obtiene la verificación de pedidos
activos con rapidez aunque el historial de pedidos del negocio crezca indefinidamente.

**Why this priority**: es una mejora de rendimiento sin cambio de comportamiento visible. Hoy el
costo de un reporte crece con cada turno del período y compite con el cobro por los mismos recursos;
con más cajas, más turnos por día y más meses de historia, el reporte se volvería lento. No es P1
porque los resultados actuales ya son correctos (US1–US5).

**Independent Test**: se puede probar comparando, para el mismo conjunto de datos, el reporte de un
período con 1 turno y uno con 186 turnos (3 cajas × 2 turnos/día × 31 días): ambos deben ejecutar
el mismo número fijo de consultas y devolver los mismos valores que la implementación anterior.

**Acceptance Scenarios**:

1. **Given** el Turno A (cerrado, con snapshot): Cono doble 10 u / $50.000 y Malteada 4 u / $36.000
   (total $86.000, 6 órdenes), y el Turno B (abierto): Cono doble 6 u / $30.000 y Paleta 20 u /
   $40.000 (total $70.000, 4 órdenes), ambos dentro del mismo período, **When** el administrador
   consulta el reporte de ese período, **Then** visualiza ventas totales de $156.000, 10 órdenes,
   ticket promedio de $15.600 y el top de productos en este orden: Cono doble 16 u / $80.000;
   Paleta 20 u / $40.000; Malteada 4 u / $36.000.
2. **Given** un mes con 186 turnos (3 cajas × 2 turnos/día × 31 días), **When** el administrador
   consulta el reporte del mes, **Then** el sistema ejecuta exactamente la misma cantidad de
   consultas que para un período con un único turno, y los valores coinciden al centavo con los de
   la implementación anterior.
3. **Given** un período que mezcla turnos cerrados con snapshot, turnos abiertos y turnos cerrados
   antes de esta spec sin snapshot (D8), **When** se consulta su reporte, **Then** el resultado es
   idéntico al actual y la cantidad de consultas no depende de cuántos turnos hay de cada tipo.
4. **Given** un tenant con un historial muy grande de pedidos ya cobrados o anulados, **When** un
   cajero intenta cerrar su turno, **Then** la verificación de pedidos activos responde en ≤ 200 ms
   (SC-010) y con el mismo resultado de hoy (bloqueo con la lista si hay pedidos activos; ningún
   bloqueo si no los hay).

---

### Edge Cases

- **Aislamiento multi-tenant y por caja**: todo reporte (de un turno, del día, de la semana, del
  mes o de un rango) únicamente puede incluir turnos, órdenes y pedidos del tenant autenticado; un
  filtro por caja específica ("Caja 1") nunca expone datos de otra caja ni de otro tenant, sin
  excepción.
- **Ticket promedio sin órdenes**: cuando el número de órdenes pagadas es cero, el ticket promedio
  se muestra como `0`, nunca como un error de división por cero ni como un valor indefinido.
- **Pedido activo que se ancla fuera de una mesa** (para llevar, domicilio): cuenta igual que un
  pedido de mesa para efectos del bloqueo de cierre (US3) — la validación de "pedido activo" no
  distingue el canal del pedido.
- **Varias cajas con turno abierto**: un pedido activo creado desde la "Caja 2" también bloquea el
  cierre del turno de la "Caja 1" — el bloqueo evalúa los pedidos activos de todo el tenant
  (FR-007), porque un pedido no queda ligado a una caja específica.
- **Pedido creado durante la confirmación del cierre**: si un pedido se crea en la ventana de
  milisegundos entre la verificación de pedidos activos y el guardado del cierre, el cierre puede
  completarse; no se coordina el cierre con la creación de pedidos (mejor esfuerzo, ver
  Clarifications). Ese pedido sigue activo y bloquea el cierre del siguiente turno de cualquier caja.
- **Pedido que pasa de activo a inactivo mientras el cajero revisa la lista de bloqueo**: si otro
  usuario cobra o anula el pedido mientras el cajero del turno está mirando la lista de pedidos
  activos, un nuevo intento de cierre vuelve a evaluar la lista vigente en ese momento (no la que
  se mostró originalmente).
- **Turno cerrado consultado después de que se anule una de sus ventas**: el reporte operativo de
  ese turno no cambia (snapshot congelado al cierre, ver Clarifications) — la anulación no se
  refleja en este reporte histórico.
- **Reporte de un rango personalizado que incluye turnos todavía abiertos**: los turnos abiertos
  dentro del rango aportan sus métricas calculadas en tiempo real (igual que US4); los turnos ya
  cerrados dentro del mismo rango aportan su snapshot congelado — ambos se agregan juntos sin
  distinción visual adicional más allá de la etiqueta por turno individual.
- **Divergencia esperada frente a la pantalla "Reportes" existente**: para un turno que cruza la
  medianoche, la tarjeta de inicio (por turno) y la pantalla `/dashboard/reports` (por fecha
  calendario) pueden mostrar ventas totales distintas para el mismo día — ambas cifras son
  correctas según su propio criterio de atribución; no se trata de un error (ver Assumptions).
- **Período sin turnos (US6)**: el reporte devuelve totales en cero y listas vacías, igual que hoy,
  sin ejecutar más consultas que un período con turnos.
- **Producto o categoría presente solo en algunos turnos del período (US6)**: se agrega con las
  unidades e ingresos de los turnos donde aparece; su nombre mostrado es el del turno más antiguo
  del período en que aparece (FR-022).
- **Empate exacto de ingresos en el top-N o en las categorías (US6)**: el orden se resuelve por
  nombre ascendente y, si también coincide, por identificador ascendente — siempre el mismo orden
  para los mismos datos (FR-022).
- **Rango personalizado muy largo (US6)**: no se impone un tope de días; el costo en consultas sigue
  siendo el mismo número fijo (FR-018).
- **Filtro por caja y aislamiento multi-tenant bajo la nueva forma de cálculo (US6)**: siguen
  intactos (FR-011, SC-004) — el cálculo en lote nunca mezcla turnos de otra caja filtrada ni de
  otro tenant.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema DEBE vincular toda orden y todo pago al turno de caja que se encontraba
  en estado abierto en el momento exacto en que se registró el cobro (RN1).
- **FR-002**: El sistema DEBE atribuir una venta al turno en el que se registró su pago, no al
  turno vigente en el momento en que se creó la orden (RN2).
- **FR-003**: El reporte operativo de un turno DEBE incluir únicamente las órdenes pagadas entre
  el `opened_at` y el `closed_at` de ese turno, sin importar si ese intervalo cruza la medianoche o
  abarca más de una fecha calendario (RN3).
- **FR-004**: El reporte operativo de un turno DEBE calcular, como mínimo: ventas totales,
  cantidad de órdenes pagadas, ticket promedio, el top de productos más vendidos y las ventas
  desagregadas por categoría, usando exclusivamente las órdenes atribuidas a ese turno (FR-001 a
  FR-003).
- **FR-005**: El reporte operativo "del día" DEBE sumar los turnos cuya fecha de apertura
  (`opened_at`), expresada en la zona horaria configurada del tenant, corresponde a la fecha
  consultada — independientemente de la hora en que ocurrió cada venta individual dentro de esos
  turnos (RN4).
- **FR-006**: Las consultas del reporte operativo por semana, por mes o por rango de fechas
  personalizado DEBEN filtrar los turnos incluidos por su fecha operativa de apertura (la misma
  noción que FR-005), nunca por la hora individual de cada venta (RN4).
- **FR-007**: El sistema NO DEBE permitir cerrar un turno mientras existan pedidos activos (pedidos
  de mesa, para llevar o domicilio que aún no se han cobrado por completo, ya sea sin pago o con
  pago parcial) en el tenant. El alcance es todo el tenant, no la caja ni el turno que se cierra:
  un pedido activo de cualquier caja bloquea el cierre de cualquier turno (RN5, `research.md` D1).
- **FR-008**: Cuando se bloquee un intento de cierre por FR-007, el sistema DEBE mostrar la lista
  de los pedidos activos que impiden el cierre, enlazando cada uno a su detalle e indicando que solo
  se puede resolver cobrándolo o anulándolo desde las pantallas de pedidos existentes (Mesas, Para
  llevar, Domicilios) — la lista no incorpora acciones propias de cobro o anulación, y no existe una
  acción de "transferir" un pedido activo a otro turno (ver Clarifications).
- **FR-009**: El sistema DEBE permitir completar el cierre del turno en cuanto, para cada pedido
  que estaba activo, se haya completado su cobro o su anulación, sin requerir ninguna otra
  condición adicional relacionada con pedidos.
- **FR-010**: Si un tenant opera varias cajas registradoras, cada caja DEBE gestionar sus propios
  turnos de forma independiente, y los reportes operativos DEBEN poder filtrarse opcionalmente por
  una caja específica (RN6).
- **FR-011**: Todo reporte operativo (de un turno, de un día, de una semana, de un mes o de un
  rango personalizado) DEBE restringirse estrictamente a los datos del tenant autenticado; un
  filtro por caja NO DEBE exponer, bajo ninguna circunstancia, datos de otro tenant ni de otra caja
  distinta a la filtrada (RN6).
- **FR-012**: El reporte operativo de un turno que todavía está abierto DEBE calcularse en tiempo
  real contra las órdenes y pagos registrados hasta el momento de la consulta, etiquetarse
  visiblemente como "Turno en curso" y mostrar el número de pedidos activos pendientes en ese
  instante. Si la opción de período "Turno actual" se consulta sin filtrar por una caja específica
  y el tenant tiene más de una caja con turno abierto simultáneamente, el sistema DEBE agregar en
  tiempo real las métricas de todos los turnos actualmente abiertos de todas las cajas del tenant,
  con el mismo criterio de agregación sin filtro de caja que ya aplica al reporte "del día" (FR-005,
  FR-010). El contador de pedidos activos corresponde a los de **todo el tenant**, con el mismo
  alcance que el bloqueo de cierre (FR-007), también cuando el reporte se filtra por una caja
  específica.
- **FR-013**: Al momento en que un turno se cierra, el sistema DEBE congelar (persistir como
  snapshot inmutable) las métricas de su reporte operativo (ventas totales, cantidad de órdenes,
  ticket promedio, top de productos, ventas por categoría) calculadas en ese instante. Una consulta
  posterior de ese turno DEBE devolver siempre esos valores persistidos, sin recalcularlos contra
  el estado actual de las órdenes, incluso si alguna de las ventas que participó en el cálculo se
  anula después del cierre. Ese snapshot DEBE incluir el desglose COMPLETO de ventas por producto y
  por categoría de ese turno (no únicamente el top-N que se muestra en pantalla), para permitir la
  agregación exacta que exige FR-017.
- **FR-014**: Un turno sin ninguna orden pagada DEBE reportar ventas totales, cantidad de órdenes y
  ticket promedio en `0`, y presentar el top de productos y las ventas por categoría como un
  estado vacío, sin generar errores ni excepciones (RN5 del escenario borde del planteamiento
  original).
- **FR-015**: El reporte operativo "del día" en la pantalla de inicio del panel de administración
  DEBE reemplazar la lógica actual de la tarjeta "Ingresos hoy" (que hoy corta por fecha calendario
  de cada venta individual) por la atribución basada en turno descrita en FR-005, y DEBE
  incorporar un selector de período (turno actual, turno específico, día, semana, mes, rango
  personalizado) y un selector de caja opcional.
- **FR-016**: Los dos cambios de comportamiento existente identificados en esta spec — el corte de
  "Ingresos hoy" por fecha calendario (reemplazado por FR-005/FR-015) y la ausencia actual de
  bloqueo de cierre por pedidos activos (introducida por FR-007) — DEBEN quedar registrados como
  decisión de negocio en `specs/000-reconocimiento/registro-de-anomalias.md`, conforme al
  Principio II de la constitución del proyecto, antes de implementarse.
- **FR-017**: Todo reporte operativo agregado por período (día, semana, mes o rango personalizado)
  DEBE calcular su top de productos y sus ventas por categoría recombinando el desglose completo
  (FR-013) de cada turno incluido, nunca sumando únicamente los top-N ya recortados de cada turno
  individual — de modo que el top de productos y las ventas por categoría a nivel de período sean
  siempre exactos, no una aproximación.
- **FR-018**: El reporte agregado de un período (día, semana, mes o rango) y el reporte de un turno
  puntual DEBEN obtenerse con una cantidad de consultas a la base de datos acotada y constante,
  independiente del número de turnos incluidos y de cuántos de ellos están cerrados con snapshot,
  abiertos o cerrados sin snapshot (D8).
- **FR-019**: La recombinación del desglose completo de productos y categorías (FR-017) y el recorte
  al top-N DEBEN resolverse en la base de datos, sin acumular en memoria del servidor el desglose de
  cada turno incluido.
- **FR-020**: Los turnos incluidos en un período que requieren cálculo en vivo — abiertos (FR-012) o
  cerrados antes de esta spec sin snapshot (D8) — DEBEN calcularse en lote, en las mismas consultas,
  nunca turno por turno. No se genera ningún snapshot retroactivo para los turnos D8.
- **FR-021**: Las búsquedas frecuentes de estos reportes y del cierre de turno — ventas pagadas de un
  turno, turnos por fecha de apertura (con y sin filtro de caja) y pedidos activos del tenant —
  DEBEN estar respaldadas por índices adecuados, de modo que su costo no crezca con el tamaño del
  historial del tenant. Esos índices DEBEN crearse sin bloquear escrituras (cobros, pedidos, apertura
  o cierre de turnos) durante su construcción; la migración DEBE poder ejecutarse de nuevo sin fallar
  si un índice ya existe, y un índice que haya quedado inválido tras una construcción interrumpida
  DEBE detectarse y reconstruirse.
- **FR-022**: Los resultados DEBEN ser idénticos, al centavo, a los que produce la implementación
  anterior para los mismos datos (ventas totales, cantidad de órdenes, ticket promedio, top de
  productos con sus unidades/ingresos/nombre y ventas por categoría), incluidas estas reglas que se
  conservan o se fijan explícitamente:
  - **Nombre mostrado de un producto** (se conserva): dentro de un turno, el mayor valor de su
    descripción registrada; en un período, el nombre del turno más antiguo (por fecha/hora de
    apertura) en que aparece esa variante.
  - **Orden** (se fija): ingreso descendente; en empate, nombre ascendente; en empate de nombre,
    identificador ascendente. Aplica igual al top de productos y a las ventas por categoría. Es el
    único punto en el que el resultado puede diferir del anterior, y solo ante empates exactos de
    ingreso, cuyo orden previo era accidental (ver Clarifications).
- **FR-023**: El contador de pedidos activos que acompaña al reporte de un turno abierto (FR-012) y
  la verificación de bloqueo de cierre (FR-007) DEBEN contar los pedidos activos en la base de
  datos, sin traer todas sus filas; la lista completa de pedidos activos solo se obtiene cuando hay
  que mostrarla (cierre bloqueado, FR-008). El resultado visible (contador, lista y su orden) no
  cambia.

### Key Entities *(include if feature involves data)*

- **CashShift (turno de caja)**: entidad ya existente (`cash_register_id`, `opened_at`,
  `closed_at`, `status` `open`/`closed`). Esta spec no modifica su ciclo de vida existente salvo
  agregar la nueva condición de bloqueo de cierre (FR-007) y la obligación de congelar, al cerrar,
  las métricas de su reporte operativo (FR-013).
- **CashRegister (caja registradora)**: entidad ya existente, usada como criterio de filtro
  opcional de los reportes (FR-010) y como unidad de independencia de turnos (RN6).
- **Pedido / Orden (de mesa, para llevar o domicilio)**: entidad ya existente. Para esta spec, un
  pedido se considera "activo" mientras no se haya cobrado por completo (sin pago o con pago
  parcial); deja de ser "activo" al cobrarse por completo o al anularse. Un pedido no está ligado a
  una caja ni a un turno para efectos del bloqueo de cierre (FR-007 evalúa todo el tenant).
- **Venta / Pago**: entidad ya existente, fuente de las métricas del reporte operativo; se atribuye
  al turno abierto en el momento de registrarse el pago (FR-001, FR-002), nunca al turno vigente
  cuando se creó la orden.
- **Reporte operativo de turno** *(nueva entidad calculada / persistida)*: agregado de ventas
  totales, cantidad de órdenes, ticket promedio, top de productos y ventas por categoría de un
  turno, más el desglose COMPLETO (no solo el top-N) de ventas por producto y por categoría de ese
  turno, necesario para agregar varios turnos con exactitud (FR-017). Mientras el turno está
  abierto, se calcula en tiempo real (FR-012); al cerrarse, se congela como snapshot inmutable
  vinculado a ese turno, incluido ese desglose completo (FR-013).
- **Reporte operativo por período** *(nueva vista agregada, sin entidad propia)*: suma de los
  reportes de turno (en tiempo real o congelados, según corresponda) cuya fecha operativa de
  apertura cae dentro del día, semana, mes o rango personalizado consultado (FR-005, FR-006).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100% de las ventas registradas en un turno que cruza la medianoche se contabilizan
  en el reporte de ese turno y en el reporte del día en que el turno abrió, nunca repartidas entre
  dos días calendario distintos.
- **SC-002**: El 100% de los intentos de cerrar un turno con al menos un pedido activo existente al
  momento de confirmar el cierre quedan bloqueados hasta que todos esos pedidos se cobran o se
  anulan. Solo se exceptúa un pedido creado en la ventana de milisegundos entre la verificación y el
  guardado del cierre (ver Edge Cases), que bloquea el cierre del turno siguiente.
- **SC-003**: El 100% de los reportes de turnos ya cerrados consultados después de una anulación
  posterior de alguna de sus ventas siguen mostrando exactamente los mismos valores que mostraban
  al momento del cierre.
- **SC-004**: El 100% de los reportes consultados (de turno, día, semana, mes o rango) respetan el
  aislamiento multi-tenant y, cuando se filtran por caja, no incluyen ningún dato de otra caja ni
  de otro tenant.
- **SC-005**: Un administrador puede pasar de ver el reporte del día en curso a ver el reporte de
  un turno específico, una semana, un mes o un rango personalizado desde la misma pantalla de
  inicio, sin necesitar navegar a una pantalla distinta.
- **SC-006**: El 100% de los turnos sin ninguna venta consultados muestran su reporte en cero/estado
  vacío, sin ningún error visible para el usuario.
- **SC-007**: El top de productos y las ventas por categoría de cualquier reporte de período
  (semana, mes o rango) coinciden exactamente con el resultado de recalcular esas mismas métricas
  desde cero sobre todas las órdenes pagadas de los turnos incluidos — nunca una aproximación
  derivada de sumar los top-N ya recortados de cada turno.
- **SC-008**: Para el mismo conjunto de datos, los reportes de turno, día, semana, mes y rango
  devuelven exactamente los mismos valores antes y después del cambio de US6 (salvo el orden de
  empates exactos, FR-022): los tests existentes de `test_cash_shift_sales_report.py` siguen
  pasando sin modificarse, y el ejemplo numérico de US6 (escenario 1) cuadra al centavo.
- **SC-009**: Un reporte de período con 1 turno y uno con 186 turnos ejecutan exactamente la misma
  cantidad de consultas a la base de datos, incluido un período que mezcla turnos con snapshot,
  abiertos y D8. Es la compuerta automática de US6 (test que cuenta consultas).
- **SC-010**: Verificación manual en `quickstart.md`, sobre un tenant desechable con datos de
  volumen (que se elimina al terminar):
  - el reporte de un período de 186 turnos sin snapshot (peor caso) responde en ≤ 2 s;
  - el reporte de un período de 186 turnos con snapshot responde en ≤ 1 s;
  - la verificación de pedidos activos responde en ≤ 200 ms con 1.000.000 de pedidos históricos;
  - el plan de ejecución de las consultas de reporte y de pedidos activos no recorre
    secuencialmente las tablas de ventas, líneas de venta ni pedidos; para los turnos y el snapshot
    el camino por índice existe y se usa (en una tabla pequeña el planificador puede preferir
    recorrerla, por lo que se comprueba que el índice está disponible y se usa al descartar el
    recorrido secuencial, no que se prefiera siempre);
  - mientras la migración de índices (FR-021) se ejecuta sobre el tenant con volumen, un cobro
    registrado en paralelo se completa sin quedar esperando a que termine la migración, y al final
    todos los índices nuevos figuran como válidos.

## Assumptions

- **Zona horaria operativa**: la "fecha operativa del turno" (FR-005, FR-006) usa la zona horaria
  ya configurada para el tenant en el resto del sistema (la misma que usan los demás reportes y
  pantallas con fecha/hora); esta spec no introduce una configuración de zona horaria nueva.
- **Semana y mes calendario**: el filtro por "semana" cubre de lunes a domingo de la semana a la que
  pertenece la fecha operativa consultada; el filtro por "mes" cubre del día 1 al último día del mes
  calendario correspondiente (confirmado directamente con el usuario el 2026-10-15, ver
  Clarifications) — **no** la ventana móvil de 7/30 días que usa `/dashboard/reports` para su propio
  criterio de atribución por fecha de venta individual, criterio que esta spec no reutiliza para el
  reporte por turno.
- **Alcance del bloqueo de cierre (FR-007)**: la validación de "pedido activo" se basa únicamente
  en el estado de cobro del pedido (pagado por completo o no), no en su estado de
  preparación/cocina — un pedido ya pagado que sigue en cocina no bloquea el cierre del turno.
- **No se introduce la acción "transferir pedido a otro turno"**: a diferencia del planteamiento
  original del negocio, esta spec fija que esa acción no existe; mientras haya pedidos activos, el
  cierre permanece bloqueado sin ninguna otra vía de salida distinta a cobrar o anular.
- **El reporte operativo vive en la pantalla de inicio del panel de administración**, reemplazando
  y ampliando las tarjetas de resumen que ya existen ahí (incluida "Ingresos hoy"); esta spec no
  crea una pantalla de "Reportes" separada ni modifica la pantalla de resumen de caja/arqueo de
  efectivo que ya existe para el cierre de turno.
- **La pantalla ya existente `/dashboard/reports` ("Reportes") no se modifica.** Esa pantalla
  (`pos-heladeria/src/app/modules/reports/`) ya calcula ventas, top de productos y ventas por
  categoría por fecha calendario de cada venta individual (`GET /reports/sales`,
  `/reports/top-products`, `/reports/categories`); esta spec no la toca ni unifica su criterio con
  el de turno (ver Clarifications). Es un comportamiento esperado, no un defecto, que esa pantalla
  y la nueva tarjeta de inicio muestren cifras distintas para "hoy" cuando haya turnos que cruzan
  la medianoche.
- **El resumen de arqueo de efectivo por turno (fondo inicial, ventas en efectivo neto,
  ingresos/egresos/retiros, efectivo esperado) no se modifica**: esta spec es independiente de ese
  resumen y no cambia su fórmula ni su pantalla; solo introduce el reporte operativo de ventas/
  productos/categorías descrito aquí.
- **Snapshot del reporte operativo (FR-013) sigue el mismo patrón ya exigido para el arqueo de
  efectivo** (`specs/006-turnos-caja-arqueo`, `RN-CASH-17`): un turno cerrado es un hecho
  inmutable; cualquier efecto de una anulación posterior sobre las ventas reales del negocio queda
  fuera del alcance de esta spec (se gestiona, si corresponde, por la vista de ajustes ya prevista
  para el arqueo de efectivo).
- **Top de productos y ventas por categoría**: se basan en los productos/categorías ya existentes
  en el catálogo del tenant; un producto o categoría eliminado después de la venta sigue
  apareciendo en el reporte histórico de un turno ya cerrado, identificado por su nombre al momento
  de la venta (consistente con la inmutabilidad de FR-013).
- **US6 no cambia el comportamiento visible**: no modifica la interfaz, los contratos de respuesta
  ni el significado de US1–US5, FR-001–FR-017 ni SC-001–SC-007. La única diferencia observable
  admitida es el orden ante empates exactos de ingreso (FR-022).
- **Almacenamiento del snapshot**: la spec no exige cambiar cómo se guarda el desglose congelado de
  cada turno; si mantenerlo o reorganizarlo para cumplir FR-019 se decide en `plan.md`.
- **Umbrales de tiempo de SC-010**: son una verificación manual con datos de volumen, no un test
  automático; dependen del hardware, por lo que se miden en el entorno de desarrollo con la base de
  datos local.
- **Rango personalizado sin tope**: se mantiene sin límite de días, como hoy.
