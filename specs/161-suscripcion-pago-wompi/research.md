# Research: Autogestión de suscripciones y pago de la membresía por link de pago (Wompi)

**Spec**: [spec.md](./spec.md) | **Fecha**: 2026-11-17 | **Repos tocados**: `pos-backend` (código) y `pos-specs` (documentos)

Este documento resuelve cada incógnita técnica del plan. Las observaciones sobre el código salen de leer `pos-backend` en la rama `develop` (2026-11-17); las de Wompi, de su documentación pública (`docs.wompi.co/docs/colombia/…`) leída ese mismo día. Donde un dato **no** se pudo confirmar se dice, y se indica cómo queda cubierto.

No quedan marcadores `NEEDS CLARIFICATION`: las 8 decisiones de negocio ya están cerradas en `spec.md § Clarifications`. Lo que sigue son decisiones técnicas.

---

## Decisión 1 — Qué se sabe (y qué no) de Wompi

**Confirmado en la documentación** (Web Checkout y Eventos):

| Tema | Hecho |
|---|---|
| URL del Web Checkout | `https://checkout.wompi.co/p/`, con parámetros por query (`GET`). |
| Obligatorios | `public-key`, `currency` (solo `COP`), `amount-in-cents` (monto en centavos), `reference`, `signature:integrity`. |
| Opcionales que usamos | `redirect-url`, `expiration-time`. |
| `expiration-time` | ISO 8601 en UTC, p. ej. `2023-06-09T20:28:50.000Z`. |
| Firma de integridad | SHA-256 hexadecimal de `<referencia><monto-en-centavos><moneda>[<expiration-time>]<secreto-de-integridad>`, sin separadores. |
| Evento | `transaction.updated`, con `data.transaction.{id, status, reference, amount_in_cents, currency, …}`, `signature.{properties, checksum}`, `timestamp` (entero) y `environment` (`test`/`prod`). |
| Checksum del evento | SHA-256 de: valores de `signature.properties` (tomados de `data`, en ese orden) + `timestamp` + secreto de eventos. También llega en la cabecera `X-Event-Checksum`. Los `properties` "pueden variar": se leen del evento, no se suponen fijos. |
| Estados | `PENDING` (inicial), `APPROVED`, `DECLINED`, `VOIDED` (solo tarjeta), `ERROR`. |
| Respuesta esperada | **Solo HTTP 200** cuenta como éxito. Ante cualquier otra, Wompi reintenta 3 veces en 24 h (a los 30 min, 3 h y 24 h). |
| Redirección | `redirect-url` recibe `?id=<id de transacción>`. La doc advierte: no usar la redirección como validación; la fuente de verdad es el evento. |
| Referencia | Se recomienda alfanumérica con `-` o `_`; no reutilizar una referencia ya completada. |
| Llaves | Pública `pub_test_`/`pub_prod_`; secretos de integración `test_integrity_`/`prod_integrity_` y `test_events_`/`prod_events_`. La llave privada (`prv_…`) no firma nada de esto. |

**Verificado por mí contra el ejemplo de la documentación**: la firma de integridad. La cadena `sk8-438k4-xmxm392-sn2m2490000COPprod_integrity_Z5mMke9x0k8gpErbDqwrJXMqsI6SFli6` produce exactamente `37c8407747e595535433ef8f6a811d853cd943046624a0ec04662b17bbf33bf5` con SHA-256. Se usa como vector de prueba.

**No reproducible**: el ejemplo numérico del checksum de eventos. Con la cadena y el secreto que publica la página (`1234-1610641025-49201` + `APPROVED` + `4490000` + `1530291411` + `prod_events_OcHn…`) SHA-256 da `5A18EC5E…`, no el `3476DDA5…` del ejemplo; ninguna permutación de los cinco componentes ni de otros algoritmos coincide. El texto de la fórmula sí es claro y coincide con lo que Wompi documenta, así que se implementa tal como está escrito, pero **el ejemplo numérico no sirve de vector de prueba** y la fórmula queda pendiente de confirmarse con un evento real de Sandbox (tarea explícita, FR-041).

**No confirmado** (se resuelve en las decisiones siguientes):

