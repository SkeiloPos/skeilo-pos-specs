# Implementation Plan: Consistencia de promociones en el detalle de la orden y en las tarjetas de la terminal

**Branch**: `118-promociones-totales-terminal` | **Date**: 2026-10-14 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/118-promociones-totales-terminal/spec.md`

## Summary

Investigación de código (no solo de specs anteriores) confirma que **ambos problemas comparten una
sola causa raíz en el backend**: el motor de promociones (`evaluate_variant_sets`,
`app/api/v1/promotions/service.py`) ya agrupa correctamente las unidades de la misma presentación
sin importar en cuántas filas `OrderItem` estén repartidas — el problema nunca es el cálculo. Lo que
falta es **persistirlo por línea mientras el pedido está abierto**: hoy `OrderItem.discounted_unit_price`
/`discounted_line_total` (columnas ya existentes desde spec 038/089) solo se escriben una vez, en
`cart.service.submit_cart` (canal QR). Los tres caminos que usa la Terminal para armar/editar un
pedido — `orders.service.create_order`, `orders.consolidation.consolidate_table`/`add_item_to_order`
y `orders.kitchen.void_item` — nunca los tocan, por lo que quedan `NULL` en el 100% de las líneas de
Mesas/Domicilios/Para llevar.

El frontend, en cambio, **ya está preparado para consumir ese dato** en los dos puntos que esta spec
corrige: `PosTerminalStore.itemLineTotal()`/`orderSubtotal()` (TOTAL de la tarjeta, Historia 1) y
`PosTerminalStore.persistedLinePromo()` (insignia/tachado del detalle, Historia 2) ya prefieren
`discounted_line_total`/`discounted_unit_price` cuando vienen poblados, y solo caen a una
*estimación* por catálogo cuando no los hay. Por eso el trabajo de esta spec es, en su mayor parte,
de **completar la persistencia que falta, no de reescribir el cálculo ni el consumo**:

1. **Historia 1 (P1, tarjetas)**: nueva función `refresh_order_item_discounts(db, order)`
   (`orders/checkout.py`) que recalcula `discounted_unit_price`/`discounted_line_total` sobre
   **todas** las líneas vigentes del pedido (no solo la que cambió) y las persiste, llamada al final
   de cada mutación de líneas de un pedido abierto: `create_order`, `consolidate_table`,
   `add_item_to_order`, `void_item`. En cuanto esto existe, `orderSubtotal()`/`itemLineTotal()` en
   el frontend quedan correctos **sin ningún cambio de código en ellos** — ya leen ese campo.
2. **Historia 2 (P2, detalle agrupado)**: el mismo dato resuelve el cálculo; falta además que el
   panel de detalle **agrupe visualmente** filas `OrderItem` distintas de la misma
   presentación+opciones+notas en una sola card, igual a como ya agrupa combos
   (`PosTerminalStore.groupByCombo`). Se generaliza `persistedLinePromo()` para operar sobre un
   grupo de filas en vez de una sola, reutilizando la misma fórmula (suma de `unit_price × qty +
   addons_total` vs. suma de `itemLineTotal()`), sin introducir un cálculo nuevo.
3. **Historia 1, Escenario 4 / FR-004 ("Pagos por confirmar")**: investigación confirma que
   `confirm_cash_payment_attempt`/`approve_payment_attempt` (`orders/checkout.py`) y el panel
   `payment-attempt-review-panel.component.ts` **ya validan contra `compute_checkout_preview`**, que
   reusa el mismo motor y ya agrupa entre filas distintas — no hay defecto aquí. Esta parte de la
   spec se cierra con un test de regresión nuevo que cubre exactamente el escenario de adiciones
   sucesivas (ausente hoy), no con código nuevo.

**Sin migración de Alembic** (ver [data-model.md](./data-model.md)): las columnas que esta spec
necesita ya existen desde las specs 038/089. El cambio es de comportamiento de escritura (cuándo se
rellenan), no de esquema.

## Technical Context

**Language/Version**: Python 3.14 (`pos-backend`, sin cambio de versión). TypeScript 5.9 / Angular
21 (`pos-heladeria`, sin cambio).

**Primary Dependencies**: FastAPI 0.136, SQLAlchemy 2.0, Pydantic v2 (backend, sin dependencia
nueva); Angular signals, Vitest (frontend, sin dependencia nueva). Principio IX: no aplica, cero
dependencias nuevas — toda la infraestructura de cálculo (`evaluate_variant_sets`,
`order_sale_lines`, `promo_lines_for`, `compute_checkout_preview`) ya existe.

**Storage**: PostgreSQL 16, esquema por tenant. **Sin cambio de esquema** — reutiliza
`order_items.discounted_unit_price`/`.discounted_line_total` (spec 038/089). Ver
[data-model.md](./data-model.md).

**Testing**: backend `python -m unittest discover -s app/characterization_tests -p 'test_*.py'`
(sesiones SQLite en memoria vía `fixtures.py::new_session`). Frontend `npx ng test --watch=false`
(Vitest). Guía manual en [quickstart.md](./quickstart.md).

**Target Platform**: Linux server (backend, `uvicorn` nativo — no Docker, ver memoria
`reference_pos_api_docker_vs_nativo`) + navegador (Terminal POS de escritorio/tableta).

**Project Type**: web — `pos-backend` + `pos-heladeria`; la spec vive en `pos-specs`.

**Performance Goals**: sin objetivo nuevo de throughput. `refresh_order_item_discounts` ejecuta el
mismo motor (`evaluate_variant_sets`) que ya corre hoy en cada cobro (`pay_order`,
`checkout_and_send`, `compute_checkout_preview`) — la novedad es que también corre en cada
**escritura** de línea (`create_order`, `add_item_to_order`, `consolidate_table`, `void_item`), no
en cada lectura. Deliberadamente **no** se añade a `GET /orders` (el listado que alimenta
Mesas/Domicilios/Para llevar): ese endpoint sigue sin recalcular nada por fila, preservando la
guarda anti-N+1 ya existente (`test_d3_el_listado_devuelve_billing_en_null_en_todos_sus_items`,
`test_orders_billing_summary.py`, y el test frontend que verifica que abrir "Domicilios" no dispara
`checkout-preview` por tarjeta, `pos-terminal.store.spec.ts`) — ver research.md D1.

**Constraints**:
- Principio VII: ninguna factura o venta ya emitida cambia de importe. El recálculo de
  `discounted_unit_price`/`discounted_line_total` solo corre sobre pedidos **abiertos, sin cobrar**
  (`create_order`, `add_item_to_order`, `consolidate_table`, `void_item` operan exclusivamente
  sobre `CustomerOrder` no terminales); `pay_order`/`checkout_and_send`/`Sale` no se tocan.
- El agrupamiento visual de la Historia 2 (FR-008) es puramente de presentación: no fusiona filas
  `OrderItem`, no altera su historial de cocina ni de auditoría.
- El backend sigue siendo la única autoridad del total; ningún total que calcule el frontend viaja
  de vuelta al servidor para cobrar (ya es así hoy — sin cambio de este contrato).

**Scale/Scope**:
- `pos-backend`: `app/api/v1/orders/checkout.py` (nueva `refresh_order_item_discounts`, y
  `line_discount_snapshot` relocada/renombrada desde `cart/service.py::_cart_line_discount`);
  `app/api/v1/cart/service.py` (`submit_cart` pasa a importar `line_discount_snapshot` en vez de
  definirlo); `app/api/v1/orders/service.py` (`create_order`); `app/api/v1/orders/consolidation.py`
  (`consolidate_table`, `add_item_to_order`); `app/api/v1/orders/kitchen.py` (`void_item`);
  characterization tests listados en `research.md`.
- `pos-heladeria`: `app/modules/tables/services/pos-terminal.store.ts` (`persistedItemsView()`:
  nueva agrupación de líneas "planas" por presentación+opciones+notas, análoga a `groupByCombo()`;
  `persistedLinePromo()` generalizada a operar sobre un grupo de filas); sus `.spec.ts`. **Sin
  cambios** en `pos-tables-panel.component.ts`, `order-summary-card.component.ts`,
  `payment-attempt-review-panel.component.ts` (ya correctos, confirmado por código).
- `pos-specs`: sin entrada nueva en `registro-de-anomalias.md` — ningún characterization test
  existente congela el `NULL` que esta spec corrige (research.md D6, verificado por grep); el
  propio `spec.md` ya documenta la corrección (Principio II).
- 2 historias en alcance (P1×1, P2×1) + 1 verificación sin código (Escenario 4 / FR-004).

## Constitution Check

*GATE: debe pasar antes de la Fase 0. Re-evaluado tras la Fase 1 al final de esta sección.*

| Principio | Evaluación |
|---|---|
| I. Las Nuevas Funcionalidades Nacen de un Spec | ✅ Pass — `spec.md` con sesión de clarificaciones (2 preguntas resueltas), 8 FR, 4 SC. |
| II. El Comportamiento Existente Sigue Protegido | ✅ Pass — el propio `spec.md` (encabezado "Naturaleza de esta spec") documenta que es una corrección de comportamiento; research.md D6 confirma por grep que ningún characterization test congela hoy el defecto, así que no hace falta decisión de negocio adicional en `registro-de-anomalias.md`. |
| III. Los Characterization Tests Protegen el Comportamiento Heredado | ✅ Pass — ninguno de los tests `"CONGELA comportamiento actual:"` existentes asume `discounted_unit_price IS NULL` para líneas de Terminal/mesero (research.md D6); no se modifica ningún test protegido, solo se añaden tests nuevos. |
| IV. Los Nuevos Specs Pueden Introducir Nuevo Comportamiento | ✅ Pass — comportamiento nuevo acotado a persistencia de descuento por línea en pedidos abiertos y agrupamiento visual; éxito = SC-001…SC-004. |
| V. Nuevas Funcionalidades Antes que Refactorizaciones Oportunistas | ✅ Pass — la única reubicación de código (`_cart_line_discount` → `line_discount_snapshot` en `checkout.py`) existe porque la función pasa de tener un solo consumidor a tener dos (`cart/service.py` y los tres write-paths de `orders/`); no se toca `evaluate_variant_sets`, `order_sale_lines` ni `promo_lines_for` porque ya son correctos (research.md D1). No se corrige nada del cálculo de combos ni de "Pagos por confirmar" (ya correctos) más allá de agregar cobertura de test. |
| VI. Evolución Incremental | ✅ Pass — dos unidades verificables por separado: (1) persistencia backend del descuento por línea en pedidos abiertos, (2) agrupamiento visual en el detalle. Ninguna requiere migración; no se mezclan con cambios de esquema ni con la corrección de combos (fuera de alcance, spec distinta). |
| VII. Compatibilidad con Datos Históricos | ✅ Pass — ninguna `Sale`/`Invoice` ya emitida se recalcula; el recálculo solo alcanza `OrderItem` de pedidos no terminales. Una línea de un pedido abierto creado **antes** del despliegue queda en `NULL` hasta que una mutación nueva (agregar/anular un ítem) toque ese mismo pedido — ventana transitoria documentada y aceptada en research.md D7, no un backfill masivo (Principio VI: no mezclar una corrección de comportamiento con una migración de datos que la propia spec no pide). |
| VIII. Evolución del Modelo de Datos | ✅ Pass (no aplica) — sin migración; [data-model.md](./data-model.md) documenta por qué no hace falta. |
| IX. Dependencias Nuevas Permitidas con Justificación | ✅ Pass (no aplica) — cero dependencias nuevas. |
| X. Verificación Obligatoria | ✅ Pass (planificado) — [quickstart.md](./quickstart.md) cubre las 2 historias + Escenario 4 (FR-004) + edge cases (promociones mixtas, canales mixtos, vigencia, combos); `research.md` lista los tests nuevos/actualizados. |
| XI. Decisiones de Negocio Frente a Decisiones Técnicas | ✅ Pass — no hay decisión de negocio nueva que tomar (el motor y las reglas de promoción no cambian, solo su persistencia); las decisiones de este plan (dónde ubicar la función compartida, criterio de agrupamiento visual) son técnicas, delegadas por la propia spec a la fase de planeación. |
| XII. Trazabilidad | ✅ Pass — Necesidad (reporte del negocio: discrepancia TOTAL tarjeta vs. cobro real) → spec + clarificaciones (2026-10-14) → este plan → research/data-model/contracts/quickstart → `tasks.md` → tests. |
| XIII. Todo en Español de Colombia | ✅ Pass — todos los artefactos de esta fase en español de Colombia. |
| XIV. Estrategia y Convención de Ramas | ✅ Pass (planificado) — antes de tocar código se crea, desde `develop`, `fix/118-promo-totals-consistency` en `pos-backend` y en `pos-heladeria` (una sola rama por repo: ambas historias comparten los mismos archivos de cálculo/consumo). |
| XV. Política de Commits | ✅ Pass (planificado) — commits pequeños por unidad (función compartida de snapshot; recálculo en los 4 write-paths; agrupamiento visual frontend; tests de regresión de "Pagos por confirmar"), en inglés, Conventional Commits, sin marca de IA, solo cuando el usuario lo pida. |

**Complexity Tracking**: sin violaciones de diseño que justificar — no se añade ningún proyecto,
capa ni dependencia nueva; el cambio reutiliza infraestructura ya construida por specs 038/063/073/089.

**Re-chequeo post Fase 1**: el diseño de la Fase 1 ([data-model.md](./data-model.md),
[contracts/](./contracts/)) confirma que no hace falta ninguna migración ni dependencia nueva, y que
ningún contrato HTTP cambia de forma (solo de valor, en los endpoints ya listados en
[contracts/order-item-discount-snapshot.md](./contracts/order-item-discount-snapshot.md)). Ningún
gate cambia de veredicto.

## Project Structure

### Documentation (this feature)

```text
specs/118-promociones-totales-terminal/
├── plan.md              # Este archivo (/speckit-plan)
├── research.md          # Fase 0 (/speckit-plan)
├── data-model.md         # Fase 1 (/speckit-plan)
├── quickstart.md         # Fase 1 (/speckit-plan)
├── contracts/            # Fase 1 (/speckit-plan)
│   ├── order-item-discount-snapshot.md
│   └── detail-panel-line-grouping.md
└── tasks.md              # Fase 2 (/speckit-tasks — NO se crea en este comando)
```

### Source Code (repository root)

```text
../pos-backend/
├── app/
│   ├── api/v1/
│   │   ├── orders/
│   │   │   ├── checkout.py        # + line_discount_snapshot (relocada), + refresh_order_item_discounts
│   │   │   ├── service.py         # create_order: llama refresh_order_item_discounts antes del commit
│   │   │   ├── consolidation.py   # consolidate_table, add_item_to_order: idem
│   │   │   └── kitchen.py         # void_item: idem (tras anular/reemplazar, antes del commit)
│   │   └── cart/
│   │       └── service.py         # submit_cart: usa line_discount_snapshot importada de orders.checkout
│   └── characterization_tests/
│       ├── test_orders_service.py           # NUEVO: discounted_* persistido en create_order (adiciones sucesivas)
│       ├── test_orders_consolidation.py     # NUEVO: idem en add_item_to_order/consolidate_table
│       ├── test_orders_kitchen.py           # NUEVO: discounted_* se revierte al anular (FR-006)
│       ├── test_orders_payment_gate.py      # NUEVO: confirm_cash/approve con adiciones sucesivas (FR-004, Escenario 4)
│       └── test_cart_service.py             # ACTUALIZAR (import de line_discount_snapshot, sin cambio de comportamiento)
│
../pos-heladeria/
└── src/app/modules/tables/
    ├── services/
    │   ├── pos-terminal.store.ts          # persistedItemsView: agrupar líneas planas por variante+opciones+notas; persistedLinePromo: generalizada a grupo de filas
    │   └── pos-terminal.store.spec.ts     # ACTUALIZAR + nuevo (agrupamiento, TOTAL de tarjeta con adiciones sucesivas)
    └── components/
        └── pos-order-panel.component.spec.ts  # NUEVO caso: una sola card para 2 adiciones sucesivas con promoción
```

**Structure Decision**: web — dos repositorios de código (`pos-backend`, `pos-heladeria`)
consumidos por la spec en `pos-specs`, mismo patrón que specs 073/089/117. Sin tercer proyecto ni
capa nueva: el trabajo reutiliza el motor de promociones y el patrón de snapshot por línea ya
construido por las specs 038/063/073/089, y el patrón de agrupamiento visual que ya existe para
combos (`groupByCombo`).
