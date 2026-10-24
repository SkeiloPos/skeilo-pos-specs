# Data Model: Búsqueda por Nombre o Código y Filtro por Proveedor en Inventario

Esta spec **no agrega entidades ni columnas nuevas**. Reutiliza entidades ya existentes
(`InventoryItem`, `SupplierItem`, `Supplier`, definidas en specs previas) y agrega únicamente
un índice compuesto nuevo sobre una tabla ya existente.

## Entidades existentes relevantes (sin cambios de esquema)

### InventoryItem (`tenant.inventory_items`)

Modelo: `pos-backend/app/models/inventory_item.py`.

| Campo | Tipo | Notas relevantes para esta spec |
|---|---|---|
| `id` | UUID (PK) | Sin cambios |
| `name` | `String(255)`, `unique`, `index` | Ya usado en la búsqueda actual; sigue sin cambios |
| `code` | `String(20)`, `unique`, `index` | Hoy no participa en la búsqueda; esta spec lo agrega como segundo criterio de `search` (D1 en research.md) |
| `type` | `String(20)` | Filtro ya existente (spec 085), sin cambios |
| `active` | `Boolean` | Filtro ya existente (spec 085), sin cambios |

### SupplierItem (`tenant.supplier_items`)

Modelo: `pos-backend/app/models/supplier_item.py` (spec 106).

| Campo | Tipo | Notas relevantes para esta spec |
|---|---|---|
| `supplier_id` | UUID (FK → `suppliers.id`) | Criterio del nuevo filtro de proveedor |
| `inventory_item_id` | UUID (FK → `inventory_items.id`) | Usado en el `EXISTS` del nuevo filtro |
| `active` | `Boolean` | Determina si la relación cuenta para el filtro (FR-005): solo relaciones activas |
| `preferred` | `Boolean` | No usado por esta spec |

### Supplier (`tenant.suppliers`)

Sin cambios. Se usa únicamente para poblar el selector de proveedores del nuevo filtro
(proveedores activos del catálogo general, igual al patrón de otros selectores de proveedor ya
existentes — ver Assumptions en spec.md).

## Cambio de esquema: índice compuesto nuevo

**Tabla**: `tenant.supplier_items`

**Índice nuevo**: `ix__supplier_items__supplier_id_active` sobre `(supplier_id, active)`.

**Migración Alembic** (nueva revisión, encadenada sobre
`99d57acd0216_supplier_items_y_proveedor_sistema`):

```python
def upgrade():
    for_each_tenant_schema(_create_index)

def _create_index(schema: str) -> None:
    op.create_index(
        "ix__supplier_items__supplier_id_active",
        "supplier_items",
        ["supplier_id", "active"],
        schema=schema,
    )

def downgrade():
    for_each_tenant_schema(_drop_index)

def _drop_index(schema: str) -> None:
    op.drop_index(
        "ix__supplier_items__supplier_id_active",
        table_name="supplier_items",
        schema=schema,
    )
```

(Usa el mismo helper `for_each_tenant_schema` que las migraciones previas de esta tabla, dado
el esquema multi-tenant por `schema_translate_map` — ver `99d57acd0216_...py`.)

**Compatibilidad con datos existentes**: Crear un índice no modifica ni reinterpreta ninguna
fila existente; es una operación puramente aditiva y segura de ejecutar con datos en
producción (no requiere backfill ni default nuevo).

**Estrategia de rollback**: `downgrade()` elimina el índice (`drop_index`); no hay pérdida de
datos posible porque el índice no almacena información de negocio, solo acelera lecturas.

## Sin cambios de relaciones

La relación `InventoryItem` ↔ `SupplierItem` ↔ `Supplier` ya existe completa desde spec 106;
esta spec solo la **consulta** (vía `EXISTS`), no la modifica.
