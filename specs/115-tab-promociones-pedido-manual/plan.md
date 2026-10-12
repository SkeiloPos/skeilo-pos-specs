# Implementation Plan: Pestaña dedicada de Promociones en el catálogo de la orden manual

**Branch**: `115-tab-promociones-pedido-manual` | **Date**: 2026-10-12 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/115-tab-promociones-pedido-manual/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Hoy, en el catálogo de la orden manual (`manual-order-page.component.ts` + `PosTerminalStore`), los productos en promoción aparecen mezclados con el resto del catálogo: la navegación solo ofrece "Todos" y las categorías reales (`showingAllCategories` + `catalogCategoryId`), sin ningún filtro dedicado a promociones. El menú QR (`public-menu.component.ts`) ya resolvió exactamente este mismo problema en la spec `081-tab-promociones-menu-qr`: una pestaña virtual `PROMOTIONS_TAB_ID` que filtra por `hasPromotion(product)`, un `@Input() fromPromotions` en el componente compartido `ProductSelectComponent` que activa el paso forzado de cantidad (`minQty()` = `min_qty` de la regla vigente en vez de `1`), y un `stepQuantity` que el modal emite en `ProductSelection` para que el carrito recuerde ese paso en los controles de +/- de la línea ya agregada. El enfoque técnico es replicar ese mismo mecanismo en el lado de la orden manual, reutilizando el componente compartido sin duplicar su lógica de cantidad: (1) agregar una tercera pestaña "Promociones" a la navegación del catálogo de `manual-order-page.component.ts`, con un computed nuevo en `PosTerminalStore` que filtra por el mismo criterio `hasPromotion`; (2) extraer `hasPromotion()` desde `public-menu.component.ts` (hoy privado ahí) al util ya compartido `promotion-pricing.util.ts`, para que ambos catálogos usen literalmente el mismo criterio en vez de dos copias; (3) rastrear, igual que hace `public-menu.component.ts` con `selectedProductFromPromotions`, desde qué pestaña se abrió el modal de selección (`openConfig`), y pasar ese booleano como `[fromPromotions]` a `<app-product-select>`; (4) agregar un campo `step?: number` a `ProductDraftLine` (análogo al mapa `stepByKey` de `DiningCartService`, pero como campo propio de la línea porque `draftLines` ya son objetos locales), poblado desde `ProductSelection.stepQuantity` en `addDraftFromSelection()`; y (5) hacer que `incDraft()`/`decDraft()` usen ese paso (`x.step ?? 1`) en vez de `±1` fijo. El mismo mecanismo se replica en el segundo punto de entrada de la orden manual, `pos-catalog-drawer.component.ts` (usado por `pos-order-panel.component.ts` para agregar productos a un pedido ya existente, de cualquier tipo — mesa, para llevar o domicilio): reutiliza íntegramente los mismos `computed`/signals ya agregados a `PosTerminalStore` (`catalogProductsPromotionsFiltered`, `configuringProductFromPromotions`, `openConfig(product, fromPromotions)`), solo necesita su propia pestaña de navegación local y su propio binding `[fromPromotions]` — ver `research.md`, Decisión 7. No se modifica el backend, el modelo de datos de promociones, ni el motor de descuentos (confirmado agnóstico al tipo de pedido en `pos-backend/app/api/v1/orders/checkout.py`, `promo_lines_for`/`auto_discount`) — todo el cambio vive en `pos-heladeria` (frontend).

## Technical Context

**Language/Version**: TypeScript ~5.9.2 (Angular 21.1, standalone components, signals)

**Primary Dependencies**: Angular core/common/forms; `ProductSelectComponent` y `promotion-pricing.util.ts` ya existentes (sin cambios en su contrato público salvo la nueva función exportada `hasPromotion`); Tailwind CSS para estilos inline en plantillas

**Storage**: N/A — no hay cambios de persistencia. El paso de cantidad (`step`) vive únicamente en memoria dentro de cada `ProductDraftLine` del signal `draftLines`, igual que hoy vive el `stepByKey` del comensal (nunca se envía al backend; solo `quantity` final via `POST /orders` o `POST /orders/{id}/items`)

