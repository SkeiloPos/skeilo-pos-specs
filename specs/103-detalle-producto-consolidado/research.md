# Research: Consolidar receta y grupos de opciones en el detalle de producto

## D1 — Nuevo tipo de respuesta `VariantDetailResponse`, sin tocar `VariantResponse`

**Decisión**: crear `VariantDetailResponse(VariantResponse)` en
`pos-backend/app/api/v1/products/schemas.py`, agregando `recipe: list[RecipeItemResponse] =
Field(default_factory=list)` y `option_groups: list[VariantOptionGroupResponse] =
Field(default_factory=list)` (ambos tipos ya existen, `catalog/schemas.py:85-90` y `:115-123` —
sin cambios). `ProductDetailResponse.variants` (`products/schemas.py:114-120`) pasa de `list[VariantResponse]`
a `list[VariantDetailResponse]`. `VariantResponse` en sí **no se toca**.

**Rationale**:

- `VariantResponse` es un tipo compartido fuera de este endpoint (usado por `GET
  /products/{id}/variants`, el listado sin receta que alimenta `loadVariants()` en el frontend —
  ver D4). Su propio comentario en `products/schemas.py:115-118` documenta que carece de receta/
  grupos de opciones **a propósito**, citando FR-018 de la spec 093. Modificarlo directamente
  arrastraría ese cambio a cualquier otro consumidor presente o futuro de `VariantResponse`, sin
  ninguna necesidad real — un tipo nuevo que **extiende** sin modificar el original preserva esa
  garantía para todo lo que no sea este endpoint (Principio II, FR-004 de esta spec).
- Mismo patrón que ya usa el propio `ProductDetailResponse` para envolver `ProductResponse`
  (`service.py:85-97`: `ProductDetailResponse(**base.model_dump(), variants=[...])`) — extender un
  tipo existente agregando un campo, no reescribirlo.

**Alternatives considered**:

- **Agregar `recipe`/`option_groups` como campos opcionales directamente en `VariantResponse`**.
  Rechazada: rompería la garantía explícita que ese mismo archivo documenta para FR-018 en
  cualquier otro lugar donde `VariantResponse` se reutilice (hoy `GET /products/{id}/variants`,
  potencialmente más adelante) — el campo quedaría `None`/vacío ahí, pero la superficie del tipo
  ya no comunicaría la garantía con la misma claridad, y un futuro cambio en ese otro endpoint
  podría poblarlo por error.

## D2 — Carga ansiosa (`selectinload`) en una consulta dedicada, sin tocar `get_or_404` genérico

**Decisión**: `ProductService` gana un método nuevo (p. ej. `get_detail_or_404`) que reemplaza, solo
para este endpoint, el `db.get(Product, id)` de `get_or_404` (`app/core/crud.py:9-14`) por:

```python
select(Product).where(Product.id == id).options(
    selectinload(Product.variants).selectinload(ProductVariant.recipe_items),
    selectinload(Product.variants).selectinload(ProductVariant.option_groups),
)
```

mismo patrón de `selectinload` encadenado que ya usa `menu/router.py:109-114` para evitar N+1 en
su propio endpoint — aquí sin encadenar hasta `.option_group`/`.options` porque
`VariantOptionGroupResponse` (D1) solo necesita las columnas propias de la fila de enlace
(`option_group_id`, `min_select`, `max_select`, `quantity_per_option`), no el grupo completo.

**Rationale**:

- Sin esta carga ansiosa, serializar `recipe`/`option_groups` por variante dispararía una consulta
  `SELECT` perezosa (`lazy="select"`, default de SQLAlchemy) por cada relación de cada variante —
  exactamente el patrón N+1 que esta spec busca eliminar, solo que movido del lado del cliente
  (FR-001, FR-002) al lado del servidor.
- `get_or_404(db, Product, id)` (`app/core/crud.py`) es genérico y lo usan otros módulos con un
  `db.get()` plano porque no necesitan precargar relaciones — cambiar su firma o su comportamiento
  para aceptar `.options()` afectaría a todos sus llamadores actuales sin necesidad (Principio II);
  un método nuevo, específico de este endpoint, no tiene ese efecto.

