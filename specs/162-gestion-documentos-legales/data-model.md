# Data Model: Gestión de documentos legales de plataforma, plantilla de tenant y consentimiento del cliente final

**Spec**: [spec.md](./spec.md) · **Research**: [research.md](./research.md)

Convenciones: tipos y helpers tomados de `app/core/models.py` (`Base`,
`UUIDPrimaryKeyMixin`, `TimestampMixin`) y del resto de `app/models/*.py` (ver
`app/models/promotion.py`, `app/models/business_hours.py` como referencia de estilo). Las
tres primeras entidades van en el schema `shared` (archivo nuevo
`app/core/models_legal.py` o extensión de `app/core/models.py`, igual que `Plan`); las
tres últimas en el schema `tenant` (`app/models/*.py`, registradas en
`app/models/__init__.py`), siguiendo Decisión 1 de research.md.

## Esquema `shared` (plataforma — solo super admin)

### 1. `PlatformLegalDocument` (`shared.platform_legal_documents`)

Una fila por **versión** de un documento de plataforma (Privacidad o Términos).

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID PK | |
| `tipo` | `String(20)` | `'privacidad' \| 'terminos'` — `CheckConstraint` |
| `version` | `Integer` | Secuencial por `tipo`, 1-based |
| `contenido_markdown` | `Text` | Markdown fuente, inmutable tras publicar |
| `estado` | `String(12)` | `'borrador' \| 'publicado' \| 'superado'` — `CheckConstraint` |
| `content_hash` | `String(32)` | `blake2b`-128 hex del `contenido_markdown` (Decisión 4) |
| `fecha_vigencia` | `DateTime` | Obligatoria para publicar (Edge Case 1) |
| `published_by_user_id` | `UUID FK -> shared.users.id` | Nullable (NULL mientras es borrador) |
| `published_at` | `DateTime` | Nullable |
| `created_at` | `DateTime` | `server_default=func.now()` |

**Reglas de validación**:
- FR-003: `UPDATE` de `contenido_markdown`/`fecha_vigencia` rechazado a nivel de servicio
  si `estado != 'borrador'` (no a nivel de constraint de BD: la fila sigue existiendo y
  cambia de `estado`, no se vuelve inmutable por trigger).
- FR-004: a lo sumo una fila con `estado='publicado'` por `tipo` — índice único parcial:
  `UNIQUE (tipo) WHERE estado = 'publicado'`. Resuelve también el Edge Case de carreras de
  publicación concurrente (dos publicaciones simultáneas del mismo `tipo`: la segunda en
  comitear choca contra el índice único y recibe 409, no corrompe el estado).
- Publicar: dentro de una transacción, la versión `publicado` previa del mismo `tipo` pasa
  a `superado` y la nueva pasa a `publicado`, en el mismo `UPDATE`+`INSERT` — nunca dos
  filas `publicado` visibles a la vez ni siquiera momentáneamente para otra transacción
  (se apoya en el índice único parcial como barrera, no solo en el orden de las
  instrucciones).

**Índices**: `UNIQUE (tipo) WHERE estado = 'publicado'`; `INDEX (tipo, version)`.

### 2. `MasterLegalTemplate` (`shared.master_legal_templates`)

Una fila por **versión** de la plantilla maestra. Misma máquina de estados que (1).

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID PK | |
| `version` | `Integer` | Secuencial, 1-based |
| `contenido_markdown` | `Text` | Con placeholders `{{variable}}` de la lista cerrada |
| `estado` | `String(12)` | `'borrador' \| 'publicado' \| 'superado'` |
| `content_hash` | `String(32)` | Del `contenido_markdown` crudo (con placeholders) |
| `fecha_vigencia` | `DateTime` | Obligatoria para publicar |
| `published_by_user_id` | `UUID FK -> shared.users.id` | Nullable |
| `published_at` | `DateTime` | Nullable |
| `created_at` | `DateTime` | |

**Lista cerrada de variables** (FR-008, constante Python, no tabla —no hay caso de uso
de administrarla desde UI):
```python
ALLOWED_TEMPLATE_VARIABLES = {
    "nombre_negocio", "identificacion_legal", "direccion_legal", "ciudad",
    "correo_contacto", "telefono_contacto",
}
```
**Validación FR-009**: al guardar, `re.findall(r"\{\{(\w+)\}\}", contenido_markdown)` →
cualquier nombre fuera de `ALLOWED_TEMPLATE_VARIABLES` se reporta en una lista en el error
422 (`{"variables_no_permitidas": [...]}`).

