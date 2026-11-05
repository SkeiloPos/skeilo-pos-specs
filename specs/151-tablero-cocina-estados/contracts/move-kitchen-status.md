# Contrato: `POST /orders/{order_id}/kitchen-status`

**Spec**: [spec.md](../spec.md) | FR-005/FR-006/FR-007/FR-008/FR-009/FR-010/FR-014

## Autorización

`Depends(require_kitchen_role)` (research.md Decisión 2): únicamente `KITCHEN`.
`Depends(require_module_access("cocina"))` (FR-006, mismo patrón que `/send-to-kitchen` de
spec 150).

## Request

```
POST /orders/{order_id}/kitchen-status
Authorization: Bearer <token KITCHEN>
Content-Type: application/json

{
  "kitchen_status": "EN_PROGRESO",
  "version": 3
}
```

- `kitchen_status`: `Literal["SIN_PREPARAR", "EN_PROGRESO", "LISTO"]` (research.md Decisión 4 —
  validado en la capa de API, no vía `CheckConstraint` de DB).
- `version`: el último `version` que el cliente observó para esta orden (de
  `GET /orders/kitchen-board` o de un evento realtime previo). Obligatorio.

## Orden de validaciones (research.md Decisión 4, mismo molde determinístico que `send_to_kitchen`)

1. Pedido no existe → 404.
2. `order.kitchen_status IS NULL` (nunca se envió a cocina) → 409 `NOT_IN_KITCHEN`.
3. `version` recibido != `order.version` vigente → 409 `KITCHEN_STATUS_CONFLICT`.
4. `order.payment_status != 'PAID'` → 409 `PAYMENT_NOT_PAID`.
5. `order.status IN ('cancelada', 'entregada')` → 409 `ORDER_NOT_ACTIVE`.
6. Módulo de plan `"cocina"` no activo → 409 (vía `require_module_access`, código existente de
   esa infraestructura).
7. Éxito: `kitchen_status = body.kitchen_status`, `version += 1`, commit. Publica
   `events.order_kitchen_status_changed`. Responde `200` con el `CardResponse` actualizado
   (mismo shape que una fila de `GET /orders/kitchen-board`).

`SELECT ... FOR UPDATE` serializa dos movimientos casi simultáneos sobre la misma orden
(FR-008), mismo patrón que `kitchen.send_to_kitchen`/`receive_order`/`deliver_order`.

## Response 200 (éxito)

```json
{
  "order_id": "uuid",
  "kitchen_status": "EN_PROGRESO",
  "version": 4,
  "sent_to_kitchen_at": "2026-11-04T15:02:00Z",
  "origin": "mesa",
  "table_number": 5,
  "customer_name": null,
  "delivery_address": null,
  "notes": "Sin cebolla",
  "items": [ /* igual que kitchen-board.md */ ]
}
```

## Errores (409)

```json
{
  "error": {
    "code": "KITCHEN_STATUS_CONFLICT",
    "message": "La orden ya cambió de estado.",
    "kitchen_status": "LISTO"
  }
}
```

| Código | Causa | Comportamiento esperado del frontend (FR-009) |
|---|---|---|
| `NOT_IN_KITCHEN` | La orden nunca se envió a cocina. | Tarjeta no debería existir en el tablero; el frontend recarga el tablero. |
| `KITCHEN_STATUS_CONFLICT` | `version` desactualizado (otro usuario movió la tarjeta primero). | La tarjeta vuelve a su columna de origen; se refleja el `kitchen_status` vigente que viene en el error; mensaje visible al usuario. |
| `PAYMENT_NOT_PAID` | El pago de la orden ya no es `PAID`. | La tarjeta vuelve a su columna de origen; mensaje visible al usuario. |
| `ORDER_NOT_ACTIVE` | La orden se canceló o se entregó entre que el tablero la mostró y el movimiento. | La tarjeta vuelve a su columna de origen (o, más probablemente, ya fue retirada por el evento `order.cancelled`/`order.delivered` antes de que el usuario llegue a soltarla); mensaje visible al usuario. |
| 403 | Rol distinto de `KITCHEN`. | No debería ser alcanzable: `ADMIN`/`CASHIER` nunca ven el control de arrastre (FR-014, frontend). |
| 404 | Pedido no existe. | Caso defensivo; no se espera en operación normal. |
