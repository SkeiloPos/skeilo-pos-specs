# Implementation Plan: Módulo "Cocina" en el catálogo de módulos por plan

**Branch**: `149-modulo-cocina-plan` | **Date**: 2026-11-04 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/149-modulo-cocina-plan/spec.md`

## Summary

`spec.md` pide incluir "Cocina" en el catálogo de módulos gobernados por plan, con el mismo
mecanismo que ya gatea Inventario y Promociones (spec 033, reducido de tres módulos a dos por
spec 141 — research.md Decisión 1), asumiendo que el tablero de cocina, el botón "Enviar a
cocina" y `kitchen_status` ya existen y solo necesitan gating. Esa asunción no es cierta en
`develop`: el tablero de cocina fue deprecado explícitamente (`pos-heladeria/.../routes.ts:95-97`,
redirige a la terminal de mesas) y no hay ningún router de cocina en `pos-backend` — la
preparación se marca hoy vía `OrderItem.estado_cocina` como parte normal del ciclo de entrega
(spec 147), no como un flujo de cocina independiente (research.md Decisión 0).

Verificada esta discrepancia, el usuario decidió, en esta misma sesión de planificación, acotar
el alcance de esta fase a **agregar únicamente la característica de plan `cocina_access`** —
columna booleana en `Plan`, administración por el Super Admin (mismos endpoints de spec 033/141),
y exposición en `GET /plan` — exactamente con el mismo patrón que `inventario_access`/
`promociones_access`, sin reintroducir ningún tablero, botón, rol de cocina ni router. No hay,
en esta fase, ningún punto de enforcement backend ni ningún elemento de UI que ocultar, porque no
existe ningún flujo de cocina al que aplicárselo — eso queda documentado como trabajo de una spec
futura que sí reviva el flujo de cocina y entonces monte
`Depends(require_module_access("cocina"))` sobre su propio router. El usuario también decidió que
el código de error reutilice `MODULE_NOT_IN_PLAN` (ya existente, `ModuleNotInPlanError`) en vez
del `MODULE_NOT_ENABLED` que pide FR-005, que no corresponde al mecanismo real (research.md
Decisión 2).

## Technical Context

**Language/Version**: Backend — Python 3.14.4 (venv `pos-backend/env`). Frontend — TypeScript
5.9.2 (Angular 21.1.x, standalone components + signals).

**Primary Dependencies**: Ninguna dependencia nueva en ningún repositorio. Reutiliza
`app.core.plan_limits` (`PLAN_MODULES`, `require_module_access`, `ensure_module_access`,
`has_module_access`) y `app.core.exceptions.ModuleNotInPlanError`, ambos ya existentes desde
spec 033/141, sin modificar su forma — solo se agrega `"cocina"` a `PLAN_MODULES` y una columna
nueva que esa infraestructura ya sabe leer vía `getattr(plan, f"{module_key}_access")`.

**Storage**: PostgreSQL 16, schema-per-tenant. Una sola columna nueva: `shared.plans.cocina_access`
(`Boolean NOT NULL DEFAULT false`), mismo tipo y mismo default que `inventario_access`/
`promociones_access` (`app/models/plan.py`). Ninguna tabla nueva, ninguna migración de datos
(data-model.md Decisión 4) — a diferencia de spec 141, que fusionaba una columna existente, esta
spec solo agrega una columna booleana sin backfill necesario (`server_default` la resuelve).

**Testing**: Backend — `unittest` vía `python -m unittest discover -s app/characterization_tests
-p 'test_*.py'`. Se extiende `test_super_admin_plans.py` (o el fichero que ya cubre
`inventario_access`/`promociones_access` tras spec 033/141) con los mismos casos para
`cocina_access`, sin agregar ningún test de enforcement de endpoint (no hay endpoint que gatear
en esta fase). Frontend — Vitest (`ng test`), se extiende `plan-form.component.spec.ts` con el
checkbox nuevo, mismo patrón que los dos existentes.

**Target Platform**: Linux server (API `pos-backend`) + navegador (SPA `pos-heladeria`, panel de
Super Admin ya existente en `src/app/modules/super-admin/`).

**Project Type**: Web application (backend FastAPI + frontend Angular, repos sibling de
`pos-specs`).

**Performance Goals**: Ninguno nuevo — una columna booleana más, leída igual que las otras dos
(sin `SELECT` ni `JOIN` adicional).

**Constraints**:
- El alcance de esta fase **no** incluye ningún endpoint ni pantalla de cocina — ver research.md
  Decisión 0. FR-004/FR-006/FR-007/FR-008/FR-009/FR-010/FR-011 del spec quedan documentados como
  comportamiento futuro, sin artefacto de código que los verifique todavía más allá de que
  `PLAN_MODULES` acepte `"cocina"` como clave válida.
- El código de error que usará el futuro enforcement es `MODULE_NOT_IN_PLAN` (ya existente), no
  `MODULE_NOT_ENABLED` (research.md Decisión 2) — ninguna clase de excepción nueva se agrega en
  esta fase.
- "Compras" no es un módulo de plan independiente desde spec 141 — ninguna referencia de esta
  spec a "Inventario, Compras y Promociones" implica reintroducir esa columna (research.md
  Decisión 1).
- Ningún dato existente se pierde: agregar `cocina_access` con `server_default=false` no cambia
  el comportamiento observable de ningún tenant ni plan ya existente (Principio II — no hay
  comportamiento de cocina en producción que esta columna esté alterando, research.md Decisión
  0).

**Scale/Scope**: 1 columna nueva (`shared.plans.cocina_access`), 1 migración Alembic, 1 entrada
nueva en `PLAN_MODULES`, 3 schemas Pydantic modificados (`PlanCreate`/`PlanUpdate`/`PlanResponse`),
1 schema `ModuleAccess` (backend) + 1 interfaz `ModuleAccess` (frontend) modificados, 1 campo en
`build_plan_summary`, 2 interfaces TypeScript modificadas (`Plan`/`PlanCreatePayload`), 1
checkbox + 2 líneas de `FormGroup`/payload en `plan-form.component.ts`. Cero endpoints nuevos,
cero routers nuevos, cero componentes de UI nuevos más allá del checkbox.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Evaluación | Estado |
|---|---|---|
| **I. Las Nuevas Funcionalidades Nacen de un Spec** | `spec.md` existe, aprobado, con 5 historias y 11 FRs. Su premisa (el flujo de cocina ya existe) resultó incorrecta frente al código real; el usuario decidió, en esta sesión de planificación, acotar el alcance de la implementación a la sola característica de plan, documentado explícitamente en research.md Decisión 0 — no se implementa nada que el spec no haya pedido, se implementa un subconjunto verificable de lo que pide. | PASS (con alcance acotado, documentado) |
| **II. El Comportamiento Existente Sigue Protegido** | No hay comportamiento de cocina en producción que esta spec esté modificando (nunca se desplegó un tablero ni un botón "Enviar a cocina" — research.md Decisión 0). Agregar `cocina_access = false` por defecto no cambia el comportamiento observable de ningún tenant/plan existente. No se requiere entrada en `registro-de-anomalias.md` (a diferencia de spec 141, que sí alteraba un contrato de API ya servido en producción). | PASS |
| **III. Los Characterization Tests Protegen el Comportamiento Heredado** | Ningún test `"CONGELA comportamiento actual:"` asume que `PLAN_MODULES` tiene exactamente dos entradas ni que `Plan` carece de `cocina_access` (research.md lo confirma por inspección directa) — ninguno se modifica. | PASS |
| **IV. Los Nuevos Specs Pueden Introducir Nuevo Comportamiento** | El comportamiento nuevo (columna `cocina_access`, administrable por el Super Admin, visible en `GET /plan`) está definido en `spec.md` (Historia 1) y acotado por esta sesión de planificación; el criterio de éxito es conformidad con ese subconjunto, no equivalencia con el pasado. | PASS |
| **V. Nuevas Funcionalidades Antes que Refactorizaciones Oportunistas** | No se toca ningún router ni componente ajeno a la característica de plan — ni `orders/kitchen.py` (ciclo de entrega, spec 147) ni ninguna ruta de `dashboard/routes.ts` se modifican. | PASS |
| **VI. Evolución Incremental** | Esta spec entrega una única unidad verificable (la característica de plan), separada deliberadamente de cualquier futura reconstrucción del flujo de cocina — mezclar ambas en un mismo incremento fue la alternativa descartada en research.md Decisión 0 precisamente por este principio. | PASS |
| **VII. Compatibilidad con Datos Históricos** | Ninguna `Sale`/`Payment`/`Invoice`/`OrderItem.estado_cocina` se toca. | PASS |
| **VIII. Evolución del Modelo de Datos** | Ver data-model.md: una columna nueva (`cocina_access`, `Boolean NOT NULL DEFAULT false`), sin backfill de datos necesario (el `server_default` lo resuelve), con estrategia de rollback explícita (`op.drop_column`, research.md Decisión 4). | PASS |
| **IX. Dependencias Nuevas Permitidas con Justificación** | No aplica — cero dependencias nuevas. | N/A |
| **X. Verificación Obligatoria** | quickstart.md traduce el alcance acotado a pasos ejecutables (US1 del spec, columna + endpoints de Super Admin + `GET /plan`); documenta explícitamente qué partes del spec original (US2-US5, FR-004 y siguientes) esta fase NO verifica, por qué, y qué debe verificar la spec futura que las retome. | PASS |
| **XI. Decisiones de Negocio Frente a Decisiones Técnicas** | Tres decisiones quedaron explícitas y correctamente atribuidas: (a) acotar el alcance a la sola característica de plan — decisión de negocio, tomada por el usuario vía pregunta directa en esta sesión; (b) reutilizar `MODULE_NOT_IN_PLAN` en vez de introducir `MODULE_NOT_ENABLED` — decisión de negocio, misma sesión; (c) tratar "Compras" como ya absorbida en "Inventario" — hecho técnico ya decidido por spec 141, no una decisión nueva de esta spec. | PASS |
| **XII. Trazabilidad** | Cadena completa: `spec.md` (Necesidad+Spec) → esta sesión de planificación (decisión de acotar alcance y de reutilizar el código de error, ambas explícitas) → este `plan.md`/`research.md` (Decisión técnica) → `tasks.md` (Fase 2, no generada por este comando) → implementación → tests nuevos → `quickstart.md` (Verificación). | PASS |
| **XIII. Todo en Español de Colombia** | Este plan y todos sus artefactos se escriben en español de Colombia, igual que `spec.md`. | PASS |

Sin violaciones que requieran Complexity Tracking. La única particularidad de este plan —reducir
el alcance de implementación frente al spec original— queda justificada arriba, no como una
excepción de complejidad sino como una decisión de negocio explícita y trazable.

**Re-chequeo post-diseño (Fase 1)**: `research.md`, `data-model.md` y `contracts/` no introdujeron
ninguna entidad, dependencia ni decisión que contradiga la tabla anterior. El contrato de
enforcement futuro (`contracts/plan-catalog-cocina.md`, última sección) se documenta por
trazabilidad (Principio XII) sin ser trabajo de esta fase. Gates siguen en PASS.

## Project Structure

### Documentation (this feature)

```text
specs/149-modulo-cocina-plan/
├── plan.md              # Este fichero (/speckit-plan)
├── research.md          # Fase 0 (/speckit-plan) — decisiones técnicas, incluida la corrección
│                           de la premisa del spec (research.md Decisión 0)
├── data-model.md         # Fase 1 (/speckit-plan) — columna nueva, sin entidades nuevas
├── quickstart.md         # Fase 1 (/speckit-plan) — validación ejecutable del alcance acotado
├── contracts/            # Fase 1 (/speckit-plan)
│   └── plan-catalog-cocina.md
└── tasks.md              # Fase 2 (/speckit-tasks — NO se crea en este comando)
```

### Source Code (repositorios sibling de `pos-specs`)

Esta spec vive en `pos-specs`, pero el código que describe está en `../pos-backend` y
`../pos-heladeria` (Constitución §Alcance). Rutas relativas a la raíz de cada repo.

```text
# pos-backend
app/
├── models/
│   └── plan.py                        # MODIFICADO — Plan gana cocina_access (Boolean, NOT NULL,
│                                         default False, server_default="false"), misma línea que
│                                         inventario_access/promociones_access (líneas 41-42
│                                         actuales)
├── core/
│   └── plan_limits.py                 # MODIFICADO — PLAN_MODULES pasa de
│                                         ("inventario", "promociones") a
│                                         ("inventario", "promociones", "cocina") (línea 30
│                                         actual); ningún otro cambio — ensure_module_access/
│                                         has_module_access/require_module_access ya resuelven
│                                         cualquier clave de PLAN_MODULES vía getattr genérico
├── api/v1/
│   ├── super_admin/
│   │   └── schemas.py                 # MODIFICADO — PlanCreate.cocina_access: bool = False,
│   │                                     PlanUpdate.cocina_access: Optional[bool] = None,
│   │                                     PlanResponse.cocina_access: bool (mismas líneas que
│   │                                     inventario_access/promociones_access, ~143/165/183)
│   └── plan/
│       ├── schemas.py                 # MODIFICADO — ModuleAccess.cocina: bool
│       └── service.py                 # MODIFICADO — build_plan_summary agrega
│                                         "cocina": plan.cocina_access al dict de modules
├── characterization_tests/
│   └── test_super_admin_plans.py      # MODIFICADO (o el fichero equivalente que ya cubre
│                                         inventario_access/promociones_access) — casos nuevos
│                                         para cocina_access (crear con/sin el campo, editar,
│                                         reflejo en GET /plan), mismo patrón que los dos módulos
│                                         existentes
└── alembic/versions/
    └── {rev}_149_plans_add_cocina_access.py   # NUEVO — agrega shared.plans.cocina_access
                                                   (Boolean NOT NULL DEFAULT false),
                                                   encadenada sobre el head actual (82bab214ee32);
                                                   downgrade() hace drop_column (research.md
                                                   Decisión 4)

