# Contrato de API: compras en presentación

No hay endpoints nuevos — se extiende el contrato de los 3 ya existentes en
`app/api/v1/inventory/router.py`. La forma de la petición decide el camino (research.md D2): una
línea trae `quantity`+`unit_cost` (directo, como hoy) **o** `supplier_item_id`+
`presentation_quantity`+`presentation_unit_cost` (nuevo) — nunca ambos.

## `POST /inventory/purchases` (alta directa, sin cambios de ruta)

Por cada línea con `supplier_item_id`:

1. 404 si la relación no existe en el tenant actual.
2. 422 si la relación está inactiva, si `relation.inventory_item_id != item.inventory_item_id`
   de la línea, o si `relation.supplier_id != purchase.supplier_id` (FR-009) — mensaje: "la
   presentación elegida no corresponde al insumo o al proveedor de esta compra".
3. Calcular `quantity = presentation_quantity × relation.conversion_factor` (FR-003).
4. Calcular `unit_cost = round(presentation_unit_cost ÷ relation.conversion_factor, 2)`
   (ROUND_HALF_UP, FR-004).
5. Guardar en el `PurchaseItem`: `quantity`, `unit_cost`, `supplier_item_id`,
   `presentation_quantity`, `presentation_label = relation.presentation` (snapshot, research.md
   D1).
6. El total de la línea, para `Purchase.total`, es `presentation_quantity × presentation_unit_cost`
   (FR-005) — no `quantity × unit_cost` derivados.
7. `record_movement(..., quantity=quantity, ...)` — sin cambios respecto a hoy, recibe siempre
   unidad base.
8. `supplier_items.apply_purchase_cost(db, relation, presentation_unit_cost)` (FR-006/RN-15,
   research.md D3) — en la misma transacción.

Por cada línea sin `supplier_item_id`: idéntico al comportamiento actual, sin ningún paso nuevo
(FR-007).

## `POST /inventory/purchases/order` (creación de orden, sin cambios de ruta)

Mismos pasos 1–6 y 8 que arriba (fija la presentación y su factor, y actualiza el último costo
del proveedor en este momento — research.md D3), pero **sin** el paso 7: el stock no se mueve al
crear la orden (sin cambios respecto al comportamiento actual, RN-INV-18).

## `POST /inventory/purchases/{id}/receive` (recepción parcial/total, sin cambios de ruta)

Por cada línea recibida cuyo `PurchaseItem.supplier_item_id` no es `NULL`:

1. El request DEBE traer `presentation_quantity` (cuántas presentaciones se están recibiendo
   ahora), nunca `quantity` directo — 422 si no es así.
2. El factor de conversión se lee de `SupplierItem.conversion_factor` **en este momento**, nunca
   del request (research.md D4) — `quantity_received = presentation_quantity ×
   relation.conversion_factor`.
3. El resto del flujo no cambia: `quantity_received` se valida contra lo pendiente exactamente
   igual que hoy (RN-INV-20), se suma al stock (`record_movement`) y a `received_quantity`.
4. **No** se vuelve a tocar `SupplierItem.last_cost`/`last_cost_at` aquí — ya se fijaron al crear
   la orden (research.md D3); el costo aplicado al insumo sigue siendo
   `PurchaseItem.unit_cost` ya pactado (RN-INV-22, sin cambios).

Por cada línea cuyo `PurchaseItem.supplier_item_id` es `NULL`: el request DEBE traer `quantity`
directo, comportamiento idéntico al actual.

## Errores comunes (las 3 rutas)

| Código | Cuándo |
|---|---|
| 422 | la línea trae `quantity` y `supplier_item_id` a la vez, o ninguno de los dos; `presentation_quantity`/`presentation_unit_cost` ausente cuando correspondía; la relación no corresponde al insumo/proveedor de la línea o de la compra; la relación está inactiva |
| 404 | `supplier_item_id` no existe en el tenant actual (incluye el caso de pertenecer a otro tenant) |

Ningún código ni mensaje nuevo para el camino sin presentación — se comporta exactamente como
hoy (FR-007), incluidas las validaciones ya protegidas RN-INV-20/22/23.
