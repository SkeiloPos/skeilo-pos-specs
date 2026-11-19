# Quickstart: validar la suscripción y el pago por link de Wompi

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | Guía de validación de punta a punta; no contiene la implementación.

Todo se valida **sin cuenta de Wompi**: las firmas las calcula el propio escenario con secretos de prueba. La prueba contra el Sandbox real es la última sección y sigue pendiente.

## 0. Prerrequisitos

- `pos-backend` en una rama nueva creada desde `develop` con la convención del Principio XIV, p. ej. `feat/161-subscription-wompi-payment`. La rama se crea antes de tocar código.
- **Haber hecho `git pull` de `develop`** (trae la spec 162). Tu `.env` necesita la variable nueva `CONSENT_IP_HASH_SALT` (la spec 162 la exige; ver `.env.example`). Si tu rama tiene cambios sin commit, `git pull` se negará en 5 archivos que ambos lados modifican (`.env.example`, `app/core/config.py`, `app/main.py`, `app/models/__init__.py`, `app/api/v1/super_admin/router.py`): confirma o guarda tus cambios y resuelve la fusión (en todos son líneas añadidas por ambos lados; se conservan las dos).
- **Estado de Alembic en la base de desarrollo** (ensayado en copia el 2026-11-19; `research.md` Decisión 14): retira los dos archivos de fusión locales sin versionar (`alembic/versions/f2d755c229e8_…` y `alembic/versions/b0ba035937ba_…`), luego `alembic stamp --purge 8d09a031cba3` y `alembic upgrade head`. Cuidado: la migración `b1c9f4e7a3d2` de la spec 162 **borra** la columna `tenant_legal_profiles.dias_retencion_datos`. Haz una copia antes (`pg_dump`) si esa base importa.
- Variables de prueba (solo en tu `.env` local, nunca en el repositorio):

```bash
WOMPI_PUBLIC_KEY=pub_test_local
WOMPI_INTEGRITY_SECRET=test_integrity_local
WOMPI_EVENTS_SECRET=test_events_local
```

- API corriendo de forma nativa con `uvicorn` (según las notas del proyecto, en Docker no alcanza PostgreSQL por los hosts del `.env`), Redis y PostgreSQL arriba. Un tenant de desarrollo con un ADMIN y un CASHIER, y un plan con `precio_mensual` definido.
- Aplicar migraciones: `alembic upgrade head`. Verificar: existe `shared.subscription_payments` y `notification_events.audience_role` en `tenant_default` y en cada esquema de tenant.

## 1. Pruebas automáticas

```bash
cd pos-backend
python -m unittest discover -s app/characterization_tests -p 'test_subscription_*.py' -v
python -m unittest app.characterization_tests.test_notifications_audience -v
# Regresión de planes y notificaciones (sin fallos nuevos):
python -m unittest app.characterization_tests.test_plan_expiration \
                   app.characterization_tests.test_plan_summary \
                   app.characterization_tests.test_module_not_in_plan_error \
                   app.characterization_tests.test_tenant_plan_assignment \
                   app.characterization_tests.test_notifications \
                   app.characterization_tests.test_scheduler -v
```

Esperado: todo en verde. Las pruebas cubren las fronteras de 48 h / 120 h, el guard y sus exentas, la construcción y la reutilización del link, cada ramal del webhook, la audiencia, la idempotencia de avisos y el script de gracia (SC-001 a SC-012). No correr la suite completa del backend en paralelo con la del frontend.

## 2. Escenario A — estado de la suscripción (US1)

Con `psql`, fijar el vencimiento del tenant de prueba (usar `BEGIN … ROLLBACK` cuando solo se quiera mirar) y consultar el plan como cualquier usuario:

```bash
curl -s -H "x-tenant-host: $HOST" -H "Authorization: Bearer $TOKEN" http://localhost:8000/api/v1/plan | jq '{subscription_state, dias_restantes, fecha_limite_pago, vencido}'
```

| `plan_vence_en` (respecto a ahora) | `subscription_state` | `vencido` |
|---|---|---|
| `+3 días` | `activa` | `false` |
| `+47 h` | `por_vencer` | `false` |
| `−1 h` | `en_gracia` | `false` |
| `−119 h` | `en_gracia` | `false` |
| `−121 h` | `bloqueada` | `true` |
| `NULL` | `activa` (sin días ni fecha) | `false` |

## 3. Escenario B — gracia y bloqueo total (US2)

1. Con el tenant `en_gracia` (−1 h): crear una venta, abrir caja, listar productos, abrir el menú QR → todo `2xx`.
2. Mover a `bloqueada` (−121 h): repetir las mismas llamadas y `GET /menu` con un comensal → `403` con `"code": "subscription_blocked"`.
3. Comprobar que siguen respondiendo: `POST /auth/login`, `GET /auth/refresh-token`, `GET /auth/logout`, `GET /plan`, `GET /notifications`, `POST /realtime/ticket`.
4. Comprobar que el panel Super Admin, `GET /health` y `POST /webhooks/wompi` no se ven afectados.

