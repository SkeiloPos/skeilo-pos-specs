# Feature Specification: Visibilidad de promociones en el menú QR

**Feature Branch**: `144-promociones-visibles-menu-qr`

**Created**: 2026-10-29

**Status**: Draft

## Clarifications

### Session 2026-10-29

- Q: Cuando una promoción tiene varias reglas con conjuntos de productos distintos (por
  ejemplo, una regla de paquete sobre las variantes A y B, y otra regla separada solo sobre la
  variante C), y C está oculta en el menú QR pero A y B no, ¿la regla de C debe desaparecer del
  detalle público de la promoción aunque la promoción en sí se siga mostrando, o se muestra la
  promoción completa con todas sus reglas tal cual están configuradas? → A: Solo nivel
  promoción — la promoción se evalúa y se muestra (o no) como un todo; si al menos un producto
  alcanzable por QR existe en cualquiera de sus reglas, la promoción completa se muestra con
  todas sus reglas tal cual están configuradas, sin filtrar reglas individuales del detalle
  público.

**Input**: User description: "necesito que hagas un ajuste en el menu qr, cuando no exista
ninguna promocion activa, la seccion de promociones no se deberia de mostrar, esta se muestra
cuando existe al menos una promocion activa, y lo otro es que quiero controlar si una promocion
se deberia mostrar en el menu qr, asi como sucede con los productos, que decido que no se vean
en el menu qr, pero se siguen mostrando en el catalogo de la orden manual, quiero replicar el
mismo comportamiento pero en las promociones, si tienes alguna duda me preguntas"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - La pestaña de promociones se oculta cuando no hay nada que anunciar (Priority: P1)

Un comensal que abre el menú QR y no tiene ninguna promoción vigente para ofrecerle no debería
ver una pestaña "Promociones" que solo lo lleva a un mensaje de "No hay promociones activas en
este momento". Esa pestaña debe aparecer únicamente cuando existe, en ese instante, al menos
una promoción que el comensal pueda aprovechar por QR.

**Why this priority**: es el ajuste explícitamente pedido para el caso de hoy (captura
adjunta) — sin esto, el menú QR sigue mostrando una pestaña vacía que confunde al comensal y le
hace perder un paso de navegación sin ningún beneficio.

**Independent Test**: puede probarse por completo pausando o dejando vencer todas las
promociones del tenant, recargando el menú QR y confirmando que la pestaña "Promociones" ya no
aparece entre las pestañas superiores; luego activando una promoción y confirmando que la
pestaña vuelve a aparecer.

**Acceptance Scenarios**:

1. **Given** ninguna promoción del tenant está vigente en este momento, **When** un comensal
   abre o recarga el menú QR, **Then** la pestaña "Promociones" no aparece entre las pestañas
   del menú.
2. **Given** al menos una promoción está vigente y visible en el menú QR, **When** un comensal
   abre el menú QR, **Then** la pestaña "Promociones" aparece normalmente y, al seleccionarla,
   muestra esa promoción.
3. **Given** la única promoción vigente deja de estarlo (se pausa, vence o se agota su ventana
   horaria) mientras el comensal navega el menú, **When** el comensal vuelve a consultar el
   menú (recarga o reabre), **Then** la pestaña "Promociones" ya no aparece.

---

### User Story 2 - El administrador decide si una promoción se ofrece por QR (Priority: P1)

Quien administra el negocio quiere poder decidir, promoción por promoción, si se ofrece a los
comensales que piden por su cuenta desde el menú QR, sin tener que pausarla ni desactivarla —
porque el personal en caja o en mesa debe poder seguir aplicándola con normalidad al armar un
pedido manual. Esto replica, para promociones, el mismo control de visibilidad que ya existe
para productos y categorías.

**Why this priority**: es el segundo ajuste pedido explícitamente — sin esto, no existe forma
de ofrecer una promoción solo al personal (por ejemplo, una promoción que requiere que el mesero
verifique algo, o una pensada como cortesía del personal) sin que también le llegue a cualquier
comensal por QR.

**Independent Test**: puede probarse por completo marcando una promoción activa como "No
mostrar en menú QR" desde la administración, recargando el menú QR y confirmando que esa
promoción ya no aparece ni cuenta para mostrar la pestaña de promociones (US1), mientras que al
armar un pedido manual desde caja o mesa la promoción sigue disponible y se sigue aplicando
exactamente igual que antes.

**Acceptance Scenarios**:

