# Línea base y hallazgos de verificación — spec 134

Registro de trabajo de la implementación (no es un contrato). Lo alimentan T003, T004, T005, T034 y T050.

## T003 — Línea base de la suite de `pos-heladeria` (sin cambios, 2026-10-24)

Rama `fix/134-block-browser-translation` recién creada desde `develop` (`ba7e9e8`), sin ninguna
edición. Comando: `npx ng test --watch=false` corrida **sola** (sin el backend en paralelo).

**Resultado**: `Test Files  24 failed | 125 passed (149)` · `Tests  103 failed | 2001 passed | 1 skipped (2105)`.

> Varios archivos de esta lista son archivos que la spec 134 va a tocar (`app.spec.ts`,
> `product-select`, `public-menu`, `transfer-details-step`, `manual-order-page`, `pos-terminal.store`,
> `cash-arqueo-modal`, `pos-checkout-panel`, `pos-order-panel`, `table-sessions`,
> `session-bill-panel`, `product-form`, `promotions-page`). Por eso la comparación de T083 se hace
> **por archivo y también por prueba**: la lista por prueba está más abajo. Una prueba de esa lista que
> siga fallando es preexistente; una que no esté en la lista y falle es regresión de esta feature.

### Archivos que ya fallan (24)

| Archivo | Pruebas | Fallan |
|---|---|---|
| `src/app/app.spec.ts` | 2 | 2 |
| `src/app/core/services/auth.service.spec.ts` | 19 | 1 |
| `src/app/core/services/menu.service.spec.ts` | 6 | 1 |
| `src/app/modules/auth/pages/reset-password.component.spec.ts` | 26 | 1 |
| `src/app/modules/cash-register/components/cash-arqueo-modal.component.spec.ts` | 12 | 1 |
| `src/app/modules/cash-register/services/cash-session.store.spec.ts` | 37 | 1 |
| `src/app/modules/dashboard/layout/dashboard-layout.component.spec.ts` | 22 | 2 |
| `src/app/modules/dashboard/layout/tenant-header.component.spec.ts` | 13 | 1 |
| `src/app/modules/dashboard/layout/tenant-sidebar.component.spec.ts` | 17 | 1 |
| `src/app/modules/orders/pages/order-detail.component.spec.ts` | 49 | 4 |
| `src/app/modules/orders/pages/orders-page.component.spec.ts` | 24 | 1 |
| `src/app/modules/products/pages/product-form.component.spec.ts` | 70 | 3 |
| `src/app/modules/promotions/pages/promotions-page.component.spec.ts` | 57 | 56 |
| `src/app/modules/super-admin/pages/super-admin-users-page.component.spec.ts` | 3 | 1 |
| `src/app/modules/super-admin/services/tenant.service.spec.ts` | 4 | 3 |
| `src/app/modules/tables/components/pos-checkout-panel.component.spec.ts` | 44 | 4 |
| `src/app/modules/tables/components/pos-order-panel.component.spec.ts` | 46 | 2 |
| `src/app/modules/tables/components/product-select.component.spec.ts` | 65 | 2 |
| `src/app/modules/tables/components/session-bill-panel.component.spec.ts` | 30 | 1 |
| `src/app/modules/tables/pages/checkout/transfer-details-step.component.spec.ts` | 27 | 1 |
| `src/app/modules/tables/pages/manual-order-page.component.spec.ts` | 81 | 6 |
| `src/app/modules/tables/pages/public-menu.component.spec.ts` | 72 | 4 |
| `src/app/modules/tables/pages/table-sessions.component.spec.ts` | 52 | 2 |
| `src/app/modules/tables/services/pos-terminal.store.spec.ts` | 227 | 2 |

### Pruebas que ya fallan (103), una por línea