1. Host del Web Checkout de Sandbox: la doc no documenta uno separado. → Es configuración (`WOMPI_CHECKOUT_URL`), con `https://checkout.wompi.co/p/` por defecto; se confirma con la cuenta.
2. Que Wompi **haga cumplir** `expiration-time` (la doc solo habla de un contador regresivo). → La vigencia de 24 h se garantiza también de nuestro lado: pasada la hora, el pago se marca expirado y se pide uno nuevo; y una aprobación tardía igual se aplica (D7, FR-025), así que no se pierde dinero.
3. Longitud máxima de `reference` en el Web Checkout (255 caracteres solo está documentado para la API). → Se usa una referencia corta (36 caracteres).
4. Si un `APPROVED` puede pasar a `VOIDED`. → Se soporta (D7) sin depender de que ocurra.
5. Si tras un `DECLINED` el mismo checkout deja reintentar con la misma referencia. → Se soporta (Decisión 9): una aprobación se aplica también sobre un pago `rejected`.

**Alternativas consideradas**: Payment Links de la API (`POST /v1/payment_links`) → rechazada por D3 (exige llave privada y una llamada saliente, y su evento no devuelve nuestra referencia de forma directa).

---

## Decisión 2 — Construcción del link (Web Checkout firmado, sin llamadas externas)

- **Referencia**: `SKP-<uuid del pago en hex, 32 caracteres>` (36 en total). Determinista respecto al pago (se deriva de su `id`), única, solo alfanumérica y guion, sin datos del tenant en claro.
- **Monto**: `amount-in-cents = int(Decimal(amount) * 100)` calculado con `Decimal` (nunca `float`). Moneda constante `COP`.
- **Vigencia**: `payment_link_expires_at = utc_now + WOMPI_LINK_TTL_HOURS` (24). Se formatea una sola vez como `YYYY-MM-DDTHH:MM:SS.000Z` y **esa misma cadena** entra en la firma y en la URL (si difieren, Wompi rechaza la firma).
- **Firma**: `hashlib.sha256((ref + str(cents) + "COP" + exp + secreto).encode()).hexdigest()`.
- **URL**: `WOMPI_CHECKOUT_URL?` + `urllib.parse.urlencode` con `public-key`, `currency`, `amount-in-cents`, `reference`, `signature:integrity`, `redirect-url`, `expiration-time`. `urlencode` codifica los dos puntos de `signature:integrity` como `%3A`, igual que un formulario HTML `GET`, que es como la doc lo muestra.
- **`redirect-url`**: `WOMPI_REDIRECT_URL_TEMPLATE.format(host=tenant.host)`; por defecto `https://{host}/`. La página real de retorno la define la spec de frontend.
- **Sin credenciales**: si falta `WOMPI_PUBLIC_KEY` o `WOMPI_INTEGRITY_SECRET`, se responde `503` con `code` estable y **no se inserta nada** (la comprobación va antes del `INSERT`).
- **Dependencias**: solo biblioteca estándar (`hashlib`, `hmac`, `urllib.parse`, `decimal`) y `dateutil`, que ya usa `calculate_plan_vencimiento`.

**Alternativa rechazada**: persistir el `payment_link_url` sin la firma y reconstruirla al leer → obliga a guardar el secreto en el flujo de lectura; guardar la URL ya firmada es más simple y no filtra el secreto (la firma es un hash, no el secreto).

---

## Decisión 3 — Verificación del webhook

Orden de las comprobaciones en `POST /webhooks/wompi` (la primera que falla corta):

1. Si falta `WOMPI_EVENTS_SECRET` → `401` y `logger.error` (el aviso se trata como de firma inválida, como dice la spec).
2. Cuerpo JSON ilegible o sin `event`/`data`/`signature`/`timestamp` → `400`.
3. Checksum: `sha256("".join(valor(data, p) for p in signature.properties) + str(timestamp) + secreto)`; se compara con `hmac.compare_digest` **en minúsculas** (el ejemplo de la doc viene en mayúsculas). Si llega la cabecera `X-Event-Checksum`, también debe coincidir. No coincide → `401`.
4. Los `properties` firmados deben incluir como mínimo `transaction.id`, `transaction.status` y `transaction.amount_in_cents`; si no, `400`. Así el estado y el monto que se aplican siempre están cubiertos por la firma.
5. `event != "transaction.updated"` → `200` (se ignora sin efecto).

