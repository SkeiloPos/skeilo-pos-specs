# Research: Eliminar columna `dimension` en unidades de medida

No quedaron `NEEDS CLARIFICATION` en el Technical Context del plan: el contexto técnico
(lenguaje, dependencias, almacenamiento, testing) ya estaba completamente determinado por el
código existente en `pos-backend` y `pos-heladeria`, verificado directamente en la exploración
previa a esta spec. Este documento registra las decisiones de diseño tomadas para cerrar la
deuda técnica, no investigación de tecnologías nuevas.

## D1 — Cómo valida `convert()` la compatibilidad entre unidades

**Decisión**: `app/core/units.py::convert()` deja de comparar `from_unit.dimension !=
to_unit.dimension` y pasa a comparar `from_unit.group_id != to_unit.group_id`. El mensaje de
error 422 sigue identificando los grupos por nombre, usando `from_unit.group.name` /
`to_unit.group.name` en vez de `from_unit.dimension` / `to_unit.dimension`.

**Rationale**: `group_id` es ya la fuente de verdad desde la spec 137; comparar por FK es
además más barato que comparar strings y no depende de que el mirror esté sincronizado.

**Alternativas consideradas**:
- Mantener la comparación por `.dimension` hasta una spec futura — rechazada: es exactamente
  la deuda técnica que esta spec existe para cerrar; postergarla otra vez no tiene causa nueva.
- Comparar `from_unit.group.name != to_unit.group.name` en vez de `group_id` — rechazada:
  obliga a cargar la relación `group` para la comparación (no solo para el mensaje de error),
  y compara por valor en vez de por identidad relacional sin ganar nada a cambio.

**Nota de compatibilidad**: `convert()` es duck-typed en los characterization tests (recibe
`SimpleNamespace` en vez de instancias reales de `UnitMeasure` en algunos tests). El cambio de
`.dimension` a `.group_id` debe reflejarse también en esos fixtures duck-typed, no solo en el
modelo real.

## D2 — Alcance de la eliminación del campo/filtro `dimension` en la API

**Decisión**: se elimina `UnitMeasureResponse.dimension` de la respuesta de `GET
/unit-measures` y el query param `?dimension=` del mismo endpoint, **sin** ofrecer un
reemplazo por nombre de texto. El filtro equivalente por `group_id` ya existe desde la spec
137 y se mantiene sin cambios.

**Rationale**: mantener un filtro por nombre de texto reintroduce exactamente el problema que
esta spec elimina (una segunda forma de referirse al grupo, esta vez en la capa de API en vez
de en la capa de datos). El único consumidor interno real (`purchase-form.component.ts` en
pos-heladeria) no usa el filtro por query param, solo el campo de respuesta — se actualiza
como parte de esta spec.

**Alternativas consideradas**:
- Mantener `?dimension=<nombre_de_grupo>` como alias de `?group_id=` resuelto por nombre —
  rechazada: añade una resolución nombre→id en el router sin necesidad de negocio que la
  justifique (viola el Principio V, que pide no justificar trabajo técnico adicional dentro de
  una funcionalidad que no lo requiere).
- Deprecar con aviso pero no eliminar en esta spec — rechazada: no hay consumidores externos
  conocidos (ver Assumptions del spec) que requieran un período de transición, y la propia
  spec 137 ya documentó esta eliminación como pendiente.

## D3 — Estrategia de migración y rollback

**Decisión**: una única migración Alembic nueva (`139_remove_unit_measure_dimension`) cuyo
`upgrade()` elimina la columna `dimension` de `unit_measures`, y cuyo `downgrade()` la
recrea y la recompone leyendo `group.name` para cada unidad — replicando exactamente el patrón
que ya usa el `downgrade()` de la migración 137
(`8f1a2c4d6e9b_137_unit_measure_groups.py`, líneas 180-196) al recomponer `dimension` desde el
grupo antes de dropear `group_id`.

**Rationale**: Principio VIII exige estrategia de rollback explícita para toda evolución del
modelo de datos; replicar el patrón ya usado y probado en la migración 137 minimiza el riesgo
de introducir un camino de rollback nuevo y no probado.

**Alternativas consideradas**:
- Downgrade que deja `dimension` en `NULL` o con un valor por defecto fijo — rechazada: un
  entorno revertido quedaría en un estado peor que el anterior al cambio (columna presente
  pero con datos incorrectos), violando el espíritu del Principio VIII de que una migración no
  debe alterar el significado histórico de los datos.
- No soportar downgrade — rechazada: la migración 137 sí lo soporta para el mismo tipo de
  cambio; no hacerlo aquí sería inconsistente sin una razón técnica nueva.

## D4 — Registro de decisión de negocio (Principio II)

**Decisión**: esta spec **no** requiere una entrada nueva en
`specs/000-reconocimiento/registro-de-anomalias.md`.

**Rationale**: el comportamiento de negocio observable — qué conversiones de unidades son
válidas, qué mensaje recibe el usuario ante una conversión incompatible, qué resultado produce
una conversión válida — no cambia (ver User Story 2 del spec). Lo único que se retira es un
campo de API y un filtro de búsqueda que la propia spec 137
(`specs/137-rediseno-ajustes/research.md`, decisión D2) ya dejó documentado como "deuda
técnica aceptada... para una futura spec de limpieza". Esta spec ejecuta esa decisión ya
tomada; no introduce una decisión de negocio nueva que requiera autorización adicional.

**Alternativas consideradas**:
- Registrar de todas formas una entrada nueva por tratarse de un breaking change de API —
  descartada como innecesaria: el registro de anomalías está reservado a decisiones de negocio
  sobre comportamiento del sistema, no a cambios de forma de una API interna sin consumidores
  externos conocidos; mantener la trazabilidad hacia la decisión original de la spec 137 (vía
  esta sección y el propio spec.md) cumple el Principio XII sin sobrecargar el registro con
  cambios puramente técnicos.
