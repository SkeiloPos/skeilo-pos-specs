# Investigación — Desglose por denominación en el arqueo de cierre de caja

**Spec**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md) · **Fecha**: 2026-10-15

La spec no dejó marcadores de aclaración pendientes; esta investigación **verifica contra el código y la
base de datos de desarrollo** las premisas de la sección «Contexto y comportamiento actual» y
resuelve las decisiones técnicas que la spec delega al plan (cómo, no qué). Las decisiones de
negocio (D-1 a D-4 de la spec) no se reabren aquí.

## Hallazgos de la verificación (premisas de la spec contra el código)

| # | Premisa de la spec | Resultado | Efecto |
|---|--------------------|-----------|--------|
| H1 | `close_shift` ignora `counted_amount` si llegan denominaciones; sin ninguna, lo usa tal cual; sin nada, cierra con contado vacío | **Confirmada** (`app/api/v1/cash/router.py:138-153`) | D-1/D-2 aplican sobre este bloque |
| H2 | `cash_count_denominations` no guarda tipo, acepta cantidad `0`, FK con cascada | **Confirmada** (`app/models/cash_count_denomination.py`; CHECK `quantity >= 0`) | Migración (R3) |
| H3 | El frontend envía las once líneas «incluidas las de cantidad `0`» | **Inexacta.** `confirmarArqueoYCerrar()` ya hace `.filter((d) => d.quantity > 0)` (`cash-session.store.ts:526`) | Ver H5; no cambia el diseño |
| H4 | El reporte ya recibe las denominaciones pero `cash-report.component.ts` no las pinta | **Confirmada** (`ShiftReportResponse.denominations`; el componente solo pinta resumen, arqueo y movimientos) | R9 |
| H5 | Hay filas con cantidad `0` que la migración debe descartar | **BD de desarrollo: 0 filas con cantidad `0`** (35 filas en `heladeria`, 0 en `skeilo`/`tenantlocal`). El descarte sigue siendo necesario por la API, que sí las admitía (`ge=0`), pero en desarrollo es un no-op | R3: la migración lo hace igual; el conteo de descartadas se registra en el log |
| H6 | FR-028: pueden existir filas con valor fuera del catálogo COP | **BD de desarrollo: 0 filas fuera del catálogo.** Producción no se pudo consultar desde aquí | Compuerta previa a ejecutar en producción (quickstart, paso 1) |
| H7 | «27 usos de `ShiftClose()`» en 4 archivos de caracterización | **Confirmada**: 7 + 6 + 5 + 9 = 27 (`test_cash_close_active_orders`, `_query_budget`, `_batch_identity`, `test_cash_shift_sales_report`); más `e2e_qr_flow.py:355` | R11 |
| H8 | `A-17` (carrera en `close_shift`, falta `with_for_update()`) | **Confirmada y vigente**: `close_shift` lee el turno con `get_or_404` sin bloqueo. La spec 119 la dejó sin corregir a propósito (A-129, «Riesgo asumido») | FR-019 la corrige (R5) |
| H9 | El turno no registra quién lo cerró | **Confirmada**: `close_shift` usa `_: User` (descarta al usuario) | R6 |
| H10 | Estado de la migración en desarrollo | `alembic_version = cd3e314a79b8` (único *head*). Esquemas con la tabla: `heladeria` (12 turnos cerrados, 2 sin desglose), `skeilo`, `tenantlocal` | La nueva revisión cuelga de `cd3e314a79b8` |

**Hallazgo adicional, fuera de alcance (no se corrige aquí, Principio V):** el reporte muestra
«Cajero: {{ store.cajero() }}», que es `auth.currentUser()` —el usuario que **mira** el reporte— y
no `shift.user_name` (quien abrió). Un administrador que consulta el histórico ve su propio nombre
como «Cajero». La spec (US4, escenario 5) da por hecho que el cajero de apertura «sigue mostrándose
como hoy»; hoy se muestra el equivocado. Se recomienda una spec propia. Esta spec **sí** muestra
«Contado por» desde `shift.closed_by_user_name` (dato persistido), por lo que no hereda el defecto.

