# Quickstart: Compra de Insumos con Conversión a Unidad Base

Valida de extremo a extremo los tres user stories de la spec contra una base de datos
real (Postgres local, disponible según memoria de sesiones previas).

## Prerrequisitos

- `pos-backend` corriendo con el venv de siempre y las migraciones de esta spec
  aplicadas (`alembic upgrade head`).
- Un tenant de prueba con al menos un usuario ADMIN y uno no-ADMIN (p. ej. CASHIER), y
  el insumo "Azúcar" con unidad base "g" (grupo/`dimension` "Masa").
- Unidades "KG" (factor 1000) y "LB" (factor 453.592) activas, `dimension = "Masa"`.
- Ver `contracts/api-changes.md` para el detalle exacto de cada endpoint.

## Escenario 1 — Registrar compra con conversión (US1, acceptance scenarios 1-2)

1. `POST /unit-measures` crea "KG" (`dimension="Masa"`, `factor_to_base=1000`) y "LB"
   (`factor_to_base=453.592`) si no existen aún.
2. Con el insumo "Azúcar" en 500 g de stock:
   `POST /inventory/purchases` con una línea
   `{"inventory_item_id": "<azucar>", "unit_measure_id": "<kg>", "quantity": 2,
   "unit_cost": 8000}`.
3. **Esperado**: `201`, `PurchaseItemResponse.quantity_base = 2000.000000`,
   `cost_base = 8.000000`, `conversion_factor_applied = 1000.000000`. `GET
   /inventory/items/{azucar}` muestra `current_stock = 2500.000000`.
4. Repite con "LB", `quantity=3`, stock inicial en 0.
   **Esperado**: `current_stock = 1360.776000` (sin redondeo intermedio).

## Escenario 2 — Vista previa sin tocar stock (US1, acceptance scenario 3)

1. En el frontend, abrir el formulario de compra, elegir "Azúcar" + unidad "KG",
   escribir cantidad `2` sin enviar el formulario.
2. **Esperado**: aparece el texto "= 2.000 g" junto a la línea (cálculo en cliente con
   `factor_to_base` ya cargado). `GET /inventory/items/{azucar}` sigue mostrando el
   stock previo — nada cambia hasta `POST /inventory/purchases`.

## Escenario 3 — Cantidad/costo inválidos (US1, acceptance scenario 4)

1. `POST /inventory/purchases` con una línea `unit_measure_id="<kg>"`, `quantity=0`.
2. **Esperado**: `422`, mensaje incluye "La cantidad debe ser mayor que cero". No se
   crea la compra ni se mueve stock.

## Escenario 4 — Selector y validación de grupo (US2)

1. `GET /unit-measures?dimension=Volumen&active=true` para el insumo "Leche" (base
   "ml", grupo "Volumen"): la lista **no** debe incluir "KG" ni "LB".
2. `POST /inventory/purchases` con una línea de "Leche" pero `unit_measure_id="<kg>"`.
   **Esperado**: `422` (dimensión incompatible), ninguna línea se registra.
3. `PATCH /unit-measures/{lb}` con `{"active": false}`.
   `GET /unit-measures?dimension=Masa&active=true` ya no incluye "LB".
4. `PATCH` la configuración del tenant con `unit_conversion_enabled=false`.
   `POST /inventory/purchases` de "Azúcar" con `unit_measure_id="<kg>"` (distinta de la
   unidad base "g") → `422`. La unidad base "g" sigue funcionando.

## Escenario 5 — Historial frente a cambios de factor y anulación (US3)

1. Confirma una compra de 2 KG de "Azúcar" (factor 1000, `quantity_base=2000`).
2. Como usuario **no-ADMIN**, `PATCH /unit-measures/{kg}` con `factor_to_base=1100`.
   **Esperado**: `403`.
3. Como ADMIN, repite el mismo `PATCH`. **Esperado**: `200`,
   `GET /unit-measures/{kg}/factor-changes` devuelve una fila con
   `old_factor=1000`, `new_factor=1100`, `changed_by=<admin>`.
4. `GET /inventory/purchases/{id}` de la compra del paso 1: su línea sigue mostrando
   `conversion_factor_applied=1000`, `quantity_base=2000` (no cambia con el factor
   nuevo).
5. `current_stock` de "Azúcar" está en 2500 g (500 + 2000 del paso 1).
   `POST /inventory/purchases/{id}/void`. **Esperado**: `200`, `current_stock = 500`
   (resta exactamente los 2000 g guardados, no un valor recalculado con factor 1100).
6. Repite el mismo `POST .../void`. **Esperado**: `409` (FR-013).

## Verificación de regresión

- Correr la suite de characterization tests de `app/characterization_tests/` — en
  particular `test_core_units.py` (se actualiza explícitamente en este cambio, citando
  esta spec) y cualquier test de `purchases`/`supplier_items` (ruta `supplier_item_id`
  debe seguir pasando sin modificar sus aserciones).
- Correr la suite de tests nueva de esta spec (modelo, servicio, endpoints) con
  `pytest`.
- En el frontend, confirmar que el flujo de presentaciones de proveedor (spec 106/107)
  sigue funcionando igual en `purchase-form.component.ts` (coexiste con, pero no se
  mezcla con, el nuevo selector de unidad).
