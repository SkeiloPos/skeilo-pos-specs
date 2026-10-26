# Research: Rediseño visual de Ajustes + grupos de unidades de medida

**Spec**: `specs/137-rediseno-ajustes/spec.md` | **Fecha**: 2026-10-26

Todas las incógnitas de negocio de este spec ya quedaron resueltas en la sección
`## Clarifications` del propio spec (sesión 2026-10-26). Este documento cubre las
decisiones **técnicas** necesarias para implementar lo ya decidido, que no requerían
pregunta al usuario por tratarse de criterio de implementación (Principio XI).

## D1 — Cómo representar "unidad base" en el modelo de datos

- **Decisión**: Añadir una columna `is_base: bool` en `UnitMeasure` (no inferirla desde
  `factor_to_base == 1`), más una FK `group_id` hacia la nueva tabla `unit_measure_groups`.
  Un `CheckConstraint`/índice único parcial garantiza "exactamente una unidad base por
  grupo" (`UNIQUE (group_id) WHERE is_base = true`, patrón ya soportado por PostgreSQL 16).
- **Rationale**: FR-007 exige "exactamente una unidad como base por grupo en todo
  momento" — una bandera explícita con constraint a nivel de base de datos hace esa
  invariante imposible de violar incluso por un bug de aplicación o un script directo, en
  vez de depender de que `factor_to_base == 1` sea siempre único (que no es una garantía:
  nada impide hoy que un mismo valor de `dimension` tenga dos unidades con
  `factor_to_base = 1`, de hecho el propio Edge Case de la spec contempla ese caso en la
  migración).
- **Alternativas consideradas**: (a) Mantener `factor_to_base == 1` como único indicador
  de "es la base" — rechazada porque no se puede expresar como constraint de base de
  datos sin un índice único parcial sobre un valor numérico igual a 1, y porque un cambio
  de `factor_to_base` por error dejaría un grupo sin base sin que la unicidad lo impida;
  (b) guardar `base_unit_id` en `unit_measure_groups` en vez de `is_base` en
  `unit_measures` — funcionalmente equivalente, pero obliga a un `UPDATE` en dos tablas
  para reasignar la base y complica el índice único parcial (se necesitaría de todos
  modos una bandera o derivarla por comparación de IDs en cada validación). Se prefiere
  `is_base` en `UnitMeasure` porque es la forma en que FR-008/FR-009/FR-014 formulan las
  restricciones ("la unidad marcada como base"), y porque el índice único parcial sobre
  booleano es el patrón estándar de Postgres para esta invariante.

## D2 — Qué pasa con la columna `dimension` tras la migración

- **Decisión**: `dimension` se **conserva** en la tabla (no se elimina en esta spec),
  pero deja de ser la fuente de verdad: pasa a ser una columna derivada/espejo que se
  sincroniza con `UnitMeasureGroup.name` en cada escritura (o se recalcula vía trigger /
  en el mismo código de servicio que escribe `group_id`). `app/core/units.py::convert()`
  sigue leyendo `dimension` sin cambios (FR-010, Assumptions), así que mantenerla viva y
  sincronizada es la forma más barata de cumplir "sin cambiar su comportamiento" sin
  tocar ese archivo.
- **Rationale**: El spec es explícito en que `convert()` "sigue funcionando igual (misma
  `dimension`, mismo `factor_to_base`)" — tocar ese archivo sería una refactorización no
  relacionada con esta feature (Principio V). Mantener `dimension` como espejo evita
  reescribir `convert()` y reduce el riesgo de introducir una regresión en spec 134.
- **Alternativas consideradas**: (a) Eliminar `dimension` y reescribir `convert()` para
  leer `group_id` — rechazada: el spec prohíbe explícitamente cambiar `convert()` o su
  fórmula, y tocar ese archivo mezclaría una refactorización de spec 134 dentro de esta
  feature (Principio V/VI); (b) dejar `dimension` como texto libre editable
  independientemente del grupo — rechazada: generaría desincronización entre grupo y
  dimensión, reabriendo el mismo problema que esta spec busca cerrar. Se documenta como
  deuda técnica aceptada (no se "limpia" `dimension` en este spec) para una futura
  spec de limpieza, si el negocio la pide.

## D3 — Cómo detectar "en uso" (FR-008, FR-009, FR-011, FR-014)

- **Decisión**: Una función de servicio `unit_measure_in_use(db, unit_measure_id) -> bool`
  que hace `EXISTS` contra `InventoryItem.unit_measure_id` y `Purchase.unit_measure_id`
  (sin filtrar por activo/inactivo, según Assumptions del spec: "activo o inactivo"). Para
  "grupo en uso" se reutiliza la misma función sobre cada unidad del grupo.
- **Rationale**: Reutiliza el patrón 409 Conflict ya existente en el código
  (`app/api/v1/catalog/service.py::_raise_presentation_conflict`), consistente con cómo
  el resto del backend comunica bloqueos por relaciones existentes.
