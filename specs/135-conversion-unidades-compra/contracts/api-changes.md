# Contratos de API: Compra de Insumos con Conversión a Unidad Base

Todos los endpoints exigen autenticación (`get_current_user`) y módulo `inventario`
(`require_module_access`), igual que hoy. Solo se documentan los cambios respecto al
contrato actual; lo no mencionado no cambia.

## `GET /unit-measures` (modifica)

Nuevo query param:

| Param | Tipo | Notas |
|---|---|---|
| `dimension` | string, opcional | Filtra por grupo de medida exacto. Usado por el selector de unidad de una línea de compra: `GET /unit-measures?dimension=Masa&active=true`. |

`UnitMeasureResponse` gana dos campos:

```json
{
  "id": "uuid",
  "name": "Kilogramo",
  "abbreviation": "KG",
  "dimension": "Masa",
  "factor_to_base": 1000.000000,
  "active": true,
  "created_at": "...",
  "updated_at": "..."
}
```

## `POST /unit-measures` (modifica)

`UnitMeasureCreate` gana campos obligatorios:

```json
{
  "name": "Kilogramo",
  "abbreviation": "KG",
  "dimension": "Masa",
  "factor_to_base": 1000.000000
}
```

Validación: `factor_to_base > 0`.

## `PATCH /unit-measures/{id}` (modifica)

`UnitMeasureUpdate` gana `dimension`/`factor_to_base` opcionales.

- Cambiar `name`, `abbreviation` o `active`: sin cambio de autorización (igual que hoy).
- Cambiar `factor_to_base`: **requiere rol ADMIN del tenant** (403 para cualquier otro
  rol, FR-011a). Si el valor nuevo difiere del actual, se inserta una fila en
  `unit_measure_factor_changes` con `old_factor`/`new_factor`/`changed_by`/`changed_at`
  (FR-011).
- Cambiar `dimension`: sin restricción adicional de rol (no lo pide la spec), pero no
  afecta compras ya confirmadas (`PurchaseItem.conversion_factor_applied` es inmutable,
  FR-010).

Respuestas nuevas:
- `403`: `"Tenant admin access required"` — intento de cambiar `factor_to_base` sin rol
  ADMIN.

## `GET /unit-measures/{id}/factor-changes` (nuevo)

Historial consultable de cambios de factor (FR-011).

```http
GET /unit-measures/{id}/factor-changes
```

```json
[
  {
    "id": "uuid",
    "unit_measure_id": "uuid",
    "old_factor": 1000.000000,
    "new_factor": 1100.000000,
    "changed_by": "uuid",
    "changed_at": "2026-10-24T10:00:00Z"
  }
]
```

## `PATCH /inventory/items/{id}` (modifica)

Nueva regla de validación (FR-002): si `body.unit_measure_id` viene y difiere del
`unit_measure_id` actual del insumo, y existe al menos un `InventoryMovement` para ese
insumo → `409` con detalle:
`"No se puede cambiar la unidad base de un insumo con movimientos registrados"`.

## `POST /inventory/purchases` y `POST /inventory/purchases/orders` (modifica)

`PurchaseItemIn` gana un tercer modo, alternativo a `quantity`/`unit_cost` directos y a
`supplier_item_id`+`presentation_*` (spec 106/107, sin cambios):

```json
{
  "inventory_item_id": "uuid",
  "unit_measure_id": "uuid",
  "quantity": 2,
  "unit_cost": 8000
}
```

Reglas del nuevo modo (mutuamente excluyente con `supplier_item_id`):
- `unit_measure_id` identifica la unidad en la que se capturó `quantity`/`unit_cost`
  (p. ej. "KG"), no necesariamente la unidad base del insumo.
- El servidor resuelve el factor de conversión del `unit_measure_id` elegido hacia la
  unidad base del insumo (FR-008; nunca se acepta un factor en el request).
- `422` si la `dimension` de `unit_measure_id` no coincide con la del insumo (RN-CAT-40,
  reutilizando `app/core/units.py::convert`).
- `422` si `unit_measure_id` no está activa (FR-005).
- `422` si el tenant tiene `unit_conversion_enabled = false` y `unit_measure_id` no es
  la unidad base del insumo (FR-016).
- `422` si `quantity <= 0` o `unit_cost <= 0` (FR-015 + edge case de costo inválido).

`PurchaseItemResponse` gana:

```json
{
  "unit_measure_id": "uuid",
  "conversion_factor_applied": 1000.000000,
  "quantity_base": 2000.000000,
  "cost_base": 8.000000
}
```

(`quantity`/`unit_cost` siguen presentes y ahora significan explícitamente "lo
originalmente capturado", no necesariamente la unidad base.)

## `POST /inventory/purchases/{id}/void` (nuevo)

Anula una compra confirmada (US3, FR-012/FR-013).

```http
POST /inventory/purchases/{id}/void
```

- `404` si la compra no existe.
- `409` si ya está anulada (`voided_at` no NULL) — rechaza doble anulación (FR-013).
- Éxito: por cada `PurchaseItem`, `record_movement(type="out", quantity=
  pi.quantity_base, reason=AJUSTE, reference_type=REF_PURCHASE_VOID, reference_id=
  purchase.id)` — resta exactamente la cantidad base guardada en la línea (FR-012).
  Marca `voided_at`/`voided_by`. Devuelve `PurchaseResponse` con esos dos campos nuevos.

```json
{
  "id": "uuid",
  "status": "received",
  "voided_at": "2026-10-24T12:00:00Z",
  "voided_by": "uuid",
  "...": "resto de PurchaseResponse sin cambios"
}
```

## `GET /tenant-info` / `PATCH /tenant-info` (modifica — nombre real del endpoint según
`app/core/tenant` del backend; ajustar al handler existente de la configuración del
tenant)

Gana `unit_conversion_enabled: bool` (FR-016), editable únicamente por un ADMIN del
tenant (mismo criterio que el resto de configuración del negocio en esa pantalla).

## Vista previa de equivalencia (FR-014) — no es un endpoint nuevo

La vista previa ("= 2.000 g") se calcula **en el cliente** (frontend), con el
`factor_to_base` que ya trae `GET /unit-measures` — no requiere una llamada al servidor
por cada tecla. El servidor solo valida/confirma al registrar la compra; antes de
confirmar, el stock no se toca (ya es así hoy: `create_purchase`/`create_purchase_order`
solo corren al hacer `POST`).
