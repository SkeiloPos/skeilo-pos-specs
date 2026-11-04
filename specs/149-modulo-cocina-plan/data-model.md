# Fase 1 — Data Model: Módulo "Cocina" en el catálogo de módulos por plan

Ver decisiones técnicas en [research.md](./research.md), en particular la Decisión 0 (alcance
reducido a la sola característica de plan, sin ningún endpoint de cocina que la consuma todavía).

## Entidades

### `Plan` (modificada — esquema `shared`, tabla `plans`, ya existente desde spec 033)

Gana una tercera característica de módulo, junto a `inventario_access`/`promociones_access`
(spec 033, reducidas de tres a dos por spec 141 — research.md Decisión 1).

| Campo | Tipo | Notas |
|---|---|---|
| **`cocina_access`** | `Boolean`, `NOT NULL`, default `false`, `server_default="false"` | Nueva. Acceso al módulo "Cocina" (FR-001/FR-002). `false` = no incluido — mismo significado y mismo default que `inventario_access`/`promociones_access`; no existe un tercer estado "no configurado" distinto de `false` (FR-003). |

**Reglas** (idénticas a las que ya rigen `inventario_access`/`promociones_access`, data-model.md
de spec 033):
- Editar `cocina_access` de un plan aplica de inmediato a todos los tenants con ese `plan_id` —
  sin caché, cada lectura futura de `GET /plan` o de un eventual gating ve el valor vigente.
- No hay borrado de la columna salvo una migración de reversión explícita (research.md Decisión
  4) — mismo criterio que cualquier columna de `Plan`.

### Catálogo de módulos de plan (`app/core/plan_limits.py::PLAN_MODULES`, sin tabla propia)

| Antes de esta spec | Después de esta spec |
|---|---|
| `("inventario", "promociones")` | `("inventario", "promociones", "cocina")` |

`PLAN_MODULES` es la única fuente de verdad de qué claves son válidas para
`require_module_access`/`ensure_module_access`/`has_module_access` (`_validate_module_key` lanza
`ValueError` ante cualquier clave fuera de esta tupla). Agregar `"cocina"` la habilita para un
futuro `Depends(require_module_access("cocina"))`, pero **ningún router la usa en esta fase**
(research.md Decisión 0) — no hay tabla de "módulo → router" que agregar todavía, a diferencia de
spec 033/062 donde sí existía el router de destino desde el día uno.

### `GET /plan` — resumen de consumo del tenant (modificado, sin nueva tabla)

`ModuleAccess` (`app/api/v1/plan/schemas.py`) y su contraparte TypeScript
(`plan-summary.interface.ts`) ganan el campo `cocina: bool`, calculado igual que los otros dos:
`plan.cocina_access` sin ninguna lógica adicional. Ver
[contracts/plan-catalog-cocina.md](./contracts/plan-catalog-cocina.md).

## Relaciones

Sin cambios — `cocina_access` es una columna más de `shared.plans`, misma relación 1-a-N con
`shared.tenants` ya descrita en data-model.md de spec 033. No se crea ninguna entidad, tabla ni FK
nueva.

## Transiciones de estado

### Asignación/edición de "Cocina" en un plan

Idéntica al diagrama "Bloqueo por acceso a módulo" de spec 033/data-model.md, con una diferencia
explícita: hoy no existe ningún paso "¿`Plan.cocina_access` es true?" conectado a un endpoint real
de cocina, porque ese endpoint no existe (research.md Decisión 0). El único flujo observable en
esta fase es:

```
Super Admin crea/edita un Plan
        │
        ▼
  envía cocina_access = true/false (u lo omite → false, FR-003)
        │
        ▼
  Plan.cocina_access persistido
        │
        ▼
  GET /plan (cualquier tenant con ese plan) refleja modules.cocina = Plan.cocina_access
        │
        ▼
  (sin punto de enforcement en esta fase — ninguna ruta de cocina existe para bloquear)
```

Cuando una spec futura reintroduzca el flujo de cocina, ese trabajo extiende este diagrama
agregando el mismo paso "¿`cocina_access` es true?" que ya protege a `inventario`/`promociones`
hoy (data-model.md de spec 033, diagrama "Bloqueo por acceso a módulo") — sin modificar nada de lo
que esta spec entrega.

## Migración de datos

Ver research.md Decisión 4. Una sola migración Alembic, encadenada sobre el head actual
(`82bab214ee32`):

1. **Agregar columna** `shared.plans.cocina_access` (`Boolean NOT NULL DEFAULT false`,
   `server_default`) — ningún plan existente queda sin valor (se backfillea solo por el
   `server_default`, sin `UPDATE` explícito necesario).
2. **Verificación** (quickstart.md): todo plan existente (incluyendo el plan transicional
   sembrado por spec 033) queda con `cocina_access = false` tras el `upgrade`; ningún tenant ve
   cambio de comportamiento observable (no hay ningún endpoint que lea esta columna todavía,
   Principio II).
3. **Rollback**: `downgrade()` ejecuta `op.drop_column("plans", "cocina_access", schema="shared")`
   — pérdida de dato aceptable porque, en esta fase, el valor no es consumido por ningún flujo de
   negocio activo (research.md Decisión 4).
