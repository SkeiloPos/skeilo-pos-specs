# Research: Cliente "Consumidor final" por defecto en Mesa y Para llevar

Toda la investigación se hizo leyendo el código vigente de `pos-backend` y `pos-heladeria`
(`develop`, árboles limpios) el 2026-10-01. No quedaban `NEEDS CLARIFICATION` en el Technical
Context del plan.

## Hechos verificados en el código

| Hecho | Dónde |
|---|---|
| Esta spec **reabre A-88** (spec 087): antes de 087 existía `applyDefaultCustomerName()` en el frontend, que precargaba "Consumidor final" en Mesa/Para llevar; 087 la retiró y volvió `customer_name` obligatorio en los 3 tabs, frontend y backend. | `registro-de-anomalias.md` A-88; comentarios "spec 087 (FR-005, A-88)" en `manual-order-page.component.ts` y `pos-terminal.store.ts` |
| `customerName` es **una sola señal** del store (`pos-terminal.store.ts`), compartida por las tres pestañas — no hay un valor por pestaña. | `pos-terminal.store.ts:375` |
| El botón "Crear pedido" se deshabilita hoy con `!store.customerName().trim()` **sin distinguir pestaña**; `confirm()` hace el mismo chequeo y corta antes de llamar al store; `mostrarErrorNombre()` (ligado a `intentoGuardar`) muestra el mismo mensaje en los 3 tabs. | `manual-order-page.component.ts:769`, `:860-868`, `:938` |
| Al crear el pedido, el payload manda `customer_name: this.customerName().trim() || null` — ya normaliza espacios a `null`, pero hoy nunca llega vacío porque el botón está deshabilitado antes. | `pos-terminal.store.ts:1556` |
| El backend (`orders/service.py::create_order`) valida **primero** Domicilio (nombre+dirección+valor, FR-007 de spec 056) y **después** `DINE_IN`/`TAKEAWAY` (A-88): si `customer_name` está vacío, `422 "El nombre del cliente es obligatorio."`, sin mirar `channel`. | `orders/service.py:279-316` |
| `_COMBINACIONES_CANAL_TIPO_ORDEN` prueba que `TAKEAWAY` también es válido para `WHATSAPP` y `API`, no solo `POS` (`DINE_IN` solo para `POS`/`QR_MENU`). El alcance de esta spec es "desde la Terminal" = canal `POS`; sin acotar por canal, `WHATSAPP`/`API` + `TAKEAWAY` sin nombre dejarían de rechazarse — **fuera del alcance pedido**. | `orders/service.py:68-73` |
| Un pedido `QR_MENU` resuelve `customer_name` desde `participant.display_label`/`display_name` **antes** de la validación de A-88; y `display_name` ya es `NOT NULL` y se valida no vacío al unirse a la mesa. Por construcción, nunca llega vacío a `create_order`. | `orders/service.py:293-316`; `table_sessions/service.py:495-496`; `session_participant.py:41` |
| Existe un literal **distinto** y ya usado: `"Consumidor Final"` (con F mayúscula) es el valor por defecto de `billing_customer_name` para la **factura/checkout**, en `resetTransient()` del store y en `checkout.py`. Esta spec usa el literal `"Consumidor final"` (f minúscula) — el texto exacto de los 10 escenarios del pedido original — para el **nombre del pedido**, un campo distinto. `syncBillingCustomerNameWithOrder()` ya compara en minúsculas (`toLowerCase() !== 'consumidor final'`) antes de copiar el nombre del pedido a la factura, así que ya tolera ambas grafías sin cambios. | `pos-terminal.store.ts:1590,1598-1601`; `orders/checkout.py:708`; `orders/schemas.py:340` |
| `ManualOrderPageComponent` arma **siempre** un pedido nuevo (nunca edita uno existente, ver comentario de `selectTable()` del componente) y, tras crear uno, navega a `/dashboard/mesas-sesiones` — la próxima vez que se abre "Nueva orden" es una instancia de componente nueva, pero `pos-terminal.store` es un servicio de mayor alcance (sobrevive la navegación), así que `customerName` **no se reinicia solo** al reabrir la pantalla si no hay una regla explícita que lo haga. | `manual-order-page.component.ts:1459-1466` (comentario), `:887-893` (`ngOnInit`) |
| El único reinicio existente de "campo vacío" ya vive en `selectTable()`: si la mesa no tiene pedido activo, `customerName.set('')` (a propósito, con un comentario que explica por qué no autocompleta "Cliente Mesa 3"). La ruta "Para llevar" (`mesas-sesiones/orden-manual` sin `:tableId`) no pasa por `selectTable()`, así que hoy nada limpia `customerName` al abrirla. | `pos-terminal.store.ts:1467-1494` |
| Tests de characterization que **codifican exactamente lo que esta spec revierte** (deben reescribirse, Principio III): backend `test_create_order_dine_in_sin_nombre_cliente_rechaza_422`, `test_create_order_takeaway_sin_nombre_cliente_rechaza_422`; frontend (`manual-order-page.component.spec.ts`) la prueba de "Para Llevar" sin valor por defecto (línea ~290) y el bloque de 4 pruebas "el campo Cliente empieza vacío…", "escribir… sin botón de edición", "'Crear pedido' está deshabilitado sin nombre…", "confirmar sin nombre… muestra el mensaje de error…" (líneas ~986-1060). | grep confirmado el 2026-10-01 |
| No existe hoy ningún test que confirme que `WHATSAPP`/`API` + `TAKEAWAY` sin nombre se **sigue** rechazando — `test_create_order_combinaciones_validas_no_rechaza` siempre manda `customer_name="Ana Torres"`. Hace falta uno nuevo para no dejar ese borde sin cubrir tras acotar la validación por canal (D2). | `test_orders_service.py:329-369` |
| Última anomalía registrada: **A-98** (spec 090). Próximo número libre: **A-99**. | `registro-de-anomalias.md` |

