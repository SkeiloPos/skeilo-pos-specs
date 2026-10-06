# Data Model: Corrección — los selectores de insumo no encuentran insumos existentes fuera de los primeros 100

Sin cambios de esquema de base de datos ni de contrato persistido: `Insumo`, `Receta de
producto/Insumo fijo`, `Opción de grupo de opciones`, `Línea de Compra` y `Movimiento de
inventario` (spec, "Key Entities") ya existen y no ganan columnas, tablas ni relaciones nuevas.
Esta corrección solo introduce **estado transitorio de UI** (no persistido, vive mientras el
selector está abierto) y un método de servicio que no guarda nada nuevo.

## Estado transitorio del picker remoto (`SearchableSelectComponent`, D2/D3 de `research.md`)

No es una entidad de dominio ni se persiste; se documenta aquí porque gobierna el comportamiento
observable de los cuatro selectores afectados.

| Campo (signal interno) | Tipo | Vive mientras... | Notas |
|---|---|---|---|
| `query` | `string` | el selector está abierto | Ya existe hoy; sin cambios |
| `remoteResults` | `SearchableSelectOption[]` | hay texto Y se proveyó `search` | Nuevo (D2). Reemplaza el filtrado local solo en ese caso; vacío mientras no hay búsqueda remota en curso o completada |
| `loading` | `boolean` | la promesa de `search(query)` está pendiente | Nuevo (D3). Evita mostrar "Sin resultados" prematuramente (FR-005) |
| `error` | `string \| null` | la última llamada a `search(query)` rechazó | Nuevo (D3). Se limpia al reintentar o al cambiar el texto; distinto del estado "sin resultados" (FR-006) |
| `searchSeq` | `number` (contador interno) | — | Nuevo (D3). Guarda contra respuestas fuera de orden; no observable desde la plantilla |

Transiciones (por selector individual, no hay estado compartido entre instancias — cada
`<app-searchable-select>` abierto tiene su propia copia):

```text
texto vacío ──(escribir)──> debounce 300ms ──> loading=true
                                                   │
                                   resuelve ───────┼─────── rechaza
                                     │                          │
                         remoteResults=[...]              error="mensaje"
                         loading=false                     loading=false
                                     │                          │
                              (reintentar) ───────────────────> loading=true (repite)

remoteResults/error ──(borrar texto)──> vuelve a "texto vacío" (muestra `options` por defecto, sin cambios respecto a hoy)
```

## `SearchableSelectOption` (`searchable-select.component.ts`, ya existente)

Sin cambios de forma — `{ id: string; label: string; disabled?: boolean }`. Los resultados remotos
se mapean a esta misma forma antes de llegar al componente (en cada uno de los 4 consumidores, vía
`InventoryService.searchActiveItems`).

## `InventoryService.searchActiveItems(query)` (nuevo método, D1 de `research.md`)

No introduce un tipo nuevo: reutiliza `InventoryItem` (interfaz ya existente,
`inventory.interface.ts`) y `Page<InventoryItemResponse>` (ya existente,
`page.interface.ts`/`inventory.service.ts`). Firma:

| Entrada | Tipo | Notas |
|---|---|---|
| `query` | `string` | Texto tal cual lo escribió el usuario; se recorta (`.trim()`) antes de enviarse como `search` |

| Salida | Tipo | Notas |
|---|---|---|
| `Promise<InventoryItem[]>` | — | Siempre `active=true`, `page=1`, `size=20` (research.md D1); mapeado con el `toItem()` ya existente, sin campos nuevos |

No hay reglas de validación nuevas ni transiciones de estado de dominio: es una lectura de solo
consulta sobre un recurso (`InventoryItem`) cuyo ciclo de vida no cambia con esta corrección.