- **Alternativas consideradas**: Añadir un contador desnormalizado (`usage_count`) en
  `UnitMeasure` — rechazada por complejidad innecesaria (Principio V/VI): el volumen de
  datos (decenas de unidades, compras e insumos por tenant) no justifica desnormalizar;
  una consulta `EXISTS` indexada por `unit_measure_id` (ya indexado en ambas tablas) es
  suficiente y no introduce un campo que haya que mantener sincronizado.

## D4 — Estrategia de la migración Alembic (data migration)

- **Decisión**: Una sola revisión Alembic que, en el mismo `upgrade()`: (1) crea
  `unit_measure_groups` y las columnas nuevas de `unit_measures` (`group_id` nullable
  temporalmente, `is_base`); (2) ejecuta la migración de datos vía SQL/ORM dentro de la
  misma función (`INSERT INTO unit_measure_groups` por cada `dimension` distinta, luego
  `UPDATE unit_measures SET group_id = ...`); (3) determina la base por grupo con
  `factor_to_base = 1` y `created_at` más antigua como desempate (Edge Case del spec); (4)
  vuelve `group_id` `NOT NULL` y agrega el índice único parcial de `is_base` al final,
  una vez poblado. El `downgrade()` revierte recomponiendo `dimension` desde
  `UnitMeasureGroup.name` (ya debería coincidir, por D2) y elimina las columnas/tabla
  nuevas.
- **Rationale**: Principio VIII exige migración y rollback explícitos en el mismo spec;
  hacerlo en una sola revisión (schema + datos) sigue el patrón ya usado en este repo
  para migraciones con backfill (ver `e4e9886ef15b_134_unit_conversion_compras.py`, que
  agregó `dimension`/`factor_to_base` con el mismo enfoque de columna nullable → backfill
  → NOT NULL).
- **Alternativas consideradas**: Separar schema y data migration en dos revisiones —
  rechazada: el spec pide una migración "una sola vez al desplegar" (Assumptions) y el
  patrón ya existente en el repo (134) resuelve ambas cosas en una sola revisión sin
  problema, evitando una ventana donde el dato está en un estado intermedio inconsistente
  entre deploys.

## D6 — Qué pasa con `factor_to_base` del resto del grupo al reasignar la base

- **Decisión**: Al mover `is_base` de una unidad a otra (FR-009), se recalcula
  `factor_to_base` de **todas** las unidades del grupo (incluida la base saliente) usando
  `nuevo_factor = factor_actual / factor_actual_de_la_nueva_base`, de modo que la nueva
  base quede en `factor_to_base = 1` y el resto conserve la misma relación proporcional
  entre sí que tenía antes.
- **Rationale**: FR-010 exige que la conversión entre unidades del mismo grupo siga
  usando "la misma fórmula que usa hoy (`factor_to_base` relativo a la unidad base del
  grupo)". Si solo se reasignara la bandera `is_base` sin recalcular los demás factores,
  la fórmula dejaría de ser correcta: `factor_to_base` de las otras unidades seguiría
  siendo relativo a la base *anterior*, no a la nueva, y las conversiones calculadas por
  `convert()` después de la reasignación darían resultados equivocados aunque `convert()`
  mismo no se haya tocado.
- **Alternativas consideradas**: (a) No recalcular nada y solo mover la bandera —
  rechazada porque rompe silenciosamente la fórmula de conversión para todas las unidades
  no-base del grupo, violando FR-010; (b) impedir la reasignación de base salvo que el
  admin reingrese manualmente todos los factores — rechazada por ser más trabajo manual
  del que el Acceptance Scenario 4 del spec sugiere ("la unidad anterior deja de ser base
  [...] y la nueva unidad base pasa a tener las restricciones del punto 3", sin mencionar
  que el admin deba recapturar factores).

## D5 — Alcance del rediseño visual (FR-001 a FR-004)

- **Decisión**: El rediseño se limita a plantillas (`.component.html` o templates
  inline) y estilos de los componentes ya existentes listados en Project Structure;
  ningún `.service.ts` ni llamada HTTP de esas tres pestañas cambia. La skill
  `frontend-design` se usa durante la fase de implementación (`/speckit-implement`), no
  en este plan, para traducir `design/ajustes.html` /
  `design/Ajustes-standalone-src.dc.html` a componentes Angular reales.
- **Rationale**: Las Assumptions del spec son explícitas: "reutiliza los mismos
  endpoints/servicios ya existentes [...] no se crean ni modifican endpoints para esas
  tres pestañas". Verificado contra el código actual: `tenant-info.component.ts`,
  `settings-page.component.ts` y el módulo de grupos de opciones ya consumen servicios
  estables que no requieren cambios de contrato para un rediseño puramente visual.
- **Alternativas consideradas**: N/A — esta decisión está explícitamente fijada por el
  spec, no es una elección técnica abierta.
