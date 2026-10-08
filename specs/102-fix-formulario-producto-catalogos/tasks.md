---

description: "Task list for feature implementation"
---

# Tasks: Corrección y mejora de rendimiento del formulario de crear/editar producto (receta, tamaños y catálogos)

**Input**: Design documents from `/specs/102-fix-formulario-producto-catalogos/`
**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: incluidos — el plan y los contratos ya comprometen ficheros de test concretos
(Principio X, Verificación Obligatoria), siguiendo el mismo criterio que la spec 098.

**Organización**: cuatro historias de usuario (US1 P1, US2 P2, US3 P3, US4 P4), las cuatro
**100% frontend** (`pos-heladeria`) — `pos-backend` no se toca (confirmado por investigación:
los tres catálogos y `GET /items/{id}` ya existen con la forma exacta que se necesita). A
diferencia de la spec 098, aquí **no hay una fase Foundational bloqueante**: las cuatro historias
tocan archivos y mecanismos distintos entre sí (research.md D1, D2, D3/D4, D5) y pueden
implementarse en cualquier orden o en paralelo — la Fase 2 queda documentada como vacía a
propósito, no omitida por error.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: se puede hacer en paralelo (archivo distinto, sin dependencia de una tarea sin terminar)
- **[Story]**: US1, US2, US3, US4

---

## Phase 1: Setup

- [X] T001 Confirmar línea base en `pos-heladeria`: `cd ../pos-heladeria && npx ng test
  --watch=false` y comparar por **conjunto de archivos con fallos preexistentes**, no por conteo
  literal (el conteo exacto varía entre corridas — ver memoria del proyecto sobre cómo correr los
  tests de los repos hermanos). No hace falta confirmar línea base de `pos-backend`: esta spec no
  toca ese repo (plan.md, Technical Context). Confirmado 2026-10-08: 10 fallos en 6 archivos
  (`tenant.service`, `pos-checkout-panel`, `pos-order-panel` y 3 más no relacionados), 1546 OK —
  misma línea base ya documentada para las specs 097/098.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: a diferencia de la spec 098 (donde el modo remoto de `app-searchable-select` y
`InventoryService.searchActiveItems()` eran prerrequisito compartido de ambas historias), esta
spec no tiene ningún mecanismo nuevo compartido entre dos o más historias: Historia 1 (D1) toca
`inventory.service.ts`/`product-form.component.ts` (lectura de receta); Historia 2 (D2) toca
`product.service.ts`/`product.interface.ts` (carga de variantes); Historia 3 (D3/D4) toca
`category.service.ts`/`presentation.service.ts`/`product-form.component.ts` (selectores); Historia
4 (D5) toca `core/query/paged-query.ts` y las tres queries "allX". El modo de búsqueda remota de
`app-searchable-select` que las Historias 1 y 3 reutilizan **ya existe** (spec 098, implementada)
— no hay nada que construir aquí.

**Esta fase no tiene tareas.** Cada historia es independiente y puede empezar directamente después
de Phase 1.

---

## Phase 3: User Story 1 - El insumo ya guardado en la receta siempre muestra su nombre real (Priority: P1) 🎯 MVP

**Goal**: el formulario de producto resuelve el nombre real de cualquier insumo ya referenciado
por una receta o un detalle de opción, sin importar si está dentro de la página de 100 que carga
`allItems()`.

**Independent Test**: en un tenant con más de 100 insumos activos, abrir la edición de un producto
cuya receta referencie un insumo fuera de los primeros 100 y verificar que el selector de "Insumos
fijos" muestra su nombre real, no "Insumo…" (quickstart.md, Escenario 1).

### Tests for User Story 1

- [X] T002 [P] [US1] Escribir test en `pos-heladeria/src/app/modules/inventory/services/inventory.service.spec.ts`:
  `resolveMissingItems(ids)` dispara `GET /inventory/items/{id}` en paralelo (vía
  `HttpTestingController`) solo para los ids que NO estén ya en `allItems()` ni en
  `resolvedExtraItems()`, mapea cada respuesta con el `toItem()` ya existente y la agrega a
  `resolvedExtraItems`; un id que responda 404 no se agrega (`contracts/inventory-item-by-id.md`)
  — debe fallar antes de implementar
