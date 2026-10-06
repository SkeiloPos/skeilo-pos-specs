# Implementation Plan: Corrección — los selectores de insumo (receta, opciones, compras, movimientos de inventario) no encuentran insumos existentes fuera de los primeros 100

**Branch**: `098-selector-insumos-receta` | **Date**: 2026-10-06 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/098-selector-insumos-receta/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

El selector genérico `app-searchable-select` (`pos-heladeria`) ganará un modo de búsqueda remota
**opt-in**: un nuevo `@Input() search?: (query: string) => Promise<SearchableSelectOption[]>` que,
cuando se provee y el usuario escribe un texto no vacío, reemplaza el filtrado local por resultados
server-side (con debounce de 300ms y manejo de carga/error ya centralizados en el propio
componente), dejando intacto el filtrado local por defecto para sus consumidores que no son de
insumo. `InventoryService` gana un método nuevo, `searchActiveItems(query)`, que reutiliza la
misma función privada (`fetchItemsPage`) que ya usa Inventario → Insumos, fijando
`active=true`/`page=1`/`size=20`. Los cuatro puntos afectados (receta, opciones, compras,
movimientos) pasan su `[search]="..."` a este nuevo método; ninguno deja de usar
`allItems()`/`loadAllItems()` para lo que ya usaban aparte (resolver nombre/unidad de un insumo ya
seleccionado) — eso queda fuera de alcance (spec FR-009). Sin cambios de backend: el endpoint
`GET /inventory/items` ya soporta `search`/`active`/paginación (research.md D1).

## Technical Context

**Language/Version**: Frontend: TypeScript ~5.9 (Angular 21). Sin cambios de backend (Python
3.14/FastAPI) — solo se **lee** su contrato ya existente, no se modifica

**Primary Dependencies**: Angular, RxJS, `@tanstack/angular-query-experimental` (ya usado por
`InventoryService` para `itemsQuery`/`allItemsQuery` — sin dependencias nuevas)

**Storage**: PostgreSQL 16, schema-per-tenant. Sin cambios de esquema ni de datos — esta
corrección es puramente de recuperación/presentación en el cliente

**Testing**: Frontend: Vitest (ya configurado; `searchable-select.component.spec.ts`,
`inventory.service.spec.ts`, `product-form.component.spec.ts`,
`option-form.component.spec.ts`, `purchase-form.component.spec.ts` ya existen y se extienden)

**Target Platform**: SPA de navegador, panel del tenant (Administrador) — el menú QR público no
se toca, no usa ninguno de los cuatro selectores afectados

**Project Type**: Aplicación web (backend + frontend en dos repos separados: `pos-backend`,
`pos-heladeria`; este repo, `pos-specs`, solo contiene la documentación). Esta corrección es
**100% frontend**

**Performance Goals**: Ninguno nuevo. Mismo patrón de debounce (300ms) y mismo endpoint/parámetros
que ya usa Inventario → Insumos hoy; no se agrega ninguna petición adicional por tecleo más allá
de la que ya dispara esa pantalla para su propia tabla

**Constraints**: `GET /inventory/items` (incluido su tope `size<=100`, su filtro `search` con
`ilike` sin normalización de tildes) NO cambia — se reutiliza tal cual (research.md D1). El
componente `app-searchable-select` y sus consumidores que no son de insumo (p. ej. selector de
mesa en `manual-order-page.component.ts`) NO deben cambiar de comportamiento (spec FR-007)

