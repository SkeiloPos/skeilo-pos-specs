# Implementation Plan: Módulo Inventario unificado (Inventario + Proveedores + Compras) en el control de acceso por plan

**Branch**: `141-modulo-inventario-unificado` (specs) · código: `feat/141-unified-inventory-module` en `pos-backend` y en `pos-heladeria`, creadas desde `develop` antes de tocar código (Principio XIV) | **Date**: 2026-10-31 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/141-modulo-inventario-unificado/spec.md`

## Summary

La spec 141 convierte «Inventario» en la unidad comercial indivisible que cubre Inventario, Proveedores y Compras, hace al
servidor la única autoridad de acceso por módulo, y hace que la interfaz sea un espejo del plan con un aviso y una conducta
únicos cuando un módulo se pierde. La investigación ([research.md](./research.md)) reconfirmó con el código cada premisa y encontró
**cuatro cosas que la spec no tenía**:

1. **La Terminal de mesas pide `GET /promotions` en todos los negocios** (`pos-terminal.store.ts:1466`). Con el aviso global que la spec
   extiende a Promociones, abrir la terminal expulsaría a cualquier negocio sin Promociones. Es el mismo fallo que FR-014 describe para
   «Stock bajo», no nombrado para Promociones (H1).
2. **Tres pantallas del catálogo base cargan endpoints de Inventario sin condición** —formulario de producto, grupos de opciones,
   formulario de adición— y deben seguir funcionando sin el módulo (H2). El barrido de FR-014 queda en **5 superficies**, no solo «Stock bajo».
3. **La importación/exportación de productos (spec 143) no respeta el módulo**: un negocio sin Inventario puede leer/escribir
   recetas y `Rastrea inventario` por ese camino (H3). Se propone cerrarlo a nivel de campo en un incremento aislado y retirable (D13).
4. **Hay specs 142–145 en los repos de código que no están en `pos-specs`**: la `down_revision` de la migración es `56a2cdbec89c` y el
   siguiente número de anomalía hay que re-verificarlo al registrar (H4).

Enfoque técnico, **sin dependencias nuevas** (Principio IX) y casi todo es resta:

- **Backend**: `ModuleNotInPlanError(HTTPException)` con `detail` string + `code` + `module` y su handler propio; catálogo único
  `PLAN_MODULES = (inventario, promociones)`; se quitan los 8 gates `compras`; una migración Alembic que absorbe `compras_access` en
  `inventario_access` y elimina la columna (con `downgrade()` declarado); `compras` desaparece de `GET /plan`, bootstrap y
  `/super-admin/plans`; una prueba de inventario de rutas (43 + 7) que fija SC-001.
- **Frontend**: un interceptor global + `ModuleAccessLostService` que dan **un solo** aviso y **una sola** redirección con el menú
  corregido sin recargar; guardias que avisan (salvo por plan vencido); `Proveedores` bajo el módulo; `PlanSummaryService.includes()`
  fail-closed y reactivo en las 5 superficies de carga de fondo; panel Super Admin con un solo control y confirmación al quitar Inventario.

El orden **I4 (cargas de fondo) antes de I5 (interceptor)** es una precondición funcional: con el interceptor activo, cada carga de fondo
rechazada deja de ser un error silencioso y pasa a expulsar al usuario.

## Technical Context

**Language/Version**: Backend: Python 3.12 (`Dockerfile`; el entorno local usa otra versión menor), FastAPI, SQLAlchemy 2.0, Pydantic 2,
Alembic. Frontend: TypeScript / Angular 21 (componentes standalone, signals), TanStack Query en las pantallas que ya lo usan.

**Primary Dependencies**: **Ninguna nueva** (Principio IX). Se reutilizan `HTTPException` y el despacho de handlers por MRO de Starlette,
`ToastService` (con su deduplicado de la spec 050), `ConfirmService`, `createCachedLoader` (spec 101, opción `force`), `PlanSummaryService`
y `planModuleGuard` (spec 033).

**Storage**: PostgreSQL 16, esquema `shared` + un esquema por tenant. **Un solo cambio de esquema**: eliminar `shared.plans.compras_access`
tras absorberla en `inventario_access` (migración Alembic con `downgrade`). Sin migración de datos de tenants. Detalle en [data-model.md](./data-model.md).

**Testing**: Backend: `python -m unittest discover -s app/characterization_tests -p 'test_*.py'` (SQLite en memoria; 1905 pruebas medidas en la
spec 138) más verificación de la migración contra PostgreSQL real en `BEGIN … ROLLBACK`. Frontend: `ng test` (vitest vía `@angular/build:unit-test`);
suite con fallos preexistentes de recuento variable → se compara **por nombre**. Backend y frontend completos nunca en paralelo.

**Target Platform**: API web (FastAPI, contenedor Docker en VPS; el entrypoint ejecuta `alembic upgrade head`) + aplicación web POS (Angular PWA).
Ambos en producción.

**Project Type**: Aplicación web con backend y frontend existentes (`pos-backend`, `pos-heladeria`) más el repositorio de especificaciones
(`pos-specs`). Es **cambio de comportamiento autorizado** (Principios II y IV): reemplaza la decisión 6 de la spec 033.

**Performance Goals**: N/A. El gate ya existe y lee un `Plan` por petición; no se agregan consultas. El interceptor solo inspecciona respuestas 403.

**Constraints**: (a) FR-006: ninguna lectura/escritura de datos del negocio antes del 403 → la dependencia es de router y corre antes de resolver el
cuerpo. (b) FR-007: `detail` sigue siendo string. (c) FR-011: ventas, catálogo, pedidos, cobro y menú QR nunca se bloquean. (d) FR-018: cero cambios en
datos del módulo. (e) Despliegue: backend primero; revertir código exige `alembic downgrade -1` antes.

**Scale/Scope**: 3 repositorios. Backend: 43 + 7 rutas inventariadas, 8 gates retirados, 1 excepción nueva + handler, 1 migración, 3 esquemas Pydantic,
1 servicio, 3 archivos de pruebas reescritos y 3 nuevos (+1 si se ratifica D13). Frontend: 1 carpeta nueva (`core/module-access/`: interceptor, servicio,
mensajes), 1 guardia, 1 servicio ampliado, 5 superficies de carga, 1 ítem de menú, 3 rutas, 1 pestaña, 1 página («Mi plan»), 3 archivos de Super Admin,
~10 specs con fixtures a actualizar. Documentación: 1 página pública, el SRS, el registro de anomalías.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Evaluación inicial | Evaluación tras el diseño |
|---|---|---|
| **I** — Todo nace de un spec | ✅ [spec.md](./spec.md) con alcance, 22 FR, 7 SC, 5 historias y 6 aclaraciones | ✅ Cada decisión de [research.md](./research.md) cita el FR que la origina; H1–H2 quedan cubiertas por **FR-014 enmendado** y H3 por **FR-023** (condicionado a A-153) |
| **II / XI** — Cambio de comportamiento = decisión registrada | ⚠ La spec toma 3 decisiones de negocio que **aún no** están en `registro-de-anomalias.md` | ⚠ Igual: [research D14](./research.md) fija A-150, A-151, A-152 (y A-153 si D13 se ratifica) con sus campos obligatorios. **Tarea previa a toda implementación**, verificando antes el siguiente número libre (H4). No bloquea el plan; bloquea el código |
| **III** — Los tests `CONGELA` no se tocan | ✅ Barrido de `CONGELA` + `compras_access`/`require_module_access`/`inventario_access`: solo aparece una advertencia en un docstring | ✅ Las 3 suites de planes que se reescriben declaran **no** ser characterization tests. **0 pruebas protegidas modificadas** |
| **IV** — Los specs pueden introducir comportamiento | ✅ | ✅ |
| **V** — Sin refactorizaciones oportunistas | ✅ | ✅ `PlanSummaryService.includes()` se usa **solo** en las 5 superficies que ya hay que tocar; Reportes, Ajustes y las demás no se migran. No se reorganiza el sidebar ni el `ToastService`. D13 va aislado y es retirable |
| **VI** — Evolución incremental | ✅ | ✅ Siete incrementos (I1–I7, [research D15](./research.md)) con su suite en verde y commits pequeños; la migración (I2) va separada del comportamiento (I1) |
| **VII** — Datos históricos inmutables | ✅ No se tocan facturas ni datos de tenants | ✅ La migración opera solo sobre `shared.plans`; invariantes verificables en [data-model.md](./data-model.md) §1 |
| **VIII** — Evolución del modelo de datos | ✅ Un cambio de esquema | ✅ Especificado en [data-model.md](./data-model.md): regla por plan, idempotencia, `downgrade()` con **declaración explícita** de qué recupera y qué no (FR-021), verificación en PostgreSQL real y regla operativa de reversión |
| **IX** — Dependencias | ✅ Ninguna nueva | ✅ Todo se resuelve con piezas existentes (research D1, D6) |
| **X** — Verificación obligatoria | ✅ | ✅ Pruebas por historia, prueba de inventario de rutas, migración contra PostgreSQL real, 12 recorridos en el [quickstart](./quickstart.md) |
| **XII** — Trazabilidad | ✅ | ✅ Necesidad → spec → A-150…A-152 → research → tareas → pruebas (mapa FR→prueba en tasks.md) |
| **XIII** — Español de Colombia | ✅ | ✅ Documentos y comentarios en español; ramas y commits en inglés |
| **XIV** — Ramas | ✅ | ✅ `feat/141-unified-inventory-module` por repositorio, desde `develop`, antes de tocar código. *(Ambos repos están hoy en `develop`.)* |
| **XV** — Commits | ✅ | ✅ Solo cuando el usuario lo pida, pequeños, en inglés, sin marcas de IA |

**Resultado**: pasa. No hay violaciones sin justificar. Dos observaciones abiertas, ninguna bloquea el diseño: (1) registrar las decisiones de
negocio antes del primer commit de código; (2) la **ratificación de D13** (importación/exportación de productos), que la spec cubre de forma condicionada (FR-023) y que viaja aislada.

## Project Structure

### Documentation (this feature)

```text
specs/141-modulo-inventario-unificado/
├── spec.md                              # Especificación (aclarada el 2026-10-31)
├── plan.md                              # Este archivo
├── research.md                          # Fase 0: reconfirmación, hallazgos H1–H5, decisiones D1–D17
├── data-model.md                        # Fase 1: shared.plans, migración, reversión, invariantes, estado del cliente
├── quickstart.md                        # Fase 1: línea base, escenarios Q1–Q12, despliegue y reversión
├── contracts/
│   ├── modulo-no-incluido-api.md        # 403 MODULE_NOT_IN_PLAN: cuerpo, precedencia, API interna
│   ├── planes-api.md                    # GET /plan, bootstrap y /super-admin/plans sin `compras` (incompatible)
│   ├── inventario-de-rutas.md           # Tabla módulo→rutas (43 + 7) que recorre la prueba de SC-001
│   └── frontend-acceso-modulos.md       # Interceptor, servicio, barrido de cargas, menú, guardias, Super Admin
├── checklists/requirements.md
└── tasks.md                             # Fase 2 (/speckit-tasks — NO lo crea este comando)
```

### Source Code (repository root)

```text
pos-backend/
├── alembic/versions/
│   └── <hash>_141_plans_unify_inventory_module.py   # NUEVA — solo shared.plans; down_revision = 56a2cdbec89c (re-verificar con `alembic heads`)
├── app/core/
│   ├── exceptions.py                                # + ModuleNotInPlanError(HTTPException)
│   ├── plan_limits.py                               # + PLAN_MODULES; ensure_/has_/require_module_access validan la clave; require_… expone .module_key
│   └── error_middleware.py                          # + registro del handler de ModuleNotInPlanError (el de super-admin no se toca)
├── app/main.py                                      # llama al registro del handler
├── app/models/plan.py                               # − compras_access
├── app/api/v1/
│   ├── inventory/router.py                          # − 8 × require_module_access("compras")
│   ├── plan/{service.py,schemas.py}                 # modules sin `compras`
│   ├── super_admin/schemas.py                       # PlanCreate/PlanUpdate/PlanResponse sin compras_access
│   └── products/{import_.py,export.py}              # I7 (D13, opcional): compuerta a nivel de campo
└── app/characterization_tests/
    ├── test_plan_module_access.py                   # REESCRIBIR (sin `compras`; fija code/module)
    ├── test_plan_summary.py                         # 1 línea (sin `compras`)
    ├── test_super_admin_plans.py                    # 1 línea (sin `compras_access`)
    ├── test_module_not_in_plan_error.py             # NUEVA
    ├── test_module_route_inventory.py               # NUEVA
    ├── test_plans_migration_141.py                  # NUEVA
    └── (test_products_import_module_gate.py)        # NUEVA solo con I7