```text
src/app/app.spec.ts > App > should create the app
src/app/app.spec.ts > App > should render title
src/app/core/services/auth.service.spec.ts > AuthService.login > clears mustChangePassword after a successful password change
src/app/core/services/menu.service.spec.ts > MenuService — la terminal gana la condición, ningún importe (spec 066) > NO mapea `discounted_price` ni `discount_kind`: el modal sigue mostrando $8.000 (FR-017)
src/app/modules/auth/pages/reset-password.component.spec.ts > ResetPasswordComponent > usa los literales del contrato de textos
src/app/modules/cash-register/components/cash-arqueo-modal.component.spec.ts > CashArqueoModalComponent > bloqueo de cierre por pedidos activos > con 2 pedidos renderiza el conteo, un elemento por pedido y los enlaces al detalle
src/app/modules/cash-register/services/cash-session.store.spec.ts > CashSessionStore — fechas y horas en 12 horas y zona horaria del negocio > formatDate (historial de cierres) usa 12 horas con AM/PM y la fecha del negocio
src/app/modules/dashboard/layout/dashboard-layout.component.spec.ts > DashboardLayoutComponent — bifurcación Super Admin vs. tenant (spec 116, research.md R1) > un usuario no-super-admin monta app-tenant-sidebar/app-tenant-header (y no app-sidebar/app-header)
src/app/modules/dashboard/layout/dashboard-layout.component.spec.ts > DashboardLayoutComponent — impresión del reporte de caja (spec 089, Historia 5) > el telón del menú móvil nunca se imprime (print:hidden), aunque el menú esté abierto
src/app/modules/dashboard/layout/tenant-header.component.spec.ts > TenantHeaderComponent (spec 116) > MESERO no ve el indicador de caja en absoluto
src/app/modules/dashboard/layout/tenant-sidebar.component.spec.ts > TenantSidebarComponent (spec 116) > un nombre de negocio largo se trunca sin romper el layout del encabezado
src/app/modules/orders/pages/order-detail.component.spec.ts > OrderDetailComponent > el botón de volver ya no es la flecha "←" (spec 082)
src/app/modules/orders/pages/order-detail.component.spec.ts > OrderDetailComponent — bloques agrupados del nuevo diseño (spec 120, US2) > "Volver a órdenes" conserva los filtros con los que se navegó al detalle (FR-011)
src/app/modules/orders/pages/order-detail.component.spec.ts > OrderDetailComponent — encabezado por tipo de pedido (spec 094, US1) > con mesa con nombre, el valor incluye el nombre tras el separador
src/app/modules/orders/pages/order-detail.component.spec.ts > OrderDetailComponent — encabezado por tipo de pedido (spec 094, US1) > con mesa, el rótulo dice "Mesa" y el valor el nombre de la mesa
src/app/modules/orders/pages/orders-page.component.spec.ts > OrdersPageComponent > una orden sin `total` (compat con un backend anterior) no muestra ningún monto inventado
src/app/modules/products/pages/product-form.component.spec.ts > ProductFormComponent > el placeholder dice "Se mostrará la presentación" si aún no se eligió ninguna
src/app/modules/products/pages/product-form.component.spec.ts > ProductFormComponent > el selector de Presentación de una fila busca en el servidor: encuentra una presentación aunque no esté en allPresentations() (D3)
src/app/modules/products/pages/product-form.component.spec.ts > ProductFormComponent > un producto nuevo abre con el switch de inventario apagado por defecto
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > addRuleRow / removeRuleRow (Paso 1 + Paso 2) > al abrir una promoción guardada, agrupa sus reglas por presentación y recupera los productos (A-81)
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > addRuleRow / removeRuleRow (Paso 1 + Paso 2) > cambiar los productos seleccionados no obliga a rehacer las reglas (A-81)
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > addRuleRow / removeRuleRow (Paso 1 + Paso 2) > con un solo producto, agrega la regla de la presentación y limpia el picker
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > addRuleRow / removeRuleRow (Paso 1 + Paso 2) > con varios productos, la lista tiene UNA regla por presentación y form.rules una por producto (A-81)
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > addRuleRow / removeRuleRow (Paso 1 + Paso 2) > FR-025: una regla de precio de paquete no admite menos de 2 unidades
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > addRuleRow / removeRuleRow (Paso 1 + Paso 2) > FR-026: rechaza un precio de paquete que no representa ahorro frente a la suma regular (espejo del guard del backend)
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > addRuleRow / removeRuleRow (Paso 1 + Paso 2) > quitar una regla de la lista quita todas sus reglas de backend
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > addRuleRow / removeRuleRow (Paso 1 + Paso 2) > remueve una fila ya agregada
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > addRuleRow / removeRuleRow (Paso 1 + Paso 2) > se puede definir la regla antes de elegir productos: no genera reglas de backend hasta que haya un producto que la tenga
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > addRuleRow / removeRuleRow (Paso 1 + Paso 2) > si el menú aún no cargó al abrir la promoción, agrupa las reglas cuando llegue
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > addRuleRow / removeRuleRow (Paso 1 + Paso 2) > una presentación solo admite una regla por promoción
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > continueToConfigure (pantalla de creación) > no avanza sin nombre
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > continueToConfigure (pantalla de creación) > si el backend rechaza la creación, se queda en la pantalla de creación con el error visible
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > continueToConfigure (pantalla de creación) > spec 083 (FR-020, A-75): crea de inmediato en Borrador y arranca sin reglas
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > continueToConfigure (pantalla de creación) > spec 127 (FR-001): starts_at usa el día calendario LOCAL del tenant, no el día UTC
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > duplicar con un nombre que ya existe (spec 084, A-83) > cambiar el nombre quita el aviso de reemplazo
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > duplicar con un nombre que ya existe (spec 084, A-83) > el diálogo muestra el aviso y cambia el texto del botón
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > duplicar con un nombre que ya existe (spec 084, A-83) > el primer intento solo avisa en el diálogo: no reemplaza nada ni muestra el error en la lista
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > duplicar con un nombre que ya existe (spec 084, A-83) > el segundo intento pide reemplazar, y al éxito cierra el diálogo y abre la copia
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > duplicar con un nombre que ya existe (spec 084, A-83) > otro error distinto al de nombre repetido se muestra como error normal
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > el conjunto vacío de una regla invalida el formulario (FR-001)
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > FR-001a: una variante repetida entre dos reglas se detecta en el cliente y bloquea el formulario
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > FR-017: promotionTypeLabel (columna "Reglas" simplificada) > muestra únicamente el tipo cuando todas las reglas comparten uno
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > FR-017: promotionTypeLabel (columna "Reglas" simplificada) > sin reglas todavía (Borrador recién creado, A-75)
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > FR-018: en una promoción activa las reglas no son editables (canEditRuleSet false)
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > FR-021: canDelete (habilitación de "Eliminar") > habilitado para Borrador, En pausa y Finalizada; bloqueado solo para Activa
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > "Guardar y sincronizar" al final del formulario, solo con cambios > al abrir la configuración no hay cambios y el botón está deshabilitado
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > "Guardar y sincronizar" al final del formulario, solo con cambios > cualquier cambio (nombre, fecha, días, horas, reglas) habilita el botón
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > "Guardar y sincronizar" al final del formulario, solo con cambios > el botón ya no está en la cabecera: es lo último del formulario
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > "Guardar y sincronizar" al final del formulario, solo con cambios > reordenar días o variantes sin cambiar su contenido no cuenta como cambio
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > "Guardar y sincronizar" al final del formulario, solo con cambios > una promoción finalizada (solo lectura) no muestra el botón
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > "Guardar y sincronizar" al final del formulario, solo con cambios > un cambio inválido no habilita el botón (sigue exigiendo formValid)
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > la ventana de vigencia (date) va string-a-string, sin corrimiento de día
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > los íconos de volver/ayuda del formulario ya no son SVG artesanales (spec 082)
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > openEdit: una promoción pausada habilita agregar/quitar reglas (FR-014) y fija el type de la primera regla existente
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > presentaciones del Paso 2 (spec 084, A-80: independientes de los productos) > agregar una presentación que ningún producto seleccionado tiene se acepta, pero queda marcada como sin aplicar (A-81)
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > presentaciones del Paso 2 (spec 084, A-80: independientes de los productos) > availablePresentations lista todas las activas del catálogo, sin productos seleccionados
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > presentaciones del Paso 2 (spec 084, A-80: independientes de los productos) > cambiar los productos seleccionados no reinicia la presentación elegida
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > presentaciones del Paso 2 (spec 084, A-80: independientes de los productos) > la etiqueta de una variante es el nombre de su presentación, aun con una sola variante
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > presentaciones del Paso 2 (spec 084, A-80: independientes de los productos) > la lista no cambia al seleccionar productos
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > presentaciones del Paso 2 (spec 084, A-80: independientes de los productos) > pickerMatchSummary avisa a cuántos de los productos seleccionados se aplicaría
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > presentaciones del Paso 2 (spec 084, A-80: independientes de los productos) > resolvedVariantIdsForPresentation junta la variante de cada producto candidato que la tiene
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > presentaciones del Paso 2 (spec 084, A-80: independientes de los productos) > un producto de una sola variante se empareja por su presentación real
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > spec 063 (FR-014): saveConfigure() actualiza las reglas (updateShape) también cuando la promoción está pausada
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > spec 083 (A-75): saveConfigure() nunca crea -- la promoción ya existe desde "Continuar"
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > spec 084 FR-008/FR-009/FR-010 (A-76): "Configurar" deshabilitado en Activa > canConfigure: habilitado para Borrador, En pausa y Finalizada; bloqueado solo para Activa, sin importar el badge
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > spec 084 FR-008/FR-009/FR-010 (A-76): "Configurar" deshabilitado en Activa > openEdit no abre la pantalla de configuración para una promoción active (defensa en profundidad)
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > spec 084 FR-008/FR-009/FR-010 (A-76): "Configurar" deshabilitado en Activa > openEdit sí abre la pantalla para draft/paused/finished
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > spec 084 FR-021/FR-022 (A-78): exclusividad de producto en el Paso 1 > blockedReason() devuelve el nombre de la promoción activa que ya cubre el producto (por cualquiera de sus variantes)
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > spec 084 FR-021/FR-022 (A-78): exclusividad de producto en el Paso 1 > FR-024: la promoción en edición (editingId) se excluye de su propio bloqueo
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > spec 084 FR-021/FR-022 (A-78): exclusividad de producto en el Paso 1 > toggleProductCandidate() rechaza seleccionar un producto bloqueado (defensa en profundidad)
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > spec 084 FR-021/FR-022 (A-78): exclusividad de producto en el Paso 1 > un producto sin ninguna promoción activa en conflicto se puede seleccionar con normalidad
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > spec 084 FR-026 a FR-028 (bug 5): menú de acciones sin recortar ni mover el scroll > cerrar el menú (clic fuera / seleccionar una opción) no deja nada en el overlay
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > spec 084 FR-026 a FR-028 (bug 5): menú de acciones sin recortar ni mover el scroll > el menú se renderiza fuera del contenedor con scroll de la tabla (CDK Overlay, no recortado)
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > spec 084 FR-026 a FR-028 (bug 5): menú de acciones sin recortar ni mover el scroll > redimensionar la ventana cierra el menú abierto (FR-028, edge case de layout)
src/app/modules/promotions/pages/promotions-page.component.spec.ts > PromotionsPageComponent > un conflicto de variante repetida de una promoción abierta antes no bloquea el guardado de la siguiente
src/app/modules/super-admin/pages/super-admin-users-page.component.spec.ts > SuperAdminUsersPageComponent — nombre y avatar (spec 091, Historia 6) > muestra el correo y su inicial si no hay nombre propio (vacío, nulo o igual al correo)
src/app/modules/super-admin/services/tenant.service.spec.ts > TenantService > creates a tenant with the user payload via POST /super-admin/tenants
src/app/modules/super-admin/services/tenant.service.spec.ts > TenantService > maps a FastAPI 422 (detail as array) to a readable message
src/app/modules/super-admin/services/tenant.service.spec.ts > TenantService > maps a string detail error
src/app/modules/tables/components/pos-checkout-panel.component.spec.ts > PosCheckoutPanelComponent — modo terminal-pos > el nombre de facturación va por defecto "Consumidor Final", en modo solo lectura (spec 058, FR-001)
src/app/modules/tables/components/pos-checkout-panel.component.spec.ts > PosCheckoutPanelComponent — modo terminal-pos > spec 058, FR-001/FR-002: el botón "editar" habilita el nombre de facturación, y vuelve a solo lectura al perder foco
src/app/modules/tables/components/pos-checkout-panel.component.spec.ts > PosCheckoutPanelComponent — modo terminal-pos > T032: ofrece "Imprimir Pre-cuenta" cuando hay cuenta de sesión
src/app/modules/tables/components/pos-checkout-panel.component.spec.ts > PosCheckoutPanelComponent — pedido ya en cocina, cobro por sesión de mesa > si ensureReadyToCharge devuelve false (cajero canceló), no cierra la sesión
src/app/modules/tables/components/pos-order-panel.component.spec.ts > PosOrderPanelComponent — reparto de alto: lista de productos sin scroll propio (spec 078, US4; hotfix posterior) > "Marcar pedido listo" (en la cabecera, a pedido del usuario) queda shrink-0, fuera de la lista scrolleable (FR-023)
src/app/modules/tables/components/pos-order-panel.component.spec.ts > PosOrderPanelComponent — sin resumen de totales (spec 049) > conserva "Marcar pedido listo" fuera del contenedor de totales retirado
src/app/modules/tables/components/product-select.component.spec.ts > ProductSelectComponent — [fromPromotions]/[existingQtyFor] (spec 081) > el botón de cerrar ya no usa el emoji ✕ (spec 082)
src/app/modules/tables/components/product-select.component.spec.ts > ProductSelectComponent — información de promoción (spec 066) > FR-014: la fila con promoción muestra el nombre de la presentación y la promoción por separado (nunca solo la promoción)
src/app/modules/tables/components/session-bill-panel.component.spec.ts > SessionBillPanelComponent > cobra enviando el efectivo recibido, no el total
src/app/modules/tables/pages/checkout/transfer-details-step.component.spec.ts > TransferDetailsStepComponent > pinta el total ANTES del <h1> con el nombre del método en el orden del documento (FR-001)
src/app/modules/tables/pages/manual-order-page.component.spec.ts > ManualOrderPageComponent > al iniciar, selecciona la mesa del parámetro de ruta
src/app/modules/tables/pages/manual-order-page.component.spec.ts > ManualOrderPageComponent > ningún ícono se renderiza ya como SVG artesanal ni con forma de cono de helado (spec 082)
src/app/modules/tables/pages/manual-order-page.component.spec.ts > ManualOrderPageComponent > spec 115 (A-125): una línea con promoción de precio de paquete (min_qty > 1, sin discounted_price) también muestra insignia y tachado
src/app/modules/tables/pages/manual-order-page.component.spec.ts > ManualOrderPageComponent — pestaña "Promociones" (spec 115) > bugfix: reabrir el modal para el mismo producto arranca sin las adiciones de la línea anterior (no las hereda al crear una línea hermana)
src/app/modules/tables/pages/manual-order-page.component.spec.ts > ManualOrderPageComponent — pestaña "Promociones" (spec 115) > T038: agregar desde la categoría original (no "Promociones") deja la línea en cantidad 1
src/app/modules/tables/pages/manual-order-page.component.spec.ts > ManualOrderPageComponent — pestaña "Promociones" (spec 115) > T039: encontrar el producto con el buscador (sin pasar por "Promociones") deja la línea en cantidad 1
src/app/modules/tables/pages/public-menu.component.spec.ts > PublicMenuComponent > mesa cerrada (spec 089, A-95) > un 401 SIN cabecera (vencimiento por inactividad) conserva la pantalla de nombre con su mensaje
src/app/modules/tables/pages/public-menu.component.spec.ts > PublicMenuComponent > "recibida" sin aceptar: badge "Por confirmar" y "Esperando a que el personal lo acepte."
src/app/modules/tables/pages/public-menu.component.spec.ts > PublicMenuComponent > una nota de ítem se muestra en "Mis pedidos", asociada solo a la línea que la tiene (FR-001 a FR-003)
src/app/modules/tables/pages/public-menu.component.spec.ts > PublicMenuComponent > un producto disponible no muestra la etiqueta "Agotado" ni queda deshabilitado
src/app/modules/tables/pages/table-sessions.component.spec.ts > TableSessionsComponent — CTA "Crear pedido nuevo" en las 3 pestañas (spec 078, US2) > el CTA se renderiza con la pestaña en 'mesas' (sin tarjeta seleccionada) (FR-007)
src/app/modules/tables/pages/table-sessions.component.spec.ts > TableSessionsComponent — diálogo de éxito (spec 029 + spec 125) > spec 125 (FR-009): "Imprimir Factura" imprime y cierra el modal
src/app/modules/tables/services/pos-terminal.store.spec.ts > PosTerminalStore.marcarListo — pedido "pagada" no desaparece (gap spec 035, A-52) > marcarListo() no llama a "ready" y en cambio hace PATCH por cada ítem pendiente, sin chocar con el 409 de A-16
src/app/modules/tables/services/pos-terminal.store.spec.ts > PosTerminalStore — no mezclar paquete con suelto en la misma línea (A-134) > saveOrder() con dos líneas hermanas hace dos llamadas a addOrderItems, una por línea
```

