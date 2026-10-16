---

description: "Task list template for feature implementation"
---

# Tasks: Correcciones visuales y funcionales de la lista de Órdenes

**Input**: Design documents from `/specs/121-fix-lista-ordenes/`

**Prerequisites**: [plan.md](plan.md) (required), [spec.md](spec.md) (required for user stories), [research.md](research.md), [data-model.md](data-model.md), [contracts/orders-total-field.md](contracts/orders-total-field.md), [quickstart.md](quickstart.md)

**Tests**: Incluidos. La constitución del proyecto (Principio X, Verificación Obligatoria) exige verificar toda nueva funcionalidad con tests; además, la corrección de US1 toca una ruta protegida por un test de characterization de N+1 (`test_guardia_de_trabajo_acotado_numero_de_sentencias_constante`), así que un test nuevo ahí no es opcional — es la prueba de que esa guardia sigue sosteniéndose con el campo `total` añadido.

**Organization**: Tareas agrupadas por historia de usuario (spec.md) para que cada una se implemente y se pruebe de forma independiente.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Puede ejecutarse en paralelo (archivo distinto, sin dependencias pendientes)
- **[Story]**: Historia de usuario a la que pertenece (US1–US4)
- Cada tarea trae la ruta de archivo exacta

## Path Conventions (de plan.md)

