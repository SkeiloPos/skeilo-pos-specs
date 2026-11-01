---

description: "Lista de tareas de la spec 141 — Módulo Inventario unificado en el control de acceso por plan"
---

# Tasks: Módulo Inventario unificado (Inventario + Proveedores + Compras) en el control de acceso por plan

**Input**: documentos de diseño en `/specs/141-modulo-inventario-unificado/`

**Prerrequisitos**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: **incluidos.** La spec fija criterios medibles (SC-001: «el 100 % de las rutas rechaza»; SC-003: «un solo aviso con N rechazos») que solo se demuestran con pruebas, y el Principio X de la constitución exige verificación. Ningún test afectado lleva el prefijo `CONGELA` (research R0): las pruebas de planes que se reescriben declaran en su docstring que **no** son characterization tests. **0 pruebas protegidas modificadas** (Principio III).

**Organización**: por historia de usuario. Las dos historias P1 de backend se ordenan **US2 → US1** porque el catálogo de módulos y la retirada de los 8 gates `compras` (US2) deben existir antes de eliminar la columna `compras_access` (US1); ver «Dependencias». El orden de los incrementos del plan (I1…I7) se conserva dentro de cada fase y se indica entre corchetes.

## Formato: `[ID] [P?] [Story] Descripción`

- **[P]**: se puede ejecutar en paralelo (archivos distintos, sin dependencia de una tarea incompleta)
- **[Story]**: historia de la spec (US1…US5). Setup, Foundational y Polish no llevan etiqueta. `[D13]` marca la extensión opcional de la Phase 8 (FR-023, condicionada a A-153)
- Las rutas son relativas a la raíz de cada repositorio hermano de `pos-specs`: `pos-backend/…` y `pos-heladeria/…` (equivalen a `../pos-backend/…` y `../pos-heladeria/…` desde `pos-specs`). `pos-specs/…` es este repositorio
- Pruebas del backend: `cd pos-backend && env/bin/python -m unittest discover -s app/characterization_tests -p '<patrón>'`. Pruebas del frontend: `cd pos-heladeria && ng test --include='<ruta del spec>'`
- **Regla de ejecución**: la suite completa del backend y la del frontend **nunca** corren en paralelo (reference_pos_suite_frontend_fallos_preexistentes). Los fallos del frontend se comparan **por nombre de prueba**, no por recuento
- **Commits** (Principio XV): solo cuando el usuario lo pida, pequeños, en inglés, Conventional Commits, sin marcas de IA. El plan sugiere un commit por incremento (I1…I7); I7 va en commits propios y revertibles

## Línea base (se llena en T003–T005)

| Medida | Valor |
|---|---|
| Backend `test_plan_*.py` | 34 OK (2026-10-31, rama `feat/141-unified-inventory-module` sin cambios) |
| Backend `test_super_admin_plans.py` | 5 OK |
| Backend suite completa | **2041 pruebas OK** en 125 s |
| Frontend suite completa (nombres que fallan) | 2 corridas solas: **10 archivos / 16 pruebas** fallando en cada una; 15 nombres en común y 2 intermitentes (`password-change.guard` solo en la 1.ª, `bill-summary` solo en la 2.ª). Unión de 17 nombres en `linea-base-frontend.txt` |
| Cabeza de Alembic | `56a2cdbec89c` (head), igual que `public.alembic_version` en la BD de desarrollo |
| Planes antes de migrar (`group by`) | dev: `inventario=t, compras=t, promociones=t` → **1** plan |

---

## Phase 1: Setup

**Purpose**: ramas de trabajo (Principio XIV) y línea base medible antes de tocar código.

- [X] T001 Verificar que `pos-backend` está en `develop` (`git branch --show-current`) y crear la rama `feat/141-unified-inventory-module` desde ahí, antes de modificar nada
- [X] T002 Verificar que `pos-heladeria` está en `develop` y crear la rama `feat/141-unified-inventory-module` desde ahí, antes de modificar nada
- [X] T003 Medir la línea base del backend, **sola**: `test_plan_*.py` (esperado 34 OK), `test_super_admin_plans.py` (esperado 5 OK) y la suite completa (`env/bin/python -m unittest discover -s app/characterization_tests`, ~2 min). Anotar los recuentos en la tabla «Línea base» de este archivo
- [X] T004 Medir la línea base del frontend, **sola** (sin backend en paralelo): `ng test` completo en `pos-heladeria`; guardar los **nombres** de las pruebas que fallan en `pos-specs/specs/141-modulo-inventario-unificado/linea-base-frontend.txt` y el recuento en la tabla «Línea base»
- [X] T005 Registrar el estado previo a la migración: `alembic heads` en `pos-backend` (esperado `56a2cdbec89c`, research H4 — si difiere, ajustar `down_revision` de T024) y, contra la BD de desarrollo (contenedor `pos`, usuario `admin`, base `pos_db`, ver reference_pos_dev_db_psql_tenantlocal), `select inventario_access, compras_access, promociones_access, count(*) from shared.plans group by 1,2,3`. Anotar ambos resultados en la tabla «Línea base»

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: registrar las decisiones de negocio (Principios II y XI: «tarea previa a toda implementación», plan.md) y crear la constante compartida que consumen dos historias del frontend.

**⚠️ CRITICAL**: no se escribe código de ninguna historia hasta registrar A-150…A-152.

- [X] T006 Verificar el siguiente número libre de anomalía (research H4): buscar `A-150`, `A-151`, `A-152` y `A-153` en `pos-specs/specs/000-reconocimiento/registro-de-anomalias.md` y en todas las ramas de `pos-specs` (`git grep -n "A-15[0-3]" $(git branch -a --format='%(refname:short)')`). Si alguno está tomado, usar los siguientes libres y **corregir las referencias** en `research.md` D14, `plan.md` y este archivo
- [X] T007 Registrar **A-150** («Inventario, Proveedores y Compras son un único módulo indivisible», reemplaza la decisión 6 de la spec 033; los planes con Inventario sí y Compras no pasan a incluir Proveedores y Compras) al final de `pos-specs/specs/000-reconocimiento/registro-de-anomalias.md`, con los campos de las entradas vecinas (A-147): Qué cambia, Por qué cambia, Quién y cuándo (2026-10-31, aclaraciones de la spec 141; **PENDIENTE de ratificación con el negocio**), Funcionalidades afectadas (planes, Mi plan, panel Super Admin, endpoints de compras, menú y pestañas), Riesgo asumido, Tests afectados, Clasificación y Estado
- [X] T008 Registrar **A-151** («un mismo código de error, aviso y conducta ante sesión activa para todos los módulos»: 403 `MODULE_NOT_IN_PLAN` + `module`, aviso «Esta funcionalidad no está incluida en tu plan», vuelta al inicio, menú actualizado sin recargar; Promociones adopta lo mismo, hoy redirige sin aviso) en `pos-specs/specs/000-reconocimiento/registro-de-anomalias.md`, con los mismos campos que T007
- [X] T009 Registrar **A-152** («retirada incompatible de `compras` en `GET /plan`, `GET /bootstrap` y `/super-admin/plans`», FR-022, sin período de transición) en `pos-specs/specs/000-reconocimiento/registro-de-anomalias.md`, con los mismos campos que T007
- [X] T010 [P] Crear `pos-heladeria/src/app/core/module-access/module-access.messages.ts` con `export const MODULE_NOT_IN_PLAN_MESSAGE = 'Esta funcionalidad no está incluida en tu plan';` y `export const MODULE_NOT_IN_PLAN_CODE = 'MODULE_NOT_IN_PLAN';` (contrato `frontend-acceso-modulos.md` §1: una sola fuente para guardia, interceptor, servicio y pruebas)

**Checkpoint**: decisiones registradas, ramas creadas, línea base medida.

---

## Phase 3: User Story 2 - El servidor rechaza toda operación del módulo cuando el plan no lo incluye (Priority: P1) 🎯 MVP · [I1]

**Goal**: el servidor es la única autoridad. Toda petición autenticada a una funcionalidad de Inventario (incluidas Proveedores y Compras) o Promociones, con un plan que no incluye el módulo, recibe **403** con `{detail, code: "MODULE_NOT_IN_PLAN", module}`, sin leer ni escribir datos del negocio. Proveedores y Compras dejan de exigir un indicador propio.

**Independent Test**: con un tenant cuyo plan no incluye Inventario, la prueba de inventario de rutas recorre las 43 rutas de `inventario` y las 7 de `promociones` y comprueba que todas llevan la dependencia correcta; un test HTTP de extremo a extremo comprueba el cuerpo `{detail, code, module}`, el 403 antes que el 422 y que no se tocan datos del negocio. (Q2–Q5, SC-001, SC-002.)

### Tests for User Story 2 ⚠️ (escribirlos primero; deben fallar antes de T015–T018)

