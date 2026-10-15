---

description: "Tareas de la spec 119 — reportes operativos por turno de caja (US1–US6)"
---

# Tasks: Reportes operativos por turno de caja

**Input**: Documentos de diseño de `/specs/119-reportes-ventas-turno/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: no se solicitó TDD explícito; se incluyen como characterization tests de
regresión (Principio III), añadidos junto a (no antes de) la implementación que verifican —
mismo patrón que specs 087/117/118 de este repo.

**Organization**: 6 historias de usuario (US1 P1, US2 P1, US3 P1, US4 P2, US5 P3, US6 P2) + 1 fase
bloqueante de registro de decisiones de negocio (FR-016, Principio II) antes de cualquier tarea de
código de producción.

**Ampliación US6 (2026-10-15)**: las fases 10 y 11 (T039–T074) se **añadieron** tras `/speckit-plan`
de la ampliación de rendimiento (FR-018 a FR-023, SC-008 a SC-010). T001–T038 conservan su
numeración y sus marcas `[X]` sin cambios; T036 (recorrido manual de US1–US5) sigue pendiente.
Para US6 los tests **sí** se piden de forma explícita (SC-008 y SC-009 son compuertas automáticas).

**Tras `/speckit-analyze` (2026-10-15)** se añadieron T075 (compuerta previa de commits de US1–US5,
**antes de T039**), T076 y T077 (pruebas de interfaz de US3 y US5, en la Fase 9 antes de T036) y se
ajustaron T031, T036, T039, T043, T051, T053, T057, T061, T068, T072 y T074. Los IDs nuevos no
renumeran los existentes. Ningún commit sin pedido explícito del usuario (Principio XV).

## Formato: `[ID] [P?] [Story] Descripción`

- **[P]**: puede ejecutarse en paralelo (archivos distintos, sin dependencias)
- **[Story]**: historia de usuario a la que pertenece la tarea (US1…US6)
- Cada tarea incluye la ruta exacta del archivo

## Convenciones de rutas

- `pos-backend`: `../pos-backend/app/...` (repo hermano de `pos-specs`)
- `pos-heladeria`: `../pos-heladeria/src/app/...` (repo hermano de `pos-specs`)
- `pos-specs`: `specs/000-reconocimiento/registro-de-anomalias.md` (FR-016, Principio II)

---

## Phase 1: Setup

**Propósito**: abrir las ramas de trabajo (Principio XIV). Sin inicialización de proyecto ni
dependencias nuevas (plan.md Technical Context: cero dependencias nuevas, Principio IX no aplica).

- [X] T001 [P] Crear, desde `develop`, la rama `feat/119-shift-sales-reports` en el repo
  `pos-backend` (`../pos-backend`)
- [X] T002 [P] Crear, desde `develop`, la rama `feat/119-shift-sales-reports` en el repo
  `pos-heladeria` (`../pos-heladeria`)

---

## Phase 2: Registro de decisiones de negocio (Principio II, FR-016) — BLOQUEANTE

**⚠️ CRÍTICO**: esta fase debe completarse antes de T005 (primera tarea de código de producción).
`spec.md` ("Contexto y comportamiento actual") y `plan.md` (Constitution Check, Principio II)
identifican dos cambios de comportamiento existente que deben quedar registrados como decisión de
negocio antes de implementarse. Confirmar el número vigente con
`grep -oE "^### A-[0-9]+" specs/000-reconocimiento/registro-de-anomalias.md | sort -t- -k2 -n | tail -1`
al momento de ejecutar (hoy sería A-127, por lo que las dos entradas nuevas serían **A-128** y
**A-129**).

- [X] T003 Registrar **A-128** en `specs/000-reconocimiento/registro-de-anomalias.md`, mismo
  formato `### A-128 — [DECISIÓN DE NEGOCIO — spec 119] ...` que A-126 (spec 117): **qué cambia**
  (la tarjeta "Ingresos hoy" del panel de administración deja de cortar por fecha calendario de
  cada venta individual — hoy `new Date(s.sold_at).toDateString() === today` en
  `admin-dashboard.component.ts` — y pasa a sumar los turnos cuya fecha de **apertura** cae en el
  día consultado, FR-005/FR-015); **por qué** (RN4 del planteamiento original: auditar con
  exactitud turnos que cruzan medianoche sin contaminar el reporte de dos días calendario); **quién
  y cuándo** (negocio, planteamiento original + sesión de Clarifications 2026-10-15); **funcionalidades
  afectadas** (únicamente la tarjeta de inicio del panel admin; `/dashboard/reports` no cambia, ver
  Assumptions de `spec.md`)
- [X] T004 Registrar **A-129** en `specs/000-reconocimiento/registro-de-anomalias.md`: **qué
  cambia** (cerrar un turno con pedidos activos sin cobrar pasa de estar permitido hoy a quedar
  bloqueado con `409`, FR-007/FR-008/FR-009 — nuevo comportamiento en
  `POST /cash/shifts/{id}/close`); **evidencia de código** (`specs/006-turnos-caja-arqueo`,
  `RN-CASH-01` a `RN-CASH-18`, ninguna bloquea hoy por pedidos activos; `close_shift` en
  `../pos-backend/app/api/v1/cash/router.py:101-135` no valida pedidos); **por qué** (RN5: evitar
  que dinero pendiente de cobro desaparezca del arqueo del turno en que ocurrió); **quién y cuándo**
  (negocio, sesión de Clarifications 2026-10-15); **funcionalidades afectadas** (`close_shift`,
  nuevo `GET /cash/active-orders`, flujo de cierre de turno en `pos-heladeria` — módulo
  `cash-register`)

---

## Phase 3: Foundational (Blocking Prerequisites)

**Propósito**: infraestructura que bloquea a TODAS las historias — el modelo/tabla de snapshot, la
función de cálculo compartida (en vivo y al cerrar, research.md D5), la consulta tenant-wide de
pedidos activos (research.md D1, reutilizada por US1/US3/US4) y los schemas/interfaces de
transporte.

**⚠️ CRÍTICO**: ninguna tarea de las fases 4-8 puede empezar hasta que esta fase esté completa.

- [X] T005 [P] Crear modelo `ShiftSalesReport` en NUEVO
  `../pos-backend/app/models/shift_sales_report.py` (data-model.md §2): tabla
  `shift_sales_reports`, schema `tenant`; columnas `id` (UUID PK), `cash_shift_id` (UUID NOT NULL,
  FK → `cash_shifts.id`, `ondelete="CASCADE"`), `total_sales` (`Numeric(12,2)`), `order_count`
  (`Integer`), `avg_ticket` (`Numeric(12,2)`), `products_breakdown` (`JSONB NOT NULL`),
  `categories_breakdown` (`JSONB NOT NULL`), `computed_at` (`DateTime, server_default=now()`);
  `UniqueConstraint("cash_shift_id", name="ux__shift_sales_reports__cash_shift_id")` y
  `CheckConstraint` de `total_sales/order_count/avg_ticket >= 0`
- [X] T006 Generar migración Alembic en NUEVA
  `../pos-backend/alembic/versions/<rev>_shift_sales_reports.py` (mismo patrón
  `@for_each_tenant_schema` que `f03274730367_presentations_y_reglas_por_presentacion.py`):
  `upgrade` hace `op.create_table("shift_sales_reports", ...)` + índice único sobre
  `cash_shift_id`; `downgrade` hace `op.drop_table("shift_sales_reports")`; sin backfill
  (data-model.md §4, research.md D8) — depende de T005
- [X] T007 [P] Crear función `list_active_orders(db) -> list[CustomerOrder]` en NUEVO
  `../pos-backend/app/api/v1/cash/active_orders.py` (research.md D1): consulta tenant-wide
  (sin filtrar por `cash_register_id` ni `CustomerOrder.cash_shift_id`),
  `CustomerOrder.status.in_(("recibida", "abierta", "bloqueada"))` — misma tupla
  `_NON_TERMINAL_ORDER_STATUSES` ya definida en `cart/service.py:82` y `orders/service.py:69` —,
  ordenada por `created_at` ascendente; devuelve también los campos para
  `ActiveOrderSummary` (`order_type`, `dining_table_id`, número de mesa vía join a
  `DiningTable.number`, `customer_name`, `created_at`)
- [X] T008 [P] Crear función `compute_shift_sales_report(db, shift) -> dict` en NUEVO
  `../pos-backend/app/api/v1/cash/reports.py` (research.md D5, data-model.md §2-3): replica el join
  `Sale → SaleItem → ProductVariant → Product → Category` de
  `app/api/v1/reports/service.py::products_report`/`categories_report`, filtrando por
  `Sale.cash_shift_id == shift.id, Sale.status == 'paid'` en vez de por rango de fechas; devuelve
  `total_sales`, `order_count`, `avg_ticket` (`0` si `order_count == 0`, FR-014), desglose
  **completo** (no top-N) de `products_breakdown`/`categories_breakdown` con
  `category_id=null, category_name="Sin categoría"` para líneas sin categoría; sin unidades
  vendidas → listas vacías, nunca error (US5/FR-014)
- [X] T009 Agregar schemas Pydantic nuevos en `../pos-backend/app/api/v1/cash/schemas.py`
  (contracts/shift-sales-report-api.md, contracts/active-orders-close-gate-api.md):
  `ProductBreakdownRow`, `CategoryBreakdownRow`, `ShiftSalesReportResponse` (incluye
  `is_live`, `active_orders_count: int | None`), `PeriodSalesReportResponse` (incluye `period`,
  `shift_ids`, `is_live`), `ActiveOrderSummary` — depende de T005/T008 (mismo shape de datos)
