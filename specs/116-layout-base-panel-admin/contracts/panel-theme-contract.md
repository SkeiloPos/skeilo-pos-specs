# Contrato — Tema claro/oscuro del marco del panel

**Spec**: [../spec.md](../spec.md) (FR-009 a FR-017) | **Research**:
[../research.md](../research.md) R3, R4, R5 | **Data model**: [../data-model.md](../data-model.md) §1, §2

## 1. Alcance de la clase `.panel-theme`

`.panel-theme` se aplica **únicamente** en la raíz de `DashboardLayoutComponent`, condicionada a
`!isSuperAdmin()`. Ninguna otra pantalla del sistema la lleva. Las reglas CSS bajo
`.panel-theme` y `.panel-theme[data-theme="dark"]` solo pueden estilar:

- El `<aside>` de `app-tenant-sidebar` (fondo, texto, bordes, ítem activo).
- El `<header>` de `app-tenant-header` (fondo, texto, bordes, controles).
- El fondo del contenedor del `<router-outlet>` (el "área de contenido"), **nunca** el contenido
  que ese `<router-outlet>` proyecta — las páginas de cada módulo no llevan esta clase ni la
  heredan en sus propios componentes de superficie (tarjetas, tablas), que siguen con sus
  clases de Tailwind actuales (FR-010).

Cualquier regla CSS que use `--panel-color-*` fuera de `app-tenant-sidebar.component.ts`,
`app-tenant-header.component.ts` o el contenedor de `router-outlet` del shell es, por definición,
una violación de este contrato.

## 2. Tokens — tabla completa (claro / oscuro)

Ver la tabla completa en [../research.md](../research.md) R3. Resumen de los que todo
implementador debe reconocer por nombre:

`--panel-color-primary`, `--panel-color-primary-active`, `--panel-color-primary-soft`,
`--panel-color-primary-text`, `--panel-color-surface`, `--panel-color-surface-elevated`,
`--panel-color-canvas`, `--panel-color-border`, `--panel-color-text-primary`,
`--panel-color-text-secondary`, `--panel-color-text-muted`, `--panel-color-text-subtle`,
`--panel-color-success`, `--panel-color-success-soft`, `--panel-color-overlay-hover`.

## 3. `PanelThemeService` — contrato público

```ts
@Injectable({ providedIn: 'root' })
export class PanelThemeService {
  readonly theme: Signal<'light' | 'dark'>;   // valor actual, resuelto (data-model §1)
  toggleTheme(): void;                         // invierte y persiste
  setTheme(value: 'light' | 'dark'): void;     // fija un valor explícito y persiste
}
```

**Garantías**:
- `theme()` nunca lanza, nunca devuelve `undefined` — siempre uno de los dos literales.
- `toggleTheme()`/`setTheme()` nunca lanzan, incluso si `localStorage.setItem` falla (FR-014):
  el signal en memoria sí cambia (el usuario ve el efecto inmediato dentro de esa carga de
  página), solo la persistencia entre cargas queda sin garantía.
- No expone ningún método para leer o fijar la preferencia del sistema operativo directamente —
  eso es un detalle interno de la resolución inicial (data-model §1), no parte del contrato
  público.

## 4. Contrato anti-parpadeo (FR-012, SC-002) — verificable

1. Al cargar `/dashboard/*` (o `/super-admin/*`, aunque ahí el atributo nunca se consulta) con
   `pos.panel.theme = 'dark'` ya guardado, el primer frame pintado por el navegador **ya** debe
   mostrar el marco en tema oscuro — no hay un frame intermedio en claro.
2. Verificación de DevTools: con *Network → Disable cache* y *CPU throttling: 4x slowdown*,
   grabar el *Performance* panel desde la navegación hasta el primer pintado del shell; el
   primer frame con el `<aside>` visible debe llevar ya el fondo oscuro. Ver paso a paso en
   [../quickstart.md](../quickstart.md) §2.

## 5. Contrato de colapso del Sidebar (FR-007, FR-017)

| Método/signal (`LayoutService`, nuevo) | Contrato |
|---|---|
| `desktopCollapsed: Signal<boolean>` | `true` = 72px, solo íconos; `false` = 248px. Solo tiene efecto visual cuando `SidebarViewMode === 'desktop'` (data-model §3). |
| `toggleDesktopCollapsed(): void` | Invierte y persiste con el mismo mecanismo de `PanelThemeService` (clave distinta, mismo `try`/`catch`). |

**Garantía de FR-007 ("sin perder la vista actual")**: colapsar/expandir el sidebar **nunca**
dispara una navegación ni desmonta el `<router-outlet>` — es puramente un cambio de ancho/clase
CSS sobre `<aside>` y de margen sobre el contenedor de contenido, igual que hoy lo es
`sidebarOpen` para `SidebarComponent`.

**Garantía de FR-007 (tooltip)**: cuando `desktopCollapsed()` es `true`, cada botón de ítem lleva
`title`, `aria-label` y un `<span role="tooltip">` propio visible por `:hover`/`:focus-visible`
(research R7) — verificable navegando el sidebar colapsado solo con Tab y comprobando que cada
ítem enfocado muestra su nombre.
