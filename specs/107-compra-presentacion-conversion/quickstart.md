# Quickstart: validar la compra en presentación

Asume que `data-model.md`/`contracts/api.md` ya están aplicados.

## Prerrequisitos

- `pos-backend`: migración aplicada; un tenant con un insumo (p. ej. "Azúcar", unidad base "g"),
  un proveedor normal, y al menos una relación proveedor-insumo activa entre ambos (p. ej.
  "Bolsa x 500 g", factor 500) — reutiliza el mismo fixture que `test_supplier_items.py`
  (spec 106).
- Postgres real disponible (ya confirmado en esta sesión) para correr el script contra una base
  de verdad, no solo contra la suite de characterization.

## 1. Backend — script autoejecutable

```bash
cd ../pos-backend
./env/bin/python -m app.scripts.test_purchase_presentation
```

Debe cubrir, como mínimo (mapeado a los Acceptance Scenarios del spec):

1. Compra directa de 1 "Bolsa x 500 g" a $4.000 → `PurchaseItem.quantity == 500`,
   `unit_cost == 8.00`, `presentation_quantity == 1`, `presentation_label == "Bolsa x 500 g"`,
   stock del insumo sube en 500 g, `Purchase.total` de esa línea es exactamente `4000` (Historia
   1, escenario 1).
2. Compra directa de 3 bolsas a $4.000 cada una → stock sube 1.500 g, total de línea $12.000
   (Historia 1, escenario 2).
3. Compra contra un insumo+proveedor sin relación activa, y una compra contra "Compra ocasional"
   → ambas aceptan `quantity`/`unit_cost` directos, sin ningún campo nuevo, comportamiento
   idéntico al de antes de esta spec (Historia 1, escenario 3).
4. Tras la compra del punto 1, la relación usada queda con `last_cost == 4000` y
   `last_cost_at` reciente (Historia 2).
5. Crear una orden de compra contra "Bolsa x 500 g" por 10 bolsas, recibir 5 y después las otras
   5 → cada recepción suma 2.500 g, ambas con el mismo factor (500) aunque se edite el factor
   de **otra** presentación distinta entre medio (Historia 3).
6. Intentar una línea con `quantity` y `supplier_item_id` a la vez → 422.
7. Intentar una línea con `supplier_item_id` de una relación que pertenece a otro insumo o a
   otro proveedor que el de la compra → 422.
8. Verificar que las reglas protegidas de la spec 005 siguen intactas también por el camino
   nuevo: `presentation_quantity <= 0` → rechazado (RN-INV-23); recibir más presentaciones de
   las pendientes → rechazado (RN-INV-20, convertido a unidad base antes de comparar).

## 2. Backend — regresión obligatoria

```bash
./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'
./env/bin/python -m app.scripts.test_supplier_items
```

Ambos deben seguir en verde — ninguno de los dos debería verse afectado por esta spec, pero son
los que protegen exactamente las reglas (RN-INV-* y las de spec 106) que este plan promete no
reabrir.

## 3. Frontend — specs Vitest + uso manual

```bash
cd ../pos-heladeria
npx ng test --watch=false --include='src/app/modules/inventory/components/purchase-form.component.spec.ts'
```

Uso manual (`ng serve`):

1. Abrir "Nueva compra", elegir un proveedor con relaciones activas, agregar una línea con un
   insumo que tenga una presentación de ese proveedor → aparece el selector de presentación;
   elegirla muestra la equivalencia en vivo (igual que en la pestaña "Proveedores" de spec 106).
2. Guardar la compra → en el detalle, la línea muestra la presentación y cantidad reales
   ("3 Bolsa x 500 g"), no solo el equivalente en gramos.
3. Abrir la pestaña "Proveedores" del insumo → el último costo ya refleja la compra recién
   hecha, sin recargar nada manualmente.
4. Elegir "Compra ocasional" como proveedor de la compra → ninguna línea ofrece selector de
   presentación; el campo de cantidad vuelve a ser directo en unidad base, como siempre.

## Criterio de éxito

Los 8 puntos del script backend pasan contra Postgres real, las dos suites de regresión siguen
en verde, y los 4 pasos manuales del frontend se comportan como se describe.