- [X] T010 [P] Crear interfaces TypeScript nuevas en NUEVO
  `../pos-heladeria/src/app/modules/dashboard/interfaces/shift-reports.interface.ts`
  (data-model.md §6): `ProductBreakdownRow`, `CategoryBreakdownRow`, `ShiftSalesReport`,
  `PeriodSalesReport`, `ActiveOrderSummary` — mismo shape que los schemas de T009, sin modificar
  `DiningOrder`/`Sale`/`CashShift` ya existentes
- [X] T011 Crear NUEVO `../pos-heladeria/src/app/modules/dashboard/services/shift-reports.service.ts`
  (esqueleto: `@Injectable({providedIn: 'root'})`, `HttpClient` inyectado,
  `baseUrl = `${environment.apiBaseUrl}/cash`` — mismo patrón que `CashService`) — depende de T010

**Checkpoint**: con esta fase completa, todas las historias de usuario pueden implementarse (en
paralelo si hay varios desarrolladores, o en el orden de prioridad P1→P1→P1→P2→P3 si es uno solo).

---

## Phase 4: User Story 1 - Reporte exacto de un turno que cruza la medianoche (Priority: P1) 🎯 MVP

**Goal**: el administrador consulta el reporte de un turno puntual (abierto o cerrado) y ve
ventas/órdenes/ticket promedio/top de productos/categorías calculados exclusivamente con las
órdenes pagadas dentro de ese turno, sin importar si cruza la medianoche.

**Independent Test**: abrir un turno a las 17:00, registrar ventas antes y después de la
medianoche, cerrarlo a las 02:00, y consultar `GET /cash/shifts/{id}/sales-report`.

### Tests para User Story 1

- [X] T012 [P] [US1] Characterization test en NUEVO
  `../pos-backend/app/characterization_tests/test_cash_shift_sales_report.py`: turno que abre a
  las 17:00, registra ventas antes y después de medianoche, cierra a las 02:00 →
  `total_sales`/`order_count`/`avg_ticket`/`top_products`/`categories` exactos solo con esas
  ventas (Acceptance Scenario 1); mismo resultado al filtrar además por `cash_register_id` de esa
  caja (Acceptance Scenario 2); tras cerrar, anular una de esas ventas y volver a consultar el
  reporte del mismo turno → debe devolver exactamente los mismos valores que antes de la anulación
  (FR-013/SC-003, snapshot inmutable, quickstart §6); un pedido creado bajo un turno ya cerrado y
  cobrado bajo el turno siguiente se atribuye al turno que registró el pago, no al turno vigente
  cuando se creó el pedido (FR-001/FR-002/RN1/RN2, research.md D3)

### Implementation para User Story 1

- [X] T013 [US1] Insertar en `close_shift` (`../pos-backend/app/api/v1/cash/router.py:130-135`,
  inmediatamente antes de `db.commit()`) la llamada a `compute_shift_sales_report` (T008) y la
  persistencia de la fila `ShiftSalesReport` dentro de la misma transacción de cierre (FR-013,
  research.md D2) — si el cómputo fallara, toda la transacción revierte (atomicidad) — depende de
  T006, T008
- [X] T014 [US1] Endpoint `GET /cash/shifts/{shift_id}/sales-report` en
  `../pos-backend/app/api/v1/cash/router.py` (`require_tenant_admin`): si `status == "closed"` y
  existe fila en `shift_sales_reports`, leerla (`is_live=false`); si está `open`, o `closed` sin
  fila (D8), llamar `compute_shift_sales_report` en vivo (`is_live=true`); `active_orders_count`
  (vía T007) solo cuando `status == "open"`, `null` en otro caso (FR-012) — depende de T007, T008,
  T009
- [X] T015 [US1] Método `getShiftSalesReport(shiftId)` en
  `../pos-heladeria/src/app/modules/dashboard/services/shift-reports.service.ts` — depende de T011
- [X] T016 [US1] Crear NUEVO subcomponente
  `../pos-heladeria/src/app/modules/dashboard/components/shift-sales-report-card.component.ts`:
  muestra el reporte de un turno elegido (lista de turnos recientes vía `CashService.listShifts`),
  reutilizando `StatTileComponent`/`RankedBarsChartComponent`/`ShareBarChartComponent` de
  `../../../shared/charts/*` (mismos componentes que ya usa `reports-page.component.ts`); se monta
  dentro de `admin-dashboard.component.ts` (selector "turno específico")

**Checkpoint**: el reporte de un turno individual (vivo o snapshot) es consultable de extremo a
extremo, de forma independiente del resto de historias.

---

## Phase 5: User Story 2 - Reporte "del día" libre de contaminación nocturna (Priority: P1)

**Goal**: el reporte "del día"/"semana"/"mes"/"rango" suma los turnos cuya fecha de **apertura**
(zona horaria del tenant) cae en el período consultado, nunca por la hora individual de cada
venta; reemplaza la tarjeta "Ingresos hoy" en la pantalla de inicio (FR-015).

**Independent Test**: con un turno abierto el día 12 a las 17:00 y cerrado el día 13 a las 02:00,
y otro turno abierto el día 13 a las 17:00, consultar el reporte del día 13 y verificar qué turnos
incluye.

### Tests para User Story 2

- [X] T017 [US2] Extender
  `../pos-backend/app/characterization_tests/test_cash_shift_sales_report.py`: reporte "del día"
  solo incluye el turno cuya fecha de apertura cae en el día consultado (Acceptance Scenario 1 de
  US2); agregación sin `cash_register_id` suma turnos de varias cajas (Acceptance Scenario 2);
  semana/mes/rango filtran por fecha operativa de apertura (Acceptance Scenario 3); agregación
  exacta por período recombinando el desglose completo de 2+ turnos con productos solapados
  (FR-017/SC-007, quickstart §8); aislamiento multi-tenant/por caja (SC-004, quickstart §7)

### Implementation para User Story 2

- [X] T018 [US2] Función `compute_period_sales_report(db, tenant, period, date_from, date_to,
  cash_register_id)` en `../pos-backend/app/api/v1/cash/reports.py`: resuelve el conjunto de
  `CashShift` cuya fecha operativa de `opened_at` (vía `resolve_timezone`/`local_day_bounds_utc` de
  `app/core/timezone.py`, mismo mecanismo que `reports/service.py`) cae en el período —
  `"week"`/`"month"` como semana/mes **calendario** (lunes a domingo / día 1 al último día del mes,
  research.md D4, confirmado con el usuario 2026-10-15), `"range"` con
  `date_from`/`date_to` explícitos —, opcionalmente filtrado por `cash_register_id`; para cada
  turno `closed` con fila en `shift_sales_reports` la lee tal cual, para `closed` sin fila u `open`
  llama a `compute_shift_sales_report` (T008); recombina sumando por
  `product_variant_id`/`category_id` antes de recortar el top-10 de productos (FR-017 — nunca sumar
  top-N ya recortados) — depende de T008
- [X] T019 [US2] Endpoint `GET /cash/reports/period` en
  `../pos-backend/app/api/v1/cash/router.py` (`require_tenant_admin`): query `period`
  (`day|week|month|range`, obligatorio), `date`, `date_from`/`date_to`, `cash_register_id?`;
  `422` si falta `date_from`/`date_to` con `period="range"` o `date_from > date_to`; `404` si
  `cash_register_id` no existe en el tenant — depende de T018, T009
- [X] T020 [US2] Método `getPeriodReport(params)` en
  `../pos-heladeria/src/app/modules/dashboard/services/shift-reports.service.ts` — depende de T011
- [X] T021 [US2] Reemplazar la tarjeta "Ingresos hoy" de `admin-dashboard.component.ts`
  (`../pos-heladeria/src/app/modules/dashboard/pages/admin-dashboard.component.ts:74-91`) por el
  reporte operativo por turno con selector de período (turno actual, turno específico, día,
  semana, mes, rango personalizado) y selector de caja opcional (FR-010/FR-015) — elimina
  `todaySales`/`todayRevenue`/`todayCount` (líneas 190-197) y el uso de `SalesService.sales()` para
  ese fin
- [X] T022 [US2] Campos de fecha para la opción "rango personalizado" en el selector de período del
  dashboard (research.md D4: sin precedente de UI a reutilizar, dos campos de fecha nuevos)

**Checkpoint**: la pantalla de inicio del panel de administración muestra el reporte por
turno/día/semana/mes/rango con selector de caja, reemplazando "Ingresos hoy" (SC-001, SC-005).

---

## Phase 6: User Story 3 - Cierre de turno bloqueado mientras existan pedidos activos (Priority: P1)

**Goal**: intentar cerrar un turno con pedidos activos (sin cobrar) queda bloqueado con `409`,
mostrando la lista de esos pedidos; solo cobrar o anular cada uno permite completar el cierre.

**Independent Test**: crear un pedido sin cobrar sobre un turno abierto e intentar cerrarlo; luego
cobrarlo o anularlo y repetir el cierre.

### Tests para User Story 3

- [X] T023 [P] [US3] Characterization test en NUEVO
  `../pos-backend/app/characterization_tests/test_cash_close_active_orders.py`: bloqueo de cierre
  con pedidos activos de los tres canales (`DINE_IN`, `TAKEAWAY`, `DELIVERY`, Acceptance Scenario 1
  de US3); cierre se completa tras cobrar/anular ambos (Acceptance Scenario 2); turno sin pedidos
  activos no muestra ningún bloqueo (Acceptance Scenario 3, comportamiento sin cambios respecto a
  `specs/006-turnos-caja-arqueo`); re-evaluación en un segundo intento tras que otro usuario
  resuelva un pedido entre dos llamadas (edge case de `spec.md`)

### Implementation para User Story 3

- [X] T024 [US3] Endpoint `GET /cash/active-orders` en
  `../pos-backend/app/api/v1/cash/router.py` (`get_current_user`, mismo nivel que `close_shift`):
  devuelve `list[ActiveOrderSummary]` vía `list_active_orders` (T007); `[]` cuando no hay ninguno —
  depende de T007, T009