1. **Given** una promoción está activa y vigente, **When** el administrador la marca como "No
   mostrar en menú QR", **Then** la promoción muestra el indicador correspondiente en la
   administración, y al recargar el menú QR esa promoción ya no aparece (ni se cuenta para
   decidir si la pestaña de promociones se muestra), mientras que en "Nuevo pedido" desde caja o
   mesa la promoción sigue disponible y se sigue aplicando con normalidad.
2. **Given** una promoción está oculta en el menú QR, **When** el administrador la vuelve a
   marcar como visible en el menú QR, **Then** la promoción vuelve a aparecer en el menú QR (si
   sigue vigente), sin perder ninguna otra configuración de la promoción (reglas, vigencia,
   estado).
3. **Given** una promoción está inactiva, pausada o terminada, **When** el administrador abre su
   pantalla de edición, **Then** el control de visibilidad en QR sigue siendo visible y
   configurable, pero no tiene efecto en el menú QR hasta que la promoción vuelva a estar
   vigente.
4. **Given** un usuario con un rol sin permiso para administrar promociones, **Then** no ve el
   control de visibilidad en QR en la pantalla de promociones, y si invoca directamente el
   mecanismo que lo cambia, recibe un error de permiso denegado.

---

### User Story 3 - Una promoción oculta en QR no se cuenta como descuento ofrecido al comensal (Priority: P2)

Si un comensal ya tiene en su carrito un producto que calificaba para una promoción que el
administrador acaba de ocultar del menú QR, el pedido que el comensal envíe por su cuenta no
debe aplicar silenciosamente ese descuento — del mismo modo en que un producto oculto deja de
estar disponible para el pedido por QR aunque ya estuviera en el carrito.

**Why this priority**: protege la regla central (US2) de quedar rota por una ventana de tiempo
entre que el comensal arma su carrito y lo envía. Es una historia propia, verificable por
separado, y de prioridad menor porque US1 y US2 ya entregan el valor principal pedido (ocultar
la pestaña y poder marcar promociones como no visibles en QR).

**Independent Test**: puede probarse agregando al carrito, desde el menú QR, un producto que
califica para una promoción visible en QR, ocultando luego esa promoción desde la
administración, y enviando el pedido del comensal — el pedido se acepta sin aplicar esa
promoción (el comensal paga el precio sin el descuento), sin bloquear el resto del pedido.

**Acceptance Scenarios**:

1. **Given** un comensal tiene en su carrito, armado desde el menú QR, un producto que calificó
   para una promoción visible en QR, **And** el administrador oculta esa promoción del menú QR,
   **When** el comensal envía su pedido, **Then** el pedido se procesa sin aplicar el descuento
   de esa promoción, y el total refleja el precio normal del producto.

---

### Edge Cases

- ¿Qué pasa si una promoción visible en QR aplica solo sobre productos que, a su vez, están
  ocultos en el menú QR (o pertenecen a una categoría oculta en QR)? La promoción no debe
  contarse como "vigente para el comensal" ni mostrarse en la pestaña de promociones del menú
  QR, porque ninguno de sus productos es alcanzable desde ahí.
- ¿Qué pasa con una promoción visible en QR pero fuera de su ventana horaria o de sus días de la
  semana configurados en este momento? No cuenta como vigente para efectos de mostrar la
  pestaña ni de aparecer en el listado de promociones del menú QR (igual que hoy, vigencia y
  visibilidad en QR son condiciones independientes y ambas deben cumplirse).
- ¿Qué pasa si todas las promociones visibles en QR dejan de estar vigentes mientras el
  comensal tiene la pestaña de promociones abierta? El comportamiento es el mismo que hoy tiene
  el menú QR ante otros cambios de catálogo mientras está abierto (se refleja al recargar/volver
  a consultar, salvo que el menú QR ya tenga un mecanismo de actualización en vivo para otro
  tipo de cambios, en cuyo caso este ajuste no necesita igualarlo).
- ¿Qué pasa si se oculta en QR una promoción que en este momento está anunciada en el carrito de
  un comensal pero este aún no ha enviado el pedido? El anuncio deja de mostrarse la próxima vez
  que el comensal consulte el menú o el carrito, y al enviar el pedido aplica la regla de la
  Historia 3 (no se aplica el descuento).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema DEBE permitir marcar cada promoción, de forma independiente a su
  estado (`draft`/`active`/`paused`/`finished`) y a su vigencia, como visible u oculta en el
  menú QR — igual que el control existente de visibilidad en QR para productos y categorías.
- **FR-002**: Al crear una promoción nueva, el sistema DEBE dejarla visible en el menú QR por
  defecto, salvo que el administrador indique lo contrario.
