# Fase 0 — Investigación: Envío de pedido confirmado y pagado a cocina

## Decisión 0 — Qué significa "orden confirmada" contra el modelo real (decisión de negocio, confirmada por el usuario en esta sesión de planificación)

**Hallazgo**: `spec.md` usa "orden confirmada" sin definir a qué valor de `CustomerOrder.status`
corresponde. El modelo real (`pos-backend/app/models/customer_order.py`, tras spec 147 + la
reintroducción posterior de `confirmado`) tiene **cuatro** valores: `pendiente → confirmado →
entregada`, con `cancelada` como terminal desde cualquiera de los tres no terminales. `confirmado`
es un paso puramente informativo ("el cajero recibió el pedido", `POST /orders/{id}/receive`),
independiente de `payment_status` y del descuento de inventario (que ocurre en
`checkout.confirm_order`, una acción distinta que ya no mueve `status`). Es decir: un pedido puede
tener `payment_status == 'PAID'` mientras su `status` sigue siendo `'pendiente'` (nunca pasó por
"Recibir"), y el spec no aclaraba si ese pedido debía mostrar el botón.

**Decisión** (confirmada explícitamente por el usuario vía pregunta directa en esta sesión):
"orden confirmada" en FR-001/FR-002/FR-006/FR-010/SC-001/SC-002 se traduce como
**`status != 'cancelada'`** — es decir, cualquier pedido vivo (`pendiente`, `confirmado` o
`entregada`) es candidato, y solo `cancelada` lo excluye.

**Por qué**: es la única lectura consistente con el propio FR-010 del spec, que da `cancelada`
como *el* contraejemplo de "no confirmada" ("por ejemplo, cancelada"), sin mencionar `pendiente`
como caso a excluir. Exigir además `status == 'confirmado'` haría que un pedido ya pagado
(`payment_status == 'PAID'`) pero que el cajero nunca "recibió" formalmente no pudiera enviarse a
cocina — un acoplamiento a un paso informativo que ninguna historia de usuario ni criterio de
aceptación de `spec.md` pide, y que contradice el caso de uso central (cajero cobra y despacha,
sin necesariamente haber presionado "Recibir" antes). Tampoco se excluye `entregada`: el spec no
define ninguna regla de precedencia entre "Enviar a cocina" y "Entregar", y excluirla
introduciría una restricción no pedida.

**Impacto**: el chequeo de elegibilidad en `kitchen.send_to_kitchen` (nueva función) y la condición
de visibilidad del botón en el frontend usan `order.status != 'cancelada'`, nunca
`order.status == 'confirmado'`.

## Decisión 1 — `kitchen_status`/`sent_to_kitchen_at` no existen: requieren migración nueva sobre `CustomerOrder`

