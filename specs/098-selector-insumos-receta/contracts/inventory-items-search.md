# Contrato: `GET /inventory/items` reutilizado por `InventoryService.searchActiveItems()`

Ámbito: `pos-heladeria` consumiendo un endpoint de `pos-backend` **ya existente y sin cambios**
(`app/api/v1/inventory/router.py:37-54`). Este documento no define un contrato nuevo — fija cómo
los cuatro selectores afectados lo consumen, para que los cuatro lo hagan de la misma forma
(research.md D1/D4).

## Petición

```text
GET /inventory/items?search={texto}&active=true&page=1&size=20
```

| Parámetro | Valor fijado por `searchActiveItems()` | Origen |
|---|---|---|
| `search` | `query.trim()` (texto escrito por el usuario) | Nuevo uso de un parámetro ya soportado por el backend |
| `active` | `true`, siempre | Nuevo uso — antes `allItems()` no lo enviaba (causa del síntoma secundario: insumos inactivos ofrecidos) |
| `page` | `1`, siempre | El picker nunca pagina más allá de la primera página de resultados; si hay más de 20 coincidencias, el usuario afina el texto |
| `size` | `20` | Igual que la solución propuesta en el reporte original |

Sin autenticación ni headers distintos a los que ya usa cualquier otra llamada de
`InventoryService` (token del tenant vía interceptor HTTP existente).

## Respuesta

Sin cambios de forma — el mismo `Page<InventoryItemResponse>` que ya devuelve este endpoint para
`itemsQuery`/`allItemsQuery`:

```jsonc
{
  "items": [
    { "id": "...", "name": "QUESO MOZARELA BLOQUE X 2500 GRAMOS", "unit_measure_id": "...", "type": "...", "current_stock": "11.250", "min_stock": "...", "unit_cost": "...", "active": true }
  ],
  "total": 1, "page": 1, "size": 20, "pages": 1
}
```

`searchActiveItems()` mapea `items[]` con el `toItem()` ya existente (mismo mapeo que usan
`items`/`allItems` hoy) y descarta `total`/`pages` — el picker no necesita navegar páginas, solo
mostrar la primera tanda de coincidencias (ver Edge Case de la spec: si hay más de 20, el usuario
escribe un texto más específico).

## Lo que NO cambia

- El router, el servicio y el modelo de `pos-backend` — cero líneas de backend tocadas por esta
  spec (research.md D1).
- `itemsQuery`/`allItemsQuery` (la tabla de Insumos y la carga de 100 para labels, `inventory.
  service.ts:129-143`) — siguen funcionando exactamente igual; `searchActiveItems()` es un método
  nuevo, independiente, que no reemplaza a ninguno de los dos (data-model.md, research.md D5).
- El tope `size<=100` del backend no se toca ni se alcanza nunca desde este picker, que siempre
  pide `size=20`.
