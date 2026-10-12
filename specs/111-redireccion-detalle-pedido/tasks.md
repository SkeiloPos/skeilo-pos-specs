---

description: "Tareas de la spec 111 — corrección: redirección al detalle del pedido tras crearlo"
---

# Tasks: Corrección — Redirección al detalle del pedido tras crearlo

**Input**: Documentos de diseño de `/specs/111-redireccion-detalle-pedido/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: se incluyen tareas de test. `plan.md` (sección Testing) exige cobertura de Vitest en
`pos-heladeria` y de characterization tests en `pos-backend`, consistente con el Principio X
(Verificación Obligatoria) de la constitución — no solo validación manual.

**Organización**: tres historias de usuario (spec.md: US1 P1, US2 P2, US3 P3), repartidas entre
`../pos-heladeria` (US1, US2, parte de US3) y `../pos-backend` (parte de US3, idempotencia).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: puede ejecutarse en paralelo (archivo distinto, sin dependencia de una tarea sin
  terminar)
- **[Story]**: a qué historia de usuario pertenece (US1, US2, US3)
- Cada tarea incluye la ruta exacta del archivo

## Convenciones de ruta

- `../pos-heladeria/...` — SPA Angular (TypeScript)
- `../pos-backend/...` — API FastAPI (Python)
- Sin prefijo — archivo dentro de este repo (`pos-specs`)

---

## Phase 1: Setup

**Propósito**: preparar las ramas de trabajo en ambos repos y confirmar la línea base antes de
tocar código.

- [X] T001 Crear la rama `fix/111-redireccion-detalle-pedido` desde la rama actual en
  `../pos-heladeria` (confirmar árbol de trabajo limpio antes de crearla; Principio XIV) —
  creada desde `main` (confirmado con el usuario: ambos repos estaban en `main` limpio; `develop`
  no se usó por señal inconsistente entre repos — ver nota en el historial de esta sesión)
- [X] T002 Crear la rama `fix/111-redireccion-detalle-pedido` desde la rama actual en
  `../pos-backend` (confirmar árbol de trabajo limpio antes de crearla; Principio XIV) — misma
  base `main`, mismo criterio que T001
- [X] T003 [P] Buscar en ambos repos tests `"CONGELA comportamiento actual:"` que referencien la
  navegación tras crear un pedido manual, `createManualOrderFromDraft`, `create_order` o el conteo
  de pedidos creados (`grep -rn "CONGELA comportamiento actual"` en
  `../pos-heladeria/src/app/modules/tables/`, `../pos-heladeria/src/app/modules/orders/` y
  `../pos-backend/app/characterization_tests/`); si alguno congela exactamente el destino actual de
  la navegación o la ausencia de idempotencia, registrar en este archivo que su actualización queda
  autorizada por esta spec (Principio III) antes de continuar — **resultado**: el único hit en
  `pos-heladeria/tables/` (`review-step.component.spec.ts:18`) es un comentario que explica por qué
  *no* usa ese prefijo, no un test real. En `pos-backend/app/characterization_tests/`, ninguno de
  los `CONGELA` de `test_orders_service.py`/`test_orders_checkout.py` cubre `create_order` sin
  `client_request_id` ni cuenta pedidos creados por carrito — el único test de idempotencia/doble
  clic existente (`test_orders_checkout.py:952-955`) protege el lock optimista de
  `checkout_and_send` (confirmar/cobrar), no la creación inicial. Nada que autorizar, vía libre.
- [X] T004 [P] Ejecutar `ng test` en `../pos-heladeria` sobre `src/app/modules/tables/` y
  `src/app/modules/orders/` y registrar el resultado como línea base de regresión (Principio X) —
  **línea base**: 808 tests, 805 passed / 3 failed, en 2 archivos
  (`pos-checkout-panel.component.spec.ts` T032, `pos-order-panel.component.spec.ts` ×2 "Marcar
  pedido listo") — mismo conjunto de fallas preexistentes ya documentado en la memoria del
  proyecto y en el tasks.md de la spec 110 (desde spec 084)
- [X] T005 [P] Ejecutar `./env/bin/python -m unittest discover -s app/characterization_tests -p "test_orders_*.py"`
  en `../pos-backend` y registrar el resultado como línea base de regresión (Principio X) —
  **línea base**: 247 tests, OK, cero fallas

**Checkpoint**: ramas creadas en ambos repos, línea base de tests registrada — listo para
implementar la primera historia de usuario.

---

## Phase 2: Foundational (Blocking Prerequisites)

**No aplica a esta spec.** No existe trabajo compartido que bloquee a las tres historias por
igual: US1 y US2 son independientes entre sí, y US3 depende únicamente de que US1 ya exista (ver
Dependencies más abajo), no de un cimiento común adicional.

**Checkpoint**: N/A — continuar directamente a la Fase 3.

---

## Phase 3: User Story 1 - Redirección automática al detalle tras crear el pedido (Priority: P1) 🎯 MVP

**Goal**: tras crear un pedido con éxito (Mesa, Para llevar o Domicilio), el sistema vuelve a la
terminal con ese pedido ya seleccionado y la pestaña correcta activa, mostrando de inmediato sus
ítems y el panel "Cobrar pedido" — en vez de dejar al usuario en la pestaña Mesas sin nada
seleccionado.

> **Hallazgo clave durante la implementación (corrección de rumbo, aprobada por el usuario)**: el
> plan original asumía que "la vista de detalle" era una ruta nueva, `/dashboard/orders/:id`
> (`OrderDetailComponent`). Al implementar se confirmó que ese componente es una página de **solo
> lectura** (el panel admin "Órdenes") **sin ningún panel "Cobrar pedido"** — ese panel
> (literalmente titulado "Cobrar pedido", `pos-checkout-panel.component.ts:224`), el estado por
> ítem "Pendiente" (`kitchenStatusLabel`, `order-status.util.ts:86`) y el encabezado por tipo
> (`headerTitle()`/`headerStatusText()`, `pos-order-panel.component.ts:430-444`: "Mesa {N}" /
> "Para llevar" / "Domicilio" + "en preparación" / "pago pendiente" / "listo para cobrar") viven
> **en la terminal misma** (`/dashboard/mesas-sesiones`), renderizados en el sitio cuando hay un
> pedido seleccionado. La corrección real es más simple que la planeada: en vez de una ruta nueva,
> la navegación de vuelta a `/dashboard/mesas-sesiones` ahora lleva `pestana`/`mesa`/`pedido` como
> query params, y `TableSessionsComponent` los usa para seleccionar lo correcto al cargar — T008,
> T008b, T009, T013 y T014 (que asumían `order-detail.component.ts`) se reemplazaron en
> consecuencia; T010/T015 ya apuntaban al lugar correcto. Los textos literales "Pedido · Mesa N" /
> "Pedido para llevar" / "Pedido a domicilio" de la spec se satisfacen con el título + el estado ya
> existentes de `pos-order-panel.component.ts`, sin reescribir ese texto (evita un cambio visual no
> relacionado en toda la terminal, Principio V/VI) — ver [contracts/order-detail-navigation.md](./contracts/order-detail-navigation.md)
> (reescrito) para el contrato real.

**Independent Test**: crear un pedido de cada uno de los tres tipos desde "Nueva orden" con
productos en el carrito, y confirmar que cada uno vuelve a la terminal con la pestaña y el pedido
correctos ya seleccionados, según la tabla de
[contracts/order-detail-navigation.md](./contracts/order-detail-navigation.md).

### Tests for User Story 1 ⚠️

> Escribir estos tests primero y confirmar que fallan contra el código actual antes de implementar.

- [X] T006 [P] [US1] Test: tras una creación exitosa, `confirm()` llama a `router.navigate` con
  `['/dashboard/mesas-sesiones']` y `queryParams: { pestana, pedido, mesa? }` (uno por tipo de
  pedido) en vez de `['/dashboard/mesas-sesiones']` sin parámetros, en
  `../pos-heladeria/src/app/modules/tables/pages/manual-order-page.component.spec.ts` — **alcance
  corregido**: 3 tests (Mesa/Para llevar/Domicilio), no uno solo con parametrización por `origen`
- [X] T007 [P] [US1] Test: `createManualOrderFromDraft()` permite al llamador obtener el id del
  pedido creado tras una respuesta exitosa (no solo un booleano), en
  `../pos-heladeria/src/app/modules/tables/services/pos-terminal.store.spec.ts` — **resultado**:
  ya pasaba sin cambios de código (ver T011)
- [X] T008 [P] [US1] ~~Test de encabezado en order-detail.component.ts~~ **reemplazada**: Test: con
  `?pestana=mesas&mesa=t1&pedido=o3`, `TableSessionsComponent` activa "mesas", selecciona la mesa
  (`selectTable`) y fija el pedido exacto (`selectOrder`) — en
  `../pos-heladeria/src/app/modules/tables/pages/table-sessions.component.spec.ts`
- [X] T008b [P] [US1] ~~Test de estado/ítems/total en order-detail.component.ts~~ **reemplazada**:
  Test: con `?pestana=para-llevar&pedido=o1` (sin mesa), activa "para-llevar" y selecciona el
  pedido vía `selectStandaloneOrder` (el que carga los datos de cobro, FR-009) — mismo archivo que
  T008
- [X] T009 [P] [US1] ~~Test de back-link en order-detail.component.ts~~ **reemplazada**: Test: con
  `?pestana=domicilios&pedido=o2`, activa "domicilios" y selecciona el pedido, con
  `selectedTableId` en `null` (FR-010, sin mesa) — mismo archivo que T008
- [X] T010 [P] [US1] Test: al inicializar con el query param `pestana` presente y válido
  (`mesas` | `para-llevar` | `domicilios`), `store.orderTypeTab()` queda fijado a ese valor en vez
  del valor por defecto `'mesas'` — y, sin ningún query param o con uno inválido, no hay regresión
  (sigue en "mesas", nada seleccionado), en
  `../pos-heladeria/src/app/modules/tables/pages/table-sessions.component.spec.ts` (el archivo ya
  existía — a diferencia de lo planeado, se agregó un describe nuevo, no uno desde cero)
- [X] T010b [P] [US1] Test de regresión: el botón "Crear pedido" queda deshabilitado y muestra
  "Guardando…" mientras `store.submitting()` es verdadero (FR-005, comportamiento preexistente —
  bloquea una futura regresión silenciosa), en
  `../pos-heladeria/src/app/modules/tables/pages/manual-order-page.component.spec.ts` — mismo
  archivo que T006

### Implementation for User Story 1

- [X] T011 [US1] Modificar `createManualOrderFromDraft()` en
  `../pos-heladeria/src/app/modules/tables/services/pos-terminal.store.ts:1570-1619` para exponer
  al llamador el id del pedido creado tras una respuesta exitosa (ajustando el tipo de retorno o
  reutilizando el signal `selectedOrderId` ya seteado en la línea 1608) — **sin cambio de
  código**: se optó por reutilizar `selectedOrderId` (ya seteado antes del `return true`), evitando
  cambiar el tipo de retorno y así no tocar los `mockResolvedValue(true/false)` de los tests ya
  existentes (alternativa que `research.md` ya dejaba abierta)
- [X] T012 [US1] Modificar el bloque de éxito de `confirm()` en
  `../pos-heladeria/src/app/modules/tables/pages/manual-order-page.component.ts:978-994` para
  navegar a `/dashboard/mesas-sesiones` con `queryParams: { pestana, pedido, mesa? }` —
  **corregido**: ya no navega a una ruta `/orders/:id` nueva; vuelve a la misma ruta de la
  terminal, pero con el pedido y la pestaña correctos como query params (`mesa` solo para tipo
  Mesa, tomado de `store.selectedTableId()`)
- [X] T013 [US1] ~~Ajustar encabezado() en order-detail.component.ts~~ **no se tocó ese archivo**:
  el encabezado real ("Mesa N"/"Para llevar"/"Domicilio" + estado de cocina) ya lo calculan
  `headerTitle()`/`headerStatusText()` en `pos-order-panel.component.ts:430-444`, sin cambios —
  solo faltaba seleccionar correctamente el pedido/mesa (T015) para que se muestren
- [X] T014 [US1] ~~Modificar el back-link en order-detail.component.ts~~ **no aplica**: no existe
  ningún "back-link" separado — el usuario ya está en la terminal; "volver" es simplemente no
  hacer nada más (el pedido queda visible en el panel central)
- [X] T015 [US1] Modificar
  `../pos-heladeria/src/app/modules/tables/pages/table-sessions.component.ts` para leer los query
  params `pestana`/`mesa`/`pedido` al inicializarse: `pestana` válido → `setOrderTypeTab`; `mesa`
  presente → `selectTable` (+ `selectOrder` si también llega `pedido`, para fijar el pedido exacto
  sobre el auto-seleccionado); solo `pedido` (sin `mesa`) → `selectStandaloneOrder`
- [ ] T016 [US1] Ejecutar manualmente los Escenarios 1, 2 y 3 de [quickstart.md](./quickstart.md)
  en un entorno de desarrollo y registrar el resultado de cada uno, incluyendo el conteo de clics
  antes/después para confirmar SC-002 (reducción de al menos 2 clics) — **pendiente**: este
  entorno de implementación no tiene navegador interactivo disponible; se corrió `ng build` +
  la suite completa de Vitest (Fase 6) como equivalente automatizado — la validación manual en
  navegador queda pendiente de que el usuario la confirme

**Checkpoint**: la historia de usuario 1 está completamente funcional y probada de forma
independiente — crear un pedido de cualquier tipo vuelve a la terminal con la pestaña y el pedido
correctos ya seleccionados.

---

## Phase 4: User Story 2 - El carrito se conserva si la creación del pedido falla (Priority: P2)

**Goal**: si el backend responde con error al crear el pedido, el usuario permanece en "Nueva
orden" con el carrito intacto, ve el mensaje "No se pudo crear el pedido. Intenta de nuevo.", y no
queda ningún pedido creado en la terminal.

**Independent Test**: simular un error del servidor en `POST /orders` con productos en el carrito,
pulsar "Crear pedido", y confirmar que la vista sigue siendo "Nueva orden" con el carrito sin
cambios, el mensaje de error visible, y ningún pedido nuevo en ninguna pestaña de la terminal.

### Tests for User Story 2 ⚠️

> Escribir estos tests primero y confirmar que fallan contra el código actual antes de implementar.

- [X] T017 [P] [US2] Test: ante un error de `createManualOrderFromDraft()`, `confirm()` NO navega a
  ninguna vista y el estado del carrito/draft permanece sin cambios, en
  `../pos-heladeria/src/app/modules/tables/pages/manual-order-page.component.spec.ts`
- [X] T018 [P] [US2] Test: ante un error HTTP en `POST /orders`, `store.error()` queda exactamente
  en "No se pudo crear el pedido. Intenta de nuevo." y ningún pedido se agrega a los signals de
  pedidos de la terminal, en
  `../pos-heladeria/src/app/modules/tables/services/pos-terminal.store.spec.ts`

### Implementation for User Story 2

- [X] T019 [US2] Actualizar el mensaje de error en `createManualOrderFromDraft()`
  (`../pos-heladeria/src/app/modules/tables/services/pos-terminal.store.ts:1613-1614`) de
  "No se pudo crear el pedido." a "No se pudo crear el pedido. Intenta de nuevo." (texto exacto
  exigido por FR-004)
- [X] T020 [US2] Confirmar que el carrito/draft de `manual-order-page.component.ts` no se limpia ni
  se resetea en la rama de error de `confirm()`; si ya es el comportamiento actual, dejar
  constancia de ello en el propio test T017 en vez de modificar código de producción —
  **confirmado sin cambios**: `draftLines.set([])` en el store solo corre dentro del `try`,
  después del `await` exitoso (línea 1609); en la rama `catch` nunca se toca, así que el carrito
  ya quedaba intacto por construcción
- [ ] T021 [US2] Ejecutar manualmente el Escenario 4 de [quickstart.md](./quickstart.md) y
  registrar el resultado — **pendiente de validación manual en navegador** (mismo motivo que T016)

**Checkpoint**: la historia de usuario 2 está completamente funcional y probada de forma
independiente — un error de servidor nunca pierde el carrito ni crea un pedido fantasma.

---

## Phase 5: User Story 3 - Un pedido no se duplica por doble clic ni por reintento de red (Priority: P3)

**Depends on**: User Story 1 (Phase 3) — el escenario de esta historia exige que, tras el doble
clic, "se abra el detalle de ese único pedido", reutilizando la navegación implementada en US1.

**Goal**: ni un doble clic en "Crear pedido" ni un reintento de red sobre la misma solicitud
generan más de un pedido; el backend garantiza esto mediante idempotencia (FR-011) además de la
guarda ya existente a nivel de botón en la interfaz (FR-006).

**Independent Test**: hacer doble clic rápido en "Crear pedido" con productos en el carrito y
confirmar que se crea un único pedido cuyo detalle se abre; además, reenviar por HTTP la misma
solicitud `POST /orders` con idéntico `client_request_id` y confirmar que solo existe una fila en
`customer_orders`.

### Tests for User Story 3 ⚠️

> Escribir estos tests primero y confirmar que fallan contra el código actual antes de implementar.

- [X] T022 [P] [US3] Test: dos llamadas a `create_order()` con el mismo `client_request_id`
  devuelven el mismo `CustomerOrder.id` y solo existe una fila en `customer_orders`, en
  `../pos-backend/app/characterization_tests/test_orders_service.py` (clase
  `TestCreateOrderIdempotencia`, no un archivo nuevo)
- [X] T023 [P] [US3] Test de regresión: dos llamadas a `create_order()` sin `client_request_id`
  siguen creando dos pedidos distintos (retrocompatibilidad) — mismo archivo que T022
- [X] T024 [P] [US3] Test: dos llamadas a `create_order()` con `client_request_id` distinto crean
  dos pedidos distintos — mismo archivo que T022
- [X] T025 [P] [US3] Test: una segunda invocación de `createManualOrderFromDraft()` mientras la
  primera está en curso (`submitting()` en verdadero) no dispara una segunda llamada HTTP, en
  `../pos-heladeria/src/app/modules/tables/services/pos-terminal.store.spec.ts` — más un test
  adicional no planeado: un reintento tras error reenvía el mismo `client_request_id`, y un
  intento posterior exitoso usa uno nuevo (cubre T029 de punta a punta)

### Implementation for User Story 3

- [X] T026 [US3] Crear una migración Alembic en `../pos-backend/alembic/versions/` que añade la
  columna nullable `client_request_id` (string) a `customer_orders` y su índice único parcial
  (`UNIQUE (client_request_id) WHERE client_request_id IS NOT NULL`), con un `downgrade()` que
  revierte ambos (ver [data-model.md](./data-model.md)) —
  `30f5e7b0ef5f_111_idempotencia_creacion_pedidos.py` (el hash `a1b2c3d4e5f6` pensado originalmente
  ya estaba en uso por `a1b2c3d4e5f6_promotions_refactor.py`; se generó uno nuevo). **Validación**:
  `alembic upgrade head` falló por una inconsistencia preexistente del entorno (la fila de
  `public.alembic_version` apunta a `42dc063d8185`, una revisión que no existe en ningún archivo
  de este checkout — no causada por esta spec). Se validó el DDL exacto de `upgrade()`/`downgrade()`
  directamente contra el schema real `heladeria3` (índice único parcial permite varios `NULL`,
  rechaza un valor real duplicado con `UniqueViolation`) y se revirtió todo, dejando el esquema
  exactamente como estaba
- [X] T027 [US3] Añadir `client_request_id: str | None = None` a `OrderCreate` en
  `../pos-backend/app/api/v1/orders/schemas.py:125-148`
- [X] T028 [US3] Modificar `create_order()` en
  `../pos-backend/app/api/v1/orders/service.py:448` para que, si `data.client_request_id` está
  presente, busque primero un `CustomerOrder` existente con ese valor y lo devuelva sin insertar
  uno nuevo; si no existe, inserte el pedido guardando el valor recibido (ver
  [contracts/post-orders.md](./contracts/post-orders.md))
- [X] T029 [US3] Generar un `client_request_id` (`crypto.randomUUID()`) una sola vez por intento de
  "Crear pedido" en
  `../pos-heladeria/src/app/modules/tables/services/pos-terminal.store.ts`
  (`createManualOrderFromDraft()`) y reenviarlo sin cambios si esa misma llamada se reintenta sobre
  el mismo carrito — campo privado `pendingCreateRequestId`, asignado con `??=` y limpiado solo
  tras una creación exitosa
- [X] T030 [US3] Añadir una guarda defensiva dentro de `createManualOrderFromDraft()` (no solo el
  `[disabled]` del botón en la plantilla) que ignore una invocación mientras `submitting()` ya es
  verdadero (FR-006)
- [ ] T031 [US3] Ejecutar manualmente los Escenarios 5 y 6 de [quickstart.md](./quickstart.md) y
  registrar el resultado — **pendiente de validación manual en navegador** (mismo motivo que T016)

**Checkpoint**: la historia de usuario 3 está completamente funcional y probada de forma
independiente (sobre la base de US1) — ningún doble clic ni reintento de red duplica un pedido, ni
en frontend ni en backend.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Propósito**: cerrar la verificación global antes de dar la spec por completada.

- [X] T032 [P] Ejecutar la suite completa de `ng test` en `../pos-heladeria` y confirmar que no se
  rompió ningún test existente fuera del alcance de esta spec (Principio X) — **resultado**:
  `tables/`+`orders/`: 820 tests, 817 passed / 3 failed, en los mismos 2 archivos de la línea base
  de T004 (`pos-checkout-panel` T032, `pos-order-panel` ×2 "Marcar pedido listo", preexistentes
  desde spec 084) — ninguna falla nueva; +12 tests nuevos, todos en verde. `ng build` también
  compila sin errores nuevos
- [X] T033 [P] Ejecutar la suite completa de characterization tests relacionados con `orders` en
  `../pos-backend` y confirmar ausencia de regresiones fuera del alcance de esta spec (Principio X)
  — **resultado**: `test_orders_*.py`: 250 tests (247 de línea base + 3 nuevos), OK. Suite
  completa (`test_*.py`, 1480 tests): OK
- [X] T034 Releer el Constitution Check de [plan.md](./plan.md) tras implementar y confirmar que
  ninguna entrada nueva en `specs/000-reconocimiento/registro-de-anomalias.md` resultó necesaria —
  confirmado: el cambio corrige a dónde navega la terminal tras crear un pedido y añade
  idempotencia a un endpoint ya existente; no redefine ninguna regla de negocio de precio,
  inventario o facturación. T003 no encontró ningún characterization test afectado
- [ ] T035 Ejecutar manualmente los Escenarios 7 y 8 de [quickstart.md](./quickstart.md) (recarga
  del navegador, no regresión en el acceso desde "Órdenes") y registrar el resultado —
  **pendiente de validación manual en navegador** (mismo motivo que T016; nota: el Escenario 8
  original de quickstart.md describía `/dashboard/orders/:id`, que ya no aplica — ver quickstart.md
  reescrito)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias — puede iniciar de inmediato
- **Foundational (Phase 2)**: N/A, no bloquea nada
- **User Story 1 (Phase 3)**: depende de Setup (T001-T005) completo
- **User Story 2 (Phase 4)**: depende de Setup completo; independiente de User Story 1 (puede
  implementarse en paralelo o en cualquier orden respecto a la Fase 3)
- **User Story 3 (Phase 5)**: depende de Setup completo **y** de que User Story 1 (Phase 3) esté
  implementada (reutiliza su navegación al detalle)
- **Polish (Phase 6)**: depende de que las Fases 3, 4 y 5 estén completas

### Within User Story 1

- Tests (T006-T010, T008b, T010b) se escriben primero y deben fallar contra el código actual
- T011 (exponer el id creado en el store) bloquea T012 (la navegación necesita ese id) — resultó
  ser un no-op (ver notas), pero la dependencia lógica sigue siendo correcta
- T012 (navega con `pestana`/`mesa`/`pedido`) y T015 (`TableSessionsComponent` los lee) son las dos
  mitades del mismo contrato — ninguna por separado cambia el comportamiento observable
- T013/T014 quedaron sin aplicar (ver notas: el archivo que iban a tocar no era el correcto)
- T016 (validación manual) va al final, después de T011/T012/T015

### Within User Story 2

- Tests (T017-T018) se escriben primero y deben fallar contra el código actual
- T019 y T020 son independientes entre sí (archivos/aspectos distintos)
- T021 (validación manual) va al final

### Within User Story 3

- Tests (T022-T025) se escriben primero y deben fallar contra el código actual
- T026 (migración) bloquea T027 y T028 (ambas asumen que la columna ya existe)
- T027 bloquea T028 (el servicio necesita el campo en el schema)
- T029 (frontend genera y envía `client_request_id`) es independiente de T026-T028 (repos
  distintos), pero ambos lados deben completarse para que el Escenario 6 de punta a punta funcione
- T030 es independiente de T026-T029
- T031 (validación manual) va al final

### Parallel Opportunities

- T003, T004, T005 pueden ejecutarse en paralelo (todas de solo lectura/verificación)
- T006, T007, T008, T008b, T009, T010, T010b pueden escribirse en paralelo (archivos distintos o
  aspectos independientes del mismo archivo)
- T017, T018 pueden escribirse en paralelo
- T022, T023, T024, T025 pueden escribirse en paralelo
- Las Fases 3 (US1) y 4 (US2) pueden avanzar en paralelo entre sí una vez completada la Fase 1
- T032 y T033 pueden ejecutarse en paralelo; T034 puede revisarse en paralelo con ambas

---

## Parallel Example: User Story 1

```bash
# Lanzar los tests de la historia de usuario 1 juntos:
Task: "Test: confirm() navega a /dashboard/mesas-sesiones con pestana/pedido/mesa (T006)"
Task: "Test: createManualOrderFromDraft() expone el id creado vía selectedOrderId (T007)"
Task: "Test: table-sessions, pestana=mesas+mesa+pedido → selectTable + selectOrder (T008)"
Task: "Test: table-sessions, pestana=para-llevar+pedido (sin mesa) → selectStandaloneOrder (T008b)"
Task: "Test: table-sessions, pestana=domicilios+pedido → selectedTableId null (T009)"
Task: "Test: table-sessions, sin query params o inválidos → sin regresión (T010)"
Task: "Test de regresión: botón deshabilitado + indicador de carga (T010b)"
```

## Parallel Example: User Story 3

```bash
# Lanzar los tests de idempotencia del backend juntos:
Task: "Test: mismo client_request_id devuelve el mismo pedido (T022)"
Task: "Test: sin client_request_id, dos pedidos distintos (T023)"
Task: "Test: client_request_id distinto, dos pedidos distintos (T024)"
Task: "Test: segunda invocación en curso no dispara una segunda llamada HTTP (T025)"
```

---

## Implementation Strategy

### MVP primero

1. Completar Fase 1: Setup (ramas en ambos repos + línea base)
2. Fase 2: N/A, pasar directo a Fase 3
3. Completar Fase 3: User Story 1 (tests → navegación con `pestana`/`mesa`/`pedido` → lectura de
   esos params en la terminal → validación manual)
4. **DETENER y VALIDAR**: confirmar los Escenarios 1-3 de `quickstart.md` — este es el MVP que
   resuelve el problema de negocio reportado (redirección automática para los tres tipos de
   pedido)

### Entrega incremental

5. Completar Fase 4: User Story 2 (protección del carrito ante errores) — puede hacerse antes,
   después o en paralelo con la Fase 3
6. Completar Fase 5: User Story 3 (idempotencia frontend + backend) — requiere que la Fase 3 ya
   esté terminada
7. Completar Fase 6: Polish (regresión completa en ambos repos + cierre de gobernanza)

### Notas

- `[P]` = archivos distintos o verificación de solo lectura, sin dependencia de una tarea sin
  terminar
- `[US1]`/`[US2]`/`[US3]` identifica a qué historia de usuario pertenece cada tarea
- Confirmar que los tests fallan antes de implementar (tests de cada fase antes de su
  implementación)
- Los commits solo se ejecutan si el usuario lo pide explícitamente, en unidades pequeñas y
  lógicas, en inglés, sin marcas de autoría de IA (Principio XV)
