---

description: "Lista de tareas — Desglose por denominación en el arqueo de cierre de caja"
---

# Tasks: Desglose por denominación en el arqueo de cierre de caja

**Input**: Documentos de diseño en `specs/121-desglose-denominaciones-cierre/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: **Incluidos.** La spec los exige: el contrato estricto de D-1/D-2 obliga a adaptar 4 suites de caracterización (Principio III), el plan define archivos de prueba nuevos (plan.md, «Source Code») y la constitución pide verificación obligatoria (Principio X).

**Organization**: Las tareas se agrupan por historia de usuario (US1–US6) para poder implementar y verificar cada una por separado. Los datos (Fase 2) y el cambio de comportamiento (Fases 3 en adelante) van en incrementos y commits **separados** (Principio VI).

## Formato: `[ID] [P?] [Story] Descripción`

- **[P]**: se puede ejecutar en paralelo (archivos distintos, sin dependencias pendientes)
- **[Story]**: historia de usuario a la que pertenece (US1…US6); las fases Setup, Foundational y Polish no llevan etiqueta
- Cada tarea incluye la ruta exacta del archivo

## Convenciones de ruta

Tres repositorios hermanos bajo `skeilo/`; **todas las rutas de este archivo son relativas a `skeilo/`**:

- `pos-backend/` — API FastAPI. Comandos: `cd pos-backend && env/bin/python …`
- `pos-heladeria/` — frontend Angular 21. Prueba puntual: `npx ng test --watch=false --include 'src/app/modules/cash-register/**/*.spec.ts'`
- `pos-specs/` — este repositorio (specs y registro de anomalías)

Todo el código nuevo del backend vive en `pos-backend/app/api/v1/cash/` (módulo propio `denominations.py`, sin engordar `router.py`) y todo el del frontend en `pos-heladeria/src/app/modules/cash-register/`. Los mensajes de usuario y los comentarios van en español de Colombia; **ramas y commits en inglés** (Principios XIII–XV). Los commits **solo** cuando el usuario los pida, en unidades pequeñas.

---

## Phase 1: Setup (registro, ramas y línea base)

**Purpose**: Cumplir las condiciones previas de la constitución (II, XIV) y fotografiar el estado antes de tocar nada.

- [X] T001 Registrar las decisiones **A-130** (D-1: el servidor calcula el efectivo contado y rechaza el del cliente), **A-131** (D-2: ya no existe el cierre «sin conteo»; lista vacía = contado $0), **A-132** (D-3: no se guardan líneas con cantidad 0) y **A-133** (D-4: cada línea registra su tipo billete/moneda) en `pos-specs/specs/000-reconocimiento/registro-de-anomalias.md`, a continuación de A-129, tras su final (≈ línea 4340, antes del separador `---`), con el mismo formato que A-129 (Qué cambia · Evidencia de código · Por qué cambia · Quién y cuándo · Funcionalidades afectadas · Riesgo asumido · Tests afectados · Clasificación · Estado). Quién/cuándo: el solicitante de la spec, sesión de clarificación del 2026-10-15. Evidencia: research.md H1, H2, H5; «Tests afectados»: las 25 llamadas a `router.close_shift` de 4 suites de caja + `e2e_qr_flow.py`. En «Funcionalidades afectadas» de A-130 y A-131 citar **A-20 / RN-CASH-09** (cierre sin conteo). **Principio II: debe quedar hecha antes de implementar.**
- [X] T002 Registrar **A-134** en `pos-specs/specs/000-reconocimiento/registro-de-anomalias.md` (tras A-133) con los cambios **D-5** y **D-6** de la tabla de la spec (research.md R12): (a) el turno pasa a registrar **quién lo cerró** (`closed_by_user_id/name`, FR-029) y (b) el campo de observación del modal queda **siempre visible** (FR-025). Mismo formato y mismos quién/cuándo que T001.
- [X] T003 [P] Crear la rama `feat/121-denomination-breakdown` en `pos-backend` desde `develop` (Principio XIV; el nombre va en inglés) — `git -C pos-backend switch -c feat/121-denomination-breakdown`
- [X] T004 [P] Crear la rama `feat/121-denomination-breakdown` en `pos-heladeria` desde `develop` (Principio XIV) — `git -C pos-heladeria switch -c feat/121-denomination-breakdown`
- [X] T005 Línea base del backend (quickstart §0.1): `cd pos-backend && env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'` **sola**, sin la suite del frontend; anotar el recuento en «Registro de línea base» al final de este archivo (referencia: 1574 en la spec 119)
- [X] T006 Línea base del frontend (quickstart §0.2), **después** de T005 y nunca en paralelo con ella (la contención infla los fallos): en `pos-heladeria`, `git stash push -u -m baseline && npm test && git stash pop`; anotar los archivos con fallos preexistentes en «Registro de línea base» (7 conocidos)
- [X] T007 Fotografía de los montos de los turnos cerrados para SC-004 (quickstart §0.3): ejecutar la consulta `md5(string_agg(…))` sobre `cash_shifts` de cada esquema con datos (`docker exec -i pos psql -U admin -d pos_db`); anotar la huella (referencia en dev: 12 turnos en `heladeria`, `a201b52b0bcb0acfed4f816a07951ee4`) en «Registro de línea base»
- [X] T008 Compuerta previa FR-028 y respaldo (quickstart §1): `docker exec -i pos psql -U admin -d pos_db < pos-specs/specs/121-desglose-denominaciones-cierre/quickstart-preflight.sql` → `fuera_de_catalogo` debe ser **0** en todos los esquemas (si no, **detenerse** y resolver con el negocio); luego `pg_dump --table='<esquema>.cash_count_denominations'` por esquema con datos. Anotar el resultado en «Registro de línea base»

---

## Phase 2: Foundational (datos, sin cambio de comportamiento de la API)

**Purpose**: Esquema, migración y siembra. Todas las historias dependen de estas tablas y columnas.

**⚠️ CRITICAL**: Ninguna historia puede empezar hasta cerrar esta fase.

**⚠️ No desplegar esta fase sola** (corrige la nota «desplegable sola» de plan.md): al quedar `cash_count_denominations.kind` como `NOT NULL` sin valor por defecto, el `close_shift` **actual** inserta líneas sin `kind` y fallaría en PostgreSQL cuando llegue un desglose. Los commits sí se separan (Principio VI), pero la migración se despliega junto con la Fase 3. Hasta cerrar la Fase 3 no cerrar turnos con desglose contra la BD de desarrollo ya migrada.

### Pruebas de la fase (escribirlas primero; fallan hasta implementar)

- [X] T009 [P] Crear `pos-backend/app/characterization_tests/test_migrate_denomination_breakdown.py` sobre SQLite. Importar la revisión de Alembic por ruta con `importlib.util.spec_from_file_location` (los nombres de revisión empiezan por hex) y probar las **funciones de datos** que se definen en T017/T018 (reciben `Connection` y esquema, SQL portable; SQLite 3.46 admite `UPDATE … FROM`): (a) la compuerta detecta una fila con `denomination = 3000` y el mensaje nombra esquema y valor; (b) el tipo se deduce del catálogo por valor (`100000 → billete`, `500 → moneda`); (c) se descartan las filas con `quantity = 0` y se conserva el resto con valor y cantidad intactos; (d) re-ejecutar sobre un esquema ya en forma final no falla ni cambia nada; (e) `counted_amount`, `close_note` y `status` de los turnos quedan idénticos (SC-004, FR-027)
- [X] T010 [P] Crear `pos-backend/app/characterization_tests/test_cash_denomination_catalog.py` con la parte de **siembra y restricciones**: `seed_default_denominations(db)` crea exactamente 11 filas (6 `billete`, 5 `moneda`, valores de data-model.md §1), es idempotente (dos llamadas = 11 filas); el `UNIQUE (denomination)` rechaza un valor repetido; los `CHECK` rechazan `denomination <= 0` y un `kind` distinto de `billete`/`moneda`; el `CHECK quantity > 0` de `CashCountDenomination` rechaza una fila con cantidad 0 (FR-009, FR-012, FR-015)

### Modelos y siembra

