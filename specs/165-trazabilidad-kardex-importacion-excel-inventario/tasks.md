---

description: "Task list for feature 165: trazabilidad de kardex en la importación masiva de Excel de inventario"
---

# Tasks: Trazabilidad de kardex en la importación masiva de Excel de inventario

**Input**: Design documents from `/specs/165-trazabilidad-kardex-importacion-excel-inventario/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/import-kardex-delta.md, quickstart.md

**Tests**: no se usa pytest en este repo; la verificación es vía characterization tests (`unittest`) y el script ejecutable contra Postgres real (`app/scripts/test_inventory_bulk_excel.py`), ambos ya existentes y extendidos por las tareas de Polish — consistente con Principio X y D9 de research.md. No se crea ningún framework de test nuevo.

**Organization**: todo el trabajo vive en `pos-backend`; no hay fases por repositorio porque `pos-heladeria` no cambia (D8). Las fases siguen a los User Stories del spec (US1/US2/US3), cada una con su Independent Test tal como lo define spec.md.

## Path Conventions

Repo único afectado: `../pos-backend/` (relativo a `pos-specs/`). Todas las rutas de archivo abajo son relativas a `pos-backend/`.

---

## Phase 1: Setup

No aplica — no hay dependencias nuevas, no hay estructura de proyecto nueva que crear (Technical Context: "sin dependencias nuevas"; Scale/Scope: cuatro archivos existentes modificados, cero archivos nuevos de producción).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: extender el catálogo de motivos/referencias y la firma de `apply_adjustment()` — ambos son prerequisito compartido de US1 y US2, ninguna historia puede implementarse sin ellos.

**⚠️ CRITICAL**: completar esta fase antes de tocar `import_.py` (Phase 3+).

- [X] T001 Agregar las constantes `IMPORTACION_MASIVA = "importacion_masiva"` y `REF_IMPORT_JOB = "import_job"` en `app/core/inventory_reasons.py`, e incluir `IMPORTACION_MASIVA` en `ENTRADA_REASONS` (queda `(COMPRA, AJUSTE, IMPORTACION_MASIVA)`); `SALIDA_REASONS` no cambia (data-model.md, D2)
- [X] T002 Extender `apply_adjustment()` en `app/inventory_engine/stock.py` (línea ~109) con los parámetros opcionales `reference_type: Optional[str] = None` y `reference_id: Optional[UUID] = None`, pasándolos al `InventoryMovement` construido al final de la función — mismo patrón que ya usa `record_movement()` en el mismo archivo (data-model.md, D3); no modificar ningún otro parámetro ni comportamiento existente de la función

**Checkpoint**: catálogo y motor de stock listos — US1 y US2 pueden implementarse en paralelo a partir de aquí (ambas tocan el mismo archivo `import_.py`, así que en la práctica se implementan en secuencia dentro de esa función, pero no tienen dependencia de orden entre sí).

---

## Phase 3: User Story 1 - Stock inicial de un insumo nuevo creado por Excel (Priority: P1) 🎯 MVP

**Goal**: al crear un insumo nuevo vía importación masiva con Stock > 0, el stock inicial queda registrado como un movimiento `in` de kardex (en vez de escribirse directo por el constructor), referenciado al job de importación; con Stock = 0 no se genera ningún movimiento.

**Independent Test**: importar un Excel con un insumo de código no existente y Stock = 50; verificar que el insumo queda creado con `current_stock = 50` y que existe un movimiento de kardex tipo `in`, cantidad 50, motivo `importacion_masiva`, referenciado al job de importación. Repetir con Stock = 0 y verificar que no se genera movimiento.

### Implementation for User Story 1

- [X] T003 [US1] En `validar_y_aplicar_fila()` (`app/api/v1/inventory/import_.py:394-439`), cambiar la firma a `validar_y_aplicar_fila(db: Session, fila: list[Any], job) -> dict` para poder referenciar `job.id`; quitar `current_stock=stock` del diccionario `campos` (el insumo nace con el default `0` del modelo tanto en creación como en actualización)
- [X] T004 [US1] En la misma función, inmediatamente después de `item, creado = service.resolve_or_create_by_code(db, code, **campos)`: si `creado` es `True` y `stock > 0`, llamar `stock_engine.record_movement(db, item.id, type="in", quantity=stock, reason=reasons.IMPORTACION_MASIVA, reference_type=reasons.REF_IMPORT_JOB, reference_id=job.id)`; si `creado` es `True` y `stock == 0`, no llamar nada (FR-002); agregar los imports necesarios (`app.inventory_engine.stock` como `stock_engine`, `app.core.inventory_reasons` como `reasons`) al encabezado de `import_.py`
- [X] T005 [US1] Actualizar la única llamada a `validar_y_aplicar_fila(db, fila)` dentro de `procesar_archivo_importacion()` (`app/api/v1/inventory/import_.py`, dentro del loop principal) para pasar `job` como tercer argumento: `validar_y_aplicar_fila(db, fila, job)`

**Checkpoint**: User Story 1 es funcional y testeable de forma independiente (creación con Stock > 0 genera movimiento `in`; creación con Stock = 0 no genera nada) — la actualización de insumos existentes (US2) aún no genera ajuste en este punto, pero tampoco regresiona porque `current_stock` del insumo existente no se toca hasta Phase 4.

---

## Phase 4: User Story 2 - Ajuste de stock al actualizar un insumo existente por Excel (Priority: P1)

**Goal**: al actualizar un insumo existente vía importación masiva cuyo Stock del Excel difiere del `current_stock` actual, la diferencia queda registrada como un ajuste de kardex (`apply_adjustment`), referenciado al job; sin cambio de Stock no se genera ningún movimiento.

**Independent Test**: con un insumo existente con `current_stock = 30`, importar un Excel con el mismo código y Stock = 45; verificar que el stock resultante es 45 y que existe un movimiento `ajuste` de +15, motivo `importacion_masiva`, referenciado al job. Repetir con Stock = 30 (sin cambio) y verificar que no se genera movimiento; repetir con Stock = 10 y verificar ajuste de -20.

### Implementation for User Story 2

- [X] T006 [US2] En `validar_y_aplicar_fila()`, antes de llamar a `resolve_or_create_by_code()`, capturar `stock_antes = existente.current_stock if existente is not None else None` (usando la variable `existente` ya resuelta por código en esa misma función)
- [X] T007 [US2] Inmediatamente después del bloque de T004 (manejo de creación), agregar el bloque de actualización: si `creado` es `False`, calcular `delta = stock - stock_antes`; si `delta != 0`, llamar `stock_engine.apply_adjustment(db, item.id, signed_delta=delta, reason=reasons.IMPORTACION_MASIVA, reference_type=reasons.REF_IMPORT_JOB, reference_id=job.id)`; si `delta == 0`, no llamar nada (FR-005)

**Checkpoint**: User Stories 1 y 2 funcionan de forma independiente y conjunta — creación y actualización por Excel ya generan kardex correctamente para los casos de delta ≠ 0 y delta = 0.

---

## Phase 5: User Story 3 - Fila rechazada cuando el ajuste dejaría stock negativo (Priority: P2)

**Goal**: si el ajuste calculado en US2 dejaría el stock resultante en negativo, la fila se rechaza individualmente (reportada como fallida en `job.errors[]`), sin modificar el insumo y sin bloquear el resto del job.

**Independent Test**: con un insumo existente con `current_stock = 5`, importar un Excel con el mismo código y un Stock tal que el ajuste resultante sea negativo; verificar que la fila se reporta como fallida en el resumen de errores del job, el stock del insumo no cambia, y las demás filas del Excel se procesan con normalidad.

### Implementation for User Story 3

- [X] T008 [US3] En `validar_y_aplicar_fila()`, ampliar el `try/except` que envuelve el cuerpo de la función (actualmente `except ValueError`, línea ~437) para capturar también `HTTPException` — mismo patrón que ya usa `_apply_preferred_supplier()` en la línea 387-391 de `import_.py` — de forma que `InsufficientStockError` (lanzada por `apply_adjustment()` en T007 cuando `new_stock < 0`, que es una `HTTPException` según `app/core/exceptions.py:12`) se convierta en `{"ok": False, "accion": None, "motivo": str(exc.detail)}` igual que cualquier otro error de fila; hacer `db.rollback()` en ese `except` igual que en el `except ValueError` existente, para que `current_stock` quede sin modificar

**Checkpoint**: las tres historias de usuario del spec están completas e integradas — el flujo de importación masiva nunca vuelve a escribir `current_stock` directo, siempre pasa por kardex, y el stock nunca queda negativo por esta vía.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: verificación obligatoria (Principio X) y actualización del characterization test afectado por el nuevo motivo canónico (Principio III, autorizado por A-165).

- [X] T009 [P] Actualizar `app/characterization_tests/test_core_inventory_reasons.py` para reflejar el séptimo motivo canónico: agregar aserciones para `r.IMPORTACION_MASIVA == "importacion_masiva"` y `r.REF_IMPORT_JOB == "import_job"`; actualizar `test_rn_inv_13_catalogo_completo_de_entrada_y_salida` para que `set(r.ENTRADA_REASONS) == {"compra", "ajuste", "importacion_masiva"}` (sin cambios en `SALIDA_REASONS`); agregar comentario citando la decisión **A-165** (`registro-de-anomalias.md`) junto al cambio, como exige Principio III
- [X] T010 Extender `app/scripts/test_inventory_bulk_excel.py` con un caso para US1/Escenario 1 (quickstart.md): importar fila de código nuevo con Stock = 50, verificar `current_stock == 50` y un `InventoryMovement` con `type="in"`, `quantity=50`, `reason="importacion_masiva"`, `reference_type="import_job"`, `reference_id=job.id`
- [X] T011 Extender el mismo script con el caso US1/Escenario 2: fila de código nuevo con Stock = 0, verificar `current_stock == 0` y **cero** movimientos nuevos para ese insumo
- [X] T012 Extender el mismo script con los casos US2/Escenarios 3-4: insumo existente con `current_stock = 30`, actualizar con Stock = 45 (verificar ajuste +15, `current_stock == 45`), luego con Stock = 10 sobre ese mismo insumo (verificar ajuste -20, `current_stock == 10`), y finalmente reimportar con Stock = 10 sin cambio (verificar que no se agrega ningún movimiento nuevo)
- [X] T013 Extender el mismo script con el caso US3/Escenario 5: insumo con `current_stock = 5`, Excel con dos filas — la primera con un delta que dejaría el stock negativo, la segunda con un código distinto válido; verificar que `job.errors[]` incluye una entrada para la primera fila con `motivo` conteniendo "dejaría el stock" y "en negativo", que el `current_stock` del primer insumo sigue en 5 sin movimiento nuevo, y que la segunda fila se procesó con normalidad (`created_count` o `updated_count` la refleja)
- [X] T014 [P] Extender el mismo script con el caso de Escenario 6 (FR-009): repetir cualquiera de los casos anteriores con una fila que además traiga un valor de Costo distinto; verificar que `unit_cost` queda igual al valor de la fila (sobrescritura directa, sin cambios) y que el único `InventoryMovement` generado por esa fila (si lo hay) es el de Stock, nunca uno relacionado con costo
- [X] T015 Ejecutar `python -m unittest discover -s app/characterization_tests -p 'test_*.py' -v` (venv del repo, ver memoria `how-to-run-sibling-repo-tests`) y confirmar que `test_core_inventory_reasons.py` (T009) y `test_inventory_stock.py` quedan en verde, este último sin cambios de comportamiento para ningún otro caller de `record_movement`/`apply_adjustment`
- [X] T016 Ejecutar `python -m app.scripts.test_inventory_bulk_excel` contra Postgres local (ver memoria `how-to-run-sibling-repo-tests` para el comando exacto) y confirmar que todos los casos nuevos (T010-T014) y los ya existentes de spec 109/138 pasan
- [X] T017 Validar manualmente los seis escenarios de `quickstart.md` contra una instancia corriendo de `pos-backend` (`POST /inventory/items/import`, `GET /inventory/items/import/{job_id}`, `GET /inventory/items/{id}/movements`), confirmando el contrato documentado en `contracts/import-kardex-delta.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Foundational (Phase 2)**: sin dependencias — bloquea Phase 3, 4 y 5 (todas necesitan `reasons.IMPORTACION_MASIVA`/`REF_IMPORT_JOB` de T001 y la firma extendida de `apply_adjustment()` de T002)
- **US1 (Phase 3)**: depende de Phase 2 — independiente de US2/US3 en términos de lógica de negocio, aunque comparte el mismo archivo/función
- **US2 (Phase 4)**: depende de Phase 2 — no depende de US1 funcionalmente, pero T006/T007 se insertan en la misma función ya tocada por T003/T004 (ver Notes sobre mismo archivo)
- **US3 (Phase 5)**: depende de que exista la llamada a `apply_adjustment()` de US2 (T007) — sin ajuste no hay nada que pueda fallar por stock negativo
- **Polish (Phase 6)**: depende de Phase 3, 4 y 5 completas