**Alternatives considered**:

- **Modificar `get_or_404` para aceptar `*options: ExecutableOption` opcionales**. Considerada
  razonable en abstracto, pero rechazada para esta spec: ampliaría la superficie de una utilidad
  compartida por un beneficio que solo necesita un llamador hoy — puede revisitarse si aparece un
  segundo caso real (Principio V, no generalizar por anticipado).

## D3 — Ocultar la receta a Cajero dentro del propio servicio, no vía `forbid_cashier`

**Decisión**: el handler de `GET /products/{id}` (`products/router.py:61-66`) sigue dependiendo de
`get_current_user` (no de `forbid_cashier`) — el Cajero debe seguir recibiendo 200 con el producto
y sus variantes, igual que hoy en "Carta del menú → detalle de producto". Dentro de
`to_detail_response(product, user)`, al construir cada `VariantDetailResponse`, `recipe` se puebla
con `[RecipeItemResponse.model_validate(r) for r in v.recipe_items]` **solo si** `user.role.name !=
"CASHIER"`; si es `"CASHIER"`, `recipe=[]`. `option_groups` se puebla siempre, para todos los
roles (ver Rationale).

**Rationale**:

- `forbid_cashier` (`app/core/dependencies.py:389-400`) es binario: 403 o nada. Usarlo aquí
  rechazaría también `variants`/`price`/`presentation` para el Cajero, rompiendo "Carta del menú →
  detalle de producto" (FR-004) — necesita ver el producto, solo no su receta.
- `GET /variants/{id}/option-groups` (`catalog/router.py:207-222`) usa `get_current_user`, no
  `forbid_cashier` — el Cajero ya puede consultar grupos de opciones hoy (sin costo/insumo
  expuesto en esa forma: `VariantOptionGroupResponse` no trae `inventory_item_id` ni precio).
  Replicar esa misma distinción (grupos sí, receta no) es lo que exige FR-003 de esta spec, no una
  regla nueva — es la continuidad exacta de lo que ya decide el Principio de autorización vigente
  (spec 093, FR-018) y de cómo ya está implementado hoy en los dos endpoints independientes.
- No existe en el proyecto un precedente de "200 siempre, oculta un campo según el rol" (la
  investigación de este research no encontró ninguno en `dependencies.py`/`products/service.py`/
  `menu/*`) — es territorio nuevo, documentado aquí explícitamente para que `tasks.md` lo pruebe
  como su propio caso, no una variante menor de algo ya probado.

**Alternatives considered**:

- **Endpoint separado `GET /products/{id}/detail-with-recipe`, exclusivo de Admin**. Rechazada:
  duplica casi todo el contrato de `GET /products/{id}` por una diferencia de un campo; además
  "Carta del menú → detalle de producto" seguiría usando el endpoint viejo sin `option_groups`
  embebido si alguna vez los necesitara, perdiendo la consistencia que FR-005 pide.
- **Devolver `recipe: null` en vez de `recipe: []` para Cajero**. Rechazada sin impacto funcional
  real, pero `[]` es consistente con el shape ya usado por los endpoints independientes
  (`list[RecipeItemResponse]`, nunca `null`) y evita que el frontend tenga que distinguir
  "sin receta" de "no autorizado a verla" — ninguna historia de esta spec necesita esa distinción.

## D4 — Frontend: `getProductDraft()` consume los datos embebidos; se retira el fetch paralelo por variante

