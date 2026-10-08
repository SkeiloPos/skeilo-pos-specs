# Quickstart: Corrección y mejora de rendimiento del formulario de crear/editar producto

Valida los escenarios de aceptación de `spec.md` (Historias 1-4). Requiere el backend
(`pos-backend`) corriendo con una base de datos de prueba y el frontend (`pos-heladeria`)
apuntando a él, con un tenant autenticado como Administrador.

## Prerrequisitos

- `pos-backend` corriendo localmente con un tenant de prueba.
- Fixtures que siembren, en ese tenant: más de 100 insumos activos, más de 100 categorías activas
  y más de 100 presentaciones activas, con al menos un registro de cada catálogo fuera de la
  primera página de 100 (p. ej. el registro número 105 insertado).
- Un producto existente con "Maneja inventario" activo y una receta guardada que incluya un
  insumo fuera de los primeros 100 (para la Historia 1).
- Un producto existente con 8 o más tamaños (variantes) activos, cada uno con su propia receta y
  grupos de opciones (para la Historia 2).

## Escenario 1 — Historia 1: el insumo ya guardado siempre muestra su nombre real (P1, el bug reportado)

1. Abrir el formulario de edición del producto con la receta preparada en los prerrequisitos.
2. **Esperado**: el selector de "Insumos fijos" muestra el nombre real del insumo (no "Insumo…"),
   con su cantidad guardada — ver `contracts/inventory-item-by-id.md`.
3. Repetir para una opción de grupo de opciones cuyo desglose de consumo referencie el mismo
   insumo. **Esperado**: también muestra el nombre y unidad reales.
4. Desactivar ese insumo desde Inventario → Insumos sin quitarlo de la receta, y reabrir el
   formulario. **Esperado**: el nombre real sigue mostrándose (FR-004).

## Escenario 2 — Historia 2: abrir un producto con varios tamaños no escala con el número de tamaños

1. Con las herramientas de red del navegador abiertas, abrir el formulario de edición del
   producto con 8+ tamaños de los prerrequisitos.
2. **Esperado**: las peticiones de receta y grupos de opciones de los 8+ tamaños aparecen
   disparadas al mismo tiempo (mismo instante de inicio), no en cascada una tras otra.
3. Comparar el tiempo total hasta que el formulario queda usable contra el de un producto con 2
   tamaños. **Esperado**: no escala de forma proporcional al número de tamaños.
4. Forzar que la petición de receta de un tamaño específico falle (p. ej. interceptando esa
   petición para devolver un error). **Esperado**: los demás tamaños quedan disponibles para
   usarse; el tamaño que falló muestra un indicador de error con un control de reintentar que, al
   usarse (con la red restaurada), carga con normalidad sin afectar a los demás tamaños.

## Escenario 3 — Historia 3: buscar y elegir cualquier insumo, categoría o presentación activa

Con el tenant de >100 registros activos en los tres catálogos:

1. En "Insumos fijos", escribir el nombre de un insumo fuera de los primeros 100. **Esperado**:
   aparece y puede seleccionarse (ya satisfecho por la spec 098 — este paso es de regresión, no de
   funcionalidad nueva).
2. En el selector de Categoría, escribir el nombre de una categoría fuera de las primeras 100.
   **Esperado**: aparece y puede seleccionarse — ver `contracts/categories-search.md`.
3. En el selector de Presentación de cualquier tamaño, escribir el nombre de una presentación
   fuera de las primeras 100. **Esperado**: aparece y puede seleccionarse — ver
   `contracts/presentations-search.md`.
4. Buscar por un registro inactivo en cualquiera de los tres selectores. **Esperado**: no aparece.
5. En un tenant con 100 registros activos o menos en algún catálogo, repetir 1-3. **Esperado**: sin
   cambios de comportamiento frente a antes de esta corrección (FR-010).

## Escenario 4 — Historia 3b: la categoría ya elegida no desaparece al migrar su selector

1. Editar un producto cuya categoría esté fuera de las primeras 100 categorías activas del
   tenant.
2. **Esperado**: el selector de Categoría muestra el nombre real de esa categoría ya seleccionada,
   igual que ya ocurre hoy para la presentación ya elegida de cada tamaño (research.md D4).

## Escenario 5 — RETIRADO (2026-10-08): ya no aplica

Historia 4 (catálogos actualizados sin recargar la aplicación) se implementó y luego se retiró a
pedido explícito del dueño/desarrollador del proyecto — ver spec.md (Clarifications) y
research.md (D5, segunda adenda). El comportamiento esperado ahora es el que había antes de esta
spec: un registro creado en otra sesión mientras el formulario está abierto no aparece hasta
recargar la página manualmente.
5. Con un selector de la Sesión A ya desplegado (escribiendo texto) justo cuando ocurre el
   refresco en segundo plano, verificar que el desplegable no se cierra ni se pierde el texto
   escrito (research.md D5, FR-013/FR-014).
6. Con una fila de receta de la Sesión A ya con un insumo elegido, verificar que ese insumo sigue
   elegido después del refresco en segundo plano (FR-013).

## Escenario 6 — API directa, sin UI (verifica D1/D3 de `research.md`)

1. `curl`/cliente HTTP equivalente contra `GET /inventory/items/{id}` con el id de un insumo
   referenciado por una receta existente. **Esperado**: devuelve el insumo con su nombre real, sin
   importar su posición en el catálogo completo.
2. Repetir contra `GET /categories?search=<texto>&active=true&page=1&size=20` y `GET
   /presentations?search=<texto>&active=true&page=1&size=20` con un texto que coincida con un
   registro fuera de los primeros 100. **Esperado**: cada respuesta trae el registro buscado en
   `items[]` — ver `contracts/categories-search.md` y `contracts/presentations-search.md`. Mismo
   contrato que ya usan sus pantallas de administración respectivas, sin cambios de backend.

## Lo que este quickstart no cubre (fuera de alcance, ver spec.md Assumptions)

- Un defecto cosmético análogo en el selector de mesa (`manual-order-page.component.ts`) o en
  cualquier otro consumidor de `app-searchable-select` que no sea insumo, categoría o
  presentación — no cambian de comportamiento, no requieren revalidación.
- Notificación en tiempo real (websockets) de catálogos nuevos — el mecanismo validado es sondeo
  periódico + refresco al recuperar el foco, no una actualización instantánea.
- Cambios en la forma en que se guarda el producto — el payload de creación/edición no cambia
  (FR-015); este quickstart no incluye escenarios de guardado.
