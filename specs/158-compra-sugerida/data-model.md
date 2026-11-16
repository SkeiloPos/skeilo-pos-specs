# Data Model: Compra Sugerida de Insumos

## Entidades existentes reutilizadas (sin cambios de esquema)

Estas entidades ya existen en `pos-backend` (esquema `tenant`) y esta funcionalidad solo las
lee o crea filas en ellas con los flujos existentes — ningún campo nuevo, ninguna migración
sobre estas tablas.

- **`InventoryItem`** (`app/models/inventory_item.py`): `current_stock`, `min_stock`,
  `unit_measure_id`, `active`. El déficit que ordena el listado (clarificación 3) se calcula
  en el query, no se guarda: `min_stock - current_stock` (puede ser negativo si el insumo no
  está bajo mínimo, pero esos no se listan).
- **`Supplier`** (`app/models/supplier.py`): `name`, `active`, `is_system` (los proveedores
  de sistema, p. ej. "Compra ocasional", nunca son preferidos y no participan aquí).
- **`SupplierItem`** (`app/models/supplier_item.py`): relación N:M insumo-proveedor;
  `preferred`, `active`, `unit_measure_id`/`presentation`/`conversion_factor` (modo
  nuevo/legado vía `effective_presentation`/`effective_conversion_factor`), `last_cost`. Es
  la fuente de "proveedor preferido", "unidad de compra", "precio" y "equivalencia" de cada
  fila (FR-002/FR-004/FR-005/FR-006).
- **`Purchase`** / **`PurchaseItem`** (`app/models/purchase.py`): cada generación exitosa crea
  N `Purchase` nuevas con `status="draft"` (una por proveedor distinto entre las líneas
  seleccionadas, FR-008) y sus `PurchaseItem` asociados, exactamente con el mismo significado
  que ya tienen hoy para cualquier otra orden de compra en borrador. `PurchaseItem.supplier_item_id`
  queda poblado (modo presentación, spec 106/107) para cada línea generada, igual que en
  `create_purchase_order` cuando la línea trae `supplier_item_id`.

Ninguna de estas entidades cambia su significado histórico: una `Purchase` en `draft` creada
por esta funcionalidad es indistinguible, para el resto del sistema (recepción, anulación,
reportes), de una creada manualmente desde "Nueva compra" — comparten el mismo modelo y el
mismo ciclo de vida (draft → partial/received, o anulada).

## Entidad nueva

### `PurchaseGenerationRequest` (tabla `purchase_generation_requests`, esquema `tenant`)

Registra cada solicitud de generación ya procesada, para que un reintento con la misma clave
de idempotencia (FR-010, SC-005) devuelva el mismo resultado sin crear órdenes duplicadas.

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID (PK) | `UUIDPrimaryKeyMixin`, igual que el resto del modelo |
| `idempotency_key` | `String(100)`, NOT NULL | Único **por tenant** (el esquema ya aísla por tenant, así que un índice único simple en esta tabla del esquema `tenant` basta) |
| `purchase_ids` | `ARRAY(UUID)` o `JSONB`, NOT NULL | Las `Purchase.id` creadas por esta solicitud, en el mismo orden en que se devuelven en la respuesta |
| `created_at` | `DateTime`, server_default `now()` | Para poder purgar/auditar más adelante si se necesita; esta spec no define retención |

**Validaciones / reglas de negocio**:
- Único índice: `ux__purchase_generation_requests__idempotency_key` sobre `idempotency_key`.
- Al recibir una solicitud de generación: si ya existe una fila con esa `idempotency_key`,
  el endpoint devuelve las `Purchase` ya existentes en `purchase_ids` (200, no 201) **sin**
  ejecutar de nuevo ninguna validación ni creación — mismo criterio de "reenvío reconocido"
  que pide FR-010/Assumptions. Si no existe, se procesa normalmente y, solo si la transacción
  completa (N órdenes) tiene éxito, se inserta esta fila junto con las `Purchase` en el mismo
  commit.
- No se referencia desde ningún otro lado (no tiene FK entrante); si en el futuro se purga,
  no rompe nada — es puramente un registro de deduplicación, no un documento de negocio.

**Estrategia de migración**: `CREATE TABLE tenant.purchase_generation_requests (...)` nueva,
vía Alembic, aplicada a cada esquema de tenant existente igual que cualquier otra migración
de este proyecto (schema-per-tenant). No requiere backfill: una tabla vacía al desplegar es
el estado correcto (no hay solicitudes "ya procesadas" antes de que la funcionalidad exista).

**Estrategia de rollback**: `DROP TABLE tenant.purchase_generation_requests` en el
`downgrade()` de la misma migración; no afecta a ninguna otra tabla ni dato histórico (no
tiene FKs salientes hacia `purchases`, solo guarda los UUID como valor, para que borrar esta
tabla de deduplicación nunca pueda arrastrar ni invalidar una `Purchase` ya creada).

