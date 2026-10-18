# Feature Specification: Visibilidad de categorías en el menú QR

**Feature Branch**: `128-categoria-visible-menu-qr`

**Created**: 2026-10-18

**Status**: Draft

**Input**: User description: "Como administrador del negocio, quiero ocultar o mostrar una
categoría solo en el menú QR, para decidir qué productos pueden pedir los comensales por su
cuenta, sin quitarlos de la venta que hace el personal en caja o en mesa." (brief completo con
reglas de negocio, escenarios Given/When/Then y notas técnicas/UX adjunto en la invocación de
`/speckit-specify`).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - El administrador oculta o muestra una categoría del menú QR (Priority: P1)

Quien administra el negocio quiere decidir, categoría por categoría, cuáles puede pedir un
comensal por su cuenta desde el menú QR — sin tener que desactivar la categoría por completo
(lo que también la quitaría del catálogo que usa el personal) ni reordenar nada para lograrlo.

**Why this priority**: es el corazón de la funcionalidad — sin esto no existe ningún control de
visibilidad en QR distinto del que ya existe (activar/desactivar la categoría entera). Es
además la única historia que, por sí sola, ya entrega el valor de negocio completo: un
comensal que abre el menú QR después de que se ocultó una categoría ya no la ve.

**Independent Test**: puede probarse por completo ocultando una categoría activa desde la
pantalla de administración, recargando el menú QR público y confirmando que la categoría y sus
productos ya no aparecen, mientras que siguen disponibles al armar un pedido manual desde caja
o mesa.

**Acceptance Scenarios**:

1. **Given** la categoría "Con licor" está activa y visible en el menú QR, **When** el
   administrador acciona "Ocultar del menú QR" en esa categoría, **Then** la categoría muestra
   el indicador "Oculta en QR", y al recargar el menú QR la categoría "Con licor" y sus
   productos ya no aparecen, y en "Nuevo pedido" desde caja o mesa la categoría "Con licor" y
   sus productos siguen disponibles exactamente igual que antes.
2. **Given** la categoría "Con licor" está oculta en el menú QR, **When** el administrador
   acciona "Mostrar en menú QR", **Then** la categoría vuelve a aparecer en el menú QR, en la
   misma posición que ya tenía según su campo Orden (el ocultamiento no lo altera).
3. **Given** un comensal busca un producto de una categoría oculta en el menú QR, **When**
   escribe en el buscador del menú, **Then** ese producto no aparece entre los resultados.
4. **Given** la categoría "Helados" está inactiva, **When** el administrador abre la pantalla
   de Categorías, **Then** la acción de visibilidad en QR aparece deshabilitada para "Helados",
   con un texto de ayuda que indica "Activa la categoría para controlar su visibilidad en QR".
5. **Given** un usuario con rol Cajero está en la pantalla de Categorías, **Then** no ve la
   acción de visibilidad en QR, y si llama directamente al mecanismo que la cambia, recibe un
   error de permiso denegado.

---

### User Story 2 - El pedido de un comensal se corrige si algo de su carrito dejó de estar disponible en QR (Priority: P2)

Un comensal pudo haber agregado al carrito un producto de una categoría que, mientras tanto, el
administrador ocultó del menú QR. El sistema no debe permitir que ese pedido se complete con
productos que ya no deberían ofrecerse por QR — pero tampoco debe perder silenciosamente el
resto del pedido ni dejar al comensal sin explicación.

**Why this priority**: protege la regla de negocio central (US1) de quedar rota por una
ventana de tiempo — sin esto, ocultar una categoría no sería una garantía real mientras haya
carritos ya armados en curso. Depende de que US1 exista (la noción de "categoría oculta en QR")
pero es una historia propia, verificable por separado.

**Independent Test**: puede probarse agregando un producto de una categoría al carrito de un
comensal, ocultando esa categoría del menú QR, y luego enviando el pedido — el producto debe
rechazarse y quitarse del carrito, con un mensaje explicativo, sin bloquear el resto del
pedido.

**Acceptance Scenarios**:

1. **Given** un comensal tiene en su carrito un producto de la categoría "Con licor", **And**
   el administrador oculta "Con licor" del menú QR, **When** el comensal envía su pedido,
   **Then** el sistema rechaza los productos de categorías ocultas en QR, el comensal ve el
   mensaje "Algunos productos ya no están disponibles y se quitaron de tu carrito", y el
   carrito queda actualizado sin esos productos (el resto del pedido, si lo hay, puede
   reintentarse).

---

### User Story 3 - El menú QR ya abierto se actualiza sin que el comensal tenga que recargar (Priority: P3)

