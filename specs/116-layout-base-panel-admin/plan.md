# Implementation Plan: Layout base del panel (Sidebar + Navbar) con tema claro/oscuro persistente aplicado globalmente y micro-interacciones de carga

**Branch**: la spec vive en `specs/116-layout-base-panel-admin/` de `pos-specs`, rama `main`. La
rama de código es `feat/116-layout-base-panel-admin` en `pos-heladeria` (**nueva rama desde
`develop`, no la original** — la primera iteración ya se fusionó a `develop` vía PR #36; Principio
XIV), y **solo ahí** — `pos-backend` no participa y no necesita rama. | **Date**: 2026-10-12
(iteración original) / **2026-10-13** (esta iteración — tema global + micro-interacciones) |
**Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/116-layout-base-panel-admin/spec.md`

> **Nota de alcance de este documento**: este plan cubre **dos iteraciones** de la misma spec. Las
> secciones "Summary", "Technical Context" y "Constitution Check" originales (2026-10-12), más
> abajo, describen la **primera** iteración (ya implementada y fusionada — T001-T032 + ajustes R13/
> R14 de research.md). La sección **"Iteración 2026-10-13"** justo después las complementa con el
> alcance ampliado (tema global al contenido de los módulos, barra de carga, skeletons, aparición
> escalonada) — no las reemplaza. Donde ambas secciones hablan de lo mismo (p. ej. Project
> Structure, orden de implementación), la de 2026-10-13 tiene la última palabra.

## Summary

El panel de Administrador de Tenant, Cajero y Mesero conserva hoy la estructura de sidebar +
navbar con la que nació hace varias specs: paleta índigo fija, Material Icons, un solo signal
booleano que en escritorio solo sabe "mostrar todo" u "ocultar todo", y ningún concepto de tema.
El archivo de diseño de referencia (`Layout base.dc.html`, con su sistema de tokens real en
`_ds/skeilopos-design-system-…/tokens/`) define algo distinto: seis grupos de navegación
reordenados, un set de íconos estilo Lucide, un marco (sidebar/navbar/fondo) que alterna entre
tema claro y oscuro de forma persistente, y un sidebar que en escritorio se colapsa a una barra de
solo íconos en vez de desaparecer por completo.

El centro de gravedad técnico es **no tocar el panel de Super Admin**, que la spec declara fuera
de alcance, sin que eso signifique duplicar el enrutador ni el cascarón que ambos paneles
comparten hoy (`DashboardLayoutComponent`). La solución es una bifurcación de una sola línea en
ese cascarón: Super Admin sigue montando `<app-sidebar>`/`<app-header>` sin ningún cambio;
Administrador/Cajero/Mesero montan dos componentes nuevos, `<app-tenant-sidebar>` y
`<app-tenant-header>`, que implementan el rediseño completo. Alrededor de ese punto, el resto es
reutilización deliberada de lo que ya existe: la lógica de filtrado por rol/plan de
`SidebarComponent` se traslada sin reescribirla; los íconos nuevos se añaden al mismo
`IconComponent` artesanal que el proyecto ya usa para íconos "estilo Lucide" desde la spec 092, en
vez de instalar una librería; las tipografías `Figtree`/`Sora` ya están autoalojadas desde la spec
095; y el indicador de caja del navbar reutiliza el mismo `CashService.discoverOpenShift()` que
ya usa Terminal de Mesas, solo disparado un poco antes. **Cero dependencias nuevas, cero cambios
en `pos-backend`, cero migraciones.**

El reconocimiento técnico encontró dos puntos que el spec no podía anticipar y que este plan
resuelve explícitamente:

1. **"Colapsar a solo íconos" no es lo que el sidebar ya hace** (research R5). Hoy, en escritorio,
   ocultar el sidebar lo saca completamente de la pantalla; el nuevo diseño pide un estado
   intermedio (72px, solo íconos) que no existe. Se añade un signal nuevo (`desktopCollapsed`),
   separado del `sidebarOpen` existente, para no alterar el comportamiento de Super Admin.
2. **El indicador "Caja N abierta" en un navbar global es información nueva, no solo
   presentación** (research R8): hoy ese dato solo se carga cuando el usuario visita Caja o
   Terminal de Mesas. Mostrarlo siempre, correctamente, exige disparar la misma llamada de
   siempre un poco más temprano — una petición de red movida, no una nueva.

## Technical Context

**Language/Version**: TypeScript 5.x con Angular 21.1 en `pos-heladeria` — componentes
standalone (cero `@NgModule` en el repositorio), signals para todo el estado reactivo de layout,
`inject()` para DI, control de flujo `@if`/`@for`/`@switch`. **`pos-backend` no participa**:
ninguna FR de esta spec pide un endpoint nuevo ni modificado; las reglas de rol/plan que el
sidebar debe preservar ya viven enteramente en el cliente (`SidebarComponent.visibleItems`).

**Primary Dependencies**: `@angular/core`/`@angular/router`/`@angular/forms` 21.1,
`@angular/cdk` 21.2 (ya presente — se usa por primera vez su `BreakpointObserver`, de
`@angular/cdk/layout`, en vez de un listener de `resize` manual; research R6), Tailwind CSS 4.1.
**Ninguna dependencia nueva** (Principio IX satisfecho por ausencia, research R2 y R7): los
íconos nuevos se copian a mano en `IconComponent` siguiendo el patrón ya establecido por la spec
092; el tooltip del sidebar colapsado es CSS puro (`:hover`/`:focus-visible`); las tipografías
`Figtree`/`Sora` ya están autoalojadas desde la spec 095.

**Storage**: ningún dato de negocio. Dos claves nuevas de `localStorage`, con el mismo patrón
defensivo (`try`/`catch`) que ya usan `sound.service.ts` y `printer-settings.store.ts`:
`pos.panel.theme` (`'light' | 'dark'`) y `pos.panel.sidebar_collapsed` (booleano serializado). Sin
esquema, sin migración, sin dato personal — ver [data-model.md](./data-model.md) §1-2.

**Testing**: Vitest (`npm test`, builder `@angular/build:unit-test`), `TestBed` + un
`*.component.spec.ts`/`*.service.spec.ts` hermano por archivo nuevo, siguiendo el patrón de
`sidebar.component.spec.ts` (dobles de `AuthService`/`TenantInfoService`/`PlanSummaryService` vía
`useValue`, el helper `setViewportWidth()` ya existente para los tests de punto de quiebre). Cero
characterization tests en el área de layout/navegación/íconos (`grep -rn "CONGELA"` no devuelve
nada ahí) — nada que el Principio III deba blindar.

**Target Platform**: navegador, panel autenticado de tenant (`Administrador`, `Cajero`, `Mesero`),
en los tres formatos reales de uso (mostrador de escritorio, tableta, celular), con el mismo
punto de quiebre ya vigente (1024px, Clarification Q4) y en los dos temas que esta spec introduce.
El panel de Super Admin es el mismo navegador y el mismo código fuente, pero **fuera de alcance
por construcción** (research R1): nunca monta los componentes nuevos.

**Project Type**: aplicación web, de un solo lado — frontend Angular. `pos-backend` queda
intacto; se lee (`CashService`, `PlanSummaryService`, `TenantInfoService`, `AuthService`), nunca se
modifica su contrato.

**Performance Goals**:
- El tema correcto se pinta en el primer frame, sin un frame intermedio con el tema contrario
  (FR-012, SC-002) — resuelto con un script inline síncrono en `index.html` antes de que Angular
  bootee (research R4), porque este proyecto es 100 % CSR sin SSR.
- El indicador de caja añade como máximo una petición de red adicional por carga de panel, solo
  para `ADMIN`/`CASHIER`, y solo si `CashService.shift()` todavía no se conocía (research R8) —
  nunca una petición duplicada si el usuario ya visitó Caja/Terminal de Mesas antes.

**Constraints**:
- **FR-006 es inviolable**: ninguna ruta, enlace ni guard de acceso cambia. `git status` de
  `pos-backend` queda limpio.
- **FR-010 es inviolable**: la clase `.panel-theme` y sus tokens `--panel-color-*` solo pueden
  estilar sidebar, navbar y el fondo del contenedor de `router-outlet` — nunca el contenido que
  ese `router-outlet` proyecta (contrato completo en
  [contracts/panel-theme-contract.md](./contracts/panel-theme-contract.md) §1).
- **El panel de Super Admin no se repinta**: `SidebarComponent`/`HeaderComponent` no se
  modifican ni un carácter (research R1); sus tests siguen en verde sin tocarlos.
- **FR-005**: ningún `NavItem` cambia su `route`/`roles`/`moduleKey` — solo gana un campo
  `frame` opcional, aditivo, que el componente legado no lee (data-model §4).

**Scale/Scope**: 2 componentes nuevos (`app-tenant-sidebar`, `app-tenant-header`) + 1 servicio
nuevo (`PanelThemeService`) + 1 extensión de servicio existente (`LayoutService.desktopCollapsed`)
+ ~18 `@case` nuevos en `IconComponent` + 1 bloque de tokens CSS (`.panel-theme`) + 1 script
inline en `index.html` + la reagrupación de 15 `NavItem` existentes (campo `frame`, aditivo).
Aproximadamente **9-10 archivos de producción nuevos/modificados y 4-5 de test** en
`pos-heladeria`. **Cero archivos en `pos-backend`. Cero entradas nuevas en el registro de
anomalías** (research R10).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Estado | Evidencia |
|---|---|---|
| **I** — Nuevas funcionalidades nacen de un spec | ✅ PASA | `spec.md` con 3 historias, 17 FR, 6 SC, 10 decisiones de clarificación cerradas. Sin `NEEDS CLARIFICATION` pendiente. |
| **II** — El comportamiento existente sigue protegido | ✅ PASA | Research R10: ningún cambio de esta spec reúne las condiciones que exigirían una entrada en `registro-de-anomalias.md` — es reagrupación/reetiquetado visual de las mismas rutas con las mismas reglas de acceso, un control de interfaz sin regla de negocio documentada previamente, y una capacidad aditiva (tema oscuro). Comparado explícitamente contra el criterio real que la spec 095 aplicó. |
| **III** — Characterization tests protegen el comportamiento heredado | ✅ PASA | Cero tests `"CONGELA comportamiento actual:"` en el área de layout/navegación/íconos (verificado con `grep`). Nada que este plan pueda poner en riesgo. |
| **IV** — Los nuevos specs pueden introducir nuevo comportamiento | ✅ PASA | El tema oscuro, el colapso a solo-íconos y la reagrupación son comportamiento nuevo autorizado por FR-001 a FR-017. |
| **V** — Nuevas funcionalidades antes que refactorizaciones oportunistas | ✅ PASA | Se evaluó y **se descartó** limpiar la lógica tenant ahora muerta de `SidebarComponent`/`HeaderComponent` (research R1): tocar ese componente para "ordenarlo" sería la refactorización no solicitada que este principio prohíbe mezclar aquí. Se documenta como consecuencia aceptada, no se oculta. |
| **VI** — Evolución incremental | ✅ PASA | Un solo repositorio (`pos-heladeria`), una sola clase de cambio (presentación + una preferencia de cliente persistida), con unidades verificables independientes: tokens/tema → íconos → sidebar → navbar → responsive. Nada de migración, arquitectura de backend ni datos de negocio mezclado. |
| **VII** — Compatibilidad con datos históricos | ✅ N/A | No se lee ni se escribe ningún dato de negocio ni factura. |
| **VIII** — Evolución del modelo de datos | ✅ N/A | No hay modelo de datos de servidor que evolucionar ([data-model.md](./data-model.md) §0). Las dos claves de `localStorage` no tienen esquema que migrar ni rollback más allá de borrar la clave. |
| **IX** — Dependencias nuevas permitidas con justificación | ✅ PASA | **Ninguna dependencia nueva.** Se evaluaron y descartaron `lucide-angular` (research R2) y `@angular/material` solo por `MatTooltip` (research R7); `@angular/cdk` ya es dependencia existente y solo se usa una API nueva de un paquete ya instalado (`BreakpointObserver`, research R6). |
| **X** — Verificación obligatoria | ✅ PASA | Tests nuevos para `PanelThemeService`, `LayoutService.desktopCollapsed`, `app-tenant-sidebar` y `app-tenant-header`; recorrido manual completo en [quickstart.md](./quickstart.md) para lo que un test de DOM no puede ver (parpadeo real, foco de teclado, redimensionado en vivo, Lighthouse); los tests del componente legado quedan como prueba negativa de que Super Admin no se vio afectado. |
| **XI** — Decisiones de negocio frente a decisiones técnicas | ✅ PASA | Las 10 decisiones de negocio están cerradas en la spec (sesión de clarificación). Las decisiones técnicas de este plan (R1-R11) no reabren ninguna de ellas; donde el reconocimiento encontró un vacío no cubierto por ninguna decisión de negocio (el indicador de caja, research R8), el plan tomó la decisión técnica más conservadora (reutilizar el método existente) en vez de escalarla, porque no cambia ningún comportamiento ya protegido. |
| **XII** — Trazabilidad | ✅ PASA | Cada FR tiene su decisión en research.md, su contrato verificable y su paso de validación en quickstart.md. |
| **XIII** — Todo en español de Colombia | ✅ PASA | Todos los artefactos de esta spec en español de Colombia. |
| **XIV** — Estrategia y convención de ramas Git | ✅ PASA | `feat/116-layout-base-panel-admin` en `pos-heladeria`, a crear **antes** de tocar código. `feat` es el tipo correcto: introduce comportamiento nuevo persistido (tema, colapso), no es solo un rediseño de superficie. `pos-backend` no necesita rama porque no cambia. |
| **XV** — Política de commits Git | ✅ PASA | Commits pequeños por unidad (ver "Orden de implementación sugerido" abajo), en inglés, Conventional Commits, sin marcas de asistencia de IA, y solo cuando el usuario los pida. |

Ninguna puerta bloquea el inicio de la implementación: no hay decisiones de negocio pendientes
(a diferencia de spec 095, aquí no hace falta escribir ninguna entrada previa en el registro de
anomalías — research R10).

## Project Structure

### Documentation (this feature)

```text
specs/116-layout-base-panel-admin/
├── plan.md                                    # Este archivo
├── spec.md                                    # Contrato funcional (ya existía)
├── research.md                                # Fase 0: R1 a R11
├── data-model.md                               # Fase 1: estructuras de cliente (sin modelo de servidor)
├── quickstart.md                                # Fase 1: guía de validación en 9 pasos
├── contracts/
│   ├── navigation-grouping-contract.md           # Tabla ruta → grupo/etiqueta/ícono nuevos (FR-001 a FR-003)
│   ├── panel-theme-contract.md                    # Tokens, PanelThemeService, contrato anti-parpadeo (FR-009 a FR-017)
│   └── tenant-layout-contract.md                   # Contrato de app-tenant-sidebar/app-tenant-header
├── checklists/                                       # Ya existía
└── tasks.md                                           # Fase 2 — la genera /speckit-tasks, no este comando
```

### Source Code (repositorio `pos-heladeria`)

```text
pos-heladeria/
├── src/
│   ├── index.html                                      # MODIFICADO — script inline anti-parpadeo (research R4)
│   ├── styles.css                                       # MODIFICADO — bloque .panel-theme / [data-theme="dark"] (research R3)
│   ├── app/
│   │   ├── modules/dashboard/layout/
│   │   │   ├── dashboard-layout.component.ts             # MODIFICADO — bifurcación de una línea (contracts/tenant-layout-contract.md §1)
│   │   │   ├── sidebar.component.ts                       # NO SE TOCA (Super Admin, research R1)
│   │   │   ├── header.component.ts                         # NO SE TOCA (Super Admin, research R1)
│   │   │   ├── layout.service.ts                            # MODIFICADO — + desktopCollapsed (persistido), additivo
│   │   │   ├── layout.service.spec.ts                        # AMPLIADO
│   │   │   ├── panel-theme.service.ts                          # NUEVO — PanelThemeService (data-model §1)
│   │   │   ├── panel-theme.service.spec.ts                      # NUEVO
│   │   │   ├── tenant-sidebar.component.ts                       # NUEVO — app-tenant-sidebar
│   │   │   ├── tenant-sidebar.component.spec.ts                   # NUEVO
│   │   │   ├── tenant-header.component.ts                          # NUEVO — app-tenant-header
│   │   │   └── tenant-header.component.spec.ts                      # NUEVO
│   │   ├── core/
│   │   │   ├── config/navigation.config.ts                           # MODIFICADO — campo `frame` aditivo en cada NavItem de tenant
│   │   │   └── interfaces/navigation.interface.ts                      # MODIFICADO — `NavItem.frame?`, `TENANT_FRAME_GROUP_ORDER`
│   │   └── shared/icon/
│   │       ├── icon.component.ts                                       # MODIFICADO — ~18 `@case` nuevos (research R2)
│   │       └── icon.component.spec.ts                                   # AMPLIADO
└── public/                                                                # sin cambios — tipografías ya autoalojadas (spec 095)
```

**`pos-backend/`**: sin cambios.

**Structure Decision**: se respeta la estructura existente de `pos-heladeria` sin inventar
carpetas nuevas. Los dos componentes nuevos van junto a `sidebar.component.ts`/`header.component.ts`
en `modules/dashboard/layout/`, porque son la misma responsabilidad (el shell del panel) para una
identidad de usuario distinta — no son un módulo de dominio aparte. `PanelThemeService` va en el
mismo directorio por la misma razón: su único consumidor es este shell. `LayoutService` se
extiende donde está, en vez de crear un servicio paralelo, porque `desktopCollapsed` y
`sidebarOpen` son dos aspectos del mismo concepto (visibilidad del sidebar) y deben poder
razonarse juntos. Los íconos nuevos entran al `IconComponent` ya existente en `shared/icon/`
porque ese es, literalmente, el catálogo de íconos "estilo Lucide" del proyecto — crear uno
paralelo duplicaría el concepto que la spec 092 ya resolvió ahí.

### Orden de implementación sugerido (unidades verificables, Principio VI)

| Unidad | Qué entrega | Por qué en este orden |
|---|---|---|
| **1** | Íconos nuevos en `IconComponent` + bloque `.panel-theme` en `styles.css` + script anti-parpadeo en `index.html` | Nada visual puede montarse sin esto; se prueba solo (cada ícono renderiza, cada token resuelve en ambos temas) |
| **2** | `PanelThemeService` + extensión de `LayoutService` (`desktopCollapsed`) | Los dos servicios de estado que todo lo demás consume; se prueban aislados, sin DOM |
| **3** | `navigation.config.ts`/`navigation.interface.ts` — campo `frame` en los 15 `NavItem` de tenant | Es el contrato de datos que `app-tenant-sidebar` necesita; se verifica contra la tabla de [contracts/navigation-grouping-contract.md](./contracts/navigation-grouping-contract.md) antes de tener ningún componente que la consuma |
| **4** | `app-tenant-sidebar` (grupos, filtrado por rol/plan reutilizado, colapso, drawer, tooltip) | Cierra la Historia 1 y la mitad de la 3 |
| **5** | `app-tenant-header` (título dinámico, notificaciones reutilizadas, interruptor de tema, indicador de caja, menú de usuario) | Cierra la Historia 2 y la otra mitad de la 3 |
| **6** | `dashboard-layout.component.ts` — la bifurcación de una línea | Último paso: conecta todo lo anterior a la aplicación real; antes de este paso nada de lo nuevo es alcanzable desde la UI, así que es el punto de menor riesgo para integrarlo |
| **7** | Recorrido manual completo y auditoría Lighthouse | Lo que los tests no ven; cierra las tres historias y SC-001 a SC-006 |

## Complexity Tracking

> Se llena solo cuando el Constitution Check tiene violaciones que haya que justificar. Aquí no
> hay violaciones, pero sí dos decisiones de diseño con una consecuencia que vale la pena dejar
> escrita en vez de descubrirla después.

| Punto | Por qué es necesario | Alternativa más simple, y por qué se rechazó |
|---|---|---|
| La lógica de filtrado tenant de `SidebarComponent`/`HeaderComponent` queda sin alcanzar desde la aplicación en ejecución, aunque sus tests sigan verificándola | Es la consecuencia directa de no tocar el panel de Super Admin (research R1); limpiarla exigiría modificar un componente que esta spec no necesita tocar | Eliminar esa lógica ahora: rechazada por el Principio V — sería una refactorización no solicitada de código fuera del alcance de esta spec, y además perdería la cobertura de regresión que hoy protege al propio Super Admin si alguna vez vuelve a compartir esa rama |
| `app-tenant-header` dispara `CashService.discoverOpenShift()` en su inicialización para `ADMIN`/`CASHIER`, una petición de red que hoy no ocurre hasta que se visita Caja o Terminal de Mesas | Sin esto, el indicador de caja mentiría ("sin turno") para cualquiera que no haya visitado esas pantallas en la sesión — mostrar un indicador incorrecto es peor que no tenerlo (research R8) | No mostrar el indicador en el navbar global y dejarlo solo donde ya vive hoy (Terminal de Mesas): rechazada porque las Assumptions de la spec sí lo esperan en el nuevo navbar; se documenta el costo en vez de ignorarlo, con el guard (`!shift()`) que ya usa `PosTerminalStore` para no duplicar la llamada si el dato ya se conoce |

---

**Artefactos generados (iteración 2026-10-12)**: [research.md](./research.md) R1-R14,
[data-model.md](./data-model.md), [quickstart.md](./quickstart.md),
[contracts/navigation-grouping-contract.md](./contracts/navigation-grouping-contract.md),
[contracts/panel-theme-contract.md](./contracts/panel-theme-contract.md),
[contracts/tenant-layout-contract.md](./contracts/tenant-layout-contract.md). **Estado**:
implementada, verificada en vivo, fusionada a `develop` (PR #36).

---

# Iteración 2026-10-13 — Tema global al contenido de los módulos + micro-interacciones de carga

**Punto de partida**: `develop` de `pos-heladeria`, limpio, con la iteración anterior ya fusionada.
Esta sección NO repite lo que la iteración anterior ya resolvió y sigue vigente (R1-R12: el shell
bifurcado por rol, los íconos artesanales, el script anti-parpadeo, el colapso de escritorio, el
punto de quiebre reactivo, el tooltip accesible, el indicador de caja) — solo documenta lo que el
alcance ampliado de la sesión de clarificación 2026-10-13 (spec.md) añade o cambia.

## Resumen de la iteración

El alcance ampliado tiene **seis piezas técnicas independientes**, cada una resuelta en su propia
sección de [research.md](./research.md) (R15-R21), con una característica común: ninguna requiere
una dependencia nueva, ningún cambio en `pos-backend`, y ninguna reabre una decisión de negocio ya
cerrada.

1. **El tema oscuro llega al contenido de ~18 módulos sin tocarlos archivo por archivo** (research
   R16): Tailwind CSS v4 compila sus utilidades de color a `var(--color-*)`, no a valores literales
   — verificado compilando el motor real, no asumido. Redeclarar esas variables bajo
   `.panel-theme[data-theme='dark']` (la misma técnica que R3 ya usó para `--panel-color-*`, ahora
   también sobre el espacio de nombres propio de Tailwind) repinta automáticamente las ~1800
   ocurrencias de `gray`/`slate` ya existentes en el código, sin editarlas. `white`/`black` quedan
   fuera de ese mecanismo a propósito (R16: `text-white` es, casi sin excepción, texto de botón
   sobre fondo saturado — redeclarar `--color-white` lo rompería) y se resuelven con una lista
   corta y cerrada de selectores dirigidos.
2. **Terminal de Mesas necesita una normalización previa, no automática** (research R16,
   confirmada con el usuario): 417 colores hex literales (`bg-[#f3f4f6]`, etc.) en 11 archivos no
   usan variables de Tailwind — son los mismos valores exactos de la paleta estándar, escritos
   distinto. Se normalizan a su clase Tailwind equivalente (sustitución mecánica, cero cambio
   visual en claro) **antes** de que la pieza 1 pueda alcanzarlos.
3. **Dos superficies deben resistir el repintado**: el reporte de cierre de caja y la hoja de QR de
   mesas (research R17) — una clase `.force-light-surface` que re-fija las mismas variables de
   vuelta a su valor claro, anidada dentro de la zona oscura.
4. **El único overlay de CDK del panel (Promociones) necesita que se le avise del tema** (research
   R18) — se sincroniza una sola vez, de forma centralizada, el `cdk-overlay-container` compartido
   de toda la app.
5. **Las gráficas (Chart.js) no se repintan con CSS** (research R19) — es el único punto que exige
   tocar TypeScript: `chart-theme.ts` gana un parámetro de tema, consumido por sus 3 componentes.
6. **Barra de carga + skeleton genérico + aparición escalonada en cada transición de navegación**
   (research R20/R21) — un servicio nuevo (`NavigationTransitionService`, fases `idle`/`out`/
   `skeleton`/`in`, data-model.md §6.1) que reproduce, con `Router.events` real en vez del
   `setTimeout` del prototipo, la coreografía que `Layout base.dc.html` ya define (barra de
   progreso simulada, aparición escalonada), con un límite explícito: el escalonado alcanza los
   bloques de nivel superior de cada vista (3-6 por página típicamente, verificado), nunca las
   filas internas de una tabla — y se omite por completo bajo `prefers-reduced-motion` (primera
   vez que el proyecto lee esa preferencia).

## Technical Context — ampliación 2026-10-13

**Language/Version**: sin cambios (TypeScript 5.x / Angular 21.1, `pos-heladeria`). Se usa por
primera vez `@angular/cdk/overlay` (`OverlayContainer`, R18) — ya una dependencia existente, cero
paquetes nuevos — y se reutiliza `chart.js`/`ng2-charts` (ya existente) con un parámetro nuevo.

**Primary Dependencies**: sin cambios. **Ninguna dependencia nueva** (Principio IX satisfecho por
ausencia, igual que la iteración anterior).

**Storage**: sin nuevas claves de `localStorage`. La coreografía de navegación (`phase`, `barWidth`)
es estado efímero en memoria (signals de `NavigationTransitionService`), nunca persistido — no hay
nada que recordar entre cargas de página para una barra de progreso.

**Testing**: Vitest, mismo patrón. Nuevos: `navigation-transition.service.spec.ts` (fases,
cronómetro con fake timers, cancelación en navegaciones rápidas sucesivas — Historia 4 Escenario
5), ampliación de `chart-theme.spec.ts`/los 3 `*chart*.component.spec.ts` (tema pasado a
`baseOptions`), verificación dirigida (no exhaustiva) de que la normalización de Terminal de Mesas
no cambió ningún snapshot/test existente en claro.

**Target Platform**: sin cambios — mismo panel, mismos tres formatos, mismo punto de quiebre único
(1024px, reafirmado en research R15 contra la tentación del sub-corte de 768px del archivo de
diseño).

**Project Type**: sin cambios. `pos-backend` intacto.

**Performance Goals**:
- La coreografía de navegación (R20) nunca revela el contenido real antes de que
  `NavigationEnd` dispare **ni** antes de que el cronómetro fijo mínimo termine — lo que ocurra
  después — para no verse brusca en una navegación caliente ni incompleta en una fría (primera
  visita a una ruta perezosa con descarga real).
- El repintado de tema (R16) es una sola reasignación de variables CSS en el nodo raíz; el
  navegador recalcula estilos, no vuelve a crear DOM — mismo costo de repintado que ya tiene hoy
  alternar `.panel-theme[data-theme]` para el marco, solo que ahora con más reglas CSS leyendo esas
  variables.
- `prefers-reduced-motion` (R21) nunca bloquea ni retrasa ninguna transición de contenido: solo
  omite las reglas CSS de animación, el cambio de vista sigue siendo instantáneo y funcional.

**Constraints**:
- **Ningún FR de la iteración anterior se afloja**: FR-006 (rutas/guards intactos) y el aislamiento
  de Super Admin (R1) siguen vigentes sin excepción — `NavigationTransitionService` y el repintado
  de R16 están acotados a `!isSuperAdmin()`, igual que todo lo demás.
- **FR-010 (reescrito)**: `.panel-theme[data-theme='dark']` puede ahora estilar cualquier
  descendiente del `router-outlet` de tenant — pero **nunca** un descendiente de
  `.force-light-surface` (R17) ni el panel de Super Admin ni las pantallas públicas de auth, que
  ni siquiera están bajo `.panel-theme` (contrato reescrito en
  [contracts/panel-theme-contract.md](./contracts/panel-theme-contract.md) §1).
- **La normalización de Terminal de Mesas (R16) es mecánica, no un rediseño**: cada sustitución
  hex→clase debe producir exactamente el mismo valor computado en tema claro — cualquier diferencia
  visual detectada en el recorrido manual es un error de la sustitución, no una mejora a colar de
  paso.

**Scale/Scope**: 1 servicio nuevo (`NavigationTransitionService`) + 1 extensión de archivo
compartido (`chart-theme.ts`) + 3 componentes de gráfica ampliados + 1 extensión de
`DashboardLayoutComponent` (sincronización de `OverlayContainer`, barra de progreso, contenedor de
transición) + 2 componentes con `.force-light-surface` nueva + ~20-30 líneas nuevas en
`styles.css` (variables `--color-*` bajo `.panel-theme[data-theme='dark']`, selectores de
`white`, regla `prefers-reduced-motion`) + **11 archivos de Terminal de Mesas normalizados**
(~417 sustituciones mecánicas hex→clase) + el botón de colapso reubicado de
`tenant-sidebar.component.ts` a `tenant-header.component.ts` (research R15). **Cero archivos en
`pos-backend`. Cero dependencias nuevas. Cero migraciones.**

## Constitution Check — ampliación 2026-10-13

| Principio | Estado | Evidencia |
|---|---|---|
| **I** | ✅ PASA | spec.md ampliado con Historia 4, FR-018 a FR-022, SC-007 a SC-009, sesión de clarificación propia (2026-10-13). Sin `NEEDS CLARIFICATION` pendiente. |
| **II** | ✅ PASA | Mismo criterio que R10 original, reaplicado: el repintado de tema y la coreografía de navegación son presentación/adorno, no reglas de negocio — ningún comportamiento protegido cambia. Sin entradas nuevas en el registro de anomalías. |
| **III** | ✅ PASA | Sin tests `"CONGELA comportamiento actual:"` en el área tocada (mismo `grep` que R original, repetido para los archivos nuevos de esta iteración). |
| **IV** | ✅ PASA | El tema extendido y las micro-interacciones son comportamiento nuevo autorizado por FR-018 a FR-022. |
| **V** | ✅ PASA, con una excepción documentada y confirmada con el usuario | La normalización de Terminal de Mesas (417 ocurrencias, 11 archivos) *parece* una refactorización amplia, pero es mecánica (hex→clase equivalente exacta, cero cambio visual) y es un **prerrequisito técnico**, no una limpieza oportunista — sin ella, FR-010 no se puede cumplir ahí. Se confirmó explícitamente con el usuario antes de incluirla en el plan (ver research.md R16, nota de confirmación). |
| **VI** | ✅ PASA | Seis unidades independientes y verificables (normalización de Terminal de Mesas → repintado de tema → `.force-light-surface` → overlay de CDK → gráficas → coreografía de navegación), cada una con su propio criterio de verificación. |
| **VII**/**VIII** | ✅ N/A | Sin datos de servidor ni modelo que evolucionar — igual que la iteración anterior. |
| **IX** | ✅ PASA | Cero dependencias nuevas — `@angular/cdk/overlay` y `chart.js`/`ng2-charts` ya existían. |
| **X** | ✅ PASA | Tests nuevos por unidad + recorrido manual ampliado en quickstart.md (dark mode en vivo sobre los 18 módulos, Terminal de Mesas, impresión, `prefers-reduced-motion`, navegación rápida sucesiva). |
| **XI** | ✅ PASA | La única decisión con consecuencia de alcance real (normalizar vs. excluir Terminal de Mesas) se escaló al usuario en vez de decidirse en silencio — ver research.md R16. |
| **XII** | ✅ PASA | Cada FR nuevo tiene su decisión en research.md (R15-R21), su contrato y su paso de validación en quickstart.md. |
| **XIII**/**XIV**/**XV** | ✅ PASA | Sin cambios de criterio frente a la iteración anterior. Nueva rama `feat/116-layout-base-panel-admin` **desde `develop`** (la anterior ya se fusionó). |

## Project Structure — ampliación 2026-10-13

```text
pos-heladeria/
├── src/
│   ├── styles.css                                          # AMPLIADO — variables --color-gray-*/--color-slate-* bajo
│   │                                                        #   .panel-theme[data-theme='dark'] (R16); selectores .bg-white/
│   │                                                        #   .focus\:bg-white/.hover\:bg-white (R16); .force-light-surface (R17);
│   │                                                        #   @media (prefers-reduced-motion: reduce) (R21); clase/keyframes de
│   │                                                        #   la barra de progreso y el fade-in escalonado (R20)
│   │   ├── app/
│   │   │   ├── modules/dashboard/layout/
│   │   │   │   ├── dashboard-layout.component.ts            # MODIFICADO — inyecta OverlayContainer (R18, effect() de sincronización);
│   │   │   │   │                                             #   monta el contenedor de transición/barra de progreso (R20)
│   │   │   │   ├── tenant-sidebar.component.ts               # MODIFICADO — se retira el botón de colapso (vuelve al header, R15)
│   │   │   │   ├── tenant-header.component.ts                 # MODIFICADO — botón de menú/colapso único, siempre visible (R15)
│   │   │   │   ├── navigation-transition.service.ts            # NUEVO — fases idle/out/skeleton/in, cronómetro, cancelación (R20)
│   │   │   │   └── navigation-transition.service.spec.ts        # NUEVO
│   │   │   └── (ningún otro archivo de dashboard/layout cambia)
│   │   ├── shared/charts/
│   │   │   ├── chart-theme.ts                                 # MODIFICADO — baseOptions(kind, theme), axisColors(theme) (R19)
│   │   │   ├── chart-theme.spec.ts                             # AMPLIADO
│   │   │   ├── bars-chart.component.ts                          # MODIFICADO — inyecta PanelThemeService
│   │   │   ├── ranked-bars-chart.component.ts                    # MODIFICADO — ídem
│   │   │   └── share-bar-chart.component.ts                       # MODIFICADO — ídem
│   │   └── modules/
│   │       ├── cash-register/components/cash-report.component.ts   # MODIFICADO — clase .force-light-surface en la raíz (R17)
│   │       └── tables/
│   │           ├── pages/table-qr-sheet.component.ts                 # MODIFICADO — clase .force-light-surface en la raíz (R17)
│   │           ├── pages/manual-order-page.component.ts                # MODIFICADO — normalización hex→clase (R16, ~207 sustituciones)
│   │           ├── components/pos-checkout-panel.component.ts           # MODIFICADO — normalización hex→clase (~51)
│   │           ├── components/pos-order-panel.component.ts               # MODIFICADO — normalización hex→clase (~49)
│   │           ├── components/pos-terminal-header.component.ts            # MODIFICADO — normalización hex→clase (~26)
│   │           ├── components/pos-tables-panel.component.ts                # MODIFICADO — normalización hex→clase (~19)
│   │           ├── pages/table-sessions.component.ts                         # MODIFICADO — normalización hex→clase (~16)
│   │           ├── services/pos-terminal.store.ts                            # MODIFICADO — normalización hex→clase (~13, incl. STATUS_META)
│   │           ├── components/session-bill-panel.component.ts                 # MODIFICADO — normalización hex→clase (~13)
│   │           ├── components/bill-summary.component.ts                        # MODIFICADO — normalización hex→clase (~11)
│   │           ├── components/order-summary-card.component.ts                   # MODIFICADO — normalización hex→clase (~9)
│   │           └── components/cart-item-options.component.ts                     # MODIFICADO — normalización hex→clase (~3)
└── (pos-backend: sin cambios)
```

### Orden de implementación sugerido — ampliación 2026-10-13

| Unidad | Qué entrega | Por qué en este orden |
|---|---|---|
| **8** | Normalización hex→clase de los 11 archivos de Terminal de Mesas (research R16) | Es un prerrequisito mecánico y autocontenido de la unidad 9 — se verifica solo (cero diff visual en claro) antes de que nada dependa de ella |
| **9** | Variables `--color-gray-*`/`--color-slate-*` + selectores `white` bajo `.panel-theme[data-theme='dark']` en `styles.css` (research R16) | El cambio de mayor impacto visual; con la unidad 8 ya hecha, repinta los ~18 módulos de una sola vez |
| **10** | `.force-light-surface` en `cash-report.component.ts`/`table-qr-sheet.component.ts` (research R17) | Depende de que la unidad 9 ya exista (si no hay nada que anular, no hay nada que verificar) |
| **11** | Sincronización de `OverlayContainer` en `DashboardLayoutComponent` (research R18) | Depende de la unidad 9 (mismas variables); se verifica abriendo el único desplegable de CDK del panel (Promociones) |
| **12** | `chart-theme.ts` + sus 3 componentes consumidores (research R19) | Independiente de las unidades 8-11; se verifica en Reportes, el único consumidor |
| **13** | Reubicación del botón de colapso al header (research R15) | Ajuste estructural pequeño y aislado, sin dependencias de las unidades anteriores |
| **14** | `NavigationTransitionService` + barra de progreso + skeleton genérico + CSS de aparición escalonada (research R20/R21) | La unidad más grande y nueva; se deja al final porque no depende de ninguna de las anteriores y es la más fácil de verificar de forma aislada (navegar entre secciones) |
| **15** | Recorrido manual completo (quickstart.md ampliado) y auditoría Lighthouse repetida en modo oscuro | Cierra la Historia 2 ampliada, la Historia 4 completa, y SC-007 a SC-009 |

## Complexity Tracking — ampliación 2026-10-13

| Punto | Por qué es necesario | Alternativa más simple, y por qué se rechazó |
|---|---|---|
| La normalización de Terminal de Mesas toca 11 archivos y ~417 líneas, el cambio de mayor volumen de todo el historial de esta spec | Sin ella, la pantalla más usada por Cajero/Mesero quedaría con una "isla clara" permanente contradiciendo SC-007 directamente — confirmado con el usuario que vale la pena el volumen a cambio de que Terminal de Mesas sí cumpla el tema oscuro en esta misma iteración | Excluir Terminal de Mesas del alcance ampliado (documentarla como excepción, como el reporte de caja): rechazada por decisión explícita del usuario — ver research.md R16 |
| El escalonado de aparición (FR-020) no alcanza las filas internas de una tabla real, solo las secciones de nivel superior de cada página | Escalonar 200 filas reales a 55ms cada una tardaría ~11 segundos — no es una interpretación más estricta posible, es aritmética | Pedir a cada módulo que marque sus bloques "escalonables": rechazada porque exige tocar los mismos ~18 módulos que el resto de esta iteración evita tocar (research R20) |
| `--color-white`/`--color-black` de Tailwind quedan fuera del mecanismo general de R16, resueltos con una lista de selectores en vez de variables | `text-white` (135 ocurrencias) es casi siempre texto de botón sobre fondo saturado — redeclarar la variable compartida rompería el contraste de todo botón primario del panel (research R16) | Redeclarar `--color-white` de todas formas y aceptar el texto de botón oscuro: rechazada, es una regresión de legibilidad real, no un detalle menor |

---

**Artefactos generados (iteración 2026-10-13)**: [research.md](./research.md) R15-R21
(continuación del mismo archivo); [data-model.md](./data-model.md) §6;
[quickstart.md](./quickstart.md) pasos 10-16; `contracts/panel-theme-contract.md` §1 reescrita y
§6-§9 nuevas; `contracts/tenant-layout-contract.md` §2-§3 actualizadas (research R15);
[contracts/navigation-transition-contract.md](./contracts/navigation-transition-contract.md)
(nuevo). `contracts/navigation-grouping-contract.md` no cambia (research R15: el archivo de
diseño vigente no altera grupos/etiquetas/íconos).

**Siguiente paso**: `/speckit-tasks` para regenerar `tasks.md` con las unidades 8 a 15 de arriba,
añadidas a continuación de las unidades 1-7 ya completadas de la iteración anterior.
