# Data Model: Simplificar columnas de proveedor en Excel de inventario

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)

Esta funcionalidad **no introduce entidades ni campos nuevos**. Modifica únicamente el
comportamiento de vinculación/creación sobre entidades ya existentes (spec 137) y retira un
subconjunto de columnas del contrato de archivo de la spec 109. Se documentan aquí solo las
entidades afectadas y los cambios de comportamiento, no un esquema nuevo.

## Entidades afectadas (sin cambio de esquema)

### UnitMeasure (`app/models/unit_measure.py`)

Sin cambios de columnas. Campos relevantes para esta funcionalidad:

| Campo | Tipo | Relevancia en esta spec |
|---|---|---|
| `name` | String, único | Se asigna igual al texto normalizado de la columna Unidad al autocrear |
| `abbreviation` | String, único | Campo contra el que ya se compara la columna Unidad (case-insensitive); se asigna igual al texto normalizado al autocrear |
| `group_id` | FK → `unit_measure_groups.id`, NOT NULL | **Gap a cerrar**: la autocreación actual no lo asigna; debe asignarse al grupo nuevo creado para esta unidad |
| `is_base` | bool | Debe quedar en `True` para la unidad autocreada (es la única de su grupo nuevo) |
| `factor_to_base` | Numeric(18,6) | Debe quedar en `1` para la unidad autocreada (es su propia base) |
| `dimension` | String | Se asigna igual al `name` del grupo nuevo, siguiendo el patrón de `create_unit_measure_group` |
| `active` | bool | `True` para la unidad autocreada |

**Regla de negocio nueva**: al **crear** un insumo por importación, el texto de la columna Unidad
se resuelve contra `UnitMeasure.abbreviation` sin distinguir mayúsculas/minúsculas; si no hay
coincidencia, se crea una `UnitMeasure` nueva con todos los campos anteriores completos (cierra el
gap de `group_id` NOT NULL). Si hay más de una coincidencia, la fila falla (FR-008). Al
**actualizar** un insumo existente, esta resolución **no se ejecuta** (ver Insumo de Inventario
abajo).

### UnitMeasureGroup (`app/models/unit_measure_group.py`)

Sin cambios de columnas. Se crea una fila nueva (`name` = texto normalizado de la unidad) cada vez
que una fila de importación crea un insumo nuevo con una unidad que no existe todavía — mismo
patrón que crear un grupo manualmente desde Ajustes (spec 137/`unit_measure_groups/router.py`).

### Insumo de Inventario (`InventoryItem` / tabla manejada por `app/api/v1/inventory/service.py`)

Sin cambios de columnas. Cambio de comportamiento sobre el campo `unit_measure_id` ya existente:

- **Fila que crea un insumo nuevo** (código no coincide con ninguno existente): `unit_measure_id`
  se asigna al resultado de resolver/crear la unidad (ver arriba). Vacío → fila fallida (FR-009).
- **Fila que actualiza un insumo existente** (código coincide): `unit_measure_id` **no se
  modifica** bajo ninguna circunstancia, sin importar el valor de la columna Unidad en la fila
  (FR-007). El resto de campos de la fila (nombre, tipo, stock, mínimo, costo) se actualiza con
  normalidad a través del mismo `resolve_or_create_by_code`.

### Supplier (`app/models/supplier.py`)

Sin cambios de columnas. Se crea una fila nueva (`name` = texto normalizado en mayúscula,
`is_system=False`, `active=True`) cuando la columna Proveedor preferido de una fila trae un
nombre que no coincide con ningún proveedor existente -- mismo patrón de consolidación ya vigente
para proveedores desde antes de esta spec.

### SupplierItem / relación proveedor-insumo (`app/models/supplier_item.py`)

**Cambio de esquema** (único de esta spec, ver migración `c5815ab62693`): `presentation` y
`conversion_factor` pasan de `NOT NULL` a nullable. `preferred`/`last_cost`/`active` no cambian.

| Campo | Antes | Después | Relevancia en esta spec |
|---|---|---|---|
| `presentation` | `String(100) NOT NULL` | `String(100)` (nullable) | Una relación creada por import (FR-012) no la trae |
| `conversion_factor` | `Numeric(12,3) NOT NULL` | `Numeric(12,3)` (nullable) | Idem; `ck__supplier_items__conversion_factor` (`> 0`) no se toca -- `NULL` ya satisface un CHECK en Postgres |

Cambio de comportamiento: `presentation`/`conversion_factor`/`last_cost` de una relación **ya
existente** nunca se modifican por el flujo de importación/exportación de inventario (FR-004);
`preferred` sí participa, tanto para vincular una relación existente como para una nueva creada
por esta vía.

- **Export**: las columnas `Presentación`, `Factor de conversión`, `Último costo` dejan de
  escribirse en el archivo (FR-001/FR-002). La columna `Proveedor preferido` (solo el nombre)
  sigue escribiéndose -- `preferred_relations_by_item` sigue usándose desde `export.py`, pero
  `build_inventory_excel` solo lee `supplier_name` del resultado, no `presentation`/
  `conversion_factor`/`last_cost`.
- **Import**: `_apply_preferred_supplier()` ya no lee ni aplica `Presentación`/`Factor de
  conversión`/`Último costo` (FR-004). Dado un nombre en la columna `Proveedor preferido`:
  resuelve/crea el `Supplier` (`_resolve_supplier`, mismo patrón que antes de esta spec); busca
  una relación proveedor-insumo **activa** entre ese insumo y ese proveedor; si hay exactamente
  una, la marca `preferred=True` (`supplier_items.set_preferred`, FR-010); si no hay ninguna,
  **crea una nueva** con `presentation=None`, `conversion_factor=None`, y la marca preferida
  (FR-012); si hay más de una, la fila falla por ambigüedad (FR-011). Un archivo legado que
  todavía traiga `Presentación`/`Factor de conversión`/`Último costo` las conserva sin leer su
  contenido (FR-003); la estructura sigue siendo válida.
- Un `SupplierItem` con `conversion_factor=None` no puede usarse todavía en una compra
  (`service.py::_resolve_purchase_line` lo rechaza con 422 explícito) hasta que el administrador
  lo complete desde el módulo de proveedores.

## Contrato de columnas del archivo (antes → después)

| # | Columna (antes, spec 109) | Columna (después, esta spec) |
|---|---|---|
| 1 | Código | Código |
| 2 | Nombre | Nombre |
| 3 | Tipo | Tipo |
| 4 | Unidad | Unidad |
| 5 | Stock | Stock |
| 6 | Mínimo | Mínimo |
| 7 | Costo | Costo |
| 8 | Proveedor preferido | Proveedor preferido *(se conserva; import solo vincula una relación ya existente, FR-010/FR-011)* |
| 9 | Presentación | *(removida del export; aceptada e ignorada si está presente al importar)* |
| 10 | Factor de conversión | *(removida del export; aceptada e ignorada si está presente al importar)* |
| 11 | Último costo | *(removida del export; aceptada e ignorada si está presente al importar)* |

`validar_estructura()` acepta ambas longitudes de encabezado (8 columnas nuevas, u 11 columnas
legadas con las 3 últimas en su posición original) sin reportar error de estructura.
