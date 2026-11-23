# Phase 1 Data Model: División automática de cuenta por ítem

No se agregan tablas ni columnas nuevas (ver `research.md` §5). Esta feature opera enteramente
sobre las entidades existentes `CustomerOrder` y `OrderItem` (y sus hijas
`OrderItemOption`/`OrderItemTopping`). Este documento describe los campos relevantes para las
tres operaciones nuevas y las reglas de validación/transición que aplican sobre ellos.

## Entidades existentes relevantes

### CustomerOrder (`pos-backend/app/models/customer_order.py`) — "Orden / cuenta"

Campos relevantes para esta feature (ya existentes, sin cambios de esquema):

| Campo | Tipo | Rol en esta feature |
|---|---|---|
| `id` | UUID/PK | Identifica la orden origen/destino en los 3 endpoints nuevos. |
| `table_session_id` | FK | Debe coincidir entre origen y destino en `move`/`split-to-new`: solo se permite mover/crear dentro de la **misma mesa** (FR-009). |
| `dining_table_id` | FK | Igual que arriba; se copia a la(s) orden(es) nueva(s) creada(s) por `split`/`split-to-new`. |
| `participant_id` | FK nullable | Se copia `NULL` en las órdenes nuevas creadas por `split`/`split-to-new` (el detalle de "quién paga qué" vive a nivel de ítem, no de orden). |
| `payment_status` | enum UNPAID/PAID | **Guard de entrada**: ninguna operación se permite si la orden origen o destino tiene `PAID` (FR-008). Se verifica vía `order_has_sale()`. |
| `status` | enum (pendiente/confirmado/entregada/cancelada) | Se recalcula para la(s) orden(es) resultante(s) con la misma lógica ya existente derivada del estado de sus líneas; no se fuerza un valor fijo. |
| `cash_shift_id`, `table_order_number` | FK / int | Se asignan a cada orden nueva igual que en `create_order`/`submit_cart` (numeración por turno de caja, spec 087). |
| `channel`, `order_type` | enum | Se copian de la orden origen a la(s) orden(es) nueva(s). |
| `merged_group_id` | FK nullable | No se modifica por esta feature (pertenece al flujo de unión de mesas, spec distinto); si la orden origen tenía uno, **no** se hereda automáticamente a las órdenes resultantes de `split` (son cuentas independientes nuevas, no una unión). |

**Transiciones de esta feature**:

- `split_order`: 1 `CustomerOrder` con N líneas (N > 1) → N `CustomerOrder` nuevas, cada una con
  1 línea; la orden original se **elimina**.
- `move_item` / `split_item_to_new_order`: la orden origen pierde una línea (o parte de su
  cantidad); si queda con 0 líneas, se **elimina** (FR-007). La orden destino (existente o nueva)
  gana una línea o ve incrementada la cantidad de una línea existente.

### OrderItem (`pos-backend/app/models/order_item.py`) — "Línea de producto / ítem"

| Campo | Tipo | Rol en esta feature |
|---|---|---|
| `id` | UUID/PK | Identifica el ítem a mover en `move_item`/`split_item_to_new_order`. |
| `order_id` | FK → customer_orders (CASCADE) | Se reasigna a la orden destino al mover; en `split_order` cada línea se reasigna a su propia orden nueva. |
| `participant_id` | FK nullable | Se preserva tal cual al mover/copiar (no se reasigna a `NULL`): el spec no pide reasignar el comensal dueño del ítem. |
| `product_variant_id` | FK | Parte de la clave de fusión (§3 de `research.md`); se copia igual en la línea nueva cuando se fracciona cantidad. |
| `quantity` | int | Se decrementa en la línea de origen y se incrementa/crea en la línea de destino cuando se mueve una cantidad parcial. Debe quedar `> 0` en ambas líneas resultantes (FR: "cantidad indicada sea mayor a 0 y menor a la cantidad total de la línea de origen"); si la cantidad movida es igual al total de la línea, la línea de origen se elimina en vez de quedar en 0. |
| `unit_price`, `discounted_unit_price`, `discounted_line_total` | numeric | Se preservan sin recalcular en ambas líneas resultantes (mismo precio unitario, ver Edge Cases del spec); `discounted_line_total` se recalcula proporcional a la nueva `quantity` de cada línea cuando hay descuento aplicado. |
| `estado_cocina` | enum (pendiente/entregado/cancelado) | Se preserva igual en la línea movida/creada; es también parte de la clave de fusión (si difiere del de una línea compatible en destino, no se fusiona — Clarification de sesión 2026-11-21). |
| `addons_total`, `combo_id`, `void_de`, `notes` | — | Se copian sin modificar al fraccionar/mover una línea. |

