# Investigación — Spec 118

**Fecha**: 2026-10-14 · **Spec**: [spec.md](./spec.md)

Toda decisión de esta fase se contrastó contra el código real de `pos-backend` y `pos-heladeria`
(ambos en `develop`, árbol limpio), no contra una lectura de las specs 038/063/073/089 en abstracto.

## D1 — Causa raíz única para los dos problemas: falta persistencia por línea, no falta cálculo

**Hallazgo clave**: `evaluate_variant_sets` (`app/api/v1/promotions/service.py:225`) — el motor
normativo de promociones por conjunto de variantes (spec 063) — ya agrupa correctamente **todas**
las unidades elegibles de una orden sin importar en cuántas filas `OrderItem` estén repartidas:
`_greedy_units` (línea 178) ordena por precio **todas** las unidades que le llegan en `promo_lines`
(sin distinguir de qué fila vienen) antes de trocearlas en bloques de `min_qty`. El problema nunca
es el motor.

Lo que falta es que su resultado se **persista por línea mientras el pedido está abierto**.
`OrderItem.discounted_unit_price`/`.discounted_line_total` (`app/models/order_item.py:51-60`,
columnas nullable desde spec 038, sin backfill) son exactamente el par de campos que el frontend ya
sabe consumir — pero la única escritura de producción en todo `app/` es
`cart/service.py::submit_cart` (línea 818-826), **solo para canal `QR_MENU`**, como una foto fija
tomada una sola vez al enviar el carrito. Los tres caminos que arma/edita una Terminal
POS de mostrador/mesero nunca los tocan:

- `orders/service.py::create_order` (línea ~622-648): construye cada `OrderItem` con
  `unit_price`/`addons_total`, nunca con `discounted_*`.
- `orders/consolidation.py::consolidate_table` (línea 141) y `::add_item_to_order` (línea 230):
  idem — cada llamada crea una fila `OrderItem` **nueva**, nunca busca ni fusiona con una existente
  del mismo `product_variant_id`+opciones, y nunca recalcula el descuento de las filas ya existentes.
- `orders/kitchen.py::void_item` (reemplazo de ítem anulado, línea 150): idem.

Confirmado también que `checkout_and_send` (`orders/checkout.py:654`) —que un comentario
desactualizado en `pos-terminal.store.ts::persistedLinePromo` (línea ~528-535) describe como el
punto donde "el backend resuelve y congela `discounted_unit_price`"— **no escribe nada en
`OrderItem`**: solo fija `order.discount`/`order.applied_promotions` a nivel agregado del pedido y
construye la `Sale` (con su propio snapshot `SaleItem`, independiente de `OrderItem`). Ese comentario
se corrige como parte de esta spec (documenta un comportamiento que nunca existió tal cual).

**Consecuencia para el frontend**: `PosTerminalStore.itemLineTotal()` (línea 480-483) y
`orderSubtotal()` (línea 2786-2806) **ya prefieren** `discounted_line_total` cuando viene poblado,
cayendo a `unit_price × quantity + addons_total` (sin descuento) solo cuando es `NULL` — que es
siempre, para pedidos de Terminal. Por eso **Historia 1 (tarjetas) no necesita ningún cambio de
código en el frontend**: basta con que el backend empiece a poblar el campo.

`persistedLinePromo()` (línea 542-570) tiene el mismo patrón para el detalle: si
`discounted_unit_price == null`, cae a una *estimación* contra el catálogo
(`lk.variantPromotion()`) evaluada **por fila** (`quantity` de esa sola fila contra `min_qty`) — por
eso dos filas de 1 unidad cada una, agregadas en momentos distintos, nunca disparan la insignia aunque
su suma sí alcance el umbral: cada fila se evalúa sola. Esto es la causa exacta de Historia 2, y
confirma que el dato que falta (D1) es el mismo que resuelve ambos problemas; Historia 2 solo necesita,
además, un paso de **agrupamiento visual** (D3) para que las dos filas se muestren como una sola card.

**Por qué no tocar `evaluate_variant_sets`, `order_sale_lines`, `promo_lines_for` ni
`compute_checkout_preview`**: todos ya implementan la fórmula correcta y ya tienen characterization
tests. El cambio real es **cuándo se les llama y qué se hace con su resultado** (persistirlo por
línea en los write-paths de pedido abierto), no reimplementar nada (Principio V).