- [X] T025 [US3] Insertar en `close_shift`
  (`../pos-backend/app/api/v1/cash/router.py:101-107`, entre la verificación de
  `shift.status == "closed"` y el cálculo de `counted`) la validación de pedidos activos vía
  `list_active_orders` (T007): si devuelve al menos uno, `409` con
  `{"detail": "...", "active_orders": [...]}` (contracts/active-orders-close-gate-api.md) y el
  cierre no continúa (ni arqueo, ni `close_note`, ni `shift_sales_reports`); el turno permanece
  `open` — depende de T007; nota: modifica la misma función que T013 pero un bloque distinto
  (inicio de la función vs. justo antes del commit) — revisar ambos diffs juntos antes de confirmar
  el archivo final
- [X] T026 [US3] Método `listActiveOrders()` en
  `../pos-heladeria/src/app/modules/dashboard/services/shift-reports.service.ts` — depende de T011
- [X] T027 [US3] Manejar la respuesta `409` con `active_orders` en
  `CashSessionStore.confirmarArqueoYCerrar()`
  (`../pos-heladeria/src/app/modules/cash-register/services/cash-session.store.ts:513-541`) y
  mostrar la lista bloqueante (canal, mesa/cliente, hora) en
  `CashArqueoModalComponent`
  (`../pos-heladeria/src/app/modules/cash-register/components/cash-arqueo-modal.component.ts`),
  con navegación hacia las pantallas de Mesas/Para llevar/Domicilios ya existentes para cobrar o
  anular — sin ninguna acción nueva de "cobrar"/"anular"/"transferir" (FR-008, Clarifications)

**Checkpoint**: ningún turno puede cerrarse con pedidos activos pendientes (SC-002), de forma
independiente de los reportes de US1/US2.

---

## Phase 7: User Story 4 - Reporte en tiempo real de un turno en curso (Priority: P2)

**Goal**: el reporte de un turno todavía abierto se calcula en vivo, se etiqueta "Turno en curso" y
muestra el número de pedidos activos pendientes; si se consulta "turno actual" sin filtrar por
caja y hay varias cajas abiertas, agrega todas en tiempo real.

**Independent Test**: abrir un turno, registrar ventas y dejar un pedido sin cobrar, y consultar su
reporte mientras sigue abierto.

### Tests para User Story 4

- [X] T028 [US4] Extender
  `../pos-backend/app/characterization_tests/test_cash_shift_sales_report.py`: turno abierto con
  ventas y un pedido activo → `status="open"`, `is_live=true`, `active_orders_count=1`, totales en
  vivo que reflejan una venta adicional registrada después (Acceptance Scenario 1 de US4); al
  cerrarse, el reporte deja de mostrar "en curso" y queda congelado con los valores del momento del
  cierre (Acceptance Scenario 2); `GET /cash/reports/current` sin `cash_register_id` agrega todos
  los turnos `open` del tenant (FR-012)

### Implementation para User Story 4

- [X] T029 [US4] Endpoint `GET /cash/reports/current` en
  `../pos-backend/app/api/v1/cash/router.py` (`require_tenant_admin`): con `cash_register_id`, si
  esa caja tiene turno abierto devuelve su reporte (mismo shape que `sales-report`), si no `404`
  "La caja no tiene un turno abierto"; sin `cash_register_id`, agrega en tiempo real todos los
  turnos `open` del tenant (`200` con totales en cero si no hay ninguno, nunca `404`) — depende de
  T007, T008, T009
- [X] T030 [US4] Método `getCurrentShiftReport(cashRegisterId?)` en
  `../pos-heladeria/src/app/modules/dashboard/services/shift-reports.service.ts` — depende de T011
- [X] T031 [US4] Opción "turno actual" en el selector de período del dashboard
  (`admin-dashboard.component.ts`): etiqueta visible "Turno en curso" y contador de pedidos activos
  cuando el reporte mostrado tiene `is_live=true`. El contador **no** viene en la respuesta del
  reporte de período: sale de `ShiftReportsService.listActiveOrders()` (longitud de la lista, todo el
  tenant, FR-012 y contrato) — depende de T021

**Checkpoint**: el administrador puede ver métricas acumuladas de un turno en curso sin esperar al
cierre (SC-005).

---

## Phase 8: User Story 5 - Reporte limpio para un turno sin ventas (Priority: P3)

**Goal**: un turno abierto y cerrado sin ninguna orden pagada muestra ventas/órdenes/ticket
promedio en `0` y el top de productos/categorías como estado vacío, sin errores.

**Independent Test**: abrir un turno y cerrarlo de inmediato sin registrar ninguna venta, y
consultar su reporte.

### Tests para User Story 5

- [X] T032 [US5] Extender
  `../pos-backend/app/characterization_tests/test_cash_shift_sales_report.py`: turno abierto y
  cerrado sin ninguna orden pagada → `total_sales="0.00"`, `order_count=0`, `avg_ticket="0.00"`,
  `top_products=[]`, `categories=[]`, sin excepción ni error `5xx` (FR-014, Acceptance Scenario 1
  de US5)

### Implementation para User Story 5

- [X] T033 [US5] Estado vacío claro (copy + ilustración/placeholder, sin "NaN" ni división visible
  por cero) para `top_products`/`categories` en la tarjeta de reporte del dashboard
  (`admin-dashboard.component.ts` o `shift-sales-report-card.component.ts` de T016) cuando ambas
  listas llegan vacías

**Checkpoint**: todas las historias de usuario (US1-US5) están implementadas y son verificables de
forma independiente.

---

## Phase 9: Polish & Cross-Cutting Concerns (US1–US5)

**Purpose**: cobertura de regresión del frontend, verificación manual end-to-end y trazabilidad.

- [X] T034 [P] Test unitario `admin-dashboard.component.spec.ts`
  (`../pos-heladeria/src/app/modules/dashboard/pages/admin-dashboard.component.spec.ts`): selector
  de período/caja, "Ingresos hoy" ya no usa `toDateString()` del navegador
- [X] T035 [P] Test unitario NUEVO
  `../pos-heladeria/src/app/modules/dashboard/services/shift-reports.service.spec.ts`: los 4
  métodos nuevos (`getShiftSalesReport`, `getPeriodReport`, `getCurrentShiftReport`,
  `listActiveOrders`) construyen la URL/params correctos
- [X] T076 [P] [US3] Tests de la interfaz de bloqueo de cierre (FR-008; hallazgo G1 de
  `/speckit-analyze`). (a) `../pos-heladeria/src/app/modules/cash-register/services/cash-session.store.spec.ts`,
  nuevo `describe` "cierre bloqueado por pedidos activos (spec 119)" con el patrón de `TestBed` del
  `describe` de `aperturaDisabled` (mock de `CashService` con `closeShift`, `getReport` y
  `extractError`; fijar `shift` y las denominaciones para que `arqueoDisabled()` sea `false`):
  un `HttpErrorResponse` 409 con `active_orders` plano → `activeOrdersBlocking()` queda con esa lista,
  `isSubmitting()` vuelve a `false`, `error()` tiene el mensaje y `screen()` no cambia; un 409 sin
  `active_orders` y un 500 → lista vacía y mensaje genérico ("No se pudo cerrar el turno."); un
  reintento exitoso tras un bloqueo → la lista se limpia y pasa a la pantalla de reporte. (b)
  `../pos-heladeria/src/app/modules/cash-register/components/cash-arqueo-modal.component.spec.ts`
  (hoy solo tiene el stub `activeOrdersBlocking: signal([])`): con 2 pedidos (uno `DINE_IN` y uno
  `TAKEAWAY`) renderiza "hay 2 pedido(s) activo(s)", 2 elementos de lista y enlaces
  `/dashboard/orders/<id>`; con lista vacía no renderiza el bloque ámbar. Cubre el código de T027
  (que no tenía prueba) — correr `npx ng test --watch=false` **solo**, nunca en paralelo con la suite
  del backend
- [X] T077 [P] [US5] Test del estado vacío de T033 (SC-006): con `top_products=[]` y `categories=[]`
  la tarjeta de reporte (`shift-sales-report-card.component.ts` y/o `admin-dashboard.component.ts`)
  muestra el estado vacío con su texto y ningún "NaN" ni "undefined"; ventas, órdenes y ticket
  promedio se muestran en `0`. Añadir el caso en `admin-dashboard.component.spec.ts` o en un spec
  nuevo de la tarjeta
- [X] T036 Ejecutar manualmente los 9 escenarios de [quickstart.md](./quickstart.md) (más §3b y §5b)
  contra `pos-backend` corriendo nativo con `uvicorn` (no Docker, ver memoria
  `reference_pos_api_docker_vs_nativo`) y `pos-heladeria` en el navegador — incluye US1-US5,
  inmutabilidad del snapshot (SC-003), aislamiento multi-tenant/caja (SC-004), agregación exacta
  por período (FR-017/SC-007), verificación visual en el panel de administración (FR-015), la
  **interfaz de bloqueo de cierre con 2 pedidos activos** (§3b, FR-008) y el **estado vacío** de un
  turno sin ventas (§5b, SC-006) — depende de T076 y T077
- [X] T037 Verificación de trazabilidad (Principio XII):
  `grep -n "A-128\|A-129" ../pos-backend/app/characterization_tests/test_cash_shift_sales_report.py
  ../pos-backend/app/characterization_tests/test_cash_close_active_orders.py` confirma que los
  tests nuevos citan las decisiones de negocio registradas en T003/T004; confirmar que
  `close_shift` (`router.py`) conserva intactas `RN-CASH-01` a `RN-CASH-17` de
  `specs/006-turnos-caja-arqueo` tras las dos inserciones de T013/T025
- [X] T038 `git status` en `pos-specs`, `../pos-backend` y `../pos-heladeria` — no commitear salvo
  que el usuario lo pida explícitamente (Principio XV)