**Hueco conocido y su mitigación**: `transaction.reference` **no** forma parte de los `properties` firmados por defecto; es el dato con el que se localiza el pago. Un tercero no puede alterarlo sin invalidar nada porque nunca ve el cuerpo (Wompi lo envía directo a nuestro servidor), pero como defensa en profundidad el pago guarda `gateway_transaction_id` con un índice único parcial: **una misma transacción de Wompi no puede aplicarse a dos pagos distintos**. Un evento válido cuya `transaction.id` ya esté ligada a otro pago se rechaza con `200` y registro de advertencia.

**Tolerancia temporal**: no se limita la antigüedad del `timestamp`, porque Wompi reintenta hasta 24 h después y la idempotencia ya neutraliza las repeticiones.

**Política de respuesta** (porque solo `200` evita reintentos): se responde `200` en aprobado, en repetido, en referencia desconocida, en monto o moneda distintos y en eventos de otros tipos; `400`/`401` solo en firma o estructura inválida (esos reintentos no hacen daño).

**Alternativa rechazada**: consultar `GET /v1/transactions/{id}` con la llave privada para confirmar cada aprobación → es la verificación más fuerte, pero exige una segunda credencial, una llamada saliente en el camino crítico y contradice D3. Queda como endurecimiento futuro si Wompi cambia los `properties` firmados.

---

## Decisión 4 — El estado de la suscripción es una función pura

Un módulo nuevo `app/core/subscription.py` expone `compute_subscription_status(plan_vence_en, now)` que devuelve `(estado, dias_restantes, fecha_limite_pago)`:

| Condición (UTC, `now` y `plan_vence_en` naive) | Estado |
|---|---|
| `plan_vence_en` es `NULL` | `activa` (sin días ni fecha límite) |
| `now < vence − 48 h` | `activa` |
| `vence − 48 h ≤ now < vence` | `por_vencer` |
| `vence ≤ now < vence + 120 h` | `en_gracia` |
| `now ≥ vence + 120 h` | `bloqueada` |

`dias_restantes = ceil((objetivo − now) / 1 día)`, con `objetivo = vence` mientras no vence, `fecha_limite_pago` en gracia, y `0` bloqueada. Las constantes (48 h, 120 h) son del módulo, no configurables por entorno (D6 las fija). `now` se inyecta, lo que permite probar cada frontera exacta sin tocar el reloj (SC-001).

Un único cálculo lo comparten `GET /plan`, el guard global, `ensure_plan_not_expired`, el job de alertas y la validación del link, para que nunca discrepen.

---

## Decisión 5 — Dónde se aplica el bloqueo total (guard global)

**Hallazgo**: hoy `ensure_plan_not_expired` se invoca solo desde `enforce_plan_limit` (5 recursos) y `require_module_access`. Ningún otro router lo consulta, así que ventas, órdenes, caja, catálogo, menú QR y reportes no se bloquean.

**Puntos únicos por donde pasa todo tenant** (verificado):

1. `get_tenant` (`app/core/db.py:280`), usado por 21 archivos vía `Depends(get_tenant)`, resuelve el tenant por la cabecera `x-tenant-host`.
2. `resolve_tenant_by_id` (`app/core/db.py:302`), usado por `qr_context.py` (líneas 49 y 170) para el comensal, cuyo tenant sale del token.
3. `get_optional_tenant` (solo `/bootstrap`, que ya es exenta).

**Decisión**: una función `enforce_subscription_access(tenant, request=None)` en un módulo nuevo `app/core/subscription_guard.py`, invocada al final de `get_tenant` y de `resolve_tenant_by_id`. Si el estado es `bloqueada` y la ruta no es exenta, lanza `SubscriptionBlockedError` (403, `code = "subscription_blocked"`).