**Alcance real de "cualquier tipo de promoción vigente" (FR-001)**: `evaluate_variant_sets`
(`app/api/v1/promotions/service.py:252-293`) evalúa **en el mismo bucle** las reglas `package_price`
(línea 273-279, el caso "por volumen" de esta spec) y `percent` (línea 280-288, FR-027 de spec 083:
el `%` se aplica sobre `base_unit_price`), acumulando ambas al mismo `by_line` (línea 291-293). Por
eso `refresh_order_item_discounts` (D3) persiste correctamente el descuento por línea para **ambos**
tipos sin ningún trabajo adicional — una promoción `percent` queda cubierta por el mismo cambio que
corrige la de volumen, no es un caso aparte. `LIVE_TYPES = ("percent", "package_price")`
(`service.py:43`) confirma además que `fixed` ("monto fijo") fue retirado en la migración `063d`
(`app/models/promotion.py:31-38`, docstring de `PROMOTION_TYPES`) y `active_variant_set_rules`
filtra por `PromotionRule.type.in_(LIVE_TYPES)` — ninguna promoción activa puede ser hoy de tipo
`fixed`, así que ese tipo queda fuera del alcance verificable de FR-001 (ver spec.md, corregido en
esta misma sesión de análisis).

## D2 — Dónde vive la función compartida de snapshot, y por qué un import local rompe el ciclo

`cart/service.py::_cart_line_discount` (línea 304-320) ya calcula exactamente
`(discounted_unit_price, discounted_line_total)` a partir de un `SetDiscountResult.by_line` — es la
pieza que los tres write-paths de `orders/` necesitan, sin reinventarla.

**Decisión**: se relocaliza y se hace pública como `line_discount_snapshot(result, index, line_total,
quantity, addons_total)` en `app/api/v1/orders/checkout.py`, junto a `order_sale_lines`/
`promo_lines_for`/`auto_discount`/`promotion_evaluation_instant` (de los que ya depende la nueva
`refresh_order_item_discounts`, D3). `cart/service.py::submit_cart` pasa a importarla desde ahí en
vez de definirla — **sin cambio de comportamiento para el canal QR**, es la misma fórmula.

**Restricción real verificada por código**: `orders/checkout.py` importa `order_has_sale` desde
`orders/service.py` (línea 59: `from app.api.v1.orders.service import order_has_sale`, usado en su
propio `cancel_order`). Si `orders/service.py::create_order` importara `refresh_order_item_discounts`
desde `orders/checkout.py` al nivel de módulo, se cerraría un ciclo de imports
(`service.py → checkout.py → service.py`). `orders/consolidation.py` y `orders/kitchen.py` no tienen
hoy ningún import de `checkout.py` ni viceversa, así que para ellos un import a nivel de módulo sería
seguro — pero para mantener un único patrón en los tres call-sites (y no depender de que la ausencia
de ciclo en consolidation/kitchen se mantenga así en el futuro), los tres importan
`refresh_order_item_discounts` **dentro de la función que la llama** (import diferido), justo antes
de usarla. Es el patrón estándar de Python para romper un ciclo de imports sin reestructurar código
no relacionado con esta spec (Principio V) — no se decide mover `order_has_sale` de sitio: esa
función no tiene relación con el problema de esta spec.

**Alternativas descartadas**:
- Nuevo módulo `orders/discounts.py` que reexporte desde `checkout.py`: no evita el ciclo, porque
  `service.py` seguiría importando (transitivamente) `checkout.py`, que importa `service.py`.
- Mover `order_has_sale` fuera de `checkout.py`'s dependencias para liberar el import a nivel de
  módulo: toca código sin relación con el defecto que esta spec corrige (Principio V).

## D3 — Recalcular TODAS las líneas del pedido en cada mutación, no solo la que cambió

`evaluate_variant_sets` reparte el descuento de un bloque completo entre las filas que aportaron
unidades a ese bloque (`_distribute_group_discount`, `promotions/service.py:189`), proporcional al
aporte de cada fila. Esto significa que agregar una segunda unidad puede cambiar qué filas "tenían"
el descuento ya asignado, incluida la primera fila que antes no calificaba sola.

**Decisión**: `refresh_order_item_discounts(db, order)` siempre:
1. Carga **todas** las líneas vigentes del pedido con `order_sale_lines(db, order.id)` (ya filtra
   `estado_cocina != "anulado"`).
2. Evalúa `evaluate_variant_sets(db, promo_lines_for(db, lines), instant)`, con
   `instant = promotion_evaluation_instant([order], now=datetime.now(timezone.utc))` — el mismo
   instante congelado que ya usa `compute_checkout_preview`/`checkout_and_send`/`pay_order`, para
   que el número coincida centavo a centavo con lo que cobrará el módulo de cobro (FR-002).
