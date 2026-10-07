---

description: "Lista de tareas de implementación — spec 100"
---

# Tasks: Carga agregada (bootstrap) del panel de staff al iniciar sesión

**Input**: Documentos de diseño de `/specs/100-bootstrap-dashboard-staff/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md) (10 decisiones),
[data-model.md](./data-model.md), [contracts/bootstrap-endpoint.md](./contracts/bootstrap-endpoint.md),
[quickstart.md](./quickstart.md)

**Tests**: **SÍ se incluyen.** El Constitution Check (Principio X) exige tests backend (`unittest`,
`test_bootstrap.py` nuevo) y tests frontend (`bootstrap.service.spec.ts` nuevo + `tenant-info.service.spec.ts`
actualizado + `plan-summary.service.spec.ts`/`notification-center.service.spec.ts` nuevos); research.md
Decisión 10 fija el archivo y la convención exacta de cada uno.

**Organization**: por historia de usuario, en el orden de prioridad de `spec.md` (US1 P1, US2 P2, US3 P2).
Las 3 historias ejercitan el **mismo** endpoint `GET /bootstrap`: US1 construye el camino feliz completo
(backend + consumo en frontend), US2 añade la tolerancia a Super Admin (bloques `null`) y US3 añade la
degradación granular por bloque — cada fase es la unidad mínima que hace avanzar `build_bootstrap()` sin
romper lo que la fase anterior ya dejó funcionando.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: puede ir en paralelo (archivo distinto, sin dependencia de una tarea sin terminar)
- **[Story]**: a qué historia de usuario pertenece (US1, US2, US3)
- Cada tarea incluye la ruta exacta del archivo

## Convenciones de ruta

Esta spec toca **ambos repositorios**; las rutas se escriben desde la raíz del workspace:

- `../pos-backend/app/...` — FastAPI + SQLAlchemy (Python 3.11+). Tests en
  `../pos-backend/app/characterization_tests/`, ejecutados desde `../pos-backend` con
  `./env/bin/python -m unittest app.characterization_tests.<modulo> -v` (suite completa:
  `./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py' -v`) — **no `pytest`**.
- `../pos-heladeria/src/app/...` — Angular 21 standalone + signals (TypeScript 5.9). Tests con Vitest vía
  `ng test --include='<glob>'` (suite completa: `ng test`).
- Sin prefijo — archivo dentro de este repo (`pos-specs`).

## Nota sobre gobernanza (Principios II/XIV/XV) y ramas

- Sin entrada nueva en `registro-de-anomalias.md`: el Constitution Check de `plan.md` (Principio II) ya
  concluye que el comportamiento nuevo de este endpoint no es un "cambio" de nada preexistente.
- **Ramas (Principio XIV)**, en `../pos-backend` **y** `../pos-heladeria`: una sola rama
  `feat/100-bootstrap-dashboard-staff`, creada desde `develop` en ambos repos (ambos están hoy limpios
  sobre `develop`). Las 3 historias comparten los mismos archivos (`service.py`/`router.py` en backend,
  `bootstrap.service.ts`/`dashboard-layout.component.ts` en frontend), así que no hay motivo para ramas
  hermanas — se trabajan en secuencia sobre la misma rama.
- **Commits**: solo cuando el usuario lo pida explícitamente (Principio XV) — pequeños, en inglés,
  Conventional Commits, sin atribución de IA.
- **Despliegue**: el endpoint es 100% aditivo (no reemplaza `/tenant`, `/plan` ni `/notifications`), así
  que no hay un orden obligatorio backend-antes-que-frontend más allá de que el frontend nuevo necesita
  que `/bootstrap` ya exista en el entorno donde se prueba.

---

## Phase 1: Setup

**Purpose**: ramas y línea base antes de tocar código.

- [X] T001 Crear la rama `feat/100-bootstrap-dashboard-staff` desde `develop` en **ambos** repos
  (verificar primero `git -C ../pos-backend status` y `git -C ../pos-heladeria status` limpios sobre
  `develop`): `git -C ../pos-backend switch -c feat/100-bootstrap-dashboard-staff` y
  `git -C ../pos-heladeria switch -c feat/100-bootstrap-dashboard-staff` (Principio XIV)
