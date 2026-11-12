---

description: "Task list template for feature implementation"
---

# Tasks: Envío a Cocina de Pedidos Para Llevar y Domicilio

**Input**: Design documents from `/specs/157-cocina-pedidos-llevar-domicilio/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/kitchen-payment-modality.md, quickstart.md

**Tests**: Characterization tests son obligatorios en este proyecto (Principio III/X de la
Constitution) — se incluyen como parte de cada historia, no como fase opcional.

**Organization**: Tareas agrupadas por historia de usuario (spec.md). US1 y US2 son ambas P1
(bloqueador principal, dos caras del mismo problema) y comparten la misma función de regla
central (`kitchen_requires_prior_payment`), por lo que se implementan en una sola fase de
backend seguida de verificación independiente por historia. US3 (P3) es prueba de
no-regresión, sin código nuevo.

## Path Conventions

Proyecto multi-repo (ver plan.md § Project Structure):

- Backend: `../pos-backend/app/...` (relativo a este repo de specs: `pos-backend/app/...`)
- Frontend: `../pos-heladeria/src/app/...` (`pos-heladeria/src/app/...`)
- Registro de anomalías: `specs/000-reconocimiento/registro-de-anomalias.md` (este repo)

---

## Phase 1: Setup

**Purpose**: Dejar registrada la decisión de negocio y la rama antes de tocar código
(Constitution, Principio II y XIV).

- [X] T001 Crear la rama `feat/157-kitchen-takeaway-delivery` desde `main` en `pos-backend` (y en
      `pos-heladeria` si el checkpoint de Fase 5 requiere cambios de frontend)
- [X] T002 Registrar la entrada `A-160` en `specs/000-reconocimiento/registro-de-anomalias.md`
      (siguiendo el formato de `A-155`): decisión de negocio de extender el alcance de
      `Plan.modalidad_pago_qr` (spec 154) para que también gobierne el envío a cocina de pedidos
      `TAKEAWAY`/`DELIVERY` (spec 157), citando que fue confirmada explícitamente por el usuario
      en las Clarifications de `spec.md`

**Checkpoint**: Decisión de negocio trazable; rama lista para implementar.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Función central de regla de negocio que reutilizan todas las historias
(`_apply_kitchen_send`, `send_to_kitchen`, `pay_order`). Bloquea las Fases 3 y 4.

- [X] T003 Añadir `kitchen_requires_prior_payment(db: Session, tenant: Tenant | None, order:
      CustomerOrder) -> bool` en `pos-backend/app/api/v1/orders/kitchen.py` (research.md
      Decisión 1): devuelve `True` siempre si `order.dining_table_id is not None` (DINE_IN, sin
      cambios spec 153); en caso contrario, `True` únicamente si `tenant is not None and
      plan_service.get_qr_payment_instruction_mode(db, tenant) == "PAY_BEFORE_RECEIVING"`, y
      `False` en cualquier otro caso (incluido `tenant is None`, para no romper llamadas sin
      tenant resuelto)
- [X] T004 Cambiar la firma de `send_to_kitchen` en `pos-backend/app/api/v1/orders/kitchen.py` de
      `send_to_kitchen(db, order_id, tenant_id=None)` a `send_to_kitchen(db, order_id,
      tenant_id=None, *, tenant: Tenant | None = None)`, y cambiar la guarda `payment_status !=
      'PAID'` (línea ~214) para usar `kitchen_requires_prior_payment(db, tenant, order) and
      order.payment_status != "PAID"` antes de lanzar `ORDER_NOT_PAID` (depende de T003)
- [X] T005 Cambiar `_apply_kitchen_send(order: CustomerOrder) -> bool` en
      `pos-backend/app/api/v1/orders/kitchen.py` a `_apply_kitchen_send(order: CustomerOrder, *,
      requires_prior_payment: bool = True) -> bool`, sustituyendo la condición fija
      `order.payment_status != "PAID"` por `requires_prior_payment and order.payment_status !=
      "PAID"` en el `if` de guarda (depende de T003); actualizar el llamador en
      `send_to_kitchen` (T004) para pasar `requires_prior_payment=kitchen_requires_prior_payment(db,
      tenant, order)`
- [X] T006 Actualizar la llamada a `_apply_kitchen_send(order)` en
      `pos-backend/app/api/v1/table_sessions/service.py::_charge_session` (línea ~450) para pasar
      explícitamente `requires_prior_payment=True` (DINE_IN, comportamiento intacto de spec 153 —
      no se introduce ninguna lectura de modalidad en esta ruta, fuera de alcance por
      research.md Decisión 1)

**Checkpoint**: `_apply_kitchen_send`/`send_to_kitchen` relajan la exigencia de pago solo para
TAKEAWAY/DELIVERY en `PAY_AFTER_RECEIVING`; DINE_IN y el resto de combinaciones siguen exigiendo
`PAID` exactamente igual que antes. Listo para construir ambas historias de usuario.

---

## Phase 3: User Story 1 - Cobro y envío a cocina en un solo paso (`PAY_BEFORE_RECEIVING`) (Priority: P1) 🎯 MVP

**Goal**: Al cobrar un pedido TAKEAWAY/DELIVERY completo en un tenant con módulo de Cocina
activo y modalidad `PAY_BEFORE_RECEIVING`, el pedido se envía a cocina automáticamente en el
mismo acto (FR-002, FR-004, FR-009).

**Independent Test**: Crear pedido TAKEAWAY o DELIVERY en tenant con Cocina activa y modalidad
`PAY_BEFORE_RECEIVING`, cobrarlo por completo vía `POST /orders/{id}/pay`, y verificar que
`kitchen_status == 'SIN_PREPARAR'` y aparece en el tablero sin acción manual adicional.

### Tests para User Story 1 (characterization tests — escribir antes de implementar)

- [X] T007 [P] [US1] Actualizar en `pos-backend/app/characterization_tests/test_orders_checkout.py`
      cualquier test que congele "pagar un pedido TAKEAWAY/DELIVERY nunca toca `kitchen_status`"
      citando la decisión `A-160`, y añadir
      `test_pay_order_envia_a_cocina_automaticamente_con_pay_before_receiving_takeaway` y su
      equivalente `_delivery`: tenant con `cocina_access=True` y plan en
      `modalidad_pago_qr='PAY_BEFORE_RECEIVING'` (usar/extender `fx.make_tenant_double` con
      `plan_id` apuntando a un `Plan` real creado en el fixture, o mockear
      `plan_service.get_qr_payment_instruction_mode` igual que ya se mockea `has_module_access`
      en `test_orders_kitchen.py`), pedido `status='confirmado'`, `payment_status='UNPAID'`,
      `kitchen_status=None`; al llamar `checkout.pay_order(...)`, verificar `payment_status ==
      'PAID'`, `kitchen_status == 'SIN_PREPARAR'`, `sent_to_kitchen_at` no nulo, y que
      `events.order_sent_to_kitchen` se llamó una vez (mock, patrón de
      `test_send_to_kitchen_exitoso_origen_mesa_usa_hora_del_servidor`)
- [X] T008 [P] [US1] Añadir en `pos-backend/app/characterization_tests/test_orders_checkout.py`
      `test_pay_order_no_envia_a_cocina_si_modalidad_pay_after_receiving` y
      `test_pay_order_no_envia_a_cocina_sin_modulo_cocina_activo`: mismas condiciones de T007 pero
      modalidad `PAY_AFTER_RECEIVING` (o `cocina_access=False`) → tras `pay_order`,
      `kitchen_status` permanece `None` y `events.order_sent_to_kitchen` no se llama
- [X] T009 [P] [US1] Añadir en `pos-backend/app/characterization_tests/test_orders_kitchen.py`
      `test_send_to_kitchen_rechaza_takeaway_sin_pagar_con_pay_before_receiving`: tenant con
      `cocina_access=True`, modalidad `PAY_BEFORE_RECEIVING`, pedido TAKEAWAY `payment_status=
      'UNPAID'` → `kitchen.send_to_kitchen(db, order.id, tenant_id=1, tenant=tenant)` lanza
      `ConflictError` con `code == 'ORDER_NOT_PAID'` (citando `A-160`: comportamiento FR-004,
      sin cambios respecto a hoy para esta combinación)

### Implementación para User Story 1

- [X] T010 [US1] En `pos-backend/app/api/v1/orders/checkout.py::pay_order`, tras `order.payment_status
      = "PAID"` (línea ~598) y antes de `db.commit()` (depende de T003/T005): si `tenant is not
      None and order.dining_table_id is None and has_module_access(db, tenant, "cocina")`,
      calcular `requires_prior_payment = kitchen_requires_prior_payment(db, tenant, order)` y,
      si es `True` (modalidad `PAY_BEFORE_RECEIVING`), llamar `sent_to_kitchen =
      kitchen._apply_kitchen_send(order, requires_prior_payment=False)` dentro de la misma
      transacción (se pasa `requires_prior_payment=False` porque en este punto el pago ya se
      fijó explícitamente arriba, no hace falta volver a chequearlo); importar `has_module_access`
      de `app.core.plan_limits` y las funciones nuevas de `app.api.v1.orders.kitchen` en
      `checkout.py`
- [X] T011 [US1] En `pos-backend/app/api/v1/orders/router.py::pay_order` (línea ~784), tras el
      `db.commit()` exitoso de `checkout.pay_order` (que ya devuelve el `Sale`), recuperar el
      pedido actualizado y, si su `kitchen_status == 'SIN_PREPARAR'` y antes de la llamada
      estaba `None` (usar el valor de retorno de `_apply_kitchen_send` propagado desde T010, p.
      ej. añadiendo ese flag al objeto `Sale` devuelto o resolviendo el pedido tras el commit y
      comparando con un flag de retorno de `pay_order`), emitir
      `events.order_sent_to_kitchen(tenant.id, order_id=order.id,
      table_session_id=order.table_session_id)` (mismo patrón post-commit que
      `kitchen.send_to_kitchen`, contracts/kitchen-payment-modality.md §1); decidir en código el
      mecanismo más simple para propagar el flag sin cambiar el contrato HTTP de `PayIn`/
      `SaleResponse`
- [X] T012 [US1] En `pos-backend/app/api/v1/orders/router.py::send_to_kitchen` (línea ~436),
      pasar `tenant=tenant` a `kitchen.send_to_kitchen(db, order_id, tenant_id=tenant.id,
      tenant=tenant)` (depende de T004) — necesario para que la guarda relajada de FR-003 (US2)
      y la guarda intacta de FR-004 (US1) puedan leer la modalidad del plan
- [X] T013 [US1] Correr `python -m unittest app.characterization_tests.test_orders_checkout
      app.characterization_tests.test_orders_kitchen -v` desde el venv de `pos-backend` y
      confirmar que T007-T009 pasan junto con los characterization tests preexistentes (sin
      nuevos fallos respecto a la línea base documentada en memoria del proyecto)

**Checkpoint**: US1 funcional y verificable de forma independiente — cobrar un TAKEAWAY/DELIVERY
en modalidad `PAY_BEFORE_RECEIVING` lo envía a cocina en el mismo acto; esa misma combinación
sigue rechazando el envío manual sin pagar (FR-004 intacto).

---

## Phase 4: User Story 2 - Envío a cocina sin exigir pago previo (`PAY_AFTER_RECEIVING`) (Priority: P1)

**Goal**: Permitir `POST /orders/{id}/send-to-kitchen` para TAKEAWAY/DELIVERY con
`payment_status='UNPAID'` cuando la modalidad del plan es `PAY_AFTER_RECEIVING` (o sin
configurar), y que el cobro posterior no altere `kitchen_status` (FR-003, FR-006, FR-008 por
defecto).

**Independent Test**: Crear y confirmar un pedido TAKEAWAY/DELIVERY sin cobrar en tenant con
Cocina activa y modalidad `PAY_AFTER_RECEIVING`; enviarlo a cocina manualmente (200 OK,
`kitchen_status='SIN_PREPARAR'`); cobrarlo después y verificar que `kitchen_status` no cambia.

### Tests para User Story 2 (characterization tests — escribir antes de implementar)

- [X] T014 [P] [US2] Actualizar en `pos-backend/app/characterization_tests/test_orders_kitchen.py`
      cualquier test que congele "`send_to_kitchen` siempre exige `PAID`" citando `A-160`, y
      añadir `test_send_to_kitchen_permite_takeaway_sin_pagar_con_pay_after_receiving` y su
      equivalente `_delivery`: tenant con `cocina_access=True` y modalidad
      `PAY_AFTER_RECEIVING` (o sin configurar, default del campo — cubre FR-008), pedido
      `status='confirmado'`, `payment_status='UNPAID'` → `kitchen.send_to_kitchen(db, order.id,
      tenant_id=1, tenant=tenant)` tiene éxito, `kitchen_status == 'SIN_PREPARAR'`,
      `payment_status` sigue `'UNPAID'`
- [X] T015 [P] [US2] Añadir en `pos-backend/app/characterization_tests/test_orders_checkout.py`
      `test_pay_order_no_altera_kitchen_status_ya_alcanzado_sin_pago_previo` (FR-006): pedido
      TAKEAWAY con `kitchen_status='SIN_PREPARAR'`/`payment_status='UNPAID'` ya enviado a
      cocina bajo `PAY_AFTER_RECEIVING` → tras `checkout.pay_order(...)`, `payment_status ==
      'PAID'` y `kitchen_status` sigue `'SIN_PREPARAR'` sin segunda emisión de
      `events.order_sent_to_kitchen`
- [X] T016 [P] [US2] Añadir en `pos-backend/app/characterization_tests/test_orders_kitchen.py`
      `test_deliver_order_y_change_kitchen_status_siguen_exigiendo_lo_mismo_para_takeaway_sin_pagar`
      si aplica (verificar si `change_kitchen_status`/`deliver_order` ya exigen `payment_status
      == 'PAID'` en otro punto del flujo para TAKEAWAY — confirmar contra
      `contracts/kitchen-payment-modality.md` que esta spec NO modifica esas dos funciones; si el
      test existente ya cubre que siguen intactas, documentar la cobertura en vez de duplicar)

### Implementación para User Story 2

- [X] T017 [US2] Verificar que T003-T005 (Fase 2) ya dejan `send_to_kitchen` relajando la
      exigencia de pago exactamente para `TAKEAWAY`/`DELIVERY` + `PAY_AFTER_RECEIVING` — esta
      historia no requiere código de producción adicional al de la Fase 2 (research.md Decisión
      2); si T014-T016 fallan, el ajuste pertenece a T003-T005, no a una función nueva
- [X] T018 [US2] Correr `python -m unittest app.characterization_tests.test_orders_kitchen
      app.characterization_tests.test_orders_checkout -v` desde el venv de `pos-backend` y
      confirmar que T014-T016 pasan junto con T007-T009/T013 sin regresiones cruzadas

**Checkpoint**: US1 y US2 conviven correctamente — cada combinación order_type × modalidad ×
módulo Cocina se comporta según la tabla de `data-model.md`, sin que una historia rompa a la
otra.

---

## Phase 5: Frontend — Ocultar botón manual en `PAY_BEFORE_RECEIVING` (Priority: P1, soporte de US1)

**Goal**: FR-002 exige que no se exponga un botón manual "Enviar a cocina" para
TAKEAWAY/DELIVERY cuando la modalidad es `PAY_BEFORE_RECEIVING` y el módulo de Cocina está
activo (research.md Decisión 5, contracts §3).

**Independent Test**: Con un tenant en `PAY_BEFORE_RECEIVING` y Cocina activa, la pantalla de
pedidos de mostrador/domicilio no muestra el botón "Enviar a cocina" para ningún pedido
TAKEAWAY/DELIVERY sin pagar; en `PAY_AFTER_RECEIVING` el botón sigue visible.

- [X] T019 [US1] Extender el cómputo de `qr_payment_instruction_mode` (hoy solo en
      `pos-backend/app/api/v1/cart/router.py`, líneas 176/214-216) a `_load_order` y/o
      `list_orders` en `pos-backend/app/api/v1/orders/router.py` (mismo patrón de atributo
      transitorio no persistido que `paid`/`staff_user_name`, ver `orders/service.py` y
      `schemas.py:344`), de forma que las respuestas de los endpoints de staff usados por la
      pantalla de mostrador/domicilio incluyan `qr_payment_instruction_mode` calculado con
      `plan_service.get_qr_payment_instruction_mode(db, tenant)`
- [X] T020 [P] [US1] Añadir characterization test en
      `pos-backend/app/characterization_tests/test_orders_*.py` (archivo según dónde viva
      `_load_order`/`list_orders` bajo prueba) que confirme que `OrderResponse.
      qr_payment_instruction_mode` ya no es `None` para una orden servida por un endpoint de
      staff (antes de esta spec siempre era `None` fuera de `cart/router.py` — citar `A-160` si
      se actualiza un test existente que congelaba ese `None`)
- [X] T021 [US1] Localizar el componente Angular de la pantalla de pedidos de
      mostrador/domicilio en `pos-heladeria/src/app/` que renderiza el botón manual "Enviar a
      cocina" (plan.md deja esta exploración exacta para esta fase) y ocultarlo cuando
      `order.order_type ∈ {TAKEAWAY, DELIVERY} AND módulo Cocina activo AND
      qr_payment_instruction_mode === 'PAY_BEFORE_RECEIVING'`, dejándolo visible en cualquier
      otro caso (incluida `PAY_AFTER_RECEIVING` sin pagar)
- [ ] T022 [US1] Verificar manualmente en el navegador (dev server de `pos-heladeria`, con
      `pos-backend` corriendo contra el tenant de prueba de `quickstart.md`) que el botón se
      oculta/muestra según la tabla de decisión, para TAKEAWAY y DELIVERY, en ambas modalidades

**Checkpoint**: El flujo de mostrador para `PAY_BEFORE_RECEIVING` no ofrece ningún camino manual
para enviar a cocina sin cobrar, cerrando US1 de punta a punta (backend + frontend).

---

## Phase 6: User Story 3 - Sin cambios cuando el módulo de Cocina está inactivo (Priority: P3)

**Goal**: Confirmar que tenants sin módulo de Cocina activo no observan ningún cambio de
comportamiento, sin importar la modalidad del plan (FR-007, SC-004). No introduce código nuevo
— es verificación de no-regresión.

**Independent Test**: En un tenant sin `cocina_access`, crear y cobrar pedidos TAKEAWAY y
DELIVERY en ambas modalidades del plan; no debe aparecer ningún campo ni acción de cocina, y el
flujo de venta/descuento de inventario es idéntico al actual.

- [X] T023 [P] [US3] Añadir en `pos-backend/app/characterization_tests/test_orders_checkout.py`
      `test_pay_order_sin_modulo_cocina_activo_no_cambia_comportamiento_en_ninguna_modalidad`:
      `cocina_access=False`, probar ambas modalidades (`PAY_BEFORE_RECEIVING` y
      `PAY_AFTER_RECEIVING`) para TAKEAWAY y DELIVERY → `pay_order` nunca toca `kitchen_status`
      (sigue `None`) y `events.order_sent_to_kitchen` nunca se llama
- [X] T024 [US3] Correr la suite completa de characterization tests
      (`python -m unittest discover app/characterization_tests -v` desde el venv de
      `pos-backend`) y diff contra la línea base conocida (ver memoria del proyecto: la suite de
      frontend es flaky — comparar por archivo, no por conteo total; el backend sobre SQLite en
      memoria no debería tener fallos nuevos)

**Checkpoint**: Ningún tenant sin módulo de Cocina observa cambios; DINE_IN tampoco (ya cubierto
transversalmente por T006/T009).

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Cierre de verificación end-to-end y trazabilidad.

- [ ] T025 Ejecutar los 3 escenarios de `specs/157-cocina-pedidos-llevar-domicilio/quickstart.md`
      manualmente contra `pos-backend` local con Postgres (venv del proyecto, ver memoria de la
      sesión) y un tenant con módulo de Cocina activo, confirmando los resultados esperados de
      cada paso
- [X] T026 Actualizar el bloque **Estado** de la entrada `A-160` en
      `specs/000-reconocimiento/registro-de-anomalias.md` (T002) a "implementado", citando los
      archivos de test afectados y el resultado de la suite (T013/T018/T024)
- [X] T027 Revisar que ningún cambio tocó `checkout_and_send`/`hold_for_payment` ni
      `_charge_session` fuera de lo explícitamente permitido en T006 (research.md Decisión 4) —
      si se detectó necesidad real de extender `checkout_and_send`, reportarlo como hallazgo
      nuevo al usuario en vez de modificarlo silenciosamente

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Sin dependencias — puede iniciar de inmediato.
- **Foundational (Phase 2)**: Depende de Phase 1 (rama creada). Bloquea Phases 3 y 4.
- **User Story 1 (Phase 3)**: Depende de Phase 2.
- **User Story 2 (Phase 4)**: Depende de Phase 2. Independiente de Phase 3 en el backend, pero
  comparte los mismos archivos de test (`test_orders_kitchen.py`,
  `test_orders_checkout.py`) — ejecutar T013 antes de empezar T014-T016 reduce conflictos de
  merge si se trabaja en paralelo.
- **Frontend US1 (Phase 5)**: Depende de que Phase 3 (T010-T012) exista en el backend — el campo
  `qr_payment_instruction_mode` y el comportamiento de `pay_order` deben estar listos antes de
  ocultar el botón.
- **User Story 3 (Phase 6)**: Depende de Phases 2-4 (verifica que no las rompe). Puede
  ejecutarse en paralelo con Phase 5 (no comparte archivos).
- **Polish (Phase 7)**: Depende de todas las fases anteriores.

### User Story Dependencies

- **US1 (P1)**: Depende solo de Foundational. Es el MVP.
- **US2 (P1)**: Depende solo de Foundational. Comparte la regla central con US1 pero no
  depende de la implementación de US1 (T010-T012) — puede implementarse en paralelo si se
  coordina el acceso a los archivos de test compartidos.
- **US3 (P3)**: Depende de Foundational + US1 + US2 (verifica que ninguna las afectó).

### Parallel Opportunities

- T007, T008, T009 (tests US1) se pueden escribir en paralelo — archivos/tests distintos.
- T014, T015, T016 (tests US2) se pueden escribir en paralelo entre sí, y en paralelo con
  T007-T009 si dos personas trabajan a la vez (mismo archivo `test_orders_kitchen.py` en algunos
  casos — coordinar para evitar conflictos de merge, no de lógica).
- T020 y T023 son independientes del resto de su fase y paralelizables entre sí.
- Phase 5 (frontend) y Phase 6 (US3) no comparten archivos y pueden avanzar en paralelo una vez
  completada Phase 4.

---

## Parallel Example: User Story 1

```bash
# Tests de US1 en paralelo (archivos ya existentes, distintos casos):
Task: "test_pay_order_envia_a_cocina_automaticamente_con_pay_before_receiving_takeaway/_delivery en test_orders_checkout.py"
Task: "test_pay_order_no_envia_a_cocina_si_modalidad_pay_after_receiving/_sin_modulo_cocina_activo en test_orders_checkout.py"
Task: "test_send_to_kitchen_rechaza_takeaway_sin_pagar_con_pay_before_receiving en test_orders_kitchen.py"
```

---

## Implementation Strategy

### MVP First (User Story 1 solamente)

1. Completar Phase 1: Setup (rama + registro de anomalía A-160).
2. Completar Phase 2: Foundational (`kitchen_requires_prior_payment`, ajustes de firma) — CRÍTICO.
3. Completar Phase 3: User Story 1 (backend).
4. Completar Phase 5: Frontend de US1 (ocultar botón en `PAY_BEFORE_RECEIVING`).
5. **DETENER y VALIDAR**: Escenario 1 de `quickstart.md` de punta a punta.

### Entrega incremental

1. Setup + Foundational → base lista.
2. US1 (backend + frontend, Phases 3 + 5) → cobrar envía a cocina en `PAY_BEFORE_RECEIVING`
   (MVP) → validar con quickstart Escenario 1.
3. US2 (Phase 4) → enviar sin pagar en `PAY_AFTER_RECEIVING` → validar con quickstart Escenario 2.
4. US3 (Phase 6) → confirmar no-regresión sin módulo de Cocina → validar con quickstart
   Escenario 3.
5. Polish (Phase 7) → cierre de trazabilidad y verificación completa.

### Nota sobre paralelismo real

Dado que US1 y US2 modifican las mismas funciones centrales (`_apply_kitchen_send`,
`send_to_kitchen`) a través de la Fase 2 compartida, la forma más segura de ejecutar este plan
con un solo desarrollador es secuencial (Setup → Foundational → US1 → Frontend US1 → US2 → US3
→ Polish), no en paralelo real entre historias — el "paralelismo" señalado arriba es útil
principalmente para dos personas trabajando con cuidado de merge, no para acelerar un trabajo
en solitario.
