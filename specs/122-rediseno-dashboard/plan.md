# Implementation Plan: Rediseño del módulo Dashboard según el prototipo

**Branch**: `122-rediseno-dashboard` | **Date**: 2026-10-16 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/122-rediseno-dashboard/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Reestructura visual completa del Dashboard (`admin-dashboard.component.ts`) hacia el diseño de referencia, en 5 historias independientes. Cuatro de ellas (saludo + reporte operativo en fila de 4 KPIs, tendencia reciente, más vendidos + ventas por categoría, stock bajo) se resuelven con datos **ya disponibles** hoy (`PeriodSalesReport`, `GET /reports/sales`, `InventoryService.loadLowStock()`) recombinados en componentes de gráfico **ya existentes y accesibles** (`BarsChartComponent`, `RankedBarsChartComponent`, `ShareBarChartComponent`). Dos piezas requieren backend nuevo, explícitamente autorizado en Clarifications: (1) exponer `User.name` en los claims de sesión (2 líneas en `auth/routes.py`, sin tocar ningún schema) para el saludo personalizado; (2) un endpoint nuevo `GET /cash/reports/payment-methods` que agrega `Payment.amount` por método y por intervalo de tiempo (hora/día/semana, según el período elegido), reutilizando toda la resolución de período/turno que ya usa la familia `/cash/reports/*` — sin tocar sus respuestas existentes. Al trazar la lógica real del prototipo (no solo su marcado) se corrigieron dos lecturas equivocadas de la primera versión del spec: el borde de las 4 tarjetas de KPI es un simple divisor gris, no un color por métrica; y el gráfico de "Estadísticas de ventas" es independiente del selector de período (tiene sus propias pestañas Ventas/Órdenes/Ticket promedio sobre una ventana fija de días recientes).

## Technical Context

**Language/Version**: TypeScript 5.x sobre Angular 21 (`pos-heladeria`, frontend) · Python 3.14 sobre FastAPI 0.136 (`pos-backend`, backend)

**Primary Dependencies**: Angular standalone components + Signals, Chart.js vía `ng2-charts` (ya integrado: `BarsChartComponent`, `RankedBarsChartComponent`, `ShareBarChartComponent`, `chart-theme.ts`), Tailwind CSS v4 — frontend. FastAPI, SQLAlchemy 2.x, Pydantic v2 — backend.

**Storage**: PostgreSQL 16, schema-per-tenant (sin migraciones: ningún campo nuevo se persiste — `name` ya existe en `User`; el endpoint de métodos de pago es una agregación de lectura sobre `Payment`/`Sale`/`CashShift` ya existentes).

**Testing**: `pos-backend`: `./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`. `pos-heladeria`: `npx ng test --watch=false [--include=...]` (Vitest vía `@angular/build:unit-test`).

**Target Platform**: Web — misma pantalla `/dashboard` ya servida hoy, escritorio y pantallas angostas (tablet/móvil, FR edge case).

**Project Type**: Web (frontend `pos-heladeria` + backend `pos-backend`, dos repos hermanos de `pos-specs`).

**Performance Goals**: El endpoint nuevo (`GET /cash/reports/payment-methods`) calcula siempre en vivo (los snapshots de turno cerrado no cubren esta dimensión, research.md §6) — una sola consulta agregada `GROUP BY bucket, payment_method_id` sobre los turnos del período resuelto, no una consulta por turno ni por día.

**Constraints**: No modificar `PeriodSalesReportResponse` ni `ShiftSalesReportResponse` (contratos ya en producción, FR-012) — el nuevo dato de métodos de pago va en un endpoint aparte. No modificar `StatTileComponent`, `ShareBarChartComponent`, `RankedBarsChartComponent`, `BarsChartComponent` (compartidos con otras pantallas/secciones) — se reutilizan tal cual. El saludo debe degradar sin error ante un JWT emitido antes de este cambio (sin `name` en claims).

