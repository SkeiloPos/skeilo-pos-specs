---

description: "Task list for spec 135 implementation"
---

# Tasks: Métodos distintos en pago mixto e ingresos de caja por método de pago

**Input**: Design documents from `/specs/135-pago-mixto-ingresos-caja/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/api.md, quickstart.md (all present)

**Tests**: Incluidos — el proyecto exige characterization tests (Principio III de la constitución) y
el plan/quickstart describen explícitamente casos nuevos a cubrir.

**Organization**: Tareas agrupadas por historia de usuario (US1/US2/US3) para permitir implementación
y prueba independiente de cada una.

**Repos**: todas las rutas son relativas a los repos hermanos de este repo de specs:
`pos-backend/` → `/home/deimer/Documents/projects/inventario/pos-backend/`
`pos-heladeria/` → `/home/deimer/Documents/projects/inventario/pos-heladeria/`

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Puede ejecutarse en paralelo (archivos distintos, sin dependencia de tareas incompletas)
- **[Story]**: US1, US2 o US3

---

## Phase 1: Setup

**Purpose**: Confirmar entorno y baseline antes de tocar código (sin infraestructura nueva — spec
reutiliza todo lo existente).

- [X] T001 Activar venv de `pos-backend` (`source env/bin/activate`), confirmar Postgres local
  disponible y correr baseline: `python -m unittest discover -s app/characterization_tests -p 'test_*.py'`
  (memoria de sesión `how-to-run-sibling-repo-tests`)
- [X] T002 [P] Confirmar que `pos-backend/alembic/versions/fe71d444fb50_123_addition_tracking_and_sale_kind.py`
  es el head actual (`alembic heads`) — la nueva migración (T012) encadena su `down_revision` ahí
- [X] T003 [P] Capturar baseline de frontend corriendo los 4 specs afectados en `pos-heladeria`
  (`ng test --include='**/payment-draft.util.spec.ts' --include='**/payment-input.component.spec.ts' --include='**/cash-movement-modal.component.spec.ts' --include='**/cash-session.store.spec.ts'`)
  para comparar diff, no conteo total (baseline flaky, memoria `how-to-run-sibling-repo-tests`)

**Checkpoint**: entorno verificado, ningún archivo de producción tocado aún.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Infraestructura compartida mínima que usan tanto US1 como US3 (mismo criterio de
rechazo "métodos distintos", mismo texto de mensaje — research.md D1).

**⚠️ CRITICAL**: T004 debe completarse antes de T006 (US1) y T023 (US3).

- [X] T004 Crear validador compartido `assert_distinct_payment_methods(lines, entity_label)` en
  nuevo archivo `pos-backend/app/api/v1/sales/payment_validation.py`: recibe una lista de objetos
  con `payment_method_id` (y sus nombres de método, vía `PaymentMethod`), si hay dos o más con el
  mismo `payment_method_id` lanza `HTTPException(422, detail=f"El método de pago «{nombre}» no
  puede usarse en más de una línea de este {entity_label}.")` (FR-002/FR-006, mismo texto para
  "cobro" e "ingreso")

**Checkpoint**: helper compartido listo — US1 y US3 pueden implementarse en paralelo si hay más de
un desarrollador (US2 no depende de T004).

---

## Phase 3: User Story 1 - El cajero no puede registrar un pago de pedido con el mismo método repetido (Priority: P1) 🎯 MVP

**Goal**: Rechazar cualquier cobro de pedido/mostrador (mostrador, cierre unificado, cierre
dividido, `pay_order` legacy) cuyas 2 o 3 líneas de pago repitan método.

**Independent Test**: Intentar guardar un cobro con 2 líneas del mismo método → rechazado con
mensaje claro; con métodos distintos → se guarda sin problema (acceptance scenarios 1-4 de spec.md).

### Tests for User Story 1

- [X] T005 [P] [US1] Agregar caso de rechazo (2 líneas mismo método; 3 líneas donde 2 repiten) y
  caso de control (métodos distintos, sin regresión) a
  `pos-backend/app/scripts/test_mixed_payment_checkout.py`
- [X] T007 [P] [US1] Agregar characterization test
  `pos-backend/app/characterization_tests/test_sales_duplicate_payment_method.py` cubriendo las 3
  rutas que llegan a `build_sale` (`PayIn.payments`, `CheckoutAndSendIn.payments`,
  `SaleCreate.payments`): todas rechazan con 422 y 0 filas `Payment` creadas cuando repiten método

