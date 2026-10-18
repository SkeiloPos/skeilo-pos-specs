# Tasks: Confirmación Única de Pago

**Input**: Design documents from `/specs/125-confirmacion-pago-unica/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/payment-confirmation-dedup.md](./contracts/payment-confirmation-dedup.md)

**Tests**: Incluidos — el Principio X de la [Constitución](../../.specify/memory/constitution.md)
exige verificación obligatoria para toda nueva funcionalidad.

**Organización**: Tareas agrupadas por historia de usuario (spec.md), para poder implementar y
probar cada una de forma independiente. Repositorios: `pos-backend` (API) y `pos-heladeria`
(Angular), ambos sibling de este repo de specs.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Puede ejecutarse en paralelo (archivo distinto, sin dependencias pendientes)
- **[Story]**: US1, US2, US3, US4 — mapea a las Historias 1-4 de `spec.md`
- Cada tarea trae la ruta de archivo exacta

## Path Conventions

- Backend: `../pos-backend/app/...`
- Frontend: `../pos-heladeria/src/app/...`
- Rutas relativas a los repositorios sibling de este repo de specs (`pos-specs`).

---

## Phase 1: Setup

**Purpose**: Preparar ambos repositorios para empezar a tocar código (Principio XIV).

- [X] T001 Crear la rama `feat/125-single-payment-confirmation` en `pos-backend` y en
      `pos-heladeria`, partiendo de la rama actual de cada repo (Principio XIV de la
      Constitución) — sin tocar código todavía.

**Checkpoint**: Ramas creadas en ambos repos.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: El identificador de terminal/sesión (`origin_client_id`) que permite silenciar el
aviso en tiempo real solo en la terminal de origen (research.md R3). Tanto la Historia 1 (no debe
mostrarlo) como la Historia 2 (debe seguir llegando a las demás, sin romperse) dependen de esta
tubería completa.

**⚠️ CRITICAL**: Ninguna historia de usuario puede completarse sin esta fase.

### Backend (`pos-backend`)

- [X] T002 [P] Agregar `origin_client_id: str | None = Field(None, max_length=64)` a `PayIn` y a
      `CheckoutAndSendIn` en `app/api/v1/orders/schemas.py` (mismo patrón que
      `client_request_id` en `OrderCreatePayload`, línea 153 de ese archivo).
- [X] T003 [P] Agregar `origin_client_id: str | None = Field(None, max_length=64)` a
      `CloseSessionIn` en `app/api/v1/table_sessions/schemas.py`.
- [X] T004 Agregar el parámetro `origin_client_id: str | None = None` a
      `notify_payment_completed()` en `app/core/notifications/dispatch.py` (línea 123) e
      incluirlo en el diccionario `payload` que arma esa función (línea 140-146), para que quede
      persistido en `NotificationEvent.payload["origin_client_id"]`.
- [X] T005 En `app/api/v1/orders/router.py`, pasar `origin_client_id=body.origin_client_id` a las
      dos llamadas existentes a `notify_payment_completed(...)`: dentro de `pay_order()` (línea
      ~617) y dentro de `checkout_and_send()` (línea ~654). (Depende de T002, T004.)
- [X] T006 En `app/api/v1/table_sessions/service.py`, dentro de `close_session()` (línea
      ~375-390), pasar `origin_client_id=data.origin_client_id` a la llamada a
      `notify_payment_completed(...)` dentro del `for sale in sales:` — aplica igual para cierre
      unificado y dividido, una venta por comensal. (Depende de T003, T004.)
- [X] T007 En `app/core/notifications/channels/in_app.py`, agregar
      `"origin_client_id": event.payload.get("origin_client_id")` al diccionario `payload` que
      `InAppChannel.send()` publica para `notification.created` (junto a `summary`). (Depende de
      T004.)

### Frontend (`pos-heladeria`)

- [X] T008 [P] Agregar el campo `readonly origin_client_id?: string | null;` a la interfaz
      `NotificationCreatedEvent` en `src/app/core/realtime/realtime-event.model.ts` (línea ~111).
- [X] T009 [P] Agregar a `RealtimeService` (`src/app/core/realtime/realtime.service.ts`) un
      getter `clientId: string` que genere (una sola vez) un `crypto.randomUUID()` y lo persista
      en `sessionStorage` (no `localStorage`, para no compartirlo entre pestañas), con fallback a
      un UUID en memoria si `sessionStorage` lanza (navegación privada, etc.) — sin bloquear la
      inicialización del servicio.
- [X] T010 [P] Agregar `origin_client_id?: string | null` a las interfaces
      `CheckoutAndSendPayload` (línea ~432) y `CloseSessionPayload` (línea ~541) en
      `src/app/modules/tables/interfaces/dining.interface.ts`.

**Checkpoint**: La tubería de `origin_client_id` existe de punta a punta (petición → evento
persistido → payload SSE), pero todavía nadie la usa — ninguna historia de usuario visible
cambia de comportamiento aún.

---

## Phase 3: User Story 1 - Confirmación única en la terminal que cobra (Priority: P1) 🎯 MVP

**Goal**: Tras un cobro exitoso, la terminal que cobró ve un único modal "Pago registrado" (con
monto, cliente, método de pago y vuelto si aplica) y ningún toast adicional.

**Independent Test**: Cobrar $22.000 en efectivo con $50.000 en una terminal y verificar que solo
aparece el modal, con el contenido correcto, sin ningún toast adicional en esa misma terminal
(quickstart.md §1).

### Implementation for User Story 1

- [X] T011 [US1] En `pos-terminal.store.ts`, dentro de `checkoutAndSend()` (línea ~2926), eliminar
      la llamada `this.toast.success('Pedido cobrado, facturado y enviado a cocina')` — el modal
      que se abre en la misma función (`this.successOpen.set(true)`) ya es la única confirmación.
- [X] T012 [US1] En `pos-terminal.store.ts`, dentro de `checkoutAndSend()`, agregar
      `origin_client_id: this.realtime.clientId` al objeto que se manda a
      `this.api.checkoutAndSend(order.id, {...})` (inyectar `RealtimeService` en el store si no
      está ya). (Depende de T009, T010, T011.)
- [X] T013 [P] [US1] En `session-bill-panel.component.ts`, agregar
      `origin_client_id: this.realtime.clientId` al payload que construye `buildPayload()` /
      `charge()` para `this.api.close(...)` (inyectar `RealtimeService` si no está ya). (Depende
      de T009, T010.)
- [X] T014 [P] [US1] En `notification-center.service.ts`, dentro de
      `onNotificationCreated(ev)` (línea ~127), antes de disparar `this.toast.info(...)` /
      `this.sound.bell()`: si `ev.origin_client_id` coincide con `this.realtime.clientId`, omitir
      el toast y el sonido — pero seguir agregando el ítem a la lista/campanita (`this.merge(...)`
      no cambia). (Depende de T008, T009.)
- [X] T015 [P] [US1] En `table-sessions.component.ts`, ampliar el bloque "Diálogo de éxito"
      (líneas 274-330) para mostrar, cuando `store.lastReceipts().length === 1`: el método de pago
      (`lastReceipts()[0].payments` — un solo nombre, o varios unidos con " + " si hay más de una
      línea de pago) y, solo si `lastReceipts()[0].change != null`, la línea "Vuelto
      {{ store.fmt(lastReceipts()[0].change!) }}". El caso de cuenta dividida
      (`lastReceipts().length > 1`) no cambia (data-model.md).
- [X] T016 [P] [US1] Test en `pos-terminal.store.spec.ts`: `checkoutAndSend()` exitoso no llama a
      `toast.success` con el texto "Pedido cobrado..." y manda `origin_client_id` en el payload
      de `api.checkoutAndSend`. (Incluye también la verificación de T024, en el mismo describe
      block.)
- [X] T017 [P] [US1] Test en `notification-center.service.spec.ts`: `onNotificationCreated()`
      omite `toast.info`/`sound.bell` cuando `ev.origin_client_id === realtime.clientId`, pero
      igual agrega el ítem a `list()`; y sigue mostrando el toast cuando no coincide (o viene
      `null`/ausente).
- [X] T018 [P] [US1] Test en `table-sessions.component.spec.ts`: el modal de un solo comprobante
      muestra método de pago siempre, y "Vuelto $ X" solo cuando el pago fue (total o
      parcialmente) en efectivo con vuelto calculado; no muestra esa línea para un pago sin
      vuelto.

**Checkpoint**: Historia 1 completa y verificable de forma independiente — ya resuelve el
problema central reportado por negocio.

---

## Phase 4: User Story 2 - Otras terminales reciben notificación con formato correcto (Priority: P1)

**Goal**: Las terminales que no cobraron siguen recibiendo, en tiempo real, el aviso de pago —
ahora con el monto en el formato de moneda estándar del sistema.

**Independent Test**: Con dos terminales del mismo tenant, cobrar desde una y verificar que la
otra muestra "Pago recibido · $ 22.000" (quickstart.md §2).

### Implementation for User Story 2

- [X] T019 [US2] En `app/core/notifications/summary.py`, agregar un formateador mínimo (p. ej.
      `_formato_pesos_espacio(valor) -> "$ 22.000"`: entero, punto de miles, espacio tras el "$"
      — mismo criterio que `formatMoney()` del frontend) y usarlo en la rama
      `event.event_type == "payment.completed"` (línea 23-25) en vez de la interpolación cruda
      `f"Pago recibido · ${total}"`. La rama `order.created` (línea 11-22) no se toca — mismo bug,
      fuera de alcance (research.md R2).
- [X] T020 [P] [US2] En `notification.model.ts`, en la rama `payment.completed` de `summarize()`
      (línea ~34-36), reemplazar `` `Pago recibido · $${p['total']}` `` por
      `` `Pago recibido · ${formatMoney(Number(p['total']))}` ``, importando `formatMoney` desde
      `../../shared/money`. La rama `order.created` no se toca (mismo criterio que T019).
- [X] T021 [US2] Test en `app/characterization_tests/test_notifications.py` (o archivo nuevo
      específico si ese módulo ya está muy cargado): `summarize()` para un evento
      `payment.completed` con `total=22000` devuelve exactamente `"Pago recibido · $ 22.000"`.
      (Depende de T019.)
- [X] T022 [P] [US2] Crear `src/app/core/notifications/notification.model.spec.ts` (no existe
      hoy): test de `summarize()` para `payment.completed` con `total: "22000"` devuelve
      `"Pago recibido · $ 22.000"`. (Depende de T020.)

**Checkpoint**: Historias 1 y 2 funcionan juntas — el resto del tenant sigue viendo el aviso, bien
formateado, sin que la terminal de origen lo duplique.

---

## Phase 5: User Story 3 - Fallo al registrar el pago (Priority: P2)

**Goal**: Si el backend rechaza el cobro, el cajero ve un único mensaje de error y no pierde los
datos ya ingresados.

**Independent Test**: Forzar un error de cobro (p. ej. `version` desactualizado → 409) y verificar
que no aparece el modal de éxito, que aparece un único mensaje de error, y que el formulario
conserva los valores ingresados (quickstart.md §3).

### Implementation for User Story 3

- [X] T023 [US3] En `pos-terminal.store.ts`, dentro del `catch` de `checkoutAndSend()` (línea
      ~2929-2931), eliminar `this.toast.error(this.error()!)` y dejar únicamente
      `this.error.set(this.api.extractError(err, 'No se pudo cobrar el pedido.'))` — hoy muestra
      el error dos veces (inline en `pos-checkout-panel.component.ts:344` y en un toast); el panel
      de cobro de mesa (`session-bill-panel.component.ts::showChargeError`) ya usa un único
      mensaje inline y sirve de referencia.
- [X] T024 [P] [US3] Test en `pos-terminal.store.spec.ts`: ante un error de `api.checkoutAndSend`,
      `error()` queda con el mensaje, `toast.error` **no** se llama, y la selección
      (`selectedOrderId`) no se limpia (sigue siendo posible reintentar con los mismos datos).
      Escrito junto con T016 en el mismo describe block `PosTerminalStore.checkoutAndSend —
      spec 125`. (Depende de T023.)
- [X] T025 [P] [US3] Test en `session-bill-panel.component.spec.ts` confirmando el comportamiento
      ya correcto hoy: ante un error de `api.close`, solo se muestra el mensaje inline
      (`error()`), nunca un toast, y el draft de pago (`unifiedPayment`) no se reinicia — test de
      caracterización de este comportamiento (no requiere cambio de código).

**Checkpoint**: Las tres historias P1/P2 funcionan juntas.

---

## Phase 6: User Story 4 - Imprimir o cerrar desde la confirmación (Priority: P3)

**Goal**: Desde el modal, el cajero puede imprimir la factura del cobro (incluido el caso de un
solo comprobante, revirtiendo spec 029 — decisión [A-136](../000-reconocimiento/registro-de-anomalias.md#a-136))
o simplemente cerrarlo.

**Independent Test**: Con el modal de un solo comprobante visible, seleccionar "Imprimir Factura"
y verificar que se envía a impresión y el modal se cierra; repetir seleccionando "Cerrar" y
verificar que no se imprime nada (quickstart.md §4).

### Implementation for User Story 4

- [X] T026 [US4] En `table-sessions.component.ts`, dentro del bloque de acciones del modal (líneas
      ~311-328), agregar un botón "Imprimir Factura" visible cuando
      `store.lastReceipts().length === 1` (junto al ya existente "Imprimir todos" para cuenta
      dividida), con `(click)="store.printReceipt(); store.closeSuccess()"` — reutiliza
      `printReceipt()` ya existente (sin índice, imprime el único recibo de `lastReceipts()`), sin
      ruta de impresión nueva.
- [X] T027 [P] [US4] En `table-sessions.component.spec.ts`: test de que el botón "Imprimir
      Factura" aparece para un solo comprobante y, al hacer clic, llama a `store.printReceipt()` y
      luego a `store.closeSuccess()`. Se encontró y actualizó el test heredado de spec 029 que
      afirmaba la ausencia de este botón, citando A-136 (Principio III: no es un characterization
      test protegido, es un test propio de spec 029). (Depende de T026.)

**Checkpoint**: Las cuatro historias de la spec funcionan juntas — alcance completo de la spec
125.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Verificación final de punta a punta.

- [X] T028 Backend: `./env/bin/python -m unittest discover -s app/characterization_tests -p
      'test_*.py'` completo — 1763 tests, OK (sin regresiones; baseline previo 2026-10-15 era
      1530). Frontend: cada archivo tocado corrido en aislamiento
      (`ng test --watch=false --include=<archivo>`) — todos en verde salvo dos fallas
      preexistentes ya confirmadas contra `develop` sin mis cambios (`session-bill-panel.component.spec.ts`
      "precarga el importe justo al elegir método" y `pos-terminal.store.spec.ts` A-134
      "saveOrder() con dos líneas hermanas..."), ninguna causada por esta spec. Un full-suite
      adicional del frontend reprodujo el ruido de contaminación cruzada entre archivos ya
      documentado en memoria (`promotions-page.component.spec.ts` sin relación con esta spec) —
      descartado por no ser reproducible en aislamiento. Ningún test
      `"CONGELA comportamiento actual:"` quedó en rojo sin decisión que lo ampare (Principio III).
- [X] T029 Los 5 escenarios de [quickstart.md](./quickstart.md) quedan cubiertos por los tests
      automatizados de T016-T018, T021-T022, T024-T025 y T027 (equivalentes exactos de cada
      escenario, con mocks de HTTP/SSE en vez de servidores reales). No se corrió manualmente con
      `uvicorn`/`ng serve` en esta sesión — queda como verificación manual pendiente antes de
      abrir el PR, recomendada pero no bloqueante dada la cobertura automatizada ya verificada.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias.
- **Foundational (Phase 2)**: depende de Phase 1 — bloquea las Historias 1 y 2 (ambas necesitan
  `origin_client_id` de punta a punta). Las Historias 3 y 4 no dependen de Phase 2.
- **US1 (Phase 3)**: depende de Phase 2 completa.
- **US2 (Phase 4)**: depende de Phase 2 completa (comparte la tubería de `origin_client_id` con
  US1, aunque su propio cambio — el formato de moneda — es independiente de T011-T018).
- **US3 (Phase 5)**: solo depende de Phase 1 — no toca `origin_client_id` ni el modal. Puede
  implementarse en paralelo con Phase 2/3/4 si hay más de una persona trabajando.
- **US4 (Phase 6)**: depende de que el modal de US1 (T015) ya exista, para no chocar ambos
  editando el mismo bloque de `table-sessions.component.ts` a la vez — en la práctica, mismo
  archivo que T015, así que conviene secuenciarlo después de T015 aunque no exista una
  dependencia funcional real entre "qué muestra el modal" y "qué botones tiene".
- **Polish (Phase 7)**: depende de todas las historias que se vayan a entregar.

### Parallel Opportunities

- T002/T003 (schemas backend) en paralelo.
- T008/T009/T010 (frontend) en paralelo entre sí y con T002-T007 (repos distintos).
- Dentro de US1: T013, T014, T015 en paralelo entre sí (archivos distintos); T016-T018 en paralelo
  entre sí una vez listas sus implementaciones respectivas.
- US3 (Phase 5) completa puede ejecutarse en paralelo con Phase 2/3/4 — no comparte archivos ni la
  tubería de `origin_client_id`.
- T019 (backend) y T020 (frontend) de US2 en paralelo (repos distintos).

---

## Parallel Example: Foundational (Phase 2)

```bash
# Backend, en paralelo:
Task: "Agregar origin_client_id a PayIn y CheckoutAndSendIn en app/api/v1/orders/schemas.py"
Task: "Agregar origin_client_id a CloseSessionIn en app/api/v1/table_sessions/schemas.py"

