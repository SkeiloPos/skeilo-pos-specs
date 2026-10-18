# Research: Visibilidad de categorías en el menú QR

No quedan `[NEEDS CLARIFICATION]` en `spec.md`. Esta fase investiga, sobre el código real de
`pos-backend`/`pos-heladeria`, dónde encaja exactamente cada requisito y qué decisiones
técnicas concretas exige — sobre todo los dos puntos que el brief original dejaba abiertos:
cómo revalidar el carrito al enviar el pedido, y si la actualización en vivo (US3) es una
extensión trivial de lo que ya existe o una pieza nueva.

## Decisión 1: columna nueva `categories.visible_en_qr`, migración por tenant sin backfill complejo

**Decision**: agregar `visible_en_qr: bool` a `Category` (`app/models/category.py:12-35`,
junto a `active`/`display_order`), con `server_default` verdadero, siguiendo exactamente el
patrón de migración ya usado para `display_order`
(`alembic/versions/94144eaa60b5_categories_display_order.py`): `@for_each_tenant_schema`,
`_has_table(schema, "categories")` como guarda, `op.add_column(..., schema=schema)`.

**Rationale**: a diferencia de `display_order` (que necesitó una fórmula de backfill para
reproducir el orden visible de antes), `visible_en_qr` no tiene ningún valor histórico que
reconstruir — FR-001 ya exige que toda categoría existente quede visible por defecto, así que
`server_default='true'` + `nullable=False` basta en un solo paso, sin UPDATE de backfill. Es
el mismo patrón de migración por tenant que ya usa este proyecto (schema-per-tenant,
`app/core/db.py` `with_db()`/`schema_translate_map`), confirmado por la migración de
referencia.

**Alternatives considered**: ninguna — es la aplicación directa del patrón ya establecido.

## Decisión 2: mismo endpoint `PATCH /categories/{id}`, mismo patrón de schema/service

**Decision**: extender `CategoryUpdate`/`CategoryResponse`
(`app/api/v1/categories/schemas.py`) con `visible_en_qr: bool | None`, y `update_category()`
(`app/api/v1/categories/router.py:126-165`) con el mismo `if body.visible_en_qr is not None:
category.visible_en_qr = body.visible_en_qr` que ya usa para `active`/`display_order`. No se
crea ningún endpoint nuevo — el brief ya lo pedía así (`PATCH /categories/{id}` con
`{"visible_en_qr": false}`) y coincide exactamente con el endpoint que ya existe.

**Rationale**: mínimo cambio posible sobre un endpoint que ya resuelve exactamente este tipo
de campo escalar opcional — ninguna razón para duplicar la ruta.

**Alternatives considered**: un endpoint dedicado (`PATCH /categories/{id}/qr-visibility`) —
rechazado, el proyecto no tiene precedente de un endpoint de un solo campo cuando el PATCH
genérico ya cubre el caso (compárese con `display_order`/`active`, ambos en el mismo PATCH).

## Decisión 3: restricción a ADMIN acotada al campo nuevo, no al endpoint completo — hallazgo importante

**Decision**: `update_category()` NO tiene hoy ninguna restricción de rol — solo exige
`get_current_user` (cualquier usuario autenticado del tenant, incluido Cajero o Mesero, puede
editar `name`/`description`/`active`/`display_order`/`presentation_ids` de cualquier
categoría; confirmado leyendo `app/api/v1/categories/router.py` completo, sin ningún
`require_tenant_admin`/`require_tenant_admin_or_cashier` importado). FR-005 exige que **solo**
el cambio de `visible_en_qr` quede restringido a ADMIN. La implementación MUST acotar esa
restricción al campo, dentro del propio handler (p. ej. `if body.visible_en_qr is not None and
user.role.name != "ADMIN": raise 403`, con `user: User = Depends(get_current_user)` ya
presente) — **no** agregar `require_tenant_admin` como dependencia de todo el endpoint.

