# Implementation Plan: Autogestión de suscripciones y pago de la membresía por link de pago (Wompi)

**Branch**: `161-suscripcion-pago-wompi` | **Date**: 2026-11-17 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/161-suscripcion-pago-wompi/spec.md`

## Summary

Hoy un tenant cuyo plan vence se bloquea de inmediato, pero solo en la creación de recursos limitados y en los módulos que dependen del plan; renovar es siempre un acto manual del Super Admin. Esta funcionalidad le da al ADMIN del tenant un flujo propio: pedir un link de pago de Wompi por el valor mensual del plan, pagar, y que el sistema aplique solo la renovación, con alertas previas, 5 días de gracia y bloqueo total al agotarse.

Enfoque técnico, todo en `pos-backend` (no se toca el frontend ni la landing):

1. **Estado como función pura** (`app/core/subscription.py`): `activa / por_vencer / en_gracia / bloqueada` a partir de `plan_vence_en` y un `now` inyectable, con tramos exactos de 48 h y 120 h. Lo comparten `GET /plan`, el guard, `ensure_plan_not_expired`, el job de alertas y la validación del link.
2. **Guard global** en los dos puntos por donde pasa todo tenant (`get_tenant` y `resolve_tenant_by_id`), con exenciones por prefijo de ruta y un 403 con `code = "subscription_blocked"`. Una ruta nueva queda protegida por defecto.
3. **Link de pago por Web Checkout firmado** (`app/core/wompi.py`), sin llamadas externas: referencia propia `SKP-<uuid>`, firma de integridad SHA-256, vigencia de 24 h, un solo pendiente por tenant (bloqueo de fila + índice único parcial).
4. **Webhook público** (`POST /webhooks/wompi`) verificado por checksum, idempotente, que aplica el recálculo de fechas dentro de una transacción de la base compartida. Una tabla nueva `shared.subscription_payments` guarda el historial.
5. **Alertas con audiencia por rol**: una columna nullable `audience_role` en `notification_events` (extiende la spec 077 sin cambiar los eventos existentes), un canal en tiempo real por rol y filtros en listado, push y "atender"; un job periódico que emite el aviso del estado vigente una sola vez por ciclo.
6. **Historial** para el ADMIN y para el Super Admin, y un **script de gracia de una sola vez** para que los tenants ya vencidos no queden bloqueados de golpe al desplegar.

Sin cuenta de Wompi todavía, todo se valida con firmas calculadas en las pruebas; la prueba real contra Sandbox queda como tarea explícita pendiente.

## Technical Context

**Language/Version**: Python 3.14 (backend `pos-backend`). Sin cambios en `pos-heladeria`.

**Primary Dependencies**: FastAPI 0.136, SQLAlchemy 2 (ORM con `Mapped`), Alembic 1.18, Pydantic 2.13, APScheduler, Redis. **Sin dependencias nuevas** (Principio IX): firmas con `hashlib`/`hmac`, URL con `urllib.parse`, importes con `decimal`, fechas con `dateutil`, todo ya presente (`research.md` Decisión 18).

**Storage**: PostgreSQL 16, esquema por tenant más `shared`. Tabla nueva `shared.subscription_payments`; columna nueva `audience_role` y un índice parcial en `tenant.notification_events`. Detalle en [data-model.md](./data-model.md).

**Testing**: `unittest` sobre SQLite en memoria (`app/characterization_tests/`, `python -m unittest discover -s app/characterization_tests -p 'test_*.py'`). Pruebas nuevas `test_subscription_*.py` y `test_notifications_audience.py`; se amplían `plan_fixtures.py` y las pruebas de plan afectadas. La concurrencia real y la verificación contra Wompi no caben en SQLite: se cubren con [quickstart.md](./quickstart.md) y con la tarea de Sandbox pendiente.

**Target Platform**: Servidor Linux (API FastAPI con `uvicorn`, PostgreSQL, Redis, planificador APScheduler dentro de la API).

**Project Type**: Servicio web (solo backend; el frontend queda para otra spec).

**Performance Goals**: el guard global no agrega consultas (el `Tenant` ya está cargado) y cuesta una comparación de fechas; el link de pago responde en menos de 2 s en el percentil 95 (sin llamadas externas); el job de alertas recorre todos los tenants una vez por hora.

**Constraints**: estado y desbloqueo sin caché (se recalculan por petición, FR-009); el webhook debe responder `200` siempre que la firma sea válida para no provocar reintentos de Wompi; ningún secreto en respuestas ni registros; fechas en UTC naive como el resto del esquema compartido; migración solo aditiva y reversible.

**Scale/Scope**: del orden de decenas a pocos cientos de tenants; unos pocos pagos por tenant al año; un evento de Wompi por pago más sus reintentos. Alcance: ~25 archivos de `pos-backend` (ver estructura) y 4 contratos nuevos.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Estado | Evidencia |
|---|---|---|
| I. Nace de un spec | **PASS** | `spec.md` con 7 historias, 43 requisitos y 8 decisiones de negocio firmadas el 2026-11-17, antes de cualquier código. |
| II. Comportamiento existente protegido | **PASS con acción previa** | Cuatro cambios intencionales (gracia de 5 días, bloqueo total, `vencido` = bloqueada, audiencia en notificaciones) están listados en `spec.md § Cambios sobre comportamiento existente`. **Antes de implementar** se registran en `specs/000-reconocimiento/registro-de-anomalias.md` (último A-160), con quién y cuándo. |
| III. Characterization tests | **PASS con acción** | Las suites `CONGELA` que mencionan "expir" tratan de sesiones de mesa, no del plan. Se revisan `test_plan_expiration.py`, `test_plan_summary.py`, `test_module_not_in_plan_error.py`, `test_tenant_plan_assignment.py` y `test_invitations_create.py` (su prueba de plan vencido usa `−1 día`, que ahora es gracia); solo cambian las aserciones que choquen con la gracia, citando la decisión en el mismo commit. |
| IV. Nuevo comportamiento permitido por spec | **PASS** | Es nueva funcionalidad autorizada. |
| V. Sin refactorizaciones oportunistas | **PASS** | No se refactoriza `plan_limits.py` ni el módulo de notificaciones más allá de lo que la funcionalidad exige (reescribir `ensure_plan_not_expired`, añadir `_dispatch_once`, una columna y un canal por rol). |
| VI. Evolución incremental | **PASS** | DDL en una revisión; el cambio de datos (D8) en un script aparte; el guard, el link, el webhook, las alertas y el historial se entregan como unidades verificables por separado (fases abajo). |
| VII. Datos históricos inmutables | **PASS** | Los pagos de suscripción no tocan facturas ni ventas (FR-040). |
| VIII. Evolución del modelo de datos | **PASS** | [data-model.md](./data-model.md) fija tabla, columna, defaults, compatibilidad (todo aditivo, sin backfill), migración y reversión con sus riesgos. |
| IX. Dependencias | **PASS** | Ninguna nueva (`research.md` Decisión 18). |
| X. Verificación obligatoria | **PASS con límite declarado** | Pruebas automáticas más quickstart. La verificación contra Wompi Sandbox no es posible sin cuenta y queda como tarea abierta (FR-041); la funcionalidad no se da por verificada de punta a punta hasta cerrarla. |
| XI. Decisión de negocio vs técnica | **PASS** | Las ocho decisiones de negocio constan en `Clarifications`; las técnicas (canal por rol, ventana horaria, índices) están en `research.md`, y las que son supuestos del plan se marcan como tales. |
| XII. Trazabilidad | **PASS** | Necesidad → `spec.md` → decisiones → `research.md`/contratos → tareas (siguiente paso) → pruebas → `quickstart.md`. |
| XIII. Español de Colombia | **PASS** | Todos los artefactos en español de Colombia; solo los commits y las ramas van en inglés. |
| XIV. Rama por spec | **PASS (pendiente de ejecutar)** | Antes de tocar `pos-backend` se crea `feat/161-subscription-wompi-payment` desde `develop`. |
| XV. Commits | **PASS** | Solo cuando el usuario lo pida, pequeños, en inglés, Conventional Commits y sin marcas de IA. |

**Resultado**: sin violaciones que justificar. Dos acciones previas a implementar: registrar las anomalías (II) y resolver el estado de los dos archivos de migración sin versionar (research Decisión 14).

## Project Structure

### Documentation (this feature)

```text
specs/161-suscripcion-pago-wompi/
├── plan.md              # Este archivo (/speckit-plan)
├── research.md          # Fase 0: 18 decisiones técnicas
├── data-model.md        # Fase 1: tabla nueva, columna nueva, estados, migración y reversión
├── quickstart.md        # Fase 1: validación de punta a punta (+ lista de Sandbox pendiente)
├── contracts/
│   ├── subscription-api.md       # GET /plan, link, historial ADMIN y Super Admin
│   ├── wompi-webhook.md          # Link firmado, webhook, fórmulas y vectores
│   ├── blocked-access.md         # Guard global: 403, exentas, casos de prueba
│   └── notifications-audience.md # Audiencia por rol y avisos de suscripción
├── checklists/
│   └── requirements.md
└── tasks.md             # Fase 2 (/speckit-tasks — NO lo crea este comando)
```

### Source Code (`pos-backend`, repositorio hermano; rama `feat/161-subscription-wompi-payment` desde `develop`)

```text
pos-backend/
├── alembic/versions/
│   └── <id>_161_subscription_payments.py     # NUEVO  tabla shared + audience_role + índices (encadenar al head real)
├── app/
│   ├── core/
│   │   ├── subscription.py                   # NUEVO  estado puro: compute_subscription_status()
│   │   ├── subscription_guard.py             # NUEVO  enforce_subscription_access() + exentas
│   │   ├── wompi.py                          # NUEVO  firma de integridad, URL, checksum de evento
│   │   ├── exceptions.py                     # MOD    SubscriptionBlockedError, SubscriptionNotPayableError, PaymentGatewayNotConfiguredError
│   │   ├── error_middleware.py               # MOD    registrar los manejadores nuevos (junto a ModuleNotInPlanError)
│   │   ├── db.py                             # MOD    get_tenant / resolve_tenant_by_id invocan el guard
│   │   ├── plan_limits.py                    # MOD    ensure_plan_not_expired sobre el estado puro
│   │   ├── config.py                         # MOD    WOMPI_* y SUBSCRIPTION_ALERT_*
│   │   ├── events.py                         # MOD    staff_role_channel()
│   │   ├── scheduler.py                      # MOD    evaluate_subscription_alerts + lock + registro del job
│   │   └── notifications/
│   │       ├── dispatch.py                   # MOD    _dispatch_once + notify_subscription_{expiring,grace_started,blocked}
│   │       ├── summary.py                    # MOD    resumen de los 3 tipos
│   │       └── channels/{in_app.py,browser_push.py}   # MOD  canal y filtro por audiencia
│   ├── models/
│   │   ├── subscription_payment.py           # NUEVO  shared.subscription_payments
│   │   ├── notification_event.py             # MOD    audience_role
│   │   └── __init__.py                       # MOD    registrar el modelo nuevo
│   ├── api/v1/
│   │   ├── plan/{router.py,schemas.py,service.py}   # MOD  campos nuevos de GET /plan + rutas /plan/subscription/*
│   │   ├── plan/subscription_service.py      # NUEVO  link, reutilización, historial, aplicar pago aprobado
│   │   ├── webhooks/{__init__.py,router.py}  # NUEVO  POST /webhooks/wompi
│   │   ├── super_admin/subscription_payments_router.py  # NUEVO  historial por tenant (se incluye en el router de Super Admin)
│   │   ├── notifications/router.py           # MOD    filtro de audiencia en listado y atender
│   │   └── realtime/{auth.py,router.py}      # MOD    rol en el ticket; suscripción a staff:<rol>
│   ├── scripts/grant_subscription_grace.py   # NUEVO  gracia de una sola vez (D8)
│   └── main.py                               # MOD    incluir el router de webhooks
├── .env.example                              # MOD    variables nuevas, sin valores reales
└── app/characterization_tests/
    ├── plan_fixtures.py                      # MOD    agregar subscription_payments a _TABLE_NAMES
    ├── test_subscription_state.py            # NUEVO  fronteras exactas, SC-001
    ├── test_subscription_guard.py            # NUEVO  gracia, bloqueo, exentas, QR
    ├── test_subscription_wompi.py            # NUEVO  firma de integridad (vector verificado), checksum
    ├── test_subscription_payment_link.py     # NUEVO  reutilización, 409/503, solo ADMIN
    ├── test_subscription_webhook.py          # NUEVO  matriz de estados, idempotencia, recálculo
    ├── test_subscription_alerts.py           # NUEVO  una vez por ciclo, ventana, reanudación
    ├── test_subscription_history.py          # NUEVO  aislamiento, paginación, Super Admin
    ├── test_subscription_grace_script.py     # NUEVO  D8 e idempotencia
    ├── test_notifications_audience.py        # NUEVO  listado, atender, canal por rol, push
    └── test_plan_expiration.py / test_plan_summary.py / …   # MOD  solo lo que choque con la gracia, citando la decisión
