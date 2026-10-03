# Quickstart: validar "Carta del menú para Cajero con estado Agotado"

**Spec**: [spec.md](./spec.md) | **Contratos**: [contracts/](./contracts/)

Esta guía valida de extremo a extremo las tres historias de usuario de la spec, sobre un
tenant de prueba con al menos un producto activo con una presentación y precio (p. ej.
"Fresa boom"). No sustituye los tests automatizados que define `tasks.md` — es la
verificación manual de que el comportamiento descrito en `spec.md` ocurre de verdad.

## Prerrequisitos

- `pos-backend` corriendo localmente con un tenant de prueba, un usuario `ADMIN` y un
  usuario `CASHIER` (`role.name = "CASHIER"`) del mismo tenant.
- `pos-heladeria` corriendo localmente contra ese backend.
- Un producto activo con al menos una presentación (p. ej. "Fresa boom", $18.000, "1
  litro") y, para el escenario 10, un segundo producto marcado como inactivo.
- Una mesa abierta (para el escenario 5/7) y el menú QR accesible por token (para el
  escenario 6/7).

## Historia 1 — Consultar la carta y marcar productos como agotados

1. Iniciar sesión como Cajero → el sidebar muestra "CATÁLOGO" con una única opción,
   "Carta del menú"; no aparecen Categorías, Presentaciones ni Promociones
   (`contracts/frontend-route-access.md`, escenario 1).
2. Entrar a "Carta del menú" → ver nombre, categoría, preparación, estado y
   disponibilidad de cada producto; buscar por nombre; filtrar por Todos/Disponibles/
   Agotados; confirmar que no aparece "Nuevo producto" ni acciones de editar/desactivar,
   y que no aparece ningún mensaje de error de permisos (escenario 2).
3. Sobre "Fresa boom" (activo y disponible), activar el interruptor "Agotado" → la fila
   pasa a mostrar la etiqueta "Agotado" y "desde hace unos segundos"; aparece la
   confirmación "Fresa boom marcado como agotado" (escenario 3). Verificar en la base de
   datos (o reabriendo el detalle) que `available_changed_at`/`available_changed_by_name`
   quedaron con el usuario y la hora correctos (`contracts/products-api.md`).
4. Desactivar el interruptor sobre el mismo producto → vuelve a "Disponible", la
   etiqueta desaparece (escenario 4).
5. Abrir el detalle ("Ver detalle" o clic en la fila) de cualquier producto como Cajero
   → ver imagen, nombre, descripción, categoría, tipo de preparación, presentaciones con
   precio, estado y disponibilidad, todo de solo lectura salvo el interruptor "Agotado";
   confirmar que no aparece costo, receta ni dato de inventario (escenario 9,
   `contracts/products-api.md`).
6. Sobre el producto inactivo de prueba, confirmar que el listado lo muestra como
   "Inactivo" y que el interruptor "Agotado" aparece deshabilitado (escenario 10,
   `data-model.md`, matriz de estados).
7. Repetir el paso 3 iniciando sesión como Administrador → confirmar que conserva todas
   sus acciones actuales (Nuevo producto, editar, desactivar) y que puede usar el mismo
   interruptor "Agotado" (escenario 15).

## Historia 2 — Evitar pedidos de productos agotados

Con "Fresa boom" marcado como agotado (repetir paso 3 de arriba si hace falta):

1. **Terminal de mesas**: abrir "Nueva orden" sobre una mesa y buscar "Fresa boom" → debe
   verse atenuado, con la etiqueta "Agotado", y el botón/tarjeta de agregar debe estar
   deshabilitado (escenario 5, `contracts/menu-and-orders.md`).
2. **Menú QR**: abrir el menú como comensal (vía el token de la mesa) → "Fresa boom"
   debe verse con la etiqueta "Agotado" y no debe poder agregarse al carrito
   (escenario 6).
3. **Carrito ya armado**: como comensal, agregar "Fresa boom" al carrito **antes** de
   marcarlo agotado; luego, como Cajero (en otra sesión/pestaña), marcarlo agotado;
   finalmente, como el mismo comensal, intentar confirmar el pedido → el sistema debe
   rechazarlo nombrando "Fresa boom", no debe crearse ninguna orden, y el resto del
   carrito (si había otros productos) debe conservarse (escenario 7,
   `contracts/menu-and-orders.md`, respuesta 409 con `productos_agotados`).
4. **Pedidos existentes**: verificar que un pedido pendiente creado **antes** de marcar
   "Fresa boom" como agotado sigue intacto y su flujo (cocina, cobro) no cambia
   (escenario 8).

## Historia 3 — Garantías de API, seguridad y consistencia

Usar un cliente HTTP directo (curl/Postman) con el token de un usuario Cajero:

1. `POST /products`, `PATCH /products/{id}` (el endpoint completo, no
   `/availability`), `DELETE /products/{id}` → cada uno debe responder `403` y no
   modificar nada (escenario 11, `contracts/permissions.md`).
2. `GET /products/{id}` y `GET /variants/{id}/recipe` → la primera no debe incluir
   costo/receta/inventario (ya es así hoy); la segunda debe responder `403` para Cajero
   (escenario 12, `contracts/products-api.md`).
3. Simular una falla de red (p. ej. cortando la conexión o forzando un 500) justo al
   activar el interruptor "Agotado" → el interruptor en pantalla debe quedar/volver a su
   estado anterior y debe verse un mensaje de error indicando que no se pudo guardar
   (escenario 13, research.md D12).
4. Disparar dos `PATCH /products/{id}/availability` casi simultáneos con valores
   distintos (p. ej. `true` y luego `false` sin esperar la primera respuesta) → el valor
   final debe corresponder a la última petición que el servidor procesó, sin quedar en
   un estado intermedio inconsistente (escenario 14, research.md D10).
5. Con un token de Cajero del tenant A, intentar `GET`/`PATCH .../availability` sobre un
   producto del tenant B → debe responder `404` (escenario 16, `contracts/
   permissions.md`).

## Verificación de la decisión de negocio A-104

Confirmar que un producto marcado "Agotado" **antes** de esta spec habría desaparecido
del menú QR/Terminal, y que **después** de implementar esta spec sigue apareciendo,
atenuado — esta comparación es la evidencia de que la anomalía A-104 (`specs/
000-reconocimiento/registro-de-anomalias.md`) quedó resuelta como se documentó.