- [X] T002 [P] Medir la línea base de la suite backend **sin cambios**, desde `../pos-backend`:
  `./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py' -v`, y anotar en
  este archivo el recuento (`Ran N tests … OK`) contra el que se compara al cierre (Principio III)
  **Línea base**: `Ran 1442 tests ... OK` (sin fallos).
- [X] T003 [P] Medir la línea base de la suite frontend **sin cambios**, desde `../pos-heladeria`: `ng
  test`, y anotar en este archivo el recuento de fallos preexistentes (ver
  `reference_pos_suite_frontend_fallos_preexistentes` de memoria: históricamente 19 fallos en 6 archivos
  ajenos al checkout) para no confundirlos con una regresión de esta spec
  **Línea base**: `6 failed | 110 passed (116)` archivos de test, `10 failed | 1490 passed | 1 skipped
  (1501)` tests individuales — fallos preexistentes en `app.spec.ts`, `auth.service.spec.ts`,
  `menu.service.spec.ts`, `tenant.service.spec.ts`, `pos-checkout-panel.component.spec.ts` y
  `pos-order-panel.component.spec.ts` (confirmado contra una corrida aislada post-implementación con el
  mismo recuento exacto — ver T033), ajenos a esta spec.

**Checkpoint**: ramas creadas en ambos repos, línea base de ambas suites anotada.

---

## Phase 2: Foundational (prerrequisitos bloqueantes)

**Purpose**: la resolución de tenant tolerante a Super Admin (sin la cual **ninguna** de las 3 historias
puede montar el endpoint) y la forma del DTO de respuesta. research.md §§1, 2.

**⚠️ CRITICAL**: ninguna historia puede empezar hasta que esta fase esté completa.

- [X] T004 En `../pos-backend/app/core/db.py`, extraer de `get_tenant()` (líneas 190-211) el `SELECT` que
  busca `Tenant.host == host_without_port` a un helper público nuevo
  `find_tenant_by_host(host_without_port: str) -> Optional[Tenant]` (mismo archivo, junto a
  `resolve_tenant_by_id`, que ya es su gemelo por id). `get_tenant()` pasa a llamar a este helper y
  **conserva exactamente** su comportamiento actual: `400` si falta la cabecera `x-tenant-host`, `404` si
  el helper devuelve `None`, y el efecto colateral `req.state.tenant_id = tenant.id` (spec 074) solo
  cuando sí hay tenant (research.md Decisión 2, Principio II — sin characterization test dedicado; lo
  protege la suite completa corrida en T002/T032)
- [X] T005 En `../pos-backend/app/core/dependencies.py` (junto al import existente de `get_db, get_tenant,
  with_db` en la línea 9, agregar `find_tenant_by_host`), crear
  `get_optional_tenant(req: Request) -> Optional[Tenant]`: igual validación de cabecera que `get_tenant`
  (`400` si falta `x-tenant-host`), pero usando `find_tenant_by_host` y devolviendo `None` en vez de
  levantar `404` cuando no hay fila — fijando `req.state.tenant_id` solo cuando sí resuelve (research.md
  Decisión 2; plan.md § Project Structure ubica esta dependencia aquí, no en `db.py`)
- [X] T006 En el mismo `../pos-backend/app/core/dependencies.py`, crear
  `get_optional_db(tenant: Optional[Tenant] = Depends(get_optional_tenant)) -> Session`, espejo de
  `get_db` (`db.py:224-227`) pero tolerante a `tenant=None`: `with with_db(tenant.schema if tenant else
  None) as db: yield db`. Sin este wrapper, el endpoint de arranque no tendría forma de obtener una
  sesión cuando el usuario es Super Admin (depende de T005)
- [X] T007 [P] Crear `../pos-backend/app/api/v1/bootstrap/__init__.py` (paquete vacío, mismo patrón que
  `tenant/`, `plan/`, `notifications/`)
