# Quickstart: Validar que la presentación se muestra en la línea del ítem

Esta guía valida manualmente, en la aplicación real, los escenarios de aceptación del spec (`spec.md`). El código vive en el repo hermano `../pos-heladeria`.

## Prerrequisitos

- Repo `pos-heladeria` en la rama de este feature, con los cambios de `tasks.md` ya implementados.
- Backend (`../pos-backend`) corriendo y accesible, con un tenant que tenga al menos un producto con más de una presentación configurada (p. ej. un granizado con 8 oz / 12 oz / 16 oz, como el usado en el reporte original) y al menos un producto sin presentaciones (producto simple).
- Un turno de caja abierto para poder operar la Terminal de Mesas.

## Puesta en marcha

```bash
cd ../pos-heladeria
npm install   # si es la primera vez
npx ng serve
```

Abrir la Terminal de Mesas en el navegador y autenticarse como cajero/mesero.

## Escenario 1 — Presentación visible al agregar a una orden nueva (Acceptance Scenario 1)

1. Ir a "Terminal de Mesas" → crear una orden nueva (mesa, para llevar o domicilio).
2. Buscar un producto con presentaciones obligatorias (p. ej. un granizado) y agregarlo, eligiendo una presentación intermedia (p. ej. "12 oz").
3. **Resultado esperado**: en el panel "Nueva orden", la línea del ítem muestra el nombre del producto junto con un pill/etiqueta con el texto "12 oz" (o el nombre de la presentación elegida), además de cantidad y costo correctos.

## Escenario 2 — Edición de presentación (Acceptance Scenario 2)

1. Sobre el ítem agregado en el Escenario 1, usar el ícono de edición (lápiz) para cambiar la presentación a otra opción (p. ej. "16 oz").
2. **Resultado esperado**: la línea del ítem actualiza tanto el costo como el texto de presentación mostrado, reflejando "16 oz".

## Escenario 3 — Producto sin presentaciones (Acceptance Scenario 3)

1. Agregar al carrito un producto que no tenga presentaciones configuradas (producto simple, una sola opción).
2. **Resultado esperado**: la línea del ítem se ve igual que antes del fix — sin ningún pill ni texto de presentación, sin espacios vacíos ni etiquetas rotas.

## Escenario 4 — Mismo producto, presentaciones distintas (Acceptance Scenario 4)

1. Agregar el mismo producto con presentación "8 oz".
2. Agregar nuevamente el mismo producto, esta vez con presentación "12 oz".
3. **Resultado esperado**: aparecen dos líneas de ítem independientes, cada una mostrando su propia presentación ("8 oz" y "12 oz" respectivamente), no una sola línea combinada.

## Escenario 5 — Agregar producto a una orden ya creada (Acceptance Scenario 5 / FR-007)

1. Crear y confirmar una orden de mesa (de forma que quede ya creada/enviada, no en borrador).
2. Abrir esa mesa desde "Terminal de Mesas" y usar "+ Agregar producto" para añadir un nuevo producto con presentación.
3. **Resultado esperado**: en el panel de la orden ya creada (`pos-order-panel`), la línea del nuevo ítem muestra el pill de presentación igual que en el carrito de una orden nueva, incluso antes de guardar/enviar ese nuevo ítem.

## Verificación automatizada (complemento, no sustituto de lo anterior)

```bash
cd ../pos-heladeria
npx ng test --watch=false --include='src/app/modules/tables/services/pos-terminal.store.spec.ts'
npx ng test --watch=false --include='src/app/modules/tables/pages/manual-order-page.component.spec.ts'
npx ng test --watch=false --include='src/app/modules/tables/components/pos-order-panel.component.spec.ts'
```

Comparar cualquier falla en `pos-order-panel.component.spec.ts` contra la baseline conocida de fallas preexistentes antes de atribuirla a este cambio (ver `research.md`, Decisión 4).
