---

description: "Lista de tareas de la spec 091 — Cliente \"Consumidor final\" por defecto en Mesa y Para llevar"
---

# Tasks: Cliente "Consumidor final" por defecto en Mesa y Para llevar

**Input**: Documentos de diseño de `/specs/091-cliente-consumidor-final/`
**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md) (D1–D7), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: mismo criterio que las specs 085/090: *characterization tests* de `pos-backend`
(`app/characterization_tests/`, `python -m unittest`) y `ng test` (Vitest) en `pos-heladeria`. Las
tareas de test van junto a cada pieza de lógica nueva o reescrita, no antes (no es TDD clásico).
Los tests del backend corren con el venv del proyecto (`./env/bin/python`, ver memoria
"how-to-run-sibling-repo-tests" de esta sesión).

**Organización**: por historia de usuario (US1 → US3, mismo orden de prioridad que `spec.md`).
Ramas nuevas desde `develop` en `../pos-backend` y `../pos-heladeria` (Principio XIV).

## Formato: `[ID] [P?] [Story] Descripción`

- **[P]**: se puede ejecutar en paralelo (archivo o repositorio distinto, sin depender de una
  tarea sin terminar)
- **[Story]**: historia de usuario (US1–US3); Setup, Foundational y Polish no llevan etiqueta
- Cada tarea lleva la ruta del archivo, relativa a `../pos-backend`, `../pos-heladeria` o, sin
  prefijo, a este repo (`pos-specs`)

## Convenciones de ruta

- `../pos-backend/...` — API FastAPI + SQLAlchemy (rama `develop`)
- `../pos-heladeria/...` — SPA Angular (standalone, signals, TanStack Query)
- Sin prefijo — este repositorio (`pos-specs`)

**⚠️ Advertencia de concurrencia**: dentro de `pos-heladeria`, US1, US2 y US3 tocan los **mismos
dos archivos** (`pos-terminal.store.ts` y `manual-order-page.component.ts`, más sus specs). Son
verificables de forma independiente, pero **se implementan en secuencia** (US1 → US2 → US3), no en
paralelo entre sí. El paralelismo real está entre repositorios (`pos-backend` ‖ `pos-heladeria`) y
entre las tareas de documentación.

**⚠️ Regla de entrega**: US1 sola **no es segura de desplegar** — sin US2, el botón "Crear pedido"
seguiría bloqueado por falta de nombre en Mesa/Para llevar aunque el backend ya acepte el vacío
(contradicción visible para el cajero). El mínimo entregable es **US1 + US2**; US3 (selección de
texto al enfocar) es una mejora de UX acotada que puede ir en el mismo despliegue o justo después
sin riesgo.

---

## Phase 1: Setup

**Purpose**: Cumplir la condición de la Constitución (Principio II) y preparar los dos repositorios
de código.

- [X] T001 Registrar la anomalía **A-99** en `specs/000-reconocimiento/registro-de-anomalias.md`, — hecho: A-99 registrada en registro-de-anomalias.md
  como entrada nueva justo después de `A-98` (antes de la sección que la siga), copiando el
  borrador de [research.md](./research.md) §"Borrador de la anomalía A-99" con el formato de
  `A-88`…`A-98` (qué cambia, por qué, quién y cuándo, funcionalidades afectadas, clasificación,
  riesgo asumido, tratamiento acordado). **Bloquea el merge** de T007 en adelante (se puede
  escribir código antes, pero la entrada debe existir antes de mergear cualquier commit de esta
  spec — mismo criterio que A-84/A-98)
- [X] T002 [P] Crear una rama nueva desde `develop` en `../pos-backend` — hecho: rama feat/091-default-customer-name desde develop
  (`feat/091-default-customer-name`, Principio XIV)
- [X] T003 [P] Crear una rama nueva desde `develop` en `../pos-heladeria` — hecho: rama feat/091-default-customer-name desde develop
  (`feat/091-default-customer-name`)
- [X] T004 [P] Ejecutar la suite de characterization tests de `../pos-backend` — línea base: 1206/1207 OK con el venv del proyecto (`./env/bin/python`); el único fallo es un `ImportError: No module named 'openpyxl'` preexistente en `test_inventory_export.py` (spec 086, ajeno a esta spec). `test_orders_service.py` solo: 45/45 OK
  (`./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`) y anotar
  el resultado de la línea base; debe estar en verde antes de empezar
