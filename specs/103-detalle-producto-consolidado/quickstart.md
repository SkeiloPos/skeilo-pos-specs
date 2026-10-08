# Quickstart: Consolidar receta y grupos de opciones en el detalle de producto

Valida los escenarios de aceptación de `spec.md` (Historia única). Requiere `pos-backend`
corriendo con una base de datos de prueba y `pos-heladeria` apuntando a él, con un tenant que
tenga al menos un usuario Admin y un usuario Cajero.

## Prerrequisitos

- Un producto con "Maneja inventario" activo y 5 o más tamaños (variantes activas), cada uno con
  su propia receta y al menos un grupo de opciones.
- Al menos un tamaño desactivado de ese mismo producto (para el Escenario 3).
- Un usuario con rol Cajero y uno con rol Admin en el mismo tenant.

## Escenario 1 — Abrir el formulario de edición dispara cero peticiones por tamaño

1. Como Admin, con las herramientas de red del navegador abiertas, abrir el formulario de edición
   del producto de los prerrequisitos.
2. **Esperado**: tras la petición a `GET /products/{id}`, no aparece ninguna petición a `GET
   /variants/{id}/recipe` ni `GET /variants/{id}/option-groups` para ninguno de los 5+ tamaños —
   ver `contracts/products-detail-embedded.md`.
3. **Esperado**: la receta y los grupos de opciones mostrados para cada tamaño son los mismos que
   se mostraban antes de esta optimización (mismos insumos, cantidades y grupos).

## Escenario 2 — El número total de peticiones no crece con el número de tamaños

1. Repetir el Escenario 1 con un producto de 2 tamaños y con uno de 10+ tamaños.
2. **Esperado**: el número total de peticiones de red para dejar el formulario listo es el mismo
   en ambos casos (1: `GET /products/{id}`, que ya trae embebidas tanto `variants[]` activas con
   receta/grupos como `deactivated[]` — research.md D6, 2026-10-08) — no escala con el número de
   tamaños.

## Escenario 3 — Un tamaño sin receta/grupos, y uno desactivado

1. Editar un tamaño del producto para que no tenga ningún insumo fijo ni grupo de opciones.
2. Reabrir el formulario de edición. **Esperado**: ese tamaño se muestra con receta y grupos
   vacíos, igual que antes de esta optimización.
3. Revisar la lista de "desactivados" del formulario. **Esperado**: el tamaño desactivado de los
   prerrequisitos sigue apareciendo ahí, restaurable, sin recibir receta/grupos embebidos (sigue
   pidiéndolos por separado solo si se restaura — Escenario 5).

## Escenario 4 — Cajero nunca recibe receta, sí recibe grupos de opciones

1. Como Cajero, abrir "Carta del menú → detalle de producto" del mismo producto, con las
   herramientas de red abiertas.
2. **Esperado**: la respuesta de `GET /products/{id}` trae `variants[].recipe: []` para los 5+
   tamaños, pero `variants[].option_groups` sí viene poblado — ver
   `contracts/products-detail-embedded.md`, tabla de roles.
3. **Esperado**: ningún dato de `inventory_item_id` ni cantidad de receta aparece en ninguna
   respuesta de red recibida por el Cajero durante este flujo.

## Escenario 5 — Restaurar un tamaño desactivado sigue pidiendo solo esa variante

1. Como Admin, en el formulario de edición, restaurar el tamaño desactivado de los prerrequisitos.
2. **Esperado**: se disparan `GET /variants/{id}/recipe` y `GET /variants/{id}/option-groups`
   **solo** para esa variante — no una nueva petición de detalle completo del producto.

## Escenario 6 — El control de "Reintentar" por tamaño ya no aparece

1. Revisar el formulario de edición de cualquier producto con varios tamaños, incluso simulando
   una respuesta de error en `GET /products/{id}` (p. ej. interceptándola para forzar un 500).
2. **Esperado**: no existe ningún control de "Reintentar" a nivel de un tamaño individual — el
   único reintento posible ante un error es recargar/reabrir el formulario completo (FR-009).

## Escenario 7 — API directa, sin UI (verifica D1/D2/D3 de `research.md`)

1. `curl`/cliente HTTP equivalente contra `GET /products/{id}` con un token de Admin válido.
   **Esperado**: `variants[]` trae `recipe` y `option_groups` poblados para cada variante activa,
   con la misma forma que ya devuelven `GET /variants/{id}/recipe` y `GET
   /variants/{id}/option-groups` para esa misma variante.
2. Repetir con un token de Cajero. **Esperado**: `variants[].recipe` viene vacío (`[]`) en todas
   las variantes; `variants[].option_groups` viene igual de poblado que con el token de Admin.

## Lo que este quickstart no cubre (fuera de alcance, ver spec.md Assumptions)

- Cambios en qué insumos, grupos de opciones o presentaciones son válidos para un producto — esta
  spec no toca esas reglas.
- El menú público del comensal (`GET /menu`) — no se modifica, no requiere revalidación.
- La forma en que se guarda el producto (crear/editar) — sin cambios, no cubierto aquí.
