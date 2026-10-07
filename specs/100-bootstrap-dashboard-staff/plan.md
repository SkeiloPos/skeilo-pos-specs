# Implementation Plan: Carga agregada (bootstrap) del panel de staff al iniciar sesión

**Branch**: `100-bootstrap-dashboard-staff` | **Date**: 2026-10-07 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/100-bootstrap-dashboard-staff/spec.md`

## Summary

Hoy `DashboardLayoutComponent.ngOnInit()` (`pos-heladeria/src/app/modules/dashboard/layout/dashboard-layout.component.ts:110-118`)
dispara en paralelo `TenantInfoService.load()` (`GET /tenant`) y `PlanSummaryService.load()`
(`GET /plan`), mientras que `NotificationCenterService` (inyectado como efecto colateral desde
`HeaderComponent`, mismo shell) dispara por su cuenta `GET /notifications?page=1&size=20` en su
método privado `bootstrap()` (`notification-center.service.ts:71-88`) — tres peticiones HTTP
independientes para pintar el panel. Esta funcionalidad agrega un único endpoint
`GET /api/v1/bootstrap` que compone esos tres bloques en una sola respuesta, y refactoriza el
shell para consumirlo: `DashboardLayoutComponent` llama una vez al nuevo `BootstrapService`, que
reparte cada bloque a los tres servicios existentes mediante un método nuevo `hydrate()` que fija
su estado sin disparar HTTP propio. El ticket de tiempo real (`POST /realtime/ticket`, línea 117
del mismo componente) queda explícitamente fuera y sin cambios (FR-004). Para Super Admin — que
hoy no tiene ninguna fila `Tenant` con `host='admin'`, por lo que `GET /tenant`/`GET /plan` ya
responden `404` y ese error se traga en silencio en el frontend — el nuevo endpoint reemplaza ese
`404` tragado por un `200` explícito con los bloques `tenant`/`plan` (y `notifications`, por la
misma razón: es tenant-scoped) en `null` (FR-007), vía una dependencia nueva que resuelve el
tenant de forma opcional en lugar de lanzar `404`.

## Technical Context

**Language/Version**: Backend: Python 3.11+ (FastAPI, SQLAlchemy 2.0). Frontend: TypeScript 5.9 /
Angular 21 (standalone components, signals).

**Primary Dependencies**: Ninguna nueva. Backend: reutiliza FastAPI (`APIRouter`, `Depends`) y los
schemas Pydantic ya existentes (`TenantInfoResponse`, `PlanSummaryResponse`,
`NotificationListResponse`). Frontend: `HttpClient` + signals, mismo patrón que
`TenantInfoService`/`PlanSummaryService`/`NotificationCenterService` ya usan.

**Storage**: PostgreSQL 16, schema-per-tenant (`schema_translate_map`) para los bloques
tenant/plan/notifications; schema `shared` para resolver al usuario autenticado
(`get_authenticated_user`, `app/core/dependencies.py:273-299`) sin exigir que el tenant exista. Sin
migraciones — el endpoint no persiste nada nuevo (spec.md, Key Entities).

**Testing**: Backend: `unittest` vía `python -m unittest discover -s app/characterization_tests -p
'test_*.py' -v` (README.md:207) — **no `pytest`**; los tests llaman las funciones del router
directamente, sin `TestClient`. Frontend: Vitest vía `ng test` (builder `@angular/build:unit-test`
de Angular 21, no Karma/Jasmine), `TestBed` + `provideHttpClientTesting`/`HttpTestingController`,
mismo patrón que `tenant-info.service.spec.ts`.

**Target Platform**: Servidor Linux (backend, ya en producción) + navegador (frontend Angular, ya
en producción).

**Project Type**: Web application — dos repositorios ya existentes (`pos-backend` +
`pos-heladeria`), sin estructura nueva de alto nivel.

**Performance Goals**: Reducir de 3 peticiones HTTP (o más, contando el 404 silencioso de Super
Admin) a 1 sola petición para obtener negocio + plan + notificaciones recientes al iniciar sesión
(SC-001). No se fija un objetivo de latencia numérico nuevo: la composición reutiliza las mismas
consultas que hoy hacen las 3 fuentes por separado, solo en un único request/response.

**Constraints**: Debe responder `200` incluso cuando tenant/plan no aplican (Super Admin, FR-007)
o cuando solo una fuente interna falla (FR-006, degradación granular); el frontend no debe
reintentar automáticamente las peticiones individuales dentro de la misma carga si el `/bootstrap`
completo falla (FR-005); el ticket de tiempo real no se incluye (FR-004); la forma de cada bloque
no cambia respecto a su endpoint individual (Assumptions de spec.md).

**Scale/Scope**: 1 endpoint nuevo (`GET /api/v1/bootstrap`) + 2 dependencias nuevas en el backend
(`get_optional_tenant`, `get_optional_db`) + 1 helper extraído en `db.py` (`find_tenant_by_host`);
1 servicio nuevo (`BootstrapService`) + 3 métodos `hydrate()` nuevos + 1 ajuste de refactor
acotado en 2 archivos frontend (`dashboard-layout.component.ts`,
`notification-center.service.ts`). Sin nuevas entidades persistidas, sin nuevas dependencias de
terceros.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Evaluado contra `.specify/memory/constitution.md` v4.0.0 (fase de Evolución Funcional):

- **I. Nace de un spec** ✅ — `specs/100-bootstrap-dashboard-staff/spec.md`, con `## Clarifications`
  resolviendo las 3 decisiones de negocio sin default obvio (fallo total, degradación parcial,
  contenido del bloque de notificaciones).
