# Cruce front↔back y hallazgos críticos — SkeiloPOS

**Spec**: [spec.md](./spec.md) | **Fecha de análisis**: 2026-10-08

Requiere `inventario-backend.md` e `inventario-frontend.md` completos. Cada endpoint del backend se marca consumido/no consumido/parcial contra la totalidad del inventario de frontend (no solo el grupo equivalente). Plantilla de hallazgo exacta en [contracts/plantilla-hallazgo.md](./contracts/plantilla-hallazgo.md).

## Tabla de correspondencia

### Grupo backend G1 — Identidad y acceso (`admin`, `auth`, `bootstrap`, `invitations`, `super_admin`, `tenant`, `users`)

#### `admin`

Sin endpoints que cruzar: el módulo no expone código fuente activo (ver `inventario-backend.md` § `admin`). Se verificó que tampoco existe ninguna llamada del frontend hacia `/api/v1/admin/*` [INFERIDO: ninguna cadena `api/v1/admin` aparece en `inventario-frontend.md`, que cubre la totalidad de los seis grupos F1-F6] — no hay discrepancia que registrar.

#### `auth`

| Endpoint | Estado | Consumido por | Evidencia |
|---|---|---|---|
| `POST /api/v1/auth/login` | Consumido | `LoginComponent.submit()` vía `AuthService.login()` | [CÓDIGO: pos-heladeria/src/app/modules/auth/pages/login.component.ts:137-149] [CÓDIGO: pos-heladeria/src/app/core/services/auth.service.ts:53-70,213] |
| `POST /api/v1/auth/forgot-password` | Consumido | `ForgotPasswordComponent.submit()` vía `AuthService.forgotPassword()` | [CÓDIGO: pos-heladeria/src/app/modules/auth/pages/forgot-password.component.ts:129-136] [CÓDIGO: pos-heladeria/src/app/core/services/auth.service.ts:140-151,204] |
| `GET /api/v1/auth/reset-password/validate` | Consumido | `ResetPasswordComponent` al montar, vía `AuthApiService.validateResetToken()` | [CÓDIGO: pos-heladeria/src/app/modules/auth/pages/reset-password.component.ts:281-290] |
| `POST /api/v1/auth/reset-password` | Consumido | `ResetPasswordComponent.submit()` vía `AuthService.resetPassword()` | [CÓDIGO: pos-heladeria/src/app/modules/auth/pages/reset-password.component.ts:338-341] [CÓDIGO: pos-heladeria/src/app/core/services/auth.service.ts:157-168,324] |
| `POST /api/v1/auth/change-password` | Consumido | `ChangePasswordComponent.submit()` y `AccountSettingsComponent` (mi cuenta), ambos vía `AuthService.changePassword()` | [CÓDIGO: pos-heladeria/src/app/modules/auth/pages/change-password.component.ts:160-178] [CÓDIGO: pos-heladeria/src/app/modules/account/pages/account-settings.component.ts:174-196] [CÓDIGO: pos-heladeria/src/app/core/services/auth.service.ts:101-128,168] |
| `GET /api/v1/auth/refresh-token` | Consumido | `authTokenInterceptor` en cada `401`, vía `AuthService.tryRefresh()` → `AuthApiService.refreshToken()` | [CÓDIGO: pos-heladeria/src/app/core/auth/auth-token.interceptor.ts:58-75] [CÓDIGO: pos-heladeria/src/app/core/auth/auth-api.service.ts:33-36] [CÓDIGO: pos-heladeria/src/app/core/services/auth.service.ts:193-215] |
| `GET /api/v1/auth/logout` | Consumido | `AuthService.logout()` (acción explícita del usuario) | [CÓDIGO: pos-heladeria/src/app/core/auth/auth-api.service.ts:38-40] [CÓDIGO: pos-heladeria/src/app/core/services/auth.service.ts:163-187] |

#### `bootstrap`

| Endpoint | Estado | Consumido por | Evidencia |
|---|---|---|---|
| `GET /api/v1/bootstrap` | Consumido | `BootstrapService.hydrate()` al montar el shell del dashboard (`DashboardLayoutComponent.ngOnInit`), hidrata `TenantInfoService`/`PlanSummaryService`/notificaciones sin que cada uno dispare su propio HTTP | [CÓDIGO: pos-heladeria/src/app/core/bootstrap/bootstrap.service.ts:10-37] [CÓDIGO: pos-heladeria/src/app/modules/dashboard/layout/dashboard-layout.component.ts:100,103-109] |

#### `invitations`

| Endpoint | Estado | Consumido por | Evidencia |
|---|---|---|---|
| `GET /api/v1/invitations` | Consumido | `PendingInvitationsListComponent` vía `InvitationsService.loadPendingInvitations()` | [CÓDIGO: pos-heladeria/src/app/modules/users/services/invitations.service.ts:65-88] |
| `POST /api/v1/invitations` | Consumido | `InvitationFormComponent.submit()` vía `InvitationsService.createInvitation()` | [CÓDIGO: pos-heladeria/src/app/modules/users/services/invitations.service.ts:31-63] [CÓDIGO: pos-heladeria/src/app/modules/users/components/invitation-form.component.ts:126-138] |
| `POST /api/v1/invitations/{id}/resend` | Consumido | botón "Reenviar" de `PendingInvitationsListComponent` vía `InvitationsService.resendInvitation()` | [CÓDIGO: pos-heladeria/src/app/modules/users/services/invitations.service.ts:90-102] |
| `POST /api/v1/invitations/{id}/cancel` | Consumido | botón "Cancelar" de `PendingInvitationsListComponent` vía `InvitationsService.cancelInvitation()` | [CÓDIGO: pos-heladeria/src/app/modules/users/services/invitations.service.ts:104-116] |

#### `super_admin`

| Endpoint | Estado | Consumido por | Evidencia |
|---|---|---|---|
| `GET /api/v1/super-admin/users` | Consumido | `SuperAdminUsersPageComponent` vía `SuperAdminUsersService.loadUsers()` | [CÓDIGO: pos-heladeria/src/app/modules/super-admin/services/super-admin-users.service.ts:24-36] |
| `GET /api/v1/super-admin/tenants` | Consumido | `TenantsPageComponent` (listado) y `SuperAdminUsersPageComponent` (selector de tenant del formulario), ambos vía `TenantService.loadTenants()` | [CÓDIGO: pos-heladeria/src/app/modules/super-admin/services/tenant.service.ts:23-25] [CÓDIGO: pos-heladeria/src/app/modules/super-admin/pages/super-admin-users-page.component.ts:229-233] |
| `PATCH /api/v1/super-admin/tenants/{id}` | Consumido | `TenantPlanFormComponent.onSubmit()` vía `TenantService.changePlan()` | [CÓDIGO: pos-heladeria/src/app/modules/super-admin/services/tenant.service.ts:44-62] [CÓDIGO: pos-heladeria/src/app/modules/super-admin/components/tenant-plan-form.component.ts:105-116] |
| `POST /api/v1/super-admin/tenants` | Consumido | `TenantFormComponent.onSubmit()` vía `TenantService.createTenant()` | [CÓDIGO: pos-heladeria/src/app/modules/super-admin/services/tenant.service.ts:31-42] [CÓDIGO: pos-heladeria/src/app/modules/super-admin/components/tenant-form.component.ts:302-322] |
| `GET /api/v1/super-admin/payment-methods-catalog` | Consumido | `PaymentMethodCatalogPageComponent` vía `.load()` | [CÓDIGO: pos-heladeria/src/app/modules/super-admin/services/payment-method-catalog.service.ts:23-35] |
| `POST /api/v1/super-admin/payment-methods-catalog` | Consumido | `PaymentMethodCatalogFormComponent` (alta) vía `.create()` | [CÓDIGO: pos-heladeria/src/app/modules/super-admin/services/payment-method-catalog.service.ts:37-50] |
| `PATCH /api/v1/super-admin/payment-methods-catalog/{id}` | Consumido | `PaymentMethodCatalogFormComponent` (edición y toggle activo/inactivo) vía `.update()` | [CÓDIGO: pos-heladeria/src/app/modules/super-admin/services/payment-method-catalog.service.ts:52-67] |
| `GET /api/v1/super-admin/plans` | Consumido | `PlansPageComponent`, y los selectores de plan de `TenantFormComponent`/`TenantPlanFormComponent`, vía `PlanService.load()` | [CÓDIGO: pos-heladeria/src/app/modules/super-admin/services/plan.service.ts:20-30] [CÓDIGO: pos-heladeria/src/app/modules/super-admin/components/tenant-form.component.ts:244-246] [CÓDIGO: pos-heladeria/src/app/modules/super-admin/components/tenant-plan-form.component.ts:97-99] |
| `POST /api/v1/super-admin/plans` | Consumido | `PlanFormComponent` (alta) vía `PlanService.create()` | [CÓDIGO: pos-heladeria/src/app/modules/super-admin/services/plan.service.ts:32-45] |
| `PATCH /api/v1/super-admin/plans/{id}` | Consumido | `PlanFormComponent` (edición) vía `PlanService.update()` | [CÓDIGO: pos-heladeria/src/app/modules/super-admin/services/plan.service.ts:47-60] |
| _(sin endpoint backend — ver H-01)_ | — | `SuperAdminUsersService.createUser()` llama `POST /api/v1/super-admin/users` | [CÓDIGO: pos-heladeria/src/app/modules/super-admin/services/super-admin-users.service.ts:37-62] |
| _(sin endpoint backend — ver H-01)_ | — | `SuperAdminUsersService.updateUser()`/`toggleActive()` llaman `PATCH /api/v1/super-admin/users/{id}` | [CÓDIGO: pos-heladeria/src/app/modules/super-admin/services/super-admin-users.service.ts:64-97] |

#### `tenant`

| Endpoint | Estado | Consumido por | Evidencia |
|---|---|---|---|
| `GET /api/v1/tenant` | Consumido | `TenantInfoComponent.ngOnInit()` vía `TenantInfoService.load()` | [CÓDIGO: pos-heladeria/src/app/modules/settings/pages/tenant-info.component.ts:249-252] [CÓDIGO: pos-heladeria/src/app/core/tenant/tenant-info.service.ts:90-100] |
| `PATCH /api/v1/tenant` | Consumido | `TenantInfoComponent.saveMessage()` (mensaje/prefijo) y `onLogoSelected()` (logo, encadenado con `uploads/presign`), ambos vía `TenantInfoService.update()` | [CÓDIGO: pos-heladeria/src/app/core/tenant/tenant-info.service.ts:111-123,137-175] |

#### `users`

