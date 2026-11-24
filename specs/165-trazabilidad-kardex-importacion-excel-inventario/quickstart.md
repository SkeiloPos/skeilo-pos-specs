# Quickstart: Trazabilidad de kardex en la importación masiva de Excel de inventario

Valida que crear un insumo nuevo por Excel con Stock > 0 deje un movimiento `in` trazable
(US1), que actualizar uno existente con un Stock distinto genere un ajuste por la diferencia
(US2), que un ajuste que dejaría el stock negativo rechace solo esa fila (US3), y que ningún
caso genere un movimiento espurio cuando el delta es cero.

## Prerrequisitos

- `pos-backend` corriendo contra Postgres local con al menos un tenant de prueba (ver
  memoria `how-to-run-sibling-repo-tests` del asistente para el comando exacto del venv).
- Un tenant con al menos un insumo existente de prueba con `current_stock` conocido (p. ej.
  `current_stock = 30`), para los escenarios de actualización.
- Usuario admin del tenant autenticado (el flujo de importación ya exige lo que exigía antes
  de esta spec, sin cambios).

## Escenario 1 — US1: creación con Stock > 0 genera movimiento `in`

1. Preparar un Excel con una fila de código **no existente** y Stock = 50.
2. `POST /inventory/items/import` con ese archivo; esperar a que el job termine
   (`GET /inventory/items/import/{job_id}` hasta `status == "finalizado"`).
3. Verificar `job.created_count == 1`, `job.failed_count == 0`.
4. `GET /inventory/items?code=<code>` → confirmar que el insumo existe con
   `current_stock == 50`.
5. `GET /inventory/items/{inventory_item_id}/movements` → confirmar que aparece un
   movimiento con `type == "in"`, `quantity == 50`, `reason == "importacion_masiva"`,
   `reference_type == "import_job"`, `reference_id == job_id`.

Referencia de contrato: [import-kardex-delta.md](./contracts/import-kardex-delta.md).

## Escenario 2 — US1 edge case: creación con Stock = 0 no genera movimiento

1. Repetir el Escenario 1 con una fila de código no existente y Stock = 0.
2. Confirmar que el insumo se crea con `current_stock == 0`.
3. `GET .../movements` del insumo recién creado → debe venir **vacío** (sin movimiento
   espurio).

## Escenario 3 — US2: actualización con Stock distinto genera ajuste por la diferencia

1. Con el insumo de prueba (`current_stock = 30`), preparar un Excel con el mismo código y
   Stock = 45.
2. Importar y esperar a que el job termine; confirmar `job.updated_count == 1`.
3. `GET /inventory/items/{id}` → `current_stock == 45`.
4. `GET .../movements` → confirmar un movimiento nuevo con `type == "adjustment"`,
   `quantity == 15`, `reason == "importacion_masiva"`, `reference_type == "import_job"`,
   `reference_id == job_id`.
5. Repetir con Stock = 10 sobre el mismo insumo (ahora en 45) → confirmar movimiento
   `type == "adjustment"`, `quantity == 20`, y `current_stock == 10`.

## Escenario 4 — US2 edge case: Stock sin cambio no genera movimiento

1. Con el insumo en `current_stock = 10` (tras el Escenario 3), importar el mismo código con
   Stock = 10 (sin cambio).
2. Confirmar `job.updated_count == 1` (la fila se procesa igual, sin cambio de campos) y que
   `GET .../movements` **no** agrega ninguna fila nueva respecto al estado previo.

## Escenario 5 — US3: ajuste que dejaría stock negativo rechaza solo esa fila

1. Con un insumo en `current_stock = 5`, preparar un Excel con dos filas: la primera con el
   código de ese insumo y un Stock tal que el delta resultante sea negativo y mayor en
   magnitud al stock disponible (p. ej. si la fila trajera un Stock que implique restar más
   de 5); la segunda fila con un código distinto, válido, sin relación con la primera.
2. Importar y esperar a que el job termine.
3. Verificar en `job.errors[]` una entrada para la primera fila con
   `motivo` conteniendo "dejaría el stock... en negativo" (ver contrato).
4. Confirmar que `current_stock` del primer insumo **no cambió** (sigue en 5) y que no se
   agregó ningún `InventoryMovement` nuevo para ese insumo.
5. Confirmar que la segunda fila sí se procesó con normalidad (`job.created_count` o
   `job.updated_count` refleja esa fila), demostrando que el rechazo es por fila individual,
   no aborta el resto del archivo (FR-006, ya vigente para otros tipos de error desde
   spec 109).

## Escenario 6 — Costo sin cambios (FR-009)

1. Repetir cualquiera de los escenarios anteriores con una fila que además traiga un valor
   de Costo distinto al `unit_cost` actual del insumo.
2. Confirmar que `unit_cost` queda igual al valor de la fila (sobrescritura directa, como
   antes de esta spec) y que **ningún** `InventoryMovement` generado por esa fila referencia
   el cambio de costo — el único movimiento, si lo hay, es el de Stock descrito en los
   escenarios 1/3.

## Verificación automatizada

- `python -m app.scripts.test_inventory_bulk_excel` (Postgres real) — extendido con los
  casos de los Escenarios 1-6.
- `python -m unittest discover -s app/characterization_tests -p 'test_*.py' -v` — confirma
  que `test_core_inventory_reasons.py` (actualizado, cita A-165) y `test_inventory_stock.py`
  (sin cambios de comportamiento para otros callers) siguen en verde.
