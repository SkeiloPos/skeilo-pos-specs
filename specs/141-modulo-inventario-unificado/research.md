# Research: Módulo Inventario unificado en el control de acceso por plan

**Spec**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md) · **Fecha**: 2026-10-31

Este documento reconfirma contra el código real cada premisa de la spec, resuelve las decisiones que la spec dejó
al plan y registra los **hallazgos que la spec no tenía**. No quedan `NEEDS CLARIFICATION` abiertas; la única
decisión que conviene que el dueño ratifique (D13) viaja aislada en su propio incremento para poder retirarse.

Convención: `repo:ruta:línea` apunta al código en `develop` a 2026-10-31 (`pos-backend` `9c42dda`, `pos-heladeria` `53e59f5`).

---

## R0 — Reconfirmación del estado actual

| Premisa de la spec | Resultado | Evidencia |
|---|---|---|
| Proveedores está protegido en el servidor y no en la interfaz | ✅ confirmado | Las rutas `/inventory/suppliers…` viven en el router `/inventory`, que declara `dependencies=[require_module_access("inventario")]` (`pos-backend:app/api/v1/inventory/router.py:38-41`). En el front, el ítem «Proveedores» no tiene `moduleKey` (`pos-heladeria:src/app/core/config/navigation.config.ts`, ítem `Proveedores`) y las rutas `proveedores` y `proveedores/:id/detalle` no tienen `planModuleGuard` (`modules/dashboard/routes.ts:247-262`) |
| Compras exige hoy dos condiciones | ✅ confirmado | Router `inventario` + **8** endpoints con `require_module_access("compras")` además (`inventory/router.py:482,500,516,532,549,566,582,597`: listar, crear, orden, `PUT` ×2, recibir, anular, eliminar) |
| El 403 por módulo es texto plano | ✅ confirmado | `ensure_module_access` lanza `HTTPException(403, "Tu plan actual no incluye el módulo de {label}.")` (`app/core/plan_limits.py:126-144`); el envelope de la spec 068 solo cubre `/api/v1/super-admin` (`app/core/error_middleware.py:296-318`) |
| La redirección de una ruta bloqueada no avisa | ✅ confirmado | `planModuleGuard` devuelve `router.createUrlTree(['/dashboard'])` sin ningún aviso (`src/app/core/guards/plan-module.guard.ts`) |
| El panel de inicio pide «Stock bajo» sin comprobar el plan | ✅ confirmado | `ngOnInit` llama `this.inventoryService.loadLowStock()` incondicional (`modules/dashboard/pages/admin-dashboard.component.ts:590`) |
| Un cambio de plan surte efecto en la siguiente petición | ✅ **ya se cumple por construcción** | No hay caché de tenant ni de plan: `get_tenant` → `find_tenant_by_host` consulta `shared.tenants` en cada petición (`app/core/db.py:266-296`) y `ensure_module_access` hace `db.get(Plan, tenant.plan_id)`. FR-005/SC-003 se **verifican con una prueba**, no requieren mecanismo nuevo |
| Los tests de planes no son «CONGELA» | ✅ confirmado | `test_plan_module_access.py` y `test_super_admin_plans.py` declaran en su docstring que **no** son characterization tests; un barrido de `CONGELA` + `compras_access`/`require_module_access`/`inventario_access` solo encuentra esa advertencia. **Principio III no se activa** |
| Estado de la BD de desarrollo | informativo | `shared.plans` tiene 1 fila (inventario=t, compras=t, promociones=t), 3 tenants, `alembic_version = 56a2cdbec89c` (= cabeza de Alembic) |

### Hallazgos que la spec no tenía

**H1 — La Terminal de mesas pide `GET /promotions` en todos los negocios.**
`PosTerminalStore.init()` incluye `this.promotionService.loadActive()` dentro de su `Promise.all`
(`modules/tables/services/pos-terminal.store.ts:1466`). `GET /promotions` está detrás de
`require_module_access("promociones")` (`app/api/v1/promotions/router.py:29`). Hoy, para un negocio sin Promociones, esa
petición termina en 403 y el error se queda en silencio dentro de la query. **Con el aviso global de FR-008/FR-016
(que cubre Promociones), abrir la Terminal de mesas expulsaría al usuario al inicio con un aviso, en cada negocio sin
Promociones.** Es el mismo fallo que FR-014 describe para «Stock bajo», pero la spec solo lo nombró para Inventario.
Además violaría el Edge Case «perder el módulo nunca debe impedir vender».

