# Research: Simplificar columnas de proveedor en Excel de inventario

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

Todas las incertidumbres de la sección "Technical Context" del plan se resuelven aquí contra el
código real de `pos-backend` (hallazgos confirmados por exploración directa del repositorio).

## 1. Dónde vive el contrato de columnas hoy

**Decisión**: el contrato único de columnas es `INVENTORY_TEMPLATE_HEADERS` en
`app/api/v1/inventory/schemas.py` (líneas 19-31). Export (`export.py`) e import (`import_.py`)
ya comparten esta constante — no hay duplicación de la lista de encabezados en otro lugar
(confirmado también que el frontend Angular no duplica esta lista; solo descarga/sube el archivo
sin parsear columnas).

**Acción**: remover `Proveedor preferido`, `Presentación`, `Factor de conversión`, `Último costo`
de esa constante y de los índices de columna en `import_.py` (`_CODE.._LAST_COST`), y de las
celdas que `build_inventory_excel` escribe en `export.py`.

**Alternativas consideradas**: mantener las columnas en el archivo pero vacías/no editables —
rechazada porque la Historia 1 pide explícitamente que el archivo "ya no incluya" esas columnas
(FR-001/FR-002), no que las incluya deshabilitadas.

## 2. Compatibilidad hacia atrás con archivos que aún traen las 3 columnas (FR-003)

**Decisión**: `validar_estructura()` en `import_.py` (líneas 36-54) hace hoy una validación
exacta de encabezados/orden (FR-005 de la spec 109). Tras el cambio, esa función debe aceptar
tanto el encabezado nuevo (sin las 3 columnas) como el antiguo (con ellas, en su posición
original al final), ignorando su contenido si están presentes. Las columnas de proveedor nunca
se leen más allá de detectar su presencia para seguir aceptando el archivo.

**Acción**: eliminar toda lectura de `Presentación` / `Factor de conversión` / `Último costo` /
`Proveedor preferido` en el cuerpo de `procesar_archivo_importacion` / `validar_y_aplicar_fila` —
incluye eliminar por completo la llamada a `_apply_preferred_supplier` (líneas 146-197) del flujo
de importación, ya que FR-004 prohíbe que la importación cree, modifique o elimine esos datos
bajo cualquier circunstancia. `_apply_preferred_supplier` y `_resolve_supplier` dejan de invocarse
desde el import; se evalúa si quedan como código muerto a remover o si se conservan por si otro
flujo los usa (no se encontró otro llamador en la exploración — se eliminan como parte de esta
spec, Principio V: no dejar código muerto que simule una funcionalidad retirada).

**Alternativas consideradas**: rechazar archivos legados con error de estructura — rechazada
explícitamente por FR-003 ("no rechazarlos por estructura").

## 3. Cómo se vincula/crea la unidad de medida desde la columna unidad (FR-006, FR-008, FR-009)

**Hallazgo**: `_resolve_unit()` en `import_.py` (líneas 69-102) **ya implementa** la mayor parte
de este comportamiento: normaliza el texto, compara sin distinguir mayúsculas/minúsculas contra
`UnitMeasure.abbreviation` (vía `func.upper(...)`), y si ninguna coincide, crea una
`UnitMeasure` nueva. La columna `Unidad` del Excel ya contiene la **abreviatura** de la unidad
(confirmado en `export.py`, que escribe `unit.abbreviation`), no su nombre completo — por lo
tanto "comparar por nombre" en el lenguaje de la spec se traduce, en el modelo de datos real, a
comparar por `abbreviation`, continuando el comportamiento ya exportado/importado hoy. Se
mantiene esta columna como abreviatura (consistencia con FR-005: "tal como existe hoy").

**Gap confirmado que esta spec debe cerrar**: la creación automática actual
(`UnitMeasure(name=normalizado, abbreviation=normalizado)`, línea ~98) **no asigna `group_id`**,
pero `UnitMeasure.group_id` es `NOT NULL` con FK a `unit_measure_groups` desde la migración de la
spec 137 (`app/models/unit_measure.py:47-49`). Contra Postgres real esto lanza `IntegrityError` en
el `flush()` — es decir, hoy la creación automática de unidades nuevas por importación está rota
para cualquier negocio que ya migró a unidades de medida estructuradas (spec 137). Esta spec
corrige ese gap como parte de FR-006.

**Decisión**: al crear la unidad automáticamente, replicar exactamente el patrón ya usado por
`create_unit_measure_group()` en `app/api/v1/unit_measure_groups/router.py` (líneas 75-98):
1. Crear `UnitMeasureGroup(name=normalizado)`, `flush()` para obtener su `id`.
2. Crear `UnitMeasure(name=normalizado, abbreviation=normalizado, group_id=group.id,
   is_base=True, factor_to_base=1, dimension=group.name, active=True)`.

