# Implementation Plan: Trazabilidad de kardex en la importación masiva de Excel de inventario

**Branch**: `feat/165-trazabilidad-kardex-importacion-excel-inventario` | **Date**: 2026-11-24 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/165-trazabilidad-kardex-importacion-excel-inventario/spec.md`

## Summary

La importación masiva de Excel de inventario (`POST /inventory/items/import`, specs
109/139/142) escribe `InventoryItem.current_stock` directamente —por `setattr` al
actualizar, o por el constructor al crear— sin pasar nunca por `record_movement`/
`apply_adjustment` (`app/inventory_engine/stock.py`, spec 005), el único mecanismo
documentado como legítimo para mutar stock. Esta spec cierra esa laguna **solo para el
Stock**: el cambio vive íntegramente en `validar_y_aplicar_fila()`
(`app/api/v1/inventory/import_.py:394-439`), la función que ya procesa cada fila de forma
independiente con su propio commit (spec 109). Se excluye `current_stock` de los campos que
`resolve_or_create_by_code()` sobrescribe directo, y en su lugar: al **crear** un insumo con
Stock > 0 se llama `record_movement(type="in", ...)`; al **actualizar** uno existente cuyo
Stock del Excel difiere del `current_stock` actual, se llama `apply_adjustment(signed_delta=
delta, ...)`. Ambas llamadas usan un motivo nuevo (`importacion_masiva`, séptimo motivo
canónico de RN-INV-13) y una referencia nueva (`reference_type="import_job"`,
`reference_id=job.id`) que extiende el catálogo ya existente de `app/core/
inventory_reasons.py`. `apply_adjustment()` se extiende con los parámetros `reference_type`/
`reference_id` (ya presentes en `record_movement`, ausentes aquí) para poder llevar esa
referencia; el rechazo de fila cuando el ajuste dejaría stock negativo (FR-006) reutiliza la
`InsufficientStockError` que `apply_adjustment()` ya lanza (spec 005), capturándola igual que
`validar_y_aplicar_fila()` ya captura `HTTPException` de `_apply_preferred_supplier()`
(`import_.py:389-391`). La columna Costo (`unit_cost`) no cambia: sigue siendo un campo
directo de `campos`, nunca un movimiento. Es un cambio exclusivo de `pos-backend`; no hay
cambios de esquema ni de `pos-heladeria` (la pantalla de kardex ya renderiza `reason`/`type`
como texto crudo, sin ningún mapa de etiquetas que actualizar).

## Technical Context

**Language/Version**: Python 3.14 (backend, FastAPI)

**Primary Dependencies**: FastAPI, SQLAlchemy 2.0, Pydantic 2 — sin dependencias nuevas

**Storage**: PostgreSQL 16, schema-per-tenant (schema `tenant`), vía SQLAlchemy ORM — sin
tablas, columnas ni `CheckConstraint` nuevos (ver data-model.md); `inventory_movements.reason`
sigue siendo texto libre a nivel de BD, por diseño (RN-INV-12)

**Testing**: `python -m unittest discover -s app/characterization_tests -p 'test_*.py' -v`
(SQLite en memoria, sin Postgres/Redis) para el catálogo de motivos
(`test_core_inventory_reasons.py`, protegido con prefijo `CONGELA`) y el motor de stock
(`test_inventory_stock.py`); `python -m app.scripts.test_inventory_bulk_excel` (requiere
Postgres local real, mismo patrón que spec 109) para los casos end-to-end de esta spec —
ver memoria `how-to-run-sibling-repo-tests` del asistente para el comando exacto del venv

**Target Platform**: Servidor Linux (API) — sin cambios de frontend (`pos-heladeria`
confirmado sin ningún mapa de etiquetas de `reason`/`reference_type` que actualizar; la
tabla de movimientos ya muestra el valor crudo con fallback a `—` solo cuando es `null`)

**Project Type**: Extensión interna de un flujo de servicio existente (import masivo de
Excel, spec 109) en un solo repo — sin pantalla, endpoint, tabla ni router nuevos

**Performance Goals**: sin cambios respecto al presupuesto ya vigente de spec 109 (cada
fila sigue procesándose y comiteándose de forma independiente); el costo adicional por fila
es, como máximo, una llamada más a `record_movement`/`apply_adjustment` (un `SELECT ... FOR
UPDATE` ya necesario para leer `current_stock` de forma segura, no una query extra
apreciable)

**Constraints**: cada fila sigue comiteando de forma independiente y sin bloquear el resto
del archivo (FR-006, invariante ya vigente de spec 109); ningún movimiento de magnitud cero
se registra (FR-002/FR-005); el ajuste nunca deja `current_stock` negativo —reutiliza la
invariante ya vigente de `apply_adjustment` (spec 005), no una nueva; `unit_cost` no pasa
por kardex (FR-009)

**Scale/Scope**: cuatro archivos de `pos-backend` —
`app/api/v1/inventory/import_.py` (`validar_y_aplicar_fila`),
`app/inventory_engine/stock.py` (`apply_adjustment`, + 2 parámetros opcionales),
`app/core/inventory_reasons.py` (+1 motivo, +1 referencia), y
`app/characterization_tests/test_core_inventory_reasons.py` (actualización explícita,
autorizada por A-165) — más la extensión del script de prueba de importación masiva; cero
tablas, cero columnas, cero endpoints nuevos

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principio I (nace de un spec)**: ✅ `specs/165-trazabilidad-kardex-importacion-excel-inventario/spec.md`
  existe, está aprobado, y cita explícitamente su origen (`analisis-falencias-inventario.md`
  §2.10) y su relación con los specs 005/109/139/142/163 que no reemplaza.
- **Principio II (comportamiento existente protegido)**: ✅ el cambio de comportamiento
  (stock de creación/actualización por Excel pasa a generar movimiento de kardex en vez de
  sobrescritura directa) ya está registrado como decisión de negocio en
  `specs/000-reconocimiento/registro-de-anomalias.md` entrada **A-165**, con quién (Deimer
  Hernandez, propietario), cuándo (2026-11-24) y qué funcionalidades afecta — exactamente lo
  que exige este principio, antes de implementar.
- **Principio III (characterization tests)**: ⚠️ ver Complexity Tracking —
  `app/characterization_tests/test_core_inventory_reasons.py` (prefijo `CONGELA`, congela
  RN-INV-13 con "seis motivos canónicos") se actualiza a siete motivos. Está explícitamente
  autorizado por la decisión A-165 (ya registrada) y el propio spec 165 (FR-007), que precisa
  RN-INV-13; la actualización debe citar A-165 en el mismo commit y no toca ningún otro
  comportamiento protegido (`ENTRADA_REASONS`/`SALIDA_REASONS` para los seis motivos
  existentes permanecen idénticos; solo se agrega una entrada nueva).
- **Principio IV (nuevos specs introducen comportamiento nuevo)**: ✅ exactamente el caso —
  el stock de creación/actualización por Excel pasa a tener trazabilidad de kardex que antes
  no existía.
- **Principio V (sin refactors oportunistas)**: ✅ el cambio se confina a
  `validar_y_aplicar_fila()` (la función que ya es dueña de aplicar cada fila, spec 109); no
  se toca `resolve_or_create_by_code()` (sigue siendo el "upsert genérico por código" que ya
  es, solo que esta spec deja de pasarle `current_stock`) ni ningún otro caller de
  `record_movement`/`apply_adjustment`. La única extensión de firma
  (`apply_adjustment(..., reference_type=None, reference_id=None)`) es la mínima necesaria
  para que el ajuste pueda referenciar el job — ver Complexity Tracking.
- **Principio VI (evolución incremental)**: ✅ un solo spec, un solo flujo de servicio
  modificado, sin mezclar con migraciones de datos, cambios de arquitectura ni refactors no
  relacionados.
- **Principio VII (datos históricos)**: ✅ no se toca ningún `InventoryMovement` ni ninguna
  factura ya existente; el cambio aplica únicamente hacia adelante, a filas de Excel
  procesadas después del despliegue.
- **Principio VIII (evolución del modelo de datos)**: ✅ N/A — no hay migración (ver
  data-model.md, "Sin migración"); `reference_type`/`reason` son texto libre ya existente,
  sin `CheckConstraint` que alterar (RN-INV-12).
- **Principio IX (dependencias nuevas)**: ✅ ninguna dependencia nueva.
- **Principio X (verificación obligatoria)**: ✅ se extiende
  `app/scripts/test_inventory_bulk_excel.py` (ya corre contra Postgres real, ya importa
  `procesar_archivo_importacion`/`InventoryImportJob`) con casos para FR-001 a FR-009 y los
  tres User Stories/Edge Cases del spec; se actualiza `test_core_inventory_reasons.py`
  (citando A-165); se re-ejecutan los characterization tests de `test_inventory_stock.py`
  para confirmar que `record_movement`/`apply_adjustment` no cambian su comportamiento para
  ningún otro caller.
- **Principio XI (negocio vs. técnico)**: ✅ la decisión de generar un ajuste (y no ignorar
  la columna o sobrescribir sin kardex) y de usar un motivo nuevo (y no reutilizar `ajuste`)
  es de negocio, ya registrada en A-165 con las alternativas consideradas; la decisión
  técnica de dónde insertar la llamada (`validar_y_aplicar_fila` vs. `resolve_or_create_by_code`)
  es de este plan (ver research.md D1).
- **Principio XIV/XV (ramas y commits)**: se seguirán al implementar
  (`feat/165-trazabilidad-kardex-importacion-excel-inventario`), fuera del alcance de este
  comando de planeación.

No hay violaciones sin justificar; la única entrada de Complexity Tracking está justificada
abajo.

## Project Structure

### Documentation (this feature)

```text
specs/165-trazabilidad-kardex-importacion-excel-inventario/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md         # Phase 1 output (/speckit-plan command)
├── quickstart.md         # Phase 1 output (/speckit-plan command)
├── contracts/            # Phase 1 output (/speckit-plan command)
│   └── import-kardex-delta.md
└── tasks.md              # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
../pos-backend/
├── app/
│   ├── api/v1/inventory/
│   │   └── import_.py                             # validar_y_aplicar_fila(): excluye current_stock
│   │                                               # de `campos`, llama record_movement/apply_adjustment
│   ├── inventory_engine/
│   │   └── stock.py                                # apply_adjustment(+reference_type, +reference_id)
│   ├── core/
│   │   └── inventory_reasons.py                    # +IMPORTACION_MASIVA, +REF_IMPORT_JOB
│   ├── characterization_tests/
│   │   └── test_core_inventory_reasons.py          # actualizado (CONGELA), cita A-165
│   └── scripts/
│       └── test_inventory_bulk_excel.py            # + casos nuevos (creación/actualización/rechazo)
└── (sin migraciones nuevas — ver data-model.md)