**Correcciones de redacción sugeridas a la spec (no bloquean el plan):** (a) en «Contexto», la
viñeta «El frontend lleva la lista fija…» debería decir que ya filtra las líneas con cantidad `0`
(H3); (b) la tabla de decisiones se queda en D-1 a D-4, pero FR-029 (usuario que cierra) y el campo
de observación siempre visible son cambios de comportamiento/datos que conviene citar al registrar
(ver R12).

---

## R1 — Dónde vive el catálogo de denominaciones

**Decisión**: tabla nueva **`denomination_catalog`** en el esquema de cada tenant (modelo
`DenominationCatalog`), con `denomination` (único) y `kind` (`billete`/`moneda`). Sin columna
`active` ni administración.

**Justificación**: la spec dice «catálogo **por tenant**», «sembrado» y «solo lectura en esta spec»,
y anticipa una spec futura que lo administre. Una tabla es el único modelo que esa spec futura puede
ampliar sin reescribir el contrato; una constante en código no sería «por tenant». No se agrega
`active` porque FR-012 deja «activar o desactivar» fuera de alcance (Principio V: nada especulativo);
la spec futura la añade con su propia migración.

**Alternativas descartadas**: (a) constante Python `DEFAULT_COP_DENOMINATIONS` servida directamente
— es más simple pero contradice «por tenant» y obligaría a migrar a tabla después; (b) tabla en
`shared` (como `payment_method_catalog`) — el catálogo de pago es de **plataforma**, este es por
negocio (la spec dice que un tenant podría manejar otra lista algún día).

**Nombre**: `denomination_catalog` y no `cash_denominations`, para no confundirlo con
`cash_count_denominations` (las líneas snapshot del conteo).

## R2 — Cómo recibe el catálogo cada tenant (existentes y nuevos)

**Decisión**: dos caminos que comparten la misma lista de once valores.

1. **Tenants existentes**: la revisión de Alembic crea la tabla y la siembra (idempotente) en cada
   esquema de `shared.tenants`, con la lista **escrita como literal dentro de la migración**
   (una migración no debe importar código de aplicación que luego cambie).
2. **Tenants nuevos**: `tenant_create()` (`app/core/db.py`) los crea con `create_all`, **no** con
   Alembic (memoria `reference_pos_dev_db_psql_tenantlocal`). Tras `create_all` y dentro de la misma
   transacción, llama a `seed_default_denominations(db)`, definida junto al modelo con la constante
   `DEFAULT_COP_DENOMINATIONS`.

**Justificación**: sin el segundo camino, un tenant creado después de desplegar nace sin catálogo y
**no podría cerrar ningún turno desde la pantalla** (FR-013 bloquea con catálogo vacío). Es un hueco
real y ya tiene precedente: el proveedor «Compra ocasional» de la spec 106 se sembró solo en
migración (`99d57acd0216`) y `tenant_create` no lo repone. Aquí no se repite el error.

**Riesgo y mitigación**: `tenant_create()` exige PostgreSQL real (documentado en
`test_tenant_plan_assignment.py`), así que no se puede cubrir con la suite en SQLite. Se cubre con
(a) una prueba unitaria de `seed_default_denominations` sobre SQLite y (b) una verificación contra
PostgreSQL con un tenant desechable (quickstart, escenario 7), siguiendo la técnica de la memoria
`reference_pos_dev_db_psql_tenantlocal`.

**Alternativa descartada**: sembrar de forma perezosa en la primera lectura del catálogo — una
lectura (`GET`) que escribe, y con riesgo de carrera entre dos cajas. No.

## R3 — Migración de datos existentes (D-3, D-4, FR-027, FR-028)

