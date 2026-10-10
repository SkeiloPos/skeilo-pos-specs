# Data Model: comprar en la presentación real, no en la unidad base

Convención del repositorio: identificadores de código en inglés (igual que spec 106).

## Entidad modificada: `PurchaseItem` (`app/models/purchase.py`) — ya existe

| Columna | Tipo | Cambio |
|---|---|---|
| `supplier_item_id` | `UUID NULL, FK → supplier_items.id` | **Ya existe** desde la spec 106 (nacía siempre `NULL`, sin poblar). Esta spec es la que la puebla de verdad cuando la línea se registró contra una presentación. |
| `presentation_quantity` | `Numeric(12, 3) NULL` | **Nueva.** Cuántas presentaciones capturó el administrador (p. ej. `3`, de "3 Bolsa x 500 g"). `NULL` si la línea se compró directo en unidad base (comportamiento actual, FR-007). |
| `presentation_label` | `String(100) NULL` | **Nueva.** Copia del texto de `SupplierItem.presentation` **en el momento de la compra** (research.md D1) — no se resuelve por `join` en vivo, para que editar la presentación después no altere cómo se ve una compra ya registrada (Principio VII). `NULL` junto con `presentation_quantity`. |

**Las columnas `quantity` y `unit_cost` ya existentes no cambian de tipo ni de significado**:
siguen siendo, siempre, la cantidad y el costo en la unidad base del insumo — lo que cambia es
que, cuando `supplier_item_id` no es `NULL`, son valores **derivados** (calculados por el
servicio) en vez de **capturados** directamente del request.

## Esquemas Pydantic (`app/api/v1/inventory/schemas.py`)

### `PurchaseItemIn` (alta directa y creación de orden)

```python
class PurchaseItemIn(BaseModel):
    inventory_item_id: UUID
    quantity: Decimal | None = Field(None, gt=0, max_digits=12, decimal_places=3)
    unit_cost: Decimal = Field(0, ge=0, max_digits=12, decimal_places=2)
    supplier_item_id: UUID | None = None
    presentation_quantity: Decimal | None = Field(None, gt=0, max_digits=12, decimal_places=3)
    presentation_unit_cost: Decimal | None = Field(None, ge=0, max_digits=12, decimal_places=2)

    @model_validator(mode="after")
    def _exactly_one_mode(self):
        """FR-001/FR-002/FR-007: exactamente un camino por línea (research.md D2)."""
        if self.supplier_item_id is not None:
            if self.presentation_quantity is None:
                raise ValueError(
                    "presentation_quantity es obligatorio cuando se indica supplier_item_id"
                )
            if self.quantity is not None:
                raise ValueError("no se puede indicar quantity junto con supplier_item_id")
        elif self.quantity is None:
            raise ValueError("quantity es obligatorio cuando no se indica supplier_item_id")
        return self
```

`unit_cost` sigue existiendo para el camino directo (igual que hoy); `presentation_unit_cost` es
el costo de **una** presentación (Clarifications, Sesión 2026-10-09) para el camino nuevo — nunca
conviven los dos con valor en la misma línea.

### `PurchaseReceiveItemIn` (recepción parcial/total)

```python
class PurchaseReceiveItemIn(BaseModel):
    purchase_item_id: UUID
    quantity: Decimal | None = Field(None, gt=0, max_digits=12, decimal_places=3)
    presentation_quantity: Decimal | None = Field(None, gt=0, max_digits=12, decimal_places=3)

    @model_validator(mode="after")
    def _exactly_one_mode(self):
        if (self.quantity is None) == (self.presentation_quantity is None):
            raise ValueError("indica exactamente uno de quantity o presentation_quantity")
        return self
```

El servicio decide cuál de los dos campos *debía* venir mirando si el `PurchaseItem` que se
recibe tiene `supplier_item_id` — si lo tiene, `presentation_quantity` es el único válido (y el
factor para convertirlo se lee del `SupplierItem` en ese momento, research.md D4, nunca del
request); si no lo tiene, `quantity` es el único válido (comportamiento actual).

### Respuestas (`PurchaseItemResponse`)

```python
class PurchaseItemResponse(BaseModel):
    id: UUID
    inventory_item_id: UUID
    quantity: Decimal
    received_quantity: Decimal
    unit_cost: Decimal
    supplier_item_id: UUID | None = None
    presentation_quantity: Decimal | None = None
    presentation_label: str | None = None
    # Denormalizado desde SupplierItem.conversion_factor al resolver la respuesta (no es una
    # columna de PurchaseItem) -- seguro de exponer como snapshot porque FR-014 (spec 106) ya
    # bloquea editar ese factor una vez usado en una compra, y esta fila es ese mismo uso. Lo
    # necesita la UI de recepción para mostrar "pendiente en presentaciones", no solo en unidad
    # base (ver tasks.md, Historia 3).
    conversion_factor: Decimal | None = None

    model_config = ConfigDict(from_attributes=True)
```

Los tres campos nuevos son `None` para cualquier línea comprada directo en unidad base
(incluidas todas las compras ya existentes) — el frontend compone "3 Bolsa x 500 g" a partir de
`presentation_quantity` + `presentation_label` cuando ambos no son `None` (FR-011); no hace falta
que el backend entregue un texto ya concatenado.

## Función nueva: `supplier_items.apply_purchase_cost`

```python
def apply_purchase_cost(db: Session, relation: SupplierItem, cost_per_presentation: Decimal) -> None:
    """RN-15: fija el último costo de la relación al precio pactado en esta compra. Sin
    commit propio -- el llamador (create_purchase/create_purchase_order) decide cuándo cerrar
    la transacción, mismo patrón que _apply_preferred_swap."""
    relation.last_cost = cost_per_presentation
    relation.last_cost_at = utc_now()
```

No valida nada propio (factor > 0, proveedor de sistema, etc.) porque, para que exista un
`supplier_item_id` válido que llegue hasta aquí, esas validaciones ya se aplicaron al elegir la
presentación en el servicio de compras (ver `contracts/api.md`).

## Migración (una sola, vía `@for_each_tenant_schema`, mismo patrón que spec 106)

**Upgrade**: `op.add_column("purchase_items", presentation_quantity NUMERIC(12,3) NULL)`,
`op.add_column("purchase_items", presentation_label VARCHAR(100) NULL)`. `supplier_item_id` no
se toca — ya existe desde la migración de spec 106.

**Compatibilidad con datos existentes**: ninguna línea de compra ya registrada cambia de
significado — ambas columnas nuevas nacen `NULL`, y nada las puebla retroactivamente.

**Downgrade**: `op.drop_column("purchase_items", "presentation_label")`,
`op.drop_column("purchase_items", "presentation_quantity")`. Lossy solo para la trazabilidad
agregada por esta propia funcionalidad (qué presentación se usó) — `quantity`/`unit_cost` en
unidad base, que es lo que de verdad mueve el inventario y afecta reportes, nunca se toca.
