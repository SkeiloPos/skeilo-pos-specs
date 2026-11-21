---

description: "Task list for Gestión de documentos legales de plataforma, plantilla de tenant y consentimiento del cliente final"
---

# Tasks: Gestión de documentos legales de plataforma, plantilla de tenant y consentimiento del cliente final

**Input**: Design documents from `/specs/162-gestion-documentos-legales/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md (all present)

**Tests**: Not explicitly requested as TDD in spec.md. However, `plan.md`'s Constitution Check (Principio X, "Verificación obligatoria") explicitly flags three invariants that MUST have test coverage before this feature is considered done: the draft/published/superseded state machine, template variable validation, and FR-018 atomicity. These are included as dedicated tasks in the Polish phase rather than as per-story TDD, since the spec does not request tests-first for every story.

**Organization**: Tasks are grouped by user story (US1–US4, all Priority P1 per spec.md) to enable independent implementation and testing of each story.

## ⚠️ Business decision required before US4's gate task (T036)

Per `plan.md` Complexity Tracking and `research.md` Decisión 7: FR-016/FR-018 change existing behavior of `POST /cart/sessions` for tenants that today operate without any published legal document. **T035 must be completed and the decision recorded before T036 is implemented.** Do not merge/deploy the gate without that record.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Maps the task to US1–US4
- File paths are relative to repo root; `pos-backend/` and `pos-heladeria/` are sibling repos under `../` from this spec's location, per `plan.md` Project Structure

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Minimal scaffolding before any model/migration work. No new dependencies (per plan.md Constitution Check, Principio IX).

- [X] T001 [P] Create empty package `pos-backend/app/api/v1/legal/__init__.py` (new router package for tenant-panel + public legal routes)
- [X] T002 [P] Add `CONSENT_IP_HASH_SALT` (required, no default) and `RATE_LIMIT_LEGAL_PUBLIC_PER_IP` (default `30`) settings to `pos-backend/app/core/config.py`, reusing the existing `RATE_LIMIT_WINDOW_SECONDS` (research.md Decisión 9, Decisión 5)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The 6 new entities, their migrations, and the shared helpers (variable substitution, markdown rendering, rate-limit bucket) that every user story's routers depend on.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T003 [P] Add `PlatformLegalDocument`, `MasterLegalTemplate`, `TenantAdminPlatformAcceptance` models to `pos-backend/app/core/models.py` (schema `shared`), per data-model.md tables 1–3: `CheckConstraint` on `tipo`/`estado`, partial unique index `UNIQUE (tipo) WHERE estado = 'publicado'` on documents, `UNIQUE (estado) WHERE estado = 'publicado'` on the template, `UNIQUE (user_id, platform_document_id)` on acceptances
- [X] T004 [P] Create `pos-backend/app/models/tenant_legal_profile.py` with `TenantLegalProfile` model (schema `tenant`, data-model.md table 4 — 7 nullable business fields + `updated_at`)
- [X] T005 [P] Create `pos-backend/app/models/tenant_legal_document.py` with `TenantLegalDocument` model (schema `tenant`, data-model.md table 5 — snapshot, cross-schema `master_template_id` column following the `payment_methods.catalog_id` pattern, partial unique index `UNIQUE (estado) WHERE estado = 'publicado'`)
- [X] T006 [P] Create `pos-backend/app/models/client_consent_acceptance.py` with `ClientConsentAcceptance` model (schema `tenant`, data-model.md table 6 — FK to `session_participants.id` and to `tenant_legal_documents.id`, `ip_hash`)
- [X] T007 Register `TenantLegalProfile`, `TenantLegalDocument`, `ClientConsentAcceptance` in `pos-backend/app/models/__init__.py` (depends on T004, T005, T006)
- [X] T008 Create Alembic migration `pos-backend/alembic/versions/<rev>_add_platform_legal_tables.py` for the 3 `shared` tables and their constraints/indexes (depends on T003)
- [X] T009 Create Alembic migration `pos-backend/alembic/versions/<rev>_add_tenant_legal_tables.py` applied via `get_tenant_specific_metadata` to every existing tenant schema, for the 3 `tenant` tables and their indexes (depends on T007)
- [X] T010 [P] Create `pos-backend/app/core/legal_template.py`: `ALLOWED_TEMPLATE_VARIABLES` constant (research.md Decisión 3 / data-model.md table 2), `validate_variables(contenido_markdown) -> list[str]` (unknown placeholders, FR-009), `substitute_variables(contenido_markdown, values) -> str` (literal `re.sub`, escaped substitution, FR-011) — no templating engine
- [X] T011 [P] Create `pos-backend/app/core/legal_markdown.py`: `render_markdown_to_html(markdown_text) -> str` using the existing `markdown-it-py` dependency
- [X] T012 [P] Add a `"legal_public"` bucket to `pos-backend/app/core/rate_limit.py`, reading `RATE_LIMIT_LEGAL_PUBLIC_PER_IP` (depends on T002)

**Checkpoint**: Foundation ready — all 4 user stories can now be implemented (in priority order, since all are P1).

---

## Phase 3: User Story 1 - Super admin publica y versiona los documentos legales de la plataforma (Priority: P1) 🎯 MVP

**Goal**: Super admin can draft, publish and version Privacy Policy / Terms & Conditions; the public can read the current version; tenant admins are blocked from the panel until they accept the current platform documents.

**Independent Test**: Quickstart Escenario 1 (publish → read publicly → publish again → history shows superseded) + Escenario 5 (tenant admin acceptance gate).

### Implementation for User Story 1

- [X] T013 [US1] Create `PlatformLegalDocumentIn`/`PlatformLegalDocumentOut` Pydantic schemas in `pos-backend/app/api/v1/super_admin/legal_schemas.py`
- [X] T014 [US1] Implement platform-document service in `pos-backend/app/api/v1/super_admin/legal_platform_service.py`: create draft (version = last version of that `tipo` + 1), edit draft (409 if `estado != 'borrador'`, FR-003), publish (requires `fecha_vigencia`, 422 if missing; transitions previous `publicado` row of the same `tipo` to `superado` and the new one to `publicado` in the same transaction; catches the partial-unique-index violation as 409 on a publish race, FR-004) (depends on T013, T003)
- [X] T015 [US1] Implement `pos-backend/app/api/v1/super_admin/legal_router.py` under `/api/v1/super-admin/legal`, `SUPER_ADMIN`-only (FR-001, FR-006): `POST /platform-documents`, `PATCH /platform-documents/{id}`, `POST /platform-documents/{id}/publish`, `GET /platform-documents/{tipo}/history` (FR-007) (depends on T014)
- [X] T016 [US1] Register `legal_router` in `pos-backend/app/main.py` (depends on T015)
- [X] T017 [US1] Implement `pos-backend/app/api/v1/legal/public_router.py` with `GET /legal/platform-documents/{tipo}`: unauthenticated, `with_db(None)` on `shared`, `markdown-it-py` render via `legal_markdown`, `ETag`/304 via `http_cache.json_or_304` on `content_hash`, `rate_limit.enforce(bucket="legal_public")`, 404 if no `publicado` row exists yet (FR-005) (depends on T001, T011, T012, T003)
- [X] T018 [US1] Register `public_router` in `pos-backend/app/main.py`; confirm the existing CORS `allow_origin_regex` in `app/main.py` already covers the landing domain (no change expected per research.md Decisión 9) (depends on T017)
- [X] T019 [US1] Implement `pos-backend/app/api/v1/legal/tenant_router.py` under `/api/v1/legal`, authenticated tenant user: `GET /platform-acceptance/pending` (lists platform document types the current user hasn't accepted yet, FR-019), `POST /platform-acceptance/accept` (idempotent on `UNIQUE (user_id, platform_document_id)`) (depends on T001, T003)
- [X] T020 [US1] Register `tenant_router` (`legal` prefix) in `pos-backend/app/main.py` (depends on T019)
- [X] T021 [P] [US1] Frontend: super-admin legal documents pages (list/create/edit draft/publish/history) in `pos-heladeria/src/app/modules/super-admin/pages/legal/`
- [X] T022 [US1] Frontend: panel-blocking acceptance modal in `pos-heladeria/src/app/modules/dashboard/layout/`, shown on first login and whenever `GET /platform-acceptance/pending` is non-empty, calling `POST /platform-acceptance/accept` (depends on T019)

**Checkpoint**: User Story 1 fully functional and independently testable (quickstart Escenarios 1 and 5).

---

## Phase 4: User Story 2 - Super admin administra la plantilla legal maestra para tenants (Priority: P1)

**Goal**: Super admin can draft, validate and publish versions of the master legal template; publishing a new version never changes already-published tenant documents.

**Independent Test**: Quickstart Escenario 2 (publish valid template → reject template with disallowed variable → publishing v2 doesn't change a tenant's already-published document).

### Implementation for User Story 2

- [X] T023 [US2] Add `MasterLegalTemplateIn`/`MasterLegalTemplateOut` schemas to `pos-backend/app/api/v1/super_admin/legal_schemas.py` (depends on T013, same file)
- [X] T024 [US2] Implement master-template service in `pos-backend/app/api/v1/super_admin/legal_platform_service.py`: create draft, edit draft, publish (same state machine as T014; on save, calls `legal_template.validate_variables` and returns 422 with `variables_no_permitidas` listing every disallowed placeholder, FR-009) (depends on T014, T010, same file as T014)
- [X] T025 [US2] Add `POST /master-template`, `PATCH /master-template/{id}`, `POST /master-template/{id}/publish`, `GET /master-template/history` to `pos-backend/app/api/v1/super_admin/legal_router.py` (depends on T024, T015, same file)
- [X] T026 [US2] On master-template publish, for every tenant whose published `TenantLegalDocument.master_template_version` is older than the new version, send the FR-015 email via `mail.send_email` using a new `pos-backend/app/core/mail_templates/plantilla_actualizada.py` template (no change to `notifications/dispatch.py`, per research.md Decisión 10) (depends on T025)
- [X] T027 [P] [US2] Frontend: super-admin master-template editor page (shows `ALLOWED_TEMPLATE_VARIABLES` as hints, renders the 422 `variables_no_permitidas` error) in `pos-heladeria/src/app/modules/super-admin/pages/legal/`

**Checkpoint**: User Story 2 independently functional and testable (quickstart Escenario 2) on top of US1.

---

## Phase 5: User Story 3 - Tenant completa sus datos y publica su propio documento legal (Priority: P1)

**Goal**: Tenant admin fills their legal profile, previews the rendered document, and publishes an immutable snapshot; later profile edits or template updates never change an already-published snapshot.

**Independent Test**: Quickstart Escenario 3 (422 on incomplete profile → complete profile → preview shows substituted variables → publish → snapshot stays the same after a profile edit and after a new template version).

### Implementation for User Story 3

- [X] T028 [US3] Create `TenantLegalProfileOut`/`TenantLegalProfileIn`, `TenantLegalDocumentOut` schemas in `pos-backend/app/api/v1/legal/schemas.py`
- [X] T029 [US3] Implement tenant-profile service (get, put — partial writes allowed) in `pos-backend/app/api/v1/legal/service.py` (depends on T028, T004)
- [X] T030 [US3] ~~Implement tenant-document service in `pos-backend/app/api/v1/legal/service.py`: completeness check of the 7 required profile fields (422 with `campos_faltantes` if incomplete, FR-012)~~ **Superseded by T030a.** `preview()` using `legal_template.substitute_variables` + `legal_markdown.render_markdown_to_html` against the current published master template, persisting nothing (FR-013); `publish()` inserting the immutable snapshot (`content_hash`, `master_template_version`, `published_at`) and transitioning the previous `publicado` snapshot to `superado` in the same transaction (FR-014); `template_update_status()` comparing the snapshot's `master_template_version` against the currently published master template version (FR-015 banner, data-model.md table 5) (depends on T029, T010, T011, T005, T003; same file as T029)
- [X] T030a [US3] Update `pos-backend/app/api/v1/legal/service.py` completeness check to require only `razon_social`, `direccion_legal`, `ciudad`, `correo_contacto`, `telefono_contacto` (422 with `campos_faltantes` if any missing, FR-012); `identificacion_legal` MUST NOT be required. Update `legal_template.substitute_variables` (or the call site in `preview()`/`publish()`) so that when `identificacion_legal` is `NULL`/empty, the line containing that variable in the rendered output is dropped entirely rather than left blank (FR-012a) (depends on T030, T010)
- [X] T031 [US3] Add `GET`/`PUT /tenant-profile`, `GET /tenant-document/preview`, `POST /tenant-document/publish`, `GET /tenant-document/current`, `GET /tenant-document/template-update-status` to `pos-backend/app/api/v1/legal/tenant_router.py` (depends on T030, T019, same file)
- [X] T032 [US3] Implement `GET /legal/tenant-documents/{document_id}` in `pos-backend/app/api/v1/legal/public_router.py`: unauthenticated, `ETag`/304 via `http_cache.json_or_304`, `rate_limit.enforce(bucket="legal_public")`, 404 if the snapshot id doesn't exist (depends on T017, T005, same file)
- [X] T033 [P] [US3] Frontend: tenant legal-profile form + preview + publish flow in `pos-heladeria/src/app/modules/settings/pages/legal/`
- [X] T033a [P] [US3] Frontend: in `pos-heladeria/src/app/modules/settings/pages/legal/`, remove the required-field validator from the "Identificación legal (NIT/RUT)" input so the "Guardar datos"/"Publicar" actions no longer block on it; update any helper text implying it's mandatory (depends on T033, T030a)
- [X] T034 [US3] Frontend: persistent "template update pending" banner in the settings legal-documents section, consuming `GET /tenant-document/template-update-status` (depends on T033, T031)

**Checkpoint**: User Story 3 independently functional and testable (quickstart Escenario 3) on top of US1/US2.

---

## Phase 6: User Story 4 - Cliente final acepta el aviso antes de dejar su nombre en el menú QR (Priority: P1)

**Goal**: The QR menu shows the tenant's current legal notice before the name field; confirming records consent atomically with the client record; tenants without any published document can't open table sessions.

**Independent Test**: Quickstart Escenario 4 (QR payload carries `legal_document` → public tenant-document fetch → `POST /cart/sessions` creates both `SessionParticipant` and `ClientConsentAcceptance` → a tenant with no published document gets 409 and nothing is created).

> ⚠️ **T035 must be done, and its decision recorded, before T036** — see the note at the top of this file and research.md Decisión 7.

### Implementation for User Story 4

- [X] T035 [US4] Record the business decision for the FR-016/FR-018 behavior change (who/when authorizes it, and whether rollout needs a per-tenant feature flag or an announced cutover date) in `specs/000-reconocimiento/registro-de-anomalias.md`, per Constitución Principio II and plan.md Complexity Tracking
- [X] T036 [US4] Add `ip_hash(ip, salt)` helper (sha256 hex, `CONSENT_IP_HASH_SALT`, reusing the IP-extraction logic already in `rate_limit.py::_client_ip`) to `pos-backend/app/core/legal_consent.py` (depends on T002)
- [X] T037 [US4] Modify `pos-backend/app/api/v1/cart/service.py::open_session`: before creating `SessionParticipant`, raise `HTTPException(409, "El negocio aún no tiene un documento legal publicado")` if the tenant has no `TenantLegalDocument` with `estado='publicado'` (FR-016); when one exists, insert a `ClientConsentAcceptance` row (`session_participant_id` = the just-created participant, `tenant_legal_document_id` = the current published snapshot, `ip_hash` from T036) in the same transaction/commit as the `SessionParticipant` insert (FR-018) (depends on T035, T036, T006, T005)
- [X] T038 [US4] Modify `pos-backend/app/api/v1/menu/router.py` (`menu_by_signed_qr`) to add a `legal_document: {id, version} | null` key to the existing response payload, additive only (depends on T005)
- [X] T039 [P] [US4] Frontend: QR menu flow — show the brief notice + link to the tenant's current legal document before the name field, single "continuar" action with no explicit checkbox (FR-017), in the client-facing QR menu module of `pos-heladeria`
- [X] T040 [US4] Frontend: if `legal_document` is `null` in the QR payload, prevent the name form from being shown/submitted (UX-only; the backend 409 from T037 remains the actual control) (depends on T039, T038)

**Checkpoint**: All four user stories independently functional (quickstart Escenario 4) on top of US1/US2/US3.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Coverage explicitly required by plan.md's Constitution Check (Principio X, "Verificación obligatoria"), plus end-to-end validation.

- [X] T041 [P] Service tests for the draft/publicado/superado state machine (platform documents and master template): reject edits to non-draft rows, enforce at-most-one-`publicado`-per-type under a publish race, confirm superseded content stays intact — in `pos-backend/tests/` (deviation: `pos-backend/tests/` doesn't exist in this repo; written as `pos-backend/app/characterization_tests/test_legal_platform_service.py`, following the project's only existing test-module convention — see that file's module docstring)
- [X] T042 [P] Service tests for template variable validation: accept only `ALLOWED_TEMPLATE_VARIABLES`, reject with the exact offending names in `variables_no_permitidas` — in `pos-backend/tests/` (same file/deviation as T041)
- [X] T043 [P] Service test for FR-018 atomicity: a failure inserting `ClientConsentAcceptance` rolls back the `SessionParticipant` insert in the same `open_session` call, and vice versa — in `pos-backend/tests/` (same deviation as T041 — written as `pos-backend/app/characterization_tests/test_cart_legal_consent.py`)
- [X] T044 [P] Service test for the FR-016 gate: `open_session` returns 409 and creates neither `SessionParticipant` nor `ClientConsentAcceptance` when the tenant has no published document — in `pos-backend/tests/` (same file/deviation as T043)
- [X] T045 Run quickstart.md Escenarios 1–5 end-to-end against local Postgres per its Prerrequisitos section (`CONSENT_IP_HASH_SALT` set, migrations applied to `shared` and every tenant schema)
- [X] T046 [P] Angular tests for the new super-admin/settings legal pages and the QR consent-notice flow, following the project's `injectPagedQuery` test-settling pattern where applicable, in `pos-heladeria/src/app/modules/`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Setup — BLOCKS all user stories
- **User Stories (Phase 3–6)**: All depend on Foundational completion. All four stories are Priority P1, but they build on each other's routers/files (US2 extends US1's `super_admin/legal_router.py` and schemas file; US3 extends US1's `legal/tenant_router.py` and `legal/public_router.py`; US4 is standalone on the `cart`/`menu` side but needs US3's `TenantLegalDocument` to exist to gate against) — **implement in order US1 → US2 → US3 → US4**, not in parallel, despite the shared priority
- **Polish (Phase 7)**: Depends on all four user stories being complete

### Within Each User Story

- Models/migrations (Foundational) before services
- Services before routers
- Backend routers before the frontend pages that consume them
- US4's T035 (business decision) before T036/T037 (the actual gate implementation)

### Parallel Opportunities

- T001, T002 (Setup) in parallel
- T003–T006, T010–T012 (Foundational, different files) in parallel; T007 after T004–T006; T008 after T003; T009 after T007
- T021 (US1 frontend) in parallel with the US1 backend tasks once T019/T020 exist for the modal's API contract
- T027 (US2 frontend) in parallel with backend once T025 exists
- T033 (US3 frontend) in parallel with backend once T031/T032 exist
- T039 (US4 frontend) in parallel with T035–T038 once T038's payload shape is known
- T041–T044, T046 (Polish) in parallel with each other

---

## Parallel Example: Foundational Phase

```bash
# Launch all independent model/helper files together:
Task: "Add PlatformLegalDocument, MasterLegalTemplate, TenantAdminPlatformAcceptance models to pos-backend/app/core/models.py"
Task: "Create pos-backend/app/models/tenant_legal_profile.py"
Task: "Create pos-backend/app/models/tenant_legal_document.py"
Task: "Create pos-backend/app/models/client_consent_acceptance.py"
Task: "Create pos-backend/app/core/legal_template.py"
Task: "Create pos-backend/app/core/legal_markdown.py"
Task: "Add a 'legal_public' bucket to pos-backend/app/core/rate_limit.py"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: quickstart.md Escenarios 1 and 5
5. Deploy/demo if ready — the platform already has versioned, publicly readable legal documents and a working tenant-admin acceptance gate

### Incremental Delivery

1. Setup + Foundational → foundation ready
2. US1 → validate (Escenarios 1, 5) → demo: platform documents + admin acceptance gate
3. US2 → validate (Escenario 2) → demo: master template with closed variable list
4. US3 → validate (Escenario 3) → demo: tenant publishes its own legal document
5. US4 → validate (Escenario 4), **after T035's business decision is recorded** → demo: client consent gate live on the QR menu
6. Polish → run full quickstart + required test coverage

Note: unlike a typical spread of priorities, all four stories here are P1 and have a strict build order (US1 → US2 → US3 → US4) because each one's routers/files extend the previous one's — "independently testable" (per each story's Independent Test) does not mean "independently buildable in any order."

### Parallel Team Strategy

Given the forced story order above, true cross-story parallelism is limited to frontend-vs-backend within a story (e.g., one developer on `legal_router.py`/`service.py` while another builds the Angular page against the documented contract) rather than multiple developers on different stories simultaneously.
