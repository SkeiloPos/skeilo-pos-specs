# Quickstart: Registro Automático de Inventario al Generar Compra Sugerida

Valida que generar órdenes desde la pantalla de compra sugerida deje el inventario
actualizado de inmediato (US1), que el movimiento quede trazable en el historial del insumo
(US2), y que la generación manual fuera de esa pantalla no cambie.

## Prerrequisitos

- `pos-backend` corriendo contra Postgres local con al menos un tenant de prueba (ver
  memoria `how-to-run-sibling-repo-tests` del asistente para el comando exacto del venv).
- Un insumo activo (p. ej. ALMENDRAS) con `min_stock` > `current_stock`, una relación
  `SupplierItem` preferida activa con `conversion_factor`/`presentation` resueltos y un
  proveedor activo.
- Usuario admin del tenant autenticado (el endpoint de generación exige
  `require_tenant_admin`).

## Escenario 1 — US1: generar deja el stock e inventario actualizados sin recibir manualmente

1. `GET /inventory/purchases/suggested` → confirmar que el insumo de prueba aparece con
   `is_preselected=true` y anotar `current_stock`.
2. `POST /inventory/purchases/suggested/generate` con una línea para ese insumo
   (`supplier_item_id`, `presentation_quantity=1`, `presentation_unit_cost=<precio>`) y un
   `idempotency_key` nuevo.
3. Verificar en la respuesta: `purchases[0].status == "received"` y
   `purchases[0].items[0].received_quantity == purchases[0].items[0].quantity`.
4. `GET /inventory/items/{inventory_item_id}` → `current_stock` debe haber subido exactamente
   en `quantity_base` de la línea (cantidad de compra × factor de conversión), sin haber
   llamado a `POST /purchases/{id}/receive`.
5. Repetir el `GET /inventory/purchases/suggested` del paso 1 → el insumo ya no debe aparecer
   (quedó por encima de su mínimo), confirmando FR-003/criterio de la lista.

Referencia de contrato: [suggested-purchases-generate-delta.md](./contracts/suggested-purchases-generate-delta.md).

## Escenario 2 — US2: trazabilidad en el historial del insumo

1. Con la orden del Escenario 1 ya generada, `GET` el historial de movimientos del insumo
   (endpoint ya existente del módulo de inventario).
2. Verificar que aparece un `InventoryMovement` con `type="in"`, `reference_type="purchase"`,
   `reference_id == purchases[0].id` y `quantity` igual a `quantity_base` de la línea.

## Escenario 3 — Edge case: transacción todo-o-nada

1. Enviar una generación con dos líneas de proveedores distintos, una de ellas con
   `presentation_unit_cost=0` (inválida).
2. Verificar `422` con `detail.lines` identificando la línea inválida por
   `inventory_item_id`.
3. Confirmar que **ninguna** `Purchase` se creó para ninguno de los dos proveedores (ni
   siquiera para la línea válida) y que el `current_stock` de ambos insumos no cambió.

## Escenario 4 — Edge case: idempotencia

1. Reenviar exactamente la misma solicitud del Escenario 1 (mismo `idempotency_key`).
2. Verificar `200` (no `201`) con las mismas `Purchase` ya creadas.
3. Confirmar que `current_stock` del insumo no volvió a subir y que no se insertó un segundo
   `InventoryMovement` para esa orden.

## Escenario 5 — Edge case: anulación

1. `POST /inventory/purchases/{purchase_id}/void` sobre la `Purchase` del Escenario 1.
2. Confirmar `current_stock` del insumo vuelve a su valor original (movimiento `type="out"`,
   `reference_type="purchase_void"`) y que un segundo intento de anular devuelve `409`.

## Escenario 6 — Comportamiento no afectado: creación manual de órdenes

1. `POST /inventory/purchases/order` (fuera de la pantalla de compra sugerida) con cualquier
   línea válida.
2. Verificar que la `Purchase` resultante sigue naciendo `status="draft"`, sin movimiento de
   inventario ni cambio de `current_stock`, hasta que se reciba manualmente
   (`POST /purchases/{id}/receive`) — confirma FR-011.

## Frontend — comprobación manual en `pos-heladeria`

1. Abrir "Compra sugerida", seleccionar un insumo bajo mínimo y generar.
2. Confirmar que, tras el `toast` de éxito, la vista redirige sola a `/dashboard/inventario`
   con la pestaña "Compras" ya abierta (feedback de usuario, post-FR-010) y que ahí se ve la
   orden recién creada con estado "Recibida".
3. Volver a "Compra sugerida": confirmar que el insumo recién repuesto ya no aparece en la
   lista (FR-011a, research.md D4) — la tabla se refrescó sola tras generar.