- [X] T011 [P] [US2] Reescribir `pos-backend/app/characterization_tests/test_plan_module_access.py` (conservar su docstring «no son characterization tests»): eliminar el caso `compras` (docstring y líneas ~24-38) y quitar `"compras"` del bucle de la línea ~60 (`("inventario", "promociones")`); en los casos de rechazo afirmar `status_code == 403`, `detail` de tipo `str`, `code == "MODULE_NOT_IN_PLAN"` y `module` correcto (US2.1, US2.4); añadir el caso «`require_module_access("compras")` lanza `ValueError` al construirse» (research D2). No usar `compras_access` en `fx.make_plan` (todavía existe la columna; se retira en US1)
- [X] T012 [P] [US2] Crear `pos-backend/app/characterization_tests/test_module_not_in_plan_error.py` (docstring «no son characterization tests», sin `TestClient`, mismo estilo que `test_plan_module_access.py`, usando `plan_fixtures`): (a) `ensure_module_access` sin módulo lanza `ModuleNotInPlanError` (subclase de `HTTPException`, 403, `.module`, `.code`, `detail` string); (b) precedencia: plan **vencido** gana sobre módulo ausente y lanza `HTTPException` 403 **sin** `code` (FR-009, US2.5); (c) `has_module_access` no lanza, devuelve `False`/`True` y rechaza claves fuera de `PLAN_MODULES` con `ValueError`; (d) cambio de plan entre dos llamadas: con módulo → pasa; se reasigna el plan del tenant a uno sin módulo; la **siguiente** llamada ya lanza (FR-005, US5.5, SC-003); (e) el rol sigue siendo un paso aparte: con módulo y sin permiso de rol, el rechazo no lleva `code` (US2.6, FR-010)
- [X] T013 [P] [US2] Crear `pos-backend/app/characterization_tests/test_module_route_inventory.py` según el algoritmo de `contracts/inventario-de-rutas.md` («Comprobación de la prueba»): recorrer `app.routes` (importando `app.main`), agrupar por prefijo (`inventario` = `/inventory` 29, `/unit-measures` 6, `/unit-measure-groups` 6, `/reports/inventory` 1, `/reports/profitability` 1 = **43**; `promociones` = `/promotions` **7**), afirmar el conteo de cada grupo, que **cada** ruta lleva una dependencia con `call.module_key` igual al módulo esperado (`r.dependant.dependencies`), y que ninguna ruta fuera de la tabla (p. ej. `/reports/sales`, `/menu/promotions`, `/products`) lleva dependencia de módulo
- [X] T014 [US2] Añadir a `pos-backend/app/characterization_tests/test_module_not_in_plan_error.py` (tras T012) una clase de pruebas HTTP de extremo a extremo con `TestClient` (precedente: `test_bootstrap.py`, `test_operational_log.py`) que ejercita el **handler real**: una ruta de `inventario` (`GET /api/v1/inventory/suppliers`) y una de `promociones` (`GET /api/v1/promotions`) con tenant sin módulo → 403 y cuerpo exacto `{"detail": "Tu plan actual no incluye el módulo de <módulo>.", "code": "MODULE_NOT_IN_PLAN", "module": "<módulo>"}`; un `POST` con cuerpo inválido a una ruta del módulo → 403, no 422 (FR-006); el conteo de filas de las tablas del negocio no cambia (US2.2); con `Origin` permitido la respuesta lleva cabeceras CORS; y un **camino positivo (Q3, US2.3, SC-002)**: tenant con plan `inventario_access=True` y `promociones_access=False`, sin ningún indicador de Compras, donde `GET /api/v1/inventory/suppliers` y `GET /api/v1/inventory/purchases` responden 200 (prueba de que Compras ya no exige un indicador propio; las demás rutas de compras las fija T013)

### Implementation for User Story 2

- [X] T015 [US2] Añadir `ModuleNotInPlanError(HTTPException)` en `pos-backend/app/core/exceptions.py`, junto a `InsufficientStockError` y `PendingPaymentExit`: constructor `(module: str, label: str)`, `status_code=403`, `detail=f"Tu plan actual no incluye el módulo de {label}."` (siempre `str`, FR-007), atributos `module` y `code = "MODULE_NOT_IN_PLAN"` (research D1)
- [X] T016 [US2] En `pos-backend/app/core/plan_limits.py`: declarar `PLAN_MODULES = ("inventario", "promociones")`; `require_module_access`, `ensure_module_access` y `has_module_access` validan que `module_key ∈ PLAN_MODULES` (`ValueError` **al construir** la dependencia, no en la primera petición); `ensure_module_access` lanza `ModuleNotInPlanError` conservando el orden «vencido primero, luego módulo» (FR-009) y se elimina el diccionario `labels`; la función que devuelve `require_module_access` expone `.module_key` (para T013). **Aplicar junto con T017**: mientras queden `require_module_access("compras")` el router no importa
- [X] T017 [US2] Eliminar los 8 `dependencies=[Depends(require_module_access("compras"))]` de `pos-backend/app/api/v1/inventory/router.py` (líneas ~482, 500, 516, 532, 549, 566, 582 y 597: listar, crear, orden, `PUT` ×2, recibir, anular, eliminar compras). Rutas, métodos y roles no cambian (FR-010); Proveedores y Compras quedan gobernadas solo por el gate `inventario` del router (línea 40)
- [X] T018 [US2] Registrar `@app.exception_handler(ModuleNotInPlanError)` que responde `JSONResponse(status_code=403, content={"detail", "code", "module"})`: definirlo en `pos-backend/app/core/error_middleware.py` (función de registro nueva, p. ej. `register_module_error_handler(app)`; **no** tocar `register_error_handlers`, que solo cubre `/api/v1/super-admin`) y llamarlo desde `pos-backend/app/main.py` junto a `register_error_handlers` (línea ~128). Starlette elige el handler por MRO, así que el handler genérico de `HTTPException` no se altera
- [X] T019 [US2] Verificar los llamadores de campo (contrato `inventario-de-rutas.md` §«Superficies de campo»): que `products/service.py` (líneas ~213 y ~316), `catalog/router.py` (~396 y ~476) y los `has_module_access` de `orders/additions.py`, `orders/toppings.py`, `orders/consolidation.py` y `sales/complementary.py` siguen funcionando y que ningún `except HTTPException` intermedio descarta `code`/`module`. Correr **sin modificarlos** `test_plan_gating_inventory_fields.py`, `test_catalog_consumption_plan.py`, `test_plan_expiration.py` y `test_inventory_export.py`; si alguno depende del texto exacto, ajustar solo el assert con la spec 141 como autoridad
- [X] T020 [US2] Correr en `pos-backend` los archivos T011–T014 y los de T019 (todos en verde), y después la **suite completa sola**; comparar contra la línea base de T003 (no se aceptan fallos nuevos). Anotar el resultado aquí

  **Resultado (2026-10-31)**: T011–T014 en verde (`test_plan_module_access` 7, `test_module_not_in_plan_error` 19, `test_module_route_inventory` 6; en rojo antes de implementar: 63 fallos de inventario de rutas + 2 errores de importación). T019: `test_plan_gating_inventory_fields`, `test_catalog_consumption_plan`, `test_plan_expiration` y `test_inventory_export` (103 pruebas) en verde **sin modificarlos**; los `except HTTPException` de `products/service.py` y `orders/consolidation.py`/`sales/complementary.py` re-lanzan con `raise`, así que `code`/`module` se conservan. Suite completa **sola**: **2070 OK** (línea base 2041 + 29 nuevas), 0 fallos nuevos.

**Checkpoint**: US2 completa y verificable sola. Backend desplegable por sí solo: el front actual sigue leyendo `modules.compras` de `GET /plan` (aún existe) y no se rompe.

---

## Phase 4: User Story 1 - El Super Admin gestiona un único módulo «Inventario» y los planes existentes migran sin perder nada (Priority: P1) · [I2 + I6]

**Goal**: «Compras» deja de existir como módulo configurable. Una migración absorbe `compras_access` en `inventario_access` y elimina la columna (idempotente, reversible con declaración explícita de qué no se recupera); `compras` desaparece de `GET /plan`, bootstrap y `/super-admin/plans`; el panel Super Admin muestra un solo control «Inventario» (con ayuda «Incluye Proveedores y Compras») y pide confirmación al quitarlo de un plan existente; «Mi plan» no lista «Compras».

**Independent Test**: sembrar planes en las cuatro combinaciones (Inventario/Compras), ejecutar el paso de datos y comprobar el resultado, la idempotencia y el `downgrade`; abrir el panel de planes y «Mi plan» y confirmar que «Compras» no aparece. (Q1, Q6, Q10, SC-006, SC-007.)

**Depende de**: US2 (T016–T017 antes de eliminar la columna).

### Tests for User Story 1 ⚠️ (backend)

- [X] T021 [P] [US1] Crear `pos-backend/app/characterization_tests/test_plans_migration_141.py`: cargar el módulo de la migración por ruta con `importlib` (el nombre de archivo lleva hash) y probar la función pura `merge_compras_into_inventario(connection, schema=None)` sobre SQLite con una tabla `plans` mínima y sin esquema (contra PostgreSQL real, T029, se usa el valor por defecto `"shared"`): las 4 combinaciones (no,no)→no, (no,sí)→**sí**, (sí,no)→sí, (sí,sí)→sí (US1.1–US1.4); `promociones_access`, límites, precios y `name` idénticos (invariante 2); `count(*)` idéntico; segunda ejecución sin cambios y sin error cuando la columna ya no existe (idempotencia, US1.5, FR-021)
- [X] T022 [P] [US1] Actualizar `pos-backend/app/characterization_tests/test_plan_summary.py` (línea ~36): `summary["modules"]` tiene **exactamente** las claves `inventario` y `promociones` (sin `compras`), y `GET /bootstrap` → `plan.modules` igual si ya hay un caso en `test_bootstrap.py`/`bootstrap_fixtures.py` que lo fije
- [X] T023 [P] [US1] Actualizar `pos-backend/app/characterization_tests/test_super_admin_plans.py` (línea ~44): quitar `assertFalse(created.compras_access)`; añadir que la respuesta de crear/listar no contiene `compras_access` y que un `PlanCreate`/`PlanUpdate` que **incluye** `compras_access` se acepta e ignora sin error de validación (research H5)

### Implementation for User Story 1 (backend)

- [X] T024 [US1] Crear `pos-backend/alembic/versions/<hash>_141_plans_unify_inventory_module.py` (`alembic revision -m "141_plans_unify_inventory_module"`; confirmar `down_revision = '56a2cdbec89c'` con T005). `merge_compras_into_inventario(connection, schema)` pura, con esta forma (la comprobación de la columna con `sa.inspect` y el nombre de tabla calificado por `schema` permiten probarla en SQLite con `schema=None` y en PostgreSQL con `"shared"`):

  ```python
  def merge_compras_into_inventario(connection, schema: str | None = "shared") -> None:
      cols = {c["name"] for c in sa.inspect(connection).get_columns("plans", schema=schema)}
      if "compras_access" not in cols:
          return                                   # idempotente
      plans = sa.table("plans", sa.column("inventario_access", sa.Boolean),
                       sa.column("compras_access", sa.Boolean), schema=schema)
      connection.execute(plans.update()
          .where(plans.c.compras_access.is_(True), plans.c.inventario_access.is_(False))
          .values(inventario_access=True))
  ```

  `upgrade()` llama `merge_compras_into_inventario(op.get_bind())` y después `op.drop_column("plans", "compras_access", schema="shared")`, solo si la columna existe (no-op si ya no); `downgrade()` hace `add_column` `compras_access boolean NOT NULL DEFAULT false` (si falta) y `UPDATE … SET compras_access = inventario_access`. Solo esquema `shared`: **no** usar `for_each_tenant_schema`. El docstring declara qué recupera y qué no el `downgrade()` (data-model §2, FR-021, Principio VIII)
