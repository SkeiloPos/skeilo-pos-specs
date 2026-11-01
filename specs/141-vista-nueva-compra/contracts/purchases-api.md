# Contrato: endpoints de compras usados por la vista nueva

Todos los endpoints ya existen en `pos-backend/app/api/v1/inventory/router.py` y se
reutilizan sin cambios salvo donde se indica explícitamente ("MODIFICADO").

## Búsqueda de insumos (FR-003, FR-004)

`GET /items?search={texto}&active=true&...` (línea 44 del router)

- Reutilizado sin cambios. La vista nueva pasa el texto escrito por el usuario (código o
  nombre, búsqueda global sobre todo el inventario) y filtra client-side los insumos que ya
  están agregados como línea (FR-004), igual que hace hoy `purchase-form.component.ts` vía
  `InventoryService.searchActiveItems()`.

## Proveedores (FR-006)

`GET /suppliers` (línea 339 del router)

- Reutilizado sin cambios vía `SuppliersService.loadSuppliers()`.

## Relación proveedor-insumo (FR-007)

Endpoints de "list-for-item" (líneas 376/390/408/422/440 del router)

- Reutilizados sin cambios vía `SupplierItemsService.listForItem()`, filtrado client-side
  por el proveedor elegido para precargar unidad de compra y costo sugerido.

## Registrar compra recibida (User Story 1)

`POST /purchases` (línea 472)

- **Sin cambios.** Request/response igual a los actuales. Exige al menos una línea con
  cantidad > 0 (FR-012); sube stock de inmediato.

## Crear orden de compra pendiente (User Story 2) / Guardar borrador (User Story 3) — **MODIFICADO**

`POST /purchases/order` (línea 488)

**Request body — campo nuevo (opcional, retrocompatible):**

```json
{
  "supplier_id": "uuid|null",
  "invoice_reference": "string|null",
  "items": [
    { "item_id": "uuid", "unit_id": "uuid|null", "quantity": "number", "unit_cost": "number|null" }
  ],
  "allow_incomplete": false
}
```

- `allow_incomplete` (nuevo, `boolean`, default `false` si se omite): preserva el
  comportamiento actual cuando no se envía (retrocompatible con cualquier otro consumidor
  del endpoint).
  - `false` (o ausente) → comportamiento actual sin cambios: exige al menos una línea con
    `item_id` y `quantity > 0` (FR-012); guarda con `status='draft', is_incomplete=false`
    (orden de compra pendiente, User Story 2).
  - `true` → **nuevo**: omite esa validación, acepta líneas sin `quantity`, sin `unit_cost`
    o sin `unit_id` (FR-013); guarda con `status='draft', is_incomplete=true` (borrador
    incompleto, User Story 3).
- Cuando `allow_incomplete=true` y no hay ninguna línea en absoluto, se acepta igualmente
  (FR-013 permite "datos incompletos", no exige ni una sola línea completa).

**Response:** sin cambios de forma, incluye el campo nuevo `is_incomplete` (reflejando el
valor persistido) junto al resto de campos actuales de `PurchaseResponse`.

## Reapertura de un borrador (FR-017)

`GET /purchases?status=draft` (línea 455, ya existente, paginado)

- Reutilizado sin cambios. El frontend filtra en el listado existente de compras las filas
  con `is_incomplete=true` para presentarlas como "Borrador" en vez de "Orden pendiente"
  (diferenciación puramente de presentación sobre un listado ya existente).
- Reabrir un borrador para continuar editando reutiliza `GET /purchases/{id}` (si existe) o
  los datos ya cargados en el listado; la vista nueva precarga el formulario con esos datos
  y permite volver a llamar a `POST /purchases/order` con `allow_incomplete` según la acción
  elegida al guardar de nuevo. (Detalle de implementación exacto a confirmar en
  `/speckit-tasks` si el endpoint de detalle no expone aún todas las líneas necesarias.)

## Recepción y anulación (fuera de alcance de esta migración)

`POST /purchases/{purchase_id}/receive`, `POST /purchases/{purchase_id}/void`

- Sin cambios. No se tocan en este spec (Assumptions del spec: la recepción y anulación ya
  existentes siguen funcionando donde están hoy).
