# Contrato — Snapshot de descuento por línea en pedidos abiertos (D1–D3)

**Afecta a**: todo endpoint que crea, anexa o anula una línea de un pedido abierto, y todo endpoint
que lee esas líneas después. No cambia la **forma** de ningún request/response (ningún campo nuevo,
ningún campo eliminado) — `OrderItemResponse.discounted_unit_price`/`.discounted_line_total`
(`app/api/v1/orders/schemas.py:182-187`) ya existen; cambia el **valor** que traen para líneas
creadas por canales distintos al carrito QR.

## Regla

Cada vez que la composición de líneas vigentes (`estado_cocina != "anulado"`) de un pedido **no
terminal** cambia, se recalcula el descuento de **todas** sus líneas de una vez:

```
refresh_order_item_discounts(db, order):
  lines   = order_sale_lines(db, order.id)                    # todas las no-anuladas
  instant = promotion_evaluation_instant([order], now=utcnow())  # mismo instante que compute_checkout_preview
  result  = evaluate_variant_sets(db, promo_lines_for(db, lines), instant)
  para cada (idx, line) en lines:
      (discounted_unit_price, discounted_line_total) =
          line_discount_snapshot(result, idx, line.line_total, line.quantity, line.addons_total)
      OrderItem[line.line_id].discounted_unit_price = discounted_unit_price   # None si no califica
      OrderItem[line.line_id].discounted_line_total = discounted_line_total   # None si no califica
```

`line_discount_snapshot` (relocada desde `cart/service.py::_cart_line_discount`, misma fórmula):

```
d = result.by_line.get(index, 0)
si d <= 0: devolver (None, None)
discounted_line_total = round(line_total - d, 2)
discounted_unit_price = round((discounted_line_total - addons_total) / quantity, 2)
```

## Dónde se llama (antes del `db.commit()` de la misma transacción)

| Función | Archivo | Cuándo |
|---|---|---|
| `create_order` | `orders/service.py` | Tras insertar todas las líneas del alta directa de comanda |
| `consolidate_table` | `orders/consolidation.py` | Tras insertar todas las líneas consolidadas de los carritos de la mesa |
| `add_item_to_order` | `orders/consolidation.py` | Tras insertar el ítem que el mesero anexa a un pedido ya existente |
| `void_item` | `orders/kitchen.py` | Tras marcar `estado_cocina = "anulado"` (y tras insertar el reemplazo, si aplica) |
| `submit_cart` | `cart/service.py` | **Sin cambio de comportamiento** — sigue calculando una sola vez sobre las líneas del carrito que se confirman; solo cambia de dónde importa `line_discount_snapshot` |

## Endpoints cuyo valor cambia (ninguno cambia de forma)

| Endpoint | Función que dispara el recálculo | Qué cambia |
|---|---|---|
| `POST /orders` (alta directa) | `create_order` | Líneas que alcanzan una promoción por volumen en una sola llamada ya calificaban visualmente; ahora además persisten el dato (antes solo el total de la Sale al cobrar lo reflejaba). |
| `POST /orders/{id}/items` (mesero anexa) | `add_item_to_order` | Caso central de la Historia 2: una segunda unidad agregada en otro momento ahora persiste el descuento en **ambas** filas. |
| `POST /tables/{id}/consolidate` | `consolidate_table` | Varios comensales pidiendo la misma presentación por separado: ahora persiste el descuento combinado. |
| `POST /orders/items/{id}/void` | `void_item` | Al anular una unidad, la(s) fila(s) restante(s) pierden el descuento si ya no alcanzan el umbral (FR-006). |
| `GET /orders` (listado, Mesas/Domicilios/Para llevar) | — (sin cambio de código) | Lee el valor ya persistido por los write-paths anteriores; sigue sin recalcular nada por fila (sin N+1 nuevo, research.md D3). |
| `GET /orders/{id}` (detalle) | — (sin cambio de código) | Idem — el detalle (`pos-order-panel.component.ts`) ya leía este campo; antes casi siempre `NULL` para Terminal, ahora poblado cuando corresponde. |
| `GET /orders/{id}/checkout-preview`, `pay_order`, `checkout_and_send`, `confirm_cash_payment_attempt`, `approve_payment_attempt` | — (sin cambio de código) | Ya eran correctos (recalculan desde cero con `order_sale_lines`+`auto_discount`); el total que devuelven ahora coincide exactamente con lo que la tarjeta/detalle ya venían mostrando, cerrando el desfase (FR-002). |

## Qué NO cambia

- Ninguna `Sale`/`SaleItem`/`Invoice` ya emitida se recalcula ni cambia de valor.
- `evaluate_variant_sets`, `order_sale_lines`, `promo_lines_for`, `compute_checkout_preview`,
  `auto_discount` no se modifican — se **reutilizan** tal cual desde el nuevo
  `refresh_order_item_discounts`.
- El canal QR (`cart.service.submit_cart`) no cambia de comportamiento ni de fórmula.
- Las líneas de combo (`combo_id is not None`) siguen excluidas del descuento por conjunto de
  variantes (filtro defensivo ya existente en `evaluate_variant_sets`) — su propio mecanismo de
  precio de combo no se toca.

## Ejemplo (Historia 2, Escenario 1 del spec)

"Fresa boom" cuesta $7.000 normal; promoción `2 x $12.000` vigente.

1. `POST /orders` con 1 unidad → `OrderItem` A: `unit_price=7000, quantity=1, discounted_unit_price=None`.
2. Más tarde, `POST /orders/{id}/items` con 1 unidad más de la misma variante → se crea `OrderItem` B
   (`unit_price=7000, quantity=1`) y `refresh_order_item_discounts` recalcula **A y B juntos**:
   `evaluate_variant_sets` ve 2 unidades elegibles → bloque completo → descuento total
   `7000×2 − 12000 = 2000`, repartido por `_distribute_group_discount` (aporte igual en A y B, 1000
   cada una) → `A.discounted_unit_price = 6000, A.discounted_line_total = 6000`;
   `B.discounted_unit_price = 6000, B.discounted_line_total = 6000`.
3. `GET /orders/{id}` y la tarjeta de Mesas muestran `TOTAL` con `6000 + 6000 = 12000` para esas dos
   unidades — igual que si se hubieran pedido juntas desde el principio.
