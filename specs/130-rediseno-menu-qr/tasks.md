---

description: "Task list for spec 130 — Rediseño visual del Menú QR, pago mixto y bloqueo de salida"
---

# Tasks: Rediseño visual del Menú QR con pago mixto y bloqueo de salida con pago pendiente

**Input**: Design documents from `/specs/130-rediseno-menu-qr/`
**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/pago-mixto-comensal.md](./contracts/pago-mixto-comensal.md), [contracts/bloqueo-salida.md](./contracts/bloqueo-salida.md), [quickstart.md](./quickstart.md)

**Tests**: no se piden tests TDD-first explícitos en la spec, pero `plan.md` (§Testing) exige
characterization tests nuevos por cada punto de FR-004 a FR-012 y correr la batería existente
antes/después sin regresiones (Principio III/X). Se incluyen como tareas dentro de cada historia,
después de la implementación (no TDD estricto).

**Repos**: `pos-backend` (FastAPI/SQLAlchemy, Python) y `pos-heladeria` (Angular, TypeScript) —
rutas de abajo son relativas a cada uno según se indica.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: se puede ejecutar en paralelo (archivo distinto, sin dependencia de una tarea sin terminar)
- **[Story]**: US1 (Historia 1, rediseño visual), US2 (Historia 2, pago mixto), US3 (Historia 3,
  bloqueo de salida), US4 (Historia 4, toppings excluidos del rediseño)

---

## Phase 1: Setup

**Propósito**: fijar la línea base antes de tocar código (Principio III/X) — ninguna dependencia
nueva que instalar (Principio IX, confirmado en plan.md).

- [X] T001 Confirmar línea base backend en verde: `cd pos-backend && ./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'` — guardar el resultado para comparar al final (Phase Polish) — **Resultado: 1835 tests, OK (0 fallos)**
- [X] T002 [P] Confirmar línea base frontend: `cd pos-heladeria && npx ng test --watch=false --include='src/app/modules/tables/**/*.spec.ts'` — comparar contra la lista de fallos preexistentes ya documentada en la memoria del proyecto, no asumir que todo en rojo es nuevo — **Resultado: 925 tests, 4 fallos preexistentes (pos-order-panel.component.spec.ts x2, pos-terminal.store.spec.ts x2 vía 1 test) / 921 OK — coincide con línea base documentada en memoria**

---

## Phase 2: Foundational (Blocking Prerequisites)

**Nota**: esta spec no tiene infraestructura bloqueante compartida entre **todas** las historias
— el rediseño visual (US1) no toca backend, el pago mixto (US2) y el bloqueo de salida (US3) tocan
partes disjuntas del backend, y los toppings (US4) no cambian nada. Cada prerrequisito real
(migraciones de US2, entrada de gobernanza de US3) vive dentro de la fase de su propia historia
para no bloquear a las demás sin necesidad. No hay tareas en esta fase.

---

## Phase 3: User Story 1 - Rediseño visual sin cambio de comportamiento (Priority: P1) 🎯 MVP

**Goal**: aplicar la apariencia de `design/Bienvenida QR v1.dc.html` a las ocho pantallas del Menú
QR, in situ sobre los componentes existentes (research.md Decisión 1), sin alterar ningún
comportamiento subyacente.

**Independent Test**: recorrer bienvenida → menú → detalle de producto → carrito → "Mis pedidos" →
revisión/pago → confirmación → despedida; verificar que precios, promociones, validaciones de
grupos de opciones y recuperación de progreso tras recarga son idénticos a los vigentes hoy.

### Implementation for User Story 1

