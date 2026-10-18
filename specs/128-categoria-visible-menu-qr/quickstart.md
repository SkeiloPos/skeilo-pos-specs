# Quickstart: Validar "Visibilidad de categorías en el menú QR"

## Prerrequisitos

- `pos-backend` corriendo localmente, con la migración de `visible_en_qr` aplicada.
- `pos-heladeria` corriendo localmente, con sesión de administrador y una de Cajero disponibles
  para probar el bloqueo de permisos.
- Un tenant de prueba con al menos una categoría activa con productos (p. ej. "Con licor") y
  una categoría inactiva (p. ej. "Helados").
- Un dispositivo (o pestaña) con el menú QR abierto vía token firmado, para los escenarios de
  comensal.

## Escenario 1 — Ocultar una categoría del menú QR (US1, FR-002/FR-003/FR-004)

1. Como administrador, en la pantalla de Categorías, accionar "Ocultar del menú QR" sobre "Con
   licor" (activa y visible).
2. **Esperado**: la fila muestra el indicador "Oculta en QR" de inmediato (sin recargar la
   página).
3. Recargar el menú QR del comensal (o abrir uno nuevo).
4. **Esperado**: "Con licor" y todos sus productos ya no aparecen, en ningún lugar del menú.
5. Desde caja o mesa, abrir "Nuevo pedido".
6. **Esperado**: "Con licor" y sus productos siguen disponibles exactamente igual que antes.

## Escenario 2 — Volver a mostrarla, en la misma posición (US1, FR-004)

1. Anotar la posición (Orden) de "Con licor" antes de ocultarla.
2. Ocultarla y luego accionar "Mostrar en menú QR".
3. Recargar el menú QR.
4. **Esperado**: "Con licor" reaparece exactamente en la misma posición relativa de antes.

## Escenario 3 — Buscador del menú QR (US1, FR-002)

1. Con "Con licor" oculta, abrir el menú QR y escribir en el buscador el nombre de un producto
   de esa categoría.
2. **Esperado**: no aparece entre los resultados.

## Escenario 4 — Categoría inactiva (US1, FR-006)

1. Con "Helados" inactiva, abrir la pantalla de Categorías como administrador.
2. **Esperado**: la acción de visibilidad en QR aparece deshabilitada para "Helados", con el
   texto de ayuda "Activa la categoría para controlar su visibilidad en QR".

## Escenario 5 — Usuario sin permiso (US1, FR-005)

1. Iniciar sesión como Cajero y abrir la pantalla de Categorías.
2. **Esperado**: no se ve ninguna acción de visibilidad en QR.
3. Llamar directamente `PATCH /categories/{id}` con `{"visible_en_qr": false}` usando las
   credenciales del Cajero.
4. **Esperado**: `403`. Confirmar aparte que ese mismo usuario SÍ puede seguir cambiando
   `name`/`display_order` de una categoría (la restricción es solo sobre `visible_en_qr`,
   research.md Decisión 3).

## Escenario 6 — Carrito con productos ya ocultos al enviar (US2, FR-007)

1. Como comensal, agregar al carrito un producto de "Con licor" (todavía visible).
2. Como administrador, ocultar "Con licor" del menú QR sin que el comensal recargue nada.
3. Como comensal, intentar enviar el pedido.
4. **Esperado**: el envío se rechaza, aparece el mensaje "Algunos productos ya no están
   disponibles y se quitaron de tu carrito", y al consultar el carrito ya no incluye ese
   producto.
5. Enviar de nuevo (sin ese producto, o vacío).
6. **Esperado**: procede con normalidad si el carrito tiene algo más que enviar.

## Escenario 7 — Pedidos QR ya enviados no se ven afectados (Edge case de `spec.md`)

1. Enviar un pedido QR que incluya un producto de "Con licor" mientras sigue visible.
2. Ocultar "Con licor" del menú QR.
3. Revisar ese pedido ya enviado (en cocina, en caja, en el historial del comensal).
4. **Esperado**: sin ningún cambio — el pedido y sus ítems se muestran exactamente igual que
   antes de ocultar la categoría.

## Escenario 8 (opcional, si se implementa US3/FR-009) — Menú QR ya abierto se actualiza solo

1. Abrir el menú QR en un dispositivo y dejarlo abierto, sin recargar.
2. Desde administración, ocultar (o volver a mostrar) una categoría que ese comensal está
   viendo.
3. **Esperado**: la categoría aparece/desaparece sola en la pantalla del comensal, sin que haya
   recargado.

## Verificación automatizada

- Backend: `cd ../pos-backend && ./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`
  debe seguir en verde — en particular los tests existentes de `test_menu_router.py`,
  `test_cart_service.py` (revalidación de agotados, spec 093, patrón de referencia para la
  revalidación nueva) y cualquier test de `categories/router.py` ya existente.
- Frontend: `cd ../pos-heladeria && npx ng test --watch=false --include='src/app/modules/categories/**/*.spec.ts'`
  y `--include='src/app/modules/tables/pages/public-menu.component.spec.ts'` (si existe) —
  confirmar en verde más los tests nuevos de esta spec.
- Diferenciar por archivo contra el baseline de fallas preexistentes ya documentado en la
  memoria del proyecto antes de asumir que algo se rompió.
