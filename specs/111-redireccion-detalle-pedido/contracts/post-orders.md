# Contrato: `POST /orders` (creación de pedido manual) — cambios

**Endpoint existente**: `POST /orders` (`../pos-backend/app/api/v1/orders/router.py:603` →
`app/api/v1/orders/service.py:448`, `create_order()`). Esta spec no cambia su propósito (crear un
pedido Mesa/Para llevar/Domicilio desde la terminal); añade un campo opcional de idempotencia para
cumplir RN4/FR-011.

## Request — campo nuevo

| Campo | Tipo | Requerido | Descripción |
|---|---|---|---|
| `client_request_id` | `string` (UUID recomendado) | No | Generado por el cliente una sola vez por intento de "Crear pedido"; se reenvía sin cambios si ese mismo intento se reintenta por una falla de red. |

Resto de campos de `OrderCreate`: sin cambios
(`../pos-backend/app/api/v1/orders/schemas.py:125-148`).

## Comportamiento

- **Sin `client_request_id`** (clientes que aún no actualizaron, o cualquier integración externa
  que no lo envíe): comportamiento idéntico al actual — cada solicitud crea un pedido nuevo.
  Retrocompatibilidad total.
- **Con `client_request_id`**:
  - Si no existe ningún pedido previo con ese valor: se crea el pedido normalmente, guardando el
    valor recibido en la columna nueva.
  - Si ya existe un pedido con ese `client_request_id` (mismo intento reintentado): la respuesta es
    `2xx` con el pedido **ya existente** (mismo `id`, mismos ítems), sin crear un segundo pedido.

## Response

Sin cambios de forma: sigue devolviendo el `CustomerOrder` completo, incluyendo `id` (el contrato
que ya consume `ManualOrderPageComponent`/`PosTerminalStore` no cambia). El único efecto observable
es que, ante un `client_request_id` repetido, el `id` devuelto es el del pedido creado en el
intento original, no uno nuevo.

## Compatibilidad

- Retrocompatible: el campo es opcional; ningún consumidor existente de `POST /orders` se rompe por
  no enviarlo.
- No afecta pedidos ya creados (Principio VII de la Constitución): la columna nueva es nullable y
  los pedidos históricos simplemente no tienen valor en ella.

## Casos de prueba de referencia (para `/speckit-tasks`)

1. Dos solicitudes con el mismo `client_request_id` y el mismo cuerpo → un único pedido creado,
   ambas respuestas con el mismo `id` (RN4, SC-003).
2. Dos solicitudes sin `client_request_id` → dos pedidos distintos (comportamiento actual sin
   cambios, retrocompatibilidad).
3. Dos solicitudes con `client_request_id` distinto → dos pedidos distintos.
4. Una solicitud con `client_request_id` ya usado por un pedido de **otro** carrito/sesión: se
   trata igual que el caso 1 (se devuelve el pedido existente). Decisión cerrada: el valor es un
   UUID generado por el cliente por intento, por lo que una colisión real entre carritos distintos
   es estadísticamente despreciable (espacio de 2^122 valores); no se requiere un alcance de
   unicidad más estrecho (p. ej. por usuario o por sesión) para esta corrección.
