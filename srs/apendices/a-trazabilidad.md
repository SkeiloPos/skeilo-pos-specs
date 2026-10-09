# Apéndice A — Matriz de trazabilidad

**SRS**: [../README.md](../README.md)

Todo RF/RNF del cuerpo del SRS, con su endpoint, pantalla y entidad de datos. El estado de consumo reproduce exactamente el de la tabla de correspondencia en [cruce-front-back.md](../../specs/104-documentacion-funciones-publica/cruce-front-back.md): **Consumido** / **Consumido (parcial)** / **No consumido**. 175 de 175 endpoints del backend están cubiertos por al menos un RF de esta tabla (ver [Apéndice E](./e-cobertura.md) para el cálculo).

## Grupo G1 — Identidad y acceso

| RF | Endpoint(s) | Estado | Pantalla(s) | Entidad(es) |
|---|---|---|---|---|
| RF-auth-001 | `POST /auth/login` | Consumido | `/login` | `User`, `UserInvitation` |
| RF-auth-002 | `POST /auth/forgot-password` | Consumido | `/forgot-password` | `PasswordResetToken` |
| RF-auth-003 | `GET /auth/reset-password/validate` | Consumido | `/reset-password` | `PasswordResetToken` |
| RF-auth-004 | `POST /auth/reset-password` | Consumido | `/reset-password` | `PasswordResetToken`, `User` |
| RF-auth-005 | `POST /auth/change-password` | Consumido | `/change-password`, `/dashboard/mi-cuenta` | `User` |
| RF-auth-006 | `GET /auth/refresh-token` | Consumido | transversal (interceptor) | `User` |
| RF-auth-007 | `GET /auth/logout` | Consumido | transversal (logout) | — |
| RF-bootstrap-001 | `GET /bootstrap` | Consumido | shell de `/dashboard/*` | `Tenant`, `Plan`, `NotificationEvent` |
| RF-invitations-001 | `GET /invitations` | Consumido | `/dashboard/users` | `UserInvitation` |
| RF-invitations-002 | `POST /invitations` | Consumido | `/dashboard/users` | `UserInvitation`, `User` |
| RF-invitations-003 | `POST /invitations/{id}/resend` | Consumido | `/dashboard/users` | `UserInvitation` |
| RF-invitations-004 | `POST /invitations/{id}/cancel` | Consumido | `/dashboard/users` | `UserInvitation` |
| RF-super_admin-001 | `GET /super-admin/users` | Consumido | `/super-admin/users` | `User` |
| RF-super_admin-002 | `GET /super-admin/tenants` | Consumido | `/super-admin/tenants` | `Tenant` |
| RF-super_admin-003 | `PATCH /super-admin/tenants/{id}` | Consumido | `/super-admin/tenants` | `Tenant`, `Plan` |
| RF-super_admin-004 | `POST /super-admin/tenants` | Consumido | `/super-admin/tenants` | `Tenant`, `User`, `Plan` |
| RF-super_admin-005 | `GET /super-admin/payment-methods-catalog` | Consumido | `/super-admin/payment-methods-catalog` | `PaymentMethodCatalog` |
| RF-super_admin-006 | `POST /super-admin/payment-methods-catalog` | Consumido | `/super-admin/payment-methods-catalog` | `PaymentMethodCatalog` |
| RF-super_admin-007 | `PATCH /super-admin/payment-methods-catalog/{id}` | Consumido | `/super-admin/payment-methods-catalog` | `PaymentMethodCatalog` |
| RF-super_admin-008 | `GET /super-admin/plans` | Consumido | `/super-admin/plans` | `Plan` |
| RF-super_admin-009 | `POST /super-admin/plans` | Consumido | `/super-admin/plans` | `Plan` |
| RF-super_admin-010 | `PATCH /super-admin/plans/{id}` | Consumido | `/super-admin/plans` | `Plan` |
| — (sin RF, ver H-01) | `POST`/`PATCH /super-admin/users` | Inexistente en backend | `/super-admin/users` | — |
| RF-tenant-001 | `GET /tenant` | Consumido | `/dashboard/ajustes/*` | `Tenant` |
| RF-tenant-002 | `PATCH /tenant` | Consumido | `/dashboard/ajustes/*` | `Tenant` |
| RF-users-001 | `GET /users` | Consumido | `/dashboard/users` | `User` |
| RF-users-002 | `GET /users/{id}` | No consumido (H-02) | ninguna | `User` |
| RF-users-003 | `PATCH /users/{id}/role` | Consumido | `/dashboard/users` | `User` |
| RF-users-004 | `PATCH /users/{id}/status` | Consumido | `/dashboard/users` | `User` |

