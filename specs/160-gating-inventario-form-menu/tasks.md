---

description: "Task list for feature 160-gating-inventario-form-menu"
---

# Tasks: Ocultar sección de Inventario en el formulario de carta según el plan

**Input**: Design documents from `/specs/160-gating-inventario-form-menu/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Repository affected**: `../pos-heladeria` (frontend Angular). `pos-backend` is **not** touched by this feature.

**Tests**: Requested implicitly — the feature spec and plan explicitly call out updating
`product-form.component.spec.ts` to assert DOM presence/absence (Principio X, plan.md
"Resultado"). Test tasks are included.

**Organization**: Tasks are grouped by user story (US1/US2/US3 from spec.md) to enable
independent verification of each story. Because all three stories are driven by the same
single `@if (inventarioIncluido())` wrap in `ProductFormComponent`, the core template change
is delivered once (US1) and US2/US3 are mostly verification of the two other directions of
that same condition.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Maps the task to US1, US2 or US3
- All file paths are relative to `../pos-heladeria` unless stated otherwise

---

## Phase 1: Setup

**Purpose**: Prepare the working branch before touching code (Constitution Principio XIV).

- [X] T001 In `../pos-heladeria`, verify/create branch `fix/160-gating-inventario-form-menu` off the current base branch before editing any file in this feature.

---

## Phase 2: Foundational

**Purpose**: Blocking prerequisites for all user stories.

**None required.** `PlanSummaryService.summary()` and the fail-closed `inventarioIncluido()`
computed already exist in `ProductFormComponent` (`src/app/modules/products/pages/product-form.component.ts:669-671`) and are hydrated by `BootstrapService.hydrate()` before the form renders (research.md, Decisión 1). No shared infrastructure needs to be built before user story work can start.

---

## Phase 3: User Story 1 - Plan sin módulo de Inventario: la sección no aparece (Priority: P1) 🎯 MVP

**Goal**: When the tenant's plan does not include the Inventario module, the "3. Inventario"
section and the "Inventario" jump button are fully absent from the DOM — no disabled switch,
no upsell text — while any previously saved inventory configuration for the product/size is
left untouched.

**Independent Test**: With `planSummary` set to `modules.inventario = false`, open the
product/size form and assert the section with id `product-form-inventario`, its heading
"3. Inventario", and the "Inventario" jump button are not present in the rendered DOM.

### Tests for User Story 1 ⚠️

- [X] T002 [P] [US1] In `src/app/modules/products/pages/product-form.component.spec.ts`, replace the existing disabled-switch assertions (around lines 725-753, block "Gating por plan del switch de inventario") with DOM-absence assertions: with `modules.inventario = false`, assert `fixture.nativeElement.querySelector('#product-form-inventario')` is `null`, that `text()` does not contain `'3. Inventario'` nor `'Tu plan actual no incluye el módulo de inventario'`, and that no button with text `'Inventario'` (the jump button in the size table) is rendered.
- [X] T003 [P] [US1] In the same spec file, add/adapt a test for the "existing data survives" edge case: with `modules.inventario = false` and `createEdit('p9', true)` (tracks_inventory already `true`), assert the section is absent from the DOM but `component.draft().tracks_inventory` is still `true` and the product's existing recipe/insumos in `draft()` are unchanged — i.e. hiding the section does not mutate the draft model (FR-005).
- [X] T004 [US1] In the same spec file, update the ordering test around line 1048 ("con tamaños, la tarjeta de tamaños va antes de la de inventario...") and the one around line 1070 to branch on `inventarioIncluido()`: keep the ordering assertions only for the `modules.inventario = true` case, and add a companion assertion that with `modules.inventario = false` the inventory card position lookup returns "not found" instead of a position.

### Implementation for User Story 1

- [X] T005 [US1] In `src/app/modules/products/pages/product-form.component.ts`, wrap the whole "3. Inventario" `<section id="product-form-inventario">...</section>` (currently lines ~302-375) in `@if (inventarioIncluido()) { ... }` with no `@else` branch, so the section (switch, description, insumos content) is entirely omitted when the plan does not include the module — removing the inner `@if (inventarioIncluido()) {...} @else { <span>Tu plan actual no incluye el módulo de inventario.</span> }` block (lines 307-311) since the whole section is now gated.
- [X] T006 [US1] In the same file, wrap the "Inventario" jump button (currently lines ~269-272, `(click)="goToInventory(v.localId)"`) in the same `@if (inventarioIncluido())` so the button is not rendered when the module is not included, avoiding a dangling scroll target.
- [X] T007 [US1] In the same file, now that the section only renders when `inventarioIncluido()` is `true`, remove the now-dead `[disabled]="!inventarioIncluido()"` binding and the `disabled:opacity-40 disabled:cursor-not-allowed` classes on the "Maneja inventario" switch button (currently line ~314-316), since the switch can no longer be reachable while disabled.
- [X] T008 [US1] In the same file, update the doc comment above the section (currently lines 294-301, "Apagado por defecto... Deshabilitado (no oculto) sin el módulo Inventario en el plan (spec 064, FR-011)") to describe the new behavior: hidden (not disabled) without the Inventario module, per this spec (160, FR-002), while existing `tracks_inventory`/recipe data for the product keeps being preserved untouched.

**Checkpoint**: Reopening the form with `modules.inventario = false` shows no trace of the Inventario section or its jump button, and no existing data is altered.

---

## Phase 4: User Story 2 - Plan con módulo de Inventario: la sección se muestra y funciona (Priority: P1)

**Goal**: When the tenant's plan includes the Inventario module, the section is shown fully
functional: switch enabled, insumos configurable and savable without restriction.

**Independent Test**: With `planSummary` set to `modules.inventario = true`, open the
product/size form, assert the section and its enabled switch are present, toggle "Maneja
inventario" on a size, add an insumo, and confirm it is accepted into the draft.

### Tests for User Story 2

- [X] T009 [P] [US2] In `src/app/modules/products/pages/product-form.component.spec.ts`, update the existing "con el módulo Inventario incluido, el switch funciona con normalidad" test (around line 755) to also assert the section (`#product-form-inventario`) and heading `'3. Inventario'` are present in the DOM (not just that the switch is enabled), and that clicking it toggles `draft().tracks_inventory` and reveals the "Insumos fijos" content.
- [X] T010 [US2] In the same spec file, add a regression test that with `modules.inventario = true` and `createEdit('p9', true)` (an existing product with `tracks_inventory = true` and saved insumos), the section renders with the previously saved recipe lines populated and editable — guarding FR-006 (data restored intact when the module comes back).