- [X] T025 [P] [US1] Eliminar `compras_access` del modelo `pos-backend/app/models/plan.py` (línea ~38) y actualizar su docstring de «tres accesos de módulo» a «dos»
- [X] T026 [P] [US1] En `pos-backend/app/api/v1/plan/schemas.py`, `ModuleAccess` (líneas 13-16) pasa a `inventario` y `promociones`
- [X] T027 [P] [US1] En `pos-backend/app/api/v1/plan/service.py` (línea ~34), quitar `"compras": plan.compras_access` de `modules` (lo reutiliza `GET /bootstrap` vía `build_plan_summary`)
- [X] T028 [P] [US1] Quitar `compras_access` de `PlanCreate`, `PlanUpdate` y `PlanResponse` en `pos-backend/app/api/v1/super_admin/schemas.py` (líneas ~143, 166, 185). No añadir `extra="forbid"`: el campo entrante debe ignorarse (H5)
- [X] T029 [US1] Verificar el paso de datos contra **PostgreSQL real** dentro de `BEGIN … ROLLBACK` (Q1): sembrar 4 planes `[141-test]` con las combinaciones, ejecutar `merge_compras_into_inventario`, comprobar `inventario_access` = no/**sí**/sí/sí, `count(*)` de `shared.plans`, `tenants.plan_id`/`ciclo_facturacion`/`plan_iniciado_en`/`plan_vence_en` y los recuentos de `inventory_items`, `inventory_movements`, `suppliers`, `supplier_items`, `purchases`, `purchase_items` e `inventory_import_jobs` del esquema `tenantlocal` idénticos antes y después; repetir el paso (idempotencia)

  **Resultado (2026-10-31)**: verificado contra PostgreSQL real en `BEGIN … ROLLBACK` (script desechable, no versionado): las 4 combinaciones dan (no,no)→no, (no,sí)→**sí**, (sí,no)→sí, (sí,sí)→sí; idempotente; nombre/límites/precios/`promociones_access` idénticos; `upgrade()` completo (con `DROP COLUMN`) y `downgrade()` (columna `NOT NULL` recreada con `compras_access = inventario_access`) dentro de la misma transacción; `count(*)` de planes (+5 sembrados), `tenants` y los recuentos de las 7 tablas de módulo de los 3 esquemas de tenant (`skeilo`, `heladeria`, `tenantlocal`) idénticos; tras el `ROLLBACK` no quedó ningún plan `[141-test]` y la columna sigue existiendo.
- [X] T030 [US1] Ciclo completo en la BD de desarrollo: `alembic upgrade head` → comprobar que `shared.plans.compras_access` ya no existe; `alembic downgrade -1` → la columna reaparece con `= inventario_access`; `alembic upgrade head` → mismo estado final. Anotar el `group by` posterior y compararlo con el de T005

  **Resultado (2026-10-31)**: `upgrade` → `shared.plans` sin `compras_access`, `group by (inventario, promociones)` = `(t,t,1)`; `downgrade -1` → columna de vuelta con `(t,t,t,1)` (= `inventario_access`); `upgrade` final → mismo estado que tras el primero. **La BD de desarrollo queda en `30cd5f4a8fd6` (cabeza de la spec 141)**: para volver a código anterior (p. ej. `develop`) hay que correr `alembic downgrade -1` antes.
- [X] T031 [US1] Comprobar que el esquema OpenAPI no contiene `compras_access` ni `modules.compras` (Q6): script desechable en el directorio temporal de la sesión que importa `app.main.app`, serializa `app.openapi()` y falla si aparece la cadena; verificar además `POST`/`PATCH /super-admin/plans` con `compras_access` en el cuerpo → 2xx

  **Resultado (2026-10-31)**: el OpenAPI no contiene la cadena `compras_access`; `ModuleAccess` = `[inventario, promociones]`; `PlanResponse`, `PlanCreate` y `PlanUpdate` sin el campo. Con la aplicación real y `get_shared_db`/`get_current_super_admin` sustituidos: `POST /super-admin/plans` con `compras_access` en el cuerpo → 201 sin el campo en la respuesta; `PATCH` → 200 con `mesas_limit` aplicado; `GET` → 200.
- [X] T032 [US1] Correr en `pos-backend` `test_plans_migration_141.py`, `test_plan_summary.py`, `test_super_admin_plans.py`, `test_plan_module_access.py`, `test_module_route_inventory.py` y `test_bootstrap.py` (en verde) y luego la **suite completa sola** contra la línea base de T003

  **Resultado (2026-10-31)**: los 6 archivos listados en verde (40 pruebas) y la suite completa **sola**: **2081 OK** en 4 corridas consecutivas (línea base 2041 + 40 nuevas). Una corrida anterior (la primera tras esta tarea) tuvo **1 error intermitente** (`AttributeError: 'float' object has no attribute 'replace'` al construir un `UUID`) que no pude identificar porque no guardé su salida y **no se reprodujo** en las 4 corridas siguientes (todas con salida guardada); no es atribuible a esta spec, queda anotado.

### Tests for User Story 1 ⚠️ (frontend)

- [X] T033 [P] [US1] Crear `pos-heladeria/src/app/modules/plan/pages/plan-summary-page.component.spec.ts`: con un resumen cuyo `modules` es `{inventario, promociones}`, la página lista **2** módulos con sus etiquetas y ningún «Compras» (US1.7). Seguir el patrón de los specs vecinos (`makeSummary`, `PlanSummaryService` falso con signal)
- [X] T034 [P] [US1] Crear `pos-heladeria/src/app/modules/super-admin/components/plan-form.component.spec.ts`: (a) el formulario ofrece un solo interruptor «Inventario» con la ayuda «Incluye Proveedores y Compras» y ningún «Compras» (US1.6); (b) editar un plan con `inventario_access: true`, desmarcarlo y guardar llama a `ConfirmService.ask` con el texto exacto «Los negocios con este plan perderán Inventario, Proveedores y Compras de inmediato» y `tone: 'danger'`; si devuelve `false` **no** se llama al servicio y el formulario queda abierto; si devuelve `true` se guarda (US1.8); (c) editar sin desmarcar, crear un plan nuevo y quitar solo «Promociones» guardan **sin** llamar a `ask` (US1.9); (d) el payload no contiene `compras_access`
- [X] T035 [P] [US1] Crear `pos-heladeria/src/app/modules/super-admin/pages/plans-page.component.spec.ts`: los chips de módulos de un plan muestran «Inventario» y «Promociones» y nunca «Compras» (contrato `frontend-acceso-modulos.md` §6)

### Implementation for User Story 1 (frontend)

- [X] T036 [P] [US1] `pos-heladeria/src/app/modules/plan/interfaces/plan-summary.interface.ts`: `ModuleAccess` pasa a `{ inventario: boolean; promociones: boolean }` (línea ~11 elimina `compras`). A partir de aquí el compilador señala toda lectura restante
- [X] T037 [US1] `pos-heladeria/src/app/modules/plan/pages/plan-summary-page.component.ts`: quitar `compras: 'Compras'` del mapa de etiquetas (línea ~15) y `'compras'` de la unión de tipos (línea ~116) (US1.7, FR-019)
- [X] T038 [US1] `pos-heladeria/src/app/modules/inventory/pages/inventory-page.component.ts`: eliminar `comprasIncluido` (líneas ~874-879) y sus dos usos (`@if (comprasIncluido())` ~107 y `tab() === 'purchases' && comprasIncluido()` ~510), de modo que la pestaña «Compras» y su contenido se vean siempre que se entra a Inventario (research D11, FR-013). Se etiqueta US1 porque es el efecto de compilación de T036; la **prueba** de la pestaña (US3.5) está en T051. Revisar también `inventory-page.component.spec.ts` por si fija `comprasIncluido`
- [X] T039 [P] [US1] `pos-heladeria/src/app/modules/super-admin/interfaces/plan.interface.ts`: quitar `compras_access` de `Plan` (línea ~16) y de `PlanCreatePayload` (línea ~40)
- [X] T040 [P] [US1] `pos-heladeria/src/app/modules/super-admin/pages/plans-page.component.ts` (línea ~121): quitar el chip `plan.compras_access && 'Compras'`
- [X] T041 [US1] `pos-heladeria/src/app/modules/super-admin/components/plan-form.component.ts`: quitar el control `compras_access` (líneas ~101, 173, 185, 215); dejar el interruptor «Inventario» con texto de ayuda «Incluye Proveedores y Compras». En el guardado, **solo** si el formulario edita un plan (`this.plan` definido), `this.plan.inventario_access === true` y el valor enviado es `false`, llamar `await confirm.ask({ title, message: 'Los negocios con este plan perderán Inventario, Proveedores y Compras de inmediato', tone: 'danger' })` con `ConfirmService` de `shared/feedback/confirm.service.ts`; si devuelve `false`, retornar sin llamar al servicio (research D12)
- [X] T042 [P] [US1] Actualizar los fixtures `modules: { …, compras: … }` en `pos-heladeria/src/app/core/bootstrap/bootstrap.service.spec.ts` (línea 35) y `pos-heladeria/src/app/modules/plan/services/plan-summary.service.spec.ts` (línea 21): quitar `compras`
- [X] T043 [P] [US1] Ídem en `pos-heladeria/src/app/modules/reports/services/reports.service.spec.ts` (líneas 28, 235, 254, 264) y `pos-heladeria/src/app/modules/reports/pages/reports-page.component.spec.ts` (líneas 18, 111, 156)
- [X] T044 [P] [US1] Ídem en `pos-heladeria/src/app/modules/dashboard/layout/sidebar.component.spec.ts` (líneas 33, 93, 103, 111, 129) y `pos-heladeria/src/app/modules/dashboard/layout/tenant-sidebar.component.spec.ts` (líneas 35, 169)
- [X] T045 [P] [US1] Ídem en `pos-heladeria/src/app/modules/settings/pages/settings-page.component.spec.ts` (líneas 15, 39, 48, 62) y `pos-heladeria/src/app/modules/products/pages/product-form.component.spec.ts` (líneas 38, 714, 721, 731, 744)
- [X] T046 [US1] En `pos-heladeria`: `ng build` sin errores (el tipo ya no permite leer `compras`) y correr los specs de T033–T035 y T042–T045 más `inventory-page.component.spec.ts`; todo en verde. `grep -rnE "compras_access|modules\??\.compras|comprasIncluido" src/app` no devuelve nada

  **Resultado (2026-10-31)**: `ng build` sin errores. Specs de T033–T035, T042–T045 y `inventory-page` en verde (18 archivos / 171 pruebas). `grep -rnE "compras_access|modules\??\.compras|comprasIncluido" src/app` solo encuentra las **aserciones negativas** de `plan-form.component.spec.ts` (comprueban que el control y el campo ya no existen); no queda ninguna referencia en código de producción.
