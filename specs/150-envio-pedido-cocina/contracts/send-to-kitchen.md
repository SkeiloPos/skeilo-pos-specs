# Contrato: `POST /orders/{order_id}/send-to-kitchen`

Ver [data-model.md](../data-model.md) y [research.md](../research.md) (Decisiones 0, 3, 5, 6)
para el razonamiento detrás de cada regla. Mismo molde de router que `POST /orders/{id}/receive`
y `POST /orders/{id}/deliver` (`app/api/v1/orders/router.py`), delegando en una función nueva
`kitchen.send_to_kitchen` (`app/api/v1/orders/kitchen.py`).

## Autenticación y autorización

- Requiere sesión autenticada de un usuario del tenant.
- **Rol**: `ADMIN` o `CASHIER` únicamente (FR-011). Dependencia:
  `Depends(require_tenant_admin_or_cashier)`. Cualquier otro rol → `403` (detalle plano, sin
  `code`, mismo patrón que el resto de rechazos de rol en este backend).
- **Módulo de plan**: `Depends(require_module_access("cocina"))`. Si el plan del tenant no
  incluye `cocina_access` → `403` con `{"detail", "code": "MODULE_NOT_IN_PLAN", "module":
  "cocina"}` (mecanismo ya existente desde spec 149, sin cambios).

## Request

```
POST /orders/{order_id}/send-to-kitchen
```

Sin body. `order_id` es el UUID del pedido (`CustomerOrder.id`).

## Respuestas

### 200 — éxito

Mismo `OrderResponse` que ya devuelven `/receive` y `/deliver`, con los dos campos nuevos
poblados:

```json
{
  "...": "...campos existentes de OrderResponse...",
  "kitchen_status": "SIN_PREPARAR",
  "sent_to_kitchen_at": "2026-11-04T15:32:07.123456"
}
```

Efectos: `kitchen_status` pasa de `NULL` a `"SIN_PREPARAR"`, `sent_to_kitchen_at` se fija con la
hora del servidor (`FR-004`), se emite `events.order_sent_to_kitchen` post-commit.

### 404 — pedido no existe

```json
{ "detail": "Order not found" }
```

Mismo formato que `/receive`/`/deliver` (sin `code`).

### 403 — rol no autorizado (FR-011)

```json
{ "detail": "Acceso de administrador o cajero requerido" }
```

(mensaje exacto del `require_tenant_admin_or_cashier` existente; puede variar levemente al
redactarse el texto final en español de Colombia).

### 403 — módulo "cocina" no incluido en el plan

```json
{ "detail": "Tu plan actual no incluye el módulo de cocina.", "code": "MODULE_NOT_IN_PLAN", "module": "cocina" }
```

### 409 — pedido no confirmado (FR-010)

```json
{
  "success": false,
  "error": { "code": "ORDER_NOT_CONFIRMED", "message": "El pedido no está en un estado válido para enviarse a cocina.", "details": null },
  "request_id": "...",
  "detail": "El pedido no está en un estado válido para enviarse a cocina."
}
```

Condición: `order.status == 'cancelada'`.

### 409 — pedido no pagado (FR-006)

```json
{
  "success": false,
  "error": { "code": "ORDER_NOT_PAID", "message": "El pedido no está pagado.", "details": null },
  "request_id": "...",
  "detail": "El pedido no está pagado."
}
```

Condición: `order.payment_status != 'PAID'` (y `order.status != 'cancelada'`, evaluado antes).

### 409 — ya está en la cola de cocina (FR-007/FR-008)

```json
{
  "success": false,
  "error": { "code": "ALREADY_IN_KITCHEN", "message": "El pedido ya está en la cola de cocina.", "details": null },
  "request_id": "...",
  "detail": "El pedido ya está en la cola de cocina."
}
```

Condición: `order.kitchen_status IS NOT NULL`. Este es el código que el frontend debe tratar en
silencio (clarificación 2 de `spec.md`): refrescar el estado de la orden sin mostrar ningún
mensaje de error, porque el pedido ya está correctamente en la cola.

## Idempotencia y concurrencia (FR-008/SC-003)

`SELECT ... FOR UPDATE` sobre la fila del pedido serializa invocaciones concurrentes. Como
máximo una transacción observa `kitchen_status IS NULL` y completa el envío; todas las demás
(sean dobles clics del mismo cajero o reintentos de red) ven `kitchen_status IS NOT NULL` tan
pronto como adquieren el lock y reciben `409 ALREADY_IN_KITCHEN` — ninguna duplica el pedido en la
cola ni modifica `sent_to_kitchen_at` del envío original.