| Endpoint | Estado | Consumido por | Evidencia |
|---|---|---|---|
| `GET /api/v1/users` | Consumido | `UsersPageComponent` vía `UsersService.loadUsers()` | [CÓDIGO: pos-heladeria/src/app/modules/users/services/users.service.ts:33-53] |
| `GET /api/v1/users/{id}` | **No consumido** — ver H-02 | `UsersService.getUser()` existe pero ninguna pantalla lo invoca | [CÓDIGO: pos-heladeria/src/app/modules/users/services/users.service.ts:91-99] |
| `PATCH /api/v1/users/{id}/role` | Consumido | `UserRoleModalComponent.onSubmit()` vía `UsersService.changeRole()` | [CÓDIGO: pos-heladeria/src/app/modules/users/services/users.service.ts:55-71] [CÓDIGO: pos-heladeria/src/app/modules/users/components/user-role-modal.component.ts:115-127] |
| `PATCH /api/v1/users/{id}/status` | Consumido | botón activar/desactivar de `UsersPageComponent` vía `UsersService.toggleActive()` | [CÓDIGO: pos-heladeria/src/app/modules/users/services/users.service.ts:73-89,275-278] |

**Corrección sobre `inventario-frontend.md` detectada durante este cruce**: la descripción original de `AuthService.tryRefresh()`/`logout()` citaba `POST /auth/refresh-token` y `POST /auth/logout`; el código real usa `GET` en ambos casos (igual que el backend) — ya corregido en el documento de origen [CÓDIGO: pos-heladeria/src/app/core/auth/auth-api.service.ts:33-40]. No es un hallazgo de discrepancia real entre sistemas, fue un error de transcripción de la Fase 4.

### Grupo backend G2 — Catálogo (`catalog`, `categories`, `products`, `unit_measures`, `menu`)

#### `catalog`

| Endpoint | Estado | Consumido por | Evidencia |
|---|---|---|---|
| `GET /api/v1/products/{id}/variants` | Consumido | `ProductService.getProductDraft()`, al abrir `/dashboard/products/:id` | [CÓDIGO: pos-heladeria/src/app/modules/products/services/product.service.ts:445-494] |
| `POST /api/v1/products/{id}/variants` | **No consumido** — ver H-04 | `ProductService.createVariant()` existe pero ningún componente lo invoca | [CÓDIGO: pos-heladeria/src/app/modules/products/services/product.service.ts:368-376] |
| `PATCH /api/v1/variants/{id}` | Consumido (parcial — solo para restaurar) | botón "Restaurar" de una presentación desactivada, vía `ProductService.restoreVariant()` (`{active:true}`); el guardado normal de una presentación pasa por `PATCH`/`POST /products/{id}`, no por aquí | [CÓDIGO: pos-heladeria/src/app/modules/products/services/product.service.ts:364-366,379-381] |
| `DELETE /api/v1/variants/{id}` | **No consumido** — ver H-04 | `ProductService.deleteVariant()` existe pero ningún componente lo invoca | [CÓDIGO: pos-heladeria/src/app/modules/products/services/product.service.ts:382-384] |
| `GET /api/v1/variants/{id}/recipe` | Consumido | `ProductService.getProductDraft()` (por cada variante activa) | [CÓDIGO: pos-heladeria/src/app/modules/products/services/product.service.ts:445-494] |
| `GET /api/v1/variants/{id}/option-groups` | Consumido | `ProductService.getProductDraft()` (por cada variante activa) | [CÓDIGO: pos-heladeria/src/app/modules/products/services/product.service.ts:445-494] |
| `GET /api/v1/option-groups` | Consumido | `OptionGroupsPageComponent` (listado) y `ProductFormComponent` (selector al armar un producto) | [CÓDIGO: pos-heladeria/src/app/modules/option-groups/services/option-group.service.ts:54-68] [CÓDIGO: pos-heladeria/src/app/modules/products/pages/product-form.component.ts:906-916] |
| `POST /api/v1/option-groups` | Consumido | formulario "Nuevo grupo de opciones" | [CÓDIGO: pos-heladeria/src/app/modules/option-groups/services/option-group.service.ts:70-84] |
| `PATCH /api/v1/option-groups/{id}` | Consumido | edición y activar/desactivar grupo | [CÓDIGO: pos-heladeria/src/app/modules/option-groups/services/option-group.service.ts:86-103] |
| `DELETE /api/v1/option-groups/{id}` | **No consumido** — ver H-04 | el toggle de activo/inactivo de la UI usa `PATCH`, nunca `DELETE` | [INFERIDO: `grep -rn "http\.delete" pos-heladeria/src/app` no incluye ninguna llamada a `/option-groups`] |
| `POST /api/v1/option-groups/{id}/options` | Consumido | botón "Agregar opción" | [CÓDIGO: pos-heladeria/src/app/modules/option-groups/services/option-group.service.ts:105-115] |
| `PATCH /api/v1/options/{id}` | Consumido | edición y activar/desactivar opción | [CÓDIGO: pos-heladeria/src/app/modules/option-groups/services/option-group.service.ts:117-135] |
| `DELETE /api/v1/options/{id}` | **No consumido** — ver H-04 | mismo patrón: el toggle usa `PATCH` | [INFERIDO: `grep -rn "http\.delete" pos-heladeria/src/app` no incluye ninguna llamada a `/options`] |

#### `categories`

| Endpoint | Estado | Consumido por | Evidencia |
|---|---|---|---|
| `GET /api/v1/categories` | Consumido | `CategoriesPageComponent` (paginado) y selectores de otros módulos (`?size=100`) | [CÓDIGO: pos-heladeria/src/app/modules/categories/services/category.service.ts:36-52,68-79] |
| `GET /api/v1/categories/{id}` | **No consumido** — ver H-05 | `CategoryService` no define siquiera un método que lo llame | [INFERIDO: `category.service.ts` solo contiene dos `http.get`, ambos contra la raíz paginada] |
| `POST /api/v1/categories` | Consumido | formulario "Nueva categoría" | [CÓDIGO: pos-heladeria/src/app/modules/categories/services/category.service.ts:106-128] |
| `PATCH /api/v1/categories/{id}` | Consumido | edición y activar/desactivar | [CÓDIGO: pos-heladeria/src/app/modules/categories/services/category.service.ts:130-165] |
| `DELETE /api/v1/categories/{id}` | **No consumido** — ver H-04 | el toggle de activo/inactivo usa `PATCH` | [INFERIDO: `category.service.ts` no contiene ningún `http.delete`] |

**Hallazgo de rol transversal a `categories`**: ver H-03 (el backend no exige `ADMIN` en ninguna de las 4 rutas; el frontend solo permite llegar aquí como `ADMIN`).

#### `products`

| Endpoint | Estado | Consumido por | Evidencia |
|---|---|---|---|
| `GET /api/v1/products` | Consumido | `ProductsPageComponent` (listado paginado, Admin y Cajero) | [CÓDIGO: pos-heladeria/src/app/modules/products/services/product.service.ts:155-176,196-210] |
| `GET /api/v1/products/{id}` | Consumido | `/dashboard/products/:id/detalle` (Cajero) y como parte de `getProductDraft()` (Admin) | [CÓDIGO: pos-heladeria/src/app/modules/products/services/product.service.ts:252-265] |
| `PATCH /api/v1/products/{id}/availability` | Consumido | toggle "Agotado" (Admin y Cajero) | [CÓDIGO: pos-heladeria/src/app/modules/products/services/product.service.ts:325-333] |
| `POST /api/v1/products` | Consumido | `/dashboard/products/new` | [CÓDIGO: pos-heladeria/src/app/modules/products/services/product.service.ts:538-553] |
| `PATCH /api/v1/products/{id}` | Consumido | guardado del árbol completo en `/dashboard/products/:id`, y toggle activo/inactivo | [CÓDIGO: pos-heladeria/src/app/modules/products/services/product.service.ts:312-319,555-575] |
| `PUT /api/v1/products/{id}` | **No consumido** — ver H-04 | el frontend nunca usa `http.put` contra la API propia (solo contra URLs prefirmadas de R2) | [INFERIDO: `grep -rn "http\.put" pos-heladeria/src/app` solo devuelve subidas directas a `presign.upload_url`, ninguna a `/products`] |
| `DELETE /api/v1/products/{id}` | **No consumido** — ver H-04 | el toggle de activo/inactivo usa `PATCH` | [INFERIDO: `product.service.ts` no contiene ningún `http.delete` hacia `/products`] |

#### `unit_measures`

| Endpoint | Estado | Consumido por | Evidencia |
|---|---|---|---|
| `GET /api/v1/unit-measures` | Consumido | `/dashboard/ajustes/unidades` y selectores de insumo/producto de otros módulos | [CÓDIGO: pos-heladeria/src/app/core/services/unit-measure.service.ts:24-36] |
| `GET /api/v1/unit-measures/{id}` | **No consumido** — ver H-05 | `UnitMeasureService` no define ningún método que lo llame | [INFERIDO: único `http.get` del servicio apunta a la raíz de la lista] |
| `POST /api/v1/unit-measures` | Consumido | formulario "Nueva unidad" | [CÓDIGO: pos-heladeria/src/app/core/services/unit-measure.service.ts:38-55] |
| `PATCH /api/v1/unit-measures/{id}` | Consumido | edición y activar/desactivar | [CÓDIGO: pos-heladeria/src/app/core/services/unit-measure.service.ts:57-90] |
| `DELETE /api/v1/unit-measures/{id}` | **No consumido** — ver H-04 | el toggle de activo/inactivo usa `PATCH` | [INFERIDO: `unit-measure.service.ts` no contiene ningún `http.delete`] |

**Hallazgo de rol transversal a `unit_measures`**: ver H-03 (mismo patrón que `categories` — el backend solo gatea por módulo de plan, nunca por rol).

#### `menu`

| Endpoint | Estado | Consumido por | Evidencia |
|---|---|---|---|
| `GET /api/v1/menu` | Consumido | Terminal de mesas (`PosTerminalStore.init()`), `/dashboard/orders/:id` (resolver nombres) y `/dashboard/promotions` (selector de variantes), vía `MenuService.loadMenu()` | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/pos-terminal.store.ts:1220-1240] [CÓDIGO: pos-heladeria/src/app/modules/orders/pages/order-detail.component.ts:248-250] [CÓDIGO: pos-heladeria/src/app/modules/promotions/pages/promotions-page.component.ts:1619-1628] [CÓDIGO: pos-heladeria/src/app/core/services/menu.service.ts:103-116] — corregido durante este cruce: la Fase 4 solo citaba "menú" en prosa, sin el endpoint exacto |
| `GET /api/v1/menu/promotions` | **No consumido** — ver H-05 | ningún archivo de `pos-heladeria` llama a esta ruta | [INFERIDO: `grep -rn "menu/promotions" pos-heladeria/src/app` no devuelve resultados] |
| `GET /api/v1/menu/qr-token/{token}` | Consumido | `/menu/t/:token` (`PublicMenuComponent`), vía `DinerService` | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/diner.service.ts:135-140] |