- [X] T008 [P] Crear `../pos-backend/app/api/v1/bootstrap/schemas.py::BootstrapResponse` con 3 campos
  opcionales que anidan, sin modificarlos, `TenantInfoResponse` (`tenant/schemas.py`), `PlanSummaryResponse`
  (`plan/schemas.py`) y `NotificationListResponse` (`notifications/schemas.py`) — los 3 con default `None`
  (research.md Decisión 4, data-model.md)

**Checkpoint**: la resolución de tenant tolera Super Admin de punta a punta (dependencia + sesión de BD) y
la forma de la respuesta del arranque está fijada. Las 3 historias pueden empezar.

---

## Phase 3: User Story 1 - Arranque del panel en una sola petición para staff y administradores de un tenant (Priority: P1) 🎯 MVP

**Goal**: staff/administrador de un tenant inicia sesión y el panel queda operativo con negocio, plan y
notificaciones recientes mediante una única petición HTTP, sin tocar el ticket de tiempo real.

**Independent Test**: iniciar sesión como staff/administrador de un tenant con datos reales, confirmar en
la pestaña de red que aparece una sola `GET /api/v1/bootstrap` (más `POST /realtime/ticket`, sin cambios)
en vez de las 3+ peticiones separadas, y que el panel se pinta igual de completo que antes.

### Backend

- [X] T009 [US1] Crear `../pos-backend/app/api/v1/bootstrap/service.py::build_bootstrap(db: Session, tenant:
  Optional[Tenant], user: User) -> dict`. Camino feliz únicamente (sin degradación granular todavía, eso
  es US3): reutiliza, **sin duplicar lógica**, lo que ya existe — `tenant_block = tenant` (igual que
  `tenant/router.py::get_tenant_info`, válido por `TenantInfoResponse.model_config.from_attributes`),
  `plan_block = plan_service.build_plan_summary(db, tenant)` (`plan/service.py`, ya recibe `db`/`tenant`
  resueltos) y `notifications_block = notifications_router.list_notifications(db=db, _=user)` (sus
  defaults `page=1, size=20, after_id=None` ya son exactamente los que pide FR-008/research.md Decisión
  5 — llamarla directamente en vez de reimplementar el query). Si `tenant` es `None` todavía no está
  contemplado aquí (lo agrega T025, US2): por ahora asumir que siempre llega un tenant resuelto
  **Nota de implementación**: los defaults de `list_notifications` son objetos `Query(...)` de FastAPI
  que solo se resuelven a su valor real cuando FastAPI invoca la ruta por una petición HTTP; llamada aquí
  como función Python directa hay que pasarlos explícitos (`page=1, size=20, after_id=None, limit=100,
  only_pending=False`) — de lo contrario `after_id` llega como el objeto `Query`, no `None`, y entra al
  modo recuperación por error (`db.get(NotificationEvent, Query(...))`, `AttributeError`). Corregido en
  `service.py` y en `test_bootstrap.py`.
- [X] T010 [US1] Crear `../pos-backend/app/api/v1/bootstrap/router.py::GET /bootstrap` (`router =
  APIRouter(prefix="/bootstrap", tags=["bootstrap"])`), sin parámetros de query/path, usando
  `db: Session = Depends(get_optional_db)`, `tenant: Optional[Tenant] = Depends(get_optional_tenant)` y
  `user: User = Depends(get_authenticated_user)` (no `get_current_user`, que exige tenant — research.md
  Decisión 2), delegando a `service.build_bootstrap(db, tenant, user)`, `response_model=BootstrapResponse`
  (depende de T008, T009)
- [X] T011 [US1] Montar el router nuevo en `../pos-backend/app/main.py`: agregar `from
  app.api.v1.bootstrap.router import router as bootstrap_router` junto al resto de imports de routers
  (líneas 19-44) y `app.include_router(bootstrap_router, prefix="/api/v1")` junto al resto de
  `include_router` (líneas 141-166) (depende de T010)
