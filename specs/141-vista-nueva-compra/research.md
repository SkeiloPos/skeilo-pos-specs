# Research: Vista dedicada para registrar una compra

## D1. Reemplazo del modal por vista enrutada

- **Decision**: Convertir `purchase-form.component.ts` (hoy un overlay condicional
  renderizado con `@if (showPurchase())` desde `inventory-page.component.ts`) en una página
  enrutada nueva (`purchase-view.component.ts`) accesible en `inventario/compras/nueva`,
  registrada en `pos-heladeria/src/app/modules/dashboard/routes.ts` junto a las rutas
  `inventario` (línea 226) e `inventario/:id/detalle` (línea 218), con las mismas guardias
  (`roleGuard([UserRole.ADMIN])`, `planModuleGuard('inventario')`).
- **Rationale**: FR-001 exige navegación propia ("Volver al inventario") en vez de overlay;
  reutilizar el componente existente (en vez de reescribirlo) preserva la lógica ya probada
  de búsqueda, selección de proveedor y cálculo de totales (Principio V: sin refactor
  oportunista).
- **Alternatives considered**: Mantener el modal y solo cambiar la URL con un modal-as-route
  (parallel route/overlay) — rechazado porque el mockup y el spec piden explícitamente que
  dejar de ser una ventana emergente, no solo que tenga URL.

## D2. Origen del botón "Nueva compra" en Inventario

- **Decision**: El botón en `inventory-page.component.ts` que hoy hace
  `showPurchase.set(true)` pasa a navegar con el `Router` a `inventario/compras/nueva`.
- **Rationale**: Consistente con FR-001; el modal de "Recibir compra" (líneas 447-489 del
  mismo archivo, RF-022) queda fuera de alcance (Assumption: solo se migra la creación, no
  la recepción) y se mantiene como está.

## D3. Mecanismo de "Guardar borrador" (FR-011, FR-013, FR-017)

- **Decision**: El estado `draft` de `Purchase` (`status IN ('draft','partial','received')`,
  `app/models/purchase.py`) ya existe pero hoy representa únicamente "orden de compra
  pendiente, validada" (RF-022/User Story 2). Para "Guardar borrador" (User Story 3, captura
  incompleta) se añade una columna aditiva `is_incomplete` (booleano, `default=false`,
  `NOT NULL`) a `purchases`. Combinaciones:
  - `status='draft', is_incomplete=false` → orden de compra pendiente (comportamiento
    actual, sin cambios).
  - `status='draft', is_incomplete=true` → borrador incompleto nuevo (FR-017): no sube
    stock, no exige líneas completas, identificable y reabrible.
  - El endpoint `POST /purchases/order` recibe un nuevo campo opcional
    `allow_incomplete: bool = False` en su schema de entrada; cuando es `true`, el servicio
    `create_purchase_order` omite la validación de "al menos una línea con cantidad > 0"
    (FR-013) y persiste `is_incomplete=true`. El endpoint `POST /purchases` (compra
    recibida) no cambia.
- **Rationale**: Reutiliza el mecanismo de "sin alta de stock" ya existente sin introducir
  un tercer estado al enum (`status`), lo que evitaría tocar todo el código que ya razona en
  términos de `status in ('draft','partial')` en recepción/anulación (Principio VI: cambio
  mínimo y aislado). El `default=false` preserva el significado histórico de cualquier
  compra con `status='draft'` ya persistida (Principio VII/VIII).
- **Alternatives considered**:
  - Añadir un cuarto valor al `CHECK ck_purchase_status` (ej. `'incomplete'`) — rechazado
    por ampliar innecesariamente el radio de cambio: todo el código que filtra por
    `status='draft'` para "pendiente de recepción" tendría que revisarse para decidir si
    también incluye `'incomplete'`.
  - Inferir "incompleto" dinámicamente revisando si falta proveedor/cantidad/costo en las
    líneas — rechazado porque FR-017 exige que el borrador sea "identificable" de forma
    confiable en un listado, y la inferencia dinámica es frágil ante futuros cambios de
    reglas de validación.
  - Guardar el borrador solo en el frontend (localStorage) — rechazado porque el spec pide
    que se pueda "reabrir y continuar" (FR-017), lo cual implica persistencia en servidor
    compartida entre sesiones/dispositivos, no solo del navegador actual.

## D4. Verificación/testing de backend

- **Finding**: No se encontró una suite `pytest` dedicada a los endpoints de compra; existen
  scripts de verificación manual (`app/scripts/test_purchase_presentation.py`,
  `app/scripts/test_purchase_unit_conversion.py`), no ejecutados por un runner de tests
  automatizado.
- **Decision**: Antes de implementar el cambio de backend (D3), confirmar con el usuario el
  mecanismo de verificación esperado (¿pytest nuevo, o seguir el patrón de script manual
  existente?) — ver memoria de sesión sobre cómo correr tests del repo hermano. Esta
  pregunta se resuelve en la fase de implementación, no bloquea el diseño de Phase 1.
- **Rationale**: Principio X exige verificación obligatoria; no se puede asumir el mecanismo
  sin confirmarlo, pero tampoco bloquea la generación de `data-model.md`/`contracts/`.

## D5. Prefetch de unidad de compra y costo por proveedor (FR-007)

- **Decision**: Reutilizar `SupplierItemsService.listForItem()` (ya usado por el modal
  actual) filtrando client-side por el proveedor elegido, igual que hoy. No se crea ningún
  endpoint nuevo.
- **Rationale**: FR-014 exige no duplicar lógica de negocio ya existente; el mecanismo actual
  ya resuelve "presentación preferida + último costo" (specs 106/107 previos).

## D6. Selector combinado de unidad de compra (Assumption del spec)

- **Decision**: Tal como señala la sección "Assumptions" del spec, el selector combinado
  (presentaciones de proveedor + conversiones genéricas en un único control) es un cambio de
  presentación visual sobre los datos que ya expone `UnitMeasureService` +
  `SupplierItemsService`; no se requiere un endpoint que ya devuelva ambos combinados.
- **Rationale**: Evita tratar un cambio de UI como si fuera un cambio de modelo de datos
  (Principio XI: distinguir decisión técnica de decisión de negocio).

## Resumen de NEEDS CLARIFICATION resueltos

No quedan `NEEDS CLARIFICATION` abiertos para Phase 1. El único punto pendiente de
confirmación operativa (mecanismo exacto de tests de backend, D4) no bloquea el diseño: se
resuelve durante `/speckit-tasks` o al inicio de la implementación.
