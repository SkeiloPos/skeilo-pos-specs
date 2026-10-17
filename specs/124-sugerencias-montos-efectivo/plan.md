# Implementation Plan: Sugerencias de Montos para Pago en Efectivo

**Branch**: `124-sugerencias-montos-efectivo` (`pos-specs`) | **Date**: 2026-10-17 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/124-sugerencias-montos-efectivo/spec.md`

## Summary

Esta funcionalidad es **puramente de frontend** (`pos-heladeria`); no requiere ningún cambio en
`pos-backend`. Se agrega una función pura de redondeo (`roundingSuggestions`, nueva en
`payment-draft.util.ts` o un archivo hermano) que, dado un saldo pendiente, devuelve hasta 5
montos sugeridos a partir de una lista fija de denominaciones COP (8.000, 10.000, 20.000, 50.000,
100.000 — ver Clarifications de spec.md). Esa función se conecta a dos superficies de UI que ya
existen y ya calculan "saldo pendiente"/"cambio": `PaymentInputComponent` (cobro de mesa, pedido
manual y domicilio) y `PaymentAttemptReviewPanelComponent` ("Pagos por confirmar", pago QR). En
`PaymentInputComponent` también se retira el precargado automático del campo cuando el método es
Efectivo (FR-010, decisión de negocio A-135) — las líneas no efectivo no cambian. No se crea
ningún endpoint, columna, migración ni dependencia nueva.

## Technical Context

**Language/Version**: TypeScript 5.9 / Angular 21 (`pos-heladeria`). No se toca `pos-backend`
(Python 3.14 / FastAPI) en esta spec: no hay contrato de API nuevo ni cambiado.

**Primary Dependencies**: Angular standalone components + signals (`pos-heladeria`, módulo
`tables`); ninguna dependencia nueva (Principio IX) — se reutilizan `PaymentInputComponent`,
`PaymentAttemptReviewPanelComponent`, `payment-draft.util.ts`, `MoneyInputComponent` y
`formatMoney` (`shared/money.ts`) ya existentes.

**Storage**: N/A. Las denominaciones de redondeo (FR-002/FR-004) se modelan como una constante en
el frontend indexada por código de moneda (hoy solo `'COP'`, el único valor real — ver
Assumptions de spec.md), no como una tabla ni un endpoint nuevo: ningún tenant tiene hoy un campo
de moneda distinto de COP (verificado: no existe columna `currency` en `app/models/tenant*.py`),
así que no hay nada que leer de la base de datos todavía. Ver research.md D1.

**Testing**: `pos-heladeria` — `npx ng test --watch=false --include='src/app/modules/tables/**/*.spec.ts'`
(Vitest). No se ejecuta la suite de `pos-backend` porque esta spec no la toca. Re-baseline antes
de implementar: correr `payment-input.component.spec.ts`, `payment-attempt-review-panel.component.spec.ts`
y `payment-draft.util.spec.ts` en aislado y registrar su conteo previo (ver memoria de sesión:
el conteo de fallas pre-existentes de la suite completa no es determinista — comparar por archivo
tocado, no por el delta de la suite completa).

**Target Platform**: SPA Angular en navegador (terminal POS táctil) — sin cambios de plataforma.

**Project Type**: aplicación web existente de dos repositorios; esta spec solo toca uno
(`pos-heladeria`).

**Performance Goals**: SC-002 del spec — recalcular sugerencias/vuelto/faltante en menos de 1
segundo. Es una función pura sobre a lo sumo 5 números; sin riesgo de desempeño (sin llamadas de
red nuevas).

**Constraints**: FR-010 (campo "Con cuánto paga" en efectivo nace vacío) es un cambio de
comportamiento ya registrado como A-135 (Principio II) — aplica solo a `PaymentInputComponent`;
`PaymentAttemptReviewPanelComponent.amountReceived` ya nace vacío hoy, sin cambio ahí. FR-012
("Exacto" como etiqueta cuando un redondeo coincide con el saldo) y el resto de FRs no exigen
renombrar las etiquetas visuales ya existentes ("Cambio", no "Vuelto"; "Faltan $[monto] por
asignar.", no "para cubrir la cuenta.") — ver research.md D2/D3: el spec usa esos términos como
lenguaje de negocio heredado del enunciado original, pero la implementación reutiliza el copy ya
existente sin renombrarlo (evita una refactorización de copy no relacionada, Principio V).

**Scale/Scope**: 1 función pura nueva + sus tests unitarios; 2 componentes Angular existentes
extendidos con un bloque de botones de sugerencia cada uno; 1 ajuste de una línea en
`setMethod()` (retirar el precargado solo para Efectivo). Sin endpoints nuevos, sin columnas
nuevas, sin componentes de administración nuevos.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Evaluación |
|---|---|
| I. Nace de un spec | PASS — `specs/124-sugerencias-montos-efectivo/spec.md`, validado por `/speckit-clarify` |
| II. Comportamiento existente protegido | PASS — el único cambio de comportamiento existente (FR-010, retirar el precargado de "Con cuánto paga" en efectivo) está documentado en spec.md ("Decisión de negocio que cambia comportamiento existente") y **registrado como `A-135`** en `registro-de-anomalias.md` durante esta sesión de planificación |
| III. Characterization tests | PASS — se verificó (`grep "CONGELA comportamiento actual:"` sobre `pos-backend/app/characterization_tests/` y sobre los `.spec.ts` de `pos-heladeria/src/app/modules/tables/`) que ningún characterization test protege el precargado de `setMethod()`; los tests que sí lo asumen (`payment-input.component.spec.ts`) son tests propios de la spec 112, no characterization tests, y se actualizan citando `A-135` |
| IV. Nuevo comportamiento vía spec | PASS — las sugerencias de monto y el retiro del precargado son comportamiento nuevo definido íntegramente por esta spec |
| V. Nuevas funcionalidades antes que refactor | PASS — no se renombra "Cambio"→"Vuelto" ni "Faltan $X por asignar"→"para cubrir la cuenta" aunque el spec use esas palabras como lenguaje de negocio; se reutiliza el copy visual existente sin tocarlo (research.md D2/D3) |
| VI. Evolución incremental | PASS — un solo tipo de cambio (UI + una función pura), sin mezclar migración de datos, refactor ni cambio de arquitectura |
| VII. Compatibilidad con datos históricos | PASS — no hay escritura de datos nueva; los `Payment`/`Sale` ya emitidos no se tocan |
| VIII. Evolución del modelo de datos | N/A — sin cambios de esquema |
| IX. Dependencias nuevas | PASS — ninguna dependencia nueva; se evaluó y se descartó crear un endpoint de catálogo de denominaciones (research.md D1) por no haber hoy ningún tenant en otra moneda que lo necesite |
| X. Verificación obligatoria | PASS (pendiente de ejecución en `/speckit-implement`) — tests unitarios de la función pura + tests de componente actualizados/nuevos para ambas superficies |
| XI. Negocio vs. técnico | PASS — FR-010 es una decisión de negocio (A-135); la elección de modelar las denominaciones como constante en vez de endpoint es una decisión técnica, justificada en research.md D1 |
| XII. Trazabilidad | PASS — Necesidad (enunciado original) → Spec 124 → Decisión A-135 → este plan → tareas/tests (pendiente de `/speckit-tasks`) |
| XIII. Español de Colombia | PASS — todos los artefactos de esta spec (spec, clarifications, plan, research, data-model, quickstart) están en español de Colombia |
| XIV. Convención de ramas Git | PENDIENTE — se crea al iniciar la implementación (`/speckit-implement`), con nombre en inglés `feat/124-cash-payment-suggestions`, no antes |
| XV. Política de commits | N/A en esta fase — no se ha commiteado nada; se aplicará al implementar |

Sin violaciones; no se requiere "Complexity Tracking".

## Project Structure

### Documentation (this feature)

```text
specs/124-sugerencias-montos-efectivo/
├── plan.md              # Este archivo (/speckit-plan)
├── research.md          # Fase 0 (/speckit-plan)
├── data-model.md        # Fase 1 (/speckit-plan)
├── quickstart.md        # Fase 1 (/speckit-plan)
├── contracts/
│   └── rounding-suggestions.md   # Contrato de la función pura y de los Inputs/Outputs de UI
└── tasks.md             # Fase 2 (/speckit-tasks — no se crea en /speckit-plan)
```

### Source Code (repository root)

Esta spec solo toca `pos-heladeria` (no crea proyectos ni carpetas nuevas):

```text
pos-heladeria/src/app/modules/tables/
├── services/
│   └── payment-draft.util.ts                      # + roundingSuggestions(), + constante de denominaciones
├── components/
│   ├── payment-input.component.ts                 # + botones de sugerencia por línea en efectivo; retira precargado (FR-010)
│   ├── payment-input.component.spec.ts             # tests actualizados (A-135) + tests nuevos de sugerencias
│   ├── payment-attempt-review-panel.component.ts   # + botones de sugerencia (FR-013); sin cambio de precargado
│   └── payment-attempt-review-panel.component.spec.ts  # tests nuevos de sugerencias
```

**Structure Decision**: se extienden los dos componentes y el util ya existentes, en su mismo
módulo (`tables`); no se crea ningún componente, servicio ni módulo nuevo. La función de
redondeo vive junto a `payment-draft.util.ts` porque ambas superficies (`PaymentInputComponent`
y `PaymentAttemptReviewPanelComponent`) ya dependen de ese módulo o de uno hermano en el mismo
directorio `services/`, evitando una dependencia cruzada nueva entre componentes.

## Complexity Tracking

> Sin violaciones de la Constitución que justificar — tabla omitida.
