# Implementation Plan: Quitar la precarga de catálogos completos en los selectores del formulario de producto (categoría, insumos, presentación)

**Branch**: `105-selectores-producto-sin-precarga` | **Date**: 2026-10-08 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/105-selectores-producto-sin-precarga/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Quitar, del formulario de crear/editar producto (`pos-heladeria`), las tres peticiones que hoy
precargan hasta 100 registros activos de categorías, insumos y presentaciones al abrirlo
(`GET /categories?size=100`, `GET /items?size=100`, `GET /presentations?size=100`). El nombre del
valor ya seleccionado de cada selector se sigue resolviendo con la información que ya trae el
detalle del producto (spec 103) o, para insumos, con el mecanismo de resolución puntual por id ya
introducido por la spec 102. La búsqueda remota de cada selector (spec 102) no cambia. El hallazgo
técnico central de esta investigación (ver `research.md`, Decisión D1) es que, hoy, el **nombre de
un valor recién elegido por búsqueda** (no uno ya guardado) también depende de la lista precargada
para resolverse — al quitarla, ese caso deja de ser una excepción rara (solo ocurría fuera de la
página 100) y pasa a ser el caso normal de cada selección, así que el plan debe resolverlo como
parte de este mismo cambio, no como un efecto secundario aceptable.

## Technical Context

**Language/Version**: TypeScript 5.9 (Angular 21, standalone components, signals) — frontend
`pos-heladeria`. No requiere cambios en `pos-backend` (Python/FastAPI): `GET /products/{id}` ya
expone `category_id`/`category_name` (spec 097) y `presentation_id`/`presentation_name` por
variante (spec 103); `GET /categories`, `GET /items`, `GET /presentations` y sus variantes
`search=` (spec 098/102) ya existen y no cambian.

**Primary Dependencies**: Angular 21 (`@angular/core`, formularios reactivos vía
`ControlValueAccessor`), `@tanstack/angular-query-experimental` (`injectPagedQuery`, ya usado por
los tres servicios de catálogo). Ninguna dependencia nueva (Principio IX): esta corrección solo
deja de invocar código ya existente y reutiliza mecanismos ya existentes (ver Decisión D1).

**Storage**: N/A (sin cambios de esquema ni de backend).

**Testing**: Vitest (`ng test`, ya configurado en `pos-heladeria`) para los tests de componente de
`ProductFormComponent` y del picker compartido `app-searchable-select`.

**Target Platform**: Navegador web (panel de administración de `pos-heladeria`).

**Project Type**: Web application — repositorio `frontend` (`pos-heladeria`) dentro del monorepo
de specs multi-repo descrito por la Constitución. Esta corrección toca exclusivamente
`pos-heladeria`; `pos-backend` no requiere cambios.

**Performance Goals**: Abrir el formulario de crear/editar producto deja de disparar 3 peticiones
de red (SC-001/SC-004 del spec). Ninguna selección nueva hecha por búsqueda debe introducir una
petición de red adicional evitable para mostrar su nombre (ver Decisión D1: se reutiliza el
resultado de búsqueda ya recibido, sin una llamada extra de resolución por id).

**Constraints**: No debe cambiar el comportamiento de ninguna otra pantalla que reutilice los
mismos servicios compartidos (`CategoryService`, `InventoryService`, `PresentationService`,
`providedIn: 'root'`) — Categorías, Presentaciones, Inventario, Compras, Grupos de opciones,
Promociones (FR-008). No debe cambiar el contrato de guardado del producto (FR-009).

**Scale/Scope**: Un único componente de página (`ProductFormComponent`) y, potencialmente, el
componente compartido `app-searchable-select` (usado por otras pantallas además de ésta — ver
Decisión D1 sobre compatibilidad). Sin cambios de backend ni de modelo de datos.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principio I (nace de un spec)**: ✅ cumple — spec 105 aprobada (`spec.md`), checklist de
  calidad en verde, sin `[NEEDS CLARIFICATION]` pendientes.
- **Principio II (comportamiento existente protegido)**: ⚠️ riesgo identificado y resuelto en este
  plan, no en `registro-de-anomalias.md` — no es una decisión de negocio nueva, es un efecto
  colateral técnico de la Causa Raíz ya autorizada por el spec. `hasFreePresentations()`
  (`product-form.component.ts:654-657`, fuera del alcance textual del spec 105 pero dependiente de
  `presentationService.allPresentations()`, la misma señal que FR-002 obliga a dejar de precargar)
  quedaría siempre en `false` si no se atiende — ver Decisión D2 de `research.md`. Se resuelve
  dentro de esta misma spec, sin tocar ninguna regla de negocio: solo cambia de qué fuente de datos
  se calcula un valor booleano ya existente.
