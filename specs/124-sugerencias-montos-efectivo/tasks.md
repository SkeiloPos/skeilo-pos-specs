---

description: "Tareas de la spec 124 — sugerencias de montos para pago en efectivo (US1–US5)"
---

# Tasks: Sugerencias de Montos para Pago en Efectivo

**Input**: Documentos de diseño de `/specs/124-sugerencias-montos-efectivo/`
**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md) (D1–D6), [data-model.md](./data-model.md), [contracts/rounding-suggestions.md](./contracts/rounding-suggestions.md), [quickstart.md](./quickstart.md)

**Tests**: `pos-heladeria` usa `ng test` (Vitest). El plan (Constitution Check, Principio X) ya
compromete tests unitarios de la función pura más tests de componente nuevos/actualizados para
las dos superficies de UI — se incluyen aquí como tareas. Las tareas de prueba van antes de la
implementación de cada historia y deben fallar contra el código actual (la función
`roundingSuggestions` no existe todavía).

**Organización**: las tareas se agrupan por historia de usuario en el orden de prioridad de
`spec.md` (US1 P1 → US2 P2 → US5 P2 → US3 P3 → US4 P3). Todas las rutas fueron verificadas contra
el código real de `pos-heladeria` (rama `develop`, árbol limpio) el 2026-10-17 durante
`/speckit-plan` (ver `research.md` D1–D6), no contra una lectura abstracta del spec.

## Formato: `[ID] [P?] [Story] Descripción`

- **[P]**: puede ejecutarse en paralelo (archivo distinto, sin dependencia de una tarea sin
  terminar)
- **[Story]**: a qué historia de usuario pertenece (US1–US5)
- Cada tarea incluye la ruta exacta del archivo

## Convenciones de ruta

- Todas las rutas son relativas a `../pos-heladeria` (no se toca `pos-backend` en esta spec — ver
  plan.md, Summary). Abreviatura: `tables/` = `../pos-heladeria/src/app/modules/tables/`.
- Tests: `npx ng test --watch=false --include='<ruta-del-archivo>'` desde `../pos-heladeria`.

## Nota sobre gobernanza y ramas

- **Decisión de negocio ya registrada**: `A-135` en `specs/000-reconocimiento/registro-de-anomalias.md`
  (retiro del precargado de "Con cuánto paga" en efectivo, FR-010) — registrada durante
  `/speckit-plan`, antes de implementar (Principio II).
- **Sin migración, sin endpoint nuevo**: esta spec es enteramente frontend (plan.md, Summary).
- **Rama (Principio XIV)**: una sola rama, `feat/124-cash-payment-suggestions`, desde `develop` en
  `../pos-heladeria` (confirmar árbol limpio con `git status` antes de crearla).
- **Commits (Principio XV)**: solo cuando el usuario lo pida; pequeños por unidad lógica (función
  pura + sus tests; cambios de `PaymentInputComponent`; cambios de
  `PaymentAttemptReviewPanelComponent`), en inglés, Conventional Commits, sin marca de IA.

---

## Phase 1: Setup

- [X] T001 Confirmar `git status` limpio en `../pos-heladeria` sobre `develop` y crear la rama
  `feat/124-cash-payment-suggestions`

- [X] T002 Línea base por archivo (research.md D6 — el delta de la suite completa no es
  confiable): correr en aislado
  `npx ng test --watch=false --include='src/app/modules/tables/services/payment-draft.util.spec.ts'`,
  `--include='src/app/modules/tables/components/payment-input.component.spec.ts'` y
  `--include='src/app/modules/tables/components/payment-attempt-review-panel.component.spec.ts'`
  en `../pos-heladeria`, y registrar el conteo de fallas de cada uno (si alguno) antes de tocar
  código — **resultado**: 22/22, 11/11, 20/20, sin fallas previas en ninguno de los 3 archivos

**Checkpoint**: rama creada, línea base de los 3 archivos documentada.

---

## Phase 2: Foundational (función pura de redondeo; bloquea US1 y US5)

**⚠️ CRITICAL**: ninguna historia de usuario puede completarse sin esta fase.

