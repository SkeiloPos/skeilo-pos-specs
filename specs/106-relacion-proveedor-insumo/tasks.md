---

description: "Task list for feature implementation"
---

# Tasks: Gestión de la relación proveedor–insumo

**Input**: Design documents from `/specs/106-relacion-proveedor-insumo/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/api.md, quickstart.md
(todos presentes)

**Tests**: incluidas — no son opcionales en este feature. El Principio X de la constitución
exige verificar toda funcionalidad nueva, y `plan.md`/`research.md` (D9) ya comprometieron el
mecanismo concreto: un script autoejecutable `pos-backend/app/scripts/test_supplier_items.py`
(no hay pytest en este repo) extendido incrementalmente por historia, más specs Vitest por
componente nuevo en `pos-heladeria`.

**Organization**: tareas agrupadas por historia de usuario (spec.md) para que cada una sea
implementable y verificable de forma independiente.

## Path Conventions

Proyecto web de dos repositorios hermanos, fuera de `pos-specs` (ver plan.md § Project
Structure): `../pos-backend/app/...` (FastAPI) y `../pos-heladeria/src/app/...` (Angular).

---

## Phase 1: Setup

**Purpose**: preparar las ramas de trabajo en los dos repositorios de código (Principio XIV de
la constitución: ninguna modificación de código empieza sin su rama propia).

- [X] T001 [P] Crear la rama `feat/106-supplier-item-relation` en `../pos-backend`, partiendo
  de la rama en la que se encuentre el repositorio en este momento.
- [X] T002 [P] Crear la rama `feat/106-supplier-item-relation` en `../pos-heladeria`, partiendo
  de la rama en la que se encuentre el repositorio en este momento.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: modelo de datos, migración, esquemas y clientes base que las cuatro historias
comparten.

**⚠️ CRITICAL**: ninguna historia de usuario puede empezar antes de que esta fase termine.

- [X] T003 Crear la migración Alembic en `../pos-backend/alembic/versions/` (nombre
  `<hash>_supplier_items_y_proveedor_sistema.py`), decorada con `@for_each_tenant_schema`
  (patrón de `f03274730367_presentations_y_reglas_por_presentacion.py`): (1) `op.add_column`
  `suppliers.is_system BOOLEAN NOT NULL DEFAULT false`; (2) `INSERT` idempotente del proveedor
  semilla "Compra ocasional" (`is_system=true, active=true`) por esquema; (3) `op.create_table`
  `supplier_items` con sus columnas, `CheckConstraint(conversion_factor > 0)`, el índice único
  por expresión `ux__supplier_items__combo` sobre `lower(trim(presentation))`, y el índice único
  parcial `ux__supplier_items__preferred` (`WHERE preferred AND active`, no `DEFERRABLE`); (4)
  `op.add_column` `purchase_items.supplier_item_id UUID NULL` con su FK — ver
  `data-model.md` § Migración.
- [X] T004 [P] Agregar la columna `is_system: Mapped[bool]` (default `False`) a
  `../pos-backend/app/models/supplier.py`.
- [X] T005 [P] Crear el modelo `SupplierItem` en
  `../pos-backend/app/models/supplier_item.py` (tabla `supplier_items`, `schema="tenant"`) con
  todas las columnas y la `CheckConstraint` de `data-model.md` § Entidad nueva.
- [X] T006 [P] Agregar la columna `supplier_item_id: Mapped[Optional[UUID]]` (FK a
  `supplier_items.id`) a `PurchaseItem` en `../pos-backend/app/models/purchase.py`.
- [X] T007 Agregar `SupplierItemCreate`, `SupplierItemUpdate` y `SupplierItemResponse` (con el
  cálculo de `equivalence`, redondeado a 2 decimales) a
  `../pos-backend/app/api/v1/inventory/schemas.py` — ver `data-model.md` § Esquemas Pydantic.
- [X] T008 [P] Crear `../pos-backend/app/api/v1/inventory/supplier_items.py` con el esqueleto de
  funciones de servicio que usarán todas las historias (`_get_or_404`, `_equivalence`), siguiendo
  el patrón de archivo propio de `stock.py`/`export.py` (research.md D1).
- [X] T009 [P] Agregar el parámetro de query `exclude_system: bool = False` a
  `list_suppliers` (`GET /inventory/suppliers`) en
  `../pos-backend/app/api/v1/inventory/router.py`: cuando es `true`, excluye los proveedores con
  `is_system=true` del resultado; el comportamiento por defecto (sin el parámetro) no cambia para
  ningún llamador existente — base de FR-012 para las historias 1, 2 y 3.
- [X] T010 [P] Crear
  `../pos-heladeria/src/app/modules/supplier-items/interfaces/supplier-item.interface.ts` con los
  campos de `data-model.md` (`presentation`, `conversionFactor`, `lastCost`, `lastCostAt`,
  `active`, `preferred`, `equivalence`, `supplierName`, `inventoryItemName`).
- [X] T011 [P] Crear
  `../pos-heladeria/src/app/modules/supplier-items/services/supplier-items.service.ts` con los
  métodos cliente de las 4 rutas de `contracts/api.md` (sin UI todavía).
- [X] T012 [P] ~~Crear el componente de pestañas genérico~~ — descartado durante la
  implementación (research.md D8, revisado): `InventoryPageComponent` ya tenía una barra de
  pestañas armada en línea (botones + clase condicional), no detectada en la Fase 0 porque el
  grep buscaba un *componente* (`TabsComponent`/`mat-tab-group`), no un *patrón* inline ya
  repetido. Las dos páginas de detalle (T020, T030) replican ese mismo bloque en vez de extraer
  una abstracción nueva (Principio V).
- [X] T013 Correr `./env/bin/python -m unittest discover -s app/characterization_tests` en
  `../pos-backend` y confirmar que la migración de T003 no rompe ningún test
  `"CONGELA comportamiento actual:"` (Principio III de la constitución).

**Checkpoint**: modelo, esquema, migración, cliente HTTP y componente de pestañas listos —
ninguna historia de usuario empieza antes de este punto.

---

## Phase 3: User Story 1 - Vincular un proveedor a un insumo con presentación y factor (Priority: P1) 🎯 MVP

**Goal**: un administrador agrega, desde la pestaña "Proveedores" del detalle de un insumo, un
proveedor que se lo vende, con presentación, factor y último costo opcional — sin duplicar
insumos ni crear relaciones duplicadas.

**Independent Test**: abrir el detalle de un insumo existente, agregar un proveedor con
presentación y factor en su pestaña "Proveedores", y verificar que la relación queda activa sin
tocar ninguna otra pantalla.

### Tests for User Story 1 ⚠️

> Escribir primero; deben FALLAR antes de la implementación (el servicio todavía no existe).

- [X] T014 [P] [US1] Escribir los escenarios 1–6 de la Historia 1 (alta con equivalencia
  "1 Bolsa x 500 g = 500 g · $16.00/g", segundo proveedor con otra presentación, factor 0/negativo
  rechazado, relación duplicada con mayúsculas/espacios distintos, reactivar en vez de duplicar,
  factor bloqueado tras uso en compra, y un mismo proveedor con dos presentaciones distintas
  del mismo insumo, ambas activas sin violar la unicidad) en
  `../pos-backend/app/scripts/test_supplier_items.py`.

### Implementation for User Story 1

- [X] T015 [US1] Implementar `create_or_reactivate(db, supplier_id, inventory_item_id, body)` en
  `../pos-backend/app/api/v1/inventory/supplier_items.py`: valida `conversion_factor > 0`
  (mensaje dinámico con la unidad base del insumo, FR-002), rechaza `supplier.is_system`
  (FR-013), busca una fila existente por `(supplier_id, inventory_item_id,
  lower(trim(presentation)))` — reactiva si está inactiva (FR-005), responde 409 si está activa
  (FR-004), crea si no existe; fija `last_cost_at = now()` cuando llega `last_cost` (FR-006)
  (depende de T005, T007, T008).
- [X] T016 [US1] Agregar `_factor_is_locked(db, relation_id) -> bool` en `supplier_items.py`
  (`EXISTS` sobre `purchase_items.supplier_item_id`) y aplicarlo para rechazar con 422 cualquier
  intento de cambiar `conversion_factor` sobre una relación ya usada en una compra (FR-014;
  depende de T006, T008).
- [X] T017 [US1] Agregar `POST /inventory/items/{item_id}/suppliers` y
  `GET /inventory/items/{item_id}/suppliers?include_inactive=` a
  `../pos-backend/app/api/v1/inventory/router.py`, delegando en T015 (depende de T015).
- [X] T018 [US1] Correr `./env/bin/python -m app.scripts.test_supplier_items` y confirmar que los
  escenarios 1–6 de T014 pasan (depende de T015, T016, T017).
- [X] T019 [P] [US1] Crear
  `../pos-heladeria/src/app/modules/supplier-items/components/supplier-item-form.component.ts`
  (presentación + factor con etiqueta dinámica "¿Cuántos {unidad base} trae 1 presentación?" y
  equivalencia recalculada en vivo antes de guardar, FR-018), con su spec
  `supplier-item-form.component.spec.ts` (depende de T010, T011).
- [X] T020 [US1] Crear
  `../pos-heladeria/src/app/modules/inventory/pages/inventory-item-detail-page.component.ts` con
  la pestaña "Proveedores" (lista de relaciones + alta vía T019; las inactivas ocultas por
  defecto, FR-017), con su spec `inventory-item-detail-page.component.spec.ts` (depende de T012,
  T019).
- [X] T021 [US1] Registrar la ruta del nuevo detalle de insumo en el enrutador de Angular y el
  enlace desde cada fila de
  `../pos-heladeria/src/app/modules/inventory/pages/inventory-page.component.ts` hacia ese
  detalle (depende de T020).

**Checkpoint**: Historia 1 funcional de punta a punta — vincular, ver la equivalencia en vivo, y
los tres rechazos (factor inválido, duplicada, factor bloqueado) funcionan de forma
independiente.

---

## Phase 4: User Story 2 - Marcar un proveedor como preferido de un insumo (Priority: P1)

**Goal**: entre varios proveedores vinculados a un insumo, marcar uno como preferido desmarca
automáticamente al anterior, y nunca queda más de un preferido activo.

**Independent Test**: con un insumo que ya tiene al menos dos proveedores vinculados (de la
Historia 1), marcar uno como preferido, luego marcar el otro, y verificar en cada paso cuál queda
marcado.

### Tests for User Story 2 ⚠️

- [X] T022 [P] [US2] Escribir los escenarios de la Historia 2 (swap de preferido entre dos
  relaciones del mismo insumo, rechazo al marcar como preferida una relación inactiva, rechazo al
  vincular o preferir al proveedor sembrado "Compra ocasional", y el rechazo de
  `preferred=true` combinado con `active=false` en la misma solicitud) en
  `../pos-backend/app/scripts/test_supplier_items.py`.

### Implementation for User Story 2

- [X] T023 [US2] Implementar `set_preferred(db, relation_id)` en `supplier_items.py`:
  `lock_items(db, [inventory_item_id])` (reutilizado de `app/inventory_engine/stock.py`) →
  desmarca cualquier otra `preferred=true` del mismo insumo → marca la relación actual → commit,
  en ese orden exacto (research.md D2/RN-16); rechaza con 422 si `active=false` (FR-010) o si
  `supplier.is_system` (FR-013) (depende de T005, T008).
- [X] T024 [US2] Implementar `PATCH /inventory/supplier-items/{relation_id}` en
  `router.py`/`supplier_items.py`: el campo `preferred` se enruta a T023; `presentation` se
  edita directamente; si `last_cost` viene en el cuerpo, se aplica y se refresca
  `last_cost_at = now()` en la misma operación (FR-006); `conversion_factor` reutiliza el guard
  de T016 (depende de T015, T016, T023).
- [X] T025 [US2] Correr `./env/bin/python -m app.scripts.test_supplier_items` y confirmar que los
  escenarios de T022 pasan; además, contra el Postgres desechable de `quickstart.md`, lanzar dos
  marcas de preferido concurrentes a proveedores distintos del mismo insumo desde dos conexiones y
  verificar que, al terminar, existe exactamente una fila `preferred=true` (RN-16 bajo
  concurrencia real — no verificable en la suite de characterization sobre SQLite, research.md
  D9) (depende de T023, T024).
- [X] T026 [P] [US2] Agregar la estrella de preferido (un clic) a la fila de relación en
  `supplier-item-form.component.ts` (o su componente de fila de listado), y usar
  `exclude_system=true` (T009) al cargar el selector de proveedores para vincular (depende de
  T019, T009).

**Checkpoint**: Historias 1 y 2 funcionan juntas — cualquier insumo con relaciones activas tiene,
a lo sumo, un preferido, y "Compra ocasional" nunca aparece ni se puede forzar por API.

---

## Phase 5: User Story 3 - Ver y gestionar las relaciones desde el detalle del proveedor (Priority: P2)

**Goal**: el mismo conjunto de relaciones, visto y gestionable desde la pestaña "Insumos que
vende" del detalle del proveedor, sin duplicar lógica ni datos.

**Independent Test**: abrir el detalle de un proveedor con al menos una relación activa (creada
en la Historia 1) y verificar que la pestaña "Insumos que vende" la muestra, y que crear o editar
una relación desde ahí produce el mismo resultado que hacerlo desde el insumo.

### Tests for User Story 3 ⚠️

- [X] T027 [P] [US3] Escribir los escenarios de la Historia 3 (la relación aparece en "Insumos
  que vende" del proveedor; un cambio hecho desde la pestaña del proveedor se refleja en la
  pestaña del insumo sin pasos adicionales) en
  `../pos-backend/app/scripts/test_supplier_items.py`.

### Implementation for User Story 3

- [X] T028 [US3] Agregar `POST /inventory/suppliers/{supplier_id}/items` y
  `GET /inventory/suppliers/{supplier_id}/items?include_inactive=` a `router.py`, reutilizando
  `create_or_reactivate` de T015 con los ids del cuerpo invertidos; 404 si el proveedor no existe
  en el tenant actual o si `is_system=true` (depende de T015).
- [X] T029 [US3] Correr `./env/bin/python -m app.scripts.test_supplier_items` y confirmar que los
  escenarios de T027 pasan (depende de T028).
- [X] T030 [US3] Crear
  `../pos-heladeria/src/app/modules/suppliers/pages/supplier-detail-page.component.ts` con la
  pestaña "Insumos que vende", reutilizando `supplier-item-form.component.ts` (T019) y el
  componente de pestañas (T012), con su spec `supplier-detail-page.component.spec.ts` (depende de
  T012, T019, T028).
- [X] T031 [US3] Registrar la ruta del nuevo detalle de proveedor en el enrutador de Angular y el
  enlace desde cada fila de
  `../pos-heladeria/src/app/modules/suppliers/pages/suppliers-page.component.ts` hacia ese
  detalle; la fila del proveedor sembrado "Compra ocasional" (`is_system=true`) se muestra sin
  ese enlace, ya que no tiene pestaña "Insumos que vende" que mostrar (FR-012; depende de
  T030).

**Checkpoint**: cualquier cambio hecho desde cualquiera de las dos pestañas se ve reflejado de
inmediato en la otra — Historias 1, 2 y 3 conviven sin desincronización.

---

## Phase 6: User Story 4 - Desactivar una relación proveedor-insumo (Priority: P2)

**Goal**: desactivar una relación (en vez de borrarla) conserva el historial; si era la
preferida, el insumo queda sin preferido y la interfaz lo advierte.

**Independent Test**: desactivar una relación activa (preferida o no, creada en historias
anteriores) y verificar su nuevo estado y el aviso mostrado, sin depender de otras historias más
allá de los datos de partida.

### Tests for User Story 4 ⚠️

- [X] T032 [P] [US4] Escribir los escenarios de la Historia 4 (desactivar la relación preferida
  → queda inactiva y no preferida, con aviso; desactivar una relación no-preferida → sin aviso,
  el insumo conserva su preferido) en `../pos-backend/app/scripts/test_supplier_items.py`.

### Implementation for User Story 4

- [X] T033 [US4] Extender el `PATCH /inventory/supplier-items/{relation_id}` de T024: cuando el
  cuerpo trae `active=false` y la relación tenía `preferred=true`, forzar `preferred=false` en la
  misma operación y devolver `was_preferred=true` en la respuesta (FR-011; depende de T024).
- [X] T034 [US4] Correr `./env/bin/python -m app.scripts.test_supplier_items` y confirmar que los
  escenarios de T032 pasan (depende de T033).
- [X] T035 [P] [US4] Agregar la acción "Desactivar" a la fila de relación en el frontend, el
  aviso "Sin proveedor preferido: no se incluirá en órdenes sugeridas" cuando la respuesta traiga
  `was_preferred=true`, y el interruptor "mostrar inactivas" (FR-017) en las dos páginas de
  detalle (depende de T020, T030).

**Checkpoint**: ciclo de vida completo de la relación — crear, preferir, ver desde ambos lados,
desactivar — funcional de punta a punta.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [X] T036 [P] Agregar a `../pos-backend/app/scripts/test_supplier_items.py` el escenario de
  aislamiento de tenant (FR-015): desde un segundo tenant, consultar, editar (`PATCH`) y
  desactivar un `relation_id` que pertenece al primer tenant, y confirmar 404 en los tres casos.
- [X] T037 [P] En `../pos-heladeria`, correr `npx ng test --watch=false` con
  `--include='src/app/modules/supplier-items/**/*.spec.ts'`,
  `--include='src/app/modules/inventory/**/*.spec.ts'` y
  `--include='src/app/modules/suppliers/**/*.spec.ts'`; comparar contra la lista base conocida
  (19 fallos preexistentes en 6 archivos no relacionados, memoria de sesión) y confirmar que no se
  agregó ningún fallo nuevo.
- [ ] T038 Ejecutar el recorrido manual de `quickstart.md` § 2 (6 pasos de UI) contra
  `ng serve` en `../pos-heladeria`.
- [X] T039 Revisar que todo comentario, mensaje de error y docstring nuevo esté en español de
  Colombia (Principio XIII), y que las ramas/commits de esta implementación sigan los
  Principios XIV/XV antes de reportar la funcionalidad como completa.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Fase 1)**: sin dependencias — arranca de inmediato.
- **Foundational (Fase 2)**: depende de Setup — bloquea las cuatro historias.
- **User Stories (Fase 3-6)**: todas dependen de Foundational. US1 es la base de datos/UI que
  las demás reutilizan directamente (no son independientes entre sí a nivel de código, a
  diferencia del caso típico): US2 extiende el mismo `PATCH`/formulario de US1; US3 reutiliza el
  servicio de creación de US1; US4 extiende el mismo `PATCH` de US2. Orden de implementación
  recomendado: **secuencial por prioridad** (US1 → US2 → US3 → US4), no en paralelo por
  desarrollador, precisamente porque cada una amplía el mismo endpoint/componente de la anterior.
- **Polish (Fase 7)**: depende de que las cuatro historias estén completas.

### Parallel Opportunities

- Fase 1: T001 y T002 en paralelo (repositorios distintos).
- Fase 2: T004, T005, T006, T008, T009, T010, T011, T012 pueden avanzar en paralelo entre sí
  (archivos distintos); T003 (migración) y T007 (schemas.py) son compartidos por varias de ellas
  y conviene cerrarlos primero; T013 va al final de la fase.
- Dentro de cada historia, la tarea de tests ([P]) puede escribirse en paralelo con tareas de
  otra historia que no dependan de ella, pero sus tareas de implementación son mayormente
  secuenciales (mismo archivo `supplier_items.py`/`router.py`/`supplier-item-form.component.ts`
  que ya tocó la historia anterior).

---

## Parallel Example: Foundational (Fase 2)

```bash
# Después de T003 (migración):
Task: "Agregar is_system a app/models/supplier.py"               # T004
Task: "Crear SupplierItem en app/models/supplier_item.py"          # T005
Task: "Agregar supplier_item_id a app/models/purchase.py"          # T006
Task: "Crear supplier-item.interface.ts"                           # T010
Task: "Crear supplier-items.service.ts"                            # T011
Task: "Crear tabs.component.ts"                                    # T012
```

---

## Implementation Strategy

### MVP First (User Story 1 solamente)

1. Completar Fase 1 (Setup) y Fase 2 (Foundational — bloquea todo).
2. Completar Fase 3 (Historia 1).
3. **Detener y validar**: correr `quickstart.md` § 1, escenarios 1–6, y el paso manual 1 de § 2.
4. Esto ya resuelve el dolor principal del spec: "a quién le compro cada insumo, en qué
   presentación", sin preferido ni desactivación todavía.

### Entrega incremental

1. Setup + Foundational → base lista.
2. + Historia 1 → vincular proveedores (MVP, demostrable).
3. + Historia 2 → preferido único, exclusión del proveedor de sistema.
4. + Historia 3 → simetría desde el detalle del proveedor.
5. + Historia 4 → ciclo de vida completo con desactivación.
6. + Polish → aislamiento de tenant verificado, specs de frontend sin regresiones, revisión de
   idioma y de ramas/commits.

---

## Notes

- `[P]` = archivos distintos, sin dependencia pendiente dentro de la misma fase.
- La etiqueta `[USx]` traza cada tarea a su historia de usuario en `spec.md`.
- Las "Tests" de cada historia se escriben primero y deben fallar antes de implementar — todas
  viven en el mismo script (`test_supplier_items.py`), extendido incrementalmente, porque ese es
  el patrón real de verificación de `pos-backend` (sin pytest).
- No se alcanza ningún checkpoint saltándose su tarea de verificación (T018, T025, T029, T034).
- Evitar: tareas vagas, dos tareas `[P]` que en realidad tocan el mismo archivo, y empezar una
  historia antes de que la Fase 2 esté completa.
