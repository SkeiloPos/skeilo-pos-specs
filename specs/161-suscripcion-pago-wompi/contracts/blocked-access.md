# Contrato: Bloqueo por suscripción vencida

**Spec**: [../spec.md](../spec.md) | **Research**: [../research.md](../research.md) Decisiones 4–6

Con el tenant en estado `bloqueada` (pasadas 120 h desde `plan_vence_en` sin pago aprobado), toda operación que resuelve al tenant se rechaza, salvo las exentas. Con el estado `activa`, `por_vencer` o `en_gracia`, el guard no actúa (FR-005).

## 1. Respuesta de rechazo

`HTTP 403`

```json
{
  "detail": "Tu plan venció. Debe renovarse para seguir usando el sistema.",
  "code": "subscription_blocked"
}
```

- `detail` es un `str` con **el mismo texto de siempre** del 403 por plan vencido (spec 033), que contiene "venci": solo gana `code`. El frontend decide su propio mensaje a partir del `code`.
- `code` es estable y distingue este rechazo del de módulo fuera del plan (`MODULE_NOT_IN_PLAN`, con `module`), de los de rol y de los de límite de recursos.
- El mismo cuerpo sirve para `ensure_plan_not_expired`, `enforce_plan_limit` y `require_module_access` (un único error tipado, `SubscriptionBlockedError`, con su manejador registrado junto al de `ModuleNotInPlanError`).
- Nota: el `code` va en minúsculas por decisión de la spec; el existente `MODULE_NOT_IN_PLAN` va en mayúsculas. Es una diferencia de estilo conocida, no un error.

## 2. Qué se bloquea y qué no

El guard vive en los dos puntos por donde todo tenant se resuelve: `get_tenant` (cabecera `x-tenant-host`) y `resolve_tenant_by_id` (comensal por token).

| Ruta o grupo | Bloqueada | Motivo / mecanismo |
|---|---|---|
| `/auth/*` (login, refresh-token, logout, forgot/reset/change-password) | **No** | Exenta por prefijo. El inicio de sesión nunca se bloquea (FR-010). |
| `/bootstrap` | **No** | Exenta; además usa `get_optional_tenant`. |
| `GET /plan` y `/plan/subscription/*` | **No** | Exenta por prefijo `/plan`. |
| `/notifications/*` | **No** | Exenta por prefijo. |
| `/legal/platform-acceptance/*` (spec 162) | **No** | Exenta por prefijo de dos segmentos: la aceptación de documentos de plataforma por el ADMIN no es una operación del negocio. |
| `/legal/*` (resto: perfil y documento legal del tenant, spec 162) | **Sí** | Configuración del negocio. `legal` es el único segmento mixto. |
| `POST /realtime/ticket` y `GET /realtime/stream` del staff | **No** | El ticket pasa por `get_tenant` bajo el prefijo exento; el stream del staff no resuelve tenant. |
| `GET /realtime/stream` del comensal | **Sí** | Pasa por `resolve_tenant_by_id`, sin exenciones. |
| `/super-admin/*`, `/health`, `/webhooks/*` | **No** | No tienen tenant: el guard no se ejecuta. |
| `/menu`, `/cart`, `/table-sessions` (comensal por QR) | **Sí** | FR-006: el comensal también queda bloqueado. |
| `/orders`, `/sales`, `/cash`, `/invoices`, `/categories`, `/presentations`, `/option-groups`, `/options`, `/variants`, `/products`, `/inventory`, `/unit-measures`, `/unit-measure-groups`, `/promotions`, `/reports`, `/users`, `/invitations`, `/tenant`, `/uploads`, `/audit-logs` | **Sí** | Cualquier ruta que resuelva tenant y no esté exenta. |

**Regla por defecto**: una ruta nueva que use `get_tenant` queda protegida sin hacer nada; para eximirla hay que agregar su prefijo a la lista de exentas.

## 3. Cómo se decide la exención

- Se toma `request.scope["route"].path_format` (o, si no hay ruta, `request.url.path`), se le quita el prefijo `/api/v1` y se compara por prefijo con `("/auth", "/bootstrap", "/plan", "/notifications", "/realtime")`. Es el mismo mecanismo que ya usa el alcance del rol Mesero.
- `resolve_tenant_by_id` no recibe `request`, así que no tiene exenciones: es el camino exclusivo del comensal.

## 4. Casos que las pruebas deben cubrir

1. Tenant en gracia: operaciones de ventas, caja, órdenes, catálogo, reportes y módulos del plan funcionan.
2. Tenant bloqueado: las mismas operaciones y la carta pública por QR responden `403` con `code = "subscription_blocked"`.
3. Tenant bloqueado: login, refresh, logout, `GET /plan`, `POST /plan/subscription/payment-link`, `GET /plan/subscription/payments`, `GET /notifications` y `POST /realtime/ticket` responden con normalidad.
4. Fronteras exactas: `vence + 119 h 59 min 59 s` → no bloquea; `vence + 120 h` → bloquea.
5. Tras un pago aprobado, la petición inmediata siguiente ya no recibe `403` (sin nuevo inicio de sesión).
6. El comensal con un token válido de un tenant bloqueado recibe `403` al abrir el stream y al enviar un carrito.
7. `enforce_plan_limit` y `require_module_access` siguen rechazando con un `403` cuyo texto contiene "venci", ahora solo en `bloqueada`.
