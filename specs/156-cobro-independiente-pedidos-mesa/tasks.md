---

description: "Task list: Cobro independiente de pedidos por mesa"
---

# Tasks: Cobro independiente de pedidos por mesa

**Input**: Design documents from `specs/156-cobro-independiente-pedidos-mesa/`
(`plan.md`, `spec.md`, `research.md`, `data-model.md`,
`contracts/table-session-charge-subset.md`, `quickstart.md`)

**Repos afectados** (fuera de `pos-specs`): `../pos-backend` (FastAPI) y
`../pos-heladeria` (Angular).

**Tests**: Solicitados explícitamente en `plan.md`/`quickstart.md`
("Verificación automatizada") — se incluyen tareas de test por historia.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Puede ejecutarse en paralelo (archivos distintos, sin dependencias)
- **[Story]**: US1 (P1), US2 (P2), US3 (P2)

---

## Phase 1: Setup

- [X] T001 Crear la rama `feat/156-cobro-independiente-pedidos-mesa` desde la
  rama actual en `../pos-backend` y en `../pos-heladeria` (Principio XIV; no
  aplica a `pos-specs`).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: la validación/filtrado de `order_ids` es compartida por `/bill`
(US3), `/charge` con 1 id (US1) y `/charge` con varios ids (US2) — debe existir
antes de implementar cualquier historia. Sin cambios en `_assert_closable`,
`_close_unified`, `_close_split`, `close_session`, `release_paid_session`
(D2/D3/D6 de `research.md`).

- [X] T002 [P] Agregar campo opcional `order_ids: list[UUID] | None = None` a
  `CloseSessionIn` en `../pos-backend/app/api/v1/table_sessions/schemas.py`
  (junto a `cash_shift_id`/`billing_mode`, con `Field(None, description=...)`
  documentando que acota el cobro al subconjunto indicado; sin valor =
  comportamiento actual).
- [X] T003 Agregar una función `_resolve_orders_to_charge(db, table_session_id,
  order_ids: list[UUID] | None) -> list[CustomerOrder]` en
  `../pos-backend/app/api/v1/table_sessions/service.py`, junto a
  `_billable_orders` (línea ~200): si `order_ids` es `None`, devuelve
  `_billable_orders(db, table_session_id)` sin cambios (compatibilidad total,
  Principio II); si no es `None`, filtra ese resultado por los ids pedidos y,
  si algún id solicitado no aparece en el filtrado, lanza
  `HTTPException(409, detail={"error": "Algunos pedidos seleccionados no se
  pueden cobrar.", "order_ids": [...]})` listando los ids no encontrados
  (D4/D5 de `research.md`, mismo patrón que usa `release_paid_session` para
  `orders` abiertas).
- [X] T004 Modificar `compute_bill(db, table_session_id, tenant=None)` en
  `../pos-backend/app/api/v1/table_sessions/service.py` (línea ~218) para
  aceptar un parámetro opcional `order_ids: list[UUID] | None = None` y usar
  `_resolve_orders_to_charge` (T003) en vez de `_billable_orders` directo, sin
  tocar el resto de la función (cálculo de `split`/`total`/`instant` no
  cambia).
- [X] T005 Agregar el query param opcional `order_ids: list[UUID] | None =
  Query(None)` al endpoint `GET /table-sessions/{table_session_id}/bill` en
  `../pos-backend/app/api/v1/table_sessions/router.py` (función `session_bill`,
  línea ~107) y pasarlo a `service.compute_bill(db, table_session_id, tenant,
  order_ids=order_ids)`.
- [X] T006 Modificar `_charge_session(db, table_session_id, data, cashier, ...)`
  en `../pos-backend/app/api/v1/table_sessions/service.py` (línea ~344) para
  usar `_resolve_orders_to_charge(db, ts.id, data.order_ids)` en vez de
  `_billable_orders(db, ts.id)` directo. No tocar `close_session` (D2): su
  llamada interna a `_charge_session`/al mismo flujo de cierre sigue sin pasar
  `order_ids` (o lo ignora si `CloseSessionIn` lo trae en ese contexto —
  confirmar en T006 que `close_session` nunca lee `data.order_ids`, para no
  violar D2).
- [X] T007 [P] Agregar `order_ids?: string[]` opcional a la interfaz
  `CloseSessionPayload` en
  `../pos-heladeria/src/app/modules/tables/interfaces/dining.interface.ts`
  (junto a los demás campos de `CloseSessionIn`, línea ~671).
