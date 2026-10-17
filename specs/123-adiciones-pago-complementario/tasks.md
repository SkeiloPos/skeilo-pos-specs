---

description: "Tareas de la spec 123 — adiciones a línea de pedido existente con pago complementario (US1–US6)"
---

# Tasks: Adiciones a Línea de Pedido Existente con Pago Complementario

**Input**: Documentos de diseño de `/specs/123-adiciones-pago-complementario/`
**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md) (D1–D9), [data-model.md](./data-model.md), [contracts/](./contracts/) (5 contratos), [quickstart.md](./quickstart.md)

**Tests**: el proyecto usa *characterization tests* (`app/characterization_tests/`, `python -m unittest`, sesiones SQLite en memoria vía `fixtures.py::new_session`) como árbitro de comportamiento (Principio III); `pos-heladeria` usa `ng test` (Vitest). Las tareas de prueba de backend van antes de la implementación de cada historia y deben fallar contra el código actual — el dominio es greenfield (confirmado en `research.md`: ningún test existente menciona `added_after_sale`/`kind='complementario'`/saldo pendiente).

**Organización**: las tareas se agrupan por historia de usuario en el orden de prioridad de `spec.md` (US1 P1 → US2 P1 → US3 P1 → US4 P2 → US5 P2 → US6 P3). Todas las rutas y nombres de función fueron verificados contra el código real de `pos-backend` y `pos-heladeria` (rama `develop`, árbol limpio) el 2026-10-17 — no contra una lectura de `plan.md`/`research.md` en abstracto (Principio III).

## Hallazgos de esta fase que corrigen `research.md`/`plan.md` (verificados contra el código; no reabren la fase de planeación — detalle de implementación, Principio XI)

1. **Ya existe `order_has_sale(db, order_id)` en `../pos-backend/app/api/v1/orders/service.py:93-103`** — su propio docstring dice que es "la señal correcta de 'ya está pagado'", precisamente porque `CustomerOrder.status` nunca llega a `"pagada"` en los caminos QR/mostrador vigentes. `research.md` D1/D2 no lo citaba y proponía un chequeo nuevo contra `Sale.status='paid'`; T010 reutiliza esta función existente en vez de duplicar lógica.
2. **Un pedido `"cancelada"` no anula el `estado_cocina` de sus ítems** (bugfix spec 050, ya documentado en el docstring de `release_paid_session`) — así que validar solo `item.estado_cocina in EN_CURSO` no basta para rechazar un pedido cancelado; T010 agrega una guarda explícita `order.status != "cancelada"` que ni `plan.md` ni `research.md` mencionaban.
3. **`add_item_to_order` (`consolidation.py:206-274`) rechaza `order.status in ("pagada", "cancelada")`** — ese patrón **no se copia** al nuevo endpoint de T010: permitir `"pagada"` es exactamente el objetivo de US2 (agregar adición a un pedido ya facturado); solo se bloquea `"cancelada"` (hallazgo 2).
4. **El flag `ready` que ya usa `pos-order-panel.component.ts` para ocultar "Marcar listo" se deriva de `rows.every(...)` sobre **varias** filas** (`pos-terminal.store.ts:1092,1127`, combos con más de un `OrderItem`) — el botón "Agregar adición" no puede asumir una correspondencia 1:1 con `it`; T015 debe resolver explícitamente sobre qué `item_id` hijo actúa cuando `it` agrega varias filas (research.md D8 ya lo señalaba como riesgo; aquí se confirma con evidencia concreta de código).
5. **(`/speckit-analyze`, posterior a la generación de tareas) `deduct_order_item`/`deduct_order_items` siempre incluyen la receta base de la variante** (`plan_line_consumption`, `app/catalog_engine/consumption.py:94-146`, línea con `source="receta"`) — llamarlas "acotadas a la nueva adición" (como describían las primeras versiones de T010/T030) habría re-descontado la receta base de la línea una segunda vez. Se agregó T010b (`deduct_addition`, filtra `source != "receta"`) y se corrigieron T010/T030 para usarla en vez de las funciones de descuento masivo existentes (research.md D9).

---

## Formato: `[ID] [P?] [Story] Descripción`

- **[P]**: puede ejecutarse en paralelo (archivo distinto, sin dependencia de una tarea sin terminar)
- **[Story]**: a qué historia de usuario pertenece (US1–US6)
- Cada tarea incluye la ruta exacta del archivo, relativa a `../pos-backend`, `../pos-heladeria` o `pos-specs` (esta carpeta) según corresponda

