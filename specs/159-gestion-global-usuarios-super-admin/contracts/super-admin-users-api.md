# Contrato: API `/super-admin` — Usuarios y Auditoría

Todos los endpoints exigen `Depends(get_current_super_admin)` (ya aplicado a nivel de
`router = APIRouter(prefix="/super-admin", ...)` en `pos-backend/app/api/v1/super_admin/router.py`
— FR-032, sin cambios). Respuestas de error reutilizan el sobre de error ya estandarizado
del panel Super Admin (spec 068).

## Listado e indicadores

### `GET /super-admin/users` (extiende el endpoint ya existente)

Query params nuevos, todos combinables entre sí (FR-005):
- `search: str | None` — coincide contra nombre, correo o nombre de negocio (FR-004).
- `status: list[str] | None` — `active|suspended|blocked_security|pending_activation|invitation_pending|anonymized`.
- `role_id: UUID | None`
- `plan_id: UUID | None` — filtra por el plan del/los negocio(s) asociado(s).
- `registered_from` / `registered_to: date | None`
- `sort_by: str | None` — `name|last_login_at|created_at` (FR-006).
- `sort_dir: "asc"|"desc"`

Respuesta (`Page[UserListItem]`), cada item agrega sobre `UserResponse` ya existente:
`status`, `memberships_count`, `memberships_preview` (hasta 1 negocio + indicador "+N" —
FR-007), `plan_name` (del negocio principal o `null` si no tiene ninguno — FR-003), 
`last_login_at`, `is_inactive_recently` (derivado: "Sin actividad reciente", sin cambiar
`status`, ver Edge case). Las filas con `status="invitation_pending"` provienen de
`UserInvitation` (Decisión 3) y traen `memberships_count=0`, `last_login_at=null`.

**Estados vacíos**: `total=0` sin ningún filtro activo ⇒ "sin datos de plataforma"; `total=0`
con algún filtro/búsqueda activo ⇒ "sin resultados" (FR-041, distintos mensajes en el
frontend según si `search`/`status`/`role_id`/`plan_id`/rango de fechas viene presente).

### `GET /super-admin/users/stats`

Sin query params. Responde `{ total, active, suspended, new_this_month }` (FR-008), calculado
sobre el mes calendario en curso en la zona horaria de la plataforma (Assumptions).

## Ficha individual

### `GET /super-admin/users/{user_id}`

Información general (FR-011): nombre, correo, fecha de registro, `status`, `last_login_at`.
404 si no existe.

### `GET /super-admin/users/{user_id}/activity?page=&size=`

Historial cronológico (más reciente primero, FR-012): une eventos propios (login,
cambio de contraseña) con `AdminAuditLog` filtrado por `affected_user_id=user_id`, indicando
quién hizo cada cambio administrativo.

### `GET /super-admin/users/{user_id}/security`

Responde: `active_sessions: UserSession[]` (device, browser, ip, created_at, last_seen_at),
`failed_login_attempts`, `security_blocked_at` (FR-013/FR-028/FR-029).

### `GET /super-admin/users/{user_id}/memberships`

Lista `{ tenant_id, tenant_name, tenant_status, plan_name, role_name, member_since }[]`
(FR-014). Vacío ⇒ estado vacío con acción de asignar negocio (FR-015, User Story 3 AS5).

## Administración

### `PATCH /super-admin/users/{user_id}`

Body: `{ name?, role_id?, membership_tenant_id?, membership_role_id? }` (FR-016/FR-017).
Escribe `AdminAuditLog(action="profile_updated"|"role_changed")`. 409 si el usuario está
`anonymized` (FR-027).

### `POST /super-admin/users/{user_id}/activate`

Sin body. Cubre activación manual de `pending_activation`, reactivación de `suspended`, y
desbloqueo de `blocked_security` (FR-018) — un solo endpoint, la transición depende del
`status` actual. Limpia `suspended_at/reason` o `security_blocked_at` según corresponda, pone
`status='active'`, `active=True`. 409 con detalle si es el último Super Admin bloqueado
sin otro activo disponible no aplica aquí (activar nunca reduce Super Admins activos).

### `POST /super-admin/users/{user_id}/suspend`

Body: `{ reason: str, revoke_sessions: bool }` (FR-019). 400 si falta `reason`. 409 (Decisión
8) si `user_id` es el último Super Admin activo. Si `revoke_sessions`, revoca todas las
sesiones como parte de la misma transacción.

### `POST /super-admin/users/{user_id}/send-password-reset`

Sin body. Reutiliza el mecanismo de correo transaccional ya existente (spec 096, Assumptions)
para emitir un `PasswordResetToken` y disparar el correo vía Celery. Responde confirmación;
registra `AdminAuditLog(action="password_reset_sent")` (FR-021). 409 si `anonymized`.

### `POST /super-admin/users/{user_id}/sessions/revoke-all`

Marca `revoked_at` en todas las sesiones activas del usuario y sube `tokens_valid_after`
como defensa adicional (FR-022/FR-030, Decisión 5).

### `DELETE /super-admin/users/{user_id}/sessions/{session_id}`

Revoca una sola sesión (FR-030). 404 si la sesión no pertenece a ese usuario o ya estaba
revocada.

### `POST /super-admin/users/{user_id}/anonymize`

Body: `{ confirm_email: str }` — debe coincidir exactamente con el correo actual del usuario
antes de anonimizarlo (FR-025). 409 si es el último Super Admin activo (Decisión 8). Ejecuta
Decisión 7 (anonimizar); registra `AdminAuditLog(action="anonymized")`.

### `DELETE /super-admin/users/{user_id}`

Body: `{ confirm_email: str }` (FR-025). 409 con `{ reason, retention_tenants: [...] }` si
existe obligación de retención vigente (Decisión 7/FR-024); 409 si es el último Super Admin
activo (Decisión 8). Si procede: registra `AdminAuditLog(action="deleted")` **antes** de
eliminar la fila `User` y sus membresías (FR-038).

## Auditoría

### `GET /super-admin/audit-logs`

Query params combinables (FR-036): `affected_user_id`, `actor_user_id`, `tenant_id`,
`action`, `date_from`, `date_to`. Respuesta paginada de `AdminAuditLog`, cada fila incluye
`actor_type` para distinguir visualmente sistema vs. administrador (FR-035). `total=0` con
algún filtro activo ⇒ estado vacío "sin registros que coincidan" (FR-041/User Story 7 AS5).

## Cambios aditivos fuera de `/super-admin`

- `POST /auth/login`: al autenticar, crea `UserSession`; al fallar, incrementa el contador
  Redis de intentos fallidos (Decisión 4) y, si cruza el umbral, escribe
  `blocked_security` + `AdminAuditLog(actor_type="system", action="blocked_security")`. Las
  respuestas y códigos ya protegidos (`401 Invalid credentials`, `403 User account is
  inactive`) no cambian; solo se agrega una rama nueva cuando el usuario ya está
  `blocked_security` al momento del intento.
- `GET /auth/refresh-token`: valida `sid` contra `UserSession.revoked_at`, actualiza
  `last_seen_at` (Decisión 5). Mismo mensaje/código ya usado para `tokens_valid_after`
  ("Token has been revoked", 401) cuando la sesión está revocada.
- `POST /auth/logout`: además de `add_jti_to_blocklist` (sin cambios), marca `revoked_at` en
  la `UserSession` correspondiente.
