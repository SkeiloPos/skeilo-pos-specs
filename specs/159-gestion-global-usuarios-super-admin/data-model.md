# Data Model: Gestión global de usuarios en el panel Super Admin

Todas las tablas nuevas o ampliadas viven en el esquema `shared` (como `users`, `tenants`,
`roles`), salvo donde se indique lo contrario. Todo campo nuevo es nullable o tiene un
`server_default` seguro para no romper filas existentes (Principio VIII).

## Entidades existentes, ampliadas

### `User` (`shared.users`)

| Campo | Tipo | Notas |
|---|---|---|
| `status` | enum (`active`, `suspended`, `blocked_security`, `pending_activation`, `anonymized`) | **Nuevo.** `server_default='active'`; backfill: todo `User` existente con `active=True` → `active`; con `active=False` → `suspended` (preserva la intención más probable de un `active=False` histórico, sin inventar datos). |
| `activated_at` | datetime, nullable | **Nuevo.** `NULL` = pendiente de activación (solo aplica a cuentas creadas directamente por el Super Admin, FR-018). Backfill: `created_at` para todo usuario existente (ya estaban operando). |
| `suspended_at` / `suspended_reason` | datetime nullable / text nullable | **Nuevo.** Se escriben juntos al suspender (FR-019); se limpian al reactivar. |
| `security_blocked_at` | datetime, nullable | **Nuevo.** Se escribe al cruzar el umbral de intentos fallidos (Decisión 4) o se limpia al desbloquear. |
| `failed_login_attempts` | integer, `server_default='0'` | **Nuevo.** Snapshot persistido del conteo (la ventana deslizante vive en Redis). |
| `anonymized_at` | datetime, nullable | **Nuevo.** Se escribe al anonimizar; marca irreversibilidad junto con `status='anonymized'`. |
| `active` | bool (existente) | **Sin cambio de tipo.** Pasa a ser escrita siempre junto con `status` por el servicio de este módulo; sigue siendo el único campo que lee `core/dependencies.py`. |

**Relaciones nuevas**: `memberships: list["TenantMembership"]`, `sessions:
list["UserSession"]`.

**Reglas de validación**:
- `status='blocked_security'` ⇒ `security_blocked_at IS NOT NULL`.
- `status='suspended'` ⇒ `suspended_at IS NOT NULL AND suspended_reason IS NOT NULL`.
- `status='anonymized'` ⇒ `anonymized_at IS NOT NULL` y `email`/`name` siguen el patrón
  anonimizado; es terminal (ninguna transición sale de `anonymized` salvo soporte manual
  fuera de alcance de este módulo).
- Transiciones permitidas por este módulo: `active ↔ suspended`, `active ↔ blocked_security`
  (solo hacia `active` vía desbloqueo manual, FR-018), `pending_activation → active`
  (activación manual), cualquier estado no terminal `→ anonymized` (irreversible).

### `Tenant` (`shared.tenants`)

| Campo | Tipo | Notas |
|---|---|---|
| `status` | enum (`active`, `suspended`), `server_default='active'` | **Nuevo** (Decisión 9). Campo de solo lectura para esta spec; no se agrega ninguna pantalla de administración de este campo (fuera de alcance). |

## Entidades nuevas

### `TenantMembership` (`shared.tenant_memberships`)

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID, PK | |
| `user_id` | UUID, FK `shared.users.id`, `ON DELETE CASCADE` | Cascada intencional: al eliminar permanentemente un usuario, sus membresías desaparecen con él (no así la bitácora, ver `AdminAuditLog`). |
| `tenant_id` | integer, FK `shared.tenants.id`, `ON DELETE CASCADE` | |
| `role_id` | UUID, FK `shared.roles.id` | Rol del usuario *en ese negocio* — puede diferir del rol de otra membresía del mismo usuario. |
| `created_at` | datetime, `server_default=now()` | Fecha desde la que pertenece a ese negocio (Key Entity "Membresía de negocio"). |

**Restricciones**: único por `(user_id, tenant_id)` — un usuario no puede tener dos
membresías activas al mismo tenant.

**Migración/backfill**: para cada `User` con `tenant_id IS NOT NULL`, se crea una fila de
membresía con ese `tenant_id`/`role_id`. Los Super Admin (`tenant_id IS NULL`) no reciben
ninguna membresía (no pertenecen a ningún negocio).

**Rollback**: `DROP TABLE shared.tenant_memberships` es seguro — ninguna otra tabla depende
de ella (es aditiva; `users.tenant_id` sigue siendo la fuente de verdad del login).