**H2 — Tres pantallas del catálogo base cargan endpoints de Inventario sin condición.**
- `ProductFormComponent.ngOnInit` → `unitMeasureService.loadUnitMeasures()` (`modules/products/pages/product-form.component.ts:1218`), `GET /unit-measures` (gate `inventario`).
- `OptionGroupsPageComponent.ngOnInit` → `loadAllItems()` y `loadUnitMeasures()` (`modules/option-groups/pages/option-groups-page.component.ts:226-229`).
- `OptionFormComponent.ngOnInit` → `loadAllItems()` y `loadUnitMeasures()` (`modules/option-groups/components/option-form.component.ts:160-163`).

Son pantallas que **deben seguir funcionando sin el módulo** (FR-011). Con el interceptor global, abrir el formulario de
un producto o los grupos de opciones sacaría al usuario al inicio. El barrido de FR-014 de la spec listaba las
superficies *visibles* (tarjeta, pestaña, bloque, campos); estas son cargas de fondo *invisibles* y por eso se le
escaparon. El barrido completo de este plan (contratos → [frontend-acceso-modulos.md](./contracts/frontend-acceso-modulos.md) §4) tiene **5 superficies**.

**H3 — La importación/exportación de productos (spec 143) no está compuerteada por módulo.**
`products/import_.py` acepta la columna `Rastrea inventario` (`:279`, `:296`) y la hoja **Receta**, que resuelve
`InventoryItem` por nombre/código y escribe `RecipeItem` (`:385-445`); `products/export.py` exporta la hoja Receta con
los nombres de insumo (`:56-91`). Ninguna de las dos comprueba el plan. Un negocio sin Inventario puede, por ese camino,
**leer y escribir datos del módulo** que el formulario de producto sí le niega (spec 064, FR-011/FR-012:
`ensure_module_access` en `products/service.py:213,316`). Contradice FR-004 («todas o ninguna») y FR-002 («cada
funcionalidad pertenece a un único módulo»). La spec no lo menciona porque la 143 se mergeó después de redactarla.

**H4 — Hay specs 142–145 en los repos de código que no están en `pos-specs`.**
`develop` de `pos-backend` trae la migración `…_144_promotions_visible_en_qr.py` y merges de `feat/142-…` y
`feat/143-…`; `pos-heladeria` trae `style/145-redesign-invited-password`. `pos-specs/specs` termina en 141.
Consecuencias para este plan: (a) la `down_revision` de la migración es `56a2cdbec89c`, no la que habría en `main`
de specs; (b) el siguiente número libre de `registro-de-anomalias.md` hay que **volver a verificarlo** al registrar
(hoy el último en este repositorio es A-149, pero otra rama de specs pudo reservar A-150+).

**H5 — `PlanResponse` y `PlanUpdate` no rechazan campos extra.**
Pydantic usa el comportamiento por defecto (`extra="ignore"`), así que un cliente con el bundle viejo que siga enviando
`compras_access` **no recibe 422**: el campo se descarta en silencio. Es el comportamiento que se necesita para el
despliegue (D5).

---

## D1 — Cómo se expresa `MODULE_NOT_IN_PLAN` sin romper a los clientes actuales

**Decisión**: una subclase nueva `ModuleNotInPlanError(HTTPException)` en `app/core/exceptions.py` (junto a
`InsufficientStockError` y `PendingPaymentExit`, que son el precedente de «HTTPException con significado propio»),
con `detail` **string** y atributos `module`. Un `@app.exception_handler(ModuleNotInPlanError)` propio —Starlette elige
el handler por MRO, así que gana al genérico de `StarletteHTTPException` sin tocarlo— responde:

```json
{ "detail": "Tu plan actual no incluye el módulo de inventario.", "code": "MODULE_NOT_IN_PLAN", "module": "inventario" }
```

**Rationale**:
- FR-007 exige que `detail` siga siendo el texto que los clientes ya leen (`extractError` de cada servicio del front
  lee `body.detail` y, si es `string`, lo muestra: p. ej. `plan-summary.service.ts`, `suppliers.service.ts`).
  Un `detail` dict rompería ese contrato en todas las pantallas.
