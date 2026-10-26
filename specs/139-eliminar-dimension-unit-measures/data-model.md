# Data Model: Eliminar columna `dimension` en unidades de medida

## `UnitMeasure` (`unit_measures`) — cambios

| Columna | Antes | Después | Notas |
|---|---|---|---|
| `dimension` | `String(100)`, `NOT NULL`, default `"general"` | **eliminada** | Era un espejo de `group.name` sincronizado en cada escritura (deuda técnica de la spec 137). |
| `group_id` | `UUID` FK a `unit_measure_groups.id`, `NOT NULL` | sin cambios | Pasa a ser la **única** fuente de verdad del grupo/dimensión de la unidad. |
| `is_base` | `Boolean`, `NOT NULL`, default `False` | sin cambios | Fuera de alcance. |
| `name`, `abbreviation`, `factor_to_base`, `active` | — | sin cambios | Fuera de alcance. |

`UnitMeasureGroup` (`unit_measure_groups`) no sufre ningún cambio estructural en esta spec.

## Regla de negocio afectada

- **Compatibilidad de conversión**: dos unidades son convertibles entre sí si y solo si
  pertenecen al mismo grupo. Antes se expresaba comparando `dimension` (string); después se
  expresa comparando `group_id` (FK). El resultado de la regla no cambia para ningún dato
  existente, porque `dimension` y `group.name` estaban garantizados sincronizados desde la
  spec 137.

## Migración

**Archivo**: `../pos-backend/alembic/versions/<rev>_139_remove_unit_measure_dimension.py`
(nombre de revisión a generar con `alembic revision`, encadenado tras la última head actual).

**`upgrade()`**:
1. `op.drop_column("unit_measures", "dimension")` (schema-per-tenant: iterar los schemas de
   tenant igual que hace la migración 137, no solo `public`).

**`downgrade()`** (recompone el estado anterior, sin pérdida de información):
1. `op.add_column("unit_measures", sa.Column("dimension", sa.String(length=100),
   nullable=True))`.
2. Por cada tenant, `UPDATE unit_measures um SET dimension = g.name FROM unit_measure_groups g
   WHERE g.id = um.group_id` — mismo patrón de recomposición que usa el `downgrade()` de
   `8f1a2c4d6e9b_137_unit_measure_groups.py` (líneas 184-191).
3. `op.alter_column("unit_measures", "dimension", nullable=False)`.

**Compatibilidad con datos existentes**: ninguna unidad existente pierde información —
`dimension` era puramente derivada de `group.name`, así que eliminarla no descarta ningún dato
que no pueda reconstruirse exactamente a partir de `group_id`.

**Estrategia de rollback**: `alembic downgrade -1` ejecuta el `downgrade()` descrito arriba;
tras aplicarlo, el esquema y los datos de `dimension` quedan en un estado equivalente al
anterior a esta spec (valor igual al `group.name` vigente en ese momento, igual que garantizaba
el mirror-sync que esta spec elimina).