### Implementation for User Story 2

- [X] T011 [US2] No new implementation — covered by the single `@if (inventarioIncluido())` wrap from T005/T006. Run the T009/T010 tests and confirm they pass against the US1 implementation; if any assertion fails, fix the template from T005-T007 rather than adding US2-specific branching.

**Checkpoint**: Tenants with the module keep the exact same functional section they had before, with no regression, and the section's visibility/enablement comes from the same single condition used to hide it for US1.

---

## Phase 5: User Story 3 - El plan del tenant cambia mientras el formulario está en uso (Priority: P2)

**Goal**: The next time the carta form is opened after the tenant's plan gains or loses the
Inventario module, the section's visibility reflects the current plan state, not a stale one.

**Independent Test**: Toggle the `planSummary` signal used by the component between
`modules.inventario = false` and `true` and confirm the section's presence in the DOM follows
the latest value without needing anything beyond reopening/re-rendering the form.

### Tests for User Story 3

- [X] T012 [US3] In `src/app/modules/products/pages/product-form.component.spec.ts`, add a test that creates the form with `modules.inventario = false` (section absent), then updates the `planSummary` test signal to `modules.inventario = true`, re-runs `fixture.detectChanges()`, and asserts the section now appears with any previously set `tracks_inventory`/recipe data intact; then flips the signal back to `false` and asserts the section disappears again without altering `component.draft()`.

### Implementation for User Story 3

