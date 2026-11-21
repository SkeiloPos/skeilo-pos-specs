# Contrato (delta): `POST /inventory/purchases/suggested/generate`

No se introduce ningún endpoint ni se cambia la forma de la petición/respuesta definida en
`specs/158-compra-sugerida/contracts/suggested-purchases-api.md`. Este documento describe
únicamente lo que cambia en el **resultado observable** de ese mismo contrato.

## Request

Sin cambios. `GenerateSuggestedPurchasesRequest { idempotency_key: str, lines:
SuggestedPurchaseLineIn[] }`, igual que spec 158.

## Response — `GenerateSuggestedPurchasesResponse`

Sin cambios de forma (`{ purchases: PurchaseResponse[] }`). Cambia el **valor** de los
siguientes campos de cada `PurchaseResponse` dentro de `purchases`:

| Campo | Antes (spec 158) | Ahora (spec 163) |
|---|---|---|
| `status` | siempre `"draft"` | siempre `"received"` |
| `items[].received_quantity` | siempre `0` | igual a `items[].quantity` (recepción completa) |

Ningún otro campo de `PurchaseResponse`/`PurchaseItemResponse` cambia de significado
(`total`, `unit_cost`, `presentation_quantity`, `conversion_factor_applied`,
`quantity_base`, `cost_base` se calculan exactamente igual que antes).

## Código de estado HTTP

Sin cambios: `201` si `idempotency_key` es nueva (se crearon órdenes), `200` si ya se había
procesado (se devuelven las mismas, sin re-ejecutar nada).

## Errores (422, `{message, lines}`)

Sin cambios: mismos `reason` (`unit_price_zero`, `quantity_below_minimum`,
`supplier_item_inactive`, `supplier_item_not_found`), mismo criterio de "todo o nada" — si
alguna línea falla, no se crea ninguna `Purchase`, ningún movimiento ni ningún aumento de
stock del lote completo (FR-004).

## Efectos secundarios ahora incluidos en esta misma llamada (antes no existían)

- Por cada `PurchaseItem` de cada `Purchase` creada: una fila nueva en `InventoryMovement`
  (`type="in"`, `reason="compra"`, `reference_type="purchase"`, `reference_id=<Purchase.id>`,
  `quantity=<quantity_base>`).
- `InventoryItem.current_stock` de cada insumo incluido aumenta en `quantity_base` de su
  línea, dentro del mismo commit que crea la orden.
- `InventoryItem.unit_cost` de cada insumo incluido se actualiza a `cost_base` de su línea
  (igual que ya hace `create_purchase()`/`receive_purchase()` hoy).
- `SupplierItem.last_cost` **no** cambia (sin cambios respecto a spec 158, FR-007).

## Otros endpoints ya existentes que ahora pueden recibir estas órdenes (sin cambios de contrato)

- `POST /inventory/purchases/{purchase_id}/void`: ya acepta cualquier `Purchase` no anulada
  sin mirar cómo se dio de alta su stock; una orden generada por esta vía se anula con el
  mismo contrato que ya existe (FR-009), revirtiendo `quantity_base` de cada línea.
- `POST /inventory/purchases/{purchase_id}/receive`: sigue rechazando con `409` cualquier
  `Purchase` cuyo `status` ya sea `"received"` (sin cambios) — una orden generada desde
  compra sugerida ya nace en ese estado, así que este endpoint nunca aplica sobre ella (no es
  un caso nuevo a soportar, es el mismo rechazo que ya existe para cualquier compra ya
  recibida por completo).