**Decisión**: **una sola revisión** de Alembic, `down_revision = 'cd3e314a79b8'`, con
`@for_each_tenant_schema` y la guarda `_has_table(schema, "cash_shifts")` (los esquemas de scratch
como `tenant_default` pueden no tener las tablas). Pasos por esquema, **en una transacción**:

1. Crear `denomination_catalog` (si no existe) y sembrar los 11 valores (`ON CONFLICT DO NOTHING`).
2. **Compuerta FR-028**: si `cash_count_denominations` tiene filas con `denomination` fuera del
   catálogo, **abortar la migración** con un mensaje que lista esquema y valores. No se descarta
   nada en silencio.
3. Agregar `cash_count_denominations.kind` como `NULL`, rellenarlo desde el catálogo por valor, y
   luego `NOT NULL` + `CHECK (kind IN ('billete','moneda'))`.
4. Borrar las filas con `quantity = 0` (D-3) y reemplazar el `CHECK (quantity >= 0)` por
   `CHECK (quantity > 0)` (misma identificación, distinta expresión).
5. Agregar `cash_shifts.closed_by_user_id` (`UUID NULL`) y `closed_by_user_name` (`VARCHAR(255) NULL`).

**Justificación**:
- Todo es DDL transaccional de PostgreSQL y no hay índices nuevos sobre tablas grandes, por lo que
  **no** hace falta la separación en dos revisiones (transaccional / no transaccional) que sí
  necesitó la spec 119 por sus `CREATE INDEX CONCURRENTLY`.
- El `CHECK quantity > 0` convierte FR-015 en garantía de base de datos, no solo de la aplicación.
- **Nombres idénticos entre migración y modelo** (gotcha ya documentado: los tenants nuevos nacen de
  `create_all` y los migrados de Alembic; `IF EXISTS` no reconoce un nombre distinto). Los `CHECK`
  se nombran con `op.f("ck__cash_count_denominations__…")`, igual que produce la convención de
  `app/core/models.py`. Se verificó en la BD de desarrollo que el `CHECK` vigente se llama
  `ck__cash_count_denominations__ck_cash_count_quantity_positive` (61 caracteres, bajo el límite de
  63); el de `denomination > 0` está truncado con hash y **no se toca**. El `DROP` usa `IF EXISTS`.
- Ningún monto de ningún turno cambia: la migración no toca `cash_shifts.counted_amount`,
  `close_note` ni la diferencia (SC-004).

**Respaldo (Principio VIII)**: el respaldo de la tabla de desglose es un **paso operativo previo**
(`pg_dump --table` por esquema; quickstart, paso 1), no una tabla `_bak` dentro del esquema del
negocio — evita dejar tablas huérfanas en producción y mantiene la migración limpia. Es lo único
desde donde se restauran las filas con cantidad `0` descartadas (pérdida aceptada por la spec).

**`downgrade`**: quita `closed_by_*`, restaura `CHECK quantity >= 0`, borra `kind` y su `CHECK`, y
borra `denomination_catalog`. **No pierde** valor ni cantidad de ninguna línea conservada; sí
pierde `kind` y `closed_by_*` (aceptado en la spec).

**Alternativa descartada**: backfill del tipo con una regla numérica (`>= 2000 → billete`) en vez
de leer el catálogo. Funciona hoy, pero duplica la regla de negocio fuera del catálogo y se rompe
con el primer catálogo no-COP.

## R4 — Contrato del cierre: rechazar totales del cliente con mensaje en español (D-1, FR-002)

**Decisión**: `ShiftClose` y `DenominationIn` se declaran con `model_config = ConfigDict(extra="allow")`
y una función `reject_client_totals(body)` (módulo nuevo `app/api/v1/cash/denominations.py`) que,
**antes de tocar la base de datos**, lanza `HTTPException(422, detail="<cadena en español>")` si
encuentra con valor no nulo cualquiera de estas claves: `counted_amount`, `total`, `difference`,
`subtotal` en el cuerpo, o `subtotal`/`total` dentro de una línea. Otras claves desconocidas se
siguen ignorando, como hoy.

