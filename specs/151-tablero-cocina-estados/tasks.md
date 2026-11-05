---

description: "Task list for feature implementation"
---

# Tasks: Tablero de cocina en tres columnas con movimiento de pedidos

**Input**: Design documents from `/specs/151-tablero-cocina-estados/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/kitchen-board.md,
contracts/move-kitchen-status.md, quickstart.md

**Tests**: quickstart.md pide explícitamente casos nuevos en
`test_orders_kitchen.py` (éxito, los 4 códigos de error, 403 por rol, concurrencia) y specs
nuevos de frontend (componente del tablero, guard de rol) — por lo tanto SÍ se incluyen tareas
de test.

**Organización**: Las tareas se agrupan por historia de usuario (US1–US4 de `spec.md`) para que
cada una se pueda implementar y probar de forma independiente. Todas las rutas son relativas a
los repos sibling de `pos-specs`: `../pos-backend` y `../pos-heladeria`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Puede ejecutarse en paralelo (archivos distintos, sin dependencias)
- **[Story]**: Historia de usuario a la que pertenece (US1, US2, US3, US4)

## Path Conventions

- Backend: `pos-backend/app/...` (FastAPI)
- Frontend: `pos-heladeria/src/app/...` (Angular standalone + signals)

---

## Phase 1: Setup (Shared Infrastructure)

**Propósito**: Preparar el rol `KITCHEN` de extremo a extremo (molde de `MESERO`, spec 075) —
prerrequisito transversal a todas las historias porque FR-014 depende de que el rol exista y sea
asignable.

- [X] T001 Agregar `"KITCHEN"` a la tupla `ROLE_NAMES` en `pos-backend/app/core/db.py` (research.md
  Decisión 1)
- [X] T002 [P] Crear migración de datos `pos-backend/alembic/versions/{rev}_151_seed_kitchen_role.py`
  que siembra `shared.roles.KITCHEN` de forma idempotente por `name`, mismo molde que
  `8421e9a2b45a_seed_mesero_role.py`; `downgrade()` hace `DELETE` solo si ningún `User`/
  `UserInvitation` referencia el rol (data-model.md §Estrategia de migración)
- [X] T003 [P] Agregar `KITCHEN = "KITCHEN"` al enum `RoleName` en
  `pos-backend/app/api/v1/users/schemas.py` (research.md Decisión 1)
- [X] T004 [P] Agregar `KITCHEN = 'kitchen'` al enum `UserRole` en
  `pos-heladeria/src/app/core/interfaces/user.interface.ts` (research.md Decisión 1)
- [X] T005 Aplicar la migración localmente (`alembic upgrade head`) y verificar que
  `shared.roles` contiene la fila `KITCHEN` (quickstart.md §Prerrequisitos)

**Checkpoint**: El rol `KITCHEN` existe en la base de datos y en ambos enums (backend/frontend);
listo para que las dependencias de autorización lo referencien.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Propósito**: Infraestructura de autorización, evento realtime y esquemas compartidos que
TODAS las historias necesitan antes de poder implementarse.

**⚠️ CRITICAL**: Ninguna historia de usuario puede empezar hasta que esta fase esté completa.

- [X] T006 [P] Agregar dependencia `require_kitchen_board_view` (acepta `ADMIN`/`CASHIER`/
  `KITCHEN`, 403 si no) en `pos-backend/app/core/dependencies.py`, mismo molde que
  `require_tenant_admin_or_cashier` (research.md Decisión 2)
- [X] T007 [P] Agregar dependencia `require_kitchen_role` (acepta únicamente `KITCHEN`, 403 si
  no) en `pos-backend/app/core/dependencies.py` (research.md Decisión 2)
- [X] T008 [P] Agregar función `order_kitchen_status_changed(tenant_id, *, order_id,
  table_session_id, kitchen_status, version)` en `pos-backend/app/core/events.py`, publicada en
  el canal `CH_STAFF` ya existente con tipo `"order.kitchen_status_changed"` (research.md
  Decisión 0, data-model.md §Evento realtime nuevo)
- [X] T009 [P] Agregar esquemas Pydantic `KitchenBoardResponse`, `KitchenCardOut`,
  `ChangeKitchenStatusIn` en `pos-backend/app/api/v1/orders/schemas.py`, con
  `kitchen_status: Literal["SIN_PREPARAR", "EN_PROGRESO", "LISTO"]` y `version: int` obligatorio
  en `ChangeKitchenStatusIn` (contracts/kitchen-board.md, contracts/move-kitchen-status.md)
- [X] T010 [P] Agregar el tipo de evento nuevo `order.kitchen_status_changed` al modelo de
  eventos existente (`realtime-event.model.ts`) en
  `pos-heladeria/src/app/core/realtime/realtime.service.ts` (research.md Decisión 0)

**Checkpoint**: Dependencias de autorización, evento realtime y esquemas listos — las historias
de usuario pueden implementarse.

---

## Phase 3: User Story 1 - Ver los pedidos en orden de llegada por columna (Priority: P1) 🎯 MVP

**Goal**: Mostrar las tres columnas fijas con los pedidos enviados a cocina, ordenados FIFO por
`sent_to_kitchen_at` (desempate por `id`), sin posibilidad de reordenar manualmente dentro de una
columna.

**Independent Test**: Enviar dos pedidos pagados a cocina con `sent_to_kitchen_at` distinto,
abrir el tablero, verificar que ambos aparecen en "SIN PREPARAR" ordenados del más antiguo al
más reciente, sin poder arrastrarlos dentro de la misma columna.

### Tests for User Story 1 ⚠️

- [X] T011 [P] [US1] Casos de test para `GET /orders/kitchen-board` en
  `pos-backend/app/characterization_tests/test_orders_kitchen.py`: tres columnas vacías sin
  pedidos; dos pedidos con `sent_to_kitchen_at` distinto quedan en orden ascendente; dos pedidos
  con el mismo `sent_to_kitchen_at` quedan ordenados por `id` ascendente (desempate); un pedido
  `cancelada`/`entregada` con `kitchen_status` no nulo NO aparece (FR-011, adelantado aquí porque
  la query de lectura ya lo filtra)

### Implementation for User Story 1

- [X] T012 [US1] Implementar función de servicio de lectura del tablero (agrupación en Python de
  un solo `SELECT` filtrado por `kitchen_status IS NOT NULL AND status NOT IN ('cancelada',
  'entregada')`, `ORDER BY sent_to_kitchen_at ASC, id ASC`) en
  `pos-backend/app/api/v1/orders/kitchen.py`, reutilizando `idx_customer_orders_kitchen_queue`
  (data-model.md §Vista del tablero)
- [X] T013 [US1] Agregar endpoint `GET /orders/kitchen-board` en
  `pos-backend/app/api/v1/orders/router.py` con `Depends(require_kitchen_board_view)`,
  respondiendo `KitchenBoardResponse` con las tres listas agrupadas (contracts/kitchen-board.md)
- [X] T014 [P] [US1] Crear interfaces TypeScript espejo de `KitchenBoardResponse`/`KitchenCardOut`
  en `pos-heladeria/src/app/modules/kitchen/interfaces/kitchen-board.interface.ts`
  (contracts/kitchen-board.md)
- [X] T015 [US1] Crear `KitchenBoardService` con método `getBoard()` (GET /orders/kitchen-board)
  en `pos-heladeria/src/app/modules/kitchen/services/kitchen-board.service.ts`
- [X] T016 [US1] Crear `KitchenBoardPageComponent` (standalone) con las tres columnas fijas
  ("SIN PREPARAR"/"EN PROGRESO"/"LISTO"), carga inicial vía `KitchenBoardService.getBoard()`, en
  `pos-heladeria/src/app/modules/kitchen/pages/kitchen-board-page.component.ts`
- [X] T017 [US1] Integrar `@angular/cdk/drag-drop` en `KitchenBoardPageComponent` configurado
  para permitir arrastre *entre* columnas pero bloquear el reordenamiento *dentro* de la misma
  columna (FR-004, research.md Decisión 7); confirmar primero en `package.json` si
  `@angular/cdk` ya está presente (plan.md §Primary Dependencies)
- [X] T018 [US1] Revertir el redirect de `cocina` en
  `pos-heladeria/src/app/modules/dashboard/routes.ts` (quitar `redirectTo: 'mesas-sesiones'` y el
  comentario "se deprecó") y montar `KitchenBoardPageComponent` con carga diferida, protegido por
  `roleGuard([UserRole.ADMIN, UserRole.CASHIER, UserRole.KITCHEN])` (research.md Decisión 10)
- [X] T019 [US1] Agregar `ROLE_DEFAULT_ROUTES[UserRole.KITCHEN] = '/dashboard/cocina'` en
  `pos-heladeria/src/app/core/guards/role.guard.ts` (research.md Decisión 10)
- [X] T020 [US1] Agregar entrada de menú "Cocina" con
  `roles: [UserRole.ADMIN, UserRole.CASHIER, UserRole.KITCHEN]` en
  `pos-heladeria/src/app/core/config/navigation.config.ts` (research.md Decisión 10)

**Checkpoint**: El tablero muestra las tres columnas con FIFO correcto y es accesible desde la
navegación por los tres roles — historia 1 completamente funcional e independiente.

---

## Phase 4: User Story 2 - Mover un pedido entre columnas (Priority: P1)

**Goal**: Permitir que `KITCHEN` mueva una tarjeta entre cualquiera de las tres columnas
(incluyendo retrocesos), gateado por pago `PAID`, orden activa y módulo `"cocina"` activo, con
concurrencia resuelta vía `version` y 409 ante conflicto.

**Independent Test**: Mover un pedido pagado de "SIN PREPARAR" a "EN PROGRESO" y verificar que
`kitchen_status` cambia, que `status`/`payment_status` no se modifican, y que un movimiento
concurrente con `version` obsoleto recibe 409 `KITCHEN_STATUS_CONFLICT`.

### Tests for User Story 2 ⚠️

- [X] T021 [P] [US2] Casos de test para `change_kitchen_status` en
  `pos-backend/app/characterization_tests/test_orders_kitchen.py`: éxito (cambia
  `kitchen_status`, incrementa `version`, no toca `status`/`payment_status`/
  `sent_to_kitchen_at`); retroceso de `LISTO` a `EN_PROGRESO` aceptado; 409 `NOT_IN_KITCHEN`
  cuando `kitchen_status` actual es `NULL`; 409 `KITCHEN_STATUS_CONFLICT` cuando `version` no
  coincide (payload incluye el `kitchen_status` vigente); 409 `PAYMENT_NOT_PAID` cuando
  `payment_status != 'PAID'`; 409 `ORDER_NOT_ACTIVE` cuando `status IN ('cancelada',
  'entregada')`; 409 cuando el módulo `"cocina"` no está activo; 403 cuando el usuario no es
  `KITCHEN`; dos locks (`SELECT ... FOR UPDATE`) concurrentes sobre la misma orden → exactamente
  uno aplica, el otro recibe `KITCHEN_STATUS_CONFLICT` (research.md Decisión 9, contracts/
  move-kitchen-status.md §Orden de validaciones)

### Implementation for User Story 2

- [X] T022 [US2] Implementar `change_kitchen_status(db, order_id, kitchen_status, version,
  tenant_id)` en `pos-backend/app/api/v1/orders/kitchen.py` con `SELECT ... FOR UPDATE` y el
  orden determinístico de validaciones: 404 → `NOT_IN_KITCHEN` → `KITCHEN_STATUS_CONFLICT` →
  `PAYMENT_NOT_PAID` → `ORDER_NOT_ACTIVE` → éxito (`kitchen_status` actualizado, `version += 1`,
  publica `events.order_kitchen_status_changed`), usando
  `app.core.domain_errors.ConflictError` para los códigos 409 (contracts/move-kitchen-status.md,
  depende de T012)
- [X] T023 [US2] Agregar endpoint `POST /orders/{order_id}/kitchen-status` en
  `pos-backend/app/api/v1/orders/router.py` con `Depends(require_kitchen_role)` y
  `Depends(require_module_access("cocina"))`, respondiendo 200 con `KitchenCardOut` actualizado
  (contracts/move-kitchen-status.md, depende de T013)
- [X] T024 [US2] Agregar método `moveCard(orderId, kitchenStatus, version)` (POST
  /orders/{id}/kitchen-status) en
  `pos-heladeria/src/app/modules/kitchen/services/kitchen-board.service.ts` (depende de T015)
- [X] T025 [US2] Conectar el drop de `@angular/cdk/drag-drop` en `KitchenBoardPageComponent` para
  llamar `KitchenBoardService.moveCard()`, con actualización óptica inmediata de la tarjeta a la
  nueva columna (depende de T016, T017, T024)
- [X] T026 [US2] Manejar los 409 (`NOT_IN_KITCHEN`, `KITCHEN_STATUS_CONFLICT`,
  `PAYMENT_NOT_PAID`, `ORDER_NOT_ACTIVE`) en `KitchenBoardPageComponent`: devolver la tarjeta
  visualmente a su columna de origen, mostrar mensaje de error, y en el caso de
  `KITCHEN_STATUS_CONFLICT` reflejar el `kitchen_status` vigente que viene en el payload del
  error (FR-009, contracts/move-kitchen-status.md §Errores, depende de T025)
- [X] T027 [US2] Ocultar el control de arrastre (drag handle) en `KitchenCardComponent`/
  `KitchenBoardPageComponent` cuando `currentUser().role !== UserRole.KITCHEN` (FR-014 frontend,
  research.md Decisión 10, depende de T016)

**Checkpoint**: `KITCHEN` puede mover tarjetas entre columnas con las tres condiciones de negocio
y concurrencia resueltas; `ADMIN`/`CASHIER` solo ven. Historias 1 y 2 funcionan juntas.

---

## Phase 5: User Story 3 - La tarjeta siempre muestra la información necesaria para preparar el pedido (Priority: P2)

**Goal**: Cada tarjeta muestra número de orden, origen, cliente/mesa, productos con cantidades,
adiciones, notas y tiempo transcurrido desde `sent_to_kitchen_at`.

**Independent Test**: Abrir el tablero con un pedido con productos, adiciones y notas; verificar
que la tarjeta muestra todos esos datos más el tiempo transcurrido, calculado y actualizado sin
recargar.

### Tests for User Story 3 ⚠️

- [X] T028 [P] [US3] Casos de test para la serialización de `KitchenCardOut` en
  `pos-backend/app/characterization_tests/test_orders_kitchen.py`: pedido `DINE_IN` serializa
  `origin="mesa"` con `table_number` presente y `customer_name`/`delivery_address` en `null`;
  pedido `DELIVERY` serializa `origin="domicilio"` con `customer_name`/`delivery_address`
  presentes y `table_number` en `null`; pedido `TAKEAWAY` sin cliente serializa `origin="caja"`
  sin nombre (edge case, sin error); productos con adiciones y notas se incluyen completos
  (contracts/kitchen-board.md §CardResponse)

### Implementation for User Story 3

- [X] T029 [US3] Extender la serialización de `KitchenCardOut` en
  `pos-backend/app/api/v1/orders/kitchen.py` para derivar `origin` desde `order_type`
  (`DINE_IN`→"mesa", `TAKEAWAY`→"caja", `DELIVERY`→"domicilio") e incluir `table_number`/
  `customer_name`/`delivery_address`/`notes`/`items` (con `product_name`, `quantity`, `addons`,
  `notes` por producto), reutilizando la lógica de serialización ya existente de
  `OrderItemResponse`/`_load_order` (data-model.md §CustomerOrder, depende de T012)
- [X] T030 [P] [US3] Crear `KitchenCardComponent` (standalone) en
  `pos-heladeria/src/app/modules/kitchen/components/kitchen-card.component.ts` mostrando número
  de orden, origen con mesa/cliente/dirección según corresponda, lista de productos con
  cantidades y adiciones, notas, y tiempo transcurrido calculado desde `sent_to_kitchen_at`
- [X] T031 [US3] Implementar el cálculo del tiempo transcurrido en `KitchenCardComponent` con un
  `signal`/temporizador que se actualiza mientras el tablero permanece abierto, sin requerir
  recarga manual (plan.md §Assumptions, depende de T030)
- [X] T032 [US3] Montar `KitchenCardComponent` dentro de cada columna de
  `KitchenBoardPageComponent`, pasando el `CardResponse` correspondiente (depende de T016, T030)

**Checkpoint**: Las tarjetas muestran toda la información operativa necesaria sin consultar otra
pantalla — historia 3 verificable de forma independiente sobre US1/US2 ya funcionando.

---

## Phase 6: User Story 4 - El tablero refleja solo pedidos activos para cocina (Priority: P2)

**Goal**: Las tarjetas desaparecen del tablero en tiempo real cuando la orden se cancela o llega
a su estado final (cerrada/entregada), y los cambios de `kitchen_status` se propagan a todos los
tableros abiertos del tenant vía el canal `CH_STAFF` existente.

**Independent Test**: Cancelar una orden que está en "EN PROGRESO" y verificar que su tarjeta
desaparece del tablero inmediatamente en todas las sesiones abiertas, sin recargar.

### Tests for User Story 4 ⚠️

- [X] T033 [P] [US4] Verificar en `pos-backend/app/characterization_tests/test_orders_kitchen.py`
  que tras cancelar o entregar una orden con `kitchen_status` no nulo, `GET
  /orders/kitchen-board` ya no la incluye en ninguna columna, aunque su `kitchen_status` en la
  fila siga sin limpiarse (FR-011, data-model.md §Vista del tablero — puede reutilizar/extender
  el caso ya cubierto en T011)

### Implementation for User Story 4

- [X] T034 [US4] Suscribir `KitchenBoardPageComponent` a `RealtimeService` para los tipos de
  evento `order.kitchen_status_changed` (nuevo, T008/T010), `order.cancelled` y
  `order.delivered` (ya existentes), actualizando o retirando la tarjeta correspondiente sin
  recargar la página (research.md Decisión 0/6, data-model.md §Evento realtime nuevo, depende de
  T016)
- [X] T035 [US4] Al recibir `order.kitchen_status_changed` para una orden que no es la que el
  usuario local movió, actualizar su columna y `version` en el estado del tablero (para que un
  movimiento posterior del mismo usuario use el `version` vigente); al recibir
  `order.cancelled`/`order.delivered`, retirar la tarjeta de cualquier columna donde esté
  (depende de T034)

**Checkpoint**: Todas las sesiones del tablero del mismo tenant se mantienen sincronizadas en
tiempo real; las tarjetas obsoletas desaparecen sin intervención manual. Las 4 historias
funcionan juntas.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Propósito**: Mejoras transversales y verificación final de extremo a extremo.

- [X] T036 [P] Agregar la opción de rol `KITCHEN` al selector de roles en
  `pos-heladeria/src/app/modules/users/components/invitation-form.component.ts`, mismo patrón
  que `MESERO` (plan.md §Source Code)
- [X] T037 [P] Agregar/actualizar specs de Vitest para `KitchenBoardPageComponent` (columnas,
  drag-and-drop entre columnas bloqueado dentro de la misma columna, manejo de los 4 códigos
  409) y para `role.guard.ts` (ruta `/dashboard/cocina` accesible para `KITCHEN` y bloqueada para
  otros roles no listados) en sus respectivos `*.spec.ts` (quickstart.md §Verificación
  automatizada)
- [X] T038 Ejecutar `python -m unittest discover -s app/characterization_tests -p 'test_*.py'`
  en `pos-backend` y confirmar que ningún test `"CONGELA comportamiento actual:"` existente se
  rompe (Principio III)
- [X] T039 Ejecutar `ng test` en `pos-heladeria` y confirmar que ningún archivo **nuevo** falla
  frente al baseline flaky ya documentado (memoria de proyecto: diff por archivo, no conteo
  total)
- [X] T040 Recorrer manualmente `quickstart.md` completo (las 4 historias + tiempo real +
  concurrencia) contra `pos-backend`/`pos-heladeria` corriendo localmente, incluyendo el
  escenario de dos sesiones simultáneas (una `KITCHEN`, una `CASHIER`) para confirmar la
  propagación realtime (FR-015)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Sin dependencias — puede iniciar de inmediato.
- **Foundational (Phase 2)**: Depende de que el rol `KITCHEN` exista (Phase 1, T001-T005) para
  que las dependencias de autorización (T006/T007) tengan un rol válido que referenciar —
  BLOQUEA todas las historias de usuario.
- **User Story 1 (Phase 3)**: Depende de Foundational. Es la base — las demás historias extienden
  lo que US1 construye.
- **User Story 2 (Phase 4)**: Depende de Foundational y de US1 (necesita el endpoint de lectura
  T013 y el componente T016/T017 para poder mover tarjetas que ya se muestran).
- **User Story 3 (Phase 5)**: Depende de Foundational y de US1 (extiende la serialización T012 y
  el componente T016 de US1); independiente de US2 (no depende del movimiento de tarjetas).
- **User Story 4 (Phase 6)**: Depende de Foundational, US1 (componente T016) y del evento nuevo
  de US2 (T008/T022, para escuchar `order.kitchen_status_changed`).
- **Polish (Phase 7)**: Depende de que todas las historias deseadas estén completas.

### User Story Dependencies

- US1 → ninguna historia (base del tablero).
- US2 → US1 (necesita el tablero visible para mover tarjetas sobre él).
- US3 → US1 (necesita el tablero visible para mostrar la información en cada tarjeta).
- US4 → US1 + US2 (necesita el tablero y el evento de cambio de estado para retirar tarjetas en
  tiempo real).

### Within Each User Story

- Tests antes de implementación (escribirlos primero, verificar que fallan).
- Backend (servicio → endpoint) antes de frontend (servicio Angular → componente).
- Dentro del frontend: interfaces/servicio antes de componente.

### Parallel Opportunities

- T002, T003, T004 (Phase 1) en paralelo tras T001.
- T006, T007, T008, T009, T010 (Phase 2) en paralelo entre sí.
- T011 (test US1) en paralelo con el resto de Setup/Foundational de otras historias si el equipo
  lo permite, pero debe completarse antes de T012.
- T014 (interfaz TS) en paralelo con T012/T013 (backend) dentro de US1.
- T021 (test US2) en paralelo con el cierre de US1.
- T028 (test US3) en paralelo con la implementación de US2.
- T030 (componente de tarjeta) en paralelo con T029 (serialización backend) dentro de US3.
- T036, T037 (Polish) en paralelo entre sí.

---

## Parallel Example: User Story 1

```bash
# Tests primero:
Task: "Casos de test para GET /orders/kitchen-board en test_orders_kitchen.py"

