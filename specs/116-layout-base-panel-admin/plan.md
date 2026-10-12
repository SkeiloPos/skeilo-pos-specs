# Implementation Plan: Layout base del panel (Sidebar + Navbar) con tema claro/oscuro persistente

**Branch**: la spec vive en `specs/116-layout-base-panel-admin/` de `pos-specs`, rama `main`. La
rama de código es `feat/116-layout-base-panel-admin` en `pos-heladeria`, y **solo ahí** (Principio
XIV) — `pos-backend` no participa y no necesita rama. | **Date**: 2026-10-12 | **Spec**:
[spec.md](./spec.md)

**Input**: Feature specification from `/specs/116-layout-base-panel-admin/spec.md`

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

**Artefactos generados**: [research.md](./research.md), [data-model.md](./data-model.md),
[quickstart.md](./quickstart.md),
[contracts/navigation-grouping-contract.md](./contracts/navigation-grouping-contract.md),
[contracts/panel-theme-contract.md](./contracts/panel-theme-contract.md),
[contracts/tenant-layout-contract.md](./contracts/tenant-layout-contract.md).

**Siguiente paso**: `/speckit-tasks` para generar `tasks.md`, siguiendo el orden de
implementación sugerido arriba.