# pos-heladeria
src/app/modules/
├── super-admin/
│   ├── interfaces/
│   │   └── plan.interface.ts          # MODIFICADO — Plan.cocina_access: boolean,
│   │                                     PlanCreatePayload.cocina_access?: boolean
│   └── components/
│       └── plan-form.component.ts     # MODIFICADO — checkbox nuevo
│                                         (formControlName="cocina_access") en la sección
│                                         "Accesos de módulo" (línea ~104), FormControl nuevo
│                                         (líneas ~181-182), mapeo al payload en modo edición y
│                                         creación (líneas ~192-193/221-222) — mismo patrón de
│                                         tres líneas que inventario_access/promociones_access,
│                                         sin diálogo de confirmación adicional (el que existe
│                                         hoy es específico de "Inventario", no se replica)
└── plan/
    ├── interfaces/
    │   └── plan-summary.interface.ts  # MODIFICADO — ModuleAccess.cocina: boolean
    └── components/plan-form.component.spec.ts  # MODIFICADO (test colocado) — casos nuevos para
                                                    el checkbox de cocina, mismo patrón que los
                                                    dos existentes
```

**Structure Decision**: cada archivo tocado es una extensión mecánica de un patrón de dos usos ya
existente (`inventario_access`/`promociones_access`) a un tercer uso (`cocina_access`) — ningún
directorio, módulo, router ni componente nuevo se crea en ninguno de los dos repositorios. No hay
ningún archivo de cocina (router, componente de tablero, guard) en este plan: ese trabajo queda
fuera de alcance por decisión explícita de esta sesión (research.md Decisión 0), para una spec
futura que lo retome usando `cocina_access` ya disponible.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

Sin violaciones — tabla vacía. La reducción de alcance frente al spec original no es una
violación de la constitución, sino una decisión de negocio documentada en Constitution Check (fila
I) y en research.md Decisión 0.
