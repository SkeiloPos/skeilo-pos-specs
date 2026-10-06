---

description: "Task list for feature implementation"
---

# Tasks: Corrección — los selectores de insumo (receta, opciones, compras, movimientos de inventario) no encuentran insumos existentes fuera de los primeros 100

**Input**: Design documents from `/specs/098-selector-insumos-receta/`
**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: incluidos — el plan y los contratos ya comprometen ficheros de test concretos
(Principio X, Verificación Obligatoria).

**Organización**: dos historias de usuario (US1 P1, US2 P2), ambas **100% frontend**
(`pos-heladeria`) — `pos-backend` no se toca. El modo de búsqueda remota del componente
compartido `app-searchable-select` y el método nuevo `InventoryService.searchActiveItems()` son
la base de la que dependen las dos historias — viven en Foundational. US1 cubre el selector de
"Insumos fijos" de la receta (el bug reportado). US2 cubre los otros tres selectores que
comparten exactamente la misma causa raíz (Opciones, Compras, Movimientos).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: se puede hacer en paralelo (archivo distinto, sin dependencia de una tarea sin terminar)
- **[Story]**: US1, US2

---

## Phase 1: Setup

- [X] T001 Confirmar línea base en `pos-heladeria`: `cd ../pos-heladeria && npx ng test --watch=false` reproduce el mismo conjunto de fallos preexistentes ya documentado (19 pruebas en 6 archivos no relacionados: `app.spec`, `auth.service`, `menu.service`, `tenant.service`, `pos-checkout-panel`, `pos-order-panel`) — comparar por archivo, no por conteo literal. No hace falta confirmar línea base de `pos-backend`: esta spec no toca ese repo (plan.md, Technical Context). Confirmado 2026-10-06: 10 fallos en los mismos 6 archivos (el conteo exacto varía por corrida, documentado en memoria del proyecto; el conjunto de archivos es idéntico)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: agregar el modo de búsqueda remota opt-in al componente compartido
`app-searchable-select` y el método `InventoryService.searchActiveItems()` que lo alimenta — es
la base de la que dependen US1 y US2 (research.md D1-D3, `contracts/searchable-select-component.
md`, `contracts/inventory-items-search.md`).

**⚠️ CRITICAL**: ninguna de las dos historias puede verificarse de verdad sin esto.

- [X] T002 [P] Escribir test en `pos-heladeria/src/app/modules/inventory/services/inventory.service.spec.ts`: `searchActiveItems('mozar')` dispara `GET /inventory/items?search=mozar&active=true&page=1&size=20` (vía `HttpTestingController`, sin necesitar los ticks extra de `injectPagedQuery`/TanStack Query porque este método no usa `injectQuery` — ver research.md D1) y devuelve el `items[]` de la respuesta mapeado con el mismo `toItem()` ya existente — debe fallar antes de implementar
- [X] T003 [P] Escribir tests en `pos-heladeria/src/app/shared/searchable-select/searchable-select.component.spec.ts` para el modo remoto (research.md D2/D3, `contracts/searchable-select-component.md`): (a) sin `[search]` provisto, comportamiento idéntico al actual (filtrado local sobre `options`); (b) con `[search]` provisto y texto no vacío, tras 300ms sin teclear se invoca `search(query)` y `filteredOptions()` devuelve su resultado en vez de filtrar `options`; (c) mientras la promesa está pendiente, no se muestra "Sin resultados"; (d) si la promesa rechaza, se muestra un mensaje de error distinto de "Sin resultados" con un control de reintentar que vuelve a invocar `search` con el mismo texto; (e) si llega una respuesta de una búsqueda ya superada por una más reciente, se descarta (guarda por secuencia); (f) al borrar el texto, vuelve a mostrarse `options` tal cual — deben fallar antes de implementar
- [X] T004 Implementar `searchActiveItems(query: string): Promise<InventoryItem[]>` en `pos-heladeria/src/app/modules/inventory/services/inventory.service.ts`: llama a la función privada ya existente `fetchItemsPage(1, 20, query.trim(), '', 'active', false)` (línea ~157-165) y mapea con `toItem()` (línea ~397) — depende de T002
- [X] T005 Implementar el modo remoto en `pos-heladeria/src/app/shared/searchable-select/searchable-select.component.ts`: agregar `@Input() search?: (query: string) => Promise<SearchableSelectOption[]>`; signals internos `remoteResults`, `loading`, `error` y un contador `searchSeq` para la guarda por secuencia; debounce de 300ms en `onQueryInput()` cuando `search` está presente (cancela el timer anterior); `filteredOptions()` devuelve `remoteResults()` cuando hay texto y `search` está presente, `options` sin filtrar cuando el texto está vacío, y el filtrado local existente en cualquier otro caso; plantilla: renglón de carga mientras `loading()`, mensaje de error con control de reintentar cuando `error()` — depende de T003
- [X] T006 Ejecutar T002 y T003, confirmar que ahora pasan; reejecutar toda la suite de `pos-heladeria` (comando de T001) y confirmar que sigue en la misma línea base (sin regresiones, en particular en el selector de mesa de `manual-order-page.component.ts`, que no pasa `[search]` y debe seguir comportándose igual — spec FR-007) — depende de T004, T005. Confirmado: 23/23 tests nuevos en verde; suite completa en la misma línea base (10 fallos, mismos 6 archivos preexistentes; 1486→1497 total por los 11 tests nuevos)

