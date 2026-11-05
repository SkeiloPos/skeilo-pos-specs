# Contrato: `GET /orders/kitchen-board`

**Spec**: [spec.md](../spec.md) | FR-001/FR-002/FR-003/FR-011/FR-012/FR-013/FR-014

## Autorización

`Depends(require_kitchen_board_view)` (research.md Decisión 2): roles `ADMIN`, `CASHIER` o
`KITCHEN`. Ningún otro rol puede ver el tablero. No depende de `require_module_access("cocina")`
— ver el tablero sin pedidos (módulo desactivado ⇒ ninguna orden nueva llega nunca a
`kitchen_status IS NOT NULL`, así que las columnas simplemente aparecen vacías; no hace falta
bloquear la lectura en sí).

## Request

```
GET /orders/kitchen-board
Authorization: Bearer <token staff>
```

Sin parámetros — siempre devuelve las tres columnas completas del tenant (FR-013: mismas reglas
sin importar el origen de la orden).

## Response 200

```json
{
  "sin_preparar": [ /* CardResponse[] */ ],
  "en_progreso": [ /* CardResponse[] */ ],
  "listo": [ /* CardResponse[] */ ]
}
```

Cada lista ordenada ascendente por `sent_to_kitchen_at`, desempate por `id` (FR-003).

### `CardResponse` (por tarjeta)

```json
{
  "order_id": "uuid",
  "table_order_number": 12,
  "kitchen_status": "EN_PROGRESO",
  "version": 3,
  "sent_to_kitchen_at": "2026-11-04T15:02:00Z",
  "origin": "mesa",
  "table_number": 5,
  "customer_name": null,
  "delivery_address": null,
  "notes": "Sin cebolla",
  "items": [
    {
      "product_name": "Hamburguesa clásica",
      "quantity": 2,
      "addons": [ { "name": "Queso extra", "quantity": 1 } ],
      "notes": null
    }
  ]
}
```

- `origin`: `"mesa"` | `"caja"` | `"domicilio"`, derivado de `order_type`
  (`DINE_IN`/`TAKEAWAY`/`DELIVERY`, data-model.md). Nunca `null`.
- `table_number`: solo presente cuando `origin == "mesa"`; `null` en otro caso.
- `customer_name`: cliente de la orden si existe (FR-012/edge case "sin mesa ni cliente" →
  `null`, el frontend no inventa un placeholder).
- `delivery_address`: solo cuando `origin == "domicilio"`.
- `version`: el cliente debe reenviarlo intacto al mover la tarjeta
  (`POST /orders/{id}/kitchen-status`, ver `move-kitchen-status.md`).

## Errores

| Status | Caso |
|---|---|
| 401 | Sin sesión válida. |
| 403 | Rol distinto de `ADMIN`/`CASHIER`/`KITCHEN`. |

No hay 404/409 — es una lectura de colección, siempre devuelve (posiblemente vacía) las tres
columnas.
