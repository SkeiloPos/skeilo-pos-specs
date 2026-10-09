# Contrato: `GET /presentations` reutilizado por `PresentationService.searchActivePresentations()`

Ámbito: `pos-heladeria` consumiendo un endpoint de `pos-backend` **ya existente y sin cambios**
(`app/api/v1/presentations/router.py`, handler `list_presentations`). Mismo patrón que
`CategoryService.searchActiveCategories()` (`categories-search.md`) e
`InventoryService.searchActiveItems()` (spec 098).

## Petición

```text
GET /presentations?search={texto}&active=true&page=1&size=20
```

| Parámetro | Valor fijado por `searchActivePresentations()` | Origen |
|---|---|---|
| `search` | `query.trim()` (texto escrito por el usuario) | Ya soportado por el backend, filtro `ilike` sobre `name` |
| `active` | `true`, siempre | Ya soportado por el backend |
| `page` | `1`, siempre | El picker nunca pagina más allá de la primera página |
| `size` | `20` | Mismo tamaño de página que los otros dos selectores (spec FR-009) |

Sin autenticación ni headers distintos a los que ya usa cualquier otra llamada de
`PresentationService`.

## Respuesta

Sin cambios de forma — el mismo `Page<Presentation>` que ya devuelve este endpoint para `allQuery`:

```jsonc
{
  "items": [
    { "id": "...", "name": "Pequeño 8 onz", "active": true }
  ],
  "total": 1, "page": 1, "size": 20, "pages": 1
}
```

## Lo que NO cambia

- El router de `pos-backend` — cero líneas de backend tocadas por esta spec.
- `allQuery` (la carga de hasta 100 presentaciones para el selector por defecto) — sigue
  funcionando exactamente igual; `searchActivePresentations()` es un método nuevo e independiente.
- El resguardo ya existente en `presentationOptionsFor()` que inyecta la presentación ya elegida de
  una variante aunque haya quedado fuera de `allPresentations()` (`product-form.component.ts:598-600`,
  usando `v.presentationName` ya denormalizado en el draft) **no cambia** — sigue aplicándose igual
  de la misma forma, independiente de la búsqueda nueva (research.md D3/D4).
- El tope `size<=100` del backend no se toca ni se alcanza nunca desde este picker.