## 4. Escenario C — link de pago (US3)

```bash
curl -s -X POST -H "x-tenant-host: $HOST" -H "Authorization: Bearer $ADMIN_TOKEN" http://localhost:8000/api/v1/plan/subscription/payment-link | jq
```

| Situación | Esperado |
|---|---|
| Tenant `por_vencer`, `en_gracia` o `bloqueada`, ADMIN | `201`, `amount` = `precio_mensual`, expira a las 24 h |
| Repetir la llamada | `200`, mismo `payment_id` y `reused: true` |
| Con el token de un CASHIER | `403` |
| Tenant `activa` | `409` `reason: already_active` |
| `plan_vence_en` `NULL` / ciclo `anual` / plan sin precio mensual | `409` con `no_expiry` / `unsupported_cycle` / `no_price` |
| Sin las variables `WOMPI_*` (reiniciar la API sin ellas) | `503` `payment_gateway_not_configured`, y `SELECT count(*) FROM shared.subscription_payments` no aumenta |
| Link expirado (`UPDATE … SET payment_link_expires_at = now() - interval '1 minute'`) y volver a pedir | El anterior pasa a `expired` y se crea uno nuevo |

Verificar la firma del link generado (la cadena de `expiration-time` debe coincidir con la de la URL):

```python
import hashlib
# reference, cents y exp salen de la URL del link; el secreto es el de tu .env
print(hashlib.sha256(f"{reference}{cents}COP{exp}test_integrity_local".encode()).hexdigest())
# debe ser igual a signature:integrity
```

Concurrencia (solo en PostgreSQL real): lanzar dos `POST` simultáneos con `xargs -P2` y comprobar que `SELECT count(*) FROM shared.subscription_payments WHERE tenant_id = X AND status = 'pending'` da 1 y que ambos recibieron el mismo `payment_id`.

## 5. Escenario D — confirmación por webhook (US4)

**Con el simulador del repositorio** (sin cuenta de Wompi): `python -m app.scripts.simulate_wompi_event --reference <gateway_reference> --amount-cents <amount×100> --secret <WOMPI_EVENTS_SECRET> --post http://localhost:8000/api/v1/webhooks/wompi` firma el evento y lo envía; sin `--post` solo lo imprime. Otros resultados: `--status DECLINED|ERROR|VOIDED|PENDING`, y `--tamper` para una firma alterada. Firma con la misma función con que el servidor verifica, así que prueba el flujo pero **no** que la fórmula coincida con la de Wompi (eso solo lo confirma un evento real de Sandbox, §10).

Helper manual equivalente, para firmar un evento de prueba con la fórmula documentada (no es el código de la funcionalidad):

```python
import hashlib, json, sys, time
secret = "test_events_local"
ref, tx, status, cents = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
ts = int(time.time())
checksum = hashlib.sha256(f"{tx}{status}{cents}{ts}{secret}".encode()).hexdigest()
print(json.dumps({"event": "transaction.updated",
  "data": {"transaction": {"id": tx, "status": status, "amount_in_cents": cents, "reference": ref, "currency": "COP"}},
  "environment": "test", "timestamp": ts, "sent_at": "2026-11-30T14:12:09.000Z",
  "signature": {"properties": ["transaction.id", "transaction.status", "transaction.amount_in_cents"], "checksum": checksum}}))
```

```bash
python firma_evento.py SKP-<hex> TX-1 APPROVED 8990000 | curl -s -X POST -H "Content-Type: application/json" -d @- http://localhost:8000/api/v1/webhooks/wompi
```

| Caso | Preparación | Esperado |
|---|---|---|
| Aprobado, `por_vencer` o `en_gracia` | pago `pending` del tenant | `200 processed`; `plan_iniciado_en` = vencimiento anterior; `plan_vence_en` = +1 mes; pago `approved` con `paid_at`, `period_start`, `period_end`; `GET /plan` → `activa` |
| Aprobado, `bloqueada` | tenant −121 h | `plan_iniciado_en` = ahora; `plan_vence_en` = ahora + 1 mes; la siguiente petición operativa ya no da `403` |
| Mismo evento otra vez | repetir el curl | `200 duplicate`; fechas sin cambios |
| Firma alterada | cambiar un carácter del checksum | `401`; nada cambia |
| `DECLINED` | pago `pending` | pago `rejected`; fechas sin cambios; se puede pedir un link nuevo |
| `VOIDED` tras aprobado | pago `approved` | pago `voided`; fechas sin cambios |
| `APPROVED` sobre `expired` | marcar el pago `expired` | `200 processed`; se aplica igual |
| Monto distinto | `cents` ≠ `amount*100` | `200 ignored`; pago intacto |
| Referencia desconocida | `SKP-000…` | `200 ignored` |
| Sin `WOMPI_EVENTS_SECRET` | reiniciar sin la variable | `401` |

