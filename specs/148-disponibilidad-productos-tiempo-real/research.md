# Research: Disponibilidad de productos en tiempo real (agotado ↔ disponible)

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

Todas las afirmaciones sobre el código se verificaron el 2026-11-02 leyendo `pos-backend`
(rama `develop`) y `pos-heladeria` (rama `develop`). Las referencias `archivo:línea` son
aproximadas: pueden moverse si otra spec toca el mismo archivo antes de implementar.

No quedaba ningún `NEEDS CLARIFICATION` en el Technical Context; esta investigación resuelve
decisiones de **cómo**, no de **qué** (el qué ya está cerrado en `spec.md`).

---

## Hallazgos que condicionan el diseño

| # | Hallazgo | Evidencia | Consecuencia |
|---|---|---|---|
| H1 | El bus SSE ya existe y es por tenant (`events:tenant:{id}`) con canales `staff`, `session:{id}` y `menu:{tenant}`. El staff **solo** se suscribe a `staff`; el comensal a `session:{id}` + `menu:{tenant}`. | `app/core/events.py`, `app/api/v1/realtime/auth.py` (`resolve_staff`, `_validate_diner_sync`) | Un evento publicado en `[staff, menu:{tenant}]` llega a ambos públicos **sin tocar la autenticación del stream** y sin que el comensal oiga `staff` (FR-030 a FR-032 por construcción). |
| H2 | `set_availability` (marca manual, spec 093) **no publica ningún evento** hoy. | `app/api/v1/products/service.py::set_availability` | Hay que agregar la publicación (post-commit, solo si cambió). |
| H3 | El menú **no considera la receta** al calcular `available`. Hoy solo calcula agotado por stock para **opciones** (`_option_availability`) y para presentaciones con un grupo obligatorio sin ninguna opción con stock. Un granizado cuyo insumo de receta llegó a 0 se muestra disponible y falla recién al cobrar. | `app/api/v1/menu/router.py::_option_availability`, `_build_menu` (no importa `RecipeItem`) | FR-008 exige agotado por receta: **es comportamiento nuevo**, no solo un aviso. Necesita un motor único de «pedibilidad» (D3) y registro de anomalía (D17). |
| H4 | Todo movimiento de stock pasa por `record_movement` / `apply_adjustment`. Hay 13 puntos de llamada en 8 módulos (compras, ajustes, confirmación, cocina, anulaciones, adiciones, ventas, complementario) y cada uno hace su propio `db.commit()`. | `app/inventory_engine/stock.py`; `grep record_movement(` | Publicar a mano en cada punto es frágil (olvidar uno rompe SC-006). Conviene un único gancho (D4). |
| H5 | Los eventos existentes se publican a mano en los routers, después del commit, con `tenant.id`. Las sesiones de BD (`with_db`) **no conocen el id del tenant**, solo el schema. | `app/api/v1/orders/router.py`, `app/core/db.py::with_db` | El gancho necesita resolver `schema → tenant_id` (D4). |
| H6 | El rechazo por agotado hoy tiene **tres formas**: 409 con lista de **nombres** (`productos_agotados`, marca manual), 400 con `producto`/`insumo` (`sold_out_detail`, descuento al confirmar/cobrar/agregar) y 409 «Stock insuficiente» con `insumo`/`disponible`/`requerido` (`check_availability`, carrito QR). | `catalog_engine/pricing.py`, `orders/consumption.py`, `catalog_engine/consumption.py`, `cart/service.py` | Unificar (D6) respetando lo que los clientes ya leen: el QR lee `detail.insumo` (`diner.service.ts:328`, `public-menu.component.ts:1010/1822`). |
| H7 | Tras la spec 146 el pedido de la Terminal nace en `pendiente` con `hold_for_payment` y **no descuenta stock al crearse**; el descuento (y su 400) ocurre en `checkout_and_send` / `confirm_order` (`_deduct_and_open`). La Terminal envía con `POST /orders` (`createManualOrderFromDraft`) y cobra después (`checkoutAndSend`). | `orders/service.py::create_order`, `orders/checkout.py::_deduct_and_open`, `pos-terminal.store.ts:1885-1960` | Para que el 409 salga «al enviar» y «sin crear orden» (US3), el chequeo preventivo de inventario debe vivir en `create_order`, no solo en el cobro. |
| H8 | **`menu.updated` (spec 128, US3) no está en `KNOWN_EVENT_TYPES` del cliente SSE.** `EventSource` solo entrega los eventos con nombre que se registraron con `addEventListener`; el comentario de `notification.created` documenta exactamente esta trampa. El test de `public-menu` pasa porque simula el evento con un `emit` falso. | `core/realtime/sse-client.ts` (lista termina en `notification.created`); `public-menu.component.spec.ts:1303` | (a) El evento nuevo **debe** registrarse o nunca llegará. (b) La actualización en vivo de 128 hoy no funciona en producción. Ver D13. |
| H9 | La conexión SSE del comensal vive en `DinerShellComponent` porque el menú y el checkout son rutas hermanas; antes, navegar al checkout destruía `PublicMenuComponent` y la conexión (precedente spec 077). Los pasos de pago son componentes de ruta propios (`pages/checkout/*`), no hijos de `PublicMenuComponent`. | `diner-shell.component.ts`, `pages/checkout/*` | La sincronización de disponibilidad del comensal **no puede** vivir en `PublicMenuComponent`: FR-019 exige que funcione en los pasos de pago (D10). |
| H10 | Las tarjetas de producto solo se deshabilitan con `product.sold_out` (marca manual), nunca con `product.available === false` (todas las presentaciones sin stock). Dentro de `ProductSelect*` cada presentación/opción sí usa `available`. | `public-menu.component.ts:592`, `pos-catalog-drawer.component.ts:92` | FR-008/FR-012: «producto con todas sus presentaciones agotadas = agotado» exige una regla de presentación compartida `sold_out \|\| available === false` (D10). |
| H11 | `DraftLine` de la Terminal guarda **copias** (`variant`, `option`) del menú del momento en que se agregó la línea. | `pos-terminal.store.ts` (`createManualOrderFromDraft`, `cartView`) | La marca «Agotado» de una línea debe resolverse contra el menú **vivo** por id, no contra su copia (D10). |
| H12 | No hay indicador visual de conexión; `RealtimeService.status` (`idle/connecting/open/reconnecting`) y los eventos de control `reconnected` y `resync` ya existen. El servidor emite `resync` (reason `gap`/`backpressure`). | `realtime.service.ts`, `sse-client.ts`, `realtime/router.py::_stream` | FR-025 a FR-027 se montan sobre piezas existentes; solo falta el temporizador de 5 s y la consulta de reconciliación (D11). |

