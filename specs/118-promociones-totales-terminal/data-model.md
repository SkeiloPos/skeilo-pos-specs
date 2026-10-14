# Modelo de datos — Spec 118

**Fecha**: 2026-10-14 · **Spec**: [spec.md](./spec.md) · **Decisiones**: [research.md](./research.md) D1–D7

## Sin migración de Alembic

Esta spec **no añade, modifica ni elimina ninguna columna**. Las dos piezas de esquema que necesita
ya existen, creadas por la spec 038 (y consumidas desde spec 089):

| Tabla (`tenant.*`) | Columna | Origen | Uso en esta spec |
|---|---|---|---|
| `order_items` | `discounted_unit_price` (`NUMERIC(12,2)`, nullable) | spec 038 | Pasa a escribirse también en `create_order`, `add_item_to_order`, `consolidate_table` y `void_item` (hoy solo en `cart.service.submit_cart`) |
| `order_items` | `discounted_line_total` (`NUMERIC(12,2)`, nullable) | spec 038 | Idem |

Esto es deliberado (Principio VI): la corrección es puramente de **comportamiento de escritura**
(cuándo se rellenan estas dos columnas, nunca su tipo ni su semántica), no de datos — abrir una
migración solo para esto mezclaría dos clases de cambio sin necesidad.

## Entidad afectada (sin cambio de esquema, cambio de cuándo se escribe)

### `OrderItem` (`app/models/order_item.py`)

Sin campos nuevos. Cambia el **conjunto de caminos que escriben** `discounted_unit_price`/
`discounted_line_total` mientras el pedido está abierto (no cobrado):

```
Antes de esta spec:
  cart.service.submit_cart          → escribe (canal QR_MENU, snapshot único al enviar)
  orders.service.create_order       → NUNCA escribe (queda NULL)
  orders.consolidation.*            → NUNCA escribe (queda NULL)
  orders.kitchen.void_item          → NUNCA escribe (queda NULL)

Después de esta spec:
  cart.service.submit_cart          → escribe (sin cambio de fórmula, D2)
  orders.service.create_order       → escribe, vía refresh_order_item_discounts (D3)
  orders.consolidation.*            → escribe, vía refresh_order_item_discounts (D3)
  orders.kitchen.void_item          → escribe (incluye reponer a NULL si ya no califica, D3/FR-006)
```

El valor se **recalcula sobre todas las líneas vigentes del pedido** en cada una de estas
escrituras (`order_sale_lines` ya excluye `estado_cocina = "anulado"`), nunca de forma incremental
fila por fila — necesario porque el motor de promociones puede redistribuir el descuento entre
filas existentes cuando se agrega o se quita una unidad (research.md D3).

Una fila histórica (creada antes de esta spec, o un pedido abierto que no recibe ninguna mutación
nueva tras el despliegue) conserva su valor actual — `NULL` si nunca se tocó, o lo que ya tuviera —
hasta la próxima vez que algo mute ese mismo pedido (research.md D7). No hay backfill.

### `CustomerOrder` / `Sale` / `Invoice`

Sin cambios de ningún tipo. `order.discount`/`order.applied_promotions` (nivel agregado del pedido)
y los campos de `Sale`/`SaleItem` ya se calculan correctamente al cobrar (`pay_order`,
`checkout_and_send`) desde antes de esta spec — no se tocan.

## Cambio de contrato (no de esquema): ninguno

`OrderItemResponse.discounted_unit_price`/`.discounted_line_total`
(`app/api/v1/orders/schemas.py:182-187`) **ya existen** en el schema de respuesta — esta spec no
agrega, elimina ni cambia de tipo ningún campo de ningún request/response. Cambia únicamente el
**valor** que esos dos campos, ya expuestos, traen para líneas creadas por los write-paths de
Terminal. Ver [contracts/order-item-discount-snapshot.md](./contracts/order-item-discount-snapshot.md).

## Frontend: sin nueva interfaz, cambio de agrupamiento (presentación)

`DiningOrderItem` (`pos-heladeria/src/app/modules/tables/interfaces/dining.interface.ts:106-150`)
ya tiene `discounted_unit_price`/`discounted_line_total` como campos opcionales — no se le agrega
nada. El cambio es la función `persistedItemsView()` de `PosTerminalStore`, que pasa a agrupar
filas `DiningOrderItem` "planas" (sin `combo_id`) por `(product_variant_id, notes,
firma_de_opciones)` antes de mapearlas a una card — un cambio de **presentación** (FR-008): no
crea, fusiona ni elimina ningún `OrderItem` ni ninguna fila en memoria del store; solo decide cuántas
cards renderizar a partir de los mismos datos ya recibidos del backend.

## Compatibilidad con datos existentes (Principio VII)

- Ninguna `Sale`/`Invoice` ya emitida cambia de valor por esta spec — los write-paths que esta spec
  toca (`create_order`, `add_item_to_order`, `consolidate_table`, `void_item`) operan exclusivamente
  sobre pedidos **no terminales** (`CustomerOrder.status` distinto de `pagada`/`cancelada`); ninguno
  de ellos participa en el camino de cobro.
- Un pedido ya cobrado conserva exactamente su `Sale`/`SaleItem`/`CustomerOrder.discount` tal como
  quedaron — se leen igual que antes (`SC-004` solo pide que, tras el despliegue, no se generen
  *nuevas* incidencias en pedidos abiertos; no exige recalcular nada ya cobrado).
- Un pedido abierto creado antes del despliegue no se toca de forma proactiva (sin backfill,
  research.md D7); su primer `OrderItem` nuevo o anulado tras el despliegue dispara el recálculo de
  **todas** sus líneas de una vez, dejándolo igual de correcto que un pedido creado después del
  despliegue.
- No aplica ningún nivel de "reversión de datos" más allá de revertir el código: no hay columna que
  revertir ni backfill que deshacer — revertir el commit que agrega las llamadas a
  `refresh_order_item_discounts` deja el sistema exactamente como estaba (las columnas ya existían,
  nullable, antes de esta spec).
