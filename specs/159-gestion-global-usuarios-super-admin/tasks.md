---

description: "Task list for feature implementation"
---

# Tasks: Gestión global de usuarios en el panel Super Admin

**Input**: Design documents from `/specs/159-gestion-global-usuarios-super-admin/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/super-admin-users-api.md, quickstart.md

**Repos**: la implementación ocurre en dos repositorios hermanos de `pos-specs`:
`../pos-backend` (FastAPI) y `../pos-heladeria` (Angular). Todas las rutas de archivo en
este documento son relativas a esos repos, tal como las usa `plan.md`.

**Tests**: se incluyen tareas de test porque `plan.md`/`research.md`/`quickstart.md` las
piden explícitamente ("Verificación automatizada", characterization tests protegidos,
Principio X de la constitución). No son estrictamente TDD-first salvo donde se indique.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Puede ejecutarse en paralelo (archivos distintos, sin dependencias pendientes)
- **[Story]**: User story a la que pertenece (US1..US8)

## Orden de fases

Las fases siguen la prioridad del spec (P1 → P2 → P3) **excepto** donde una dependencia
técnica lo impide: la parte de User Story 8 que agrega el enlace de "Auditoría y actividad"
al sidebar solo puede construirse después de que exista la página de Auditoría (User Story
7, P2), así que esa sub-tarea se ubica al final aunque US8 sea P1. El resto de US8
(verificar que Tenants/Métodos de pago/Planes siguen intactos) no tiene esa dependencia y
puede validarse desde el inicio.

---

## Phase 1: Setup

**Purpose**: preparar las ramas de trabajo en los dos repos de implementación (Principio XIV
de la constitución).

- [X] T001 Create branch `feat/159-gestion-global-usuarios-super-admin` in `../pos-backend` from its up-to-date default branch
- [X] T002 [P] Create branch `feat/159-gestion-global-usuarios-super-admin` in `../pos-heladeria` from its up-to-date default branch

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: expansión aditiva del modelo de datos (research.md Decisiones 1-2, 5-6, 9) que
casi todas las user stories necesitan para existir: estado enriquecido de usuario, estado de
tenant, membresía multi-negocio, sesiones activas y bitácora de auditoría.

**⚠️ CRITICAL**: ninguna user story puede implementarse (ni siquiera US1, el listado) hasta
que esta fase esté completa, porque el listado ya depende de `status` y de
`tenant_memberships`.

- [X] T003 Add `status` (enum), `activated_at`, `suspended_at`, `suspended_reason`, `security_blocked_at`, `failed_login_attempts`, `anonymized_at` columns to `User` in `../pos-backend/app/core/models.py`
- [X] T004 Create Alembic migration for the `User` columns of T003, with `server_default` seguro y backfill (`active=True`→`status='active'`, `active=False`→`status='suspended'`, `activated_at=created_at`) in `../pos-backend/alembic/versions/`
- [X] T005 [P] Add `status` (enum: `active`, `suspended`), `server_default='active'`, column to `Tenant` in `../pos-backend/app/core/models.py`
- [X] T006 Create Alembic migration for the `Tenant.status` column of T005 in `../pos-backend/alembic/versions/`
- [X] T007 [P] Create `TenantMembership` model (`id`, `user_id` FK CASCADE, `tenant_id` FK CASCADE, `role_id` FK, `created_at`, unique `(user_id, tenant_id)`) in `../pos-backend/app/models/tenant_membership.py`
- [X] T008 Create Alembic migration for `shared.tenant_memberships` + backfill one membership row per existing `User` with `tenant_id IS NOT NULL` in `../pos-backend/alembic/versions/` (depends on T007)
- [X] T009 [P] Create `UserSession` model (`id`=`jti`, `user_id` FK CASCADE, `device_label`, `browser`, `ip_address`, `created_at`, `last_seen_at`, `revoked_at` nullable) in `../pos-backend/app/models/user_session.py`
- [X] T010 Create Alembic migration for `shared.user_sessions` (sin backfill, tabla nueva) in `../pos-backend/alembic/versions/` (depends on T009)
- [X] T011 [P] Create `AdminAuditLog` model (`id`, `actor_type` enum, `actor_user_id` referencia blanda, `actor_name_snapshot`, `affected_user_id` referencia blanda, `affected_user_email_snapshot`, `tenant_id` referencia blanda, `action`, `detail` JSONB, `ip_address`, `created_at`) in `../pos-backend/app/models/admin_audit_log.py`
- [X] T012 Create Alembic migration for `shared.admin_audit_logs` with indexes on `(created_at)`, `(affected_user_id)`, `(actor_user_id)`, `(tenant_id)` in `../pos-backend/alembic/versions/` (depends on T011)
- [X] T013 Create `AdminAuditLogService.record(actor_type, actor_user, affected_user, tenant_id, action, detail, ip_address)` helper used by every administrative action in `../pos-backend/app/services/admin_audit_log_service.py` (depends on T011)
- [X] T014 [P] Create base Pydantic schemas (`UserStatus` enum, `UserListItem`, `UserDetail`, `MembershipItem`, `UserSessionItem`, `AdminAuditLogItem`) for the `/super-admin` users/audit API in `../pos-backend/app/api/v1/super_admin/schemas.py`
- [X] T015 Run `alembic upgrade head` against local Postgres and the full `app/characterization_tests/` suite to confirm no regression before building on top of these migrations, in `../pos-backend`
- [X] T016 [P] Extend `AdminUser`/create `UserStatus` type in the frontend interface (`status`, `memberships`, `sessionsCount`, `isInactiveRecently`) in `../pos-heladeria/src/app/modules/super-admin/interfaces/admin-user.interface.ts`

**Checkpoint**: migraciones aplicadas, characterization tests en verde, modelos/schemas base
listos — las user stories pueden empezar.

---

## Phase 3: User Story 1 - Consultar el listado centralizado de usuarios (Priority: P1) 🎯 MVP

**Goal**: tabla centralizada de todos los usuarios de la plataforma con búsqueda, filtros
combinables, orden y paginación (FR-001 a FR-007).

**Independent Test**: abrir el módulo con datos de varios negocios/roles y verificar que la
tabla muestra todas las columnas requeridas, que búsqueda/filtros/orden/paginación funcionan
y se combinan, y que usuarios multi-negocio o sin negocio se identifican visualmente.

### Implementation for User Story 1

- [X] T017 [US1] Extend `GET /super-admin/users` query params (`search`, `status`, `role_id`, `plan_id`, `registered_from`, `registered_to`, `sort_by`, `sort_dir`) in `../pos-backend/app/api/v1/super_admin/router.py`
- [X] T018 [US1] Implement unified paginated projection joining `User` (with `status`, `tenant_memberships` count/preview, principal `plan_name`, `last_login_at`, `is_inactive_recently`) and `UserInvitation` (`status='invitation_pending'`) rows, sorted/filtered/searched per T017, in `../pos-backend/app/api/v1/super_admin/router.py` (depends on T017, T003, T007)
- [X] T019 [P] [US1] Add indexes on `users(status, role_id, created_at, last_login_at)` via Alembic migration to support SC-010 in `../pos-backend/alembic/versions/`
- [X] T020 [US1] Add empty-state distinction in the response/service layer: `total=0` sin filtros ⇒ "sin datos de plataforma", `total=0` con filtros/búsqueda ⇒ "sin resultados" (FR-041) in `../pos-backend/app/api/v1/super_admin/router.py`
- [X] T021 [P] [US1] Write backend tests for the extended listing endpoint (search, combinable filters, sort, pagination, invitation rows, both empty states) in `../pos-backend/app/characterization_tests/test_super_admin_users_list.py`
- [X] T022 [P] [US1] Update `SuperAdminUsersService.getUsers()` to send the new query params and parse `UserListItem` fields in `../pos-heladeria/src/app/modules/super-admin/services/super-admin-users.service.ts`
- [X] T023 [US1] Rebuild `super-admin-users-page.component` table (nombre, correo, rol, negocio, plan, estado, último acceso) with "+N" badge for multi-tenant users and an explicit "sin negocio" indicator in `../pos-heladeria/src/app/modules/super-admin/pages/super-admin-users-page.component.ts` (depends on T022)
- [X] T024 [US1] Add debounced search input wired to the `search` param, updating the table without a full page reload in `../pos-heladeria/src/app/modules/super-admin/pages/super-admin-users-page.component.ts` (depends on T023)
- [X] T025 [US1] Add combinable filters (estado, rol, plan, rango de fecha de registro) plus a single "limpiar filtros" action in `../pos-heladeria/src/app/modules/super-admin/pages/super-admin-users-page.component.ts` (depends on T023)
- [X] T026 [US1] Add sortable column headers (nombre, último acceso, fecha de registro) that preserve active filters/search while reordering in `../pos-heladeria/src/app/modules/super-admin/pages/super-admin-users-page.component.ts` (depends on T023)
- [X] T027 [US1] Add pagination control that preserves filters/search/sort across pages in `../pos-heladeria/src/app/modules/super-admin/pages/super-admin-users-page.component.ts` (depends on T023)
- [X] T028 [US1] Add loading placeholder, error-with-retry, "sin datos" and "sin resultados" states to the listing page in `../pos-heladeria/src/app/modules/super-admin/pages/super-admin-users-page.component.ts` (depends on T023)
- [X] T029 [P] [US1] Write Angular tests for the listing page (search, filters combined, sort, pagination, multi-tenant badge, empty states) in `../pos-heladeria/src/app/modules/super-admin/pages/super-admin-users-page.component.spec.ts`

**Checkpoint**: el listado centralizado es completamente funcional y verificable de forma
independiente (MVP base).

---

## Phase 4: User Story 2 - Consultar los indicadores generales de usuarios (Priority: P1)

**Goal**: cuatro indicadores resumidos (total, activos, suspendidos, nuevos del mes) que se
mantienen consistentes tras acciones administrativas (FR-008/FR-009).

**Independent Test**: cargar el módulo con usuarios de distintos estados/fechas y verificar
que los cuatro indicadores son correctos y se actualizan tras suspender/reactivar un usuario.

### Implementation for User Story 2

- [X] T030 [P] [US2] Implement `GET /super-admin/users/stats` (`total`, `active`, `suspended`, `new_this_month` sobre el mes calendario en curso, zona horaria de la plataforma) in `../pos-backend/app/api/v1/super_admin/router.py` (depends on T003)
- [X] T031 [P] [US2] Write backend test for `/super-admin/users/stats` counts, including the current-month boundary case in `../pos-backend/app/characterization_tests/test_super_admin_users_stats.py`
- [X] T032 [US2] Add `getStats()` to `SuperAdminUsersService` in `../pos-heladeria/src/app/modules/super-admin/services/super-admin-users.service.ts` (depends on T030)
- [X] T033 [US2] Add a 4-card indicators widget to `super-admin-users-page.component` that re-fetches after a suspend/reactivate action completes, without a manual page reload in `../pos-heladeria/src/app/modules/super-admin/pages/super-admin-users-page.component.ts` (depends on T023, T032)
- [X] T034 [P] [US2] Write Angular test verifying the indicators refresh after a suspend action in `../pos-heladeria/src/app/modules/super-admin/pages/super-admin-users-page.component.spec.ts`

**Checkpoint**: listado + indicadores (US1+US2) conforman el MVP visible del módulo.

---

## Phase 5: User Story 3 - Consultar la ficha individual de un usuario (Priority: P1)

**Goal**: ficha con pestañas de información general, actividad, seguridad y negocios
asociados (FR-010 a FR-015).

**Independent Test**: abrir la ficha de un usuario desde el listado y navegar entre sus
cuatro pestañas, verificando datos correctos por pestaña, incluyendo un usuario con varios
negocios/roles y los estados vacíos de seguridad/negocios.

### Implementation for User Story 3

- [X] T035 [P] [US3] Implement `GET /super-admin/users/{user_id}` (nombre, correo, fecha de registro, `status`, `last_login_at`; 404 si no existe) in `../pos-backend/app/api/v1/super_admin/users_router.py`
- [X] T036 [P] [US3] Implement `GET /super-admin/users/{user_id}/activity?page=&size=` merging login/password events with `AdminAuditLog` filtered by `affected_user_id`, most-recent-first, showing who made each administrative change in `../pos-backend/app/api/v1/super_admin/users_router.py` (depends on T011)
- [X] T037 [P] [US3] Implement `GET /super-admin/users/{user_id}/memberships` (`tenant_id`, `tenant_name`, `tenant_status`, `plan_name`, `role_name`, `member_since`) in `../pos-backend/app/api/v1/super_admin/users_router.py` (depends on T007, T005)
- [X] T038 [P] [US3] Implement `GET /super-admin/users/{user_id}/security` (`active_sessions`, `failed_login_attempts`, `security_blocked_at`) in `../pos-backend/app/api/v1/super_admin/users_router.py` (depends on T009)
- [X] T039 [US3] Register `users_router` under the `/super-admin` prefix (reusing the already-applied `get_current_super_admin` dependency) in `../pos-backend/app/api/v1/super_admin/router.py` (depends on T035-T038)
- [X] T040 [P] [US3] Write backend tests for the four ficha endpoints, including empty states (no memberships, no active sessions) and the multi-membership case in `../pos-backend/app/characterization_tests/test_super_admin_user_detail.py`
- [X] T041 [P] [US3] Create `SuperAdminUserDetailService` (`getUser`, `getActivity`, `getMemberships`, `getSecurity`) in `../pos-heladeria/src/app/modules/super-admin/services/super-admin-user-detail.service.ts`
- [X] T042 [US3] Create `super-admin-user-detail-page.component` with tabbed navigation (información general, actividad, seguridad, negocios asociados) and loading/error states in `../pos-heladeria/src/app/modules/super-admin/pages/super-admin-user-detail-page.component.ts` (depends on T041)
- [X] T043 [US3] Implement the "información general" tab (datos personales, correo, fecha de registro, estado, último acceso) in `../pos-heladeria/src/app/modules/super-admin/pages/super-admin-user-detail-page.component.ts` (depends on T042)
- [X] T044 [US3] Implement the "actividad" tab (historial cronológico, autor de cada cambio administrativo) in `../pos-heladeria/src/app/modules/super-admin/pages/super-admin-user-detail-page.component.ts` (depends on T042)
- [X] T045 [US3] Create `user-security-tab.component` showing active sessions (dispositivo/navegador/IP) and a failed-attempts summary, with an empty state and a disabled revoke control when there are no active sessions in `../pos-heladeria/src/app/modules/super-admin/components/user-security-tab.component.ts` (depends on T042)
- [X] T046 [US3] Implement the "negocios asociados" tab (negocio, plan, rol por membresía) with an empty state offering "asignar negocio" in `../pos-heladeria/src/app/modules/super-admin/pages/super-admin-user-detail-page.component.ts` (depends on T042)
- [X] T047 [US3] Wire row click in the listing page to navigate to the user detail page in `../pos-heladeria/src/app/modules/super-admin/pages/super-admin-users-page.component.ts` (depends on T023, T042)
- [X] T048 [US3] Add the user detail route in `../pos-heladeria/src/app/modules/super-admin/routes.ts` (depends on T042)
- [X] T049 [P] [US3] Write Angular tests for the detail page's four tabs, the multi-membership case and both empty states (negocios, sesiones) in `../pos-heladeria/src/app/modules/super-admin/pages/super-admin-user-detail-page.component.spec.ts`

**Checkpoint**: US1+US2+US3 cierran el alcance P1 completo (listado, indicadores, ficha).

---

## Phase 6: User Story 4 - Administrar el estado y los datos de un usuario (Priority: P2)

**Goal**: editar, cambiar rol, activar/reactivar, suspender con motivo, recuperar contraseña,
con confirmaciones y registro en auditoría (FR-016 a FR-022, FR-025 a FR-027 parcial).

**Independent Test**: editar rol, suspender con motivo obligatorio, reactivar, enviar
recuperación de contraseña, confirmando en cada caso la confirmación previa, el reflejo
inmediato del estado y el registro en el historial.

### Implementation for User Story 4

- [X] T050 [P] [US4] Implement `PATCH /super-admin/users/{user_id}` (name/role_id/membership edit; 409 si `status='anonymized'`) in `../pos-backend/app/api/v1/super_admin/users_router.py` (depends on T039)
- [X] T051 [P] [US4] Implement `POST /super-admin/users/{user_id}/activate` covering activation, reactivation and manual unlock (transition depends on current `status`) in `../pos-backend/app/api/v1/super_admin/users_router.py` (depends on T039)
- [X] T052 [P] [US4] Implement `POST /super-admin/users/{user_id}/suspend` (`reason` required 400 si falta, `revoke_sessions` opcional en la misma transacción) in `../pos-backend/app/api/v1/super_admin/users_router.py` (depends on T039)
- [X] T053 [P] [US4] Implement `POST /super-admin/users/{user_id}/send-password-reset` reusing the existing transactional-email mechanism (spec 096) via Celery in `../pos-backend/app/api/v1/super_admin/users_router.py` (depends on T039)
- [X] T054 [US4] Implement the "last active Super Admin" guard (count `tenant_id IS NULL AND status='active'`, 409 if it would reach 0) reused by suspend in `../pos-backend/app/services/super_admin_guard_service.py` (depends on T003)
- [X] T055 [US4] Wire `AdminAuditLogService.record(...)` into every action of T050-T053 (`profile_updated`, `role_changed`, `activated`, `suspended`, `password_reset_sent`) in `../pos-backend/app/api/v1/super_admin/users_router.py` (depends on T050, T051, T052, T053, T013)
- [X] T056 [P] [US4] Write backend tests for edit/role-change/activate/suspend-with-required-reason/send-password-reset, including the last-Super-Admin guard in `../pos-backend/app/characterization_tests/test_super_admin_user_actions.py`
- [X] T057 [P] [US4] Add `updateUser`, `activateUser`, `suspendUser`, `sendPasswordReset` methods to `SuperAdminUserDetailService` in `../pos-heladeria/src/app/modules/super-admin/services/super-admin-user-detail.service.ts` (depends on T041)
- [X] T058 [US4] Rebuild `admin-user-form.component` for editing name/role/membership with a confirmation step in `../pos-heladeria/src/app/modules/super-admin/components/admin-user-form.component.ts` (depends on T057)
- [X] T059 [US4] Create `suspend-user-modal.component` requiring a reason and offering an optional "cerrar sesiones activas" checkbox in `../pos-heladeria/src/app/modules/super-admin/components/suspend-user-modal.component.ts` (depends on T057)
- [X] T060 [US4] Add activate/reactivate/unblock and "enviar recuperación de contraseña" actions with confirmation dialogs to the listing and detail pages in `../pos-heladeria/src/app/modules/super-admin/pages/super-admin-user-detail-page.component.ts` (depends on T043, T058, T059)
- [X] T061 [US4] Reflect role/status changes immediately in both the listing and the ficha without a full reload in `../pos-heladeria/src/app/modules/super-admin/pages/super-admin-user-detail-page.component.ts` (depends on T060, T023)
- [X] T062 [P] [US4] Write Angular tests for edit/suspend/reactivate/password-reset flows, including the required-reason validation in `../pos-heladeria/src/app/modules/super-admin/components/suspend-user-modal.component.spec.ts`

**Checkpoint**: administración básica (editar, rol, activar, suspender, recuperar
contraseña) funciona de punta a punta con auditoría.

---

## Phase 7: User Story 6 - Supervisar accesos, intentos fallidos y sesiones (Priority: P2)

**Goal**: construir el bloqueo automático por intentos fallidos (research.md Decisión 4), el
registro de sesiones activas (Decisión 5) y su revocación individual/masiva (FR-013,
FR-028 a FR-030).

**Independent Test**: abrir la pestaña de Seguridad de varios usuarios con distinta cantidad
de sesiones/intentos fallidos, verificar los datos mostrados y que la revocación de sesiones
funciona de forma aislada a cualquier otra acción administrativa.

### Implementation for User Story 6

- [X] T063 [US6] Implement a Redis sliding-window failed-login counter per `(tenant_scope, email)` (reusing the `enforce_sliding_window` pattern from `/auth/forgot-password`) in `POST /auth/login`; on crossing the threshold, set `status='blocked_security'`, `active=False`, `security_blocked_at=now()`, persist `failed_login_attempts`, and call `AdminAuditLogService.record(actor_type="system", action="blocked_security")`, without changing the existing `401`/`403` response contract in `../pos-backend/app/api/v1/auth/routes.py` (depends on T003, T013)
- [X] T064 [US6] Reset the Redis counter and `failed_login_attempts` to 0 on a successful login or a password change in `../pos-backend/app/api/v1/auth/routes.py` (depends on T063)
- [X] T065 [US6] Add a `sid` claim to access/refresh JWTs and create a `UserSession` row on login (`device_label`/`browser` derived from `User-Agent`, `ip_address`) in `../pos-backend/app/api/v1/auth/routes.py` (depends on T009)
- [X] T066 [US6] Update `GET /auth/refresh-token` to validate `sid` against `UserSession.revoked_at` (respond `401 "Token has been revoked"`, same contract as the existing `tokens_valid_after` check, when revoked) and update `last_seen_at` on success in `../pos-backend/app/api/v1/auth/routes.py` (depends on T065)
- [X] T067 [US6] Update `POST /auth/logout` to mark the corresponding `UserSession.revoked_at`, alongside the existing `add_jti_to_blocklist` call (unchanged) in `../pos-backend/app/api/v1/auth/routes.py` (depends on T065)
- [X] T068 [P] [US6] Implement `POST /super-admin/users/{user_id}/sessions/revoke-all` (marks `revoked_at` on all active sessions and bumps `tokens_valid_after` as an extra safeguard) in `../pos-backend/app/api/v1/super_admin/users_router.py` (depends on T039, T009)
- [X] T069 [P] [US6] Implement `DELETE /super-admin/users/{user_id}/sessions/{session_id}` (404 si no pertenece al usuario o ya estaba revocada) in `../pos-backend/app/api/v1/super_admin/users_router.py` (depends on T039, T009)
- [X] T070 [US6] Wire `AdminAuditLogService.record(action="sessions_revoked")` into both revoke endpoints in `../pos-backend/app/api/v1/super_admin/users_router.py` (depends on T068, T069, T013)
- [X] T071 [P] [US6] Write backend tests: lockout threshold → `blocked_security` + system audit entry, `sid` revocation on refresh, logout revokes the session, and both revoke endpoints, **without modifying** the assertions of `test_auth_session_revocation.py`/`test_auth_session_name_claim.py` in `../pos-backend/app/characterization_tests/test_auth_lockout_and_sessions.py`
- [X] T072 [US6] Run `test_auth_session_revocation.py` and `test_auth_session_name_claim.py` unchanged and confirm they stay green in `../pos-backend` (depends on T063, T064, T065, T066, T067)
- [X] T073 [US6] Add "revocar todas las sesiones" / revoke-single-session actions to `user-security-tab.component`, with a confirmation that warns when the Super Admin's own current session will also close (Edge case) in `../pos-heladeria/src/app/modules/super-admin/components/user-security-tab.component.ts` (depends on T045)
- [X] T074 [US6] Show "Bloqueado por seguridad" as visually distinct from "Suspendido", with a manual-unlock action equivalent to reactivating in `../pos-heladeria/src/app/modules/super-admin/components/user-security-tab.component.ts` (depends on T073, T060)
- [X] T075 [P] [US6] Write Angular tests for session revocation (individual/all, own-session warning) and the blocked-security unlock flow in `../pos-heladeria/src/app/modules/super-admin/components/user-security-tab.component.spec.ts`

**Checkpoint**: supervisión de seguridad (bloqueo automático, sesiones, revocación) funciona
de forma independiente al resto de la administración.

---

## Phase 8: User Story 5 - Anonimizar o eliminar permanentemente (Priority: P3)

**Goal**: anonimización irreversible y borrado permanente sujeto a retención, con la mayor
fricción de confirmación del módulo (FR-023 a FR-025, FR-027).

**Independent Test**: anonimizar un usuario de prueba confirmando con su correo y verificar
la irreversibilidad y preservación del historial; por separado, probar la eliminación
permanente verificando el bloqueo por retención y, cuando procede, la desaparición del
listado.

### Implementation for User Story 5

- [X] T076 [P] [US5] Implement `POST /super-admin/users/{user_id}/anonymize` (`confirm_email` must match exactly, irreversible name/email replacement, invalidate `password_hash`, `status='anonymized'`, revoke all sessions, bump `tokens_valid_after`, last-Super-Admin guard) in `../pos-backend/app/api/v1/super_admin/users_router.py` (depends on T054, T068)
- [X] T077 [US5] Implement a cross-tenant retention check (facturas/órdenes referencing `user_id` in each tenant schema of the user's memberships) reused by the delete endpoint in `../pos-backend/app/services/user_retention_service.py` (depends on T007)
- [X] T078 [US5] Implement `DELETE /super-admin/users/{user_id}` (`confirm_email` match; 409 with `{reason, retention_tenants}` if retention applies; 409 if last active Super Admin; on success, record the `AdminAuditLog` entry **before** deleting the `User` row and its memberships) in `../pos-backend/app/api/v1/super_admin/users_router.py` (depends on T077, T054, T013)
- [X] T079 [P] [US5] Write backend tests for anonymize (confirm-email requirement, irreversible data replacement, preserved transactional history) and delete (retention block with alternative offered, successful delete, audit entry survives the deleted user) in `../pos-backend/app/characterization_tests/test_super_admin_user_anonymize_delete.py`
- [X] T080 [P] [US5] Create `confirm-sensitive-action-modal.component` requiring the user's email to be typed as confirmation, reusable by anonymize/delete/revoke-all in `../pos-heladeria/src/app/modules/super-admin/components/confirm-sensitive-action-modal.component.ts`
- [X] T081 [US5] Wire the "anonimizar" action in the ficha through the confirmation modal in `../pos-heladeria/src/app/modules/super-admin/pages/super-admin-user-detail-page.component.ts` (depends on T080, T060)
- [X] T082 [US5] Wire the "eliminar permanentemente" action, showing the retention-block message with "anonimizar" offered as the alternative when applicable in `../pos-heladeria/src/app/modules/super-admin/pages/super-admin-user-detail-page.component.ts` (depends on T080, T060)
- [X] T083 [US5] Disable/hide actions that no longer apply (editar datos personales, enviar recuperación de contraseña) in the listing and the ficha for `status='anonymized'` users in `../pos-heladeria/src/app/modules/super-admin/pages/super-admin-user-detail-page.component.ts` (depends on T081)
- [X] T084 [P] [US5] Write Angular tests for the anonymize/delete confirmation flows and for disabled actions on anonymized users in `../pos-heladeria/src/app/modules/super-admin/components/confirm-sensitive-action-modal.component.spec.ts`

**Checkpoint**: todas las operaciones sensibles del módulo (incluyendo las irreversibles)
están implementadas y verificables.

---

## Phase 9: User Story 7 - Consultar la auditoría administrativa (Priority: P2)

**Goal**: sección centralizada de auditoría, combinable por filtros, distinguiendo
administrador de sistema (FR-033 a FR-038).

**Independent Test**: realizar varias acciones administrativas y verificar que cada una
aparece correctamente en la auditoría, y que un evento automático del sistema se distingue
visualmente.

### Implementation for User Story 7

- [X] T085 [P] [US7] Implement `GET /super-admin/audit-logs` (filtros combinables: `affected_user_id`, `actor_user_id`, `tenant_id`, `action`, `date_from`, `date_to`; paginado; expone `actor_type`) in `../pos-backend/app/api/v1/super_admin/audit_router.py` (depends on T011)
- [X] T086 [US7] Register `audit_router` under the `/super-admin` prefix in `../pos-backend/app/api/v1/super_admin/router.py` (depends on T085)
- [X] T087 [P] [US7] Write backend tests for the audit-logs endpoint's combinable filters and the "sin registros que coincidan" empty state in `../pos-backend/app/characterization_tests/test_super_admin_audit_logs.py`
- [X] T088 [P] [US7] Create `SuperAdminAuditService.getAuditLogs(filters)` in `../pos-heladeria/src/app/modules/super-admin/services/super-admin-audit.service.ts`
- [X] T089 [US7] Create `super-admin-audit-page.component` with a chronological list (administrador/sistema, usuario afectado, negocio, tipo de operación, fecha/hora, IP) in `../pos-heladeria/src/app/modules/super-admin/pages/super-admin-audit-page.component.ts` (depends on T088)
- [X] T090 [US7] Add visual distinction (etiqueta/ícono) between "Sistema" and "Administrador" entries in `../pos-heladeria/src/app/modules/super-admin/pages/super-admin-audit-page.component.ts` (depends on T089)
- [X] T091 [US7] Add combinable filters (usuario, administrador, negocio, tipo de acción, rango de fechas) in `../pos-heladeria/src/app/modules/super-admin/pages/super-admin-audit-page.component.ts` (depends on T089)
- [X] T092 [US7] Add click-through from the affected-user row to its ficha, preserving the audit filters context on return in `../pos-heladeria/src/app/modules/super-admin/pages/super-admin-audit-page.component.ts` (depends on T089, T042)
- [X] T093 [US7] Add the "sin registros que coincidan" empty state, distinct from the loading/error states in `../pos-heladeria/src/app/modules/super-admin/pages/super-admin-audit-page.component.ts` (depends on T089)
- [X] T094 [P] [US7] Write Angular tests for the audit page's filters, the system/admin visual distinction, and the empty state in `../pos-heladeria/src/app/modules/super-admin/pages/super-admin-audit-page.component.spec.ts`

**Checkpoint**: la auditoría administrativa está completa y navegable desde la ficha de
usuario.

---

## Phase 10: User Story 8 - Navegación e integración con el panel existente (Priority: P1)

**Goal**: integrar Usuarios y la nueva Auditoría sin romper Tenants/Métodos de pago/Planes
(FR-042 a FR-044).

**Independent Test**: navegar entre los cinco módulos desde el sidebar, confirmando que
ninguno cambió de comportamiento y que Usuarios/Auditoría comparten identidad visual con el
resto del panel.

### Implementation for User Story 8

- [X] T095 [US8] Add the "Auditoría y actividad" route and sidebar entry alongside the existing Tenants/Usuarios/Métodos de pago/Planes entries in `../pos-heladeria/src/app/modules/super-admin/routes.ts` (depends on T089)
- [X] T096 [US8] Manually verify Tenants, Métodos de pago and Planes remain accessible with unchanged behavior after integrating the rebuilt Usuarios module and the new Auditoría section in `../pos-heladeria/src/app/modules/super-admin/`
- [X] T097 [P] [US8] Write/confirm an Angular test asserting the sidebar lists all five entries (Tenants, Usuarios, Métodos de pago, Planes, Auditoría) sharing the same layout/typography in `../pos-heladeria/src/app/modules/super-admin/` (depends on T095)

**Checkpoint**: todas las user stories (P1 a P3) están completas e integradas.

---

## Phase 11: Polish & Cross-Cutting Concerns

**Purpose**: verificación final de regresión y de los criterios de éxito transversales.

- [X] T098 [P] Run the full `pos-backend` characterization test suite (project venv, per memoria del proyecto) and confirm it is green in `../pos-backend`
- [X] T099 [P] Run the `pos-heladeria` `super-admin` module test suite and diff failures against the documented flaky baseline (by file, not by full-suite count) in `../pos-heladeria`
- [X] T100 Execute the `quickstart.md` end-to-end validation for all 8 user stories against a local Postgres + `ng serve` environment in `../pos-backend` and `../pos-heladeria`
- [X] T101 [P] Review the responsive layout (<1024px breakpoint already in effect) of the listing, ficha and audit pages in `../pos-heladeria/src/app/modules/super-admin/`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias.
- **Foundational (Phase 2)**: depende de Setup — BLOQUEA todas las user stories.
- **US1 (Phase 3)**: depende de Foundational (T003, T007).
- **US2 (Phase 4)**: depende de Foundational (T003); su widget de indicadores se inserta en
  la página construida en US1 (T023), así que en la práctica sigue a US1.
- **US3 (Phase 5)**: depende de Foundational (T003, T005, T007, T009, T011); su navegación
  desde el listado (T047) depende de US1 (T023).
- **US4 (Phase 6)**: depende de US3 (la ficha/listado para ubicar al usuario, T039, T042-T043).
- **US6 (Phase 7)**: depende de Foundational (T009) y de US3 (T045, la pestaña de Seguridad
  que extiende) y US4 (T060, los modales de confirmación que reutiliza).
- **US5 (Phase 8)**: depende de US4 (T054, el guard de último Super Admin) y US6 (T068, el
  endpoint de revoke-all que reutiliza al anonimizar).
- **US7 (Phase 9)**: depende de Foundational (T011/AdminAuditLog) y, para tener registros que
  mostrar, de que US4/US5/US6 ya estén escribiendo auditoría — es consultable incluso antes,
  pero su validación end-to-end es más significativa después.
- **US8 (Phase 10)**: su verificación de módulos existentes (T096) no depende de nada nuevo;
  su enlace de Auditoría en el sidebar (T095) depende de US7 (T089).
- **Polish (Phase 11)**: depende de que todas las user stories deseadas estén completas.

### Parallel Opportunities

- Dentro de Foundational: T005/T006 (Tenant), T007 (TenantMembership), T009 (UserSession),
  T011 (AdminAuditLog) y T014 (schemas) pueden avanzar en paralelo tras T003/T004; T016
  (frontend interface) es independiente de todo el backend.
- Dentro de cada user story, las tareas backend marcadas [P] (endpoints distintos) y la
  tarea de tests backend marcada [P] pueden avanzar junto con el trabajo frontend de la
  historia previa, siempre que no compartan archivo.
- US1 y US2 comparten `super-admin-users-page.component.ts`, así que sus tareas de UI no son
  paralelas entre sí pese a ser historias P1 distintas; sus tareas backend sí lo son.
- US6 y US5 pueden desarrollarse backend-en-paralelo con el frontend de US4 una vez que US3
  está completa, ya que tocan archivos de backend distintos.

---

## Implementation Strategy

### MVP First (User Stories 1+2+3, P1)

1. Completar Phase 1 (Setup) y Phase 2 (Foundational) — crítico, bloquea todo lo demás.
2. Completar Phase 3 (US1 — listado).
3. Completar Phase 4 (US2 — indicadores).
4. Completar Phase 5 (US3 — ficha individual).
5. **DETENER y VALIDAR**: correr la sección "User Story 1+2" y "User Story 3+6" (parcial, sin
   lockout/revocación) de `quickstart.md`.
6. Desplegar/demostrar si está listo — es el valor base pedido por el negocio (consulta
   centralizada).

### Entrega incremental

1. Setup + Foundational → base lista.
2. US1 + US2 → listado con indicadores (MVP visible).
3. US3 → ficha de detalle (contexto antes de administrar).
4. US4 → administración básica (editar, rol, activar/suspender, recuperar contraseña).
5. US6 → supervisión de seguridad (bloqueo automático, sesiones, revocación).
6. US5 → anonimizar/eliminar (mayor riesgo, al final).
7. US7 → auditoría administrativa, ahora con acciones reales que mostrar.
8. US8 (enlace de Auditoría) → cierra la integración de navegación.
9. Polish → regresión completa y verificación de SC-010/SC-009.

---

## Notes

- [P] = archivos distintos, sin dependencias pendientes entre sí.
- [Story] mapea cada tarea a su user story para trazabilidad (Principio XII).
- Las migraciones de Alembic son aditivas y reversibles por separado (`alembic downgrade`),
  consistente con `data-model.md`.
- Ningún characterization test protegido (`test_auth_session_revocation.py`,
  `test_auth_session_name_claim.py`) se modifica; las ramas nuevas de comportamiento se
  verifican con tests nuevos (T071).
- Confirmar siempre antes de operaciones sensibles (FR-025): revisar que cada tarea de UI de
  suspender/revocar/anonimizar/eliminar implemente el paso de confirmación antes de marcarla
  completa.