- **FR-003**: El menú QR público DEBE excluir del listado de promociones anunciadas a cualquier
  promoción marcada como oculta en el menú QR, aunque esté activa y vigente.
- **FR-004**: El menú QR público DEBE excluir del listado de promociones anunciadas a cualquier
  promoción cuyos productos o variantes alcanzables estén todos ocultos en el menú QR (por
  ocultamiento del producto o de su categoría), aunque la promoción en sí esté marcada como
  visible en QR. Esta evaluación de "alcanzable" se hace a nivel de la promoción completa (no
  por regla individual dentro de ella): si al menos un producto o variante de cualquiera de sus
  reglas es alcanzable por QR, la promoción se muestra completa, con todas sus reglas tal cual
  están configuradas, sin filtrar u ocultar reglas individuales del detalle público.
- **FR-005**: El sistema DEBE ocultar por completo la sección/pestaña de promociones del menú QR
  cuando, en el momento de la consulta, no exista ninguna promoción que cumpla a la vez: estar
  vigente (estado `active` dentro de su ventana de fechas/horario/días), estar marcada como
  visible en QR, y tener al menos un producto o variante alcanzable desde el menú QR.
- **FR-006**: El sistema DEBE mostrar la sección/pestaña de promociones del menú QR cuando exista
  al menos una promoción que cumpla las tres condiciones de FR-005.
- **FR-007**: La administración de pedidos manuales (caja o mesa) DEBE seguir ofreciendo y
  aplicando con normalidad cualquier promoción vigente, sin importar si está marcada como
  oculta en el menú QR — el ocultamiento en QR no afecta su disponibilidad fuera del menú QR.
- **FR-008**: El sistema DEBE excluir el descuento de cualquier promoción oculta en el menú QR
  al calcular y aplicar el pedido que un comensal envía por su cuenta desde el menú QR, aunque
  el producto ya estuviera en su carrito antes de ocultarse la promoción.
- **FR-009**: El sistema DEBE restringir el cambio de visibilidad en QR de una promoción a los
  roles que ya tienen permiso para administrar promociones, devolviendo un error de permiso
  denegado ante cualquier intento de un rol sin ese permiso.
- **FR-010**: La pantalla de administración de promociones DEBE mostrar, por cada promoción, un
  indicador claro de si está visible u oculta en el menú QR, y un control para cambiarlo,
  disponible sin importar el estado de la promoción.

### Key Entities *(include if feature involves data)*

- **Promoción**: agrupa una o más reglas de descuento con vigencia y estado propios. Gana un
  atributo de visibilidad en el menú QR, independiente de su estado y de su vigencia, análogo al
  que ya tienen `Producto` y `Categoría`.
- **Anuncio de promoción en el menú QR**: representación pública de una promoción vigente que se
  muestra al comensal; solo se construye a partir de promociones visibles en QR cuyos productos
  alcanzables también lo sean.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Cuando no hay ninguna promoción ofrecible por QR, el 100% de las cargas del menú
  QR no muestran la pestaña de promociones.
- **SC-002**: El administrador puede ocultar o volver a mostrar una promoción en el menú QR en
  menos de 2 acciones (por ejemplo, un interruptor) desde la pantalla de promociones, sin
  navegar a otra pantalla.
- **SC-003**: Una promoción marcada como oculta en el menú QR deja de aparecer en el menú QR y en
  cualquier pedido enviado por un comensal, mientras sigue apareciendo y aplicándose en el 100%
  de los pedidos manuales creados desde caja o mesa.

## Assumptions

- Se asume que "promoción activa" para efectos de mostrar la pestaña de promociones del menú QR
  significa lo mismo que ya usa el menú QR hoy para anunciar promociones: estado `active` y
  dentro de su ventana de vigencia (fechas, horario y días de la semana), evaluada en hora local
  del tenant — sin introducir una noción distinta de "activa".
- Se asume que el campo de visibilidad en QR se agrega a nivel de `Promoción` (no por regla
  individual dentro de ella), porque todas las reglas de una promoción ya comparten vigencia y
  estado, siguiendo el mismo patrón de partición que el resto del modelo.
- Se asume que el comportamiento de actualización en vivo del menú QR ya abierto (si existe hoy
  para categorías/productos ocultos) no es un requisito nuevo de este ajuste; si el menú QR hoy
  solo refleja estos cambios al recargar, este ajuste mantiene ese mismo comportamiento para
  promociones.
- Se asume que ocultar una promoción en el menú QR no cancela descuentos ya aplicados a pedidos
  que el comensal ya envió antes de ocultarla — solo afecta pedidos nuevos o carritos aún no
  enviados.
