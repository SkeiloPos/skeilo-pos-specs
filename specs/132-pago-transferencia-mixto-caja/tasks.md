---

description: "Task list template for feature implementation"
---

# Tasks: Pago por transferencia y pago mixto sin subida de comprobante, con verificación del cajero

**Input**: Documentos de diseño de `/specs/132-pago-transferencia-mixto-caja/`

**Prerequisitos**: plan.md, spec.md, research.md, data-model.md, contracts/payment-attempts-api.md, quickstart.md

**Tests**: El spec no exige TDD explícitamente, pero plan.md y quickstart.md sí piden
characterization tests nuevos bajo `app/characterization_tests` (mismo runner que spec
024/130) y verificación manual por historia. Se incluyen tareas de test por historia porque
el contrato de API y las reglas de negocio (motivos cerrados, invariante de suma, reintento
único) son el tipo de comportamiento que este proyecto protege con characterization tests
(Principio III de la constitución).

**Organización**: Las tareas se agrupan por historia de usuario para permitir implementación
y prueba independientes de cada una.

## Rutas de los dos repos hermanos (fuera de `pos-specs`)

- Backend: `../pos-backend/app/...`
- Frontend: `../pos-heladeria/src/app/modules/tables/...`

## Phase 1: Setup

**Purpose**: Registrar la decisión de negocio pendiente (Principio II) antes de tocar código.

- [X] T001 Registrar la decisión de negocio del cambio de comportamiento de
  `receipt_file_url` (de requerido a evidencia opcional del cajero) en
  `specs/000-reconocimiento/registro-de-anomalias.md`, citando spec 132, FR-001/002/012/023 y
  research.md Decisión 1, antes de modificar `approve_payment_attempt`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Cambios de esquema y de contrato compartidos por todas las historias de usuario.

**⚠️ CRITICAL**: Ninguna historia puede implementarse hasta que esta fase esté completa.

- [X] T002 Auditar valores actuales de `rejection_reason` en
  `tenant.order_payment_attempts` (todos los tenants) para detectar texto libre fuera del
  conjunto cerrado de 5 valores, documentando el resultado como entrada para la migración de
  T003
- [X] T003 Crear migración Alembic `<hash>_132_rejection_reason_enum.py` en
  `../pos-backend/alembic/versions/` que: (a) normaliza en la misma transacción los valores de
  `rejection_reason` fuera del conjunto cerrado a `comprobante_sospechoso` (dejando constancia
  en el mensaje de la revisión, Principio VII), y (b) agrega un `CheckConstraint` que restringe
  `rejection_reason` a `cliente_no_muestra_app`, `monto_no_coincide`,
  `transferencia_no_completada`, `cliente_se_niega_a_mostrar`, `comprobante_sospechoso` cuando
  `status = 'rechazado'`; `downgrade()` elimina el `CheckConstraint`
- [X] T004 Definir el enum cerrado de motivos de rechazo (`RejectionReason`) en
  `../pos-backend/app/models/order_payment_attempt.py` o módulo compartido de enums, para
  reutilizarlo tanto en el modelo como en `schemas.py`
- [X] T005 [P] Agregar `PaymentAttemptRejectIn.reason` como `Enum`/`Literal` cerrado (los 5
  valores de T004) en `../pos-backend/app/api/v1/orders/schemas.py`, retornando `422` si el
  valor no pertenece al conjunto
- [X] T006 [P] Agregar schema `PaymentAttemptAdjustSplitIn` (`cash_amount: int >= 0`,
  `transfer_amount: int >= 0`, `transfer_method_id: UUID | None`, `payment_method_id: UUID |
  None`) en `../pos-backend/app/api/v1/orders/schemas.py`

**Checkpoint**: Esquema y contratos base listos; las historias de usuario pueden empezar.

---

## Phase 3: User Story 1 - Comensal paga 100% por transferencia desde el QR (Priority: P1) 🎯 MVP

**Goal**: El comensal puede elegir transferencia total desde el QR y confirmar el pedido sin
subir ningún archivo, viendo el monto exacto y la instrucción de referencia.

