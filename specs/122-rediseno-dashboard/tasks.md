---

description: "Task list template for feature implementation"
---

# Tasks: Rediseño del módulo Dashboard según el prototipo

**Input**: Design documents from `/specs/122-rediseno-dashboard/`

**Prerequisites**: [plan.md](plan.md) (required), [spec.md](spec.md) (required for user stories), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: Incluidos. La constitución del proyecto (Principio X, Verificación Obligatoria) exige verificar toda nueva funcionalidad con tests; el endpoint nuevo (`GET /cash/reports/payment-methods`) y el claim de sesión nuevo también quedan protegidos por characterization tests desde que nacen, igual que el resto de `pos-backend`.

**Organization**: Tareas agrupadas por historia de usuario (spec.md) para que cada una se implemente y se pruebe de forma independiente.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Puede ejecutarse en paralelo (archivo distinto, sin dependencias pendientes)
- **[Story]**: Historia de usuario a la que pertenece (US1–US5)
- Cada tarea trae la ruta de archivo exacta

## Path Conventions (de plan.md)

- Backend: `../pos-backend/app/api/v1/auth/` y `../pos-backend/app/api/v1/cash/` (relativo a `pos-specs/`, repo hermano)
- Frontend: `../pos-heladeria/src/app/core/` y `../pos-heladeria/src/app/modules/dashboard/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Cumplir el Principio XIV de la constitución (rama nueva antes de tocar código) en ambos repos, antes de empezar cualquier historia.

- [ ] T001 [P] Crear la rama `feat/122-dashboard-redesign` en `../pos-backend` desde su rama actual (`develop`)
- [ ] T002 [P] Crear la rama `feat/122-dashboard-redesign` en `../pos-heladeria` desde su rama actual (`develop`)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Infraestructura compartida que debe completarse antes de cualquier historia.

**No aplica a esta feature.** Las 5 historias son independientes entre sí (ver "Independent Test" de cada una en [spec.md](spec.md)): ninguna depende de datos ni de código que otra historia deba crear primero — incluso US1 (saludo) y US4 (métodos de pago), las dos únicas con pieza de backend, tocan archivos de backend completamente distintos (`auth/routes.py` vs. `cash/reports.py`/`router.py`/`schemas.py`). Esta fase queda vacía a propósito; se pasa directo a Phase 3.

---

## Phase 3: User Story 1 - Ver el saludo, los accesos rápidos y los indicadores del turno con el nuevo diseño (Priority: P1) 🎯 MVP

**Goal**: El Dashboard muestra un saludo con el nombre real del usuario según la hora del día, los accesos rápidos justo debajo, y los 4 indicadores del reporte operativo en una sola fila — conservando las tarjetas "Usuarios"/"Productos" y "Órdenes recientes" (FR-001, FR-002, FR-003, FR-009, FR-010).

**Independent Test**: Entrar al Dashboard y verificar que el saludo, los accesos rápidos y las 4 tarjetas de indicadores se ven con el estilo del diseño de referencia, que cambiar el período actualiza esas 4 tarjetas, y que las tarjetas/lista ya existentes siguen presentes (spec.md, US1).

### Backend — nombre real en la sesión (FR-010)

- [X] T003 [US1] **Antes de modificar código**: ejecutar `cd ../pos-backend && ./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'` una vez para capturar la línea base real vigente (no asumir el número de la memoria del proyecto — puede haber cambiado desde que se registró). Luego añadir `"name": user.name,` a los dos diccionarios `user_data` en `../pos-backend/app/api/v1/auth/routes.py` (login, ~líneas 218-225; refresh, ~líneas 441-448) — `User.name` es `NOT NULL` (`core/models.py:131`), lectura segura sin guardas adicionales
- [X] T004 [P] [US1] Crear `../pos-backend/app/characterization_tests/test_auth_session_name_claim.py`: login y refresh devuelven/firman `name` igual a `User.name` sembrado (reusar fixtures de `auth_fixtures.py` y el patrón de llamada de `test_auth_login_platform_isolation.py`, que ya invoca login y lee `body["user"]`) (depende de T003)

