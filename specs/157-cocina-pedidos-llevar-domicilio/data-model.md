# Data Model: Envío a Cocina de Pedidos Para Llevar y Domicilio

No se introducen entidades, campos ni migraciones nuevas. Este documento describe el
**comportamiento** de los campos existentes que esta funcionalidad modifica, no su esquema.

## CustomerOrder (existente, sin cambio de esquema)

| Campo | Tipo | Rol en esta funcionalidad |
|---|---|---|
| `order_type` | `DINE_IN` / `TAKEAWAY` / `DELIVERY` | Determina si aplica la regla nueva (TAKEAWAY/DELIVERY) o la regla intacta de spec 153 (DINE_IN, vía `dining_table_id is not None`) |
| `dining_table_id` | UUID nullable | Discriminador real usado por el código hoy para "es pedido de mesa"; no nulo ⇔ `DINE_IN` en la práctica. Esta spec no lo modifica. |
| `payment_status` | `UNPAID` / `PAID` | Condición de envío a cocina; se vuelve condicional (no siempre exigida) para TAKEAWAY/DELIVERY bajo `PAY_AFTER_RECEIVING` |
| `kitchen_status` | `NULL` / `SIN_PREPARAR` / `EN_PROGRESO` / `LISTO` | Transición `NULL → SIN_PREPARAR` ahora alcanzable para TAKEAWAY/DELIVERY por dos caminos nuevos (auto-envío al cobrar, o envío manual sin cobro) |
| `sent_to_kitchen_at` | timestamp nullable | Se fija igual que hoy, en el mismo instante de la transición anterior |
| `status` | `pendiente`/`confirmado`/`entregada`/`cancelada` | Sin cambios; "confirmado" (no cancelado) sigue siendo la condición de elegibilidad base |

## Plan (existente, sin cambio de esquema — spec 154)

| Campo | Tipo | Rol en esta funcionalidad |
|---|---|---|
| `modalidad_pago_qr` | `PAY_AFTER_RECEIVING` / `PAY_BEFORE_RECEIVING`, `NOT NULL DEFAULT 'PAY_AFTER_RECEIVING'` | Extiende su efecto: además de gobernar el mensaje del menú QR (spec 154), ahora también gobierna cuándo se dispara el envío a cocina para TAKEAWAY/DELIVERY (esta spec) |
| `cocina_access` | boolean | Gate de módulo existente (spec 149); sin cambios — esta funcionalidad solo aplica cuando es `True` |

## Regla derivada: `kitchen_requires_prior_payment(order, modalidad)`

No es un campo persistido — es la regla de negocio central que gobierna la transición
`kitchen_status: NULL → SIN_PREPARAR`, evaluada en el momento de cada intento de envío (manual o
automático):

| `order_type` | módulo Cocina activo | modalidad del plan | ¿Exige `payment_status = PAID` antes de enviar a cocina? |
|---|---|---|---|
| `DINE_IN` | — | — | Sí, siempre (sin cambios, spec 153) |
| cualquiera | No | — | N/A — no hay `kitchen_status`, flujo actual sin cambios (FR-007) |
| `TAKEAWAY`/`DELIVERY` | Sí | `PAY_BEFORE_RECEIVING` | Sí — y además se dispara automáticamente al completarse el pago (FR-002) |
| `TAKEAWAY`/`DELIVERY` | Sí | `PAY_AFTER_RECEIVING` (o sin configurar, por el default `NOT NULL` del campo) | No — se permite el envío manual con `payment_status = UNPAID` (FR-003) |

## Transiciones de estado afectadas

```
CustomerOrder.kitchen_status: NULL → SIN_PREPARAR

Disparadores posibles (tras esta spec, para TAKEAWAY/DELIVERY + módulo Cocina activo):
  1. Cobro completo (payment_status → PAID) cuando modalidad = PAY_BEFORE_RECEIVING
     → automático, mismo acto, sin botón manual (FR-002).
  2. Acción manual "Enviar a cocina" cuando modalidad = PAY_AFTER_RECEIVING
     → permitido con payment_status = UNPAID (FR-003).
  3. (Sin cambio) Acción manual "Enviar a cocina" con payment_status ya = PAID,
     en cualquier modalidad → sigue permitido (comportamiento ya existente, FR-004).

CustomerOrder.payment_status: UNPAID → PAID

  Disparador: flujo de cobro existente (`pay_order`), sin cambios en su lógica de
  cobro/facturación — solo se le añade el efecto lateral del disparador 1 arriba.
  No altera kitchen_status si éste ya alcanzó SIN_PREPARAR/EN_PROGRESO/LISTO (FR-006).
```

## Invariantes que se preservan

- `kitchen_status` nunca retrocede de `SIN_PREPARAR`/`EN_PROGRESO`/`LISTO` a `NULL` (sin
  cambios respecto a spec 150).
- Un pedido `cancelada` nunca transiciona a `SIN_PREPARAR` (sin cambios).
- La transición es idempotente: un segundo intento de envío sobre un pedido que ya tiene
  `kitchen_status IS NOT NULL` no hace nada (vía `_apply_kitchen_send`, sin cambios en esa
  guarda).
- Ningún pedido `DINE_IN` existente cambia de comportamiento: la nueva regla solo se evalúa
  cuando `order.dining_table_id is None`.
- Ningún pedido ya enviado a cocina antes de un cambio de modalidad del plan se reevalúa
  retroactivamente (edge case de spec.md) — la regla se consulta solo en el momento del
  intento de envío, nunca en batch sobre pedidos existentes.