### Grupo backend G3 — Presentaciones, promociones e inventario (`presentations`, `promotions`, `inventory`)

#### `presentations`

| Endpoint | Estado | Consumido por | Evidencia |
|---|---|---|---|
| `GET /api/v1/presentations` | Consumido | `/dashboard/presentations` (paginado) y selectores de `categories`/`products` (`?size=100`) | [CÓDIGO: pos-heladeria/src/app/modules/presentations/services/presentation.service.ts:46-78] |
| `GET /api/v1/presentations/{id}` | **No consumido** — ver H-05 | `PresentationService` no define ningún método que lo llame | [INFERIDO: el servicio solo contiene los dos `http.get` de la raíz, ver línea 49/77] |
| `POST /api/v1/presentations` | Consumido | modal "Nueva Presentación" | [CÓDIGO: pos-heladeria/src/app/modules/presentations/services/presentation.service.ts:105-120] |
| `PATCH /api/v1/presentations/{id}` | Consumido | edición de nombre y activar/desactivar | [CÓDIGO: pos-heladeria/src/app/modules/presentations/services/presentation.service.ts:122-152] |

**Hallazgo de rol transversal a `presentations`**: ver H-03 (el backend no exige `ADMIN` en ninguna de sus 4 rutas; el frontend solo permite llegar aquí como `ADMIN`).

#### `promotions`

| Endpoint | Estado | Consumido por | Evidencia |
|---|---|---|---|
| `GET /api/v1/promotions` | Consumido | listado paginado, vigentes activas (`?status=active&size=100`, reutilizado por la Terminal) y banner de migración (`?closed_by_refactor=true`) | [CÓDIGO: pos-heladeria/src/app/modules/promotions/services/promotion.service.ts:61-111] |
| `POST /api/v1/promotions` | Consumido | pantalla "create" (botón "Continuar") | [CÓDIGO: pos-heladeria/src/app/modules/promotions/services/promotion.service.ts:172-176] |
| `PATCH /api/v1/promotions/{id}` | Consumido | edición de escalares en "configure" | [CÓDIGO: pos-heladeria/src/app/modules/promotions/services/promotion.service.ts:179-182] |
| `PATCH /api/v1/promotions/{id}/shape` | Consumido | botón "Guardar y sincronizar" (reemplazo de reglas) | [CÓDIGO: pos-heladeria/src/app/modules/promotions/services/promotion.service.ts:186-189] |
| `PATCH /api/v1/promotions/{id}/status` | Consumido | botones Activar/Pausar/Finalizar | [CÓDIGO: pos-heladeria/src/app/modules/promotions/services/promotion.service.ts:191-194] |
| `POST /api/v1/promotions/{id}/duplicate` | Consumido | acción "Duplicar" del menú por fila | [CÓDIGO: pos-heladeria/src/app/modules/promotions/services/promotion.service.ts:196-201] |
| `DELETE /api/v1/promotions/{id}` | Consumido | acción "Eliminar" del menú por fila | [CÓDIGO: pos-heladeria/src/app/modules/promotions/services/promotion.service.ts:203-206] |

#### `inventory`

| Endpoint | Estado | Consumido por | Evidencia |
|---|---|---|---|
| `GET /api/v1/inventory/items` | Consumido | pestaña "Insumos" (paginado) y picker (`?size=100`) | [CÓDIGO: pos-heladeria/src/app/modules/inventory/services/inventory.service.ts:107-140] |
| `GET /api/v1/inventory/items/low-stock` | Consumido | alerta "Bajo mínimo" | [CÓDIGO: pos-heladeria/src/app/modules/inventory/services/inventory.service.ts:199-215] |
| `GET /api/v1/inventory/items/export` | Consumido | botón "Exportar" (.xlsx) | [CÓDIGO: pos-heladeria/src/app/modules/inventory/services/inventory.service.ts:283-289,509-523] |
| `GET /api/v1/inventory/items/{id}` | **No consumido** — ver H-05 | `InventoryService` no define ningún método que lo llame | [INFERIDO: el servicio solo tiene `http.get` contra `/items` (lista), `/items/low-stock`, `/items/export`, `/items/{id}/movements`, `/suppliers` y `/purchases` — ningún `/items/{id}` suelto] |
| `POST /api/v1/inventory/items` | Consumido | modal "Nuevo insumo" | [CÓDIGO: pos-heladeria/src/app/modules/inventory/services/inventory.service.ts:237-249] |
| `PATCH /api/v1/inventory/items/{id}` | Consumido | edición y activar/desactivar insumo | [CÓDIGO: pos-heladeria/src/app/modules/inventory/services/inventory.service.ts:251-269] |
| `POST /api/v1/inventory/items/{id}/adjust` | Consumido | modal "Ajustar stock" | [CÓDIGO: pos-heladeria/src/app/modules/inventory/services/inventory.service.ts:271-281] |
| `GET /api/v1/inventory/items/{id}/movements` | Consumido | pestaña "Movimientos" (kardex) | [CÓDIGO: pos-heladeria/src/app/modules/inventory/services/inventory.service.ts:292-303] |
| `GET /api/v1/inventory/suppliers` | Consumido | `/dashboard/proveedores` | [CÓDIGO: pos-heladeria/src/app/modules/suppliers/services/suppliers.service.ts:13-40] |
| `POST /api/v1/inventory/suppliers` | Consumido | modal "Nuevo proveedor" | [CÓDIGO: pos-heladeria/src/app/modules/suppliers/services/suppliers.service.ts:42-50] |
| `PATCH /api/v1/inventory/suppliers/{id}` | Consumido | edición y activar/desactivar proveedor | [CÓDIGO: pos-heladeria/src/app/modules/suppliers/services/suppliers.service.ts:52-69] |
| `GET /api/v1/inventory/purchases` | Consumido | pestaña "Compras" (paginado) | [CÓDIGO: pos-heladeria/src/app/modules/inventory/services/inventory.service.ts:305-322] |
| `POST /api/v1/inventory/purchases` | Consumido | modal "Nueva compra" (compra directa) | [CÓDIGO: pos-heladeria/src/app/modules/inventory/services/inventory.service.ts:325-327] |
| `POST /api/v1/inventory/purchases/order` | Consumido | modal "Nueva compra" con checkbox "Crear como orden de compra" | [CÓDIGO: pos-heladeria/src/app/modules/inventory/services/inventory.service.ts:329-332] |
| `POST /api/v1/inventory/purchases/{id}/receive` | Consumido | acción "Recibir" sobre una compra pendiente | [CÓDIGO: pos-heladeria/src/app/modules/inventory/services/inventory.service.ts:362-385] |

**Hallazgo de rol transversal a `inventory`**: ver H-06 (las 6 rutas de solo lectura no exigen `ADMIN`, aunque la UI reserva el módulo completo a Admin y las mutaciones del mismo router sí lo exigen).

### Grupo backend G4 — Pedidos y mesas (`orders`, `table_sessions`, `tables`, `cart`, `business_hours`)

#### `tables` y `business_hours`

Sin endpoints que cruzar en ninguno de los dos: `tables` no tiene código fuente activo (su funcionalidad real vive en `orders` — ver `inventario-backend.md` § `tables`) y `business_hours` es un módulo huérfano sin router registrado. Ninguna cadena `business_hours`/`horario` aparece en `pos-heladeria/src/app` [INFERIDO: búsqueda literal sin resultados] — no hay discrepancia que registrar en ninguno de los dos.

#### `orders` — Mesas

| Endpoint | Estado | Consumido por | Evidencia |
|---|---|---|---|
| `GET /api/v1/orders/tables` | Consumido | `/dashboard/mesas`, `/dashboard/mesas/qr`, `OrdersPageComponent` (resolver etiqueta), Terminal | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/table.service.ts:46-69,78-83] |
| `POST /api/v1/orders/tables` | Consumido | modal "Nueva mesa" | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/table.service.ts:92-110] |
| `PATCH /api/v1/orders/tables/{id}` | Consumido | edición de nombre y activar/desactivar | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/table.service.ts:112-142] |
| `PATCH /api/v1/orders/tables/{id}/status` | Consumido | `<select>` inline de estado | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/table.service.ts:149-163] |
| `POST /api/v1/orders/{id}/move` | **No consumido** — ver H-07 | `TableService.moveOrder()` existe pero ningún componente lo invoca | [INFERIDO: cero ocurrencias de `.moveOrder(` fuera de su propia declaración en `table.service.ts:166-169`] |
| `POST /api/v1/orders/merge` | **No consumido** — ver H-07 | `TableService.mergeOrders()` existe pero ningún componente lo invoca | [INFERIDO: cero ocurrencias de `.mergeOrders(` fuera de `table.service.ts:172-179`] |
| `GET /api/v1/orders/group/{id}/bill` | **No consumido** — ver H-07 | `TableService.groupBill()` existe pero ningún componente lo invoca | [INFERIDO: cero ocurrencias de `.groupBill(` fuera de `table.service.ts:182-184`] |
| `GET /api/v1/orders/tables/{id}/qr-token` | Consumido | modal "Ver QR" y hoja de impresión | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/table.service.ts:144-147] |
| `POST /api/v1/orders/tables/{id}/release` | **No consumido** — ver H-07 | el botón "Liberar Mesa" de la Terminal llama a `TableSessionService.release()` (`POST /table-sessions/{id}/release`), no a este endpoint de `orders` | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/table-session.service.ts:58-69] [INFERIDO: cero ocurrencias de `orders/tables/${...}/release` en todo `pos-heladeria/src/app`] |

#### `orders` — Comandas

| Endpoint | Estado | Consumido por | Evidencia |
|---|---|---|---|
| `POST /api/v1/orders` | Consumido | "Crear pedido" en `ManualOrderPageComponent` (`hold_for_payment: true`) | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/pos-terminal.store.ts:1582-1591] |
| `GET /api/v1/orders` | Consumido | `/dashboard/orders`, recarga de la Terminal, detalle de orden | [CÓDIGO: pos-heladeria/src/app/modules/orders/services/orders-list.service.ts:61-71] |
| `GET /api/v1/orders/{id}` | Consumido | `/dashboard/orders/:id` | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/dining-session.service.ts:51-53] |
| `POST /api/v1/orders/tables/{id}/consolidate` | **No consumido** — ver H-07 | ninguna cadena `consolidate`/`consolidar` aparece en todo `pos-heladeria/src/app` | [INFERIDO: búsqueda literal sin resultados] |
| `POST /api/v1/orders/{id}/items` | Consumido (parcial — rol `MESERO` bloqueado por bug del backend, ver H-09) | "＋ Agregar producto" del Panel de pedido de la Terminal | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/dining-session.service.ts:224-228] |
| `POST /api/v1/orders/{id}/confirm` | **No consumido** — ver H-08 | `DiningSessionService.confirmOrder()` solo se invoca desde su propio test unitario, nunca desde un componente | [INFERIDO: única ocurrencia de `.confirmOrder(` fuera de su declaración está en `dining-session.service.spec.ts:70`] |