### Frontend — preferir el nombre real (FR-010)

- [X] T005 [P] [US1] Añadir `name?: string` a `BackendUser` en `../pos-heladeria/src/app/core/auth/auth.models.ts`
- [X] T006 [US1] En `buildUserFromBackend` (`../pos-heladeria/src/app/core/services/auth.service.ts:244-259`), cambiar `name: displayNameFromEmail(backend.email)` por `name: backend.name || displayNameFromEmail(backend.email)`; actualizar el comentario desactualizado en `core/interfaces/user.interface.ts` que dice que el backend no devuelve nombre (depende de T005)
- [X] T007 [P] [US1] Añadir casos en `../pos-heladeria/src/app/core/services/auth.service.spec.ts`: con `backend.name` presente se usa tal cual; sin él, cae a `displayNameFromEmail` (igual que hoy) (depende de T006)

### Frontend — plantilla del Dashboard (FR-001, FR-002, FR-003, FR-009)

- [X] T008 [US1] **Antes de modificar código**: ejecutar `cd ../pos-heladeria && npx ng test --watch=false` una vez para capturar la línea base real vigente de fallas pre-existentes (no asumir el conteo de la memoria del proyecto — puede haber cambiado desde que se registró). Luego, en `../pos-heladeria/src/app/modules/dashboard/pages/admin-dashboard.component.ts`, reemplazar el saludo genérico ("Bienvenido👋") por un saludo según la hora del día ("Buenos días"/"Buenas tardes"/"Buenas noches") + `authService.currentUser()?.name`, y el subtítulo "Esto es lo que pasa hoy en tu negocio." (depende de T006)
- [X] T009 [US1] En el mismo archivo, mover el bloque "Accesos rápidos" para que aparezca inmediatamente debajo del saludo, antes del bloque "Reporte operativo" (hoy está después) — sin cambiar `quickActions` ni su comportamiento (FR-012)
- [X] T010 [US1] En el mismo archivo, reemplazar los 3 `<app-stat-tile>` (Ventas totales/Órdenes/Ticket promedio) por una fila de 4 celdas (+ Órdenes activas) separadas por un divisor de 1px `border-gray-100` entre celdas 2-4 (no en la primera), cada una con etiqueta + valor + texto secundario descriptivo fijo (lista completa de las 4 etiquetas en data-model.md §5; razón de diseño en research.md §2) — sin modificar `StatTileComponent` (sigue usándose igual en `shift-sales-report-card.component.ts`)
- [X] T011 [P] [US1] Extender `../pos-heladeria/src/app/modules/dashboard/pages/admin-dashboard.component.spec.ts`: el saludo cambia según la hora simulada y usa `currentUser()?.name`; los accesos rápidos aparecen antes del reporte operativo; la fila de 4 indicadores muestra los valores correctos; las tarjetas "Usuarios"/"Productos" y la lista "Órdenes recientes" siguen renderizándose (depende de T008, T009, T010)

**Checkpoint**: El Dashboard ya muestra el saludo, los accesos rápidos reposicionados y los 4 indicadores del nuevo diseño, conservando el contenido existente — US1 es funcional y verificable de forma independiente (quickstart.md §1).

---

## Phase 4: User Story 2 - Ver la tendencia reciente de ventas, órdenes o ticket promedio en el nuevo gráfico interactivo (Priority: P2)

**Goal**: El panel "Estadísticas de ventas" muestra, con pestañas Ventas/Órdenes/Ticket promedio, el total y un gráfico de barras día a día de los días más recientes, independiente del selector de período del reporte operativo (FR-004).

