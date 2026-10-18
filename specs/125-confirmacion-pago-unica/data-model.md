# Data Model: Confirmación Única de Pago

Esta funcionalidad no introduce entidades nuevas. Amplía, de forma aditiva y opcional, una
estructura de datos ya existente (`NotificationEvent.payload`, spec 077) y los cuerpos de
petición de tres endpoints de cobro ya existentes. Ningún campo nuevo requiere migración de
esquema (ver Constitution Check, Principio VIII).

## Campo nuevo: `origin_client_id`

| Dónde vive | Tipo | Obligatorio | Descripción |
|---|---|---|---|
| Cuerpo de `POST /orders/{id}/pay` (`PayIn`) | `str \| None`, máx. 64 | No | Id de la pestaña/terminal que origina el cobro. |
| Cuerpo de `POST /orders/{id}/checkout-and-send` (`CheckoutAndSendIn`) | `str \| None`, máx. 64 | No | Igual. |
| Cuerpo de `POST /table-sessions/{id}/close` (`CloseSessionIn`) | `str \| None`, máx. 64 | No | Igual — se usa para todas las ventas emitidas en ese cierre (unificado o dividido). |
| `NotificationEvent.payload["origin_client_id"]` (JSONB ya existente) | `str \| None` | No | Copiado del campo anterior al despachar la notificación `payment.completed`. |
| Payload del evento SSE `notification.created` (`InAppChannel.send()`) | `str \| None` | No | Copiado de `NotificationEvent.payload["origin_client_id"]`, para que el frontend lo compare. |
| `RealtimeService.clientId` (frontend, nuevo) | `string` (UUID v4) | Sí (generado localmente) | Identificador estable de esta pestaña, generado una vez con `crypto.randomUUID()` y persistido en `sessionStorage`. Nunca se envía al backend como identidad de autenticación — es solo una marca de correlación para deduplicar avisos. |

**Compatibilidad con datos existentes**: una petición de cobro que no mande `origin_client_id`
(cliente desactualizado, o endpoint llamado desde otro lugar) se comporta exactamente igual que
hoy — el campo es `None`, nunca hay coincidencia con ningún `clientId` de ninguna terminal, y el
evento se muestra como notificación en todas las terminales conectadas (comportamiento actual, sin
regresión). Ningún `NotificationEvent` histórico tiene este campo; su ausencia se trata igual que
`None`.

**Vida del identificador de terminal (`clientId`)**: por pestaña, no por usuario ni por
dispositivo. Vive en `sessionStorage` (se pierde al cerrar la pestaña, no se comparte con otras
pestañas del mismo navegador ni se sincroniza entre dispositivos) — exactamente el alcance que
pide la spec ("otra pestaña del mismo cajero cuenta como otra terminal").

## Contenido ampliado del modal "Pago registrado" (frontend, sin persistencia nueva)

El modal ya recibe `store.lastSale()` (`{ total, customer }`) y `store.lastReceipts()` (lista de
`ReceiptData`, ya calculada por `saleToReceipt()` en `receipt.util.ts`). Para un solo comprobante,
`lastReceipts()[0]` ya trae `payments: { name, amount }[]` y `change: number | null` — el modal
solo deja de ignorarlos:

| Campo del modal | Origen | Nuevo en el modal |
|---|---|---|
| `total` | `lastSale().total` | No (ya existe) |
| `customer` | `lastSale().customer` | No (ya existe) |
| Método de pago | `lastReceipts()[0].payments` — si hay una sola línea, su `name`; si hay varias (cobro mixto, spec 112), se unen con " + " | Sí — se expone en el modal |
| Vuelto | `lastReceipts()[0].change`, mostrado solo cuando `change` no es `null` (ya es `null` para cualquier cobro sin efectivo — `sale.change_given` lo calcula así hoy) | Sí — se expone en el modal |

No se agrega ningún campo nuevo al backend para esto: el dato ya viaja en la venta (`Sale`) que
produce `checkoutAndSend`/`close`, y `saleToReceipt()` ya lo proyecta para el recibo imprimible —
el modal solo deja de ignorarlo. Para el caso de cuenta dividida (`lastReceipts().length > 1`) el
modal conserva su resumen agregado actual (sin método/vuelto por comensal) — fuera de alcance de
esta spec, cuyos escenarios Gherkin solo describen el caso de un único comprobante.