**Rationale**: agregar `require_tenant_admin` a todo el endpoint cambiaría comportamiento
existente no relacionado con esta spec (hoy Cajero/Mesero pueden renombrar una categoría o
cambiar su orden; eso dejaría de ser cierto) — eso es exactamente el tipo de cambio que el
Principio II exige registrar como decisión de negocio en
`registro-de-anomalias.md`, y esta spec no lo pide ni lo justifica (su alcance es
`visible_en_qr` únicamente). Restringir solo el campo nuevo es, en cambio, comportamiento
**100% nuevo** (el campo no existía antes), así que no hay ningún comportamiento previo que
proteger — aplica directamente el Principio IV (los specs nuevos pueden introducir
comportamiento nuevo) sin tocar el Principio II.

**Alternatives considered**: restringir todo el endpoint a ADMIN — rechazada por las razones de
arriba (fuera de alcance, cambiaría comportamiento no relacionado sin decisión de negocio que
lo autorice). Si en el futuro se decide que *todo* `PATCH /categories/{id}` debería ser
exclusivo de ADMIN, es una spec/decisión aparte.

## Decisión 4: el filtro del menú QR gana una condición, nada más

**Decision**: en `_build_menu()` (`app/api/v1/menu/router.py:97-100`), cambiar
`Category.active.is_(True)` por `Category.active.is_(True), Category.visible_en_qr.is_(True)`
en el mismo `.where(...)`. No hace falta tocar ningún otro punto del backend para el buscador:
confirmado que el menú QR **no tiene ningún endpoint de búsqueda propio** — el buscador
(`PublicMenuComponent.visibleProducts`,
`pos-heladeria/.../public-menu.component.ts:956-969`) filtra en el cliente sobre los
`categories()` ya cargados desde `_build_menu`. Con la categoría ya excluida de la respuesta,
el buscador la excluye gratis.

**Rationale**: es el único punto real que decide qué categorías/productos ve el comensal
(`menu_by_signed_qr` y `public_menu` llaman ambos a `_build_menu`, confirmado en spec 127);
cambiar un único `where()` resuelve FR-002 para los tres escenarios (menú, sus productos, y el
buscador) a la vez.

**Alternatives considered**: filtrar también en `_build_menu_promotions` (anuncios de
promociones vigentes) — **fuera de alcance**: una promoción no pertenece a una categoría, sino
a un conjunto de variantes; si una variante de una categoría ahora oculta sigue teniendo una
promoción vigente, su anuncio podría seguir apareciendo en `GET /menu/promotions` aunque el
producto ya no se liste en `_build_menu`. El brief original no menciona promociones y esta
spec no las toca — se documenta como inconsistencia menor preexistente, no como requisito de
esta spec (ninguna de las Acceptance Scenarios la ejercita).

## Decisión 5: revalidación en `submit_cart` — rechaza el envío Y limpia el carrito, mismo patrón que spec 093

**Decision**: en `submit_cart` (`app/api/v1/cart/service.py:764-769`), justo antes/junto a
`ensure_products_available(...)`, agregar una revalidación equivalente que identifique los
ítems del carrito cuyo producto pertenece a una categoría que ya no es `active AND
visible_en_qr` — mismo criterio que FR-002. Si hay alguno: **eliminar esas filas de
`CartItem` de una vez** (igual que si el comensal las hubiera quitado él mismo) y responder con
un `409` que liste los productos afectados, **sin crear ninguna orden** en esa misma llamada.

