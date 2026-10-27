# Implementation Plan: Vista dedicada para registrar una compra

**Branch**: `feat/140-vista-nueva-compra` | **Date**: 2026-10-26 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/140-vista-nueva-compra/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Reemplazar el modal actual de "Nueva compra" (`purchase-form.component.ts`, abierto como overlay desde `inventory-page.component.ts`) por una vista enrutada propia dentro del módulo de Inventario (Angular, `pos-heladeria`), reproduciendo el mockup `design/SkeiloPOS App - Nueva compra.dc.html`. La vista reutiliza en su totalidad los endpoints y servicios ya existentes (`InventoryService.searchActiveItems/createPurchase/createPurchaseOrder`, `SuppliersService`, `SupplierItemsService`) sin duplicar lógica de negocio. El único cambio de backend necesario es acomodar la acción nueva "Guardar borrador" (FR-011/FR-013/FR-017): el estado `draft` de `Purchase` ya existe pero hoy representa únicamente "orden pendiente validada" (RF-022); se añade un indicador adicional para distinguir una captura incompleta ("borrador") de una orden de compra validada, sin introducir un estado nuevo ni duplicar el mecanismo de "sin alta de stock" (Principio VIII, Principio VI).

## Technical Context

**Language/Version**: Backend: Python 3.11 (FastAPI). Frontend: TypeScript 5.x (Angular 18+, standalone components, signals)

**Primary Dependencies**: Backend: FastAPI, SQLAlchemy, Alembic, `fastapi-pagination`. Frontend: Angular Router, Angular Forms (reactive), señales (`signal`/`computed`), sin librerías nuevas

**Storage**: PostgreSQL 16, schema-per-tenant (tabla `purchases` / `purchase_items` existentes en `pos-backend/app/models/purchase.py`)

**Testing**: Backend: scripts de verificación manual en `app/scripts/` (no hay suite pytest dedicada para compras; confirmar con el usuario el mecanismo de verificación antes de implementar — ver `research.md` D4). Frontend: Vitest vía `@angular/build:unit-test` (`ng test` / `npm test`), specs existentes en `purchase-form.component.spec.ts` e `inventory-page.component.spec.ts` como base de characterization

**Target Platform**: Web (navegador de escritorio, con adaptaciones responsive ya presentes en el mockup para pantallas intermedias/móviles)

**Project Type**: Web application (backend `pos-backend` + frontend `pos-heladeria`, repos independientes)

**Performance Goals**: Ninguno nuevo; conservar la experiencia actual del modal (búsqueda de insumos con debounce ya implementado, SC-001: completar y registrar 5 insumos en <2 min)

**Constraints**: No modificar el contrato de los endpoints de recepción/anulación existentes; `is_incomplete_draft` (o campo equivalente) debe tener `default=false` para no alterar el significado de los borradores (órdenes pendientes) ya persistidos (Principio VII/VIII); la vista nueva vive bajo las mismas guardias de ruta (`roleGuard([UserRole.ADMIN])`, `planModuleGuard('inventario')`) que el resto de Inventario

**Scale/Scope**: 1 vista nueva enrutada (`inventario/compras/nueva`), 1 ruta nueva en `dashboard/routes.ts`, reutilización completa de 3 servicios de frontend y 2 endpoints de backend existentes (`POST /purchases`, `POST /purchases/order`), 1 extensión aditiva de backend (parámetro + columna) para soportar "Guardar borrador"

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principio I (Spec primero)**: ✅ Esta planificación parte de `specs/140-vista-nueva-compra/spec.md`, ya aprobado.
- **Principio II (Comportamiento existente protegido)**: ✅ Se reutilizan los mecanismos existentes de compra recibida y orden pendiente sin alterar su contrato ni su significado (FR-014). El único cambio de comportamiento es aditivo (nueva acción "Guardar borrador"), no modifica lo existente.
- **Principio III (Characterization tests)**: ⚠️ Pendiente de verificar en Phase 0 si existen characterization tests (`"CONGELA comportamiento actual:"`) sobre el modal de compra o los endpoints de compra; si existen, deben seguir pasando sin modificación.
- **Principio IV**: ✅ El spec autoriza explícitamente la nueva funcionalidad (vista dedicada + acción "Guardar borrador").
- **Principio V (Sin refactors oportunistas)**: ✅ Alcance limitado a migrar el modal a vista + la extensión mínima de borrador; no se incluyen refactors no relacionados del módulo de Inventario.
- **Principio VI (Evolución incremental)**: ✅ Cambio de frontend (vista/ruta) y cambio de backend (columna + parámetro) se mantienen como unidades separadas y verificables; no se mezcla con otras features.
- **Principio VII (Datos históricos inmutables)**: ✅ No se recalculan compras ya recibidas; el nuevo campo es aditivo con default que preserva el significado de registros existentes.
- **Principio VIII (Evolución del modelo de datos)**: ✅ Ver `data-model.md` para la especificación completa de la columna nueva, su default, compatibilidad y rollback.
- **Principio IX (Dependencias nuevas)**: ✅ No se introduce ninguna dependencia nueva.
- **Principio X (Verificación obligatoria)**: ⚠️ Pendiente confirmar en Phase 0 cómo se ejecutan tests de backend (no se halló suite pytest dedicada a compras); se documenta en `research.md`.
- **Principio XIV/XV (Ramas y commits)**: Se trabajará sobre una rama `feat/140-vista-nueva-compra` creada antes de tocar código; los commits se seccionan y solo se ejecutan si el usuario lo pide explícitamente.

No hay violaciones que requieran `Complexity Tracking`.

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

```text
# [REMOVE IF UNUSED] Option 1: Single project (DEFAULT)
src/
├── models/
├── services/
├── cli/
└── lib/

../pos-backend/
├── app/
│   ├── models/purchase.py          # Purchase, PurchaseItem (extender: columna nueva)
│   ├── api/v1/inventory/router.py  # POST /purchases, /purchases/order (extender validación)
│   ├── schemas/                    # PurchaseCreate / PurchaseOrderCreate (nuevo campo opcional)
│   └── services/                   # create_purchase_order (parámetro allow_incomplete)
└── alembic/versions/               # nueva migración aditiva (columna + default)

../pos-heladeria/
└── src/app/modules/
    ├── inventory/
    │   ├── pages/
    │   │   └── purchase-view.component.ts   # NUEVA vista enrutada (reemplaza el modal)
    │   ├── components/
    │   │   └── purchase-form.component.ts   # Lógica/plantilla migrada a la página nueva
    │   ├── services/
    │   │   ├── inventory.service.ts         # searchActiveItems/createPurchase/createPurchaseOrder (reutilizados)
    │   │   ├── suppliers.service.ts         # reutilizado
    │   │   └── supplier-items.service.ts    # reutilizado
    │   └── interfaces/inventory.interface.ts
    └── dashboard/
        └── routes.ts                         # + ruta inventario/compras/nueva
```

**Structure Decision**: Web application con dos repos existentes (Opción 2 del template,
adaptada a la estructura real): cambios de frontend en `pos-heladeria/src/app/modules/inventory`
(nueva página enrutada bajo `dashboard/routes.ts`) y un cambio aditivo mínimo de backend en
`pos-backend/app/{models,schemas,services,api}` para soportar "Guardar borrador". No se crean
nuevos proyectos ni carpetas de nivel superior.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

Sin violaciones. No aplica.
