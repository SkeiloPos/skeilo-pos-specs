---

description: "Task list template for feature implementation"
---

# Tasks: Módulo "Cocina" en el catálogo de módulos por plan

**Input**: Design documents from `/specs/149-modulo-cocina-plan/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/plan-catalog-cocina.md, quickstart.md

**Alcance acotado** (research.md Decisión 0): esta fase implementa **únicamente** la
característica de plan `cocina_access` — columna booleana, administración por el Super Admin,
y exposición en `GET /plan` — con el mismo patrón que `inventario_access`/`promociones_access`.
No existe en esta fase ningún endpoint ni pantalla de cocina real a la que aplicar enforcement
(FR-004/FR-006 a FR-011 y las Historias de Usuario 2 a 5 del spec quedan documentadas como
comportamiento futuro, sin artefacto de código que las verifique todavía). Por eso **solo hay
una fase de historia de usuario** (US1) — las demás historias del spec no tienen tareas en este
documento porque no hay nada que construir para ellas todavía.

**Tests**: Se extienden characterization tests ya existentes (`test_super_admin_plans.py` en
backend, `plan-form.component.spec.ts` en frontend) con los mismos casos que ya cubren
`inventario_access`/`promociones_access` — no se agrega ningún test de enforcement de endpoint
porque no hay endpoint de cocina que gatear.

**Organización**: Repositorios sibling de `pos-specs` — rutas relativas a la raíz de cada repo:
`../pos-backend` y `../pos-heladeria`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Puede ejecutarse en paralelo (archivos distintos, sin dependencias)
- **[Story]**: Historia de usuario a la que pertenece (US1)

---

## Phase 1: Setup

**Purpose**: Confirmar la línea base antes de tocar código (quickstart.md Paso 0)

- [X] T001 Ejecutar la suite de characterization tests de `pos-backend` para confirmar que
  parte en verde antes de cualquier cambio: `cd ../pos-backend && source env/bin/activate &&
  python -m unittest discover -s app/characterization_tests -p 'test_*.py' -v`. Ningún test
  `"CONGELA comportamiento actual:"` debe asumir que `PLAN_MODULES` tiene exactamente dos
  entradas ni que `Plan` carece de `cocina_access` (research.md Decisión 0, Principio III).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Columna, catálogo de módulos y migración — infraestructura que bloquea toda la
Historia de Usuario 1, porque los schemas y el frontend dependen de que `cocina_access` ya
exista en el modelo

**⚠️ CRITICAL**: Ningún task de la Fase 3 puede completarse sin esta fase

- [X] T002 Agregar `cocina_access: Mapped[bool] = mapped_column(Boolean, nullable=False,
  default=False, server_default="false")` a la clase `Plan` en
  `../pos-backend/app/models/plan.py`, inmediatamente después de `promociones_access`
  (research.md Decisión 3) — mismo tipo y mismo default que `inventario_access`/
  `promociones_access`.
- [X] T003 Agregar `"cocina"` a `PLAN_MODULES` en `../pos-backend/app/core/plan_limits.py`,
  pasando de `("inventario", "promociones")` a `("inventario", "promociones", "cocina")`
  (data-model.md) — ningún otro cambio en ese archivo, `ensure_module_access`/
  `has_module_access`/`require_module_access` ya resuelven cualquier clave vía `getattr`
  genérico.
- [X] T004 Crear la migración Alembic `../pos-backend/alembic/versions/{rev}_149_plans_add_cocina_access.py`,
  encadenada sobre el head actual (`82bab214ee32`): `upgrade()` ejecuta
  `op.add_column("plans", sa.Column("cocina_access", sa.Boolean(), nullable=False,
  server_default=sa.false()), schema="shared")`; `downgrade()` ejecuta
  `op.drop_column("plans", "cocina_access", schema="shared")` (research.md Decisión 4). Depende
  de T002.

**Checkpoint**: `Plan.cocina_access` existe en el modelo y en la base de datos — la Historia de
Usuario 1 puede empezar.

---

## Phase 3: User Story 1 - El Super Admin incluye "Cocina" en un plan (Priority: P1) 🎯 MVP

**Goal**: El Super Admin puede marcar "Cocina" como incluida o no incluida al crear o editar un
plan, con el mismo control que ya usa para Inventario/Promociones, y el tenant ve ese valor
reflejado en `GET /plan`.

**Independent Test**: El Super Admin abre la pantalla de edición de un plan, verifica que
"Cocina" aparece en la lista de módulos disponibles junto a Inventario y Promociones, la marca
como incluida en un plan y como no incluida en otro, guarda ambos cambios exitosamente, y un
tenant de cada plan ve el valor correspondiente en `GET /plan`.

### Backend — schemas y servicio

- [X] T005 [P] [US1] Agregar `cocina_access` a `PlanCreate` (`bool = False`), `PlanUpdate`
  (`Optional[bool] = None`) y `PlanResponse` (`bool`) en
  `../pos-backend/app/api/v1/super_admin/schemas.py`, mismas líneas relativas que
  `inventario_access`/`promociones_access` (contracts/plan-catalog-cocina.md). Depende de T002.
- [X] T006 [P] [US1] Agregar `cocina: bool` a `ModuleAccess` en
  `../pos-backend/app/api/v1/plan/schemas.py` (contracts/plan-catalog-cocina.md). Depende de
  T002.
- [X] T007 [US1] Agregar `"cocina": plan.cocina_access` al diccionario de `modules` construido
  por `build_plan_summary` en `../pos-backend/app/api/v1/plan/service.py`, mismo criterio que
  `inventario`/`promociones` (data-model.md). Depende de T006.

### Backend — characterization tests

- [X] T008 [US1] Extender `../pos-backend/app/characterization_tests/test_super_admin_plans.py`
  con los casos de `cocina_access` (quickstart.md US1): crear plan con `cocina_access=true` →
  `201` con el valor persistido; crear plan sin enviarlo → `201` con `cocina_access: false`
  (FR-003); `PATCH` que cambia `cocina_access` de `true` a `false` → `200`, reflejado en el
  siguiente `GET /super-admin/plans`; `GET /plan` de un tenant con ese plan → `modules.cocina`
  refleja el valor vigente. Mismo patrón que los casos ya existentes de `inventario_access`/
  `promociones_access`. Depende de T005, T007.
- [X] T009 [US1] Ejecutar `cd ../pos-backend && python -m unittest
  app.characterization_tests.test_super_admin_plans -v` y confirmar que todo pasa en verde.
  Depende de T008.

### Frontend — interfaces y formulario

- [X] T010 [P] [US1] Agregar `cocina_access: boolean` a la interfaz `Plan` y
  `cocina_access?: boolean` a `PlanCreatePayload` en
  `../pos-heladeria/src/app/modules/super-admin/interfaces/plan.interface.ts`. Depende de T005.
- [X] T011 [P] [US1] Agregar `cocina: boolean` a la interfaz `ModuleAccess` en
  `../pos-heladeria/src/app/modules/plan/interfaces/plan-summary.interface.ts`. Depende de T006.
- [X] T012 [US1] Agregar el checkbox `formControlName="cocina_access"` en la sección "Accesos de
  módulo" de `../pos-heladeria/src/app/modules/super-admin/components/plan-form.component.ts`,
  el `FormControl` correspondiente y el mapeo al payload en modo creación y edición — mismo
  patrón de tres líneas que `inventario_access`/`promociones_access`, sin diálogo de
  confirmación adicional. Depende de T010.
- [X] T013 [US1] Extender
  `../pos-heladeria/src/app/modules/plan/components/plan-form.component.spec.ts` con los casos
  del checkbox nuevo de "Cocina" (se construye, se muestra, se incluye en el payload de
  creación/edición), mismo patrón que los checkboxes de "Inventario"/"Promociones" ya cubiertos.
  Depende de T012.
- [X] T014 [US1] Ejecutar `cd ../pos-heladeria && ng test --include='**/plan-form.component.spec.ts'`
  y confirmar que todo pasa en verde. Depende de T013.

**Checkpoint**: La Historia de Usuario 1 es completamente funcional y verificable de forma
independiente — es también el alcance total de esta fase (research.md Decisión 0).

---

## Phase 4: Polish & Cross-Cutting Concerns

**Purpose**: Validación end-to-end del alcance acotado, incluyendo la migración

- [X] T015 Ejecutar `cd ../pos-backend && alembic upgrade head` y confirmar que
  `shared.plans` gana `cocina_access` (`boolean NOT NULL DEFAULT false`) y que todo plan
  existente queda con `cocina_access = false` sin acción manual. Depende de T004.
- [X] T016 Ejecutar `cd ../pos-backend && alembic downgrade -1` y confirmar que
  `cocina_access` se elimina de `shared.plans` sin error (research.md Decisión 4). Depende de
  T015.
- [X] T017 Ejecutar `cd ../pos-backend && alembic upgrade head` de nuevo (dejar la base en el
  estado final) y correr la suite completa de characterization tests
  (`python -m unittest discover -s app/characterization_tests -p 'test_*.py' -v`) para confirmar
  que nada existente se rompió (Principio II/III). Depende de T016, T009.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Sin dependencias — puede empezar de inmediato.
- **Foundational (Phase 2)**: Depende de Setup. BLOQUEA toda la Fase 3.
- **User Story 1 (Phase 3)**: Depende de Foundational. Es la única historia con tareas en esta
  fase (research.md Decisión 0).
- **Polish (Phase 4)**: Depende de que la Fase 3 esté completa.

### Dentro de la Fase 3

- Backend (T005-T009) y Frontend (T010-T014) pueden avanzar en paralelo entre sí una vez
  completada la Fase 2, porque no comparten archivos.
- Dentro de backend: schemas (T005, T006) en paralelo → servicio (T007, depende de T006) →
  tests (T008, depende de T005+T007) → ejecución (T009).
- Dentro de frontend: interfaces (T010, T011) en paralelo → componente (T012, depende de T010)
  → test (T013, depende de T012) → ejecución (T014).

### Parallel Example: Phase 3

```bash
# Backend — schemas en paralelo:
Task: "Agregar cocina_access a PlanCreate/PlanUpdate/PlanResponse en app/api/v1/super_admin/schemas.py"
Task: "Agregar cocina: bool a ModuleAccess en app/api/v1/plan/schemas.py"

