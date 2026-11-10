# Implementation Plan: Cobro independiente de pedidos por mesa

**Branch**: `feat/156-cobro-independiente-pedidos-mesa` | **Date**: 2026-11-10 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/156-cobro-independiente-pedidos-mesa/spec.md`

## Summary

Hoy, cobrar una mesa con varios pedidos QR (uno por comensal) siempre cobra **todos**
los pedidos facturables de la sesión en una sola operación; no existe forma de cobrar
solo el pedido de un comensal que quiere pagar y retirarse antes que el resto. La
investigación del código actual (`pos-backend/app/api/v1/table_sessions/service.py`)
muestra que la pieza central ya es genérica: `_charge_session` opera sobre cualquier
lista de `CustomerOrder`, y cada pedido ya tiene su propio `payment_status`
(`'UNPAID'|'PAID'`, independiente de `status`) desde spec 147. La única pieza que falta
es permitir que el cajero **seleccione explícitamente** qué pedidos entran en una
transacción de cobro, en vez de que siempre sea "todos los facturables de la sesión".

Enfoque técnico: agregar un parámetro opcional `order_ids` al endpoint existente
`POST /table-sessions/{id}/charge` (y al `GET /bill` para la previsualización), que
acota `_billable_orders` al subconjunto pedido y valida que cada id sea cobrable. No
se toca `close_session` (cobra+libera todo siempre, por diseño — ver `research.md`
D2) ni `release_paid_session` (ya exige el 100% pagado, satisface FR-005/006 sin
cambios). En el frontend, el panel de cobro de sesión de la Terminal de Mesas agrega
selección múltiple sobre las pestañas "Pedido N" existentes. Sin cambios de modelo de
datos ni migraciones.

## Technical Context

**Language/Version**: Python 3.11 (FastAPI) en `pos-backend`; TypeScript/Angular en
`pos-heladeria`.

**Primary Dependencies**: FastAPI, SQLAlchemy (backend); Angular, RxJS/Signals
(frontend). Sin dependencias nuevas.

**Storage**: PostgreSQL 16, schema-per-tenant. Sin migraciones (Principio VIII no
aplica — no hay campos ni entidades nuevas).

**Testing**: `pytest` (backend, incluye characterization tests
`"CONGELA comportamiento actual:"`); suite de tests de `pos-heladeria` (Angular/Jest o
Karma, según configuración del repo) para el componente de cobro.

**Target Platform**: API HTTP (Linux server) + SPA Angular, consumidos por la
Terminal de Mesas del cajero.

**Project Type**: Web application (backend API + frontend SPA) — repositorios
independientes `pos-backend` y `pos-heladeria`, ambos en producción.

**Performance Goals**: Sin requisitos nuevos de rendimiento; el cobro parcial usa las
mismas rutas de cálculo (`order_sale_lines`, `auto_discount`) ya en producción, acotadas
a menos pedidos, nunca a más.

**Constraints**: Debe preservar el comportamiento actual cuando no se envía selección
(Principio II); no debe alterar `close_session`/`release_paid_session`; no debe tocar
facturas ya emitidas (Principio VII) — nunca se modifica una `Sale`/factura existente,
solo se crean nuevas para los pedidos recién seleccionados.

**Scale/Scope**: Cambio acotado a `table_sessions` (backend) y al panel de cobro de la
Terminal de Mesas (frontend) de `pos-heladeria`. No afecta el flujo de cobro de
mostrador (pedidos sin mesa), que usa un panel distinto (`checkout-and-send` /
`pay_order`).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principio I (Spec previo)**: ✅ `spec.md` ya existe y define problema, alcance,
  reglas de negocio, casos de aceptación e impacto — este plan se construye sobre él.
- **Principio II (Comportamiento existente protegido)**: ✅ El diseño (D1/D2 en
  `research.md`) hace que `order_ids` sea **opcional** y, al omitirse, replica
  exactamente el comportamiento actual de `/charge` y `/bill`. No se identificó
  ningún comportamiento existente que esta feature deba cambiar — por tanto **no se
  requiere ninguna entrada nueva en `registro-de-anomalias.md`**: no hay decisión de
  negocio que "cambie" comportamiento, solo se añade una capacidad nueva sobre
  comportamiento preexistente ya diseñado para ser genérico.
- **Principio III (Characterization tests)**: ✅ No se modifica ningún test
  `"CONGELA comportamiento actual:"` de `table_sessions`/`customer_order`; el plan
  exige que sigan pasando sin cambios (ver `quickstart.md`, sección de verificación).
- **Principio IV (Nuevo comportamiento vía spec)**: ✅ El comportamiento nuevo
  (cobro de subconjunto) está definido en `spec.md` (FR-001 a FR-009).
- **Principio V (Sin refactors oportunistas)**: ✅ Se reutiliza `_charge_session`,
  `_close_unified`, `_close_split`, `compute_bill` tal cual — no se refactoriza nada
  no relacionado con aceptar/validar `order_ids`.
- **Principio VI (Evolución incremental)**: ✅ Un solo tipo de cambio: extender un
  parámetro de selección sobre un endpoint existente + UI de selección. No mezcla
  migración de datos, cambio de arquitectura ni refactor.
- **Principio VII (Datos históricos inmutables)**: ✅ Ninguna `Sale`/factura ya
  emitida se recalcula ni modifica; el cobro parcial solo crea `Sale`s nuevas para
  pedidos que antes no tenían ninguna.
- **Principio VIII (Evolución del modelo de datos)**: ✅ No aplica — sin campos,
  entidades ni migraciones nuevas (ver `data-model.md`).
- **Principio IX (Dependencias nuevas)**: ✅ No aplica — ninguna dependencia nueva.
- **Principio X (Verificación obligatoria)**: Pendiente de ejecución en fase de
  implementación — `quickstart.md` define los escenarios y characterization tests a
  verificar.
- **Principio XI/XII (Negocio vs. técnico / Trazabilidad)**: ✅ La cadena Necesidad
  (reporte del usuario) → Spec 156 → (sin decisión de negocio adicional, ver
  Principio II arriba) → este plan → implementación/tests queda documentada en estos
  artefactos.
- **Principio XIV (Rama Git)**: antes de tocar código en `pos-backend` o
  `pos-heladeria` se crea `feat/156-cobro-independiente-pedidos-mesa` desde la rama
  actual de cada repo (no aplica a `pos-specs`, que no sigue esta convención de
  ramas de código).
- **Principio XV (Commits)**: ningún commit se hace en esta sesión de planificación;
  se diferirá a cuando el usuario lo solicite explícitamente durante la
  implementación.

**Resultado**: Sin violaciones. No se requiere `Complexity Tracking`.

## Project Structure

### Documentation (this feature)

```text
specs/156-cobro-independiente-pedidos-mesa/
├── plan.md              # Este archivo
├── research.md          # Decisiones D1-D8
├── data-model.md         # Campos existentes reutilizados, sin entidades nuevas
├── contracts/
│   └── table-session-charge-subset.md   # Contrato de /bill, /charge, /close, /release, /cancel
├── quickstart.md        # Escenarios de validación manual + automatizada
└── tasks.md             # Fase 2 (/speckit-tasks, no generado por este comando)
```

### Source Code (repository root)

Repositorios reales afectados (fuera de `pos-specs`):

```text
../pos-backend/
└── app/
    ├── api/v1/table_sessions/
    │   ├── schemas.py     # + order_ids opcional (CloseSessionIn o esquema de /charge)
    │   ├── service.py     # _billable_orders/compute_bill/charge_session: filtrar y
    │   │                   #   validar order_ids; sin cambios en _assert_closable,
    │   │                   #   _close_unified, _close_split, close_session,
    │   │                   #   release_paid_session
    │   └── router.py      # /bill: query param order_ids; /charge: body order_ids
    ├── models/customer_order.py   # sin cambios (payment_status ya existe)
    └── characterization_tests/    # deben seguir pasando sin modificación

../pos-heladeria/
└── src/app/modules/tables/
    ├── services/table-session.service.ts   # charge()/getBill() aceptan order_ids
    ├── services/pos-terminal.store.ts       # estado de selección de pedidos
    ├── components/session-bill-panel.component.ts   # UI de selección + total parcial
    └── components/pos-checkout-panel.component.ts   # sin cambios estructurales
```

**Structure Decision**: Web application existente de dos repos (backend FastAPI +
frontend Angular), ya en producción. No se crea ninguna estructura nueva de
proyecto; el cambio vive enteramente dentro de los módulos `table_sessions`
(backend) y `modules/tables` (frontend) ya existentes.

## Complexity Tracking

*No aplica — sin violaciones del Constitution Check.*
