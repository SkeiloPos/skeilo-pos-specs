# Quickstart: Corrección — los selectores de insumo no encuentran insumos existentes fuera de los primeros 100

Valida los escenarios de aceptación de `spec.md` (Historias 1 y 2). Requiere el backend
(`pos-backend`) corriendo con una base de datos de prueba y el frontend (`pos-heladeria`)
apuntando a él, con un tenant autenticado como Administrador.

## Prerrequisitos

- `pos-backend` corriendo localmente con un tenant de prueba.
- Un script/fixture que siembre más de 100 insumos activos en ese tenant (reutilizable entre
  escenarios), con al menos uno cuyo nombre quede fuera de las primeras 100 filas por el orden que
  devuelve `GET /inventory/items` sin `search` (p. ej. un nombre que empiece por una letra tardía,
  o el ítem número 105 insertado).
- Al menos un insumo **inactivo** en ese mismo tenant, para el escenario de exclusión.

## Escenario 1 — Historia 1: "Insumos fijos" de la receta (P1, el bug reportado)

1. Con el tenant de >100 insumos activos, abrir "Carta del menú" → editar un producto con "Maneja
   inventario" activo.
2. En "Insumos fijos", agregar una fila y escribir el nombre (o parte del nombre) del insumo
   sembrado fuera de las primeras 100.
3. **Esperado**: el insumo aparece en el selector (no "Sin resultados") y puede agregarse con su
   unidad de medida correcta.

## Escenario 2 — Historia 2: Opciones, Compras, Movimientos (P2)

Repetir el mismo texto de búsqueda del Escenario 1, una vez por cada punto:

1. Grupos de opciones → editar una opción con "Maneja inventario" habilitado → buscar el insumo en
   su selector. **Esperado**: aparece y puede asociarse a la opción.
2. Inventario → Compras → registrar una compra → buscar el insumo en el selector de una línea.
   **Esperado**: aparece y puede agregarse como línea.
3. Inventario → tab "Movimientos" → registrar un movimiento manual → buscar el insumo.
   **Esperado**: aparece y puede seleccionarse.

## Escenario 3 — Insumos inactivos excluidos (los 4 selectores)

1. En cualquiera de los 4 selectores, buscar por el nombre del insumo inactivo sembrado.
2. **Esperado**: no aparece como opción en ninguno de los 4 (FR-003) — mismo criterio que
   Inventario → Insumos aplica por defecto.

## Escenario 4 — Mensaje de error distinto de "Sin resultados"

1. En cualquiera de los 4 selectores, con el backend inalcanzable o devolviendo error (p. ej.
   deteniendo `pos-backend` momentáneamente, o interceptando la petición en las herramientas de
   desarrollador del navegador para forzar un 500), escribir un texto de búsqueda.
2. **Esperado**: el selector muestra un mensaje de error distinto de "Sin resultados", con una
   opción de reintentar (Clarifications, FR-006). Al restaurar el backend y reintentar, la
   búsqueda se completa con normalidad.

## Escenario 5 — Tenants con 100 insumos activos o menos no cambian de comportamiento

1. En un tenant con, por ejemplo, 12 insumos activos (el caso típico hoy), repetir los Escenarios
   1 y 2 buscando cualquiera de esos 12 insumos.
2. **Esperado**: sigue encontrándolos y agregándolos con normalidad — ningún cambio visible frente
   al comportamiento anterior a este fix (FR-007).

## Escenario 6 — API directa, sin UI (verifica D1/D4 de `research.md`)

1. `curl`/cliente HTTP equivalente contra `GET /inventory/items?search=<texto>&active=true&page=
   1&size=20` con un token válido del tenant de prueba.
2. **Esperado**: la respuesta trae el insumo buscado en `items[]`, sin importar su posición en el
   catálogo completo — ver `contracts/inventory-items-search.md`. Este es el mismo contrato que ya
   usa Inventario → Insumos, sin cambios de backend.

## Lo que este quickstart no cubre (fuera de alcance, ver spec.md FR-009)

- La resolución de nombre/unidad de un insumo **ya asociado** a una fila existente (receta, opción
  o compra guardada antes de este fix) que haya quedado fuera de la caché de 100 de `allItems()` —
  es un defecto cosmético distinto, documentado como fuera de alcance en la spec.
- El selector de mesa (`manual-order-page.component.ts`) y cualquier otro consumidor de
  `app-searchable-select` que no sea de insumo — no cambian de comportamiento, no requieren
  revalidación.
