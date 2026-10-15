# Implementation Plan: Reportes operativos por turno de caja

**Branch**: `119-reportes-ventas-turno` | **Date**: 2026-10-15 | **Spec**: [spec.md](./spec.md)

**Última actualización**: 2026-10-15 — ampliación **US6** (FR-018 a FR-023, SC-008 a SC-010)

**Input**: Feature specification from `/specs/119-reportes-ventas-turno/spec.md`

## Summary

La spec tiene dos bloques de trabajo. **US1–US5** (reporte por turno, bloqueo de cierre, snapshot)
ya están implementadas en `pos-backend` y `pos-heladeria` (sin commit; solo falta el recorrido
manual T036). **US6** (rendimiento de los reportes de período) es lo que añade esta actualización
del plan. Ambos se resumen aquí.

### Alcance US1–US5 (implementado)

Investigación de código (no solo de la spec) confirmó que **la mitad del contrato ya existía**:
`Sale.cash_shift_id` (`app/models/sale.py`) es `NOT NULL` y se fija en `build_sale`
(`app/api/v1/sales/builder.py`) con el turno que `ensure_open_shift` valida como abierto **en el
instante del cobro** — nunca el vigente cuando se creó el pedido. RN1/RN2 (FR-001/FR-002) **ya eran
el comportamiento actual**; la spec solo construye el reporte que lee esa vinculación.

Lo que sí faltaba, y se construyó:

1. **Snapshot inmutable del cierre (FR-013)**: tabla `shift_sales_reports` (1:1 con `cash_shifts`),
   sin tocar `reconcile()` ni el arqueo de efectivo (research.md D2).
2. **Bloqueo de cierre por pedidos activos (FR-007)**: evalúa los pedidos activos de **todo el
   tenant**, porque el modelo no liga pedidos para llevar/domicilio a ninguna caja (research.md D1).
3. **Endpoints de reporte** bajo `/cash` (turno puntual, "turno actual", período, pedidos activos)
   sin tocar `/reports/*` (research.md D5).
4. **Selector de período/caja** en `admin-dashboard.component.ts` en lugar de "Ingresos hoy".

### Ampliación US6 — rendimiento sin cambio de comportamiento

**Diagnóstico** (research.md, "Ampliación US6"): `aggregate_shifts` recorre los turnos en Python y
lanza hasta 4 consultas por turno (≈ 745 para un mes de 186 turnos sin snapshot), acumulando el
desglose de cada turno en memoria; el contador de pedidos activos trae todas las filas para llamar
`len()`; `cash_shifts` no tiene índice por `opened_at`.

**Decisiones del plan** (todas con evidencia medida en PostgreSQL 16; ver research.md D9–D16):

1. **Desglose congelado en filas, no `JSONB`** (D9): dos tablas hijas
   `shift_sales_report_products` / `shift_sales_report_categories`; la cabecera conserva solo los
   totales. Es lo que permite resolver la recombinación en SQL **estándar**, ejercitable con la suite
   actual (SQLite en memoria) — requisito de SC-008.
2. **Cuatro consultas fijas por reporte** (D10), con un *selector de turnos* repetido en cada una:
   turnos incluidos, totales, top-N de productos y categorías; cada una une las filas de snapshot
   con el cálculo en vivo (turnos abiertos o D8) en un `UNION ALL`. Recombinación y `LIMIT` en la
   base de datos.
3. **Identidad con el resultado anterior** (D11): nombre mostrado = turno más antiguo (función de
   ventana), orden determinista (ingreso ↓, nombre ↑, id ↑, nulo al final), ticket promedio
   calculado en Python (el redondeo de SQL difiere en empates de medio centavo).
4. **Contadores en la base de datos** (D12): `COUNT` en lugar de traer filas; la lista solo si el
   contador es > 0.
5. **Índices** (D13): solo dos nuevos, sobre `cash_shifts` (`opened_at`; `cash_register_id, opened_at`).
   `sales(cash_shift_id)` y el índice parcial de `customer_orders` **ya bastan** (medido: 150 ms y
   0,02 ms) — no se pagan índices extra en el camino caliente del cobro.
6. **Dos revisiones de migración** (D14): **B** (transaccional: tablas hijas + backfill desde el
   `JSONB` + borrar el `JSONB`; con rollback sin pérdida) y **C** (no transaccional:
   `CREATE INDEX CONCURRENTLY IF NOT EXISTS` con detección y reparación de índices inválidos).
   Ambas idempotentes frente a tenants nuevos, que ya nacen en la forma final por `create_all`.
