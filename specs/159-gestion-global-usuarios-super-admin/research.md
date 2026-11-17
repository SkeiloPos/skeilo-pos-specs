# Research: Gestión global de usuarios en el panel Super Admin

Todas las decisiones de esta fase resuelven brechas encontradas al contrastar el spec contra
el código real de `pos-backend`/`pos-heladeria` (no "NEEDS CLARIFICATION" del template
genérico, sino hallazgos de investigación técnica directa sobre el código).

## Decisión 1 — Membresía multi-negocio por usuario

**Decisión**: introducir una tabla nueva `shared.tenant_memberships`
(`user_id`, `tenant_id`, `role_id`, `created_at`, única por `(user_id, tenant_id)`) que
representa el conjunto completo de negocios y roles de un usuario. Se mantiene la columna
`users.tenant_id` (FK única) sin cambios, como el "negocio principal" que ya usan el login
(spec 091, resolución de ámbito por host) y la invitación (spec 037) — ninguno de esos dos
flujos se toca. Una migración de backfill crea, para cada `User` existente, exactamente una
fila de membresía que refleja su `tenant_id`/`role_id` actuales.

**Rationale**: el spec exige mostrar y administrar usuarios que pertenecen a varios negocios
con roles distintos en cada uno (FR-014, User Story 1 AS2, User Story 3 AS4), pero
`users.tenant_id` es una FK única — un usuario pertenece hoy a cero o un tenant, nunca a
varios. Agregar membresías sin tocar `tenant_id` es aditivo: no cambia cómo se resuelve el
login ni cómo se consume una invitación (Principio II).

**Alternativas consideradas**: reemplazar `users.tenant_id` por un campo derivado
("negocio primario" calculado desde las membresías) — rechazada por el riesgo de tocar la
ruta caliente de login/resolución de tenant (spec 091) y la unicidad `(tenant_id, email)` ya
usada hoy para permitir el mismo correo en negocios distintos; ese cambio, de necesitarse,
merece su propio spec.

**Alcance de uso en este módulo**: la gestión de "varios negocios" de este módulo (asignar
un negocio adicional a un usuario sin negocio — User Story 3 AS5, FR-015/FR-016) crea/edita
filas de `tenant_memberships` directamente desde el Super Admin; no reutiliza ni modifica el
flujo de invitación (spec 037), que sigue operando igual que hoy y seguirá generando también
su propia fila de membresía al consumirse.

## Decisión 2 — Estado enriquecido del usuario

**Decisión**: agregar `users.status` (enum: `active`, `suspended`, `blocked_security`,
`pending_activation`, `anonymized`) más los campos de soporte `activated_at` (nullable),
`suspended_at`/`suspended_reason` (nullable), `security_blocked_at` (nullable),
`failed_login_attempts` (int, default 0) y `anonymized_at` (nullable). La columna existente
`active: bool`, de la que depende hoy `get_current_user`/`get_authenticated_user`, se
mantiene como el único campo que la capa de autenticación consulta, y el servicio de este
módulo la escribe siempre en conjunto con `status` (p. ej. `suspended`/`blocked_security`/
`anonymized` ⇒ `active=False`; `active`/`pending_activation` ⇒ `active` solo pasa a `True`
cuando el estado es `active`). Así ningún check de autenticación existente cambia de
comportamiento.

"Invitación pendiente" **no** se almacena en `users.status`: por definición (ver spec, Key
Entities) es un usuario que todavía no tiene fila en `users`, solo una `UserInvitation` con
`status='pending'`. Se trata en la Decisión 3.

**Rationale**: FR-031/SC-008 exigen distinguir 7 estados visualmente; hoy solo existe un
booleano. Mantener `active` como fuente de verdad para la autenticación evita tocar
`core/dependencies.py` (Principio II); `status` es el campo enriquecido que consume
exclusivamente este módulo (listado, filtros, ficha).

**Alternativas consideradas**: derivar el estado enriquecido en tiempo de lectura sin
columna persistida (combinando `active`, `tokens_valid_after`, intentos fallidos, etc.) —
rechazada porque algunos estados (`suspended` vs. `blocked_security`, ambos con
`active=False` hoy) no son distinguibles sin un campo propio, y porque el listado necesita
filtrar/ordenar por estado con una consulta indexada (SC-010).

## Decisión 3 — Listado unificado de usuarios e invitaciones pendientes

**Decisión**: `GET /super-admin/users` proyecta y pagina, en una sola lista ordenable, tanto
filas de `User` como filas de `UserInvitation` con `status='pending'`, marcando estas
últimas con `status: "invitation_pending"` y datos limitados (sin "último acceso", sin
ficha completa — al abrir su "ficha" solo se ofrece reenviar/cancelar la invitación, no las
acciones de administración de un usuario real).

