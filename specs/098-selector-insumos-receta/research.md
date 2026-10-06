# Research: Corrección — los selectores de insumo no encuentran insumos existentes fuera de los primeros 100

## D1 — Reutilizar el endpoint y los parámetros que ya usa Inventario → Insumos, sin tocar el backend

**Decisión**: agregar `InventoryService.searchActiveItems(query: string): Promise<InventoryItem[]>`
(`inventory.service.ts`), implementado como una llamada directa a la función privada ya existente
`fetchItemsPage(page, size, search, type, active, lowStock)` (`inventory.service.ts:157-165`), con
`page=1`, `size=20`, `search=query.trim()`, `type=''`, `active='active'`, `lowStock=false`, y
mapeando la respuesta con el `toItem()` ya existente (`:397`).

**Rationale**:
- `GET /inventory/items` (`pos-backend/app/api/v1/inventory/router.py:37-54`) ya acepta `search`
  (`ilike` case-insensitive sobre `name`, `service.py:36`), `active` (`service.py:39`), `page` y
  `size` (`le=100`) — exactamente los parámetros que pide la solución propuesta del reporte
  original (`?search=&active=true&page=1&size=20`). No hay ningún cambio de backend que hacer.
- Llamar a la misma función privada `fetchItemsPage()` que ya usa `itemsQuery` (la tabla de
  Insumos) garantiza por construcción el requisito FR-002 ("mismas reglas de búsqueda que
  Inventario"): es literalmente la misma petición HTTP con los mismos parámetros, no una
  reimplementación paralela que podría divergir con el tiempo.
- `size=20` (no 100) es intencional: esta llamada se dispara en cada tecleo (con debounce, D3), así
  que una página pequeña reduce payload y tiempo de respuesta; el usuario puede seguir escribiendo
  para acotar más si hay más de 20 coincidencias — consistente con la Assumption del spec sobre el
  tamaño de página.

**Alternatives considered**:
- **Agregar un endpoint nuevo `/inventory/items/search` dedicado a pickers**. Rechazada: no aporta
  nada sobre reutilizar `GET /inventory/items?search=&active=true` ya existente; viola el
  Principio IX (dependencias/superficie nueva sin justificación) al duplicar un contrato que ya
  resuelve el problema.
- **Subir el tope de `allItems()` de 100 a un número más alto (p. ej. 1000) para que la mayoría de
  tenants quepan en una sola carga**. Rechazada: no resuelve el problema de fondo (sigue habiendo
  un límite fijo que algún tenant eventualmente supera, igual que categorías en spec 097) y no
  resuelve el filtro `active` ausente; solo retrasa el síntoma.

## D2 — Modo de búsqueda remota opt-in en `SearchableSelectComponent`, no un componente nuevo

**Decisión**: agregar `@Input() search?: (query: string) => Promise<SearchableSelectOption[]>` a
`searchable-select.component.ts`. `filteredOptions()` cambia a:

```ts
filteredOptions(): SearchableSelectOption[] {
  const q = normalizeText(this.query());
  if (!q) return this.options;                 // sin texto: comportamiento actual, sin cambios
  if (this.search) return this.remoteResults(); // con texto Y modo remoto: resultados del servidor
  return this.options.filter((o) => normalizeText(o.label).includes(q)); // comportamiento actual
}
```

`remoteResults` es un `signal<SearchableSelectOption[]>` actualizado por `onQueryInput()` (D3).
`selectedLabel()` (resuelve la etiqueta del valor ya seleccionado para el botón cerrado) **no
cambia**: sigue leyendo `this.options`, que los cuatro consumidores siguen alimentando con
`allItems()` igual que hoy — así que un insumo ya seleccionado (venga de donde venga) sigue
mostrando su nombre en el botón cerrado sin depender del modo remoto.

**Rationale**:
- Es un cambio aditivo y opt-in: los consumidores que no pasan `[search]` (selector de mesa en
  `manual-order-page.component.ts`, y cualquier otro uso futuro de `app-searchable-select`) no
  cambian de comportamiento en absoluto — satisface FR-007 y el Principio II (comportamiento
  existente protegido) sin necesidad de un flag booleano aparte (`remoteSearch`): la sola presencia
  de la función ya basta como interruptor.
- Reutiliza `options` para dos propósitos distintos sin conflicto: lista por defecto (texto vacío,
  igual que hoy, FR-007/Edge Case "borrar el texto") y resolución de etiqueta del valor ya
  seleccionado (`selectedLabel()`, fuera de alcance por FR-009) — ninguno de los dos requiere que
  `options` contenga el insumo que se está buscando ahora.
- Un componente nuevo (`app-searchable-select-remote` o similar) duplicaría ~150 líneas
  (navegación por teclado, `ControlValueAccessor`, cierre al hacer click fuera) solo para cambiar
  una función — viola el Principio V (no refactor/duplicación oportunista).

**Alternatives considered**:
- **`@Output() queryChange` y dejar que cada uno de los 4 consumidores maneje su propio debounce,
  estado de carga y de error**. Rechazada: duplica la misma lógica de debounce/loading/error en 4
  archivos distintos (receta, opciones, compras, movimientos) en vez de centralizarla una sola vez
  en el componente compartido que ya la necesita — más superficie para que alguno de los 4 la
  implemente de forma distinta a los otros tres, justo el tipo de inconsistencia que FR-002 busca
  evitar.
- **Reemplazar por completo `options` con los resultados remotos** (en vez de usarlos solo cuando
  hay texto). Rechazada: rompería `selectedLabel()` y la lista por defecto al abrir el selector sin
  haber escrito nada (Edge Case "borrar el texto"), obligando a los 4 consumidores a replicar la
  carga inicial de 100 solo para ese caso — el diseño elegido ya cubre ambos casos sin duplicar
  nada.

## D3 — Debounce, carga y error centralizados en el componente, con guarda de respuestas fuera de orden

**Decisión**: dentro de `searchable-select.component.ts`:
- `onQueryInput(v)` sigue actualizando `query` de inmediato (para que el campo de texto no se
  sienta con lag), pero si `this.search` está presente programa un `setTimeout` de 300ms (mismo
  valor que ya usa `inventory-page.component.ts:464-468`) antes de invocar `this.search(v)`,
  cancelando cualquier timer pendiente anterior — mismo patrón ya probado en este código base, solo
  centralizado una vez.
- Mientras la promesa está en curso, `loading` (signal interno) es `true`; la plantilla muestra un
  renglón "Buscando…" en vez de "Sin resultados" (Edge Case, FR-005: nunca mostrar "Sin
  resultados" por una respuesta que aún no llegó).
- Cada llamada incrementa un contador interno `searchSeq`; al resolver la promesa, el resultado
  solo se aplica (`remoteResults.set(...)`, `loading.set(false)`) si su id sigue siendo el más
  reciente — evita que una respuesta lenta de una búsqueda vieja sobreescriba el resultado de una
  búsqueda más nueva (tecleo rápido).
- Si la promesa rechaza, `error` (signal interno) guarda el mensaje; la plantilla muestra ese
  mensaje con un control de "Reintentar" que vuelve a invocar `this.search(query())` con el mismo
  texto (FR-006).

**Rationale**: centralizar esto una sola vez, en el componente que todos comparten, es lo que
permite que los 4 consumidores no repitan la misma lógica (D2) y es exactamente el comportamiento
que pide la spec (Clarifications: error distinto de "Sin resultados", con reintentar). La guarda
por secuencia es el mecanismo estándar y más simple para "última respuesta gana" con `Promise`,
sin necesitar cancelación real de la petición HTTP en curso (un `AbortController` sería más
"correcto" pero innecesario: la petición vieja igual se completa y se descarta, sin efecto visible
ni fuga de recursos relevante a esta escala).

**Alternatives considered**:
- **`AbortController` para cancelar la petición HTTP anterior de verdad**. Rechazada por
  complejidad innecesaria: `HttpClient` lo soporta, pero exige propagar la señal a través de
  `fetchItemsPage()`/`firstValueFrom()` solo para un beneficio marginal (ahorrar una petición ya en
  vuelo) frente a la guarda por secuencia, que ya evita el único efecto observable que importa
  (pisar un resultado nuevo con uno viejo).
- **RxJS `switchMap` sobre un `Subject` de texto** (patrón más idiomático en Angular/RxJS para
  typeahead). Rechazada únicamente por consistencia: el resto de `InventoryService` y de este
  componente ya está migrado a signals (`computed`, `signal`), no a Observables expuestos
  directamente; introducir un `Subject` aquí sería el único punto del componente con ese estilo,
  sin necesidad real (la guarda por secuencia logra el mismo resultado con signals puros).

## D4 — Los otros tres selectores (opciones, compras, movimientos) reciben el mismo tratamiento, sin variantes

**Decisión**: `option-form.component.ts`, `purchase-form.component.ts` e
`inventory-page.component.ts` (tab Movimientos) pasan `[search]="searchInventoryItems"` al mismo
`<app-searchable-select>` que ya usan, donde `searchInventoryItems` es un método/arrow que llama a
`this.inventoryService.searchActiveItems(q)` y mapea a `SearchableSelectOption[]` — la misma firma
en los cuatro archivos, sin variantes por pantalla.

**Rationale**: los cuatro puntos comparten exactamente la misma causa raíz (spec, "Causa raíz") y
exactamente el mismo contrato de datos (`InventoryItem` con `id`/`name`), así que no hay ninguna
razón de negocio ni técnica para que se comporten distinto entre sí — tratarlos todos igual es lo
que exige FR-001/FR-002 ("cada selector de insumo DEBE...") y evita que, dentro de un año, alguien
copie el patrón viejo (`allItems()` como fuente del picker) en una quinta pantalla porque las
cuatro existentes no eran consistentes entre sí.

**Alternatives considered**:
- **Extraer un `InventoryItemPickerComponent` de más alto nivel que envuelva
  `app-searchable-select` + `searchInventoryItems`, para no repetir el método mapper en 4
  archivos**. Considerada razonable, pero diferida: el mapper es una línea (`items =>
  items.map(i => ({id: i.id, label: i.name}))`), y cada uno de los 4 consumidores ya tiene su propio
  manejo del valor seleccionado (receta con cantidad, opción con cantidad, compra con costo
  unitario, movimiento con tipo); envolver eso en un componente nuevo agrega una capa de
  indirección para ahorrar una línea de mapeo — no se justifica por la complejidad real que resuelve
  (Principio V). Puede revisitarse si aparece un quinto consumidor.

## D5 — Qué NO cambia: `allItems()`/`loadAllItems()`, y la resolución de nombre/unidad de filas ya guardadas

**Decisión**: `allItems()`, `loadAllItems()`, `buildUnitLookup()` y los `Map`/`.find()` que los 4
archivos ya construyen sobre `allItems()` para resolver el nombre/unidad de un insumo **ya
seleccionado** (filas existentes de receta/opción/compra, y los defaults como
`product-form.component.ts:1156`) permanecen exactamente como están.

**Rationale**: spec FR-009 excluye explícitamente de esta corrección la resolución de
nombre/unidad para filas ya guardadas — es un defecto cosmético distinto (mismo patrón de causa
raíz, pero sin bloquear ninguna acción) que el negocio decidió dejar fuera de alcance al planear
(spec, "Alcance ampliado", punto 5). Tocar `allItems()` para resolver también ese caso ampliaría el
diff a un problema que no estaba autorizado para esta spec (Principio VI, evolución incremental) y
que no tiene un reporte de bug que lo respalde.

**Alternatives considered**:
- **Reemplazar `allItems()` por completo con una caché que se construye a demanda a partir de los
  ids realmente referenciados por cada formulario** (sin tope de 100, sin carga adelantada).
  Rechazada para esta spec: resolvería también el defecto cosmético (FR-009), pero es un cambio de
  mayor alcance que toca los 4 archivos en un eje distinto (cómo se resuelven labels de filas
  existentes, no cómo se buscan insumos nuevos) — queda documentado aquí como candidato para una
  spec de corrección independiente si el negocio decide abordar el punto 5 del "Alcance ampliado"
  más adelante.

## Limitación heredada, no introducida por esta corrección

`InventoryItem.name.ilike(f"%{search}%")` (`pos-backend/app/api/v1/inventory/service.py:36`) es
sensible a tildes (no usa `unaccent` ni una columna normalizada) — buscar "jamon" no encuentra
"Jamón" en el servidor, a diferencia del filtrado local actual (`normalizeText()`, que sí quita
tildes). Esto **ya es el comportamiento de Inventario → Insumos hoy** (mismo `ilike`, mismo
endpoint); FR-002 pide deliberadamente que los 4 selectores se comporten igual que Inventario, así
que esta corrección **hereda** esa limitación en vez de introducirla o corregirla — corregirla
(p. ej. con `unaccent` de PostgreSQL) sería un cambio de backend fuera del alcance de esta spec,
que ninguna de las dos historias de usuario pide.