Causa visible de `app.spec.ts` (2 pruebas): `No provider found for SwPush` (el `App` real arrastra
`AuthService → PushRegistrationService → SwPush` y el spec no lo provee). **Preexistente**: T022 monta el
banner en `app.html`, pero `app.spec.ts` ya estaba rojo; lo que T022/T024 exigen es que **no empeore**
(mismo error, mismas 2 pruebas), no que pase a verde.

## T004 — Invariantes de diseño (2026-10-24, antes de implementar)

| # | Comprobación | Resultado |
|---|---|---|
| a | `grep -rn '<font' src/ public/` | vacío ✔ (S3 es segura: la app no usa `<font>`) |
| b | `grep -rnE 'hyphens\|:lang\(' src/ public/` | vacío ✔ (`lang="es"` no cambia maquetación ni impresión) |
| c | `grep -rnE 'status\s*===?\s*423' src/` | vacío ✔ (nadie interpreta el 423 del bloqueo) |

## T005 — Escáner de texto suelto vs. tests protegidos (2026-10-24)

- `scan-loose-text.py ../pos-heladeria/src/app` → `TOTAL bloques con texto suelto: 55 en 21 archivos` ✔
  (con la herramienta **original**. Al implementar US5 se refinó —ignora `@let` y entiende `@else if` con
  paréntesis anidados— y sobre el mismo código da **49 bloques en 19 archivos**: ver
  [contracts/alternating-labels.md](./contracts/alternating-labels.md).)