**Independent Test**: Verificar que el panel muestra el indicador elegido con su gráfico, que las pestañas cambian lo que se grafica, que el cursor sobre una barra muestra fecha y valor, y que cambiar el período de la Historia 1 no afecta este panel (spec.md, US2).

### Implementation for User Story 2

- [X] T012 [US2] Añadir `getDailySalesTrend(dateFrom: string, dateTo: string)` a `../pos-heladeria/src/app/modules/dashboard/services/shift-reports.service.ts`, llamando a `GET /reports/sales?date_from=&date_to=&group_by=day` (mismo endpoint ya usado por el módulo de Reportes, RF-059) — **sin** inyectar `modules/reports/services/reports.service.ts`: ese servicio tiene su propio `period`/`range` global que también gobierna la pantalla de Reportes, y mutarlo desde el Dashboard la afectaría; esta llamada es un método propio, con parámetros explícitos por invocación, igual al resto de `ShiftReportsService`
- [X] T013 [US2] En `admin-dashboard.component.ts`, añadir el panel "Estadísticas de ventas" con pestañas Ventas/Órdenes/Ticket promedio, una ventana fija de los últimos 10 días naturales (independiente del selector de período del reporte operativo), alimentando `<app-bars-chart>` dentro de `<app-chart-card>` con los `[values]`/`[kind]` que correspondan a la pestaña activa (Ticket promedio derivado de `total/count` en el propio componente) (depende de T012)
- [X] T014 [P] [US2] Extender `admin-dashboard.component.spec.ts`: cambiar de pestaña actualiza el total grande y el gráfico; cambiar el período del reporte operativo (Historia 1) no modifica este panel; una ventana sin ventas se muestra vacía sin inventar barras (depende de T013)

**Checkpoint**: El panel de tendencia reciente funciona de forma independiente del selector de período — US2 es funcional y verificable por separado (quickstart.md §2), sin afectar US1.

---

## Phase 5: User Story 3 - Ver los productos más vendidos y las ventas por categoría con el nuevo diseño visual (Priority: P3)

**Goal**: "Más vendidos" permite alternar entre cantidad e ingresos; "Ventas por categoría" sigue mostrando el reparto por categoría (FR-005, FR-006).

**Independent Test**: Alternar el criterio de "Más vendidos" y verificar que el orden y las barras cambian; confirmar que "Ventas por categoría" muestra el reparto con porcentaje (spec.md, US3).

### Implementation for User Story 3

- [X] T015 [US3] En `admin-dashboard.component.ts`, añadir un signal `topMode: 'units'|'revenue'` con su control de alternancia (dos botones, estilo "Ver por" del diseño de referencia); los `[values]`/`[kind]` que ya se pasan al `<app-ranked-bars-chart>` existente cambian según `topMode`, reordenando `topProducts()` por el criterio activo (`units` o `revenue`, ambos ya presentes en `ProductBreakdownRow`) — "Ventas por categoría" no requiere cambios (research.md §5: `ShareBarChartComponent` ya cumple FR-006 tal como está)
- [X] T016 [P] [US3] Extender `admin-dashboard.component.spec.ts`: alternar a "ingresos" reordena y re-etiqueta las barras por monto; alternar a "cantidad" vuelve al criterio por unidades (depende de T015)

**Checkpoint**: "Más vendidos" alterna cantidad/ingresos y "Ventas por categoría" sigue funcionando — US3 es funcional y verificable por separado (quickstart.md §3), sin afectar US1/US2.

---

## Phase 6: User Story 4 - Ver los ingresos por método de pago (Priority: P4)

**Goal**: Una sección nueva muestra el total por método de pago y un gráfico con la granularidad de tiempo que corresponda al período elegido (hora/día/semana), con filtros por método (FR-007).

**Independent Test**: Verificar que la sección muestra totales y un gráfico cuya granularidad cambia con el período elegido, y que desactivar un método lo quita del total y del gráfico (spec.md, US4).

### Backend — endpoint nuevo (FR-007)

