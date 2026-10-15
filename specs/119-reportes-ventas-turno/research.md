# Investigación — Spec 119

**Fecha**: 2026-10-15 · **Spec**: [spec.md](./spec.md)

Toda decisión de esta fase se contrastó contra el código real de `pos-backend` y `pos-heladeria`
(ambos en `develop`, árbol limpio), no contra una lectura de las specs 006/087 en abstracto.

## D1 — Alcance de "pedidos activos" para el bloqueo de cierre (FR-007): todo el tenant, no por caja

**El problema**: la formulación original de FR-007 exigía bloquear el cierre mientras existieran
pedidos activos "asociados a ese turno" (hoy FR-007 ya dice "en el tenant", conforme a esta decisión).
El modelo de datos actual no sostiene esa asociación de forma uniforme:

- `CustomerOrder.cash_shift_id` (`app/models/customer_order.py:129-131`) **existe**, pero es
  `nullable`, con `ondelete="SET NULL"`, y según el propio comentario del código se fija **una
  sola vez, al crear el pedido**, exclusivamente para numeración estable de mesas (spec 087,
  `resolve_dine_in_table_order`, `cash/service.py:32-58`) — nunca para `TAKEAWAY` ni `DELIVERY`,
  que quedan `NULL` siempre, y nunca para pedidos anteriores a esa migración.
- `Sale.cash_shift_id` (el vínculo autoritativo de cobro, RN1/RN2) solo nace cuando la venta ya
  existe — es decir, cuando el pedido **deja** de estar activo. No sirve para encontrar pedidos
  activos, por definición.
- No existe ningún otro campo que ligue un `CustomerOrder` a una `CashRegister`/`CashShift`
  concreta de forma confiable para los tres canales (mesa, para llevar, domicilio) por igual.

**Decisión**: el bloqueo de cierre (FR-007/FR-008/FR-009) evalúa los pedidos activos de **todo el
tenant** (`CustomerOrder.status IN ('recibida', 'abierta', 'bloqueada')` — la misma tupla
`_NON_TERMINAL_ORDER_STATUSES` ya definida en `app/api/v1/cart/service.py:82` y
`app/api/v1/orders/service.py:69`), sin filtrar por `cash_register_id` ni por
`CustomerOrder.cash_shift_id`. Intentar cerrar cualquier turno de cualquier caja del tenant se
bloquea si existe al menos un pedido activo en cualquier caja.

