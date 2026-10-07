# Contrato: variantes de producto y menú público — campos `name` / `display_name`

Ámbito: `pos-backend`, `app/api/v1/catalog/`, `app/api/v1/products/`, `app/api/v1/menu/`. Ningún
método, ruta ni código de estado existente cambia; se agregan campos a cuerpos ya existentes y una
nueva causa de error 409 al guardar.

## Escritura: `POST`/`PATCH`/`PUT /products`, `POST`/`PATCH /variants/{id}`

`VariantCreate`, `VariantUpdate` y `VariantSaveIn` (la entrada de cada presentación dentro del
árbol de `/products`) ganan un campo opcional:

```jsonc
// Antes
{ "presentation_id": "9f1b...", "price": 18000, "sku": "FRB-GDE" }

// Después
{ "presentation_id": "9f1b...", "price": 18000, "sku": "FRB-GDE", "name": "Para compartir" }
```

- **`name`** (`string`, opcional, 0-60 caracteres): ausente, `null` o cualquier texto se normaliza
  con la regla de [variant-name-rules.md](./variant-name-rules.md) — nunca produce un error por
  estar ausente (Escenario 14), solo por superar 60 caracteres (Escenario 8).
- Ningún otro campo cambia de forma ni de obligatoriedad. `presentation_id` sigue siendo la fuente
  estructural del tamaño (sin cambios).

### Error nuevo: longitud (422, ya en el formato estándar de Pydantic)

```jsonc
{ "detail": [{ "loc": ["body", "variants", 1, "name"], "msg": "Value error, El nombre admite hasta 60 caracteres", "type": "value_error" }] }
```

### Error nuevo: nombre duplicado dentro del producto (409)

```jsonc
{ "detail": { "error": "Ya existe un tamaño con ese nombre en este producto", "variant_index": 2 } }
```

A propósito **sin** `variant_id` — a diferencia del 409 de "presentación en uso"
(`_raise_presentation_conflict`), que sí lo trae porque ese conflicto ofrece un flujo de
"restaurar la variante desactivada". Este conflicto no tiene esa salida (ya excluye variantes
desactivadas de la comparación — research.md D5), así que no debe activar ese flujo en el cliente.
Solo compara contra variantes **activas** del mismo producto, insensible a mayúsculas, sobre el
`display_name` resultante (no sobre `name` crudo): un nombre propio puede chocar con el nombre de
la presentación que ya usa otra variante sin nombre, y viceversa (Escenario 9).

## Lectura: `GET /products`, `GET /products/{id}`, respuestas de los tres métodos de escritura

`VariantResponse`/`VariantSaveOut` ganan dos campos de solo lectura:

```jsonc
// Antes
{ "id": "...", "presentation_id": "9f1b...", "presentation_name": "Grande 16 onz", "price": 18000, "active": true }

// Después
{ "id": "...", "presentation_id": "9f1b...", "presentation_name": "Grande 16 onz", "name": "Para compartir", "display_name": "Para compartir", "price": 18000, "active": true }
```

- **`name`**: el valor crudo guardado (puede ser `""`).
- **`display_name`**: el calculado (data-model.md) — `name` si no es `""`, si no
  `presentation_name`, si ninguno está disponible `"Tamaño"`.
- `presentation_name` **no cambia de significado ni se retira** — sigue siendo el nombre de la
  presentación asociada, con o sin nombre propio.

## Menú público: `GET /menu` (o equivalente consumido por el frontend de comensal)

`MenuVariantResponse` gana `display_name` (no `name`: el menú público nunca necesitó el valor
crudo, solo la etiqueta final):

```jsonc
// Antes
{ "id": "...", "presentation_id": "9f1b...", "presentation_name": "Grande 16 onz", "price": 18000, "...": "..." }

// Después
{ "id": "...", "presentation_id": "9f1b...", "presentation_name": "Grande 16 onz", "display_name": "Para compartir", "price": 18000, "...": "..." }
```

`display_name` es la etiqueta que el detalle del producto, el carrito y el resumen de checkout
deben mostrar (FR-006). El texto de condición de las promociones que trae el propio menú también
usa `display_name` en vez de `presentation_name` (research.md D10) — sin eso, la insignia de una
promoción mostraría el nombre de la presentación aunque el resto de la pantalla ya muestre el
nombre propio.

## Lo que NO cambia

- `presentation_id`/`presentation_name` siguen presentes y con el mismo significado en todas las
  respuestas — `name`/`display_name` son **adicionales**, no un reemplazo (Escenario 15: un
  frontend en caché de una versión anterior sigue leyendo `presentation_name` sin errores).
- `GET /categories`, `GET /presentations` y cualquier endpoint fuera de productos/variantes/menú no
  se tocan.
- El texto de línea que se **persiste** en un pedido/venta al finalizar el pago
  (`format_item_description`, usado por `orders/checkout.py` y `sales/service.py`) sigue leyendo
  `presentation_name` — fuera de alcance a propósito (research.md D11). Órdenes y Ventas no
  exponen `name`/`display_name` en ningún endpoint.
- Ningún endpoint de `GET /categories`-style paginado cambia su contrato de paginación.
