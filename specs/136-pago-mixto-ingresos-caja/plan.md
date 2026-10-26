# Implementation Plan: Métodos distintos en pago mixto e ingresos de caja por método de pago

**Branch**: `136-pago-mixto-ingresos-caja` | **Date**: 2026-10-25 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/136-pago-mixto-ingresos-caja/spec.md`

## Summary

Dos cambios acotados sobre infraestructura de pagos ya existente en `pos-backend`/`pos-heladeria`,
sin entidades nuevas de "pago" (US1) y con una sola extensión de esquema (US2/US3):

1. **US1 — no repetir método en pago mixto de pedido**: agregar una validación de "métodos
   distintos" en el único punto donde ya confluyen las 3 rutas de cobro de pedido/mostrador
   (`build_sale`, `pos-backend/app/api/v1/sales/builder.py`) más su espejo en el borrador del
   frontend (`paymentIssue()`, `payment-draft.util.ts`). Revierte explícitamente A-124/FR-005 de
   spec 112 (ver `registro-de-anomalias.md`, A-146) — no toca el tope de 3 líneas ni ninguna otra
   regla de spec 112.
2. **US2/US3 — ingresos de caja por método de pago, hasta 2 líneas**: extender `CashMovement`
   (hoy implícitamente efectivo, sin columna de método) con `payment_method_id` (obligatorio,
   backfill a "Efectivo" para filas históricas y para egreso/retiro, que siguen forzados a
   efectivo) y `group_id` (opcional, enlaza las 1-2 filas de un mismo evento de ingreso mixto).
   `reconcile()` separa el efectivo (sigue sumando a `expected`, sin cambio de fórmula) de los
   demás métodos (se agregan a un nuevo desglose de ingresos por método en el arqueo, sin tocar
   `expected`).

Ninguna de las dos capacidades introduce un modelo de "pago"/"ingreso" nuevo: ambas reutilizan los
contenedores de líneas que el sistema ya tiene (`Payment` 1:N por `Sale`; `CashMovement`, ahora 1:N
opcional por evento vía `group_id`), siguiendo el mismo patrón que spec 112 (lista de líneas) y
spec 132 (ajuste de constraint, no de arquitectura).

## Technical Context

**Language/Version**: Python 3.11 (FastAPI, backend), TypeScript 5 / Angular (frontend)

**Primary Dependencies**: FastAPI, SQLAlchemy 2.x, Alembic (backend); Angular, RxJS (frontend).
Sin dependencias nuevas — toda la funcionalidad se apoya en infraestructura ya existente
(`Payment`, `PaymentMethod`, `CashMovement`, el catálogo de métodos por tenant de spec 032).

**Storage**: PostgreSQL 16, schema-per-tenant. Sin tablas nuevas. Una migración Alembic agrega
`payment_method_id` (FK, `NOT NULL` tras backfill) y `group_id` (`UUID`, nullable) a
`tenant.cash_movements`. `tenant.payments` no cambia de esquema (la validación de "métodos
distintos" es lógica de aplicación, no una columna ni un constraint nuevo — ver research.md D1).

**Testing**: Backend — `unittest` (`python -m unittest discover -s app/characterization_tests
-p 'test_*.py'`) dentro del venv de `pos-backend` (`source env/bin/activate`), más tests nuevos de
la funcionalidad bajo el mismo runner y los scripts de verificación manual existentes
(`app/scripts/test_mixed_payment_checkout.py`) extendidos con el caso de rechazo. Frontend —
`ng test` (Karma/Jasmine); baseline conocido como flaky, se compara diff de archivos afectados, no
el conteo total de la suite (memoria de sesión: `how-to-run-sibling-repo-tests`).

**Target Platform**: Servidor Linux (API `pos-backend`); navegador (Terminal POS del cajero,
servida por `pos-heladeria`). Esta spec no toca el flujo QR del comensal.

**Project Type**: Web application (dos repositorios: `pos-backend` API + `pos-heladeria` frontend
Angular).

**Performance Goals**: SC-003 — registrar un ingreso de caja (de un solo método o mixto) en menos
de 30s, sin pasos adicionales a los que ya usa hoy el ingreso en efectivo; no se introducen
llamadas de red nuevas más allá de las que ya hace el modal de movimientos (que ya obtiene el
catálogo de métodos activos para el panel de cobro, vía `GET /sales/payment-methods?available=true`
— se reutiliza, no se agrega un endpoint nuevo de catálogo).

**Constraints**: Los datos históricos de `Payment`/`Sale`/`CashMovement` no se recalculan
(Principio VII); el backfill de `payment_method_id` en `cash_movements` es solo metadata derivada
(todo movimiento histórico era efectivo por definición, no una reinterpretación de su monto o
decisión de negocio); egreso/retiro permanecen forzados a efectivo sin excepción (FR-012, fuera de
alcance).

**Scale/Scope**: Cambio acotado a los módulos de pagos de pedidos/mostrador
(`app/api/v1/sales/`, `app/api/v1/orders/`) y al módulo de caja (`app/api/v1/cash/`,
`app/models/cash_movement.py`) en `pos-backend`; a los componentes de cobro de pedido y al modal
de movimientos de caja en `pos-heladeria`. No afecta facturación, inventario, ni el flujo de pago
mixto del autocheckout QR (`OrderPaymentAttempt`, spec 130/132), que usa columnas fijas
(`cash_amount`/`transfer_amount`) y queda fuera de esta spec.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principio I (nace de un spec)**: ✅ `spec.md` aprobado en `specs/136-...` define problema,
  alcance, reglas de negocio (vía Clarifications), criterios de aceptación e impacto. Este plan no
  añade alcance fuera de ese spec.
- **Principio II (comportamiento existente protegido / decisión de negocio)**: ⚠️ requiere
  registro, ya completado en Fase 0 — US1 revierte explícitamente A-124/FR-005 de spec 112 (permitir
  repetir método en pago mixto de pedido). Registrado como
  [`A-146`](../000-reconocimiento/registro-de-anomalias.md#a-146--decisión-de-negocio--spec-136-se-revierte-a-124fr-005-de-spec-112-un-pago-mixto-de-pedido-ya-no-admite-repetir-el-mismo-método-en-dos-líneas)
  en `registro-de-anomalias.md`. US2/US3 (ingresos por método) no revierte ningún comportamiento
  existente: amplía una capacidad (hoy el ingreso solo admite efectivo) sin cambiar el
  comportamiento de los ingresos en efectivo (FR-009, preservado sin cambios) ni el de
  egreso/retiro (FR-012, preservado sin cambios) — no requiere entrada en el registro.
- **Principio III (characterization tests)**: no se identifican characterization tests
  `"CONGELA comportamiento actual:"` sobre "mismo método repetido en pago mixto" ni sobre
  "ingresos solo en efectivo" (ver A-146 y research.md D1/D4); si la implementación encuentra
  alguno no detectado en esta investigación, se actualiza explícitamente citando esta spec, no se
  omite.
- **Principio V/VI (sin refactor oportunista, evolución incremental)**: el plan reutiliza
  `Payment`/`Sale`/`CashMovement`/`PaymentMethod` tal cual existen (salvo las dos columnas nuevas
  de `CashMovement`); no se propone ninguna refactorización no relacionada con FR-001 a FR-014. US1
  y US2/US3 son cambios independientes entre sí (distintos modelos, distintos endpoints) y se
  pueden entregar como incrementos separados si conviene en `/speckit-tasks`.
- **Principio VII (datos históricos)**: no se recalcula ningún `Payment`, `Sale` ni `CashMovement`
  ya registrado; el backfill de `payment_method_id` en filas históricas de `cash_movements` es
  metadata (todo movimiento histórico ya era efectivo por definición — ver research.md D4), no una
  reinterpretación de un hecho de negocio ya ocurrido.
- **Principio VIII (evolución del modelo de datos)**: ver data-model.md — se documentan las dos
  columnas nuevas de `cash_movements`, su compatibilidad con datos existentes (backfill), y la
  estrategia de rollback.
- **Principio IX (dependencias)**: ninguna dependencia nueva.
- **Principio XIV/XV (ramas y commits)**: fuera del alcance de `/speckit-plan`; se aplican en la
  fase de implementación.

**Resultado del gate**: PASA. La única entrada pendiente del Principio II (A-146) ya se registró en
esta misma Fase 0, antes de que exista cualquier tarea de implementación.

## Project Structure

### Documentation (this feature)

```text
specs/136-pago-mixto-ingresos-caja/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/
│   └── api.md           # Phase 1 output (/speckit-plan command)
└── tasks.md              # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