```

También en `pos-specs`: registrar las entradas de anomalías en `specs/000-reconocimiento/registro-de-anomalias.md` antes de implementar.

**Structure Decision**: aplicación FastAPI existente, estructura por módulo en `app/api/v1/<modulo>/` con lógica transversal en `app/core/`; se respeta ese patrón. Las pruebas van en `app/characterization_tests/`, donde ya viven las de "nueva funcionalidad" de planes (precedente: `test_plan_expiration.py`).

## Fases de implementación (guía para `/speckit-tasks`)

Cada fase es verificable por sí sola y, salvo la A, no depende de Wompi.

| Fase | Entrega | Historias | Depende de |
|---|---|---|---|
| **A. Preparación** | Registrar anomalías, rama en `pos-backend`, resolver el estado de las migraciones sin versionar, variables en `Settings` y `.env.example` | — | — |
| **B. Estado y bloqueo** | `subscription.py`, `GET /plan` ampliado, guard global, errores tipados, `ensure_plan_not_expired` reescrita | US1, US2 | A |
| **C. Modelo y migración** | Modelo `SubscriptionPayment`, `audience_role`, revisión de Alembic, `plan_fixtures` | (base) | A |
| **D. Link de pago** | `wompi.py` (firma/URL), servicio y endpoint del link, reutilización, 409/503 | US3 | B, C |
| **E. Webhook** | Verificación de checksum, matriz de estados, recálculo, idempotencia | US4 | D |
| **F. Audiencia y alertas** | `audience_role` en listado/atender/SSE/push, `notify_subscription_*`, job periódico, expiración de pendientes | US5 | C |
| **G. Historial** | Endpoint del ADMIN y del Super Admin | US6 | C |
| **H. Despliegue** | Script de gracia, pruebas de regresión, quickstart completo | US7 | B–G |
| **I. Sandbox (pendiente)** | Lista de la sección 10 del quickstart cuando exista la cuenta | FR-041 | cuenta de Wompi |

B, C y F/G pueden avanzar en paralelo una vez cerrada A; D y E dependen del estado y del modelo.

## Riesgos y supuestos del plan (a confirmar)

| # | Riesgo o supuesto | Mitigación / quién decide |
|---|---|---|
| R1 | Desplegar antes de tener cuenta de Wompi deja a un tenant que venza sin forma de pagar y, a los 5 días, bloqueado (solo el Super Admin podría renovarlo). | No activar en producción hasta tener llaves, o correr el script de gracia el día que se configuren (`research.md` Decisión 13). Un interruptor "solo registrar" queda descartado salvo que el negocio lo pida. |
| R2 | La ventana horaria local 8–20 para emitir avisos es una decisión del plan para dar contenido a FR-030. | Configurable; `0` y `24` la desactivan. Confirmar con el negocio. |
| R3 | `vencido` pasa a significar "bloqueada" para no anular la gracia en el frontend. | Derivado de la regla de gracia; ya consta en la spec como "confirmar en revisión". |
| R4 | La conexión en tiempo real del staff queda exenta del bloqueo para que el ADMIN reciba el aviso en vivo. | Supuesto ya registrado en la spec. |
| R5 | La fórmula del checksum de eventos no se pudo comprobar: el ejemplo numérico de la documentación no reproduce con su propia cadena. Si la fórmula real difiere, el webhook rechazaría todo (falla cerrado, sin riesgo de aprobar de más). | Se verifica con el primer evento real de Sandbox (quickstart § 10). Hasta entonces, no se da por probado. |
| R6 | Que Wompi permita reintentar tras un `DECLINED` con la misma referencia no está confirmado; la matriz acepta `rejected → approved` por si ocurre. | Inocuo si no ocurre; se confirma en Sandbox. |
| R7 | La spec 162 (documentos legales) trae 3 migraciones propias; sin re-encadenar, las dos de la 161 serían una segunda cabeza. Además, 2 archivos de fusión locales sin versionar dejan la base de desarrollo estampada en una revisión que dejará de existir. | **Resuelto el 2026-11-19**: la 161 cuelga ahora de `b1c9f4e7a3d2` (cadena lineal, una cabeza); ensayado el procedimiento completo tras el pull sobre una copia de la base (`alembic stamp --purge 8d09a031cba3` + `alembic upgrade head`). Falta ejecutarlo en la base real, que es decisión del usuario (T079). |
| R8 | El script D8 mueve `plan_vence_en` de los tenants vencidos al `cutoff`, perdiendo el valor histórico (queda en la salida del script). | Decisión documentada en `research.md` Decisión 13; el valor anterior es operativo, no contable. |

## Complexity Tracking

Sin violaciones de la constitución; no hay nada que justificar en esta tabla.

## Post-design Constitution Check

Re-evaluado después de la fase 1 (`data-model.md`, `contracts/`, `quickstart.md`): **sin cambios respecto al chequeo inicial**. El diseño no introdujo dependencias, no toca datos históricos ni facturas, mantiene la migración aditiva y reversible, y deja explícitas las dos acciones previas (anomalías y migraciones sin versionar) y la verificación pendiente con Wompi.