## 6. Escenario E — alertas (US5)

Ejecutar la evaluación una vez a mano (la misma función que corre el planificador):

```bash
python -c "from app.core.scheduler import evaluate_subscription_alerts as f; print(f())"
```

1. Tenant `por_vencer`, hora local del tenant dentro de 8–20 → se crea **un** `subscription.expiring`. Repetir el comando 5 veces → sigue habiendo uno.
2. `GET /notifications` con el token de un ADMIN → lo ve. Con el de un CASHIER y el de un MESERO → **no** lo ven. `POST /notifications/{id}/attend` con el CASHIER → `404`.
3. Con un cliente SSE de ADMIN y otro de CASHIER abiertos (ticket de `POST /realtime/ticket`), disparar el job: solo el del ADMIN recibe `notification.created`.
4. Pasar a `en_gracia` → `subscription.grace_started`; a `bloqueada` → `subscription.blocked` (el ADMIN lo lee aunque el tenant esté bloqueado).
5. Tenant `bloqueada` sin avisos previos → solo se emite `subscription.blocked`.
6. Fuera de la ventana local (p. ej. fijar `SUBSCRIPTION_ALERT_LOCAL_END_HOUR=0` y reiniciar) → no se emite nada.
7. Tras un pago aprobado, forzar un nuevo `por_vencer` → un aviso nuevo.
8. Una notificación `order.created` sigue llegando a todo el personal.

## 7. Escenario F — historial (US6)

- ADMIN: `GET /plan/subscription/payments?page=1&size=10` → solo pagos de su tenant, del más reciente al más antiguo, con `total`/`page`/`size`. Con un CASHIER → `403`.
- Aislamiento: crear pagos de un segundo tenant y comprobar que no aparecen.
- Super Admin (host de plataforma): `GET /api/v1/super-admin/tenants/{id}/subscription-payments` → los pagos de ese tenant; un id inexistente → `404` con el formato estandarizado.

## 8. Escenario G — despliegue sobre tenants ya vencidos (US7)

```bash
python -m app.scripts.grant_subscription_grace --cutoff "$(date -u +%Y-%m-%dT%H:%M:%S)"            # solo informa
python -m app.scripts.grant_subscription_grace --cutoff "<mismo valor>" --apply                       # aplica
```

1. Con tenants de prueba vencidos hace 40 días y hace 3 h, y otro vigente: el informe lista solo los dos vencidos con su valor anterior y el nuevo.
2. Tras `--apply`: los dos vencidos pasan a `en_gracia` con ~120 h por delante; el vigente no cambia.
3. Repetir `--apply` con el **mismo** `--cutoff`: no modifica nada.

## 9. Reversión

1. Exportar los pagos: `\copy shared.subscription_payments TO 'subscription_payments.csv' CSV HEADER`.
2. (Ya no es un paso manual) La reversión de la revisión de `audience_role` borra por sí misma los avisos con audiencia antes de quitar la columna.
3. `alembic downgrade -1`. Verificar que la tabla y la columna ya no existen y que `GET /notifications` funciona.

## 10. Pendiente: prueba real contra Wompi Sandbox (FR-041)

Se hace cuando exista la cuenta y las credenciales de Sandbox. Hasta entonces la funcionalidad **no se da por verificada de punta a punta**.

- [ ] Crear la cuenta y obtener `pub_test_…`, `test_integrity_…` y `test_events_…`.
- [ ] Confirmar el host del checkout de Sandbox y, si cambia, ajustar `WOMPI_CHECKOUT_URL`.
- [ ] Pagar un link real con una tarjeta de prueba y comprobar que Wompi **acepta** la firma de integridad y la `expiration-time`.
- [ ] Capturar el primer evento real: verificar que **nuestro** checksum coincide con el suyo (fórmula y orden de `properties`) y qué `properties` firma realmente. Es la comprobación que el ejemplo de la documentación no permitió hacer.
- [ ] Confirmar la URL de eventos registrada en el dashboard de Sandbox (distinta de la de Producción).
- [ ] Comprobar si Wompi hace cumplir `expiration-time` (abrir un link vencido) y qué ve el cliente.
- [ ] Provocar un `DECLINED` y reintentar en el mismo checkout; confirmar el comportamiento esperado de `rejected → approved`.
- [ ] Confirmar la redirección: `redirect-url` con `?id=` y la página de retorno de cada tenant.
- [ ] Repetir la secuencia con credenciales de Producción antes de activar el cobro real.