- [X] T011 [P] Crear `pos-backend/app/models/denomination_catalog.py`: modelo `DenominationCatalog` (`UUIDPrimaryKeyMixin`, `denomination Numeric(12,2)` único y `kind String(10)`, `{"schema": "tenant"}`) con los CHECK `ck_denomination_value_positive` (`denomination > 0`) y `ck_denomination_kind` (`kind IN ('billete','moneda')`); el `UniqueConstraint("denomination")` **sin nombre explícito** para que la convención de `app/core/models.py` produzca `uq__denomination_catalog__denomination`. Definir en el mismo archivo la constante `DEFAULT_COP_DENOMINATIONS` (11 pares valor/tipo, FR-009) y `seed_default_denominations(db)` idempotente (inserta solo los valores que falten)
- [X] T012 [P] Modificar `pos-backend/app/models/cash_count_denomination.py`: agregar `kind: Mapped[str] = mapped_column(String(10), nullable=False)` (sin valor por defecto), el CHECK `ck_cash_count_kind` (`kind IN ('billete','moneda')`) y cambiar la expresión de `ck_cash_count_quantity_positive` de `quantity >= 0` a `quantity > 0` **conservando el nombre** (el nombre resultante en PostgreSQL es `ck__cash_count_denominations__ck_cash_count_quantity_positive`). No tocar `ck_cash_count_denomination_positive` ni el índice único existente (data-model.md §2)
- [X] T013 [P] Modificar `pos-backend/app/models/cash_shift.py`: agregar `closed_by_user_id` (`UUID(as_uuid=True)`, nullable, referencia blanda sin FK, como `user_id`) y `closed_by_user_name` (`String(255)`, nullable, snapshot), ambos sin valor por defecto (FR-029, data-model.md §3)
- [X] T014 Registrar `DenominationCatalog` en `pos-backend/app/models/__init__.py`, en el bloque «Caja y conciliación», junto a `CashCountDenomination` (depende de T011)
- [X] T015 Modificar `pos-backend/app/core/db.py::tenant_create()`: tras `get_tenant_specific_metadata().create_all(bind=db.connection())` y dentro de la misma transacción, llamar a `seed_default_denominations(db)` para que los tenants nuevos nazcan con el catálogo (research.md R2, FR-012). La sesión de `with_db(schema)` ya traduce `tenant → schema`; no abrir una sesión nueva (depende de T011)
- [X] T016 Modificar `pos-backend/app/characterization_tests/orders_fixtures.py`: agregar `"denomination_catalog"` y `"cash_count_denominations"` a `_ORDERS_TABLE_NAMES` (hoy ninguna de las dos se crea en SQLite), y las ayudas `seed_denomination_catalog(db)` (llama a `seed_default_denominations`) y `make_cash_count_denomination(db, shift, **kw)` (kw por defecto: `denomination=Decimal("10000")`, `kind="billete"`, `quantity=1`). Verificar que `make_user_double()` (ya existe) alcanza para `closed_by_*` (depende de T011, T012)

### Migración de Alembic

- [X] T017 Crear `pos-backend/alembic/versions/<rev>_121_denomination_breakdown.py` (generar el id con `env/bin/python -m alembic revision -m "121 denomination breakdown"` y fijar `down_revision = 'cd3e314a79b8'`; confirmar con `alembic heads` que sigue habiendo un único *head*). Con `@for_each_tenant_schema` y la guarda `_has_table(schema, "cash_shifts")` (copiar el patrón de `cd3e314a79b8_119_report_indexes.py`), y **en una transacción** por esquema: (1) `CREATE TABLE IF NOT EXISTS` de `denomination_catalog` con los mismos nombres de restricción que T011 (`pk__denomination_catalog`, `uq__denomination_catalog__denomination`, `ck__denomination_catalog__ck_denomination_value_positive`, `ck__denomination_catalog__ck_denomination_kind`) y siembra de los 11 valores con `gen_random_uuid()` y `ON CONFLICT (denomination) DO NOTHING`, con la lista COP **escrita como literal** en la migración (no importar código de la aplicación); (2) **compuerta FR-028**: función de datos `_find_out_of_catalog(conn, schema)` y, si devuelve valores, `raise RuntimeError` con esquema y valores (nada se descarta en silencio). Estructurar los pasos de datos como funciones de módulo que reciben `Connection` y esquema para poder probarlas en T009
- [X] T018 En la misma revisión `pos-backend/alembic/versions/<rev>_121_denomination_breakdown.py`, agregar el resto de `upgrade` (data-model.md §6, pasos 3–5), idempotente y tolerante a esquemas ya en forma final: (3) `ADD COLUMN IF NOT EXISTS kind` nulo → función `_backfill_kind(conn, schema)` (`UPDATE … FROM denomination_catalog` por valor, solo donde `kind IS NULL`) → `SET NOT NULL` → `DROP CONSTRAINT IF EXISTS` + `ADD CONSTRAINT ck__cash_count_denominations__ck_cash_count_kind`; (4) función `_discard_zero_quantity(conn, schema)` (`DELETE … WHERE quantity = 0`, registrando cuántas filas descartó), luego `DROP CONSTRAINT IF EXISTS ck__cash_count_denominations__ck_cash_count_quantity_positive` y `ADD CONSTRAINT` con `CHECK (quantity > 0)` — **el `DELETE` va antes del nuevo CHECK**; (5) `ADD COLUMN IF NOT EXISTS closed_by_user_id UUID` y `closed_by_user_name VARCHAR(255)`. No leer ni escribir `counted_amount`, `close_note` ni la diferencia (SC-004). Dejar pasar T009
- [X] T019 En la misma revisión, escribir `downgrade` en orden inverso (data-model.md §6): quitar `closed_by_*` → restaurar `CHECK (quantity >= 0)` con el nombre original → quitar el CHECK y la columna `kind` → `DROP TABLE denomination_catalog`. Con `@for_each_tenant_schema`, la misma guarda `_has_table` y `IF EXISTS`; no debe perder valor ni cantidad de ninguna línea conservada

### Verificación contra PostgreSQL real

- [X] T020 Verificar la migración en la BD de desarrollo (quickstart §2): `env/bin/python -m alembic upgrade head` → por esquema: `denomination_catalog` = 11 filas (6/5), `kind` `NOT NULL`, ninguna fila con `quantity = 0`, tipo correcto por valor, `closed_by_*` existen en `NULL`, **huella md5 idéntica a la de T007**; luego `alembic downgrade -1` (las líneas conservadas siguen con valor y cantidad), `alembic upgrade head` otra vez (reejecutable) y la **compuerta que aborta** con `BEGIN … ROLLBACK` sobre `tenantlocal` insertando `denomination = 3000`. Anotar resultados en «Registro de línea base»
- [X] T021 Verificar la siembra en un tenant nuevo (quickstart §6): crear un tenant desechable con `tenant_create(...)` siguiendo la receta de la memoria `reference_pos_dev_db_psql_tenantlocal` (contraseña válida de 8–12 caracteres, correo sin `.test`), comprobar `SELECT count(*) FROM <esquema_nuevo>.denomination_catalog` = 11 sin acción manual, y limpiar (`DELETE` en `shared.users`/`shared.tenants` y `DROP SCHEMA … CASCADE`)

**Checkpoint**: Esquema listo, migración reversible verificada y T009/T010 en verde. Ya se pueden implementar las historias. (No desplegar aún; ver advertencia arriba.)

---

## Phase 3: User Story 1 - El cajero cierra el turno con su conteo y el servidor calcula los totales (Priority: P1) 🎯 MVP

**Goal**: El cierre recibe solo `{denominación, cantidad}` + observación; el servidor calcula subtotal, efectivo contado y diferencia, persiste únicamente las líneas con cantidad > 0 (con su tipo) y registra quién cerró (FR-001, FR-003, FR-008, FR-014, FR-015, FR-016, FR-029; D-1, D-2, D-3, D-4).

**Independent Test**: Cerrar un turno con efectivo esperado $115.000 enviando 1×$100.000, 1×$10.000 y 1×$5.000 → exactamente 3 líneas guardadas, contado $115.000, diferencia $0, turno cerrado (quickstart §3, casos 1–5).

### Pruebas de US1 (escribirlas primero; fallan hasta implementar)

- [X] T022 [US1] Crear `pos-backend/app/characterization_tests/test_cash_close_denominations.py` (patrón de `test_cash_close_active_orders.py`: `fx.new_session()`, `fx.make_cash_shift`, `fx.seed_denomination_catalog(db)`, invocar `router.close_shift(shift.id, body, db, fx.make_user_double(...))` como función) con la clase `TestCierreConDesglose`; turno con `opening_amount=Decimal("115000")` (esperado $115.000): (a) 100000×1 + 10000×1 + 5000×1 → 3 filas con `kind="billete"`, `counted_amount == 115000`, diferencia 0, `status="closed"` (US1-1, SC-001); (b) 100000×1 + 10000×1 + observación → contado 110000, diferencia −5000 (US1-2); (c) lo mismo **sin** observación → `HTTPException` 422, turno `open`, 0 filas (US1-3, `RN-CASH-10`); (d) 4 líneas con una en cantidad 0 → 3 filas guardadas (US1-4, FR-015); (e) `denominations=[]` + observación → contado 0, 0 filas, diferencia = −esperado (US1-5, D-2); (f) `closed_by_user_id`/`closed_by_user_name` = los del usuario que llama y distintos de `shift.user_id`/`user_name` de apertura (FR-029). Comprobar el estado tras un 422 con `db.rollback()` + nueva consulta, no con `db.refresh` (la sesión de prueba usa autoflush)

### Implementación de US1

