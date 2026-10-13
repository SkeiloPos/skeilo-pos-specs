# Modelo de datos — Spec 117

**Fecha**: 2026-10-13 · **Spec**: [spec.md](./spec.md) · **Decisiones**: [research.md](./research.md) D1–D8

## Sin migración de Alembic

Esta spec **no añade, modifica ni elimina ninguna columna**. Las cuatro piezas de esquema que
necesita ya existen, creadas por specs anteriores:

| Tabla (`tenant.*`) | Columna | Origen | Uso en esta spec |
|---|---|---|---|
| `cart_items` / `order_items` | `addons_total` (`NUMERIC(12,2)`) | spec 089 | Destino de `Σ(cantidad_adición × precio_adición)` para adiciones "cantidad" (D1) |
| `cart_item_options` / `order_item_options` | `per_line` (`BOOLEAN`) | spec 089 | Se activa también cuando `option_group.selection_mode = 'cantidad'` (D1), no solo bajo la regla de 089 |
| `option_groups` | `max_quantity_per_option`, `max_total_quantity` (`INTEGER`, opcionales) | spec 065 | Se interpretan ahora escalados por la cantidad de producto de la línea al validar (D2), sin cambiar su valor almacenado |
| `option_groups` | `selection_mode` (`'conteo' \| 'cantidad'`) | spec 065 | Pasa a ser, junto con la regla de 089, el criterio que decide `per_line` (D1) |

Esto es deliberado (Principio VI): la corrección es puramente de **comportamiento** (qué fórmula
se aplica y cuándo), no de datos — abrir una migración solo para esto mezclaría dos clases de
cambio sin necesidad.

## Entidades afectadas (sin cambio de esquema, cambio de regla de cálculo)

### `OptionGroup` (spec 065)

Sin campos nuevos. Cambia la **interpretación** de `max_quantity_per_option` y
`max_total_quantity` cuando `selection_mode = 'cantidad'`: ya no son un tope fijo para la línea,
sino un tope **por cada unidad de producto**, escalado en el momento de validar
(`max_quantity_per_option × Cantidad Producto`, `max_total_quantity × Cantidad Producto` — D2).
Un grupo `selection_mode = 'conteo'` no cambia de interpretación (`FR-013`).

### `CartItemOption` / `OrderItemOption` (spec 065 + spec 089)

Sin campos nuevos. Cambia la **condición** que decide `per_line = True` al escribir la fila (D1):

```
per_line = (regla_089: pricing_type == 'con_recargo' AND canal == carrito_QR AND flag activa)
           OR (regla_117: option_group.selection_mode == 'cantidad')
```

Una fila histórica (creada antes de esta spec) no se reescribe — su `per_line` ya persistido
queda intacto (Principio VII); la regla nueva solo aplica a filas que se **crean o editan** desde
que el código entra en vigor, exactamente como ya ocurrió con la regla 089 sobre estas mismas
columnas.

### `CartItem` / `OrderItem` — `line_total` (propiedad, spec 089)

Sin cambio de fórmula: `line_total = unit_price × quantity + addons_total` ya es correcta para
ambos ejes (`pricing_type` y `selection_mode`) porque ambos terminan en el mismo campo `per_line`
por fila. El cambio está en qué filas entran a `addons_total` (D1), no en la fórmula misma.

### `SaleLine` / `SaleItem` (ventas, spec 089)

Sin cambio de esquema (`SaleItem.line_total` ya persistido es autoritativo; el snapshot JSONB
`options` ya tiene la clave opcional `per_line`). Una venta de mostrador o de mesero con una
adición "cantidad" pasa a construir `SaleLine` con `unit_price`/`addons_total` separados en vez de
"folded" (D1), igual que ya hace `cart/service.py` desde la spec 089.

## Cambio de contrato (no de esquema): `CartItemResponse.adjusted_options`

Única pieza nueva de datos de esta spec, y vive solo en la capa de API (Pydantic), no en la base
de datos — es el resultado de un ajuste que ya se escribió en las columnas existentes, nunca un
estado que se persista por separado:

```python
class AdjustedOptionOut(BaseModel):
    option_id: UUID
    option_name: str
    previous_quantity: int
    new_quantity: int

class CartItemResponse(BaseModel):
    ...
    adjusted_options: list[AdjustedOptionOut] = Field(default_factory=list)
```

Ver [contracts/cart-item-auto-adjust.md](./contracts/cart-item-auto-adjust.md) para su contrato
completo. No requiere columna porque no es un hecho que haya que recordar después de la petición
que lo generó — las cantidades ya ajustadas quedan en `CartItemOption.quantity`, que es lo único
que cualquier lectura posterior (`GET /cart`) necesita leer.

## Compatibilidad con datos existentes (Principio VII)

- Ninguna fila existente cambia de valor por esta spec: el cambio de regla solo decide qué pasa
  **al escribir** una fila nueva o editada, nunca recalcula una ya persistida.
- Un pedido o venta confirmado antes de esta funcionalidad conserva exactamente su `unit_price`,
  `addons_total`, `per_line` por opción y consumo de inventario ya registrado — se leen tal cual
  quedaron (`SC-005`).
- No aplica ningún nivel de "reversión de datos" (no hay columna que revertir): la única reversa
  posible es de código (revertir el commit que cambia la condición de `per_line` y el escalado de
  topes), igual de instantánea en cualquier dirección porque no hay backfill de por medio.
