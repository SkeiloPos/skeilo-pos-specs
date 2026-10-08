---

description: "Task list for feature implementation"
---

# Tasks: Quitar la precarga de catálogos completos en los selectores del formulario de producto (categoría, insumos, presentación)

**Input**: Design documents from `/specs/105-selectores-producto-sin-precarga/`
**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: incluidos — el plan y los contratos ya comprometen ficheros de test concretos
(Principio X, Verificación Obligatoria), siguiendo el mismo criterio que las specs 098/102.

**Organización**: tres historias de usuario (US1 P1, US2 P1, US3 P2), las tres **100% frontend**
(`pos-heladeria`) — `pos-backend` no se toca (plan.md, Technical Context: `GET /products/{id}` ya
expone todo lo necesario desde las specs 097/103). US1 (quitar las tres llamadas de precarga) es
el cambio mínimo y el MVP. US2 (nombre real del valor ya guardado) no requiere código nuevo más
allá de US1 — los mecanismos que la cumplen ya existen desde la spec 102/103 — por lo que su fase
es principalmente de verificación/regresión. US3 (la búsqueda sigue funcionando igual) es donde
vive el trabajo nuevo real: el hallazgo de `research.md` (Decisión D1) de que elegir un resultado
de búsqueda hoy no fija su nombre de forma confiable sin la precarga, y necesita una extensión
aditiva del componente compartido `app-searchable-select`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: se puede hacer en paralelo (archivo distinto, sin dependencia de una tarea sin
  terminar); para tareas de **escritura de test**, también se marca `[P]` cuando dos casos nuevos
  conviven en el mismo archivo de test pero son independientes entre sí (mismo criterio ya usado
  en la spec 102 para sus tests de Historia 3)
- **[Story]**: US1, US2, US3

---

## Phase 1: Setup

- [X] T001 Confirmar línea base en `pos-heladeria`: `cd ../pos-heladeria && npx ng test
  --watch=false` y comparar por **conjunto de archivos con fallos preexistentes**, no por conteo
  literal (el conteo exacto varía entre corridas — ver memoria del proyecto sobre cómo correr los
  tests de los repos hermanos). No hace falta confirmar línea base de `pos-backend`: esta spec no
  lo toca (plan.md, Technical Context).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: a diferencia de una spec con infraestructura compartida nueva, aquí no hay ningún
mecanismo nuevo que dos o más historias necesiten antes de empezar: US1 solo quita líneas ya
existentes en `product-form.component.ts`; US2 no agrega código; US3 extiende
`searchable-select.component.ts`, un archivo que US1 no toca. El único acoplamiento real entre
historias es de **validación**, no de código (ver Dependencies & Execution Order), así que no
bloquea el inicio de ninguna.

**Esta fase no tiene tareas.** Cada historia puede empezar directamente después de Phase 1.

---

## Phase 3: User Story 1 - Abrir el formulario de producto no dispara peticiones de catálogo completo (Priority: P1) 🎯 MVP

**Goal**: abrir el formulario de crear o editar un producto deja de disparar
`GET /categories?size=100`, `GET /items?size=100` y `GET /presentations?size=100`.

**Independent Test**: con el panel de red del navegador abierto, abrir el formulario de crear un
producto nuevo y el de editar uno existente, y verificar que ninguna de las tres peticiones de
precarga aparece en ninguno de los dos casos (quickstart.md, Escenario 1).

### Tests for User Story 1

- [X] T002 [P] [US1] Escribir test en
  `pos-heladeria/src/app/modules/products/pages/product-form.component.spec.ts`: al llamar
  `ngOnInit()` (crear o editar), **no** se invoca `categoryService.loadAllCategories()`,
  `inventoryService.loadAllItems()` ni `presentationService.loadAllPresentations()` (espías/mocks
  de los tres servicios) — `unitMeasureService.loadUnitMeasures()` y
  `optionGroupService.loadGroups()` siguen invocándose sin cambios (fuera de alcance, FR-001/
  FR-002) — debe fallar antes de implementar
