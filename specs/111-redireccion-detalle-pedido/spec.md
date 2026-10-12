# Feature Specification: Corrección — Redirección al detalle del pedido tras crearlo

**Feature Branch**: `111-redireccion-detalle-pedido`

**Created**: 2026-10-11

**Status**: Draft

**Naturaleza de esta spec**: **spec de corrección**, no una funcionalidad nueva desde cero. Igual
que las specs [019](../019-correccion-cuenta-mesas-fusionadas/spec.md),
[020](../020-correccion-validacion-opciones-mesero/spec.md),
[041](../041-correccion-bugs-menu-qr/spec.md),
[050](../050-correccion-liberar-mesa-pedido-cancelado/spec.md) y
[110](../110-liberar-mesa-sin-pedido/spec.md), cita archivo, función y línea del código actual
(`pos-heladeria`) porque son el contrato observable que se está corrigiendo, no una fuga de
detalles de implementación. El bug de redirección en sí es exclusivamente de frontend; el endpoint
de backend que crea el pedido ya responde con éxito (2xx) y con el ID del pedido creado. Esta spec
añade, además, un requisito nuevo de idempotencia en ese mismo endpoint (FR-011) para cumplir RN4
ante reintentos de red — ver Clarifications.

**Autorización de negocio (Principio I y Principio II de la
[Constitución](../../.specify/memory/constitution.md))**: reportado por el dueño/desarrollador del
proyecto el 2026-10-11, con base en capturas del comportamiento actual en producción.

**Input**: User description (verbatim, resumido): "Como cajero o mesero de la heladería, quiero
que al crear un pedido el sistema me lleve directo a su detalle, para marcar los ítems como
listos, agregar productos o cobrar sin tener que buscarlo de nuevo en la terminal. Hoy, en 'Nueva
orden', al crear el pedido (Mesa / Para llevar / Domicilio) el pedido se crea bien, pero el usuario
siempre termina en la terminal, en la pestaña Mesas, sin importar el tipo de pedido creado."

**Causa raíz confirmada (investigación del código actual, `pos-heladeria`)**:

- La vista "Nueva orden" (`manual-order-page.component.ts`, rutas
  `mesas-sesiones/:tableId/orden-manual` y `mesas-sesiones/orden-manual`, registradas en
  `routes.ts:185-202`) usa un único flujo de creación para los tres tipos de pedido: el botón
  "Crear pedido" (`manual-order-page.component.ts:766-781`) llama a `confirm()`
  (`manual-order-page.component.ts:951-982`), que a su vez llama a
  `PosTerminalStore.createManualOrderFromDraft()` (`pos-terminal.store.ts:1570-1619`). Un único
  campo `order_type` (`'DINE_IN' | 'TAKEAWAY' | 'DELIVERY'`) distingue Mesa, Para llevar y
  Domicilio dentro del mismo método (`pos-terminal.store.ts:1597`).
- El backend ya responde con éxito y con el pedido completo (incluyendo su `id`) en
  `DiningSessionService.createManualOrder()` (`dining-session.service.ts:60-62`,
  `POST /orders`). El problema no es la creación en sí, sino qué hace el frontend con esa
  respuesta.
- **Línea exacta de la causa raíz**: tras una creación exitosa, `createManualOrderFromDraft()`
  solo guarda el ID internamente (`this.selectedOrderId.set(order.id)`,
  `pos-terminal.store.ts:1608`) y devuelve `Promise<boolean>` — **nunca devuelve el ID al
  llamador**. De vuelta en el componente, `manual-order-page.component.ts:978-981` navega siempre
  a la ruta fija de la terminal, sin ID y sin distinguir el tipo de pedido:
  ```ts
  const ok = await this.store.createManualOrderFromDraft();
  if (ok) {
    await this.router.navigate(['/dashboard/mesas-sesiones']);
  }
  ```
- **Por qué siempre termina en la pestaña "Mesas"** (no solo "sin detalle"): `PosTerminalStore` no
  es singleton — tanto `TableSessionsComponent` como `ManualOrderPageComponent` declaran su propia
  instancia vía `providers: [PosTerminalStore]` (`table-sessions.component.ts:64`,
  `manual-order-page.component.ts:70`). Al navegar a `/dashboard/mesas-sesiones` se construye una
  instancia nueva del store, cuyo signal `orderTypeTab` arranca siempre en `'mesas'`
  (`pos-terminal.store.ts:392`). El estado de pestaña nunca sobrevive la navegación, sin importar
  qué tipo de pedido se acabó de crear.