**Índices**: `UNIQUE (id) WHERE estado = 'publicado'` expresado como
`UNIQUE (estado) WHERE estado = 'publicado'` (a lo sumo una plantilla vigente en todo
momento, no por `tipo` — solo hay un tipo de plantilla).

### 3. `TenantAdminPlatformAcceptance` (`shared.tenant_admin_platform_acceptances`)

Evidencia de que un **administrador de tenant** aceptó los documentos de plataforma
vigentes (FR-019) — separada de `ClientConsentAcceptance` (tabla 6, tenant final).

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID PK | |
| `user_id` | `UUID FK -> shared.users.id` | El admin de tenant que aceptó |
| `tenant_id` | `Integer FK -> shared.tenants.id` | Denormalizado desde `user.tenant_id` para consultas directas |
| `platform_document_id` | `UUID FK -> shared.platform_legal_documents.id` | Versión exacta aceptada |
| `accepted_at` | `DateTime` | `server_default=func.now()` |

**Regla de negocio (FR-019)**: el panel del tenant bloquea con modal si, para **cada**
`tipo` con una versión `publicado` vigente, no existe una fila aquí con ese
`platform_document_id` para el `user_id` autenticado. Primer login = no existe ninguna
fila todavía para ese `user_id`.

**Índices**: `UNIQUE (user_id, platform_document_id)` (evita duplicar el registro si el
admin reenvía la aceptación); `INDEX (tenant_id)`.

---

## Esquema `tenant` (por tenant — aislamiento por schema, FR-020)

### 4. `TenantLegalProfile` (`tenant.tenant_legal_profiles`)

Fila única por tenant (una tabla por schema de tenant, así que "única por tenant" = a lo
sumo una fila en toda la tabla). Datos editables, sin versionar — reemplazan su propio
valor.

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID PK | |
| `razon_social` | `String(255)` | Nullable hasta completarse (FR-012) |
| `identificacion_legal` | `String(50)` | Nullable |
| `direccion_legal` | `String(255)` | Nullable |
| `ciudad` | `String(100)` | Nullable |
| `correo_contacto` | `String(255)` | Nullable — también destino del email de FR-015 |
| `telefono_contacto` | `String(30)` | Nullable |
| `updated_at` | `DateTime` | `onupdate=func.now()` |

**Regla (FR-012)**: "completo" = los 5 campos obligatorios (`razon_social`,
`direccion_legal`, `ciudad`, `correo_contacto`, `telefono_contacto`) no son `NULL`/cadena
vacía; validado en el servicio antes de permitir vista previa o publicación (tabla 5), no
por `NOT NULL` de columna (el tenant puede guardar parcialmente mientras completa el
formulario). `identificacion_legal` queda explícitamente fuera de esta validación (FR-012a):
puede quedar `NULL`/vacío sin bloquear vista previa ni publicación.

### 5. `TenantLegalDocument` (`tenant.tenant_legal_documents`)

Snapshot inmutable por versión publicada (FR-014). Es la única fuente que ven los clientes
finales.

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID PK | Id opaco, público (Decisión 8 de research.md) |
| `version` | `Integer` | Secuencial, 1-based, por tenant |
| `master_template_id` | `UUID` | FK lógica a `shared.master_legal_templates.id` (cross-schema: columna sin `ForeignKey` de SQLAlchemy — ver Nota) |
| `master_template_version` | `Integer` | Denormalizado para mostrar sin round-trip a `shared` |
| `contenido_renderizado` | `Text` | Markdown ya con variables sustituidas y escapadas |
| `content_hash` | `String(32)` | Del `contenido_renderizado` |
| `estado` | `String(12)` | `'publicado' \| 'superado'` — nunca `'borrador'` (la vista previa no persiste nada, FR-013) |
| `published_at` | `DateTime` | `server_default=func.now()` |

**Nota cross-schema**: igual que `payment_methods.catalog_id -> shared.payment_method_catalog`
(ya existente, ver `app/core/db.py::get_tenant_specific_metadata`), una FK de una tabla
`tenant` a una tabla `shared` es válida en Postgres (ambos schemas viven en la misma base)
y el helper existente ya copia la tabla referenciada al crear el schema de un tenant nuevo.
Se usa la misma técnica aquí para `master_template_id`.

