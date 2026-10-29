# Data Model: Filtro buscable de proveedor, exportación filtrada y vinculación de unidades de compra por Excel

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)

Esta funcionalidad **no introduce entidades ni columnas nuevas, ni requiere ninguna migración**.
Las tres historias reutilizan entidades y relaciones ya existentes desde las specs 106, 133, 137,
139 y 140. Se documentan aquí solo las entidades afectadas y los cambios de comportamiento sobre
ellas.

## Historia 1 — Filtro buscable de proveedor

Sin entidades afectadas. `Supplier` se usa exactamente igual que hoy (lectura, sin cambios);
cambia únicamente el componente de UI que recoge la selección del usuario.

## Historia 2 — Exportación filtrada

### `InventoryItem` (`app/models/inventory_item.py`) — sin cambio de esquema

Sin cambios de columnas. Cambia el **criterio de selección** de filas incluidas en el archivo de
exportación (`GET /inventory/items/export`):

| Antes (spec 109/139) | Después (esta spec) |
|---|---|
| `list_all_items_for_export(db)`: todos los insumos del tenant, activos e inactivos, sin filtrar | `list_items_query(type_=type_, supplier_id=supplier_id)` ejecutado sin paginar: mismo universo base (activos e inactivos, `active` sin fijar), con `AND` opcional por `type_` y/o por existencia de una relación activa con `supplier_id` |

Sin `type_` ni `supplier_id` el resultado es idéntico al actual (FR-005) — no hay regresión para
quien no usa los filtros nuevos.

### `SupplierItem` (`app/models/supplier_item.py`) — sin cambio de esquema

Se usa en modo lectura (vía `exists()` dentro de `list_items_query`) exactamente con el mismo
criterio que ya usa el filtro de proveedor del listado de Insumos (spec 133): `active = true`,
sin importar si la relación es la preferida ni el estado del `Supplier` (Edge Case: proveedor
inactivo con relación activa igual se exporta).

## Historia 3 — Grupo de unidad base y unidad de compra por proveedor vía Excel

### `UnitMeasureGroup` (`app/models/unit_measure_group.py`) — sin cambio de esquema

Campos relevantes (sin cambio): `id`, `name` (único en el tenant, case-insensitive vía
`ensure_unique_ci`), `units` (relación inversa).

**Regla de negocio nueva**: al crear un insumo nuevo por importación con la columna `Grupo`
llena, el texto se normaliza (mayúscula, espacios recortados) y se busca un `UnitMeasureGroup`
existente por `name` sin distinguir mayúsculas/minúsculas; si no existe, se crea uno nuevo con ese
nombre (FR-010). Con la columna `Grupo` vacía, se conserva el comportamiento de la spec 139: se
crea un grupo propio nuevo con el texto de la unidad como nombre (FR-011).

### `UnitMeasure` (`app/models/unit_measure.py`) — sin cambio de esquema

Campos relevantes (sin cambio): `name` (único en el tenant), `abbreviation` (sin restricción de
unicidad desde la spec 140), `group_id` (FK, `NOT NULL`), `is_base`, `factor_to_base`, `active`.

**Reglas de negocio nuevas** (solo al **crear** un insumo nuevo; una fila que actualiza un insumo
existente nunca ejecuta ninguna de estas resoluciones — FR-013, FR-021, mismo criterio ya vigente
desde la spec 139 para la columna `Unidad`):

- **Unidad base** (columna `Unidad`, ya existía; cambia solo cuando `Grupo` viene lleno): se
  busca por `abbreviation` sin distinguir mayúsculas/minúsculas, ahora acotado a buscar coincidencia
  dentro del grupo resuelto arriba cuando `Grupo` viene lleno. Si el nombre de la unidad ya existe
  en el negocio pero en un grupo **distinto** al resuelto, la fila falla por ambigüedad (FR-012);
  no se crea ni modifica nada. Si no hay ninguna coincidencia, se crea la `UnitMeasure` nueva en el
  grupo resuelto, con `is_base=True`, `factor_to_base=1` (FR-010).
