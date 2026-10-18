# Contratos: Visibilidad de categorías en el menú QR

Esta spec modifica el contrato observable de tres puntos ya existentes y, si se implementa
US3/FR-009, agrega uno nuevo. No se introduce ningún endpoint de administración nuevo.

## 1. `PATCH /categories/{id}` — campo nuevo

**Request** (campo agregado a `CategoryUpdate`, el resto sin cambios):

```json
{ "visible_en_qr": false }
```

**Respuestas**:
- `200` — igual que hoy, pero `CategoryResponse` ahora incluye `"visible_en_qr": <bool>`.
- `403` — **nuevo**, solo cuando el payload incluye `visible_en_qr` y quien llama no tiene rol
  ADMIN (research.md, Decisión 3). El resto de los campos (`name`, `description`, `active`,
  `display_order`, `presentation_ids`) sigue sin exigir ningún rol — el 403 depende
  exclusivamente de que `visible_en_qr` esté presente en el payload.
- `404`/`409` (nombre duplicado) — sin cambios.
- `422` — **nuevo caso**: `visible_en_qr` presente en el payload mientras la categoría está
  `active = false` (FR-006) — el cuerpo del error MUST comunicar que hay que activarla primero.

## 2. `GET /menu`, `GET /menu/qr-token/{token}` — regla de filtrado

**Sin cambio de forma** (mismo `MenuCategoryResponse`/`MenuProductResponse`). Cambia el
criterio de qué categorías/productos se incluyen: antes `active = true`; ahora
`active = true AND visible_en_qr = true` (research.md, Decisión 4). El buscador del menú QR no
tiene endpoint propio — hereda este filtro automáticamente porque filtra en el cliente sobre
esta misma respuesta.

## 3. Envío del carrito (`submit_cart` / endpoint que lo expone en `cart/router.py`)

**Sin cambio de forma del endpoint.** Se amplía el caso ya existente de `409` (hoy exclusivo de
productos agotados, spec 093) para que también cubra productos cuya categoría dejó de ser
visible en QR entre que se agregaron al carrito y que se intentó enviar:

```json
{
  "detail": {
    "error": "Algunos productos ya no están disponibles y se quitaron de tu carrito",
    "productos_no_disponibles": ["Ron Añejo 8oz", "Mojito Clásico"]
  }
}
```

**Efecto colateral del mismo `409`** (nuevo, a diferencia del caso de agotados): las filas de
`CartItem` correspondientes a esos productos se eliminan como parte de esta misma llamada —
`GET /cart` inmediatamente después ya no las incluye, sin que el comensal tenga que quitarlas a
mano (research.md, Decisión 5). Ningún pedido se crea en esta llamada; un segundo envío sin
esos productos puede proceder con normalidad.

## 4. Evento en tiempo real `menu.updated` (opcional — US3/FR-009, prioridad P3)

Si se implementa: evento delgado, sin payload relevante más allá del aviso mismo (mismo
principio que el resto del catálogo de `app/core/events.py`):

```json
{ "type": "menu.updated", "v": <int>, "at": "<iso8601>" }
```

Publicado en un canal nuevo que todo comensal con el menú QR abierto recibe (distinto del
`session_channel` por mesa ya existente — research.md, Decisión 6). El cliente, al recibirlo,
MUST volver a pedir `GET /menu` (o el endpoint QR equivalente) completo — no se envía ningún
diff de qué cambió.
