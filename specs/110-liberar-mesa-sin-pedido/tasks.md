---

description: "Tareas de la spec 110 — corrección: mesa ocupada sin pedido no se puede liberar"
---

# Tasks: Corrección — Mesa ocupada sin pedido no se puede liberar

**Input**: Documentos de diseño de `/specs/110-liberar-mesa-sin-pedido/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [quickstart.md](./quickstart.md)

**Tests**: se incluyen tareas de test. `plan.md` (sección Testing) y `research.md` (Decisión 3)
ya exigen cobertura unitaria del computed corregido, no solo validación manual — consistente con
el Principio X (Verificación Obligatoria) de la constitución. `pos-heladeria` usa `ng test`
(Jasmine/Karma vía Angular CLI) sobre los `*.spec.ts` ya existentes.

**Organización**: una única historia de usuario (spec.md: US1, P1), acotada por completo a
`../pos-heladeria` (sin cambios en `../pos-backend`, que ya soporta el caso — ver plan.md,
Summary).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: puede ejecutarse en paralelo (archivo distinto, sin dependencia de una tarea sin
  terminar)
- **[Story]**: a qué historia de usuario pertenece (US1)
- Cada tarea incluye la ruta exacta del archivo, relativa a `../pos-heladeria` (repositorio
  hermano de este `pos-specs`) salvo que se indique lo contrario

## Convenciones de ruta

- `../pos-heladeria/...` — SPA Angular (TypeScript), único repositorio que cambia en esta spec
- Sin prefijo — archivo dentro de este repo (`pos-specs`)

---

## Phase 1: Setup

**Propósito**: preparar la rama de trabajo y confirmar la línea base antes de tocar código.

- [X] T001 Crear la rama `fix/110-liberar-mesa-sin-pedido` desde la rama actual en `../pos-heladeria` (confirmar árbol de trabajo limpio antes de crearla; Principio XIV) — **corrección sobre lo planeado**: `../pos-heladeria` estaba en `main`, pero el flujo real del equipo trabaja sobre `develop` (memoria del proyecto); la rama se creó desde `develop` (`19d1064`), no desde `main`
- [X] T002 Buscar en `../pos-heladeria` tests `"CONGELA comportamiento actual:"` que referencien `centralState`, `showingDetail` o `'mesa-libre'` (`grep -rn "CONGELA comportamiento actual" --include=*.spec.ts src/app/modules/tables/`); si alguno congela exactamente el colapso de "mesa ocupada sin pedido" a `'mesa-libre'`, registrar en `research.md` que su actualización queda autorizada por esta spec (Principio III) antes de continuar — **resultado**: ningún test de `src/app/modules/tables/` usa ese prefijo sobre `centralState`/`showingDetail`/`'mesa-libre'`; nada que autorizar, vía libre
- [X] T003 [P] Ejecutar `ng test` en `../pos-heladeria` sobre los archivos de `src/app/modules/tables/` y registrar el resultado como línea base de regresión (Principio X) — **línea base**: 736 passed / 3 failed en 2 archivos (`pos-checkout-panel.component.spec.ts` T032, `pos-order-panel.component.spec.ts` ×2 "Marcar pedido listo") — coincide con la línea base ya documentada en la memoria del proyecto (pre-existente desde spec 084)

**Checkpoint**: rama creada, línea base de tests registrada — listo para implementar la única historia de usuario.

---

## Phase 2: Foundational (Blocking Prerequisites)

**No aplica a esta spec.** Al haber una sola historia de usuario (US1), no existe trabajo
fundacional compartido entre historias distintas que deba resolverse por separado — todo el
trabajo pertenece a la Fase 3.

**Checkpoint**: N/A — continuar directamente a la Fase 3.

---

## Phase 3: User Story 1 - Liberar una mesa ocupada sin ningún pedido (Priority: P1) 🎯 MVP

**Goal**: al hacer click sobre una mesa en estado `'ocupada'` sin pedidos vivos, el cajero/admin ve
el panel de detalle con "Liberar Mesa" como única acción disponible, y al presionarlo la mesa
queda libre — sin alterar el comportamiento de mesas realmente libres ni de mesas con pedidos
activos.

**Independent Test**: abrir una sesión sobre una mesa, crear un pedido manual y rechazarlo/
cancelarlo antes de que cocina reciba nada (la mesa queda `'ocupada'` con cero pedidos vivos),
hacer click sobre la mesa, verificar que aparece "Liberar Mesa", presionarlo y confirmar que la
mesa vuelve a `'libre'` en la grilla sin ningún error.

### Tests for User Story 1 ⚠️

> Escribir estos tests primero y confirmar que fallan contra el código actual antes de implementar.

- [X] T004 [P] [US1] Test unitario: `centralState` NO colapsa a `'mesa-libre'` cuando la mesa seleccionada tiene `table.status === 'ocupada'` y `tableOrders(tableId).length === 0` (sin draft) en `../pos-heladeria/src/app/modules/tables/services/pos-terminal.store.spec.ts`
- [X] T005 [P] [US1] Test unitario: `centralState` SIGUE devolviendo `'mesa-libre'` cuando la mesa está genuinamente libre (`table.status === 'libre'`, sin sesión, cero pedidos, sin draft) — regresión, mismo archivo que T004
- [X] T006 [P] [US1] Test unitario de regresión: `centralState` SIGUE devolviendo `'pedido'` para una mesa `'ocupada'` con un pedido activo, y también cuando el único pedido de esa mesa está `'cancelada'` (cero pedidos vivos) sigue cayendo en `'ocupada-sin-pedido'`, no en `'pedido'` — mismo archivo que T004. **Ajuste sobre lo planeado**: el escenario textual de la spec [050](../050-correccion-liberar-mesa-pedido-cancelado/spec.md) (ítems sin terminar en cocina) es un bloqueo de `release_paid_session`/`_assert_closable` en el **backend**, no algo que `centralState()` evalúe — no aplica como test de este computed; se cubre en su lugar con el caso de pedido cancelado arriba, que sí es relevante para este archivo
- [X] T007 [P] [US1] Test de componente: `app-pos-checkout-panel` renderiza el botón "Liberar Mesa" cuando el estado central es "ocupada-sin-pedido", y NO renderiza la tarjeta "Pedido de mostrador"/"+ Crear pedido nuevo" en ese caso (duplicaría el CTA de la sub-barra), en `../pos-heladeria/src/app/modules/tables/components/pos-checkout-panel.component.spec.ts`. **Ajuste sobre lo planeado**: `store.sessionBill()` SÍ se puebla normalmente en este caso (la sesión de mesa existe aunque tenga cero pedidos; `compute_bill` en el backend devuelve `total=0, split=[]` sin error) — el guard `@if (store.sessionBill(); as bill)` nunca fue el problema real; el test verifica en cambio la exclusión nueva de la tarjeta "Pedido de mostrador"

### Implementation for User Story 1

- [X] T008 [US1] Modificar `centralState` en `../pos-heladeria/src/app/modules/tables/services/pos-terminal.store.ts:628-637` para distinguir, cuando `tableOrders(tableId).length === 0 && !hasDraft()`, entre mesa genuinamente libre y mesa `status === 'ocupada'` sin pedidos, reutilizando el mismo criterio que ya aplica `deriveTableStatus` (líneas 254-258) — devuelve `'ocupada-sin-pedido'` para el segundo caso, dejando `'mesa-libre'` únicamente para el primero
- [X] T009 [US1] Actualizar la firma de tipos de `centralState` y de `effectiveCentralView` (`pos-terminal.store.ts:628`, `:678-680`) para incluir el nuevo valor en su unión de literales
- [X] T010 [US1] Verificar `showingDetail()` en `../pos-heladeria/src/app/modules/tables/pages/table-sessions.component.ts:388-390` (ruta corregida: vive en `pages/`, no en `components/` como decía el plan) — **sin cambio de código**: su guardia ya es `effectiveCentralView() !== 'mesa-libre'`, así que el nuevo valor `'ocupada-sin-pedido'` ya pasa automáticamente sin tocar el caso `'mesa-libre'` real
- [X] T011 [US1] Revisar qué renderiza `table-sessions.component.ts` cuando `showingDetail()` es verdadero — **sin cambio de código**: `<app-pos-order-panel />` y `<app-pos-checkout-panel />` (líneas 259/265) se renderizan siempre juntos ahí, sin `@switch` por estado; no hace falta enrutar un "modo solo liberar" a nivel de página, el filtrado ocurre dentro de cada componente hijo (ver T011b/T012 reales abajo)
- [X] T011b [US1] (tarea no planeada, necesaria tras leer el código real) Ocultar el botón "+ Agregar producto" en `../pos-heladeria/src/app/modules/tables/components/pos-order-panel.component.ts` (`@if (!readOnly())`, línea 337) cuando `store.centralState() === 'ocupada-sin-pedido'` — sin este cambio, el panel de carrito seguía ofreciendo una acción para empezar un borrador, violando FR-002 ("Liberar Mesa" como única acción)
- [X] T012 [US1] (alcance corregido) Excluir el caso `'ocupada-sin-pedido'` de la tarjeta "Pedido de mostrador"/"+ Crear pedido nuevo" en `../pos-heladeria/src/app/modules/tables/components/pos-checkout-panel.component.ts` (condición `@else if`, línea 208) — **hallazgo clave**: el guard `@if (store.sessionBill(); as bill)` (línea 358) NUNCA fue el bloqueo real: `loadSessionBill()` encuentra la sesión de mesa (existe aunque tenga cero pedidos, `open_session`/`_get_or_create_table_session` en el backend siempre la crea) y `compute_bill` devuelve `total=0, split=[]` sin error — "Liberar Mesa" (líneas 401-408) ya se mostraba una vez visible la columna de detalle. El problema real era que la tarjeta "Pedido de mostrador" (pensada para "mesa libre sin pedido todavía") también entraba a tallar y duplicaba el CTA "+ Crear pedido nuevo" que ya ofrece la sub-barra de la página para esta misma mesa (`newOrderTableId()`) — se excluyó explícitamente
- [X] T013 [US1] Verificar `releaseTable()` (`pos-terminal.store.ts:2414-2428`) con sesión sin pedidos — **confirmado sin cambios**: usa `bill.table_session_id` (presente incluso con cuenta en cero) y llama al mismo endpoint ya verificado por el backend; no asume ningún pedido
- [ ] T014 [US1] Ejecutar manualmente los Escenarios 1 a 5 de [quickstart.md](./quickstart.md) en un entorno de desarrollo y registrar el resultado de cada uno — **pendiente**: este entorno de implementación no tiene navegador/servidor interactivo disponible; se corrió en su lugar `ng build` completo (compila sin errores nuevos) más la suite completa de `ng test` (ver T015) como equivalente automatizado — la validación manual en navegador de los 5 escenarios queda pendiente de que el usuario la confirme antes de mergear

**Checkpoint**: la historia de usuario 1 está completamente funcional y probada de forma independiente — mesas ocupadas sin pedido pueden liberarse desde la interfaz, sin afectar mesas libres ni mesas con pedidos activos.

---

## Phase 4: Polish & Cross-Cutting Concerns

**Propósito**: cerrar la verificación global antes de dar la spec por completada.

- [X] T015 Ejecutar la suite completa de `ng test` en `../pos-heladeria` y confirmar que no se rompió ningún test ni characterization test existente fuera del alcance de esta spec (Principio X) — **resultado**: 1607 passed / 10 failed en los mismos 6 archivos ya documentados como línea base preexistente en la memoria del proyecto (`app.spec`, `auth.service`, `menu.service`, `tenant.service`, `pos-checkout-panel`, `pos-order-panel`, desde spec 084) — mismo conjunto de archivos, ninguna regresión nueva fuera de ese conjunto; dentro de `tables/`, los 8 tests nuevos de esta spec (T004-T007) pasan y las 3 fallas preexistentes de línea base (T003) siguen siendo exactamente las mismas
- [X] T016 [P] Releer el Constitution Check de [plan.md](./plan.md) tras implementar y confirmar que ninguna entrada nueva en `specs/000-reconocimiento/registro-de-anomalias.md` resultó necesaria — confirmado: el cambio corrige un bug de interfaz (qué se renderiza), no redefine ninguna regla de negocio de precio/inventario/facturación; T002 no encontró ningún characterization test afectado, así que no hay actualización que citar

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias — puede iniciar de inmediato
- **Foundational (Phase 2)**: N/A, no bloquea nada
- **User Story 1 (Phase 3)**: depende de Setup (T001-T003) completo
- **Polish (Phase 4)**: depende de que la Fase 3 esté completa

### Within User Story 1

- Tests (T004-T007) se escriben primero y deben fallar contra el código actual
- T008 (fix de `centralState`) bloquea T009, T010, T011, T012 (todos dependen de que exista el
  nuevo valor de estado)
- T012 (botón "Liberar Mesa" sin `sessionBill()`) bloquea T013 (verificar `releaseTable()` en ese
  mismo camino)
- T014 (validación manual) va al final, después de que T004-T013 estén implementadas

### Parallel Opportunities

- T004, T005, T006, T007 pueden escribirse en paralelo (mismo archivo T004-T006, pero son tests
  independientes entre sí; T007 es un archivo distinto)
- T003 puede ejecutarse en paralelo con T002 (ambas de solo lectura/verificación)
- T016 puede revisarse en paralelo con la ejecución de T015

---

## Parallel Example: User Story 1

```bash
# Lanzar los tests de la historia de usuario 1 juntos:
Task: "Test unitario: centralState no colapsa a 'mesa-libre' en pos-terminal.store.spec.ts (T004)"
Task: "Test unitario: centralState sigue en 'mesa-libre' para mesa realmente libre (T005)"
Task: "Test unitario de regresión: pedido activo / spec 050 (T006)"
Task: "Test de componente: botón Liberar Mesa sin sessionBill() (T007)"
```

---

## Implementation Strategy

### MVP (única historia de usuario)

1. Completar Fase 1: Setup (rama + línea base)
2. Fase 2: N/A, pasar directo a Fase 3
3. Completar Fase 3: User Story 1 (tests → fix de `centralState` → guards de render → botón →
   validación manual)
4. **DETENER y VALIDAR**: confirmar los 5 escenarios de `quickstart.md`
5. Completar Fase 4: Polish (regresión completa + cierre de gobernanza)

### Notas

- `[P]` = archivos distintos o verificación de solo lectura, sin dependencia de una tarea sin
  terminar
- `[US1]` identifica cada tarea con la única historia de usuario de esta spec
- Confirmar que los tests fallan antes de implementar (T004-T007 antes de T008-T013)
- Los commits solo se ejecutan si el usuario lo pide explícitamente, en unidades pequeñas y
  lógicas, en inglés, sin marcas de autoría de IA (Principio XV)