- [X] T023 [US1] Crear `pos-backend/app/api/v1/cash/denominations.py` con `resolve_count_lines(db, lines)`: **una** consulta del catálogo (`DenominationCatalog`), mapa valor→tipo por `Decimal`, descarta las líneas con `quantity == 0` y devuelve las restantes (valor, `kind`, cantidad, `subtotal = valor × cantidad`) ordenadas de mayor a menor, más `total_of(lines)` (0 si no hay líneas, D-2). Una denominación ausente del catálogo se rechaza aquí mismo con `HTTPException(422, "La denominación $3.000 no está registrada para este negocio.")` (sin el tipo no se puede resolver la línea; FR-004); incluir un formateador privado de pesos con punto de miles (`$3.000`) que reutilizarán T035
- [X] T024 [US1] Modificar `pos-backend/app/api/v1/cash/schemas.py`: quitar el campo `counted_amount` de `ShiftClose` (conserva `denominations` y `close_note`) y agregar `closed_by_user_id: UUID | None = None` y `closed_by_user_name: str | None = None` a `ShiftResponse` (contracts/close-shift-api.md; el rechazo explícito del campo llega en US2)
- [X] T025 [US1] Modificar `close_shift` en `pos-backend/app/api/v1/cash/router.py` (depende de T023, T024): cambiar `_: User` por `user: User = Depends(get_current_user)`; **conservar tal cual** el bloqueo por pedidos activos de la spec 119 y su snapshot; reemplazar el bloque `counted = …` (ramas `RN-CASH-09`) por `lines = denominations.resolve_count_lines(db, body.denominations)` y `counted = denominations.total_of(lines)`; asignar `shift.counted_amount = counted` y llamar **siempre** a `service.reconcile` (ya no existe `counted is None`), exigiendo `close_note` no vacía si la diferencia ≠ 0 con el mismo mensaje y 422 de hoy; insertar una `CashCountDenomination` por línea **con `kind`**; fijar `closed_by_user_id = user.id` y `closed_by_user_name = user.name`; un solo `commit`. Actualizar el comentario del cuerpo citando A-130/A-131 y añadir `from app.api.v1.cash import denominations` a las importaciones
- [X] T026 [P] [US1] Adaptar `pos-backend/app/characterization_tests/test_cash_close_active_orders.py` (7 llamadas a `ShiftClose()`): las que **completan** el cierre pasan a `ShiftClose(close_note="…")` y reciben `fx.make_user_double()` como 4.º argumento (D-2: sin conteo ⇒ contado $0 ⇒ diferencia ≠ 0 ⇒ observación; FR-029: el usuario ya no se descarta); las que terminan en 409 antes de persistir no cambian. La intención de cada prueba no cambia. Citar «D-1/D-2, A-130/A-131» en el docstring del módulo (mismo commit que T025)
- [X] T027 [P] [US1] Adaptar `pos-backend/app/characterization_tests/test_cash_report_query_budget.py` (6 llamadas) con el mismo criterio que T026. **Vigilar el presupuesto de consultas**: si `TOPE_TURNO` o el conteo de `INSERT` se rompen, documentar la cifra **medida** en el docstring y ajustar solo entonces (research.md R11); no subirlo «a ojo»
- [X] T028 [P] [US1] Adaptar `pos-backend/app/characterization_tests/test_cash_report_batch_identity.py` (5 usos: 4 llamadas más la mención en el docstring de la línea ≈ 40, que dice «`ShiftClose()` sin `counted_amount`» y queda desactualizada) con el mismo criterio que T026
- [X] T029 [P] [US1] Adaptar `pos-backend/app/characterization_tests/test_cash_shift_sales_report.py` (9 usos: 8 llamadas más la mención del docstring de la línea ≈ 34) con el mismo criterio que T026
- [X] T030 [US1] Actualizar `pos-backend/app/scripts/e2e_qr_flow.py` (≈ línea 355): reemplazar `{"counted_amount": "30.00"}` por `{"denominations": [{"denomination": 50, "quantity": 1}], "close_note": "<texto>"}` (D-1). El esperado $30,00 no es componible con el catálogo COP, así que la diferencia ≠ 0 exige observación; confirmar que el tenant que usa el script ya tiene catálogo (migración de T020) y, si no, cerrar con `{"denominations": [], "close_note": "<texto>"}`
- [X] T031 [US1] Ejecutar la suite completa del backend **sola** (`env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`): sin fallos nuevos frente a T005, T022 en verde, y `grep -rn 'CONGELA comportamiento actual' pos-backend/app/characterization_tests/test_cash_*.py` sin ninguna prueba protegida afectada (Principio III)

**Checkpoint**: El servidor calcula y persiste el desglose. US1 verificable por sí sola; el frontend actual aún no es compatible (se coordina en US3).

---

## Phase 4: User Story 2 - El servidor rechaza cualquier conteo inválido sin cerrar el turno ni guardar nada (Priority: P1)

**Goal**: Rechazo atómico con `422` en español ante totales del cliente, denominaciones repetidas, cantidades que desbordan o líneas inválidas; el turno sigue abierto y no se guarda nada (FR-002, FR-004 a FR-007; D-1).

**Independent Test**: Enviar cierres con `counted_amount`, denominación fuera del catálogo, repetida, cantidad enorme y 9 válidas + 1 inválida → en cada caso `422`, turno abierto y cero líneas guardadas (quickstart §3, casos 6–11).

### Pruebas de US2 (escribirlas primero)

- [X] T032 [US2] Agregar a `pos-backend/app/characterization_tests/test_cash_close_denominations.py` la clase `TestRechazosDelCierre` (cada caso verifica `HTTPException` 422, turno `open`, `counted_amount` y `close_note` sin tocar, 0 filas): (a) cuerpo con `counted_amount: 95000` + líneas → 422 con «Recarga la página» (US2-4), y también con `total`, `difference` y `subtotal`, y con `subtotal` dentro de una línea (construir el cuerpo con `ShiftClose.model_validate({...})`); (b) `counted_amount: None` **no** se rechaza (research.md R4); (c) denominación 3000 → 422 que nombra «$3.000» (US2-1); (d) `10000` y `Decimal("10000.00")` en la misma petición → 422 «repetida» (US2-3, edge case), también cuando una de las dos trae cantidad 0; (e) `100000 × 1_000_000_000` → 422 «excede el monto máximo», nunca 500; (f) 9 líneas válidas + 1 inválida → 0 filas (US2-5, todo o nada); (g) cantidad negativa y cantidad `2.5` → `pydantic.ValidationError` al construir `DenominationIn` (US2-2, FR-005); (h) cuerpo con `counted_amount` **y** pedidos activos sin cobrar → 422, no 409 (el rechazo va primero, research.md R4)

### Implementación de US2

- [X] T033 [US2] En `pos-backend/app/api/v1/cash/denominations.py` agregar `reject_client_totals(body)`: lanza `HTTPException(422, detail=<cadena>)` con el texto de contracts/close-shift-api.md («La aplicación está desactualizada: el total contado ahora lo calcula el servidor. Recarga la página e intenta cerrar el turno de nuevo.») si hay un valor **no nulo** en `counted_amount`, `total`, `difference` o `subtotal` (en `body.model_extra`), o en `subtotal`/`total` dentro de alguna línea; cualquier otra clave desconocida se ignora como hoy
- [X] T034 [US2] En `pos-backend/app/api/v1/cash/schemas.py` declarar `model_config = ConfigDict(extra="allow")` en `ShiftClose` y `DenominationIn` (no `forbid`: el handler de validación por defecto de FastAPI devolvería un `detail` en lista y en inglés, ver research.md R4)
- [X] T035 [US2] En `resolve_count_lines` de `pos-backend/app/api/v1/cash/denominations.py` agregar, **antes** de consultar el catálogo, la detección de denominación repetida (`Decimal` en un `set`: `10000` ≡ `10000.00`, independiente de la cantidad) → 422 «La denominación $10.000 está repetida en el conteo.» (FR-006); y, tras calcular, si `Σ subtotales > 9 999 999 999,99` → 422 «El efectivo contado excede el monto máximo permitido ($9.999.999.999,99).» (valida el total, no cada cantidad; research.md R5). Reutilizar el formateador de T023
- [X] T036 [US2] En `close_shift` de `pos-backend/app/api/v1/cash/router.py` llamar a `denominations.reject_client_totals(body)` como **primera** sentencia, antes de leer el turno y antes del bloqueo por pedidos activos (research.md R4)
- [X] T037 [US2] Verificar contra la API real (quickstart §3, casos 1–12) con `curl` sobre `uvicorn` **nativo** (no Docker; memoria `reference_pos_api_docker_vs_nativo`) y un turno con esperado $115.000; tras cada `422` comprobar en SQL que el turno sigue `open` y `cash_count_denominations` no ganó filas. Anotar los resultados al final de este archivo