- `grep -rln "CONGELA comportamiento actual" ../pos-heladeria/src` → solo
  `modules/tables/pages/checkout/review-step.component.spec.ts`, que **no** figura entre los 21 archivos
  del escáner ✔ (Principio III: no se toca).

## T034 — ¿Cada superficie de cobro del panel muestra el motivo del 423? (2026-10-24)

Lectura del código (sin cambios de negocio). Todas las superficies pasan el error por un `extractError`
que devuelve `error.detail` cuando es una cadena —exactamente lo que escribe el interceptor—, así que
muestran "No se pudo {acción}: la página fue alterada por el navegador. Recarga para continuar." sin
código nuevo. Además el banner raíz (`blockedNotice`) repite la acción rechazada, de modo que ninguna
superficie queda sin explicación visible aunque descartara su propio error.

| Superficie | Acción (fila) | Cómo muestra el error | ¿Se ve el 423? |
|---|---|---|---|
| `PosCheckoutPanelComponent` → `PosTerminalStore` | P-1, P-3, P-2 | `error.set(api.extractError(...))` + `toast.error(...)` | Sí |
| `PaymentAttemptReviewPanelComponent` ("Pagos por confirmar") | P-5, P-6 (P-7 sin UI) | `toast.error(api.extractError(...))` en aprobar/confirmar | Sí |
| `SessionBillPanelComponent` | P-8 | `error.set(api.extractError(...))`, pintado en el panel | Sí |
| Armado de orden manual (`manual-order-page`) | P-1, P-2 | usa `PosTerminalStore` (misma ruta que la Terminal) | Sí |
| `CashSessionStore` (abrir, movimiento, cierre) | P-10, P-11, P-12 | `error.set(api.extractError(...))`, pintado en `cash-open`, `cash-movement-modal`, `cash-arqueo-modal` y `cash-dashboard` | Sí |
| `TableSessionService.extractError` / `CashService.extractError` | — | leen `detail` cadena | Sí |