## Decisiones

### D1 — Texto exacto del valor por defecto: `"Consumidor final"`, literal nuevo y separado de `"Consumidor Final"`

- **Decisión**: usar exactamente `"Consumidor final"` (f minúscula) como valor de `customer_name`
  para Mesa/Para llevar sin nombre — el texto literal de los 10 escenarios del pedido original.
  **No** se reutiliza ni se renombra el literal `"Consumidor Final"` (F mayúscula) que ya existe
  para `billing_customer_name` (factura): son dos campos distintos con propósitos distintos
  (identificar el pedido vs. a nombre de quién va la factura), y `syncBillingCustomerNameWithOrder`
  ya los concilia sin cambios (hecho verificado arriba).
- **Rationale**: los escenarios de aceptación citan el texto exacto repetidamente; cambiarlo
  rompería la verificación literal de la spec. Unificar ambos literales obligaría a tocar
  `checkout.py`/`resetTransient()` sin que el pedido lo exija — fuera de alcance (Principio V).
- **Alternativas consideradas**: (a) reutilizar `"Consumidor Final"` — descartada, no es el texto
  pedido y mezclaría dos conceptos; (b) una constante compartida entre frontend y backend — no
  aplica, son dos repositorios sin un paquete común para constantes de dominio.

### D2 — Dónde vive la regla de "vacío → valor por defecto" (una sola regla cubre carga inicial, cambio de pestaña y reinicio tras crear)

- **Decisión**: una única función del store, ejecutada (a) al construirse/abrir `ManualOrderPageComponent`
  (antes de aplicar `tableId`/`tipo` de la ruta) y (b) en cada `setOrderTypeTab()`, que aplica:
  - pestaña `mesas`/`para-llevar` + campo vacío o solo espacios ⇒ `"Consumidor final"`.
  - pestaña `domicilios` + campo con **exactamente** `"Consumidor final"` (recortado) ⇒ `''`.
  - cualquier otro valor (nombre propio, o vacío que no sea el caso anterior) ⇒ se conserva.
- **Rationale**: cubre los 10 escenarios con una sola regla, sin una bandera nueva de "¿editó el
  campo?": como `ManualOrderPageComponent` siempre arma un pedido nuevo (hecho verificado arriba),
  aplicar la regla **al abrir la pantalla** — no solo al cambiar de pestaña — resuelve a la vez la
  carga inicial (Historias 1 y 2) **y** el reinicio tras crear un pedido (Historia 3, escenario de
  reinicio): la próxima apertura de "Nueva orden" vuelve a evaluar "¿está vacío?" sobre un
  `customerName` que, si no se tocó, puede traer un nombre de un pedido anterior — por eso la regla
  debe aplicarse también sobre un valor **no vacío** cuando la pantalla se abre de cero, no solo
  sobre "vacío". Ver D3 para el mecanismo exacto que lo resuelve sin inventar una bandera.
- **Alternativas consideradas**: (a) una bandera `customerNameEditedByUser` — más explícita para
  "no he editado el campo", pero introduce estado nuevo y un caso más que sincronizar (reset de la
  bandera en cada punto de reinicio); se prefiere la comparación por valor (D3) porque ya basta
  para los 10 escenarios y es menos superficie para desincronizarse. (b) resetear `customerName` a
  `''` en `ngOnInit` y dejar que la regla de "vacío → defecto" la rellene — funciona igual de bien
  y es más simple todavía; se adopta como el mecanismo concreto (ver D3).

