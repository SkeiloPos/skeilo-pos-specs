# Research: Cobro independiente de pedidos por mesa

## Contexto de código relevante (hoy)

- `pos-backend/app/models/customer_order.py`: `CustomerOrder` ("Pedido") ya tiene
  `payment_status` (`'UNPAID'|'PAID'`) como campo propio, independiente de `status`
  (`'pendiente'|'confirmado'|'entregada'|'cancelada'`). Introducido en spec 147.
- `pos-backend/app/api/v1/table_sessions/service.py`:
  - `_billable_orders(db, table_session_id)` (línea 200): selecciona **todos** los
    pedidos no cancelados, no pagados, sin `Sale` ya emitida de la sesión. No acepta
    hoy un subconjunto explícito.
  - `_assert_closable(db, orders, tenant=None)` (línea 302): valida, sobre la lista
    de `orders` que recibe (no sobre "toda la sesión" por constante interna), que
    ninguno esté `'pendiente'` ni tenga ítems en curso de cocina (salvo módulo Cocina
    activo). Ya está parametrizado por lista — hoy siempre se le pasa el resultado
    completo de `_billable_orders`.
  - `_charge_session(db, table_session_id, data, cashier, ...)` (línea 344): obtiene
    `orders = _billable_orders(...)`, valida con `_assert_closable`, cobra con
    `_close_unified`/`_close_split` (que ya reciben `orders` como parámetro genérico),
    y marca `order.payment_status = "PAID"` solo para ese `orders`. Es decir: **la
    función de cobro ya es genérica sobre cualquier lista de pedidos** — lo único que
    falta es poder restringir esa lista a una selección explícita del cajero en vez
    de "todos los facturables".
  - `charge_session` (línea 497, `POST /table-sessions/{id}/charge`): cobra sin
    cerrar la sesión ni liberar la mesa — ya es el endpoint correcto para "cobro
    parcial, la mesa sigue abierta" (spec 147 ciclo 2).
  - `close_session` (línea 417, `POST /table-sessions/{id}/close`): cobra **y**
    libera la mesa en la misma transacción. Siempre opera sobre `_billable_orders`
    completo.
  - `release_paid_session` (línea 555, `POST /table-sessions/{id}/release`): único
    camino para liberar la mesa; ya rechaza (409) si queda algún pedido `'pendiente'`
    o `'entregada'` con `payment_status='UNPAID'`. No requiere cambios para FR-005/006.
- `pos-backend/app/api/v1/orders/router.py` / `checkout.py`: `POST /orders/{id}/cancel`
  ya cancela un pedido individual (`status='cancelada'`) sin afectar a otros pedidos
  de la misma mesa — satisface FR-008 sin cambios.
- Frontend (`pos-heladeria/src/app/modules/tables/`):
  - `pos-terminal.store.ts`: ya construye pestañas "Pedido N" (`table_order_number`)
    y ya expone `payment_status` por pedido (`paymentStatusLabel`/`paymentStatusClass`).
  - `pos-checkout-panel.component.ts` / `session-bill-panel.component.ts`: el botón
    "Cobrar" siempre dispara `charge()`/`close()` del `table-session.service.ts` sin
    ningún parámetro de selección — cobra siempre todo lo facturable de la sesión.

## Decisiones

### D1 — Dónde se agrega la selección de pedidos
**Decisión**: agregar un campo opcional `order_ids: list[UUID] | None` al payload que
ya usa `POST /table-sessions/{id}/charge` (reutilizando o extendiendo `CloseSessionIn`).
Cuando se omite o es `None`, el comportamiento es idéntico al actual (cobra todos los
pedidos facturables) — compatibilidad total con el flujo existente (Edge case: mesa
con un único pedido no cambia).

**Alternativas consideradas**: crear un endpoint nuevo `POST
/table-sessions/{id}/charge-orders`. Rechazada: duplicaría la lógica de `_close_unified`/
`_close_split`/eventos que ya vive en `charge_session`, y el contrato (`billing_mode`,
`payments`/`splits`) es idéntico; basta con acotar qué pedidos entran.

### D2 — `close` (cobrar + liberar) NO acepta selección parcial
**Decisión**: `order_ids` solo se admite en `/charge`, no en `/close`. `close_session`
sigue cobrando y liberando **todo** lo facturable de la sesión en un solo paso.