**Rationale**: el spec define "Invitación pendiente" como un estado más del listado (FR-031,
SC-008), pero esa entidad no es un `User`. Unificar la proyección en el endpoint es más
simple que forzar al frontend a mezclar dos fuentes y dos paginaciones.

**Alternativas consideradas**: excluir invitaciones del listado centralizado y mostrarlas
solo en otra pantalla — rechazada porque contradice directamente FR-031/SC-008, que exigen
distinguir ese estado en el mismo listado/ficha de usuarios.

## Decisión 4 — Bloqueo automático por intentos fallidos

**Decisión**: aunque la clarificación del spec asume que esta lógica "ya existe", la
investigación confirmó que **no existe** en `pos-backend` (no hay contador de intentos ni
bloqueo en `POST /auth/login`). Se construye aquí, de forma mínima y aditiva: un contador
deslizante en Redis por `(tenant_scope, email)` usando el mismo mecanismo ya empleado por
`enforce_sliding_window` en `/auth/forgot-password`, que al cruzar el umbral configurado
escribe `users.status = blocked_security`, `users.active = False`,
`users.security_blocked_at = now()` y congela `users.failed_login_attempts` con el conteo
alcanzado (snapshot persistido, consultable para el listado/filtros sin depender de que la
clave de Redis siga viva). Un login exitoso o un cambio de contraseña reinicia el contador
Redis y `failed_login_attempts` a 0. El desbloqueo manual (FR-018) es la misma acción que
"reactivar": limpia `security_blocked_at`, pone `status='active'`, `active=True`.

**Rationale**: FR-029/031 y la User Story 6 exigen mostrar y consultar este estado; sin la
lógica de conteo no hay nada que mostrar. Es comportamiento genuinamente nuevo (Principio
IV) y aditivo: ningún login que hoy tiene éxito deja de tenerlo; solo se agrega un techo que
antes no existía.

**Alternativas consideradas**: mantener la asunción del spec de que ya existe y dejar este FR
sin implementar — rechazada porque el usuario ya decidió explícitamente planear todo en esta
spec; dejarlo fuera dejaría el estado "Bloqueado por seguridad" permanentemente vacío.

## Decisión 5 — Registro de sesiones activas (dispositivo/navegador/IP)

**Decisión**: agregar `shared.user_sessions` (`id` = mismo `jti` del refresh token, `user_id`,
`device_label`, `browser`, `ip_address`, `created_at`, `last_seen_at`, `revoked_at`
nullable). `POST /auth/login` crea la fila al emitir el refresh token; `GET
/auth/refresh-token` actualiza `last_seen_at`. El JWT (access y refresh) gana un claim `sid`
con el id de sesión. `get_current_user`/`get_authenticated_user`/el endpoint de refresh
agregan una verificación adicional: si la sesión referida por `sid` tiene `revoked_at` no
nulo, se responde igual que hoy responde una sesión revocada por `tokens_valid_after`
("Token has been revoked", 401) — mismo contrato, nueva causa. `POST
/auth/logout` (que ya usa `add_jti_to_blocklist`) también marca `revoked_at` en la sesión
correspondiente. El Super Admin puede revocar una sesión puntual
(`DELETE /super-admin/users/{id}/sessions/{session_id}`) o todas
(`POST /super-admin/users/{id}/sessions/revoke-all`, que también barre
`tokens_valid_after` como defensa adicional para cualquier token ya emitido sin `sid` previo
a este cambio).

**Rationale**: FR-013/FR-030 exigen listar sesiones con dispositivo/navegador/IP y revocar
individual o conjuntamente; el mecanismo actual (`tokens_valid_after` global +
blocklist de un solo `jti` en logout) no expone esa información ni permite revocar una sola
sesión sin cerrar todas.

**Alternativas consideradas**: seguir usando solo `tokens_valid_after` para "revocar todas"
y omitir visibilidad de dispositivo/IP y revocación individual — rechazada porque el spec las
pide explícitamente (FR-013/FR-030, User Story 6 AS3).

## Decisión 6 — Bitácora de auditoría administrativa (alcance plataforma)

**Decisión**: tabla nueva `shared.admin_audit_logs` (`id`, `actor_type` [`admin`|`system`],
`actor_user_id` nullable, `actor_name_snapshot`, `affected_user_id` nullable,
`affected_user_email_snapshot`, `tenant_id` nullable, `action`, `detail` JSONB,
`ip_address` nullable, `created_at`), con referencias *blandas* (sin `FK ON DELETE CASCADE`)
a `users`/`tenants`, para que sobreviva a la eliminación permanente de un usuario (FR-038).
Toda acción administrativa de este módulo (cambiar rol, suspender, reactivar, revocar
sesiones, enviar recuperación, anonimizar, eliminar) y todo evento automático relevante
(bloqueo por intentos fallidos) escribe una fila aquí.