- [X] T017 [US4] Añadir `PaymentMethodBucketRow` y `PaymentMethodsReportResponse` a `../pos-backend/app/api/v1/cash/schemas.py` (contracts/payment-methods-report-api.md: `bucket_unit` + `rows: [{bucket_start, payment_method_id, payment_method_name, amount}]`)
- [X] T018 [US4] Añadir una función de agregación (p. ej. `payment_methods_report`) a `../pos-backend/app/api/v1/cash/reports.py`: resuelve el conjunto de turnos reutilizando `resolve_period_bounds`/`period_selector`/`shift_selector`/`open_shifts_selector` (ya existentes, sin modificarlas), elige `bucket_unit` según el período resuelto (hora: turno actual/específico/día; día: semana; semana: mes; día: rango — research.md §6), y agrega `Payment.amount` agrupado por `(bucket, payment_method_id)` uniendo `Payment → Sale (cash_shift_id) → CashShift` — siempre en vivo, sin atajo de snapshot (`ShiftSalesReport` no cubre esta dimensión) (depende de T017)
- [X] T019 [US4] Añadir `GET /cash/reports/payment-methods` a `../pos-backend/app/api/v1/cash/router.py`: mismos parámetros y mismas validaciones 422/404 que `/cash/reports/period` (más `shift_id` obligatorio si `period=shift`), protegido por `require_tenant_admin` (depende de T018)
- [X] T020 [US4] Crear `../pos-backend/app/characterization_tests/test_cash_reports_payment_methods.py`: `bucket_unit` correcto por cada tipo de período; un pago dividido entre dos métodos se atribuye correctamente a cada uno (no a `Sale.total`); un período sin pagos devuelve `rows: []` (200, no 404); 422/404 en los mismos casos que `/cash/reports/period` (depende de T019)
- [X] T021 [US4] Ejecutar de nuevo la suite completa de characterization tests de `pos-backend` (`cd ../pos-backend && ./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`) y confirmar que solo crecen los tests nuevos de T004/T020 respecto a la línea base capturada en T003, sin regresiones (depende de T004, T020)

### Frontend — sección nueva (FR-007)

- [X] T022 [P] [US4] Añadir `PaymentMethodBucketRow`/`PaymentMethodsReport` a `../pos-heladeria/src/app/modules/dashboard/interfaces/shift-reports.interface.ts`
- [X] T023 [US4] Añadir `getPaymentMethodsReport(...)` a `shift-reports.service.ts`, llamando a `GET /cash/reports/payment-methods` con los mismos parámetros que `getPeriodReport`/`getCurrentShiftReport` (depende de T022)
- [X] T024 [US4] Crear `../pos-heladeria/src/app/modules/dashboard/components/payment-methods-chart.component.ts`: gráfico de barras agrupadas multiserie (una serie por método de pago, un grupo por bucket de tiempo), reutilizando `seriesColor`/`axisColors`/tooltip de `shared/charts/chart-theme.ts` (no existe hoy un componente compartido para esta forma — `ShareBarChartComponent` es apilado al 100%, no agrupado)
- [X] T025 [P] [US4] Crear `payment-methods-chart.component.spec.ts`: casos para el número de series/grupos, colores por método, formato de tooltip (depende de T024)
- [X] T026 [US4] En `admin-dashboard.component.ts`, añadir la sección "Ingresos por método de pago": chips para incluir/excluir cada método, totales por método, `<app-payment-methods-chart>` dentro de `<app-chart-card>`, recalculando al cambiar el período del reporte operativo (Historia 1, ya que esta sección sí sigue ese período) (depende de T023, T024)
- [X] T027 [P] [US4] Extender `admin-dashboard.component.spec.ts`: desactivar un método en los chips lo quita del total y del gráfico; la granularidad mostrada cambia con el período elegido; estados de carga/error/vacío propios de la sección, sin bloquear el resto del Dashboard (depende de T026)