- **Principio V (sin refactorizaciones oportunistas)**: ✅ — el cambio al contrato de
  `app-searchable-select` (Decisión D1) es el mínimo necesario para que FR-003/FR-005 sigan
  cumpliéndose sin precarga; no se toca ningún otro comportamiento del componente compartido.
- **Principio VI (evolución incremental)**: ✅ — una sola unidad de cambio (frontend,
  `pos-heladeria`), sin tocar `pos-backend`, sin migración de datos.
- **Principio IX (dependencias nuevas)**: ✅ — no se agrega ninguna dependencia nueva.
- **Principio XIV (rama Git)**: pendiente de aplicar al iniciar la implementación en
  `pos-heladeria`: `fix/105-selectores-producto-sin-precarga` (tipo `fix` porque corrige un
  defecto de rendimiento ya reportado, igual que la spec 102 usó `fix/102-...`).

Sin violaciones que requieran `Complexity Tracking`.

**Re-chequeo post Fase 1 (tras `research.md`, `data-model.md`, `contracts/`, `quickstart.md`)**:
sin cambios de postura. La Decisión D1 (`contracts/searchable-select-contract.md`) confirma que la
extensión del componente compartido es aditiva (no rompe el Principio V ni a otros consumidores) y
la Decisión D2 (`research.md`) confirma que `hasFreePresentations` se resuelve reutilizando un
endpoint de búsqueda ya vigente, no uno nuevo (Principio IX). Ningún artefacto de diseño introdujo
un riesgo adicional a los dos ya identificados antes de la Fase 1. Gate: **PASA**.

## Project Structure

### Documentation (this feature)

```text
specs/105-selectores-producto-sin-precarga/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

Repositorio afectado: `../pos-heladeria` (frontend Angular, sibling repo de este repo de specs).
`../pos-backend` no requiere cambios — ver Technical Context.

```text
pos-heladeria/
└── src/app/
    ├── modules/
    │   ├── products/
    │   │   ├── pages/
    │   │   │   └── product-form.component.ts        # ngOnInit: quitar 3 llamadas de precarga;
    │   │   │                                         # categoryOptions/inventoryOptions/
    │   │   │                                         # presentationOptionsFor/
    │   │   │                                         # hasFreePresentations: nueva fuente de datos
    │   │   └── services/
    │   │       └── product.service.ts                # sin cambios (ya expone category_name/
    │   │                                               # presentation_name por spec 097/103)
    │   ├── categories/services/category.service.ts    # sin cambios al servicio; solo deja de
    │   │                                               # recibir la llamada loadAllCategories()
    │   │                                               # desde product-form
    │   ├── presentations/services/presentation.service.ts  # idem (loadAllPresentations())
    │   └── inventory/services/
    │       ├── inventory.service.ts                   # resolveMissingItems()/resolvedExtraItems
    │       │                                           # pasan a ser el único camino, no el respaldo
    │       └── unit-lookup.ts                          # sin cambios
    └── shared/searchable-select/
        └── searchable-select.component.ts              # nuevo output opcional (Decisión D1),
                                                          # aditivo — no rompe otros consumidores
```

**Structure Decision**: cambio acotado a `pos-heladeria` (frontend), dentro de los módulos
`products` (consumidor principal) e `inventory` (reutiliza su mecanismo existente de resolución
por id). El componente compartido `src/app/shared/searchable-select/` recibe una extensión aditiva
de su contrato público (ver `research.md`, Decisión D1) consumida únicamente por
`product-form.component.ts`; sus demás consumidores (listados en `research.md`, sección "Otros
consumidores") siguen usando el `ControlValueAccessor` existente sin cambios. No se crean
directorios nuevos.

## Complexity Tracking

> No hay violaciones de la Constitución que requieran justificación. El único riesgo detectado
> (`hasFreePresentations`, Principio II) se resuelve dentro del alcance ya aprobado del spec, sin
> necesitar una excepción ni una entrada en `registro-de-anomalias.md` — ver Constitution Check y
> `research.md` Decisión D2.
