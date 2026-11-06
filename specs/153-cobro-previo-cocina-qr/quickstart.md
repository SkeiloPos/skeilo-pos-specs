# Quickstart: Validación de 153-cobro-previo-cocina-qr

**Feature**: 153-cobro-previo-cocina-qr | **Fecha**: 2026-11-05

Guía para validar manualmente que el ajuste cumple las historias de usuario y criterios de
aceptación del spec. No sustituye los tests automatizados definidos en `tasks.md`; es la
comprobación end-to-end antes de dar la feature por completa (Principio X de la
constitución).

## Prerrequisitos

- Backend (`pos-backend`) corriendo localmente contra Postgres (ver memoria del proyecto:
  Postgres local disponible, usar el venv del proyecto para levantar/ejecutar tests).
- Frontend (`pos-heladeria`) corriendo localmente (`ng serve`) apuntando a ese backend.
- Dos tenants de prueba:
  - **Tenant A**: con el módulo de Cocina **activo** (plan que ya incluye "cocina", el
    mismo usado en specs 149-151).
  - **Tenant B**: sin el módulo de Cocina activo.
- Al menos una mesa con su QR de menú configurado en cada tenant.

## Escenario 1 — Historia 1: Cobrar envía a cocina en un solo paso (Tenant A)

1. Desde el menú QR de una mesa de Tenant A, crear un pedido con 1+ productos.
2. En el panel de la mesa (backoffice), "Recibir" el pedido (paso sin cambios).
3. Abrir el tablero de Cocina de Tenant A → confirmar que el pedido **no** aparece todavía
   en ninguna columna (FR-002, Acceptance Scenario 1.2).
4. En el panel de la mesa, cobrar el pedido. Confirmar:
   - No existe ningún botón "Entregar" activo en ese momento (FR-003, Acceptance
     Scenario 1.1).
   - La única acción visible es la de cobro, y al ejecutarla el pedido queda pagado.
5. Volver al tablero de Cocina → el pedido debe aparecer de inmediato en la columna "Sin
   preparar" (FR-001, Acceptance Scenario 1.2).
6. Volver a abrir el panel de esa mesa → el pedido se muestra como ya pagado (comprobante
   de solo lectura), sin acción de cobro pendiente (FR-005, Acceptance Scenario 1.3).

**Resultado esperado**: pasos 3-6 se cumplen exactamente en ese orden; en ningún punto
coexisten una acción de cobro activa y un botón "Entregar" activo.

## Escenario 2 — Historia 2: Entregar solo cuando cocina marca "Listo" (Tenant A)

Continuando desde el Escenario 1 (pedido ya cobrado y en cocina):

1. En el tablero de Cocina, mover el pedido a "En progreso". Abrir el panel de la mesa →
   confirmar que no se ofrece ninguna acción de "Entregar" ni de cobro (FR-004, Acceptance
   Scenario 2.1).
2. Mover el pedido a "Listo" en el tablero de Cocina.
3. Abrir el panel de la mesa → confirmar que el botón "Entregar" ahora está disponible, y
   que no hay ninguna acción de cobro activa al mismo tiempo (FR-004, Acceptance
   Scenario 2.2 y 2.3).
4. Entregar el pedido → confirmar que se marca como entregado sin error.
5. (Verificación de backend) Intentar llamar directamente a
   `POST /orders/{id}/deliver` para un pedido de mesa de Tenant A cuyo `kitchen_status`
   no sea `LISTO` → confirmar que la API lo rechaza (409), no solo la UI (ver
   `contracts/order-deliver.md`).

## Escenario 3 — Historia 3: Sin módulo de Cocina, todo igual (Tenant B)

1. Repetir el Escenario 1 completo en Tenant B. Confirmar que, a diferencia de Tenant A, la
   acción de cobro está disponible de inmediato al abrir el panel de la mesa, sin esperar
   ningún paso de cocina (FR-006, Acceptance Scenario 3.1).
2. Con un pedido de Tenant B que tenga algún producto sin marcar como entregado, confirmar
   que el botón "Entregar" aparece igual que antes de este ajuste, de forma independiente
   a la acción de cobro (FR-006, Acceptance Scenario 3.2).

## Escenario 4 — Cuenta dividida (Tenant A, clarification 2)

1. Crear un pedido de mesa en Tenant A y cobrarlo parcialmente (cuenta dividida, pago
   parcial vía `OrderPaymentAttempt`/pagos desde la app del cliente).
2. Mientras quede cualquier parte sin cobrar, confirmar en el tablero de Cocina que el
   pedido **no** aparece (FR-002).
3. Completar el 100% del cobro → confirmar que el pedido aparece de inmediato en el
   tablero de Cocina, recién en ese momento.

## Escenario 5 — No regresión en mostrador/domicilio

1. Crear y cobrar un pedido de mostrador (sin mesa) en Tenant A.
2. Confirmar que el comportamiento es idéntico al actual: se cobra y envía a cocina en un
   solo paso vía `checkout_and_send`, sin pasar por ninguno de los caminos modificados en
   este ajuste (FR-009).

## Verificación automatizada mínima (referencia, detalle en tasks.md)

- Backend: extender `app/characterization_tests/test_orders_kitchen.py` con casos para el
  nuevo guard de `deliver_order` y para el envío automático a cocina desde
  `_charge_session`/`charge_session`/`close_session`, cubriendo ambos tenants (módulo
  activo/inactivo) y el caso de cuenta dividida.
- Frontend: tests de `ensureReadyToCharge` (`pos-terminal.store.ts`) y de
  `canDeliverOrder`/`canSendToKitchen` (`order-status.util.ts`) para los dos tenants.
- No ejecutar la suite completa de ninguno de los dos repos como criterio de aceptación;
  comparar resultados por archivo afectado (ver memoria del proyecto sobre baseline
  flaky del frontend).
