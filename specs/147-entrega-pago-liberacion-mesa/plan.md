# Implementation Plan: Ciclo de Vida Simplificado del Pedido y Control Manual de Mesas

**Branch**: `147-entrega-pago-liberacion-mesa` | **Date**: 2026-11-01 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/147-entrega-pago-liberacion-mesa/spec.md`

## Summary

Reemplaza el modelo de 5 estados de pedido (`pendiente, abierta, bloqueada, pagada,
cancelada`) por 3 (`pendiente, entregada, cancelada`), separando explícitamente el estado
de pago (`UNPAID, PAID`, eliminando `PARTIAL`) y colapsando los 4 estados de cocina por
ítem (`pendiente, en_preparacion, listo, anulado`) en 3 reflejados siempre por el estado del
pedido (`pendiente, entregado, cancelado`). La entrega pasa de ser una acción por ítem
(`kitchen_transition`) a una sola acción idempotente por pedido completo. La liberación de
mesa deja de evaluar "¿hay algo por cobrar?" (criterio actual de
`release_paid_session`/`try_release_if_empty`) y pasa a evaluar "¿hay alguna orden
`pendiente` o `entregada`+`UNPAID`?", sin ningún mecanismo de liberación por tiempo. Es una
migración de datos (Alembic, mismo patrón que la migración precedente del spec 146) más
cambios acotados en los endpoints de pedidos, ítems y sesión de mesa, y en las etiquetas de
estado del frontend Angular.

## Technical Context

**Language/Version**: Backend: Python 3.11 (FastAPI). Frontend: TypeScript (Angular,
standalone components, sin NgModules nuevos).

**Primary Dependencies**: Backend: FastAPI, SQLAlchemy 2.x (`Mapped`/`mapped_column`),
Alembic, `app.core.event_bus` (Redis Streams, SSE). Frontend: Angular, `dining-session.service.ts`
y `pos-terminal.store.ts` como consumidores del API y del stream de eventos.

**Storage**: PostgreSQL 16, schema-per-tenant (`tenant_default` + un esquema por tenant en
`shared.tenants`), migrado con `@for_each_tenant_schema` (ver
`alembic/versions/e967f9848848_rename_recibida_to_pendiente_add_payment_status.py`, spec 146 —
precedente directo de esta misma migración).

**Testing**: Backend: `pytest` (suite de `app/characterization_tests/` protege comportamiento
heredado; memoria de sesión: usar el venv de `pos-backend`, Postgres local disponible).
Frontend: `ng test` (`@angular/build:unit-test`, Jasmine) — baseline conocido como flaky/no
determinista; comparar por archivo afectado, no por conteo total de la suite completa.

**Target Platform**: Backend: servidor Linux (API HTTP + SSE). Frontend: navegador (SPA
Angular), incluida la vista QR del comensal (misma SPA, ruta pública).

**Project Type**: Web application (dos repositorios: `pos-backend` API + `pos-heladeria`
frontend), consumida también por un canal público QR (sin app aparte: mismo frontend).

**Performance Goals**: SC-001 — marcar un pedido completo como entregado en menos de 2
segundos de interacción (un solo clic, sin ítem-por-ítem). Sin otros objetivos de
rendimiento nuevos: el volumen de pedidos no cambia respecto al sistema actual.

**Constraints**: FR-011/SC-006 — dos solicitudes de entrega casi simultáneas sobre el mismo
pedido deben producir un único cambio de estado efectivo y ambas respuestas exitosas (mismo
patrón de `SELECT ... FOR UPDATE` ya usado en `app/api/v1/orders/checkout.py` para
`CustomerOrder`/`OrderPaymentAttempt`). FR-023/SC-007 — la migración de datos no puede dejar
ningún registro fuera del conjunto final de estados, sin excepciones, y debe ser reversible
en la ventana de emergencia inmediatamente posterior al despliegue (mismo criterio de
rollback documentado que la migración `e967f9848848` precedente).

**Scale/Scope**: Afecta el módulo de pedidos (`CustomerOrder`, `OrderItem`), el módulo de
mesas/sesión de mesa (`DiningTable`, `TableSession`), la Terminal de Mesas y la vista QR del
comensal (ambas en `pos-heladeria`), y una migración de datos sobre todos los esquemas de
tenant existentes. No introduce entidades nuevas (ver Key Entities del spec: son las tres ya
existentes, con su modelo de estados reducido).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principio I (Nace de un spec)**: PASA — `spec.md` ya está aprobado con clarificaciones
  resueltas (sección Clarifications) antes de este plan.
- **Principio II (Comportamiento existente protegido)**: PASA con decisión de negocio
  explícita — el spec mismo documenta el cambio de comportamiento (colapsar estados,
  liberación manual) con sus reglas de mapeo (FR-023). Pendiente: registrar esta decisión en
  `specs/000-reconocimiento/registro-de-anomalias.md` antes de implementar (tarea de
  `/speckit-tasks`, no de este plan).
- **Principio III (Characterization tests)**: aplica — cualquier test
  `"CONGELA comportamiento actual:"` que asuma `abierta`/`bloqueada`/`PARTIAL`/
  `en_preparacion`/`listo` queda afectado y debe actualizarse citando este spec, no
  silenciosamente. Se detalla en `research.md` (R6).
- **Principio IV (Nuevo comportamiento permitido)**: PASA — el spec define comportamiento
  nuevo explícitamente (entrega de un clic, pago independiente, liberación manual).
- **Principio V (Sin refactors oportunistas)**: PASA — el alcance se limita a lo que FR-001…
  FR-023 exige; no se tocan módulos no relacionados (facturación, inventario, promociones)
  salvo donde el modelo de estados de orden es una precondición leída por ellos (ver
  `research.md` R7 para el inventario de esos puntos de lectura).
- **Principio VI (Evolución incremental)**: la migración de datos, el cambio de backend y el
  cambio de frontend son três clases de cambio distintas; `/speckit-tasks` debe secuenciarlas
  en unidades verificables por separado (migración primero y aislada, backend después,
  frontend al final), no mezclarlas en un commit.
- **Principio VII (Datos históricos inmutables)**: PASA — ninguna `Sale`/`Invoice` ya emitida
  se recalcula; la migración solo reescribe `status`/`payment_status`/`estado_cocina`, campos
  operativos de pedido, no campos de factura.
- **Principio VIII (Evolución del modelo de datos)**: ver `data-model.md` — entidades,
  mapeo de migración, estrategia de rollback documentados explícitamente, siguiendo el mismo
  patrón que la migración `e967f9848848`.
- **Principio IX (Dependencias nuevas)**: N/A — no se introduce ninguna dependencia nueva.
- **Principio X (Verificación obligatoria)**: ver `quickstart.md` para los escenarios de
  validación extremo a extremo; `/speckit-tasks` deberá listar los tests concretos.
- **Principio XI/XII (Negocio vs técnico / Trazabilidad)**: PASA — el spec ya distingue
  ambos tipos de decisión (clarificaciones = decisiones de negocio citadas con fecha
  2026-11-01); este plan no introduce ninguna decisión de negocio nueva, solo técnica.

**Resultado**: ninguna violación que requiera `Complexity Tracking`. Gate superado.

## Project Structure

### Documentation (this feature)

```text
specs/147-entrega-pago-liberacion-mesa/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   └── orders-api.md
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

