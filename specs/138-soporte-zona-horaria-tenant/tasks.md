---

description: "Lista de tareas de la spec 138 — soporte de zonas horarias por tenant sin desfases"
---

# Tasks: Soporte de zonas horarias por tenant sin desfases

**Input**: Documentos de diseño en `/specs/138-soporte-zona-horaria-tenant/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md),
[contracts/](./contracts/), [quickstart.md](./quickstart.md) (todos presentes). [hallazgos.md](./hallazgos.md) es solo evidencia:
el inventario definitivo está en `research.md` §R0 y en los contratos.

**Tests**: **Incluidos.** La spec los exige (US6, FR-003, FR-012), la constitución los exige (Principio X) y el plan
fija ocho archivos de pruebas nuevos y dos corregidos. Donde el defecto es reproducible, la prueba se escribe **primero** y
debe verse **fallar** antes de la corrección (plan, «Incrementos de entrega»).

**Organization**: Tareas agrupadas por historia de usuario. El orden de las fases **no** es el numérico de las historias,
sino el de dependencia técnica del plan (I1 → I7); ver «Dependencies & Execution Order».

## Format: `[ID] [P?] [Story] Description`

- **[P]**: se puede ejecutar en paralelo (archivos distintos y sin dependencia de una tarea incompleta)
- **[Story]**: US1…US6 (ver spec.md). Setup, Foundational y Polish no llevan etiqueta de historia
- Cada tarea nombra el archivo exacto. Los números de línea son de `develop` el 2026-10-25 y **se desplazan**: relocalizar
  con `grep` antes de editar

## Rutas y convenciones

Repositorios hermanos de este (`pos-specs`). Las rutas de las tareas son relativas a la raíz de cada repositorio:

- `pos-backend/…` → `/home/leonardo-gomez/Documentos/skeilo/pos-backend/` (Python; pruebas con `env/bin/python -m unittest`)
- `pos-heladeria/…` → `/home/leonardo-gomez/Documentos/skeilo/pos-heladeria/` (Angular; pruebas con `npx ng test --watch=false`)
- `pos-specs/…` → este repositorio (solo documentos)

**Reglas que valen para TODAS las tareas** (constitución v4.0.0):

- **Principio III**: ninguna prueba con prefijo `"CONGELA comportamiento actual:"` se modifica. Si una falla, **detenerse y
  consultar**; no ajustar la prueba. Los tres archivos de correo (`test_correo_contrasena_cambiada.py`,
  `test_correo_texto_plano.py`, `test_plantillas_correo_escape.py`) quedan **sin tocar**.
- **Principio V**: nada de refactorizaciones oportunistas; solo lo que pide una tarea.
- **Principio XIII**: nombres de pruebas, comentarios y documentos en español de Colombia.
- **Principio XV**: **no commitear** hasta que el usuario lo pida; cuando lo pida, commits pequeños, en inglés, Conventional
  Commits, sin marcas de IA. (Esto reemplaza la nota genérica «commit after each task» de la plantilla.)
- **A-147 y A-148 en commits propios** (se implementan antes de la ratificación del negocio, T099): los cambios que alteran lo
  que ve Bogotá viajan separados del resto para poder revertirlos si el negocio no los ratifica. A-147 = T031, T032, T033
  (+ sus pruebas T029, T030); A-148 = T046–T050 (+ T054). Mensaje `fix:` en inglés que cite la anomalía. Si el negocio no los
  ratifica, se revierte el commit propio y se abre una spec aparte; no se revierte en silencio.
- **Nunca** correr a la vez la suite completa del backend y la del frontend (la contención de CPU produce falsos fallos).
- La suite del frontend arrastra fallos preexistentes ajenos (7 archivos): comparar **por nombre de prueba** contra la línea
  base de T003, nunca por conteo.

---

## Phase 1: Setup

**Purpose**: ramas, línea base medida y registro de la decisión antes de tocar código.

- [X] T001 Crear la rama `fix/138-tenant-timezone-support` **desde `develop`** en `pos-backend` y en `pos-heladeria`
  (Principio XIV), antes de editar cualquier archivo de código. Confirmar con `git branch --show-current` en ambos.
  `pos-specs` se trabaja en `main` (solo documentos).
- [X] T002 Línea base del backend: en `pos-backend`, `env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`
  (≈110 s, 1905 pruebas) y `env/bin/python -m app.scripts.test_promotions_rules`. Guardar la **lista de nombres de pruebas
  fallidas** en un archivo temporal fuera del repo. Esperado: 1 fallo
  (`test_payment_attempt_reject … test_segundo_rechazo_del_dia_en_la_misma_mesa_escribe_marca_de_revision`) si se corre entre
  las 19:00 y las 24:00 de Bogotá; 0 fallos fuera de ese rango.
  > **Hecho 2026-10-26 (con desviación).** Línea base sobre `develop`: **1918 pruebas**. La primera corrida dio 1 fallo + **270 errores** `no such table: main.unit_measure_groups`: defecto **preexistente de `develop`** (las specs 137-rediseño/140 hicieron obligatoria la FK `unit_measures.group_id` y cinco listas de tablas SQLite de fixtures no incluyen `unit_measure_groups`; el remoto tampoco lo había corregido). Ajeno a esta spec, pero enmascaraba precisamente las pruebas de órdenes/checkout. Se añadió `"unit_measure_groups"` a las listas de `orders_fixtures.py`, `cart_fixtures.py`, `product_availability_fixtures.py`, `table_sessions_fixtures.py` y `test_plan_gating_inventory_fields.py` (ninguna con `CONGELA`; cambio aislado, `test:`, sin commit). Línea base **reparada**: 1918 pruebas, **1 fallo** (`test_segundo_rechazo…`, por la hora del día: son más de las 19:00 en Bogotá), `test_promotions_rules` OK. Lista guardada en el scratchpad de la sesión.
- [X] T003 Línea base del frontend (**después** de T002 terminar, nunca en paralelo): en `pos-heladeria`,
  `npx ng test --watch=false`. Guardar la **lista de nombres de pruebas fallidas** (fallos preexistentes en `app.spec`,
  `auth.service.spec`, `menu.service.spec`, `tenant.service.spec`, `pos-checkout-panel`, `pos-order-panel`,
  `pos-terminal.store`) para comparar por nombre al final. Además, con `tenantlocal` en `America/Bogota`, tomar las **capturas de
  referencia** de T101 (ticket en vista previa, reloj/fecha/turno de la terminal, gráfica por hora, notificaciones, plan y
  «Vence» de Super Admin) sobre `develop`, **antes** de cambiar nada.
  > **Hecho 2026-10-26 (parcial).** Línea base del frontend sobre `develop`: 2329 pruebas OK / **14 fallan en 8 archivos** (`app.spec` ×2, `auth.service` ×1, `menu.service` ×1, `tenant.service` ×3, `pos-checkout-panel` ×1, `pos-order-panel` ×2, `manual-order-page` ×3, `pos-terminal.store` ×1), todas preexistentes. Nota: `manual-order-page.component.spec` no estaba en la lista de 7 archivos de la planificación. **Pendiente:** las capturas de referencia de T101; se tomarán desde un `git worktree` de `develop` si se ejecuta T101 (el código de `develop` no cambia).
- [X] T004 [P] Confirmar el entorno de desarrollo: `docker ps` muestra el contenedor `pos`; `cd pos-backend && env/bin/alembic heads`
  devuelve `c3d9a1f08b42 (head)` (de él colgará la migración de T081); `env/bin/alembic current` está en head. `pos-api` en Docker
  entra en bucle de reinicio por diseño de desarrollo (hosts del `.env` en `localhost`): para probar HTTP real usar `uvicorn`
  nativo, no el contenedor.
  > **Hecho 2026-10-26 (con desviación).** Contenedor `pos` arriba; `pos-api` en reinicio (esperado). **La cabeza de Alembic ya NO es `c3d9a1f08b42`: es `c5815ab62693`** (`138_supplier_items_presentation_factor`; `develop` avanzó con las specs 137-rediseño, 139 y 140). `alembic current` = head. **La migración de T081 debe colgar de `c5815ab62693`.**
- [X] T005 [P] Completar **A-148** en `pos-specs/specs/000-reconocimiento/registro-de-anomalias.md` **antes de implementar**
  (Principios II y XI): el inventario definitivo es de **16 esquemas / 24 campos** ([contracts/instantes-api.md](./contracts/instantes-api.md) §1).
  Agregar los que la entrada actual omite: `PaymentMethodCatalogResponse` y `PlanResponse` (`created_at`, `updated_at`),
  `PromotionResponse.closed_by_refactor_at`, `ParticipantResponse.expires_at` (esquema de `table_sessions`); y reemplazar la
  nota «la planificación debe buscar compensaciones manuales» por el resultado ya medido (R0.4 de research.md: no existe
  ninguna en el frontend). No cambiar el estado «pendiente de ratificación».
  > Hecho 2026-10-26. Las entradas A-147/A-148/A-149 estaban solo en un `git stash` (alguien lo creó en esta máquina al hacer `pull` durante la sesión); se restauraron con `git stash apply` (la entrada del stash sigue ahí: puede descartarse con `git stash drop` una vez commiteado el registro). A-148 completada con el inventario medido hoy, que **ya es mayor** que el de la planificación (27 campos / 15 definiciones; ver T046).
---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: funciones nuevas del módulo central de zona horaria de cada lado y utilidades de prueba que usan **varias**
historias. Son aditivas y no cambian ningún comportamiento por sí solas. Todas las ediciones de
`pos-backend/app/core/timezone.py` van aquí (un solo archivo → un solo lugar) para que ninguna historia pelee por él.

**⚠️ CRITICAL**: US1–US6 consumen estas funciones. Hay dos cadenas independientes que pueden avanzar en paralelo:
backend (T006–T013) y frontend (T014–T017).

### Backend — `app/core/timezone.py` y utilidades de prueba

- [X] T006 [P] Escribir `pos-backend/app/characterization_tests/test_zonas_curadas.py` (debe **fallar** hasta T012/T013):
  (a) `ZONAS_CURADAS` es exactamente el literal de [data-model.md §3](./data-model.md) — las siete zonas `America/Bogota`,
  `America/Mexico_City`, `America/Lima`, `America/Santiago`, `America/Argentina/Buenos_Aires`, `Europe/Madrid`, `Asia/Tokyo` con
  su nombre de selector y su etiqueta de correo; el mismo literal lo repite la prueba de paridad del frontend (T076);
  (b) toda IANA de la lista se resuelve con `ZoneInfo`; (c) `etiqueta_zona_correo`: Bogotá → `Colombia`, México →
  `Ciudad de México`, Lima, Santiago, Buenos Aires, Madrid, Tokio; zona válida fuera de la lista en fecha fija
  (`America/Sao_Paulo` → `UTC−3`, `Asia/Kolkata` → `UTC+5:30`, `UTC` → `UTC`); signo menos tipográfico `−` (U+2212), minutos
  solo si no son cero; el desfase se calcula **para el instante dado** (una zona con horario de verano da `UTC+1` o `UTC+2`
  según la fecha).
- [X] T007 [P] Escribir `pos-backend/app/characterization_tests/test_tenant_timezone_validation.py` (parte 1; debe **fallar**
  hasta T011): tabla de [data-model.md §1](./data-model.md) contra `validate_iana_timezone` — válidos: las siete zonas
  curadas y `UTC`; rechazados con `ValueError`: `Nowhere/Land`, `Bogota`, `america/bogota` (distingue mayúsculas), `UTC+5`,
  `PST`, `''`, `' '`, `../etc/passwd`, `None`, y los archivos de la máquina `localtime`, `Factory`, `posixrules`. La parte 2
  (modelo, esquema, alta, script) la agrega T075 en el **mismo archivo**.
- [X] T008 [P] En `pos-backend/app/characterization_tests/fixtures.py` agregar las constantes de prueba compartidas:
  `ZONAS_DE_PRUEBA = ("America/Bogota", "America/Mexico_City", "Europe/Madrid")` (FR-012: tres zonas de tenant), y un helper
  `tenant_en(zona)` que devuelva `make_tenant_stub(timezone=zona)` (ya existe `make_tenant_stub`; `resolve_timezone` solo lee
  `tenant.timezone`). No modificar ninguna función existente.
- [X] T009 En `pos-backend/app/core/timezone.py` agregar `utc_now_naive() -> datetime`: `datetime.now(timezone.utc)` sin
  `tzinfo`, para columnas `DateTime` sin zona. Docstring con la regla: **columna sin zona ⇒ `utc_now_naive()`; columna
  `DateTime(timezone=True)` ⇒ `utc_now()`** (hoy solo `promotion_evaluated_at`). No cambiar `utc_now()`.
- [X] T010 En `pos-backend/app/core/timezone.py` agregar `business_today(tenant) -> date` (`utc_now().astimezone(resolve_timezone(tenant)).date()`),
  **moviéndola** desde `pos-backend/app/api/v1/cash/reports.py:371`. En `cash/reports.py` reemplazar la definición por
  `from app.core.timezone import business_today` (alias): `cash/router.py:260` y `cash/reports.py:399-404` siguen llamándola
  como `reports.business_today(tenant)` sin tocarlos. Quitar de `cash/reports.py` solo los imports que queden sin uso.
- [X] T011 En `pos-backend/app/core/timezone.py` agregar `validate_iana_timezone(value) -> str`: devuelve el valor o lanza
  `ValueError`. Regla ([data-model.md §1](./data-model.md)): `value` es `str`, está en `zoneinfo.available_timezones()` **y**
  (`== "UTC"` o contiene `/`). Cachear el conjunto de `available_timezones()` (se recorre el disco en cada llamada). Hace pasar T007.
- [X] T012 En `pos-backend/app/core/timezone.py` agregar `ZONAS_CURADAS`: tupla inmutable de siete entradas
  (`NamedTuple` con `iana`, `nombre`, `etiqueta`) con los valores de [data-model.md §3](./data-model.md) (p. ej. `America/Bogota` /
  «Bogotá (Colombia)» / «Colombia»; `Asia/Tokyo` / «Tokio (Japón)» / «Tokio»).
- [X] T013 En `pos-backend/app/core/timezone.py` agregar `etiqueta_zona_correo(zona: str, instante: datetime) -> str`: la
  `etiqueta` de la lista curada («Colombia», «Ciudad de México»…) o, si la zona es válida pero no está en la lista, el desfase
  **vigente en `instante`** con el formato de T006 (`UTC−3`, `UTC+5:30`, `UTC` si es cero). Hace pasar T006.
  (Quien la usa decide el texto envolvente: ver T052.)

### Frontend — módulo único de presentación

- [X] T014 [P] Crear `pos-heladeria/src/app/shared/date-format.util.spec.ts` (no existe; debe **fallar** hasta T015):
  `FALLBACK_TIMEZONE === 'America/Bogota'`; `zonedParts('2026-10-26T00:30:00+00:00', tz)` devuelve `ymd`/`hhmm` `2026-10-25`/`19:30`
  en Bogotá, `2026-10-25`/`18:30` en `America/Mexico_City` y `2026-10-26`/`01:30` en `Europe/Madrid`; `weekday` con 0 = lunes
  … 6 = domingo (igual que el backend); `null` ante un valor que no es fecha; `formatInZone` formatea en la zona pedida
  **aunque la del sistema sea otra**; `businessToday` (ya existe) sigue devolviendo `YYYY-MM-DD`.
- [X] T015 En `pos-heladeria/src/app/shared/date-format.util.ts` agregar, según [contracts/frontend-fechas.md §1](./contracts/frontend-fechas.md):
  `export const FALLBACK_TIMEZONE = 'America/Bogota'` (la **única** del frontend), `interface ZonedParts`,
  `zonedParts(instant, timezone): ZonedParts | null` y `formatInZone(instant, timezone, options, locale = 'es-CO')` — ambas
  con `Intl.DateTimeFormat({ timeZone })`, sin dependencias nuevas (Principio IX). `businessToday` no cambia.
- [X] T016 En `pos-heladeria/src/app/core/tenant/tenant-info.service.ts` agregar
  `readonly timezone = computed(() => this.info()?.timezone ?? FALLBACK_TIMEZONE)`; extender
  `tenant-info.service.spec.ts` con: con `info()` cargado devuelve la zona del tenant; sin cargar, el respaldo.
- [X] T017 En `pos-heladeria/src/app/shared/pipes/tenant-date.pipe.ts` agregar el tercer parámetro
  `transform(value, format = 'medium', timezone?: string)` con precedencia **zona explícita > `tenantInfo.timezone()` >
  `FALLBACK_TIMEZONE`**; eliminar el `DEFAULT_TIMEZONE` privado (importar `FALLBACK_TIMEZONE`). Se conserva `ianaOffset` (corrige
  que `formatDate` de Angular ignora los nombres IANA). Extender `tenant-date.pipe.spec.ts` con: zona explícita Tokio,
  México y Madrid sobre un mismo instante; sin zona usa la del tenant; el resultado no cambia con `TZ=Asia/Tokyo`.

### Verificación de la fase

- [X] T018 Ejecutar solo lo nuevo: backend `env/bin/python -m unittest app.characterization_tests.test_zonas_curadas app.characterization_tests.test_tenant_timezone_validation -v`
  y frontend `npx ng test --watch=false --include='**/date-format.util.spec.ts' --include='**/tenant-date.pipe.spec.ts' --include='**/tenant-info.service.spec.ts'`
  (uno después del otro). Esperado: todo en verde. Confirmar con `git diff` que ningún archivo `CONGELA` cambió.

**Checkpoint**: funciones centrales listas — las historias pueden empezar. US2, US3 y US4 son solo backend y dependen
únicamente de T009–T013; US1 y US5 también de la cadena frontend.
  > Hecho 2026-10-26. Backend: 12 pruebas nuevas OK (zonas curadas + validación). Frontend: 46 pruebas OK con la zona del sistema, `TZ=Asia/Tokyo` y `TZ=UTC`. Ningún archivo `CONGELA` modificado. Nota para T075: `test_tenant_timezone` falla ejecutado solo (el mapper de `Tenant` necesita que `app.models` registre `Plan`; preexistente, pasa en la suite completa): el archivo de validación debe importar `app.models` cuando instancie `Tenant`.
---

## Phase 3: User Story 4 — Lo guardado no depende de la configuración de la base de datos (Priority: P1) 🎯 MVP · plan I1

**Goal**: toda conexión a PostgreSQL trabaja en UTC y todo instante se escribe de **una sola forma**, de modo que cambiar la
zona de la sesión del motor no corrompa nada (FR-004, FR-005).

**Independent Test**: [quickstart Q2](./quickstart.md) — `PGTZ=America/Bogota … verify_timezone_storage` guarda `17:00 UTC` como
`17:00`, y la guarda `ast` no encuentra ninguna escritura fuera de `utc_now_naive()`.

> Es el primer incremento aunque la historia sea la 4: es la base sobre la que las demás son correctas, y cambia cero
> comportamiento (producción ya corre en UTC — compuerta 0, T100).

### Tests for User Story 4 (escribir primero, deben fallar)

- [X] T019 [P] [US4] Crear `pos-backend/app/characterization_tests/test_session_utc.py`: `force_utc_session` (T021) con una
  conexión DBAPI simulada ejecuta `SET TIME ZONE 'UTC'`, deja `autocommit` como estaba y cierra el cursor; el listener **solo**
  se registra si `engine.dialect.name == "postgresql"` (las suites usan SQLite y no deben ejecutarlo). Debe fallar mientras
  `force_utc_session` no exista.
- [X] T020 [P] [US4] Crear `pos-backend/app/characterization_tests/test_instantes_forma_unica.py` — guarda con `ast` (FR-005).
  Recorre `pos-backend/app/**/*.py` **excepto** `characterization_tests/`, `scripts/test_*` y `core/timezone.py`, y falla
  indicando archivo y línea ante: (a) `.replace(tzinfo=None)` cuyo receptor sea `utc_now()` o `datetime.now(<…>.utc)`;
  (b) `datetime.utcnow()`; (c) `datetime.now()` sin argumentos; (d) asignación de un `utc_now()` aware a un atributo
  (`objeto.atributo = utc_now()`). **Límite documentado** (en el docstring de la prueba): no detecta argumentos con nombre ni
  valores que pasan antes por una variable local —p. ej. `last_cost_at=utc_now() if …` en `supplier_items.py:147`, que T023
  corrige a mano—, porque `now=utc_now()` hacia `promotion_evaluation_instant` es un uso aware legítimo y no se distingue sin
  conocer la columna. **Permitidos** (hora de pared local o conversión de instante, no «ahora» en UTC):
  `.astimezone(...).replace(tzinfo=None)`, `datetime.now(tz).replace(tzinfo=None)` con una zona de tenant
  (`scheduler.py:235`, `promotions/service.py:65-67`, `cash/reports.py:507`). Incluye además la prueba unitaria de
  `utc_now_naive()` (sin `tzinfo`, dentro de 1 s de `utc_now()`). Debe fallar mientras queden las ≈38 escrituras a mano.

### Implementation for User Story 4

- [X] T021 [US4] En `pos-backend/app/core/db.py` (justo tras `engine = create_engine(...)`, línea ~39) definir
  `force_utc_session(dbapi_connection, connection_record)` y registrarla con `sqlalchemy.event.listen(engine, "connect", …)`
  **solo si el dialecto es `postgresql`**: pone `autocommit` en verdadero, ejecuta `SET TIME ZONE 'UTC'` en un cursor, y
  restaura el `autocommit` anterior. Debe ser un **evento `connect`**, no `connect_args={"options": "-c timezone=UTC"}`:
  research Decisión 1 midió que `options` pierde contra `PGTZ`. Un solo `engine` cubre API, worker de Celery, scheduler,
  Alembic y scripts. Hace pasar T019.
- [X] T022 [US4] Sustituir `X.replace(tzinfo=None)` por `utc_now_naive()` (importar de `app.core.timezone`; quitar imports
  sin uso) en el **núcleo**: `pos-backend/app/core/db.py:85` (`plan_iniciado_en`, mismo archivo que T021),
  `app/celery_task.py:41`, `app/core/qr_context.py:91,194`, `app/core/notifications/dispatch.py:68`,
  `app/core/notifications/purge.py:25`, `app/core/plan_limits.py:90`, `app/core/scheduler.py:105,190`. **No tocar**
  `scheduler.py:235` (hora de pared local del tenant: permitido por T020).
- [X] T023 [P] [US4] Misma sustitución en `pos-backend/app/api/v1/`: `inventory/service.py:50`, `inventory/import_.py:279`,
  `inventory/router.py:209`, `plan/service.py:24`, `auth/routes.py:113,152,284,365,395`. Y en `inventory/supplier_items.py:136,147,219,359`
  cambiar `last_cost_at = utc_now()` (aware sobre columna sin zona) por `utc_now_naive()`.
- [X] T024 [P] [US4] Misma sustitución en: `pos-backend/app/api/v1/invitations/router.py:247,274`,
  `notifications/router.py:88,152`, `products/service.py:176`, `super_admin/router.py:113`; y `cart/service.py:94`
  (helper privado `_now`: hacer que delegue en `utc_now_naive()` o eliminarlo y llamar al central, **sin** cambiar su uso en
  `test_cart_service.py`, que lo congela vía `cart_fixtures.frozen_now`). Y `cash/router.py:186`:
  `shift.closed_at = utc_now()` → `utc_now_naive()`.
- [X] T025 [P] [US4] En `pos-backend/app/api/v1/orders/checkout.py`: `:1053,1084` (`datetime.now(timezone.utc).replace(tzinfo=None)`)
  y los aware sobre columnas sin zona `resolved_at` (`:984,1269,1402,1781`) y `cash_confirmed_at` (`:1627`) → `utc_now_naive()`.
  En `pos-backend/app/models/order_payment_attempt.py:107` el `default=lambda: datetime.now(timezone.utc).replace(tzinfo=None)`
  pasa a `default=utc_now_naive`. **No tocar** los usos de `utc_now()`/`datetime.now(timezone.utc)` que alimentan
  `promotion_evaluation_instant` ni los de columnas con zona (`promotion_evaluated_at`): son instantes aware por diseño.
- [X] T026 [US4] Crear `pos-backend/app/scripts/verify_timezone_storage.py` (mismo estilo que
  `verify_tracks_inventory_backfill.py`; **solo lectura** + una tabla `TEMP`), según research Decisión 14 y
  [quickstart Q2](./quickstart.md). Imprime primero, **informativo**, la zona de una conexión **sin forzar** (con
  `PGTZ=America/Bogota` muestra `America/Bogota` y el defecto original `17:00 UTC → 12:00`) y `pg_settings.TimeZone` con su
  `source` más `pg_db_role_setting`; luego, con la **conexión de la aplicación**: (1) la zona de sesión es `UTC`;
  (2) un `datetime` aware de `2026-10-25 17:00 UTC` se guarda como `17:00`; (3) `now()` ≈ hora UTC real; (4) la zona de cada
  tenant pasa `validate_iana_timezone` **y** está en `pg_timezone_names` (incluidas las siete curadas); (5) informa si existe el
  disparador `trg_tenants_validate_timezone` (informativo, no falla). Código de salida distinto de cero ante cualquier fallo
  de (1)–(4); última línea `OK` si todo pasa.
- [X] T027 [US4] Verificación: `env/bin/python -m unittest app.characterization_tests.test_session_utc app.characterization_tests.test_instantes_forma_unica -v`
  en verde; ejecutar [quickstart Q2](./quickstart.md) con `PGTZ=America/Bogota`, `PGTZ=Asia/Tokyo` y sin `PGTZ` (las tres
  terminan en `OK`); y la suite completa del backend sin fallos nuevos respecto de T002.

**Checkpoint**: US4 completa — el almacenamiento es UTC con una sola forma de escribir, probado contra PostgreSQL real.
  > Hecho 2026-10-26. Q2 con `PGTZ=America/Bogota`, `PGTZ=Asia/Tokyo` y sin `PGTZ`: las tres terminan en `OK` (sin forzar, 17:00 UTC se guardaría como 12:00 / 02:00 / 17:00; con la conexión de la app siempre 17:00). Suite completa: 1951 pruebas (33 nuevas), solo el fallo preexistente de la hora del día (`segundo_rechazo`, lo arregla T031); 0 fallos nuevos. Desviaciones: (1) la guarda `ast` encontró **38** escrituras reales (40 líneas con las dos de `checkout` aware) y todas se sustituyeron; el helper `install_force_utc_session(engine)` se agregó para poder probar el registro condicional; (2) `cart/service.py::_now` delega en `utc_now_naive()` y el fixture `cart_fixtures.frozen_now` ahora fija **también** `app.core.timezone.datetime` (si no, `test_cart_service` dejaba de estar congelado); ninguna prueba modificada; (3) `import app.main` con el `.env` real abre la BD de desarrollo y corre `alembic upgrade head` — cuidado cuando exista la migración de T081.
---

## Phase 4: User Story 3 — El día de negocio es el día local (Priority: P1) · plan I2 (parte 1)

**Goal**: «hoy», «segundo rechazo del día» y el día del nombre del archivo de inventario usan siempre la fecha **local**
del tenant, nunca la UTC (FR-007, FR-009). Es la excepción **A-147** a FR-013.

**Independent Test**: [quickstart Q6](./quickstart.md) — dos rechazos de la misma mesa a las 20:00 y 21:00 de Bogotá dejan la
marca; en Madrid entre 00:00 y 02:00 locales «hoy» es el día local.

### Tests for User Story 3 (escribir primero, deben fallar donde indica)

- [X] T028 [P] [US3] Crear `pos-backend/app/characterization_tests/test_business_day_boundaries.py`, parametrizado con
  `ZONAS_DE_PRUEBA` (T008) y los valores **medidos** de [data-model.md «Día de negocio»](./data-model.md): `local_day_bounds_utc`
  Madrid 25/10/2026 = `[24/10 22:00Z, 25/10 23:00Z)` (25 h), Madrid 24/10 = 24 h, Madrid 29/03/2026 = `[28/03 23:00Z, 29/03 22:00Z)`
  (23 h), **Santiago 06/09/2026 = `[06/09 04:00Z, 07/09 03:00Z)` (medianoche inexistente)**, Ciudad de México 24 h todo el año,
  Bogotá 25/10/2026 = `[25/10 05:00Z, 26/10 05:00Z)`, Tokio `[24/10 15:00Z, 25/10 15:00Z)`. `business_today(tenant)` con el reloj
  congelado (`cart_fixtures.frozen_now(instante, module="app.core.timezone")`): `2026-10-26 00:30Z` → Bogotá 25/10, México
  25/10, Madrid 26/10; Madrid `2026-11-24 23:30Z` (00:30 local) → 25/11 aunque el día UTC sea el 24; Tokio `2026-10-24 16:00Z`
  (01:00 local) → 25/10. Caso del **turno que cruza la medianoche local** (US3-3, sin cambio): agregar aquí la prueba de que
  las ventas de un turno abierto a las 23:30 y cobradas a las 00:30 locales se atribuyen al día de apertura (`test_cash_timezone.py`
  no tiene ninguna: una búsqueda de «medianoche», «cruza», «23:30» y «00:30» no halló coincidencias).
- [X] T029 [P] [US3] En `pos-backend/app/characterization_tests/test_payment_attempt_reject.py` **agregar** (no tocar los existentes)
  `test_segundo_rechazo_a_las_20_y_21_de_bogota_escribe_marca` con el reloj congelado en `2026-10-26 01:00Z` (20:00 Bogotá) y
  `2026-10-26 02:00Z` (21:00 Bogotá) — siembra y rechaza ambos intentos con el **mismo** reloj congelado
  (`frozen_now(instante, module="app.core.timezone")`) — y comprueba que queda 1 marca `payment.table_repeat_rejection` con
  `rejection_count_today == 2`. Complementar con el mismo caso a mediodía de Bogotá (control: pasaba antes) y con un tenant de
  Ciudad de México. **Debe fallar antes de T031** (ventana vacía: `utc_now().date()` ya es el 26).
  > Hecho 2026-10-26. Rojo verificado antes de T031 (Bogotá 20:00/21:00, Ciudad de México y Madrid 00:10/00:40 fallaban; los controles pasaban). Se corrigió además el fixture `orders_fixtures.make_payment_attempt`: `created_at` era `datetime.now()` (hora LOCAL de la máquina) y no obedecía al reloj fijado; ahora usa `utc_now_naive()`. Añadidos controles negativos (dos días locales distintos no dejan marca).
- [X] T030 [P] [US3] En `pos-backend/app/characterization_tests/test_inventory_export.py` **agregar** una prueba del nombre del
  archivo: con el reloj congelado en `2026-10-26 01:00Z`, un tenant de Bogotá recibe `filename="inventario_2026-10-25.xlsx"` y
  uno de Madrid `inventario_2026-10-26.xlsx`. Debe fallar antes de T032 (hoy usa `date.today()` del servidor).

### Implementation for User Story 3

- [X] T031 [US3] En `pos-backend/app/api/v1/orders/checkout.py` (~línea 1423, función `reject_payment_attempt`) reemplazar
  `local_day_bounds_utc(utc_now().date(), tz)` por `local_day_bounds_utc(business_today(tenant), tz)`; importar `business_today`
  de `app.core.timezone`. Hace pasar T029. No cambia ninguna otra parte del cálculo.
- [X] T032 [US3] En `pos-backend/app/api/v1/inventory/router.py` (`export_items`, ~línea 90): declarar
  `tenant: Tenant = Depends(get_tenant)` (patrón de `orders/router.py`: `from app.core.db import get_tenant`) y reemplazar
  `date.today().isoformat()` por `business_today(tenant).isoformat()`; quitar el import de `date` si queda sin uso. Hace pasar T030.
- [X] T033 [P] [US3] En `pos-heladeria/src/app/modules/inventory/pages/inventory-page.component.ts` (`exportFilename`, ~línea
  654) el respaldo `new Date().toISOString().slice(0, 10)` pasa a `businessToday(this.tenantInfo.timezone())`; la página aún
  no inyecta `TenantInfoService`: agregar `private readonly tenantInfo = inject(TenantInfoService)`. (El nombre real viene de
  `Content-Disposition` del backend; el respaldo solo corre si falta la cabecera.) Extender
  `inventory-page.component.spec.ts`: sin cabecera, con el reloj en `2026-10-26T01:00:00Z` y tenant de Bogotá el nombre es
  `inventario_2026-10-25.xlsx`, también con `TZ=Asia/Tokyo` y `TZ=UTC`.
- [X] T034 [US3] Verificación ([quickstart Q6](./quickstart.md)): `env/bin/python -m unittest app.characterization_tests.test_payment_attempt_reject app.characterization_tests.test_business_day_boundaries app.characterization_tests.test_inventory_export app.characterization_tests.test_cash_timezone -v`
  en verde. Correrlo **entre las 19:00 y las 24:00 de Bogotá** si es posible (el rango donde la suite fallaba); si no, las
  pruebas con reloj congelado cubren ese rango.

**Checkpoint**: US3 completa — la suite del backend deja de depender de la hora del día.
  > Hecho 2026-10-26, ejecutado a las ~21:30 de Bogotá (dentro del rango 19:00–24:00): `test_payment_attempt_reject`, `test_business_day_boundaries`, `test_inventory_export`, `test_cash_timezone` = 59 pruebas OK; el fallo preexistente `test_segundo_rechazo…` ya pasa. Frontend: `inventory-page.component.spec` 9/9 con la zona del sistema, `TZ=Asia/Tokyo` y `TZ=UTC` (se reemplazó la expectativa del test existente de respaldo, que calculaba el día UTC —el mismo defecto— por una con reloj fijo).
---

## Phase 5: User Story 2 — Las promociones se evalúan en la zona del tenant en todos los caminos de cobro (Priority: P1) · plan I2 (parte 2)

**Goal**: las **ocho** llamadas a `auto_discount` que hoy caen en la zona global reciben el tenant del cobro (FR-006).

**Independent Test**: [quickstart Q5](./quickstart.md) — promoción 18:00–20:00 y cobro a las 17:30 locales de Ciudad de México
no aplica el descuento por ninguno de los caminos; a las 18:30 locales de Bogotá sí aplica.

### Tests for User Story 2 (escribir primero, deben fallar)

- [X] T035 [P] [US2] Crear `pos-backend/app/characterization_tests/test_promotions_tenant_timezone_paths.py`. Promoción activa
  18:00–20:00 contra instantes `2026-10-25 23:30Z` y control `22:30Z`, parametrizado con `ZONAS_DE_PRUEBA` (T008):
  `23:30Z` → Bogotá (18:30) **aplica**, México (17:30) **no**, Madrid (00:30 del 26/10) **no**; `22:30Z` → ninguna aplica;
  control positivo `2026-10-26 00:30Z` → Bogotá (19:30) y México (18:30) aplican, Madrid (01:30) no. Un caso por camino:
  venta directa (`sales.service.checkout`), cobro de mesa unificado y dividido (`table_sessions.service.close_session`) y su
  factura previa (`compute_bill`), mesas fusionadas (`orders.tables_advanced.group_bill`), aprobación de un pago QR
  (`checkout.approve_payment_attempt`), confirmación de efectivo (`confirm_cash_payment_attempt`) y la porción en efectivo de un
  pago mixto (`_confirm_cash_portion_of_mixed_attempt`). Coincidencia vista previa = menú público = cobro para el mismo
  instante y tenant (US2-4). Caso de hora repetida (Madrid 25/10/2026, ventana 02:00–03:00 aplica en las dos pasadas
  `00:30Z` y `01:30Z`; edge case de la spec). Congelar el reloj en el módulo que cada camino use para «ahora»
  (`frozen_now(instante, module=…)`: `app.core.timezone`, `app.api.v1.sales.service`, `app.api.v1.orders.tables_advanced`).
  Reutilizar `orders_fixtures.py`, `table_sessions_fixtures.py` y las fixtures de promociones de `test_promotions_service.py`.
  Debe fallar para México y Madrid antes de T036–T041.

### Implementation for User Story 2

Patrón (research Decisión 4, el mismo que ya usan `reject_payment_attempt` y `evaluate_variant_sets`): parámetro **opcional por
nombre** `tenant: Tenant | None = None`, pasado a `auto_discount(db, lines, instant, tenant)`. Opcional para no romper a los
llamadores de pruebas ni scripts; el respaldo global solo rige si de verdad no hay tenant. **No** se toca `_valid_now` (A-57).

- [X] T036 [P] [US2] En `pos-backend/app/api/v1/orders/checkout.py`: agregar `tenant` a `approve_payment_attempt` (~1212),
  `_confirm_cash_portion_of_mixed_attempt` (~1587) y `confirm_cash_payment_attempt` (~1707, que debe reenviarlo a la
  anterior en ~1751); pasarlo a las llamadas `auto_discount(db, lines, instant)` de ~1305, ~1650 y ~1802.
- [X] T037 [P] [US2] En `pos-backend/app/api/v1/orders/tables_advanced.py`: `group_bill(db, group_id, *, tenant=None)` y pasarlo a
  `auto_discount` (~línea 161).
- [X] T038 [US2] En `pos-backend/app/api/v1/orders/router.py`: los endpoints `group_bill` (~196), `approve_payment_attempt` (~291) y
  `confirm_cash_payment_attempt` (~349) declaran `tenant: Tenant = Depends(get_tenant)` (ya importado en ese archivo) y lo
  pasan a T036/T037. FastAPI resuelve `get_tenant` una vez por petición: no agrega consultas. Ninguna prueba llama a estos tres
  endpoints, ni directo ni por HTTP (verificado el 2026-10-25), así que `= Depends(get_tenant)` es seguro aquí; no así en
  `session_bill` (T041). Depende de T036 y T037.
- [X] T039 [P] [US2] `pos-backend/app/api/v1/sales/service.py`: `checkout(db, data, cashier, *, invoice_prefix="", tenant=None)`
  y pasarlo a `auto_discount` (~373); `pos-backend/app/api/v1/sales/router.py:126` ya tiene `tenant` en alcance: agregar
  `tenant=tenant` a la llamada.
- [X] T040 [P] [US2] `pos-backend/app/api/v1/table_sessions/service.py`: agregar `tenant` a `compute_bill` (~203),
  `close_session` (~309, que lo reenvía), `_close_unified` (~739) y `_close_split` (~786); pasarlo a `auto_discount` en ~235,
  ~758 y ~868. **Además** `set_assignments` (~586) devuelve `compute_bill(db, ts.id)` en ~698: agregarle `tenant` y reenviarlo
  (el plan no lo listaba; sin esto el resumen que devuelve esa operación seguiría evaluando en la zona global).
- [X] T041 [US2] `pos-backend/app/api/v1/table_sessions/router.py`: `set_assignments` (~L97) y `close_session` (~L131) **ya**
  declaran `tenant`; solo hay que pasarlo a `service.set_assignments` / `service.close_session` (T040). `session_bill` (~L118)
  gana `tenant: Annotated[Tenant, Depends(get_tenant)] = None` (importar `Annotated` de `typing`) y lo pasa a
  `service.compute_bill`. **No** usar `= Depends(get_tenant)` aquí: el test protegido
  `test_table_sessions_router.py::test_session_bill_endpoint_delega_en_compute_bill` (CONGELA, ~L211) invoca
  `ts_router.session_bill(...)` directo, sin `tenant`, y recibiría el marcador `Depends` (⇒ `AttributeError` en
  `resolve_timezone`). Con `Annotated` + `None`, FastAPI resuelve la dependencia por HTTP y la llamada directa usa la zona de
  respaldo, que es lo que ese test ya espera (probado el 2026-10-25 con un script aparte). Dejar un comentario de una línea que lo
  explique. Verificar que `test_table_sessions_router` sigue en verde **sin modificarlo** (Principio III; T097). Depende de T040.
- [X] T042 [US2] Verificación ([quickstart Q5](./quickstart.md)): `env/bin/python -m unittest app.characterization_tests.test_promotions_tenant_timezone_paths -v`
  en verde; `grep -rn "auto_discount(" pos-backend/app --include=*.py | grep -v characterization_tests` — **toda** llamada (salvo
  la definición) pasa 4 argumentos; y sin fallos nuevos en `test_promotions_service`, `test_orders_checkout`,
  `test_table_sessions_router`, `test_cart_service` ni en `env/bin/python -m app.scripts.test_promotions_rules` (A-57 intacto).

**Checkpoint**: US2 completa — 0 aplicaciones indebidas de promociones en las tres zonas (SC-003).
  > Hecho 2026-10-26. 1969 pruebas, 0 fallos (suite completa); `test_promotions_rules` OK (A-57 intacto); `grep`: toda llamada a `auto_discount` pasa 4 argumentos. **Sensibilidad probada**: quitar el `tenant` de cada uno de los 8 sitios (uno por vez) pone T035 en rojo. **Ampliaciones sobre el plan** (FR-006 dice «todos los caminos»): además de las 8 llamadas, `confirm_cash_payment_attempt` y `adjust_split_payment_attempt` llamaban `compute_checkout_preview(db, order_id)` sin tenant (validaban el monto con otra zona que la venta) → ahora reciben y reenvían `tenant` (con `Depends(get_tenant)` en `adjust-split`). **Fixture**: `table_sessions_fixtures.make_tenant_double` no tenía `timezone` y rompía dos pruebas `CONGELA` de `test_table_sessions_router` (que no se tocaron): se agregó `timezone='America/Bogota'` (mismo precedente que la spec 127 en `cart_fixtures`). **En el cobro dividido** el descuento no se suma a `Sale.discount` (lo trae el bloque del comensal): T035 lo mide en `applied_promotions`. **Deuda residual detectada, FUERA de alcance** (no está en la lista de FR-006): ~10 llamadas a `refresh_order_item_discounts(db, order)` sin tenant (`orders/kitchen.py`, `additions.py` ×3, `consolidation.py` ×2, `service.py`, `toppings.py` ×3) evalúan el snapshot por línea en la zona global; candidata a spec aparte / anotar en A-149 (T095).
---

## Phase 6: User Story 1 — Un negocio en otra zona ve todo en su hora (Priority: P1) · plan I3 + I5

**Goal**: toda fecha y hora (pantalla, ticket, reportes, correos) sale en la zona del tenant, sin importar la del navegador, el
servidor o el dispositivo del comensal (FR-001, FR-003, FR-008, FR-009, FR-011). Incluye la excepción **A-148** a FR-013.

**Independent Test**: [quickstart Q7](./quickstart.md) — tenant de Ciudad de México, navegador emulado en `Asia/Tokyo`, venta a las
17:30 locales: 17:30 en todas las pantallas; y [Q4](./quickstart.md)/[Q9](./quickstart.md) para el contrato y el correo.

### Backend — pruebas primero (deben fallar)

- [X] T043 [P] [US1] Crear `pos-backend/app/characterization_tests/test_contrato_instantes_api.py` según
  [contracts/instantes-api.md §4](./contracts/instantes-api.md): sustituye `app.core.db.initialize_database` por una función vacía
  **antes** de importar `app.main` (si no, `create_app()` intenta conectar a PostgreSQL) y usa las variables de entorno inertes
  de `fixtures.py`; obtiene `app.openapi()`; reúne los esquemas **alcanzables desde las respuestas** (cierre transitivo de
  `$ref`); recorre `anyOf/oneOf/allOf` y marca cada propiedad con `format == "date-time"`; define
  `INSTANTES_SIN_OFFSET_PERMITIDOS = {("PromotionResponse", "starts_at"), ("PromotionResponse", "ends_at")}` con su
  justificación (FR-002); **falla nombrando `Esquema.campo`** si el conjunto encontrado menos la excepción no está vacío, y
  también si una entrada de la lista de excepciones ya no existe. Incluye la **prueba de sensibilidad**: un modelo mínimo con
  `datetime` plano aparece en el conjunto y con `UtcDatetime` no (US6-1). Debe fallar listando los 24 campos hasta T046–T050.
  > Hecho 2026-10-26. Rojo verificado antes de implementar: el detector listó los **36** pares `Esquema.campo` (más amplio que los 24 del plan: ver T046) y quedó en 7 pruebas verdes tras T046–T050; sus 4 pruebas de sensibilidad (datetime plano / `UtcDatetime` / esquema solo de entrada / anidado en página) pasan. `app.main` se importa con `initialize_database` parcheado (si no abre PostgreSQL y migra).
- [X] T044 [P] [US1] Crear `pos-backend/app/characterization_tests/test_correo_zona_horaria.py` ([quickstart Q9](./quickstart.md);
  debe fallar hasta T052): sobre `construir_correo_contrasena_cambiada` con el mismo `momento` — Bogotá →
  `… (hora de Colombia)` **idéntico** al de hoy; Ciudad de México → `(hora de Ciudad de México)` y la hora local (UTC−6);
  Madrid, Lima, Santiago, Buenos Aires y Tokio con su nombre; zona válida fuera de la lista (`America/Sao_Paulo`) → `(UTC−3)`
  **sin** «hora de»; `zona_horaria=None` (Super Admin / sin tenant) → Bogotá; **ningún** texto (HTML y plano) de un tenant fuera
  de Colombia contiene «Colombia» (SC-010); y `_dispatch_password_changed_email` pasa `user.tenant.timezone` si
  `user.tenant_id is not None`.
- [X] T045 [P] [US1] En `pos-backend/app/characterization_tests/test_tenant_timezone.py` **agregar** (sin tocar las existentes, ver
  si alguna lleva `CONGELA`): `MenuBusinessResponse.model_validate(tenant)` incluye `timezone` (p. ej. `America/Mexico_City`) y
  `TenantResponse` incluye `timezone` además de `plan_vence_en` con offset `+00:00`. Debe fallar hasta T050/T051.

### Backend — contrato de instantes (FR-001): un `UtcDatetime` por definición

Reemplazar `datetime` por `UtcDatetime` (importar de `app.core.timezone`; conservar `Optional[...]`/`| None` y `Field(...)` tal
como estén). Solo esquemas de **respuesta**; los de entrada no cambian.

- [X] T046 [P] [US1] `pos-backend/app/api/v1/categories/schemas.py:84-85`, `presentations/schemas.py:31-32`,
  `unit_measures/schemas.py:30-31`, `users/schemas.py:40-41` — `created_at`, `updated_at` en `CategoryResponse`,
  `PresentationResponse`, `UnitMeasureResponse`, `UserResponse`. **Ampliada el 2026-10-26** (el inventario creció con las
  specs de grupos de unidades mergeadas en `develop` tras el plan; medido con el OpenAPI real): también
  `unit_measures/schemas.py` — `FactorChangeResponse.changed_at` — y `unit_measure_groups/schemas.py` —
  `UnitMeasureGroupResponse.created_at`, `updated_at`. Total medido: **27 campos en 15 definiciones** (no 24 / 13).
- [X] T047 [P] [US1] `pos-backend/app/api/v1/cart/schemas.py` — `SessionOpenResponse.expires_at` (~36) y
  `DinerPaymentAttempt.created_at`, `cash_confirmed_at` (~204, ~209); `table_sessions/schemas.py:27` —
  `ParticipantResponse.expires_at`; `invitations/schemas.py:48` — `InvitationResponse.sent_at`.
- [X] T048 [P] [US1] `pos-backend/app/api/v1/products/schemas.py:142,149-150` — `ProductResponse.available_changed_at`,
  `created_at`, `updated_at`. `ProductListResponse`, `ProductDetailResponse` y `ProductSaveResponse` lo **heredan**: no se editan.
- [X] T049 [P] [US1] `pos-backend/app/api/v1/promotions/schemas.py:252` — `PromotionResponse.closed_by_refactor_at`
  (es un instante, no hora de pared). **Dejar** `starts_at`/`ends_at` como están y agregar junto a ellos un comentario que cite
  FR-002 y la lista de excepciones de T043 (única excepción documentada).
- [X] T050 [P] [US1] `pos-backend/app/api/v1/super_admin/schemas.py` — `PaymentMethodCatalogResponse.created_at/updated_at` (~77-78),
  `TenantResponse.plan_vence_en/created_at/updated_at` (~99, ~102-103) y `PlanResponse.created_at/updated_at` (~186-187); y en
  `TenantResponse` agregar `timezone: str` (la zona IANA de la fila; FR-008, contrato
  [zona-horaria-tenant.md §2](./contracts/zona-horaria-tenant.md)). Mismo archivo que T078: este va primero.
- [X] T051 [P] [US1] `pos-backend/app/api/v1/menu/schemas.py` — `MenuBusinessResponse` (~171) gana `timezone: str`
  (research Decisión 11: el comensal es anónimo y no puede llamar a `GET /tenant`). `menu/router.py:387` ya construye el negocio con
  `MenuBusinessResponse.model_validate(ctx.tenant)`; confirmar que toma el atributo sin más cambios.

### Backend — correo con la zona del tenant (FR-011)

- [X] T052 [US1] `pos-backend/app/core/mail_templates/_campos.py`: agregar `formatear_fecha_hora(momento, zona)` con el mismo
  formato que hoy (`dd/mm/aaaa · hh:mm a. m./p. m.`, hora de 12 con cero inicial, construido a mano, sin `%p`) y el paréntesis
  final: si `zona` está en `ZONAS_CURADAS` → `(hora de {etiqueta})`; si es válida pero no está → `({desfase})` (T013). Dejar
  `formatear_fecha_hora_colombia(momento)` como **envoltorio de Bogotá** que devuelve **exactamente** el texto de hoy (los tres
  archivos `CONGELA` lo llaman y no se tocan). `pos-backend/app/core/mail_templates/contrasena_cambiada.py`:
  `construir_correo_contrasena_cambiada(..., zona_horaria: str | None = None)` (`None` ⇒ `America/Bogota`) y usar
  `formatear_fecha_hora`. Las plantillas de invitación y restablecimiento no muestran hora y no cambian.
- [X] T053 [US1] `pos-backend/app/api/v1/auth/routes.py` — `_dispatch_password_changed_email` (~57) pasa
  `zona_horaria=user.tenant.timezone if user.tenant_id is not None else None` (la relación `User.tenant` existe en
  `app/core/models.py`; el `try/except` existente se conserva). Depende de T052. Hace pasar T044.
- [X] T054 [US1] Suite completa del backend (una sola corrida) tras T046–T053: corregir las pruebas **no `CONGELA`** que comparen
  un `datetime` tomado de un `model_dump()` de estos esquemas (ahora es `str` porque `PlainSerializer` no tiene `when_used`:
  efecto conocido, research Decisión 3). Si falla una prueba `CONGELA`, **detenerse y consultar** (Principio III). Hace pasar T043
  y T045. Comparar con T002.
  > Hecho 2026-10-26. Suite completa: **1988 pruebas, 0 fallos**. Ninguna prueba no-`CONGELA` necesitó corrección por el `model_dump()` ahora `str`. `test_correo_contrasena_cambiada`, `test_correo_texto_plano` y `test_plantillas_correo_escape` (69 pruebas con las nuevas) pasan **sin haberse modificado** (`git diff` vacío). Commits sugeridos: A-148 = T046–T050 (+T054) en un commit propio y revertible; T051 (campo `timezone` del menú) va aparte.
### Frontend — cada sitio de [contracts/frontend-fechas.md §2](./contracts/frontend-fechas.md) (depende de T015–T017)

Regla: ninguna llamada directa a `toLocale(Date|Time)String`, `getHours()/getDay()/getDate()/getMonth()/getFullYear()`,
`toISOString().slice`, `| date`, `DatePipe` ni `formatDate` con zona IANA. La zona sale de `TenantInfoService.timezone()`
(o de un parámetro explícito). Escribir primero el caso de prueba que falla (México en tu `TZ`, instante `2026-10-25T23:30:00Z`
→ `17:30`).

- [X] T055 [P] [US1] `pos-heladeria/src/app/modules/tables/services/receipt.util.ts` (sitio 1): `formatDateTime` deja
  `getDate()/getHours()…` y usa `zonedParts(iso, opts.timezone)`; `ReceiptOptions` gana `timezone: string` **requerido** (así el
  compilador obliga a los cuatro llamadores). Extender `receipt.util.spec.ts`: ticket de un instante en Ciudad de México y en
  Madrid, correcto bajo `TZ=Asia/Tokyo` y `TZ=UTC`.
  > Hecho 2026-10-26. Tras agregar `timezone: string` **requerido** a `ReceiptOptions` el compilador marcó exactamente los 4 llamadores (`pos-terminal.store` ×2, `sales-page`, `tenant-info`), ya actualizados; el spec existente usaba `soldAt` SIN offset (dependía de la zona de la máquina) y ahora usa `2026-07-28T23:42:00+00:00` con helper `build()` que fija Bogotá. Fecha del ticket probada en Bogotá/México/Madrid/Tokio.
- [X] T056 [P] [US1] `pos-heladeria/src/app/modules/tables/components/pos-terminal-header.component.ts` (sitio 2):
  `formatClock` (`toLocaleTimeString`, ~107) y `formatDate` (`toLocaleDateString`, ~111) pasan a `formatInZone(d, timezone, …)`;
  `formatShift` (~117) usa `zonedParts(d, timezone).hour` con el mismo criterio (`< 12` Mañana, `< 19` Tarde, resto Noche) —
  contrato §3. Inyectar `TenantInfoService`. Extender `pos-terminal-header.component.spec.ts`: a `2026-10-25T23:30:00Z` con tenant
  de México muestra `17:30` y «Turno Tarde»; con tenant de Tokio muestra `08:30` y «Turno Mañana»; igual con el sistema en
  Tokio, Bogotá y UTC.
- [X] T057 [US1] `pos-heladeria/src/app/modules/tables/services/pos-terminal.store.ts` (sitios 1 y 3): las dos llamadas a
  `buildReceiptHtml` (~3226 y ~3272) pasan `timezone`; `createdAtLabel` (~921, `toLocaleTimeString('es-CO')`) usa
  `formatInZone`. Extender `pos-terminal.store.spec.ts` solo con el caso de hora (hay fallos preexistentes en ese archivo:
  comparar por nombre contra T003). Depende de T055.
- [X] T058 [US1] Pasar `timezone` (de `TenantInfoService.timezone()`) a `buildReceiptHtml` en
  `pos-heladeria/src/app/modules/sales/pages/sales-page.component.ts` (~270) y en
  `pos-heladeria/src/app/modules/settings/pages/tenant-info.component.ts` (~263, ticket de prueba). Verificar con los specs
  existentes `sales-page.component.spec.ts` y `tenant-info.component.spec.ts`. Depende de T055.
- [X] T059 [P] [US1] `pos-heladeria/src/app/modules/dashboard/components/shift-sales-report-card.component.ts` (sitio 4, ~144,
  `toLocaleString('es-CO')` de una fecha): usar `formatInZone`. Extender `shift-sales-report-card.component.spec.ts`.
- [X] T060 [P] [US1] `pos-heladeria/src/app/modules/dashboard/pages/admin-dashboard.component.ts` (sitio 5): saludo (~338,
  `new Date().getHours()` → `zonedParts(new Date(), tz).hour`, mismos umbrales `< 12` y `< 19`) y los **ejes** de la gráfica
  por hora/día/semana (~538-543: etiquetas de hora, `Sem d/m`, día) con `zonedParts`/`formatInZone`. **No** tocar
  `loadTrend` (aritmética de calendario ya local). Extender `admin-dashboard.component.spec.ts`: el 100 % de los ejes de un
  tenant de México salen en hora local aunque el sistema esté en Tokio (SC-002).
- [X] T061 [P] [US1] Sitios 6 y 7: `pos-heladeria/src/app/modules/dashboard/layout/header.component.ts:86` y
  `…/tenant-header.component.ts:173` — `| date: 'short'` → `| tenantDate: 'short'` (agregar `TenantDatePipe` a `imports` y quitar `DatePipe` del `import` de `@angular/common` y de
  `imports`).
  Extender `header.component.spec.ts` y `tenant-header.component.spec.ts` con una notificación a `23:30Z` de un tenant de
  México: muestra la hora local (5:30 p. m. / 17:30 según el formato), no la del navegador.
- [X] T062 [P] [US1] Sitio 8: `pos-heladeria/src/app/modules/plan/pages/plan-summary-page.component.ts:55` —
  `| date: 'mediumDate'` → `| tenantDate: 'mediumDate'` (cambiar `DatePipe` por `TenantDatePipe` en el `import` y en `imports`).
  Sin spec nuevo (la página no tiene): la protección es el spec del pipe
  (T017) y la guarda de T090.
  > Hecho 2026-10-26. La página no tiene spec propio: el cambio (`DatePipe` → `TenantDatePipe`) queda protegido por el spec del pipe (T017) y por la guarda de T090. Mismo caso: `header` y `tenant-header` (T061) y `pending-invitations-list` (T064) ganaron casos con México/Tokio/Bogotá en sus specs existentes.
- [X] T063 [P] [US1] Sitio 9: `pos-heladeria/src/app/modules/super-admin/pages/tenants-page.component.ts:112` —
  `| date: 'mediumDate'` → `| tenantDate: 'mediumDate' : t.timezone` (y cambiar `DatePipe` por `TenantDatePipe` en el `import` y en `imports`); en
  `pos-heladeria/src/app/modules/super-admin/interfaces/tenant.interface.ts` agregar `timezone: string` a `Tenant`. Crear
  `tenants-page.component.spec.ts` (la página no tiene): un tenant de Tokio con `plan_vence_en: '2026-11-01T16:00:00+00:00'` se
  muestra como **2 de noviembre de 2026** (no el 1.º), también con el navegador en Bogotá (US1-7).
  > Hecho 2026-10-26. Spec nuevo `tenants-page.component.spec.ts`: Tokio vence el 2/nov, Bogotá/México el 1/nov, mismo instante. `Tenant.timezone` requerido rompía la compilación del fixture de `tenant.service.spec.ts` (ya con `timezone`).
- [X] T064 [P] [US1] Sitio 10: `pos-heladeria/src/app/modules/users/components/pending-invitations-list.component.ts:43` —
  `| date: 'dd/MM/yyyy HH:mm'` → `| tenantDate: 'dd/MM/yyyy HH:mm'` (cambiar `DatePipe` por `TenantDatePipe` en el `import` y
  en `imports`). Extender `pending-invitations-list.component.spec.ts`
  («Enviada el…» con offset `+00:00` en la zona del tenant).
- [X] T065 [P] [US1] Sitio 11 (parte 1): `pos-heladeria/src/app/modules/tables/services/diner.service.ts` — `ResolvedBusiness` gana
  `timezone: string`, copiado de `business.timezone` del menú (T051). Extender `diner.service.spec.ts`.
- [X] T066 [US1] Sitio 11 (parte 2): `pos-heladeria/src/app/modules/tables/pages/public-menu.component.ts:1616` (`orderTime`,
  `toLocaleTimeString([])`) → `formatInZone(…, business.timezone)`. Extender `public-menu.component.spec.ts`: el comensal con
  el dispositivo en Tokio ve la hora del negocio. Depende de T065.
- [X] T067 [P] [US1] Sitio 13: `pos-heladeria/src/app/modules/reports/services/reports.service.ts` (~22 y ~63; el hallazgo E cita
  también ~294): `DEFAULT_TIMEZONE` → `FALLBACK_TIMEZONE`; el «hoy» del selector (`new Date().toLocaleDateString('en-CA')`) →
  `businessToday(timezone())`. `selectedDate` es un inicializador de campo que se evalúa **una sola vez** al construir el servicio:
  comprobar que `TenantInfoService.info()` ya esté hidratado en ese momento (arranque agregado, spec 100) o inicializarlo de forma
  perezosa; si no, un tenant fuera de Bogotá arrancaría con el «hoy» de la zona de respaldo. **No** tocar `getDateRange` ni `fmt`. Extender `reports.service.spec.ts`.
- [X] T068 [P] [US1] Sitio 16: `pos-heladeria/src/app/modules/promotions/services/promotion-pricing.util.ts` — nueva firma
  `isPromoActiveNow(promo, now: Date, timezone: string)` y `getPromoDisplay(p, now, timezone)`; con `p = zonedParts(now, timezone)`
  ([contracts §4](./contracts/frontend-fechas.md)): inicio `p.ymd + 'T' + hh:mm:ss` contra `promo.starts_at.slice(0,19)`; fin
  `p.ymd > promo.ends_at.slice(0,10)`; día de la semana `p.weekday`; ventana con `p.hhmm` contra `start_time`/`end_time`.
  `starts_at`/`ends_at` **no** pasan por `new Date()` (son hora de pared, FR-002). Sin implementar el cruce de medianoche de
  A-57 (fuera de alcance). Extender `promotion-pricing.util.spec.ts` con 18:00–20:00 y `23:30Z` en las tres zonas.
- [X] T069 [P] [US1] Sitio 15: `pos-heladeria/src/app/modules/promotions/services/promotion.service.ts:40` —
  `DEFAULT_TIMEZONE` → `FALLBACK_TIMEZONE`. Verificar con `promotion.service.spec.ts`.
- [X] T070 [US1] Sitio 14: `pos-heladeria/src/app/modules/promotions/pages/promotions-page.component.ts` (~46 y ~1670):
  `DEFAULT_TIMEZONE` → `FALLBACK_TIMEZONE` y pasar la zona del tenant a `getPromoDisplay`. **No** tocar `fmtDate`
  (mediodía local fijo). Verificar con `promotions-page.component.spec.ts`. Depende de T068.
- [X] T071 [P] [US1] Crear `pos-heladeria/src/app/shared/relative-time.pipe.spec.ts` (no existe): con `Date.now` fijado, un
  instante `…+00:00` de hace 2 h da «desde hace 2 horas» igual bajo `TZ=Asia/Tokyo`, Bogotá y UTC; pasadas 24 h cae a la fecha
  absoluta **en la zona del tenant** (México). Cubre SC-005 («agotado desde hace…» sin los 5 h de error).

### Verificación de User Story 1

- [X] T072 [US1] Frontend (solo esta suite): `TZ=Asia/Tokyo npx ng test --watch=false` sobre los specs tocados en T055–T071 y
  luego lo mismo con `TZ=UTC`; sin fallos nuevos por nombre respecto de T003.
  > Hecho 2026-10-26. Suite completa del frontend en las tres zonas: con la zona del sistema **0 fallos nuevos** (los mismos 14 de la línea base). En `Asia/Tokyo` y `UTC` apareció **1 fallo extra, preexistente y ajeno al código tocado**: `order-detail.component.spec` («Información de la orden»…) usaba `created_at: '2026-08-21T18:27:00'` SIN offset, que el navegador lee como hora local de la máquina (la línea base solo se midió en Bogotá y no podía verlo); se corrigió el fixture a `…T23:27:00+00:00`. Con eso Tokio/UTC quedan en los mismos 14 de la línea base (se reconfirma en T092).
- [X] T073 [US1] Backend: [quickstart Q4 y Q9](./quickstart.md) — `env/bin/python -m unittest app.characterization_tests.test_contrato_instantes_api app.characterization_tests.test_correo_zona_horaria app.characterization_tests.test_correo_contrasena_cambiada app.characterization_tests.test_correo_texto_plano app.characterization_tests.test_plantillas_correo_escape -v`:
  los tres archivos protegidos pasan **sin haberse modificado**. Con `uvicorn` nativo y un token válido,
  `curl -s … /api/v1/products | jq '.items[0].created_at'` termina en `+00:00`.
  > Hecho 2026-10-26 (parte automática y parte en vivo). `test_contrato_instantes_api` + los 3 archivos de correo protegidos pasan sin modificarse. En vivo con `uvicorn` nativo (puerto 8765) y un token acuñado con `create_access_token` (sin tocar datos): `GET /api/v1/users` → `created_at: 2026-10-06T21:10:14.483976+00:00`; `GET /tenant` → `timezone: America/Bogota`. (`tenantlocal` no tiene productos/categorías/unidades, por eso solo se pudo mostrar `users`.) **El recorrido manual T074 queda pendiente** (ver al final).
- [ ] T074 [US1] Recorrido manual **[quickstart Q7](./quickstart.md)** en el navegador del MCP con la zona emulada a `Asia/Tokyo`
  (`emulate`): poner `tenantlocal` en `America/Mexico_City` con `set_tenant_timezone`, hacer una venta y comprobar la **misma hora de
  Ciudad de México** en Ventas, Órdenes, Caja, Inventario («agotado desde hace»), ticket (vista previa), terminal (reloj, fecha,
  turno, hora de cada pedido), gráfica (todos los ejes), notificaciones, plan e invitaciones; y el menú público por QR. **Revertir**
  a `America/Bogota` al terminar. Registrar capturas en el informe de implementación.

**Checkpoint**: US1 completa — ninguna pantalla ni correo muestra una hora de Tokio o de Bogotá a un negocio de México.
  > **PARCIAL — sin marcar, 2026-10-26.** Hecho en vivo en el navegador del MCP (contexto aislado): como la herramienta `emulate` de esta versión **no tiene zona horaria**, se invirtió el diseño de Q7 con el mismo poder de detección: `tenantlocal` → `Asia/Tokyo` con `set_tenant_timezone` (imprimió la advertencia de FR-016) y el navegador en Bogotá (14 h de diferencia). A las 22:07 de Bogotá / 12:07 del 27/10 en Tokio: el **saludo del Dashboard** dijo «Buenas tardes» (hora de Tokio; con la zona del navegador diría «Buenas noches») y la **terminal de mesas** mostró «Turno Tarde», «12:07 p. m. · 27/10/2026» (no «Turno Noche», «10:07 p. m. · 26/10/2026»). Se revirtió a `America/Bogota`. **Falta** (requiere datos que `tenantlocal` no tiene —sin productos, categorías ni ventas— o un navegador con zona emulada): hacer una venta y ver Ventas/Órdenes/Caja, «agotado desde hace» (Inventario), ticket en vista previa, hora de cada pedido, ejes de la gráfica con datos, notificaciones, plan, invitaciones y el menú público por QR. Todo eso está cubierto por pruebas unitarias con México/Tokio/Bogotá en las tres zonas del sistema, pero no por un recorrido manual.
---

## Phase 7: User Story 5 — La zona se define al crear el tenant y siempre es válida (Priority: P2) · plan I4 + I6

**Goal**: el alta de tenant captura la zona desde una lista curada y toda zona se valida contra la base IANA por **cualquier**
camino, incluida la base de datos (FR-010, FR-016).

**Independent Test**: [quickstart Q3 y Q8](./quickstart.md) — crear un tenant eligiendo «Ciudad de México»; intentar guardar
`Nowhere/Land` por la pantalla (no deja), por la API (422), por el script (error) y directo en SQL (error `22023`).

### Tests for User Story 5 (escribir primero, deben fallar)

- [X] T075 [P] [US5] Extender `pos-backend/app/characterization_tests/test_tenant_timezone_validation.py` (parte 2; mismo archivo que
  T007): (a) `Tenant.timezone = 'localtime'` y `'Factory'` lanzan `ValueError` (antes el ORM las aceptaba); (b) `TenantCreateWithUser`
  sin `timezone` o con `None` es válido y con `Nowhere/Land` falla la validación; (c) `POST /api/v1/super-admin/tenants` con una zona
  inválida responde **422** con el formato de error del módulo y no crea nada (patrón de `test_tenant_plan_assignment.py`:
  `tenant_create()` exige PostgreSQL real, así que se prueba el esquema y se simula `tenant_create`); el alias heredado `Asia/Calcutta` pasa el
  esquema y se cubre con la función pura de T079 (`DataError` simulado con SQLSTATE `22023` ⇒ 422; otro SQLSTATE ⇒ no se traduce)
  y contra PostgreSQL real en T082; (d) `tenant_create`
  recibe `timezone` y, si es `None`, no lo asigna; (e) `set_tenant_timezone` con valor inválido termina en error y **no**
  persiste nada, e imprime la advertencia de FR-016 **antes** de escribir.
  > Hecho 2026-10-26. 25 pruebas (parte 1 + 2) rojas antes de implementar (23 fallos/errores) y verdes después. `tenant_create` se prueba con sus bordes sustituidos (exige PostgreSQL real); la traducción 22023→422 con `psycopg.errors` reales (`InvalidParameterValue` ⇒ 422; `NumericValueOutOfRange` ⇒ 500). El módulo de la prueba importa `app.models` (si no, ejecutado solo falla el mapper de `Tenant`).
- [X] T076 [P] [US5] Crear `pos-heladeria/src/app/shared/tenant-timezones.ts` (`TENANT_TIMEZONE_OPTIONS: { value: string; label: string }[]`
  con las siete zonas de [data-model.md §3](./data-model.md) y el nombre del selector, p. ej. «Bogotá (Colombia)», «Tokio (Japón)») y
  `pos-heladeria/src/app/shared/tenant-timezones.parity.spec.ts` que compara los `value` y `label` con **el mismo literal** que
  T006 (precedente: `core/tenant/reserved-slugs.parity.spec.ts`). Si la lista cambia en un lado, una prueba lo obliga en el otro.

### Implementation for User Story 5 — backend

- [X] T077 [US5] `pos-backend/app/core/models.py` (~108, `Tenant._validate_timezone`): reemplazar la validación con `ZoneInfo` por
  `validate_iana_timezone`. **Cuidado con el ciclo**: `app/core/timezone.py` importa `Tenant` de `app.core.models` en el nivel de
  módulo; importar `validate_iana_timezone` dentro del método, o mover el import de `Tenant` en `timezone.py` bajo
  `TYPE_CHECKING` (su anotación ya va entre comillas). Actualizar el comentario de ~87 («se fija vía `set_tenant_timezone.py`»)
  para citar también el alta.
- [X] T078 [US5] `pos-backend/app/api/v1/super_admin/schemas.py` — `TenantCreateWithUser` gana `timezone: str | None = None` con un
  `@field_validator` que, si el valor no es `None`, llama a `validate_iana_timezone` y lo convierte en error de validación (⇒
  **422** antes de crear nada). Mismo archivo que T050: este va después.
- [X] T079 [US5] `pos-backend/app/core/db.py` — `tenant_create(..., timezone: str | None = None)`: con valor se asigna al `Tenant`
  antes del `flush` (el `@validates` actúa); con `None` no se asigna y rige el `server_default='America/Bogota'`.
  `pos-backend/app/api/v1/super_admin/router.py` pasa `timezone=body.timezone`. **Además**, `tenant_create` —que hoy convierte
  cualquier excepción inesperada en `HTTPException(500)`, de modo que el router nunca ve el error de la base de datos— gana una rama
  `except DataError` **antes** del `except Exception` genérico: si el SQLSTATE es `22023` (el disparador de T081) hace `rollback` y
  responde **422** con el mismo tipo de `HTTPException` que ya usa para 404/409. La decisión vive en una función pura de
  `core/db.py` (p. ej. `_http_error_for_timezone_rejection(exc) -> HTTPException | None`) para probarla sin PostgreSQL (T075).
  Motivo: los alias heredados (`Asia/Calcutta`, `America/Buenos_Aires`) pasan `validate_iana_timezone` pero no existen en
  `pg_timezone_names`. Es seguro: `db.flush()` del `Tenant` ocurre **antes** de `CreateSchema`, dentro de la misma transacción.
  Depende de T078. El campo es **aditivo**.
- [X] T080 [P] [US5] `pos-backend/app/scripts/set_tenant_timezone.py` — validar con `validate_iana_timezone`; **antes de escribir**
  imprimir la advertencia de [zona-horaria-tenant.md §5](./contracts/zona-horaria-tenant.md) (zona anterior y nueva: «los instantes
  guardados no cambian, pero el historial se reinterpretará en la nueva zona…»); si la base rechaza el valor (disparador), informar
  el mensaje del motor; actualizar el docstring (hoy dice que valida «con `zoneinfo.ZoneInfo`»). Sigue siendo el **único** camino
  para un tenant ya creado (no hay pantalla de edición).
- [X] T081 [US5] Crear la migración `pos-backend/alembic/versions/<hash>_138_tenant_timezone_trigger.py`
  (`env/bin/alembic revision -m "138_tenant_timezone_trigger"`, `down_revision = 'c3d9a1f08b42'`) según
  [data-model.md §1](./data-model.md), **sobre `shared`** (no envuelta en `for_each_tenant_schema`, igual que
  `2d2c3090473f_add_tenant_timezone.py`, cuyo estilo de guardas `_has_*` se sigue): (1) pre-chequeo — seleccionar los tenants cuya
  zona no cumpla la regla y, si hay alguno, **no crear el disparador**: imprimir una advertencia con host y valor de cada tenant
  inválido y **terminar la migración sin error** (la migración corre en el arranque del API, `api-entrypoint.sh`; abortar lo
  dejaría en bucle de reinicio y tumbaría también I1–I3, contra «se pausa solo lo que depende» de la spec, Supuestos; nunca
  corregir datos: Principio VII). Tras corregir la zona con `set_tenant_timezone` se reaplica la migración (`alembic downgrade -1
  && alembic upgrade head` mientras sea la cabeza; si ya hay migraciones posteriores, ejecutar a mano el SQL del disparador de
  data-model.md §1);
  (2) `CREATE OR REPLACE FUNCTION shared.tenants_validate_timezone()` en PL/pgSQL: válida si
  `NEW.timezone = 'UTC' OR NEW.timezone LIKE '%/%'` **y** existe en `pg_timezone_names`, si no
  `RAISE EXCEPTION 'Zona horaria inválida: %', NEW.timezone USING ERRCODE = '22023'`; (3) `DROP TRIGGER IF EXISTS` +
  `CREATE TRIGGER trg_tenants_validate_timezone BEFORE INSERT OR UPDATE OF timezone ON shared.tenants FOR EACH ROW EXECUTE FUNCTION …`;
  `downgrade()` ejecuta `DROP TRIGGER IF EXISTS …` y `DROP FUNCTION IF EXISTS …` y no modifica filas. Idempotente.
  > Hecho 2026-10-26. **La migración cuelga de `c5815ab62693`** (no de `c3d9a1f08b42`, que ya no es la cabeza: `develop` avanzó). Revisión `af8fd44b3c4e`. Verificada en PostgreSQL real: ver T082.
- [X] T082 [US5] Verificar en **PostgreSQL real** ([quickstart Q3](./quickstart.md)): `env/bin/alembic upgrade head`; con `psql` en
  `BEGIN … ROLLBACK` y `SAVEPOINT` probar que `Nowhere/Land`, `localtime` y `''` fallan con `22023` y `America/Mexico_City`
  pasa, y que al final `tenantlocal` conserva `America/Bogota`; repetir con las siete zonas curadas (todas pasan);
  `set_tenant_timezone --host tenantlocal --timezone Nowhere/Land` ⇒ error y nada persistido; `env/bin/alembic downgrade -1`
  elimina el disparador (la primera sentencia ya no falla) y `upgrade head` lo recrea. Volver a correr `verify_timezone_storage`
  (T026): ahora informa que el disparador existe. Además: (a) el alias `Asia/Calcutta` también falla con `22023` en el `psql` (pasa
  Python, no PostgreSQL), y un `POST /api/v1/super-admin/tenants` real (con `uvicorn` nativo) con ese alias responde **422**, no 500,
  y no crea nada; (b) **migración con una zona inválida**: con el disparador ausente (tras `downgrade -1`), hacer
  `UPDATE shared.tenants SET timezone='Nowhere/Land' WHERE host='tenantlocal'` **confirmado** (la migración corre en su propia
  conexión y no vería un cambio sin confirmar), ejecutar `upgrade head` ⇒ termina **sin error**, imprime la advertencia con
  `tenantlocal` y **no** crea el disparador; restaurar `America/Bogota` de inmediato (pase lo que pase) y repetir
  `downgrade -1 && upgrade head` para instalarlo.
  > Hecho 2026-10-26 contra PostgreSQL 16 real (BD de desarrollo). (1) `alembic upgrade head` crea el disparador. (2) En `BEGIN…ROLLBACK` con `SAVEPOINT`: `Nowhere/Land`, `localtime`, `''`, `Bogota` y el alias `Asia/Calcutta` fallan con «Zona horaria inválida»; las 7 curadas y `UTC` pasan; `tenantlocal` queda en `America/Bogota`. (3) `set_tenant_timezone --timezone Nowhere/Land` ⇒ error (exit 1), nada persistido. (4) `downgrade -1` quita el disparador (el UPDATE inválido deja de fallar) y `upgrade head` lo recrea. (5) `verify_timezone_storage` informa «disparador existe». (a) **POST real** (`uvicorn` nativo, token de super admin acuñado) con `Asia/Calcutta` ⇒ **422** («la base de datos no la reconoce»), no 500; con `Nowhere/Land` y `localtime` ⇒ 422; **no se creó nada** (3 tenants antes y después, ningún esquema). (b) **Migración con zona inválida**: tras `downgrade -1` y un `UPDATE` confirmado a `Nowhere/Land`, `upgrade head` terminó con **exit 0**, avisó «[138] NO se creó el disparador… tenantlocal='Nowhere/Land'» y no creó el disparador; se restauró `America/Bogota` de inmediato y `downgrade -1 && upgrade head` lo instaló.
- [X] T083 [US5] Backend: `env/bin/python -m unittest app.characterization_tests.test_tenant_timezone_validation app.characterization_tests.test_tenant_timezone app.characterization_tests.test_tenant_plan_assignment app.characterization_tests.test_super_admin_error_envelope -v`
  en verde (T075 incluido).
  > Hecho 2026-10-26: 46 pruebas OK (`test_tenant_timezone_validation`, `test_tenant_timezone`, `test_tenant_plan_assignment`, `test_super_admin_error_envelope`).
### Implementation for User Story 5 — frontend (depende de T076 y T063)

- [X] T084 [US5] `pos-heladeria/src/app/modules/super-admin/interfaces/tenant.interface.ts` — `TenantCreateWithUser` gana
  `timezone?: string` (la pantalla siempre lo envía; opcional en el tipo porque la API lo es). Mismo archivo que T063: este va
  después.
- [X] T085 [US5] `pos-heladeria/src/app/modules/super-admin/components/tenant-form.component.ts` (sitio 20): campo
  `timezone` del formulario reactivo como `<select>` **obligatorio, sin valor inicial** (opción vacía «Selecciona una zona») con las
  opciones de `TENANT_TIMEZONE_OPTIONS`; «Guardar» no avanza sin elegir una (nadie queda en Bogotá por olvido); el valor viaja en el
  payload de `createTenant`. Extender `tenant-form.component.spec.ts` (usa `form.patchValue` y un `TenantService` simulado):
  nace vacío y el formulario es inválido; elegido «Ciudad de México», `createTenant` recibe `timezone: 'America/Mexico_City'`;
  los casos existentes de host reservado siguen pasando (ahora `llenarValido` debe incluir `timezone`).
  > Hecho 2026-10-26. 12 pruebas OK (`tenant-form` + paridad) con la zona del sistema y `TZ=Asia/Tokyo`. El selector nace vacío, ofrece «Selecciona una zona» (deshabilitada) + las 7 zonas en español, bloquea «Guardar» sin elegir y envía `timezone: 'America/Mexico_City'` al elegir Ciudad de México; `llenarValido` ahora incluye `timezone`.
- [X] T086 [US5] Recorrido manual **[quickstart Q8](./quickstart.md)**: en `admin.<dominio>` → «Nuevo Tenant»: «Zona horaria» aparece
  vacía con las siete opciones en español y no deja guardar sin elegir; crear un tenant con «Ciudad de México» y comprobar
  `GET /api/v1/super-admin/tenants` (`timezone: America/Mexico_City`) y que su «Vence» se ve en esa zona aunque el navegador esté
  en otra; por API sin `timezone` nace `America/Bogota` y con `Nowhere/Land` ⇒ 422 sin crear nada. **Limpiar** el tenant de prueba
  (`DELETE` de `shared.users`/`shared.tenants` y `DROP SCHEMA … CASCADE`).

**Checkpoint**: US5 completa — la zona nace en el alta y no puede guardarse inválida por ningún camino.
  > Hecho 2026-10-26 **en vivo** (stack de desarrollo: `ng serve` 4200 + `fastapi` 8000; sesión de Super Admin acuñada con el secreto del `.env` en un contexto aislado del navegador del MCP). (1) «Nuevo Tenant» muestra «Zona horaria *» **vacía** («Selecciona una zona») con las **siete** opciones en español; «Guardar» sin elegir no avanza y muestra «Debes elegir una zona horaria». (2) Alta real desde la UI con «Ciudad de México», plan «Ilimitado (transición)», sin vencimiento ⇒ la BD guarda `America/Mexico_City` y `GET /super-admin/tenants` lo lista con su `timezone` (esto ejercitó `tenant_create(timezone=…)` y el disparador contra PostgreSQL real, lo que los tests con bordes simulados no podían). (3) Por API **sin** `timezone` ⇒ nace `America/Bogota`; con `Asia/Calcutta` ⇒ **422** y 0 tenants creados (en el servidor del usuario, puerto 8000); con `Nowhere/Land`/`localtime` ⇒ 422 (verificado antes en 8765). (4) **Limpieza hecha**: `DELETE` de `shared.users`/`shared.tenants` y `DROP SCHEMA … CASCADE` de `prueba137mx` y `prueba137bo`; 0 esquemas y 0 usuarios residuales. No se vio una fila con «Vence» ≠ «Sin vencimiento» (los tenants de desarrollo no tienen vencimiento): ese caso lo cubre `tenants-page.component.spec`.
---

## Phase 8: User Story 6 — Red de seguridad de pruebas (Priority: P2) · plan I7

**Goal**: pruebas y verificaciones automáticas que impiden reintroducir estos defectos, y suites que no dependen de la zona de la
máquina que las corre (FR-003, FR-012).

**Independent Test**: introducir a propósito un campo `datetime` plano en una respuesta de la API y una `toLocaleTimeString` en
el frontend: las pruebas fallan nombrándolos.

> El detector del OpenAPI (T043), la guarda `ast` (T020) y los casos de borde (T028) ya nacieron con sus historias; esta fase
> agrega lo que falta y **demuestra** el conjunto.

- [X] T087 [P] [US6] Corregir `pos-backend/app/characterization_tests/test_auth_session_revocation.py::test_same_wall_clock_second_as_cutover_is_not_rejected`
  (~92): calcula `iat` con `int(now.timestamp())` sobre un `datetime` **naive en UTC**, que Python interpreta como hora local
  (falla con `TZ=Asia/Tokyo`). Usar un `datetime` aware en UTC (`now.replace(tzinfo=timezone.utc).timestamp()`). El código de
  producción es correcto (`core/dependencies.py` documenta esa trampa). No lleva prefijo `CONGELA` (verificado en la planificación;
  reconfirmar antes de editar).
  > Hecho 2026-10-26. Verificado rojo con `TZ=Asia/Tokyo` antes del arreglo y verde en Tokio, UTC y la zona del sistema (29 pruebas de `test_auth_session_revocation` + `test_table_sessions_router`). Ninguna lleva prefijo `CONGELA`.
- [X] T088 [P] [US6] Corregir `pos-backend/app/characterization_tests/test_table_sessions_router.py::test_401_por_inactividad_no_lleva_la_cabecera`
  (~465): `ana.expires_at = datetime.now() - timedelta(minutes=5)` usa la hora **local** de la máquina para una columna en UTC.
  Usar `utc_now_naive()` (o `datetime.now(timezone.utc).replace(tzinfo=None)` en la prueba). Revisar en el mismo archivo los demás
  `datetime.now()` naive (p. ej. el de duración máxima, ~479, que no falla por su margen de 3 días pero tiene el mismo defecto).
  > Hecho 2026-10-26: `datetime.now()` → `utc_now_naive()` en las dos pruebas (la de inactividad y la de duración máxima, que tenía el mismo defecto aunque no fallaba por su margen de 3 días).
- [X] T089 [P] [US6] `pos-backend/.github/workflows/deploy.yml`: en el job `test`, agregar **después** del paso «Characterization
  tests» un paso «Characterization tests (zona del sistema Asia/Tokyo)» con
  `run: TZ=Asia/Tokyo python -m unittest discover -s app/characterization_tests -p 'test_*.py' -v`. El runner ya es UTC, así que
  los dos pasos cubren Tokio y UTC (FR-012).
  > Hecho 2026-10-26 (YAML validado).
- [X] T090 [P] [US6] Crear `pos-heladeria/src/app/shared/date-usage.guard.spec.ts` — contraparte de T020, según
  [contracts/frontend-fechas.md §5](./contracts/frontend-fechas.md): lee con `node:fs` (comprobado: el constructor de pruebas de
  Angular 21 lo permite) las fuentes `.ts` (no `.spec.ts`) de `src/app` y falla indicando archivo y línea ante las **reglas
  exactas** de [contracts §5](./contracts/frontend-fechas.md) (expresiones regulares, no subcadenas: `DatePipe` casaría con
  `TenantDatePipe` y `formatDate(` con los métodos propios `store.formatDate(` que sí usan el tenant): importación de `DatePipe` o
  `formatDate` desde `@angular/common`; `| date` en plantillas; `.getHours(`, `.getMinutes(`, `.getSeconds(`, `.getDay(`,
  `.getDate(`, `.getMonth(`, `.getFullYear(`, `.toTimeString(`, `.toDateString(`; `.toLocaleDateString(` y `.toLocaleTimeString(`;
  `.toLocaleString(` solo si sus opciones traen `hour|minute|day|month|year|weekday` (el de **números**, que formatea dinero,
  está permitido); `toISOString().slice|substring|split`; e `Intl.DateTimeFormat` fuera de `date-format.util.ts` y
  `tenant-date.pipe.ts`. Lista de excepciones **comentada una por una** y declarada **por archivo y por texto literal de la línea
  permitida** (no por archivo completo: un `getHours()` nuevo en `admin-dashboard.component.ts` debe seguir fallando aunque
  `loadTrend` esté exceptuado), construida ejecutando la guarda y
  justificando cada hallazgo: el propio `date-format.util.ts`, `tenant-date.pipe.ts` (envuelve `formatDate`) y los sitios de
  aritmética de calendario de [contracts §2 «Revisados y sin cambio»](./contracts/frontend-fechas.md) (`reports.service.ts::getDateRange`
  y `fmt`, `order-date-filter.component.ts`, `orders-page.component.ts`, `cash-session.store.ts`, `promotions-page.component.ts::fmtDate`,
  `checkout-progress.store.ts`, `jwt.util.ts`, `app-update.service.ts`, `forgot-password.component.ts`, `auth-shell.component.ts`, y los
  dos que faltaban en la primera versión del contrato: `reports-page.component.ts::bucketLabel` —`getDay` sobre una fecha ya
  local— y `admin-dashboard.component.ts::loadTrend`).
  **Depende de T055–T070 y T033**: si alguna quedó sin migrar, la guarda las lista.
  > Hecho 2026-10-26. 15 pruebas (4 sobre el árbol real + 11 de sensibilidad). `node:fs` compila y lee las fuentes en el constructor de pruebas de Angular 21. Hallazgos reales = exactamente los 8 sitios de «aritmética de calendario» del contrato + el `import` de `formatDate` del propio pipe; cada excepción va por archivo + texto literal de la línea y con su motivo, y una prueba demuestra que un `getHours()` nuevo en `admin-dashboard` sigue fallando aunque `loadTrend` esté exceptuado. También revisa la única plantilla `.html` (`app.html`).
- [X] T091 [US6] Matriz de zonas del **backend** ([quickstart Q1](./quickstart.md)): una corrida por zona, una tras otra —
  `env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'` con la zona de la máquina, con
  `TZ=Asia/Tokyo` y con `TZ=UTC` — más `env/bin/python -m app.scripts.test_promotions_rules`. Esperado: **0 fallos nuevos** en las
  tres (en la línea base T002 había 1 fallo por la hora del día y 2 por la zona de la máquina).
  > Hecho 2026-10-26. **2010 pruebas, 0 fallos** con la zona del sistema (UTC−5), con `TZ=Asia/Tokyo` y con `TZ=UTC` (línea base: 1 fallo por la hora del día + 2 por la zona de la máquina) y `test_promotions_rules` OK en dos zonas.
- [X] T092 [US6] Matriz de zonas del **frontend** (**después** de T091, nunca en paralelo): `npx ng test --watch=false`,
  `TZ=Asia/Tokyo npx ng test --watch=false` y `TZ=UTC npx ng test --watch=false`; comparar los nombres de pruebas fallidas
  contra T003. Esperado: los mismos fallos preexistentes ajenos y ninguno nuevo en ninguna zona.
  > Hecho 2026-10-26, una zona tras otra y después del backend. Con una corrida limpia, **la zona del sistema, `Asia/Tokyo` y `UTC` dan los mismos 14 fallos preexistentes de la línea base, 0 nuevos por nombre**. Nota honesta: una primera pasada de la matriz mostró desviaciones (+1 en la zona del sistema, +57 en UTC, todas en `promotions-page`/`admin-dashboard`); esos specs pasaron aislados en ambas zonas y la repetición de la suite completa las eliminó: es la deriva por carga ya documentada de esta suite (comparar siempre por nombre y repetir ante una desviación).
- [X] T093 [US6] Demostrar la sensibilidad de las guardas (SC-008) y **revertir cada cambio**: (a) cambiar `UtcDatetime` por
  `datetime` en `CategoryResponse.created_at` ⇒ `test_contrato_instantes_api` falla nombrando `CategoryResponse.created_at`;
  (b) agregar `.replace(tzinfo=None)` sobre `utc_now()` en un módulo ⇒ `test_instantes_forma_unica` falla con archivo y línea;
  (c) agregar un `toLocaleTimeString` en un componente ⇒ `date-usage.guard.spec.ts` falla. Dejar el árbol sin esos cambios.
  > Hecho 2026-10-26, las tres demostradas y REVERTIDAS (el `sha1sum` de cada archivo es idéntico al de antes): (a) `UtcDatetime`→`datetime` en `CategoryResponse.created_at` ⇒ `test_contrato_instantes_api` falla listando `CategoryResponse.created_at`; (b) `utc_now().replace(tzinfo=None)` a mano en `inventory/service.py` ⇒ `test_instantes_forma_unica` falla con `api/v1/inventory/service.py:52`; (c) un `toLocaleTimeString` en `admin-dashboard.component.ts` ⇒ `date-usage.guard.spec` falla con `…admin-dashboard.component.ts:50 — toLocaleDateString/toLocaleTimeString`. Además (T035): quitar el `tenant` de cada uno de los 8 sitios de `auto_discount` pone `test_promotions_tenant_timezone_paths` en rojo.
- [X] T094 [US6] Auditoría de cobertura de US6-2 y US6-4: confirmar por escrito (comentario o nota en el informe) que existe **una
  prueba por cada** caso: tres zonas de tenant en cada archivo nuevo de zona (Bogotá, México, Madrid), día de 25 h, día de 23 h,
  medianoche inexistente de Santiago, ventana 00:00–02:00 al este de UTC, turno que cruza la medianoche y hora repetida.
  Cualquier hueco se cierra en `test_business_day_boundaries.py` o `test_promotions_tenant_timezone_paths.py`.

**Checkpoint**: las seis historias funcionan y la deuda no puede volver sin que algo falle.
  > Hecho 2026-10-26. Auditoría por escrito — **una prueba por caso**: (1) tres zonas de tenant (Bogotá, Ciudad de México, Madrid): `test_business_day_boundaries` (propiedad sobre `ZONAS_DE_PRUEBA` y turno que cruza), `test_promotions_tenant_timezone_paths` (`CASOS`), `test_payment_attempt_reject` (rechazos), `test_inventory_export` (nombre del archivo), `test_correo_zona_horaria`, `test_tenant_timezone` (respuestas); (2) día de **25 h** (Madrid 25/10/2026) y de **23 h** (Madrid 29/03/2026 y Santiago) y **medianoche inexistente de Santiago** (06/09/2026): `TestLimitesDelDiaLocalMedidos`; (3) **00:00–02:00 al este de UTC**: `test_madrid_entre_las_00_y_las_02_locales_hoy_es_el_dia_local` (el «hoy») y, **agregada en esta auditoría** (era el único hueco), `TestVentanaDeMadrugadaAlEsteDeUtc` (ventana de promoción 00:00–02:00 a las 00:30 locales de Madrid con el día UTC todavía anterior); (4) **turno que cruza la medianoche local**: `TestTurnoQueCruzaLaMedianocheLocal` (3 zonas, atribuido al día de apertura); (5) **hora repetida** de Madrid: `TestHoraRepetidaDeMadrid`. Frontend: ticket, terminal, dashboard, promociones, reportes y menú público con México/Tokio/Madrid.
---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: cierre documental, verificación final y el paso a producción.

- [X] T095 [P] `pos-specs/specs/000-reconocimiento/registro-de-anomalias.md`: completar **A-149** con lo que la planificación y la
  implementación descubrieron (las dos pruebas dependientes de la zona de la máquina, la suite dependiente de la hora del día,
  `connect` en vez de `options`, el disparador, el nombre del archivo de inventario si se prefiere citar aquí); y pasar el estado de
  A-147, A-148 y A-149 a «IMPLEMENTADA» **solo** cuando T091–T094 estén en verde, **conservando** «pendiente de ratificación con
  el negocio» en A-147/A-148 hasta que T099 ocurra.
  > Hecho 2026-10-26: A-149 completada (pruebas dependientes de la zona/hora, `connect` en vez de `options`, inventario ampliado, disparador, llamadores extra, **deuda residual de `refresh_order_item_discounts`**); A-147, A-148 y A-149 pasan a «IMPLEMENTADA»; A-147/A-148 **conservan «pendiente de ratificación con el negocio»** hasta T099. La tabla resumen no se tocó (no se mantiene más allá de A-65).
- [X] T096 [P] Revisar los pasajes que describan horas y zona (sin cambio de comportamiento para Bogotá, salvo A-147/A-148):
  `pos-specs/docs-publicos/06-administracion-global/gestion-de-tenants-y-planes.md` (el alta de tenant ahora pide la zona,
  lista curada de siete) y `pos-specs/srs/README.md` (~líneas 146, 496, 1067 y 2228: reloj de referencia, perfil del tenant,
  `X-Server-Time`, filtros por día). Si el SRS describe «instantes sin offset» o el correo con «hora de Colombia» fijo, corregir.
  > Hecho 2026-10-26. `docs-publicos/06-administracion-global/gestion-de-tenants-y-planes.md` (paso 3: el alta pide la zona, lista de siete, sin valor inicial, cambio posterior solo por soporte) y `srs/README.md` (supuesto 2.5: instantes en UTC con offset y zona curada; `TenantCreateWithUser` con `timezone?`, regla de 422/disparador y citas de línea actualizadas; RF-tenant-001). El SRS no describía «instantes sin offset» ni «hora de Colombia» fijo: nada más que corregir; `X-Server-Time` y los filtros por día ya eran correctos.
- [X] T097 Comprobar el Principio III: en `pos-backend`, `git diff develop -- app/characterization_tests | grep -n "CONGELA"`
  no muestra ninguna prueba `CONGELA` modificada o eliminada, y `git diff develop --stat -- app/characterization_tests/test_correo_contrasena_cambiada.py app/characterization_tests/test_correo_texto_plano.py app/characterization_tests/test_plantillas_correo_escape.py`
  está **vacío** (0 pruebas protegidas modificadas, [plan.md](./plan.md) Constitution Check).
  > Hecho 2026-10-26: `git diff develop` en `pos-backend` no muestra ninguna línea `CONGELA` agregada ni eliminada (0 coincidencias) y los tres archivos de correo protegidos tienen diff vacío. Archivos de prueba existentes tocados: solo fixtures (tablas SQLite, `ZONAS_DE_PRUEBA`, reloj fijado, `timezone` del doble) y 4 pruebas NO `CONGELA` (2 defectuosas por zona, 2 ampliadas).
- [X] T098 Validación final del [quickstart](./quickstart.md): repetir Q2, Q3, Q4, Q5, Q6 y Q9 de punta a punta sobre el árbol final
  (Q1 ya fue T091/T092; Q7 y Q8 fueron T074/T086) y comprobar el mapa de trazabilidad del quickstart (Q → historia → FR → SC). Un
  solo ciclo completo de la suite del backend al final, sin la del frontend en paralelo.
  > Hecho 2026-10-26 sobre el árbol final: Q2 (PGTZ=America/Bogota, Asia/Tokyo y sin PGTZ ⇒ `OK`), Q3 (psql: los tres inválidos fallan, `tenantlocal` intacto), Q4+Q5+Q6+Q9 (101 pruebas OK, incluidos los 3 archivos de correo protegidos) y **un ciclo completo del backend: 2014 pruebas OK** + `test_promotions_rules` OK, sin la suite del frontend en paralelo. Q1 fue T091/T092; Q7 y Q8 son los recorridos manuales T074/T086 (pendientes).
- [ ] T099 *(humano, no bloquea la implementación)* Obtener la **ratificación del negocio** de A-147 y A-148 (segundo rechazo y
  nombre del archivo de inventario para Bogotá entre 19:00 y 24:00; «agotado desde hace…» y «Enviada el…» sin 5 h de desfase).
  Hasta entonces siguen «pendientes de ratificación» (decisión del equipo de desarrollo, 2026-10-25). Puede gestionarse en paralelo
  desde el inicio. Si el negocio rechaza una, se abre una spec aparte; no se revierte en silencio.
- [ ] T100 *(operativo, fuera del entorno de desarrollo)* **Compuerta 0 y despliegue** ([quickstart Q10](./quickstart.md), research
  Decisión 16). Paso 0, **antes de cualquier despliegue**: en el servidor de producción,
  `docker compose exec api python -m app.scripts.verify_timezone_storage` debe terminar en `OK`, y la señal complementaria
  `SELECT now() AT TIME ZONE 'UTC' - max(paid_at) FROM <tenant>.payments;` en un tenant de uso diario debe dar horas o minutos
  **positivos pequeños** (una diferencia cercana a ±5 h delata una sesión histórica no UTC). Si la sesión no es UTC o los datos no
  estaban en UTC ⇒ **pausar solo FR-004/FR-005 en producción**, informar y abrir la spec de corrección de datos (Principios VII
  y VIII); si algún tenant tiene zona inválida ⇒ la migración T081 **omite** el disparador y avisa (el backend arranca igual) y no se
  endurece la validación en la base de datos hasta resolverlo; la compuerta lo detecta antes (verificación (4)). Paso 1:
  **backend** (la migración del disparador corre en el arranque vía `api-entrypoint.sh`). Paso 2: **frontend**. Reversa:
  revertir el código de cada repositorio por separado y `alembic downgrade -1`; no hay datos que restaurar.
- [ ] T101 *(manual; ejecutar antes de desplegar, T100)* Recorrido de **no regresión de Bogotá** (FR-013, SC-009;
  [quickstart Q11](./quickstart.md)). Con `tenantlocal` en `America/Bogota`, comparar el árbol final contra las capturas de
  `develop` tomadas **antes de empezar** (T003): con el navegador emulado en `Asia/Tokyo` y luego en la zona de Bogotá, ticket
  (vista previa), reloj/fecha/turno de la terminal, gráfica por hora, notificaciones, plan y «Vence» de Super Admin muestran los
  **mismos valores**, salvo A-147 y A-148 (las capturas de «agotado desde hace…» y «Enviada el…» documentan el cambio de A-148).
  Registrar las capturas en el informe de implementación.
  > **PARCIAL — sin marcar, 2026-10-26.** Con `tenantlocal` en `America/Bogota` (navegador en Bogotá) el stack en vivo muestra el saludo/terminal con los valores de Bogotá de siempre: «Turno Noche», «10:09 p. m. · 26/10/2026» (= la hora de Bogotá del momento). **No se cumplió el requisito de la tarea**: (a) las capturas de referencia de `develop` de T003 **no se tomaron** antes de cambiar el código (se pueden regenerar desde un `git worktree` de `develop`), y (b) no se pudo emular el navegador en `Asia/Tokyo` (la herramienta no tiene zona horaria). Pendiente comparar ticket (vista previa), gráfica por hora, notificaciones, plan y «Vence» de Super Admin contra `develop`, con A-147/A-148 como únicas diferencias esperadas.
---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias. T002 y T003 se ejecutan **una después de la otra**.
- **Foundational (Phase 2)**: depende de Setup. Cadena backend T006–T013 y cadena frontend T014–T017 son independientes entre sí.
  **Bloquea a las historias**, con una precisión: US2, US3 y US4 solo necesitan la cadena backend (T009–T013); US1 y US5 necesitan
  además la cadena frontend; US6 necesita el resto.
- **User Stories (Phase 3+)**: ver el orden recomendado abajo. Dependencia técnica real, no numérica:
  - **US4 → resto del backend**: deja la sesión en UTC y la forma única de escritura sobre la que las demás son correctas.
  - **US3 y US2 comparten `orders/checkout.py`** (T025 → T031 → T036): hacerlas en este orden evita conflictos.
  - **US1-backend** necesita T050/T051 para los campos `timezone`; **US5-backend** (T078) edita el mismo
    `super_admin/schemas.py` que T050 → T050 va primero. **US5-frontend** (T084) edita el mismo `tenant.interface.ts` que T063 → T063 primero.
  - **US6** va **al final**: la guarda del frontend (T090) y la matriz (T091–T092) exigen que todo lo demás ya esté migrado.
- **Polish (Phase 9)**: depende de las historias deseadas. T100 es operativo y se ejecuta con el despliegue.

### Mapa plan ↔ tareas

| Incremento del plan | Historia | Tareas |
|---|---|---|
| I1 Almacenamiento en UTC | US4 | T019–T027 (+ T009 de la fase 2) |
| I2 Reglas que dependen de la hora | US3, US2 | T028–T034, T035–T042 (+ T010) |
| I3 Contrato de instantes | US1 (+ US6) | T043, T045–T051, T054 |
| I4 Zona del tenant | US5 (+ correo en US1) | T075, T077–T083, T052–T053 (+ T011–T013) |
| I5 Presentación en el frontend | US1 | T055–T072 (+ T014–T017) |
| I6 Alta con zona en Super Admin | US5 | T076, T084–T086 |
| I7 Red de seguridad y documentación | US6 + Polish | T087–T094, T095–T101 |

**Despliegue** (distinto del orden de implementación): compuerta 0 → backend (I1–I4) → frontend (I5–I6) → T100.

### Within Each User Story

- Las pruebas se escriben **primero** y deben fallar donde la tarea lo indica (T019/T020, T029/T030, T035, T043/T044, T075).
- Funciones centrales antes que sus usos; esquemas antes que routers; interfaces antes que componentes.
- Cerrar la verificación de la historia (T027, T034, T042, T072–T074, T083, T086) antes de pasar a la siguiente prioridad.

### Parallel Opportunities

- **Entre repositorios**: la cadena frontend de Foundational (T014–T017) corre a la vez que la backend (T006–T013).
- **Phase 3**: T019 ‖ T020; luego T023 ‖ T024 ‖ T025 (archivos distintos, tras T021/T022 y T009).
- **Phase 4**: T028 ‖ T029 ‖ T030 ‖ T033.
- **Phase 5**: T036 ‖ T037 ‖ T039 ‖ T040 (archivos distintos); T038 y T041 después de las suyas.
- **Phase 6**: T043 ‖ T044 ‖ T045; T046 ‖ T047 ‖ T048 ‖ T049 ‖ T050 ‖ T051 (un archivo de esquemas cada una); en el frontend
  T055 ‖ T056 ‖ T059 ‖ T060 ‖ T061 ‖ T062 ‖ T063 ‖ T064 ‖ T065 ‖ T067 ‖ T068 ‖ T069 ‖ T071.
- **Phase 8**: T087 ‖ T088 ‖ T089 ‖ T090. **Nunca** en paralelo: T002/T003, T091/T092, ni ninguna suite completa de un repo con la del otro.

### Parallel Example: User Story 1 (frontend, tras la fase 2)

```bash
# Sitios independientes (archivos distintos), cada uno con su spec:
Task: "T055 receipt.util.ts + receipt.util.spec.ts"
Task: "T056 pos-terminal-header.component.ts + spec"
Task: "T059 shift-sales-report-card.component.ts + spec"
Task: "T060 admin-dashboard.component.ts + spec"
Task: "T063 tenants-page.component.ts + tenant.interface.ts + spec nuevo"
Task: "T068 promotion-pricing.util.ts + spec"
```

---

## Implementation Strategy

### MVP First (US4 → US3 → US2)

1. Phase 1: Setup (T001–T005).
2. Phase 2: Foundational (T006–T018).
3. Phase 3: **US4** — almacenamiento correcto. **STOP y VALIDAR** con Q2: cero cambio de comportamiento, base segura.
4. Phase 4–5: **US3 y US2** — los dos defectos que cuestan dinero o señal de revisión (uno ya afecta a Bogotá a diario).
   Backend puro, desplegable por sí solo.

### Incremental Delivery

1. Setup + Foundational → funciones centrales listas.
2. US4 → US3 → US2 (backend, desplegable): reglas correctas en cualquier zona.
3. US1 → el negocio de otra zona **ve** todo en su hora (contrato + correo + 21 sitios del frontend). Es el valor de cara al
   cliente y la razón de la spec; desplegar backend primero y frontend después (T100).
4. US5 → alta con zona y validación en la base de datos.
5. US6 → red de seguridad y matriz de zonas. Cada incremento termina con su suite en verde y se puede revertir solo.

### Parallel Team Strategy

Con varias personas, tras Foundational: A toma US4 → US3 → US2 (backend); B toma el frontend de US1 (T055–T071, que solo
necesita T014–T017 y los campos `timezone` ya acordados en los contratos); C toma US5-backend (T075–T083) una vez libre
`super_admin/schemas.py`. US6 la cierra quien termine primero.

---

## Notes

- **[P]** = archivos distintos y sin dependencia de una tarea incompleta; las tareas sobre el mismo archivo van en serie
  aunque pertenezcan a historias distintas (la lista está en «Phase Dependencies»).
- **Sin dependencias nuevas** (Principio IX): `zoneinfo` + `tzdata==2026.2` en el backend e `Intl` en el frontend ya existen.
- **Un solo cambio de esquema**: el disparador de T081. Ningún tipo de columna cambia y ningún dato histórico se migra ni se
  recalcula (Principio VII). Un tenant de Bogotá no ve cambios salvo las dos excepciones registradas, A-147 y A-148.
- Los números de línea se desplazan: relocalizar con `grep -n` antes de editar.
- Las tareas manuales (T074, T086, T099, T100, T101) no tienen automatización posible desde el entorno de desarrollo; se reportan
  como pendientes si no se ejecutan.
- Verificar que las pruebas fallan antes de implementar donde se indica; detenerse en cada **Checkpoint** para validar la
  historia de forma independiente.
