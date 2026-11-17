# Research: Ocultar sección de Inventario en el formulario de carta según el plan

**Feature**: `160-gating-inventario-form-menu` | **Fecha**: 2026-11-17

## Alcance de la investigación

Esta feature es un cambio puramente de frontend (pos-heladeria, Angular). No introduce
nuevos endpoints, nuevas dependencias ni cambios de modelo de datos. El objetivo de esta
fase de research es confirmar que existe ya un mecanismo consistente para "ocultar
completamente, sin pérdida de datos" una sección dependiente del módulo de Inventario, y
localizar con precisión el código actual que debe cambiar.

## Decisión 1: Fuente de verdad del estado del plan

- **Decision**: Usar `PlanSummaryService` (`src/app/modules/plan/services/plan-summary.service.ts`),
  ya inyectado en `ProductFormComponent`, como única fuente del estado del módulo
  Inventario. No se introduce ningún mecanismo de consulta nuevo.
- **Rationale**: Es la misma fuente que ya usan `SettingsPageComponent`,
  `TenantSidebarComponent`/`SidebarComponent` y `ReportsPageComponent`/`ReportsService`
  para decidir qué se muestra según el plan vigente. `PlanSummaryService.summary` es un
  signal poblado por `BootstrapService.hydrate()` al iniciar la app
  (`src/app/core/bootstrap/bootstrap.service.ts:29`), por lo que al abrir el formulario de
  carta el estado del plan ya está disponible sin necesidad de un fetch adicional
  (satisface FR-004: refleja el estado vigente al cargar el formulario, no un valor
  cacheado de sesiones previas, porque el hydrate ocurre en cada carga de la app).
- **Alternatives considered**:
  - Introducir un nuevo servicio/flag específico para esta sección → rechazado: duplicaría
    lógica ya existente y rompería la consistencia exigida por FR-007 con otras superficies
    (ajustes, reportes).
  - Consultar el plan directamente vía HTTP en `ProductFormComponent` → rechazado:
    `PlanSummaryService` ya resuelve esto de forma centralizada; no hay justificación de
    negocio para una fuente paralela.

## Decisión 2: Patrón de "ocultar completamente" a reutilizar

- **Decision**: Replicar el patrón ya usado en `ReportsPageComponent`
  (`src/app/modules/reports/pages/reports-page.component.ts:89,194-197`), que envuelve una
  sección completa en `@if (svc.inventarioIncluido()) { <section>...</section> }`, respaldado
  por un `computed()` fail-closed (`summary !== null && summary.modules.inventario && !summary.vencido`,
  `src/app/modules/reports/services/reports.service.ts:83-86`).
- **Rationale**: Es el precedente más cercano a "ocultar una sub-sección completa dentro de
  una página/formulario más grande" (a diferencia de `SettingsPageComponent`, que oculta
  pestañas completas de navegación, y de los sidebars, que ocultan ítems de menú). Reusar
  este patrón exacto satisface FR-007 (consistencia con otras superficies dependientes de
  Inventario).
- **Alternatives considered**:
  - Crear una directiva estructural compartida (`*appHasModule`) → rechazado: no existe hoy
    en la base de código (confirmado por búsqueda); introducirla sería una refactorización
    no relacionada con esta funcionalidad (Principio V de la constitución) y afectaría a
    cuatro componentes existentes fuera del alcance de este spec. Queda registrado como
    posible mejora técnica futura, no parte de esta feature.
  - Mantener el patrón "deshabilitado + upsell" actual pero solo quitar el texto de upsell →
    rechazado: no satisface FR-002, que exige omitir por completo la sección, no solo su
    mensaje.

## Decisión 3: Fail-closed vs. fail-open para esta sección

- **Decision**: Mantener el `computed()` `inventarioIncluido` ya existente en
  `ProductFormComponent` (`product-form.component.ts:664-671`), que es fail-closed
  (`summary === null` → la sección no se muestra), igual que en `ReportsPageComponent`.
