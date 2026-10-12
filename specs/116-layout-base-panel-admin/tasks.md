---

description: "Task list template for feature implementation"
---

# Tasks: Layout base del panel (Sidebar + Navbar) con tema claro/oscuro persistente

**Input**: Documentos de diseño de `specs/116-layout-base-panel-admin/`
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md) | **Data model**: [data-model.md](./data-model.md) | **Quickstart**: [quickstart.md](./quickstart.md) | **Contratos**: [contracts/](./contracts/)

**Repositorio de código**: todas las rutas de archivo son relativas a `pos-heladeria/` (el repositorio
`skeilo-pos-heladeria`, rama `feat/116-layout-base-panel-admin`). **`pos-backend` no participa en
ninguna tarea** (plan.md, Technical Context).

**Tests**: se incluyen — el plan (Principio X) pide un `*.spec.ts` hermano por archivo nuevo o
ampliado, siguiendo el patrón de `sidebar.component.spec.ts`/`sound.service.ts` ya existente.

**Organización**: las tareas de las Fases 3-5 están agrupadas por historia de usuario (US1, US2,
US3 de spec.md) para poder implementarlas y probarlas de forma independiente, siguiendo el orden
de implementación sugerido en plan.md.

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
- [X] T032 Confirmar la lista de cierre de quickstart.md §9 (los 8 puntos) y verificar visualmente,
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
- **Polish (Fase 6)**: depende de que las tres historias estén completas.

### Dependencias dentro de cada unidad

- Dentro de la Fase 2: T004 depende de T003; T008 depende de T007; T010 depende de T009; T012
  depende de T011. T003, T005, T006, T007, T009, T011 no dependen entre sí (archivos distintos).
- Dentro de la Fase 3: T014→T013; T015→(T013,T014); T017→T016; T018→T016; T019→T018; T020→(T013,
  T016); T021→T020. T013 y T016 no dependen entre sí.
- Dentro de la Fase 4: T022 y T023 no dependen entre sí (archivos distintos); T024→(T022,T023).
- Dentro de la Fase 5: T026→T025; T027→T025; T028→T026.

### Oportunidades de paralelismo

- Fase 2: T003, T005, T006, T007, T009, T011 se pueden hacer en paralelo (archivos distintos, sin
  dependencias entre ellos).
- Fase 3: T013 (`tenant-sidebar.component.ts`) y T016 (`tenant-header.component.ts`) se pueden
  hacer en paralelo — son componentes independientes que solo comparten servicios ya listos desde
  la Fase 2.
- Fase 4: T022 (`dashboard-layout.component.ts`) y T023 (`tenant-header.component.ts`) se pueden
  hacer en paralelo.
- Fase 6: T030 (auditoría de accesibilidad) se puede hacer en paralelo con T029/T031.

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
5. Polish (Fase 6) → recorrido manual completo, Lighthouse, regresión final.

---

## Notes

- `[P]` = archivos distintos, sin dependencias pendientes.
- La etiqueta `[Story]` solo aparece en las Fases 3-5 (Setup, Foundational y Polish no llevan
  etiqueta de historia, según el formato requerido).
- Ningún test `"CONGELA comportamiento actual:"` existe en esta área (research.md, verificación de
  `CONGELA`) — nada que blindar con characterization tests antes de empezar.
- `SidebarComponent`/`HeaderComponent` (legado, Super Admin) **no se modifican** en ninguna tarea —
  solo se verifican con pruebas negativas (T021, T024, T031, T032).
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
