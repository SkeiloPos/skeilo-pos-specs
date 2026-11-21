# Implementation Plan: Registro Automático de Inventario al Generar Compra Sugerida

**Branch**: `feat/163-compra-sugerida-registro-inventario` | **Date**: 2026-11-21 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/163-compra-sugerida-registro-inventario/spec.md`

## Summary

Cambia el resultado de `POST /inventory/purchases/suggested/generate` (spec 158): cada
`Purchase` generada desde la pantalla de compra sugerida nace directamente en estado
`received` en lugar de `draft`, con sus `PurchaseItem` ya marcados como recibidos por
completo y con el stock del insumo y su movimiento de inventario de entrada aplicados en la
misma transacción que crea la orden — sin esperar un paso manual posterior de recepción. La
creación manual de órdenes (`POST /inventory/purchases/order`, `/items/{id}/receive`, "Nueva
compra") no cambia. Se reutiliza exactamente la lógica que ya existe para dar alta de stock al
recibir/crear una compra (`record_movement`, actualización de `InventoryItem.unit_cost`) y para
anular una compra con stock dado de alta (`void_purchase`) — ningún movimiento nuevo de
inventario, ninguna conversión de unidades nueva. El único cambio de comportamiento vive dentro
de `generate_suggested_purchases()`/`_build_purchase_order()` en `pos-backend`; en
`pos-heladeria`, la pantalla invalida su listado tras generar con éxito (FR-011a) para que los
insumos repuestos desaparezcan de "bajo mínimo" sin recarga manual, y su confirmación muestra
el estado "recibida" de cada orden creada (FR-010).

## Technical Context

**Language/Version**: Python 3.14 (backend, FastAPI 0.136), TypeScript/Angular 21 (frontend, standalone components + signals)

**Primary Dependencies**: FastAPI, SQLAlchemy 2.0, Pydantic 2, Alembic (backend, sin dependencias nuevas); Angular 21, `@tanstack/angular-query-experimental` (`injectPagedQuery`/`QueryClient.invalidateQueries`, ya usado en `presentations/services/presentation.service.ts`) (frontend, sin dependencias nuevas)

**Storage**: PostgreSQL 16, schema-per-tenant (schema `tenant`), vía SQLAlchemy ORM — sin tablas ni columnas nuevas (ver data-model.md)

**Testing**: scripts de prueba ejecutables vía `python -m app.scripts.<name>` (mismo patrón que `app/scripts/test_suggested_purchases.py`, sin pytest en este repo); `ng test` (Vitest) en `pos-heladeria` para el componente/servicio afectados

**Target Platform**: Servidor Linux (API) + SPA Angular servida al navegador

**Project Type**: Web application (backend + frontend, dos repos hermanos) — extensión de una funcionalidad existente (spec 158), no una pantalla nueva

**Performance Goals**: generar hasta 20 insumos / 5 proveedores con recepción automática en la misma transacción, sin exceder el presupuesto ya aceptado en spec 158 (<2s de proceso en servidor, SC-002 de ese spec sigue vigente; SC-002 de este spec exige que el stock ya refleje la generación en <1 min, cota de UX con amplio margen sobre lo anterior)

**Constraints**: toda la generación (creación de N órdenes + N movimientos de inventario + N aumentos de stock) sigue corriendo en una única transacción de base de datos todo-o-nada (FR-004, extiende la constraint ya existente de spec 158 FR-009); la misma `idempotency_key` no debe duplicar movimientos ni stock en un reintento (FR-006); la creación manual de órdenes fuera de esta pantalla no cambia su comportamiento (FR-011)

**Scale/Scope**: cambio acotado a una función de servicio (`generate_suggested_purchases`/`_build_purchase_order` en `pos-backend/app/api/v1/inventory/service.py`) + un ajuste de invalidación de caché y de etiqueta de estado en la pantalla ya existente (`pos-heladeria`); cero tablas nuevas, cero endpoints nuevos

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principio I (nace de un spec)**: ✅ `specs/163-compra-sugerida-registro-inventario/spec.md` existe, está clarificado (2026-11-21) y aprobado.
- **Principio II (comportamiento existente protegido)**: ✅ FR-011 fija explícitamente que la creación manual de órdenes (`create_purchase_order`/`update_purchase_order`, fuera de la pantalla de compra sugerida) sigue en `draft` sin cambios; el cambio de comportamiento (órdenes de compra sugerida nacen `received` en vez de `draft`) está documentado en este mismo spec como decisión de negocio explícita (ver Clarifications del spec y Assumptions), que es la autorización que exige este principio — reemplaza, solo para ese flujo, la regla fijada por spec 158. No se requiere entrada adicional en `registro-de-anomalias.md` porque la decisión ya queda registrada con quién (usuario, vía sesión de clarificación) y cuándo (2026-11-21) directamente en el spec de la funcionalidad que la introduce, igual que hace spec 158 con sus propias decisiones.
- **Principio III (characterization tests)**: ✅ no existe ningún test `"CONGELA comportamiento actual:"` sobre `generate_suggested_purchases` (la funcionalidad spec 158 es reciente y sus pruebas son scripts de funcionalidad, no characterization); los tests de `create_purchase`/`create_purchase_order`/`receive_purchase`/`void_purchase` no se tocan, porque esos caminos no cambian.
- **Principio IV (nuevos specs introducen comportamiento nuevo)**: ✅ exactamente el caso — este spec redefine, de forma acotada y aprobada, qué estado nace una `Purchase` cuando se genera desde compra sugerida.
- **Principio V (sin refactors oportunistas)**: ⚠️ ver Complexity Tracking — se extiende `_build_purchase_order` con un parámetro nuevo (`receive_immediately`); es la extensión mínima necesaria para la funcionalidad, no una limpieza cosmética, documentada igual que spec 158 extendió la misma función con `update_supplier_cost`.
- **Principio VI (evolución incremental)**: ✅ un solo spec, una sola función de servicio modificada, sin mezclar con cambios de arquitectura ni migraciones de datos (no hay migración en este spec).
- **Principio VII (datos históricos)**: ✅ no se toca ninguna `Purchase` ya existente (ni las que ya están en `draft` de antes de este cambio, por Assumptions del spec) ni ninguna factura; el cambio solo aplica hacia adelante a órdenes nuevas.
- **Principio VIII (evolución del modelo de datos)**: ✅ N/A — no hay cambios de esquema; ver data-model.md ("Sin migración").
- **Principio IX (dependencias nuevas)**: ✅ no se introduce ninguna dependencia nueva en ningún repo.
- **Principio X (verificación obligatoria)**: ✅ se añaden tests de funcionalidad (mismo patrón de script que spec 158) que cubren FR-001 a FR-011a y los Edge Cases del spec; se re-ejecutan los scripts existentes de compras (`test_purchase_presentation.py`, `test_purchase_unit_conversion.py`, `test_suggested_purchases.py`) para confirmar ausencia de regresión en la creación manual.
- **Principio XI (negocio vs. técnico)**: ✅ la decisión de que estas órdenes nazcan "recibidas" es una decisión de negocio explícita en el spec (el administrador ya da por recibida la mercancía al generar), distinta de la decisión técnica de cómo implementarla (extender `_build_purchase_order` en la misma transacción en vez de encadenar una llamada HTTP a `receive_purchase`).
- **Principio XIV/XV (ramas y commits)**: se seguirán al implementar (`feat/163-compra-sugerida-registro-inventario`), fuera del alcance de este comando de planeación.

No hay violaciones sin justificar; la única entrada de Complexity Tracking está justificada arriba y abajo.

## Project Structure

### Documentation (this feature)

```text
specs/163-compra-sugerida-registro-inventario/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md         # Phase 1 output (/speckit-plan command)
├── quickstart.md         # Phase 1 output (/speckit-plan command)
├── contracts/            # Phase 1 output (/speckit-plan command)
│   └── suggested-purchases-generate-delta.md
└── tasks.md              # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
../pos-backend/
├── app/
│   ├── api/v1/inventory/
│   │   └── service.py                           # _build_purchase_order(+receive_immediately), generate_suggested_purchases()
│   └── scripts/
│       └── test_suggested_purchases.py           # + casos nuevos (recepción automática, idempotencia, rollback, anulación)
└── (sin migraciones nuevas — ver data-model.md)