- **Exenciones por ruta**: se leen de `request.scope["route"].path_format` quitando el prefijo `/api/v1`, con el mismo mecanismo que ya usa `_enforce_mesero_scope` (`app/core/dependencies.py`). Si `route` no está disponible se cae a `request.url.path`. Prefijos exentos: `/auth`, `/bootstrap`, `/plan`, `/notifications`, `/realtime`.
- **`/realtime`**: `POST /realtime/ticket` (staff) pasa por `get_tenant` y queda exento; `GET /realtime/stream` del comensal pasa por `resolve_tenant_by_id`, que **no** recibe `request` y por tanto **no** tiene exenciones: el comensal de un tenant bloqueado no puede abrir el stream. El stream del staff no usa tenant en absoluto (ticket), así que sigue abierto.
- **Sin caché**: `find_tenant_by_host` consulta la base en cada petición, así que el estado se recalcula con `plan_vence_en` fresco; un pago aprobado desbloquea en la petición siguiente (FR-009) sin invalidar nada.
- **Costo**: cero consultas adicionales (el `Tenant` ya está cargado) y una comparación de fechas.
- **`ensure_plan_not_expired`** se reescribe sobre la misma función pura: bloquea solo en `bloqueada`, y con el mismo `SubscriptionBlockedError`. Se conserva como defensa para las llamadas directas (los tests la invocan sin FastAPI) y su mensaje sigue conteniendo "venci" para no romper `test_plan_expiration.py`.
- **Prefijos que quedan bloqueados**: `categories`, `presentations`, `unit-measures`, `unit-measure-groups`, `products`, `users`, `invitations`, `menu`, `orders`, `catalog`, `inventory`, `cash`, `sales`, `uploads`, `cart`, `table-sessions`, `invoices`, `tenant`, `reports`, `promotions`, `audit`. Sin tenant (nunca se bloquean): `super-admin`, `health` y `webhooks`.
- **Nota**: no existe un `/auth/me`; la "sesión propia" la cubren `/bootstrap` y `/auth/*`.

**Alternativas rechazadas**:

- *Middleware ASGI*: debería resolver el tenant por su cuenta (y decodificar el token del comensal) duplicando `get_tenant` y `resolve_tenant_by_id`.
- *Añadir `Depends` a cada router*: 21 archivos; fácil olvidar uno nuevo. El guard en el punto único hace que un router futuro quede protegido por defecto.

**Riesgo operativo**: ver Decisión 13.

---

## Decisión 6 — Qué significa `vencido` y por qué no hay que tocar el frontend

El frontend lee `summary.vencido` para ocultar módulos y como guard de navegación (`plan-module.guard.ts:30`, `tenant-sidebar.component.ts:269`, `reports.service.ts:85`, `option-groups-page.component.ts:206`, `plan-summary.service.ts:44`). Si `vencido` siguiera siendo "pasó `plan_vence_en`", la gracia de 5 días quedaría anulada en la interfaz aunque el backend la permitiera.

**Decisión**: `vencido = (subscription_state == "bloqueada")`. El campo conserva su nombre y tipo (compatibilidad, FR-004) y su significado de siempre ("el sistema ya me bloquea"). Los tres campos nuevos (`subscription_state`, `dias_restantes`, `fecha_limite_pago`) son aditivos.

**Pruebas afectadas** (Principio III): `test_plan_summary.py` y `test_plan_expiration.py` (límites de vencido), y por revisión `test_module_not_in_plan_error.py` y `test_tenant_plan_assignment.py`. Las suites `CONGELA` que mencionan "expir" tratan de la expiración de **sesiones de mesa**, no del plan, y no se tocan.

---

## Decisión 7 — Audiencia por rol de las notificaciones

**Hallazgo**: `NotificationEvent` (esquema `tenant`) no tiene destinatario; `GET /notifications` lo lee cualquier rol; `InAppChannel` publica en `CH_STAFF`; `BrowserPushChannel` envía a todas las `PushSubscription` activas del tenant.

**Decisión** — una columna `audience_role String(20) NULL` en `notification_events` (`NULL` = todo el personal, que es el comportamiento de todos los eventos existentes, así que no hay backfill):

| Superficie | Cambio |
|---|---|
| Listado `GET /notifications` | `WHERE audience_role IS NULL OR audience_role = <rol del usuario>`. Aplica también al modo recuperación (`after_id`) y al total. |
| Marcar atendida `POST /notifications/{id}/attend` | Un evento fuera de la audiencia del usuario responde `404`, no `403`, para no revelar que existe. |
| Tiempo real (SSE) | Se agrega un canal por rol `staff:<rol>` (`staff_role_channel`). El ticket del staff guarda el rol (`"r"`), y `resolve_staff` suscribe a `{CH_STAFF, staff:<rol>}`. Un evento con audiencia se publica **solo** en su canal por rol; uno sin audiencia, en `CH_STAFF` como hoy. Los tickets sin `"r"` (de antes del despliegue, 30 s de vida) caen en solo `CH_STAFF`. |
| Push | Con `audience_role`, se filtran las `PushSubscription` por usuarios de ese rol: `PushSubscription.user_id IN (SELECT users.id … JOIN roles WHERE roles.name = rol)`; son tablas de `shared`, que el `schema_translate_map` no toca. |
| Texto | `summarize()` gana tres ramas (`subscription.expiring`, `.grace_started`, `.blocked`). |
| Preferencias de canal | Sin cambio: la ausencia de fila equivale a habilitado. |

