# Implementation Plan: Cantidad de adiciones como total de línea, no multiplicador por producto

**Branch**: `117-adiciones-cantidad-total-linea` | **Date**: 2026-10-13 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/117-adiciones-cantidad-total-linea/spec.md`

## Summary

El motor de pricing (`catalog_engine/core.py`) y de consumo (`catalog_engine/consumption.py`) ya
implementan exactamente la fórmula que esta spec necesita — fue construido por la spec 089 bajo el
nombre `per_line`, pero atado al eje equivocado: hoy solo se activa para opciones de grupos
`pricing_type = 'con_recargo'` agregadas desde el carrito del Menú QR, no para grupos
`selection_mode = 'cantidad'` (spec 065) en cualquier canal. El trabajo de esta spec es, por
tanto, principalmente de **recableo**, no de reescribir fórmulas:

1. **Historia 1/2 (P1)**: `per_line` pasa a activarse también cuando `option_group.selection_mode
   == 'cantidad'`, sin importar canal ni `pricing_type` — union con la condición 089 existente, que
   no se toca (así "Conteo" no cambia, `FR-013`). Se recablean los 4 call-sites que hoy construyen
   la línea con `compute_line_price` "folded" (`orders/consolidation.py::add_item_to_order`,
   `orders/service.py::create_order`, `sales/service.py::checkout`, `orders/kitchen.py` reemplazo)
   para que separen `unit_price`/`addons_total` como ya hace `cart/service.py`. Nada en
   `core.py`/`consumption.py` cambia: ambos ya resuelven correctamente `per_line = True` para
   pricing (`FR-002`) y para inventario (`FR-007`), sin tocarlos.
2. **Historia 3 (P2)**: los topes `max_quantity_per_option`/`max_total_quantity` (spec 065) se
   escalan por la cantidad de producto al validar (`validate_option_selection` gana un parámetro
   `quantity`). El único camino de backend donde puede reducirse la cantidad de una línea **ya
   creada** con adiciones ya elegidas es `cart/service.py::update_item` (confirmado por código,
   `research.md` D3) — ahí se añade el algoritmo determinista de reducción automática (orden
   alfabético descendente por nombre de opción, `research.md` D4) y un campo de respuesta aditivo
   `adjusted_options` para el aviso (`research.md` D5). En Terminal POS y en el modal de selección
   el caso equivalente es 100% frontend (líneas aún no enviadas al backend).
3. **Historia 4 (P2)**: la comanda ya muestra la cantidad de la opción tal cual se guardó
   (spec 065 `FR-010`) — se verifica con un test, no se cambia código de formato.
4. **Frontend**: `ProductSelectComponent.lineTotal()` y `PosTerminalStore` dejan de usar
   `addonsPerLine` como bandera fija por canal; deciden por cada opción elegida según el
   `selection_mode` de su grupo (mismo OR que en backend, `research.md` D6).

**Sin migración de Alembic** (ver [data-model.md](./data-model.md)): las cuatro piezas de esquema
necesarias (`per_line`, `addons_total`, `max_quantity_per_option`, `max_total_quantity`) ya
existen desde las specs 065 y 089.

## Technical Context

**Language/Version**: Python 3.14 (`pos-backend`, sin cambio de versión). TypeScript 5.9 /
Angular 21 (`pos-heladeria`, sin cambio).

**Primary Dependencies**: FastAPI 0.136, SQLAlchemy 2.0, Pydantic v2, Alembic (backend, sin
dependencia nueva); Angular signals, Vitest (frontend, sin dependencia nueva). Principio IX: no
aplica, cero dependencias nuevas.

**Storage**: PostgreSQL 16, esquema por tenant. **Sin cambio de esquema** — reutiliza columnas ya
existentes de spec 065 (`option_groups.selection_mode`, `.max_quantity_per_option`,
`.max_total_quantity`) y spec 089 (`cart_items`/`order_items.addons_total`,
`cart_item_options`/`order_item_options.per_line`). Ver [data-model.md](./data-model.md).

**Testing**: backend `python -m unittest discover -s app/characterization_tests -p 'test_*.py'`
(sesiones SQLite en memoria vía `fixtures.py::new_session`). Frontend `npx ng test --watch=false`
(Vitest). Guía en [quickstart.md](./quickstart.md).

**Target Platform**: Linux server (backend, `uvicorn` nativo — no Docker, ver memoria
`reference_pos_api_docker_vs_nativo`) + navegador (Terminal POS de escritorio/tableta, Menú QR
móvil).

**Project Type**: web — `pos-backend` + `pos-heladeria`; la spec vive en `pos-specs`.

**Performance Goals**: sin objetivo nuevo — el cálculo sigue siendo una suma por opción de la
línea, mismo orden de magnitud que hoy. El algoritmo de reducción automática (Historia 3) opera
sobre, como máximo, las opciones de un solo grupo de una sola línea (decenas, no miles).

**Constraints**:
- Principio VII: ninguna línea, pedido, venta o factura confirmados antes de esta funcionalidad
  cambia de total, cantidad de adición o consumo de inventario ya registrado (`FR-012`, `SC-005`).
- `FR-013`: el cálculo de "Conteo" (spec 004) no cambia en ningún canal, incluida la diferencia ya
  existente entre canal QR y Terminal para grupos "Conteo" con recargo (spec 089) — no se corrige
  aquí (Principio V: no es el problema que esta spec ataca).
- El backend es siempre la autoridad final del total (`FR-009`); ningún total enviado por el
  cliente (POS o QR) se acepta sin recalcular.

**Scale/Scope**:
- `pos-backend`: `app/catalog_engine/pricing.py` (`validate_option_selection`,
  `load_valid_options`: parámetro `quantity`); `app/api/v1/cart/service.py` (`add_item`,
  `update_item`: marcar `per_line` por `selection_mode`, algoritmo de reducción automática);
  `app/api/v1/cart/schemas.py` (`AdjustedOptionOut`, `CartItemResponse.adjusted_options`);
  `app/api/v1/orders/consolidation.py` (`add_item_to_order`); `app/api/v1/orders/service.py`
  (`create_order`); `app/api/v1/sales/service.py` (`checkout`); `app/api/v1/orders/kitchen.py`
  (reemplazo de ítem anulado); characterization tests listados en `research.md`.
- `pos-heladeria`: `app/modules/tables/components/product-select.component.ts` (`lineTotal()`,
  `canIncrement()`, nuevo efecto de reducción automática al bajar cantidad); `pos-terminal.store.ts`
  (`addDraftFromSelection`, `cartView`, `decDraft`); `dining-cart.service.ts` (`setQuantity`: leer
  `adjusted_options` de la respuesta); interfaces de `product.interface.ts`/`dining.interface.ts`
  si exponen el nuevo campo; `.spec.ts` correspondientes.
- `pos-specs`: registro de la decisión de negocio en
  `specs/000-reconocimiento/registro-de-anomalias.md` (tarea de `tasks.md`, no de este plan — ver
  `research.md` D8).
- 4 historias en alcance (P1×2, P2×2); Historia 5 original (devolución parcial) ya retirada por
  la spec antes de esta fase.

## Constitution Check

*GATE: debe pasar antes de la Fase 0. Re-evaluado tras la Fase 1 al final de esta sección.*

| Principio | Evaluación |
|---|---|
| I. Las Nuevas Funcionalidades Nacen de un Spec | ✅ Pass — `spec.md` con una sesión de clarificaciones (5 preguntas resueltas), 13 FR, 5 SC. |
| II. El Comportamiento Existente Sigue Protegido | ⚠️ Pass **condicionado** — reabre deliberadamente `RN-CAT-01` solo para grupos "cantidad", decisión ya documentada en `spec.md` (sesión 2026-10-13); falta solo el registro formal en `registro-de-anomalias.md`, que es trabajo de `tasks.md` (research.md D8), igual que A-94 lo fue de la spec 089. |
| III. Los Characterization Tests Protegen el Comportamiento Heredado | ⚠️ Pass **condicionado** — se actualizan explícitamente, citando esa decisión, los tests que hoy congelan el *bug* (`test_catalog_option_groups_quantity.py`, listados en `research.md`); los que congelan "Conteo" y el canal QR de la spec 089 **no se tocan**. |
| IV. Los Nuevos Specs Pueden Introducir Nuevo Comportamiento | ✅ Pass — comportamiento nuevo acotado a grupos "cantidad"; éxito = SC-001…SC-005. |
| V. Nuevas Funcionalidades Antes que Refactorizaciones Oportunistas | ✅ Pass — no se corrige la inconsistencia preexistente entre canal QR y Terminal para "Conteo" con recargo (spec 089, fuera de esta spec); no se toca `catalog_engine/core.py` ni `consumption.py` porque ya implementan la fórmula correcta (research.md D1/D7) — recablear, no reescribir. |
| VI. Evolución Incremental | ✅ Pass — tres unidades verificables por separado: (1) pricing/consumo (`per_line` por `selection_mode`), (2) topes escalados, (3) ajuste automático + aviso. Ninguna requiere migración; no se mezclan con cambios de esquema. |
| VII. Compatibilidad con Datos Históricos | ✅ Pass — ninguna fila existente se reescribe; el cambio de regla solo decide qué pasa al crear/editar una línea nueva (igual que la spec 089 sobre las mismas columnas). Test explícito de que una línea histórica no cambia (`SC-005`). |
| VIII. Evolución del Modelo de Datos | ✅ Pass (no aplica) — sin migración; [data-model.md](./data-model.md) documenta explícitamente por qué no hace falta. |
| IX. Dependencias Nuevas Permitidas con Justificación | ✅ Pass (no aplica) — cero dependencias nuevas. |
| X. Verificación Obligatoria | ✅ Pass (planificado) — [quickstart.md](./quickstart.md) cubre las 4 historias + regresión de "Conteo"; `research.md` lista los characterization tests a actualizar. |
| XI. Decisiones de Negocio Frente a Decisiones Técnicas | ✅ Pass — la decisión de negocio (reabrir `RN-CAT-01` para "cantidad") está en `spec.md`; este plan solo resuelve el "cómo" (criterio de reducción D4, formato del aviso D5), explícitamente delegado a planeación por la propia sección "Assumptions" de la spec. |
| XII. Trazabilidad | ✅ Pass — Necesidad (reporte del negocio, "2 granizados cobran 2 gomitas") → spec + clarificaciones (2026-10-13) → este plan → research/data-model/contracts/quickstart → `tasks.md` (incluye el registro de la decisión) → tests. |
| XIII. Todo en Español de Colombia | ✅ Pass — todos los artefactos de esta fase en español de Colombia. |
| XIV. Estrategia y Convención de Ramas | ✅ Pass (planificado) — antes de tocar código se crea, desde `develop`, `feat/117-addons-quantity-line-total` en `pos-backend` y en `pos-heladeria` (una sola rama por repo: las tres historias en alcance comparten los mismos archivos de pricing). |
| XV. Política de Commits | ✅ Pass (planificado) — commits pequeños por unidad (motor de marcado `per_line`; topes escalados; algoritmo de reducción automática + contrato de respuesta; frontend), en inglés, Conventional Commits, sin marca de IA, solo cuando el usuario lo pida. |

**Complexity Tracking**: sin violaciones de diseño que justificar — no se añade ningún proyecto,
capa ni dependencia nueva; el cambio reutiliza infraestructura ya construida por specs 065/089.

**Re-chequeo post Fase 1**: el diseño de la Fase 1 ([data-model.md](./data-model.md),
[contracts/](./contracts/)) confirma que no hace falta ninguna migración ni dependencia nueva. El
único artefacto nuevo es un campo de respuesta aditivo (`adjusted_options`), que no cambia el tipo
ni elimina ningún campo existente en ningún contrato HTTP — ningún gate cambia de veredicto.

## Project Structure

### Documentation (this feature)

```text
specs/117-adiciones-cantidad-total-linea/
├── plan.md              # Este archivo (/speckit-plan)
├── research.md          # Fase 0 (/speckit-plan)
├── data-model.md         # Fase 1 (/speckit-plan)
├── quickstart.md         # Fase 1 (/speckit-plan)
├── contracts/            # Fase 1 (/speckit-plan)
│   ├── line-pricing-per-line-cantidad.md
│   ├── option-selection-validation.md
│   └── cart-item-auto-adjust.md
└── tasks.md              # Fase 2 (/speckit-tasks — NO se crea en este comando)
```

### Source Code (repository root)

```text
../pos-backend/
├── app/
│   ├── catalog_engine/
│   │   ├── core.py                        # Sin cambios (ya correcto para per_line=True)
│   │   ├── consumption.py                 # Sin cambios (ya correcto para per_line=True)
│   │   └── pricing.py                     # validate_option_selection/load_valid_options: + quantity, topes escalados
│   ├── api/v1/
│   │   ├── cart/
│   │   │   ├── schemas.py                 # + AdjustedOptionOut, CartItemResponse.adjusted_options
│   │   │   └── service.py                 # add_item/update_item: per_line por selection_mode; algoritmo de reducción automática
│   │   ├── orders/
│   │   │   ├── consolidation.py           # add_item_to_order: separar unit_price/addons_total
│   │   │   ├── service.py                 # create_order: idem
│   │   │   └── kitchen.py                 # reemplazo de ítem anulado: idem
│   │   └── sales/
│   │       └── service.py                 # checkout: idem
│   └── characterization_tests/
│       ├── test_catalog_line_pricing.py             # ACTUALIZAR
│       ├── test_catalog_consumption_plan.py         # ACTUALIZAR
│       ├── test_catalog_option_groups_quantity.py   # ACTUALIZAR (cita la decisión de negocio)
│       ├── test_catalog_option_groups_selection_mode.py  # ACTUALIZAR (topes escalados)
│       ├── test_cart_service.py                     # ACTUALIZAR + nuevo (ajuste automático)
│       ├── test_orders_consolidation.py             # ACTUALIZAR
│       └── test_orders_service.py                   # ACTUALIZAR
│
../pos-heladeria/
└── src/app/modules/
    ├── products/interfaces/product.interface.ts     # (si hace falta exponer algo nuevo del grupo)
    └── tables/
        ├── components/
        │   ├── product-select.component.ts          # lineTotal()/canIncrement(): por selection_mode; efecto de reducción al bajar cantidad
        │   └── product-select.component.spec.ts     # ACTUALIZAR + nuevo
        ├── services/
        │   ├── pos-terminal.store.ts                 # addDraftFromSelection/cartView/decDraft: por selection_mode
        │   ├── pos-terminal.store.spec.ts            # ACTUALIZAR + nuevo
        │   ├── dining-cart.service.ts                # setQuantity: leer adjusted_options
        │   └── dining-cart.service.spec.ts           # ACTUALIZAR + nuevo
        └── interfaces/dining.interface.ts            # + AdjustedOption (tipo espejo del backend)

../pos-specs/
└── specs/000-reconocimiento/registro-de-anomalias.md  # + entrada de decisión de negocio (tarea de tasks.md)
```

**Structure Decision**: web — dos repositorios de código (`pos-backend`, `pos-heladeria`) consumidos
por la spec en `pos-specs`, mismo patrón que specs 065/089. Sin tercer proyecto ni capa nueva: el
trabajo reutiliza el motor de pricing/consumo existente (`catalog_engine/`) y el patrón de campo
aditivo en respuesta ya usado por `OrderBillingSummary` (spec 094) para el aviso de ajuste.