## Grupo G2 — Catálogo

| RF | Endpoint(s) | Estado | Pantalla(s) | Entidad(es) |
|---|---|---|---|---|
| RF-catalog-001 | `GET /products/{id}/variants` | Consumido | `/dashboard/products/:id` | `ProductVariant` |
| RF-catalog-002 | `POST /products/{id}/variants` | No consumido (H-04) | ninguna | `ProductVariant` |
| RF-catalog-003 | `PATCH /variants/{id}` | Consumido (parcial) | `/dashboard/products/:id` | `ProductVariant` |
| RF-catalog-004 | `DELETE /variants/{id}` | No consumido (H-04) | ninguna | `ProductVariant` |
| RF-catalog-005 | `GET /variants/{id}/recipe` | Consumido | `/dashboard/products/:id` | `RecipeItem` |
| RF-catalog-006 | `GET /variants/{id}/option-groups` | Consumido | `/dashboard/products/:id`, Terminal | `VariantOptionGroup` |
| RF-catalog-007 | `GET /option-groups` | Consumido | `/dashboard/ajustes/grupos-opciones`, formulario de producto | `OptionGroup`, `Option` |
| RF-catalog-008 | `POST /option-groups` | Consumido | `/dashboard/ajustes/grupos-opciones` | `OptionGroup` |
| RF-catalog-009 | `PATCH /option-groups/{id}` | Consumido | `/dashboard/ajustes/grupos-opciones` | `OptionGroup` |
| RF-catalog-010 | `DELETE /option-groups/{id}` | No consumido (H-04) | ninguna | `OptionGroup` |
| RF-catalog-011 | `POST /option-groups/{id}/options` | Consumido | `/dashboard/ajustes/grupos-opciones` | `Option` |
| RF-catalog-012 | `PATCH /options/{id}` | Consumido | `/dashboard/ajustes/grupos-opciones` | `Option` |
| RF-catalog-013 | `DELETE /options/{id}` | No consumido (H-04) | ninguna | `Option` |
| RF-categories-001 | `GET /categories` | Consumido | `/dashboard/categories`, selectores | `Category` |
| RF-categories-002 | `GET /categories/{id}` | No consumido (H-05) | ninguna | `Category` |
| RF-categories-003 | `POST /categories` | Consumido | `/dashboard/categories` | `Category` |
| RF-categories-004 | `PATCH /categories/{id}` | Consumido | `/dashboard/categories` | `Category`, `CategoryPresentation` |
| RF-categories-005 | `DELETE /categories/{id}` | No consumido (H-04) | ninguna | `Category` |
| RF-products-001 | `GET /products` | Consumido | `/dashboard/products` | `Product` |
| RF-products-002 | `GET /products/{id}` | Consumido | `/dashboard/products/:id/detalle` | `Product`, `ProductVariant` |
| RF-products-003 | `PATCH /products/{id}/availability` | Consumido | `/dashboard/products`, detalle | `Product`, `AuditLog` |
| RF-products-004 | `POST /products` | Consumido | `/dashboard/products/new` | `Product`, `ProductVariant`, `RecipeItem`, `VariantOptionGroup` |
| RF-products-005 | `PATCH /products/{id}`, `PUT /products/{id}` | Consumido (`PUT` sin uso, H-04) | `/dashboard/products/:id` | `Product`, `ProductVariant` |
| RF-products-006 | `PATCH /products/{id}` | Consumido | `/dashboard/products` | `Product` |
| RF-products-007 | `DELETE /products/{id}` | No consumido (H-04) | ninguna | `Product` |
| RF-unit_measures-001 | `GET /unit-measures` | Consumido | `/dashboard/ajustes/unidades`, selectores | `UnitMeasure` |
| RF-unit_measures-002 | `GET /unit-measures/{id}` | No consumido (H-05) | ninguna | `UnitMeasure` |
| RF-unit_measures-003 | `POST /unit-measures` | Consumido | `/dashboard/ajustes/unidades` | `UnitMeasure` |
| RF-unit_measures-004 | `PATCH /unit-measures/{id}` | Consumido | `/dashboard/ajustes/unidades` | `UnitMeasure` |
| RF-unit_measures-005 | `DELETE /unit-measures/{id}` | No consumido (H-04) | ninguna | `UnitMeasure` |
| RF-menu-001 | `GET /menu` | Consumido | Terminal, detalle de orden, promociones | `Product`, `ProductVariant` |
| RF-menu-002 | `GET /menu/promotions` | No consumido (H-05) | ninguna | `Promotion` |
| RF-menu-003 | `GET /menu/qr-token/{token}` | Consumido | `/menu/t/:token` | `DiningTable`, `Tenant` |