- [X] T047 [US1] **Recorrido manual Q10** (panel Super Admin con API y front reales): «Nuevo plan» y «Editar plan» muestran un solo interruptor «Inventario»; la lista no muestra «Compras»; editar un plan con Inventario y desmarcarlo → diálogo con el texto fijo; **Cancelar** deja el plan igual (verificar con `GET`), **Confirmar** guarda; crear, editar sin tocar Inventario o quitar solo Promociones guardan sin diálogo. «Mi plan» de un tenant lista 2 módulos. Si no se puede ejecutar, anotarlo aquí como **pendiente** con el motivo

  **Resultado (2026-10-31), en vivo** (API nativa `uvicorn` + `ng serve` + Chrome/Playwright; Super Admin `qa141-superadmin@e2e-pos.com`, datos `[141-test]` en la BD de desarrollo): 16/16 comprobaciones. «Nuevo plan» y «Editar plan» muestran **un solo** interruptor «Inventario» con la ayuda «Incluye Proveedores y Compras» y uno de «Promociones»; la lista de planes muestra «Inventario» y «Promociones» y nunca «Compras»; crear un plan (aun marcando y desmarcando Inventario) guarda **sin** diálogo; editar un plan con Inventario y desmarcarlo abre el diálogo con el texto fijo «Los negocios con este plan perderán Inventario, Proveedores y Compras de inmediato» (rojo, botones «Cancelar»/«Confirmar»); **Cancelar** deja el plan igual en el servidor (`true,false`) y el formulario abierto; **Confirmar** guarda (`false,false`) y cierra; editar sin tocar Inventario y quitar solo Promociones guardan sin diálogo. «Mi plan» del tenant lista exactamente `Inventario` y `Promociones`. Capturas en el scratchpad de la sesión (`q10-*.png`).

**Checkpoint**: US1 completa. El contrato de planes ya no expone `compras` en backend ni frontend. Desplegar backend primero y frontend inmediatamente después (ver «Despliegue»).

---

## Phase 5: User Story 3 - El menú y las pantallas muestran solo lo que el plan incluye (Priority: P1) · [I3 + I4]

**Goal**: un tenant sin el módulo ve 0 opciones de menú del módulo (Inventario **y** Proveedores), 0 encabezados de sección vacíos y 0 elementos dependientes del módulo; y **ninguna carga de fondo** de endpoints del módulo sale cuando el plan no lo incluye (las 5 superficies de research H1/H2), para que el interceptor de US5 no expulse al usuario sin que haya hecho nada.

**Independent Test**: iniciar sesión en un tenant con módulo (P-A) y en otro sin él (P-B) y comparar menú, panel de inicio, Ajustes, Reportes y Inventario; con recarga dura en `/dashboard/products/new`, `/dashboard/ajustes/grupos-opciones` y `/dashboard/mesas-sesiones`, DevTools muestra 0 peticiones a `/unit-measures`, `/inventory/*` y `/promotions` sin módulo. (Q7, Q11, SC-004.)

**Depende de**: US1 (el tipo `ModuleAccess` sin `compras`). **Debe terminar antes que US5** (I4 antes de I5, plan.md «Regla de orden»).

### Tests for User Story 3 ⚠️ (escribirlos primero)

- [X] T048 [P] [US3] Ampliar `pos-heladeria/src/app/modules/plan/services/plan-summary.service.spec.ts` con `includes(key)`: `summary = null` → `false`; `vencido: true` → `false`; módulo ausente → `false`; módulo incluido y no vencido → `true`; es reactivo (leer dentro de un `computed`/`effect` y cambiar el signal)
- [X] T049 [P] [US3] Ampliar `pos-heladeria/src/app/modules/dashboard/layout/tenant-sidebar.component.spec.ts`: sin Inventario (`modules.inventario = false`) no aparecen «Inventario» ni «Proveedores» **y el encabezado de sección «Inventario» desaparece** (no queda bloque vacío, `groupedItems`); con módulo aparecen ambos bajo el encabezado; con `summary = null` el menú se muestra (fail-open, edge case «estado desconocido») (US3.1, US3.2, SC-004)
- [X] T050 [P] [US3] Revisar `pos-heladeria/src/app/modules/dashboard/layout/sidebar.component.spec.ts`: si `SidebarComponent` consume los mismos `NAV_ITEMS`, añadir los mismos casos que T049; si no, dejar nota «sin cambios» en la descripción de la tarea
- [X] T051 [P] [US3] Ampliar `pos-heladeria/src/app/modules/inventory/pages/inventory-page.component.spec.ts`: la pestaña «Compras» aparece siempre que el plan incluye Inventario, aunque el resumen no tenga ningún indicador adicional (US3.5)
- [X] T052 [P] [US3] Ampliar `pos-heladeria/src/app/modules/dashboard/pages/admin-dashboard.component.spec.ts` (hoy espera la petición «Stock bajo» sin mirar el plan): sin módulo → **0 peticiones** a `/inventory/items/low-stock` y sin tarjeta «Stock bajo» (US3.3); con módulo → la petición sale una vez; con el resumen que llega **después** de `ngOnInit` → la petición sale una vez cuando llega
- [X] T053 [P] [US3] Ampliar `pos-heladeria/src/app/modules/products/pages/product-form.component.spec.ts`: sin módulo → 0 peticiones a `/unit-measures` y el formulario carga completo; con el resumen tardío → una petición al llegar
- [X] T054 [P] [US3] Crear `pos-heladeria/src/app/modules/option-groups/pages/option-groups-page.component.spec.ts`: sin módulo → 0 peticiones a `/inventory/items` y `/unit-measures` y la pantalla carga los grupos; con módulo o con resumen tardío → las peticiones salen una vez
- [X] T055 [P] [US3] Ampliar `pos-heladeria/src/app/modules/option-groups/components/option-form.component.spec.ts`: ídem T054 para el formulario de adición (el selector de insumo sigue oculto por `inventarioIncluido`)
- [X] T056 [P] [US3] Ampliar `pos-heladeria/src/app/modules/tables/services/pos-terminal.store.spec.ts`: `init()` sin Promociones → **no** se llama `promotionService.loadActive()`, la terminal carga sin error y `activePromotions()` queda `[]` (sin descuentos, como hoy); con Promociones → se llama una vez; resumen tardío → se llama al llegar (research H1)

### Implementation for User Story 3

- [X] T057 [US3] Añadir `includes(key: keyof ModuleAccess): boolean` a `pos-heladeria/src/app/modules/plan/services/plan-summary.service.ts`: verdadero solo si `summary()` existe, `!vencido` y `modules[key]` es verdadero. Es el predicado **fail-closed para cargar datos** (el menú sigue **fail-open** para mostrar; `frontend-acceso-modulos.md` tabla de predicados)
- [X] T058 [P] [US3] `pos-heladeria/src/app/core/config/navigation.config.ts` (ítem `Proveedores`, líneas ~106-113): añadir `moduleKey: 'inventario'` (FR-012). El encabezado de sección desaparece sin código nuevo (research D9)
- [X] T059 [US3] `pos-heladeria/src/app/modules/dashboard/pages/admin-dashboard.component.ts`: quitar `this.inventoryService.loadLowStock()` de `ngOnInit` (línea ~590) y lanzarlo desde un `effect` que se ejecute cuando `planSummaryService.includes('inventario')` sea verdadero (una sola vez); la tarjeta «Stock bajo» (~298-306) usa la misma condición (FR-014, US3.3)
- [X] T060 [P] [US3] `pos-heladeria/src/app/modules/products/pages/product-form.component.ts` (línea ~1218): condicionar `loadUnitMeasures()` a `includes('inventario')` mediante `effect` (reactivo: en recarga directa el resumen puede llegar después de `ngOnInit`, research D10)
- [X] T061 [P] [US3] `pos-heladeria/src/app/modules/option-groups/pages/option-groups-page.component.ts` (líneas ~226-229): condicionar `loadAllItems()` y `loadUnitMeasures()` a `includes('inventario')` mediante `effect`
- [X] T062 [P] [US3] `pos-heladeria/src/app/modules/option-groups/components/option-form.component.ts` (líneas ~160-163): ídem T061 (inyectar `PlanSummaryService`; el `@Input() inventarioIncluido` actual solo oculta el selector, no impide la carga)
- [X] T063 [P] [US3] `pos-heladeria/src/app/modules/tables/services/pos-terminal.store.ts` (`init()`, línea ~1466): condicionar `promotionService.loadActive()` a `includes('promociones')` y garantizar que, si el resumen llega después, la carga ocurre una vez al llegar; la terminal **no** se interrumpe ni muestra error sin Promociones (research H1, FR-011)
- [X] T064 [US3] Barrido de la «regla de revisión» (`frontend-acceso-modulos.md` §4): buscar en `pos-heladeria/src/app` toda llamada a los endpoints de `inventario-de-rutas.md` (`/inventory`, `/unit-measures`, `/unit-measure-groups`, `/reports/inventory`, `/reports/profitability`, `/promotions`) y sus servicios (`InventoryService`, `UnitMeasureService`, `PromotionService`, `reports.service.ts`) e identificar quién los llama **fuera de las pantallas del módulo**. Confirmar que Reportes (`reports.service.ts`) y Ajustes (`settings-page.component.ts`) ya cumplen el patrón y que no queda otra carga incondicional; si aparece una, corregirla con `includes(...)` y añadir su prueba. Anotar el resultado en esta tarea

  **Resultado (2026-10-31)**: barrido de `InventoryService`, `UnitMeasureService`, `UnitMeasureGroupService` y `PromotionService` fuera de sus módulos: solo aparecen las 5 superficies de T059–T063 (panel de inicio, formulario de producto, grupos de opciones, formulario de adición, Terminal de mesas). El resto de consumidores son pantallas del propio módulo (`inventory/`, `unit-measures/`, `supplier-items/`, `promotions/`), todas detrás de `planModuleGuard`. Reportes (`inventarioIncluido`, `enabled:` de las dos consultas) y Ajustes (pestaña «Unidades de medida» con `moduleKey`) ya cumplen el patrón y **no se tocaron**; `PromotionService.loadActive()` solo lo llama la Terminal y la pantalla de Promociones. Las lecturas de `searchActiveItems`/`resolveMissingItems` de `product-form` ocurren desde el selector de la receta (acción del usuario, sección oculta sin el módulo), no en segundo plano. Sin hallazgos nuevos.
