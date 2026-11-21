---

description: "Lista de tareas de la spec 161: autogestión de suscripciones y pago por link de Wompi"
---

# Tasks: Autogestión de suscripciones y pago de la membresía por link de pago (Wompi)

**Input**: Documentos de diseño en `/specs/161-suscripcion-pago-wompi/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/ (4 archivos), quickstart.md

**Repos**: la implementación ocurre solo en `../pos-backend` (FastAPI). `pos-heladeria` y `skeilo-pos-landing` **no** se tocan. Las rutas con prefijo `../pos-backend/` son del backend; las que empiezan por `specs/` son de este repo (`pos-specs`).

**Tests**: se incluyen tareas de prueba porque la spec lo exige (FR-041, SC-001 a SC-012) y la constitución pide verificación obligatoria (Principio X). Dentro de cada historia las pruebas se **escriben primero y deben fallar** antes de implementar (precedente: `test_plan_expiration.py`, spec 033). Corren con `unittest` sobre SQLite en memoria: `python -m unittest discover -s app/characterization_tests -p 'test_*.py' -v` desde `../pos-backend`.

**Sin cuenta de Wompi**: ninguna tarea fuera de la fase final depende de ella; las firmas se calculan en las pruebas (ver `contracts/wompi-webhook.md`). La fase 10 recoge la verificación real contra Sandbox, hoy **bloqueada**.

## Format: `[ID] [P?] [Story] Descripción`

- **[P]**: puede ejecutarse en paralelo (archivos distintos, sin dependencias pendientes)
- **[Story]**: historia de usuario de `spec.md` (US1..US7)
- Cada tarea termina con los requisitos de `spec.md` que cubre, entre paréntesis: `(FR-005 a FR-010)` es un rango, `(FR-001, FR-002; SC-001)` agrega criterios de éxito, y las tareas sin requisito funcional citan el principio que las origina (Principio XII, trazabilidad).
- Los identificadores de código van en `monoespaciado`; las descripciones, en español de Colombia (Principio XIII). Los commits y las ramas van en inglés y **solo cuando el usuario lo pida** (Principio XV).

## Orden de fases

Las historias P1 (US1–US4) cierran el ciclo completo de cobro; las P2 (US5–US7) lo complementan. Las fases siguen la prioridad de la spec, con una salvedad técnica: US2 (guard global) no depende de US1, pero **no debe activarse en producción sin llaves de Wompi** (plan, riesgo R1), así que su entrega a producción se coordina con la fase 10.

---

## Phase 1: Setup

**Purpose**: compromisos previos que la constitución y el plan exigen antes de escribir código.

- [X] T001 Registrar en `specs/000-reconocimiento/registro-de-anomalias.md` cuatro entradas nuevas a continuación de A-160, con el mismo formato (`### A-NNN — [DECISIÓN DE NEGOCIO — spec 161] …` y los bloques **Qué cambia**, **Por qué cambia**, **Quién y cuándo**), una por fila de la tabla «Cambios sobre comportamiento existente» de `spec.md`: A-161 período de gracia de 5 días (antes el bloqueo era inmediato al vencer), A-162 bloqueo total con `subscription_blocked` (antes solo creación de recursos y módulos del plan), A-163 `vencido` pasa a significar «bloqueada» (marcar como derivada, pendiente de confirmación del usuario) y A-164 audiencia por rol en `notification_events`. Decisión del usuario, 2026-11-17. Debe quedar hecho **antes** de T004 (Principio II) (FR-043)
- [X] T002 Decidir con el usuario qué hacer con las dos migraciones locales sin versionar `../pos-backend/alembic/versions/f2d755c229e8_fusionar_cabezas_de_inventario_y_.py` y `../pos-backend/alembic/versions/b0ba035937ba_merge_multiple_heads.py` (versionarlas o descartarlas), ejecutar `alembic heads` y `alembic current` contra la base de desarrollo y anotar en este archivo, bajo esta tarea, el `down_revision` real que usará T014 (el head versionado es `8d09a031cba3`). **Bloquea T014** (FR-036) — **Resuelta el 2026-11-19** (el usuario delegó la decisión): los dos archivos de fusión locales (`f2d755c229e8…`, `b0ba035937ba…`) eran fusiones vacías; no se tocaron ni se usaron como padre. Al integrar con la spec 162, la cadena de la 161 pasó a colgar de `b1c9f4e7a3d2` → una sola cabeza. El procedimiento tras el pull se ensayó sobre una copia de la base (`research.md` Decisión 14); aplicarlo a la base REAL queda en T079
- [X] T003 Crear la rama `feat/161-subscription-wompi-payment` en `../pos-backend` a partir de `develop` actualizada (Principio XIV) (Principio XIV)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: lo que casi todas las historias necesitan: configuración, el cálculo puro del estado, los errores tipados, el modelo y la migración.

**⚠️ CRITICAL**: ninguna historia puede empezar antes de cerrar esta fase.

