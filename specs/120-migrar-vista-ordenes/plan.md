# Implementation Plan: Migrar vista del módulo de Órdenes al nuevo diseño

**Branch**: `120-migrar-vista-ordenes` | **Date**: 2026-10-15 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/120-migrar-vista-ordenes/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Migrar la vista del módulo de Órdenes de `pos-heladeria` (lista + detalle) al look&feel del diseño de referencia (`desing/SkeiloPOS App.dc.html`), con paridad funcional completa: tarjetas en grid, buscador por cliente/orden, filtro de fecha con calendario, filtro de tipo segmentado, acceso directo "Nueva orden" y un detalle agrupado por bloques (orden, cliente, domicilio, factura). El buscador y el filtro de fecha deben operar sobre todas las órdenes del negocio, no solo sobre la página visible, lo que exige extender de forma aditiva el endpoint `GET /orders` de `pos-backend` con `date_from`/`date_to` y una búsqueda `q`, siguiendo el mismo patrón ya usado por `GET /sales`. No se modifican reglas de negocio, estados, tipos ni el modelo de datos existente: solo se añade una superficie de consulta de solo lectura y se reconstruye visualmente el frontend.

## Technical Context

**Language/Version**: TypeScript 5.9 (Angular 21, standalone components + signals) en `pos-heladeria`; Python 3.11 (FastAPI + SQLAlchemy) en `pos-backend`.

**Primary Dependencies**: Angular 21 (`@angular/core`, `@angular/router`, `@angular/forms`), `@tanstack/angular-query-experimental` (ya en uso vía `injectPagedQuery`), Tailwind CSS 4.1. Backend: FastAPI, SQLAlchemy, el helper de paginación existente (`app/core/pagination.py`). **No se introduce ninguna dependencia nueva** (Principio IX).

**Storage**: PostgreSQL 16 (schema-per-tenant), sin cambios de esquema — solo nuevos parámetros de consulta de solo lectura sobre `customer_orders`.

**Testing**: Backend — pytest (suite existente de `app/api/v1/orders`). Frontend — Vitest + Angular Testing Library/TestBed vía `@angular/build:unit-test` (patrón ya usado en `orders-page.component.spec.ts`, `order-detail.component.spec.ts`, `orders-list.service.spec.ts`).

**Target Platform**: Navegador web, responsive (escritorio y pantallas angostas tablet/móvil), mismo soporte que el resto del dashboard administrativo.

**Project Type**: Aplicación web de dos repositorios independientes ya en producción (`../pos-backend` API, `../pos-heladeria` frontend Angular) — ver Principio "Alcance del Proyecto" de la constitución.

**Performance Goals**: Filtrar/buscar sin recarga completa de página (SC-002); respuesta de la lista filtrada percibida como instantánea en operación típica (decenas de órdenes por día, mismo orden de magnitud que `GET /sales` hoy).

**Constraints**: Ningún cambio de comportamiento en estados, tipos o reglas de facturación existentes (Principio II); el cambio de backend es aditivo y retrocompatible (parámetros opcionales, respuesta `Page<OrderResponse>` sin cambios de forma); sin migración de datos (Principio VIII, N/A).

**Scale/Scope**: Un módulo (Órdenes): 2 pantallas (lista, detalle), 1 servicio de datos frontend extendido, 1 endpoint backend extendido. Sin pantallas nuevas de creación (se reutiliza el flujo existente de pedido manual).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Evaluación |
|---|---|
| I. Nace de un spec | PASS — `specs/120-migrar-vista-ordenes/spec.md` define problema, alcance, reglas y criterios de aceptación antes de tocar código. |
| II. Comportamiento existente protegido | PASS — estados, tipos y reglas de facturación/estado de pago se conservan igual (spec FR-017, Assumptions); el único comportamiento *nuevo* (buscar/filtrar por fecha sobre todo el negocio) es aditivo, no reemplaza nada existente, y queda definido en el spec — no requiere entrada en `registro-de-anomalias.md` porque no cambia ningún comportamiento ya vigente. |
| III. Characterization tests | PASS — no se toca código de facturación/cocina; ningún test `"CONGELA comportamiento actual:"` debería verse afectado. A verificar en implementación que ningún test de ese prefijo en `orders`/`tables` se vea tocado. |
| IV. Nuevos specs pueden introducir comportamiento nuevo | PASS — búsqueda y filtro de fecha son comportamiento nuevo, explícitamente definido en el spec (FR-004, FR-005). |
| V. Nuevas funcionalidades antes que refactors oportunistas | PASS (gate de diseño) — este plan no incluye ninguna refactorización no relacionada; a vigilar en `/speckit-tasks`/implementación. |
| VI. Evolución incremental | **Atención** — la funcionalidad toca dos repositorios (backend + frontend). Se divide en unidades verificables: (a) extensión del endpoint `GET /orders` en `pos-backend` con sus propios tests, y (b) migración de la vista en `pos-heladeria` con sus propios tests, cada una en su propia rama por repositorio (Principio XIV). Documentado en Complexity Tracking. |
| VII. Compatibilidad con datos históricos | PASS — ninguna factura emitida se recalcula ni se re-representa; la vista solo lee datos ya existentes. |
| VIII. Evolución del modelo de datos | PASS — no hay cambios de esquema ni migración; solo nuevos parámetros de consulta sobre columnas ya existentes (`customer_name`, `created_at`, `id`). |
| IX. Dependencias nuevas | PASS — ninguna dependencia nueva en ninguno de los dos repositorios. |
| X. Verificación obligatoria | PASS (gate de diseño) — plan exige tests backend para los nuevos parámetros y tests frontend para filtros/lista/detalle; se detallan en `/speckit-tasks`. |
| XI. Negocio vs técnico | PASS — no se introduce ninguna regla de negocio nueva; las decisiones de este plan (código de orden visible, UI de calendario, etc.) son técnicas/de presentación, documentadas en `research.md`. |
| XII. Trazabilidad | PASS — cadena Necesidad (diseño de referencia) → Spec 120 → este plan → research/data-model/contracts → tasks (siguiente comando). |
| XIII. Español de Colombia | PASS — todos los artefactos de esta fase (spec, plan, research, data-model, quickstart) en español de Colombia. |
| XIV. Ramas Git | A aplicar en implementación — una rama `feat/120-orders-filters-api` (o equivalente) en `pos-backend` y `feat/120-orders-view-redesign` (o equivalente) en `pos-heladeria`, cada una creada antes de tocar código en su repositorio. |
| XV. Commits | A aplicar en implementación — commits pequeños y enfocados, solo bajo pedido explícito del usuario, en inglés, sin marcas de autoría de IA. |

