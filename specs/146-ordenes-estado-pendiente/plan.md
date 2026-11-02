# Implementation Plan: Estado inicial PENDIENTE para órdenes e ítems, sin traducción en frontend

**Branch**: `146-ordenes-estado-pendiente` | **Date**: 2026-11-01 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/146-ordenes-estado-pendiente/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Toda orden nueva, sin importar el canal (QR, caja/mostrador, domicilio), debe nacer con
`status = "pendiente"` (reemplazando a `"recibida"`, que se elimina como valor válido), y
con un nuevo campo `payment_status = "UNPAID"` salvo que el pago se confirme en el mismo
acto de creación. El frontend deja de inferir o traducir el estado mostrado: muestra
siempre el valor crudo de `status` (y de `estado_cocina` para ítems), con una lista
estática de estados conocidos usada solo para detectar y loguear valores no mapeados.

Hallazgos de la investigación técnica que cambian el alcance real respecto a una lectura
superficial del spec:

- **No existe `payment_status` hoy** en `pos-backend` (el pago se infiere de
  `CustomerOrder.status == "pagada"` y de `OrderPaymentAttempt.status`). Decisión del
  usuario (ver sección Clarifications de planificación): se añade una columna real
  `payment_status` nueva (migración + plan de rollback, Principio VIII).
- **Caja/mostrador y domicilio hoy crean la orden directamente en `"abierta"`** (confirmada,
  con descuento de inventario inmediato), saltándose `"recibida"` salvo en el caso raro
  `hold_for_payment`. Hacer que *todo* canal nazca en `"pendiente"` es un cambio de
  comportamiento real para caja/domicilio, no solo un renombrado. Decisión del usuario:
  se trata como cambio de comportamiento en alcance, registrado en
  `specs/000-reconocimiento/registro-de-anomalias.md` (Principio II) antes de implementar.
- **`OrderItem` no tiene un estado "recibida" propio** — su único campo de estado es
  `estado_cocina`, que ya nace en `"pendiente"` hoy. FR-003 ya se cumple para ítems; no
  requiere cambio de modelo, solo verificación/characterization test.
- El frontend tiene **dos mecanismos de inferencia** que violan FR-008 y deben eliminarse o
  acotarse: `displayOrderStatus()` (sustituye el estado por `"pagada"` si `order.paid` es
  verdadero) y `deriveTableStatus()` (sintetiza un estado de mesa/tarjeta de orden a partir
  de `status`, `channel`, `paid` y los `estado_cocina` de los ítems, y alimenta también el
  `statusLabel` de las tarjetas de orden dentro del panel de mesas). Decisión técnica de
  este plan: la tarjeta de **mesa** (agregado de varias órdenes) puede seguir existiendo
  como una heurística de **ocupación de mesa**, pero deja de llamarse o presentarse como
  "estado de la orden"; toda vista que muestre el estado de **una orden o ítem específico**
  (lista de órdenes, detalle de pedido, tarjetas de orden dentro del panel de mesas, filas
  de ítems) deja de pasar por `deriveTableStatus`/`displayOrderStatus` y usa el valor crudo.

## Technical Context

**Language/Version**: Python 3.11 (pos-backend, FastAPI) · TypeScript / Angular (pos-heladeria)

**Primary Dependencies**: FastAPI, SQLAlchemy 2.x, Alembic (pos-backend); Angular (standalone
components, signals), Vitest (`@angular/build:unit-test`) (pos-heladeria)

**Storage**: PostgreSQL 16, schema-per-tenant (`shared.tenants` + un esquema físico por
tenant, más `tenant_default`); estado de orden e ítem se guardan como `VARCHAR` + `CHECK
constraint` (no ENUM nativo de Postgres)

**Testing**: `unittest`-style characterization tests en `app/characterization_tests/`
(pos-backend, corridos contra una base real); Vitest con sintaxis Jasmine
(`describe/it/expect`) en specs co-localizados por componente/servicio (pos-heladeria)

**Target Platform**: Linux server (API), navegador (frontend Angular)

**Project Type**: Web application — backend (`../pos-backend`) + frontend (`../pos-heladeria`)

**Performance Goals**: N/A — no se introduce una ruta de alto volumen nueva; el cambio es de
valores de estado y de una columna nueva, no de carga transaccional

**Constraints**: Migración debe ejecutarse automáticamente durante `alembic upgrade head`,
recorriendo `tenant_default` + cada esquema de `shared.tenants` (patrón existente
`for_each_tenant_schema`), sin pasos manuales; no debe alterar facturas ya emitidas
(Principio VII) ni el significado histórico de órdenes ya `"pagada"`/`"cancelada"`

