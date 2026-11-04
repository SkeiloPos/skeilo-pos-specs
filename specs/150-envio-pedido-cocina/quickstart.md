# Quickstart — Validación: Envío de pedido confirmado y pagado a cocina

Ver [contracts/send-to-kitchen.md](./contracts/send-to-kitchen.md) y [data-model.md](./data-model.md)
para el detalle de request/response y esquema. Esta guía valida los criterios de aceptación de
`spec.md` extremo a extremo, no repite su contenido.

## Prerrequisitos

- `pos-backend`: entorno levantado (`docker compose up -d postgres redis`), venv activo
  (`pos-backend/env`), migraciones al día (`alembic upgrade head`, incluida la nueva de esta
  spec).
- Un tenant de prueba con un plan cuyo `cocina_access = true` (editable desde el panel de
  Super Admin, o directamente en `shared.plans` para pruebas locales).
- Un usuario de ese tenant con rol `ADMIN` o `CASHIER` autenticado (token JWT).
- Un pedido (`CustomerOrder`) de cualquier origen (mostrador, mesa o domicilio) creado vía los
  flujos ya existentes.

## Escenario 1 — Envío exitoso (Historia 1, FR-001/FR-003/FR-004/FR-005)

1. Crear un pedido y llevarlo a `payment_status = 'PAID'` (flujo normal de cobro:
   `checkout.checkout_and_send`/`confirm_order` + pago).
2. Verificar que `kitchen_status` es `NULL` y `status != 'cancelada'`.
3. `POST /orders/{order_id}/send-to-kitchen` con un usuario `CASHIER` o `ADMIN`.
4. **Esperado**: `200`, respuesta con `kitchen_status: "SIN_PREPARAR"` y `sent_to_kitchen_at`
   poblado con una marca de tiempo cercana a la hora actual del servidor (no del cliente).
5. Repetir con pedidos de los otros dos orígenes (mesa, domicilio) y confirmar el mismo resultado
   (FR-002) — en la UI, confirmar que el botón "Enviar a cocina" aparece para los tres antes del
   paso 3 y desaparece después.

## Escenario 2 — Rechazo por falta de pago (Historia 2, FR-006)

1. Crear un pedido con `payment_status = 'UNPAID'`, `status != 'cancelada'`, `kitchen_status`
   `NULL`.
2. En la UI: confirmar que el botón "Enviar a cocina" no se muestra.
3. `POST /orders/{order_id}/send-to-kitchen` directamente (sin pasar por el botón).
4. **Esperado**: `409`, `error.code == "ORDER_NOT_PAID"`. `kitchen_status` sigue `NULL` tras la
   llamada.

## Escenario 3 — Rechazo por envío duplicado / concurrencia (Historia 3, FR-007/FR-008/SC-003)

1. Ejecutar el Escenario 1 hasta completar un envío exitoso (`kitchen_status = "SIN_PREPARAR"`,
   `sent_to_kitchen_at = t0`).
2. `POST /orders/{order_id}/send-to-kitchen` una segunda vez sobre el mismo pedido.
3. **Esperado**: `409`, `error.code == "ALREADY_IN_KITCHEN"`. `sent_to_kitchen_at` sigue siendo
   `t0` (no se reescribe). En la UI: ningún mensaje de error visible — el botón simplemente
   permanece oculto tras el refresco (clarificación 2 de `spec.md`).
4. (Opcional, concurrencia real) Disparar dos `POST` casi simultáneos sobre un pedido elegible
   (ej. dos requests en paralelo con `curl`/un script) y confirmar que exactamente uno responde
   `200` y el otro `409 ALREADY_IN_KITCHEN`, sin que el pedido aparezca duplicado en
   `SELECT ... WHERE kitchen_status IS NOT NULL ORDER BY sent_to_kitchen_at`.

## Escenario 4 — Edge cases

- **Módulo "cocina" inactivo para el tenant**: con `cocina_access = false` en el plan del
  tenant, repetir el Escenario 1. **Esperado**: el botón no se muestra en la UI; el `POST`
  directo responde `403` con `code: "MODULE_NOT_IN_PLAN"`, `module: "cocina"`.
- **Orden cancelada**: crear un pedido y cancelarlo (`status = 'cancelada'`), luego intentar
  `POST /orders/{order_id}/send-to-kitchen`. **Esperado**: `409`,
  `error.code == "ORDER_NOT_CONFIRMED"`.
- **Rol no autorizado**: repetir el Escenario 1 con un usuario de rol distinto de
  `ADMIN`/`CASHIER` (ej. `MESERO`). **Esperado**: `403` (sin `code`, mensaje plano de rol).
- **Orden pagada y enviada, pago revertido después**: no aplica ningún rollback automático
  (fuera de alcance, ver "Assumptions" de `spec.md`) — confirmar que revertir manualmente
  `payment_status` a `'UNPAID'` después de un envío exitoso no cambia `kitchen_status` ni
  `sent_to_kitchen_at` (ninguna lógica de esta spec los vuelve a tocar).

## Verificación de la migración

```sql
-- Tras alembic upgrade head, en cualquier esquema de tenant:
SELECT count(*) FROM customer_orders WHERE kitchen_status IS NOT NULL;
-- Esperado: 0 (ningún pedido histórico nace "ya enviado a cocina").

SELECT count(*) FROM customer_orders WHERE sent_to_kitchen_at IS NOT NULL;
-- Esperado: 0.
```

## Verificación automatizada

- Backend: `python -m unittest app.characterization_tests.test_orders_kitchen -v` (incluye los
  casos nuevos de `send_to_kitchen` agregados por esta spec, más los ya existentes de
  `receive_order`/`deliver_order`/`void_item`, que no deben romperse).
- Frontend: `ng test` — comparar el conjunto de archivos que fallan contra el baseline conocido
  en `specs/148-disponibilidad-productos-tiempo-real/checklists/baseline-suites.md` (incluye ya
  `pos-order-panel`/`manual-order-page`/`pos-terminal.store.spec.ts` como flaky conocidos); el
  criterio de éxito es que no aparezcan **archivos nuevos** fallando, no un conteo total de 0
  fallos.
