# Research: Envío a Cocina de Pedidos Para Llevar y Domicilio

## Contexto explorado

Exploración del código actual en `../pos-backend` (ver resumen con file:line en el historial de
la sesión que generó este plan):

- `app/models/customer_order.py`: `order_type` (DINE_IN/TAKEAWAY/DELIVERY), `payment_status`
  (UNPAID/PAID), `kitchen_status` (NULL/SIN_PREPARAR/EN_PROGRESO/LISTO), `sent_to_kitchen_at`,
  `dining_table_id` (no nulo únicamente para DINE_IN).
- `app/api/v1/orders/kitchen.py::_apply_kitchen_send`: transición compartida
  `kitchen_status: NULL → SIN_PREPARAR`, guardas `status != 'cancelada'`, `kitchen_status IS
  NULL`, `payment_status == 'PAID'`. Usada por el envío manual (`send_to_kitchen`) y por el
  auto-envío de `_charge_session`.
- `app/api/v1/table_sessions/service.py::_charge_session`: tras cobrar la sesión de mesa, si el
  módulo de Cocina está activo, llama a `_apply_kitchen_send` **solo si
  `order.dining_table_id is not None`** — el auto-envío está hoy restringido a DINE_IN.
- `app/models/plan.py::Plan.modalidad_pago_qr`: `NOT NULL DEFAULT 'PAY_AFTER_RECEIVING'`, con
  `CheckConstraint` a los dos valores válidos. Ya resuelve FR-008 a nivel de esquema: no existe
  estado "sin modalidad configurada", siempre hay un valor, y el default es exactamente el que
  pide FR-008.
- `app/api/v1/plan/service.py::get_qr_payment_instruction_mode`: único lector actual del campo,
  usado hoy solo por `cart/router.py` para el mensaje del menú QR.
- `app/core/plan_limits.py::has_module_access`/`require_module_access`: chequeo existente del
  módulo de Cocina (spec 149), reutilizado sin cambios.
- `app/api/v1/orders/checkout.py::pay_order`: cobro genérico por pedido (`POST
  /orders/{id}/pay`), fija `order.payment_status = "PAID"` tras `build_sale`; hoy no llama a
  `_apply_kitchen_send` — es el punto de inserción natural para el auto-envío en modalidad
  `PAY_BEFORE_RECEIVING`.
- Characterization tests (`test_orders_kitchen.py`) confirman que `send_to_kitchen`/
  `_apply_kitchen_send` **no filtran por `order_type`** — la única razón por la que
  TAKEAWAY/DELIVERY quedan bloqueados hoy es la exigencia universal de `payment_status ==
  'PAID'` combinada con la ausencia de un auto-envío equivalente al de `_charge_session`.

## Decisiones

### Decisión 1: Dónde vive la lógica de "¿requiere pago antes de cocina?"

**Decisión**: Centralizar la regla en una función nueva (p. ej.
`kitchen_requires_prior_payment(db, tenant, order) -> bool`) dentro de `orders/kitchen.py`,
reutilizada tanto por `_apply_kitchen_send`/`send_to_kitchen` como por el nuevo gancho en
`pay_order`. Regla:
- `order.dining_table_id is not None` (DINE_IN) → `True` siempre (sin cambios, spec 153 intacto).
- en caso contrario (TAKEAWAY/DELIVERY) → `True` únicamente si
  `get_qr_payment_instruction_mode(db, tenant) == "PAY_BEFORE_RECEIVING"`; `False` si es
  `PAY_AFTER_RECEIVING`.

**Rationale**: Evita duplicar la lectura de la modalidad del plan en dos sitios distintos
(`_apply_kitchen_send` y `pay_order`) y mantiene una sola fuente de verdad para "qué exige cada
combinación order_type × módulo Cocina × modalidad", como pide FR-001.

**Alternatives considered**: Repetir el chequeo inline en cada función — rechazado por duplicar
la regla de negocio en dos lugares que podrían desincronizarse si la modalidad cambia de
semántica en el futuro.

### Decisión 2: Cómo relajar `_apply_kitchen_send` sin romper DINE_IN

**Decisión**: Cambiar la guarda de `_apply_kitchen_send` de
`order.payment_status != "PAID"` a `kitchen_requires_prior_payment(db, tenant, order) and
order.payment_status != "PAID"`. `send_to_kitchen` pasa a necesitar `tenant` (ya lo recibe vía
`tenant_id`; se ajusta su firma para recibir/resolver el `Tenant` necesario para leer el plan).

**Rationale**: Mantiene exactamente el comportamiento de DINE_IN (donde la función siempre
devuelve `True` para el chequeo, igual que hoy) y solo abre la excepción para la combinación
explícita de FR-003.

