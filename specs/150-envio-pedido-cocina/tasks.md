---

description: "Task list template for feature implementation"
---

# Tasks: Envío de pedido confirmado y pagado a cocina

**Input**: Documentos de diseño de `/specs/150-envio-pedido-cocina/`
(`plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/send-to-kitchen.md`, `quickstart.md`)

**Tests**: Se incluyen tareas de test — `plan.md` (Technical Context) y `research.md` Decisión 9
piden explícitamente extender `test_orders_kitchen.py` con los casos de `send_to_kitchen`. Son
`characterization tests` de `pos-backend` (`unittest` sobre SQLite en memoria). No se agregan
tests nuevos de frontend — `quickstart.md` solo pide comparar `ng test` contra el baseline
conocido, no escribir pruebas nuevas.

**Organization**: Las tareas están agrupadas por historia de usuario de `spec.md` para permitir
implementación y prueba independiente de cada una.

## Rutas de los repositorios

Esta spec vive en `pos-specs`, pero el código vive en los repos sibling. Todas las rutas de abajo
son relativas a la raíz de cada repo:

- **`pos-backend`**: `app/models/customer_order.py`, `app/api/v1/orders/kitchen.py`,
  `app/api/v1/orders/router.py`, `app/api/v1/orders/schemas.py`, `app/core/events.py`,
  `app/characterization_tests/test_orders_kitchen.py`,
  `app/characterization_tests/orders_fixtures.py`, `alembic/versions/`.
- **`pos-heladeria`**: `src/app/modules/tables/services/dining-session.service.ts`,
  `src/app/modules/tables/services/pos-terminal.store.ts`,
  `src/app/modules/tables/components/pos-order-panel.component.ts`, la interfaz `DiningOrder`
  (`dining-order.interface.ts`), y `order-status.util.ts` (donde viva hoy — ver `plan.md`).

---

## Phase 1: Setup

No aplica — `plan.md` (Primary Dependencies) confirma que no hay dependencia nueva ni
inicialización de proyecto nueva en ningún repositorio; toda la infraestructura reutilizada ya
existe. Se pasa directo a Foundational.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Columnas, esquema, interfaz TS, fixture de test y evento de dominio que todas las
historias de usuario necesitan antes de poder implementarse o probarse.

**⚠️ CRITICAL**: Ninguna historia de usuario puede empezar hasta que esta fase esté completa.

- [X] T001 Agregar columnas `kitchen_status` (`String`, nullable, sin `server_default`) y
  `sent_to_kitchen_at` (`DateTime`, nullable, sin `server_default`) al modelo `CustomerOrder`, más
  el índice parcial `idx_customer_orders_kitchen_queue` (`sent_to_kitchen_at`,
  `postgresql_where=text("kitchen_status IS NOT NULL")`, mismo patrón que
  `idx_active_order_per_participant`) en `pos-backend/app/models/customer_order.py`
  (data-model.md).
- [X] T002 Crear la migración Alembic nueva en
  `pos-backend/alembic/versions/{rev}_150_customer_orders_kitchen_status.py`, encadenada sobre el
  head actual, vía `@for_each_tenant_schema` (mismo patrón que
  `c5d6e7f8a9b0_simplify_kitchen_status.py`): `upgrade()` agrega ambas columnas + el índice
  parcial; `downgrade()` hace `op.drop_index(...)` seguido de `op.drop_column(...)` para ambas
  columnas (data-model.md).
- [X] T003 [P] Agregar los campos `kitchen_status: Optional[str]` y
  `sent_to_kitchen_at: Optional[datetime]` a `OrderResponse` en
  `pos-backend/app/api/v1/orders/schemas.py` (data-model.md).
- [X] T004 [P] Agregar los campos `kitchen_status: string | null` y
  `sent_to_kitchen_at: string | null` (ISO 8601) a la interfaz `DiningOrder` en `pos-heladeria`
  (data-model.md).
- [X] T005 [P] Extender `orders_fixtures.make_customer_order` en
  `pos-backend/app/characterization_tests/orders_fixtures.py` para aceptar
  `kitchen_status`/`payment_status`/`status` como parámetros opcionales, si aún no los acepta —
  sin crear una fixture nueva (research.md Decisión 9).