- Subclasear `HTTPException` (y no una excepción de dominio aparte) conserva la semántica de los `except HTTPException`
  que envuelven transacciones —`ensure_module_access` también se invoca *dentro* de handlers (`catalog/router.py:396,476`,
  `products/service.py:213,316`)—.
- El campo se llama `module` y el código `code`, planos y al nivel raíz, igual que el 423 que ya produce el front
  (`{detail, code}` en `page-integrity.interceptor.ts`).
- El 403 de **plan vencido** sigue siendo `HTTPException(403, …)` sin código (FR-009); el 403 de rol sigue igual. El front
  distingue por `code`, nunca por el texto.

**Alternativas consideradas**:
- `detail` como dict `{code, message}` (patrón de `PendingPaymentExit`) — rechazada: viola FR-007.
- Extender el envelope de la spec 068 a todo el backend — rechazada: cambia la forma de **todas** las respuestas de error de
  los tenants, fuera de alcance (Principio V) y con riesgo sobre cada cliente.
- Solo una cabecera `X-Error-Code` — rechazada: el front ya parsea cuerpos JSON; una cabecera exigiría además exponerla
  en CORS (`expose_headers`) y no hay precedente para códigos.

## D2 — Un único módulo `inventario` en el servidor

**Decisión**:
1. Se **eliminan** los 8 `dependencies=[Depends(require_module_access("compras"))]` de `inventory/router.py`. Proveedores
   y Compras quedan gobernados por el gate del router, sin cambio de rutas, métodos ni roles (FR-010).
2. `plan_limits.py` declara `PLAN_MODULES = ("inventario", "promociones")`. `require_module_access`,
   `ensure_module_access` y `has_module_access` rechazan una clave fuera de esa tupla **al construirse la dependencia**
   (`ValueError` al importar el router), no en la primera petición. Un `require_module_access("compras")` olvidado
   rompe el arranque y la suite, en vez de convertirse en un `AttributeError` en producción tras quitar la columna.
3. `ensure_module_access` lanza `ModuleNotInPlanError`; el orden se conserva: **vencido primero** (FR-009), luego módulo.
   Se elimina el diccionario `labels` (el texto sigue siendo «…el módulo de inventario/promociones.»).

**Rationale**: el cambio es una resta, no una suma; mantiene `require_module_access` como único punto de aplicación
(research 033 Decisión 14). Falla-rápido barato frente a un error silencioso.

**Alternativas**: dejar `compras` como alias de `inventario` — rechazada: es exactamente la ambigüedad que FR-001/FR-002 eliminan.

## D3 — Cómo se demuestra SC-001 («el 100 % de las funcionalidades rechaza»)

**Decisión**: una prueba de **inventario de rutas** (`test_module_route_inventory.py`) que recorre `app.routes`,
agrupa por prefijo según una tabla explícita módulo→prefijos y comprueba que **cada** ruta lleva la dependencia del
módulo correcto. La tabla es el contrato ([inventario-de-rutas.md](./contracts/inventario-de-rutas.md)):
`inventario` = `/inventory` (29), `/unit-measures` (6), `/unit-measure-groups` (6), `/reports/inventory` y
`/reports/profitability` (2) = **43** rutas; `promociones` = `/promotions` (7). La dependencia se reconoce porque
`require_module_access` devuelve una función con el atributo `module_key`.
Además: una prueba por comportamiento (con la dependencia invocada directamente, como ya hace
`test_plan_module_access.py`) para 403 + `code` + `module` + plan vencido + rol, y una prueba de «cambio de plan entre dos
llamadas» para FR-005.

**Rationale**: la introspección falla en el momento en que alguien añade una ruta bajo un prefijo del módulo sin la
dependencia (la causa raíz del hueco de Proveedores en el front); las pruebas por comportamiento fijan el cuerpo.
La suite del backend ya usa `TestClient` en tres archivos (`test_bootstrap.py`, `test_operational_log.py`,
`test_super_admin_sentry_integration.py`), de modo que un test HTTP de extremo a extremo del cuerpo `{detail, code, module}`
(que ejercita el handler real) es viable y se incluye para una ruta de cada módulo.

