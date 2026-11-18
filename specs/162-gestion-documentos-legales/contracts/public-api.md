# Contrato: API pública (landing + menú QR del cliente final)

Sin autenticación. Rate limit vía `app/core/rate_limit.py::enforce(bucket="legal_public")`
(Decisión 9 de research.md). Cacheo condicional vía `ETag` +
`app/core/http_cache.py::json_or_304` sobre `content_hash`.

## Documentos de plataforma (landing)

### `GET /legal/platform-documents/{tipo}`
`tipo` ∈ `privacidad | terminos`.

**200** →
```json
{
  "tipo": "privacidad",
  "version": 3,
  "contenido_html": "<p>...</p>",
  "fecha_vigencia": "2026-12-01T00:00:00Z",
  "content_hash": "a1b2c3..."
}
```
Header `ETag: a1b2c3...`. Si `If-None-Match` coincide → `304` sin cuerpo.
**404** si nunca se publicó ninguna versión de ese `tipo` (Edge Case: el sistema aún no
tiene nada vigente que mostrar).
**429** con `Retry-After` si se excede `RATE_LIMIT_LEGAL_PUBLIC_PER_IP`.

`contenido_html` es el `contenido_markdown` de la versión `publicado` vigente, renderizado
con `markdown-it-py` en el momento de responder (no se persiste HTML, solo Markdown — así
un cambio futuro de reglas de render no exige reprocesar filas).

## Documento legal del tenant (menú QR)

### `GET /legal/tenant-documents/{document_id}`
`document_id` = id del `TenantLegalDocument` (snapshot), tal como lo referencia el bloque
`legal_document` agregado a la respuesta de `GET /menu/qr-token/{token}` (Decisión 8).

**200** →
```json
{
  "id": "uuid",
  "version": 2,
  "contenido_html": "<p>...</p>",
  "published_at": "2026-11-15T00:00:00Z",
  "content_hash": "a1b2c3..."
}
```
**404** si el id no existe (nunca cambia de contenido mientras exista: es un snapshot
inmutable, así que un `200` de ayer sigue siendo válido hoy sin reconsultar más que para
cacheo).

## Cambios en un endpoint ya existente

### `GET /menu/qr-token/{token}` (sin cambios de autenticación/firma del token)

Se agrega una clave al payload actual (aditivo, no rompe consumidores existentes):

```json
{
  "table": { "...": "..." },
  "business": { "...": "..." },
  "menu": { "...": "..." },
  "promotions": { "...": "..." },
  "legal_document": { "id": "uuid", "version": 2 } // null si el tenant no tiene ninguno publicado
}
```

El frontend usa `legal_document` para: (a) mostrar u ocultar el aviso + enlace antes del
campo de nombre (FR-017); (b) construir el enlace a
`GET /legal/tenant-documents/{legal_document.id}`. Si `legal_document` es `null`, el
frontend no debe permitir continuar al formulario de nombre (el backend lo rechazaría
igual en `POST /cart/sessions`, FR-016 — esto es solo UX, no el control de seguridad).

## `POST /cart/sessions` (sin cambios de firma — comportamiento ampliado)

Mismo contrato de entrada/salida ya documentado en el código
(`app/api/v1/cart/schemas.py::SessionOpenIn/SessionOpenResponse`). Cambios de
comportamiento (FR-016, FR-018):

- **409** nuevo: `{"detail": "El negocio aún no tiene un documento legal publicado"}` si
  la mesa pertenece a un tenant sin `TenantLegalDocument` en `estado='publicado'`. Se
  evalúa **antes** de crear el `SessionParticipant`.
- Efecto colateral nuevo en el **200/201** existente: además del `SessionParticipant`, se
  inserta una fila en `ClientConsentAcceptance` (tenant_legal_document_id = el snapshot
  vigente en ese instante, session_participant_id = el recién creado, ip_hash calculado
  de la petición), en la misma transacción. No se agrega ningún campo nuevo a
  `SessionOpenResponse`: el consentimiento es evidencia de servidor, no algo que el
  frontend necesite leer de vuelta.