**Razón**: liberar la mesa con pedidos aún pendientes de pago violaría FR-005/FR-006
("la mesa permanece abierta mientras existan pedidos pendientes... hasta que el
cajero libere explícitamente"). Si el cajero solo quiere cobrar un pedido y dejar la
mesa abierta para los demás, el camino ya existente es `charge` (parcial) seguido más
tarde de `release` una vez todos pagados — exactamente el "modo híbrido" que ya
soporta `release_paid_session` desde spec 028/147. No se requiere ningún cambio en
`close_session` ni en `release_paid_session`.

### D3 — Alcance de `_assert_closable` cuando se cobra un subconjunto
**Decisión**: `_assert_closable` sigue validando únicamente la lista de `orders` que
efectivamente se va a cobrar (ya es su comportamiento actual, solo que hasta ahora esa
lista siempre era "todos los facturables"). Al cobrar solo el Pedido 42, el chequeo de
"sin confirmar"/"cocina en curso" se evalúa solo sobre el Pedido 42; el estado del
Pedido 41 no bloquea ni se ve afectado.

**Razón**: es exactamente el comportamiento que pide FR-001 ("sin requerir que se
cobren los demás pedidos pendientes") — y no exige tocar `_assert_closable`, solo
pasarle la lista correcta.

### D4 — Validación de los `order_ids` solicitados
**Decisión**: al recibir `order_ids`, `_billable_orders` (o una nueva función que la
envuelva) filtra `_billable_orders(session)` por esos ids y, si algún id solicitado no
aparece en el resultado (porque no existe, no pertenece a esa sesión, ya está
`PAID`, está `cancelada`, o ya tiene una `Sale`), responde `409 Conflict` listando los
ids rechazados — mismo patrón de error que ya usa `release_paid_session` (lista de
pedidos problemáticos en el detail).

**Razón**: evita cobrar dos veces el mismo pedido o cobrar un pedido de otra mesa por
error de payload; es consistente con cómo el código ya reporta estos conflictos.

### D5 — Previsualización del monto a cobrar (FR-003) para una selección parcial
**Decisión**: `GET /table-sessions/{id}/bill` (`compute_bill`) acepta un query param
opcional `order_ids` (misma semántica y mismas reglas de validación que D4) para que
el panel de cobro pueda mostrar el total exacto de los pedidos seleccionados antes de
confirmar, sin inventar un endpoint de preview nuevo.

### D6 — `billing_mode` y `split` no cambian
**Decisión**: `_close_unified` y `_close_split` no requieren cambios: ya reciben
`orders` como parámetro genérico. Cobrar un pedido individual usa
`billing_mode='unified'` con un solo pago por el total de ese pedido (caso normal);
`billing_mode='split'` sigue existiendo para repartir por comensal dentro de los
pedidos seleccionados, sin relación directa con esta feature.

### D7 — Frontend: selección en la Terminal de Mesas
**Decisión**: en el panel de cobro de sesión (`session-bill-panel.component.ts`), se
agrega selección múltiple sobre las pestañas "Pedido N" (todas preseleccionadas por
defecto, replicando el comportamiento actual de "cobrar todo"). El cajero puede
deseleccionar los pedidos que no quiere cobrar en esa transacción. El total mostrado
y el botón "Cobrar" usan esa selección (vía D5/D1). No se modifica el flujo de cobro
de pedidos de mostrador (sin mesa), que no pasa por este panel.

### D8 — No hay cambios de modelo de datos ni migración
**Decisión**: no se requiere ningún campo nuevo ni migración. `payment_status` por
pedido ya existe (spec 147) y ya es la fuente de verdad que usan `_billable_orders`,
`open_orders` y `has_pending_balance`. Esta feature es un cambio de API (parámetro de
selección) + UI (selección de pestañas), no de esquema. Principio VIII (evolución del
modelo de datos) no aplica.

## Resumen de impacto
- Backend: extender `CloseSessionIn` (o esquema específico de `/charge`) con
  `order_ids` opcional; extender `_billable_orders`/`compute_bill`/`charge_session`
  para filtrar y validar por esos ids; sin cambios en `_assert_closable`,
  `_close_unified`, `_close_split`, `close_session`, `release_paid_session`,
  `POST /orders/{id}/cancel`.
- Frontend: selección múltiple de pedidos en el panel de cobro de sesión; el
  servicio de sesión de mesa (`table-session.service.ts`) pasa `order_ids` a
  `charge()` y a la consulta de `bill()`.
- Sin migraciones. Sin nuevas dependencias.