**Alternativas**: solo pruebas de comportamiento con `TestClient` por ruta (43 + 7 llamadas con tenants, tokens y esquemas
en SQLite) — rechazada: caro y no detecta una ruta nueva.

## D4 — Estrategia de migración y de reversión (resuelve el «conservar o eliminar» de la spec)

**Decisión**: **una** migración Alembic, solo sobre `shared.plans`
(`<hash>_141_plans_unify_inventory_module.py`, `down_revision = '56a2cdbec89c'`):

- `upgrade()`: (1) si la columna `compras_access` existe, `UPDATE shared.plans SET inventario_access = true WHERE compras_access = true AND inventario_access = false`; (2) `ALTER TABLE shared.plans DROP COLUMN compras_access`.
  Guardada con comprobación de existencia de la columna, de modo que ejecutarla otra vez es un no-op (**idempotente**, FR-021).
- `downgrade()`: `ADD COLUMN compras_access boolean NOT NULL DEFAULT false` y luego `UPDATE shared.plans SET compras_access = inventario_access`.

**Qué recupera y qué no el `downgrade()`** (declaración exigida por FR-021 y Principio VIII):
- Recupera **la columna y la forma del esquema** anterior, y que ningún plan quede sin acceso a algo que tenía.
- **No** recupera la información previa «tenía Inventario sin Compras»: tras `upgrade`, un plan (Inventario=sí, Compras=no) y uno (sí, sí) son idénticos, y un plan (no, sí) pasó a (sí, sí). El `downgrade()` los deja **todos** con `compras_access = inventario_access`. Efecto neto de ir y volver: los planes (sí, no) ganan Compras y los (no, sí) quedan con Inventario *y* Compras. Es un enriquecimiento, nunca una pérdida de acceso; coherente con la decisión de negocio 2 de la spec.
- No toca límites, precios, ciclos, vencimientos ni la asignación `tenants.plan_id` (FR-020): el `UPDATE` solo escribe `inventario_access`.
- No itera esquemas de tenant (`for_each_tenant_schema` **no** se usa): `plans` vive en `shared`.

**Rationale**:
- La spec 140 (`eliminar-dimension-unit-measures`, D3) fijó el precedente: eliminar la columna y reconstruirla en `downgrade()`
  con la mejor información disponible, en vez de dejar un estado revertido peor que el original.
- «Migración limpia del antiguo módulo Compras» (Escenario 6) y FR-022 («sin período de transición») apuntan a eliminar, no a dejar una columna muerta con valores que ya nadie mantiene.
- El contenedor de la API ejecuta `alembic upgrade head` al arrancar (`docker/api-entrypoint.sh`), así que esquema y código nuevos se despliegan juntos. La contrapartida —el código **anterior** deja de funcionar si la columna ya no existe— se cubre con la regla de reversión de [quickstart.md](./quickstart.md) §Despliegue: *`alembic downgrade -1` antes de volver a la imagen anterior*.
- El `UPDATE` precede al `DROP` en la misma transacción de Alembic: no existe un estado intermedio observable.

**Alternativas consideradas**:
- Conservar la columna «muerta» y retirarla en otra spec (expand/contract) — rechazada: deja un dato que diverge del comportamiento real (planes nuevos con Inventario y `compras_access=false`), y un `SELECT *` o una herramienta de soporte lo leería como verdad. El único beneficio (rollback de código sin `downgrade`) se resuelve con la regla de reversión.
- Dos revisiones (datos y luego `DROP`) — rechazada: ambas se aplican en el mismo arranque; no hay ventana intermedia que aproveche la separación.
- Tabla auxiliar con el estado original para reversión exacta — rechazada: la spec acepta la reversión inexacta (FR-021) con declaración; son pocos planes (1 en desarrollo) y el costo de mantener una tabla temporal no se justifica (Principio V).

## D5 — Contrato de planes: cambio incompatible sin transición (FR-022)

**Decisión**: `compras` desaparece de `GET /plan` (`ModuleAccess`), de `bootstrap.plan.modules` (que reutiliza
`build_plan_summary`) y `compras_access` desaparece de `PlanCreate`/`PlanUpdate`/`PlanResponse` (`/api/v1/super-admin/plans`).
Sin campo deprecado ni período de gracia. Se documenta como cambio incompatible en
[planes-api.md](./contracts/planes-api.md).