- [X] T003 [P] Tests para `roundingSuggestions` en `tables/services/payment-draft.util.spec.ts`
  (deben fallar: la función no existe aún) — la tabla de casos de
  `contracts/rounding-suggestions.md` (22000→`[24000,30000,40000,50000,100000]`;
  47500→`[48000,50000,60000,100000]`; 12000→`[16000,20000,50000,100000]`;
  100000→`[100000,104000]`), más `saldoPendiente <= 0` y denominaciones vacías — confirmado en
  rojo (`TS2305: no exported member 'roundingSuggestions'`)

- [X] T004 En `tables/services/payment-draft.util.ts`: agregar la constante
  `ROUNDING_DENOMINATIONS_BY_CURRENCY: Record<'COP', number[]> = { COP: [8000, 10000, 20000, 50000, 100000] }`
  y la función pura `roundingSuggestions(saldoPendiente: number, denominations = ROUNDING_DENOMINATIONS_BY_CURRENCY.COP): number[]`
  (data-model.md §1–2: `Math.ceil(saldoPendiente / d) * d` por cada `d`, `Set` + `sort`
  ascendente). Hace pasar T003 — 28/28 en verde. Depende de T003

**Checkpoint**: `roundingSuggestions` lista y probada; ningún componente la usa todavía.

---

## Phase 3: User Story 1 — Registrar con un toque con cuánto paga el cliente (Priority: P1) 🎯 MVP

**Goal**: en `PaymentInputComponent` (cobro de mesa, pedido manual y domicilio), el campo "Con
cuánto paga" nace vacío para una línea en efectivo (FR-010, `A-135`) y se muestran hasta 5
botones de sugerencia que lo llenan con un toque (FR-001/002/003/005/006/008/009/012).

**Independent Test**: cobrar un pedido en efectivo con un único método, verificar que el campo
nace vacío con los botones correctos, tocar uno y verificar que el campo se llena, "Cambio" se
calcula y "Cobrar" se habilita (spec.md, Historia 1; quickstart.md, Escenario 1).

### Tests para User Story 1 (escribir primero; deben fallar) ⚠️

- [X] T005 [P] [US1] En `tables/components/payment-input.component.spec.ts`: (a) al elegir
  "Efectivo" en una línea nueva, `line.amount` queda en `0` (no se precarga con `total`) — cubre
  FR-010/`A-135`; (b) con saldo pendiente $22.000 se renderizan los botones
  `[24000,30000,40000,50000,100000]`, ninguno etiquetado "Exacto"; (c) con saldo pendiente
  $100.000 se renderizan solo 2 botones, uno etiquetado "Exacto" ($100.000) y otro "$104.000"
  (FR-012); (d) tocar un botón llama a `setAmount(i, valor)` y el bloque "Cambio" muestra el
  valor correcto — confirmado en rojo antes de T006/T007 (la plantilla no tenía botones de
  sugerencia ni la condición nueva de `setMethod`)

### Implementación de User Story 1

- [X] T006 [US1] En `tables/components/payment-input.component.ts::setMethod()`: cuando
  `isCash(methodId)`, no precargar `amount` (queda en `0`); para cualquier otro método, sin
  cambios respecto al código actual (FR-010, `A-135`). Depende de T005. También se ajustó el
  binding `[ngModel]="line.amount || null"` (antes `line.amount`) para que el campo se vea
  realmente vacío en `0`, no "0" — `money-input` solo muestra vacío para `null`/`undefined`

- [X] T007 [US1] En `tables/components/payment-input.component.ts`: dentro del bloque
  `@if (line.methodId)`, cuando `isCash(line.methodId)` y
  `pendingBalanceExcluding(draft(), i, total, methods) > 0`, renderizar hasta 5 botones con
  `roundingSuggestions(pendingBalanceExcluding(draft(), i, total, methods))`; cada botón muestra
  "Exacto" si su valor coincide con ese saldo pendiente, o `money(valor)` en caso contrario; click
  llama a `setAmount(i, valor)` (FR-001/002/003/005/006/008/009/012, contracts/rounding-suggestions.md).
  Depende de T004, T006 — 19/19 en verde (11 previas + 8 nuevas)

**Checkpoint**: User Story 1 funcional de forma independiente — MVP cobrable.

---

## Phase 4: User Story 2 — Sugerencias correctas en pago combinado con efectivo (Priority: P2)