3. Para cada línea (identificada por `SaleLine.line_id`, el `OrderItem.id`), calcula
   `line_discount_snapshot(result, idx, line.line_total, line.quantity, line.addons_total)` y lo
   **sobrescribe** en la fila `OrderItem` correspondiente — incluido escribir `(None, None)` cuando
   `by_line` ya no le asigna descuento (FR-006: revertir la presentación al caer bajo el umbral).

Se llama al final de cada mutación de líneas, **antes** del `db.commit()` de esa misma transacción
(mismo patrón que ya usa cada write-path para su propio `db.flush()`):

- `orders/service.py::create_order` — tras insertar todos los `entries`.
- `orders/consolidation.py::consolidate_table` — tras insertar todas las líneas consolidadas de la
  mesa (puede haber varias presentaciones distintas; el recálculo cubre el pedido completo de una).
- `orders/consolidation.py::add_item_to_order` — tras insertar el ítem nuevo (cubre exactamente el
  escenario de la Historia 2: una segunda unidad agregada en un momento distinto).
- `orders/kitchen.py::void_item` — tras marcar `estado_cocina = "anulado"` (y tras insertar el
  reemplazo, si `data.replacement` viene) — cubre FR-006 (retirar una unidad hace caer el umbral).

Verificado por grep (`\.quantity = ` / `db.delete(OrderItem)`) que no existe ningún otro punto que
modifique la composición de líneas de un pedido **abierto**: no hay endpoint para cambiar la
`quantity` de un `OrderItem` ya creado (mismo hallazgo que spec 117 D3), y `cancel_order` siempre
termina el pedido completo (deja de ser visible en Mesas/Domicilios/Para llevar), así que no
necesita refrescar nada.

**Costo**: el mismo motor que ya corre en cada cobro ahora también corre en cada escritura de línea
(crear/anexar/anular ítem) — no en cada lectura. `GET /orders` (el listado de la Terminal) **no**
cambia: sigue sin llamar a `evaluate_variant_sets` por fila, preservando deliberadamente la misma
guarda anti-N+1 que ya protege `test_d3_el_listado_devuelve_billing_en_null_en_todos_sus_items`
(`test_orders_billing_summary.py`) y el test frontend que verifica que abrir "Domicilios" no dispara
`checkout-preview` por tarjeta (`pos-terminal.store.spec.ts`, bloque spec 078 US1). El dato ya llega
calculado en la respuesta del listado porque se escribió en la fila al momento de crearla/editarla,
no al leerla.

## D4 — Agrupamiento visual del detalle: generalizar `persistedLinePromo`, no reinventar

`PosTerminalStore.persistedItemsView()` (línea 1030-1108) convierte cada `OrderItem` "plano" (sin
`combo_id`) en su propia línea de carrito 1:1 — no hay ningún agrupamiento por
`product_variant_id`+opciones para productos sueltos repetidos, a diferencia de `groupByCombo()`
(línea 1929-1938), que sí agrupa, pero únicamente por `combo_id`.