**Scale/Scope**: 2 repositorios (`pos-backend`, `pos-heladeria`); cambia 1 CHECK constraint +
1 columna nueva + ~10 archivos de servicio/router en backend; ~6 archivos de utilidades/
store + renombrado de literal en ~12 specs en frontend

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principio I (Spec primero)**: PASS. `specs/146-ordenes-estado-pendiente/spec.md` existe,
  aprobado, con checklist de calidad en verde.
- **Principio II (Comportamiento existente protegido)**: GATE CONDICIONAL. Este plan modifica
  comportamiento existente en dos puntos: (a) caja/mostrador y domicilio dejan de crear
  órdenes directamente en `"abierta"` y pasan a nacer en `"pendiente"`; (b) se introduce una
  columna `payment_status` que no existía. Ambos cambios están explícitamente autorizados
  por FR-001/FR-002 del spec aprobado y por la decisión de planificación tomada con el
  usuario (ver Clarifications de planificación, abajo). **Antes de implementar**, ambos
  cambios deben quedar registrados en
  `specs/000-reconocimiento/registro-de-anomalias.md` con quién, cuándo, qué cambia, por
  qué, y qué funcionalidades se ven afectadas (confirmación de pago en caja, descuento de
  inventario inmediato en caja/domicilio).
- **Principio III (Characterization tests)**: GATE CONDICIONAL. Existen characterization
  tests que fijan el comportamiento actual de `"recibida"`/`"abierta"` en
  `app/characterization_tests/` (p. ej. `test_orders_service.py`,
  `test_orders_checkout.py`, `test_cash_close_active_orders.py`, y posiblemente otros — se
  debe correr `grep -rn "recibida" app/characterization_tests` antes de tocar código). Los
  que fijan el comportamiento de creación en `"abierta"`/`"recibida"` deben actualizarse
  explícitamente citando la decisión de negocio registrada (Principio II), no solo para
  hacer pasar el código nuevo.
- **Principio IV (Nuevo comportamiento vía spec)**: PASS. El cambio de comportamiento está
  definido por el spec aprobado.
- **Principio V (Sin refactors oportunistas)**: PASS con vigilancia — `pos-terminal.store.ts`
  tiene lógica de inferencia (`deriveTableStatus`) que mezcla la preocupación de este spec
  (no inferir estado de orden) con la preocupación de "estado agregado de mesa", que es
  legítima y no debe tocarse más de lo necesario para dejar de alimentar `statusLabel` de
  tarjetas de orden individuales.
- **Principio VI (Evolución incremental)**: PASS — se divide en 3 unidades verificables
  (ver User Stories P1/P1/P2 del spec): (1) backend status+payment_status en creación, (2)
  migración + eliminación de `"recibida"`, (3) frontend sin traducción/inferencia. No se
  mezclan en un único commit/PR.
- **Principio VII (Compatibilidad con datos históricos)**: PASS con guardas explícitas — la
  migración solo reescribe `status = 'recibida' → 'pendiente'`; no toca órdenes en
  `'pagada'`/`'cancelada'`/`'abierta'`/`'bloqueada'`, ni recalcula montos ni facturas.
- **Principio VIII (Evolución del modelo de datos)**: GATE — ver `data-model.md`: define
  explícitamente la columna nueva `payment_status`, sus valores, default, estrategia de
  migración (backfill) y estrategia de rollback (downgrade de Alembic que revierte el CHECK
  y recalcula `status` hacia `'recibida'` donde aplique, y elimina la columna
  `payment_status`).
- **Principio IX (Dependencias nuevas)**: PASS — no se introduce ninguna dependencia nueva en
  ningún repositorio.
- **Principio X (Verificación obligatoria)**: PASS — ver `quickstart.md` y tareas de test que
  generará `/speckit-tasks`.
- **Principio XI (Negocio vs técnico)**: PASS — las dos decisiones de comportamiento
  (caja/domicilio naciendo en pendiente; nueva columna payment_status) se tomaron
  explícitamente con el usuario durante esta sesión de planificación, no por iniciativa
  técnica unilateral.
- **Principio XII (Trazabilidad)**: PASS — spec → esta sesión de planificación (decisiones
  documentadas aquí) → registro de anomalías (pendiente, antes de implementar) →
  implementación → tests → verificación.
- **Principios XIV/XV (Ramas y commits Git)**: N/A en fase de planificación — se aplican al
  iniciar la implementación (`/speckit-tasks` → `/speckit-implement`): crear rama
  `feat/146-ordenes-estado-pendiente` en cada repo antes de tocar código, commits en inglés
  bajo pedido explícito del usuario.

