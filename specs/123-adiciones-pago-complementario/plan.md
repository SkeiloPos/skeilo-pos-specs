# Implementation Plan: Adiciones a Línea de Pedido Existente con Pago Complementario

**Branch**: `123-adiciones-pago-complementario` | **Date**: 2026-10-17 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/123-adiciones-pago-complementario/spec.md`

## Summary

Hoy **no existe ningún mecanismo para tocar una línea de pedido (`OrderItem`) ya persistida**:
`cart/service.py::add_item`/`update_item` solo operan sobre el carrito pre-pedido, y
`orders/consolidation.py::add_item_to_order` siempre inserta un `OrderItem` nuevo — nunca agrega
una opción/adición a una fila existente (confirmado por código, `research.md` D1). Tampoco existe
ninguna relación entre dos `Sale` (no hay `parent_sale_id` ni equivalente), ni el concepto de
"saldo pendiente" o "pago complementario" en ningún repositorio (grep limpio en `pos-backend` y
`pos-heladeria`). Esta spec es, por tanto, trabajo nuevo sobre infraestructura existente, no un
recableo como la spec 117:

1. **Historias 1/2/4 (P1/P2 — agregar adición post-hoc)**: nuevo endpoint que inserta una fila
   `OrderItemOption` sobre un `OrderItem` ya creado, reutilizando el motor de precio existente
   (`OrderItem.line_total` ya suma `unit_price × quantity + addons_total` — no se toca,
   `research.md` D1). Dos columnas nuevas en `order_item_options` (`added_after_sale`,
   `complementary_sale_id`) distinguen, sin tocar ninguna fila histórica, qué adiciones nacieron
   después de que el pedido ya tenía una `Sale` emitida y si ya fueron cubiertas por un pago
   complementario (`data-model.md`).
2. **Historia 2/3 (P1 — saldo pendiente y pago complementario)**: el "saldo pendiente" es un valor
   **calculado**, no una columna — suma de `OrderItemOption` con `added_after_sale=True` y
   `complementary_sale_id IS NULL` de líneas no anuladas del pedido (mismo patrón que
   `has_billable_orders`, que tampoco persiste nada). El pago complementario reutiliza
   `sales/builder.py::build_sale` con un nuevo parámetro `kind='complementario'` (columna nueva
   `sales.kind`, spec de migración en `data-model.md`), generando una `Sale` nueva vinculada por el
   `customer_order_id` ya existente — nunca se reescribe la `Sale` original (Principio VII).
3. **Historia 3/4 (P1/P2 — atomicidad + gating por plan)**: el cobro complementario es una sola
   transacción: si el tenant tiene el módulo de inventario (`ensure_module_access`, spec 033) y
   falta stock de cualquier insumo cubierto, se aborta completo (409, sin cobrar nada); si el
   tenant no tiene el módulo, se omite el chequeo/descuento por completo (`research.md` D5). La
   regla "un solo método de pago" (spec 046) hoy es **solo convención de frontend** — el esquema
   Pydantic permite hasta 3 pagos y no hay guard de backend (`research.md` D3) — así que el nuevo
   endpoint agrega su propia validación explícita `len(payments) == 1`, sin tocar `pay_order` ni
   `checkout_and_send`.
4. **Historia 5 (P2 — bloqueo de "Liberar Mesa")**: nueva función `has_pending_balance`, hermana de
   `has_billable_orders` (misma función, mismo archivo, `table_sessions/service.py`), invocada
   dentro de `release_paid_session` justo después del chequeo existente.
5. **Historia 6 (P3 — tiempo real)**: nuevo tipo de evento `order.item_addon_added` sobre el
   despachador ya construido por la spec 077 (`app/core/events.py::publish`), siguiendo el molde
   exacto de `item_kitchen_changed` — ningún canal, transporte ni dependencia nueva.

## Technical Context

**Language/Version**: Python 3.14.4 (`pos-backend`, sin cambio de versión). TypeScript 5.9.2 /
Angular 21.1 (`pos-heladeria`, sin cambio).

**Primary Dependencies**: FastAPI 0.136.3, SQLAlchemy 2.0.50, Pydantic 2.13.4, Alembic 1.18.4
(backend, sin dependencia nueva); Angular signals, Vitest 4.0.8 (frontend, sin dependencia nueva).
Principio IX: no aplica, cero dependencias nuevas — toda la funcionalidad reutiliza motores ya
existentes (`catalog_engine`, `app/core/events.py`, `sales/builder.py`).

**Storage**: PostgreSQL 16, esquema por tenant. **Dos migraciones additivas** (ver
[data-model.md](./data-model.md)):
`order_item_options` gana `added_after_sale boolean NOT NULL DEFAULT false` y
`complementary_sale_id uuid NULL REFERENCES sales(id)`; `sales` gana
`kind varchar NOT NULL DEFAULT 'original' CHECK (kind IN ('original','complementario'))`. Ambas con
default que preserva el significado histórico de cada fila existente (Principio VII/VIII) y
rollback trivial (`DROP COLUMN`).

**Testing**: backend `python -m unittest discover -s app/characterization_tests -p 'test_*.py'`
(sesiones SQLite en memoria vía `fixtures.py::new_session`). Frontend `npx ng test --watch=false`
(Vitest). Guía en [quickstart.md](./quickstart.md).

**Target Platform**: Linux server (backend, `uvicorn` nativo) + navegador (Terminal POS de
escritorio/tableta; cocina se opera desde la misma Terminal, spec 009 FR-033 — no hay KDS
separado).

**Project Type**: web — `pos-backend` + `pos-heladeria`; la spec vive en `pos-specs`.

**Performance Goals**: sin objetivo nuevo. El cómputo de saldo pendiente es una suma sobre, como
máximo, decenas de filas `OrderItemOption` por pedido (mismo orden de magnitud que
`has_billable_orders`, que ya recorre todas las órdenes de una sesión de mesa).

**Constraints**:
- Principio VII: ninguna `Sale`/factura ya emitida se modifica, recalcula ni reemite al agregar
  una adición posterior (`FR-007`); la factura complementaria es siempre una `Sale` nueva e
  independiente (`FR-011`).
- `FR-020`: el cobro complementario es atómico — stock insuficiente de cualquier insumo cubierto
  aborta el cobro completo, nunca cobra una parte.
- `FR-021`: la validación/descuento de stock solo corre si `ensure_module_access(db, tenant,
  "inventario")` no levanta 403 — gating por plan (spec 033), no por código hardcodeado.
- `FR-018`: el pago complementario exige `len(payments) == 1` — validación nueva de backend, no
  heredada (hoy `pay_order`/`checkout_and_send` no la exigen a nivel de esquema).
- El backend sigue siendo la autoridad final del saldo pendiente y de la validez del cobro —
  ningún monto enviado por el cliente se acepta sin recalcular contra las filas
  `OrderItemOption` pendientes reales.

**Scale/Scope**:
- `pos-backend`: `app/models/order_item.py` (`OrderItemOption`: +2 columnas); `app/models/sale.py`
  (`Sale`: +1 columna `kind`); migración Alembic nueva; `app/api/v1/orders/consolidation.py` o
  nuevo módulo (`orders/additions.py`) para el endpoint de agregar adición; `app/api/v1/sales/
  builder.py` (`build_sale`: + parámetro `kind`); `app/api/v1/orders/checkout.py` o nuevo módulo
  para el endpoint de cobro complementario; `app/api/v1/table_sessions/service.py`
  (`has_pending_balance`, invocada en `release_paid_session`); `app/core/plan_limits.py`
  (`ensure_module_access`, reusado sin cambios); `app/api/v1/orders/consumption.py`
  (+ `deduct_addition`, nueva — descuenta solo la adición, nunca la receta base ya descontada al
  crear la línea, research.md D9; `check_availability` reusado con el mismo filtro);
  `app/core/events.py` (+ `item_addon_added`); characterization tests listados en `research.md`.
- `pos-heladeria`: `src/app/modules/tables/components/pos-order-panel.component.ts` (botón
  "Agregar adición" junto a "Marcar listo"/"Anular"); `pos-checkout-panel.component.ts` (bloque de
  "Saldo pendiente" + botón "Cobrar saldo", condicionado como ya lo están "Imprimir
  Factura"/"Liberar Mesa"); `pos-terminal.store.ts` (`connectRealtime()`: suscripción a
  `order.item_addon_added`; nuevas acciones `addAddition`/`settlePendingBalance`); `table-session.
  service.ts` (nuevo método de cobro complementario); `.spec.ts` correspondientes.
- `pos-specs`: no se requiere registro en `registro-de-anomalias.md` — esta spec no reabre ni
  modifica ningún comportamiento protegido, solo agrega capacidad nueva (Principio IV).
- 6 historias en alcance (P1×3, P2×2, P3×1).

## Constitution Check

*GATE: debe pasar antes de la Fase 0. Re-evaluado tras la Fase 1 al final de esta sección.*

| Principio | Evaluación |
|---|---|
| I. Las Nuevas Funcionalidades Nacen de un Spec | ✅ Pass — `spec.md` con sesión de clarificaciones (2026-10-17, 2 preguntas), 22 FR, 9 SC. |
| II. El Comportamiento Existente Sigue Protegido | ✅ Pass — no reabre ningún comportamiento vigente; todas las rutas y modelos existentes (`add_item_to_order`, `pay_order`, `release_paid_session`, `build_sale`) quedan intactos, solo se les agregan guardas/funciones nuevas. |
| III. Los Characterization Tests Protegen el Comportamiento Heredado | ✅ Pass — ningún test `"CONGELA comportamiento actual:"` listado en `research.md` se modifica; el dominio es greenfield (confirmado por grep: cero tests existentes mencionan `addons_total` + `Sale` ya emitida simultáneamente). |
| IV. Los Nuevos Specs Pueden Introducir Nuevo Comportamiento | ✅ Pass — comportamiento enteramente nuevo (agregar adición post-hoc, saldo pendiente, pago/factura complementaria), sin pretender equivalencia con nada anterior. |
| V. Nuevas Funcionalidades Antes que Refactorizaciones Oportunistas | ✅ Pass — no se corrigen las 3 implementaciones fragmentadas de "cuánto se le debe cobrar a esta mesa" (contradicción 06, fuera de esta spec); no se toca el endpoint legado `checkout.release_table` (no cableado en frontend) más allá de documentar la decisión de no extenderlo (`research.md` D6); no se endurece `pay_order`/`checkout_and_send` a `len(payments)==1` aunque comparten la misma ambigüedad — la nueva validación solo aplica al endpoint nuevo. |
| VI. Evolución Incremental | ✅ Pass — 3 unidades verificables por separado: (1) agregar adición + recálculo normal (pedido sin pagar), (2) saldo pendiente + cobro complementario atómico + gating por plan, (3) bloqueo de "Liberar Mesa" + evento de tiempo real. Cada una tiene su propia migración/endpoint/test sin mezclarse. |
| VII. Compatibilidad con Datos Históricos | ✅ Pass — ninguna `Sale`/`OrderItemOption` existente cambia de valor; las columnas nuevas nacen con default que reproduce el significado histórico (`kind='original'`, `added_after_sale=false`) sin excepción. |
| VIII. Evolución del Modelo de Datos | ✅ Pass — [data-model.md](./data-model.md) documenta las 2 migraciones additivas, sus defaults, compatibilidad con filas existentes, y rollback (`DROP COLUMN`, sin pérdida de datos de negocio porque son columnas nuevas). |
| IX. Dependencias Nuevas Permitidas con Justificación | ✅ Pass (no aplica) — cero dependencias nuevas; reutiliza `catalog_engine`, `events.py`, `sales/builder.py`. |
| X. Verificación Obligatoria | ✅ Pass (planificado) — [quickstart.md](./quickstart.md) cubre las 6 historias; `research.md` lista los characterization tests nuevos y los que deben seguir intactos. |
| XI. Decisiones de Negocio Frente a Decisiones Técnicas | ✅ Pass — las decisiones de negocio (acumular en un solo saldo, atomicidad del cobro, gating por plan, ciclos repetidos) están en `spec.md` (FR-015, FR-020, FR-021, FR-022); este plan solo resuelve el "cómo" (columnas nuevas, endpoints, reutilización de `build_sale`). |
| XII. Trazabilidad | ✅ Pass — Necesidad (cajero no puede atender un pedido adicional sin anular y recrear) → spec + clarificaciones (2026-10-17) → este plan → research/data-model/contracts/quickstart → `tasks.md` → tests. |
| XIII. Todo en Español de Colombia | ✅ Pass — todos los artefactos de esta fase en español de Colombia. |
| XIV. Estrategia y Convención de Ramas | ✅ Pass (planificado) — antes de tocar código se crea, desde la rama actual, `feat/123-adiciones-pago-complementario` en `pos-backend` y en `pos-heladeria` (una sola rama por repo: todas las historias comparten el mismo dominio OrderItem/Sale). |
| XV. Política de Commits | ✅ Pass (planificado) — commits pequeños por unidad (migraciones + modelo; endpoint de agregar adición; endpoint de cobro complementario + gating; bloqueo de Liberar Mesa; evento tiempo real; frontend), en inglés, Conventional Commits, sin marca de IA, solo cuando el usuario lo pida. |

**Complexity Tracking**: sin violaciones que justificar — ningún proyecto, capa ni dependencia
nueva; dos columnas additivas y dos endpoints nuevos sobre módulos ya existentes.

**Re-chequeo post Fase 1**: el diseño de la Fase 1 ([data-model.md](./data-model.md),
[contracts/](./contracts/)) confirma que las dos migraciones son additivas y reversibles, que
ningún contrato HTTP existente cambia de forma (solo se agregan endpoints y un campo opcional
`pending_balance` de solo lectura en la respuesta de cuenta de mesa), y que la atomicidad del
cobro complementario se resuelve dentro de una sola transacción de base de datos sin necesitar
una tabla de "intentos" adicional. Ningún gate cambia de veredicto.

## Project Structure

### Documentation (this feature)

```text
specs/123-adiciones-pago-complementario/
├── plan.md               # Este archivo (/speckit-plan)
├── research.md           # Fase 0 (/speckit-plan)
├── data-model.md          # Fase 1 (/speckit-plan)
├── quickstart.md          # Fase 1 (/speckit-plan)
├── contracts/             # Fase 1 (/speckit-plan)
│   ├── add-addition-to-order-item.md
│   ├── pending-balance-exposure.md
│   ├── complementary-payment.md
│   ├── release-table-pending-balance-gate.md
│   └── realtime-item-addon-added-event.md
└── tasks.md               # Fase 2 (/speckit-tasks — NO se crea en este comando)
```

### Source Code (repository root)

```text
../pos-backend/
├── app/
│   ├── models/
│   │   ├── order_item.py                  # OrderItemOption: + added_after_sale, complementary_sale_id
│   │   └── sale.py                         # Sale: + kind ('original' | 'complementario')
│   ├── alembic/versions/
│   │   └── XXXX_add_addition_tracking_and_sale_kind.py  # Migración nueva (ver data-model.md)
│   ├── catalog_engine/
│   │   ├── pricing.py                      # check_availability: reusado, sin cambios de firma (required acotado a source != "receta")
│   │   └── consumption.py                  # plan_line_consumption: reusado sin cambios (solo lectura)
│   ├── api/v1/
│   │   ├── orders/
│   │   │   ├── additions.py                # NUEVO — add_addition_to_order_item (Historia 1/2/4); descuenta vía deduct_addition si pedido sin pagar
│   │   │   ├── consumption.py               # + deduct_addition (research.md D9) — descuenta solo la adición, nunca la receta base (source != "receta")
│   │   │   ├── schemas.py                  # + AddAdditionIn, PendingBalanceOut
│   │   │   ├── kitchen.py                  # Sin cambios (estado_cocina ya expone EN_CURSO)
│   │   │   └── checkout.py                 # Sin cambios (pay_order/checkout_and_send no se tocan)
│   │   ├── sales/
│   │   │   ├── builder.py                  # build_sale: + parámetro kind='original'|'complementario'
│   │   │   └── complementary.py            # NUEVO — settle_pending_balance (Historia 3); descuenta vía deduct_addition (research.md D9), nunca deduct_order_items
│   │   ├── table_sessions/
│   │   │   └── service.py                  # + has_pending_balance; release_paid_session: + guarda nueva; compute_bill: + pending_balance
│   │   └── cash/
│   │       └── service.py                  # Sin cambios (reconcile ya deriva de Sale/Payment)
│   ├── core/
│   │   ├── events.py                        # + item_addon_added(...)
│   │   └── plan_limits.py                   # ensure_module_access: reusado sin cambios
│   └── characterization_tests/
│       ├── test_orders_additions.py                 # NUEVO
│       ├── test_sales_complementary_payment.py       # NUEVO
│       ├── test_table_sessions_service.py            # ACTUALIZAR (+ has_pending_balance, release 409 nuevo)
│       └── test_plan_module_access.py                # ACTUALIZAR (+ caso: cobro complementario sin módulo inventario)
│
../pos-heladeria/
└── src/app/modules/tables/
    ├── components/
    │   ├── pos-order-panel.component.ts            # + botón "Agregar adición" (estado_cocina en EN_CURSO)
    │   ├── pos-order-panel.component.spec.ts        # ACTUALIZAR + nuevo
    │   ├── pos-checkout-panel.component.ts          # + bloque "Saldo pendiente" / botón "Cobrar saldo"
    │   └── pos-checkout-panel.component.spec.ts      # ACTUALIZAR + nuevo
    ├── services/
    │   ├── pos-terminal.store.ts                     # + addAddition/settlePendingBalance; connectRealtime(): + 'order.item_addon_added'
    │   ├── pos-terminal.store.spec.ts                 # ACTUALIZAR + nuevo
    │   ├── table-session.service.ts                   # + settlePendingBalance()
    │   └── table-session.service.spec.ts               # ACTUALIZAR + nuevo
    └── interfaces/
        └── dining.interface.ts                        # + PendingBalance, AdditionInput
```

**Structure Decision**: web — dos repositorios de código (`pos-backend`, `pos-heladeria`)
consumidos por la spec en `pos-specs`, mismo patrón que specs 065/089/117. Sin tercer proyecto ni
capa nueva: el trabajo agrega dos módulos de servicio puntuales (`orders/additions.py`,
`sales/complementary.py`) sobre la arquitectura ya existente (`catalog_engine`, `sales/builder.py`,
`app/core/events.py`), siguiendo el mismo patrón de "función hermana" que `has_billable_orders` →
`has_pending_balance`.