**Rationale / efecto en pestañas con bundle viejo** (H5): un cliente antiguo que envíe `compras_access` es ignorado sin error.
Uno antiguo que *lea* `modules.compras` obtiene `undefined` y oculta la pestaña «Compras» hasta que recargue; el front ya
recarga solo al detectar versión nueva (spec 134, `SwUpdate`). La spec ya declaró (Assumptions) que no hay consumidores
externos.

## D6 — Manejo global en el front: interceptor + servicio de «módulo perdido»

**Decisión**: tres piezas nuevas en `src/app/core/module-access/`:
1. `module-access.interceptor.ts` — `HttpInterceptorFn` registrado **último** en `withInterceptors([...])` (más interno: ve el 403 real, también el reintento tras un refresh de token). Si la respuesta es `403` con `error.code === 'MODULE_NOT_IN_PLAN'`, llama a `ModuleAccessLostService.handle(error.module)` y **vuelve a lanzar** el error (los llamadores necesitan terminar su estado de carga).
2. `module-access-lost.service.ts` — orquesta aviso + redirección + actualización del plan **una sola vez** (FR-016):
   ```
   handle(module):
     si ya hay una atención en curso            → ignorar            (rechazos simultáneos o en sucesión)
     si el resumen del plan ya dice «sin módulo» → ignorar            (rechazo tardío de una petición ya en vuelo)
     marcar «en curso»
     marcar localmente el módulo como ausente   (el menú se corrige en el acto, aunque el refresco falle)
     toast.error(MODULE_NOT_IN_PLAN_MESSAGE)
     en paralelo: navegar a /dashboard  y  planSummary.load({ force: true })
     al terminar ambos (bien o mal): liberar «en curso»
   ```
3. `module-access.messages.ts` — la constante `MODULE_NOT_IN_PLAN_MESSAGE = 'Esta funcionalidad no está incluida en tu plan'` (una sola fuente para guardia, interceptor y pruebas).

**Rationale**: «el primer rechazo muestra el aviso y lleva al inicio; los que lleguen mientras se atiende esa misma pérdida no
repiten» es literalmente la bandera «en curso»; la regla «el resumen ya dice sin módulo» cubre las respuestas lentas que
llegan **después** de terminar la atención. Marcar localmente antes del refresco hace que el menú se corrija aunque
`GET /plan` falle (el servidor ya dijo, con autoridad, que no hay módulo). Se reutiliza el cargador cacheado de la spec 101
(`createCachedLoader`, opción `force`), que además deduplica refrescos simultáneos.

**Alternativas**: devolver `EMPTY`/`NEVER` desde el interceptor para que los llamadores nunca vean el error — rechazada:
`firstValueFrom(EMPTY)` rechaza con `EmptyError` (otro mensaje de error) y `NEVER` deja promesas y spinners colgados.

## D7 — «Un solo aviso» frente a los toasts propios de cada pantalla

**Decisión**: el interceptor relanza un `HttpErrorResponse` **clonado** cuyo `error.detail` es
`MODULE_NOT_IN_PLAN_MESSAGE` (el resto del cuerpo, incluidos `code` y `module`, se conserva). El aviso global se emite con
el mismo `kind` (`'error'`) y el mismo texto, de modo que cualquier pantalla que haga `toast.error(extractError(err))`
produce un toast **idéntico**, y `ToastService.push` ya descarta duplicados exactos (bugfix de la spec 050:
`toasts().some(t => t.kind === kind && t.text === text)`).

**Límite honesto**: una pantalla que ignora `detail` y muestra un texto fijo (p. ej. `'No se pudo exportar el inventario'`,
`inventory-page.component.ts:1056`) produciría un segundo toast distinto. Es un caso residual: esa pantalla pertenece al módulo
y, tras el aviso, el usuario ya está en el inicio. Se cubre con **una tarea de auditoría** (tasks.md) que revisa los
`toast.error(...)` de texto fijo alcanzables por una acción del usuario dentro de Inventario/Proveedores/Promociones y los
hace tolerantes (no mostrar toast si `err.error?.code === 'MODULE_NOT_IN_PLAN'`).

