# Contratos de API: Ciclo de Vida Simplificado del Pedido y Control Manual de Mesas

Contratos a nivel de comportamiento (request/response/errores), no de implementación. Los
nombres exactos de ruta/parámetros se confirman en `/speckit-tasks`; lo que no cambia es el
contrato funcional descrito aquí, derivado directamente de los Acceptance Scenarios del
spec.

## 1. Entregar un pedido completo

**`POST /orders/{order_id}/deliver`** (nombre tentativo — reemplaza semánticamente a
`POST /orders/items/{item_id}/kitchen`, que se retira, FR-002/R4).

- **Precondición de negocio**: ninguna sobre el estado — la acción es válida para
  `pendiente` y para `entregada` (reentrega, FR-002a); inválida solo para `cancelada`.
- **Comportamiento** (FR-001, FR-002a, FR-011):
  - `status == 'pendiente'` → pasa a `'entregada'`; todo ítem `'pendiente'` pasa a
    `'entregado'`. `payment_status` no cambia.
  - `status == 'entregada'` → permanece `'entregada'`; cualquier ítem `'pendiente'` (nacido
    después de la primera entrega, FR-002a) pasa a `'entregado'`. Si no había ítems
    `'pendiente'`, la operación es un no-op exitoso (idempotente).
  - `status == 'cancelada'` → **rechazo**, `409 Conflict`, "transición inválida"; ningún
    estado cambia (FR-010).
- **Concurrencia** (FR-011/SC-006): dos solicitudes casi simultáneas sobre el mismo pedido
  → ambas responden éxito (`200`), un único cambio de estado efectivo, un único evento de
  tiempo real emitido (no uno por solicitud).
- **Response**: representación del pedido con sus dos ejes de estado (`status`,
  `payment_status`) y el estado de cada ítem — igual forma que el response actual de pedido,
  sin campo nuevo.
- **Efecto secundario**: emite `order_delivered` (nuevo, `research.md` R8) en el canal de la
  sesión de mesa (si aplica) y en `staff`, después del commit.

## 2. Registrar el cobro (sin cambios de contrato, criterio de habilitación ajustado)

**Endpoint existente de cobro** (`pay_order`/`checkout_and_send`, `orders/checkout.py`).

- **Precondición de negocio** (FR-004): permitido en cualquier `status` salvo
  `'cancelada'`, sin importar si ya fue entregado o no.
- **Comportamiento** (FR-003): cambia solo `payment_status` (`'UNPAID' → 'PAID'`); `status`
  no se toca.
- **Rechazo**: `status == 'cancelada'` → `409 Conflict`, transición inválida (FR-010).

## 3. Cancelar un pedido entregado y sin cobrar

**Endpoint existente de cancelación** (`cancel_order`, `orders/checkout.py`), con motivo
obligatorio ya soportado por `OrderCancelLog.motivo`.

- **Precondición de negocio**:
  - `status == 'entregada' AND payment_status == 'UNPAID'` → permitido con `motivo`
    (FR-007).
  - `status == 'entregada' AND payment_status == 'PAID'` → **rechazo**, `409 Conflict`,
    "requiere proceso de reembolso, fuera de alcance" (FR-009).
  - `status == 'cancelada'` → rechazo, transición inválida (FR-010, Acceptance Scenario 4
    de Historia 4).
  - sin `motivo` → **rechazo**, `422`/`400`, "el motivo es obligatorio" (FR-008).
- **Comportamiento**: pedido e ítems pasan a `'cancelada'`/`'cancelado'`; no se genera
  movimiento de caja (FR-007); no bloquea la liberación de la mesa (FR-016, las órdenes
  `'cancelada'` nunca son "abiertas").

## 4. Liberar una mesa (manual, único punto de cierre)

**Endpoint existente** `POST /table-sessions/{id}/release` (`release_paid_session`,
criterio ajustado — `research.md` R5).

- **Precondición de negocio** (FR-016): ninguna orden de la sesión está "abierta", donde
  abierta = `status == 'pendiente'` OR (`status == 'entregada'` AND
  `payment_status == 'UNPAID'`). Las `cancelada` nunca cuentan como abiertas.
- **Rechazo** (FR-017, SC-004): si existe al menos una orden abierta → `409 Conflict`,
  payload incluye la lista de esas órdenes (id, estado, estado de pago) para que el cajero
  las cobre o cancele sin tener que buscarlas por separado.
- **Éxito**: cierra la `TableSession` (`status = 'closed'`), pone `DiningTable.status =
  'libre'`; emite `table_status_changed` (ya existe) y `session_closed` (ya existe) tras el
  commit.
- **Garantía explícita** (FR-015, SC-005): este es el **único** camino que pone la mesa en
  `'libre'` por una orden/sesión con actividad real; no existe temporizador que lo haga (el
  barrido de sesiones huérfanas, `research.md` R6, es un mecanismo distinto para sesiones ya
  sin comensales).

## 5. Lectura — indicadores separados y filtro "entregadas sin cobrar"

**Endpoints de lectura existentes** (detalle de pedido, Terminal de Mesas, listado de
pedidos) — sin contrato nuevo de escritura, solo garantías de lectura:

- **FR-012**: toda respuesta que incluya un pedido expone `status` y `payment_status` como
  dos campos independientes (ya es la forma actual del modelo, FR-012 solo exige que la UI
  los pinte por separado — ver `contracts` del frontend más abajo).
- **FR-013**: ningún campo de respuesta introduce una etiqueta inferida
  (`"en preparación"`, etc.) que no sea uno de los tres valores válidos de `status` o los
  tres de `estado_cocina`/dos de `payment_status`.
- **FR-014/SC-003**: un filtro (`GET` con query param, p. ej. `?entregadas_sin_cobrar=true`
  o vista dedicada — nombre a confirmar en `/speckit-tasks`) devuelve exactamente las
  órdenes con `status == 'entregada' AND payment_status == 'UNPAID'`.
- **FR-019**: el response de cada mesa ocupada en la Terminal incluye el tiempo transcurrido
  desde `TableSession.opened_at` (campo informativo, calculado en el momento de responder,
  no persistido).

## 6. Tiempo real — vista del comensal QR

**Canal SSE existente** (`GET /realtime/stream`, `app/api/v1/realtime/router.py`).

- **FR-020**: cuando una orden de origen QR cambia `status` o `payment_status`, el canal
  `session:{table_session_id}` recibe un evento (`order_delivered` nuevo para la entrega;
  `payment_completed` ya existente para el cobro) que el comensal, ya suscrito, recibe sin
  tener que recargar.
- Sin cambio de protocolo SSE (mismo formato de frame, mismo mecanismo de replay por
  `Last-Event-ID`) — solo un tipo de evento nuevo en el catálogo.