# Frontend — interfaces en paralelo:
Task: "Agregar cocina_access a Plan/PlanCreatePayload en plan.interface.ts"
Task: "Agregar cocina a ModuleAccess en plan-summary.interface.ts"
```

---

## Implementation Strategy

### MVP = alcance completo de esta fase

No hay incrementos adicionales que agregar después de la Fase 3 en esta spec: la Historia de
Usuario 1 **es** el MVP y el alcance total acordado con el negocio (research.md Decisión 0). Las
Historias 2 a 5 del spec original quedan documentadas como trabajo de una spec futura que
reintroduzca el flujo de cocina y entonces consuma `cocina_access` montando
`Depends(require_module_access("cocina"))` sobre su propio router.

1. Completar Fase 1: Setup (confirmar línea base).
2. Completar Fase 2: Foundational (columna + catálogo + migración) — bloquea todo lo demás.
3. Completar Fase 3: User Story 1 (backend + frontend).
4. Completar Fase 4: Polish (migración de ida y vuelta + suite completa en verde).
5. Ejecutar `quickstart.md` completo como verificación final.

## Notes

- `[P]` = archivos distintos, sin dependencias entre sí.
- `[US1]` es la única etiqueta de historia en este documento — no hay tareas para US2-US5 porque
  no existe código de cocina real al que aplicarles nada todavía (research.md Decisión 0).
- Ningún task de esta fase toca `app/api/v1/orders/kitchen.py`, `OrderItem.estado_cocina`, ni
  ningún router o componente del flujo de entrega de spec 147 — fuera de alcance por diseño.
- Hacer commit después de cada task o grupo lógico.
