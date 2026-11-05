---

description: "Task list for feature implementation"
---

# Tasks: Rediseño del listado de la Carta del menú

**Input**: Design documents from `/specs/152-rediseno-listado-carta-menu/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/get-products.md, quickstart.md

**Tests**: Backend characterization tests are explicitly requested (quickstart.md, Constitution Principio III). Frontend `ng test` specs are also explicitly named in quickstart.md as minimum automated verification, so both are included.

**Organization**: Tasks are grouped by user story (US1 = tarjetas móvil/tablet + tabla intacta, US2 = filtro de categoría, US3 = precio resumido), per spec.md priorities.

**Repos involved**: `pos-backend` (FastAPI) and `pos-heladeria` (Angular), both siblings of this `pos-specs` repo under `/home/deimer/Documents/projects/inventario/`. Branch `feat/152-menu-list-redesign` must exist in both repos before touching code (plan.md, Principio XIV/XV).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1, US2, US3 — maps to spec.md user stories
- File paths are relative to `/home/deimer/Documents/projects/inventario/<repo>/`

## Path Conventions

- Backend: `pos-backend/app/api/v1/products/{router,schemas,service}.py`, `pos-backend/app/characterization_tests/`
- Frontend: `pos-heladeria/src/app/modules/products/{pages,components,services,interfaces}/`

---

## Phase 1: Setup

**Purpose**: Ensure both repos are on the feature branch before any code change.

- [X] T001 Create/checkout branch `feat/152-menu-list-redesign` in `pos-backend` (from its current default branch), confirm `git status` is clean before starting.
- [X] T002 Create/checkout branch `feat/152-menu-list-redesign` in `pos-heladeria` (from its current default branch), confirm `git status` is clean before starting.

**Checkpoint**: Both repos on the feature branch, working trees clean.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Backend contract changes that every user story (card view, table view, filter, price) depends on — `ProductListResponse` shape and the `list_query` price computation must exist before either frontend view can render price/category correctly.

**⚠️ CRITICAL**: No frontend work can be considered "done" against the real contract until this phase's backend tasks land, though UI scaffolding can proceed against mocked data in parallel per story.

### Backend: response shape & price computation (data-model.md, research.md D2/D4)

- [X] T003 In `pos-backend/app/api/v1/products/schemas.py`, change `ProductListResponse` from `class ProductListResponse(ProductResponse): pass` to an explicit schema declaring exactly: `id, category_id, category_name, name, image_url, preparation_type, active, available, available_changed_at, created_at, updated_at, price_display, price_from` (per data-model.md table and research.md D4). Do not include `code, description, tracks_inventory, is_topping, visible_en_qr, available_changed_by_name`.
- [X] T004 In `pos-backend/app/api/v1/products/service.py`, in the function building the listing query (`list_query` / equivalent), add `selectinload(Product.variants)` to the existing query and compute `price_display`/`price_from` in Python per the rule in data-model.md: filter variants to `active=True AND price > 0`; 0 matches → `price_display=None, price_from=False`; 1 match → that price, `price_from=False`; ≥2 matches → `min(price)`, `price_from=True`. Attach these two values onto each row before serialization into `ProductListResponse`.
- [X] T005 [P] In `pos-backend/app/api/v1/products/router.py`, add optional query param `category_id: UUID | None = None` to the `GET /products` endpoint signature and pass it through to the service/`list_query` call.
- [X] T006 In `pos-backend/app/api/v1/products/service.py`, apply `Product.category_id == category_id` as an additional `AND` filter in `list_query` when `category_id` is provided, alongside the existing `active`, `available`, `search`, `is_topping` filters (contracts/get-products.md, research.md D3). Do not change the semantics of existing filters.

**Checkpoint**: `GET /products` now accepts `category_id`, returns the trimmed `ProductListResponse` with `price_display`/`price_from`, without N+1 queries. Existing filters/pagination behavior unchanged.

---

## Phase 3: User Story 1 - Explorar la carta del menú desde el móvil (Priority: P1) 🎯 MVP

**Goal**: Products render as cards (image/placeholder, name, category, price, status) on viewports < 1024px, and the existing table (now with price/created/updated columns) is preserved unchanged on ≥ 1024px, with no loss of filters/pagination across the breakpoint.

**Independent Test**: Open the module at 375px viewport → cards with no horizontal scroll; resize to 1200px → table appears with same columns/actions plus new ones, search term and current page preserved.

### Tests for User Story 1

- [X] T007 [P] [US1] Add backend characterization test in `pos-backend/app/characterization_tests/test_product_list_pricing_and_category_filter.py` asserting `GET /products` response items contain exactly the trimmed `ProductListResponse` field set (no `code, description, tracks_inventory, is_topping, visible_en_qr, available_changed_by_name`) and that `created_at`/`updated_at` are present, for a basic product fixture (covers FR-008/SC-004, D4).
- [X] T008 [P] [US1] Update/extend `pos-heladeria/src/app/modules/products/pages/products-page.component.spec.ts`: add a test verifying the template renders the card list (not the table) when the component's responsive state indicates `< 1024px`, and renders the table when `≥ 1024px`, using the same `ProductService` data for both (no remount/state loss).

### Implementation for User Story 1

- [X] T009 [US1] In `pos-heladeria/src/app/modules/products/interfaces/product.interface.ts`, add `price_display: string | null` and `price_from: boolean` to the `Product` interface, and remove any interface fields that no longer appear in the trimmed backend response (per data-model.md "Campos excluidos"), keeping fields still used elsewhere in the module intact.
- [X] T010 [US1] Create `pos-heladeria/src/app/modules/products/components/product-list-card.component.ts` (standalone component, per research.md D5): renders image (`image_url`) or "Sin imagen" placeholder using `app-mi-icon name="image-off"` (same icon as `products-page.component.ts:191`), product `name`, `category_name` (fallback "Sin categoría" when `null`), price text (`price_display` formatted via the existing money pipe in `pos-heladeria/src/app/shared/money.pipe.ts`, prefixed "Desde " when `price_from` is true, or "Sin precio" when `price_display` is `null`), and Activo/Inactivo + Disponible/Agotado status badges, matching the layout of `design/SkeiloPOS App - Carta del menu offline.html`.
- [X] T011 [US1] In `pos-heladeria/src/app/modules/products/pages/products-page.component.ts`, update the template to render `<app-product-list-card>` in a grid for `< 1024px` (Tailwind `lg:hidden` block) and keep the existing `<table>` markup under `hidden lg:block` (Tailwind `lg` breakpoint, per research.md D1), with no change to the component's filter/pagination state — both views must read from the same signals/observables.
- [X] T012 [US1] In the same `products-page.component.ts` table template, add "Precio" column (same price text rule as the card) and "Creación"/"Actualización" columns (`created_at`/`updated_at`, formatted with the module's existing date formatting pattern), matching quickstart.md Escenario 1 step 4.
- [X] T013 [US1] In `products-page.component.ts` (table template) and the new `product-list-card.component.ts`, ensure the "Sin imagen" placeholder (`app-mi-icon name="image-off"`) renders whenever `image_url` is `null`, in both views (FR-007).
- [X] T014 [US1] In `pos-heladeria/src/app/modules/products/services/product.service.ts`, confirm/update the method backing the listing page so it maps the new `price_display`/`price_from` fields through unchanged request/response handling (no new params needed for this story — category filter param added in US2).

**Checkpoint**: User Story 1 fully functional and independently testable — cards on mobile/tablet, table (with new columns) on desktop, breakpoint switch preserves filters/pagination, "Sin imagen" placeholder works in both views.

---

## Phase 4: User Story 2 - Filtrar productos por categoría (Priority: P2)

**Goal**: A category selector (chip-style, with an "Todas las categorías" option) filters the listing server-side, combined via AND with existing filters, in both card and table views.

**Independent Test**: Select a category → listing (cards or table) shows only that category's products, combined correctly with an active name search; clearing the filter restores all categories while keeping other active filters; a non-matching combination shows the existing "sin resultados" message.

### Tests for User Story 2

- [X] T015 [P] [US2] Extend `pos-backend/app/characterization_tests/test_product_list_pricing_and_category_filter.py` with cases for `category_id` filtering: (a) `category_id` set → only matching products returned; (b) `category_id` combined with `search`/`active`/`available` → AND semantics; (c) `category_id` omitted → behavior identical to current (no regression), per contracts/get-products.md.
- [X] T016 [P] [US2] Update `pos-heladeria/src/app/modules/products/services/product.service.spec.ts` to assert the products-listing request includes `category_id` in query params when a category filter is active, and omits it when "Todas las categorías" is selected.

### Implementation for User Story 2

- [X] T017 [US2] In `pos-heladeria/src/app/modules/products/services/product.service.ts`, add an optional `categoryId` parameter to the method that calls `GET /products`, serialized as the `category_id` query param only when set (contracts/get-products.md).
- [X] T018 [US2] In `pos-heladeria/src/app/modules/products/pages/products-page.component.ts`, add category filter state (selected category id or "all") combined with existing search/active/available filters when triggering `product.service.ts` loads, resetting pagination to page 1 on category change (consistent with how existing filters reset pagination today).
- [X] T019 [US2] In `products-page.component.ts` template, add a category selector (chip/select, per design reference) populated from `pos-heladeria/src/app/modules/categories/services/category.service.ts` (`GET /categories`), with an explicit "Todas las categorías" option that clears the `category_id` filter.
- [X] T020 [US2] In `products-page.component.ts`, ensure the existing "sin resultados" empty-state message is shown (not an unexplained blank list) when the category + other filters combination returns zero items, in both card and table views (FR-010).

**Checkpoint**: User Stories 1 AND 2 both work independently — category filter combines correctly with existing filters in both views.

---

## Phase 5: User Story 3 - Ver el precio del producto directamente en el listado (Priority: P2)

**Goal**: Each product in the listing shows its exact price (single priced variant), "Desde $X" (multiple priced variants, lowest shown), or "Sin precio" (no priced variant) — without opening product detail.

**Independent Test**: For a product with one priced variant, a product with several priced variants, and a product with none, confirm the listing (card or table) shows the exact price, "Desde $X", and "Sin precio" respectively, matching a manual check against `product_variants`/`GET /products/{id}`.

> Note: the backend computation (T004) and the card/table price rendering (T010/T012) were already built in Phase 2/3 because US1's table and card views needed a price column/line to match the reference design. This phase adds the targeted verification that the price rule itself (not just its presence in the layout) is correct for all three cases.

### Tests for User Story 3

- [X] T021 [P] [US3] Extend `pos-backend/app/characterization_tests/test_product_list_pricing_and_category_filter.py` with three fixtures covering data-model.md's price rule exactly: (a) one active variant with `price > 0` → `price_display` equals that price, `price_from=false`; (b) two active variants with distinct `price > 0` → `price_display` equals the minimum, `price_from=true`; (c) no active variant with `price > 0` (either all inactive or all `price = 0`) → `price_display=null`, `price_from=false`.
- [X] T022 [P] [US3] Add a test in `pos-heladeria/src/app/modules/products/components/product-list-card.component.spec.ts` (new spec file) asserting the card renders "$X" when `price_from=false` and `price_display` is set, "Desde $X" when `price_from=true`, and "Sin precio" when `price_display` is `null`.

### Implementation for User Story 3

- [X] T023 [US3] Verify (and adjust if needed) that `products-page.component.ts`'s table "Precio" column (added in T012) applies the same three-case formatting as the card component — single source of truth for the "Desde "/"Sin precio" text, e.g. a shared pipe or helper function in `pos-heladeria/src/app/modules/products/` reused by both `product-list-card.component.ts` and the table template.

**Checkpoint**: All three user stories independently functional — mobile/tablet cards + desktop table (US1), category filter (US2), and verified price display rule in both views (US3).

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation against quickstart.md and regression safety across both repos.

- [X] T024 [P] Run full backend characterization suite `pytest app/characterization_tests/` in `pos-backend` to confirm no regressions beyond the new/updated test file (quickstart.md "Verificación automatizada mínima").
- [X] T025 [P] Run `ng test` in `pos-heladeria` for `products-page.component.spec.ts` and `product-list-card.component.spec.ts` to confirm the full frontend suite passes (per [[how-to-run-sibling-repo-tests]] memory: diff by file against baseline, not full-suite count, since the frontend baseline is flaky).
- [ ] T026 Manually execute quickstart.md Escenario 5 (role preservation): log in as Cajero and confirm only availability toggling is available in both views; log in as Admin and confirm edit/activate/export/import actions are unchanged (FR-011).
- [ ] T027 Manually execute quickstart.md Escenario 4 (payload inspection): confirm via browser devtools that `GET /products` responses never include `description, tracks_inventory, is_topping, visible_en_qr, available_changed_by_name`, and that every field present is rendered somewhere in the card or table (FR-008/SC-004).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — run first in both repos.
- **Foundational (Phase 2)**: Depends on Setup. Blocks all user stories — the trimmed `ProductListResponse` and price computation (T003-T006) must exist before frontend tasks can consume real data, though frontend component scaffolding (T010) can be written against the interface changes (T009) in parallel.
- **User Story 1 (Phase 3)**: Depends on Foundational. No dependency on US2/US3.
- **User Story 2 (Phase 4)**: Depends on Foundational. Builds on US1's `products-page.component.ts` template (T011) existing, but is independently testable once present.
- **User Story 3 (Phase 5)**: Depends on Foundational and on the price rendering added during US1 (T010/T012) — this phase is primarily verification plus a shared-formatting cleanup (T023).
- **Polish (Phase 6)**: Depends on US1, US2, US3 all complete.

### Within Each User Story

- Tests before/alongside implementation (characterization tests written first where feasible, per Constitution Principio III).
- Backend schema/service changes (Phase 2) before any frontend task that reads `price_display`/`price_from`/`category_id`.
- Interface update (T009) before component creation (T010) before page-template wiring (T011-T013).

### Parallel Opportunities

- T001/T002 (branch creation in each repo) can run in parallel.
- T005 (router param) can run in parallel with T003/T004 (schema/service) since it touches a different file, though T006 (filter logic) depends on T005's param existing in the function signature it calls.
- T007/T008 (US1 tests) in parallel — different repos/files.
- T015/T016 (US2 tests) in parallel — different repos/files.
- T021/T022 (US3 tests) in parallel — different repos/files.
- T024/T025 (Polish test runs) in parallel — different repos.

---

## Parallel Example: User Story 1

```bash
# Backend and frontend US1 tests, different repos — run together:
Task: "Backend characterization test for trimmed ProductListResponse fields in pos-backend/app/characterization_tests/test_product_list_pricing_and_category_filter.py"
Task: "Frontend spec for card/table breakpoint switch in pos-heladeria/src/app/modules/products/pages/products-page.component.spec.ts"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (branches in both repos).
2. Complete Phase 2: Foundational (backend contract: trimmed response + price computation + `category_id` param, even though US1 doesn't filter by it yet — it's cheapest to land once).
3. Complete Phase 3: User Story 1 (cards + table + breakpoint + price/date columns).
4. **STOP and VALIDATE**: Run quickstart.md Escenario 1, confirm mobile cards / desktop table / breakpoint preserves state.
5. Deploy/demo if ready — this alone delivers the core "unusable table on mobile" fix.

### Incremental Delivery

1. Setup + Foundational → backend contract ready for both repos to build against.
2. Add User Story 1 → validate independently (Escenario 1) → MVP.
3. Add User Story 2 → validate independently (Escenario 2).
4. Add User Story 3 → validate independently (Escenario 3) — mostly already built in US1, this phase confirms correctness.
5. Polish → full regression pass (Escenarios 4-5, full test suites) before considering the feature done.

---

## Notes

- [P] tasks touch different files with no completed-task dependency between them.
- [Story] label maps each task to US1/US2/US3 for traceability back to spec.md.
- Commit only on explicit user request, in English, no AI attribution (plan.md, Principio XIV/XV; CLAUDE.md attribution rules apply to Claude Code's own commits/PRs, not to this project's own commit convention).
- No new DB tables/columns — all "model" work here is response-shape and query-filter changes, not migrations (data-model.md).
