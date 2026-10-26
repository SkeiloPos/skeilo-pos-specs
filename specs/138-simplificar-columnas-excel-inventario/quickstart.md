# Quickstart: Verificación de la spec 138

**Spec**: [spec.md](./spec.md) | **Contrato**: [contracts/plantilla-excel-inventario.md](./contracts/plantilla-excel-inventario.md)

Guía de validación manual/funcional end-to-end contra `pos-backend` en local, usando Postgres
local disponible (ver memoria `[[how-to-run-sibling-repo-tests]]`). No sustituye los tests
automatizados de implementación — es la lista de escenarios que deben poder reproducirse para
considerar la funcionalidad verificada (Principio X de la constitución).

## Prerrequisitos

- `pos-backend` corriendo localmente contra Postgres (venv del proyecto, no el pytest de
  Anaconda — ver memoria de cómo correr los tests del repo hermano).
- Un tenant de prueba con al menos un insumo existente y, opcionalmente, un proveedor preferido
  ya asignado a ese insumo (para validar que esa relación no se toca).
- Cliente HTTP (curl/Postman) o la UI de `pos-heladeria` autenticado contra ese tenant.

## Escenario 1 — Exportación sin presentación/factor/último costo, con proveedor preferido (Historia 1, FR-001/FR-002)

1. `GET /inventory/items/export` para el tenant de prueba.
2. Abrir el `.xlsx` resultante.
3. **Esperado**: encabezados exactos `Código, Nombre, Tipo, Unidad, Stock, Mínimo, Costo,
   Proveedor preferido` — sin `Presentación`, `Factor de conversión` ni `Último costo`. La
   columna `Proveedor preferido` trae el nombre del proveedor preferido de cada insumo (en
   blanco si no tiene uno asignado).

## Escenario 2 — Importar un archivo legado con las columnas viejas (FR-003, FR-004, FR-010)

1. Tomar (o construir) un `.xlsx` con el encabezado legado de 11 columnas (spec 109), incluyendo
   valores no vacíos en Presentación/Factor de conversión/Último costo para una fila que
   actualiza un insumo con dos relaciones proveedor-insumo activas ya creadas desde el módulo de
   proveedores (p. ej. "Proveedor A", hoy preferida, y "Proveedor B", no preferida). En la
   columna Proveedor preferido de esa fila, poner "Proveedor B".
2. `POST /inventory/items/import` con ese archivo.
3. **Esperado**: el job termina sin error de estructura. Tras finalizar, la relación con
   "Proveedor B" queda marcada como preferida (y "Proveedor A" deja de estarlo), pero la
   presentación/factor de conversión/último costo de "Proveedor B" son exactamente los mismos
   que tenía antes de la importación (los valores de esas 3 columnas en el archivo se ignoraron
   por completo). El resto de campos de la fila (nombre, stock, costo, etc.) sí se actualiza.

## Escenario 2b — Proveedor preferido sin relación existente (FR-012)

1. Importar una fila que actualiza un insumo existente con un nombre en la columna Proveedor
   preferido para el que ese insumo no tiene ninguna relación proveedor-insumo activa (puede ser
   un proveedor que no existe todavía, o uno que existe pero sin relación con ese insumo).
2. **Esperado**: la fila se procesa sin error. Si el proveedor no existía, aparece creado (en
   mayúscula) en el módulo de proveedores. Aparece una relación proveedor-insumo nueva entre ese
   proveedor y el insumo, marcada como preferida, con Presentación y Factor de conversión en
   blanco en la UI del módulo de proveedores (campos pendientes de completar). El resto de
   campos de la fila se actualiza con normalidad.

## Escenario 2c — Ambigüedad de proveedores al importar (FR-011)

1. Crear manualmente en el módulo de proveedores dos proveedores cuyos nombres solo difieren en
   mayúsculas (p. ej. "ABC" y "abc").
2. Importar una fila con columna Proveedor preferido = "ABC".
3. **Esperado**: la fila se reporta como fallida por ambigüedad, sin elegir ninguno de los dos
   proveedores arbitrariamente ni crear ninguna relación.

## Escenario 3 — Crear insumo nuevo con unidad existente, sin duplicar (Historia 2, caso 1)

1. Confirmar que el negocio ya tiene una `UnitMeasure` con `abbreviation` = `KG`.
2. Importar un archivo (formato nuevo, 8 columnas) con una fila nueva (código inexistente) cuya
   columna Unidad es `kg` (minúsculas).
3. **Esperado**: el insumo queda creado usando la `UnitMeasure` `KG` existente. No aparece una
   unidad nueva en Ajustes → Unidades de medida.

## Escenario 4 — Crear insumo nuevo con unidad inexistente (Historia 2, caso 2 — cierra el gap de `group_id`)

1. Confirmar que el negocio no tiene ninguna `UnitMeasure` llamada/abreviada `Galón`.
2. Importar una fila nueva con columna Unidad = `Galón`.
3. **Esperado**: la fila se procesa sin `IntegrityError` (este es el gap de `group_id` NOT NULL
   detectado en `research.md` §3 — correr este escenario contra Postgres real, no SQLite, para
   confirmar que el fix cierra el gap). Aparece un grupo nuevo "Galón" en Ajustes → Unidades de
   medida, con la unidad "Galón" como su unidad base (factor 1). El insumo queda creado usando
   esa unidad. La unidad nueva es seleccionable de inmediato en el formulario de compras
   (spec 135).

## Escenario 5 — Unidad vacía al crear (Historia 2, caso 3 / FR-009)

1. Importar una fila nueva (código inexistente) con columna Unidad vacía.
2. **Esperado**: la fila se reporta como fallida por campo obligatorio faltante (mismo mensaje
   que cualquier otro campo requerido vacío en la spec 109).

## Escenario 6 — Actualizar insumo existente no cambia su unidad (Historia 3, FR-007)

1. Tomar un insumo existente cuya unidad hoy es `g`.
2. Importar una fila que lo actualiza (mismo código) con columna Unidad = `KG` y un precio
   distinto.
3. **Esperado**: tras la importación, el insumo sigue teniendo unidad `g` (sin cambios), y su
   precio sí quedó actualizado al nuevo valor. No aparece ninguna unidad ni grupo nuevo como
   efecto secundario de esta fila.
4. Repetir con columna Unidad vacía y con un texto que no existe como unidad (`"Bulto"`,
   asumiendo que no existe) — en ambos casos la unidad del insumo no cambia y no se crea ninguna
   `UnitMeasure`/`UnitMeasureGroup` nueva.

## Escenario 7 — Ambigüedad de unidades al crear (FR-008)

1. Crear manualmente en Ajustes dos unidades cuyas abreviaturas solo difieren en mayúsculas,
   p. ej. `Gal` y `GAL` (confirmar que el sistema lo permite hoy, dado que `ensure_unique` no es
   case-insensitive — ver `research.md` §3).
2. Importar una fila nueva con columna Unidad = `gal`.
3. **Esperado**: la fila se reporta como fallida por ambigüedad, sin elegir ninguna de las dos
   unidades arbitrariamente.

## Regresión a cubrir (characterization / spec 109)

- Re-ejecutar `python -m unittest discover -s app/characterization_tests -p 'test_*.py' -v` y
  `python -m app.scripts.test_inventory_bulk_excel` (contra Postgres local) tras los cambios;
  ningún test existente debe pasar a fallar salvo los que se actualicen explícitamente para
  reflejar el nuevo contrato de columnas (y esos cambios deben citarse en el commit, Principio
  III de la constitución).