pos-heladeria/src/app/
├── app.config.ts                                    # + moduleAccessInterceptor (último)
├── core/
│   ├── module-access/                               # NUEVA carpeta
│   │   ├── module-access.interceptor.ts (+ .spec)
│   │   ├── module-access-lost.service.ts (+ .spec)
│   │   └── module-access.messages.ts
│   ├── guards/plan-module.guard.ts                  # aviso por módulo, no por vencido; hidrata el resumen
│   └── config/navigation.config.ts                  # Proveedores: moduleKey 'inventario'
└── modules/
    ├── plan/{services/plan-summary.service.ts,interfaces/plan-summary.interface.ts,pages/plan-summary-page.component.ts}
    │                                                # + includes(), markModuleMissing(); ModuleAccess sin `compras`; etiquetas de «Mi plan»
    ├── dashboard/{routes.ts,pages/admin-dashboard.component.ts}   # guardias en proveedores; «Stock bajo» reactivo
    ├── inventory/pages/inventory-page.component.ts  # − comprasIncluido
    ├── products/pages/product-form.component.ts     # carga de unidades reactiva
    ├── option-groups/{pages/option-groups-page.component.ts,components/option-form.component.ts}   # cargas reactivas
    ├── tables/services/pos-terminal.store.ts        # loadActive() solo con Promociones
    └── super-admin/{interfaces/plan.interface.ts,components/plan-form.component.ts,pages/plans-page.component.ts}
                                                     # un solo control + confirmación; chips sin Compras

