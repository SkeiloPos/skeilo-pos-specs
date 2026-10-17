# Contrato — Evento de tiempo real `order.item_addon_added`

**FR cubiertos**: FR-017.

Nuevo tipo de evento sobre el despachador ya existente de la spec 077
(`app/core/events.py::publish`), siguiendo el molde exacto de `item_kitchen_changed`
(`events.py`, L196-211). Sin transporte, canal ni dependencia nueva.

## Emisión

```python
def item_addon_added(
    tenant_id: UUID, *, order_id: UUID, table_session_id: UUID | None,
    item_id: UUID, option_name: str, quantity: Decimal,
) -> None: ...
```

- **Canales**: `CH_STAFF` siempre; `session_channel(table_session_id)` si el pedido pertenece a
  una sesión de mesa (igual que `item_kitchen_changed`).
- **Cuándo**: siempre **después del commit**, nunca antes (regla general del despachador,
  `events.py` — fail-open, nunca lanza).
- **Dónde se llama**:
  - `orders/additions.py::add_addition_to_order_item`, tras insertar la `OrderItemOption` nueva.
  - `sales/complementary.py::settle_pending_balance`, tras cobrar con éxito (además de
    `bill_changed`, ya existente).

## Payload

```jsonc
{
  "type": "order.item_addon_added",
  "order_id": "uuid",
  "table_session_id": "uuid | null",
  "item_id": "uuid",
  "option_name": "Leche condensada",
  "quantity": "1"
}
```

Payload delgado (ids + el dato que cambió), consistente con el resto del catálogo de eventos de
`events.py` — el cliente que reciba el evento recarga la línea/pedido (`scheduleReload()`), no
reconstruye estado desde el payload.

## Consumo en frontend

`pos-terminal.store.ts::connectRealtime()` (L1434-1461) gana:

```ts
this.realtime.on('order.item_addon_added', () => this.scheduleReload());
```

Mismo patrón de debounce que ya usan los listeners de `item_kitchen_changed`/`item_voided`. El
payload no necesita un campo "modificada" propio — el dato (`added_after_sale` en las opciones de
la línea) ya queda disponible tras la recarga. Pero sí hace falta una pieza de UI nueva, separada
de este listener: un badge "Modificada" en `pos-order-panel.component.ts` que lea ese dato y lo
muestre — sin esa pieza, la recarga trae el dato pero nadie lo pinta (`/speckit-analyze` G3).

## Por qué no reutilizar `item_kitchen_changed`

Ese evento documenta semánticamente un cambio de `estado_cocina`; agregar una adición no cambia el
estado de preparación de la línea (sigue "Pendiente" o "En preparación"). Forzar el mismo tipo de
evento a representar dos cosas distintas confundiría a cualquier consumidor futuro que asuma que
`item_kitchen_changed` siempre implica una transición de estado.