- **Unidad de compra del proveedor preferido** (columnas nuevas `Unidad de compra` + `Factor de
  conversión (compra)`, solo si `Proveedor preferido` también viene lleno en la misma fila —
  FR-020a): se busca por `abbreviation`/`name` sin distinguir mayúsculas/minúsculas, acotada al
  **mismo grupo** que la unidad base ya resuelta del insumo.
  - Coincide en ese grupo, factor de la fila vacío o igual al `factor_to_base` ya vigente →
    se reutiliza esa `UnitMeasure` sin modificar su factor (FR-015, Acceptance Scenario 5).
  - Coincide en ese grupo, factor de la fila distinto al ya vigente → fila fallida por conflicto
    de factor, sin modificar el factor ya vigente (FR-016, Acceptance Scenario 6).
  - Coincide por nombre/abreviatura pero en un grupo **distinto** → fila fallida por ambigüedad de
    grupo (FR-017).
  - No hay ninguna coincidencia y la fila trae factor → se crea una `UnitMeasure` nueva en el
    grupo de la unidad base, `is_base=False`, `factor_to_base` = el de la fila (FR-015, Acceptance
    Scenario 7).
  - No hay ninguna coincidencia y la fila no trae factor → fila fallida por dato obligatorio
    faltante (FR-018, Acceptance Scenario 8).

### `SupplierItem` (`app/models/supplier_item.py`) — sin cambio de esquema

Campos relevantes (sin cambio, ya introducidos por la spec 140): `unit_measure_id` (FK opcional a
`unit_measures.id`, modo nuevo) vs. `presentation`/`conversion_factor` (modo legado, texto libre +
factor a mano) — mutuamente excluyentes.

**Cambio de comportamiento**: cuando una fila que **crea** un insumo nuevo trae
`Proveedor preferido` y además `Unidad de compra`/`Factor de conversión (compra)` resueltos con
éxito (ver arriba), la relación `SupplierItem` creada por esta vía queda con `unit_measure_id` =
la `UnitMeasure` resuelta, en vez de con `presentation=NULL, conversion_factor=NULL` (FR-019).
Si la fila no trae unidad de compra (dato opcional), la relación se crea igual que hoy, con ambos
campos en `NULL` (FR-020). Una relación proveedor-insumo **ya existente** — incluida una creada
antes de esta spec con el campo libre `presentation` en blanco — nunca se modifica por una fila
que actualiza un insumo (FR-021, Edge Case de la spec).

**Validación de "sin proveedor, sin unidad de compra"**: si la fila trae `Unidad de compra` y/o
`Factor de conversión (compra)` pero **no** trae `Proveedor preferido`, la fila se reporta como
fallida (FR-020a) antes de crear el insumo, la unidad o cualquier relación — no hay forma de
asociar esos datos sin un proveedor al cual asociarlos.

## Contrato de columnas del archivo (antes → después)

| # | Columna (antes, spec 139) | Columna (después, esta spec) |
|---|---|---|
| 1 | Código | Código |
| 2 | Nombre | Nombre |
| 3 | Tipo | Tipo |
| 4 | Unidad | Unidad |
| — | *(no existía)* | **Grupo** *(nueva, opcional)* |
| 5 | Stock | Stock |
| 6 | Mínimo | Mínimo |
| 7 | Costo | Costo |
| 8 | Proveedor preferido | Proveedor preferido *(sin cambio de comportamiento salvo lo descrito arriba)* |
| — | *(no existía)* | **Unidad de compra** *(nueva, opcional)* |
| — | *(no existía)* | **Factor de conversión (compra)** *(nueva, opcional)* |

`validar_estructura()` sigue aceptando, además del nuevo formato de 10 columnas, el formato de 8
columnas (spec 139) y el legado de 11 columnas (spec 109) como estructuralmente válidos, para no
romper ningún archivo exportado antes de esta spec (Principio II).

## Diagrama de relaciones (solo lo reutilizado, sin cambios de esquema)

```text
UnitMeasureGroup
├── name: str (único, case-insensitive)      ← resuelto por la columna Grupo (H3)
└── units (1:N) → UnitMeasure
        ├── abbreviation / name               ← resueltos por Unidad (base) y Unidad de
        │                                        compra, ambos acotados al mismo group_id
        ├── group_id → UnitMeasureGroup.id     ← nunca cruzado entre unidad base y de compra
        ├── is_base / factor_to_base
        └── (relación inversa) SupplierItem.unit_measure_id
                                                ← fijado por _apply_preferred_supplier (H3)

InventoryItem
├── unit_measure_id → UnitMeasure.id (unidad base, ya existente, sin cambio)
└── (filtrado por) list_items_query(type_, supplier_id)  ← reusado también por export (H2)

SupplierItem
├── supplier_id / inventory_item_id
├── unit_measure_id → UnitMeasure.id (modo nuevo, spec 140; usado desde import, H3)
└── presentation / conversion_factor (modo legado; sin cambio, ya no se asigna desde import)
```