### `UserSession` (`shared.user_sessions`)

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID, PK | Igual al claim `jti` del refresh token emitido en el login. |
| `user_id` | UUID, FK `shared.users.id`, `ON DELETE CASCADE` | |
| `device_label` | text, nullable | Derivado del `User-Agent` en el login (p. ej. "Chrome en Windows"). |
| `browser` | text, nullable | |
| `ip_address` | text, nullable | IP de origen del login. |
| `created_at` | datetime, `server_default=now()` | |
| `last_seen_at` | datetime, `server_default=now()` | Actualizado en cada `GET /auth/refresh-token` exitoso de esa sesión. |
| `revoked_at` | datetime, nullable | `NULL` = sesión activa. Se escribe en logout, revocación individual o revocación masiva. |

**Migración/backfill**: tabla nueva, sin backfill posible (no hay forma de reconstruir
sesiones ya emitidas antes de este cambio). Cualquier token emitido antes de esta migración
sin `sid` se trata, en la verificación de `get_current_user`, como válido mientras no lo
alcance `tokens_valid_after` (compatibilidad retroactiva) — ver Decisión 5.

**Rollback**: `DROP TABLE shared.user_sessions`; si se revierte, `get_current_user` debe
dejar de exigir el claim `sid` (feature flag de código, no de datos) para no romper logins ya
emitidos con `sid`.

### `AdminAuditLog` (`shared.admin_audit_logs`)

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID, PK | |
| `actor_type` | enum (`admin`, `system`) | FR-034/035. |
| `actor_user_id` | UUID, nullable, **referencia blanda** (sin FK) | `NULL` cuando `actor_type='system'`. |
| `actor_name_snapshot` | text, nullable | Nombre del administrador al momento de la acción (sobrevive a cambios de nombre o borrado del admin). |
| `affected_user_id` | UUID, nullable, **referencia blanda** | `NULL` tras la eliminación permanente del usuario afectado — el registro sobrevive (FR-038). |
| `affected_user_email_snapshot` | text, nullable | Email del usuario afectado al momento de la acción. |
| `tenant_id` | integer, nullable, **referencia blanda** | Negocio relacionado, cuando aplica (FR-034). |
| `action` | text | p. ej. `role_changed`, `suspended`, `reactivated`, `sessions_revoked`, `password_reset_sent`, `anonymized`, `deleted`, `blocked_security` (sistema). |
| `detail` | JSONB, nullable | p. ej. `{"motivo": "..."}` en una suspensión, `{"rol_anterior": "...", "rol_nuevo": "..."}` en un cambio de rol. |
| `ip_address` | text, nullable | IP del administrador que ejecutó la acción; `NULL` para eventos de sistema (FR-034). |
| `created_at` | datetime, `server_default=now()`, indexado | |

**Por qué referencias blandas**: un `ON DELETE SET NULL`/sin FK evita que borrar
permanentemente un usuario (o, en teoría, un tenant) arrastre o bloquee su propia bitácora —
condición explícita de FR-038 ("de forma independiente al registro eliminado").

**Índices**: `(created_at)`, `(affected_user_id)`, `(actor_user_id)`, `(tenant_id)` — soportan
los filtros combinables de FR-036 dentro del presupuesto de SC-010.

**Rollback**: `DROP TABLE shared.admin_audit_logs` es seguro (ninguna otra tabla depende de
ella), pero destruye el historial de auditoría — solo aceptable como rollback de una
migración que todavía no se usó en producción.

## Resumen de impacto en migraciones (Alembic, `pos-backend`)

1. `users`: agregar columnas (`status`, `activated_at`, `suspended_at`, `suspended_reason`,
   `security_blocked_at`, `failed_login_attempts`, `anonymized_at`) + backfill.
2. `tenants`: agregar columna `status`.
3. Tabla nueva `tenant_memberships` + backfill desde `users.tenant_id`/`role_id`.
4. Tabla nueva `user_sessions` (sin backfill).
5. Tabla nueva `admin_audit_logs` (sin backfill).

Cada migración es independiente y reversible por separado (`alembic downgrade`), consistente
con la entrega por User Story: la migración 1-2 habilita P1 (estados/indicadores/listado), la
3 habilita el resto de P1/P3 (negocios asociados múltiples), la 4 habilita P2/P3 (seguridad,
revocación, auto-cierre de sesión al anonimizar/eliminar), la 5 habilita P2 (auditoría).
