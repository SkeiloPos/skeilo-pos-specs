# Implementation Plan: Compra de Insumos con Conversión a Unidad Base

**Branch**: `134-conversion-unidades-compra` | **Date**: 2026-10-24 | **Spec**:
[spec.md](./spec.md)

**Input**: Feature specification from `specs/134-conversion-unidades-compra/spec.md`

## Summary

Permitir que una línea de compra se capture en la unidad en que el proveedor factura
(p. ej. KG, LB) y que el sistema calcule en servidor, al confirmar el documento, la
cantidad y el costo unitario equivalentes en la unidad base del insumo — sin cálculo
manual del encargado y sin pérdida de precisión. El enfoque técnico reutiliza
infraestructura ya existente en `pos-backend` que fue construida para esto pero nunca
conectada: `app/core/units.py::convert()` (congelado hoy como código muerto, RN-CAT-41)
se activa añadiendo `dimension`/`factor_to_base` a `UnitMeasure`; el patrón de
"conversión de línea de compra con snapshot inmutable" ya existe para presentaciones de
proveedor (spec 106/107, `supplier_item_id`) y se generaliza con columnas nuevas en
`PurchaseItem` (`unit_measure_id`, `conversion_factor_applied`, `quantity_base`,
`cost_base`) sin tocar esa ruta existente. La atomicidad de stock concurrente (FR-020)
ya la da `record_movement()` con `SELECT ... FOR UPDATE`. Lo genuinamente nuevo es:
anulación de compras confirmadas (no existía ningún endpoint de void), historial de
cambios de factor con autorización de ADMIN, y la bandera de tenant
`unit_conversion_enabled`. Ver `research.md` para el detalle de cada decisión.

## Technical Context

**Language/Version**: Python 3.11 (FastAPI) en `pos-backend`; TypeScript/Angular
(standalone components, signals) en `pos-heladeria`.

**Primary Dependencies**: FastAPI, SQLAlchemy 2.x, Alembic, Pydantic v2 (backend);
Angular, RxJS/Signals (frontend). Ninguna dependencia nueva (Principio IX: no aplica,
no se justifica ninguna).

**Storage**: PostgreSQL 16, schema-per-tenant (`tenant` para datos de negocio, `shared`
para `tenants`/`users`/`roles`).

**Testing**: `pytest`/`unittest` — characterization tests existentes
(`app/characterization_tests/`, en particular `test_core_units.py`) más tests nuevos de
modelo/servicio/endpoint para esta spec, siguiendo el patrón ya usado por spec 106/107
(`app/scripts/test_purchase_presentation.py`, `test_supplier_items.py`). Frontend: la
suite existente de Angular (baseline conocido como flaky; comparar por archivo
afectado, no por conteo total — ver memoria de sesión).

**Target Platform**: Linux server (API detrás de Gunicorn/Uvicorn); navegador (SPA
Angular).

**Project Type**: Web application — dos repositorios independientes ya en producción
(`pos-backend`, `pos-heladeria`), ambos tocados por esta spec.

**Performance Goals**: sin metas nuevas explícitas en la spec. No debe degradar el
camino ya existente de `create_purchase`/`receive_purchase` (reutiliza
`record_movement()` tal cual, sin locks ni queries adicionales por línea más allá de
cargar la `UnitMeasure` elegida).

**Constraints**: precisión de 6 decimales para cantidad/costo en unidad base
(clarificación de la spec, cierra en `Numeric(18,6)`, ver research.md D4); ningún
recálculo retroactivo de compras ya confirmadas tras un cambio de factor (FR-010,
Principio VII extendido por analogía a compras — no solo facturas); aislamiento
estricto por tenant (FR-017, ya dado por el esquema per-tenant).