- [X] T003 [US1] Restylar la pantalla de bienvenida (formulario de nombre) en `pos-heladeria/src/app/modules/tables/pages/public-menu.component.ts` (vista `'name'`, líneas ~151-202) para igualar el diseño de referencia, sin tocar la lógica de `confirmName()`
- [X] T004 [US1] Restylar la barra superior, el banner de promociones, las pestañas de categoría y la barra de búsqueda en `public-menu.component.ts` (vista `'menu'`, líneas ~204-311), sin alterar `promotionAnnouncements`, el filtrado por categoría ni la búsqueda
- [X] T005 [US1] Restylar las tarjetas de pedido de la pestaña "Mis pedidos" en `public-menu.component.ts` (líneas ~317-342+) sin cambiar la información ni el estado mostrados
- [X] T006 [US1] Restylar la navegación inferior (Inicio/Mis pedidos/Carrito/Salir, `public-menu.component.ts` líneas ~596-639) manteniendo la llamada a `confirmExit()` tal cual (el diálogo de bloqueo en sí es alcance de US3)
- [X] T007 [US1] Restylar la pantalla de despedida (`view()==='closed'`, líneas ~132-149) y la pantalla de acceso expirado (`view()==='exited'`, líneas ~112-130) en `public-menu.component.ts` para igualar el estado de despedida del diseño de referencia, sin tocar `expireSession()`
- [X] T008 [P] [US1] Restylar el carrito en `pos-heladeria/src/app/modules/tables/components/cart.component.ts`, preservando intactas las mutaciones de ítems (agregar/actualizar/quitar)
- [X] T009 [P] [US1] Restylar el selector de presentación (`role="radiogroup"`) en `pos-heladeria/src/app/modules/tables/components/product-select.component.ts` (líneas ~152-230), sin tocar el checklist de toppings de las líneas ~311-334 (excluido, ver US4) ni su lógica de selección
- [X] T010 [P] [US1] Restylar `pos-heladeria/src/app/modules/tables/pages/checkout/review-step.component.ts` para igualar el "Paso 1" del diseño de referencia, sin alterar la navegación de "Salir sin enviar" ni el resumen embebido
- [X] T011 [P] [US1] Restylar `checkout-order-summary.component.ts` y `checkout-step-indicator.component.ts` (mismo directorio `pages/checkout/`) para igualar el resumen de pedido y el indicador "Paso X de Y" del diseño de referencia
- [X] T012 [P] [US1] Restylar el contenido no relacionado con pago mixto de `pages/checkout/confirmation-step.component.ts` para igualar la confirmación del diseño de referencia (el desglose de pago mixto se agrega en US2, T038)
- [X] T013 [US1] Mapear los íconos Lucide de `design/Bienvenida QR v1.dc.html` al set de íconos interno ya usado por los pasos de checkout (research.md Decisión 9), en todos los componentes restylados en T003-T012, sin introducir una librería nueva
- [ ] T014 [US1] Verificación manual: ejecutar el Escenario 1 de `quickstart.md` de punta a punta (bienvenida → menú → detalle con presentación y grupo obligatorio → carrito → "Mis pedidos", más recarga a mitad de revisión/pago) y confirmar que ningún resultado documentado en specs 007/004/025/032/034/128 cambió

**Checkpoint**: las ocho pantallas usan la apariencia nueva; ningún comportamiento vigente cambió.

---

## Phase 4: User Story 2 - Pago mixto para el comensal (Priority: P1)

**Goal**: permitir "Pago mixto" (efectivo + transferencia) como método de pago del comensal,
habilitable por el tenant en su catálogo (spec 032) solo si ya tiene efectivo y transferencia
activos.

**Independent Test**: en "¿Cómo vas a pagar?", elegir "Pago mixto", ingresar un monto en efectivo
menor al total, verificar el cálculo del resto, la exigencia de comprobante solo por ese resto, y
que el pedido queda registrado con el desglose de ambos montos.

### Implementation for User Story 2 — Backend