### Dentro de cada fase

- T001 y T002 no tienen dependencia entre sí (archivos distintos) pero ambos deben completarse antes de T003
- T003 → T004 → T005 (mismo archivo, cambios secuenciales sobre la misma función y su único caller)
- T006 → T007 (T007 usa `stock_antes` capturado en T006)
- T008 depende de que T007 ya lance `InsufficientStockError` para tener algo que capturar
- T009 es independiente de T010-T014 (archivos distintos) pero todas antes de T015/T016
- T010-T013 son secuenciales dentro del mismo script si comparten el mismo insumo de prueba (ver quickstart.md: Escenario 4 depende del estado dejado por Escenario 3); T014 es independiente (usa su propio caso)

### Parallel Opportunities

- T001 [P] y T002 [P] (Phase 2): archivos distintos (`inventory_reasons.py` vs `stock.py`), sin dependencia entre sí
- T009 [P] (Phase 6): archivo distinto a T010-T014, puede hacerse en paralelo con la extensión del script
- T014 [P] (Phase 6): caso independiente de los demás casos del script, puede escribirse en paralelo

**Nota sobre "mismo archivo"**: a diferencia del caso general, T003-T008 modifican todos la misma función (`validar_y_aplicar_fila()`) en el mismo archivo (`import_.py`) — no son candidatas reales a paralelismo entre sí aunque pertenezcan a historias de usuario distintas (US1/US2/US3), porque cada tarea depende del estado que deja la anterior sobre esa función. El paralelismo de este feature es limitado por diseño (Scale/Scope: cuatro archivos, cambio concentrado).

