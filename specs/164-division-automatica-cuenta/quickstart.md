# Quickstart: validación de "División automática de cuenta por ítem"

Guía de validación manual/automatizada de extremo a extremo para las tres operaciones definidas
en [contracts/orders-item-transfer.md](./contracts/orders-item-transfer.md), usando los
criterios de aceptación de [spec.md](./spec.md).

## Prerrequisitos

- `pos-backend` corriendo localmente contra PostgreSQL 16 local (ver memoria
  `how-to-run-sibling-repo-tests` del usuario: hay Postgres local disponible y un comando de
  venv ya documentado para correr tests de `pos-backend`).
- Un tenant de prueba con al menos una mesa (`DiningTable`) y una `TableSession` activa.
- Autenticado como un usuario con el rol que hoy ya puede cobrar/gestionar órdenes en la
  terminal de mesas (sin permiso nuevo que configurar).

## Escenario 1 — Dividir cuenta (User Story 1, SC-001)

1. Crear (o usar `orders_fixtures.py`) una orden con 3 líneas de producto distintas, sin pago
   registrado.
2. `POST /orders/{order_id}/split`.
3. **Esperado**: respuesta `200` con `created_orders` de longitud 3; la orden original ya no
   existe (`GET /orders/{order_id}` → `404`); cada orden nueva tiene exactamente 1 línea, con
   producto/variante/cantidad/precio/`estado_cocina` idénticos a la línea original
   correspondiente.
4. Repetir con una orden de **1 sola línea**: la respuesta debe ser `200` con
   `created_orders: []` y la orden original sigue existiendo sin cambios (no-op).
5. Repetir con una orden que tenga una línea de cantidad `2` (ej. "2x ojo de diablo"): la línea
   resultante en su orden nueva debe conservar `quantity = 2` (no se fracciona por unidad).
6. Repetir sobre una orden con un pago ya registrado (`Sale` existente o `payment_status=PAID`):
   debe responder `403` y la orden original debe permanecer intacta.

## Escenario 2 — Mover ítem entre órdenes (User Story 2, SC-003)

1. Tener dos órdenes activas en la misma mesa (`order_a`, `order_b`), cada una con al menos 1
   ítem, sin pagos registrados.
2. `POST /orders/{order_a_id}/items/{item_id}/move` con `target_order_id = order_b_id` (sin
   `quantity`, mueve el total).
3. **Esperado**: el ítem desaparece de `order_a` (o `order_a` se elimina si quedó en 0 ítems),
   aparece en `order_b`, y los totales de ambas (las que sigan existiendo) quedan recalculados
   correctamente en la respuesta.
4. Repetir moviendo un ítem ya marcado `estado_cocina = entregado`: el ítem debe conservar ese
   estado en la orden destino.
5. Repetir con una línea de cantidad `2`, moviendo `quantity: 1`: `order_a` conserva una línea
   con `quantity = 1` del mismo producto; `order_b` recibe una línea (nueva o fusionada) con
   `quantity = 1` sumado.
6. Repetir el caso anterior cuando `order_b` **ya tiene** una línea con el mismo
   producto+variante+precio+`estado_cocina`: la respuesta debe traer `merged: true` y no debe
   aparecer una línea duplicada en `order_b` (verificar `GET /orders/{order_b_id}`).
7. Repetir el caso anterior pero con `estado_cocina` distinto entre la línea movida y la línea
   existente en `order_b`: la respuesta debe traer `merged: false` y `order_b` debe terminar con
   dos líneas independientes del mismo producto.
8. Intentar mover el único ítem restante de `order_a` hacia `order_b`: debe permitirse, y
   `order_a` debe dejar de existir tras la operación (`GET /orders/{order_a_id}` → `404`).
9. Intentar la operación cuando `order_a` o `order_b` tiene pago registrado: debe responder
   `403` sin modificar ninguna de las dos órdenes.
10. Intentar mover un ítem hacia una orden de **otra mesa**: debe responder `400` sin modificar
    ninguna orden.

## Escenario 3 — Crear cuenta nueva desde un ítem (User Story 3, SC-004)

1. Tener una orden con 2 ítems, sin pago registrado.
2. `POST /orders/{order_id}/items/{item_id}/split-to-new` (sin `quantity`, mueve el total de esa
   línea).
3. **Esperado**: respuesta `200` con una `new_order` que contiene únicamente ese ítem; la orden
   original conserva el ítem restante con su total recalculado.
4. Repetir cuando, tras la operación, la orden original queda sin ítems (porque tenía
   exactamente ese 1 ítem con cantidad total movida en un caso límite construido para la
   prueba): la orden original debe dejar de existir.
5. Repetir con una línea de cantidad `2`, indicando `quantity: 1`: la orden nueva debe quedar con
   `quantity = 1` de ese producto, y la orden original debe conservar una línea del mismo
   producto con `quantity = 1` restante.
6. Intentar la operación cuando el ítem elegido es la **única línea restante** de una orden que
   ya tiene un solo ítem, indicando la cantidad total de esa línea: debe responder `400` (no
   genera cambio real).
7. Repetir el caso anterior pero indicando solo una cantidad **parcial** de esa única línea
   (ej. `1` de `2`): debe permitirse (deja una línea con cantidad `> 0` en la orden original).

## Verificación de limpieza (SC-002, aplica a los 3 escenarios)

Para cada caso anterior donde una orden termina con 0 ítems: confirmar con una consulta directa
(`SELECT * FROM customer_orders WHERE id = :id`) que la fila **no existe** — no basta con que la
API no la devuelva; el requisito (FR-007/SC-002) es que se elimine de la base de datos, sin
registro vacío.

## Regresión mínima a correr antes de dar la feature por completa

- `python -m unittest app.characterization_tests.test_orders_tables_advanced -v` (move/merge de
  órdenes completas — no debe romperse por los endpoints nuevos).
- `python -m unittest app.characterization_tests.test_orders_payment_gate -v` (guard de pago —
  confirma que el patrón reutilizado por las 3 operaciones nuevas sigue vigente).
- Suite nueva: `python -m unittest app.characterization_tests.test_orders_item_transfer -v`
  (cubre los escenarios 1-3 de este quickstart).
