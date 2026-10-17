# Notas de implementación — Spec 123

## T002 — Línea base (2026-10-17)

- **Backend** (`../pos-backend`, rama `feat/123-adiciones-pago-complementario` desde `develop`):
  `./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'` →
  **1681 tests, OK** (0 fallos). Supera el último baseline documentado en memoria (1530,
  2026-10-15) — normal, otras specs aterrizaron desde entonces.
- **Frontend** (`../pos-heladeria`, misma rama): `npx ng test --watch=false` →
  **1962 passed, 11 failed, 1 skipped (1974 total)**, en 7 archivos — **fallos preexistentes, no
  relacionados con esta spec** (confirmado contra memoria `how-to-run-sibling-repo-tests`, que ya
  documentaba un baseline con fallos creciendo por "cross-file TestBed/DI state bleed"):
  - `src/app/app.spec.ts` (2)
  - `src/app/core/services/auth.service.spec.ts` (1)
  - `src/app/core/services/menu.service.spec.ts` (1)
  - `src/app/modules/super-admin/services/tenant.service.spec.ts` (3)
  - `src/app/modules/tables/components/pos-checkout-panel.component.spec.ts` (1)
  - `src/app/modules/tables/components/pos-order-panel.component.spec.ts` (2)
  - `src/app/modules/tables/services/pos-terminal.store.spec.ts` (1)

  Dos de esos archivos (`pos-order-panel.component.spec.ts`, `pos-terminal.store.spec.ts`) son
  justamente los que esta spec va a modificar — el criterio de éxito de Polish (T050) es que el
  conteo de fallos en esos archivos no **crezca** más allá de este baseline (no que baje a 0, que
  no es objetivo de esta spec).

## Resumen de la implementación (2026-10-17)

Las 6 historias de usuario quedaron implementadas y verificadas por tests automatizados
(backend + frontend). Las tareas marcadas `[ ]` en `tasks.md` son exclusivamente las de
**recorrido manual por navegador** (checkpoints T016/T022/T035/T039/T044/T048, y T051) — esta
sesión no tuvo acceso a un navegador/app corriendo, así que esas verificaciones quedan
pendientes para quien las ejecute contra la app real. Todo lo demás (migración, modelos,
endpoints, frontend, tests) está hecho.

### Backend (`../pos-backend`)

- **Migración** `fe71d444fb50_123_addition_tracking_and_sale_kind.py`: aplicada y verificada
  contra el esquema real `heladeria` (Postgres local) — `order_item_options` ganó
  `added_after_sale`/`complementary_sale_id`, `sales` ganó `kind`. `alembic upgrade head` sin
  errores; columnas confirmadas con una consulta directa a `information_schema.columns`.
- **Modelos**: `OrderItemOption`/`Sale` (`app/models/order_item.py`, `app/models/sale.py`).
- **`order_pending_balance`/`order_has_sale`** (`app/api/v1/orders/service.py`): el saldo
  pendiente es un valor calculado (join `OrderItemOption` + `OrderItem` + `Option`), nunca una
  columna — confirma el diseño de `data-model.md`/`research.md`.
- **`additions.py`** (nuevo): `add_addition_to_order_item` — agregar una adición a una línea
  existente, con todos los guardas (estado de línea, pedido cancelado, opción repetida, stock).
- **`consumption.py`** (+3 funciones nuevas): `plan_addition_consumption`/
  `check_addition_availability`/`deduct_addition` — ver "Hallazgo G1 profundizado" abajo.
- **`complementary.py`** (nuevo, en `sales/`): `settle_pending_balance` — cobro atómico del
  saldo pendiente, con lock de insumos en orden canónico antes de descontar ninguno.
- **`build_sale`** (`sales/builder.py`): + parámetro `kind`, default `'original'` — ningún
  llamador existente cambia de comportamiento.
- **`has_pending_balance`** (`table_sessions/service.py`) + guarda nueva en
  `release_paid_session`; `compute_bill` + campo `pending_balance` (**no** reusa
  `_billable_orders`: un pedido con saldo pendiente es justo uno de los que esa función ya
  excluye por tener `Sale`).
