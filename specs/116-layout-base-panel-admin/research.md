# Research — Fase 0: Layout base del panel (Sidebar + Navbar) con tema claro/oscuro persistente

**Spec**: [spec.md](./spec.md) | **Fecha**: 2026-10-12

La spec llegó sin ningún `NEEDS CLARIFICATION`: su sesión de clarificación ya cerró el "qué"
(diez preguntas, ver spec.md). Lo que esta fase resuelve es el "cómo", contra el código real de
`pos-heladeria` y contra los archivos de diseño reales (`Layout base.dc.html` y su sistema de
tokens), no contra el pedido en abstracto. Cada decisión se numera **R1, R2, …** para no
confundirse con las decisiones de negocio de la spec (citadas como **Clarification Q1…Q10** o
como **Decisión A-xxx** del registro de anomalías).

**Fuentes verificadas**: `pos-heladeria` en `/home/leonardo-gomez/Documentos/skeilo/pos-heladeria`
(rama `main`); el archivo de diseño de referencia en
`~/Escritorio/SkeiloPOS App diseñada/Layout base.dc.html` y su sistema de tokens en
`~/Escritorio/SkeiloPOS App diseñada/_ds/skeilopos-design-system-071995f1-.../tokens/*.css`
(colors.css, theme-light.css, typography.css, spacing.css, effects.css, fonts.css) — el mismo
sistema de diseño que la spec 095 ya trasladó parcialmente a `.auth-theme`. `pos-backend` **no
participa**: ninguna FR de esta spec pide un endpoint nuevo ni modificado, y las reglas de
rol/plan que el sidebar debe preservar ya se resuelven hoy enteramente en el cliente.

---

## R1 — Un único shell compartido, con bifurcación por rol, en vez de duplicarlo

**Decisión**: `DashboardLayoutComponent` sigue siendo el único cascarón que `dashboard/routes.ts`
y `super-admin/routes.ts` montan como padre. Dentro de su plantilla, se bifurca por
`isSuperAdmin()`:

- `true` → sigue renderizando `<app-sidebar>` + `<app-header>` **exactamente como hoy**, sin
  ningún cambio. El panel de Super Admin queda fuera de alcance (Assumptions de la spec) y esta
  rama lo garantiza por construcción, no por disciplina.
- `false` (Administrador de tenant, Cajero, Mesero) → renderiza dos componentes **nuevos**,
  `<app-tenant-sidebar>` y `<app-tenant-header>`, que implementan el rediseño completo.

**Fundamento**: hoy `SidebarComponent`/`HeaderComponent` ya bifurcan internamente por
`isSuperAdmin()` (`sidebar.component.ts:108`), así que el patrón de "un shell, dos identidades"
ya existe en el proyecto — esta decisión lo extiende un nivel, en vez de inventar uno nuevo. La
alternativa de meter el rediseño dentro de los mismos `SidebarComponent`/`HeaderComponent` con un
`@if` gigante se descartó: el rediseño cambia paleta, tipografía, sistema de íconos, estructura
de grupos y mecánica de colapso al mismo tiempo — mezclar dos sistemas visuales completos dentro
de un mismo `template:` inline (ya largo hoy) es exactamente la clase de cambio que el Principio
VI pide separar en unidades verificables.

**Alternativas consideradas**:
- *Reescribir `SidebarComponent`/`HeaderComponent` in situ*: rechazada — repintaría también el
  panel de Super Admin, que la spec declara fuera de alcance (Assumptions), violando el Principio
  V si se intentara "arreglarlo de paso".
- *Un segundo componente de ruta padre (`TenantLayoutComponent`) separado de
  `DashboardLayoutComponent`*: rechazada por alcance — obligaría a tocar `dashboard/routes.ts` y
  duplicar la carga de `BootstrapService`/`RealtimeService` que `ngOnInit` ya hace una vez; la
  bifurcación interna consigue el mismo aislamiento sin tocar el enrutador.

**Consecuencia aceptada, documentada en vez de disimulada**: `SidebarComponent`/`HeaderComponent`
conservan su lógica de filtrado por rol/plan para ítems de **tenant** (`visibleItems`,
`groupedItems`), que a partir de esta spec **ya no es alcanzable desde la aplicación en
ejecución** (ningún usuario tenant volverá a montar ese componente), aunque sus tests
(`sidebar.component.spec.ts`) sigan verificándola. Es código muerto en producción, no un bug: se
acepta porque tocar ese componente para "limpiarlo" sería la refactorización no solicitada que el
Principio V prohíbe mezclar con esta funcionalidad. Queda como candidato explícito para una spec
de limpieza futura, si el panel de Super Admin llega a rediseñarse.

---

## R2 — Los íconos nuevos se añaden a `IconComponent` (`app-icon`), no a una librería nueva

**Decisión**: los ~18 íconos que el diseño de referencia pide y que el panel no tiene hoy
(`layout-dashboard`, `shopping-cart`, `layout-grid`, `qr-code`, `book-open`, `tags`, `cup-soda`,
`percent`, `package`, `truck`, `banknote`, `chart-column`, `menu`, `bell`, `moon`, `sun`,
`key-round`, `badge-check`, `log-out`) se añaden como nuevos `@case` de
`src/app/shared/icon/icon.component.ts`, copiando el `path` real de Lucide (SVG 24×24,
`stroke-width="2"`, trazo redondeado) para cada nombre — el mismo patrón, letra por letra, que ya
usa ese archivo para sus ~30 íconos actuales (`dashboard`, `reports`, `layers`, `chevron-down`,
…). **No se añade `lucide-angular` ni ninguna otra dependencia de íconos.**

**Fundamento**: `IconComponent` (`app-icon`) ya es, textualmente, "SVG artesanal estilo Lucide" —
su propio comentario dice *"no external icon library is configured"* — y varios de sus casos
actuales (`layers`, `chevron-down`, `receipt`, `users`, `settings`) **son** rutas reales de
Lucide ya copiadas a mano; `chevron-down` incluso lleva el comentario *"spec 092"*, o sea que
este es exactamente el mecanismo que el proyecto ya usa para incorporar un ícono nuevo del set de
Lucide cuando una spec lo pide. Repetirlo aquí no es una decisión nueva, es seguir la convención
existente. El Principio IX exige justificar toda dependencia nueva por el problema que resuelve,
las alternativas consideradas y el impacto — y aquí la justificación falla en el primer punto:
**no hay problema sin resolver**, porque el mecanismo para resolverlo ya está en el repositorio.

**Alternativas consideradas**:
- *`lucide-angular`*: cubre los íconos con fidelidad garantizada a la versión exacta de Lucide,
  pero es una dependencia nueva completa (paquete + su propio sistema de registro de íconos) para
  un problema que 18 líneas de `@case` ya resuelven, y que deja dos sistemas de íconos "estilo
  Lucide" convivir en el mismo repositorio (el artesanal y el real) sin que ninguna FR lo exija.
- *`app-mi-icon` (Material Icons Outlined) con nombres nuevos en `icon-catalog.ts`*: rechazada por
  la propia spec (clarificación: "se adopta el set de íconos del diseño de referencia", que es
  Lucide, no Material) y porque cambiaría la identidad visual del trazo (relleno outlined vs.
  trazo lineal) que el diseño de referencia pide.

**Riesgo que esto evita**: `app-icon` hoy solo se usa en el flujo público del comensal (menú QR,
checkout). Extenderlo para que también sirva al nuevo `app-tenant-sidebar`/`app-tenant-header` no
afecta esas pantallas (son `@case` nuevos, aditivos) ni reabre la decisión de la spec 082 de
migrar el panel admin a `app-mi-icon` — esa migración sigue vigente para **el resto del panel**
(contenido de cada módulo) y para el panel de Super Admin (R1); esta spec solo introduce una
segunda familia de íconos **acotada al marco** (sidebar/navbar), que es justo lo que las
Assumptions de la spec autorizan ("tokens visuales… solo al layout base").

---

## R3 — Los tokens de color salen del sistema de diseño real, en una clase `.panel-theme` nueva

**Decisión**: se crea un bloque de tokens CSS en `src/styles.css` (o un archivo nuevo importado
desde ahí), con la forma `.panel-theme { --panel-color-primary: #7C3AED; … }` para el tema claro
(valores por defecto) y `.panel-theme[data-theme="dark"] { --panel-color-primary: #7C3AED;
--panel-color-surface: #111827; … }` para el oscuro. La clase se aplica en la raíz de
`DashboardLayoutComponent` **solo cuando `!isSuperAdmin()`**:
`[class.panel-theme]="!sidebar.isSuperAdmin()"` junto con `[attr.data-theme]="theme()"`.

Los valores concretos, tomados literalmente de `tokens/colors.css` (paleta oscura, declarada en
`:root`) y `tokens/theme-light.css` (`[data-theme="light"]`, que sobreescribe `:root`) del
sistema de diseño entregado:

| Token (`--panel-color-*`) | Claro | Oscuro |
|---|---|---|
| `primary` | `#7C3AED` | `#7C3AED` |
| `primary-active` | `#6D28D9` | `#6D28D9` |
| `primary-soft` | `rgba(124,58,237,.10)` | `rgba(124,58,237,.16)` |
| `primary-text` | `#6D28D9` | `#A78BFA` |
| `surface` (fondo de sidebar/navbar) | `#FFFFFF` | `#111827` |
| `surface-card` (paneles flotantes: menú de usuario, notificaciones; §R13) | `#FFFFFF` | `#1E293B` |
| `surface-elevated` (menús, tarjetas del marco) | `#F1F5F9` | `#263449` |
| `canvas` (fondo del área de contenido) | `#F4F6F9` | `#090D16` |
| `border` | `#E5E9EF` | `#334155` |
| `text-primary` | `#090D16` | `#F8FAFC` |
| `text-secondary` | `#334155` | `#CBD5E1` |
| `text-muted` | `#64748B` | `#94A3B8` |
| `text-subtle` | `#94A3B8` | `#64748B` |
| `success` / `success-soft` (pill "Caja abierta") | `#6D28D9` / `rgba(124,58,237,.10)` | `#00FF87` / `rgba(0,255,135,.10)` |
| `error` (texto "Cerrar sesión"; §R13) | `#E11D48` | `#FB7185` (no `#F43F5E` real — ver §R13) |
| `overlay-hover` | `rgba(9,13,22,.05)` | `rgba(248,250,252,.06)` |

(`surface` = `--color-surface-soft` del sistema de diseño real en ambos temas —no
`--color-surface`—, confirmado leyendo `tokens/colors.css`/`theme-light.css` directamente en la
ronda de ajuste visual de §R13; `canvas` = `--color-canvas-dark` real. Ver §R13 para el detalle
completo de esta corrección y de `surface-card`.)

