# Data Model: Gestión de la relación proveedor–insumo

Convención del repositorio: identificadores de código (tablas, columnas) en inglés; comentarios,
docstrings y mensajes de negocio en español de Colombia (Principio XIII) — igual que
`InventoryItem`, `Supplier` y `PurchaseItem` ya existentes. `presentación` → `presentation`,
`factor_conversión` → `conversion_factor`, `último_costo`/`fecha_último_costo` →
`last_cost`/`last_cost_at`, `preferido` → `preferred`, `es_sistema` → `is_system`.

## Entidades modificadas

### `Supplier` (`app/models/supplier.py`) — ya existe

| Columna | Tipo | Cambio |
|---|---|---|
| `is_system` | `Boolean NOT NULL DEFAULT false` | **Nueva** (FR-019). `true` solo para el proveedor semilla "Compra ocasional"; todo proveedor existente la recibe en `false` vía `server_default`, sin backfill manual. |

**Regla derivada**: ningún `Supplier` con `is_system=true` puede aparecer como `supplier_id` de
un `SupplierItem` (FR-012/FR-013) ni en el selector de vinculación de la UI.

### `PurchaseItem` (`app/models/purchase.py`) — ya existe

| Columna | Tipo | Cambio |
|---|---|---|
| `supplier_item_id` | `UUID NULL REFERENCES supplier_items.id` | **Nueva**, sin poblar por ningún flujo de esta spec (research.md D6). Existe únicamente para que FR-014 tenga algo que inspeccionar; HU-05 es quien la llena al implementar el upsert automático (RN-15). |

## Entidad nueva

### `SupplierItem` (`app/models/supplier_item.py`, tabla `supplier_items`, schema `tenant`)

| Columna | Tipo | Regla |
|---|---|---|
| `id` | `UUID PK` | — |
| `supplier_id` | `UUID NOT NULL, FK → suppliers.id, index` | El proveedor debe tener `is_system=false` (validado en servicio y rechazado por la BD de forma indirecta: ver FR-013) |
| `inventory_item_id` | `UUID NOT NULL, FK → inventory_items.id, index` | — |
| `presentation` | `String(100) NOT NULL` | Texto libre (p. ej. "Bolsa x 500 g"); comparación de unicidad normalizada, ver índice `ux__supplier_items__combo` |
| `conversion_factor` | `Numeric(12, 3) NOT NULL` | `CHECK (conversion_factor > 0)` (FR-002). No editable si `EXISTS` una fila en `purchase_items.supplier_item_id` apuntando a esta relación (FR-014) — regla de servicio, no de esquema, porque depende de otra tabla |
| `last_cost` | `Numeric(12, 2) NULL` | Opcional; al escribirse (alta o edición), el servicio fija `last_cost_at = now()` en la misma operación (FR-006) |
| `last_cost_at` | `DateTime NULL` | Ver arriba — nunca se setea manualmente sin `last_cost` |
| `active` | `Boolean NOT NULL DEFAULT true` | `false` = oculta por defecto en ambas pestañas (FR-017) |
| `preferred` | `Boolean NOT NULL DEFAULT false` | Solo puede ser `true` si `active=true` (FR-010); a lo sumo una fila `true` por `inventory_item_id` (FR-008/FR-009), forzado por `ux__supplier_items__preferred` |
| `created_at` / `updated_at` | `TimestampMixin` | Igual que el resto de modelos del repositorio |

**Constraints e índices**:

- `CheckConstraint("conversion_factor > 0", name="ck__supplier_items__conversion_factor")`
- Índice único por expresión (no una `UniqueConstraint` simple — ver research.md D3):
  `ux__supplier_items__combo` ON `(supplier_id, inventory_item_id,
  lower(trim(presentation)))` — cubre activas e inactivas (FR-003), es lo que permite
  distinguir "ya existe activa → rechazar como duplicada" (FR-004) de "ya existe inactiva →
  reactivar" (FR-005) en el servicio antes de decidir qué hacer.