Repositorios hermanos de `pos-specs`, en `../pos-backend` y `../pos-heladeria` (fuera de este repo
de specs, ya en producción):

```text
pos-backend/
├── app/
│   ├── models/
│   │   └── cash_movement.py                 # + payment_method_id, + group_id
│   ├── api/v1/
│   │   ├── sales/
│   │   │   ├── builder.py                   # build_sale: valida métodos distintos (US1)
│   │   │   └── schemas.py                   # PaymentIn sin cambio; validador compartido de duplicados
│   │   ├── orders/
│   │   │   └── schemas.py                   # PayIn/CheckoutAndSendIn.payments reusan el validador
│   │   └── cash/
│   │       ├── schemas.py                    # CashMovementIn: + lines opcional; ReconciliationResponse: + ingresos_by_method
│   │       ├── router.py                     # add_movement: hasta 2 líneas, fuerza efectivo en egreso/retiro
│   │       └── service.py                    # reconcile(): separa ingreso-efectivo de ingreso-otros-métodos
│   └── characterization_tests/               # (sin tests protegidos afectados, ver A-146/research.md D1)
├── app/scripts/
│   └── test_mixed_payment_checkout.py        # + caso de rechazo por método repetido
└── alembic/versions/                         # nueva revisión: columnas de cash_movements + backfill

pos-heladeria/
└── src/app/modules/
    ├── tables/
    │   ├── services/
    │   │   └── payment-draft.util.ts         # paymentIssue(): + regla de método repetido (US1)
    │   └── components/
    │       └── payment-input.component.ts    # selector: excluye métodos ya usados en otra línea
    └── cash-register/
        ├── interfaces/
        │   └── cash.interface.ts             # CashMovementPayload: + lines opcional
        ├── services/
        │   └── cash-session.store.ts         # confirmarMovimiento(): construye lines para 'ingreso'
        └── components/
            └── cash-movement-modal.component.ts  # + selector de método, + "agregar otro método" (máx. 2, solo ingreso)
```