**Independent Test**: Crear un pedido en el QR, elegir "Transferencia", confirmar sin adjuntar
archivo, y verificar que el pedido queda en espera de pago con un único registro de pago por el
total.

### Tests for User Story 1

- [X] T007 [P] [US1] Characterization test: creación de un intento de transferencia 100%
  desde el flujo QR sin `receipt_file_url` en el body es aceptada (antes requería el campo) en
  `../pos-backend/app/characterization_tests/test_payment_attempt_transfer_no_receipt.py`

### Implementation for User Story 1

- [X] T008 [US1] En `../pos-backend/app/api/v1/orders/checkout.py`, en el endpoint de
  creación de intento de pago desde el QR, eliminar la aceptación/exigencia de
  `receipt_file_url` en el body cuando el actor es el comensal (FR-001, FR-023)
- [X] T009 [US1] En `../pos-heladeria/src/app/modules/tables/pages/checkout/transfer-details-step.component.ts`,
  retirar el paso de subida de comprobante (input de archivo, lógica de presign/upload) y
  mostrar únicamente el monto total a transferir junto con la instrucción de referencia
  (mesa/pedido) y el aviso de mostrar el comprobante al cajero en la entrega (FR-004, FR-008,
  FR-023)
- [X] T010 [US1] En `../pos-heladeria/src/app/modules/tables/services/diner.service.ts`,
  eliminar los métodos `uploadReceiptFile`/presign usados por este flujo de transferencia
  total y cualquier llamada residual desde `transfer-details-step.component.ts` (FR-023)
- [X] T011 [US1] Verificar/ajustar que el comensal puede confirmar el pedido (pasar a
  preparación) inmediatamente tras elegir transferencia, sin esperar ni rastrear si la
  transferencia ya ocurrió (FR-007), en el flujo de confirmación de
  `../pos-heladeria/src/app/modules/tables/pages/checkout/`

**Checkpoint**: La Historia 1 es funcional y verificable de forma independiente (incluyendo el
Escenario 1 de quickstart.md).

---

## Phase 4: User Story 2 - Comensal paga con pago mixto (efectivo + transferencia) desde el QR (Priority: P1)

**Goal**: El comensal puede elegir pago mixto, declarar el efectivo, ver el monto a transferir
calculado, y confirmar sin subir archivos, con validación de rango del efectivo.

**Independent Test**: Ingresar un monto de efectivo válido (0 < efectivo < total) en pago
mixto, confirmar sin archivos, y verificar que se crean los registros de pago cuya suma es
igual al total.

### Tests for User Story 2

- [X] T012 [P] [US2] Characterization test: creación de intento(s) de pago mixto desde el QR
  sin `receipt_file_url`, con la suma `cash_amount + transfer_amount == total` (FR-022) en
  `../pos-backend/app/characterization_tests/test_payment_attempt_mixed_no_receipt.py`
- [X] T013 [P] [US2] Characterization test: validación de rango del efectivo declarado en
  pago mixto — rechazo con `0` y con el total exacto, aceptación de valores intermedios
  (FR-005, FR-006) en
  `../pos-backend/app/characterization_tests/test_payment_attempt_mixed_cash_range.py`

### Implementation for User Story 2

- [X] T014 [US2] En `../pos-backend/app/api/v1/orders/checkout.py`, en el endpoint de
  creación de intento mixto desde el QR, eliminar la aceptación/exigencia de
  `receipt_file_url` en el body cuando el actor es el comensal, y validar que el efectivo
  declarado sea un entero `> 0` y `< total del pedido` (FR-002, FR-005, FR-006, FR-023)
  (depende de T008 si comparten el mismo endpoint de creación)
- [X] T015 [US2] En el mismo endpoint, calcular `transfer_amount = total - cash_amount` y
  devolverlo junto con la instrucción de referencia (mesa/pedido) en la respuesta (FR-003)
- [X] T016 [US2] En `../pos-heladeria/src/app/modules/tables/pages/checkout/cash-amount-step.component.ts`,
  retirar cualquier input/validación de subida de comprobante para el flujo mixto y mostrar el
  monto a transferir calculado + instrucción de referencia + aviso de mostrar comprobante al
  cajero (FR-003, FR-008, FR-023)
