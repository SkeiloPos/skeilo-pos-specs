# Contrato: Envío a cocina gobernado por modalidad de cobro (TAKEAWAY/DELIVERY)

Este documento describe el cambio de comportamiento sobre endpoints HTTP **existentes** —
ninguna ruta nueva se introduce. Las firmas y formatos de request/response no cambian; cambia
cuándo cada uno tiene éxito o falla, y un efecto lateral nuevo en uno de ellos.

## 1. `POST /orders/{order_id}/pay` (cobro genérico, `pay_order`)

Sin cambios de request/response. Nuevo efecto lateral, solo cuando se cumplen **todas**:

- El tenant tiene el módulo de Cocina activo (`cocina_access = True`).
- El pedido es `TAKEAWAY` o `DELIVERY` (`dining_table_id IS NULL`).
- La modalidad del plan es `PAY_BEFORE_RECEIVING`.
- El pedido no está ya en cocina (`kitchen_status IS NULL`).
- El pedido no está `cancelada`.

En ese caso, en la misma transacción que fija `payment_status = PAID`, también se fija
`kitchen_status = 'SIN_PREPARAR'` y `sent_to_kitchen_at = now()`. Tras el commit, se emite
`events.order_sent_to_kitchen` además de los eventos de cobro ya existentes (mismo patrón que
`_charge_session` para mesas).

Si alguna de las condiciones no se cumple (p. ej. modalidad `PAY_AFTER_RECEIVING`, o módulo de
Cocina inactivo), el cobro se completa exactamente como hoy, sin ningún efecto sobre
`kitchen_status`.

## 2. `POST /orders/{order_id}/send-to-kitchen` (envío manual, `send_to_kitchen`)

Sin cambios de request/response. Cambia la condición de éxito/error `ORDER_NOT_PAID`:

| Condición previa | Hoy (antes de esta spec) | Después de esta spec |
|---|---|---|
| `DINE_IN`, `payment_status = UNPAID` | 409 `ORDER_NOT_PAID` | 409 `ORDER_NOT_PAID` (sin cambios) |
| `TAKEAWAY`/`DELIVERY`, módulo Cocina activo, modalidad `PAY_BEFORE_RECEIVING`, `payment_status = UNPAID` | 409 `ORDER_NOT_PAID` | 409 `ORDER_NOT_PAID` (sin cambios — FR-004) |
| `TAKEAWAY`/`DELIVERY`, módulo Cocina activo, modalidad `PAY_AFTER_RECEIVING`, `payment_status = UNPAID` | 409 `ORDER_NOT_PAID` | **200 OK** — transiciona a `SIN_PREPARAR` (FR-003) |
| Cualquier combinación con `payment_status = PAID` | 200 OK | 200 OK (sin cambios) |

El resto de las validaciones (`ORDER_NOT_CONFIRMED` si `status = 'cancelada'`,
`ALREADY_IN_KITCHEN` si `kitchen_status IS NOT NULL`) no cambian para ningún caso.

## 3. Lectura de la modalidad en respuestas de staff (frontend)

`OrderResponse.qr_payment_instruction_mode` (campo existente de spec 154) se empieza a
computar también para las respuestas de los endpoints de staff que alimentan la pantalla de
pedidos de mostrador/domicilio (hoy solo se computaba para el contexto QR_MENU en
`cart/router.py`). Mismo patrón de cómputo: `plan_service.get_qr_payment_instruction_mode(db,
tenant)`, sin persistir el valor en la orden.

El frontend usa este campo, junto con `order_type` y el estado del módulo de Cocina ya
disponibles, para decidir si mostrar el botón manual "Enviar a cocina" (oculto exactamente
cuando la fila 2 de la tabla anterior aplicaría — FR-002).

## No-contrato: rutas fuera de alcance

- `POST /table-sessions/{id}/charge` (`_charge_session`): sin cambios. Sigue aplicando
  únicamente a `DINE_IN`.
- `checkout_and_send` (`hold_for_payment`): fuera de alcance de esta spec (ver research.md,
  Decisión 4). Si algún flujo de UI activo depende de ella para TAKEAWAY/DELIVERY con módulo de
  Cocina activo, se reporta como hallazgo antes de modificarla.
