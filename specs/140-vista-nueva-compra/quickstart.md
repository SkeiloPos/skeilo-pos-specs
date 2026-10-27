# Quickstart: validar "Vista dedicada para registrar una compra"

## Prerrequisitos

- Backend (`pos-backend`) corriendo localmente contra Postgres (ver memoria de sesión:
  "How to run sibling-repo tests" para el comando de venv) con la migración nueva de
  `purchases.is_incomplete` aplicada (`alembic upgrade head`).
- Frontend (`pos-heladeria`) corriendo con `ng serve` apuntando a ese backend.
- Un tenant con al menos 5 insumos activos, 1 proveedor con una relación proveedor-insumo
  configurada (presentación preferida + último costo) para alguno de esos insumos.

## Escenario 1 — Registrar una compra recibida (User Story 1 / SC-001, SC-002)

1. Entrar a Inventario y hacer clic en "Nueva compra".
2. Verificar que la navegación lleva a una URL propia (`.../inventario/compras/nueva`), no a
   un modal superpuesto (FR-001).
3. Buscar un insumo por código y otro por nombre; verificar que los resultados muestran
   código, nombre y unidad base, y que un insumo ya agregado deja de aparecer (FR-003,
   FR-004, Edge Case "insumo ya en la lista").
4. Elegir el proveedor con relación configurada; verificar que la línea correspondiente
   precarga unidad de compra y costo sugerido (FR-007).
5. Completar cantidades para 5 insumos y presionar "Registrar compra".
6. Verificar: mensaje de éxito, vuelta a Inventario, y que el stock de cada insumo subió
   según la cantidad convertida a unidad base (SC-002). Tiempo total < 2 minutos (SC-001).
7. Repetir el envío del mismo formulario (doble clic o reenvío tras simular error de red) y
   verificar que el stock no se duplica (FR-015, SC-003).

## Escenario 2 — Crear una orden de compra pendiente (User Story 2)

1. Completar proveedor y al menos una línea válida.
2. Presionar "Crear orden de compra".
3. Verificar: se guarda como pendiente, el stock no cambia (SC-004), y aparece en el
   listado de compras existente como orden pendiente de recepción.
4. Intentar crear una orden sin ninguna línea válida; verificar el mensaje de validación
   (FR-012) y que no se crea nada.

## Escenario 3 — Guardar un borrador incompleto (User Story 3)

1. Elegir proveedor y agregar una línea sin precio todavía.
2. Presionar "Guardar borrador".
3. Verificar: se guarda sin exigir líneas completas (FR-013), el stock no cambia (SC-004),
   y se muestra un mensaje de confirmación.
4. Volver a la sección de compras y verificar que el borrador es identificable (distinto de
   una orden pendiente) y se puede reabrir para continuar editando (FR-017).

## Escenario 4 — Edge cases

- Cambiar de proveedor con líneas ya agregadas que no tienen relación configurada para el
  nuevo proveedor: verificar que esas líneas conservan su unidad de compra y costo actuales
  (FR-007, Edge Case).
- Buscar un texto sin coincidencias: verificar el mensaje de "ningún insumo coincide" (Edge
  Case), no un listado vacío sin explicación.
- Simular pérdida de conexión al guardar: verificar que se muestra el error y los datos
  capturados permanecen en la vista (Edge Case).
- Salir con "Cancelar" sin haber usado "Guardar borrador": verificar que lo capturado se
  descarta.

## Verificación técnica

- Backend: confirmar el mecanismo de test a usar antes de implementar (ver `research.md`
  D4); como mínimo, ejecutar los scripts de verificación manual existentes
  (`app/scripts/test_purchase_presentation.py`, `app/scripts/test_purchase_unit_conversion.py`)
  tras el cambio, y validar `POST /purchases/order` con `allow_incomplete=true` y `false`
  por separado (ver `contracts/purchases-api.md`).
- Frontend: `ng test` sobre `purchase-form.component.spec.ts` /
  `purchase-view.component.spec.ts` (nuevo) / `inventory-page.component.spec.ts` para
  confirmar que no hay regresiones en el flujo migrado (Principio III/X).