- [X] T006 Agregar la función de evento `order_sent_to_kitchen(tenant_id, *, order_id,
  table_session_id)` en `pos-backend/app/core/events.py`, mismo molde que `order_delivered`
  (payload `{"order_id", "table_session_id", "kitchen_status": "SIN_PREPARAR"}`) (data-model.md,
  research.md Decisión 6).

**Checkpoint**: Modelo, esquema, interfaz, fixture y evento listos — las historias de usuario
pueden empezar.

---

## Phase 3: User Story 1 - El cajero envía un pedido pagado a cocina (Priority: P1) 🎯 MVP

**Goal**: El cajero presiona "Enviar a cocina" sobre un pedido confirmado y pagado (de cualquier
origen) y el pedido queda con `kitchen_status = "SIN_PREPARAR"` y `sent_to_kitchen_at` con la hora
del servidor; el botón desaparece después.

**Independent Test**: Confirmar una orden con `payment_status = 'PAID'` y `kitchen_status` nulo,
presionar "Enviar a cocina", y verificar `kitchen_status = "SIN_PREPARAR"`, `sent_to_kitchen_at`
poblado con hora del servidor, y que el botón deja de mostrarse.

### Tests for User Story 1 ⚠️

> **NOTE**: Escribir estos tests primero y confirmar que fallan antes de implementar.

- [X] T007 [P] [US1] Characterization tests de envío exitoso (orígenes manual, mesa y domicilio,
  más verificación de que `sent_to_kitchen_at` usa la hora del servidor, no la del cliente) en
  `pos-backend/app/characterization_tests/test_orders_kitchen.py` (depende de T005).

### Implementation for User Story 1

- [X] T008 [US1] Implementar `kitchen.send_to_kitchen(db, order_id, tenant_id) -> CustomerOrder`
  en `pos-backend/app/api/v1/orders/kitchen.py`: `SELECT ... FOR UPDATE` sobre la fila (mismo
  patrón que `receive_order`), orden determinístico de validaciones (404 → `status == 'cancelada'`
  → `ConflictError(code="ORDER_NOT_CONFIRMED")` → `kitchen_status is not None` →
  `ConflictError(code="ALREADY_IN_KITCHEN")` → `payment_status != 'PAID'` →
  `ConflictError(code="ORDER_NOT_PAID")` → éxito: `kitchen_status = "SIN_PREPARAR"`,
  `sent_to_kitchen_at = utc_now_naive()`, commit, emite `events.order_sent_to_kitchen`
  post-commit) (depende de T001, T006; contracts/send-to-kitchen.md, research.md Decisiones 0, 3,
  6).
- [X] T009 [US1] Agregar el endpoint `POST /orders/{order_id}/send-to-kitchen` en
  `pos-backend/app/api/v1/orders/router.py`, justo después de `/deliver`, mismo molde
  (`_load_order` al final), con `Depends(require_module_access("cocina"))` y
  `Depends(require_tenant_admin_or_cashier)` (depende de T008; research.md Decisiones 4, 5).
- [X] T010 [US1] Agregar el método `sendToKitchen(orderId): Promise<DiningOrder>` (`POST
  /orders/{id}/send-to-kitchen`) en `pos-heladeria`
  `src/app/modules/tables/services/dining-session.service.ts`, mismo molde que `deliverOrder`
  (depende de T004).
- [X] T011 [US1] Agregar el método async `sendToKitchen(orderId?)` en `pos-heladeria`
  `src/app/modules/tables/services/pos-terminal.store.ts`, mismo molde que `deliverOrder`
  (llama al servicio, espera, `await this.reload()`, reporta errores genéricos vía
  `toast.error(extractError(err, ...))`) (depende de T010).
- [X] T012 [US1] Agregar el helper puro `canSendToKitchen(order, moduleAccess): boolean` en
  `pos-heladeria` `order-status.util.ts`: `order.status !== 'cancelada' && order.payment_status
  === 'PAID' && !order.kitchen_status && moduleAccess.cocina` (research.md Decisión 10).