Conclusión: no hace falta tocar ninguna superficie. El 423 no se confunde con `401`/`409` (el
`closeBlocked` de la cuenta de mesa solo mira `409`).

## T050 — V8: momento seguro en reposo (2026-10-24)

En reposo (sin modales ni formularios editados) se evaluó, con Chrome y el tenant desechable `qa134`
(panel) y el tenant `heladeria` (menú QR), la condición `.fixed.inset-0` con `getClientRects().length > 0`,
`.ng-dirty` y el campo con foco y valor. **Resultado: `[]`, `0` y sin foco en las 16 pantallas
revisadas** (pantalla de nombre y menú QR, `checkout/review`, `checkout/method`, `checkout/confirmation`,
`/dashboard/{admin, mesas-sesiones, orders, mesas, caja, inventario, reports, ajustes, products, users}` y
login). La actualización de versión puede aplicarse en reposo en todas; no hizo falta ninguna excepción.

## T083 — Suite completa al final (2026-10-24, corrida sola, sin el backend en paralelo)

**Resultado**: `Test Files  8 failed | 150 passed (158)` · `Tests  14 failed | 2311 passed | 1 skipped (2326)`.
Línea base (T003): 24 archivos / 103 pruebas fallando sobre 149 archivos / 2105 pruebas.