- [X] T017 [US2] En `../pos-heladeria/src/app/modules/tables/pages/checkout/cash-amount-step.component.ts`,
  agregar la validación de cliente del rango del efectivo (FR-005) con mensajes que orienten a
  "Efectivo" (si el valor ingresado es igual al total) o "Transferencia" (si es cero)
- [X] T018 [US2] En `../pos-heladeria/src/app/modules/tables/services/diner.service.ts`,
  eliminar cualquier llamada de subida de comprobante remanente del flujo mixto (FR-023)
  (depende de T010 si comparten lógica)

**Checkpoint**: Las Historias 1 y 2 funcionan de forma independiente (Escenario 2 de
quickstart.md).

---

## Phase 5: User Story 3 - El cajero verifica la transferencia en la mesa y confirma el pago antes de entregar (Priority: P1)

**Goal**: El cajero puede confirmar el pago (transferencia y/o efectivo) sin foto obligatoria,
el pedido pasa a pagado solo cuando todos los pagos activos están confirmados, y la entrega
queda bloqueada hasta entonces.

**Independent Test**: Confirmar desde caja un pedido con pagos pendientes (transferencia o
mixto) sin adjuntar foto, y verificar que el pedido pasa a pagado y queda habilitado para
entrega.

### Tests for User Story 3

- [X] T019 [P] [US3] Characterization test: `approve_payment_attempt` confirma un intento de
  transferencia pendiente sin `receipt_file_url` (cambia el comportamiento previo que exigía el
  campo) en
  `../pos-backend/app/characterization_tests/test_approve_payment_attempt_no_receipt.py`
- [X] T020 [P] [US3] Characterization test: `approve_payment_attempt` acepta y persiste una
  foto opcional (`receipt_file_url`) adjuntada por el cajero sin que su ausencia bloquee la
  confirmación en ningún caso (FR-012) en el mismo archivo de T019
- [ ] T021 [P] [US3] Characterization test: un pedido con pago mixto solo pasa a `pagada`
  cuando tanto la porción de transferencia (`approve`) como la de efectivo (`confirm-cash`)
  están confirmadas, no antes (FR-010) en
  `../pos-backend/app/characterization_tests/test_order_paid_state_mixed.py`
- [ ] T022 [P] [US3] Characterization test: intentar marcar como entregado un pedido con
  pagos pendientes es rechazado por el sistema (FR-011) en
  `../pos-backend/app/characterization_tests/test_delivery_blocked_pending_payment.py`

### Implementation for User Story 3

- [X] T023 [US3] En `../pos-backend/app/api/v1/orders/checkout.py`, en
  `approve_payment_attempt` (línea ~1241), eliminar el chequeo que exige
  `attempt.receipt_file_url` para aprobar; mantener los demás chequeos (`status == 'pendiente'`,
  método no efectivo) (FR-012, Decisión 1 de research.md) — depende de T001
- [X] T024 [US3] En el mismo endpoint, aceptar opcionalmente `receipt_file_url` en el body
  de `approve` cuando el actor es el cajero, persistirlo en el intento si se envía, y no
  generar error/advertencia si se omite (FR-012)
- [X] T025 [US3] Verificar que la lógica existente que deriva el estado "pagado" del pedido a
  partir de sus pagos activos confirmados (`_confirm_order_impl` o equivalente en
  `checkout.py`) sigue aplicando sin cambios para pedidos mixtos/transferencia (FR-010); ajustar
  solo si el chequeo de `receipt_file_url` de T023 rompía ese flujo
- [ ] T026 [US3] Verificar/ajustar la validación de entrega (`mark_delivered` o equivalente en
  `checkout.py`) para que siga impidiendo la entrega mientras existan pagos pendientes o
  rechazados sin resolver (FR-011) — probablemente sin cambios, solo confirmar con T022
- [ ] T027 [US3] En `../pos-heladeria/src/app/modules/tables/components/payment-attempt-review-panel.component.ts`,
  agregar un input opcional de foto del comprobante al confirmar el pago, que nunca bloquea el
  botón "Confirmar pago" si se omite (FR-012)
