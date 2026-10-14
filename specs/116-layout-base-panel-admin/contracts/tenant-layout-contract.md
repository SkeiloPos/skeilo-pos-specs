# Contrato — `app-tenant-sidebar` y `app-tenant-header`

**Spec**: [../spec.md](../spec.md) (Historias 1 a 3, y Historia 4 en lo que toca al botón de
menú/colapso) | **Research**: [../research.md](../research.md) R1, R5, R6, R8, R15

> **§2/§3 actualizadas en la iteración 2026-10-13** (research R15): el botón de menú/colapso del
> sidebar de escritorio vuelve a vivir en `app-tenant-header` (como en `Layout base.dc.html`,
> fuente de verdad vigente), no en `app-tenant-sidebar` (como quedó tras el ajuste R13 de la
> iteración anterior, que seguía a `SkeiloPOS App.dc.html`, ya no vigente).

## 1. `DashboardLayoutComponent` — el único cambio en el shell compartido

```html
@if (sidebarGate.isSuperAdmin()) {
  <app-sidebar />
  <app-header />
} @else {
  <app-tenant-sidebar />
  <app-tenant-header />
}
```

**Garantías**:
- `isSuperAdmin()` se evalúa contra `AuthService.currentUser()`, la misma fuente que ya usa
  `SidebarComponent` hoy — no hay una segunda forma de clasificar al usuario.
- Ningún guard de ruta, ninguna entrada de `dashboard/routes.ts` ni de `super-admin/routes.ts`
  cambia (FR-006). Este `@if` es la única línea nueva relevante en
  `dashboard-layout.component.ts`; `ngOnInit`/`ngOnDestroy` (carga de `BootstrapService`,
  conexión de `RealtimeService`) no se tocan.
- El wrapper `shell-root`/`shell-content`/`shell-main` (scroll independiente del contenido,
  FR-015) tampoco cambia — `app-tenant-sidebar`/`app-tenant-header` se montan dentro de la misma
  estructura que ya lo garantiza.

## 2. `app-tenant-sidebar`

### Responsabilidades
- Pintar el encabezado del sidebar con `logoUrl`/`businessName` (truncado en una sola línea, sin
  "sede" — research R9), igual que hoy `SidebarComponent`.
- Pintar los 6 grupos de [navigation-grouping-contract.md](./navigation-grouping-contract.md),
  filtrados por rol/plan con la misma lógica que `visibleItems()`/`groupedItems()` de
  `SidebarComponent` (reutilizada, no reimplementada desde cero — ver
  [../data-model.md](../data-model.md) §4).
- Resolver `SidebarViewMode` (`'desktop' | 'drawer'`) vía `BreakpointObserver` (research R6) y
  pintar en consecuencia: 248px/72px en `'desktop'`, superpuesto con scrim en `'drawer'`.
- Mostrar el tooltip accesible por teclado cuando está colapsada (contrato en
  [panel-theme-contract.md](./panel-theme-contract.md) §5).
- **Actualizado de nuevo** (research.md R15, revierte R13 para este punto): el botón de colapso
  **ya no vive aquí** — vuelve a `app-tenant-header` (§3), consolidado con el botón de drawer
  móvil en un único control, igual que `Layout base.dc.html`. El pie del sidebar sigue pintando la
  marca estática "SkeiloPOS" (wordmark, R14.2), sin cambios.

### Garantías observables
- El ítem correspondiente a la ruta activa se resalta (FR-004) — **actualizado** (research R22.1,
  spec.md Session 2026-10-14): `routerLinkActive` con `exact: false`, no `exact: true`. Angular
  compara por segmento de `UrlTree`, no por substring de texto, así que una subvista sin ítem
  propio (editar/crear/detalle, de cualquier módulo, no solo Carta) resalta a su módulo padre, sin
  que rutas que solo comparten prefijo de texto (`/dashboard/mesas` vs.
  `/dashboard/mesas-sesiones`) se confundan entre sí.
