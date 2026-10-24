# Contrato: GET /inventory/items

Endpoint existente (`pos-backend/app/api/v1/inventory/router.py`, función `list_items`). Esta
spec amplía su comportamiento de búsqueda y agrega un query param nuevo; no cambia el método,
la ruta, ni el `response_model`.

## Request

`GET /inventory/items`

| Query param | Tipo | Requerido | Estado | Descripción |
|---|---|---|---|---|
| `page` | `int` (≥1) | No (default `1`) | Sin cambios | Página de resultados |
| `size` | `int` (1–100) | No (default `20`) | Sin cambios | Tamaño de página |
| `search` | `string` | No | **Comportamiento ampliado** | Antes: coincidencia parcial insensible a mayúsculas solo contra `name`. Ahora: coincidencia parcial insensible a mayúsculas contra `name` **o** `code` (FR-001/FR-002/FR-003). El contrato del parámetro (un solo string) no cambia. |
| `type` | `InventoryItemType` (enum) | No | Sin cambios | Filtro por tipo de insumo |
| `active` | `bool` | No | Sin cambios | Filtro por estado activo/inactivo |
| `low_stock` | `bool` | No | Sin cambios | Solo insumos en o bajo el mínimo |
| `supplier_id` | `UUID` | No | **Nuevo** | FR-004/FR-005: filtra solo insumos con una relación **activa** (`SupplierItem.active = true`) con este proveedor. Si el proveedor no existe o no tiene insumos vinculados activos, la lista queda vacía (no es un 404 — mismo tratamiento que hoy tiene `type`/`active` sin coincidencias). |

Todos los parámetros presentes se combinan con intersección (`AND`) entre sí; `search` combina
con `OR` únicamente entre `name` y `code` para el mismo texto (FR-006, ver research.md D5).

## Response

Sin cambios de forma: `Page[InventoryItemResponse]` (mismo esquema de paginación y de item ya
existente). El contenido de `items` refleja los nuevos criterios de filtrado cuando aplican.

## Casos de contrato a verificar (trazados a Acceptance Scenarios de spec.md)

1. `search=<código parcial de un insumo>` → el insumo aparece en `items` (Historia 1, escenario 1).
2. `search=<nombre parcial de un insumo>` → sigue apareciendo igual que antes del cambio
   (Historia 1, escenario 2 — regresión FR-010).
3. `search=<texto que coincide con el nombre de A y con el código de B>` → tanto A como B
   aparecen en `items` (Historia 1, escenario 3).
4. `search=<texto sin coincidencias>` → `items` vacío, `total` en `0` (Historia 1, escenario 4).
5. `supplier_id=<id de un proveedor con insumos activos vinculados>` → `items` contiene
   únicamente esos insumos (Historia 2, escenario 1).
6. `supplier_id=<id de un proveedor sin insumos vinculados activos>` → `items` vacío (Historia
   2, escenario 2).
7. `supplier_id` omitido tras haber estado presente → `items` vuelve a incluir insumos de todos
   los proveedores, sujeto a los demás filtros activos (Historia 2, escenario 3).
8. `search` + `supplier_id` simultáneos → `items` cumple ambos criterios a la vez (Historia 3,
   escenario 1).
9. `search` + `supplier_id` + `type` + `active` simultáneos → `items` cumple los cuatro
   criterios a la vez (Historia 3, escenario 2).
10. Cualquier cambio de `search`, `type`, `active` o `supplier_id` entre dos llamadas sucesivas
    desde el frontend reinicia `page` a `1` (FR-007) — este es un contrato de comportamiento del
    **frontend** (el endpoint en sí es stateless y siempre respeta el `page` que reciba), ver
    quickstart.md.

## Sin contrato nuevo de UI

El filtro de proveedor en el frontend no introduce un endpoint nuevo: el selector se puebla con
el listado de proveedores activos ya expuesto por `GET /inventory/suppliers` (o el endpoint
equivalente ya consumido hoy por `suppliers.service.ts`), sin cambios a ese contrato.