- [X] T003 [P] [US1] Escribir test en
  `pos-heladeria/src/app/modules/products/pages/product-form.component.spec.ts`: con un producto
  donde ninguna presentación activa está libre, `hasFreePresentations()` sigue devolviendo
  `false` (mensaje "No hay más presentaciones disponibles"); con al menos una presentación activa
  libre, devuelve `true` ("Elige una presentación") — ambos casos sin que
  `presentationService.allPresentations()` tenga datos (simulando la precarga ya eliminada),
  usando en su lugar `searchActivePresentations('')` (`contracts/removed-preload-requests.md`,
  Decisión D2 de `research.md`) — debe fallar antes de implementar

### Implementation for User Story 1

- [X] T004 [US1] En
  `pos-heladeria/src/app/modules/products/pages/product-form.component.ts`, `ngOnInit()`
  (~líneas 970-985), quitar las tres llamadas
  `categoryService.allCategories().length === 0 ? categoryService.loadAllCategories() : null`,
  `inventoryService.allItems().length === 0 ? inventoryService.loadAllItems() : null` y
  `presentationService.allPresentations().length === 0 ? presentationService.loadAllPresentations() : null`
  del `Promise.all([...])`, dejando intactas las de `unitMeasureService`/`optionGroupService`;
  actualizar el comentario que las precede (ya no aplica: describía por qué el antiguo `<select>`
  nativo necesitaba sus `<option>` precargadas, algo que `app-searchable-select` —ya en uso desde
  la spec 102— no requiere, al resolver sus opciones de forma reactiva) — depende de T002
- [X] T005 [US1] En
  `pos-heladeria/src/app/modules/products/pages/product-form.component.ts`, cambiar
  `hasFreePresentations()` (líneas 654-657) de depender de `presentationService.allPresentations()`
  a calcularse con una verificación puntual vía `presentationService.searchActivePresentations('')`
  (ya existente, spec 102), disparada de forma perezosa — no en `ngOnInit()` — comparando el
  resultado contra los `presentationId` ya usados por las demás filas del draft, igual que hoy —
  depende de T003
- [X] T006 [US1] Ejecutar T002 y T003, confirmar que ahora pasan; reejecutar toda la suite de
  `pos-heladeria` (comando de T001) y confirmar que sigue en la misma línea base — depende de
  T004, T005

**Checkpoint**: Historia de Usuario 1 funciona de punta a punta — quickstart.md Escenario 1
verificable; las tres peticiones de precarga desaparecen del panel de red.

---

## Phase 4: User Story 2 - Un valor ya seleccionado siempre muestra su nombre real, usando el detalle del producto (Priority: P1)

**Goal**: cada uno de los tres selectores (categoría, presentación por tamaño, insumo de
receta/consumo) sigue mostrando el nombre real de su valor ya guardado, sin depender de la
precarga eliminada en US1.

**Independent Test**: editar un producto con categoría, presentación e insumo de receta ya
guardados y que existan fuera de los primeros 100 registros de su catálogo respectivo; verificar
que los tres muestran su nombre real de inmediato, sin buscar nada (quickstart.md, Escenario 2).
Crear un producto nuevo y verificar que los tres selectores aparecen vacíos (quickstart.md,
Escenario 3).

### Tests for User Story 2

- [X] T007 [P] [US2] Escribir/actualizar test en
  `pos-heladeria/src/app/modules/products/pages/product-form.component.spec.ts`: (a) al editar un
  producto cuyo `category_id`/`presentationId` (de una variante)/`inventory_item_id` (de una fila
  de receta) no están en `allCategories()`/`allPresentations()`/`allItems()` (ahora siempre vacíos
  tras T004), los tres selectores muestran el nombre real correspondiente
  (`category_name`/`presentationName`/el insumo resuelto por `resolveMissingItems`) sin disparar
  ninguna búsqueda — FR-003; (b) un insumo, categoría o presentación ya seleccionados y luego
  desactivados siguen mostrando su nombre real al reabrir el formulario — FR-007; (c) al crear un
  producto nuevo (sin id), los tres selectores aparecen sin ningún valor preseleccionado — FR-004.
  Se espera que este test **ya pase** una vez aplicado T004 (research.md documenta que
  `category_name`/`presentationName` del draft y `resolveMissingItems()` ya cubren este caso desde
  las specs 097/102/103, sin código nuevo) — si falla, hay una regresión sobre esos mecanismos

### Implementation for User Story 2

