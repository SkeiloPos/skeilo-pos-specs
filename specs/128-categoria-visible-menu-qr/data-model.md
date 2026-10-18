# Data Model: Visibilidad de categorías en el menú QR

## Categoría (`Category`, `app/models/category.py`, schema `tenant`)

Campo nuevo:

| Campo | Tipo | Notas |
|---|---|---|
| `visible_en_qr` | `bool`, `NOT NULL`, `server_default='true'` | Visibilidad específica del menú QR, independiente de `active`. Toda categoría existente queda `true` al migrar (FR-001). No tiene relación con `display_order`: cambiarlo nunca reordena nada (FR-004). |

Campos existentes, sin cambios: `id`, `name`, `description`, `active` (alta/baja general,
afecta también al catálogo del personal), `display_order` (posición en el filtro del menú QR,
spec 067), `products` (relación inversa 1-a-muchos — **un producto pertenece a exactamente una
categoría**, `Product.category_id` es `NOT NULL` y no hay tabla puente; confirma que ocultar
una categoría oculta siempre el 100% de sus productos, sin ningún caso de visibilidad parcial),
`presentations` (spec 083, sin relación con esta spec).

**Regla de vigencia en QR** (FR-002): una categoría aparece en el menú QR (y en su buscador,
que filtra sobre los mismos datos ya cargados) si y solo si `active = true` **y**
`visible_en_qr = true`. Ambas condiciones son independientes entre sí — cada una tiene su
propio control en la UI de administración, y cambiar una no toca el valor de la otra (ver Edge
Cases de `spec.md`: reactivar una categoría no reinicia su `visible_en_qr`).

## Producto (`Product`, `app/models/product.py`)

Sin cambios de esquema. Relevante para esta spec: `category_id` (`NOT NULL`, FK única — un
producto, una categoría) y `available` (el flag de "Agotado" de spec 093, ortogonal a esta
spec: un producto puede estar disponible y su categoría oculta en QR a la vez, o viceversa).

## Carrito del comensal (`Cart`/`CartItem`, sin cambios de esquema)

No gana ningún campo nuevo. Lo que cambia es el momento de envío (`submit_cart`,
`app/api/v1/cart/service.py`): además de la revalidación ya existente de `Product.available`
(spec 093), se suma una revalidación equivalente sobre la categoría de cada ítem
(`active AND visible_en_qr`, mismo criterio de FR-002). Un ítem que ya no cumple esa condición
se elimina del carrito como parte de esa misma llamada y el envío se rechaza, nombrando los
productos afectados (research.md, Decisión 5) — no se introduce ningún estado nuevo en
`CartItem`, solo una fila que deja de existir.

## Evento en tiempo real (US3/FR-009, `app/core/events.py` — opcional, prioridad P3)

Si se implementa: un nuevo tipo de evento (`menu.updated` o equivalente) sin payload
relevante más allá de la notificación misma (el cliente vuelve a pedir `GET /menu` entero, no
recibe el diff) — mismo principio de "eventos delgados" que ya sigue el catálogo existente
(`app/core/events.py`, docstring del módulo). Requiere además un canal SSE nuevo que todo
comensal con el menú QR abierto reciba, distinto del `session_channel` por mesa que ya existe
(research.md, Decisión 6) — es la única pieza de este modelo de datos que no es una extensión
de algo ya existente, sino una ampliación real de la arquitectura de canales.

## Relación para esta corrección

```text
Category.active ──┐
                   ├──(AND)──► visible en menú QR / buscador / revalidación de carrito
Category.visible_en_qr ──┘

Category.display_order ──► posición en el filtro del menú QR (sin relación con lo anterior)
```