**Justificación**: el handler de validación unificado (`error_middleware.register_error_handlers`)
**solo aplica al prefijo del Super Admin**; en `/cash` rige el de FastAPI por defecto, cuyo `detail`
es una *lista* con mensajes en inglés, y el frontend (`CashService.extractError`) toma
`detail[0].msg`. Usar `extra="forbid"` mostraría al cajero «Extra inputs are not permitted», no el
«recarga la aplicación» que la spec exige (FR-002). Un `HTTPException` con `detail` en cadena es el
patrón que ya usan los demás `422` de este router («El arqueo no cuadra: …») y llega intacto a la
pantalla.

**Se exige valor no nulo**: `{"counted_amount": null}` no «trae un valor monetario», por lo que no
se rechaza. Evita romper a un cliente que serialice el campo vacío sin ser la versión antigua.

**Orden**: este rechazo va **primero** (antes del bloqueo por pedidos activos y antes de leer el
turno): la causa más probable es una pantalla desactualizada, y ahí lo útil es decir «recarga».

**Errores estructurales** (cantidad negativa o decimal, `Decimal` mal formado): los sigue
resolviendo Pydantic (`ge=0`, `int`, `max_digits`), con el formato `422` por defecto de FastAPI. La
pantalla nunca los genera (los pasos son enteros ≥ 0); son errores de un cliente por API, para el
que el formato estándar es aceptable. FR-005 exige `422`, no un texto.

## R5 — Validación de líneas, atomicidad y concurrencia (FR-004 a FR-007, FR-016 a FR-019)

**Decisión**: reordenar `close_shift` así (solo se agregan pasos; las reglas heredadas no cambian):

1. `reject_client_totals(body)` → 422 (R4).
2. **Leer el turno con `SELECT … FOR UPDATE`** (`service.get_shift_for_update`, mismo mensaje
   `Shift not found` en 404). Si `closed` → 409 (`RN-CASH-11`, sin cambios).
3. Bloqueo por pedidos activos (spec 119, **sin cambios**) → 409.
4. `resolve_count_lines(db, lines)` → 422 por: denominación repetida, denominación fuera del
   catálogo, total que excede `Numeric(12,2)`. Devuelve las líneas con `kind` y `subtotal`
   calculados, **solo las de cantidad > 0**.
5. `counted = Σ subtotales` (lista vacía → `Decimal(0)`, D-2); asignar a `shift`; `reconcile`;
   observación obligatoria si hay diferencia (422, **sin cambios**, `RN-CASH-10`).
6. Insertar las líneas, fijar `status/closed_at/close_note/closed_by_*`, snapshot del reporte de
   ventas (spec 119) y **un solo `commit`**.

**Justificación de cada punto**:
- **Atomicidad (FR-007/FR-016)**: todo ocurre en una sola transacción de SQLAlchemy y se confirma
  una sola vez al final. Cualquier `HTTPException` previa deja la sesión sin `commit`; `get_db`
  cierra la sesión y PostgreSQL revierte. Es el mismo mecanismo que hoy protege el snapshot de la
  spec 119. No hace falta código de reversión.
- **Concurrencia (FR-019/SC-006)**: `FOR UPDATE` serializa los cierres del mismo turno; el segundo
  espera, relee la fila ya `closed` (READ COMMITTED vuelve a evaluar tras el bloqueo) y responde
  `409`. Es el patrón que `service.resolve_dine_in_table_order` ya usa. Cierra A-17 (H8).
  *Defensa en profundidad*: el índice único `(cash_shift_id, denomination)` ya existente haría
  fallar un inserto duplicado; se captura `IntegrityError` en el `commit` y se traduce a `409`, para
  que nunca llegue un `500` (FR-019, «sin error interno»).
