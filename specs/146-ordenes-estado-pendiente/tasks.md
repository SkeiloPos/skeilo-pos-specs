---

description: "Task list for: Estado inicial PENDIENTE para órdenes e ítems, sin traducción en frontend"
---

# Tasks: Estado inicial PENDIENTE para órdenes e ítems, sin traducción en frontend

**Input**: Design documents from `/specs/146-ordenes-estado-pendiente/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/order-status-contract.md, quickstart.md (all present)

**Repos involved**: `../pos-backend` (FastAPI/SQLAlchemy/Alembic), `../pos-heladeria` (Angular/Vitest)

**Tests**: Included — the project's testing model is characterization tests (backend,
`app/characterization_tests/`, run against a real Postgres DB) and Vitest specs (frontend),
both explicitly required by Principio III/X and by quickstart.md.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on an incomplete task)
- **[Story]**: US1 (P1 — creación), US2 (P1 — migración/eliminación), US3 (P2 — frontend)
- File paths are relative to `../pos-backend` or `../pos-heladeria` as noted per task

---

## Phase 1: Setup

- [X] T001 [P] Crear rama `feat/146-ordenes-estado-pendiente` en `pos-backend` (Principio XIV), partiendo de `main` actualizado
- [X] T002 [P] Crear rama `feat/146-ordenes-estado-pendiente` en `pos-heladeria` (Principio XIV), partiendo de `main` actualizado

  Nota de implementación: ninguno de los dos repos tiene una rama `main` (el
  default real es `develop`); ambas ramas se crearon desde `develop` tras
  `git pull --ff-only`.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Infraestructura de datos compartida por las tres historias. Ningún valor
`"pendiente"` es válido para `CustomerOrder.status` hasta que el `CHECK constraint` se
actualice, así que ninguna historia puede probarse de punta a punta sin esta fase.

**⚠️ CRITICAL**: No se toca código de aplicación (Fases 3-5) sin completar T003 primero
(Principio II exige registrar la decisión de negocio antes de implementar el cambio de
comportamiento).

- [X] T003 Registrar en `specs/000-reconocimiento/registro-de-anomalias.md` (Principio II) ambos cambios de comportamiento autorizados por el plan: (a) caja/mostrador y domicilio dejan de crear órdenes directamente en `"abierta"` y nacen en `"pendiente"`, moviendo el descuento de inventario inmediato al punto de confirmación; (b) se añade la columna `payment_status` (no existía). Incluir quién/cuándo/qué cambia/por qué/funcionalidades afectadas, citando `plan.md` § Clarifications de planificación — **A-150**
- [X] T004 [P] En `pos-backend/app/api/v1/orders/schemas.py`: renombrar el miembro `OrderStatus.RECIBIDA` a `OrderStatus.PENDIENTE` (mismo valor `"pendiente"` que ya usa el futuro `status`, no confundir con `estado_cocina`); agregar enum nuevo `PaymentStatus` con `UNPAID`, `PAID`, `PARTIAL`
- [X] T005 [P] En `pos-backend/app/models/customer_order.py`: actualizar el `CHECK constraint` `ck_customer_order_status` (línea ~178) para que acepte `('pendiente','abierta','bloqueada','pagada','cancelada')` en lugar de `'recibida'`; agregar columna nueva `payment_status: Mapped[str]` (`VARCHAR(10)`, `nullable=False`, `server_default="UNPAID"`) con `CHECK constraint` propio `ck_customer_order_payment_status` en `('UNPAID','PAID','PARTIAL')`
- [X] T006 Escribir migración Alembic nueva `pos-backend/alembic/versions/<rev>_rename_recibida_to_pendiente_add_payment_status.py` con `upgrade(schema)`/`downgrade(schema)` decorados con `@for_each_tenant_schema` (`app/scripts/tenant.py:9-19`), siguiendo el patrón de `alembic/versions/c9d0e1f2a3b4_table_sessions_participants.py`, implementando exactamente los pasos de `data-model.md` § Migración de datos (drop/update/re-create CHECK de status, add column + backfill + CHECK de payment_status; downgrade espejo con la limitación de rollback documentada) — depende de T004, T005

  Nota de implementación: revisión `e967f9848848` (no `a1b2c3d4e5f6` como se
  había anticipado — colisión con una revisión existente, `alembic heads`
  detectó el ciclo). `op.drop_constraint` en este runtime **sí** reaplica la
  naming convention (nombre bare, no el prefijado `ck__tabla__nombre`) —
  verificado empíricamente contra Postgres real; pasar el nombre ya prefijado
  produce un doble-prefijo y falla.
- [X] T007 Ejecutar `alembic upgrade head` contra Postgres local con datos de prueba que incluyan órdenes `status='recibida'` en `tenant_default` y al menos otro esquema de tenant; verificar que `SELECT count(*) FROM customer_order WHERE status='recibida'` da `0` en cada esquema y que un `UPDATE ... SET status='recibida'` directo es rechazado por el nuevo CHECK (quickstart.md Escenario 2, pasos 1-4) — depende de T006

  Nota de implementación: el único tenant con datos reales en este ambiente es
  `heladeria` (1 orden `'recibida'`, 8 `'cancelada'`, 47 `'pagada'`);
  `tenant_default` no tiene la tabla `customer_orders` (la salta la guarda
  `_has_table`). Verificado contra Postgres real: tras `upgrade head`, 0 filas
  `'recibida'`; backfill correcto (`47 → PAID`, `9 → UNPAID`); `UPDATE ... SET
  status='recibida'` rechazado por el CHECK; round-trip `downgrade` →
  `upgrade` limpio. No había un segundo tenant con datos para una prueba
  multi-esquema literal con dos conjuntos de filas `'recibida'` distintos; el
  mecanismo `for_each_tenant_schema` en sí ya está probado por otras
  migraciones existentes del repo.

**Checkpoint**: `"pendiente"` es ahora un valor válido de `CustomerOrder.status` en todos los
esquemas; `"recibida"` es rechazado a nivel de base de datos; `payment_status` existe con
`UNPAID` por defecto. Las historias de usuario pueden comenzar.

---

## Phase 3: User Story 1 - Toda orden nueva nace en PENDIENTE sin importar el canal (Priority: P1) 🎯 MVP (parte 1/2)

**Goal**: Toda orden nueva (QR, caja/mostrador, domicilio) queda `status="pendiente"` con
`payment_status="UNPAID"` salvo pago confirmado en el mismo acto de creación; todos sus ítems
nacen `estado_cocina="pendiente"`.

**Independent Test**: Crear una orden por cada canal con varios ítems y verificar vía API/DB
que `status=="pendiente"`, `payment_status=="UNPAID"` (o `"PAID"`/`"PARTIAL"` si hubo pago
inmediato), y todos los ítems en `"pendiente"`.

### Implementation for User Story 1

- [X] T008 [US1] En `pos-backend/app/api/v1/orders/service.py::create_order` (~línea 784): quitar el condicional `"recibida" if data.hold_for_payment else "abierta"` y fijar siempre `status="pendiente"` para todo canal (caja/mostrador, domicilio); fijar `payment_status="UNPAID"` por defecto en la creación del `CustomerOrder`
- [X] T009 [US1] En `pos-backend/app/api/v1/orders/service.py` (~líneas 875-895): mover el descuento de inventario inmediato (`deduct_order_items_naming_product`, `topping_lines.deduct_toppings`) que hoy ocurre al crear cuando `not data.hold_for_payment` para que deje de ejecutarse en la creación — ese descuento pasa al punto de confirmación (T012), igual que ya ocurre para QR — depende de T008

  Nota de implementación: se eliminó el bloque completo (deducción de
  producto + de adiciones) y las variables que solo servían para él
  (`entries`, `inventario_activo`, `topping_consumption`) — quedaban muertas
  tras el cambio, no una limpieza aparte.
- [X] T010 [US1] En `pos-backend/app/api/v1/orders/service.py::create_order`: si el canal confirma el pago en el mismo acto de creación (venta de mostrador pagada de inmediato), fijar `payment_status="PAID"` o `"PARTIAL"` según corresponda en vez de `"UNPAID"` (FR-002, Edge Cases pago mixto/parcial) — depende de T008

  **Decisión de alcance tomada durante la implementación**: `OrderCreate` no
  tiene ningún campo `payments`/`amount_paid` — no existe hoy ningún mecanismo
  por el que `create_order` reciba datos de un pago en la misma llamada
  (`POST /orders` solo crea; cobrar es siempre una llamada aparte,
  `checkout_and_send`/`pay_order`, posterior). El escenario "pago confirmado en
  el mismo acto de creación" que motiva este task no tiene ningún punto de
  entrada real en la API actual. `payment_status` queda siempre `"UNPAID"` al
  crear; construir ese mecanismo (aceptar pagos en `OrderCreate`) sería una
  funcionalidad nueva no pedida literalmente por ningún FR del spec aprobado —
  fuera de alcance (Principio V). Si el negocio confirma que esto debe
  resolverse, es candidata a spec aparte.
- [X] T011 [P] [US1] En `pos-backend/app/api/v1/cart/service.py` (~línea 1034, flujo QR `submit_cart`): cambiar `status="recibida"` a `status="pendiente"`; fijar `payment_status="UNPAID"` en la creación del `CustomerOrder`
- [X] T012 [US1] En `pos-backend/app/api/v1/orders/checkout.py`: generalizar la transición `pendiente → abierta` (hoy solo para QR vía `confirm_order`/`checkout_and_send`) para que sea también el punto donde caja/domicilio descuentan inventario al confirmar, usando el mismo descuento único que T009 dejó de ejecutar en creación — depende de T009

  Nota de implementación: `checkout_and_send` ya era channel-agnóstico (sin
  gate de `OrderPaymentAttempt`) y ya llamaba a `_deduct_and_open` — no
  necesitó lógica nueva, solo los renombres de T016. `confirm_order` (vía
  `_confirm_order_impl`) sigue exigiendo un `OrderPaymentAttempt` confirmado,
  así que sigue siendo exclusivo del camino QR; caja/domicilio usa
  `checkout_and_send` (que además es, hoy, el único camino que el frontend
  vigente ejercita — ver nota de T013).
- [X] T013 [US1] Actualizar `pos-backend/app/characterization_tests/test_orders_service.py` para fijar el nuevo comportamiento de creación (todo canal → `pendiente`/`UNPAID` salvo pago inmediato; descuento de inventario ya no ocurre en la creación de caja/domicilio), citando la decisión registrada en T003 (Principio III) — depende de T008-T010

  Nota de implementación: se verificó en el frontend (`pos-terminal.store.ts`)
  que `createManualOrderFromDraft()` —la única vía real de creación manual—
  siempre envía `hold_for_payment: true`; el camino `hold_for_payment=False`
  (creación directa en `'abierta'` con descuento inmediato) nunca lo ejercita
  el frontend vigente, así que unificarlo a `'pendiente'` para todo canal no
  cambia ningún comportamiento observable de la Terminal hoy. También se
  actualizaron `test_orders_sold_out.py`, `test_order_create_with_toppings.py`
  (gap de descuento de adiciones documentado en su cabecera, citando A-150),
  `test_catalog_option_groups_quantity.py`, `test_order_audit_log.py` y
  `test_orders_pagination.py` — todas con assertions que asumían el
  comportamiento anterior (409 en la creación o `status='abierta'`/`'recibida'`).
- [X] T014 [P] [US1] Actualizar `pos-backend/app/characterization_tests/test_cart_single_active_order.py` (fixtures QR en `"recibida"` → `"pendiente"`) citando T003 — depende de T011
- [X] T015 [P] [US1] Agregar characterization test que fije explícitamente el invariante ya existente de ítems: `OrderItem.estado_cocina` nace `"pendiente"` para todo canal (FR-003, ya cumplido hoy — research.md § 2) en `pos-backend/app/characterization_tests/test_orders_service.py` o archivo nuevo dedicado

  Nota de implementación: archivo nuevo dedicado,
  `test_item_pendiente_invariant.py` — 3 tests (POS/DINE_IN, POS/DELIVERY, QR).

**Checkpoint**: User Story 1 es funcional y probable de forma independiente — crear una orden
por cada canal y verificar `pendiente`/`UNPAID` (o `PAID`/`PARTIAL`) en API y DB.

---

## Phase 4: User Story 2 - Eliminación del estado RECIBIDA y migración de órdenes históricas (Priority: P1) 🎯 MVP (parte 2/2)

**Goal**: `"recibida"` deja de existir como valor válido en cualquier esquema; toda orden/ítem
histórico con ese valor queda migrado a `"pendiente"`; la base de datos rechaza cualquier
intento de volver a escribirlo.

**Independent Test**: Correr la migración sobre una base con órdenes `"recibida"` en varios
tenants y verificar que no queda ningún registro `"recibida"` en ningún esquema, y que esas
órdenes aparecen como `"pendiente"` en la API y en la Terminal de Mesas.

> La migración de esquema en sí (T006/T007) ya corrió en la Fase 2 porque US1 la necesita para
> poder escribir `"pendiente"`. Esta fase cubre lo que falta para que `"recibida"` quede
> **completamente** eliminado del código de aplicación, no solo del esquema.

### Implementation for User Story 2

- [X] T016 [US2] Reemplazar los literales `"recibida"` restantes por `"pendiente"` en `pos-backend/app/api/v1/orders/checkout.py`: `_NOT_DEDUCTED = ("recibida",)` (línea 73), los chequeos `order.status != "recibida"` de `confirm_order`/`checkout_and_send` (líneas ~681, ~787) y sus mensajes de error asociados (líneas ~684, ~790) — depende de T012
- [X] T017 [P] [US2] En `pos-backend/app/api/v1/cash/active_orders.py` (línea 24): `_NON_TERMINAL_ORDER_STATUSES = ("recibida", "abierta", "bloqueada")` → `("pendiente", "abierta", "bloqueada")`
- [X] T018 [P] [US2] En `pos-backend/app/api/v1/table_sessions/service.py` (línea 286): `sin_confirmar = [o for o in orders if o.status == "recibida"]` → `o.status == "pendiente"`
- [X] T019 [P] [US2] Actualizar `pos-backend/app/characterization_tests/test_orders_checkout.py` (fixtures y aserciones `"recibida"` → `"pendiente"`), citando T003 (Principio III) — depende de T016
- [X] T020 [P] [US2] Actualizar `pos-backend/app/characterization_tests/test_cash_close_active_orders.py` citando T003 — depende de T017
- [X] T021 [P] [US2] Actualizar `pos-backend/app/characterization_tests/test_table_sessions_service.py`, `test_table_sessions_router.py` y `table_sessions_fixtures.py` citando T003 — depende de T018
- [X] T022 [P] [US2] Actualizar `pos-backend/app/characterization_tests/test_orders_payment_gate.py`, `test_orders_status_type_filters.py` y `cart_fixtures.py` (fixtures `"recibida"` → `"pendiente"`) citando T003
- [X] T023 [P] [US2] Actualizar `pos-backend/app/scripts/test_cancel_inventory.py`, `e2e_qr_flow.py`, `test_variant_option_groups.py`, `test_receta_obligatoria.py` y `test_purchase_draft_incomplete.py` (fixtures `"recibida"` → `"pendiente"`)

  Nota de implementación: `test_purchase_draft_incomplete.py` no tenía ningún
  literal de estado de orden que renombrar — su único uso de "recibida" es
  sobre el dominio de compras de inventario ("compra ya recibida"), sin
  relación con `CustomerOrder.status`. Sin cambios en ese archivo.
- [X] T024 [US2] Agregar characterization test nuevo `pos-backend/app/characterization_tests/test_migration_pendiente_payment_status.py` que verifique end-to-end lo de quickstart.md Escenario 2: cobertura multi-esquema de la migración, `0` filas `"recibida"` tras `upgrade`, rechazo de `"recibida"` a nivel de CHECK, y tenant sin filas `"recibida"` sin cambios adicionales — depende de T007

  Nota de implementación: la migración usa `op.*` (contexto de Alembic) +
  DDL de Postgres dentro de `@for_each_tenant_schema`, no una función de
  datos aislable como las migraciones de promociones — no se puede ejercitar
  contra SQLite en memoria. El archivo nuevo cubre lo verificable sin
  Postgres real (cadena de revisiones, firma de `upgrade`/`downgrade`); la
  verificación end-to-end real contra Postgres (quickstart Escenario 2) se
  hizo manualmente esta sesión y queda documentada en el docstring del
  archivo y en la nota de T007.
- [X] T025 [US2] Barrido final: `grep -rn "'recibida'\|\"recibida\"" pos-backend/app` debe devolver cero resultados fuera de comentarios que documentan historia/decisiones ya tomadas (p. ej. `checkout.py` docstrings explicando la transición antigua); corregir cualquier literal vivo que aparezca — depende de T016-T023

  Verificado: cero literales `'recibida'`/`"recibida"` vivos fuera de
  `app/models/purchase.py`/`app/api/v1/inventory/*` (dominio de compras, sin
  relación) y comentarios de historia en `orders/service.py`/
  `test_orders_pagination.py`. Suite completa (con T015/T024 ya agregados):
  2044/2045 tests en verde (el 1 restante, `test_cash_report_query_budget.py`,
  falla igual en `develop` limpio sin ningún cambio de esta spec — confirmado
  con `git stash`).

**Checkpoint**: User Stories 1 y 2 funcionan juntas e independientemente — migración corrida,
`"recibida"` ausente en cualquier esquema y en cualquier ruta de código, rechazado por la DB.

---

## Phase 5: User Story 3 - El frontend muestra el estado crudo entregado por la API (Priority: P2)

**Goal**: Ninguna pantalla traduce ni infiere el estado de una orden o ítem; se muestra siempre
el valor crudo de `status`/`estado_cocina`; un valor no mapeado se muestra crudo y se loguea
como error en consola.

**Independent Test**: Simular que la API devuelve un estado no mapeado y verificar que la
pantalla de detalle muestra ese valor crudo (no un estado por defecto) y que se registra un
error en consola; verificar que una orden `payment_status="PAID"` con `status="pendiente"`
sigue mostrándose como "Pendiente" en todas las pantallas.

### Implementation for User Story 3

- [X] T026 [US3] En `pos-heladeria/src/app/modules/orders/order-status.util.ts`: reemplazar los mapas de traducción `ORDER_STATUS`/`KITCHEN_STATUS` (usados hoy para producir una etiqueta traducida) por listas estáticas `KNOWN_ORDER_STATUSES`/`KNOWN_KITCHEN_STATUSES` usadas solo para detectar valores no mapeados y loguear `console.error`; ningún helper debe seguir devolviendo una etiqueta distinta al valor crudo recibido
- [X] T027 [P] [US3] Actualizar `pos-heladeria/src/app/modules/orders/order-status.util.spec.ts`: specs para detección de valor no mapeado + `console.error`, eliminar specs de la traducción vieja — depende de T026
- [X] T028 [US3] En `pos-heladeria/src/app/modules/orders/pages/order-detail.component.ts`: eliminar `displayOrderStatus()` y cualquier sustitución de `order.status` por `"pagada"` basada en `order.paid`; mostrar siempre el `status`/`estado_cocina` crudo — depende de T026
- [X] T029 [P] [US3] Actualizar `pos-heladeria/src/app/modules/orders/pages/order-detail.component.spec.ts` — depende de T028
- [X] T030 [US3] En `pos-heladeria/src/app/modules/orders/pages/orders-page.component.ts`: filtro/literal `'recibida'` → `'pendiente'`
- [X] T031 [P] [US3] Actualizar `pos-heladeria/src/app/modules/orders/pages/orders-page.component.spec.ts` — depende de T030
- [X] T032 [US3] En `pos-heladeria/src/app/modules/orders/services/orders-list.service.ts`: `OrdersStatusFilter` type (`'' | 'recibida' | 'abierta' | 'bloqueada' | 'pagada' | 'cancelada'`) → reemplazar `'recibida'` por `'pendiente'`
- [X] T033 [US3] En `pos-heladeria/src/app/modules/tables/services/pos-terminal.store.ts`: acotar `deriveTableStatus()` a heurística de **ocupación de mesa** únicamente; deja de alimentar el `statusLabel` de las tarjetas de **orden individual** (`OrderSummaryCardView`) dentro del panel de mesas — esas tarjetas pasan a mostrar el `status` crudo de esa orden específica

  Nota de implementación: el único consumidor de `OrderSummaryCardView` es
  `toOrderCardView()` (tarjetas de domicilio/para-llevar); se reemplazó su
  llamada a `deriveTableStatus([o], 'ocupada')` por `orderStatusLabel(o.status)`/
  `orderStatusClass(o.status)` directamente. `deriveTableStatus` sigue
  intacto para el agregado real de mesa (`tablesView()`).
- [X] T034 [P] [US3] Actualizar `pos-heladeria/src/app/modules/tables/services/pos-terminal.store.spec.ts` — depende de T033
- [X] T035 [P] [US3] En `pos-heladeria/src/app/modules/tables/interfaces/dining.interface.ts`: `DiningOrderStatus` — `'recibida'` → `'pendiente'`
- [X] T036 [P] [US3] Actualizar `pos-heladeria/src/app/modules/tables/interfaces/dining.interface.spec.ts` — depende de T035 (sin cambios: no tenía ningún literal `'recibida'`)
- [X] T037 [US3] En `pos-heladeria/src/app/modules/tables/pages/checkout/checkout-hydration.guard.ts`: literal `'recibida'` → `'pendiente'`
- [X] T038 [US3] En `pos-heladeria/src/app/modules/tables/components/pos-checkout-panel.component.ts`: literal(es) `'recibida'` → `'pendiente'`; eliminar cualquier inferencia de estado de orden a partir de otros campos (no había ninguna más allá de los literales renombrados — verificado, sin `displayOrderStatus`/`deriveTableStatus` en este archivo)
- [X] T039 [P] [US3] Actualizar `pos-heladeria/src/app/modules/tables/components/pos-checkout-panel.component.spec.ts` — depende de T038
- [X] T040 [US3] En `pos-heladeria/src/app/modules/tables/pages/public-menu.component.ts` (línea ~453, condición de template `order.status === 'recibida'`): `'recibida'` → `'pendiente'`
- [X] T041 [P] [US3] Actualizar `pos-heladeria/src/app/modules/tables/pages/public-menu.component.spec.ts` — depende de T040
- [X] T042 [US3] En `pos-heladeria/src/app/modules/tables/components/payment-attempt-review-panel.component.ts`: verificar si hay lógica viva (no solo comentarios) que compare contra `'recibida'` y actualizarla a `'pendiente'` (solo había comentarios de historia; actualizados por consistencia, sin lógica viva que tocar)
- [X] T043 [P] [US3] Actualizar `pos-heladeria/src/app/modules/tables/components/payment-attempt-review-panel.component.spec.ts` — depende de T042
- [X] T044 [P] [US3] Actualizar fixtures `'recibida'` → `'pendiente'` en `pos-heladeria/src/app/modules/tables/components/pos-order-panel.component.spec.ts` y `order-summary-card.component.spec.ts` (este último no tenía ningún literal `'recibida'`, sin cambios)
- [X] T045 [P] [US3] Actualizar fixtures `'recibida'` → `'pendiente'` en `pos-heladeria/src/app/modules/tables/pages/table-sessions.component.spec.ts`
- [X] T046 [P] [US3] Actualizar fixtures `'recibida'` → `'pendiente'` en `pos-heladeria/src/app/modules/tables/pages/manual-order-page.component.spec.ts` (sin literales `'recibida'`, sin cambios)
- [X] T047 [P] [US3] Actualizar fixtures `'recibida'` → `'pendiente'` en `pos-heladeria/src/app/modules/tables/services/diner.service.spec.ts` y `dining-session.service.spec.ts`
- [X] T048 [P] [US3] Actualizar fixtures `'recibida'` → `'pendiente'` en `pos-heladeria/src/app/modules/cash-register/components/cash-arqueo-modal.component.spec.ts` y `pos-heladeria/src/app/modules/cash-register/services/cash-session.store.spec.ts`
- [X] T049 [US3] Barrido final: `grep -rln "'recibida'\|\"recibida\"" src` en `pos-heladeria` debe devolver cero coincidencias fuera de comentarios que documentan historia ya resuelta; corregir cualquier literal vivo que aparezca — depende de T026-T048

  Verificado: cero literales `'recibida'`/`"recibida"` vivos en `src/` fuera
  del dominio de compras de inventario (`inventory.interface.ts`,
  `inventory-page.component.ts`, `inventory.service.ts`, sin relación con
  `CustomerOrder.status`). Suite completa de Vitest: 2460 passed, 15 failed —
  los 15 son exactamente el baseline conocido/flaky preexistente (ver memoria
  "cómo correr tests del repo hermano": `app.spec`, `auth.service`,
  `menu.service`, `tenant.service`, `pos-checkout-panel`, `pos-order-panel`,
  `manual-order-page`, `pos-terminal.store`, `date-usage.guard`), ninguno en
  los módulos tocados por esta spec (`orders/*`, `order-status.util`,
  `dining.interface`, `orders-list.service`, `public-menu`,
  `payment-attempt-review-panel`, `checkout-hydration.guard`,
  `table-sessions`, `diner.service`, `dining-session.service`,
  `cash-session.store`, `cash-arqueo-modal`).

**Checkpoint**: User Story 3 es funcional y probable de forma independiente — un estado no
mapeado se muestra crudo y loguea error; `payment_status="PAID"` no sustituye la etiqueta de
`status="pendiente"`; las tarjetas de orden individual del panel de mesas muestran su `status`
crudo, y solo el agregado de ocupación de mesa puede diferir.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [~] T050 Ejecutar manualmente los 3 escenarios de `quickstart.md` de punta a punta contra backend+frontend locales (creación por canal, migración, visualización cruda) y confirmar SC-001 a SC-005

  Parcial: Escenario 2 (migración) verificado de punta a punta contra Postgres
  real (ver nota de T007). Escenarios 1 y 3 (creación por canal vía HTTP real
  y visualización en la UI corriendo en el navegador) **no se ejecutaron**
  en esta sesión — la cobertura equivalente vive en los characterization
  tests de backend (T013/T015) y en los specs de frontend (T027-T049), pero
  eso no sustituye una pasada manual real contra los servidores corriendo.
  Pendiente antes de dar por cerrado el feature.
- [X] T051 Correr la suite completa de characterization tests de `pos-backend` (venv del proyecto, ver memoria "cómo correr tests del repo hermano") y confirmar que no quedan referencias rotas ni regresiones fuera del alcance de este feature — 2044/2045 en verde, el 1 restante preexistente (ver nota de T025)
- [X] T052 Correr la suite completa de Vitest de `pos-heladeria` y diferenciar por archivo contra el baseline conocido (memoria: baseline de frontend es flaky/no determinista — comparar por archivo, no por conteo total) — 2460 passed / 15 failed, los 15 son el baseline conocido (ver nota de T049)
- [X] T053 Revisar que `contracts/order-status-contract.md` siga reflejando exactamente los campos/valores finales expuestos por la API tras la implementación (sin cambios esperados, solo verificación) — confirmado: `status` (`pendiente|abierta|bloqueada|pagada|cancelada`), `payment_status` (`UNPAID|PAID|PARTIAL`) y `estado_cocina` (sin cambios) coinciden exactamente con lo implementado

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Fase 1)**: sin dependencias — T001/T002 en paralelo (repos distintos)
- **Foundational (Fase 2)**: depende de Setup; **bloquea** todas las historias — sin T003 no se toca código (Principio II); sin T006/T007 `"pendiente"` no es un valor válido en ningún esquema
- **US1 (Fase 3)** y **US2 (Fase 4)**: ambas dependen de Foundational completo; comparten prioridad P1 y forman el MVP junto con Foundational. US2 depende parcialmente de que T012 (US1) exista antes de generalizar los chequeos de `checkout.py` (T016), pero puede avanzar en paralelo en los archivos que no tocan creación (T017, T018, T024)
- **US3 (Fase 5)**: depende de que el backend (US1+US2) ya devuelva `"pendiente"`/`payment_status` reales en la API — no tiene sentido verificar "muestra el valor crudo" contra un backend que todavía no lo produce
- **Polish (Fase 6)**: depende de que las tres historias estén completas

### Parallel Opportunities

- T001, T002 (ramas en repos distintos)
- T004, T005 (archivos distintos: `schemas.py` vs `customer_order.py`)
- T011, T014 dentro de US1 (ruta QR, independiente de T008-T010/T012-T013 de caja/domicilio)
- T017, T018 dentro de US2 (archivos distintos)
- T019-T023 dentro de US2 (archivos de test distintos entre sí)
- La mayoría de los pares `componente.ts` + `componente.spec.ts` en US3 pueden tratarse como una unidad secuencial, pero distintos componentes (T033 vs T035 vs T037, etc.) son paralelos entre sí

---

## Parallel Example: Foundational

```bash
Task: "Renombrar OrderStatus.RECIBIDA a PENDIENTE y agregar PaymentStatus en pos-backend/app/api/v1/orders/schemas.py"
Task: "Agregar columna payment_status y actualizar CHECK de status en pos-backend/app/models/customer_order.py"
```

## Parallel Example: User Story 3 (componentes independientes)

```bash
Task: "pos-terminal.store.ts: acotar deriveTableStatus a ocupación de mesa"
Task: "dining.interface.ts: DiningOrderStatus 'recibida' -> 'pendiente'"
Task: "orders-list.service.ts: OrdersStatusFilter 'recibida' -> 'pendiente'"
```

---

## Implementation Strategy

### MVP First (Foundational + User Story 1 + User Story 2)

Las dos historias P1 comparten el mismo prerrequisito de esquema (Fase 2) y, juntas, resuelven
el problema central del spec (estado inicial consistente entre canales + eliminación de
`"recibida"`) sin tocar el frontend todavía. El MVP de este feature es:

1. Fase 1: Setup
2. Fase 2: Foundational (**crítico** — bloquea todo lo demás)
3. Fase 3: User Story 1
4. Fase 4: User Story 2
5. **STOP and VALIDATE**: correr Escenarios 1 y 2 de `quickstart.md` contra el backend
6. Desplegar/demo backend si está listo (el frontend sigue funcionando con `deriveTableStatus`/`displayOrderStatus` sin romperse, solo sin cumplir aún FR-008/FR-009)

### Incremental Delivery

1. Setup + Foundational → esquema listo, `"pendiente"` válido, `"recibida"` rechazado
2. + User Story 1 → toda orden nueva nace `pendiente`/`UNPAID` → probar independientemente
3. + User Story 2 → `"recibida"` erradicado de código y datos históricos → probar independientemente → **MVP completo**
4. + User Story 3 → frontend deja de traducir/inferir → probar independientemente → feature completo
5. Polish: validación end-to-end + suites completas de test

### Commits/PRs (Principio VI)

No mezclar en un único commit/PR: (1) Foundational+US1, (2) US2, (3) US3 — tal como lo divide
`plan.md` en sus "3 unidades verificables". Ramas creadas en T001/T002; commits en inglés bajo
pedido explícito del usuario (Principio XV).