## Convenciones de ruta

- `../pos-backend/app/...` — API FastAPI + SQLAlchemy (Python 3.14). Tests: `python -m unittest discover -s app/characterization_tests -p 'test_*.py'` desde `../pos-backend`.
- `../pos-heladeria/src/app/...` — SPA Angular 21 (TypeScript); `npx ng test --watch=false`. Abreviatura: `tables/` = `../pos-heladeria/src/app/modules/tables/`.
- Sin prefijo — archivo dentro de este repo (`pos-specs`).

## Nota sobre gobernanza y ramas

- **Sin registro en `registro-de-anomalias.md`**: esta spec no reabre ningún comportamiento protegido (Principio II) — es enteramente capacidad nueva (Principio IV); `plan.md` ya lo concluye en su Constitution Check.
- **Rama (Principio XIV)**: una sola rama por repo, `feat/123-adiciones-pago-complementario`, desde `develop` en `../pos-backend` **y** `../pos-heladeria` (ambos confirmados limpios en `develop` el 2026-10-17).
- **Migración Alembic**: encadenar desde la cabeza actual (`e0faa21295a3_121_denomination_breakdown.py` era la más reciente el 2026-10-17 — confirmar con `alembic heads` al ejecutar T003, puede haber cambiado).
- **Commits**: solo cuando el usuario lo pida (Principio XV); pequeños por unidad (migración + modelos; endpoint de agregar adición; endpoint de cobro complementario; bloqueo de Liberar Mesa; evento de tiempo real; frontend), en inglés, Conventional Commits, sin marca de IA.

---

## Phase 1: Setup

- [X] T001 Crear la rama `feat/123-adiciones-pago-complementario` desde `develop` en `../pos-backend` y en `../pos-heladeria` (ambos en `develop`, árbol limpio — verificar con `git status`)
- [X] T002 Línea base: correr las suites completas de ambos repos **sin cambios** (`python -m unittest discover -s app/characterization_tests -p 'test_*.py'` en `../pos-backend`; `npx ng test --watch=false` en `../pos-heladeria`) y crear `specs/123-adiciones-pago-complementario/implementation-notes.md` con el número de tests y el resultado de cada suite

**Checkpoint**: rama creada en ambos repos, línea base verde documentada.

---

## Phase 2: Foundational (modelo de datos y cómputo de saldo pendiente; bloquea las 6 historias)

**⚠️ CRITICAL**: ninguna historia puede completarse sin esta fase.

- [X] T003 Migración Alembic nueva en `../pos-backend/alembic/versions/` (encadenar desde la cabeza actual, ver nota de gobernanza): `ALTER TABLE order_item_options ADD COLUMN added_after_sale boolean NOT NULL DEFAULT false, ADD COLUMN complementary_sale_id uuid NULL REFERENCES sales(id)`; `ALTER TABLE sales ADD COLUMN kind varchar(20) NOT NULL DEFAULT 'original' CONSTRAINT ck_sales_kind CHECK (kind IN ('original','complementario'))` (data-model.md). `downgrade()` en orden inverso con `DROP CONSTRAINT`/`DROP COLUMN`
- [X] T004 [P] En `../pos-backend/app/models/order_item.py::OrderItemOption` (L104-134): agregar `added_after_sale: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="false")` y `complementary_sale_id: Mapped[Optional[UUID]] = mapped_column(ForeignKey("sales.id"), nullable=True)` (data-model.md §1)
- [X] T005 [P] En `../pos-backend/app/models/sale.py::Sale` (L17-128): agregar `kind: Mapped[str] = mapped_column(String(20), nullable=False, server_default="original")` + `CheckConstraint("kind IN ('original', 'complementario')", name="ck_sale_kind")` en `__table_args__` (data-model.md §2)
- [X] T006 En `../pos-backend/app/api/v1/orders/service.py`: nueva función `order_pending_balance(db: Session, order_id: UUID) -> Decimal`, hermana de `order_has_sale` (L93-103) — suma `Option.extra_price × oio.quantity` (confirmado contra `app/models/option.py`, `/speckit-analyze` I1) sobre `OrderItemOption` con `added_after_sale=True AND complementary_sale_id IS NULL`, unido a `OrderItem` por `order_item_id` y a `Option` por `option_id`, filtrado por `OrderItem.order_id == order_id AND OrderItem.estado_cocina != 'anulado'` (data-model.md §1, edge case de línea anulada)
- [X] T007 Checkpoint Foundational: aplicar la migración sobre un esquema de tenant de prueba (`alembic upgrade head`) y confirmar que la suite completa de `../pos-backend` sigue en verde (ninguna fila existente cambia de valor)