- [X] T004 Agregar a `Settings` en `../pos-backend/app/core/config.py` las variables nuevas, todas **opcionales o con valor por defecto** para no romper el arranque ni las suites: `WOMPI_PUBLIC_KEY`, `WOMPI_INTEGRITY_SECRET` y `WOMPI_EVENTS_SECRET` (`Optional[str] = None`), `WOMPI_CHECKOUT_URL` (`https://checkout.wompi.co/p/`), `WOMPI_REDIRECT_URL_TEMPLATE` (`https://{host}/`), `WOMPI_LINK_TTL_HOURS` (24), `SUBSCRIPTION_ALERT_INTERVAL_MINUTES` (60), `SUBSCRIPTION_ALERT_LOCAL_START_HOUR` (8) y `SUBSCRIPTION_ALERT_LOCAL_END_HOUR` (20). Ver `research.md` Decisión 15 (FR-014, FR-015, FR-017, FR-030)
- [X] T005 [P] Documentar las mismas variables en `../pos-backend/.env.example`, sin valores reales (solo marcadores) y con un comentario de que los secretos nunca se versionan (FR-017)
- [X] T006 [P] Escribir primero `../pos-backend/app/characterization_tests/test_subscription_state.py` (debe fallar): una prueba por frontera de `research.md` Decisión 4 con `now` inyectado — `plan_vence_en` `NULL`, `vence−48 h−1 s` (activa), `vence−48 h` exacto (por_vencer), `vence−1 s` (por_vencer), `vence` exacto (en_gracia), `vence+119 h 59 min 59 s` (en_gracia), `vence+120 h` exacto (bloqueada) — y los valores de `dias_restantes` (redondeo hacia arriba; `0` si bloqueada; `None` sin vencimiento) y `fecha_limite_pago` (FR-001 a FR-003; SC-001)
- [X] T007 Crear `../pos-backend/app/core/subscription.py` con las constantes `ALERT_WINDOW = timedelta(hours=48)` y `GRACE_PERIOD = timedelta(hours=120)`, un `dataclass` `SubscriptionStatus(state, dias_restantes, fecha_limite_pago)` y la función pura `compute_subscription_status(plan_vence_en, now=None)` (UTC naive; `now` por defecto `utc_now_naive()`), de modo que pasen las pruebas de T006 (FR-001 a FR-003)
- [X] T008 [P] Escribir primero `../pos-backend/app/characterization_tests/test_subscription_errors.py` (debe fallar), siguiendo el patrón de `test_module_not_in_plan_error.py`: cada error tipado responde con el cuerpo de `contracts/` — `SubscriptionBlockedError` → 403 `{detail, code: "subscription_blocked"}` con «venci» en `detail`; `SubscriptionNotPayableError` → 409 `{detail, code: "subscription_not_payable", reason}`; `PaymentGatewayNotConfiguredError` → 503 `{detail, code: "payment_gateway_not_configured"}`; y siguen siendo `HTTPException` (los `except HTTPException` existentes los atrapan) (FR-007, FR-013, FR-017)
- [X] T009 Agregar en `../pos-backend/app/core/exceptions.py` las tres clases `SubscriptionBlockedError`, `SubscriptionNotPayableError` (con atributo `reason` ∈ `already_active`/`no_expiry`/`unsupported_cycle`/`no_price`) y `PaymentGatewayNotConfiguredError`, con el mismo estilo que `ModuleNotInPlanError` (`detail` siempre `str`, `code` como atributo de clase) (FR-007, FR-013, FR-017)
- [X] T010 Agregar en `../pos-backend/app/core/error_middleware.py` la función `register_subscription_error_handlers(app)` (un manejador por clase de T009, devolviendo `{detail, code[, reason]}`) y llamarla en `../pos-backend/app/main.py` justo después de `register_module_error_handler(app)` (FR-007, FR-013, FR-017)
- [X] T011 [P] Crear el modelo `SubscriptionPayment` en `../pos-backend/app/models/subscription_payment.py` con exactamente las columnas, `CHECK` e índices de `data-model.md § 2` (esquema `shared`; `gateway_reference` único; índices únicos parciales `ux__subscription_payments__tenant_id__pending` y `ux__subscription_payments__gateway_transaction_id` declarados con `postgresql_where` **y** `sqlite_where`; `requested_by_user_id` con `ON DELETE SET NULL`) y registrarlo en `../pos-backend/app/models/__init__.py` (FR-036)
- [X] T012 [P] Agregar la columna `audience_role` (`String(20)`, nullable) y el índice único parcial `ux__notification_events__subscription_once` (`(event_type, related_entity_id) WHERE event_type LIKE 'subscription.%'`, con `postgresql_where` y `sqlite_where`) al modelo en `../pos-backend/app/models/notification_event.py` (FR-029, FR-031, FR-037)
- [X] T013 [P] Extender `../pos-backend/app/characterization_tests/plan_fixtures.py`: agregar `subscription_payments` a `_TABLE_NAMES` y un auxiliar `make_subscription_payment(db, tenant, **kw)`; revisar cómo `test_notifications.py` arma la tabla `notification_events` en SQLite y dejar disponible esa misma tabla (y `push_subscriptions`) para las pruebas de la fase 7 (FR-041) — Hecha (2026-11-17): `subscription_payments`, `notification_events`, `notification_channel_preferences` y `push_subscriptions` en `_TABLE_NAMES`, y `new_session(multithreaded=…)` para las pruebas HTTP. El auxiliar `make_subscription_payment` no se creó: cada prueba arma sus pagos con su propio constructor local
- [X] T014 Crear la revisión de Alembic `../pos-backend/alembic/versions/<id>_161_subscription_payments.py` encadenada al `down_revision` decidido en T002: `upgrade` crea `shared.subscription_payments` (omitir si existe, con `_has_table` como la revisión 158) y, con `@for_each_tenant_schema`, agrega `audience_role` (`ADD COLUMN IF NOT EXISTS`) y el índice único parcial a `notification_events`; `downgrade` en orden inverso con guardas (`data-model.md § 6`). Una sola revisión, solo DDL (FR-036, FR-037) — Hecha en **dos** revisiones encadenadas: `e0230fd88635` (`shared.subscription_payments`) y `a65d3ff9da49` (`audience_role` + índice por esquema de tenant; su reversión borra antes los avisos con audiencia). Desde el 2026-11-19 cuelgan de `b1c9f4e7a3d2` (spec 162). Validadas en PostgreSQL 16 y ensayadas de punta a punta (T015, T064). **No aplicadas a la base real** (T079)
- [X] T015 Verificar la migración contra la base de desarrollo (según `quickstart.md § 0` y `§ 9`): `alembic heads` devuelve **un** head; `alembic upgrade head` crea la tabla y la columna en `tenant_default` y en cada esquema de tenant; `alembic downgrade -1` las elimina; `alembic upgrade head` las vuelve a crear. Inspeccionar con `psql` dentro de `BEGIN … ROLLBACK`. Anotar el resultado bajo esta tarea (FR-036, FR-037) — Ejecutada el 2026-11-19 sobre una COPIA de la base de desarrollo (`pos_sim161`, ya eliminada; tu base real no se tocó) con el árbol fusionado (spec 162 + 161), la app real, PostgreSQL y Redis reales y el simulador de eventos: upgrade de los 5 pasos (3 de la spec 162 y 2 de la 161), una sola cabeza (`a65d3ff9da49`), y conteos de datos idénticos a la base real en 8 tablas comparadas

**Checkpoint**: configuración, estado puro, errores, modelo y migración listos; las historias pueden empezar.

---

## Phase 3: User Story 1 - Conocer el estado de la suscripción del tenant (Priority: P1) 🎯

**Goal**: `GET /plan` informa el estado de suscripción, los días restantes y la fecha límite de pago, con `vencido` ajustado a «bloqueada».

**Independent Test**: con tenants cuyo vencimiento cae en cada tramo (y sin vencimiento), consultar el plan y comprobar `subscription_state`, `dias_restantes`, `fecha_limite_pago` y `vencido` (`quickstart.md § 2`).

### Tests for User Story 1 ⚠️ (escribir primero, deben fallar)

- [X] T016 [US1] Ampliar `../pos-backend/app/characterization_tests/test_plan_summary.py`: para cada tramo de la tabla de `quickstart.md § 2` comprobar los tres campos nuevos de `build_plan_summary`; `vencido` es `False` en gracia y `True` solo en bloqueada; sin vencimiento → `activa`, `dias_restantes` y `fecha_limite_pago` en `None`. Citar la decisión A-163 en un comentario (Principio III) (FR-002 a FR-004)

### Implementation for User Story 1

- [X] T017 [P] [US1] Agregar `subscription_state` (`Literal["activa","por_vencer","en_gracia","bloqueada"]`), `dias_restantes` (`Optional[int]`) y `fecha_limite_pago` (`Optional[UtcDatetime]`) a `PlanSummaryResponse` en `../pos-backend/app/api/v1/plan/schemas.py`, conservando `vencido` (FR-004)
- [X] T018 [US1] En `../pos-backend/app/api/v1/plan/service.py` hacer que `build_plan_summary` use `compute_subscription_status` para llenar los tres campos nuevos y para calcular `vencido = (estado == "bloqueada")`, sin tocar `resources` ni `modules` (FR-002, FR-004)
- [X] T019 [US1] Ejecutar `python -m unittest app.characterization_tests.test_plan_summary -v` y la tabla de `quickstart.md § 2` contra la API; confirmar que la respuesta coincide con `contracts/subscription-api.md § 1` (FR-004) — Ejecutada el 2026-11-19 sobre una COPIA de la base de desarrollo (`pos_sim161`, ya eliminada; tu base real no se tocó) con el árbol fusionado (spec 162 + 161), la app real, PostgreSQL y Redis reales y el simulador de eventos (sección A, 5 comprobaciones): `GET /plan` en cada tramo y sin vencimiento

