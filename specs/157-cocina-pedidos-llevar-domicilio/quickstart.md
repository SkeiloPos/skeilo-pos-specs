# Quickstart: Validación de Envío a Cocina para Pedidos Para Llevar y Domicilio

## Prerrequisitos

- `pos-backend` corriendo localmente con Postgres (venv del proyecto, ver memoria de la
  sesión: `python -m venv env`, `pip install -r requirements.txt`, `alembic upgrade head`,
  `uvicorn app.main:app --reload`).
- Un tenant de prueba con el módulo de Cocina activo (`Plan.cocina_access = True`).
- Acceso para fijar `Plan.modalidad_pago_qr` en ese tenant (endpoint de Super Admin de spec
  154, o directamente en base de datos para pruebas locales).

## Escenario 1 — `PAY_BEFORE_RECEIVING`: cobrar envía a cocina en un solo paso

1. Fijar `modalidad_pago_qr = 'PAY_BEFORE_RECEIVING'` en el plan del tenant de prueba.
2. Crear un pedido `TAKEAWAY` (o `DELIVERY`) y confirmarlo (`status != 'cancelada'`).
3. Confirmar que **no** aparece ningún botón manual "Enviar a cocina" para ese pedido en la
   pantalla de mostrador (FR-002, ver contracts/kitchen-payment-modality.md §3).
4. Cobrar el pedido por completo: `POST /orders/{order_id}/pay` con el total cubierto.
5. **Esperado**: la respuesta de cobro es exitosa (sin cambio de contrato); al consultar el
   pedido, `kitchen_status == 'SIN_PREPARAR'` y `sent_to_kitchen_at` tiene un timestamp; el
   pedido aparece en la columna "Sin preparar" del tablero de cocina sin ninguna acción
   adicional.
6. Repetir con `DELIVERY` y confirmar el mismo resultado (FR-005).

## Escenario 2 — `PAY_AFTER_RECEIVING`: enviar a cocina sin pagar

1. Fijar `modalidad_pago_qr = 'PAY_AFTER_RECEIVING'` en el plan del tenant de prueba (o dejarlo
   en su valor por defecto).
2. Crear y confirmar un pedido `TAKEAWAY` (o `DELIVERY`), sin cobrarlo
   (`payment_status == 'UNPAID'`).
3. Llamar `POST /orders/{order_id}/send-to-kitchen`.
4. **Esperado**: 200 OK; `kitchen_status == 'SIN_PREPARAR'`, `payment_status` sigue `'UNPAID'`;
   el pedido aparece en el tablero de cocina.
5. Más tarde, cobrar el mismo pedido: `POST /orders/{order_id}/pay`.
6. **Esperado**: `payment_status` pasa a `'PAID'`; `kitchen_status` y `sent_to_kitchen_at` no
   cambian (FR-006).
7. Repetir con `DELIVERY` y confirmar el mismo resultado (FR-005).

## Escenario 3 — Regresión: `DINE_IN` y módulo de Cocina inactivo

1. Con el tenant de Escenario 1 (`PAY_BEFORE_RECEIVING`), crear un pedido `DINE_IN`, confirmar
   y cobrar. **Esperado**: comportamiento idéntico al existente antes de esta spec (patrón de
   `_charge_session`, sin cambios) — no se usa `pay_order` directamente para mesas, pero si se
   invoca, debe seguir exigiendo pago antes de cocina (FR-004).
2. En un tenant **sin** módulo de Cocina activo, crear y cobrar un pedido `TAKEAWAY`/`DELIVERY`
   en ambas modalidades de plan. **Esperado**: ningún campo ni acción de cocina visible; el
   flujo de venta/descuento de inventario ocurre igual que antes de esta spec (FR-007).

## Verificación automatizada

```bash
# Desde el venv de pos-backend:
python -m unittest app.characterization_tests.test_orders_kitchen -v
python -m unittest app.characterization_tests.test_orders_checkout -v
```

Los characterization tests existentes que fijaban "TAKEAWAY/DELIVERY nunca se auto-envían" o
"`_apply_kitchen_send` siempre exige `PAID`" deben haber sido actualizados explícitamente (con
referencia a la decisión de negocio registrada en
`specs/000-reconocimiento/registro-de-anomalias.md`) y seguir en verde junto con los tests
nuevos de los Escenarios 1–3 de este documento.

Ver [data-model.md](./data-model.md) para la tabla completa de reglas por combinación
`order_type` × módulo Cocina × modalidad, y
[contracts/kitchen-payment-modality.md](./contracts/kitchen-payment-modality.md) para el detalle
de contrato por endpoint.