**Checkpoint**: "Ingresos por método de pago" funciona con la granularidad adaptativa del diseño de referencia — US4 es funcional y verificable por separado (quickstart.md §4), sin afectar US1/US2/US3.

---

## Phase 7: User Story 5 - Ver la alerta de stock bajo (Priority: P5)

**Goal**: Una sección nueva lista los insumos bajo su mínimo, con enlace a Inventario (FR-008).

**Independent Test**: Verificar que la sección lista los insumos bajo mínimo con su cantidad restante, y que "Ver inventario" lleva al módulo de Inventario (spec.md, US5).

### Implementation for User Story 5

- [X] T028 [US5] En `admin-dashboard.component.ts`, inyectar `InventoryService` (ya existente, `modules/inventory/services/inventory.service.ts`), llamar `loadLowStock()` en `ngOnInit` (mismo patrón ya usado ahí para `usersService`/`tableService`/`productService`), y añadir la sección "Stock bajo" renderizando `lowStockItems()` (`{name, current_stock, min_stock}`) con `routerLink="/dashboard/inventory"` en "Ver inventario"; sin insumos bajo mínimo, la sección se omite o indica claramente que no hay alertas (no una lista vacía confusa)
- [X] T029 [P] [US5] Extender `admin-dashboard.component.spec.ts`: lista los insumos de `lowStockItems()` con su cantidad restante; "Ver inventario" apunta a `/dashboard/inventory`; sin insumos bajo mínimo, no se muestra una lista vacía (depende de T028)

**Checkpoint**: "Stock bajo" funciona reutilizando el servicio ya existente — US5 es funcional y verificable por separado (quickstart.md §5), sin afectar US1/US2/US3/US4.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Verificación final de regresión (SC-005) sobre las 5 historias juntas.

- [X] T030 Ejecutar de nuevo la suite completa de `pos-heladeria` (`cd ../pos-heladeria && npx ng test --watch=false`) y confirmar que no hay fallas nuevas más allá de la línea base capturada en T008 (depende de T011–T029)
- [ ] T031 Ejecutar manualmente la guía [quickstart.md](quickstart.md) completa (secciones 1 a 6, incluyendo la §6 de regresión: selector de período, accesos rápidos, tarjetas conservadas, sesión con token emitido antes del cambio) contra ambos repos corriendo localmente (depende de T021, T030)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias — arranca de inmediato
- **Foundational (Phase 2)**: vacía (no aplica a esta feature) — no bloquea nada
- **User Stories (Phase 3-7)**: cada una puede arrancar justo después de Setup; no dependen entre sí (archivos distintos salvo el punto de integración señalado abajo)
- **Polish (Phase 8)**: depende de que las historias que se vayan a entregar estén completas

### User Story Dependencies