---

## D1 — Evento nuevo `availability.changed`, delgado y por lote (no reutilizar `menu.updated`)

**Decisión**: tipo nuevo `availability.changed` con una lista `changes[]` de `{kind, id, …estado}`
(contrato en [contracts/availability-event.md](./contracts/availability-event.md)). Un solo evento
por commit, aunque afecte a muchos elementos (FR-010). `menu.updated` (spec 128) queda intacto.

**Rationale**:
- `menu.updated` no lleva ids: obliga a cada cliente a pedir `GET /menu` completo (promociones,
  imágenes, toppings, N consultas) por cada aviso. Con 20 tablets y una ráfaga de ventas eso es
  carga evitable; la spec 128 lo aceptó porque cambia rara vez, la disponibilidad no.
- Un evento por elemento llenaría rápido la cola por suscriptor (`REALTIME_QUEUE_SIZE=100` →
  `resync` por backpressure). Un lote por commit mantiene el volumen proporcional a transacciones,
  no a elementos.
- Respeta el principio documentado del módulo: eventos delgados, sin datos internos (FR-007): solo
  ids y booleanos; nunca existencias, costos ni insumos.

**Alternativas**:
- *Reutilizar `menu.updated` + refetch*: descartada por costo y porque no permite el parche
  inmediato <3 s con carga normal (SC-001) sin una consulta pesada por cliente.
- *Un evento por elemento*: descartada por backpressure.
- *Evento con el menú completo*: descartada por tamaño y por filtrar datos fuera del canal correcto.

