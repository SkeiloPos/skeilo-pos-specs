# Contrato de API: relación proveedor–insumo

Todas las rutas viven en el router existente `app/api/v1/inventory/router.py` (prefijo
`/inventory`, ya protegido por `require_module_access("inventario")`), bajo las dependencias ya
usadas en ese archivo (`get_current_user`, `require_tenant_admin`). El aislamiento de tenant
(FR-015) es automático: la sesión de base de datos ya está ligada al esquema del tenant
autenticado, así que un `id` de otro tenant simplemente no existe en esa sesión — `get_or_404`
responde `404` sin lógica adicional, igual que el resto del router.

## `GET /inventory/items/{item_id}/suppliers`

Lista las relaciones del insumo `item_id`, del lado del insumo (pestaña "Proveedores").

- Query: `include_inactive: bool = false` (FR-017).
- 404 si `item_id` no existe en el tenant actual.
- 200 → `list[SupplierItemResponse]`, ordenado por `preferred DESC, created_at ASC`.

## `GET /inventory/suppliers/{supplier_id}/items`

Simétrico — pestaña "Insumos que vende" del proveedor. Mismo query param, mismo orden, mismo
cuerpo de respuesta (FR-016: ambas pestañas leen la misma tabla, no hay desincronización
posible).

- 404 si `supplier_id` no existe en el tenant actual, o si `supplier.is_system=true` (un
  proveedor de sistema no tiene pestaña "Insumos que vende" que mostrar).

## `POST /inventory/items/{item_id}/suppliers` y `POST /inventory/suppliers/{supplier_id}/items`

Alta de una relación. Ambas rutas aceptan `SupplierItemCreate` (una fija `inventory_item_id` por
la URL y pide `supplier_id` en el cuerpo; la otra al revés) y delegan en la misma función de
servicio `create_or_reactivate(db, supplier_id, inventory_item_id, body)`.

**Lógica (FR-004/FR-005/FR-012/FR-013)**:
1. 404 si el proveedor o el insumo no existen en el tenant actual.
2. 422 si `supplier.is_system=true` — mensaje: "No se puede vincular el proveedor de sistema
   'Compra ocasional'" (FR-013; el selector de la UI ya lo excluye, FR-012, así que este caso
   solo ocurre si alguien llama a la API directamente).
3. 422 si `conversion_factor <= 0` — mensaje dinámico con la unidad base del insumo (FR-002):
   "El factor debe ser mayor que 0: indica cuántos {unidad base} trae 1 presentación".
4. Buscar `SupplierItem` existente con el mismo `(supplier_id, inventory_item_id,
   lower(trim(presentation)))`:
   - Si existe y `active=true` → 409, cuerpo incluye `existing_id` para que la UI ofrezca
     "editar la existente" (FR-004).
   - Si existe y `active=false` → reactivar (`active=true`), actualizar `presentation` (forma
     tal cual la envió esta solicitud, no la anterior), `conversion_factor`, `last_cost`/
     `last_cost_at` si vino costo — 200, no 201 (FR-005).
   - Si no existe → crear fila nueva, `active=true`, `preferred=false` — 201.
5. Si el cuerpo incluye `last_cost`, fijar `last_cost_at = now()` en el mismo commit (FR-006).

Respuesta: `SupplierItemResponse`.

## `PATCH /inventory/supplier-items/{relation_id}`

Edición parcial — mismo estilo que `PATCH /inventory/suppliers/{id}` (`SupplierUpdate`): un solo
endpoint para editar campos, marcar/desmarcar preferido y activar/desactivar, cuerpo
`SupplierItemUpdate` con todos los campos opcionales.

**Lógica**:
1. 404 si `relation_id` no existe en el tenant actual (FR-015).
2. Si `conversion_factor` viene en el cuerpo y `EXISTS (SELECT 1 FROM purchase_items WHERE
   supplier_item_id = relation_id)` → 422, mensaje: "Esta relación ya se usó en una compra; no se
   puede cambiar su factor. Crea una presentación nueva en su lugar" (FR-014) — ningún otro campo
   del cuerpo se rechaza por esto; solo `conversion_factor` queda bloqueado.
3. Si `preferred=true` viene en el cuerpo:
   - 422 si la fila (tras aplicar el resto del cuerpo en la misma solicitud) quedaría con
     `active=false` (FR-010).
   - Si `supplier.is_system=true` (no debería ocurrir, pero se revalida) → 422 (FR-013).
   - Transacción: `lock_items(db, [inventory_item_id])` → `UPDATE ... SET preferred=false WHERE
     inventory_item_id=... AND preferred AND id != relation_id` → `UPDATE ... SET
     preferred=true WHERE id=relation_id` → commit (research.md D2).
4. Si `active=false` viene en el cuerpo y la fila tenía `preferred=true`, se fuerza
   `preferred=false` en la misma operación (FR-011) — la respuesta incluye
   `was_preferred: true` para que la UI muestre el aviso "Sin proveedor preferido: no se
   incluirá en órdenes sugeridas".
5. Resto de campos (`presentation`, `last_cost`) se aplican directamente; si `last_cost` viene en
   el cuerpo, se refresca `last_cost_at` (FR-006).

Respuesta: `SupplierItemResponse` (con `was_preferred` solo presente cuando aplica el punto 4).

## Errores comunes (todas las rutas)

| Código | Cuándo |
|---|---|
| 404 | el insumo, el proveedor o la relación no existen en el tenant autenticado (incluye el caso de pertenecer a otro tenant, FR-015) |
| 422 | factor ≤ 0 (FR-002); proveedor de sistema (FR-013); factor editado tras uso en compra (FR-014); `preferred=true` sobre una relación inactiva (FR-010) |
| 409 | alta duplicada sobre una combinación ya activa (FR-004) |