**Reglas**:
- FR-014: ninguna columna de una fila con `estado` se actualiza después de insertarse
  (immutabilidad aplicada a nivel de servicio: no existe ningún `UPDATE` de esta tabla en
  el código, solo `INSERT` + el único `UPDATE` que pasa la fila anterior de `publicado` a
  `superado` al publicar la siguiente).
- Índice único parcial `UNIQUE (estado) WHERE estado = 'publicado'` — mismo patrón que
  tabla 1/2, un único documento vigente por tenant a la vez.
- FR-015 ("banner + aviso pendiente"): se calcula, no se almacena — comparar
  `master_template_version` del documento `publicado` vigente contra la versión
  `publicado` vigente actual de `shared.master_legal_templates`; si son distintas, el
  panel del tenant muestra el banner. El email (FR-015) se dispara una vez, en el momento
  de publicar la nueva versión de plantilla (Decisión 10), no en cada carga de página.

### 6. `ClientConsentAcceptance` (`tenant.client_consent_acceptances`)

Evidencia de aceptación de un **cliente final** (FR-018). Nace siempre junto con el
`SessionParticipant` que identifica al cliente (Decisión 6 de research.md).

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID PK | |
| `session_participant_id` | `UUID FK -> tenant.session_participants.id` | El registro de cliente recién creado — identificador del cliente (FR-018) |
| `tenant_legal_document_id` | `UUID FK -> tenant.tenant_legal_documents.id` | Snapshot exacto aceptado |
| `ip_hash` | `String(64)` | `sha256` hex con salt de aplicación (Decisión 5) — nunca la IP en claro |
| `accepted_at` | `DateTime` | `server_default=func.now()` |

**Regla (FR-018, atomicidad)**: insertada en la misma transacción SQLAlchemy que crea el
`SessionParticipant` dentro de `cart/service.py::open_session`; si cualquiera de las dos
inserciones falla, ninguna persiste (`db.rollback()` ya existente en ese flujo).

**Regla (FR-016, gate)**: `open_session` consulta primero si existe una fila en
`tenant_legal_documents` con `estado='publicado'`; si no existe, lanza `HTTPException 409`
antes de crear el `SessionParticipant` — ninguna sesión de mesa nace sin que exista un
documento vigente que aceptar.

**Índices**: `INDEX (session_participant_id)`; `INDEX (tenant_legal_document_id)`
(auditoría: "cuántas aceptaciones tiene esta versión exacta").

---

## Diagrama de relaciones (resumen textual)

```
shared.platform_legal_documents  (tipo, version) ──┐
                                                      │ (platform_document_id)
shared.tenant_admin_platform_acceptances ◄───────────┘
            │ user_id → shared.users.id
            │ tenant_id → shared.tenants.id

shared.master_legal_templates (version) ──────────────┐
                                                         │ (master_template_id, cross-schema)
tenant.tenant_legal_documents ◄─────────────────────────┘
            │ (tenant_legal_document_id)
            ▼
tenant.client_consent_acceptances
            │ session_participant_id
            ▼
tenant.session_participants   (ya existente — sin cambios de esquema)

tenant.tenant_legal_profiles  (fuente de datos para renderizar tenant_legal_documents)
```

## Migraciones (Alembic)

Dos revisiones, siguiendo la convención de `alembic/versions/` del repo (una por "unidad
de cambio coherente", Principio VI):

1. `shared`: `platform_legal_documents`, `master_legal_templates`,
   `tenant_admin_platform_acceptances` + sus índices únicos parciales.
2. `tenant` (vía `get_tenant_specific_metadata`, se aplica a cada schema de tenant
   existente): `tenant_legal_profiles`, `tenant_legal_documents`,
   `client_consent_acceptances` + sus índices.

Ninguna migración necesita backfill: las tres tablas de `tenant` nacen vacías para todo
tenant existente (ningún tenant tiene hoy un perfil legal ni un documento publicado), y
FR-016 es justamente la regla que hace explícito ese estado inicial — ver research.md
Decisión 7 sobre el impacto de activar el gate en tenants ya en producción.
