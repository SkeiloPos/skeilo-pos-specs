# Implementation Plan: Pago por transferencia y pago mixto sin subida de comprobante, con verificación del cajero

**Branch**: `132-pago-transferencia-mixto-caja` | **Date**: 2026-10-23 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/132-pago-transferencia-mixto-caja/spec.md`

## Summary

Eliminar la subida de comprobante por el comensal en el flujo QR (transferencia total y
pago mixto) y mover toda la verificación de la transferencia al cajero, en persona, en el
momento de la entrega. El enfoque técnico reutiliza la infraestructura de pagos ya existente
(`OrderPaymentAttempt`, spec 024/130) en lugar de crear un nuevo modelo: se relaja la
obligatoriedad de `receipt_file_url` (pasa de "requerido para aprobar" a "evidencia opcional
que solo el cajero puede adjuntar"), se cierra el conjunto de motivos de rechazo, se agrega
un endpoint de reajuste de división efectivo/transferencia al confirmar, y se usa el patrón
de auditoría ya persistido (`AuditLog`/`record_audit`, RF-076) — no el canal solo-Sentry de
spec 074 — como historial consultable de cada cambio de estado de un pago, porque las
historias de usuario exigen poder "consultar el historial del pedido" dentro del propio
sistema. La resolución de un rechazo por cancelación-como-impago reutiliza el endpoint de
cancelación de pedido ya existente (`cancel_order`), que ya anula pagos pendientes y traza
pérdidas de inventario como auditoría — el mismo patrón que este spec adopta para registrar
la cancelación como merma (FR-018), sin introducir una entidad `Merma` nueva.

## Technical Context

**Language/Version**: Python 3.11 (FastAPI, backend), TypeScript 5 / Angular (frontend)

**Primary Dependencies**: FastAPI, SQLAlchemy 2.x, Alembic (backend); Angular, RxJS (frontend).
Sin dependencias nuevas — toda la funcionalidad se apoya en infraestructura ya existente
(`OrderPaymentAttempt`, `AuditLog`, `PaymentMethod`, almacenamiento de archivos vía
presigned URL).

**Storage**: PostgreSQL 16, schema-per-tenant (`tenant.order_payment_attempts`,
`tenant.audit_logs`, `tenant.customer_orders`). Sin nuevas tablas; se agregan/ajustan
constraints sobre `order_payment_attempts` vía migración Alembic.

**Testing**: Backend — `unittest` (`python -m unittest discover -s app/characterization_tests
-p 'test_*.py'`) ejecutado dentro del venv de `pos-backend` (`source env/bin/activate`), más
tests nuevos de la funcionalidad bajo el mismo runner. Frontend — `ng test` (Karma/Jasmine);
baseline conocido como flaky, por lo que la verificación compara diff de archivos afectados,
no el conteo total de la suite (ver memoria de sesión).

**Target Platform**: Servidor Linux (API `pos-backend`); navegador (QR del comensal y
terminal POS del cajero, ambos servidos por `pos-heladeria`).

**Project Type**: Web application (dos repositorios: `pos-backend` API + `pos-heladeria`
frontend Angular).

**Performance Goals**: SC-002 — el cajero debe poder confirmar o rechazar una verificación en
menos de 30s desde que recibe el pedido en caja; no hay pasos de red adicionales (sin OCR, sin
llamadas a pasarelas) que puedan introducir latencia relevante frente al flujo manual actual.

**Constraints**: No se introduce ningún control técnico de validación automática de
transferencias (Assumptions del spec); la foto de comprobante que el cajero puede adjuntar
nunca bloquea la confirmación (FR-012); los datos históricos de pagos y facturas ya emitidas
no se recalculan (Principio VII de la constitución).

**Scale/Scope**: Cambio acotado a los módulos de pagos de pedidos QR (`app/api/v1/orders/`,
`app/models/order_payment_attempt.py`) y a los componentes de checkout QR y revisión de pagos
en caja del frontend (`tables/pages/checkout/`, `tables/components/payment-attempt-review-panel.component.ts`).
No afecta facturación, inventario fuera del flujo de cancelación-como-merma ya existente, ni
otros métodos de pago (efectivo puro no se modifica).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principio I (nace de un spec)**: ✅ `spec.md` aprobado en `specs/132-...` define problema,
  alcance, reglas de negocio, criterios de aceptación e impacto. Este plan no añade alcance
  fuera de ese spec.
- **Principio II (comportamiento existente protegido / decisión de negocio)**: ⚠️ requiere
  registro. El spec cambia comportamiento existente del flujo QR (spec 024/130): hoy
  `approve_payment_attempt` exige `receipt_file_url`; este spec lo convierte en opcional
  (FR-012) y retira la UI de subida del comensal (FR-023). Es un cambio de comportamiento
  explícitamente autorizado por el propio spec 132 (no es una decisión implícita del
  implementador) — se registra en
  `specs/000-reconocimiento/registro-de-anomalias.md` como parte de la Fase 0 (ver
  research.md, Decisión 1).
- **Principio III (characterization tests)**: no se identifican characterization tests
  `"CONGELA comportamiento actual:"` sobre el flujo de aprobación de comprobante de
  transferencia; si la implementación encuentra alguno, se actualiza explícitamente citando
  este spec, no se omite.
- **Principio V/VI (sin refactor oportunista, evolución incremental)**: el plan reutiliza
  `OrderPaymentAttempt`/`AuditLog` tal cual existen; no se propone ninguna refactorización no
  relacionada con FR-001 a FR-023.
- **Principio VII (datos históricos)**: no se recalculan pagos ni ventas ya confirmados;
  el reajuste de división (FR-013) solo aplica a intentos `pendiente`.
- **Principio VIII (evolución del modelo de datos)**: ver data-model.md — se documentan los
  cambios de constraint (no de columnas) y la estrategia de migración/rollback.
- **Principio XIV/XV (ramas y commits)**: fuera del alcance de `/speckit-plan`; se aplican en
  la fase de implementación.

**Resultado del gate**: PASA, con una entrada pendiente de registro en
`registro-de-anomalias.md` (Principio II) que se completa en Fase 0 antes de implementar.

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

Repositorios hermanos de `pos-specs`, en `../pos-backend` y `../pos-heladeria` (fuera de este
repo de specs, ya en producción):

```text
pos-backend/
├── app/
│   ├── models/
│   │   └── order_payment_attempt.py       # ajuste de constraints (sin columnas nuevas)
│   ├── api/v1/orders/
│   │   ├── checkout.py                    # approve/reject/confirm-cash/adjust-split/cancel
│   │   ├── schemas.py                     # enum cerrado de motivos de rechazo, body de adjust-split
│   │   └── router.py                      # nuevo endpoint adjust-split; sin cambios de ruta en los existentes
│   └── core/
│       └── audit.py                       # reutilizado (record_audit) para historial consultable
├── alembic/versions/                      # nueva revisión: constraint de motivos + comentarios
└── app/characterization_tests/            # tests nuevos de la funcionalidad bajo el mismo runner