- [X] T003 [P] [US1] Escribir/actualizar test en `pos-heladeria/src/app/modules/products/pages/product-form.component.spec.ts`:
  con un producto cuya receta tiene una línea con un `inventory_item_id` que NO está en el
  `allItems()` inicial (simula estar fuera de los primeros 100), tras cargar el draft el selector
  de "Insumos fijos" muestra el nombre real de ese insumo (no el placeholder); lo mismo para el
  desglose de consumo de insumo de una opción de grupo de opciones que referencie el mismo insumo
  (`groupBreakdown()`); un insumo desactivado después de guardado sigue mostrando su nombre real
  (FR-004) — debe fallar antes de implementar

### Implementation for User Story 1

- [X] T004 [US1] Implementar `resolvedExtraItems` (signal) y `resolveMissingItems(ids: string[]):
  Promise<void>` en `pos-heladeria/src/app/modules/inventory/services/inventory.service.ts`:
  filtra ids ya conocidos, llama en paralelo a `GET /items/{id}` (ya existente,
  `pos-backend/app/api/v1/inventory/router.py:86`) y mapea con `toItem()` — depende de T002
- [X] T005 [US1] En `pos-heladeria/src/app/modules/products/pages/product-form.component.ts`,
  cambiar la fuente de `inventoryOptions()` (`:564-566`) y de `unitLookup` (`:559-561`) de
  `this.inventoryService.allItems()` a `[...this.inventoryService.allItems(),
  ...this.inventoryService.resolvedExtraItems()]` (deduplicado por `id`) — depende de T004
- [X] T006 [US1] En `pos-heladeria/src/app/modules/products/pages/product-form.component.ts`,
  después de que `getProductDraft` resuelve, recolectar todos los `inventory_item_id` referenciados
  por la receta y por el desglose de consumo de opciones de **todas** las variantes del draft, y
  llamar una sola vez a `this.inventoryService.resolveMissingItems(idsFaltantes)` (ids que no
  estén ya en `allItems()`) — depende de T005
- [X] T007 [US1] Ejecutar T002 y T003, confirmar que ahora pasan; reejecutar toda la suite de
  `pos-heladeria` (comando de T001) y confirmar que sigue en la misma línea base — depende de
  T004, T005, T006. Confirmado 2026-10-08: 5 tests nuevos/actualizados en verde
  (`inventory.service.spec.ts` +3, `product-form.component.spec.ts` +2); suite completa en línea
  base (10 fallos, mismos 6 archivos preexistentes; 1546→1551)

**Checkpoint**: Historia de Usuario 1 funciona de punta a punta — quickstart.md Escenario 1
verificable; el bug reportado en producción queda corregido.

---

## Phase 4: User Story 2 - Abrir un producto con varios tamaños no se vuelve más lento mientras más tamaños tiene (Priority: P2)

**Goal**: la receta y los grupos de opciones de todas las variantes de un producto se cargan en
simultáneo al abrir el formulario de edición, con aislamiento de fallos por variante.

**Independent Test**: medir que las peticiones de receta/grupos de opciones de un producto con 8+
tamaños se disparan todas al mismo tiempo, y que el tiempo de carga no escala con el número de
tamaños (quickstart.md, Escenario 2).

### Tests for User Story 2

- [X] T008 [P] [US2] Escribir test en `pos-heladeria/src/app/modules/products/services/product.service.spec.ts`:
  `getProductDraft` con un producto de 3+ variantes activas dispara las peticiones de receta y
  grupos de opciones de **todas** las variantes en el mismo tick (vía `HttpTestingController`,
  confirmando que las peticiones de la variante 2 están pendientes sin haber resuelto las de la
  variante 1) — debe fallar antes de implementar (hoy el `for...of` secuencial solo tiene
  pendientes las 2 peticiones de una variante a la vez)
