# Quickstart: Validar "Nuevo Pedido en Mesa con Cuenta Pagada" (post-A-138)

Esta spec no cambia ningún comportamiento — los escenarios siguientes confirman que lo que ya
funciona (spec 087/123/049/052/010) sigue funcionando exactamente igual, y documentan las tres
decisiones negativas explícitas (sin consolidar, sin liberación forzada, sin bloqueo al crear).

## Prerrequisitos

- `pos-backend` corriendo localmente (venv del proyecto: `cd ../pos-backend && ./env/bin/python -m ...`).
- `pos-heladeria` corriendo localmente (`ng serve` o equivalente).
- Un tenant de prueba con al menos una mesa física y un turno de caja abierto.

## Escenario 1 — Crear un segundo pedido sobre una mesa ya pagada (Historia 1)

1. Crear un pedido de mesa, enviarlo a cocina y cobrarlo por completo.
2. Con cocina todavía preparándolo (ítems no todos "Listo"), seleccionar esa mesa y usar "+ Crear
   pedido nuevo".
3. **Esperado**: navega a la pantalla de creación de orden manual con la mesa preseleccionada;
   agregar un producto y confirmar crea un segundo pedido ("Pedido 2") sin alterar el primero
   ("Pedido 1"), que sigue viéndose en cocina sin cambios.

## Escenario 2 — Crear un segundo pedido con el primero sin pagar o con saldo pendiente (Historia 2, A-138)

1. Crear un pedido de mesa y enviarlo a cocina **sin cobrarlo**.
2. Seleccionar esa mesa.
3. **Esperado**: "+ Crear pedido nuevo" aparece **habilitado** (no hay ninguna condición de
   saldo) — esto es el comportamiento confirmado por A-138, no un bug.
4. Usarlo, agregar un producto y confirmar. **Esperado**: el pedido original sigue exactamente
   igual (mismo estado, mismo saldo); ambos pedidos pueden cobrarse por separado, en cualquier
   orden.
5. Repetir generando saldo pendiente por una adición posterior a facturar (spec 123) en vez de un
   pedido sin pagar — mismo resultado esperado: "+ Crear pedido nuevo" sigue habilitado.

## Escenario 3 — Sin consolidación de cuentas (FR-010)

1. Con dos o más pedidos sin resolver sobre la misma mesa (Escenario 2), revisar el panel de
   cobro de cada uno.
2. **Esperado**: no existe ninguna acción que combine el cobro o la factura de ambos pedidos en
   una sola operación — cada uno se cobra por separado, con su propia factura.

## Escenario 4 — Liberar mesa con saldo pendiente: solo anulación, sin liberación forzada (FR-011)

1. Con un pedido sin pagar sobre una mesa, intentar "Liberar Mesa".
2. **Esperado**: se bloquea (comportamiento ya existente, spec 123, sin cambios).
3. Anular ese pedido (`cancel_order`) y volver a intentar "Liberar Mesa".
4. **Esperado**: ahora procede sin error. No existe ninguna otra acción ("forzar liberación",
   "liberar con pérdida") en ningún punto de la interfaz.

## Escenario 5 — Abandonar un pedido nuevo vacío (Historia 3, sin cambios)

1. Usar "+ Crear pedido nuevo" en cualquier mesa (pagada, con saldo pendiente o sin pagar), sin
   agregar productos.
2. Pulsar "← Volver a la Terminal".
3. **Esperado**: la mesa conserva exactamente los pedidos que tenía antes, sin ningún registro
   nuevo.

## Verificación automatizada

- `cd ../pos-heladeria && npx ng test --watch=false --include='src/app/modules/tables/pages/table-sessions.component.spec.ts'`
  — confirmar en verde los tests ya existentes que protegen FR-001 ("el CTA solo se deshabilita
  por falta de mesa libre..."; "bugfix: el CTA... sigue visible con una mesa/pedido
  seleccionado") más el test nuevo de regresión que agrega research.md (Decisión 1), citando
  A-138.
- `npx ng test --watch=false --include='src/app/modules/tables/services/pos-terminal.store.spec.ts'`
  — sin regresiones.
- Diferenciar por archivo contra el baseline de fallas preexistentes ya documentado en la memoria
  del proyecto antes de asumir que algo se rompió.
- Backend: `cd ../pos-backend && ./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`
  debe seguir en verde **sin modificación** — es la prueba de que esta spec no tocó
  `has_billable_orders`/`has_pending_balance`/`compute_bill`/`release_paid_session`/
  `cancel_order` (research.md, Decisiones 4 y 6).