**Checkpoint**: US1 funcional y verificable por sí sola.

---

## Phase 4: User Story 2 - Operar durante la gracia y bloqueo total al agotarse (Priority: P1)

**Goal**: durante la gracia todo opera; agotada la gracia, toda operación del tenant (personal y comensal por QR) responde `403 subscription_blocked`, salvo las exentas.

**Independent Test**: con un tenant en gracia, las operaciones de negocio funcionan; con el reloj pasado de las 120 h, las mismas y la carta pública responden `403` con el código, mientras login, `GET /plan`, suscripción y notificaciones siguen funcionando (`quickstart.md § 3`).

### Tests for User Story 2 ⚠️

- [X] T020 [US2] Escribir `../pos-backend/app/characterization_tests/test_subscription_guard.py` con los 7 casos de `contracts/blocked-access.md § 4`: gracia no bloquea; `bloqueada` bloquea con `code`; exentas (`/auth/*`, `/bootstrap`, `/plan`, `/notifications`, `/realtime`) pasan simulando `request.scope["route"].path_format`; fronteras `vence+119 h 59 min 59 s` y `vence+120 h`; `resolve_tenant_by_id` bloquea al comensal; `get_optional_tenant` no bloquea; tras mover `plan_vence_en` el desbloqueo es inmediato; y un caso HTTP (`TestClient` con `dependency_overrides`, patrón de `test_bootstrap.py`) en el que un tenant bloqueado recibe `403` con el cuerpo `{detail, code: "subscription_blocked"}` a través del manejador registrado (FR-005 a FR-010)
- [X] T021 [P] [US2] Actualizar `../pos-backend/app/characterization_tests/test_plan_expiration.py`: las pruebas de «vencido» usan hoy 45 días y siguen válidas; agregar las fronteras de la gracia (`+119 h` no bloquea, `+120 h` bloquea) y comprobar que el `403` conserva «venci» y ahora es `SubscriptionBlockedError`. Citar A-161 y A-162 en el comentario de cabecera (FR-005, FR-006, FR-043)
- [X] T022 [P] [US2] Revisar `../pos-backend/app/characterization_tests/test_module_not_in_plan_error.py` y `../pos-backend/app/characterization_tests/test_tenant_plan_assignment.py`: ajustar solo las aserciones que dependan de que el vencimiento bloquee de inmediato; dejar constancia en el comentario de cada cambio (decisión A-161, Principio III). Incluir `../pos-backend/app/characterization_tests/test_invitations_create.py` (`test_tenant_con_plan_vencido_es_403_sin_enviar_correo`, FR-018 de invitaciones): hoy usa `plan_vence_en = ahora − 1 día`, que con la gracia es `en_gracia` y ya no da 403; cambiarlo a `ahora − 6 días` (pasadas las 120 h) para conservar la intención y agregar una prueba hermana con `−1 día` que compruebe que la invitación **sí** se crea durante la gracia, citando A-161. Comprobar además que `test_tenant_plan_assignment.py` sigue verde **sin cambios** (la renovación manual del Super Admin convive con este flujo). No tocar ninguna prueba `CONGELA` (FR-039, FR-043)
- [X] T023 [US2] Crear `../pos-backend/app/core/subscription_guard.py` con `EXEMPT_PREFIXES = ("/auth", "/bootstrap", "/plan", "/notifications", "/realtime")`, un auxiliar que obtiene la ruta de `request.scope["route"].path_format` (con respaldo en `request.url.path`) y le quita `/api/v1`, y `enforce_subscription_access(tenant, request=None)` que lanza `SubscriptionBlockedError` solo si el estado es `bloqueada` y (`request is None` o la ruta no es exenta). Mismo mecanismo que `_enforce_mesero_scope` en `../pos-backend/app/core/dependencies.py` (FR-006, FR-008, FR-010)
- [X] T024 [US2] En `../pos-backend/app/core/db.py` invocar `enforce_subscription_access(tenant, req)` al final de `get_tenant` (después de `req.state.tenant_id = tenant.id`) y `enforce_subscription_access(tenant)` en `resolve_tenant_by_id` (sin `request`, sin exenciones). **No** invocarlo en `get_optional_tenant`. Cuidar el import para no crear un ciclo con `plan_limits.py` (FR-006, FR-009)
- [X] T025 [US2] Reescribir `ensure_plan_not_expired` en `../pos-backend/app/core/plan_limits.py` sobre `compute_subscription_status`: lanza `SubscriptionBlockedError` solo en `bloqueada` y sigue sin hacer nada con `plan_vence_en` `NULL`; actualizar los docstrings de `enforce_plan_limit`/`require_module_access`/`ensure_module_access` que hablan de bloqueo inmediato, sin cambiar el orden de rechazos de spec 141 (FR-005, FR-006)
- [X] T026 [US2] Crear `../pos-backend/app/characterization_tests/test_subscription_route_inventory.py` con el patrón de `test_module_route_inventory.py` (spec 141): recorrer las rutas reales de la aplicación sin base de datos y comprobar que cada ruta que depende de `get_tenant` está clasificada como exenta (prefijos de T023) o bloqueada según la tabla de `contracts/blocked-access.md § 2`, de modo que una ruta nueva sin clasificar haga fallar la prueba (FR-006, FR-008)
- [X] T027 [US2] Verificar `quickstart.md § 3` contra la API en marcha y comprobar con un token de comensal de un tenant bloqueado que `GET /realtime/stream` y `POST /cart/submit` responden `403`, mientras `POST /realtime/ticket` del staff responde `200`. Ejecutar además `python -m unittest app.characterization_tests.test_plan_expiration app.characterization_tests.test_module_route_inventory -v` (FR-006 a FR-008, FR-010) — Ejecutada el 2026-11-19 sobre una COPIA de la base de desarrollo (`pos_sim161`, ya eliminada; tu base real no se tocó) con el árbol fusionado (spec 162 + 161), la app real, PostgreSQL y Redis reales y el simulador de eventos (sección B, 9 comprobaciones): bloqueo de rutas de negocio y del menú del comensal, rutas exentas, login nunca bloqueado, gracia sin bloqueo

**Checkpoint**: US1 y US2 funcionan; el bloqueo es total y exacto.

---

## Phase 5: User Story 3 - El ADMIN genera un link de pago para renovar (Priority: P1)

**Goal**: el ADMIN obtiene un link de Wompi firmado por el valor mensual del plan; se reutiliza el pendiente vigente; los casos no cobrables y la falta de llaves responden de forma controlada.

