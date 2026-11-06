# Contrato: Cobro de sesión de mesa (`POST /table-sessions/{id}/charge`, `/close`)

**Feature**: 153-cobro-previo-cocina-qr

No se introducen endpoints nuevos. Este documento describe el cambio de **comportamiento**
de los endpoints existentes `POST /table-sessions/{id}/charge` y
`POST /table-sessions/{id}/close` (backend `charge_session`/`close_session` →
`_charge_session`, `table_sessions/service.py:328`), consumidos por
`TableSessionService.charge()`/`.close()` (frontend).

## Request

Sin cambios en el esquema del request (`billing_mode`, método de pago, etc. permanecen
igual). No se añade ningún parámetro nuevo: la decisión de "¿este tenant envía a cocina al
cobrar?" se resuelve internamente consultando el módulo de plan del tenant, no mediante un
flag que el cliente deba enviar.

## Comportamiento — ANTES de este ajuste

1. El backend exige, vía `_assert_closable`, que ningún ítem de ningún pedido de la sesión
   esté en `estado_cocina=='pendiente'` — sin importar si el tenant tiene el módulo de
   Cocina activo.
2. Si hay ítems pendientes, el backend responde con error; el frontend atrapa ese caso
   **antes** de llamar al endpoint (vía `ensureReadyToCharge`), entregando primero cada
   pedido pendiente (`POST /orders/{id}/deliver`) y solo entonces reintentando el cobro.
3. El cobro exitoso deja `payment_status=='PAID'`; `kitchen_status` nunca se toca desde
   este endpoint.

## Comportamiento — DESPUÉS de este ajuste

1. **Si el tenant NO tiene el módulo de Cocina activo**: sin cambios respecto a "ANTES".
   (FR-006)
2. **Si el tenant SÍ tiene el módulo de Cocina activo**:
   - `_assert_closable` deja de exigir que los ítems estén entregados. El cobro procede
     sin ninguna llamada previa a `/deliver`. (FR-001, FR-003)
   - Al completarse el cobro con éxito, para cada pedido de la sesión cuyo
     `payment_status` queda en `PAID` tras esta operación, el backend invoca
     internamente la misma transición que hoy ejecuta `send_to_kitchen`
     (`kitchen_status: NULL → SIN_PREPARAR`, `sent_to_kitchen_at = now()`), siempre que
     ese pedido tenga `dining_table_id` (solo pedidos de mesa, FR-009) y
     `kitchen_status IS NULL` (idempotencia: nunca reenvía un pedido ya enviado). (FR-001,
     FR-002)
   - Si la sesión se cobra parcialmente (cuenta dividida vía `OrderPaymentAttempt`) y
     algún pedido de la sesión aún no alcanza `payment_status=='PAID'`, ese pedido
     específico **no** se envía a cocina en esta invocación; se evalúa de nuevo en el
     siguiente cobro parcial que sí lo deje en `PAID`. (FR-002, clarification 2)

## Response

Sin cambios en el esquema de la respuesta. El cliente puede observar el efecto
(`kitchen_status` del pedido pasó de `NULL` a `SIN_PREPARAR`) recargando el pedido/sesión
por los endpoints de lectura ya existentes, igual que hoy observa cualquier otro cambio de
estado tras un cobro.

## Errores

- Ningún código de error nuevo. El caso "no se pudo entregar antes de cobrar" (409 que
  hoy puede surgir de `_assert_closable`) deja de ser alcanzable para tenants con el
  módulo de Cocina activo, porque la condición que lo dispara deja de evaluarse para ellos.
- El envío automático a cocina reutiliza las mismas condiciones de `send_to_kitchen`
  (`kitchen_status IS NULL`, `payment_status=='PAID'`); si por alguna razón no se cumplen
  para un pedido puntual, ese pedido simplemente no se envía en este paso — no se propaga
  un error al response del cobro (el cobro en sí fue exitoso; el envío a cocina es un
  efecto derivado, no una precondición del cobro).
