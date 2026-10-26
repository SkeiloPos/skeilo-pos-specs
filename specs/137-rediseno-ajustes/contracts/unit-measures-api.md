# Contrato: Ajustes a la API de Unidades de medida existente

**Spec**: `specs/137-rediseno-ajustes/spec.md` | **Fecha**: 2026-10-26

`GET /unit-measures`, `GET /unit-measures/{id}` y `GET /unit-measures/{id}/factor-changes`
**no cambian** (spec 134 sigue intacto). Este documento cubre solo los ajustes a los
endpoints de escritura.

## `GET /unit-measures` — ajuste de respuesta

- `UnitMeasureResponse` gana `group_id: UUID` e `is_base: bool`.
- El query param `dimension` se conserva por compatibilidad (`dimension` sigue siendo un
  espejo válido de `group.name`, `research.md` D2); se agrega `group_id: UUID | None`
  como alternativa explícita de filtro.

## `POST /unit-measures` — **retirado del flujo normal**

Crear una unidad suelta sin grupo deja de tener sentido tras esta spec (FR-005/FR-006:
toda unidad nace dentro de un grupo, ya sea como base al crear el grupo o agregada a uno
existente). El endpoint se mantiene por compatibilidad con integraciones/scripts
existentes pero ahora **exige** `group_id` en el body y crea la unidad con `is_base=false`
dentro de ese grupo — usar `POST /unit-measure-groups/{id}/units` es el flujo
recomendado desde el nuevo frontend. No se elimina el endpoint (Principio V: no romper
integraciones existentes sin que el spec lo pida explícitamente).

- **Body nuevo**: `{ "name", "abbreviation", "group_id", "factor_to_base" }` — se quita
  `dimension` del body de entrada (se deriva de `group_id`).
- **409** adicional: si `group_id` no existe → 404; si se intenta crear con
  `factor_to_base` igual al de la base sin marcarla como tal, no hay conflicto (varias
  unidades no-base pueden compartir factor).

## `PATCH /unit-measures/{id}` — ajustes

- Se retira `dimension` del body de entrada (ya no se edita unidad por unidad; se edita
  vía `PATCH /unit-measure-groups/{id}` si se quiere renombrar el grupo completo).
- **Nuevo bloqueo (FR-008)**: si `unit_measure.is_base == true` y el body trae
  `factor_to_base` o `active`, responde `409`:
  ```json
  { "error": "No se puede editar el factor ni desactivar la unidad base de un grupo. Elige otra unidad base primero." }
  ```
- **Nuevo bloqueo (FR-014)**: si el body trae `name` o `abbreviation` distintos a los
  actuales y la unidad está en uso (`research.md` D3), responde `409`:
  ```json
  { "error": "Esta unidad está en uso en compras y no se puede renombrar." }
  ```
- El bloqueo de rol ADMIN para cambiar `factor_to_base` (spec 134, FR-011a) se mantiene
  sin cambios y se evalúa **antes** del bloqueo de "es base" (primero se valida
  autorización, luego la regla de negocio).

## `DELETE /unit-measures/{id}` — ajuste

- Sigue siendo soft-delete (`active=False`), sin cambios para unidades no-base (FR-013).
- **Nuevo bloqueo (FR-008)**: si `is_base == true`, responde `409` con el mismo mensaje
  que el bloqueo de `PATCH` — "no se puede desactivar/eliminar la unidad base de un
  grupo".