Si un comensal ya tiene el menú QR abierto en su teléfono cuando el administrador oculta o
vuelve a mostrar una categoría, el cambio se refleja solo, sin que tenga que salir y volver a
escanear o refrescar la página manualmente.

**Why this priority**: es una mejora de experiencia sobre US1, no una condición para que la
regla de negocio funcione — US1 ya garantiza el resultado correcto "al recargar el menú QR".
Se entrega aparte y después porque hoy el menú QR, una vez abierto, no vuelve a consultar el
catálogo por su cuenta (ver Assumptions); es la única de las tres historias que agrega una
capacidad nueva de por sí, no solo una corrección de alcance.

**Independent Test**: puede probarse abriendo el menú QR en un dispositivo, ocultando (o
volviendo a mostrar) una categoría desde la administración sin recargar la pantalla del
comensal, y confirmando que la categoría aparece/desaparece sola en ese dispositivo.

**Acceptance Scenarios**:

1. **Given** un comensal tiene el menú QR abierto, **When** el administrador oculta una
   categoría que el comensal está viendo, **Then** esa categoría y sus productos desaparecen de
   la pantalla del comensal sin que haya recargado la página.
2. **Given** un comensal tiene el menú QR abierto, **When** el administrador vuelve a mostrar
   una categoría oculta, **Then** esa categoría reaparece en la pantalla del comensal sin que
   haya recargado la página.

---

### Edge Cases

- ¿Qué pasa si se oculta la última categoría que le quedaba visible al menú QR? El menú QR
  queda sin ninguna categoría ni producto para mostrar — se comporta igual que cualquier otro
  caso de "sin productos disponibles", sin ningún error especial.
- ¿Qué pasa si se oculta una categoría que ya está inactiva? No aplica: la acción de
  visibilidad en QR solo existe para categorías activas (ver Escenario 4 de US1) — una
  categoría inactiva ya no aparece en el menú QR por esa sola razón, sin importar su
  `visible_en_qr`.
- ¿Qué pasa si se reactiva una categoría que había quedado marcada como oculta en QR mientras
  estaba inactiva? Conserva el valor de visibilidad en QR que ya tenía (no se reinicia a
  visible al reactivar) — el administrador debe mostrarla en QR explícitamente si así lo
  quiere.
- ¿Qué pasa con los pedidos QR ya enviados antes de ocultar la categoría? No se ven afectados
  en absoluto — la restricción aplica únicamente a pedidos nuevos que se intenten enviar
  después del cambio.
- ¿Qué pasa con el campo Orden (posición) de una categoría mientras está oculta en QR? No se
  modifica — al volver a mostrarla, reaparece exactamente en esa misma posición.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST permitir marcar cada categoría como visible u oculta
  específicamente en el menú QR, de forma independiente a si la categoría está activa o
  inactiva. Toda categoría ya existente MUST quedar visible en QR por defecto.
- **FR-002**: El menú QR (y su buscador) MUST mostrar una categoría, y los productos que le
  pertenecen, únicamente cuando la categoría está activa Y visible en QR a la vez — si falta
  cualquiera de las dos condiciones, la categoría y sus productos no aparecen.
- **FR-003**: Ocultar una categoría del menú QR MUST dejarla intacta en todo lo demás: el
  catálogo de productos del personal, la creación de pedidos manuales (desde caja, mesa o
  administración) y los reportes MUST seguir mostrándola y permitiendo venderla exactamente
  igual que antes.
- **FR-004**: Cambiar la visibilidad en QR de una categoría MUST conservar su posición (campo
  Orden) sin alterarla — al volver a mostrarla, MUST reaparecer en esa misma posición.
- **FR-005**: Únicamente un usuario con rol Administrador MUST poder cambiar la visibilidad en
  QR de una categoría; cualquier intento por parte de otro rol (p. ej. Cajero) MUST rechazarse,
  tanto si se intenta desde la pantalla de administración (la acción ni siquiera se ofrece)
  como si se intenta de forma directa sin pasar por esa pantalla.
- **FR-006**: El sistema MUST impedir cambiar la visibilidad en QR de una categoría que está
  inactiva, y MUST comunicar al administrador que debe activarla primero para poder
  controlarla.
- **FR-007**: Cuando un comensal intenta enviar un pedido que incluye uno o más productos de
  una categoría que quedó oculta en QR después de que el producto ya estaba en su carrito, el
  sistema MUST rechazar esos productos específicos (no el pedido completo si incluye otros
  productos válidos), MUST quitarlos del carrito del comensal, y MUST informarle que algunos
  productos ya no estaban disponibles y se quitaron.