**Tope**: si un solo commit afecta a más de `AVAILABILITY_EVENT_MAX_CHANGES` (propuesta: 200)
elementos, se publica `{changes: [], refresh: true}` y el cliente hace la consulta de reconciliación
(D8). Evita eventos gigantes por un insumo muy compartido.

---

## D2 — Canales: `[staff, menu:{tenant}]`; no se modifica la autenticación del stream

**Decisión**: `events.availability_changed(tenant_id, changes)` publica con
`channels=[CH_STAFF, menu_channel(tenant_id)]`. `app/api/v1/realtime/auth.py` no cambia.

**Rationale**: H1. El comensal ya oye `menu:{tenant}` y nunca `staff` (FR-032). El staff oye
`staff`. Como el stream es por tenant y el tenant sale del token/ticket firmado (FR-031), el
aislamiento entre negocios (RN-4, SC-004) es el mismo que ya protege al resto de eventos; no se
introduce ningún parámetro que el cliente pueda elegir.

**Alternativas**: *suscribir al staff también a `menu:{tenant}`*: descartada, cambia la
autenticación del stream y el alcance de la prueba de aislamiento sin ganar nada.

**Verificación**: tests de canales (suscriptor comensal recibe, suscriptor de otro tenant no; el
comensal no recibe `staff`) siguiendo el patrón de `test_menu_realtime.py`.

---

## D3 — Un único motor de «pedibilidad» que alimenta menú, evento, snapshot y 409

**Decisión**: módulo nuevo `app/catalog_engine/availability.py` con
`compute_availability(db, *, stock=None, scope_item_ids=None) -> CatalogAvailability` y
`ensure_orderable(...)` (D6). `_build_menu` deja de calcular `available` por su cuenta y consume el
motor. Tres niveles (spec, Key Entities):

| Nivel | Regla de «no se puede pedir» por stock |
|---|---|
| **Opción** | Igual que hoy (`_option_availability`): ligada a un insumo inactivo, o `stock < need` con `need` = peor caso del catálogo para esa opción. Se **mueve sin cambiar** (la prueba de equivalencia lo exige). |
| **Presentación** (variante activa) | (a) **nuevo**: algún `RecipeItem` con `stock < cantidad` — solo si `Product.tracks_inventory`; (b) igual que hoy: algún grupo obligatorio (`min_select > 0`, modo `conteo`) sin ninguna opción disponible. |
| **Producto** | Sin ninguna presentación activa pedible ⇒ `available = false` (igual que hoy: `pedible`). La marca manual (`sold_out = not Product.available`) sigue siendo **independiente** (spec 093 FR-012). |

«Agotado» en pantalla = `sold_out OR NOT available` a nivel producto (H10).

**Rationale**: una sola definición evita que lo que se pinta, lo que se anuncia y lo que el servidor
rechaza diverjan (la causa de «lo vi disponible y me lo rechazaron»). Reutilizar el cálculo de
opciones tal cual preserva el comportamiento actual (Principio II) y solo añade la receta, que es
lo que FR-008 pide.

**Alcance acotado (rendimiento)**: `scope_item_ids` restringe el cálculo a los dependientes de
ciertos insumos (recetas y opciones ligadas a ellos, y las presentaciones que los usan por
cualquier vía). Sin `scope` calcula el catálogo completo en un número **constante** de consultas
(recetas, stock, opciones+insumo, enlaces variante-grupo), sin N+1.

**Adiciones (toppings)**: son productos con variantes propias. `MenuToppingResponse.available`
pasa de `active ∧ manual` a `active ∧ manual ∧ pedible(variante principal)` con el mismo motor
(FR-017, Assumptions).

**Alternativas**: *dejar `_build_menu` como está y agregar la receta solo en el nuevo módulo*:
descartada, crea dos fuentes de verdad. *Calcular en SQL puro por insumo*: descartada, la regla
mezcla receta, grupos y tamaños (`quantity_per_option`) y ya existe en Python.

**Riesgo conocido, no se corrige aquí**: el motor conserva la regla actual «grupo obligatorio sin
**ninguna** opción disponible» aunque `min_select > 1` (debería exigir `min_select`). Cambiarlo
alteraría el menú actual sin autorización (Principio II); el 409 del servidor sigue siendo la red
fina.

