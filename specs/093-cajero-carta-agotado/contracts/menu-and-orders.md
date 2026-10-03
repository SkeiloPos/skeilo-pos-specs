# Contrato: Efecto de "Agotado" en el menú (QR y Terminal) y en carrito/pedidos

**Spec**: [../spec.md](../spec.md) | **Research**: [../research.md](../research.md) (D6, D7)
**Anomalía registrada**: `specs/000-reconocimiento/registro-de-anomalias.md`, A-104

## `GET /menu` y `GET /menu/qr-token/{token}` — dejan de ocultar productos agotados

Ambos endpoints están resueltos por la misma función `_build_menu()`
(`app/api/v1/menu/router.py`) — un único cambio cubre Terminal de mesas (que consume
`GET /menu`) y el menú QR del comensal (`GET /menu/qr-token/{token}`) a la vez.

**Antes**: la consulta de productos filtraba `Product.available.is_(True)` — un producto
agotado no aparecía en absoluto en la respuesta.

**Después**: se quita ese filtro (el producto sigue devolviéndose mientras
`Product.active=True`, sin cambio ahí) y `MenuProductResponse` gana un campo nuevo:

```json
{
  "id": "…",
  "name": "Fresa boom",
  "...": "...resto de campos sin cambios...",
  "available": true,
  "sold_out": true
}
```

| Campo | Significado | ¿Cambia con esta spec? |
|---|---|---|
| `available` | "Pedible dado el stock de las opciones obligatorias de sus presentaciones" (characterization-protegido) | **No** — ni su cálculo ni su nombre cambian |
| `sold_out` | `not Product.available` — el flag manual "Agotado" de esta spec | **Nuevo** |

Un producto puede tener `available=true` y `sold_out=true` simultáneamente (pedible por
stock, pero marcado agotado manualmente) — en ese caso `sold_out=true` manda: no se
puede agregar al pedido (ver abajo). También puede darse `available=false` (sin stock de
una opción obligatoria) y `sold_out=false` (nadie lo marcó manualmente) — ese caso ya
existe hoy y no cambia.

## Frontend: Terminal de mesas y menú QR

| Componente | Cambio |
|---|---|
| `pos-catalog-drawer.component.ts` (grilla "Nueva orden", Terminal de mesas) | Cuando `product.sold_out`: tarjeta atenuada, etiqueta "Agotado", clic deshabilitado (no abre el modal de selección de variante) |
| `public-menu.component.ts` (grilla del menú QR) | Mismo tratamiento: tarjeta atenuada, etiqueta "Agotado", no abre `ProductSelectComponent` |

No se requiere actualización en tiempo real del menú QR ya abierto (excluido
explícitamente del alcance de la spec) — el comensal ve el estado vigente al cargar o
recargar el menú; la garantía real contra pedidos de productos agotados es la validación
del servidor al confirmar (ver abajo), no la UI del menú.

## Validación al agregar un ítem (carrito del comensal y pedido manual de Terminal)

Se agrega el mismo chequeo en los cuatro puntos que ya validan `variant.active` hoy
(research.md D7):

| Endpoint | Chequeo nuevo |
|---|---|
| `POST /cart/items` (`cart/service.py::add_item`) | Si `not variant.product.available` → `409` |
| `PATCH /cart/items/{id}` (`cart/service.py::update_item`) | Igual |
| `POST /orders/{order_id}/items` (`orders/consolidation.py::add_item_to_order`) | Igual |

**Respuesta 409** (un solo producto, el que se intentó agregar):
```json
{
  "error": "«Fresa boom» está agotado y no se puede agregar al pedido",
  "producto": "Fresa boom"
}
```
Mismo shape que ya usa `sold_out_detail()` para el agotado por inventario — el frontend
reutiliza el mismo manejo de error (`extractError`/`detail.error`), sin un caso nuevo que
programar en ese nivel.

## Validación al confirmar (envío del carrito y creación de pedido manual)

| Endpoint | Chequeo nuevo |
|---|---|
| `POST /cart/submit` (`cart/service.py::submit_cart`) | Antes de crear la orden: recorre todos los ítems del carrito; si alguno está agotado, rechaza **todo** el envío |
| `POST /orders` (`orders/service.py::create_order`) | Mismo chequeo, para los varios ítems que puede traer un pedido manual nuevo |

**Respuesta 409** (uno o más productos — shape nuevo, no existía precedente de nombrar
varios a la vez, ver research.md D7):
```json
{
  "error": "Los siguientes productos están agotados: Fresa boom, Oreo split",
  "productos_agotados": ["Fresa boom", "Oreo split"]
}
```

**Garantías** (escenario 7 / FR-021 / FR-022):
- No se crea ninguna orden si al menos un ítem está agotado (todo-o-nada, misma
  transacción que ya envuelve la creación de la orden).
- El carrito del comensal **no se vacía** tras el rechazo — sigue existiendo con todos
  sus ítems (incluido el agotado) para que el comensal pueda quitarlo y reintentar.
- Un pedido ya creado **antes** de que el producto se marcara agotado no se toca ni se
  revalida — esta validación solo corre en el momento de `add_item`/`submit_cart`/
  `create_order`, nunca sobre pedidos existentes (FR-023/escenario 8).