# Luego, en paralelo, servicio backend y interfaz frontend:
Task: "Implementar función de servicio de lectura del tablero en kitchen.py"
Task: "Crear interfaces TypeScript espejo de KitchenBoardResponse en kitchen-board.interface.ts"
```

---

## Implementation Strategy

### MVP First (User Story 1 + User Story 2)

1. Completar Phase 1: Setup (rol `KITCHEN` de extremo a extremo).
2. Completar Phase 2: Foundational (CRÍTICO — bloquea todas las historias).
3. Completar Phase 3: User Story 1 (tablero de solo lectura con FIFO correcto).
4. **DETENER y VALIDAR**: probar US1 de forma independiente (quickstart.md Historia 1).
5. Completar Phase 4: User Story 2 (mover tarjetas) — sin esto el tablero es de solo lectura y no
   cumple el objetivo central de la spec.
6. **DETENER y VALIDAR**: probar US2 (quickstart.md Historia 2 + Concurrencia).
7. Desplegar/demo del MVP (US1+US2 ya cubren las dos historias P1 de `spec.md`).

### Incremental Delivery

1. Setup + Foundational → base lista.
2. US1 → tablero visible y navegable → validar → demo.
3. US2 → movimiento de tarjetas con gating de negocio y concurrencia → validar → demo (MVP
   completo, las dos historias P1).
4. US3 → información completa en cada tarjeta → validar → demo.
5. US4 → retiro automático y sincronización en tiempo real entre tableros → validar → demo.
6. Polish → selector de roles, specs de frontend, verificación completa de quickstart.md.

### Parallel Team Strategy

Con varios desarrolladores:

1. El equipo completa Setup + Foundational junto.
2. Una vez lista Foundational y US1:
   - Desarrollador A: User Story 2 (movimiento de tarjetas).
   - Desarrollador B: User Story 3 (información de la tarjeta) — no depende de US2.
3. Tras US2: Desarrollador A o C toma User Story 4 (depende del evento de US2).
4. Polish al final, en paralelo entre los dos últimos ítems (T036/T037).

---

## Notes

- `[P]` = archivos distintos, sin dependencias entre sí.
- La etiqueta de historia (`[US1]`...`[US4]`) permite trazabilidad directa a `spec.md`.
- Cada historia debe quedar completable y probable de forma independiente, según su
  "Independent Test" en `spec.md`.
- Verificar que los tests fallan antes de implementar (T011, T021, T028, T033).
- Ningún test `"CONGELA comportamiento actual:"` existente en `test_orders_kitchen.py` se
  modifica — solo se agregan casos nuevos (Principio III, plan.md Constitution Check).
- Evitar: tocar `OrderItem.estado_cocina` o el ciclo de entrega de spec 147; crear un canal
  realtime nuevo cuando `CH_STAFF` ya resuelve FR-015 (research.md Decisión 0); poner
  `CheckConstraint` sobre `kitchen_status` (spec 150 Decisión 2, no se reabre).