**Structure Decision**: Web application de dos repos ya existentes (Principio: Alcance del
Proyecto de la constitución). No se crean nuevos proyectos ni paquetes; US1 vive dentro del módulo
de cobro de pedidos/mostrador ya establecido por spec 011/112; US2/US3 viven dentro del módulo de
caja ya establecido por spec 006/108/114/121.

## Complexity Tracking

> No hay violaciones del Constitution Check que requieran justificación. US1 no agrega modelo ni
> columnas. US2/US3 agregan dos columnas a una tabla existente (`cash_movements`), no una tabla ni
> una entidad nueva — ver data-model.md para la justificación de por qué no se introduce un
> "evento de ingreso" como entidad separada.

## Constitution Check (post-diseño)

*Re-evaluado tras research.md y data-model.md (Fase 1).*

- **Principio II**: confirmado — único cambio de comportamiento existente es la reversión de
  A-124/FR-005 (US1), ya registrada como A-146 antes de esta fase de diseño. US2/US3 no cambian
  comportamiento existente (ingreso en efectivo, egreso, retiro quedan idénticos).
- **Principio VIII**: data-model.md documenta las dos columnas nuevas de `cash_movements`
  (`payment_method_id` NOT NULL con backfill, `group_id` nullable sin backfill), con estrategia de
  migración y de rollback explícitas. `tenant.payments` no cambia de esquema.
- **Principio IX**: ninguna dependencia nueva.
- **Resultado**: PASA sin excepciones nuevas respecto al gate inicial.