## DTOs de la capa API (nuevos, Pydantic — no son tablas)

### Lectura — `GET /inventory/purchases/suggested`

**`SuggestedPurchaseLineResponse`** (una fila del listado):

| Campo | Tipo | Origen |
|---|---|---|
| `inventory_item_id` | UUID | `InventoryItem.id` |
| `code`, `name` | str | `InventoryItem.code`, `.name` |
| `current_stock`, `min_stock` | Decimal | `InventoryItem.current_stock`, `.min_stock` |
| `deficit` | Decimal | `min_stock - current_stock`, calculado en el query, usado para el orden por defecto |
| `base_unit_abbreviation` | str | `InventoryItem.unit_measure.abbreviation` |
| `supplier_item_id` | UUID \| null | `SupplierItem.id` de la relación **preferida** activa, si existe |
| `supplier_id`, `supplier_name` | UUID/str \| null | de esa relación preferida |
| `purchase_unit_label` | str \| null | `SupplierItem.effective_presentation` |
| `conversion_factor` | Decimal \| null | `SupplierItem.effective_conversion_factor` |
| `unit_price` | Decimal \| null | `SupplierItem.last_cost` |
| `suggested_quantity` | Decimal | `1` siempre al abrir (FR-003) — no se persiste, el cliente la recalcula localmente al ajustar |
| `is_preselected` | bool | `true` solo si `supplier_item_id`, `purchase_unit_label` y `unit_price` (> 0) están completos (FR-005/FR-006) |
| `missing_supplier_reason` | str \| null | `"Sin proveedor configurado. Elige uno."` cuando `is_preselected` es `false` (FR-006) |

Paginada como `Page[SuggestedPurchaseLineResponse]` (mismo contrato `Page` que ya usan
`/items` y `/purchases`), ordenada por `deficit DESC` por defecto (clarificación 3).

No incluye los proveedores alternos de cada fila (ver research.md D4): esos se piden aparte.

### Lectura — alternos de una fila (sin endpoint nuevo)

`GET /inventory/items/{item_id}/suppliers` (ya existe, `SupplierItemResponse[]`) — se usa
sin cambios cuando el usuario abre el selector de proveedor de una fila concreta (FR-004).

### Escritura — `POST /inventory/purchases/suggested/generate`

**`GenerateSuggestedPurchasesRequest`**:

| Campo | Tipo | Notas |
|---|---|---|
| `idempotency_key` | `str`, requerido | Generado por el cliente (Assumptions) |
| `lines` | `list[SuggestedPurchaseLineIn]`, mínimo 1 | Las filas que el usuario dejó marcadas |

**`SuggestedPurchaseLineIn`**:

| Campo | Tipo | Notas |
|---|---|---|
| `inventory_item_id` | UUID | |
| `supplier_item_id` | UUID | La relación proveedor-insumo elegida (preferida o alterna) — de aquí el servidor deriva el `supplier_id` para agrupar (FR-008) |
| `presentation_quantity` | `Decimal`, `ge=1` | Cantidad en unidad de compra (FR-003: nunca `< 1`) |
| `presentation_unit_cost` | `Decimal`, `gt=0` | Precio para **esta** generación (FR-007: no persiste a `SupplierItem.last_cost`) |

**`GenerateSuggestedPurchasesResponse`**:

| Campo | Tipo | Notas |
|---|---|---|
| `purchases` | `list[PurchaseResponse]` | Reusa el `PurchaseResponse` que ya devuelve `/purchases`/`/purchases/order`, una por proveedor distinto |

**Validación de servidor (FR-011/FR-012, nunca confía en lo enviado por pantalla)**:
reconsulta cada `supplier_item_id` (activo, con factor de conversión resuelto, `last_cost`
no aplica aquí porque el precio de esta generación es el enviado), exige
`presentation_quantity >= 1` y `presentation_unit_cost > 0`; si cualquier línea falla, el
error identifica la línea (`inventory_item_id`) y el motivo, y la respuesta es 422 sin haber
creado ninguna `Purchase` (transacción completa revertida).

## Relaciones / flujo de datos

```text
InventoryItem (current_stock <= min_stock, active)
   │ 1
   │ preferida activa
   ▼
SupplierItem (preferred=true, active=true) ──► Supplier
   │ effective_presentation / effective_conversion_factor / last_cost
   ▼
SuggestedPurchaseLineResponse (fila en pantalla, ajustable)
   │ el usuario marca, ajusta cantidad/proveedor/precio
   ▼
SuggestedPurchaseLineIn[] (POST .../generate, agrupadas por SupplierItem.supplier_id)
   │ una Purchase(draft) por grupo, en una sola transacción
   ▼
Purchase (draft) ──1:N──► PurchaseItem (supplier_item_id, presentation_quantity, …)
   │
   └─ PurchaseGenerationRequest(idempotency_key, purchase_ids) escrita en el mismo commit
```
