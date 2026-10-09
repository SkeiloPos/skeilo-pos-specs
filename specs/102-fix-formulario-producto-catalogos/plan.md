# Implementation Plan: Corrección y mejora de rendimiento del formulario de crear/editar producto (receta, tamaños y catálogos)

**Branch**: `102-fix-formulario-producto-catalogos` | **Date**: 2026-10-07 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/102-fix-formulario-producto-catalogos/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Cuatro correcciones acotadas al formulario de crear/editar producto de `pos-heladeria`, sin
cambios de backend (confirmado por investigación directa de los tres catálogos y del endpoint de
insumo por id). **Historia 1**: `InventoryService` gana `resolvedExtraItems`/`resolveMissingItems()`,
que resuelve por id (`GET /items/{id}`, ya existente) cualquier insumo ya referenciado por una
receta o un detalle de opción que no esté en la página de 100 que carga `allItems()`; el
formulario de producto combina ambas fuentes al construir las opciones del selector y el lookup de
unidad, sin tocar `selectedLabel()` del componente compartido. **Historia 2**:
`ProductService.getProductDraft` pasa de un `for...of` secuencial a `Promise.allSettled` sobre
todas las variantes activas, disparando sus peticiones de receta y grupos de opciones en paralelo
entre variantes, con aislamiento de fallos por variante (`loadError` + reintento puntual).
**Historia 3**: `CategoryService`/`PresentationService` ganan `searchActiveCategories()`/
`searchActivePresentations()`, mismo patrón que `InventoryService.searchActiveItems()` (spec 098),
contra `GET /categories`/`GET /presentations` — confirmado que ya soportan `search`/`active`/
paginación igual que `/inventory/items`; sus selectores migran de `<select>` nativo a
`<app-searchable-select>`, reusando el contrato ya definido por la 098 sin tocar el componente
compartido (el selector de insumo ya lo usa desde esa spec). De paso, el selector de categoría
gana el mismo resguardo de una línea que presentación ya tiene para no perder de vista la opción
ya elegida (usa `category_name`, ya presente en el draft). **Historia 4**: cada servicio de
catálogo gana `refreshAllX()`, que invalida únicamente su query "ver todos"; el formulario de
producto arranca, al abrirse, un sondeo de 2 minutos con `startVisibleInterval()`
(`core/realtime/visible-interval.ts`, utilidad ya existente y ya usada por
`public-menu.component.ts` — se pausa sola con la pestaña oculta y refresca de inmediato al
volver), que llama a los tres `refreshAllX()`; se detiene en `ngOnDestroy`. **Nota**: esta
historia se implementó distinto a como la planeó este documento originalmente (ver research.md D5,
Adenda) — no se tocó `injectPagedQuery`/`paged-query.ts` en absoluto.

## Technical Context

**Language/Version**: Frontend: TypeScript ~5.9 (Angular 21). Sin cambios de backend (Python
3.14/FastAPI) — solo se **leen** contratos ya existentes, no se modifican

**Primary Dependencies**: Angular, `@tanstack/angular-query-experimental` (ya usado por las tres
services de catálogo, sin cambios en esta spec), `core/realtime/visible-interval.ts` (utilidad ya
existente, reusada tal cual para Historia 4 — sin dependencias nuevas)

**Storage**: PostgreSQL 16, schema-per-tenant. Sin cambios de esquema ni de datos — esta
corrección es puramente de recuperación/presentación/concurrencia en el cliente

**Testing**: Frontend: Vitest (ya configurado). Se extienden `product-form.component.spec.ts`,
`product.service.spec.ts`, `inventory.service.spec.ts`; se crean `category.service.spec.ts` y
`presentation.service.spec.ts` (no existían)

**Target Platform**: SPA de navegador, panel del tenant (Administrador) — el menú QR público no
se toca, no usa el formulario de producto ni ninguno de los tres selectores afectados

**Project Type**: Aplicación web (backend + frontend en dos repos separados: `pos-backend`,
`pos-heladeria`; este repo, `pos-specs`, solo contiene la documentación). Esta corrección es
**100% frontend** — confirmado por investigación directa: `GET /categories`, `GET /presentations`
y `GET /inventory/items/{id}` ya existen con la forma exacta que se necesita

**Performance Goals**: el tiempo de apertura del formulario de edición no debe escalar
linealmente con el número de tamaños del producto (SC-002); las búsquedas remotas nuevas usan el
mismo tamaño de página (20) y debounce (300ms, ya centralizado en `searchable-select.component.ts`
por la spec 098) que la ya validada para insumos

