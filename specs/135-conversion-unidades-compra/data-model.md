# Data Model: Compra de Insumos con Conversión a Unidad Base

**Spec**: `specs/135-conversion-unidades-compra/spec.md` | Decisiones: ver `research.md`

Todas las tablas nuevas/modificadas viven en el esquema `tenant` salvo donde se indique
`shared` explícitamente. Todo cambio es aditivo y con backfill (Principio VIII).

## `unit_measures` (modifica, `tenant`)

| Columna | Tipo | Notas |
|---|---|---|
| `id` | UUID PK | ya existe |
| `name` | String(255) | ya existe, unique |
| `abbreviation` | String(50) | ya existe, unique |
| `active` | Boolean | ya existe |
| **`dimension`** | String(100) NOT NULL | **nueva**. Grupo de medida (p. ej. "Masa", "Volumen"). Backfill: `'general'`. |
| **`factor_to_base`** | Numeric(18,6) NOT NULL DEFAULT 1 | **nueva**. Factor hacia la base de su `dimension`. Backfill: `1`. |

Reglas:
- Dos unidades son convertibles entre sí si `dimension` coincide exactamente.
- No existe un catálogo cerrado de valores de `dimension`: el admin lo escribe al crear
  la unidad, igual que ya escribe `name`/`abbreviation`.
- `factor_to_base` solo puede cambiarse por un usuario con rol ADMIN del tenant
  (FR-011a); cada cambio genera una fila en `unit_measure_factor_changes` (FR-011).

## `unit_measure_factor_changes` (nueva, `tenant`)

| Columna | Tipo | Notas |
|---|---|---|
| `id` | UUID PK | |
| `unit_measure_id` | UUID FK → `unit_measures.id` | índice |
| `old_factor` | Numeric(18,6) NOT NULL | valor antes del cambio |
| `new_factor` | Numeric(18,6) NOT NULL | valor después del cambio |
| `changed_by` | UUID NOT NULL | referencia blanda a `shared.users.id` (mismo patrón que `Purchase.user_id`) |
| `changed_at` | DateTime NOT NULL, server_default now() | |

Solo lectura desde la API (histórico consultable, FR-011); se inserta exclusivamente
desde el handler de `PATCH /unit-measures/{id}` cuando cambia `factor_to_base`.

## `inventory_items` (modifica, `tenant`)

| Columna | Cambio |
|---|---|
| `current_stock` | `Numeric(12,3)` → **`Numeric(18,6)`** (ensanche, ver research.md D4) |
| `unit_cost` | `Numeric(12,2)` → **`Numeric(18,6)`** (ensanche) |

Sin cambios de columnas nuevas. `unit_measure_id` ya es la unidad base del insumo
(FR-001, ya satisfecho). Regla nueva en la capa de aplicación (no en el esquema):
`PATCH /inventory/items/{id}` rechaza (409) cambiar `unit_measure_id` si el insumo ya
tiene al menos un `InventoryMovement` (FR-002).

## `inventory_movements` (modifica, `tenant`)

| Columna | Cambio |
|---|---|
| `quantity` | `Numeric(12,3)` → **`Numeric(18,6)`** (ensanche, consistente con D4) |

Nuevo valor de referencia usado por esta spec (no es columna, es un literal de
`app/core/inventory_reasons.py`): `REF_PURCHASE_VOID`, análogo a `REF_ORDER_VOID` ya
existente, para los movimientos de reversa que genera `POST /purchases/{id}/void`.

## `purchases` (modifica, `tenant`)

| Columna | Tipo | Notas |
|---|---|---|
| **`voided_at`** | DateTime NULL | **nueva**. NULL = no anulada. |
| **`voided_by`** | UUID NULL | **nueva**. Referencia blanda a `shared.users.id`. |

`status` (`draft`/`partial`/`received`) no cambia: la anulación es ortogonal al ciclo de
recepción (FR-012/FR-013).