**Scale/Scope**: cambio acotado a los módulos de catálogo de unidades
(`unit_measures`), insumos (`inventory_items`) y compras (`purchases`/
`purchase_items`) de ambos repos. No toca ventas, caja, pedidos de mesa ni
facturación.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Evaluación |
|---|---|
| I. Nace de un spec | ✅ `specs/134-conversion-unidades-compra/spec.md` ya aprobado, con FRs/criterios de aceptación. |
| II. Comportamiento existente protegido | ✅ La ruta `supplier_item_id` (spec 106/107) queda congelada sin cambios observables (research.md D5). El único comportamiento "cambiado" es activar `convert()`, que hoy es código muerto sin usuarios reales (RN-CAT-41) — no hay comportamiento de producción que proteger ahí. Documentado explícitamente en research.md D2. |
| III. Characterization tests | ⚠️ `test_core_units.py::ConvertWithRealUnitMeasureModelTests` queda obsoleto por diseño (el modelo real pasa a tener `dimension`/`factor_to_base`). Se actualiza explícitamente en el mismo cambio, citando esta spec (research.md D2) — no se "ajusta a escondidas". |
| IV. Nuevo comportamiento permitido | ✅ Toda la funcionalidad nueva (conversión general, anulación de compras, historial de factor) está definida por esta spec. |
| V. Sin refactors oportunistas | ✅ No se toca la ruta de presentaciones de proveedor ni se introduce una media ponderada de costo (research.md D6) aunque la spec hable de "costo promedio" — se preserva la sobrescritura simple ya existente. |
| VI. Evolución incremental | ✅ Cambios de esquema aditivos (nuevas columnas/tabla, ensanches de precisión); ninguna migración de datos destructiva. |
| VII. Compatibilidad con datos históricos | ✅ Backfill explícito (FR-021/data-model.md) preserva stock y valores ya registrados; ninguna factura se toca (esta spec no interactúa con facturación). |
| VIII. Evolución del modelo de datos | ✅ `data-model.md` detalla entidades/columnas nuevas, defaults, compatibilidad y estrategia de backfill. Rollback: todas las columnas nuevas son `DROP COLUMN` seguro; los ensanches de precisión son reversibles porque ningún dato existente excede la escala anterior. |
| IX. Dependencias nuevas | ✅ No aplica — cero dependencias nuevas. |
| X. Verificación obligatoria | ✅ `quickstart.md` cubre los 3 user stories + regresión de characterization tests. |
| XI. Negocio vs. técnico | ✅ Las decisiones de research.md (D1, D4, D5, D6, D9, D11) son técnicas (cómo implementar FRs ya aprobados); ninguna redefine comportamiento de negocio no cubierto por la spec. D8 (bandera de tenant) cierra un hueco de persistencia para un FR ya aprobado, no una decisión de negocio nueva. |
| XII. Trazabilidad | ✅ Necesidad (spec) → Decisión (research.md, citando hallazgos concretos de código) → Implementación (tasks.md, pendiente de `/speckit-tasks`) → Tests → Verificación (quickstart.md). |
| XIII–XV. Español/branches/commits | ✅ Este plan y sus artefactos están en español de Colombia; nombres de rama/commits se definirán en inglés al implementar, conforme a los Principios XIV/XV (fuera del alcance de este documento de planeación). |

**Resultado**: PASA sin violaciones que requieran justificación en Complexity
Tracking. Único punto de atención (⚠️) es el characterization test que queda
desactualizado por diseño — ya resuelto con una actualización explícita y citada, no
una excepción sin registrar.

## Project Structure

### Documentation (this feature)

```text
specs/134-conversion-unidades-compra/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md         # Phase 1 output
├── quickstart.md         # Phase 1 output
├── contracts/
│   └── api-changes.md    # Phase 1 output
└── tasks.md               # Phase 2 output (/speckit-tasks — no creado aún)
```

### Source Code (repositorios afectados)

```text
../pos-backend/
├── app/
│   ├── models/
│   │   ├── unit_measure.py          # + dimension, factor_to_base
│   │   ├── unit_measure_factor_change.py   # NUEVO
│   │   ├── inventory_item.py        # ensancha current_stock/unit_cost
│   │   ├── inventory_movement.py    # ensancha quantity
│   │   └── purchase.py              # + voided_at/voided_by; PurchaseItem + 4 columnas
│   ├── core/
│   │   ├── units.py                 # ya existe (convert()); se activa, no se reescribe
│   │   ├── inventory_reasons.py     # + REF_PURCHASE_VOID
│   │   ├── models.py                # Tenant + unit_conversion_enabled
│   │   └── dependencies.py          # require_tenant_admin ya existe, se reutiliza
│   ├── api/v1/
│   │   ├── unit_measures/
│   │   │   ├── router.py            # + filtro dimension, + endpoint factor-changes, rol admin en PATCH de factor
│   │   │   └── schemas.py           # + dimension/factor_to_base, FactorChangeResponse
│   │   └── inventory/
│   │       ├── service.py           # _resolve_purchase_line: nueva rama unit_measure_id; nuevo void_purchase()
│   │       ├── schemas.py           # PurchaseItemIn/Response + campos nuevos; PurchaseResponse + voided_*
│   │       └── router.py            # POST /purchases/{id}/void; PATCH /items/{id} valida FR-002
│   └── characterization_tests/
│       └── test_core_units.py       # actualiza ConvertWithRealUnitMeasureModelTests (cita spec 134)
├── alembic/versions/
│   └── <rev>_134_unit_conversion_compras.py   # NUEVA migración (aditiva + backfill)
└── app/scripts/
    └── test_purchase_unit_conversion.py        # NUEVO, mismo patrón que test_purchase_presentation.py

../pos-heladeria/
└── src/app/
    ├── core/services/unit-measure.service.ts          # + dimension/factor_to_base, filtro por dimension
    ├── modules/inventory/
    │   ├── interfaces/inventory.interface.ts           # + campos nuevos en PurchaseItem/PurchaseLineForm
    │   ├── components/purchase-form.component.ts       # + selector de unidad + vista previa de equivalencia
    │   └── services/inventory.service.ts                # + voidPurchase()
    └── modules/settings/
        └── pages/tenant-info.component.ts                # + toggle unit_conversion_enabled
```

**Structure Decision**: aplicación web con dos repos ya existentes y en producción
(`pos-backend` API, `pos-heladeria` frontend Angular) — misma estructura que el resto
del proyecto, sin reorganización. El trabajo se concentra en los módulos de catálogo de
unidades y de inventario/compras de `pos-backend`, con su contraparte mínima en los
componentes de compra y configuración del tenant de `pos-heladeria`.

## Complexity Tracking

*Sin violaciones del Constitution Check que requieran justificación — tabla vacía
intencionalmente.*