**Por qué un canal por rol y no filtrar al emitir**: la suscripción se deriva de la credencial (principio del módulo realtime: "los canales se derivan de la credencial, nunca se piden"), así que el filtrado ocurre en el bus, sin que el stream tenga que inspeccionar cada evento.

**Alternativas rechazadas**: una tabla de destinatarios por usuario (sobredimensionado para un solo caso, y cambia el modelo de "marca compartida" de spec 077); filtrar en el frontend (rompe la regla de que los demás roles no reciben el aviso, SC-009).

---

## Decisión 8 — Idempotencia de los avisos (una vez por ciclo)

- `event_type`: `subscription.expiring`, `subscription.grace_started`, `subscription.blocked`.
- `related_entity_type = "subscription"`.
- `related_entity_id` (UUID obligatorio): `uuid5(NAMESPACE, f"{event_type}|{plan_vence_en.isoformat()}")`. Es estable para un ciclo y cambia cuando un pago mueve el vencimiento, que es justo la definición de "ciclo" (FR-029).
- Un **índice único parcial** `ux__notification_events__subscription_once` sobre `(event_type, related_entity_id)` con `WHERE event_type LIKE 'subscription.%'`. Garantiza SC-008 aunque dos instancias corran el job a la vez (el lock de Redis lo evita en la práctica; el índice lo garantiza en teoría). Funciona en PostgreSQL y en SQLite (los tests).
- `_dispatch` hoy hace `db.add` + `commit` sin manejo de duplicados. Se agrega un `_dispatch_once` que atrapa `IntegrityError`, hace `rollback` y devuelve `None` (ya enviado).
- `payload`: `{plan_vence_en, fecha_limite_pago, dias_restantes}`.
- **Purga**: la retención estándar (90 días) borra el evento, pero para entonces el vencimiento ya cambió de ciclo, así que no hay riesgo de reenvío.

---

## Decisión 9 — Máquina de estados del pago y recálculo de fechas

```
pending ──APPROVED──▶ approved ──VOIDED──▶ voided
   │  ▲                  ▲
   │  └──(reintento)─ rejected      expired ──APPROVED──▶ approved
   ├──DECLINED/ERROR──▶ rejected
   └──tiempo────────▶ expired
```

Reglas (se evalúan con la fila del pago bloqueada, ver Decisión 11):

- `APPROVED` se aplica desde `pending`, `expired` y `rejected` (esta última cubre el reintento dentro del mismo checkout; si Wompi no lo permite, la rama simplemente no ocurre). Desde `approved` es un no-op idempotente. Desde `voided` se ignora.
- `DECLINED`/`ERROR` solo mueven `pending → rejected`. Nunca retroceden un `approved`.
- `VOIDED` solo actúa sobre `approved → voided` y **no revierte fechas** (D7).
- `PENDING` y cualquier otro estado se ignoran.
- Recálculo al aprobar (FR-022), con `now = utc_now_naive()`:
  - Si el tenant no tiene `ciclo_facturacion = "mensual"` o `plan_vence_en` es `NULL` → el pago queda `approved` **sin** tocar fechas y se registra una advertencia (FR-027).
  - Si el estado calculado es `bloqueada` → `inicio = now`, `fin = calculate_plan_vencimiento(now, "mensual")`.
  - En cualquier otro caso → `inicio = plan_vence_en` actual, `fin = calculate_plan_vencimiento(inicio, "mensual")`.
  - Se escriben `plan_iniciado_en`, `plan_vence_en`, y en el pago `period_start`, `period_end`, `paid_at = now`, `status = "approved"`.
- Una aprobación con estado `activa` (p. ej. el Super Admin renovó a mano mientras el link estaba pendiente) sigue la rama "otro caso" y acumula un mes: es el caso raro aceptado en la spec (el dinero ya entró).

---

## Decisión 10 — Un solo link pendiente por tenant, sin carreras

