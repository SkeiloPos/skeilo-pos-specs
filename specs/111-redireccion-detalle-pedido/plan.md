# Implementation Plan: Corrección — Redirección al detalle del pedido tras crearlo

**Branch**: `111-redireccion-detalle-pedido` | **Date**: 2026-10-11 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/111-redireccion-detalle-pedido/spec.md`

## Summary

Tras crear un pedido desde "Nueva orden" (Mesa, Para llevar o Domicilio), el sistema debe llevar al
cajero/mesero directo al detalle de ese pedido en vez de dejarlo en la pestaña Mesas de la
terminal, sin nada seleccionado, como ocurre hoy. La causa raíz es exclusivamente de frontend
(`manual-order-page.component.ts:978-981` navega siempre a una ruta fija sin el ID del pedido ni su
tipo). **Corrección de rumbo tomada durante la implementación** (aprobada por el usuario, ver
`tasks.md`): el diseño original de este plan asumía que "la vista de detalle" era una ruta nueva,
`/dashboard/orders/:id`; se confirmó que ese componente es de solo lectura y no tiene ningún panel
de cobro — el panel "Cobrar pedido" real vive **en la terminal misma**. La corrección entonces es
más simple: la navegación de vuelta a `/dashboard/mesas-sesiones` lleva la pestaña, la mesa (si
aplica) y el pedido como parámetros de ruta, y `TableSessionsComponent` los usa para seleccionar
lo correcto con los métodos que ya existían (`setOrderTypeTab`, `selectTable`, `selectOrder`,
`selectStandaloneOrder`) — sin convertir el store en singleton, para no mezclar un refactor no
pedido. Además, la clarificación de negocio de esta spec exige que la prevención de pedidos
duplicados por reintento de red (RN4) se resuelva también en el backend: se añade un campo
opcional `client_request_id` en `POST /orders` con deduplicación en el servicio de creación,
siguiendo el patrón ya usado por `invoices/service.py` (devolver el recurso existente en vez de
duplicarlo).

## Technical Context

**Language/Version**: TypeScript 5.x sobre Angular (standalone components, signals) en
`pos-heladeria`; Python 3.11 sobre FastAPI en `pos-backend`.

**Primary Dependencies**: Angular Router + `PosTerminalStore` (signals) en frontend;
SQLAlchemy + Alembic en backend. No se introduce ninguna dependencia nueva (Principio IX): todo el
cambio usa el stack ya presente en ambos repos.

**Storage**: PostgreSQL 16, schema-per-tenant (`Base.metadata = MetaData(schema="tenant")`,
`app/core/models.py:22-23`). Se añade una columna nullable + índice único parcial en
`customer_orders` (ver [data-model.md](./data-model.md)).

**Testing**: Vitest (`ng test`) para componentes/stores Angular (`*.component.spec.ts`,
`*.store.spec.ts`, con `provideHttpClientTesting()`); characterization tests basados en
`unittest` contra una base de datos real, sin mocks (`app/characterization_tests/`, ejecutados con
`python -m unittest app.characterization_tests.<módulo>`), siguiendo la convención ya usada en
`test_orders_checkout.py` / `test_orders_service.py`.

**Target Platform**: aplicación web de terminal POS (navegador de escritorio) sobre backend Linux.

**Project Type**: aplicación web con frontend y backend en repos independientes
(`../pos-heladeria` y `../pos-backend`, relativos a este repo de specs), ambos en producción.

**Performance Goals**: sin metas nuevas; la redirección debe sentirse instantánea, al mismo nivel
que la navegación ya existente en la terminal (sin llamadas adicionales: el pedido recién creado ya
está disponible en memoria al navegar).

**Constraints**: no debe alterar pedidos/facturas históricos (Principio VII) — la columna nueva es
nullable y no requiere backfill; el nuevo destino del botón de regreso no debe romper el acceso
actual a la vista de detalle desde "Órdenes"/admin (FR-010); sin dependencias nuevas (Principio IX).

**Scale/Scope**: cambio acotado a 2 componentes y 1 store en `pos-heladeria`, y 1 endpoint + 1
columna + 1 migración en `pos-backend`; no afecta volumen de datos ni concurrencia de forma
material.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| # | Principio | Evaluación |
|---|---|---|
| I | Nace de un spec | ✅ Spec [111](./spec.md) aprobada antes de este plan. |
| II | Comportamiento existente protegido | ✅ El cambio de navegación está autorizado explícitamente en la spec (sección "Autorización de negocio", reportado por el dueño del proyecto el 2026-10-11). Siguiendo el precedente de la spec [110](../110-liberar-mesa-sin-pedido/spec.md) — misma clase de corrección, mismo origen de autorización — no se requiere una entrada adicional en `registro-de-anomalias.md`; la autorización documentada dentro de la spec es consistente con cómo el proyecto ya trató esa corrección anterior. |
| III | Characterization tests protegidos | ⚠️ A verificar en implementación: si existe algún test `"CONGELA comportamiento actual:"` que cubra la navegación tras `confirm()` en `manual-order-page.component.ts` o el conteo de pedidos creados en `test_orders_checkout.py`/`test_orders_service.py`, su actualización debe citar esta spec explícitamente. |
| IV | Nuevos specs pueden introducir nuevo comportamiento | ✅ Aplica; la spec define el comportamiento nuevo (redirección + idempotencia). |
| V | Nuevas funcionalidades antes que refactors oportunistas | ✅ El plan NO convierte `PosTerminalStore` en singleton (aunque la causa raíz documenta que no serlo contribuye al bug): se propaga el estado necesario por query params, evitando un refactor de ciclo de vida no pedido por la spec. |
| VI | Evolución incremental | ✅ El cambio se mantiene en una sola unidad coherente: navegación + encabezado/back-link en frontend, y campo + deduplicación en backend; no se mezcla con otras clases de cambio. |
| VII | Compatibilidad con datos históricos | ✅ `client_request_id` es nullable, sin backfill; ningún pedido o factura histórico se recalcula ni se modifica. |
| VIII | Evolución del modelo de datos | ✅ Documentado en [data-model.md](./data-model.md): campo nuevo, compatibilidad, migración y rollback. |
| IX | Dependencias nuevas con justificación | ✅ No se añade ninguna dependencia nueva. |
| X | Verificación obligatoria | ✅ Se cubre con characterization tests existentes + tests nuevos de idempotencia (backend) y specs de Vitest nuevos/actualizados (frontend), más los criterios de aceptación de la spec. |
| XI | Decisiones de negocio vs técnicas | ✅ La spec (Clarifications) ya fijó las decisiones de negocio; este plan solo decide la técnica (query params, columna nueva, patrón de deduplicación). |
| XII | Trazabilidad | ✅ Necesidad (reporte del dueño) → Spec 111 → Clarifications → este plan → tasks/implementación/tests. |
| XIII | Español de Colombia | ✅ Este plan y los artefactos de diseño se escriben en español de Colombia. |
| XIV / XV | Ramas y commits | N/A en esta fase (se aplican al implementar, no al planear). |

Sin violaciones que requieran la tabla de Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/111-redireccion-detalle-pedido/
├── plan.md              # Este archivo
├── research.md          # Fase 0 — decisiones de diseño
├── data-model.md         # Fase 1 — modelo de datos afectado
├── quickstart.md         # Fase 1 — guía de validación manual
├── contracts/            # Fase 1 — contrato del endpoint y de la navegación
│   ├── post-orders.md
│   └── order-detail-navigation.md
└── tasks.md              # Fase 2 (/speckit-tasks) — no se crea en este comando
```