- [X] T028 [US3] En el mismo componente, mostrar al cajero el desglose esperado del pedido
  (monto esperado en efectivo si aplica, monto esperado en transferencia) antes de confirmar
  (FR-009)

**Checkpoint**: Las Historias 1-3 funcionan juntas de forma independiente (Escenario 3 de
quickstart.md); este es el corazón operable del spec.

---

## Phase 6: User Story 4 - El cajero ajusta la división de pago al confirmar (Priority: P2)

**Goal**: El cajero puede reajustar la división efectivo/transferencia de un intento
pendiente (incluyendo convertir transferencia total ↔ mixto ↔ efectivo total), con validación
de que la suma sea igual al total y registro en auditoría de los valores antes/después.

**Independent Test**: Reajustar un pedido de transferencia total a mixto con un nuevo monto de
efectivo al confirmar, y verificar que queda pagado con la nueva división y el ajuste quedó
registrado en auditoría con valores previos y finales.

### Tests for User Story 4

- [X] T029 [P] [US4] Characterization test: `adjust-split` sobre un intento `pendiente`
  actualiza `cash_amount`/`transfer_amount`/`transfer_method_id`/`payment_method_id` cuando la
  suma coincide con el total del pedido (FR-013) en
  `../pos-backend/app/characterization_tests/test_payment_attempt_adjust_split.py`
- [X] T030 [P] [US4] Characterization test: `adjust-split` retorna `409` cuando
  `cash_amount + transfer_amount != total del pedido` (FR-013, Acceptance Scenario 3) en el
  mismo archivo de T029
- [X] T031 [P] [US4] Characterization test: `adjust-split` retorna `409` si el intento no
  está `pendiente` en el mismo archivo de T029
- [X] T032 [P] [US4] Characterization test: `adjust-split` escribe un
  `AuditLog(action="payment_attempt.split_adjusted")` con `cash_amount_antes`,
  `transfer_amount_antes`, `cash_amount_despues`, `transfer_amount_despues` (FR-014) en
  `../pos-backend/app/characterization_tests/test_payment_attempt_split_audit.py`

### Implementation for User Story 4

- [X] T033 [US4] Implementar el endpoint `POST
  /orders/payment-attempts/{attempt_id}/adjust-split` en
  `../pos-backend/app/api/v1/orders/checkout.py` usando `PaymentAttemptAdjustSplitIn` (T006):
  valida `status == 'pendiente'` (409 si no), valida `cash_amount + transfer_amount == total`
  (409 si no), actualiza los campos del intento, y responde con `PaymentAttemptResponse`
  (contrato en contracts/payment-attempts-api.md)
- [X] T034 [US4] En el mismo endpoint, antes de mutar, capturar el payload `antes` (valores
  actuales) y después de mutar escribir `record_audit(action="payment_attempt.split_adjusted",
  entity="order_payment_attempts", entity_id=attempt.id, payload={...antes, ...después})`
  usando `app/core/audit.py` (FR-014) — depende de T033
- [X] T035 [US4] Registrar la nueva ruta en `../pos-backend/app/api/v1/orders/router.py`
  (depende de T033)
- [X] T036 [US4] Implementar `GET /orders/{order_id}/payment-events` en
  `../pos-backend/app/api/v1/orders/checkout.py` (y registrar la ruta en `router.py`),
  devolviendo filas de `AuditLog` donde `entity IN ('order_payment_attempts',
  'customer_orders')` y `entity_id` corresponde a un intento de esa orden o a la orden misma,
  ordenadas por `at` ascendente (FR-019)
- [ ] T037 [US4] En `../pos-heladeria/src/app/modules/tables/components/payment-attempt-review-panel.component.ts`,
  agregar la UI de reajuste de división (campos editables de efectivo/transferencia, llamada a
  `adjust-split`, manejo del `409` con mensaje claro) (FR-013)
- [ ] T038 [US4] En el mismo componente, agregar una vista del historial del pedido
  (`GET /orders/{order_id}/payment-events`) que muestre motivo/montos antes-después, cajero y
  hora de cada evento (FR-014, Acceptance Scenario 2 de US4) — depende de T036