- [X] T065 [US3] En `pos-heladeria`: correr los specs de T048–T056 más los de Ajustes y Reportes (`settings-page.component.spec.ts`, `reports*.spec.ts`) en verde y `ng build` sin errores

  **Resultado (2026-10-31)**: specs de T048–T056 (+ Ajustes y Reportes) en verde: `plan-summary.service` (`includes`), sidebars, `inventory-page`, `admin-dashboard` (4 pruebas nuevas de «Stock bajo» según el plan), `product-form` (3), `option-groups-page` (3, spec nuevo), `option-form` (3) y `pos-terminal.store` (4); el único fallo del lote es el preexistente `saveOrder() con dos líneas hermanas…` (`linea-base-frontend.txt`). `ng build` sin errores. Dos pruebas existentes se actualizaron con la spec 141 como autoridad: la de `tenant-sidebar` que fijaba «Proveedores» visible sin Inventario (spec 116) y las de «Stock bajo» del panel de inicio (ahora fijan el plan antes de montar).
- [X] T066 [US3] **Recorrido manual Q7** (tenant P-A con módulo vs. P-B sin módulo, y en `springfieldgranizados` si hay acceso al entorno desplegado): menú con y sin «Inventario»/«Proveedores»/encabezado; pestaña «Compras» y vista de nueva compra operan sin errores de permisos; panel de inicio sin tarjeta y, en DevTools › Red, **0** peticiones a `/inventory/*` sin módulo; Ajustes sin «Unidades de medida», Reportes sin bloque de stock, formularios sin campos de receta. Repetir con **recarga dura** en `/dashboard/products/new`, `/dashboard/ajustes/grupos-opciones` y `/dashboard/mesas-sesiones`. Si no se puede ejecutar, anotarlo como **pendiente** con el motivo

  **Resultado (2026-10-31), en vivo** (tenant `tenantlocal`; P-A = «Ilimitado (transición)», P-B = «[141-test] Sin módulos»): Con P-A: menú con «Inventario» y «Proveedores» bajo el encabezado «Inventario», 1 petición a `/inventory/items/low-stock` en el panel de inicio, pestaña «Compras» visible y operativa (sin 403) y Proveedores carga. Con P-B, **recarga dura** en `/dashboard/admin`, `/dashboard/products/new`, `/dashboard/ajustes/grupos-opciones` y `/dashboard/mesas-sesiones`: **0 peticiones** a `/inventory`, `/unit-measures`, `/unit-measure-groups` ni `/promotions` en cada una (y 0 en Reportes: sin `/reports/inventory` ni `/reports/profitability`), ningún 403, ningún aviso, ninguna expulsión; el menú no muestra «Inventario», «Proveedores» ni el encabezado «Inventario»; sin tarjeta «Stock bajo»; Ajustes sin la pestaña «Unidades de medida»; el formulario de producto carga completo con su sección 3 «Tu plan actual no incluye el módulo de inventario». *No ejecutado*: `springfieldgranizados` (no existe en dev; queda para después del despliegue, T101). Una aserción mía («carga completo» contando `<input>`) falló por ser ingenua; la captura `q7-pb-product-form.png` muestra el formulario completo.
- [ ] T067 [US3] **Recorrido manual Q11** (regresión de H1/H2, FR-011): tenant P-B sin módulo — crear un producto, tomar un pedido en la Terminal de mesas y cobrarlo; todo funciona, no se descuenta stock y no aparece aviso alguno. Si no se puede ejecutar, anotarlo como **pendiente** con el motivo

  **PARCIAL — se deja `[ ]` (2026-10-31)**: con P-B se creó un producto **por la UI** (`/dashboard/products/new`, categoría de prueba) y quedó guardado; la creación no disparó ninguna petición de módulo, ningún 403 ni aviso; la Terminal de mesas abre sin aviso, sin 403 y sin peticiones de módulo. **Sin ejecutar: tomar un pedido en la Terminal y cobrarlo.** Motivo: `tenantlocal` está vacío (0 mesas, 0 cajas, 0 métodos de pago, 0 categorías) y cobrar exigiría sembrar todo eso y dejar una venta inmutable (Principio VII) en la BD de desarrollo; `heladeria` tiene datos reales de desarrollo y no se tocó. Lo que sí respalda ese camino: ninguna ruta del cobro lleva dependencia de módulo (`test_module_route_inventory.py`), y `has_module_access` (descuento de stock) no lanza sin módulo (specs 123/064, sus pruebas en verde). El producto y la categoría de prueba se borraron.

**Checkpoint**: US3 completa. Sin módulo no sale ninguna petición de fondo a los endpoints del módulo: precondición cumplida para US5.

---

## Phase 6: User Story 4 - Entrar por URL directa a una pantalla no incluida en el plan (Priority: P2) · [I3]

**Goal**: abrir por URL directa Proveedores (y su detalle), Inventario (y su detalle), nueva compra, Unidades de medida o Promociones en un tenant sin el módulo bloquea la carga, lleva al inicio y muestra **«Esta funcionalidad no está incluida en tu plan»**. Con plan vencido se conserva la vuelta al inicio **sin** ese aviso.

**Independent Test**: sin el módulo, navegar manualmente a las 7 rutas y comprobar bloqueo, aviso único y redirección; con plan vencido, vuelta al inicio sin aviso; con módulo, cargan normal. (Q8, SC-005.)

### Tests for User Story 4 ⚠️

- [X] T068 [P] [US4] Crear `pos-heladeria/src/app/core/guards/plan-module.guard.spec.ts` (no existe): módulo ausente → `UrlTree('/dashboard')` **y** `toast.error(MODULE_NOT_IN_PLAN_MESSAGE)`; `vencido` → `UrlTree('/dashboard')` **sin** toast (FR-017, US4.4); `GET /plan` falla → devuelve `true` (fail-open conservado); el resumen recién pedido se pasa a `PlanSummaryService.hydrate(summary)`; módulo incluido → `true` (US4.5)
- [X] T069 [P] [US4] Crear `pos-heladeria/src/app/modules/dashboard/routes.spec.ts` (no existe): recorrer la configuración exportada de rutas del dashboard y afirmar que `proveedores`, `proveedores/:id/detalle`, `inventario`, `inventario/:id/detalle`, `inventario/compras/nueva` y `ajustes/unidades` tienen `planModuleGuard('inventario')` y `promotions` tiene `planModuleGuard('promociones')` en `canActivate` (SC-005, US4.1–US4.3). Si no se puede identificar el guard por referencia, comparar por la fábrica o el nombre del módulo que devuelve

  **Nota de implementación**: `planModuleGuard` devuelve la guardia con una propiedad `moduleKey` (como `.module_key` en el backend); `routes.spec.ts` identifica con ella qué módulo gobierna cada ruta y además fija que **ninguna otra** ruta del panel lleva guardia de módulo.

### Implementation for User Story 4

- [X] T070 [US4] `pos-heladeria/src/app/core/guards/plan-module.guard.ts`: inyectar `ToastService` (`shared/feedback/toast.service.ts`); al bloquear **por módulo**, `toast.error(MODULE_NOT_IN_PLAN_MESSAGE)` (T010) y devolver `UrlTree('/dashboard')`; al bloquear **por `vencido`**, devolver el `UrlTree` sin aviso; hidratar `planSummaryService.hydrate(summary)` con el resumen que de todos modos acaba de pedir (research D8); conservar `catchError(() => of(true))`
- [X] T071 [US4] `pos-heladeria/src/app/modules/dashboard/routes.ts` (líneas ~249-262): añadir `planModuleGuard('inventario')` a `canActivate` de `proveedores/:id/detalle` y de `proveedores`, quedando `[roleGuard([UserRole.ADMIN]), planModuleGuard('inventario')]` como en `inventario` (FR-015)
- [X] T072 [US4] En `pos-heladeria`: correr T068–T069 más los specs de guardias existentes en verde y `ng build` sin errores

  **Resultado (2026-10-31)**: `plan-module.guard.spec.ts` (9 pruebas) y `routes.spec.ts` (10) en verde junto con las demás guardias; `ng build` sin errores.
- [X] T073 [US4] **Recorrido manual Q8**: sin el módulo, pegar en la barra `/dashboard/proveedores`, `/dashboard/proveedores/<id>/detalle`, `/dashboard/inventario`, `/dashboard/inventario/<id>/detalle`, `/dashboard/inventario/compras/nueva`, `/dashboard/ajustes/unidades` y `/dashboard/promotions`: en cada una aterriza en el inicio con **un** aviso; con plan vencido, vuelta al inicio sin aviso; con módulo, cargan normal. Si no se puede ejecutar, anotarlo como **pendiente** con el motivo

  **Resultado (2026-10-31), en vivo**: sin el módulo (P-B), pegar en la barra cada una de `/dashboard/proveedores`, `/dashboard/proveedores/<id>/detalle`, `/dashboard/inventario`, `/dashboard/inventario/<id>/detalle`, `/dashboard/inventario/compras/nueva`, `/dashboard/ajustes/unidades` y `/dashboard/promotions` aterriza en `/dashboard/admin` con **exactamente un** aviso «Esta funcionalidad no está incluida en tu plan» y sin pedir datos del módulo (14/14). Con **plan vencido** (P-A con `plan_vence_en` pasado): `/dashboard/inventario`, `/dashboard/proveedores` y `/dashboard/promotions` vuelven al inicio **sin aviso** (3/3). Con módulo y plan vigente: las 6 rutas probadas cargan en su ruta, sin aviso (6/6). Captura `q8-aviso.png`.

**Checkpoint**: US4 completa. Las rutas bloquean y avisan; el aviso global durante una sesión activa llega con US5.

---

## Phase 7: User Story 5 - Un tenant pierde el módulo mientras tiene la sesión abierta (Priority: P2) · [I5]

**Goal**: cuando una acción del usuario recibe `MODULE_NOT_IN_PLAN`, la aplicación muestra **un solo** aviso, hace **una sola** redirección al inicio y corrige el menú **sin recargar**, aunque varias peticiones sean rechazadas a la vez o en sucesión. Los datos se conservan (garantía de US2/FR-018).

