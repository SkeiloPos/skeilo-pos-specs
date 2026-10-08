# Contrato: `app-searchable-select` (extensión aditiva)

**Spec**: [../spec.md](../spec.md) · **Decisión**: [../research.md](../research.md) (D1)

`app-searchable-select` (`pos-heladeria/src/app/shared/searchable-select/searchable-select.component.ts`)
es un componente compartido por varias pantallas del panel de administración, no exclusivo del
formulario de producto. Esta corrección **no** reemplaza su contrato existente — lo extiende con
una única salida nueva, opcional, que ningún otro consumidor actual necesita escuchar.

## Contrato ya existente (sin cambios)

| Miembro | Tipo | Descripción |
|---|---|---|
| `@Input() options` | `SearchableSelectOption[]` | Opciones mostradas cuando no hay texto de búsqueda o cuando `search` no está provisto. |
| `@Input() placeholder` | `string` | Texto cuando no hay valor seleccionado. |
| `@Input() search` | `(query: string) => Promise<SearchableSelectOption[]>` (opcional) | Búsqueda remota (spec 098/102); si se provee, un texto no vacío consulta el servidor en vez de filtrar `options` localmente. |
| `[ngModel]` / `(ngModelChange)` (vía `ControlValueAccessor`) | `string` (id) | Valor seleccionado — solo el id, como hoy. |

Ningún consumidor existente (tablas/mesas — spec 053, Categorías, Presentaciones, Inventario,
Compras, Grupos de opciones, Promociones, y los propios selectores no tocados del formulario de
producto) necesita cambiar: siguen usando únicamente `options`/`search`/`[ngModel]` igual que hoy.

## Extensión nueva (aditiva)

| Miembro | Tipo | Descripción |
|---|---|---|
| `@Output() optionPicked` | `EventEmitter<SearchableSelectOption>` (nuevo, opcional) | Emite la opción completa (`{ id, label }`) en el momento en que el usuario la elige — ya sea de `options` (lista local) o de un resultado de `search` (búsqueda remota). Se emite **junto con**, no en reemplazo de, el `onChange(opt.id)` existente del `ControlValueAccessor`. |

**Quién lo usa**: únicamente los tres selectores del formulario de producto que esta spec toca
(categoría, presentación por fila, insumo por fila de receta/consumo). Ningún otro consumidor
listado en `research.md` ("Otros consumidores") necesita escuchar esta salida — pueden ignorarla
sin romper nada, porque es un `@Output()` adicional, no una señal que reemplace el flujo de
`ngModel` ya existente.

**Por qué aditivo y no un cambio al tipo de valor del `ngModel`**: cambiar `[ngModel]` de `string`
(id) a `{id, label}` rompería la implementación de `ControlValueAccessor` y a todos los
consumidores existentes que hacen `[ngModel]="algo.id"` esperando un string — una migración mucho
más amplia que el problema que esta spec resuelve (Principio V: sin refactorizaciones
oportunistas).

## Ejemplo de uso esperado (ilustrativo, no prescriptivo de la implementación exacta)

```html
<app-searchable-select
  [ngModel]="draft().category_id"
  (ngModelChange)="setField('category_id', $event)"
  (optionPicked)="onCategoryPicked($event)"
  [options]="categoryOptions()"
  [search]="searchCategories" />
```

```ts
onCategoryPicked(opt: SearchableSelectOption | null): void {
  this.draft.update((d) => ({
    ...d,
    category_name: opt?.label ?? '',
  }));
}
```

El mismo patrón aplica a `presentationOptionsFor`/`setVariantPresentation` (actualiza
`presentationName` de la fila) y al selector de insumo de cada fila de receta/consumo (empuja la
opción elegida a `InventoryService.resolvedExtraItems`, reutilizando `resolveMissingItems` cuando
el picker de insumos solo tiene `{id, label}` a mano, sin el `InventoryItem` completo).

## Qué NO cambia en este contrato

- El mecanismo de búsqueda remota (`search`, debounce de 300ms, `filteredOptions()`,
  `runRemoteSearch()`) — FR-005, sin cambios.
- El comportamiento de `filteredOptions()` cuando el texto está vacío: sigue devolviendo
  `this.options` tal cual (que, para los tres selectores de esta spec, ya no incluirá un catálogo
  precargado — ver FR-006 y Edge Cases del spec).
- `selectedLabel()`: sigue resolviendo el botón cerrado buscando el id en `options` — sigue
  funcionando porque `options` (vía `categoryOptions()`/`inventoryOptions()`/
  `presentationSelectOptionsFor()`) ahora incluye la entrada recién fijada por `optionPicked`,
  no porque el componente compartido cambie su lógica interna.
