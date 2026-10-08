# Research: Quitar la precarga de catálogos completos en los selectores del formulario de producto

**Spec**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md)

Esta investigación confirma, leyendo el código real de `pos-heladeria`, qué se debe quitar
(FR-001/FR-002) y qué mecanismo ya existente resuelve FR-003 (nombre real del valor ya
seleccionado) sin esa precarga. También identifica dos riesgos técnicos que el spec no nombra
explícitamente pero que son consecuencia directa de aplicar FR-001/FR-002, y que este plan debe
resolver para no violar el Principio II de la Constitución (comportamiento existente protegido).

## Qué se quita (FR-001, FR-002)

Las tres llamadas de precarga se disparan desde un único punto:
`product-form.component.ts`, `ngOnInit()` (líneas 970-985):

```ts
await Promise.all([
  this.categoryService.allCategories().length === 0 ? this.categoryService.loadAllCategories() : null,
  this.inventoryService.allItems().length === 0 ? this.inventoryService.loadAllItems() : null,
  this.unitMeasureService.unitMeasures().length === 0 ? this.unitMeasureService.loadUnitMeasures() : null,
  this.optionGroupService.groups().length === 0 ? this.optionGroupService.loadGroups() : null,
  this.presentationService.allPresentations().length === 0 ? this.presentationService.loadAllPresentations() : null,
]);
```

**Decisión**: quitar únicamente las llamadas a `categoryService.loadAllCategories()`,
`inventoryService.loadAllItems()` y `presentationService.loadAllPresentations()` de este bloque.
`unitMeasureService.loadUnitMeasures()` y `optionGroupService.loadGroups()` quedan fuera de
alcance (no son los tres endpoints señalados en la captura del Input, y no tienen un endpoint de
búsqueda remota equivalente que los reemplace).

**Por qué no se tocan los servicios (`category.service.ts`, `presentation.service.ts`,
`inventory.service.ts`) ni sus señales `allCategories()`/`allPresentations()`/`allItems()`**: son
singletons `providedIn: 'root'` compartidos por otras pantallas que sí siguen necesitando la
precarga completa y la disparan de forma independiente (ver "Otros consumidores" más abajo). Quitar
la llamada únicamente desde `product-form.component.ts` no afecta a esas pantallas: cada una ya
tiene su propio guard `if (xxx().length === 0) loadXxx()` al montar.

## Decisión D1 — Nombre de un valor ya seleccionado vs. nombre de un valor recién elegido por búsqueda

### El mecanismo que ya existe para "valor ya guardado" (FR-003) — confirmado, no requiere cambios

- **Categoría**: `ProductResponse.category_name` (`product.service.ts`, resuelto en el servidor
  desde la spec 097) viaja en el detalle de producto y `getProductDraft()` lo mapea directo al
  `draft()`. `categoryOptions()` (`product-form.component.ts:589-598`) ya hace un *guard*: si
  `draft().category_id` no está en `allCategories()`, empuja `{ id, label: draft().category_name }`.
  Con `allCategories()` siempre vacío tras quitar la precarga, este guard pasa a ser la única
  fuente — funciona igual porque nunca dependió de que el id estuviera en la lista precargada.
- **Presentación**: mismo patrón con `presentationName` por variante
  (`presentationOptionsFor()`, líneas 620-634).
- **Insumos (receta y consumo de opción)**: `ProductDetailResponse` solo trae el id del insumo
  (`inventory_item_id`), no su nombre (a diferencia de categoría/presentación). El nombre se
  resuelve con `InventoryService.resolveMissingItems()` (`inventory.service.ts:212-229`),
  invocado una vez en `ngOnInit()` (línea ~1002) con los ids de receta/consumo del draft recién
  cargado — ya es la ruta que la spec 102 (Historia 1) introdujo precisamente para el caso "no
  está en la página precargada". Guarda el resultado en `resolvedExtraItems` (signal), combinado
  con `allItems()` por `combinedInventoryItems()` (líneas 555-560). Con `allItems()` siempre
  vacío, `resolveMissingItems()` pasa a resolver el 100% de los insumos de la receta (antes
  resolvía solo los que quedaban fuera de la página de 100), vía `GET /items/{id}` en paralelo
  — sigue siendo una sola tanda de peticiones en paralelo al abrir el formulario, no secuencial
  por fila.

**Conclusión**: FR-003 no requiere ningún mecanismo nuevo para el valor **ya guardado** de un
producto existente. Los tres mecanismos ya existen y ya fueron diseñados, en la spec 102, para
exactamente este caso.