**Checkpoint**: Historias 1-4 funcionan de forma independiente (Escenario 4 de quickstart.md).

---

## Phase 7: User Story 5 - El cajero rechaza la verificación y resuelve la situación (Priority: P2)

**Goal**: El cajero puede rechazar un pago con motivo obligatorio del conjunto cerrado, y
resolver mediante exactamente una de tres vías (efectivo total, reintento único, cancelación
por impago), con marca de revisión en segundo rechazo de la misma mesa en el día.

**Independent Test**: Rechazar un pago con motivo, verificar que el pedido queda pendiente de
pago y no se puede entregar, y luego resolver por cada una de las tres salidas en pruebas
separadas.

### Tests for User Story 5

- [X] T039 [P] [US5] Characterization test: `reject` sin `reason` retorna `422`; con `reason`
  fuera del conjunto cerrado retorna `422`; con un valor válido retorna `200` y el intento pasa
  a `rechazado` (FR-015) en
  `../pos-backend/app/characterization_tests/test_payment_attempt_reject.py`
- [ ] T040 [P] [US5] Characterization test: un pedido con un intento `rechazado` no puede
  marcarse como entregado hasta resolver el rechazo (FR-016) en
  `../pos-backend/app/characterization_tests/test_delivery_blocked_rejected_payment.py`
- [ ] T041 [P] [US5] Characterization test: resolución vía efectivo total — `adjust-split` a
  `cash_amount=total, transfer_amount=0` seguido de `confirm-cash` deja el pedido `pagada`
  (FR-017, Acceptance Scenario 2 de US5) en
  `../pos-backend/app/characterization_tests/test_rejection_resolution_cash.py`
- [X] T042 [P] [US5] Characterization test: resolución vía reintento único — crear un nuevo
  intento de transferencia tras un rechazo y aprobarlo tiene éxito; un segundo reintento tras un
  segundo rechazo retorna `409` orientando a las otras dos salidas (FR-017, Decisión 5) en
  `../pos-backend/app/characterization_tests/test_rejection_resolution_retry_limit.py`
- [X] T043 [P] [US5] Characterization test: resolución vía cancelación por impago —
  `cancel_order` sobre un pedido con intento `rechazado` anula los pagos, marca el pedido como
  cancelado, y registra `AuditLog(action="order.cancel.loss")` con motivo distintivo
  `impago_transferencia_rechazada` (FR-018) en
  `../pos-backend/app/characterization_tests/test_rejection_resolution_cancel_as_loss.py`
- [X] T044 [P] [US5] Characterization test: un segundo rechazo de pago en el mismo día para la
  misma mesa escribe `AuditLog(action="payment.table_repeat_rejection")` sin bloquear el flujo
  ni cambiar la respuesta (FR-020) en
  `../pos-backend/app/characterization_tests/test_table_repeat_rejection.py`

### Implementation for User Story 5

- [X] T045 [US5] En `../pos-backend/app/api/v1/orders/checkout.py`, endpoint `reject`:
  validar `reason` contra el enum de T004/T005 (422 si no pertenece), persistir el rechazo
  (`status = 'rechazado'`) y escribir `AuditLog(action="payment_attempt.rejected")` con el
  motivo, cajero y hora (FR-015, FR-019) — depende de T004, T005
- [X] T046 [US5] En el mismo endpoint, tras persistir el rechazo, contar los intentos
  `rechazado` de método no efectivo existentes para órdenes de la misma `dining_table_id` con
  `created_at` dentro del día calendario actual (zona horaria del negocio); si el conteo llega a
  2 o más, escribir adicionalmente `AuditLog(action="payment.table_repeat_rejection",
  entity="dining_tables", entity_id=<mesa>, payload={order_id, rejection_count_today})` sin
  alterar la respuesta (FR-020, Decisión 7)
- [X] T047 [US5] En el endpoint de creación de un nuevo intento de transferencia tras un
  rechazo (`checkout.py`), contar los intentos `rechazado` de método no efectivo ya existentes
  para la orden; si ya hay uno, rechazar con `409` y mensaje orientando a las otras dos salidas
  (efectivo total o cancelación por impago) (FR-017, Decisión 5)