**Testing**: Vitest vía `npx ng test` (Angular CLI). Specs existentes relevantes: `pos-terminal.store.spec.ts`, `manual-order-page.component.spec.ts`, `product-select.component.spec.ts`, `public-menu.component.spec.ts` (como referencia de los casos ya cubiertos para el mismo comportamiento del lado QR), `promotion-pricing.util.spec.ts` (si existe, para la función extraída)

**Target Platform**: Web (navegador), terminal de mesas del POS (uso interno de cajeros/meseros)

**Project Type**: Aplicación web de una sola página (Angular) — cambio exclusivamente de frontend

**Performance Goals**: N/A — filtrado en memoria de una lista de catálogo ya cargada (`menuService.categories()`); mismo orden de magnitud que el filtro por categoría o por texto de búsqueda ya existentes

**Constraints**: No modificar el backend ni los contratos de `GET /menu`; no modificar el motor de cálculo de descuentos (`evaluate_variant_sets`, autoritativo en el backend al cobrar); mantener `ProductSelectComponent` como único punto de verdad para el paso de cantidad forzado, sin reimplementar esa lógica en `PosTerminalStore`; preservar el comportamiento actual de "Todos"/categorías/buscador sin el paso forzado (FR-007, FR-008)

**Scale/Scope**: 6 archivos de producción con cambios funcionales (`promotion-pricing.util.ts` — nueva función exportada; `pos-terminal.store.ts` — nuevo computed de filtrado, nuevo estado de "abierto desde Promociones", campo `step` en `ProductDraftLine`, `incDraft`/`decDraft` actualizados; `manual-order-page.component.ts` — nueva pestaña de navegación, estado de pestaña activa, binding `[fromPromotions]`; `pos-catalog-drawer.component.ts` — mismo tratamiento que `manual-order-page.component.ts` (nueva pestaña local, binding `[fromPromotions]`), para que "+ Agregar producto" a un pedido ya existente (mesa/llevar/domicilio) quede cubierto (FR-014); `public-menu.component.ts` — se reemplaza su `hasPromotion()` privado por el import del util compartido, sin cambio de comportamiento) + sus specs

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Las Nuevas Funcionalidades Nacen de un Spec** — Cumple: `specs/115-tab-promociones-pedido-manual/spec.md` existe, aprobado y clarificado antes de este plan.
- **II. El Comportamiento Existente Sigue Protegido** — Cumple: "Todos", las categorías existentes y el buscador conservan el comportamiento de cantidad libre (FR-007/FR-008, confirmado en Clarifications); la pestaña "Promociones" no se autoselecciona por defecto (FR-013), a diferencia del menú QR — decisión de negocio explícita del dueño, documentada en Clarifications, no requiere entrada en `registro-de-anomalias.md` porque no cambia comportamiento de negocio ya existente, solo decide el de uno nuevo. Extraer `hasPromotion()` a un util compartido no cambia su comportamiento en `public-menu.component.ts` (mismo criterio, misma función, solo distinto lugar).
- **III. Characterization Tests** — Cumple: no se toca lógica de cálculo de descuentos ni flujos protegidos por characterization tests; los specs afectados son specs de comportamiento de UI/estado del propio feature de catálogo y carrito, no characterization tests con el prefijo `"CONGELA comportamiento actual:"`.
- **V. Nuevas Funcionalidades Antes que Refactorizaciones Oportunistas** — Cumple: la extracción de `hasPromotion()` a `promotion-pricing.util.ts` no es una refactorización oportunista — es la forma exigida por el propio spec de que "la orden manual siga las mismas reglas que ya aplican en el menú QR" (mismo criterio, un solo lugar, no dos copias que puedan divergir). No se incluye ninguna otra refactorización no relacionada.
- **VI. Evolución Incremental** — Cumple: cambio acotado a una vista de catálogo y su flujo de agregado; no mezcla cambios de arquitectura, migración de datos ni cambios de comportamiento en otras áreas.
- **VII. Compatibilidad con Datos Históricos** — Cumple: no se toca ninguna orden ni factura ya emitida; el campo nuevo `step` es puramente de UI en memoria, nunca se persiste.
- **VIII. Evolución del Modelo de Datos** — Cumple: no hay cambios de modelo de datos de backend. El único campo nuevo (`ProductDraftLine.step?: number`) es un tipo de frontend en memoria, opcional, sin migración ni estrategia de rollback aplicable (se pierde al recargar la página, igual que el resto de `draftLines`).
- **IX. Dependencias Nuevas** — Cumple: no se introduce ninguna dependencia nueva.
- **X. Verificación Obligatoria** — Se cumplirá en la fase de implementación mediante tests unitarios actualizados/añadidos en los archivos listados en *Scale/Scope*, más verificación manual en la terminal de mesas (ver `quickstart.md`).
- **XIII. Todo en Español de Colombia** — Cumple: este plan, el spec y los artefactos de diseño están en español de Colombia; el código y los nombres de símbolos siguen la convención ya existente del repo (inglés para identificadores).