- [X] T009 [P] [US2] Escribir test en `pos-heladeria/src/app/modules/products/services/product.service.spec.ts`:
  si la petición de receta o de grupos de opciones de una variante específica falla (simulando un
  error de red), el `VariantDraft` resultante de esa variante tiene `loadError: true` con
  `recipe: []`/`optionGroups: []`, mientras las demás variantes cargan con normalidad — debe
  fallar antes de implementar
- [X] T010 [P] [US2] Escribir test en `pos-heladeria/src/app/modules/products/pages/product-form.component.spec.ts`:
  `retryVariantLoad(variantId)` repite solo las peticiones de esa variante y limpia `loadError` si
  tienen éxito, sin afectar a las demás variantes ya cargadas — debe fallar antes de implementar

### Implementation for User Story 2

- [X] T011 [US2] Agregar el campo opcional `loadError?: boolean` a `VariantDraft` en
  `pos-heladeria/src/app/modules/products/interfaces/product.interface.ts` (`:372` y alrededores;
  ver `data-model.md`) — depende de T009
- [X] T012 [US2] En `pos-heladeria/src/app/modules/products/services/product.service.ts`, cambiar
  el `for...of` con `await` de `getProductDraft` (`:453-469`) por `Promise.allSettled(...)` sobre
  todas las variantes activas (cada variante sigue pidiendo receta + grupos de opciones en
  paralelo entre sí, `Promise.all`, sin cambios ahí); mapear cada rechazo a `{ recipe: [],
  optionGroups: [], loadError: true }` — depende de T008, T009, T011. **Nota de implementación**:
  además de lo previsto, se descubrieron y corrigieron dos efectos colaterales reales de
  paralelizar: (a) `getVariantRecipe`/`getVariantOptionGroups` nunca rechazaban (atrapaban todo
  error internamente), así que `getProductDraft` ganó variantes privadas
  `fetchVariantRecipeRaw`/`fetchVariantOptionGroupsRaw` (sin atrapar, salvo 404) para que
  `Promise.allSettled` pueda distinguir un fallo real de "aún no tiene receta"; (b) la guarda
  original de `optionGroupService.groups().length` para evitar recargar el catálogo de grupos
  confundía "catálogo vacío" con "nunca cargado" y, al paralelizar, dispararía `GET
  /option-groups` una vez por variante — se corrigió con un `ensureOptionGroupsLoaded()` que
  deduplica por promesa en vuelo, no por longitud. También se agregó `retryVariant(variantId)`
  (público, sí puede rechazar) para uso exclusivo de T013
- [X] T013 [US2] En `pos-heladeria/src/app/modules/products/pages/product-form.component.ts`,
  implementar `retryVariantLoad(variantId: string)` que repite `getVariantRecipe`/
  `getVariantOptionGroups` solo para esa variante, actualiza su `VariantDraft` y limpia
  `loadError` si tiene éxito; agregar en la plantilla un control de "Reintentar" visible solo en
  la variante con `loadError` — depende de T010, T012. Implementado contra `service.retryVariant()`
  (T012), no contra `getVariantRecipe`/`getVariantOptionGroups` (que nunca rechazan y no
  permitirían saber si el reintento realmente tuvo éxito)
- [X] T014 [US2] Ejecutar T008, T009 y T010, confirmar que ahora pasan; reejecutar toda la suite de
  `pos-heladeria` y confirmar que sigue en la misma línea base — depende de T011, T012, T013.
  Confirmado 2026-10-08: 6 tests nuevos en verde (`product.service.spec.ts` +5,
  `product-form.component.spec.ts` +1); suite completa en línea base (10 fallos, mismos 6
  archivos preexistentes; 1551→1557)

**Checkpoint**: Historia de Usuario 2 funciona de punta a punta — quickstart.md Escenario 2
verificable; el tiempo de apertura del formulario deja de escalar con el número de tamaños.

---

## Phase 5: User Story 3 - Encontrar y elegir cualquier insumo, categoría o presentación activa, sin tope fijo (Priority: P3)