- **Gating por plan**: `has_module_access` nueva en `app/core/plan_limits.py` — **deviación de
  research.md**: no se envuelve `ensure_module_access` en `try/except HTTPException` (esa función
  también lanza 403 por plan vencido, que el `except` genérico confundiría con "sin módulo de
  inventario"). Ver sección de deviaciones.
- **`OrderResponse`/`OrderItemOptionResponse`**: + `pending_balance` y `added_after_sale`
  (campos aditivos, asignados en `_load_order`/ya presentes en el modelo) — el frontend los
  necesita para el saldo pendiente y el badge "Modificada".
- **Eventos** (`app/core/events.py`): `item_addon_added` nuevo, emitido desde el router de
  `additions.py`. `complementary.py` **no** lo reemite — ver deviación T046 abajo.
- **Tests nuevos**: `test_orders_additions.py` (15 tests), `test_sales_complementary_payment.py`
  (7 tests), + 3 tests nuevos en `test_table_sessions_service.py`. Total suite: **1706 OK**
  (1681 línea base + 25 nuevos), sin ningún test existente modificado.

### Frontend (`../pos-heladeria`)

- **`dining-session.service.ts`** (no `table-session.service.ts` como decía `tasks.md` original
  — corregido durante la implementación): `addAddition`/`settleComplementaryPayment`.
- **`pos-terminal.store.ts`**: señales `additionPickerItemId`/`additionPickerOptions` +
  `openAdditionPicker`/`closeAdditionPicker`/`confirmAddition`/`settlePendingBalance`; `variantId`
  y `modificada` agregados a la vista de línea persistida (`persistedItemsView`); listener
  `order.item_addon_added` en `connectRealtime()`.
- **`pos-order-panel.component.ts`**: botón "Agregar adición" (visible solo si `!it.ready &&
  !it.comboId`, disponible aunque el pedido esté pagado — a diferencia de "Anular"); badge
  "Modificada"; selector mínimo de opciones (**deviación de diseño**, ver abajo); texto de ayuda
  cuando la línea ya está lista.
- **`pos-checkout-panel.component.ts`**: bloque "Saldo pendiente" + `app-payment-input` reusado
  + botón "Cobrar saldo", condicionado a `+order.pending_balance > 0` (por pedido seleccionado,
  no por sesión agregada — ver deviación abajo).
- **`realtime-event.model.ts`**/`sse-client.ts`: tipo `ItemAddonAddedEvent` +
  `KNOWN_EVENT_TYPES` (sin esto el navegador descarta el evento en silencio).
- **Tests nuevos**: 5 tests en `pos-terminal.store.spec.ts` (selector, `confirmAddition`,
  `settlePendingBalance` con y sin turno abierto). `ng build` sin errores. Suite completa
  verificada **por archivo, en aislamiento** (ver nota de memoria actualizada sobre por qué
  el conteo de la suite completa no es confiable) — `pos-terminal.store.spec.ts` 209/210,
  `pos-order-panel.component.spec.ts` 42/44, `pos-checkout-panel.component.spec.ts` 42/43, los
  tres exactamente en la línea base (ningún fallo nuevo).

## Deviaciones respecto al plan/research/tasks originales

Todas son detalle de implementación (Principio XI) — ninguna cambia una decisión de negocio ya
tomada en `spec.md`.

1. **Gating por plan sin `try/except`** (ver arriba): `has_module_access` nueva, en vez del
   `ensure_module_access` envuelto que proponía `research.md` D4/D9 — evita confundir "plan
   vencido" con "sin módulo de inventario".
2. **`complementary.py` no reemite `item_addon_added`** (corrección ya aplicada a `tasks.md`
   T046 durante la implementación): cobrar el saldo no agrega ninguna adición nueva; reemitir
   ese evento sería semánticamente incorrecto. Emite `bill_changed` + `payment_completed`
   (reusado), igual que `pay_order`.
3. **Archivo de servicio frontend correcto**: `dining-session.service.ts`, no
   `table-session.service.ts` (ese archivo es `TableSessionService`, un servicio distinto para
   `/table-sessions`, no para `/orders`).
4. **Selector de "Agregar adición" mínimo, no `product-select.component.ts` reutilizado**: ese
   componente está diseñado para armar una línea nueva desde cero (con validación de
   min/max del grupo completo), no para "agregar una opción más a una línea ya persistida".
   Adaptarlo habría exigido reconstruir su `initialSelection` y diferenciar la adición nueva del
   resto por diff — más riesgo que valor. Se construyó un selector dedicado, pequeño, que lista
   las opciones de la variante (mismo catálogo cacheado, `store.catalogProducts()`) y deja que
   el backend valide todo (FR-008/FR-009) — consistente con que el backend sea la autoridad
   final.
5. **"Cobrar saldo" opera sobre el pedido seleccionado, no sobre el agregado de la sesión**: el
   endpoint de cobro complementario es por `order_id` (FR-010 habla de "el saldo pendiente de
   un pedido"). El bloque de UI usa `store.selectedOrder()?.pending_balance` (ya expuesto por
   `OrderResponse`) para el monto y la visibilidad, mientras que `sessionBill().pending_balance`
   (agregado de la sesión) sigue sirviendo solo para lo que pide `contracts/pending-balance-
   exposure.md`: el *dato* de cuenta de mesa. Si una mesa tuviera varios pedidos con saldo
   pendiente cada uno, el cajero cobra cada uno por separado seleccionando su pestaña — caso no
   cubierto explícitamente por ningún escenario de `spec.md`.
6. **`it.itemIds[0]`** para "Agregar adición" (igual que ya hace "Anular"): una línea de la
   vista agrupa varias filas reales `OrderItem` cuando comparten presentación+opciones+notas
   (spec 118) — no solo en combos. Se sigue el mismo criterio ya establecido por "Anular", en
   vez de inventar uno nuevo para esta acción.

## Pendiente para quien continúe

- Checkpoints manuales (T016, T022, T035, T039, T044, T048, T051): recorrer `quickstart.md`
  contra la app real corriendo en navegador — esta sesión no tuvo esa capacidad. La lógica de
  cada escenario ya está cubierta por los tests automatizados citados arriba.
- No se registró ninguna decisión en `registro-de-anomalias.md`: esta spec no reabre ningún
  comportamiento protegido (confirmado en el Constitution Check de `plan.md`).
- Ninguna rama se fusionó ni se hizo ningún commit (Principio XV: solo cuando el usuario lo
  pida). Ramas creadas: `feat/123-adiciones-pago-complementario` en `pos-backend` y
  `pos-heladeria`, ambas con cambios sin commitear.