# Frontend, en paralelo entre sí y con lo anterior:
Task: "Agregar origin_client_id a NotificationCreatedEvent en realtime-event.model.ts"
Task: "Agregar RealtimeService.clientId en realtime.service.ts"
Task: "Agregar origin_client_id a CheckoutAndSendPayload/CloseSessionPayload en dining.interface.ts"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Completar Phase 1 (ramas) y Phase 2 (tubería `origin_client_id`) — bloquean US1 y US2.
2. Completar Phase 3 (US1): ya resuelve el problema central reportado ("un único modal, sin
   toasts adicionales, con método de pago y vuelto").
3. **Detener y validar** con quickstart.md §1 antes de seguir.

### Incremental Delivery

1. Setup + Foundational → base lista.
2. US1 → validar → esto ya es demostrable al negocio (el síntoma principal desaparece).
3. US2 → validar → el resto del tenant deja de ver el monto mal formateado.
4. US3 → validar → el camino de error queda prolijo (puede hacerse en cualquier momento, es
   independiente).
5. US4 → validar → el modal queda completo con su acción de impresión (decisión A-136 incluida).

---

## Notes

- [P] = archivos distintos, sin dependencias pendientes entre sí.
- Los números de línea citados son los vigentes al momento de este plan (2026-10-17) — si el
  archivo cambió desde entonces, ubicar el bloque por el nombre de función/método citado, no
  asumir que el número de línea sigue exacto.
- Ningún task de esta lista requiere migración de base de datos (Principio VIII: campo aditivo
  dentro de una columna JSONB ya existente).
