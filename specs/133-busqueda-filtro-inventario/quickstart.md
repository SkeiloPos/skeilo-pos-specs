# Quickstart: Verificar búsqueda por nombre/código y filtro por proveedor en Inventario

## Prerrequisitos

- `pos-backend`: venv en `env/` activado (`source env/bin/activate`), Postgres 16 local
  levantado (`docker compose up -d postgres redis`), migraciones aplicadas
  (`alembic upgrade head`, incluye el índice nuevo `ix__supplier_items__supplier_id_active` —
  ver [data-model.md](./data-model.md)).
- Un tenant de prueba con: al menos dos insumos cuyo `code` no se parezca a su `name` (para
  distinguir el match por código del match por nombre), al menos un proveedor con una relación
  **activa** a uno de esos insumos (spec 106), y al menos un proveedor sin ninguna relación
  activa.
- `pos-heladeria`: frontend corriendo contra ese backend (`ng serve` o equivalente), sesión
  autenticada en ese tenant, en la pestaña "Insumos" de Inventario.

## Validación del backend (contrato)

Con el servidor corriendo y un token válido, contra `GET /inventory/items`:

1. `?search=<fragmento del code de un insumo>` → la respuesta `items` incluye ese insumo
   (contrato §1).
2. `?search=<fragmento del name de otro insumo>` → la respuesta `items` lo incluye igual que
   antes del cambio (contrato §2, regresión FR-010).
3. `?supplier_id=<id del proveedor con relación activa>` → `items` contiene únicamente insumos
   vinculados activamente a ese proveedor (contrato §5).
4. `?supplier_id=<id del proveedor sin relaciones activas>` → `items` es `[]` (contrato §6).
5. `?search=<texto>&supplier_id=<id>&type=<tipo>&active=true` → `items` cumple los cuatro
   criterios a la vez (contrato §9).

Corroborar que ninguno de estos casos rompe los characterization tests existentes:

```bash
cd pos-backend && source env/bin/activate
python -m unittest discover -s app/characterization_tests -p 'test_*.py' -v
```

(Baseline conocida: comparar resultado por archivo de test, no por conteo total — ver nota de
memoria del proyecto sobre la suite de frontend; para la suite de `unittest` del backend no se
ha reportado esa inestabilidad.)

## Validación del frontend (end-to-end manual)

En la pestaña "Insumos" de Inventario:

1. Escribir en el buscador un código conocido de un insumo (no su nombre) → el insumo aparece
   en la tabla (Historia 1, escenario 1).
2. Escribir un nombre conocido → sigue funcionando igual que antes (Historia 1, escenario 2).
3. Escribir un texto sin coincidencias → la tabla muestra el mensaje de "sin resultados"
   existente (Historia 1, escenario 4 / FR-008).
4. Seleccionar un proveedor en el nuevo filtro → la tabla muestra solo insumos vinculados
   (activamente) a ese proveedor (Historia 2, escenario 1).
5. Seleccionar un proveedor sin insumos vinculados → "sin resultados" (Historia 2, escenario 2).
6. Volver a "Todos los proveedores" → la tabla vuelve a mostrar insumos de todos los
   proveedores, respetando cualquier otro filtro/búsqueda activo (Historia 2, escenario 3 /
   FR-009).
7. Con una página distinta de la primera ya abierta, cambiar el buscador o cualquier filtro
   (incluyendo el nuevo de proveedor) → la tabla vuelve a la página 1 automáticamente (FR-007).
8. Activar buscador + filtro de proveedor + filtro de tipo + filtro de estado a la vez →
   verificar que los resultados cumplen los cuatro criterios simultáneamente, no una unión
   (Historia 3, escenario 2).

## Qué NO verifica este quickstart

- No cubre las pestañas "Compras" ni "Movimientos" de Inventario (fuera de alcance, spec.md).
- No cubre selección múltiple de proveedores (fuera de alcance, Assumptions de spec.md).
- No mide rendimiento con un catálogo real de 5,000 insumos (SC-003); si se requiere evidencia
  de esa medición, se hace aparte con un script de carga de datos de prueba, no como parte de
  este quickstart manual.
