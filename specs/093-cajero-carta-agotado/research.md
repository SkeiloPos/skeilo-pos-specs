# Research: Carta del menú para Cajero con estado Agotado

**Spec**: [spec.md](./spec.md) | **Fecha**: 2026-10-03

Este documento resuelve las decisiones técnicas para implementar la spec sobre los dos
repos existentes: `pos-backend` (FastAPI + PostgreSQL 16, schema-per-tenant) y
`pos-heladeria` (Angular). No queda ningún `NEEDS CLARIFICATION` pendiente del spec. Lo
que sigue es investigación técnica sobre el código real (dos agentes de exploración
revisaron ambos repos antes de escribir este documento) para decidir **cómo** implementar
las reglas de negocio ya cerradas en `spec.md`.

**Hallazgo de partida que cambia el alcance técnico**: el campo `Product.available`
(`app/models/product.py:37-39`) **ya existe** y ya es, literalmente, el "Agotado" que pide
esta spec ("Disponibilidad operativa... 'agotado temporal' sin dar de baja el producto.
Distinto de `active`"). También ya existe en el frontend un toggle administrador completo
para él (`ProductService.toggleAvailable()`, badge "Agotado", toast de confirmación) y ya
existe el ítem de sidebar "Carta del menú" bajo una sección "CATÁLOGO" — hoy ambos
exclusivos de `ADMIN`. **Esta spec no crea el concepto de "Agotado" desde cero: lo
extiende** a un segundo rol (Cajero) y, sobre todo, le da por primera vez un **efecto
real** sobre pedidos nuevos (hoy el flag existe pero solo se usa para ocultar productos
del menú QR — en ningún punto de carrito/Terminal de mesas se consulta).

## D1 — Cómo se identifica el rol Cajero en el backend

**Decisión**: El literal de `Role.name` para Cajero es `"CASHIER"`, no `"CAJERO"` —
confirmado en `app/core/db.py:230` (`ROLE_NAMES = ("SUPER_ADMIN", "ADMIN", "CASHIER",
"MESERO")`) y en `app/api/v1/users/schemas.py:8-12` (`RoleName` enum). `"CAJERO"` solo
existe como valor de un enum no relacionado (`ActorType.CAJERO` en
`app/core/order_audit.py:49`, para auditoría de ciclo de vida de órdenes) — no se debe
confundir con `Role.name`. "Cajero" es únicamente la etiqueta en español que usa la
interfaz (`UserRole.CASHIER = 'cashier'` en el frontend, mostrado como "Cajero").

**Rationale**: usar el literal real evita introducir una comparación que nunca
coincidiría con ningún usuario real (`user.role.name == "CAJERO"` sería un 403
permanente, indetectable salvo en pruebas manuales).

## D2 — Nueva dependencia de autorización: "Admin o Cajero"

**Decisión**: Agregar `require_tenant_admin_or_cashier` en `app/core/dependencies.py`,
con la misma forma que `require_tenant_admin` (línea ~338-344):

```python
def require_tenant_admin_or_cashier(user: User = Depends(get_current_user)) -> User:
    if not user.role or user.role.name not in {"ADMIN", "CASHIER"}:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN,
                             detail="Acceso de administrador o cajero requerido")
    return user
```

**Rationale**: no existe ningún helper multi-rol reutilizable hoy — solo
`require_tenant_admin` (un solo rol, hardcodeado) y el mecanismo de default-deny de
Mesero (`_enforce_mesero_scope`, una lista de rutas permitidas, de forma arquitectónica
distinta porque Mesero necesita "todo excepto..." mientras que esta spec necesita "nada
excepto un endpoint muy puntual"). Replicar la forma de `require_tenant_admin` es más
simple y más legible que adaptar el mecanismo de lista de Mesero para un caso de dos
roles permitidos.

**Alternativas consideradas**:
- *Extender `_MESERO_ALLOWED_ROUTES` a un mecanismo genérico por rol*: rechazada — es un
  refactor de un mecanismo que hoy solo sirve a Mesero, no relacionado con esta
  funcionalidad (Principio V). Mesero no entra en el alcance de esta spec y no debe
  ganar ni perder acceso por este cambio.
- *Reutilizar `require_tenant_admin` y dejar que el Cajero llegue por otro camino*:
  rechazada — el objetivo explícito de la spec es que el Cajero NO dependa del
  Administrador; un endpoint exclusivo de Admin no cumple eso.

## D3 — Nuevo endpoint dedicado para el interruptor "Agotado" (no reusar el PATCH completo)

**Decisión**: Nuevo endpoint `PATCH /products/{id}/availability`, body `{"available":
bool}`, protegido por `require_tenant_admin_or_cashier` — **distinto** del `PATCH
/products/{id}` existente (que sigue exigiendo `require_tenant_admin` sin cambios, para
nombre/categoría/descripción/imagen/receta/presentaciones). El frontend migra
`ProductService.toggleAvailable()` para llamar a este endpoint nuevo en vez del PATCH
completo, para los dos roles (Admin incluido, por consistencia — un único camino en
código para el mismo interruptor, FR-009).

**Rationale**: `ProductUpdate` (el body del PATCH completo) acepta cualquier combinación
de campos (`category_id`, `name`, `image_url`, `variants`, etc.) y ese endpoint está —
correctamente— reservado a `require_tenant_admin`. Dar acceso de Cajero a ese endpoint
completo violaría FR-007/FR-024 (el Cajero no puede crear, editar ni desactivar
productos) aunque el frontend nunca le muestre esos campos: la superficie de la API
quedaría abierta a cualquier petición directa. Un endpoint angosto, que solo acepta
`available`, es la forma de dar el permiso mínimo necesario (FR-009) sin tocar en nada
la autorización ya existente de `create_product`/`update_product`/`soft_delete`.

**Alternativas consideradas**:
- *Relajar `require_tenant_admin` del PATCH completo a `require_tenant_admin_or_cashier`
  y validar por campo dentro del service*: rechazada — movería la superficie de ataque
  de "endpoint equivocado" a "lógica de service equivocada", con más código y más riesgo,
  para el mismo resultado.

## D4 — Un producto inactivo no admite el toggle (FR-011)

**Decisión**: El nuevo endpoint `PATCH /products/{id}/availability` responde `409
Conflict` (`{"error": "No se puede cambiar la disponibilidad de un producto inactivo"}`)
cuando `product.active is False`, sin importar el valor de `available` solicitado. El
PATCH completo existente (`ProductUpdate`, solo Admin) no se toca: sigue permitiendo que
el propio Admin edite `active` y `available` en la misma petición si así lo decide, como
ya puede hacer hoy — esta restricción nueva es específica del interruptor dedicado al
que ahora también llega el Cajero.

**Rationale**: la spec exige que el interruptor quede deshabilitado para un producto
inactivo (escenario 10) para ambos roles; bloquearlo en el endpoint dedicado (que es el
único que el frontend usará para el interruptor, Admin incluido tras D3) implementa la
regla una sola vez, en el único lugar que la necesita, sin tocar `update_product` (que
no es "el interruptor", es el formulario completo de edición, fuera de alcance de esta
spec por Principio V).

## D5 — Trazabilidad de quién y cuándo (FR-013): columnas nuevas + `AuditLog` existente

**Decisión**: Dos cambios complementarios, reutilizando patrones ya existentes en el
repo:
1. Dos columnas nuevas, nullable, en `tenant.products`: `available_changed_at`
   (`DateTime`) y `available_changed_by_name` (`String`, snapshot del nombre — **no**
   FK dura a `shared.users`, igual que `AuditLog.user_id`/`user_name` ya hacen, porque
   `users` vive en el schema `shared` y `products` en el schema `tenant`: una FK cruzada
   de schema no es el patrón de este proyecto). Se actualizan en cada cambio exitoso del
   nuevo endpoint. Sirven para pintar "desde hace unos segundos" en el listado y el
   detalle sin una consulta adicional por fila.
2. Una entrada en la tabla genérica `AuditLog` (`app/models/audit_log.py`, ya existe,
   schema `tenant`) vía el helper `record_audit()` (`app/core/audit.py:10-24`, ya
   existe): `record_audit(db, action="availability_changed", entity="product",
   entity_id=product.id, user=user, payload={"available": nuevo_valor, "previous":
   valor_anterior})`. Mismo patrón que ya usa `promotions/router.py` para
   crear/actualizar promociones — no se inventa un mecanismo de auditoría nuevo.

**Rationale**: ninguna de las dos piezas por sí sola alcanza. Solo las columnas
denormalizadas no dejan un historial completo (cada cambio nuevo pisa al anterior — basta
para "desde hace X" pero no para auditar cambios previos). Solo `AuditLog` sin las
columnas obligaría a una subconsulta (o un join) por producto para pintar el listado, con
riesgo de N+1. Combinar ambas reutiliza exactamente los dos mecanismos que el repo ya
tiene para este tipo de necesidad ("dato rápido de mostrar" + "historial auditable"), sin
agregar un tercero.

**Alternativas consideradas**:
- *Solo `AuditLog`, sin columnas en `Product`*: rechazada por el costo de N+1 al listar.
- *Una tabla de historial propia para `Product`*: rechazada — `AuditLog` ya es genérica
  (`entity`/`entity_id`/`payload`) y cubre el caso sin crear una tabla nueva (Principio
  IX: preferir lo que ya existe).

## D6 — Efecto en Terminal de mesas y menú QR: un único punto de cambio (`_build_menu`)

**Decisión**: `GET /menu` (usado hoy por la Terminal de mesas vía `MenuService.loadMenu()`)
y `GET /menu/qr-token/{token}` (comensal) son la **misma función**,
`_build_menu()` en `app/api/v1/menu/router.py:83`. Un solo cambio ahí resuelve los
escenarios 5 y 6 a la vez:
1. Quitar `Product.available.is_(True)` del `WHERE` de la consulta de productos (línea
   ~103) — un producto agotado deja de desaparecer de la respuesta.
2. Agregar un campo **nuevo**, `sold_out: bool`, a `MenuProductResponse` (`app/api/v1/
   menu/schemas.py:92-108`), calculado como `not product.available` (el flag manual de
   esta spec).
3. **No tocar** el campo `available` que ya existe en `MenuProductResponse` — ese campo
   significa hoy "puede pedirse dado el stock de sus opciones obligatorias" (comentario
   en la propia clase, línea 106-107: "False si ninguna presentación se puede pedir"),
   un concepto **distinto** calculado por `test_menu_router.py` (`CONGELA comportamiento
   corregido`, characterization test). Es una colisión de nombre con el `Product.
   available` del modelo (incidental: el modelo usa "disponible = no agotado" y la
   respuesta de menú usa "disponible = pedible por stock"), no la misma cosa — por eso
   el flag manual nuevo necesita su **propio** campo (`sold_out`) en vez de reusar
   `available`.
4. En el frontend, `pos-catalog-drawer.component.ts` (grilla de "Nueva orden" de la
   Terminal) y `public-menu.component.ts` (grilla del menú QR) — ninguno de los dos
   consulta hoy disponibilidad a nivel de producto completo (solo existe ese patrón a
   nivel de variante/opción dentro del modal compartido `ProductSelectComponent`) — pasan
   a leer `product.sold_out` para atenuar la tarjeta, mostrar la etiqueta "Agotado" y
   deshabilitar abrir/agregar, replicando visualmente el patrón ya usado para variantes
   agotadas dentro de `ProductSelectComponent` (`:146-154`).

**Rationale**: un solo punto de cambio en el backend cubre ambas superficies porque ya
comparten código — exactamente el tipo de apalancamiento que evita duplicar la regla de
negocio en dos sitios. Mantener separado el campo nuevo del campo existente evita un bug
sutil (un producto "no pedible por stock" pasando a leerse como "agotado manual" o
viceversa) y no toca código protegido por characterization test.

Este cambio de comportamiento (dejar de ocultar productos agotados) queda registrado como
decisión de negocio en `specs/000-reconocimiento/registro-de-anomalias.md` (A-104), según
exige el Principio II de la constitución.

## D7 — Bloqueo real al armar/confirmar un pedido (Historia 2)

**Decisión**: agregar una validación de `variant.product.available` en los puntos que ya
validan `variant.active` hoy (mismo lugar, misma forma, un `if` más):

| Flujo | Archivo:función | Qué se agrega |
|---|---|---|
| Agregar ítem al carrito (comensal) | `app/api/v1/cart/service.py::add_item`/`update_item` | Si `not variant.product.available`: `HTTPException(409, {"error": f"«{nombre}» está agotado y no se puede agregar al pedido", "producto": nombre})` — mismo shape que ya usa `sold_out_detail()` (`app/catalog_engine/consumption.py:175-191`) para el agotado por inventario, reutilizado para el agotado manual. |
| Confirmar carrito → crea la orden (comensal) | `app/api/v1/cart/service.py::submit_cart` (línea ~678, junto al `check_availability` existente) | Recorre todos los ítems del carrito antes de crear nada; si alguno tiene `product.available=False`, rechaza con `HTTPException(409, {"error": "Los siguientes productos están agotados: X, Y", "productos_agotados": ["X", "Y"]})` y **no crea la orden** (escenario 7). Este es el único shape multi-ítem nuevo de la spec — no existía precedente de "nombrar varios productos a la vez" (ver research, hallazgo del agente de exploración backend). |
| Agregar ítem a una orden de mesa (Terminal de mesas) | `app/api/v1/orders/consolidation.py::add_item_to_order` | Mismo chequeo single-item que en cart `add_item`. |
| Crear pedido manual (Terminal de mesas, "Nueva orden") | `app/api/v1/orders/service.py::create_order` | Mismo chequeo multi-item que en `submit_cart` (crea varios ítems en una sola llamada). |

El front-end, además, deshabilita visualmente el botón de agregar (FR-020) para que el
caso feliz del escenario 5/6 nunca llegue a disparar el 409 — el backend es la garantía
real (escenario 7 exige el rechazo del lado servidor cuando el estado cambió *después* de
que el comensal ya tenía el producto en el carrito, donde el frontend no puede haberlo
prevenido).

**Rationale**: ninguno de estos cuatro puntos valida hoy `Product.available` — el agente
de exploración backend confirmó que el flag solo se usaba (antes de esta spec) para
filtrar el menú QR. Insertar el chequeo junto al `variant.active` ya existente, con el
mismo nivel de granularidad (por variante, ya que cada `OrderItem`/ítem de carrito
referencia una `ProductVariant`, y `ProductVariant.product` ya está disponible sin
consulta extra en los cuatro sitios), es el cambio mínimo y más consistente con el estilo
ya establecido del código.

**Alternativas consideradas**:
- *Un único helper compartido `ensure_product_available()` en `catalog_engine` o
  `line_pricing`, llamado desde los cuatro sitios*: considerada y preferida para la
  implementación (evita duplicar el mensaje/shape cuatro veces), documentada aquí como
  la forma concreta de aplicar esta decisión, no como una alternativa descartada.
- *Rechazar ítem por ítem en `submit_cart`/`create_order` (abortar en el primero)*:
  rechazada — el escenario 7 exige nombrar el producto agotado y el FR-021 pide
  identificar **todos** los agotados de una vez, no obligar a reintentar uno por uno.

## D8 — Restringir datos de receta/inventario para Cajero por API (FR-025, escenario 12)

**Decisión**: `GET /variants/{variant_id}/recipe` (`app/api/v1/catalog/router.py:171-182`)
pasa de `Depends(get_current_user)` a una nueva verificación que **excluye** a `CASHIER`
(manteniendo a `ADMIN` con acceso, y preservando el bloqueo ya existente de `MESERO` por
el default-deny que no incluye esta ruta en su lista). El resto de `ProductResponse`/
`ProductDetailResponse`/`ProductListResponse` ya no incluye costo ni receta ni
`inventory_item_id` para ningún rol (verificado: esos campos nunca estuvieron en esos
schemas) — no se necesita ningún cambio ahí.

`GET /variants/{variant_id}/option-groups` **no se restringe**: aunque
`VariantOptionGroupResponse.quantity_per_option` está ligado al descuento de inventario,
este endpoint es el que ya usa el flujo existente de la Terminal de mesas para que
cualquier Cajero arme un pedido con opciones/adicionales — bloquearlo rompería una
funcionalidad protegida que el Cajero ya usa hoy (Principio II). La spec no pide ocultar
"grupos de opciones" (no aparece en la lista de lo que el detalle de producto debe
excluir en el escenario 9: solo "costos, recetas ni datos de inventario"); "receta" se
interpreta de forma literal como el BOM (`RecipeItemResponse`, que expone
`inventory_item_id` sin ningún propósito en la toma de pedidos), no como la configuración
de selección de opciones que el comensal sí ve.

**Rationale**: es la única restricción de API nueva que hace falta — todo lo demás que
la spec pide ocultar ya estaba fuera de los schemas existentes. Diferenciar receta
(bloquear) de grupos de opciones (no tocar) evita una regresión real sobre Terminal de
mesas, que no está en el alcance de esta spec y que la constitución protege por defecto
(Principio II).

## D9 — Detalle de producto de solo lectura con presentaciones y precio, sin receta (escenario 9)

**Decisión**: extender `ProductDetailResponse` (hoy idéntico a `ProductResponse`, sin
variantes) con `variants: list[VariantResponse]` (el modelo ya existente en
`app/api/v1/catalog/schemas.py:29-39` — solo `id`, `product_id`, `sku`, `price`,
`active`, `presentation_id`, `presentation_name`; **sin** receta ni grupos de opciones),
filtrado a `v.active`. `GET /products/{id}` pasa a incluir esta lista para **cualquier**
rol que lo consulte (Admin incluido) — no se condiciona por rol, porque `VariantResponse`
ya es, por diseño, la forma "sin receta/costo/inventario" (a diferencia de
`VariantSaveOut`, que sí las trae y que sigue siendo exclusiva de las respuestas de
`POST`/`PATCH /products`, sin cambios).

**Rationale**: el agente de exploración frontend confirmó que no existe hoy ninguna
vista de detalle de solo lectura (solo lista + formulario de edición) y que el
formulario de edición de Admin obtiene sus presentaciones por **otra** llamada
(`loadVariants(id)`, `GET /variants?product_id=...`), no por `GET /products/{id}` — así
que ampliar esta respuesta no interfiere con el formulario de edición existente
(Principio II: nada que ya lo consuma deja de funcionar). Reusar `VariantResponse` en vez
de crear un tercer DTO evita duplicar un shape ya probado.

## D10 — Concurrencia: "última petición gana" sin bloqueo (FR-016, escenario 14)

**Decisión**: el nuevo endpoint `PATCH /products/{id}/availability` hace una actualización
simple de una sola columna (`UPDATE ... SET available = :valor, available_changed_at =
now(), available_changed_by_name = :nombre WHERE id = :id`), **sin** `SELECT ... FOR
UPDATE` ni columna de versión.

**Rationale**: el agente de exploración backend confirmó que hoy `Product.active` y
`Product.available` ya se actualizan así (sin ningún bloqueo) y que el único patrón de
concurrencia real del repo (`with_for_update()`) se reserva para filas disputadas con
lógica de negocio acumulativa (stock, contador de facturas, turnos de caja) — nunca para
un flag booleano simple. Una sola sentencia `UPDATE` sobre una sola fila ya es atómica a
nivel de PostgreSQL: dos peticiones casi simultáneas producen dos `UPDATE` secuenciales,
y la que el servidor procesa después dejar el valor final — exactamente "la última
petición gana, sin estado inconsistente" (FR-016), sin necesidad de ningún mecanismo
adicional.

**Alternativas consideradas**: `with_for_update()` sobre la fila del producto — rechazada
por ser un mecanismo nuevo para esta tabla, no justificado por ningún requisito que lo
pida (el propio escenario 14 solo exige que la última gane, no un orden específico ni un
409 por conflicto).

## D11 — Frontend: reutilizar el ítem "Carta del menú" existente, no crear uno nuevo

**Decisión**: agregar `UserRole.CASHIER` al arreglo `roles` del `NavItem` "Carta del
menú" ya existente (`navigation.config.ts:51-ish`, hoy `[UserRole.ADMIN]`) y a la ruta
`/dashboard/products` en `routes.ts` (hoy `roleGuard([UserRole.ADMIN])`). Dentro de
`ProductsPageComponent`, un `computed(() => auth.currentUser()?.role === UserRole.ADMIN)`
— mismo patrón que `cash-session.store.ts:136` ya usa para Caja (pantalla compartida
Admin+Cajero con acciones admin-only adentro) — oculta "Nuevo producto" y las acciones de
editar/desactivar cuando el usuario no es Admin, dejando visibles el listado, la
búsqueda/filtro y el interruptor "Agotado" para ambos roles.

Al hacer clic en una fila ("Ver detalle"): Admin sigue navegando al formulario de edición
existente (`/dashboard/products/:id`, sin cambios, Principio II); Cajero navega a una
vista nueva, de solo lectura (ver D9), en una ruta nueva (p. ej.
`/dashboard/products/:id/detalle`) con `roleGuard([UserRole.ADMIN, UserRole.CASHIER])`
para que Admin también pueda usarla si quiere una vista rápida sin entrar a editar.

**Rationale**: evita duplicar la sección "CATÁLOGO"/el ítem de sidebar (ya existe, solo
le faltaba el rol) y reutiliza el único patrón ya establecido en este repo para "una
misma pantalla, con una acción admin-only adentro" en vez de inventar un mecanismo de
visibilidad nuevo. Mantener la navegación de Admin sin cambios (sigue yendo al formulario
de edición) respeta el escenario 15 ("mantengo todas mis acciones actuales") sin
ambigüedad.

## D12 — Toggle del interruptor: reusar el patrón no-optimista ya existente (escenario 13)

**Decisión**: no se introduce ningún mecanismo de "optimistic update + rollback". Se
reutiliza tal cual el patrón que ya usan `toggleActive`/`toggleAvailable`
(`product.service.ts:261-278`) y los toggles equivalentes de Categorías/Presentaciones:
`isSubmitting → await PATCH → éxito: invalidar query (re-render desde el dato real del
servidor) → toast de éxito` / `fallo: error signal → toast de error, la fila nunca
cambió visualmente porque la invalidación nunca ocurrió`.

**Rationale**: el agente de exploración frontend confirmó que **no existe ningún**
patrón optimista en el repo — introducir uno sería un mecanismo nuevo no relacionado con
esta funcionalidad (Principio V). Y no hace falta: como la fila nunca se actualiza
visualmente hasta que el PATCH confirma éxito, un fallo de red dentro de esta lógica ya
dejan la fila "en su estado anterior" sin ningún código adicional — satisface el
escenario 13 (el interruptor "vuelve" a su estado previo porque nunca lo abandonó) con
el mecanismo que ya existe.

## D13 — Texto de tiempo relativo ("desde hace unos segundos")

**Decisión**: crear una utilidad nueva y mínima (pipe Angular puro,
`relative-time.pipe.ts`, sin dependencia externa) que formatee `available_changed_at`
(ver D5) en español de Colombia con la granularidad que ya usa el ejemplo de la spec
("hace unos segundos", "hace 5 minutos", "hace 2 horas", cayendo a fecha absoluta — vía
el `TenantDatePipe` ya existente — pasado cierto umbral, p. ej. 24 horas).

**Rationale**: el agente de exploración frontend confirmó que no existe ninguna utilidad
de tiempo relativo en el repo ni ninguna dependencia (`dayjs`/`date-fns`) ya instalada
para ese propósito — es, genuinamente, pieza nueva y pequeña, sin alternativa a reusar.
No se agrega una dependencia nueva para esto (Principio IX): la lógica de "hace X
tiempo" con 3-4 escalones es trivial de escribir a mano y no justifica una librería.