- [X] T012 [P] [US1] Crear `../pos-backend/app/characterization_tests/bootstrap_fixtures.py`: mismo patrón
  que `plan_fixtures.py` (`new_session()` sobre SQLite en memoria, `make_plan`/`make_tenant`/`make_user`
  reexportados o reimportados de `plan_fixtures`), pero con la tabla `notification_events` agregada a su
  lista de tablas (y el shim `@compiles(JSONB, "sqlite")` que `test_notifications.py` ya usa para que
  `payload` compile sobre SQLite) más un `make_notification(db, tenant, **kw)` que inserte una fila mínima
  válida de `NotificationEvent`
- [X] T013 [US1] Crear `../pos-backend/app/characterization_tests/test_bootstrap.py` con el caso feliz
  (Acceptance Scenario 1 de US1): llamando `bootstrap_router.get_bootstrap(db=db, tenant=tenant, user=user)`
  directamente (sin `TestClient`, research.md Decisión 10) sobre una sesión de `bootstrap_fixtures.py` con
  tenant+plan+al menos una notificación, verificar que los 3 bloques de la respuesta son **exactamente**
  equivalentes a lo que hoy devuelven `plan_router.get_plan_summary(db, tenant, user)` y
  `notifications_router.list_notifications(db=db, _=user)` por separado (contrato § Caso 1) (depende de
  T009, T012)

### Frontend

- [X] T014 [P] [US1] En `../pos-heladeria/src/app/core/tenant/tenant-info.service.ts`, agregar
  `hydrate(value: TenantInfo | null): void { this.info.set(value); }` — fija el signal directamente, sin
  disparar `HttpClient`; `load()` queda intacto para los refrescos de FR-003 (research.md Decisión 7)
- [X] T015 [P] [US1] En
  `../pos-heladeria/src/app/modules/plan/services/plan-summary.service.ts`, agregar
  `hydrate(value: PlanSummary | null): void { this.summary.set(value); }`, mismo criterio que T014
- [X] T016 [P] [US1] En `../pos-heladeria/src/app/core/notifications/notification-center.service.ts`,
  agregar una guarda booleana `initialized` compartida entre el `bootstrap()` privado (líneas 71-88,
  invocado hoy desde el constructor en la línea 46) y un nuevo `hydrate(value: NotificationListResponse |
  null): void` público: **el primero que se ejecuta marca la guarda y gana** (si es `hydrate()`, fusiona
  `value.items` vía el `merge()` existente cuando `value` no es `null`; si es el `bootstrap()` automático
  por DI, sigue igual que hoy) — el que llega después queda no-operativo. Marcar la guarda **antes** de
  cualquier `await`, de forma síncrona, para que el orden real de instanciación de Angular (no garantizado,
  research.md Decisión 8) nunca dispare `GET /notifications` dos veces
  **Corrección durante la implementación (research.md Decisión 8, addendum, aprobada por el usuario)**:
  verificado en la práctica que la premisa de "orden no garantizado" era falsa — la construcción de
  Angular es síncrona y `HeaderComponent` ya inyecta `NotificationCenterService` como campo de clase, así
  que el auto-arranque del constructor **siempre** ganaba la guarda, y `GET /notifications` seguía
  disparándose por separado en todas las cargas (SC-001 no se cumplía para ese bloque). Verificado que
  `NotificationCenterService` no tiene otro consumidor fuera de este shell. Se retiró la llamada
  incondicional a `bootstrap()` del constructor; la recuperación por `lastSeenId` (RF-008) quedó inline en
  el constructor (sigue siendo petición propia, fuera del alcance del agregador — research.md §5) y la
  carga común (sesión nueva) llega solo vía `hydrate()`. El método privado `bootstrap()` se eliminó.
- [X] T017 [P] [US1] Crear `../pos-heladeria/src/app/core/bootstrap/bootstrap.model.ts` con la interfaz
  `BootstrapResponse` espejo del schema backend: `{ tenant: TenantInfo | null; plan: PlanSummary | null;
  notifications: NotificationListResponse | null }`, reutilizando los tipos ya existentes de cada servicio