**Independent Test**: como ADMIN pedir el link con un tenant por vencer, repetir la petición (mismo link), probar cada `409`, la ausencia de llaves (`503`, sin fila) y un rol no ADMIN (`403`) (`quickstart.md § 4`).

### Tests for User Story 3 ⚠️

- [X] T028 [P] [US3] Escribir `../pos-backend/app/characterization_tests/test_subscription_wompi.py` (parte del link): la firma de integridad reproduce el vector de la documentación (`sk8-438k4-xmxm392-sn2m2490000COPprod_integrity_Z5mMke9x0k8gpErbDqwrJXMqsI6SFli6` → `37c8407747e595535433ef8f6a811d853cd943046624a0ec04662b17bbf33bf5`); con `expiration-time` la cadena firmada incluye exactamente el mismo texto que va en la URL; la URL contiene `public-key`, `currency=COP`, `amount-in-cents` entero calculado con `Decimal`, `reference`, `signature%3Aintegrity`, `redirect-url` y `expiration-time` con formato `YYYY-MM-DDTHH:MM:SS.000Z`; la referencia es `SKP-` + 32 hex (36 caracteres) (FR-014, FR-015)
- [X] T029 [P] [US3] Escribir `../pos-backend/app/characterization_tests/test_subscription_payment_link.py`: crea un pago `pending` con monto = `precio_mensual` y expiración a 24 h en estados `por_vencer`/`en_gracia`/`bloqueada`; la segunda llamada devuelve el mismo pago (`reused`); un pendiente expirado pasa a `expired` y se crea otro; `409` con `reason` correcto para `activa`, `plan_vence_en` `NULL`, ciclo `anual` y plan sin `precio_mensual` (sin crear filas); `503` sin llaves (sin crear filas); un `IntegrityError` por el índice parcial se resuelve releyendo el pendiente existente; `requested_by_user_id` queda guardado; un usuario no ADMIN recibe `403` vía `require_tenant_admin`; y casos HTTP (`TestClient` con `dependency_overrides`, patrón de `test_bootstrap.py`) de `POST /api/v1/plan/subscription/payment-link`: `201`, `200` al reutilizar, `403`, `409` con `code` y `reason`, y `503` con `code`, con los cuerpos de `contracts/subscription-api.md § 2` (FR-011 a FR-013, FR-016 a FR-018)

### Implementation for User Story 3

- [X] T030 [US3] Crear `../pos-backend/app/core/wompi.py` con `build_reference(payment_id)`, `format_expiration(dt)`, `integrity_signature(reference, amount_in_cents, currency, expiration, secret)`, `build_checkout_url(...)` (con `urllib.parse.urlencode`, `signature:integrity` incluido) y `gateway_configured(settings)` (verdadero solo si hay `WOMPI_PUBLIC_KEY` y `WOMPI_INTEGRITY_SECRET`), según `contracts/wompi-webhook.md § 1`. Solo biblioteca estándar (FR-014, FR-015)
- [X] T031 [P] [US3] Crear `../pos-backend/app/api/v1/plan/subscription_schemas.py` con `PaymentLinkResponse` según `contracts/subscription-api.md § 2` (`payment_id`, `status`, `amount`, `currency`, `gateway_reference`, `payment_link_url`, `payment_link_expires_at`, `reused`) (FR-018)
- [X] T032 [US3] Crear `../pos-backend/app/api/v1/plan/subscription_service.py` con `get_or_create_payment_link(db, tenant, user)` y el orden de `contracts/subscription-api.md § 2`: llaves (`PaymentGatewayNotConfiguredError`) → estado/ciclo/precio (`SubscriptionNotPayableError` con su `reason`) → `SELECT … FROM tenants WHERE id = :id FOR UPDATE` → buscar el `pending` del tenant → reutilizar, o marcar `expired` + `flush()` y crear uno nuevo (generar `id`, derivar la referencia, firmar, guardar `payment_link_url`/`payment_link_expires_at` = ahora + `WOMPI_LINK_TTL_HOURS`) → `commit`; atrapar `IntegrityError` del índice parcial y releer el pendiente (FR-011 a FR-018)
- [X] T033 [US3] Agregar en `../pos-backend/app/api/v1/plan/router.py` la ruta `POST /plan/subscription/payment-link` protegida con `require_tenant_admin`, `response_model=PaymentLinkResponse`, `201` si se creó y `200` si se reutilizó (cambiar el código de estado con `Response`), documentada con los errores `403/409/503` (FR-011, FR-012)
- [X] T034 [US3] Ejecutar `python -m unittest app.characterization_tests.test_subscription_wompi app.characterization_tests.test_subscription_payment_link -v` y recorrer `quickstart.md § 4`, incluida la verificación manual de la firma y la prueba de dos peticiones simultáneas contra PostgreSQL (un solo `pending`) (FR-016) — Ejecutada el 2026-11-19 sobre una COPIA de la base de desarrollo (`pos_sim161`, ya eliminada; tu base real no se tocó) con el árbol fusionado (spec 162 + 161), la app real, PostgreSQL y Redis reales y el simulador de eventos (secciones C y D, 13 comprobaciones): cuerpo del contrato, firma de la URL recalculada aparte, los 409 y el 503, y **10 solicitudes simultáneas → un solo pago pendiente**

**Checkpoint**: US1–US3 funcionan; ya se puede emitir un link.

---

## Phase 6: User Story 4 - El pago aprobado renueva la suscripción de forma automática (Priority: P1)

**Goal**: el webhook de Wompi, verificado por firma e idempotente, aprueba o rechaza el pago, recalcula las fechas dentro de una transacción y desbloquea el tenant al instante.

**Independent Test**: simular avisos firmados (aprobado en cada estado, repetido, rechazado, anulado, firma alterada, referencia desconocida, monto distinto) y comprobar fechas, estado del pago y desbloqueo (`quickstart.md § 5`).

### Tests for User Story 4 ⚠️

- [X] T035 [P] [US4] Ampliar `../pos-backend/app/characterization_tests/test_subscription_wompi.py` (parte del evento) con un auxiliar de test que aplica la fórmula documentada del checksum (`sha256(valores de signature.properties + str(timestamp) + secreto)`): comparación en minúsculas; coincidencia obligatoria con `X-Event-Checksum` cuando llega; rechazo por `properties` que no incluyan `transaction.id`, `transaction.status` y `transaction.amount_in_cents`; rechazo por cuerpo sin `signature`/`timestamp`; rechazo si falta `WOMPI_EVENTS_SECRET`. **No** usar como vector el ejemplo numérico de la documentación (no reproduce; `research.md` Decisión 1) (FR-019)
- [X] T036 [P] [US4] Escribir `../pos-backend/app/characterization_tests/test_subscription_webhook.py` con la matriz de `contracts/wompi-webhook.md § 2.2` y los escenarios de `§ 2.3`: aprobado desde `por_vencer`/`en_gracia` (inicio = vencimiento anterior, fin = +1 mes), desde `bloqueada` (inicio = ahora), repetido (`duplicate`, fechas intactas), rechazado, anulado tras aprobar (sin revertir fechas), aprobado sobre `expired` y sobre `rejected`, monto o moneda distintos (`ignored`), referencia desconocida (`ignored`), `transaction.id` ya ligada a otro pago (`ignored`), tenant con ciclo `anual` o sin vencimiento (aprobado **sin** tocar fechas), aprobación con estado `activa` (acumula un mes), `approved` que nunca retrocede, atomicidad (si falla la actualización del tenant el pago sigue `pending`), la coexistencia con la renovación manual (el Super Admin reasigna plan y ciclo con un pago `pending`: la asignación funciona igual, el pago no cambia y, al aprobarse después, el recálculo usa las fechas vigentes en ese momento), y casos HTTP de `POST /api/v1/webhooks/wompi` con cuerpo crudo y sin `x-tenant-host` (`TestClient` con `dependency_overrides`): `200` con `{status}`, `400` por estructura o `properties` incompletos, `401` por checksum alterado, `X-Event-Checksum` distinto o secreto ausente (FR-020 a FR-027, FR-039)

