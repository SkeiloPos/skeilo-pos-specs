# Contrato API: Transferencia de ítems entre órdenes

Prefijo existente reutilizado: `/orders` (`pos-backend/app/api/v1/orders/router.py`). Tres
endpoints nuevos, mismo guard de autorización que `POST /orders/{order_id}/move` y
`POST /orders/merge` (cualquier rol habilitado para cobrar/gestionar órdenes en la terminal de
mesas — sin permiso nuevo, ver Clarifications del spec).

Todas las respuestas de error usan el formato de error ya estándar del API (`detail`). Códigos
HTTP usados: `200` éxito, `400` violación de regla de negocio (mismos casos para las 3
operaciones salvo que se indique lo contrario), `403` sin pago gate (orden ya cobrada), `404`
orden/ítem no encontrado.

---

## 1. `POST /orders/{order_id}/split`

Divide automáticamente cada línea de la orden en una cuenta (orden) independiente. Implementa
User Story 1 (FR-001, FR-002, FR-003).

**Path params**: `order_id` (UUID) — orden a dividir.

**Request body**: ninguno.

**Respuesta 200**:
```json
{
  "original_order_id": "uuid",
  "created_orders": [
    {
      "order_id": "uuid",
      "table_order_number": 12,
      "item": { "product_variant_id": "uuid", "quantity": 2, "unit_price": "15000.00" }
    }
  ]
}
```

**Reglas**:
- Si la orden tiene **1 sola línea**: `200` sin cambios, `created_orders: []` (no-op explícito,
  no error — Edge Cases del spec, acceptance scenario 2 de User Story 1).
- Si la orden tiene **0 pagos** y **>1 línea**: crea una `CustomerOrder` nueva por cada
  `OrderItem` (conservando producto, variante, cantidad, precio, `estado_cocina`), elimina la
  orden original.
- Si la orden tiene pago registrado (`order_has_sale == True`): `403`, `detail`: "La orden ya fue
  cobrada; no se puede dividir."

---

## 2. `POST /orders/{order_id}/items/{item_id}/move`

Mueve un ítem (total o parcial) hacia una orden destino existente de la misma mesa. Implementa
User Story 2 (FR-004, FR-005).

**Path params**: `order_id` (UUID) — orden origen. `item_id` (UUID) — línea a mover.

**Request body**:
```json
{
  "target_order_id": "uuid",
  "quantity": 1
}
```
`quantity` es opcional; si se omite, se mueve la cantidad total de la línea.

**Respuesta 200**:
```json
{
  "source_order": { "order_id": "uuid", "deleted": false, "total": "30000.00" },
  "target_order": { "order_id": "uuid", "total": "45000.00" },
  "merged": false
}
```
`source_order.deleted: true` cuando la orden origen quedó sin ítems y fue eliminada (FR-007).
`merged: true` cuando la cantidad se sumó a una línea existente del destino en vez de crear una
línea nueva (regla de fusión, Clarification de sesión 2026-11-21).

**Reglas / errores**:
- `404` si `order_id`, `item_id` o `target_order_id` no existen, o si `item_id` no pertenece a
  `order_id`.
- `400` "La orden destino no pertenece a la misma mesa" si `target_order_id` no comparte
  `table_session_id`/`dining_table_id` con `order_id` (FR-009).
- `403` "La orden ya fue cobrada; no se puede mover el ítem." si la orden origen o la orden
  destino tiene pago registrado (FR-008).
- `400` "La cantidad a mover debe ser mayor a 0 y menor a la cantidad de la línea" si
  `0 < quantity < línea.quantity` no se cumple y `quantity` fue explícito y es distinto a la
  cantidad total de la línea (Edge Cases).
- Si `target_order_id == order_id`: `400` "No se puede mover un ítem a la misma orden."

---

## 3. `POST /orders/{order_id}/items/{item_id}/split-to-new`

Crea una orden nueva en la misma mesa que contiene únicamente el ítem (o la cantidad indicada de
él). Implementa User Story 3 (FR-006).

**Path params**: `order_id` (UUID) — orden origen. `item_id` (UUID) — línea a separar.

**Request body**:
```json
{
  "quantity": 1
}
```
`quantity` opcional; si se omite, se mueve la cantidad total de la línea (sujeto a la regla de
"único ítem restante" más abajo).

**Respuesta 200**:
```json
{
  "source_order": { "order_id": "uuid", "deleted": false, "total": "30000.00" },
  "new_order": { "order_id": "uuid", "table_order_number": 13, "total": "15000.00" }
}
```

**Reglas / errores**:
- `404` si `order_id` o `item_id` no existen, o `item_id` no pertenece a `order_id`.
- `403` "La orden ya fue cobrada; no se puede crear una cuenta nueva." si `order_id` tiene pago
  registrado (FR-008).
- `400` "Esta acción no genera ningún cambio: el ítem ya es una cuenta independiente." si
  `item_id` es la única línea restante de `order_id` **y** `quantity` es igual a la cantidad
  total de esa línea (Edge Cases: bloqueo solo cuando se mueve la totalidad de la única línea
  restante; una cantidad parcial de esa misma línea sí está permitida).
- `400` "La cantidad a mover debe ser mayor a 0 y menor a la cantidad de la línea" — misma regla
  que en `move`, cuando aplica fraccionamiento.

---

## Respuesta compartida: recálculo de totales

Las tres operaciones devuelven, para cada orden afectada que siga existiendo, su total
recalculado (`order_totals`/`build_billing_summary` ya existentes en
`app/api/v1/orders/service.py`), para que el frontend pueda refrescar los montos sin una llamada
adicional (SC-003).