7. **Compuerta automática** (D15): un test que cuenta consultas (1 turno vs 186, tres composiciones).

**Resultado esperado medido en el diseño**: 186 turnos sin snapshot ≈ 0,15 s (umbral 2 s); con
snapshot ≈ 0,02 s (umbral 1 s); pedidos activos con 1.000.000 de históricos ≈ 0,02 ms (umbral 200 ms).

## Technical Context

**Language/Version**: Python 3.12 (`pos-backend`; el entorno local corre 3.14 vía `env/`, sin impacto
verificado). TypeScript 5.9 / Angular 21 (`pos-heladeria`) — **US6 no lo toca**.

**Primary Dependencies**: FastAPI 0.136, SQLAlchemy 2.0, Pydantic v2, Alembic 1.18 — sin dependencia
nueva (Principio IX: no aplica). US6 usa solo SQL estándar (`UNION ALL`, `GROUP BY`,
`ROW_NUMBER() OVER`), disponible en PostgreSQL 16 y en el SQLite 3.46 de la suite de tests.

**Storage**: PostgreSQL 16, esquema por tenant (`schema_translate_map`, sin columna `tenant_id`).
Cambios de esquema de la spec 119, en orden:

| Revisión | Contenido | Estado |
|---|---|---|
| A `2009eabd2e82` | Tabla `shift_sales_reports` con columnas `JSONB` | Existente; aplicada en la base local de desarrollo (0 filas); archivo sin versionar. **Su estructura no se modifica**; solo se le añade una guarda de idempotencia (omitir si `shift_sales_reports` ya existe, research.md D14 §2) para tenants ya en forma final. |
| B (nueva) | Tablas hijas del desglose + backfill + eliminar `JSONB` | US6, transaccional |
| C (nueva) | Índices `cash_shifts(opened_at)` y `cash_shifts(cash_register_id, opened_at)` | US6, `CONCURRENTLY` |

Ver [data-model.md](./data-model.md). Ninguna columna existente de `cash_shifts`, `sales`,
`sale_items`, `customer_orders` ni `cash_registers` cambia. Los tenants nuevos se crean con
`create_all` (`app/core/db.py`) y nacen en la forma final.

**Testing**: backend `python -m unittest discover -s app/characterization_tests -p 'test_*.py'`
(SQLite en memoria vía `fixtures.py::new_session`). Frontend `npx ng test --watch=false`. Guía manual
en [quickstart.md](./quickstart.md) (§1–9 US1–US5; §10 US6, con volumen real).

**Target Platform**: Linux server (`uvicorn` nativo — no Docker, ver memoria
`reference_pos_api_docker_vs_nativo`) + navegador.

**Project Type**: web — `pos-backend` + `pos-heladeria`; la spec vive en `pos-specs`.

**Performance Goals** (US6, SC-009/SC-010):
- Número de consultas de un reporte **fijo** e independiente de los turnos (compuerta automática).
- Verificación manual con volumen: 186 turnos sin snapshot ≤ 2 s; con snapshot ≤ 1 s; pedidos activos
  con 1.000.000 de históricos ≤ 200 ms; sin `Seq Scan` en `sales`/`sale_items`/`customer_orders`;
  migración de índices sin bloquear cobros.

**Constraints**:

- Principio VII: ningún `Sale`/`Invoice` ya emitido cambia de importe ni de representación. El
  snapshot se calcula **una sola vez**, al cerrar, y nunca se actualiza (FR-013, SC-003).
- El bloqueo de cierre (FR-007) es una validación **nueva** en `close_shift`; no reabre
  `RN-CASH-01`…`RN-CASH-17` de `specs/006-turnos-caja-arqueo`.
- FR-016 (Principio II): los dos cambios de comportamiento existente están registrados como **A-128**
  y **A-129** en `registro-de-anomalias.md` (T003/T004, hechas). US6 no añade una entrada nueva: el
  orden de empates de FR-022 (decisión de negocio) quedó como adenda de A-128 (research.md D16).
- `/dashboard/reports` y `app/api/v1/reports/*` quedan **sin ningún cambio**.
- **US6**: sin cambio de interfaz ni de contratos HTTP; los tests existentes de
  `test_cash_shift_sales_report.py` y `test_cash_close_active_orders.py` pasan **sin modificarse**
  (SC-008); la superficie pública que los tests invocan (`router.*`, `reports.compute_shift_sales_report`,
  `reports.compute_period_sales_report`) conserva firma, claves y tipos de salida.