**Scale/Scope**: Cinco archivos de frontend modificados (`searchable-select.component.ts`,
`inventory.service.ts`, y los cuatro puntos de consumo); cero archivos de backend; cero
migraciones; cero endpoints nuevos

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Evaluación |
|---|---|
| I. Nace de un spec | ✅ `specs/098-selector-insumos-receta/spec.md`, 2 historias de usuario, 9 FR y 4 SC cerrados, sin `NEEDS CLARIFICATION` pendiente (la única duda se resolvió en `/speckit-clarify`, ver `## Clarifications`) |
| II. Comportamiento existente protegido | ✅ El único comportamiento que cambia (cómo cada selector de insumo encuentra un insumo) es el defecto mismo que esta spec corrige, documentado como tal en "Autorización de negocio"/"Alcance ampliado" del spec — no es una decisión de negocio nueva, así que no aplica entrada en `registro-de-anomalias.md`. El filtrado local por defecto del componente compartido y todo lo que no sea insumo (selector de mesa) queda explícitamente sin tocar (FR-007); la resolución de nombre/unidad para filas ya guardadas tampoco cambia (FR-009) |
| III. Characterization tests protegen lo heredado | ✅ Ningún test `"CONGELA comportamiento actual:"` se toca; research.md D2 verifica que el modo remoto es opt-in (`search` no provisto = comportamiento idéntico de hoy) |
| IV. Los nuevos specs pueden introducir comportamiento nuevo | N/A — esta spec no introduce comportamiento de negocio nuevo, corrige uno existente para que cumpla lo que ya se pretendía (spec, "Naturaleza de esta spec") |
| V. Nueva funcionalidad antes que refactor oportunista | ✅ No se reescribe `searchable-select.component.ts` ni `InventoryService` más allá de lo necesario (research.md D2/D3, alternativas rechazadas); no se toca la resolución de nombre/unidad de filas ya guardadas (FR-009), que es un defecto distinto fuera de alcance |
| VI. Evolución incremental | ✅ Dos historias de usuario independientes (receta P1 ya reportada; opciones/compras/movimientos P2, misma causa raíz); el alcance de cada una está acotado y no se mezcla con ninguna otra funcionalidad |
| VII. Compatibilidad con datos históricos | N/A — no se toca ninguna factura, venta ni pedido; los insumos y sus asociaciones son catálogo/inventario, no histórico de facturación |
| VIII. Evolución del modelo de datos | N/A — sin cambios de esquema; `data-model.md` solo documenta el nuevo estado transitorio de UI (texto de búsqueda, resultados, carga, error), no entidades persistidas |
| IX. Dependencias nuevas | N/A — no se agrega ninguna dependencia de terceros |
| X. Verificación obligatoria | ✅ `quickstart.md` cubre los 9 escenarios de aceptación de ambas historias; `tasks.md` (siguiente comando) debe incluir tests de `searchable-select.component.spec.ts` (modo remoto: debounce, error, reintentar) y de cada uno de los 4 consumidores (insumo fuera de los primeros 100 encontrado vía `search`) |
| XI. Decisiones de negocio frente a decisiones técnicas | ✅ La única decisión de negocio nueva (ampliar el alcance a los otros tres selectores) está documentada en el spec ("Alcance ampliado"), no enterrada en el código; las decisiones de este plan son todas técnicas (research.md D1-D5) |
| XII. Trazabilidad | ✅ research.md y los contratos referencian los FR/escenarios de spec.md por número; el spec documenta explícitamente cuándo y por qué se amplió el alcance |
| XIII. Español de Colombia | ✅ Todos los artefactos de esta funcionalidad están en español; los identificadores de código nuevos (`searchActiveItems`, `search`, `SearchableSelectOption`) usan inglés técnico, consistente con el resto del código de ambos repos |
| XIV. Convención de ramas Git | Pendiente al iniciar la implementación: crear `fix/098-inventory-item-picker-search` (o equivalente) en `pos-heladeria` antes de tocar código, conforme a `<tipo>/<numero_spec>-<nombre_spec>` — no aplica a `pos-backend` (sin cambios) |
| XV. Política de commits | Pendiente al iniciar la implementación: commits solo bajo pedido explícito del usuario, atómicos, en inglés, sin marca de IA |

**Resultado**: sin violaciones. No se requiere la tabla de Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/098-selector-insumos-receta/
├── plan.md                            # This file (/speckit-plan command output)
├── research.md                        # Phase 0 output (/speckit-plan command)
├── data-model.md                      # Phase 1 output (/speckit-plan command)
├── quickstart.md                      # Phase 1 output (/speckit-plan command)
├── contracts/
│   ├── inventory-items-search.md      # Phase 1 output (/speckit-plan command)
│   └── searchable-select-component.md # Phase 1 output (/speckit-plan command)
├── checklists/
│   └── requirements.md
└── tasks.md                           # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

Este repo (`pos-specs`) solo contiene la documentación de la funcionalidad. El código vive en
`pos-heladeria` (repo hermano, ya existente) — no se crea ninguna carpeta ni proyecto nuevo, y
`pos-backend` no se toca:

```text
../pos-heladeria/
├── src/app/shared/searchable-select/
│   ├── searchable-select.component.ts       # + modo remoto opt-in (D2/D3): @Input() search,
│   │                                         #   debounce interno, estados loading/error,
│   │                                         #   filteredOptions() delega al modo remoto cuando
│   │                                         #   hay texto y se proveyó `search`
│   └── searchable-select.component.spec.ts  # + tests del modo remoto
├── src/app/modules/inventory/services/
│   ├── inventory.service.ts                 # + searchActiveItems(query) (D1): reutiliza
│   │                                         #   fetchItemsPage() ya existente, active=true fijo
│   └── inventory.service.spec.ts            # + test de searchActiveItems()
├── src/app/modules/products/pages/
│   ├── product-form.component.ts            # [search] del picker de "Insumos fijos" →
│   │                                         #   searchActiveItems (Historia 1)
│   └── product-form.component.spec.ts       # + test: insumo fuera de los primeros 100
├── src/app/modules/option-groups/components/
│   ├── option-form.component.ts             # [search] del picker de insumo de la opción →
│   │                                         #   searchActiveItems (Historia 2)
│   └── option-form.component.spec.ts        # + test: insumo fuera de los primeros 100
├── src/app/modules/inventory/components/
│   ├── purchase-form.component.ts           # [search] del picker de insumo de cada línea →
│   │                                         #   searchActiveItems (Historia 2)
│   └── purchase-form.component.spec.ts      # + test: insumo fuera de los primeros 100
└── src/app/modules/inventory/pages/
    ├── inventory-page.component.ts          # [search] del picker del tab "Movimientos" →
    │                                        #   searchActiveItems (Historia 2)
    └── inventory-page.component.spec.ts     # + test: insumo fuera de los primeros 100
```

**Structure Decision**: Aplicación web con backend y frontend en repos separados (patrón ya
establecido por el resto de `pos-specs`). Esta corrección no introduce ningún módulo, endpoint,
tabla ni pantalla nueva — extiende un componente compartido y un servicio ya existentes con un
modo opt-in, y actualiza cuatro puntos de consumo para usarlo. `pos-backend` no se toca.

## Complexity Tracking

*Sin violaciones de la Constitution Check — tabla no aplica.*