- [X] T008 [US2] Ejecutar T007 y confirmar que pasa sin necesitar cambios de código adicionales
  más allá de T004 (US1); si falla, diagnosticar sobre cuál de los tres mecanismos existentes
  (`category_name`/`presentationName` del draft, o `resolveMissingItems()`/`resolvedExtraItems`
  de `inventory.service.ts`) se rompió al quitar la precarga, y corregirlo ahí — depende de T007,
  T004

**Checkpoint**: Historia de Usuario 2 funciona de punta a punta — quickstart.md Escenarios 2 y 3
verificables; ningún valor ya guardado (ni un producto nuevo) depende de la precarga eliminada.

---

## Phase 5: User Story 3 - Buscar en cualquiera de los tres selectores sigue funcionando exactamente igual que antes (Priority: P2)

**Goal**: cada selector sigue permitiendo buscar y elegir cualquier registro activo por texto
parcial (sin cambios en ese mecanismo), y además el registro recién elegido durante la sesión de
edición muestra su nombre real de inmediato, sin depender de la precarga eliminada (hallazgo de
`research.md`, Decisión D1) ni de una petición de red adicional evitable. Abrir cualquier selector
sin escribir texto muestra un mensaje que invita a buscar, no una lista vacía sin explicación ni
"Sin resultados" antes de tiempo.

**Independent Test**: en un tenant con más de 100 registros activos en cada catálogo, buscar y
elegir —en cada uno de los tres selectores— un registro que exista fuera de los primeros 100;
verificar que aparece, se puede seleccionar, y que inmediatamente después de elegirlo el selector
muestra su nombre real sin una petición de red adicional evitable (quickstart.md, Escenario 4).

### Tests for User Story 3

- [X] T009 [P] [US3] Escribir test en
  `pos-heladeria/src/app/shared/searchable-select/searchable-select.component.spec.ts`: al elegir
  una opción (de `options` local o de un resultado de `search` remoto), el componente emite un
  nuevo `@Output() optionPicked` con la opción completa (`{id, label}`) **además** de, no en vez
  de, el `onChange(opt.id)` existente del `ControlValueAccessor` —
  `contracts/searchable-select-contract.md` — debe fallar antes de implementar
- [X] T010 [P] [US3] Escribir test en
  `pos-heladeria/src/app/shared/searchable-select/searchable-select.component.spec.ts`: con
  `search` provisto, `options` vacío y el campo de texto vacío, el desplegable muestra un mensaje
  de invitación a escribir (no "Sin resultados"); con texto escrito y cero coincidencias remotas,
  sigue mostrando "Sin resultados" como hoy; sin `search` provisto (modo local), el comportamiento
  de `@empty` no cambia para ningún otro consumidor del componente — debe fallar antes de
  implementar
- [X] T011 [P] [US3] Escribir test en
  `pos-heladeria/src/app/modules/products/pages/product-form.component.spec.ts`: al elegir, en el
  selector de Categoría, un resultado de `searchCategories` que no está en `allCategories()`
  (vacío tras US1), el `draft().category_id` **y** `draft().category_name` quedan fijados con los
  datos del resultado elegido, y el selector (ya cerrado) muestra su nombre real de inmediato —
  debe fallar antes de implementar
- [X] T012 [P] [US3] Escribir test en
  `pos-heladeria/src/app/modules/products/pages/product-form.component.spec.ts`: al elegir, en el
  selector de Presentación de una fila, un resultado de `searchPresentations` que no está en
  `allPresentations()`, `presentationId` **y** `presentationName` de esa variante quedan fijados
  con los datos del resultado elegido (sin depender de
  `presentationService.allPresentations().find(...)`, que ya no tendrá datos) — debe fallar antes
  de implementar
- [X] T013 [P] [US3] Escribir test en
  `pos-heladeria/src/app/modules/products/pages/product-form.component.spec.ts` y/o
  `inventory.service.spec.ts`: al elegir, en el selector de Insumo de una fila de receta/consumo,
  un resultado de `searchInventoryItems` que no está en `combinedInventoryItems()`, ese insumo
  queda registrado en `resolvedExtraItems` (directo si el resultado de búsqueda ya trae el
  `InventoryItem` completo, o vía `resolveMissingItems([id])` si solo se tiene `{id,label}`), y el
  nombre/unidad del insumo se muestran de inmediato en la fila — debe fallar antes de implementar

### Implementation for User Story 3