---

## D4 — Detección de transiciones por inventario: gancho de sesión sobre `record_movement`

**Decisión**: `record_movement` y `apply_adjustment` registran, **antes** de mutar el stock, en
`db.info["availability_stock"]` el par `{item_id: (stock_inicial, stock_final)}` (el inicial solo la
primera vez que se toca el insumo en esa transacción; el final se actualiza en cada movimiento).
Un oyente de `Session` hace el resto:

1. `before_commit`: si hay insumos registrados, calcula `compute_availability(scope=insumos
   tocados)` dos veces —con `stock` = iniciales y con `stock` = finales (sobrescritura explícita, no
   depende de `flush`)— y guarda en `db.info` la **diferencia** (solo elementos que cambiaron entre
   pedible / no pedible: FR-009).
2. `after_commit`: publica un único `availability_changed` con esa diferencia.
3. `after_rollback`: descarta lo acumulado (nunca se anuncia lo que no ocurrió, FR-004).

`tenant_id`: `with_db(schema)` marca `db.info["tenant_schema"]`; el oyente resuelve
`schema → tenant_id` con una consulta cacheada (`lru_cache`; el par es inmutable). Los tests con
SQLite fijan `db.info["tenant_id"]` directamente.

**Instalación explícita** (`install_availability_hooks()`), no al importar: se llama en el `lifespan`
de `app/main.py` (donde ya arranca el bus) y en `app/celery_task.py`. Así ninguna suite existente
cambia de comportamiento ni intenta hablar con Redis.

**Rationale**:
- Cubre los 13 puntos actuales **y los futuros** sin tocarlos (SC-006 al 100%).
- Publicar *después del commit* y *una sola vez por transacción* es exactamente la regla del módulo
  de eventos; el cálculo de diferencia dentro de `before_commit` evita consultar BD en
  `after_commit` (donde la transacción ya terminó).
- La diferencia neta por transacción es lo correcto: una venta que baja y repone el mismo insumo no
  produce aviso; varias líneas sobre un insumo compartido producen un lote (FR-010).
- Costo nulo para commits sin movimientos de stock (`db.info` vacío ⇒ el oyente retorna).

**Alternativas**:
- *Publicar a mano tras cada commit de los 13 sitios*: descartada (H4; se olvida uno).
- *Trigger de Postgres + LISTEN/NOTIFY*: descartada, nueva infraestructura y rompe la suite SQLite.
- *Sondeo periódico del servidor (comparar snapshots)*: descartada para el camino principal por
  latencia (SC-001: 3 s) y carga. Queda como respaldo posible, no se implementa.

**Riesgo**: un movimiento de stock hecho fuera de esos dos puntos de entrada no avisaría. Mitigación:
test que recorre el código buscando `current_stock =` fuera de `stock.py`/importación y falla si
aparece uno nuevo (hoy solo hay dos asignaciones, ambas en `stock.py`; la importación crea insumos
nuevos sin dependientes).

---

## D5 — Marca manual: publicar tras el commit y solo si cambió

**Decisión**: `ProductService.set_availability` conserva su `UPDATE` único y, después de
`db.commit()`, si `previous != available`, publica `availability_changed` con el estado completo del
producto (`sold_out` y `available` derivado, calculado con el motor acotado a ese producto).
`events` se llama desde el **router** (`products/router.py`), como el resto del catálogo de eventos,
porque ahí está el `tenant`.

**Rationale**: H2, FR-004 y la regla «publicar siempre después del COMMIT». Evita ruido de «nada
cambió» (mismo criterio que 128). El evento lleva `sold_out` **y** `available` juntos porque el
cliente no puede recombinarlos para las adiciones (D10).

**Falla del canal**: `events.publish` nunca lanza (FR-005): el cambio queda guardado y las vistas se
ponen al día al reconectar.

---

## D6 — 409 unificado: una sola forma, cuatro puntos de chequeo preventivo y un guardia final

**Decisión**: función `ensure_orderable(db, lines)` en `availability.py` que recibe las líneas
(variante, cantidad, opciones, adiciones) y levanta **un** `HTTPException(409)` con la forma de
[contracts/sold-out-conflict.md](./contracts/sold-out-conflict.md):