**Goal**: los selectores de categoría y presentación del formulario de producto ganan búsqueda
remota con el mismo patrón que ya tiene el selector de insumo (spec 098); de paso, el selector de
categoría preserva la opción ya elegida aunque quede fuera de la página cargada, igual que ya hace
presentación (research.md D4).

**Independent Test**: en un tenant con más de 100 registros activos en cada catálogo, buscar por
texto un insumo, una categoría y una presentación que existan fuera de los primeros 100 en sus
selectores respectivos del formulario de producto y verificar que cada uno aparece y puede
seleccionarse (quickstart.md, Escenarios 3 y 4).

### Tests for User Story 3

- [X] T015 [P] [US3] Escribir test en `pos-heladeria/src/app/modules/categories/services/category.service.spec.ts`:
  `searchActiveCategories('x')` dispara `GET /categories?search=x&active=true&page=1&size=20` (vía
  `HttpTestingController`) y devuelve el `items[]` de la respuesta sin transformación adicional
  (`contracts/categories-search.md`) — debe fallar antes de implementar
- [X] T016 [P] [US3] Escribir test en `pos-heladeria/src/app/modules/presentations/services/presentation.service.spec.ts`:
  `searchActivePresentations('x')` dispara `GET
  /presentations?search=x&active=true&page=1&size=20` y devuelve el `items[]` de la respuesta
  (`contracts/presentations-search.md`) — debe fallar antes de implementar
- [X] T017 [P] [US3] Escribir/actualizar test en `pos-heladeria/src/app/modules/products/pages/product-form.component.spec.ts`:
  (a) escribir en el selector de Categoría el nombre de una categoría que NO esté en el
  `allCategories()` inicial dispara `searchActiveCategories` y la categoría aparece como opción
  seleccionable; (b) con un producto cuyo `category_id` ya elegido NO está en `allCategories()`
  (simula estar fuera de los primeros 100), el selector sigue mostrando el nombre real de esa
  categoría (`category_name` del draft, research.md D4) — debe fallar antes de implementar
- [X] T018 [P] [US3] Escribir/actualizar test en `pos-heladeria/src/app/modules/products/pages/product-form.component.spec.ts`:
  escribir en el selector de Presentación de un tamaño el nombre de una presentación que NO esté
  en el `allPresentations()` inicial dispara `searchActivePresentations` y la presentación aparece
  como opción seleccionable, sin romper el resguardo ya existente que preserva la presentación ya
  elegida de esa variante — debe fallar antes de implementar
- [X] T019 [US3] Prueba de regresión en `pos-heladeria/src/app/modules/products/pages/product-form.component.spec.ts`:
  el selector de "Insumos fijos" sigue encontrando un insumo fuera de los primeros 100 mediante
  `[search]="searchActiveItems"` (comportamiento ya entregado por la spec 098) — no se espera
  código nuevo para que este test pase; si falla, hay una regresión sobre la 098

### Implementation for User Story 3

- [X] T020 [US3] Implementar `searchActiveCategories(query: string): Promise<Category[]>` en
  `pos-heladeria/src/app/modules/categories/services/category.service.ts`, mismo patrón que
  `InventoryService.searchActiveItems()` (`page=1`, `size=20`, `active=true`,
  `search=query.trim()`) — depende de T015
- [X] T021 [US3] Implementar `searchActivePresentations(query: string): Promise<Presentation[]>`
  en `pos-heladeria/src/app/modules/presentations/services/presentation.service.ts`, mismo patrón
  — depende de T016
- [X] T022 [US3] En `pos-heladeria/src/app/modules/products/pages/product-form.component.ts`,
  reemplazar el `<select>` nativo de Categoría (`:138-145`) por `<app-searchable-select>`, con un
  método `searchCategories` que delega en `searchActiveCategories` (mapeado a
  `{id, label}`) y un nuevo computed `categoryOptionsFor()` (mismo rol que `inventoryOptions()`)
  como `[options]` — depende de T020, T017. **Nota**: el computed se llamó `categoryOptions`
  (sin argumento `v`, a diferencia de `presentationOptionsFor(v)`) porque la categoría es una sola
  por producto, no por variante
