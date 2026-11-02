# Contrato: evento SSE `availability.changed`

**Spec**: [../spec.md](../spec.md) (FR-001 a FR-007, FR-010, FR-030 a FR-032) | **Research**: [../research.md](../research.md) (D1, D2, D4, D5, D9, D13)

Extiende el catálogo de `app/core/events.py` / `realtime-event.model.ts`. No cambia la
autenticación ni los canales del stream.

## Tipo y canales

| Campo | Valor |
|---|---|
| `type` | `availability.changed` |
| Canales de publicación | `staff` **y** `menu:{tenant_id}` (`events.availability_changed()` → `publish(channels=[CH_STAFF, menu_channel(tenant_id)])`) |
| Quién lo recibe | Toda terminal del personal del tenant (canal `staff`) y todo comensal del tenant con el menú abierto (canal `menu:{tenant}`) |
| Quién **no** lo recibe | Cualquier suscriptor de otro tenant (el stream es por tenant, `events:tenant:{id}`); el comensal nunca recibe `staff` (FR-032) |
| Publicación | Solo **después del commit**; `events.publish` nunca lanza (FR-004, FR-005) |

## Cuerpo del frame

El frame SSE lo arma `realtime/router.py::_event_frame`: `{ "type", "v", "at", ...payload }`.
`v` es la versión monótona del stream (`version_of(entry_id)`); el `id:` SSE es el id crudo de
Redis (alimenta `Last-Event-ID` y el replay existentes).

```json
{
  "type": "availability.changed",
  "v": 1762099200000123,
  "at": "2026-11-02T15:20:00.123456+00:00",
  "changes": [
    { "kind": "product", "id": "8f1c…", "sold_out": true,  "available": true },
    { "kind": "variant", "id": "2b7e…", "product_id": "8f1c…", "available": false },
    { "kind": "option",  "id": "c41a…", "available": false }
  ],
  "refresh": false
}
```

### `changes[]` — estado **absoluto** tras el cambio

| `kind` | Campos | Significado |
|---|---|---|
| `product` | `id`, `sold_out: bool`, `available: bool` | `sold_out` = marca manual (`not Product.available`); `available` = pedible por stock (alguna presentación pedible). **Siempre ambos**: el cliente no puede recombinarlos para las adiciones. Para una adición (topping) el `id` es el de su producto. |
| `variant` | `id`, `product_id`, `available: bool` | Presentación. `product_id` evita al cliente buscar el padre. |
| `option` | `id`, `available: bool` | Opción/sabor/salsa. |

Reglas:
- Solo aparecen elementos cuyo estado «pedible» **cambió** en esa transacción (FR-009). Una venta
  que baja el stock de 10 a 9 no emite nada.
- Un mismo commit que afecta a varios elementos (insumo compartido, FR-010) produce **un** evento
  con todos.
- `refresh: true` y `changes: []` cuando el lote superaría `AVAILABILITY_EVENT_MAX_CHANGES`
  (propuesta: 200). El cliente trata `refresh` como `resync` (consulta de reconciliación).
- **Prohibido en el payload** (FR-007): existencias, cantidades, costos, nombres o ids de insumos,
  nombres de empleados, precios.

### Quién publica

| Origen | Dónde | Cuándo | Contenido |
|---|---|---|---|
| Marca manual (spec 093) | `PATCH /products/{id}/availability` (router, tras `db.commit()`) | solo si `previous != available` | un `product` con `sold_out` y `available` actuales |
| Inventario | Gancho de sesión (`core/availability_hooks.py`) en `after_commit` | solo si la diferencia antes/después no es vacía | `product`/`variant`/`option` que cambiaron |

## Orden y consistencia en el cliente (FR-006)

1. El cliente guarda `lastV["kind:id"]` y `snapshotAsOf`.
2. Aplica un cambio **solo si** `v > lastV[kind:id]` **y** `v > snapshotAsOf`.
3. Como los cambios son estados absolutos, aplicar el mismo dos veces es inocuo.

## Eventos de control que se reutilizan (sin cambios en el servidor)

| Evento | Origen | Acción del cliente |
|---|---|---|
| `reconnected` | `SseClient` al reabrir tras una caída | consulta de reconciliación (FR-026) |
| `resync` (`gap` / `backpressure`) | `realtime/router.py::_stream` | consulta de reconciliación (FR-027) |
| `refresh: true` dentro de este evento | publicador | consulta de reconciliación |

## Registro en el cliente (obligatorio)

`core/realtime/sse-client.ts::KNOWN_EVENT_TYPES` **debe** incluir `'availability.changed'`. Sin esto
`EventSource` descarta el frame en silencio (mismo caso documentado para `notification.created`).
Se añade además el test guardia de [research.md D13](../research.md): toda `type` de la unión
`RealtimeEvent` está en `KNOWN_EVENT_TYPES`.

## Pruebas del contrato

- Un suscriptor con canales `{menu:{A}}` recibe; uno con `{menu:{B}}` no (SC-004).
- Un suscriptor `{session:{x}, menu:{A}}` recibe y **nunca** ve `staff`.
- Un `rollback` no publica. Un commit sin movimientos de stock no publica.
- El payload serializado no contiene claves fuera de la lista de arriba (test de forma).