- [X] T008 Actualizar `TableSessionService` en
  `../pos-heladeria/src/app/modules/tables/services/table-session.service.ts`:
  `bill(id, orderIds?: string[])` agrega `?order_ids=...` (repetido por cada id)
  a la URL de `GET .../bill` solo si `orderIds` tiene elementos; `charge()` ya
  recibe `order_ids` dentro de `payload: CloseSessionPayload` (T007) sin
  cambios de firma.

**Checkpoint**: con esta base, `/bill` y `/charge` aceptan `order_ids` de
extremo a extremo; falta exponer la selección en la UI y cubrir con tests.

---

## Phase 3: User Story 1 - Cobrar un pedido individual de la mesa (Priority: P1) 🎯 MVP

**Goal**: el cajero cobra un solo "Pedido N" de la mesa sin afectar a los
demás pedidos pendientes de la misma sesión.

**Independent Test**: dos pedidos en la misma mesa, cobrar solo uno, verificar
que éste queda `PAID` y el otro sigue `UNPAID` sin liberar la mesa.

### Tests for User Story 1

- [X] T009 [P] [US1] Nuevo archivo de test
  `../pos-backend/app/characterization_tests/test_table_sessions_order_ids.py`
  (reutiliza `table_sessions_fixtures.py` como los tests existentes de
  `test_table_sessions_service.py`, pero sin el prefijo "CONGELA" por ser
  comportamiento nuevo): cubre Escenario 1 de `quickstart.md` —
  `compute_bill(..., order_ids=[pedido_42.id])` devuelve `total`/`order_ids`
  solo del Pedido 42; `_charge_session` con `order_ids=[pedido_42.id]` deja
  Pedido 42 `payment_status='PAID'` y Pedido 41 `'UNPAID'`; la sesión sigue
  `'active'`.
- [X] T010 [P] [US1] En el mismo archivo de T009: Escenario 5 — `order_ids`
  con un id que ya está `PAID` (o de otra sesión) → `HTTPException` 409 con
  `detail["order_ids"]` listando el id inválido, tanto desde `compute_bill`
  como desde `_charge_session`.
- [X] T011 [P] [US1] En el mismo archivo de T009: Escenario 6 — mesa con un
  único pedido pendiente; cobrar sin `order_ids` y cobrar con `order_ids=[ese
  id]` producen el mismo resultado (mismo `Sale`, mismo `payment_status`)
  — confirma que el caso por defecto no cambió (Principio II).

### Implementation for User Story 1

- [X] T012 [US1] En
  `../pos-heladeria/src/app/modules/tables/services/pos-terminal.store.ts`,
  agregar una señal `selectedChargeOrderIds = signal<Set<string>>(new
  Set())` junto a `selectedOrderId` (línea ~479): se reinicia a "todos los
  `orderTabs()` no pagados de la sesión actual" cada vez que cambia
  `sessionBill()`/`orderTabs()` de mesa (mismo patrón que usa `ngOnChanges` en
  `session-bill-panel.component.ts` para resetear el pago al cambiar `bill`),
  replicando por defecto "cobrar todo" (D7 de `research.md`).
- [X] T013 [US1] Agregar en `pos-terminal.store.ts` un método
  `toggleChargeOrder(orderId: string)` que añade/quita `orderId` del `Set` de
  T012, y un computed `chargeOrderIdsParam = computed(() => { ... })` que
  devuelve `undefined` si la selección incluye exactamente todos los pedidos
  facturables actuales (para no romper el caso por defecto, Principio II) o
  el arreglo de ids seleccionados en caso contrario.
- [X] T014 [US1] En
  `../pos-heladeria/src/app/modules/tables/components/pos-order-panel.component.ts`,
  agregar un control de selección (checkbox o icono toggle) dentro de cada
  pestaña "Pedido N" del `role="tablist"` (línea ~247), visible solo cuando el
  pedido está `UNPAID`/pendiente de cobro, enlazado a
  `store.selectedChargeOrderIds()`/`store.toggleChargeOrder(ot.id)` (T012/T013)
  — sin afectar el click que ya selecciona la pestaña activa
  (`selectOrderTab`).
- [X] T015 [US1] En `pos-terminal.store.ts`, pasar
  `store.chargeOrderIdsParam()` (T013) a `this.tableSessions.bill(session.id,
  ...)` dentro de `refreshBill()` (línea ~1820) y donde se llama a `bill()` al
  seleccionar mesa (línea ~3070), para que `sessionBill()` refleje el total
  del subconjunto seleccionado.
