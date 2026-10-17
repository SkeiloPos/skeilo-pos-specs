# Investigación — Spec 123

**Fecha**: 2026-10-17 · **Spec**: [spec.md](./spec.md)

Toda decisión de esta fase se contrastó contra el código real de `pos-backend` y `pos-heladeria`
(ambos en su rama activa, árbol limpio), no contra una lectura de specs anteriores en abstracto.
Confirmado por grep exhaustivo: **ningún repositorio tiene hoy nada de "saldo pendiente",
"complementario/a", "pending_balance" ni relación padre-hijo entre `Sale`** — el dominio completo
de esta spec es nuevo; no hay nada que recablear (a diferencia de la spec 117).

## D1 — Agregar una adición a un `OrderItem` ya persistido

**Hallazgo clave**: no existe hoy ningún camino que module un `OrderItem` ya creado para
agregarle una opción. `cart/service.py::add_item`/`update_item` operan sobre `CartItem`
(pre-pedido). `orders/consolidation.py::add_item_to_order` (`app/api/v1/orders/consolidation.py`,
L206-274) siempre inserta un `OrderItem` **nuevo**, con `estado_cocina="pendiente"` — nunca toca
una fila existente. `kitchen.py::void_item` con reemplazo (L150-161) también crea una fila nueva
(`void_de=item.id`), nunca modifica la anulada.

**Decisión**: nuevo endpoint `POST /orders/items/{item_id}/additions` (módulo nuevo
`app/api/v1/orders/additions.py`, función `add_addition_to_order_item(db, item_id, data, user)`)
que:
1. Carga el `OrderItem`, valida `estado_cocina in OrderItem.EN_CURSO` (reutiliza la constante ya
   definida en `app/models/order_item.py:15`) — si no, 409 con el mensaje de FR-003.
2. Valida la opción (`option_id`) contra el mismo motor de reglas que ya usa `add_item_to_order`
   (grupo al que pertenece, `min_select`/`max_select`, spec 065) — **sin duplicar lógica**, se
   reutiliza `load_valid_options`/`validate_option_selection`
   (`app/catalog_engine/pricing.py`).
3. Inserta una fila `OrderItemOption` nueva sobre el `item_id` existente (no sobre el carrito), con
   `per_line` igual al `selection_mode` del grupo (regla ya vigente desde spec 089/117, sin
   cambios) y las dos columnas nuevas de D2.
4. No recalcula nada manualmente: `OrderItem.line_total` (`app/models/order_item.py`, property
   L87-91) ya suma `unit_price × quantity + addons_total` — al refrescar `addons_total` (mismo
   patrón que usa `add_item_to_order` tras insertar opciones) el total de la línea queda correcto
   sin tocar el motor de pricing.

**Por qué no reutilizar `add_item_to_order`**: esa función siempre crea una fila `OrderItem` nueva
con `estado_cocina="pendiente"`; forzarla a aceptar "agregar sobre una fila existente" le haría dos
responsabilidades distintas con reglas de validación distintas (línea nueva vs. línea existente con
restricción de estado). Un módulo nuevo y pequeño es más simple que ramificar una función que ya
tiene 4 llamadores distintos (spec 117, research D1).

## D2 — Distinguir una adición post-hoc sin tocar ninguna fila histórica

**Problema**: el sistema necesita saber, por cada `OrderItemOption`, (a) si nació después de que el
pedido ya tenía una `Sale` emitida, y (b) si ya fue cubierta por un pago (complementario). Ninguna
columna existente lo expresa.

**Decisión**: dos columnas nuevas en `order_item_options` (ver `data-model.md` para la migración):
- `added_after_sale: bool NOT NULL DEFAULT false` — `true` únicamente si, en el momento de
  insertarla, el `CustomerOrder` ya tenía al menos una `Sale` con `status='paid'`. Nunca se
  recalcula después; es un hecho histórico de cuándo se agregó.
- `complementary_sale_id: UUID NULL REFERENCES sales(id)` — se llena exactamente una vez, al
  cobrarse con éxito el pago complementario que la cubre (D4). Antes de eso, permanece `NULL`.