- **El panel "Cobrar pedido" vive en la terminal misma, no en una vista aparte**: existe un
  `OrderDetailComponent` en la ruta `orders/:id` (`routes.ts:210-214`), pero es una página de solo
  lectura (el panel admin "Órdenes") sin ningún panel de cobro. El panel con ese nombre literal —
  "Cobrar pedido" (`pos-checkout-panel.component.ts:224`) — el estado por ítem "Pendiente"
  (`order-status.util.ts:86`) y el encabezado por tipo (`pos-order-panel.component.ts:430-444`:
  "Mesa {N}" / "Para llevar" / "Domicilio" + "en preparación" / "pago pendiente" / "listo para
  cobrar") se renderizan **dentro de la terminal** (`/dashboard/mesas-sesiones`,
  `TableSessionsComponent`) cuando hay un pedido seleccionado (`store.selectedOrderId()`) —
  usando los mismos métodos de selección que ya existen para cuando el cajero elige una mesa o un
  pedido a mano (`selectTable()`, `selectOrder()`, `selectStandaloneOrder()`). "Llevar al usuario
  al detalle del pedido" significa, entonces, volver a esta misma terminal con esa selección ya
  hecha — no abrir una vista nueva.
- **Protección contra doble clic ya existe, pero solo a nivel de interfaz**: el signal
  `store.submitting` (`pos-terminal.store.ts:408`) se activa al iniciar la creación
  (`pos-terminal.store.ts:1582`) y se libera en un bloque `finally`
  (`pos-terminal.store.ts:1617`); el botón "Crear pedido" queda deshabilitado y cambia su etiqueta
  a "Guardando…" mientras `submitting()` es verdadero (`manual-order-page.component.ts:770,780`).
  No existe, sin embargo, una guarda defensiva dentro del propio método
  `createManualOrderFromDraft()` contra una segunda invocación o un reintento de red — la
  protección depende únicamente de que el botón esté deshabilitado en la interfaz. Tampoco existe
  hoy ningún mecanismo de idempotencia en el endpoint de creación de pedidos del backend: si la
  misma solicitud de creación se reintenta por una falla de red (no solo por un segundo clic en la
  interfaz), el backend la procesaría como un pedido nuevo.

## Clarifications

### Session 2026-10-11

- Q: ¿La prevención de pedidos duplicados por reintento de red (RN4) exige un cambio en el
  backend, o basta con una protección del lado del frontend? → A: Requiere backend — se agrega un
  mecanismo de idempotencia en el endpoint de creación de pedidos, además de la guarda ya existente
  en la interfaz.
- Q: El botón "atrás" nativo del navegador (no el botón de regreso dentro de la vista de detalle)
  ¿también debe llevar a la pestaña correcta de la terminal? → A: No. Solo el botón explícito
  dentro de la vista de detalle tiene esa garantía (RN3); el botón "atrás" nativo del navegador
  queda fuera de alcance de esta corrección.

  **Nota de implementación** (ver causa raíz, corrección de rumbo): al confirmarse que no existe
  una vista de detalle separada — el pedido se ve seleccionado dentro de la terminal misma —,
  "el botón de regreso" de esta decisión es, en la práctica, simplemente no navegar a ningún otro
  lado tras crear el pedido. Esta clarificación sigue vigente para RN3 (qué pestaña queda activa),
  pero ya no aplica a un botón explícito separado del botón "atrás" del navegador, porque no existe
  tal botón.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Redirección automática al detalle tras crear el pedido (Priority: P1)

Un cajero o mesero está en "Nueva orden", selecciona el tipo de pedido (Mesa, Para llevar o
Domicilio), agrega productos al carrito y pulsa "Crear pedido". En cuanto el backend confirma la
creación, el sistema debe llevarlo directo a la vista de detalle de ese pedido específico —
identificada por su ID — en vez de dejarlo en la terminal, en la pestaña Mesas, como ocurre hoy sin
importar el tipo de pedido creado.