- [X] T016 [US1] En
  `../pos-heladeria/src/app/modules/tables/components/session-bill-panel.component.ts`,
  agregar `@Input() chargeOrderIds: string[] | undefined` y usarlo en
  `buildPayload()` (línea ~334) como `...(this.chargeOrderIds?.length ?
  {order_ids: this.chargeOrderIds} : {})`.
- [X] T017 [US1] En
  `../pos-heladeria/src/app/modules/tables/components/pos-checkout-panel.component.ts`,
  pasar `[chargeOrderIds]="store.chargeOrderIdsParam()"` a las dos
  instancias de `<app-session-bill-panel>` (líneas ~154 y ~186).

**Checkpoint**: cobrar un único pedido de una mesa con varios pedidos ya no
cobra a los demás; el flujo con un solo pedido en la mesa no cambia.

---

## Phase 4: User Story 2 - Cobrar varios pedidos de la mesa en una sola transacción (Priority: P2)

**Goal**: el cajero sigue pudiendo cobrar 2+ (o todos) los pedidos pendientes
de la mesa en una sola operación, sin regresión del flujo actual.

**Independent Test**: seleccionar 2+ pedidos pendientes y confirmar que el
cobro conjunto los marca `PAID` en una sola transacción, sin afectar a un
tercer pedido no seleccionado.

### Tests for User Story 2

- [X] T018 [P] [US2] En
  `../pos-backend/app/characterization_tests/test_table_sessions_order_ids.py`
  (mismo archivo de T009): Escenario 2 — `_charge_session` con
  `order_ids=[pedido_41.id, pedido_42.id]` deja ambos `PAID` en una sola
  llamada, generando la(s) `Sale` según `billing_mode` (`unified`→1 `Sale`,
  `split`→1 por comensal) igual que hoy sin selección.
- [X] T019 [P] [US2] En el mismo archivo: mesa con 3 pedidos pendientes,
  `order_ids` con solo 2 de ellos → el tercero permanece `'UNPAID'` tras el
  cobro (acceptance scenario 2 de User Story 2 en `spec.md`).

### Implementation for User Story 2

- [X] T020 [US2] Verificar que el control de selección de T014 permite marcar
  más de un pedido a la vez (es un `Set`, no una selección única) y que
  `chargeOrderIdsParam()` (T013) devuelve el arreglo completo cuando se
  seleccionan 2+ pedidos; ajustar si el control de T014 se implementó como
  radio/single-select en vez de checkbox.
- [X] T021 [US2] Agregar un control "Seleccionar todos / Ninguno" en el mismo
  bloque de pestañas de `pos-order-panel.component.ts` (T014) para cobrar
  varios pedidos sin tocarlos uno por uno — preselecciona todos por defecto
  (ya es el comportamiento de T012) y permite deseleccionar todos de un
  golpe.

### Tests for User Story 2 (frontend)

- [X] T022 [US2] En
  `../pos-heladeria/src/app/modules/tables/components/pos-order-panel.component.spec.ts`,
  test que selecciona 2 pestañas y verifica que
  `store.chargeOrderIdsParam()` expone ambos ids.

**Checkpoint**: cobro individual y cobro conjunto conviven sin romperse
mutuamente; seleccionar todos replica el "Cobrar y cerrar mesa" actual.

---

## Phase 5: User Story 3 - Visualizar el estado de pago de cada pedido de la mesa (Priority: P2)

**Goal**: el cajero distingue a simple vista qué pedidos de la mesa ya están
pagados y cuáles pendientes, incluyendo justo después de un cobro parcial
(US1/US2).

**Independent Test**: mesa con pedidos en distinto estado de pago; abrir su
cuenta y verificar que la interfaz diferencia pagados de pendientes, y que se
actualiza tras cobrar uno de ellos.

**Nota**: `paymentStatusLabel`/`paymentStatusClass` ya existen en
`pos-terminal.store.ts` (líneas ~1127, ~1226) y ya se muestran en
`order-summary-card.component.ts` y `pos-order-panel.component.ts` (línea
~115). Falta llevarlos a las pestañas "Pedido N" mismas (donde el cajero
elige qué cobrar) y confirmar que se refrescan tras un cobro parcial.

### Tests for User Story 3

