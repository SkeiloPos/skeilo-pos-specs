---

description: "Tareas de la spec 126 (replanificadas tras A-138) — verificación de regresión, un solo test nuevo"
---

# Tasks: Nuevo Pedido en Mesa con Cuenta Pagada

**Input**: Documentos de diseño de `/specs/126-nuevo-pedido-mesa-pagada/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [quickstart.md](./quickstart.md)

**Nota sobre el `tasks.md` anterior**: este documento **reemplaza por completo** el generado
antes de la segunda sesión de `/speckit-clarify` (planificaba implementar A-137, el bloqueo —
revertido el mismo día por A-138 antes de ejecutarse ninguna tarea). Tras el replan, **FR-001 a
FR-011 ya están implementados**; el único trabajo de código de esta spec es **un test de
regresión nuevo** (research.md, Decisión 1) — todo lo demás es ejecutar suites ya existentes y
validación manual, sin tocar ningún archivo de producción.

**Tests**: Se incluye un único test nuevo (ver Phase 4). El resto de las tareas son ejecución de
tests/validación ya existentes, no construcción de funcionalidad.

**Organización**: Tareas agrupadas por historia de usuario (spec.md: US1, US2, US3). No hay fase
Foundational: al no haber implementación compartida entre historias, no existe trabajo
fundacional que resolver por separado — cada historia es, en sí misma, verificación de un
subconjunto de FR. Acotado casi en su totalidad a `../pos-heladeria`; `../pos-backend` solo se
ejecuta (sin tocarse) para confirmar que sus characterization tests siguen en verde.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: puede ejecutarse en paralelo (archivo distinto, o verificación de solo lectura sin
  dependencia de una tarea sin terminar)
- **[Story]**: US1, US2, US3 — mapea a las Historias 1-3 de `spec.md`
- Cada tarea incluye la ruta exacta del archivo (cuando aplica)

## Path Conventions

- `../pos-heladeria/...` — SPA Angular (TypeScript); único repositorio con un archivo tocado
  (un test)
- `../pos-backend/...` — API FastAPI; se ejecuta, no se modifica
- Sin prefijo — archivo dentro de este repo (`pos-specs`)

---

## Phase 1: Setup

**Propósito**: preparar la rama de trabajo (solo para el test nuevo) y confirmar la línea base.

- [X] T001 Crear la rama `chore/126-verify-new-order-pending-balance` desde la rama actual en
      `../pos-heladeria` (Principio XIV) — único cambio de código de toda la spec es un archivo
      de test en este repo; `../pos-backend` no requiere rama (sin cambios, plan.md Summary).
- [X] T002 Confirmar árbol de trabajo limpio en `../pos-heladeria` y `../pos-backend` antes de
      empezar (ya verificado durante `/speckit-plan`: ambos en `develop` sin cambios pendientes).
- [X] T003 [P] Ejecutar
      `npx ng test --watch=false --include='src/app/modules/tables/**/*.spec.ts'` en
      `../pos-heladeria` y registrar el resultado como línea base (Principio X; comparar contra
      el baseline ya documentado en la memoria del proyecto).
- [X] T004 [P] Ejecutar
      `cd ../pos-backend && ./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`
      y registrar el resultado como línea base.

**Checkpoint**: rama creada, línea base de ambas suites registrada.

---

## Phase 2: Foundational (Blocking Prerequisites)

**No aplica a esta spec.** No hay ninguna pieza de código compartida entre historias de usuario
que resolver por separado — el único cambio (T007, Phase 4) es un test autocontenido. Las tres
historias dependen únicamente de Setup.

**Checkpoint**: N/A — continuar directamente a la Fase 3.

---

## Phase 3: User Story 1 - Iniciar una segunda ronda en una mesa ya pagada (Priority: P1)

**Goal**: confirmar que el camino ya existente (mesa pagada → "+ Crear pedido nuevo" →
`manual-order-page.component.ts` con esa mesa preseleccionada) sigue funcionando exactamente
igual tras A-138 — comportamiento de spec 087, sin cambios de esta spec (research.md, Decisión
3).

**Independent Test**: pagar por completo el único pedido de una mesa, usar "+ Crear pedido
nuevo" con esa mesa seleccionada, y verificar que navega correctamente con el pedido anterior
intacto (quickstart.md, Escenario 1).

- [ ] T005 [US1] Ejecutar manualmente el Escenario 1 de [quickstart.md](./quickstart.md) (mesa
      pagada, cocina todavía trabajando → segunda ronda) y registrar el resultado.
- [X] T006 [P] [US1] Confirmar por lectura de código (sin escribir ningún test nuevo —
      research.md, Decisión 3) que FR-003 a FR-008 siguen vigentes sin cambios:
      `manual-order-page.component.ts` (navegación y draft no persistido, spec 045/052),
      `orderTabs()`/`table_order_number` en `pos-terminal.store.ts` (pestañas "Pedido N", spec
      087), y el renderizado de cocina sin alteración. Registrar qué se revisó.

**Checkpoint**: el camino "feliz" de la Historia 1 sigue funcionando, sin ninguna regresión ni
código nuevo.

---

## Phase 4: User Story 2 - Varias cuentas sin resolver conviven en la misma mesa, cada una independiente (Priority: P1) 🎯 Único trabajo de código de la spec

**Goal**: cerrar el único hueco de cobertura real que encontró `research.md` (Decisión 1): hoy
ningún test junta, en una sola aserción, "mesa seleccionada con saldo pendiente o pedido sin
pagar" + "'+ Crear pedido nuevo' habilitado". Se agrega ese test, citando A-138, para que una
futura reintroducción accidental de A-137 falle con un mensaje que apunte a la decisión de
negocio que lo prohíbe (Principio III).

**Independent Test**: dejar un pedido de mesa con saldo pendiente (o sin pagar), seleccionar esa
mesa, y verificar que "+ Crear pedido nuevo" aparece habilitado — nunca deshabilitado por esa
razón (quickstart.md, Escenario 2).

### Tests for User Story 2

- [X] T007 [US2] Agregar, en
      `../pos-heladeria/src/app/modules/tables/pages/table-sessions.component.spec.ts`, un test
      nuevo: con una mesa seleccionada cuyo único pedido tiene `pending_balance > 0` (o
      `status: 'recibida'`, sin pagar), `cta().disabled` DEBE ser `false` — citar A-138 en el
      nombre/comentario del test como la decisión que protege. (Research.md, Decisión 1.)

### Implementation for User Story 2

- [X] T008 [P] [US2] Confirmar que T007, ejecutado contra una versión hipotética con la
      condición de A-137 reintroducida (`newOrderTableId()` devolviendo `null` para una mesa con
      saldo pendiente), **falla** — es la prueba de que el test agregado protege algo real, no
      solo pasa trivialmente. Registrar el resultado (puede hacerse revirtiendo T007 mentalmente/
      con un `git stash` temporal del test, sin tocar producción).
- [ ] T009 [P] [US2] Ejecutar manualmente los Escenarios 2 y 3 de
      [quickstart.md](./quickstart.md) (coexistencia de varias cuentas sin resolver; ausencia de
      cualquier acción de "consolidar cuentas", FR-010) y registrar el resultado de cada uno.
- [X] T010 [US2] Ejecutar
      `npx ng test --watch=false --include='src/app/modules/tables/pages/table-sessions.component.spec.ts'`
      en `../pos-heladeria` y confirmar que T007 pasa y que ningún test existente de spec 087 se
      rompió. (Depende de T007.)

**Checkpoint**: la Historia 2 queda con cobertura explícita y trazable hacia A-138; sin ningún
archivo de producción tocado.

---

## Phase 5: User Story 3 - Abandonar un pedido nuevo vacío (Priority: P3)

**Goal**: confirmar que el descarte de carritos vacíos (`manual-order-page.component.ts`, nunca
persistido hasta confirmar) sigue aplicando igual, sin importar cuántas cuentas sin resolver
tenga ya la mesa — sin cambios de código (research.md, Decisión 3).

**Independent Test**: usar "+ Crear pedido nuevo" en cualquier mesa (pagada, con saldo pendiente
o sin pagar), sin agregar productos, volver a la Terminal, y verificar que no queda ningún
rastro (quickstart.md, Escenario 5).

- [ ] T011 [US3] Ejecutar manualmente el Escenario 5 de [quickstart.md](./quickstart.md) y
      registrar el resultado.
- [X] T012 [P] [US3] Confirmar por lectura de código que `confirm()`/`backToTerminal()` en
      `manual-order-page.component.ts` no tienen ninguna dependencia del estado de pago de la
      mesa (el descarte es puramente "no hay petición de red hasta confirmar", sin relación con
      saldo pendiente) — sin acción adicional, research.md Decisión 3.

**Checkpoint**: las tres historias de usuario quedan verificadas de forma independiente.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Propósito**: cerrar la verificación global y la gobernanza antes de dar la spec por
completada.

- [ ] T013 Ejecutar manualmente el Escenario 4 de [quickstart.md](./quickstart.md) (liberar mesa
      con saldo pendiente → bloqueado; anular el pedido → procede; ninguna liberación forzada
      existe) y registrar el resultado.
- [X] T014 Ejecutar la suite completa de `ng test` en `../pos-heladeria` y confirmar que no se
      rompió ningún test fuera del baseline ya documentado en la memoria del proyecto
      (Principio X).
- [X] T015 [P] Ejecutar la suite completa de characterization tests en `../pos-backend`
      (`./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`) y
      confirmar que sigue en verde **sin modificación** — prueba de que esta spec no tocó
      `has_billable_orders`/`has_pending_balance`/`compute_bill`/`release_paid_session`/
      `cancel_order` (research.md, Decisiones 4 y 6).
- [X] T016 Actualizar el **Estado** de
      [A-138](../000-reconocimiento/registro-de-anomalias.md#a-138--decisión-de-negocio--spec-126-se-revierte-a-137-crear-pedido-nuevo-vuelve-a-estar-disponible-con-saldo-pendiente)
      de "REGISTRADA, pendiente de que `spec.md`/`plan.md`/`tasks.md` se actualicen" a
      "REGISTRADA y verificada", citando T007-T010 como evidencia de que la cobertura de
      regresión quedó en su lugar.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias — puede iniciar de inmediato
- **Foundational (Phase 2)**: N/A, no bloquea nada
- **User Story 1 (Phase 3)**: depende de Setup
- **User Story 2 (Phase 4)**: depende de Setup; independiente de la Fase 3
- **User Story 3 (Phase 5)**: depende de Setup; independiente de las Fases 3-4
- **Polish (Phase 6)**: depende de que las Fases 3, 4 y 5 estén completas

### Within Each User Story

- US1: T005 y T006 pueden ejecutarse en cualquier orden (ambas de solo lectura/validación)
- US2: T007 (escribir el test) antes de T008 y T010 (verificarlo); T009 es independiente
- US3: T011 y T012 pueden ejecutarse en cualquier orden

### Parallel Opportunities

- T003 y T004 en paralelo (repos distintos)
- T005/T006 (US1), T008/T009 (US2) y T011/T012 (US3) son de solo lectura/validación — paralelos
  entre sí y con las demás historias
- Las Fases 3, 4 y 5 completas pueden ejecutarse en paralelo entre sí (ninguna depende de otra)
- T014 y T015 en paralelo (repos distintos)

---

## Parallel Example: Las tres historias a la vez

```bash
# Tras Setup, lanzar en paralelo (ninguna historia depende de otra):
Task: "Validar camino feliz de Historia 1 (T005-T006)"
Task: "Agregar y verificar el único test nuevo de Historia 2 (T007-T010)"
Task: "Validar descarte de pedido vacío de Historia 3 (T011-T012)"
```

---

## Implementation Strategy

### MVP (todo el trabajo de código cabe en una sola historia)

1. Completar Fase 1: Setup (rama + línea base en ambos repos)
2. Completar Fase 4: User Story 2 — es la única con código (T007), y es la que cierra el
   verdadero hueco de trazabilidad hacia A-138
3. **DETENER y VALIDAR**: confirmar que T007 pasa y que T008 demuestra que protege algo real

### Entrega incremental

1. Setup → línea base conocida en ambos repos
2. Historia 2 (el único test nuevo) → valida → esto ya cierra la trazabilidad de A-138
3. Historias 1 y 3 (validación pura, sin código) → en paralelo con lo anterior o después
4. Polish → regresión completa + cierre de gobernanza (A-138 → "verificada")

### Notas

- `[P]` = archivos distintos, repos distintos, o verificaciones de solo lectura, sin dependencia
  de una tarea sin terminar
- `[US1]`/`[US2]`/`[US3]` identifican cada tarea con su historia de usuario
- Esta spec tiene un solo archivo de producción tocado en total: ninguno. El único archivo
  tocado es un `*.spec.ts` (T007)
- Los commits solo se ejecutan si el usuario lo pide explícitamente, en unidades pequeñas y
  lógicas, en inglés, sin marcas de autoría de IA (Principio XV)
