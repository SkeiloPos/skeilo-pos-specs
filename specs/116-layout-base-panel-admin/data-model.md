# Data Model — Fase 1: Layout base del panel (Sidebar + Navbar) con tema claro/oscuro persistente

**Spec**: [spec.md](./spec.md) | **Research**: [research.md](./research.md)

## 0. Lo primero, porque cambia cómo se lee este documento

Esta spec **no tiene modelo de datos de servidor**: no crea, modifica ni migra ninguna tabla de
`pos-backend` (Technical Context del plan). Todo lo que sigue son **estructuras de cliente**
(`pos-heladeria`) — señales de Angular y, para dos de ellas, una clave de `localStorage`. El
Principio VIII (evolución del modelo de datos) no aplica por ausencia de modelo que evolucionar.

Las "entidades" de la spec (Preferencia de tema, Ítem de navegación, Preferencia de colapso del
Sidebar — sección *Key Entities* de spec.md) se traducen aquí a su forma concreta en código.

---

## 1. Preferencia de tema — `PanelTheme` (nueva, persistida)

| Campo | Tipo | Notas |
|---|---|---|
| `theme` | `'light' \| 'dark'` | Único valor; no hay un tercer estado "sistema" persistido — FR-013 solo usa la señal del sistema como *valor inicial* cuando no hay nada guardado, nunca como un modo que se recuerde como tal. |

**Dónde vive**: signal `theme` en `PanelThemeService`
(`src/app/modules/dashboard/layout/panel-theme.service.ts`, nuevo, `providedIn: 'root'`).

**Persistencia**: `localStorage`, clave `pos.panel.theme`, valor `'light'` o `'dark'` como string
literal. Mismo patrón defensivo que `sound.service.ts`/`printer-settings.store.ts` (R3 del
research de la spec 095, ya establecido en este proyecto):

```ts
private read(): 'light' | 'dark' | null {
  try {
    const v = localStorage.getItem(THEME_KEY);
    return v === 'light' || v === 'dark' ? v : null;
  } catch {
    return null; // almacenamiento no disponible (FR-014) — no es un error, es el caso previsto
  }
}
private write(value: 'light' | 'dark'): void {
  try { localStorage.setItem(THEME_KEY, value); }
  catch { /* navegación privada u otro bloqueo: la preferencia vive solo esta carga */ }
}
```

**Resolución del valor inicial** (FR-013, orden estricto):
1. `read()` — si hay un valor guardado, es ese, punto. Una vez el usuario elige, la señal del
   sistema operativo deja de consultarse (Edge Case: la preferencia explícita prevalece).
2. Si `read()` devuelve `null` → `window.matchMedia('(prefers-color-scheme: dark)').matches`
   (con su propio `try` — algunos entornos de test/SSR no exponen `matchMedia`).
3. Si tampoco hay señal del sistema → `'light'` (FR-013, última cláusula).

**Quién la fija antes del primer pintado**: el script inline de `index.html` (research R4) hace
la misma lectura en JavaScript plano (sin `PanelThemeService`, que todavía no existe en ese punto
del arranque) y escribe el atributo en el DOM. `PanelThemeService`, al construirse, **lee ese
mismo atributo ya puesto** en vez de repetir la detección — así nunca hay una segunda decisión que
pueda discrepar de la primera.

**Transiciones**: `toggleTheme()` invierte el valor actual y lo persiste; no hay más estados ni
transiciones posibles (es un interruptor de dos posiciones, FR-009).

---

## 2. Preferencia de colapso del Sidebar — `SidebarCollapsePreference` (nueva, persistida)

| Campo | Tipo | Notas |
|---|---|---|
| `collapsed` | `boolean` | `true` = solo íconos (72px); `false` = expandido (248px, valor por defecto). Aplica **solo en escritorio** (≥1024px) — en móvil/tablet este valor no se lee (ahí gobierna el drawer, ver §3). |

**Dónde vive**: signal `desktopCollapsed` en `LayoutService`
(`src/app/modules/dashboard/layout/layout.service.ts`, existente — se le añade este signal nuevo
junto al `sidebarOpen` que ya tiene, sin tocar este último; ver research R5).

**Persistencia**: mismo mecanismo exacto que §1 — `localStorage`, clave
`pos.panel.sidebar_collapsed`, con el mismo `try`/`catch` y el mismo valor por defecto (`false`,
expandido) cuando no hay nada guardado o el almacenamiento falla (FR-017, que cita expresamente
"el mismo mecanismo… y el mismo manejo… que la preferencia de tema").

**Quién la consume**: únicamente `app-tenant-sidebar`/`app-tenant-header` (los componentes
nuevos). `SidebarComponent`/`HeaderComponent` (Super Admin) no la leen ni la escriben — no
necesitan saber que existe.

---

## 3. Modo de visualización del Sidebar — `SidebarViewMode` (derivado, no persistido)

