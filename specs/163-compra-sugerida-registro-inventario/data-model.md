# Data Model: Registro Automático de Inventario al Generar Compra Sugerida

## Sin migración

Esta funcionalidad no añade ni modifica ninguna tabla, columna ni constraint. Las entidades
que participan ya existen con el significado necesario; el cambio es puramente de
**comportamiento de servicio** (qué valores recibe cada fila al crearse, no qué columnas
tiene la tabla).

## Entidades existentes reutilizadas (sin cambios de esquema)

- **`Purchase`** (`app/models/purchase.py`, tabla `purchases`, esquema `tenant`): su columna
  `status` ya acepta `'received'` (`CheckConstraint ck_purchase_status: status IN ('draft',
  'partial', 'received')`) y su significado ya está definido (docstring del modelo: "`received`:
  recibida por completo (el alta directa vía POST /purchases nace así)"). Esta funcionalidad
  solo cambia **cuál** de esos tres valores recibe una `Purchase` creada desde compra sugerida
  (`'received'` en vez de `'draft'`) — ningún valor nuevo, ninguna columna nueva.
  `voided_at`/`voided_by` (anulación) ya son ortogonales a `status` y ya cubren el caso de una
  `Purchase` `received` sin cambios.
- **`PurchaseItem`** (`app/models/purchase.py`, tabla `purchase_items`): `received_quantity`,
  `quantity_base`, `cost_base`, `conversion_factor_applied` ya existen y ya se resuelven en
  `_resolve_purchase_line` para toda línea (spec 106/107/134). Esta funcionalidad solo cambia
  que `received_quantity` se fije igual a `quantity` (recepción completa) en el mismo momento
  en que la línea se crea, en vez de quedar en `0` hasta una recepción manual posterior.
- **`InventoryMovement`** (`app/models/inventory_movement.py`, tabla `inventory_movements`):
  ya acepta `reference_type='purchase'` + `reference_id=<Purchase.id>` (constante
  `reasons.REF_PURCHASE`) como origen de un movimiento `type='in'` — exactamente la fila que
  `record_movement()` ya escribe para `create_purchase()`/`receive_purchase()`. Esta
  funcionalidad agrega un nuevo *caller* de `record_movement()` con esos mismos valores
  (origen: generación desde compra sugerida), no un nuevo tipo ni una nueva referencia.
- **`InventoryItem`** (`app/models/inventory_item.py`): `current_stock` (aumentado por
  `record_movement`) y `unit_cost` (actualizado igual que en `create_purchase`/
  `receive_purchase`) ya son los campos que cualquier recepción de compra ya modifica.
- **`SupplierItem`** (`app/models/supplier_item.py`): `last_cost` explícitamente **no**
  cambia en este flujo (research.md D2) — mismo comportamiento que spec 158 ya fijó.
- **`PurchaseGenerationRequest`** (`app/models/purchase_generation_request.py`, tabla
  `purchase_generation_requests`, spec 158): sin cambios de esquema. Su `purchase_ids` ya
  referencia las `Purchase` creadas por una solicitud; como esas `Purchase` ahora nacen
  `received` en vez de `draft`, un reintento con la misma `idempotency_key` sigue devolviendo
  exactamente las mismas filas (ya `received`), sin ejecutar de nuevo `record_movement` ni
  tocar `current_stock` otra vez (FR-006/SC-004) — la tabla de deduplicación ya resuelve esto
  por construcción, antes de llegar a crear nada.

## Relaciones / flujo de datos (reemplaza el tramo final del diagrama de spec 158)

```text
SuggestedPurchaseLineIn[] (POST .../generate, agrupadas por SupplierItem.supplier_id)
   │ una Purchase por grupo, en una sola transacción
   ▼
_build_purchase_order(..., receive_immediately=True)
   │
   ├─ PurchaseItem.received_quantity = PurchaseItem.quantity   (antes: 0)
   ├─ record_movement(type="in", quantity=quantity_base,         (antes: no se llamaba)
   │                   reason="compra", reference_type="purchase",
   │                   reference_id=Purchase.id)
   │      → inserta InventoryMovement + aumenta InventoryItem.current_stock
   ├─ InventoryItem.unit_cost = PurchaseItem.cost_base           (antes: no se tocaba)
   └─ Purchase.status = "received"                               (antes: "draft")
   │
   └─ PurchaseGenerationRequest(idempotency_key, purchase_ids) escrita en el mismo commit
```

## Validaciones / reglas de negocio (sin cambios respecto a spec 158, se siguen cumpliendo)

- Toda la validación de servidor que ya exige spec 158 (proveedor, unidad de compra y precio
  > 0, cantidad ≥ 1, FR-005 de este spec) ocurre **antes** de construir cualquier `Purchase`,
  sin cambios de orden ni de criterio.
- La transacción completa del lote (N órdenes, N movimientos, N aumentos de stock) sigue
  teniendo un único punto de `db.commit()`/`db.rollback()` en `generate_suggested_purchases()`
  (FR-004): si `record_movement()` lanza (p. ej. por un insumo inexistente a mitad del lote),
  el `except` existente revierte todo, incluidas las `Purchase` ya construidas en memoria pero
  no comiteadas.

## Estrategia de rollback

No aplica — no hay migración que revertir. El rollback de esta funcionalidad es revertir el
cambio de código (`receive_immediately` vuelve a su default `False` en el único *call site*
nuevo, o se elimina esa llamada), sin ningún paso de base de datos.