- [X] T048 [US5] Verificar que el endpoint de cancelación de pedido (`cancel_order`,
  `checkout.py` ~líneas 900-985) acepta un `motivo` distintivo
  (`impago_transferencia_rechazada`) al cancelar por impago, y que sigue anulando el intento
  `pendiente`/`rechazado` y registrando `AuditLog(action="order.cancel.loss")` con ese motivo
  (FR-018); ajustar la firma del endpoint o su body solo si no acepta hoy un motivo
  parametrizable
- [X] T049 [US5] En `../pos-heladeria/src/app/modules/tables/components/payment-attempt-review-panel.component.ts`,
  agregar la UI de rechazo con selector del motivo cerrado (obligatorio, bloquea el envío si no
  hay selección) (FR-015)
- [X] T050 [US5] En el mismo componente, agregar las tres acciones de resolución de un pago
  rechazado: pagar efectivo total (reutiliza T037), reintentar transferencia (crea nuevo
  intento), y cancelar por impago (llama a `cancel_order` con el motivo distintivo) (FR-017)
  — depende de T037, T047, T048
- [ ] T051 [US5] En el mismo componente, mostrar un indicador visible cuando el pedido/mesa
  tiene un segundo rechazo en el día (consultando `payment-events` de T036 o un indicador
  expuesto por el backend), sin bloquear ninguna acción (FR-020) — depende de T038, T046

**Checkpoint**: Todas las historias de usuario son independientemente funcionales (Escenario 5
de quickstart.md).

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Mejoras que afectan a varias historias y cierre de la verificación end-to-end.

- [X] T052 [P] Revisar y actualizar, si corresponde, los characterization tests existentes de
  spec 024/130 sobre el flujo de aprobación de comprobante de transferencia en
  `../pos-backend/app/characterization_tests/`, citando explícitamente spec 132 en cualquier
  cambio (Principio III de la constitución)
- [X] T053 [P] Validar control de tenant: los endpoints `approve`, `reject`, `confirm-cash`,
  `adjust-split` y `GET /orders/{order_id}/payment-events` rechazan el acceso cuando el pedido
  pertenece a otro tenant (FR-021, SC-006) en
  `../pos-backend/app/characterization_tests/test_payment_attempt_tenant_isolation.py`
- [X] T054 Ejecutar `python -m unittest discover -s app/characterization_tests -p
  'test_*.py' -v` dentro del venv de `pos-backend` y confirmar que no hay regresiones fuera de
  los archivos de este spec
- [X] T055 Ejecutar `ng test` en `pos-heladeria` y comparar el diff de los archivos afectados
  (`transfer-details-step.component`, `cash-amount-step.component`,
  `payment-attempt-review-panel.component`, `diner.service`) contra el baseline conocido como
  flaky, en vez del conteo total de la suite
- [ ] T056 Ejecutar manualmente los 5 escenarios de `quickstart.md` de punta a punta sobre los
  dos repos corriendo localmente, confirmando SC-001 a SC-006

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Sin dependencias — puede iniciar inmediatamente.
- **Foundational (Phase 2)**: Depende de Setup (T001, por el registro de Principio II antes de
  tocar `approve_payment_attempt`) — BLOQUEA todas las historias de usuario.
- **Historias de usuario (Phase 3+)**: Todas dependen de Foundational.
  - US1 y US2 comparten el endpoint de creación de intento desde el QR (T008/T014 pueden
    requerir coordinación si es el mismo endpoint).
  - US3 depende de T001 (registro de decisión) antes de modificar `approve_payment_attempt`.
  - US4 y US5 dependen de que US3 exista (confirmación de pagos) para ser demostrables de punta
    a punta, aunque sus endpoints (`adjust-split`, `reject`) son técnicamente independientes.
- **Polish (Final Phase)**: Depende de que todas las historias deseadas estén completas.

### User Story Dependencies