- [X] T014 [US3] En
  `pos-heladeria/src/app/shared/searchable-select/searchable-select.component.ts`, agregar
  `@Output() optionPicked = new EventEmitter<SearchableSelectOption>()` y emitirlo dentro de
  `selectOption()` junto al `onChange(opt.id)` existente, sin tocar `registerOnChange`,
  `writeValue` ni ningún otro miembro del `ControlValueAccessor` —
  `contracts/searchable-select-contract.md` — depende de T009
- [X] T015 [US3] En
  `pos-heladeria/src/app/shared/searchable-select/searchable-select.component.ts`, en la
  plantilla, distinguir dentro del bloque `@empty` de `filteredOptions()`: si `search` está
  provisto y `query()` (sin espacios) está vacío, mostrar un mensaje de invitación a escribir; en
  cualquier otro caso (incluida la ausencia de `search`, modo local), mantener el texto "Sin
  resultados" actual — depende de T010
- [X] T016 [US3] En
  `pos-heladeria/src/app/modules/products/pages/product-form.component.ts`, enlazar
  `(optionPicked)` del selector de Categoría a un nuevo método (p. ej. `onCategoryPicked(opt)`)
  que actualiza `draft().category_id` **y** `draft().category_name` a la vez con los datos de la
  opción elegida — depende de T014, T011
- [X] T017 [US3] En
  `pos-heladeria/src/app/modules/products/pages/product-form.component.ts`, enlazar
  `(optionPicked)` del selector de Presentación de cada fila y modificar `setVariantPresentation`
  para recibir el nombre directamente de la opción elegida en vez de buscarlo con
  `presentationService.allPresentations().find(...)` — depende de T014, T012
- [X] T018 [US3] En
  `pos-heladeria/src/app/modules/products/pages/product-form.component.ts`, enlazar
  `(optionPicked)` del selector de Insumo de cada fila de receta/consumo a un nuevo método que
  registra la opción elegida en `inventoryService.resolvedExtraItems` (directo si el picker tiene
  a mano el `InventoryItem` completo del resultado de búsqueda, o vía
  `inventoryService.resolveMissingItems([opt.id])` en caso contrario) — depende de T014, T013
- [X] T019 [US3] Ejecutar T009-T013, confirmar que pasan; reejecutar toda la suite de
  `pos-heladeria` (comando de T001) y confirmar que sigue en la misma línea base — depende de
  T014, T015, T016, T017, T018

**Checkpoint**: Historia de Usuario 3 funciona de punta a punta — quickstart.md Escenario 4
verificable; elegir cualquier registro por búsqueda, dentro o fuera de un catálogo grande, muestra
su nombre real de inmediato.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [ ] T020 [P] Ejecutar manualmente `quickstart.md` completo (Escenarios 1-7) contra
  `pos-backend`/`pos-heladeria` corriendo en local, con un tenant de prueba con >100 categorías,
  >100 insumos y >100 presentaciones activas. Si el entorno no tiene PostgreSQL local ni navegador
  disponible (misma limitación ya documentada para las specs 098/102), dejarlo explícitamente
  pendiente y apoyarse en la evidencia de los tests automatizados de T002-T003/T007/T009-T013 +
  `npx ng build --configuration=production` como verificación parcial.
  **Pendiente**: este entorno no tiene PostgreSQL local ni navegador disponible (misma limitación
  de las specs 098/102 — ver memoria del proyecto). Verificación parcial aplicada en su lugar: los
  63 tests de `product-form.component.spec.ts` (T002-T003/T007/T011-T013) y los 35 de
  `searchable-select.component.spec.ts` (T009-T010) pasan, y `ng build --configuration=production`
  compila sin errores (T022).
- [X] T021 [P] Confirmar, con `git diff --stat` sobre
  `pos-heladeria/src/app/modules/{categories,presentations,inventory,option-groups,promotions}/`
  y una corrida de sus propias suites de test, que ninguna otra pantalla que reutiliza
  `CategoryService`/`InventoryService`/`PresentationService` (Categorías, Presentaciones,
  Inventario, Compras, Grupos de opciones, Promociones — `research.md`, "Otros consumidores")
  recibió cambios de comportamiento — FR-008, SC-005. Confirmar también, con `grep` de
  `optionPicked` en todo `src/app`, que ningún otro consumidor de `app-searchable-select` además
  de `product-form.component.ts` quedó enlazado a la nueva salida por accidente.
