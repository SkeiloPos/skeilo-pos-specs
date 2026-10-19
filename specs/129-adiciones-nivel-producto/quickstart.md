# Quickstart: validar adiciones a nivel de producto

Guía de validación manual end-to-end por historia de usuario. Requiere `pos-backend` corriendo
contra Postgres con las migraciones de esta spec aplicadas, y `pos-heladeria` apuntando a esa API.
Ver [[how-to-run-sibling-repo-tests]] para cómo levantar ambos y correr sus suites.

## Prerrequisitos

```bash
cd ../pos-backend && ./env/bin/python -m alembic upgrade head
```

Un tenant con al menos: una categoría activa y visible en QR, un producto "Granizado" con dos
variantes ("Pequeño", "Grande"), y permisos de Administrador.

## US1 — Configurar una adición una sola vez para todas las variantes

1. `POST /products` con `is_topping: true`, `name: "Gomitas"`, precio en su variante default →
   `201`, respuesta con `is_topping: true`, `visible_en_qr: false` (sin haberlo pedido
   explícitamente — ver [contracts/products-api.md](./contracts/products-api.md)).
2. `PATCH /products/{granizado_id}` con `topping_ids: ["<gomitas_id>"]` → `200`.
3. `GET /products/{granizado_id}` → `topping_ids` incluye a "Gomitas", sin haber tocado ninguna
   variante de "Granizado" por separado.
4. Agregar una nueva variante ("Mediano") a "Granizado" → al volver a leer el producto, "Gomitas"
   sigue en `topping_ids` (es una asociación del producto, no de la variante — nada que heredar
   explícitamente).

**Resultado esperado**: una sola llamada de configuración por producto, cero por variante (spec
SC-001).

## US2 — Pedir una adición como línea independiente en el pedido manual

1. Abrir "Nuevo pedido" (mesa o mostrador) en `pos-heladeria`, buscar "Gomitas" en el catálogo del
   pedido manual → aparece como resultado seleccionable, igual que cualquier producto.
2. Agregarla con cantidad `3` → la línea se cobra `precio_gomitas × 3`, sin relación con ninguna
   otra línea del pedido.
3. Confirmar el pedido y revisar el recibo/comanda → la línea aparece igual que cualquier línea de
   producto (SC-002).

## US3 — Adiciones ocultas del menú QR pero disponibles al personalizar

1. `GET /menu/qr-token/{token}` (o abrir el menú QR en el navegador) → buscar "Gomitas": **no**
   aparece como tarjeta ni como resultado (FR-008, SC-003).
2. Abrir "Granizado" para personalizarlo → el selector de "Adiciones disponibles" muestra
   "Gomitas" con su precio de catálogo; elegir cantidad `2` y agregarlo al carrito.
3. `GET /cart` (con el `x-session-token` de la sesión) → la línea de "Granizado" trae
   `toppings: [{ topping_product_id: <gomitas_id>, quantity: 2, unit_price: ... }]`.
4. Enviar el pedido (`POST /cart/submit`) → el pedido resultante conserva la adición adjunta
   (SC-004).

**Variante del edge case**: después del paso 2 (carrito con "Gomitas" adjunta, sin enviar aún),
quitar la asociación (`PATCH /products/{granizado_id}` con `topping_ids: []`) y luego enviar el
pedido → la adición se quita del carrito con el mensaje esperado, el resto del pedido se envía
igual (FR-014).

## US4 — Visibilidad en QR por producto

1. Crear o elegir un producto regular visible en QR. Confirmar que aparece en el menú QR.
2. `PATCH /products/{id}` con `visible_en_qr: false` → el producto deja de aparecer en el menú QR
   al recargar, pero sigue disponible al buscarlo en el pedido manual (SC-005).
3. `PATCH /products/{id}` con `visible_en_qr: true` → vuelve a aparecer, en la misma posición
   dentro de su categoría.
4. Repetir el paso 2 sobre un producto de una categoría ya oculta en QR (spec 128) → el producto
   sigue sin aparecer en el menú QR aunque su propio flag sea `true` (FR-012).
5. Como Cajero (no Administrador), intentar `PATCH /products/{id}` con `visible_en_qr` → `403`.

## Verificación de no regresión (Principio III)

```bash
cd ../pos-backend && ./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'
```

Ningún test `"CONGELA comportamiento actual:"` sobre `option_groups`/`variant_option_groups`
debe cambiar de resultado — esta spec no toca ese mecanismo (research.md D1). Comparar el conteo
total contra el baseline más reciente registrado en [[how-to-run-sibling-repo-tests]] antes de
asumir que cualquier diferencia es intencional.