pos-specs/
├── specs/000-reconocimiento/registro-de-anomalias.md   # + A-150…A-152 (A-153 con I7)
├── specs/033-planes-suscripcion-tenant/research.md     # nota «Decisión 6 sustituida por 141» (con aprobación)
├── docs-publicos/06-administracion-global/gestion-de-tenants-y-planes.md   # tres módulos → dos
└── srs/README.md (+ lo que cite `compras` como módulo)
```

**Structure Decision**: aplicación web con dos repos de código ya existentes; no se crean proyectos ni capas. Lo único nuevo es una carpeta
pequeña en el front (`core/module-access/`), junto a `core/integrity/` (spec 134), que ya sigue el mismo patrón interceptor + servicio + mensajes.

## Incrementos de entrega

| # | Incremento | Repo | Cubre | Verificación de cierre |
|---|---|---|---|---|
| I1 | Error `MODULE_NOT_IN_PLAN`, catálogo único, 8 gates menos, prueba de inventario de rutas | backend | US2, FR-005–FR-011, SC-001 | 3 suites nuevas/reescritas + E2E `TestClient`; suite del backend completa |
| I2 | Migración y contratos de planes sin `compras` | backend | US1 (datos), FR-019–FR-022, SC-006 | Q1 y Q6 contra PostgreSQL real; `upgrade`/`downgrade`/`upgrade` |
| I3 | Contrato del front, menú, guardias, pestaña Compras, «Mi plan» | frontend | US3, US4, FR-012, FR-013, FR-015, FR-017 | Q7 y Q8; specs de menú y guardia |
| I4 | Cargas de fondo fail-closed y reactivas (5 superficies) | frontend | FR-014 (ampliado) | «0 peticiones sin módulo» por superficie; Q7 recarga dura |
| I5 | Interceptor + `ModuleAccessLostService` | frontend | US5, FR-016, SC-003 | Q9; «5 rechazos → 1 aviso» |
| I6 | Panel Super Admin: un control + confirmación | frontend | US1.6–1.9, FR-019, SC-007 | Q10 |
| I7 | *(opcional, D13)* Importación/exportación de productos respeta el módulo | backend | FR-023 (A-153), H3 | Q12 |

Regla de orden: **I4 antes de I5**. I3 e I6 no dependen de I5. I1 va antes de I2 para que el catálogo de módulos exista antes de retirar la columna.
Las excepciones ratificables (I7) viajan en commits propios y revertibles, como A-147/A-148 en la spec 138.

## Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| Una carga de fondo olvidada expulsa al usuario cuando el interceptor entre en producción | Barrido de 5 superficies con pruebas «0 peticiones», orden I4 → I5 obligatorio, regla de revisión en [frontend-acceso-modulos.md](./contracts/frontend-acceso-modulos.md) §4 |
| Código anterior contra el esquema nuevo (columna eliminada) | Regla operativa en [quickstart.md](./quickstart.md): `alembic downgrade -1` antes de volver a la imagen anterior; backend primero, worker reiniciado |
| Planes (Inventario sí, Compras no) ganan acceso sin haberlo contratado | Decisión de negocio 2 de la spec, aceptada; se anota el recuento previo (`group by`) antes de desplegar para que el dueño sepa qué planes cambiaron |
| Toasts propios de pantallas con texto fijo duplican el aviso | `detail` reescrito + deduplicado del `ToastService`; tarea de auditoría de los `toast.error` de texto fijo del módulo (research D7) |
| Una ruta nueva bajo un prefijo del módulo se publica sin la dependencia | La prueba de inventario de rutas falla (y también si aparece una ruta fuera de la tabla con dependencia de módulo) |
| Pestañas con el bundle viejo durante el despliegue | `compras_access` entrante se ignora (sin 422); `modules.compras` ausente oculta la pestaña hasta el auto-recargo (spec 134) |

## Complexity Tracking

> Sin violaciones de la Constitución que justificar. H1 y H2 quedan cubiertas por FR-014 (enmendado el 2026-10-31 tras `/speckit-analyze` para
> nombrar las cargas de fondo); H3 por FR-023, condicionado a la ratificación de A-153, con D13 aislado y retirable.