- Backend: `../pos-backend/app/api/v1/orders/` (relativo a `pos-specs/`, repo hermano)
- Frontend: `../pos-heladeria/src/app/modules/orders/` y `../pos-heladeria/src/app/modules/tables/interfaces/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Cumplir el Principio XIV de la constitución (rama nueva antes de tocar código) en ambos repos, antes de empezar cualquier historia.

- [X] T001 [P] Crear la rama `fix/121-orders-list-corrections` en `../pos-backend` desde su rama actual (`develop`) — nombre en inglés, kebab-case, per Principio XIV
- [X] T002 [P] Crear la rama `fix/121-orders-list-corrections` en `../pos-heladeria` desde su rama actual (`develop`) — nombre en inglés, kebab-case, per Principio XIV

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Infraestructura compartida que debe completarse antes de cualquier historia.

**No aplica a esta feature.** Las 4 historias son independientes entre sí (ver "Independent Test" de cada una en [spec.md](spec.md)): US1 toca backend + frontend, US2/US3/US4 son solo frontend y no comparten código nuevo entre ellas ni con US1 (research.md §2–§4, data-model.md §3–§5). No hay esquema de BD, autenticación ni enrutamiento nuevos que preparar — se reutiliza todo lo que ya existe en producción. Esta fase queda vacía a propósito; se pasa directo a Phase 3.

---

## Phase 3: User Story 1 - Ver el total de cada orden sin abrir su detalle (Priority: P1) 🎯 MVP

**Goal**: Cada tarjeta de la lista de Órdenes muestra el monto total de esa orden, igual al que se ve en su detalle (FR-001, FR-002).

**Independent Test**: Abrir la lista de Órdenes, confirmar que cada tarjeta muestra un total, y que coincide con el total del detalle de esa misma orden (spec.md, US1).

### Backend — campo `total` en `OrderResponse`

- [X] T003 [P] [US1] Añadir el campo `total: Decimal | None = None` a `OrderResponse` en `../pos-backend/app/api/v1/orders/schemas.py` (junto a `billing`, con un comentario que aclare que (a) es distinto de `billing.total`, y (b) es distinto del `total` del envoltorio `Page[OrderResponse]` — ese es el conteo de resultados, este es el monto por orden — ver contracts/orders-total-field.md)
- [X] T004 [US1] Añadir una función en bloque (p. ej. `order_totals(db, orders)`) en `../pos-backend/app/api/v1/orders/service.py` que calcule `total` por orden con, como máximo, 2 consultas adicionales para todo el lote (no por fila): (a) `Sale.customer_order_id, Sale.total` para las órdenes con factura propia (mismo patrón que `paid_order_ids`, service.py:335-343); (b) `table_session_id` con venta existente, en bloque, para resolver `factura_agrupada` sobre las órdenes sin factura propia; usando `order.items` ya precargados para sumar `line_total` de los no anulados — misma fórmula de 3 ramas que `build_billing_summary` (service.py:227-318), `max(total, 0)` incluido (research.md §1)
- [X] T005 [US1] En `_load_order` (`../pos-backend/app/api/v1/orders/router.py:49-77`), asignar `order.total = order.billing.total` después de calcular `billing` (costo cero, reutiliza el cálculo del detalle)
- [X] T006 [US1] En la rama paginada de `list_orders` (`../pos-backend/app/api/v1/orders/router.py:638-697`), llamar a la función de T004 sobre `result["items"]` (mismo punto donde hoy se llama `_decorate_orders`) y asignar `total` a cada item; la rama **sin** paginar (`service.list_orders`, usada por Terminal/Dashboard) NO se toca (research.md §1, Principio III)

### Backend — tests de characterization

- [X] T007 [US1] En `../pos-backend/app/characterization_tests/test_orders_pagination.py`: añadir un test que siembre al menos una orden de cada estado de facturación (`factura_propia`, `factura_agrupada`, `sin_factura`) y verifique que `GET /orders?page=1&size=N` devuelve el `total` correcto para cada una; extender `test_guardia_de_trabajo_acotado_numero_de_sentencias_constante` (o añadir un test hermano con el mismo patrón) para confirmar que el conteo de sentencias SQL sigue siendo constante entre 5 y 25 órdenes **con el campo `total` ya poblado** (depende de T003–T006)
- [X] T008 [P] [US1] En `../pos-backend/app/characterization_tests/test_orders_billing_summary.py`: añadir un test que confirme que `GET /orders/{id}` devuelve `total` igual a `billing.total` (depende de T003, T005)
- [X] T009 [US1] Ejecutar la suite completa de characterization tests de `pos-backend` (`cd ../pos-backend && ./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`) **antes** de T003 para capturar la línea base real vigente (el número de 1530 OK de la memoria del proyecto es anterior a los 9 tests que spec 120 ya añadió y fusionó a `main` — no usarlo como referencia actual), y volver a ejecutarla al final de esta fase para confirmar que solo crecen los tests nuevos de T007/T008, sin regresiones (depende de T007, T008)

### Frontend — mostrar el total en la tarjeta

- [X] T010 [P] [US1] Añadir `total?: string | null` a la interfaz `DiningOrder` en `../pos-heladeria/src/app/modules/tables/interfaces/dining.interface.ts` (mismo patrón que los demás importes `Decimal` serializados como texto, p. ej. `OrderBilling.total`)
- [X] T011 [US1] Mostrar `{{ order.total | money }}` en la tarjeta de orden de `../pos-heladeria/src/app/modules/orders/pages/orders-page.component.ts` (importar `MoneyPipe` de `../../../shared/money.pipe.ts`, mismo pipe ya usado en otras pantallas de montos); para una orden sin `total` (compat con backend anterior) no inventar un valor — omitir el bloque igual que ya hace la plantilla con otros campos opcionales (depende de T010)
- [X] T012 [P] [US1] Añadir casos en `../pos-heladeria/src/app/modules/orders/pages/orders-page.component.spec.ts`: el total se renderiza desde `order.total` con el formato de `MoneyPipe`, y una orden con `total: "0.00"` (sin ítems) muestra `$ 0`, no un espacio vacío (depende de T011)

**Checkpoint**: La tarjeta de la lista de Órdenes ya muestra el total correcto, igual al del detalle — US1 es funcional y verificable de forma independiente (quickstart.md §1).

---

## Phase 4: User Story 2 - Confiar en la fecha que muestra el filtro tras elegir un día (Priority: P2)

**Goal**: El texto del filtro de fecha refleja exactamente la fecha elegida, en vez de quedarse fijo en "Hoy" (FR-003, FR-004).

**Independent Test**: Elegir una fecha distinta de hoy en el calendario del filtro y confirmar que el texto visible cambia a esa fecha, incluso después de que la lista recargue (spec.md, US2).

### Implementation for User Story 2

- [X] T013 [US2] En `../pos-heladeria/src/app/modules/orders/components/order-date-filter.component.ts`, convertir `@Input() value = ''` a una signal de entrada (`value = input('')`) para que `readonly label = computed(...)` (líneas 167-173) se reevalúe correctamente cuando el valor cambia; ajustar los usos de `this.value` que ya existen (`ngOnChanges`, `cells()`, `pick()`, etc.) para leer la signal (`this.value()`), y simplificar/eliminar `ngOnChanges` si su única función (sincronizar `viewIso` al cambiar `value`) puede resolverse con un `effect()` sobre la nueva signal (research.md §2)

### Tests for User Story 2

- [X] T014 [P] [US2] Crear `../pos-heladeria/src/app/modules/orders/components/order-date-filter.component.spec.ts`: montar el componente, cambiar el `@Input` `value` después del render inicial (simulando lo que hace el padre al elegir una fecha) y verificar que el texto visible del botón (`label()`) se actualiza a la nueva fecha, no se queda en "Hoy" (depende de T013)

**Checkpoint**: El filtro de fecha refleja siempre la selección vigente — US2 es funcional y verificable de forma independiente (quickstart.md §2), sin afectar US1.

---

## Phase 5: User Story 3 - Navegar la lista de órdenes con el paginador del diseño original (Priority: P3)

**Goal**: La lista de Órdenes muestra un paginador propio con el rango "X–Y de Z", el selector de cantidad por página y los controles de anterior/siguiente del diseño de referencia, sin modificar el paginador compartido con otras pantallas (FR-005, FR-006).

**Independent Test**: Con más órdenes que las que caben en una página, verificar que aparece el paginador con el rango visible y el total, y que cambiar de página o de tamaño actualiza ese rango (spec.md, US3).

### Implementation for User Story 3

- [X] T015 [US3] Crear `../pos-heladeria/src/app/modules/orders/components/orders-pagination.component.ts`: componente standalone con `@Input() page`, `@Input() size`, `@Input() total`, `@Input() loading`, `@Output() pageChange`, `@Output() sizeChange` (misma forma de entrada/salida que `PaginationBarComponent`, para que el reemplazo en T016 sea un cambio de selector); calcula el rango visible (`inicio = (page-1)*size+1`, `fin = min(page*size, total)`, data-model.md §4) y lo muestra junto con el selector de cantidad y controles de anterior/siguiente con chevrons, replicando el diseño de referencia (research.md §3)
- [X] T016 [US3] En `../pos-heladeria/src/app/modules/orders/pages/orders-page.component.ts`, reemplazar `<app-pagination-bar>` (líneas 189-197) por `<app-orders-pagination>`, pasando los mismos signals (`svc.page()`, `svc.size()`, `svc.total()`, `svc.loading()`) y manejando los mismos eventos (`(pageChange)`, `(sizeChange)`) ya conectados a `svc.list(...)`; quitar el import de `PaginationBarComponent` y añadir el de `OrdersPaginationComponent` (depende de T015)

### Tests for User Story 3

- [X] T017 [P] [US3] Crear `../pos-heladeria/src/app/modules/orders/components/orders-pagination.component.spec.ts`: casos para el cálculo del rango (incluyendo la última página parcial, p. ej. "9–10 de 10"), el cambio de tamaño de página, y los estados deshabilitados de los controles en la primera y última página (depende de T015)
- [X] T018 [P] [US3] Ejecutar los specs existentes de los otros 8 consumidores de `PaginationBarComponent` (`presentations-page.component.spec.ts`, `products-page.component.spec.ts`, `sales-page.component.spec.ts`, `promotions-page.component.spec.ts`, `categories-page.component.spec.ts`, `tables-page.component.spec.ts`, `inventory-page.component.spec.ts`) y confirmar que siguen pasando sin cambios — verificación de que `PaginationBarComponent` no fue tocado (depende de T016)

**Checkpoint**: El paginador de Órdenes muestra el rango del diseño de referencia sin afectar ninguna otra pantalla — US3 es funcional y verificable de forma independiente (quickstart.md §3), sin afectar US1/US2.

---

## Phase 6: User Story 4 - Ver los estados como píldoras completamente redondeadas (Priority: P4)

**Goal**: Las etiquetas de estado de pago y de estado de la orden se ven como píldoras completamente redondeadas en cualquier tarjeta, para cualquier longitud de texto (FR-007).

**Independent Test**: Comparar visualmente las etiquetas de estado de cualquier tarjeta contra el diseño de referencia (spec.md, US4).

### Implementation for User Story 4

- [X] T019 [US4] Reproducir el defecto contra el build actual de `main`/`develop` de `../pos-heladeria` (`ng serve`, módulo de Órdenes) **antes** de cambiar código: confirmar si las etiquetas realmente muestran esquinas apenas curvas (el código ya usa `rounded-full` en `orders-page.component.ts:173-176,180-184` — research.md §4). Documentar en este task (comentario de commit o nota en el PR) si reprodujo o no, y con qué causa aparente
- [X] T020 [US4] Si T019 reprodujo el defecto: aplicar un `border-radius` explícito y robusto a ambas etiquetas (estado de pago y estado de la orden) en `../pos-heladeria/src/app/modules/orders/pages/orders-page.component.ts`, independiente de que `rounded-full` se purgue/genere correctamente — verificar visualmente con un estado de texto largo (p. ej. "Por confirmar") además de uno corto (depende de T019; si T019 no reprodujo el defecto, esta tarea se marca como no aplicable y se reporta el hallazgo)

### Tests for User Story 4

- [X] T021 [P] [US4] Añadir un caso en `../pos-heladeria/src/app/modules/orders/pages/orders-page.component.spec.ts` que verifique que las etiquetas de estado de pago y de estado de la orden tienen la clase/estilo de píldora completa, para un estado de texto corto y uno largo (depende de T020)

**Checkpoint**: Los badges de la tarjeta se ven como píldoras completas en cualquier estado — US4 es funcional y verificable de forma independiente (quickstart.md §4), sin afectar US1/US2/US3.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Verificación final de regresión (SC-005) sobre las 4 historias juntas.

- [X] T022 Ejecutar la suite completa de `pos-heladeria` (`cd ../pos-heladeria && npx ng test --watch=false`) **antes** de empezar esta spec para capturar la línea base real vigente (la memoria del proyecto marca el rango de 6–11 archivos con fallas pre-existentes como no reconfirmado desde 2026-10-15 — no asumirlo, volver a medirlo), y de nuevo al final para confirmar que no hay fallas nuevas más allá de esa línea base recién capturada (depende de T010–T021)
- [ ] T023 Ejecutar manualmente la guía [quickstart.md](quickstart.md) completa (secciones 1 a 5, incluyendo la §5 de regresión: filtros de estado/tipo/búsqueda combinados, navegación al detalle y vuelta conservando filtros, "Nueva orden") contra ambos repos corriendo localmente (depende de T009, T022)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias — arranca de inmediato
- **Foundational (Phase 2)**: vacía (no aplica a esta feature) — no bloquea nada
- **User Stories (Phase 3-6)**: cada una puede arrancar justo después de Setup; no dependen entre sí (US1 es backend+frontend, US2/US3/US4 son solo frontend y tocan archivos distintos de los de US1, salvo el punto de integración señalado abajo)
- **Polish (Phase 7)**: depende de que las historias que se vayan a entregar estén completas

### User Story Dependencies

- **US1 (P1)**: sin dependencia de otras historias
- **US2 (P2)**: sin dependencia de otras historias (archivo distinto: `order-date-filter.component.ts`)
- **US3 (P3)**: sin dependencia de otras historias en lógica, pero **T016 edita el mismo archivo** que T011 (US1) y T020 (US4) — `orders-page.component.ts` — así que si se implementan en la misma rama/sesión, conviene secuenciar esos tres cambios (US1 → US3 → US4) en vez de editarlos a ciegas en paralelo, aunque las historias en sí sean independientes
- **US4 (P4)**: igual que US3 — comparte archivo (`orders-page.component.ts`) con US1/US3, sin depender funcionalmente de ninguna

### Within Each User Story

- Backend antes que frontend cuando la historia toca ambos (US1): el contrato (`total` en `OrderResponse`) debe existir antes de consumirlo en la plantilla
- Implementación antes que su test correspondiente (no se pidió TDD)
- Historia completa y verificada (checkpoint) antes de pasar a la siguiente en una entrega secuencial

### Parallel Opportunities

- T001/T002 (Setup, dos repos distintos) en paralelo
- Dentro de US1: T003 (schemas) y T010 (frontend interface) en paralelo entre sí (repos distintos); T008 (test de billing) en paralelo con T007 una vez exista la implementación
- Dentro de US3: T017 (test) en paralelo con T018 (regresión de otras pantallas) una vez exista T016
- Si hay más de una persona disponible, US2 puede trabajarse en paralelo con US1 desde el inicio (archivos completamente distintos); US3/US4 mejor en serie después de US1 por el archivo compartido (`orders-page.component.ts`)

---

## Parallel Example: User Story 1

```bash
# Backend y frontend de US1 pueden arrancar a la vez (repos distintos):
Task: "Añadir total: Decimal | None a OrderResponse en ../pos-backend/app/api/v1/orders/schemas.py"
Task: "Añadir total?: string | null a DiningOrder en ../pos-heladeria/src/app/.../dining.interface.ts"

