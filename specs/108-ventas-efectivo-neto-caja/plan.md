# Implementation Plan: Ventas en Efectivo por Valor Neto en el Resumen de Caja

**Branch**: `fix/108-ventas-efectivo-neto-caja` (`pos-specs`) | **Date**: 2026-10-10 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/108-ventas-efectivo-neto-caja/spec.md`

## Summary

La tarjeta "Ventas Efectivo" del resumen de caja hoy muestra el efectivo bruto recibido en mano
(`sales_by_method` para el tipo `cash`, construido en `pos-backend/app/api/v1/cash/service.py`),
mientras que `ReconciliationResponse.ventas_efectivo` ya calcula correctamente el valor neto
(bruto − cambio entregado) y ya es lo que usa `expected` para el Efectivo Esperado. El fix consiste
en que la fila de tipo `cash` dentro de `sales_by_method` reporte ese mismo valor neto —no uno
nuevo, el que ya existe y ya es correcto— y en actualizar el texto del banner (pantalla e impreso)
para que deje de mencionar "cambio entregado" como término de la fórmula. El cálculo de
`expected` no cambia: ya era matemáticamente correcto, solo estaba mal explicado y mal mostrado en
la tarjeta de desglose por método.

## Technical Context

**Language/Version**: Python 3.14 (`pos-backend`, vía `./env/bin/python`) + TypeScript 5.9 /
Angular 21 (`pos-heladeria`).

**Primary Dependencies**: FastAPI 0.136 + SQLAlchemy 2.0 (`pos-backend`, módulo
`app/api/v1/cash/`); Angular standalone components + signals (`pos-heladeria`, módulo
`cash-register`) — ninguna dependencia nueva (Principio IX); se reutiliza íntegramente el mismo
endpoint y el mismo store ya existentes.

**Storage**: PostgreSQL 16, un esquema por tenant — sin cambios de esquema; el fix es puramente de
cálculo/presentación sobre datos ya persistidos (`Sale.change_given`, montos de factura).

**Testing**: `pos-backend` — `./env/bin/python -m unittest discover -s app/characterization_tests
-p 'test_*.py'` (baseline 2026-10-03: 1290 OK, sin PostgreSQL local, SQLite en memoria) más un
script dedicado nuevo `app/scripts/test_cash_net_sales.py`, siguiendo el mismo patrón que la spec
107. `pos-heladeria` — `npx ng test --watch=false --include='src/app/modules/cash-register/**/*.spec.ts'`
(Vitest); la baseline general de 19 tests fallando en 6 archivos no relacionados (spec 084) no
incluye ningún archivo de `cash-register`, así que cualquier falla ahí es atribuible a este cambio.

**Target Platform**: servidor Linux (API) + SPA Angular en navegador.

**Project Type**: aplicación web existente de dos repositorios, ambos en producción.

**Performance Goals**: sin objetivo propio — el cálculo es aritmética simple sobre datos ya
agregados en una sola consulta por turno; no agrega consultas nuevas.

**Constraints**: el valor numérico final de `expected` (Efectivo Esperado) y de `difference` NO
puede cambiar para ningún turno, abierto o cerrado (FR-003) — el fix es de dónde se expone el
valor neto, no de cómo se calcula el total. Ningún dato persistido se modifica ni se migra: el
arqueo se recalcula en el momento de la consulta a partir de `Sale`/`CashMovement` ya existentes
(no hay una columna "ventas_efectivo" guardada que migrar).

**Scale/Scope**: 1 función de servicio ajustada (`reconcile` en
`pos-backend/app/api/v1/cash/service.py`), comentarios de `schemas.py` actualizados para reflejar
la nueva semántica, 1 cadena de texto cambiada en 2 plantillas del frontend
(`cash-dashboard.component.ts`, `cash-report.component.ts`) que ya comparten la misma fuente de
datos (`CashSessionStore.indicadores()`); sin endpoints nuevos, sin componentes nuevos, sin
columnas nuevas.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Evaluación |
|---|---|
| I. Nace de un spec | PASS — `specs/108-ventas-efectivo-neto-caja/spec.md` |
| II. Comportamiento existente protegido | PASS CON ACCIÓN — esto sí cambia un comportamiento visible (qué número muestra la tarjeta "Ventas Efectivo" y qué dice el banner); la decisión de negocio ya está documentada en el spec (acceptance criteria literales del pedido original), pero falta registrarla formalmente en `specs/000-reconocimiento/registro-de-anomalias.md` (próxima entrada disponible: A-122) **antes** de implementar — queda como tarea T001 de `tasks.md` |
| III. Characterization tests | PASS — se verificó que ningún test `CONGELA comportamiento actual:` cubre `sales_by_method`, `ventas_efectivo` ni el texto del banner (`grep` sobre `app/characterization_tests` solo encuentra asserts directos sobre `Sale.change_given`, no sobre el endpoint de arqueo); no hay test protegido que reabrir |
| IV. Nuevos specs introducen comportamiento nuevo | PASS — exactamente este caso: corrige qué se muestra, con spec que lo autoriza |
| V. Sin refactors oportunistas | PASS — se toca solo `reconcile()` (ya existente) y las 2 cadenas de texto del banner; no se reorganiza `cash/service.py` ni se tocan otros módulos de caja (apertura, movimientos manuales, arqueo físico) |
| VI. Evolución incremental | PASS — una sola clase de cambio (presentación/cálculo de un valor ya derivado), sin mezclar con modelo de datos ni arquitectura; no requiere Complexity Tracking |
| VII. Datos históricos | PASS, con aclaración — no hay facturas que se recalculen ni se alteren: `Sale.change_given` y los montos de cada factura no cambian. Lo que cambia es la lectura/presentación de un reporte derivado (el arqueo), que siempre se calcula en el momento de la consulta y nunca se persiste — ver Assumptions del spec. Un turno cerrado hace 3 meses, al reabrirse en el historial, se verá con la nueva interpretación — eso es el comportamiento deseado por FR-006, no una violación de inmutabilidad de facturas |
| VIII. Evolución del modelo de datos | N/A — ninguna columna, tabla ni migración nueva |
| IX. Dependencias nuevas | PASS — cero |
| X. Verificación obligatoria | PASS, ver `quickstart.md` — script dedicado en `pos-backend` + specs Angular de `cash-register` + verificación manual de los 2 textos del banner |
| XI. Negocio vs técnico | PASS — la decisión de negocio (mostrar neto, no restar cambio en la fórmula) ya está en el spec; este plan solo decide el *cómo* (reutilizar `ventas_efectivo` ya calculado en vez de duplicar el cálculo) |
| XII. Trazabilidad | PASS — necesidad (confusión al leer el arqueo) → spec 108 → decisión de negocio (pendiente de registrar, T001) → este plan → `tasks.md` → implementación → script de verificación/specs Angular |
| XIII. Español de Colombia | Aplicado en este documento y en el resto de artefactos de esta fase |
| XIV. Rama Git | Pendiente de implementación: crear `fix/108-ventas-efectivo-neto-caja` en `pos-backend` y en `pos-heladeria` antes de tocar su código (ambos repos trabajan sobre `develop`, no `main`) |
| XV. Commits | Pendiente de implementación: solo bajo pedido explícito del usuario, en inglés, sin marca de autoría de IA |

**Re-chequeo post-diseño (Fase 1)**: sin cambios — `data-model.md` y `contracts/api.md` confirman
que no se introduce ningún campo, endpoint ni dependencia nueva respecto a lo evaluado arriba. La
única acción pendiente del gate II (registrar la decisión en el registro de anomalías) se traslada
explícitamente a `tasks.md` como su primera tarea.

## Project Structure

### Documentation (this feature)

```text
specs/108-ventas-efectivo-neto-caja/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── api.md
└── tasks.md              # /speckit-tasks, no este comando
```

### Source Code (sibling repositories, fuera de `pos-specs`)

```text
../pos-backend/
├── app/api/v1/cash/
│   ├── service.py          # reconcile(): la fila `sales_by_method` de tipo "cash" pasa a
│   │                        #   reportar `ventas_efectivo` (ya calculado, neto) en vez del
│   │                        #   bruto `by_type["cash"]`; sin cambios en `expected` ni en el
│   │                        #   resto de tipos de método (card/transfer no tienen cambio)
│   └── schemas.py           # comentarios de `SalesByMethod`/`ReconciliationResponse`
│                             #   actualizados: ya no hace falta aclarar que la fila es bruta
└── app/scripts/
    └── test_cash_net_sales.py   # NUEVO, mismo patrón que test_purchase_presentation.py (spec 107)