**Independent Test**: con una sesión abierta en Inventario o Proveedores, cambiar el plan a uno sin Inventario y ejecutar cualquier acción: un aviso, una redirección, menú corregido; volver a asignar el plan con módulo y comprobar que los datos reaparecen. (Q5, Q9, SC-003.)

**Depende de**: US3 (cargas de fondo ya corregidas) y US4 (aviso de la guardia, ya activo).

- [X] T074 [US5] **Compuerta de precondición**: confirmar que T057–T064 están `[x]` y que el barrido de T064 no dejó cargas de fondo sin condicionar. Si no, **no** continuar: con el interceptor activo cada carga de fondo rechazada expulsaría al usuario (plan.md, riesgo 1)

  **Compuerta superada (2026-10-31)**: T057–T064 están `[X]` y el barrido de T064 no dejó cargas de fondo sin condicionar.

### Tests for User Story 5 ⚠️

- [X] T075 [P] [US5] Crear `pos-heladeria/src/app/core/module-access/module-access.interceptor.spec.ts`: 403 con `error.code === 'MODULE_NOT_IN_PLAN'` → llama a `ModuleAccessLostService.handle(error.module)` y **relanza** un `HttpErrorResponse` cuyo `error.detail === MODULE_NOT_IN_PLAN_MESSAGE` conservando `code` y `module`; 403 **sin** código (vencido, rol, límite) → intacto y sin llamar al servicio; otros estados (401, 404, 422, 500) → intactos; URL fuera de `environment.apiBaseUrl` → intacta; 403 con cuerpo `Blob` (petición con `responseType:'blob'`) que contiene `{"code":"MODULE_NOT_IN_PLAN","module":"inventario",…}` → llama a `handle('inventario')` y relanza con `error.code` y `error.detail` ya como objeto; `Blob` con JSON inválido o sin código → relanza intacto y sin llamar al servicio
- [X] T076 [P] [US5] Crear `pos-heladeria/src/app/core/module-access/module-access-lost.service.spec.ts` con el contrato de `frontend-acceso-modulos.md` §3 y §8: 1 rechazo → 1 aviso + 1 navegación a `/dashboard` + 1 `load({ force: true })`; **5 rechazos simultáneos → 1 aviso y 1 redirección** (US5.6, SC-003); rechazo tardío con el resumen ya «sin módulo» → 0; falla del refresco → el menú queda corregido igualmente y la bandera «en curso» se libera; dos pérdidas sucesivas separadas en el tiempo → 2 atenciones; `module` ausente o desconocido → aviso + inicio + refresco, sin marcar nada
- [X] T077 [P] [US5] Ampliar `pos-heladeria/src/app/modules/plan/services/plan-summary.service.spec.ts` con `markModuleMissing(module)`: pone `summary().modules[module] = false` de inmediato y de forma síncrona (sin petición); si `summary()` es `null` no hace nada; no toca otros módulos

### Implementation for User Story 5

- [X] T078 [US5] Añadir `markModuleMissing(module)` a `pos-heladeria/src/app/modules/plan/services/plan-summary.service.ts`: actualización inmutable del signal `summary` poniendo ese módulo en `false` (el menú se corrige en el acto aunque `GET /plan` falle)
- [X] T079 [US5] Crear `pos-heladeria/src/app/core/module-access/module-access-lost.service.ts` (`providedIn: 'root'`) con `handle(module)` según `frontend-acceso-modulos.md` §3: (1) si hay atención en curso → retornar; (2) si `summary()` existe y `modules[module]` ya es `false` → retornar; (3) marcar «en curso»; (4) `planSummary.markModuleMissing(module)`; (5) `toast.error(MODULE_NOT_IN_PLAN_MESSAGE)`; (6) `await Promise.allSettled([router.navigateByUrl('/dashboard'), planSummary.load({ force: true })])`; (7) liberar «en curso» siempre (`finally`). Reutiliza `createCachedLoader` vía `load` (research D6)
- [X] T080 [US5] Crear `pos-heladeria/src/app/core/module-access/module-access.interceptor.ts` (`HttpInterceptorFn`): solo para URLs de `environment.apiBaseUrl`. En un `HttpErrorResponse` 403, normalizar el cuerpo con `readErrorBody(err.error)`: si es un `Blob` (peticiones con `responseType:'blob'`, p. ej. `exportItems` y `downloadImportErrors` de `inventory.service.ts`), leerlo con `blob.text()` y `JSON.parse` (si falla, tratarlo como sin código); si es un objeto, usarlo tal cual. Si `body.code === MODULE_NOT_IN_PLAN_CODE`: llamar a `inject(ModuleAccessLostService).handle(body.module)` y relanzar (`throwError`) un `HttpErrorResponse` clonado cuyo `error` es el **cuerpo ya parseado** con `detail = MODULE_NOT_IN_PLAN_MESSAGE` (research D7). Cualquier otro caso se relanza intacto. Seguir el patrón de `core/integrity/page-integrity.interceptor.ts`
- [X] T081 [US5] Registrar `moduleAccessInterceptor` **último** en `withInterceptors([...])` de `pos-heladeria/src/app/app.config.ts` (línea ~39: `[pageIntegrityInterceptor, inflightRequestsInterceptor, authTokenInterceptor, moduleAccessInterceptor]`) para que vea el 403 real, también el de un reintento tras refrescar el token. Añadir el comentario de por qué va al final, como el existente sobre `pageIntegrityInterceptor`
- [X] T082 [US5] Auditoría de toasts de texto fijo (research D7): revisar los `toast.error('…')` o mensajes de error que ignoran `detail` y son alcanzables por una acción del usuario en Inventario, Proveedores, Compras, Unidades de medida y Promociones (p. ej. `inventory-page.component.ts` ~1056 «No se pudo exportar el inventario») y hacerlos tolerantes: no mostrar el toast propio si `err.error?.code === MODULE_NOT_IN_PLAN_CODE` (el interceptor de T080 ya entrega `error` como objeto, también en las peticiones `blob`), reutilizando `shared/api-error.util.ts` si encaja, **sin crear abstracciones nuevas**. Anotar los archivos tocados

  **Resultado (2026-10-31)**: de los `toast.error` de los módulos, solo 3 mostraban un texto fijo ignorando `detail` y son alcanzables por una acción del usuario: `inventory-page.component.ts` (exportar), `inventory-import-modal.component.ts` (descargar reporte de errores y cancelar importación). Ahora no repiten su aviso si el error es `MODULE_NOT_IN_PLAN` (`isModuleNotInPlan` en `core/module-access/module-access.messages.ts`; el interceptor entrega `error` como objeto, también en las peticiones `blob`). Los demás toasts de los módulos usan `service.error() ?? '…'`, cuyo `extractError` lee `detail`, que el interceptor ya reescribió al texto del aviso: el `ToastService` descarta el duplicado. El de `promotions-page.component.ts:1718` es un 409 de solape y no se ve afectado. Archivos tocados: `inventory-page.component.ts`, `inventory-import-modal.component.ts`, `module-access.messages.ts` (+ specs).
- [X] T083 [US5] En `pos-heladeria`: correr T075–T077 y los specs tocados por T082 en verde, la suite completa **sola** comparando por nombre contra `linea-base-frontend.txt`, y `ng build` sin errores

  **Resultado (2026-10-31)**: `module-access.interceptor.spec.ts` (14), `module-access-lost.service.spec.ts` (10), `module-access.messages.spec.ts` (2), `markModuleMissing` en `plan-summary.service.spec.ts` (4) y los specs de las pantallas de los módulos en verde (17 archivos / 206 pruebas). Suite completa **sola**, 2 corridas: **173 archivos / 2568 pruebas, 15 fallos, 0 nuevos frente a `linea-base-frontend.txt`** (comparado por nombre con `comm -13`). `ng build` sin errores.
- [X] T084 [US5] **Recorrido manual Q5 + Q9**: (Q5 por curl) tenant en P-C, `GET /inventory/items` → 200; reasignar a P-B; la siguiente → 403 `MODULE_NOT_IN_PLAN`; reasignar P-C y los datos reaparecen. (Q9) sesión de Administrador en `/dashboard/inventario`, Super Admin pasa el tenant a P-B, el administrador hace una acción: **un** aviso, **una** redirección, menú sin el módulo, sin recargar, varias respuestas 403 en DevTools y ningún aviso extra; una acción posterior no repite el aviso; repetir con Promociones en `/dashboard/promotions` y con **dos pestañas** abiertas. Si no se puede ejecutar, anotarlo como **pendiente** con el motivo

  **Resultado (2026-10-31), en vivo**. **Q5 (curl, API real, `qa141-admin` de `tenantlocal`)**: en P-A `GET /inventory/items`, `/inventory/suppliers`, `/inventory/purchases`, `/promotions` → 200; tras reasignar a P-B con `UPDATE shared.tenants`, la **siguiente** petición ya da 403 `{"detail":"Tu plan actual no incluye el módulo de inventario.","code":"MODULE_NOT_IN_PLAN","module":"inventario"}` (también `/unit-measures`, `/promotions` con `module: promociones` y un `POST` con cuerpo inválido → 403, no 422); `/plan` trae `modules = {inventario, promociones}` (sin `compras`); `/products` y `/categories` siguen en 200; al reasignar P-A los datos (proveedor «Compra ocasional») reaparecen. **Q9 (navegador)**: sesión de Administrador en `/dashboard/inventario`, el plan del tenant pasa a P-B y el usuario escribe en el buscador: el servidor responde 403 (la petición y su reintento automático de TanStack Query), y la aplicación muestra **un** aviso, hace **una** redirección SPA a `/dashboard/admin`, corrige el menú (sin «Inventario» ni «Proveedores») **sin recargar** (una marca en memoria de `window` sobrevive) y no repite el aviso; con **Promociones** (`/dashboard/promotions`, plan «solo inventario») ocurre lo mismo y el menú conserva «Inventario»; con **dos pestañas** abiertas, cada una atiende su propia pérdida al actuar (un aviso por pestaña). Reasignado el plan con módulo, Proveedores vuelve con sus datos. Aserción mía corregida: `framenavigated` también cuenta la navegación SPA del router, así que «1 navegación» es justo «una sola redirección». Capturas `q9-*.png`.

**Checkpoint**: US5 completa. Las cinco historias son funcionales.

---

## Phase 8: Extensión opcional D13 — la importación/exportación de productos respeta el módulo (Priority: opcional) · [I7]

