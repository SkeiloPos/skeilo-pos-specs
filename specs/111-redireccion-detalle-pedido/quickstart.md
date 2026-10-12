# Quickstart: Redirección al detalle del pedido tras crearlo

**Spec**: [spec.md](./spec.md) | **Contratos**: [contracts/post-orders.md](./contracts/post-orders.md),
[contracts/order-detail-navigation.md](./contracts/order-detail-navigation.md)

> **Corregido durante la implementación** (ver `tasks.md`, Fase 3): "la vista de detalle" es la
> terminal (`/dashboard/mesas-sesiones`) mostrando el pedido ya seleccionado, no una ruta nueva.
> Los escenarios 3 y 8 de esta versión anterior ya no aplican tal como estaban escritos; se
> reescribieron.

## Prerrequisitos

- `pos-backend` corriendo localmente con la migración de esta spec aplicada (`alembic upgrade head`).
- `pos-heladeria` corriendo localmente contra ese backend (`ng serve` o equivalente).
- Usuario cajero, mesero o admin autenticado en la terminal POS.
- Al menos un producto disponible en el catálogo para armar un pedido de prueba.

## Escenario 1 — Camino feliz (Para llevar)

1. En la terminal, pestaña "Para llevar", iniciar una nueva orden.
2. Agregar 1 "Ensalada de frutas grande" (o cualquier producto disponible) al carrito.
3. Pulsar "Crear pedido".
4. **Esperado**: vuelve a la terminal, en la pestaña "Para llevar", con ese pedido ya seleccionado:
   el panel central muestra el encabezado "Para llevar", el estado "en preparación" (mientras el
   ítem no esté marcado listo), el ítem con estado "Pendiente", y el panel "Cobrar pedido" con el
   total correcto (spec.md, User Story 1, escenario 1).

## Escenario 2 — Los tres tipos de pedido

Repetir los pasos 1-4 del Escenario 1 para "Mesa" y "Domicilio". Verificar la pestaña activa y la
selección contra la tabla de [contracts/order-detail-navigation.md](./contracts/order-detail-navigation.md).

## Escenario 3 — La pestaña activa respeta el tipo de pedido

Crear un pedido de Mesa → debe volver con la pestaña "Mesas" activa y esa mesa/pedido
seleccionados. Repetir para Para llevar (pestaña "Para llevar") y Domicilio (pestaña
"Domicilios") — no siempre "Mesas" por defecto sin nada seleccionado, que es el bug actual.

## Escenario 4 — Error del servidor

1. Forzar un error en `POST /orders` (p. ej. deteniendo el backend o interceptando la petición con
   las herramientas de desarrollador del navegador para forzar un 5xx).
2. Con productos en el carrito, pulsar "Crear pedido".
3. **Esperado**: sigue en "Nueva orden", el carrito conserva productos/cantidades/tipo, aparece el
   mensaje "No se pudo crear el pedido. Intenta de nuevo.", y no aparece ningún pedido nuevo en
   ninguna pestaña de la terminal ni en "Órdenes".

## Escenario 5 — Doble clic no duplica el pedido

1. Con productos en el carrito, hacer doble clic rápido en "Crear pedido".
2. **Esperado**: el botón se deshabilita y muestra "Guardando…" desde el primer clic; se crea un
   único pedido; la terminal vuelve con ese único pedido seleccionado.

## Escenario 6 — Reintento de red no duplica el pedido (backend)

1. Con un cliente HTTP (`curl`/Postman/Insomnia), enviar dos veces la misma solicitud
   `POST /orders` con idéntico `client_request_id` en el cuerpo (simulando que el frontend
   reintentó tras no recibir respuesta).
2. **Esperado**: ambas respuestas son `2xx` y devuelven el mismo `id` de pedido; en la base de
   datos solo existe un `CustomerOrder` con ese `client_request_id` (ver
   [contracts/post-orders.md](./contracts/post-orders.md)).

## Escenario 7 — Recargar el navegador mantiene la selección

Tras el Escenario 1, recargar el navegador (F5) en
`/dashboard/mesas-sesiones?pestana=para-llevar&pedido=<id>`. **Esperado**: la terminal vuelve a
mostrar el mismo pedido seleccionado, porque toda la información necesaria vive en la URL, no en
memoria del store.

## Escenario 8 — No hay regresión al entrar a la terminal por otro camino

Entrar a `/dashboard/mesas-sesiones` desde el menú de navegación (sin ningún pedido recién creado
de por medio). **Esperado**: comportamiento sin cambios — pestaña "Mesas" por defecto, nada
seleccionado (FR-010). Igualmente, abrir el detalle de cualquier pedido desde el panel admin
"Órdenes" (`/dashboard/orders/:id`) sigue sin cambios — esa vista no interviene en este flujo.

## Verificación automatizada (referencia)

- **Backend**: `./env/bin/python -m unittest app.characterization_tests.test_orders_service.TestCreateOrderIdempotencia`
  — casos de prueba en [contracts/post-orders.md](./contracts/post-orders.md).
- **Frontend**: `npx ng test --watch=false` sobre `manual-order-page.component.spec.ts`,
  `pos-terminal.store.spec.ts` y `table-sessions.component.spec.ts` — casos de prueba en
  [contracts/order-detail-navigation.md](./contracts/order-detail-navigation.md).