**Checkpoint**: US1 + US2 completas: el contrato del backend es estricto y atómico.

---

## Phase 5: User Story 3 - El arqueo se arma desde el catálogo de denominaciones del negocio (Priority: P1)

**Goal**: El backend expone el catálogo en solo lectura y el modal de arqueo construye sus filas desde él (sin lista fija), muestra total y diferencia como «estimado», deja la observación siempre visible y envía solo `{denominación, cantidad}` (FR-009 a FR-013, FR-025, FR-026).

**Independent Test**: Abrir el arqueo en un tenant con el catálogo por defecto → 11 filas con su tipo, total estimado que se actualiza al teclear y petición de cierre sin `counted_amount` (quickstart §7).

> **Coordinación**: el backend de US1/US2 ya rechaza `counted_amount`; el frontend de esta historia debe desplegarse **junto** con él (despliegue coordinado, sin ventana de compatibilidad). Los bloques de backend y de frontend son de repositorios distintos y pueden avanzar en paralelo.

### Backend — catálogo

- [X] T038 [US3] Agregar a `pos-backend/app/characterization_tests/test_cash_denomination_catalog.py` la clase `TestEndpointCatalogo`: `router.list_denominations(db, user)` devuelve 11 elementos de mayor a menor con su `kind` (6 `billete`, 5 `moneda`); un catálogo vacío devuelve `[]` con éxito; el router **no** expone `POST`/`PUT`/`PATCH`/`DELETE` bajo `/cash/denominations` (recorrer `router.routes`) (US3-1, US3-5, FR-011)
- [X] T039 [US3] Agregar `DenominationCatalogItem` (`denomination: Decimal`, `kind: str`, `model_config = ConfigDict(from_attributes=True)`) en `pos-backend/app/api/v1/cash/schemas.py`
- [X] T040 [US3] Agregar `list_catalog(db)` en `pos-backend/app/api/v1/cash/denominations.py` (todas las filas de `DenominationCatalog` ordenadas por `denomination` descendente) y reutilizarla desde `resolve_count_lines` si evita una segunda consulta
- [X] T041 [US3] Agregar en `pos-backend/app/api/v1/cash/router.py` el endpoint `GET /denominations` (`response_model=list[DenominationCatalogItem]`, `Depends(get_current_user)`, resumen «Catálogo de denominaciones del tenant»). **No** modificar `_MESERO_ALLOWED_ROUTES` de `app/core/dependencies.py` (research.md R7)

### Frontend — pantalla de arqueo

- [X] T042 [P] [US3] Modificar `pos-heladeria/src/app/modules/cash-register/interfaces/cash.interface.ts`: agregar `CatalogDenomination` (`{ denomination: string; kind: 'billete' | 'moneda' }`) y quitar `counted_amount` de `ShiftClosePayload` (queda `{ denominations: DenominationIn[]; close_note?: string | null }`)
- [X] T043 [P] [US3] Modificar `pos-heladeria/src/app/modules/cash-register/interfaces/cash-session.interface.ts`: agregar `kind: 'billete' | 'moneda'` y `kindLabel: string` («Billete»/«Moneda») a `Denomination`
- [X] T044 [US3] Agregar `getDenominations(): Promise<CatalogDenomination[]>` (`GET ${baseUrl}/denominations`) en `pos-heladeria/src/app/modules/cash-register/services/cash.service.ts`, junto a `getReport` (depende de T042)
- [X] T045 [P] [US3] Adaptar `pos-heladeria/src/app/modules/cash-register/services/cash.service.spec.ts`: la prueba «closes a shift with denominations and close_note» (≈ línea 101) ya no envía `counted_amount` y verifica que el cuerpo **no** lo contiene; agregar la prueba de `getDenominations()` (URL y respuesta)
- [X] T046 [US3] Adaptar y ampliar `pos-heladeria/src/app/modules/cash-register/services/cash-session.store.spec.ts` (antes de tocar el store): el `api` simulado de `crear()` suma `getDenominations` (resuelve el catálogo de 11 filas) y el helper carga el catálogo antes de `store.setDenom(100000, '1')`; nuevas pruebas: catálogo `cargando` → `arqueoDisabled()` true; `error` (rechazo del servicio) y catálogo vacío → `arqueoDisabled()` true y **ninguna** llamada a `closeShift`; `reintentarCatalogo()` recupera; todo en cero → `arqueoDisabled()` true (US3-7); el cuerpo de `closeShift` lleva solo `denominations` con cantidad > 0 y `close_note`, **sin** `counted_amount`; ante un `422` el modal sigue abierto, `denomCounts` se conserva y `error()` trae el mensaje del servidor (US3-4, US3-8)
- [X] T047 [US3] Modificar `pos-heladeria/src/app/modules/cash-register/services/cash-session.store.ts` (depende de T042–T044): eliminar `DENOMS` (≈ línea 87); agregar las señales `catalogo` y `catalogoEstado` (`'cargando' | 'listo' | 'error'`), un computed `catalogoError` (estado `error`, o `listo` con catálogo vacío), y `cargarCatalogo()`/`reintentarCatalogo()` (un `try/catch` sobre `api.getDenominations()`, sin caché entre aperturas); `openArqueo()` conserva su reinicio de estado y dispara `cargarCatalogo()`; derivar `denominaciones` (con `kind` y `kindLabel`), `totalContado` y `contadoIngresado` de `catalogo()`; `arqueoDisabled` suma `catalogoEstado() !== 'listo' || catalogo().length === 0` y **conserva** `!contadoIngresado()`; `confirmarArqueoYCerrar()` arma las líneas desde `catalogo()` (solo cantidad > 0) y llama a `closeShift(shift.id, { denominations, close_note })` sin `counted_amount`; no limpiar `denomCounts` en el `catch`
- [X] T048 [US3] Adaptar y ampliar `pos-heladeria/src/app/modules/cash-register/components/cash-arqueo-modal.component.spec.ts` (antes de tocar el componente): el `fakeStore` suma `catalogoEstado`, `catalogoError`, `reintentarCatalogo` y `denominaciones` con `kind`/`kindLabel`; pruebas: una fila por denominación con su tipo; rótulos «(estimado)» en total y diferencia; el `textarea` de observación **siempre** presente (aunque `requiereObservacion` sea false) con el rótulo «opcional»/«requerida por diferencia» según el caso; con `catalogoError` aparece el mensaje y el botón «Reintentar» que invoca `reintentarCatalogo`, y el botón de confirmar está deshabilitado
- [X] T049 [US3] Modificar `pos-heladeria/src/app/modules/cash-register/components/cash-arqueo-modal.component.ts` (depende de T047): rótulos «Total contado (estimado)» y «Diferencia (estimado)», y texto introductorio que indique que los valores oficiales los calcula el servidor al cerrar; mostrar el tipo (`kindLabel`) en cada fila de la rejilla; el bloque de observación sale de `@if (store.requiereObservacion())` y queda siempre visible con rótulo variable (FR-025); estado «Cargando denominaciones…» y, con `catalogoError()`, mensaje de error + botón «Reintentar» (`store.reintentarCatalogo()`) sin lista de respaldo (FR-013)
- [X] T050 [US3] Ejecutar `npx ng test --watch=false --include 'src/app/modules/cash-register/**/*.spec.ts'` en `pos-heladeria`: todo verde. Revisar si `pages/cash-page.component.spec.ts` (simula `openArqueo`) o algún otro spec instancia el store y necesita `getDenominations` en su servicio simulado
- [X] T051 [US3] Verificación manual (quickstart §7 y §4 punto 1): `GET /cash/denominations` devuelve 11 elementos de mayor a menor y un MESERO recibe `403`; con `ng serve`, el modal muestra 11 filas con tipo, total/diferencia «(estimado)», confirmar deshabilitado con todo en 0, observación siempre visible, error + «Reintentar» al bloquear la petición del catálogo (0 peticiones de cierre), `…/close` sin `counted_amount`, y los `422` de observación y de denominación sin cerrar el modal (escenarios 6 y 7 del quickstart). Anotar los resultados al final de este archivo

**Checkpoint**: US1 + US2 + US3 = **flujo de extremo a extremo** (cierre desde pantalla con desglose). Es el MVP desplegable.

---

## Phase 6: User Story 4 - El reporte de cierre muestra «Desglose del conteo» (Priority: P2)

**Goal**: El reporte (inmediato y desde el histórico) muestra la tabla Denominación · Tipo · Cantidad · Subtotal con una fila de total que coincide con el efectivo contado, y la línea «Contado por» (FR-020, FR-021, FR-023; US4).

**Independent Test**: Cerrar el turno de US1, abrir su reporte y comparar la tabla con las líneas ingresadas y la suma de subtotales con «Efectivo contado» (quickstart §4 puntos 2–4 y §8 puntos 1–2).

### Backend