- Un grupo sin ítems visibles no se renderiza, nunca como contenedor vacío (FR-016).
- Colapsar/expandir no navega ni pierde el scroll del `<router-outlet>` (FR-007).
- En `'drawer'`, un scrim (fondo oscurecido) cubre el resto de la pantalla; tocarlo o seleccionar
  un ítem cierra el drawer (FR-008, Historia 3 Escenario 2) — mismo patrón que el backdrop actual
  de `dashboard-layout.component.ts` (`fixed inset-0 bg-black/40 … lg:hidden`), replicado aquí
  con el nuevo punto de quiebre reactivo.

### Lo que NO hace
- No decide qué rutas existen ni qué guard protege cada una.
- No lee `cashService` ni ningún estado de caja — eso es responsabilidad de
  `app-tenant-header` (§3).

## 3. `app-tenant-header`

### Responsabilidades
- Botón de menú/colapso — **actualizado de nuevo** (research.md R15, revierte R13 para este punto,
  vuelve a `Layout base.dc.html`): un único botón, **siempre visible** (en ambos modos de vista),
  con un solo efecto según `viewMode()`: en `'drawer'` (<1024px) invoca `layoutService.toggle()`
  (abre/cierra el sidebar superpuesto, sin cambios de comportamiento ahí); en `'desktop'` invoca
  `layoutService.toggleDesktopCollapsed()` (antes vivía dentro de `app-tenant-sidebar`, §2 — ya
  no). El `aria-label`/`title` cambia según el modo y el estado, igual que hoy. El ícono es
  siempre `menu` (**actualizado**, research R23.1): `Layout base.dc.html:52` no define un ícono
  distinto para el estado colapsado/expandido ni para el modo escritorio — es el mismo ícono de
  hamburguesa en todos los casos, nunca `panel-left` (resto de una iteración ya revertida).
- Título de sección y de página, derivados de la ruta activa (el mismo criterio que hoy usa
  `HeaderComponent` con un título fijo "Panel de Control" se reemplaza por uno dinámico: sección
  = `frame.group` del ítem activo; título = `frame.label` del ítem activo). **Actualizado**
  (research R22.1): el ítem activo se resuelve por coincidencia de prefijo de segmento
  (`path === item.route || path.startsWith(`${item.route}/`)`, sobre la URL sin query/fragment,
  con desempate por la ruta más larga), no por igualdad exacta — una subvista sin ítem propio
  también resuelve el título/sección de su módulo padre.
- Campana de notificaciones — reutiliza `NotificationCenterService`/`PushRegistrationService`
  exactamente como `HeaderComponent` hoy (mismo dropdown, mismo conteo, mismo flujo de permiso
  push); solo cambia su envoltorio visual (ícono `bell` de `app-icon`, paleta `.panel-theme`).
- Interruptor de tema — `PanelThemeService.toggleTheme()` (contrato en
  [panel-theme-contract.md](./panel-theme-contract.md) §3).
- Indicador de caja — `CashService.isOpen()`/`shift()`, solo para `ADMIN`/`CASHIER`, con la carga
  adicional de `discoverOpenShift()` descrita en research R8.
- Menú de usuario — mismas tres acciones y mismos destinos que hoy
  (`/dashboard/mi-plan`, `/dashboard/mi-cuenta`, `logout()` vía `AuthService`), con los íconos
  nuevos de [navigation-grouping-contract.md](./navigation-grouping-contract.md).

### Garantías observables
- "Mi plan" solo aparece si `!currentUser()?.isSuperAdmin` (mismo criterio que hoy; en la
  práctica siempre visible aquí, porque este componente solo se monta para no-Super-Admin).
- `logout()` navega a `/login` tras cerrar sesión — sin cambios de comportamiento.
- Ningún texto ni acción del menú de usuario cambia su destino o su efecto; solo su presentación.

## 4. Qué pasa con `SidebarComponent`/`HeaderComponent` (legado)

No se modifican. Siguen siendo la implementación real y única para Super Admin. Sus tests
(`sidebar.component.spec.ts`, `header.component.spec.ts`) siguen pasando sin tocarlos — son la
prueba de que este contrato no los afectó.