**Decisión**: `ProductService.getProductDraft()` (`pos-heladeria/src/app/modules/products/services/product.service.ts`)
deja de disparar `Promise.allSettled(activeVariants.map(v => Promise.all([fetchVariantRecipeRaw(v.id),
fetchVariantOptionGroupsRaw(v.id)])))` (introducido por la spec 102, Historia 2). En su lugar,
`getProduct()`/`getProductDraft()` leen `recipe`/`option_groups` directamente del `variants[]` que ya
trae la respuesta de `GET /products/{id}` (ahora con D1-D3 aplicados) y construyen cada
`VariantDraft` a partir de ahí. `loadVariants()` (`GET /products/{id}/variants`, sin filtro
`?active=`) **se mantiene sin cambios**: sigue siendo la única fuente de las variantes
**desactivadas** (`draft.deactivated`), que `GET /products/{id}` nunca incluye (`to_detail_response`
ya filtra `if v.active`, antes y después de esta spec). El nombre de cada grupo de opciones (que el
link embebido no trae, solo `option_group_id`) se sigue resolviendo contra
`optionGroupService.groups()` — se mantiene `ensureOptionGroupsLoaded()`, ejecutada una vez antes
de mapear los `variants[]` recibidos, ya no una vez por variante en paralelo.

**Rationale**:

- Dos peticiones totales (`GET /products/{id}` y `GET /products/{id}/variants`), sin importar
  cuántos tamaños tenga el producto — cumple SC-001 (cero peticiones adicionales de receta/grupos
  por tamaño) y SC-002 (número total constante) sin necesitar eliminar `loadVariants()`, que sigue
  resolviendo un dato que `GET /products/{id}` no cubre (las desactivadas).
- El link de grupo de opciones embebido (D1) es la misma forma que ya devolvía el endpoint
  independiente (`VariantOptionGroupResponse`, sin el nombre del grupo) — la resolución de nombre
  contra el catálogo local no cambia, solo deja de repetirse una vez por variante en paralelo.

**Alternatives considered**:

- **Eliminar también `loadVariants()`/`GET /products/{id}/variants`**. Rechazada: esa petición
  resuelve las variantes desactivadas, que `GET /products/{id}` nunca incluyó ni esta spec le pide
  incluir (FR no lo exige; Edge Cases de esta spec documentan que las desactivadas siguen sin
  receta/grupos embebidos). Eliminarla rompería `draft.deactivated` y el flujo de "restaurar"
  (FR-006).

## D5 — Retiro de `loadError`/`retryVariantLoad()`/`retryVariant()`: quedan sin escenario (FR-009)

**Decisión**: se retiran, del frontend, los tres elementos que la spec 102 (Historia 2) introdujo
específicamente para el fallo parcial de la carga en paralelo por variante: el campo
`VariantDraft.loadError`, el método `ProductFormComponent.retryVariantLoad()`, el control
"Reintentar" de la plantilla que dependía de `v.loadError`, y `ProductService.retryVariant()` (el
único método que `retryVariantLoad()` llamaba). `getVariantRecipe()`/`getVariantOptionGroups()`
(y sus privados `fetchVariantRecipeRaw`/`fetchVariantOptionGroupsRaw`) **no se tocan**: siguen
siendo necesarios para `restoreVariant()` (FR-006).

**Rationale**:

- `loadError` solo podía quedar en `true` cuando, dentro de `Promise.allSettled` sobre las
  variantes, la promesa de **una** variante se rechazaba mientras las demás sí resolvían (research.md
  D2 de la spec 102). Con D2/D4 de esta spec, la carga inicial pasa a ser una sola consulta SQL
  (una sola petición HTTP): o falla completa (ya cubierto por el manejo de error existente de
  `getProduct()`, sin relación con `loadError`) o resuelve completa con los 0-N tamaños que tenga
  el producto. No queda ninguna ejecución del código donde `loadError` pueda volverse `true` —
  dejarlo sería una rama muerta, no una funcionalidad en reserva.
- Principio V (no refactor oportunista) no aplica aquí en sentido contrario: retirar código que
  esta misma spec deja inalcanzable es consecuencia directa del cambio que se está haciendo, no
  una limpieza no relacionada — dejarlo introduciría una rama de código que ningún test podría
  ejercitar honestamente después de esta spec.

**Alternatives considered**:

- **Dejar `loadError`/`retryVariantLoad()`/`retryVariant()` tal cual, inertes**. Rechazada: un
  control de "Reintentar" que nunca puede aparecer (porque nada vuelve a poner `loadError` en
  `true`) es peor que no tenerlo — confunde a quien lea el código después preguntándose cuándo se
  dispara, y a `tasks.md` le tocaría mantener una prueba de un camino que ya no existe.

## D6 — Las variantes desactivadas se mueven a un campo nuevo en la misma respuesta (ajuste posterior, 2026-10-08)

**Decisión**: `ProductDetailResponse` gana `deactivated: list[VariantResponse]` (mismo tipo ya
existente, sin receta/grupos de opciones), poblado en `to_detail_response()` con `[v for v in
product.variants if not v.active]` — la misma relación `product.variants` que D2 ya precarga para
`variants`, filtrando al revés. El frontend deja de llamar a `GET /products/{id}/variants` desde
`getProductDraft()`: construye `deactivated` directamente de este nuevo campo.
`ProductService.loadVariants()`/`loadDeactivated()` **no se eliminan** — siguen siendo el único
camino para refrescar la lista de desactivados en otros puntos del formulario (p. ej. tras un
conflicto de nombre al guardar).

**Rationale**:

- Tras implementar la Historia única, el dueño/desarrollador del proyecto observó en el panel de
  red que `GET /products/{id}/variants` seguía disparándose al abrir el formulario, y pidió
  quitarla por considerarla redundante con el detalle ya embebido. Investigar confirmó que **sí**
  cubría algo que el detalle no traía (las desactivadas) — la solución correcta es hacer que ese
  dato exista en la misma respuesta, no eliminar la petición y perder la función de restaurar un
  tamaño (Clarifications, 2026-10-08).
- `product.variants` (la relación ORM) ya trae TODAS las variantes (activas e inactivas) desde
  D2 — `to_detail_response` ya hacía `if v.active` para filtrar `variants`; agregar `deactivated`
  con el filtro inverso no agrega ninguna consulta nueva, solo una segunda lista construida sobre
  los mismos datos ya en memoria.
- Reutilizar `VariantResponse` (no `VariantDetailResponse`) para `deactivated` es deliberado: una
  variante desactivada no se edita in place en el formulario (FR-006, restaurarla sigue pidiendo
  su receta/grupos por separado cuando el usuario de verdad decide restaurarla) — incluirle
  receta/grupos de opciones ahí sería trabajo sin ningún consumidor.

**Alternatives considered**:

- **Eliminar `GET /products/{id}/variants` de `getProductDraft()` sin agregar `deactivated`**.
  Rechazada: el pedido literal del dueño/desarrollador del proyecto asumía que toda la
  información ya estaba disponible, pero no lo estaba (desactivadas) — seguirla al pie de la
  letra habría roto silenciosamente la función de restaurar un tamaño desactivado.
- **Incluir receta/grupos de opciones también para las desactivadas**. Rechazada: ningún
  consumidor los necesita mientras la variante sigue desactivada (FR-006) — sería payload sin uso,
  exactamente el tipo de carga innecesaria que esta spec busca eliminar.

## Qué NO cambia

- `GET /variants/{id}/recipe` y `GET /variants/{id}/option-groups` (`catalog/router.py:189-222`):
  siguen existiendo tal cual, con las mismas reglas de autorización (`forbid_cashier` y
  `get_current_user` respectivamente) — los sigue usando `restoreVariant()` del frontend (FR-006).
- `GET /menu` (`menu/router.py`) y su `selectinload` propio: no se tocan; esta spec no modifica el
  menú público del comensal.
- El modelo de datos persistido (`Product`, `ProductVariant`, `RecipeItem`, `VariantOptionGroup`,
  `OptionGroup`, `Option`): sin columnas, tablas ni relaciones nuevas — todo esto es forma de
  consulta y de respuesta HTTP, no de almacenamiento.
- El contrato de guardado (`POST`/`PATCH` de producto, `to_save_response`): no se toca; ya
  construye `recipe`/`option_groups` por su cuenta, en un camino de código separado del de lectura
  que esta spec optimiza.