1. `SELECT … FROM shared.tenants WHERE id = :id FOR UPDATE` (mismo patrón que `enforce_plan_limit`) serializa las solicitudes del mismo tenant.
2. Bajo el lock: validar reglas (Decisión 4 + FR-012/013), buscar el pago `pending` del tenant, y si existe y no expiró, devolverlo (`200`, `reused = true`). Si expiró, marcarlo `expired` y hacer `flush()` antes del `INSERT` nuevo.
3. Red de seguridad: un **índice único parcial** `ux__subscription_payments__tenant_id__pending` sobre `(tenant_id) WHERE status = 'pending'`. En SQLite (tests) `FOR UPDATE` no existe, pero el índice sí protege: la segunda inserción falla con `IntegrityError`, que se atrapa y se resuelve releyendo el pago existente.
4. Las comprobaciones de credenciales (503) y de reglas (409) van **antes** de cualquier escritura.

Un barrido en el job periódico marca como `expired` los `pending` vencidos, para que el historial no muestre links caducados como pendientes.

---

## Decisión 11 — El webhook solo toca el esquema compartido

Con la tabla `subscription_payments` y `tenants` en `shared`, el webhook usa `with_db(None)` (sin tenant). Procesa dentro de **una transacción**: `SELECT … FROM subscription_payments WHERE gateway_reference = :ref FOR UPDATE` (serializa duplicados concurrentes), luego `SELECT … FROM tenants WHERE id = :id FOR UPDATE`, aplica y `commit`. El pago y las fechas cambian juntos o no cambian (FR-023).

Una aprobación **no genera notificación** (la spec define solo tres avisos), así que el webhook no necesita entrar al esquema del tenant. Esto corrige un supuesto de `spec.md`, que decía que el webhook emitiría notificaciones cambiando de esquema; solo lo hace el job de alertas (Decisión 12), y la spec se ajusta.

---

## Decisión 12 — Job de alertas

- **Disparador**: `IntervalTrigger(minutes=settings.SUBSCRIPTION_ALERT_INTERVAL_MINUTES)` (60 por defecto), el mismo patrón de `expire_promotions`: no un `CronTrigger` de hora fija, que se interpretaría en la zona del servidor (A-128).
- **Exclusión entre instancias**: lock en Redis, copia del patrón `_run_expire_promotions_with_lock`.
- **Recorrido**: `SELECT id, schema, timezone, plan_vence_en, ciclo_facturacion FROM shared.tenants WHERE plan_vence_en IS NOT NULL`, un tenant roto no detiene a los demás (como `sweep_orphan_sessions`).
- **Qué aviso corresponde** (FR-032): se toma **solo el del estado vigente** — `por_vencer → expiring`, `en_gracia → grace_started`, `bloqueada → blocked`, `activa → ninguno` — y se intenta con `_dispatch_once`. Tras una caída larga no se manda "vence en 2 días" a un tenant ya bloqueado.
- **Zona horaria (FR-030)**: los tramos son exactos (Decisión 4); la zona del tenant decide **cuándo se emite**. El aviso solo sale mientras la hora local del tenant esté dentro de la ventana `SUBSCRIPTION_ALERT_LOCAL_START_HOUR`–`SUBSCRIPTION_ALERT_LOCAL_END_HOUR` (8 a 20 por defecto), para no despertar a un ADMIN de madrugada; fuera de ella se espera al siguiente tick. Consecuencia aceptada: un aviso puede salir hasta ~12 h después de su umbral; el estado y el bloqueo en sí siguen siendo exactos.
- **Mismo tick**: marca `expired` los pagos `pending` cuyo `payment_link_expires_at` ya pasó (una sola sentencia `UPDATE`).
- **Registro**: se agrega al `start_scheduler()` y al mensaje de arranque.

**Supuesto a confirmar**: la ventana horaria 8–20 es una decisión de este plan para dar contenido a FR-030; si el negocio prefiere emitir sin ventana, basta fijar `0` y `24`.

---

## Decisión 13 — Despliegue seguro (D8) y riesgo sin cuenta de Wompi

