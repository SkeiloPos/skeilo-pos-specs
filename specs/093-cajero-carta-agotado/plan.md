# Implementation Plan: Carta del menú para Cajero con estado Agotado

**Branch**: `093-cajero-carta-agotado` | **Date**: 2026-10-03 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/093-cajero-carta-agotado/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Dar al rol Cajero una pantalla de solo lectura, "Carta del menú" (listado + detalle de
producto), y extenderle a él (además del Administrador) el interruptor "Agotado" que
marca un producto como temporalmente no vendible sin desactivarlo del catálogo; ese
estado debe bloquear de verdad que se agregue el producto a un pedido nuevo (Terminal de
mesas y menú QR), sin ocultar el producto ni tocar pedidos ya creados.

El hallazgo central de la investigación técnica (research.md) es que **el campo
`Product.available` y su interruptor administrador ya existen en producción** — esta
spec no crea "Agotado" desde cero, lo extiende a un segundo rol y, sobre todo, le da por
primera vez un efecto real sobre carrito y órdenes (hoy el flag solo oculta productos del
menú QR, sin validarse en ningún punto de creación de pedidos). El enfoque técnico：(1)
backend: un endpoint nuevo y angosto (`PATCH /products/{id}/availability`) protegido por
una dependencia nueva de dos roles, validación de `variant.product.available` en los
cuatro puntos donde hoy se valida `variant.active` (carrito y órdenes), y un cambio
puntual en la función compartida que arma el menú (`_build_menu`) para dejar de ocultar
productos agotados; (2) frontend: reutilizar el ítem de sidebar y el patrón de pantalla
compartida Admin+Cajero-con-acciones-admin-only que ya usa Caja, agregar una vista de
detalle de solo lectura (no existía), y reflejar el nuevo campo `sold_out` del menú en
las dos grillas de selección de producto que hoy lo ignoran.

## Technical Context

**Language/Version**: Backend: Python 3.14 (FastAPI). Frontend: TypeScript ~5.9 (Angular 21)

**Primary Dependencies**: Backend: FastAPI, SQLAlchemy, Alembic, Pydantic (sin
dependencias nuevas). Frontend: Angular Router, RxJS, `@tanstack/angular-query-experimental`
(sin dependencias nuevas — la utilidad de tiempo relativo de research.md D13 se escribe a
mano, sin librería)

**Storage**: PostgreSQL 16, schema-per-tenant. Dos columnas nuevas, nullable, en
`tenant.products` (`available_changed_at`, `available_changed_by_name`); reutilización de
la tabla genérica ya existente `tenant.audit_logs` — ver data-model.md

**Testing**: Backend: `unittest` (`app/characterization_tests/`, convención del repo).
Frontend: Vitest (unitario/componentes), Playwright (e2e) — ambos ya configurados

**Target Platform**: Backend: servidor Linux (API). Frontend: SPA de navegador, panel del
tenant + menú QR público

**Project Type**: Aplicación web (backend + frontend en dos repos separados:
`pos-backend`, `pos-heladeria`; este repo, `pos-specs`, solo contiene la documentación)

**Performance Goals**: Ninguno nuevo. La validación de disponibilidad en carrito/órdenes
reutiliza una relación ya cargada (`ProductVariant.product`) en los mismos puntos donde
ya corre `variant.active`, sin consulta adicional por ítem

**Constraints**: No modificar el comportamiento de edición/creación/desactivación de
productos que ya tiene el Administrador (FR-007); el bloqueo de pedidos debe ser real del
lado del servidor, no solo deshabilitar un botón (escenario 7); ningún pedido ya creado
se recalcula ni se revalida (FR-023); el campo `available` ya existente en la respuesta
del menú (semántica "pedible por stock") no puede tocarse ni reinterpretarse (D6)

