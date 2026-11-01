# Tasks: Ciclo de Vida Simplificado del Pedido y Control Manual de Mesas

**Input**: Design documents from `/specs/147-entrega-pago-liberacion-mesa/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/orders-api.md, quickstart.md

**Tests**: no se solicitó TDD explícito en el spec; se incluyen tareas de actualización de
`characterization_tests` existentes (Principio III — comportamiento protegido que cambia debe
citar este spec, no quedar roto en silencio) y una tarea de verificación de migración (SC-007).

**Repos reales** (hermanos de este repo de specs): `../pos-backend` (API) y `../pos-heladeria`
(frontend Angular). Todas las rutas de archivo abajo son relativas a esos repos salvo que se
indique `pos-specs/`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: se puede ejecutar en paralelo (archivos distintos, sin dependencias pendientes)
- **[Story]**: US1 (Entregar con un clic), US2 (Pago independiente), US3 (Liberar mesa
  manualmente), US4 (Cancelar un pedido entregado sin cobrar)

---

## Phase 1: Setup

- [X] T001 Crear rama `147-entrega-pago-liberacion-mesa` en `../pos-backend` desde `main`
  actualizado (Principio XIV).
- [X] T002 [P] Crear rama `147-entrega-pago-liberacion-mesa` en `../pos-heladeria` desde `main`
  actualizado (Principio XIV).
- [X] T003 Registrar la decisión de negocio de colapso de estados (5→3 en pedido, 3→2 en pago,
  4→3 en ítem, liberación manual sin TTL) en
  `pos-specs/specs/000-reconocimiento/registro-de-anomalias.md`, citando spec 147 y la fecha
  2026-11-01, **antes** de tocar código de implementación (plan.md, Constitution Check,
  Principio II).

---

## Phase 2: Foundational (Blocking Prerequisites)

**⚠️ CRITICAL**: ninguna historia de usuario puede completarse sin esta fase — todas leen o
escriben los mismos tres campos de estado.

- [ ] T004 Crear migración Alembic
  `../pos-backend/alembic/versions/<rev>_147_simplify_order_item_status_payment.py` siguiendo
  el patrón de `e967f9848848_rename_recibida_to_pendiente_add_payment_status.py` (research.md
  R1/R2): decorador `@for_each_tenant_schema`, guardia `_has_table`; por esquema, en este
  orden exacto: (1) `op.drop_constraint` de `ck_customer_order_status`,
  `ck_customer_order_payment_status`, `ck_order_item_estado_cocina` con el nombre completo
  prefijado por esquema; (2) `UPDATE customer_orders.status`
  (`'abierta'→'pendiente'`, `'bloqueada'→'entregada'`, `'pagada'→'entregada'`); (3)
  `UPDATE customer_orders.payment_status` (`'PARTIAL'→'UNPAID'`); (4)
  `UPDATE order_items.estado_cocina` (`'en_preparacion'→'pendiente'`, `'listo'→'entregado'`,
  `'anulado'→'cancelado'`); (5) `UPDATE` de forzado FR-023 in fine: para pedidos ya
  `'entregada'`, todo ítem no `'cancelado'` → `'entregado'`; para pedidos `'cancelada'`, todo
  ítem → `'cancelado'`; (6) `op.create_check_constraint` de los tres CHECK con los conjuntos
  finales (sin prefijo de esquema en el nombre, R1). Usar `op.execute(text(f'UPDATE
  "{schema}"...'))` sin `:param::cast` dentro de `text()` (memoria de sesión, gotcha de
  Alembic). `downgrade()` documentado como agregado/no exacto, mismo criterio que
  `e967f9848848`.
- [ ] T005 [P] Agregar verificación de migración en
  `../pos-backend/app/characterization_tests/test_migration_147_simplify_status.py`: aplicar
  la migración T004 sobre un esquema de prueba con filas en todos los estados viejos
  (`abierta`, `bloqueada`, `pagada`, `PARTIAL`, `en_preparacion`, `listo`, `anulado`) y
  verificar (a) el `SELECT` de control de `data-model.md` (`count(*) == 0` fuera del conjunto
  final, en `customer_orders` y `order_items`), y (b) el caso de forzado FR-023 in fine: una
  fila `bloqueada` con un ítem que era `pendiente` termina `entregada` con ese ítem forzado a
  `entregado` (SC-007).
- [ ] T006 [P] Actualizar `../pos-backend/app/models/customer_order.py`: reescribir
  `ck_customer_order_status` a `('pendiente','entregada','cancelada')`,
  `ck_customer_order_payment_status` a `('UNPAID','PAID')`, y el predicado de
  `idx_active_order_per_participant` (línea ~209-214) de
  `status NOT IN ('pagada','cancelada')` a `status != 'cancelada'`.
- [ ] T007 [P] Actualizar `../pos-backend/app/models/order_item.py`: reescribir
  `ck_order_item_estado_cocina` (línea ~103) a `('pendiente','entregado','cancelado')` y
  `EN_CURSO` (línea 15) de `("pendiente", "en_preparacion")` a `("pendiente",)`.
- [ ] T008 [P] Actualizar `../pos-backend/app/api/v1/orders/schemas.py`: el enum de estado de
  pedido (líneas ~35-42: `ABIERTA`, `BLOQUEADA`, `PAGADA`) pasa a solo
  `PENDIENTE`/`ENTREGADA`/`CANCELADA`; el enum `KitchenStatus`/`estado_cocina` pierde
  `en_preparacion`/`listo`/`anulado` y gana `entregado`/`cancelado`; el enum de
  `payment_status` (línea ~49, `PARTIAL`) pierde ese valor. Revisar `KitchenTransitionIn`
  (línea 455) y `VoidItemIn` (línea 460) por si quedan con un enum obsoleto.
- [ ] T009 [P] Agregar evento `order_delivered(tenant_id, *, order_id, table_session_id)` en
  `../pos-backend/app/core/events.py`, misma forma que `order_confirmed`/`order_cancelled`
  (líneas ~195-262): mismo canal `session:{id}` + `staff` (research.md R8).
- [ ] T010 Actualizar `../pos-backend/app/api/v1/orders/service.py`:
  `_NON_TERMINAL_ORDER_STATUSES` (línea 72) → `("pendiente", "entregada")`;
  `ESTADOS_MOSTRADOS_ORDENES` (línea 504) → `("pendiente", "entregada", "cancelada")`
  (research.md R7).
- [ ] T011 Actualizar `../pos-backend/app/api/v1/cart/service.py`: `_NON_TERMINAL_ORDER_STATUSES`
  (línea 89) → `("pendiente", "entregada")`; revisar la lógica de líneas ~677-706 que compara
  `estado_cocina` contra `("pendiente", "anulado")` y `order.status` contra
  `("pendiente", "abierta")` para usar los valores nuevos (`"cancelado"`, sin `"abierta"`).

**Checkpoint**: modelo de datos, constantes de servicio y evento nuevo listos — las historias
de usuario pueden implementarse.

---

## Phase 3: User Story 1 - Entregar un pedido completo con un solo clic (Priority: P1) 🎯 MVP

**Goal**: una sola acción "Entregar" pasa el pedido completo y todos sus ítems `pendiente` a
`entregado`, sin acción por ítem individual, de forma idempotente.

**Independent Test**: crear un pedido con varios ítems en `pendiente` y presionar "Entregar";
verificar que el pedido y todos sus ítems quedan en `entregado` en una sola operación (sin que
exista aún pago separado o liberación de mesa).

### Implementation for User Story 1

- [ ] T012 [US1] Implementar la acción de entrega en
  `../pos-backend/app/api/v1/orders/checkout.py` (o módulo nuevo `deliver.py` junto a
  `kitchen.py`): función que, con `SELECT ... FOR UPDATE` sobre la fila de `CustomerOrder`
  (mismo patrón que `checkout.py:155`/`:677`): si `status == 'cancelada'` → `HTTPException`
  409 "transición inválida" (FR-010); si `status == 'entregada'` → promueve cualquier ítem
  `'pendiente'` a `'entregado'` y responde éxito, sin emitir evento si no hubo cambios
  (FR-002a, idempotente); si `status == 'pendiente'` → pasa `status` a `'entregada'` y todos
  los ítems `'pendiente'` a `'entregado'`, sin tocar `payment_status` (FR-001/FR-003). Emite
  `order_delivered` (T009) después del commit.
- [ ] T013 [US1] Agregar endpoint `POST /orders/{order_id}/deliver` en
  `../pos-backend/app/api/v1/orders/router.py`, `response_model=OrderResponse`, usando la
  función de T012.
- [ ] T014 [US1] Retirar el endpoint `PATCH /items/{item_id}/kitchen`
  (`router.py` líneas ~383-411) y `kitchen.transition_kitchen` + `_ALLOWED`
  (`kitchen.py` líneas ~29-52); retirar `KitchenTransitionIn` si queda sin otro uso (FR-002,
  research.md R4).
- [ ] T015 [US1] Retirar los endpoints `POST /{order_id}/start-preparation` y
  `POST /{order_id}/ready` (`router.py`) y las funciones
  `kitchen.accept_order_for_kitchen`/`kitchen.mark_order_ready` (`kitchen.py`) — el paso
  intermedio "aceptado para cocina"/"listo" por ítem deja de existir, sustituido por la
  acción única de T012/T013 (research.md R4).
- [ ] T016 [US1] Actualizar `kitchen.void_item` (`kitchen.py`): reemplazar la comparación
  `item.estado_cocina == "anulado"` y la asignación `item.estado_cocina = "anulado"` por
  `"cancelado"`; reemplazar el chequeo `order_status == "pagada"` (ese valor ya no existe) por
  el criterio equivalente de pedido cerrado (`payment_status == "PAID"`) para seguir
  bloqueando la anulación de un ítem ya cobrado.
- [ ] T017 [P] [US1] Actualizar
  `../pos-heladeria/src/app/modules/tables/interfaces/dining.interface.ts`:
  `DiningOrderStatus` → `'pendiente' | 'entregada' | 'cancelada'`; `KitchenStatus` →
  `'pendiente' | 'entregado' | 'cancelado'`.
- [ ] T018 [P] [US1] Actualizar
  `../pos-heladeria/src/app/modules/orders/order-status.util.ts`: `KNOWN_ORDER_STATUSES`,
  `ORDER_STATUS_CLASSES`, `KNOWN_KITCHEN_STATUSES`, `KITCHEN_STATUS_CLASSES`,
  `TERMINAL_ORDER_STATUSES` a los nuevos 3 valores de pedido / 3 de ítem; retirar
  `KITCHEN_NOT_READY`, `hasPendingKitchenWork` y `pedidoAceptadoSinCobrar` (el paso
  intermedio que describían ya no existe tras T015).
- [ ] T019 [US1] En
  `../pos-heladeria/src/app/modules/tables/components/pos-order-panel.component.ts` y
  `pos-tables-panel.component.ts`: retirar los controles de entrega por ítem y de "aceptar
  pedido"/"marcar listo"; agregar un único botón "Entregar" que llama a
  `POST /orders/{id}/deliver` (T013) y refresca el pedido con la respuesta.
- [ ] T020 [US1] Actualizar
  `../pos-backend/app/characterization_tests/test_orders_kitchen.py` (y cualquier otro test
  que ejercite `kitchen_transition`/`start-preparation`/`ready`) para reflejar su retiro,
  citando spec 147 explícitamente en el test o en su eliminación (Principio III).

**Checkpoint**: Historia 1 completa y verificable de forma independiente.

---

## Phase 4: User Story 2 - Ver el estado de pago separado del estado del pedido (Priority: P1)

**Goal**: `status` y `payment_status` evolucionan por separado: entregar no cambia el pago,
cobrar no cambia la orden; ambos se muestran por separado; existe un filtro "entregadas sin
cobrar".

**Independent Test**: mostrar una orden "Entregada"+"Sin pagar" y otra "Entregada"+"Pagado" en
la Terminal y en el detalle, verificando que ambos indicadores se muestran por separado.

### Implementation for User Story 2

- [ ] T021 [US2] Reescribir en `../pos-backend/app/api/v1/orders/checkout.py`: `block_order`
  (línea ~192), `pay_order` (línea ~605), y el paso de `confirm_order`/`checkout_and_send`
  que fija `order.status = "abierta"` (línea ~650) o `"pagada"` (línea ~844) para dejar de
  mutar `order.status` a esos valores retirados; estas funciones solo mutan `payment_status`
  (`'UNPAID' → 'PAID'`, FR-003/FR-004). Conservar el `SELECT ... FOR UPDATE` existente como
  mecanismo de concurrencia del cobro (ya no depende de un `status` intermedio tipo
  `'bloqueada'`).
- [ ] T022 [US2] Revisar las demás asignaciones `order.status = "pagada"` en `checkout.py`
  (líneas ~1369, ~1717, ~1866 — flujos de cierre de caja / pago dividido) con el mismo
  criterio de T021: pasan a mutar solo `payment_status`.
- [ ] T023 [US2] Actualizar `../pos-backend/app/api/v1/orders/tables_advanced.py` (líneas
  ~41, ~57, ~135): la condición `order.status == "pagada"` (ese valor ya no existe) pasa al
  criterio de pedido cerrado (`order.status == 'entregada' and order.payment_status ==
  'PAID'`).
- [ ] T024 [US2] Actualizar `../pos-backend/app/api/v1/orders/consolidation.py` (líneas ~90,
  ~105, ~222, ~233): `status == "abierta"` (retirado) pasa a usar `'pendiente'` como pedido
  editable por el mesero al que se anexan líneas; `status in ("pagada", "cancelada")` para
  rechazar un anexo pasa a `(status == 'entregada' and payment_status == 'PAID') or status ==
  'cancelada'`.
- [ ] T025 [US2] Agregar o confirmar en `../pos-backend/app/api/v1/orders/service.py` +
  `router.py` un filtro de lectura "entregadas sin cobrar" (FR-014/SC-003):
  `status == 'entregada' AND payment_status == 'UNPAID'`, expuesto como query param (p. ej.
  `?entregadas_sin_cobrar=true`) sobre el listado existente de pedidos.
- [ ] T026 [P] [US2] Actualizar
  `../pos-heladeria/src/app/modules/orders/order-status.util.ts`:
  `KNOWN_PAYMENT_STATUSES`, `PAYMENT_STATUS_LABELS`, `PAYMENT_STATUS_CLASSES` — retirar
  `PARTIAL`.
- [ ] T027 [P] [US2] Actualizar
  `../pos-heladeria/src/app/modules/tables/interfaces/dining.interface.ts`:
  `OrderPaymentStatus` → `'UNPAID' | 'PAID'`.
- [ ] T028 [US2] En
  `../pos-heladeria/src/app/modules/orders/pages/order-detail.component.ts` y en la tarjeta
  de mesa (`pos-tables-panel.component.ts` / `order-summary-card.component.ts`), mostrar
  `status` y `payment_status` como dos indicadores visualmente separados (FR-012); agregar en
  `orders-page.component.ts` el filtro UI "Entregadas sin cobrar" que consume T025.
- [ ] T029 [US2] Confirmar en
  `../pos-heladeria/src/app/modules/tables/services/dining-session.service.ts` que la vista
  QR del comensal reacciona tanto a `order_delivered` (T009, nuevo) como a
  `payment_completed` (ya existente) para reflejar en tiempo real ambos ejes de estado
  (FR-020).
- [ ] T030 [US2] Actualizar los characterization tests que citen `'bloqueada'`, `'pagada'` o
  `'PARTIAL'` en el flujo de cobro (`test_orders_checkout.py`, `test_orders_payment_gate.py`,
  `test_cart_payment_attempts.py`, `test_orders_tables_advanced.py`,
  `test_orders_consolidation.py`), citando spec 147 (Principio III).

**Checkpoint**: Historias 1 y 2 funcionan juntas de forma independiente.

---

## Phase 5: User Story 3 - Decidir cuándo liberar una mesa (Priority: P2)

**Goal**: liberar una mesa es siempre una acción manual del cajero; se rechaza si hay alguna
orden "abierta" (`pendiente`, o `entregada`+`UNPAID`), devolviendo esa lista.

**Independent Test**: ocupar una mesa, cerrar todas sus órdenes (entregadas y pagadas, o
canceladas) y verificar que permanece ocupada hasta que el cajero presiona "Liberar mesa".

### Implementation for User Story 3

- [ ] T031 [US3] En `../pos-backend/app/api/v1/table_sessions/service.py`, sustituir el
  criterio de `has_billable_orders`/`has_pending_balance` (líneas ~66-100, usado en
  `release_paid_session` línea ~446-452) por una función nueva `has_open_orders(db,
  table_session_id)` con el criterio de FR-016: existe alguna orden con
  `status == 'pendiente'` OR (`status == 'entregada'` AND `payment_status == 'UNPAID'`); las
  `'cancelada'` nunca cuentan como abiertas. `release_paid_session` usa esta función; al
  rechazar, el 409 incluye la lista de esas órdenes (id, status, payment_status) en vez del
  mensaje genérico actual (FR-017/SC-004).
- [ ] T032 [US3] Actualizar
  `../pos-backend/app/api/v1/table_sessions/schemas.py` (`ReleaseSessionResponse` o el
  payload de error 409) para incluir la lista de órdenes abiertas devuelta por T031.
- [ ] T033 [P] [US3] Frontend: en la acción "Liberar mesa"
  (`../pos-heladeria/src/app/modules/tables/components/pos-tables-panel.component.ts` /
  `services/table-session.service.ts`), mostrar la lista de órdenes abiertas del 409 (T032) en
  vez del mensaje genérico actual.
- [ ] T034 [P] [US3] Frontend: confirmar o agregar en `pos-tables-panel.component.ts` el
  indicador de tiempo ocupado por mesa a partir de `TableSession.opened_at` (FR-019),
  puramente informativo — verificar que sigue funcionando tras los cambios de status de las
  fases anteriores y que no dispara ninguna acción automática.
- [ ] T035 [US3] Actualizar los characterization tests de `table_sessions` que citen
  `has_billable_orders`/`has_pending_balance`/`'pagada'`/`'bloqueada'`
  (`test_table_sessions_service.py`, `test_table_sessions_router.py`,
  `test_cash_close_active_orders.py`), citando spec 147 (Principio III).

**Checkpoint**: Historias 1, 2 y 3 funcionan juntas de forma independiente.

---

## Phase 6: User Story 4 - Cancelar un pedido entregado que no se pudo cobrar (Priority: P3)

**Goal**: cancelar con motivo obligatorio un pedido `entregada`+`UNPAID`; rechazar si ya está
`PAID` (requiere reembolso) o ya está `cancelada`.

**Independent Test**: llevar una orden a `'entregada'`+`'UNPAID'`, cancelarla con motivo, y
verificar que queda `'cancelada'` sin bloquear la liberación de la mesa.

### Implementation for User Story 4

- [ ] T036 [US4] Actualizar `cancel_order` en `../pos-backend/app/api/v1/orders/checkout.py`
  (línea ~892): permitir cancelar cuando `status == 'entregada' AND payment_status ==
  'UNPAID'` con `motivo` obligatorio (FR-007/FR-008, reusando `OrderCancelLog.motivo`);
  rechazar con 409 "requiere proceso de reembolso, fuera de alcance" si `payment_status ==
  'PAID'` (FR-009); rechazar con 409 "transición inválida" si `status == 'cancelada'`
  (FR-010).
- [ ] T037 [US4] Confirmar que `cancel_order` fuerza `status`/`estado_cocina` de pedido e
  ítems a `'cancelada'`/`'cancelado'` (FR-007), no genera ningún movimiento de caja, y no
  revierte el inventario ya consumido (Assumptions del spec — comportamiento ya existente,
  solo verificar que sigue aplicando sobre los nuevos valores de estado).
- [ ] T038 [P] [US4] Frontend: habilitar la acción "Cancelar" con motivo obligatorio sobre
  pedidos `'entregada'`+`'UNPAID'` en
  `../pos-heladeria/src/app/modules/orders/pages/order-detail.component.ts` /
  `pos-order-panel.component.ts`, mostrando el mensaje de reembolso cuando el pedido ya está
  `'PAID'`.
- [ ] T039 [US4] Actualizar los characterization tests de cancelación en
  `test_orders_checkout.py` para cubrir los nuevos casos `'entregada'+'UNPAID'` (permitido) y
  `'entregada'+'PAID'` (rechazado), citando spec 147.

**Checkpoint**: las 4 historias funcionan juntas de forma independiente.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [ ] T040 [P] Barrido final en ambos repos:
  `grep -rn "'pagada'\|'bloqueada'\|'abierta'\|PARTIAL\|en_preparacion\|'listo'\|'anulado'"`
  (excluyendo migraciones históricas y comentarios que documentan el pasado) y confirmar que
  no queda ninguna referencia viva fuera de lo ya resuelto en las fases anteriores.
- [ ] T041 [P] Actualizar los scripts de desarrollo en `../pos-backend/app/scripts/`
  (`e2e_qr_flow.py`, `test_cancel_inventory.py`, `test_mixed_payment_checkout.py`,
  `test_realtime_stream.py`, `test_receta_obligatoria.py`, `test_split_blindaje.py`) que
  referencien los estados retirados.
- [ ] T042 Ejecutar `quickstart.md` completo (Escenarios 1-4 + verificación de migración,
  SC-007) sobre un tenant de prueba con Postgres local, documentando el resultado de cada
  paso.
- [ ] T043 Ejecutar la suite `pytest` de `pos-backend` (venv, memoria de sesión) y el diff de
  `ng test` de `pos-heladeria` por archivo afectado (baseline flaky — comparar por archivo,
  no por conteo total), confirmando ninguna regresión fuera de lo esperado por este spec.
- [ ] T044 Revisar el Constitution Check de `plan.md`: confirmar que T003 (registro de la
  decisión de negocio) quedó hecho y que ningún characterization test quedó en rojo sin una
  decisión citada explícitamente (Principio III).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias — puede iniciar de inmediato.
- **Foundational (Phase 2)**: depende de Setup. **BLOQUEA** las 4 historias de usuario.
- **User Story 1 (Phase 3)**: depende solo de Foundational.
- **User Story 2 (Phase 4)**: depende de Foundational; T021/T022/T023/T024 no dependen de US1
  pero T029 (SSE del comensal para `order_delivered`) requiere T009/T012/T013 de US1.
- **User Story 3 (Phase 5)**: depende de Foundational y lee el modelo de estados que US1/US2
  terminan de fijar (FR-016 combina `status` y `payment_status`); ejecutable en paralelo con
  US1/US2 si se acepta codificar el criterio FR-016 contra el modelo ya definido en Foundational
  (no requiere que los endpoints de US1/US2 existan, solo el modelo de datos).
- **User Story 4 (Phase 6)**: depende de Foundational; conceptualmente depende de que
  `'entregada'`/`payment_status` ya se comporten como en US1/US2 (mismo campo que lee),
  aunque no llama a sus endpoints directamente.
- **Polish (Phase 7)**: depende de que las 4 historias estén completas.

### Parallel Opportunities

- Dentro de Foundational: T005, T006, T007, T008, T009 son `[P]` (archivos distintos).
- Dentro de US1: T017, T018 son `[P]` (frontend, archivos distintos); pueden correr junto a
  T012-T016 (backend).
- Dentro de US2: T026, T027 son `[P]`.
- Dentro de US3: T033, T034 son `[P]`.
- Dentro de US4: T038 es `[P]`.
- Una vez cerrada Foundational, un equipo puede trabajar US1 y US2 en paralelo (ambas P1); US3
  y US4 pueden empezar en paralelo tan pronto el modelo de datos de Foundational está listo,
  aunque su validación de extremo a extremo (quickstart Escenarios 3 y 4) necesita que US1/US2
  ya existan para generar los datos de prueba (`'entregada'+'UNPAID'`, etc.).

---

## Parallel Example: Foundational

```bash
Task: "Actualizar ck_customer_order_status/ck_customer_order_payment_status/idx_active_order_per_participant en app/models/customer_order.py"
Task: "Actualizar ck_order_item_estado_cocina/EN_CURSO en app/models/order_item.py"
Task: "Actualizar enums de OrderStatus/KitchenStatus/PaymentStatus en app/api/v1/orders/schemas.py"
Task: "Agregar evento order_delivered en app/core/events.py"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Completar Phase 1 (Setup) y Phase 2 (Foundational — crítico, bloquea todo).
2. Completar Phase 3 (US1 — entregar con un clic).
3. **Detener y validar**: Escenario 1 de `quickstart.md` de forma independiente (sin pago
   separado ni liberación de mesa todavía).
4. Desplegar/demo si está listo (ya resuelve el dolor principal reportado).

### Incremental Delivery

1. Setup + Foundational → modelo de estados y migración listos.
2. + US1 → entrega de un clic → probar con Escenario 1 → demo (MVP).
3. + US2 → pago independiente y filtro "entregadas sin cobrar" → probar con Escenario 2 → demo.
4. + US3 → liberación manual de mesa → probar con Escenario 3 → demo.
5. + US4 → cancelación de entregados sin cobrar → probar con Escenario 4 → demo.
6. Polish → barrido de referencias viejas, scripts de desarrollo, suite completa, quickstart
   íntegro.

### Secuencia obligatoria por tipo de cambio (Principio VI)

Por indicación explícita de `plan.md`: la migración de datos (Phase 2, T004-T005), el cambio
de backend (Phases 2-6, tareas sin `[P]` de frontend) y el cambio de frontend (tareas que
tocan `../pos-heladeria`) son tres clases de cambio distintas y deben quedar en **commits
separados y verificables**, no mezclados — migración primero y aislada, backend después,
frontend al final, dentro de cada fase de historia.

## Notes

- `[P]` = archivos distintos, sin dependencia pendiente entre sí.
- `[US#]` traza cada tarea a su historia de usuario para verificar independencia.
- Ningún CHECK constraint certifica por sí solo SC-007 — por eso T005 agrega el `SELECT` de
  control explícito, no solo confía en que la migración no falle.
- Commit después de cada tarea o grupo lógico; detenerse en cada checkpoint para validar la
  historia de forma independiente antes de seguir con la siguiente.