- [X] T023 [US3] En `categoryOptionsFor()` (de T022), aplicar el mismo resguardo de una línea que
  ya usa `presentationOptionsFor()` (`:598-600`): si `draft().category_id` está definido y no
  aparece entre las opciones de `allCategories()`, agregarlo usando `draft().category_name`
  (research.md D4) — depende de T022. **Nota de implementación**: `ProductDraft` no traía
  `category_name` todavía (solo `category_id`) — se agregó el campo opcional
  `category_name?: string` a la interfaz y se pobló en `getProductDraft()` desde
  `product.category_name` (ya resuelto por el backend, spec 097), sin lo cual D4 no tenía dato que
  mostrar
- [X] T024 [US3] En `pos-heladeria/src/app/modules/products/pages/product-form.component.ts`,
  reemplazar el `<select>` nativo de Presentación (`:202-211`) por `<app-searchable-select>`, con
  un método `searchPresentations` que delega en `searchActivePresentations` (mapeado a
  `{id, label}`) como `[search]`, manteniendo `presentationOptionsFor(v)` (sin cambios de lógica)
  como `[options]` — depende de T021, T018. **Nota**: se agregó `presentationSelectOptionsFor(v)`
  como envoltorio de una línea sobre `presentationOptionsFor(v)` para mapear `{id,name}` →
  `{id,label}` (la forma que exige `app-searchable-select`), sin tocar `presentationOptionsFor`
  (que un test existente sigue consultando directamente por `.name`)
- [X] T025 [US3] Ejecutar T015-T019, confirmar que pasan (T019 sin cambios de código, por
  regresión); reejecutar toda la suite de `pos-heladeria` y confirmar que sigue en la misma línea
  base — depende de T020, T021, T022, T023, T024. **Nota de implementación**: convertir los dos
  `<select>` nativos a `app-searchable-select` rompió 5 tests existentes que interactuaban con el
  DOM del `<select>` de presentación (`variantRowSelect`, lectura de `.options`, `change` nativo) —
  se actualizaron para interactuar con el botón/lista de `app-searchable-select` en su lugar (no
  son characterization tests protegidos; reflejan el control de UI, no una regla de negocio).
  Confirmado 2026-10-08: category.service.spec.ts (2 tests, archivo nuevo) +
  presentation.service.spec.ts (2 tests, archivo nuevo) + product-form.component.spec.ts (+3
  nuevos, 5 actualizados) en verde; suite completa en línea base (10 fallos, mismos 6 archivos
  preexistentes; 1557→1564)

**Checkpoint**: Historia de Usuario 3 funciona de punta a punta — quickstart.md Escenarios 3 y 4
verificables; los tres selectores del formulario de producto se comportan de forma consistente.

---

## Phase 6: User Story 4 - Ver catálogos razonablemente actualizados sin recargar toda la aplicación (Priority: P4) — RETIRADA

> **Retirada por completo (2026-10-08)**: implementada, verificada, y luego retirada a pedido
> explícito del dueño/desarrollador del proyecto tras verla funcionar en producción (panel de red
> del navegador mostrando el sondeo repetido cada 2 minutos) — prefiere que el usuario recargue la
> página manualmente. `startCatalogPolling()`/`refreshCatalogs()`/`pollHandle` se eliminaron de
> `product-form.component.ts`; `refreshAllItems()`/`refreshAllCategories()`/
> `refreshAllPresentations()` se eliminaron de los tres servicios de catálogo, junto con todos sus
> tests. `core/realtime/visible-interval.ts` NO se tocó (sigue en uso por otros módulos, sin
> relación con esta spec). Ver spec.md (Clarifications, sesión 2026-10-08) y research.md (D5,
> segunda adenda). Las tareas de abajo quedan como registro de lo que se construyó y se retiró, no
> como trabajo pendiente.

**Goal**: las tres queries "ver todos" que alimentan los selectores de insumo, categoría y
presentación del formulario de producto se refrescan en segundo plano, sin tocar el
`defaultOptions` global del `QueryClient` ni ninguna tabla paginada administrativa.