---

## Parallel Example: Phase 2 (Foundational)

```bash
# T001 y T002 pueden hacerse en paralelo (archivos distintos):
Task: "Agregar IMPORTACION_MASIVA/REF_IMPORT_JOB en app/core/inventory_reasons.py"
Task: "Extender apply_adjustment() con reference_type/reference_id en app/inventory_engine/stock.py"
```

## Parallel Example: Phase 6 (Polish)

```bash
# T009 puede hacerse en paralelo con el inicio de T010-T014 (archivos distintos):
Task: "Actualizar test_core_inventory_reasons.py citando A-165"
Task: "Extender test_inventory_bulk_excel.py con el caso US1/Escenario 1"
```

---

## Implementation Strategy

### MVP First (User Story 1 solamente)

1. Completar Phase 2: Foundational (T001-T002) — bloqueante
2. Completar Phase 3: User Story 1 (T003-T005)
3. **STOP and VALIDATE**: ejecutar el Independent Test de US1 manualmente (crear insumo nuevo con Stock > 0 por Excel, confirmar movimiento `in`) antes de continuar
4. US2 y US3 son necesarias para que el spec esté completo — el "MVP" de US1 por sí solo no cierra la laguna de actualización que motivó la spec (ver "Why this priority" de US2: "es el caso de la laguna original detectada"), así que no se recomienda desplegar solo con US1 en producción, aunque sí es un punto de validación intermedio útil

### Incremental Delivery

1. Foundational (T001-T002) → listo para empezar las historias
2. US1 (T003-T005) → validar creación con stock inicial trazable
3. US2 (T006-T007) → validar actualización con ajuste trazable (cierra la laguna original del spec)
4. US3 (T008) → validar que el rechazo por stock negativo no rompe el resto del job
5. Polish (T009-T017) → characterization test actualizado + script extendido + verificación manual contra quickstart.md

### Alcance final

Al completar T001-T017, la importación masiva de Excel de inventario (specs 109/139/142) deja de escribir `current_stock` directo en cualquier camino (creación o actualización), pasando siempre por `record_movement`/`apply_adjustment` (spec 005); `unit_cost` permanece sin cambios (FR-009, fuera de alcance por diseño). No hay cambios de esquema, endpoint, ni frontend (`pos-heladeria`).