- **II. Comportamiento existente protegido** ✅ — `GET /tenant`, `GET /plan` y `GET /notifications`
  individuales no cambian (FR-003); el endpoint nuevo es un punto de entrada que no existía, por lo
  que su propio comportamiento (`200` con bloques `null` para Super Admin) no es un "cambio" de
  nada preexistente — no se requiere entrada en `registro-de-anomalias.md`. El único efecto
  observable sobre comportamiento existente es que el panel deja de disparar 3 peticiones
  separadas al iniciar sesión (justamente lo que el spec pide cambiar, FR-001/FR-002).
- **III. Characterization tests** ✅ (a verificar en Phase 0) — ningún test
  `"CONGELA comportamiento actual:"` conocido cubre hoy el `ngOnInit` del shell ni el `bootstrap()`
  de `NotificationCenterService` (son comportamiento de frontend, los characterization tests viven
  en `app/characterization_tests/` del backend); research.md incluye una verificación explícita de
  que ninguno referencia los endpoints `/tenant`, `/plan`, `/notifications` de una forma que este
  cambio pudiera romper.
- **IV. Nuevo comportamiento vía spec** ✅ — el endpoint agregador y los bloques `null`/vacío para
  Super Admin son comportamiento nuevo explícitamente definido por FR-001 a FR-009.
- **V. Sin refactorizaciones oportunistas** ✅ — el alcance se limita a los 2 archivos que el ticket
  original ya señala (`dashboard-layout.component.ts`, `notification-center.service.ts`) más los 2
  servicios que ganan `hydrate()`; no se toca nada de `TenantInfoService`/`PlanSummaryService` más
  allá de ese método nuevo, ni se reordena el resto del shell.
- **VI. Evolución incremental** ✅ — una sola unidad verificable: 1 endpoint + su consumo en el
  frontend, sin migraciones, sin cambios de arquitectura adicionales.
- **VII. Compatibilidad con datos históricos** — N/A, no hay facturas ni datos históricos
  involucrados.
- **VIII. Evolución del modelo de datos** — N/A, no se agregan entidades ni columnas (spec.md, Key
  Entities: "No introduce datos nuevos ni persistentes").