- [X] T052 [US4] Crear `pos-backend/app/characterization_tests/test_cash_report_denominations.py` (mismas fixtures que T022): tras cerrar con 3 líneas, `router.shift_report(shift.id, db, user)["denominations"]` trae 3 elementos de mayor a menor con `kind`, `quantity` y `subtotal`, y **la suma de `subtotal` es igual a `shift.counted_amount`** (FR-021, US4-1); cierre con lista vacía → `denominations == []` y `counted_amount == 0` (US4-4); `shift.closed_by_user_name` es el de quien cerró («Luis») aunque quien consulta el reporte sea otro usuario o el nombre del usuario cambie después (US4-5, US4-6); un turno **abierto** devuelve `denominations == []` y `closed_by_* == None` sin fallar
- [X] T053 [US4] En `pos-backend/app/api/v1/cash/schemas.py` agregar `CountLineOut` (`denomination: Decimal`, `kind: str`, `quantity: int`, `subtotal: Decimal`) y cambiar `ShiftReportResponse.denominations` de `list[DenominationIn]` a `list[CountLineOut]` (cambio **aditivo**, contracts/shift-report-api.md)
- [X] T054 [US4] En `shift_report` de `pos-backend/app/api/v1/cash/router.py` construir `CountLineOut(denomination=d.denomination, kind=d.kind, quantity=d.quantity, subtotal=d.denomination * d.quantity)` (el subtotal se **deriva**, no se almacena; sigue siendo una sola consulta ordenada por `denomination` descendente). Quitar de las importaciones lo que deje de usarse

### Frontend

- [X] T055 [P] [US4] Modificar `pos-heladeria/src/app/modules/cash-register/interfaces/cash.interface.ts`: agregar `closed_by_user_id?: string | null` y `closed_by_user_name?: string | null` a `CashShift`; agregar `CountLine` (`{ denomination: string; kind: 'billete' | 'moneda'; quantity: number; subtotal: string }`) y cambiar `ShiftReport.denominations` a `CountLine[]`. En `pos-heladeria/src/app/modules/cash-register/interfaces/cash-session.interface.ts` agregar `DesgloseRow` (`denominacionFmt`, `tipoLabel`, `cantidad`, `subtotalFmt`)
- [X] T056 [US4] Ampliar `pos-heladeria/src/app/modules/cash-register/services/cash-session.store.spec.ts` (antes de tocar el store): `desgloseView` formatea las filas con el patrón de `movimientosView` (importes con `fmt`, «Billete»/«Moneda»); `desgloseTotal` es la suma de los subtotales; `sinDesglose` es true cuando no hay líneas; `contadoPor` devuelve `closed_by_user_name` o `null`
- [X] T057 [US4] En `pos-heladeria/src/app/modules/cash-register/services/cash-session.store.ts` agregar los computeds `desgloseView` (desde `report()?.denominations`), `desgloseTotal` (Σ de los subtotales de las líneas, no de `counted_amount`), `sinDesglose` y `contadoPor` (depende de T055)
- [X] T058 [US4] Ampliar `pos-heladeria/src/app/modules/cash-register/components/cash-report.component.spec.ts` (antes de tocar el componente): el `fakeStore` suma `desgloseView`, `desgloseTotal`, `sinDesglose`, `contadoPor`; pruebas: con líneas se renderiza la tabla con encabezados Denominación/Tipo/Cantidad/Subtotal, una fila por línea y la fila «Total»; sin líneas aparece exactamente «No se registró desglose para este turno» y no hay tabla; «Contado por: Luis» aparece solo si `contadoPor` tiene valor y, si no, no hay rastro de la línea ni marcador vacío (US5-4); la misma sección se renderiza con `reportContext` `'live'` e `'history'` (FR-023)
- [X] T059 [US4] En `pos-heladeria/src/app/modules/cash-register/components/cash-report.component.ts` agregar la sección «Desglose del conteo» **entre «Arqueo de caja» y «Movimientos»** (research.md R9, contracts/shift-report-api.md): encabezado, línea «Contado por: {nombre}» solo si existe, tabla Denominación · Tipo · Cantidad · Subtotal (tipo como «Billete»/«Moneda», importes con `store.fmt`) con fila final «Total» (`desgloseTotal`), o el mensaje exacto de FR-022 si `sinDesglose()`. **No** corregir «Cajero: {{ store.cajero() }}» (muestra al usuario que mira el reporte; fuera de alcance, Principio V — ver research.md, hallazgo adicional) (depende de T057)
- [X] T060 [US4] Verificación manual (quickstart §4 puntos 2–4 y §8 puntos 1–2): `GET /cash/shifts/{id}/report` trae `kind`/`quantity`/`subtotal` y la suma = `counted_amount`; cerrar con «Luis» un turno abierto por «Ana» → `closed_by_user_name="Luis"` y `user_name="Ana"`, y renombrar a Luis en `shared.users` no cambia el reporte; en pantalla, la sección con 3 filas, «Contado por», fila «Total» = «Efectivo contado» y la diferencia de −$5.000 resaltada como faltante. Anotar los resultados al final de este archivo

**Checkpoint**: Los reportes nuevos muestran el desglose y quién contó.

---

## Phase 7: User Story 5 - Los turnos cerrados antes de esta funcionalidad siguen siendo consultables (Priority: P2)

**Goal**: Los turnos históricos conservan contado, diferencia y observación; con líneas muestran su tipo, sin líneas muestran el mensaje, y nunca aparece «Contado por» ni un error (FR-022, FR-027; SC-004, SC-008). La migración en sí ya está en la Fase 2 (T017–T020); esta fase demuestra el comportamiento de lectura sobre datos reales.

**Independent Test**: Abrir el reporte de un turno histórico sin líneas (mensaje) y de uno con líneas previas (tabla con tipo) y comparar contado/diferencia contra la huella de T007 (quickstart §4 punto 5 y §8 punto 3).

- [X] T061 [US5] Agregar a `pos-backend/app/characterization_tests/test_cash_report_denominations.py` la clase `TestTurnosHistoricos`: (a) turno cerrado **sin** filas y sin `closed_by_*` (sembrado directo, simulando un turno anterior a la spec) → `denominations == []`, `counted_amount` y diferencia intactos y `shift.closed_by_user_name is None`, sin error (US5-1, US5-4); (b) turno cerrado con filas previas creadas con `fx.make_cash_count_denomination(..., kind="billete")` → el reporte las devuelve con su tipo y `subtotal` (US5-2); (c) turno histórico cerrado con `counted_amount = None` (cierre antiguo «sin conteo») → el reporte no falla
- [X] T062 [US5] Verificar sobre la BD de desarrollo ya migrada (quickstart §4 punto 5): `GET /cash/shifts/{id}/report` de los turnos históricos reales del esquema `heladeria` — los 2 sin desglose devuelven `denominations: []` y `closed_by_*: null`, los 10 con desglose devuelven todas las líneas con `kind` — y recalcular la huella `md5` de T007: **0 diferencias** en `counted_amount`, `close_note` y estado (SC-004, US5-3). Anotar los resultados al final de este archivo
- [X] T063 [US5] Verificación en pantalla (quickstart §8 punto 3): desde el histórico (administrador) abrir un turno histórico **sin desglose** → mensaje exacto «No se registró desglose para este turno», efectivo contado y diferencia visibles, **sin** «Contado por» y **sin errores en consola** (`mcp__chrome-devtools__list_console_messages`); abrir uno con desglose → tabla con tipo. Anotar los resultados al final de este archivo

**Checkpoint**: El histórico sigue íntegro y legible.

---

## Phase 8: User Story 6 - El desglose es inmutable y el reporte impreso lo incluye (Priority: P2)

**Goal**: Un turno cerrado no admite ninguna escritura sobre su desglose; los cierres simultáneos resuelven con exactamente un ganador y un `409` sin `500`; la impresión incluye la tabla (o el mensaje) sin cortar filas (FR-017, FR-018, FR-019, FR-024; SC-005, SC-006).

**Independent Test**: Reenviar el cierre de un turno cerrado → `409` con el desglose intacto; imprimir un turno con 11 líneas sin filas cortadas (quickstart §3 caso 13, §5 y §8 punto 4).

### Backend

