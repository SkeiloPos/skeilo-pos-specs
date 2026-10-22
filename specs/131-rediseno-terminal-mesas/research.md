# Research: Rediseño visual de la Terminal de Mesas

Este spec no dejó ninguna `NEEDS CLARIFICATION` pendiente en el Technical Context (las 5
preguntas abiertas ya se resolvieron en la sección "Clarifications" del spec, 2026-10-22).
Este documento recoge las decisiones técnicas necesarias para ejecutar el rediseño, cada una
con su justificación y alternativas descartadas.

## 1. Componente host real de la Terminal de Mesas

- **Decision**: El componente a rediseñar es `table-sessions.component.ts`
  (`app-table-sessions`), no `tables-page.component.ts`.
- **Rationale**: `tables-page.component.ts` es la pantalla de administración CRUD de mesas y
  generación de códigos QR (`/dashboard/mesas`) — no compone `app-pos-tables-panel` ni
  `app-pos-order-panel`. `table-sessions.component.ts` sí compone
  `<app-pos-terminal-header />`, `<app-pos-tables-panel />`, `<app-pos-order-panel />` y
  `<app-pos-checkout-panel />`, y sus propios comentarios internos documentan la historia de
  por qué `pos-order-panel` cae a `store.firstPendingOrder()` cuando no hay
  `selectedOrderId` — es, sin ambigüedad, la pantalla "Terminal de Mesas" del spec.
- **Alternatives considered**: Rediseñar `tables-page.component.ts` por su nombre más obvio
  — descartado tras confirmar por grep que no referencia ninguno de los componentes de
  grilla/detalle/cobro que el spec describe.

## 2. Fuente de tokens visuales ("modelo de caja")

- **Decision**: Portar los valores de
  `design/_ds/skeilopos-design-system-*/tokens/{colors,spacing,typography,base,effects,theme-light}.css`
  como la fuente de verdad de bordes, radios, espaciados, tipografía y color para los
  componentes rediseñados, en vez de inventar valores leyendo solo el HTML del mockup.
- **Rationale**: El mockup (`SkeiloPOS.html`) referencia variables CSS (`var(--color-surface)`,
  `var(--color-border)`, `border-radius:16px`, etc.) definidas en ese paquete de design
  system, que además trae un `readme.md` y un manifiesto (`_ds_manifest.json`) pensados para
  portarse a un proyecto de código real. Leer los tokens ahí evita adivinar valores a partir
  de estilos inline dispersos por las 2179 líneas del mockup.
- **Alternatives considered**: Extraer los valores directamente de los estilos inline del
  HTML uno por uno — descartado porque el HTML es una exportación de herramienta de diseño
  (nombres de variable generados, `sc-if`/`x-import`) pensada para reproducirse visualmente,
  no para leerse como fuente de verdad de tokens; el paquete `_ds` es la fuente normalizada
  para eso.

## 3. Iconografía

- **Decision**: Introducir un componente de iconos nuevo (estilo `lucide`, SVG inline) para
  los flujos rediseñados, dejando intacto `app-mi-icon` (`icon-mi.component.ts`, basado en
  Material) para el resto de la aplicación.
- **Rationale**: El mockup resuelve sus iconos vía
  `<x-import component-from-global-scope="SkeiloPOSDesignSystem_....Icon" name="plus" .../>`
  — un componente de icono por nombre, con el set "lucide" (confirmado por el nombre de
  icono `plus`, `layout-grid`, `cup-soda`, `credit-card`, etc. encontrados en el mockup, que
  son nombres de icono literales de la librería lucide). `app-mi-icon` ya se usa en 7
  llamadas solo dentro de `pos-order-panel`, 4 en `payment-attempt-review-panel`, 3 en
  `pos-terminal-header`/`pos-checkout-panel`, 2 en `pos-tables-panel`/`product-select`, 1 en
  `pos-catalog-drawer`/`cart` — reemplazarlas todas por fidelidad visual (Assumptions del
  spec) es parte explícita del alcance.