- [X] T015 [US2] Migración Alembic: ampliar el `CHECK` de `type` en `shared.payment_method_catalog` para incluir `'mixed'` (nueva fila en `pos-backend/alembic/versions/`, DROP/ADD del constraint existente)
- [X] T016 [US2] Actualizar el `CheckConstraint` de `type` en `pos-backend/app/models/payment_method_catalog.py` (líneas ~29-33) para incluir `'mixed'`, igual que T015
- [X] T017 [P] [US2] Migración Alembic `@for_each_tenant_schema` (plantilla: `pos-backend/alembic/versions/2d50957395dc_product_availability_audit_columns.py`) que agrega a `tenant.order_payment_attempts` las columnas nullable `cash_amount` (`Numeric(12,2)`), `transfer_amount` (`Numeric(12,2)`), `transfer_method_id` (UUID, FK a `payment_methods.id`), `cash_confirmed_at` (`DateTime`), con guardas de idempotencia y sin backfill
- [X] T018 [US2] Agregar las cuatro columnas de T017 al modelo `pos-backend/app/models/order_payment_attempt.py` (después de `receipt_file_url`, ~línea 45), con `foreign_keys=` explícito en la relación `transfer_method` para distinguirla de `payment_method_id` (ya es FK al mismo `payment_methods`)
- [X] T019 [US2] Extender `SubmitCartIn` en `pos-backend/app/api/v1/cart/schemas.py` (líneas ~225-229) con `cash_amount: Decimal | None` y `transfer_method_id: UUID | None`, ambos opcionales
- [X] T020 [P] [US2] Validación FR-004 en `create_payment_method` (`pos-backend/app/api/v1/sales/service.py`, líneas ~149-196): si `catalog.type == 'mixed'`, rechazar con `409` salvo que el tenant ya tenga activo al menos un `PaymentMethod` `type='cash'` y uno `type='transfer'`, con mensaje citando ambos requisitos
- [X] T021 [US2] Extender el bloque de validación de pago de `submit_cart()` (`pos-backend/app/api/v1/cart/service.py`, líneas ~836-854) con una rama para `method.type == 'mixed'`: `422` si `cash_amount` es `null`/`<=0`/`>=` total (mensaje orientando a "Efectivo", FR-006); resolver `transfer_method_id` automáticamente si el tenant tiene exactamente un método de transferencia activo, exigirlo si tiene más de uno (FR-005); calcular `transfer_amount = total - cash_amount`; exigir `receipt_file_url` para esa porción (FR-007); persistir los cuatro campos en el `OrderPaymentAttempt` creado
- [X] T022 [US2] Extender `confirm_cash_payment_attempt` (`pos-backend/app/api/v1/orders/checkout.py`, líneas ~1369-1460): si `attempt.cash_amount is not None`, fijar `cash_confirmed_at=now()` en vez de `status`, y solo invocar `_confirm_order_impl` cuando `status` ya es `'confirmado'`; comportamiento no mixto sin cambios
- [X] T023 [US2] Extender `approve_payment_attempt` (`pos-backend/app/api/v1/orders/checkout.py`, líneas ~1196-1311): si el intento es mixto, seguir fijando `status='confirmado'`, pero solo invocar `_confirm_order_impl` cuando `cash_confirmed_at` ya tiene valor; comportamiento no mixto sin cambios
- [X] T024 [US2] Extender la condición de "pago confirmado" del gate en `_confirm_order_impl` (`pos-backend/app/api/v1/orders/checkout.py`, ~líneas 631-672): para un intento con `cash_amount IS NOT NULL` exigir `status='confirmado' AND cash_confirmed_at IS NOT NULL`; para `cash_amount IS NULL` mantener solo `status='confirmado'`
- [X] T025 [P] [US2] Extender `PaymentAttemptResponse` (`pos-backend/app/api/v1/orders/schemas.py`, líneas ~367-386) con `cash_amount`, `transfer_amount`, `transfer_method_id`, `cash_confirmed_at` (FR-008)
- [X] T026 [P] [US2] Extender `DinerPaymentMethod` (`pos-backend/app/api/v1/cart/schemas.py`, líneas ~156-187) y `list_payment_methods` (`pos-backend/app/api/v1/cart/service.py`, líneas ~1092-1101) para exponer cómo distinguir "Pago mixto" en el frontend (ninguna de las dos banderas binarias actuales basta — exponer el `type` del catálogo o una bandera `is_mixed`)
- [X] T027 [US2] Tests backend en `pos-backend/app/characterization_tests/test_cart_payment_attempts.py` (o `test_cart_service.py`): límites de `cash_amount` (0, negativo, igual/mayor al total con mensaje de orientación), resolución automática con un único método de transferencia activo, exigencia de `transfer_method_id` con más de uno, desglose persistido correctamente
- [X] T028 [US2] Tests backend en `pos-backend/app/characterization_tests/test_orders_payment_gate.py`: la orden solo avanza a cocina cuando `status='confirmado'` y `cash_confirmed_at` tienen ambos valor, en cualquier orden de confirmación, para un intento mixto
- [X] T029 [US2] Tests backend en `pos-backend/app/characterization_tests/test_sales_payment_methods_catalog.py` (o archivo equivalente de spec 032 que resulte más cercano a `create_payment_method`): activar `'mixed'` sin efectivo/transferencia activos se rechaza; con ambos activos, se acepta