../pos-heladeria/
├── src/app/modules/inventory/
│   ├── pages/
│   │   └── suggested-purchase-page.component.ts        # confirmación muestra "recibida"; invalida el listado tras generar (FR-011a)
│   ├── services/
│   │   └── suggested-purchase.service.ts                # invalidateQueries(['suggested-purchases']) tras generate() exitoso
│   └── pages/
│       └── suggested-purchase-page.component.spec.ts     # + casos nuevos
```

**Structure Decision**: mismo módulo `inventory` de ambos repos que ya usa spec 158; no se
crea ninguna pantalla, servicio, router ni tabla nueva — es una modificación interna y acotada
de la función de generación ya existente y de la pantalla ya existente.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|---------------------------------------|
| Extender `_build_purchase_order()` con un parámetro nuevo `receive_immediately: bool = False` que, cuando es `True`, marca cada `PurchaseItem` como recibido por completo, llama a `record_movement` y actualiza `InventoryItem.unit_cost` antes de que el llamador decida el commit | FR-001/FR-002/FR-003/FR-004 exigen que la creación de la orden, el movimiento de inventario y el aumento de stock de **todas** las líneas de **todas** las órdenes del lote ocurran dentro de la misma transacción todo-o-nada que ya usa `generate_suggested_purchases()`. La lógica de "dar stock completo al crear" ya existe y está probada en `create_purchase()` (mismos tres pasos: `record_movement`, `received_quantity = quantity`, `item.unit_cost = cost_base`); el único hueco real es que `_build_purchase_order()` (la variante no-commiteadora que ya construye N órdenes por proveedor) nunca los ejecuta. | Llamar a `receive_purchase()` después de crear cada orden: esa función re-consulta la `Purchase` por `id` esperando que ya esté comiteada, recalcula la cantidad a partir de `presentation_quantity`/`relation.effective_conversion_factor` en vez de reusar el `quantity_base`/`cost_base` ya resueltos por `_resolve_purchase_line`, y comitea/rollbackea su propia transacción — encadenarla rompería la atomicidad del lote completo (FR-004) exactamente igual que llamar a `create_purchase_order()` una vez por proveedor ya se rechazó en spec 158 (research.md D5). Duplicar los tres pasos de recepción en una función nueva separada en vez de añadir el flag: repite lógica ya probada por `create_purchase()` con riesgo de que ambas copias diverjan. |
