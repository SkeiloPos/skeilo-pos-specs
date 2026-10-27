# Implementation Plan: Soporte de zonas horarias por tenant sin desfases

**Branch**: `138-soporte-zona-horaria-tenant` (specs) · código: `fix/138-tenant-timezone-support` en `pos-backend` y en `pos-heladeria`, creadas desde `develop` antes de tocar código (Principio XIV) | **Date**: 2026-10-25 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/138-soporte-zona-horaria-tenant/spec.md`

## Summary

La spec 138 cierra la deuda que dejaron las specs 022, 023, 030 y 127: el mecanismo de zona horaria por tenant ya existe,
pero hay lugares que no lo usan. La investigación ([research.md](./research.md)) **reconfirmó con ejecución real** cada
hallazgo y encontró tres cosas que la spec no tenía:

1. **El defecto C ya rompe una prueba hoy**: entre las 19:00 y las 24:00 de Bogotá, la suite del backend falla en el
   «segundo rechazo del día».
2. **`connect_args={"options": "-c timezone=UTC"}` no funciona** contra `PGTZ`; la sesión se fuerza con un **evento
   `connect`** (`SET TIME ZONE 'UTC'`), medido contra PostgreSQL real.
3. El inventario de instantes sin offset sale del **esquema OpenAPI** y es de **16 esquemas / 24 campos**, no la lista de
   `hallazgos.md` (faltaban `PaymentMethodCatalogResponse` y `PlanResponse`).

Enfoque técnico, mínimo y sin dependencias nuevas: (backend) forzar la sesión a UTC y unificar la forma de escribir
instantes con `utc_now_naive()`; enhebrar el `tenant` a las 8 funciones que contienen las llamadas sin tenant (más 2 reenviadoras) para evaluar promociones en su zona;
usar `business_today(tenant)` donde hoy se usa el día UTC; ampliar `UtcDatetime` a 13 definiciones; validar la zona IANA
también en la base de datos con un **disparador** y capturarla en el alta de tenant; y hacer que el correo use la zona del
tenant conservando «(hora de Colombia)» para Bogotá. (Frontend) un único módulo de presentación (`Intl`, ya usado por el
proyecto) y `TenantDatePipe` extendido, aplicado a 21 sitios; el menú público y la lista de tenants entregan la zona
(campos aditivos). Verificaciones automáticas en ambos lados impiden que la deuda vuelva, y las suites se ejecutan con la
zona del sistema forzada a Tokio y a UTC.

**Qué cambia para un tenant de Bogotá** (FR-013): nada, salvo dos excepciones ya registradas y **pendientes de
ratificación con el negocio** — A-147 (día de negocio 19:00–24:00: segundo rechazo y nombre del archivo de inventario) y
A-148 (instantes sin offset: «agotado desde hace…» y «Enviada el…» dejan de estar 5 h desfasados).

## Technical Context

**Language/Version**: Backend: Python 3.12 (`Dockerfile` y CI; el entorno local usa 3.14), FastAPI 0.136, SQLAlchemy 2.0,
Pydantic 2.13, Alembic 1.18, psycopg 3.3. Frontend: TypeScript ~5.9 / Angular ^21.1 (componentes standalone, signals).

**Primary Dependencies**: **Ninguna nueva** (Principio IX). Backend: `zoneinfo` + `tzdata==2026.2` (ya en
`requirements.txt`). Frontend: `Intl.DateTimeFormat` con `timeZone`; `date-fns-tz`/`luxon`/`dayjs` no están en
`package.json` y no se justifican. Se reutiliza el mecanismo central de las specs 022/023/030/127 (`app/core/timezone.py`,
`TenantDatePipe`, `businessToday`).

**Storage**: PostgreSQL 16 (producción `postgres:16.10`; desarrollo 16.14), esquema por tenant. **Un solo cambio de
esquema**: un disparador de validación sobre `shared.tenants.timezone` (migración Alembic nueva, sobre `shared`, con
`downgrade`). Sin cambio de tipo de columna, sin migración de datos. Detalle en [data-model.md](./data-model.md).

**Testing**: Backend: `python -m unittest discover -s app/characterization_tests -p 'test_*.py'` (SQLite en memoria; 1905
pruebas, ~110 s) más `python -m app.scripts.test_promotions_rules`. Frontend: `ng test` (vitest 4 vía
`@angular/build:unit-test`). Verificación contra PostgreSQL real con `app/scripts/verify_timezone_storage.py` y
`psql` en `BEGIN … ROLLBACK`. Las suites se corren además con `TZ=Asia/Tokyo` y `TZ=UTC` (FR-012).

**Target Platform**: API web (FastAPI, contenedor Docker en VPS) + aplicación web POS (Angular PWA) — ambos en
producción.

**Project Type**: Aplicación web con backend y frontend ya existentes (`pos-backend`, `pos-heladeria`) más el repositorio de
especificaciones (`pos-specs`). Es **corrección de comportamiento existente y deuda técnica** (Principios II y III), no
funcionalidad nueva.

**Performance Goals**: N/A. Sin cambio de complejidad algorítmica: el `tenant` que se enhebra ya está resuelto por
`get_tenant` (FastAPI lo cachea por petición, no hay consultas nuevas); `UtcDatetime` es una conversión trivial; el
disparador solo se ejecuta al insertar o actualizar `timezone` en `shared.tenants` (operaciones raras).

**Constraints**: Un tenant de Bogotá no debe ver cambios salvo A-147/A-148 (FR-013). Datos históricos intactos
(Principio VII). Despliegue sin ventana de horas desplazadas: backend primero, compatible hacia atrás (research
Decisión 16). Los tests `"CONGELA comportamiento actual:"` de correo no se modifican.

**Scale/Scope**: 2 repositorios de código + specs. Backend: ~13 módulos de esquemas, 8 sitios de `auto_discount` (8 funciones
que los contienen + 2 reenviadoras = 10 firmas), 38 sitios de escritura de instantes, 1 migración, 1 script nuevo, 8 archivos de pruebas nuevos y 2 corregidos. Frontend: 21
sitios (ver [contracts/frontend-fechas.md](./contracts/frontend-fechas.md)), 1 formulario, 2 pruebas de guarda/paridad.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Evaluación inicial | Evaluación tras el diseño |
|---|---|---|
| **I** — Todo nace de un spec | ✅ Existe [spec.md](./spec.md) con alcance, reglas, escenarios y criterios | ✅ Cada decisión de [research.md](./research.md) cita el FR que la origina |
| **II / XI** — Cambio de comportamiento = decisión registrada | ⚠ A-147/A-148/A-149 registradas en `registro-de-anomalias.md` (sin commit) y **pendientes de ratificación con el negocio** | ⚠ Igual. Además el inventario de A-148 queda incompleto (faltan 2 esquemas y `closed_by_refactor_at`): **tarea de actualización** antes de implementar. No bloquea: la decisión la tomó el equipo de desarrollo y la spec lo declara. Las dos excepciones viajan en **commits propios y revertibles** (regla en tasks.md) por si el negocio no las ratifica (T099) |
| **III** — Los tests `CONGELA` no se tocan | ✅ Los 3 archivos de correo fijan «(hora de Colombia)» | ✅ `formatear_fecha_hora_colombia` se conserva como envoltorio de Bogotá: **0 pruebas protegidas modificadas**. Las 2 pruebas dependientes de la zona que se corrigen no llevan prefijo `CONGELA` (verificado). `session_bill` declara `tenant: Annotated[Tenant, Depends(get_tenant)] = None` para que el test protegido que lo invoca directo siga pasando sin tocarlo (T041) |
| **IV** — Los specs pueden introducir comportamiento | ✅ | ✅ |
| **V** — Sin refactorizaciones oportunistas | ✅ | ✅ `utc_now_naive()` y `business_today` en el módulo central son lo que exigen FR-005 y FR-007; no se reordena nada más. El alias en `cash/reports.py` evita tocar a sus llamadores |
| **VI** — Evolución incremental | ✅ | ✅ Siete incrementos verificables (abajo), cada uno con su suite en verde y commits pequeños |
| **VII** — Datos históricos inmutables | ✅ Sin migración de datos | ✅ La migración es solo DDL (disparador) y, si hay datos inválidos, **se omite con una advertencia** en vez de corregirlos (ni abortar el arranque del API). La corrección de datos, si hiciera falta, va en spec aparte |
| **VIII** — Evolución del modelo de datos | ✅ Un cambio de esquema | ✅ Especificado en [data-model.md](./data-model.md): objeto nuevo, compatibilidad con datos existentes (pre-chequeo), idempotencia y `downgrade` |
| **IX** — Dependencias | ✅ Ninguna nueva | ✅ `Intl` y `zoneinfo` bastan; se justifica en research Decisión 10 |
| **X** — Verificación obligatoria | ✅ | ✅ Pruebas por historia, guardas automáticas, verificación en PostgreSQL real y matriz de zonas (quickstart Q1–Q10) |
| **XII** — Trazabilidad | ✅ | ✅ Necesidad → spec → A-147/148/149 → research → tareas → pruebas (mapa en el quickstart) |
| **XIII** — Español de Colombia | ✅ | ✅ Documentos y comentarios en español; commits y ramas en inglés |
| **XIV** — Ramas | ✅ | ✅ `fix/138-tenant-timezone-support` por repositorio, desde `develop`, antes de tocar código |
| **XV** — Commits | ✅ | ✅ Solo cuando el usuario lo pida, pequeños, en inglés, sin marcas de IA |

**Resultado**: pasa. No hay violaciones sin justificar. La única observación abierta es la **ratificación del negocio**
de A-147/A-148, que la spec ya reconoce como pendiente (no bloqueante).

## Project Structure

### Documentation (this feature)

```text
specs/138-soporte-zona-horaria-tenant/
├── spec.md                          # Especificación (aclarada el 2026-10-25)
├── hallazgos.md                     # Evidencia de la spec (reconfirmada en research.md §R0)
├── plan.md                          # Este archivo
├── research.md                      # Fase 0: reconfirmación, 16 decisiones, línea base medida
├── data-model.md                    # Fase 1: disparador, reglas de almacenamiento, zona curada, DTO
├── quickstart.md                    # Fase 1: escenarios de validación Q1–Q10
├── contracts/
│   ├── instantes-api.md             # Inventario definitivo de 16 esquemas, excepciones, verificación OpenAPI
│   ├── zona-horaria-tenant.md       # Alta de tenant, lista, menú, correo, script de soporte
│   └── frontend-fechas.md           # API compartida de presentación, 21 sitios, guarda
├── checklists/requirements.md
└── tasks.md                         # Fase 2 (/speckit-tasks — NO lo crea este comando)
```

### Source Code (repository root)

```text
pos-backend/
├── alembic/versions/
│   └── <hash>_138_tenant_timezone_trigger.py        # NUEVA — disparador en shared.tenants; down_revision = c5815ab62693 (era c3d9a1f08b42 al planificar)
├── app/core/
│   ├── timezone.py                                  # + utc_now_naive, business_today, validate_iana_timezone,
│   │                                                #   ZONAS_CURADAS, etiqueta_zona_correo
│   ├── db.py                                        # + force_utc_session (evento connect); tenant_create(timezone=) y traducción 22023 → 422
│   ├── models.py                                    # Tenant.timezone usa validate_iana_timezone
│   └── mail_templates/
│       ├── _campos.py                               # + formatear_fecha_hora(momento, zona); colombia = envoltorio
│       └── contrasena_cambiada.py                   # + zona_horaria
├── app/api/v1/
│   ├── orders/{checkout.py,tables_advanced.py,router.py}      # tenant → auto_discount; business_today
│   ├── sales/{service.py,router.py}                           # tenant → checkout
│   ├── table_sessions/{service.py,router.py}                  # tenant → compute_bill/_close_*
│   ├── inventory/router.py                                    # nombre del export con el día local
│   ├── cash/{reports.py,router.py}                            # business_today → alias
│   ├── auth/routes.py                                         # zona del tenant en el correo
│   ├── super_admin/{schemas.py,router.py}                     # timezone en alta y en la lista
│   ├── menu/schemas.py                                        # timezone en MenuBusinessResponse
│   └── {categories,cart,invitations,table_sessions,presentations,products,promotions,
│        unit_measures,users}/schemas.py                       # UtcDatetime (13 definiciones)
├── app/scripts/
│   ├── verify_timezone_storage.py                   # NUEVO — compuerta y verificación en PostgreSQL real
│   └── set_tenant_timezone.py                       # + validador común y advertencia (FR-016)
├── app/characterization_tests/                      # NUEVAS: test_session_utc, test_instantes_forma_unica,
│                                                    #   test_contrato_instantes_api, test_promotions_tenant_timezone_paths,
│                                                    #   test_business_day_boundaries, test_tenant_timezone_validation,
│                                                    #   test_zonas_curadas, test_correo_zona_horaria
│                                                    # CORREGIDAS (zona de la máquina): test_auth_session_revocation,
│                                                    #   test_table_sessions_router
└── .github/workflows/deploy.yml                     # + paso de la suite con TZ=Asia/Tokyo