- [X] T018 [US1] Crear `../pos-heladeria/src/app/core/bootstrap/bootstrap.service.ts::BootstrapService`
  (`providedIn: 'root'`), con `load(): Promise<void>` que hace `GET ${environment.apiBaseUrl}/bootstrap`
  y reparte la respuesta llamando `tenantInfo.hydrate(res.tenant)`, `planSummaryService.hydrate(res.plan)`
  y `notificationCenter.hydrate(res.notifications)`; un fallo total (red, timeout, `5xx`) se captura en
  silencio **sin llamar ningún `hydrate()`** y sin reintentar nada dentro de ese mismo `load()` (FR-005,
  research.md Decisión 7) (depende de T014, T015, T016, T017)
- [X] T019 [US1] Refactorizar `ngOnInit()` de
  `../pos-heladeria/src/app/modules/dashboard/layout/dashboard-layout.component.ts` (líneas 110-118):
  inyectar `BootstrapService` y reemplazar las llamadas a `this.tenantInfo.load()` y
  `this.planSummaryService.load()` por una sola `void this.bootstrapService.load()`; `this.realtime.connectStaff()`
  **no cambia de línea ni de posición** (FR-004) (depende de T018)
- [X] T020 [P] [US1] Crear `../pos-heladeria/src/app/core/bootstrap/bootstrap.service.spec.ts` (`TestBed` +
  `provideHttpClientTesting`/`HttpTestingController`, mismo patrón que `tenant-info.service.spec.ts`):
  caso feliz — una sola `GET /bootstrap` reparte cada bloque al `hydrate()` correspondiente de los 3
  servicios inyectados (con `useValue` espía o servicios reales con sus signals verificados) (depende de
  T018)
- [X] T021 [P] [US1] Actualizar
  `../pos-heladeria/src/app/core/tenant/tenant-info.service.spec.ts` con un `describe('hydrate')` que
  verifica que fija `info()` sin disparar ninguna petición HTTP (`http.verify()` sin peticiones pendientes)
  (depende de T014)
- [X] T022 [P] [US1] Crear
  `../pos-heladeria/src/app/modules/plan/services/plan-summary.service.spec.ts` (nuevo — no existe hoy)
  cubriendo `hydrate()` con el mismo criterio que T021 (depende de T015)
- [X] T023 [P] [US1] Crear
  `../pos-heladeria/src/app/core/notifications/notification-center.service.spec.ts` (nuevo — no existe
  hoy) cubriendo la guarda de una sola ejecución de T016 en **ambos órdenes posibles** (quickstart.md §6):
  "el bootstrap llega primero" (llamar `hydrate()` antes de que el `bootstrap()` automático del
  constructor resuelva su petición) y "el auto-arranque por DI corre primero" (dejar que `bootstrap()`
  resuelva antes de llamar `hydrate()`) — en ambos casos, `GET /notifications` se dispara **como máximo
  una vez** por instancia del servicio (depende de T016)
  **Nota (tras el addendum de research.md Decisión 8)**: con `bootstrap()` eliminado, los dos escenarios
  ya no son una carrera — son dos ramas deterministas según haya o no `lastSeenId` persistido. "El
  bootstrap llega primero" = sesión nueva (sin `lastSeenId`): `hydrate()` es la única vía, sin petición
  HTTP alguna. "El auto-arranque por DI corre primero" = sesión con `lastSeenId` (RF-008): el constructor
  dispara `recoverMissed()` de forma síncrona y gana la guarda; un `hydrate()` posterior es no-operativo.
  Ambos casos cubiertos; 18/18 tests en verde (`bootstrap.service.spec.ts` +
  `tenant-info.service.spec.ts` + `plan-summary.service.spec.ts` + `notification-center.service.spec.ts`).