pos-heladeria/
└── src/app/modules/tables/
    ├── pages/checkout/
    │   └── transfer-details-step.component.ts   # retira el paso de subida de comprobante
    ├── services/
    │   └── diner.service.ts                      # retira uploadReceiptFile/presign en este flujo
    └── components/
        └── payment-attempt-review-panel.component.ts  # agrega: foto opcional, motivo cerrado,
                                                         # reajuste de división, resolución de rechazo
```

**Structure Decision**: Web application de dos repos ya existentes (Principio: Alcance del
Proyecto de la constitución). No se crean nuevos proyectos ni paquetes; el cambio vive dentro
de los módulos de pagos de pedidos QR ya establecidos por spec 024/130, tanto en backend como
en frontend.

## Complexity Tracking

> No hay violaciones del Constitution Check que requieran justificación. El cambio reutiliza
> modelos y patrones de auditoría existentes (spec 024/074/130, RF-076) sin introducir
> entidades, dependencias ni proyectos nuevos.

## Constitution Check (post-diseño)

*Re-evaluado tras research.md y data-model.md (Fase 1).*

- **Principio II**: confirmado — el único cambio de comportamiento existente es el gate de
  `receipt_file_url` en `approve_payment_attempt` (research.md, Decisión 1); queda pendiente
  de registrar en `registro-de-anomalias.md` antes de implementar, no antes de planear.
- **Principio VIII**: data-model.md documenta que no hay columnas nuevas, solo un
  `CheckConstraint` sobre `rejection_reason`, con estrategia de migración (normalización de
  valores fuera del conjunto cerrado) y de rollback explícitas.
- **Principio IX**: ninguna dependencia ni entidad nueva — `AuditLog` (Decisión 3) y
  `cancel_order`/`OrderCancelLog` (Decisión 6) ya existían y se reutilizan sin modificar su
  esquema.
- **Resultado**: PASA sin excepciones nuevas respecto al gate inicial.