- [X] T013 [US3] No new implementation required — `inventarioIncluido()` already reads `PlanSummaryService.summary()` reactively (research.md, Decisión 1), so the `@if` from T005/T006 reacts automatically to plan changes. Run T012 and confirm it passes; if it does not, investigate whether `PlanSummaryService.summary` is being read through a stale snapshot instead of the live signal in `inventarioIncluido()` and fix that read, without widening scope beyond this computed.

**Checkpoint**: All three user stories pass independently using the same single template condition; no story required diverging logic.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final consistency checks across the whole feature.

- [X] T014 [P] Run the full `product-form.component.spec.ts` suite in `../pos-heladeria` and confirm no previously passing test (outside the ones touched in T002-T004, T009-T010, T012) regressed.
- [X] T015 [P] Grep `../pos-heladeria/src` for any other reference to `#product-form-inventario` or `goToInventory` (e.g. e2e specs, other components) to confirm nothing else assumes the section/button is always rendered.
- [ ] T016 Walk through `quickstart.md` Escenario 1, 2 and 3 manually against a local `pos-backend` + `pos-heladeria` with a real test tenant, confirming DOM behavior and that saved insumos survive a module loss/recovery cycle end-to-end (not just via unit test mocks).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — do first.
- **Foundational (Phase 2)**: None — nothing blocks user stories beyond Setup.
- **User Story 1 (Phase 3)**: Depends on Setup (T001). Delivers the actual template change (T005-T007) that every other story's tests exercise.
- **User Story 2 (Phase 4)**: Depends on Setup; its implementation task (T011) depends on US1's T005-T007 already being in place (same `@if`).
- **User Story 3 (Phase 5)**: Depends on Setup; its implementation task (T013) depends on US1's T005-T007 already being in place (same `@if`, same reactive `inventarioIncluido()`).
- **Polish (Phase 6)**: Depends on Phases 3-5 being complete.

### Within Each User Story

- Tests are written/updated before relying on the implementation passing them.
- T005 (section wrap) must land before T006 (button wrap) can be verified end-to-end, since both use the same section id as a reference point in tests, but T005 and T006 touch disjoint lines and can be coded in either order.
- T007 (remove dead `[disabled]`) depends on T005 being done first (the section must already be gated before the binding is provably dead).

### Parallel Opportunities

- T002 and T003 touch the same spec file but disjoint test blocks — safe to do in sequence by the same author; not meaningfully parallelizable across people without conflicting edits to the same file.
- T014 and T015 are independent verification tasks and can run in parallel with each other.
- US2 (Phase 4) and US3 (Phase 5) tests (T009-T010, T012) can be written in parallel with each other once US1's implementation (T005-T007) exists, since none of them edit the component's non-test code.

---

## Parallel Example: Verification after US1 implementation lands

```bash
# Once T005-T007 are done, these can run concurrently (different test blocks, same file —
# coordinate edits, but the underlying assertions are independent):
Task: "Update switch-enabled test to also assert section presence (T009)"
Task: "Add saved-recipe-restored test (T010)"
Task: "Add plan-change-during-session test (T012)"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (branch).
2. Complete Phase 3: User Story 1 — this alone fixes the reported defect (section shown
   disabled + upsell → section fully hidden) and is independently testable/demoable.
3. **STOP and VALIDATE**: Confirm with `modules.inventario = false` the section and jump
   button are gone and no data was touched.

### Incremental Delivery

1. Phase 1 (Setup) → ready to edit.
2. Phase 3 (US1) → fixes the defect → validate → this is the MVP.
3. Phase 4 (US2) → confirms no regression for tenants with the module → validate.
4. Phase 5 (US3) → confirms reactivity to plan changes → validate.
5. Phase 6 (Polish) → full-suite regression check + manual quickstart walkthrough.

### Notes

- There is deliberately no separate implementation task for US2/US3 beyond T011/T013: per
  plan.md and research.md, all three stories are different observable consequences of the
  same single `@if (inventarioIncluido())` condition, reusing the exact pattern already
  validated in `ReportsPageComponent`. Introducing story-specific branching would violate
  Constitution Principio V (no refactorizaciones oportunistas / no complejidad innecesaria).
- No `pos-backend` tasks exist because this feature has no backend scope (plan.md, Project
  Structure).
