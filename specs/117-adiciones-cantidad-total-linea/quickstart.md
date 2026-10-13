# Quickstart — Spec 117

**Fecha**: 2026-10-13 · **Spec**: [spec.md](./spec.md) · **Contratos**: [contracts/](./contracts/)

Valida de punta a punta que una adición de un grupo "Por cantidad" cobra como total de línea, no
multiplicada por la cantidad de producto, en las superficies listadas en `FR-010`, y que "Conteo"
sigue sin cambios. No requiere migración (ver [data-model.md](./data-model.md)).

## Prerrequisitos

- `pos-backend` en la rama de esta spec, backend levantado con `uvicorn` nativo (no Docker — ver
  memoria `reference_pos_api_docker_vs_nativo`), base de datos de desarrollo con al menos un
  tenant.
- `pos-heladeria` en la rama de esta spec, `ng serve` apuntando a ese backend.
- Un producto con una presentación de precio conocido (ej. "Ojo de diablo – Extra grande" a
  `$18.000`) y un grupo de opciones en modo **"Por cantidad"** con al menos una opción con
  recargo (ej. "Gomitas" a `$1.000`) asignado a esa presentación, con `max_quantity_per_option = 1`
  para probar la Historia 3.

## Escenario 1 — Historia 1 (el total no multiplica la adición)

1. Terminal POS: agregar la presentación con cantidad de producto **2** y 1 unidad de "Gomitas".
2. **Esperado**: el botón de acción muestra `Agregar • $37.000` (`2×18.000 + 1×1.000`), no
   `$38.000`. Ver [contracts/line-pricing-per-line-cantidad.md](./contracts/line-pricing-per-line-cantidad.md).
3. Repetir agregando 2 unidades de "Gomitas" explícitamente ⇒ esperado `$38.000`
   (`2×18.000 + 2×1.000`).
4. Repetir el mismo armado desde pedido manual (`manual-order-page`) ⇒ mismo resultado que en
   Terminal (antes de esta spec, pedido manual multiplicaba igual que Terminal; ambos comparten
   `PosTerminalStore`).

## Escenario 2 — Historia 2 (consistencia entre superficies)

1. Menú QR: un comensal arma "2 × Ojo de diablo" con 1 "Gomitas" y confirma el pedido.
2. **Esperado**: el total mostrado en el Menú QR es `$37.000`.
3. Cajero: abrir **"Pagos por confirmar"** para ese pedido (pago QR pendiente).
4. **Esperado**: el monto que el sistema valida contra lo recibido es `$37.000` — mismo cálculo,
   usando `GET /orders/{id}/checkout-preview`
   (ver [contracts/line-pricing-per-line-cantidad.md](./contracts/line-pricing-per-line-cantidad.md)).
5. Confirmar el pago; imprimir el recibo y abrir el detalle de la orden / "Mis pedidos".
6. **Esperado**: ambas superficies muestran "Gomitas ×1" y `$37.000` — sin discrepancias (`SC-003`).

## Escenario 3 — Historia 3 (ajuste automático al reducir cantidad)

1. Con el grupo "toppings" en `max_quantity_per_option = 1`: desde el Menú QR, agregar al carrito
   la presentación con cantidad de producto **2** y 2 unidades de "Gomitas" (válido: tope escalado
   `1×2=2`).
2. `PATCH /cart/items/{id}` con `{"quantity": 1}` (reducir la cantidad de producto a 1).
3. **Esperado**: `200 OK`, `options[0].quantity == 1` (ajustado de 2 a 1), `adjusted_options ==
   [{"option_name": "Gomitas", "previous_quantity": 2, "new_quantity": 1}]`, `line_total ==
   19000.00` (`1×18.000 + 1×1.000`). Ver
   [contracts/cart-item-auto-adjust.md](./contracts/cart-item-auto-adjust.md).
4. En la UI del Menú QR, verificar que aparece un aviso visible del ajuste (diseño concreto fuera
   de alcance de esta spec, pero debe existir algún aviso no silencioso).
5. Repetir con dos adiciones distintas del mismo grupo (`max_total_quantity = 2`, "Gomitas" ×2 +
   "Chocolate" ×1 con cantidad de producto 2, reducida a 1) y verificar el criterio determinista
   (se reduce "Gomitas" por ir alfabéticamente después que "Chocolate", no "Chocolate").
6. Volver a subir la cantidad de producto a 2 ⇒ verificar que "Gomitas" **no** vuelve solo a 2
   (el ajuste automático nunca "revive" una cantidad reducida — Edge Case de la spec).

## Escenario 4 — Historia 4 (comanda de cocina)

1. Enviar a cocina una línea de cantidad de producto 2 con "Gomitas ×1" (total de línea).
2. **Esperado**: la comanda muestra "2 × Ojo de diablo – Extra grande · Adiciones: Gomitas ×1
   (total)" — mismo formato ya definido por spec 065 `FR-010`, sin inferencia manual.

## Escenario 5 — "Conteo" no cambia (FR-013, regresión)

1. Con un grupo en modo **"Conteo"** con recargo, repetir el Escenario 1 en Terminal POS
   (cantidad de producto 2, 1 opción marcada).
2. **Esperado**: el total sigue siendo `2×(precio presentación + recargo)` — exactamente el mismo
   resultado que antes de esta spec, en todos los canales donde ya se comportaba así (incluida la
   eventual diferencia entre canal QR y Terminal para grupos "Conteo" con recargo que ya existía
   desde spec 089, que esta spec no toca ni corrige).

## Verificación automatizada

- Backend: `python -m unittest discover -s app/characterization_tests -p 'test_*.py'` — deben
  pasar los tests actualizados listados en `research.md` (sección final) citando la decisión de
  negocio registrada en `registro-de-anomalias.md`.
- Frontend: `npx ng test --watch=false` — deben pasar los `.spec.ts` nuevos/actualizados de
  `product-select.component`, `pos-terminal.store`, `dining-cart.service` para `selection_mode =
  'cantidad'` fuera del canal QR.
- Regresión explícita: una línea histórica (creada antes del despliegue) debe devolver, al
  leerla, exactamente el mismo `line_total`, desglose de opciones y consumo de inventario que
  mostraba antes (`SC-005`) — no requiere ningún paso manual porque no hay backfill que verificar.
