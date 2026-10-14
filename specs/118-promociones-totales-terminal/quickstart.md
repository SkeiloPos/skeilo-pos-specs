# Quickstart — Spec 118

**Fecha**: 2026-10-14 · **Spec**: [spec.md](./spec.md) · **Contratos**: [contracts/](./contracts/)

Valida de punta a punta que el `TOTAL` de las tarjetas de Mesas/Domicilios/Para llevar, el detalle
de la orden y "Pagos por confirmar" coinciden cuando hay promociones por volumen vigentes, y que el
detalle agrupa visualmente adiciones sucesivas de la misma presentación. No requiere migración (ver
[data-model.md](./data-model.md)).

## Prerrequisitos

- `pos-backend` en la rama de esta spec, levantado con `uvicorn` nativo (no Docker — ver memoria
  `reference_pos_api_docker_vs_nativo`), base de datos de desarrollo con al menos un tenant.
- `pos-heladeria` en la rama de esta spec, `ng serve` apuntando a ese backend.
- Una promoción por volumen activa y vigente (sin restricción de horario) sobre una presentación de
  precio conocido, ej. "Fresa boom" a `$7.000` con regla `2 x $12.000`.
- Una segunda presentación a precio regular conocido (sin promoción), ej. "Ensalada de frutas" a
  `$14.000`, para el escenario de la tarjeta de Mesas del spec (Acceptance Scenario 1 de Historia 1).

## Escenario 1 — Historia 1 (el TOTAL de la tarjeta coincide con el cobro real)

1. Terminal POS → Mesas: abrir "Mesa 1", agregar 2 × "Fresa boom" (en una sola adición) + 1 ×
   "Ensalada de frutas". Guardar el pedido.
2. Volver a la vista general de Mesas.
3. **Esperado**: la tarjeta de "Mesa 1" muestra `TOTAL = $26.000` (`12.000 + 14.000`), no `$30.000`
   (`14.000 + 14.000` sin descuento). Ver
   [contracts/order-item-discount-snapshot.md](./contracts/order-item-discount-snapshot.md).
4. Abrir el detalle de esa mesa: el subtotal de la línea de "Fresa boom" muestra `$12.000` con
   insignia de promoción y precio tachado `$14.000`.
5. Abrir el módulo de cobro de esa misma orden: el total a cobrar coincide con `$26.000`, sin
   desfase frente a la tarjeta ni al detalle (FR-002).
6. Repetir el mismo armado en una orden de **Domicilios** y otra de **Para llevar**: mismo resultado
   en ambas pestañas (FR-003).

## Escenario 2 — Historia 2 (adiciones sucesivas: el detalle agrupa visualmente)

1. Terminal POS → Mesas: abrir una mesa nueva, agregar 1 × "Fresa boom" (quantity 1) y guardar.
2. Esperado tras guardar: el detalle muestra "Fresa boom ×1" a precio regular `$7.000`, sin
   insignia.
3. Agregar otro producto de por medio (ej. 1 × "Ensalada de frutas") y guardarlo, para simular que
   pasa un momento distinto.
4. Agregar una **segunda** unidad de "Fresa boom" (otra adición directa del mesero, `POST
   /orders/{id}/items`) y guardar.
5. **Esperado**: el detalle muestra **una sola card** de "Fresa boom" con `×2`, insignia de
   promoción, precio tachado `$14.000` y monto ajustado `$12.000` — el mismo formato que si las 2
   unidades se hubieran agregado juntas desde el inicio (FR-005/FR-007). Ver
   [contracts/detail-panel-line-grouping.md](./contracts/detail-panel-line-grouping.md).
6. Recargar la página (`GET /orders/{id}` fresco, no solo estado en memoria del navegador):
   verificar que la card agrupada persiste igual tras la recarga (confirma que el dato vive en el
   backend, no es un cálculo efímero del cliente).
7. Anular una de las dos unidades de "Fresa boom" (botón de anular sobre esa línea).
8. **Esperado**: el detalle vuelve a mostrar "Fresa boom ×1" a precio regular `$7.000`, sin insignia
   (FR-006).

## Escenario 3 — "Pagos por confirmar" con adiciones sucesivas (FR-004, Acceptance Scenario 4)

1. Desde el Menú QR de una mesa, un comensal pide 1 × "Fresa boom" y envía el pedido con un método
   de pago en efectivo (queda `recibida`, con intento de pago pendiente).
2. Desde la Terminal POS, el mesero anexa 1 unidad más de "Fresa boom" al mismo pedido
   (`POST /orders/{id}/items`) — simula el Edge Case de canales mixtos del spec.
3. El cajero abre "Pagos por confirmar" para ese pedido y confirma el efectivo recibido con
   `$12.000`.
4. **Esperado**: confirma sin el error "monto menor al total" y con cambio `$0` — el panel ya
   validaba contra `compute_checkout_preview` (research.md D5); este escenario solo verifica que
   sigue siendo correcto cuando las unidades llegaron por canales/momentos distintos.

## Escenario 4 — Edge cases del spec

1. **Promociones mixtas en la misma orden**: agregar una línea con promoción por volumen y otra con
   una promoción porcentual distinta, en la misma orden. **Esperado**: el `TOTAL` de la tarjeta
   descuenta ambas (FR-001 — "para cualquier tipo de promoción vigente").
2. **Promoción deja de estar vigente entre agregar y cobrar** (ej. horario): si la regla tiene
   ventana horaria, agregar las unidades dentro de la ventana y luego, ya fuera de la ventana, abrir
   el detalle/tarjeta/pagos por confirmar. **Esperado**: las tres superficies reflejan la vigencia
   del momento en que se consultan (ya es el comportamiento de `evaluate_variant_sets`/
   `promotion_evaluation_instant` — este escenario es de regresión, no de código nuevo).
3. **Orden con combo + línea plana con promoción por volumen**: verificar que el combo sigue
   mostrándose con su propio mecanismo (sin cambios) y la línea plana con promoción por volumen se
   descuenta igual que en el Escenario 1, sin interferencia entre ambos.

## Verificación automatizada

- Backend: `python -m unittest discover -s app/characterization_tests -p 'test_*.py'` — deben pasar
  los tests nuevos listados en `research.md` (`test_orders_service.py`,
  `test_orders_consolidation.py`, `test_orders_kitchen.py`, `test_orders_payment_gate.py`) y seguir
  pasando `test_cart_service.py` (solo cambia el import de `line_discount_snapshot`) y
  `test_orders_billing_summary.py` (el `billing=null` del listado, spec 094 D3, no se toca).
- Frontend: `npx ng test --watch=false` — deben pasar `pos-terminal.store.spec.ts` (agrupamiento
  nuevo + regresión de los bloques existentes de `tablesView`/`ordersByType`, incluido el test que
  verifica que no se dispara `checkout-preview` por tarjeta) y
  `pos-order-panel.component.spec.ts` (una sola card renderizada).
- Regresión explícita: una `Sale`/`Invoice` ya emitida antes de esta spec, y un pedido abierto que
  **no** recibe ninguna mutación nueva tras el despliegue, no cambian de valor al leerse
  (`SC-004` + research.md D7) — no requiere ningún paso manual porque no hay backfill que verificar.
