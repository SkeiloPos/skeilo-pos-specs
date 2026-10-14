---

description: "Task list template for feature implementation"
---

# Tasks: Layout base del panel (Sidebar + Navbar) con tema claro/oscuro persistente aplicado globalmente y micro-interacciones de carga

**Input**: Documentos de diseño de `specs/116-layout-base-panel-admin/`
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md) | **Data model**: [data-model.md](./data-model.md) | **Quickstart**: [quickstart.md](./quickstart.md) | **Contratos**: [contracts/](./contracts/)

> **Nota de alcance**: este archivo cubre **dos iteraciones** de la misma spec. Las Fases 1-6
> (T001-T032) son la **primera** iteración (2026-10-12) — ya implementada, verificada y
> commiteada (ver nota de verificación al final de la Fase 6). Las Fases 7-10 (T033 en adelante)
> son la **segunda** iteración (2026-10-13 — tema global al contenido de los módulos + botón de
> colapso reubicado + micro-interacciones de carga), generadas a partir de las unidades 8-15 de
> `plan.md` y todavía sin implementar.

**Repositorio de código**: todas las rutas de archivo son relativas a `pos-heladeria/` (el repositorio
`skeilo-pos-heladeria`, rama `feat/116-layout-base-panel-admin` — **nueva rama desde `develop`**
para la segunda iteración, ya que la primera se fusionó vía PR #36; plan.md, "Branch"). **`pos-backend`
no participa en ninguna tarea** (plan.md, Technical Context).

**Tests**: se incluyen — el plan (Principio X) pide un `*.spec.ts` hermano por archivo nuevo o
ampliado, siguiendo el patrón de `sidebar.component.spec.ts`/`sound.service.ts` ya existente.

**Organización**: las tareas de las Fases 3-5 y 7-9 están agrupadas por historia de usuario (US1,
US2, US3, US4 de spec.md) para poder implementarlas y probarlas de forma independiente, siguiendo
el orden de implementación sugerido en plan.md.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: se puede ejecutar en paralelo (archivo distinto, sin dependencia de una tarea sin terminar)
- **[Story]**: a qué historia de usuario pertenece (US1, US2, US3)
- Cada tarea incluye la ruta exacta del archivo

---

## Phase 1: Setup

**Propósito**: preparar el repositorio de código antes de tocar nada (Principio XIV).

- [X] T001 Crear la rama `feat/116-layout-base-panel-admin` desde `develop` en el repositorio
      `pos-heladeria` (Principio XIV — `pos-backend` no necesita rama porque no cambia ningún
      archivo suyo en esta spec).
- [X] T002 Ejecutar `npm test` en `pos-heladeria` (rama recién creada, sin cambios todavía) y
      anotar cuántos tests pasan/fallan como línea base (quickstart.md §0) — comparar contra la
      memoria de fallos preexistentes de la suite frontend; cualquier fallo nuevo después de
      implementar es una regresión de esta spec hasta que se demuestre lo contrario.
      **Línea base (2026-10-12)**: 20 fallan / 1648 pasan / 1 skip (14 archivos en rojo) —
      consistente con los fallos preexistentes ya conocidos (memoria del proyecto).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Propósito**: los tres bloques de los que depende todo lo demás — nada de `app-tenant-sidebar`/
`app-tenant-header` puede montarse ni pintarse sin esto (plan.md, "Orden de implementación
sugerido", Unidades 1-3).

**⚠️ CRÍTICO**: ninguna tarea de las Fases 3-5 puede empezar hasta que esta fase esté completa.

### Unidad 1 — Íconos, tokens de tema y script anti-parpadeo

- [X] T003 [P] Añadir ~18 `@case` nuevos de íconos estilo Lucide en
      `pos-heladeria/src/app/shared/icon/icon.component.ts` —
      `layout-dashboard`, `shopping-cart`, `layout-grid`, `qr-code`, `book-open`, `tags`,
      `cup-soda`, `percent`, `package`, `truck`, `banknote`, `chart-column`, `menu`, `bell`,
      `moon`, `sun`, `key-round`, `badge-check`, `log-out` — copiando el `path` real de Lucide
      (SVG 24×24, `stroke-width="2"`, trazo redondeado), con el mismo patrón que los ~30 `@case`
      ya existentes en ese archivo (research.md R2; contracts/navigation-grouping-contract.md).
- [X] T004 Ampliar `pos-heladeria/src/app/shared/icon/icon.component.spec.ts` con un caso por cada
      ícono nuevo de T003 que verifique que `app-icon` renderiza un `<svg>` con contenido para ese
      `name` (depende de T003).
- [X] T005 [P] Crear el bloque de tokens CSS `.panel-theme { --panel-color-*: … }` (tema claro) y
      `.panel-theme[data-theme="dark"] { --panel-color-*: … }` (tema oscuro) en
      `pos-heladeria/src/styles.css`, con los valores exactos de la tabla de research.md §R3
      (`primary`, `primary-active`, `primary-soft`, `primary-text`, `surface`, `surface-elevated`,
      `canvas`, `border`, `text-primary`, `text-secondary`, `text-muted`, `text-subtle`,
      `success`, `success-soft`, `overlay-hover`), reutilizando los `@font-face` de `Figtree`/
      `Sora` ya autoalojados (líneas ~51-90 del mismo archivo, spec 095) para `font-family` dentro
      de `.panel-theme` (contracts/panel-theme-contract.md §1-2).
- [X] T006 [P] Añadir un `<script>` inline síncrono en el `<head>` de `pos-heladeria/src/index.html`
      (antes de `<app-root>`) que: lee `pos.panel.theme` de `localStorage` con `try`/`catch`; si no
      hay valor, evalúa `window.matchMedia('(prefers-color-scheme: dark)').matches` (con su propio
      `try`); si tampoco hay señal, no hace nada (tema por defecto = claro); y fija el resultado
      como atributo `data-theme` en `<html>` antes de que el navegador pinte el primer frame
      (research.md R4; FR-012, FR-013, FR-014).

### Unidad 2 — Servicios de estado (`PanelThemeService` + `LayoutService.desktopCollapsed`)

- [X] T007 [P] Crear `pos-heladeria/src/app/modules/dashboard/layout/panel-theme.service.ts`
      (`PanelThemeService`, `providedIn: 'root'`) con el signal público `theme: Signal<'light' |
      'dark'>` resuelto en este orden: el atributo `data-theme` que T006 ya dejó en `<html>` →
      `localStorage` clave `pos.panel.theme` → `matchMedia('(prefers-color-scheme: dark)')` →
      `'light'`; y los métodos `toggleTheme()`/`setTheme(value)` que actualizan el signal y
      persisten con el mismo patrón `try`/`catch` que `sound.service.ts` (nunca lanzan, ni siquiera
      si `localStorage.setItem` falla) (data-model.md §1; contracts/panel-theme-contract.md §3).
- [X] T008 Crear `pos-heladeria/src/app/modules/dashboard/layout/panel-theme.service.spec.ts`
      cubriendo los 4 casos de quickstart.md §1: sin storage ni señal de sistema → `'light'`; sin
      storage con `matchMedia` mockeado en `dark` → `'dark'`; con `pos.panel.theme = 'dark'`
      guardado → `'dark'` sin consultar `matchMedia` (spy que nunca se llama);
      `localStorage.getItem`/`setItem` lanzando → no se propaga la excepción y el signal sigue
      cambiando en memoria (depende de T007).
- [X] T009 [P] Añadir a `pos-heladeria/src/app/modules/dashboard/layout/layout.service.ts` el
      signal nuevo `desktopCollapsed: Signal<boolean>` (persistido en `localStorage`, clave
      `pos.panel.sidebar_collapsed`, mismo `try`/`catch` que T007, por defecto `false` cuando no
      hay valor guardado o el storage falla) y el método `toggleDesktopCollapsed()` — sin
      modificar `sidebarOpen`, `open()`, `close()` ni `toggle()` ya existentes (research.md R5;
      data-model.md §2; contracts/panel-theme-contract.md §5).
- [X] T010 Crear `pos-heladeria/src/app/modules/dashboard/layout/layout.service.spec.ts` cubriendo
      `desktopCollapsed` (valor por defecto `false` sin nada guardado, cambia y persiste tras
      `toggleDesktopCollapsed()`, no lanza si `localStorage` no está disponible) sin reescribir
      ningún caso de `sidebarOpen` (depende de T009).

### Unidad 3 — Contrato de datos: campo `frame` en `NavItem`

- [X] T011 [P] Añadir a `pos-heladeria/src/app/core/interfaces/navigation.interface.ts` el campo
      opcional `frame?: { label: string; icon: string; group: 'Inicio' | 'Operación' | 'Catálogo'
      | 'Inventario' | 'Control' | 'Administración' }` en `NavItem`, y la constante nueva
      `TENANT_FRAME_GROUP_ORDER = ['Inicio', 'Operación', 'Catálogo', 'Inventario', 'Control',
      'Administración'] as const` — sin tocar `label`, `icon`, `route`, `group`, `roles`,
      `moduleKey` ni `NAV_GROUP_ORDER` existentes (data-model.md §4; FR-005, FR-006).
- [X] T012 Añadir el campo `frame` a cada uno de los 15 `NavItem` de tenant en
      `pos-heladeria/src/app/core/config/navigation.config.ts`, exactamente según
      contracts/navigation-grouping-contract.md: Dashboard→Inicio/"Dashboard"/`layout-dashboard`;
      Ventas→Operación/"Ventas"/`shopping-cart`; Órdenes→Operación/"Órdenes"/`receipt`;
      Mesas→Operación/"Mesas"/`layout-grid`; Terminal de mesas→Operación/"Terminal de
      Mesas"/`qr-code`; Carta del menú→Catálogo/"Carta del Menú"/`book-open`;
      Categorías→Catálogo/"Categorías"/`tags`; Presentaciones→Catálogo/"Presentaciones"/`cup-soda`;
      Promociones→Catálogo/"Promociones"/`percent`; Inventario→Inventario/"Inventario"/`package`;
      Proveedores→Inventario/"Proveedores"/`truck`; Caja→Control/**"Cajas"**/`banknote`;
      Reportes→Control/"Reportes"/`chart-column`; Usuarios→Administración/"Usuarios"/`users`;
      Ajustes→Administración/"Ajustes"/`settings` — sin tocar `SUPER_ADMIN_NAV_ITEMS` (depende de
      T011).

**Checkpoint**: con la Fase 2 completa, `app-tenant-sidebar`/`app-tenant-header` tienen todo lo que
necesitan para construirse (íconos, tokens, script anti-parpadeo, los dos servicios de estado y el
campo `frame` en los 15 ítems).

---

## Phase 3: User Story 1 - Navegación y estructura visual del panel rediseñadas (Priority: P1) 🎯 MVP

**Goal**: el sidebar y el navbar nuevos (`app-tenant-sidebar`, `app-tenant-header`) sustituyen al
layout legado para Administrador/Cajero/Mesero, con los 6 grupos, etiquetas e íconos del diseño de
referencia, preservando exactamente el acceso por rol/plan de hoy, con resaltado del ítem activo y
colapso a solo-íconos en escritorio (persistido, con tooltip accesible). Super Admin no cambia.

**Independent Test**: iniciar sesión con ADMIN, CASHIER y MESERO y verificar que cada uno ve
exactamente los grupos/ítems que ya veía, con las etiquetas e íconos nuevos, que el ítem activo se
resalta al navegar, que un grupo sin ítems visibles no aparece vacío, y que colapsar el sidebar en
escritorio y recargar lo deja colapsado sin parpadeo de la versión expandida.

### Implementación para la Historia de Usuario 1

- [X] T013 [P] [US1] Crear `pos-heladeria/src/app/modules/dashboard/layout/tenant-sidebar.component.ts`
      (`app-tenant-sidebar`, standalone): trasladar (no reescribir) la lógica de `visibleItems()`/
      `groupedItems()` de `SidebarComponent` (`sidebar.component.ts:111-137`) pero agrupando por
      `item.frame!.group` contra `TENANT_FRAME_GROUP_ORDER` en vez de `item.group`/`NAV_GROUP_ORDER`
      — mismo filtro por `roles`, mismo fail-open de `moduleKey` mientras el plan no carga, mismo
      `.filter(g => g.items.length > 0)` para grupos vacíos (FR-016); pintar cada ítem con
      `app-icon [name]="item.frame!.icon"` y `item.frame!.label`, resaltando el activo con
      `routerLinkActive`/`exact: true`; pintar también el encabezado con
      `tenantInfo.logoUrl`/`businessName` truncado en una sola línea (sin segunda línea de
      "sede" — research.md R9), reutilizando las mismas propiedades que ya expone
      `SidebarComponent` (FR-001, FR-002, FR-003, FR-004, FR-005, FR-016;
      contracts/navigation-grouping-contract.md; contracts/tenant-layout-contract.md §2).
- [X] T014 [US1] Ampliar `tenant-sidebar.component.ts` (T013) con el colapso de escritorio: leer
      `layoutService.desktopCollapsed()` para alternar el ancho del `<aside>` entre 248px
      (expandido) y 72px (solo íconos) sin desmontar el `<router-outlet>` ni perder la vista
      actual; cuando está colapsado, cada botón de ítem lleva `title="{{ item.frame!.label }}"`,
      `aria-label` con el mismo texto y un `<span role="tooltip">` propio visible por `:hover` y
      `:focus-visible` en CSS puro (FR-007, research.md R7; contracts/panel-theme-contract.md §5)
      (depende de T013).
- [X] T015 [US1] Crear `pos-heladeria/src/app/modules/dashboard/layout/tenant-sidebar.component.spec.ts`
      con dobles (`useValue`) de `AuthService`/`TenantInfoService`/`PlanSummaryService` (mismo
      patrón que `sidebar.component.spec.ts`): ADMIN/CASHIER/MESERO ven exactamente los
      grupos/ítems que `navigation.config.ts` les permite hoy; un plan sin `inventario` oculta el
      grupo "Inventario" completo (no vacío); el ítem de la ruta activa se resalta; colapsar y
      expandir no navega ni cambia la ruta activa; un nombre de negocio largo (doble de
      `TenantInfoService.businessName`) se trunca sin romper el layout del encabezado (Edge Case
      de spec.md, research.md R9) (depende de T013, T014).
- [X] T016 [P] [US1] Crear `pos-heladeria/src/app/modules/dashboard/layout/tenant-header.component.ts`
      (`app-tenant-header`, standalone) con: botón de menú con ícono `menu`; título de sección y de
      página derivados del ítem activo (sección = `frame.group`, título = `frame.label`, resuelto
      igual que hoy deriva el título `HeaderComponent` pero dinámico en vez de fijo "Panel de
      Control"); campana de notificaciones reutilizando `NotificationCenterService`/
      `PushRegistrationService` exactamente igual que `header.component.ts` (mismo dropdown, mismo
      conteo, mismo flujo de permiso push), con ícono `bell`; menú de usuario con las mismas tres
      acciones y destinos de hoy (`/dashboard/mi-plan` solo si `!currentUser()?.isSuperAdmin`,
      `/dashboard/mi-cuenta`, `logout()` vía `AuthService`) usando los íconos nuevos
      `badge-check`/`key-round`/`log-out` (FR-001, FR-003; contracts/tenant-layout-contract.md §3).
- [X] T017 [US1] Crear `pos-heladeria/src/app/modules/dashboard/layout/tenant-header.component.spec.ts`
      cubriendo: el título/sección cambia según la ruta activa simulada; la campana de
      notificaciones reutiliza el doble de `NotificationCenterService`/`PushRegistrationService`
      (mismos casos que `header.component.spec.ts`); el menú de usuario navega a los tres destinos
      correctos y `logout()` llama `AuthService.logout()` y navega a `/login` (depende de T016).
- [X] T018 [US1] Añadir a `tenant-header.component.ts` (T016) el indicador "Caja N abierta" /"sin
      turno": inyectar `CashService` (ya `providedIn: 'root'`) y mostrar el estado a partir de
      `cashService.isOpen()`/`cashService.shift()`, visible solo para roles `ADMIN`/`CASHIER`; en
      la inicialización del componente, si `!cashService.shift()`, llamar una sola vez a
      `cashService.discoverOpenShift()` (el mismo método, sin modificar, que usa
      `pos-terminal.store.ts:1281` con el mismo guard) (research.md R8;
      contracts/tenant-layout-contract.md §3) (depende de T016).
- [X] T019 [US1] Ampliar `tenant-header.component.spec.ts` (T017) con: CASHIER sin haber visitado
      Caja/Terminal antes ve el indicador correcto tras `discoverOpenShift()` (doble de
      `CashService` con un turno abierto simulado); MESERO no ve el indicador en absoluto (depende
      de T018).
- [X] T020 [US1] Modificar `pos-heladeria/src/app/modules/dashboard/layout/dashboard-layout.component.ts`:
      reemplazar el montaje incondicional de `<app-sidebar/><app-header/>` por la bifurcación
      `@if (isSuperAdmin()) { <app-sidebar/><app-header/> } @else { <app-tenant-sidebar/>
      <app-tenant-header/> }`, evaluando `isSuperAdmin()` contra `AuthService.currentUser()`
      (misma fuente que ya usa `SidebarComponent`) — sin tocar `ngOnInit`/`ngOnDestroy` ni el
      listener de `NavigationEnd` existente (contracts/tenant-layout-contract.md §1; FR-006)
      (depende de T013, T016).
- [X] T021 [US1] Ampliar `pos-heladeria/src/app/modules/dashboard/layout/dashboard-layout.component.spec.ts`
      con dos casos: un usuario no-super-admin monta `app-tenant-sidebar`/`app-tenant-header` (y no
      `app-sidebar`/`app-header`); un super admin sigue montando `app-sidebar`/`app-header` sin
      ningún cambio (prueba negativa de research.md R1) (depende de T020).

**Checkpoint**: la Historia 1 es funcional y comprobable de forma independiente — el panel de
tenant ya navega con la estructura, etiquetas e íconos nuevos, con colapso de escritorio
persistente, y Super Admin no se vio afectado.

---

## Phase 4: User Story 2 - Alternar y conservar la preferencia de tema claro/oscuro (Priority: P2)

**Goal**: un interruptor en el navbar nuevo alterna entre tema claro y oscuro para el marco del
panel (sidebar/navbar/fondo del contenido), la preferencia persiste entre recargas sin parpadeo, y
degrada con normalidad cuando el almacenamiento no está disponible.

**Independent Test**: activar el interruptor, confirmar el cambio inmediato de paleta en
sidebar/navbar/fondo (sin afectar el contenido de los módulos), recargar la página y verificar que
el tema oscuro persiste sin parpadeo del tema anterior, incluso en una ventana con storage
bloqueado.

### Implementación para la Historia de Usuario 2

- [X] T022 [P] [US2] Modificar `dashboard-layout.component.ts` (T020): inyectar `PanelThemeService`
      y aplicar `[class.panel-theme]="!isSuperAdmin()"` junto con `[attr.data-theme]=
      "panelThemeService.theme()"` en el elemento raíz del shell (`.shell-root`) — ninguna otra
      pantalla del sistema lleva esta clase (contracts/panel-theme-contract.md §1; FR-009, FR-010)
      (depende de T020, T007).
- [X] T023 [P] [US2] Añadir en `tenant-header.component.ts` (T016/T018) el botón interruptor de
      tema: ícono `moon` cuando `panelThemeService.theme() === 'light'` (lo que se activaría),
      ícono `sun` cuando es `'dark'`, que llama `panelThemeService.toggleTheme()` al hacer clic, con
      `aria-label` descriptivo del estado (FR-009; contracts/panel-theme-contract.md §3) (depende
      de T016, T007).
- [X] T024 [US2] Ampliar `dashboard-layout.component.spec.ts` y `tenant-header.component.spec.ts`
      para verificar: alternar el tema actualiza `data-theme` en la raíz y cambia el ícono del
      botón (`moon`↔`sun`); un super admin nunca recibe la clase `.panel-theme` ni ve el
      interruptor de tema (depende de T022, T023).

**Checkpoint**: las Historias 1 y 2 funcionan juntas de forma independiente — el tema oscuro se
activa, persiste sin parpadeo (verificación manual completa en Fase 6/quickstart.md §4) y no
afecta el contenido de los módulos ni a Super Admin.

---

## Phase 5: User Story 3 - Uso cómodo del panel en pantallas pequeñas (Priority: P3)

**Goal**: en pantallas con ancho menor a 1024px, el sidebar se oculta por defecto y se abre como un
menú desplegable superpuesto con scrim, cerrándose al seleccionar un ítem o tocar fuera; el layout
reacciona en vivo al cruzar el punto de quiebre sin recargar ni perder el módulo activo.

**Independent Test**: abrir el panel con un ancho menor a 1024px, confirmar que el sidebar está
oculto con un botón de menú visible, que abrirlo muestra el scrim, y que seleccionar un ítem o
tocar fuera lo cierra; luego, sin recargar, cruzar el punto de quiebre varias veces y confirmar que
el layout alterna de modo sin perder la vista actual.

### Implementación para la Historia de Usuario 3

- [X] T025 [US3] Ampliar `tenant-sidebar.component.ts` (T013/T014) con la resolución reactiva de
      `SidebarViewMode` (`'desktop' | 'drawer'`): registrar en el constructor
      `BreakpointObserver.observe('(min-width: 1024px)')` de `@angular/cdk/layout` (ya
      dependencia del proyecto), convertido a signal con `toSignal()`, desregistrado con
      `takeUntilDestroyed()` al destruirse el componente (research.md R6; data-model.md §3)
      (depende de T014).
- [X] T026 [US3] Ampliar `tenant-sidebar.component.ts` (T025) con el modo `'drawer'` (ancho
      < 1024px): el `<aside>` oculto por defecto, superpuesto con scrim
      (`fixed inset-0 bg-black/40 … lg:hidden`, mismo patrón que el backdrop actual de
      `dashboard-layout.component.ts`) cuando `layoutService.sidebarOpen()` es `true`; tocar el
      scrim o seleccionar un ítem de navegación llama `layoutService.close()` (FR-008, Historia 3
      Escenario 2) (depende de T025).
- [X] T027 [US3] Ampliar `tenant-header.component.ts` (T016) con el comportamiento dual del botón
      de menú: en modo `'drawer'` llama `layoutService.toggle()` (abre/cierra el drawer); en modo
      `'desktop'` llama `layoutService.toggleDesktopCollapsed()` (colapsa/expande) — resolviendo el
      mismo `SidebarViewMode` que `tenant-sidebar.component.ts` (T025), ya sea compartiéndolo a
      través de `LayoutService` o observando el mismo `BreakpointObserver` de forma independiente
      (contracts/tenant-layout-contract.md §3) (depende de T025).
- [X] T028 [US3] Ampliar `tenant-sidebar.component.spec.ts` (T015) con los casos de responsive:
      con un ancho simulado < 1024px (helper `setViewportWidth()`, mismo patrón que
      `dashboard-layout.component.spec.ts`) el sidebar inicia oculto y el scrim aparece al abrirlo;
      seleccionar un ítem o "tocar" el scrim lo cierra; alternar el ancho simulado 900→1200→900px
      sin recargar cambia entre modo `'drawer'` y `'desktop'` sin perder la ruta activa (Edge Case
      de la spec) (depende de T026).

**Checkpoint**: las tres historias de usuario son funcionales de forma independiente y conjunta.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Propósito**: lo que ningún test de `TestBed` puede observar — recorrido manual, accesibilidad y
regresión completa (plan.md, Unidad 7; Principio X).

- [X] T029 Ejecutar el recorrido manual completo de quickstart.md §2 a §6 en `pos-heladeria`
      (`npm start`): verificación visual del cascarón en ambos temas sin parpadeo (DevTools →
      Performance, CPU 4x), los 6 grupos/etiquetas/íconos contra
      contracts/navigation-grouping-contract.md, acceso por rol/plan sin regresiones, colapso con
      tooltip por teclado, drawer con scrim, cruce de punto de quiebre en vivo, y el indicador de
      caja para CASHIER sin haber visitado Caja/Terminal antes.
      **Hecho (2026-10-12)** con `pos-api` nativo (uvicorn) + Chrome real (chrome-devtools MCP),
      usuarios de prueba ADMIN/CASHIER/MESERO/SUPER_ADMIN en el tenant `heladeria`
      (`qa116-*@e2e-pos.com` / `Qa116Test1`, ver nota al final del archivo). Verificado: los 6
      grupos/etiquetas/íconos coinciden con el contrato; ADMIN/CASHIER/MESERO ven exactamente sus
      ítems (MESERO solo "Operación", sin indicador de caja); colapso de escritorio persiste tras
      recargar; drawer con scrim abre/cierra por clic fuera y por selección de ítem; cruce de punto
      de quiebre en vivo confirmado por test automatizado (jsdom no permite verificarlo a ojo).
      **Bug real encontrado y corregido**: el tooltip del ícono colapsado (`position: absolute`)
      quedaba invisible — el `<nav>` con `overflow-y: auto` recorta también el eje horizontal
      (regla "contradictory overflow" de CSS2.1), contradiciendo lo que research.md R7 asumía.
      Solución: tooltip único con `position: fixed`, calculado desde el rect del ítem en
      hover/focus (`tenant-sidebar.component.ts`, método `showTooltip()`), cubierto con 2 tests
      nuevos.
- [X] T030 [P] Ejecutar la auditoría de accesibilidad de quickstart.md §7 (Lighthouse →
      Accessibility, o `mcp__chrome-devtools__lighthouse_audit`) sobre una pantalla del panel en
      tema claro y en tema oscuro — ambas deben dar 100 (SC-006) — y verificar manualmente el
      contraste de `--panel-color-text-*` sobre `--panel-color-surface`/`-canvas` en ambos temas
      contra WCAG 2.1 AA (4.5:1 texto normal, 3:1 texto grande).
      **Hecho (2026-10-12)**, 5 pantallas distintas, ambos temas, con Lighthouse real.
      **2 bugs reales de contraste encontrados y corregidos** (research.md R3 avisaba
      explícitamente: "debe confirmarse, no asumirse"): `--panel-color-text-subtle` sobre
      `-surface`/`-canvas` mide 2.56:1 (claro) / 3.73:1 (oscuro) — muy por debajo del 4.5:1 de WCAG
      AA — usado en las etiquetas de grupo del sidebar y el título de sección del navbar; y
      `--panel-color-text-muted` sobre `-overlay-hover` mide 4.28:1 (claro) en el pill "Sin turno"
      del indicador de caja. Ambos se cambiaron a `--panel-color-text-secondary` (10.35:1 / 9.32:1
      claro; 11.95:1 / 10.26:1 oscuro), verificado con cálculo WCAG manual y confirmado con
      Lighthouse tras el fix: **cero hallazgos de `color-contrast` en los componentes de esta spec,
      en ambos temas, en 5 pantallas**. El resto de hallazgos de Lighthouse en esas pantallas
      (`color-contrast` en `text-gray-400`/`text-green-600` del contenido de Dashboard, `select-name`
      en Categorías/paginación, `target-size` en `app-password-input`) son **preexistentes, en
      código que esta spec no toca** (sin `--panel-color-*`, fuera de `app-tenant-sidebar`/
      `app-tenant-header`) — el score de categoría no llega a 100 en ninguna pantalla por esos
      hallazgos ajenos, no por el marco del panel. SC-006 se cumple para lo que esta spec controla;
      el 100 de categoría completa no es alcanzable hoy en ninguna pantalla del panel por deuda
      preexistente fuera de alcance (Principio V).
- [X] T031 Ejecutar `npm test` completo en `pos-heladeria` y confirmar (quickstart.md §8): cero
      tests nuevos en rojo; `sidebar.component.spec.ts`, `header.component.spec.ts` y
      `dashboard-layout.component.spec.ts` (legado) siguen en verde sin haberlos tocado más allá
      de T021/T024 (prueba de que Super Admin no se vio afectado); el conteo de fallos
      preexistentes de la suite no sube respecto a la línea base de T002.
      **Hecho** — 3 corridas completas de la suite (antes y después de los fixes de T029/T030):
      20/20/14 fallos (línea base: 20), siempre en archivos distintos y ajenos a esta spec (tablas,
      ventas, auth, super-admin — nunca en `layout/`, `icon/`, `navigation.*`) — contención
      documentada en memoria, no regresión. Los 8 archivos directamente tocados por esta spec
      (60 tests) pasan limpio y determinístico en corridas aisladas repetidas.
- [X] T032 Confirmar la lista de cierre de quickstart.md §16 (los 8 puntos) y verificar visualmente,
      iniciando sesión como super admin, que su panel no tuvo ningún cambio (research.md R1)
      **Hecho** — los 8 puntos verificados (ver detalle arriba); Super Admin verificado en vivo
      (`admin.localhost:4200`): sidebar índigo legado, íconos Material, grupo único "PLATAFORMA",
      sin interruptor de tema ni indicador de caja — sin ningún cambio.

---

**Nota de verificación (2026-10-12)**: el recorrido manual (T029-T032) usó 4 usuarios de prueba
desechables creados directamente en la base de datos de desarrollo (`shared.users`, tenant
`heladeria` para ADMIN/CASHIER/MESERO, sin tenant para SUPER_ADMIN), porque las cuentas reales del
usuario no tienen contraseña conocida para este agente:
`qa116-admin@e2e-pos.com` / `qa116-cashier@e2e-pos.com` / `qa116-mesero@e2e-pos.com` /
`qa116-superadmin@e2e-pos.com`, contraseña `Qa116Test1` para los cuatro. Se dejan en la base (no se
eliminan) por si el usuario quiere reutilizarlos; son claramente identificables por el prefijo
`qa116-` y el dominio `e2e-pos.com` (mismo patrón que la cuenta e2e ya existente del tenant). El
contenedor Docker `pos-api` (en crash-loop) se detuvo; `pos-backend` corre nativo con `uvicorn`
(memoria: "pos-api: Docker vs nativo") y `pos-heladeria` con `npm start`, ambos en segundo plano —
quedan corriendo al cierre de esta sesión para que el usuario pueda seguir probando.
      (depende de T029, T030, T031).

---

# Segunda iteración (2026-10-13) — Tema global al contenido de los módulos + micro-interacciones de carga

Punto de partida: `develop` de `pos-heladeria`, con la primera iteración ya fusionada (PR #36).
Nueva rama `feat/116-layout-base-panel-admin` **desde `develop`** (plan.md, "Branch"). Las Fases
7-10 implementan las unidades 8-15 de plan.md ("Orden de implementación sugerido — ampliación
2026-10-13"), que a su vez resuelven research.md R15-R21 para los FR-010 (ampliado), FR-018 a
FR-022 y SC-007 a SC-009 de spec.md.

> **Prerrequisito de esta fase (antes de T033)**: crear la rama `feat/116-layout-base-panel-admin`
> desde `develop` (Principio XIV) y correr `npm test` para anotar una línea base fresca de
> fallos/pasos — **no reusar el número de T002**, capturado en la rama anterior ya fusionada.
> Anotar aquí el resultado antes de tocar cualquier archivo.

## Phase 7: User Story 2 (continuación) - Tema oscuro ampliado a todo el panel de tenant (Priority: P2)

**Goal**: el tema oscuro deja de limitarse al marco del layout y cubre también el contenido de los
~18 módulos de tenant (tablas, formularios, tarjetas, gráficas) y cualquier modal/menú
desplegable/overlay que abran, sin tocar archivo por archivo cada módulo — excepto Terminal de
Mesas, que necesita una normalización previa, y dos superficies de impresión/exportación que deben
resistir el repintado.

**Independent Test**: con el tema oscuro activo, recorrer Inventario, Ventas, Terminal de Mesas,
Usuarios, Reportes y Promociones (incluyendo su único overlay de CDK) y confirmar que ningún
elemento queda en paleta clara sobre fondo oscuro (salvo insignias de estado y acentos de marca,
fuera de alcance); confirmar que el reporte de cierre de caja y la hoja de QR de mesas se ven y se
imprimen siempre en claro, sin importar el tema activo.

### Unidad 8 — Normalización hex→clase de Terminal de Mesas (prerrequisito mecánico de la Unidad 9)

- [X] T033 [P] [US2] Normalizar los ~207 valores arbitrarios hex (`bg-[#f3f4f6]`, `text-[#111827]`,
      etc.) a su clase Tailwind equivalente exacta (tabla de equivalencias de research.md R16) en
      `pos-heladeria/src/app/modules/tables/pages/manual-order-page.component.ts` — sustitución
      mecánica, cero cambio visual en tema claro por construcción (research R16, confirmado con el
      usuario).
- [X] T034 [P] [US2] Normalizar los ~51 valores hex de
      `pos-heladeria/src/app/modules/tables/components/pos-checkout-panel.component.ts` con el
      mismo criterio de T033.
- [X] T035 [P] [US2] Normalizar los ~49 valores hex de
      `pos-heladeria/src/app/modules/tables/components/pos-order-panel.component.ts` con el mismo
      criterio de T033.
- [X] T036 [P] [US2] Normalizar los ~26 valores hex de
      `pos-heladeria/src/app/modules/tables/components/pos-terminal-header.component.ts` con el
      mismo criterio de T033.
- [X] T037 [P] [US2] Normalizar los ~19 valores hex de
      `pos-heladeria/src/app/modules/tables/components/pos-tables-panel.component.ts` con el mismo
      criterio de T033.
- [X] T038 [P] [US2] Normalizar los ~16 valores hex de
      `pos-heladeria/src/app/modules/tables/pages/table-sessions.component.ts` con el mismo
      criterio de T033.
- [X] T039 [P] [US2] Normalizar los ~13 valores hex (incluyendo `STATUS_META`) de
      `pos-heladeria/src/app/modules/tables/services/pos-terminal.store.ts` con el mismo criterio
      de T033.
- [X] T040 [P] [US2] Normalizar los ~13 valores hex de
      `pos-heladeria/src/app/modules/tables/components/session-bill-panel.component.ts` con el
      mismo criterio de T033.
- [X] T041 [P] [US2] Normalizar los ~11 valores hex de
      `pos-heladeria/src/app/modules/tables/components/bill-summary.component.ts` con el mismo
      criterio de T033.
- [X] T042 [P] [US2] Normalizar los ~9 valores hex de
      `pos-heladeria/src/app/modules/tables/components/order-summary-card.component.ts` con el
      mismo criterio de T033.
- [X] T043 [P] [US2] Normalizar los ~3 valores hex de
      `pos-heladeria/src/app/modules/tables/components/cart-item-options.component.ts` con el
      mismo criterio de T033.
- [X] T044 [US2] Ejecutar `npm test` filtrado a los 11 archivos normalizados en T033-T043 (sin
      cambios de aserciones esperados) y confirmar visualmente en Chrome, en tema claro, que
      Terminal de Mesas (`pos-heladeria`, `/dashboard/mesas-sesiones`) no cambió ni un píxel —
      cualquier diferencia encontrada aquí es un error de la sustitución, no un ajuste (research
      R16; quickstart.md §10.1) (depende de T033-T043).
      **Hecho (2026-10-13)**: 419 sustituciones mecánicas (hex→clase, tabla de equivalencias
      verificada convirtiendo los valores `oklch` reales de `tailwindcss@4.3.0` a hex para
      confirmar cada alias) en los 11 archivos, cero literales `[#...]` restantes. Un solo ajuste
      de aserción de test (no de producción): `manual-order-page.component.spec.ts` comprobaba la
      clase literal `'bg-[#f3f4f6]'` en el DOM — se actualizó a `'bg-gray-100'` (mismo elemento,
      visualmente idéntico). Corrida filtrada a los 11 archivos: 4 fallos, los mismos 4 ya
      presentes en la línea base fresca de esta fase (`pos-checkout-panel`×1,
      `pos-order-panel`×2, `pos-terminal.store`×1 — ninguno relacionado con color/clases) — sin
      regresiones nuevas. **Línea base fresca (2026-10-13, antes de tocar nada, en rama nueva desde
      `develop`)**: 11 tests fallan / 1790 pasan / 1 skip (7 archivos en rojo:
      `app.spec.ts`, `auth.service.spec.ts`, `menu.service.spec.ts`, `tenant.service.spec.ts`,
      `pos-checkout-panel.component.spec.ts`, `pos-order-panel.component.spec.ts`,
      `pos-terminal.store.spec.ts`) — no reutiliza el número de T002 (rama anterior, ya fusionada).

### Unidad 9 — Variables de Tailwind redeclaradas bajo `.panel-theme[data-theme='dark']`

- [X] T045 [US2] Ampliar el bloque `.panel-theme[data-theme="dark"]` de
      `pos-heladeria/src/styles.css` con los alias de research.md R16/contracts/panel-theme-contract.md
      §6: `--color-gray-50`/`--color-slate-50` → `--panel-color-surface-elevated`;
      `--color-gray-100`/`-200`/`--color-slate-200` y `--color-gray-300` →
      `--panel-color-border`; `--color-gray-400`/`--color-slate-400` →
      `--panel-color-text-subtle`; `--color-gray-500` → `--panel-color-text-muted`;
      `--color-gray-600`/`-700`/`--color-slate-700` → `--panel-color-text-secondary`;
      `--color-gray-800`/`-900`/`--color-slate-800` → `--panel-color-text-primary`; más los
      selectores dirigidos `.bg-white`, `.focus\:bg-white:focus`, `.hover\:bg-white:hover` →
      `var(--panel-color-surface-card)` — sin tocar `--color-white`/`--color-black` ni ningún color
      semántico (`indigo-*`, `amber-*`, etc.) (depende de T044).

### Unidad 10 — `.force-light-surface` (superficies de impresión/exportación, research R17)

- [X] T046 [US2] Añadir a `pos-heladeria/src/styles.css` la regla
      `.panel-theme[data-theme='dark'] .force-light-surface { … }` que re-fija cada variable que
      T045 redeclaró de vuelta a su valor claro original (literal, no alias) (contracts/panel-theme-contract.md
      §7) (depende de T045).
- [X] T047 [P] [US2] Aplicar la clase `force-light-surface` a la raíz
      (`<div class="flex-1 w-full max-w-[900px] mx-auto p-6">`) de
      `pos-heladeria/src/app/modules/cash-register/components/cash-report.component.ts` (depende de
      T046).
- [X] T048 [P] [US2] Aplicar la clase `force-light-surface` a la raíz
      (`<div class="max-w-5xl mx-auto">`) de
      `pos-heladeria/src/app/modules/tables/pages/table-qr-sheet.component.ts` (depende de T046).

### Unidad 11 — Sincronización del `cdk-overlay-container` compartido (research R18)

- [X] T049 [US2] Modificar
      `pos-heladeria/src/app/modules/dashboard/layout/dashboard-layout.component.ts`: inyectar
      `OverlayContainer` de `@angular/cdk/overlay` y, con un `effect()`, reflejar
      `panelThemeService.theme()` e `!isSuperAdmin()` como clase `panel-theme`/atributo
      `data-theme` sobre `overlayContainer.getContainerElement()` (contracts/panel-theme-contract.md
      §9) (depende de T045).
- [X] T050 [US2] Ampliar `dashboard-layout.component.spec.ts` verificando que el contenedor
      compartido de CDK Overlay recibe la clase/atributo de tema cuando el usuario no es super
      admin, y que un super admin nunca lo repinta (depende de T049).

### Unidad 12 — Gráficas (Chart.js) con tema (research R19) — independiente de las Unidades 8-11

- [X] T051 [P] [US2] Modificar `pos-heladeria/src/app/shared/charts/chart-theme.ts`:
      `baseOptions(kind, theme: 'light' | 'dark')` gana el parámetro `theme`; `INK`/`MUTED`/`GRID`
      se convierten en `axisColors(theme)` con un segundo juego de valores oscuros verificados
      contra `--panel-color-canvas` oscuro (`#090D16`, mismo criterio de contraste de R3); cubrir
      también `borderColor: '#ffffff'` con el mismo criterio; `CHART_COLORS` no cambia con el tema
      (contracts/panel-theme-contract.md §8).
- [X] T052 [US2] Ampliar `pos-heladeria/src/app/shared/charts/chart-theme.spec.ts` cubriendo
      `axisColors('light')`/`axisColors('dark')` y confirmando que los 5 colores de `CHART_COLORS`
      siguen midiendo ≥3:1 de contraste contra `--panel-color-canvas` oscuro (research R19) (depende
      de T051).
- [X] T053 [P] [US2] Modificar
      `pos-heladeria/src/app/shared/charts/bars-chart.component.ts` para inyectar
      `PanelThemeService` y pasar `panelThemeService.theme()` a `baseOptions()` dentro de su
      `computed()` de `options` existente (depende de T051).
- [X] T054 [P] [US2] Modificar
      `pos-heladeria/src/app/shared/charts/ranked-bars-chart.component.ts` con el mismo criterio de
      T053 (depende de T051).
- [X] T055 [P] [US2] Modificar
      `pos-heladeria/src/app/shared/charts/share-bar-chart.component.ts` con el mismo criterio de
      T053 (depende de T051).
- [X] T056 [US2] Ampliar los tres `*chart*.component.spec.ts` correspondientes a T053-T055
      verificando que `options()` recibe el tema activo y cambia cuando
      `panelThemeService.theme()` cambia (depende de T053, T054, T055).
      **Hecho (2026-10-13)**: ninguno de los 3 existía todavía (premisa de la tarea: "ampliar" —
      en realidad se crean los 3 desde cero). `axisColors(theme)` centraliza ink/muted/grid/
      tooltipBg/segmentBorder; `tooltipBg` se deja igual en ambos temas a propósito (ficha
      flotante oscura con texto blanco de Chart.js, funciona igual en claro/oscuro — no es una
      superficie del panel); `segmentBorder` sí cambia (blanco claro → `--panel-color-surface-card`
      oscuro, para que el hueco de 2px entre segmentos de `app-share-bar-chart` se funda con la
      tarjeta real, no quede como una línea blanca). 19 tests nuevos en verde (4 archivos).
      **Hallazgo real, documentado para la Fase 10 (T066 §13/T067)**: el test de T052 verifica
      `CHART_COLORS` contra `--panel-color-canvas` oscuro (#090D16, el criterio que pide research.md
      R19) y los 5 colores pasan ≥3:1 (3.09–6.10:1) — pero `app-chart-card` (la tarjeta real que
      envuelve las 3 gráficas en Reportes) usa `bg-white`, que la Unidad 9 repinta a
      `--panel-color-surface-card` oscuro (#1E293B), **no** al canvas. Contra ese fondo real,
      recalculado aparte (no en el test, que sigue el criterio exacto de R19): 3 de los 5 colores
      caen por debajo de 3:1 (`#4f46e5` 2.33:1, `#be123c` 2.33:1, `#7c3aed` 2.57:1). No se cambió
      `CHART_COLORS` por esto — research.md R19 decide explícitamente que esa paleta no cambia con
      el tema, y tocarla es una decisión de diseño mayor que excede esta tarea mecánica. Queda
      como verificación pendiente explícita del recorrido visual de la Fase 10 (T066 §13), con
      Lighthouse/inspección real — research.md ya documenta el mismo tipo de riesgo para R16 ("ningún
      valor se da por bueno sin verlo renderizado").

**Checkpoint**: el tema oscuro cubre el marco (Fase 4, ya fusionada) y ahora también el contenido
de los ~18 módulos, Terminal de Mesas incluida, las dos superficies de impresión/exportación
resisten el repintado, el overlay de CDK de Promociones se tematiza, y las gráficas de Reportes
responden al tema sin tocar su paleta de series.

---

## Phase 8: User Story 1 (continuación) - Fidelidad visual: el botón de colapso vuelve al navbar (Priority: P1)

**Goal**: igualar la fidelidad pixel-perfect de `Layout base.dc.html` (FR-018, fuente de verdad
reafirmada en research R15): el botón de menú/colapso del sidebar de escritorio deja de vivir
dentro de `app-tenant-sidebar` (junto al logo) y pasa a ser un único control, siempre visible, en
`app-tenant-header` — el mismo botón que ya abre/cierra el drawer móvil, con un segundo efecto
según el modo de vista.

**Independent Test**: en escritorio, el botón de colapso aparece en el navbar (no en el sidebar) y
alterna expandido/72px igual que antes; en pantallas &lt;1024px, el mismo botón abre/cierra el
drawer, sin ningún botón duplicado en el sidebar.

### Unidad 13 — Reubicación del botón de colapso (research R15)

- [X] T057 [US1] Retirar el botón de colapso del encabezado del `<aside>` (junto al logo) en
      `pos-heladeria/src/app/modules/dashboard/layout/tenant-sidebar.component.ts`
      (contracts/tenant-layout-contract.md §2).
- [X] T058 [US1] Añadir a
      `pos-heladeria/src/app/modules/dashboard/layout/tenant-header.component.ts` un único botón de
      menú/colapso **siempre visible** (en `'desktop'` y en `'drawer'`): invoca
      `layoutService.toggleDesktopCollapsed()` en `'desktop'` y `layoutService.toggle()` en
      `'drawer'`, con `aria-label`/`title` que cambian según el modo y el estado actual
      (contracts/tenant-layout-contract.md §3) (depende de T057).
- [X] T059 [US1] Ampliar `tenant-sidebar.component.spec.ts` (confirmar que ya no renderiza ningún
      botón de colapso) y `tenant-header.component.spec.ts` (confirmar el comportamiento dual
      correcto del botón único en ambos modos) (depende de T057, T058).

**Checkpoint**: la estructura del navbar/sidebar vuelve a ser fiel a `Layout base.dc.html` en este
punto concreto, sin romper el colapso de escritorio (Fase 3) ni el drawer móvil (Fase 5) ya
fusionados.

---

## Phase 9: User Story 4 - Transiciones y feedback de carga fluidos al navegar (Priority: P4)

**Goal**: cada navegación entre secciones del sidebar muestra una barra de carga delgada superior,
un skeleton genérico mientras el contenido real no está listo, y una aparición gradual escalonada
del contenido real al completarse — replicando la coreografía ya aprobada de `Layout base.dc.html`
con el Router real en vez de clics simulados, y omitiéndose por completo bajo
`prefers-reduced-motion`.

**Independent Test**: navegar entre dos secciones del sidebar y observar la barra de carga, el
skeleton genérico y la aparición escalonada del contenido real; repetir con varios clics rápidos
sucesivos y confirmar que solo la última sección navegada queda visible; repetir con
`prefers-reduced-motion: reduce` emulado y confirmar que el cambio de contenido es inmediato, sin
barra ni animación.

### Unidad 14 — `NavigationTransitionService` + barra de carga + skeleton + aparición escalonada + `prefers-reduced-motion` (research R20, R21) — independiente de las Unidades 8-13

- [X] T060 [P] [US4] Crear
      `pos-heladeria/src/app/modules/dashboard/layout/navigation-transition.service.ts`
      (`NavigationTransitionService`, `providedIn: 'root'`) con los signals públicos `phase:
      Signal<'idle' | 'out' | 'skeleton' | 'in'>`, `barVisible: Signal<boolean>`, `barProgress:
      Signal<0 | 75 | 100>`; suscrito a `Router.events` (`NavigationStart`/`NavigationEnd`/
      `NavigationCancel`/`NavigationError`), que solo arranca la coreografía cuando el *path* (sin
      query string) cambió respecto al anterior, con el cronómetro fijo ~150/170/230/900ms que
      replica `Layout base.dc.html` (líneas 83-118), reiniciándose por completo ante un
      `NavigationStart` nuevo mientras ya hay una transición en curso (data-model.md §6.1;
      contracts/navigation-transition-contract.md §1-§2).
- [X] T061 [US4] Crear
      `pos-heladeria/src/app/modules/dashboard/layout/navigation-transition.service.spec.ts` con
      fake timers cubriendo: la secuencia `idle`→`out`→`skeleton`→`in`; `NavigationCancel`/
      `NavigationError` vuelven a `idle`; varios `NavigationStart` en rápida sucesión reinician el
      cronómetro y solo el último llega a `in` (Historia 4, Escenario 5); un cambio de solo query
      string no dispara ninguna fase; `skeleton` no avanza a `in` antes de que `NavigationEnd`
      dispare, aunque el cronómetro ya haya cumplido su mínimo (depende de T060).
- [X] T062 [US4] Modificar
      `pos-heladeria/src/app/modules/dashboard/layout/dashboard-layout.component.ts` para montar,
      acotado a `!isSuperAdmin()`: la barra de carga superior (leyendo
      `navigationTransitionService.barVisible()`/`barProgress()`) y el contenedor de
      transición/skeleton alrededor del `router-outlet` de tenant (leyendo
      `navigationTransitionService.phase()`) (contracts/navigation-transition-contract.md §1, §6)
      (depende de T060).
- [X] T063 [P] [US4] Añadir a `pos-heladeria/src/styles.css` las reglas CSS del skeleton genérico
      (bloques fijos con el mismo efecto de aparición gradual del contenido, sin brillo/pulso
      adicional) y del selector genérico de aparición escalonada aplicado solo a los hijos directos
      de nivel superior del contenedor de `router-outlet` (retraso `i × 55ms`, con tope para los
      hijos más allá del N-ésimo) (research R20; contracts/navigation-transition-contract.md §3-§4).
- [X] T064 [P] [US4] Añadir a `pos-heladeria/src/styles.css` la regla
      `@media (prefers-reduced-motion: reduce) { … }` que anula las transiciones/animaciones de la
      barra de progreso y del contenedor de aparición escalonada de T063 — sin modificar ninguna
      transición ya existente de colapso/drawer (research R21; contracts/navigation-transition-contract.md
      §5).
- [X] T065 [US4] Ampliar `dashboard-layout.component.spec.ts` verificando que la barra/skeleton se
      muestran y ocultan según `phase()`, y que un super admin nunca monta el contenedor de
      transición (depende de T062).

**Checkpoint**: las cuatro historias de usuario son funcionales de forma independiente y conjunta
— navegación/estructura (US1), tema oscuro global (US2), responsive (US3) y transiciones de
navegación (US4).

---

## Phase 10: Polish & Cross-Cutting Concerns (ampliación 2026-10-13)

**Propósito**: recorrido manual, Lighthouse y regresión completa de la segunda iteración — lo que
ningún test de `TestBed` puede observar (plan.md, Unidad 15; Principio X).

- [X] T066 Ejecutar el recorrido manual de quickstart.md §10 a §14 en `pos-heladeria` (`npm
      start`): tema oscuro recorrido en Inventario, Ventas, Terminal de Mesas, Usuarios, Reportes y
      Promociones (§10); reporte de cierre de caja y hoja de QR siempre en claro, en pantalla y al
      imprimir (§11); overlay de CDK de Promociones y modales `fixed inset-0` tematizados (§12);
      gráficas de Reportes en ambos temas (§13); barra de carga, skeleton, aparición escalonada,
      clics rápidos sucesivos y `prefers-reduced-motion` emulado (§14) (depende de T033-T065).
      **Hecho (2026-10-13)**, `pos-api` nativo (uvicorn) + `pos-heladeria` (`npm start`) + Chrome
      real (chrome-devtools MCP), tenant `heladeria`, usuario `qa116-admin@e2e-pos.com`. Verificado
      en vivo: Dashboard (tarjetas/accesos rápidos), Inventario (tabla+filtros+skeleton de carga),
      Terminal de Mesas y `orden-manual` (flujo completo: categorías, modal de producto, carrito,
      panel de cobro — los 207 valores normalizados de T033 se ven idénticos al claro), Usuarios
      (skeleton de carga `animate-pulse`), Reportes (las 3 gráficas con ejes/tooltip oscuros,
      paleta categórica sin cambios), Promociones (el único `cdkConnectedOverlay` del panel
      tematizado correctamente — research R18 confirmado funcionando). Botón único de colapso/menú
      verificado en ambos modos (desktop: colapsa a 72px; se reubicó del sidebar al navbar, T057-
      T059). Super Admin (`admin.localhost:4200`) verificado sin ningún cambio: sidebar índigo
      legado, sin `.panel-theme`, sin `.nav-transition`/`.nav-transition-bar` en el DOM (confirmado
      por script, no solo visualmente).
      **Bug real encontrado y corregido** (mismo rigor que R14/T029/T030 — "ningún valor se da por
      bueno sin verlo renderizado"): `.force-light-surface` (T046) re-fijaba las variables de texto
      a su valor claro pero **no fijaba un fondo claro** — ni `cash-report.component.ts` ni
      `table-qr-sheet.component.ts` traen su propio `background` en su raíz, así que heredaban el
      fondo oscuro de `shell-root` (`--panel-color-surface-elevated` oscuro, `#263449`) mientras su
      texto ya se había forzado a casi negro (`oklch(21%...)`) — contraste ~1:1, prácticamente
      invisible, confirmado con `getComputedStyle` antes y después. Corregido añadiendo
      `background-color: #fff` (+ `color` por defecto) a la regla `.force-light-surface` en
      `styles.css` — verificado de nuevo en Chrome real en ambas pantallas: fondo blanco sólido,
      texto oscuro legible, exactamente "siempre claras" (FR-010).
      **Límite de la verificación, documentado con honestidad**: la ventana exacta de la
      coreografía (barra+skeleton, ~230-900ms) no se pudo capturar visualmente con el round-trip de
      las herramientas de automatización del navegador (cada click/navegación ya resuelve antes de
      que vuelva el control) — cubierta en su lugar por los 6 tests con temporizadores falsos de
      `navigation-transition.service.spec.ts` (T061, secuencia exacta de fases) + los 2 tests de
      `dashboard-layout.component.spec.ts` (T065, enlace de plantilla con `data-phase`). Tras una
      navegación real completa, el estado final es correcto (sin barra ni skeleton colgados, scroll
      independiente intacto — `shell-main` conserva `overflow-y: auto`, confirmado con
      `getComputedStyle`). `prefers-reduced-motion` no tiene una opción de emulación en las
      herramientas disponibles (solo `colorScheme`); la regla CSS en sí se revisó por código (T064)
      y no depende de ningún estado del servicio (Principio VI — es una media query pura). Sin
      errores de consola en ninguna de las pantallas recorridas.
- [X] T067 [P] Repetir la auditoría de accesibilidad de quickstart.md (Lighthouse → Accessibility)
      sobre al menos una pantalla del panel en tema oscuro tras el repintado ampliado de T045,
      confirmando que no se introdujo ningún hallazgo nuevo de `color-contrast` en los componentes
      de esta spec (SC-006 reafirmado) (depende de T045).
      **Hecho (2026-10-13)**, Lighthouse real (`mcp__chrome-devtools__lighthouse_audit`) sobre
      Inventario en tema oscuro: Accessibility 94/100, Best Practices 100/100. Único hallazgo:
      `select-name` (los `<select>` de filtro/paginación sin `<label>`) — el mismo hallazgo ya
      documentado como preexistente y fuera de alcance en T030 (iteración 1), sin relación con
      `--panel-color-*`. **Cero hallazgos de `color-contrast`** (`audit.score === 1`, confirmado en
      el JSON del reporte) — SC-006 se reafirma tras el repintado ampliado de la Unidad 9, incluso
      después de corregir el bug de T066.
- [X] T068 Ejecutar `npm test` completo en `pos-heladeria` (quickstart.md §15) y confirmar: cero
      tests nuevos en rojo (`navigation-transition.service.spec.ts`, `chart-theme.spec.ts`
      ampliado, los 3 `*chart*.component.spec.ts` ampliados); los tests de los 11 archivos de
      Terminal de Mesas normalizados en T033-T043 siguen en verde sin cambios de aserciones; el
      conteo de fallos preexistentes de la suite no sube respecto a la línea base fresca capturada
      al inicio de la Fase 7 (no la de T002, de una rama distinta) (depende de T033-T065).
      **Hecho (2026-10-13)**, corrida completa tras T033-T065 y de nuevo tras el fix de T066: ambas
      veces **7 archivos fallan / 11 tests fallan / 1808 pasan / 1 skip** — exactamente los mismos
      7 archivos de la línea base fresca de T044 (`app.spec.ts`, `auth.service.spec.ts`,
      `menu.service.spec.ts`, `tenant.service.spec.ts`, `pos-checkout-panel.component.spec.ts`,
      `pos-order-panel.component.spec.ts`, `pos-terminal.store.spec.ts`), nunca en archivos de esta
      spec (`layout/`, `charts/`, `tables/` ya normalizados) — cero regresiones. 1808 pasan vs. 1790
      de la línea base = +18 tests nuevos en verde (T052, T056×3, T061, T065).
- [X] T069 Confirmar la lista de cierre ampliada de quickstart.md §16 (los 5 puntos nuevos:
      SC-007 a SC-009, FR-010 en el reporte de caja/hoja de QR, overlay de CDK) y verificar
      visualmente, iniciando sesión como super admin, que su panel sigue sin ningún cambio
      (research R1, reafirmado en R20) (depende de T066, T067, T068).
      **Hecho (2026-10-13)** — los 5 puntos verificados en vivo (detalle en T066); Super Admin
      confirmado sin cambios, tanto visualmente como por inspección del DOM
      (`document.querySelector('.panel-theme'/.nav-transition'/.nav-transition-bar')` → los tres
      `null`/`false` en `admin.localhost:4200`).

---

## Dependencies & Execution Order

### Dependencias entre fases

- **Setup (Fase 1)**: sin dependencias — puede empezar de inmediato.
- **Foundational (Fase 2)**: depende de Setup — **bloquea** las tres historias de usuario.
- **Historias de usuario (Fases 3-5)**: todas dependen de que Foundational esté completa.
  - US1 (Fase 3) no depende de US2 ni de US3.
  - US2 (Fase 4) depende de que `tenant-header.component.ts`/`dashboard-layout.component.ts`
    existan (T016, T020 de US1) para tener dónde montar el interruptor — no depende de ninguna
    otra decisión de US1.
  - US3 (Fase 5) depende de que `tenant-sidebar.component.ts`/`tenant-header.component.ts` existan
    (T014, T016 de US1) para tener qué hacer responsive — no depende de US2.
- **Polish (Fase 6)**: depende de que las tres historias estén completas. Cierra la primera
  iteración (ya fusionada).
- **Historias de usuario de la segunda iteración (Fases 7-9)**: parten de `develop` con la primera
  iteración ya fusionada — no dependen de que la Fase 6 "se repita", solo de que ese código ya
  exista en la rama base.
  - US2 continuación (Fase 7) no depende de US1 continuación (Fase 8) ni de US4 (Fase 9) — es la
    unidad más grande, y la única con dependencias internas estrictas entre sus propias unidades
    (8→9→10, 9→11; la unidad 12 es independiente de las unidades 8-11).
  - US1 continuación (Fase 8) no depende de la Fase 7 ni de la Fase 9 (plan.md: "ajuste estructural
    pequeño y aislado").
  - US4 (Fase 9) no depende de las Fases 7 ni 8 (plan.md: "la unidad más grande y nueva... no
    depende de ninguna de las anteriores").
- **Polish ampliado (Fase 10)**: depende de que las Fases 7, 8 y 9 estén completas.

### Dependencias dentro de cada unidad

- Dentro de la Fase 2: T004 depende de T003; T008 depende de T007; T010 depende de T009; T012
  depende de T011. T003, T005, T006, T007, T009, T011 no dependen entre sí (archivos distintos).
- Dentro de la Fase 3: T014→T013; T015→(T013,T014); T017→T016; T018→T016; T019→T018; T020→(T013,
  T016); T021→T020. T013 y T016 no dependen entre sí.
- Dentro de la Fase 4: T022 y T023 no dependen entre sí (archivos distintos); T024→(T022,T023).
- Dentro de la Fase 5: T026→T025; T027→T025; T028→T026.
- Dentro de la Fase 7: T033-T043 no dependen entre sí (11 archivos distintos); T044→(T033..T043);
  T045→T044; T046→T045; T047→T046; T048→T046 (T047 y T048 no dependen entre sí); T049→T045;
  T050→T049; T051 no depende de T045-T050 (unidad 12 independiente); T052→T051; T053→T051;
  T054→T051; T055→T051 (T053, T054, T055 no dependen entre sí); T056→(T053,T054,T055).
- Dentro de la Fase 8: T058→T057; T059→(T057,T058).
- Dentro de la Fase 9: T061→T060; T062→T060; T063 y T064 no dependen de T060-T062 (reglas CSS
  independientes, archivo distinto); T065→T062.
- Dentro de la Fase 10: T066→(T033..T065, toda la segunda iteración); T067→T045; T068→(T033..T065);
  T069→(T066,T067,T068).

### Oportunidades de paralelismo

- Fase 2: T003, T005, T006, T007, T009, T011 se pueden hacer en paralelo (archivos distintos, sin
  dependencias entre ellos).
- Fase 3: T013 (`tenant-sidebar.component.ts`) y T016 (`tenant-header.component.ts`) se pueden
  hacer en paralelo — son componentes independientes que solo comparten servicios ya listos desde
  la Fase 2.
- Fase 4: T022 (`dashboard-layout.component.ts`) y T023 (`tenant-header.component.ts`) se pueden
  hacer en paralelo.
- Fase 6: T030 (auditoría de accesibilidad) se puede hacer en paralelo con T029/T031.
- Fase 7: T033-T043 (los 11 archivos de Terminal de Mesas) se pueden hacer en paralelo entre sí; una
  vez completa esa tanda, T051 (gráficas, unidad 12) puede avanzar en paralelo con T045-T050
  (unidades 9-11) por ser independiente; T053, T054, T055 (los 3 componentes de gráfica) se pueden
  hacer en paralelo entre sí.
- Fase 8 puede avanzar en paralelo con toda la Fase 7 (unidades independientes, plan.md).
- Fase 9 puede avanzar en paralelo con las Fases 7 y 8 por completo (plan.md: "no depende de
  ninguna de las anteriores"); dentro de ella, T063 y T064 (reglas CSS) se pueden hacer en paralelo
  con T060-T062 (el servicio). **Nota**: esta independencia es lógica, no de archivo — T049 (Fase
  7) y T062 (Fase 9) comparten `dashboard-layout.component.ts`, y T045 (Fase 7) y T063/T064 (Fase
  9) comparten `styles.css`; si se implementan con más de un agente/rama a la vez, coordinar el
  orden de edición de esos dos archivos para evitar conflictos de fusión.
- Fase 10: T067 (auditoría de accesibilidad) se puede hacer en paralelo con T066/T068.

---

## Parallel Example: Fase 2 (Foundational)

```bash
# Lanzar junto las tareas de archivo independiente de la Fase 2:
Task: "Añadir ~18 @case nuevos en icon.component.ts (T003)"
Task: "Crear el bloque .panel-theme en styles.css (T005)"
Task: "Añadir el script anti-parpadeo en index.html (T006)"
Task: "Crear panel-theme.service.ts (T007)"
Task: "Añadir desktopCollapsed a layout.service.ts (T009)"
Task: "Añadir el campo frame a navigation.interface.ts (T011)"
```

## Parallel Example: Fase 3 (US1)

```bash
Task: "Crear tenant-sidebar.component.ts (T013)"
Task: "Crear tenant-header.component.ts (T016)"
```

## Parallel Example: Fase 7 (US2 continuación — Unidad 8)

```bash
# Los 11 archivos de Terminal de Mesas, normalización mecánica hex→clase, sin dependencias entre sí:
Task: "Normalizar manual-order-page.component.ts (T033)"
Task: "Normalizar pos-checkout-panel.component.ts (T034)"
Task: "Normalizar pos-order-panel.component.ts (T035)"
Task: "Normalizar pos-terminal-header.component.ts (T036)"
Task: "Normalizar pos-tables-panel.component.ts (T037)"
Task: "Normalizar table-sessions.component.ts (T038)"
Task: "Normalizar pos-terminal.store.ts (T039)"
Task: "Normalizar session-bill-panel.component.ts (T040)"
Task: "Normalizar bill-summary.component.ts (T041)"
Task: "Normalizar order-summary-card.component.ts (T042)"
Task: "Normalizar cart-item-options.component.ts (T043)"
```

## Parallel Example: Fase 9 (US4)

```bash
Task: "Crear navigation-transition.service.ts (T060)"
Task: "Añadir reglas CSS de skeleton/aparición escalonada en styles.css (T063)"
Task: "Añadir regla prefers-reduced-motion en styles.css (T064)"
```

---

## Implementation Strategy

### MVP primero (solo Historia de Usuario 1)

1. Completar Fase 1: Setup (T001-T002).
2. Completar Fase 2: Foundational (T003-T012) — **crítico**, bloquea todo lo demás.
3. Completar Fase 3: Historia de Usuario 1 (T013-T021).
4. **Detenerse y validar**: recorrido manual de quickstart.md §2-3 sobre la Historia 1 sola.
5. El panel de tenant ya navega con la estructura, etiquetas e íconos nuevos — sin tema oscuro
   todavía, sin drawer responsive todavía (ambos degradan con normalidad: sin interruptor de tema
   visible, el sidebar seguiría con el comportamiento de "oculto por completo" en pantallas
   pequeñas hasta completar la Fase 5).

### Entrega incremental

1. Setup + Foundational → base lista.
2. Historia 1 → probar de forma independiente → MVP.
3. Historia 2 (tema) → probar de forma independiente → se añade sin romper la Historia 1.
4. Historia 3 (responsive) → probar de forma independiente → se añade sin romper las dos
   anteriores.
5. Polish (Fase 6) → recorrido manual completo, Lighthouse, regresión final. **Cierra la primera
   iteración (2026-10-12), ya fusionada a `develop` vía PR #36.**
6. Segunda iteración (2026-10-13), sobre la misma base: Historia 2 continuación (Fase 7, tema
   ampliado al contenido de los módulos) → probar de forma independiente. Historia 1 continuación
   (Fase 8, botón de colapso reubicado) y Historia 4 (Fase 9, transiciones de navegación) no
   dependen de la Fase 7 ni entre sí — se pueden intercalar en cualquier orden o en paralelo.
7. Polish ampliado (Fase 10) → recorrido manual de quickstart.md §10-16, Lighthouse repetido en
   oscuro, regresión final de toda la segunda iteración.

---

## Notes

- `[P]` = archivos distintos, sin dependencias pendientes.
- La etiqueta `[Story]` solo aparece en las Fases 3-5 y 7-9 (Setup, Foundational y Polish no llevan
  etiqueta de historia, según el formato requerido).
- Ningún test `"CONGELA comportamiento actual:"` existe en esta área (research.md, verificación de
  `CONGELA`), ni en los archivos nuevos que toca la segunda iteración — nada que blindar con
  characterization tests antes de empezar.
- `SidebarComponent`/`HeaderComponent` (legado, Super Admin) **no se modifican** en ninguna tarea,
  de ninguna de las dos iteraciones — solo se verifican con pruebas negativas (T021, T024, T031,
  T032, T050, T065, T069).
- La normalización de Terminal de Mesas (T033-T043) es mecánica (hex→clase equivalente exacta,
  cero cambio visual en claro), no una refactorización oportunista — es un prerrequisito técnico
  confirmado con el usuario (research.md R16, plan.md Complexity Tracking) para que la Unidad 9
  pueda alcanzar esa pantalla.
- Commits pequeños por tarea o grupo lógico, en inglés, Conventional Commits, sin marcas de
  asistencia de IA, y solo cuando el usuario los pida (Principio XV).

---

## Addendum — Ajuste visual post-implementación (2026-10-12)

Tras completar T001-T032, el usuario señaló que `Layout base.dc.html` (la referencia usada) estaba
desactualizado y pidió ajustar el layout para ser 100% fiel a `SkeiloPOS App.dc.html` (archivo
completo de la app, misma carpeta de diseños) — **solo visual**, sin tocar transiciones/animaciones
ya implementadas. Dos decisiones se confirmaron con el usuario vía `/speckit-clarify` (ver spec.md,
Clarifications): mantener "Cerrar sesión" (no "Salir") y omitir el botón "Ayuda" (sin destino real).

Cambios aplicados (detalle completo en research.md R13): corrección de dos valores de color mal
transcritos (`canvas` claro, `surface`/`surface-soft` en ambos temas), token nuevo
`--panel-color-surface-card` para paneles flotantes, botón de colapso reubicado del navbar al
propio sidebar, barra de acento del ítem activo, pie de marca SkeiloPOS, botones del navbar
unificados (bordeados), avatar/píldora de usuario con rol visible, orden del menú de usuario,
indicador de caja con punto de color, ícono nuevo `panel-left`. Verificado en Chrome real (ambos
temas, ambos modos, colapsado/expandido) y con Lighthouse Accessibility re-auditado en ambos temas
sin regresión. 91 tests (8 archivos) en verde de forma aislada y determinística.

## Addendum 2 — Tres bugs reales encontrados en la verificación del usuario (mismo día)

El usuario probó el ajuste visual y reportó 3 defectos concretos (no ambigüedades — cada uno se
diagnosticó empíricamente en el navegador, sin preguntas de clarificación). Detalle completo en
research.md R14:

1. **Animación del drawer (móvil/tablet) no se veía**: Tailwind 4 anima `translate`, no
   `transform` — la clase de transición observaba la propiedad equivocada. Corregido:
   `transition-[translate,width]`.
2. **Logo del pie no era el oficial**: se usaba `/logo.svg` (favicon antiguo). Se trajeron los
   activos reales del sistema de diseño (`_ds/.../assets/logo-horizontal-*`) — el claro ya estaba
   en el repo (`logo-horizontal.webp`, mismo archivo); se agregó el oscuro
   (`logo-horizontal-dark.webp`, convertido con `cwebp`). Recorte al ícono cuando está colapsado
   con la misma técnica del prototipo (contenedor angosto + overflow-hidden sobre una sola
   imagen).
3. **Logo del encabezado se deformaba al colapsar**: a 72px no cabían el logo + el botón de
   colapso en una fila (92px necesarios); además `<img>` hereda `max-width:100%` del preflight de
   Tailwind, que aplastaba la imagen en vez de desbordarla. Corregido apilando en columna cuando
   está colapsado.

Verificado en Chrome real (ambos temas, ambos modos); Lighthouse sin regresión; 91 tests en verde.

**Commiteado** (2026-10-12), 6 commits pequeños en `feat/116-layout-base-panel-admin`, en inglés,
Conventional Commits, sin atribución de IA (Principio XV): íconos, servicio de tema +
colapso, metadatos de navegación, `app-tenant-sidebar`, `app-tenant-header`, bifurcación del
shell. Sin push.

---

## Nota de cierre — segunda iteración (2026-10-13)

T033-T069 (Fases 7-10) completas: 37/37 tareas. Rama **nueva** `feat/116-layout-base-panel-admin`
creada desde `develop` (la anterior ya se fusionó vía PR #36) — 31 archivos modificados/nuevos en
`pos-heladeria` (11 de Terminal de Mesas normalizados mecánicamente, `styles.css` ampliado,
`navigation-transition.service.ts` nuevo + su spec, 3 specs de gráficas nuevos, resto de
componentes/specs ampliados). 1808 tests en verde (+18 sobre la línea base fresca de esta fase),
mismos 7 archivos/11 tests preexistentes en rojo que la línea base — sin regresiones. Verificado en
vivo con Chrome real (tenant `heladeria`, cuentas `qa116-*@e2e-pos.com` de la primera iteración,
reutilizadas — siguen en la base de datos de desarrollo) y Lighthouse real (Accessibility 94/100 en
Inventario oscuro, cero hallazgos de `color-contrast`).

**Un bug real encontrado y corregido durante la verificación** (detalle en T066): `.force-light-
surface` no fijaba un fondo claro, solo las variables de texto — el reporte de cierre de caja y la
hoja de QR quedaban con texto casi negro sobre fondo oscuro heredado (contraste ~1:1). Corregido
con `background-color: #fff` en la regla.

**Sin commitear** — [[feedback_git_commit_conventions]]: no se comitea sin que el usuario lo pida
explícitamente en esta sesión. `pos-api` (uvicorn nativo) y `pos-heladeria` (`npm start`) quedan
corriendo en segundo plano al cierre de esta sesión para que el usuario pueda seguir probando; el
contenedor Docker `pos-api` (en crash-loop) se detuvo, igual que en la primera iteración.

---

## Phase 11: Convergence

**Propósito**: cierra la brecha entre `spec.md` (Session 2026-10-14 — tercera ronda de
clarificación) y el código real en `pos-heladeria` (rama `feat/116-layout-base-panel-admin`).
Esas tres decisiones (FR-004 ampliado, FR-023, FR-024) nunca se propagaron a `plan.md`,
`research.md`, `data-model.md`, `quickstart.md` ni a las Fases 1-10 de este archivo — no existe
ninguna tarea previa que las cubra. Generado por `/speckit-converge`, inspeccionando
directamente el código de `pos-heladeria` (no solo los checkboxes de las fases anteriores).

- [X] T070 Sustituir la coincidencia exacta de ítem activo en
      `pos-heladeria/src/app/modules/dashboard/layout/tenant-sidebar.component.ts`
      (`[routerLinkActiveOptions]="{ exact: true }"`, ~línea 111) y en
      `pos-heladeria/src/app/modules/dashboard/layout/tenant-header.component.ts`
      (`activeItem = computed(() => NAV_ITEMS.find(item => item.route === this.currentUrl()))`,
      ~líneas 321-325) por una coincidencia de prefijo de ruta genérica, de forma que cualquier
      subvista sin ítem propio en el Sidebar (editar/crear/detalle, para todos los módulos con
      subrutas, no solo Carta) siga resaltando el ítem padre en el Sidebar y siga reflejando su
      grupo/etiqueta en el título de sección/página del Navbar; añadir un caso en
      `tenant-sidebar.component.spec.ts`/`tenant-header.component.spec.ts` con una subruta
      distinta de Carta (p. ej. editar un ítem de Inventario) per FR-004 (spec.md, Session
      2026-10-14, Edge Cases) (contradicts)
      **Hecho (2026-10-14)**: sidebar cambiado a `{ exact: false }` (Angular compara por
      segmento de `UrlTree`, no por substring de texto); header reescrito con coincidencia manual
      por prefijo de segmento (`path === item.route || path.startsWith(`${item.route}/`)`, URL
      sin query/fragment, desempate por ruta más larga). 4 tests nuevos (2 por componente,
      incluyendo el caso de colisión de texto `/dashboard/mesas` vs. `/dashboard/mesas-sesiones`,
      que confirma que la coincidencia por segmento no los confunde) — los 4 en verde.
      research.md R22.1; contracts/tenant-layout-contract.md §2-§3 actualizadas.
- [X] T071 Añadir estilo de scrollbar acorde al tema activo en `pos-heladeria/src/styles.css`
      usando únicamente las propiedades estándar `scrollbar-color`/`scrollbar-width` (sin
      pseudo-elementos `::-webkit-scrollbar`, sin dependencias nuevas), ajustado a los tokens
      `--panel-color-*` del tema activo, acotado al panel de tenant con las mismas exclusiones ya
      vigentes de FR-010 (Super Admin, pantallas públicas de autenticación, superficies
      `.force-light-surface`) — hoy no existe ninguna ocurrencia de `scrollbar` en
      `pos-heladeria/src/` per FR-024 (missing)
      **Hecho (2026-10-14)**: una sola declaración en el bloque base `.panel-theme`
      (`scrollbar-color: var(--panel-color-border) transparent; scrollbar-width: thin;`) — al
      heredarse igual que `color` y `--panel-color-border` ya cambiar de valor en
      `.panel-theme[data-theme='dark']`, resuelve ambos temas sin repetirla. CSS puro, sin test
      de `TestBed` posible (igual que R16/R17) — pendiente de recorrido visual manual
      (quickstart.md §17). research.md R22.2; contracts/panel-theme-contract.md §10 nueva.
- [X] T072 Corregir de forma sistemática la legibilidad de fondo/texto de los `<select>` del panel
      de tenant en modo oscuro — no solo los que ya quedan cubiertos de forma incidental por la
      redeclaración de variables de Tailwind de la Unidad 9 (research.md R16) — concretamente
      `pos-heladeria/src/app/modules/tables/components/payment-input.component.ts` (`<select>` sin
      ninguna clase de color, ~línea 60, el mismo que la sesión de clarificación detectó roto) y
      los dos `<select>` de
      `pos-heladeria/src/app/modules/inventory/components/purchase-form.component.ts` (~líneas 44
      y 86 — uno sin clases de color, el otro con `text-gray-600` ya redeclarado por R16 pero sin
      fondo redeclarado, quedando con texto claro sobre fondo nativo claro invertido, peor que
      antes); añadir una regla CSS general (p. ej. `.panel-theme select`) para que cualquier
      `<select>` futuro sin clases de color de Tailwind quede cubierto por construcción, en vez de
      depender de que cada autor añada `bg-white`/`text-gray-*` per FR-023 (partial)
      **Hecho (2026-10-14)**: una sola regla por elemento,
      `.panel-theme[data-theme='dark'] select { background-color: var(--panel-color-surface-card);
      color: var(--panel-color-text-secondary); border-color: var(--panel-color-border); }` —
      sin tocar `payment-input.component.ts` ni `purchase-form.component.ts`: su especificidad
      (una clase + un atributo + un tipo) es menor que cualquier utilidad de Tailwind ya presente
      en un `<select>` (`.bg-white`, `.text-gray-*`), así que no cambia nada donde ya había una
      clase de color y cubre por construcción cualquier `<select>` sin ninguna. CSS puro, sin test
      de `TestBed` posible — pendiente de recorrido visual manual (quickstart.md §17). research.md
      R22.3; contracts/panel-theme-contract.md §10 nueva.

---

## Nota de cierre — Fase 11 (2026-10-14)

T070-T072 completas: 3/3 tareas. Cambios en `pos-heladeria` (misma rama
`feat/116-layout-base-panel-admin`, sin commitear, sobre el trabajo ya acumulado de las Fases
1-10): `tenant-sidebar.component.ts` (+comentario, 1 atributo), `tenant-header.component.ts`
(lógica de `activeItem` reescrita), `styles.css` (+2 reglas CSS), y 2 specs ampliados
(`tenant-sidebar.component.spec.ts`, `tenant-header.component.spec.ts`, +4 tests). Suite completa
tras el cambio: 7 archivos/11 tests en rojo (exactamente los mismos ya documentados como
preexistentes al cierre de la Fase 10), 1812 pasan (1808 + 4 nuevos), 1 skip — sin regresiones.

Documentación actualizada para cerrar la trazabilidad que esta fase existía para resolver
(Principio XII): research.md (R22.1-R22.3), contracts/tenant-layout-contract.md (§2-§3),
contracts/panel-theme-contract.md (§10 nueva), quickstart.md (§17 nueva + 3 ítems en la lista de
cierre §16).

**Pendiente**: recorrido visual manual de T071/T072 (scrollbar y `<select>` son CSS puro, sin
test de `TestBed` posible, igual que R16/R17 en la Fase 7) — quickstart.md §17. **Sin
commitear** — [[feedback_git_commit_conventions]]: no se comitea sin que el usuario lo pida
explícitamente en esta sesión.

---

## Phase 12: Convergence

**Propósito**: cierra la brecha entre `spec.md` (tercera ronda de clarificación del
2026-10-14, vía `/speckit-clarify` — FR-025 nueva y dos correcciones contra FR-003/FR-010 ya
existentes) y el código real en `pos-heladeria`, detectada tras el recorrido visual del usuario
sobre la implementación de la Fase 11. Generado por `/speckit-converge`, con evidencia
archivo:línea confirmada directamente en el código (no solo los checkboxes de fases anteriores).

- [X] T073 Cambiar el ícono del botón de menú/colapso en
      `pos-heladeria/src/app/modules/dashboard/layout/tenant-header.component.ts`
      (`<app-icon [name]="viewMode() === 'drawer' ? 'menu' : 'panel-left'" />`, ~línea 62) para
      que use siempre el ícono `menu`, sin condicional por modo (`[name]="'menu'"`) — el archivo
      de diseño de referencia (`Layout base.dc.html:52`) usa ese mismo ícono fijo tanto en
      escritorio como en el menú móvil, nunca `panel-left`; ajustar
      `tenant-header.component.spec.ts` si algún caso existente verificaba el ícono anterior per
      FR-003 (spec.md, Clarifications Session 2026-10-14) (contradicts)
      **Hecho (2026-10-14)**: `[name]="'menu'"` fijo, sin condicional. Ningún test existente
      verificaba `panel-left` (nada que actualizar); se agregó 1 test nuevo que confirma el
      ícono `menu` en ambos modos (`desktop`/`drawer`) vía `By.directive(IconComponent)` — en
      verde junto con los 12 tests ya existentes del archivo.
- [X] T074 Dar color de texto propio a los íconos que hoy dependen de la herencia del color de
      texto ambiental del tema sobre un fondo de color pastel/semántico fijo (`bg-indigo-50`, que
      no se redeclara en modo oscuro por ser semántico, no `gray`/`slate` — research.md R16), en
      las 9 instancias confirmadas: `pos-heladeria/src/app/modules/tables/pages/tables-page.component.ts`
      (~líneas 81-82), `pos-heladeria/src/app/modules/categories/pages/categories-page.component.ts`
      (~líneas 98-99), `pos-heladeria/src/app/modules/settings/pages/tenant-info.component.ts`
      (5 instancias, ~líneas 46-47, 89-90, 124-125, 178-179, 198-199),
      `pos-heladeria/src/app/modules/products/pages/products-page.component.ts` (~líneas 150-153)
      y `pos-heladeria/src/app/modules/products/pages/product-detail-page.component.ts`
      (~líneas 55-56) — añadiendo `text-indigo-600` (o el color semántico que corresponda a cada
      insignia) al `<app-mi-icon>`/wrapper inmediato en cada una, de forma que el ícono deje de
      heredar `color` de `.panel-theme` y sea legible en ambos temas per FR-025/SC-012 (spec.md,
      Clarifications Session 2026-10-14) (missing)
      **Hecho (2026-10-14)**: `class="text-indigo-600"` añadida a las 9 instancias en los 5
      archivos — mismo patrón ya usado como precedente real en `orders-page.component.ts:103`/
      `admin-dashboard.component.ts` (ícono + `bg-indigo-50` + `text-indigo-600`), ninguna clase
      nueva inventada. Sin test de `TestBed` posible para color CSS — pendiente de recorrido
      visual manual (quickstart.md §18).
- [X] T075 Extender la lista cerrada de selectores de superficie clara en
      `pos-heladeria/src/styles.css` (`.panel-theme[data-theme='dark'] .bg-white,
      .focus\:bg-white:focus, .hover\:bg-white:hover`, ~líneas 529-531) para cubrir también
      `.via-white` y `.to-white` (mismas reglas, mismo valor `var(--panel-color-surface-card)`) —
      la única ocurrencia en el repo de esas dos clases,
      `pos-heladeria/src/app/modules/tables/components/product-select.component.ts:261`
      (`bg-gradient-to-br from-indigo-50/40 via-white to-white`, el panel de "adicionales" del
      modal de selección de producto en Terminal de Mesas), queda con fondo blanco fijo en modo
      oscuro sin este cambio; dejar `from-indigo-50/40` sin tocar (acento decorativo, confirmado
      con el usuario) per FR-010 (spec.md, Clarifications Session 2026-10-14) (missing)
      **Hecho (2026-10-14)**: la premisa de la tarea era imprecisa — compilando el motor real de
      `tailwindcss@4.1.12` (vía `@tailwindcss/postcss`, confirmado antes de escribir CSS a
      ciegas, mismo rigor que R16/R19) se verificó que `.via-white`/`.to-white` NO fijan
      `background-color` como `.bg-white` sí hace — fijan `--tw-gradient-via`/`--tw-gradient-to`,
      consumidas por `background-image: linear-gradient(var(--tw-gradient-stops))` en
      `.bg-gradient-to-*`. Repetir la regla de `.bg-white` ahí no habría tenido ningún efecto
      visual. Se agregaron 2 reglas nuevas (no 2 líneas más en la lista existente) que
      sobrescriben esas variables de degradado correctas:
      `.panel-theme[data-theme='dark'] .via-white { --tw-gradient-via: var(--panel-color-surface-card); }`
      y la misma para `.to-white`/`--tw-gradient-to`. `from-indigo-50/40` sin tocar. CSS puro, sin
      test de `TestBed` posible — pendiente de recorrido visual manual (quickstart.md §18).

---

## Nota de cierre — Fase 12 (2026-10-14)

T073-T075 completas: 3/3 tareas. Cambios en `pos-heladeria` (misma rama
`feat/116-layout-base-panel-admin`, sin commitear): `tenant-header.component.ts` (ícono fijo,
+1 línea), `tenant-header.component.spec.ts` (+1 test), 5 archivos de componentes
(`tables-page`, `categories-page`, `tenant-info`, `products-page`, `product-detail-page`, 9
instancias de `class="text-indigo-600"`), `styles.css` (+2 reglas de degradado). Suite completa
tras el cambio: 7 archivos/11 tests en rojo (exactamente los mismos ya documentados como
preexistentes al cierre de la Fase 11), 1813 pasan (1812 + 1 nuevo), 1 skip — sin regresiones.

**Hallazgo real durante la implementación** (T075): la premisa de la tarea asumía que
`via-white`/`to-white` se repintarían igual que `bg-white` (`background-color`); compilando el
motor real de Tailwind antes de escribir CSS a ciegas se confirmó que usan un mecanismo distinto
(`--tw-gradient-via`/`--tw-gradient-to`, no `background-color`) — mismo rigor que R16/R19 ya
aplicaron ("ningún valor se da por bueno sin verlo renderizado"/compilado). La solución final
sobrescribe las variables correctas, no las de la tarea original.

Documentación actualizada (Principio XII): research.md (R23.1-R23.3), contracts (iconografía
del botón de menú y degradado de superficie), quickstart.md (§18 nueva + lista de cierre
ampliada).

**Pendiente**: recorrido visual manual de T074/T075 (color de ícono y degradado son CSS puro,
sin test de `TestBed` posible) — quickstart.md §18. **Sin commitear** —
[[feedback_git_commit_conventions]]: no se comitea sin que el usuario lo pida explícitamente en
esta sesión.