## Grupo G3 — Presentaciones, promociones e inventario

| RF | Endpoint(s) | Estado | Pantalla(s) | Entidad(es) |
|---|---|---|---|---|
| RF-presentations-001 | `GET /presentations` | Consumido | `/dashboard/presentations`, selectores | `Presentation` |
| RF-presentations-002 | `GET /presentations/{id}` | No consumido (H-05) | ninguna | `Presentation` |
| RF-presentations-003 | `POST /presentations` | Consumido | `/dashboard/presentations` | `Presentation` |
| RF-presentations-004 | `PATCH /presentations/{id}` | Consumido | `/dashboard/presentations` | `Presentation` |
| RF-promotions-001 | `GET /promotions` | Consumido | `/dashboard/promotions`, Terminal | `Promotion` |
| RF-promotions-002 | `POST /promotions` | Consumido | `/dashboard/promotions` | `Promotion`, `PromotionRule`, `PromotionVariant` |
| RF-promotions-003 | `PATCH /promotions/{id}` | Consumido | `/dashboard/promotions` | `Promotion` |
| RF-promotions-004 | `PATCH /promotions/{id}/shape` | Consumido | `/dashboard/promotions` | `PromotionRule`, `PromotionVariant` |
| RF-promotions-005 | `PATCH /promotions/{id}/status` | Consumido | `/dashboard/promotions` | `Promotion` |
| RF-promotions-006 | `POST /promotions/{id}/duplicate` | Consumido | `/dashboard/promotions` | `Promotion` |
| RF-promotions-007 | `DELETE /promotions/{id}` | Consumido | `/dashboard/promotions` | `Promotion`, `PromotionRule`, `PromotionVariant` |
| RF-inventory-001 | `GET /inventory/items` | Consumido | `/dashboard/inventario` | `InventoryItem` |
| RF-inventory-002 | `GET /inventory/items/low-stock` | Consumido | `/dashboard/inventario`, `/dashboard/reports` | `InventoryItem` |
| RF-inventory-003 | `GET /inventory/items/export` | Consumido | `/dashboard/inventario` | `InventoryItem` |
| RF-inventory-004 | `GET /inventory/items/{id}` | No consumido (H-05) | ninguna | `InventoryItem` |
| RF-inventory-005 | `POST /inventory/items` | Consumido | `/dashboard/inventario` | `InventoryItem` |
| RF-inventory-006 | `PATCH /inventory/items/{id}` | Consumido | `/dashboard/inventario` | `InventoryItem` |
| RF-inventory-007 | `POST /inventory/items/{id}/adjust` | Consumido | `/dashboard/inventario` | `InventoryItem`, `InventoryMovement` |
| RF-inventory-008 | `GET /inventory/items/{id}/movements` | Consumido | `/dashboard/inventario` | `InventoryMovement` |
| RF-inventory-009 | `GET /inventory/suppliers` | Consumido | `/dashboard/proveedores` | `Supplier` |
| RF-inventory-010 | `POST /inventory/suppliers` | Consumido | `/dashboard/proveedores` | `Supplier` |
| RF-inventory-011 | `PATCH /inventory/suppliers/{id}` | Consumido | `/dashboard/proveedores` | `Supplier` |
| RF-inventory-012 | `GET /inventory/purchases` | Consumido | `/dashboard/inventario` | `Purchase`, `PurchaseItem` |
| RF-inventory-013 | `POST /inventory/purchases` | Consumido | `/dashboard/inventario` | `Purchase`, `PurchaseItem`, `InventoryMovement` |
| RF-inventory-014 | `POST /inventory/purchases/order` | Consumido | `/dashboard/inventario` | `Purchase`, `PurchaseItem` |
| RF-inventory-015 | `POST /inventory/purchases/{id}/receive` | Consumido | `/dashboard/inventario` | `Purchase`, `PurchaseItem`, `InventoryMovement` |