Sin violaciones. No se requiere la tabla de Complexity Tracking.

**Re-chequeo post-diseño (tras Fase 1)**: `research.md` y `data-model.md` confirman que no se agregan entidades de dominio, dependencias, contratos de API ni migraciones — solo se reutilizan el modelo de promociones ya existente (`MenuVariantPromotion`, `min_qty`) y el componente/mecanismo ya implementado en la spec 081 (`ProductSelectComponent.fromPromotions`/`stepQuantity`). Los gates anteriores siguen cumpliéndose sin cambios.

## Project Structure

### Documentation (this feature)

```text
specs/115-tab-promociones-pedido-manual/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

No se genera `contracts/`: esta funcionalidad no agrega ni modifica ninguna interfaz pública (API REST, evento). Reutiliza el endpoint `GET /menu` y el modelo de promociones ya existentes sin cambios de contrato; es un cambio interno de filtrado y estado de UI dentro del frontend.

### Source Code (repository root)

El código vive en el repo hermano `../pos-heladeria` (Angular), no en `pos-specs`. Estructura relevante para este cambio:

```text
pos-heladeria/src/app/modules/
├── promotions/services/
│   ├── promotion-pricing.util.ts         # AGREGAR hasPromotion(product) exportado (extraído de public-menu)
│   └── promotion-pricing.util.spec.ts    # agregar casos para hasPromotion()
└── tables/
    ├── services/
    │   ├── pos-terminal.store.ts         # AGREGAR computed catalogProductsPromotionsFiltered,
    │   │                                   estado "abierto desde Promociones", campo `step` en
    │   │                                   ProductDraftLine, incDraft()/decDraft() con paso
    │   └── pos-terminal.store.spec.ts    # agregar casos para el filtro y el paso de cantidad
    ├── components/
    │   └── product-select.component.ts   # SIN CAMBIOS — ya implementa fromPromotions/stepQuantity
    │                                       (spec 081); solo se consume desde el lado manual
    └── pages/
        ├── manual-order-page.component.ts       # AGREGAR pestaña "Promociones", estado de
        │                                           pestaña activa, binding [fromPromotions]
        ├── manual-order-page.component.spec.ts  # agregar casos para la nueva pestaña y el paso
        └── public-menu.component.ts              # REEMPLAZAR hasPromotion() privado por el
                                                     import del util compartido (sin cambio de
                                                     comportamiento visible)
```

```text
pos-heladeria/src/app/modules/tables/components/
├── pos-catalog-drawer.component.ts        # AGREGAR pestaña "Promociones" (sin "Todos", solo
│                                             categorías + esta nueva), estado de pestaña activa,
│                                             binding [fromPromotions] — mismo tratamiento que
│                                             manual-order-page.component.ts, para que "+ Agregar
│                                             producto" a un pedido ya existente quede cubierto
│                                             (FR-014)
└── pos-catalog-drawer.component.spec.ts   # agregar casos análogos a manual-order-page
```

**Structure Decision**: Cambio contenido dentro del módulo `tables` del frontend Angular existente, con una sola función movida al módulo `promotions` ya compartido entre ambos catálogos. No se crean módulos, servicios, rutas ni componentes nuevos — se reutiliza íntegramente `ProductSelectComponent`, que ya implementa el mecanismo de paso de cantidad forzado desde la spec 081.

## Complexity Tracking

*Sin violaciones de la Constitution Check — tabla no requerida.*