### D3 — Mecanismo concreto: `ngOnInit` reinicia a `''` y aplica la regla de pestaña explícitamente (no solo al cambiar de tab)

- **Decisión**: `applyCustomerNameDefaultForTab(tab)` (D2) se vuelve un método **público** del
  store, porque lo invocan dos llamadores: `setOrderTypeTab()` (cambios de pestaña en caliente) y
  `ManualOrderPageComponent.ngOnInit()`. En `ngOnInit()`, **antes** de leer `tableId`/`tipo` de la
  ruta, `store.customerName.set('')`; y **al final** de `ngOnInit()` (después de cualquier
  `selectTable()`/`setOrderTypeTab()` que dispare la ruta), se invoca explícitamente
  `store.applyCustomerNameDefaultForTab(store.orderTypeTab())` sobre la pestaña vigente en ese
  momento.
- **Por qué el paso final es obligatorio y no opcional**: la ruta principal para un pedido de Mesa
  (`mesas-sesiones/:tableId/orden-manual`, sin `?tipo=`) **nunca** llama a `setOrderTypeTab()` — el
  tab ya nace en `'mesas'` por el valor inicial de la señal, sin ningún evento de cambio que
  dispare la regla de D2. Confiar solo en "cambiar de tab ya la corre" (como asumía una versión
  anterior de esta decisión) deja el campo vacío en vez de `"Consumidor final"` para ese camino —
  que es el más común de los tres, no un borde. Invocar la regla explícitamente al final de
  `ngOnInit`, sobre la pestaña que haya quedado vigente (la del query param si lo hubo, o `'mesas'`
  por defecto), cubre los tres caminos de entrada con una sola llamada.
- **Rationale**: un solo punto de reinicio (abrir la pantalla) más una sola invocación explícita de
  la regla ya existente, en vez de duplicar "aplicar default" en varios sitios o depender de que un
  evento de cambio de pestaña ocurra cuando puede no ocurrir.
- **Riesgo aceptado**: si en el futuro `ManualOrderPageComponent` empezara a **editar** un pedido ya
  creado (hoy no lo hace, por diseño — hecho verificado arriba), este reinicio incondicional sería
  incorrecto. Vale la pena señalarlo en un comentario junto al reinicio, como ya hace el código
  vecino (`selectTable()` del componente).

### D4 — Selección de texto al enfocar (FR-003): `(focus)="$any($event.target).select()"`

- **Decisión**: agregar el manejador de `focus` al `<input>` de "Cliente" en las pestañas Mesa y
  Para llevar únicamente (Domicilio no cambia). Usa el método nativo `HTMLInputElement.select()` —
  sin librería nueva (Principio IX).
- **Aplica siempre**, tenga el campo el valor por defecto o un nombre ya escrito (Assumptions de la
  spec): mismo comportamiento simple en los dos casos, sin una condición extra que distinga "¿es el
  default?".

### D5 — Frontend: quitar el bloqueo de "Crear pedido" y el error inline solo para Mesa/Para llevar