### El problema real: el valor elegido por búsqueda *durante la sesión de edición actual*

`app-searchable-select` (`searchable-select.component.ts`) resuelve la etiqueta del botón cerrado
así (línea 118-120):

```ts
selectedLabel(): string {
  return this.options.find((o) => o.id === this.value())?.label ?? '';
}
```

`this.options` es el `@Input` que el padre pasa (`categoryOptions()` / `inventoryOptions()` /
`presentationSelectOptionsFor()`). Al **elegir** un resultado de la búsqueda remota,
`selectOption()` (línea ~242) solo emite el id:

```ts
selectOption(opt: SearchableSelectOption): void {
  if (opt.disabled) return;
  this.value.set(opt.id);
  this.onChange(opt.id);   // <- solo el id viaja al padre
  this.open.set(false);
}
```

El padre (`setField('category_id', $event)`, `setRecipeField(..., 'inventory_item_id', $event)`,
`setVariantPresentation(localId, presentationId)`) solo guarda el id — ninguno actualiza el campo
de nombre correspondiente (`category_name`, `presentationName`) ni empuja el insumo elegido a
`resolvedExtraItems`. Hoy esto es *casi* invisible porque, si el registro elegido estaba dentro de
la página precargada de 100, `categoryOptions()`/`inventoryOptions()` ya lo incluían y
`selectedLabel()` lo encontraba igual. Es decir: **ya existe hoy** este defecto latente para un
registro elegido por búsqueda que esté fuera de la página 100 (el mismo síntoma "Insumo…" que la
spec 102 corrigió para el caso "ya guardado", pero nunca para el caso "recién elegido"). Al quitar
la precarga (FR-001/FR-002), la página siempre está vacía, así que este caso deja de ser una
rareza (>100 registros) y pasa a ser el 100% de las selecciones hechas por búsqueda — rompería
visiblemente FR-005 ("buscar... y poder seleccionarlo") si no se corrige como parte de este mismo
cambio.

**Decisión**: extender `app-searchable-select` con una salida adicional, opcional y aditiva —
p. ej. `(optionPicked)` emitiendo el `SearchableSelectOption` completo (`{ id, label }`) elegido —
sin tocar el flujo existente de `ControlValueAccessor` (`registerOnChange`/`writeValue`), que
sigue intacto para todos los demás consumidores del componente. `ProductFormComponent` escucha esa
salida solo en los tres selectores que toca esta spec y actualiza, en el mismo evento, el campo de
nombre correspondiente:

- Categoría → además de `category_id`, también `category_name` = `opt.label` (reutiliza el guard
  de `categoryOptions()` ya descrito, que lee `draft().category_name`; no requiere lógica nueva de
  lectura, solo de escritura).
- Presentación de una fila → `setVariantPresentation` deja de buscar el nombre en
  `presentationService.allPresentations().find(...)` (que con la precarga quitada casi nunca
  encontrará nada) y en su lugar recibe el nombre directo del `opt` elegido.
- Insumo de una fila de receta/consumo → el id elegido se registra inmediatamente en
  `inventoryService.resolvedExtraItems` reutilizando `resolveMissingItems([opt.id])` (ya existe,
  ya hace `GET /items/{id}` en caso de no conocerlo) **o**, más barato, si `searchActiveItems` ya
  devolvió el registro completo (`InventoryItem`, no solo `{id,label}`) para esa búsqueda, se
  empuja directo a `resolvedExtraItems` sin una petición nueva — evita una llamada redundante
  inmediatamente después de la búsqueda que ya trajo el dato.

**Alternativas consideradas**:

- *Resolver el nombre con una petición nueva por id justo después de cada selección* (reusar
  siempre `resolveMissingItems`/un endpoint `GET /{entidad}/{id}` equivalente para categoría y
  presentación). Rechazada como camino por defecto: desperdicia una petición que la búsqueda que
  el usuario ya disparó manualmente acaba de responder, e introduce un parpadeo perceptible justo
  después de elegir (contradice FR-010, "sin demora perceptible"). Queda como repuesto válido solo
  para insumos cuando el picker no tiene a mano el objeto completo devuelto por la búsqueda.
- *Mantener una precarga "disfrazada"* (p. ej. un `size=20` en vez de `size=100`, o dispararla en
  segundo plano sin bloquear el render). Rechazada: contradice directamente el Input del usuario
  ("remover el llamado") y la captura de pantalla que identifica las tres peticiones exactas a
  eliminar — no es una cuestión de tamaño de página, es la precarga en sí.