- **Rationale**: Es el mismo computed que el componente ya usa hoy para deshabilitar el
  interruptor "Maneja inventario"; no se modifica su semántica, solo su uso en el template
  (de "deshabilitar" a "ocultar"). Mantiene exactamente el comportamiento de Reports, el
  precedente elegido en la Decisión 2. El pequeño efecto cosmético de que la sección no
  aparezca durante el instante en que el plan aún no ha hidratado es idéntico al que ya
  tiene Reports hoy; no es un comportamiento nuevo introducido por esta feature.
- **Alternatives considered**:
  - Cambiar a fail-open (como `visibleTabs`/`visibleItems` en settings/sidebar) → rechazado:
    cambiaría la semántica de un computed ya usado por otra lógica del mismo componente
    (`sectionsEnabled`), fuera del alcance mínimo de este spec, y se alejaría del precedente
    de Reports elegido como referencia.

## Decisión 4: Elementos adicionales a ocultar junto con la sección

- **Decision**: Además de la sección 3 "Inventario" completa (líneas ~294-375 de
  `product-form.component.ts`), ocultar también el botón de salto "Inventario"
  (`goToInventory`, líneas ~269-272) en la tabla de tamaños/presentaciones, envolviéndolo en
  la misma condición `@if (inventarioIncluido())`.
- **Rationale**: Ese botón hace scroll a `#product-form-inventario`; si la sección deja de
  renderizarse, el botón quedaría roto (apuntando a un elemento inexistente). Es el mismo
  elemento condicionado por el mismo flag, por lo que ocultarlo es consistente con FR-002
  ("omitir por completo... para todos los tamaños/presentaciones").
- **Alternatives considered**:
  - Dejar el botón visible pero sin efecto → rechazado: violaría FR-002 (deja un rastro
    visible de la sección "Inventario" aunque el plan no la incluya) y dejaría un control
    roto en la UI.

## Decisión 5: Qué NO se oculta

- **Decision**: La sección 4 "Sabores a elegir" (grupos de opciones) permanece siempre
  visible; solo sus sub-campos específicos de inventario (cantidad a descontar, detalle de
  insumo) siguen gateados por el `computed()` existente `sectionsEnabled()`
  (`product-form.component.ts:679-683`), sin cambios.
- **Rationale**: El spec (FR-002, FR-003) solo exige ocultar la sección "Inventario" en sí
  (el interruptor "Maneja inventario" y su contenido asociado). "Sabores a elegir" es dato
  de carta (grupos/mín/máx), no de inventario; el código ya documenta esta distinción
  explícitamente (comentario referenciando spec 064, FR-006). Tocar esa sección estaría
  fuera del alcance de este spec.
- **Alternatives considered**: Ninguna — no hay ambigüedad en el spec sobre este punto.

## Decisión 6: Persistencia de datos existentes (FR-005, FR-006)

- **Decision**: No se modifica el modelo `draft().tracks_inventory` ni la lógica de guardado
  del formulario. Ocultar la sección es exclusivamente un cambio de template (visibilidad
  condicional); los datos de inventario ya guardados en el producto/tamaño no se tocan al
  guardar con la sección oculta, porque el payload de guardado no se altera por este cambio.
- **Rationale**: El spec exige explícitamente (FR-005) que ocultar la sección no borre ni
  modifique configuración existente. Al no cambiar la lógica de guardado ni el modelo de
  datos, el payload enviado al backend cuando la sección está oculta es el mismo que ya se
  envía hoy para un producto cuyo `tracks_inventory` está en `true` pero el interruptor está
  deshabilitado — es decir, el valor existente viaja intacto sin intervención del usuario.
- **Alternatives considered**:
  - Forzar `tracks_inventory = false` en el payload cuando la sección está oculta →
    rechazado explícitamente: violaría FR-005/FR-006 y el Edge Case que exige conservar
    configuración de inventario existente al perder el acceso al módulo.

## Resumen: NEEDS CLARIFICATION resueltos

No quedan `NEEDS CLARIFICATION` pendientes. Todos los puntos de Technical Context se derivan
directamente del código ya existente en `pos-heladeria` (Angular 21, TypeScript 5.9), sin
necesidad de nuevas dependencias, nuevos endpoints ni cambios de esquema.