### Implementation for User Story 4

- [X] T037 [US4] Agregar a `../pos-backend/app/core/wompi.py` `compute_event_checksum(event, secret)` y `verify_event(event, header_checksum, secret)` (comparación con `hmac.compare_digest` en minúsculas, validación de los `properties` mínimos, errores diferenciados 400/401) según `contracts/wompi-webhook.md § 2` (FR-019)
- [X] T038 [US4] Agregar a `../pos-backend/app/api/v1/plan/subscription_service.py` `apply_wompi_event(db, event)` que, en **una** transacción, bloquea el pago por `gateway_reference` (`FOR UPDATE`) y luego su tenant, valida monto/moneda/`transaction.id`, aplica la matriz de `data-model.md § 2.1`, guarda `gateway_transaction_id`, recalcula con `compute_subscription_status` + `calculate_plan_vencimiento` según `data-model.md § 2.2` (rama sin período para ciclo no mensual o sin vencimiento) y devuelve `processed`/`duplicate`/`ignored`; registra advertencias con `reference` y `transaction.id`, nunca el cuerpo (FR-020 a FR-027)
- [X] T039 [US4] Crear `../pos-backend/app/api/v1/webhooks/__init__.py` y `../pos-backend/app/api/v1/webhooks/router.py` con `POST /webhooks/wompi`: lee el cuerpo JSON y `X-Event-Checksum`, verifica con `verify_event` (400/401 según `contracts/wompi-webhook.md § 2.1`), ignora eventos que no sean `transaction.updated` (`200 ignored`), usa `get_shared_db` y responde `{"status": ...}` con `200` (FR-019 a FR-021)
- [X] T040 [US4] Registrar el router de webhooks en `../pos-backend/app/main.py` (`app.include_router(webhooks_router, prefix="/api/v1")`), sin `x-tenant-host` ni guard de suscripción (FR-019)
- [X] T041 [US4] Comprobar que `OperationalLogMiddleware` (`../pos-backend/app/core/error_middleware.py`) no registra el cuerpo del webhook ni falla por no haber tenant, y que ningún registro de la funcionalidad imprime secretos ni el checksum (FR-017); corregir si fuera el caso (FR-017)
- [X] T042 [US4] Ejecutar `python -m unittest app.characterization_tests.test_subscription_wompi app.characterization_tests.test_subscription_webhook -v` y recorrer `quickstart.md § 5` con el auxiliar de firma, incluidos el desbloqueo inmediato de un tenant bloqueado y la repetición del mismo evento (FR-020 a FR-026) — Ejecutada el 2026-11-19 sobre una COPIA de la base de desarrollo (`pos_sim161`, ya eliminada; tu base real no se tocó) con el árbol fusionado (spec 162 + 161), la app real, PostgreSQL y Redis reales y el simulador de eventos (sección E, 21 comprobaciones): recálculo en bloqueada y en gracia, desbloqueo inmediato, **8 entregas simultáneas del mismo evento → vigencia extendida exactamente un mes**, firma alterada, monto distinto, referencia desconocida, DECLINED, reintento aprobado y VOIDED

**Checkpoint**: ciclo completo de cobro (US1–US4) verificado con firmas simuladas. **Alcance mínimo viable.**

---

## Phase 7: User Story 5 - Los ADMIN reciben alertas de vencimiento, gracia y bloqueo (Priority: P2)

**Goal**: tres avisos in-app, solo para ADMIN, una vez por ciclo, emitidos por un job periódico dentro de la ventana horaria local del tenant.

**Independent Test**: con un tenant por vencer correr la evaluación varias veces (un solo aviso, visible al ADMIN y no al cajero), y avanzar el reloj por cada hito (`quickstart.md § 6`).

### Tests for User Story 5 ⚠️

- [X] T043 [P] [US5] Escribir `../pos-backend/app/characterization_tests/test_notifications_audience.py` según `contracts/notifications-audience.md § 5`: el listado (con `after_id`, `only_pending` y `total`) filtra por `audience_role`; `attend` de un evento fuera de la audiencia da `404`; `resolve_staff` suscribe a `{staff, staff:<rol>}` cuando el ticket trae el rol y solo a `staff` cuando no lo trae; `InAppChannel` publica en `staff:<audiencia>` solo con audiencia y en `staff` sin ella; el push solo va a usuarios del rol; los eventos `order.created` y `payment.completed` no cambian (FR-031, FR-037)
- [X] T044 [P] [US5] Escribir `../pos-backend/app/characterization_tests/test_subscription_alerts.py`: un aviso por tipo y ciclo aunque la evaluación corra 10 veces; el segundo intento por `IntegrityError` no inserta; tras una pausa solo se emite el aviso del estado vigente; dentro/fuera de la ventana local del tenant (probar con dos zonas distintas, p. ej. `America/Bogota` y `Asia/Tokyo`); un nuevo ciclo tras un pago reinicia los avisos; tenant sin ADMIN activo igual registra el evento; marca `expired` los `pending` vencidos; un tenant que falla no detiene a los demás (FR-028 a FR-032)

### Implementation for User Story 5