**Independent Test**: con el formulario de producto abierto en una sesión, crear desde otra sesión
una categoría, un insumo y una presentación nuevos, y verificar que cada uno aparece como opción
buscable sin recargar la página (quickstart.md, Escenario 5).

### Tests for User Story 4

> **Nota de implementación (2026-10-08)**: T026-T032 se planearon alrededor de extender
> `injectPagedQuery` con `refetchInterval`/`refetchOnWindowFocus`. Al implementar se encontró
> `core/realtime/visible-interval.ts` (`startVisibleInterval`), una utilidad ya existente y ya
> usada por `public-menu.component.ts` que resuelve exactamente "sondear mientras se ve, pausar en
> segundo plano, refrescar de inmediato al volver" — research.md D5 (Adenda) documenta el cambio
> de decisión. Las tareas de abajo reflejan lo que realmente se construyó; `paged-query.ts` no se
> tocó.

- [X] T026 [P] [US4] Escribir tests en `inventory.service.spec.ts`, `category.service.spec.ts`
  (nuevo) y `presentation.service.spec.ts` (nuevo): `refreshAllItems()`/`refreshAllCategories()`/
  `refreshAllPresentations()` invalidan únicamente la query `[..., 'all']` de su servicio (vía
  `queryClient.invalidateQueries`), sin invalidar la query paginada de administración — debe
  fallar antes de implementar
- [X] T027 [P] [US4] Escribir tests en `product-form.component.spec.ts`: (a) cada ejecución del
  sondeo llama a los tres `refreshAllX()`; (b) al abrir el formulario se arranca un sondeo real
  (`startVisibleInterval`) que `ngOnDestroy` detiene (`.stop()`) — debe fallar antes de implementar

### Implementation for User Story 4

- [X] T028 [US4] Implementar `refreshAllItems()` en `inventory.service.ts`,
  `refreshAllCategories()` en `category.service.ts` y `refreshAllPresentations()` en
  `presentation.service.ts`, cada uno invalidando solo `queryKey: [<recurso>, 'all']` — depende de
  T026
- [X] T029 [US4] En `product-form.component.ts`, agregar `private pollHandle:
  VisibleInterval | null`, `startCatalogPolling()` (llama a `startVisibleInterval(() =>
  this.refreshCatalogs(), 120_000)`) invocado al final de `ngOnInit`, y `refreshCatalogs()` (llama
  a los tres `refreshAllX()`) — depende de T028, T027
- [X] T030 [US4] En `ngOnDestroy()` de `product-form.component.ts`, agregar
  `this.pollHandle?.stop()` — depende de T029
- [X] T031 [US4] Ejecutar T026 y T027, confirmar que ahora pasan; reejecutar toda la suite de
  `pos-heladeria` y confirmar que sigue en la misma línea base — depende de T028, T029, T030.
  Confirmado 2026-10-08: category.service.spec.ts (+1) + presentation.service.spec.ts (+1) +
  inventory.service.spec.ts (+1) + product-form.component.spec.ts (+2) en verde; suite completa en
  línea base (10 fallos, mismos 6 archivos preexistentes; 1564→1569)
- [X] T032 [US4] **(retirada, 2026-10-08)** Eliminar `startCatalogPolling()`/`refreshCatalogs()`/
  `pollHandle` de `product-form.component.ts` (y el import de `visible-interval.ts`),
  `refreshAllItems()`/`refreshAllCategories()`/`refreshAllPresentations()` de los tres servicios
  de catálogo, y todos los tests asociados (T026/T027) — a pedido explícito del
  dueño/desarrollador del proyecto. Confirmado: suite completa en línea base (10 fallos, mismos 6
  archivos; 1569→1563, neto -5 por los tests retirados); build de producción sin errores nuevos