- **US6**: el mismo SQL debe correr en PostgreSQL y en SQLite — sin `jsonb_*`, `DISTINCT ON` ni
  `array_agg ... ORDER BY` en el código de la aplicación (las migraciones sí son solo PostgreSQL).
- **US6**: el índice parcial de `customer_orders` que respalda "pedidos activos" pertenece a la spec
  025; cualquier cambio futuro sobre él debe revisar este plan (contingencia en research.md D12).

**Scale/Scope**:

- `pos-backend` (US6): `app/models/shift_sales_report.py` (cabecera sin `JSONB` + 2 clases hijas),
  `app/models/cash_shift.py` (+2 `Index`), `app/models/__init__.py`; 2 revisiones Alembic;
  `app/api/v1/cash/reports.py` (agregación en lote con una definición compartida de la rama en vivo;
  escritura del snapshot en filas); `app/api/v1/cash/active_orders.py` (+`count_active_orders`);
  `app/api/v1/cash/router.py` (`close_shift` y los endpoints usan lo anterior);
  `characterization_tests/orders_fixtures.py` (+2 tablas); 2 archivos de test nuevos.
- `pos-heladeria`: **sin cambios por US6**.
- `pos-specs`: este directorio (incluye `quickstart-volume.sql`, validado contra la base real).
- 6 historias (P1×3, P2×2, P3×1); 16 decisiones de investigación (D1–D16); 23 FR y 10 SC.

## Constitution Check

*GATE: debe pasar antes de la Fase 0. Re-evaluado tras la Fase 1 al final de esta sección.*

| Principio | Evaluación |
|---|---|
| I. Las Nuevas Funcionalidades Nacen de un Spec | ✅ Pass — `spec.md` con 3 sesiones de clarificación (19 preguntas resueltas; la segunda, de la ampliación US6, y la tercera, del análisis de consistencia), 23 FR, 10 SC, checklist de calidad en verde. |
| II. El Comportamiento Existente Sigue Protegido | ✅ Pass — A-128 y A-129 ya registradas (FR-016). US6 no cambia comportamiento existente: los endpoints de reporte no existen en producción (código sin versionar; migración A solo en la base local) y FR-022 acota la única diferencia visible, el orden en empates exactos, antes accidental; al ser decisión de negocio queda registrada como adenda de A-128 (research.md D16). |
| III. Los Characterization Tests Protegen el Comportamiento Heredado | ✅ Pass — ningún test `"CONGELA comportamiento actual:"` toca este código (D6). US6 **no modifica** los dos archivos de test existentes de la spec; añade dos nuevos. |
| IV. Los Nuevos Specs Pueden Introducir Nuevo Comportamiento | ✅ Pass — éxito = SC-001…SC-010. |
| V. Nuevas Funcionalidades Antes que Refactorizaciones Oportunistas | ✅ Pass — la reescritura del agregador es el objeto explícito de US6 (FR-018…FR-023), no una refactorización oportunista. A-17 (`with_for_update()` en `close_shift`) sigue fuera de alcance (D7). El índice de la spec 025 no se toca. |
| VI. Evolución Incremental | ✅ Pass — US6 se divide en 5 unidades verificables por separado (ver "Estrategia de entrega de US6"); forma del dato y rendimiento de índices van en revisiones distintas, con requisitos de transacción opuestos. |
| VII. Compatibilidad con Datos Históricos | ✅ Pass — ninguna `Sale`/`Invoice` se recalcula. Los turnos cerrados antes de la spec siguen sin snapshot ni backfill (D8) y ahora se calculan en lote (FR-020). El backfill de la Rev. B solo reorganiza el snapshot de esta misma spec; no toca datos de negocio. |
| VIII. Evolución del Modelo de Datos | ✅ Pass — [data-model.md](./data-model.md) §2 y §4 especifican entidades nuevas, valores por defecto, compatibilidad, estrategia de migración y **rollback sin pérdida validado** (JSONB → filas → JSONB idéntico) de cada revisión; idempotencia frente a tenants nuevos. |
| IX. Dependencias Nuevas Permitidas con Justificación | ✅ Pass (no aplica) — cero dependencias nuevas. |
| X. Verificación Obligatoria | ✅ Pass (planificado) — compuerta automática de consultas (SC-009), pruebas de identidad (SC-008), tests existentes sin modificar, y verificación manual con volumen real en [quickstart.md](./quickstart.md) §10 (SC-010). Los planes de ejecución y SQL ya se contrastaron en PostgreSQL durante la investigación. |
| XI. Decisiones de Negocio Frente a Decisiones Técnicas | ✅ Pass — el negocio ya cerró las decisiones de US6 (orden de empates, alcance del snapshot, sin tope de rango, creación de índices sin bloqueo, mejor esfuerzo en la carrera de cierre). Las que toma este plan son técnicas y están marcadas como tales: forma de almacenamiento (D9), extender a categorías el criterio de nombre mostrado (D11), qué índices crear y cuáles no (D13). |
| XII. Trazabilidad | ✅ Pass — Necesidad → spec + clarificaciones → este plan → research (D1–D16) / data-model / contracts / quickstart → `tasks.md` → tests → verificación (quickstart §10). |
| XIII. Todo en Español de Colombia | ✅ Pass — artefactos en español de Colombia; identificadores de código en inglés. |
| XIV. Estrategia y Convención de Ramas | ✅ Pass — US6 continúa en la rama ya creada `feat/119-shift-sales-reports` de `pos-backend` (misma spec); `pos-heladeria` no se toca. |
| XV. Política de Commits | ✅ Pass (planificado) — commits pequeños por unidad (una por cada unidad de entrega de US6), en inglés, Conventional Commits, sin marca de IA, solo cuando el usuario lo pida. |