## Decisión D2 — `hasFreePresentations()` también depende de la señal que se deja de precargar

`hasFreePresentations()` (`product-form.component.ts:654-657`) decide qué mensaje mostrar al
Administrador cuando un tamaño todavía no tiene presentación asignada:

```ts
readonly hasFreePresentations = computed(() => {
  const used = new Set(this.draft().variants.map((v) => v.presentationId));
  return this.presentationService.allPresentations().some((p) => p.active && !used.has(p.id));
});
```

Usado en la plantilla (línea 205) para alternar entre "Elige una presentación" y "No hay más
presentaciones disponibles: créalas en Presentaciones". No está mencionado en el Input original ni
en el spec 105 (su alcance textual son los tres selectores de búsqueda), pero depende exactamente
de la señal (`allPresentations()`) que FR-002 obliga a dejar sin precargar — sin un ajuste,
quedaría siempre en `false` (arreglo vacío ⇒ `.some()` nunca es verdadero), mostrando siempre "No
hay más presentaciones disponibles" aunque sí las haya. Es una violación del Principio II
(comportamiento existente protegido) si no se atiende, pero **no** es una decisión de negocio que
requiera entrada en `registro-de-anomalias.md`: ningún criterio de qué presentación es válida
cambia, solo la fuente de datos de un cálculo que ya existía.

**Decisión**: calcular `hasFreePresentations()` con una verificación puntual y liviana —
reutilizando `presentationService.searchActivePresentations('')` (ya existente, ya usado por el
picker de la misma fila) en vez de la lista precargada completa — disparada de forma perezosa
(cuando el formulario necesita mostrar ese mensaje, no en `ngOnInit`), y no como una nueva
precarga eager al abrir el formulario. El resultado se compara contra los `presentationId` ya
usados por las demás filas, igual que hoy.

**Alternativas consideradas**:

- *No tocarlo y aceptar el mensaje incorrecto como regresión conocida*. Rechazada: el Principio II
  no permite dejar una regresión de comportamiento sin que el spec la autorice explícitamente, y
  esta spec no la menciona como cambio aceptado.
- *Devolver `allCategories()`/`allPresentations()` a una precarga "ligera" solo para este cálculo*.
  Rechazada por la misma razón que en Decisión D1: reintroduce la precarga que el Input pide
  eliminar, solo que camuflada para un propósito distinto.

## Otros consumidores de `allCategories()`/`allItems()`/`allPresentations()` (confirmación de que no se rompen)

Cada uno dispara su propia carga de forma independiente al montar su propia página/componente —
no dependen de que `product-form.component.ts` la haya disparado antes:

| Consumidor | Archivo | Señal/carga usada |
|---|---|---|
| Página de Categorías | `categories/pages/categories-page.component.ts:187-188` | `loadAllCategories()` |
| Formulario de Categoría (picker de presentación) | `categories/components/category-form.component.ts:194-201,234` | `loadAllPresentations()`, `allCategories()` |
| Página de Presentaciones | `presentations/pages/presentations-page.component.ts:237-238,282` | `loadAllPresentations()` |
| Página de Inventario (ajuste de stock/kardex) | `inventory/pages/inventory-page.component.ts:431,435,447` | `loadAllItems()` |
| Formulario de Compras | `inventory/components/purchase-form.component.ts:153,184` | `loadAllItems()` |
| Página y formulario de Grupos de opciones | `option-groups/pages/option-groups-page.component.ts:161,186`, `.../components/option-form.component.ts:129,148,161-164` | `loadAllItems()` |
| Página de Promociones | `promotions/pages/promotions-page.component.ts:1542,1621,1623,2031` | `loadAllCategories()`, `loadAllPresentations()` |

Ninguno requiere cambios: siguen funcionando exactamente igual (FR-008, SC-005).

## Resumen de decisiones

| # | Decisión | Alcance |
|---|---|---|
| D1 | `app-searchable-select` gana una salida opcional `(optionPicked)`; los tres selectores de `ProductFormComponent` la usan para fijar el nombre del valor recién elegido sin depender de la precarga ni de una petición nueva | `searchable-select.component.ts` (aditivo), `product-form.component.ts` |
| D2 | `hasFreePresentations()` se recalcula con una verificación puntual vía `searchActivePresentations('')`, no con `allPresentations()` | `product-form.component.ts` |