**Scale/Scope**: 5 historias de usuario, 1 campo nuevo en claims de sesión, 1 endpoint nuevo de solo lectura (sin migración), reestructura de una sola plantilla (`admin-dashboard.component.ts`) reutilizando componentes de gráfico ya existentes — ningún componente de gráfico nuevo salvo el que renderiza el endpoint de métodos de pago (multiserie agrupado, no existe un componente así hoy).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Evaluación |
|---|---|
| I. Nace de un spec | ✅ `specs/122-rediseno-dashboard/spec.md`, con Clarifications resueltas (2 rondas) antes de este plan. |
| II. Comportamiento existente protegido | ✅ Explícitamente delimitado: `/cash/reports/current`, `/cash/reports/period`, `/cash/shifts/{id}/sales-report`, `/reports/sales`, `/inventory/items/low-stock` no cambian; `StatTileComponent`/`ShareBarChartComponent`/`RankedBarsChartComponent`/`BarsChartComponent` no cambian; las tarjetas "Usuarios"/"Productos" y "Órdenes recientes" se conservan (FR-009, decisión de negocio explícita en Clarifications). Único comportamiento nuevo: campo `name` aditivo en sesión, endpoint de solo lectura nuevo. |
| III. Characterization tests protegidos | ✅ Ningún test `"CONGELA comportamiento actual:"` se ve afectado: no se toca `aggregate_shifts`, `compute_period_sales_report`, ni los endpoints `/cash/reports/current`/`/period`/`/cash/shifts/{id}/sales-report` — solo se reutilizan sus funciones de resolución de período como lectura. |
| IV. Nuevo comportamiento vía spec | ✅ El campo `name` y el endpoint de métodos de pago son comportamiento nuevo, explícitamente autorizado en Clarifications, no una reinterpretación retroactiva. |
| V. No mezclar refactor oportunista | ✅ No se toca `StatTileComponent` ni ningún chart compartido "ya que se está ahí" — la fila de KPIs se construye inline en `admin-dashboard.component.ts` precisamente para no arrastrar ese riesgo (research.md §2). |
| VI. Evolución incremental | ✅ 5 historias independientemente testeables (spec.md), cada una verificable por separado; el trabajo de backend (2 piezas) está acotado y no se mezcla con migración de datos ni cambio de arquitectura. |
| VII. Compatibilidad con datos históricos | ✅ El endpoint nuevo es de solo lectura (`GROUP BY` sobre `Payment`/`Sale` ya existentes, sin escritura); `name` en la sesión no toca ninguna factura ni venta histórica. |
| VIII. Evolución del modelo de datos | ✅ N/A — sin columnas nuevas, sin migración (`User.name` ya existe; el endpoint nuevo no persiste nada). |
| IX. Dependencias nuevas | ✅ N/A — ninguna dependencia nueva; Chart.js/`ng2-charts` ya están integrados y se reutilizan. |
| X. Verificación obligatoria | ✅ Planificado: characterization tests existentes (backend) + tests nuevos del endpoint y del claim de sesión + tests de Angular para la plantilla reestructurada + criterios de aceptación del spec (quickstart.md). |
| XI. Negocio vs. técnico | ✅ Dos decisiones de negocio ya registradas en Clarifications (conservar contenido existente, autorizar backend nuevo para métodos de pago con fidelidad completa). Una decisión técnica documentada explícitamente en research.md §5 (reusar `ShareBarChartComponent` en vez de reconstruir un gráfico de área/línea) — surfaced para que el negocio pueda objetar si la fidelidad pixel a pixel de esa sección específica importa más que la legibilidad/accesibilidad ya lograda. |
| XII. Trazabilidad | ✅ Cadena completa: prompt de `/speckit-specify` → spec 122 → 2 rondas de Clarifications → este plan → (pendiente) tasks/implementación/tests. |
| XIII. Español de Colombia | ✅ Todos los artefactos de esta fase en español de Colombia; nombres de rama/commits quedan para la implementación, en inglés (Principios XIV/XV). |