**Checkpoint**: el componente compartido y el método del servicio están listos y probados en
aislamiento; US1 y US2 solo necesitan conectarlos a cada picker.

---

## Phase 3: User Story 1 - Encontrar y agregar cualquier insumo activo existente a la receta de un producto (Priority: P1) 🎯 MVP

**Goal**: el selector de "Insumos fijos" de la receta de producto usa búsqueda remota: cualquier
insumo activo es encontrable sin importar cuántos insumos tenga el tenant.

**Independent Test**: en un tenant con más de 100 insumos activos, abrir la edición de un
producto con "Maneja inventario" activo, ir a "Insumos fijos", buscar un insumo que exista fuera
de los primeros 100 y verificar que aparece y puede agregarse (quickstart.md, Escenario 1).

### Tests for User Story 1

- [X] T007 [P] [US1] Escribir/actualizar test en `pos-heladeria/src/app/modules/products/pages/product-form.component.spec.ts`: con un insumo que NO esté en el `options` inicial (simula estar fuera de los primeros 100), escribir su nombre en el selector de "Insumos fijos" dispara `inventoryService.searchActiveItems` y el insumo aparece como opción seleccionable; además, un insumo inactivo buscado no aparece (FR-003) — debe fallar antes de implementar

### Implementation for User Story 1

- [X] T008 [US1] En `pos-heladeria/src/app/modules/products/pages/product-form.component.ts`, agregar un método `searchInventoryItems = (query: string) => this.inventoryService.searchActiveItems(query).then(items => items.map(i => ({ id: i.id, label: i.name })))` (mismo mapeo que ya usa `inventoryOptions`, línea ~548-549) — depende de T007
- [X] T009 [US1] En la plantilla de `product-form.component.ts`, agregar `[search]="searchInventoryItems"` al `<app-searchable-select>` del selector de "Insumos fijos" (línea 319-321), sin tocar `[options]="inventoryOptions()"` (sigue alimentando la lista por defecto y `selectedLabel()`, research.md D2/D5) — depende de T008
- [X] T010 [US1] Ejecutar T007, confirmar que ahora pasa; reejecutar toda la suite de `pos-heladeria` y confirmar que sigue en la misma línea base — depende de T009. Confirmado: 42/42 en `product-form.component.spec.ts`; suite completa en línea base (10 fallos, mismos 6 archivos; 1486→1487)

**Checkpoint**: Historia de Usuario 1 funciona de punta a punta — quickstart.md Escenario 1
verificable; el bug reportado queda corregido.

---

## Phase 4: User Story 2 - Encontrar cualquier insumo activo desde los demás selectores que comparten el mismo defecto (Priority: P2)

**Goal**: los selectores de insumo de Opciones, Compras y Movimientos de Inventario usan la misma
búsqueda remota que US1, con el mismo comportamiento.

**Independent Test**: en un tenant con más de 100 insumos activos, para cada uno de los tres
puntos, buscar un insumo que exista fuera de los primeros 100 y verificar que aparece y puede
seleccionarse (quickstart.md, Escenario 2).

### Tests for User Story 2