#### `orders` — Intentos de pago del cajero

| Endpoint | Estado | Consumido por | Evidencia |
|---|---|---|---|
| `GET /api/v1/orders/{id}/payment-attempts` | Consumido | `PaymentAttemptReviewPanelComponent` ("Pagos por confirmar") | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/dining-session.service.ts:171-178] |
| `POST /api/v1/orders/payment-attempts/{id}/approve` | Consumido | botón "Aprobar" (transferencia con comprobante) | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/dining-session.service.ts:180-190] |
| `POST /api/v1/orders/payment-attempts/{id}/reject` | Consumido | botón "Rechazar" (motivo obligatorio) | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/dining-session.service.ts:192-200] |
| `POST /api/v1/orders/payment-attempts/{id}/confirm-cash` | Consumido | "Confirmar efectivo" | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/dining-session.service.ts:202-216] |

#### `orders` — Preparación/cocina

| Endpoint | Estado | Consumido por | Evidencia |
|---|---|---|---|
| `PATCH /api/v1/orders/items/{id}/kitchen` | Consumido | "Marcar listo" | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/dining-session.service.ts:150-153] |
| `POST /api/v1/orders/{id}/ready` | Consumido | avance de pedido a listo (consolidación) | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/dining-session.service.ts:163] |
| `POST /api/v1/orders/items/{id}/void` | Consumido | "Anular" línea/combo | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/dining-session.service.ts:230-234] |

#### `orders` — Cobro y cierre

| Endpoint | Estado | Consumido por | Evidencia |
|---|---|---|---|
| `GET /api/v1/orders/tables/{id}/bill` | **No consumido** — ver H-07 | ninguna cadena `tables/${...}/bill` aparece en `pos-heladeria/src/app` (la Terminal usa en su lugar `GET /table-sessions/{id}/bill`) | [INFERIDO: búsqueda literal sin resultados] |
| `GET /api/v1/orders/{id}/checkout-preview` | Consumido | desglose autoritativo antes de cobrar (mostrador y borrador) | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/dining-session.service.ts:87-89] |
| `POST /api/v1/orders/draft-preview` | Consumido | `ManualOrderPageComponent` en cada cambio de línea | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/dining-session.service.ts:99] |
| `POST /api/v1/orders/{id}/block` | **No consumido** — ver H-08 | ninguna cadena `/block` contra `orders` aparece en `pos-heladeria/src/app` | [INFERIDO: búsqueda literal sin resultados] |
| `POST /api/v1/orders/{id}/pay` | **No consumido** — ver H-08 | ninguna cadena `/pay` contra `orders` aparece en `pos-heladeria/src/app` (solo un comentario de tipos) | [INFERIDO: pos-heladeria/src/app/modules/tables/interfaces/dining.interface.ts:191 es un comentario, no una llamada] |
| `POST /api/v1/orders/{id}/checkout-and-send` | Consumido | botón "Cobrar" (mostrador/mesa sin cobrar) | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/dining-session.service.ts:74-77] |
| `POST /api/v1/orders/{id}/cancel` | Consumido | "Rechazar pedido" / "cancelar pedido propio" | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/dining-session.service.ts:138] |

#### `table_sessions`

| Endpoint | Estado | Consumido por | Evidencia |
|---|---|---|---|
| `GET /api/v1/table-sessions` | Consumido | `ensureCheckoutDataLoaded()` (resolver sesión de la mesa seleccionada) | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/pos-terminal.store.ts:2118] |
| `GET /api/v1/table-sessions/{id}` | **No consumido** — ver H-05 | `TableSessionService.get()` existe pero ningún componente lo invoca (la Terminal resuelve la sesión con `list()`) | [INFERIDO: cero ocurrencias de `.get(` de este servicio fuera de su propia declaración] |
| `POST /api/v1/table-sessions/{id}/participants` | **No consumido** — ver H-07 | ninguna cadena `/participants` aparece en `pos-heladeria/src/app` | [INFERIDO: búsqueda literal sin resultados] |
| `DELETE /api/v1/table-sessions/{id}/participants/{pid}` | **No consumido** — ver H-07 | idéntica ausencia | [INFERIDO: búsqueda literal sin resultados] |
| `PUT /api/v1/table-sessions/{id}/assignments` | **No consumido** — ver H-07 | ninguna cadena `/assignments` aparece en `pos-heladeria/src/app` | [INFERIDO: búsqueda literal sin resultados] |
| `GET /api/v1/table-sessions/{id}/bill` | Consumido | mismo flujo que la lista — cuenta de la sesión seleccionada | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/pos-terminal.store.ts:2120] |
| `POST /api/v1/table-sessions/{id}/close` | Consumido | botón "Cobrar y cerrar mesa" | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/table-session.service.ts:52-56] |
| `POST /api/v1/table-sessions/{id}/release` | Consumido | botón "Liberar Mesa" | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/table-session.service.ts:64-68] |

#### `cart`

| Endpoint | Estado | Consumido por | Evidencia |
|---|---|---|---|
| `POST /api/v1/cart/sessions` | Consumido | formulario de nombre al escanear el QR | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/diner.service.ts:148-157] |
| `GET /api/v1/cart` | Consumido | hidratación del carrito del comensal | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/diner.service.ts:162-178] |
| `POST /api/v1/cart/items` | Consumido | agregar producto al carrito | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/diner.service.ts:162-178] |
| `PATCH /api/v1/cart/items/{id}` | Consumido | `±`/nota de línea del carrito | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/diner.service.ts:162-178] |
| `DELETE /api/v1/cart/items/{id}` | Consumido | eliminar línea del carrito | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/diner.service.ts:177] |
| `POST /api/v1/cart/leave` | Consumido | botón "Salir" | [CÓDIGO: pos-heladeria/src/app/modules/tables/pages/public-menu.component.ts:1402-1414] |
| `POST /api/v1/cart/submit` | Consumido | pago en efectivo (paso 2) y envío tras adjuntar comprobante (paso 3) | [CÓDIGO: pos-heladeria/src/app/modules/tables/pages/checkout/payment-method-step.component.ts:109-128] [CÓDIGO: pos-heladeria/src/app/modules/tables/pages/checkout/transfer-details-step.component.ts:384-400] |
| `GET /api/v1/cart/orders` | Consumido | `ConfirmationStepComponent.myOrders()` (fallback sin guard) | [CÓDIGO: pos-heladeria/src/app/modules/tables/pages/checkout/confirmation-step.component.ts:96-103] |
| `POST /api/v1/cart/orders/{id}/cancel` | Consumido | cancelar pedido propio ("Mis pedidos") | [CÓDIGO: pos-heladeria/src/app/modules/tables/pages/public-menu.component.ts:1286] |
| `GET /api/v1/cart/payment-methods` | Consumido | Paso 2 y Paso 3 del checkout | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/diner.service.ts:183-187] |
| `POST /api/v1/cart/payment-receipt/presign` | Consumido | Paso 3 (subida de comprobante) | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/diner.service.ts:225-246] |
| `POST /api/v1/cart/orders/{id}/payment-attempts` | Consumido | abrir pago de un pedido propio desde "Mis pedidos" | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/diner.service.ts:183-246] |
| `POST /api/v1/cart/payment-attempts/{id}/receipt/presign` | Consumido | mismo flujo | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/diner.service.ts:183-246] |
| `POST /api/v1/cart/payment-attempts/{id}/receipt` | Consumido | mismo flujo | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/diner.service.ts:183-246] |

**Nota de rol transversal**: la lista `_MESERO_ALLOWED_ROUTES` del backend confirma que `move`, `merge`, `group/bill`, `consolidate`, `tables/{id}/bill`, `tables/{id}/release`, `confirm`, `block`, `pay`, `participants` (alta/baja) y `assignments` fueron deliberadamente habilitados para el rol Mesero (spec 075) [CÓDIGO: pos-backend/app/core/dependencies.py:139-191] — no son descuido del backend: alguien los diseñó para que la Terminal los usara, y la Terminal nunca llegó a implementarlos (ver H-07) o los reemplazó por otro camino (ver H-08).

### Grupo backend G5 — Caja, ventas y facturación (`cash`, `sales`, `invoices`, `reports`, `audit`, `plan`)

#### `cash`

| Endpoint | Estado | Consumido por | Evidencia |
|---|---|---|---|
| `GET /api/v1/cash/registers` | Consumido | selector de caja en "Apertura"/"Gestión de cajas" | [CÓDIGO: pos-heladeria/src/app/modules/cash-register/services/cash.service.ts:96-98] |
| `POST /api/v1/cash/registers` | Consumido | "Crear caja" | [CÓDIGO: pos-heladeria/src/app/modules/cash-register/services/cash.service.ts:100-102] |
| `GET /api/v1/cash/shifts` | Consumido | pantalla "Historial" | [CÓDIGO: pos-heladeria/src/app/modules/cash-register/services/cash.service.ts:150-164] |
| `POST /api/v1/cash/shifts/open` | Consumido | "Abrir caja y comenzar turno" | [CÓDIGO: pos-heladeria/src/app/modules/cash-register/services/cash.service.ts:104-111] |
| `GET /api/v1/cash/shifts/current` | Consumido | `discoverOpenShift()` al montar | [CÓDIGO: pos-heladeria/src/app/modules/cash-register/services/cash.service.ts:113-120] |
| `POST /api/v1/cash/shifts/{id}/close` | Consumido | "Confirmar arqueo y cerrar caja" | [CÓDIGO: pos-heladeria/src/app/modules/cash-register/services/cash.service.ts:140-144] |
| `GET /api/v1/cash/shifts/{id}/reconciliation` | Consumido | modal de arqueo (desglose en vivo) | [CÓDIGO: pos-heladeria/src/app/modules/cash-register/services/cash.service.ts:134-138] |
| `GET /api/v1/cash/shifts/{id}/report` | Consumido | pantalla "Reporte" / "Ver reporte" del historial | [CÓDIGO: pos-heladeria/src/app/modules/cash-register/services/cash.service.ts:146-148] |
| `GET /api/v1/cash/shifts/{id}/movements` | Consumido | línea de tiempo/tabla de movimientos del turno | [CÓDIGO: pos-heladeria/src/app/modules/cash-register/services/cash.service.ts:128-132] |
| `POST /api/v1/cash/shifts/{id}/movements` | Consumido | modal "+ Ingreso"/"− Egreso"/"↓ Retiro" | [CÓDIGO: pos-heladeria/src/app/modules/cash-register/services/cash.service.ts:122-126] |