**Transiciones de esta feature**:

- Fusión (misma `product_variant_id` + `unit_price`/`discounted_unit_price` + `estado_cocina` en
  destino): `UPDATE order_items SET quantity = quantity + :moved WHERE id = :destino_id`.
- No fusión (no hay línea compatible, o `estado_cocina` difiere): `INSERT` de una línea nueva en
  la orden destino con los campos copiados y `quantity = :moved`.
- Línea de origen: `UPDATE ... SET quantity = quantity - :moved` si queda `> 0`, o `DELETE` si
  queda en `0`.

### OrderItemOption / OrderItemTopping (hijas de OrderItem)

- Al **fusionar** una línea movida en una línea existente del destino, las opciones/toppings de
  la línea movida (si la línea original no se elimina por completo, solo se mueve cantidad
  parcial) permanecen asociadas a la línea de origen; solo se duplican cuando se crea una línea
  nueva en destino (caso "no fusión"), copiando 1:1 las filas de opciones/toppings de la línea
  origen hacia la línea nueva.
- Al mover la **totalidad** de la cantidad de una línea (sin fraccionar) hacia una orden
  existente con línea compatible, las opciones/toppings de la línea original se eliminan junto
  con ella (cascade ya existente) — la línea destino ya tiene las suyas, correctas para la
  cantidad fusionada, dado que fusión solo ocurre cuando producto+variante+precio+estado_cocina
  coinciden exactamente (mismas opciones esperadas por construcción del catálogo).

## Reglas de validación compartidas (las 3 operaciones)

1. **Guard de pago** (FR-008): `order_has_sale(db, order_id)` debe ser `False` para toda orden
   origen y, cuando aplica, toda orden destino involucrada. Si es `True`, se rechaza con el aviso
   correspondiente.
2. **Guard de mesa** (FR-009): orden origen y orden destino (cuando aplica) deben compartir
   `table_session_id`/`dining_table_id`.
3. **Guard de cantidad mínima en split** (FR-001, Edge Cases): `split_order` solo procede si la
   orden tiene **más de 1 línea**; con 1 línea no hace nada (no es error, es no-op).
4. **Guard de cantidad mínima en "crear cuenta nueva"** (Edge Cases): se rechaza si el ítem
   seleccionado es la única línea restante de la orden y se indica el 100% de su cantidad (no
   genera cambio real); se permite si se indica una cantidad parcial de esa única línea.
5. **Guard de cantidad válida al fraccionar** (Edge Cases): `0 < cantidad_movida < cantidad_total_de_la_línea`.
6. **Post-condición de limpieza** (FR-007, SC-002): tras cualquiera de las 3 operaciones, toda
   orden que quede con `COUNT(order_items) == 0` se elimina de la base de datos dentro de la
   misma transacción.

## Entidades no afectadas

- **`Sale`/`SaleItem`/`Invoice`**: no se leen ni escriben por estas operaciones (son
  precondición negativa: si existen para una orden, la operación se rechaza). Ningún dato
  histórico de facturación se toca (Principio VII).
- **`OrderPaymentAttempt`**: no aplica — solo existe para órdenes QR en proceso de pago; el guard
  de "sin pago registrado" ya cubre ese caso indirectamente vía `payment_status`.
- **`DiningTable`, `TableSession`, `SessionParticipant`**: se leen (para el guard de mesa y para
  copiar `dining_table_id`/`table_session_id`) pero no se modifican.