**Goal** (research H3/D13, FR-023 —condicionado a A-153—, FR-004 y FR-002): un negocio sin Inventario ya no puede leer ni escribir recetas ni `Rastrea inventario` por la importación/exportación de productos. **Se ejecuta solo si el dueño ratifica D13.** Va en commits propios y revertibles (como A-147/A-148 en la spec 138). Si no se ratifica, 141 se cierra sin esta fase, se retiran FR-023, US2.7 y la decisión de negocio 4 de `spec.md`, y queda constancia en T085.

**Independent Test**: tenant P-B: exportar productos → el libro no trae la hoja «Receta» ni la columna «Rastrea inventario»; importar un libro con «Rastrea inventario = Sí» o filas de «Receta» → esas filas se rechazan por fila con «Tu plan actual no incluye el módulo de inventario.» y el resto se procesa. Tenant P-A: sin cambios. (Q12.)

- [ ] T085 [D13] **Decisión (bloquea T086–T091)**: `spec.md` ya trae FR-023, US2.7 y la decisión de negocio 4 como **condicionados** a esta ratificación; pedir al dueño que ratifique D13 (research D13): *compuerta a nivel de campo* (opción provisional) / *dejarlo para otra spec* / *bloquear el libro entero* (descartada en el research). Anotar la decisión y la fecha aquí y en `research.md` D13. Si **no** se ratifica: marcar T086–T091 como `N/A` con ese motivo, retirar FR-023, US2.7 y la decisión de negocio 4 de `spec.md`, y seguir con la Polish

  **Estado (2026-10-31): SIN DECISIÓN DEL DUEÑO.** La implementación de las historias US1–US5 no ratifica D13 (el dueño no la ha ratificado en esta sesión), así que **no se ejecutó nada de la Phase 8** y T086–T091 siguen sin marcar. Mientras no se decida, 141 se puede cerrar sin esta fase (se retirarían FR-023, US2.7 y la decisión de negocio 4 de `spec.md`, y T086–T091 pasarían a `N/A`); el camino de importación/exportación de productos sigue sin compuerta de módulo (research H3).
- [ ] T086 [D13] Registrar **A-153** (importación/exportación de productos respeta el módulo Inventario a nivel de campo) en `pos-specs/specs/000-reconocimiento/registro-de-anomalias.md`, con los mismos campos que T007 (verificar el número libre como en T006)
- [ ] T087 [P] [D13] Crear `pos-backend/app/characterization_tests/test_products_import_module_gate.py`: con módulo → sin cambios; sin módulo → las filas de «Productos» con `Rastrea inventario = Sí` y **todas** las de «Receta» se rechazan por fila con «Tu plan actual no incluye el módulo de inventario.» y el resto se procesa; la exportación sin módulo no incluye la hoja «Receta» ni la columna `Rastrea inventario`; un libro sin esa hoja ni columna se importa sin error de estructura
- [ ] T088 [D13] `pos-backend/app/api/v1/products/import_.py`: aplicar la compuerta por fila usando `has_module_access(db, tenant, "inventario")` (columna `Rastrea inventario` en líneas ~279 y ~296; hoja «Receta» en ~385-445). Verificar que `validar_estructura` (líneas ~46 y ~83, que hoy lista «Receta» entre las hojas esperadas) tolera libros sin esa hoja o columna; si no, ajustarlo aquí. **Commit propio**
- [ ] T089 [D13] `pos-backend/app/api/v1/products/export.py` (hoja «Receta» en líneas ~56-91): con `has_module_access` falso, omitir la hoja «Receta» y la columna `Rastrea inventario`. **Commit propio**
- [ ] T090 [D13] Correr `test_products_import_module_gate.py` y las pruebas existentes de importación/exportación de productos en verde; hacer el viaje de ida y vuelta (exportar sin módulo → importar el mismo libro) sin errores
- [ ] T091 [D13] **Recorrido manual Q12** (tenant P-B y P-A) según el quickstart. Si no se puede ejecutar, anotarlo como **pendiente** con el motivo

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: documentación, verificación final y notas de despliegue.

- [X] T092 [P] Actualizar `pos-specs/docs-publicos/06-administracion-global/gestion-de-tenants-y-planes.md` (líneas 15, 36, 62, 88 y 104): de tres módulos (inventario, compras, promociones) a **dos**, indicando que Inventario incluye Proveedores y Compras (research D17). No tocar `specs/104-documentacion-funciones-publica/`: son fotografías de una fecha

  **Resultado (2026-10-31)**: `docs-publicos/06-administracion-global/gestion-de-tenants-y-planes.md` — «tres módulos» pasa a dos (Inventario, que incluye Proveedores y Compras, y Promociones), «ocho características» a siete, se documenta la confirmación al quitar Inventario de un plan y el aviso único ante la pérdida del módulo. `specs/104-documentacion-funciones-publica/` no se tocó.
- [X] T093 [P] Actualizar `pos-specs/srs/README.md`: línea 139 (módulos del plan: `inventario`, `promociones`), línea 1166 (el router `inventory` exige el módulo «inventario»; ya no hay «exige además "compras"») y RF-inventory-012 (líneas ~1307 y ~1310: precondición «plan con el módulo "inventario"» y criterio de aceptación sin referencia a un módulo «compras»); luego `grep -n -i "compras" srs/README.md` y corregir cualquier otra cita de «compras» como módulo del plan (respetando las marcas `[CÓDIGO: …]` y `[INFERIDO]` del documento)

  **Resultado (2026-10-31)**: `srs/README.md` — línea 139 (módulos `inventario` y `promociones`), encabezado del router `inventory` (línea 1166) y RF-inventory-012 (precondición y criterio de aceptación, con `MODULE_NOT_IN_PLAN` y sin indicador propio de «compras»; las citas `[CÓDIGO: …]` se actualizaron a `router.py:38-41` y `plan_limits.py:139-155`). `grep` posterior: no queda ninguna otra cita de «compras» como módulo del plan.
- [ ] T094 Añadir en `pos-specs/specs/033-planes-suscripcion-tenant/research.md` (Decisión 6, línea ~158) una nota «sustituida por la spec 141». **Requiere aprobación explícita del usuario antes de editar** (precedente: spec 100); si no la da, dejarlo como pendiente

  **PENDIENTE (2026-10-31)**: requiere la aprobación explícita del usuario para editar `specs/033-planes-suscripcion-tenant/research.md` (precedente: spec 100); no se editó.
- [X] T095 Actualizar el campo **Estado** de A-150, A-151 y A-152 (y A-153 si T085 la ratificó) en `pos-specs/specs/000-reconocimiento/registro-de-anomalias.md`: implementadas en la spec 141, con el commit/rama y «PENDIENTE de ratificación con el negocio»

  **Resultado (2026-10-31)**: A-150, A-151 y A-152 pasan a **IMPLEMENTADA** en la spec 141 (ramas `feat/141-unified-inventory-module`, sin commit ni despliegue), cada una con su detalle y todas siguen **PENDIENTES de ratificación con el negocio**. A-153 no existe (D13 sin ratificar).
- [X] T096 Verificación final del backend, **sola**: `env/bin/python -m unittest discover -s app/characterization_tests` en `pos-backend`; comparar contra T003 (0 fallos nuevos, 0 pruebas `CONGELA` modificadas: `git diff develop --stat -- app/characterization_tests` debe mostrar solo los archivos esperados)

  **Resultado (2026-10-31)**: suite completa del backend **sola**: **2081 OK** (línea base 2041 + 40 nuevas), 0 fallos. `git diff develop --stat -- app/characterization_tests`: solo `test_bootstrap.py` (+2), `test_plan_module_access.py`, `test_plan_summary.py` y `test_super_admin_plans.py` modificados, más 3 archivos nuevos (`test_module_not_in_plan_error.py`, `test_module_route_inventory.py`, `test_plans_migration_141.py`); **0 pruebas con prefijo `CONGELA` tocadas**.
- [X] T097 Verificación final del frontend, **sola**: `ng test` completo en `pos-heladeria` comparando **por nombre** contra `linea-base-frontend.txt` (0 fallos nuevos) y `ng build` sin errores

  **Resultado (2026-10-31)**: suite completa del frontend **sola**: 173 archivos / 2568 pruebas, 15 fallos, **0 nuevos** frente a `linea-base-frontend.txt` (comparado por nombre); `ng build` de producción sin errores (solo las advertencias de presupuesto de bundle y de `qrcode`, ajenas a esta spec).
- [X] T098 Revisar `git status`/`git diff --stat` en `pos-backend`, `pos-heladeria` y `pos-specs`: ningún archivo fuera de alcance (Principio V: no se migran Reportes ni Ajustes a `includes()`, no se reorganiza el sidebar ni el `ToastService`); limpiar planes `[141-test]` y otros datos de prueba de la BD de desarrollo

  **Resultado (2026-10-31)**: `git status` revisado en los 3 repos: `pos-backend` 13 modificados + 4 nuevos; `pos-heladeria` 29 modificados + 7 rutas nuevas; `pos-specs` 3 modificados + la carpeta de la spec. Ningún archivo fuera de alcance (Reportes y Ajustes no se migraron a `includes()`, no se reorganizó el sidebar ni el `ToastService`). BD de desarrollo limpia: 0 planes `[141-test]`, 0 usuarios `qa141-*`, `tenantlocal` de vuelta en «Ilimitado (transición)» sin vencimiento y sin productos ni categorías de prueba. **Queda en la BD de desarrollo la migración aplicada (`30cd5f4a8fd6`)**: para volver a `develop` hay que correr `alembic downgrade -1`. El contenedor `pos-worker` sigue con la imagen anterior (modelo `Plan` con `compras_access`): hay que reconstruirlo/reiniciarlo con el código nuevo.
- [X] T099 Releer las 6 tareas de recorrido manual (T047, T066, T067, T073, T084 y, si se ratificó D13, T091) y dejar en cada una `[x]` o **pendiente con su motivo** (quickstart «Verificación final»); ningún recorrido no ejecutado queda como hecho

  **Resultado (2026-10-31)**: T047, T066, T073 y T084 ejecutados en vivo (`[X]`); **T067 queda `[ ]` por ser PARCIAL** (falta tomar un pedido y cobrarlo, con el motivo en su nota); T091 no aplica (D13 sin ratificar). Ningún recorrido no ejecutado se marcó como hecho.
