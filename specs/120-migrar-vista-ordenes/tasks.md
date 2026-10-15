---

description: "Task list for migrating the Órdenes module view to the reference design"
---

# Tasks: Migrar vista del módulo de Órdenes al nuevo diseño

**Input**: Design documents from `/specs/120-migrar-vista-ordenes/`
**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/orders-list-api.md](./contracts/orders-list-api.md), [quickstart.md](./quickstart.md)

**Tests**: Incluidos — la constitución del proyecto (Principio X, "Verificación Obligatoria") exige verificar toda nueva funcionalidad con tests, y ambos repositorios ya mantienen suites de tests para este módulo (`pytest` en `pos-backend`, Vitest en `pos-heladeria`).

**Organization**: Tareas agrupadas por historia de usuario (spec.md) para que cada una sea implementable y verificable de forma independiente. Rutas relativas a la raíz de `pos-specs`: `../pos-backend/...` y `../pos-heladeria/...` (dos repositorios hermanos ya en producción — ver plan.md, Project Structure).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Puede ejecutarse en paralelo (archivos distintos, sin dependencias entre sí)
- **[Story]**: Historia de usuario a la que pertenece (US1, US2, US3)

---

## Phase 1: Setup

**Purpose**: Preparar ambos repositorios antes de tocar código (Constitución, Principio XIV).

- [X] T001 Crear la rama `feat/120-orders-filters-api` en `../pos-backend` y la rama `feat/120-orders-view-redesign` en `../pos-heladeria`, cada una desde la rama actual de su propio repositorio (Principio XIV; plan.md Constitution Check)
- [X] T002 [P] Confirmar que ambos entornos locales levantan (API de `../pos-backend` y `npm start` en `../pos-heladeria`) y que existe al menos un tenant de prueba con órdenes `DINE_IN`, `TAKEAWAY` y `DELIVERY` en distintos estados y fechas, por [quickstart.md](./quickstart.md) "Prerrequisitos"

**Checkpoint**: Ambos repos listos para recibir cambios de esta feature.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Utilidades de presentación compartidas por US1 (tarjeta) y US2 (detalle) — deben existir antes de reconstruir cualquiera de las dos pantallas.

**⚠️ CRITICAL**: Ninguna historia de usuario arranca su implementación (no sus tests) hasta cerrar esta fase.

- [X] T003 Agregar `orderDisplayCode(order: Pick<DiningOrder, 'id'>): string` (código corto `#XXXXXX` derivado del `id`, ver [research.md](./research.md) §3 y [data-model.md](./data-model.md) "Código corto de orden") y `orderLocationLabel(order, tableLabel: string | null): string` (mesa si existe, `'Mostrador'` si no y no es domicilio, `null`/vacío si es domicilio — mismo criterio ya usado hoy en `orders-page.component.ts`, ver [data-model.md](./data-model.md) "Ubicación mostrada") en `../pos-heladeria/src/app/modules/orders/order-status.util.ts`
- [X] T004 Agregar tests unitarios para `orderDisplayCode` y `orderLocationLabel` (casos: mesa, para llevar, domicilio, UUID conocido → código esperado) en `../pos-heladeria/src/app/modules/orders/order-status.util.spec.ts` (depende de T003; usado por US1 y US2)

**Checkpoint**: Helpers compartidos listos y probados — US1 y US2 pueden empezar.

---

## Phase 3: User Story 1 - Explorar y filtrar la lista de órdenes con el nuevo diseño (Priority: P1) 🎯 MVP

**Goal**: Lista de órdenes rediseñada como tarjetas, con filtro de estado, filtro de tipo segmentado, buscador de cliente/orden y filtro de fecha — ambos operando sobre todas las órdenes del negocio — más conteo en vivo, estado vacío y paginación (spec FR-001 a FR-009).

**Independent Test**: Abrir `/dashboard/orders`, combinar los cuatro filtros (estado, tipo, fecha, búsqueda) y confirmar que la lista de tarjetas y el conteo de resultados se actualizan de forma consistente, incluyendo el estado vacío y la paginación en los bordes (última página parcial).