../pos-heladeria/
└── src/app/modules/cash-register/
    ├── components/cash-dashboard.component.ts   # texto del banner: "Fondo inicial + ventas en
    │                                             #   efectivo + ingresos − egresos − retiros"
    ├── components/cash-report.component.ts      # la fila "Cambio entregado" sale de la tabla
    │                                             #   secuencial (hoy aparece con "−" entre Ventas
    │                                             #   e Ingresos, como si fuera un término de la
    │                                             #   suma que termina en "Efectivo esperado") y
    │                                             #   pasa a mostrarse aparte, como dato
    │                                             #   informativo — ver research.md D2
    └── services/cash-session.store.ts            # sin cambios: `indicadores()` sigue leyendo
                                                   #   `sales_by_method` y `cambio_entregado` tal
                                                   #   cual el backend los entrega
```

**Structure Decision**: se corrige en el único lugar donde nace el dato (`service.py`), reutilizando
`ventas_efectivo` que ya existe y ya es correcto, en vez de introducir un cálculo nuevo o parchear
el frontend para que reste el cambio a la fila bruta — eso evitaría duplicar la misma resta en dos
capas y mantiene `sales_by_method` como la única fuente de verdad que ya consume
`CashSessionStore.indicadores()` sin que el store ni los 3 componentes que lo leen
(`cash-dashboard`, `cash-report`, `cash-history`) necesiten saber que el tipo `cash` es un caso
especial.

## Complexity Tracking

*Sin violaciones que requieran justificación — ver Constitution Check arriba. La única acción de
cumplimiento pendiente (registro de anomalías, Principio II) se trata como tarea, no como
excepción.*