**Goal**: cuando la línea en efectivo no es la única (pago mixto), las sugerencias se calculan y
recalculan sobre el saldo pendiente real, nunca sobre el total completo (FR-009).

**Independent Test**: registrar $10.000 por Nequi, agregar una línea de Efectivo y verificar que
las sugerencias son las del saldo de $12.000; eliminar la línea de Nequi y verificar que se
recalculan sobre $22.000 (spec.md, Historia 2; quickstart.md, Escenario 2).

### Tests para User Story 2 (escribir primero; deben fallar si hay alguna brecha) ⚠️

- [X] T008 [P] [US2] En `tables/components/payment-input.component.spec.ts`: con una línea de
  $10.000 por un método no efectivo y una segunda línea en Efectivo, las sugerencias son
  `[16000,20000,50000,100000]`; al eliminar la primera línea, las sugerencias de la línea de
  efectivo se recalculan de inmediato sobre `[24000,30000,40000,50000,100000]` (saldo $22.000) —
  escritas junto a T005 (mismo archivo), confirmadas en verde sin cambios adicionales

### Implementación de User Story 2

- [X] T009 [US2] Verificar contra T008: como T007 ya deriva las sugerencias de
  `pendingBalanceExcluding(draft(), i, total, methods)` (señal reactiva, se recalcula en cada
  `patchLine`/`removeLine`), no debería requerir código nuevo. Si T008 falla, ajustar T007 en
  `tables/components/payment-input.component.ts` hasta que la recalculación sea inmediata.
  Depende de T007, T008 — confirmado: no hizo falta ningún cambio de código, T007 ya lo cubre

**Checkpoint**: User Story 1 y 2 funcionan juntas de forma independiente.

---

## Phase 5: User Story 5 — Confirmar con un toque un pago en efectivo declarado por QR (Priority: P2)

**Goal**: en `PaymentAttemptReviewPanelComponent` ("Pagos por confirmar"), se muestran hasta 5
botones de sugerencia calculados sobre el total del pedido (FR-013).

**Independent Test**: abrir "Pagos por confirmar" para un pedido QR con pago en efectivo
declarado, tocar una sugerencia y verificar que el campo de monto recibido se llena y "Confirmar
efectivo" se habilita si cubre el total (spec.md, Historia 5; quickstart.md, Escenario 5).

### Tests para User Story 5 (escribir primero; deben fallar) ⚠️

- [X] T010 [P] [US5] En `tables/components/payment-attempt-review-panel.component.spec.ts`: con
  `attempt.is_cash` y `checkoutPreview().total = 16000`, se renderizan hasta 5 botones de
  `roundingSuggestions(16000)`; tocar uno asigna `amountReceived = valor` y actualiza el bloque
  "Cambio" (positivo o negativo) igual que si se hubiera escrito a mano — confirmado en rojo (2
  tests) antes de T011; las 3 pruebas de "sin sugerencias" (preview en error, método no efectivo)
  ya pasaban porque la plantilla todavía no tenía ningún botón

### Implementación de User Story 5

- [X] T011 [US5] En `tables/components/payment-attempt-review-panel.component.ts`: dentro de la
  rama `@if (attempt.is_cash)`, cuando `checkoutPreview()` tiene valor, renderizar hasta 5 botones
  junto al `<app-money-input>` de "Monto recibido" con
  `roundingSuggestions(Number(checkoutPreview()!.total))`; etiqueta "Exacto" si coincide con el
  total; click asigna `this.amountReceived = valor` (FR-013, contracts/rounding-suggestions.md).
  Sin cambios en `confirmCash()` ni en la inicialización de `amountReceived`. Depende de T004, T010
  — 24/24 en verde. Se cambió `orderTotal()` de `private` a público (`strictTemplates` en
  `tsconfig.json` exige que la plantilla pueda acceder a lo que usa) y se agregó el método público
  `suggestions()`

**Checkpoint**: las 3 historias P1/P2 funcionan de forma independiente.

---

## Phase 6: User Story 3 — El sistema sigue bloqueando el cobro si el monto recibido no alcanza (Priority: P3)

**Goal**: confirmar que la validación de monto insuficiente ya existente sigue funcionando,
comparando contra el saldo pendiente de la línea (no contra el total) una vez retirado el
precargado (research.md D3: el mensaje real es "Faltan $[monto] por asignar.").