### Tests for User Story 1 ⚠️

> Escribir primero, confirmar que fallan antes de implementar.

- [X] T005 [P] [US1] Casos de `date_from`, `date_to` y `q` (solos y combinados entre sí y con `status`/`order_type`) para la rama paginada de `GET /orders`, invocando `orders_router.list_orders` con `orders_fixtures` igual que `test_orders_status_type_filters.py`, en `../pos-backend/app/characterization_tests/test_orders_date_search_filters.py`
- [X] T006 [P] [US1] Casos de `search`, `dateFrom`, `dateTo` en la query key/params de `OrdersListService` (combinados con `status`/`orderType` ya existentes) en `../pos-heladeria/src/app/modules/orders/services/orders-list.service.spec.ts`
- [X] T007 [P] [US1] Casos de UI del grid de tarjetas, buscador, filtro de fecha (con bloqueo de fechas futuras), filtro de tipo segmentado, conteo en vivo, estado vacío y rango de paginación en última página parcial, en `../pos-heladeria/src/app/modules/orders/pages/orders-page.component.spec.ts`

### Implementation for User Story 1

- [X] T008 [US1] Agregar `date_from: date | None`, `date_to: date | None` y `q: str | None` (Query opcionales) a `list_orders` en `../pos-backend/app/api/v1/orders/router.py`, pasados únicamente a la rama paginada (`contracts/orders-list-api.md`; la rama sin `page`/`size` de `list_orders()` no se toca, Principio III)
- [X] T009 [US1] Extender `list_orders_query()` en `../pos-backend/app/api/v1/orders/service.py` para aplicar `created_at >= date_from`, `created_at <= date_to` (inclusive, fin de día) y `customer_name ILIKE` / `id::text ILIKE` sobre `q` (research.md §1-2) — depende de T008
- [X] T010 [US1] Agregar signals `search`, `dateFrom`, `dateTo` (con sus setters, cada uno reinicia a página 1) a `OrdersListService` en `../pos-heladeria/src/app/modules/orders/services/orders-list.service.ts`, mismo patrón que `SalesService.dateFrom/dateTo/invoiceReference` — depende de T009
- [X] T011 [P] [US1] Crear el componente de calendario de fecha (botón con la fecha elegida, atajos "Hoy"/"Ayer", navegación mes a mes, fechas futuras deshabilitadas) en `../pos-heladeria/src/app/modules/orders/components/order-date-filter.component.ts` (research.md §5)
- [X] T012 [US1] Reconstruir `OrdersPageComponent` (`../pos-heladeria/src/app/modules/orders/pages/orders-page.component.ts`): grid de tarjetas (cliente, `orderDisplayCode`, hora, cantidad de ítems, `orderLocationLabel`/tipo, badge de estado de pago, badge de estado), selector de estado, filtro de tipo segmentado, buscador, `app-order-date-filter`, conteo en vivo, estado vacío y paginación — depende de T003, T010, T011

**Checkpoint**: US1 funcional y verificable de forma independiente (MVP).

---

## Phase 4: User Story 2 - Ver el detalle de una orden con la información agrupada del nuevo diseño (Priority: P2)

**Goal**: Detalle de orden agrupado en bloques (orden, cliente, domicilio condicional, factura), ítems con sus particularidades existentes y desglose de totales, omitiendo datos no disponibles (spec FR-011 a FR-016).

**Independent Test**: Abrir el detalle de una orden en mesa y de una a domicilio por separado y confirmar que los bloques, los ítems, los totales y el botón "Volver a órdenes" (con filtros conservados) se comportan según los Acceptance Scenarios de US2 del spec, incluyendo que ningún dato ausente se muestre inventado.

### Tests for User Story 2 ⚠️

- [X] T013 [P] [US2] Casos de encabezado + bloques agrupados (orden/cliente/factura), bloque de domicilio condicional, omisión de identificación/método de pago ausentes, ítems con notas/adicionales/anulado, y desglose de totales, en `../pos-heladeria/src/app/modules/orders/pages/order-detail.component.spec.ts`