- **US1 (P1)**: Puede iniciar tras Foundational. Sin dependencia de otras historias.
- **US2 (P1)**: Puede iniciar tras Foundational. Comparte endpoint de creación de intento con
  US1; coordinar T008/T014.
- **US3 (P1)**: Puede iniciar tras Foundational. Depende de T001 (Setup). Es prerrequisito
  *funcional* (no de código) para demostrar US4/US5 de punta a punta.
- **US4 (P2)**: Puede iniciar tras Foundational. Usa el mismo intento que crea US1/US2 y que
  confirma US3, pero su endpoint es independiente.
- **US5 (P2)**: Puede iniciar tras Foundational. Reutiliza `adjust-split` (US4) y
  `confirm-cash`/`cancel_order` (US3) para sus salidas de resolución.

### Within Each User Story

- Tests antes de la implementación (deben fallar primero).
- Cambios de backend antes de los de frontend que consumen el endpoint.
- Historia completa y verificada antes de pasar a la siguiente prioridad.

### Parallel Opportunities

- T005 y T006 (Foundational) en paralelo (archivos de schemas distintos, sin dependencia entre
  sí).
- Todos los tests marcados [P] dentro de una historia en paralelo entre sí.
- US1 y US2 pueden trabajarse en paralelo por desarrolladores distintos si se coordina el
  endpoint compartido de creación de intento.
- US4 y US5 pueden trabajarse en paralelo entre sí tras Foundational, aunque su verificación de
  punta a punta espera a US3.

---

## Parallel Example: User Story 3

```bash
# Lanzar juntos los tests de la Historia 3:
Task: "Characterization test: approve sin receipt_file_url en test_approve_payment_attempt_no_receipt.py"
Task: "Characterization test: foto opcional en el mismo archivo"
Task: "Characterization test: pedido mixto solo pagado con ambas porciones confirmadas en test_order_paid_state_mixed.py"
Task: "Characterization test: entrega bloqueada con pago pendiente en test_delivery_blocked_pending_payment.py"
```

---

## Implementation Strategy

### MVP First (User Story 1 solamente)

1. Completar Phase 1: Setup (registro de decisión de negocio).
2. Completar Phase 2: Foundational (migración + enums + schemas) — bloquea todo lo demás.
3. Completar Phase 3: User Story 1.
4. **DETENER y VALIDAR**: probar la Historia 1 de forma independiente (Escenario 1 de
   quickstart.md).
5. Desplegar/demostrar si está listo.

### Incremental Delivery

1. Setup + Foundational → base lista.
2. Agregar US1 → probar independientemente → demo (MVP parcial: solo transferencia total).
3. Agregar US2 → probar independientemente → demo (MVP completo: transferencia + mixto sin
   comprobante).
4. Agregar US3 → probar independientemente → demo (flujo cerrable: el cajero puede confirmar y
   entregar).
5. Agregar US4 → probar independientemente → demo (reajuste de división).
6. Agregar US5 → probar independientemente → demo (camino de excepción completo).
7. Cada historia agrega valor sin romper las anteriores.

### Parallel Team Strategy

Con varios desarrolladores:

1. El equipo completa Setup + Foundational en conjunto.
2. Una vez lista Foundational:
   - Desarrollador A: US1 + US2 (comparten endpoint de creación de intento)
   - Desarrollador B: US3 (confirmación/entrega)
   - Desarrollador C: US4 + US5 (reajuste y rechazo, tras coordinar con B sobre `confirm-cash`
     y `cancel_order`)
3. Las historias se integran de forma independiente, con US3 como punto de sincronización
   funcional antes de la demo end-to-end.

---

## Notes

- [P] tasks = archivos distintos, sin dependencias entre sí.
- [Story] mapea la tarea a su historia de usuario para trazabilidad.
- T001 debe completarse antes de T023 (gate de Principio II antes de tocar
  `approve_payment_attempt`).
- Verificar que los tests fallan antes de implementar.
- Hacer commit tras cada tarea o grupo lógico.
- Detenerse en cada checkpoint para validar la historia de forma independiente.
- Evitar: tareas vagas, conflictos en el mismo archivo sin coordinación, dependencias entre
  historias que rompan su independencia.