### Implementation for User Story 1

- [X] T006 [US1] Implementar la validación de métodos distintos en el bucle de creación de
  `Payment` de `build_sale` (`pos-backend/app/api/v1/sales/builder.py:215-223`), invocando
  `assert_distinct_payment_methods(payments, "cobro")` (T004) antes de crear cualquier fila
  `Payment` (FR-001/FR-002/FR-003) — depends on T004
- [X] T008 [P] [US1] Agregar el paso 3 (nuevo) de `paymentIssue()` en
  `pos-heladeria/src/app/modules/tables/services/payment-draft.util.ts:172-195`: dos o más líneas
  con el mismo `methodId` → `"[Método] no puede usarse en más de una línea."`, insertado antes de
  la validación de saldo pendiente (orden exacto en data-model.md)
- [X] T009 [US1] En el `<select>`/`@for` de métodos de
  `pos-heladeria/src/app/modules/tables/components/payment-input.component.ts:66-76`, filtrar los
  métodos ya elegidos en otra línea del mismo borrador (conservando la selección propia de la
  línea actual en la lista)
- [X] T010 [P] [US1] Actualizar
  `pos-heladeria/src/app/modules/tables/services/payment-draft.util.spec.ts` y
  `pos-heladeria/src/app/modules/tables/components/payment-input.component.spec.ts` con casos de
  rechazo por método repetido y de filtrado del selector

**Checkpoint**: US1 funcional y probable de forma independiente — ningún cobro de pedido admite
líneas con método repetido, en backend y frontend.

---

## Phase 4: User Story 2 - El cajero registra un ingreso de caja en un método distinto a efectivo (Priority: P1)

**Goal**: Permitir registrar un ingreso de caja de una sola línea en cualquier método activo del
catálogo (no solo efectivo), sin afectar el efectivo esperado ni egreso/retiro.

**Independent Test**: Registrar un ingreso de $50.000 en Nequi → queda guardado con ese método,
visible en historial y en `ingresos_by_method` del arqueo, sin alterar el efectivo esperado
(acceptance scenarios 1-4 de US2 en spec.md).

### Implementation for User Story 2

- [X] T011 [P] [US2] Agregar columnas `payment_method_id` (UUID, FK → `tenant.payment_methods.id`,
  `NOT NULL` tras backfill) y `group_id` (UUID, nullable) al modelo `CashMovement`
  (`pos-backend/app/models/cash_movement.py:10-45`)
- [X] T012 [US2] Crear migración Alembic
  `pos-backend/alembic/versions/<hash>_135_cash_movement_payment_method.py` con
  `down_revision='fe71d444fb50'`: agregar `payment_method_id` nullable, backfill por tenant con el
  `PaymentMethod` `is_cash=True`, alterar a `NOT NULL`, agregar `group_id` nullable sin backfill,
  índice sobre `payment_method_id`; `downgrade()` elimina ambas columnas e índice (research.md D4)
  — depends on T011
- [X] T013 [P] [US2] Agregar `CashMovementLineIn` (`payment_method_id: UUID`,
  `amount: Decimal gt=0`) y extender `CashMovementIn` con `lines: list[CashMovementLineIn] | None`
  (`min_length=1, max_length=2`), manteniendo `amount: Decimal | None` para compatibilidad, en
  `pos-backend/app/api/v1/cash/schemas.py:85-89`
- [X] T014 [P] [US2] Extender `CashMovementResponse` con `payment_method_id: UUID` y
  `group_id: UUID | None` en `pos-backend/app/api/v1/cash/schemas.py:92-102`
- [X] T015 [P] [US2] Agregar campo `ingresos_by_method: list[SalesByMethod]` a
  `ReconciliationResponse` en `pos-backend/app/api/v1/cash/schemas.py:117-139` (reutiliza el DTO
  `SalesByMethod`, sin ceros rellenados — FR-008)