- [X] T011 [P] [US2] Escribir/actualizar test en `pos-heladeria/src/app/modules/option-groups/components/option-form.component.spec.ts`: igual que T007, aplicado al selector de insumo de una opción (línea 63-64) — debe fallar antes de implementar
- [X] T012 [P] [US2] Escribir/actualizar test en `pos-heladeria/src/app/modules/inventory/components/purchase-form.component.spec.ts`: igual que T007, aplicado al selector de insumo de una línea de Compra (línea 78-80) — debe fallar antes de implementar
- [X] T013 [P] [US2] Escribir/actualizar test en `pos-heladeria/src/app/modules/inventory/pages/inventory-page.component.spec.ts`: igual que T007, aplicado al selector de insumo del tab "Movimientos" (línea 288-289) — debe fallar antes de implementar

### Implementation for User Story 2

- [X] T014 [P] [US2] En `pos-heladeria/src/app/modules/option-groups/components/option-form.component.ts`: agregar el mismo método `searchInventoryItems` que T008 y `[search]="searchInventoryItems"` en el `<app-searchable-select>` de línea 63-64, sin tocar `[options]="inventoryOptions()"` — depende de T011
- [X] T015 [P] [US2] En `pos-heladeria/src/app/modules/inventory/components/purchase-form.component.ts`: agregar el mismo método `searchInventoryItems` y `[search]="searchInventoryItems"` en el `<app-searchable-select>` de línea 78-80, sin tocar `[options]="itemOptions()"` — depende de T012. Nota: la etiqueta del resultado remoto replica el mismo formato `"{name} · {unidad}"` que ya usa `itemOptions()`
- [X] T016 [P] [US2] En `pos-heladeria/src/app/modules/inventory/pages/inventory-page.component.ts`: agregar el mismo método `searchInventoryItems` y `[search]="searchInventoryItems"` en el `<app-searchable-select>` de línea 288-289, sin tocar `[options]="movementItemOptions()"` — depende de T013
- [X] T017 [US2] Ejecutar T011, T012 y T013, confirmar que ahora pasan; reejecutar toda la suite de `pos-heladeria` y confirmar que sigue en la misma línea base — depende de T014, T015, T016. Confirmado: 19/19 en los tres archivos; suite completa en línea base (10 fallos, mismos 6 archivos; 1487→1490)

**Checkpoint**: Historias de Usuario 1 y 2 funcionan de punta a punta — quickstart.md Escenarios
1-3 verificables; los cuatro selectores de insumo comparten el mismo comportamiento (FR-001/FR-002).

---

## Phase 5: Polish & Cross-Cutting Concerns

- [X] T018 Ejecutar manualmente (o con un script de siembra) `quickstart.md` completo contra `pos-backend`/`pos-heladeria` corriendo en local: Escenario 4 (error de red/servidor distinto de "Sin resultados", con reintentar, en al menos uno de los 4 selectores), Escenario 5 (tenant con ≤100 insumos activos, sin cambio de comportamiento visible) y Escenario 6 (API directa, `GET /inventory/items?search=&active=true&page=1&size=20` trae el insumo sin importar su posición). **Verificación parcial**: este entorno no tiene PostgreSQL local corriendo ni navegador disponible (misma limitación que el Polish de la spec 097), así que no se levantó `pos-backend`/`pos-heladeria` en vivo. En su lugar: (a) Escenario 4 (error/reintentar) y el contrato exacto del Escenario 6 (`search`/`active=true`/`page=1`/`size=20`, insumo encontrado sin importar su posición) ya quedan demostrados por los tests automatizados de T002-T003/T007/T011-T013 con `HttpTestingController`, que simulan la petición y la respuesta HTTP real byte a byte contra el contrato de `contracts/inventory-items-search.md`; (b) Escenario 5 se verifica por diseño, no en vivo: `filteredOptions()` con texto vacío sigue devolviendo `options` sin cambios (research.md D2, test "al borrar el texto... vuelve a mostrar `options`"), y ningún consumidor cambió su `[options]="allItems()"` por defecto — un tenant con ≤100 insumos ve exactamente el mismo comportamiento que antes de este fix; (c) se corrió `npx ng build --configuration=production` con éxito (sin errores; solo warnings preexistentes de budget y de `qrcode` CommonJS, no relacionados con este cambio), confirmando que los 4 puntos tocados compilan e integran correctamente en el bundle completo. Queda pendiente, si se desea cerrar el Escenario 4/6 en vivo, levantar un Postgres desechable (ver memoria del proyecto) y los servidores de desarrollo
- [X] T019 Confirmar que el selector de mesa (`pos-heladeria/src/app/modules/tables/pages/manual-order-page.component.ts`), el único otro consumidor de `app-searchable-select` fuera de los cuatro tocados, no recibió ningún cambio y su suite (`manual-order-page.component.spec.ts`) sigue en verde sin modificaciones (FR-007). Confirmado: `git diff --stat` sobre ese archivo no muestra cambios; su suite pasa 65/65

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias.
- **Foundational (Phase 2)**: depende de Setup — BLOQUEA User Story 1 y User Story 2 (ninguna
  historia tiene nada que conectar sin el modo remoto del componente y `searchActiveItems()`).