- **US1 (P1)**: sin dependencia de otras historias
- **US2 (P2)**: sin dependencia de otras historias (archivos distintos de US1)
- **US3 (P3)**: sin dependencia de otras historias
- **US4 (P4)**: sin dependencia de otras historias en lógica, aunque es la única con pieza de backend propia (`cash/reports.py`/`router.py`/`schemas.py`, no compartidos con US1's `auth/routes.py`)
- **US5 (P5)**: sin dependencia de otras historias
- Las 5 historias **comparten un único archivo frontend** — `admin-dashboard.component.ts` (T008-T010 de US1, T013 de US2, T015 de US3, T026 de US4, T028 de US5) y su spec `admin-dashboard.component.spec.ts` — no es una dependencia funcional entre ellas, pero sí un punto de conflicto de archivo a tener en cuenta al paralelizar: conviene secuenciar esos cambios en vez de editarlos a ciegas en paralelo.

### Within Each User Story

- Backend antes que frontend cuando la historia toca ambos (US1, US4): el contrato debe existir antes de consumirlo — salvo las interfaces TypeScript (p. ej. T022), que solo reflejan el contrato ya definido en `contracts/` y no necesitan el endpoint real construido para escribirse.
- Implementación antes que su test correspondiente (no se pidió TDD).
- Historia completa y verificada (checkpoint) antes de pasar a la siguiente en una entrega secuencial.

### Parallel Opportunities

- T001/T002 (Setup, dos repos distintos) en paralelo.
- Dentro de US1: T004 (test backend) en paralelo con T005 (interfaz frontend) una vez exista T003; T007 en paralelo con el resto una vez exista T006.
- Dentro de US4: T022 (interfaz frontend) en paralelo con el trabajo de backend (T017-T021, repos distintos); T025 en paralelo con T026/T027 una vez exista T024.
- Si hay más de una persona disponible: US2, US3 y US5 pueden trabajarse en paralelo entre sí desde el inicio (no comparten archivo de servicio/componente propio); mejor secuenciar quién toca `admin-dashboard.component.ts` y en qué orden para evitar conflictos de merge.

---

## Parallel Example: User Story 4

```bash
# Backend y frontend de US4 pueden arrancar a la vez (repos distintos):
Task: "Añadir PaymentMethodBucketRow/PaymentMethodsReportResponse en ../pos-backend/app/api/v1/cash/schemas.py"
Task: "Añadir PaymentMethodBucketRow/PaymentMethodsReport en ../pos-heladeria/.../shift-reports.interface.ts"

# Una vez listo el endpoint, el componente de gráfico nuevo y su test en paralelo:
Task: "Crear payment-methods-chart.component.ts"
Task: "Crear payment-methods-chart.component.spec.ts" (tras crear el componente)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Completar Phase 1: Setup (ramas en ambos repos)
2. Phase 2: Foundational — vacía, se salta
3. Completar Phase 3: User Story 1 (saludo + accesos rápidos + 4 KPIs)
4. **Parar y validar**: quickstart.md §1, de forma independiente
5. Es la primera impresión del nuevo diseño — entregable solo, si hace falta priorizar

### Incremental Delivery

1. Setup → Foundational (vacía) → listo para empezar
2. US1 (saludo/accesos/KPIs) → validar con quickstart.md §1 → entregar (MVP)
3. US2 (tendencia reciente) → validar con quickstart.md §2 → entregar
4. US3 (más vendidos/categoría) → validar con quickstart.md §3 → entregar
5. US4 (ingresos por método) → validar con quickstart.md §4 → entregar
6. US5 (stock bajo) → validar con quickstart.md §5 → entregar
7. Phase 8 (Polish): regresión completa (quickstart.md §6, SC-005) antes de cerrar la spec

### Parallel Team Strategy

Con más de una persona disponible:

1. Completar Setup juntos (T001/T002)
2. Una persona en US1 (toca `auth/routes.py` + `admin-dashboard.component.ts`), otra en US4 (toca `cash/*` + un componente nuevo) desde el inicio — repos/archivos de backend distintos
3. US2/US3/US5 mejor después de que US1 termine su parte de `admin-dashboard.component.ts` (todas lo comparten) — evita conflictos de merge, no porque dependan funcionalmente

---

## Notes

- [P] = archivos distintos, sin dependencias pendientes entre sí
- La etiqueta [Story] mapea cada tarea a su historia para trazabilidad (Principio XII de la constitución)
- Cada historia es completable y verificable de forma independiente (quickstart.md, una sección por historia)
- `admin-dashboard.component.ts`/`.spec.ts` son tocados por las 5 historias — no es una dependencia funcional entre ellas, pero sí un punto de conflicto de archivo a tener en cuenta al paralelizar
- Commits: solo cuando el usuario lo pida explícitamente, en unidades pequeñas y lógicas, en inglés, sin marcas de autoría de IA (Principio XV) — no implícito en ninguna tarea de este archivo
- Evitar: tareas vagas, conflictos de archivo marcados como [P], dependencias cruzadas entre historias que rompan su independencia
