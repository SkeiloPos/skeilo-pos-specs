# Contrato: `GET /categories` reutilizado por `CategoryService.searchActiveCategories()`

Ámbito: `pos-heladeria` consumiendo un endpoint de `pos-backend` **ya existente y sin cambios**
(`app/api/v1/categories/router.py`, handler `list_categories`). Este documento no define un
contrato nuevo — fija cómo el selector de categoría del formulario de producto lo consume, con el
mismo patrón que ya usa `InventoryService.searchActiveItems()` (ver
`../../098-selector-insumos-receta/contracts/inventory-items-search.md`).

## Petición

```text
GET /categories?search={texto}&active=true&page=1&size=20
```

| Parámetro | Valor fijado por `searchActiveCategories()` | Origen |
|---|---|---|
| `search` | `query.trim()` (texto escrito por el usuario) | Ya soportado por el backend (`search: str \| None = Query(None, ...)`), filtro `ilike` sobre `name` |
| `active` | `true`, siempre | Ya soportado por el backend (`active: bool \| None = Query(None, ...)`) |
| `page` | `1`, siempre | El picker nunca pagina más allá de la primera página; si hay más de 20 coincidencias, el usuario afina el texto |
| `size` | `20` | Mismo tamaño de página que `searchActiveItems()`, por consistencia (spec FR-009) |

Sin autenticación ni headers distintos a los que ya usa cualquier otra llamada de
`CategoryService` (token del tenant vía interceptor HTTP existente).

## Respuesta

Sin cambios de forma — el mismo `Page<Category>` que ya devuelve este endpoint para `allQuery`:

```jsonc
{
  "items": [
    { "id": "...", "name": "Postres", "active": true }
  ],
  "total": 1, "page": 1, "size": 20, "pages": 1
}
```

`searchActiveCategories()` mapea `items[]` tal cual (sin transformación adicional) y descarta
`total`/`pages` — el picker no necesita navegar páginas.

## Lo que NO cambia

- El router de `pos-backend` — cero líneas de backend tocadas por esta spec.
- `allQuery` (la carga de hasta 100 categorías para el selector por defecto y para
  `selectedLabel()`) — sigue funcionando exactamente igual; `searchActiveCategories()` es un método
  nuevo e independiente que no la reemplaza (ver `data-model.md`).
- El tope `size<=100` del backend no se toca ni se alcanza nunca desde este picker, que siempre
  pide `size=20`.