**Resultado de la gate**: No hay violaciones sin justificar. Las dos gates condicionales
(Principios II y III) tienen una ruta de cumplimiento clara y deben resolverse como
prerrequisito de implementación (registrar la decisión de negocio **antes** de tocar
código), no como bloqueo de este plan.

## Clarifications de planificación

### Sesión 2026-11-01 (durante `/speckit-plan`)

- Q: FR-002 exige un `payment_status` explícito, pero `pos-backend` no tiene esa columna hoy
  (el pago se infiere de `status == 'pagada'` + `OrderPaymentAttempt.status`). → A: Se añade
  una columna nueva `payment_status` real en `CustomerOrder`, con migración y estrategia de
  rollback (Principio VIII), en vez de derivarlo solo en la capa de API.
- Q: FR-001 exige que *todo* canal nazca en PENDIENTE, pero hoy caja/mostrador y domicilio
  crean la orden directamente en `"abierta"` (confirmada, con descuento de inventario
  inmediato), salvo el caso `hold_for_payment`. → A: Se trata como cambio de comportamiento
  en alcance de este spec (no como un gap a devolver a `/speckit-clarify`), registrado en
  `specs/000-reconocimiento/registro-de-anomalias.md` antes de implementar (Principio II).

## Project Structure

### Documentation (this feature)

```text
specs/146-ordenes-estado-pendiente/
├── plan.md              # Este archivo (/speckit-plan)
├── research.md          # Fase 0 (/speckit-plan)
├── data-model.md         # Fase 1 (/speckit-plan)
├── quickstart.md         # Fase 1 (/speckit-plan)
├── contracts/            # Fase 1 (/speckit-plan)
└── tasks.md              # Fase 2 (/speckit-tasks — no generado por /speckit-plan)
```

### Source Code (repository root)

```text
../pos-backend/
├── app/
│   ├── models/
│   │   └── customer_order.py        # status column + CHECK constraint, nueva columna payment_status
│   ├── api/v1/orders/
│   │   ├── schemas.py                # OrderStatus enum, nuevo PaymentStatus enum
│   │   ├── service.py                # create_order: status/payment_status en creación (caja/domicilio)
│   │   ├── checkout.py               # confirm_order, checkout_and_send: transiciones de estado
│   │   └── router.py                 # comentarios/validaciones de estado
│   ├── api/v1/cart/
│   │   └── service.py                # submit_cart: status/payment_status en creación (QR)
│   ├── api/v1/cash/
│   │   └── active_orders.py          # filtros de estados no terminales
│   ├── api/v1/table_sessions/
│   │   └── service.py                # filtros por status == 'recibida'
│   ├── scripts/
│   │   └── tenant.py                 # for_each_tenant_schema (reutilizado por la migración)
│   └── characterization_tests/       # tests existentes a actualizar explícitamente
└── alembic/versions/
    └── <nueva>_rename_recibida_to_pendiente_add_payment_status.py

../pos-heladeria/
└── src/app/modules/
    ├── orders/
    │   ├── order-status.util.ts      # ORDER_STATUS/KITCHEN_STATUS: quitar traducción, agregar detección+log
    │   ├── order-status.util.spec.ts
    │   ├── pages/orders-page.component.ts     # filtro 'recibida' → 'pendiente'
    │   └── pages/order-detail.component.ts    # quitar displayOrderStatus()
    ├── tables/
    │   ├── services/pos-terminal.store.ts     # deriveTableStatus: acotar a ocupación de mesa, no a statusLabel de orden
    │   ├── interfaces/dining.interface.ts     # DiningOrderStatus: 'recibida' → 'pendiente'
    │   ├── pages/checkout/checkout-hydration.guard.ts
    │   └── components/pos-checkout-panel.component.ts
    └── (specs afectados listados en research.md)
```

**Structure Decision**: Aplicación web con dos repositorios independientes y ya existentes
(`../pos-backend`, `../pos-heladeria`); no se crea una estructura nueva de proyecto, se
modifican archivos existentes en los módulos de órdenes/mesas de cada repo, siguiendo las
rutas reales identificadas en la investigación técnica (no las plantillas genéricas
Option 1/2/3).

## Complexity Tracking

> No hay violaciones de la constitución que requieran justificación de complejidad. Las dos
> gates condicionales (Principios II y III) se resuelven con el procedimiento estándar que la
> propia constitución define (registrar en `registro-de-anomalias.md` antes de implementar),
> no con una excepción.
