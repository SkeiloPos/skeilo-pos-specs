# Research: Corrección — Mesa ocupada sin pedido no se puede liberar

No quedaban `[NEEDS CLARIFICATION]` en `spec.md` (ver checklist de calidad); la investigación de
código previa a esta spec ya identificó la causa raíz exacta y la solución ya existente a la que
alinearse (`deriveTableStatus`). Este documento registra las decisiones técnicas evaluadas para
Phase 1.

## Decisión 1: Dónde corregir la señal de "mesa ocupada sin pedido"

**Decision**: hacer que `centralState` (`pos-terminal.store.ts:628-637`) consulte el `status` real
de la mesa seleccionada (vía el mismo criterio que ya usa `deriveTableStatus`,
`pos-terminal.store.ts:222-259`, líneas 254-258) antes de colapsar a `'mesa-libre'` cuando
`tableOrders(tableId).length === 0`. Si la mesa está genuinamente `'libre'` (o `'reservada'`, fuera
de alcance), se mantiene `'mesa-libre'`. Si la mesa tiene `status === 'ocupada'` sin pedidos vivos,
`centralState` devuelve un nuevo valor (p. ej. `'ocupada-sin-pedido'`) que el panel de detalle
interpreta como "solo liberar".

**Rationale**: `deriveTableStatus` ya resuelve correctamente esta misma distinción para la
insignia de la grilla (línea 256: `if (tableStatus === 'ocupada') return 'ocupada';`), pero
`centralState` nunca la consulta — es exactamente la discrepancia que causa el bug. Reutilizar el
mismo criterio evita introducir una segunda fuente de verdad sobre qué significa "ocupada".

**Alternatives considered**:
- *Cambiar el backend para auto-liberar la mesa cuando se cancela el único pedido pendiente*
  (extender `try_release_if_empty` al camino de `cancel_order`): rechazada — liberaría la mesa sin
  que el cajero lo confirme explícitamente, un cambio de comportamiento de negocio (quién decide
  que una mesa queda libre) que no fue lo que pidió el usuario ni está autorizado por el spec; el
  spec pide expresamente que el cajero/admin vea el detalle y decida liberar, no una liberación
  automática silenciosa.
- *Mostrar un estado "vacío" genérico distinto al panel de checkout, con su propio botón "Liberar
  Mesa" duplicado*: rechazada por Principio V/VI de la constitución — duplicaría la lógica de
  `releaseTable()` que ya vive en `pos-checkout-panel.component.ts:401-408`, en vez de reusarla
  condicionalmente.

## Decisión 2: Qué debe mostrar el panel de detalle para este caso

**Decision**: `pos-checkout-panel.component.ts` ya guarda el botón "Liberar Mesa" detrás de
`@if (store.sessionBill(); as bill)` (línea 358) — una guarda que existe porque hoy siempre hay una
cuenta/pedido cuando el panel llega a renderizarse. Para el caso sin pedidos, el panel debe poder
mostrar el botón "Liberar Mesa" sin depender de que exista `sessionBill()`/pedidos, y sin mostrar
ningún listado de ítems o cuenta (porque no existen).

**Rationale**: reutilizar el componente que ya contiene `releaseTable()` minimiza el cambio y
mantiene una sola implementación del flujo de liberación (coherente con el fix de backend ya
existente en `release_paid_session`, que no requiere pedidos).

**Alternatives considered**:
- *Redirigir automáticamente a la vista de "mesa libre" tras liberar, sin mostrar nada intermedio*:
  no aplica — ya es el comportamiento esperado una vez se libera (la mesa pasa a estar realmente
  libre); no cambia esta decisión, solo el post-condición ya cubierta por el flujo existente de
  `releaseTable()`.

## Decisión 3: Alcance de pruebas

**Decision**: tests unitarios sobre `centralState`/`deriveTableStatus` (mesa ocupada + 0 pedidos →
no colapsa a `'mesa-libre'`; mesa libre real → sigue colapsando) y sobre el guard de render del
panel de detalle; validación manual end-to-end según `quickstart.md` para el flujo completo
(crear sesión → rechazar pedido → click mesa → ver botón → liberar → mesa vuelve a libre).

**Rationale**: Principio X de la constitución exige verificación combinando tests existentes,
characterization tests y los criterios de aceptación del spec — no basta con prueba manual para
una corrección de un computed que ya tiene cobertura previa parcial.

**Alternatives considered**: ninguna — es el mínimo exigido por la constitución del proyecto.