**Constraints**: el tope `size<=100` y el `ilike` sin `unaccent` de los tres endpoints de catálogo
NO cambian (se heredan, igual que la limitación ya documentada por la spec 098). El refresco en
segundo plano (Historia 4) se acota a las tres queries "ver todos" que alimentan selectores — no
se toca el `defaultOptions` global del `QueryClient` (`app.config.ts`) ni ninguna tabla paginada
administrativa existente

**Scale/Scope**: frontend únicamente. Archivos modificados: `inventory.service.ts`,
`category.service.ts`, `presentation.service.ts`, `product.service.ts`, `product.interface.ts`,
`product-form.component.ts`, y sus `*.spec.ts`. `core/query/paged-query.ts` NO se toca (ver
research.md D5, Adenda). Cero archivos de backend, cero migraciones, cero endpoints nuevos

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Evaluación |
|---|---|
| I. Nace de un spec | ✅ `specs/102-fix-formulario-producto-catalogos/spec.md`, 4 historias de usuario, 15 FR y 5 SC cerrados, sin `NEEDS CLARIFICATION` pendiente |
| II. Comportamiento existente protegido | ✅ El único comportamiento que cambia de forma visible para casos que hoy ya "funcionaban" es el manejo de fallos de red al cargar variantes (de "todo o nada" a aislado por variante) — cambio explícitamente autorizado por FR-007 del spec, no una decisión de negocio nueva sobre qué puede guardarse, así que no aplica entrada en `registro-de-anomalias.md`. Todo lo demás es aditivo/opt-in (D1, D3, D5) o corrige un defecto cosmético que la spec 098 ya dejó documentado como pendiente (D1) |
| III. Characterization tests protegen lo heredado | ✅ Ningún test `"CONGELA comportamiento actual:"` existe sobre el formulario de producto ni sobre los tres servicios de catálogo (confirmar en tasks.md al escribir los tests); de existir alguno, no se toca |
| IV. Los nuevos specs pueden introducir comportamiento nuevo | N/A — esta spec no introduce comportamiento de negocio nuevo, corrige defectos de carga/visualización y mejora la frescura de catálogos ya existentes |
| V. Nueva funcionalidad antes que refactor oportunista | ✅ No se reescribe `searchable-select.component.ts`, `injectPagedQuery`, ni los tres servicios de catálogo más allá de lo necesario (research.md D1-D5, alternativas rechazadas); el único "extra" (D4, resguardo de categoría) está directamente acoplado al mismo archivo y la misma selección que D3 ya modifica, reusando un patrón ya existente en la línea de arriba — no es una refactorización no relacionada |
| VI. Evolución incremental | ✅ Cuatro historias de usuario independientes y priorizadas (P1-P4), cada una con su propio research.md (D1/D2, D3/D4, D5) y alcance acotado; no se mezclan entre sí ni con ninguna otra funcionalidad |
| VII. Compatibilidad con datos históricos | N/A — no se toca ninguna factura, venta ni pedido; insumos, categorías y presentaciones son catálogo, no histórico de facturación |
| VIII. Evolución del modelo de datos | N/A — sin cambios de esquema; `data-model.md` solo documenta estado transitorio de UI (`loadError`, `resolvedExtraItems`) y la forma de dos métodos de servicio nuevos, no entidades persistidas |
| IX. Dependencias nuevas | N/A — no se agrega ninguna dependencia de terceros; `startVisibleInterval` ya existe en el proyecto (`core/realtime/visible-interval.ts`) y ya lo usa otro componente |
| X. Verificación obligatoria | ✅ `quickstart.md` cubre los escenarios de aceptación de las 4 historias; `tasks.md` (siguiente comando) debe incluir tests de: `inventory.service.spec.ts` (`resolveMissingItems`, `refreshAllItems`), `product.service.spec.ts` (`getProductDraft` en paralelo, aislamiento de fallos), `category.service.spec.ts`/`presentation.service.spec.ts` (`searchActiveX`, `refreshAllX`), `product-form.component.spec.ts` (opciones combinadas, resguardo de categoría, retry por variante, sondeo de catálogos) |
| XI. Decisiones de negocio frente a decisiones técnicas | ✅ La única decisión que podría confundirse con una decisión de negocio (D4, extender el resguardo de categoría) está documentada explícitamente en research.md como decisión técnica, no de negocio — no cambia qué categoría puede asociarse a un producto |
| XII. Trazabilidad | ✅ research.md y los contratos referencian los FR/escenarios de spec.md por número; data-model.md referencia research.md por decisión (D1-D5) |
| XIII. Español de Colombia | ✅ Todos los artefactos de esta funcionalidad están en español; los identificadores de código nuevos (`resolveMissingItems`, `searchActiveCategories`, `searchActivePresentations`, `loadError`, `refreshAllCategories`) usan inglés técnico, consistente con el resto del código de ambos repos |
| XIV. Convención de ramas Git | Pendiente al iniciar la implementación: crear `fix/102-product-form-catalogs` en `pos-heladeria` antes de tocar código, conforme a `<tipo>/<numero_spec>-<nombre_spec>` — no aplica a `pos-backend` (sin cambios) |
| XV. Política de commits | Pendiente al iniciar la implementación: commits solo bajo pedido explícito del usuario, atómicos (uno por historia es razonable dado que cada una es independiente), en inglés, sin marca de IA |

