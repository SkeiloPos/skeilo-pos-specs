# Quickstart: Validar ocultamiento de la sección Inventario en el formulario de carta

**Feature**: `160-gating-inventario-form-menu`

Esta guía valida end-to-end los tres user stories del spec (`spec.md`) usando datos reales
de un tenant de prueba en `pos-heladeria` + `pos-backend`. No requiere mocks: el estado del
plan se lee del tenant real vía `PlanSummaryService` (ver `research.md`, Decisión 1).

## Prerrequisitos

- `pos-backend` corriendo localmente con Postgres disponible (ver memoria del proyecto:
  venv de `pos-backend` y Postgres local ya configurados).
- `pos-heladeria` corriendo localmente (`ng serve` o equivalente) apuntando a ese backend.
- Un tenant de prueba con al menos un producto que tenga más de un tamaño/presentación, y
  con insumos de inventario ya configurados en alguno de esos tamaños (`tracks_inventory =
  true` + recetas/insumos guardados), para poder probar el Edge Case de "no perder datos".
- Acceso para cambiar el plan asignado a ese tenant (o el flag `modules.inventario` de su
  plan) entre una corrida y otra.

## Escenario 1 — Plan sin módulo de Inventario (User Story 1, P1)

1. Asegurar que el plan del tenant de prueba tiene `modules.inventario = false`.
2. Iniciar sesión como administrador de ese tenant y abrir el formulario de edición del
   producto que ya tenía insumos configurados (carta → editar producto).
3. **Resultado esperado**: en cada tamaño/presentación del producto, la sección
   "Inventario" (interruptor "Maneja inventario" + contenido) no aparece en absoluto en el
   DOM — no hay texto de upsell, no hay interruptor deshabilitado. El botón de salto
   "Inventario" en la tabla de tamaños tampoco aparece.
4. Guardar el formulario sin tocar nada relacionado a inventario (ej. solo cambiar el
   nombre del producto) y confirmar por API/DB que los insumos previamente guardados para
   ese tamaño siguen intactos (FR-005).

## Escenario 2 — Plan con módulo de Inventario (User Story 2, P1)

1. Cambiar el plan del tenant de prueba para que `modules.inventario = true`.
2. Recargar/reabrir el formulario del mismo producto.
3. **Resultado esperado**: la sección "Inventario" se muestra en cada tamaño, con el
   interruptor habilitado. Si el tamaño ya tenía `tracks_inventory = true`, el contenido de
   insumos aparece con los datos previamente guardados (preservados en el Escenario 1),
   editable con normalidad.
4. Activar "Maneja inventario" en un tamaño que no lo tenía, configurar un insumo y
   guardar. Confirmar que se guarda sin restricciones adicionales.

## Escenario 3 — Cambio de plan durante la sesión (User Story 3, P2)

1. Con el tenant en estado "con módulo" (como quedó al final del Escenario 2), con el
   usuario con sesión abierta, cambiar el plan del tenant a "sin módulo de Inventario"
   desde otro canal (ej. panel de administración de planes).
2. Sin cerrar sesión, recargar/reabrir el formulario de carta del mismo producto.
3. **Resultado esperado**: la sección "Inventario" ya no se muestra (refleja el plan
   vigente, no el estado cacheado al iniciar sesión — FR-004).
4. Revertir el plan a "con módulo" y repetir la apertura del formulario: la sección vuelve
   a aparecer con los datos intactos (FR-006).

## Verificación complementaria (no requiere UI)

- Revisar/actualizar `src/app/modules/products/pages/product-form.component.spec.ts` en
  `pos-heladeria`: los tests que hoy verifican el texto "Tu plan actual no incluye el
  módulo de inventario" y el interruptor deshabilitado deben pasar a verificar que la
  sección completa está **ausente del DOM** cuando `inventarioIncluido()` es falso, y
  presente y funcional cuando es verdadero — siguiendo el mismo patrón ya usado en
  `reports-page.component.spec.ts` (aparece/no aparece) referenciado en `research.md`.
- No se requiere verificación de backend/API: esta feature no modifica contratos ni
  endpoints (ver `plan.md`, sección de contratos).
