# Quickstart: validar la relación proveedor–insumo

Guía de validación end-to-end. No sustituye `tasks.md`; asume que la implementación de
`data-model.md`/`contracts/api.md` ya está aplicada.

## Prerrequisitos

- `pos-backend`: entorno del proyecto (`cd ../pos-backend && ./env/bin/python ...`), migraciones
  aplicadas (incluye el seed de "Compra ocasional" por tenant, data-model.md), un tenant con al
  menos un insumo ("Almendras", unidad base "g") y dos proveedores normales ("Distribuidora
  Norte", "Agro Sur").
- `pos-heladeria`: `npm install` si no se hizo antes.
- No hay Postgres local por defecto (ver memoria de sesión); para validar de verdad el candado de
  preferido (RN-16) contra Postgres real, levantar uno desechable:
  `conda create -p <scratchpad>/pgconda -c conda-forge --override-channels postgresql=16`.

## 1. Backend — script autoejecutable

```bash
cd ../pos-backend
./env/bin/python -m app.scripts.test_supplier_items
```

Debe cubrir, como mínimo (mapeado a los Acceptance Scenarios del spec):

1. Crear "Distribuidora Norte" – "Almendras" – "Bolsa x 500 g", factor 500, último costo 8000 →
   relación activa, `last_cost_at` reciente, `equivalence == "1 Bolsa x 500 g = 500 g · $16.00/g"`.
2. Vincular "Agro Sur" con "Bolsa x 140 g", factor 140 → el insumo tiene 2 relaciones activas; no
   se creó ningún `InventoryItem` nuevo.
3. Factor 0 o negativo → 422 con el mensaje dinámico de unidad base.
4. Repetir el alta #1 con "bolsa x 500 g " (mayúsculas/espacios distintos) → 409, con
   `existing_id` apuntando a la relación de #1.
5. Desactivar la relación de "Agro Sur" y volver a darla de alta igual → reactivada (mismo `id`
   de antes de desactivar, no uno nuevo).
6. Insertar manualmente una fila de `purchase_items` con `supplier_item_id` apuntando a la
   relación de "Distribuidora Norte"; intentar `PATCH conversion_factor` → 422 sugiriendo crear
   una presentación nueva.
7. Marcar "Agro Sur" como preferido mientras "Distribuidora Norte" ya lo es → al terminar, solo
   "Agro Sur" tiene `preferred=true`; contra Postgres real, lanzar dos marcas concurrentes a
   proveedores distintos del mismo insumo (dos hilos/conexiones) y verificar que, tras ambas,
   sigue existiendo exactamente una fila `preferred=true` (RN-16 bajo concurrencia real — no
   verificable en la suite de characterization sobre SQLite, research.md D9).
8. Intentar vincular o preferir al proveedor sembrado "Compra ocasional" (`is_system=true`) → 422
   en ambos casos; no aparece en ningún listado usado por el selector.
9. Desactivar la relación preferida de un insumo → queda `active=false, preferred=false`,
   respuesta con `was_preferred=true`.
10. Como otro tenant, consultar/editar/desactivar el `id` de una relación creada en el tenant de
    prueba → 404.

## 2. Frontend — specs Vitest + uso manual

```bash
cd ../pos-heladeria
npx ng test --watch=false --include='src/app/modules/supplier-items/**/*.spec.ts'
npx ng test --watch=false --include='src/app/modules/inventory/**/*.spec.ts'
npx ng test --watch=false --include='src/app/modules/suppliers/**/*.spec.ts'
```

Uso manual (`ng serve`, admin del tenant):

1. Abrir el detalle de "Almendras" → pestaña "Proveedores" → agregar "Distribuidora Norte" con
   "Bolsa x 500 g" / 500 / 8000 → la fila muestra la equivalencia en vivo mientras se escribe el
   factor, antes de guardar (FR-018).
2. Abrir el detalle de "Distribuidora Norte" → pestaña "Insumos que vende" → la relación recién
   creada aparece ahí sin recargar nada aparte (FR-016).
3. Marcar la estrella de preferido en una segunda relación del mismo insumo → la primera se
   desmarca sola, sin recargar la página.
4. Desactivar la relación preferida → aviso "Sin proveedor preferido: no se incluirá en órdenes
   sugeridas" visible de inmediato.
5. Abrir el selector de proveedores para vincular a cualquier insumo → "Compra ocasional" no
   aparece en la lista.
6. Con el filtro "mostrar inactivas" apagado (default), ninguna relación desactivada aparece en
   ninguna de las dos pestañas; al activarlo, aparecen.

## Criterio de éxito

Los 10 puntos del script backend pasan contra un Postgres real, y los 6 pasos manuales del
frontend se comportan como se describe, sin tocar ningún otro módulo (ventas, caja, mesas) ni
modificar el comportamiento de `Supplier`/`InventoryItem`/`Purchase` ya existente.
