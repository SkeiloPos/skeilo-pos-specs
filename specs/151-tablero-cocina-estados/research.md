# Research: Tablero de cocina en tres columnas con movimiento de pedidos

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

## Decisión 0 (negocio): FR-015 reutiliza la infraestructura SSE ya existente

**Decisión**: El tablero NO abre una conexión WebSocket/SSE nueva. Reutiliza íntegramente
la infraestructura de tiempo real ya existente de spec 077 (`app/core/events.py` +
`app/api/v1/realtime/router.py`, canal `CH_STAFF`), con un evento nuevo
`order.kitchen_status_changed` publicado en ese mismo canal.

**Por qué la spec se equivoca en su Assumption**: `spec.md` (sección Assumptions) afirma que
"no hay un mecanismo de tiempo real en el sistema hoy" y que FR-015 es "una conexión nueva...
porque no hay una existente". Eso es falso contra el código real: spec 077 ya implementó un
stream SSE multi-tenant por `CH_STAFF` (canal del staff: todo `ADMIN`/`CASHIER` conectado al
tenant), con reconexión, replay por `Last-Event-ID` y eventos ya publicados para
`order.created`, `order.confirmed`, `order.item_kitchen_changed`, etc. `ADMIN` y `CASHIER` ya
consumen ese canal hoy desde la Terminal de Mesas (`pos-terminal.store.ts`,
`core/realtime/realtime.service.ts`).

**Confirmado explícitamente por el usuario en esta sesión de planificación** (mismo patrón que
spec 150 Decisión 0: una ambigüedad de la spec contra el modelo real se resuelve con una
decisión de negocio explícita, no asumida unilateralmente).

**Alternativa descartada**: construir un segundo stream/WebSocket exclusivo para el tablero de
cocina, tal como la spec literalmente describe. Se descarta porque duplicaría infraestructura
ya probada en producción (reconexión, backoff, replay, aislamiento por tenant) sin ningún
beneficio — el canal `CH_STAFF` ya es exactamente "todo el personal del tenant conectado", que
es lo que FR-015 necesita.

**Consecuencia de diseño**: el rol `KITCHEN` nuevo (Decisión 1) debe poder autenticarse como
cualquier otro usuario de staff y usar `POST /realtime/ticket` + `GET /realtime/stream` sin
cambios — ambos endpoints ya usan `Depends(get_current_user)` sin restricción de rol, así que
un usuario `KITCHEN` los consume gratis en cuanto exista como rol válido.

## Decisión 1 (negocio): `KITCHEN` es un rol nuevo de primera clase, igual que `MESERO`

**Decisión**: `KITCHEN` se agrega al catálogo `shared.roles` y al enum de roles asignables por
el admin de tenant, con el mismo patrón que `MESERO` (spec 075): migración de datos que siembra
la fila, enum backend (`RoleName`) y enum frontend (`UserRole`) actualizados, dependencia de
autorización nueva en `app/core/dependencies.py`, guard de ruta y navegación en
`pos-heladeria`.

**Evidencia del patrón a replicar** (spec 075, commit `3d56388`):
- `app/core/db.py::ROLE_NAMES` — tupla de nombres sembrados en una DB nueva.
- `alembic/versions/8421e9a2b45a_seed_mesero_role.py` — migración de datos idempotente por
  `name` para tenants/instalaciones que ya pasaron el seed inicial; `downgrade()` solo borra la
  fila si ningún `User`/`UserInvitation` la referencia.
- `app/api/v1/users/schemas.py::RoleName` — enum de roles asignables por un admin de tenant.
- `app/core/dependencies.py` — nueva función `require_*` análoga a
  `require_tenant_admin_or_cashier`.
- `pos-heladeria/src/app/core/interfaces/user.interface.ts::UserRole` — enum paralelo.
- `pos-heladeria/src/app/core/guards/role.guard.ts::ROLE_DEFAULT_ROUTES` — ruta de aterrizaje
  por rol.
- `pos-heladeria/src/app/core/config/navigation.config.ts` — entradas de menú filtradas por rol.