- [X] T016 [US2] Actualizar `add_movement`
  (`pos-backend/app/api/v1/cash/router.py:401-414`): exactamente uno de `amount`/`lines` presente;
  `kind in ('egreso','retiro')` exige `amount` y rechaza `lines` (fuerza método `is_cash=True` del
  tenant automáticamente); `kind='ingreso'` con `amount` (sin `lines`) → 1 fila en efectivo
  (compatibilidad, FR-009); `kind='ingreso'` con `lines` de 1 elemento → 1 fila con cualquier método
  activo del tenant (FR-004); respuesta cambia a `response_model=list[CashMovementResponse]`
  — depends on T011, T013, T014
- [X] T017 [US2] Actualizar `reconcile()` (`pos-backend/app/api/v1/cash/service.py:201-210`): unir
  con `PaymentMethod` y agrupar también por `is_cash`; `ingresos` (el que entra en `expected`) solo
  suma `kind='ingreso' AND is_cash=True` (FR-007); segunda consulta agrupada por
  `payment_method_id` para filas `is_cash=False` alimenta `ingresos_by_method` (FR-008)
  — depends on T011, T015
- [X] T018 [P] [US2] Agregar characterization test
  `pos-backend/app/characterization_tests/test_cash_movement_non_cash_income.py`: ingreso de 1
  línea en método no-efectivo crea 1 fila `CashMovement` con `group_id=None`, `expected` del
  arqueo no cambia, `ingresos_by_method` incluye el método con su total; control: ingreso en
  efectivo se comporta idéntico al actual (FR-009)
- [X] T019 [P] [US2] Agregar `lines?: { paymentMethodId: string; amount: number }[]` a
  `CashMovementPayload` en
  `pos-heladeria/src/app/modules/cash-register/interfaces/cash.interface.ts:33-38`
- [X] T020 [US2] Agregar selector de método de pago (poblado vía
  `GET /sales/payment-methods?available=true`, reutilizado) al formulario de tipo "Ingreso" en
  `pos-heladeria/src/app/modules/cash-register/components/cash-movement-modal.component.ts:16-77`
  — depends on T019
- [X] T021 [US2] Actualizar `confirmarMovimiento()`
  (`pos-heladeria/src/app/modules/cash-register/services/cash-session.store.ts:528-550`): cuando
  `kind='ingreso'` y hay un método seleccionado, enviar `lines: [{ paymentMethodId, amount }]` en
  vez de `amount` plano; egreso/retiro y el camino de compatibilidad sin selector no cambian
  — depends on T019, T020
- [X] T022 [P] [US2] Actualizar
  `pos-heladeria/src/app/modules/cash-register/components/cash-movement-modal.component.spec.ts` y
  `.../cash-register/services/cash-session.store.spec.ts` con casos de selector de método e
  ingreso no-efectivo

**Checkpoint**: US2 funcional de forma independiente — ingreso de 1 línea en cualquier método
activo, efectivo/egreso/retiro sin cambios.

---

## Phase 5: User Story 3 - El cajero registra un ingreso mixto en dos métodos distintos (Priority: P2)

**Goal**: Permitir que un ingreso se componga de 2 líneas con métodos distintos, agrupadas por
`group_id`, rechazando el mismo método repetido en ambas.

**Independent Test**: Registrar un ingreso con 2 líneas (Efectivo + Nequi) → ambas quedan con el
mismo `group_id`, efectivo esperado sube solo por la porción efectivo; 2 líneas del mismo método →
rechazado (acceptance scenarios 1-4 de US3 en spec.md).

### Implementation for User Story 3

- [X] T023 [US3] Extender `add_movement`
  (`pos-backend/app/api/v1/cash/router.py:401-414`, mismo bloque de T016): `kind='ingreso'` con
  `lines` de 2 elementos genera un `group_id` compartido para ambas filas y llama
  `assert_distinct_payment_methods(lines, "ingreso")` (T004) antes de crear cualquiera de las 2
  filas (FR-005/FR-006/FR-011) — depends on T016, T004
- [X] T024 [P] [US3] Agregar characterization test
  `pos-backend/app/characterization_tests/test_cash_movement_mixed_income.py`: ingreso mixto de 2
  líneas (Efectivo $20.000 + Nequi $30.000) crea 2 filas con el mismo `group_id`, `expected` sube
  solo $20.000, `ingresos_by_method` refleja $30.000 en Nequi; control de rechazo: 2 líneas con el
  mismo método → 422, 0 filas creadas; control: 3 líneas → 422 de Pydantic (`max_length=2`)