- [ ] T024 [US1] Recorrido manual de `quickstart.md` §1 (una sola petición, SC-001), §2 (los refrescos
  puntuales de Ajustes siguen usando `GET/PATCH /tenant`, `/plan`, `/notifications` individuales, nunca
  `/bootstrap` — SC-004) y §5 (el ticket de tiempo real sigue pidiéndose individual, FR-004/FR-009),
  dejando constancia del resultado en este archivo (depende de T011, T019)
  **Bloqueado en este entorno**: el contenedor `pos-api` está en crash-loop (no alcanza Postgres en
  `127.0.0.1:5432` dentro de su red Docker — error preexistente, ajeno a esta spec) y es una imagen
  construida sin montar el código fuente, por lo que ni siquiera reflejaría estos cambios si arrancara.
  Pendiente de ejecutar cuando el stack de desarrollo esté operativo.

**Checkpoint**: US1 es demostrable sola — staff/administrador de un tenant carga el panel con una sola
petición, con los refrescos puntuales y el tiempo real intactos.

---

## Phase 4: User Story 2 - Arranque sin fallos para Super Admin sin tenant ni plan asignados (Priority: P2)

**Goal**: el Super Admin (sin `tenant` ni `plan`) completa el arranque con `200` y los 3 bloques en `null`,
sin que el panel se caiga.

**Independent Test**: iniciar sesión como Super Admin y confirmar que el panel carga sin pantalla en
blanco ni bloqueo, con los bloques de negocio/plan vacíos, y que `GET /api/v1/bootstrap` respondió `200`
(no `404`).

- [X] T025 [US2] En `../pos-backend/app/api/v1/bootstrap/service.py::build_bootstrap`, agregar al inicio
  de la función: `if tenant is None: return {"tenant": None, "plan": None, "notifications": None}` — los 3
  bloques en `null`, **incluyendo** `notifications` (research.md Decisión 6: es tenant-scoped igual que
  las otras dos, no solo `tenant`/`plan`), sin intentar ninguna consulta (depende de T009)
- [X] T026 [P] [US2] Extender `../pos-backend/app/characterization_tests/test_bootstrap.py` (Acceptance
  Scenario 1 de US2, contrato § Caso 2): llamar `bootstrap_router.get_bootstrap(db=None, tenant=None,
  user=super_admin)` y verificar que no levanta ninguna excepción y devuelve los 3 bloques en `None`
  (depende de T025)
- [ ] T027 [US2] Recorrido manual de `quickstart.md` §3 (SC-003): iniciar sesión como Super Admin, confirmar
  en la pestaña de red que `GET /api/v1/bootstrap` responde `200` con `{ "tenant": null, "plan": null,
  "notifications": null }` y que el resto del shell (header, sidebar, navegación de super-admin) funciona
  con normalidad, dejando constancia del resultado en este archivo (depende de T011, T025)
  **Bloqueado en este entorno** — mismo motivo que T024 (`pos-api` en crash-loop, imagen sin montar el
  código fuente).

**Checkpoint**: US1 y US2 funcionan juntas — staff/admin de tenant y Super Admin cargan el panel sin
fallos, cada uno con su propio contenido.

---

## Phase 5: User Story 3 - Continuidad del panel cuando el arranque falla total o parcialmente (Priority: P2)

**Goal**: si `/bootstrap` falla por completo o solo una de sus 3 fuentes internas falla, el panel sigue
siendo usable — degradación granular en el backend (FR-006), sin reintentos automáticos en el frontend
(FR-005).

**Independent Test**: simular la caída completa de `/bootstrap` y, en otro caso, forzar que falle
únicamente una de sus 3 fuentes internas, confirmando en ambos casos que el panel permanece usable.

- [X] T028 [US3] En `../pos-backend/app/api/v1/bootstrap/service.py::build_bootstrap`, envolver cada uno
  de los 3 bloques (`tenant_block`, `plan_block`, `notifications_block`) en su propio `try/except`
  independiente (research.md Decisión 3): un fallo en uno deja ese bloque en `None` y registra el error
  con `logger.exception` (sin filtrar datos sensibles), sin interrumpir el cálculo de los otros dos; la
  respuesta siempre es `200` (depende de T025)
