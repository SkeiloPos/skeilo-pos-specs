# Data Model: Vista dedicada para registrar una compra

Ninguna entidad nueva. Se extiende de forma aditiva la entidad existente `Purchase`
(`pos-backend/app/models/purchase.py`). No cambia `PurchaseItem`, `InventoryItem`,
`Supplier` ni la relación proveedor-insumo.

## Purchase (existente, extendida)

| Campo | Tipo | Estado | Descripción |
|---|---|---|---|
| `id` | UUID/int (según modelo actual) | sin cambios | identificador de la compra |
| `supplier_id` | FK nullable | sin cambios | proveedor; nulo = "compra ocasional" |
| `invoice_reference` | string nullable | sin cambios | número/referencia de factura (FR-010) |
| `status` | enum `draft \| partial \| received` (CHECK `ck_purchase_status`) | sin cambios de valores | `draft`=pendiente de recepción, `partial`=recibida parcialmente, `received`=recibida completa |
| `is_incomplete` | **boolean, NOT NULL, default `false`** | **NUEVO** | `true` únicamente cuando `status='draft'` y la compra se guardó con "Guardar borrador" (FR-017), es decir, sin exigir líneas completas. `false` para toda orden de compra validada (comportamiento actual, User Story 2) y para toda compra recibida. |
| `total` | numeric | sin cambios | total monetario calculado |
| ... | ... | sin cambios | resto de columnas existentes (fecha, tenant/schema, etc.) |

### Reglas de validación

- `is_incomplete=true` solo es válido cuando `status='draft'`. No tiene sentido combinarlo
  con `partial` o `received` (una compra recibida, aunque sea parcialmente, ya tiene al
  menos una línea con cantidad válida procesada).
- Toda fila existente antes de esta migración tiene `is_incomplete=false` por el `default`,
  preservando su significado histórico de "orden de compra pendiente" (Principio VII).

### Migración (Alembic)

- **Up**: `ALTER TABLE purchases ADD COLUMN is_incomplete BOOLEAN NOT NULL DEFAULT false;`
  en cada schema de tenant (patrón ya usado por migraciones previas schema-per-tenant de
  este repo).
- **Compatibilidad con datos existentes**: el `default false` hace que ninguna fila
  histórica cambie de significado; las órdenes pendientes actuales siguen siendo órdenes
  pendientes (`is_incomplete=false`), nunca se reinterpretan como "borrador incompleto".
- **Rollback**: `ALTER TABLE purchases DROP COLUMN is_incomplete;` — seguro porque ninguna
  otra tabla ni lógica depende todavía de esta columna antes de que se implemente la nueva
  acción "Guardar borrador"; revertir la migración simplemente retira la capacidad de
  distinguir un borrador incompleto de una orden pendiente (ambas seguirían existiendo como
  `status='draft'`).

## Interfaz de frontend (`inventory.interface.ts`)

- El tipo `PurchaseStatus = 'draft' | 'partial' | 'received'` no cambia.
- Se añade `isIncomplete?: boolean` (mapeado de `is_incomplete`) a la interfaz de respuesta
  de compra, usado por el listado de compras para distinguir visualmente "Orden pendiente"
  de "Borrador" (ambos con `status='draft'`) y por la vista nueva para permitir reabrir y
  continuar editando un borrador (FR-017).

## Sin cambios de esquema en:

- `PurchaseItem` / líneas de compra.
- `InventoryItem` (insumo): código, nombre, unidad base, stock — ya expuestos por
  `GET /items`.
- `Supplier` y la relación proveedor-insumo (presentación preferida + último costo): ya
  expuestos por los endpoints existentes de `suppliers`/`supplier-items`.
