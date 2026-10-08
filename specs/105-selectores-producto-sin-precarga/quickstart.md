# Quickstart: validar la corrección de precarga de selectores en el formulario de producto

**Spec**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md) · **Contratos**:
[contracts/](./contracts/)

Guía de validación manual, de extremo a extremo, sobre `pos-heladeria` corriendo localmente contra
un `pos-backend` con datos de un tenant que tenga **más de 100** categorías, insumos y
presentaciones activas (condición necesaria para distinguir "funciona porque estaba en la primera
página" de "funciona porque ya no depende de ninguna página" — mismo tenant de prueba usado para
validar la spec 102).

## Prerrequisitos

- `pos-backend` corriendo localmente (ver `../pos-backend/README.md` o el comando habitual del
  proyecto) contra un tenant de prueba con >100 categorías activas, >100 insumos activos y >100
  presentaciones activas.
- `pos-heladeria` corriendo localmente (`ng serve` o el comando equivalente del proyecto) apuntando
  a ese backend.
- Sesión iniciada como Administrador.
- Panel de red (Network) del navegador abierto, con el filtro limpio, antes de cada paso.

## Escenario 1 — Abrir el formulario no dispara precarga (US1 / FR-001 / FR-002 / SC-001)

1. Con el panel de red abierto y limpio, ir a Productos → "Crear producto".
2. **Verificar**: ninguna petición `GET /categories?size=100`, `GET /items?size=100` ni
   `GET /presentations?size=100` aparece en el panel (ver
   [contracts/removed-preload-requests.md](./contracts/removed-preload-requests.md)).
3. Cerrar el formulario. Limpiar el panel de red. Abrir "Editar" sobre un producto existente que
   tenga categoría, al menos un tamaño con presentación, y al menos una fila de receta con insumo.
4. **Verificar**: aparece `GET /products/{id}` (y, si el producto tiene tamaños desactivados o
   restaurables, las peticiones puntuales ya existentes para eso — sin cambios), pero **ninguna**
   de las tres peticiones de precarga completa.

## Escenario 2 — Valores ya guardados muestran su nombre real sin buscar nada (US2 / FR-003 / SC-002)

Requisito: el producto editado en el Escenario 1 debe tener su categoría, al menos una presentación
y al menos un insumo de receta con un registro que esté **fuera de los primeros 100** del catálogo
del tenant (igual que el caso de prueba usado en la spec 102 para su Historia 1).

1. Con el formulario de edición abierto (del paso 4 anterior), sin escribir nada en ningún
   selector, observar:
   - El selector de categoría muestra el nombre real de la categoría guardada.
   - El selector de presentación de cada tamaño muestra el nombre real de su presentación guardada.
   - Cada fila de receta muestra el nombre real de su insumo guardado (nunca el placeholder
     genérico "Insumo…").
2. **Verificar** que esto se cumple incluso para el registro que está fuera de la primera página
   de 100 — es la prueba de que el nombre vino del detalle del producto (o de la resolución
   puntual por id), no de una lista precargada que ya no existe.

## Escenario 3 — Crear un producto nuevo: selectores vacíos (US2, escenario 5 / FR-004)

1. Abrir "Crear producto" (formulario vacío, sin producto guardado).
2. **Verificar**: los tres selectores (categoría, presentación de cada tamaño que se agregue,
   insumo de cada fila de receta que se agregue) aparecen sin ningún valor preseleccionado.

## Escenario 4 — Buscar y elegir un registro fuera de la primera página (US3 / FR-005 / SC-003)

Para cada uno de los tres selectores (categoría, presentación, insumo), en el formulario de crear
o editar:

1. Escribir el nombre (o parte del nombre) de un registro activo que exista fuera de los primeros
   100 del catálogo del tenant.
2. **Verificar**: aparece como opción y se puede seleccionar.
3. Seleccionarlo.
4. **Verificar**: inmediatamente después de elegirlo, el selector (ya cerrado) muestra su nombre
   real — no queda en blanco ni con el placeholder genérico. Esta es la comprobación del hallazgo
   técnico de `research.md` (Decisión D1): antes de esta corrección, este caso podía fallar para un
   registro fuera de la página 100; con la corrección debe funcionar siempre, para cualquier
   registro.
5. **Verificar** en el panel de red: elegir el resultado no dispara ninguna petición de red
   adicional más allá de la búsqueda que ya se había disparado al escribir (sin una llamada extra
   de resolución por id para categoría/presentación; para insumos, solo si el picker no tenía ya el
   registro completo en memoria — ver `research.md`, Decisión D1).

## Escenario 5 — Registro inactivo ya seleccionado conserva su nombre (US2, escenario 4 / FR-007)

1. Desactivar (desde su propia pantalla: Categorías, Presentaciones o Inventario) un registro que
   esté asociado a un producto ya guardado.
2. Abrir el formulario de edición de ese producto.
3. **Verificar**: el selector correspondiente sigue mostrando el nombre real del registro, aunque
   ahora esté inactivo.
4. **Verificar**: al buscar ese mismo registro por nombre en el selector, ya no aparece como opción
   seleccionable nueva (sigue excluyendo inactivos, FR-007 / spec 102).

## Escenario 6 — Mensaje de presentaciones libres sigue siendo correcto (Principio II / Decisión D2)

No está en el Input original ni en el spec como historia propia, pero es un efecto colateral
directo de FR-002 que este plan debe preservar (ver `research.md`, Decisión D2).

1. En un tenant donde **todas** las presentaciones activas ya estén usadas por algún tamaño del
   producto que se edita, agregar un tamaño nuevo sin presentación.
2. **Verificar**: el mensaje mostrado es "No hay más presentaciones disponibles: créalas en
   Presentaciones".
3. En un tenant donde **sí** quede alguna presentación activa libre, repetir el mismo paso.
4. **Verificar**: el mensaje mostrado es "Elige una presentación" (no el mensaje de "no hay más"),
   confirmando que el cálculo ya no depende de la precarga eliminada.

## Escenario 7 — Otras pantallas no cambian (FR-008 / SC-005)

Con el panel de red abierto, visitar — sin pasar antes por el formulario de producto — cada una de
estas pantallas y confirmar que su propia precarga de catálogo completo sigue disparándose igual
que antes de esta corrección (ver `research.md`, "Otros consumidores"):

1. Categorías → listado. 2. Presentaciones → listado. 3. Inventario → ajuste de stock/kardex.
2. Compras → formulario de nueva compra. 5. Grupos de opciones → formulario de opción.
3. Promociones → formulario de criterios.

## Resultado esperado

Todos los escenarios anteriores pasan sin necesitar recargar la página entre pasos (salvo donde se
indique explícitamente desactivar/crear un registro desde otra pantalla), y ninguna petición
`GET /categories?size=100`, `GET /items?size=100` ni `GET /presentations?size=100` vuelve a
aparecer en el panel de red mientras se usa el formulario de producto.