### Implementation for User Story 2 — Frontend

- [X] T030 [US2] Mostrar "Pago mixto" como opción distinguible en el listado de métodos de `pos-heladeria/src/app/modules/tables/pages/checkout/payment-method-step.component.ts` (líneas ~42-59), usando el nuevo campo de T026 en vez de solo `is_cash`
- [X] T031 [US2] Extender `choose(method)` en `payment-method-step.component.ts` (líneas ~96-136) para que elegir "Pago mixto" navegue a un nuevo paso de monto en efectivo, en vez de enviar directo (como efectivo) o ir a `transfer-details` (como transferencia pura)
- [X] T032 [US2] Extender `CheckoutProgressRecord` en `pos-heladeria/src/app/modules/tables/pages/checkout/checkout-progress.store.ts` (líneas ~9-14) con `cash_amount: number | null` y `transfer_method_id: string | null`, y un valor de `step` para el nuevo paso de monto en efectivo
- [X] T033 [US2] Construir el paso de monto en efectivo (componente nuevo o ampliación del flujo de `payment-method-step`) con cálculo en vivo del resto a transferir y validación FR-006 (bloquea con monto `<= 0` o `>=` total orientando a "Efectivo"; un monto de `0` se trata como elegir "Transferencia")
- [X] T034 [US2] Agregar la selección de método de transferencia dentro del flujo mixto cuando el tenant tenga más de un método activo (reusar el patrón de selección ya usado para transferencia pura)
- [X] T035 [US2] Extender `transfer-details-step.component.ts` para mostrar la etiqueta "+ {monto} en efectivo al recibir el pedido" y los datos de cuenta/QR del `transfer_method_id` elegido cuando el flujo es mixto (FR-007)
- [X] T036 [US2] En `checkout-progress.store.ts`, borrar `receipt_file_url` del registro guardado cada vez que se escribe un `cash_amount` distinto del ya guardado (Decisión 6, Clarificación Q6)
- [X] T037 [US2] Extender `submitCart()` en `pos-heladeria/src/app/modules/tables/services/diner.service.ts` (líneas ~267-273) para enviar `cash_amount`/`transfer_method_id` cuando el pago es mixto
- [X] T038 [US2] Extender `confirmation-step.component.ts` para mostrar el desglose de pago mixto (efectivo pendiente al recibir + transferencia en verificación), completando el restyle de T012
- [X] T039 [US2] Mostrar el mismo desglose de pago mixto en las tarjetas de pedido de la pestaña "Mis pedidos" (`public-menu.component.ts`, mismo bloque de T005) (FR-008)
- [X] T040 [US2] Tests frontend nuevos (`pages/checkout/*.spec.ts`) para el paso de monto en efectivo, la selección de método de transferencia forzada/automática, y la invalidación del comprobante al cambiar el monto — comparar contra la baseline de fallos preexistentes (T002)
- [ ] T041 [US2] Verificación manual: ejecutar los Escenarios 2 y 3 de `quickstart.md` de punta a punta, incluyendo la confirmación en dos partes desde backend/Terminal (`confirm-cash` + `approve`, en cualquier orden)

**Checkpoint**: un comensal puede completar un pago mixto de punta a punta; la orden solo avanza a
cocina con ambas confirmaciones.

---

## Phase 5: User Story 3 - Bloqueo de salida con pago pendiente (Priority: P1)

**Goal**: impedir que un comensal cierre su sesión mientras tenga un pedido propio con pago no
confirmado.

**Independent Test**: enviar un pedido en efectivo (o transferencia sin comprobante verificado) y,
sin confirmar el pago, pulsar "Salir"; verificar que el sistema lo bloquea y la sesión sigue activa.

### Governance gate (Principio II — obligatorio antes de tocar `leave_session`)

