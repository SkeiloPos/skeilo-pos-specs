# Contrato — Tema claro/oscuro del marco del panel

**Spec**: [../spec.md](../spec.md) (FR-009 a FR-017, y FR-010/FR-018 a FR-022 ampliados en la
sesión 2026-10-13) | **Research**: [../research.md](../research.md) R3, R4, R5, R15-R19 | **Data
model**: [../data-model.md](../data-model.md) §1, §2, §6

> **§1 reescrita en la iteración 2026-10-13.** La versión original (iteración 2026-10-12) acotaba
> `.panel-theme` exclusivamente al marco (sidebar/navbar/fondo). FR-010 se amplió para cubrir
> también el contenido de cada módulo — la versión de abajo es la vigente; la original queda solo
> en el historial de git.

## 1. Alcance de la clase `.panel-theme` (vigente desde 2026-10-13)

`.panel-theme` se sigue aplicando **únicamente** en la raíz de `DashboardLayoutComponent`
(`shell-root`), condicionada a `!isSuperAdmin()` — eso no cambió. Lo que cambió es **qué puede
estilar** una vez aplicada: ya no se limita al marco, cubre **todo** el subárbol de ese nodo,
incluyendo el contenido que el `<router-outlet>` de tenant proyecte (tablas, formularios,
tarjetas, gráficas, y cualquier modal/menú desplegable que ese contenido abra — FR-010 ampliado).

El mecanismo (research R16) **no es** una regla CSS por componente: es la redeclaración, bajo
`.panel-theme[data-theme='dark']`, de las variables de tema que Tailwind CSS v4 ya usa para
generar sus propias utilidades (`--color-gray-50` … `--color-gray-900`, `--color-slate-*`) más un
conjunto cerrado de selectores dirigidos para `white`/`black` (§6). Ningún componente de ningún
módulo necesita saber que `.panel-theme` existe, ni leer `PanelThemeService` — las clases Tailwind
que ya usan (`bg-white`, `text-gray-900`, etc.) se repintan solas por herencia de variables CSS.

**Las tres excepciones explícitas, cada una con su propio mecanismo**:

1. **Super Admin**: nunca está bajo `.panel-theme` (no cambió — `!isSuperAdmin()` sigue siendo la
   única condición de la clase).
2. **Pantallas públicas de autenticación** (`.auth-theme`, spec 095): un árbol de rutas
   completamente distinto, nunca anidado bajo `DashboardLayoutComponent`. No necesita ninguna
   exclusión activa — simplemente nunca está bajo `.panel-theme`.
3. **Superficies de impresión/exportación** (`app-cash-report`, `app-table-qr-sheet`): **sí** están
   dentro del árbol de `.panel-theme` (research R17) y por tanto necesitan una exclusión **activa**:
   la clase `.force-light-surface` (§7), que re-fija las mismas variables de vuelta a su valor
   claro dentro de su propio subárbol.

Cualquier regla CSS que redeclare `--color-*`/`--panel-color-*` fuera de `styles.css` (p. ej. en el
`styles:` de un componente individual) es, por definición, una violación de este contrato — el
mecanismo entero depende de que exista **un solo lugar** donde se declaran estas variables.

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

## 6. Tokens de Tailwind redeclarados (FR-010 ampliado, research R16) — nuevo, 2026-10-13

`.panel-theme[data-theme='dark']` redeclara, además de los `--panel-color-*` de §2, estas
variables del propio sistema de temas de Tailwind CSS v4 — **alias**, no valores inventados, cada
uno apuntando a un `--panel-color-*` ya auditado:

| Variable de Tailwind | Valor (alias a) |
|---|---|
| `--color-gray-50`, `--color-slate-50` | `var(--panel-color-surface-elevated)` |
| `--color-gray-100`, `--color-gray-200`, `--color-slate-200` | `var(--panel-color-border)` |
| `--color-gray-300` | `var(--panel-color-border)` |
| `--color-gray-400`, `--color-slate-400` | `var(--panel-color-text-subtle)` |
| `--color-gray-500` | `var(--panel-color-text-muted)` |
| `--color-gray-600`, `--color-gray-700`, `--color-slate-700` | `var(--panel-color-text-secondary)` |
| `--color-gray-800`, `--color-gray-900`, `--color-slate-800` | `var(--panel-color-text-primary)` |