No es una entidad de la spec, pero es el estado que decide **cuál** de las dos preferencias
anteriores pinta la pantalla en cada momento. Vive como signal derivado dentro de
`app-tenant-sidebar` (research R6), a partir de un `BreakpointObserver.observe('(min-width:
1024px)')` del `@angular/cdk` ya presente en el proyecto:

| `SidebarViewMode` | Cuándo | Qué se lee |
|---|---|---|
| `'desktop'` | ancho ≥ 1024px | `desktopCollapsed` (§2) decide 72px vs. 248px |
| `'drawer'` | ancho < 1024px | `sidebarOpen` (existente, no persistido) decide superpuesto vs. oculto |

No se persiste nunca — es 100 % función del ancho actual de la ventana, recalculado en vivo
(Edge Case de cruzar el punto de quiebre sin recargar).

---

## 4. Ítem de navegación — extensión aditiva de `NavItem` (existente)

La interfaz `NavItem` (`src/app/core/interfaces/navigation.interface.ts`) ya tiene todo lo que
gobierna el **acceso** (`route`, `roles`, `moduleKey`) — eso **no cambia**, porque cambiarlo sería
tocar exactamente lo que FR-005/FR-006 prohíben tocar. Lo que cambia es **solo la presentación**
del ítem dentro del sidebar nuevo, y se añade como campos opcionales que el componente legado
(Super Admin, R1) simplemente no lee:

```ts
export interface NavItem {
  label: string;      // sin cambios — lo sigue leyendo SidebarComponent (legado)
  icon: string;        // sin cambios — nombre de app-mi-icon (Material), legado
  route: string;        // sin cambios — fuente de verdad de acceso
  group: string;         // sin cambios — grupo legado (PRINCIPAL, OPERACIONES, …)
  roles: UserRole[];      // sin cambios — fuente de verdad de acceso
  moduleKey?: keyof ModuleAccess; // sin cambios — fuente de verdad de acceso por plan

  /** Presentación nueva (spec 116), solo para `app-tenant-sidebar`. Si falta,
   *  ese ítem no debería aparecer en TENANT_FRAME_GROUP_ORDER (ver tasks.md) —
   *  cada uno de los 15 NavItem de tenant la define. */
  frame?: {
    label: string;  // p.ej. "Cajas" en vez de "Caja"; la mayoría repite `label`
    icon: string;    // nombre de `app-icon` (Lucide), p.ej. "banknote"
    group: 'Inicio' | 'Operación' | 'Catálogo' | 'Inventario' | 'Control' | 'Administración';
  };
}
```

**Por qué aditivo y no un arreglo paralelo**: `roles`/`moduleKey` son la única fuente de verdad
del acceso (FR-005). Un segundo arreglo con su propia copia de `route`/`roles` para el nuevo
sidebar podría divergir del original con el tiempo (alguien actualiza uno y olvida el otro) — el
campo `frame` opcional en el mismo objeto hace que la divergencia sea imposible de introducir sin
tocar el mismo `NavItem`, y que `app-tenant-sidebar` filtre exactamente con la misma lógica que
`visibleItems`/`groupedItems` de `SidebarComponent` ya implementan hoy (fail-open mientras el plan
no carga, ocultar si el tenant está vencido, ocultar grupos sin ítems visibles — FR-016, ya
implementado, solo se reutiliza).

**Nuevo orden de grupos para el frame de tenant**: una constante nueva,
`TENANT_FRAME_GROUP_ORDER`, independiente de `NAV_GROUP_ORDER` (que sigue gobernando
exclusivamente al componente legado — Super Admin y su único grupo `PLATAFORMA`):

```ts
export const TENANT_FRAME_GROUP_ORDER = [
  'Inicio', 'Operación', 'Catálogo', 'Inventario', 'Control', 'Administración',
] as const;
```

**Mapeo completo** (los 15 `NavItem` de tenant existentes, verificados contra
`navigation.config.ts`, ninguno nuevo ni eliminado — ver
[contracts/navigation-grouping-contract.md](./contracts/navigation-grouping-contract.md) para la
tabla exhaustiva ruta → grupo/etiqueta/ícono nuevos).

---

## 5. Lo que explícitamente no cambia

- **Reglas de acceso por rol y por plan** (`visibleItems`, fail-open, `vencido`): se reutiliza la
  lógica ya implementada en `SidebarComponent`, trasladada tal cual a `app-tenant-sidebar` sobre
  los mismos campos (`roles`, `moduleKey`), nunca sobre los nuevos campos `frame`.
- **`SUPER_ADMIN_NAV_ITEMS`, `NAV_GROUP_ORDER`**: sin un solo campo `frame`; el componente legado
  (R1) no cambia su fuente de datos.
- **Cualquier dato de servidor**: `TenantInfoService`, `PlanSummaryService`, `AuthService`,
  `CashService` se **leen** (el último, con una llamada adicional ya existente — research R8),
  nunca se modifican sus contratos ni sus endpoints.
