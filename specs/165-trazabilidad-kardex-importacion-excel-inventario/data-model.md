# Data Model: Trazabilidad de kardex en la importación masiva de Excel de inventario

## Sin migración

Esta funcionalidad no añade ni modifica ninguna tabla, columna ni constraint de base de
datos. Las entidades que participan ya existen con el significado necesario; el cambio es
puramente de **comportamiento de servicio** (por qué camino llega un valor a
`current_stock`, no qué columnas tiene la tabla) y de **catálogo de aplicación** (valores de
texto libre nuevos en campos que ya existen, sin `CheckConstraint`, RN-INV-12).

## Entidades existentes reutilizadas (sin cambios de esquema)

- **`InventoryMovement`** (`app/models/inventory_movement.py`, tabla
  `tenant.inventory_movements`): sin cambios de columnas. Esta funcionalidad agrega dos
  *valores* nuevos a columnas de texto libre ya existentes:
  - `reason`: nuevo valor `"importacion_masiva"` (constante `IMPORTACION_MASIVA`), séptimo
    motivo canónico del catálogo de aplicación (`app/core/inventory_reasons.py`), válido
    solo para movimientos `type="in"` (creación) o `type="adjustment"` (actualización) —
    nunca `type="out"`.
  - `reference_type`: nuevo valor `"import_job"` (constante `REF_IMPORT_JOB`), usado junto a
    `reference_id=<InventoryImportJob.id>` — el mismo patrón polimórfico (tipo + id, sin FK,
    índice compuesto `idx_invmov_ref` ya existente) que ya usan `REF_SALE`/`REF_ORDER`/
    `REF_PURCHASE`.
  - `type`: sin valores nuevos. Se usan los dos ya existentes relevantes para esta spec —
    `"in"` para el stock inicial de un insumo creado, `"adjustment"` para la diferencia al
    actualizar uno existente.
- **`InventoryItem`** (`app/models/inventory_item.py`): sin cambios de columnas.
  `current_stock` sigue siendo el campo que `record_movement`/`apply_adjustment` ya
  actualizan de forma atómica bajo `SELECT ... FOR UPDATE`; esta spec solo cambia que la
  importación masiva deje de escribirlo por `setattr`/constructor directo y pase a hacerlo
  exclusivamente a través de esas dos funciones. `unit_cost` no cambia de ningún modo —sigue
  siendo un `setattr`/constructor directo, igual que hoy (FR-009).
- **`InventoryImportJob`** (`app/models/inventory_import_job.py`, tabla
  `tenant.inventory_import_jobs`, spec 109): sin cambios de columnas. Pasa a ser también el
  origen citado en `InventoryMovement.reference_id` de los movimientos que genera; sus
  columnas de conteo (`created_count`, `updated_count`, `failed_count`, `errors` JSONB) ya
  reciben, sin cambios de forma, una fila fallida más cuando `apply_adjustment` rechaza el
  ajuste por dejaría el stock negativo (FR-006) — el `motivo` de esa entrada en `errors` es
  el mensaje de `InsufficientStockError` ("El ajuste dejaría el stock de '<nombre>' en
  negativo."), igual que cualquier otro `ValueError`/`HTTPException` que ya captura
  `validar_y_aplicar_fila()`.

## Catálogo de aplicación extendido (`app/core/inventory_reasons.py`)

Sin `CheckConstraint` en BD (RN-INV-12, decisión deliberada preexistente). Nuevas constantes
de módulo:

```python
IMPORTACION_MASIVA = "importacion_masiva"   # motivo — séptimo de RN-INV-13
REF_IMPORT_JOB = "import_job"                # referencia — origen InventoryImportJob
```

`ENTRADA_REASONS` pasa de `(COMPRA, AJUSTE)` a `(COMPRA, AJUSTE, IMPORTACION_MASIVA)`.
`SALIDA_REASONS` **no cambia** — `IMPORTACION_MASIVA` nunca es válido para `type="out"`
(FR-007).

## Firma extendida (`app/inventory_engine/stock.py`)

`apply_adjustment()` gana dos parámetros opcionales, con default `None` para no alterar
ningún caller existente:

```python
def apply_adjustment(
    db: Session, inventory_item_id: UUID, *, signed_delta: Decimal,
    reason: Optional[str] = None, user_id: Optional[UUID] = None,
    reference_type: Optional[str] = None,    # nuevo
    reference_id: Optional[UUID] = None,      # nuevo
) -> InventoryMovement: ...
```

## Relaciones / flujo de datos

```text
Fila del Excel (code, name, type, stock, minimo, costo, …)
   │
   ▼
validar_y_aplicar_fila(db, fila)
   │
   ├─ existente = InventoryItem con ese `code` (o None)
   ├─ stock_antes = existente.current_stock si existe, si no 0
   ├─ campos = {name, type, min_stock, unit_cost, …}   (SIN current_stock)
   │
   ├─ item, creado = resolve_or_create_by_code(db, code, **campos)
   │
   ├─ si creado y stock > 0:
   │      record_movement(type="in", quantity=stock,
   │                       reason=IMPORTACION_MASIVA, reference_type=REF_IMPORT_JOB,
   │                       reference_id=job.id)
   │        → inserta InventoryMovement + current_stock pasa de 0 a `stock`
   │
   ├─ si no creado:
   │      delta = stock - stock_antes
   │      si delta != 0:
   │          apply_adjustment(signed_delta=delta,
   │                            reason=IMPORTACION_MASIVA, reference_type=REF_IMPORT_JOB,
   │                            reference_id=job.id)
   │            → inserta InventoryMovement (type="adjustment") + current_stock += delta
   │            → si current_stock + delta < 0: InsufficientStockError (capturada como
   │              fila fallida, current_stock SIN modificar)
   │
   └─ item.unit_cost = costo   (sin cambios, directo, fuera del mecanismo de movimientos)
```