**Checkpoint**: modelo de datos y primitivo de saldo pendiente listos; ningún endpoint todavía los usa.

---

## Phase 3: User Story 1 — Agregar adición a una línea de un pedido aún no pagado (Priority: P1) 🎯 MVP

**Goal**: nuevo endpoint que agrega una opción a un `OrderItem` ya persistido; para un pedido sin `Sale` emitida, el total se recalcula de inmediato (FR-001, FR-004, FR-005, FR-019).

**Independent Test**: agregar una adición a una línea "Pendiente" de un pedido sin cobrar y verificar que el total de la línea y del pedido se recalculan de inmediato; cobrar después y confirmar que el monto exigido ya incluye la adición (spec.md, Historia 1).

### Tests para User Story 1 (escribir primero; deben fallar contra el código actual) ⚠️

- [X] T008 [P] [US1] Nuevo archivo `../pos-backend/app/characterization_tests/test_orders_additions.py`: agregar una opción válida a un `OrderItem` "pendiente" de un pedido **sin** `Sale` (`order_has_sale` false) vía la función de T010; confirmar `item.addons_total`/`item.line_total` recalculados correctamente, `added_after_sale=False`, `order_pending_balance(db, order.id) == 0`, que no se crea ninguna `Sale`, **y que el insumo de la adición se descuenta de inmediato del inventario sin descontar de nuevo la receta base de la variante** (`/speckit-analyze` G1/research.md D9: verificar el `current_stock` del insumo de la receta antes/después — no debe cambiar por esta operación, solo el insumo propio de la adición). Tercer caso (`/speckit-analyze` G2): agregar una adición "Por cantidad" a una línea de cantidad de producto 2 y confirmar que el total solo incluye 1× la adición (no 2×); agregar una adición "Conteo" y confirmar que sí se multiplica por la cantidad de producto (FR-004, regresión de spec 117 sobre este nuevo call-site)
- [X] T009 [P] [US1] Mismo archivo: rechazo 409 cuando `item.estado_cocina == 'anulado'`; rechazo 409 cuando `order.status == 'cancelada'` aunque el ítem siga `'pendiente'` (hallazgo 2); en ambos casos, ninguna fila cambia ni se descuenta inventario

### Implementación de User Story 1 — backend

- [X] T010 [US1] Nuevo módulo `../pos-backend/app/api/v1/orders/additions.py`, función `add_addition_to_order_item(db: Session, item_id: UUID, data, user: User) -> OrderItem`: carga el `OrderItem` y su `CustomerOrder` (`get_or_404`, patrón de `consolidation.py`); valida `order.status != "cancelada"` → 409 (hallazgo 2); valida `item.estado_cocina in OrderItem.EN_CURSO` → 409 "Producto ya preparado: agrega un producto nuevo" (FR-002/003); valida la opción vía `load_valid_options`/`mark_per_line` reutilizados sin cambio de firma; si el tenant tiene el módulo de inventario (`ensure_module_access` envuelto en `try/except HTTPException`, FR-008), valida stock vía `check_availability` acotado a `source != "receta"` (FR-009, research.md D9); inserta `OrderItemOption(order_item_id=item.id, option_id=chosen.option.id, quantity=chosen.quantity, per_line=chosen.per_line, added_after_sale=order_has_sale(db, order.id))` (hallazgo 1); **si `added_after_sale=False` (pedido sin pagar) y el tenant tiene módulo de inventario, descuenta de inmediato vía `deduct_addition` (T010b) — nunca `deduct_order_item`/`deduct_order_items`, que re-descontarían la receta base de la línea (`/speckit-analyze` G1, FR-005, research.md D9)**; recalcula `item.addons_total` sumando el nuevo monto; commit. Depende de T004, T006, T010b
- [X] T010b [P] [US1] En `../pos-backend/app/api/v1/orders/consumption.py`: nueva función `deduct_addition(db: Session, order_item: OrderItem, chosen_option: ChosenOption, user_id: UUID | None, reference_id: UUID) -> None` — llama `plan_line_consumption(db, order_item.product_variant_id, order_item.quantity, [chosen_option])` y descarta toda línea con `source == "receta"` antes de aplicar `record_movement(..., type="out", reason=reasons.VENTA, reference_type=reasons.REF_ORDER, ...)` (research.md D9). Usada por T010 (caso sin pagar) y T030 (cobro complementario) — ninguno de los dos llama a las funciones de descuento masivo existentes
- [X] T011 [US1] Schemas nuevos en `../pos-backend/app/api/v1/orders/schemas.py`: `AddAdditionIn` (`option_id: UUID`, `quantity: Decimal`); extender la respuesta existente de ítem con `pending_balance: Decimal` (0 si no aplica)
- [X] T012 [US1] Router: `POST /orders/items/{item_id}/additions` en `../pos-backend/app/api/v1/orders/router.py`, invoca T010 (contracts/add-addition-to-order-item.md). Hace pasar T008/T009

