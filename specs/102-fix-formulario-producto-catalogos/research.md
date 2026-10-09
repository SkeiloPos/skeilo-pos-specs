# Research: Corrección y mejora de rendimiento del formulario de crear/editar producto

## D1 — Resolver el nombre real de insumos ya referenciados, sin tocar `allItems()` ni `selectedLabel()`

**Decisión**: `InventoryService` gana una señal nueva `resolvedExtraItems` (`signal<InventoryItem[]>([])`)
y un método `resolveMissingItems(ids: string[]): Promise<void>` que, para cada id que no esté en
`allItems()` ni ya en `resolvedExtraItems()`, llama en paralelo (`Promise.all`) al endpoint que ya
existe `GET /items/{item_id}` (`pos-backend/app/api/v1/inventory/router.py:86`, "Obtener un
insumo") y agrega los resultados mapeados con el `toItem()` ya existente. `ProductFormComponent`
cambia la fuente de `inventoryOptions()` (`:564-566`) y de `unitLookup` (`:559-561`) de
`this.inventoryService.allItems()` a `[...this.inventoryService.allItems(),
...this.inventoryService.resolvedExtraItems()]` (deduplicado por `id`). Después de que
`getProductDraft` resuelve (D2), el componente junta todos los `inventory_item_id` referenciados
por la receta y por el desglose de consumo de opciones de **todas** las variantes y llama una sola
vez a `resolveMissingItems(ids)`.

**Rationale**:

- El backend ya expone exactamente lo que falta: un insumo por id, sin importar su posición en el
  catálogo completo — cero cambios de backend, mismo patrón que research.md D1 de la spec 098
  (reutilizar lo que ya existe en vez de construir un endpoint nuevo).
- No toca `selectedLabel()` (`searchable-select.component.ts:118-120`), que sigue leyendo
  únicamente `options` — exactamente la superficie que la spec 098 (D2/D5) decidió no tocar. El
  fix ocurre un nivel más arriba: se asegura de que `options` (el `@Input` que cada consumidor ya
  construye y pasa) **incluya** cualquier insumo ya referenciado, así `selectedLabel()` encuentra su
  `id` sin ningún cambio en el componente compartido.
- Resuelve a la vez el síntoma reportado (receta) y el síntoma gemelo no reportado pero presente en
  el mismo formulario (`groupBreakdown()` → `lookup.nameOf(...)`, `:830`, construido sobre el mismo
  `unitLookup`): ambos leen la misma fuente, así que el mismo cambio los corrige juntos sin lógica
  duplicada.
- Es exactamente la alternativa que research.md D5 de la spec 098 dejó documentada como candidata
  para una spec de corrección independiente ("una caché que se construye a demanda a partir de los
  ids realmente referenciados por cada formulario") — esta spec es esa continuación.

**Alternatives considered**:

- **Extender `app-searchable-select` con un `@Input() resolveLabel?: (id) => Promise<string |
  null>` que `selectedLabel()` use como fallback**. Rechazada: amplía la superficie del componente
  compartido en un eje que la spec 098 (D2/D5) decidió explícitamente no tocar, y que ningún otro
  consumidor (selector de mesa, categoría, presentación) necesita — el fix a nivel de `options` del
  consumidor resuelve lo mismo sin tocar el componente genérico (Principio V).
- **Denormalizar el nombre del insumo directamente en la respuesta de `GET /variants/{id}/recipe`**
  (agregar `name`/`unit_measure_id` resuelto en el backend). Rechazada: requiere un cambio de
  backend que no es necesario cuando un endpoint de solo lectura ya existente (`GET
  /items/{item_id}`) resuelve el mismo problema desde el cliente, con el mismo costo (una petición
  adicional por insumo faltante, ya acotada a los que realmente faltan).

## D2 — Paralelizar `getProductDraft` entre variantes, con aislamiento de fallos por variante

**Decisión**: en `product.service.ts`, el `for...of` con `await` (`:453-469`) se reemplaza por
`Promise.allSettled(variants.filter((v) => v.active).map(async (v) => {...}))`. Cada variante
sigue pidiendo su receta y sus grupos de opciones en paralelo entre sí (`Promise.all`, sin cambios
ahí), pero ahora todas las variantes empiezan sus dos peticiones al mismo tiempo, sin esperar a la
anterior. Una variante cuya promesa se rechaza se mapea a un `VariantDraft` con `recipe: []`,
`optionGroups: []` y un campo nuevo `loadError: true` (ver `data-model.md`), en vez de abortar la
carga de las demás. `ProductFormComponent` gana `retryVariantLoad(variantId)`, que repite
únicamente las dos peticiones de esa variante y limpia `loadError` si tiene éxito.

**Rationale**:

- Elimina la dependencia lineal que hoy hace que el tiempo total escale con el número de tamaños
  (spec FR-005/FR-006/SC-002): todas las peticiones de receta/grupos de opciones de todas las
  variantes se disparan en el mismo instante, limitadas solo por la concurrencia real del
  navegador/red, no por un `await` artificial entre variantes.
- `Promise.allSettled` (en vez de `Promise.all`) es lo que exige FR-007/el Edge Case de la spec: una
  variante que falle no debe bloquear ni descartar el trabajo ya hecho de las demás — comportamiento
  distinto al actual (hoy, un fallo de red en cualquier punto del `for` deja sin aplicar también lo
  que las variantes anteriores sí lograron cargar), cambio explícitamente autorizado por el spec
  (FR-007), no una decisión de negocio nueva que requiera entrada en
  `registro-de-anomalias.md` (Principio II): es una corrección de manejo de errores, no una regla de
  negocio sobre qué puede guardarse.
- No se toca el backend ni se agrega ningún endpoint de "lote": paralelizar en el cliente ya elimina
  el escalamiento lineal sin ese costo adicional.

**Alternatives considered**:

- **Endpoint de backend que devuelva receta + grupos de opciones de todas las variantes de un
  producto en una sola petición**. Rechazada: requiere cambio de backend (nuevo endpoint, nuevo
  contrato) que no es necesario — paralelizar las peticiones ya existentes del lado del cliente
  resuelve el mismo problema de rendimiento sin tocar `pos-backend`, consistente con el alcance
  "solo frontend" confirmado para los otros tres puntos.
- **`Promise.all` simple (sin `allSettled`)**. Rechazada: preserva el defecto de "todo o nada" que
  FR-007 pide corregir — un solo tamaño con error de red seguiría bloqueando la carga completa del
  formulario.

**Adenda de implementación (2026-10-08)**: leer el código real durante la implementación reveló
dos detalles que este research no había anticipado:

1. `getVariantRecipe()`/`getVariantOptionGroups()` **nunca rechazan** — atrapan internamente
   cualquier error (incluido uno que no sea 404) y devuelven `[]`, dejando el detalle en
   `otherError`. Por construcción, `Promise.allSettled` nunca vería un `rejected` si se la aplicara
   directamente sobre ellos. Se agregaron dos métodos privados nuevos,
   `fetchVariantRecipeRaw`/`fetchVariantOptionGroupsRaw` (idénticos, pero un 404 sigue siendo vacío
   válido y cualquier OTRO error se propaga), usados solo por `getProductDraft` y por
   `retryVariant()` (nuevo, público, para T013). `getVariantRecipe()`/`getVariantOptionGroups()`
   (ya usados por `restoreVariant()`) quedan intactos en su contrato de siempre resolver,
   delegando en las versiones `Raw` por dentro — ningún consumidor existente cambia de
   comportamiento (Principio II).
2. La guarda original para no recargar el catálogo de grupos de opciones
   (`optionGroupService.groups().length ? Promise.resolve() : loadGroups()`) confunde "catálogo
   vacío" con "nunca cargado": con variantes en paralelo, si el tenant no tiene ningún grupo de
   opciones, cada variante vería `length === 0` al mismo tiempo y dispararía su propia `GET
   /option-groups` (N peticiones idénticas en vez de una). Se reemplazó por
   `ensureOptionGroupsLoaded()`, que deduplica por una promesa en vuelo (`optionGroupsLoadPromise`)
   en vez de por longitud — una sola petición sin importar cuántas variantes la pidan a la vez, ni
   si el resultado real está vacío.

## D3 — Extender la búsqueda remota ya definida por la spec 098 a categorías y presentaciones

**Decisión**: `CategoryService` gana `searchActiveCategories(query: string): Promise<Category[]>` y
`PresentationService` gana `searchActivePresentations(query: string): Promise<Presentation[]>`, con
la misma firma y los mismos parámetros fijos que `InventoryService.searchActiveItems()`
(`page=1`, `size=20`, `active=true`, `search=query.trim()`), contra `GET /categories` y `GET
/presentations` — confirmado que **ya soportan** `search` (ilike sobre `name`), `active` y
`page`/`size` (tope `le=100`, igual que `/inventory/items`), usando el mismo helper compartido
`paginate()` de `pos-backend` (`app/core/pagination.py`); cero cambios de backend. El selector de
categoría (hoy un `<select>` nativo con `@for` sobre `categoryService.allCategories()`,
`product-form.component.ts:138-145`) y el de presentación (hoy un `<select>` nativo con `@for`
sobre `presentationOptionsFor(v)`, `:202-211`) migran a `<app-searchable-select>` con
`[search]="searchCategories"` / `[search]="searchPresentations"`, reusando el contrato ya definido
por la spec 098 (`../098-selector-insumos-receta/contracts/searchable-select-component.md`) sin
modificar el componente compartido, que ya soporta esta forma de uso.

**Nota sobre insumos**: el selector de "Insumos fijos" **ya tiene** `[search]="searchActiveItems"`
cableado (`product-form.component.ts:574-577`, implementado por la spec 098). La Historia 3 de
esta spec, para insumos, ya está satisfecha por código existente — no se escribe código nuevo para
ese punto; `quickstart.md` lo revalida como regresión, no como funcionalidad nueva.

**Rationale**:

- Mismo comportamiento de búsqueda en los tres selectores (FR-009): reutilizar literalmente el
  mismo patrón (mismo tamaño de página, mismo debounce de 300ms ya centralizado en
  `searchable-select.component.ts` por la spec 098, mismo filtro `active`) es lo que garantiza esa
  consistencia por construcción, no por convención entre archivos separados.
- Cero cambios de backend: la investigación confirmó que `GET /categories` y `GET /presentations`
  ya exponen `search`/`active`/paginación con la misma forma que `/inventory/items` — no hay nada
  que construir del lado del servidor.
- Reutilizar `app-searchable-select` (en vez de un combobox nuevo por catálogo) evita duplicar
  navegación por teclado, `ControlValueAccessor` y manejo de carga/error que el componente
  compartido ya resuelve (Principio V) — exactamente la misma razón que la spec 098 (D2) dio para no
  crear un componente nuevo.

**Alternatives considered**:

- **Un combobox de búsqueda nuevo y distinto para categoría/presentación**. Rechazada: duplicaría
  ~150 líneas ya resueltas por `app-searchable-select` (spec 098, D2) solo por no reutilizar un
  componente que ya soporta exactamente este caso de uso.
- **Subir el tope de `allCategories()`/`allPresentations()` de 100 a un número mayor**. Rechazada
  por la misma razón que research.md D1 de la spec 098: no resuelve el problema de fondo (sigue
  habiendo un límite fijo que algún tenant eventualmente supera), solo retrasa el síntoma.

## D4 — Al migrar el selector de categoría, preservar la opción ya elegida aunque quede fuera de la página cargada

**Decisión**: al construir las opciones de categoría para `<app-searchable-select>`, aplicar el
mismo resguardo de una línea que `presentationOptionsFor()` ya aplica hoy
(`product-form.component.ts:598-600`: `if (v.presentationId && !options.some((o) => o.id ===
v.presentationId)) options.push({ id: v.presentationId, name: v.presentationName })`), usando
`category_name`, que el draft **ya recibe** del backend (`product.service.ts:61` y `:686`,
`category_name: p.category_name ?? null`) sin necesitar ninguna petición nueva.

**Rationale**:

- Evita introducir, en el mismo cambio que agrega búsqueda a categoría (D3), una variante nueva del
  defecto exacto que la Historia 1 corrige para insumos (una categoría ya elegida que deja de verse
  si queda fuera de la página de 100 cargada) — el dato que hace falta (`category_name`) ya viaja en
  el draft, a costo cero.
- No es una decisión de negocio nueva (Principio XI): es un detalle técnico de cómo se construyen
  las opciones de un selector, idéntico a uno que ya existe, en el mismo archivo, para presentación
  — no cambia qué categoría puede asociarse a un producto, solo cómo se muestra la ya asociada.

**Alternatives considered**:

- **Dejar el selector de categoría sin este resguardo, ya que no fue reportado con ese síntoma**.
  Rechazada: dejaría dos selectores del mismo formulario, tocados en el mismo cambio, con niveles de
  robustez distintos sin ninguna razón técnica — el dato ya está disponible y el patrón ya está
  probado en la línea de arriba del mismo archivo.

## D5 — Refresco en segundo plano acotado a las tres queries "ver todos" de los catálogos

**Decisión (revisada durante la implementación — ver Adenda)**: cada servicio de catálogo
(`CategoryService`, `InventoryService`, `PresentationService`) gana un método `refreshAllX()` que
invalida **únicamente** su query "ver todos" (`queryClient.invalidateQueries({ queryKey: [...,
'all'] })`), sin tocar la tabla paginada de administración. `ProductFormComponent` arranca, al
abrir el formulario (`ngOnInit`), un sondeo con `startVisibleInterval()`
(`core/realtime/visible-interval.ts`, ya existente y usado por `public-menu.component.ts`) que
llama a los tres `refreshAllX()` cada 2 minutos, y lo detiene en `ngOnDestroy`.

**Rationale**:

- `startVisibleInterval` ya resuelve exactamente lo que esta historia necesita y ya está probado
  en producción por otro consumidor: sondea mientras la pestaña se ve, se pausa sola en segundo
  plano (costo cero), y al volver a primer plano ejecuta la función de inmediato antes de
  reprogramar el intervalo — ese último detalle cubre el caso "el mismo usuario alterna pestañas"
  sin necesitar una opción separada tipo `refetchOnWindowFocus`. Reutilizarlo es consistente con el
  Principio V/IX (preferir lo que ya existe antes que construir un mecanismo nuevo) y evita
  reinventar la pausa-en-segundo-plano con `refetchInterval`/`refetchOnWindowFocus` de TanStack
  Query, que no comparten esa semántica de "pausa total en pestaña oculta".
- El escenario que pide la Historia 4 es multi-sesión (otra persona crea el registro mientras el
  formulario ya está abierto en una sesión distinta): el sondeo periódico es lo que garantiza que
  la novedad aparezca "dentro de un tiempo razonable" (SC-004) sin depender de que el usuario
  cambie de pestaña.
- `invalidateQueries({ queryKey: [..., 'all'] })` (en vez de tocar `defaultOptions` del
  `QueryClient` o la query paginada) evita que cualquier otra tabla administrativa de la aplicación
  empiece a sondear en segundo plano — alcance acotado exactamente a lo que FR-010 exige no
  cambiar.
- `searchable-select.component.ts` no reacciona a cambios de `options` con ningún `effect()` que
  cierre el desplegable o reinicie el valor seleccionado (confirmado leyendo el componente: `open` y
  `value` son señales internas independientes de `options`, que es un `@Input` plano) — un refetch
  en segundo plano que renueva el array de `options` no interrumpe una selección ya hecha ni cierra
  un desplegable abierto, satisfaciendo FR-013/FR-014 sin ningún cambio adicional en el componente
  compartido.

**Alternatives considered**:

- **Extender `injectPagedQuery` con `refetchInterval`/`refetchOnWindowFocus` propios de TanStack
  Query** (decisión original de este research.md antes de implementar). Descartada al
  implementar: `startVisibleInterval` ya resuelve lo mismo, ya está probado, y ya lo usa otro
  módulo de la aplicación — preferirlo es más consistente que una segunda forma de lograr el mismo
  resultado (Principio V).
- **Cambiar `defaultOptions` del `QueryClient` global**. Rechazada: afectaría cada query paginada de
  la aplicación (todas las tablas administrativas), muy por encima del alcance de esta spec
  (Principio VI, evolución incremental).
- **Websockets o Server-Sent Events para notificar la creación de un registro en tiempo real**.
  Rechazada: ya existe infraestructura SSE en el proyecto (`core/realtime/`), pero su protocolo de
  eventos (`realtime-event.model.ts`) cubre pedidos/mesas/pagos, no catálogo (categorías, insumos,
  presentaciones) — agregar eventos nuevos exigiría cambios de backend (emitirlos al crear cada
  registro), fuera del alcance "100% frontend" confirmado para esta spec. La spec (Assumptions) ya
  asume que un sondeo periódico es suficiente para "razonablemente actualizado", no "instantáneo".

**Adenda de implementación (2026-10-08)**: la decisión original de este documento (extender
`injectPagedQuery`) se escribió antes de encontrar `core/realtime/visible-interval.ts` al navegar
el código durante la implementación. Al descubrir que ya resuelve exactamente "sondear mientras se
ve, pausar en segundo plano, refrescar de inmediato al volver", se reemplazó la decisión original
por su reúso, sin tocar `paged-query.ts` en absoluto (el archivo queda sin cambios en esta spec).

**Segunda adenda — D5 retirado por completo (2026-10-08)**: tras implementarse y verse en
producción (panel de red del navegador mostrando el sondeo repetido cada 2 minutos), el
dueño/desarrollador del proyecto pidió explícitamente retirar todo el mecanismo: prefiere que el
usuario recargue la página manualmente. Se eliminaron `startCatalogPolling()`/`refreshCatalogs()`/
`pollHandle` de `product-form.component.ts`, y `refreshAllItems()`/`refreshAllCategories()`/
`refreshAllPresentations()` de los tres servicios de catálogo — ninguno de los tres queda con otro
llamador. `core/realtime/visible-interval.ts` en sí no se toca (sigue usándolo
`public-menu.component.ts`/`pos-terminal.store.ts`, sin relación con esta spec). Historia 4 (spec,
FR-012/013/014, SC-004) queda marcada como retirada, no eliminada del documento, para dejar
registro de qué se intentó y por qué ya no aplica.

## Qué NO cambia

- `selectedLabel()` de `searchable-select.component.ts` (`:118-120`): sigue leyendo únicamente
  `options`, sin ningún cambio — el fix de D1 ocurre en qué construye `options`, no en el
  componente.
- `manual-order-page.component.ts` (selector de mesa) y cualquier otro consumidor de
  `app-searchable-select` que no sea insumo, categoría o presentación: sin cambios.
- `pos-backend`: cero archivos tocados. Los tres catálogos (`/inventory/items`, `/categories`,
  `/presentations`) y el endpoint `GET /items/{item_id}` ya existen con exactamente la forma que
  esta corrección necesita.
- `allItems()`, `allCategories()`, `allPresentations()` (las queries "ver todos" en sí): no cambian
  su forma, su filtro ni su tope `size=100` — solo ganan un método `refreshAllX()` que las invalida
  bajo demanda (D5) y se complementan (no se reemplazan) con la búsqueda remota (D3) y la
  resolución por id (D1). `core/query/paged-query.ts` no se toca en absoluto.
- Las tablas paginadas administrativas de Insumos, Categorías y Presentaciones (`itemsQuery` y
  equivalentes): no se tocan ni ganan refresco en segundo plano — ese cambio se acota a las queries
  "ver todos" que alimentan selectores (D5).

## Limitación heredada, no introducida por esta corrección

`Category.name.ilike`/`Presentation.name.ilike`/`InventoryItem.name.ilike` son sensibles a tildes
(sin `unaccent`), igual que ya documentó research.md de la spec 098 para insumos — buscar "jamon"
no encuentra "Jamón" en ninguno de los tres catálogos. Esta corrección **hereda** esa limitación
(FR-009 pide que los tres selectores se comporten igual entre sí, no que corrijan un problema de
backend que ninguna historia de esta spec pide corregir).
