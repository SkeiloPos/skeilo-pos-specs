# Contrato: Retiro de `dimension` en la API de Unidades de medida

**Spec**: `specs/140-eliminar-dimension-unit-measures/spec.md` | **Fecha**: 2026-10-26

Este documento cubre únicamente el ajuste que esta spec introduce sobre `GET
/unit-measures`. Ningún otro endpoint de `unit-measures` ni de `unit-measure-groups` cambia:
el contrato definido en `specs/137-rediseno-ajustes/contracts/unit-measures-api.md` sigue
vigente salvo por lo descrito aquí.

## `GET /unit-measures` — breaking change

- **Respuesta**: `UnitMeasureResponse` **pierde** el campo `dimension: str`. El grupo de la
  unidad se identifica exclusivamente por `group_id: UUID` (ya presente desde la spec 137).
  Un cliente que necesite el nombre del grupo debe resolverlo vía `GET
  /unit-measure-groups/{group_id}` o el endpoint de listado de grupos.
- **Query param**: `dimension` **se retira**. Ya no existe como filtro de texto libre. El
  filtro equivalente sigue siendo `group_id: UUID | None` (sin cambios respecto a la spec
  137).
- **Sin período de transición**: no se ofrece alias ni resolución nombre→id para el filtro
  retirado (ver `research.md` D2) — no hay consumidores externos conocidos que dependan de
  él (Assumptions del spec).

## Endpoints de escritura (`POST`/`PATCH` de `unit-measures` y `unit-measure-groups`)

- Ningún body de entrada cambia: `dimension` ya no viajaba en los bodies de escritura desde
  la spec 137 (ver `specs/137-rediseno-ajustes/contracts/unit-measures-api.md`).
- Se retira, como detalle interno de implementación (no de contrato), la escritura automática
  que sincronizaba `dimension = group.name` en cada creación de unidad y en cada renombrado de
  grupo — esto no es observable por un cliente de la API, solo deja de ejecutarse una
  escritura redundante en base de datos.