**Alternativas**: silenciar *todos* los toasts de error durante la atención — rechazada: oculta errores legítimos que
coinciden en el tiempo; es un mecanismo más amplio de lo que pide la spec.

## D8 — Guardia de ruta: aviso, no aviso por vencido, y corregir el resumen

**Decisión**: `planModuleGuard` (a) muestra `MODULE_NOT_IN_PLAN_MESSAGE` cuando bloquea **por módulo** y **no** cuando
bloquea por `vencido` (FR-017); (b) hace `planSummaryService.hydrate(summary)` con el resumen que de todos modos acaba de
pedir, para que el menú no siga mostrando un ítem que el servidor ya negó; (c) se agrega a `proveedores` y
`proveedores/:id/detalle` (FR-015). Se conserva `catchError(() => of(true))` (fail-open si `GET /plan` falla): el
destino devolverá su 403 real y el interceptor lo atenderá.

**Rationale**: el cambio en (b) es una línea sobre datos que la guardia ya tiene; sin él, un resumen en memoria desactualizado
produciría el mismo aviso en cada clic.

## D9 — Menú: Proveedores bajo el módulo y encabezado de sección sin huérfanos

**Decisión**: el ítem `Proveedores` recibe `moduleKey: 'inventario'`. El encabezado «Inventario» del sidebar de tenant
desaparece **sin código nuevo**: `TenantSidebarComponent.groupedItems` ya descarta los grupos sin ítems visibles
(`tenant-sidebar.component.ts:267-272`). La prueba existente se amplía para fijar ambos hechos (FR-012, SC-004).
Mientras el resumen del plan es `null`, el menú sigue siendo **fail-open** (muestra), como hoy y como exige el Edge Case
«no asumir sin módulo mientras se desconoce».

## D10 — Cargas de fondo: fail-closed y reactivas (FR-014 ampliado a H1 y H2)

**Decisión**: se añade `PlanSummaryService.includes(key): boolean` —verdadero solo si el resumen existe, el negocio **no**
está vencido y el módulo está incluido—. Es el predicado **fail-closed** para *cargar datos*, a diferencia del menú, que es
fail-open para *mostrar*. Las 5 superficies de carga de fondo lo usan a través de un `effect` (no una comprobación única en
`ngOnInit`), porque el resumen llega del bootstrap de forma asíncrona y en una recarga directa sobre `/dashboard/products/new`
`ngOnInit` corre con el resumen aún en `null`: una comprobación puntual dejaría las unidades sin cargar para siempre.

| # | Superficie | Carga de fondo hoy | Condición nueva |
|---|---|---|---|
| 1 | Panel de inicio | `loadLowStock()` (`admin-dashboard.component.ts:590`) | `includes('inventario')`; la tarjeta usa la misma condición |
| 2 | Formulario de producto | `loadUnitMeasures()` (`product-form.component.ts:1218`) | `includes('inventario')` |
| 3 | Grupos de opciones | `loadAllItems()` + `loadUnitMeasures()` (`option-groups-page.component.ts:226-229`) | `includes('inventario')` |
| 4 | Formulario de adición | `loadAllItems()` + `loadUnitMeasures()` (`option-form.component.ts:160-163`) | `includes('inventario')` |
| 5 | Terminal de mesas | `promotionService.loadActive()` (`pos-terminal.store.ts:1466`) | `includes('promociones')` |

Reportes (`reports.service.ts:84-86`) y Ajustes (`settings-page.component.ts`) ya cumplen el patrón; no se tocan.

**Orden obligatorio**: estas cinco correcciones van **antes** de activar el interceptor global (I4 antes de I5 en el plan),
porque con el interceptor activo cada una de ellas dejaría de ser un error silencioso para convertirse en una expulsión.
Sin Promociones, `activePromotions()` queda en `[]` y la Terminal calcula sin descuentos exactamente como hoy (cuando
`ready()` es falso, `currentNow` devuelve `null` y se usa la lista vacía: `pos-terminal.store.ts:1118,1246,3307`).

**Alternativas**: dejar que el interceptor ignore las peticiones «de fondo» — rechazada: el front no distingue una petición
automática de una del usuario, y un `HttpContextToken` en cada llamada sería disperso y fácil de olvidar.