- [X] T029 [P] [US3] Extender `../pos-backend/app/characterization_tests/test_bootstrap.py` (Acceptance
  Scenario 2 de US3, contrato § Caso 3) con 3 casos — uno por bloque (`tenant`, `plan`, `notifications`)
  — que fuerzan el fallo de exactamente esa fuente (p. ej. monkeypatching la función reutilizada de T009
  para que levante una excepción) y verifican que los otros dos bloques llegan completos en la misma
  respuesta `200`, más un 4º caso que fuerza el fallo simultáneo de las 3 fuentes a la vez y verifica
  que la respuesta sigue siendo `200` con los 3 bloques en `None` (Edge Case 2 de spec.md —
  combinaciones de 2 o 3 fuentes fallando a la vez, cubiertas por el mismo diseño de `try/except`
  independiente por bloque) (depende de T028)
  **Ajuste**: `tenant_block = tenant` es una referencia directa al parámetro ya resuelto — no hay ninguna
  consulta ni operación dentro de `build_bootstrap` que pueda fallar ahí (a diferencia de `plan`/
  `notifications`, que sí ejecutan queries reales), así que no existe un caso real "solo tenant falla"
  que forzar. Implementados: plan solo, notifications solo, y plan+notifications simultáneo (Edge Case 2:
  "dos o las tres fuentes" — cubre la independencia del diseño); 5/5 tests en verde.
- [X] T030 [P] [US3] Extender `../pos-heladeria/src/app/core/bootstrap/bootstrap.service.spec.ts` (T020)
  con el caso de fallo total: la petición `GET /bootstrap` responde con error (red o `5xx`) y se verifica
  que **ningún** `hydrate()` de los 3 servicios se invoca y que no se dispara ninguna petición adicional
  dentro de esa misma llamada a `load()` (FR-005) (depende de T018, T020)
  Ya incluido en T020 (escrito de una vez junto con los otros 2 casos del mismo archivo).
- [ ] T031 [US3] Recorrido manual de `quickstart.md` §4 (SC-002): fallo total (bloquear `**/api/v1/bootstrap`
  en DevTools antes del login) — el panel sigue usable con los valores por defecto actuales, sin
  reintentos automáticos de `/tenant`, `/plan` ni `/notifications`; y fallo parcial (forzar que solo
  `notifications` falle en el backend) — `GET /bootstrap` responde `200` con `tenant`/`plan` completos y
  `notifications: null`, dejando constancia del resultado en este archivo (depende de T028). Incluir
  también la verificación de `quickstart.md` §5 bajo estos dos escenarios (realtime sigue funcionando
  tras un arranque parcialmente degradado y tras un arranque totalmente fallido) — T024 solo la
  verificó bajo el camino feliz de US1, antes de que existieran estos dos estados
  **Bloqueado en este entorno** — mismo motivo que T024/T027 (`pos-api` en crash-loop, imagen sin montar
  el código fuente).

**Checkpoint**: las 3 historias funcionan juntas — el panel es usable en los 4 escenarios del spec (feliz,
Super Admin, fallo total, fallo parcial).

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: confirmar que no hay regresiones en ninguna de las dos suites completas.

- [X] T032 [P] Correr la suite completa backend desde `../pos-backend`:
  `./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py' -v` y comparar el
  recuento contra la línea base de T002 (debe ser igual más los tests nuevos de `test_bootstrap.py`, todo
  en `OK`)
  **Resultado**: `Ran 1447 tests ... OK` (1442 base + 5 nuevos de `test_bootstrap.py`). Sin regresiones.
- [X] T033 [P] Correr la suite completa frontend desde `../pos-heladeria`: `ng test` y comparar los fallos
  contra la línea base de T003 (debe ser igual — los fallos preexistentes documentados en memoria, ninguno
  nuevo)
  **Resultado** (corrida aislada, sin la suite backend compitiendo por CPU — una corrida en paralelo dio
  19/36 fallos por timeouts de contención, una corrida intermedia dio 7/11 por la misma razón residual):
  `6 failed | 113 passed (119)` archivos, `10 failed | 1503 passed | 1 skipped (1514)` tests — **idéntico**
  a la línea base de T003 (6 archivos / 10 tests, los mismos: `app.spec.ts`, `auth.service.spec.ts`,
  `menu.service.spec.ts`, `tenant.service.spec.ts`, `pos-checkout-panel.component.spec.ts`,
  `pos-order-panel.component.spec.ts`) más las 13 pruebas nuevas de esta spec, todas en verde. Sin
  regresiones.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias — puede empezar de inmediato