## Grupo G4 — Pedidos y mesas

| RF | Endpoint(s) | Estado | Pantalla(s) | Entidad(es) |
|---|---|---|---|---|
| RF-orders-001 | `GET /orders/tables` | Consumido | `/dashboard/mesas`, `/dashboard/mesas/qr`, Terminal, `/dashboard/orders` | `DiningTable` |
| RF-orders-002 | `POST /orders/tables` | Consumido | `/dashboard/mesas` | `DiningTable` |
| RF-orders-003 | `PATCH /orders/tables/{id}` | Consumido | `/dashboard/mesas` | `DiningTable` |
| RF-orders-004 | `PATCH /orders/tables/{id}/status` | Consumido | `/dashboard/mesas` | `DiningTable` |
| RF-orders-005 | `POST /orders/{id}/move` | No consumido (H-07) | ninguna | `CustomerOrder`, `DiningTable` |
| RF-orders-006 | `POST /orders/merge` | No consumido (H-07) | ninguna | `CustomerOrder` |
| RF-orders-007 | `GET /orders/group/{id}/bill` | No consumido (H-07) | ninguna | `CustomerOrder` |
| RF-orders-008 | `GET /orders/tables/{id}/qr-token` | Consumido | `/dashboard/mesas`, `/dashboard/mesas/qr` | `DiningTable` |
| RF-orders-009 | `POST /orders/tables/{id}/release` | No consumido (H-07) | ninguna | `DiningTable`, `TableSession` |
| RF-orders-010 | `POST /orders` | Consumido | `/dashboard/mesas-sesiones/*/orden-manual` | `CustomerOrder`, `OrderItem` |
| RF-orders-011 | `GET /orders` | Consumido | `/dashboard/orders`, Terminal, detalle | `CustomerOrder` |
| RF-orders-012 | `GET /orders/{id}` | Consumido | `/dashboard/orders/:id` | `CustomerOrder` |
| RF-orders-013 | `POST /orders/tables/{id}/consolidate` | No consumido (H-07) | ninguna | `CustomerOrder`, `Cart` |
| RF-orders-014 | `POST /orders/{id}/items` | Consumido (parcial, H-09) | Terminal (Panel de pedido) | `OrderItem` |
| RF-orders-015 | `POST /orders/{id}/confirm` | No consumido (H-08) | ninguna | `CustomerOrder` |
| RF-orders-016 | `GET /orders/{id}/payment-attempts` | Consumido | Terminal ("Pagos por confirmar") | `OrderPaymentAttempt` |
| RF-orders-017 | `POST /orders/payment-attempts/{id}/approve` | Consumido | Terminal | `OrderPaymentAttempt`, `Sale`, `Invoice` |
| RF-orders-018 | `POST /orders/payment-attempts/{id}/reject` | Consumido | Terminal | `OrderPaymentAttempt` |
| RF-orders-019 | `POST /orders/payment-attempts/{id}/confirm-cash` | Consumido | Terminal | `OrderPaymentAttempt`, `Sale` |
| RF-orders-020 | `PATCH /orders/items/{id}/kitchen` | Consumido | Terminal (Panel de pedido) | `OrderItem` |
| RF-orders-021 | `POST /orders/{id}/ready` | Consumido | Terminal | `CustomerOrder` |
| RF-orders-022 | `POST /orders/items/{id}/void` | Consumido | Terminal (Panel de pedido) | `OrderItem`, `OrderItemVoidLog` |
| RF-orders-023 | `GET /orders/tables/{id}/bill` | No consumido (H-07) | ninguna | `CustomerOrder`, `DiningTable` |
| RF-orders-024 | `GET /orders/{id}/checkout-preview` | Consumido | Terminal (Panel de cobro) | `CustomerOrder` |
| RF-orders-025 | `POST /orders/draft-preview` | Consumido | `/dashboard/mesas-sesiones/*/orden-manual` | — |
| RF-orders-026 | `POST /orders/{id}/block` | No consumido (H-08) | ninguna | `CustomerOrder` |
| RF-orders-027 | `POST /orders/{id}/pay` | No consumido (H-08) | ninguna | `CustomerOrder`, `Sale` |
| RF-orders-028 | `POST /orders/{id}/checkout-and-send` | Consumido | Terminal ("Cobrar") | `CustomerOrder`, `Sale`, `Invoice` |
| RF-orders-029 | `POST /orders/{id}/cancel` | Consumido | Terminal, "Mis pedidos" | `CustomerOrder`, `OrderCancelLog`, `AuditLog` |
| RF-table_sessions-001 | `GET /table-sessions` | Consumido | Terminal (Panel de cobro) | `TableSession` |
| RF-table_sessions-002 | `GET /table-sessions/{id}` | No consumido (H-05) | ninguna | `TableSession`, `SessionParticipant` |
| RF-table_sessions-003 | `POST /table-sessions/{id}/participants` | No consumido (H-07) | ninguna | `SessionParticipant` |
| RF-table_sessions-004 | `DELETE /table-sessions/{id}/participants/{pid}` | No consumido (H-07) | ninguna | `SessionParticipant` |
| RF-table_sessions-005 | `PUT /table-sessions/{id}/assignments` | No consumido (H-07) | ninguna | `OrderItem`, `SessionParticipant` |
| RF-table_sessions-006 | `GET /table-sessions/{id}/bill` | Consumido | Terminal (Panel de cobro) | `TableSession` |
| RF-table_sessions-007 | `POST /table-sessions/{id}/close` | Consumido | Terminal ("Cobrar y cerrar mesa") | `TableSession`, `Sale` |
| RF-table_sessions-008 | `POST /table-sessions/{id}/release` | Consumido | Terminal ("Liberar Mesa") | `TableSession`, `DiningTable` |
| RF-cart-001 | `POST /cart/sessions` | Consumido | `/menu/t/:token` | `TableSession`, `SessionParticipant`, `Cart` |
| RF-cart-002 | `GET /cart` | Consumido | `/menu/t/:token` | `Cart`, `CartItem` |
| RF-cart-003 | `POST /cart/items` | Consumido | `/menu/t/:token` | `CartItem` |
| RF-cart-004 | `PATCH /cart/items/{id}` | Consumido | `/menu/t/:token` | `CartItem` |
| RF-cart-005 | `DELETE /cart/items/{id}` | Consumido | `/menu/t/:token` | `CartItem` |
| RF-cart-006 | `POST /cart/leave` | Consumido | `/menu/t/:token` ("Salir") | `SessionParticipant` |
| RF-cart-007 | `POST /cart/submit` | Consumido | checkout del comensal (pasos 2/3) | `CustomerOrder`, `OrderPaymentAttempt` |
| RF-cart-008 | `GET /cart/orders` | Consumido | "Mis pedidos", confirmación | `CustomerOrder` |
| RF-cart-009 | `POST /cart/orders/{id}/cancel` | Consumido | "Mis pedidos" | `CustomerOrder` |
| RF-cart-010 | `GET /cart/payment-methods` | Consumido | checkout del comensal (paso 2) | `PaymentMethod` |
| RF-cart-011 | `POST /cart/payment-receipt/presign` | Consumido | checkout del comensal (paso 3) | — |
| RF-cart-012 | `POST /cart/orders/{id}/payment-attempts` | Consumido | "Mis pedidos" | `OrderPaymentAttempt` |
| RF-cart-013 | `POST /cart/payment-attempts/{id}/receipt/presign` | Consumido | "Mis pedidos" | `OrderPaymentAttempt` |
| RF-cart-014 | `POST /cart/payment-attempts/{id}/receipt` | Consumido | checkout del comensal, "Mis pedidos" | `OrderPaymentAttempt` |