- **Precedencia 409 vs 422 (Edge Case de la spec)**: la spec no la fija; el orden de arriba es
  determinista y deja el turno intacto en ambos casos, que es lo único exigido.
- **Denominación equivalente (`10000` y `10000.00`)**: `Decimal` compara y hashea por valor
  numérico, así que un `set` de `Decimal` las trata como iguales sin normalizar a mano.
- **Cantidades enormes**: se valida **el total**, no cada cantidad —`Σ > 9 999 999 999,99` (el
  máximo de `Numeric(12,2)`)→ `422`—. Como la cantidad entera máxima útil
  (⌊9 999 999 999,99 / 50⌋ ≈ 2·10⁸) es menor que el máximo de `INTEGER` de PostgreSQL (≈ 2,1·10⁹),
  el chequeo del total también protege la columna `quantity`.
- **Dependencia de SQLite en pruebas**: SQLAlchemy omite `FOR UPDATE` en SQLite, así que la suite
  no puede demostrar la serialización; solo prueba el resultado secuencial (el segundo cierre ve
  `closed` y recibe 409). La concurrencia real se verifica contra PostgreSQL (quickstart,
  escenario 6).

**Alternativas descartadas**: (a) `UPDATE … WHERE status='open' RETURNING` como compuerta — válido,
pero obliga a reescribir cómo se carga/modifica el objeto `CashShift` en un router que no se está
refactorizando (Principio V); (b) bloqueo optimista con columna de versión — agrega una columna sin
necesidad.

## R6 — Quién cerró el turno (FR-029)

**Decisión**: dos columnas nuevas y opcionales en `cash_shifts`: `closed_by_user_id` (`UUID`) y
`closed_by_user_name` (`VARCHAR(255)`), **referencia blanda** a `shared.users` (sin FK
entre esquemas) y nombre como snapshot —idéntico a `user_id`/`user_name` de apertura—. Se exponen
en `ShiftResponse`, por lo que el reporte las recibe en `report.shift` sin campo nuevo.
`close_shift` pasa de `_: User` a `user: User` y las fija **dentro** de la transacción del cierre.

**Justificación**: replica un patrón ya existente y entendido; el snapshot de nombre cumple
US4-escenario 6 (el reporte sigue mostrando el nombre de entonces). Vacías en turnos abiertos e
históricos (la spec prohíbe inferirlas del usuario de apertura).

## R7 — Forma del catálogo y de las líneas en la API

**Decisión**:
- Nuevo `GET /api/v1/cash/denominations` → `[{denomination, kind}]`, de mayor a menor, `kind` ∈
  `billete`/`moneda`. Autenticación `get_current_user` (el mismo nivel que `close_shift`: cualquier
  usuario autenticado que pueda cerrar).
- `ShiftReportResponse.denominations` pasa de `[{denomination, quantity}]` a
  `[{denomination, kind, quantity, subtotal}]`. Es **aditivo**: los consumidores actuales (que solo
  leen `denomination` y `quantity`) no se rompen.
- Los importes viajan como cadena decimal (`"100000.00"`), como el resto del módulo de caja.

**Justificación**: `subtotal` lo calcula el servidor (FR-001, «cálculo autoritativo») y el
frontend solo lo pinta; así «la suma de subtotales = efectivo contado» (FR-021) se sostiene por
construcción y no depende de que la pantalla multiplique bien.

**MESERO**: `_MESERO_ALLOWED_ROUTES` (`app/core/dependencies.py`) es *default-deny* y **no incluye**
`POST /cash/shifts/{id}/close`; el Mesero no puede cerrar turnos, por lo que tampoco necesita el
catálogo. **No se modifica la lista** (hacerlo ampliaría el alcance del rol sin que nadie lo pida).

## R8 — Frontend: catálogo, estimación y bloqueo (FR-013, FR-025, FR-026)

