---

description: "Task list for Compra Sugerida de Insumos"
---

# Tasks: Compra Sugerida de Insumos

**Input**: Design documents from `/specs/158-compra-sugerida/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/suggested-purchases-api.md, quickstart.md

**Tests**: no explicitamente pedidas como TDD, pero el plan.md y la Constitución del
proyecto exigen characterization tests de backend para toda funcionalidad nueva de
compras; se incluyen como parte de la implementación de cada historia (Principio III).

**Organization**: tareas agrupadas por historia de usuario (spec.md) para permitir
implementación y prueba independiente de cada una.

**Repos**: `../pos-backend` (FastAPI) y `../pos-heladeria` (Angular), hermanos de este repo
de specs.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: se puede ejecutar en paralelo (archivos distintos, sin dependencias)
- **[Story]**: US1 / US2 / US3

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: nueva tabla de idempotencia y modelo asociado, base para ambas historias P1.

- [X] T001 Crear modelo `PurchaseGenerationRequest` en `../pos-backend/app/models/purchase_generation_request.py` (UUID PK vía `UUIDPrimaryKeyMixin`, `idempotency_key: String(100) NOT NULL`, `purchase_ids: ARRAY(UUID)` o `JSONB NOT NULL`, `created_at: DateTime server_default=now()`, esquema `tenant`), registrándolo en `../pos-backend/app/models/__init__.py` si el proyecto centraliza imports de modelos ahí (seguir el patrón de `../pos-backend/app/models/purchase.py`)
- [X] T002 Generar migración Alembic en `../pos-backend/alembic/versions/<rev>_add_purchase_generation_requests.py` con `upgrade()` creando `tenant.purchase_generation_requests` + índice único `ux__purchase_generation_requests__idempotency_key` sobre `idempotency_key`, y `downgrade()` con `DROP TABLE tenant.purchase_generation_requests` (data-model.md: estrategia de migración/rollback)
- [X] T003 Aplicar la migración localmente: `cd ../pos-backend && ./env/bin/python -m alembic upgrade head` y verificar `\d tenant.purchase_generation_requests` en psql (ver memoria del proyecto sobre Postgres local disponible)

**Checkpoint**: tabla de idempotencia lista; ninguna historia de usuario depende de más infraestructura compartida.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: DTOs Pydantic y el refactor interno de `service.py` que ambas historias de backend necesitan (research.md D5). Nada de esta fase es específico de una sola historia.

**⚠️ CRITICAL**: ninguna tarea de US1/US2/US3 en backend puede empezar hasta terminar esta fase.

- [X] T004 [P] Agregar DTOs de lectura en `../pos-backend/app/api/v1/inventory/schemas.py`: `SuggestedPurchaseLineResponse` (campos de data-model.md: `inventory_item_id`, `code`, `name`, `current_stock`, `min_stock`, `deficit`, `base_unit_abbreviation`, `supplier_item_id`, `supplier_id`, `supplier_name`, `purchase_unit_label`, `conversion_factor`, `unit_price`, `suggested_quantity`, `is_preselected`, `missing_supplier_reason`), siguiendo el estilo de `LowStockResponse` ya existente en el mismo archivo
- [X] T005 [P] Agregar DTOs de escritura en `../pos-backend/app/api/v1/inventory/schemas.py`: `SuggestedPurchaseLineIn` (`inventory_item_id: UUID`, `supplier_item_id: UUID`, `presentation_quantity: Decimal = Field(ge=1)`, `presentation_unit_cost: Decimal = Field(gt=0)`), `GenerateSuggestedPurchasesRequest` (`idempotency_key: str`, `lines: list[SuggestedPurchaseLineIn] = Field(min_length=1)`), `GenerateSuggestedPurchasesResponse` (`purchases: list[PurchaseResponse]`)
- [X] T006 En `../pos-backend/app/api/v1/inventory/service.py`, extraer de `create_purchase_order()` (línea ~414) una variante interna no-commiteadora (p. ej. `_build_purchase_order(db, ..., update_supplier_cost: bool = True) -> Purchase`) que construye `Purchase`+`PurchaseItem[]` en `draft` sin llamar `db.commit()`; `create_purchase_order()` pasa a llamar a esta variante con `update_supplier_cost=True` y hace el commit (comportamiento idéntico, cero cambios observables)
- [X] T007 En `../pos-backend/app/api/v1/inventory/service.py`, modificar `_resolve_purchase_line()` (línea ~160) para aceptar un parámetro `update_supplier_cost: bool = True` que controla si se invoca `supplier_items.apply_purchase_cost()`; propagar el flag desde la variante de T006; verificar que `create_purchase`/`create_purchase_order` siguen usando el default `True`
- [X] T008 Ejecutar characterization tests existentes de compras para confirmar cero regresión tras T006/T007: `cd ../pos-backend && ./env/bin/python -m unittest app.characterization_tests.test_purchase -v` (o el nombre real del archivo de characterization tests de `create_purchase`/`create_purchase_order`; localizarlo con `grep -rl "CONGELA comportamiento actual" app/characterization_tests`)
- [X] T009 [P] Agregar en `../pos-backend/app/api/v1/inventory/supplier_items.py` una función de precarga para el listado sugerido (p. ej. `suggested_purchase_relations_by_item`) que extienda `preferred_relations_by_item()` (línea ~362) con `unit_measure_id`/abreviatura de unidad necesarios para el selector (FR-002/FR-004), reusando esa función en vez de duplicar su query

**Checkpoint**: DTOs y refactor de servicio listos; el endpoint de lectura (US1) y el de escritura (US2) pueden implementarse en paralelo.

---

## Phase 3: User Story 1 - Ver el sugerido de insumos bajo mínimo (Priority: P1) 🎯 MVP

**Goal**: pantalla que lista, paginada y ordenada por déficit descendente, todos los insumos
activos bajo mínimo con proveedor preferido precargado, marcas iniciales y avisos.

**Independent Test**: abrir la pantalla con ALMENDRAS (bajo mínimo, con proveedor), AGUA
BOLSA X 300 ML (bajo mínimo, sin proveedor) y el caso sin insumos bajo mínimo; verificar
listado, marcas, avisos y contadores sin generar ninguna orden.

### Backend para User Story 1

- [X] T010 [US1] Implementar `generate_suggested_purchase_lines(db, page, size)` en `../pos-backend/app/api/v1/inventory/service.py`: query sobre `InventoryItem` (`active=True`, `current_stock <= min_stock`), `deficit = min_stock - current_stock` calculado en el query, orden `deficit DESC`, paginado igual que el patrón de `/items`/`/purchases`; combina con la función de precarga de T009 para completar proveedor/unidad/precio por fila; calcula `is_preselected` (`true` solo si `supplier_item_id`, `purchase_unit_label` y `unit_price > 0` están completos) y `missing_supplier_reason` (`"Sin proveedor configurado. Elige uno."` cuando `is_preselected` es `false`)
- [X] T011 [US1] Agregar endpoint `GET /inventory/purchases/suggested` en `../pos-backend/app/api/v1/inventory/router.py` (cerca de `/purchases`, línea ~483): `response_model=Page[SuggestedPurchaseLineResponse]`, query params `page: int = Query(1, ge=1)` y `size: int = Query(20, ge=1, le=100)`, guard `get_current_user` (mismo criterio de solo lectura que `/purchases`), delega a T010
- [X] T012 [P] [US1] Characterization test nuevo en `../pos-backend/app/characterization_tests/test_suggested_purchases.py`: casos de "insumo bajo mínimo con proveedor preferido completo" (preseleccionado), "insumo bajo mínimo sin proveedor/unidad/precio" (desmarcado + `missing_supplier_reason`), "sin insumos bajo mínimo" (`items: []`, `total: 0`), "orden por déficit descendente", "paginación respeta `page`/`size`"

### Frontend para User Story 1

- [X] T013 [P] [US1] Agregar interfaces nuevas en `../pos-heladeria/src/app/modules/inventory/interfaces/inventory.interface.ts`: `SuggestedPurchaseLine` (espejo de `SuggestedPurchaseLineResponse`) y `SuggestedPurchaseAlternativeSupplier` si se necesita un tipo distinto al ya existente para `GET /items/{id}/suppliers`
- [X] T014 [US1] Crear `../pos-heladeria/src/app/modules/inventory/services/suggested-purchase.service.ts` con un método que consuma `GET /inventory/purchases/suggested` vía `injectPagedQuery` (mismo patrón que el servicio de `/inventory/items`/`/inventory/purchases` en `inventory.service.ts`), devolviendo `Page<SuggestedPurchaseLine>`
- [X] T015 [P] [US1] Test de `suggested-purchase.service.ts` en `../pos-heladeria/src/app/modules/inventory/services/suggested-purchase.service.spec.ts`: verifica la llamada HTTP con `page`/`size` y el mapeo de la respuesta paginada
- [X] T016 [US1] Crear `../pos-heladeria/src/app/modules/inventory/pages/suggested-purchase-page.component.ts` (standalone, `OnPush`, signals, mismo esqueleto que `purchase-view.component.ts`): tabla paginada de `SuggestedPurchaseLine`, columna de proveedor/unidad/precio/cantidad/equivalencia/subtotal, checkbox de selección deshabilitado cuando `is_preselected` es `false` mostrando `missing_supplier_reason`, mensaje "No hay insumos bajo mínimo" y botón "Generar órdenes de compra" deshabilitado cuando `total === 0`, selección inicial = `is_preselected` por fila
- [X] T017 [US1] Mantener la selección/cantidades/proveedores/precios ajustados en un `Map<string, LineState>` por `inventory_item_id` dentro de `suggested-purchase-page.component.ts` (no en el array de la página actual), para que sobrevivan al cambiar de página (FR-020)
- [X] T018 [P] [US1] Agregar ruta `inventario/compra-sugerida` en `../pos-heladeria/src/app/modules/dashboard/routes.ts` apuntando a `suggested-purchase-page.component.ts`, con `roleGuard([UserRole.ADMIN])` + `planModuleGuard('inventario')` (mismo criterio que `inventario/compras/nueva`, research.md D2)
- [X] T019 [P] [US1] Test de componente en `../pos-heladeria/src/app/modules/inventory/pages/suggested-purchase-page.component.spec.ts`: casos de fila preseleccionada con proveedor, fila desmarcada sin proveedor con el aviso correspondiente, y mensaje "No hay insumos bajo mínimo" con botón deshabilitado cuando no hay filas

**Checkpoint**: User Story 1 completamente funcional y probable de forma independiente (solo lectura, sin generar órdenes).

---

## Phase 4: User Story 2 - Generar órdenes de compra agrupadas por proveedor (Priority: P1)

**Goal**: generación transaccional de una orden `draft` por proveedor distinto entre las
líneas seleccionadas, con idempotencia, revalidación de servidor y rollback total ante error.

**Independent Test**: con varios insumos ya seleccionados y repartidos entre proveedores
(incluyendo un caso de datos inválidos y uno de fallo simulado), presionar "Generar órdenes
de compra" y verificar que se crean o no las órdenes esperadas, sin depender de la Historia 3.

### Backend para User Story 2

- [X] T020 [US2] Implementar `generate_suggested_purchases(db, idempotency_key, lines)` en `../pos-backend/app/api/v1/inventory/service.py`: (a) si ya existe `PurchaseGenerationRequest` con esa `idempotency_key`, devolver las `Purchase` ya existentes (`purchase_ids`) sin revalidar ni crear nada; (b) si no existe, revalidar cada línea contra `SupplierItem` (activo, con factor de conversión resuelto) exigiendo `presentation_quantity >= 1` y `presentation_unit_cost > 0` — si alguna falla, no crear ninguna `Purchase` y devolver el detalle de línea/motivo (`unit_price_zero` | `quantity_below_minimum` | `supplier_item_inactive` | `supplier_item_not_found`); (c) agrupar las líneas válidas por `SupplierItem.supplier_id`, construir una `Purchase`+`PurchaseItem[]` en `draft` por grupo reusando la variante no-commiteadora de T006 con `update_supplier_cost=False`; (d) insertar la fila `PurchaseGenerationRequest(idempotency_key, purchase_ids)` y hacer un único `db.commit()` para todas las órdenes + la fila de idempotencia; (e) ante cualquier excepción durante la creación, `db.rollback()` completo sin insertar la fila de idempotencia (para que un reintento con la misma clave sí reintente)
- [X] T021 [US2] Agregar endpoint `POST /inventory/purchases/suggested/generate` en `../pos-backend/app/api/v1/inventory/router.py` (cerca de `/purchases/order`, línea ~514): `request_body=GenerateSuggestedPurchasesRequest`, `response_model=GenerateSuggestedPurchasesResponse`, guard `require_tenant_admin` (mismo criterio que `/purchases/order`); responde `201` en la primera ejecución y `200` cuando la `idempotency_key` ya existía; ante líneas inválidas responde `422` con el `detail.lines[]` del contrato (`message`, `inventory_item_id`, `reason`)
- [X] T022 [P] [US2] Characterization test nuevo (agregar a `../pos-backend/app/characterization_tests/test_suggested_purchases.py`): 3 insumos de 3 proveedores distintos → 3 `Purchase draft`; línea con precio `0` o cantidad `< 1` → `422`, ninguna orden creada; dos líneas seleccionadas con el mismo proveedor → una sola `Purchase` con dos `PurchaseItem`; fallo simulado a mitad de la creación (p. ej. `SupplierItem` desactivado entre lectura y generación) → rollback total, ninguna orden parcial; reenvío de la misma `idempotency_key` → misma respuesta, `COUNT(*) FROM tenant.purchase_generation_requests WHERE idempotency_key = ...` sigue siendo `1`; confirmar que `SupplierItem.last_cost` no cambia tras generar con un precio editado distinto al guardado (FR-007)

### Frontend para User Story 2

- [X] T023 [US2] Agregar al `suggested-purchase.service.ts` (de T014) un método `generate(idempotencyKey, lines)` que llame `POST /inventory/purchases/suggested/generate` devolviendo `GenerateSuggestedPurchasesResponse`
- [X] T024 [P] [US2] Test del método `generate()` en `suggested-purchase.service.spec.ts`: payload correcto, mapeo de `200`/`201`, y propagación del error `422` con `detail.lines[]`
- [X] T025 [US2] En `suggested-purchase-page.component.ts`: generar un `idempotency_key` por intento de envío (UUID de cliente) al construir el payload de "Generar órdenes de compra"; reusar la misma clave si el usuario reintenta sin recargar la pantalla tras un error de red (no generar una nueva en cada click mientras la solicitud anterior pueda no haber terminado)
- [X] T026 [US2] En `suggested-purchase-page.component.ts`: deshabilitar el botón "Generar órdenes de compra" mientras la solicitud está en curso (FR-010); al éxito, mostrar confirmación con enlace a cada `Purchase` creada (usar `PurchaseResponse.id` para construir el enlace a la vista de compra existente); al error `422`, resaltar cada fila listada en `detail.lines[]` con su mensaje y no limpiar la selección/cantidades/proveedores/precios; al error `5xx`, mostrar mensaje de error genérico (`ToastService`) conservando igualmente todo el estado en pantalla (FR-019)
- [X] T027 [P] [US2] Test de componente (agregar a `suggested-purchase-page.component.spec.ts`): generación exitosa con 3 proveedores muestra confirmación con 3 enlaces; línea inválida resalta la fila con su mensaje y no limpia el formulario; error de servidor conserva selección/cantidades/proveedores/precios; el botón de generar queda deshabilitado mientras la solicitud está en curso

**Checkpoint**: Historias 1 y 2 (ambas P1) funcionan juntas de forma independiente — la pantalla completa ya es usable de punta a punta con valores por defecto.

---

## Phase 5: User Story 3 - Ajustar cantidad y proveedor antes de generar (Priority: P2)

**Goal**: permitir ajustar cantidad y cambiar a un proveedor alternativo por fila, con
recálculo inmediato de subtotal, equivalencia y contadores de resumen.

**Independent Test**: con un insumo preseleccionado y un proveedor alternativo configurado,
subir/bajar la cantidad y cambiar el proveedor, verificando que subtotal, equivalencia y
contadores se recalculan de inmediato sin generar ninguna orden.

### Frontend para User Story 3

(No requiere backend nuevo: reusa `GET /inventory/items/{item_id}/suppliers` ya existente,
research.md D4.)

- [X] T028 [US3] En `suggested-purchase-page.component.ts`: controles de incremento/decremento y entrada directa de cantidad por fila (mínimo `1`, corrigiendo o rechazando valores menores o no numéricos antes de permitir marcar la fila, FR-003/Edge Cases), actualizando el `Map<string, LineState>` de T017
- [X] T029 [US3] En `suggested-purchase-page.component.ts`: selector de proveedor alternativo por fila que, al abrirse, llama `GET /inventory/items/{item_id}/suppliers` (servicio ya existente, `SupplierItemsService`/`list_for_item`) **solo en ese momento** (no precargado en bloque — research.md D4, [[no-proactive-background-fetches-in-selectors]]); al elegir una alternativa, carga su unidad de compra y precio, conserva la cantidad ya ingresada (FR-004)
- [X] T030 [US3] En `suggested-purchase-page.component.ts`: `computed()` de subtotal por fila (`cantidad × precio`, redondeado a 2 decimales, FR-016) y de equivalencia en unidad de inventario (`cantidad × conversion_factor`, sin redondeo adicional más allá del que ya usa el sistema de unidades, FR-015), recalculados ante cualquier cambio de cantidad/proveedor/precio
- [X] T031 [US3] En `suggested-purchase-page.component.ts`: `computed()` de resumen (insumos seleccionados, proveedores distintos entre seleccionados, número de órdenes a generar = proveedores distintos, total estimado redondeado a 2 decimales), recalculado de inmediato ante cada cambio (FR-016/SC-006)
- [X] T032 [US3] Permitir editar el precio de una línea directamente en la fila (reusando `MoneyInputComponent` como en `purchase-view.component.ts`), afectando solo el payload de generación de esa línea sin llamar a ningún endpoint de actualización de `SupplierItem` (FR-007)
- [X] T033 [P] [US3] Test de componente (agregar a `suggested-purchase-page.component.spec.ts`): subir cantidad de `1` a `6` actualiza subtotal/equivalencia/resumen; elegir proveedor alternativo carga su unidad/precio y conserva cantidad, actualizando contador de proveedores y de órdenes a generar; editar el precio de una fila no dispara ninguna llamada de actualización de `SupplierItem`; entrada de cantidad inválida (`0`, texto no numérico) se corrige o rechaza antes de permitir marcar la fila

**Checkpoint**: las tres historias funcionan juntas; la pantalla completa cubre el spec entero.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: validación end-to-end y verificación de los criterios de éxito no cubiertos
historia por historia.

- [X] T034 [P] Ejecutar la guía completa de `quickstart.md` (los 3 escenarios) contra `pos-backend`/`pos-heladeria` corriendo localmente, incluyendo las verificaciones SQL de `last_cost` sin cambios (FR-007) y de `COUNT(*)` en `purchase_generation_requests` tras reenvío (SC-005)
- [X] T035 [P] Ejecutar la suite completa de characterization tests de backend (`cd ../pos-backend && ./env/bin/python -m unittest discover app/characterization_tests`) y diffear contra el baseline conocido antes de este feature (ver memoria del proyecto: comparar por archivo, no por conteo total)
- [X] T036 [P] Ejecutar `ng test` en `pos-heladeria` para los specs nuevos (`suggested-purchase-page.component.spec.ts`, `suggested-purchase.service.spec.ts`) y diffear contra el baseline conocido (memoria del proyecto: frontend baseline es flaky/no determinista, comparar por archivo)
- [X] T037 Verificar manualmente con ~100 filas bajo mínimo (seed de prueba) que la paginación responde fluida y que la selección/cantidades/proveedores/precios se conservan al cambiar de página (FR-020, no cubierto por quickstart.md)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias — puede iniciar de inmediato
- **Foundational (Phase 2)**: depende de Phase 1 (T001-T003) solo porque `GenerateSuggestedPurchasesResponse`/el flujo de generación referencian la tabla de idempotencia; los DTOs de T004/T005 no dependen de ella y pueden empezar en paralelo con Phase 1
- **User Story 1 (Phase 3)**: depende de Phase 2 completa (T004, T009 para el endpoint de lectura)
- **User Story 2 (Phase 4)**: depende de Phase 1 y Phase 2 completas (T001-T003 para la tabla de idempotencia, T005-T007 para DTOs y refactor de servicio); no depende de Phase 3, pero en frontend reusa el mismo componente/servicio creados en T014/T016, así que en la práctica conviene completar T014/T016 antes de T023/T025
- **User Story 3 (Phase 5)**: depende de Phase 3 (reusa el componente `suggested-purchase-page.component.ts` y el `Map<string, LineState>` de T016/T017); no requiere backend nuevo
- **Polish (Phase 6)**: depende de que las 3 historias estén completas

### Parallel Opportunities

- T001 y T004/T005 pueden avanzar en paralelo (modelo nuevo vs. DTOs nuevos, archivos distintos)
- Dentro de Phase 2: T004, T005, T009 son `[P]` (archivos/funciones distintas); T006/T007 son secuenciales entre sí (mismo archivo, mismo refactor)
- Backend de US1 (T010-T012) y el refactor de servicio para US2 (dentro de Phase 2) no se bloquean entre sí, pero ambos dependen de Phase 2 completa
- Frontend: T013/T015/T018/T019 son `[P]` entre sí (archivos distintos); T024/T027 y T033 igualmente `[P]` respecto a tareas de otras historias que tocan archivos distintos
- T034/T035/T036 en Polish son `[P]` entre sí (verificación manual, backend, frontend — sin dependencia de archivo)

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Completar Phase 1 (tabla de idempotencia) — aunque no se use todavía, aplicar la migración desde ya evita un segundo ciclo de migración antes de US2
2. Completar Phase 2 (DTOs + refactor de servicio)
3. Completar Phase 3 (User Story 1: pantalla de solo lectura)
4. **STOP y VALIDAR**: abrir la pantalla con los 3 casos del quickstart (Escenario 1) sin generar ninguna orden

### Incremental Delivery

1. Setup + Foundational → infraestructura compartida lista
2. User Story 1 → pantalla de solo lectura usable (demo: "qué necesito comprar")
3. User Story 2 → generación transaccional agrupada por proveedor (MVP funcional completo, ambas P1)
4. User Story 3 → ajuste de cantidad/proveedor antes de generar (mejora sobre el MVP, P2)
5. Polish → quickstart completo + diffs de characterization tests/specs de Angular