- [X] T064 [US6] Agregar a `pos-backend/app/characterization_tests/test_cash_close_denominations.py` la clase `TestInmutabilidadYConcurrencia`: (a) reenviar el cierre de un turno cerrado → `HTTPException` 409 «El turno ya está cerrado» y las filas, `counted_amount`, diferencia y `closed_by_*` quedan **idénticos** (US6-1, FR-018); (b) N reintentos seguidos no crean ninguna línea nueva (SC-006); (c) forzar un `IntegrityError` en el `commit` del cierre (adaptar `force_flush_integrity_error` de `orders_fixtures.py` a `db.commit`) → 409 en lugar de excepción sin controlar, y el turno no queda a medio cerrar (FR-019); (d) ninguna ruta del router permite editar, reemplazar ni borrar las líneas del desglose (recorrer `router.routes`; US6-2, FR-017). La suite es SQLite y ignora `FOR UPDATE`: solo demuestra el resultado secuencial; la concurrencia real va en T068
- [X] T065 [US6] Agregar `get_shift_for_update(db, shift_id)` en `pos-backend/app/api/v1/cash/service.py`: `select(CashShift).where(CashShift.id == shift_id).with_for_update()` y `404 "Shift not found"` si no existe (mismo patrón que `resolve_dine_in_table_order`, que ya usa `with_for_update`; research.md R5)
- [X] T066 [US6] En `close_shift` de `pos-backend/app/api/v1/cash/router.py` (depende de T065): leer el turno con `service.get_shift_for_update` en lugar de `get_or_404` (queda **después** de `reject_client_totals` y **antes** del `409` de turno cerrado), y envolver el `db.commit()` final en `try/except IntegrityError` → `db.rollback()` + `HTTPException(409, "El turno ya está cerrado")`. Cierra la ventana de carrera A-17 (research.md H8)

### Frontend — impresión

- [X] T067 [P] [US6] En `pos-heladeria/src/app/modules/cash-register/components/cash-report.component.ts`, dentro del bloque `@media print` de `styles`, agregar `tr { break-inside: avoid; }` y `thead { display: table-header-group; }` (SC-005, research.md R9). **No** tocar `dashboard-layout.component.ts` ni la clase `printing-cash-report`; los botones siguen con `print:hidden`

### Verificación

- [X] T068 [US6] Verificar contra PostgreSQL real (quickstart §5 y §3 caso 13): con un turno abierto y un desglose válido lanzar **dos cierres en paralelo** (`curl … &` + `wait`, o dos hilos con `httpx`) y repetir ≈ 20 veces con turnos nuevos → siempre exactamente un `200` y un `409`, nunca un `500`, y `SELECT count(*) FROM cash_count_denominations WHERE cash_shift_id = …` igual al número de líneas de la petición; reenviar el cierre del caso 1 → `409` con desglose idéntico. Anotar los resultados al final de este archivo
- [X] T069 [US6] Verificar la impresión (quickstart §8 puntos 4–5): «Imprimir / Exportar reporte» con un turno de **11 líneas** → la vista previa incluye la tabla (o el mensaje de FR-022 en un turno sin desglose), ninguna fila cortada entre páginas y encabezado repetido; revisar en claro/oscuro y a ancho móvil que la tabla no desborda. Anotar los resultados al final de este archivo

**Checkpoint**: Las seis historias funcionan de forma independiente y en conjunto.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Regresión completa, cierre documental y condiciones de despliegue.

- [X] T070 [P] En `pos-specs/specs/000-reconocimiento/registro-de-anomalias.md`: anotar en **A-129**, «Riesgo asumido», «resuelto por la spec 121» para la ventana de carrera de `close_shift` (A-17), y actualizar la línea de estado de **A-17** (≈ línea 597) con la misma referencia para `close_shift`; actualizar la fila **A-20 / RN-CASH-09** de la tabla de preguntas (≈ línea 74): «~~Mitigado~~ **Superada por A-130/A-131 (spec 121)**: el servidor calcula el contado y ya no existe el cierre sin conteo», con una nota equivalente al final de la entrada A-20 (≈ línea 673); y marcar el «Estado» de A-130 a A-134 como «REGISTRADA, implementada»
- [X] T071 [P] Corregir en `pos-specs/specs/121-desglose-denominaciones-cierre/spec.md`, sección «Contexto y comportamiento actual», la viñeta «El frontend lleva la lista fija…» (premisa inexacta, research.md H3): el store **ya** filtra las líneas con cantidad 0 (`confirmarArqueoYCerrar`, `.filter((d) => d.quantity > 0)`). Es un cambio de redacción: no altera ningún requisito, decisión ni criterio de aceptación. Corregir además el escenario 5 de la User Story 4 (hallazgo I2 del análisis): el «Cajero:» del reporte hoy muestra al usuario que consulta (`cash-report.component.ts:19`), no al que abrió el turno; la redacción pasa a exigir solo «Contado por: Luis»
- [ ] T072 **[PARCIAL: puntos 1, 2, 4 y 5 hechos; el 3 (`e2e_qr_flow.py`) bloqueado porque el script está obsoleto desde antes de esta spec, ver «Registro de verificaciones»]** Regresión completa (quickstart §9), una suite a la vez y **nunca** backend y frontend en paralelo: (1) backend completo → recuento de T005 **más** las pruebas nuevas, sin fallos nuevos; (2) `ng test` del módulo `cash-register` en verde y suite completa de `pos-heladeria` con el **mismo** conjunto de fallos preexistentes de T006 (ninguno nuevo); (3) `env/bin/python app/scripts/e2e_qr_flow.py` termina en «TODO OK ✔»; (4) el bloqueo por pedidos activos (caso 3.12) y `/cash/shifts/{id}/sales-report` de la spec 119 siguen igual; (5) `grep` confirma que ningún test «CONGELA comportamiento actual:» quedó en rojo sin decisión que lo ampare (Principio III)
- [X] T073 Recorrer los criterios de salida del quickstart: SC-001 a SC-008 verificados con evidencia (referenciando T020, T031, T037, T051, T060, T062, T068, T069, T072), huella `md5` idéntica antes/después y recuento de pruebas = línea base + nuevas; registrar el resultado final en «Registro de línea base»
- [X] T074 [P] Actualizar `pos-specs/specs/121-desglose-denominaciones-cierre/checklists/requirements.md` con una nota de cierre (estado de implementación, enlace a este `tasks.md`, tareas manuales pendientes si las hay) — paso final del plan
- [ ] T075 **[A CARGO DEL EQUIPO — no ejecutable desde el entorno de desarrollo]** Condiciones operativas de despliegue (a cargo del equipo; **no ejecutable desde el entorno de desarrollo**): (1) repetir en **producción** la compuerta FR-028 (`quickstart-preflight.sql`) y el respaldo `pg_dump --table` de `cash_count_denominations` por esquema; (2) desplegar `pos-backend` y `pos-heladeria` **de forma coordinada** (la migración corre con el backend; el `422` por `counted_amount` es el mecanismo de la ventana de despliegue); (3) avisar que un cajero con la pantalla anterior abierta deberá recargar y perderá el conteo tecleado (costo aceptado en la spec)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Fase 1)**: sin dependencias. T001–T002 (registro) deben cerrarse **antes** de implementar; T003–T004 antes de tocar código; T005 → T006 en orden, nunca en paralelo.
- **Foundational (Fase 2)**: depende de Setup; **bloquea** todas las historias. Pruebas (T009–T010) → modelos (T011–T013) → registro/siembra/fixtures (T014–T016) → migración (T017 → T018 → T019, mismo archivo) → verificación en PostgreSQL (T020, T021).
- **US1 (Fase 3)** → **US2 (Fase 4)** → **US6 (Fase 8, parte backend)**: tocan la misma función `close_shift` y el mismo módulo `denominations.py`; van en secuencia.
- **US3 (Fase 5)**: el backend del catálogo (T038–T041) solo necesita la Fase 2; el frontend (T042–T051) se puede hacer **en paralelo con el backend** (otro repositorio, contrato ya fijado). Para probar de extremo a extremo hace falta US1 + US2.
- **US4 (Fase 6)**: backend (T052–T054) solo necesita la Fase 2 (siembra sus propias líneas con la fábrica de T016); el frontend (T055–T060) edita los mismos archivos que US3 (`cash.interface.ts`, store, specs), por lo que va **después** de T042–T049.
- **US5 (Fase 7)**: depende de la migración (T020) y de US4 (el reporte que se verifica).
- **US6 (Fase 8)**: T064–T066 después de US1/US2; T067 (impresión) después de T059 (la tabla ya existe).
- **Polish (Fase 9)**: depende de todas las historias que se quieran entregar.

### Dentro de cada historia

- Las pruebas se escriben **antes** y deben fallar hasta implementar.
- Modelos → servicios/módulo `denominations.py` → router → verificación.
- La adaptación de las 4 suites existentes (T026–T029) viaja **en el mismo commit** que el cambio de contrato (T025); de lo contrario la suite queda en rojo entre commits.

### Parallel Opportunities

- T003 ∥ T004 (ramas de repos distintos).
- T009 ∥ T010 (archivos de prueba nuevos); T011 ∥ T012 ∥ T013 (tres modelos distintos).
- T026 ∥ T027 ∥ T028 ∥ T029 (cuatro suites distintas, mismo criterio de adaptación).
- Backend de US3 (T038–T041) ∥ frontend de US3 (T042–T049).
- T042 ∥ T043; T045 ∥ T042/T043 (archivos distintos).
- T070 ∥ T071 ∥ T074 (documentos distintos).

### Parallel Example: Foundational

