# Data Model: Grupos de unidades de medida

**Spec**: `specs/137-rediseno-ajustes/spec.md` | **Fecha**: 2026-10-26

Afecta solo a `pos-backend`, schema `tenant`. No hay cambios de modelo de datos en las
pestañas de rediseño puramente visual (Información básica, Métodos de pago, Grupos de
opciones) — ver `research.md` D5 y Assumptions del spec.

## Entidad nueva: `UnitMeasureGroup`

Reemplaza el rol que hoy cumple `UnitMeasure.dimension` como texto libre (ver
`research.md` D2: `dimension` se conserva como espejo sincronizado, no se elimina en
esta spec).

| Campo | Tipo | Reglas |
|---|---|---|
| `id` | UUID (PK) | `UUIDPrimaryKeyMixin`, igual que el resto de entidades del repo |
| `name` | `String(255)` | `NOT NULL`, `UNIQUE` en todo el tenant (FR-005, Edge Case: nombre de grupo único) |
| `created_at` / `updated_at` | timestamps | `TimestampMixin`, igual que `UnitMeasure` |

No necesita campo `active`: el grupo "se oculta si todas sus unidades están
desactivadas" (Edge Case) — esto se **deriva** (no se persiste) a partir del estado de
sus unidades, para no mantener dos fuentes de verdad sobre si el grupo está "vivo".

**Relación**: un `UnitMeasureGroup` tiene muchas `UnitMeasure` (1:N); exactamente una de
ellas tiene `is_base = true` en todo momento mientras el grupo exista (FR-007).

## Entidad existente ajustada: `UnitMeasure`

| Campo | Cambio | Reglas |
|---|---|---|
| `group_id` | **NUEVO** — FK a `unit_measure_groups.id`, `NOT NULL` tras la migración (nullable solo durante el backfill, ver `research.md` D4) | Toda unidad pertenece a exactamente un grupo |
| `is_base` | **NUEVO** — `Boolean`, `NOT NULL`, `default=False` | `UNIQUE` parcial sobre `(group_id)` `WHERE is_base = true` → exactamente una base por grupo (FR-007) |
| `dimension` | Sin cambio de tipo; pasa a sincronizarse automáticamente con `group.name` en cada escritura (espejo, `research.md` D2) | Ya no se edita directamente vía API; el `PATCH` de grupo o de unidad lo actualiza internamente |
| `name` | Sin cambio | `UNIQUE` en todo el tenant (ya existente), confirmado explícitamente por la clarificación del spec: único en todo el tenant, no por grupo |
| `abbreviation` | Sin cambio | `UNIQUE` en todo el tenant (ya existente); se mantiene visible y editable en el formulario (clarificación del spec) |
| `factor_to_base` | Sin cambio de tipo/semántica | Relativo a la unidad base de su grupo (igual fórmula que hoy, FR-010); **bloqueado** para la unidad con `is_base = true` (FR-008) |
| `active` | Sin cambio | Soft-delete existente; **bloqueado** para la unidad base (FR-008, Edge Case "desactivar la base") |

### Invariantes y reglas de negocio (dónde se validan, no en el schema de BD)

- **Exactamente una base por grupo** (FR-007): garantizado por índice único parcial en BD
  + validado en el servicio al crear/reasignar.
- **La unidad base no se edita/desactiva/elimina** (FR-008): validado en el servicio
  (`PATCH`/`DELETE` de `UnitMeasure`) antes de aplicar el cambio; responde 409 si
  `is_base = true` y el cambio afecta `factor_to_base` o `active`.
- **Reasignar base requiere que ninguna unidad del grupo esté en uso** (FR-009): el
  endpoint de reasignación de base valida `unit_measure_in_use()` (`research.md` D3)
  sobre **todas** las unidades del grupo (no solo la saliente/entrante) antes de mover la
  bandera `is_base`. Al reasignar, se recalcula `factor_to_base` de todas las unidades del
  grupo relativo a la nueva base, para no romper la fórmula de FR-010 (`research.md` D6).
- **Eliminar un grupo exige que ninguna de sus unidades esté en uso** (FR-011): válido
  solo cuando el grupo no tiene unidades activas referenciadas por `InventoryItem` ni
  `Purchase` (ninguna unidad del grupo, sin importar si es base).
- **Renombrar una unidad en uso está bloqueado** (FR-014): aplica a `name` y
  `abbreviation` de cualquier unidad (base o no) mientras `unit_measure_in_use()` sea
  verdadero; no bloquea otros campos (p. ej. no impide activar/desactivar una unidad
  no-base que esté en uso, eso no lo pide el spec).
- **Nombre de grupo único en todo el tenant** (Edge Case): `UNIQUE` en BD + 409 con
  mensaje explicativo si se intenta duplicar.
- **Unicidad de nombre/abreviatura de unidad es por tenant, no por grupo** (clarificación
  del spec): sin cambio respecto al comportamiento actual de `UnitMeasure` — se mantiene
  el `ensure_unique` ya existente en `router.py`, simplemente ahora ignorando a qué grupo
  pertenece la unidad duplicada.

## Entidades existentes sin cambio de esquema

- **`InventoryItem`**: conserva `unit_measure_id` (FK) sin cambios. Se usa para
  determinar "en uso" (Key Entities del spec).
- **`Purchase`**: conserva `unit_measure_id` (FK) sin cambios. Se usa para determinar "en
  uso" (histórico incluido, activo o inactivo — Assumptions del spec).
- **`UnitMeasureFactorChange`**: sin cambios de esquema; su endpoint
  `GET /unit-measures/{id}/factor-changes` (spec 134) sigue existiendo tal cual
  (Assumptions del spec) — la vista consolidada por grupo queda fuera de alcance.

## Plan de migración (resumen; detalle de pasos en `research.md` D4)

1. Crear tabla `unit_measure_groups` y columnas `group_id` (nullable)/`is_base` en
   `unit_measures`.
2. Backfill: un grupo por `dimension` distinto existente; para cada grupo, marcar como
   base la unidad con `factor_to_base = 1` más antigua (`created_at` mínimo) si hay
   exactamente una, o la más antigua de todas si hay cero o más de una con
   `factor_to_base = 1` (Acceptance Scenario 7 + Edge Case del spec).
3. Volver `group_id` `NOT NULL`, agregar el índice único parcial de `is_base`.
4. **Rollback**: recompone `dimension` desde `UnitMeasureGroup.name` por cada unidad
   (ya deberían coincidir por el espejo de D2), luego elimina `group_id`, `is_base` y la
   tabla `unit_measure_groups`. No hay pérdida de datos porque `dimension` y
   `factor_to_base` nunca se sobrescriben durante el `upgrade()`, solo se leen (FR-012).

## Verificación de la migración (SC-003)

Tras el backfill, para cada grupo debe cumplirse: exactamente una unidad con
`is_base = true`, ningún `factor_to_base` ni `active` alterado respecto al valor previo a
la migración, y ninguna fila de `InventoryItem`/`Purchase` cambia de `unit_measure_id` ni
de valor calculado. Esto se cubre con un test de migración que compara un snapshot antes/
después sobre una base de datos de prueba con datos representativos del Edge Case (dos
unidades con `factor_to_base = 1` en el mismo `dimension`).
