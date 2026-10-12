# Implementation Plan: Mostrar presentación elegida en la línea del ítem de la orden manual

**Branch**: `113-presentacion-item-pedido-manual` | **Date**: 2026-10-12 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/113-presentacion-item-pedido-manual/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Cuando se agrega un producto con presentación (variante) obligatoria al carrito de una orden manual, la línea del ítem no muestra qué presentación quedó seleccionada — solo nombre, cantidad y costo. La causa raíz está aislada a una sola función: `PosTerminalStore.cartView()` (en `pos-heladeria/src/app/modules/tables/services/pos-terminal.store.ts`) construye el nombre a mostrar de las líneas de borrador (`draft lines`, ítems recién agregados y aún no guardados) usando únicamente `l.product.name`, descartando `l.variant.name` aunque el objeto `ProductDraftLine` ya conserva la variante completa. Las líneas ya persistidas (`persistedItemsView()`) sí combinan producto + variante mediante `menu-lookup.ts::variantLabel()`, que sólo antepone la variante cuando el producto tiene más de una presentación configurada. El enfoque técnico es: (1) hacer que las líneas de borrador usen el mismo `variantLabel()` que las persistidas, para que ambos tipos de línea produzcan el mismo formato combinado "Producto · Variante"; y (2) añadir el marcado visual (pill) que ya existe en `pos-order-panel.component.ts` (vía `splitVariantLabel()`) también a `manual-order-page.component.ts`, que hoy no tiene ningún marcado de presentación. Como ambas pantallas leen el mismo `cartView()` computed, corregir la fuente de datos cubre automáticamente tanto el carrito de orden nueva (FR-001 a FR-006) como el panel de agregar productos a una orden ya creada (FR-007), sin tocar backend, modelo de datos ni contratos públicos.

## Technical Context

**Language/Version**: TypeScript ~5.9.2 (Angular 21.1, standalone components, signals)

**Primary Dependencies**: Angular core/common/forms, `@tanstack/angular-query-experimental` (no se usa en esta ruta de código, solo presente en el repo), Tailwind CSS para estilos inline en plantillas

**Storage**: N/A (no hay cambios de persistencia; el campo `variant` ya existe en el objeto de borrador en memoria del store)

**Testing**: Vitest vía `npx ng test` (Angular CLI), specs existentes relevantes: `pos-terminal.store.spec.ts`, `manual-order-page.component.spec.ts`, `pos-order-panel.component.spec.ts`, `menu-lookup.spec.ts`

**Target Platform**: Web (navegador), terminal de mesas del POS (uso interno de cajeros/meseros)

**Project Type**: Aplicación web de una sola página (Angular) — este cambio es exclusivamente de frontend

**Performance Goals**: N/A — cambio de presentación de datos ya cargados en memoria, sin impacto medible de rendimiento

**Constraints**: No modificar el modelo de datos del backend ni los contratos de API; no alterar el comportamiento de precio/cálculo ya correcto; mantener el umbral existente de "solo mostrar variante cuando el producto tiene más de una presentación configurada" para no introducir inconsistencias entre líneas persistidas y líneas de borrador

**Scale/Scope**: 2 archivos de producción con cambios funcionales (`pos-terminal.store.ts`, `manual-order-page.component.ts`) + sus specs; sin cambios en `pos-order-panel.component.ts` (su marcado ya existe y empezará a funcionar al corregir la fuente de datos), pero sí se agrega/ajusta cobertura de test ahí

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Las Nuevas Funcionalidades Nacen de un Spec** — Cumple: `specs/113-presentacion-item-pedido-manual/spec.md` ya existe, aprobado y clarificado antes de este plan.
- **II. El Comportamiento Existente Sigue Protegido** — Cumple: no se cambia ningún comportamiento funcional existente (precio, cálculo, persistencia); solo se agrega texto visible que antes faltaba. No aplica registro en `registro-de-anomalias.md` porque no hay cambio de comportamiento de negocio, solo corrección de un defecto de visualización.
- **III. Characterization Tests** — Cumple: no se toca lógica de cálculo ni flujos protegidos por characterization tests; los specs afectados (`pos-terminal.store.spec.ts`, `manual-order-page.component.spec.ts`, `pos-order-panel.component.spec.ts`) son specs de comportamiento de UI del propio feature de carrito, no characterization tests con el prefijo `"CONGELA comportamiento actual:"`.
- **V. Nuevas Funcionalidades Antes que Refactorizaciones Oportunistas** — Cumple: el alcance se limita a lo exigido por el spec (mostrar la presentación); no se incluyen refactorizaciones no relacionadas del store ni de los componentes.
- **VI. Evolución Incremental** — Cumple: cambio aislado, de alcance acotado, verificable de forma independiente (un solo defecto de visualización).
- **IX. Dependencias Nuevas** — Cumple: no se introduce ninguna dependencia nueva.
- **X. Verificación Obligatoria** — Se cumplirá en la fase de implementación mediante tests unitarios actualizados/añadidos en los tres specs afectados más verificación manual en la terminal de mesas.
- **XIII. Todo en Español de Colombia** — Cumple: este plan, el spec y los artefactos de diseño están en español de Colombia; el código y los nombres de símbolos siguen la convención ya existente del repo (inglés para identificadores, como el resto del código base).

Sin violaciones. No se requiere la tabla de Complexity Tracking.

**Re-chequeo post-diseño (tras Fase 1)**: `research.md` y `data-model.md` confirman que no se agregan entidades, dependencias, contratos ni migraciones — solo se reutilizan tipos y helpers ya existentes (`MenuVariant`, `variantLabel()`, `splitVariantLabel()`). Los gates anteriores siguen cumpliéndose sin cambios.

## Project Structure

### Documentation (this feature)

```text
specs/113-presentacion-item-pedido-manual/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

No se genera `contracts/`: esta funcionalidad no agrega ni modifica ninguna interfaz pública (API REST, evento, contrato CLI). Es un cambio interno de presentación dentro del frontend que consume datos ya disponibles en memoria.

### Source Code (repository root)

El código vive en el repo hermano `../pos-heladeria` (Angular), no en `pos-specs`. Estructura relevante para este cambio:

```text
pos-heladeria/src/app/modules/tables/
├── services/
│   ├── pos-terminal.store.ts        # store de signals; cartView() computed — FIX PRINCIPAL (líneas de borrador)
│   ├── pos-terminal.store.spec.ts   # tests del store — agregar casos para variant en líneas de borrador
│   └── menu-lookup.ts               # variantLabel()/splitVariantLabel() — se reutilizan, sin cambios
├── components/
│   ├── pos-order-panel.component.ts       # panel de orden ya creada; YA tiene el pill vía splitVariantLabel() — sin cambios de marcado, solo se beneficia del fix del store
│   └── pos-order-panel.component.spec.ts  # agregar caso: ítem recién agregado (borrador) muestra el pill
└── pages/
    ├── manual-order-page.component.ts       # panel "Nueva orden"; AGREGAR marcado de presentación (pill), hoy inexistente
    └── manual-order-page.component.spec.ts  # agregar casos para el nuevo marcado
```

**Structure Decision**: Cambio contenido dentro del módulo `tables` del frontend Angular existente; no se crean módulos, servicios ni rutas nuevas. Se reutiliza el helper `splitVariantLabel()` ya existente en `menu-lookup.ts` para mantener un único patrón visual de "pill de presentación" entre `pos-order-panel.component.ts` y `manual-order-page.component.ts`.

## Complexity Tracking

*Sin violaciones de la Constitution Check — tabla no requerida.*
