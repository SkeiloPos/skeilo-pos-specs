# Contrato: Webhook de Wompi y construcción del link

**Spec**: [../spec.md](../spec.md) | **Research**: [../research.md](../research.md) Decisiones 1–3 y 9–11

Fuente de las fórmulas: documentación pública de Wompi Colombia (Web Checkout y Eventos), leída el 2026-11-17. **Pendiente de confirmar con una cuenta de Sandbox**: el checksum real de un evento, el host del checkout de Sandbox y la aplicación de `expiration-time` (tarea explícita, FR-041).

---

## 1. Link de pago (Web Checkout firmado)

Dirección base: `WOMPI_CHECKOUT_URL` (por defecto `https://checkout.wompi.co/p/`). Parámetros por query, codificados con `urlencode`:

| Parámetro | Valor |
|---|---|
| `public-key` | `WOMPI_PUBLIC_KEY` |
| `currency` | `COP` |
| `amount-in-cents` | `int(Decimal(amount) * 100)` |
| `reference` | `SKP-<uuid del pago en hex>` (36 caracteres) |
| `signature:integrity` | Ver abajo |
| `redirect-url` | `WOMPI_REDIRECT_URL_TEMPLATE.format(host=tenant.host)` |
| `expiration-time` | `creación + WOMPI_LINK_TTL_HOURS`, formato `YYYY-MM-DDTHH:MM:SS.000Z` (UTC) |

**Firma de integridad** (SHA-256 hexadecimal en minúsculas, sin separadores):

```
sha256( reference + amount_in_cents + currency + expiration_time + WOMPI_INTEGRITY_SECRET )
```

La cadena de `expiration-time` que entra en la firma es **exactamente** la que va en la URL.

**Vector de prueba verificado** (de la documentación de Wompi, caso sin `expiration-time`):

```
entrada : sk8-438k4-xmxm392-sn2m2490000COPprod_integrity_Z5mMke9x0k8gpErbDqwrJXMqsI6SFli6
sha256  : 37c8407747e595535433ef8f6a811d853cd943046624a0ec04662b17bbf33bf5
```

(Reproducido con SHA-256 el 2026-11-17. El mismo código de firma recibe `expiration_time` vacío en este caso de prueba.)

---

## 2. `POST /api/v1/webhooks/wompi`

**Quién**: público (Wompi). Sin `x-tenant-host` y sin token; no pasa por el guard de suscripción. La autenticidad la da únicamente la firma.

**Cuerpo** (evento `transaction.updated`, estructura documentada por Wompi):

```json
{
  "event": "transaction.updated",
  "data": {
    "transaction": {
      "id": "1234-1610641025-49201",
      "amount_in_cents": 8990000,
      "reference": "SKP-8f0c6f0e1a4b4a439d512c4d6c1f9e10",
      "currency": "COP",
      "status": "APPROVED"
    }
  },
  "environment": "test",
  "signature": {
    "properties": ["transaction.id", "transaction.status", "transaction.amount_in_cents"],
    "checksum": "<sha256 hex>"
  },
  "timestamp": 1530291411,
  "sent_at": "2026-11-30T14:12:09.000Z"
}
```

**Checksum del evento** (SHA-256 hexadecimal; se compara en minúsculas y con `hmac.compare_digest`):

```
sha256( valor(data, p1) + valor(data, p2) + ... + str(timestamp) + WOMPI_EVENTS_SECRET )
```

con `p1, p2, …` = `signature.properties` **en el orden recibido**, resolviendo cada ruta con puntos (`transaction.status`) dentro de `data`. Si llega la cabecera `X-Event-Checksum`, debe coincidir con el calculado.

### 2.1 Respuestas

| Código | Cuándo | Cuerpo |
|---|---|---|
| `200` | Evento válido procesado | `{"status": "processed"}` |
| `200` | Evento válido ya procesado (duplicado) | `{"status": "duplicate"}` |
| `200` | Evento válido sin efecto: referencia desconocida, monto/moneda distintos, estado `PENDING`, transición no permitida, evento de otro tipo, transacción ya ligada a otro pago | `{"status": "ignored"}` |
| `400` | Cuerpo ilegible o faltan `event`, `data`, `signature.properties`, `signature.checksum` o `timestamp`; o los `properties` firmados no incluyen `transaction.id`, `transaction.status` y `transaction.amount_in_cents` | `{"detail": <texto>}` |
| `401` | Checksum (o `X-Event-Checksum`) no coincide; o `WOMPI_EVENTS_SECRET` no está configurado | `{"detail": "Firma inválida"}` |

Solo `200` evita los reintentos de Wompi (3 en 24 h). Los `400`/`401` son por diseño: un evento forjado no debe tener efecto y sus reintentos no hacen daño.

### 2.2 Efecto de un evento válido de `transaction.updated`

Todo ocurre en **una transacción** de la base compartida, con `SELECT … FOR UPDATE` sobre el pago (por `gateway_reference = data.transaction.reference`) y luego sobre su tenant.

| Estado de Wompi | Pago en `pending` | Pago en `expired` / `rejected` | Pago en `approved` | Pago en `voided` |
|---|---|---|---|---|
| `APPROVED` | → `approved`, recalcula fechas | → `approved`, recalcula fechas | no-op (`duplicate`) | ignora |
| `DECLINED` / `ERROR` | → `rejected` | ignora | ignora (nunca retrocede) | ignora |
| `VOIDED` | ignora | ignora | → `voided`, **sin** revertir fechas | no-op |
| `PENDING` | ignora | ignora | ignora | ignora |

Antes de aplicar una aprobación se valida: `amount_in_cents == int(payment.amount * 100)`, `currency == "COP"` y que `transaction.id` no esté ligada a otro pago. Si algo no coincide: `ignored`, estado del pago intacto y una advertencia en el registro (con `reference` y `transaction.id`, nunca el cuerpo completo).

Al aprobar, se guarda `gateway_transaction_id`, y las fechas se calculan según `data-model.md § 2.2` y `research.md` Decisión 9. El desbloqueo es inmediato: la siguiente petición del tenant ya ve la nueva vigencia.

### 2.3 Vectores y pruebas

- La **firma de integridad** se prueba con el vector verificado de la sección 1.
- El **checksum del evento** se prueba con un auxiliar de test que aplica la fórmula de arriba. El ejemplo numérico de la documentación de Wompi para este checksum **no reproduce** con su propia cadena (ver `research.md` Decisión 1), así que no se usa como vector.
- Escenarios mínimos: aprobado con tenant `por_vencer`, `en_gracia` y `bloqueada`; aprobado repetido; rechazado; anulado tras aprobar; aprobado tardío sobre `expired`; monto distinto; referencia desconocida; firma alterada; firma ausente; `properties` incompletos; secreto sin configurar; transacción ya ligada a otro pago; tenant ya sin ciclo mensual.