- **Fallos nuevos: 0** —ni por archivo ni por prueba—. Las 14 pruebas que fallan **ya fallaban en la línea base**
  (lista abajo); se reportan como preexistentes y no se atribuyen a esta feature (SC-006).
- 9 archivos de spec nuevos (5 de `core/integrity`, 3 de `core/update`, `product-select-pos`) y casos nuevos en
  8 specs existentes: **2326 pruebas contra 2105** de la línea base (+221), todas las nuevas en verde.
- Los 89 fallos de la línea base que ya no aparecen **no son mérito de esta feature**: la línea base se midió
  con la máquina cargada (la contención infla fallos por *timeout* de 5 s; ver la memoria del proyecto sobre
  el recuento que deriva). Con los cambios, esos archivos pasan corridos de a uno (comprobado para los de
  las plantillas tocadas: `product-form`, `public-menu`, `table-sessions`, `payment-attempt-review-panel`…).

Pruebas que siguen fallando (todas preexistentes):

```text
src/app/app.spec.ts > App > should create the app
src/app/app.spec.ts > App > should render title
src/app/core/services/auth.service.spec.ts > AuthService.login > clears mustChangePassword after a successful password change
src/app/core/services/menu.service.spec.ts > MenuService — la terminal gana la condición, ningún importe (spec 066) > NO mapea `discounted_price` ni `discount_kind`: el modal sigue mostrando $8.000 (FR-017)
src/app/modules/super-admin/services/tenant.service.spec.ts > TenantService > creates a tenant with the user payload via POST /super-admin/tenants
src/app/modules/super-admin/services/tenant.service.spec.ts > TenantService > maps a FastAPI 422 (detail as array) to a readable message
src/app/modules/super-admin/services/tenant.service.spec.ts > TenantService > maps a string detail error
src/app/modules/tables/components/pos-checkout-panel.component.spec.ts > PosCheckoutPanelComponent — modo terminal-pos > T032: ofrece "Imprimir Pre-cuenta" cuando hay cuenta de sesión
src/app/modules/tables/components/pos-order-panel.component.spec.ts > PosOrderPanelComponent — reparto de alto: lista de productos sin scroll propio (spec 078, US4; hotfix posterior) > "Marcar pedido listo" (en la cabecera, a pedido del usuario) queda shrink-0, fuera de la lista scrolleable (FR-023)
src/app/modules/tables/components/pos-order-panel.component.spec.ts > PosOrderPanelComponent — sin resumen de totales (spec 049) > conserva "Marcar pedido listo" fuera del contenedor de totales retirado
src/app/modules/tables/pages/manual-order-page.component.spec.ts > ManualOrderPageComponent — pestaña "Promociones" (spec 115) > T038: agregar desde la categoría original (no "Promociones") deja la línea en cantidad 1
src/app/modules/tables/pages/manual-order-page.component.spec.ts > ManualOrderPageComponent — pestaña "Promociones" (spec 115) > T039: encontrar el producto con el buscador (sin pasar por "Promociones") deja la línea en cantidad 1
src/app/modules/tables/pages/manual-order-page.component.spec.ts > ManualOrderPageComponent — pestaña "Promociones" (spec 115) > bugfix: reabrir el modal para el mismo producto arranca sin las adiciones de la línea anterior (no las hereda al crear una línea hermana)
src/app/modules/tables/services/pos-terminal.store.spec.ts > PosTerminalStore — no mezclar paquete con suelto en la misma línea (A-134) > saveOrder() con dos líneas hermanas hace dos llamadas a addOrderItems, una por línea
```