- [X] T025 [US3] Agregar control "Agregar otro método" (máx. 2 líneas, solo visible para tipo
  "Ingreso") en
  `pos-heladeria/src/app/modules/cash-register/components/cash-movement-modal.component.ts`,
  filtrando del segundo selector el método ya elegido en la primera línea (mismo patrón que T009);
  deshabilitado/oculto si el tenant tiene menos de 2 métodos activos (FR-013) — depends on T020
- [X] T026 [US3] Extender `confirmarMovimiento()` en `cash-session.store.ts` para enviar 2 `lines`
  cuando se agrega un segundo método, y exponer el `group_id` resultante para que el historial del
  turno agrupe visualmente las 2 filas (FR-011) — depends on T021
- [X] T027 [P] [US3] Actualizar `cash-movement-modal.component.spec.ts` y
  `cash-session.store.spec.ts` con casos de ingreso mixto, rechazo por método repetido, y tenant
  con un solo método activo (FR-013)

**Checkpoint**: Las 3 historias de usuario son funcionales y probables de forma independiente.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Verificación de no regresión across todas las historias (quickstart.md).

- [X] T028 [P] Correr suite de no regresión completa en `pos-backend`: `python -m unittest
  discover -s app/characterization_tests -p 'test_*.py'`, `python -m
  app.scripts.test_mixed_payment_checkout`, `python -m app.scripts.test_split_blindaje`, y
  `python -m app.scripts.test_cash_net_sales` si existe (confirma que la fórmula de `expected` no
  cambió, solo su fuente de `ingresos`)
- [X] T029 [P] Correr diff de specs de frontend afectados en `pos-heladeria` contra el baseline de
  T003 (no el conteo total de la suite, memoria `how-to-run-sibling-repo-tests`)
- [ ] T030 Ejecutar manualmente los pasos de `quickstart.md` (US1, US2, US3) en el Terminal POS con
  un tenant de prueba con ≥2 métodos activos (uno `is_cash=True`), confirmando SC-001 a SC-004

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias — puede iniciar de inmediato
- **Foundational (Phase 2)**: sin dependencias de Setup; bloquea T006 (US1) y T023 (US3) —
  **no bloquea US2**, que no usa el validador compartido (su ingreso de 1 línea no tiene nada que
  comparar)
- **US1 (Phase 3)**: depende de T004 (Foundational)
- **US2 (Phase 4)**: depende solo de Setup — puede avanzar en paralelo con US1 y con Foundational
- **US3 (Phase 5)**: depende de T004 (Foundational) y de T016/T020/T021 (US2) — no es
  independiente a nivel de código (reutiliza el mismo endpoint y el mismo modal que US2), pero sí
  es independientemente probable una vez esas tareas existen
- **Polish (Phase 6)**: depende de que US1 y US2 (mínimo) estén completas; US3 recomendado

### Parallel Opportunities

- T001/T002/T003 (Setup) en paralelo
- US1 y US2 pueden implementarse en paralelo por desarrolladores distintos tras T004 (no se tocan
  archivos en común)
- Dentro de US2: T011/T013/T014/T015/T019 en paralelo (archivos distintos); T012/T016/T017/T020/T021
  son secuenciales por depender de las anteriores
- Tests marcados [P] en cada historia pueden correr en paralelo con la implementación de esa misma
  historia si se escriben primero (TDD), o después como verificación

---

## Implementation Strategy

### MVP First (User Story 1)

1. Completar Phase 1 (Setup) y Phase 2 (Foundational — solo T004)
2. Completar Phase 3 (US1) → validar de forma independiente con el script y specs de T005/T007/T010
3. Esta es la entrega mínima que satisface SC-001 (mitad: pedidos) y revierte A-146

### Incremental Delivery

1. Setup + Foundational → base lista
2. US1 → cobros de pedido sin método repetido (MVP del cambio de validación)
3. US2 → ingresos de caja en cualquier método (1 línea) — satisface SC-002/SC-003 para el caso
   simple
4. US3 → ingresos mixtos de caja (2 líneas) — completa SC-001 (mitad: ingresos) y SC-002 para el
   caso mixto
5. Polish → confirma SC-004 (egreso/retiro sin cambios) y no regresión general
