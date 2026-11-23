# Implementation Plan: División automática de cuenta por ítem

**Branch**: `164-division-automatica-cuenta` | **Date**: 2026-11-21 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/164-division-automatica-cuenta/spec.md`

## Summary

Hoy el backend (`pos-backend`) ya soporta cobro independiente por orden dentro de una mesa
(spec 156) y primitivas de movimiento/fusión **a nivel de orden completa**
(`POST /orders/{order_id}/move`, `POST /orders/merge`), pero no existe ninguna operación que
mueva o divida **ítems individuales** entre órdenes de la misma mesa. Esta feature agrega esa
capacidad faltante:

1. **Dividir cuenta** (`POST /orders/{order_id}/split`): convierte cada línea (`OrderItem`) de
   una orden sin pago registrado en una `CustomerOrder` nueva independiente, y elimina la
   orden original.
2. **Mover ítem** (`POST /orders/{order_id}/items/{item_id}/move`): mueve una línea (completa o
   una cantidad parcial) hacia una orden destino existente de la misma mesa, fusionando con una
   línea compatible si existe (mismo producto+variante+precio+`estado_cocina`) o creando una
   línea nueva si no.
3. **Crear cuenta nueva desde un ítem** (`POST /orders/{order_id}/items/{item_id}/split-to-new`):
   igual que mover, pero el destino es una `CustomerOrder` nueva en la misma mesa en vez de una
   existente.

Las tres operaciones comparten las mismas reglas de guardia: ninguna orden involucrada puede
tener `payment_status == PAID` ni una `Sale` asociada (reutilizando `order_has_sale`), y
cualquier orden que quede con cero `OrderItem` tras la operación se elimina de inmediato. En el
frontend (`pos-heladeria`), se agrega un botón "Dividir cuenta" junto a cada pestaña de orden en
`pos-order-panel.component.ts`, y una acción por ítem ("Mover a cuenta…" / "Nueva cuenta") en la
fila de cada línea, reutilizando el patrón ya existente de "Nueva cuenta" (línea 283-291) para la
construcción de la UI de selección de orden destino.

## Technical Context

**Language/Version**: Backend: Python 3.11 (FastAPI). Frontend: TypeScript 5.x (Angular,
standalone components + signals, consistente con `pos-order-panel.component.ts` y
`pos-terminal.store.ts`).

**Primary Dependencies**: Backend: FastAPI, SQLAlchemy 2.x, Alembic, PostgreSQL 16
(schema-per-tenant). Frontend: Angular, RxJS, señales de Angular (`signal`/`computed`), sin
dependencias nuevas.

**Storage**: PostgreSQL 16, esquema por tenant. No se requieren tablas nuevas; la feature opera
sobre `customer_orders` y `order_items` ya existentes (ver `data-model.md`).

**Testing**: Backend: `unittest` bajo `app/characterization_tests/` (ejecutable también vía
pytest), siguiendo el patrón de `test_orders_tables_advanced.py` y
`app/characterization_tests/orders_fixtures.py` para fixtures de tenant/mesa/orden. Frontend: no
se identificaron specs Angular existentes para `pos-order-panel.component.ts`; se seguirá el
patrón de pruebas unitarias Angular ya usado en el módulo `tables` cuando exista, documentado en
memoria (`angular-query-test-settling`) para componentes con query/signals.

**Target Platform**: Servidor Linux (API) + navegador (terminal de mesas Angular).

**Project Type**: Web application (backend API + frontend SPA ya existentes; Option 2 del
template).

**Performance Goals**: Alineado con SC-001/SC-003/SC-004 del spec: cada operación (dividir,
mover, crear cuenta nueva) debe completarse y reflejarse en la UI en menos de 5 s, 3 s y 10 s
respectivamente — tiempos dominados por la latencia de red/UI, no por cómputo (son operaciones
de una sola transacción SQL sobre un número pequeño de filas por mesa).

**Constraints**: Debe respetar el Principio VII (no tocar facturas/ventas emitidas: las
operaciones solo son posibles antes de que exista una `Sale`/`payment_status=PAID`) y el
Principio VIII (cualquier cambio de esquema, si lo hay, debe documentar compatibilidad y
rollback). No se introduce ningún permiso o rol nuevo (confirmado en Clarifications): las tres
operaciones usan el mismo guard de autorización que ya protege `/orders/{order_id}/move` y
`/orders/merge`.

**Scale/Scope**: Operación por mesa individual (unas pocas órdenes, cada una con pocas líneas);
no hay impacto de escala distinto al ya existente para órdenes de mesa.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principio I (nace de un spec)**: PASS. `specs/164-division-automatica-cuenta/spec.md` existe,
  aprobado, con clarifications resueltas.
- **Principio II (comportamiento existente protegido)**: PASS. No se modifica ningún
  comportamiento de `move`/`merge`/`charge` existente; se agregan tres operaciones nuevas. No se
  requiere entrada en `registro-de-anomalias.md` porque no hay cambio de comportamiento
  existente, solo comportamiento nuevo.
- **Principio III (characterization tests)**: PASS (sin impacto). Las operaciones nuevas no
  tocan rutas de código cubiertas por tests `"CONGELA comportamiento actual:"` de move/merge/pay;
  esos tests se mantienen intactos y se agregan tests nuevos para las tres operaciones nuevas.
- **Principio IV (nuevos specs introducen comportamiento nuevo)**: PASS, aplica directamente:
  este spec define comportamiento nuevo (mover/dividir ítems), no equivalencia con el pasado.
- **Principio V (no refactors oportunistas)**: PASS. El plan reutiliza `order_has_sale`,
  `order_totals`/`build_billing_summary` y el patrón de `tables_advanced.py` sin reescribirlos;
  cualquier extracción de helper se limita a lo necesario para la nueva operación.
- **Principio VI (evolución incremental)**: PASS. Las tres operaciones (dividir, mover, crear
  cuenta) son unidades verificables independientes y se implementan como tal en `tasks.md`
  (fase 2), sin mezclar con migraciones de datos no relacionadas.
- **Principio VII (datos históricos inmutables)**: PASS por diseño — el guard de "sin pago
  registrado" (`order_has_sale`) es la condición de entrada a las tres operaciones; ninguna
  `Sale`/`Invoice` ya emitida se recalcula ni se toca.
- **Principio VIII (evolución del modelo de datos)**: N/A — no se agregan columnas ni tablas
  nuevas (ver `data-model.md`); se documenta explícitamente por qué no hace falta migración.
- **Principio IX (dependencias nuevas)**: PASS — no se introduce ninguna dependencia nueva.
- **Principio X (verificación obligatoria)**: Pendiente de ejecución en fase de implementación;
  el plan deja definidos los criterios de aceptación a verificar (ver `quickstart.md`).
- **Principio XI/XII (decisiones de negocio / trazabilidad)**: PASS — las Clarifications del
  spec documentan las decisiones de negocio (fraccionamiento de cantidad, fusión de líneas,
  roles) con su razón; no se requiere entrada adicional en el registro de anomalías porque no
  hay cambio de comportamiento heredado, solo decisiones sobre comportamiento nuevo.
- **Principio XIV/XV (rama y commits)**: a aplicar durante la implementación (`feat/164-...`,
  commits atómicos en inglés, sin marca de IA, solo bajo pedido explícito del usuario).

**Resultado**: Sin violaciones. No se requiere `Complexity Tracking`.

## Project Structure

### Documentation (this feature)

```text
specs/164-division-automatica-cuenta/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   └── orders-item-transfer.md
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
# Backend: ../pos-backend (FastAPI + PostgreSQL 16, schema-per-tenant)
pos-backend/
├── app/
│   ├── models/
│   │   ├── customer_order.py        # CustomerOrder (orden/cuenta) — sin cambios de esquema
│   │   └── order_item.py            # OrderItem (línea) — sin cambios de esquema
│   ├── api/v1/orders/
│   │   ├── router.py                # + 3 endpoints nuevos: split, items/{id}/move, items/{id}/split-to-new
│   │   ├── service.py               # reutiliza order_has_sale, order_totals
│   │   ├── tables_advanced.py        # patrón de referencia (move_order/merge_orders) para la
│   │   │                              # nueva lógica de transferencia de ítems
│   │   └── item_transfer.py          # NUEVO: split_order, move_item, split_item_to_new_order
│   └── characterization_tests/
│       ├── orders_fixtures.py        # fixtures reutilizadas
│       └── test_orders_item_transfer.py  # NUEVO: tests de las 3 operaciones

# Frontend: ../pos-heladeria (Angular)
pos-heladeria/
└── src/app/modules/tables/
    ├── components/
    │   └── pos-order-panel.component.ts   # + botón "Dividir cuenta" por orden,
    │                                        # + acción por ítem "Mover" / "Nueva cuenta"
    ├── services/
    │   ├── table.service.ts               # + splitOrder(), moveItem(), splitItemToNewOrder()
    │   └── pos-terminal.store.ts          # + estado/acciones para las 3 operaciones nuevas
    └── interfaces/
        └── dining.interface.ts            # + tipos de request/response de las 3 operaciones
```

**Structure Decision**: Se reutiliza la estructura Option 2 (web application) ya existente en
ambos repositorios. No se crean módulos nuevos; las tres operaciones viven en el módulo `orders`
del backend (junto a `move`/`merge`, su análogo a nivel de orden) y en el módulo `tables` del
frontend (donde ya vive toda la UI de la terminal de mesas).

## Complexity Tracking

*No violations — table intentionally omitted.*
