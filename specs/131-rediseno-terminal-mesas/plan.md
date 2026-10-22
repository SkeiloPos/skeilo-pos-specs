# Implementation Plan: Rediseño visual de la Terminal de Mesas (grilla y detalle de pedido)

**Branch**: `131-rediseno-terminal-mesas` | **Date**: 2026-10-22 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/131-rediseno-terminal-mesas/spec.md`

## Summary

Rediseñar visualmente (layout, componentes, "modelo de caja") las dos pantallas de la
Terminal de Mesas — la grilla principal (`app-table-sessions` + `app-pos-tables-panel`) y el
detalle de pedido (`app-pos-order-panel` + `app-pos-checkout-panel`) — para que coincidan
con el mockup de referencia `design/SkeiloPOS.html` (secciones `isTerminal`, `tcOn`/`tDetOn`),
sin cambiar ningún comportamiento funcional salvo los dos cambios explícitos ya decididos
por negocio (FR-022b, FR-023). Es un cambio exclusivamente de frontend Angular: se
reconstruyen las plantillas y estilos de los componentes existentes reutilizando el design
system de referencia (`design/_ds/.../styles.css` + `tokens/*.css`) como fuente de tokens
(color, radio, espaciado, tipografía), y el set de iconos `lucide` del mockup reemplaza a
`app-mi-icon` en los dos flujos rediseñados. No se toca ningún store, servicio ni endpoint:
`PosTerminalStore` sigue siendo la única fuente de verdad de estado/comportamiento.

## Technical Context

**Language/Version**: TypeScript (Angular, standalone components, signals) — versión ya
fijada por `pos-heladeria/package.json` (no se cambia como parte de este spec).

**Primary Dependencies**: Angular (standalone components + signals), Tailwind-style utility
classes ya en uso en el proyecto (ver `tables-page.component.ts`), `IconMiComponent`
(`app-mi-icon`, hoy basado en Material) a reemplazar por un nuevo componente de iconos
estilo `lucide` en los dos flujos rediseñados (FR nuevo de iconografía, ver Assumptions del
spec). No se introduce ningún paquete npm nuevo: los iconos del mockup se reproducen como
SVG inline o un componente de iconos propio, igual que ya existe `app-mi-icon` hoy (decisión
técnica, no requiere justificación de dependencia nueva por Principio IX de la constitución
porque no se agrega ninguna librería externa).

**Storage**: N/A — este spec no toca el modelo de datos ni la API (confirmado: cero
endpoints nuevos, SC-004).

**Testing**: Jasmine/Karact vía Angular CLI (`ng test`), igual que el resto del proyecto.
Characterization tests existentes con marca `CONGELA comportamiento actual:` ya presentes en
`pos-terminal.store.spec.ts`, `pos-order-panel.component.spec.ts`,
`payment-attempt-review-panel.component.spec.ts` y
`checkout-order-summary.component.spec.ts` siguen siendo la referencia de comportamiento; se
actualizan únicamente los que dependan de selectores/estructura visual específica del diseño
anterior, y los dos casos de FR-022b/FR-023 (con la decisión de negocio ya registrada antes
de tocar código, Principio II/III).

**Target Platform**: Web (navegador), mismo despliegue que el resto de `pos-heladeria`.

**Project Type**: Web application — frontend Angular existente (`pos-heladeria`), sin
contraparte de backend para este spec.

**Performance Goals**: Sin metas de rendimiento específicas más allá de no introducir
regresiones perceptibles; es un cambio de presentación sobre datos ya cargados por el store
existente.

**Constraints**: Debe conservar el 100% del comportamiento funcional actual salvo FR-022b y
FR-023 (SC-001); debe ser responsive en móvil/tablet/escritorio con una única región de
scroll por columna (FR-018, FR-019); no puede crear endpoints nuevos (SC-004); no puede
tocar `PosTerminalStore` más allá de lo necesario para exponer/leer el mismo estado desde la
nueva plantilla.

**Scale/Scope**: 2 pantallas (grilla + detalle), ~9 componentes Angular existentes a
rediseñar (`pos-terminal-header`, `pos-tables-panel`, `pos-order-panel`,
`pos-checkout-panel`, `pos-catalog-drawer`, `payment-attempt-review-panel`, `cart`,
`bill-summary`, `session-bill-panel`, `order-summary-card`) más la plantilla host
`table-sessions.component.ts`; 0 componentes de dominio nuevos (todo reutiliza el modelo de
datos existente).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Evaluación |
|---|---|
| I. Nace de un spec | ✅ `specs/131-rediseno-terminal-mesas/spec.md` existe y está clarificado. |
| II. Comportamiento existente protegido | ✅ Casi todo se preserva; los dos cambios de comportamiento (FR-022b, FR-023) están documentados en el spec con quién/cuándo/qué/por qué y **deben registrarse en `registro-de-anomalias.md` antes de implementarse** (pendiente — tarea de la fase de implementación, no de este plan). |
| III. Characterization tests protegidos | ✅ Solo se tocan los tests `CONGELA comportamiento actual:` afectados por FR-022b/FR-023 o por selectores visuales que cambian; el resto sigue en verde sin modificarse. |
| V. Sin refactors oportunistas | ✅ Alcance limitado a presentación; no se reestructura `PosTerminalStore` ni se "aprovecha" para limpiar código no relacionado. |
| VI. Evolución incremental | ✅ Spec separado en dos vistas (US1 grilla, US2 detalle, US3 cobro, US4 responsive) con prioridades propias, verificables de forma independiente. |
| VII. Datos históricos intactos | ✅ No aplica cambio de datos; el rediseño es puramente visual. |
| VIII. Evolución del modelo de datos | N/A — no hay cambio de modelo de datos. |
| IX. Dependencias nuevas justificadas | ✅ No se agrega ninguna dependencia npm nueva; el reemplazo de iconografía se hace con assets/SVG propios. |
| XIV/XV. Rama y commits | A aplicar en fase de implementación: rama `style/131-rediseno-terminal-mesas` (o `feat/...` si se prefiere, dado que incluye los dos cambios de comportamiento) antes de tocar código en `pos-heladeria`; commits pequeños en inglés, solo bajo pedido explícito del usuario. |

Sin violaciones que requieran justificación en Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/131-rediseno-terminal-mesas/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command) — N/A, ver nota abajo
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

No se genera `contracts/` con definiciones de API: este spec no crea ni modifica ningún
endpoint (SC-004) y no define un contrato nuevo de interfaz pública — reutiliza
exactamente las mismas respuestas de API que ya consume `PosTerminalStore`. El "contrato"
relevante de este spec es visual (fidelidad al mockup), documentado en `data-model.md`
(mapeo componente↔sección del mockup) y `quickstart.md` (guion de validación visual +
funcional).

### Source Code (repository root)

Repositorio de código fuente afectado: `../pos-heladeria` (no `pos-backend`). Estructura
real relevante (ya existente, no se crean carpetas nuevas):

```text
../pos-heladeria/src/app/modules/tables/
├── pages/
│   └── table-sessions.component.ts         # Host real de la Terminal de Mesas
│       (selector app-table-sessions; compone header + tables-panel + order-panel +
│        checkout-panel; NO confundir con tables-page.component.ts, que es la
│        administración CRUD de mesas/QR, fuera de alcance de este spec)
├── components/
│   ├── pos-terminal-header.component.ts     # Cabecera: turno/conexión/caja (FR-001)
│   ├── pos-tables-panel.component.ts        # Grilla de mesas/domicilios/para llevar (FR-002..006)
│   ├── pos-order-panel.component.ts         # Detalle de pedido: líneas, pestañas "Pedido N" (FR-007..011, FR-022, FR-022b, FR-023)
│   ├── pos-checkout-panel.component.ts      # Panel de cobro (FR-012..017)
│   ├── payment-attempt-review-panel.component.ts  # Validación de pago QR (FR-014a/b/c)
│   ├── pos-catalog-drawer.component.ts      # Catálogo embebido "Agregar producto" (FR-009)
│   ├── cart.component.ts                    # Carrito dentro del catálogo
│   ├── cart-item-options.component.ts
│   ├── bill-summary.component.ts            # Desglose subtotal/domicilio/total (FR-012)
│   ├── session-bill-panel.component.ts      # Cuenta de mesa consolidada
│   ├── order-summary-card.component.ts      # Tarjeta de la grilla (FR-004)
│   ├── payment-input.component.ts           # Línea de método de pago (FR-013)
│   └── product-select.component.ts
└── services/
    └── pos-terminal.store.ts                # Única fuente de estado/comportamiento — NO se modifica su lógica, solo se consume desde las plantillas rediseñadas

../pos-heladeria/src/app/shared/icon-mi/
└── icon-mi.component.ts                     # `app-mi-icon` actual (Material) — se reemplaza
                                                por un componente de iconos estilo lucide en
                                                los componentes listados arriba (fuera de ese
                                                alcance, el resto del proyecto sigue usando
                                                `app-mi-icon` sin cambios)
```

Fuente de diseño (solo lectura, repositorio `pos-specs`, no se modifica):

```text
design/
├── SkeiloPOS.html                           # Mockup de referencia (secciones isTerminal, tcOn, tDetOn, tdQrOn, tdQ2On, tdQ3On)
└── _ds/skeilopos-design-system-.../
    ├── tokens/{colors,spacing,typography,base,effects,theme-light,fonts,logo}.css
    └── styles.css                            # Fuente de los tokens (bordes, radios, espaciados, color) a portar como valores/CSS vars en pos-heladeria
```

**Structure Decision**: Opción de proyecto único existente — no se crea ningún módulo,
carpeta ni proyecto nuevo. Todos los cambios viven dentro de
`pos-heladeria/src/app/modules/tables/` (plantillas y estilos de los componentes ya
listados) más, opcionalmente, un componente de iconos nuevo en
`pos-heladeria/src/app/shared/` si no es viable extender `icon-mi.component.ts` sin romper
sus otros consumidores fuera de este spec. El repositorio `pos-specs` no recibe cambios de
código, solo esta documentación de planeación.

## Complexity Tracking

*Sin violaciones de la Constitution Check — tabla vacía, no aplica.*
