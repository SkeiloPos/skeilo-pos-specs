# Contrato: `GET /inventory/items/{item_id}` reutilizado por `InventoryService.resolveMissingItems()`

Ámbito: `pos-heladeria` consumiendo un endpoint de `pos-backend` **ya existente y sin cambios**
(`app/api/v1/inventory/router.py:86`, "Obtener un insumo"). Fija cómo se resuelve el nombre real de
un insumo ya referenciado por una receta o un detalle de opción, cuando ese insumo no está dentro
de la página de hasta 100 que carga `allItems()` (research.md D1).

## Petición

```text
GET /inventory/items/{item_id}
```

Una petición por cada id que falte (en paralelo, `Promise.all`), disparada **una sola vez** por
apertura del formulario de edición, solo para los ids que no estén ya en `allItems()` ni en
`resolvedExtraItems()`. Sin autenticación ni headers distintos a los que ya usa cualquier otra
llamada de `InventoryService`.

## Respuesta

Sin cambios de forma — el mismo `InventoryItemResponse` que ya devuelve este endpoint:

```jsonc
{ "id": "...", "name": "QUESO MOZARELA BLOQUE X 2500 GRAMOS", "unit_measure_id": "...", "type": "...", "current_stock": "11.250", "min_stock": "...", "unit_cost": "...", "active": true }
```

`resolveMissingItems()` mapea cada respuesta con el `toItem()` ya existente (mismo mapeo que usan
`items`/`allItems` hoy) y la agrega a `resolvedExtraItems`.

## Qué pasa si el insumo ya no existe o el id es inválido (404)

El insumo no se agrega a `resolvedExtraItems`; el selector sigue mostrando el placeholder genérico
únicamente para ese id puntual (caso residual, no cubierto por los escenarios de aceptación de la
spec, que asumen que el id guardado siempre corresponde a un insumo existente — ver spec,
Assumptions).

## Lo que NO cambia

- El router y el servicio de `pos-backend` — cero líneas de backend tocadas por esta spec.
- `allItems()`/`allItemsQuery` (`inventory.service.ts:133-140`) — no cambian; `resolveMissingItems`
  es un método independiente que complementa, no reemplaza, la fuente de `inventoryOptions()`/
  `unitLookup` (ver `data-model.md`).
- `selectedLabel()` de `searchable-select.component.ts` — sigue sin conocer este mecanismo; solo lee
  `options`, que ya viene enriquecido por el consumidor (research.md D1).