**Invariante**: `--color-white`, `--color-black` y cualquier color semántico de Tailwind
(`red-*`, `amber-*`, `green-*`, `emerald-*`, `indigo-*`, etc.) **NO se redeclaran** — ver research
R16 para por qué (`text-white` es texto de botón sobre fondo saturado; redeclarar `--color-white`
lo rompería). En su lugar, `white`/`black` se resuelven con selectores dirigidos:

```css
.panel-theme[data-theme='dark'] .bg-white,
.panel-theme[data-theme='dark'] .focus\:bg-white:focus,
.panel-theme[data-theme='dark'] .hover\:bg-white:hover {
  background-color: var(--panel-color-surface-card);
}
```

Cualquier adición futura a esta lista de selectores debe, igual que las de arriba, verificarse
contra un uso real en el código (research R16: la lista nace de un inventario exhaustivo, no de
una enumeración especulativa de todas las variantes que Tailwind podría generar).

## 7. `.force-light-surface` (FR-010, excepción de impresión/exportación, research R17) — nuevo, 2026-10-13

Aplicada en la raíz de `app-cash-report` y `app-table-qr-sheet` — **las dos únicas** superficies
del panel de tenant con esta clase. Re-fija, dentro de su propio subárbol, cada variable que §6
redeclaró, de vuelta a su valor claro original (no a un alias — el valor literal claro de
Tailwind), anulando la herencia de `.panel-theme[data-theme='dark']` solo ahí dentro:

```css
.panel-theme[data-theme='dark'] .force-light-surface {
  --color-gray-50: oklch(98.5% 0.002 247.839); /* … el resto de la tabla de §6, cada uno de vuelta a su valor claro */
}
```

**Garantía**: ningún componente marcado con `.force-light-surface` cambia su apariencia cuando
`panelThemeService.theme()` cambia — ni en pantalla ni al imprimir/exportar (FR-010). Ninguno de
los dos componentes necesita inyectar `PanelThemeService` para esto — es una propiedad puramente
CSS de su plantilla.

**No aplica** a `receipt.util.ts` (impresión de tickets/facturas): ese flujo construye un
documento HTML completamente aparte e imprime en un `<iframe>` oculto sin Tailwind ni los estilos
de la app (comentario propio del archivo) — nunca estuvo expuesto a `.panel-theme` y no necesita
ninguna exclusión activa.

## 8. Gráficas — `baseOptions(kind, theme)` (FR-010, Chart.js, research R19) — nuevo, 2026-10-13

```ts
export function baseOptions(kind: ValueKind, theme: 'light' | 'dark'): ChartOptions<'bar'>;
```

**Garantías**:
- Los colores de ejes/rejilla/tooltip (antes `INK`/`MUTED`/`GRID`/`'#111827'` fijos) dependen de
  `theme` — los únicos 3 consumidores (`bars-chart`, `ranked-bars-chart`, `share-bar-chart`)
  pasan `panelThemeService.theme()` en su propio `computed()`.
- `CHART_COLORS` (la paleta categórica de 5 series) **no cambia con el tema** — identifica datos,
  no superficie (mismo criterio que los colores semánticos de Tailwind en §6).
- `seriesColor()`/`PRIMARY_SERIES` no reciben parámetro de tema — no lo necesitan, por la garantía
  anterior.

## 9. Sincronización del `cdk-overlay-container` (FR-010, overlay de CDK, research R18) — nuevo, 2026-10-13

