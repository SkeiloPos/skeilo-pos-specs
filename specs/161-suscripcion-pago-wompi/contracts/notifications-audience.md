# Contrato: Audiencia por rol en las notificaciones y avisos de suscripción

**Spec**: [../spec.md](../spec.md) | **Research**: [../research.md](../research.md) Decisiones 7, 8 y 12 | Extiende el módulo de notificaciones de la spec 077 sin cambiar el comportamiento de los eventos actuales.

## 1. Modelo

`notification_events.audience_role` (`String(20)`, `NULL`): rol destinatario. `NULL` = todo el personal (todos los eventos existentes).

## 2. Eventos nuevos

| `event_type` | Cuándo | `related_entity_type` | `audience_role` |
|---|---|---|---|
| `subscription.expiring` | Estado `por_vencer` (faltan 48 h o menos) | `subscription` | `ADMIN` |
| `subscription.grace_started` | Estado `en_gracia` | `subscription` | `ADMIN` |
| `subscription.blocked` | Estado `bloqueada` | `subscription` | `ADMIN` |

`related_entity_id = uuid5(NAMESPACE, "<event_type>|<plan_vence_en en ISO>")`. `payload`:

```json
{
  "plan_vence_en": "2026-12-01T05:00:00",
  "fecha_limite_pago": "2026-12-06T05:00:00",
  "dias_restantes": 2,
  "fecha_limite_pago_local": "6 de diciembre"
}
```

`fecha_limite_pago_local` se calcula **al emitir**, con la zona horaria del tenant (`ZoneInfo(tenant.timezone)`), porque `summarize(event)` no recibe el tenant; el resto de fechas del `payload` van en UTC.

Texto de resumen (`summarize`), en español de Colombia:

| `event_type` | Resumen |
|---|---|
| `subscription.expiring` | `Tu suscripción vence en {dias_restantes} día(s). Paga para evitar interrupciones.` |
| `subscription.grace_started` | `Tu suscripción venció. Tienes hasta el {fecha_limite_pago_local} para pagar sin interrupciones.` |
| `subscription.blocked` | `Tu suscripción está bloqueada. Paga tu plan para volver a operar.` |

La fecha del resumen sale ya formateada en la zona horaria del tenant (`fecha_limite_pago_local`); el resto del `payload` conserva UTC.

## 3. Superficies afectadas

| Superficie | Regla con `audience_role` |
|---|---|
| `GET /notifications` | Devuelve solo eventos con `audience_role IS NULL` o igual al rol del usuario. Vale igual para `after_id`, `only_pending`, `total` y paginación. |
| `POST /notifications/{id}/attend` | Un evento fuera de la audiencia responde `404`. |
| Tiempo real (`GET /realtime/stream`, staff) | Canal por rol `staff:<rol en minúsculas>` (p. ej. `staff:admin`). El ticket del staff lleva el rol y `resolve_staff` suscribe a `{staff, staff:<rol>}`. |
| Publicación en tiempo real | Con audiencia, `notification.created` se publica **solo** en `staff:<audiencia>`; sin audiencia, en `staff` como hoy. |
| Push del navegador | Con audiencia, solo a las `PushSubscription` activas de usuarios con ese rol. Sin audiencia, a todas como hoy. |
| Preferencias de canal por tipo de evento | Sin cambios; ausencia de fila = habilitado. |

## 4. Emisión (job periódico)

- Frecuencia: cada `SUBSCRIPTION_ALERT_INTERVAL_MINUTES` (60), con lock de Redis entre instancias.
- Para cada tenant con `plan_vence_en` no nulo se calcula el estado vigente y se intenta emitir **solo** el aviso de ese estado (`activa` no emite).
- Solo se emite dentro de la ventana local del tenant (`SUBSCRIPTION_ALERT_LOCAL_START_HOUR`–`_END_HOUR`, 8 a 20 por defecto); fuera de ella se espera al siguiente tick.
- Idempotencia: índice único parcial `(event_type, related_entity_id)` para `subscription.%`; el segundo intento no inserta nada (`_dispatch_once` atrapa `IntegrityError`).
- Tras un pago aprobado `plan_vence_en` cambia, también `related_entity_id`: los tres avisos vuelven a ser posibles en el ciclo nuevo.
- Fallo de un canal (push, tiempo real): se registra y no impide la emisión ni el resto de tenants.

## 5. Casos que las pruebas deben cubrir

1. Un ADMIN ve el aviso; un cajero, un mesero y cocina **no** lo ven en el listado, en el canal en tiempo real ni en el push.
2. Las notificaciones `order.created` y `payment.completed` siguen llegando a todo el personal, sin cambios.
3. Correr el job 10 veces seguidas con el mismo estado genera un solo aviso; correrlo en dos sesiones simultáneas también.
4. Tras un pago aprobado (nuevo `plan_vence_en`), el siguiente `por_vencer` emite un aviso nuevo.
5. Tenant `bloqueada` tras una caída del job: se emite `subscription.blocked` y no `subscription.expiring`.
6. Fuera de la ventana horaria local no se emite; dentro, sí.
7. Un `attend` de un cajero sobre un aviso de ADMIN devuelve `404`.
8. Tenant sin ningún ADMIN activo: el evento se registra igualmente.