../pos-heladeria/
└── (sin cambios — ver Technical Context: sin mapa de etiquetas que actualizar)
```

**Structure Decision**: cambio confinado al módulo `inventory` de `pos-backend`; no se crea
ninguna pantalla, servicio, router ni tabla nueva, y `pos-heladeria` no requiere ningún
cambio porque ya renderiza `reason`/`type` de forma genérica.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Extender la firma de `apply_adjustment()` con `reference_type`/`reference_id` opcionales | FR-004 exige que el ajuste generado por la importación quede referenciado al job (`reference_type="import_job"`, `reference_id=job.id`); `apply_adjustment()` hoy no acepta esos parámetros (solo `record_movement()` los tiene) | Setear `reference_type`/`reference_id` a mano sobre el `InventoryMovement` devuelto, después de llamarla — rechazada: duplica la responsabilidad de escribir esos campos fuera de la función que ya es la única dueña de crear movimientos `adjustment`, y cualquier otro caller futuro de un ajuste con referencia tendría que repetir el mismo parche en vez de usar el parámetro ya expuesto por `record_movement()` |
| Actualizar el characterization test `test_core_inventory_reasons.py` (prefijo `CONGELA`) | FR-007 extiende RN-INV-13 de seis a siete motivos canónicos — el test protegido queda en rojo si no se actualiza, y la decisión que lo autoriza (A-165) ya está registrada en `registro-de-anomalias.md` antes de este cambio, como exige Principio III | Dejar el test en rojo o ignorarlo — rechazada: un test `CONGELA` en rojo sin actualización explícita que cite la decisión se considera una regresión según el propio Principio III, no una opción válida |