### Implementación de User Story 1 — frontend

- [X] T013 [P] [US1] En `tables/services/table-session.service.ts` (o el servicio de órdenes vigente): nuevo método `addAddition(itemId, optionId, quantity)` que llama al endpoint de T012
- [X] T014 [US1] En `tables/services/pos-terminal.store.ts`: nueva acción `addAddition(itemId, optionId, quantity)` (mismo patrón que `avanzarItem`/`voidPersistedItem`) que llama a T013 y refresca el pedido. Depende de T013
- [X] T015 [US1] En `tables/components/pos-order-panel.component.ts` (bloque `it.kind === 'persisted'`, L282-324): agregar botón "Agregar adición" junto a "Marcar listo"/"Anular", que abre el selector de opciones existente (`product-select.component.ts`, en modo "agregar a línea existente") y llama `store.addAddition(...)` (T014). **Resolver explícitamente sobre qué `item_id` hijo actúa cuando `it` agrega varias filas** (hallazgo 4) — si `it` representa un combo, el botón debe operar sobre la fila concreta, no sobre el agregado. Depende de T014
- [X] T015b [US1] En `tables/components/pos-order-panel.component.ts`: mostrar un badge "Modificada" en la línea persistida que tenga al menos una `OrderItemOption` con `added_after_sale=true` o agregada después de la creación inicial de la línea, distinto del badge de `estado_cocina` ya existente (`/speckit-analyze` G3; FR-017, Historia 6). Depende de T015
- [ ] T016 [US1] Checkpoint: suite backend + `ng test` en verde; recorrido manual del Escenario 1 de `quickstart.md`

**Checkpoint**: US1 completa y verificable por sí sola (pedido sin pagar).

---

## Phase 4: User Story 2 — Agregar adición a una línea de un pedido ya pagado genera saldo pendiente (Priority: P1)

**Goal**: la misma acción de US1, cuando el pedido ya tiene una `Sale` (`order_has_sale`), no toca la factura original y genera saldo pendiente visible (FR-006, FR-007, FR-015).

**Independent Test**: agregar una adición a una línea "Pendiente" de un pedido ya pagado y verificar que la factura original no cambia de monto, que aparece un saldo pendiente igual al valor de la adición, y que aparece la acción para cobrarlo (spec.md, Historia 2).

**Dependencias**: depende de US1 (mismo endpoint, mismo módulo `additions.py`).

### Tests para User Story 2 ⚠️

- [X] T017 [P] [US2] En `test_orders_additions.py`: agregar una opción a un `OrderItem` "pendiente" de un pedido **con** `Sale` existente (`order_has_sale=True`); confirmar que la `Sale` original no cambia ningún campo (snapshot antes/después, FR-007), `added_after_sale=True`, `complementary_sale_id IS NULL`, y `order_pending_balance(db, order.id)` refleja exactamente el valor de la adición
- [X] T018 [P] [US2] Test de `order_pending_balance` (T006) con varias adiciones sobre distintas líneas del mismo pedido → suma correcta; con una línea anulada que tenía una adición pendiente → esa porción se excluye del saldo (edge case de la spec)

### Implementación de User Story 2

- [X] T019 [US2] Extender `../pos-backend/app/api/v1/table_sessions/service.py::compute_bill` (L187+) con `pending_balance: Decimal` en `SessionBillResponse`, sumando `order_pending_balance` (T006) de todas las órdenes de la sesión — campo aditivo (contracts/pending-balance-exposure.md). Depende de T006
- [X] T020 [P] [US2] Frontend: en `tables/services/table-session.service.ts` e interfaces (`dining.interface.ts`), exponer `pending_balance` de la respuesta de T019. Depende de T019
- [X] T021 [US2] Frontend: en `tables/components/pos-checkout-panel.component.ts` (bloque post-cobro, L378-421), agregar el bloque "Saldo pendiente: $X" visible cuando `pending_balance > 0`, con el botón "Cobrar saldo" visible (su manejador se conecta en US3, T034). Depende de T020
- [ ] T022 [US2] Checkpoint: recorrido manual del Escenario 2 de `quickstart.md` (factura original intacta, saldo pendiente visible)