- [X] T042 [US3] Agregar la entrada **A-139** en `pos-specs/specs/000-reconocimiento/registro-de-anomalias.md` (formato de A-130/A-131): "[DECISIÓN DE NEGOCIO — spec 130] `POST /cart/leave` deja de ser infalible: bloquea la salida con pago pendiente" — citando qué cambia (`leave_session` ya no es "nunca falla"), por qué (pedido explícito del negocio, `spec.md` Historia 3), quién y cuándo (clarificaciones Q1/Q2 de la sesión 2026-10-20 de `spec.md`), qué se ve afectado (`leave_session`, `POST /cart/leave`, el botón "Salir" del Menú QR), y el tratamiento acordado (`spec.md`, `research.md` Decisión 7, `contracts/bloqueo-salida.md`)

### Implementation for User Story 3 — Backend

- [X] T043 [US3] Agregar `PendingPaymentExit(HTTPException)` en `pos-backend/app/core/exceptions.py` (mismo patrón que `InsufficientStockError`: `status_code=409`, `detail={"error": "pago_pendiente", "message": "Tienes un pago pendiente. Para salir, dirígete a la caja. Si no deseas llevar tu pedido, indícalo allí."}`) — depende de T042
- [X] T044 [US3] Agregar en `leave_session` (`pos-backend/app/api/v1/cart/service.py`, líneas ~720-733), antes de `close_participant`, la validación FR-009: lanzar `PendingPaymentExit` si el participante tiene al menos un `CustomerOrder` propio no cancelado cuyo intento de pago vigente no está completamente confirmado (`status != 'confirmado'`, o intento mixto con `cash_confirmed_at IS NULL`) — query exacta en `contracts/bloqueo-salida.md`; evaluar solo pedidos del participante que invoca (Clarificación Q2)
- [X] T045 [US3] Corregir `leave()` (`pos-backend/app/api/v1/cart/router.py`, líneas ~116-131): hoy un `except HTTPException: pass` genérico envolvería y silenciaría también `PendingPaymentExit` (que hereda de `HTTPException`) — capturar `PendingPaymentExit` primero y dejarla propagar como `409`, conservando el `except HTTPException: pass` solo para errores de token
- [X] T046 [US3] Tests backend en `pos-backend/app/characterization_tests/test_cart_service.py` y/o `test_table_sessions_router.py`: pedido propio en efectivo sin cobrar bloquea (`PendingPaymentExit`, participante sigue `open`); pedido propio por transferencia sin comprobante verificado bloquea; pedido propio mixto con solo una de las dos confirmaciones bloquea; pedido propio completamente confirmado permite salir; sin pedidos propios permite salir; pedido pendiente de **otro** comensal de la misma mesa no bloquea (Clarificación Q2)
- [X] T047 [US3] Test backend en `pos-backend/app/characterization_tests/test_cart_router.py`: `POST /cart/leave` responde `409` (no se traga el error) para un participante con un pedido propio pendiente, y la sesión del participante sigue activa después del intento

### Implementation for User Story 3 — Frontend

- [X] T048 [P] [US3] Reemplazar el `confirm()` nativo del navegador en `confirmExit()`/`exit()` (`pos-heladeria/src/app/modules/tables/pages/public-menu.component.ts`, líneas ~1227-1232 y ~1437-1449): primero revisar los pedidos ya cargados de "Mis pedidos" por si alguno propio no cancelado tiene pago pendiente (si lo hay, mostrar el diálogo de bloqueo sin llamar al backend); si no, llamar `api.leave()` y mostrar el mismo diálogo si la respuesta es `409`, en vez de tragarse el error en silencio
- [X] T049 [US3] Extender `leave()` en `pos-heladeria/src/app/modules/tables/services/diner.service.ts` (líneas ~296-302) para distinguir un `409` (pago pendiente) de otros errores de red, en vez de tragarse toda la llamada POST sin distinción
- [X] T050 [US3] Agregar el diálogo de bloqueo (título "Tienes un pago pendiente.", cuerpo fijo del mensaje del `409`, único botón "Entendido", sin reintento ni bypass) equivalente al estado `exitBlock` del diseño de referencia
- [X] T051 [US3] Tests frontend nuevos en el spec de `public-menu.component.ts`: la revisión client-side bloquea sin llamar al backend cuando ya hay datos de un pedido propio pendiente; el camino `409` muestra el mismo diálogo; un error de red simple sigue permitiendo la salida best-effort como hoy
- [ ] T052 [US3] Verificación manual: ejecutar el Escenario 4 de `quickstart.md` de punta a punta, incluyendo el caso de dos comensales en la misma mesa (Ana/Luis, Clarificación Q2) y confirmando que la liberación de mesa de `RN-CART-15` sigue sin cambios (FR-012)