## Grupo G5 — Caja, ventas y facturación

| RF | Endpoint(s) | Estado | Pantalla(s) | Entidad(es) |
|---|---|---|---|---|
| RF-cash-001 | `GET /cash/registers` | Consumido | `/dashboard/caja` | `CashRegister` |
| RF-cash-002 | `POST /cash/registers` | Consumido | `/dashboard/caja` | `CashRegister` |
| RF-cash-003 | `GET /cash/shifts` | Consumido | `/dashboard/caja` (Historial) | `CashShift` |
| RF-cash-004 | `POST /cash/shifts/open` | Consumido | `/dashboard/caja` | `CashShift` |
| RF-cash-005 | `GET /cash/shifts/current` | Consumido | `/dashboard/caja` | `CashShift` |
| RF-cash-006 | `POST /cash/shifts/{id}/close` | Consumido | `/dashboard/caja` | `CashShift`, `CashCountDenomination` |
| RF-cash-007 | `GET /cash/shifts/{id}/reconciliation` | Consumido | `/dashboard/caja` | `CashShift`, `Sale`, `Payment` |
| RF-cash-008 | `GET /cash/shifts/{id}/report` | Consumido | `/dashboard/caja` (Reporte) | `CashShift` |
| RF-cash-009 | `GET /cash/shifts/{id}/movements` | Consumido | `/dashboard/caja` | `CashMovement` |
| RF-cash-010 | `POST /cash/shifts/{id}/movements` | Consumido | `/dashboard/caja` | `CashMovement` |
| RF-sales-001 | `GET /sales/payment-methods/catalog` | Consumido | `/dashboard/ajustes/metodos-pago` | `PaymentMethodCatalog`, `PaymentMethod` |
| RF-sales-002 | `GET /sales/payment-methods` | Consumido | `/dashboard/ajustes/metodos-pago`, Terminal | `PaymentMethod` |
| RF-sales-003 | `POST /sales/payment-methods` | Consumido | `/dashboard/ajustes/metodos-pago` | `PaymentMethod` |
| RF-sales-004 | `PATCH /sales/payment-methods/{id}` | Consumido | `/dashboard/ajustes/metodos-pago` | `PaymentMethod` |
| RF-sales-005 | `POST /sales` | No consumido (H-10) | ninguna | `Sale`, `SaleItem`, `Payment`, `Invoice` |
| RF-sales-006 | `GET /sales` | Consumido | `/dashboard/ventas` | `Sale` |
| RF-sales-007 | `GET /sales/{id}` | Consumido | Terminal (reimpresión) | `Sale` |
| RF-invoices-001 | `GET /invoices/{id}` | No consumido (H-05) | ninguna | `Invoice` |
| RF-invoices-002 | `GET /invoices` | Consumido | Terminal (`findSaleForOrder`) | `Invoice` |
| RF-reports-001 | `GET /reports/sales` | Consumido | `/dashboard/reports` | `Sale` |
| RF-reports-002 | `GET /reports/products` | No consumido (H-05) | ninguna | `SaleItem`, `Product` |
| RF-reports-003 | `GET /reports/top-products` | Consumido | `/dashboard/reports` | `SaleItem`, `Product` |
| RF-reports-004 | `GET /reports/categories` | Consumido | `/dashboard/reports` | `SaleItem`, `Category` |
| RF-reports-005 | `GET /reports/cashiers` | Consumido | `/dashboard/reports` | `Sale`, `User` |
| RF-reports-006 | `GET /reports/inventory` | Consumido | `/dashboard/reports` | `InventoryItem` |
| RF-reports-007 | `GET /reports/profitability` | Consumido | `/dashboard/reports` | `Sale`, `RecipeItem` |
| RF-audit-001 | `GET /audit-logs` | No consumido (H-05) | ninguna | `AuditLog` |
| RF-plan-001 | `GET /plan` | Consumido | `/dashboard/plan`, `/dashboard/ajustes` | `Plan`, `Tenant` |