**Why this priority**: es el comportamiento que resuelve el problema de negocio reportado — en la
heladería casi siempre se cobra justo después de tomar el pedido, sobre todo en "Para llevar", y
hoy esos 2-3 clics de navegación manual se repiten en cada venta. Sin esta historia no hay
funcionalidad que entregar.

**Independent Test**: se puede probar completamente creando un pedido de cualquiera de los tres
tipos desde "Nueva orden" con al menos un producto en el carrito, confirmando que tras la respuesta
exitosa del backend el sistema vuelve a la terminal con ese pedido ya seleccionado — mostrando de
inmediato su encabezado, sus ítems y el panel de cobro — en la pestaña correcta para ese tipo.

> **Nota de implementación** (ver causa raíz, corrección de rumbo tomada durante la
> implementación): "la vista de detalle" no es una pantalla separada — es la terminal
> (`/dashboard/mesas-sesiones`) mostrando el pedido recién creado ya seleccionado. Los textos
> entre comillas de los escenarios de abajo describen el *contenido* que debe verse (tipo de
> pedido, estado, ítems, total a cobrar), satisfecho por los elementos ya existentes de la
> terminal (`pos-order-panel`/`pos-checkout-panel`): "Mesa {N}"/"Para llevar"/"Domicilio" como
> encabezado, "en preparación"/"pago pendiente"/"listo para cobrar" como estado, "Pendiente" por
> ítem, y "Cobrar pedido" con el total — no un string literal nuevo a reproducir byte por byte.

**Acceptance Scenarios**:

1. **Given** que estoy en "Nueva orden" con el tipo "Para llevar" seleccionado y 1 "Ensalada de
   frutas grande" en el carrito, **When** pulso "Crear pedido" y el sistema confirma la creación,
   **Then** se abre la vista de detalle de ese pedido, veo el encabezado "Pedido para llevar" con
   estado "En preparación", el ítem "Ensalada de frutas grande" con estado "Pendiente", y el panel
   "Cobrar pedido" con el total correspondiente.
2. **Given** que estoy en "Nueva orden" con el tipo "Mesa" seleccionado y productos en el carrito,
   **When** creo el pedido con éxito, **Then** se abre el detalle del pedido creado con el
   encabezado "Pedido · Mesa N" (N = número de esa mesa), y el botón de regreso me lleva a la
   pestaña "Mesas" de la terminal.
3. **Given** que estoy en "Nueva orden" con el tipo "Domicilio" seleccionado y productos en el
   carrito, **When** creo el pedido con éxito, **Then** se abre el detalle del pedido creado con el
   encabezado "Pedido a domicilio", y el botón de regreso me lleva a la pestaña "Domicilios" de la
   terminal.
4. **Given** que fui redirigido al detalle de un pedido recién creado, **When** recargo el
   navegador, **Then** sigo viendo el detalle del mismo pedido (la vista se identifica por el ID
   del pedido, no por un estado temporal de navegación).

---

### User Story 2 - El carrito se conserva si la creación del pedido falla (Priority: P2)

Si el backend responde con un error al crear el pedido, el cajero o mesero no debe perder el
trabajo que ya hizo armando el pedido: debe seguir en "Nueva orden", con el carrito intacto
(productos, cantidades y tipo de pedido), y debe quedar claro que el pedido no se creó.

**Why this priority**: sin esta protección, un error transitorio del servidor obligaría a rearmar
el pedido completo desde cero, además del riesgo de que el cajero crea que el pedido sí se creó
cuando en realidad no existe en la terminal.

**Independent Test**: se puede probar completamente simulando una respuesta de error del servidor
al pulsar "Crear pedido" con productos en el carrito, y verificando que la vista sigue siendo
"Nueva orden" con el carrito sin cambios, que aparece el mensaje de error, y que no aparece ningún
pedido nuevo en la terminal.

**Acceptance Scenarios**:

1. **Given** que estoy en "Nueva orden" con productos en el carrito, **When** pulso "Crear pedido"
   y el servidor responde con un error, **Then** sigo en la vista "Nueva orden", el carrito
   conserva sus productos, cantidades y el tipo de pedido, veo el mensaje "No se pudo crear el
   pedido. Intenta de nuevo.", y no se crea ningún pedido en la terminal.

