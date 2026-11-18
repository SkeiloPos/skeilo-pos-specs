# Research: Gestión de documentos legales de plataforma, plantilla de tenant y consentimiento del cliente final

**Fecha**: 2026-11-18
**Spec**: [spec.md](./spec.md)

Todas las incógnitas detectadas en el Contexto Técnico se resuelven aquí, apoyándose en
patrones ya existentes en `pos-backend` (ver referencias de archivo), sin introducir
dependencias nuevas.

## Decisión 1: Ubicación de cada entidad (schema `shared` vs `tenant`)

**Decisión**: Documento legal de plataforma, Plantilla legal maestra y Aceptación de la
plataforma por el tenant viven en el schema `shared` (son datos de la plataforma, no de un
tenant). Perfil legal del tenant, Documento legal del tenant (snapshots) y Consentimiento
del cliente final viven en el schema `tenant` (una tabla por tenant, igual que
`customer_orders`, `session_participants`, etc.).

**Rationale**: El proyecto ya es schema-per-tenant (`app/core/db.py::get_shared_metadata` /
`get_tenant_specific_metadata`). FR-020 ("aislar completamente los datos legales... entre
tenants") se obtiene gratis poniendo las tablas de tenant en el schema `tenant`: PostgreSQL
ya impide que una sesión conectada al schema de un tenant lea el de otro
(`with_db(tenant.schema)`, `schema_translate_map`). No hace falta ningún `tenant_id` de
aplicación adicional para esas tres tablas. Las tres tablas de plataforma usan el mismo
patrón que `Plan`, `User` (con `tenant_id` NULL) y los roles: visibles solo desde
`with_db(None)` o desde la sesión de super admin.

**Alternativas consideradas**: Poner todo en `shared` con `tenant_id` explícito (como
`User`) — rechazado porque mezclaría el aislamiento fuerte por schema (ya probado en el
resto del dominio de tenant) con aislamiento por columna, sin ninguna ventaja: estas tablas
no las consulta nunca el super admin de forma cruzada entre tenants (al contrario que
`User`, que sí necesita listarse globalmente en `super_admin/users_router.py`).

## Decisión 2: Documento de tenant es un solo tipo, no dos

**Decisión**: El "Documento legal del tenant" (US3/US4) es una única entidad versionada,
no un par (Privacidad + Términos) como en plataforma.

**Rationale**: El texto de la spec siempre habla de "su propio documento legal" /
"el documento vigente del tenant" en singular (FR-012 a FR-018, Key Entities). La plantilla
maestra combina ambos temas en un solo texto parametrizado por tenant (clarificación de
redacción de la spec: "generar su propio aviso de privacidad y términos y condiciones"
como una sola pieza). Mantener un solo tipo evita que el tenant tenga que gestionar dos
ciclos de publicación independientes solo para rellenar variables, cosa que la spec nunca
pide explícitamente.

## Decisión 3: Sustitución de variables sin motor de plantillas

**Decisión**: Las variables de la plantilla maestra se escriben como `{{nombre_variable}}`
y se sustituyen con una pasada de regex (`re.sub`) contra un diccionario cerrado; el valor
sustituido se escapa con `markdown-it-py`-safe escaping (equivalente a `html.escape` sobre
caracteres especiales de Markdown/HTML) antes de insertarse. No se usa Jinja2 ni ningún
motor que evalúe expresiones.

**Rationale**: FR-011 exige "sustitución literal de texto... sin evaluar código ni
expresiones" explícitamente — un motor de plantillas con `{% %}`/`{{ }}` evaluables sería
una superficie de inyección de lado servidor justo donde la spec pide lo contrario. Con
regex + lista cerrada de nombres de variable (FR-008/FR-009), cualquier placeholder que no
esté en la lista permitida se rechaza en el guardado de la plantilla (servicio de
validación, no en el render). `markdown-it-py` ya es una dependencia existente
(`requirements.txt:44`) usada para convertir Markdown a HTML; se reutiliza aquí para
renderizar tanto los documentos de plataforma como los de tenant al servirlos — no se añade
ninguna dependencia nueva.

**Alternativas consideradas**: Jinja2 `Template` con `autoescape=True` — rechazado: aunque
`autoescape` mitiga XSS, el motor completo sigue evaluando `{{ }}` como expresión Python
limitada (filtros, atributos), más superficie que un `re.sub` literal; no aporta nada que
la spec pida y abre una clase de bug (plantilla maestra que alguien edita con una
expresión válida de Jinja2 que no está en la lista cerrada pero tampoco falla el guardado
si no se audita el AST).

## Decisión 4: Huella de verificación de contenido (`content_hash`)

**Decisión**: `content_hash` se calcula igual que el `ETag` débil ya usado en
`app/core/http_cache.py::weak_etag` — `blake2b` de 128 bits sobre los bytes UTF-8 del
contenido final (Markdown ya renderizado/sustituido). Se guarda en columna propia de cada
versión/snapshot y se reexpone directamente como valor del header `ETag` en los endpoints
públicos.

**Rationale**: Reutilizar `weak_etag` da gratis FR-005 ("marca de verificación de contenido
que cambie cuando el contenido cambie" + "cacheo eficiente") sin añadir una librería de
hashing nueva ni duplicar lógica — el mismo patrón que ya usa `json_or_304` para 304s
condicionales en rutas de polling (`cart/router.py`, `menu/router.py`). No es
criptográfico (no lo necesita: no es un secreto, es una huella de integridad de contenido
público), consistente con el comentario ya existente en `http_cache.py` ("blake2b-128
basta: no es un hash criptográfico").

## Decisión 5: Huella no reversible de IP del cliente final (FR-018)

**Decisión**: `sha256(IP + salt_de_aplicación)` en hex, con el salt leído de una variable
de entorno nueva (`CONSENT_IP_HASH_SALT`), nunca derivado del propio valor ni reversible.

**Rationale**: La spec exige explícitamente "no reversible" pero también que "permita
comparar si dos aceptaciones provienen de la misma dirección" (Assumptions) — un hash
determinista con salt fijo de aplicación cumple ambas: mismo IP + mismo salt → mismo hash
(comparable), pero sin el salt (que no se persiste junto al hash, solo en configuración del
servidor) no se puede invertir por fuerza bruta de IPv4 completo tan fácilmente como un
hash sin salt. Es un hash de propósito general, no una contraseña, así que no se requiere
`bcrypt`/Argon2 (coste computacional no es el objetivo; irreversibilidad práctica sí). Se
reutiliza el mismo `_client_ip()` ya definido en `app/core/rate_limit.py` para extraer la
IP real detrás de proxy (primer salto de `X-Forwarded-For`).

## Decisión 6: Punto de integración del consentimiento atómico (FR-018)

**Decisión**: El consentimiento se registra dentro de
`app/api/v1/cart/service.py::open_session` (llamado por `POST /cart/sessions`,
`app/api/v1/cart/router.py:60`), en la misma transacción que crea el `SessionParticipant` —
no en un endpoint ni servicio nuevo.

**Rationale**: `POST /cart/sessions` es, hoy, el único punto donde el cliente final escribe
su nombre y nace su registro (`SessionParticipant`) — confirmado leyendo
`app/models/session_participant.py` y `cart/router.py`. La clarificación de la sesión 2026-
11-18 ("'Continuar' es una sola acción que... registra la aceptación; el identificador es
el client/order record creado por esa misma submission") señala exactamente esta llamada.
Insertar el consentimiento en el mismo `db.add()`/`db.commit()` que ya persiste el
`SessionParticipant` da la atomicidad de FR-018 sin necesitar una transacción distribuida:
ambas tablas están en el mismo schema `tenant`, misma sesión SQLAlchemy.

## Decisión 7: Gate "sin documento publicado → no se puede capturar el nombre" (FR-016)

**Decisión**: No existe ("activar la función") como un interruptor de configuración nuevo
— hoy `display_name` ya es obligatorio en todo `POST /cart/sessions`
(`cart/schemas.py::SessionOpenIn`), es decir la captura de nombre ya ocurre siempre. Lo que
FR-016 pide es una guarda nueva: `open_session` rechaza la petición (409) si el tenant no
tiene ningún `tenant_legal_document` en estado publicado. `menu_by_signed_qr` (que no crea
nada) sigue respondiendo siempre, pero su payload expone si existe o no un documento
vigente, para que el frontend decida si mostrar el formulario de nombre/aviso o un mensaje
de "menú no disponible todavía".

**Rationale — impacto en comportamiento existente (Principio II)**: esto SÍ cambia
comportamiento existente para cualquier tenant ya en producción sin un documento legal
publicado: hoy puede abrir sesión de mesa por QR sin restricción; tras esta spec, deja de
poder hacerlo hasta publicar su documento. Es un cambio de negocio explícitamente pedido
por la spec (US3 AC5, US4 AC3), así que corresponde registrarlo en
`specs/000-reconocimiento/registro-de-anomalias.md` **antes** de implementar el gate, y
evaluar en la fase de tareas una estrategia de activación controlada (p. ej. feature flag
por tenant o fecha de corte anunciada) para no romper en caliente a tenants ya operando.
Se deja marcado en Complexity Tracking del plan.

## Decisión 8: Exposición pública del documento del tenant en el flujo QR

**Decisión**: `menu_by_signed_qr` (`GET /menu/qr-token/{token}`) se amplía con un bloque
`legal_document` (id de snapshot, versión, `content_hash`) dentro de la respuesta ya
existente; el contenido completo se sirve desde un endpoint público nuevo y aparte,
`GET /legal/tenant-documents/{document_id}`, direccionable por el id opaco del snapshot
(UUID), sin necesitar resolver tenant por host ni repetir el token de mesa.

**Rationale**: El id del snapshot ya identifica unívocamente tenant + versión + contenido
inmutable (FR-014); no es información sensible (es exactamente lo que un cliente anónimo
debe poder leer antes de aceptar), así que no necesita ir protegido por el token de QR.
Mantiene el payload de `menu_by_signed_qr` liviano (no repite el texto legal completo en
cada carga de menú) y reutiliza el mismo patrón de recurso público direccionable por UUID
que ya existe para el documento de plataforma (Decisión 9).

## Decisión 9: Endpoint público de documentos de plataforma (FR-005)

**Decisión**: Router nuevo `app/api/v1/legal/public_router.py`, sin dependencia de
`get_tenant`/`get_db` (usa `with_db(None)` directo sobre el schema `shared`, igual que
`find_tenant_by_host`). Dos rutas:
- `GET /legal/platform-documents/{tipo}` (`tipo` ∈ `privacidad`/`terminos`): documento
  vigente de plataforma.
- `GET /legal/tenant-documents/{document_id}`: snapshot vigente de un tenant (Decisión 8).

Ambas usan `app/core/http_cache.py::json_or_304` para 304 condicional vía `ETag` (el mismo
`content_hash`), y `app/core/rate_limit.py::enforce()` con un bucket nuevo
`"legal_public"`.

**Umbral de rate limit** (clarificación de la sesión 2026-11-18, deferida a planificación):
se añade `RATE_LIMIT_LEGAL_PUBLIC_PER_IP` (default `30`) a `app/core/config.py`, reusando
`RATE_LIMIT_WINDOW_SECONDS` (60s) ya existente. 30 req/min por IP cubre con holgura una
carga de landing + polling normal del menú QR (que hoy usa el bucket `menu_qr`, mucho más
permisivo, para su propio tráfico) sin abrir una ventana de abuso significativa.

**CORS**: no se añade ningún mecanismo nuevo. El middleware CORS global de
`app/main.py` (`allow_origin_regex`) ya cubre `https://([a-z0-9-]+\.)?skeilopos.com` y
`localhost:4200` — dominio donde corre tanto la landing como los paneles. `fastapi-cors` no
soporta políticas por ruta sin un segundo `add_middleware` con *path* propio, y como el
contenido servido aquí no es sensible (es exactamente el texto que cualquier visitante no
autenticado debe poder leer), no se justifica la complejidad de una segunda política CORS
solo para este router. Si en el futuro la landing vive en un dominio distinto, es un cambio
de una línea en el regex existente, no de arquitectura.

## Decisión 10: Notificación por email al tenant (FR-015)

**Decisión**: Se reutiliza `app/core/mail.py::create_message`/`send_email` (llamada
síncrona a `EMAIL_API_URL`, mismo mecanismo que usan `invitacion.py` y
`contrasena_cambiada.py` en `app/core/mail_templates/`), con una plantilla nueva
`app/core/mail_templates/plantilla_actualizada.py`, llamada directamente desde el servicio
que publica una nueva versión de la plantilla maestra — no se añade un canal nuevo al
sistema de eventos de `app/core/notifications/dispatch.py`.

**Rationale**: `app/core/notifications/dispatch.py` está deliberadamente acotado a dos
disparadores (`order.created`, `payment.completed`, ver docstring del propio archivo) y a
canales `in_app`/`browser_push` — no tiene canal de email. Añadir "publicación de plantilla
maestra" a ese catálogo de eventos sería una ampliación de un módulo ya cerrado por diseño
para otro propósito (RF-002/RF-009 de la spec 077). El envío de email de las invitaciones
ya prueba que llamar `send_email()` directamente desde el servicio de negocio, sin pasar
por `dispatch.py`, es el patrón establecido para emails transaccionales puntuales como
este.

## Resumen de incógnitas → resueltas

| Incógnita (Contexto Técnico) | Resuelta en |
|---|---|
| Dónde viven las 6 entidades (shared vs tenant) | Decisión 1, 2 |
| Cómo sustituir variables sin motor de plantillas | Decisión 3 |
| Cómo calcular `content_hash` / ETag | Decisión 4 |
| Cómo hacer irreversible pero comparable la huella de IP | Decisión 5 |
| Dónde se registra el consentimiento atómico | Decisión 6 |
| Cómo bloquear la captura de nombre sin documento | Decisión 7 |
| Cómo llega el enlace del documento del tenant al menú QR | Decisión 8 |
| Endpoint público + rate limit + CORS de plataforma | Decisión 9 |
| Canal de email de aviso de plantilla pendiente | Decisión 10 |