**Checkpoint**: Historias 1-3 funcionan de punta a punta — quickstart.md Escenarios 1-4 y 6-7
verificables. El Escenario 5 (catálogos actualizados sin recarga) ya no aplica: el formulario
depende de una recarga manual de la página, igual que antes de esta spec.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [X] T033 Ejecutar manualmente (o con un script de siembra) `quickstart.md` completo contra
  `pos-backend`/`pos-heladeria` corriendo en local, en particular el Escenario 2 (tiempo real de
  carga con 8+ tamaños) y el Escenario 5 (refresco entre sesiones distintas), que no pueden
  demostrarse completamente solo con `HttpTestingController`. Si el entorno no tiene PostgreSQL
  local ni navegador disponible (misma limitación documentada para la spec 098), dejarlo
  explícitamente pendiente y apoyarse en la evidencia de los tests automatizados + `npx ng build
  --configuration=production` como verificación parcial, igual que hizo la spec 098.
  **Verificación parcial** (2026-10-08): este entorno tampoco tiene PostgreSQL local ni navegador
  disponible. En su lugar: (a) Escenario 1 (nombre real de insumo), Escenario 3 (búsqueda remota
  en los 3 catálogos) y Escenario 4 (resguardo de categoría) ya quedan demostrados por los tests
  automatizados de T002-T003/T017-T019 con `HttpTestingController`/`TestBed`, que simulan la
  petición y respuesta HTTP real contra los contratos de `contracts/`; (b) el Escenario 2 (carga
  en paralelo) queda demostrado por T008 (confirma que las 6 peticiones de 3 variantes están
  pendientes al mismo tiempo, no en cascada) — no se midió un tiempo de reloj real, pero el
  mecanismo (disparo simultáneo) está probado; (c) el Escenario 5 (refresco entre sesiones) queda
  demostrado por T026/T027 (invalidación correcta + wiring del sondeo), no por un cronómetro de 2
  minutos real; (d) `npx ng build --configuration=production` corrió con éxito (sin errores; solo
  los mismos warnings preexistentes de budget y de `qrcode` CommonJS, no relacionados con este
  cambio). Queda pendiente, si se desea cerrar los 5 escenarios en vivo, levantar un Postgres
  desechable (ver memoria del proyecto) y los servidores de desarrollo
- [X] T034 Confirmar que `manual-order-page.component.ts` (selector de mesa) y cualquier otro
  consumidor de `app-searchable-select` que no sea insumo/categoría/presentación no recibió ningún
  cambio, y que su suite sigue en verde sin modificaciones. Confirmado: `git diff --stat` sobre ese
  archivo no muestra cambios; su suite pasa 65/65
- [X] T035 Confirmar que ninguna tabla paginada administrativa (listados de Insumos, Categorías o
  Presentaciones) ganó sondeo en segundo plano: `core/query/paged-query.ts` no se tocó, y
  `refreshAllItems()`/`refreshAllCategories()`/`refreshAllPresentations()` solo se llaman desde
  `product-form.component.ts` (research.md D5, FR-010). Confirmado por `git diff --stat` y `grep`
  de los tres métodos en todo `src/app`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias.
- **Foundational (Phase 2)**: vacía a propósito — ninguna historia bloquea a otra.
- **User Story 1 (Phase 3)**: depende solo de Setup. Independiente de US2/US3/US4.
- **User Story 2 (Phase 4)**: depende solo de Setup. Independiente de US1/US3/US4.
- **User Story 3 (Phase 5)**: depende solo de Setup. Independiente de US1/US2/US4.
- **User Story 4 (Phase 6)**: depende solo de Setup. Independiente de US1/US2/US3.
- **Polish (Phase 7)**: depende de que al menos US1 esté completa; T033 cubre las 4 historias si
  todas están completas.

### Dentro de cada fase

- Tests (T002-T003, T008-T010, T015-T019, T026-T027) se escriben y deben fallar antes de
  implementar.
- Dentro de US1: T004 (servicio) y la lectura combinada en el componente (T005/T006) son
  secuenciales porque el componente depende de que el servicio exista primero.
- Dentro de US2: `loadError` en la interfaz (T011) antes de usarlo en `product.service.ts` (T012).
- Dentro de US3: cada servicio nuevo (T020, T021) es independiente del otro; el wiring de cada
  selector en el componente (T022/T023, T024) depende de su propio servicio, no del otro.
