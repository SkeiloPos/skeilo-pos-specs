# Contrato (delta): endpoints de importación masiva de inventario e historial de movimientos

No se introduce ningún endpoint nuevo ni se cambia la forma de petición/respuesta de los
endpoints ya existentes (spec 109). Este documento describe únicamente lo que cambia en el
**resultado observable** de los endpoints ya documentados.

## `POST /inventory/items/import`, `GET /inventory/items/import/{job_id}`, `GET /inventory/items/import/current`

Sin cambios de forma (`InventoryImportJobResponse`: `id`, `status`, `file_name`,
`started_by_user_id`, `started_at`, `finished_at`, `total_rows`, `created_count`,
`updated_count`, `failed_count`, `errors[]`).

Cambia lo que puede aparecer dentro de `errors[]` (lista de `{fila, codigo, motivo}`):

| Campo | Antes | Ahora |
|---|---|---|
| `motivo` | nunca incluía un mensaje de stock negativo (la fila siempre se aplicaba igual) | puede ser `"El ajuste dejaría el stock de '<nombre>' en negativo."` (US3/FR-006), cuando el Stock de la fila, comparado con el stock actual del insumo, produciría un ajuste negativo que dejaría `current_stock < 0` |

`created_count`/`updated_count`/`failed_count` no cambian de significado — solo que ahora
una fila puede fallar por este motivo nuevo además de los ya existentes (dato inválido,
código duplicado en el archivo, proveedor/unidad no resuelta).

## Código de estado HTTP

Sin cambios en ningún endpoint de este contrato.

## `GET /inventory/items/{item_id}/movements` (kardex de un insumo)

Sin cambios de forma (`Page[MovementResponse]`: `id`, `type`, `quantity`, `reason`,
`reference_type`, `reference_id`, `moved_at`, `user_id`).

Cambia lo que puede aparecer como **valor** de los siguientes campos, para los movimientos
originados por una importación masiva de Excel:

| Campo | Antes (spec 109/139/142) | Ahora (spec 165) |
|---|---|---|
| (ningún movimiento existía) | la importación nunca generaba filas en este listado | cada insumo creado con Stock > 0, o actualizado con un delta de Stock ≠ 0, tiene una fila nueva aquí |
| `type` | — | `"in"` (insumo creado) o `"adjustment"` (insumo actualizado) |
| `reason` | — | `"importacion_masiva"` |
| `reference_type` | — | `"import_job"` |
| `reference_id` | — | `id` del `InventoryImportJob` que procesó esa fila |
| `quantity` | — | magnitud absoluta del Stock inicial (creación) o del delta (actualización) |

Ningún otro movimiento (venta, compra, ajuste manual, orden) cambia de forma ni de
significado.

## Efectos secundarios ahora incluidos en el procesamiento de cada fila (antes no existían)

- Insumo **creado** por una fila con Stock > 0: una fila nueva en `InventoryMovement`
  (`type="in"`) y `InventoryItem.current_stock` pasa de `0` al valor de Stock de la fila, en
  el mismo commit que ya aplicaba esa fila (spec 109, cada fila comitea de forma
  independiente).
- Insumo **actualizado** por una fila cuyo Stock difiere del `current_stock` actual: una
  fila nueva en `InventoryMovement` (`type="adjustment"`) y `InventoryItem.current_stock`
  cambia exactamente en esa diferencia, en el mismo commit de la fila.
- Insumo **actualizado** por una fila cuyo Stock coincide con el `current_stock` actual
  (delta = 0): sin cambios observables, igual que antes de esta spec.
- Insumo **actualizado** por una fila cuyo delta dejaría el stock negativo: la fila se
  reporta como fallida (`errors[]`, ver arriba); `InventoryItem.current_stock` **no** cambia;
  el resto del archivo sigue procesándose con normalidad (ya vigente, spec 109).
- `InventoryItem.unit_cost`: sin cambios en ningún caso — sigue sobrescribiéndose directo con
  el valor de Costo de la fila (FR-009), nunca genera un `InventoryMovement`.