**Checkpoint**: US1 y US2 funcionan de forma independiente.

---

## Phase 5: User Story 3 — Cobrar el saldo pendiente como pago complementario (Priority: P1)

**Goal**: endpoint de cobro complementario — atómico, gated por plan, pago único, genera `Sale`/factura independiente, ciclos repetibles (FR-010 a FR-014, FR-018, FR-020 a FR-022).

**Independent Test**: cobrar en efectivo el saldo pendiente de un pedido y verificar que se genera una factura independiente, que el insumo de la adición se descuenta del inventario, y que el pedido vuelve a reflejarse como completamente pagado (spec.md, Historia 3).

**Dependencias**: depende de T010/T010b (US1) y T006 (Foundational) — no de toda la Historia 2; el
backend de esta historia puede empezar en cuanto T010 pueda producir `added_after_sale=True`
(ejercitado por T017 de US2), en paralelo con el frontend de US2 (T019-T022) (`/speckit-analyze`
I2).

### Tests para User Story 3 (escribir primero; deben fallar contra el código actual) ⚠️

- [X] T023 [P] [US3] Nuevo archivo `../pos-backend/app/characterization_tests/test_sales_complementary_payment.py`: cobro exitoso de un saldo pendiente de una sola adición → nueva `Sale` con `kind='complementario'` y el mismo `customer_order_id` que la original, `complementary_sale_id` fijado en la `OrderItemOption` cubierta, inventario descontado **solo del insumo de la adición, sin descontar de nuevo la receta base de la línea** (`/speckit-analyze` G1/research.md D9), `order_pending_balance` vuelve a `0`, y `reconcile(shift)` incluye el pago de la nueva `Sale` complementaria (`/speckit-analyze` G4, FR-013)
- [X] T024 [P] [US3] Mismo archivo: `len(payments) > 1` → 422 (FR-018); monto distinto al saldo pendiente exacto → 422; saldo pendiente `== 0` → 409 "No hay saldo pendiente por cobrar"
- [X] T025 [P] [US3] Mismo archivo: stock insuficiente de **una** de dos adiciones cubiertas (tenant **con** módulo de inventario) → rechazo atómico completo — ninguna `Sale` generada, ningún insumo descontado (ni el que sí tenía stock), saldo pendiente intacto (FR-020)
- [X] T026 [P] [US3] Mismo archivo: mismo escenario de T025 en un tenant **sin** módulo de inventario habilitado → el cobro se completa sin ningún chequeo ni descuento de stock (FR-021)
- [X] T027 [P] [US3] Mismo archivo: dos ciclos sucesivos de saldo pendiente + cobro sobre el mismo pedido → dos `Sale` `kind='complementario'` independientes, ninguna modifica a la otra ni a la original (FR-022)
- [X] T028 [P] [US3] Nuevo caso en `../pos-backend/app/characterization_tests/test_plan_module_access.py` (patrón existente de esa clase): el cobro complementario respeta `ensure_module_access` igual que otros puntos ya gateados por el módulo de inventario

### Implementación de User Story 3

