# Contrato: la interfaz como espejo del plan (frontend)

**Spec**: [spec.md](../spec.md) (FR-012–FR-017, FR-019, US3–US5) · **Research**: [D6–D12](../research.md) · **API**: [modulo-no-incluido-api.md](./modulo-no-incluido-api.md)

La interfaz **nunca decide** el acceso: refleja lo que dice el plan y reacciona a lo que dice el servidor. Dos predicados distintos,
a propósito:

| Predicado | Para qué | Mientras el plan es desconocido (`summary = null`) |
|---|---|---|
| **Mostrar** (menú, pestañas, tarjetas) | pintar opciones | **fail-open**: se muestra (no se asume «sin módulo»). Comportamiento actual, se conserva |
| **Cargar datos** (`PlanSummaryService.includes(key)`) | disparar peticiones | **fail-closed**: no se carga hasta saber que el módulo está incluido; se carga en cuanto llega el resumen (reactivo) |

## 1. Texto único

```ts
// src/app/core/module-access/module-access.messages.ts
export const MODULE_NOT_IN_PLAN_MESSAGE = 'Esta funcionalidad no está incluida en tu plan';
export const MODULE_NOT_IN_PLAN_CODE = 'MODULE_NOT_IN_PLAN';
```

Una sola fuente para la guardia, el interceptor, el servicio y las pruebas. El aviso es un toast de tipo `error` (mismo `kind` y
mismo texto que el `detail` reescrito por el interceptor → el `ToastService` descarta el duplicado, spec 050).

## 2. Interceptor `moduleAccessInterceptor`

- Registro: **último** en `provideHttpClient(withInterceptors([pageIntegrity, inflightRequests, authToken, moduleAccess]))`
  (`app.config.ts`). Al ser el más interno, ve el 403 real y también el de un reintento tras refrescar el token.
- Solo actúa sobre URLs de `environment.apiBaseUrl` y sobre respuestas `HttpErrorResponse` con `status === 403` y
  cuerpo con `code === 'MODULE_NOT_IN_PLAN'`. El 403 de plan vencido, de rol o de límite **no** tiene ese código: no se toca.
- **Cuerpos `Blob`**: las peticiones con `responseType:'blob'` (`exportItems` y `downloadImportErrors` de Inventario) reciben el cuerpo del
  error como `Blob`; el interceptor lo lee (`blob.text()` + `JSON.parse`) antes de buscar el código. Si no se puede parsear, el error pasa intacto.
- Acción: `moduleAccessLost.handle(body.module)` y **relanza** un `HttpErrorResponse` clonado cuyo `error` es el cuerpo ya parseado, con
  `detail = MODULE_NOT_IN_PLAN_MESSAGE` (el resto del cuerpo se conserva). Los llamadores cierran su estado de carga como siempre y ven
  siempre un objeto, nunca un `Blob`.
- Las rutas públicas del comensal (`/cart`, `/menu/qr-token`) nunca devuelven este código; el interceptor las deja pasar sin lógica extra.

## 3. Servicio `ModuleAccessLostService` (providedIn: 'root')

```text
handle(module: keyof ModuleAccess | undefined)
  1. si hay atención en curso                                  → return         # N rechazos simultáneos o en sucesión → 1 aviso
  2. si summary() existe y summary.modules[module] es false    → return         # rechazo tardío de una petición ya en vuelo
  3. en curso := true
  4. planSummary.markModuleMissing(module)                                      # el menú se corrige en el acto
  5. toast.error(MODULE_NOT_IN_PLAN_MESSAGE)
  6. await Promise.allSettled([ router.navigateByUrl('/dashboard'), planSummary.load({ force: true }) ])
  7. en curso := false                                                          # también si algo falló
```

- **Un solo aviso y una sola redirección** (FR-016, US5.6, SC-003): los pasos 1 y 2 absorben los rechazos que llegan *mientras*
  se atiende y *después* de atender.
- **Sin recargar** (US5.1): el paso 4 es síncrono sobre la señal del resumen; el paso 6 lo confirma contra el servidor.
- `module` ausente o desconocido: se atiende igual (aviso + inicio + refresco del plan), sin marcar nada.
- Redirige a `/dashboard` (el mismo destino que ya usan las guardias; el router lo resuelve por rol).

## 4. Barrido de cargas de fondo (FR-014, research D10) — **precondición del interceptor**

Todas usan `PlanSummaryService.includes(key)` a través de un `effect` (reactivo, fail-closed). Mientras no se cumpla la condición,
**ninguna petición sale** y la superficie se oculta o queda vacía como hoy.

| # | Superficie | Archivo | Qué se condiciona | Comportamiento sin módulo |
|---|---|---|---|---|
| 1 | Panel de inicio | `modules/dashboard/pages/admin-dashboard.component.ts` | `loadLowStock()` y la tarjeta «Stock bajo» → `includes('inventario')` | Sin tarjeta y sin petición (FR-014, US3.3) |
| 2 | Formulario de producto | `modules/products/pages/product-form.component.ts` | `loadUnitMeasures()` → `includes('inventario')` | El formulario carga normal; sin sección de receta (ya oculta por `inventarioIncluido`) |
| 3 | Grupos de opciones | `modules/option-groups/pages/option-groups-page.component.ts` | `loadAllItems()` y `loadUnitMeasures()` → `includes('inventario')` | La pantalla carga grupos; sin nombres de insumo |
| 4 | Formulario de adición | `modules/option-groups/components/option-form.component.ts` | ídem | El formulario abre; el selector de insumo ya está oculto por `inventarioIncluido` |
| 5 | Terminal de mesas | `modules/tables/services/pos-terminal.store.ts` | `promotionService.loadActive()` → `includes('promociones')` | Sin descuentos de promoción, exactamente como hoy (lista vacía); **la terminal no se interrumpe** |

