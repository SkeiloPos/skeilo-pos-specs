# Contrato: API nueva (opt-in) de `app-searchable-select`

Ámbito: `pos-heladeria/src/app/shared/searchable-select/searchable-select.component.ts`. Documenta
la superficie **nueva** que agrega esta spec al componente compartido (research.md D2/D3), para
que los cuatro consumidores afectados —y cualquier consumidor futuro— la usen de forma consistente.
La API ya existente (`options`, `placeholder`, `id`, `ControlValueAccessor`) no cambia.

## Entrada nueva

```ts
@Input() search?: (query: string) => Promise<SearchableSelectOption[]>;
```

- **Ausente/`undefined`** (todos los consumidores actuales que no son de insumo, p. ej. el
  selector de mesa de `manual-order-page.component.ts`): comportamiento idéntico al de hoy, sin
  ningún cambio observable.
- **Presente**: cuando `query()` no está vacío, `filteredOptions()` devuelve el resultado de la
  última llamada a `search(query())` resuelta correctamente, en vez de filtrar `options`
  localmente. Cuando `query()` está vacío, se sigue devolviendo `options` tal cual (sin cambios).

No se agrega ningún otro `@Input` (no hay `remoteMode`/`debounceMs` configurables): el debounce
(300ms) y el comportamiento de carga/error están fijos e iguales para todo consumidor que use
`search`, por diseño (research.md D3) — así los cuatro selectores de insumo se comportan
idénticamente entre sí sin que cada archivo deba configurarlos por separado.

## Comportamiento observable nuevo (solo cuando `search` está presente)

| Situación | Lo que muestra la lista desplegable |
|---|---|
| Usuario deja de teclear (texto no vacío), petición en curso | Indicador de carga (p. ej. "Buscando…"), nunca "Sin resultados" (FR-005) |
| Petición resuelve con 0 coincidencias | "Sin resultados" (comportamiento ya existente, reutilizado) |
| Petición resuelve con N coincidencias | Esas N opciones, seleccionables igual que cualquier opción local |
| Petición rechaza (red/servidor) | Mensaje de error distinto de "Sin resultados", con control para reintentar la misma búsqueda (FR-006) |
| Usuario sigue tecleando antes de que resuelva una petición anterior | Solo se aplica la respuesta de la petición más reciente (guarda por secuencia, research.md D3); las respuestas de peticiones ya superadas se descartan en silencio |
| Usuario borra el texto | Vuelve a mostrar `options` (la lista por defecto que el consumidor ya pasaba) — sin cambios respecto a hoy |

`selectedLabel()` (etiqueta del botón cerrado) sigue leyendo únicamente `options`, nunca
`remoteResults` — ver research.md D2/D5 y spec FR-009.

## Consumidores que adoptan este contrato en esta spec

| Archivo | Picker | Historia |
|---|---|---|
| `products/pages/product-form.component.ts` | "Insumos fijos" de la receta | 1 (P1) |
| `option-groups/components/option-form.component.ts` | Insumo de una opción | 2 (P2) |
| `inventory/components/purchase-form.component.ts` | Insumo de cada línea de Compra | 2 (P2) |
| `inventory/pages/inventory-page.component.ts` | Insumo del tab "Movimientos" | 2 (P2) |

Los cuatro pasan el mismo `search` (una función que delega en
`InventoryService.searchActiveItems`, ver `contracts/inventory-items-search.md`) y siguen pasando
`options` exactamente como hoy (respaldado por `allItems()`, sin cambios — research.md D5).

## Consumidores que NO adoptan este contrato (sin cambios)

- `tables/pages/manual-order-page.component.ts` (selector de mesa): no pasa `search`; sigue
  filtrando localmente sobre la lista de mesas ya cargada, sin ningún cambio de comportamiento
  (FR-007).