**Decisión**: se añade un agrupamiento análogo para líneas planas, con clave
`(product_variant_id, notes, firma_de_opciones)` — donde `firma_de_opciones` es la lista
`(option_id, quantity)` de cada fila, ordenada por `option_id`, serializada a string. Dos filas
agrupan solo si tienen la misma presentación, las mismas notas y exactamente las mismas opciones con
la misma cantidad cada una — coherente con el enunciado de FR-005 ("mismas adiciones o modificadores,
cuando aplique").

Para la card resultante de un grupo de `N` filas, se generaliza `persistedLinePromo()` para que
reciba el arreglo de filas del grupo en vez de los campos de una sola fila:

```ts
private persistedLinePromo(rows: DiningOrderItem[], catalogPromo: MenuVariantPromotion | null): CartLinePromo | null {
  const totalQty = rows.reduce((s, r) => s + r.quantity, 0);
  const originalAmount = rows.reduce(
    (s, r) => s + Number(r.unit_price) * r.quantity + Number(r.addons_total ?? 0), 0,
  );
  const anyDiscounted = rows.some((r) => r.discounted_unit_price != null);
  if (anyDiscounted) {
    const discountedAmount = rows.reduce((s, r) => s + this.itemLineTotal(r), 0);
    if (discountedAmount >= originalAmount) return null;
    const percent = Math.round((1 - discountedAmount / originalAmount) * 100);
    if (percent <= 0) return null;
    return { badge: `-${percent}%`, originalAmount, discountedAmount, savings: originalAmount - discountedAmount };
  }
  if (!catalogPromo || totalQty < catalogPromo.min_qty) return null;
  const unitPrice = Number(rows[0].unit_price);           // misma presentación+opciones ⇒ mismo unit_price
  const addonsTotal = rows.reduce((s, r) => s + Number(r.addons_total ?? 0), 0);
  const discountedAmount = packagePrice(unitPrice, catalogPromo, totalQty) + addonsTotal;
  if (discountedAmount >= originalAmount) return null;
  return {
    badge: catalogPromo.short_condition,
    originalAmount, discountedAmount, savings: originalAmount - discountedAmount,
  };
}
```

Esta generalización **subsume el caso de hoy** (grupo de una sola fila: `originalAmount`/
`discountedAmount` quedan matemáticamente idénticos a los que ya calculaba la versión por fila), así
que no hace falta mantener dos funciones ni dos formatos de insignia (FR-007: mismo formato ya usado
hoy). La rama "sin descuento persistido" (`catalogPromo`, estimación) sigue existiendo para pedidos
históricos que cruzan la fecha de despliegue con `discounted_unit_price` aún `NULL` (ver D7) —
`packagePrice(unitPrice, catalogPromo, totalQty)` ya calculaba bloques sobre una cantidad
combinada, así que evaluarlo sobre `totalQty` del grupo (en vez de la cantidad de una sola fila) es
la corrección natural del mismo bug de fondo, para el caso estimado.

`pendingItemIds`/`ready`/`kitchenStatus` del grupo se calculan igual que ya hace `persistedCombos`
para `comboGroups` (`its.every(...)`, `leastAdvanced(its)`, concatenar los `id` de cada fila) — mismo
patrón, sin inventar uno nuevo.

**Fuera de alcance deliberado**: las líneas en estado `draft` (todavía no enviadas al backend,
`cartView()` rama `draft`) no se tocan — los escenarios de aceptación de Historia 2 describen
unidades agregadas en **momentos distintos sobre una orden ya abierta** (persistida), no dos líneas
borrador coexistiendo en la misma sesión de edición antes de guardar (ese caso ya lo resuelve
`incDraft` desde spec 115/117, fuera del problema que reporta esta spec).

## D5 — "Pagos por confirmar" (FR-004, Escenario 4): ya correcto, falta solo cobertura de test

`confirm_cash_payment_attempt` (`orders/checkout.py:1297-1422`) valida
`amount_received < compute_checkout_preview(db, attempt.order_id).total` — el mismo total con
promociones que usan la tarjeta y el detalle (ya corregido por spec 073, comentario explícito en el
código: antes usaba `_order_total`, suma sin descuento; "FR-004" de ESA spec, no de esta).
`approve_payment_attempt` (línea 1124-1239) paga con el mismo `auto_discount`. Ambos reusan
`order_sale_lines`+`evaluate_variant_sets`, que ya agrupan entre filas distintas (D1) — nada que
corregir aquí.

El frontend (`payment-attempt-review-panel.component.ts`) pide `GET /orders/{id}/checkout-preview`
(`loadCheckoutPreview()`, línea 381-395) y valida/muestra el cambio contra
`checkoutPreview().total` (línea 434-550) — nunca contra una suma local. `reconfirmIfTotalChanged()`
(línea 463-478) además revalida el preview justo antes de aprobar/confirmar, por si la promoción
cambió entre que se mostró y que el cajero hizo clic.

**Gap real, confirmado por grep**: existe `TestConfirmCashChequeoPrevioConPromocion073`
(`test_orders_payment_gate.py:541`) que ya cubre "Pagos por confirmar" con una promoción de volumen
— pero su fixture (`_seed_qr_order_con_promo`) crea la línea con `fx.make_order_item(..., quantity=2)`
en **una sola fila**, el caso que ya funcionaba antes de esta spec. No existe ningún test que cubra
el caso de esta spec: la misma orden QR recibiendo una **segunda** unidad por un camino distinto
(`add_item_to_order`, el mesero) antes de que el cajero abra "Pagos por confirmar" — el Edge Case
explícito del `spec.md` ("cantidad combinada... agregando unidades desde canales distintos").

**Decisión**: no se toca código de producción de `checkout.py` para este punto; se añade un test
nuevo en `test_orders_payment_gate.py` que reproduce exactamente ese camino (orden QR con 1 unidad +
`add_item_to_order` del mesero con 1 unidad más + `confirm_cash_payment_attempt`) y verifica que el
monto validado ya incluye el descuento — cerrando la cobertura de FR-004/Escenario 4 sin cambiar
comportamiento.

## D6 — Sin entrada nueva en `registro-de-anomalias.md`

Se verificó por grep (`discounted_unit_price|discounted_line_total` dentro de
`app/characterization_tests/*.py`) que la única coincidencia es `test_cart_service.py` — ningún test
con prefijo `"CONGELA comportamiento actual:"` en `test_orders_service.py`,
`test_orders_consolidation.py`, `test_orders_kitchen.py` ni `test_orders_billing_summary.py` asume o
congela que estas columnas queden `NULL` para líneas creadas por `create_order`/
`add_item_to_order`/`consolidate_table`/`void_item`. Por el Principio III, no hay ningún test
protegido que esta spec deba actualizar citando una decisión de negocio — el defecto que corrige
nunca estuvo "congelado" como comportamiento intencional, solo ausente de cobertura.

El propio `spec.md` (encabezado "Naturaleza de esta spec") ya documenta por qué esto es una
corrección de comportamiento, satisfaciendo el requisito de documentación explícita del Principio
II sin necesitar, además, una entrada en `registro-de-anomalias.md` (que el Principio II reserva
para cambios que SÍ reabren un comportamiento ya protegido por un test, caso que aquí no se da).

## D7 — Ventana transitoria para pedidos abiertos creados antes del despliegue (Principio VII)

Un pedido abierto creado **antes** de que esta corrección se despliegue conserva sus líneas con
`discounted_unit_price`/`discounted_line_total` en `NULL` hasta que una mutación nueva
(`add_item_to_order`, `void_item`, o una nueva consolidación) vuelva a tocar ese mismo pedido —
momento en el que `refresh_order_item_discounts` recalcula **todas** sus líneas de una vez. Mientras
tanto, su tarjeta de Terminal sigue mostrando el `TOTAL` sin descontar, igual que hoy.

**Por qué se acepta esta ventana en vez de un backfill**: (1) Principio VII protege datos
**históricos/finalizados** (facturas, ventas emitidas) — un pedido abierto no cobrado no es dato
histórico, así que no hay problema de principio en recalcularlo "retroactivamente" cuando se
mutate, pero tampoco hay obligación de tocarlo si nadie lo mutate; (2) las sesiones de mesa/pedidos
abiertos se cierran solas en 30 minutos (sin pedidos nuevos) o 6 horas (con pedidos), memoria
`reference_sesion_mesa_cierre_automatico` — la ventana de inconsistencia posible al desplegar es
acotada a, como máximo, un turno; (3) añadir un script de recálculo masivo de todos los pedidos
abiertos al momento del despliegue mezclaría una migración de datos con una corrección de
comportamiento que la propia spec no pide (Principio VI) — la spec no incluye ningún Requisito
Funcional ni Criterio de Éxito que exija corrección instantánea para pedidos **ya abiertos** al
desplegar, solo que el defecto "se reduzca a cero tras el despliegue" (SC-004), lo que una ventana de
un turno satisface sin trabajo adicional.

Queda como tarea opcional (no obligatoria) de `tasks.md` decidir si se agrega un script de
recálculo único para los pedidos abiertos al momento del despliegue, si el negocio prefiere cerrar
la ventana de inmediato.

## Tests nuevos/actualizados (ninguno es characterization protegido, ver D6)

- `app/characterization_tests/test_orders_service.py` — `create_order` con 2 líneas de la misma
  presentación en una sola llamada (ya calificaba) persiste `discounted_*`; caso base de
  regresión antes de probar adiciones sucesivas.
- `app/characterization_tests/test_orders_consolidation.py` — `add_item_to_order` dos veces
  (1 unidad cada vez) sobre la misma presentación: tras la segunda llamada, **ambas** filas quedan
  con `discounted_unit_price`/`discounted_line_total` poblados y coherentes con
  `compute_checkout_preview` del pedido completo (Historia 2, Escenario 1). `consolidate_table` con
  carritos de dos comensales distintos sobre la misma presentación: idem.
- `app/characterization_tests/test_orders_kitchen.py` — `void_item` sobre una de las dos filas:
  la fila restante vuelve a `discounted_unit_price = None` (Historia 2, Escenario 2 / FR-006).
- `app/characterization_tests/test_orders_payment_gate.py` — ver D5 (adiciones sucesivas + "Pagos
  por confirmar").
- `app/characterization_tests/test_cart_service.py` — se actualiza solo el import
  (`line_discount_snapshot` en vez de `_cart_line_discount`); sin caso nuevo, sin cambio de
  comportamiento (D2).
- Frontend: `pos-terminal.store.spec.ts` — nuevo bloque para `persistedItemsView()` con 2 filas de
  la misma presentación+opciones agregadas por separado (agrupan en una card, insignia correcta) y
  caso de reversión al anular una; `pos-order-panel.component.spec.ts` — verificación visual de que
  se renderiza una sola card, no dos.