**Independent Test**: escribir a mano un monto menor al saldo pendiente y verificar el mensaje de
faltante y que "Cobrar" queda deshabilitado (spec.md, Historia 3; quickstart.md, Escenario 3).

### Tests para User Story 3 (escribir primero; deben fallar si hay alguna regresión) ⚠️

- [X] T012 [P] [US3] En `tables/components/payment-input.component.spec.ts`: con saldo pendiente
  $22.000 y método Efectivo, escribir a mano $20.000 → `issue()` es
  `"Faltan $2.000 por asignar."` y "Cobrar" deshabilitado; corregir a $25.000 (o tocar una
  sugerencia) → el mensaje desaparece, "Cambio" muestra el valor correcto y "Cobrar" se habilita —
  escrita junto a T005 (mismo archivo); confirmada en verde sin cambios adicionales

### Implementación de User Story 3

- [X] T013 [US3] Verificar contra T012: `paymentIssue()`/`missingAmount()` en
  `tables/services/payment-draft.util.ts` ya implementan esta regla sin cambios (no se toca
  texto ya existente, research.md D3). Si T012 falla, es una regresión introducida por T006/T007 —
  corregirla ahí, no reescribir el mensaje. Depende de T007, T012 — confirmado: ningún cambio de
  código hizo falta, la regla ya existente sigue intacta

**Checkpoint**: la protección de monto insuficiente sigue intacta tras retirar el precargado.

---

## Phase 7: User Story 4 — Sin sugerencias de billetes para métodos distintos a efectivo (Priority: P3)

**Goal**: ningún botón de sugerencia aparece cuando el método de la línea no es Efectivo
(FR-008).

**Independent Test**: elegir "Bancolombia" como método de una línea y verificar que no aparece
ningún botón de sugerencia (spec.md, Historia 4; quickstart.md, Escenario 4).

### Tests para User Story 4 (escribir primero; deben fallar si hay alguna regresión) ⚠️

- [X] T014 [P] [US4] En `tables/components/payment-input.component.spec.ts`: con método
  "Bancolombia" (`is_cash: false`) en una línea, no se renderiza ningún botón de sugerencia —
  escrita junto a T005 (mismo archivo, probado con "Nequi"/`pm-transfer`, también `is_cash:
  false`); confirmada en verde sin cambios adicionales

### Implementación de User Story 4

- [X] T015 [US4] Verificar contra T014: la condición `isCash(line.methodId)` de T007 ya excluye
  este caso (no entra al bloque que renderiza botones). Si T014 falla, corregir la condición en
  `tables/components/payment-input.component.ts`. Depende de T007, T014 — confirmado: ningún
  cambio de código hizo falta

**Checkpoint**: las 5 historias de usuario funcionan de forma independiente.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [~] T016 [P] Ejecutar manualmente los 5 escenarios + 2 casos borde de `quickstart.md` contra un
  tenant de prueba con turno de caja abierto — **parcial**: esta sesión no tiene un navegador
  disponible para abrir la Terminal real; se corrió `npx ng build` (producción, `strictTemplates`)
  sin errores y las 71 pruebas automatizadas de T002–T015 cubren los 5 escenarios y los 2 casos
  borde de `quickstart.md` al nivel de componente. **Pendiente**: validación manual en navegador
  contra un tenant real antes de mezclar a `develop`

- [X] T017 Re-correr en aislado los 3 archivos de T002 y comparar contra la línea base; ningún
  test `"CONGELA comportamiento actual:"` existe en estos archivos (no son characterization
  tests), así que no aplica ese chequeo — solo confirmar que no quedó ninguna falla nueva sin
  explicar. **Resultado**: 71/71 (28+19+24), sin fallas, sin regresión respecto a la línea base
  (22/22, 11/11, 20/20)

- [X] T018 [P] Revisar que el comentario de cabecera de `setMethod()` en
  `tables/components/payment-input.component.ts` cite `A-135` (trazabilidad, Principio XII),
  igual que el comentario existente ya cita `A-124`/spec 112 — confirmado

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias — empieza de inmediato.
- **Foundational (Phase 2)**: depende de Setup — **bloquea** US1 y US5 (ambas llaman a
  `roundingSuggestions`).
