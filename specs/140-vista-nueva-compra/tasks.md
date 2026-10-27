---

description: "Task list template for feature implementation"
---

# Tasks: Vista dedicada para registrar una compra

**Input**: Design documents from `/specs/140-vista-nueva-compra/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/purchases-api.md, quickstart.md (all present)

**Tests**: No se solicitaron tests explícitamente en el spec; se incluyen tareas de verificación/characterization (Principio III/X) en lugar de TDD estricto, siguiendo el patrón ya usado en este repo (scripts manuales de backend, specs de Vitest en frontend).

**Repos involucrados**: `pos-backend` (FastAPI) y `pos-heladeria` (Angular), ambos actualmente en la rama `develop`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Puede ejecutarse en paralelo (archivo distinto, sin dependencias)
- **[Story]**: US1 (Registrar compra recibida), US2 (Crear orden de compra), US3 (Guardar borrador)

---

## Phase 1: Setup

- [X] T001 Crear la rama `feat/140-vista-nueva-compra` desde `develop` en `pos-backend` y en `pos-heladeria` (plan.md exige la rama creada antes de tocar código; ambos repos están hoy en `develop`).

**Checkpoint**: rama lista en ambos repos.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: vista enrutada con la composición visual del mockup (`design/SkeiloPOS App - Nueva compra.dc.html`, bloque `buyPage`) y toda la lógica compartida por las 3 historias (búsqueda, proveedor, líneas, totales). Ninguna acción de guardado se conecta todavía.

**⚠️ CRITICAL**: ninguna historia de usuario puede probarse de forma independiente hasta que este bloque esté completo.

- [X] T002 Agregar la ruta `inventario/compras/nueva` en `pos-heladeria/src/app/modules/dashboard/routes.ts`, junto a `inventario` (línea ~226), con las mismas guardias `canActivate: [roleGuard([UserRole.ADMIN]), planModuleGuard('inventario')]`, apuntando (lazy) al nuevo `PurchaseViewComponent`.
- [X] T003 Crear `pos-heladeria/src/app/modules/inventory/pages/purchase-view.component.ts` (standalone, `ChangeDetectionStrategy.OnPush`) con el esqueleto de la vista: botón "Volver al inventario" (navega a `inventario`), encabezado (`COMPRAS` + título + texto de ayuda, como `buyTitle`/`buyHelp` del mockup), panel contenedor, estado de error (`mErrOn`/`mErr`) y fila final de acciones con "Cancelar" (navega a `inventario` sin guardar, Edge Case de salir sin guardar). Inyectar `InventoryService`, `SuppliersService`, `UnitMeasureService`, `SupplierItemsService` y cargar sus catálogos en `ngOnInit` (portar de `purchase-form.component.ts:272-278`).
- [X] T004 [P] Actualizar `pos-heladeria/src/app/modules/inventory/pages/inventory-page.component.ts`: cambiar el botón "Nueva compra" (línea ~80) de `showPurchase.set(true)` a navegación con `Router` hacia `inventario/compras/nueva`; eliminar el signal `showPurchase`, el bloque `@if (showPurchase())`/`<app-purchase-form>` (líneas ~442-445) y el import de `PurchaseFormComponent`. No tocar el modal "Recibir compra" (líneas ~446-489).
- [X] T005 Implementar el buscador de insumos en `purchase-view.component.ts`: input de texto ligado a un signal `query`, debounce manual de 300ms con `setTimeout`/`clearTimeout` + guarda de secuencia (`searchSeq`) para descartar respuestas fuera de orden — mismo idiom que `searchable-select.component.ts` (líneas ~110-215) pero sin `ControlValueAccessor`: al resolver, llama a `InventoryService.searchActiveItems(query)` y renderiza un dropdown con código, nombre y unidad base de cada resultado (FR-003/FR-004), excluyendo insumos que ya están en `rows()`; click o Enter sobre el primer resultado agrega una línea nueva (FR-005); si no hay coincidencias muestra "Ningún insumo disponible coincide" (Edge Case); Escape limpia el input.
- [X] T006 Implementar el selector de proveedor en `purchase-view.component.ts`: opciones desde `SuppliersService.suppliers()` más "Sin proveedor" (compra ocasional, FR-006); al cambiar, para cada línea ya agregada, consultar `SupplierItemsService.listForItem(inventory_item_id, false)` filtrado client-side por el proveedor elegido (reutilizando el patrón de `purchase-form.component.ts:306-312, 326-336`, research.md D5) y, solo si hay relación activa coincidente, actualizar unidad de compra y costo sugerido; las líneas sin coincidencia conservan lo que ya tenían (FR-007, Edge Case).
- [X] T007 Implementar la tabla de líneas en `purchase-view.component.ts` con las columnas del mockup (CÓDIGO, NOMBRE con aviso de stock bajo, UNIDAD DE COMPRA, PRECIO, CANTIDAD, SUBTOTAL, ACCIÓN): selector combinado de unidad de compra (presentaciones del proveedor + conversiones genéricas del mismo grupo de medida, D6, portando `presentationsFor`/`unitsForRow`/`onPresentationChange`/`onUnitMeasureChange` de `purchase-form.component.ts:214-262,314-324`), precio editable (reusar `MoneyInputComponent`), cantidad con controles +/- y mínimo 1, subtotal calculado, y botón para quitar la línea.
- [X] T008 Implementar el resumen de totales (TOTAL DE LÍNEAS, TOTAL) como `computed()` en tiempo real a partir de `rows()` (FR-009), portando `total`/`canSubmit` de `purchase-form.component.ts:264-270`.
- [X] T009 Implementar el campo de número/referencia de factura: precargarlo con un valor generado automáticamente al abrir la vista (p. ej. secuencial u. basado en fecha/hora) y permitir que el usuario lo edite antes de guardar (FR-010).

**Checkpoint**: la vista `inventario/compras/nueva` reproduce la composición del mockup (SC-005) y permite armar líneas, elegir proveedor y ver totales, pero ningún botón de guardado está conectado todavía.

---

## Phase 3: User Story 1 - Registrar una compra ya recibida (Priority: P1) 🎯 MVP

**Goal**: completar la vista y presionar "Registrar compra" sube el stock de inmediato (flujo que hoy existe como modal).

**Independent Test**: desde Inventario, entrar a la vista, buscar y agregar 5 insumos, elegir proveedor, completar cantidades y precios, presionar "Registrar compra"; verificar stock actualizado y mensaje de éxito (quickstart.md Escenario 1).

- [X] T010 [US1] Conectar el botón "Registrar compra" en `purchase-view.component.ts`: valida que exista ≥1 línea con insumo y cantidad > 0 (FR-012, mostrando mensaje si no se cumple), mapea `rows()` al `PurchaseForm` existente (misma lógica de `purchase-form.component.ts:338-363`) y llama a `InventoryService.createPurchase(form)` (endpoint sin cambios).
- [X] T011 [US1] Deshabilitar el botón mientras `service.isSubmitting()` sea verdadero (reutilizar el signal existente) para que un doble clic o reenvío tras error no dupare el movimiento de stock (FR-015, SC-003); al terminar con éxito, mostrar mensaje de éxito acorde ("Registrar compra") y navegar de vuelta a `inventario` (FR-016).
- [X] T012 [US1] Manejar el error de guardado: si `service.error()` queda con valor tras el intento, mostrarlo en la vista sin navegar fuera y conservando los datos capturados (Edge Case "pérdida de conexión").
- [X] T013 [US1] [P] Crear `pos-heladeria/src/app/modules/inventory/pages/purchase-view.component.spec.ts` y portar/adaptar los casos relevantes de `purchase-form.component.spec.ts` (búsqueda server-side, íconos sin SVG artesanal) más casos nuevos: insumo ya agregado no vuelve a aparecer en resultados, "Registrar compra" exitoso navega a `inventario` y deja `isSubmitting()` en `false`, reintento tras error no duplica la llamada HTTP.
- [X] T014 [US1] Una vez verificada la paridad funcional, eliminar `pos-heladeria/src/app/modules/inventory/components/purchase-form.component.ts` y `purchase-form.component.spec.ts` (confirmar primero con `grep -r PurchaseFormComponent` que no queda ninguna referencia).

**Checkpoint**: User Story 1 funcional y verificable de forma independiente (SC-001, SC-002, SC-003).

---

## Phase 4: User Story 2 - Crear una orden de compra pendiente (Priority: P2)

**Goal**: la misma vista permite "Crear orden de compra" sin subir stock, usando el mecanismo `status='draft'` ya existente.

**Independent Test**: completar proveedor y ≥1 línea válida, presionar "Crear orden de compra"; verificar que el stock no cambia y la orden aparece como pendiente en el listado de Compras (quickstart.md Escenario 2).

- [X] T015 [US2] Conectar el botón "Crear orden de compra" en `purchase-view.component.ts`: misma validación que "Registrar compra" (FR-012), llama a `InventoryService.createPurchaseOrder(form)` (endpoint `POST /purchases/order` sin cambios para este flujo, `allow_incomplete` ausente/`false`), muestra mensaje de éxito distinto ("Crear orden de compra") y navega a `inventario` (FR-016).
- [X] T016 [US2] Bloquear la acción con mensaje de validación cuando no hay ninguna línea válida (Acceptance Scenario 2 de US2) sin llegar a llamar al backend.
- [X] T017 [US2] [P] Confirmar (sin cambios de código salvo que la prueba revele una regresión) que `purchaseLabel()`/`purchaseChip()` en `inventory-page.component.ts` (líneas ~662-671) siguen mostrando "Orden" para compras `status='draft'` creadas desde la nueva vista.
- [X] T018 [US2] [P] Agregar casos en `purchase-view.component.spec.ts` para "Crear orden de compra": el request a `POST /purchases/order` no incluye alta de stock, y el intento sin líneas válidas no dispara ninguna llamada HTTP y muestra el mensaje de validación.

**Checkpoint**: User Story 1 y 2 funcionan de forma independiente (SC-004 para US2).

---

## Phase 5: User Story 3 - Guardar un borrador incompleto para continuar después (Priority: P3)

**Goal**: "Guardar borrador" persiste una captura incompleta sin subir stock y permite reabrirla luego; requiere la única extensión de backend de esta feature (`purchases.is_incomplete`).

**Independent Test**: con datos parciales (p. ej. línea sin costo), presionar "Guardar borrador"; verificar que se guarda sin exigir líneas completas, el stock no cambia, y al volver a Compras se puede identificar y reabrir el borrador (quickstart.md Escenario 3).

### Backend (aditivo, `POST /purchases/order` modificado — contracts/purchases-api.md)

- [X] T019 [US3] Crear migración Alembic en `pos-backend/alembic/versions/` que agregue `purchases.is_incomplete BOOLEAN NOT NULL DEFAULT false` en cada esquema de tenant, siguiendo el patrón `@for_each_tenant_schema` de `alembic/versions/b8c9d0e1f2a3_option_group_active.py` (incluir `_has_table` guard y `downgrade` con `drop_column`).
- [X] T020 [US3] Agregar la columna `is_incomplete: Mapped[bool]` (`default=False, server_default="false"`) al modelo `Purchase` en `pos-backend/app/models/purchase.py`, documentando en un comentario breve que solo es válida junto a `status='draft'` (data-model.md).
- [X] T021 [US3] [P] En `pos-backend/app/api/v1/inventory/schemas.py`: introducir `PurchaseOrderItemIn` (como `PurchaseItemIn` pero con `quantity`/`unit_cost`/`unit_measure_id` todos opcionales cuando el padre tenga `allow_incomplete=True`) y `PurchaseOrderCreate` (como `PurchaseCreate` pero `items: list[PurchaseOrderItemIn] = Field(default_factory=list)` y nuevo campo `allow_incomplete: bool = False`), con un `model_validator(mode="after")` que, solo cuando `allow_incomplete` sea `False`, reaplique la validación actual (≥1 línea, y por línea la misma regla de "exactamente un modo" de `PurchaseItemIn._exactly_one_mode`); agregar `is_incomplete: bool` a `PurchaseResponse`.
- [X] T022 [US3] Extender `create_purchase_order(db, data, user_id, tenant)` en `pos-backend/app/api/v1/inventory/service.py` para aceptar el `PurchaseOrderCreate` de T021: cuando `data.allow_incomplete` sea `True`, omitir la validación de "≥1 línea con cantidad > 0" y aceptar líneas sin `quantity`/`unit_cost`/`unit_measure_id`; persistir `purchase.is_incomplete = data.allow_incomplete` antes del `commit`.
- [X] T023 [US3] Actualizar el endpoint `POST /purchases/order` en `pos-backend/app/api/v1/inventory/router.py` (línea ~489) para tipar `body: PurchaseOrderCreate` en lugar de `PurchaseCreate` (sin cambios de path ni de los demás endpoints).
- [X] T024 [US3] [P] Crear `pos-backend/app/scripts/test_purchase_draft_incomplete.py` (mismo patrón autoejecutable que `test_purchase_unit_conversion.py`: fixture propia, limpieza al final) que verifique: `allow_incomplete=true` con una línea sin `unit_cost`/sin líneas en absoluto persiste `status='draft', is_incomplete=true` sin alta de stock; `allow_incomplete=false` (u omitido) conserva el comportamiento actual de "orden de compra pendiente" (`is_incomplete=false`) y sigue exigiendo ≥1 línea válida.

### Frontend

- [X] T025 [US3] [P] En `pos-heladeria/src/app/modules/inventory/interfaces/inventory.interface.ts`: agregar `isIncomplete: boolean` a `Purchase` y `allow_incomplete?: boolean` a `PurchaseCreatePayload`; en `inventory.service.ts`, mapear `is_incomplete` → `isIncomplete` en `toPurchase()`.
- [X] T026 [US3] Agregar `saveDraft(form: PurchaseForm): Promise<boolean>` en `InventoryService` (`pos-heladeria/src/app/modules/inventory/services/inventory.service.ts`), reutilizando `postPurchase` hacia `${this.baseUrl}/purchases/order` con `allow_incomplete: true` agregado al payload y sin forzar `quantity`/`unit_cost` a `0` cuando la línea no los tiene (enviar `undefined` en ese caso, a diferencia de `createPurchase`/`createPurchaseOrder`).
- [X] T027 [US3] Conectar el botón "Guardar borrador" en `purchase-view.component.ts`: sin las validaciones de FR-012, llama a `saveDraft(form)`, muestra un mensaje de confirmación distinto a los otros dos ("Guardar borrador") y, a diferencia de FR-016 para las otras dos acciones, permanece en la vista en vez de navegar a Inventario.
- [X] T028 [US3] Actualizar `purchaseLabel()`/`purchaseChip()` en `inventory-page.component.ts` (líneas ~662-671) para distinguir, cuando `status === 'draft'`: `isIncomplete === true` → "Borrador" (con su propio estilo de chip), `isIncomplete === false` → "Orden" (comportamiento actual, sin cambios).
- [X] T029 [US3] Hacer que las filas "Borrador" de la pestaña Compras en `inventory-page.component.ts` naveguen a `inventario/compras/nueva` pasando la `Purchase` completa (ya incluye `items`, cargados por `GET /purchases`, sin necesitar un endpoint de detalle nuevo — contracts/purchases-api.md) vía estado de navegación de Angular Router; `purchase-view.component.ts` debe leer ese estado en `ngOnInit` y precargar proveedor, número de factura y líneas (FR-017).
- [X] T030 [US3] [P] Agregar casos en `purchase-view.component.spec.ts` para "Guardar borrador": una línea sin costo se guarda igual (payload sin exigir `unit_cost`), el stock no se toca, la vista no navega tras guardar, y al reabrir un borrador pasado por estado de navegación los campos quedan precargados.

**Checkpoint**: las 3 historias de usuario funcionan de forma independiente (SC-004 completo).

---

## Phase 6: Polish & Cross-Cutting Concerns

- [ ] T031 [P] Ejecutar manualmente los 4 escenarios de `quickstart.md` (incluyendo Edge cases: búsqueda sin coincidencias, cambio de proveedor sin relación, pérdida de conexión, cancelar sin guardar) contra backend + frontend locales; confirmar SC-001 a SC-005.
- [X] T032 [P] Ejecutar `python -m app.scripts.test_purchase_presentation` y `python -m app.scripts.test_purchase_unit_conversion` en `pos-backend` para confirmar que no hay regresión por los cambios de T019-T023 (Principio III).
- [X] T033 [P] Ejecutar `ng test` sobre `purchase-view.component.spec.ts` e `inventory-page.component.spec.ts` en `pos-heladeria`; corregir cualquier regresión.
- [X] T034 Limpieza final en `inventory-page.component.ts` y módulos relacionados: confirmar que no quedan imports, signals (`showPurchase`) ni referencias muertas de la migración modal → vista.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias.
- **Foundational (Phase 2)**: depende de Setup; BLOQUEA las 3 historias de usuario (T002-T009 construyen el mismo archivo `purchase-view.component.ts` secuencialmente).
- **User Story 1 (Phase 3)**: depende de Foundational; sin dependencia de US2/US3.
- **User Story 2 (Phase 4)**: depende de Foundational; independiente de US1/US3 (reutiliza el mismo endpoint sin cambios).
- **User Story 3 (Phase 5)**: depende de Foundational; su bloque de backend (T019-T024) es independiente de frontend hasta T026 (que necesita el campo `allow_incomplete` del request ya soportado por el backend).
- **Polish (Phase 6)**: depende de que las historias que se vayan a entregar estén completas.

### Dentro de cada historia

- US1: validación/guardado (T010) antes de no-duplicación (T011) y manejo de error (T012); tests (T013) después de implementar; borrado del componente viejo (T014) al final, una vez verificada la paridad.
- US2: igual patrón (T015 → T016), T017/T018 en paralelo al final.
- US3 backend: migración (T019) → modelo (T020) → schemas (T021) → service (T022) → router (T023); T024 (script) en paralelo una vez T022/T023 existen. US3 frontend: interfaces (T025) → servicio (T026) → UI del botón (T027) → listado (T028) → reapertura (T029); T030 al final.

### Parallel Opportunities

- T004 (inventory-page.component.ts) es paralelo a T003 (archivo nuevo) dentro de Foundational.
- Dentro de US3 backend, T021 y T024 pueden solaparse con trabajo en otros archivos una vez sus dependencias directas existen.
- T017/T018 (US2), T025 (US3 frontend), T030, T031-T033 son paralelizables entre sí (archivos/comandos distintos).

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1: Setup (rama).
2. Phase 2: Foundational (vista completa sin botones de guardado conectados).
3. Phase 3: User Story 1 (Registrar compra).
4. Validar independientemente (SC-001/SC-002/SC-003) antes de continuar.

### Incremental Delivery

1. Setup + Foundational → vista navegable, sin guardar.
2. + User Story 1 → MVP: reemplaza el modal para el flujo de compra directa.
3. + User Story 2 → agrega "Crear orden de compra" sin tocar backend.
4. + User Story 3 → única pieza de backend (columna + endpoint aditivo) y "Guardar borrador".
5. Polish → verificación cruzada backend/frontend y limpieza.