## `purchase_items` (modifica, `tenant`)

| Columna | Tipo | Notas |
|---|---|---|
| `quantity` | Numeric(12,3) | ya existe. Pasa a significar explícitamente "cantidad **original ingresada**" (FR-009), en la unidad de `unit_measure_id` de esta misma fila. |
| `unit_cost` | Numeric(12,2) | ya existe. "Costo unitario **original ingresado**" en esa misma unidad. |
| **`unit_measure_id`** | UUID FK → `unit_measures.id`, NOT NULL tras backfill | **nueva**. Unidad en la que se capturó la línea. |
| **`conversion_factor_applied`** | Numeric(18,6) NOT NULL DEFAULT 1 | **nueva**. Factor resuelto en servidor al confirmar (FR-008), inmutable después (FR-010). |
| **`quantity_base`** | Numeric(18,6) NOT NULL | **nueva**. `quantity * conversion_factor_applied`. Es lo que alimenta `record_movement` (FR-006). |
| **`cost_base`** | Numeric(18,6) NOT NULL | **nueva**. `unit_cost / conversion_factor_applied`. Alimenta el costo del insumo (FR-007). |

Backfill (FR-021) para toda fila existente antes de esta spec:
`unit_measure_id = <unit_measure_id del InventoryItem referenciado>`,
`conversion_factor_applied = 1`, `quantity_base = quantity`, `cost_base = unit_cost`.
No se recalcula ni se toca ningún stock existente.

Relación con `supplier_item_id` (spec 106/107, columna ya existente, sin cambios): una
línea con `supplier_item_id` no NULL sigue calculando su equivalente en unidad base
exactamente como hoy (vía `SupplierItem.conversion_factor`); para esas filas,
`unit_measure_id` se guarda igual a la unidad base del insumo y
`conversion_factor_applied = 1`, de modo que `quantity_base`/`cost_base` coincidan con
los `quantity`/`unit_cost` ya calculados por esa ruta (comportamiento observable
idéntico al actual). Las dos rutas (`supplier_item_id` vs. "unidad distinta a la base
elegida en esta línea") son mutuamente excluyentes: nunca ambas a la vez en la misma
línea.

## `tenants` (modifica, `shared`)

| Columna | Tipo | Notas |
|---|---|---|
| **`unit_conversion_enabled`** | Boolean NOT NULL DEFAULT true | **nueva**. FR-016. `true` preserva el comportamiento de todo tenant existente. |

## Entidades sin cambios de esquema

- **Insumo** (`InventoryItem`): sin columnas nuevas (ver arriba).
- **Grupo de medida**: no es una tabla — ver `unit_measures.dimension` (research.md D1).

## Diagrama de relaciones (solo lo nuevo/modificado)

```text
tenants (shared)
└── unit_conversion_enabled: bool

unit_measures
├── dimension: str                 (NUEVO)
├── factor_to_base: numeric(18,6)  (NUEVO)
└── unit_measure_factor_changes (1:N, NUEVA tabla)
        ├── old_factor / new_factor
        └── changed_by / changed_at

inventory_items
├── unit_measure_id → unit_measures.id   (ya existía; es la "unidad base")
├── current_stock: numeric(18,6)         (ENSANCHADA)
└── unit_cost: numeric(18,6)             (ENSANCHADA)

purchases
├── voided_at / voided_by                (NUEVO)
└── items (1:N) → purchase_items
        ├── supplier_item_id → supplier_items.id   (ya existía, spec 106/107, sin cambios)
        ├── unit_measure_id → unit_measures.id      (NUEVO)
        ├── conversion_factor_applied: numeric(18,6) (NUEVO)
        ├── quantity / unit_cost                     (ya existían; = "capturado original")
        └── quantity_base / cost_base: numeric(18,6) (NUEVOS; = "en unidad base del insumo")

inventory_movements
└── quantity: numeric(18,6)              (ENSANCHADA)
```
