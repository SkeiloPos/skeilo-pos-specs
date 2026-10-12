# Quickstart: Validar la pestaña "Promociones" en el catálogo de la orden manual

Esta guía valida manualmente, en la aplicación real, los escenarios de aceptación del spec (`spec.md`). El código vive en el repo hermano `../pos-heladeria`.

## Prerrequisitos

- Repo `pos-heladeria` en la rama de este feature, con los cambios de `tasks.md` ya implementados.
- Backend (`../pos-backend`) corriendo y accesible, con un tenant que tenga:
  - Al menos una promoción **vigente** (dentro de su vigencia de fecha/horario/días, `status: active`) con una regla de precio de paquete y `min_qty = 2` sobre un producto con una sola variante (p. ej. "2 x $17.000").
  - Al menos un producto **sin** ninguna promoción vigente, para confirmar que no aparece en la pestaña nueva.
  - Idealmente, un segundo producto en promoción en una categoría distinta al primero, para confirmar que la pestaña junta productos de categorías distintas (FR-002).
- Un turno de caja abierto para poder operar la Terminal de Mesas / crear un pedido manual.

## Puesta en marcha

```bash
cd ../pos-heladeria
npm install   # si es la primera vez
npx ng serve
```

Abrir "Crear pedido manual" (o la Terminal de Mesas → Nueva orden) en el navegador, autenticado como cajero/mesero.

## Escenario 1 — Encontrar los productos en promoción sin revisar categoría por categoría (User Story 1)

1. Con el catálogo recién cargado (sin tocar nada), observar qué pestaña está activa.
2. **Resultado esperado (FR-013)**: la pestaña "Todos" (o la categoría que ya estuviera activa) sigue seleccionada por defecto — la pestaña "Promociones" NO se autoselecciona aunque haya promociones vigentes.
3. Seleccionar la nueva pestaña "Promociones" en la navegación del catálogo.
4. **Resultado esperado (FR-001/FR-002)**: la grilla muestra únicamente los productos con al menos una promoción vigente, sin importar su categoría original; los productos sin promoción no aparecen.
5. Revisar una de las tarjetas listadas.
6. **Resultado esperado (FR-003)**: la tarjeta muestra la misma insignia/condición de promoción (tipo de descuento y cantidad mínima) que se ve hoy en su categoría original.

## Escenario 2 — Sin promociones vigentes (Acceptance Scenario 3, FR-012)

1. Desactivar temporalmente (o esperar a que venza) la única promoción vigente del tenant de prueba.
2. Seleccionar la pestaña "Promociones".
3. **Resultado esperado**: la pestaña sigue visible en la navegación; la grilla muestra un mensaje explícito de que no hay promociones activas en este momento, nunca una grilla vacía sin explicación.

## Escenario 3 — Agregar con la cantidad mínima, luego ajustar libremente (User Story 2, FR-004/FR-005/FR-006, A-126)

1. Con la promoción "2 x $17.000" (`min_qty = 2`) vigente, ir a la pestaña "Promociones" y agregar ese producto al pedido por primera vez.
2. **Resultado esperado**: la línea del pedido queda con cantidad **2**, no 1 (FR-004, sin cambio).
3. Sobre esa misma línea (en el panel del pedido en curso), presionar el control "+" una vez.
4. **Resultado esperado (A-126)**: la cantidad pasa a **3** (una unidad más) — el control de la línea ya agregada avanza siempre de 1 en 1, sin importar la promoción, a diferencia del menú QR.
5. Presionar el control "−" dos veces, hasta volver a 1.
6. **Resultado esperado**: la cantidad baja a **2** y luego a **1** — nunca salta a 0 ni se retira por tener una cantidad que ya no completa el paquete; esa unidad simplemente no calificará para el precio de paquete al cobrar.
7. Presionar "−" una vez más, estando en 1.
8. **Resultado esperado**: recién ahí la línea se retira por completo del pedido (al llegar a 0), igual que cualquier otra línea.

## Escenario 4 — Regla con cantidad mínima 1 (Acceptance Scenario 5 de User Story 2)