- [X] T022 Ejecutar `npx ng build --configuration=production` en `pos-heladeria` y confirmar que
  compila sin errores nuevos (solo warnings preexistentes no relacionados con este cambio) —
  depende de T006, T008, T019

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias — puede empezar de inmediato.
- **Foundational (Phase 2)**: vacía — no bloquea nada.
- **User Story 1 (Phase 3)**: depende solo de Phase 1.
- **User Story 2 (Phase 4)**: depende de Phase 1; su tarea de verificación (T008) depende además
  de que T004 (US1) esté hecha, porque el comportamiento que confirma solo es observable una vez
  que la precarga ya no está. No depende de User Story 3.
- **User Story 3 (Phase 5)**: depende de Phase 1; toca un archivo distinto a US1/US2
  (`searchable-select.component.ts`) por lo que puede *implementarse* en paralelo con US1/US2, pero
  su validación de punta a punta (T019, quickstart Escenario 4) tiene más sentido una vez que US1
  ya quitó la precarga — antes de eso, el defecto que corrige (research.md, Decisión D1) es
  infrecuente y difícil de reproducir de forma confiable.
- **Polish (Phase 6)**: depende de que las tres historias estén completas.

### Dentro de cada fase

- Los tests (T002-T003, T007, T009-T013) se escriben y deben fallar antes de implementar.
- Dentro de US1: T004 y T005 tocan el mismo archivo (`product-form.component.ts`) — secuenciales,
  no en paralelo entre sí; T006 depende de ambos.
- Dentro de US2: una sola tarea de verificación (T008), depende de su test (T007) y de US1 (T004).
- Dentro de US3: T014 (nuevo `@Output()`) antes que T015 (mismo archivo,
  `searchable-select.component.ts`); T016, T017 y T018 dependen de T014 y tocan el mismo archivo
  entre sí (`product-form.component.ts`) — secuenciales, no en paralelo entre sí, aunque sean
  lógicamente independientes (igual criterio que la spec 102 aplicó a su Historia 3); T019 depende
  de las cinco anteriores.

### Parallel Opportunities

- T002 y T003 (US1, mismo archivo de test, casos independientes) se escriben en paralelo entre sí.
- T009 y T010 (US3, `searchable-select.component.spec.ts`) y T011, T012, T013 (US3,
  `product-form.component.spec.ts`) se escriben en paralelo entre sí (son todas tareas de
  escritura de test, no de implementación).
- User Story 1 y User Story 3 pueden *implementarse* en paralelo por personas distintas desde que
  termina Phase 1 (archivos distintos); User Story 2 conviene dejarla para después de que User
  Story 1 esté mergeada, porque su única tarea es verificar el efecto de esa historia.
- T020 y T021 (Polish, sin dependencia entre sí) en paralelo.

---

## Parallel Example: Entre historias

```bash
# US1 y US3 son independientes a nivel de archivo una vez completada Phase 1:
Task: "Historia 1 — quitar las 3 llamadas de precarga + hasFreePresentations (product-form.component.ts)"
Task: "Historia 3 — optionPicked + mensaje de invitación a buscar (searchable-select.component.ts)"
```

## Parallel Example: Tests de User Story 3