pos-heladeria/src/app/
├── shared/
│   ├── date-format.util.ts                          # + FALLBACK_TIMEZONE, zonedParts, formatInZone
│   ├── tenant-timezones.ts                          # NUEVO — las 7 zonas del selector
│   ├── date-usage.guard.spec.ts                     # NUEVO — guarda con node:fs
│   └── pipes/tenant-date.pipe.ts                    # + 3.er parámetro; sin DEFAULT_TIMEZONE
├── core/tenant/tenant-info.service.ts               # + timezone computado
└── modules/
    ├── tables/{services/receipt.util.ts,services/pos-terminal.store.ts,services/diner.service.ts,
    │           components/pos-terminal-header.component.ts,pages/public-menu.component.ts}
    ├── dashboard/{pages/admin-dashboard.component.ts,components/shift-sales-report-card.component.ts,
    │              layout/{header,tenant-header}.component.ts}
    ├── {plan,users,inventory,reports,settings,sales}/…
    ├── promotions/{pages/promotions-page.component.ts,services/{promotion.service.ts,promotion-pricing.util.ts}}
    └── super-admin/{components/tenant-form.component.ts,pages/tenants-page.component.ts,
                     interfaces/tenant.interface.ts}

pos-specs/
├── specs/000-reconocimiento/registro-de-anomalias.md  # completar A-148 (inventario definitivo) y A-149
└── docs-publicos/, srs/                               # revisar pasajes que describan horas (sin cambio de comportamiento)
```

**Structure Decision**: aplicación web con dos repositorios de código independientes y un repositorio de especificaciones;
se conserva la estructura real de cada uno. El cambio es transversal pero **no crea módulos nuevos**: añade funciones al
módulo central de zona horaria existente de cada lado y un script de verificación, siguiendo los precedentes del
proyecto (`verify_*_backfill.py`, parity specs de la spec 091).

## Incrementos de entrega (Principio VI)

Cada incremento termina con su suite en verde, se commitea en unidades pequeñas y puede revertirse solo. Orden de
dependencia estricto en el backend; el frontend va después. **Despliegue: compuerta 0 → backend (I1–I4) → frontend (I5–I6).**

| # | Incremento | Historias / FR | Repos | Cambio de comportamiento para Bogotá |
|---|---|---|---|---|
| **I1** | Almacenamiento en UTC: `force_utc_session`, `utc_now_naive`, sustitución de las 3 formas de escritura, guarda `ast`, `verify_timezone_storage` | US4 · FR-004, FR-005 | backend | Ninguno (producción ya está en UTC — compuerta 0) |
| **I2** | Reglas que dependen de la hora: `tenant` a 8 funciones + 2 reenviadoras, `business_today`, arreglo de `checkout.py:1423`, nombre del export de inventario, 2 pruebas defectuosas | US2, US3 · FR-006, FR-007 | backend | **A-147** (segundo rechazo 19:00–24:00; nombre del archivo) |
| **I3** | Contrato de instantes: `UtcDatetime` en 13 definiciones, prueba del OpenAPI, `timezone` en `TenantResponse` y `MenuBusinessResponse` | US1, US6 · FR-001–003 | backend | **A-148** («agotado desde hace…», «Enviada el…») |
| **I4** | Zona del tenant: `validate_iana_timezone`, `ZONAS_CURADAS`, alta con `timezone`, migración del disparador, correo por zona, script de soporte | US5 · FR-010, FR-011, FR-016 | backend | Ninguno (correo de Bogotá idéntico) |
| **I5** | Presentación en el frontend: módulo compartido, `TenantDatePipe`, los sitios 1–19 de la tabla del contrato, guarda `node:fs` | US1 · FR-008, FR-009 | frontend | Ninguno visible en Bogotá (salvo A-148 ya cubierto) |
| **I6** | Alta de tenant con zona en Super Admin (`<select>` obligatorio, paridad con la lista del backend) | US5 · FR-010 | frontend | Ninguno |
| **I7** | Red de seguridad y documentación: paso `TZ=Asia/Tokyo` en `deploy.yml`, matriz Q1, A-148 completo, A-149, revisión de `docs-publicos`/`srs` | US6 · FR-012, FR-014 | todos | Ninguno |

Las pruebas de cada incremento se escriben **primero** (rojas) donde el defecto es reproducible: el «segundo rechazo»
(I2), el detector del OpenAPI con un campo sin offset (I3), la sesión de `PGTZ` hostil (I1).

## Complexity Tracking

Sin violaciones de la constitución. Las siguientes decisiones añaden un objeto o un mecanismo nuevo y se justifican aquí
para que `/speckit-tasks` y la revisión no las lean como complejidad accidental:

| Decisión | Por qué es necesaria | Alternativa más simple descartada porque… |
|---|---|---|
| Disparador de validación en `shared.tenants` (objeto de base de datos nuevo) | FR-010 exige validar «también en la base de datos», contra la base IANA del propio motor | Un `CHECK` no admite subconsultas a `pg_timezone_names`; una función `IMMUTABLE` que consulte el catálogo miente sobre su inmutabilidad; validar solo en la aplicación incumple el requisito |
| Lista curada duplicada (backend y frontend) con prueba de paridad por lado | El correo necesita el nombre en español en el backend; el selector, en el frontend | Un endpoint para entregar siete filas estáticas agrega un contrato y una llamada; el proyecto ya resolvió exactamente esto con los subdominios reservados (spec 091) |
| Dos pruebas de guarda que leen fuentes (`ast` en Python, `node:fs` en el frontend) | FR-003 y FR-005 piden impedir que la deuda vuelva; el frontend no tiene linter ni CI | Un linter nuevo sería una dependencia; sin guarda, la próxima `toLocaleTimeString` reintroduce el defecto sin que nada falle (la línea base lo demuestra: las 154 pruebas pasan con el código incorrecto) |
| Evento `connect` en vez de `connect_args` | `options` no gana frente a `PGTZ` (medido) | — es la única opción que funcionó en las tres pruebas hostiles |

## Riesgos y pendientes

- **Compuerta 0 (producción)**: no verificable desde el entorno de desarrollo. Si la sesión de producción no era UTC o hay
  una zona inválida, se pausa solo lo que depende de ello y la corrección de datos va en una spec aparte. En particular, la
  migración del disparador **no aborta** ante una zona inválida: lo omite y avisa, para que el backend arranque igual.
- **Ratificación de A-147/A-148** con el negocio: pendiente; el equipo de desarrollo la declaró como excepción a FR-013.
- **Regla de forma IANA más estricta que Python hoy** (rechaza `localtime`, `Factory`): ningún tenant existente la usa
  (desarrollo: 3 de 3 `America/Bogota`); el pre-chequeo de la migración lo confirma en producción.
- **`model_dump()` de esquemas con `UtcDatetime`** devuelve `str`: la suite completa lo detectará; se corrige en la prueba.
- **Suite del frontend con fallos preexistentes ajenos** (7 archivos): comparar siempre por nombre contra la línea base, y
  nunca correr a la vez la suite del backend.

## Siguiente paso

`tasks.md` generado (T001–T101) y analizado con `/speckit-analyze` (2026-10-25; ajustes aplicados). Siguiente paso: `/speckit-implement`.