## D11 — La pestaña «Compras» deja de depender de un indicador propio

**Decisión**: se elimina `comprasIncluido` (`inventory-page.component.ts:876-879`) y su `@if` (`:107`). La pestaña y la vista
`inventario/compras/nueva` son visibles siempre que se pueda entrar a Inventario (FR-013, US3.5). No se crea ítem de menú
ni pantalla (decisión previa de la spec). La pestaña «Compras» no necesita guardia propia: la ruta `inventario` ya la tiene.

## D12 — Panel Super Admin: un control y confirmación al quitar Inventario

**Decisión**: `PlanFormComponent` ofrece un solo interruptor «Inventario» con texto de ayuda «Incluye Proveedores y Compras»;
se retiran `compras_access` del formulario, la interfaz y los chips de `PlansPageComponent`. La confirmación usa el
`ConfirmService` existente (`ask({ ..., tone: 'danger' })`, ya montado en `DashboardLayoutComponent`, que también envuelve las
rutas de Super Admin) y se dispara **solo** cuando `this.plan` existe, `this.plan.inventario_access === true` y el valor
enviado es `false`. Texto fijo: «Los negocios con este plan perderán Inventario, Proveedores y Compras de inmediato»,
sin conteo. Cancelar deja el formulario abierto y sin llamar al servicio (US1.8). Crear un plan, reasignar un negocio y
quitar Promociones **no** disparan la confirmación (US1.9, Assumptions).

## D13 — Importación/exportación de productos sin módulo (H3) — decisión a ratificar

**Decisión provisional** (aislada en su propio incremento I7, con commits propios y retirables, como se hizo con A-147/A-148
en la spec 138): la compuerta se aplica **a nivel de campo**, igual que la spec 064 hizo con el formulario de producto, sin
bloquear la importación/exportación de productos en sí (FR-011: el catálogo sigue funcionando):
- **Importar sin módulo**: toda fila de la hoja «Productos» con `Rastrea inventario = Sí` y **toda** fila de la hoja «Receta»
  se rechazan **por fila** con el mensaje «Tu plan actual no incluye el módulo de inventario.»; el resto del archivo se
  procesa con normalidad.
- **Exportar sin módulo**: el libro **no** incluye la hoja «Receta», y la columna `Rastrea inventario` se omite.
- Con módulo: sin cambios.

**Por qué es una decisión de negocio** (Principio II/XI): cambia el comportamiento observable de un archivo que hoy
funciona. **Qué se verifica al implementar**: que el importador tolere libros sin la hoja «Receta» ni la columna (hoy lista
las hojas esperadas en `import_.py:46,83`); si no lo tolera, el ajuste del importador es parte de I7.

**Alternativas**: (a) dejarlo para otra spec — viable y la opción por defecto si el dueño prefiere acotar 141; el costo
es que 141 se cierre con un camino por el que un negocio sin Inventario sigue leyendo/escribiendo insumos; (b) bloquear
**todo** el libro con 403 — rechazada: rompe la importación de catálogo para negocios que legítimamente no tienen Inventario.

## D14 — Decisiones de negocio a registrar (Principio II y XI)

Antes de implementar, en `specs/000-reconocimiento/registro-de-anomalias.md`, **verificando primero el siguiente número
libre** (H4; el último visible aquí es A-149):

| Propuesta | Decisión | Qué cambia | Funcionalidades afectadas |
|---|---|---|---|
| A-150 | Inventario, Proveedores y Compras son un único módulo indivisible | Reemplaza la decisión 6 de la spec 033; «Compras» deja de ser un módulo configurable; los planes (Inventario sí, Compras no) pasan a incluir Proveedores y Compras | Planes, Mi plan, panel Super Admin, endpoints de compras, menú y pestañas |
| A-151 | Un mismo código de error, aviso y conducta ante sesión activa para todos los módulos | 403 `MODULE_NOT_IN_PLAN` + `module`; aviso «Esta funcionalidad no está incluida en tu plan» + vuelta al inicio + menú actualizado; Promociones adopta lo mismo (hoy redirige sin aviso) | Todos los endpoints gobernados por módulo; guardias de ruta; interceptor |
| A-152 | Retirada incompatible de `compras` en `GET /plan` y `/super-admin/plans` (FR-022) | Los consumidores dejan de recibir el campo, sin transición | `GET /plan`, bootstrap, `/super-admin/plans` |
| A-153 *(solo si D13 se ratifica)* | Importación/exportación de productos respeta el módulo Inventario a nivel de campo | Filas con receta o `Rastrea inventario` se rechazan; el libro exportado omite la hoja Receta y la columna | Importación y exportación de productos |

