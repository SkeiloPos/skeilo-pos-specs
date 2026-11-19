# Contrato: API de suscripción del tenant

**Spec**: [../spec.md](../spec.md) | Prefijo común de la API: `/api/v1`. Todas las rutas del tenant exigen la cabecera `x-tenant-host` y `Authorization: Bearer <token>` (como el resto de la API del tenant). Los timestamps salen en UTC con offset explícito `+00:00` (`UtcDatetime`, spec 138).

Convención de errores: `detail` es **siempre un `str`** (como el resto de la API); los errores con significado de negocio agregan `code` (y `reason` cuando aplica) como campos hermanos de `detail`.

---

## 1. `GET /plan` (existente, ampliado)

**Quién**: cualquier usuario autenticado del tenant, también con el tenant bloqueado (ruta exenta).
**Cambio**: tres campos nuevos y un campo existente con significado ajustado. El resto de la respuesta no cambia.

```json
{
  "plan_name": "Pro",
  "ciclo_facturacion": "mensual",
  "plan_vence_en": "2026-12-01T05:00:00+00:00",
  "vencido": false,
  "subscription_state": "por_vencer",
  "dias_restantes": 2,
  "fecha_limite_pago": "2026-12-06T05:00:00+00:00",
  "resources": { "mesas": { "used": 3, "limit": 10 } },
  "modules": { "inventario": true, "promociones": false, "cocina": true }
}
```

| Campo | Tipo | Regla |
|---|---|---|
| `subscription_state` | `"activa" \| "por_vencer" \| "en_gracia" \| "bloqueada"` | FR-001; ver `research.md` Decisión 4 |
| `dias_restantes` | `integer \| null` | Hasta el vencimiento; en gracia, hasta `fecha_limite_pago`; `0` si bloqueada; `null` sin vencimiento |
| `fecha_limite_pago` | `datetime \| null` | `plan_vence_en + 120 h`; `null` sin vencimiento |
| `vencido` | `boolean` | **Ajustado**: `true` solo si `subscription_state == "bloqueada"` (antes: `plan_vence_en` pasado) |

Sin vencimiento: `subscription_state = "activa"`, `dias_restantes = null`, `fecha_limite_pago = null`, `plan_vence_en = null`.

---

## 2. `POST /plan/subscription/payment-link`

**Quién**: rol `ADMIN` del tenant (`require_tenant_admin`). Cualquier otro rol → `403`. Ruta exenta del bloqueo.
**Cuerpo**: ninguno.

**Respuestas**

| Código | Cuándo | Cuerpo |
|---|---|---|
| `201` | Se creó un pago pendiente nuevo | `PaymentLinkResponse` con `reused = false` |
| `200` | Ya había un pendiente vigente (no expirado) | `PaymentLinkResponse` con `reused = true` |
| `403` | El usuario no es `ADMIN` | `{"detail": "Tenant admin access required"}` |
| `409` | El tenant no puede pagar por este flujo | `{"detail": <texto>, "code": "subscription_not_payable", "reason": <ver tabla>}` |
| `503` | Faltan las llaves de Wompi | `{"detail": <texto>, "code": "payment_gateway_not_configured"}` — no se crea ningún pago |

`reason` de los `409`:

| `reason` | Condición | Texto base |
|---|---|---|
| `already_active` | Estado `activa` (ciclo en curso ya pagado) | "Tu suscripción está al día; podrás pagar la siguiente cuando falten 48 horas para vencer." |
| `no_expiry` | `plan_vence_en` es `NULL` | "Tu plan no tiene vencimiento; no requiere pago." |
| `unsupported_cycle` | `ciclo_facturacion` distinto de `mensual` | "Tu plan se renueva con la plataforma; contacta a soporte." |
| `no_price` | El plan no tiene `precio_mensual` | "Tu plan no tiene un precio mensual definido; contacta a soporte." |

**`PaymentLinkResponse`**

```json
{
  "payment_id": "8f0c6f0e-1a4b-4a43-9d51-2c4d6c1f9e10",
  "status": "pending",
  "amount": "89900.00",
  "currency": "COP",
  "gateway_reference": "SKP-8f0c6f0e1a4b4a439d512c4d6c1f9e10",
  "payment_link_url": "https://checkout.wompi.co/p/?public-key=...&currency=COP&amount-in-cents=8990000&reference=SKP-...&signature%3Aintegrity=...&redirect-url=...&expiration-time=2026-11-18T15:30:00.000Z",
  "payment_link_expires_at": "2026-11-18T15:30:00+00:00",
  "reused": false
}
```

**Orden de las comprobaciones** (la primera que falla corta, y ninguna escribe antes de aprobarse todas): rol → llaves configuradas (503) → estado/ciclo/precio (409) → bloqueo del tenant y búsqueda del pendiente → creación.

**Garantías**: un solo `pending` por tenant (índice único parcial + bloqueo de fila); el link expirado se marca `expired` antes de crear uno nuevo; `amount` es el `precio_mensual` del plan vigente al momento de pedirlo.

---

## 3. `GET /plan/subscription/payments`

**Quién**: rol `ADMIN` del tenant. Otros roles → `403`. Ruta exenta del bloqueo.
**Query**: `page` (≥ 1, por defecto 1), `size` (1–100, por defecto 20).
**Aislamiento**: el tenant sale **siempre** de `x-tenant-host`; no existe parámetro de tenant.
**Orden**: `created_at DESC, id DESC`.

```json
{
  "items": [
    {
      "id": "8f0c6f0e-1a4b-4a43-9d51-2c4d6c1f9e10",
      "status": "approved",
      "amount": "89900.00",
      "currency": "COP",
      "ciclo_facturacion": "mensual",
      "gateway": "wompi",
      "gateway_reference": "SKP-8f0c6f0e1a4b4a439d512c4d6c1f9e10",
      "requested_by_user_id": "c3f1…",
      "period_start": "2026-12-01T05:00:00+00:00",
      "period_end": "2027-01-01T05:00:00+00:00",
      "paid_at": "2026-11-30T14:12:09+00:00",
      "payment_link_expires_at": "2026-12-01T05:30:00+00:00",
      "created_at": "2026-11-30T14:05:00+00:00",
      "updated_at": "2026-11-30T14:12:09+00:00"
    }
  ],
  "total": 1,
  "page": 1,
  "size": 20
}
```

No se exponen `payment_link_url`, `gateway_transaction_id` ni nada de la firma (FR-035).

---

## 4. `GET /super-admin/tenants/{tenant_id}/subscription-payments`

**Quién**: Super Admin (`get_current_super_admin`, ya aplicado a todo el router de Super Admin). No usa `x-tenant-host`: el tenant va en la ruta y se resuelve contra `shared.tenants`.
**Query y respuesta**: idénticas a la sección 3.
**Errores**: `404` si el tenant no existe, con el formato estandarizado del prefijo `/api/v1/super-admin` (spec 068); `401`/`403` según la autenticación existente del panel.