---

## Phase 10: User Story 6 - Reportes de período rápidos sin importar cuántos turnos contienen (Priority: P2)

**Goal**: el reporte de un turno, de "turno actual" y de cualquier período se arma con un número
**fijo** de consultas (independiente de cuántos turnos incluye y de cuántos están con snapshot,
abiertos o cerrados sin snapshot, D8), con la recombinación y el top-N resueltos en la base de
datos, los índices adecuados creados sin bloquear cobros y el contador de pedidos activos obtenido
con `COUNT` — devolviendo exactamente los mismos valores que hoy (FR-018 a FR-023, SC-008 a SC-010).

**Independent Test**: comparar, para el mismo conjunto de datos, el reporte de un período con 1
turno y uno con 186 turnos (3 cajas × 2 turnos/día × 31 días): mismo número de consultas
(`test_cash_report_query_budget.py`) y mismos valores que la implementación anterior
(`test_cash_report_batch_identity.py` + los dos archivos de test existentes, sin modificar).

**Alcance y límites** (plan.md): solo `pos-backend` y `pos-specs`; **`pos-heladeria` no se toca**
(cero cambios de interfaz y de contrato HTTP). Rama: la ya creada `feat/119-shift-sales-reports`
(T001, Principio XIV). Principio II: US6 **no** añade una entrada nueva a `registro-de-anomalias.md`;
el orden de empates de FR-022 (decisión de negocio) quedó como adenda de A-128 (research.md D16). `test_cash_shift_sales_report.py` y `test_cash_close_active_orders.py` **no se
modifican** (SC-008). La superficie pública que esos tests invocan (`reports.compute_shift_sales_report`,
`reports.compute_period_sales_report`, `router.shift_sales_report`, `router.current_shift_report`,
`router.close_shift`) conserva firma, claves y tipos de salida.

**Orden de las unidades** (plan.md "Estrategia de entrega de US6"): 1 → 2; 3 después de 2 (ambas
tocan `shift_sales_report` en `router.py`); 4 después de 1 (la Rev. C continúa la cadena de la Rev.
B). La unidad 5 (volumen real) es la Fase 11. Cada unidad cierra con una tarea de verificación y se
puede commitear por separado.

**Portabilidad (plan.md, Constraints)**: el SQL de la aplicación debe correr igual en PostgreSQL y en
el SQLite de la suite — sin `jsonb_*`, `DISTINCT ON` ni `array_agg ... ORDER BY` en `app/`; solo las
migraciones son exclusivas de PostgreSQL.

### Compuerta previa (antes de tocar código)

- [X] T075 [US6] **Compuerta de commits de US1–US5 (Principios VI y XV; hallazgo C1 de
  `/speckit-analyze`)** — **debe resolverse antes de T039**: el código de US1–US5 sigue sin commit y
  comparte `router.py` y `reports.py` con US6; T046 y T054 lo reescriben, así que después ya no se
  podrá separar el historial por unidad. Preguntarle al usuario si quiere commitear US1–US5 en
  commits pequeños, en inglés y Conventional Commits, sin marca de IA —`pos-backend`: modelo + Rev. A
  → `active_orders` → `reports`/`schemas` → `router` → tests; `pos-heladeria`: interfaces/servicio →
  tarjeta → dashboard → bloqueo de cierre; `pos-specs`: A-128/A-129 y artefactos de la spec— o si
  acepta un historial mezclado. **No commitear nada sin su pedido explícito.** Anotar aquí la
  decisión: `[X]` commiteado por el usuario / `[ ]` acepta historial mezclado. Si se commitea,
  recalcular y registrar en T039 el hash de los dos tests (siguen siendo la línea base).
  **Decisión (2026-10-15)**: el usuario eligió commitear US1–US5 antes de US6. Hecho: `pos-backend`
  5 commits (`3d04b76` modelo + Rev. A → `f13fdfe` active_orders → `ae1f867` reports/schemas →
  `7428c92` router → `1554a4e` tests), `pos-heladeria` 4 commits (`c8f82ba` interfaces/servicio →
  `b962db1` tarjeta → `ad19de2` dashboard → `28a756f` bloqueo de cierre), `pos-specs` 2 commits
  (`55ee6df` A-128/A-129 → `981aff2` artefactos de la spec). Sin push

### Línea base (antes de tocar código)

- [X] T039 [US6] Fijar la línea base de SC-008: (a) con el entorno virtual de `../pos-backend`,
  ejecutar `python -m unittest app.characterization_tests.test_cash_shift_sales_report
  app.characterization_tests.test_cash_close_active_orders -v` y confirmar todo en verde; (b)
  registrar el `sha256sum` de ambos archivos de test. **Los dos están sin versionar, por lo que
  `git diff --stat` NO detectaría que se modificaron** (quickstart.md §10.1 ya se corrigió para
  comparar por hash): la comparación se hace por hash en T067, y sigue siendo válida si T075 termina
  en commit. Línea base calculada al generar
  estas tareas (2026-10-15):
  `test_cash_shift_sales_report.py` = `c0e956fc858c72ac32144aa6398ad321efa20992227b335e1c0d573d4ace3f8c`;
  `test_cash_close_active_orders.py` = `33b62b70a3efac5df9dac9f873f33e8f5a4fe2787ced3bb54c2886b844bdb621`.
  Si difieren por un cambio legítimo anterior a US6 (p. ej. algo corregido durante T036), recalcular
  y dejar aquí la constancia del valor nuevo — depende de T075

### Unidad 1 — Forma del dato (data-model.md §2 y §4, research.md D9/D14)

**Meta**: el snapshot de cada turno cerrado pasa de columnas `JSONB` a filas (cabecera + dos tablas
hijas), con su migración (Rev. B) reversible sin pérdida, y los tests existentes siguen en verde.

> **⚠️ Puente obligatorio (T046)**: al quitar el `JSONB` del modelo (T040), el `aggregate_shifts`
> actual deja de poder leer snapshots (`snapshot.products_breakdown` ya no existe) y los tests
> existentes —p. ej. el de snapshot inmutable— fallarían hasta que la Unidad 2 lo reescriba. Para que
> la Unidad 1 sea verificable y commiteable por sí sola, T046 adapta **solo** esa lectura; la Unidad 2
> reemplaza la función completa.

- [X] T040 [US6] Reescribir `../pos-backend/app/models/shift_sales_report.py` (data-model.md
  §2.1–2.3, research.md D9): (1) `ShiftSalesReport` conserva `cash_shift_id`, `total_sales`,
  `order_count`, `avg_ticket`, `computed_at`, el `UniqueConstraint` y los 3 `CheckConstraint` tal
  cual, y **pierde** `products_breakdown`/`categories_breakdown` (y el import de `JSONB`); (2) NUEVA
  clase `ShiftSalesReportProduct` (tabla `shift_sales_report_products`, schema `tenant`): `id`
  (mixin), `cash_shift_id` (`UUID NOT NULL`, FK a `cash_shifts.id`, `ondelete="CASCADE"`),
  `product_variant_id` (`UUID NOT NULL`, **sin FK**: un producto eliminado después sigue
  figurando), `name` (`String(255) NOT NULL`), `units` (`Integer NOT NULL`), `revenue`
  (`Numeric(14,2) NOT NULL`),
  `UniqueConstraint("cash_shift_id", "product_variant_id", name="ux__shift_sales_report_products__shift_variant")`
  y `CheckConstraint` de `units >= 0` y `revenue >= 0`; (3) NUEVA clase `ShiftSalesReportCategory`
  (tabla `shift_sales_report_categories`): `id`, `cash_shift_id` (igual que arriba), `category_id`
  (`UUID NULL`, **sin FK**; `NULL` = "Sin categoría"), `category_name` (`String(255) NOT NULL`),
  `units`, `revenue`, `Index("ix__shift_sales_report_categories__cash_shift_id", "cash_shift_id")`
  y los mismos `CheckConstraint`; **sin** `UNIQUE (cash_shift_id, category_id)` (en PostgreSQL
  `NULL` no cuenta como igual). Nombrar los `CheckConstraint` con el prefijo
  `ck_shift_sales_report_product_*` / `ck_shift_sales_report_category_*` (**en la implementación se
  usaron nombres cortos `units_nonneg`/`revenue_nonneg`**: con los largos la convención de nombres
  superaba los 63 caracteres de PostgreSQL y SQLAlchemy los truncaba con un hash), en la línea de los
  `ck_shift_sales_report_*` de la cabecera
- [X] T041 [US6] Registrar `ShiftSalesReportProduct` y `ShiftSalesReportCategory` en
  `../pos-backend/app/models/__init__.py` (línea 27, junto a `ShiftSalesReport`). Es obligatorio, no
  cosmético: los tenants nuevos se crean con `create_all` de los modelos (`app/core/db.py:100`,
  research.md D14 §4) y sin estas clases nacerían sin dónde guardar el snapshot — depende de T040
- [X] T042 [US6] Registrar las dos tablas hijas en `_ORDERS_TABLE_NAMES` de
  `../pos-backend/app/characterization_tests/orders_fixtures.py` (junto a `"shift_sales_reports"`,
  línea ~123) e importar las dos clases nuevas como ya se importa `ShiftSalesReport` (línea ~79).
  Es infraestructura de test, no una modificación de los tests existentes — depende de T040