**Hallazgo**: ninguna columna `kitchen_status` ni `sent_to_kitchen_at` existe hoy en
`pos-backend` (confirmado por búsqueda exhaustiva). Existe `OrderItem.estado_cocina`
(`pendiente | entregado | cancelado`), pero es un campo **por ítem**, ya consumido íntegramente
por el flujo de entrega de spec 147 (`kitchen.deliver_order`) — no es el campo que esta spec
necesita, que es a nivel de **pedido completo** y representa un concepto distinto ("¿ya se envió
a la cola de preparación de cocina?"), sin relación con "¿ya se entregó al cliente?".

**Decisión**: agregar dos columnas nuevas a `tenant.customer_orders` (esquema `tenant`,
migración con `@for_each_tenant_schema`, mismo patrón que
`c5d6e7f8a9b0_simplify_kitchen_status.py`):

- `kitchen_status: Mapped[Optional[str]]`, sin `server_default` (nace `NULL`).
- `sent_to_kitchen_at: Mapped[Optional[datetime]]`, sin `server_default` (nace `NULL`).

**Alternativa descartada**: reutilizar/extender `OrderItem.estado_cocina` con un nuevo valor para
representar "enviado a cocina" a nivel de pedido. Se descarta porque mezclaría dos conceptos ya
protegidos por characterization tests de spec 147 (el ciclo de entrega por ítem) con uno nuevo
(el envío a la cola de preparación), violando el Principio VI (no mezclar clases de cambio) y
arriesgando romper los tests `"CONGELA comportamiento actual:"` de `test_orders_kitchen.py` sin
necesidad.

## Decisión 2 — Sin `CheckConstraint` sobre `kitchen_status`

**Hallazgo**: la clarificación de `spec.md` (pregunta 4) es explícita: "Solo dos valores
relevantes aquí (nulo y 'SIN_PREPARAR'); cualquier valor no nulo se trata igual (ya enviado), sin
asumir estados adicionales." Esto es una instrucción deliberada de **no cerrar** el conjunto de
valores válidos, a diferencia de `status`/`payment_status`/`estado_cocina`, que sí tienen
`CheckConstraint` con un conjunto cerrado.

**Decisión**: `kitchen_status` se modela como `String` nullable **sin** `CheckConstraint`. Toda
lógica de negocio de esta spec lee únicamente `kitchen_status IS NULL` (no enviado) vs
`kitchen_status IS NOT NULL` (ya enviado, cualquiera sea el valor) — nunca compara contra el
literal `"SIN_PREPARAR"` como si fuera el único valor no nulo posible. Esto deja espacio para que
una spec futura (tablero de cocina) agregue `PREPARANDO`/`LISTO` sin requerir otra migración de
constraint ni romper esta spec.

## Decisión 3 — Mecanismo de error con código estable: reutilizar `DomainError`/`ConflictError`, no `HTTPException` plano

**Hallazgo**: la mayoría de los 409 existentes en `orders/` son `HTTPException(409, "texto
plano")`, sin código de máquina. Pero ya existe un mecanismo genérico pensado exactamente para
esto: `app/core/domain_errors.py::DomainError` (y su subclase `ConflictError`, `default_status_code
= 409`), traducido a un envelope JSON estable por `app/core/error_response.py::build_envelope`
(`{"success": false, "error": {"code", "message", "details"}, "request_id", "detail"}`) y
registrado **globalmente** (no solo bajo `/api/v1/super-admin`) por el
`@app.exception_handler(DomainError)` dentro de `register_error_handlers` en
`app/core/error_middleware.py` — Starlette despacha por tipo de excepción, no por prefijo de
ruta, así que cualquier router (incluido `orders`) que levante un `DomainError` ya recibe esta
traducción sin registrar nada nuevo.

**Decisión**: 
- FR-006 (pago no `PAID`) → `raise ConflictError("El pedido no está pagado.", code="ORDER_NOT_PAID")`.
- FR-007/FR-008 (`kitchen_status` ya no nulo, incluida la carrera concurrente) →
  `raise ConflictError("El pedido ya está en la cola de cocina.", code="ALREADY_IN_KITCHEN")`.
- FR-010 (orden no confirmada, ej. cancelada) →
  `raise ConflictError("El pedido no está en un estado válido para enviarse a cocina.", code="ORDER_NOT_CONFIRMED")`
  (código no exigido literalmente por `spec.md`, que solo pide rechazar — se documenta aquí por
  trazabilidad, mismo patrón que los otros dos).
- FR-011 (rol) → sigue el patrón existente de rol (`HTTPException` 403 plano vía
  `require_tenant_admin_or_cashier`, ver Decisión 5) — no es un `DomainError`, porque el spec no
  exige un código de máquina para este caso y el patrón de rol existente ya es `HTTPException`
  plano en todo el código base.

**Alternativa descartada**: una clase de excepción dedicada por código al estilo
`ModuleNotInPlanError` (con su propio `@app.exception_handler` registrado a mano). Se descarta
porque `DomainError`/`ConflictError` ya resuelve el mismo problema de forma genérica y reutilizable
— crear una clase nueva por código sería la dependencia/abstracción no pedida que el Principio V
desalienta.

**Impacto en frontend**: `DiningSessionService.extractError` (lee `err.error.detail` como
string) sigue funcionando sin cambios para mostrar el mensaje en los dos códigos que sí generan
toast. Para el comportamiento silencioso de `ALREADY_IN_KITCHEN` (clarificación 2 de `spec.md`),
la nueva lógica de la store debe inspeccionar `err.error?.error?.code === 'ALREADY_IN_KITCHEN'`
*antes* de llamar a `extractError`/`toast.error`, y en ese caso solo refrescar
(`await this.reload()`) sin mostrar ningún mensaje.

## Decisión 4 — Gating del módulo "cocina": reutilizar `require_module_access("cocina")`, ya disponible desde spec 149

**Hallazgo**: spec 149 ya agregó `"cocina"` a `PLAN_MODULES` (`app/core/plan_limits.py`) y la
columna `shared.plans.cocina_access`, pero **sin ningún punto de enforcement** — documentó
explícitamente que esa parte quedaba para una spec futura que reviviera el flujo de cocina. Esta
spec (150) es esa spec futura: es el primer punto real de enforcement de `cocina_access`.

**Decisión**: el nuevo endpoint de envío a cocina se protege con
`Depends(require_module_access("cocina"))` (gating a nivel de ruta, mismo patrón que
`promotions/router.py`/`unit_measures/router.py`) — sin necesidad de ninguna dependencia ni
columna nueva, y sin modificar `plan_limits.py` más allá de que ya acepta `"cocina"` como clave
válida desde spec 149. El 403 resultante (`ModuleNotInPlanError`, código `MODULE_NOT_IN_PLAN`) ya
tiene su propio handler registrado (`register_module_error_handler`), sin relación con la
Decisión 3 de este documento.

**Frontend**: el botón usa el guard ya existente `planModuleGuard`/`ModuleAccess.cocina`
(`plan-summary.service.ts`) — leído como una condición más de visibilidad del botón (junto con
`status`, `payment_status` y `kitchen_status`), no como un guard de ruta completa (el botón vive
dentro de un panel ya accesible, no detrás de una ruta separada).

## Decisión 5 — Restricción de rol: reutilizar `require_tenant_admin_or_cashier`

**Hallazgo**: `app/core/dependencies.py::require_tenant_admin_or_cashier` ya exige exactamente
`ADMIN` o `CASHIER` (nombres en inglés de los roles `admin`/`cajero` del dominio) y ya devuelve
403 plano ante cualquier otro rol — mismo requisito que FR-011.

**Decisión**: el nuevo endpoint usa
`user: User = Depends(require_tenant_admin_or_cashier)` en vez de `Depends(get_current_user)`
(que es lo que usan hoy `/receive` y `/deliver`, sin restricción de rol). Ningún otro endpoint se
modifica — este endpoint nuevo es el único que necesita esta restricción según FR-011.

**Alternativa descartada**: crear una dependencia nueva específica para "cajero o admin envían a
cocina". Se descarta porque `require_tenant_admin_or_cashier` ya expresa exactamente esa regla,
reutilizada sin modificación.

## Decisión 6 — Patrón del endpoint y del servicio: mismo molde que `receive_order`/`deliver_order`

**Hallazgo**: `app/api/v1/orders/kitchen.py` ya tiene el molde exacto para una acción única sobre
un pedido, idempotente, con `SELECT ... FOR UPDATE` para la carrera concurrente (FR-008/SC-003) y
emisión de evento post-commit vía `app/core/events.py` (mismo patrón pub/sub Redis que
`order_received`/`order_delivered`, consumido por otras terminales que miran el mismo pedido/mesa).

**Decisión**: 
- Nueva función `kitchen.send_to_kitchen(db, order_id, tenant_id) -> CustomerOrder` en
  `app/api/v1/orders/kitchen.py`, con el mismo `SELECT ... FOR UPDATE` que `receive_order`.
- Nuevo endpoint `POST /orders/{order_id}/send-to-kitchen` en `app/api/v1/orders/router.py`,
  justo después de `/deliver`, mismo molde (`_load_order` al final).
- Nuevo evento `events.order_sent_to_kitchen(tenant_id, *, order_id, table_session_id)`, mismo
  molde que `order_delivered` (payload `{"order_id", "table_session_id", "kitchen_status":
  "SIN_PREPARAR"}`), para que otras terminales que miren la misma mesa/sesión oculten el botón sin
  esperar su propio refresco periódico.
- La hora se toma del servidor con `app.core.timezone.utc_now_naive()` (mismo helper ya usado en
  `plan_limits.py` para otros timestamps de servidor), nunca de un valor enviado por el cliente —
  satisface FR-004/SC-004 sin introducir ninguna dependencia nueva.

**Orden de validaciones dentro de `send_to_kitchen`** (determinístico, para que los tests de
característica puedan fijar exactamente qué código devuelve cada combinación de estado inválido):
1. `order is None` → 404.
2. `order.status == 'cancelada'` (Decisión 0) → 409 `ORDER_NOT_CONFIRMED`.
3. `order.kitchen_status is not None` → 409 `ALREADY_IN_KITCHEN` (cubre FR-007 y, bajo el lock de
   fila, también la carrera concurrente de FR-008/SC-003: la segunda transacción ve el valor ya
   escrito por la primera tan pronto como obtiene el lock).
4. `order.payment_status != 'PAID'` → 409 `ORDER_NOT_PAID`.
5. Éxito: `kitchen_status = 'SIN_PREPARAR'`, `sent_to_kitchen_at = utc_now_naive()`, commit, evento.

## Decisión 7 — Origen de la orden (manual/mesa/domicilio): ningún campo nuevo, ninguna lógica condicionada por canal

**Hallazgo**: los tres orígenes son combinaciones de `channel`
(`POS | QR_MENU | WHATSAPP | API`) y `order_type` (`DINE_IN | TAKEAWAY | DELIVERY`) sobre la
misma tabla `customer_orders` — no hay tres modelos ni tres rutas distintas.

**Decisión**: `send_to_kitchen` no lee `channel` ni `order_type` en absoluto (FR-002: la condición
de visibilidad/aceptación es idéntica sin importar el origen) — la elegibilidad depende
exclusivamente de `status`/`payment_status`/`kitchen_status`. Esto cumple FR-002 "gratis": al no
ramificar por canal, el comportamiento ya es uniforme por construcción, sin necesitar un test por
canal más allá de uno que confirme que ninguno de los tres queda excluido por accidente.

## Decisión 8 — Cola de preparación: sin columna de posición, consulta ordenada bajo demanda

**Hallazgo**: la clarificación 1 de `spec.md` ya resuelve esto explícitamente: la posición se
calcula dinámicamente ordenando por `sent_to_kitchen_at`, sin columna propia.

**Decisión**: no se persiste ninguna "posición". Se agrega un índice parcial
`idx_customer_orders_kitchen_queue` sobre `(sent_to_kitchen_at)` con
`postgresql_where=text("kitchen_status IS NOT NULL")` — mismo patrón de índice parcial ya usado en
`idx_active_order_per_participant` (`customer_order.py`) — para que un futuro `ORDER BY
sent_to_kitchen_at` sobre "pedidos en cocina" no dependa de un *table scan*. No es un requisito
funcional del spec (que no define ningún endpoint de lectura de la cola — "Assumptions" lo deja
fuera de alcance explícitamente), pero es consistente con SC-003 y de costo mínimo (un índice, sin
lógica nueva). Si se prefiere no anticiparlo, se puede omitir sin romper ningún FR — se documenta
aquí como decisión técnica, no como requisito.

## Decisión 9 — Testing: characterization tests nuevos en `test_orders_kitchen.py`, sin Postgres

**Hallazgo**: la suite de `app/characterization_tests/` corre con `unittest` sobre SQLite en
memoria, no sobre Postgres — ya cubre `receive_order`/`deliver_order`/`void_item` en
`test_orders_kitchen.py` reutilizando `orders_fixtures.make_customer_order`/`make_order_item`.

**Decisión**: los tests de `send_to_kitchen` (uno por escenario de aceptación de las 3 historias +
edge cases) se agregan a `test_orders_kitchen.py`, reutilizando esas mismas fixtures — sin crear
un archivo nuevo ni una fixture nueva, salvo que `make_customer_order` necesite aceptar
`kitchen_status`/`payment_status`/`status` como parámetros opcionales (si no los acepta ya, se
extiende su firma, no se duplica la fixture).

## Decisión 10 — Frontend: botón y store nuevos en `pos-order-panel`/`PosTerminalStore`, mismo molde que "Entregar"

**Hallazgo**: existe un único componente/store que renderiza el panel de pedido para los tres
orígenes (`pos-order-panel.component.ts` + `PosTerminalStore`), con un patrón ya establecido de
botón condicional + método async en la store (`deliverOrder`) que llama al servicio HTTP, espera,
y refresca (`await this.reload()`), reportando errores vía `toast.error(extractError(err, ...))`.

**Decisión**:
- `DiningSessionService.sendToKitchen(orderId)` — `POST /orders/{id}/send-to-kitchen`, mismo
  molde que `deliverOrder`.
- `PosTerminalStore.sendToKitchen(orderId?)` — mismo molde que `deliverOrder`, con la excepción de
  la Decisión 3: si el error tiene `code === 'ALREADY_IN_KITCHEN'`, se hace `await this.reload()`
  sin `toast.error` (comportamiento silencioso, clarificación 2 de `spec.md`); cualquier otro
  error sí muestra el toast con `extractError`.
- Botón nuevo en `pos-order-panel.component.ts`, condición de visibilidad:
  `order.status !== 'cancelada' && order.payment_status === 'PAID' && !order.kitchen_status &&
  planSummary.modules.cocina` (la última condición vía el guard/servicio ya existente,
  `plan-summary.service.ts`), como helper puro en `order-status.util.ts` (mismo patrón que
  `hasPendingKitchenWork`/`puedeCancelarComensal`), no como lógica inline en el template.
- No se toca `order-detail.component.ts` (vista histórica/solo lectura) — el botón de acción vive
  únicamente en el panel en vivo, igual que "Recibir"/"Entregar".

## Decisión 11 — `DiningOrder` (interfaz TS) y `OrderResponse` (esquema Pydantic) ganan los dos campos nuevos

**Decisión**: `kitchen_status: string | null` y `sent_to_kitchen_at: string | null` (ISO 8601) se
agregan a `OrderResponse` (`app/api/v1/orders/schemas.py`) y a la interfaz `DiningOrder` del
frontend — mismo patrón mecánico que cualquier campo ya expuesto de `CustomerOrder`, sin
estructuras anidadas nuevas.