**Rationale**: reproduce exactamente el patrón ya existente de spec 093 (FR-021/FR-022) para
productos agotados —"se rechaza el envío completo aquí, nombrando todos los agotados a la vez,
antes de crear la orden; el carrito no se toca" (cita literal del comentario en
`cart/service.py`)— con una única extensión deliberada: **esta vez el carrito SÍ se toca**,
porque el Escenario 3 de `spec.md` lo exige explícitamente ("el carrito se actualiza sin esos
productos"), a diferencia del caso de agotados (donde el comensal debe quitarlo él mismo). El
comensal ve el mensaje, su carrito ya quedó limpio, y un segundo envío (sin esos productos)
puede tener éxito de inmediato — no hace falta inventar una creación de orden parcial dentro de
la misma transacción, que sería un cambio de forma mucho más grande sobre `submit_cart`.

**Alternatives considered**: crear la orden igual, pero solo con las líneas válidas, dentro de
la misma llamada que rechaza las inválidas — rechazada: ninguna spec previa de este proyecto
tiene ese patrón de "éxito parcial" para `submit_cart` (siempre es todo-o-nada), y adoptarlo
aquí sería una ampliación de alcance no pedida por ningún escenario de `spec.md` (el Escenario
3 solo exige que el carrito quede limpio, no que el resto del pedido se envíe solo).

## Decisión 6: US3 (menú abierto se actualiza solo) necesita un canal SSE nuevo para comensales — no es una extensión trivial

**Decision**: confirmado que la arquitectura de tiempo real actual (`app/core/events.py`,
`app/api/v1/realtime/`) es **un stream por tenant** con canales filtrados en memoria. Un
comensal (`kind="diner"`) se suscribe **únicamente** a
`frozenset({session_channel(table_session_id)})` (`app/api/v1/realtime/auth.py:61`) — el canal
de su propia mesa, derivado del token firmado, nunca más. El canal de "todo el tenant"
(`CH_STAFF`) existe pero es exclusivo del personal (`auth.py:105`). **No existe hoy ningún
canal que llegue a la vez a todos los comensales con el menú QR abierto**, sin importar su
mesa — necesario para que `menu.updated` les llegue a todos. Implementarlo exige: (a) un canal
nuevo (p. ej. `menu_channel(tenant_id)`) que todo comensal reciba además de su
`session_channel`, (b) publicar `menu.updated` ahí al cambiar `visible_en_qr`, y (c) que el
frontend del menú QR (`public-menu.component.ts`), que hoy carga `categories` **una sola vez**
en `ngOnInit` (`:999-1006`) y nunca la vuelve a pedir, aprenda a re-consultar el menú al recibir
ese evento — hoy sus únicos listeners SSE (`:1559-1581`) solo refrescan la lista "Mis pedidos",
ninguno re-carga el catálogo.

**Rationale**: por esto `spec.md` separó esto como US3/FR-009 (SHOULD, prioridad P3) en vez de
tratarlo como parte de FR-002/FR-008 (MUST) — es trabajo de infraestructura nuevo en ambos
lados, no una línea de código adicional sobre algo que ya existe. FR-008 (recarga manual del
menú) ya queda completamente cubierto por la Decisión 4, sin depender de esto.

**Alternatives considered**: reutilizar `CH_STAFF` para que el comensal también escuche ahí —
rechazada, mezclaría eventos exclusivamente de personal (turnos de caja, otros pedidos del
tenant) en la conexión de un comensal, una fuga de información y de ancho de banda no
relacionada con el propósito original de ese canal.

## Decisión 7: sin caché que invalidar, confirmado

**Decision**: no se agrega ningún mecanismo de invalidación de caché — `public_menu()` no
usa `json_or_304`/`http_cache.py` (eso solo lo usan `cart/router.py`/`orders/router.py`, para
sondeo de pedidos) y no hay ninguna capa de CDN/Redis delante de `GET /menu`. La nota técnica
del brief sobre "invalidar caché" no aplica a la arquitectura actual (ya documentado en
`spec.md`, Assumptions).

**Rationale**: confirmación directa, sin alternativas que evaluar.

## Decisión 8: UI de administración — columna nueva, mismo patrón que "Estado"

**Decision**: en `categories-page.component.ts`, agregar una columna "Menú QR" en la tabla
(junto a la columna "Estado" ya existente, líneas 86-91), con un toggle/pill del mismo estilo
que el de `active` (líneas 112-145), llamando a un nuevo método del servicio (p. ej.
`categoryService.toggleVisibleQr(id, current)`) que siga exactamente el patrón ya usado por
`toggleActive()` (`category.service.ts:161-168`: `PATCH` con el campo invertido). El filtro
"Todas" (líneas 38-46, hoy `all`/`active`/`inactive`) gana una cuarta opción "Ocultas en QR"
(FR-011) — filtrado en cliente sobre la página ya cargada, o como parámetro de consulta nuevo,
a decidir en el diseño de tareas sin que cambie el contrato visible de esta investigación.

**Rationale**: reutiliza el patrón visual y de servicio que ya existe para `active` en el
mismo archivo, sin introducir un componente ni un patrón de interacción nuevo.

**Alternatives considered**: ícono ambiguo dentro de "Acciones" — explícitamente descartado
por el propio brief del usuario, que pide una columna dedicada con toggle en línea.