- **Migración de datos aparte** del DDL (Principio VI): un script `app/scripts/grant_subscription_grace.py` con `--cutoff <ISO-UTC>` y `--apply` (sin `--apply` solo informa). Para todo tenant con `plan_vence_en < cutoff` fija `plan_vence_en = cutoff`, sin tocar `plan_iniciado_en`. Es **idempotente por construcción**: repetirlo con el mismo `cutoff` no encuentra tenants con `plan_vence_en < cutoff`. Imprime, por tenant, el valor anterior y el nuevo, para dejar rastro (el valor anterior se conserva en la salida y en `app.log`; no se guarda en base de datos).
- **Por qué mover `plan_vence_en` y no agregar un campo "gracia hasta"**: el estado, el guard y el recálculo quedan sin un segundo ingrediente. El costo es perder el valor histórico del vencimiento anterior, que es operativo (no un hecho contable como una factura) y queda en la salida del script. Alternativa rechazada: una columna `grace_override_until` en `tenants` — añade una rama a cada consumidor del estado por un caso de una sola vez.
- **Orden recomendado**: aplicar migraciones de esquema → ejecutar el script con `--cutoff` = instante actual → reiniciar la API con el código nuevo. Mientras corre, la API vieja sigue sirviendo (esos tenants ya estaban bloqueados por la regla vieja en los módulos con plan).
- **Riesgo sin Wompi**: si el código se despliega en producción **antes** de tener credenciales de Wompi, un tenant que venza no podrá pagar solo y, cumplidos 5 días, quedará bloqueado por completo (el Super Admin todavía puede renovarlo a mano, D4). **Recomendación**: o bien no activar esto en producción hasta tener la cuenta, o ejecutar el script de gracia con `--cutoff` el día que se configuren las llaves. No se agrega un interruptor de "no bloquear" porque crearía un tercer modo de comportamiento; si el negocio lo quiere, es una tarea chica (una variable de entorno que haga que el guard solo registre).

---

## Decisión 14 — Migración de Alembic

- **Cadena (actualizado 2026-11-19, al integrar `origin/develop`)**: arriba llegó la spec 162 (documentos legales) con tres migraciones encadenadas `8d09a031cba3 → e27442deb15b → e9ab58cbea91 → b1c9f4e7a3d2`. Para no dejar dos cabezas, mi primera revisión (`e0230fd88635`) cuelga de `b1c9f4e7a3d2` y la segunda (`a65d3ff9da49`) de la primera: **cadena lineal `8d09… → spec 162 → spec 161`, una sola cabeza**. Antes colgaba de `8d09a031cba3`. Ojo: `b1c9f4e7a3d2` **borra** la columna `tenant_legal_profiles.dias_retencion_datos`; no es de esta spec, pero viaja en el mismo `upgrade`.
- **Los dos archivos de fusión sin versionar** (`f2d755c229e8…`, `b0ba035937ba…`, del árbol local del usuario) eran fusiones sin ninguna instrucción (`upgrade` y `downgrade` vacíos) entre revisiones que ya son ancestros de `8d09a031cba3`: no cambian el esquema. **Nunca se usaron como padre** (quien clone el repositorio no los tiene) y no se tocaron. La base de desarrollo del usuario estaba estampada en `b0ba035937ba`; tras el pull ese archivo deja de ser necesario y Alembic no sabrá ubicar esa revisión, por lo que hay que re-estampar.
- **Procedimiento tras el pull, ensayado el 2026-11-19 sobre una copia de la base de desarrollo** (nunca sobre la real): retirar los dos archivos de fusión locales; `alembic stamp --purge 8d09a031cba3` (solo reescribe `alembic_version`, no toca esquema ni datos); `alembic upgrade head` aplica 5 pasos (3 de la spec 162 y 2 de la 161). Resultado verificado: una cabeza (`a65d3ff9da49`), mismos conteos de datos que antes (3 tenants, 12 usuarios, 49 notificaciones de `heladeria`). Sin re-estampar, `alembic current` falla con `Can't locate revision identified by 'b0ba035937ba'`.
- **Dos revisiones de esquema, no una** (cada una con una sola clase de cambio, Principio VI): `e0230fd88635` crea `shared.subscription_payments` con sus índices; `a65d3ff9da49` agrega, con `@for_each_tenant_schema`, `audience_role` y el índice único parcial a `notification_events` de cada esquema de tenant (se omite el esquema que aún no tiene la tabla, p. ej. `tenant_default`). Ambas con guardas `IF NOT EXISTS` / `_has_table` para poder reejecutarlas.
- **Reversión**: la de `a65d3ff9da49` borra primero las filas con `audience_role` (los avisos de suscripción, transitorios y regenerables) y luego el índice y la columna, para que los avisos del ADMIN no pasen a verse para todo el personal; la de `e0230fd88635` elimina la tabla nueva. Ensayado en copia: bajar mis dos revisiones y volver a subirlas deja el esquema idéntico.
- **Tablas nuevas y `create_all`**: `initialize_database()` solo crea las tablas compartidas en una base nueva (`get_shared_metadata`) y estampa el head; una base existente avanza únicamente con Alembic. Un tenant nuevo recibe sus tablas por `tenant_create`, que usa los modelos, así que `audience_role` queda incluida sin más.