### Implementation for User Story 2

- [X] T014 [US2] Reconstruir el encabezado y los bloques de "Información de la orden" / "Información del cliente" / "Información de factura" (usando `orderDisplayCode` y `orderLocationLabel`) en `../pos-heladeria/src/app/modules/orders/pages/order-detail.component.ts` — depende de T003
- [X] T015 [US2] Agregar el bloque condicional de datos de domicilio (teléfono, dirección) solo para `order_type === 'DELIVERY'`, en el mismo archivo — depende de T014
- [X] T016 [US2] Restyle del resumen de ítems al formato de columnas del diseño (PRODUCTO/CANTIDAD/PRECIO UNIT./SUBTOTAL), preservando las filas condicionales ya existentes (notas, adicionales, ítem anulado, `muestraImportes()`), en el mismo archivo — depende de T014 (research.md §6)
- [X] T017 [US2] Reestilizar el desglose de totales (subtotal, domicilio, descuento, total, pagado) y los avisos existentes (cuenta unificada, pedido sin cobrar, sin detalle de precios) sin alterar su lógica, en el mismo archivo — depende de T014
- [X] T018 [US2] Hacer que "Volver a órdenes" conserve los filtros vigentes de la lista (estado, tipo, búsqueda, fecha, página) vía query params en la navegación, tocando `../pos-heladeria/src/app/modules/orders/pages/order-detail.component.ts` (botón) y `../pos-heladeria/src/app/modules/orders/pages/orders-page.component.ts` (leer filtros de query params al entrar) — depende de T012, T014

**Checkpoint**: US1 y US2 funcionan de forma independiente.

---

## Phase 5: User Story 3 - Iniciar una nueva orden desde el módulo de Órdenes (Priority: P3)

**Goal**: Acceso directo "Nueva orden" desde la lista hacia el flujo ya existente de creación de pedido manual (spec FR-010).

**Independent Test**: Desde la lista de órdenes, presionar "Nueva orden" y confirmar que lleva a `mesas-sesiones/orden-manual`.

### Tests for User Story 3 ⚠️

- [X] T019 [US3] Caso de navegación al presionar "Nueva orden" en `../pos-heladeria/src/app/modules/orders/pages/orders-page.component.spec.ts` (mismo archivo que T007/T012; agregar, no reemplazar, los casos ya escritos)

### Implementation for User Story 3

- [X] T020 [US3] Agregar el botón "Nueva orden" (`routerLink="/dashboard/mesas-sesiones/orden-manual"`) al encabezado de `OrdersPageComponent` en `../pos-heladeria/src/app/modules/orders/pages/orders-page.component.ts` — depende de T012

**Checkpoint**: Las tres historias de usuario son funcionales de forma independiente.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Verificación final transversal a las tres historias.

- [X] T021 [P] Revisar el grid de tarjetas y los bloques del detalle en punto de quiebre móvil/tablet (sin información cortada u oculta, SC-003) en `../pos-heladeria/src/app/modules/orders/pages/orders-page.component.ts` y `order-detail.component.ts`
- [ ] T022 Ejecutar los 12 escenarios de [quickstart.md](./quickstart.md) de punta a punta contra ambos repos en la rama de esta feature
- [X] T023 [P] Confirmar que ningún test con prefijo `"CONGELA comportamiento actual:"` en `../pos-backend` (`app/characterization_tests/`) ni en `../pos-heladeria` (suites de `orders`/`tables`) quedó en rojo por los cambios de esta feature (Principio III)

---

## Correcciones post-implementación

Reportadas por el negocio tras ver el detalle de orden desplegado (no estaban en el `tasks.md` original porque el supuesto de spec.md que las originó resultó incorrecto — ver spec.md Assumptions y data-model.md "Valores derivados"):

