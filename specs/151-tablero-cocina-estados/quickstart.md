# Quickstart: validación del tablero de cocina

**Spec**: [spec.md](./spec.md) | **Contratos**: [kitchen-board.md](./contracts/kitchen-board.md),
[move-kitchen-status.md](./contracts/move-kitchen-status.md)

## Prerrequisitos

- `pos-backend`: venv activo (`source env/bin/activate`), Postgres local disponible, migraciones
  aplicadas (`alembic upgrade head`, incluida la nueva que siembra `shared.roles.KITCHEN`).
- Plan del tenant de prueba con `cocina_access = true` (spec 149/150).
- Un usuario de rol `KITCHEN` creado en ese tenant (`PATCH /users/{id}/role` con
  `{"role": "KITCHEN"}`, o directo en seed de datos de prueba).
- Dos pedidos ya enviados a cocina (`POST /orders/{id}/send-to-kitchen`, spec 150) con
  `sent_to_kitchen_at` distinto — p. ej. uno de mesa (`order_type=DINE_IN`) y uno de domicilio
  (`order_type=DELIVERY`).

## Historia 1 — Orden FIFO por columna (US1)

1. Enviar la orden A a cocina a las 10:00, la orden B a las 10:02 (mismo tenant).
2. `GET /orders/kitchen-board` con un token `ADMIN`/`CASHIER`/`KITCHEN`.
3. **Esperado**: ambas en `sin_preparar`, A antes de B.
4. Enviar dos órdenes C y D con el mismo `sent_to_kitchen_at` manipulado en los datos de prueba
   (o dos envíos dentro del mismo milisegundo).
5. **Esperado**: la de menor `id` aparece primero.
6. **Esperado (negativo)**: no existe ningún endpoint que acepte una posición manual dentro de
   una columna — intentar `POST /orders/{id}/kitchen-status` con el mismo `kitchen_status` que
   ya tiene no cambia su posición relativa (sigue ordenado por `sent_to_kitchen_at`, no por la
   llamada).

## Historia 2 — Mover una tarjeta (US2)

1. Con el usuario `KITCHEN`, `POST /orders/{A}/kitchen-status`
   `{"kitchen_status": "EN_PROGRESO", "version": <version vigente de A>}`.
2. **Esperado**: 200, `kitchen_status` actualizado, `status`/`payment_status` de la orden sin
   cambios (verificar con `GET /orders/{A}`).
3. Repetir el movimiento hacia `LISTO` y luego de vuelta a `EN_PROGRESO` (corrección).
4. **Esperado**: 200 en ambos, mientras `payment_status == 'PAID'` y la orden no esté
   cancelada/cerrada y el módulo esté activo.
5. Revertir manualmente `payment_status` de una orden en `EN_PROGRESO` a algo distinto de
   `PAID` (dato de prueba) y repetir el movimiento.
6. **Esperado**: 409 `PAYMENT_NOT_PAID`, `kitchen_status` sin cambios.
7. Repetir el movimiento con un usuario `ADMIN` o `CASHIER` en vez de `KITCHEN`.
8. **Esperado**: 403.

## Historia 3 — Información de la tarjeta (US3)

1. Crear un pedido de mesa con dos productos, una adición y una nota; enviarlo a cocina.
2. `GET /orders/kitchen-board`.
3. **Esperado**: la tarjeta trae número de orden, mesa, ambos productos con cantidades, la
   adición, la nota y `sent_to_kitchen_at` (el frontend calcula el tiempo transcurrido desde
   ahí, sin requerir recarga).
4. Repetir con un pedido `DELIVERY`.
5. **Esperado**: `origin == "domicilio"`, `customer_name`/`delivery_address` presentes en vez de
   `table_number`.

## Historia 4 — Retiro de tarjetas (US4)

1. Con una orden en `EN_PROGRESO`, cancelarla (`POST /orders/{id}/cancel` o el flujo existente
   de cancelación).
2. `GET /orders/kitchen-board` inmediatamente después.
3. **Esperado**: la orden ya no aparece en ninguna columna.
4. Repetir entregando la orden (`POST /orders/{id}/deliver`, spec 147) en vez de cancelarla.
5. **Esperado**: tampoco aparece, aunque su `kitchen_status` siga siendo `"LISTO"` en la DB
   (nunca se limpia retroactivamente — el filtro del endpoint lo excluye, data-model.md).

## Tiempo real (FR-015, research.md Decisión 0)

1. Abrir dos sesiones de tablero (dos pestañas/dos tokens) del mismo tenant: una `KITCHEN`, una
   `CASHIER`.
2. Desde la sesión `KITCHEN`, mover una tarjeta.
3. **Esperado**: la sesión `CASHIER` ve el cambio de columna sin recargar, vía el mismo stream
   SSE (`GET /realtime/stream`, canal `CH_STAFF`) que ya usa el resto del POS — confirmar en
   DevTools que llega un evento `order.kitchen_status_changed`.
4. Cancelar una orden visible en el tablero desde otra pantalla del POS (p. ej. Terminal de
   Mesas).
5. **Esperado**: ambas sesiones del tablero retiran la tarjeta sin recargar (evento
   `order.cancelled` ya existente).

## Concurrencia (edge case, FR-008/SC-003)

1. Obtener el `version` vigente de una orden en `EN_PROGRESO` (p. ej. `version = 2`).
2. Disparar dos `POST /orders/{id}/kitchen-status` casi simultáneos con ese mismo `version = 2`,
   uno a `LISTO` y otro a `SIN_PREPARAR`.
3. **Esperado**: exactamente una respuesta 200 (`version` pasa a 3) y la otra 409
   `KITCHEN_STATUS_CONFLICT` con el `kitchen_status` que sí quedó aplicado.

## Verificación automatizada

- Backend: `python -m unittest discover -s app/characterization_tests -p 'test_*.py'` — nuevos
  casos en `test_orders_kitchen.py` para `change_kitchen_status` (éxito, los 4 códigos 409, 403
  por rol, concurrencia con dos locks).
- Frontend: `ng test` — nuevo spec para el componente del tablero (columnas, drag-and-drop entre
  columnas bloqueado dentro de la misma columna, manejo de los 409) y para el guard de rol.
  Criterio de éxito: ningún archivo **nuevo** fallando frente al baseline flaky documentado
  (memoria de proyecto: diff por archivo, no conteo total).
