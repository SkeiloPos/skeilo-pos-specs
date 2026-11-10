# Quickstart: Validar el cobro independiente de pedidos por mesa

Ver `contracts/table-session-charge-subset.md` para el detalle de cada endpoint y
`data-model.md` para los campos involucrados. Esta guía solo cubre cómo ejecutar y
verificar los escenarios de aceptación del spec.

## Prerrequisitos

- Backend (`pos-backend`) corriendo con Postgres local disponible (ver
  `how-to-run-sibling-repo-tests` en memoria del asistente para el comando del
  venv).
- Un tenant de prueba con una mesa (`DiningTable`) y una caja (`cash_shift`)
  abierta.
- Dos pedidos QR distintos enviados sobre la misma mesa (misma `TableSession`),
  p. ej. vía `POST /cart/sessions` + flujo de carrito del comensal, de forma que
  queden como "Pedido 41" y "Pedido 42" con `status='entregada'` (o confirmados)
  y `payment_status='UNPAID'`.

## Escenario 1 — Cobrar un único pedido (User Story 1, FR-001/FR-003)

1. `GET /table-sessions/{id}/bill?order_ids={id_pedido_42}` → verificar que
   `total` corresponde solo al Pedido 42.
2. `POST /table-sessions/{id}/charge` con body
   `{"cash_shift_id": ..., "billing_mode": "unified", "payments": [...], "order_ids": [id_pedido_42]}`.
3. Verificar en la respuesta y en BD: `CustomerOrder` del Pedido 42 tiene
   `payment_status='PAID'`; el Pedido 41 sigue en `'UNPAID'`.
4. `GET /table-sessions/{id}/bill` (sin `order_ids`) → el `total` ahora refleja
   solo lo pendiente (Pedido 41).
5. `DiningTable.status` sigue `'ocupada'` (la mesa no se libera).

## Escenario 2 — Cobrar varios pedidos juntos (User Story 2, FR-002)

1. Con ambos pedidos aún `UNPAID`, `POST /table-sessions/{id}/charge` con
   `order_ids: [id_pedido_41, id_pedido_42]`.
2. Verificar que ambos quedan `payment_status='PAID'` tras una sola llamada y que
   se generó la(s) `Sale` correspondiente(s) según `billing_mode`.

## Escenario 3 — Visualizar estado de pago por pedido (User Story 3, FR-004)

1. Repetir Escenario 1 hasta el paso 3 (Pedido 42 pagado, Pedido 41 pendiente).
2. En la Terminal de Mesas (frontend), abrir la cuenta de la mesa y verificar que
   las pestañas "Pedido 41"/"Pedido 42" muestran un indicador visual distinto de
   estado de pago (ya soportado por `paymentStatusLabel`/`paymentStatusClass` en
   `pos-terminal.store.ts`; verificar que se actualiza tras el cobro parcial).

## Escenario 4 — Intentar liberar la mesa con un pedido pendiente (Edge case)

1. Con el Pedido 41 aún `UNPAID` (tras Escenario 1), `POST
   /table-sessions/{id}/release` → debe responder `409 Conflict` listando el
   Pedido 41 como pendiente (comportamiento ya existente, sin cambios).
2. Cobrar el Pedido 41 (`POST /charge` con su `order_ids`) y repetir `POST
   /release` → ahora debe liberar la mesa (`DiningTable.status='libre'`).

## Escenario 5 — Validación de `order_ids` inválidos

1. `POST /table-sessions/{id}/charge` con `order_ids` que incluya un id ya
   `PAID` o de otra sesión → `409 Conflict` con el detalle de ids inválidos
   (ver contrato).

## Escenario 6 — Caso sin cambios visibles (mesa con un solo pedido)

1. Mesa con un único pedido pendiente: cobrar sin enviar `order_ids` (o
   enviándolo con ese único id) debe producir el mismo resultado que el cobro
   total actual — sin diferencias observables para el cajero.

## Verificación automatizada

- Tests nuevos en `pos-backend/app/api/v1/table_sessions/` (o
  `app/tests/` equivalente) cubriendo los Escenarios 1, 2, 4 y 5 contra
  `charge_session`/`compute_bill`.
- Characterization tests existentes de `table_sessions`/`customer_order`
  (`"CONGELA comportamiento actual:"`) deben seguir pasando sin modificación: el
  comportamiento por defecto (sin `order_ids`) no cambia.
- Tests E2E/componente del frontend para la selección de pedidos en el panel de
  cobro de sesión.