- [ ] T100 **Despliegue — antes**: anotar `select inventario_access, compras_access, promociones_access, count(*) from shared.plans group by 1,2,3` en el entorno destino, insumo del informe de qué planes ganaron Proveedores y Compras (la spec lo acepta sin revisión individual)

  **PENDIENTE (2026-10-31)**: es un paso de despliegue contra el entorno destino; no se ejecutó. Referencia de dev (antes de migrar): `(inventario=t, compras=t, promociones=t) → 1` plan.
- [ ] T101 **Despliegue — orden**: **backend primero** (la migración corre sola en `docker/api-entrypoint.sh`), reiniciar `pos-worker` junto con la API (su imagen vieja conserva el modelo `Plan` con `compras_access` y no ejecuta migraciones), y el frontend inmediatamente después. **Revertir código**: primero `alembic downgrade -1`, después la imagen anterior. Declarar que no se recupera «tenía Inventario sin Compras» (data-model §2). Tras desplegar, recorrer Q7 en `springfieldgranizados`

  **PENDIENTE (2026-10-31)**: despliegue no realizado (no solicitado). Recordatorio: backend primero, reiniciar `pos-worker` junto con la API, frontend inmediatamente después; revertir código exige `alembic downgrade -1` antes; recorrer Q7 en `springfieldgranizados` tras desplegar.

---

## Dependencias y orden de ejecución

### Dependencias entre fases

```text
Phase 1 Setup ──► Phase 2 Foundational ──► Phase 3 US2 ──► Phase 4 US1 ──► Phase 5 US3 ──► Phase 7 US5
                                                │                                │
                                                └─► Phase 8 D13 (opcional)       └─► Phase 6 US4 ─┘ (US5 también depende de US4)
                                                                                                      
Phase 9 Polish: tras las fases que se ejecuten
```

- **Setup → Foundational**: bloquea todo. A-150…A-152 (T007–T009) antes de cualquier código.
- **US2 antes de US1**: el catálogo `PLAN_MODULES` y la retirada de los 8 gates `compras` (T016–T017) deben existir antes de eliminar la columna (T024–T025); si no, un `require_module_access("compras")` olvidado rompería producción tras el `DROP`.
- **US1 antes de US3**: el tipo `ModuleAccess` sin `compras` (T036) cambia lo que compila en el menú y en Inventario.
- **US3 antes de US5 (obligatorio)**: I4 antes de I5. Con el interceptor activo, cada carga de fondo rechazada pasa de error silencioso a expulsión (T074 lo comprueba).
- **US4 antes de US5**: el aviso de la guardia y el interceptor usan el mismo texto y el mismo deduplicado; probarlos juntos evita dos avisos.
- **US3 y US4** no dependen entre sí (archivos distintos salvo `plan-module.guard.ts`/`routes.ts` frente a `navigation.config.ts`); se pueden hacer en cualquier orden o en paralelo tras US1.
- **Phase 8 (D13)** solo depende de US2 (T016 `has_module_access`) y puede hacerse en cualquier momento tras ella, si se ratifica.
- **Dentro de cada historia**: tests primero (fallan), después implementación, después verificación y recorrido manual.

### Dependencias dentro de las historias (puntos críticos)

- T016 y T017 se aplican juntas (el router no importa si queda un gate `compras` y `PLAN_MODULES` valida al construir).
- T025–T028 se aplican juntas antes de correr la suite del backend (el modelo y los esquemas deben quedar coherentes).
- T036 rompe la compilación hasta que se aplican T037, T038, T039–T041 y los fixtures T042–T045; correr `ng build` solo después de T045 (T046).
- T057 (`includes`) antes de T059–T063; T078 (`markModuleMissing`) antes de T079; T079 antes de T080; T080 antes de T081.

---

## Oportunidades de paralelismo

### US2 (backend)

```text
En paralelo (archivos distintos):  T011  T012  T013      → luego T014 (mismo archivo que T012)
Secuencial:                        T015 → T016+T017 → T018 → T019 → T020
```

### US1

```text
Backend tests en paralelo:      T021  T022  T023
Backend código en paralelo:     T025  T026  T027  T028    (después de T024; aplicar juntas)
Frontend tests en paralelo:     T033  T034  T035
Frontend código en paralelo:    T036 ; T039  T040          (T037, T038, T041 tras T036)
Fixtures en paralelo:           T042  T043  T044  T045
```

### US3

```text
Tests en paralelo (9 archivos):   T048  T049  T050  T051  T052  T053  T054  T055  T056
Código en paralelo tras T057:     T058  T060  T061  T062  T063      (T059 también; archivo propio)
```

### US4 / US5

```text
US4 tests en paralelo:   T068  T069
US5 tests en paralelo:   T075  T076  T077
```

Un desarrollador puede llevar backend (US2 → US1 backend) y otro frontend (US1 frontend tras T036 → US3 → US4 → US5) en paralelo **desde T033**, siempre que el contrato de `GET /plan` esté acordado (está en [contracts/planes-api.md](./contracts/planes-api.md)).

---

## Estrategia de implementación

### MVP primero (US2)

1. Phase 1 + Phase 2.
2. Phase 3 (US2): el servidor es la autoridad. **Detenerse y validar**: Q2 = T013 + T014, Q3 = T014 (camino positivo), Q4 = T012 (b)(e) + T014, todos en verde. Ya cumple SC-001 y SC-002 y es desplegable sola: el front actual sigue funcionando (aún lee `modules.compras`, que sigue existiendo).

### Entrega incremental (un incremento = una unidad de commits pequeños)

| Incremento del plan | Fase | Tareas | Verificación de cierre |
|---|---|---|---|
| I1 | Phase 3 (US2) | T011–T020 | 3 suites + E2E `TestClient`; suite backend completa |
| I2 | Phase 4 backend (US1) | T021–T032 | Q1 y Q6 contra PostgreSQL real; `upgrade`/`downgrade`/`upgrade` |
| I3 | Phase 4 (contrato y «Mi plan», US1) + Phase 5 (menú, pestaña Compras, US3) + Phase 6 (guardias, US4) | T033, T036–T038, T042–T046 · T049–T051, T058 · T068–T073 | Q7 (menú), Q8; specs de menú y guardia |
| I4 | Phase 5 (cargas de fondo, US3) | T048, T052–T057, T059–T067 | «0 peticiones sin módulo» por superficie; Q7 recarga dura; Q11 |
| I5 | Phase 7 (US5) | T074–T084 | Q9; «5 rechazos → 1 aviso» |
| I6 | Phase 4 (panel Super Admin, US1) | T034, T035, T039–T041, T047 | Q10 |
| I7 | Phase 8 (opcional) | T085–T091 | Q12 |

> I3 e I6 viven dentro de la Phase 4 en lo que pertenece a US1, y I3 se reparte además entre las Phases 5 y 6 por historia. **El orden de fases prevalece sobre el número de incremento**; la única regla de orden entre incrementos que no se puede alterar es I4 antes de I5.

### Despliegue

La Phase 3 (US2) se puede desplegar sola: el front actual sigue leyendo `modules.compras`, que aún existe. **Desde T024 el backend deja de devolver `modules.compras`** y un front viejo oculta la pestaña «Compras» hasta recargar (el front recarga solo al detectar versión nueva, spec 134): por eso el backend de US1 y el frontend de US1/US3 se despliegan en el mismo ciclo, **backend primero y frontend inmediatamente después** (T101). Lo inverso dejaría a los planes sin Compras viendo una pestaña que responde 403.

---

## Trazabilidad: requisito → tarea → prueba (Principio XII)

| Requisito / criterio | Tareas de implementación | Pruebas / verificación |
|---|---|---|
| FR-001, FR-002, FR-003 (catálogo, una funcionalidad = un módulo) | T016, T017, T026 | T011, T013 |
| FR-004 (todo o nada) | T016, T017 | T013 |
| FR-005 (plan vigente en cada petición) | T016 (sin caché; research R0) | T012 (d), Q5 en T084 |
| FR-006, FR-007, FR-008 (403, `code`, `module`, `detail` string) | T015, T016, T018 | T011, T012, T014 |
| FR-009 (plan vencido distinto) | T016 | T012 (b), T068 |
| FR-010 (rol sin cambios) | T017 | T012 (e) |
| FR-011 (ventas/catálogo/QR no se bloquean) | T060–T063 (cargas de fondo) | T053–T056, T067 |
| FR-012 (menú + encabezado) | T058 | T049, T050, T066 |
| FR-013 (Compras como pestaña) | T038 | T051 |
| FR-014 (cargas de fondo / 5 superficies) | T057, T059–T064 | T048, T052–T056, T066 |
| FR-015 (URL directa) | T070, T071 | T068, T069, T073 |
| FR-016 (un aviso, una redirección, sin recargar) | T078–T081, T082 | T075, T076, T077, T084 |
| FR-017 (vencido sin aviso) | T070 | T068 |
| FR-018 (datos se conservan) | T024 (solo `shared.plans`) | T029, T030, T084 |
| FR-019 (un control + confirmación + Mi plan) | T037, T039–T041, T036 | T033, T034, T035, T047 |
| FR-020, FR-021 (migración idempotente y reversible) | T024 | T021, T029, T030 |
| FR-022 (cambio incompatible documentado) | T025–T028, T009 | T022, T023, T031 |
| FR-023 (importación/exportación de productos; condicionado a A-153) | T086, T088–T089 | T087, T090, T091 |
| SC-001 | T013 | T013, T020 |
| SC-002 | T017 | T014 (camino positivo), T013 |
| SC-003 | T078–T081 | T012 (d), T076, T084 |
| SC-004 | T058, T059–T063 | T049, T052, T066 |
| SC-005 | T071 | T069, T073 |
| SC-006 | T024 | T021, T029, T030 |
| SC-007 | T041 | T034, T047 |

---

## Notas

- Las pruebas del frontend con fallos preexistentes se comparan **por nombre**; nunca se corren frontend y backend completos a la vez.
- Todo recorrido manual que no se pueda ejecutar queda **pendiente con su motivo**, no como hecho (quickstart).
- Si un hallazgo nuevo cambia el alcance (p. ej. T064 descubre otra carga de fondo), se corrige con `includes(...)`, se añade su prueba y se anota en esa tarea; no se amplía la spec en silencio.
- No commitear sin que el usuario lo pida (Principio XV); al pedirlo, un commit por incremento o por unidad coherente, en inglés y sin atribución de IA.