```bash
# Pruebas nuevas (archivos distintos):
Task: "T009 test_migrate_denomination_breakdown.py"
Task: "T010 test_cash_denomination_catalog.py (siembra y restricciones)"

# Los tres modelos a la vez:
Task: "T011 pos-backend/app/models/denomination_catalog.py"
Task: "T012 pos-backend/app/models/cash_count_denomination.py"
Task: "T013 pos-backend/app/models/cash_shift.py"
```

### Parallel Example: adaptación de las suites de caja (D-1/D-2)

```bash
Task: "T026 test_cash_close_active_orders.py"
Task: "T027 test_cash_report_query_budget.py"
Task: "T028 test_cash_report_batch_identity.py"
Task: "T029 test_cash_shift_sales_report.py"
```

---

## Implementation Strategy

### MVP primero (US1 + US2 + US3, todas P1)

1. Fase 1 (Setup) y Fase 2 (Foundational): registro, ramas, línea base, esquema y migración verificada.
2. Fase 3 (US1): el servidor calcula y persiste el desglose.
3. Fase 4 (US2): rechazo atómico de conteos inválidos.
4. Fase 5 (US3): catálogo + modal. **Detenerse y validar** el flujo completo (quickstart §3 y §7).
5. El MVP real es US1 + US2 + US3 **juntas**: el backend estricto de US1/US2 rompe la pantalla actual hasta que US3 la actualice, así que no se despliega una sin la otra.

### Entrega incremental

1. Setup + Foundational → esquema listo (no desplegar solo; ver advertencia de la Fase 2).
2. US1 + US2 + US3 → MVP → verificar → desplegar de forma coordinada.
3. US4 → reporte con desglose y «Contado por».
4. US5 → verificación del histórico sobre datos reales.
5. US6 → inmutabilidad, concurrencia e impresión.
6. Polish → regresión y cierre documental.

### Estrategia con dos desarrolladores

1. Ambos cierran Setup + Foundational.
2. Tras la Fase 2: A toma el backend (US1 → US2 → US6 backend); B toma el frontend (US3 → US4), apoyado en los contratos de `contracts/`.
3. Se integran para T051, T060, T068 y T069 (verificación de extremo a extremo).

---

## Notes

- [P] = archivos distintos y sin dependencias pendientes.
- Cada tarea cita el requisito (FR/SC/US) o la decisión (D-1…D-4, R1…R12) que la origina (Principio XII).
- Ningún `commit` sin pedido explícito del usuario; unidades pequeñas, en inglés, Conventional Commits y **sin** líneas de autoría de IA (Principio XV y memoria `feedback_git_commit_conventions`). Sugerencia de agrupación: registro (T001–T002, `pos-specs`) · datos (T009–T019) · contrato del cierre con las suites adaptadas (T022–T036) · catálogo (T038–T041) · frontend de arqueo (T042–T049) · reporte (T052–T059) · impresión y concurrencia (T064–T067) · cierre documental (T070–T074).
- Las pruebas del backend invocan el router como función (patrón de `test_cash_close_active_orders.py`); `close_shift` ahora recibe `user`, por eso las llamadas que completan un cierre pasan `fx.make_user_double()`.
- **Fuera de alcance** (no tocar): el «Cajero:» del encabezado del reporte (research.md, hallazgo adicional), el renombrado de `cash_count_denominations`, `_MESERO_ALLOWED_ROUTES`, `dashboard-layout.component.ts` y cualquier administración del catálogo (FR-012).
- `tenant_create()` y `FOR UPDATE` no se pueden demostrar en SQLite: se verifican en PostgreSQL real (T021, T068).

## Registro de línea base

> Se rellena durante la ejecución (T005–T008, T020, T037, T051, T060, T062, T063, T068, T069, T073). No borrar las referencias: sirven para la comparación antes/después.

| Medida | Antes (T005–T008) | Después |
|--------|-------------------|---------|
| Recuento de pruebas del backend | **1588** OK (T005, rama `feat/121-denomination-breakdown` sin cambios, 2026-10-15) | **1661** OK (= 1588 + **73** nuevas: 16 migración · 15 catálogo · 31 cierre · 11 reporte) |
| Archivos con fallos preexistentes del frontend | **7 archivos / 11 tests** (1873 pasan, 1 omitido, 1885 en total): `app.spec.ts`, `auth.service.spec.ts`, `menu.service.spec.ts`, `tenant.service.spec.ts`, `pos-checkout-panel.component.spec.ts`, `pos-order-panel.component.spec.ts`, `pos-terminal.store.spec.ts` (T006; árbol limpio, el `stash` no tuvo nada que guardar) | **El mismo conjunto de 7 archivos / 11 tests**; 1908 pasan, 1 omitido, 1920 en total (+35 pruebas nuevas). La primera corrida completa mostró 3 archivos extra (`tenant-sidebar`, `promotions-page`, `public-menu`) que **pasan solos** (130/130) y no se repitieron en la segunda corrida: fallos intermitentes de la suite completa, no de esta spec |
| Huella `md5` de `cash_shifts` (`heladeria`, 12 turnos) | `a201b52b0bcb0acfed4f816a07951ee4` (12 turnos; `skeilo` y `tenantlocal` sin turnos) — idéntica a la referencia (T007) | **`a201b52b0bcb0acfed4f816a07951ee4`** (12 turnos) — **idéntica** tras subir, bajar, volver a subir, y tras todas las verificaciones (T020, T062, T073) |
| `fuera_de_catalogo` por esquema (compuerta FR-028) | `heladeria` 35 filas / 0 en cero / **0** fuera; `skeilo` y `tenantlocal` vacíos (T008). Respaldo `pg_dump --table` de `heladeria.cash_count_denominations` (35 filas) en `/tmp/claude-1000/-home-leonardo-gomez-Documentos-skeilo-pos-specs/119977ab-7135-4b3a-b8b6-1cb6654e54e7/scratchpad/backup_heladeria_cash_count_denominations.sql` | — |
| Filas descartadas con cantidad 0 por la migración | — | **0** en dev (las 35 filas de `heladeria` tenían cantidad > 0) |


## Registro de verificaciones (ejecución del 2026-10-15)

Entorno: PostgreSQL de desarrollo (contenedor `pos`), API **nativa** con `uvicorn`, `ng serve` y Chrome
(DevTools). Los datos de prueba se crearon en `tenantlocal` con prefijo `v121-` y se borraron al terminar
(0 usuarios, cajas, turnos ni líneas residuales; la huella de `heladeria` no cambió).

**T020 · Migración en PostgreSQL real.** `alembic upgrade head` → catálogo = 11 (6 `billete` / 5 `moneda`) en
`heladeria`, `skeilo` y `tenantlocal`; `kind` `NOT NULL`; 0 filas con cantidad 0 y 0 sin tipo ni con tipo
incorrecto (35 líneas); `closed_by_*` existen y están en `NULL`; restricciones con los mismos nombres que el
modelo (`ck__cash_count_denominations__ck_cash_count_kind`, `…_quantity_positive` = `quantity > 0`). Huella
`md5` idéntica. `downgrade -1` → desaparecen tabla y columnas, `quantity >= 0` restaurado, **35 líneas con
las mismas cantidades (56) y el mismo valor ($1.720.000)**, huella idéntica. `upgrade head` otra vez →
mismo resultado. Compuerta FR-028 (`BEGIN … ROLLBACK` sobre `tenantlocal`, línea con `denomination = 3000`):
**aborta** con «…el esquema 'tenantlocal' tiene líneas de desglose con denominaciones fuera del catálogo:
$3.000…»; conteos 0/0/0 antes y después.

**T021 · Tenant nuevo.** `tenant_create(...)` sobre un tenant desechable → `denomination_catalog` = 11 (6/5)
**sin ninguna acción manual**, `kind` `NOT NULL` y los tres CHECK con los mismos nombres que deja la migración.
Limpieza hecha (`shared.users`, `shared.tenants`, `DROP SCHEMA`).

**T037 · API real, casos 1–13 (quickstart §3) + catálogo.** 44/44 comprobaciones OK (script desechable). Caso 1:
200, `counted_amount = 115000.00`, 3 filas `billete`, `closed_by_user_name = Luis` ≠ `user_name = Ana`; 2: contado
110000, diferencia −5000; 3: 422 «El arqueo no cuadra», turno `open`, 0 filas; 4: línea en cero no se guarda;
5: lista vacía + nota → contado 0.00, 0 filas; 6/6b/6c: `counted_amount`, `total` y `subtotal` de línea → 422
«Recarga la página» con `detail` en **cadena**; 7: `$3.000`; 8: −1 y 2.5 → 422; 9: «repetida»; 10: 9 válidas + 1
inválida → 0 filas; 11: «excede el monto máximo», nunca 500; 12: pedido activo → 409 con `active_orders`
(spec 119 intacta), y con total del cliente + pedido activo → 422 (el rechazo va primero); 13: reenvío → 409 con
estado idéntico. `counted_amount: null` no se rechaza. Catálogo: 200 con 11 elementos de mayor a menor para
ADMIN y CASHIER, **403 para MESERO**, sin sesión 401/403, `POST/PUT/PATCH/DELETE` → 404/405. Tras cada
rechazo: turno `open`, sin monto ni observación y sin filas.

