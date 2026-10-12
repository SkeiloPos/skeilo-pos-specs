---

description: "Tareas de la spec 115 — pestaña dedicada de Promociones en el catálogo de la orden manual"
---

# Tasks: Pestaña dedicada de Promociones en el catálogo de la orden manual

**Input**: Documentos de diseño de `/specs/115-tab-promociones-pedido-manual/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [quickstart.md](./quickstart.md)

**Tests**: se incluyen tareas de test. `plan.md` (sección Constitution Check, Principio X) y
`research.md` (Decisión 7) exigen cobertura unitaria tanto del criterio compartido
(`hasPromotion`) como del filtrado, el estado de "abierto desde Promociones" y el paso de
cantidad, no solo validación manual. `pos-heladeria` usa Vitest vía `npx ng test` sobre los
`*.spec.ts` ya existentes.

**Organización**: tres historias de usuario (spec.md: US1 y US2 con prioridad P1, US3 con
prioridad P2), acotadas por completo a `../pos-heladeria` (sin cambios en `../pos-backend`, que no
interviene — el modelo de promociones y `GET /menu` se reutilizan sin modificación, ver plan.md,
Summary). **Alcance ampliado tras `/speckit-analyze`** (hallazgo C1, decisión del dueño del
producto): FR-014 exige que el filtro y el paso de cantidad apliquen tanto al catálogo de "crear
pedido nuevo" (`manual-order-page.component.ts`) como al de "+ Agregar producto" a un pedido ya
existente (`pos-catalog-drawer.component.ts`, usado por `pos-order-panel.component.ts` para mesa,
para llevar y domicilio por igual) — ver `research.md`, Decisión 6. Cada historia incluye ahora
tareas para ambos componentes.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: puede ejecutarse en paralelo (archivo distinto, o mismo archivo pero tests/bloques
  independientes entre sí, sin dependencia de una tarea sin terminar)
- **[Story]**: a qué historia de usuario pertenece (US1, US2, US3)
- Cada tarea incluye la ruta exacta del archivo, relativa a `../pos-heladeria` (repositorio
  hermano de este `pos-specs`) salvo que se indique lo contrario

## Convenciones de ruta

- `../pos-heladeria/...` — SPA Angular (TypeScript), único repositorio que cambia en esta spec
- Sin prefijo — archivo dentro de este repo (`pos-specs`)

---

## Phase 1: Setup

**Propósito**: preparar la rama de trabajo y confirmar la línea base antes de tocar código.

- [X] T001 Crear la rama `feat/115-tab-promociones-pedido-manual` desde la rama actual en
  `../pos-heladeria` (confirmar árbol de trabajo limpio antes de crearla; Principio XIV)
- [X] T002 Buscar en `../pos-heladeria` tests `"CONGELA comportamiento actual:"` que referencien
  `catalogProducts`, `catalogCategoryId`, `openConfig`, `incDraft`, `decDraft`,
  `addDraftFromSelection`, `hasPromotion` o `pos-catalog-drawer`
  (`grep -rn "CONGELA comportamiento actual" --include=*.spec.ts src/app/modules/tables/
  src/app/modules/promotions/`); si alguno congela la ausencia de un filtro de promociones o el
  paso fijo de `±1` como comportamiento protegido (en cualquiera de los dos catálogos), registrar
  en `research.md` que su actualización queda autorizada por esta spec (Principio III) antes de
  continuar — **resultado**: ningún test con ese prefijo referencia esos símbolos; nada que
  autorizar, vía libre
- [X] T003 [P] Ejecutar `npx ng test --watch=false --include='src/app/modules/tables/**/*.spec.ts'
  --include='src/app/modules/promotions/**/*.spec.ts'` en `../pos-heladeria` y registrar el
  resultado como línea base de regresión (Principio X), comparando contra la baseline ya conocida
  de fallas preexistentes documentada en memoria del proyecto — **línea base**: 874 passed / 3
  failed / 1 skipped en 2 archivos (`pos-checkout-panel.component.spec.ts` ×1 "T032: Imprimir
  Pre-cuenta", `pos-order-panel.component.spec.ts` ×2 "Marcar pedido listo") — coincide con la
  baseline documentada en memoria del proyecto

**Checkpoint**: rama creada, línea base de tests registrada — listo para implementar las
historias de usuario.

---

## Phase 2: Foundational (Blocking Prerequisites)

**No aplica a esta spec.** No existe una pieza compartida por las tres historias a la vez: el
criterio `hasPromotion()` solo lo necesita US1, el estado de "abierto desde Promociones" y el
paso de cantidad solo los necesita US2, y US3 es una historia de no-regresión que no agrega
código nuevo propio. Cada pieza se construye dentro de la fase de la historia que la necesita.

**Checkpoint**: N/A — continuar directamente a la Fase 3.

---

## Phase 3: User Story 1 - Encontrar todos los productos en promoción sin revisar categoría por categoría (Priority: P1) 🎯 MVP

**Goal**: un cajero o mesero puede seleccionar una nueva pestaña "Promociones" en la navegación
del catálogo — tanto al crear un pedido nuevo como al agregar productos a uno ya existente — y ver
únicamente los productos con promoción vigente de cualquier categoría, con su condición visible,
un mensaje claro cuando no hay ninguna vigente, y sin que esa pestaña se autoseleccione por
defecto.

**Independent Test**: en el catálogo de "Crear pedido manual" y en el catálogo de
"+ Agregar producto" de un pedido ya existente, confirmar que "Todos"/la primera categoría sigue
seleccionado por defecto, seleccionar "Promociones" y verificar que solo aparecen productos con
promoción vigente de distintas categorías, cada uno con su condición visible; confirmar el mensaje
de vacío cuando no hay ninguna promoción vigente (ver `quickstart.md`, Escenarios 1, 2 y 7).

### Tests for User Story 1 ⚠️

> Escribir estos tests primero y confirmar que fallan contra el código actual antes de
> implementar.

- [X] T004 [P] [US1] Test unitario: `hasPromotion(product)` en su nueva ubicación
  `../pos-heladeria/src/app/modules/promotions/services/promotion-pricing.util.spec.ts` — `true`
  si alguna variante del producto tiene `promotion != null`, `false` si ninguna
- [X] T005 [P] [US1] Test unitario: `PosTerminalStore.catalogProductsPromotionsFiltered` devuelve
  solo productos de cualquier categoría con `hasPromotion(p)` verdadero, lista vacía cuando no hay
  ninguno, y respeta el filtro de `catalogSearchText()` igual que `catalogProductsAllFiltered`, en
  `../pos-heladeria/src/app/modules/tables/services/pos-terminal.store.spec.ts`
- [X] T006 [P] [US1] Test de componente: `manual-order-page.component` renderiza el botón
  "Promociones" en la navegación del catálogo, junto a "Todos" y las categorías existentes, en
  `../pos-heladeria/src/app/modules/tables/pages/manual-order-page.component.spec.ts`
- [X] T007 [P] [US1] Test de componente: al seleccionar "Promociones", la grilla muestra
  únicamente los productos de `catalogProductsPromotionsFiltered` y cada tarjeta conserva la
  insignia de condición ya existente (`store.cardPromotionText`) — mismo archivo que T006
- [X] T008 [P] [US1] Test de componente: sin promociones vigentes, al seleccionar "Promociones" se
  muestra un mensaje explícito (p. ej. "No hay promociones activas en este momento") en vez de una
  grilla vacía sin explicación — mismo archivo que T006
- [X] T009 [P] [US1] Test de componente: al cargar la página sin ninguna interacción, "Todos" (o
  la categoría ya activa) permanece seleccionado — "Promociones" nunca se autoselecciona aunque
  haya promociones vigentes (FR-013) — mismo archivo que T006
- [X] T010 [P] [US1] Test de regresión: tras mover `hasPromotion()` fuera de
  `public-menu.component.ts`, los tests ya existentes de la pestaña "Promociones" del menú QR en
  `../pos-heladeria/src/app/modules/tables/pages/public-menu.component.spec.ts` siguen pasando sin
  ningún cambio de comportamiento
- [X] T011 [P] [US1] Test de componente: `pos-catalog-drawer.component` renderiza el botón
  "Promociones" en su fila de categorías (FR-014), en
  `../pos-heladeria/src/app/modules/tables/components/pos-catalog-drawer.component.spec.ts`
- [X] T012 [P] [US1] Test de componente: al seleccionar "Promociones" en el drawer, la grilla
  muestra únicamente `store.catalogProductsPromotionsFiltered()` en vez de
  `store.catalogProductsFiltered()`, conservando la insignia de condición — mismo archivo que T011
- [X] T013 [P] [US1] Test de componente: sin promociones vigentes, el drawer muestra el mismo
  mensaje explícito que `manual-order-page.component` en vez de una grilla vacía — mismo archivo
  que T011

### Implementation for User Story 1

- [X] T014 [US1] Extraer `hasPromotion(product: MenuProduct): boolean` desde
  `../pos-heladeria/src/app/modules/tables/pages/public-menu.component.ts` (línea ~1107) hacia
  `../pos-heladeria/src/app/modules/promotions/services/promotion-pricing.util.ts` como función
  exportada — depende de que T004 falle primero
- [X] T015 [US1] Actualizar `../pos-heladeria/src/app/modules/tables/pages/public-menu.component.ts`
  para importar `hasPromotion` desde `promotion-pricing.util.ts` en vez de su copia privada,
  eliminando la copia local — depende de T014; debe dejar pasando T010
- [X] T016 [US1] Agregar el computed `catalogProductsPromotionsFiltered` a
  `../pos-heladeria/src/app/modules/tables/services/pos-terminal.store.ts` (junto a
  `catalogProductsAllFiltered`, línea ~1226): junta todas las categorías
  (`this.categories().flatMap(c => c.products)`), filtra por `hasPromotion(p)` (importado de
  `promotion-pricing.util.ts`) y aplica el mismo filtro de `catalogSearchText()` — depende de
  T014, T005
- [X] T017 [US1] Agregar en `../pos-heladeria/src/app/modules/tables/pages/manual-order-page.component.ts`
  el signal local `showingPromotions = signal(false)` y el método `selectPromotions()` (desactiva
  `showingAllCategories` y no deja ninguna categoría marcada como activa, análogo a
  `selectAllCategories()`), y extender el computed local `catalogProducts()` (línea ~846-850) para
  devolver `store.catalogProductsPromotionsFiltered()` cuando `showingPromotions()` es `true` —
  depende de T016
- [X] T018 [US1] Agregar el botón de navegación "Promociones" a la plantilla de
  `manual-order-page.component.ts` (bloque de nav, líneas ~173-205), junto a "Todos" y las
  categorías, con el mismo estilo activo/inactivo ya usado para las demás pestañas — depende de
  T017
- [X] T019 [US1] Agregar el estado vacío ("No hay promociones activas en este momento.") en la
  grilla de `manual-order-page.component.ts` cuando `showingPromotions()` es `true` y la lista
  filtrada está vacía — depende de T017
- [X] T020 [US1] Agregar a `../pos-heladeria/src/app/modules/tables/components/pos-catalog-drawer.component.ts`
  el signal local `showingPromotions = signal(false)` (sin equivalente a "Todos": la alternativa
  es tener una categoría seleccionada vía `store.setCatalogCategory(id)`, que debe desactivar
  `showingPromotions`), el botón de nav "Promociones" junto a las categorías (líneas ~40-50), el
  cambio de fuente de la grilla a `store.catalogProductsPromotionsFiltered()` cuando está activa
  (líneas ~53-91), y el mismo mensaje de estado vacío que T019 — depende de T016

**Checkpoint**: la historia de usuario 1 está completamente funcional y probada de forma
independiente en **ambos** catálogos — la pestaña "Promociones" filtra correctamente, no se
autoselecciona por defecto, y muestra un estado vacío claro cuando no hay promociones vigentes.

---

## Phase 4: User Story 2 - Agregar al pedido respetando las unidades mínimas de la promoción (Priority: P1)

**Goal**: al agregar desde la pestaña "Promociones" (en cualquiera de los dos catálogos) un
producto cuya regla vigente tiene cantidad mínima mayor a 1, el pedido queda en pasos de esa
cantidad (incremento y decremento simétricos, retiro de la línea solo al llegar exactamente a 0);
con cantidad mínima 1 se agrega libre, una unidad a la vez; y los casos ya cubiertos por el
mecanismo compartido de `ProductSelectComponent` (ajuste al múltiplo más cercano, alcance limitado
a la variante/opciones cubierta, no combinación entre productos distintos) quedan verificados en
el contexto de la orden manual.

**Independent Test**: desde la pestaña "Promociones" de cualquiera de los dos catálogos (ya
entregada por US1), agregar un producto con regla "2 x $17.000" y verificar que la línea entra con
cantidad 2, sube de 2 en 2, baja de 2 en 2, y se retira al llegar a 0 (ver `quickstart.md`,
Escenarios 3 y 7); un producto con regla de cantidad mínima 1 se agrega de a una unidad
(Escenario 4).

### Tests for User Story 2 ⚠️

> Escribir estos tests primero y confirmar que fallan contra el código actual antes de
> implementar.

- [X] T021 [P] [US2] Test unitario: `PosTerminalStore.openConfig(product, true)` deja
  `configuringProductFromPromotions()` en `true`; `openConfig(product)` (sin segundo argumento),
  `closeConfig()` y `addDraftFromSelection()` lo dejan o lo resetean en `false`, en
  `../pos-heladeria/src/app/modules/tables/services/pos-terminal.store.spec.ts`
- [X] T022 [P] [US2] Test unitario: `addDraftFromSelection(sel)` con `sel.stepQuantity` definido
  guarda ese valor como `step` en la `ProductDraftLine` resultante; sin `stepQuantity`, la línea
  queda sin `step` (equivalente a paso 1) — mismo archivo que T021
- [X] T023 [P] [US2] Test unitario: `incDraft(key)`/`decDraft(key)` avanzan/retroceden en
  `x.step ?? 1`; una línea con `step: 2` pasa de 2 a 4 al incrementar, y de 2 a 0 (retirada por
  completo) al decrementar una vez — mismo archivo que T021
- [X] T024 [P] [US2] Test de componente: al pulsar una tarjeta desde la pestaña "Promociones" en
  `manual-order-page.component`, se invoca `store.openConfig(product, true)` y el
  `<app-product-select>` recibe `[fromPromotions]="true"`; desde "Todos" o una categoría, recibe
  `false`, en `../pos-heladeria/src/app/modules/tables/pages/manual-order-page.component.spec.ts`
- [X] T025 [P] [US2] Test de integración (store): agregar un producto con regla `min_qty = 2`
  desde "Promociones" (`stepQuantity = 2`) deja la línea de `draftLines` en cantidad 2, no 1;
  agregar uno con regla `min_qty = 1` (sin `stepQuantity`) deja la línea en cantidad 1 — mismo
  archivo que T021
- [X] T026 [P] [US2] Test de componente: igual que T024 pero para
  `pos-catalog-drawer.component` (FR-014), en
  `../pos-heladeria/src/app/modules/tables/components/pos-catalog-drawer.component.spec.ts`
- [X] T027 [P] [US2] Test de integración (store): un producto con dos variantes, solo una cubierta
  por una regla vigente — el paso forzado por cantidad mínima (FR-004) aplica únicamente a la
  combinación de variante/opciones efectivamente cubierta; la otra variante se agrega libre
  (FR-009) — mismo archivo que T021
- [X] T028 [P] [US2] Test de componente: reabrir desde "Promociones" la tarjeta de un producto que
  ya está en el pedido con una cantidad no múltiplo de su `min_qty` (agregada antes desde una
  categoría normal) ajusta la cantidad configurada hacia arriba al múltiplo más cercano antes de
  seguir incrementando/decrementando en pasos (FR-010) — mismo archivo que T024
- [X] T029 [P] [US2] Test de integración (store): una regla vigente que cubre dos variantes
  combinables entre sí — el paso forzado dentro de "Promociones" solo suma unidades del mismo
  producto en esa tarjeta, sin combinar con la otra variante para completar el mínimo compartido
  (FR-011) — mismo archivo que T021

### Implementation for User Story 2

- [X] T030 [US2] Agregar el signal `configuringProductFromPromotions = signal(false)` a
  `PosTerminalStore` y extender la firma de `openConfig` a
  `openConfig(product: MenuProduct, fromPromotions = false): void` para fijarlo; resetearlo en
  `closeConfig()` y al final de `addDraftFromSelection()`, en
  `../pos-heladeria/src/app/modules/tables/services/pos-terminal.store.ts` (líneas ~1689-1778) —
  depende de T021
- [X] T031 [US2] Agregar el campo opcional `step?: number` a la interfaz `ProductDraftLine`
  (`pos-terminal.store.ts`, líneas ~51-60) y poblarlo en `addDraftFromSelection()`
  (líneas ~1731-1778) desde `sel.stepQuantity`, preservando el valor previo si una línea existente
  se fusiona sin un `stepQuantity` nuevo en esa llamada — depende de T030, T022
- [X] T032 [US2] Actualizar `incDraft(key)`/`decDraft(key)` (líneas ~1816-1827) para usar
  `x.step ?? 1` en vez de `±1` fijo, manteniendo el filtro `quantity > 0` ya existente en
  `decDraft` para retirar la línea al llegar a 0 — depende de T031, T023
- [X] T033 [US2] Actualizar el handler de click de tarjeta en
  `../pos-heladeria/src/app/modules/tables/pages/manual-order-page.component.ts` (línea ~212, hoy
  `store.openConfig(p)`) para pasar `store.openConfig(p, showingPromotions())` — depende de T030
- [X] T034 [US2] Agregar el binding `[fromPromotions]="store.configuringProductFromPromotions()"`
  al `<app-product-select>` en `manual-order-page.component.ts` (líneas ~811-817) — depende de
  T033, T024
- [X] T035 [US2] Actualizar el handler de click de tarjeta en
  `../pos-heladeria/src/app/modules/tables/components/pos-catalog-drawer.component.ts`
  (línea ~68, hoy `store.openConfig(p)`) para pasar `store.openConfig(p, showingPromotions())` —
  depende de T030, T020
- [X] T036 [US2] Agregar el binding `[fromPromotions]="store.configuringProductFromPromotions()"`
  al `<app-product-select>` en `pos-catalog-drawer.component.ts` (líneas ~95-101) — depende de
  T035, T026

**Checkpoint**: las historias de usuario 1 y 2 funcionan juntas de forma independiente, en los dos
catálogos — agregar desde "Promociones" respeta la cantidad mínima en pasos simétricos (incluidos
los casos heredados de variante parcial, ajuste al múltiplo y no-combinación entre productos);
agregar desde cualquier otro punto sigue siendo libre.

---

## Phase 5: User Story 3 - Las categorías normales del catálogo no cambian su comportamiento (Priority: P2)

**Goal**: confirmar que agregar un producto desde "Todos", una categoría existente o el buscador
de cualquiera de los dos catálogos sigue siendo libre (una unidad a la vez), sin el paso forzado de
US2, incluso cuando ese producto tiene una promoción vigente con cantidad mínima mayor a 1 — tal
como se decidió en la sesión de clarificación sobre el buscador.

**Independent Test**: agregar el mismo producto con regla "2 x $17.000" desde su categoría
original o desde el buscador (no desde "Promociones"), tanto en "Crear pedido manual" como en
"+ Agregar producto" a un pedido existente, y verificar que entra con cantidad 1, no 2 (ver
`quickstart.md`, Escenario 5).

### Tests for User Story 3 ⚠️

> Escribir estos tests primero y confirmar que fallan (o ya pasan sin cambios, si no hay
> regresión) contra el código resultante de US1/US2 antes de cerrar la historia.

- [X] T037 [P] [US3] Test unitario de regresión: `catalogProductsFiltered` y
  `catalogProductsAllFiltered` no cambian de comportamiento tras T016 — no filtran por
  `hasPromotion`, en `../pos-heladeria/src/app/modules/tables/services/pos-terminal.store.spec.ts`
- [X] T038 [P] [US3] Test de componente: agregar un producto con regla `min_qty = 2` desde su
  categoría original (no desde "Promociones") en `manual-order-page.component` deja la línea en
  cantidad 1, y `<app-product-select>` recibe `[fromPromotions]="false"`, en
  `../pos-heladeria/src/app/modules/tables/pages/manual-order-page.component.spec.ts`
- [X] T039 [P] [US3] Test de componente: encontrar ese mismo producto con el buscador del catálogo
  (`store.catalogSearchText`, sin estar en la pestaña "Promociones") y agregarlo deja la línea en
  cantidad 1 — mismo archivo que T038 (cubre la aclaración de la sesión de clarificación sobre el
  buscador, FR-008)
- [X] T040 [P] [US3] Test de componente: igual que T038 pero para `pos-catalog-drawer.component`
  (FR-014), en
  `../pos-heladeria/src/app/modules/tables/components/pos-catalog-drawer.component.spec.ts`

### Implementation for User Story 3

- [X] T041 [US3] Verificación de no regresión: confirmar, sin cambio de código esperado, que nada
  de T014-T036 afecta `catalogProducts()`, `catalogProductsFiltered()`,
  `catalogProductsAllFiltered()` ni el valor por defecto de `fromPromotions` (`false`) cuando
  `openConfig` se invoca con un solo argumento, en ninguno de los dos catálogos — depende de
  T014-T036; tarea de verificación — **confirmado**: `catalogProducts()` (por categoría, línea
  ~1200), `catalogProductsFiltered()` y `catalogProductsAllFiltered()` no se tocaron; `openConfig`
  tiene `fromPromotions = false` como default; `git diff` sobre esas funciones está vacío salvo
  los cambios ya descritos en T016/T030

**Checkpoint**: las tres historias de usuario funcionan juntas sin regresión, en ambos catálogos —
catálogo completo, filtro de promociones, y pasos de cantidad correctos según el punto de entrada.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Propósito**: cerrar la verificación global antes de dar la spec por completada.

- [X] T042 [P] Ejecutar la suite completa `npx ng test --watch=false` en `../pos-heladeria` y
  confirmar que el conjunto de archivos con fallas preexistentes no crece respecto a la baseline
  registrada en T003 (Principio X) — **resultado**: 1682 passed / 10 failed / 1 skipped, mismo
  conjunto exacto de 6 archivos que la baseline conocida en memoria del proyecto (`app.spec`,
  `auth.service`, `menu.service`, `tenant.service`, `pos-checkout-panel`, `pos-order-panel`) —
  ningún archivo nuevo con fallas, ninguna falla nueva atribuible a esta spec
- [X] T043 [P] Releer el Constitution Check de [plan.md](./plan.md) tras implementar y confirmar
  que ninguna entrada nueva en `specs/000-reconocimiento/registro-de-anomalias.md` resultó
  necesaria — este cambio no redefine ninguna regla de negocio de precio o descuento, solo
  reutiliza la ya existente desde dos puntos de entrada — **confirmado**: sin cambios de
  precio/cálculo de descuento, sin nuevas dependencias, alcance acotado a 4 archivos de producción
  (`promotion-pricing.util.ts`, `pos-terminal.store.ts`, `manual-order-page.component.ts`,
  `pos-catalog-drawer.component.ts`) + 1 ajuste menor en `public-menu.component.ts`; nada que
  registrar
- [X] T044 [P] Test de integración (store): un pedido con una línea en promoción (cantidad ya
  múltiplo de su `min_qty`) y una línea de un producto normal, guardado/cobrado para los tres
  valores de `orderTypeTab` (`mesas`, `para-llevar`, `domicilios`), deja el total esperado —
  responde directamente al hallazgo C7 de `/speckit-analyze` sobre cálculo de total con carrito
  mixto, en `../pos-heladeria/src/app/modules/tables/services/pos-terminal.store.spec.ts` —
  **resultado**: 3 casos (`it.each` por tipo de pedido) confirman que `createManualOrderFromDraft`
  envía ambas líneas (variante en promoción cantidad 2 + variante normal cantidad 1) al backend sin
  ninguna rama por tipo de pedido — el cálculo del descuento en sí sigue siendo responsabilidad
  exclusiva del motor de backend ya existente (`evaluate_variant_sets`), no de este cambio
- [ ] T045 Ejecutar manualmente los 8 escenarios de [quickstart.md](./quickstart.md) en un entorno
  de desarrollo (`npx ng serve` + backend corriendo, con al menos una promoción vigente de
  `min_qty = 2` seeded) y registrar el resultado de cada uno, incluyendo los tres tipos de pedido
  del Escenario 7 — **pendiente**: esta sesión no tiene credenciales de un tenant ni una promoción
  vigente ya seeded para iniciar sesión como cajero/mesero y navegar la Terminal de Mesas; los 8
  escenarios ya quedan cubiertos a nivel de lógica/render por T004-T040 (rojo→verde confirmado en
  cada paso), y la validación visual en navegador queda pendiente de que el usuario la confirme
  antes de mergear (mismo patrón que specs 110/113)
- [X] T046 [P] Hallazgo del dueño del producto al revisar la implementación en un entorno real
  (no estaba en `tasks.md` original): la línea de un producto con promoción de precio de paquete
  (`min_qty > 1`) no mostraba ninguna insignia en el carrito de la orden manual (causa raíz:
  `cartLinePromo()` en `pos-terminal.store.ts` depende de `variant.discounted_price`, que el
  backend nunca puebla para ese tipo de regla — solo para `min_qty = 1`), y el resumen de la orden
  mostraba una fila "Descuento" genérica sin esa explicación. Decisión de negocio (registrada como
  **A-125** en `specs/000-reconocimiento/registro-de-anomalias.md`): ocultar la fila "Descuento"
  del resumen en borrador de `manual-order-page.component.ts`, manteniendo "Subtotal" y
  "TOTAL ORDEN" tal como están (el cálculo no cambia, solo la fila intermedia) — **resultado**: se
  quitó el binding `[discount]="+p.discount"` del único `<app-bill-summary>` de ese archivo que lo
  pasaba (línea ~754); `BillSummaryComponent` en sí no se modifica (sigue compartido con
  `pos-checkout-panel`/`payment-attempt-review-panel`/`session-bill-panel`, que conservan su fila
  "Descuento" sin cambio). Se actualizaron 2 tests existentes en
  `manual-order-page.component.spec.ts` ("desglose del borrador spec 073 US5" Scenario 2, y "TOTAL
  ORDEN con ítems guardados spec 087 US10") para dejar de esperar el texto "Descuento", citando
  A-125
- [X] T047 [P] Hallazgo adicional del dueño del producto (captura de pantalla del carrito): la
  línea del producto también debía mostrar la insignia/tachado/"Ahorras $X" para promociones de
  paquete, igual que ya se ve en el modal de selección (lo que en T046 se había dejado anotado
  como "fuera de alcance" pasó a implementarse en la misma sesión) — **resultado**: se extrajo
  `packagePrice()` desde `product-select.component.ts` al util compartido
  `promotion-pricing.util.ts` (mismo patrón de deduplicación que `hasPromotion`, T014);
  `cartLinePromo()` en `pos-terminal.store.ts` ahora usa `packagePrice()` cuando
  `promo.min_qty > 1` en vez de depender únicamente de `variant.discounted_price`. Tests nuevos:
  `promotion-pricing.util.spec.ts` (5 casos para `packagePrice`), `pos-terminal.store.spec.ts`
  (`cartView — promo por línea`, 2 casos nuevos con `min_qty > 1`), `manual-order-page.component.spec.ts`
  (caso nuevo reproduciendo el reporte exacto, "2 x $15.000"). 2 tests existentes con fixtures
  irreales (`min_qty: 2` + `discounted_price`) se corrigieron a `min_qty: 1` sin cambiar los
  importes esperados. Registrado en la actualización de A-125 del 2026-10-12. Suite completa:
  1690 passed / 10 failed, mismo conjunto exacto de 6 archivos de la baseline; `npx ng build`
  limpio
- [X] T048 [P] Hallazgo adicional del dueño del producto (revisión en entorno real, captura del
  contador "- 1 +"): el control +/- de una línea YA agregada al pedido no debe replicar el paso
  de cantidad mínima de la promoción — debe avanzar siempre de 1 en 1, sin importar si esa línea
  tiene promoción vigente, a diferencia del menú QR. **Revierte parcialmente T031/T032** (que
  habían implementado exactamente lo contrario, siguiendo FR-004/FR-006 como se habían
  especificado inicialmente). Decisión de negocio registrada como **A-126** en
  `specs/000-reconocimiento/registro-de-anomalias.md` — **resultado**: se quitó por completo el
  campo `step?: number` de `ProductDraftLine`, su población en `addDraftFromSelection()` (ambas
  ramas: línea nueva y fusión con una existente), y el helper `draftStep()`; `incDraft`/`decDraft`
  vuelven a `quantity ± 1` sin condición. **Lo que NO cambia**: `openConfig(product,
  fromPromotions)` y `configuringProductFromPromotions` (T030) siguen intactos — el primer
  agregado desde "Promociones" sigue entrando con la cantidad mínima de la regla, vía el modal de
  selección (`ProductSelectComponent`, spec 081, sin tocar). Se actualizaron `spec.md` (FR-004,
  FR-006 reescrito, Acceptance Scenarios 2-4 de US2, SC-002, SC-004, Assumptions, nueva
  Clarification), `research.md` (Decisión 5 marcada como revertida), `data-model.md` (se retira
  toda la documentación del campo `step`) y `quickstart.md` (Escenario 3 reescrito). Tests:
  `pos-terminal.store.spec.ts` pierde los 4 casos sobre el campo `step` (antes T022/T025/T027/T029)
  y gana 2 casos nuevos confirmando `incDraft`/`decDraft` siempre de 1 en 1 — 183 passed en ese
  archivo. Suite completa tras el cambio: 910 passed / 3 failed en el subconjunto
  `tables`+`promotions` (misma baseline preexistente, sin fallas nuevas)
- [X] T049 [P] Hallazgo adicional del dueño del producto (captura del resumen tras A-125): tras
  ocultar la fila "Descuento", "Subtotal" seguía mostrando el importe bruto ($16.000) mientras la
  línea del producto (A-125/T047) y "TOTAL ORDEN" ya mostraban el importe neto ($15.000) — dos
  cifras distintas para la misma mercancía. Decisión de negocio registrada como **A-127** en
  `specs/000-reconocimiento/registro-de-anomalias.md`: "Subtotal" también debe mostrarse neto —
  **resultado**: se cambió el binding `[subtotal]="+p.subtotal + store.combosSubtotal()"` a
  `[subtotal]="+p.subtotal - +p.discount + store.combosSubtotal()"` en el único
  `<app-bill-summary>` de `manual-order-page.component.ts` que ya tocó A-125 (línea ~754); la
  rama `@else` (sin `draftPreview` resuelto todavía) no cambia, no tiene descuento que restar.
  Tests: se actualizó el test "Scenario 2" de A-125 (ya no espera ver el bruto 16.000 en el
  resumen) y se agregó un test nuevo que reproduce el reporte exacto ("ojo de diablo", Subtotal y
  TOTAL ORDEN ambos 15.000); ambos acotados al elemento `<app-bill-summary>` (nuevo helper
  `billSummaryText()`) en vez de a toda la página, porque el costo bruto de otra línea sin
  promoción puede coincidir por casualidad con una de las cifras buscadas. Suite completa:
  1688 passed / 10 failed, mismo conjunto exacto de 6 archivos de la baseline; `npx ng build`
  limpio
- [X] T050 [P] Hallazgo adicional del dueño del producto (revisión de un pedido ya creado, estado
  "Pendiente"): un ítem ya persistido pero aún sin cobrar seguía mostrándose a precio de lista
  completo, sin insignia, aunque su variante tuviera una promoción de paquete vigente en el
  catálogo — distinto del tratamiento que la línea de borrador ya tiene desde A-125/T047.
  Decisión de negocio registrada como **A-128** en `specs/000-reconocimiento/registro-de-anomalias.md`:
  estimar la misma insignia/tachado con la promoción vigente del catálogo mientras el backend no
  congele el descuento real (recién al cobrar) — **resultado**: `MenuLookup` (`menu-lookup.ts`)
  gana `variantPromotion(variantId)`; `persistedLinePromo()` en `pos-terminal.store.ts` gana un
  quinto parámetro `catalogPromo` y, cuando `discounted_unit_price` es `null`, usa `packagePrice()`
  (igual que `cartLinePromo()`, T047) para estimar la insignia en vez de devolver `null`; el
  call site en `persistedItemsView()` pasa `lk.variantPromotion(i.product_variant_id)`. Tests
  nuevos: `menu-lookup.spec.ts` (2 casos para `variantPromotion`), `pos-order-panel.component.spec.ts`
  (2 casos: con promoción de catálogo → insignia estimada; sin promoción → sin insignia). Suite
  completa: 1692 passed / 10 failed, mismo conjunto exacto de 6 archivos de la baseline;
  `npx ng build` limpio
- [X] T051 [P] Hallazgo adicional del dueño del producto (comparación modal vs. panel de pedido):
  la insignia resultante de T050 usaba un esquema rojo con sufijo " Promoción" + una píldora verde
  "Ahorras $X" aparte, que no coincidía con el formato indigo del modal de selección
  (`product-select.component.ts`, `data-testid="variant-promo"`) para la misma promoción.
  Decisión de negocio registrada como **A-129** en `specs/000-reconocimiento/registro-de-anomalias.md`:
  el panel de pedido debe reproducir el formato del modal — **resultado**: en
  `pos-order-panel.component.ts`, el bloque de plantilla de `it.promo` (líneas ~206-248) cambió de
  `bg-[#fee2e2] text-[#dc2626]` + "{{ promo.badge }} Promoción" + fila aparte con tachado y
  píldora verde "Ahorras", a una insignia `bg-[#e0e7ff] text-[#4338ca]` con solo
  `{{ promo.badge }}` debajo del nombre, y el precio tachado + `text-[#4f46e5]` con descuento
  juntos en la misma línea (sin píldora "Ahorras"). Aplica a toda línea con promoción de ese panel
  (draft, "Pendiente" estimada de T050, o ya cobrada) porque comparten el mismo bloque.
  `manual-order-page.component.ts` (esquema ámbar propio) no se tocó — no se pidió. Tests: ningún
  test existente verificaba clases/texto de color (solo valores de `row.promo` vía el store), así
  que ninguno se rompió; se agregó un test nuevo que confirma que la condición aparece en el DOM y
  que "Promoción"/"Ahorras" ya no aparecen. Suite completa: 1693 passed / 10 failed, mismo
  conjunto exacto de 6 archivos de la baseline; `npx ng build` limpio
- [X] T052 [P] Hallazgo adicional del dueño del producto (mismo pedido, comparando cifras entre
  filas): el subtítulo "{{ qty }} × $precio" de una línea en promoción seguía anclado al precio
  de lista ("2 × $8.000" = $16.000), que no cuadraba con el importe neto mostrado arriba
  ($15.000) para la misma línea. Decisión de negocio registrada como **A-130** en
  `specs/000-reconocimiento/registro-de-anomalias.md` — **resultado**: nuevo método
  `netUnitPrice(it)` en `pos-order-panel.component.ts` que devuelve
  `(promo.discountedAmount - addonsTotal) / qty` cuando hay promoción (si no, `it.unitPrice` sin
  cambio); el subtítulo ahora usa `netUnitPrice(it)` en vez de `it.unitPrice` directamente.
  `it.unitPrice`/`it.subtotal` de la línea no cambian (siguen a precio de lista, FR-023) — solo
  cambia qué número se pinta en ese subtítulo. Test nuevo: "2 × $7.500" en vez de "2 × $8.000"
  para la línea del reporte.
- [X] T053 [P] Hallazgo adicional del dueño del producto (pantalla de cobro, "Facturar a nombre
  de"): el panel de cobro (`pos-checkout-panel.component.ts`) tiene su **propio** binding de
  `<app-bill-summary>`, independiente del de `manual-order-page.component.ts` que ya corrigieron
  T046/T049 (A-125/A-127) — seguía mostrando la fila "Descuento" y "Subtotal" bruto. Decisión de
  negocio registrada como **A-131** en `specs/000-reconocimiento/registro-de-anomalias.md`: mismo
  tratamiento que A-125/A-127, en esta tercera pantalla — **resultado**: se quitó
  `[discount]="+p.discount"` y se cambió `[subtotal]="+p.subtotal"` a
  `[subtotal]="+p.subtotal - +p.discount"` en `pos-checkout-panel.component.ts` (líneas ~282-290).
  Tests actualizados: "FR-004" (Scenario 1) y "US3 Scenario 3" en
  `pos-checkout-panel.component.spec.ts`, que esperaban ver "Descuento" y el bruto — ahora esperan
  que NO aparezcan, con Subtotal/Total ya netos. Suite completa tras T052/T053: 1694 passed /
  10 failed, mismo conjunto exacto de 6 archivos de la baseline; `npx ng build` limpio
- [X] T054 [P] Hallazgo adicional del dueño del producto ("Cuenta de la mesa", sección "Ya
  pagado"): cuarta pantalla con el mismo problema de la fila "Descuento"/Subtotal bruto.
  Decisión de negocio registrada como **A-132** en `specs/000-reconocimiento/registro-de-anomalias.md`:
  mismo tratamiento que A-125/A-127/A-131 — **resultado**: en `session-bill-panel.component.ts`
  se quitó `[discount]` y se ajustó `[subtotal]` a neto (`subtotal - discount`) en los **dos**
  bloques de `<app-bill-summary>` del archivo — "Ya pagado" (`pagado.*`, líneas ~64-71) y "Total a
  cobrar"/"Subtotal mesa" (`summary.*`, líneas ~97-104) — corregidos juntos por estar en la misma
  pantalla, aunque solo se mostró explícitamente el primero. `payment-attempt-review-panel.component.ts`
  y `orders/pages/order-detail.component.ts` (con su propia decisión ya establecida, A-106/spec
  094) **no se tocan** — no se pidieron. Tests actualizados en
  `session-bill-panel.component.spec.ts` ("resumen agregado Subtotal/Descuento" con descuento, y
  "con paidSummary..."), citando esta entrada. Suite completa: 1694 passed / 10 failed, mismo
  conjunto exacto de 6 archivos de la baseline; `npx ng build` limpio
- [X] T055 [P] Hallazgo adicional del dueño del producto (cantidad ajustada a un valor que no
  completa un paquete exacto, posible desde A-126): el subtítulo "{{ qty }} × ..." que T052/A-130
  había corregido mostraba un precio por unidad promediado ("3 × $7.667" para 3 unidades de una
  regla "2 x $15.000") que no corresponde a ningún precio real cobrado. Decisión de negocio
  registrada como **A-133** en `specs/000-reconocimiento/registro-de-anomalias.md`: quitarlo por
  completo con promoción, en vez de arreglar el cálculo — **revierte T052** — **resultado**: en
  `pos-order-panel.component.ts`, el `<div>` de "{{ qty }} × ..." queda envuelto en
  `@if (!it.promo)`; se retira el método `netUnitPrice()` (T052) por quedar sin ningún uso; sin
  promoción el comportamiento es idéntico al que había antes de T052. Tests: se reemplazó el test
  de T052 por uno que confirma la ausencia total de "{{ qty }} × ..." con promoción, y uno nuevo
  que confirma que sigue mostrándose sin promoción. Suite completa: 1695 passed / 10 failed,
  mismo conjunto exacto de 6 archivos de la baseline; `npx ng build` limpio

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias — puede iniciar de inmediato
- **Foundational (Phase 2)**: N/A, no bloquea nada
- **User Story 1 (Phase 3)**: depende de Setup (T001-T003) completo
- **User Story 2 (Phase 4)**: depende de que US1 (Phase 3) esté completa — necesita la pestaña
  "Promociones" y `showingPromotions()` ya existentes en ambos catálogos para poder pasar
  `fromPromotions` al abrir el modal
- **User Story 3 (Phase 5)**: depende de que US1 y US2 (Phases 3-4) estén completas — es una
  historia de no-regresión sobre lo que ambas introdujeron
- **Polish (Phase 6)**: depende de que las Fases 3-5 estén completas

### Within Each User Story

- Los tests de cada historia se escriben primero y deben fallar contra el código actual (o, en
  US3, confirmar ausencia de regresión) antes de implementar
- Dentro de US1: T014 (extracción de `hasPromotion`) bloquea T015 (actualizar `public-menu`) y
  T016 (nuevo computed); T016 bloquea T017 (estado de `manual-order-page`) y T020 (estado del
  drawer); T017 bloquea T018 (botón de nav) y T019 (estado vacío) de `manual-order-page`
- Dentro de US2: T030 (signal + firma de `openConfig`) bloquea T031 (campo `step`), T033 y T035
  (actualizar los handlers de click de ambos catálogos); T031 bloquea T032 (`incDraft`/`decDraft`);
  T033 bloquea T034 (binding en `manual-order-page`); T035 (que también depende de T020) bloquea
  T036 (binding en el drawer)
- Dentro de US3: T041 depende de que toda la implementación de US1/US2 (T014-T036) esté terminada

### Parallel Opportunities

- T004-T013 pueden escribirse en paralelo entre sí (archivos distintos, o mismo archivo con tests
  independientes)
- T002 y T003 pueden ejecutarse en paralelo (ambas de solo lectura/verificación)
- T018 y T019 pueden implementarse en paralelo una vez completado T017 (bloques de plantilla
  distintos dentro del mismo archivo); T020 puede implementarse en paralelo con T017-T019 (archivo
  distinto), una vez completado T016
- T021-T029 pueden escribirse en paralelo entre sí
- T033 y T035 pueden implementarse en paralelo una vez completado T030 (archivos distintos)
- T037-T040 pueden escribirse en paralelo entre sí
- T042, T043 y T044 pueden ejecutarse en paralelo

---

## Parallel Example: User Story 1

```bash
# Lanzar los tests de la historia de usuario 1 juntos:
Task: "Test: hasPromotion() en su nueva ubicación (T004)"
Task: "Test: catalogProductsPromotionsFiltered filtra por hasPromotion y respeta el buscador (T005)"
Task: "Test de componente: botón de nav 'Promociones' en manual-order-page (T006)"
Task: "Test de componente: grilla filtrada al seleccionar 'Promociones' en manual-order-page (T007)"
Task: "Test de componente: mensaje de vacío sin promociones vigentes en manual-order-page (T008)"
Task: "Test de componente: 'Todos' permanece seleccionado por defecto en manual-order-page (T009)"
Task: "Test de regresión: pestaña 'Promociones' del menú QR sigue pasando (T010)"
Task: "Test de componente: botón de nav 'Promociones' en pos-catalog-drawer (T011)"
Task: "Test de componente: grilla filtrada en pos-catalog-drawer (T012)"
Task: "Test de componente: mensaje de vacío en pos-catalog-drawer (T013)"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Completar Fase 1: Setup (rama + línea base)
2. Fase 2: N/A, pasar directo a Fase 3
3. Completar Fase 3: User Story 1 (tests → extracción de `hasPromotion` → nuevo computed → nav +
   estado vacío en ambos catálogos)
4. **DETENER y VALIDAR**: confirmar los Escenarios 1, 2 y 7 de `quickstart.md`
5. Desplegar/demostrar si está listo — el personal ya puede ver todos los productos en promoción
   en un solo lugar, en cualquiera de los dos catálogos, aunque agregarlos todavía se comporte
   como hoy (US2 pendiente)

### Incremental Delivery

1. Completar Setup → línea base lista
2. Agregar US1 → probar de forma independiente → demo (MVP: ver promociones agrupadas en ambos
   catálogos)
3. Agregar US2 → probar de forma independiente → demo (agregar respeta la cantidad mínima en
   ambos catálogos)
4. Agregar US3 → probar de forma independiente → demo (confirmación de no-regresión en el resto
   de ambos catálogos)
5. Completar Fase 6: Polish (regresión completa + validación manual de los 8 escenarios + cierre
   de gobernanza)

### Notas

- `[P]` = archivos distintos, o mismo archivo con tests/bloques independientes entre sí, sin
  dependencia de una tarea sin terminar
- `[US1]`/`[US2]`/`[US3]` identifican cada tarea con su historia de usuario correspondiente
- Confirmar que los tests fallan antes de implementar (T004-T013, T021-T029, T037-T040 antes de
  sus tareas de implementación correspondientes)
- Los commits solo se ejecutan si el usuario lo pide explícitamente, en unidades pequeñas y
  lógicas, en inglés, sin marcas de autoría de IA (Principio XV)