- **User Stories (Phase 3-7)**: todas dependen de Foundational. US2, US3 y US4 además dependen de
  que T007 (US1) exista, porque reutilizan el mismo bloque de renderizado — no son peticiones de
  código nuevo, son verificaciones/ajustes sobre lo que entrega US1.
- **Polish (Phase 8)**: depende de que las historias que se vayan a entregar ya estén completas.

### User Story Dependencies

- **US1 (P1)**: depende solo de Foundational. Es el MVP.
- **US2 (P2)**: depende de Foundational y de que exista el bloque de renderizado de US1 (T007) —
  reutiliza `pendingBalanceExcluding`, que ya es reactivo; verifica que no haga falta tocar nada
  más.
- **US5 (P2)**: depende solo de Foundational — superficie distinta (`PaymentAttemptReviewPanelComponent`),
  no toca `PaymentInputComponent`. Puede implementarse en paralelo a US1/US2 por otra persona.
- **US3 (P3)**: depende de Foundational y de T007 — verifica que la validación de faltante ya
  existente no se rompió.
- **US4 (P3)**: depende de Foundational y de T007 — verifica que la condición `isCash` ya excluye
  métodos no efectivo.

### Parallel Opportunities

- T001/T002 (Setup) son secuenciales entre sí (confirmar rama antes de correr baseline).
- T003 (Foundational) no tiene dependientes previos — único [P] de esa fase.
- T005 (tests de US1) puede escribirse en paralelo a T010 (tests de US5): archivos distintos.
- Una vez T007 existe, T008/T012/T014 (tests de US2/US3/US4) pueden escribirse en paralelo entre
  sí (mismo archivo que T005, pero tareas de solo-lectura/aserciones que no se pisan si se
  redactan como bloques `it()` independientes — ejecutarlas en paralelo con otra persona sigue
  requiriendo coordinarse en el mismo archivo).
- T011 (US5) puede implementarse en paralelo a T009/T013/T015 (US2/US3/US4): archivo distinto
  (`payment-attempt-review-panel.component.ts` vs. `payment-input.component.ts`).

---

## Parallel Example: Foundational + User Story 1 + User Story 5

```bash
# Tras Phase 1 (Setup):
Task: "T003 [P] Tests para roundingSuggestions en payment-draft.util.spec.ts"
# T004 depende de T003 — no paralelizable con ella.

# Tras Phase 2 (Foundational):
Task: "T005 [P] [US1] Tests de PaymentInputComponent (precargado vacío, botones, Exacto)"
Task: "T010 [P] [US5] Tests de PaymentAttemptReviewPanelComponent (botones sobre el total QR)"
# Dos archivos de test distintos — dos personas pueden avanzar US1 y US5 a la vez.
```

---

## Implementation Strategy

### MVP primero (User Story 1 solamente)

1. Completar Phase 1 (Setup) y Phase 2 (Foundational — bloqueante).
2. Completar Phase 3 (US1).
3. **Detenerse y validar**: correr quickstart.md, Escenario 1, manualmente.
4. Esto ya es un incremento demostrable: cobro de mesa/manual/domicilio con sugerencias.

### Entrega incremental

1. Setup + Foundational → base lista.
2. US1 → validar → (opcional) desplegar/demostrar (MVP).
3. US2 → validar que el pago mixto sigue correcto.
4. US5 → validar "Pagos por confirmar" (puede hacerse en paralelo a US2/US3/US4, otra persona).
5. US3 y US4 → confirmar que ninguna protección existente se rompió.
6. Polish (quickstart completo + trazabilidad `A-135`).

---

## Notes

- US2, US3 y US4 son, en su mayoría, tareas de **verificación** sobre lo que ya entrega US1
  (T007) — el diseño de `roundingSuggestions` + `pendingBalanceExcluding` ya reactivo cubre esos
  casos sin código adicional; las tareas existen para que cada historia siga siendo
  independientemente verificable (spec.md lo exige), no porque se anticipe una reimplementación.
- Ningún test `"CONGELA comportamiento actual:"` protege nada de lo que toca esta spec — se
  confirmó durante `/speckit-plan` (plan.md, Constitution Check, Principio III).
- Commitear solo cuando el usuario lo pida (Principio XV); unidades sugeridas: (T003-T004),
  (T005-T007), (T008-T009), (T010-T011), (T012-T015), (T016-T018).