**Decisión** (módulo `cash-register`, sin dependencias nuevas):
- `CashService.getDenominations()` consulta el catálogo. `CashSessionStore` elimina `DENOMS` y gana
  `catalogo` (señal) y `catalogoEstado` (`'cargando' | 'listo' | 'error'`). **Se consulta cada vez
  que se abre el modal** (`openArqueo()`), sin caché entre aperturas: son 11 filas y así el
  escenario «el catálogo cambió entre abrir y confirmar» queda acotado a esa ventana.
- `denominaciones`, `totalContado` y `contadoIngresado` se derivan de `catalogo()`.
- `arqueoDisabled` suma `catalogoEstado() !== 'listo' || catalogo().length === 0`. En `'error'` o
  catálogo vacío el modal muestra el mensaje y **«Reintentar»** (`reintentarCatalogo()`), sin lista
  de respaldo.
- Se **conserva** `contadoIngresado()` en `arqueoDisabled` → con todo en cero el botón sigue
  deshabilitado (decisión de la sesión de clarificación; «caja vacía» solo por API).
- El `textarea` de observación se muestra **siempre**; solo cambia el rótulo («opcional» /
  «requerida por diferencia»). Hoy está dentro de `@if (store.requiereObservacion())`, lo que dejaba
  atascado al cajero si el esperado cambiaba con el modal abierto.
- Los rótulos de total y diferencia pasan a «(estimado)»; al confirmar se envía
  `{ denominations: [{denomination, quantity}], close_note }` **sin** `counted_amount`, y tras la
  respuesta el reporte se lee del servidor (`getReport`), como hoy.
- El mensaje del `422` (denominación inválida, observación faltante, «recarga») ya llega a pantalla
  vía `extractError` + `error` del store y **el modal no se cierra** salvo en éxito: FR-026 y
  US3-escenarios 4 y 8 se cumplen con ese flujo, sin código de reintento nuevo. Las cantidades
  tecleadas se conservan porque `denomCounts` no se limpia en el `catch`.

**Alternativa descartada**: guardar el catálogo en una señal de `CashService` (singleton raíz) para
reutilizarlo. Evita una petición, pero introduce caché que habría que invalidar cuando exista la
spec de administración. No hay ahorro que lo justifique con 11 filas.

## R9 — Frontend: «Desglose del conteo» en pantalla e impresión (FR-020 a FR-024)

**Decisión**: nueva sección en `cash-report.component.ts`, entre «Arqueo de caja» y «Movimientos»:
- Encabezado «Desglose del conteo» y, si `shift.closed_by_user_name` existe, la línea
  «Contado por: {nombre}»; si no existe se **omite** sin marcador.
- Si hay líneas: tabla *Denominación · Tipo · Cantidad · Subtotal* (de mayor a menor, `kind` como
  «Billete»/«Moneda») y una fila final «Total» con la **suma de los subtotales de las líneas**
  (así FR-021 es visible y verificable a simple vista contra «Efectivo contado»).
- Si no hay líneas: el texto exacto «No se registró desglose para este turno».
- Un `computed` `desgloseView` en el store formatea las filas (patrón de `movimientosView`).

**Impresión**: el reporte se imprime con `window.print()` sobre el mismo DOM (specs 087/089/090) y
solo oculta los botones con `print:hidden`; la tabla nueva **entra sola**. Para SC-005 («sin filas
cortadas entre páginas») se agrega, en los `styles` del componente bajo `@media print`,
`tr { break-inside: avoid }` y `thead { display: table-header-group }`. No se toca
`dashboard-layout.component.ts` ni la clase `printing-cash-report`.

**Histórico**: `cash-history.component.ts` no cambia (la fila del histórico no muestra desglose; se
llega al detalle por «ver reporte», que ya carga `getReport`).

## R10 — Dependencias nuevas (Principio IX)

**Ninguna.** Backend: SQLAlchemy/FastAPI/Pydantic/Alembic ya presentes. Frontend: Angular y
Tailwind ya presentes.