```json
{ "error": "Se agotó: Granizado de mora · 16 oz. Quítalo para continuar",
  "productos_agotados": ["Granizado de mora · 16 oz"],
  "agotados": [{"id": "…", "tipo": "presentacion", "nombre": "Granizado de mora · 16 oz",
                "producto_id": "…", "motivo": "inventario"}] }
```

Se invoca (siempre **antes** de crear/mutar nada) en: `create_order`, `add_item_to_order`
(consolidación), `cart.add_item`/`update_item`/`submit_cart`. Reemplaza a
`ensure_products_available` / `ensure_product_available` (que pasan a ser casos particulares del
motor). El descuento real de inventario (`deduct_order_items*`) **sigue siendo el guardia final**:
su `InsufficientStockError` (400) se convierte, en `_deduct_and_open` y en las rutas de
consolidación/cocina, en el mismo 409 unificado (carrera entre el chequeo y el descuento).

**Compatibilidad (FR-023)**: se conservan las claves que cada punto ya devolvía:
- `error` (texto legible; `extractError` del front lo muestra sin cambios),
- `productos_agotados` (lista de **nombres**, como hoy en el 409 manual),
- `producto` e `insumo` cuando el rechazo es de **un** solo elemento por inventario (forma del
  400 de `sold_out_detail`),
- `disponible`, `requerido`, `contexto` en el 409 «Stock insuficiente» del carrito QR (el comensal
  lee `detail.insumo` para «No queda suficiente X»).
Lo nuevo es solo la clave aditiva `agotados[]`.

**Cambio de comportamiento autorizado**: 400 → 409 en los caminos de inventario, y rechazo por
inventario **al crear** el pedido (hoy aparece recién al cobrar, H7). Se registra antes de
implementar (D17) y se actualizan los tests que lo congelan citando esa decisión.

**Alternativas**: *dejar el 400 para inventario*: contradice la decisión de negocio ya tomada
(Clarifications Q4). *Solo unificar en el cliente*: el cliente no puede inventar el `id`.

---

## D7 — Cantidad pedida mayor a lo que alcanza el inventario (hay para 1)

**Decisión**: `ensure_orderable` agrega el consumo **por insumo** de todas las líneas del pedido
(`required_consumption`, ya existente) y compara con el stock. Por cada insumo insuficiente, todas
las líneas que lo consumen entran a `agotados[]` con `motivo: "cantidad"` y el `id` del
producto/presentación de esa línea. No hay aviso en vivo para este caso (FR-022 + Edge Case).

**Rationale**: reutiliza el mismo cálculo que `check_availability`. Marcar **todas** las líneas que
consumen el insumo escaso es conservador (puede marcar de más si se quitara una sola), pero la
spec ya dice que la persona quita la línea y vuelve a agregar lo que alcance; identificar «cuál
sobra» sería una regla de negocio que nadie pidió.

**El cliente** trata `motivo: "cantidad"` como marca **solo de línea** (no parcha el menú como
agotado, porque el producto sigue pedible en cantidad 1).

---

## D8 — Snapshot de disponibilidad con `as_of`

**Decisión**: dos lecturas ligeras que devuelven únicamente el estado de disponibilidad (sin
precios, imágenes ni promociones): `GET /menu/availability` (tenant por cabecera, staff) y
`GET /menu/qr-token/{token}/availability` (tenant y mesa firmados). Contrato en
[contracts/availability-snapshot-api.md](./contracts/availability-snapshot-api.md). La respuesta
incluye `as_of`: la versión (`version_of`) del último evento del stream del tenant **leída antes**
de calcular.

**Rationale**: es la «consulta completa de la disponibilidad del catálogo» de FR-026/FR-027, mucho
más barata que `GET /menu`. `as_of` permite al cliente descartar eventos que el snapshot ya refleja
(D9). El del comensal aplica los mismos filtros de visibilidad QR que `_build_menu(only_visible_en_qr=True)`
para no filtrar ids de productos ocultos.

**Si Redis no responde**: `as_of = null`; el cliente aplica los eventos siguientes sin filtro
(son estados absolutos, así que aplicarlos dos veces es inocuo).