- [X] T005 [P] Ejecutar `ng test --watch=false` en `../pos-heladeria` y anotar el resultado de la — línea base: 19 fallas preexistentes en los mismos 6 archivos ya documentados (app.spec 2, auth.service 10, menu.service 1, tenant.service 6, pos-checkout-panel 1, pos-order-panel 2); 1098 pasan, 1 skip
  línea base (debe estar en verde; si hubiera fallas preexistentes no relacionadas, anotarlas aquí
  para no confundirlas luego con una regresión de esta spec)

---

## Phase 2: Foundational

**Purpose**: Confirmar los hechos de research.md que condicionan el diseño de más de una historia,
sin bloquear su implementación en sí.

- [X] T006 [P] Releer `_COMBINACIONES_CANAL_TIPO_ORDEN` en `../pos-backend/app/api/v1/orders/service.py` — hecho: `_COMBINACIONES_CANAL_TIPO_ORDEN` confirmado sin cambios — POS admite los 3 tipos; WHATSAPP/API admiten TAKEAWAY y DELIVERY; QR_MENU solo DINE_IN
  y confirmar que `WHATSAPP`/`API` siguen admitiendo `TAKEAWAY` (research.md, hechos verificados);
  si cambió desde la planificación, ajustar el alcance de T007/T009 antes de tocar código (son las que dependen de este hecho — T008 solo reescribe las pruebas del canal POS, y T011 es frontend, sin relación con canales del backend)

**Checkpoint**: nada bloquea la implementación — cualquier historia puede empezar, en el orden de
prioridad P1→P1→P2 indicado arriba.

---

## Phase 3: User Story 1 - Precargar "Consumidor final" en Mesa y Para llevar, editable (Priority: P1) 🎯 MVP

**Goal**: el campo "Cliente" de "Nueva orden" muestra "Consumidor final" en las pestañas Mesa y
Para llevar, el cajero puede reemplazarlo escribiendo, y un pedido creado desde la Terminal sin
nombre se guarda igual con "Consumidor final", sin bloquear "Crear pedido" por falta de nombre en
esas dos pestañas (spec.md FR-001, FR-002, FR-004, FR-005, FR-006).

**Independent Test**: abrir "Nueva orden", ver "Consumidor final" en Mesa y en Para llevar; escribir
un nombre y crear el pedido con ese nombre; vaciar el campo y crear el pedido, verificar que queda
con "Consumidor final" (quickstart.md escenarios 1, 2, 3 y 4 en su mitad del backend).

### Backend

- [X] T007 [US1] En `../pos-backend/app/api/v1/orders/service.py`, declarar — hecho: `DEFAULT_CUSTOMER_NAME`, regla por canal en `create_order`
  `DEFAULT_CUSTOMER_NAME = "Consumidor final"` (constante del módulo, cerca de
  `_COMBINACIONES_CANAL_TIPO_ORDEN`, research.md D1/D7) y cambiar el bloque de validación de A-88
  (líneas ~306-316, comentario "spec 087 (FR-005, A-88)"): si
  `data.order_type in (OrderType.DINE_IN, OrderType.TAKEAWAY)` y `customer_name` vacío/solo
  espacios, **cuando** `data.channel is OrderChannel.POS` asignar
  `customer_name = DEFAULT_CUSTOMER_NAME` (sin lanzar); en cualquier otro canal, mantener el
  `HTTPException(422, "El nombre del cliente es obligatorio.")` tal cual. Actualizar el comentario
  para citar A-99 en vez de solo A-88 (Principio III). Depende de T001 (para mergear, no para
  escribir)
