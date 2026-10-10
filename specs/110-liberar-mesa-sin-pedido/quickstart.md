# Quickstart: Validar la corrección — Mesa ocupada sin pedido no se puede liberar

## Prerrequisitos

- `pos-backend` corriendo localmente (ver memoria del proyecto: comando del venv, sin Postgres
  local — usar la base de datos remota/compartida configurada para desarrollo).
- `pos-heladeria` corriendo localmente (`ng serve` o equivalente) apuntando a ese backend.
- Un tenant de prueba con al menos una mesa física disponible y un usuario cajero o admin
  autenticado en la terminal de mesas.

## Escenario 1 — Caso que hoy falla (reproducir el bug antes del fix)

1. Abrir la terminal de mesas y seleccionar una mesa libre.
2. Crear un pedido manual sobre esa mesa (sin confirmarlo en cocina).
3. Rechazar/cancelar ese pedido manual desde la propia terminal, antes de que cocina reciba nada.
4. Verificar en la grilla que la mesa sigue mostrándose como **"ocupada"** (confirma la causa raíz:
   `try_release_if_empty` no se dispara en este camino).
5. Hacer click sobre esa mesa.
6. **Comportamiento actual (bug)**: no aparece ningún panel de detalle ni acción — la mesa queda
   sin ninguna forma de liberarse desde la interfaz.

## Escenario 2 — Validar el fix

Repetir los pasos 1-5 anteriores sobre una build con la corrección aplicada:

6. **Comportamiento esperado**: aparece el panel de detalle de la mesa, sin listado de ítems ni
   cuenta (porque no hay pedidos), con "Liberar Mesa" como única acción visible.
7. Presionar "Liberar Mesa".
8. Verificar que la mesa vuelve a mostrarse como **"libre"** en la grilla, sin ningún error en
   pantalla ni en la consola del navegador.
9. Verificar (API o reintentando el flujo) que la mesa admite abrir una sesión nueva con
   normalidad.

## Escenario 3 — Regresión: mesa realmente libre

1. Seleccionar una mesa que nunca se abrió (sin sesión activa).
2. Verificar que el comportamiento no cambió: se sigue mostrando como mesa libre, sin panel de
   detalle con acciones de liberación.

## Escenario 4 — Regresión: mesa con pedido activo

1. Seleccionar una mesa con al menos un pedido vivo (confirmado, no cancelado).
2. Verificar que el panel de detalle muestra el pedido y sus acciones normales, sin cambios
   respecto al comportamiento actual.

## Escenario 5 — Regresión: spec 050 (pedido cancelado con ítems sin terminar en cocina)

1. Reproducir el escenario de la spec
   [050](../050-correccion-liberar-mesa-pedido-cancelado/spec.md) (pedido cancelado con algún ítem
   todavía `'pendiente'`/`'en_preparacion'` en cocina).
2. Verificar que "Liberar Mesa" sigue funcionando sin el error "Hay ítems sin terminar en cocina"
   (esa corrección no se revierte con este fix).

## Verificación automatizada

- Tests unitarios de `centralState`/`deriveTableStatus` en `pos-terminal.store.spec.ts` (o archivo
  equivalente): casos "mesa ocupada + 0 pedidos → no colapsa a `mesa-libre`" y "mesa libre real →
  sigue colapsando a `mesa-libre`".
- Tests de `table-sessions.component.ts` / `pos-checkout-panel.component.ts` que cubran que el
  botón "Liberar Mesa" se renderiza y es funcional sin `sessionBill()`/pedidos.
- Suite completa de `ng test` en verde, sin romper characterization tests existentes de la
  terminal de mesas.
