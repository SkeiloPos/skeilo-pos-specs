# Quickstart: Nombre comercial propio para los tamaños de un producto

Valida las 4 historias de usuario y los 18 escenarios de aceptación de `spec.md`. Requiere el
backend (`pos-backend`) corriendo con una base de datos de prueba migrada hasta
`e7d8c9b0a1f2_099_nombre_tamano_variante` y el frontend (`pos-heladeria`) apuntando a él.

## Prerrequisitos

- `pos-backend` corriendo localmente con un tenant de prueba autenticado como Administrador.
- Un producto de prueba con al menos dos variantes (tamaños), cada una con una `Presentation`
  distinta (p. ej. "Pequeño 8 onz" y "Grande 16 onz").
- Acceso a la API (`curl` o equivalente) además de la interfaz, para los escenarios de
  compatibilidad y migración.

## Historia 1 — El comensal ve el nombre comercial del tamaño, no uno vacío

1. Desde "Tamaños del producto", ponle `name = "Para compartir"` a la variante "Grande 16 onz" y
   guarda; deja la variante "Pequeño 8 onz" sin nombre.
2. Abre el detalle del producto en el menú público.
   **Esperado**: la variante grande muestra "Para compartir"; la pequeña muestra "Pequeño 8 onz"
   — ver [contracts/product-variants-api.md](./contracts/product-variants-api.md) §Menú público
   (Escenarios 2, 3).
3. Agrega "Para compartir" al carrito y avanza al resumen del checkout.
   **Esperado**: ambas pantallas muestran "Para compartir" (Escenario 11).
4. `GET /products/{id}` directamente (sin UI).
   **Esperado**: la variante grande trae `name: "Para compartir"`, `display_name: "Para
   compartir"`; la pequeña trae `name: ""`, `display_name: "Pequeño 8 onz"`.
5. Pon `<b>x</b>` como nombre de una variante y guárdalo.
   **Esperado**: en el detalle del producto se ve literalmente el texto `<b>x</b>`, nunca en
   negrita ni ejecutado como HTML (Escenario 13).

## Historia 2 — El administrador gestiona el nombre desde el formulario

1. En "Tamaños del producto", verifica que cada fila tiene el campo "Nombre (opcional)" junto a la
   presentación (Escenario 6).
2. Elige una presentación y deja el nombre vacío.
   **Esperado**: el placeholder dice `Se mostrará: <nombre de la presentación>` (Escenario 7).
3. En una fila sin presentación elegida todavía.
   **Esperado**: el placeholder dice `Se mostrará la presentación`.
4. Escribe `"   "` (solo espacios) como nombre y guarda.
   **Esperado**: se guarda como `""`; la variante vuelve a mostrar la presentación (Escenario 4).
5. Escribe `"  Para   compartir  "` y guarda.
   **Esperado**: se guarda `"Para compartir"` (Escenario 5).
6. Escribe 61 caracteres en el nombre.
   **Esperado**: el formulario muestra "El nombre admite hasta 60 caracteres" y el guardado no se
   envía (Escenario 8); si se envía igual por API, el backend responde 422 (ver
   [contracts/product-variants-api.md](./contracts/product-variants-api.md)).
7. Ponle a una segunda variante del mismo producto el mismo nombre que ya resuelve otra (por
   nombre propio repetido o porque coincide con la presentación que usa una variante sin nombre).
   **Esperado**: "Ya existe un tamaño con ese nombre en este producto"; no se guarda (Escenario 9,
   409 según el contrato).
8. Borra el nombre de la variante "Para compartir" del paso 1 de la Historia 1 y guarda.
   **Esperado**: esa variante vuelve a mostrar "Grande 16 onz" en el menú público.
9. Con `curl`, envía una petición de crear/editar variante sin el campo `name`, y otra con
   `"name": null`.
   **Esperado**: ambas se guardan como `name: ""`, sin error (Escenario 14).

## Historia 3 — Los datos y los clientes existentes no se rompen con el cambio

1. Antes de migrar, anota el `presentation_name` mostrado en el menú público para 2-3 variantes
   existentes.
2. Ejecuta la migración (`alembic upgrade head`, incluye
   `e7d8c9b0a1f2_099_nombre_tamano_variante`).
   **Esperado**: `GET /products/{id}` de esas variantes trae `name: ""`; su presentación, precio,
   orden y cantidad no cambiaron; el menú público las muestra exactamente igual que antes
   (Escenario 1).
3. Abre un pedido ya facturado antes de la migración, en Órdenes o Ventas.
   **Esperado**: se muestra sin ninguna modificación (Escenario 12).
4. Simula un frontend en caché de una versión anterior: consume `GET /menu` ignorando el campo
   `display_name` (quédate solo con `presentation_name`, como hacía antes).
   **Esperado**: sigue mostrando la presentación sin errores (Escenario 15).
5. Ejecuta el downgrade (`alembic downgrade -1`).
   **Esperado**: la columna `name` desaparece; presentaciones, precios y pedidos quedan intactos
   (Escenario 18). Ejecutar el módulo de prueba de la migración:
   `python -m unittest app.characterization_tests.test_variant_display_name -v`.

## Historia 4 — Renombrar una presentación no toca los nombres propios ya puestos

1. Con la variante "Pequeño 8 onz" sin nombre propio y la variante "Para compartir" (Grande 16 onz,
   con nombre propio) del mismo producto, renombra la presentación "Pequeño 8 onz" a "Pequeño 250
   ml" desde la pantalla de Presentaciones.
2. Recarga el menú público del producto.
   **Esperado**: la primera variante ahora muestra "Pequeño 250 ml"; la segunda sigue mostrando
   "Para compartir", sin cambios (Escenario 10).

## Escenario 16 — Nunca una etiqueta vacía, aunque falte la presentación

Este caso requiere manipular datos directamente (no alcanzable desde la UI, ya que
`presentation_id` es obligatorio y `RESTRICT` impide borrar una presentación en uso):

1. En un entorno de prueba, fuerza una variante con `name = ''` y cuya fila de `Presentation`
   asociada no tenga `name` resoluble (p. ej. simulando el fallo en un test unitario del modelo,
   no contra la base real).
2. Lee `display_name`.
   **Esperado**: devuelve `"Tamaño"` y queda una línea de advertencia en el log del servidor con el
   `id` de la variante (Escenario 16) — verificable con el test unitario de la propiedad
   `display_name` en `test_variant_display_name.py`.

## Escenario 17 — Aislamiento y rendimiento

1. Siembra un tenant con 40 productos y 3 variantes cada uno (120 variantes en total).
2. Consulta `GET /menu` y cuenta las consultas SQL ejecutadas (log de SQLAlchemy o `EXPLAIN
   ANALYZE` del lado de la app).
   **Esperado**: el número de consultas no crece con la cantidad de variantes (una consulta de
   productos con `selectinload`/`lazy="joined"` ya cubre presentación y nombre propio, research.md
   D2/D7).
3. Repite la consulta como un subdominio de **otro** tenant.
   **Esperado**: solo se devuelven productos y variantes de ese segundo tenant.

## Lo que este quickstart no cubre (fuera de alcance, ver spec.md y research.md D11)

- El texto de línea que se persiste en un pedido o venta al finalizar el pago
  (`format_item_description`) y las pantallas de Órdenes/Ventas — siguen mostrando
  `presentation_name`, sin ningún cambio, tanto para pedidos nuevos como antiguos.
- `GET /categories`, `GET /presentations` y cualquier pantalla que no sea "Tamaños del producto"
  o el menú público del comensal.