**Alternativas**: *refrescar `GET /menu` completo*: más simple pero ~10× más pesado por
reconexión y sin `as_of`.

---

## D9 — Orden y consistencia en el cliente (FR-006)

**Decisión**: cada cambio del evento trae el estado **absoluto** del elemento y el evento trae `v`
(versión monótona del stream). El cliente mantiene `lastV[elemento]` y `snapshotAsOf`:
- ignora un cambio si `v <= lastV[elemento]` o `v <= snapshotAsOf`;
- tras aplicar un snapshot, fija `snapshotAsOf = as_of` y limpia `lastV`.

**Rationale**: SSE ya entrega en orden por conexión y el servidor deduplica el replay, pero las
condiciones de carrera reales son *snapshot vs. evento en vuelo* y *replay tras reconexión*. Estados
absolutos + `v` las resuelven sin reloj del cliente ni reintentos. Una ráfaga marcar/desmarcar/
marcar termina en el último estado confirmado aunque el evento viejo llegue tarde.

---

## D10 — Cliente: sincronizador en la raíz, parche sobre los datos, «línea afectada» derivada

**Decisión**:
1. `AvailabilitySyncService` (`providedIn: 'root'`, en `core/availability/`) se suscribe a
   `availability.changed`, `reconnected`, `resync` y a la visibilidad de la pestaña (D12), aplica D9
   y delega el parche a un **destino** registrado. Destinos:
   - **Staff**: `MenuService.categories` (ya compartido por Terminal, orden manual, drawer,
     promociones). `MenuService` gana `applyAvailability(changes)` / `loadAvailability()`.
     El sincronizador lo arranca `DashboardLayoutComponent` junto a `connectStaff()`.
   - **Comensal**: `DiningCartService` (raíz) guarda un índice de disponibilidad por
     producto/presentación/opción/adición, actualizado por el sincronizador **aunque
     `PublicMenuComponent` no esté vivo** (H9); `PublicMenuComponent` además parcha su signal
     `categories` mientras exista. Lo arranca `DinerShellComponent` junto a `connectDiner()`.
2. Se parchean **los datos** (inmutable), no cada componente: `ProductSelect*`, tarjetas y
   `cartView` ya leen `.available`/`.sold_out`, así que se actualizan solos (signals).
3. Regla compartida `isProductSoldOut(p) = p.sold_out || p.available === false` en
   `availability.util.ts`, usada por las tarjetas del QR, del drawer y de la orden manual (H10).
4. **«Línea afectada» es derivada (`computed`), nunca estado guardado**: dada una línea y el menú
   vivo resuelve por id si su producto, presentación, opción o adición está agotado, o si el 409
   la marcó por cantidad. Por eso FR-016 (la marca se retira sola al volver) y FR-018 (nunca se
   vacía el carrito) salen gratis: nadie escribe en las líneas.
5. Bloqueo: `submitDisabled = affectedLines().length > 0` (Terminal: «Crear pedido»; QR:
   «Confirmar pedido», también en los pasos de pago, con botón «Volver al carrito», FR-019).

**Terminal — modalidades**: mesa, para llevar, domicilio y la página de orden manual comparten
`PosTerminalStore.draftLines`/`cartView`, así que el cambio vive en el store y se refleja en las
cuatro (FR-003 b). El drawer de «agregar a orden existente» solo necesita el parche del menú
(deshabilita tarjetas y presentaciones).

**Alternativas**: *guardar un flag `agotado` dentro de cada `DraftLine`*: descartada, exige limpiar
a mano al volver disponible y es la fuente típica de carritos «pegados». *Parchear cada componente*:
~40 usos de `.available`.

---

## D11 — Indicador «Sin actualización en vivo» (5 s continuos)

**Decisión**: `LiveStatusService` (`core/availability/`) observa `RealtimeService.status`. Cuando
deja de ser `open` arranca un temporizador de 5 s; si vuelve a `open` antes, lo cancela (no
parpadea, FR-025/US5.6); si vence, expone `liveLost = true`. Al volver a `open` tras haberlo
perdido, dispara la reconciliación (D8) —además del `reconnected` que el cliente SSE ya emite—.
Componente `LiveStatusIndicatorComponent` (texto «Sin actualización en vivo», discreto,
`role="status"`, `aria-live="polite"`, sin bloquear nada) montado en: menú QR (y pasos de pago),
cabecera de la Terminal, orden manual, drawer del catálogo y Carta del menú.