- [X] T029 [US3] Extender `../pos-backend/app/api/v1/sales/builder.py::build_sale` (L120-247): nuevo parámetro `kind: str = "original"`, propagado al `Sale(...)` construido — el default preserva sin cambios a todos los llamadores existentes (`pay_order`, `checkout_and_send`, caminos QR)
- [X] T030 [US3] Nuevo módulo `../pos-backend/app/api/v1/sales/complementary.py`, función `settle_pending_balance(db, order_id, data, cashier) -> Sale`: implementa en una sola transacción la secuencia de `contracts/complementary-payment.md` — recalcular saldo pendiente (T006, 409 si es 0); validar `len(payments) == 1` y monto exacto (422, FR-018); `ensure_open_shift` (reusado sin cambios); si el tenant tiene módulo de inventario, `check_availability` atómico sobre **todos** los insumos de las adiciones pendientes, acotado a `source != "receta"` (409 si falta cualquiera, FR-020) y luego **una llamada a `deduct_addition` (T010b) por cada `OrderItemOption` pendiente cubierta — nunca `deduct_order_items`/`deduct_order_items_naming_product`, que re-descontarían la receta base de cada línea** (`/speckit-analyze` G1, research.md D9); `build_sale(..., kind='complementario', customer_order_id=order_id, payments=data.payments)` (T029); marcar `complementary_sale_id` en cada `OrderItemOption` cubierta; commit. Depende de T006, T029, T010b
- [X] T031 [US3] Schema nuevo `ComplementaryPaymentIn` (`payments: list[PaymentIn]`, reutilizando `PaymentIn` existente) en `orders/schemas.py` o `sales/schemas.py`
- [X] T032 [US3] Router: `POST /orders/{order_id}/complementary-payment`, invoca T030. Hace pasar T023-T027
- [X] T033 [P] [US3] Frontend: en `tables/services/table-session.service.ts`, método `settlePendingBalance(orderId, payment)` que llama al endpoint de T032
- [X] T034 [US3] Frontend: conectar el botón "Cobrar saldo" (T021) a `store.settlePendingBalance(...)` (T033), reutilizando el componente de selección de método de pago ya existente del cobro normal. Depende de T021, T033
- [ ] T035 [US3] Checkpoint: suite backend + `ng test`; recorrido manual de los Escenarios 3 y 4 de `quickstart.md` (cobro exitoso, ciclo repetido, rechazo atómico con y sin módulo de inventario)

**Checkpoint**: las tres historias P1 (US1, US2, US3) funcionan de punta a punta.

---

## Phase 6: User Story 4 — Restricciones de estado de línea y validación de stock al agregar una adición (Priority: P2)

**Goal**: completar la UX de los guards ya funcionales desde US1 (bloqueo por estado, stock insuficiente al agregar) con texto de ayuda visible y tests dedicados que citen el mensaje literal (FR-002, FR-003, FR-008, FR-009).

**Independent Test**: intentar agregar una adición a una línea "Listo" y verificar que la acción no está disponible; intentar agregar una adición sin stock suficiente y verificar el rechazo sin cambios en la línea ni en el total (spec.md, Historia 4).

**Dependencias**: depende de US1 (los guards ya existen en T010; esta fase los documenta con tests dedicados y completa su UX).

### Tests para User Story 4 ⚠️

- [X] T036 [P] [US4] En `test_orders_additions.py`: test dedicado que agrega una opción a una línea `'listo'` → 409 con el mensaje exacto "Producto ya preparado: agrega un producto nuevo" (FR-003)
- [X] T037 [P] [US4] En `test_orders_additions.py`: test dedicado de stock insuficiente al agregar (tenant con módulo de inventario) → 409 "Stock insuficiente de [insumo]", línea y total sin cambios; caso contrario sin módulo de inventario → no se valida ni rechaza por stock

### Implementación de User Story 4

- [X] T038 [US4] En `tables/components/pos-order-panel.component.ts` (botón de T015): condicionar visibilidad/estado deshabilitado de "Agregar adición" al mismo criterio que ya oculta "Marcar listo" (`!it.ready`, verificado en el hallazgo 4) y mostrar el texto de ayuda "Producto ya preparado: agrega un producto nuevo" cuando no esté disponible
- [ ] T039 [US4] Checkpoint: recorrido manual del Escenario 5 de `quickstart.md`

**Checkpoint**: las cuatro primeras historias (US1-US4) completas y verificables.

---

## Phase 7: User Story 5 — Bloqueo de "Liberar Mesa" mientras exista saldo pendiente (Priority: P2)

**Goal**: nueva guarda en el único endpoint de "Liberar Mesa" cableado al frontend (FR-016).

**Independent Test**: generar un saldo pendiente en un pedido de mesa e intentar liberar esa mesa, verificando el bloqueo; cobrar el saldo y repetir, verificando que ya libera (spec.md, Historia 5).

**Dependencias**: depende de US2/US3 (necesita que el saldo pendiente exista y se pueda cobrar para probar ambos lados del bloqueo).

### Tests para User Story 5 ⚠️

- [X] T040 [P] [US5] Nuevo test en `../pos-backend/app/characterization_tests/test_table_sessions_service.py`: `has_pending_balance` (T042) devuelve `true`/`false` según exista saldo pendiente en alguna orden de la sesión
- [X] T041 [P] [US5] Mismo archivo: `release_paid_session` rechaza con 409 "Hay un saldo pendiente por cobrar" cuando hay saldo pendiente, y libera normalmente una vez cobrado íntegramente (reutilizando el flujo de US3) — verificar explícitamente que `test_release_paid_session_409_si_queda_algo_por_cobrar` (caso distinto, `has_billable_orders`) sigue en verde sin modificarse

