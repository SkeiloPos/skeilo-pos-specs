---

description: "Task list template for feature implementation"
---

# Tasks: Pago antes de cocina para pedidos de mesa (QR) con módulo de cocina activo

**Input**: Design documents from `/specs/153-cobro-previo-cocina-qr/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Incluidos — `plan.md` exige extender characterization tests (Principio III) y
`quickstart.md` define una verificación automatizada mínima explícita en ambos repos.

**Organización**: Las tareas están agrupadas por historia de usuario. US1 y US3 son P1 y
comparten la mayor parte del código tocado (son, literalmente, las dos ramas de los mismos
`if`), así que US3 se implementa y valida junto con US1, no por separado. US2 (P2) depende de
que US1 exista (un pedido debe llegar a cocina cobrado antes de poder entregarse).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Puede ejecutarse en paralelo (archivos distintos, sin dependencias)
- **[Story]**: Historia de usuario a la que pertenece (US1, US2, US3)

## Path Conventions

Dos repositorios independientes, sibling de `pos-specs`:

- Backend: `../pos-backend/app/...`
- Frontend: `../pos-heladeria/src/app/...`

---

## Phase 1: Setup (Registro de anomalías — obligación de proceso)

**Purpose**: Cumplir el Principio II de la constitución (registro previo a implementar)
antes de tocar cualquier código. Bloquea todas las fases siguientes.

- [X] T001 Registrar la entrada `A-155 — [DECISIÓN DE NEGOCIO — spec 153]` en
  `specs/000-reconocimiento/registro-de-anomalias.md` (al final del documento, siguiendo el
  formato de las entradas `A-153`/`A-154`), documentando: qué cambia (`_assert_closable`/
  `ensureReadyToCharge` deja de exigir entrega previa al cobro de mesa con módulo de Cocina
  activo; `deliver_order` exige `kitchen_status=='LISTO'` cuando antes no exigía nada; envío
  automático a cocina tras cobro 100%), por qué (autorizado por
  `specs/153-cobro-previo-cocina-qr/spec.md`, Clarifications 2026-11-05, FR-001 a FR-004),
  quién y cuándo (sesión de clarificación de la spec 153, 2026-11-05, antes de implementar),
  funcionalidades afectadas (`_charge_session`/`close_session`/`charge_session`
  (`table_sessions/service.py`), `deliver_order`/`send_to_kitchen` (`orders/kitchen.py`),
  `ensureReadyToCharge` (`pos-terminal.store.ts`)), riesgo asumido, y los characterization
  tests que se van a actualizar en el mismo commit que el código que los provoca
  (`app/characterization_tests/test_orders_kitchen.py`)

**Checkpoint**: Entrada registrada y commiteada antes de cualquier cambio de código de las
fases siguientes.

---

## Phase 2: Foundational

**Purpose**: No hay infraestructura nueva que crear (sin entidades, sin migraciones, sin
dependencias nuevas — ver `plan.md`/`data-model.md`). El único prerrequisito real ya quedó
cubierto en la Fase 1.

**Checkpoint**: No aplica ninguna tarea adicional — se pasa directo a las historias de
usuario.

---

## Phase 3: User Story 1 — Cobrar el pedido de mesa antes de que cocina lo prepare (Priority: P1) 🎯 MVP

**Goal**: Con el módulo de Cocina activo, cobrar un pedido de mesa por QR lo paga y lo envía
a cocina en un mismo paso, sin pasar antes por "Entregar", y solo cuando el 100% de lo
cobrado para ese pedido/sesión queda pagado.

**Independent Test**: Con el módulo de Cocina activo, crear un pedido desde el menú QR de
una mesa, recibirlo, y cobrarlo. Confirmar que: (a) antes de cobrar, la cocina no tiene
ningún ticket de ese pedido; (b) al cobrar, el pedido se marca como pagado y aparece de
inmediato en el tablero de cocina (contratos: `table-session-charge.md`).

### Tests for User Story 1 ⚠️

> Escribir/extender estos tests PRIMERO; deben fallar antes de implementar.

- [X] T002 [P] [US1] En
  `../pos-backend/app/characterization_tests/test_orders_kitchen.py`, añadir un caso que
  cobra una sesión de mesa (`_charge_session`/`charge_session`) de un tenant con módulo de
  Cocina activo y confirma que, tras el cobro, el pedido asociado queda con
  `kitchen_status=='SIN_PREPARAR'` y `sent_to_kitchen_at` no nulo (hoy el test esperado debe
  fallar porque `kitchen_status` permanece `NULL`)
- [X] T003 [P] [US1] En el mismo archivo, añadir un caso que confirma que, para un tenant
  con módulo de Cocina activo, `_assert_closable` ya **no** rechaza el cobro de una sesión
  con ítems en `estado_cocina=='pendiente'` (hoy ese caso debe fallar porque el cobro se
  rechaza)
- [X] T004 [P] [US1] En el mismo archivo, añadir un caso de cuenta dividida: cobrar
  parcialmente una sesión con dos pedidos (uno pagado, uno pendiente vía
  `OrderPaymentAttempt`) y confirmar que solo el pedido que alcanza `payment_status=='PAID'`
  recibe `kitchen_status='SIN_PREPARAR'`; el pedido aún no pagado permanece con
  `kitchen_status IS NULL` (FR-002, clarification 2)
- [X] T005 [P] [US1] En
  `../pos-heladeria/src/app/modules/tables/services/pos-terminal.store.spec.ts`, añadir un
  caso que confirma que `ensureReadyToCharge` NO muestra el diálogo "Entregar y cobrar" ni
  llama a `deliverOrder()` cuando el tenant tiene `cocinaAccess` activo y hay ítems en
  `estado_cocina==='pendiente'` (hoy este caso debe fallar porque sí los entrega primero)
- [X] T006 [P] [US1] En el mismo archivo, confirmar que sin `cocinaAccess` (módulo inactivo)
  `ensureReadyToCharge` sigue mostrando el diálogo y entregando antes de cobrar, exactamente
  como hoy (characterization test de no-regresión para US3/FR-006 — ver Fase 5)

### Implementation for User Story 1

- [X] T007 [US1] En `../pos-backend/app/api/v1/table_sessions/service.py`, modificar
  `_assert_closable` (línea ~328 y su llamador) para que la exigencia de "todos los ítems
  entregados antes de cobrar" se omita cuando el tenant tiene el módulo de Cocina activo
  (mismo `has_module_access("cocina")` que ya usa `orders/kitchen.py`), manteniendo la
  validación intacta cuando el módulo está inactivo (FR-001, FR-003, FR-006)
- [X] T008 [US1] En `../pos-backend/app/api/v1/table_sessions/service.py`, dentro de
  `_charge_session`, tras confirmar el cobro exitoso, para cada pedido de la sesión con
  `dining_table_id` no nulo cuyo `payment_status` queda en `PAID` tras esta operación,
  invocar la misma transición que usa `send_to_kitchen` (`kitchen_status: NULL →
  'SIN_PREPARAR'`, `sent_to_kitchen_at = now()`) solo si el tenant tiene el módulo de Cocina
  activo y el pedido tiene `kitchen_status IS NULL` (idempotencia); pedidos sin
  `payment_status=='PAID'` (cuenta dividida incompleta) se omiten en esta invocación
  (FR-001, FR-002, depende de T007)
- [X] T009 [US1] Extraer o reutilizar la lógica de transición de
  `send_to_kitchen` (`../pos-backend/app/api/v1/orders/kitchen.py:145`) como una función
  interna invocable desde `table_sessions/service.py` sin duplicar la validación de
  `kitchen_status IS NULL`/`payment_status=='PAID'` (soporta T008)
- [X] T010 [US1] En
  `../pos-heladeria/src/app/modules/tables/services/pos-terminal.store.ts`, modificar
  `ensureReadyToCharge` (línea ~2954) para consultar `cocinaAccess` del tenant antes de
  evaluar ítems `estado_cocina==='pendiente'`: si `cocinaAccess` es verdadero, omitir el
  diálogo "Entregar y cobrar" y la llamada a `deliverOrder()`, dejando que el cobro proceda
  directamente; si es falso, mantener el comportamiento actual sin cambios (FR-001, FR-003,
  FR-006, depende de T007/T008 para que el backend ya acepte el cobro directo)
- [X] T011 [US1] En
  `../pos-heladeria/src/app/modules/tables/components/session-bill-panel.component.ts`
  (línea ~300, `charge()`), confirmar/ajustar que tras un cobro exitoso con módulo de Cocina
  activo el panel refleje el pedido como pagado sin ofrecer una acción de cobro adicional,
  recargando el estado del pedido/sesión (FR-005)

**Checkpoint**: Con el módulo de Cocina activo, cobrar un pedido de mesa por QR lo envía a
cocina en el mismo paso, sin pasar por "Entregar"; con cuenta dividida, solo se envía al
completar el 100%. Tests T002-T006 en verde.

---

## Phase 4: User Story 2 — Entregar solo cuando cocina marca "Listo" (Priority: P2)

**Goal**: Con un pedido de mesa por QR ya cobrado y enviado a cocina, "Entregar" solo se
habilita cuando `kitchen_status=='LISTO'`, nunca antes y nunca junto a una acción de cobro
activa — reforzado también en el backend (defensa en profundidad).

**Independent Test**: Con un pedido de mesa por QR ya cobrado y enviado a cocina, mover su
estado en el tablero de Cocina a "Listo" y confirmar que "Entregar" aparece; confirmar que
mientras el estado es distinto de "Listo" no aparece ninguna acción de cobro ni de entrega
activa a la vez (contrato: `order-deliver.md`).

### Tests for User Story 2 ⚠️

- [X] T012 [P] [US2] En
  `../pos-backend/app/characterization_tests/test_orders_kitchen.py`, añadir un caso que
  llama a `deliver_order` para un pedido de mesa de un tenant con módulo de Cocina activo y
  `kitchen_status` distinto de `'LISTO'` (p. ej. `'SIN_PREPARAR'` o `'EN_PROGRESO'`) y
  confirma que responde 409 con un código nuevo (p. ej. `ORDER_NOT_READY`) — hoy este caso
  debe fallar porque la entrega se permite sin esa validación
- [X] T013 [P] [US2] En el mismo archivo, añadir un caso que confirma que `deliver_order`
  **sí** permite entregar cuando `kitchen_status=='LISTO'` (camino feliz, no debe cambiar)
- [X] T014 [P] [US2] En el mismo archivo, revisar y actualizar explícitamente cualquier test
  existente con prefijo `"CONGELA comportamiento actual:"` que hoy asuma que `deliver_order`
  no valida `kitchen_status`, citando la entrada `A-155` del registro de anomalías (Principio
  III: se actualiza, no se borra, en el mismo commit que el cambio de código)
- [X] T015 [P] [US2] En
  `../pos-heladeria/src/app/modules/orders/order-status.util.spec.ts`, confirmar que
  `canDeliverOrder` (línea ~281) ya cubre: con `cocinaAccess` activo, solo
  `kitchen_status==='LISTO'` habilita "Entregar"; si no hay cobertura explícita para el caso
  "cobro activo + entrega nunca a la vez" (FR-003), añadirla

### Implementation for User Story 2

- [X] T016 [US2] En `../pos-backend/app/api/v1/orders/kitchen.py` (`deliver_order`, líneas
  89-141), añadir la precondición: si el tenant tiene el módulo de Cocina activo y el pedido
  tiene `dining_table_id` no nulo, exigir `kitchen_status=='LISTO'`; si no lo está, responder
  409 con un código nuevo (p. ej. `ORDER_NOT_READY`, siguiendo el estilo de
  `ORDER_NOT_PAID` ya usado por `send_to_kitchen`). Sin módulo activo o sin `dining_table_id`,
  no añadir ninguna validación nueva (FR-004, FR-006, FR-009; contrato `order-deliver.md`)
- [X] T017 [US2] Verificar en
  `../pos-heladeria/src/app/modules/tables/components/session-bill-panel.component.ts` y/o el
  componente que renderiza las acciones del pedido de mesa, que el botón "Entregar" y la
  acción de cobro nunca se muestran habilitados a la vez para el mismo pedido cuando el
  módulo de Cocina está activo (FR-003) — usar `canDeliverOrder`/estado de pago ya existentes
  en `order-status.util.ts`, sin introducir un cálculo nuevo

**Checkpoint**: "Entregar" solo aparece con `kitchen_status=='LISTO'`, verificado tanto en
frontend como en backend (409 si se intenta antes). Tests T012-T015 en verde.

---

## Phase 5: User Story 3 — Sin módulo de Cocina, todo sigue igual (Priority: P1)

**Goal**: Un negocio sin el módulo de Cocina activo mantiene exactamente el comportamiento
actual: cobro inmediato, "Entregar" gobernado solo por el estado de entrega de cada producto.

**Independent Test**: Repetir los pasos de las Historias 1 y 2 en un negocio sin el módulo de
Cocina activo y confirmar que el resultado es idéntico al comportamiento actual documentado
antes de este cambio.

### Tests for User Story 3 ⚠️

- [X] T018 [P] [US3] En
  `../pos-backend/app/characterization_tests/test_orders_kitchen.py`, añadir un caso que
  confirma que para un tenant SIN módulo de Cocina activo, `_assert_closable` sigue
  rechazando el cobro de una sesión con ítems `estado_cocina=='pendiente'`, exactamente como
  hoy (no-regresión de T007)
- [X] T019 [P] [US3] En el mismo archivo, añadir un caso que confirma que para un tenant SIN
  módulo de Cocina activo, cobrar una sesión de mesa NO dispara ningún envío automático a
  cocina (`kitchen_status` permanece `NULL` tras el cobro) — no-regresión de T008
- [X] T020 [P] [US3] En el mismo archivo, añadir un caso que confirma que `deliver_order`
  para un pedido SIN módulo de Cocina activo (o sin `dining_table_id`) sigue rechazando
  únicamente `status=='cancelada'`, sin exigir `kitchen_status` — no-regresión de T016
- [X] T021 [P] [US3] Confirmar en
  `../pos-heladeria/src/app/modules/tables/services/pos-terminal.store.spec.ts` que el test
  T006 (ensureReadyToCharge sin `cocinaAccess`) pasa sin cambios de comportamiento

### Implementation for User Story 3

- [X] T022 [US3] Revisión de no-regresión (sin código nuevo esperado): confirmar que las
  ramas `if`/`else` introducidas en T007, T008, T010 y T016 dejan la rama "módulo inactivo"
  bit a bit igual al comportamiento previo a esta feature; si se detecta cualquier desviación,
  corregirla aquí (FR-006, FR-009)

**Checkpoint**: Tests T018-T021 en verde; ningún comportamiento observable cambia para
tenants sin el módulo de Cocina activo.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Cierre de la feature — validación end-to-end y housekeeping que no pertenece a
ninguna historia individual.

- [X] T023 [P] Ejecutar la suite de `app/characterization_tests/test_orders_kitchen.py`
  completa (venv del proyecto, Postgres local) y confirmar que todos los casos nuevos y
  existentes pasan
- [X] T024 [P] Ejecutar `ng test` acotado a los archivos tocados
  (`pos-terminal.store.spec.ts`, `order-status.util.spec.ts`,
  `session-bill-panel.component.spec.ts`) y comparar por archivo contra la baseline conocida
  (no comparar por conteo total de la suite — ver memoria del proyecto sobre baseline flaky)
- [ ] T025 Ejecutar manualmente los 5 escenarios de `quickstart.md` (cobro→cocina en un solo
  paso, entrega solo en Listo, no-regresión sin módulo, cuenta dividida, no-regresión
  mostrador/domicilio) contra backend+frontend locales con los tenants A/B descritos ahí
- [X] T026 Confirmar que la entrada `A-155` del registro de anomalías (T001) quedó con
  **Estado**: actualizado de "REGISTRADA" a algo como "implementada" una vez cerradas las
  fases 3-5, citando los tests nuevos por nombre de archivo (siguiendo el formato de cierre
  usado en entradas previas del registro)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Fase 1)**: Sin dependencias — debe completarse (y commitearse) antes de cualquier
  cambio de código de las fases 3-5 (Principio II)
- **Foundational (Fase 2)**: No aplica (sin tareas)
- **US1 (Fase 3)**: Depende de Fase 1. Es la base de todo lo demás (los pedidos deben poder
  llegar a cocina cobrados antes de que tenga sentido entregarlos)
- **US2 (Fase 4)**: Depende de Fase 1 y de que US1 exista — necesita pedidos que ya llegaron
  a cocina cobrados para poder probar la regla de entrega
- **US3 (Fase 5)**: Depende de Fase 1. Es no-regresión de los cambios de US1/US2 (T007, T008,
  T010, T016), así que en la práctica se implementa en el mismo cambio de código que US1/US2,
  pero se valida (y se reporta) como fase independiente
- **Polish (Fase 6)**: Depende de que Fases 3, 4 y 5 estén completas

### Dentro de cada historia

- Tests (T002-T006, T012-T015, T018-T021) se escriben/extienden antes de la implementación y
  deben fallar primero
- Backend antes de frontend donde hay dependencia real: T010 (frontend, deja de forzar
  entrega previa) depende de que T007/T008 (backend) ya acepten el cobro directo, para no
  dejar al usuario con un cobro que el backend rechaza

### Parallel Opportunities

- T002-T006 (tests de US1) se pueden escribir en paralelo — archivos distintos o casos
  independientes dentro del mismo archivo
- T012-T015 (tests de US2) en paralelo entre sí
- T018-T021 (tests de US3) en paralelo entre sí, y en paralelo con T012-T015 (no comparten
  archivo de implementación)
- T023/T024 (verificación automatizada final) en paralelo entre sí

---

## Parallel Example: User Story 1

```bash
# Tests de US1 en paralelo:
Task: "Caso: cobrar sesión con módulo activo envía a cocina (test_orders_kitchen.py)"
Task: "Caso: _assert_closable ya no exige entrega previa con módulo activo (test_orders_kitchen.py)"
Task: "Caso: cuenta dividida solo envía a cocina al completar 100% (test_orders_kitchen.py)"
Task: "Caso: ensureReadyToCharge omite diálogo con cocinaAccess (pos-terminal.store.spec.ts)"
```

---

## Implementation Strategy

### MVP First (User Story 1 + registro de anomalías)

1. Completar Fase 1 (registro de anomalías — bloqueante)
2. Completar Fase 3 (US1): cobro envía a cocina en un solo paso
3. **DETENER y VALIDAR**: probar US1 de forma independiente (Escenario 1 de `quickstart.md`)
4. Esto ya corrige la causa raíz principal del reporte del usuario

### Incremental Delivery

1. Fase 1 (registro) → bloqueo levantado
2. US1 → validar → esto ya es un MVP demostrable (cobro sin "Entregar y cobrar")
3. US2 → validar → "Entregar" ahora depende de "Listo", con guard de backend
4. US3 → validar (en la práctica, validación de no-regresión de los cambios de US1/US2)
5. Fase 6 (Polish) → cierre formal con `quickstart.md` y actualización del registro

### Notas

- US1 y US3 comparten código (son las dos ramas del mismo condicional); no dupliques
  implementación — implementa el `if`/`else` completo en la Fase 3 y usa la Fase 5
  exclusivamente para probar y reportar la rama "sin módulo" como su propia historia
- No tocar `checkout_and_send` (mostrador/domicilio) en ninguna tarea — fuera de alcance
  (FR-009)
- No introducir ningún campo, flag o parámetro de request nuevo — toda la lógica se resuelve
  consultando estado ya persistido (`payment_status`, `kitchen_status`, módulo de plan del
  tenant)