---

### User Story 3 - Un pedido no se duplica por doble clic ni por reintento de red (Priority: P3)

El cajero o mesero puede pulsar "Crear pedido" dos veces seguidas por accidente (doble clic, o una
conexión lenta que lo hace reintentar), y eso no debe generar dos pedidos. Solo debe quedar creado
uno, y el sistema debe terminar mostrando el detalle de ese único pedido.

**Why this priority**: un pedido duplicado en la terminal (y potencialmente en cocina/caja) genera
confusión operativa y riesgo de cobrar o preparar de más; es una protección necesaria, pero de
menor impacto inmediato que entregar la redirección en sí (P1) o proteger el carrito ante errores
(P2).

**Independent Test**: se puede probar completamente pulsando "Crear pedido" dos veces en rápida
sucesión (o forzando un reintento de red) con productos en el carrito, y verificando que solo se
crea un pedido y que el sistema abre el detalle de ese único pedido.

**Acceptance Scenarios**:

1. **Given** que estoy en "Nueva orden" con productos en el carrito, **When** pulso "Crear pedido"
   dos veces seguidas, **Then** se crea un único pedido, el botón se deshabilita y muestra un
   indicador de carga hasta recibir respuesta, y se abre el detalle de ese único pedido.

---

### Edge Cases

- **Reintento de red tras una respuesta perdida**: si la petición de creación del pedido llega al
  backend y se crea el pedido, pero la respuesta nunca llega al cliente (timeout) y el sistema o el
  usuario reintentan, no debe quedar un segundo pedido creado por el mismo carrito (RN4 aplica
  también a este caso, no solo al doble clic en la interfaz).
- **Botón "atrás" nativo del navegador tras la redirección**: queda fuera de alcance de esta
  corrección garantizar explícitamente su comportamiento (ver Clarifications, sesión 2026-10-11).
  En la práctica, como la terminal ya muestra el pedido correcto en la misma URL de siempre
  (`/dashboard/mesas-sesiones?...`), "atrás" normalmente devuelve a "Nueva orden" (la pantalla
  anterior en el historial), sin garantía adicional más allá de esa.
- **Error de red después de que el pedido ya se creó en el backend** (la petición tuvo éxito en el
  servidor pero la confirmación no llegó al cliente, p. ej. por corte de conexión): el pedido existe
  en la terminal aunque el cajero haya visto un error; queda fuera del alcance de esta corrección
  resolver esa reconciliación — se documenta como riesgo conocido, no como requisito de esta spec.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema DEBE volver automáticamente a la terminal con el pedido recién creado ya
  seleccionado (mostrando su detalle: ítems, estado y panel de cobro) inmediatamente después de
  que el backend confirme la creación exitosa (respuesta 2xx con el ID del pedido), para los tres
  tipos de pedido (Mesa, Para llevar, Domicilio), en vez de dejar la pestaña Mesas sin nada
  seleccionado.
- **FR-002**: La selección del pedido DEBE identificarse mediante el ID devuelto por el backend
  (viajando en la URL, no en memoria), de forma que recargar el navegador en la terminal siga
  mostrando el mismo pedido seleccionado.
- **FR-003**: Si la creación del pedido falla (error del servidor o de red), el sistema DEBE
  mantener al usuario en la vista "Nueva orden", conservando productos, cantidades y tipo de
  pedido seleccionados en el carrito, sin redirigir a ninguna otra vista.
- **FR-004**: Cuando falle la creación, el sistema DEBE mostrar el mensaje "No se pudo crear el
  pedido. Intenta de nuevo." y no debe quedar ningún pedido nuevo creado en la terminal.
- **FR-005**: El sistema DEBE deshabilitar el botón "Crear pedido" y mostrar un indicador de carga
  desde el primer clic hasta recibir respuesta del backend.
- **FR-006**: El sistema DEBE impedir, desde la interfaz, que un segundo clic mientras la primera
  solicitud de creación está en curso dispare una segunda petición de creación de pedido.
- **FR-007**: La terminal DEBE mostrar, junto al pedido seleccionado, un encabezado que identifique
  su tipo: la mesa asociada (Mesa), o el tipo de pedido (Para llevar/Domicilio) cuando no hay mesa.