`PosTerminalHeaderComponent` ya lee `realtimeStatus`; se reutiliza esa señal, no se duplica la
conexión.

---

## D12 — Pestaña en segundo plano o dispositivo en reposo (FR-028)

**Decisión**: al pasar a `visible` (`document.visibilitychange`), el sincronizador hace la
reconciliación **si** la pestaña estuvo oculta más de 10 s **o** `status !== 'open'`. Un `EventSource`
en segundo plano puede quedar suspendido sin que el navegador avise, así que no basta confiar en
`reconnected`.

**Alternativas**: *reconciliar siempre al volver*: aceptable (la consulta es barata) pero genera
tráfico al alternar pestañas; el umbral lo evita. 10 s es un valor de implementación, no de negocio,
y queda en una constante.

---

## D13 — Registrar los tipos de evento en el cliente SSE (hallazgo H8)

**Decisión**: agregar `availability.changed` **y** `menu.updated` a `KNOWN_EVENT_TYPES`, más un test
guardia que compara la unión `RealtimeEvent` del modelo con esa lista y falla si algún tipo de
negocio no está registrado.

**Rationale**: sin el registro el frame llega y el navegador lo descarta en silencio; es la misma
trampa que ya cayó una vez (`notification.created`). El test guardia convierte el olvido en un fallo
de compilación de la suite.

**Punto a confirmar con el usuario** (no bloquea el plan): registrar `menu.updated` activa por
primera vez en producción el refresco en vivo de categorías de la spec 128, que hoy nunca llega. Es
el comportamiento que 128 documentó como intención, pero es un cambio observable. Se propone un
commit propio y reversible. Si el usuario prefiere no tocarlo, el test guardia lo lista como
excepción explícita.

---

## D14 — Menú QR en los pasos de pago (FR-019)

**Decisión**: no se mueve al comensal de paso. `CheckoutOrderSummaryComponent` (resumen de la spec
092) ya recibe `lines`; se le añade una marca por línea («Agotado» + elemento afectado) alimentada
por el índice de `DiningCartService`. Cada paso (`method`, `cash`, `transfer`, `review`) muestra la
alerta y deshabilita su acción de confirmar mientras haya líneas afectadas; un botón «Volver al
carrito» navega al menú con el carrito abierto. `CheckoutProgressStore` (que persiste método,
monto y comprobante en `localStorage`) **no se toca**, así se conserva lo ya llenado.

Cuando el total baja tras quitar la línea: el resumen compara el total previo con el nuevo y, si
cambió mientras hay progreso guardado, muestra «El total cambió a $X». Solo en pago mixto, si
`cash_amount >= nuevoTotal`, se vuelve a pedir el monto (reutiliza la regla de la spec 130, que ya
invalida el comprobante). No se agrega validación automática del monto del comprobante (Edge Case).

---

## D15 — Carta del menú de Cajero/Administrador (FR-003 d)

**Decisión**: `ProductsPageComponent` escucha `availability.changed` (vía el sincronizador) y, para
cambios con `sold_out` de un producto **que está en la página actual**, vuelve a pedir **solo esa
fila** (`GET /products/{id}`) para traer también quién y cuándo (`available_changed_by_name/_at`) sin
poner nombres de empleados en un evento que también oye el comensal. Los cambios solo de inventario
(`available` derivado) **no** tocan el interruptor manual (US6.5). Con `reconnected`/`resync` recarga
la página actual. El listado está paginado (spec 079): no se trae nada fuera de la página visible.

---

## D16 — Sin migración, sin dependencias nuevas

- **Datos**: ninguna columna ni tabla nueva (estado derivado de datos existentes; la marca manual
  ya existe). Principio VIII: no hay migración ni rollback de datos; revertir es revertir código.
- **Dependencias**: ninguna (eventos de SQLAlchemy ya presente; Redis/SSE ya presentes). Principio IX.
- **Configuración**: una constante nueva `AVAILABILITY_EVENT_MAX_CHANGES` (D1).

