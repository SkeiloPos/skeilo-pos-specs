# Contrato: API del panel de tenant — perfil legal, documento propio y aceptación de plataforma

Prefijo: `/api/v1/legal`. Requiere `User` autenticado del tenant (`get_current_user` +
`get_db`/`get_tenant`, mismo patrón que `table_sessions/router.py`).

## Perfil legal del tenant

### `GET /tenant-profile`
**200** → `TenantLegalProfileOut` (todos los campos, pueden venir `null`).

### `PUT /tenant-profile`
Reemplaza el perfil (FR-012). Parcial permitido (guarda lo enviado, no exige completitud
aquí — la completitud se exige en `preview`/`publish`).
**200** → `TenantLegalProfileOut`.

## Documento legal del tenant

### `GET /tenant-document/preview`
Renderiza el texto final con los datos actuales del perfil, sin guardar nada (FR-013).
**200** → `{ "contenido_renderizado": str, "master_template_version": int }`
**422** si el perfil no está completo →
```json
{ "detail": "Faltan datos legales obligatorios", "campos_faltantes": ["correo_contacto"] }
```

### `POST /tenant-document/publish`
Publica el snapshot (FR-014). Repite la validación de completitud de `preview`.
**201** → `TenantLegalDocumentOut` (`estado: "publicado"`). El snapshot anterior (si
existía) pasa a `"superado"`.
**422** mismo cuerpo que `preview` si faltan datos.

### `GET /tenant-document/current`
**200** → `TenantLegalDocumentOut | null`.

### `GET /tenant-document/template-update-status`
Deriva el banner de FR-015 comparando `master_template_version` del snapshot vigente
contra la versión vigente de `shared.master_legal_templates`.
**200** → `{ "actualizacion_pendiente": bool, "version_actual": int, "version_disponible": int | null }`

## Aceptación de la plataforma por el tenant (FR-019)

### `GET /platform-acceptance/pending`
Llamado al cargar el panel (antes de renderizar cualquier otra pantalla). Lista, para el
usuario autenticado, los tipos de documento de plataforma vigentes que aún no aceptó.
**200** → `{ "pendientes": [ { "tipo": "privacidad", "platform_document_id": "uuid", "version": 2, "contenido_markdown": "..." } ] }`
(vacío si ya aceptó todo lo vigente). El frontend bloquea el panel con un modal mientras
`pendientes` no esté vacío.

### `POST /platform-acceptance/accept`
**Body**: `{ "platform_document_id": "uuid" }`
**201** → `{ "accepted_at": datetime }`. Idempotente: aceptar dos veces la misma versión no
duplica la fila (`UNIQUE (user_id, platform_document_id)`, ver data-model.md tabla 3).

## Esquemas

```json
// TenantLegalProfileOut
{
  "razon_social": "string|null", "identificacion_legal": "string|null",
  "direccion_legal": "string|null", "ciudad": "string|null",
  "correo_contacto": "string|null", "telefono_contacto": "string|null"
}

// TenantLegalDocumentOut
{
  "id": "uuid", "version": 1, "master_template_version": 3,
  "contenido_renderizado": "...", "content_hash": "a1b2c3...",
  "estado": "publicado", "published_at": "2026-11-20T10:00:00Z"
}
```
