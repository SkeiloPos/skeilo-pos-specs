# Contrato — Agrupamiento visual de líneas planas en el detalle (D4)

**Afecta a**: `PosTerminalStore.persistedItemsView()` (`pos-heladeria/src/app/modules/tables/
services/pos-terminal.store.ts`), consumida por `pos-order-panel.component.ts` (detalle/carrito de
la Terminal, compartido por Mesas, Domicilios y Para llevar). Es un contrato de **presentación**:
no cambia ningún request/response HTTP, no crea ni fusiona ninguna fila `OrderItem`.

## Regla de agrupamiento

Dos o más `DiningOrderItem` "planos" (sin `combo_id`) de un mismo pedido se presentan como **una
sola card** del carrito cuando comparten exactamente:

```
clave_de_grupo = (product_variant_id, notes, firma_de_opciones)
firma_de_opciones = [(option_id, quantity), ...] de cada opción elegida, ordenada por option_id
```

No agrupa si cambia cualquiera de los tres: presentación distinta, notas distintas (aunque sea un
espacio de diferencia), o conjunto/cantidad de opciones distinto. Mismo criterio de "pertenencia"
que ya usa FR-005 ("mismas adiciones o modificadores, cuando aplique").

## Qué pinta la card de un grupo

| Campo de la card | Cómo se deriva del grupo (`rows: DiningOrderItem[]`) |
|---|---|
| `qty` | `Σ rows[i].quantity` |
| `subtotal` | `Σ itemLineTotal(rows[i])` (ya usa `discounted_line_total` por fila cuando viene poblado — contrato [order-item-discount-snapshot.md](./order-item-discount-snapshot.md)) |
| `promo` | `persistedLinePromo(rows, catalogPromo)` generalizada (research.md D4) — combina `originalAmount`/`discountedAmount` de todas las filas antes de derivar el % de la insignia |
| `pendingItemIds` | Concatenación de los `id` de las filas cuyo `estado_cocina` esté en `KITCHEN_NOT_READY` |
| `ready` | `rows.every((r) => !KITCHEN_NOT_READY.includes(r.estado_cocina))` |
| `kitchenStatus` | `leastAdvanced(rows)` — mismo helper que ya usa `persistedCombos` |
| `key` | Estable mientras el grupo exista (ej. `plain:${product_variant_id}:${notes}:${firma_de_opciones}`), no el `id` de una sola fila — necesario porque el grupo representa N filas, no 1 |

Formato de la insignia/tachado/monto ajustado: **idéntico** al que ya usa hoy una card de una sola
fila con promoción (FR-007) — la generalización de `persistedLinePromo` produce el mismo objeto
`CartLinePromo` (`badge`, `originalAmount`, `discountedAmount`, `savings`) para un grupo de 1 fila
que la versión anterior por fila, así que el componente de presentación
(`pos-order-panel.component.ts`) no cambia su template.

## Qué NO cambia

- Ningún `OrderItem` se fusiona, elimina ni reescribe en el backend — las N filas siguen existiendo
  tal cual, con su propio historial de cocina (`estado_cocina`), de auditoría y de anulación
  (`void_de`) independiente (FR-008).
- Anular una unidad del grupo (`void_item`) sigue operando sobre **una** fila específica, elegida
  por el cajero en la UI (ej. "quitar 1 unidad" en la card agrupada mapea a anular una de las `N`
  filas del grupo, no una cantidad parcial de una fila) — el backend ya rechaza anular una fila que
  no existe o que ya está anulada; no se agrega ningún endpoint nuevo.
- Las líneas de combo (`combo_id` no nulo) no entran en este agrupamiento — siguen agrupándose
  exclusivamente por `groupByCombo()` (sin cambios).
- Las líneas `draft` (aún no guardadas en el backend) no entran en este agrupamiento (research.md
  D4, "fuera de alcance deliberado").

## Ejemplo (Historia 2, Escenario 1 del spec)

Tras el ejemplo del contrato [order-item-discount-snapshot.md](./order-item-discount-snapshot.md)
(`OrderItem` A y B, cada uno `quantity=1`, ambos con `discounted_unit_price=6000`):

- `persistedItemsView()` agrupa A y B (misma `product_variant_id`, mismas `notes` vacías, mismas
  opciones — ninguna) en una sola card: `qty=2`, `subtotal=12000`,
  `promo={ badge: '-14%', originalAmount: 14000, discountedAmount: 12000, savings: 2000 }`
  (`7000×2=14000` vs. `6000+6000=12000`).
- El cajero ve exactamente la misma card que vería si hubiera agregado las 2 unidades juntas desde
  el inicio.

## Ejemplo (Historia 2, Escenario 2 del spec — reversión)

El cajero anula la fila B (`void_item`): `refresh_order_item_discounts` recalcula solo con A
(`quantity=1` elegible, no alcanza `min_qty=2`) → `A.discounted_unit_price = None`. En el siguiente
`GET /orders/{id}`, el grupo vuelve a tener una sola fila (A) sin pareja — `persistedItemsView()` ya
no agrupa nada (grupo de tamaño 1) y `persistedLinePromo([A], catalogPromo)` cae a la rama estimada
o devuelve `null` si la cantidad tampoco alcanza el catálogo — la card vuelve a mostrar el precio
regular, sin insignia (FR-006).