**Alternativa descartada**: reutilizar `CASHIER` con una bandera adicional ("cajero de
cocina"). Se descarta porque FR-014 exige una frontera de autorización binaria y exclusiva
(solo `KITCHEN` mueve tarjetas; `ADMIN`/`CASHIER` solo ven) que un rol nuevo expresa
directamente vía `user.role.name`, sin introducir un segundo eje de permisos.

## Decisión 2 (técnica): dos niveles de autorización — ver vs. mover

**Decisión**: dos dependencias nuevas en `app/core/dependencies.py`:
- `require_kitchen_board_view` — acepta `ADMIN`, `CASHIER`, `KITCHEN` (FR-014, ver tablero).
- `require_kitchen_role` — acepta únicamente `KITCHEN` (FR-014, mover tarjetas).

Mismo molde que `require_tenant_admin_or_cashier`/`require_tenant_admin` (chequeo de
`user.role.name in {...}`, 403 si no matchea). El endpoint de lectura del tablero usa la
primera; el endpoint de transición de `kitchen_status` usa la segunda.

**Alternativa descartada**: una sola dependencia con un parámetro de modo (`mode="view"` /
`mode="move"`). Se descarta por ser indirección innecesaria para dos chequeos de rol
simples y estáticos — tres roles fijos en una constante no justifica un parámetro.

## Decisión 3 (técnica): el endpoint de transición reutiliza `CustomerOrder.version` para `KITCHEN_STATUS_CONFLICT`

**Decisión**: `CustomerOrder` ya tiene una columna `version` (`Integer`, `server_default="0"`,
ya usada como mecanismo de concurrencia optimista en otras rutas del pedido). El endpoint de
movimiento de tarjeta (`POST /orders/{id}/kitchen-status`) recibe el `version` que el cliente
tenía al momento de iniciar el arrastre; el servicio hace `SELECT ... FOR UPDATE` (mismo molde
que `send_to_kitchen`/`receive_order`/`deliver_order`), compara `order.version` contra el
recibido, y si no coincide lanza `ConflictError("...", code="KITCHEN_STATUS_CONFLICT")` con el
`kitchen_status` vigente en el payload de error — sin incrementar `version` él mismo en esta
spec (ninguna otra ruta del pedido lo hace tampoco al escribir `kitchen_status`; ver Decisión 9
sobre si incrementarlo).

**Por qué no un campo de "lock" nuevo**: el `SELECT ... FOR UPDATE` + comparación de `version`
ya es el patrón establecido en este código para "la primera transacción que llega gana, la
segunda ve el estado ya cambiado" (ver `send_to_kitchen`, docstring: "la segunda transacción ve
`kitchen_status` ya escrito por la primera tan pronto como adquiere el lock"). FR-008 pide
exactamente ese comportamiento, no un nuevo primitivo de bloqueo.

**Decisión 3b**: el movimiento de tarjeta **sí incrementa** `order.version` en cada transición
exitosa. Es la única forma de que el `version` que el cliente reenvía tras un movimiento previo
detecte un segundo movimiento concurrente sobre el mismo pedido — si `version` no cambiara
nunca, dos tarjetas movidas "a la vez" con el mismo `version` inicial nunca generarían el 409
que FR-008 exige salvo que ambas lleguen literalmente dentro de la ventana del lock (improbable
de testear de forma determinística). Incrementar `version` en cada escritura de
`kitchen_status` es además consistente con el propósito general de la columna (concurrencia
optimista), no un uso nuevo.

## Decisión 4 (técnica): el endpoint de transición es nuevo, no una extensión de `/send-to-kitchen`

**Decisión**: `POST /orders/{order_id}/kitchen-status`, body `{ "kitchen_status": "EN_PROGRESO",
"version": 3 }`. Nuevo, no se reutiliza `/send-to-kitchen` (que solo hace la transición inicial
`NULL → SIN_PREPARAR` y ya tiene sus propias reglas de FR-001/FR-003 de spec 150, distintas:
exige `kitchen_status IS NULL`, esta spec exige `kitchen_status IS NOT NULL`).

**Validaciones, en el mismo orden determinístico que `send_to_kitchen` estableció** (research.md
Decisión 6 de spec 150):
1. Pedido no existe → 404.
2. `kitchen_status` actual es `NULL` (nunca se envió a cocina) → 409 `NOT_IN_KITCHEN` (código
   nuevo; no es ninguno de los tres que `spec.md` define, porque `spec.md` no contempla este
   caso — edge case no cubierto, se documenta aquí en vez de inventar un comportamiento
   silencioso).
3. `version` recibido != `order.version` actual → 409 `KITCHEN_STATUS_CONFLICT` (FR-008), con el
   `kitchen_status` vigente en el payload (FR-009).
4. `payment_status != 'PAID'` → 409 `PAYMENT_NOT_PAID` (FR-007).
5. `order.status in ('cancelada', ...)` o módulo `"cocina"` no activo → 409 (FR-006; se
   reutiliza `require_module_access("cocina")` como dependencia del router, igual que
   `/send-to-kitchen`, en vez de chequearlo a mano en el servicio).
6. Éxito: `kitchen_status = body.kitchen_status`, `version += 1`, commit, publica
   `events.order_kitchen_status_changed` (Decisión 0).

**Validación del valor destino**: `body.kitchen_status` se restringe a
`{"SIN_PREPARAR", "EN_PROGRESO", "LISTO"}` vía Pydantic `Literal`, no vía `CheckConstraint` en
la columna (spec 150 Decisión 2 ya decidió no poner `CheckConstraint` sobre `kitchen_status`
para no migrar de nuevo si aparece un cuarto estado — esta spec no reabre esa decisión, valida
en la capa de API, no en la DB).

## Decisión 5 (técnica): el endpoint de lectura del tablero reutiliza el índice parcial de spec 150

**Decisión**: `GET /orders/kitchen-board` (nuevo), devuelve las tres columnas ya agrupadas
(`{ "sin_preparar": [...], "en_progreso": [...], "listo": [...] }`), cada lista ordenada por
`sent_to_kitchen_at ASC, id ASC` (FR-003), filtrando `kitchen_status IS NOT NULL` — exactamente
la condición que `idx_customer_orders_kitchen_queue` (spec 150, `postgresql_where=text(
"kitchen_status IS NOT NULL")`) ya cubre. Ningún índice nuevo.

**Por qué un endpoint de agregación y no tres llamadas a `GET /orders?kitchen_status=X`**: FR-001
pide las tres columnas "a la vez" para pintar el tablero completo en una sola carga; devolverlas
ya agrupadas evita que el frontend dispare tres requests secuenciales al abrir la pantalla y
evita además que el frontend reimplemente el criterio de orden (FR-003) — el backend es la
única fuente de ese orden, igual que ya pasa con cualquier otro listado paginado de `orders`.

**Alternativa descartada**: añadir un parámetro `kitchen_status` a `GET /orders` existente
(`service.py`, el que ya pagina). Se descarta porque ese endpoint pagina (`Page[OrderResponse]`,
spec 079) y el tablero no quiere paginación por columna — quiere las tres columnas completas
(volumen bajo: solo pedidos activos y no finalizados, research.md spec 150 ya documentó que el
volumen de cocina es bajo). Mezclar ambos contratos en un mismo endpoint complicaría más de lo
que ahorra.

## Decisión 6 (técnica): FR-011 (retirar tarjetas en estado final) no agrega lógica nueva de transición de `status`

**Decisión**: ninguna función nueva marca "estado final". El endpoint de lectura del tablero ya
filtra implícitamente: una orden `cancelada` o `entregada` (el único "estado final del flujo
actual" que `CustomerOrder.status` modela hoy, research.md spec 150 Decisión 0) sigue teniendo
su `kitchen_status` no nulo (nunca se limpia retroactivamente, research.md data-model.md spec
150), así que el filtro de FR-011 se agrega como condición extra en el mismo `WHERE` del
Decisión 5: `kitchen_status IS NOT NULL AND status NOT IN ('cancelada', 'entregada')`.

El evento realtime de retiro (FR-011 "sin requerir ninguna acción adicional del usuario") se
emite reutilizando los eventos ya existentes `order_delivered`/`order_cancelled`-equivalente
que `kitchen.deliver_order` y el flujo de cancelación de orden ya publican (`events.py`) — el
frontend del tablero escucha esos tipos de evento ya existentes (`order.delivered`, el que
exista para cancelación) y retira la tarjeta localmente, sin que el backend necesite un evento
nuevo para esto. Solo `order.kitchen_status_changed` (Decisión 0) es nuevo.

**Punto a verificar en Fase 1 (data-model.md)**: confirmar el nombre exacto del evento de
cancelación de orden ya existente en `app/core/events.py`, para documentarlo en el contrato en
vez de asumirlo.

## Decisión 7 (técnica): FR-004 (prohibir reordenar dentro de una columna) es una restricción de UI, no de backend

**Decisión**: el backend no necesita ningún campo de "posición manual" porque nunca existe un
estado válido de reordenamiento manual — FR-003/FR-004 definen que el único orden válido es
FIFO por `sent_to_kitchen_at`. El frontend (biblioteca de drag-and-drop) se configura para
permitir arrastrar tarjetas *entre* columnas pero bloquear el *reordenamiento* dentro de la
misma columna (la mayoría de librerías de drag-and-drop en Angular exponen esto como una opción
por lista/columna). Ningún endpoint nuevo ni campo nuevo lo expresa — es puramente
responsabilidad del cliente, reforzada porque el servidor jamás persiste ni lee una posición
manual: la posición se recalcula siempre desde `sent_to_kitchen_at` en cada respuesta.

## Decisión 8 (técnica): no se crea ninguna tabla nueva

Ninguna entidad nueva persiste. El "tablero" (Key Entity de `spec.md`) es una vista computada
sobre `CustomerOrder` ya existente, igual que `spec.md` documenta en su propia sección de Key
Entities ("Vista de las órdenes con `kitchen_status` no nulo..."). Esta spec solo agrega:
una fila en `shared.roles` (Decisión 1), ningún campo nuevo en `CustomerOrder` (reutiliza
`kitchen_status`/`sent_to_kitchen_at`/`version`, todos de spec 150 o preexistentes), y ningún
índice nuevo (Decisión 5).

## Decisión 9 (técnica): tests backend reutilizan las fixtures de spec 150

**Decisión**: `app/characterization_tests/test_orders_kitchen.py` (ya extendido por spec 150
con casos de `send_to_kitchen`) gana una sección nueva para `change_kitchen_status`, reutilizando
`orders_fixtures.make_customer_order`/`make_order_item`, sobre SQLite en memoria — mismo patrón,
mismo fichero, sin suite nueva.

## Decisión 10 (técnica): frontend — se revive la ruta `cocina`, no se crea un módulo nuevo desde cero

**Decisión**: `pos-heladeria/src/app/modules/dashboard/routes.ts` tiene hoy
`{ path: 'cocina', pathMatch: 'full', redirectTo: 'mesas-sesiones' }` con el comentario "El
tablero de cocina se deprecó". Esta spec revierte ese redirect y monta ahí el componente nuevo
del tablero (standalone, carga diferida igual que el resto de páginas de `dashboard/routes.ts`),
protegido por `roleGuard([UserRole.ADMIN, UserRole.CASHIER, UserRole.KITCHEN])` (FR-014, ver), y
el propio componente oculta el drag de columnas si `currentUser().role !== UserRole.KITCHEN`
(FR-014, mover). Se usa el directorio `modules/kitchen/` nuevo (no existe ningún código vivo de
tablero de cocina para reutilizar — el viejo quedó solo como ese redirect, spec 149 ya lo
verificó) en vez de reutilizar `modules/tables/`, porque el tablero no es una vista de mesas.

**`UserRole` (enum) y `ROLE_DEFAULT_ROUTES`**: `KITCHEN` se agrega con una ruta de aterrizaje
propia (`/dashboard/cocina`) — mismo patrón que `MESERO` → `/dashboard/mesas-sesiones`.

**`navigation.config.ts`**: la entrada de menú "Cocina" se agrega con
`roles: [UserRole.ADMIN, UserRole.CASHIER, UserRole.KITCHEN]`.
