# Contrato API: Compra Sugerida

Dos endpoints nuevos bajo el router `inventory` existente (`app/api/v1/inventory/router.py`),
mismo prefijo `/inventory`, mismo gate de módulo (`require_module_access("inventario")`) que
ya aplica a todo ese router. Sigue el estilo de los endpoints hermanos `/items`, `/items/low-stock`
y `/purchases`/`/purchases/order` (DTOs Pydantic, `response_model`, `Page[...]` para paginar).

## `GET /inventory/purchases/suggested`

Lista, paginada, los insumos activos en o bajo su mínimo con sus datos de proveedor
preferido precargados. Solo lectura — mismo guard que `/purchases` (`get_current_user`, sin
exigir admin).

**Query params**:
- `page: int = 1` (`ge=1`)
- `size: int = 20` (`ge=1, le=100`)

**Response `200`**: `Page[SuggestedPurchaseLineResponse]` (ver data-model.md). Orden fijo
`deficit DESC` (clarificación 3 del spec) — este endpoint no acepta parámetro de orden
distinto, no lo pide ningún escenario del spec.

**Caso "no hay insumos bajo mínimo" (FR-017)**: `Page` con `items: []`, `total: 0` —
el frontend muestra "No hay insumos bajo mínimo" y deshabilita "Generar órdenes de compra"
cuando `total == 0` en la primera página, sin necesidad de un código de estado especial.

**Errores**:
- `401`/`403`: mismos que cualquier otro endpoint de `inventory` sin sesión válida o sin el
  módulo `inventario` habilitado en el plan del tenant (`require_module_access`).

## `POST /inventory/purchases/suggested/generate`

Genera, en una sola transacción, una `Purchase` en `draft` por cada proveedor distinto entre
las líneas recibidas (FR-008/FR-009). Mismo guard que `/purchases/order`
(`require_tenant_admin`).

**Request body**: `GenerateSuggestedPurchasesRequest` (ver data-model.md) —
`idempotency_key` + `lines: SuggestedPurchaseLineIn[]` (mínimo 1).

**Response `201`** (primera vez que se procesa esta `idempotency_key`):
`GenerateSuggestedPurchasesResponse` — `purchases: PurchaseResponse[]`, una por proveedor
distinto, cada una con sus líneas/cantidades/precios ya resueltos a unidad base
(FR-011, mismo contrato que ya devuelve `POST /purchases/order`).

**Response `200`** (reintento con una `idempotency_key` ya procesada, FR-010/SC-005): mismo
`GenerateSuggestedPurchasesResponse`, con las `Purchase` que ya se habían creado la primera
vez — no se vuelve a ejecutar ninguna validación ni se crea nada nuevo.

**Response `422`** (alguna línea falla la revalidación de servidor — FR-011/FR-012; ninguna
orden se crea):

```json
{
  "detail": {
    "message": "No se pudo generar la compra sugerida",
    "lines": [
      {
        "inventory_item_id": "…",
        "reason": "unit_price_zero" // o "quantity_below_minimum" | "supplier_item_inactive" | "supplier_item_not_found"
      }
    ]
  }
}
```

El frontend usa `lines[].inventory_item_id` para resaltar la fila correspondiente con su
mensaje (Acceptance Scenario 2 de la Historia 2), sin necesidad de volver a pedir el listado.

**Response `500`/excepción no controlada durante la creación de alguna orden** (Acceptance
Scenario 3 de la Historia 2): la transacción completa se revierte (`db.rollback()`), **no**
se inserta la fila de idempotencia (para que un reintento con la misma clave sí vuelva a
intentarlo, no quede "atascado" en un fallo parcial), y el endpoint responde un error 5xx
genérico; el frontend conserva en pantalla la selección/cantidades/proveedores/precios
ajustados (FR-019) porque nunca los perdió — el error solo afecta la respuesta de la
solicitud, no el estado local del componente.

**Errores de autorización**: `401`/`403` igual que `/purchases/order` (requiere admin del
tenant con el módulo `inventario` habilitado).

## Endpoint reutilizado sin cambios

`GET /inventory/items/{item_id}/suppliers` → `SupplierItemResponse[]` (ya existe) se usa, sin
ninguna modificación, para poblar el selector de "proveedor alternativo" de una fila cuando
el usuario lo abre (research.md D4). No se documenta de nuevo aquí porque su contrato no
cambia.