# Una vez implementado, los dos tests de backend en archivos distintos:
Task: "Test de total por estado de facturación en test_orders_pagination.py"
Task: "Test de total == billing.total en test_orders_billing_summary.py"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Completar Phase 1: Setup (ramas en ambos repos)
2. Phase 2: Foundational — vacía, se salta
3. Completar Phase 3: User Story 1 (total en la tarjeta, backend + frontend)
4. **Parar y validar**: quickstart.md §1, de forma independiente
5. Es el defecto de mayor impacto (información de dinero ausente) — entregable solo, si hace falta priorizar

### Incremental Delivery

1. Setup → Foundational (vacía) → listo para empezar
2. US1 (total) → validar con quickstart.md §1 → entregar (MVP)
3. US2 (filtro de fecha) → validar con quickstart.md §2 → entregar
4. US3 (paginador) → validar con quickstart.md §3 → entregar
5. US4 (badges) → validar con quickstart.md §4 → entregar
6. Phase 7 (Polish): regresión completa (quickstart.md §5, SC-005) antes de cerrar la spec

### Parallel Team Strategy

Con más de una persona disponible:

1. Completar Setup juntos (T001/T002)
2. Una persona en US1 (backend + frontend), otra en US2 (archivo independiente) desde el inicio
3. US3 y US4 mejor después de que US1 termine su parte de `orders-page.component.ts` (comparten ese archivo) — evita conflictos de merge, no porque dependan funcionalmente

---

## Notes

- [P] = archivos distintos, sin dependencias pendientes entre sí
- La etiqueta [Story] mapea cada tarea a su historia para trazabilidad (Principio XII de la constitución)
- Cada historia es completable y verificable de forma independiente (quickstart.md, una sección por historia)
- `orders-page.component.ts` es tocado por US1, US3 y US4 — no es una dependencia funcional entre esas historias, pero sí un punto de conflicto de archivo a tener en cuenta al paralelizar
- Commits: solo cuando el usuario lo pida explícitamente, en unidades pequeñas y lógicas, en inglés, sin marcas de autoría de IA (Principio XV) — no implícito en ninguna tarea de este archivo
- Evitar: tareas vagas, conflictos de archivo marcados como [P], dependencias cruzadas entre historias que rompan su independencia