**"Saldo pendiente del pedido" es un valor calculado, no una columna**: `SUM(precio_adición ×
cantidad)` sobre las filas `OrderItemOption` del pedido donde `added_after_sale = true AND
complementary_sale_id IS NULL`, excluyendo las de líneas con `estado_cocina = 'anulado'` (edge case
de la spec: anular la línea retira su porción del saldo). Mismo patrón arquitectónico que
`has_billable_orders` (`table_sessions/service.py`, L65-85) — tampoco persiste nada, se deriva de
las filas vigentes en cada consulta. Evita una columna contadora que podría desincronizarse de las
filas reales tras una anulación.

**Alternativa descartada**: agregar un campo `Sale.pending_balance` persistido y actualizarlo en
cada operación. Se descarta porque introduciría una segunda fuente de verdad que podría
desincronizarse (ej. si se anula una línea con adición pendiente sin pasar por el mismo código
que actualiza el contador) — el cómputo on-the-fly es la misma estrategia que ya usa el sistema
para "¿hay algo por cobrar en esta mesa?".

## D3 — Factura complementaria: extender `Sale`, no crear una entidad nueva

**Hallazgo clave**: `Sale` (`app/models/sale.py`, L17-128) ya tiene `customer_order_id` (FK a
`customer_orders.id`, L40-42) como "gancho para la facturación por order". **No existe
`parent_sale_id` ni ninguna relación entre `Sale`s** — confirmado por lectura directa del modelo.
`build_sale` (`app/api/v1/sales/builder.py`, L120-247) ya arma `Sale`+`SaleItem`+`Payment`+factura
(`issue_for_sale`, L244-246) en una sola función, sin tocar inventario (se deduce aparte).

**Decisión**: agregar `Sale.kind: str NOT NULL DEFAULT 'original' CHECK (kind IN ('original',
'complementario'))` (ver `data-model.md`). La factura complementaria es simplemente una `Sale` más
con `kind='complementario'` y el mismo `customer_order_id` que la original — reutiliza
`build_sale` tal cual, pasándole un nuevo parámetro `kind` (default `'original'`, así ningún
llamador existente —`pay_order`, `checkout_and_send`, los caminos QR— cambia de comportamiento sin
tocarlos). `Sale.status` sigue su ciclo normal (`issued`→`paid`); no se necesita un estado nuevo.

**Por qué no una entidad `ComplementaryPayment` separada**: duplicaría toda la maquinaria que
`Sale`/`Payment`/`issue_for_sale` ya resuelve (numeración de factura, relación con método de pago,
reportes de turno vía `reconcile`, que agrupa por `Sale.cash_shift_id` sin importar su `kind`). Una
columna de discriminación sobre la misma tabla es el cambio mínimo que preserva FR-011
(factura independiente) y deja los reportes existentes funcionando sin tocarlos (verificado contra
`test_cash_shift_sales_report.py`).

**Invariante de aplicación (no de base de datos)**: toda `Sale` con `kind='complementario'` DEBE
tener `customer_order_id IS NOT NULL` — se valida en `settle_pending_balance` (D4), no con un CHECK
de SQL que acoplaría dos columnas (consistente con cómo `order_has_sale` ya resuelve relaciones
similares a nivel de aplicación, no de esquema).

## D4 — Cobro complementario: atómico, con gating por plan, pago único

**Decisión**: nuevo endpoint `POST /orders/{order_id}/complementary-payment` (módulo nuevo
`app/api/v1/sales/complementary.py`, función `settle_pending_balance(db, order_id, data, cashier)`)
que, en una sola transacción:

1. Recalcula el saldo pendiente vigente (D2) — si es cero, 409 "No hay saldo pendiente por cobrar".
2. Valida `len(data.payments) == 1` → 422/409 si no (FR-018). **Esto es una validación nueva**: el
   esquema `PaymentIn`/`PayIn.payments` (`app/api/v1/orders/schemas.py`, L401/L422) permite hoy
   hasta 3 pagos sin que ningún guard de backend fuerce uno solo — la regla "un único método" (spec
   046) es hoy solo convención de frontend (`pos-terminal.store.ts::checkoutAndSend`, construye un
   array de un elemento). Esta spec no endurece `pay_order`/`checkout_and_send` (Principio V: no es
   el problema que ataca); solo el endpoint nuevo exige explícitamente un único pago.