- [X] T013 [US1] Agregar el botón "Enviar a cocina" en `pos-heladeria`
  `src/app/modules/tables/components/pos-order-panel.component.ts`, visible según
  `canSendToKitchen`, que invoca `store.sendToKitchen(orderId)` (depende de T011, T012).

**Checkpoint**: User Story 1 completamente funcional y probable de forma independiente — envío
exitoso end-to-end para los tres orígenes, botón aparece/desaparece correctamente.

---

## Phase 4: User Story 2 - El sistema impide enviar a cocina pedidos no pagados (Priority: P1)

**Goal**: Un pedido confirmado con `payment_status = 'UNPAID'` no puede enviarse a cocina: el
botón no se muestra y el endpoint rechaza con 409 `ORDER_NOT_PAID`.

**Independent Test**: Visualizar una orden confirmada con pago `UNPAID` — el botón no aparece;
invocar el endpoint directamente — responde 409 con `ORDER_NOT_PAID`.

### Tests for User Story 2 ⚠️

- [X] T014 [P] [US2] Characterization test: `send_to_kitchen` sobre una orden con
  `payment_status = 'UNPAID'` lanza `ConflictError` `ORDER_NOT_PAID` y `kitchen_status` permanece
  `NULL` tras la llamada, en `test_orders_kitchen.py` (depende de T008; FR-006).

### Implementation for User Story 2

La validación `payment_status != 'PAID'` → `ORDER_NOT_PAID` y la condición
`order.payment_status === 'PAID'` en `canSendToKitchen` ya quedan implementadas como parte del
flujo compartido de T008/T012 (Historia 1) — no se requiere código nuevo, solo el test T014 que
verifica el comportamiento de forma independiente para esta historia.

**Checkpoint**: Historias 1 y 2 funcionan de forma independiente.

---

## Phase 5: User Story 3 - El sistema protege la cola ante envíos duplicados (Priority: P2)

**Goal**: Un segundo intento de envío sobre el mismo pedido (doble clic o reintento de red) es
rechazado con 409 `ALREADY_IN_KITCHEN`, sin duplicar el pedido en la cola ni alterar
`sent_to_kitchen_at`; la UI maneja ese código en silencio.

**Independent Test**: Enviar una orden a cocina exitosamente, invocar el envío una segunda vez
sobre la misma orden, y verificar 409 `ALREADY_IN_KITCHEN` con la posición en la cola sin cambios.

### Tests for User Story 3 ⚠️

- [X] T015 [P] [US3] Characterization tests: segundo envío sobre una orden ya en cocina devuelve
  `ConflictError` `ALREADY_IN_KITCHEN` sin modificar `kitchen_status`/`sent_to_kitchen_at`
  originales, más un test de carrera concurrente (dos invocaciones casi simultáneas vía
  `SELECT ... FOR UPDATE`, solo una tiene éxito), en `test_orders_kitchen.py` (depende de T008;
  FR-007, FR-008, SC-003).

### Implementation for User Story 3

- [X] T016 [US3] Manejar `ALREADY_IN_KITCHEN` en silencio en `sendToKitchen` de `pos-heladeria`
  `pos-terminal.store.ts`: si `err.error?.error?.code === 'ALREADY_IN_KITCHEN'`, solo
  `await this.reload()` sin `toast.error`; cualquier otro error sigue mostrando el toast con
  `extractError` (depende de T011; research.md Decisiones 3, 10; clarificación 2 de `spec.md`).

**Checkpoint**: Las tres historias de usuario funcionan de forma independiente y conjunta.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Edge cases de `spec.md` que no pertenecen a una sola historia (gating de módulo, rol,
orden cancelada) y verificación final end-to-end.

- [X] T017 [P] Characterization test: `send_to_kitchen` sobre una orden con `status == 'cancelada'`
  devuelve `ConflictError` `ORDER_NOT_CONFIRMED`, en `test_orders_kitchen.py` (depende de T008;
  FR-010, edge case).
- [X] T018 [P] Characterization test (o test de integración de router): un usuario sin rol
  `ADMIN`/`CASHIER` recibe 403 al invocar `POST /orders/{order_id}/send-to-kitchen`, en
  `test_orders_kitchen.py` (depende de T009; FR-011, edge case).