---

## Decisión 15 — Configuración y secretos

Nuevas entradas en `Settings` (todas opcionales o con valor por defecto, para no romper el arranque ni las suites, que rellenan solo las variables sin default):

| Variable | Por defecto | Uso |
|---|---|---|
| `WOMPI_PUBLIC_KEY` | `None` | Llave pública en la URL del checkout. |
| `WOMPI_INTEGRITY_SECRET` | `None` | Firma de integridad. |
| `WOMPI_EVENTS_SECRET` | `None` | Checksum de los eventos. |
| `WOMPI_CHECKOUT_URL` | `https://checkout.wompi.co/p/` | Base del checkout. |
| `WOMPI_REDIRECT_URL_TEMPLATE` | `https://{host}/` | Retorno por tenant. |
| `WOMPI_LINK_TTL_HOURS` | `24` | Vigencia del link. |
| `SUBSCRIPTION_ALERT_INTERVAL_MINUTES` | `60` | Frecuencia del job. |
| `SUBSCRIPTION_ALERT_LOCAL_START_HOUR` / `_END_HOUR` | `8` / `20` | Ventana local de emisión. |

Los secretos nunca se devuelven en respuestas, se escriben en logs ni en `NotificationEvent`; el registro de advertencias del webhook incluye `reference` y `transaction.id`, nunca el cuerpo completo. `.env.example` se actualiza con las variables nuevas (sin valores reales).

---

## Decisión 16 — Historial y panel Super Admin

- `GET /plan/subscription/payments`: `require_tenant_admin`, mismo `get_db` del tenant, consulta sobre `shared.subscription_payments` filtrada **siempre** por `tenant.id` resuelto de `get_tenant` (nunca por parámetro). Paginación `page`/`size` con `{items, total, page, size}`, igual que `/notifications`; orden `created_at DESC, id DESC`.
- `GET /super-admin/tenants/{tenant_id}/subscription-payments`: nuevo sub-router incluido en el router de Super Admin, que ya aplica `get_current_super_admin` a todas sus rutas y usa el manejo de errores estandarizado del prefijo `/api/v1/super-admin` (spec 068); un `tenant_id` inexistente responde `404` con ese formato.
- Ninguno expone `gateway_transaction_id`, la firma ni nada de la pasarela más allá de `gateway` y `gateway_reference` (FR-035).

---

## Decisión 17 — Estrategia de pruebas (sin cuenta de Wompi)

- Las suites del proyecto son `unittest` sobre SQLite en memoria (`python -m unittest discover -s app/characterization_tests -p 'test_*.py' -v`). Las pruebas nuevas siguen ese precedente (como `test_plan_expiration.py`, que es de "nueva funcionalidad") y se agregan `subscription_payments` a `_TABLE_NAMES` de `plan_fixtures.py`.
- **Firmas**: la de integridad se prueba contra el **vector de la documentación** (verificado). El checksum de eventos se prueba con un auxiliar de test que aplica la fórmula documentada; como el ejemplo de la doc no reproduce, no se usa como vector (Decisión 1).
- **Tiempo**: `now` inyectable en las funciones puras; los endpoints se prueban llamando a las funciones de servicio con la sesión de prueba, como hacen las suites existentes.
- **Concurrencia real** (dos solicitudes simultáneas, `FOR UPDATE`, índice parcial bajo PostgreSQL): no se puede probar en SQLite; se cubre con la verificación manual de `quickstart.md` contra la base de desarrollo.
- **No se puede probar sin cuenta**: la fórmula real del checksum de eventos, el host de Sandbox, la aplicación de `expiration-time` por parte de Wompi y la URL de retorno. Quedan como una tarea explícita al final de `tasks.md` (FR-041).

---

## Decisión 18 — Sin dependencias nuevas

Todo se resuelve con la biblioteca estándar y paquetes ya presentes (`hashlib`, `hmac`, `urllib.parse`, `decimal`, `uuid`, `dateutil`, APScheduler, Redis, FastAPI, SQLAlchemy, Alembic). Principio IX: no hay dependencia que justificar.
