# Contrato — Cobrar el saldo pendiente (pago complementario)

**FR cubiertos**: FR-010, FR-011, FR-012, FR-013, FR-014, FR-018, FR-020, FR-021, FR-022.

## `POST /orders/{order_id}/complementary-payment`

Cobra, en un único pago, todo el saldo pendiente vigente de un pedido, generando una factura
independiente.

### Request

```jsonc
{
  "payments": [
    { "payment_method_id": "uuid", "amount": "2000.00" }
  ]
}
```

### Reglas de validación (en orden, toda la operación es una sola transacción)

1. `order_id` debe existir → 404 si no.
2. Recalcula el saldo pendiente vigente (`data-model.md` §1). Si es `0` → **409** "No hay saldo
   pendiente por cobrar".
3. `len(payments) == 1` → si no, **422** "El pago complementario exige un único método de pago"
   (FR-018; validación nueva de este endpoint, no heredada de `pay_order`).
4. `payments[0].amount` debe ser exactamente igual al saldo pendiente vigente → si no, **422**
   "El monto no coincide con el saldo pendiente".
5. Debe existir un turno de caja abierto para la caja del cajero (`ensure_open_shift`, reusado sin
   cambios) → 404/409 si no, igual que cualquier otro cobro.
6. Si el tenant tiene el módulo de inventario (spec 033) habilitado: valida stock de **cada**
   insumo de **todas** las adiciones pendientes cubiertas por este cobro. Si **cualquiera** no
   tiene stock suficiente → **409** `{"error": "Stock insuficiente", "insumo": "..."}` y se
   **aborta la transacción completa** — no se cobra ninguna parte, no se genera ninguna factura
   (FR-020; atomicidad: todo o nada). Si el tenant no tiene el módulo, se omite este paso y el
   siguiente (FR-021).

### Efecto (solo si todas las validaciones pasan)

1. Si aplicó el paso 6: descuenta del inventario el insumo de cada adición cubierta, una llamada a
   `deduct_addition` por fila (research.md D9) — nunca `deduct_order_items`, que volvería a
   descontar la receta base de cada línea.
2. Llama `build_sale(..., kind='complementario', customer_order_id=order_id, payments=payments)` →
   nueva `Sale` + `SaleItem` + `Payment` + factura independiente (FR-011). La `Sale` original del
   pedido no se modifica (FR-007).
3. Marca `complementary_sale_id` en cada `OrderItemOption` cubierta.
4. El movimiento de caja queda registrado automáticamente: la nueva `Sale` tiene `cash_shift_id`
   del turno abierto, y `reconcile` ya la contabiliza sin código adicional (FR-013).
5. El pedido vuelve a reflejar saldo pendiente `0` (FR-014).
6. Emite, tras el commit: `order.bill_changed` y, si corresponde, un evento de pago completado
   (reusa el ya existente del dominio de pagos).

### Ciclos repetidos (FR-022)

Nada en este contrato limita cuántas veces se puede invocar sobre el mismo `order_id` a lo largo
del tiempo: cada invocación exitosa cubre exactamente el saldo pendiente vigente en ese momento.
Si después se agregan más adiciones (ver `add-addition-to-order-item.md`), se genera un nuevo
saldo pendiente independiente, cobrable con una nueva invocación de este mismo endpoint.

### Response `200`

```jsonc
{
  "sale": { /* Sale nueva, kind='complementario' */ },
  "invoice": { /* factura independiente */ },
  "order_pending_balance": "0.00"
}
```

### Errores

| Código | Caso |
|---|---|
| 404 | `order_id` no existe, o no hay turno de caja abierto |
| 409 | saldo pendiente es cero |
| 409 | stock insuficiente de cualquier insumo cubierto (solo si el tenant tiene módulo de inventario) — rechazo atómico |
| 422 | más de un método de pago, o el monto no coincide con el saldo pendiente |