**T068 · Concurrencia (FR-019, SC-006).** 20 repeticiones de dos cierres simultáneos (hilos con barrera) sobre
turnos nuevos: **20/20 exactamente un `200` y un `409`**, 0 respuestas `500`, 3 filas por turno, turno `closed`;
el log de `uvicorn` sin `Traceback`.

**T051 · Pantalla del arqueo (`ng serve`).** El modal muestra **11 filas con su tipo** (6 Billete / 5 Moneda), de
mayor a menor, «Total contado (estimado)» y «Diferencia (estimado)» y el texto que aclara que el servidor
calcula los oficiales; con todo en 0 «Confirmar» está deshabilitado; al teclear 100.000 + 10.000 la estimación
pasa a $110.000 y −$5.000 «Faltante» y la observación cambia de «opcional» a «requerida por diferencia»; **la
observación está siempre visible**. Con el navegador **sin red** al abrir el modal: mensaje de error +
«Reintentar», sin filas, «Confirmar» deshabilitado y **0 peticiones `/close`**; al restablecer la red y
pulsar «Reintentar» cargó las 11 filas (6/5). La petición `…/close` lleva **solo** `denominations` y `close_note`
(sin `counted_amount`). 422 de observación (el esperado del servidor cambió con un ingreso de $1.000): el modal
**sigue abierto**, conserva las cantidades, muestra «El arqueo no cuadra…» y permite escribir la observación.
422 de denominación (se quitó $5.000 del catálogo con el modal abierto): «La denominación $5.000 no está
registrada para este negocio.», modal abierto y cantidades conservadas; se restituyó la fila (catálogo 11 = 6/5) y el
mismo conteo cerró bien. Sin errores de consola (los 404 son `GET /cash/shifts/current` de una caja sin turno,
comportamiento existente).

**T060 · Reporte (API + pantalla).** API: el reporte trae `kind`/`quantity`/`subtotal`, Σ subtotales = `counted_amount`;
turno abierto por «Verif Admin» y cerrado por «Luis Cajero» → `closed_by_user_name = Luis Cajero` y
`user_name = Verif Admin`; **renombrar a Luis en `shared.users` no cambia el reporte**. Pantalla (turno con faltante
−$5.000): «Desglose del conteo» entre «Arqueo de caja» y «Movimientos», «Contado por: Luis Cajero», tabla con tipo y
fila «Total» $110.000 = «Efectivo contado», diferencia −$5.000 «Faltante» resaltada. *(La pantalla se verificó con 2 y 11
líneas; el caso de 3 líneas se verificó por API y por pruebas unitarias.)*

**T062 · Históricos reales de `heladeria` (solo lectura).** 12 turnos cerrados: los **2 sin desglose** devuelven
`denominations: []` y `closed_by_*: null`; los **10 con desglose** devuelven todas sus líneas con `kind` y la suma de
subtotales **= efectivo contado en los 10**; huella `md5` idéntica (0 diferencias en contado, observación y estado).

**T063 · Histórico en pantalla (administrador).** Turno histórico **sin desglose** (simulado en `tenantlocal`):
«No se registró desglose para este turno», efectivo contado y diferencia visibles, **sin «Contado por»**, sin
tabla y sin `undefined`/`null`. Turno histórico **con líneas**: tabla con tipo («Billete») y Total $110.000 = contado.
Sin errores de consola.

**T069 · Impresión y diseño.** Cierre real con las **11 denominaciones** ($188.850): 11 filas (6 Billete / 5 Moneda), «Total»
= «Efectivo contado» $188.850. La hoja de estilos entregada incluye, dentro de `@media print`, `tr { break-inside: avoid }`
y `thead { display: table-header-group }`. A 390 px de ancho, tema claro: la tabla no desborda (24–366 px dentro de 390)
ni hay desplazamiento horizontal de la página; tema oscuro revisado en el recorrido de T051/T060. **Limitación:** el
navegador de pruebas es *headless* y **no se abrió la vista previa de impresión real**; falta confirmar a mano que
ninguna fila se corta entre páginas (SC-005).

**T072 · Regresión.** (1) Backend completo: **1661 OK** (línea base 1588 + 73 nuevas). (2) `ng test` del módulo
`cash-register`: 73/73; suite completa: el **mismo** conjunto de 7 archivos preexistentes, ninguno nuevo (ver tabla).
(4) Bloqueo por pedidos activos (caso 12) y `/cash/shifts/{id}/sales-report`/reportes de la spec 119 siguen igual
(sus suites —adaptadas solo en la llamada de cierre— pasan: 53/53 en las cuatro). (5) `grep "CONGELA comportamiento
actual"` en `test_cash_*.py`: **0 coincidencias**; ningún test protegido afectado. **(3) NO se pudo cumplir:**
`app/scripts/e2e_qr_flow.py` **ya estaba roto antes de esta spec** y no es solo su *seed*: (a) el *seed* inserta un
`ProductVariant` sin `presentation_id`, `NOT NULL` desde la spec 083 (`NotNullViolation`); hay un usuario
`e2e-04dfc817@e2e-pos.com` del 2026-10-12 con el mismo fallo y el `seed` ya dejaba `invoice_prefix = 'E2E'` en el tenant
`heladeria`. (b) Se probó un arreglo mínimo del seed (reutilizar una `Presentation`): el script avanzó hasta el carrito y
falló en `POST /cart/submit → 422 «body Field required»`, porque desde la spec 025 ese endpoint crea el pedido
**junto con su intento de pago** y el e2e describe el flujo anterior (envío sin pago → `recibida` → confirmar). Repararlo
exige **reescribir el recorrido**, no parchearlo: queda como trabajo aparte (Principio V) y el parche del seed se
**revirtió**; el script conserva solo el cambio de T030. El paso de cierre se comprobó con el script de T037 (44/44).
Las corridas no dejaron basura nueva: el usuario de la 1.ª corrida se borró y la 2.ª limpió su propio fixture; el usuario
del 2026-10-12 y el prefijo `E2E` **no se tocaron**.

**T073 · Criterios de salida (quickstart).**

| Criterio | Evidencia |
|----------|-----------|
| SC-001 suma de subtotales = contado y n.º de líneas = denominaciones con cantidad > 0 | T031/T037 (casos 1, 2, 4), `TestCierreConDesglose`, reporte T060/T062 (10/10 históricos coinciden) |
| SC-002 todo conteo inválido se rechaza sin cerrar ni guardar | `TestRechazosDelCierre` (16 pruebas) y T037 casos 6–11: turno `open` y 0 filas tras cada 422 |
| SC-003 «cuántos billetes de una denominación» en < 30 s | Cumplido **cualitativamente** (histórico → «Ver reporte» → tabla con cantidad por denominación, sin cálculo a mano); **no se cronometró** |
| SC-004 históricos intactos | T020 + T062 + T063: 12/12 abren sin error, huella `md5` idéntica, con/sin desglose correctos |
| SC-005 impresión sin filas cortadas | **Parcial**: reglas `@media print` presentes, 11 filas sin desbordar; **falta la vista previa de impresión real** (manual) |
| SC-006 reintentos/simultáneos no alteran el desglose | T068 (20/20), `TestInmutabilidadYConcurrencia`, T037 caso 13 |
| SC-007 estimado = oficial; si el esperado cambia prevalece el servidor sin salir del modal | T051: estimado $110.000 = oficial $110.000; con el esperado cambiado (+$1.000) el 422 deja el modal abierto con las cantidades |
| SC-008 «Contado por» por nombre; omitido en históricos | T037/T060 (API y pantalla), T063 (histórico sin la línea ni errores) |

## Resumen

| Fase | Tareas | Rango | En paralelo `[P]` |
|------|--------|-------|-------------------|
| 1 · Setup | 8 | T001–T008 | 2 |
| 2 · Foundational (datos) | 13 | T009–T021 | 5 |
| 3 · US1 (P1) 🎯 | 10 | T022–T031 | 4 |
| 4 · US2 (P1) | 6 | T032–T037 | 0 |
| 5 · US3 (P1) | 14 | T038–T051 | 3 |
| 6 · US4 (P2) | 9 | T052–T060 | 1 |
| 7 · US5 (P2) | 3 | T061–T063 | 0 |
| 8 · US6 (P2) | 6 | T064–T069 | 1 |
| 9 · Polish | 6 | T070–T075 | 3 |
| **Total** | **75** | | **19** |

**Alcance sugerido del MVP**: Fases 1–2 + US1 + US2 + US3 (T001–T051). Las tres son P1 y se despliegan juntas.