- [X] T023 [P] [US3] En
  `../pos-heladeria/src/app/modules/tables/components/pos-order-panel.component.spec.ts`,
  test que, con `orderTabs()` mezclando pedidos `PAID`/`UNPAID`, verifica que
  cada pestaña muestra su badge de estado (`paymentStatusLabel`/
  `paymentStatusClass`) y que un pedido `PAID` no ofrece el control de
  selección de cobro de T014 (ya cobrado, no se puede volver a seleccionar).
- [X] T024 [P] [US3] En
  `../pos-backend/app/characterization_tests/test_table_sessions_order_ids.py`
  (mismo archivo de T009): tras cobrar Pedido 42 de forma independiente,
  `GET /bill` sin `order_ids` refleja solo lo pendiente (Pedido 41) — cubre
  acceptance scenario 2 de User Story 1, reutilizado aquí como soporte de
  US3 (el total mostrado ya no incluye lo cobrado).

### Implementation for User Story 3

- [X] T025 [US3] En `pos-order-panel.component.ts`, agregar el badge de
  `ot.paymentStatusLabel`/`ot.paymentStatusClass` (exponer esos campos en
  `orderTabs()` del store si `orderTabs()` aún no los incluye — verificar
  contra `paymentStatusLabel`/`paymentStatusClass` por pedido, línea ~1226)
  dentro de cada botón de pestaña del `role="tablist"` (línea ~247), junto al
  indicador `ot.pending` ya existente.
- [X] T026 [US3] Confirmar que `refreshBill()`/el manejo de
  `session.bill_changed` en `pos-terminal.store.ts` (línea ~1775) actualiza
  `orderTabs()` (y por tanto los badges de T025) después de un cobro parcial
  sin recargar toda la página — si solo marca `billStale` sin recomputar
  `orderTabs()`, ajustar para que el estado de pago por pestaña no quede
  obsoleto tras el cobro de otro cajero/terminal.

**Checkpoint**: todas las historias (US1/US2/US3) funcionan juntas: cobro
individual, cobro conjunto, y visibilidad del estado de pago por pedido.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [ ] T027 Ejecutar los Escenarios 1-6 de `quickstart.md` manualmente contra
  backend+frontend corriendo en local (ver memoria `how-to-run-sibling-repo-tests`
  para el comando del venv de `pos-backend` y Postgres local).
- [X] T028 Ejecutar `python -m unittest
  app.characterization_tests.test_table_sessions_service -v` y el resto de
  `app/characterization_tests/` en `pos-backend` y confirmar que ningún test
  `"CONGELA comportamiento actual:"` cambió (Principio III/X).
- [X] T029 [P] Ejecutar la suite de `pos-heladeria` (Angular) y diffear contra
  el baseline conocido (memoria: "frontend baseline es flaky/no determinista
  — comparar por archivo, no por el conteo total de la suite").

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias.
- **Foundational (Phase 2)**: depende de Setup — BLOQUEA las historias.
- **US1 (Phase 3)**: depende de Foundational. Es el MVP.
- **US2 (Phase 4)**: depende de Foundational; reutiliza casi toda la
  implementación de US1 (T012-T017) — sus tareas propias son principalmente de
  test + UI de selección múltiple/"todos".
- **US3 (Phase 5)**: depende de Foundational; depende de que T012-T014 (US1)
  existan, porque el badge de estado (T025) vive en el mismo bloque de
  pestañas que el control de selección.
- **Polish (Phase 6)**: depende de que US1-US3 estén implementadas.

### Parallel Opportunities

- T002 y T007 (esquemas backend/frontend, archivos distintos) en paralelo.
- T009, T010, T011 (mismo archivo nuevo, pero métodos de test independientes)
  pueden escribirse en paralelo y luego unirse en un solo archivo.
- T018, T019 en paralelo con T009-T011 una vez exista T003 (mismo archivo de
  test, distintos métodos).
- T023, T024 en paralelo (frontend vs backend).

---

## Implementation Strategy

### MVP First (User Story 1)

1. Fase 1 (Setup) + Fase 2 (Foundational) — obligatorias primero.
2. Fase 3 (US1): backend ya permite cobrar un pedido individual; frontend
   expone la selección. **Checkpoint**: validar Escenario 1 de
   `quickstart.md` manualmente antes de seguir.
3. Fase 4 (US2): confirma que seleccionar varios/todos no se rompió.
4. Fase 5 (US3): pule la visibilidad del estado de pago por pedido, que ya
   era casi toda preexistente (research.md D7).
5. Fase 6: verificación cruzada (quickstart + characterization tests +
   suite frontend) antes de dar la feature por completa.