#### `sales`

| Endpoint | Estado | Consumido por | Evidencia |
|---|---|---|---|
| `GET /api/v1/sales/payment-methods/catalog` | Consumido | modal "+ Activar método" | [CÓDIGO: pos-heladeria/src/app/modules/sales/services/payment-method-catalog.service.ts:16-34] |
| `GET /api/v1/sales/payment-methods` | Consumido | `/dashboard/ajustes/metodos-pago` | [CÓDIGO: pos-heladeria/src/app/modules/sales/services/payment-method.service.ts:25-35] |
| `POST /api/v1/sales/payment-methods` | Consumido | activar método del catálogo | [CÓDIGO: pos-heladeria/src/app/modules/sales/services/payment-method.service.ts:64-82] |
| `PATCH /api/v1/sales/payment-methods/{id}` | Consumido | editar campos y toggle activo/inactivo | [CÓDIGO: pos-heladeria/src/app/modules/sales/services/payment-method.service.ts:91-109] |
| `POST /api/v1/sales` | **No consumido** — ver H-10 | `SalesService.checkout()` existe pero `SalesPageComponent` no lo invoca y no se encontró ningún otro llamador fuera de pruebas unitarias | [INFERIDO: `inventario-frontend.md` ya documenta explícitamente esta ausencia — búsqueda de `.checkout(` fuera de `*.spec.ts` sin resultados] |
| `GET /api/v1/sales` | Consumido | `/dashboard/ventas` (listado paginado) | [CÓDIGO: pos-heladeria/src/app/modules/sales/services/sales.service.ts:65-79] |
| `GET /api/v1/sales/{id}` | Consumido | "Reimprimir Factura POS" desde la Terminal (`findSaleForOrder()`), no desde `/dashboard/ventas` (que reusa la fila ya cargada) | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/dining-session.service.ts:111-120] [CÓDIGO: pos-heladeria/src/app/modules/tables/services/pos-terminal.store.ts:341,2465] |

#### `invoices`

| Endpoint | Estado | Consumido por | Evidencia |
|---|---|---|---|
| `GET /api/v1/invoices/{id}` | **No consumido** — ver H-05 | ninguna cadena `invoices/${` aparece en `pos-heladeria/src/app` | [INFERIDO: búsqueda literal sin resultados] |
| `GET /api/v1/invoices` | Consumido | `findSaleForOrder()` filtra por `order_id` para resolver la venta antes de reimprimir | [CÓDIGO: pos-heladeria/src/app/modules/tables/services/dining-session.service.ts:111-120] |

#### `reports`

| Endpoint | Estado | Consumido por | Evidencia |
|---|---|---|---|
| `GET /api/v1/reports/sales` | Consumido | gráfica de ventas por día | [CÓDIGO: pos-heladeria/src/app/modules/reports/services/reports.service.ts:98-106] |
| `GET /api/v1/reports/products` | **No consumido** — ver H-05 | `ReportsService` no define ningún método que lo llame (la pantalla usa `top-products`, no este) | [INFERIDO: `reports.service.ts` no contiene ninguna llamada a `/reports/products` sin `top-`] |
| `GET /api/v1/reports/top-products` | Consumido | gráfica "Productos más vendidos" | [CÓDIGO: pos-heladeria/src/app/modules/reports/services/reports.service.ts:108-116] |
| `GET /api/v1/reports/categories` | Consumido | gráfica por categoría | [CÓDIGO: pos-heladeria/src/app/modules/reports/services/reports.service.ts:118-124] |
| `GET /api/v1/reports/cashiers` | Consumido | gráfica por cajero | [CÓDIGO: pos-heladeria/src/app/modules/reports/services/reports.service.ts:126-132] |
| `GET /api/v1/reports/inventory` | Consumido | tarjeta "Insumos con stock bajo" (solo si el plan incluye Inventario) | [CÓDIGO: pos-heladeria/src/app/modules/reports/services/reports.service.ts:134-141] |
| `GET /api/v1/reports/profitability` | Consumido | datos de margen (solo si el plan incluye Inventario) | [CÓDIGO: pos-heladeria/src/app/modules/reports/services/reports.service.ts:143-153] |

#### `audit`

| Endpoint | Estado | Consumido por | Evidencia |
|---|---|---|---|
| `GET /api/v1/audit-logs` | **No consumido** — ver H-05 | ninguna cadena `audit-logs`/`audit_logs` aparece en `pos-heladeria/src/app`: no existe ninguna pantalla de auditoría en el frontend | [INFERIDO: búsqueda literal sin resultados] |

#### `plan`

| Endpoint | Estado | Consumido por | Evidencia |
|---|---|---|---|
| `GET /api/v1/plan` | Consumido | `PlanSummaryService.load()`, hidratado también por `GET /bootstrap` | [CÓDIGO: pos-heladeria/src/app/modules/plan/services/plan-summary.service.ts:22-24,32-52] |

### Grupo backend G6 — Infraestructura técnica (`health`, `notifications`, `realtime`, `uploads`)

#### `health`

| Endpoint | Estado | Consumido por | Evidencia |
|---|---|---|---|
| `GET /api/v1/health` | No consumido por `pos-heladeria` — sin discrepancia | pensado para infraestructura (balanceador/orquestador), no para la SPA; `include_in_schema=False` y sin `x-tenant-host` lo confirman como fuera del contrato de la app | [INFERIDO: ninguna cadena `/health` aparece en `pos-heladeria/src/app`; coherente con `inventario-backend.md` § `health`, que lo describe como liveness trivial sin tenant] |

#### `notifications`

| Endpoint | Estado | Consumido por | Evidencia |
|---|---|---|---|
| `GET /api/v1/notifications` | Consumido | `NotificationCenterService` (campanita del header, con y sin `after_id` para recuperación) | [CÓDIGO: pos-heladeria/src/app/core/notifications/notification-center.service.ts:109-118] |
| `GET /api/v1/notifications/push/public-key` | Consumido | registro de push al habilitar notificaciones | [CÓDIGO: pos-heladeria/src/app/core/notifications/push-registration.service.ts:58-66] |
| `POST /api/v1/notifications/push/subscriptions` | Consumido | mismo flujo de registro | [CÓDIGO: pos-heladeria/src/app/core/notifications/push-registration.service.ts:67-75] |
| `DELETE /api/v1/notifications/push/subscriptions` | Consumido | desregistro al cerrar sesión (`logout()`) | [CÓDIGO: pos-heladeria/src/app/core/notifications/push-registration.service.ts:85-93] |
| `POST /api/v1/notifications/{id}/attend` | Consumido | marcar notificación como atendida desde la campanita | [CÓDIGO: pos-heladeria/src/app/core/notifications/notification-center.service.ts:88-98] |

#### `realtime`

| Endpoint | Estado | Consumido por | Evidencia |
|---|---|---|---|
| `POST /api/v1/realtime/ticket` | Consumido | `RealtimeService` antes de abrir el stream de staff | [CÓDIGO: pos-heladeria/src/app/core/realtime/realtime.service.ts:50-58] |
| `GET /api/v1/realtime/stream` | Consumido | `EventSource` (staff y comensal), conexión SSE de la Terminal y del shell del comensal | [CÓDIGO: pos-heladeria/src/app/core/realtime/realtime.service.ts:90-96] |

#### `uploads`

| Endpoint | Estado | Consumido por | Evidencia |
|---|---|---|---|
| `POST /api/v1/uploads/presign` | Consumido | subida de logo del negocio, imagen de producto y QR de método de pago (siempre seguido de un `PUT` directo a R2) | [CÓDIGO: pos-heladeria/src/app/core/tenant/tenant-info.service.ts:137-175] [CÓDIGO: pos-heladeria/src/app/modules/products/services/product.service.ts:648-663] [CÓDIGO: pos-heladeria/src/app/modules/sales/services/payment-method.service.ts:120-148] |

## Hallazgos

#### H-01: El frontend llama a `POST`/`PATCH /api/v1/super-admin/users`, endpoints que no existen en el backend

- **Categoría**: contrato distinto
- **Severidad**: Alta — las acciones "Crear usuario", "Editar" y "Activar/Desactivar" de la pantalla `/super-admin/users` son inoperables en producción: cualquier intento termina en un `404 Not Found` de FastAPI (ninguna ruta coincide), no en un error de negocio.
- **Backend**: el router raíz de `super_admin` solo define cuatro rutas propias: `GET /super-admin/users` (listar), `GET /super-admin/tenants`, `PATCH /super-admin/tenants/{id}` y `POST /super-admin/tenants`; no existe ningún `@router.post("/users")` ni `@router.patch("/users/{id}")` en todo el archivo [CÓDIGO: pos-backend/app/api/v1/super_admin/router.py:38-173] (verificado línea por línea: los únicos decoradores `@router.*` del archivo son las 4 rutas citadas).
- **Frontend**: `SuperAdminUsersService.createUser()` hace `POST {apiBaseUrl}/super-admin/users`, y tanto `updateUser()` como `toggleActive()` hacen `PATCH {apiBaseUrl}/super-admin/users/{id}` [CÓDIGO: pos-heladeria/src/app/modules/super-admin/services/super-admin-users.service.ts:37-97]; la UI expone botones "Crear usuario", "Editar" y "Activar/Desactivar" en `SuperAdminUsersPageComponent`/`AdminUserFormComponent` que invocan esos tres métodos sin que nada en el código detecte la ausencia de la ruta [CÓDIGO: pos-heladeria/src/app/modules/super-admin/pages/super-admin-users-page.component.ts:164-183,255-263].
- **Discrepancia**: el backend de `super_admin` nunca tuvo (ni tiene hoy) una vía para crear o editar usuarios de cualquier tenant desde la plataforma — la única creación de usuarios documentada en todo G1 es `POST /api/v1/invitations`, que es un flujo distinto, acotado a un solo tenant y ejecutado por un `ADMIN` de ese tenant, no por el Super Admin. El frontend construyó una pantalla completa (formulario de alta/edición + botón de activación) contra un contrato que el backend nunca expuso.
- **Entidades afectadas**: Endpoint(s): `POST /api/v1/super-admin/users`, `PATCH /api/v1/super-admin/users/{id}` (inexistentes); Pantalla(s): `/super-admin/users` (botones "Crear usuario", "Editar", "Activar"/"Desactivar").
- **Riesgo si no se corrige**: el Super Admin no tiene, en la práctica, ninguna forma funcional de administrar usuarios individuales de un tenant desde la plataforma, pese a que la UI aparenta ofrecerla; cualquier clic en esos tres botones produce un error de red sin mensaje de negocio útil para quien lo opera.