```bash
# Las 5 tareas de test de US3 son archivos (o casos independientes del mismo archivo) distintos:
Task: "optionPicked se emite junto al onChange existente — searchable-select.component.spec.ts"
Task: "mensaje de invitación a buscar vs. Sin resultados — searchable-select.component.spec.ts"
Task: "elegir categoría por búsqueda fija category_name — product-form.component.spec.ts"
Task: "elegir presentación por búsqueda fija presentationName — product-form.component.spec.ts"
Task: "elegir insumo por búsqueda registra resolvedExtraItems — product-form.component.spec.ts"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Completar Phase 1: Setup.
2. Completar Phase 2: Foundational (vacía, sin trabajo).
3. Completar Phase 3: User Story 1 — las tres peticiones de precarga desaparecen.
4. **DETENERSE y VALIDAR**: confirmar con el panel de red que User Story 1 funciona de forma
   independiente (quickstart.md, Escenario 1).
5. Desplegar/demostrar si está listo — ya es la mejora de rendimiento principal reportada.

### Incremental Delivery

1. Setup + Foundational → base lista.
2. User Story 1 → validar independientemente → demo/deploy (MVP: las 3 peticiones desaparecen).
3. User Story 2 → validar independientemente → confirma que ningún valor ya guardado se rompió.
4. User Story 3 → validar independientemente → confirma que buscar y elegir sigue funcionando, y
   corrige el hallazgo de `research.md` (Decisión D1) para cualquier registro elegido fuera de la
   página precargada (que ahora es siempre, no una rareza).
5. Cada historia agrega valor sin romper a la anterior.

### Parallel Team Strategy

Con varios desarrolladores: completar Phase 1 juntos; luego una persona toma User Story 1 (y,
tras mergearla, User Story 2, que depende de validarla) y otra toma User Story 3 en paralelo
(archivo distinto); ambas se integran y validan por separado, con Polish al final.

---

## Notes

- `[P]` = archivo distinto sin dependencias, o escritura de test independiente dentro del mismo
  archivo (ver Format arriba).
- `[US1]`/`[US2]`/`[US3]` mapean la tarea a su historia de usuario.
- Verificar que los tests fallan antes de implementar.
- No commitear salvo pedido explícito del usuario (Principio XV); cuando se commitee, en commits
  pequeños y enfocados (uno por historia es razonable), en inglés, sin ninguna marca de IA. Crear
  la rama `fix/105-selectores-producto-sin-precarga` en `pos-heladeria` antes de tocar código
  (Principio XIV) — no aplica a `pos-backend`, que no se toca en esta spec.

### Adenda post-implementación (fuera del alcance original de tasks.md)

Durante la verificación manual tras completar T001-T022, se encontró que `referencedInventoryItemIds()`
(mecanismo heredado de la spec 102, no tocado por las tareas de arriba) seguía disparando una
ráfaga de peticiones individuales `GET /inventory/items/{id}` al editar un producto -- la precarga
completa de `allItems()` (ahora eliminada por FR-002) absorbía en silencio ese costo antes de esta
spec. Resuelto en dos pasos, con autorización explícita del usuario en cada uno:

1. Se quitó un `effect()` añadido en el momento (no documentado aquí porque se revirtió en el
   mismo turno) que agravaba el problema al re-disparar la resolución en cada cambio del draft.
2. Causa raíz real: `referencedInventoryItemIds()` resolvía por id tanto los insumos de la receta
   como los de cada opción de cada grupo de sabores usado. Se acotó a solo la receta (conjunto
   pequeño, configurado a mano) — el resumen "Descuenta de:" de los grupos de sabores ya no
   resuelve nombre/stock de insumos fuera de `allItems()`/`resolvedExtraItems()` (gap aceptado).
3. Fix definitivo (SÍ toca `pos-backend`, con autorización explícita del usuario): se denormalizó
   `inventory_item_name`/`unit_measure_id` en `RecipeItemResponse` y `OptionResponse`
   (`app/api/v1/catalog/schemas.py`, `app/models/recipe_item.py`, `app/models/option.py` —
   `lazy="joined"` + `@property`, mismo patrón que `category_name`/`presentation_name` de las
   specs 097/103, sin migración de esquema nueva). El frontend (`product.service.ts`,
   `product-form.component.ts`) ya no necesita ninguna resolución por id para una línea de receta
   ya guardada; el resumen de grupos de sabores (paso 2) queda igual, sin resolver, porque esta
   adenda no extendió la denormalización al flujo de guardado/consumo de `GET /option-groups`.
   Rama creada en `pos-backend`: `fix/105-selectores-producto-sin-precarga` (antes en `develop`,
   sin commitear, mismo criterio que Principio XIV).
- Evitar: tareas vagas, conflictos de archivo simultáneos, tocar `pos-backend`, tocar el flujo de
  `ControlValueAccessor` existente de `searchable-select.component.ts` (`writeValue`/
  `registerOnChange`/`registerOnTouched`/`setDisabledState`) al implementar `optionPicked`
  (`contracts/searchable-select-contract.md`), tocar `manual-order-page.component.ts` o cualquier
  otro consumidor de `app-searchable-select` fuera de categoría/presentación/insumo del formulario
  de producto, tocar `category.service.ts`/`inventory.service.ts`/`presentation.service.ts` más
  allá de dejar de invocar sus métodos `loadAllX()` desde `product-form.component.ts`, y cambiar
  la forma en que se guarda el producto (FR-009).