## R11 — Impacto en pruebas existentes (Principio III) y estrategia de verificación

**Pruebas que cambian (autorizadas por la spec, mínimo indispensable, cada commit cita D-1/D-2):**
- 27 `ShiftClose()` en 4 archivos: hoy cierran «sin conteo»; con D-2 eso es «contado $0» y, como
  el esperado de un turno de prueba es > 0 (`opening_amount > 0` por `CHECK` y los fixtures no
  retiran efectivo), la diferencia es distinta de cero y exige observación. Cambio mínimo: `ShiftClose(close_note="…")`, o un desglose válido cuando la prueba
  necesite un cuadre. La **intención** de cada prueba (bloqueo por pedidos activos, snapshot del
  reporte de ventas, presupuesto de consultas, identidad de lotes) **no cambia**.
- Riesgo a vigilar: `test_cash_report_query_budget` mide el **presupuesto de consultas del reporte**;
  se agregará una consulta de líneas al reporte (ya existe una, ahora con más columnas) y una de
  catálogo al cierre. Hay que confirmar que el presupuesto no se rompe antes de ajustarlo; si el
  presupuesto exige moverse, se documenta con la cifra medida, no se sube «a ojo».
- `e2e_qr_flow.py:355`: `{"counted_amount": "30.00"}` → `{"denominations": […], "close_note": …}`.
- Frontend: `cash.service.spec.ts`, `cash-session.store.spec.ts`, `cash-arqueo-modal.component.spec.ts`,
  `cash-report.component.spec.ts` (+ `cash-page.component.spec.ts` si instancia el store).
  La suite del frontend ya arrastra fallos preexistentes en otros 7 archivos (memoria
  `reference_pos_suite_frontend_fallos_preexistentes`): línea base con `git stash` y **nunca**
  correr frontend y backend completos en paralelo.

**Pruebas nuevas** (backend, SQLite en memoria, patrón de `test_cash_close_active_orders.py`,
invocando el router como función): contrato del cierre (US1/US2), catálogo y siembra,
reporte con desglose, migración (datos de ejemplo con tipo deducido / cantidad `0` descartada /
valor fuera del catálogo que aborta), e inmutabilidad (reenvío → 409 con líneas intactas). Frontend
(Vitest): store (catálogo cargando/error/vacío/listo, payload sin `counted_amount`, observación
visible), modal, y reporte (tabla, total, mensaje de vacío, «Contado por» presente/ausente).

**Verificación en PostgreSQL real** (no cubrible en SQLite): concurrencia del cierre, siembra en
`tenant_create`, y migración `upgrade`/`downgrade` sobre un esquema desechable con `BEGIN … ROLLBACK`
(quickstart).

## R12 — Registro de decisiones y rama (Principios II, XIV)

- **Registrar antes de implementar** en `specs/000-reconocimiento/registro-de-anomalias.md`
  (siguiente libre tras A-129): **A-130** (D-1), **A-131** (D-2), **A-132** (D-3), **A-133** (D-4),
  con quién (el solicitante), cuándo (2026-10-15), qué cambia, por qué y qué funcionalidades afecta,
  en el formato de A-129. Dos cambios no listados en la tabla de la spec merecen constar dentro de
  esas entradas o en una **A-134**: el usuario que cierra (FR-029) y la observación siempre visible
  (FR-025). Esta decisión de agrupación la toma quien registre; no altera el diseño.
- **A-129 «Riesgo asumido»** menciona la ventana de carrera A-17 como no corregida: esta spec la
  corrige (R5); la entrada debe anotar «resuelto por la spec 121».
- **Ramas**: `feat/121-denomination-breakdown` en `pos-backend` y en `pos-heladeria`, creadas desde
  la rama actual de cada repo (`develop` en ambos) **antes** de tocar código (Principio XIV). Los
  commits solo cuando el usuario lo pida (Principio XV).
