# Contrato: Deduplicación de la confirmación de pago

**Spec**: [../spec.md](../spec.md) | **Data model**: [../data-model.md](../data-model.md)

Extiende, sin romper compatibilidad, tres endpoints de cobro ya existentes y el evento SSE
`notification.created` ya definido por la spec
[077](../../077-notificaciones-tiempo-real/contracts/realtime-events.md).

## Campo nuevo en el cuerpo de los endpoints de cobro

Aplica a los tres endpoints que hoy emiten `payment.completed`/`notification.created`:

| Endpoint | Schema |
|---|---|
| `POST /orders/{id}/pay` | `PayIn` |
| `POST /orders/{id}/checkout-and-send` | `CheckoutAndSendIn` |
| `POST /table-sessions/{id}/close` | `CloseSessionIn` |

Campo agregado a los tres:

```json
{
  "origin_client_id": "c3f6b2e0-6a4b-4e9a-9c2a-1e8f0a2b7d41"
}
```

- Tipo: `str | None`, máx. 64 caracteres. **Opcional** — su ausencia es compatible con clientes
  desactualizados: el comportamiento es idéntico al actual (la notificación llega a todas las
  terminales, sin silenciar ninguna).
- Origen: `RealtimeService.clientId` del frontend (UUID v4 generado una vez por pestaña,
  persistido en `sessionStorage`).
- Sin validación de formato más allá del límite de longitud — es un valor opaco de correlación,
  no una clave de negocio ni un identificador de autenticación.

## Evento `notification.created` — campo nuevo en el payload

Mismo evento ya contratado por la spec 077 (ver `realtime-events.md`), con un campo adicional:

```
id: 1725730000123-0
event: notification.created
data: {"type":"notification.created","v":1725730000123000,"at":"2026-10-17T18:30:00Z","notification_id":"uuid","event_type":"payment.completed","related_entity_type":"sale","related_entity_id":"uuid","summary":"Pago recibido · $ 22.000","origin_client_id":"c3f6b2e0-6a4b-4e9a-9c2a-1e8f0a2b7d41"}
```

- `origin_client_id`: copiado tal cual del campo del mismo nombre recibido en la petición de
  cobro que originó este evento (`None` si no se mandó, o si el tipo de evento no es
  `payment.completed`/no aplica — p. ej. `order.created` sigue sin este campo, no es parte del
  alcance de esta spec).
- `summary`, para `event_type: "payment.completed"`, cambia de formato: pasa de interpolar el
  monto crudo (`"Pago recibido · $22000.00"`) a usar el formato de moneda estándar
  (`"Pago recibido · $ 22.000"`, espacio tras el "$", punto de miles, sin decimales — spec 035).
  Ninguna otra rama de `summary` (p. ej. `order.created`) cambia de formato en esta spec.

**Consumo esperado (frontend)**: `NotificationCenterService.onNotificationCreated(ev)` compara
`ev.origin_client_id` contra `this.realtime.clientId`. Si coinciden: el ítem se sigue agregando a
la lista/campanita de notificaciones (no desaparece, sigue siendo consultable), pero se omiten
`this.toast.info(...)` y `this.sound.bell()` para ese evento puntual. Si no coinciden, o
`origin_client_id` viene ausente/`null`, el comportamiento es exactamente el actual (toast +
sonido si la pestaña tiene foco).

## Sin cambios

- El evento de negocio `payment.completed` (canal `staff`/`session:{table_session_id}`, el que
  escucha `pos-terminal.store.ts` solo para recargar estado): payload sin cambios, sigue
  llegando a todas las terminales por igual — no participa en la deduplicación de avisos, porque
  nunca mostró un toast propio.
- Todo lo demás del contrato de `notification.created` de la spec 077 (resto de campos,
  heartbeat, replay, aislamiento por tenant).
- El endpoint de pago complementario (`settleComplementaryPayment`, spec 123) — no emite
  `notification.created` hoy y esta spec no se lo agrega (R4 de `research.md`).