Esto coincide con la Aclaración previa #1 de la spec ("se crea como grupo propio nuevo, siendo
ella misma la unidad base de ese grupo, factor 1") y con el criterio de unicidad existente
(`uq__unit_measures__group_id__is_base_true` — una sola unidad base por grupo, que aquí se
satisface trivialmente porque el grupo es nuevo).

**FR-008** (dos unidades existentes empatan sin distinguir mayúsculas/minúsculas): `_resolve_unit`
actualmente no contempla el caso de ambigüedad entre dos filas de `UnitMeasure` activas que
coincidan por `abbreviation` normalizada (debería ser imposible si `abbreviation` tiene índice
único real en BD, pero la unicidad en `app/core/crud.py::ensure_unique` no es case-insensitive —
confirmado en la exploración —, así que dos abreviaturas como `"Gal"` y `"GAL"` sí pueden coexistir
hoy). Se añade una comprobación explícita: si la consulta case-insensitive devuelve más de una
fila, la fila se reporta como fallida (mismo criterio que FR-006a de la spec 109 para
unidades/proveedores, ya implementado de forma análoga en `_resolve_supplier`).

**FR-009** (columna unidad vacía al crear): ya debe estar cubierto por la validación genérica de
campos obligatorios de la spec 109 (unidad es requerida igual que código/nombre/tipo); se verifica
en implementación que `_resolve_unit` reciba cadena vacía y la reporte como campo faltante en vez
de intentar crear una `UnitMeasure` con nombre vacío.

**Alternativas consideradas**: comparar por `UnitMeasure.name` en vez de `abbreviation` —
rechazada porque rompería la continuidad con lo que el export ya escribe en esa columna hoy
(`abbreviation`), y obligaría a cambiar qué valor se exporta en la columna Unidad, algo que FR-005
prohíbe explícitamente ("tal como existe hoy").

## 4. La unidad no cambia al actualizar un insumo existente (FR-007)

**Hallazgo**: `resolve_or_create_by_code()` en `app/api/v1/inventory/service.py` (líneas 127-164)
es el upsert compartido por creación manual e importación. Se debe confirmar en implementación si
hoy sobrescribe `unit_measure_id` también en la rama de actualización (comportamiento probable,
dado que recibe `**fields` genéricos). Si es así, constituye el comportamiento que FR-007 exige
corregir.

**Decisión**: en el flujo de importación (`import_.py`), al detectar que la fila actualiza un
insumo ya existente (coincide por código), **no pasar `unit_measure_id` resuelto** a
`resolve_or_create_by_code` para esa fila — ni siquiera llamar a `_resolve_unit` para esa fila,
ya que FR-007 (caso 3) exige que tampoco se cree una unidad de medida nueva por una fila de
actualización, aunque el texto no exista todavía como unidad. Esto evita por completo el efecto
secundario de creación de unidades en el camino de actualización, no solo el de reasignación.

**Alternativas consideradas**: resolver la unidad siempre pero descartar el resultado solo al
persistir — rechazada porque violaría el caso 3 de la Historia 3 (no debe crearse ninguna unidad
nueva por una fila de actualización).

## 5. Convenciones de pruebas del repositorio (sin pytest)

**Hallazgo**: `pos-backend` no usa pytest; las pruebas son `unittest` puro, ejecutadas con
`python -m unittest discover -s app/characterization_tests -p 'test_*.py' -v`, usando SQLite en
memoria (`app/characterization_tests/test_inventory_export.py`) o, para un caso, un script
independiente contra Postgres real (`app/scripts/test_inventory_bulk_excel.py`). No existe
`pytest.ini` ni `conftest.py`.

**Decisión**: las pruebas de esta funcionalidad siguen el mismo patrón: `unittest.TestCase` en
`app/characterization_tests/`, reutilizando los factories de `app/characterization_tests/fixtures.py`
(`make_unit`, `make_inventory_item`, `make_supplier`, `make_supplier_item`) en vez de duplicar
factories locales como hace hoy `test_inventory_export.py`. El caso del gap de `group_id` (NOT
NULL contra Postgres real) se verifica explícitamente contra Postgres local disponible, siguiendo
`[[how-to-run-sibling-repo-tests]]` — SQLite en memoria no lo habría detectado porque no aplica la
restricción NOT NULL de la misma forma.

## 6. Alcance frontend

**Decisión confirmada por exploración**: cambio exclusivamente de `pos-backend`. El frontend
Angular (`pos-heladeria`) no duplica la lista de columnas ni la lógica de creación de unidades;
solo sube/descarga el archivo y muestra el resumen del job de importación. No se requiere ningún
cambio en `pos-heladeria` para esta spec.