- [X] T043 [P] [US6] Crear la **Revisión B** en NUEVO
  `../pos-backend/alembic/versions/<rev>_119_report_breakdown_rows.py` (`<rev>` = 12 hex nuevos;
  `down_revision = '2009eabd2e82'`, hoy la cabeza de la cadena; **no editar** la Rev. A: ya está
  aplicada en la base de desarrollo). **Transaccional**, `@for_each_tenant_schema`, con la guarda
  `_has_table(schema, "cash_shifts")` de la Rev. A. `upgrade` por esquema, cada paso **idempotente
  frente a un tenant ya en forma final** (research.md D14 §2): (1) crear las dos tablas hijas de
  T040 con sus constraints e índices solo si `to_regclass` dice que no existen; (2) rellenarlas
  desde las columnas `JSONB` de `shift_sales_reports` con `CROSS JOIN LATERAL
  jsonb_array_elements(...)` y `(e->>'campo')::tipo` — solo si esas columnas aún existen
  (`information_schema.columns`); (3) `drop_column` de `products_breakdown`/`categories_breakdown`
  solo si existen. `downgrade`: recrear las dos columnas `JSONB NOT NULL` (con valor temporal
  `'[]'`), **reconstruirlas** desde las filas con `jsonb_agg(jsonb_build_object(...))` en el mismo
  formato que escribía la Rev. A (`product_variant_id`, `name`, `units` como número, `revenue` como
  texto; `category_id` nulo como `null`) y solo entonces borrar las tablas hijas — sin pérdida. Los
  nombres de PK/FK/UNIQUE/índices deben coincidir con los de T040 (mismo patrón `op.f(...)` de la
  Rev. A). **Además, en la Rev. A** (`../pos-backend/alembic/versions/2009eabd2e82_119_shift_sales_reports.py`,
  hallazgo U1; research.md D14 §2): añadir en `upgrade`, justo después de la guarda de
  `cash_shifts`, `if _has_table(schema, "shift_sales_reports"): return`, para que un tenant que ya
  nació en forma final (creado por `create_all`) no haga fallar `alembic upgrade head` antes de B y
  C. Es el **único** cambio a la Rev. A (su estructura no se toca: ya está aplicada en la base de
  desarrollo). Se verifica con quickstart §10.8, paso 6 (T072)
- [X] T044 [US6] Añadir en `../pos-backend/app/api/v1/cash/reports.py` la función
  `persist_shift_snapshot(db, shift, data)` (`data` = salida de `compute_shift_sales_report`):
  agrega la cabecera `ShiftSalesReport` (`total_sales`, `order_count`, `avg_ticket`) y escribe el
  desglose COMPLETO con **una inserción masiva por tabla hija** (`db.execute(insert(ShiftSalesReportProduct), filas)`
  y la equivalente de categorías; omitir la sentencia si la lista viene vacía) — nunca `db.add` fila
  por fila, para que el número de `INSERT` no dependa de cuántos productos se vendieron
  (data-model.md §2.4, research.md D15). Convertir `product_variant_id`/`category_id` de `str` a
  `UUID` (`None` se conserva) y `revenue` a `Decimal`. No hace `commit` — depende de T040
- [X] T045 [US6] En `close_shift` (`../pos-backend/app/api/v1/cash/router.py:161-173`) reemplazar
  el `db.add(ShiftSalesReport(... products_breakdown=..., categories_breakdown=...))` por una
  llamada a `reports.persist_shift_snapshot(db, shift, report_data)` (T044), en la misma posición
  —justo antes del `db.commit()`, misma transacción— y retirar el import de `ShiftSalesReport`
  (línea 22) si queda sin uso. No tocar el bloque del 409 (T025) ni `RN-CASH-01`…`RN-CASH-17` —
  depende de T044
- [X] T046 [US6] **Puente temporal**: en `aggregate_shifts`
  (`../pos-backend/app/api/v1/cash/reports.py:121-133`) sustituir la lectura del `JSONB` por la
  lectura de las filas hijas del turno (hasta 2 consultas por turno cerrado con cabecera) y
  reconstruir `products_breakdown`/`categories_breakdown` con la **misma forma de antes**
  (`product_variant_id` y `category_id` como `str`, `units` entero, `revenue` como `str(Decimal)`),
  para que el resto de la función no cambie. Dejar un comentario `# PUENTE US6: lo reemplaza
  T054` — es deliberadamente ineficiente (sigue siendo N+1) y no es el diseño final — depende de
  T040
- [X] T047 [US6] Crear NUEVO `../pos-backend/app/characterization_tests/test_cash_report_batch_identity.py`
  (docstring con el estilo de `test_cash_shift_sales_report.py`: cita FR-013/FR-017/FR-022,
  research.md D9 y el comando para ejecutar solo el módulo) con su **propio** helper `_seed_sale`
  (copia del de `test_cash_shift_sales_report.py`; no importarlo: ese archivo no se toca) y la
  clase `TestSnapshotEnFilas`: (a) cerrar un turno con **12 productos distintos** (> `TOP_PRODUCTS_LIMIT`)
  deja 12 filas en `shift_sales_report_products` —desglose completo, no top-10— y 1 fila por
  categoría, con los mismos valores que `reports.compute_shift_sales_report`; (b) la cabecera
  guarda los totales y `ShiftSalesReport` ya no tiene atributos de desglose; (c) turno sin ventas →
  cabecera en cero y **cero** filas hijas; (d) insertar dos veces el mismo `(turno, variante)` viola
  `ux__shift_sales_report_products__shift_variant` (`IntegrityError`) — depende de T044, T045
- [X] T048 [US6] **Verificar la Unidad 1**: con el entorno virtual de `../pos-backend`, ejecutar
  `python -m unittest app.characterization_tests.test_cash_report_batch_identity
  app.characterization_tests.test_cash_shift_sales_report
  app.characterization_tests.test_cash_close_active_orders -v`. **Esperado**: todo en verde (los dos
  existentes pasan gracias al puente T046, sin modificarse) — depende de T041, T042, T045, T046, T047
- [X] T049 [US6] Validar el SQL de la Rev. B contra PostgreSQL real **sin dejar rastro**: en
  `psql` (contenedor `pos`, esquema `tenantlocal`, ver memoria `reference_pos_dev_db_psql_tenantlocal`)
  abrir `BEGIN;`, sembrar dentro de la transacción un turno con una cabecera cuyo `JSONB` tenga 2
  productos y 2 categorías (una con `category_id` nulo), ejecutar el SQL de *backfill* de T043 y
  comprobar que las filas hijas coinciden con el `JSONB`; ejecutar el SQL de reconstrucción del
  `downgrade` y comprobar que el `JSONB` resultante es idéntico (comparado como conjuntos); cerrar
  con `ROLLBACK;` — depende de T043
- [X] T050 [US6] Aplicar la Rev. B a la base de desarrollo desde `../pos-backend`
  (`alembic upgrade <rev_B>`, **no** `head` todavía: la Rev. C aún no existe) y comprobar con
  `alembic current` y `\d tenantlocal.shift_sales_report_products` que las tablas existen y que
  `shift_sales_reports` ya no tiene las columnas `JSONB`; probar `alembic downgrade 2009eabd2e82` y
  volver a subir. Sin esto, `pos-api` nativo falla al cerrar un turno con el modelo nuevo — depende
  de T043, T049

**Checkpoint (Unidad 1)**: el snapshot vive en filas, la Rev. B va y vuelve sin pérdida y la suite
de la spec sigue en verde. Todavía hay N+1: lo cierra la Unidad 2.

### Unidad 2 — Agregación en lote (research.md D10/D11, contracts/shift-sales-report-api.md)

**Meta**: `aggregate_shifts` se reescribe con **cuatro consultas fijas** (turnos, totales,
productos, categorías), con un *selector de turnos* repetido en cada una, `UNION ALL` de snapshot y
cálculo en vivo, y recombinación, nombre mostrado, orden y `LIMIT` resueltos en la base de datos.

- [X] T051 [P] [US6] Crear NUEVO `../pos-backend/app/characterization_tests/test_cash_report_query_budget.py`
  — compuerta automática de SC-009/FR-018 (research.md D15). Engancha `before_cursor_execute` (mismo
  patrón que `test_orders_billing_summary.py:504` y `test_orders_pagination.py:278`) y exige que el
  número de sentencias sea **igual** con un período pequeño y con 186 turnos, y no supere un techo
  fijo (anotar el valor medido) en `reports.compute_period_sales_report` y
  `router.current_shift_report`. Tres composiciones: (i) todos con snapshot (cerrados con
  `router.close_shift`; base de 1 turno); (ii) mezcla de con snapshot + abiertos + cerrados sin
  cabecera (D8), con una base de **3 turnos** (uno de cada tipo: una mezcla no puede existir con 1
  solo turno); (iii) todos sin snapshot (base de 1 turno). Para
  `router.shift_sales_report` (siempre un turno) comparar los tres estados (snapshot / abierto /
  D8) y un turno con 1 frente a otro con 80 productos. Casos adicionales: un período **sin turnos**
  ejecuta ≤ sentencias que uno con turnos; `router.close_shift` ejecuta el **mismo número de
  `INSERT`** con 1 y con 80 productos vendidos (este caso ya debe pasar tras la Unidad 1). Sembrar
  los 186 turnos con **186 cajas distintas** —el índice parcial `idx_open_shift_per_register` se
  vuelve UNIQUE total bajo SQLite (memoria `project_spec_119_implementado`) y no se remueve del
  metadata para no alterar otros tests— y los datos en bloque (`db.add_all`). **Ejecutarlo contra
  la implementación actual y confirmar que FALLA** (hoy hay hasta 4 consultas por turno): una
  compuerta que nunca se vio en rojo no prueba nada. Dejar como comentario los conteos antes/después
  (precedente: G9 de `test_orders_billing_summary.py`). **(d) Verificación de FR-019** (hallazgo G2):
  contar sentencias no basta —una implementación con cuatro consultas que agregue en Python también
  las cumpliría—, así que el mismo enganche captura el texto del SQL y exige que la sentencia de
  productos contenga `GROUP BY` y `LIMIT` y la de categorías `GROUP BY`; con 12 productos sembrados,
  `top_products` trae exactamente 10 — depende de T048