**Alternatives considered**: Crear una función `_apply_kitchen_send` separada para
TAKEAWAY/DELIVERY — rechazado por Principio V/VI (evitar duplicar una transición de estado que
ya es idempotente y compartida; divergería con el tiempo).

### Decisión 3: Dónde se dispara el auto-envío para `PAY_BEFORE_RECEIVING`

**Decisión**: Dentro de `pay_order`, inmediatamente después de `order.payment_status = "PAID"`
y antes del `db.commit()`, si `tenant is not None and has_module_access(db, tenant, "cocina")
and order.dining_table_id is None and not kitchen_requires_prior_payment(...)` es **falso**
(es decir, la modalidad es `PAY_BEFORE_RECEIVING`, que es cuando se exige pago primero) →
llamar `_apply_kitchen_send(order, tenant)` dentro de la misma transacción, igual al patrón de
`_charge_session`. Tras el commit, emitir `events.order_sent_to_kitchen` si la transición
ocurrió (mismo patrón post-commit que usa `send_to_kitchen`).

**Rationale**: Reproduce exactamente el patrón ya construido y probado para mesas en spec 153
(cobrar + enviar en un solo paso, misma transacción, mismo evento), sin introducir un mecanismo
nuevo.

**Alternatives considered**: Disparar el envío desde un listener de eventos tras
`payment_status = PAID` — rechazado: `_charge_session` no usa ese mecanismo y añadiría una
asincronía/complejidad no pedida por el spec (Principio V, VI).

### Decisión 4: `checkout_and_send` (ruta legacy de `hold_for_payment`)

**Decisión**: Fuera de alcance de este plan. `checkout_and_send` no toca `kitchen_status` hoy
(usa un concepto distinto, `_deduct_and_open`, previo a spec 150) y el spec no menciona esa
ruta. Si en implementación se detecta que algún flujo de UI activo todavía depende de
`checkout_and_send` para pedidos TAKEAWAY/DELIVERY con módulo de Cocina activo, se reporta como
hallazgo al usuario antes de tocarla — no se asume su inclusión silenciosamente.

**Rationale**: Principio V (sin refactorizaciones/extensiones no pedidas) y Principio VI (una
sola clase de cambio por incremento); el spec.md no la menciona y los FR se centran en
`payment_status`/`kitchen_status`, que `checkout_and_send` no gestiona en su forma actual.

### Decisión 5: Frontend (`pos-heladeria`)

**Decisión**: El único cambio de frontend requerido por FR-002 es ocultar el botón manual
"Enviar a cocina" para pedidos TAKEAWAY/DELIVERY cuando el tenant está en modalidad
`PAY_BEFORE_RECEIVING` y el módulo de Cocina está activo. Hoy `qr_payment_instruction_mode` solo
se computa en `cart/router.py` (contexto QR_MENU: `submit_cart`, `my_orders`); el endpoint de
staff que alimenta la pantalla de mostrador (`orders/router.py::_load_order` y sus listados) no
lo rellena. Se extiende ese mismo cómputo (`plan_service.get_qr_payment_instruction_mode`) a la
respuesta de los endpoints de staff usados por la pantalla de mostrador/domicilio, reutilizando
el campo existente en `OrderResponse` — sin crear un campo nuevo ni duplicar el nombre. El
frontend deriva la visibilidad del botón con: `order_type ∈ {TAKEAWAY, DELIVERY} AND módulo
Cocina activo AND qr_payment_instruction_mode == 'PAY_BEFORE_RECEIVING'` → oculto;
en cualquier otro caso (incluida `PAY_AFTER_RECEIVING` sin pagar) → visible.

**Rationale**: Minimiza el cambio de contrato HTTP reutilizando un campo y un cómputo que ya
existen (spec 154), evitando un campo paralelo con el mismo significado (`can_manual_send_to_kitchen`
sería redundante con `qr_payment_instruction_mode` + `order_type` + estado del módulo, todos ya
disponibles en la respuesta).

**Alternatives considered**: Añadir un campo booleano explícito `can_manual_send_to_kitchen` en
`OrderResponse` — rechazado por Principio V: sería lógica de presentación duplicada en el
backend cuando el frontend ya puede derivarla de datos que la respuesta ya expone (o expondrá).

## Unknowns resueltos

Ninguna de las dimensiones de Technical Context quedó marcada `NEEDS CLARIFICATION`: lenguaje,
dependencias, storage, testing, plataforma y alcance ya están fijados por el proyecto existente
y por las clarificaciones ya resueltas en `spec.md`.
