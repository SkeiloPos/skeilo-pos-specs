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
