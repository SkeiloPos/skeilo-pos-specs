# Implementation Plan: Comprar en la presentación real, no en la unidad base

**Branch**: `107-compra-presentacion-conversion` | **Date**: 2026-10-09 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/107-compra-presentacion-conversion/spec.md`

## Summary

Conectar `SupplierItem.presentation`/`conversion_factor` (spec 106, ya implementado) a los 3
flujos de compra de `pos-backend` (alta directa, creación de orden, recepción parcial): cuando
una línea de compra indica `supplier_item_id` en vez de `quantity`/`unit_cost` directos, el
servicio calcula la cantidad y el costo en unidad base a partir de la presentación, conserva lo
que el administrador tecleó realmente (cantidad de presentaciones + una copia del texto de la
presentación, por integridad histórica) y actualiza automáticamente `SupplierItem.last_cost`/
`last_cost_at` (RN-15). `record_movement` (kardex) no cambia: sigue recibiendo siempre la
cantidad ya convertida a unidad base, igual que hoy.

## Technical Context

**Language/Version**: Python 3.14 (`pos-backend`) + TypeScript 5.9 / Angular 21
(`pos-heladeria`) — mismo entorno que la spec 106.

**Primary Dependencies**: FastAPI 0.136, SQLAlchemy 2.0, Pydantic 2.13, Alembic 1.18
(`pos-backend`); Angular 21 (`pos-heladeria`) — ninguna dependencia nueva (Principio IX);
reutiliza íntegramente `app/api/v1/inventory/supplier_items.py` y
`src/app/modules/supplier-items/` de la spec 106.

**Storage**: PostgreSQL 16, un esquema por tenant — igual que la spec 106.

**Testing**: mismo patrón que la spec 106 — script autoejecutable
`app/scripts/test_purchase_presentation.py` (`python -m app.scripts.test_purchase_presentation`)
contra un tenant real, más la suite de characterization
(`./env/bin/python -m unittest discover -s app/characterization_tests`), que **protege**
RN-INV-16/17/22/23 (spec 005) — esta spec no las reabre, solo les agrega un segundo camino de
entrada (vía presentación) que debe respetarlas igual que el camino directo ya existente.
`pos-heladeria` usa `npx ng test --watch=false` (Vitest).

**Target Platform**: servidor Linux (API) + SPA Angular en navegador.

**Project Type**: aplicación web existente de dos repositorios, ambos en producción.

**Performance Goals**: sin objetivo propio — una compra tiene, como mucho, unas pocas decenas de
líneas; el cálculo de conversión es aritmética simple, sin consultas adicionales por línea más
allá de obtener la relación proveedor-insumo ya elegida.

**Constraints**: `record_movement` (kardex, invariante protegido por spec 005 US1) no cambia su
firma ni su contrato — toda conversión ocurre **antes** de llamarlo, nunca dentro. El costo
aplicado en una recepción debe seguir siendo el pactado al crear la orden (RN-INV-22) — el factor
de conversión usado en la recepción se recupera del `PurchaseItem` ya creado (vía su
`supplier_item_id`), nunca del request de recepción, para que no pueda cambiar entre crear y
recibir.

**Scale/Scope**: 2 columnas nuevas en `PurchaseItem`; 1 función nueva en `supplier_items.py`
(RN-15); 2 esquemas Pydantic extendidos (`PurchaseItemIn`, `PurchaseReceiveItemIn`) + sus
respuestas; los 3 endpoints de compra ya existentes, sin endpoints nuevos; en el frontend, un
selector de presentación nuevo por línea en `purchase-form.component.ts`, reutilizando
componentes y servicios ya construidos por la spec 106.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Evaluación |
|---|---|
| I. Nace de un spec | PASS — `specs/107-compra-presentacion-conversion/spec.md`, clarificada |
| II. Comportamiento existente protegido | PASS — una compra que no indica `supplier_item_id` se comporta exactamente igual que hoy (FR-007); es el mismo criterio ya usado por spec 106 para "Compra ocasional" |
| III. Characterization tests | PASS con atención — RN-INV-16/17/22/23 (spec 005) son invariantes protegidos que este plan reutiliza sin reabrir; `quickstart.md` incluye verificarlos explícitamente contra el camino nuevo, no solo el camino directo ya cubierto |
| IV. Nuevos specs introducen comportamiento nuevo | PASS — exactamente ese caso |
| V. Sin refactors oportunistas | PASS — se extiende `service.py` (ya existente) y `supplier_items.py` (spec 106); no se reorganiza nada de lo ya construido |
| VI. Evolución incremental | PASS — una sola pieza de modelo de datos nueva (2 columnas en `PurchaseItem`, ambas nullable), sin mezclar clases de cambio distintas; no requiere Complexity Tracking |
| VII. Datos históricos | PASS — ninguna compra ya registrada se recalcula; las columnas nuevas nacen `NULL` para todo lo existente. Ver `research.md` D1 para el hallazgo de que el *texto* de la presentación debe copiarse (snapshot), no solo referenciarse, para no alterar retroactivamente cómo se ve una compra vieja si alguien edita esa presentación después |
| VIII. Evolución del modelo de datos | PASS, ver `data-model.md` — columnas nuevas, defaults, compatibilidad y rollback documentados explícitamente |
| IX. Dependencias nuevas | PASS — cero |
| X. Verificación obligatoria | PASS, ver `quickstart.md` — script dedicado + specs Angular del formulario de compra |
| XI. Negocio vs técnico | PASS — RN-15, RN-INV-22/23 y la clarificación de costo-por-presentación son decisiones de negocio ya registradas en el spec; este plan solo decide el *cómo* |
| XII. Trazabilidad | PASS — spec 107 → este plan → tasks.md → implementación → script de verificación/specs Angular |
| XIII. Español de Colombia | Aplicado en este documento y en los artefactos de esta fase |
| XIV. Rama Git | Pendiente de implementación: `feat/107-compra-presentacion-conversion` en `pos-backend` y en `pos-heladeria` |
| XV. Commits | Pendiente de implementación: solo bajo pedido explícito del usuario |

**Re-chequeo post-diseño (Fase 1)**: sin cambios — `data-model.md` y `contracts/api.md` no
introdujeron ninguna pieza adicional de modelo de datos ni ninguna dependencia nueva respecto a
lo evaluado arriba.

## Project Structure

### Documentation (this feature)

```text
specs/107-compra-presentacion-conversion/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── api.md
└── tasks.md              # /speckit-tasks, no este comando
```

### Source Code (sibling repositories, fuera de `pos-specs`)

```text
../pos-backend/
├── app/models/purchase.py              # PurchaseItem += supplier_item_id (ya existe, se puebla
│                                        #   de verdad) + presentation_quantity + presentation_label
├── app/api/v1/inventory/
│   ├── schemas.py                      # PurchaseItemIn/PurchaseReceiveItemIn += campos de
│   │                                    #   presentación + sus Response
│   ├── service.py                      # create_purchase / create_purchase_order /
│   │                                    #   receive_purchase: calculan unidad base cuando hay
│   │                                    #   supplier_item_id, delegan RN-15 a supplier_items.py
│   └── supplier_items.py               # + apply_purchase_cost(db, relation, cost) -- RN-15,
│                                        #   reutiliza el patrón "no hace commit" de
│                                        #   _apply_preferred_swap (spec 106)
├── alembic/versions/
│   └── <hash>_purchase_items_presentacion.py   # NUEVO, vía @for_each_tenant_schema
└── app/scripts/
    └── test_purchase_presentation.py   # NUEVO

../pos-heladeria/
└── src/app/modules/inventory/
    ├── interfaces/inventory.interface.ts   # PurchaseLineForm/PurchaseItemPayload += campos de
    │                                       #   presentación
    ├── services/inventory.service.ts       # createPurchase/createPurchaseOrder/receivePurchase
    │                                       #   envían los campos nuevos cuando aplica
    └── components/purchase-form.component.ts  # selector de presentación por línea, reutilizando
                                               #   SupplierItemsService.listForItem (spec 106) ya
                                               #   existente -- sin componente ni endpoint nuevos
```

**Structure Decision**: se extiende `service.py`/`schemas.py`/`supplier_items.py` ya existentes
en vez de crear un módulo nuevo — es el mismo patrón que la propia spec 106 siguió para no
fragmentar un dominio que el código ya trata como una sola unidad (`inventory`). En el frontend,
no se crea ningún componente nuevo: el selector de presentación reutiliza
`SupplierItemsService.listForItem()` (ya construido), filtrado por el proveedor ya elegido en la
compra — no hace falta un endpoint de lectura nuevo para esto.

## Complexity Tracking

*Sin violaciones que requieran justificación — ver Constitution Check arriba.*