- Índice único parcial (research.md D4): `ux__supplier_items__preferred` ON
  `(inventory_item_id)` `WHERE preferred AND active` — **no `DEFERRABLE`** (los índices de
  Postgres no lo admiten). El servicio debe bloquear el `InventoryItem` padre
  (`SELECT ... FOR UPDATE`, reutilizando `lock_items`) antes de desmarcar y volver a marcar, en
  ese orden, dentro de la misma transacción (RN-16).

**Transiciones de estado**:

```
          crear (combo nuevo)
   (ninguna) ─────────────────► active=true, preferred=false
          │
          │ crear (combo ya existe inactivo) → reactivar
          │ PATCH active=false                 PATCH active=true
          ▼                                        │
      active=false ◄───────────────────────────────┘
      preferred=false (forzado)

   active=true, preferred=false ──PATCH preferred=true──► active=true, preferred=true
         (desmarca, en la misma tx, cualquier otra preferred=true del mismo insumo)

   active=true, preferred=true ──PATCH active=false──► active=false, preferred=false
                                  (cascada en la misma operación, FR-011)
```

Marcar `preferred=true` sobre una fila con `active=false` se rechaza (FR-010): no hay transición
directa de `(active=false, *)` a `preferred=true` sin pasar primero por `active=true`.

## Migración (una sola, vía `@for_each_tenant_schema`)

**Upgrade** (por cada esquema de tenant, igual que
`f03274730367_presentations_y_reglas_por_presentacion.py`):
1. `op.add_column("suppliers", is_system BOOLEAN NOT NULL DEFAULT false)`.
2. Seed idempotente: `INSERT INTO {schema}.suppliers (name, is_system, active) SELECT 'Compra ocasional', true, true WHERE NOT EXISTS (SELECT 1 FROM {schema}.suppliers WHERE is_system)`.
3. `op.create_table("supplier_items", ...)` con las columnas/constraints de arriba.
4. Los dos índices (`ux__supplier_items__combo` por expresión, `ux__supplier_items__preferred`
   parcial).
5. `op.add_column("purchase_items", supplier_item_id UUID NULL, FK → supplier_items.id)`.

**Compatibilidad con datos existentes**: ningún `Supplier`, `InventoryItem` ni `PurchaseItem` fila
existente cambia de significado — `is_system` nace `false` para todos los proveedores ya
creados, y `supplier_item_id` nace `NULL` para toda línea de compra ya registrada. Ninguna
factura ni compra histórica se recalcula (Principio VII).

**Downgrade**: simétrico — `op.drop_column("purchase_items", "supplier_item_id")`,
`op.drop_table("supplier_items")`, borrar la fila sembrada
(`DELETE FROM suppliers WHERE is_system`), `op.drop_column("suppliers", "is_system")`. Lossy
solo para datos de esta propia funcionalidad (relaciones proveedor-insumo creadas después del
upgrade) — nunca para facturas, compras o movimientos de inventario históricos.

## Esquemas Pydantic (`app/api/v1/inventory/schemas.py`)

- `SupplierItemCreate`: `supplier_id: UUID`, `inventory_item_id: UUID`, `presentation: str`,
  `conversion_factor: Decimal` (`gt=0`), `last_cost: Decimal | None` (`ge=0`).
- `SupplierItemUpdate` (todos opcionales, PATCH parcial — mismo estilo que `SupplierUpdate`):
  `presentation: str | None`, `conversion_factor: Decimal | None` (`gt=0`),
  `last_cost: Decimal | None`, `active: bool | None`, `preferred: bool | None`.
- `SupplierItemResponse`: todos los campos de la entidad + `equivalence: str` calculado
  (`"1 {presentation} = {conversion_factor} {unit_measure.abbreviation} · ${last_cost /
  conversion_factor, redondeado a 2 decimales}/{unit_measure.abbreviation}"`, `None` si no hay
  `last_cost`) + los datos mínimos del lado contrario para pintar la fila sin otra consulta
  (`supplier_name`, `inventory_item_name`) + `was_preferred: bool` (default `false`, siempre
  presente — no un campo opcional-ausente; `true` solo cuando un `PATCH` con `active=false`
  acabó de quitarle la marca de preferido, FR-011).
- `SupplierItemConflict` (cuerpo del 409 de FR-004): `existing_id: UUID` — el id de la relación
  activa con la que colisionó el alta, para que la UI ofrezca "editar la existente".