**Resultado**: sin violaciones. No se requiere la tabla de Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/102-fix-formulario-producto-catalogos/
├── plan.md                               # This file (/speckit-plan command output)
├── research.md                           # Phase 0 output (/speckit-plan command)
├── data-model.md                         # Phase 1 output (/speckit-plan command)
├── quickstart.md                         # Phase 1 output (/speckit-plan command)
├── contracts/
│   ├── categories-search.md              # Phase 1 output (/speckit-plan command)
│   ├── presentations-search.md           # Phase 1 output (/speckit-plan command)
│   └── inventory-item-by-id.md           # Phase 1 output (/speckit-plan command)
├── checklists/
│   └── requirements.md
└── tasks.md                              # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

Este repo (`pos-specs`) solo contiene la documentación de la funcionalidad. El código vive en
`pos-heladeria` (repo hermano, ya existente) — no se crea ninguna carpeta ni proyecto nuevo, y
`pos-backend` no se toca (los tres catálogos y el endpoint de insumo por id ya existen con la
forma exacta que se necesita):

```text
../pos-heladeria/
├── src/app/modules/inventory/services/
│   ├── inventory.service.ts                 # + resolvedExtraItems, resolveMissingItems() (D1);
│   │                                         #   + refreshAllItems() (D5)
│   └── inventory.service.spec.ts            # + tests de resolveMissingItems()/refreshAllItems()
├── src/app/modules/categories/services/
│   ├── category.service.ts                  # + searchActiveCategories() (D3); + refreshAllCategories() (D5)
│   └── category.service.spec.ts             # nuevo: tests de ambos métodos
├── src/app/modules/presentations/services/
│   ├── presentation.service.ts              # + searchActivePresentations() (D3); + refreshAllPresentations() (D5)
│   └── presentation.service.spec.ts         # nuevo: tests de ambos métodos
├── src/app/modules/products/services/
│   ├── product.service.ts                   # getProductDraft: for secuencial → Promise.allSettled (D2)
│   └── product.service.spec.ts              # + test de carga en paralelo y aislamiento de fallos
├── src/app/modules/products/interfaces/
│   └── product.interface.ts                 # VariantDraft + loadError? (D2); ProductDraft +
│                                             #   category_name? (D4, data-model.md)
└── src/app/modules/products/pages/
    ├── product-form.component.ts            # inventoryOptions()/unitLookup combinan allItems()+
    │                                         #   resolvedExtraItems() (D1); recolecta ids tras
    │                                         #   getProductDraft (D1); selector de categoría →
    │                                         #   app-searchable-select + [search] + resguardo (D3/D4);
    │                                         #   selector de presentación → app-searchable-select +
    │                                         #   [search] (D3); retryVariantLoad() (D2);
    │                                         #   startCatalogPolling()/refreshCatalogs() con
    │                                         #   startVisibleInterval() (D5)
    └── product-form.component.spec.ts       # + tests de las 4 historias
```

`core/query/paged-query.ts` y `core/realtime/visible-interval.ts` **no se tocan**: el primero
porque D5 no terminó necesitándolo (ver research.md, Adenda), el segundo porque ya resuelve lo que
esta spec necesita tal cual está.

**Structure Decision**: Aplicación web con backend y frontend en repos separados (patrón ya
establecido por el resto de `pos-specs`). Esta corrección no introduce ningún módulo, endpoint,
tabla ni pantalla nueva — extiende tres servicios y un componente de página ya existentes, y
reutiliza una utilidad de sondeo ya existente. `pos-backend` no se toca.

## Complexity Tracking

*Sin violaciones de la Constitution Check — tabla no aplica.*