- [X] T052 [P] [US6] Ampliar `../pos-backend/app/characterization_tests/test_cash_report_batch_identity.py`
  (SC-008, FR-017, FR-022; el archivo ya lo creó T047, y es paralelizable con T051, que escribe otro
  archivo) con las clases: (a) el
  **ejemplo numérico del escenario 1 de US6**: Turno A cerrado con snapshot (Cono doble 10 u /
  $50.000 y Malteada 4 u / $36.000, 6 órdenes, total $86.000) y Turno B abierto (Cono doble 6 u /
  $30.000 y Paleta 20 u / $40.000, 4 órdenes, total $70.000) → total $156.000, 10 órdenes, ticket
  $15.600 y top Cono doble 16 u / $80.000 → Paleta 20 u / $40.000 → Malteada 4 u / $36.000; (b)
  nombre mostrado = el del turno **más antiguo** del período (misma variante con descripción
  distinta en dos turnos) y, dentro de un turno, el **mayor** valor de `description`; (c) orden en
  **empates exactos de ingreso**, sembrando de modo que el orden de inserción NO coincida con el
  orden esperado: nombre ascendente y, con el mismo nombre, `product_variant_id` ascendente; en
  categorías igual, con `category_id` nulo ("Sin categoría") **al final** (insertar esa fila
  directamente en `shift_sales_report_categories`, porque `Product.category_id` es `NOT NULL`);
  usar nombres con la misma capitalización (limitación de colación, research.md D11); (d) filas
  hijas **huérfanas** (sin cabecera) se ignoran; (e) ticket promedio *half-even*: `Decimal.quantize`
  y no `ROUND` de SQL (p. ej. dos ventas por $0,02 y $0,03 → promedio sobre $0,05 / 2); (f) un
  período que mezcla snapshot + abierto + D8 devuelve **lo mismo** que recalcular desde cero con una
  función oráculo del propio test escrita en Python puro sobre `Sale`/`SaleItem` (sin reutilizar
  código de `reports.py`), y `is_live`/`shift_ids` (orden `opened_at, id`) correctos en cada
  composición; (g) período sin turnos → totales en cero y listas vacías; (h) el filtro por
  `cash_register_id` nunca mezcla turnos de otra caja ni de otro tenant (SC-004). Cada turno en una
  caja distinta (límite SQLite de T051). Los casos de orden de (c) deben fallar contra el agregador
  actual — depende de T048
- [X] T053 [US6] En `../pos-backend/app/api/v1/cash/reports.py` extraer la **rama en vivo
  compartida** (research.md D10): una única definición de las consultas en vivo —ventas pagadas
  agrupadas por (turno, variante) y por (turno, categoría), con el `LEFT JOIN` a `Category` y
  "Sin categoría" cuando es nulo— parametrizada por una lista de condiciones sobre `cash_shifts`
  (el *selector de turnos*). Refactorizar `compute_shift_sales_report` para que use esa misma
  definición con el selector `CashShift.id == shift.id`, **conservando su firma y su forma de
  salida**: claves `total_sales` (`Decimal`), `order_count`, `avg_ticket` (`quantize(Decimal("0.01"))`
  en Python, `0.00` sin órdenes), `products_breakdown`/`categories_breakdown` con `product_variant_id`
  y `category_id` como `str` (o `None`), `units` entero y `revenue` como `str(Decimal)`. El cálculo
  del cierre y el de los turnos en vivo no pueden divergir. Los tests existentes lo invocan
  directamente — depende de T048 y de **haber visto en rojo** T051 y los casos de orden de T052
  (la reescritura no empieza hasta que las compuertas hayan fallado contra el código actual)
- [X] T054 [US6] Reescribir `aggregate_shifts` en `../pos-backend/app/api/v1/cash/reports.py`
  (reemplaza el puente de T046): deja de recibir `list[CashShift]` y recibe el selector de turnos
  (T053). **Cuatro consultas fijas**, cada una con el selector repetido (research.md D10, sin listas
  de ids en los parámetros): (1) turnos incluidos con `LEFT JOIN` a `ShiftSalesReport` → `shift_ids`
  (orden `opened_at, id`, como `UUID`) e `is_live` (algún turno sin cabecera); (2) totales: `UNION
  ALL` de la suma de cabeceras y la suma/cuenta de `Sale` pagadas de los turnos sin cabecera, sumados
  después en Python; (3) productos: `UNION ALL` de las filas de snapshot de los turnos con cabecera
  y el cálculo en vivo de los turnos sin cabecera, nombre mostrado con `ROW_NUMBER() OVER (PARTITION
  BY variante ORDER BY opened_at, shift_id)` y `MAX(CASE WHEN rn = 1 THEN name END)`, `GROUP BY`
  variante, `ORDER BY` ingreso descendente, nombre ascendente, `product_variant_id` ascendente y
  `LIMIT TOP_PRODUCTS_LIMIT`; (4) categorías: igual sin `LIMIT`, mismo criterio de nombre,
  `category_id` ascendente con `NULLS LAST` **explícito** (PostgreSQL y SQLite difieren por defecto).
  Con cero turnos puede omitir las consultas 2–4. `avg_ticket` en Python con `quantize` (no `ROUND`
  de SQL, research.md D11). Salida con la misma forma de antes (`shift_ids`, `is_live`, `total_sales`
  `Decimal`, `order_count`, `avg_ticket`, `top_products`, `categories` con `revenue` `Decimal`). Sin
  `jsonb_*`, `DISTINCT ON` ni `array_agg ... ORDER BY` — depende de T053
- [X] T055 [US6] Reemplazar `_shifts_for_period` por la construcción del selector de período en
  `../pos-backend/app/api/v1/cash/reports.py`: las mismas condiciones de hoy (`opened_at >= start`,
  `opened_at < end` con `resolve_timezone`/`local_day_bounds_utc`, más `cash_register_id` opcional;
  `reports.py:216-230`) pero devueltas como condiciones, no como lista de objetos; adaptar
  `compute_period_sales_report` (`reports.py:233-252`) para pasarlas a `aggregate_shifts` sin cambiar
  su firma ni las claves de su salida (`period`, `date_from`, `date_to`, `cash_register_id` + las del
  agregador) — depende de T054
- [X] T056 [US6] Adaptar los dos endpoints que llaman al agregador en
  `../pos-backend/app/api/v1/cash/router.py`: `shift_sales_report` (línea 187) usa el selector
  `CashShift.id == shift_id`; `current_shift_report` (líneas 223-238) usa `status == 'open'` más
  `cash_register_id` opcional. Mantener el `404 "La caja no tiene un turno abierto"` cuando se pide
  una caja sin turno abierto, y el `200` con ceros —nunca `404`— cuando no se filtra por caja y no hay
  turnos abiertos. Sin cambios de firma, de `response_model` ni de claves — depende de T054, T055
- [X] T057 [US6] **Verificar la Unidad 2**: en `../pos-backend`, ejecutar los cuatro módulos de
  `app/characterization_tests/` (`test_cash_report_query_budget.py`,
  `test_cash_report_batch_identity.py`, `test_cash_shift_sales_report.py`,
  `test_cash_close_active_orders.py`) con `python -m unittest app.characterization_tests.<módulo> ... -v`.
  **Esperado**: todo en verde; la
  compuerta de T051, que estaba en rojo, ahora pasa con un número de sentencias constante; los dos
  archivos existentes pasan sin modificarse — depende de T051, T052 y T056

**Checkpoint (Unidad 2)**: un reporte de 186 turnos ejecuta las mismas consultas que uno de 1 turno y
devuelve los mismos valores (SC-008, SC-009, FR-018/FR-019/FR-020/FR-022).

### Unidad 3 — Contadores de pedidos activos (research.md D12, contracts/active-orders-close-gate-api.md)

**Meta**: el contador de pedidos activos se obtiene con `COUNT` en la base de datos y la lista solo se
trae cuando hay que mostrarla. El resultado visible (contador, lista y su orden, cuerpo del 409) no
cambia. **No se crea ningún índice para esto**: `idx_active_order_per_participant` (spec 025) ya basta.

- [X] T058 [P] [US6] Añadir `count_active_orders(db) -> int` en
  `../pos-backend/app/api/v1/cash/active_orders.py`: `SELECT count(*)` sobre el **mismo predicado**
  que `list_active_orders` (`CustomerOrder.status.in_(_NON_TERMINAL_ORDER_STATUSES)`). Compartir el
  predicado en una sola definición para que contador y lista no puedan divergir
- [X] T059 [US6] En `close_shift` (`../pos-backend/app/api/v1/cash/router.py:118-132`) contar primero
  con `active_orders.count_active_orders(db)` y solo si es `> 0` traer la lista con
  `list_active_orders`; si entre el conteo y la lista el pedido se resolvió (lista vacía), el cierre
  continúa con el estado vigente (research.md D12). El cuerpo del `409` (texto con `len(active)`,
  `active_orders` plano) y su orden no cambian — depende de T058, T045
- [X] T060 [US6] En `shift_sales_report` (`../pos-backend/app/api/v1/cash/router.py:194-196`)
  calcular `active_orders_count` con `active_orders.count_active_orders(db)` en lugar de
  `len(active_orders.list_active_orders(db))`, manteniendo `None` cuando el turno no está `open`
  (FR-012) — depende de T058, T056 (misma función)
- [X] T061 [US6] Ampliar `../pos-backend/app/characterization_tests/test_cash_report_query_budget.py`
  (mismo archivo que T051) con: (a) `count_active_orders` coincide con `len(list_active_orders)`
  sobre un conjunto con pedidos activos de los tres canales (`DINE_IN`, `TAKEAWAY`, `DELIVERY`) y
  pedidos `pagada`/`cancelada` que no cuentan; (b) con **0** pedidos activos `close_shift` no invoca
  `list_active_orders` y con **> 0** lo invoca una sola vez (espiar con `unittest.mock.patch.object`);
  (c) `shift_sales_report` de un turno abierto ejecuta el mismo número de sentencias con 1 y con 50
  pedidos activos y devuelve el mismo `active_orders_count` que antes — depende de T051 (mismo
  archivo), T059 y T060