- [X] T045 [P] [US5] Agregar `staff_role_channel(role)` (devuelve `f"staff:{role.lower()}"`) en `../pos-backend/app/core/events.py`, junto a `CH_STAFF` (FR-031)
- [X] T046 [US5] Guardar el rol en el ticket del staff: `create_ticket` en `../pos-backend/app/api/v1/realtime/router.py` pasa `user.role_name` a `issue_ticket` y `issue_ticket`/`resolve_staff` en `../pos-backend/app/api/v1/realtime/auth.py` lo persisten (`"r"`) y suscriben a `{CH_STAFF, staff_role_channel(rol)}`; un ticket sin `"r"` conserva solo `CH_STAFF` (FR-031)
- [X] T047 [P] [US5] Hacer que `InAppChannel.send` en `../pos-backend/app/core/notifications/channels/in_app.py` publique `notification.created` solo en `staff_role_channel(event.audience_role)` cuando el evento tiene audiencia, y en `CH_STAFF` cuando no (FR-031)
- [X] T048 [P] [US5] En `BrowserPushChannel.send` (`../pos-backend/app/core/notifications/channels/browser_push.py`), cuando el evento tiene `audience_role`, limitar las `PushSubscription` a las de usuarios de ese rol (subconsulta sobre `User`/`Role`, tablas de `shared`); sin audiencia, comportamiento actual (FR-031)
- [X] T049 [P] [US5] En `../pos-backend/app/api/v1/notifications/router.py` filtrar `list_notifications` por `audience_role IS NULL OR audience_role = <rol del usuario>` (también en el modo `after_id` y en el total) y hacer que `attend` responda `404` para eventos fuera de la audiencia (FR-031)
- [X] T050 [P] [US5] Agregar a `summarize` en `../pos-backend/app/core/notifications/summary.py` las tres ramas `subscription.expiring`, `subscription.grace_started` y `subscription.blocked` con los textos de `contracts/notifications-audience.md § 2`, usando `payload["fecha_limite_pago_local"]` ya formateada (FR-028)
- [X] T051 [US5] En `../pos-backend/app/core/notifications/dispatch.py`: agregar el parámetro `audience_role` (por defecto `None`) a `_dispatch`; crear `_dispatch_once` (atrapa `IntegrityError`, hace `rollback` y devuelve `None`); y crear `notify_subscription_expiring`, `notify_subscription_grace_started` y `notify_subscription_blocked`, con `related_entity_type="subscription"`, `related_entity_id = uuid5(NAMESPACE, f"{event_type}|{plan_vence_en.isoformat()}")`, `audience_role="ADMIN"` y `payload` con `plan_vence_en`, `fecha_limite_pago`, `dias_restantes` y `fecha_limite_pago_local` (formateada en la zona `ZoneInfo(tenant.timezone)`) (FR-028, FR-029, FR-031)
- [X] T052 [US5] En `../pos-backend/app/core/scheduler.py` crear `evaluate_subscription_alerts()` (recorre `shared.tenants` con `plan_vence_en` no nulo; calcula el estado; respeta la ventana local `SUBSCRIPTION_ALERT_LOCAL_START_HOUR`–`_END_HOUR`; emite solo el aviso del estado vigente; marca `expired` los `pending` con `payment_link_expires_at` pasado; un tenant roto no detiene a los demás), `_run_subscription_alerts_with_lock()` con lock de Redis como `_run_expire_promotions_with_lock`, y registrarlo en `start_scheduler()` con `IntervalTrigger(minutes=settings.SUBSCRIPTION_ALERT_INTERVAL_MINUTES)` y su línea de arranque en el log (FR-028 a FR-032)
- [X] T053 [US5] Ejecutar `python -m unittest app.characterization_tests.test_notifications_audience app.characterization_tests.test_subscription_alerts app.characterization_tests.test_notifications app.characterization_tests.test_scheduler app.characterization_tests.test_menu_realtime -v` (sin regresiones) y recorrer `quickstart.md § 6` con clientes SSE de ADMIN y CASHIER (FR-031) — Ejecutada el 2026-11-19 sobre una COPIA de la base de desarrollo (`pos_sim161`, ya eliminada; tu base real no se tocó) con el árbol fusionado (spec 162 + 161), la app real, PostgreSQL y Redis reales y el simulador de eventos (sección G, 14 comprobaciones): una sola emisión por ciclo en 5 ejecuciones, audiencia ADMIN en listado/atender, canales por rol y publicación en Redis solo en `staff:admin`. **No se abrió un cliente SSE real**: se verificaron los canales del ticket y lo publicado en Redis

**Checkpoint**: las alertas llegan solo a los ADMIN y una sola vez por ciclo.

---

## Phase 8: User Story 6 - Consultar el historial de pagos de suscripción (Priority: P2)

**Goal**: el ADMIN ve los pagos de su tenant y el Super Admin los de cualquier tenant, paginados y del más reciente al más antiguo.

**Independent Test**: con pagos de dos tenants, listar como ADMIN de cada uno (solo los propios), como CASHIER (`403`) y como Super Admin por tenant (`quickstart.md § 7`).

### Tests for User Story 6 ⚠️

- [X] T054 [P] [US6] Escribir `../pos-backend/app/characterization_tests/test_subscription_history.py`: aislamiento entre tenants, orden `created_at DESC, id DESC`, paginación (`page`, `size`, `total`), `403` para roles no ADMIN, la respuesta no incluye `payment_link_url` ni `gateway_transaction_id`, y la consulta del Super Admin por `tenant_id` (incluido `404` para un tenant inexistente); más casos HTTP de `GET /api/v1/plan/subscription/payments` y del historial del Super Admin (`TestClient` con `dependency_overrides`): paginación, orden y `403` (FR-033 a FR-035)

### Implementation for User Story 6

- [X] T055 [US6] Agregar `PaymentHistoryItem` y `PaymentHistoryResponse` (`items`, `total`, `page`, `size`) a `../pos-backend/app/api/v1/plan/subscription_schemas.py` con los campos de `contracts/subscription-api.md § 3` (FR-035)
- [X] T056 [US6] Agregar `list_payments(db, tenant_id, page, size)` a `../pos-backend/app/api/v1/plan/subscription_service.py`: filtra siempre por el `tenant_id` recibido, ordena y pagina como `/notifications` y devuelve el total (FR-033)
- [X] T057 [US6] Agregar `GET /plan/subscription/payments` a `../pos-backend/app/api/v1/plan/router.py` con `require_tenant_admin`, `page` (≥ 1) y `size` (1–100), usando el tenant de `get_tenant` (sin parámetro de tenant) (FR-033)
- [X] T058 [P] [US6] Crear `../pos-backend/app/api/v1/super_admin/subscription_payments_router.py` con `GET /tenants/{tenant_id}/subscription-payments` (misma respuesta; `404` con el formato estandarizado del prefijo `/api/v1/super-admin`, spec 068) e incluirlo en `../pos-backend/app/api/v1/super_admin/router.py` junto a los demás sub-routers (FR-034)
- [X] T059 [US6] Ejecutar `python -m unittest app.characterization_tests.test_subscription_history -v` y recorrer `quickstart.md § 7` (FR-033, FR-034) — Ejecutada el 2026-11-19 sobre una COPIA de la base de desarrollo (`pos_sim161`, ya eliminada; tu base real no se tocó) con el árbol fusionado (spec 162 + 161), la app real, PostgreSQL y Redis reales y el simulador de eventos (sección F, 8 comprobaciones): paginación, orden, aislamiento entre tenants, sin link ni firma, 403 y 404 con el sobre del panel

**Checkpoint**: el historial es auditable por el ADMIN y por soporte.

---

## Phase 9: User Story 7 - Activar la funcionalidad sin bloquear de golpe a los tenants ya vencidos (Priority: P2)

**Goal**: un procedimiento de una sola vez, idempotente, da a los tenants ya vencidos la gracia completa desde el despliegue.

**Independent Test**: con tenants vencidos hace 40 días, hace 3 h y vigente, el informe lista solo los vencidos; tras `--apply` quedan en gracia; repetir con el mismo corte no cambia nada (`quickstart.md § 8`).

### Tests for User Story 7 ⚠️