**Complexity Tracking**: sin violaciones de diseño que justificar. US6 añade 2 tablas hijas y 2
índices —proporcionales a los 6 FR nuevos— y **retira** una decisión anterior (el `JSONB`) en vez de
mantener dos formas de almacenamiento. Se descartó explícitamente añadir índices que la medición no
justifica.

**Re-chequeo post Fase 1**: el diseño de la Fase 1 ([data-model.md](./data-model.md),
[contracts/](./contracts/), [quickstart.md](./quickstart.md)) confirma que no cambia ningún contrato
HTTP ni ninguna interfaz, que cada revisión tiene rollback validado y que el SQL de agregación es
portable. Ningún gate cambia de veredicto. Hallazgo de la Fase 1 que condiciona la implementación:
los tenants nuevos nacen por `create_all`, así que el modelo final es obligatorio y las revisiones
deben ser idempotentes (research.md D14).

## Project Structure

### Documentation (this feature)

```text
specs/119-reportes-ventas-turno/
├── plan.md                  # Este archivo (/speckit-plan)
├── research.md              # Fase 0 — D1–D8 (spec original) + D9–D16 (US6, con evidencia medida)
├── data-model.md            # Fase 1 — cabecera + 2 tablas hijas, lectura en lote, revisiones A/B/C
├── quickstart.md            # Fase 1 — §1–9 US1–US5, §10 US6 (volumen, planes, índices, migraciones)
├── quickstart-volume.sql    # Fase 1 — siembra de volumen para §10 (validada contra la base real)
├── contracts/               # Fase 1 — sin cambio de forma; notas de orden y presupuesto de consultas
│   ├── shift-sales-report-api.md
│   └── active-orders-close-gate-api.md
├── checklists/requirements.md
└── tasks.md                 # Fase 2 (/speckit-tasks) — se amplía con las tareas de US6
```

### Source Code (repository root)