- [X] T062 [US6] **Verificar la Unidad 3**: en `../pos-backend`, ejecutar
  `app/characterization_tests/test_cash_report_query_budget.py`,
  `app/characterization_tests/test_cash_shift_sales_report.py` y
  `app/characterization_tests/test_cash_close_active_orders.py` con
  `python -m unittest app.characterization_tests.<módulo> -v`. **Esperado**: todo en verde y el
  segundo y el tercero sin modificarse — depende de T061

**Checkpoint (Unidad 3)**: FR-023 cumplido; el índice parcial de la spec 025 sigue sin tocarse.

### Unidad 4 — Índices sin bloquear escrituras (research.md D13/D14, FR-021)

**Meta**: dos índices nuevos sobre `cash_shifts` —solo esos dos; `sales(cash_shift_id)` y el parcial
de `customer_orders` ya bastan y un índice cubriente en `sales` se descartó por la medición— creados
con `CREATE INDEX CONCURRENTLY`, repetibles sin fallar y con reparación de índices inválidos.

- [X] T063 [P] [US6] Declarar los dos índices en `CashShift.__table_args__`
  (`../pos-backend/app/models/cash_shift.py:43-58`, antes del dict `{"schema": "tenant"}`):
  `Index("ix__cash_shifts__opened_at", "opened_at")` e
  `Index("ix__cash_shifts__register_opened_at", "cash_register_id", "opened_at")`. Los nombres deben
  ser **idénticos** a los de la Rev. C (T064): si no, un tenant nuevo (creado con `create_all`) y uno
  migrado tendrían nombres distintos y `IF NOT EXISTS` no los reconocería (research.md D14 §3). No
  tocar `idx_open_shift_per_register` ni el índice existente de `cash_register_id`
- [X] T064 [US6] Crear la **Revisión C** en NUEVO
  `../pos-backend/alembic/versions/<rev>_119_report_indexes.py` (`down_revision` = el id real de la
  Rev. B de T043; **no transaccional**; `@for_each_tenant_schema`; guarda `_has_table(schema,
  "cash_shifts")`). Por esquema y por cada uno de los dos índices, dentro de
  `op.get_context().autocommit_block()`: (1) consultar `pg_index.indisvalid` (unido a `pg_class` y
  `pg_namespace` por nombre y esquema) y, si el índice existe **inválido**, ejecutar `DROP INDEX
  CONCURRENTLY IF EXISTS`; (2) `CREATE INDEX CONCURRENTLY IF NOT EXISTS` con los nombres y columnas
  de T063. Citar los identificadores de esquema/índice con el *quoting* del dialecto. `downgrade`:
  `DROP INDEX CONCURRENTLY IF EXISTS` de ambos, también en `autocommit_block`. **Punto abierto de
  research.md D14**: `autocommit_block()` dentro del bucle de `for_each_tenant_schema` con
  `transaction_per_migration=True` (`alembic/env.py:99`) solo se puede ejercitar con la revisión
  escrita; si fallara, usar la alternativa de respaldo (conexión separada con
  `isolation_level="AUTOCOMMIT"`) y dejar el motivo anotado en el docstring — depende de T043
- [X] T065 [US6] Aplicar la Rev. C a la base de desarrollo (`alembic upgrade head` desde
  `../pos-backend`) y comprobar en `psql`, **por nombre de índice y esquema**, que ambos índices de
  `cash_shifts` existen con `indisvalid = true` en `tenantlocal` (y en `tenant_default` si tiene
  `cash_shifts`); luego `alembic downgrade -1 && alembic upgrade head` para confirmar que se puede
  ejecutar de nuevo sin errores. Nota: `CREATE INDEX CONCURRENTLY` **no** puede validarse dentro de
  `BEGIN…ROLLBACK`; la verificación con volumen y cobro concurrente es T071 — depende de T063, T064

**Checkpoint (Unidad 4)**: los dos índices existen y la migración es repetible. Falta medir su efecto
con volumen real (Fase 11).

---

## Phase 11: Polish & Verificación de US6 (Unidad 5 — SC-008 a SC-010)

**Purpose**: regresión completa del backend, verificación de que los tests existentes no se tocaron,
trazabilidad y la verificación manual con volumen real de `quickstart.md` §10 sobre un **tenant
desechable** (SC-010). Los umbrales de tiempo y el uso de índices no los cubre ningún test automático:
solo la compuerta de consultas (T051) lo es.

- [X] T066 Ejecutar la suite completa del backend **sola** (nunca en paralelo con la suite del
  frontend: la contención infla los fallos, memoria `reference_pos_suite_frontend_fallos_preexistentes`):
  `python -m unittest discover -s app/characterization_tests -p 'test_*.py'` en `../pos-backend`.
  **Esperado**: todo en verde; la línea base de la spec es de 1541 tests (memoria
  `project_spec_119_implementado`) más los nuevos de US6. Cualquier fallo se reporta con su salida,
  no se descarta como preexistente sin comprobarlo contra `git stash`/la rama base — depende de
  T057, T062, T065
- [X] T067 Comprobar SC-008 por hash: `sha256sum
  ../pos-backend/app/characterization_tests/test_cash_shift_sales_report.py
  ../pos-backend/app/characterization_tests/test_cash_close_active_orders.py` y comparar con los
  valores de T039. **Esperado**: idénticos (los dos archivos no se modificaron durante US6)
- [X] T068 Trazabilidad y portabilidad (Principio XII, plan.md Constraints): (a)
  `grep -nEi "jsonb_|distinct on|array_agg" ../pos-backend/app/api/v1/cash/*.py` debe **no devolver
  nada** (SQL de la aplicación portable); (b) `grep -n "FR-018\|FR-019\|FR-022\|FR-023\|SC-008\|SC-009"
  ../pos-backend/app/characterization_tests/test_cash_report_*.py` confirma que los tests nuevos
  citan los requisitos que verifican; (c) comprobar que los nombres de los dos índices coinciden
  letra por letra entre `app/models/cash_shift.py` y la Rev. C, y los de las tablas hijas entre
  `app/models/shift_sales_report.py` y la Rev. B; (d) confirmar que `app/api/v1/reports/*` y
  `pos-heladeria` no tienen cambios atribuibles a US6 (`git status`); (e) FR-019: `grep -n "setdefault"
  ../pos-backend/app/api/v1/cash/reports.py` **no debe devolver nada** (hoy da 2 resultados en
  `aggregate_shifts`, líneas 142 y 150: el desglose ya no se acumula en diccionarios del servidor)
- [X] T069 Verificación manual **quickstart.md §10.1–§10.5** (prerrequisito: `pos-api` nativo con
  `uvicorn`, no Docker — memoria `reference_pos_api_docker_vs_nativo`): crear el tenant desechable
  (`vol119`), sembrar el volumen con `quickstart-volume.sql`, y medir con `curl` (mediana de 5):
  186 turnos **sin snapshot** ≤ 2 s; 186 turnos **con snapshot** (`only_freeze=1`) ≤ 1 s con
  **exactamente los mismos** valores que sin snapshot; pedidos activos con 1.000.000 de históricos
  ≤ 200 ms con 6 pedidos en la lista, `active_orders_count = 6` y el `409` de cierre con 6 elementos.
  Anotar lo medido en la tabla "Registro de resultados" de `quickstart.md`. Si §10.3 incumpliera
  SC-010, reabrir la decisión del índice cubriente sobre `sales` (research.md D13) antes de seguir —
  depende de T066
- [X] T070 Verificación manual **quickstart.md §10.6** (planes de ejecución): capturar el SQL de las
  cuatro consultas del reporte y ejecutarlas con `EXPLAIN (ANALYZE, BUFFERS)` en el tenant
  desechable. **Esperado**: ningún `Seq Scan` sobre `sales`, `sale_items` ni `customer_orders`; el
  conteo y la lista de pedidos activos usan `idx_active_order_per_participant`; `cash_shifts` usa
  `ix__cash_shifts__opened_at` / `ix__cash_shifts__register_opened_at` (con `SET enable_seqscan = off`
  si el planificador prefiere recorrer una tabla pequeña); las tablas de snapshot se leen por
  `cash_shift_id`. Confirmar por **columnas** (no por nombre, varía por entorno) el índice de
  `sales (cash_shift_id)`. Si el `EXPLAIN` dejara de mostrar el índice de la spec 025, aplicar la
  contingencia de research.md D12 — depende de T069
- [X] T071 Verificación manual **quickstart.md §10.7** (FR-021, SC-010): con el tenant cargado,
  `alembic downgrade -1`, dejar un cobro repetido cada segundo y ejecutar `alembic upgrade head` en
  paralelo. **Esperado**: ningún cobro falla ni espera a la migración, ambos índices quedan con
  `indisvalid = t`, `downgrade -1 && upgrade head` termina sin errores, y un índice marcado inválido
  a propósito (`alembic stamp <rev_B>` + `upgrade head`) se detecta y se reconstruye. Si
  `autocommit_block()` fallara aquí, aplicar el respaldo de T064 — depende de T069
- [X] T072 Verificación manual **quickstart.md §10.8** (Principio VIII): calcular la huella de las
  filas de las dos tablas hijas, `alembic downgrade 2009eabd2e82`, comprobar que el `JSONB` se
  reconstruyó, `alembic upgrade head` y repetir la huella. **Esperado**: idéntica. Después, la
  idempotencia frente a la forma final: `alembic stamp 2009eabd2e82` + `upgrade head` sin errores ni
  filas duplicadas, huella igual (paso 5) y, para la guarda de la Rev. A añadida en T043,
  `alembic stamp 607ff811ddff` + `upgrade head` con el mismo resultado (paso 6, quickstart §10.8) —
  depende de T069