- [X] T060 [US7] Escribir `../pos-backend/app/characterization_tests/test_subscription_grace_script.py`: sin `--apply` solo informa y no escribe; con `--apply` mueve `plan_vence_en` de los tenants con `plan_vence_en < cutoff` a `cutoff` y no toca `plan_iniciado_en`, vigentes ni tenants sin vencimiento; repetir con el mismo `cutoff` no modifica nada; el estado resultante es `en_gracia` con ~120 h por delante; informa por tenant el valor anterior y el nuevo; `--cutoff` es obligatorio (FR-038)

### Implementation for User Story 7

- [X] T061 [US7] Crear `../pos-backend/app/scripts/grant_subscription_grace.py` siguiendo las convenciones de `set_tenant_timezone.py` (docstring con uso `python -m app.scripts.grant_subscription_grace --cutoff <ISO-UTC> [--apply]`, `argparse`, `logging`, `with_db(None)`): informa por defecto y solo escribe con `--apply`; imprime y registra id, nombre, valor anterior y nuevo de cada tenant afectado; salida clara cuando no hay nada que hacer (FR-038)
- [X] T062 [US7] Ejecutar `python -m unittest app.characterization_tests.test_subscription_grace_script -v` y recorrer `quickstart.md § 8` (FR-038) — Ejecutada el 2026-11-19 sobre una COPIA de la base de desarrollo (`pos_sim161`, ya eliminada; tu base real no se tocó) con el árbol fusionado (spec 162 + 161), la app real, PostgreSQL y Redis reales y el simulador de eventos (sección H, 4 comprobaciones): simulación, aplicación con 5 días completos de gracia e idempotencia. En la base de desarrollo real ningún tenant tiene un vencimiento pasado, así que allí no cambiaría nada

**Checkpoint**: la activación no bloquea a nadie de golpe.

---

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: regresión completa, reversión, seguridad y la verificación real con Wompi (bloqueada hasta tener cuenta).

- [X] T063 Ejecutar toda la suite del backend (`python -m unittest discover -s app/characterization_tests -p 'test_*.py' -v`) y comparar **por nombre de prueba** contra la línea base de `develop`: ninguna falla nueva; las pruebas `CONGELA` sin cambios (SC-012). No correr la suite del frontend en paralelo (FR-043)
- [X] T064 Recorrer `quickstart.md § 9` (exportar `subscription_payments`, borrar los avisos de suscripción, `alembic downgrade -1`, verificar que `GET /notifications` funciona y volver a `upgrade head`) (FR-036, FR-037) — Ejecutada el 2026-11-19 sobre una COPIA de la base de desarrollo (`pos_sim161`, ya eliminada; tu base real no se tocó) con el árbol fusionado (spec 162 + 161), la app real, PostgreSQL y Redis reales y el simulador de eventos: bajar mis dos revisiones y volver a subirlas deja el esquema idéntico, y el procedimiento tras el pull (`alembic stamp --purge` + `upgrade head`) también
- [X] T065 [P] Auditoría de seguridad: buscar en `../pos-backend` que ningún secreto de Wompi se imprima en logs, respuestas ni `NotificationEvent`, que el webhook solo registre `reference` y `transaction.id`, y que `payment_link_url` e `gateway_transaction_id` no salgan en los historiales; comprobar además que `../pos-backend/app/api/v1/plan/subscription_service.py` y `../pos-backend/app/api/v1/webhooks/router.py` no importan ni referencian `Invoice`, `Sale` ni `CustomerOrder` (los pagos de suscripción no tocan facturas) y que `git diff` de `../pos-backend/requirements.txt` está vacío (sin dependencias nuevas) (FR-017, FR-035, FR-040, FR-042)
- [X] T066 [P] Actualizar `specs/000-reconocimiento/registro-de-anomalias.md` con el estado final de A-161 a A-164 (incluida la confirmación o corrección de A-163) y marcar en `spec.md` los supuestos derivados que el usuario haya confirmado o cambiado (FR-043) — Hecha (2026-11-17): A-161 a A-164 actualizadas con su estado real; **A-163 sigue pendiente de confirmación expresa del usuario**
- [X] T067 Ejecutar `quickstart.md §§ 2–8` completo contra la API en marcha con la rama final y anotar bajo esta tarea los resultados y cualquier desviación (Principio X) — Ejecutada el 2026-11-19 sobre una COPIA de la base de desarrollo (`pos_sim161`, ya eliminada; tu base real no se tocó) con el árbol fusionado (spec 162 + 161), la app real, PostgreSQL y Redis reales y el simulador de eventos: **74 de 74 comprobaciones en verde** (secciones A–H de `quickstart.md`)

### Verificación real contra Wompi Sandbox — ⛔ BLOQUEADA hasta que exista la cuenta (FR-041)

La funcionalidad **no se da por verificada de punta a punta** hasta cerrar estas tareas. Espejan `quickstart.md § 10`.

- [ ] T068 Crear la cuenta de Wompi, obtener `pub_test_…`, `test_integrity_…` y `test_events_…` y configurarlas en el `.env` local (usuario) (FR-041)
- [ ] T069 Confirmar el host del checkout de Sandbox y, si cambia, ajustar `WOMPI_CHECKOUT_URL` en `../pos-backend/.env.example` y en `../pos-backend/app/core/config.py` (FR-041)
- [ ] T070 Pagar un link real con una tarjeta de prueba y comprobar que Wompi acepta la firma de integridad y la `expiration-time` (FR-041)
- [ ] T071 Capturar el primer evento real y verificar que `compute_event_checksum` (`../pos-backend/app/core/wompi.py`) coincide con el checksum de Wompi y qué `properties` firma realmente; si la fórmula real difiere, corregir `wompi.py`, `test_subscription_wompi.py` y `contracts/wompi-webhook.md` (FR-041)
- [ ] T072 Registrar la URL de eventos de Sandbox en el dashboard de Wompi (distinta de la de Producción) y confirmar que el webhook recibe `200` (FR-041)
- [ ] T073 Comprobar si Wompi hace cumplir `expiration-time` (abrir un link vencido) y si tras un `DECLINED` el mismo checkout permite reintentar; ajustar `research.md` Decisión 9 si el comportamiento difiere (FR-041)
- [ ] T074 Confirmar la redirección: que Wompi devuelva al cliente a la `redirect-url` armada con `WOMPI_REDIRECT_URL_TEMPLATE` (`../pos-backend/app/core/config.py`) agregando `?id=<transacción>`, y ajustar la plantilla a la página de retorno por tenant cuando la defina la spec de frontend (FR-041)
- [ ] T075 Repetir la secuencia con credenciales de Producción antes de activar el cobro real y ejecutar `../pos-backend/app/scripts/grant_subscription_grace.py` con `--cutoff` el día en que se configuren las llaves de Producción (plan, riesgo R1) (FR-041)

### Ajustes posteriores a la integración con la spec 162 (2026-11-19)