#### H-02: `GET /api/v1/users/{id}` no tiene ningún consumidor en el frontend

- **Categoría**: endpoint no consumido
- **Severidad**: Baja — ambos lados documentan explícitamente la falta de uso; no hay comportamiento sorpresivo, solo código muerto en el lado del servicio frontend.
- **Backend**: expone `GET /api/v1/users/{user_id}`, acotado al tenant del admin autenticado, devolviendo `404` si el usuario no existe en ese tenant [CÓDIGO: pos-backend/app/api/v1/users/router.py:57-71].
- **Frontend**: `UsersService.getUser()` encapsula la llamada, pero el propio código del servicio deja constancia explícita de que ninguna pantalla lo invoca [CÓDIGO: pos-heladeria/src/app/modules/users/services/users.service.ts:91-99].
- **Discrepancia**: existe un método de servicio completo, probado presumiblemente en aislamiento, sin ningún punto de entrada en la UI que lo dispare.
- **Entidades afectadas**: Endpoint: `GET /api/v1/users/{user_id}`; Pantalla(s): ninguna.
- **Riesgo si no se corrige**: ninguno funcional inmediato; es deuda técnica (código muerto) que aumenta la superficie de mantenimiento sin aportar valor.

#### H-03: `categories`, `unit_measures` y `presentations` no exigen rol `ADMIN` en el backend (en ninguno de sus endpoints), pese a que el frontend solo permite llegar a esas pantallas como `ADMIN`

- **Categoría**: rol inconsistente
- **Severidad**: Media — requiere ya tener credenciales válidas de un rol inferior (Cajero/Mesero) del mismo tenant; el riesgo es manipular catálogo/unidades de medida/presentaciones, no fuga de datos sensibles ni fraude de pagos.
- **Backend**: ninguna de las 5 rutas de `categories` (`GET`×2/`POST`/`PATCH`/`DELETE`) usa `require_tenant_admin` — solo `get_current_user` [CÓDIGO: pos-backend/app/api/v1/categories/router.py:58-60,85,103-107,139-144,179-184]. Lo mismo ocurre en las 5 rutas de `unit_measures`: el único gating es `require_module_access("inventario")` a nivel de router, sin chequeo de rol [CÓDIGO: pos-backend/app/api/v1/unit_measures/router.py:15-18,36,58,76-80,106-111,140-145]. Y en las 4 rutas de `presentations` (`GET`×2/`POST`/`PATCH`): la única dependencia es `get_current_user`, nunca `require_tenant_admin` [CÓDIGO: pos-backend/app/api/v1/presentations/router.py:40-42,66,84-88,111-116].
- **Frontend**: `/dashboard/categories` exige `roleGuard([UserRole.ADMIN])` [CÓDIGO: pos-heladeria/src/app/modules/dashboard/routes.ts:104-111]; `/dashboard/ajustes/unidades` hereda `roleGuard([UserRole.ADMIN])` de su padre `ajustes` [CÓDIGO: pos-heladeria/src/app/modules/dashboard/routes.ts:54-58]; `/dashboard/presentations` exige `roleGuard([UserRole.ADMIN])` propio [CÓDIGO: pos-heladeria/src/app/modules/dashboard/routes.ts:112-121]. Ningún Cajero o Mesero puede alcanzar ninguna de las tres pantallas desde la UI oficial.
- **Discrepancia**: el frontend trata las tres pantallas como exclusivas de Admin; el backend las trata como accesibles a cualquier rol autenticado del tenant, tanto para leer como para escribir. La restricción es puramente de navegación, no de autorización de API.
- **Entidades afectadas**: Endpoint(s): `GET`/`POST`/`PATCH`/`DELETE /api/v1/categories[/{id}]`, `GET`/`POST`/`PATCH`/`DELETE /api/v1/unit-measures[/{id}]`, `GET`/`POST`/`PATCH /api/v1/presentations[/{id}]`; Pantalla(s): `/dashboard/categories`, `/dashboard/ajustes/unidades`, `/dashboard/presentations`.
- **Riesgo si no se corrige**: un Cajero o Mesero con su propio JWT válido puede, llamando directamente a la API (sin pasar por la UI), leer, crear, editar o desactivar categorías, unidades de medida o presentaciones — una acción que el negocio diseñó como exclusiva del Admin del tenant.

#### H-04: varias rutas de escritura de `catalog`/`categories`/`products`/`unit_measures` nunca se invocan porque el frontend usa una vía alterna

- **Categoría**: endpoint no consumido
- **Severidad**: Baja — cada caso tiene un camino alterno real que cubre la misma necesidad funcional; no hay pérdida de capacidad para el usuario final, solo superficie de API sin cliente oficial.
- **Backend**: expone rutas `DELETE` dedicadas de soft-delete en `variants`, `option-groups`, `options`, `categories`, `products` y `unit-measures` [CÓDIGO: pos-backend/app/api/v1/catalog/router.py:172-182,356-365,484-492] [CÓDIGO: pos-backend/app/api/v1/categories/router.py:179-184] [CÓDIGO: pos-backend/app/api/v1/products/router.py:179-183] [CÓDIGO: pos-backend/app/api/v1/unit_measures/router.py:140-145]; además `PUT /products/{id}` como alias explícito de `PATCH /products/{id}` [CÓDIGO: pos-backend/app/api/v1/products/router.py:147-166] y `POST /products/{id}/variants` para alta de una variante suelta [CÓDIGO: pos-backend/app/api/v1/catalog/router.py:87-99].
- **Frontend**: el patrón "activar/desactivar" de las seis pantallas de catálogo llama siempre a `PATCH {id}` con `{active: false}`, nunca al verbo `DELETE` [CÓDIGO: pos-heladeria/src/app/modules/categories/services/category.service.ts:130-165] [CÓDIGO: pos-heladeria/src/app/modules/products/services/product.service.ts:312-319] [CÓDIGO: pos-heladeria/src/app/core/services/unit-measure.service.ts:57-90] [CÓDIGO: pos-heladeria/src/app/modules/option-groups/services/option-group.service.ts:86-135]; el guardado de un producto es siempre el árbol consolidado vía `POST`/`PATCH /products` (nunca `PUT`, nunca `POST .../variants` suelto) [CÓDIGO: pos-heladeria/src/app/modules/products/services/product.service.ts:538-575]; `ProductService.createVariant()`/`deleteVariant()` existen como métodos de servicio pero ningún componente los invoca [INFERIDO: ninguna ocurrencia de `.createVariant(`/`.deleteVariant(` fuera de su propia declaración en todo `pos-heladeria/src/app`].
- **Discrepancia**: el backend ofrece dos formas válidas de lograr lo mismo (verbo `DELETE`/`PUT` dedicado vs. `PATCH` parcial o guardado consolidado); el frontend oficial estandarizó en una sola y dejó la otra sin ningún cliente.
- **Entidades afectadas**: Endpoint(s): `DELETE /api/v1/variants/{id}`, `DELETE /api/v1/option-groups/{id}`, `DELETE /api/v1/options/{id}`, `DELETE /api/v1/categories/{id}`, `DELETE /api/v1/products/{id}`, `DELETE /api/v1/unit-measures/{id}`, `PUT /api/v1/products/{id}`, `POST /api/v1/products/{id}/variants`; Pantalla(s): ninguna las invoca.
- **Riesgo si no se corrige**: ninguno funcional inmediato; es superficie de API y código de servicio (`createVariant`/`deleteVariant`) que aumenta el costo de mantenimiento sin un consumidor real que lo ejerza en cada despliegue.

#### H-05: nueve endpoints de solo lectura (G2+G3+G4+G5) no tienen ningún consumidor ni alterno conocido

- **Categoría**: endpoint no consumido
- **Severidad**: Baja — son lecturas sin efecto secundario; no hay riesgo de integridad, solo código sin uso (salvo `GET /audit-logs`, que además implica que no existe ninguna pantalla de auditoría en el frontend — ver nota).
- **Backend**: `GET /api/v1/categories/{id}`, `GET /api/v1/unit-measures/{id}`, `GET /api/v1/presentations/{id}`, `GET /api/v1/inventory/items/{id}`, `GET /api/v1/table-sessions/{id}`, `GET /api/v1/menu/promotions`, `GET /api/v1/invoices/{id}`, `GET /api/v1/reports/products` y `GET /api/v1/audit-logs` existen como rutas completas con su propio esquema de respuesta [CÓDIGO: pos-backend/app/api/v1/categories/router.py:73-87] [CÓDIGO: pos-backend/app/api/v1/unit_measures/router.py:46-60] [CÓDIGO: pos-backend/app/api/v1/presentations/router.py:54-68] [CÓDIGO: pos-backend/app/api/v1/inventory/router.py:86-88] [CÓDIGO: pos-backend/app/api/v1/table_sessions/router.py:36-39] [CÓDIGO: pos-backend/app/api/v1/menu/router.py:279-282] [CÓDIGO: pos-backend/app/api/v1/invoices/router.py:15-17] [CÓDIGO: pos-backend/app/api/v1/reports/router.py:36-41] [CÓDIGO: pos-backend/app/api/v1/audit/router.py:32-35].
- **Frontend**: ninguno de los servicios correspondientes (`CategoryService`, `UnitMeasureService`, `PresentationService`, `InventoryService`, `TableSessionService`) define un punto de entrada de UI que llame a su respectivo endpoint por id individual — `TableSessionService.get()` existe como método pero ningún componente lo invoca [INFERIDO: los servicios solo contienen llamadas a la raíz paginada/completa de su recurso, o a `list()`, desde las pantallas reales]; ninguna cadena `menu/promotions`, `invoices/${`, `/reports/products` (sin `top-`) ni `audit-logs`/`audit_logs` aparece en todo `pos-heladeria/src/app` [INFERIDO: búsqueda literal sin resultados en los cuatro casos].
- **Discrepancia**: a diferencia de H-04, aquí no hay un camino alterno visible que explique la ausencia — las pantallas de catálogo/inventario y la Terminal de mesas ya tienen toda la fila en memoria tras su listado, `menu/promotions` parece pensado para un consumidor externo que `pos-heladeria` no implementa, `reports/products` quedó reemplazado en la práctica por `reports/top-products`, y **no existe ninguna pantalla de auditoría en todo el frontend**: un Admin no tiene forma de ver `audit_logs` desde la UI oficial, pese a que el backend los registra para `products`, `promotions` y `orders` (cancelaciones con pérdida).
- **Entidades afectadas**: Endpoint(s): `GET /api/v1/categories/{id}`, `GET /api/v1/unit-measures/{id}`, `GET /api/v1/presentations/{id}`, `GET /api/v1/inventory/items/{id}`, `GET /api/v1/table-sessions/{id}`, `GET /api/v1/menu/promotions`, `GET /api/v1/invoices/{id}`, `GET /api/v1/reports/products`, `GET /api/v1/audit-logs`; Pantalla(s): ninguna.
- **Riesgo si no se corrige**: ninguno funcional para los primeros ocho; para `GET /audit-logs`, el riesgo es de producto — la trazabilidad que el backend ya registra (quién canceló qué, quién cambió una promoción) no es visible para nadie en la operación real del negocio.