No hay violaciones que bloqueen el diseño; el único punto de atención (Principio VI, dos repositorios) queda justificado en **Complexity Tracking**.

**Re-chequeo post-diseño (tras Fase 1)**: `research.md` y `data-model.md` confirman que ninguna decisión de diseño introdujo cambios de esquema (Principio VIII), nuevas dependencias (Principio IX) ni reglas de negocio nuevas (Principio XI) — el código corto de orden, el mapeo de estados/tipos y el calendario de fecha son decisiones de presentación, no de datos ni de negocio. El Constitution Check sigue en PASS sin cambios respecto a la evaluación anterior a la Fase 0.

## Project Structure

### Documentation (this feature)

```text
specs/120-migrar-vista-ordenes/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   └── orders-list-api.md
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

Aplicación web de dos repositorios hermanos (no un monorepo) — ambos ya en producción, referenciados desde `pos-specs` como `../pos-backend` y `../pos-heladeria`:

```text
../pos-backend/
└── app/api/v1/orders/
    ├── router.py          # GET /orders: agrega date_from, date_to, q (opcionales)
    ├── service.py         # list_orders_query(): agrega filtros de fecha y búsqueda
    └── schemas.py         # sin cambios de forma (Page[OrderResponse] ya expone lo necesario)
tests/api/v1/orders/
└── test_list_orders.py    # (o el archivo de tests existente) casos nuevos: date_from/date_to, q

../pos-heladeria/
└── src/app/modules/orders/
    ├── pages/
    │   ├── orders-page.component.ts     # rediseño: grid de tarjetas, filtros, buscador, fecha, paginación, "Nueva orden"
    │   ├── orders-page.component.spec.ts
    │   ├── order-detail.component.ts    # rediseño: encabezado + bloques agrupados (orden/cliente/domicilio/factura) + ítems + totales
    │   └── order-detail.component.spec.ts
    ├── services/
    │   ├── orders-list.service.ts       # agrega search/dateFrom/dateTo (mismo patrón que SalesService)
    │   └── orders-list.service.spec.ts
    ├── order-status.util.ts             # sin cambios de significado; posible helper nuevo de código de orden visible
    └── components/                      # (nuevo, si se extrae) selector de fecha con calendario, reutilizable dentro del módulo
```

**Structure Decision**: Se extiende el patrón ya existente en ambos repositorios en vez de crear estructura nueva. En `pos-backend`, el cambio vive enteramente dentro de `app/api/v1/orders/` (router + service), espejando cómo `app/api/v1/sales/` ya resuelve `date_from`/`date_to`. En `pos-heladeria`, el cambio vive enteramente dentro de `src/app/modules/orders/` (páginas + servicio), sin tocar `modules/tables` más allá de los puntos de entrada/salida de navegación ya existentes (ruta `mesas-sesiones/orden-manual` para "Nueva orden"). No se crean módulos, apps ni paquetes nuevos.

## Complexity Tracking

> El Constitution Check no tiene violaciones bloqueantes; se documenta aquí el único punto de atención identificado (Principio VI) y cómo se resuelve.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|---------------------------------------|
| La funcionalidad toca dos repositorios (`pos-backend` + `pos-heladeria`) en vez de uno solo | La búsqueda y el filtro de fecha deben operar sobre todas las órdenes del negocio (spec, Assumptions), no solo sobre la página ya cargada en el navegador; eso exige que el propio backend sepa filtrar por fecha y texto, no solo el frontend. | Filtrar/buscar únicamente en el cliente sobre la página visible (sin tocar `pos-backend`) fue considerado y rechazado explícitamente por el usuario: da resultados incompletos (solo busca dentro de los ítems ya cargados) y no cumple la paridad funcional con el diseño de referencia que se pidió migrar. |