## D15 — Incrementos, orden y ramas

Siete incrementos verificables (Principio VI), cada uno con su suite en verde y commits pequeños. **Ramas**
(Principio XIV), creadas desde `develop` en ambos repos **antes de tocar código**: `feat/141-unified-inventory-module`.

| # | Incremento | Repos | Historias | Depende de |
|---|---|---|---|---|
| I1 | Servidor: error `MODULE_NOT_IN_PLAN`, módulo único, prueba de inventario de rutas | backend | US2 | — |
| I2 | Migración + contratos de planes (retirar `compras`) | backend | US1 (datos), FR-019–022 | I1 |
| I3 | Front: contrato, menú, guardias, pestaña Compras, «Mi plan» | frontend | US3, US4 | I2 (o contrato acordado) |
| I4 | Front: cargas de fondo fail-closed (5 superficies) | frontend | FR-014 | I3 |
| I5 | Front: interceptor + servicio de módulo perdido | frontend | US5 | **I4** |
| I6 | Front: panel Super Admin (un control + confirmación) | frontend | US1 (UI) | I3 |
| I7 | Importación/exportación de productos (opcional, D13) | backend | FR-004 | I1 |

I4 antes de I5 es una **precondición de seguridad funcional**, no una preferencia (D10).

## D16 — Pruebas que cambian (Principio III/X)

Ninguna lleva el prefijo `CONGELA`; todas se modifican con la spec 141 como autoridad.
- **Backend (reescribir)**: `test_plan_module_access.py` (el caso `compras` desaparece; se fija `code`/`module`), `test_plan_summary.py:36`
  (`modules` sin `compras`), `test_super_admin_plans.py:44` (sin `compras_access`).
- **Backend (nuevas)**: `test_module_not_in_plan_error.py`, `test_module_route_inventory.py`, `test_plans_migration_141.py`
  (el paso de datos como función pura sobre SQLite + verificación contra PostgreSQL real con `BEGIN … ROLLBACK`).
- **Frontend (fixtures `modules: { …, compras: … }` a actualizar)**: `bootstrap.service.spec.ts:35`,
  `plan-summary.service.spec.ts:21`, `reports.service.spec.ts` (28, 235, 254, 264), `reports-page.component.spec.ts` (18, 111),
  `sidebar.component.spec.ts` (33, 93, 103, 111, 129), `tenant-sidebar.component.spec.ts` (35, 169).
- **Frontend (nuevas / ampliadas)**: interceptor, servicio de módulo perdido (incluye «un solo aviso» con N rechazos simultáneos
  y rechazo tardío), guardia (aviso, sin aviso por vencido, hidrata), `PlanSummaryService.includes`, las 5 superficies de carga,
  `admin-dashboard.component.spec.ts` («Stock bajo», que hoy espera la petición sin plan), plan-form (confirmación) y plans-page.
- **Línea base**: la suite del frontend tiene fallos preexistentes cuyo recuento deriva con la carga; se mide **al empezar** y se
  compara **por nombre de prueba**, no por recuento. Nunca se corren backend y frontend completos en paralelo.

## D17 — Documentación y trazabilidad

- `docs-publicos/06-administracion-global/gestion-de-tenants-y-planes.md` (líneas 15, 36, 62, 88, 104) y `srs/README.md:139`
  (y `srs/` donde cite `compras` como módulo) describen tres módulos: se actualizan a dos, con Compras y Proveedores dentro de Inventario.
- `specs/033-planes-suscripcion-tenant/research.md` Decisión 6: añadir una nota de sustitución «sustituida por la spec 141»
  (con aprobación del usuario, como se hizo en la spec 100).
- `specs/104-documentacion-funciones-publica/inventario-{frontend,backend}.md` son fotografías de una fecha; no se reescriben.