1. Con una promoción vigente de `min_qty = 1` (por ejemplo, un descuento por porcentaje simple) sobre otro producto, agregarlo desde la pestaña "Promociones".
2. **Resultado esperado**: se agrega una unidad a la vez, igual que el comportamiento normal — sin pasos de a 2 ni ajustes especiales.

## Escenario 5 — Las categorías normales y el buscador no cambian (User Story 3 + Clarifications, FR-007/FR-008)

1. Sin pasar por "Promociones", navegar hasta la categoría original del producto "2 x $17.000" (o usar el buscador del catálogo para encontrarlo por nombre) y agregarlo al pedido desde ahí.
2. **Resultado esperado**: se agrega **una unidad**, no dos — el paso forzado de FR-004 no aplica fuera de la pestaña "Promociones", ni siquiera cuando se encuentra el mismo producto con el buscador.

## Escenario 6 — Ajuste al múltiplo más cercano (Edge Case, FR-010)

1. Agregar el producto "2 x $17.000" desde su categoría normal con cantidad **1** (comportamiento libre).
2. Ir a la pestaña "Promociones", abrir la tarjeta de ese mismo producto y confirmar la selección sin cambiar nada.
3. **Resultado esperado**: la cantidad configurada en el modal arranca ya ajustada hacia arriba al múltiplo de 2 más cercano (es decir, parte de 2, no de 1), antes de que el cajero siga incrementando/decrementando en pasos de 2.

## Escenario 7 — Agregar a un pedido ya existente, mesa/llevar/domicilio (Edge Case, FR-014)

Este es el catálogo "+ Agregar producto" (`pos-catalog-drawer.component.ts`, embebido en el panel de un pedido ya creado) — una pantalla distinta a la de "Crear pedido manual" de los Escenarios 1-6, que también debe tener la pestaña "Promociones".

1. Crear y confirmar un pedido de **mesa** (de forma que quede ya creado/enviado, no en borrador).
2. Abrir esa mesa y usar "+ Agregar producto", entrando a la pestaña "Promociones" del catálogo que se abre ahí.
3. **Resultado esperado**: se cumplen las mismas reglas de los Escenarios 1 y 3 (filtro y paso de cantidad), igual que en el catálogo de "Crear pedido manual".
4. Repetir los pasos 1-3 para un pedido **para llevar** ya creado.
5. Repetir los pasos 1-3 para un pedido a **domicilio** ya creado.
6. **Resultado esperado**: el comportamiento es idéntico en los tres tipos de pedido — "+ Agregar producto" no distingue mesa/llevar/domicilio para este filtro ni para el paso de cantidad.

## Escenario 8 — Carrito mixto (promoción + producto normal), total correcto al guardar (pregunta de negocio)

1. En un pedido (de cualquier tipo: mesa, para llevar o domicilio), agregar desde "Promociones" el producto "2 x $17.000" (queda en cantidad 2 con descuento) **y**, en la misma orden, agregar un segundo producto sin ninguna promoción vigente, a precio normal.
2. Guardar/confirmar el pedido (o, si ya existe, cobrarlo).
3. **Resultado esperado**: el total refleja el descuento únicamente sobre las unidades del producto en promoción (el paquete de 2), y el precio de lista completo sobre el producto normal — el cálculo lo resuelve el backend igual que hoy (motor de descuento ya existente, sin cambios de esta spec), sin importar el tipo de pedido.

## Verificación automatizada (complemento, no sustituto de lo anterior)

```bash
cd ../pos-heladeria
npx ng test --watch=false --include='src/app/modules/promotions/services/promotion-pricing.util.spec.ts'
npx ng test --watch=false --include='src/app/modules/tables/services/pos-terminal.store.spec.ts'
npx ng test --watch=false --include='src/app/modules/tables/pages/manual-order-page.component.spec.ts'
npx ng test --watch=false --include='src/app/modules/tables/components/pos-catalog-drawer.component.spec.ts'
npx ng test --watch=false --include='src/app/modules/tables/pages/public-menu.component.spec.ts'
```

Comparar cualquier falla en `public-menu.component.spec.ts` (afectado solo por el cambio de ubicación de `hasPromotion()`, sin cambio de comportamiento esperado) contra la baseline conocida de fallas preexistentes de `pos-heladeria` antes de atribuirla a este cambio (ver `research.md`, Decisión 7).