**Checkpoint**: 0% de los intentos de "Salir" con pago pendiente propio logran cerrar la sesión;
100% sin pedidos pendientes la cierran con normalidad.

---

## Phase 6: User Story 4 - Toppings fuera del rediseño visual (Priority: P3)

**Goal**: confirmar que ni la apariencia ni el comportamiento del control de toppings/adiciones
cambian en ningún lugar donde se muestran.

**Independent Test**: comparar antes/después que las mismas combinaciones de selección producen
las mismas validaciones, precios y resultados, y que el control y su listado se ven exactamente
igual.

### Implementation for User Story 4

- [X] T053 [P] [US4] Verificar que el checklist de toppings en `pos-heladeria/src/app/modules/tables/components/product-select.component.ts` (líneas ~311-334) conserva exactamente su apariencia actual tras el restyle de T009 del resto de la hoja de producto, y que `toggleOption()` (líneas ~998-1015) no se modificó
- [X] T054 [P] [US4] Verificar que `pos-heladeria/src/app/modules/tables/components/cart-item-options.component.ts` (archivo completo, líneas 26-54) conserva su apariencia exacta en carrito/revisión/"Mis pedidos" tras los restyles de T005/T008/T010
- [ ] T055 [US4] Verificación manual: ejecutar el Escenario 5 de `quickstart.md` — intentar continuar sin cumplir un grupo obligatorio sigue bloqueando con el mismo mensaje; la lista de toppings elegidos se ve y contiene exactamente lo mismo que antes del rediseño

**Checkpoint**: 0% de las interacciones con toppings producen un resultado distinto al de antes del
rediseño.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Propósito**: cerrar la verificación exigida por Principio III/X y dejar trazabilidad de los
tests tocados.

- [X] T056 [P] Volver a correr la batería backend completa (`./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`) y confirmar cero regresiones no autorizadas contra la línea base de T001
- [X] T057 [P] Volver a correr la batería frontend (`npx ng test --watch=false --include='src/app/modules/tables/**/*.spec.ts'`) y comparar contra la línea base de T002
- [X] T058 Ejecutar la sección "Verificación automatizada" completa de `quickstart.md` y registrar el resultado
- [X] T059 Revisar que ningún test `"CONGELA comportamiento actual:"` sobre `leave_session`/`POST /cart/leave`, `_confirm_order_impl`, `confirm_cash_payment_attempt` o `approve_payment_attempt` quedó describiendo el comportamiento anterior sin citar la spec 130 (Principio III)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias — arranca de inmediato.
- **Foundational (Phase 2)**: vacía para esta spec (ver nota arriba) — no bloquea nada.
- **User Stories (Phase 3-6)**: pueden arrancar en paralelo entre sí tras Setup — no comparten
  archivos de implementación entre historias (US1 es solo CSS/plantilla sobre componentes que US2
  y US3 también tocan, pero en bloques distintos — ver Nota de conflicto abajo).
- **Polish (Phase 7)**: depende de que las historias que se vayan a entregar ya estén completas.

### Nota de conflicto de archivos entre historias