- **User Story 1 (Phase 3)**: depende de Foundational completo (T002-T006). No depende de US2.
- **User Story 2 (Phase 4)**: depende de Foundational completo (T002-T006). No depende de US1 —
  puede implementarse en paralelo o después, indistintamente.
- **Polish (Phase 5)**: depende de que al menos US1 esté completa; T018/T019 cubren ambas
  historias si US2 también está completa.

### Dentro de cada fase

- Tests (T002, T003, T007, T011-T013) se escriben y deben fallar antes de implementar.
- `searchActiveItems()` (T004) y el modo remoto del componente (T005) son independientes entre sí
  (archivos distintos) pero ambos deben estar listos antes de T006 y antes de cualquier tarea de
  US1/US2 que los conecte.
- Dentro de cada historia: método `searchInventoryItems` del archivo antes del binding
  `[search]` en su plantilla (mismo archivo, mismo commit lógico).

### Parallel Opportunities

- T002 y T003 (Foundational, archivos distintos) en paralelo.
- T007, T011, T012, T013 (tests de US1/US2, archivos distintos) en paralelo entre sí una vez
  completada Foundational.
- T014, T015, T016 (implementación de US2, archivos distintos) en paralelo entre sí.
- US1 (Phase 3) y US2 (Phase 4) pueden trabajarse en paralelo por personas distintas una vez
  completada Foundational, al no depender una de la otra.

---

## Parallel Example: Foundational

```bash
# T002 y T003 son archivos distintos sin dependencia entre sí:
Task: "Test de searchActiveItems() en inventory.service.spec.ts"
Task: "Tests del modo remoto en searchable-select.component.spec.ts"
```

## Parallel Example: User Story 2

```bash
# Los tres selectores son archivos distintos, mismo cambio en cada uno:
Task: "Wiring de [search] en option-form.component.ts"
Task: "Wiring de [search] en purchase-form.component.ts"
Task: "Wiring de [search] en inventory-page.component.ts"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Completar Phase 1: Setup.
2. Completar Phase 2: Foundational (CRÍTICO — bloquea ambas historias).
3. Completar Phase 3: User Story 1.
4. **DETENER y VALIDAR**: correr quickstart.md Escenario 1 (y 5, 6 para esa historia).
5. El bug reportado (`MOZARELA` en la receta) queda corregido; US2 puede entregarse después sin
   romper lo ya entregado.

### Incremental Delivery

1. Setup + Foundational → base lista.
2. US1 → validar independientemente → el bug reportado queda resuelto (MVP).
3. US2 → validar independientemente → Opciones/Compras/Movimientos quedan alineados con el mismo
   comportamiento, sin reabrir US1.
4. Phase 5 (Polish) → validación manual completa de `quickstart.md` + confirmación de que el
   selector de mesa no cambió.

## Notes

- [P] = archivos distintos, sin dependencias entre sí.
- [US1]/[US2] mapean la tarea a su historia de usuario.
- Verificar que los tests fallan antes de implementar.
- No commitear salvo pedido explícito del usuario (Principio XV); cuando se commitee, en commits
  pequeños y enfocados, en inglés, sin ninguna marca de IA. Crear la rama
  `fix/098-inventory-item-picker-search` (o equivalente) en `pos-heladeria` antes de tocar código
  (Principio XIV) — no aplica a `pos-backend`, que no se toca en esta spec.
- Evitar: tareas vagas, conflictos de archivo simultáneos, tocar `pos-backend`, tocar
  `allItems()`/`loadAllItems()` o la resolución de nombre/unidad de filas ya guardadas (fuera de
  alcance, spec.md FR-009), tocar el selector de mesa de `manual-order-page.component.ts`.