**Fundamento**: es el mismo patrón que la spec 095 ya validó para `.auth-theme` — una clase
**acotada**, nunca `:root`, para que las ~40 pantallas que esta spec no toca (ni el panel de
Super Admin) sigan en su paleta índigo actual sin que nadie se entere. La spec lo exige
explícitamente (Assumptions: "sin reemplazar los estilos ya usados en el resto de las pantallas
y módulos"). Los valores no son una interpretación: son los que el propio archivo de tokens del
sistema de diseño define para ambos temas — el mismo sistema que `Layout base.dc.html` consume
vía `var(--color-primary)`, etc.

**Tipografía**: se reutilizan los `@font-face` de `Figtree` y `Sora` que **ya existen**,
autoalojados, en `src/styles.css` (añadidos por la spec 095 para `.auth-theme`, líneas ~51-90) —
cero fuentes nuevas, cero CDN. `.panel-theme` fija `font-family: 'Figtree', ui-sans-serif,
system-ui, sans-serif` para texto de interfaz y `'Sora'` para los títulos de sección
(`h1`/`h2` del navbar), igual que el diseño de referencia.

**Alternativas consideradas**:
- *Variables en `:root`*: rechazada, repintaría toda la aplicación (Principio V).
- *Pedir al negocio los archivos de tokens antes de planear*: innecesario — los archivos ya
  existen en el equipo (`~/Escritorio/SkeiloPOS App diseñada/_ds/…/tokens/`), solo no estaban
  copiados al repositorio; esta spec los trae por primera vez, igual que la spec 095 trajo los
  suyos para `.auth-theme`.

---

## R4 — Sin parpadeo (FR-012): el tema se fija antes del primer pintado, con un script inline en `index.html`

**Decisión**: se añade un `<script>` inline, síncrono, en el `<head>` de `src/index.html`,
**antes** de `<app-root>`, que lee la clave de tema de `localStorage` (try/catch) y, si hay un
valor, lo fija como `data-theme` en un contenedor que Angular todavía no pintó — en la práctica,
como atributo en `<html>` o `<body>`, leído después por `.panel-theme` vía CSS heredado
(`:root[data-theme="dark"] .panel-theme { … }` o replicando el mismo atributo en el nodo raíz del
shell cuando Angular arranca). Si no hay valor guardado, el mismo script evalúa
`window.matchMedia('(prefers-color-scheme: dark)').matches` como aproximación (FR-013). Si
`localStorage` no está disponible, el `try/catch` lo deja en blanco y el CSS por defecto (claro)
se aplica sin error.

**Fundamento**: FR-012 exige que el tema se aplique "antes de que el contenido visible del panel
termine de pintarse" y SC-002 exige "sin percibir un parpadeo". Angular es **100% CSR** en este
proyecto (sin SSR; el único artefacto de build adicional es el Service Worker de
`ngsw-config.json`, que no interviene en el primer pintado): el primer HTML que llega al
navegador es el `index.html` estático, y `<app-root>` tarda milisegundos reales en montar
`DashboardLayoutComponent`. Si el atributo de tema se fijara solo dentro de ese componente (p. ej.
en su constructor), habría una ventana real — corta pero perceptible, y que SC-002 prohíbe
explícitamente — en la que el marco se pinta en el tema por defecto y luego cambia. Un script de
dos líneas en `index.html`, que no depende de Angular ni de zona alguna, es la única forma de que
el atributo exista en el DOM antes de que el navegador pinte el primer frame.

**Nota de alcance**: este script lee **una sola clave** (el tema) y no ejecuta lógica de negocio;
no es código de la aplicación Angular, por lo que no participa de sus tests de Vitest — se
verifica manualmente en [quickstart.md](./quickstart.md) (desactivando JS lo necesario para
confirmar que no rompe el resto de la carga, y con DevTools → Network throttling para observar el
primer frame).

**Alternativas consideradas**:
- *Fijar el tema solo en el constructor de `DashboardLayoutComponent`*: no cumple SC-002 por lo
  explicado arriba.
- *Angular SSR / hidratación*: fuera de alcance total — el proyecto no usa SSR y adoptarlo solo
  para esta spec sería una migración de arquitectura, prohibida por el Principio VI.

---

## R5 — El colapso de escritorio es un signal nuevo, separado del `sidebarOpen` existente

**Decisión**: `LayoutService` gana un signal nuevo, `desktopCollapsed` (persistido), que
**solo leen y escriben** los componentes nuevos (`app-tenant-sidebar`, `app-tenant-header`). El
signal `sidebarOpen` existente **no cambia de significado**: sigue siendo exactamente lo que es
hoy (drawer superpuesto en móvil/tablet; mostrar/ocultar por completo en escritorio), porque
sigue gobernando `SidebarComponent`/`HeaderComponent` (Super Admin, R1). Los componentes nuevos
reutilizan `sidebarOpen` **solo** para su propio drawer de móvil/tablet (la misma semántica:
"¿está el panel superpuesto visible?"), pero en escritorio ignoran `sidebarOpen` por completo y
leen `desktopCollapsed` para decidir entre 248px (expandido) y 72px (solo íconos) — nunca "oculto
por completo", que es el comportamiento *actual* de escritorio y que esta spec reemplaza
explícitamente para el tenant (FR-007), no para Super Admin.

**Hallazgo relevante**: hoy `sidebarOpen=false` en escritorio **no colapsa a íconos**, oculta el
sidebar por completo (`-translate-x-full`, sin margen para el contenido) — es un comportamiento
distinto al que FR-007 pide ("colapsar a una versión reducida (solo íconos)… sin perder la vista
actual"). No es un matiz: con el sidebar oculto no hay íconos que mostrar ni botones en los que
poner un tooltip. Por eso hace falta un estado nuevo, no basta reinterpretar el que ya existe.

**Fundamento de mantener dos signals separados en vez de uno**: `desktopCollapsed` se persiste
(FR-017) y `sidebarOpen` nunca se ha persistido ni esta spec lo pide para el drawer móvil (el
Edge Case solo exige persistir "el estado de colapso… en pantallas de escritorio"). Fusionarlos
obligaría a decidir qué pasa con el valor persistido cuando el usuario cruza el punto de quiebre
en vivo (R6) — separarlos lo vuelve trivial: cada signal vive en su propio régimen y el punto de
quiebre solo decide **cuál de los dos se usa para pintar**, nunca los reescribe entre sí.

**Alternativas consideradas**: *añadir un tercer valor "colapsado" al mismo `sidebarOpen`
booleano, convirtiéndolo en un enum de tres estados*: rechazada — habría obligado a auditar y
actualizar las clases condicionales de `SidebarComponent`/`dashboard-layout.component.ts` (Super
Admin) para el valor nuevo que nunca van a producir, aumentando el riesgo sobre código fuera de
alcance a cambio de nada.

---

## R6 — El punto de quiebre se vuelve reactivo, pero solo dentro del árbol nuevo

**Decisión**: se añade un listener de `resize` (con un debounce corto, p. ej. 150 ms, para no
recalcular en cada píxel) que solo se registra **desde el constructor de `app-tenant-sidebar`**
(con `DestroyRef`/`takeUntilDestroyed()` para desregistrarlo al destruirse) y que actualiza un
signal de modo (`'desktop' | 'drawer'`) usado únicamente por los componentes nuevos. **No se
añade ningún listener global ni se toca el constructor de `LayoutService`.**

**Hallazgo**: hoy no existe ningún listener de `resize` en todo el layout — el ancho de ventana
solo se lee una vez, al construirse `LayoutService`, y aparte se compara puntualmente en cada
`NavigationEnd` (`dashboard-layout.component.ts:136`). El Edge Case "el usuario cambia el tamaño
de la ventana… cruzando el punto de quiebre… sin recargar" **no se cumple hoy para nadie**, ni
siquiera para Super Admin. Esta spec lo exige solo para el panel de tenant (es un Edge Case de
*esta* spec); por eso el listener se añade acotado al árbol nuevo, no al servicio compartido —
así Super Admin no gana una reactividad que ninguna spec le pidió y que podría cambiar algo de su
comportamiento actual sin autorización (Principio V).

**Alternativas consideradas**: *`@angular/cdk/layout` `BreakpointObserver`*: el CDK ya es una
dependencia del proyecto (`@angular/cdk ^21.2.14`), así que usarlo no añade nada nuevo al
Principio IX y es más robusto que un listener manual (usa `matchMedia`, no un evento de `resize`
sin debounce). **Se adopta como mecanismo**, en vez de un listener manual — la decisión de
"dónde" (solo en el árbol nuevo) no cambia, solo el "cómo" mejora: `BreakpointObserver.observe('(min-width: 1024px)')`
dentro de `app-tenant-sidebar`, convertido a signal con `toSignal()`.

---

## R7 — El tooltip del ícono colapsado es CSS puro, sin dependencia nueva

**Decisión**: cada botón de navegación lleva `title="{{ item.label }}"` (igual que el HTML de
referencia) como respaldo nativo, más un `<span role="tooltip">` propio, posicionado con CSS
absoluto, que se vuelve visible con `:hover` y con `:focus-visible` sobre el botón — ambos
definidos en CSS plano, sin JavaScript ni overlay. El botón conserva además su `aria-label` con
el nombre completo del ítem.

**Fundamento**: FR-007 exige el tooltip "al pasar el mouse **o dar foco de teclado**". El
atributo `title` nativo —que es lo que usa el propio `Layout base.dc.html`— solo se muestra de
forma confiable con el mouse; la mayoría de navegadores no lo muestra al enfocar con Tab, así que
por sí solo no basta. Un tooltip en CSS con `:focus-visible` cubre el hueco sin añadir nada: ni
`@angular/material` (que traería `MatTooltip`, pensado para esto, pero es una dependencia nueva
completa solo para un tooltip), ni `@angular/cdk/overlay` a mano (reinventa posicionamiento,
scroll y z-index para un caso que no lo necesita, porque el ítem colapsado tiene una posición fija
y predecible dentro de una barra de 72px).

**Alternativas consideradas**: *`@angular/material` solo por `MatTooltip`*: rechazada por el
Principio IX — el problema (un tooltip sobre un ícono en una posición fija) no justifica una
librería de componentes completa. *Dejar solo `title` nativo*: rechazada porque no cumple la
mitad de FR-007 (teclado).

---

## R8 — El indicador "Caja N abierta" del navbar nuevo lee `CashService`, con una carga mínima añadida

**Decisión**: `app-tenant-header` inyecta `CashService` (ya `providedIn: 'root'`, el mismo
singleton que usa hoy `pos-terminal-header.component.ts` a través de `PosTerminalStore`) y
muestra el indicador a partir de `cashService.isOpen()` / `cashService.shift()`, **solo para
roles con acceso a Caja** (`ADMIN`, `CASHIER` — `MESERO` no lo ve, igual que hoy no ve el ítem
"Caja" en el sidebar). En su inicialización, si `!cashService.shift()`, llama una vez a
`cashService.discoverOpenShift()` — el mismo método, sin modificar, que `PosTerminalStore` ya usa
con el mismo guard (`this.cash.shift() ? null : this.cash.discoverOpenShift()`,
`pos-terminal.store.ts:1281`) — para que el indicador sea correcto incluso si el usuario no ha
visitado antes Caja o Terminal de Mesas en esa sesión.

**Hallazgo que esto corrige**: `CashService.shift` es un estado compartido que hoy solo se llena
cuando el usuario visita Caja (`cash-session.store.ts:258`) o Terminal de Mesas
(`pos-terminal.store.ts:1281`). Si el navbar nuevo leyera el signal sin más, un cajero que entra
directo a "Ventas" vería "sin turno" aunque sí tenga uno abierto, hasta que visite una de esas dos
pantallas — un indicador incorrecto es peor que no tenerlo. La llamada a `discoverOpenShift()` ya
existe y ya hace exactamente esta averiguación (consulta las cajas y busca el turno abierto); esta
spec solo la dispara un poco antes, desde un tercer sitio, sin crear un endpoint ni cambiar su
contrato — consistente con la Assumption de la spec ("ya existen como funcionalidades del panel;
esta spec solo cubre su presentación").

**Nota de alcance aceptada**: esto añade una petición HTTP de lectura (`GET /cash/registers` o la
que `discoverOpenShift()` ya dispare) en cada carga del panel para `ADMIN`/`CASHIER`, que hoy no
ocurre hasta que visitan Caja o Terminal. Es una petición ya existente, movida más temprano, no
una nueva superficie de red — se documenta aquí en vez de disimularla, siguiendo el mismo
criterio de la spec 095 al aceptar y anotar sus propias consecuencias técnicas.

---

## R9 — El "Sede Laureles" del mockup no tiene con qué llenarse; se omite

**Hallazgo**: el diseño de referencia muestra, bajo el nombre del negocio, una segunda línea con
el nombre de la sede ("Sede Laureles"). El sistema actual **no tiene** concepto de sede/sucursal
— `TenantInfoService` solo expone `businessName` y `logoUrl` (verificado en
`tenant-info.service.ts:60-67`); no hay ninguna entidad "sede" en el panel.

**Decisión**: el encabezado del sidebar nuevo muestra una sola línea (el nombre del negocio,
truncado, igual que hoy) y omite la segunda. Es consistente con las Assumptions de la spec
("fuente de verdad visual… no código a trasladar literalmente") y con el propio Edge Case de la
spec sobre el nombre largo del tenant, que habla solo de truncar un nombre, no de una sede.
Inventar una sede falsa o repetir el nombre del negocio en dos líneas sería mostrar información
que no existe. Si el negocio llega a modelar sucursales, esa segunda línea es una spec propia.

---

**Nota de vocabulario**: spec.md usa el término "Staff" para el tercer rol del panel (Historias
1 y 3, Clarification Q7, Assumptions). Este plan y los artefactos siguientes lo traducen a
`UserRole.MESERO` — el rol de mesero, con acceso a Órdenes y Terminal de Mesas — y no al alias
`STAFF` que el frontend definió en una fase anterior y que hoy mapea a `CASHIER`
(`user.interface.ts:26-32`, ya deprecado: su pantalla de inicio era el tablero de cocina). Se
documenta aquí para que la traducción sea explícita y no una inferencia tácita.

---

## R10 — Ningún cambio requiere una entrada nueva en el registro de anomalías

**Decisión**: esta spec **no** añade entradas a
`specs/000-reconocimiento/registro-de-anomalias.md`.

**Fundamento**: el Principio II exige registrar ahí los cambios de **comportamiento** existente
—no los cambios de presentación—, con el mismo criterio que la spec 095 ya aplicó: sus entradas
A-108 a A-111 cubrieron un mensaje de error que deja de distinguir dos casos, un destino de
redirección que cambia y un hallazgo de seguridad — nunca la paleta, la tipografía ni los íconos,
que cambiaron igual de radicalmente (R3 revocada) sin generar ninguna entrada. Aplicando el mismo
criterio aquí:

- **Reagrupación, reetiquetado y reiconografía del sidebar** (FR-001 a FR-003): presentación de
  las mismas rutas, con las mismas reglas de acceso — nada que un usuario pueda "hacer" hoy
  deja de poder hacerlo ni empieza a poder hacer algo nuevo.
- **Colapso a solo-íconos en escritorio** (FR-007, R5): es un control de interfaz (el botón de
  menú) cuyo efecto visual cambia, pero no estaba protegido por ninguna decisión de negocio
  documentada — era un efecto secundario de cómo se implementó `sidebarOpen`, no una regla que el
  negocio hubiera fijado deliberadamente. La propia spec, ya aprobada, define el efecto nuevo
  (Principio IV: un spec nuevo puede introducir comportamiento nuevo).
- **Tema oscuro** (FR-009 a FR-017): es aditivo — nadie pierde el tema claro, que sigue siendo el
  predeterminado (FR-013).

No hay ningún caso, a diferencia de spec 095, donde el comportamiento *nuevo* contradiga una regla
de negocio *ya documentada en otra parte* (como el mensaje de error de login) — por eso no aplica
la obligación de registrar.

---

## R11 — Qué queda explícitamente fuera, aunque el mockup lo muestre

| Elemento del mockup | Por qué no se implementa |
|---|---|
| Segunda línea "Sede Laureles" bajo el nombre del negocio | No existe el concepto de sede (R9). |
| Transiciones animadas de página (`phase`, `bar` de progreso superior) | Ninguna FR las pide; son adorno del prototipo, no estructura ni accesibilidad. Añadirlas sería alcance no solicitado (Principio V). |
| Tarjetas/filas de ejemplo del área de contenido (`cards`, `rowsL`) | Son contenido de muestra del prototipo, no del layout; el contenido real de cada módulo existente no se toca (Assumptions de la spec). |
| Punto de quiebre intermedio "tablet" (1100px/768px) del prototipo | La spec fija un único punto de quiebre, el ya vigente (1024px) — Clarification Q4. |
| Semántica de colores exacta de `--color-info`/`--color-warning` | No hay ningún control del marco (sidebar/navbar/fondo) que las necesite; se incorporan solo los tokens que R3 usa. |

---

## R12 — FR-015 (scroll independiente) se hereda sin cambios del shell existente

**Hallazgo**: FR-015 exige que el área de contenido principal tenga desplazamiento (scroll)
independiente del Sidebar y del Navbar. El shell compartido (`dashboard-layout.component.ts`)
ya resuelve esto hoy con `shell-root flex h-screen overflow-hidden` → `shell-content
overflow-hidden` → `shell-main overflow-y-auto` envolviendo el `<router-outlet>`.

**Decisión**: ninguna tarea de esta spec modifica esa estructura de contenedores — T020 solo
reemplaza qué se monta dentro (`<app-sidebar>`/`<app-header>` vs. `<app-tenant-sidebar>`/
`<app-tenant-header>`), nunca el wrapper `shell-root`/`shell-content`/`shell-main` que ya
garantiza el scroll independiente. FR-015 se satisface por herencia estructural, no por una
tarea nueva — se documenta aquí para cerrar la cadena de trazabilidad (Principio XII); ver
verificación en quickstart.md §2.

---

## R13 — Ajuste visual post-implementación: `Layout base.dc.html` estaba desactualizado

**Contexto**: tras implementar y verificar la spec (T001-T032, Fase 6 completa), el usuario señaló
que el archivo de diseño usado (`Layout base.dc.html`, una maqueta aislada de 121 líneas) estaba
desactualizado frente al archivo completo real de la app, `SkeiloPOS App.dc.html` (1922 líneas,
misma carpeta de diseños), que pasa a ser la fuente de verdad visual (spec.md, Clarifications,
sesión 2026-10-12). Alcance confirmado con el usuario: **solo** ajuste visual — las transiciones y
animaciones ya implementadas no se tocan.

**Hallazgos al leer `SkeiloPOS App.dc.html` (líneas 59-123, el sidebar+navbar completo) y los
archivos de tokens reales (`_ds/.../tokens/colors.css`, `theme-light.css`) directamente**:

1. **Dos errores reales de valor de color** en la tabla de R3 (no visibles sin leer el CSS fuente
   directamente, exactamente el riesgo que panel-theme-contract.md §2 ya advertía — "debe
   confirmarse, no asumirse"): `canvas` claro es `#F4F6F9` (`--color-canvas-dark` real), no
   `#EDF1F5` (que en realidad es `--color-surface-soft`); y `surface` (fondo de sidebar/navbar) en
   AMBOS temas corresponde a `--color-surface-soft` del sistema real, no a `--color-surface` —el
   prototipo usa un tono "hundido" para el marco, distinto del tono "tarjeta" que usan los paneles
   flotantes (ver punto 2). Corregido en la tabla de R3 y en `styles.css`.
2. **Token nuevo `surface-card`** (`--color-surface` real: `#FFFFFF` claro — igual que `surface`
   — / `#1E293B` oscuro — **distinto** de `surface` `#111827`): el menú de usuario, el panel de
   notificaciones y el botón-píldora del usuario usan este tono en el prototipo real, no el mismo
   fondo que el propio sidebar/navbar. Solo se nota la diferencia en tema oscuro.
3. **El botón de colapso del sidebar se reubicó**: en el prototipo real vive DENTRO del propio
   sidebar (junto al logo/nombre del negocio), no en el navbar. El navbar solo conserva un botón
   de menú, y únicamente en modo `'drawer'` (<1024px) — en escritorio el navbar no tiene ningún
   control de menú. Esto simplifica `TenantHeaderComponent` (ya no necesita comportamiento dual)
   y añade el control a `TenantSidebarComponent`.
4. **Barra de acento del ítem activo**: una línea de 3px (`--panel-color-primary`) a la izquierda
   del ítem, además del fondo `primary-soft` ya implementado.
5. **Pie del sidebar**: el prototipo añade una marca "SkeiloPOS" (ícono + wordmark) al fondo del
   sidebar, con `/logo.svg` ya existente en el repo. El prototipo también muestra un botón "Ayuda"
   que se **omite** (spec.md, Clarifications): no existe ninguna pantalla, ruta ni enlace de
   soporte real en el panel hoy — agregarlo sin acción sería UI muerta o alcance nuevo no
   solicitado (mismo criterio que R9 para la línea "Sede Laureles").
6. **Botones del navbar unificados**: bell/tema/menú-drawer pasan de "ícono simple con hover" a
   un estilo cuadrado 36px bordeado (`border` + `surface` + hover `surface-elevated`), consistente
   entre los tres.
7. **Avatar y botón de usuario**: avatar con fondo `primary-soft`/texto `primary-text` (no sólido
   + blanco); botón en forma de píldora (`border-radius: 999px`) con borde, fondo `surface-card`
   (punto 2), y un ícono `chevron-down` al final (nuevo `@case` ya existía en `IconComponent`).
   Se añade el rol (Administrador/Cajero/Mesero) bajo el nombre, mismo texto que ya usa
   `ROLE_LABELS` en `header.component.ts` legado, sin su badge de color.
8. **Orden del menú de usuario**: "Cambiar contraseña" antes que "Mi plan" (antes al revés),
   seguido de un divisor y "Cerrar sesión" — reordenamiento puro, sin cambiar destinos.
9. **Texto "Salir" vs. "Cerrar sesión"** (spec.md, Clarifications): el prototipo dice "Salir"; se
   **mantiene** "Cerrar sesión" por consistencia con el resto del panel de staff (`header.component.ts`
   legado también dice "Cerrar sesión"; "Salir" en el código hoy solo aparece en el menú QR del
   comensal, audiencia distinta).
10. **Indicador de caja**: el prototipo usa un punto de color de 8px en vez de un ícono de
    billete — cambiado para igualar.
11. **Nuevo ícono**: `panel-left` (botón de colapso), añadido a `IconComponent` con el mismo
    patrón artesanal de R2.

**Verificación**: recorrido manual repetido en Chrome real (ambos temas, ambos modos de vista,
colapsado/expandido, tooltip, dropdowns) y Lighthouse Accessibility re-auditado en ambos temas —
sin ninguna regresión de contraste ni de puntuación frente a la ronda de verificación original
(T030); los 3 hallazgos de `color-contrast` restantes en cada auditoría siguen siendo,
exactamente igual que antes, contenido preexistente de `app-admin-dashboard` ajeno a esta spec.
Regresión automatizada: los 8 archivos de esta spec (ahora 91 tests) pasan limpio y
determinístico en corridas aisladas; la corrida completa de la suite mostró más fallos que la
línea base por tener `pos-api`/`ng serve` corriendo en paralelo durante la corrida (memoria del
proyecto: nunca correr frontend+backend completos en paralelo), no por una regresión real —
confirmado reejecutando en aislamiento cada archivo marcado como fallido.

---

## Resumen de incógnitas resueltas

| Incógnita | Resuelta en |
|---|---|
| Cómo convive el rediseño con el panel de Super Admin sin tocarlo | R1 |
| De dónde salen los íconos sin añadir una dependencia | R2 |
| De dónde salen los colores y la tipografía de ambos temas | R3 |
| Cómo evitar el parpadeo del tema al cargar | R4 |
| Qué significa "colapsar a solo íconos" frente al "ocultar" actual | R5 |
| Cómo reaccionar en vivo al cruzar el punto de quiebre sin afectar a Super Admin | R6 |
| Cómo mostrar un tooltip accesible por teclado sin dependencia nueva | R7 |
| De dónde sale el indicador de caja del navbar, y por qué hace falta una carga más | R8 |
| Qué hacer con el renglón de "sede" del mockup | R9 |
| Si algo de esto necesita una entrada en el registro de anomalías | R10 |
| Qué del mockup se deja fuera a propósito | R11 |
| Si FR-015 (scroll independiente) necesita una tarea nueva | R12 |
| Qué cambia al corregir la referencia visual a `SkeiloPOS App.dc.html` | R13 |
| Tres bugs reales encontrados tras R13 (animación, logo del pie, logo del encabezado) | R14 |

**Dependencias nuevas**: ninguna (Principio IX satisfecho por ausencia — R2, R6 usa
`@angular/cdk`, ya presente). **Cambios en `pos-backend`**: ninguno. **Migraciones**: ninguna.
**Entradas nuevas en el registro de anomalías**: ninguna (R10).

---

## R14 — Tres bugs reales encontrados al verificar R13 en Chrome real

Tras aplicar el ajuste visual de R13, el usuario probó el resultado y reportó tres defectos
concretos (no ambigüedades de spec) — ninguno requirió una pregunta de clarificación porque cada
uno tenía una causa raíz verificable empíricamente en el navegador.

**1. La animación de apertura/cierre del drawer (móvil/tablet) no se veía — solo el colapso de
escritorio animaba.** Causa raíz confirmada leyendo `getComputedStyle` en vivo: Tailwind CSS 4
mueve las utilidades `translate-x-*`/`-translate-x-full` a la propiedad CSS nativa `translate`
(ya no usan `transform: translateX(...)`). La clase de transición del `<aside>` era
`transition-[transform,width]` — observaba `transform`, que nunca cambia (permanece `none`,
porque el movimiento real ocurre en `translate`), así que el salto era instantáneo. El colapso de
escritorio sí animaba porque usa la propiedad `width`, que SÍ estaba en la lista observada.
**Corregido**: `transition-[translate,width]`. Verificado muestreando `getComputedStyle(aside).translate`
cada 30ms durante la apertura — interpola suavemente de `-100%` a `0%` en ~200ms.

**2. El logo del pie del sidebar no era el oficial del sistema de diseño.** Se había usado
`/logo.svg` (el ícono cuadrado índigo + remolino blanco del favicon/PWA, un activo *distinto* y
más antiguo) en vez del wordmark horizontal real. El wordmark real vive en
`_ds/.../assets/logo-horizontal-{violeta-fondo-claro,degradado-fondo-oscuro}-1200px.png`
(confirmado en el `readme.md` del sistema de diseño: "dos versiones oficiales horizontales...
`Wordmark` intercambia automáticamente por tema"). La versión clara (ícono violeta + texto tinta)
resultó ser **exactamente** el mismo archivo que `public/images/logo-horizontal.webp`, ya en el
repo (usado hoy en el login) — reutilizado sin cambios. La versión oscura (ícono degradado
violeta→verde + texto "Pure Ice" casi blanco) no existía en el repo — se convirtió el PNG oficial
a webp (`cwebp -q 90`) y se agregó como `public/images/logo-horizontal-dark.webp` (14 KB).
`PanelThemeService` ahora se inyecta en `TenantSidebarComponent` para elegir el archivo correcto
por tema. Colapsado, se recorta al ícono con la MISMA técnica que usa el propio prototipo
(`width:{{ logoW }}` + `overflow:hidden` alrededor de una única imagen del lockup completo) en vez
de usar un segundo activo: un contenedor de ancho fijo (24px colapsado, 128px expandido) con
`overflow-hidden` recorta la misma imagen (altura fija `h-8`, `width:auto`), mostrando solo el
ícono (columnas 66-289 de los 1200px del PNG original, confirmado analizando el canal alfa) cuando
no hay espacio para el texto.

**3. El logo del encabezado se deformaba al colapsar el sidebar.** Causa raíz confirmada midiendo
`getBoundingClientRect()`: a 72px de ancho, el logo (36px) + separación (8px) + el botón de
colapso (32px) + relleno (16px) suman 92px — no caben en 72px. El contenedor flexible exterior
(`justify-between`) comprimía al contenedor interno del logo (`flex-1`) por debajo de 36px, y el
elemento `<img>` (a diferencia de un `<span>`) hereda `max-width: 100%` del *preflight* de
Tailwind — con su contenedor ya comprimido, ese `max-width` ganaba sobre el `width: 2.25rem` fijo
(`w-9`), aplastando la imagen en vez de desbordarla. Mismo riesgo latente en la imagen nueva del
pie de R14.2, por lo que ambas llevan `max-w-none` como defensa. **Corrección de layout**: en vez
de pelear por espacio en una fila, el encabezado colapsado apila logo y botón en **columna**
centrada (`flex-col`, sin `justify-between`) — cada uno recibe los 72px completos para sí, sin
compresión posible.

**Verificación**: recorrido manual repetido en Chrome real, ambos temas, ambos modos de vista,
colapsado/expandido; Lighthouse Accessibility re-auditado (95, mismos 3 hallazgos preexistentes
ajenos a esta spec, sin regresión); 91 tests (8 archivos) en verde de forma aislada.

---

# Research — Fase 0 (continuación), sesión 2026-10-13: tema global + micro-interacciones de carga

**Contexto**: T001-T032 y el ajuste de R13/R14 ya están fusionados en `develop` de `pos-heladeria`
(PR #36). Esta sección resuelve el "cómo" de la ampliación de alcance de la sesión de
clarificación 2026-10-13 (spec.md): FR-018 a FR-022, FR-010 ampliado, SC-007 a SC-009, Historia de
Usuario 4. Sigue la misma numeración corrida (**R15** en adelante) para no romper las referencias
cruzadas ya citadas en tasks.md/quickstart.md de la primera iteración.

**Fuentes verificadas de nuevo para esta sesión**: el código real ya fusionado
(`panel-theme.service.ts`, `layout.service.ts`, `dashboard-layout.component.ts`,
`tenant-sidebar.component.ts`, `tenant-header.component.ts`, `styles.css` líneas 419-490); el
archivo de diseño `~/Escritorio/SkeiloPOS App diseñada/Layout base.dc.html` completo, incluyendo
su script de lógica (`<script type="text/x-dc" data-dc-script>`, líneas 83-118) que define
literalmente la coreografía de `nav()`/`phase`/`bar` que las Historias 4 piden; una compilación
aislada real de Tailwind CSS v4.3.0 (vía `@tailwindcss/postcss` + `postcss`, ya presentes en
`node_modules` de `pos-heladeria`) para confirmar, no asumir, cómo emite sus utilidades; y un
inventario exhaustivo (`grep -rhoE`, no una muestra) de clases Tailwind de color en los 124
archivos de producción de los ~18 módulos de tenant listados en Assumptions.

---

## R15 — `Layout base.dc.html` vuelve a ser la fuente de verdad; un delta estructural real, no solo cosmético

**Hallazgo confirmado leyendo el archivo completo** (no solo el resumen de R13, que describía el
otro archivo, `SkeiloPOS App.dc.html`): el botón de colapso del sidebar en escritorio **vive en el
`<header>`** en `Layout base.dc.html` (línea 52, `onClick="{{ toggleSide }}"`, ícono `menu`), **no
dentro del propio `<aside>`** como R13 decidió para el otro archivo (y como ya está implementado en
`tenant-sidebar.component.ts` hoy). Es el mismo botón que en modo `'drawer'` abre/cierra el menú
superpuesto (`toggleSide:()=>mode==='d'?set({open:!s.open}):set({drawer:!s.drawer})`,
línea 109) — un único control, dos efectos según el modo, siempre en el navbar.

**Decisión**: se revierte R13 punto 3. El botón de menú/colapso vuelve a `app-tenant-header`,
sustituyendo el `@if (viewMode() === 'drawer') { … }` actual (único lugar donde hoy existe ese
botón, `tenant-header.component.ts:50-60`) por un botón que **siempre** se renderiza, con el mismo
`aria-label`/comportamiento dual que ya describe
[contracts/tenant-layout-contract.md](./contracts/tenant-layout-contract.md) §3 para el archivo
anterior, pero re-apuntado: en `'desktop'` invoca `layoutService.toggleDesktopCollapsed()`; en
`'drawer'` invoca `layoutService.toggle()` (sin cambios ahí). El botón equivalente que hoy vive en
`tenant-sidebar.component.ts` (encabezado del `<aside>`, junto al logo) se retira de ahí.

**Lo que NO cambia, verificado explícitamente para no reabrir una decisión ya cerrada**: el archivo
sí reintroduce una lógica de "solo visible en móvil" (`mob = mode==='m'`, un tercer corte en 768px,
distinto del único breakpoint de 1024px) para ocultar el indicador de caja y el interruptor de tema
del navbar y duplicarlos dentro del menú de usuario (`mobOnly`, líneas 61-64). **Esto no se
adopta**: la Clarification Q4 de la sesión 2026-10-12 ya fijó un único punto de quiebre (1024px,
"no se adopta ningún otro umbral distinto del diseño de referencia", Assumptions) — introducir un
segundo corte interno a 768px solo para este detalle sería reabrir esa decisión de negocio ya
cerrada por una preferencia estética del prototipo, no por un FR nuevo de esta sesión. El
comportamiento actual (interruptor de tema siempre visible; indicador de caja oculto por debajo de
`sm` = 640px, sin duplicarse en el menú) se **reafirma**, no se toca.

**El resto de la fidelidad pixel-perfect (FR-018) que este archivo pueda exigir** (medidas exactas
de `clamp()` en la altura de los ítems del sidebar, el valor exacto de `grpH`/`lblT` de las
transiciones de grupo, etc.) se resuelve con el mismo método que R13/R14 ya usaron con éxito:
implementar contra el archivo y **comparar en vivo en Chrome real**, documentando cualquier
hallazgo nuevo con el mismo rigor que R14 — no se intenta enumerar aquí cada valor de forma
especulativa sin haberlo visto renderizado. Es una unidad de verificación propia en el orden de
implementación (ver tabla actualizada al final de este documento).

---

## R16 — Cómo el tema oscuro llega al contenido de ~18 módulos sin tocarlos archivo por archivo

Esta es la decisión técnica central de la sesión: FR-010 ahora exige que tablas, formularios,
tarjetas y gráficas de **todo** el panel de tenant respondan al tema, pero las Assumptions de la
spec no piden (ni financian) retocar cada uno de los ~124 archivos de producción de los ~18 módulos
de tenant. Un inventario exhaustivo (no una muestra) de sus plantillas, vía `grep -rhoE` contra las
carpetas `src/app/modules/{account,cash-register,categories,inventory,option-groups,orders,plan,
presentations,products,promotions,reports,sales,settings,suppliers,supplier-items,tables,
unit-measures,users}`, cuenta:

| Familia | Ocurrencias | Ejemplo real |
|---|---|---|
| `gray-*` (bg/text/border) | 1818 | `text-gray-500`, `bg-gray-50`, `border-gray-200` |
| `slate-*` (bg/text/border) | 12 | `text-slate-700`, `bg-slate-50` |
| `divide-gray-*` | 33 | `divide-gray-50` (filas de tabla) |
| `bg-white` | 223 | fondo de tarjetas/tablas/modales |
| `text-white` | 135 | **texto de botones sobre fondo saturado** (`bg-indigo-600 text-white`) |
| `bg-black` (con opacidad) | 41 | scrim de modales (`fixed inset-0 bg-black/40`) |
| `zinc-*`/`neutral-*`/`stone-*` | 0 | — (ninguna aparece) |

**Hallazgo técnico que habilita la solución** (verificado compilando Tailwind CSS v4.3.0 de forma
aislada contra una plantilla de prueba con `@tailwindcss/postcss`, no asumido de la documentación):
las utilidades de color de Tailwind v4 **no emiten un valor literal** — emiten una referencia a una
variable CSS del tema, declarada en `@layer theme { :root, :host { --color-gray-50: oklch(...); } }`:

```css
.bg-gray-50 { background-color: var(--color-gray-50); }
.text-gray-900 { color: var(--color-gray-900); }
.border-gray-200 { border-color: var(--color-gray-200); }
```

Y, crucialmente, las variantes con opacidad (`bg-gray-50/50`, `hover:bg-gray-50`,
`disabled:bg-gray-50`, `read-only:bg-gray-50` — las cuatro ya están en uso real en el código hoy)
**también** terminan leyendo la misma variable, dentro de un `@supports (color: color-mix(in lab,
red, red))` que todos los navegadores objetivo de este proyecto soportan:

```css
.bg-gray-50\/50 {
  background-color: color-mix(in srgb, oklch(98.5% 0.002 247.839) 50%, transparent); /* fallback legado */
  @supports (color: color-mix(in lab, red, red)) {
    background-color: color-mix(in oklab, var(--color-gray-50) 50%, transparent); /* gana en todo navegador real */
  }
}
```

**Decisión**: se extiende `.panel-theme[data-theme='dark']` (hoy acotada a `--panel-color-*`, R3)
para que **también** redeclare las variables de tema `--color-gray-50` a `--color-gray-900` y
`--color-slate-50`/`-200`/`-400`/`-700`/`-800` (las únicas sombras de `slate` realmente en uso, por
el inventario de arriba) con los valores oscuros **ya elegidos y ya auditados con Lighthouse** en
R3/R13/R14 — no se inventan valores nuevos, se **alían** los tokens de Tailwind a los
`--panel-color-*` existentes:

| Variable de Tailwind | Alias a (R3/R13) | Rol que cubre |
|---|---|---|
| `--color-gray-50`, `--color-slate-50` | `--panel-color-surface-elevated` (`#263449`) | fondos "recesivos" (cabecera de tabla `bg-gray-50/50`, fila alterna) |
| `--color-gray-100`, `--color-gray-200`, `--color-slate-200` | `--panel-color-border` (`#334155`) | bordes, separadores, `divide-gray-*` |
| `--color-gray-300` | `--panel-color-border` (`#334155`) | bordes de `<input>`/`<select>` |
| `--color-gray-400`, `--color-slate-400` | `--panel-color-text-subtle` (`#64748b`) | iconografía apagada, texto deshabilitado |
| `--color-gray-500` | `--panel-color-text-muted` (`#94a3b8`) | texto secundario (subtítulos, ayudas) |
| `--color-gray-600`, `--color-gray-700`, `--color-slate-700` | `--panel-color-text-secondary` (`#cbd5e1`) | texto de cuerpo |
| `--color-gray-800`, `--color-gray-900`, `--color-slate-800` | `--panel-color-text-primary` (`#f8fafc`) | títulos, texto de mayor énfasis |

**Por qué esto NO cubre `white`/`black`, a propósito**: el mismo inventario muestra que `text-white`
(135 ocurrencias) es, casi sin excepción, **texto de botón sobre fondo saturado**
(`bg-indigo-600 text-white` es el patrón dominante — verificado: de 135 líneas con `text-white`,
solo 2 comparten línea con `bg-white`, y esas 2 son coincidencia de dos elementos distintos en la
misma línea de código, no el mismo elemento). Redeclarar `--color-white` repintaría *también* ese
texto de botón (porque `.text-white`/`.bg-white` comparten la misma variable en Tailwind v4),
convirtiendo el texto blanco de cada botón primario del panel en un tono oscuro apenas legible
sobre su propio fondo índigo — una regresión de contraste real, no cosmética. **Se descarta**
tocar `--color-white`/`--color-black`.

En su lugar, `white`/`black` se resuelven con una lista cerrada y corta de *selectores* (no
variables), verificada contra el mismo inventario — solo los usos reales de **superficie** (nunca
`.text-white`, que se deja intacto):

```css
.panel-theme[data-theme='dark'] .bg-white,
.panel-theme[data-theme='dark'] .focus\:bg-white:focus,
.panel-theme[data-theme='dark'] .hover\:bg-white:hover {
  background-color: var(--panel-color-surface-card);
}
```

(9 usos reales de `focus:bg-white`, 1 de `hover:bg-white`, 223 de `bg-white` liso — todos
verificados por `grep`, ninguno inventado.) `bg-black` (41 usos, siempre con opacidad — scrims de
modal, `fixed inset-0 bg-black/40`) **no se toca**: un fondo oscurecido semitransparente funciona
igual de bien detrás de un modal en ambos temas, y no hay ningún caso real de `bg-black` usado como
"superficie opaca" en el inventario. Las dos excepciones puntuales de gradiente con `white`
(`via-white`/`to-white`, un solo archivo, `product-select.component.ts:261`) quedan documentadas
como un hallazgo a resolver durante la auditoría visual (R15), no como una regla general — es un
caso aislado, no un patrón.

**Por qué no se usa la alternativa obvia (`dark:` de Tailwind)**: Tailwind permite escribir
`dark:bg-slate-800` directamente en cada plantilla, pero eso exige **tocar cada una de las ~1800
ocurrencias** en los 124 archivos — exactamente el costo que esta decisión evita. La técnica de
variable elegida logra el mismo resultado visual con un bloque de ~20 líneas en `styles.css`,
**cero cambios en los 18 módulos existentes** (consistente con las Assumptions: "los ~20 módulos
existentes conservan... sin tocar los módulos ya existentes", dicho para los skeletons pero con el
mismo espíritu aplicable aquí) y cero dependencias nuevas (Principio IX).

**Alcance de la clase**: `.panel-theme` se expande de "sidebar + navbar + fondo de contenido" a
"sidebar + navbar + fondo de contenido + todo el `<router-outlet>` de tenant" — en la práctica, se
mueve del `<aside>`/`<header>` al **`shell-root`** (la raíz de `DashboardLayoutComponent`, donde ya
vive hoy, `dashboard-layout.component.ts:32`), sin mover la clase de sitio: ya envuelve al
`router-outlet` desde la primera iteración (R3 solo *prohibía*, por contrato, que las reglas CSS de
esa clase estilaran más allá del marco — el contrato es lo que cambia, no el HTML). Esto se
documenta como la reescritura de
[contracts/panel-theme-contract.md](./contracts/panel-theme-contract.md) §1.

**Riesgo aceptado y cómo se cierra**: la técnica de variable es un repintado **genérico** — no
conoce el contexto semántico de cada uso. Una combinación puntual podría quedar con contraste
insuficiente aunque la regla general funcione para el otro 99%. Se acepta este riesgo con el mismo
criterio que R13/R14 ya usaron (ningún valor se da por bueno sin verlo renderizado): la unidad de
implementación de este cambio **incluye** un recorrido visual real de los ~18 módulos en tema
oscuro (quickstart.md, nueva sección), documentando cualquier combinación rota como un hallazgo
puntual a corregir ahí mismo — no una búsqueda exhaustiva previa de las 1800 ocurrencias.

**Dos hallazgos adicionales del mismo inventario, fuera del mecanismo de R16 — uno se corrige, el
otro se deja documentado y fuera de alcance a propósito:**

1. **La discrepancia de marca `indigo-600` vs. `--panel-color-primary` (#7C3AED) ya existía antes
   de esta spec y no se toca.** El segundo color más frecuente del inventario (`indigo`, cientos de
   ocurrencias en botones primarios/focus rings de todos los módulos) es el acento visual *de
   facto* del contenido de cada módulo — un remanente de antes de que la spec 082 empezara a migrar
   el panel a la paleta violeta real, migración que nunca llegó al contenido de los módulos (solo al
   marco, con esta spec). Unificar `indigo-600` con `--panel-color-primary` sería una
   refactorización de marca no pedida por ningún FR de esta sesión — exactamente lo que el
   Principio V prohíbe mezclar aquí. Se deja como está, en ambos temas, igual que hoy.

2. **Terminal de Mesas (`/dashboard/mesas-sesiones`, el POS de mostrador que usa Cajero/Mesero en
   cada turno) no usa clases Tailwind de color en absoluto — usa valores arbitrarios con hex
   literal** (`bg-[#f3f4f6]`, `text-[#111827]`, `border-[#e5e7eb]`, etc.), portados tal cual de un
   mockup estático (`terminal-de-mesas/code.html`, citado en un comentario de
   `pos-terminal.store.ts`). Un valor arbitrario de Tailwind compila a un color fijo, nunca a
   `var(--color-*)` — **no se beneficia de nada de lo anterior en este documento**. El inventario
   cuenta 417 ocurrencias en 11 archivos (`manual-order-page.component.ts` sola concentra 207;
   el resto se reparte entre `pos-checkout-panel`, `pos-order-panel`, `pos-terminal-header`,
   `pos-tables-panel`, `table-sessions.component.ts`, `pos-terminal.store.ts`,
   `session-bill-panel`, `bill-summary`, `order-summary-card`, `cart-item-options`). Es, con
   diferencia, la pantalla más usada por Cajero/Mesero durante un turno — dejarla fuera del tema
   oscuro no sería una excepción menor, sería la pantalla principal de dos de los tres roles de esta
   spec quedando sin SC-007.

   **Verificado un detalle clave que cambia el riesgo de la corrección**: los valores hex no son
   arbitrarios de verdad — son, literalmente, los mismos valores hexadecimales de la paleta
   estándar de Tailwind que R16 ya cubre (`border-[#e5e7eb]` = `border-gray-200`,
   `text-[#111827]` = `text-gray-900`, `text-[#6b7280]` = `text-gray-500`,
   `text-[#4b5563]` = `text-gray-600`, `bg-[#f3f4f6]` = `bg-gray-100`,
   `bg-[#f9fafb]` = `bg-gray-50`, `text-[#4f46e5]`/`bg-[#4f46e5]` = `indigo-600`). **Decisión
   (confirmada con el usuario)**: se normalizan las 417 ocurrencias a su clase Tailwind equivalente
   exacta en los 11 archivos — una sustitución mecánica, verificable uno a uno contra la tabla de
   equivalencias de arriba, con **cero cambio visual en tema claro** por construcción (mismo valor,
   distinta forma de escribirlo). Una vez normalizadas, Terminal de Mesas cae dentro del mismo
   mecanismo de R16 sin necesitar ningún tratamiento especial propio — se trata como una unidad de
   implementación propia y previa a R16 en el orden sugerido (normalizar primero, para que R16 ya
   la cubra al activarse), con su propia verificación (diff visual nulo en claro) antes de dar por
   cerrada la Historia 2 para este módulo. Un tercer tono de morado (`#4a3aff`, en los *focus rings*
   de `inventory-page.component.ts`, 6 usos) se detectó en el mismo barrido pero **no** se normaliza
   — es un cuarto acento aislado sin relación con Terminal de Mesas, y entra en el mismo criterio
   del punto 1 (consistencia de marca, fuera de alcance de esta spec).

---

## R17 — Dos superficies deben *resistir* el repintado de R16: reporte de caja y hoja de QR

**Hallazgo**: `app-cash-report` (`cash-register/components/cash-report.component.ts`) se monta
inline dentro de `cash-page.component.ts` (`@case ('report') { <app-cash-report /> }`, línea 73) —
dentro del mismo árbol de `router-outlet` que R16 acaba de hacer sensible al tema. Lo mismo
`app-table-qr-sheet` (`tables/pages/table-qr-sheet.component.ts`), una página enrutada normal
(`dashboard/routes.ts:166`). Ninguna de las dos está aislada en un `<iframe>` — a diferencia de
`receipt.util.ts`, que sí imprime en un iframe oculto *sin* Tailwind ni estilos de la app (comentario
propio del archivo, línea 5: "no usa Tailwind ni los estilos de la app"), y por eso nunca necesitó
ninguna exclusión. El reporte de caja y la hoja de QR, en cambio, usan las mismas clases
`bg-white`/`text-gray-900` que R16 acaba de hacer sensibles al tema — sin una exclusión explícita,
FR-010 ("siempre usan presentación clara... sin importar el tema activo") se rompería.

**Decisión**: una clase nueva, `.force-light-surface`, aplicada en la raíz de ambos componentes
(`<div class="flex-1 w-full max-w-[900px] mx-auto p-6">` de `cash-report.component.ts`;
`<div class="max-w-5xl mx-auto">` de `table-qr-sheet.component.ts`), que **re-fija** dentro de su
propio subárbol las mismas variables que R16 redeclaró, de vuelta a sus valores claros —
anulando la herencia de `.panel-theme[data-theme='dark']` solo ahí dentro:

```css
.panel-theme[data-theme='dark'] .force-light-surface {
  --color-gray-50: oklch(98.5% 0.002 247.839); /* valor claro real de Tailwind, no un alias */
  /* … resto de los tokens de R16, cada uno de vuelta a su valor claro original */
}
```

Funciona por la misma razón que el resto de este mecanismo: las variables CSS heredan por el árbol
del DOM, así que una redeclaración más profunda (mayor especificidad de selector, más cerca en el
árbol) gana sobre la de `.panel-theme[data-theme='dark']` para cualquier descendiente de
`.force-light-surface` — sin que ese componente necesite saber que el repintado global existe.
**No requiere lógica en TypeScript**: ni `cash-report.component.ts` ni `table-qr-sheet.component.ts`
leen `PanelThemeService`, antes ni después de este cambio.

**Qué pasa al imprimir**: `@media print` ya fuerza colores reales sobre fondo blanco en la mayoría
de navegadores modulos de impresión (y el `@media print` existente de
`dashboard-layout.component.ts` ya oculta el shell completo para el reporte de caja, spec 087/089) —
pero no hay que depender de eso: `.force-light-surface` ya dejó esas variables en su valor claro
**en pantalla**, antes de llegar a imprimir, así que lo que se imprime es exactamente lo que ya se
veía en pantalla. Se verifica en quickstart.md con el mismo método que R13/R14 (Chrome real, ambos
temas activos al momento de abrir cada superficie).

---

## R18 — El único overlay de CDK del panel de tenant necesita que se le avise del tema

**Hallazgo**: de todos los módulos de tenant, solo uno usa `@angular/cdk/overlay` de verdad
(`cdkConnectedOverlay`, no un `@if` con `position: fixed` hecho a mano): `promotions-page.component.ts`
(líneas 15-19, 156-157, 347-361, spec 084 FR-026 a FR-028). CDK Overlay **teletransporta** su
contenido a un único `<div class="cdk-overlay-container">` que Angular CDK añade como hijo directo
de `<body>` — **fuera** del subárbol de `.panel-theme` (que vive dentro de `<app-root>`). Las
variables CSS de R16 heredan por el árbol del DOM real; un nodo que es hermano de `<app-root>`, no
descendiente, no las hereda. Sin una corrección, el único desplegable de Promociones quedaría
congelado en paleta clara aunque el resto del panel esté en oscuro — justo el caso que FR-010
menciona explícitamente ("cualquier... menú desplegable... que se abra desde cualquier módulo").

Los demás "modales" del panel (el modal de compra de Inventario, los modales de Super Admin con
`fixed inset-0 bg-black/40`, `app-confirm-dialog`/`app-toast-container` ya compartidos — estos dos
últimos, de hecho, ya están dentro de `.panel-theme` desde la primera iteración, montados como
hermanos directos de `<app-tenant-sidebar>` en `dashboard-layout.component.ts`) son `@if` normales
dentro de la plantilla de su propio componente — **no** se mueven en el DOM, solo se superponen
visualmente con CSS (`position: fixed`/`absolute`). Siguen siendo descendientes de
`.panel-theme` sin ningún cambio, y por tanto heredan R16 sin ningún trabajo adicional. Verificado
contra un inventario exhaustivo, no una muestra: **33 archivos** usan el patrón `fixed inset-0`
en `src/app/modules` + `shared`, y los dos overlays compartidos (`confirm-dialog`,
`toast-container`) no usan CDK. Ningún `OverlayContainer` personalizado existe hoy en el proyecto
(`grep -rln "OverlayContainer"` vacío) — confirma que Angular CDK usa su contenedor por defecto
(el que este research corrige) y que `promotions-page.component.ts` es, verificado de forma
exhaustiva, el único punto de riesgo real.

**Decisión**: se centraliza, en un único sitio, la sincronización del `cdk-overlay-container`
compartido (uno solo para toda la aplicación, lo crea Angular CDK la primera vez que algo lo usa)
con el tema activo. `DashboardLayoutComponent` (donde ya vive el resto de la orquestación de tema,
R3/R4) inyecta `OverlayContainer` de `@angular/cdk/overlay` (ya una dependencia existente, cero
paquetes nuevos) y, con un `effect()`, refleja `panelThemeService.theme()` e `isSuperAdmin()` como
clase/atributo sobre `overlayContainer.getContainerElement()` — el mismo par
`class="panel-theme" data-theme="…"` que ya lleva `shell-root`. Como solo hay un contenedor
compartido en toda la app, esta sincronización cubre automáticamente cualquier `cdkConnectedOverlay`
futuro, no solo el de Promociones — sin que ese módulo (ni ningún otro) tenga que inyectar nada.

**Alternativa considerada**: que `promotions-page.component.ts` fije la clase a mano en su propio
`cdkConnectedOverlayPanelClass`. Rechazada — es una solución por módulo para un problema de la
plataforma (el contenedor es compartido), y no protegería al siguiente módulo que adopte CDK
Overlay en una spec futura.

---

## R19 — Las gráficas (Chart.js) no se repintan solas; es el único punto que exige tocar TypeScript, no solo CSS

**Hallazgo**: el panel usa `chart.js`/`ng2-charts` (ya dependencias existentes) a través de un
único módulo compartido, `src/app/shared/charts/chart-theme.ts`, consumido por exactamente 3
componentes (`bars-chart.component.ts`, `ranked-bars-chart.component.ts`,
`share-bar-chart.component.ts`) — ninguna gráfica define sus propios colores de forma suelta. El
archivo mismo documenta, en su propio comentario, que nunca contempló un tema oscuro: *"La app es
solo clara (cero clases `dark:`), así que no hay columna oscura"* (`chart-theme.ts:18-19`). Chart.js
pinta sobre un `<canvas>`: sus colores (`INK`/`MUTED`/`GRID` para ejes y rejilla, `backgroundColor:
'#111827'` del tooltip) son opciones de JavaScript, no clases CSS — la técnica de variable de R16
**no los alcanza**, porque un `<canvas>` no tiene cascada CSS para lo que dibuja dentro.

**Decisión**: `baseOptions(kind)` gana un segundo parámetro, `theme: 'light' | 'dark'`, y las tres
constantes `INK`/`MUTED`/`GRID` se convierten en una función `axisColors(theme)` con un segundo
juego de valores oscuros (a elegir con el mismo criterio de contraste ya aplicado en R3: contra
`--panel-color-canvas` oscuro, no a ojo). También debe cubrirse `borderColor: '#ffffff'` (separador
de segmentos, repetido como literal en los 3 componentes consumidores) con el mismo criterio.
Cada uno de los 3 componentes consumidores pasa `panelThemeService.theme()` (inyectado, un
`computed()` más en su `options`, igual patrón que ya usa `BarsChartComponent.options` para
reaccionar a `kind`) — `ng2-charts` ya reacciona a un cambio de referencia en `[options]` (es como
hoy ya reacciona a que cambien `labels`/`values`/`kind`, sin código adicional de redibujado
manual). `reports/pages/reports-page.component.ts` es, verificado, el único consumidor real de
`shared/charts/` en todo el panel — la superficie completa de esta unidad son 4 archivos.

**Lo que NO cambia**: `CHART_COLORS` (la paleta categórica de 5 series, validada contra el
verificador de la guía de visualización del proyecto — banda de luminosidad, croma mínimo,
contraste ≥3:1, separación CVD) se **mantiene igual en ambos temas**. Son colores que identifican
una serie de datos, no una superficie — el mismo criterio que R16 aplicó para no tocar los colores
semánticos de Tailwind (`amber`/`red`/`emerald`/etc., que tampoco aparecen en el inventario de R16
fuera de su rol de insignia/estado). Queda pendiente, como parte de la unidad de implementación de
este punto, reverificar que los 5 colores de `CHART_COLORS` sigan midiendo ≥3:1 contra
`--panel-color-canvas` oscuro (`#090D16`) — no solo contra blanco, que es contra lo único que se
validaron originalmente.

---

## R20 — Barra de carga + skeleton + aparición escalonada: un mecanismo nuevo, con límites explícitos

**La coreografía exacta ya existe, literal, en el archivo de diseño** (`Layout base.dc.html`,
líneas 83-118, método `nav(p)` del componente de lógica) — no es una interpretación, es la fuente
de verdad que FR-019 a FR-022 describen en prosa:

1. Al navegar: fase `'out'` inmediata (contenido anterior se desvanece y sube 4px en 150ms) y la
   barra empieza a crecer hacia 75% (transición de 500ms).
2. A los 170ms: cambia la vista real; fase `'pre'` (el contenido nuevo se fija, **sin transición**,
   en el estado "a punto de aparecer": opacidad 0, desplazado 12px hacia abajo) — este es
   literalmente el momento del skeleton.
3. A los 230ms (60ms después): fase `'in'` — cada bloque aparece con opacidad 1 y sin desplazamiento,
   en una transición de 380ms escalonada por índice (`i × 55ms` de retraso): el bloque 0 empieza ya,
   el 1 a los 55ms, el 2 a los 110ms, etc. La barra salta a 100% (transición de 200ms) y luego se
   desvanece (`opacity` a 0 con 150ms de retraso).
4. A los 900ms: la barra vuelve a 0% de ancho sin transición, lista para la próxima navegación.

Esto confirma, de forma literal y no ambigua, lo que la Clarification de la sesión 2026-10-13 ya
había cerrado en prosa: la barra **no** refleja ninguna petición real (es un cronómetro fijo,
`setTimeout` tras `setTimeout`), y el "skeleton" (fase `'pre'`) es un **salto instantáneo** a un
estado visual fijo, no una animación en sí mismo — la animación ocurre al *salir* de ese estado
(fase `'in'`), no al entrar en él.

**Terreno limpio, verificado de forma exhaustiva**: hoy no existe ningún indicador de
progreso/carga global (sin `ngx-progressbar` ni nada similar) y solo dos suscriptores reales de
`Router.events`, ninguno a `NavigationStart`: `dashboard-layout.component.ts` (cierra el drawer
móvil en cada `NavigationEnd`) y `tenant-header.component.ts` (deriva `currentUrl()` con
`toSignal()` para el título/sección activa). Ningún guard (`authGuard`, `tenantDomainGuard`,
`roleGuard`, `planModuleGuard`, `checkoutHydrationGuard`, …) se engancha a `Router.events` — son
`CanActivate` normales. `NavigationTransitionService` coexiste con los dos suscriptores existentes
sin reemplazar ninguno; no hay riesgo de interferencia, pero conviene no duplicar la misma
derivación de "ruta activa" en un tercer sitio — ver si `tenant-header.component.ts` puede
compartir su `currentUrl()` ya existente en vez de que el servicio nuevo recalcule lo mismo por su
cuenta (detalle de implementación, no de diseño).

### Qué dispara la coreografía en la app real (el archivo de diseño no lo resuelve, porque no tiene rutas reales)

El archivo de diseño es una maqueta de un solo componente sin Angular Router: su `nav(p)` es una
función de clic directa. La app real navega con rutas perezosas (`loadComponent`,
`dashboard/routes.ts`) protegidas solo por `canActivate` (sin `resolve`) — no hay ninguna espera de
datos bloqueando la navegación del Router; cada página pide sus propios datos en su `ngOnInit`,
después de montarse. Eso significa que `NavigationEnd` puede llegar **antes** de que termine el
cronómetro fijo de arriba (navegación "caliente", chunk ya descargado) o **después** (primera visita
a una ruta perezosa, con descarga de red real — variable, fuera de control de esta spec).

**Decisión**: un servicio nuevo, `NavigationTransitionService` (`providedIn: 'root'`), suscrito a
`Router.events` (patrón ya usado en `dashboard-layout.component.ts:168-186` para
`NavigationEnd`, aquí se añade `NavigationStart`/`NavigationCancel`/`NavigationError`):

- En `NavigationStart`, **solo si la ruta (sin query string) cambió** respecto a la anterior (un
  cambio de parámro de consulta en la misma página no es una "transición de sección" — evita que
  filtros/paginación disparen la coreografía): arranca la fase `'out'` y la barra, con el mismo
  cronómetro fijo del archivo de diseño (los tiempos exactos, p. ej. 150/170/230/900ms, se calibran
  en la implementación contra el propio archivo — no son una decisión de negocio, son una réplica
  de un comportamiento visual ya aprobado).
- El skeleton permanece visible hasta que ocurra **lo último** entre "el cronómetro fijo llegó a la
  fase `'pre'`→`'in'`" y "`NavigationEnd` ya disparó" — así una navegación caliente no se siente
  instantánea/brusca (se respeta el mínimo de la coreografía) y una navegación fría (chunk aún
  descargando) no revela contenido a medio montar ni dispara el `'in'` antes de tiempo.
- `NavigationCancel`/`NavigationError` cierran la coreografía igual que un `NavigationEnd` (vuelven
  a `'in'`/idle) — una navegación cancelada no debe dejar la barra o el skeleton congelados a medio
  camino.
- Clics múltiples en rápida sucesión (Historia 4, Escenario 5): cada `NavigationStart` nuevo
  **reinicia** el cronómetro (cancela los `setTimeout` pendientes de la navegación anterior, mismo
  patrón que ya usa `nav()` del archivo de diseño: `clearTimeout(this._t1,._t2,._t3)`) — solo la
  navegación más reciente llega a `'in'`.

**Dónde vive**: el servicio no decide layout; `DashboardLayoutComponent` lee sus signals
(`phase`, `barVisible`) para pintar la barra (un `<div>` nuevo, análogo al de la línea 70 del
archivo de diseño) y una clase sobre el contenedor de `router-outlet` que activa el skeleton
genérico mientras `phase() === 'pre'`. Acotado a `!isSuperAdmin()` (mismo criterio que todo lo
demás de esta spec — Super Admin no estaba mencionado en la Historia 4 ni en ninguna Clarification
de esta sesión, y la spec entera ya excluye ese panel desde su primera Clarification, Q7).

### El límite real: no se puede escalonar lo que no se controla

El archivo de diseño escalona **5 filas individuales** de una lista de ejemplo (`rowsL`). Trasladado
literalmente a, por ejemplo, una tabla real de Inventario con 200 filas, escalonar cada fila a 55ms
de distancia tardaría 11 segundos en completarse — no es un desacuerdo de interpretación, es
aritmética. Las Assumptions de la spec ya anticipan el límite correcto: el skeleton es "genérico...
sin adaptarse al contenido real" — es decir, el skeleton **nunca** representa las 200 filas reales,
siempre un número fijo y pequeño de bloques (un diseño genérico equivalente al propio `cards`/`rowsL`
del archivo: unas pocas tarjetas + una franja de filas, el mismo markup sin importar a qué módulo se
navegue). Ese escalonado, del skeleton, es seguro: su cuenta de bloques **no depende de datos**, la
fija esta spec.

Lo que sí exige FR-020/AC2 de la Historia 4 es que, además, **el contenido real** (no el skeleton)
aparezca "en orden escalonado... uno tras otro". Verificado contra una plantilla real
(`inventory-page.component.ts:55`, raíz `<div class="space-y-6">`): cada página del panel ya
estructura su plantilla como una raíz única con un puñado de secciones de nivel superior como hijos
directos (cabecera, pestañas, alerta, tabla) — 3 a 6 típicamente, nunca las filas internas de una
tabla, que son hijas de un hijo, no hijas directas de la raíz. Esto permite un selector CSS
genérico, sin tocar ningún módulo, que escalona **solo los hijos directos de nivel superior** de lo
que sea que `router-outlet` monte, con un tope (los hijos más allá del N-ésimo comparten el retraso
del último, en vez de seguir sumando) — nunca alcanza las filas internas de una tabla, sin importar
cuántas tenga. Verificación en quickstart.md: confirmar en 3-4 módulos reales (Inventario, Ventas,
Dashboard, Reportes) que el número de secciones de nivel superior es razonable (no hay un módulo
con, p. ej., 40 hijos directos en su raíz) antes de dar por buena la generalidad del selector.

**Alternativa descartada**: pedir a cada uno de los ~18 módulos que marque sus bloques "escalonables"
con una clase/directiva propia. Técnicamente más preciso, pero exige tocar los mismos ~18 módulos
que R16 consiguió no tocar — contradice la misma Assumption ("sin tocar los módulos ya existentes")
que ya se citó para el skeleton.

---

## R21 — `prefers-reduced-motion`: primera aparición en el proyecto

**Hallazgo**: `grep -rn "prefers-reduced-motion"` contra todo `src/` no devuelve nada — ni en CSS ni
en TypeScript. Tampoco existe hoy ningún `@keyframes` en `styles.css` (las transiciones de spec 116
ya implementadas, colapso/drawer, usan `transition`, no `@keyframes`). FR-022 es la primera vez que
el proyecto necesita leer esta preferencia del sistema operativo.

**Alcance, verificado para no exceder lo que FR-022 realmente pide**: las transiciones ya
implementadas y ya fusionadas de la primera iteración (`shell-content` con
`transition-[margin-left]` en `dashboard-layout.component.ts`; `transition-[translate,width]` en
`tenant-sidebar.component.ts:50`; `transition-colors`/`transition-transform` varios de
`tenant-header.component.ts`) **no llevan ningún guard de `prefers-reduced-motion` hoy, y esta
spec no se lo añade** — FR-022 cita, por nombre, solo "las animaciones... del FR-020" y "el efecto
de la barra de carga del FR-019", es decir, exclusivamente las animaciones **nuevas** de esta
sesión. Añadírselo también a las transiciones de colapso/drawer ya shippeadas sería una mejora de
accesibilidad genuina pero no pedida por ningún FR de esta sesión — mezclarla aquí sería la
refactorización oportunista que el Principio V prohíbe. El componente legado de Super Admin
(`sidebar.component.ts:24`, `transition-transform`) queda fuera por partida doble (R1 y este mismo
criterio).

**Decisión**: se resuelve con el mismo patrón defensivo ya usado para `matchMedia(
'prefers-color-scheme: dark')` en `panel-theme.service.ts::prefersDark()` (try/catch, por si el
entorno — p. ej. un test con `TestBed` sin `window.matchMedia` mockeado — no expone la API): una
consulta `window.matchMedia('(prefers-reduced-motion: reduce)').matches`, envuelta en un signal
derivado de `NavigationTransitionService` (o, más simple y más barato: una regla CSS pura
`@media (prefers-reduced-motion: reduce) { … }` que anula `transition`/`animation` sobre la barra y
el contenedor con animación escalonada — sin necesidad de leer la preferencia desde TypeScript en
absoluto, porque ninguna decisión de *lógica* depende de ella, solo la *presentación* visual). Se
prefiere la regla CSS pura: es más simple, no puede desincronizarse de un signal, y es exactamente
el mecanismo que el propio CSS fue diseñado para resolver. El cronómetro de `NavigationTransitionService`
(R20) sigue funcionando igual internamente (fases `'out'`/`'pre'`/`'in'` se siguen sucediendo) — lo
único que cambia es que, bajo ese media query, las reglas CSS que animan esas fases no tienen
ninguna transición que ejecutar, así que el cambio se ve instantáneo sin que el servicio necesite
saberlo (Principio VI: la unidad más simple que cumple el requisito).

---

## Resumen de incógnitas resueltas (sesión 2026-10-13)

| Incógnita | Resuelta en |
|---|---|
| Qué cambia al volver a `Layout base.dc.html` como fuente de verdad | R15 |
| Cómo llega el tema oscuro a ~18 módulos sin tocarlos archivo por archivo | R16 |
| Por qué `white`/`black` necesitan un mecanismo distinto al de `gray`/`slate` | R16 |
| Por qué Terminal de Mesas (417 hex literales) necesita una normalización previa | R16 |
| Cómo el reporte de caja y la hoja de QR resisten el repintado global | R17 |
| Cómo se tematiza el único overlay de CDK del panel de tenant | R18 |
| Por qué las gráficas necesitan un cambio de TypeScript, no solo CSS | R19 |
| Qué dispara la barra/skeleton en rutas reales (el mockup no tiene rutas) | R20 |
| Por qué el escalonado no puede aplicarse a filas de tabla reales | R20 |
| Qué pasa con navegaciones múltiples rápidas | R20 |
| Cómo se respeta `prefers-reduced-motion` por primera vez en el proyecto | R21 |

**Dependencias nuevas**: ninguna — `@angular/cdk/overlay` (R18) y `chart.js`/`ng2-charts` (R19) ya
son dependencias existentes del proyecto (Principio IX satisfecho por ausencia). **Cambios en
`pos-backend`**: ninguno. **Migraciones**: ninguna. **Entradas nuevas en el registro de
anomalías**: ninguna — ver Constitution Check del plan para la misma evaluación que R10 ya hizo,
reaplicada a este alcance ampliado.

---

## R22 — Tercera sesión de clarificación (2026-10-14): resaltado por prefijo de ruta, scrollbar y `<select>` en oscuro

Generada por `/speckit-converge` (Fase 11 de tasks.md, T070-T072) al detectar que la sesión de
clarificación 2026-10-14 de spec.md (FR-004 ampliado, FR-023, FR-024 nuevas) nunca se propagó a
plan.md/research.md/data-model.md/quickstart.md ni a ninguna fase previa de tasks.md.

**R22.1 — FR-004 ampliado (resaltado por prefijo de ruta)**: `tenant-sidebar.component.ts` usaba
`[routerLinkActiveOptions]="{ exact: true }"` y `tenant-header.component.ts` resolvía el ítem
activo con `item.route === currentUrl()` — ninguno de los dos resaltaba el ítem padre en una
subvista sin ítem propio (p. ej. `/dashboard/products/editar/5`). Se cambió a
`{ exact: false }` en el sidebar (Angular ya compara por segmento de `UrlTree`, no por substring
de texto, así que `/dashboard/mesas-sesiones` nunca se confunde con `/dashboard/mesas` aunque
comparten prefijo de texto) y, en el header, a una coincidencia manual
`path === item.route || path.startsWith(`${item.route}/`)` con desempate por la ruta más larga,
sobre la ruta ya sin query string/fragmento. Verificado con 4 tests nuevos (2 por componente,
incluyendo el caso de colisión de texto `mesas`/`mesas-sesiones`) — ver
[contracts/tenant-layout-contract.md](./contracts/tenant-layout-contract.md) §2-§3.

**R22.2 — FR-024 (scrollbar por tema)**: no existía ninguna regla de `scrollbar-color`/
`scrollbar-width` en el proyecto. Se añadió una sola declaración en el bloque base `.panel-theme`
(`scrollbar-color: var(--panel-color-border) transparent; scrollbar-width: thin;`) — al ser
`scrollbar-color` una propiedad heredada (igual que `color`) y `--panel-color-border` ya cambiar
de valor dentro de `.panel-theme[data-theme='dark']`, una sola declaración resuelve ambos temas
sin repetirla. Sin pseudo-elementos `::-webkit-scrollbar`, sin dependencias nuevas, consistente
con la decisión explícita de FR-024 — ver
[contracts/panel-theme-contract.md](./contracts/panel-theme-contract.md) §10.

**R22.3 — FR-023 (legibilidad de `<select>` en oscuro)**: la redeclaración de variables de R16
solo repinta `<select>` que ya llevan clases de color de Tailwind (`bg-white`, `text-gray-*`);
los que no llevan ninguna (`payment-input.component.ts`, el caso detectado en la sesión de
clarificación, y los dos `<select>` de `purchase-form.component.ts`) quedan con el fondo nativo
del navegador, en un caso con texto ya redeclarado a un tono claro sobre ese fondo nativo claro
también — invertido respecto al resto del panel oscuro. En vez de editar cada componente, se
añadió una sola regla por elemento, `.panel-theme[data-theme='dark'] select { background-color:
…; color: …; border-color: …; }`, con menor especificidad que cualquier utilidad de Tailwind ya
presente (`.bg-white`, `.text-gray-*`) — así que no cambia nada donde ya había una clase de color,
y cubre por construcción cualquier `<select>` futuro que no declare la suya. Confirmado por
inspección de especificidad CSS (una clase + un atributo + un tipo, siempre por debajo de
cualquier combinación de clases de Tailwind) — ver
[contracts/panel-theme-contract.md](./contracts/panel-theme-contract.md) §10.

**Verificación**: suite completa de `pos-heladeria` tras los tres cambios — 7 archivos/11 tests en
rojo (exactamente los mismos ya documentados como preexistentes al cierre de la Fase 10, T068),
1812 pasan (1808 + 4 tests nuevos de R22.1), 1 skip — sin regresiones. R22.2/R22.3 son CSS puro,
sin test de `TestBed` posible (igual que R16/R17); quedan pendientes de recorrido visual manual
(quickstart.md §17).

---

## R23 — Cuarta ronda de clarificación (2026-10-14): ícono de colapso, íconos invisibles sobre fondo pastel, degradado de "adicionales"

Generada por `/speckit-converge` (Fase 12 de tasks.md, T073-T075) tras un nuevo recorrido visual
del usuario sobre la implementación de la Fase 11, que encontró 3 defectos no cubiertos por las
tres rondas de clarificación anteriores.

**R23.1 — ícono del botón de menú/colapso (FR-003)**: `tenant-header.component.ts` usaba
`[name]="viewMode() === 'drawer' ? 'menu' : 'panel-left'"` — `panel-left` era un resto de la
iteración R13 (cuando `SkeiloPOS App.dc.html` era la fuente de verdad), nunca revertido cuando
R15 devolvió `Layout base.dc.html` a ese rol. El archivo de diseño (línea 52) usa el mismo ícono
`menu` en todos los modos, sin excepción. Se fijó `[name]="'menu'"`, sin condicional. Único uso
de `panel-left` en todo el repo (confirmado por `grep`) — el `@case ('panel-left')` de
`icon.component.ts` queda sin consumidores, se deja (no se pidió limpiarlo).

**R23.2 — íconos invisibles sobre fondo pastel fijo (FR-025 nueva)**: un ícono sin su propia
clase `text-*` hereda el `color` ambiental de `.panel-theme`, que en modo oscuro es casi blanco
(`--panel-color-text-primary`, `#f8fafc`) — invisible sobre un fondo `bg-indigo-50` que no cambia
con el tema (los colores semánticos quedan fuera del mecanismo de R16 a propósito). 9 instancias
confirmadas en 5 archivos (`tables-page`, `categories-page`, `tenant-info` ×5, `products-page`,
`product-detail-page`), corregidas con `text-indigo-600` — el mismo patrón icono+badge que ya usa
correctamente el resto del panel (`orders-page.component.ts:103`, `admin-dashboard.component.ts`,
confirmado como precedente antes de aplicar el fix, no inventado). No es un problema resoluble con
una sola variable CSS global como R16 (el color de ícono correcto depende de a qué insignia
semántica pertenece cada contenedor — no hay un valor único de reemplazo).

**R23.3 — degradado de "adicionales" con `via-white`/`to-white` (FR-010)**: única ocurrencia en
el repo, `product-select.component.ts:261`. La hipótesis inicial (repetir la regla de `.bg-white`)
resultó falsa al compilar el motor real de `tailwindcss@4.1.12`: `via-white`/`to-white` fijan
`--tw-gradient-via`/`--tw-gradient-to`, no `background-color` — la superficie visible la pinta
`background-image: linear-gradient(var(--tw-gradient-stops))` de `.bg-gradient-to-*`, no la capa
de `background-color`. Se sobrescriben las variables de degradado correctas en vez de repetir la
regla existente sin efecto. `from-indigo-50/40` (el acento del mismo degradado) queda sin tocar,
confirmado con el usuario.

**Verificación**: suite completa de `pos-heladeria` tras los tres cambios — 7 archivos/11 tests en
rojo (exactamente los mismos preexistentes al cierre de la Fase 11), 1813 pasan (1812 + 1 test
nuevo de R23.1), 1 skip — sin regresiones. R23.2/R23.3 son CSS puro, sin test de `TestBed`
posible — pendientes de recorrido visual manual (quickstart.md §18).