- **Alternatives considered**:
  - Agregar la dependencia npm `lucide-angular` — descartada por ahora: no hay necesidad de
    traer una librería externa completa cuando el set de iconos requerido es acotado (los
    mismos ~15-20 nombres que aparecen en el mockup) y el proyecto ya tiene el patrón de un
    componente de icono propio (`app-mi-icon`) que recibe un `name` y renderiza el SVG
    correspondiente; replicar ese mismo patrón con los SVGs de lucide necesarios evita sumar
    una dependencia nueva sin justificar alternativas/impacto como exige el Principio IX. Si
    en la fase de tareas se concluye que el volumen de iconos lo justifica, se puede
    reconsiderar — pero esa sería una decisión a tomar (y justificar) en `tasks.md`/
    implementación, no en este plan.
  - Seguir usando `app-mi-icon` (Material) y solo cambiar el resto del layout — descartada
    porque el spec exige explícitamente fidelidad de iconografía ("la iconografía del diseño
    de referencia... reemplaza a la iconografía Material actual... en los dos flujos
    rediseñados", Assumptions del spec).

## 4. Pestañas "Cuentas" → "Pedido N" / "Nueva cuenta"

- **Decision**: Reutilizar literalmente el bloque `accOn` del mockup (markup
  `role="tablist"` con botones `role="tab"` + badge de conteo + botón punteado "Nueva
  cuenta") como el componente visual de las pestañas de pedido dentro de
  `pos-order-panel.component.ts`, cambiando únicamente los textos ("Pedido 1", "Pedido 2", …)
  y cableando el botón "Nueva cuenta" a la misma acción que hoy dispara el botón "+ Crear
  pedido nuevo" de la sub-barra (ver store: creación de pedido en paralelo sobre la misma
  mesa, spec 087).
- **Rationale**: FR-022 exige exactamente esta reutilización 1:1 de componente visual; el
  mockup ya separa ese bloque en una sección propia (`accOn`) con su propio estilo de
  pestaña tipo "pill" y contador, independiente del resto del detalle.
- **Alternatives considered**: Diseñar una pestaña nueva "Pedido N" desde cero con estilo
  propio — descartada, contradice FR-022 (fidelidad al componente de referencia) sin
  aportar nada que el bloque `accOn` no resuelva ya.

## 5. Paneles de validación de pago QR (`tdQrOn`/`tdQ2On`/`tdQ3On`)

- **Decision**: Construir los tres paneles como variantes de un mismo componente
  `payment-attempt-review-panel.component.ts` ya existente (hoy cubre efectivo y
  transferencia), extendiéndolo visualmente para el caso mixto (`tdQ3On`) con los campos que
  ya calcula el mockup (`tdM3Nq`, `tdM3Cash`, estado de "comprobante ok"/"pendiente",
  diferencia a favor/en contra) — sin iniciar su validación funcional real porque los campos
  de origen (`cash_amount`/`transfer_amount`/`transfer_method_id`, tipo `'mixed'`) no existen
  aún en la API (dependen del spec 130, estado Draft).
- **Rationale**: El mockup ya trata los tres casos (`tdQrOn`, `tdQ2On`, `tdQ3On`) como
  variantes del mismo bloque lateral (`border-left`, mismo contenedor `padding:20px` sobre
  `--color-surface-soft`), no como tres pantallas separadas; y
  `payment-attempt-review-panel.component.ts` ya existe hoy en el proyecto con 2 variantes
  (efectivo/transferencia) listas para extender a una tercera.
- **Alternatives considered**: Esperar a que el spec 130 esté implementado antes de tocar
  este panel — descartado por la Clarification Q4 ya resuelta con el usuario de negocio: se
  construye el panel visual ahora, documentando que su verificación con datos reales queda
  bloqueada hasta que 130 se implemente (no bloquea el resto de este spec 131).

## 6. Responsive / una sola región de scroll por columna

- **Decision**: Adoptar la distribución de columnas del mockup (grilla de mesas a la
  izquierda / detalle + cobro a la derecha en escritorio ancho; una sola columna a pantalla
  completa con botón de volver en móvil) implementada con flexbox/grid + `overflow:auto`
  acotado a cada columna, sin contenedores de scroll anidados.
- **Rationale**: FR-018/FR-019 y la User Story 4 lo piden explícitamente; el mockup ya separa
  sus contenedores con `overflow:hidden` en el borde exterior y deja el scroll interno
  implícito en cada bloque de contenido, patrón replicable con CSS estándar sin librería
  adicional.
- **Alternatives considered**: Ninguna evaluada — es una extensión directa del layout ya
  presente en el mockup, no una decisión abierta.

## Resumen

No quedan incógnitas técnicas abiertas. Las seis decisiones anteriores fijan: qué componente
Angular se rediseña, de dónde salen los tokens visuales, cómo se resuelve la iconografía sin
dependencias nuevas, cómo se reutiliza el bloque de pestañas y los tres paneles de pago QR, y
cómo se logra el comportamiento responsive exigido — todo consistente con el resto del spec
y sin violar ningún principio de la constitución.
