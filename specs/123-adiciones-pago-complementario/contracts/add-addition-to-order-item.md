# Contrato — Agregar adición a una línea de pedido existente

**FR cubiertos**: FR-001, FR-002, FR-003, FR-004, FR-005, FR-006, FR-008, FR-009, FR-019.

**Nota (regla vigente, spec 117)**: el request de FR-004 — "la cantidad es el total para la
línea, no un multiplicador" — solo aplica a adiciones de un grupo en modo "Por cantidad"; las de
un grupo "Conteo" siguen multiplicándose por la cantidad de producto de la línea, sin cambios
(reutiliza `mark_per_line` existente, sin tocarlo).

## `POST /orders/items/{item_id}/additions`

Agrega una adición (opción de un grupo de opciones) a un `OrderItem` ya persistido.

### Request

```jsonc
{
  "option_id": "uuid",   // opción del grupo (ej. "Leche condensada")
  "quantity": 1          // total para la línea, no multiplicador (spec 117)
}
```

### Reglas de validación (en orden)

1. `item_id` debe existir → 404 si no.
2. `item.estado_cocina` debe estar en `OrderItem.EN_CURSO` (`{"pendiente", "en_preparacion"}`) → si
   no, **409** `{"error": "Producto ya preparado: agrega un producto nuevo"}` (FR-002, FR-003).
3. `option_id` debe pertenecer a un grupo de opciones válido para el producto/variante de la línea,
   respetando `min_select`/`max_select`/topes vigentes (spec 065) — reutiliza
   `load_valid_options`/`validate_option_selection` sin cambios de firma.
4. Si el tenant tiene el módulo de inventario habilitado (spec 033) y el insumo de la opción no
   tiene stock suficiente → **409** `{"error": "Stock insuficiente", "insumo": "...", "disponible":
   "...", "requerido": "..."}` (mismo shape que RN-CAT-24) — **no se modifica la línea ni el total
   del pedido** (FR-009). Si el tenant no tiene el módulo, se omite este paso.

### Efecto

- Inserta una fila `OrderItemOption` nueva sobre el `item_id` dado.
- Determina `added_after_sale` consultando si el `CustomerOrder` del ítem ya tiene una `Sale` con
  `status='paid'` en este instante; lo fija una sola vez.
- Recalcula `addons_total`/`line_total` de la línea (motor existente, sin cambios) y el total del
  pedido.
- Si `added_after_sale = false` (pedido no pagado): el nuevo total del pedido queda disponible para
  el cobro normal (FR-005) — no se activa ningún mecanismo de saldo pendiente. **Si el tenant tiene
  el módulo de inventario habilitado, el insumo de la adición se descuenta de inmediato** vía
  `deduct_addition` (research.md D9) — nunca `deduct_order_item`/`deduct_order_items`, que
  volverían a descontar la receta base de la línea, ya descontada cuando esta se creó.
- Si `added_after_sale = true` (pedido ya pagado): la `Sale` original **no se toca** (FR-007); el
  saldo pendiente del pedido (ver `data-model.md` §1) aumenta por `Option.extra_price × quantity`;
  el inventario **no** se descuenta en este momento — ocurre al cobrarse el pago complementario
  (FR-012, `complementary-payment.md`).
- Emite, tras el commit: `order.item_addon_added` (ver `realtime-item-addon-added-event.md`) y, si
  el paso anterior generó saldo pendiente, `order.bill_changed`.

### Response `200`

```jsonc
{
  "item": { /* OrderItem actualizado, con sus opciones */ },
  "order_total": "10000.00",
  "pending_balance": "2000.00"   // 0 si el pedido no estaba pagado
}
```

### Errores

| Código | Caso |
|---|---|
| 404 | `item_id` no existe |
| 409 | estado de línea fuera de `EN_CURSO` |
| 409 | stock insuficiente (solo si el tenant tiene módulo de inventario) |
| 422 | opción inválida para el grupo/variante (min/max, spec 065) |
