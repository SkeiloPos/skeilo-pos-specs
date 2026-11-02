# Contrato: rechazo 409 unificado por producto agotado

**Spec**: [../spec.md](../spec.md) (FR-021 a FR-024, US3, Clarifications Q4/Q8) | **Research**: [../research.md](../research.md) (D6, D7, D17)

Un pedido que incluya al menos un elemento no pedible —por **marca manual**, por **falta de
insumos** o porque la **cantidad pedida supera lo que alcanza el inventario**— se rechaza con
**un único** `409 Conflict`, **sin crear ni modificar nada** (ni orden, ni ítems, ni descuento de
inventario, ni limpieza de carrito).

## Forma de la respuesta

```json
{
  "detail": {
    "error": "Se agotaron: Granizado de mora · 16 oz, Paleta de coco. Quítalos para continuar",
    "productos_agotados": ["Granizado de mora · 16 oz", "Paleta de coco"],
    "agotados": [
      {
        "id": "2b7e…",
        "tipo": "presentacion",
        "nombre": "Granizado de mora · 16 oz",
        "producto_id": "8f1c…",
        "motivo": "inventario"
      },
      {
        "id": "91d0…",
        "tipo": "producto",
        "nombre": "Paleta de coco",
        "producto_id": "91d0…",
        "motivo": "manual"
      }
    ]
  }
}
```

### `agotados[]` (clave **nueva**, aditiva)

| Campo | Valores | Notas |
|---|---|---|
| `id` | UUID | Del elemento agotado: producto, presentación u opción según `tipo`. |
| `tipo` | `producto` \| `presentacion` \| `opcion` | Una adición agotada es un `producto`. |
| `nombre` | string | Legible. Para `presentacion`/`opcion` va **junto con su producto**: `«Granizado de mora · 16 oz»`, `«Granizado de mora · Mora»` (FR-022). Usa `display_name` de la variante (spec 099). |
| `producto_id` | UUID | Producto dueño (igual a `id` cuando `tipo = producto`). |
| `motivo` | `manual` \| `inventario` \| `cantidad` | `manual` = marca de la spec 093; `inventario` = sin existencias para 1 unidad; `cantidad` = hay para 1 pero no para lo pedido (FR-022, Edge Case). |

Lista **completa**: nombra todos los elementos afectados, no solo el primero. Sin duplicados.
Orden estable (producto → presentación → opción, luego por nombre).

### Texto de `error` (FR-024)

- Uno: `Se agotó: <nombre>. Quítalo para continuar`
- Varios: `Se agotaron: <nombre 1>, <nombre 2>. Quítalos para continuar`

## Compatibilidad (FR-023): claves que se conservan

El rechazo conserva, **por punto de entrada**, las claves que ese punto ya devolvía:

| Clave | Se conserva cuando… | Quién la lee hoy |
|---|---|---|
| `error` | siempre | `extractError()` de todos los clientes |
| `productos_agotados` | siempre (lista de **nombres**; antes solo en el rechazo manual) | ningún cliente del frontend actual la lee; se mantiene por integraciones |
| `producto` | el rechazo es de un solo elemento (forma del 409 manual y del 400 `sold_out_detail`) | — |
| `insumo` | el rechazo es de **un** elemento por inventario | `diner.service.ts:328` → «No queda suficiente X para esa cantidad» (carrito QR) |
| `disponible`, `requerido`, `contexto` | el punto de entrada es el carrito QR (`add_item` / `update_item` / `submit`) y el motivo es `inventario`/`cantidad` | `StockConflictDetail` del comensal |

El cliente nuevo usa `agotados[]`; un cliente viejo sigue funcionando con las claves de siempre.

## Puntos de entrada afectados

Todos validan **antes** de mutar; el descuento real de inventario sigue siendo el guardia final y
su `InsufficientStockError` (400) se convierte en este mismo 409 (carrera entre chequeo y
descuento), con `rollback` total como hoy.

| Ruta | Función | Hoy | Después |
|---|---|---|---|
| `POST /orders` | `orders/service.py::create_order` | 409 con **nombres** solo por marca manual; el inventario no se mira al crear (se descubre al cobrar) | 409 unificado; **chequeo preventivo de inventario nuevo** al crear (D6/H7). Es el rechazo de la Terminal. |
| `POST /orders/{order_id}/items` | `consolidation.add_item_to_order` | manual: 409 `producto`; inventario: **400** `sold_out_detail`; adiciones: 409 «Stock insuficiente» | 409 unificado |
| `POST /orders/{order_id}/checkout-and-send` | `checkout.checkout_and_send` → `_deduct_and_open` | **400** (`InsufficientStockError`) | 409 unificado (guardia final) |
| `POST /orders/{order_id}/confirm`, `POST /orders/payment-attempts/{id}/approve`, `…/confirm-cash` | `checkout._confirm_order_impl` → `_deduct_and_open` | **400** | 409 unificado (guardia final) |
| `POST /orders/items/{item_id}/void` (con reemplazo) | `kitchen.void_item` | **400** `sold_out_detail` | 409 unificado |
| `POST /cart/items`, `PATCH /cart/items/{item_id}` | `cart/service.py` | 409 «Stock insuficiente» (`insumo`/`disponible`/`requerido`) o 409 manual `producto` | 409 unificado conservando esas claves |
| `POST /cart/submit` | `cart/service.py::submit_cart` | 409 manual `productos_agotados` (nombres) o 409 «Stock insuficiente» | 409 unificado |
| `POST /orders/items/{item_id}/additions`, `…/toppings` | `orders/consumption.py` (adiciones), `orders/toppings.py` | 409 «Stock insuficiente» | mismo 409 + `agotados[]` (sin cambiar status) |

> **No cambia** el 409 por categoría oculta/desactivada de la spec 128 (`productos_no_disponibles`,
> que además **limpia** el carrito) ni el 409 de adición desasociada de la spec 129. Son otro
> motivo, otra clave y otro comportamiento; esta spec no los toca.

## Comportamiento esperado del cliente (FR-024, FR-018)

1. Conserva el carrito completo; **nunca** lo vacía.
2. Parcha el menú local con los elementos `motivo ∈ {manual, inventario}` (los marca no pedibles) y
   dispara la consulta de reconciliación (el servidor es la verdad). Los de `motivo = cantidad` **no**
   marcan el producto como agotado: marcan solo esa línea (`conflictosPorCantidad`).
3. Marca únicamente las líneas afectadas, muestra la alerta con el texto de `error` y mantiene el
   envío bloqueado hasta que se quiten o se normalicen.
4. En el menú QR dentro de los pasos de pago: se queda en el paso (sin perder método, monto ni
   comprobante), marca la línea en el resumen y ofrece «Volver al carrito».

## Pruebas del contrato

Un test por punto de entrada de la tabla verificando: (a) status 409, (b) `agotados[]` con `id`/
`tipo`/`nombre`/`motivo` correctos, (c) claves heredadas presentes, (d) **cero** filas nuevas en
`customer_orders`, `order_items`, `inventory_movements` y carrito intacto, (e) caso de dos
productos agotados a la vez, (f) caso `cantidad` (5 pedidos, insumo para 3).