- [X] T019 [P] Characterization test (o test de integración de router): un tenant cuyo plan no
  incluye el módulo `"cocina"` recibe 403 `MODULE_NOT_IN_PLAN` al invocar el endpoint, en
  `test_orders_kitchen.py` (depende de T009; edge case de `spec.md`).
- [X] T020 Ejecutar la verificación de migración de `quickstart.md` (`SELECT count(*) FROM
  customer_orders WHERE kitchen_status IS NOT NULL` / `sent_to_kitchen_at IS NOT NULL` → ambos 0
  tras `alembic upgrade head`) y recorrer manualmente los 4 escenarios de `quickstart.md`.
- [X] T021 Ejecutar `ng test` en `pos-heladeria` y comparar los archivos que fallan contra el
  baseline documentado en
  `specs/148-disponibilidad-productos-tiempo-real/checklists/baseline-suites.md` — criterio de
  éxito: ningún archivo **nuevo** fallando.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Foundational (Phase 2)**: Sin dependencias — bloquea todas las historias de usuario.
- **User Story 1 (Phase 3)**: Depende de Foundational (T001, T004, T006). Sin dependencia de otras
  historias.
- **User Story 2 (Phase 4)**: Depende de T008 (US1) — reutiliza la validación ya implementada; solo
  agrega su test.
- **User Story 3 (Phase 5)**: Depende de T008 (US1, para los tests) y T011 (US1, para el manejo
  silencioso en la store).
- **Polish (Phase 6)**: Depende de T008/T009 (US1).

### Dentro de cada historia

- Tests antes de la implementación (T007 antes de T008; T014/T015 reutilizan T008 ya implementado
  para verificarlo de forma independiente).
- Modelo/esquema (Foundational) antes de servicio (T008) antes de endpoint (T009) antes de
  servicio HTTP de frontend (T010) antes de store (T011) antes de componente (T012, T013).

### Oportunidades de paralelismo

- T003, T004, T005 (Foundational) se pueden hacer en paralelo — archivos distintos.
- T007 (test de US1) es independiente de la implementación hasta que se ejecute contra ella.
- T014, T015, T017, T018, T019 son todos tests sobre `test_orders_kitchen.py` que se pueden
  escribir en paralelo entre sí (aunque compartan archivo, son casos nuevos sin solaparse), una
  vez que T008/T009 existen.

---

## Parallel Example: Foundational

```bash
Task: "Agregar kitchen_status/sent_to_kitchen_at a OrderResponse en pos-backend/app/api/v1/orders/schemas.py"
Task: "Agregar kitchen_status/sent_to_kitchen_at a DiningOrder en pos-heladeria"
Task: "Extender orders_fixtures.make_customer_order en pos-backend/app/characterization_tests/orders_fixtures.py"
```

---

## Implementation Strategy

### MVP First (User Story 1 solamente)

1. Completar Phase 2: Foundational.
2. Completar Phase 3: User Story 1 (T007–T013).
3. **Detener y validar**: probar el envío exitoso de forma independiente (Escenario 1 de
   `quickstart.md`).
4. Esto ya es un incremento desplegable — el botón funciona end-to-end para los tres orígenes.

### Entrega incremental

1. Foundational → base lista.
2. User Story 1 → Validar → MVP.
3. User Story 2 → Agregar su test (sin código nuevo) → Validar.
4. User Story 3 → Agregar manejo silencioso + sus tests → Validar.
5. Polish → edge cases restantes (módulo, rol, cancelada) + verificación de migración + `ng test`.

## Notes

- `[P]` = archivos distintos, sin dependencias entre sí.
- La etiqueta `[Story]` mapea cada tarea a su historia de usuario para trazabilidad.
- Las Historias 2 y 3 reutilizan código ya escrito en la Historia 1 (`kitchen.send_to_kitchen` es
  una función compartida con un orden de validación único, fijado por `data-model.md`) — esto es
  intencional, no una violación de independencia: cada historia sigue siendo probable de forma
  aislada con su propio test, aunque el código de producción ya exista.
- Commitear después de cada tarea o grupo lógico.
- Detenerse en cada checkpoint para validar la historia de forma independiente.