- [X] T076 Crear el simulador de eventos de Wompi `../pos-backend/app/scripts/simulate_wompi_event.py` (firma y envía `transaction.updated`; `--status`, `--tamper`, `--post`) con sus pruebas `../pos-backend/app/characterization_tests/test_subscription_simulator.py`, para recorrer el ciclo de pago sin cuenta de Wompi. Firma con la misma función con que el servidor verifica: prueba el flujo, no la fórmula de Wompi (FR-041)
- [X] T077 Re-encadenar `../pos-backend/alembic/versions/e0230fd88635_161_subscription_payments.py` a `b1c9f4e7a3d2` (última migración de la spec 162) para tener una sola cabeza, y ensayar la cadena completa y el procedimiento tras el pull sobre una copia de la base de desarrollo (FR-036, FR-037)
- [X] T078 Clasificar `/legal` (spec 162) en el guard `../pos-backend/app/core/subscription_guard.py`: `/legal/platform-acceptance` exenta y el resto bloqueado; pasar `test_subscription_route_inventory.py` a clasificación por ruta con segmentos mixtos (FR-006, FR-008). Decisión del asistente, pendiente de confirmación del usuario
- [ ] T079 Tras el `git pull` del usuario: retirar los dos archivos de fusión locales, `alembic stamp --purge 8d09a031cba3` y `alembic upgrade head` en la base de desarrollo REAL (`research.md` Decisión 14), con una copia de seguridad antes. **Requiere el visto bueno del usuario**: la migración `b1c9f4e7a3d2` de la spec 162 borra una columna (FR-036, FR-037)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias. T001 debe cerrarse antes de implementar (T004 en adelante); T002 bloquea T014.
- **Foundational (Phase 2)**: depende de Setup; **bloquea** todas las historias.
- **US1 (Phase 3)**, **US2 (Phase 4)**, **US5 (Phase 7)** y **US7 (Phase 9)**: dependen solo de Foundational y pueden avanzar en paralelo entre sí.
- **US3 (Phase 5)**: depende de Foundational (modelo, errores, `subscription.py`); sus reglas usan el estado de US1/US2 pero solo a través de `compute_subscription_status`.
- **US4 (Phase 6)**: depende de US3 (comparte `wompi.py` y `subscription_service.py`, y necesita pagos creados).
- **US6 (Phase 8)**: depende de US3 (archivos `subscription_schemas.py`, `subscription_service.py` y `plan/router.py`).
- **Polish (Phase 10)**: depende de las historias que se quieran entregar; la verificación con Sandbox depende además de la cuenta de Wompi.

### User Story Dependencies

- **US1 (P1)**: independiente tras Foundational.
- **US2 (P1)**: independiente tras Foundational. No activar en producción sin llaves de Wompi (riesgo R1).
- **US3 (P1)**: independiente en pruebas (los pagos se crean desde las fixtures), secuencial en archivos con US4 y US6.
- **US4 (P1)**: requiere US3 en el árbol de trabajo.
- **US5 (P2)**: independiente; sus avisos usan el modelo `SubscriptionPayment` solo para marcar pendientes vencidos.
- **US6 (P2)**: requiere US3 en el árbol de trabajo.
- **US7 (P2)**: independiente.

### Within Each User Story

- Las pruebas se escriben primero y deben fallar.
- Modelos y errores (fase 2) → servicios → rutas → verificación manual con `quickstart.md`.
- Una historia queda completa cuando sus pruebas pasan y su sección del quickstart se recorre.

### Archivos compartidos (no paralelizar entre sí)

| Archivo | Tareas | Orden |
|---|---|---|
| `app/core/wompi.py` | T030 → T037 | US3 antes que US4 |
| `app/api/v1/plan/subscription_service.py` | T032 → T038 → T056 | US3 → US4 → US6 |
| `app/api/v1/plan/subscription_schemas.py` | T031 → T055 | US3 → US6 |
| `app/api/v1/plan/router.py` | T033 → T057 | US3 → US6 |
| `app/characterization_tests/test_subscription_wompi.py` | T028 → T035 | US3 → US4 |
| `app/main.py` | T010 → T040 | Foundational → US4 |

---

## Parallel Example

```bash
# Foundational, tras T004/T005: pruebas y modelos en archivos distintos
Task: "Escribir test_subscription_state.py"                 # T006
Task: "Escribir test_subscription_errors.py"                # T008
Task: "Crear el modelo SubscriptionPayment"                 # T011
Task: "Agregar audience_role a notification_event.py"       # T012
Task: "Extender plan_fixtures.py"                           # T013

# Una vez cerrada la fase 2, en paralelo por distintas personas:
#   Persona A: US1 (T016–T019) y luego US2 (T020–T027)
#   Persona B: US5 (T043–T053)
#   Persona C: US7 (T060–T062)
#   Persona D: US3 (T028–T034) y luego US4 y US6

# Dentro de US5, después de T051: archivos distintos
Task: "InAppChannel con canal por rol"        # T047
Task: "BrowserPushChannel con filtro por rol" # T048
Task: "Filtro de audiencia en el listado"     # T049
Task: "Resumen de los tres avisos"            # T050
```

---

## Implementation Strategy

### MVP (US1 + US2 + US3 + US4)

1. Fase 1 (Setup) y fase 2 (Foundational): **críticas**.
2. US1 → el estado se ve. US2 → el bloqueo y la gracia funcionan.
3. US3 → se emite el link. US4 → el pago renueva solo.
4. **DETENER y VALIDAR** con `quickstart.md §§ 2–5` y la suite de pruebas. Con esto el ciclo de cobro está completo y verificado con firmas simuladas.
5. **No** activar US2 en producción hasta tener llaves de Wompi o ejecutar el script de gracia ese día (riesgo R1).

### Entrega incremental

1. Setup + Foundational → base lista.
2. US1 → US2 → US3 → US4 (cada una verificable) → MVP.
3. US7 (script de gracia) puede prepararse en paralelo y se ejecuta justo antes de activar en producción.
4. US5 (alertas por audiencia) y US6 (historial) añaden valor sin romper lo anterior.
5. Polish → regresión completa → verificación real con Sandbox cuando exista la cuenta.

### Equipo en paralelo

Con varias personas: todos cierran Setup + Foundational; después se reparten US1/US2, US3→US4→US6, US5 y US7 respetando la tabla de archivos compartidos.

---

## Notes

- [P] = archivos distintos, sin dependencias pendientes.
- [Story] mapea cada tarea a su historia para trazabilidad (Principio XII).
- Los cuatro cambios de comportamiento existente (gracia, bloqueo total, `vencido`, audiencia) se registran en T001, **antes** de implementar (Principio II).
- Ninguna prueba `CONGELA comportamiento actual:` se modifica; las pruebas de expiración de spec 033 que cambian por la gracia citan A-161/A-162 (Principio III).
- La migración (T014) es solo DDL, aditiva y reversible; el cambio de datos es el script de US7, aparte (Principio VI).
- No hay dependencias nuevas (Principio IX).
- Commits pequeños, en inglés, Conventional Commits, sin marcas de IA y solo cuando el usuario lo pida (Principio XV).
- El ejemplo numérico del checksum de eventos de la documentación de Wompi **no reproduce**; no usarlo como vector de prueba hasta confirmarlo en Sandbox (T071).