- **Decisión**: en `manual-order-page.component.ts`:
  - El `[disabled]` de "Crear pedido" deja de incluir `!store.customerName().trim()` de forma
    incondicional; esa condición se vuelve `store.orderTypeTab() === 'domicilios' &&
    !store.customerName().trim()` (Domicilio igual que hoy; Mesa/Para llevar ya no lo exigen).
  - `confirm()`: el corte temprano `if (!this.store.customerName().trim()) return;` se vuelve
    condicional a `orderTypeTab() === 'domicilios'`.
  - `mostrarErrorNombre()`: igual, solo se evalúa (y el mensaje "El nombre del cliente es
    obligatorio." solo se muestra) cuando la pestaña activa es Domicilio.
- **Rationale**: es el reverso quirúrgico exacto de lo que A-88 introdujo para estos dos tabs,
  dejando intacto el camino de Domicilio (FR-007 de la spec, A-88 sin cambios ahí).

### D6 — Backend: el valor por defecto solo aplica al canal `POS` (Terminal)

- **Decisión**: en `create_order` (`orders/service.py`), la validación de A-88 para
  `DINE_IN`/`TAKEAWAY` se dividen en dos ramas:
  - `data.channel is OrderChannel.POS` y `customer_name` vacío/solo espacios ⇒ se asigna
    `"Consumidor final"` (no se rechaza).
  - cualquier otro canal (`WHATSAPP`, `API`; `QR_MENU` nunca llega vacío, ver hechos arriba) y
    `customer_name` vacío ⇒ sigue rechazando `422` exactamente como hoy.
- **Rationale**: el pedido es explícito — "pedidos... creados desde la Terminal de mesas". Sin esta
  condición por canal, un `TAKEAWAY` por `WHATSAPP`/`API` sin nombre dejaría de rechazarse, un
  cambio de comportamiento no pedido ni registrado (Principio VI: evitar mezclar cambios no
  relacionados).
- **Verificación nueva requerida** (no existe hoy, hecho verificado arriba): un test que confirme
  que `WHATSAPP`/`API` + `TAKEAWAY` sin nombre **sigue** devolviendo `422` después de este cambio.

### D7 — Constante del literal, una por repositorio

- **Decisión**: declarar `"Consumidor final"` como una constante nombrada una sola vez por
  repositorio (p. ej. `DEFAULT_CUSTOMER_NAME` en `orders/service.py`; una constante o función
  compartida en el store/componente de `pos-heladeria`), en vez de repetir el literal suelto en
  cada punto donde se usa (asignación backend, regla de pestaña, y los tests nuevos/actualizados
  que lo esperan).
- **Rationale**: un único punto de verdad por el texto exacto evita que una futura corrección de
  redacción deje una instancia desactualizada; no es una dependencia nueva ni cruza repositorios.

## Borrador de la anomalía A-99 (a registrar antes de implementar)

Formato de las entradas A-88…A-98 de `specs/000-reconocimiento/registro-de-anomalias.md`. **No es
parte del alcance de `/speckit-plan`** registrar el texto: lo hace una tarea de `tasks.md`, igual
que A-84 en spec 085 y A-98 en spec 090.

> ### A-99 — [DECISIÓN DE NEGOCIO — spec 091, 2026-10-01] "Consumidor final" vuelve a ser el valor por defecto del cliente en pedidos de Mesa y Para llevar creados desde la Terminal
>
> **Qué cambia**: reabre parcialmente **A-88** (spec 087). Para pedidos `DINE_IN`/`TAKEAWAY`
> creados con `channel=POS` (Terminal de mesas), `customer_name` vacío o solo espacios deja de
> rechazarse (`422 "El nombre del cliente es obligatorio."`) y se guarda como `"Consumidor final"`.
> En el frontend, el campo "Cliente" de "Nueva orden" vuelve a precargar ese texto en las pestañas
> Mesa y Para llevar (editable, seleccionado por completo al enfocarlo), deja de bloquear "Crear
> pedido" por falta de nombre en esas dos pestañas, y se vuelve a vaciar al pasar a Domicilio
> cuando seguía en el valor por defecto sin editar. **Domicilio no cambia**: sigue exigiendo nombre,
> dirección y valor del domicilio (A-88/spec 056 intactos ahí), igual que cualquier pedido
> `TAKEAWAY` por `WHATSAPP`/`API` (canales fuera de la Terminal).
>
> **Por qué cambia**: en horas pico, pedir un nombre real para una mesa o un pedido para llevar
> genérico frena la operación más de lo que aporta; identificar al cliente real solo sigue siendo
> necesario para Domicilio, donde hace falta para la entrega.
>
> **Quién tomó la decisión y cuándo**: propietario del producto, 2026-10-01
> (`specs/091-cliente-consumidor-final/spec.md`, encabezado y Contexto).
>
> **Funcionalidades afectadas**: `pos-backend` (`orders/service.py::create_order`; tests
> `test_orders_service.py` — se reescriben `test_create_order_dine_in_sin_nombre_cliente_rechaza_422`
> y `test_create_order_takeaway_sin_nombre_cliente_rechaza_422`, y se agrega una prueba nueva para
> `WHATSAPP`/`API` + `TAKEAWAY` sin nombre); `pos-heladeria`
> (`manual-order-page.component.ts`, `pos-terminal.store.ts` y sus specs — se reescribe el bloque de
> pruebas de A-88 citado en research.md). Domicilio, menú QR, Órdenes, Ventas y pedidos ya
> existentes no cambian.
>
> **Clasificación**: DECISIÓN DE NEGOCIO. **Riesgo asumido**: ninguno sobre datos existentes (sin
> migración; solo rige para pedidos creados desde el despliegue en adelante, igual que A-88).
> **Tratamiento acordado**: `specs/091-cliente-consumidor-final/tasks.md`.
