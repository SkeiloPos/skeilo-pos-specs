---

description: "Task list template for feature implementation"
---

# Tasks: Instrucciones de Pago del Menú QR por Modalidad del Plan

**Input**: Design documents from `/specs/154-instrucciones-pago-menu-qr/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/plan-qr-payment-instruction.md, quickstart.md

**Tests**: Characterization tests (backend) y specs Jasmine (frontend) se extienden/crean como
parte de cada historia — este codebase los trata como protección de comportamiento, no como
TDD opcional (Principio III/X de la constitución), así que se incluyen en las tareas de
implementación de cada historia, no en una fase separada.

**Organization**: Tareas agrupadas por historia de usuario (US1/US2/US3 de spec.md). Rutas
relativas a cada repo: `pos-backend/` y `pos-heladeria/` (siblings de `pos-specs/`).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Puede ejecutarse en paralelo (archivos distintos, sin dependencias)
- **[Story]**: US1, US2 o US3
- Rutas de archivo exactas en cada descripción

---

## Phase 1: Setup

No se requiere inicialización de proyecto nueva — ambos repos (`pos-backend`, `pos-heladeria`)
ya existen con su stack configurado (Technical Context de plan.md). Esta fase queda vacía.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: La columna `Plan.modalidad_pago_qr` y su migración son la única fuente de verdad;
deben existir antes de que cualquier historia pueda leerla o escribirla.

- [X] T001 Agregar columna `modalidad_pago_qr` (`String(30)`, `NOT NULL`,
  `CheckConstraint IN ('PAY_AFTER_RECEIVING', 'PAY_BEFORE_RECEIVING')`, default
  `'PAY_AFTER_RECEIVING'`) al modelo `Plan` en `pos-backend/app/models/plan.py`, junto a las
  columnas existentes (data-model.md, research.md Decisión 2)
- [X] T002 Crear migración Alembic nueva en `pos-backend/alembic/versions/`
  (`{rev}_154_plans_add_modalidad_pago_qr.py`), encadenada sobre el head actual
  (`019b97e8a107`): `op.add_column("plans", sa.Column("modalidad_pago_qr", sa.String(30),
  nullable=False, server_default="PAY_AFTER_RECEIVING"), schema="shared")` +
  `op.create_check_constraint("ck_plans_modalidad_pago_qr", "plans", "modalidad_pago_qr IN
  ('PAY_AFTER_RECEIVING', 'PAY_BEFORE_RECEIVING')", schema="shared")`; `downgrade()` hace
  `op.drop_constraint("ck_plans_modalidad_pago_qr", "plans", schema="shared", type_="check")`
  antes de `op.drop_column(...)` (research.md Decisión 7, memory del proyecto sobre el gotcha
  de nombrado de constraints)
- [X] T003 Ejecutar `alembic upgrade head` y `alembic downgrade -1` seguido de
  `alembic upgrade head` otra vez desde `pos-backend/` para confirmar que la migración corre
  limpia en ambas direcciones (quickstart.md, "Verificación de migración")

**Checkpoint**: La columna existe en la base de datos; las historias pueden empezar.

---

## Phase 3: User Story 1 - El Super Admin define la modalidad de pago del plan (Priority: P1) 🎯 MVP

**Goal**: El Super Admin puede fijar `modalidad_pago_qr` al crear/editar un plan desde los
endpoints de Super Admin existentes, sin que ningún rol de administración del tenant la vea.

**Independent Test**: `POST`/`PATCH /super-admin/plans` con `modalidad_pago_qr`, y `GET /plan`
como ADMIN de tenant confirmando que la clave no aparece en ningún nivel del JSON.

### Implementation for User Story 1

- [X] T004 [P] [US1] Agregar `modalidad_pago_qr: Literal["PAY_AFTER_RECEIVING",
  "PAY_BEFORE_RECEIVING"] = "PAY_AFTER_RECEIVING"` a `PlanCreate`,
  `modalidad_pago_qr: Optional[Literal["PAY_AFTER_RECEIVING", "PAY_BEFORE_RECEIVING"]] = None`
  a `PlanUpdate`, y `modalidad_pago_qr: Literal["PAY_AFTER_RECEIVING", "PAY_BEFORE_RECEIVING"]`
  a `PlanResponse`, en `pos-backend/app/api/v1/super_admin/schemas.py` (mismo patrón que
  `inventario_access`/`promociones_access`/`cocina_access`, contracts/plan-qr-payment-instruction.md)
- [X] T005 [US1] Confirmar en `pos-backend/app/api/v1/super_admin/plans_router.py` que
  `POST /super-admin/plans` y `PATCH /super-admin/plans/{id}` ya persisten cualquier campo de
  `PlanCreate`/`PlanUpdate` sobre el modelo `Plan` sin lista blanca que excluya
  `modalidad_pago_qr`; si existe una lista explícita de campos permitidos, agregarlo ahí
  (depende de T004)
- [X] T006 [US1] Confirmar en `pos-backend/app/api/v1/plan/schemas.py`
  (`ModuleAccess`/`PlanSummaryResponse`) y `pos-backend/app/api/v1/plan/service.py`
  (`build_plan_summary`) que ninguno de los dos agrega `modalidad_pago_qr` ni un alias — esta
  tarea es de verificación/no-regresión explícita de FR-004 (research.md Decisión 3), no se
  edita código de producción en `GET /plan`
- [X] T007 [US1] Extender `pos-backend/app/characterization_tests/test_super_admin_plans.py`
  con los casos: crear plan con `modalidad_pago_qr="PAY_BEFORE_RECEIVING"` → `201` con el valor
  persistido; crear sin enviarlo → `201` con `"PAY_AFTER_RECEIVING"`; crear con
  `modalidad_pago_qr="OTRO"` → `422`; `PATCH` que cambia de `PAY_BEFORE_RECEIVING` a
  `PAY_AFTER_RECEIVING` → `200` con el reemplazo completo (quickstart.md US1, pasos 1-4)
  (depende de T004, T005)
- [X] T008 [US1] Extender `pos-backend/app/characterization_tests/test_plan_summary.py` con un
  caso nuevo: `GET /plan` como ADMIN de un tenant con un plan en `PAY_BEFORE_RECEIVING` → la
  respuesta no contiene `modalidad_pago_qr` ni ninguna clave equivalente en ningún nivel del
  JSON (quickstart.md US1, paso 5; FR-004) (depende de T006)
- [X] T009 [US1] Ejecutar `python -m unittest app.characterization_tests.test_super_admin_plans
  app.characterization_tests.test_plan_summary -v` desde `pos-backend/` (venv `env`) y confirmar
  todo en verde (depende de T007, T008)
- [X] T010 [P] [US1] Agregar `modalidad_pago_qr: 'PAY_AFTER_RECEIVING' | 'PAY_BEFORE_RECEIVING'`
  a la interfaz `Plan` y `modalidad_pago_qr?: 'PAY_AFTER_RECEIVING' | 'PAY_BEFORE_RECEIVING'` a
  `PlanCreatePayload` en
  `pos-heladeria/src/app/modules/super-admin/interfaces/plan.interface.ts`
- [X] T011 [US1] Agregar un control nuevo tipo radio/select de dos opciones ("Pago después de
  recibir" = `PAY_AFTER_RECEIVING` / "Pago antes de recibir" = `PAY_BEFORE_RECEIVING") con
  `formControlName="modalidad_pago_qr"` en
  `pos-heladeria/src/app/modules/super-admin/components/plan-form.component.ts`, como control
  independiente de los checkboxes de módulo existentes (research.md Decisión 6) (depende de
  T010)

**Checkpoint**: El Super Admin puede fijar la modalidad por plan; ningún rol de tenant la ve en
`GET /plan`. Historia 1 completamente funcional y testeable de forma independiente.

---

## Phase 4: User Story 2 - El comensal ve la instrucción correcta según la modalidad del plan de su tenant (Priority: P1)

**Goal**: El comensal que envía una orden desde el menú QR ve, en la pantalla de confirmación,
el mensaje exacto que corresponde a `(modalidad del plan, método de pago elegido)`.

**Independent Test**: Fijar la modalidad de un plan y enviar una orden con cada método de pago
(efectivo/Nequi/mixto), verificando el mensaje mostrado en la confirmación.

**Depends on**: Foundational (Phase 2). Lee `Plan.modalidad_pago_qr` de US1 pero no requiere la
UI de Super Admin de US1 para probarse (puede fijarse el valor directamente en BD/fixture).

### Implementation for User Story 2

- [X] T012 [US2] Agregar `get_qr_payment_instruction_mode(db: Session, tenant: Tenant) -> str`
  a `pos-backend/app/api/v1/plan/service.py`, junto a `build_plan_summary`: hace
  `db.get(Plan, tenant.plan_id)` y devuelve `plan.modalidad_pago_qr` del plan vigente del
  tenant propietario (FR-005, research.md Decisión 4)
- [X] T013 [US2] Agregar `qr_payment_instruction_mode: Literal["PAY_AFTER_RECEIVING",
  "PAY_BEFORE_RECEIVING"] | None = None` a `OrderResponse` en
  `pos-backend/app/api/v1/orders/schemas.py`, junto a `paid`/`pending_balance`
- [X] T014 [US2] En `pos-backend/app/api/v1/cart/router.py`, asignar
  `order.qr_payment_instruction_mode = plan_service.get_qr_payment_instruction_mode(ctx.db,
  ctx.tenant)` sobre cada `CustomerOrder` devuelto por `submit_cart` y `my_orders`, antes de
  serializar — mismo patrón que `orders/router.py:73-77` para `paid`/`pending_balance` (depende
  de T012, T013)
- [X] T015 [US2] Extender `pos-backend/app/characterization_tests/test_cart_router.py` con
  casos para `POST /cart/submit` y `GET /cart/orders`: para cada combinación de
  `Plan.modalidad_pago_qr` (`PAY_AFTER_RECEIVING`/`PAY_BEFORE_RECEIVING`), la respuesta trae
  `qr_payment_instruction_mode` igual al valor del plan del tenant; y un `OrderResponse`
  devuelto por un endpoint de staff (p. ej. `GET /orders`) para la misma orden trae
  `qr_payment_instruction_mode: null` (quickstart.md US2 backend, pasos 1-3; FR-006/FR-013)
  (depende de T014)
- [X] T016 [US2] Ejecutar `python -m unittest app.characterization_tests.test_cart_router -v`
  desde `pos-backend/` (venv `env`) y confirmar todo en verde (depende de T015)
- [X] T017 [P] [US2] Agregar `qr_payment_instruction_mode?: 'PAY_AFTER_RECEIVING' |
  'PAY_BEFORE_RECEIVING' | null` a la interfaz `DiningOrder` en
  `pos-heladeria/src/app/modules/tables/interfaces/dining.interface.ts`
- [X] T018 [US2] Agregar la función pura `qrPaymentInstructionMessage(mode, attempt)` en
  `pos-heladeria/src/app/modules/tables/order-status.util.ts`, junto a
  `orderStatusLabel`/`orderStatusClass`, que resuelve las seis combinaciones de FR-007/FR-008
  (tabla completa en data-model.md, "Combinación modalidad + método de pago → mensaje exacto")
  y devuelve `null` para un método de pago fuera de efectivo/transferencia/mixto o
  `mode: null`/no reconocido (depende de T017)
- [X] T019 [US2] Extender
  `pos-heladeria/src/app/modules/tables/order-status.util.spec.ts` con casos para las seis
  combinaciones de `qrPaymentInstructionMessage` más el caso `mode: null`/método fuera de
  catálogo → `null` (depende de T018)
- [X] T020 [US2] En
  `pos-heladeria/src/app/modules/tables/pages/checkout/confirmation-step.component.ts`,
  reemplazar los tres literales de plantilla (líneas 82-83, 117, 126) por una sola llamada a
  `qrPaymentInstructionMessage(order.qr_payment_instruction_mode ?? 'PAY_AFTER_RECEIVING',
  order.current_payment_attempt)` (research.md Decisión 5, default de compatibilidad hacia
  atrás) (depende de T018)
- [X] T021 [US2] Crear
  `pos-heladeria/src/app/modules/tables/pages/checkout/confirmation-step.component.spec.ts`
  (nuevo, no existía spec dedicado) cubriendo: PAY_AFTER_RECEIVING × efectivo/Nequi/mixto (los
  tres mensajes actuales exactos), PAY_BEFORE_RECEIVING × efectivo/Nequi/mixto (los tres
  mensajes nuevos exactos), y `qr_payment_instruction_mode: null` → no se renderiza ninguna
  instrucción sin error (quickstart.md US2 frontend, pasos 1-5) (depende de T020)
- [X] T022 [US2] Ejecutar `ng test --include='**/confirmation-step.component.spec.ts'` y
  `ng test --include='**/order-status.util.spec.ts'` desde `pos-heladeria/` y confirmar ambos
  specs en verde (memory del proyecto: comparar por archivo afectado, baseline completa es
  flaky) (depende de T019, T021)

**Checkpoint**: El comensal ve el mensaje correcto para las seis combinaciones modalidad ×
método de pago. Historias 1 y 2 funcionan de forma independiente.

---

## Phase 5: User Story 3 - El cambio de modalidad del Super Admin se refleja de inmediato en los tenants del plan (Priority: P2)

**Goal**: Confirmar que el cómputo sin caché de US2 propaga un cambio de plan a todos sus
tenants de inmediato, sin afectar a tenants de otros planes ni a instrucciones ya mostradas.

**Independent Test**: Dos tenants en el mismo plan; cambiar la modalidad una vez desde el plan
y verificar que ambos ven el mensaje nuevo en órdenes nuevas, sin acción propia.

**Depends on**: US1 (para el `PATCH` de Super Admin) y US2 (para el cómputo en `OrderResponse`)
— esta historia no agrega código nuevo, solo characterization tests que verifican la propiedad
de propagación inmediata ya garantizada por el diseño sin caché de T012/T014.

### Implementation for User Story 3

- [X] T023 [US3] Extender `pos-backend/app/characterization_tests/test_cart_router.py` con un
  escenario de propagación: dos tenants suscritos al mismo plan en `PAY_AFTER_RECEIVING` →
  ambos reciben ese valor en `POST /cart/submit`; `PATCH /super-admin/plans/{id}` cambia el
  plan a `PAY_BEFORE_RECEIVING`; un nuevo `POST /cart/submit` de cada tenant → ambos reciben
  `PAY_BEFORE_RECEIVING` sin acción propia; un tercer tenant de un plan distinto no cambia
  (quickstart.md US3, pasos 1-4; Acceptance Scenarios 1-2 de US3) (depende de T014)
- [X] T024 [US3] En el mismo fichero, agregar el caso: una orden creada antes del `PATCH`, al
  volver a consultarse vía `GET /cart/orders` después del `PATCH`, refleja la modalidad nueva
  del plan (el campo se recalcula en cada lectura, nunca se persiste — quickstart.md US3, paso
  5; Acceptance Scenario 3 de US3, research.md Decisión 4) (depende de T014)
- [X] T025 [US3] Ejecutar `python -m unittest app.characterization_tests.test_cart_router -v`
  desde `pos-backend/` (venv `env`) y confirmar todo en verde, incluidos los casos nuevos de
  T023/T024 (depende de T023, T024)

**Checkpoint**: Las tres historias funcionan de forma independiente y en conjunto.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T026 Ejecutar la suite completa de characterization tests backend
  (`python -m unittest discover -s app/characterization_tests -p 'test_*.py' -v` desde
  `pos-backend/`, venv `env`) y confirmar que ningún test existente quedó en rojo (Principio
  III/X; depende de T009, T016, T025)
- [X] T027 Ejecutar `alembic upgrade head` y `alembic downgrade -1` una vez más desde
  `pos-backend/` tras completar todas las historias, confirmando ambas direcciones limpias
  (quickstart.md, "Verificación de migración"; depende de T026)
- [X] T028 Revisar el quickstart.md completo (US1 pasos 1-5, US2 backend pasos 1-3 + frontend
  pasos 1-5, US3 pasos 1-5) como checklist final de cierre de la spec (depende de T022, T025,
  T027)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: vacía, sin bloqueos.
- **Foundational (Phase 2)**: sin dependencias — BLOQUEA todas las historias (la columna debe
  existir antes de leerla o escribirla).
- **User Story 1 (Phase 3)**: depende de Foundational. Sin dependencia de US2/US3.
- **User Story 2 (Phase 4)**: depende de Foundational. Lee `Plan.modalidad_pago_qr` (columna de
  T001/T002), no de la UI de Super Admin de US1 — puede probarse fijando el valor directamente
  en BD/fixture sin que US1 esté implementada, pero en la práctica ambas son P1 y se entregan
  juntas.
- **User Story 3 (Phase 5)**: depende de US1 (T005, `PATCH` de Super Admin) y US2 (T014, cómputo
  sin caché) — es puramente de verificación, no agrega código nuevo.
- **Polish (Phase 6)**: depende de que las tres historias estén completas.

### Within Each User Story

- Backend: modelo/schema → service → router → characterization tests → ejecución.
- Frontend: interfaces TypeScript → función pura de utilidad → spec de la función → componente
  → spec del componente → ejecución `ng test`.

### Parallel Opportunities

- T004 (schemas Super Admin) puede avanzar en paralelo con T010 (interfaz TypeScript de Plan)
  — repos distintos.
- T017 (interfaz `DiningOrder`) puede avanzar en paralelo con el trabajo backend de US2
  (T012-T016) — repos distintos.
- Dentro de Foundational, T001 y T002 son secuenciales (la migración depende del modelo), pero
  distintos desarrolladores podrían preparar T002 mientras T001 se revisa.

---

## Parallel Example: User Story 2

```bash
# Backend (pos-backend) y frontend (pos-heladeria) en paralelo, repos distintos:
Task: "Agregar get_qr_payment_instruction_mode en app/api/v1/plan/service.py"
Task: "Agregar DiningOrder.qr_payment_instruction_mode en dining.interface.ts"
```

---

## Implementation Strategy

### MVP First (User Story 1 + User Story 2, ambas P1)

1. Completar Phase 2: Foundational (columna + migración).
2. Completar Phase 3: User Story 1 (Super Admin configura la modalidad).
3. Completar Phase 4: User Story 2 (el comensal ve el mensaje correcto).
4. **Validar**: ambas historias P1 juntas cubren el valor completo visible al negocio —
   configurar + ver el efecto.

### Incremental Delivery

1. Foundational → columna lista, sin efecto observable (default reproduce comportamiento
   actual, Principio II).
2. + US1 → Super Admin puede fijar la modalidad, aún sin efecto visible para el comensal (nadie
   la lee todavía en `cart/router.py`).
3. + US2 → el comensal empieza a ver el mensaje correcto; MVP completo.
4. + US3 → verificación explícita de que el cambio se propaga sin pasos manuales (sin código
   nuevo, solo tests).
5. Polish → suite completa + migración en ambas direcciones + checklist de quickstart.md.
