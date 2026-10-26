# Quickstart: Validar Rediseño de Ajustes + grupos de unidades de medida

**Spec**: `specs/137-rediseno-ajustes/spec.md` | **Fecha**: 2026-10-26

## Prerrequisitos

- Postgres local disponible (ver memoria del proyecto — hay Postgres local, no se
  necesita Docker).
- `pos-backend`: venv activo con las dependencias del repo instaladas; migraciones al día
  antes de aplicar la nueva (`alembic upgrade head` en la rama `main` primero).
- `pos-heladeria`: `npm install` si no está hecho.
- Rama de trabajo creada en ambos repos siguiendo el Principio XIV:
  `feat/137-rediseno-ajustes`.

## 1. Migración de datos (grupos de unidades)

```bash
# en pos-backend, con el venv activo
alembic upgrade head
```

**Validar**: para cada valor distinto que tenía `dimension` antes de la migración, existe
ahora un `UnitMeasureGroup` con ese nombre, y exactamente una de sus unidades tiene
`is_base = true` (ver criterio de desempate en `data-model.md`). Consulta de verificación
rápida:

```sql
SELECT g.name, count(*) FILTER (WHERE u.is_base) AS bases, count(*) AS total
FROM tenant.unit_measure_groups g
JOIN tenant.unit_measures u ON u.group_id = g.id
GROUP BY g.name;
-- "bases" debe ser 1 en cada fila (SC-003)
```

**Rollback** (si algo sale mal): `alembic downgrade -1` — debe dejar `dimension` con los
mismos valores que tenía antes del `upgrade` (ver `research.md` D4).

## 2. Verificación de endpoints nuevos/ajustados (backend)

```bash
# tests nuevos y existentes relevantes
pytest tests/unit/test_unit_measure_groups.py tests/unit/test_unit_measures_in_use.py -v
pytest tests/integration/test_units_conversion.py -v   # spec 134, debe seguir en verde
```

Escenarios manuales equivalentes a los Acceptance Scenarios del spec (via
`http://localhost:8000/docs` o `curl`):

1. `POST /unit-measure-groups` con `name="Volumen"`, `base_unit={"name":"Mililitro","abbreviation":"ml"}`
   → 201, unidad base con `factor_to_base=1`.
2. `POST /unit-measure-groups/{id}/units` con `name="Litro"`, `factor_to_base=1000` → 201.
3. `PATCH /unit-measures/{mililitro_id}` con `{"factor_to_base": 2}` → 409 (es la base).
4. Sin unidades en uso: `PATCH /unit-measure-groups/{id}/base-unit` reasignando a
   "Litro" → 200, `factor_to_base` de "Mililitro" recalculado (`research.md` D6).
5. Con una unidad en uso (crear un `InventoryItem` que la referencie primero): reintentar
   el paso 4 → 409 con `blocking_units`.
6. `DELETE /unit-measure-groups/{id}` sobre un grupo sin unidades en uso → 204; con una
   unidad en uso → 409 con `blocking_units`.

## 3. Verificación visual (frontend)

```bash
# en pos-heladeria
ng serve
```

- Abrir Ajustes → "Información básica": confirmar que los mismos valores guardados
  (logo, mensaje de recibo, ancho de rollo) se ven y se pueden editar igual que antes,
  con la apariencia nueva (FR-001, Acceptance Scenario 1 de User Story 1).
- Abrir "Métodos de pago": activar/editar/desactivar un método sin cambios de datos
  (FR-002, Acceptance Scenario 2).
- Abrir "Grupos de opciones": crear/editar/activar/desactivar/eliminar un grupo u opción
  (FR-003, Acceptance Scenario 3).
- Abrir "Unidades de medida": confirmar que los grupos migrados aparecen con su unidad
  base marcada, que la base no se puede editar/desactivar desde la UI, y que crear un
  grupo nuevo + agregar una unidad adicional toma menos de 1 minuto sin ayuda externa
  (SC-002).
- Confirmar que la pestaña "Unidades de medida" sigue oculta para un tenant sin el plan
  Inventario (FR-004).

## 4. Tests frontend

```bash
ng test
```

Nota: la baseline de `ng test` en este proyecto es flaky/no determinista (ver memoria del
proyecto) — comparar archivo por archivo contra la baseline previa, no el conteo total de
la suite completa.

## Criterios de salida (resumen)

- [ ] `alembic upgrade head` corre limpio y la consulta de verificación de SC-003 da 1
      base por grupo en todos los grupos migrados.
- [ ] `pytest` backend en verde, incluyendo `test_units_conversion.py` (spec 134) sin
      regresiones.
- [ ] Los 6 escenarios manuales del paso 2 responden como se describe (200/201/409 según
      corresponda, con `blocking_units` en los 409 de uso).
- [ ] Las 4 pestañas de Ajustes se ven con el nuevo diseño y el comportamiento descrito en
      `contracts/ajustes-ui-contract.md` se cumple.
- [ ] `ng test` no introduce fallas nuevas respecto a la baseline conocida.
