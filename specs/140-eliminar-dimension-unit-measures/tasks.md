---

description: "Task list template for feature implementation"
---

# Tasks: Eliminar columna `dimension` en unidades de medida

**Input**: Design documents from `/specs/140-eliminar-dimension-unit-measures/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/unit-measures-api.md, quickstart.md

**Tests**: se incluyen tareas de test porque la columna eliminada está protegida por
characterization tests existentes (Principio III de la constitución) que deben actualizarse
explícitamente, no en silencio.

**Organización**: por la naturaleza de esta spec (eliminar una columna leída en varios puntos
del código), el modelo y la migración son **foundational** — ningún punto de uso puede
actualizarse de forma aislada mientras el atributo siga existiendo, porque el objetivo final es
que deje de existir en todos lados a la vez. Las fases de User Story agrupan los puntos de uso
por la historia que verifican, para poder validar cada una independientemente una vez
completada la fase foundational.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: se puede ejecutar en paralelo (archivos distintos, sin dependencias)
- **[Story]**: a qué historia de usuario del spec pertenece (US1, US2, US3)
- Rutas de archivo relativas a `../pos-backend` o `../pos-heladeria` según se indique

## Phase 1: Setup

**Purpose**: preparar la rama de trabajo y el esqueleto de la migración, por repositorio.

- [x] T001 Crear rama `refactor/139-eliminar-dimension-unit-measures` en `pos-backend` desde la rama actual (Principio XIV de la constitución)
- [x] T002 Crear rama `refactor/139-eliminar-dimension-unit-measures` en `pos-heladeria` desde la rama actual (Principio XIV de la constitución)
- [x] T003 Generar el esqueleto de la migración con `alembic revision -m "139_remove_unit_measure_dimension"` en `../pos-backend/alembic/versions/`, encadenada tras la head actual

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: cambios que deben aplicarse juntos porque ningún punto de uso de `dimension`
puede actualizarse mientras el atributo siga existiendo en el modelo, y viceversa.

**⚠️ CRITICAL**: ninguna tarea de las fases de User Story puede completarse (el código no
compila/corre) hasta que esta fase termine.

- [x] T004 Implementar `upgrade()`/`downgrade()` en la migración creada en T003 (`../pos-backend/alembic/versions/<rev>_139_remove_unit_measure_dimension.py`): `upgrade()` dropea `unit_measures.dimension` por cada schema de tenant; `downgrade()` la recrea y la recompone desde `unit_measure_groups.name`, siguiendo el patrón del downgrade de `8f1a2c4d6e9b_137_unit_measure_groups.py` (ver `data-model.md` §Migración)
- [x] T005 Quitar la columna `dimension` del modelo `UnitMeasure` en `../pos-backend/app/models/unit_measure.py` (línea ~37-39) y actualizar su docstring, que hoy documenta `dimension` como espejo de `group.name`
- [x] T006 Aplicar la migración en local (`alembic upgrade head`) y confirmar en Postgres que `unit_measures` ya no tiene la columna `dimension` en ningún schema de tenant

**Checkpoint**: el modelo y el esquema de BD ya no tienen `dimension` — a partir de aquí, todo
el código que aún la referencia está roto hasta que se completen las fases siguientes.

---

## Phase 3: User Story 1 - Renombrar un grupo de medida sin inconsistencias (Priority: P1) 🎯 MVP

**Goal**: renombrar un grupo de medida deja de requerir ninguna escritura de sincronización
sobre las unidades miembro, y la API deja de exponer el campo redundante.

**Independent Test**: renombrar un grupo vía `PATCH /unit-measure-groups/{id}` y confirmar que
la operación no toca ningún campo de las unidades miembro (ya no existe `dimension` que
sincronizar) y que `GET /unit-measures` no incluye un campo `dimension` en la respuesta.

### Implementation for User Story 1

- [x] T007 [US1] Quitar `UnitMeasureResponse.dimension` del schema de respuesta en `../pos-backend/app/api/v1/unit_measures/schemas.py` (línea ~42)
- [x] T008 [P] [US1] Quitar la escritura `dimension=group.name` al crear una unidad standalone en `../pos-backend/app/api/v1/unit_measures/router.py` (línea ~106)
- [x] T009 [P] [US1] Quitar la escritura `dimension=group.name` al crear un grupo + unidad base en `../pos-backend/app/api/v1/unit_measure_groups/router.py` (línea ~90)
- [x] T010 [P] [US1] Quitar la escritura `dimension=group.name` al agregar una unidad a un grupo existente en `../pos-backend/app/api/v1/unit_measure_groups/router.py` (línea ~125)
- [x] T011 [US1] Quitar el loop de sincronización `for unit in group.units: unit.dimension = body.name` del endpoint de renombrado de grupo en `../pos-backend/app/api/v1/unit_measure_groups/router.py` (líneas ~139-160)
- [x] T012 [US1] Actualizar `UnitMeasure.dimension: string` y comentarios asociados en `../pos-heladeria/src/app/core/interfaces/unit-measure.interface.ts` (líneas 7-8, 21): quitar el campo

**Checkpoint**: renombrar un grupo ya no sincroniza nada adicional; la API y el frontend dejan
de exponer el campo redundante. User Story 1 queda verificable de forma independiente.

---

## Phase 4: User Story 2 - Conversión entre unidades sigue validando compatibilidad (Priority: P1)

**Goal**: `convert()` sigue rechazando conversiones entre unidades de grupos distintos y
acepta las del mismo grupo exactamente igual que antes, ahora comparando `group_id`.

**Independent Test**: ejecutar `app/scripts/test_purchase_unit_conversion.py` y los
characterization tests de `convert()`; confirmar que el comportamiento observable (qué
conversiones se aceptan/rechazan, mensaje de error) no cambia.

### Tests for User Story 2 ⚠️

> Actualizar estos tests PRIMERO y confirmar que fallan contra el `convert()` aún no migrado,
> antes de implementar el cambio (characterization tests protegidos, Principio III).

- [x] T013 [US2] Actualizar fixtures `SimpleNamespace(dimension=...)` en `../pos-backend/app/characterization_tests/test_core_units.py` (líneas ~27-28, 33-34, 43) para usar `group_id`/`group` en vez de `dimension`, y actualizar el assert del mensaje de error que hoy espera `"(masa)"`/`"(volumen)"` para que espere el nombre de grupo resuelto vía `group.name`
- [x] T014 [US2] Actualizar las construcciones `make_unit(self.db, ..., dimension="masa", ...)` en `../pos-backend/app/characterization_tests/test_core_units.py` (línea ~57-58) para pasar `group_id` en vez de `dimension`
- [x] T015 [US2] Invertir el assert `assertIn("dimension", UnitMeasure.__table__.columns.keys())` (línea ~62) a `assertNotIn`, documentando en el propio test que esta spec autoriza explícitamente el cambio (Principio III)

### Implementation for User Story 2

- [x] T016 [US2] Cambiar `app/core/units.py::convert()` en `../pos-backend/app/core/units.py` (líneas ~17-22) para comparar `from_unit.group_id != to_unit.group_id` en vez de `.dimension`, y usar `from_unit.group.name`/`to_unit.group.name` en el mensaje de error 422
- [x] T017 [US2] Actualizar `../pos-backend/app/scripts/test_purchase_unit_conversion.py` (líneas ~60-63): construir `UnitMeasure(..., group_id=..., ...)` en vez de `dimension=...`
- [x] T018 [US2] Ejecutar `pytest app/characterization_tests/test_core_units.py -v` en `../pos-backend` y confirmar que los tests actualizados en T013-T015 ahora pasan contra el `convert()` migrado

**Checkpoint**: la validación de compatibilidad entre unidades funciona igual que antes,
verificada por los characterization tests actualizados. User Story 2 queda verificable de
forma independiente.

---

## Phase 5: User Story 3 - Filtrar unidades de medida por grupo (Priority: P2)

**Goal**: el filtro de unidades de medida por grupo sigue funcionando vía `group_id`; el
filtro por nombre de dimensión (texto libre) deja de existir.

**Independent Test**: llamar `GET /unit-measures?group_id=<id>` y confirmar que devuelve el
mismo conjunto de unidades que antes se obtenía filtrando por `dimension`; confirmar que
`GET /unit-measures?dimension=...` ya no es un filtro reconocido (FR-004, FR-008 del spec).

### Implementation for User Story 3

- [x] T019 [US3] Quitar el query param `dimension` y su filtro `query.where(UnitMeasure.dimension == dimension)` en `../pos-backend/app/api/v1/unit_measures/router.py` (líneas ~40-43 y ~53-54)
- [x] T020 [US3] Actualizar las llamadas a `list_unit_measures(..., dimension=masa, ...)` en `../pos-backend/app/scripts/test_purchase_unit_conversion.py` (líneas ~188, 206) para filtrar por `group_id` en vez de `dimension`
- [x] T021 [P] [US3] Eliminar el método muerto `loadUnitMeasuresByDimension(dimension)` (sin llamadores) en `../pos-heladeria/src/app/core/services/unit-measure.service.ts` (líneas ~46-51) y limpiar el comentario de la línea ~77 que referencia `dimension`
- [x] T022 [US3] Actualizar `unitsForRow()` en `../pos-heladeria/src/app/modules/inventory/components/purchase-form.component.ts` (línea 251): cambiar `u.dimension === base.dimension` por `u.groupId === base.groupId` (único consumidor real en runtime del campo eliminado)

**Checkpoint**: el filtrado por grupo funciona igual que antes vía `group_id`; no queda ningún
rastro de `dimension` como filtro ni en backend ni en frontend. User Story 3 queda verificable
de forma independiente.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: verificación final de que no queda ninguna referencia al campo eliminado.

- [x] T023 [P] Ejecutar `npm run build` (o el comando de typecheck configurado) en `../pos-heladeria` y confirmar que compila sin errores
- [x] T024 Ejecutar `grep -rn "\.dimension\b" app/ --include="*.py"` en `../pos-backend` y `grep -rn "\.dimension\b" src/ --include="*.ts"` en `../pos-heladeria`; confirmar que no quedan referencias relacionadas con `UnitMeasure`/`unit_measures` (ignorar falsos positivos tipo "dimensionar"/"redimensionar")
- [x] T025 Ejecutar el flujo completo de `quickstart.md` (migración upgrade/downgrade/upgrade, tests, script de integración, build de frontend, prueba manual del formulario de compra) y confirmar todos los resultados esperados

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias — puede iniciar de inmediato.
- **Foundational (Phase 2)**: depende de Setup — BLOQUEA todas las historias de usuario; nada
  en las fases 3-5 puede ejecutarse (el código no corre) hasta que T004-T006 estén completas.
- **User Stories (Phase 3-5)**: todas dependen de Foundational. Dentro de cada fase, las tareas
  marcadas `[P]` tocan archivos distintos y pueden hacerse en paralelo; las no marcadas tienen
  una dependencia secuencial dentro de la misma fase (p. ej. T013-T015 antes de T016 en US2,
  porque los tests deben fallar primero contra el código viejo).
- **Polish (Phase 6)**: depende de que las tres historias de usuario estén completas.

### User Story Dependencies

- **US1 (P1)**: puede iniciar apenas termina Foundational. Sin dependencia de US2/US3.
- **US2 (P1)**: puede iniciar apenas termina Foundational, en paralelo con US1. Sin dependencia
  de US1/US3, salvo que comparte el mismo repositorio de tests (`test_core_units.py`) — si se
  trabajan en paralelo, coordinar para no pisar el mismo archivo.
- **US3 (P2)**: puede iniciar apenas termina Foundational. T020 depende conceptualmente de que
  T016 (US2) ya exista `group_id` como comparación válida, pero no bloquea técnicamente — ambos
  pueden implementarse en paralelo ya que `group_id` existe en el modelo desde la spec 137.

### Parallel Opportunities

- T001/T002 (ramas en ambos repos) en paralelo.
- Dentro de Foundational: T004 y T005 tocan archivos distintos y pueden iniciarse en paralelo,
  pero T006 (aplicar migración) depende de que T004 esté completa.
- Dentro de US1: T008, T009, T010 tocan el mismo archivo (`unit_measure_groups/router.py`) en
  puntos distintos — pueden hacerse en la misma sesión de edición sin bloquearse entre sí, pero
  no son estrictamente paralelizables por dos personas sobre el mismo archivo.
- US1, US2 y US3 pueden trabajarse en paralelo por personas distintas una vez completada
  Foundational, coordinando los archivos compartidos señalados arriba.

---

## Implementation Strategy

### MVP First (User Story 1 + User Story 2)

Ambas son P1: no hay una única historia "mínima" — el MVP real de esta spec es completar
Foundational + US1 + US2 (quitar el campo redundante de la API y migrar la validación de
`convert()`), que ya deja el sistema en un estado correcto y sin la deuda técnica original. US3
(el filtro por query param, ya cubierto por `group_id` desde la spec 137) es la limpieza final
de un camino que ya tenía alternativa funcionando.

### Incremental Delivery

1. Setup + Foundational → esquema y modelo sin `dimension` (el código aún no compila en los
   puntos de uso restantes, por diseño — ver nota de Organización arriba).
2. US1 + US2 en paralelo → API y validación de negocio correctas y verificadas.
3. US3 → limpieza del filtro de query y del frontend.
4. Polish → verificación cruzada de que no queda ningún rastro.

Dado que el cambio es una eliminación de columna (no una funcionalidad aditiva), las fases 2-5
deben completarse como una única entrega: el sistema no es desplegable en un estado intermedio
entre Foundational y el fin de la Fase 5, porque el código roto por Foundational solo vuelve a
compilar/correr al cerrar las tres historias de usuario.