**Rationale**: la tabla `audit_logs` ya existente vive en el esquema `tenant` (por negocio) y
se usa para operaciones de venta/mesa — no es consultable de forma cross-tenant ni pensada
para sobrevivir al borrado de un usuario. FR-033/034/038 piden explícitamente una bitácora de
alcance plataforma e independiente del registro del usuario.

**Alternativas consideradas**: reutilizar `tenant.audit_logs` añadiéndole un `entity="user"`
— rechazada porque esa tabla es por-tenant y el Super Admin opera sobre usuarios
cross-tenant (incluyendo usuarios sin tenant); consultarla exigiría iterar todos los
esquemas por cada búsqueda de auditoría, incompatible con SC-010.

## Decisión 7 — Anonimización, eliminación permanente y retención

**Decisión**:
- **Anonimizar**: reemplaza `name`/`email` por valores anonimizados irreversibles
  (`anon-<uuid>@anonimizado.invalid`), invalida `password_hash`, pone `status='anonymized'`,
  `active=False`, revoca todas las sesiones y sube `tokens_valid_after`. La fila `User` y
  sus membresías permanecen (preserva el historial transaccional ya ligado a `user_id` en
  cada esquema de tenant, sin datos personales legibles).
- **Eliminar permanentemente**: antes de borrar, se verifica, para cada tenant de las
  membresías del usuario, si existe algún registro transaccional/fiscal (facturas, órdenes)
  que referencie su `user_id` en el esquema de ese tenant. Si existe en cualquiera, la
  acción se bloquea con 409 y el motivo (FR-024/Edge case), ofreciendo anonimizar como
  alternativa. Si no existe ninguna obligación de retención, se registra primero la entrada
  en `admin_audit_logs` (snapshot de email/id) y luego se elimina la fila `User` y sus
  membresías.
- Ambas acciones cierran automáticamente cualquier sesión activa como parte de la misma
  operación (Edge case correspondiente).

**Rationale**: instrumenta FR-023/024/038 y el Edge case de retención, sin tocar el
Principio VII (ninguna factura ya emitida se altera; el `user_id` que referencian permanece
válido tanto si se anonimiza como si queda huérfano tras un borrado ya autorizado por no
tener esa referencia).

**Alternativas consideradas**: soft-delete genérico (columna `deleted_at` sin
distinguir anonimización de borrado) — rechazada porque el spec exige dos acciones
distinguibles con semántica distinta (User Story 5) y un bloqueo explícito por retención que
un soft-delete único no modela.

## Decisión 8 — Protección del último Super Admin activo

**Decisión**: antes de suspender, bloquear, anonimizar o eliminar a un usuario con
`tenant_id IS NULL` (Super Admin de plataforma), se cuenta cuántos otros usuarios
`tenant_id IS NULL AND status='active'` existen; si el resultado es 0, la acción se bloquea
con 409 explicando el motivo (Edge case correspondiente, FR-026).

**Rationale**: instrumenta directamente el edge case y FR-026; reutiliza el mismo campo
`status` de la Decisión 2, sin necesitar una tabla o lógica adicional.

## Decisión 9 — Estado mínimo de Tenant para reflejarlo en la ficha de usuario

**Decisión**: agregar `tenants.status` (enum: `active`, `suspended`), default `active` para
todo tenant existente (ningún tenant existente cambia de comportamiento). Es el único campo
nuevo que se agrega al módulo de Tenants (spec 033) — exclusivamente para que la pestaña de
"Negocios asociados" de la ficha de usuario (FR-014, Edge case) pueda reflejar si alguno de
los negocios del usuario está suspendido, sin redefinir ni administrar el ciclo de vida
completo de un tenant (fuera de alcance de esta spec, que solo referencia el módulo de
Tenants).

**Rationale**: hoy `Tenant` no tiene ningún campo de estado — el Edge case "¿qué pasa si el
negocio del usuario fue suspendido?" no tiene qué reflejar sin él. Se limita a un campo de
lectura para esta spec; la administración de ese estado (si llega a necesitarse una pantalla
para cambiarlo) queda fuera de alcance y es trabajo de una futura spec sobre el módulo de
Tenants.

**Alternativas consideradas**: omitir el campo y asumir siempre "activo" — rechazada porque
contradice explícitamente el Edge case del spec ("sin ocultar la membresía ni mostrarla como
si el negocio estuviera activo").