- [X] T024 Exponer `invoice_reference`/`payment_method_name` reales en `GET /orders/{id}` (`../pos-backend/app/api/v1/orders/service.py::invoice_and_payment_info`, `router.py::_load_order`, `schemas.py::OrderResponse`) y usarlos en el detalle de `../pos-heladeria` (`DiningOrder`, `order-detail.component.ts::invoiceReference()`/`paymentMethod()`), con respaldo al código interno/`current_payment_attempt` cuando no existan todavía. Tests nuevos: `../pos-backend/app/characterization_tests/test_orders_invoice_reference_and_payment_method.py` (5 casos) y 4 casos nuevos en `order-detail.component.spec.ts`.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Sin dependencias — puede arrancar de inmediato.
- **Foundational (Phase 2)**: Depende de Setup. Bloquea la **implementación** de US1 y US2 (no bloquea escribir sus tests, que pueden adelantarse en paralelo).
- **User Story 1 (Phase 3)**: Depende de Foundational. Es el MVP; no depende de US2 ni US3.
- **User Story 2 (Phase 4)**: Depende de Foundational. T018 (conservar filtros al volver) depende además de que US1 (T012) ya exista, porque toca `orders-page.component.ts`.
- **User Story 3 (Phase 5)**: Depende de que `orders-page.component.ts` ya exista (T012 de US1) — el botón se agrega a esa misma pantalla.
- **Polish (Phase 6)**: Depende de que las historias que se vayan a entregar ya estén completas.

### Dentro de cada historia

- Tests antes que implementación, y deben fallar antes de implementar.
- Backend antes que el servicio frontend que lo consume (T008→T009→T010 en US1).
- Helpers compartidos (Foundational) antes que las pantallas que los usan.
- Dentro de un mismo archivo (p. ej. `order-detail.component.ts` en US2), las tareas son secuenciales aunque no lleven `[P]`.

### Parallel Opportunities

- T005, T006, T007 (tests de US1: backend, servicio, componente — tres archivos distintos)
- T011 (componente de calendario) en paralelo con T008/T009/T010 (cambios de backend/servicio) dentro de US1
- T013 (tests de US2) en paralelo con el trabajo de implementación de US1, una vez cerrada la fase Foundational
- T021 y T023 en Polish

---

## Parallel Example: User Story 1

```bash
# Tests de US1 en paralelo (archivos distintos):
Task: "Casos de date_from/date_to/q en GET /orders — ../pos-backend/app/characterization_tests/test_orders_date_search_filters.py"
Task: "Casos de search/dateFrom/dateTo en OrdersListService — ../pos-heladeria/.../orders-list.service.spec.ts"
Task: "Casos de UI del grid/buscador/fecha/tipo/paginación — ../pos-heladeria/.../orders-page.component.spec.ts"

# Componente de calendario en paralelo con el trabajo de backend/servicio:
Task: "Crear order-date-filter.component.ts"
```

---

## Implementation Strategy

### MVP First (User Story 1)

1. Completar Phase 1 (Setup) y Phase 2 (Foundational).
2. Completar Phase 3 (US1): lista con tarjetas, filtros, búsqueda y fecha ya operando sobre todo el negocio.
3. **Detenerse y validar** US1 de forma independiente contra [quickstart.md](./quickstart.md) (escenarios 1-6).
4. Demostrar/entregar si está listo.

### Incremental Delivery

1. Setup + Foundational → base lista.
2. US1 (P1) → validar independientemente → MVP entregable.
3. US2 (P2) → validar independientemente (incluye T018, que toca también la pantalla de US1).
4. US3 (P3) → validar independientemente (atajo de una línea sobre la pantalla de US1).
5. Polish → revisión responsive, quickstart completo, characterization tests intactos.

---

## Notes

- `[P]` = archivos distintos, sin dependencias entre sí.
- `[Story]` mapea cada tarea a su historia de usuario para trazabilidad.
- Ningún test con prefijo `"CONGELA comportamiento actual:"` se edita en esta feature (Principio III) — todo lo nuevo va en archivos/casos nuevos.
- Confirmar que los tests fallan antes de implementar.
- Las ramas de Git y los commits siguen los Principios XIV y XV de la constitución (una rama por repositorio, creada antes de tocar código; commits pequeños y enfocados, solo bajo pedido explícito del usuario).