- **IX. Dependencias nuevas** — N/A, no se agrega ninguna dependencia de terceros en ningún repo.
- **X. Verificación obligatoria** ✅ (a completar en implementación) — tests backend (`unittest`,
  nuevo `test_bootstrap.py`) + tests frontend (`bootstrap.service.spec.ts`,
  `notification-center.service.spec.ts` actualizado) + recorrido manual de `quickstart.md` por los
  3 escenarios de aceptación del spec.
- **XI. Negocio vs técnico** ✅ — las decisiones de negocio ya están resueltas en
  `## Clarifications` de spec.md; este plan solo fija decisiones técnicas (ver research.md).
- **XII. Trazabilidad** ✅ — spec.md → este plan.md → tasks.md (siguiente comando) →
  implementación → tests → quickstart.md.
- **XIII. Español de Colombia** ✅ — todos los artefactos de esta fase (este plan, research.md,
  data-model.md, contracts/, quickstart.md) en español de Colombia.
- **XIV. Estrategia de ramas** — no aplica todavía: esta fase solo escribe en `pos-specs` (rama
  `main`, igual que el resto de specs de este repo). Al iniciar la implementación en `pos-backend`
  y `pos-heladeria`, corresponde crear `feat/100-bootstrap-dashboard-staff` en cada uno antes de
  tocar código.
- **XV. Política de commits** — no aplica en esta fase (no se genera código todavía); se recuerda
  para la fase de implementación: commits pequeños, en inglés, sin atribución de IA, solo cuando el
  usuario lo pida explícitamente.

**Resultado**: sin violaciones. No se requiere la tabla de Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/100-bootstrap-dashboard-staff/
├── plan.md              # Este archivo
├── research.md          # Fase 0
├── data-model.md         # Fase 1
├── quickstart.md         # Fase 1
└── contracts/
    └── bootstrap-endpoint.md   # Fase 1
```

### Source Code (dos repositorios hermanos, fuera de `pos-specs`)

```text
../pos-backend/app/api/v1/bootstrap/        # nuevo
├── router.py             # GET /bootstrap
├── schemas.py            # BootstrapResponse
└── service.py            # build_bootstrap(db, tenant) — composición + degradación granular

../pos-backend/app/core/db.py               # + find_tenant_by_host (helper extraído de get_tenant(), sin cambiar su comportamiento)
../pos-backend/app/core/dependencies.py     # + get_optional_tenant (usa find_tenant_by_host, sin levantar 404) + get_optional_db (espejo de get_db, tolerante a tenant=None)
../pos-backend/app/main.py                  # + include_router(bootstrap_router, prefix="/api/v1")

../pos-heladeria/src/app/core/bootstrap/    # nuevo
└── bootstrap.service.ts  # BootstrapService.load() → GET /bootstrap, reparte a hydrate()

../pos-heladeria/src/app/core/tenant/tenant-info.service.ts                      # + hydrate()
../pos-heladeria/src/app/modules/plan/services/plan-summary.service.ts          # + hydrate()
../pos-heladeria/src/app/core/notifications/notification-center.service.ts      # + hydrate(), guarda de una sola ejecución
../pos-heladeria/src/app/modules/dashboard/layout/dashboard-layout.component.ts # refactor de ngOnInit (líneas 110-118)
```

**Structure Decision**: Web application de dos repositorios ya existentes y en producción
(`pos-backend`, `pos-heladeria`), según el alcance fijado por la constitución del proyecto. No se
introduce ninguna carpeta de alto nivel nueva: el backend agrega un módulo `bootstrap/` siguiendo
exactamente el mismo patrón de un router por recurso que ya usan `tenant/`, `plan/` y
`notifications/`; el frontend agrega un módulo `core/bootstrap/` siguiendo el mismo patrón que
`core/tenant/`, `core/notifications/` y `core/realtime/`.

## Complexity Tracking

*Sin violaciones de la Constitution Check — tabla no aplica.*
