# Contrato: API de Grupos de unidades de medida

**Spec**: `specs/137-rediseno-ajustes/spec.md` | **Fecha**: 2026-10-26

Prefijo nuevo: `/unit-measure-groups` (mismo patrón de autenticación/autorización que
`/unit-measures` hoy: `require_module_access("inventario")` + `get_current_user`).
Las tres pestañas rediseñadas visualmente (Información básica, Métodos de pago, Grupos
de opciones) **no** tienen contrato nuevo — reutilizan los endpoints existentes sin
cambios (Assumptions del spec, `research.md` D5).

## `GET /unit-measure-groups`

Lista los grupos del tenant, cada uno con sus unidades anidadas (para que el frontend
pinte el acordeón de grupo → unidades del diseño sin un N+1 de llamadas).

- **Auth**: tenant autenticado, módulo `inventario` requerido.
- **Query params**: `active: bool | None` — si se pasa, filtra grupos que tengan al menos
  una unidad con ese estado (ver Edge Case "grupo sin unidades activas se oculta, no se
  borra").
- **200**: `list[UnitMeasureGroupResponse]` (ver forma abajo).

## `POST /unit-measure-groups`

Crea un grupo nuevo junto con su unidad base en el mismo paso (FR-005).

- **Body**:
  ```json
  {
    "name": "Volumen",
    "base_unit": { "name": "Mililitro", "abbreviation": "ml" }
  }
  ```
- **Efecto**: crea `UnitMeasureGroup(name=...)`, crea `UnitMeasure(name=..., abbreviation=...,
  group_id=<nuevo grupo>, is_base=true, factor_to_base=1, dimension=<name del grupo>)`.
- **201**: `UnitMeasureGroupResponse` con la unidad base incluida.
- **409**: nombre de grupo duplicado, o nombre/abreviatura de unidad ya usado en el tenant
  (Edge Cases del spec).
- **422**: datos inválidos (nombre vacío, abreviatura vacía).

## `POST /unit-measure-groups/{id}/units`

Agrega una unidad adicional a un grupo existente (FR-006). Equivalente a
`POST /unit-measures` pero fijando `group_id` y `is_base=false` explícitamente, para que
el cliente no pueda crear una unidad "huérfana" sin grupo.

- **Body**:
  ```json
  { "name": "Litro", "abbreviation": "L", "factor_to_base": 1000.000000 }
  ```
- **201**: `UnitMeasureResponse` (ver forma ajustada en `unit-measures-api.md`).
- **404**: el grupo no existe.
- **409**: nombre/abreviatura ya usado en el tenant (sin importar grupo).
- **422**: `factor_to_base <= 0`, igual regla que hoy.

## `PATCH /unit-measure-groups/{id}`

Renombrar el grupo. Sincroniza `dimension` de todas sus unidades (espejo, `research.md`
D2).

- **Body**: `{ "name": "Volumen líquido" }`
- **200**: `UnitMeasureGroupResponse`.
- **404 / 409**: igual que arriba.

## `PATCH /unit-measure-groups/{id}/base-unit`

Reasigna cuál unidad del grupo es la base (FR-009, Acceptance Scenario 4 y 5).

- **Body**: `{ "unit_measure_id": "<uuid de la unidad que pasa a ser base>" }`
- **Efecto**: si ninguna unidad del grupo está en uso (`research.md` D3): (1) recalcula
  `factor_to_base` de **todas** las unidades del grupo dividiendo su valor actual entre el
  `factor_to_base` actual de la nueva base (`nuevo_factor = factor_actual / factor_actual_de_la_nueva_base`),
  para que la fórmula de conversión (FR-010) siga dando el mismo resultado relativo entre
  cualquier par de unidades del grupo; (2) pone `is_base=false, factor_to_base` recalculado
  en la unidad anterior (deja de ser 1 salvo que coincida numéricamente) y
  `is_base=true, factor_to_base=1` en la nueva base. Esto preserva FR-010 ("misma fórmula
  que usa hoy") porque la relación `factor(A)/factor(B)` entre cualquier par de unidades
  del grupo no cambia, solo el punto de referencia (factor=1) se mueve a la nueva base.
- **200**: `UnitMeasureGroupResponse` actualizado.
- **404**: grupo o unidad no existen, o la unidad no pertenece a ese grupo.
- **409**: `{ "error": "...", "blocking_units": [{"id": "...", "name": "...", "reason": "en uso"}] }`
  — alguna unidad del grupo está en uso (FR-009, SC-004: siempre explica por qué).

## `DELETE /unit-measure-groups/{id}`

Elimina el grupo completo (FR-011, Acceptance Scenario 6). Distinto del soft-delete de
una unidad individual: esto es borrado real del grupo, permitido solo si ninguna de sus
unidades está en uso.

- **Efecto si procede**: elimina (hard-delete) el grupo y todas sus `UnitMeasure`
  asociadas — coherente con que, si nada las usa, no hay histórico que preservar.
- **204**: eliminado.
- **404**: el grupo no existe.
- **409**: `{ "error": "...", "blocking_units": [...] }` — igual forma que arriba
  (FR-011: "informar cuáles unidades lo bloquean").

## Forma de `UnitMeasureGroupResponse`

```json
{
  "id": "uuid",
  "name": "Volumen",
  "units": [
    { "id": "uuid", "name": "Mililitro", "abbreviation": "ml", "factor_to_base": 1.0, "is_base": true, "active": true },
    { "id": "uuid", "name": "Litro", "abbreviation": "L", "factor_to_base": 1000.0, "is_base": false, "active": true }
  ],
  "created_at": "...",
  "updated_at": "..."
}
```

## Errores de "en uso" (forma común para FR-008, FR-009, FR-011, FR-014)

Todos los bloqueos por uso devuelven `409` con el mismo detalle estructurado, para que el
frontend pueda listar qué está bloqueando sin parsear texto:

```json
{
  "error": "No se puede completar la acción: hay unidades en uso.",
  "blocking_units": [
    { "id": "uuid", "name": "Mililitro", "abbreviation": "ml" }
  ]
}
```