### Source Code (repos existentes, fuera de este repo de specs)

```text
../pos-backend/                                   # FastAPI + PostgreSQL 16, schema-per-tenant
├── app/
│   ├── api/v1/orders/
│   │   ├── router.py            # POST /orders → create_order() (línea 603)
│   │   ├── service.py           # create_order() (línea 448) — añade deduplicación por
│   │   │                        #   client_request_id antes del INSERT (líneas ~573-599)
│   │   └── schemas.py           # OrderCreate (líneas 125-148) — añade client_request_id opcional
│   ├── models/
│   │   └── customer_order.py    # CustomerOrder — añade columna client_request_id (nullable)
│   └── characterization_tests/
│       └── test_orders_service.py       # clase TestCreateOrderIdempotencia (nueva), tests
│                                         #   existentes de create_order sin cambios
└── alembic/versions/
    └── 30f5e7b0ef5f_111_idempotencia_creacion_pedidos.py   # migración aditiva (columna + índice único parcial)

../pos-heladeria/                                 # Angular standalone + signals
└── src/app/modules/tables/
    ├── pages/
    │   ├── manual-order-page.component.ts        # confirm(): navega a /dashboard/mesas-sesiones con
    │   │                                          #   queryParams { pestana, pedido, mesa? }
    │   ├── manual-order-page.component.spec.ts    # se extiende
    │   ├── table-sessions.component.ts             # ngOnInit lee pestana/mesa/pedido y selecciona
    │   └── table-sessions.component.spec.ts        # se extiende (describe nuevo)
    └── services/
        ├── pos-terminal.store.ts                   # createManualOrderFromDraft(): guarda defensiva
        │                                            #   (FR-006) + client_request_id (FR-011)
        └── pos-terminal.store.spec.ts               # se extiende

# order-detail.component.ts (ruta /dashboard/orders/:id) NO se toca — es la vista de solo lectura
# de "Órdenes"/admin, sin relación con este flujo (ver causa raíz corregida en spec.md).
```

**Structure Decision**: aplicación web ya existente con frontend (`pos-heladeria`) y backend
(`pos-backend`) en repos independientes, ambos en producción (Alcance del Proyecto, Constitución).
Esta corrección no introduce módulos ni proyectos nuevos: modifica archivos ya existentes en las
rutas listadas arriba, añadiendo únicamente una columna + una migración en el backend y ningún
archivo nuevo en el frontend salvo los `.spec.ts` que ya acompañan a cada archivo modificado.

## Complexity Tracking

*No aplica — el Constitution Check no registró violaciones que requieran justificación.*

## Constitution Check (re-evaluación post-diseño)

Tras completar [research.md](./research.md) y [data-model.md](./data-model.md)/`contracts/`, se
revisó nuevamente la tabla anterior: ninguna decisión de diseño introdujo una dependencia nueva, un
refactor no relacionado, ni una alteración de datos históricos. El único artefacto de datos nuevo
(`client_request_id`, nullable, con índice único parcial) queda documentado en data-model.md con su
estrategia de migración y rollback (Principio VIII), por lo que el Constitution Check **sigue en
verde** sin cambios respecto a la evaluación inicial.