- **FR-008**: El sistema MUST reflejar un cambio de visibilidad en QR en la siguiente vez que
  se cargue el menú QR (recarga de página o nueva sesión), sin ningún paso manual adicional por
  parte del administrador.
- **FR-009**: El sistema SHOULD actualizar automáticamente un menú QR que un comensal ya tiene
  abierto cuando su visibilidad cambia, sin exigirle recargar la página (US3) — esta capacidad
  es una mejora sobre FR-008, no un reemplazo: FR-008 MUST cumplirse incluso si esta no se
  implementa.
- **FR-010**: La pantalla de administración de categorías MUST mostrar, para cada categoría
  activa, su estado actual de visibilidad en QR y MUST ofrecer una acción reversible de un solo
  paso para cambiarlo (sin exigir una confirmación adicional, dado que no destruye ningún dato
  y puede revertirse de inmediato).
- **FR-011**: El selector de filtro de la pantalla de administración de categorías MUST
  permitir encontrar específicamente las categorías ocultas en QR.

### Key Entities *(include if feature involves data)*

- **Categoría**: entidad ya existente del catálogo (tiene nombre, estado activo/inactivo,
  posición de orden, y agrupa productos). Gana un nuevo atributo de **visibilidad en el menú
  QR** (verdadero por defecto), independiente de su estado activo/inactivo y de su posición de
  orden. Cada producto pertenece a exactamente una categoría, así que ocultar una categoría del
  menú QR oculta siempre el 100% de sus productos ahí — no hay ningún caso de un producto
  "parcialmente visible" por pertenecer a varias categorías.
- **Carrito del comensal**: puede contener, en el momento de enviarse como pedido, productos
  cuya categoría quedó oculta en QR después de haberse agregado — el envío revalida esto y
  corrige el carrito en consecuencia (FR-007).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un administrador puede ocultar o volver a mostrar una categoría del menú QR en
  menos de 10 segundos, sin tener que reconfigurar ni recrear la categoría.
- **SC-002**: El 100% de los productos de una categoría oculta en QR dejan de aparecer en el
  menú QR y en su buscador la próxima vez que se carga, mientras que el 100% de ellos sigue
  disponible para pedidos manuales desde caja, mesa o administración.
- **SC-003**: El 100% de los intentos de un comensal de enviar un pedido con un producto cuya
  categoría quedó oculta en QR se rechazan específicamente por ese producto, con el carrito
  resultante libre de productos no disponibles y sin perder el resto del pedido.
- **SC-004**: El 100% de los intentos de cambiar la visibilidad en QR por parte de un usuario
  sin rol Administrador se rechazan, tanto desde la interfaz como desde un intento directo.
- **SC-005**: Al reactivar el control de visibilidad para una categoría que estuvo oculta en
  QR, esta recupera exactamente la misma posición (Orden) que tenía antes de ocultarse, el
  100% de las veces.

## Assumptions

- **Un producto pertenece a exactamente una categoría** en el modelo actual del sistema (no a
  varias a la vez) — por eso esta spec no incluye ninguna regla sobre "productos compartidos
  entre categorías con distinta visibilidad": siempre que su categoría se oculta, el producto
  se oculta con ella, sin excepción.
- El mecanismo que hoy permite editar una categoría (incluyendo su activo/orden) **no
  distingue por rol de usuario** — cualquier usuario autenticado del tenant puede editarla hoy,
  no solo el Administrador. Esta spec introduce, por primera vez, una restricción de rol — pero
  acotada explícitamente a la acción de cambiar la visibilidad en QR (FR-005); si esa
  restricción conviene extenderla al resto de la edición de categorías es una decisión aparte,
  fuera del alcance de esta spec.
- El menú QR no tiene hoy ninguna capa de caché (ni en servidor ni en el navegador) por delante
  de los datos que lo alimentan — un cambio de visibilidad ya queda disponible la próxima vez
  que se carga el menú, sin ningún paso de invalidación adicional (cubre FR-008 tal cual).
- El menú QR, una vez que un comensal lo abre, hoy carga el catálogo una sola vez y no vuelve a
  consultarlo por su cuenta mientras la sesión sigue abierta — por eso US3/FR-009 (que un menú
  ya abierto se actualice solo) es una capacidad nueva que se entrega aparte, con prioridad más
  baja que el resultado que FR-008 ya garantiza con una recarga manual.
- Los textos exactos de interfaz mencionados en los escenarios (p. ej. "Oculta en QR",
  "Mostrar en menú QR", el mensaje al comensal) se tratan como parte del comportamiento
  esperado de cara al usuario, no como un detalle de implementación.