```text
../pos-backend/
├── app/
│   ├── models/
│   │   ├── shift_sales_report.py       # MODIFICA (US6) — cabecera sin JSONB;
│   │   │                                #   + ShiftSalesReportProduct, + ShiftSalesReportCategory
│   │   ├── cash_shift.py               # MODIFICA (US6) — + Index opened_at, + Index (register, opened_at)
│   │   └── __init__.py                 # MODIFICA (US6) — registra las dos clases hijas
│   ├── api/v1/cash/
│   │   ├── reports.py                  # REESCRIBE aggregate_shifts (US6): 4 consultas fijas,
│   │   │                                #   selector de turnos, UNION ALL snapshot + en vivo,
│   │   │                                #   definición única de la rama en vivo (la usa también
│   │   │                                #   compute_shift_sales_report); + escritura del snapshot
│   │   ├── active_orders.py            # + count_active_orders (US6, FR-023)
│   │   ├── router.py                   # close_shift: cuenta antes de listar; escribe cabecera + filas;
│   │   │                                #   shift_sales_report: usa el conteo; endpoints llaman al
│   │   │                                #   agregador con selector
│   │   └── schemas.py                  # sin cambio (los contratos no cambian)
│   └── characterization_tests/
│       ├── orders_fixtures.py          # + 2 tablas en _ORDERS_TABLE_NAMES (infraestructura)
│       ├── test_cash_shift_sales_report.py     # EXISTENTE — no se modifica (SC-008)
│       ├── test_cash_close_active_orders.py    # EXISTENTE — no se modifica
│       ├── test_cash_report_query_budget.py    # NUEVO (US6) — SC-009
│       └── test_cash_report_batch_identity.py  # NUEVO (US6) — SC-008, FR-017, FR-022
├── alembic/versions/
│   ├── 2009eabd2e82_119_shift_sales_reports.py # Rev. A — existente; solo se añade la guarda de idempotencia
│   ├── <rev>_119_report_breakdown_rows.py      # Rev. B — NUEVA (US6)
│   └── <rev>_119_report_indexes.py             # Rev. C — NUEVA (US6)
│
../pos-heladeria/                       # sin cambios por US6
```

**Structure Decision**: web — dos repositorios de código consumidos por la spec en `pos-specs`, igual
que las specs 073/089/117/118. US6 no añade proyecto, servicio ni capa: reescribe por dentro el
módulo `cash/reports.py` ya existente y cambia la forma de almacenar el snapshot, manteniendo
intacta la superficie pública que usan los tests y el frontend.

## Estrategia de entrega de US6 (unidades verificables, Principio VI)

Cada unidad se puede verificar y commitear por separado. Dependencias: 1 → 2; 3 y 4 son
independientes entre sí; 4 va después de 1 porque la Rev. C continúa la cadena de la Rev. B; 5 al
final.

| # | Unidad | Qué entrega | Cómo se verifica |
|---|---|---|---|
| 1 | **Forma del dato** | Modelos hijos + cabecera sin `JSONB` + Rev. B + escritura de filas en `close_shift` + fixtures | Tests: filas escritas al cerrar y coherentes con el cálculo en vivo; ida y vuelta de la Rev. B (quickstart §10.8) |
| 2 | **Agregación en lote** | `aggregate_shifts` reescrito (D10/D11) y endpoints con selector | Tests existentes sin modificar (SC-008) + `test_cash_report_batch_identity` + `test_cash_report_query_budget` (SC-009) |
| 3 | **Contadores** | `count_active_orders`; `close_shift` y `shift_sales_report` lo usan (D12) | Tests existentes de cierre sin modificar + conteo de sentencias; quickstart §10.5 |
| 4 | **Índices** | `Index` en `CashShift` + Rev. C `CONCURRENTLY` (D13/D14) | Quickstart §10.6 y §10.7 (planes, cobros en paralelo, índices válidos, reparación) |
| 5 | **Verificación de volumen** | Resultados de SC-010 | Quickstart §10 con `quickstart-volume.sql`, sobre un tenant desechable |

**Compuerta previa a la Unidad 1 (T075, Principios VI y XV)**: el código de US1–US5 sigue sin commit
y comparte `router.py` y `reports.py` con US6; la Unidad 1 y la 2 lo reescriben. Antes de empezar se
le pregunta al usuario si quiere commitear US1–US5 en commits pequeños (nunca sin pedido explícito) o
si acepta un historial mezclado; la decisión queda anotada en T075.

**Riesgos conocidos y cómo se cierran**:
- Tenant creado por `create_all` entre el despliegue del código y `alembic upgrade head` → las tres
  revisiones (A, B y C) son idempotentes frente a la forma final; la verificación es quickstart §10.8,
  paso 6 (research.md D14 §2).
- `autocommit_block()` dentro del bucle de `for_each_tenant_schema` con `transaction_per_migration=True`
  no se puede ejercitar hasta tener la Rev. C → quickstart §10.7 (respaldo: conexión separada con
  `AUTOCOMMIT`, research.md D14).
- Colación en el desempate por nombre (PostgreSQL vs SQLite) → los tests usan nombres con la misma
  capitalización; limitación documentada en research.md D11.
- Acoplamiento al índice parcial de la spec 025 → `EXPLAIN` en quickstart §10.6 y contingencia ya
  probada en research.md D12.