**Rationale**:
1. Usar `CustomerOrder.cash_shift_id` dejaría sin cubrir el 100% de los pedidos `TAKEAWAY`/
   `DELIVERY` (siempre `NULL`) — una fuga directa contra SC-002 ("el 100% de los intentos... quedan
   bloqueados"), y el edge case explícito de la spec que dice que el canal no debe afectar el
   bloqueo ("Pedido activo que se ancla fuera de una mesa... cuenta igual").
2. Es consistente con la propia Decisión del usuario para FR-012 (turno actual sin filtro de caja
   = agregar todas las cajas abiertas del tenant): cuando el sistema no tiene un vínculo de datos
   confiable por caja, ya se optó por el criterio tenant-wide en vez de inventar uno nuevo.
3. No agrega ningún campo nuevo a `CustomerOrder` — la spec declara explícitamente esta entidad
   como "ya existente" sin ampliar su esquema (Key Entities); construir un vínculo fiable por caja
   para los tres canales exigiría justamente eso, fuera del alcance declarado.

**Alternativas consideradas**:
- Filtrar por `CustomerOrder.cash_shift_id == shift.id`: rechazada — deja fuera `TAKEAWAY`/
  `DELIVERY` por completo (siempre `NULL`), y para `DINE_IN` refleja el turno de **creación**, no
  uno necesariamente relacionado con el turno que se intenta cerrar ahora si el pedido lleva abierto
  más de un turno.
- Agregar un nuevo campo `cash_register_id` a `CustomerOrder`, poblado para los tres canales:
  rechazada — es un cambio de modelo de datos no declarado en la spec (Principio VIII exige que
  toda evolución del modelo esté especificada explícitamente) y desproporcionado para un bloqueo
  que, dado que casi todos los tenants operan una sola caja, no necesita esa granularidad hoy.

**Consecuencia aceptada, a confirmar con negocio si aparecen tenants multi-caja activos**: en un
tenant con dos cajas abiertas simultáneamente, un pedido pendiente originado en la Caja 1 bloquea
también el cierre de la Caja 2, aunque no tenga relación operativa con ella. Es el mismo
"costo de no tener el vínculo" que ya acepta FR-012 para la agregación de "turno actual" — no una
inconsistencia nueva de este plan.

## D2 — Snapshot inmutable (FR-013): tabla nueva, no columna JSON en `cash_shifts`, y no se toca `reconcile()`

> **Revisado por la ampliación US6 (2026-10-15)**: la decisión de fondo (tabla propia 1:1, escrita
> una sola vez dentro de la transacción de cierre, sin tocar `reconcile()`) se mantiene. Lo que
> cambia es **cómo se guarda el desglose completo**: filas en dos tablas hijas en vez de columnas
> `JSONB` — ver [D9](#d9--almacenamiento-del-desglose-congelado-filas-no-jsonb). Donde este
> apartado dice "columnas `JSONB`", léase "filas del desglose".

**Hallazgo clave**: `specs/006-turnos-caja-arqueo` (RN-CASH-17) ya exige el mismo principio de
inmutabilidad para `expected`/`difference` del arqueo de efectivo — pero, verificado en el código,
**tampoco está implementado todavía**: `CashShift` no tiene ninguna columna para eso, y
`service.reconcile()` siempre recalcula contra `Sale`/`Payment` vivos, incluso para turnos
cerrados hace meses. Esta spec es, en los hechos, la primera en materializar el patrón de
snapshot inmutable para turnos — pero únicamente para el reporte de ventas/productos/categorías
que le compete (FR-013), no para el arqueo de efectivo (`expected`/`difference`), que sigue fuera
de alcance y sin cambios (`cash/service.py::reconcile` no se modifica).

**Decisión**: tabla nueva `shift_sales_reports`, relación 1:1 con `cash_shifts`
(`cash_shift_id UNIQUE`), con el desglose **completo** de productos y categorías en columnas
`JSONB` (no solo el top-N visible, FR-013/FR-017). Se escribe **una sola vez**, dentro de la misma
transacción de `close_shift`, inmediatamente después de que el resto de la lógica de cierre ya
validada (arqueo, denominaciones, `close_note`) decide seguir adelante — si el cómputo del
snapshot fallara, toda la transacción de cierre revierte (atomicidad: nunca queda un turno
`closed` sin su reporte, ni un reporte sin su turno).

**Rationale**:
- Una tabla propia (no una columna `JSONB` en `cash_shifts`) mantiene `CashShift` liviano para las
  lecturas frecuentes que no necesitan el desglose completo (listado histórico, arqueo), y refleja
  la propia spec: "Reporte operativo de turno" es una **entidad nueva**, no un atributo del turno
  (Key Entities, `spec.md`).
- Guardar el desglose completo (no el top-N) es lo que permite que FR-017 (agregación exacta por
  período) recombine productos/categorías de varios turnos sin perder precisión — sumar top-N ya
  recortados de cada turno da una aproximación, no un total exacto.
- Función de cálculo compartida (ver D5): la misma lógica que calcula el reporte **en vivo** para
  un turno abierto (US4) es la que, al cerrar, se ejecuta una última vez y se persiste —
  garantiza que el valor congelado sea exactamente el último valor en vivo que el cajero pudo ver
  antes de cerrar, sin una fórmula paralela que pueda divergir.

**Alternativas consideradas**:
- Columna `report_snapshot JSONB` directamente en `cash_shifts`: rechazada — mezcla una entidad de
  reporte con el registro operativo del turno, y cada lectura de `cash_shifts` (incluida la lista
  histórica, que no necesita el desglose) cargaría ese JSON innecesariamente.
- Recalcular siempre en caliente, también para turnos cerrados (sin snapshot): rechazada
  explícitamente por FR-013/SC-003 — el reporte de un turno cerrado debe sobrevivir a la anulación
  posterior de una de sus ventas sin cambiar.
- Extender `reconcile()`/RN-CASH-17 (arqueo de efectivo) en la misma spec, ya que comparten
  filosofía: rechazada — es una funcionalidad de otra spec (006) con su propio contrato pendiente
  de implementar; mezclarla aquí viola el Principio VI (no combinar dos clases de cambio en un
  mismo incremento). Esta spec solo deja el patrón disponible para que 006 lo reutilice después.

## D3 — `Sale.cash_shift_id` ya satisface RN1/RN2 (FR-001/FR-002): sin cambio de backend

Confirmado en `app/api/v1/sales/builder.py`: `build_sale` exige `ensure_open_shift(shift_id)`
(rechaza con `409` si el turno no está `open`) y construye `Sale` con `cash_shift_id=shift.id`
dentro de la misma transacción que fija `status='paid'` — nunca antes, nunca con el turno vigente
en un momento distinto al del cobro. Esto es así tanto para venta de mostrador (spec 011) como
para el cobro de pedidos de mesa/para llevar/domicilio (que también terminan construyendo una
`Sale` vía el mismo `builder.py`). **No hay ningún camino de cobro que fije `cash_shift_id` en un
momento distinto al de la transacción de pago.**

**Consecuencia para esta spec**: FR-001, FR-002 y FR-003 no requieren ningún cambio de código en
`sales/builder.py` ni en `cash/service.py::ensure_open_shift`. El trabajo de esta spec sobre esas
tres reglas es exclusivamente de **verificación** (un characterization test que documente el
comportamiento ya correcto, útil como regresión) y de **construir el reporte** que lee
`Sale.cash_shift_id`, reutilizando exactamente el mismo filtro que ya usa `reconcile()`
(`Sale.cash_shift_id == shift.id, Sale.status == 'paid'`, `cash/service.py:119-122`).

## D4 — Periodos "semana"/"mes": semana y mes calendario, confirmado con el usuario (no ventana móvil)

La Assumption original de `spec.md` dejaba "semana"/"mes" condicionados a un estándar previo en el
código. Verificado en código (`pos-heladeria/src/app/modules/reports/services/reports.service.ts:293-321`,
`ReportsService.getDateRange`), el único precedente real en el repositorio **no es una semana
calendario**: es una ventana móvil de 7 días (`hoy − 6` hasta `hoy`, en fecha de negocio del tenant
vía `businessToday(tz)`) para `'week'`, y de 30 días (`hoy − 29` hasta `hoy`) para `'month'`, usada
por `/dashboard/reports` para su propio criterio de atribución por fecha de venta individual.

**Decisión (confirmada directamente con el usuario, 2026-10-15, ver `spec.md` Clarifications)**: el
reporte por turno de esta spec **no** reutiliza esa ventana móvil. "Semana" cubre de lunes a
domingo de la semana a la que pertenece la fecha operativa de apertura consultada; "mes" cubre del
día 1 al último día del mes calendario correspondiente. Es una decisión de negocio explícita que
prevalece sobre el precedente de código encontrado en esta investigación — el usuario consideró más
intuitivo el calendario estándar para un reporte que se audita con exactitud, aunque signifique
introducir lógica nueva en vez de reutilizar la de `/dashboard/reports`.

**Consecuencia para la implementación**: `compute_period_sales_report` (D5) calcula los límites de
"semana"/"mes" con aritmética de calendario (lunes de la semana de `date` hasta el domingo
siguiente; día 1 del mes de `date` hasta su último día), no con `hoy − N` días — sin reutilizar
`ReportsService.getDateRange` ni ningún equivalente de ventana móvil del backend.

**Alternativas consideradas**: ventana móvil de 7/30 días (el precedente real de código) —
rechazada explícitamente por el usuario al confirmarse esta decisión, pese a ser la opción que
reutilizaba lógica existente, porque el reporte por turno prioriza que "semana"/"mes" tengan el
significado calendario intuitivo para quien audita, no el de la pantalla `/dashboard/reports` con
la que coexiste pero no comparte criterio de atribución.

**"Rango personalizado" (FR-006)**: sin precedente en el código — el selector de `reports-page`
no tiene una opción de rango libre `date_from`/`date_to` (solo día/semana/mes/fecha
puntual/año). Es UI nueva (dos campos de fecha) sin equivalente que reutilizar.

## D5 — Dónde vive la agregación: módulo `cash`, función compartida en vivo/snapshot

> **Revisado por US6**: el módulo (`cash/reports.py`) y la función por turno
> (`compute_shift_sales_report`, usada en vivo y al cerrar) se mantienen. El recorrido "una
> llamada por turno incluido" que describe el segundo punto de la lista queda **reemplazado** por
> la consulta en lote de [D10](#d10--consulta-en-lote-con-selector-de-turnos-cuatro-consultas-fijas).

**Decisión**: nuevo archivo `app/api/v1/cash/reports.py` con una función
`compute_shift_sales_report(db, shift) -> ShiftSalesReportData` que replica, acotado por
`cash_shift_id` en vez de por rango de fechas, el mismo patrón ya usado por
`app/api/v1/reports/service.py::products_report`/`categories_report` (join
`Sale → SaleItem → ProductVariant → Product → Category`, agrupado y sumado). Se llama:

- **En vivo**, para un turno abierto (US4) o como parte de "turno actual"/período cuando el turno
  incluido todavía está `open` (FR-012, edge case de rango con turnos abiertos).
- **Una vez, al cerrar** (D2), para fijar la fila de `shift_sales_reports`.
- **Para la agregación por período** (FR-017): se llama una vez por turno `open` incluido en el
  rango (en vivo) y se lee la fila ya persistida para cada turno `closed` incluido; ambos
  resultados se recombinan sumando por `product_variant_id`/`category_id` antes de recortar al
  top-N visible.

**Por qué no en `app/api/v1/reports/`**: esa carpeta es, por decisión explícita de la spec
(Assumptions, Clarifications), un criterio de atribución distinto (fecha calendario de
`sold_at`) que **no se toca**. Ponerlo ahí obligaría a parametrizar `_paid_sales_filter` con un
modo "por turno" ajeno a su propósito actual, mezclando dos contratos que la spec exige mantener
separados.

**Top-N**: 10 productos (confirmado directamente con el usuario, 2026-10-15) — mismo valor que ya
usa el frontend para `GET /reports/top-products` (`reports.service.ts`); se documenta como
contrato cerrado de esta spec, no solo como valor heredado por defecto.

## D6 — Sin test protegido que esta spec deba reabrir

Verificado por grep (`close_shift|cash_shift_id|reconcile`) sobre
`app/characterization_tests/*.py`: no existe hoy ningún test con prefijo `"CONGELA comportamiento
actual:"` que documente que `close_shift` ignora pedidos activos, ni que el histórico de un turno
cerrado se recalcula siempre en caliente. El comportamiento que esta spec cambia (bloqueo de
cierre) nunca estuvo caracterizado como contrato protegido — es una ausencia de validación, no un
comportamiento deliberado congelado. Por el Principio III, no hay ningún test que esta spec deba
actualizar citando una decisión de negocio; sí hay, por el Principio II, la entrada obligatoria en
`registro-de-anomalias.md` que ya exige FR-016 (tarea de `tasks.md`).

## D7 — Anomalía A-17 (falta de `with_for_update()` en `close_shift`): relacionada, explícitamente fuera de alcance

`specs/006-turnos-caja-arqueo` ya documenta que `close_shift` no bloquea la fila del turno antes
de leer su estado (`A-17`, `ACCIDENTAL`, corrección asignada a esa spec, no a esta). La nueva
validación de pedidos activos que esta spec añade hereda la misma ventana de carrera ya conocida
(dos clics de cierre casi simultáneos). **Decisión**: no se agrega `with_for_update()` aquí — es
una corrección de concurrencia ya asignada a otra spec, y agregarla ahora mezclaría dos clases de
cambio no relacionadas (Principio V). El edge case de la spec ("pedido pasa de activo a inactivo
mientras el cajero revisa la lista") se resuelve de forma suficiente sin el lock: cada intento de
cierre vuelve a ejecutar la consulta de pedidos activos contra el estado vigente en ese momento,
nunca contra una lista cacheada del intento anterior.

## D8 — Turnos cerrados antes de esta spec: sin snapshot, caen a cálculo en vivo

> **US6 (FR-020)**: sigue sin haber backfill ni snapshot retroactivo. Lo que cambia es que estos
> turnos, igual que los abiertos, se calculan **en lote dentro de las mismas consultas** del
> período (D10), nunca uno por uno.

Un turno que ya estaba `closed` antes de que esta funcionalidad se despliegue no tiene fila en
`shift_sales_reports` (la migración no hace backfill, D2). **Decisión**: al consultar su reporte,
el sistema recalcula en caliente exactamente igual que para un turno abierto, en vez de fallar o
de mostrar un estado vacío falso. Es una ventana de transición explícita, no un error: ese
reporte, a diferencia de uno cerrado **después** del despliegue, no está protegido por SC-003
hasta que ese turno antiguo nunca lo estuvo (no existía el concepto). Documentado para que
`tasks.md`/el frontend no necesiten tratarlo como caso de error.

## Ampliación US6 — rendimiento de reportes de período (FR-018 a FR-023)

**Fecha**: 2026-10-15 · Las decisiones D9–D16 se contrastaron con el código real y con
**mediciones sobre PostgreSQL 16 local** (datos sintéticos de volumen en esquemas desechables y en
transacciones con `ROLLBACK`; todo eliminado al terminar). El procedimiento reproducible queda en
[quickstart.md](./quickstart.md) §10 y [quickstart-volume.sql](./quickstart-volume.sql).

### Diagnóstico del estado actual (medido en el código)

`aggregate_shifts` (`app/api/v1/cash/reports.py`) recorre los turnos en Python y, por cada uno,
lanza 1 consulta del snapshot (si está `closed`) y, si el turno es en vivo (abierto o D8), 3
consultas más de `compute_shift_sales_report` (totales, productos, categorías): hasta **4
consultas por turno**. Un mes de 186 turnos D8 son ≈ 745 consultas; uno de 186 turnos con
snapshot, 187. Además acumula en diccionarios de Python el desglose completo de cada turno
(contraviene FR-019), y `shift_sales_report` trae todas las filas de pedidos activos solo para
llamar `len()` sobre ellas (FR-023). `cash_shifts` no tiene índice por `opened_at`.

### Evidencia medida

Datos sintéticos de volumen: 3 cajas × 2 turnos/día × 365 días = 2.190 turnos, 328.500 ventas,
985.500 líneas; el período medido es octubre de 2026 (186 turnos). Cada cifra es la mediana de 3
corridas con `EXPLAIN (ANALYZE)`.

| Escenario | Resultado |
|---|---|
| Peor caso: 186 turnos **sin snapshot** (D8), solo índices que ya existen | **≈ 150 ms** (SC-010 pide ≤ 2 s) |
| ... añadiendo índices de `cash_shifts` por `opened_at` | ≈ 153 ms (sin cambio: la tabla es pequeña) |
| ... añadiendo un índice parcial cubriente sobre `sales` | ≈ 120–125 ms (−20 %) → **no se crea**, ver D13 |
| 186 turnos **con snapshot** | **≈ 21 ms** (SC-010 pide ≤ 1 s) |
| Mismo caso sobre las **tablas reales** del esquema de desarrollo (366 turnos, 54.900 ventas) | con snapshot 11 ms · sin snapshot 110 ms |
| Pedidos activos con **1.000.000** de pedidos históricos, **solo el índice que ya existe** | **0,02 ms** (SC-010 pide ≤ 200 ms) |
| Identidad: período calculado desde el snapshot vs recalculado desde las ventas | **0 filas distintas** |
| Ejemplo numérico de US6 (escenario 1) ejecutado en **SQLite 3.46** con la misma forma de SQL | Cono doble 16 u / $80.000 → Paleta 20 u / $40.000 → Malteada 4 u / $36.000 ✔ |

### D9 — Almacenamiento del desglose congelado: filas, no `JSONB`

**Decisión**: el desglose completo por producto y por categoría de cada turno cerrado se guarda
como **filas** en dos tablas hijas nuevas — `shift_sales_report_products` y
`shift_sales_report_categories` —; la cabecera `shift_sales_reports` conserva únicamente los
totales y **pierde** sus columnas `products_breakdown`/`categories_breakdown`. La spec delegó esta
decisión a `plan.md` (Clarifications US6, Assumptions "Almacenamiento del snapshot").

**Rationale**:
1. FR-019 exige recombinar y recortar al top-N **en la base de datos**. Con `JSONB` eso obliga a
   `jsonb_array_elements`/`jsonb_to_recordset`, SQL exclusivo de PostgreSQL.
2. **Toda la suite de characterization corre sobre SQLite en memoria** (`fixtures.py::new_session`,
   con un shim que solo compila `JSONB` como texto). SQL específico de PostgreSQL no se podría
   ejercitar ahí, y SC-008 exige que los tests existentes de `test_cash_shift_sales_report.py`
   sigan pasando **sin modificarse** y sobre esa misma infraestructura. Con filas, la recombinación
   es SQL estándar (`UNION ALL`, `GROUP BY`, funciones de ventana) y corre idéntico en ambos motores
   (verificado: el ejemplo de US6 sale igual en SQLite 3.46 y en PostgreSQL 16).
3. Las filas son indexables por `cash_shift_id` y se leen sin deserializar nada; el costo de
   escritura al cerrar es una inserción masiva por tabla (decenas o cientos de filas por turno).

**Detalles que se fijan**: las tablas hijas **no** llevan clave foránea hacia `product_variants` ni
`categories` (un producto o categoría eliminado después sigue figurando por su nombre congelado,
Assumptions de la spec); sí hacia `cash_shifts` con `ON DELETE CASCADE`. El discriminador de "este
turno tiene snapshot" es **la existencia de la fila de cabecera**, no el `status` ni las hijas: unas
hijas huérfanas se ignoran (verificado en la base real).

**Alternativas consideradas**:
- Mantener `JSONB` y recombinar con `jsonb_to_recordset` — rechazada (puntos 1 y 2: SQL no portable,
  imposible de cubrir con la suite actual, o exigiría dos implementaciones que pueden divergir).
- Mantener `JSONB` y recombinar en Python — rechazada: es exactamente lo que FR-019 prohíbe.
- Una sola tabla hija con columna `kind` (`product`/`category`) — rechazada: mezcla dos claves
  distintas (`product_variant_id` vs `category_id` nulable) y obliga a filtros en cada consulta.

### D10 — Consulta en lote con "selector de turnos": cuatro consultas fijas

**Decisión**: el agregador deja de recibir una lista de objetos `CashShift` y pasa a recibir un
**selector** — una lista de condiciones SQL sobre `cash_shifts` — que se repite dentro de cada
consulta: `opened_at` en rango (+ `cash_register_id` opcional) para día/semana/mes/rango;
`status = 'open'` (+ caja) para "turno actual"; `id = X` para un turno puntual. Así no hay listas de
identificadores en los parámetros (constante aunque el rango sea de años) ni viaje de ida y vuelta
para resolver los turnos antes de agregarlos. El reporte se arma con **cuatro consultas fijas**:

1. **Turnos incluidos**: `id`, y si tienen cabecera de snapshot (`LEFT JOIN`) → `shift_ids`
   (ordenados por `opened_at, id`) e `is_live` (algún turno sin cabecera).
2. **Totales**: suma de `total_sales`/`order_count` de las cabeceras **más** la suma/cuenta de
   `Sale` pagadas de los turnos sin cabecera (`UNION ALL` de dos agregados).
3. **Top-N de productos**: `UNION ALL` de (a) las filas de snapshot de los turnos con cabecera y
   (b) el cálculo en vivo — `sales → sale_items` agrupado por (turno, variante) — de los turnos sin
   cabecera; sobre esa unión se calcula el nombre mostrado (D11), se agrupa por variante, se ordena y
   se aplica `LIMIT` — todo en la base de datos.
4. **Categorías**: igual que la 3, sin `LIMIT`, con el `LEFT JOIN` a `Category` para las filas en vivo.

Las ramas (a) y (b) son parte de **una sola definición** compartida: la rama en vivo es la misma
consulta que usa `compute_shift_sales_report` para un turno (el cálculo del cierre y el de los
turnos en vivo no pueden divergir — mismo objetivo que ya fijaba D5). `compute_shift_sales_report`
conserva su firma y su forma de salida (los tests existentes la invocan directamente).

El costo medido (≈ 150 ms con 186 turnos D8; 21 ms con snapshot) crece con las **filas** del
período, no con el número de consultas.

**Alternativas consideradas**: resolver primero la lista de ids de turnos y pasarla como `IN (...)`
(rechazada: un rango de años significa miles de parámetros y una consulta extra); una `CTE` común
(rechazada: PostgreSQL la materializa al referenciarse varias veces, y SQLAlchemy ya repite el
selector sin costo apreciable); fusionar las consultas 2–4 en una (rechazada: complica sin ahorro
medible, el requisito es un número fijo, no el mínimo).

### D11 — Reglas de identidad con el resultado anterior (FR-022)

- **Nombre mostrado del producto**: dentro de un turno, `MAX(descripción)` (igual que hoy); en el
  período, el nombre de la fila del turno más antiguo por `(opened_at, id del turno)`, con
  `ROW_NUMBER() OVER (PARTITION BY variante ORDER BY opened_at, shift_id)` y `MAX(CASE WHEN rn = 1 ...)`.
  Se usa una función de ventana, no `DISTINCT ON`/`array_agg ... ORDER BY`, porque estas dos últimas
  son exclusivas de PostgreSQL (D9). El desempate por id del turno hace determinista el caso de dos
  turnos con la misma hora de apertura (antes, orden accidental).
- **Nombre mostrado de la categoría**: se aplica **el mismo criterio** (turno más antiguo). FR-022
  solo lo enuncia para productos, pero es lo que hace hoy el código con las categorías
  (`setdefault` sobre los turnos ordenados por `opened_at`); copiarlo mantiene la identidad que
  exige SC-008. Decisión técnica de este plan, no de negocio.
- **Orden** (FR-022): ingreso descendente, nombre ascendente, identificador ascendente. En
  categorías, el identificador nulo ("Sin categoría") va **al final** (`NULLS LAST` explícito, porque
  PostgreSQL y SQLite difieren en su valor por defecto). El nombre se compara con la colación por
  defecto de cada motor; los tests usan nombres con la misma capitalización, así que el orden es el
  mismo en ambos. Limitación aceptada: en producción, "nombre ascendente" sigue la colación de la
  base de datos del tenant.
- **Ticket promedio**: se calcula **en Python** a partir de los totales con
  `(total / n).quantize(Decimal("0.01"))`, igual que hoy. No se calcula con `ROUND()` de SQL: el
  redondeo por defecto de `Decimal.quantize` es *half-even* y el de `ROUND(numeric)` de PostgreSQL
  es *half-away-from-zero*; difieren justo en los empates de medio centavo y romperían "al centavo".
- **Tipos de salida**: sin cambios — `shift_ids` como `UUID`, filas como `dict` con las mismas
  claves, `revenue` como `Decimal`; los tests existentes comparan esas estructuras con `==`.

### D12 — Contadores de pedidos activos: `COUNT` en la base de datos, lista solo si hace falta

**Decisión (FR-023)**: nueva función `count_active_orders(db)` (`SELECT count(*)` sobre el mismo
predicado que `list_active_orders`). `close_shift` cuenta primero y solo si hay > 0 trae la lista
(para el cuerpo del 409); `shift_sales_report` usa el conteo para `active_orders_count` en vez de
`len(list_active_orders(...))`. Si entre el conteo y la lista el pedido se resolvió (lista vacía),
el cierre continúa: es el estado vigente (mismo criterio de re-evaluación que ya fija D7).

**Índice**: **no se crea ninguno**. `idx_active_order_per_participant` (índice único parcial,
spec 025: `participant_id WHERE status <> ALL ('pagada','cancelada')`) lo usa el planificador para
`status IN ('recibida','abierta','bloqueada')` — PostgreSQL demuestra la implicación — y con 1.000.000
de pedidos históricos responde en 0,02 ms. Un índice parcial dedicado dio 0,03 ms: sin ganancia real
y con costo de escritura sobre una tabla caliente. **Contingencia documentada**: si el `EXPLAIN` del
quickstart §10 dejara de mostrar ese índice (porque alguien modifique el de la spec 025), crear
`ix__customer_orders__active_created_at ON customer_orders (created_at) WHERE status IN
('recibida','abierta','bloqueada')` (probado: `Index Only Scan` para el conteo, `Index Scan` ordenado
para la lista, sin `Sort`).

### D13 — Índices: cuáles se crean y cuáles no (FR-021)

| Búsqueda | Índice que la respalda | ¿Nuevo? |
|---|---|---|
| Ventas pagadas de un turno | `sales (cash_shift_id)` — existe desde la baseline | **No** (medido, abajo) |
| Líneas de una venta | `sale_items (sale_id)` — existe | No |
| Snapshot de un turno | `UNIQUE (cash_shift_id)` en la cabecera; `UNIQUE (cash_shift_id, product_variant_id)` en productos; índice sobre `cash_shift_id` en categorías | Sí, con la creación de las tablas (Rev. B) |
| Turnos por fecha de apertura, **sin** filtro de caja | `cash_shifts (opened_at)` | **Sí** (Rev. C) |
| Turnos por fecha de apertura, **con** filtro de caja | `cash_shifts (cash_register_id, opened_at)` | **Sí** (Rev. C) |
| Pedidos activos del tenant | `idx_active_order_per_participant` (parcial) | **No** (D12) |

**Por qué no un índice parcial cubriente sobre `sales`** (`(cash_shift_id) INCLUDE (id, total) WHERE
status = 'paid'`): la medición dio −20 % (150 → 120 ms), con un margen de 13× frente al objetivo de
2 s, y cada índice adicional sobre `sales` se paga en el camino caliente del cobro. Se reabre solo si
la verificación de volumen de `quickstart.md` §10.3 incumple SC-010.

**Los nombres de índices existentes varían por entorno** (`ix__sales__cash_shift_id` en las
migraciones, `ix_tenant_sales_cash_shift_id` en la base de desarrollo). Causa verificada: los tenants
se crean con `get_tenant_specific_metadata().create_all(...)` (`app/core/db.py:100`), que nombra los
índices con otra convención que las migraciones baseline. Ninguna migración ni verificación debe
referirse a índices existentes por nombre, sino por columnas.

**Interpretación operativa de SC-010** ("sin recorridos secuenciales sobre las tablas grandes de
ventas, turnos o pedidos"): con unos pocos miles de turnos el planificador elige recorrer
`cash_shifts` y las tablas de snapshot (cabe en pocas páginas) aunque el índice exista — se vio con
`random_page_cost` por defecto y se corrige con 1,1 (disco SSD). Por eso la verificación exige
**cero `Seq Scan` sobre `sales`, `sale_items` y `customer_orders`**, y para `cash_shifts` y las tablas
de snapshot exige que el índice **esté disponible y se use** (`enable_seqscan = off` como prueba de
existencia del camino), no que el planificador lo prefiera en una tabla pequeña.

### D14 — Migraciones: dos revisiones nuevas, una transaccional y otra no

La migración de la spec (`2009eabd2e82`, "Rev. A") **ya está aplicada en la base local de
desarrollo** (`public.alembic_version = 2009eabd2e82`, tablas vacías) y su archivo aún no está
versionado. No se reescribe su estructura: se avanza con revisiones nuevas, válidas desde cualquier
estado. **Única modificación permitida a la Rev. A** (hallazgo U1 de `/speckit-analyze`, 2026-10-15):
una guarda de idempotencia (ver §2 más abajo); no altera lo que ya se aplicó en la base local.

- **Rev. B** (`down_revision = '2009eabd2e82'`, **transaccional**, `@for_each_tenant_schema`, con la
  guarda `_has_table` de la Rev. A): crea las dos tablas hijas, **rellena** las filas desde las
  columnas `JSONB` existentes y elimina esas columnas. `downgrade`: vuelve a crear las columnas
  `JSONB` y las **reconstruye** desde las filas antes de borrar las tablas hijas — sin pérdida.
  SQL de referencia validado en la base real (ida y vuelta, `ROLLBACK`): el *backfill* usa
  `CROSS JOIN LATERAL jsonb_array_elements(...)` con `(e->>'campo')::tipo`; el *rollback*,
  `jsonb_agg(jsonb_build_object(...))`; el resultado restaurado es idéntico (comparado como
  conjuntos) incluida una categoría con `category_id` nulo.
- **Rev. C** (`down_revision` = Rev. B, **no transaccional**): crea los dos índices de `cash_shifts`
  con `CREATE INDEX CONCURRENTLY IF NOT EXISTS`, dentro de `op.get_context().autocommit_block()`,
  esquema por esquema. Para cada índice, **antes** de crearlo consulta el catálogo
  (`pg_index.indisvalid`) y, si quedó inválido por una construcción interrumpida, lo borra con
  `DROP INDEX CONCURRENTLY IF EXISTS` y lo recrea. `downgrade`: `DROP INDEX CONCURRENTLY IF EXISTS`.

**Validado en PostgreSQL 16** (esquema desechable): una construcción `CONCURRENTLY` que falla deja un
índice con `indisvalid = false`; `CREATE INDEX ... IF NOT EXISTS` sobre ese nombre **lo omite en
silencio** (de ahí la detección explícita que pide FR-021); `DROP INDEX CONCURRENTLY IF EXISTS` +
recreación lo deja válido.

**Por qué dos revisiones**: son dos clases de cambio distintas (forma del dato frente a rendimiento)
con requisitos de transacción opuestos — Principios VI y VIII. Cada una tiene su propio rollback.

**Tenants nuevos frente a existentes (hallazgo verificado en `app/core/db.py:100`)**: el alta de un
tenant NO usa Alembic: ejecuta `create_all` con los modelos vigentes. Consecuencias de diseño:
1. Un tenant creado **después** de este cambio nace ya en la **forma final** (tablas hijas, sin
   columnas `JSONB`, con los dos índices de `cash_shifts` declarados en el modelo). Las revisiones B y
   C existen solo para los tenants **ya existentes**.
2. Por eso las revisiones **A, B y C** deben ser **idempotentes frente a una forma ya final** (p. ej.
   un tenant creado entre el despliegue del código y la ejecución de las migraciones): la **Rev. A**
   omite el esquema entero si `shift_sales_reports` ya existe (`if _has_table(schema,
   "shift_sales_reports"): return`, justo después de la guarda de `cash_shifts`) —sin esta guarda, un
   tenant ya en forma final haría fallar `alembic upgrade head` en la Rev. A, antes de llegar a B y C,
   y `transaction_per_migration=True` bloquearía el despliegue—; la Rev. B omite crear una tabla hija
   que ya existe y omite el *backfill* y el borrado si las columnas `JSONB` ya no están (se comprueba
   en `information_schema`); la Rev. C ya es idempotente por `IF NOT EXISTS`. Un tenant en forma final
   que pasa por la Rev. A omitida y luego por B ve que no hay columnas `JSONB` y tampoco hace nada, así
   que las tres se componen. La verificación es [quickstart.md](./quickstart.md) §10.8, paso 6.

   **Alternativa descartada (U1)**: plegar la Rev. A dentro de la Rev. B (A nunca salió a producción).
   Eliminaría el *backfill* y la reconstrucción del `downgrade`, pero obliga a rehacer plan,
   data-model, quickstart y las tareas T043/T049/T050/T072, y descarta el rollback sin pérdida ya
   validado en la base real. Se prefirió la guarda mínima.
3. Los nombres de los dos índices en `CashShift.__table_args__` deben ser **idénticos** a los de la
   Rev. C (`ix__cash_shifts__opened_at`, `ix__cash_shifts__register_opened_at`); si no, un tenant
   nuevo y uno migrado tendrían nombres distintos y `IF NOT EXISTS` no los reconocería.
4. Declarar el modelo final es **obligatorio**, no un detalle: sin las clases de las tablas hijas en
   `app/models/`, los tenants nuevos no tendrían dónde guardar el snapshot.

**Punto cerrado en la implementación (2026-10-15)**: `autocommit_block()` dentro del bucle de
`for_each_tenant_schema` con `transaction_per_migration=True` **funciona** sin el respaldo: la Rev. C
creó los dos índices en los 4 esquemas con `CREATE INDEX CONCURRENTLY`, se reaplicó con
`downgrade -1 && upgrade head` y reparó un índice inválido (quickstart §10.7). El respaldo (conexión
separada con `isolation_level="AUTOCOMMIT"`) no fue necesario.

**Nombres de los `CHECK` de las tablas hijas (2026-10-15)**: la convención de nombres antepone
`ck__<tabla>__` y con nombres largos (`ck_shift_sales_report_product_units`) PostgreSQL los cortaba a 63
caracteres (SQLAlchemy los trunca con un hash). Se usaron nombres cortos (`units_nonneg`,
`revenue_nonneg`) para que el modelo y la Rev. B generen exactamente el mismo nombre sin depender del
truncamiento.

**Modelo**: `CashShift.__table_args__` declara los dos índices (convención del repositorio: los
índices viven en el modelo y en la migración, para que `alembic` no detecte deriva).

### D15 — Compuerta automática: un test que cuenta consultas (SC-009)

**Decisión**: test nuevo que engancha `before_cursor_execute` (precedente en
`test_orders_pagination.py`, `test_products_service.py`, `test_orders_billing_summary.py`) y mide el
número de sentencias de: `compute_period_sales_report`, `router.shift_sales_report` y
`router.current_shift_report`, para un período **pequeño** y para **186 turnos** (3 cajas × 62), y
exige que sean **iguales** y no superen un techo fijo. Tres composiciones: todos con snapshot (base de
1 turno); mezcla (con snapshot + abiertos + cerrados sin snapshot; base de **3 turnos**, uno de cada
tipo, porque una mezcla no puede existir con 1 solo turno); y todos sin snapshot (base de 1 turno).
Funciona sobre SQLite porque el SQL es portable (D9). Otro caso: `close_shift` ejecuta el mismo número
de `INSERT` con 1 y con 80 productos vendidos (inserción masiva, no una por fila).

**Verificación de FR-019** (hallazgo G2 de `/speckit-analyze`): contar sentencias no basta, porque una
implementación con cuatro consultas que agregue en Python también las cumpliría. El mismo test captura
además el texto del SQL y exige que la sentencia de productos contenga `GROUP BY` y `LIMIT`, y la de
categorías `GROUP BY`; y T068 comprueba por búsqueda de texto que `reports.py` ya no acumula el
desglose en diccionarios (`setdefault`).

**Límite honesto**: el test cuenta sentencias, no tiempo ni planes; los umbrales de SC-010 y el uso de
índices se verifican a mano (quickstart §10), como fija la spec.

### D16 — US6 no requiere una entrada nueva en `registro-de-anomalias.md`; el orden de empates queda como adenda de A-128

El Principio II protege el comportamiento **existente**. Los endpoints de reporte por turno y su
orden de empates no existen en producción: el código de la spec 119 está sin versionar y su
migración solo está aplicada en la base local de desarrollo (con 0 filas). FR-022 acota la única
diferencia visible — el orden en empates exactos de ingreso, antes accidental — y A-128/A-129
cubren los dos cambios de comportamiento real de la spec. Ningún test `"CONGELA comportamiento
actual:"` toca este código (D6).

**Trazabilidad (resultado de `/speckit-analyze`, 2026-10-15)**: el criterio de orden de FR-022 es
una decisión de **negocio** (la tomó el usuario en la sesión de Clarifications de US6), no técnica,
y el Principio II hace del negocio la única autoridad para decidir un cambio de comportamiento. Aunque
no haya un comportamiento publicado que proteger, se deja constancia de quién y cuándo como
**adenda dentro de A-128** (sección "Decisión relacionada (ampliación US6, FR-022)"), sin abrir un
A-130: evita inflar el registro con una entrada que no cambia nada en producción.

## Tests nuevos (ninguno es characterization protegido, ver D6)

- `app/characterization_tests/test_cash_shift_sales_report.py` — reporte de un turno que cruza
  medianoche (US1), snapshot inmutable tras anular una venta (US1/FR-013/SC-003), turno sin ventas
  (US5), agregación por período recombinando desglose completo de 2+ turnos (US2/FR-017),
  aislamiento multi-tenant/caja (SC-004). **Existente; US6 no lo modifica** (SC-008).
- `app/characterization_tests/test_cash_close_active_orders.py` — bloqueo de cierre con pedidos
  activos de los tres canales (US3), desbloqueo tras cobrar/anular, turno sin pedidos activos
  (comportamiento sin cambios), re-evaluación en un segundo intento tras que otro usuario resuelva
  un pedido (edge case). **Existente; US6 no lo modifica.**
- **Nuevo (US6)** `test_cash_report_query_budget.py` — compuerta SC-009 (D15).
- **Nuevo (US6)** `test_cash_report_batch_identity.py` — ejemplo numérico del escenario 1 de US6
  (SC-008); nombre mostrado = turno más antiguo; orden determinista en empates exactos de ingreso
  (producto y categoría, nulo al final); filas hijas huérfanas ignoradas; las filas del snapshot se
  escriben al cerrar y coinciden con `compute_shift_sales_report`; ticket promedio *half-even*;
  período que mezcla snapshot + abierto + D8 devuelve lo mismo que recalcular desde las ventas.
- Los fixtures (`orders_fixtures.py`) registran las dos tablas hijas nuevas en `_ORDERS_TABLE_NAMES`;
  es infraestructura de test, no una modificación de los tests existentes.
- Frontend: sin cambios por US6 (no modifica la interfaz ni los contratos). Los tests de la spec
  original (`admin-dashboard.component.spec.ts`, `shift-reports.service.spec.ts`) siguen vigentes.