- Dentro de US4: los tres `refreshAllX()` (T028, un método por servicio) antes de que el
  componente los llame (T029); `ngOnDestroy` (T030) depende de que `pollHandle` ya exista (T029).

### Parallel Opportunities

- T002 (US1) puede hacerse en paralelo con T008-T010 (US2), T015-T016 (US3) y T026 (US4) — todas
  tocan archivos distintos sin dependencias cruzadas.
- Las cuatro historias (Phases 3-6) pueden trabajarse en paralelo por personas distintas desde que
  termina Phase 1, al no depender ninguna de otra.
- T020, T021 (US3, archivos distintos) en paralelo entre sí.
- Dentro de T028 (US4), los tres métodos (`inventory.service.ts`, `category.service.ts`,
  `presentation.service.ts`) son archivos distintos y se implementan en paralelo entre sí.

---

## Parallel Example: Entre historias

```bash
# Las 4 historias son independientes entre sí una vez completada Phase 1:
Task: "Historia 1 — resolución de nombre real de insumos (inventory.service.ts + product-form.component.ts)"
Task: "Historia 2 — carga en paralelo de variantes (product.service.ts + product.interface.ts)"
Task: "Historia 3 — búsqueda remota en categorías/presentaciones (category.service.ts + presentation.service.ts + product-form.component.ts)"
Task: "Historia 4 — refresco en segundo plano (refreshAllX() en las 3 services + sondeo en product-form.component.ts)"
```

## Parallel Example: User Story 4

```bash
# Los tres refreshAllX() de T028 son archivos distintos, mismo cambio en cada uno:
Task: "refreshAllItems() en inventory.service.ts"
Task: "refreshAllCategories() en category.service.ts"
Task: "refreshAllPresentations() en presentation.service.ts"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Completar Phase 1: Setup.
2. Completar Phase 3: User Story 1.
3. **DETENER y VALIDAR**: correr quickstart.md Escenario 1.
4. El bug que ya afecta producción queda corregido; US2/US3/US4 pueden entregarse después, en
   cualquier orden, sin romper lo ya entregado.

### Incremental Delivery

1. Setup → base lista.
2. US1 → validar independientemente → bug de producción resuelto (MVP).
3. US2 → validar independientemente → tiempo de apertura deja de escalar con el número de tamaños.
4. US3 → validar independientemente → categoría y presentación alcanzan paridad de búsqueda con
   insumo.
5. US4 → validar independientemente → catálogos razonablemente actualizados sin recarga manual.
6. Phase 7 (Polish) → validación manual completa de `quickstart.md` + confirmación de que ningún
   consumidor/tabla fuera de alcance cambió de comportamiento.

### Parallel Team Strategy

Con varios desarrolladores: completar Phase 1 juntos; luego cada persona toma una historia
(US1-US4) de forma simultánea, sin coordinación adicional entre ellas (archivos distintos, sin
dependencias cruzadas); cada una se integra y valida por separado.

## Notes

- [P] = archivos distintos, sin dependencias entre sí.
- [US1]/[US2]/[US3]/[US4] mapean la tarea a su historia de usuario.
- Verificar que los tests fallan antes de implementar.
- No commitear salvo pedido explícito del usuario (Principio XV); cuando se commitee, en commits
  pequeños y enfocados (uno por historia es razonable), en inglés, sin ninguna marca de IA. Crear
  la rama `fix/102-product-form-catalogs` en `pos-heladeria` antes de tocar código (Principio
  XIV) — no aplica a `pos-backend`, que no se toca en esta spec.
- Evitar: tareas vagas, conflictos de archivo simultáneos, tocar `pos-backend`, tocar
  `selectedLabel()` de `searchable-select.component.ts` (research.md D1/D6), tocar el
  `defaultOptions` global del `QueryClient` o cualquier tabla paginada administrativa (research.md
  D5/D6), tocar `manual-order-page.component.ts` o cualquier otro consumidor de
  `app-searchable-select` fuera de insumo/categoría/presentación, cambiar la forma en que se
  guarda el producto (FR-015).