**Scale/Scope**: Alcance acotado: un endpoint nuevo, una dependencia de autorización
nueva, dos columnas nuevas, un campo nuevo en una respuesta ya existente, cuatro puntos
de validación en servicios ya existentes, y extensiones de configuración/pantalla
(no de mecanismo) en el frontend — ningún módulo ni tabla nueva

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Evaluación |
|---|---|
| I. Nace de un spec | ✅ `specs/093-cajero-carta-agotado/spec.md`, con 16 escenarios de aceptación y reglas de negocio ya cerradas, sin `NEEDS CLARIFICATION` pendiente |
| II. Comportamiento existente protegido | ✅ El único cambio de comportamiento ya vigente (dejar de ocultar productos agotados en el menú QR/Terminal) está documentado explícitamente en el spec (FR-019, escenarios 5/6) y registrado como decisión de negocio en `specs/000-reconocimiento/registro-de-anomalias.md` (A-104), con quién y cuándo. Todo lo demás (edición/creación/desactivación de productos por Admin, acceso de Mesero, grupos de opciones de la Terminal) queda explícitamente sin tocar (research.md D8, D11; `contracts/permissions.md`) |
| III. Characterization tests protegen lo heredado | ✅ Ningún test `"CONGELA comportamiento actual:"` se toca. `test_menu_router.py` no prueba el filtro `Product.available` que se quita (research.md D6) — se verificó explícitamente antes de tocar esa función. La lógica de "pedible por stock" que sí protege ese archivo no se modifica |
| IV. Los nuevos specs pueden introducir comportamiento nuevo | ✅ Aplica — el bloqueo real de pedidos agotados y la visibilidad "atenuado, no oculto" son comportamiento nuevo, autorizado explícitamente por el spec |
| V. Nueva funcionalidad antes que refactor oportunista | ✅ No se generaliza el mecanismo de default-deny de Mesero a multi-rol (D2), no se toca `update_product`/el formulario de edición de Admin (D3/D9), no se restringe `option-groups` aunque comparte terreno conceptual con "inventario" (D8) — cada decisión documenta por qué el cambio más amplio quedó fuera |
| VI. Evolución incremental | ✅ Las tres historias de usuario del spec son independientes y acumulativas (P1 listar/marcar → P2 bloquear pedidos → P3 garantías de API); el plan no mezcla esto con ninguna otra funcionalidad |
| VII. Compatibilidad con datos históricos | N/A — no se toca ninguna factura ni venta ya emitida; FR-023/escenario 8 exigen explícitamente que los pedidos existentes no se alteren, y ningún punto de la implementación los revalida |
| VIII. Evolución del modelo de datos | ✅ `data-model.md`: columnas nuevas, nullable, default `NULL`, compatibilidad con filas existentes, migración (up/down) y reutilización de `AuditLog` ya documentadas explícitamente |
| IX. Dependencias nuevas | N/A — no se agrega ninguna dependencia de terceros (research.md D13 descarta explícitamente una librería de tiempo relativo por no estar justificada) |
| X. Verificación obligatoria | ✅ `quickstart.md` cubre las tres historias y los 16 escenarios; `tasks.md` (siguiente comando) deberá incluir tests de characterization/unitarios para la validación de disponibilidad en carrito/órdenes y para el endpoint nuevo |
| XI. Decisiones de negocio vs técnicas | ✅ La única decisión de negocio detectada durante la investigación (dejar de ocultar productos agotados) se registró en el libro de anomalías (A-104) separada de las decisiones técnicas de este plan (research.md D1-D13) |
| XII. Trazabilidad | ✅ research.md, data-model.md y los contratos referencian los FR/escenarios de spec.md por número; A-104 referencia de vuelta a research.md D6 |
| XIII. Español de Colombia | ✅ Todos los artefactos de esta funcionalidad están en español; el endpoint/campos nuevos de la API usan inglés técnico (`available`, `sold_out`) como ya hace el resto del catálogo de este backend |
| XIV. Convención de ramas Git | Pendiente al iniciar la implementación: crear `feat/093-cashier-menu-sold-out` (o equivalente) antes de tocar código en `pos-backend`/`pos-heladeria`, conforme a `<tipo>/<numero_spec>-<nombre_spec>` |
| XV. Política de commits | Pendiente al iniciar la implementación: commits solo bajo pedido explícito, atómicos, en inglés, sin marca de IA |