#### H-06: las lecturas de `inventory` (insumos, proveedores, compras) no exigen rol `ADMIN`, pese a que todas sus mutaciones sí lo hacen y la UI reserva el módulo completo a Admin

- **Categoría**: rol inconsistente
- **Severidad**: Media — expone datos sensibles para el negocio (costo unitario de insumos, datos de contacto de proveedores, historial de compras) a cualquier Cajero/Mesero con el módulo "inventario" habilitado en el plan, aunque no pueda modificarlos.
- **Backend**: `GET /inventory/items`, `GET /inventory/items/low-stock`, `GET /inventory/items/{id}`, `GET /inventory/items/{id}/movements`, `GET /inventory/suppliers` y `GET /inventory/purchases` solo exigen `get_current_user` (más el módulo de plan) [CÓDIGO: pos-backend/app/api/v1/inventory/router.py:37-54,57-67,86-88,155-168,172-174,206-213]; en cambio, **todas** las mutaciones del mismo router (`POST`/`PATCH /items`, `/adjust`, `/export`, `POST`/`PATCH /suppliers`, `POST /purchases[/order]`, `POST /purchases/{id}/receive`) sí exigen `require_tenant_admin` [CÓDIGO: pos-backend/app/api/v1/inventory/router.py:73,95,118,145,178,191,224,237,251] — el gating por rol existe en el módulo, pero deliberadamente no cubre ninguna lectura.
- **Frontend**: `/dashboard/inventario` exige `roleGuard([UserRole.ADMIN])` [CÓDIGO: pos-heladeria/src/app/modules/dashboard/routes.ts:215-222]; `/dashboard/proveedores` exige `roleGuard([UserRole.ADMIN])` [CÓDIGO: pos-heladeria/src/app/modules/dashboard/routes.ts:228-235]. Ningún Cajero o Mesero puede ver estas pantallas desde la UI oficial.
- **Discrepancia**: el backend de `inventory` sí distingue lectura de escritura (algo que `categories`/`unit_measures`/`presentations` ni intentan — ver H-03), pero solo protegió la escritura; las 6 rutas de lectura quedaron fuera del mismo criterio, mientras el frontend trata el módulo completo (lectura y escritura) como exclusivo de Admin.
- **Entidades afectadas**: Endpoint(s): `GET /api/v1/inventory/items[/{id}|/low-stock|/{id}/movements]`, `GET /api/v1/inventory/suppliers`, `GET /api/v1/inventory/purchases`; Pantalla(s): `/dashboard/inventario`, `/dashboard/proveedores`.
- **Riesgo si no se corrige**: un Cajero o Mesero con su propio JWT válido puede leer, vía API directa, el costo unitario de cada insumo, el stock exacto, los datos de contacto de los proveedores y el historial completo de compras — información que la UI oficial nunca les muestra.

#### H-07: toda la gestión avanzada de mesas (mover, fusionar, cuenta de grupo, consolidar, dividir cuenta entre comensales) existe en el backend — deliberadamente habilitada para el rol Mesero — pero no tiene ningún punto de entrada en la UI

- **Categoría**: endpoint no consumido
- **Severidad**: Media — no rompe nada hoy (nadie lo invoca), pero es una funcionalidad completa (RF-052/RF-053, spec 075) con lógica transaccional no trivial (locks, `merged_group_id`, reparto de cantidades) que el negocio pagó construir y el personal no puede usar desde la Terminal oficial.
- **Backend**: `POST /orders/{id}/move`, `POST /orders/merge`, `GET /orders/group/{id}/bill`, `POST /orders/tables/{id}/consolidate`, `GET /orders/tables/{id}/bill`, `POST /orders/tables/{id}/release`, `POST`/`DELETE /table-sessions/{id}/participants[/{pid}]` y `PUT /table-sessions/{id}/assignments` están todos en `_MESERO_ALLOWED_ROUTES`, la lista autoritativa de rutas que spec 075 habilitó explícitamente para la Terminal de Mesas operada por un Mesero [CÓDIGO: pos-backend/app/core/dependencies.py:139-191].
- **Frontend**: ninguno de esos ocho endpoints tiene un punto de entrada real: `TableService.moveOrder()`/`.mergeOrders()`/`.groupBill()` existen como métodos de servicio sin ningún llamador [CÓDIGO: pos-heladeria/src/app/modules/tables/services/table.service.ts:165-184]; ninguna cadena `consolidate`, `tables/${...}/bill`, `participants` o `assignments` aparece en todo `pos-heladeria/src/app` [INFERIDO: búsqueda literal sin resultados]; "Liberar Mesa" usa la ruta de `table_sessions`, no la de `orders/tables/{id}/release` (ver tabla de `orders` — Mesas).
- **Discrepancia**: el backend fue diseñado y habilitado por rol específicamente para que la Terminal ofreciera mover una orden entre mesas, fusionar mesas, ver la cuenta consolidada de un grupo, consolidar los carritos de una mesa en una sola comanda, y repartir ítems entre comensales para dividir la cuenta — ninguna de esas capacidades tiene hoy un botón, modal o flujo en `pos-heladeria`.
- **Entidades afectadas**: Endpoint(s): `POST /api/v1/orders/{id}/move`, `POST /api/v1/orders/merge`, `GET /api/v1/orders/group/{id}/bill`, `POST /api/v1/orders/tables/{id}/consolidate`, `GET /api/v1/orders/tables/{id}/bill`, `POST /api/v1/orders/tables/{id}/release`, `POST`/`DELETE /api/v1/table-sessions/{id}/participants[/{pid}]`, `PUT /api/v1/table-sessions/{id}/assignments`; Pantalla(s): ninguna.
- **Riesgo si no se corrige**: ninguno de integridad inmediato (el código no se ejecuta); el riesgo es de producto — una inversión de desarrollo backend sin retorno visible para el usuario final, y una ambigüedad para quien lea solo la API y asuma que la UI la expone.

#### H-08: el ciclo antiguo `block`→`pay` y la confirmación directa de una orden quedaron reemplazados por `checkout-and-send`/`close` y por `approve`/`confirm-cash`, pero las rutas antiguas siguen activas en el backend

- **Categoría**: endpoint no consumido
- **Severidad**: Baja — a diferencia de H-07, aquí el propio código documenta la sustitución; no hay funcionalidad perdida, solo rutas legacy que nadie retiró.
- **Backend**: `POST /orders/{id}/block`, `POST /orders/{id}/pay` y `POST /orders/{id}/confirm` siguen activos y en el allowlist de Mesero [CÓDIGO: pos-backend/app/api/v1/orders/router.py:469-480] [CÓDIGO: pos-backend/app/core/dependencies.py:173-175,160].
- **Frontend**: el comentario de `TableSessionService` es explícito: "Sustituye al ciclo `block` → `pay` por orden: cerrar la sesión cobra todos sus pedidos de una vez" [CÓDIGO: pos-heladeria/src/app/modules/tables/services/table-session.service.ts:19-24]; `DiningSessionService.confirmOrder()` solo se invoca desde su propio test unitario [INFERIDO: única ocurrencia de `.confirmOrder(` fuera de su declaración está en `dining-session.service.spec.ts:70`] — la confirmación real de una orden QR ocurre como efecto colateral de `approve_payment_attempt`/`confirm_cash_payment_attempt` (ver `inventario-backend.md` § `orders` — Intentos de pago).
- **Discrepancia**: el frontend migró deliberadamente a un flujo distinto (`checkout-and-send`/`close` de sesión completa; confirmación implícita al aprobar el pago) y dejó de llamar las tres rutas originales, que el backend nunca retiró.
- **Entidades afectadas**: Endpoint(s): `POST /api/v1/orders/{id}/block`, `POST /api/v1/orders/{id}/pay`, `POST /api/v1/orders/{id}/confirm`; Pantalla(s): ninguna.
- **Riesgo si no se corrige**: ninguno funcional; candidatas a retirar del backend si se confirma que ningún otro cliente (API externa) las usa.

#### H-09: un Mesero no puede agregar un ítem directo a un pedido porque la ruta registrada en su allowlist no coincide con la ruta real del endpoint

- **Categoría**: rol inconsistente
- **Severidad**: Alta — bloquea una acción central y visible de la Terminal de Mesas ("＋ Agregar producto") para un rol completo, con un `403` que no da ninguna pista útil del motivo real.
- **Backend**: `_MESERO_ALLOWED_ROUTES` declara permitida la tupla `("POST", "/orders/tables/{table_id}/items")`, pero el único endpoint real que agrega un ítem a una orden existente está registrado como `POST /{order_id}/items` bajo el prefijo `/orders` — su ruta real es `/orders/{order_id}/items`, no `/orders/tables/{table_id}/items` [CÓDIGO: pos-backend/app/core/dependencies.py:166] [CÓDIGO: pos-backend/app/api/v1/orders/router.py:214-227]. `_enforce_mesero_scope` compara `(method, path)` exactos contra esa lista [CÓDIGO: pos-backend/app/core/dependencies.py:196-220], así que la entrada nunca hace match y cualquier Mesero recibe `403 "Fuera del alcance del rol Mesero"` en este endpoint, aunque el propio comentario del código lo describe como pensado para él. **Origen del error**: no es una transcripción incorrecta cometida solo al escribir `dependencies.py` — la propia tabla de contrato de la spec 075 ya nombraba esa misma ruta incorrecta ("Agregar ítem al pedido de una mesa") [CÓDIGO: pos-specs/specs/075-rol-mesero/contracts/backend-endpoint-access.md:47]; el backend implementó el allowlist exactamente como la spec lo especificó, pero ni la spec ni la implementación lo reconciliaron contra la ruta real que ya existía en `orders/router.py`. Esto no contradice la intención de la spec 075 (que sí quería que el Mesero pudiera agregar ítems) — documenta que su propio contrato quedó con una ruta que nunca fue la implementada.
- **Frontend**: la Terminal de Mesas, accesible a `[ADMIN, CASHIER, MESERO]` [CÓDIGO: pos-heladeria/src/app/modules/dashboard/routes.ts:176-179], muestra el botón "＋ Agregar producto" del Panel de pedido sin distinguir por rol, y lo conecta a `POST /orders/{id}/items` vía `DiningSessionService` [CÓDIGO: pos-heladeria/src/app/modules/tables/components/pos-order-panel.component.ts:96-136] [CÓDIGO: pos-heladeria/src/app/modules/tables/services/dining-session.service.ts:224-228] — no hay ningún chequeo de rol en el cliente que oculte el botón para Mesero.
- **Discrepancia**: el frontend asume (correctamente, según la intención del backend) que un Mesero puede agregar productos a un pedido abierto; el backend, por un error de transcripción de ruta en su propio allowlist, lo bloquea en la práctica.
- **Entidades afectadas**: Endpoint: `POST /api/v1/orders/{id}/items`; Pantalla(s): `/dashboard/mesas-sesiones` (Panel de pedido, botón "＋ Agregar producto"), y por extensión `/dashboard/mesas-sesiones/:tableId/orden-manual` si un Mesero reabre un pedido ya creado para agregar líneas.
- **Riesgo si no se corrige**: cualquier Mesero que intente agregar un producto a un pedido ya existente en la Terminal recibe un error genérico sin poder completar una tarea cotidiana del rol — afecta la operación real del negocio, no solo un caso de borde.

