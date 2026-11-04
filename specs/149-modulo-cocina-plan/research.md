# Fase 0 — Research: Módulo "Cocina" en el catálogo de módulos por plan

## Decisión 0 (corrige la premisa del spec): no existe hoy un flujo de cocina que gatear

`spec.md` (Nota de alcance, Assumptions) asume que el tablero de cocina, el botón "Enviar a
cocina" y el atributo `kitchen_status` **ya existen** en el sistema, y que esta spec solo les
agrega gating por plan. Esa premisa es falsa en `develop` de ambos repositorios, verificado por
inspección directa antes de este plan:

- **`pos-heladeria`**: `src/app/modules/dashboard/routes.ts:95-97` — la ruta `/dashboard/cocina`
  es un `redirectTo: 'mesas-sesiones'` puro, con un comentario explícito: *"El tablero de cocina
  se deprecó: la preparación se marca desde la terminal de mesas, en la misma pantalla donde se
  toma y se cobra."* No hay componente de tablero, no hay botón "Enviar a cocina", no hay rol
  `KITCHEN` en `UserRole` (`core/interfaces/user.interface.ts:1-6`), no hay entrada en
  `navigation.config.ts`.
- **`pos-backend`**: no existe ningún router de cocina montado. `app/api/v1/orders/kitchen.py`
  es un módulo de servicio (no un router) que gestiona `OrderItem.estado_cocina`
  (`pendiente`/`entregado`/`cancelado`) como parte del ciclo de vida normal de entrega de la
  orden (spec 147) — no es un "enviar a cocina" independiente ni expone un endpoint propio.
  `app/api/v1/kitchen/` solo contiene artefactos `.pyc` sueltos de una rama abandonada, sin
  fuente rastreada por git.
- Existe un intento previo no fusionado: rama `feat/146-modulo-cocina-por-plan` (backend commit
  `7cd8a2e`, no ancestro de `develop`) que sí construyó un tablero completo
  (`KitchenTicket`/`KitchenTicketItem`, `src/app/modules/kitchen/`) gateado por un
  `cocina_access` ya absorbido antes del fold de spec 141 (su `plan.interface.ts` todavía tenía
  `compras_access`). Es útil como referencia de nombres, pero demasiado desactualizado para
  retomar tal cual (antecede a spec 141, spec 147, spec 148).

**Decisión**: siguiendo la elección del negocio (ver sesión de planificación), esta fase
implementa **únicamente la característica de plan `cocina_access`** — el booleano en el
catálogo, su administración por el Super Admin, y su exposición en `GET /plan` — exactamente con
el mismo mecanismo que `inventario_access`/`promociones_access`. No se reintroduce ningún
tablero, botón, rol `KITCHEN`, ni router de cocina en esta spec: **no hay ningún punto de
enforcement real todavía**, porque no hay ningún endpoint ni pantalla de cocina en `develop` a la
que `require_module_access("cocina")` pueda aplicarse. El día en que una spec futura reintroduzca
el flujo de cocina, esa spec consume `cocina_access` montando
`Depends(require_module_access("cocina"))` sobre su propio router — igual que spec 062 reutilizó
`require_module_access("inventario")` sin que spec 033 hubiera previsto esas superficies.

Esto redefine el alcance de FR-004/FR-006/FR-007/FR-008/FR-009/FR-010/FR-011 y de las Historias de
Usuario 2 a 5 del spec: documentan el comportamiento **que tendrá** el gating cuando el flujo de
cocina exista, pero esta fase de implementación no tiene ningún artefacto de código que los
verifique todavía más allá de `PLAN_MODULES` aceptando `"cocina"` como clave válida. Es una
decisión de negocio explícita, tomada por el usuario durante esta sesión de planificación (no
una corrección silenciosa de la spec) — pero **no** requiere una entrada en
`registro-de-anomalias.md`: el Principio II exige esa bitácora cuando un cambio modifica
comportamiento **existente** y ya observable en producción; aquí no hay ningún comportamiento de
cocina en producción que esta decisión esté alterando (el tablero y el botón nunca llegaron a
`develop`), solo un alcance de implementación sobre una spec todavía no construida.

**Alternativas consideradas**:
- *Rechazar la spec y devolverla a `/speckit-specify`*: más correcto a largo plazo, pero el
  negocio decidió seguir adelante con el alcance reducido ahora y resolver la reescritura de la
  spec como deuda de redacción, no como bloqueo de este incremento.
- *Revivir el tablero completo en esta misma spec*: mezclaría dos clases de cambio distintas
  (gating de plan + funcionalidad de cocina nueva) en un mismo incremento, violando el Principio
  VI (Evolución Incremental) — se descarta.

## Decisión 1: "Compras" ya no es un módulo de plan independiente — el catálogo vigente es dos módulos, no tres

