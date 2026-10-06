# Contrato: `GET /products`, `GET /products/{id}` — campo `category_name`

Ámbito: `pos-backend`, `app/api/v1/products/`. Ningún método, ruta ni código de estado cambia;
solo se agrega un campo a los cuerpos de respuesta ya existentes.

## `GET /products` (listado, paginado)

Sin cambios en query params, autenticación ni paginación. Cada ítem de `items[]` gana
`category_name`:

```jsonc
// Antes
{
  "items": [
    { "id": "...", "category_id": "9f1b...", "name": "Fresa boom", "...": "..." }
  ],
  "total": 134, "page": 1, "size": 20, "pages": 7
}

// Después
{
  "items": [
    { "id": "...", "category_id": "9f1b...", "category_name": "Postres fríos", "name": "Fresa boom", "...": "..." }
  ],
  "total": 134, "page": 1, "size": 20, "pages": 7
}
```

`category_name` llega resuelto **sin importar cuántas categorías tenga el tenant** — no depende
de haber paginado `GET /categories` hasta encontrar la fila correspondiente (criterio de
aceptación 1 y 2 del spec).

## `GET /products/{id}` (detalle)

Mismo campo nuevo, mismo origen. `category_name` se agrega al cuerpo ya existente de
`ProductDetailResponse` (que además trae `variants[]`, sin cambios).

## `POST`/`PATCH`/`PUT /products`, `PATCH /products/{id}/availability`

Las cuatro respuestas de escritura (`ProductSaveResponse`/`ProductResponse`) también ganan
`category_name` de forma consistente, por heredar de la misma clase base — ningún cliente que lea
la respuesta de un guardado necesita una llamada aparte para mostrar la categoría actualizada.

## Lo que NO cambia

- `GET /categories` — mismo contrato, misma paginación (`size` máximo 100). Lo siguen usando el
  selector del formulario de producto, el filtro de promociones y la pantalla de Categorías.
- `category_id` sigue presente y sin cambios en todas las respuestas — `category_name` es
  **adicional**, no un reemplazo.
- Ningún campo nuevo se acepta en `ProductCreate`/`ProductUpdate`: `category_name` es de solo
  lectura; para cambiar la categoría de un producto se sigue enviando `category_id`.