#### H-10: `POST /api/v1/sales` (checkout de mostrador independiente de un pedido) no tiene ningún consumidor en el frontend

- **Categoría**: endpoint no consumido
- **Severidad**: Baja — existe una vía alterna real y ya en uso (`checkout-and-send`/`close` de sesión, ambas sobre `orders`/`table_sessions`) que cubre el cobro de mostrador y de mesa; no hay pérdida de capacidad para el usuario final.
- **Backend**: `POST /sales` construye y cobra una venta directamente a partir de ítems sueltos (`SaleItemIn`), sin pasar por una `CustomerOrder` previa — es, por diseño, un segundo camino de cobro independiente del flujo de pedidos [CÓDIGO: pos-backend/app/api/v1/sales/router.py:119-127] [CÓDIGO: pos-backend/app/api/v1/sales/builder.py:1-16].
- **Frontend**: `SalesService.checkout()` existe y envuelve la llamada, pero `SalesPageComponent` nunca lo invoca, y no se encontró ningún otro llamador fuera de las pruebas unitarias del propio servicio [CÓDIGO: pos-heladeria/src/app/modules/sales/services/sales.service.ts:113-127] [INFERIDO: búsqueda de `.checkout(` sobre `src/app` fuera de archivos `*.spec.ts` sin resultados]; todo cobro real observado en la UI pasa por `POST /orders/{id}/checkout-and-send` o `POST /table-sessions/{id}/close` (ver `orders` — Cobro y cierre, y `table_sessions`).
- **Discrepancia**: el backend mantiene un segundo camino de venta directa (mostrador sin pedido) que el frontend decidió no usar — probablemente porque todo flujo real de venta pasa primero por un pedido (QR, mesero o mostrador con `hold_for_payment`), haciendo innecesario cobrar "en frío" sin ese paso previo.
- **Entidades afectadas**: Endpoint: `POST /api/v1/sales`; Pantalla(s): ninguna.
- **Riesgo si no se corrige**: ninguno funcional inmediato; es superficie de API (constructor `build_sale` completo) sin ningún cliente oficial que la ejerza en cada despliegue.

#### H-11: `PATCH /api/v1/categories/{id}` responde `404` por `presentation_id` inválido, pero su propio OpenAPI (`responses=`) solo documenta ese `404` como "la categoría no existe"

- **Categoría**: otro (inconsistencia entre la documentación OpenAPI del propio backend y su comportamiento real — detectada al redactar los atributos IEEE 830 de este requisito, no es un hallazgo de cruce front↔back en sentido estricto, pero se registra aquí por la regla de `plantilla-requisito.md`)
- **Severidad**: Baja — no afecta el comportamiento real (el código sí responde con el código HTTP correcto), solo la calidad de la documentación OpenAPI/Swagger que describe ese endpoint.
- **Backend**: el decorador `@router.patch("/{id}", ...)` de `categories` declara `responses={404: {"description": "La categoría no existe."}, 422: {"description": "Datos de entrada inválidos."}, ...}` [CÓDIGO: pos-backend/app/api/v1/categories/router.py:125-137]; pero `_replace_category_presentations`, invocada por este mismo handler cuando `presentation_ids` incluye un id que no existe en `presentations`, lanza explícitamente `HTTPException(404, detail="Presentation {id} not found")` [CÓDIGO: pos-backend/app/api/v1/categories/router.py:28-33] — un segundo motivo de `404` que la descripción documentada no menciona (la describe solo como "la categoría no existe").
- **Frontend**: no aplica — es una inconsistencia interna de la documentación OpenAPI del backend, no una discrepancia con `pos-heladeria`.
- **Discrepancia**: quien integre contra la API leyendo solo el esquema OpenAPI generado (p. ej. Swagger UI) concluiría que un `404` en este endpoint solo puede significar "la categoría no existe", cuando en realidad también puede significar "una de las presentaciones que querías asociar no existe" — un caso que, además, se parece más a un error de validación (422) que a un recurso no encontrado al nivel de la URL.
- **Entidades afectadas**: Endpoint: `PATCH /api/v1/categories/{id}`; Pantalla(s): `/dashboard/categories` (no observa el problema porque siempre envía ids de presentación ya existentes, tomados de un selector poblado por `GET /presentations`).
- **Riesgo si no se corrige**: bajo para `pos-heladeria` (nunca envía un id inválido); relevante solo para un futuro cliente API distinto que integre contra este endpoint confiando literalmente en la documentación OpenAPI.

## ⏸ Punto de parada — pendiente de confirmación

Cruce completo: **175 endpoints** de `pos-backend` marcados en la tabla de correspondencia (G1-G6), **100% cubiertos** — cada uno quedó como Consumido, Consumido (parcial) o **No consumido**, nunca sin marcar. 10 hallazgos (`H-01`–`H-10`) resumidos por categoría:

| Categoría | Hallazgos | Severidad más alta |
|---|---|---|
| Contrato distinto | H-01 | **Alta** |
| Rol inconsistente | H-03, H-06, H-09 | **Alta** (H-09) |
| Endpoint no consumido | H-02, H-04, H-05, H-07, H-08, H-10 | Media (H-07) |
| Otro | H-11 | Baja |

**Los tres hallazgos más importantes**:
- **H-01 (Alta)**: `/super-admin/users` — el Super Admin no puede crear, editar ni activar/desactivar usuarios desde la UI; el frontend llama a `POST`/`PATCH` que no existen en el backend (404 garantizado).
- **H-09 (Alta)**: un **Mesero no puede agregar un producto a un pedido ya creado** en la Terminal — bug de transcripción de ruta en el allowlist de rol del backend (`_MESERO_ALLOWED_ROUTES`), que bloquea con 403 una acción que el propio backend documenta como destinada a ese rol.
- **H-07 (Media)**: toda la gestión avanzada de mesas (mover orden, fusionar mesas, cuenta de grupo, consolidar, dividir cuenta entre comensales) — 8 endpoints, deliberadamente habilitados para Mesero en spec 075 — no tiene ningún punto de entrada en la UI. O es trabajo pendiente, o es alcance abandonado; no se puede saber solo leyendo el código.

**Otros ocho** (H-02, H-03, H-04, H-05, H-06, H-08, H-10, H-11) son de severidad Baja/Media: código muerto en ambos lados (métodos de servicio sin llamador, endpoints `GET`/`DELETE`/`PUT` sin cliente), rutas reemplazadas deliberadamente sin retirar (`block`/`pay`/`confirm`), dos brechas de rol adicionales — `categories`/`unit_measures`/`presentations` sin ningún chequeo de rol (H-03) y las lecturas de `inventory` sin rol pese a que sus escrituras sí lo exigen (H-06) — que exponen catálogo y costos a Cajero/Mesero vía API directa aunque la UI los oculte, y una inconsistencia menor entre el OpenAPI del propio backend y su comportamiento real en `PATCH /categories/{id}` (H-11, detectada ya durante la redacción del SRS, no durante este cruce).

**Correcciones aplicadas durante este cruce** (no son hallazgos de discrepancia real, sino errores de documentación de la Fase 4 corregidos sobre la marcha, con evidencia nueva verificada contra el código): `AuthService.tryRefresh()`/`logout()` usan `GET`, no `POST`, como ya documentaba el backend; `GET /menu` tenía tres consumidores reales (Terminal, detalle de orden, promociones) sin ninguna cita explícita del endpoint; `GET /table-sessions` y `GET /table-sessions/{id}/bill` faltaban en la descripción del panel de cobro de la Terminal.

**Resumen de la cobertura por grupo backend** (175 endpoints totales: 143 consumidos —141 completos + 2 parciales—, 32 no consumidos, de los cuales 31 son hallazgo y 1 es `/health`, deliberadamente fuera del contrato de la app):
- G1 (Identidad y acceso): 28 endpoints — 1 hallazgo crítico (H-01, 2 endpoints inexistentes citados), 1 menor (H-02).
- G2 (Catálogo): 33 endpoints — 3 patrones (H-03 rol, H-04 verbos alternos ×8, H-05 lecturas sin uso ×3).
- G3 (Presentaciones/promociones/inventario): 26 endpoints — `promotions` 100% consumido; `presentations`/`inventory` con brechas de rol (H-03/H-06) y 2 lecturas sin uso (H-05).
- G4 (Pedidos y mesas): 51 endpoints — el grupo con más hallazgos: 9 endpoints sin UI de gestión avanzada (H-07), 3 rutas legacy (H-08), 1 bug de rol de severidad Alta (H-09), 1 lectura sin uso (H-05); `cart` y `table_sessions` (salvo el `GET` individual) 100% consumidos.
- G5 (Caja/ventas/facturación): 28 endpoints — `cash`/`reports` (salvo `products`) y `plan` 100% consumidos; `POST /sales`, `GET /invoices/{id}`, `GET /reports/products` y `GET /audit-logs` sin uso (H-05, H-10).
- G6 (Infraestructura): 9 endpoints — 100% consumido salvo `/health` (deliberadamente fuera del contrato de la app, sin discrepancia).

Antes de continuar a la Fase 6 (redacción del SRS completo en `srs/`), se necesita confirmación textual explícita del usuario sobre este resultado — en particular, si los hallazgos de severidad Alta (H-01, H-09) y Media (H-03, H-06, H-07) deben documentarse en el SRS únicamente como hallazgos del Apéndice D (tal como exige FR-016, nunca como requisitos), o si el usuario quiere primero accionarlos fuera de este flujo de documentación antes de seguir.

**✅ Confirmación del usuario (2026-10-09)**: "si, continua" — confirmación textual explícita recibida para avanzar a la Fase 6 con los 10 hallazgos documentados únicamente en el Apéndice D (FR-016), sin accionarlos fuera de este flujo. Punto de parada resuelto; T032 queda habilitado.
