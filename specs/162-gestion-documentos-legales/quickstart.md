# Quickstart: validación end-to-end

**Spec**: [spec.md](./spec.md) · **Contratos**: [contracts/](./contracts/)

## Prerrequisitos

- `pos-backend` corriendo contra Postgres local (ver memoria de proyecto: venv +
  Postgres local disponible), migraciones de esta spec aplicadas (`alembic upgrade head`,
  ambos schemas `shared` y `tenant` por tenant).
- Redis disponible (rate limiting ya existente lo requiere; en su ausencia, `enforce()`
  deja pasar en modo fail-open — ver `app/core/rate_limit.py`).
- Variable de entorno `CONSENT_IP_HASH_SALT` configurada (Decisión 5 de research.md).
- Un tenant de prueba ya creado (`tenant_create` o script existente), con un usuario
  `ADMIN` y al menos una mesa activa con su QR firmado.
- Usuario `SUPER_ADMIN` existente (seed de `_seed_shared_data`, ver `app/core/db.py`).

## Escenario 1 — Super admin publica y versiona documentos de plataforma (US1)

1. Login como `SUPER_ADMIN`.
2. `POST /api/v1/super-admin/legal/platform-documents` con `tipo=terminos` → `201`,
   `estado=borrador`, `version=1`.
3. `POST .../platform-documents/{id}/publish` con `fecha_vigencia` futura → `200`,
   `estado=publicado`.
4. **Sin autenticación**: `GET /legal/platform-documents/terminos` → `200`, mismo
   `content_hash` que el paso anterior.
5. Repetir 2–3 con un nuevo borrador del mismo `tipo` → tras publicar, `GET
   .../platform-documents/terminos/history` muestra la v1 en `estado=superado` con su
   contenido intacto, y el público (paso 4) ahora devuelve la v2.
6. Como usuario sin rol `SUPER_ADMIN`: repetir paso 2 → `403`.

**Pasa si**: el paso 4 nunca devuelve una versión `borrador` ni `superado`, y el historial
del paso 5 conserva ambos contenidos sin alterarse.

## Escenario 2 — Plantilla maestra con lista cerrada de variables (US2)

1. Como `SUPER_ADMIN`, `POST .../master-template` con contenido que use solo
   `{{nombre_negocio}}` y `{{correo_contacto}}` → `201`.
2. `POST .../master-template/{id}/publish` → `200`, `estado=publicado`.
3. Repetir paso 1 con `{{codigo_promocional}}` (variable no permitida) → `422` con
   `variables_no_permitidas: ["codigo_promocional"]`.
4. Con un tenant que ya publicó su propio documento (Escenario 3) basado en la plantilla
   v1: publicar una v2 de la plantilla → el documento del tenant (Escenario 3, paso 3) no
   cambia su `contenido_renderizado` ni su `content_hash`.

**Pasa si**: el paso 3 nunca persiste la plantilla inválida, y el paso 4 confirma que
`GET /legal/tenant-documents/{id}` sigue devolviendo exactamente el mismo `content_hash`
de antes de publicar la v2.

## Escenario 3 — Tenant completa datos y publica su documento (US3)

1. Login como `ADMIN` del tenant de prueba.
2. `GET /api/v1/legal/tenant-document/preview` sin perfil completo → `422` con
   `campos_faltantes`.
3. `PUT /api/v1/legal/tenant-profile` con los 6 campos de negocio.
4. `GET .../tenant-document/preview` → `200`, `contenido_renderizado` con las variables
   ya sustituidas (sin placeholders `{{...}}` restantes).
5. `POST .../tenant-document/publish` → `201`, con `content_hash` y
   `master_template_version`.
6. Cambiar `correo_contacto` vía `PUT /tenant-profile` → `GET .../tenant-document/current`
   sigue devolviendo el snapshot del paso 5 sin cambios (FR-014, Edge Case del correo).
7. (Depende de Escenario 2, paso 4) `GET .../tenant-document/template-update-status` →
   `actualizacion_pendiente: true` tras la publicación de la plantilla v2.

**Pasa si**: el paso 4 no persiste nada (repetirlo no crea versiones), y el paso 6
confirma inmutabilidad del snapshot ya publicado.

## Escenario 4 — Cliente final acepta antes de dejar su nombre (US4)

1. Con el tenant del Escenario 3 ya con documento publicado: resolver
   `GET /menu/qr-token/{token}` (token de la mesa de prueba) → `200`, con
   `legal_document: {id, version}` no nulo.
2. `GET /legal/tenant-documents/{legal_document.id}` → `200`, mismo `content_hash` que el
   snapshot del Escenario 3.
3. `POST /cart/sessions` con `qr_token` + `display_name="Ana"` → `201`, con token de
   sesión.
4. Verificar en BD del schema del tenant: existe una fila en `client_consent_acceptances`
   con `session_participant_id` = el `SessionParticipant` recién creado y
   `tenant_legal_document_id` = el snapshot del paso 1; `ip_hash` no es la IP en claro.
5. Con un tenant **sin** documento publicado (tenant nuevo, sin pasar por Escenario 3):
   `POST /cart/sessions` → `409`, y no se crea ninguna fila nueva en
   `session_participants` ni en `client_consent_acceptances` para ese intento.

**Pasa si**: el paso 4 muestra que la fila de consentimiento nació en la misma operación
que el `SessionParticipant` (mismo instante, mismo request), y el paso 5 confirma que el
gate de FR-016 bloquea antes de crear nada.

## Escenario 5 — Aceptación de plataforma por el admin de tenant (US1 AC6/AC7, FR-019)

1. Primer login de un `ADMIN` de tenant recién creado (sin ninguna fila en
   `tenant_admin_platform_acceptances`): `GET /api/v1/legal/platform-acceptance/pending`
   → `pendientes` no vacío (todos los `tipo` vigentes de plataforma).
2. `POST .../platform-acceptance/accept` por cada `tipo` pendiente → `201`.
3. Repetir paso 1 → `pendientes: []`; el panel deja de bloquear.
4. Como `SUPER_ADMIN`, publicar una nueva versión de `terminos` (Escenario 1).
5. Repetir paso 1 para el mismo `ADMIN` → `pendientes` vuelve a incluir `terminos` v2,
   aunque ya había aceptado la v1.

**Pasa si**: el paso 5 confirma que aceptar una versión no cubre automáticamente la
siguiente — cada publicación nueva reabre el bloqueo para quien no la aceptó todavía.

## Nota sobre impacto en tenants ya en producción (ver research.md Decisión 7)

Antes de desplegar en producción, confirmar con el negocio (y registrar en
`specs/000-reconocimiento/registro-de-anomalias.md`, Principio II de la constitución) la
estrategia de corte: el Escenario 4 paso 5 implica que **todo tenant activo sin un
documento legal publicado dejará de poder abrir sesiones de mesa por QR** en el momento en
que el gate entre en vigor. Validar manualmente en un entorno de staging con datos
representativos de tenants reales antes de habilitarlo en producción.