Repositorios hermanos reales (no sub-carpetas de este repo de specs):

```text
../pos-backend/
├── app/
│   ├── models/
│   │   ├── customer_order.py        # status, payment_status, __table_args__ (CHECKs)
│   │   ├── order_item.py            # estado_cocina, EN_CURSO
│   │   ├── order_cancel_log.py      # motivo (ya existe, se reutiliza)
│   │   ├── dining_table.py          # status ('libre'/'ocupada'/...)
│   │   └── table_session.py         # status ('active'/'closed'), opened_at
│   ├── api/v1/orders/
│   │   ├── service.py               # _NON_TERMINAL_ORDER_STATUSES, ESTADOS_MOSTRADOS_ORDENES
│   │   ├── checkout.py              # pay_order, confirm_order, cancel_order
│   │   ├── kitchen.py                # transition_kitchen (acción por ítem — a retirar, FR-002)
│   │   └── router.py                 # POST /orders/items/{id}/kitchen (a retirar)
│   ├── api/v1/table_sessions/
│   │   ├── service.py               # has_billable_orders, try_release_if_empty,
│   │   │                            # release_paid_session (base de la liberación manual)
│   │   └── router.py
│   ├── core/events.py                # order_confirmed/order_cancelled/... (falta order_delivered)
│   └── api/v1/realtime/              # SSE: router.py, auth.py (stream por table_session/staff)
└── alembic/versions/
    └── <nueva>_147_simplify_order_item_status_payment.py

../pos-heladeria/
└── src/app/modules/
    ├── orders/order-status.util.ts          # KNOWN_ORDER_STATUSES, labels crudos (FR-013)
    └── tables/
        ├── interfaces/dining.interface.ts    # DiningOrderStatus, KitchenStatus, OrderPaymentStatus
        ├── services/pos-terminal.store.ts    # estado de la Terminal de Mesas
        ├── services/dining-session.service.ts # vista QR del comensal (tiempo real)
        └── components/pos-order-panel.component.ts / pos-tables-panel.component.ts
```

**Structure Decision**: proyecto web de dos repositorios ya existentes (Opción 2 del
template, sin crear estructura nueva): `pos-backend` (API) y `pos-heladeria` (frontend). Este
spec no crea módulos nuevos; modifica archivos puntuales dentro de los módulos `orders`,
`table_sessions` y `tables` ya existentes en ambos repos, siguiendo Principio XIV (rama
nueva por repositorio antes de tocar código).

## Complexity Tracking

*Sin violaciones que justificar — tabla omitida (Constitution Check superado sin excepciones).*