### Implementación de User Story 5

- [X] T042 [US5] En `../pos-backend/app/api/v1/table_sessions/service.py`: nueva función `has_pending_balance(db: Session, table_session_id: UUID) -> bool`, hermana de `has_billable_orders` (L65-85) — suma `order_pending_balance` (T006) de las órdenes con `status != "cancelada"` de la sesión y devuelve si el total es `> 0`. Depende de T006
- [X] T043 [US5] En `release_paid_session` (L379+): agregar la guarda de T042 inmediatamente después del chequeo existente de `has_billable_orders` (L410-414), mismo formato de 409 (contracts/release-table-pending-balance-gate.md). Hace pasar T040/T041. Depende de T042
- [ ] T044 [US5] Checkpoint: recorrido manual del Escenario 6 de `quickstart.md`

**Checkpoint**: cinco historias completas (US1-US5).

---

## Phase 8: User Story 6 — Cocina ve en tiempo real que la línea cambió (Priority: P3)

**Goal**: nuevo evento sobre el despachador ya existente de la spec 077 (FR-017).

**Independent Test**: agregar una adición desde una sesión de Terminal POS y verificar, en otra sesión conectada, que la línea aparece marcada como modificada con la adición, sin recargar manualmente (spec.md, Historia 6).

**Dependencias**: depende de US1 y US3 (los dos puntos de emisión).

- [X] T045 [P] [US6] Nuevo evento en `../pos-backend/app/core/events.py`: `item_addon_added(tenant_id: int, *, order_id, table_session_id, item_id, option_name, quantity) -> str | None`, mismo molde que `item_kitchen_changed` (L196-211) — canales `CH_STAFF` + `session_channel(table_session_id)` si aplica (contracts/realtime-item-addon-added-event.md)
- [X] T046 [US6] Emitir `events.item_addon_added(...)` **después del commit**, desde el router (`orders/router.py::add_addition`), tras llamar `additions.add_addition_to_order_item` (T010) — **corrección de implementación**: `complementary.py` (T030) emite `events.bill_changed` + `events.payment_completed` (reusa el existente, mismo patrón que `pay_order`), **no** `item_addon_added` — pagar el saldo no agrega ninguna adición nueva, así que reemitir ese evento sería semánticamente incorrecto (ninguna línea "cambió por una adición" en ese momento, solo se cobró lo que ya existía). Depende de T010, T030, T045
- [X] T047 [US6] Frontend: en `tables/services/pos-terminal.store.ts::connectRealtime()` (L1434-1461), agregar `this.realtime.on('order.item_addon_added', () => this.scheduleReload())` (mismo patrón que `item_kitchen_changed`/`item_voided`). La recarga por sí sola no materializa "la cocina ve la línea marcada como Modificada" — ese badge es T015b; esta tarea solo dispara el refresco que trae los datos que T015b ya sabe pintar (`/speckit-analyze` G3). Depende de T045, T015b
- [ ] T048 [US6] Checkpoint: recorrido manual del Escenario 7 de `quickstart.md` (dos sesiones de navegador)

**Checkpoint**: las seis historias completas.

---

## Phase 9: Polish & Cross-Cutting Concerns

- [X] T049 Suite completa de `../pos-backend` en verde y comparada con la línea base de T002 (solo suben los tests nuevos)
- [X] T050 Suite completa de `../pos-heladeria` (`ng test` + `ng build` sin errores de tipos) comparada con la línea base de T002
- [ ] T051 Recorrido completo de `quickstart.md` (los 7 escenarios) y verificación de SC-001 a SC-009; documentar resultado en `implementation-notes.md`
- [X] T052 Completar `specs/123-adiciones-pago-complementario/implementation-notes.md`: decisiones tomadas, los 5 hallazgos de corrección listados al inicio de este archivo (con su resolución), y cualquier desviación respecto al plan
- [X] T053 Verificación de trazabilidad (Principio XII): `git status` en `pos-specs`, `../pos-backend` y `../pos-heladeria` — **no commitear** salvo que el usuario lo pida (Principio XV)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias.
- **Foundational (Phase 2)**: depende del Setup; bloquea las 6 historias (modelo de datos y `order_pending_balance`).
- **US1 (Phase 3)**: depende de Foundational. Es el MVP.
- **US2 (Phase 4)**: depende de US1 (mismo endpoint/módulo).
- **US3 (Phase 5)**: depende de T010/T010b (US1) y T006 (Foundational), no de toda US2 (`/speckit-analyze` I2).
- **US4 (Phase 6)**: depende de US1 (los guards ya existen; esta fase los documenta/completa su UX).
- **US5 (Phase 7)**: depende de US2/US3 (necesita saldo pendiente generable y cobrable para probar ambos lados).
- **US6 (Phase 8)**: depende de US1 y US3 (los dos puntos de emisión del evento).
- **Polish (Phase 9)**: depende de las seis historias.