`DashboardLayoutComponent` inyecta `OverlayContainer` (`@angular/cdk/overlay`) y mantiene, con un
`effect()`, la clase `panel-theme` y el atributo `data-theme` sobre
`overlayContainer.getContainerElement()` en sincronía con `!isSuperAdmin()` y
`panelThemeService.theme()` — el mismo par que ya lleva `shell-root`. Como el contenedor es
**compartido por toda la aplicación** (Angular CDK crea uno solo), esta sincronización cubre
automáticamente cualquier `cdkConnectedOverlay` presente o futuro (hoy, solo
`promotions-page.component.ts`) sin que ese módulo tenga que hacer nada.

## 10. Scrollbar y `<select>` en oscuro (FR-023, FR-024, research R22) — nuevo, 2026-10-14

**Scrollbar (FR-024)**: una sola declaración en el bloque base `.panel-theme`:

```css
.panel-theme {
  scrollbar-color: var(--panel-color-border) transparent;
  scrollbar-width: thin;
}
```

`scrollbar-color` se hereda igual que `color` — como `--panel-color-border` ya cambia de valor
dentro de `.panel-theme[data-theme='dark']` (§2), esta única declaración resuelve ambos temas sin
repetirla ahí. Propiedades estándar, sin `::-webkit-scrollbar`, sin dependencias nuevas.

**`<select>` (FR-023)**: una regla por elemento, no por variable, porque un `<select>` sin
ninguna clase de color de Tailwind no pasa por ninguna de las variables de §6:

```css
.panel-theme[data-theme='dark'] select {
  background-color: var(--panel-color-surface-card);
  color: var(--panel-color-text-secondary);
  border-color: var(--panel-color-border);
}
```

Su especificidad (una clase + un atributo + un tipo) es menor que la de cualquier utilidad de
Tailwind ya presente en un `<select>` existente (`.bg-white`, `.text-gray-*`, `.border-gray-*`),
así que donde un `<select>` ya tenga esas clases esta regla no cambia el valor final — solo actúa
donde no había ninguna clase de color, cubriendo por construcción cualquier `<select>` futuro.

## 11. Íconos sobre fondo pastel e insignia de degradado (FR-025, FR-010, research R23) — nuevo, 2026-10-14

**Íconos sobre fondo pastel/semántico fijo (FR-025)**: a diferencia de `gray`/`slate` (§6), los
colores semánticos (`indigo`, `amber`, etc.) no se redeclaran bajo `.panel-theme[data-theme='dark']`
a propósito (§6 ya lo justifica: redeclararlos rompería botones primarios y acentos de marca). Un
ícono sin su propia clase `text-*` dentro de un contenedor `bg-{color}-50` fijo hereda el `color`
ambiental de `.panel-theme` (casi blanco en oscuro) en vez del color de esa insignia — se vuelve
invisible contra el fondo pastel, que tampoco cambió. No hay una variable CSS única que resuelva
esto para todas las insignias (cada una usa un color semántico distinto) — la corrección es darle
al ícono su propio `text-{color}-600`, igual al patrón ya usado correctamente en el resto del
panel (`orders-page.component.ts:103`), no una regla CSS nueva.

**Degradado de `via-white`/`to-white` (FR-010)**: Tailwind v4 no les fija `background-color` —
fijan `--tw-gradient-via`/`--tw-gradient-to`, consumidas por
`background-image: linear-gradient(var(--tw-gradient-stops))` en `.bg-gradient-to-*`. La lista de
§... (selectores de superficie clara, `.bg-white`) no los alcanza por construcción, aunque tengan
"white" en el nombre. Se sobrescriben esas variables de degradado directamente:

```css
.panel-theme[data-theme='dark'] .via-white {
  --tw-gradient-via: var(--panel-color-surface-card);
}
.panel-theme[data-theme='dark'] .to-white {
  --tw-gradient-to: var(--panel-color-surface-card);
}
```

Un acento de degradado que no sea `white`/`black` (p. ej. `from-indigo-50/40`) se deja sin tocar
cuando es decorativo y de baja intensidad — confirmado caso por caso con el usuario, no asumido.