---

## D17 — Registro de anomalías y tests protegidos

Antes de implementar (Principio II), registrar en
`specs/000-reconocimiento/registro-de-anomalias.md`, tomando el **siguiente número libre al momento
de registrar** (hoy el último es A-152 y hay un A-150 duplicado entre las specs 141 y 146; los
colegas crean specs en paralelo, así que se verifica con `git fetch` justo antes):

1. **Rechazo por agotado unificado (409)**: 400 → 409 en los caminos de inventario, rechazo
   preventivo por inventario al crear el pedido (D6, H7) y texto `error` de FR-024 también en los
   409 que ya existían (adiciones y toppings «Stock insuficiente», carrito QR), conservando
   `insumo`, `disponible`, `requerido` y `contexto`.
2. **El menú marca agotado por receta**: presentaciones, productos y adiciones
   (`MenuToppingResponse.available`) cuyo insumo de receta no alcanza dejan de mostrarse
   disponibles (D3, H3).

Tests a actualizar de forma explícita, citando la decisión en el mismo commit (Principio III),
lista **inicial** que `/speckit-tasks` debe confirmar corriendo la suite:
- `test_orders_checkout.py` (~585, ~1001): esperan 400 en `confirm_order`/`checkout_and_send`.
- `test_orders_payment_gate.py` (~467): espera 400 en `confirm_cash_payment_attempt` por stock
  insuficiente (se agregó tras `/speckit-analyze`: la lista inicial lo omitía).
- `test_orders_service.py` (~1047-1054): `sold_out_detail` con `producto`/`insumo`.
- `test_orders_additions.py` (~222), `test_cart_sold_out.py`, `test_orders_sold_out.py`,
  `test_menu_router.py`: cubren el 409 manual y la forma del menú; deben seguir en verde salvo lo
  que el motor cambie a propósito.
Ninguno lleva el prefijo literal `CONGELA comportamiento actual:` en lo revisado, pero se trata
igual: no se editan para «hacerlos pasar» sin la decisión registrada.

---

## D18 — Entrega incremental (Principio VI)

Seis unidades verificables e independientemente revertibles (detalle en [plan.md](./plan.md)):
docs → motor + snapshot + menú (backend) → eventos manual e inventario (backend) → 409 unificado
(backend) → núcleo cliente (frontend) → superficies (frontend). El backend queda desplegable y
retrocompatible tras cada paso: el evento nuevo es ignorado por clientes viejos (no está registrado
en su `KNOWN_EVENT_TYPES`) y el 409 conserva todas las claves previas.

**Despliegue**: backend primero (sin riesgo para el frontend viejo), frontend después. Los
navegadores con pestañas viejas necesitan una recarga manual única para recibir el cliente nuevo
(mismo caso que la spec 134, `SwUpdate`).

---

## D19 — El guardia por módulo `inventario` se conserva en cada punto de entrada

**Hallazgo** (verificado en el código al analizar las tareas): la validación de stock de
**adiciones y toppings** solo se hace si el plan incluye el módulo `inventario`
(`has_module_access(db, tenant, "inventario")` en `consolidation.py`, `toppings.py` y
`additions.py`), y un test lo congela (`test_stock_insuficiente_sin_modulo_de_inventario_no_rechaza`).
La receta y las opciones de la línea principal **no** consultan el módulo: `create_order` y el
carrito no reciben el módulo, y el descuento usa solo `tracks_inventory`.

**Decisión**: `compute_availability` y el menú/snapshot no consultan el módulo (hoy
`_option_availability` tampoco; T005 lo congela, y `tracks_inventory` solo se activa con el módulo,
spec 064). `ensure_orderable` recibe `toppings_inventory: bool` y cada punto de entrada lo pasa
**igual que hoy** decide si valida el stock de adiciones y toppings; con `False` se omite solo ese
chequeo (la marca manual `sold_out` de una adición sigue aplicando).

**Alternativa descartada**: que el motor resuelva el módulo por tenant. Cambiaría `create_order` y
el carrito, que hoy no lo consultan, sin una decisión de negocio registrada (Principio II).
