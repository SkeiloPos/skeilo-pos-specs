# Contrato: Entrega de pedido (`POST /orders/{order_id}/deliver`)

**Feature**: 153-cobro-previo-cocina-qr

Endpoint existente (`deliver_order`, `pos-backend/app/api/v1/orders/kitchen.py:89-141`,
`router.py:408`). No cambia su ruta, método ni esquema de request/response. Cambia
únicamente su precondición de negocio.

## Comportamiento — ANTES de este ajuste

Rechaza únicamente pedidos con `status=='cancelada'`. No valida `kitchen_status` en
absoluto — un pedido puede entregarse sin haber pasado por cocina, o antes de que cocina lo
marque "Listo", incluso con el módulo de Cocina activo. (Hoy esta regla solo existe en el
frontend, `canDeliverOrder`.)

## Comportamiento — DESPUÉS de este ajuste

1. Sigue rechazando `status=='cancelada'`, sin cambios.
2. **Si el tenant tiene el módulo de Cocina activo y el pedido tiene `dining_table_id`**
   (pedido de mesa): además exige `kitchen_status=='LISTO'`. Si no lo está, responde 409
   (mismo estilo de error que ya usa `send_to_kitchen` para `ORDER_NOT_PAID`, p. ej.
   `ORDER_NOT_READY`). (FR-004)
3. **Si el tenant no tiene el módulo de Cocina activo, o el pedido no tiene
   `dining_table_id`**: sin cambios respecto a "ANTES" (FR-006, FR-009).

## Razón del cambio

El frontend (`canDeliverOrder`, `order-status.util.ts:281`) ya implementa esta regla desde
la spec 151, pero la API no la exige: cualquier otro cliente, una condición de carrera, o
un error de UI podría entregar un pedido antes de "Listo". Este ajuste traslada la misma
regla al backend como defensa en profundidad, sin cambiar el comportamiento ya correcto del
frontend.

## Errores nuevos

| Código | Condición | Mensaje |
|---|---|---|
| 409 (nuevo) | Módulo de Cocina activo, pedido de mesa, `kitchen_status != 'LISTO'` | p. ej. `ORDER_NOT_READY` — "El pedido aún no está listo en cocina." |

No se modifican los errores existentes (p. ej. el 409 por `status=='cancelada'`).