- **Foundational (Phase 2)**: depende de Setup — **bloquea** las 3 historias
- **US1 (Phase 3)**: depende de Foundational
- **US2 (Phase 4)**: depende de Foundational **y de US1** (T025 modifica la misma función que crea T009;
  no es una historia independiente en el sentido de "archivo distinto", sino un paso incremental sobre el
  mismo `build_bootstrap`)
- **US3 (Phase 5)**: depende de US2 (T028 envuelve en `try/except` lo que T025 ya dejó armado)
- **Polish (Phase 6)**: depende de que las 3 historias estén completas

### Notas sobre independencia de las historias

A diferencia de specs con historias en archivos separados, aquí **las 3 historias modifican la misma
función** `build_bootstrap()` de forma estrictamente aditiva: US1 la crea (camino feliz, tenant siempre
presente), US2 le agrega el `if tenant is None` al principio, US3 le agrega `try/except` por bloque. Cada
fase es "independientemente demostrable" en el sentido de `spec.md` (su escenario de aceptación pasa al
cerrar esa fase), pero **no son paralelizables entre sí** — van en orden estricto US1 → US2 → US3.

### Parallel Opportunities

- Dentro de Setup: T002 y T003 en paralelo
- Dentro de Foundational: T007 y T008 en paralelo (después de T004-T006, que sí son secuenciales entre sí)
- Dentro de US1: T012 puede ir en paralelo con T009-T011 (archivo de fixtures sin dependencia de código);
  T014, T015, T016, T017 en paralelo entre sí (archivos frontend distintos, sin dependencia de backend);
  T020, T021, T022, T023 en paralelo entre sí una vez lista T018/T019
- Dentro de US3: T029 y T030 en paralelo (backend y frontend, archivos distintos)
- Polish: T032 y T033 en paralelo

---

## Parallel Example: User Story 1 (frontend)

```bash
# Los 3 hydrate() son archivos distintos, sin dependencia entre sí:
Task: "hydrate() en tenant-info.service.ts"
Task: "hydrate() en plan-summary.service.ts"
Task: "hydrate() + guarda en notification-center.service.ts"

# Una vez listos, los 4 archivos de test también en paralelo:
Task: "bootstrap.service.spec.ts"
Task: "tenant-info.service.spec.ts (hydrate)"
Task: "plan-summary.service.spec.ts (nuevo)"
Task: "notification-center.service.spec.ts (nuevo, ambos órdenes de la guarda)"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Completar Phase 1 (Setup) y Phase 2 (Foundational — crítico, bloquea todo)
2. Completar Phase 3 (US1): endpoint + consumo en frontend
3. **Detener y validar**: recorrido manual de quickstart.md §1/§2/§5; con esto ya se cumple SC-001
4. Desplegar/demostrar si está listo — el Super Admin seguiría viendo el `500` de hoy (404 silencioso)
   hasta que US2 aterrice, pero el 100% de los inicios de sesión de staff/tenant ya se benefician

### Incremental Delivery

1. Setup + Foundational → base lista
2. + US1 → una sola petición para staff/tenant (MVP, SC-001)
3. + US2 → Super Admin ya no se cae (SC-003)
4. + US3 → resiliencia ante fallo total o parcial (SC-002)
5. Polish → ambas suites completas en verde, sin regresiones

---

## Notes

- [P] = archivos distintos, sin dependencias pendientes
- [Story] mapea cada tarea a su historia de usuario para trazabilidad
- Verificar que los tests nuevos fallan antes de implementar (T013 antes de que T009 exista debería
  fallar por `ImportError`; T026/T029 antes de T025/T028 deberían fallar por el bloque equivocado)
- Commits solo cuando el usuario lo pida explícitamente (Principio XV)
- Detenerse en cada checkpoint para validar la historia de forma independiente