- [X] T073 Cerrar **quickstart.md §10.9**: eliminar el tenant desechable (flujo habitual de baja, o
  `DROP SCHEMA <ESQUEMA> CASCADE` y su fila en `shared.tenants`), confirmar que no queda nada con el
  prefijo `[119-vol]` en ningún esquema y completar la tabla "Registro de resultados" de
  `quickstart.md` con los valores medidos y su veredicto — depende de T070, T071, T072
- [X] T074 `git status` en `pos-specs` y `../pos-backend` — no commitear salvo que el usuario lo pida
  (Principio XV). Si lo pide: un commit pequeño por unidad (1 a 4), en inglés, Conventional
  Commits, **sin** atribución de IA (preferencia del usuario). **Aviso**: el código de US1–US5 aún no
  está commiteado y comparte archivos con US6 (`router.py`, `reports.py`); la decisión de commitearlo
  antes o de aceptar un historial mezclado es **T075**, que se resuelve antes de T039

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias — puede empezar de inmediato.
- **Registro de decisiones de negocio (Phase 2)**: sin dependencias de código; **bloquea** la Fase
  3 (Principio II — ninguna tarea de código de producción antes de T003/T004).
- **Foundational (Phase 3)**: depende de la Fase 2 — bloquea TODAS las historias de usuario.
- **Historias de usuario (Fases 4-8)**: todas dependen de la Fase 3. US1, US2 y US3 son P1 y pueden
  avanzar en paralelo entre sí (archivos mayormente distintos, salvo T013/T025 que tocan
  `close_shift` en bloques separados — ver nota de T025). US4 depende conceptualmente de que US1 ya
  exista (`compute_shift_sales_report` lo construye T008, pero el endpoint de "turno actual" es
  propio de US4) y de que el selector de período de US2 (T021) ya exista para añadir la opción
  "turno actual" (T031). US5 solo necesita T008 (ya cubre el caso de cero ventas) + una tarea de UI
  de estado vacío.
- **Polish (Phase 9)**: depende de que las historias deseadas estén completas. T076 y T077 (pruebas
  de interfaz de US3 y US5) van antes del recorrido manual T036.
- **US6 (Phase 10)**: **no depende de la Fase 3 ni de las historias de usuario 1–5 como trabajo
  pendiente** — todas están implementadas (solo falta T036); depende de su *código*, que reescribe
  (`cash/reports.py`, `close_shift`, `shift_sales_report`, `current_shift_report`). Se trabaja en la
  misma rama y los mismos repos. Orden interno por unidades: **1 → 2 → 3**, y **4 después de 1**
  (la Rev. C continúa la cadena de la Rev. B; independiente de 2 y 3 en archivos). La Unidad 3 va
  después de la 2 porque ambas tocan `shift_sales_report` en `router.py` (T056 → T060), y después de
  T045 porque ambas tocan `close_shift` (T045 → T059). **T075 (compuerta de commits de US1–US5)
  bloquea T039**, y por tanto todo US6: se resuelve con el usuario antes de tocar código.
- **Polish de US6 (Phase 11)**: T066–T068 dependen de las unidades 1–4 completas; T069–T073 (manuales,
  tenant desechable) dependen de T066 y se hacen en orden — T070/T071/T072 reutilizan el tenant
  sembrado en T069 y T073 lo elimina; T074 va al final.

### Dentro de cada historia

- Tests (si se incluyen) antes de o junto con la implementación que verifican.
- Backend antes que el método del servicio Angular que lo consume; servicio antes que el
  componente que lo usa.

### Parallel Opportunities

- T001/T002 (ramas) en paralelo.
- T005/T007/T008/T010 (Foundational, archivos nuevos distintos) en paralelo.
- T012 (test US1) en paralelo con el arranque de T023 (test US3, archivo distinto) una vez cerrada
  la Fase 3.
- T034/T035/T076/T077 (Polish, archivos distintos) en paralelo.
- **US6**: T043 (Rev. B, archivo nuevo) en paralelo con T040–T042 (modelo y fixtures); T051/T052
  (tests de presupuesto y de identidad, archivos distintos) en paralelo una vez cerrada la Unidad 1;
  T058 (`count_active_orders`, archivo propio) y T063 (índices del modelo, archivo propio) pueden
  avanzar mientras se reescribe el agregador, porque no tocan `reports.py` ni `router.py`.

---

## Parallel Example: Foundational (Phase 3)

```bash
# Backend, archivos nuevos independientes:
Task: "Crear modelo ShiftSalesReport en app/models/shift_sales_report.py"
Task: "Crear list_active_orders en app/api/v1/cash/active_orders.py"
Task: "Crear compute_shift_sales_report en app/api/v1/cash/reports.py"

# Frontend, archivo nuevo independiente:
Task: "Crear interfaces TypeScript en dashboard/interfaces/shift-reports.interface.ts"
```

## Parallel Example: US6 (Phase 10)

```bash
# Tras T040 (modelo): la migración no importa el modelo, puede escribirse a la vez
Task: "Crear Rev. B en alembic/versions/<rev>_119_report_breakdown_rows.py"      # T043
Task: "Registrar modelos hijos en app/models/__init__.py y fixtures"             # T041/T042

# Tras cerrar la Unidad 1 (T048): dos archivos de test distintos
Task: "Crear test_cash_report_query_budget.py (compuerta SC-009, en rojo primero)" # T051
Task: "Ampliar test_cash_report_batch_identity.py (identidad SC-008, FR-022)"      # T052

# Durante la reescritura del agregador (T053–T056), archivos que no tocan reports.py/router.py
Task: "Añadir count_active_orders en app/api/v1/cash/active_orders.py"          # T058
Task: "Declarar los dos índices en app/models/cash_shift.py"                    # T063
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Completar Fase 1 (Setup) + Fase 2 (registro de A-128/A-129, bloqueante) + Fase 3 (Foundational).
2. Completar Fase 4 (US1): reporte exacto de un turno individual, vivo o snapshot.
3. **Detener y validar**: ejecutar quickstart.md §1 y §6 (snapshot inmutable) de forma aislada.
4. US1 por sí sola ya demuestra el valor central del spec (atribución correcta por turno) aunque
   la UI del dashboard (US2) todavía no exista — verificable solo por API.

### Incremental Delivery

1. Setup + Decisiones de negocio + Foundational → base lista.
2. US1 → reporte de turno individual verificable por API.
3. US2 → reporte "del día"/semana/mes/rango en el dashboard, reemplaza "Ingresos hoy" (primer valor
   visible para el usuario final).
4. US3 → cierre de turno seguro (garantía operativa, independiente de los reportes).
5. US4 → visibilidad en tiempo real de un turno en curso (depende de que el selector de US2 ya
   exista).
6. US5 → pulido de caso borde (turno sin ventas) — bajo riesgo, última prioridad.
7. Polish → tests de regresión del frontend, recorrido manual completo, trazabilidad.
8. US6 → rendimiento sin cambio de comportamiento, en cuatro unidades verificables por separado
   (ver abajo) y una verificación final con volumen real (Fase 11).

### US6: estrategia de entrega (Principio VI)

US6 es una mejora de rendimiento sin cambio visible, así que **su MVP es la Unidad 2** (la compuerta
de consultas en verde con resultados idénticos); las demás reducen costo o riesgo operativo.

1. **Compuerta y línea base** (T075, T039): primero se resuelve con el usuario el commit de US1–US5;
   luego, tests existentes en verde y hash de los dos archivos que no se pueden tocar.
2. **Unidad 1 — forma del dato** (T040–T050): filas en lugar de `JSONB`, Rev. B reversible, puente
   temporal en el agregador. Se detiene aquí y se valida: tests existentes en verde, ida y vuelta de la
   Rev. B en `psql`.
3. **Unidad 2 — agregación en lote** (T051–T057): primero los tests (la compuerta debe verse en
   **rojo** contra el código actual), luego la reescritura. Se detiene aquí y se valida: 186 turnos =
   mismas consultas que 1 turno, mismos valores.
4. **Unidad 3 — contadores** (T058–T062) y **Unidad 4 — índices** (T063–T065): independientes entre
   sí; la 4 es la única con riesgo operativo (migración `CONCURRENTLY`), por eso su verificación real
   (T071) es con cobro concurrente sobre un tenant con volumen.
5. **Unidad 5 — volumen** (T069–T073): única forma de comprobar SC-010. Conviene hacerla con el stack
   ya levantado para cerrar de paso **T036** (recorrido manual de US1–US5).

**Riesgos conocidos** (plan.md): tenant creado por `create_all` entre el despliegue del código y
`alembic upgrade head` (guarda de idempotencia de las Rev. A, B y C; T043/T072); `autocommit_block()`
dentro del bucle de `for_each_tenant_schema`
(T064/T071, con respaldo documentado); colación del desempate por nombre entre PostgreSQL y SQLite
(los tests usan la misma capitalización, T052); acoplamiento al índice parcial de la spec 025
(`EXPLAIN` en T070, contingencia en research.md D12).

### Parallel Team Strategy

Con varios desarrolladores, tras completar Foundational:

- Desarrollador A: US1 (backend: snapshot + endpoint de turno individual) → luego US4 (depende de
  que el selector de US2 exista para la opción "turno actual").
- Desarrollador B: US2 (backend: agregación por período + reemplazo de "Ingresos hoy" en el
  dashboard).
- Desarrollador C: US3 (backend + frontend del bloqueo de cierre) — el único punto de coordinación
  real es revisar juntos el diff final de `close_shift` (T013 de A, T025 de C) antes de confirmar
  el archivo.