`public-menu.component.ts` lo tocan **US1** (T003-T007, restyle), **US2** (T039, desglose en "Mis
pedidos") y **US3** (T048, reemplazo de `confirmExit()`/`exit()`) — en bloques de líneas distintos,
pero si se trabajan en paralelo por personas distintas, coordinar el orden de merge (recomendado:
US1 primero, como base visual, luego US2/US3 sobre ella). `checkout-progress.store.ts` lo tocan
**US2** (T032, T036) de forma secuencial entre sí, sin conflicto con otras historias.

### Dependencias dentro de User Story 2 (backend)

T015/T016 (CHECK del catálogo) y T017/T018 (columnas de `order_payment_attempts`) son
independientes entre sí. T019 depende de T018. T021 depende de T018 y T019. T022/T023/T024
dependen de T018 (necesitan las columnas nuevas en el modelo) y conviene hacerlas juntas (mismo
archivo `checkout.py`, gate compartido). T020, T025, T026 son independientes del resto (`[P]`).
T027-T029 (tests) van después de su implementación correspondiente. En frontend, T030→T031→T033
son secuenciales (mismo flujo); T032 puede ir en paralelo con T030/T031; T035-T037 dependen de
T033/T034.

### Dependencias dentro de User Story 3

T042 (entrada de gobernanza) **bloquea** T043-T047 — no se toca `leave_session` sin esa entrada
(Principio II). T043→T044→T045 son secuenciales (misma cadena de excepción). T046/T047 (tests) van
después de T044/T045. En frontend, T048 y T049 son independientes entre sí pero ambos dependen
conceptualmente de que el backend (T044/T045) ya devuelva el `409` para poder probarse de punta a
punta (T051).

### Parallel Opportunities

- T001/T002 (Setup) en paralelo.
- Dentro de US1: T008-T012 son `[P]` entre sí (archivos distintos sin dependencia).
- Dentro de US2 backend: T017, T020, T025, T026 son `[P]` entre sí y respecto al resto.
- Dentro de US3 frontend: T048 es `[P]` respecto a T049 (archivos distintos).
- Dentro de US4: T053 y T054 son `[P]` entre sí.
- T056/T057 (Polish) en paralelo.
- Las historias US1, US2, US3, US4 se pueden repartir entre personas distintas una vez pasado Setup
  (ver Nota de conflicto de archivos arriba para el único punto de coordinación real).

---

## Parallel Example: User Story 1

```bash
Task: "Restylar cart.component.ts (T008)"
Task: "Restylar product-select.component.ts, radiogroup de presentación (T009)"
Task: "Restylar review-step.component.ts (T010)"
Task: "Restylar checkout-order-summary.component.ts y checkout-step-indicator.component.ts (T011)"
Task: "Restylar confirmation-step.component.ts, contenido no-mixto (T012)"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Completar Phase 1 (Setup) — confirmar líneas base.
2. Completar Phase 3 (US1) — las ocho pantallas con la apariencia nueva, cero cambio de
   comportamiento.
3. **Parar y validar**: Escenario 1 de `quickstart.md` por separado.
4. Desplegar/demostrar si está listo — ya es un incremento de valor visible por sí solo.

### Incremental Delivery

1. Setup → línea base registrada.
2. US1 (rediseño visual) → validar → demo (MVP).
3. US3 (bloqueo de salida) → requiere primero T042 (gobernanza) → validar → demo. Puede ir antes
   que US2 porque no depende de ella.
4. US2 (pago mixto) → el bloque más grande (migraciones + gate de cajero + flujo nuevo de
   checkout) → validar → demo.
5. US4 (toppings) → verificación, sin cambios reales — se puede hacer en cualquier momento después
   de US1, incluso en paralelo.
6. Polish → regresión completa + auditoría de characterization tests.

### Parallel Team Strategy

Con varias personas, tras Setup:

- Persona A: US1 (rediseño visual, principalmente frontend).
- Persona B: US3 backend (empieza por T042, gobernanza) + frontend del diálogo de bloqueo.
- Persona C: US2 backend (migraciones, modelo, gate de cajero).
- Persona D: US2 frontend (nuevo paso de monto en efectivo), una vez que C publique los cambios de
  `SubmitCartIn`/`DinerPaymentMethod` (T019/T026).
- US4 lo puede absorber quien termine primero, como verificación final antes de Polish.

---

## Notes

- `[P]` = archivos distintos, sin dependencia pendiente.
- `[Story]` mapea cada tarea a su historia para trazabilidad.
- Ninguna tarea de rediseño visual (US1/US4) debe tocar lógica de negocio — si al restylar se
  encuentra que el diseño de referencia no cubre algo vigente hoy, seguir la instrucción original
  de la spec: preguntar antes de decidir, no improvisar.
- T042 (registro de anomalías) es la única tarea de **gobernanza pura** de esta lista — bloquea
  toda la Phase 5 y no tiene archivo de código asociado.
- Verificar que los tests fallan/pasan según corresponda antes de dar por completada cada
  historia; commitear por tarea o grupo lógico (solo si el usuario lo pide explícitamente,
  Principio XV).