**Gate (pre-Phase 0)**: PASA. No hay violaciones que registrar en Complexity Tracking.

**Gate (post-Phase 1, re-chequeado tras research.md/data-model.md/contracts/)**: PASA sin cambios. La única decisión que un lector debería poder objetar (reusar `ShareBarChartComponent` en vez de un gráfico de área/línea nuevo, research.md §5) quedó documentada explícitamente, no oculta; nada más en el diseño final introdujo dependencias, columnas o modificaciones a contratos protegidos más allá de lo ya evaluado arriba.

## Project Structure

### Documentation (this feature)

```text
specs/122-rediseno-dashboard/
├── plan.md                              # This file (/speckit-plan command output)
├── research.md                          # Phase 0 output (/speckit-plan command)
├── data-model.md                        # Phase 1 output (/speckit-plan command)
├── quickstart.md                        # Phase 1 output (/speckit-plan command)
├── contracts/
│   ├── payment-methods-report-api.md    # Phase 1 output (/speckit-plan command)
│   └── session-name-claim.md            # Phase 1 output (/speckit-plan command)
├── checklists/
│   └── requirements.md                  # /speckit-specify + /speckit-clarify output
└── tasks.md                             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

Dos repos hermanos de `pos-specs`, ya en producción — ninguna reestructuración de carpetas, solo archivos nuevos/modificados dentro de la organización por módulo ya existente.

```text
../pos-backend/
├── app/
│   └── api/v1/
│       ├── auth/
│       │   └── routes.py                  # +"name": user.name en los dos user_data (login, refresh)
│       └── cash/
│           ├── router.py                  # + GET /cash/reports/payment-methods
│           ├── reports.py                 # + función de agregación por método/bucket (reusa resolve_period_bounds/period_selector/shift_selector/open_shifts_selector)
│           └── schemas.py                 # + PaymentMethodBucketRow, PaymentMethodsReportResponse
└── app/characterization_tests/
    ├── test_auth_session_name_claim.py    # test nuevo: name en claims de login/refresh
    └── test_cash_reports_payment_methods.py  # test nuevo: endpoint, por período y pago dividido

../pos-heladeria/
├── src/app/core/
│   ├── auth/auth.models.ts                # BackendUser.name?: string
│   └── services/auth.service.ts           # buildUserFromBackend: preferir backend.name
└── src/app/modules/dashboard/
    ├── pages/
    │   └── admin-dashboard.component.ts   # reestructura: saludo, accesos rápidos reposicionados, fila de 4 KPIs, tendencia con pestañas, más vendidos con toggle, ingresos por método (nuevo), stock bajo (nuevo), Usuarios/Productos/Órdenes recientes conservados
    ├── interfaces/
    │   └── shift-reports.interface.ts     # + PaymentMethodBucketRow, PaymentMethodsReport
    ├── services/
    │   └── shift-reports.service.ts       # + getPaymentMethodsReport(...)
    └── components/
        └── payment-methods-chart.component.ts  # NUEVO: gráfico de barras agrupadas multiserie (no existe hoy un chart compartido así)
```

**Structure Decision**: Cambio acotado dentro de la organización por módulo que ya existe en ambos repos (`app/api/v1/cash/` y `app/api/v1/auth/` en el backend, `src/app/modules/dashboard/` en el frontend). No se crea ningún módulo nuevo ni dependencia nueva; el único componente de UI genuinamente nuevo es `payment-methods-chart.component.ts` (gráfico multiserie agrupado que no tiene equivalente reutilizable hoy — `ShareBarChartComponent` es apilado al 100%, no agrupado por categoría de tiempo). Todo lo demás reutiliza componentes y servicios ya existentes.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No aplica — el Constitution Check no registró violaciones. No se añade ninguna dependencia, proyecto, capa de abstracción ni columna de base de datos nueva.
