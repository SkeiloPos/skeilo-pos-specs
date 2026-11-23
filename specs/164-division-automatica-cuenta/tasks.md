---

description: "Task list for feature 164: División automática de cuenta por ítem"
---

# Tasks: División automática de cuenta por ítem

**Input**: Design documents from `/specs/164-division-automatica-cuenta/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/orders-item-transfer.md, quickstart.md

**Tests**: Backend characterization tests are included — the plan and quickstart explicitly name
`test_orders_item_transfer.py` as the regression suite that proves FR-001..FR-010/SC-001..SC-004,
following the existing `"CONGELA comportamiento actual:"` pattern used by
`test_orders_tables_advanced.py`. Frontend unit tests are NOT included — no existing Angular
specs cover `pos-order-panel.component.ts` today (per plan.md Testing section), so adding a first
one is out of scope for this feature.

**Organization**: Tasks are grouped by user story (US1 = Dividir cuenta, US2 = Mover ítem, US3 =
Crear cuenta nueva desde ítem), per their priority in spec.md (US1/US2 = P1, US3 = P2).

## Path Conventions

Sibling repos referenced from this spec repo's root (`pos-specs/`), per plan.md's Project
Structure:

- Backend: `pos-backend/app/...`
- Frontend: `pos-heladeria/src/app/...`

---

## Phase 1: Setup

**Purpose**: Branch for the feature (no new dependencies or project scaffolding needed — plan.md
confirms no new deps, no schema migration).

- [X] T001 Create branch `feat/164-division-automatica-cuenta` from `main` in both `pos-backend`
  and `pos-heladeria` repos (Principio XIV).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared backend/frontend building blocks that all three operations (split, move,
split-to-new) depend on. No user story can be implemented until this phase is done.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T002 Add request/response Pydantic schemas for the three new endpoints in
  `pos-backend/app/api/v1/orders/schemas.py` (next to `MoveOrderIn`/`MergeResponse`, ~line 87-99):
  `ItemMoveIn` (`target_order_id: UUID`, `quantity: int | None`), `SplitToNewIn`
  (`quantity: int | None`), `OrderTotalSummary` (`order_id: UUID`, `deleted: bool = False`,
  `total: Decimal`), `SplitOrderCreatedItem` (`order_id`, `table_order_number`, `item` summary),
  `SplitOrderResponse` (`original_order_id`, `created_orders: list[SplitOrderCreatedItem]`),
  `MoveItemResponse` (`source_order: OrderTotalSummary`, `target_order: OrderTotalSummary`,
  `merged: bool`), `SplitToNewResponse` (`source_order: OrderTotalSummary`,
  `new_order: OrderTotalSummary` with `table_order_number`) — matching the response shapes in
  `contracts/orders-item-transfer.md`.
- [X] T003 [P] Create `pos-backend/app/api/v1/orders/item_transfer.py` with the shared guard
  helpers reused by all three operations, following the `tables_advanced.py` pattern (pure
  service functions + explicit transaction): `_assert_not_paid(db, order)` (wraps
  `service.order_has_sale`, raises the `403` matching each operation's message from the
  contract), `_assert_same_table(source_order, target_order)` (raises `400` "La orden destino no
  pertenece a la misma mesa" on `table_session_id`/`dining_table_id` mismatch per FR-009),
  `_find_mergeable_item(target_order, product_variant_id, unit_price, discounted_unit_price,
  estado_cocina)` (fusion key per research.md §3), `_delete_order_if_empty(db, order)` (deletes a
  `CustomerOrder` with zero `OrderItem` rows, FR-007/SC-002), `_new_sibling_order(db,
  source_order)` (builds a new `CustomerOrder` copying `table_session_id`, `dining_table_id`,
  `channel`, `order_type`, `cash_shift_id`, a fresh `table_order_number`, `participant_id=None`,
  reusing the same numbering logic as `create_order`/`submit_cart`, per research.md §4).
- [X] T004 [P] Add `make_order_with_items(db, table, variant, *, quantities: list[int],
  estado_cocina: str = "pendiente", **kw)` helper to
  `pos-backend/app/characterization_tests/orders_fixtures.py` (building on
  `make_customer_order`/`make_order_item`, ~lines 314-357), returning a `CustomerOrder` with one
  `OrderItem` per entry in `quantities` — needed by every test in Phase 3-5 to build multi-line
  orders without repeating fixture boilerplate.
- [X] T005 [P] Add TypeScript request/response interfaces for the three operations to
  `pos-heladeria/src/app/modules/tables/interfaces/dining.interface.ts`: `OrderTotalSummary`,
  `SplitOrderResponse`, `MoveItemRequest`, `MoveItemResponse`, `SplitItemToNewRequest`,
  `SplitItemToNewResponse` — mirroring the backend schemas from T002 and the JSON shapes in
  `contracts/orders-item-transfer.md`.

**Checkpoint**: Shared guards, fixtures and types are in place — user story implementation can
now begin.

---

## Phase 3: User Story 1 - Dividir automáticamente una orden en cuentas por producto (Priority: P1) 🎯 MVP

**Goal**: El botón "Dividir cuenta" convierte cada línea de una orden sin pago en una orden
independiente, y elimina la orden original.

**Independent Test**: Enviar una orden con 3 líneas de producto distintas, presionar "Dividir
cuenta", y verificar que el sistema crea una orden independiente por cada línea, cada una
cobrable por separado y visible en la mesa.

### Tests for User Story 1 ⚠️

> Write these tests FIRST; they must FAIL before the T011/T012 implementation exists.

- [X] T006 [P] [US1] Characterization test "split with 3 distinct lines creates 3 orders and
  deletes the original" (Acceptance Scenario 1, quickstart Escenario 1 steps 1-3) in
  `pos-backend/app/characterization_tests/test_orders_item_transfer.py`
- [X] T007 [P] [US1] Characterization test "split on a single-line order is a no-op" (Acceptance
  Scenario 2, quickstart Escenario 1 step 4) in the same file
- [X] T008 [P] [US1] Characterization test "split preserves quantity > 1 as a single line, not
  fractioned by unit" (Acceptance Scenario 3, quickstart Escenario 1 step 5) in the same file
- [X] T009 [P] [US1] Characterization test "split is rejected with 403 when the order already has
  a registered payment, and the original order is left intact" (FR-008, quickstart Escenario 1
  step 6) in the same file

### Implementation for User Story 1

- [X] T010 [US1] Implement `split_order(db, order_id) -> dict` in
  `pos-backend/app/api/v1/orders/item_transfer.py`: no-op (empty `created_orders`) when the order
  has exactly 1 `OrderItem`; otherwise, for each `OrderItem`, create a sibling order via
  `_new_sibling_order` (T003) with that single line (and its
  `OrderItemOption`/`OrderItemTopping` children) reassigned to it, then delete the original order
  — all inside one transaction (FR-001, FR-002, FR-003). Depends on T002, T003, T004.
- [X] T011 [US1] Add `POST /orders/{order_id}/split` endpoint to
  `pos-backend/app/api/v1/orders/router.py` (next to `move_order`/`merge_orders`, ~line 179-205),
  `response_model=SplitOrderResponse`, same auth deps as `move_order`
  (`require_tenant_admin_or_cashier` pattern already used by other order-mutation endpoints),
  calling `item_transfer.split_order`. Depends on T010.
- [X] T012 [US1] Add `splitOrder(orderId: string): Promise<SplitOrderResponse>` to
  `pos-heladeria/src/app/modules/tables/services/table.service.ts` (next to `moveOrder`/
  `mergeOrders`, ~line 166-180), POSTing to `/orders/{orderId}/split`. Depends on T005, T011.
- [X] T013 [US1] Add a `splitOrder(orderId: string)` action to
  `pos-heladeria/src/app/modules/tables/services/pos-terminal.store.ts` (following the
  `async`-method + `reload()` pattern used by `voidPersistedCombo`, ~line 2797): calls
  `table.service.ts`'s `splitOrder`, then `reload()` and clears `selectedOrderId` if the original
  order was deleted. Depends on T012.
- [X] T014 [US1] Add a "Dividir cuenta" button per order tab in
  `pos-heladeria/src/app/modules/tables/components/pos-order-panel.component.ts` (next to the
  order-tabs loop, ~line 260-290): visible only when `!ot.paid` and the tab's order has more than
  1 item (FR-001), calling `store.splitOrder(ot.id)` on click. Depends on T013.

**Checkpoint**: User Story 1 is fully functional and independently testable (SC-001).

---

## Phase 4: User Story 2 - Mover un ítem de una orden a otra dentro de la misma mesa (Priority: P1)

**Goal**: El cajero puede mover un ítem (completo o una cantidad parcial) desde su orden actual
hacia otra orden existente de la misma mesa, con fusión cuando corresponde.

**Independent Test**: Con dos órdenes activas en la misma mesa, mover un ítem de una a la otra y
verificar que aparece en la orden destino con el total recalculado en ambas órdenes.

### Tests for User Story 2 ⚠️

> Write these tests FIRST; they must FAIL before the T020/T021 implementation exists.

- [X] T015 [P] [US2] Characterization test "move full item between two orders recalculates both
  totals" (Acceptance Scenario 1, quickstart Escenario 2 steps 1-3) in
  `pos-backend/app/characterization_tests/test_orders_item_transfer.py`
- [X] T016 [P] [US2] Characterization test "moved item preserves its estado_cocina in the target
  order" (Acceptance Scenario 2, quickstart Escenario 2 step 4) in the same file
- [X] T017 [P] [US2] Characterization test "moving the only remaining item deletes the source
  order" (Acceptance Scenario 3, quickstart Escenario 2 step 8) in the same file
- [X] T018 [P] [US2] Characterization test "partial-quantity move splits the line: source keeps
  the remainder, target gets the moved quantity" (Acceptance Scenario 4, quickstart Escenario 2
  step 5) in the same file
- [X] T019 [P] [US2] Characterization test "partial move that empties the source line removes
  that line" (Acceptance Scenario 5) in the same file
- [X] T020 [P] [US2] Characterization test "move merges into a compatible existing line in the
  target order (same product+variant+price+estado_cocina) and returns merged: true, no duplicate
  line" (Acceptance Scenario 6, quickstart Escenario 2 step 6) in the same file
- [X] T021 [P] [US2] Characterization test "move does NOT merge when estado_cocina differs,
  leaving two independent lines and merged: false" (Acceptance Scenario 7, quickstart Escenario 2
  step 7) in the same file
- [X] T022 [P] [US2] Characterization test "move is rejected with 403 when source or target order
  already has a registered payment, neither order is modified" (FR-008, quickstart Escenario 2
  step 9) in the same file
- [X] T023 [P] [US2] Characterization test "move is rejected with 400 when the target order
  belongs to a different table/session" (FR-009, quickstart Escenario 2 step 10) in the same file
- [X] T024 [P] [US2] Characterization test "move is rejected with 400 when target_order_id ==
  order_id, and when quantity is out of the (0, line.quantity) range" (contract rules) in the same
  file

### Implementation for User Story 2

- [X] T025 [US2] Implement `move_item(db, order_id, item_id, target_order_id, quantity=None) ->
  dict` in `pos-backend/app/api/v1/orders/item_transfer.py`: validates `item_id` belongs to
  `order_id` (404), `_assert_same_table`, `_assert_not_paid` on both orders, `target_order_id !=
  order_id` (400), quantity range `0 < quantity < line.quantity` when explicit and partial (400);
  moves the full/partial quantity decrementing (or deleting, if it reaches 0) the source line,
  then via `_find_mergeable_item` either increments a compatible target line or inserts a new one
  (copying `OrderItemOption`/`OrderItemTopping` 1:1 only in the non-merge case, per data-model.md
  §OrderItemOption), then `_delete_order_if_empty` on the source; returns recalculated totals via
  `service.order_totals`/`build_billing_summary` for both surviving orders (FR-004, FR-005).
  Depends on T002, T003, T004.
- [X] T026 [US2] Add `POST /orders/{order_id}/items/{item_id}/move` endpoint to
  `pos-backend/app/api/v1/orders/router.py` (next to the `/split` endpoint from T011),
  `response_model=MoveItemResponse`, calling `item_transfer.move_item`. Depends on T025.
- [X] T027 [US2] Add `moveItem(orderId: string, itemId: string, targetOrderId: string, quantity?:
  number): Promise<MoveItemResponse>` to
  `pos-heladeria/src/app/modules/tables/services/table.service.ts` (next to `splitOrder` from
  T012), POSTing to `/orders/{orderId}/items/{itemId}/move`. Depends on T005, T026.
- [X] T028 [US2] Add a `moveItem(orderId, itemId, targetOrderId, quantity?)` action to
  `pos-heladeria/src/app/modules/tables/services/pos-terminal.store.ts` (same pattern as T013's
  `splitOrder` action): calls the service method, then `reload()`, clearing `selectedOrderId` if
  the source order was deleted. Depends on T027.
- [X] T029 [US2] Add a "Mover a cuenta…" action per item row in
  `pos-heladeria/src/app/modules/tables/components/pos-order-panel.component.ts`, next to the
  existing per-item actions (e.g. "Anular"): opens a target-order picker (listing the other
  `orderTabs()` of the same table, excluding the current one and any already-paid tabs) and,
  for a line with `quantity > 1`, a quantity input (default = full quantity, range `1..quantity`);
  on confirm calls `store.moveItem(...)`. Reuses the same target-order list used by the "Nueva
  cuenta" button area (~line 260-290) as the source of selectable destinations. Depends on T028.

**Checkpoint**: User Stories 1 AND 2 both work independently (SC-001, SC-003).

---

## Phase 5: User Story 3 - Crear una cuenta nueva a partir de un ítem específico (Priority: P2)

**Goal**: El cajero puede separar un ítem (completo o parcial) de una orden con 2+ ítems en una
cuenta completamente nueva de la misma mesa.

**Independent Test**: En una orden con 2 ítems, seleccionar "crear cuenta nueva" sobre uno de
ellos y verificar que se crea una orden nueva que contiene únicamente ese ítem, mientras el resto
permanece en la orden original.

### Tests for User Story 3 ⚠️

> Write these tests FIRST; they must FAIL before the T034/T035 implementation exists.

- [X] T030 [P] [US3] Characterization test "split-to-new with 2 items creates a new order with
  only the chosen item, original keeps the rest" (Acceptance Scenario 1, quickstart Escenario 3
  steps 1-3) in `pos-backend/app/characterization_tests/test_orders_item_transfer.py`
- [X] T031 [P] [US3] Characterization test "split-to-new that empties the original order deletes
  it" (Acceptance Scenario 2, quickstart Escenario 3 step 4) in the same file
- [X] T032 [P] [US3] Characterization test "partial-quantity split-to-new splits the line between
  original and new order" (Acceptance Scenario 3, quickstart Escenario 3 step 5) in the same file
- [X] T033 [P] [US3] Characterization test "split-to-new is rejected with 400 when the item is the
  only remaining line and the full quantity is requested (no real change); but a partial quantity
  of that same single line IS allowed" (Edge Cases, quickstart Escenario 3 steps 6-7) in the same
  file
- [X] T034 [P] [US3] Characterization test "split-to-new is rejected with 403 when the order
  already has a registered payment" (FR-008) in the same file

### Implementation for User Story 3

- [X] T035 [US3] Implement `split_item_to_new_order(db, order_id, item_id, quantity=None) -> dict`
  in `pos-backend/app/api/v1/orders/item_transfer.py`: validates `item_id` belongs to `order_id`
  (404), `_assert_not_paid`, the "only remaining line + full quantity" guard (400, Edge Cases),
  and the `0 < quantity < line.quantity` range when partial (400); creates a new sibling order via
  `_new_sibling_order` (T003) containing just the (full or partial) quantity, decrementing/deleting
  the source line, then `_delete_order_if_empty` on the source order; returns recalculated totals
  for both orders (FR-006, FR-007). Depends on T002, T003, T004.
- [X] T036 [US3] Add `POST /orders/{order_id}/items/{item_id}/split-to-new` endpoint to
  `pos-backend/app/api/v1/orders/router.py` (next to `/move` from T026),
  `response_model=SplitToNewResponse`, calling `item_transfer.split_item_to_new_order`. Depends
  on T035.
- [X] T037 [US3] Add `splitItemToNewOrder(orderId: string, itemId: string, quantity?: number):
  Promise<SplitItemToNewResponse>` to
  `pos-heladeria/src/app/modules/tables/services/table.service.ts` (next to `moveItem` from T027),
  POSTing to `/orders/{orderId}/items/{itemId}/split-to-new`. Depends on T005, T036.
- [X] T038 [US3] Add a `splitItemToNewOrder(orderId, itemId, quantity?)` action to
  `pos-heladeria/src/app/modules/tables/services/pos-terminal.store.ts` (same pattern as T028):
  calls the service method, then `reload()`, clearing `selectedOrderId` if the source order was
  deleted. Depends on T037.
- [X] T039 [US3] Add a "Nueva cuenta" per-item action in
  `pos-heladeria/src/app/modules/tables/components/pos-order-panel.component.ts`, alongside the
  "Mover a cuenta…" action added in T029: for a line with `quantity > 1`, reuses the same quantity
  input as T029 (default = full quantity); disabled when the item is the only remaining line of
  the order and the quantity is the full amount (Edge Cases, matching the 400 from T035). On
  confirm, calls `store.splitItemToNewOrder(...)`. Depends on T038.

**Checkpoint**: All three user stories are independently functional (SC-001 through SC-004).

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final regression pass across the three new operations and their interaction with
existing move/merge/payment-gate behavior.

- [X] T040 Run `python -m unittest app.characterization_tests.test_orders_tables_advanced -v` and
  `python -m unittest app.characterization_tests.test_orders_payment_gate -v` from `pos-backend`
  to confirm the new endpoints don't regress existing move/merge/payment-gate behavior
  (quickstart "Regresión mínima").
- [X] T041 Run `python -m unittest app.characterization_tests.test_orders_item_transfer -v` from
  `pos-backend` and confirm every scenario in quickstart.md Escenarios 1-3 passes, including the
  direct-DB zero-item cleanup check (SC-002) via a raw `SELECT` against `customer_orders`.
- [ ] T042 Manually walk through quickstart.md Escenarios 1-3 in the running `pos-heladeria`
  terminal de mesas UI against a local `pos-backend` (per memoria `how-to-run-sibling-repo-tests`),
  verifying the "Dividir cuenta", "Mover a cuenta…" and "Nueva cuenta" (per-item) controls end to
  end, including the disabled/no-op states (single-item order, single-remaining-line full-quantity
  split-to-new).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies.
- **Foundational (Phase 2)**: Depends on Setup — BLOCKS all user stories (shared schemas, guard
  helpers, fixtures, and frontend types used by every operation).
- **User Story 1 (Phase 3)**: Depends on Foundational only. No dependency on US2/US3.
- **User Story 2 (Phase 4)**: Depends on Foundational only. Independent of US1/US3 at the data
  layer; shares the per-item action area in `pos-order-panel.component.ts` with US3 (T029/T039
  live side by side, not on each other).
- **User Story 3 (Phase 5)**: Depends on Foundational only; reuses the quantity-input UI piece
  introduced by US2 (T029) for consistency, so T039 is sequenced after T029 even though the
  backend logic (T035) has no runtime dependency on US2.
- **Polish (Phase 6)**: Depends on US1 + US2 + US3 all being complete.

### Within Each User Story

- Tests (T006-T009, T015-T024, T030-T034) MUST be written and FAIL before their story's
  implementation tasks.
- Service function (item_transfer.py) → router endpoint → frontend service method → store action
  → UI control, in that order, within each story.

### Parallel Opportunities

- T003, T004, T005 (Phase 2) can run in parallel once T002 is merged conceptually (T002 only
  touches `schemas.py`; T003/T004/T005 touch different files).
- All test tasks within a story phase (marked [P]) can run in parallel — they add independent
  test methods to the same new file, but as long as each task's diff is additive this is safe to
  parallelize across contributors; a single contributor should still write them in one pass to
  avoid merge noise in one file.
- US1 (Phase 3) and US2 (Phase 4) can be implemented in parallel by different contributors once
  Phase 2 is done — they touch the same files (`item_transfer.py`, `router.py`,
  `table.service.ts`, `pos-terminal.store.ts`, `pos-order-panel.component.ts`) but in
  non-overlapping functions/sections, so coordinate merges rather than parallelizing blindly on a
  single branch.

---

## Parallel Example: Phase 2 (Foundational)

```bash
# After T002 (schemas.py) lands:
Task: "Create item_transfer.py guard helpers (T003)"
Task: "Add make_order_with_items fixture helper (T004)"
Task: "Add frontend request/response interfaces to dining.interface.ts (T005)"
```

## Parallel Example: User Story 2 tests

```bash
Task: "T015 move full item between two orders recalculates both totals"
Task: "T016 moved item preserves estado_cocina"
Task: "T017 moving the only remaining item deletes the source order"
Task: "T018 partial-quantity move splits the line"
Task: "T019 partial move that empties the source line removes that line"
Task: "T020 move merges into a compatible existing line"
Task: "T021 move does not merge when estado_cocina differs"
Task: "T022 move rejected 403 when a payment is registered"
Task: "T023 move rejected 400 for a different table/session"
Task: "T024 move rejected 400 for same-order target or out-of-range quantity"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup.
2. Complete Phase 2: Foundational (CRITICAL — blocks all stories).
3. Complete Phase 3: User Story 1 (Dividir cuenta).
4. **STOP and VALIDATE**: run T006-T009, confirm SC-001 manually.
5. Demo "Dividir cuenta" as the MVP increment.

### Incremental Delivery

1. Setup + Foundational → foundation ready.
2. Add User Story 1 → validate independently → demo (MVP).
3. Add User Story 2 → validate independently → demo.
4. Add User Story 3 → validate independently → demo.
5. Phase 6 Polish once all three stories are in.

### Parallel Team Strategy

With two contributors after Foundational is done:

- Contributor A: User Story 1 (Phase 3), then helps with User Story 3 (Phase 5).
- Contributor B: User Story 2 (Phase 4).
- Coordinate on `pos-order-panel.component.ts` since all three stories touch it — land US1's
  button (T014) first to avoid merge conflicts with US2/US3's per-item actions (T029/T039).