### Parallel Opportunities

- Setup: T001 y T002 son secuenciales (T002 corre sobre las ramas creadas en T001).
- Foundational: T004 y T005 en paralelo (archivos distintos); T006 depende de ambas (usa `OrderItemOption` y conceptualmente `Sale`, aunque no la toca directamente).
- US1: tests T008-T009 en paralelo; T010b en paralelo con T004/T005 (archivo distinto, sin depender de ellos); frontend T013 en paralelo con el backend T010-T012 (contrato ya definido en `contracts/`), T014 depende de T013, T015 depende de T014, T015b depende de T015.
- US2: tests T017-T018 en paralelo; T020 depende de T019; T021 depende de T020.
- US3: tests T023-T028 todos en paralelo (mismo archivo nuevo o `test_plan_module_access.py`, pero sin dependencias entre sí); T033 en paralelo con el backend T029-T032; T034 depende de T021 y T033.
- US4: T036-T037 en paralelo.
- US5: T040-T041 en paralelo.
- US6: T045 puede ir en paralelo con cualquier cosa de US1-US5 que no sea T010/T030 (los puntos de emisión); T047 depende de T045 y T015b.

---

## Parallel Example: Foundational + User Story 1

```bash
# Foundational (archivos distintos):
Task: "models/order_item.py::OrderItemOption: + added_after_sale, complementary_sale_id"
Task: "models/sale.py::Sale: + kind"

# Tests de backend de US1 (mismo archivo nuevo, pero independientes entre sí):
Task: "test_orders_additions.py: agregar adición a pedido sin Sale, recalcula normal"
Task: "test_orders_additions.py: rechazo por estado anulado / orden cancelada"

# Frontend de US1 en paralelo con el backend (contrato ya fijado en contracts/):
Task: "table-session.service.ts: addAddition(itemId, optionId, quantity)"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Completar Phase 1: Setup
2. Completar Phase 2: Foundational (CRÍTICO)
3. Completar Phase 3: User Story 1
4. **DETENER y VALIDAR**: probar User Story 1 de forma independiente (quickstart §1)
5. Desplegar/demo si está listo — ya permite agregar adiciones a pedidos sin pagar, sin anular ni recrear el producto

### Incremental Delivery

1. Setup + Foundational → base lista
2. US1 → probar independientemente → demo (capacidad básica)
3. US2 → probar independientemente → demo (saldo pendiente visible)
4. US3 → probar independientemente → demo (cobro complementario — cierra el ciclo de negocio central)
5. US4 → probar independientemente → demo (UX de restricciones)
6. US5 → probar independientemente → demo (bloqueo de Liberar Mesa)
7. US6 → probar independientemente → demo (tiempo real)

### Parallel Team Strategy

Con dos personas: una completa Setup + Foundational + US1 + US2 + US3 en secuencia (mismo dominio OrderItem/Sale); otra, tras el checkpoint de US1, se encarga de US4 (UX de guards) y luego, tras US2/US3, de US5 (Liberar Mesa); US6 (la más pequeña) la hace quien quede libre primero, una vez existan T010 y T030.

---

## Notes

- **[P]** tareas = archivos distintos, sin dependencias entre ellas
- **[Story]** mapea cada tarea a su historia de usuario para trazabilidad
- Verificar que los tests fallan antes de implementar
- Commits solo cuando el usuario lo pida (Principio XV)
- Detenerse en cada checkpoint para validar la historia de forma independiente
- Los 5 hallazgos de esta fase (ver encabezado; el quinto proviene de `/speckit-analyze`) corrigen `research.md`/`plan.md` contra el código real — no reabren la fase de planeación (Principio XI), pero `implementation-notes.md` (T052) debe dejarlos documentados