**Resultado**: sin violaciones. No se requiere la tabla de Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/093-cajero-carta-agotado/
├── plan.md                          # This file (/speckit-plan command output)
├── research.md                      # Phase 0 output (/speckit-plan command)
├── data-model.md                    # Phase 1 output (/speckit-plan command)
├── quickstart.md                    # Phase 1 output (/speckit-plan command)
├── contracts/
│   ├── permissions.md               # Phase 1 output (/speckit-plan command)
│   ├── products-api.md              # Phase 1 output (/speckit-plan command)
│   ├── menu-and-orders.md           # Phase 1 output (/speckit-plan command)
│   └── frontend-route-access.md     # Phase 1 output (/speckit-plan command)
├── checklists/
│   └── requirements.md
└── tasks.md                         # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

Este repo (`pos-specs`) solo contiene la documentación de la funcionalidad. El código
vive en dos repos hermanos, ya existentes — no se crea ninguna carpeta ni proyecto nuevo:

```text
../pos-backend/
├── app/core/
│   └── dependencies.py                     # require_tenant_admin_or_cashier (D2); restricción de GET /variants/{id}/recipe para CASHIER (D8)
├── app/models/
│   └── product.py                          # available_changed_at, available_changed_by_name (nuevas columnas, D5)
├── app/api/v1/products/
│   ├── router.py                           # PATCH /products/{id}/availability (nuevo, D3/D4)
│   ├── schemas.py                          # ProductResponse: + available_changed_at/by_name; ProductDetailResponse: + variants (D9)
│   └── service.py                          # set_availability() (nuevo, con record_audit, D5/D10)
├── app/api/v1/catalog/router.py            # get_recipe(): nueva verificación de rol (D8)
├── app/api/v1/menu/
│   ├── router.py                           # _build_menu(): quita el filtro Product.available (D6)
│   └── schemas.py                          # MenuProductResponse: + sold_out (D6)
├── app/api/v1/cart/service.py              # add_item/update_item/submit_cart: validación de product.available (D7)
├── app/api/v1/orders/
│   ├── consolidation.py                    # add_item_to_order: validación de product.available (D7)
│   └── service.py                          # create_order: validación de product.available (D7)
├── alembic/versions/
│   └── <nueva>_product_availability_audit_columns.py   # columnas nuevas, data-model.md
└── app/characterization_tests/             # tests nuevos/actualizados para D7/D8

../pos-heladeria/
├── src/app/core/config/navigation.config.ts        # "Carta del menú": + UserRole.CASHIER
├── src/app/modules/dashboard/routes.ts             # roleGuard de 'products' + nueva ruta 'products/:id/detalle'
├── src/app/modules/products/
│   ├── pages/products-page.component.ts            # isAdmin computed; gating de acciones; destino del clic por rol (D11)
│   ├── pages/product-detail-page.component.ts      # nuevo — vista de solo lectura (D9/D11)
│   ├── services/product.service.ts                 # toggleAvailable() → PATCH /products/{id}/availability (D3)
│   └── interfaces/product.interface.ts             # + available_changed_at/by_name
├── src/app/modules/tables/
│   ├── components/pos-catalog-drawer.component.ts  # dimming/label por product.sold_out (D6)
│   └── pages/public-menu.component.ts              # dimming/label por product.sold_out (D6)
├── src/app/core/interfaces/menu.interface.ts (o equivalente)  # MenuProduct: + sold_out
├── src/app/shared/relative-time.pipe.ts            # nuevo — "desde hace unos segundos" (D13)
└── (specs de Vitest/Playwright nuevas o actualizadas para lo anterior)
```

**Structure Decision**: Aplicación web con backend y frontend en repos separados (patrón
ya establecido por el resto de `pos-specs`). Esta funcionalidad no introduce ningún
módulo, router ni tabla nueva — extiende archivos y mecanismos ya existentes (el
endpoint de productos, la función de menú, los servicios de carrito/órdenes, y la
pantalla "Carta del menú" que ya existía solo para Admin), salvo una página nueva
("detalle de producto de solo lectura") y un pipe nuevo ("tiempo relativo"), ninguno de
los cuales existía en ninguna forma previa.

## Complexity Tracking

*Sin violaciones de la Constitution Check — tabla no aplica.*
