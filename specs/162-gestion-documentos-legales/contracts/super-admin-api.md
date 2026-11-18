# Contrato: API de super admin — documentos de plataforma y plantilla maestra

Prefijo: `/api/v1/super-admin/legal` (mismo prefijo con manejo de errores estandarizado que
el resto de `super_admin`, ver `SUPER_ADMIN_ERROR_PREFIX` en `app/main.py`). Todas las
rutas exigen `User` autenticado con rol `SUPER_ADMIN` (mismo dependency que
`super_admin/users_router.py`).

## Documentos de plataforma

### `POST /platform-documents`
Crea un borrador nuevo de un tipo de documento (FR-001).

**Body**: `{ "tipo": "privacidad" | "terminos", "contenido_markdown": str }`
**201** → `PlatformLegalDocumentOut` (`estado: "borrador"`, `version` = última `version` de
ese `tipo` + 1).
**403** si el usuario no es `SUPER_ADMIN` (FR-006).

### `PATCH /platform-documents/{id}`
Edita el `contenido_markdown` de un borrador (FR-001).
**200** → `PlatformLegalDocumentOut`.
**409** si `estado != "borrador"` (FR-003: "el sistema rechaza la edición").

### `POST /platform-documents/{id}/publish`
Publica la versión (FR-002, FR-003, FR-004). Requiere `fecha_vigencia` en el body si no
se fijó antes.

**Body**: `{ "fecha_vigencia": datetime }`
**200** → `PlatformLegalDocumentOut` (`estado: "publicado"`). La versión `publicado`
previa del mismo `tipo` (si existía) cambia a `"superado"` en la misma transacción.
**422** si falta `fecha_vigencia` válida (Edge Case 1).
**409** si, por una carrera, otra publicación del mismo `tipo` ganó primero (choque contra
el índice único parcial de data-model.md tabla 1) — el cliente debe recargar y reintentar
con la versión más reciente.

### `GET /platform-documents/{tipo}/history`
Historial completo, incluyendo versiones superadas (FR-007).
**200** → `list[PlatformLegalDocumentOut]`, orden descendente por `version`.

## Plantilla legal maestra

### `POST /master-template` / `PATCH /master-template/{id}`
Igual forma que arriba, mismas reglas de `estado`. El guardado valida la lista cerrada de
variables (FR-008/FR-009):

**422** (variables inválidas) →
```json
{ "detail": "Variables no permitidas en la plantilla", "variables_no_permitidas": ["codigo_promo"] }
```

### `POST /master-template/{id}/publish`
Igual forma que `platform-documents/{id}/publish`. Publicar una nueva versión **no**
dispara ningún recálculo de `tenant_legal_documents` existentes (FR-010) — solo:
1. marca la versión anterior como `"superado"`;
2. encola, para cada tenant con un `tenant_legal_documents` publicado en una versión
   anterior de la plantilla, el envío del email de FR-015 (Decisión 10 de research.md) y
   deja que el panel calcule el banner en la siguiente carga (no se persiste un "aviso
   pendiente" como fila, se deriva comparando versiones — ver data-model.md tabla 5).

### `GET /master-template/history`
Historial completo (mismo patrón que documentos de plataforma).

## Esquema común `PlatformLegalDocumentOut` / `MasterLegalTemplateOut`

```json
{
  "id": "uuid",
  "tipo": "privacidad",            // solo en PlatformLegalDocumentOut
  "version": 3,
  "contenido_markdown": "...",
  "estado": "publicado",
  "content_hash": "a1b2c3...",
  "fecha_vigencia": "2026-12-01T00:00:00Z",
  "published_by_user_id": "uuid",
  "published_at": "2026-11-20T10:00:00Z"
}
```
