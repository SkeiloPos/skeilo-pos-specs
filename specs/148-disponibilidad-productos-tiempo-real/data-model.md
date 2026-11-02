# Data Model: Disponibilidad de productos en tiempo real

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)

## Cambios de esquema: ninguno

Esta funcionalidad **no agrega tablas, columnas, índices ni migraciones** (Principio VIII). La
disponibilidad es un **estado derivado** de datos que ya existen:

| Dato existente | Rol en esta funcionalidad | Se modifica |
|---|---|---|
| `Product.available` (+ `available_changed_at`, `available_changed_by_name`) | Marca manual «Agotado» (spec 093). `available = false` ⇒ agotado a mano. | **No** (solo se publica el cambio que ya hace `set_availability`) |
| `Product.active`, `Product.tracks_inventory`, `Product.visible_en_qr` | Filtros del menú; `tracks_inventory = false` excluye la receta del cálculo. | No |
| `ProductVariant` (+ `display_name`) | Presentación; nivel 2. | No |
| `RecipeItem(product_variant_id, inventory_item_id, quantity)` | Insumos fijos que consume 1 unidad de la presentación. | No |
| `VariantOptionGroup(min_select, quantity_per_option, option_group_id)` y `OptionGroup(selection_mode)` | Grupos obligatorios y cantidad definida por tamaño. | No |
| `Option(inventory_item_id, item_quantity, active)` | Opción/sabor/salsa/adición; nivel 3. | No |
| `InventoryItem(current_stock, active)` | Existencias; solo se **lee** (el movimiento ya lo hace `record_movement`). | No |

**Compatibilidad con datos existentes**: total — no hay backfill. Al desplegar, el primer cálculo
parte del stock vigente.

**Rollback**: revertir el código. No queda ningún dato propio de la funcionalidad que limpiar. Un
evento ya publicado en Redis es efímero (`REALTIME_STREAM_MAXLEN`) y un cliente viejo lo ignora.

**Datos históricos**: pedidos, ventas y facturas existentes no se leen ni se recalculan.

## Entidades conceptuales (no persistidas)

### Disponibilidad (por elemento)

Estado «se puede pedir / no se puede pedir» en tres niveles. Cada nivel combina fuentes distintas
(research.md D3):

| Nivel | Identificador | Campos | Agotado cuando |
|---|---|---|---|
| **Producto** | `product.id` | `sold_out` (marca manual), `available` (derivado por stock) | `sold_out` **o** `available = false` (sin ninguna presentación activa pedible) |
| **Presentación** | `product_variant.id` | `available` | falta stock de algún `RecipeItem` (solo si `tracks_inventory`) **o** un grupo obligatorio no tiene ninguna opción disponible |
| **Opción / adición** | `option.id` (opción) · `product.id` (adición, que es un producto) | `available` | insumo ligado inactivo o `stock < need` (peor caso del catálogo, regla actual de `_option_availability`) |

Reglas:
- `sold_out` (manual) y `available` (derivado) son **independientes**: el inventario nunca
  modifica la marca manual (FR-011); la marca manual no se levanta por tener insumo.
- Un producto con todas sus presentaciones agotadas es agotado (`available = false`).
- La marca manual existe **solo a nivel de producto** (spec 093).
- Una adición (topping) es un producto: su disponibilidad es la de ese producto y su presentación
  principal. En `MenuToppingResponse.available` el valor combinado es
  `active ∧ ¬sold_out ∧ available`.

### Transición de disponibilidad

Diferencia entre dos cálculos del motor (antes/después) para un mismo elemento. Solo existe si el
estado «pedible» cambió (FR-009). Es la unidad que alimenta `changes[]` del evento.

```text
Transición = { kind, id, product_id?, antes: bool, después: bool }
Evento     = { changes: [ { kind, id, product_id?, …estado absoluto después } ] }
```

### Línea afectada (solo cliente)

Línea de un carrito sin enviar (borrador de la Terminal o carrito QR) cuyo producto, presentación,
opción o adición está agotado, o que un 409 marcó por cantidad. **Derivada**, nunca guardada:

```text
afectada(línea, menúVivo) =
    producto(línea).sold_out OR producto(línea).available == false
 OR presentación(línea).available == false
 OR ∃ opción elegida con available == false
 OR ∃ adición elegida con (sold_out OR available == false)
 OR línea ∈ conflictosPorCantidad            // marcada por un 409 motivo "cantidad"
```

`elementoAgotado(línea)` devuelve cuál (para «Granizado de mora · 16 oz» o el sabor «mora»).
Se vacía sola cuando la condición deja de cumplirse (FR-016). `conflictosPorCantidad` se limpia al
quitar o cambiar la cantidad de la línea.

### Estado de la conexión en vivo (solo cliente)

```text
liveLost = (RealtimeService.status ≠ 'open') sostenido ≥ 5 000 ms
```

Se reinicia al volver a `open`. No es persistido ni compartido.

### Guardia de orden (solo cliente)

```text
lastV:        Map<"kind:id", number>     // última versión aplicada por elemento
snapshotAsOf: number | null              // versión a la que llegó el último snapshot
aplicar(cambio, v) ⇔ v > (lastV[kind:id] ?? 0) AND v > (snapshotAsOf ?? 0)
```

## Formas de datos que viajan

Detalladas en los contratos:

| Forma | Dónde | Contrato |
|---|---|---|
| `AvailabilityChangedEvent` | SSE, canales `staff` + `menu:{tenant}` | [availability-event.md](./contracts/availability-event.md) |
| `AvailabilitySnapshot` | `GET /menu/availability`, `GET /menu/qr-token/{token}/availability` | [availability-snapshot-api.md](./contracts/availability-snapshot-api.md) |
| `SoldOutConflict` (409) | respuestas de crear/agregar/enviar/cobrar | [sold-out-conflict.md](./contracts/sold-out-conflict.md) |

## Estado interno del servidor (no persistido)

`Session.info` (por transacción, descartado al cerrar):

| Clave | Contenido | Escribe | Lee |
|---|---|---|---|
| `tenant_schema` | schema del tenant | `with_db()` | gancho (resuelve `tenant_id`) |
| `availability_stock` | `{item_id: (stock_inicial, stock_final)}` | `record_movement`, `apply_adjustment` | gancho `before_commit` |
| `availability_pending` | `list[cambio]` ya calculada | gancho `before_commit` | gancho `after_commit` |

Se limpian en `after_commit` y `after_rollback`.