Ya cumplen el patrón y **no se tocan**: Reportes (`reports.service.ts`, `inventarioIncluido` fail-closed) y Ajustes
(`settings-page.component.ts`, pestaña «Unidades de medida» oculta).

**Regla de revisión**: cualquier carga nueva de un endpoint de [inventario-de-rutas.md](./inventario-de-rutas.md) fuera de las pantallas del
módulo debe pasar por `includes(...)`. La prueba de cada superficie verifica «0 peticiones HTTP sin módulo» y «la petición sale cuando el
resumen llega después de `ngOnInit`».

## 5. Menú, guardias y pestañas

| Elemento | Cambio |
|---|---|
| `NAV_ITEMS` → «Proveedores» | `moduleKey: 'inventario'` (FR-012) |
| Encabezado de sección «Inventario» (sidebar de tenant) | Desaparece solo: `groupedItems` ya descarta grupos sin ítems visibles. Se fija con prueba (SC-004) |
| `dashboard/routes.ts` → `proveedores`, `proveedores/:id/detalle` | `canActivate: [roleGuard([ADMIN]), planModuleGuard('inventario')]` (FR-015) |
| `planModuleGuard(moduleKey)` | Si bloquea **por módulo**: toast `MODULE_NOT_IN_PLAN_MESSAGE` + `UrlTree('/dashboard')`. Si bloquea **por `vencido`**: solo `UrlTree` **sin** aviso (FR-017). Hidrata `PlanSummaryService` con el resumen que acaba de pedir. Mantiene `catchError → true` |
| Rutas cubiertas | Proveedores y su detalle, Inventario y su detalle, `inventario/compras/nueva`, Ajustes › Unidades, Promociones (US4.1–US4.3) |
| Pestaña «Compras» (`inventory-page.component.ts`) | Se elimina `comprasIncluido`; la pestaña y la vista de nueva compra se ven siempre que se entra a Inventario (FR-013, US3.5) |
| «Mi plan» (`plan-summary-page.component.ts`) | Mapa de etiquetas y unión de tipos sin `compras` (FR-019, US1.7) |
| `ModuleAccess` (`plan-summary.interface.ts`) | `{ inventario: boolean; promociones: boolean }` |

## 6. Panel Super Admin

| Elemento | Contrato |
|---|---|
| `PlanFormComponent` | Interruptor «Inventario» con ayuda «Incluye Proveedores y Compras» e interruptor «Promociones». Sin `compras_access` (control, payload, valores iniciales, interfaz `Plan`/`PlanCreatePayload`) |
| `PlansPageComponent` | Chips «Inventario» · «Promociones» (sin «Compras») |
| Confirmación | Solo al **editar** (`this.plan` definido) cuando `this.plan.inventario_access === true` y el valor enviado es `false`. `ConfirmService.ask({ title, message: 'Los negocios con este plan perderán Inventario, Proveedores y Compras de inmediato', tone: 'danger' })`. Cancelar → no se llama al servicio y el formulario sigue abierto. Confirmar → se guarda. **No** aparece al crear, al reasignar el plan de un negocio ni al quitar «Promociones» (US1.8, US1.9) |

## 7. Accesibilidad y consistencia

- El aviso reutiliza el `ToastService` y su contenedor (`app-toast-container`, montado en `DashboardLayoutComponent`): mismo tratamiento
  de lectura que los demás avisos de error de la aplicación. La verificación con lector de pantalla real queda como recorrido manual.
- El diálogo de confirmación reutiliza `app-confirm-dialog` (también en `DashboardLayoutComponent`, que envuelve las rutas de Super Admin).
- Sin colores, iconos ni componentes nuevos: no hay diseño visual nuevo que contrastar.

## 8. Pruebas que fijan este contrato

| Pieza | Casos clave |
|---|---|
| Interceptor | 403 con código → llama al servicio y relanza con `detail` reescrito; 403 sin código (vencido/rol/límite) → intacto; otros estados → intacto; URL ajena a la API → intacta |
| Servicio | 1 rechazo → 1 aviso + 1 navegación + 1 refresco; **5 rechazos simultáneos → 1 y 1**; rechazo tardío con resumen ya «sin módulo» → 0; falla del refresco → menú igualmente corregido y bandera liberada; dos pérdidas sucesivas separadas en el tiempo → 2 atenciones |
| Guardia | módulo → aviso + inicio; vencido → inicio **sin** aviso; `GET /plan` falla → deja pasar; hidrata el resumen |
| `includes` | `null` → false; vencido → false; módulo ausente → false; incluido → true; reactivo |
| Cargas de fondo (×5) | sin módulo → 0 peticiones; resumen que llega tarde → la petición sale una vez; con módulo → igual que hoy |
| Menú | «Proveedores» oculto sin módulo; encabezado «Inventario» ausente; con módulo ambos presentes |
| Plan form | confirmación solo en editar+quitar; cancelar no llama; confirmar llama; crear/Promociones sin confirmación |