- **FR-008**: La terminal DEBE activar, al volver tras crear el pedido, la pestaña correspondiente
  a su tipo (Mesas, Para llevar o Domicilios respectivamente) — no siempre "Mesas" por defecto.
- **FR-009**: La terminal DEBE mostrar, para el pedido seleccionado, su estado de preparación,
  cada ítem con su estado individual ("Pendiente" al crearse), y el panel de cobro con el total
  del pedido.
- **FR-010**: La redirección automática NO DEBE alterar el comportamiento ya existente de la
  terminal cuando se llega a ella por otros caminos (por ejemplo, por el menú de navegación, sin
  ningún pedido recién creado de por medio) ni el de la vista de detalle de "Órdenes"/admin
  (`/dashboard/orders/:id`), que no interviene en este flujo.
- **FR-011**: El backend DEBE garantizar, mediante un mecanismo de idempotencia en el endpoint de
  creación de pedidos, que un reintento de red sobre la misma solicitud de creación (p. ej. el
  cliente no recibe la respuesta y reintenta) no genere un segundo pedido.

### Key Entities

- **Pedido**: unidad creada desde "Nueva orden"; tiene un ID único, un tipo (Mesa, Para llevar,
  Domicilio), un estado ("En preparación" al crearse), una lista de ítems, y — cuando es de tipo
  Mesa — una mesa asociada con su número.
- **Ítem de pedido**: producto incluido en el pedido, con su cantidad y un estado individual
  ("Pendiente" al crearse).
- **Pestaña de la terminal**: una de "Mesas", "Para llevar" o "Domicilios"; cuál queda activa al
  volver tras crear el pedido depende de su tipo.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Tras crear un pedido exitosamente, el 100% de las veces el usuario ve el detalle de
  ese pedido específico sin necesidad de ninguna navegación manual adicional, para los tres tipos
  de pedido.
- **SC-002**: El número de clics necesarios para llegar del carrito completado al panel "Cobrar
  pedido" se reduce en al menos 2 clics respecto al comportamiento actual, para los tres tipos de
  pedido.
- **SC-003**: Cero pedidos duplicados: ningún doble clic ni reintento de red sobre el mismo carrito
  produce más de un pedido, verificado en el 100% de los intentos de prueba.
- **SC-004**: El 100% de los casos de error en la creación preservan el carrito intacto (productos,
  cantidades y tipo de pedido) y muestran el mensaje de error especificado, sin crear ningún pedido.
- **SC-005**: Un pedido recién creado sigue siendo visible en su vista de detalle tras recargar el
  navegador, sin pérdida de contexto, en el 100% de los casos.

## Assumptions

- "La vista de detalle del pedido" es la terminal misma (`/dashboard/mesas-sesiones`) con el
  pedido ya seleccionado — no una pantalla nueva ni la vista de solo lectura de "Órdenes"/admin.
  Los paneles que muestran encabezado, estado, ítems y total a cobrar ya existen en la terminal
  para cuando el cajero selecciona algo a mano; esta corrección solo hace que esa misma selección
  ocurra automáticamente al volver de crear un pedido (confirmado durante la implementación, ver
  causa raíz).
- El mecanismo exacto para que la terminal recuerde qué pestaña/mesa/pedido mostrar al volver es
  una decisión técnica de implementación (p. ej. parámetros en la ruta); esta spec exige el
  resultado observable (RN3, FR-008), no la técnica. El botón "atrás" nativo del navegador queda
  explícitamente fuera de esa garantía (ver Clarifications).
- La técnica concreta del mecanismo de idempotencia del backend (FR-011) — p. ej. una idempotency
  key enviada por el cliente, una restricción de unicidad sobre algún identificador de la
  solicitud, u otra — es una decisión técnica que se define en la fase de planificación; esta spec
  exige el resultado observable (cero pedidos duplicados por reintento de red, RN4/SC-003).
- El número de mesa (N) usado en el encabezado "Pedido · Mesa N" ya está disponible como parte de
  los datos del pedido o de la mesa asociada, sin requerir una consulta adicional no contemplada
  hoy.
- La reconciliación de un pedido que se creó en el backend pero cuya confirmación no llegó al
  cliente por un corte de red (ver Edge Cases) queda fuera de alcance de esta corrección.
