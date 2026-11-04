# Contrato: "Cocina" en el catálogo de módulos de plan

Extiende los contratos ya existentes de spec 033 (`GET/POST /super-admin/plans`,
`PATCH /super-admin/plans/{id}`, `GET /plan`) agregando un campo más a cada payload — no crea
ningún endpoint nuevo. Ver research.md Decisión 0: esta spec **no** agrega ningún endpoint de
cocina ni ningún router gateado por `cocina_access` — solo el booleano en el catálogo y su
exposición en `GET /plan`.

## `POST /super-admin/plans` / `PATCH /super-admin/plans/{id}` (modificados)

**Request** (`PlanCreate`/`PlanUpdate`) gana `cocina_access`, mismo tipo y mismo comportamiento de
omisión que `inventario_access`/`promociones_access`:

```json
{
  "name": "Pro",
  "inventario_access": true,
  "promociones_access": true,
  "cocina_access": true
}
```

- `PlanCreate.cocina_access: bool = False` — omitido se guarda como `false` (bloqueado, FR-002/
  FR-003).
- `PlanUpdate.cocina_access: Optional[bool] = None` — omitido no modifica el valor vigente del
  plan (mismo patrón que los otros dos accesos).

## `GET /super-admin/plans` / respuesta de `POST`/`PATCH` (modificados)

**Response** (`PlanResponse`) gana `cocina_access: bool`, siempre presente (nunca `null` —
booleano, no límite):

```json
{
  "id": "uuid",
  "name": "Pro",
  "inventario_access": true,
  "promociones_access": true,
  "cocina_access": true,
  "...": "..."
}
```

**Errores**: sin cambios respecto al contrato de spec 033 — ningún código ni validación nueva
sobre este campo (es un booleano, no admite `422` por rango como los límites numéricos).

## `GET /plan` (modificado — resumen de consumo del tenant)

`ModuleAccess` gana `cocina: bool`:

```json
{
  "plan_name": "Pro",
  "modules": {
    "inventario": true,
    "promociones": true,
    "cocina": true
  },
  "...": "..."
}
```

Calculado como `plan.cocina_access`, sin ninguna lógica de vencimiento ni de conteo adicional —
mismo criterio que `inventario`/`promociones` (`app/api/v1/plan/service.py`).

## Sin contrato de enforcement todavía

Spec 033 documentó, en `contracts/tenant-plan-enforcement.md`, el 403 que cada endpoint de
inventario/promociones ya emite cuando el plan no incluye el módulo. Esta spec **no** tiene un
contrato equivalente para "cocina" porque no existe ningún endpoint de cocina al que aplicárselo
(research.md Decisión 0). El contrato que aplicará, el día en que una spec futura introduzca el
flujo de cocina, es exactamente ese mismo mecanismo:

- `Depends(require_module_access("cocina"))` sobre el router/ruta de cocina que se introduzca.
- Respuesta `403` con el código ya existente `MODULE_NOT_IN_PLAN` (`ModuleNotInPlanError`,
  `app/core/exceptions.py:34-46`) — **no** un código nuevo `MODULE_NOT_ENABLED` (research.md
  Decisión 2) — y `detail: "Tu plan actual no incluye el módulo de cocina."`.
- El mismo bloqueo por vencimiento (`ensure_plan_not_expired`) que ya corre, gratis, dentro de
  `require_module_access` para cualquier clave de `PLAN_MODULES`.

Esta sección documenta la extensión futura por trazabilidad (Principio XII) — no es trabajo de
esta fase.