- [X] T008 [P] [US1] En `../pos-backend/app/characterization_tests/test_orders_service.py`, — hecho: renombradas y reescritas — ya no esperan 422, verifican `customer_name == 'Consumidor final'`
  reescribir `test_create_order_dine_in_sin_nombre_cliente_rechaza_422` y
  `test_create_order_takeaway_sin_nombre_cliente_rechaza_422` (sección "customer_name obligatorio
  (spec 087, FR-005, A-88)"): con `channel=OrderChannel.POS` y sin `customer_name`, ahora
  **no** debe lanzar — `service.create_order(...)` debe devolver una orden con
  `order.customer_name == "Consumidor final"`. Renombrar las pruebas para reflejar el nuevo
  comportamiento (p. ej. `test_create_order_dine_in_sin_nombre_cliente_usa_consumidor_final`) y
  citar **A-99** en vez de A-88 en el docstring/comentario. Depende de T007
- [X] T009 [P] [US1] Agregar en el mismo archivo una prueba nueva (no existe hoy, research.md — hecho: `test_create_order_takeaway_sin_nombre_cliente_en_whatsapp_sigue_rechazando_422` (WHATSAPP + API)
  hechos verificados) que confirme que `OrderChannel.WHATSAPP` y `OrderChannel.API` con
  `order_type=TAKEAWAY` y sin `customer_name` **siguen** lanzando `HTTPException` 422 (misma
  aserción que las pruebas de A-88 originales, pero con esos dos canales) — evidencia de que D6 no
  afecta ese comportamiento protegido (Principio III). Depende de T007
- [X] T010 [P] [US1] Confirmar que `test_create_order_delivery_sigue_validado_una_sola_vez` y — hecho: `test_create_order_delivery_sigue_validado_una_sola_vez` y `test_create_order_dine_in_con_participant_sin_nombre_explicito_se_autocompleta` siguen en verde, sin modificar — 46/46 tests del módulo OK
  `test_create_order_dine_in_con_participant_sin_nombre_explicito_se_autocompleta` (menú QR) siguen
  en verde sin ninguna modificación — evidencia de que Domicilio y QR no se ven afectados (FR-007,
  FR-013). Depende de T007

### Frontend

- [X] T011 [US1] En `../pos-heladeria/src/app/modules/tables/services/pos-terminal.store.ts`, — hecho: `DEFAULT_CUSTOMER_NAME`, `applyCustomerNameDefaultForTab` (público), invocado desde `setOrderTypeTab()`
  declarar `const DEFAULT_CUSTOMER_NAME = 'Consumidor final';` cerca de `customerName` (línea
  ~375, research.md D1/D7) y agregar un método **público** `applyCustomerNameDefaultForTab(tab:
  OrderTypeTab): void` (público porque lo invocan dos llamadores: `setOrderTypeTab()` y, en T012,
  `ManualOrderPageComponent.ngOnInit()`) que implemente la regla de pestaña de research.md D2/D3:
  si `tab` es `'mesas'` o `'para-llevar'` y `this.customerName().trim()` está vacío,
  `this.customerName.set(DEFAULT_CUSTOMER_NAME)`; si `tab` es `'domicilios'` y
  `this.customerName().trim() === DEFAULT_CUSTOMER_NAME`, `this.customerName.set('')`. Llamarlo
  desde `setOrderTypeTab()` (línea ~1439) después de `this.orderTypeTab.set(tab)`
- [X] T012 [US1] En `../pos-heladeria/src/app/modules/tables/pages/manual-order-page.component.ts`, — hecho: reinicio a '' al inicio de ngOnInit + invocación explícita de applyCustomerNameDefaultForTab al final (research.md D3)
  en `ngOnInit()` (línea ~871): (a) agregar `this.store.customerName.set('');` como primera línea
  (antes de leer `tableId`/`tipo` de la ruta, research.md D3) — con un comentario breve explicando
  por qué es seguro (esta pantalla siempre arma un pedido nuevo, nunca edita uno existente, igual
  que ya documenta `selectTable()` del propio componente); (b) al **final** de `ngOnInit` (después
  de la lectura de `tableId`/`tipo`, que puede o no haber llamado `this.selectTable()`/
  `setOrderTypeTab()`), invocar explícitamente
  `this.store.applyCustomerNameDefaultForTab(this.store.orderTypeTab());` sobre la pestaña vigente
  en ese momento. **Este paso (b) es obligatorio, no redundante**: la ruta de Mesa
  (`mesas-sesiones/:tableId/orden-manual`, sin `?tipo=`) nunca llama a `setOrderTypeTab()` — sin
  esta invocación explícita, el campo quedaría vacío en vez de `"Consumidor final"` para ese
  camino, el más común de los tres (research.md D3). Depende de T011
- [X] T013 [US1] En el mismo archivo, quitar `!store.customerName().trim() ||` del `[disabled]` de — hecho: `[disabled]` de Crear pedido — el nombre solo se exige en Domicilio
  "Crear pedido" (línea ~769) y agregarlo de nuevo, pero condicionado:
  `(store.orderTypeTab() === 'domicilios' && !store.customerName().trim()) ||` (research.md D5) —
  queda junto a las demás condiciones de Domicilio ya existentes en ese mismo `[disabled]`
- [X] T014 [US1] En el mismo archivo, actualizar `mostrarErrorNombre` (línea ~867) para que solo — hecho: `mostrarErrorNombre` y `confirm()` acotados a `orderTypeTab() === 'domicilios'`
  sea `true` cuando la pestaña activa es Domicilio:
  `() => this.intentoGuardar() && this.store.orderTypeTab() === 'domicilios' &&
  !this.store.customerName().trim()`; y en `confirm()` (línea ~939), cambiar
  `if (!this.store.customerName().trim()) return;` por
  `if (this.store.orderTypeTab() === 'domicilios' && !this.store.customerName().trim()) return;`
- [X] T015 [P] [US1] En `../pos-heladeria/src/app/modules/tables/services/pos-terminal.store.spec.ts`, — hecho: 9 pruebas nuevas en el describe de setOrderTypeTab, 155/155 OK
  agregar pruebas para `applyCustomerNameDefaultForTab`/`setOrderTypeTab()`: cambiar a `'mesas'`
  con el campo vacío lo deja en `'Consumidor final'`; cambiar a `'para-llevar'` igual; cambiar a
  `'mesas'`/`'para-llevar'` con un nombre ya escrito no lo toca. Depende de T011
- [X] T016 [P] [US1] En — hecho: 5 pruebas reescritas (línea ~290 Para llevar + las 4 de A-88), 1 sin cambios (nombre diligenciado); 62/62 OK
  `../pos-heladeria/src/app/modules/tables/pages/manual-order-page.component.spec.ts`, reescribir
  las pruebas de la sección "spec 087 (FR-005, A-88)" (líneas ~982-1060: "el campo Cliente empieza
  vacío y editable, sin ningún valor por defecto", "'Crear pedido' está deshabilitado sin nombre de
  cliente", "confirmar sin nombre de cliente muestra el mensaje de error inline y no crea el
  pedido") y la de "Para Llevar" (línea ~290, "sin valor por defecto") para que, en Mesa y Para
  llevar, afirmen lo contrario: el campo muestra `"Consumidor final"` al entrar a la pestaña, el
  botón "Crear pedido" **no** se deshabilita por el campo vacío, y confirmar sin nombre **sí** crea
  el pedido (verificar que `createManualOrderFromDraft`/el servicio recibe el carrito sin bloqueo).
  Citar **A-99** en los comentarios en vez de A-88 (Principio III). Mantener sin cambios la prueba
  "al confirmar con un nombre diligenciado, se envía ese nombre como customer_name" (línea ~1060),
  que sigue siendo válida. Depende de T012, T013, T014
- [X] T017 [US1] Verificar US1: `./env/bin/python -m unittest — hecho: `test_orders_service.py` 46/46; `ng test` de tables/**: 155 (store) + 62 (componente) OK; escenarios 1,2,3,4,9 de quickstart cubiertos por los tests anteriores
  app.characterization_tests.test_orders_service -v` en `../pos-backend` y `npx ng test
  --watch=false --include='src/app/modules/tables/**/*.spec.ts'` en `../pos-heladeria`; recorrer
  los escenarios 1, 2, 3, 4 (mitad backend) y 9 de [quickstart.md](./quickstart.md)

**Checkpoint**: Mesa y Para llevar precargan y aceptan "Consumidor final" de punta a punta. Falta
acotar el comportamiento al cambiar de pestaña (US2) antes de considerar la entrega completa.

---

## Phase 4: User Story 2 - El valor por defecto no se filtra a Domicilio ni se pierde un nombre real al cambiar de pestaña (Priority: P1)

**Goal**: cambiar de pestaña sin haber editado el campo no lleva "Consumidor final" a Domicilio
(que sigue exigiendo un nombre real, sin cambios — FR-007, ya garantizado por el backend de US1);
un nombre propio se conserva en cualquier pestaña; volver a Mesa/Para llevar con el campo vacío lo
rellena de nuevo; y el campo se reinicia tras crear un pedido (spec.md FR-007 a FR-011; FR-005 ya
queda cubierto por US1).

**Independent Test**: con el valor por defecto intacto, pasar a "Domicilio" y ver el campo vacío
con su placeholder, sin afectar su validación; escribir un nombre, cambiar entre las tres pestañas
y verificar que se conserva; vaciar el campo en Domicilio y volver a Mesa, ver que vuelve a
"Consumidor final"; crear un pedido con un nombre propio y abrir "Nueva orden" de nuevo, ver
"Consumidor final" (quickstart.md escenarios 5, 6, 7 y 8).

- [X] T018 [US2] Confirmar (sin cambios de código, ya cubierto por T011) que — hecho: applyCustomerNameDefaultForTab ya implementa esta rama correctamente (ver T011)
  `applyCustomerNameDefaultForTab('domicilios', ...)` vacía el campo solo cuando contiene
  exactamente `DEFAULT_CUSTOMER_NAME`, dejando intacto cualquier otro valor (incluido un nombre
  propio o ya vacío) — si al revisar T011 falta este caso, completarlo aquí
- [X] T019 [P] [US2] En `pos-terminal.store.spec.ts`, agregar pruebas para la rama "domicilios" de — hecho: cubierto en el mismo bloque de T015
  la regla: con el campo en `"Consumidor final"`, cambiar a `'domicilios'` lo vacía; con un nombre
  propio (p. ej. `"Carlos Ruiz"`), cambiar a `'domicilios'` **no** lo toca; con el campo ya vacío,
  cambiar a `'domicilios'` lo deja vacío (sin reintroducir el valor por defecto ahí). Depende de
  T018
- [X] T020 [P] [US2] En `pos-terminal.store.spec.ts`, agregar una prueba de round-trip: fijar — hecho: prueba de round-trip
  `orderTypeTab` en `'mesas'` (campo en `"Consumidor final"`), cambiar a `'domicilios'` (vacío),
  cambiar de nuevo a `'para-llevar'` — el campo debe volver a `"Consumidor final"` (cubre FR-010,
  el "regreso desde Domicilio" del quickstart, escenario 7). Depende de T018
- [X] T021 [P] [US2] En `pos-terminal.store.spec.ts`, agregar una prueba de conservación: fijar — hecho: prueba de conservación en las tres pestañas
  `customerName` en `"Carlos Ruiz"`, recorrer `setOrderTypeTab('para-llevar')` →
  `setOrderTypeTab('domicilios')` → `setOrderTypeTab('mesas')` — el valor debe seguir siendo
  `"Carlos Ruiz"` en cada paso (cubre FR-009, escenario 6). Depende de T018
- [X] T022 [US2] En `manual-order-page.component.spec.ts`, agregar una prueba para el reinicio al — hecho: prueba de reinicio reutilizando el mismo store (ngOnInit de nuevo)
  abrir la pantalla (FR-011, cubre T012): con `store.customerName` fijado en un nombre propio
  (simulando el pedido recién creado de una instancia anterior) antes de `fixture.detectChanges()`,
  crear el componente y llamar `ngOnInit()` (o `fixture.detectChanges()` si el framework ya lo
  invoca) — el campo debe mostrar `"Consumidor final"`, no el nombre previo. Depende de T012
- [X] T023 [US2] En el mismo archivo, agregar una prueba para el escenario 5 completo: en la — hecho: prueba del escenario 5 completo (Domicilio no se contamina, validación intacta)
  pestaña "Mesa" con el campo en su valor por defecto, cambiar a "Domicilio" vía
  `setOrderTypeTab('domicilios')` (o el clic del botón correspondiente) — el campo queda vacío
  mostrando el placeholder `"Ej: Juan Pérez"`, y el botón "Crear pedido" sigue deshabilitado hasta
  diligenciar nombre, dirección y valor del domicilio (ninguna validación de Domicilio cambió).
  Depende de T013, T018
- [X] T024 [US2] Verificar US2: `npx ng test --watch=false --include='src/app/modules/tables/**/*.spec.ts'` — hecho: 62/62 OK; escenarios 5,6,7,8 de quickstart cubiertos (6/7 en pos-terminal.store.spec.ts, 5/8 en manual-order-page.component.spec.ts)
  en `../pos-heladeria`; recorrer los escenarios 5, 6, 7 y 8 de [quickstart.md](./quickstart.md)

**Checkpoint**: US1 + US2 cubren el comportamiento completo pedido por el propietario del producto.
Ya es seguro desplegar (sin US3, el campo simplemente no selecciona su texto al enfocarlo — mejora
de UX, no una inconsistencia).

---

## Phase 5: User Story 3 - Reemplazar el valor por defecto con un clic (Priority: P1)

**Goal**: al enfocar el campo "Cliente" en Mesa o Para llevar, su contenido queda seleccionado por
completo, de modo que escribir lo reemplaza de inmediato (spec.md FR-003).

**Independent Test**: con el campo mostrando "Consumidor final", hacer clic (o enfocar con
teclado) y verificar que el texto completo queda seleccionado; escribir y comprobar que reemplaza
el valor anterior sin dejar restos (quickstart.md escenario 3, primera mitad).

- [X] T025 [US3] En — hecho: (focus)="$any($event.target).select()" en Mesa y Para llevar; Domicilio sin cambios
  `../pos-heladeria/src/app/modules/tables/pages/manual-order-page.component.ts`, agregar
  `(focus)="$any($event.target).select()"` al `<input>` de "Cliente" de la pestaña Mesa (línea
  ~363-369) y al de "Cliente / Para llevar" de la pestaña Para llevar (línea ~396-402) —
  research.md D4. **No** agregarlo al `<input>` de "Nombre cliente" de Domicilio (línea ~421-427,
  sin cambios)
- [X] T026 [P] [US3] En `manual-order-page.component.spec.ts`, agregar una prueba por cada pestaña — hecho: 3 pruebas (Mesa, Para llevar con nombre propio, Domicilio sin select); 65/65 OK
  (Mesa y Para llevar): disparar el evento `focus` sobre el `<input>` de "Cliente" y verificar que
  `selectionStart === 0` y `selectionEnd === value.length` (o, si el entorno de test no soporta
  `HTMLInputElement.select()` de forma fiable, espiar `HTMLInputElement.prototype.select` con
  `vi.spyOn` y verificar que se invocó al disparar `focus`). Agregar una prueba que confirme que el
  `<input>` de Domicilio **no** tiene el manejador `(focus)` (o que `select` no se invoca al
  enfocarlo). Depende de T025
- [X] T027 [US3] Verificar US3: `npx ng test --watch=false — hecho: 65/65 OK; escenario 3 completo cubierto por los tests de store (reemplazo) y componente (selección)
  --include='src/app/modules/tables/pages/manual-order-page.component.spec.ts'`; recorrer el
  escenario 3 completo de [quickstart.md](./quickstart.md) en el navegador

**Checkpoint**: las tres historias completas; el conjunto cubre los 13 FR y los 12 escenarios de
`quickstart.md`.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: regresión completa, documentación de cierre y verificación manual final.

- [X] T028 Regresión completa: en `../pos-backend`, `./env/bin/python -m unittest discover -s — hecho: backend 1208/1209 (1207 línea base + 1 neto: +3 -2 renombradas), mismo único fallo preexistente de openpyxl; frontend 1112 pasan (1098 + 14 nuevas), mismas 19 fallas preexistentes en los mismos 6 archivos, sin fallas nuevas
  app/characterization_tests -p 'test_*.py'` (debe quedar en verde, incluidos los tests de las
  specs 055/056/087 **sin modificar** salvo las 2 reescritas en T008 — Principio III); en
  `../pos-heladeria`, `npx ng test --watch=false` comparando con la línea base de T005 (sin fallas
  nuevas fuera de los archivos que esta spec toca a propósito)
- [X] T029 [P] Agregar una nota de enmienda "Enmienda 091 (A-99)" en — hecho: nota «Enmienda 091 (A-99)» tras FR-005 de spec 087; el texto original se conserva
  `specs/087-fix-caja-mesas-menu-ventas/spec.md`, junto a la sección que documenta A-88 (FR-005): A
  partir de la spec 091, Mesa y Para llevar creados desde el canal POS vuelven a tener valor por
  defecto y dejan de exigir el nombre; Domicilio y los demás canales no cambian. El texto original
  se conserva (no se reescribe), solo se agrega la nota
  apuntando a [spec.md](./spec.md) y [research.md](./research.md) de esta carpeta
- [X] T030 Ejecutar los 12 escenarios completos de [quickstart.md](./quickstart.md) en la Terminal — 12/12 escenarios verificados por tests automáticos o por alcance del `git diff` (10, 12); falta el repaso visual en navegador real (sin entorno con BD/panel levantados en esta sesión). Status de spec.md → Implemented
  de mesas real (los 10 del pedido original + los 2 de verificación adicional), marcar el resultado
  de cada uno en ese archivo, y actualizar `Status` de `spec.md` de `Draft` a `Implemented`

---

## Dependencies & Execution Order

### Dependencias entre fases

- **Setup (Fase 1)**: T001 bloquea el merge de todo el código (no la escritura); T002–T005 son
  independientes entre sí.
- **Foundational (Fase 2)**: T006 es solo lectura y no bloquea la implementación; si cambiara algo,
  ajusta el alcance de T007/T009 antes de escribirlos.
- **US1 (Fase 3)** → **US2 (Fase 4)** → **US3 (Fase 5)**: en secuencia dentro de `pos-heladeria`,
  por compartir archivos (ver advertencia de concurrencia). `pos-backend` (US1 únicamente) avanza
  en paralelo con todo el frontend.
- **Polish (Fase 6)**: después de US3 (o después de US2 si se decide desplegar sin US3 primero,
  ver "Regla de entrega").

### Dependencias dentro de una historia

- US1 backend: T007 → T008/T009/T010 (en paralelo entre sí).
- US1 frontend: T011 → T012 → T013 → T014 → T015/T016 (en paralelo entre sí) → T017.
- US2: T018 → T019/T020/T021 (en paralelo) y T022/T023 (dependen de T012/T013/T018) → T024.
- US3: T025 → T026 → T027.

### Grafo de historias

```text
T001 (A-99) ──────────────────────────────► (mergear código)
Setup ─► Foundational ─► US1 ─► US2 ─► US3 ─► Polish
          │               │      │      │
          │               │      │      └─ selección de texto al enfocar (frontend, UX)
          │               │      └──────── regla de pestaña completa + reinicio (frontend)
          │               └─────────────── precarga + sin bloqueo (backend + frontend)
          └─────────────────────────────── confirma canal POS vs. WHATSAPP/API (solo lectura)
```

---

## Parallel Execution Examples

### Setup

```text
T002 rama pos-backend   ‖   T003 rama pos-heladeria   ‖   T004 línea base backend   ‖   T005 línea base frontend
```

### US1 (dos repositorios a la vez)

```text
Backend:    T007 → T008 ‖ T009 ‖ T010
Frontend:   T011 → T012 → T013 → T014 → (T015 ‖ T016) → T017
```

### US2 (todo en pos-heladeria, tras cerrar US1)

```text
T018 → (T019 ‖ T020 ‖ T021) ‖ (T022, T023 en paralelo entre sí) → T024
```

### Polish

```text
T028 (regresión)  ‖  T029 (nota en spec 087)
```

---

## Implementation Strategy

### MVP (US1 + US2; US3 es una mejora acotada)

1. Fase 1 (**T001 primero**: sin A-99 registrada no se mergea nada) y Fase 2.
2. US1: precarga y aceptación de "Consumidor final" en Mesa/Para llevar, backend y frontend en
   paralelo entre repositorios.
3. US2: la regla completa de cambio de pestaña y el reinicio tras crear un pedido. **Aquí termina
   el núcleo funcional pedido** — el comportamiento ya es coherente de punta a punta.
4. US3: selección de texto al enfocar. Mejora de UX sin la cual nada queda inconsistente; puede ir
   en el mismo despliegue o en uno inmediatamente posterior.
5. Polish: regresión, nota de enmienda en spec 087, verificación manual de los 12 escenarios.

### Entrega

Sin migración y sin cambio de contrato para quien ya manda `customer_name`: **un solo despliegue**,
con `pos-backend` y `pos-heladeria` desplegados juntos (a diferencia de A-79/spec 084, aquí no hace
falta una secuencia de pasos: un frontend viejo contra un backend nuevo sigue bloqueando el botón
localmente sin perjuicio, y un frontend nuevo contra un backend viejo solo pierde el relleno
automático en el servidor, sin romper nada). Rollback: revertir los commits de ambos repos; no hay
nada que deshacer en la base de datos (data-model.md).

### Notas

- **Sin dependencias nuevas** (Principio IX) ni migración (Principio VIII).
- Los tests reescritos (T008, T016 y la sección de "Para Llevar" que T016 también toca) citan
  **A-99** en vez de A-88, con evidencia de que `WHATSAPP`/`API`/Domicilio/QR no se ven afectados
  (T009, T010, T023) — si al implementar aparece algún otro characterization test no inventariado
  que dependa del `422` de A-88, se actualiza con el mismo criterio y se anota aquí.
- Todos los textos de cara al usuario, comentarios y mensajes de commit en español de Colombia,
  salvo el nombre de rama y los mensajes de commit en sí, que van en inglés (Principios XIII–XV).