`spec.md` y su checklist citan "Inventario, Compras y Promociones" como los tres módulos ya
gateados (heredado del redactado original de spec 033). Spec 141 (A-150/A-152,
`app/models/plan.py:16-18`, migración `30cd5f4a8fd6_141_plans_unify_inventory_module.py`) absorbió
`compras_access` dentro de `inventario_access` y eliminó la columna — Compras no es, hoy, una
característica de plan separada; vive dentro de "Inventario" (que cubre también Proveedores).

**Decisión**: el catálogo vigente de módulos de plan (`app/core/plan_limits.py:29-30`,
`PLAN_MODULES = ("inventario", "promociones")`) tiene **dos** entradas, no tres. Esta spec agrega
una tercera: `"cocina"`. Toda referencia de este plan a "el mismo patrón que Inventario, Compras
y Promociones" se entiende como "el mismo patrón que Inventario y Promociones" — no se reintroduce
Compras como concepto, es una imprecisión heredada del redactado del spec que no cambia ningún
requisito funcional (ambos ejemplos, con o sin Compras, describen el mismo mecanismo de columna
booleana + `require_module_access`).

**Alternativas consideradas**: corregir `spec.md` para que diga "Inventario y Promociones" —
descartado para esta fase porque es un cambio de redacción sin impacto funcional; se deja anotado
aquí para quien lea el spec junto con este plan.

## Decisión 2: el código de error reutiliza `MODULE_NOT_IN_PLAN`, no introduce `MODULE_NOT_ENABLED`

FR-005 pide que el backend rechace con HTTP 403 y "un código identificable" `MODULE_NOT_ENABLED`.
El mecanismo real que ya cubre `inventario`/`promociones` (`app/core/exceptions.py:34-46`,
`ModuleNotInPlanError`, introducido en spec 141/A-151) ya hace exactamente eso — 403 + código
estructurado en el cuerpo (`code`/`module`, servido aparte de `detail` por
`register_module_error_handler` en `app/core/error_middleware.py:356-357`) — pero con el código
`MODULE_NOT_IN_PLAN`, no `MODULE_NOT_ENABLED`. `MODULE_NOT_ENABLED` no existe en ningún lugar del
código ni de los characterization tests (`test_module_not_in_plan_error.py`,
`test_plan_module_access.py`).

**Decisión**: siguiendo la elección del negocio, "Cocina" reutiliza `ModuleNotInPlanError` /
`MODULE_NOT_IN_PLAN` tal cual, el día en que exista un punto de enforcement real (Decisión 0) —
no se introduce un segundo código de error paralelo solo para este módulo. El nombre
`MODULE_NOT_ENABLED` de FR-005 se entiende como una referencia genérica al mecanismo ("un código
identificable"), no como un valor literal nuevo a implementar.

**Alternativas consideradas**: introducir `MODULE_NOT_ENABLED` como código adicional específico
de cocina — descartado: dividiría en dos el contrato de error que hoy es uniforme para todo
módulo de plan, obligando a cualquier cliente integrador a reconocer dos códigos con el mismo
significado.

## Decisión 3: ubicación y forma de la columna nueva — mismo patrón que `inventario_access`/`promociones_access`

`cocina_access: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False,
server_default="false")` en `app/models/plan.py`, inmediatamente después de `promociones_access`
(línea 42 actual). Mismo tipo, mismo default (`false` = bloqueado, FR-003), misma ausencia de
`nullable` real — un booleano no tiene estado "no configurado" distinto de `false`, consistente
con cómo ya se resuelve FR-002/FR-003 para los otros dos módulos (research.md de spec 033,
Decisión 1: "No configurar una característica explícitamente produce el mismo bloqueo que
configurarla en su default").

**Alternativas consideradas**: ninguna — es la extensión mecánica de un patrón de tres usos ya
consistente (spec 033 original + spec 141 que lo redujo a dos), no hay una decisión de diseño
nueva que tomar.

## Decisión 4: migración Alembic — agregar columna, no una migración de datos

A diferencia de spec 141 (que fusionaba datos de una columna existente), esta spec solo agrega una
columna booleana nueva con `server_default="false"` — todo plan existente queda con
`cocina_access = false` sin ninguna migración de datos adicional (FR-003: por defecto no
incluido). Mismo patrón de nombre de archivo que `30cd5f4a8fd6_141_plans_unify_inventory_module.py`:
`<rev>_149_plans_add_cocina_access.py`, encadenada sobre el head actual (`82bab214ee32`).
`downgrade()` hace `op.drop_column("plans", "cocina_access", schema="shared")` — pérdida de dato
aceptable porque el valor es, en esta fase, un booleano sin ningún endpoint que lo lea aún
(Decisión 0), nunca un dato de negocio ya consumido.

**Alternativas consideradas**: ninguna — `op.add_column(..., server_default=sa.false())` es la
operación estándar del proyecto para una columna booleana nueva no derivada de otra ya existente.