3. Si el tenant tiene el módulo de inventario (`ensure_module_access(db, tenant, "inventario")`,
   `app/core/plan_limits.py`, L126-144, envuelto en `try/except HTTPException` — el patrón que la
   propia función documenta para "un endpoint que debe seguir funcionando para tenants sin el
   módulo", L126-133): valida stock de cada insumo de las adiciones pendientes vía
   `check_availability` (`app/catalog_engine/pricing.py`, L298-319). Si falta cualquiera, 409
   "Stock insuficiente de [insumo]" y la transacción se aborta completa — ninguna fila cambia
   (FR-020). Si el tenant no tiene el módulo, se omite este paso y el siguiente (FR-021).
4. Si el chequeo pasó (o no aplicaba), descuenta inventario con **una llamada a `deduct_addition`
   (D9) por cada `OrderItemOption` pendiente identificada en el paso 1** — nunca
   `deduct_order_items`/`deduct_order_items_naming_product`, que recalculan la receta base de la
   variante (`source="receta"`) además del consumo de la opción: llamarlas aquí re-descontaría esa
   receta base una segunda vez, porque el producto base y sus opciones originales ya se descontaron
   cuando se creó/consolidó el `OrderItem` (detectado en `/speckit-analyze`, ver D9).
5. Llama `build_sale(..., kind='complementario', customer_order_id=order.id)` (D3). El movimiento
   de caja no requiere código adicional: `reconcile` (`app/api/v1/cash/service.py`) ya agrupa por
   `Sale.cash_shift_id` sin importar `kind`, así que la nueva `Sale` aparece automáticamente en el
   turno abierto (`ensure_open_shift`, `sales/builder.py` L88-92, ya exige turno abierto — si no
   hay, 404/409 igual que cualquier otro cobro, sin necesidad de un chequeo nuevo).
6. Marca cada `OrderItemOption` cubierta con `complementary_sale_id = nueva_sale.id`.
7. Emite `events.item_addon_added(...)` (D7) y el evento ya existente `bill_changed` (mismo patrón
   que usa `void_item` router, L401-417) **después del commit**.

**Por qué todo en una sola transacción de base de datos (sin tabla de "intentos")**: el paso 3
(chequeo de stock) y el paso 4 (descuento vía `deduct_addition`, D9) ya usan `lock_items` con
locks en orden canónico (spec 003) para cada insumo. Envolver los pasos 1-6 en la misma transacción
de SQLAlchemy que abre el endpoint basta para que un fallo en cualquier paso haga rollback completo
— no se necesita infraestructura de compensación ni una tabla de staging.

## D5 — Bloqueo de "Liberar Mesa"

**Hallazgo clave**: hay **dos** endpoints de liberar mesa, pero el frontend solo usa uno.
`release_paid_session` (`app/api/v1/table_sessions/service.py`, L379+, expuesto en
`POST /table-sessions/{id}/release`) es el que llama
`pos-terminal.store.ts::releaseTable()` → `table-session.service.ts::release()`. Ya tiene, en
orden, `ts.status != "active"` (409), `has_billable_orders` (409 "Todavía hay algo por cobrar"),
`_assert_closable` (ítems en curso en cocina). El segundo, `checkout.release_table`
(`app/api/v1/orders/checkout.py`, L1088-1135, `POST /tables/{table_id}/release`), es más estricto
pero **no está cableado en ningún punto del frontend actual** (grep confirmado).

**Decisión**: agregar `has_pending_balance(db, table_session_id)` como función hermana de
`has_billable_orders`, en el mismo archivo, con la misma forma (recorre las órdenes de la sesión,
suma el saldo pendiente de D2 de cada una). Se invoca dentro de `release_paid_session`
inmediatamente después del chequeo de `has_billable_orders` existente, con el mensaje exacto de
FR-016 ("Hay un saldo pendiente por cobrar"). **No se toca `checkout.release_table`** en esta spec
— no está en el camino activo del usuario y añadirle la misma guarda sin que nada lo ejercite sería
trabajo no verificable (Principio X); queda documentado aquí como deuda conocida si ese endpoint
legado se reactiva alguna vez, consistente con no mezclar refactorizaciones no relacionadas
(Principio V).

## D6 — Exponer el saldo pendiente en el panel de cuenta

**Hallazgo clave**: la "cuenta" que ve el cajero en `pos-checkout-panel.component.ts` depende de
qué endpoint de cómputo de cuenta esté vivo. El propio repositorio documentó (`pos-specs/
specs/000-reconocimiento/contradiccion-06-cuenta-a-cobrar-tres-implementaciones.md`) que existen
**tres** implementaciones distintas de "cuánto se le debe cobrar a esta mesa", y que
`table_sessions/service.py::compute_bill` es la única con uso real confirmado en frontend
(`table-session.service.ts`, expuesta en `GET /table-sessions/{id}/bill`) — las otras dos
(`orders/checkout.py::compute_bill`, `group_bill`) no tienen ningún llamador vivo.

**Decisión**: agregar `pending_balance: Decimal` (y, si es útil para el detalle visual,
`pending_additions: list[...]`) a la respuesta de `compute_bill` (`table_sessions/service.py`),
calculado con la misma fórmula de D2, sumada sobre todas las órdenes de la sesión. **No se toca**
`orders/checkout.py::compute_bill` ni `group_bill` — extenderlos también sería arreglar la
fragmentación de la contradicción 06, un problema preexistente y no relacionado con esta spec
(Principio V). Si en el futuro se resuelve esa contradicción, ese trabajo deberá propagar
`pending_balance` a las implementaciones que sobrevivan.

## D7 — Evento de tiempo real para "línea modificada"

**Hallazgo clave**: el despachador (`app/core/events.py`) ya resuelve transporte (Redis Streams por
tenant), canales (`CH_STAFF`, `session_channel`) y el primitivo `publish()` (L106-143, fail-open,
se llama siempre después del commit). El evento más parecido, `item_kitchen_changed` (L196-211),
tiene exactamente la forma que necesitamos (ids + el campo que cambió) pero semánticamente describe
una transición de `estado_cocina`, no una adición nueva.

**Decisión**: nuevo tipo de evento `order.item_addon_added(tenant_id, *, order_id,
table_session_id, item_id, option_name, quantity)`, mismo molde que `item_kitchen_changed`, mismos
canales (`CH_STAFF` + `session_channel` si hay mesa). Se emite desde `additions.py` tras el commit
del paso D1, y desde `complementary.py` tras el commit del paso D4 (ahí también se emite
`bill_changed`, igual que ya hace `void_item` router cuando una operación cambia el total).
**Frontend**: `pos-terminal.store.ts::connectRealtime()` (L1434-1461) gana un listener
`this.realtime.on('order.item_addon_added', recargar)`, mismo patrón que los listeners existentes
de `item_kitchen_changed`/`item_voided`.

**Por qué un tipo nuevo y no reutilizar `item_kitchen_changed`**: ese evento documenta que
`estado_cocina` cambió; una adición no cambia `estado_cocina` (la línea sigue "Pendiente" o "En
preparación"). Forzar el payload existente a representar algo distinto confundiría a cualquier
consumidor futuro que asuma que ese evento siempre implica un cambio de estado.

## D8 — Frontend: puntos de inserción exactos

- **Botón "Agregar adición"**: `pos-order-panel.component.ts`, mismo bloque `it.kind ===
  'persisted'` (L282-324) donde ya viven "Marcar listo" (condicionado a `!it.ready`) y "Anular"
  (condicionado a `!store.selectedOrder()?.paid`). El nuevo botón usa la misma condición de
  `!it.ready` que ya acota a `estado_cocina ∈ {pendiente, en_preparacion}` — se verificará en
  implementación la derivación exacta de `it.ready` antes de reutilizarla, para no asumir que
  cubre el mismo conjunto de estados sin confirmarlo contra el código vigente en ese momento.
- **Panel de cuenta / "Cobrar saldo"**: `pos-checkout-panel.component.ts`, mismo bloque post-cobro
  donde ya están "Imprimir Factura" y "Liberar Mesa" (L378-421, condicionado a
  `!pendingCheckout()`). El bloque nuevo de saldo pendiente se condiciona de forma análoga —
  visible solo cuando `pending_balance > 0` (D6).
- **Store**: `pos-terminal.store.ts` gana `addAddition(itemId, optionId, quantity)` y
  `settlePendingBalance(orderId, payment)`, siguiendo el mismo patrón de las acciones existentes
  (`voidPersistedItem`, `avanzarItem`) — llaman al servicio HTTP, y dejan que el evento de
  tiempo real (D7) o la recarga optimista actualicen el estado, igual que ya hacen esas acciones.

## D9 — Descontar solo la adición, nunca la receta base de la línea otra vez

**Hallazgo clave (detectado en `/speckit-analyze`, no en la investigación original)**: tanto el
descuento inmediato de una adición sobre un pedido sin pagar (D1/FR-005) como el descuento al
cobrar el pago complementario (D4/FR-012) necesitan descontar inventario de **una sola** adición
nueva sobre una línea que **ya existe**. Pero `deduct_order_item`/`deduct_order_items`
(`app/api/v1/orders/consumption.py`) siempre llaman a `plan_line_consumption(db, variant_id,
item.quantity, options)` (`app/catalog_engine/consumption.py:94-146`), que **siempre** incluye la
receta base de la variante (`ConsumptionLine(..., source="receta")`, línea 114-117) multiplicada
por `item.quantity`, además del consumo de las `options` que se le pasen. Esa receta base **ya se
descontó** cuando la línea se creó (`add_item_to_order`/`create_order`) — volver a llamar
`deduct_order_item`/`deduct_order_items` "acotado a la nueva opción" descontaría la receta base de
toda la línea **una segunda vez**, descuadrando el inventario.

**Decisión**: nueva función en `app/api/v1/orders/consumption.py`:

```python
def deduct_addition(
    db: Session, order_item: OrderItem, chosen_option: ChosenOption,
    user_id: UUID | None, reference_id: UUID,
) -> None:
    """Descuenta solo el insumo de UNA adición agregada después de que la línea ya
    existe (spec 123) — a diferencia de deduct_order_item, nunca incluye la receta
    base de la variante (ya se descontó cuando se creó la línea): descarta toda
    línea de consumo con source == 'receta' antes de aplicar el movimiento."""
    for line in plan_line_consumption(
        db, order_item.product_variant_id, order_item.quantity, [chosen_option]
    ):
        if line.source == "receta":
            continue
        record_movement(
            db, line.inventory_item_id, type="out", quantity=line.quantity,
            reason=reasons.VENTA, reference_type=reasons.REF_ORDER,
            reference_id=reference_id, user_id=user_id,
        )
```

El chequeo preventivo (`check_availability`) debe construir su `required` con el mismo filtro
(`source != "receta"`), por la misma razón — si no, rechazaría agregar una adición válida contando
de más el insumo de la receta base, que no tiene que ver con esta operación.

**Dónde se usa**: `orders/additions.py::add_addition_to_order_item` (D1, caso sin pagar — descuento
inmediato) y `sales/complementary.py::settle_pending_balance` (D4, una llamada por cada
`OrderItemOption` pendiente cubierta) — **ninguno de los dos llama `deduct_order_item`/
`deduct_order_items`/`deduct_order_items_naming_product` directamente** para una adición post-hoc;
esas funciones siguen siendo exclusivas de líneas completas nuevas (`add_item_to_order`,
`create_order`, reemplazo de ítem anulado), sin cambios.

## Characterization tests — qué se preserva, qué se agrega

- **Se preservan sin cambios**: `test_orders_kitchen.py` (transiciones/void), `test_orders_
  checkout.py` (`pay_order`/`checkout_and_send`/`build_sale` existentes — `build_sale` gana un
  parámetro con default que no altera ningún llamador actual), `test_cart_service.py`,
  `test_table_sessions_service.py::test_release_paid_session_409_si_queda_algo_por_cobrar` (caso
  distinto al nuevo).
- **Se agregan**: `test_orders_additions.py` (Historias 1, 2, 4), `test_sales_complementary_
  payment.py` (Historias 3, 4 — incluye el caso atómico de stock insuficiente y el caso sin módulo
  de inventario), casos nuevos en `test_table_sessions_service.py` (`has_pending_balance`,
  409 nuevo en `release_paid_session`) y en `test_plan_module_access.py` (cobro complementario sin
  módulo de inventario habilitado).
