---

description: "Tareas de la spec 113 — mostrar la presentación elegida en la línea del ítem de la orden manual"
---

# Tasks: Mostrar presentación elegida en la línea del ítem de la orden manual

**Input**: Documentos de diseño de `/specs/113-presentacion-item-pedido-manual/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [quickstart.md](./quickstart.md)

**Tests**: se incluyen tareas de test. `plan.md` (sección Constitution Check, Principio X) y
`research.md` (Decisión 4) exigen cobertura unitaria tanto de la causa raíz (el `computed`
corregido) como de su efecto visible en cada pantalla, no solo validación manual.
`pos-heladeria` usa Vitest vía `npx ng test` sobre los `*.spec.ts` ya existentes.

**Organización**: una única historia de usuario (spec.md: US1, P1, con 5 escenarios de
aceptación), acotada por completo a `../pos-heladeria` (sin cambios en `../pos-backend`, que no
interviene en este defecto — ver plan.md, Summary).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: puede ejecutarse en paralelo (archivo distinto, o mismo archivo pero tests
  independientes entre sí, sin dependencia de una tarea sin terminar)
- **[Story]**: a qué historia de usuario pertenece (US1)
- Cada tarea incluye la ruta exacta del archivo, relativa a `../pos-heladeria` (repositorio
  hermano de este `pos-specs`) salvo que se indique lo contrario

## Convenciones de ruta

- `../pos-heladeria/...` — SPA Angular (TypeScript), único repositorio que cambia en esta spec
- Sin prefijo — archivo dentro de este repo (`pos-specs`)

---

## Phase 1: Setup

**Propósito**: preparar la rama de trabajo y confirmar la línea base antes de tocar código.

- [X] T001 Crear la rama `fix/113-presentacion-item-pedido-manual` desde la rama actual en
  `../pos-heladeria` (confirmar árbol de trabajo limpio antes de crearla; Principio XIV) —
  **resultado**: creada desde `develop` (árbol limpio confirmado antes)
- [X] T002 Buscar en `../pos-heladeria` tests `"CONGELA comportamiento actual:"` que referencien
  `cartView`, `draftLines`, `variantLabel` o `splitVariantLabel`
  (`grep -rn "CONGELA comportamiento actual" --include=*.spec.ts src/app/modules/tables/`); si
  alguno congela explícitamente la ausencia de presentación en líneas de borrador como
  comportamiento protegido, registrar en `research.md` que su actualización queda autorizada por
  esta spec (Principio III) antes de continuar — **resultado**: ningún test con ese prefijo
  referencia esos símbolos; nada que autorizar, vía libre
- [X] T003 [P] Ejecutar `npx ng test --watch=false --include='src/app/modules/tables/**/*.spec.ts'`
  en `../pos-heladeria` y registrar el resultado como línea base de regresión (Principio X),
  comparando contra la baseline ya conocida (fallas preexistentes en `pos-checkout-panel` y
  `pos-order-panel`, documentadas en memoria del proyecto) — **línea base**: 780 passed / 3 failed
  en 2 archivos (`pos-checkout-panel.component.spec.ts` ×1 "T032: Imprimir Pre-cuenta",
  `pos-order-panel.component.spec.ts` ×2 "Marcar pedido listo") — coincide con el conjunto de
  archivos preexistentes documentado en memoria del proyecto

**Checkpoint**: rama creada, línea base de tests registrada — listo para implementar la única
historia de usuario.

---

## Phase 2: Foundational (Blocking Prerequisites)

**No aplica a esta spec.** Al haber una sola historia de usuario (US1), no existe trabajo
fundacional compartido entre historias distintas que deba resolverse por separado — la corrección
de la fuente de datos (`cartView()`) es, en sí misma, parte de la Fase 3.

**Checkpoint**: N/A — continuar directamente a la Fase 3.

---

## Phase 3: User Story 1 - Ver la presentación elegida al agregar un producto a la orden manual (Priority: P1) 🎯 MVP

**Goal**: un cajero o mesero que agrega al carrito un producto con presentación obligatoria ve el
nombre de esa presentación directamente en la línea del ítem — tanto en el carrito de una orden
nueva como al agregar productos a una orden ya creada — sin tener que abrir el editor del ítem, y
sin que productos sin presentaciones configuradas sufran ningún cambio visual.

**Independent Test**: agregar al carrito de una orden manual un producto con presentaciones
(p. ej. un granizado), y verificar que la línea del ítem en el panel "Nueva orden" muestre el
nombre de la presentación seleccionada junto al producto (ver `quickstart.md`, Escenarios 1 a 5).

### Tests for User Story 1 ⚠️

> Escribir estos tests primero y confirmar que fallan contra el código actual antes de
> implementar.

- [X] T004 [P] [US1] Test unitario: `cartView()` incluye el nombre de la variante combinado
  ("Producto · Variante") para una línea de borrador (`draftLines`) cuando el producto tiene más
  de una presentación configurada, en
  `../pos-heladeria/src/app/modules/tables/services/pos-terminal.store.spec.ts`
- [X] T005 [P] [US1] Test unitario de regresión: `cartView()` NO antepone ningún texto de variante
  para una línea de borrador cuyo producto tiene una sola presentación configurada (FR-003) —
  mismo archivo que T004
- [X] T006 [P] [US1] Test unitario: al editar una línea de borrador ya agregada y cambiar su
  presentación (p. ej. de "12 oz" a "16 oz"), `cartView()` refleja el nuevo nombre de variante
  (FR-004 / Acceptance Scenario 2) — mismo archivo que T004
- [X] T007 [P] [US1] Test unitario: dos líneas de borrador del mismo producto agregadas con
  presentaciones distintas ("8 oz" y "12 oz") aparecen en `cartView()` como entradas
  independientes, cada una con su propio nombre de variante (FR-005 / Acceptance Scenario 4) —
  mismo archivo que T004 — **resultado (T004-T007)**: 4 tests nuevos añadidos en un describe
  dedicado `PosTerminalStore.cartView — nombre con presentación de líneas de borrador (spec 113)`;
  confirmados en rojo contra el código original (`name: l.product.name`), luego en verde tras T011
- [X] T008 [P] [US1] Test de componente: la fila de escritorio de `manual-order-page.component`
  renderiza el pill de presentación (vía `splitVariantLabel(it.name)`) junto al nombre del
  producto cuando el ítem tiene variante con más de una presentación, y no renderiza ningún pill
  cuando no aplica, en
  `../pos-heladeria/src/app/modules/tables/pages/manual-order-page.component.spec.ts`
- [X] T009 [P] [US1] Test de componente: igual que T008 pero para la tarjeta de vista móvil del
  mismo componente — mismo archivo que T008 — **resultado (T008-T009)**: 3 tests nuevos (pill en
  fila de escritorio, pill en tarjeta móvil, y el caso FR-003 de una sola presentación → sin
  pill), confirmados en rojo contra el marcado original (T008/T009 fallaban, el de FR-003 ya
  pasaba porque nunca hubo pill) y en verde tras T012/T013 (71/71)
- [X] T010 [P] [US1] Test de componente: `pos-order-panel.component` muestra el pill de
  presentación para un ítem de borrador recién agregado a una orden ya creada (no solo para ítems
  ya persistidos) (FR-007 / Acceptance Scenario 5), en
  `../pos-heladeria/src/app/modules/tables/components/pos-order-panel.component.spec.ts` —
  **resultado**: pasa en verde tras T011 (el pill ya existía en el marcado, solo faltaba la
  fuente de datos); las únicas 2 fallas al correr este archivo son las 2 ya documentadas en la
  línea base (T003, "Marcar pedido listo"), sin ninguna falla nueva

### Implementation for User Story 1

- [X] T011 [US1] Modificar el mapeo de `draftLines()` dentro del `computed` `cartView()` en
  `../pos-heladeria/src/app/modules/tables/services/pos-terminal.store.ts` (bloque ~líneas
  1091-1140) para construir el campo `name` con el mismo helper `variantLabel()` que ya usa
  `persistedItemsView()` (vía `menu-lookup.ts`), en lugar de `l.product.name` — depende de que
  T004-T007 fallen primero — **desviación sobre lo planeado (research.md, Decisión 2)**: NO se usa
  `lk.variantLabel(l.variant.id)`. `lk` sale de `buildMenuLookup(this.menuService.categories())`,
  y en la mayoría de los tests (y potencialmente en producción antes de que el menú termine de
  cargar) ese signal está vacío — `variantLabel()` habría devuelto el fallback genérico
  `'Producto'` en vez del nombre real, reemplazando un nombre de producto que hoy SÍ es correcto
  por uno peor. En su lugar se calcula el mismo formato "Producto · Variante" (mismo umbral `>1`
  que `menu-lookup.ts::indexVariants()`) directamente desde `l.product.variants.length` y
  `l.variant.name`, que el draft ya trae completos sin depender de ningún índice externo —
  confirmado en rojo contra el código original (`git stash` del archivo, 3/4 tests nuevos
  fallaban) y en verde tras el cambio (168/168)
- [X] T012 [US1] Agregar el marcado del pill de presentación a la fila de escritorio de
  `../pos-heladeria/src/app/modules/tables/pages/manual-order-page.component.ts` (bloque ~líneas
  519-531): llamar a `splitVariantLabel(it.name)` y renderizar `parts.variant`, si existe, con las
  mismas clases Tailwind ya usadas en `pos-order-panel.component.ts` (líneas 199-216) — depende de
  T011 — **resultado**: se agregó `@let partsDesktop = splitVariantLabel(it.name);` y el pill
  (`bg-[#f3f4f6] text-[#4b5563] text-[10px] font-semibold px-1.5 py-0.5 rounded-full shrink-0`)
  junto al nombre; también se expuso `splitVariantLabel` como propiedad de la clase (mismo patrón
  que `pos-order-panel.component.ts`) e importó desde `menu-lookup.ts`
- [X] T013 [US1] Agregar el mismo marcado del pill de presentación a la tarjeta de vista móvil de
  `../pos-heladeria/src/app/modules/tables/pages/manual-order-page.component.ts` (bloque ~líneas
  618-628) — depende de T011 — **resultado**: mismo patrón con `@let partsMobile = ...`, bloque de
  tarjeta apilada
- [X] T014 [US1] Verificar que `../pos-heladeria/src/app/modules/tables/components/pos-order-panel.component.ts`
  (líneas 199-216) no requiere ningún cambio de marcado — el pill ya existente pasa a mostrarse
  correctamente para ítems de borrador una vez que T011 corrige la fuente de datos; tarea de
  verificación, sin cambio de código esperado — **confirmado**: `git diff` sobre ese archivo está
  vacío; T010 pasa sin tocarlo
- [ ] T015 [US1] Ejecutar manualmente los 5 escenarios de [quickstart.md](./quickstart.md) en un
  entorno de desarrollo (`npx ng serve` + backend corriendo) y registrar el resultado de cada uno
  — **pendiente**: hay un frontend (`:4200`) y un backend (`:8000`) corriendo en este entorno,
  pero esta sesión no tiene credenciales de un tenant ni acceso a un producto con presentaciones
  ya seeded para iniciar sesión como cajero/mesero y navegar la Terminal de Mesas; los 5
  escenarios ya quedan cubiertos a nivel de lógica/render por T004-T010 (rojo→verde confirmado), y
  la validación visual en navegador queda pendiente de que el usuario la confirme antes de mergear
  (mismo patrón que spec 110)

**Checkpoint**: la historia de usuario 1 está completamente funcional y probada de forma
independiente — la presentación elegida es visible en la línea del ítem tanto en el carrito de
una orden nueva como al agregar productos a una orden ya creada, sin afectar productos sin
presentaciones.

---

## Phase 4: Polish & Cross-Cutting Concerns

**Propósito**: cerrar la verificación global antes de dar la spec por completada.

- [X] T016 Ejecutar la suite completa de `npx ng test --watch=false` en `../pos-heladeria` y
  confirmar que no se rompió ningún test ni characterization test existente fuera del alcance de
  esta spec (Principio X) — comparar el conjunto de archivos con fallas contra la baseline
  preexistente documentada en memoria del proyecto (6 archivos, desde spec 084), no contra el
  conteo total — **resultado**: mismo conjunto exacto de 6 archivos (`app.spec`, `auth.service`,
  `menu.service`, `tenant.service`, `pos-checkout-panel`, `pos-order-panel`); 65 fallas/1596
  passed en este run puntual, un conteo distinto al "19" de la memoria del proyecto, pero
  consistente con lo ya documentado ahí mismo: cruces de estado de TestBed/DI entre archivos
  hacen variar el conteo exacto entre corridas completas, mientras el conjunto de 6 archivos se
  mantiene estable — ningún archivo nuevo fuera de ese conjunto, y los 2 del módulo `tables/`
  (`pos-checkout-panel`, `pos-order-panel`) muestran exactamente las mismas fallas puntuales ya
  descritas en T003/T010
- [X] T017 [P] Releer el Constitution Check de [plan.md](./plan.md) tras implementar y confirmar
  que ninguna entrada nueva en `specs/000-reconocimiento/registro-de-anomalias.md` resultó
  necesaria — este cambio corrige un defecto de visualización, no redefine ninguna regla de
  negocio de precio, inventario o facturación — **confirmado**: sin cambios de precio/cálculo,
  sin nuevas dependencias, alcance acotado a 3 archivos de producción
  (`pos-terminal.store.ts`, `manual-order-page.component.ts`) + 3 archivos de test; nada que
  registrar

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias — puede iniciar de inmediato
- **Foundational (Phase 2)**: N/A, no bloquea nada
- **User Story 1 (Phase 3)**: depende de Setup (T001-T003) completo
- **Polish (Phase 4)**: depende de que la Fase 3 esté completa

### Within User Story 1

- Tests (T004-T010) se escriben primero y deben fallar contra el código actual
- T011 (fix de `cartView()` en el store) bloquea T012 y T013 (ambas dependen de que las líneas de
  borrador ya traigan el nombre combinado "Producto · Variante")
- T011 también es prerrequisito de T014 (verificación de que `pos-order-panel.component.ts` ya
  funciona sin cambios)
- T015 (validación manual) va al final, después de que T011-T014 estén implementadas

### Parallel Opportunities

- T004, T005, T006, T007 pueden escribirse en paralelo (mismo archivo, pero son tests
  independientes entre sí)
- T008 y T009 pueden escribirse en paralelo con T010 (archivos distintos)
- T003 puede ejecutarse en paralelo con T002 (ambas de solo lectura/verificación)
- T012 y T013 pueden implementarse en paralelo entre sí una vez completado T011 (bloques de
  plantilla distintos — escritorio vs. móvil — dentro del mismo archivo, sin dependencia mutua)
- T017 puede revisarse en paralelo con la ejecución de T016

---

## Parallel Example: User Story 1

```bash
# Lanzar los tests de la historia de usuario 1 juntos:
Task: "Test: cartView() incluye variante en línea de borrador con >1 presentación (T004)"
Task: "Test de regresión: cartView() omite variante cuando el producto tiene 1 presentación (T005)"
Task: "Test: editar presentación de una línea de borrador actualiza cartView() (T006)"
Task: "Test: mismo producto con presentaciones distintas = líneas independientes (T007)"
Task: "Test de componente: pill de presentación en fila de escritorio de manual-order-page (T008)"
Task: "Test de componente: pill de presentación en tarjeta móvil de manual-order-page (T009)"
Task: "Test de componente: pill de presentación para ítem de borrador en pos-order-panel (T010)"
```

---

## Implementation Strategy

### MVP (única historia de usuario)

1. Completar Fase 1: Setup (rama + línea base)
2. Fase 2: N/A, pasar directo a Fase 3
3. Completar Fase 3: User Story 1 (tests → fix de `cartView()` → pills en `manual-order-page` →
   verificación de `pos-order-panel` → validación manual)
4. **DETENER y VALIDAR**: confirmar los 5 escenarios de `quickstart.md`
5. Completar Fase 4: Polish (regresión completa + cierre de gobernanza)

### Notas

- `[P]` = archivos distintos, o mismo archivo con tests/bloques independientes entre sí, sin
  dependencia de una tarea sin terminar
- `[US1]` identifica cada tarea con la única historia de usuario de esta spec
- Confirmar que los tests fallan antes de implementar (T004-T010 antes de T011-T014)
- Los commits solo se ejecutan si el usuario lo pide explícitamente, en unidades pequeñas y
  lógicas, en inglés, sin marcas de autoría de IA (Principio XV)