## Grupo G6 — Infraestructura técnica

| RF | Endpoint(s) | Estado | Pantalla(s) | Entidad(es) |
|---|---|---|---|---|
| RF-health-001 | `GET /health` | No consumido por `pos-heladeria` (sin discrepancia) | ninguna (infraestructura) | — |
| RF-notifications-001 | `GET /notifications` | Consumido | campanita del header | `NotificationEvent` |
| RF-notifications-002 | `GET /notifications/push/public-key` | Consumido | registro de push | — |
| RF-notifications-003 | `POST /notifications/push/subscriptions` | Consumido | registro de push | `PushSubscription` |
| RF-notifications-004 | `DELETE /notifications/push/subscriptions` | Consumido | logout | `PushSubscription` |
| RF-notifications-005 | `POST /notifications/{id}/attend` | Consumido | campanita del header | `NotificationEvent` |
| RF-realtime-001 | `POST /realtime/ticket` | Consumido | transversal (staff) | — |
| RF-realtime-002 | `GET /realtime/stream` | Consumido | Terminal, shell del comensal | — |
| RF-uploads-001 | `POST /uploads/presign` | Consumido | logo, imagen de producto, QR de método de pago | — |

## Requisitos no funcionales (§ 3.5 y 3.3)

| RNF | Endpoint(s)/alcance | Entidad(es) |
|---|---|---|
| RNF-rendimiento-001 (paginación) | transversal a G1-G5 | — |
| RNF-rendimiento-002 (timeouts R2) | `POST /uploads/presign` y flujos de imagen/comprobante | — |
| RNF-rendimiento-003 (SSE) | `GET /realtime/stream` | — |
| RNF-rendimiento-004 (rate limiting) | `POST /auth/forgot-password`, `POST /cart/*`, `GET /menu/qr-token/{token}`, `POST`/`GET /realtime/*` | — |
| RNF-seguridad-001 (sesión JWT) | `POST`/`GET /auth/*` | `User` |
| RNF-seguridad-002 (separación de credenciales) | `/cart/*`, `/menu/qr-token/{token}` | `TableSession`, `SessionParticipant` |
| RNF-seguridad-003 (RBAC + Mesero) | transversal a G1-G5 | — |
| RNF-seguridad-004 (aislamiento multi-tenant) | transversal | `Tenant` |
| RNF-seguridad-005 (política de contraseñas) | `POST /auth/change-password`, `POST /auth/reset-password` | `User` |
| RNF-seguridad-006 (subida de archivos) | `POST /uploads/presign` | — |
| RNF-seguridad-007 (ocultamiento de datos sensibles) | `GET /orders/{id}/payment-attempts`, `GET /sales/payment-methods?available=true`, `GET /users*` | `OrderPaymentAttempt`, `PaymentMethod`, `User` |
| RNF-fiabilidad-001 (atomicidad cobro/inventario) | `POST /orders/{id}/checkout-and-send`, `POST /sales`, `POST /table-sessions/{id}/close` | — |
| RNF-fiabilidad-002 (idempotencia) | `POST /cart/leave`, `POST /notifications/{id}/attend`, `DELETE /notifications/push/subscriptions`, `GET /invoices` | — |
| RNF-fiabilidad-003 (degradación controlada) | `GET /bootstrap` y envíos de correo/push/Sentry | — |
| RNF-disponibilidad-001 (liveness) | `GET /health` | — |
| RNF-mantenibilidad-001 (motores compartidos) | transversal a G2/G4/G5 | — |
| RNF-mantenibilidad-002 (characterization tests) | transversal | — |
| RNF-portabilidad-001 (almacenamiento S3-compatible) | `POST /uploads/presign` | — |
| RNF-portabilidad-002 (despliegue containerizado) | transversal | — |
