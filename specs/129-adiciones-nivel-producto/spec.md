# Feature Specification: Adiciones (toppings) configuradas a nivel de producto y vendibles como línea independiente

**Feature Branch**: `129-adiciones-nivel-producto`

**Created**: 2026-10-19

**Status**: Draft

**Input**: User description: "hoy en dia los toppings se configura mediante un grupo de opciones,
en cierta forma funciona, porque me obliga a configurar un topping por cada variante de producto,
pero quiero cambiar eso, la idea es que los topping se puedan configurar a nivel de producto y
este disponible para todas las variantes, y lo otro es que un topping tambien es un producto,
entonces la idea es que tambien se pueda pedir desde el catalogo de la orden como si fuera una
linea independiente de la orden, pero los toppings no se deben mostrar como un producto en el
menu del qr, pero si se debe estar disponible en el catalogo de la orden manual, por eso sugiero
tambien agregar la opcion de controlar la visibilidad de los productos en el menu qr. Por ahora
los grupos de opciones quedarían únicamente para configurar sabores."

## Decisión de modelado

Tras evaluar tres formas de modelar el problema, se eligió: **una adición (topping) es un
producto normal del catálogo** (con su propio precio, receta de insumos y, si aplica, variantes),
marcado con un indicador de que funciona como adición. La asociación "esta adición está
disponible para ese producto" pasa a vivir a nivel de producto (ya no a nivel de variante), por
lo que configurarla una sola vez la deja disponible para todas las variantes del producto. Los
grupos de opciones (`OptionGroup`/`Option`) dejan de usarse para adiciones y quedan reservados
exclusivamente para sabores; la vinculación de un grupo de sabores a una variante **no cambia**
— sigue a nivel de variante, igual que hoy, porque el mínimo/máximo de sabores a elegir y el
insumo que descuenta cada uno varían intencionalmente según el tamaño de la presentación (ej. la
ensalada pequeña elige 1 sabor y descuenta 60 g; la mediana elige 2 y descuenta 120 g de cada
uno). Esta spec solo resuelve la duplicación por variante para adiciones, no para sabores.

Se descartaron: (a) modelar la adición como una entidad completamente nueva y separada de
`products`, porque obligaría a duplicar catálogo, precio, receta y pantallas de búsqueda que ya
existen para productos; y (b) dejar la adición viviendo solo como una opción dentro de un grupo
y permitir que una opción se convierta en línea de pedido suelta, porque no resolvía el pedido
explícito del usuario de que "un topping también es un producto" con su propio ciclo de vida de
catálogo.

## Clarifications

### Session 2026-10-19

- Q: ¿Cómo modelar que una adición se configure a nivel de producto (no por variante) y además se
  pueda vender como línea independiente en el pedido manual? → A: la adición es un producto
  normal del catálogo marcado como adición; la disponibilidad de una adición para un producto se
  configura a nivel de producto (no de variante).
- Q: Hoy un comensal que pide un producto por el menú QR puede agregarle adiciones eligiéndolas
  del grupo de opciones de esa variante (ej. "+ gomitas" en un granizado). Si las adiciones dejan
  de vivir en grupos de opciones y pasan a ser productos-adición enlazados al producto, ¿el
  comensal del menú QR debe poder seguir agregándolas a su producto al pedirlo? → A: sí, mediante
  un selector de "Adiciones disponibles" al personalizar el producto en el menú QR, poblado con
  las adiciones enlazadas a ese producto. La adición sigue sin aparecer como ítem suelto del menú.
- Q: Cuando una adición se ofrece dentro de otro producto (ej. "Gomitas" en un "Granizado"), ¿su
  precio es siempre el mismo precio de catálogo de la adición, o un producto puede definir un
  recargo distinto al de su precio de catálogo cuando la ofrece como adición? → A: el precio de
  la adición es siempre su precio de catálogo, sin importar a qué producto esté asociada; ningún
  producto puede definir un recargo propio distinto para esa adición.
- Q: Al agregar una adición ya asociada a un producto (en el menú QR o en el pedido manual),
  ¿puede elegirse cuántas unidades agregar a esa línea, o solo puede agregarse o no (una unidad
  fija)? → A: puede elegirse cuántas unidades agregar (cantidad libre), igual que hoy en el modo
  "Por cantidad" de los grupos de opciones (spec 065); esta capacidad no se pierde al migrar.
- Q: Un producto marcado como adición, ¿sigue necesitando pertenecer a una categoría del catálogo
  (igual que cualquier producto), o puede existir sin categoría ya que no se muestra como ítem
  propio en el menú QR? → A: mantiene la regla actual — toda adición pertenece a una categoría,
  igual que cualquier producto (por ejemplo, una categoría dedicada como "Adiciones", que a su vez
  puede ocultarse del menú QR igual que cualquier categoría, spec 128). No se necesita ningún
  cambio en el formulario de creación de producto.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Configurar una adición una sola vez para todas las variantes de un producto (Priority: P1)

Quien administra el catálogo quiere decidir qué adiciones (ej. "gomitas", "crema", "salsa extra")
puede llevar un producto, configurándolo **una sola vez por producto**, sin tener que repetir esa
configuración en cada una de sus variantes/presentaciones.

**Why this priority**: es la queja central que origina esta spec — hoy la configuración se
duplica por variante, lo que hace tedioso y propenso a error mantener el catálogo. Sin esto, el
resto de la funcionalidad (vender la adición suelta, ocultarla del QR) no tiene un punto de
configuración coherente del cual partir.

**Independent Test**: puede probarse por completo creando un producto con dos o más variantes,
asociándole una adición desde la pantalla del producto (no de la variante), y confirmando que esa
adición queda disponible al pedir cualquiera de sus variantes, tanto en el pedido manual como en
el menú QR, sin repetir la configuración.

**Acceptance Scenarios**:

1. **Given** un producto "Granizado" con variantes "Pequeño" y "Grande", **When** el
   administrador asocia la adición "Gomitas" al producto "Granizado" (no a una variante en
   particular), **Then** "Gomitas" aparece disponible como adición al pedir tanto "Pequeño" como
   "Grande", sin que el administrador la haya configurado por separado en cada variante.
2. **Given** un producto con adiciones ya asociadas, **When** el administrador agrega una nueva
   variante a ese producto, **Then** la nueva variante hereda automáticamente todas las
   adiciones ya asociadas al producto, sin configuración adicional.
3. **Given** un administrador en la pantalla de un producto, **When** quita la asociación de una
   adición a ese producto, **Then** esa adición deja de ofrecerse para cualquiera de sus
   variantes, mientras que los pedidos ya existentes que la incluían no se alteran.

---

### User Story 2 - Pedir una adición como línea independiente desde el pedido manual (Priority: P1)

Quien atiende en caja o en mesa quiere poder agregar una adición al pedido como su propia línea
(ej. vender "Gomitas" sueltas, sin que vayan atadas a otro producto), igual que agrega cualquier
otro producto del catálogo.

**Why this priority**: es el segundo pilar explícito de la solicitud — una adición "también es
un producto" y el negocio necesita poder venderla por sí sola. Es independiente de la US1 en el
sentido de que entrega valor por separado (vender adiciones sueltas), aunque depende de que la
adición exista como producto configurado.

**Independent Test**: puede probarse abriendo el catálogo del pedido manual, buscando una
adición por su nombre igual que se busca cualquier producto, agregándola como línea propia con su
propia cantidad, y confirmando que el pedido queda con esa línea cobrada a su propio precio.

**Acceptance Scenarios**:

1. **Given** la adición "Gomitas" existe en el catálogo, **When** quien atiende en caja la busca
   en el catálogo del pedido manual, **Then** "Gomitas" aparece como resultado seleccionable, igual
   que cualquier producto, y puede agregarse como línea independiente del pedido con cantidad
   propia.
2. **Given** una línea de pedido formada por una adición vendida suelta, **When** se cobra el
   pedido, **Then** esa línea se cobra como cualquier línea de producto (precio × cantidad de esa
   línea), sin relación con la cantidad de ninguna otra línea del pedido.
3. **Given** una adición vendida suelta como línea independiente, **When** se consulta el recibo,
   la comanda o el detalle del pedido, **Then** esa línea se identifica igual que cualquier línea
   de producto (nombre, cantidad, precio), sin tratamiento especial que la distinga visualmente
   de un producto cualquiera.

---

### User Story 3 - Las adiciones no aparecen como producto del menú QR, pero sí como opción al personalizar (Priority: P1)

Quien administra el negocio no quiere que una adición (ej. "Gomitas") aparezca en el menú QR como
si fuera un platillo que el comensal puede pedir por sí solo, pero sí quiere que el comensal
pueda seguir agregándola como adición al personalizar un producto que la tenga asociada (ej. "+
Gomitas" al pedir un granizado).

**Why this priority**: protege la experiencia actual del comensal (poder personalizar su pedido
con adiciones) mientras resuelve el riesgo de que, al convertir la adición en un producto más del
catálogo, termine ofreciéndose por error como plato independiente en el menú QR.

**Independent Test**: puede probarse creando una adición, asociándola a un producto, y
confirmando que (a) la adición no aparece listada ni en el buscador del menú QR como ítem propio,
y (b) al personalizar ese producto en el menú QR, la adición sí aparece en el selector de
adiciones disponibles.

**Acceptance Scenarios**:

1. **Given** la adición "Gomitas" está asociada al producto "Granizado", **When** un comensal
   navega o busca en el menú QR, **Then** "Gomitas" no aparece como resultado ni como tarjeta de
   producto independiente.
2. **Given** la adición "Gomitas" está asociada al producto "Granizado", **When** el comensal
   personaliza "Granizado" en el menú QR, **Then** "Gomitas" aparece en el selector de adiciones
   disponibles de ese producto y puede agregarla a su pedido, eligiendo cuántas unidades agregar
   (ej. "2 Gomitas").
3. **Given** una adición recién creada, **When** el administrador la guarda sin tocar nada más,
   **Then** queda oculta del menú QR como ítem propio por defecto, sin que el administrador tenga
   que ocultarla manualmente.

---

### User Story 4 - Controlar la visibilidad de cualquier producto en el menú QR (Priority: P2)

Quien administra el negocio quiere poder ocultar o mostrar, producto por producto, cuáles puede
pedir un comensal por su cuenta desde el menú QR — sin desactivar el producto por completo (lo
que también lo quitaría del catálogo que usa el personal), igual que hoy ya puede hacerlo por
categoría.

**Why this priority**: es el mecanismo general que, aplicado por defecto a las adiciones (US3),
resuelve el pedido del usuario; además da valor por sí solo para cualquier otro producto que el
negocio no quiera ofrecer por QR (ej. un producto en prueba, o de venta exclusiva en mesa).

**Independent Test**: puede probarse ocultando un producto activo (que no sea una adición) desde
la pantalla de administración, recargando el menú QR público y confirmando que el producto ya no
aparece, mientras sigue disponible al armar un pedido manual desde caja o mesa.

**Acceptance Scenarios**:

1. **Given** un producto activo y visible en el menú QR, **When** el administrador acciona
   "Ocultar del menú QR" sobre ese producto, **Then** el producto muestra el indicador "Oculto en
   QR", y al recargar el menú QR el producto ya no aparece, mientras que en "Nuevo pedido" desde
   caja o mesa sigue disponible exactamente igual que antes.
2. **Given** un producto oculto en el menú QR, **When** el administrador acciona "Mostrar en menú
   QR", **Then** el producto vuelve a aparecer en el menú QR, en la misma posición que ya tenía
   según el orden de su categoría.
3. **Given** un producto pertenece a una categoría oculta en el menú QR (spec 128), **When** el
   administrador muestra ese producto individualmente en el menú QR, **Then** el producto sigue
   sin aparecer mientras su categoría permanezca oculta — la visibilidad de categoría manda sobre
   la de producto.
4. **Given** un usuario con rol Cajero está en la pantalla de un producto, **Then** no ve la
   acción de visibilidad en QR, y si llama directamente al mecanismo que la cambia, recibe un
   error de permiso denegado.

---

### Edge Cases

- ¿Qué pasa si un comensal tiene en su carrito del menú QR una adición agregada a un producto, y
  mientras tanto el administrador desasocia esa adición del producto? El sistema debe rechazar la
  adición al enviar el pedido y avisar al comensal, sin bloquear el resto del pedido — mismo
  patrón ya usado para categorías ocultas en QR (spec 128, US2).
- ¿Qué pasa con los pedidos y ventas ya confirmados que incluyen adiciones configuradas con el
  mecanismo anterior (grupo de opciones por variante)? No se alteran ni se reescriben; conservan
  exactamente la configuración y el precio con el que se cobraron.
- ¿Qué pasa si se intenta marcar como "adición" un producto que ya tiene grupos de opciones de
  sabor configurados? Ambas configuraciones pueden coexistir — una adición puede tener sus propias
  variantes y sabores, igual que cualquier producto.
- ¿Qué pasa si se intenta asociar una adición a sí misma como su propia adición disponible (ciclo
  directo)? El sistema debe rechazar esa asociación.
- ¿Qué pasa si una adición se desactiva (no solo se desasocia de un producto, sino que se marca
  inactiva en el catálogo)? Deja de ofrecerse en todos los productos a los que estaba asociada y
  deja de poder venderse como línea suelta, igual que cualquier producto inactivo.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST permitir marcar un producto del catálogo como "adición", distinto de
  un producto regular, conservando todas las capacidades normales de un producto (precio, receta
  de insumos, variantes, estado activo/inactivo, pertenencia a una categoría).
- **FR-002**: El sistema MUST permitir asociar una o varias adiciones a un producto a nivel del
  producto (no de una variante específica), de forma que esa asociación aplique automáticamente a
  todas las variantes existentes y futuras de ese producto.
- **FR-003**: El sistema MUST dejar de requerir que una adición se configure por separado para
  cada variante de un producto.
- **FR-004**: Los grupos de opciones (`OptionGroup`/`Option`) MUST quedar reservados
  exclusivamente para configurar sabores; el sistema no debe ofrecer la creación de nuevas
  adiciones a través de ese mecanismo.
- **FR-005**: El sistema MUST mantener la asociación de un grupo de opciones (sabores) a nivel de
  variante, sin cambios respecto a hoy, para conservar el mínimo/máximo de sabores y el consumo
  de insumo propios de cada tamaño de presentación.
- **FR-006**: El sistema MUST permitir agregar una adición al catálogo del pedido manual como una
  línea de pedido independiente, con su propia cantidad, buscable y seleccionable igual que
  cualquier producto del catálogo.
- **FR-007**: Una línea de pedido formada por una adición vendida como línea independiente MUST
  cobrarse como cualquier línea de producto (precio unitario × cantidad de esa línea), sin
  relación con la cantidad de ninguna otra línea del pedido.
- **FR-008**: El sistema MUST excluir las adiciones de los listados, búsquedas y resultados del
  menú QR como ítems de producto independientes — un comensal nunca debe poder pedir una adición
  por sí sola desde el menú QR.
- **FR-009**: El sistema MUST permitir que, al personalizar en el menú QR un producto que tiene
  adiciones asociadas, el comensal elija agregar esas adiciones a su línea de producto, igual que
  hoy puede elegir opciones de un grupo.
- **FR-010**: El sistema MUST ocultar por defecto del menú QR, como ítem de producto
  independiente, a todo producto marcado como adición, sin requerir una acción manual adicional
  del administrador (FR-008 aplica automáticamente al crearla).
- **FR-011**: El sistema MUST permitir controlar, producto por producto, su visibilidad como ítem
  independiente en el menú QR (mostrar/ocultar), de forma análoga al control ya existente por
  categoría (spec 128), sin afectar su disponibilidad en el catálogo del pedido manual.
- **FR-012**: Cuando la categoría de un producto está oculta en el menú QR, el sistema MUST
  mantener oculto a ese producto en el menú QR sin importar su visibilidad individual (la
  visibilidad de categoría manda sobre la de producto, igual que hoy).
- **FR-013**: Solo roles con permiso administrativo sobre el catálogo MUST poder cambiar la
  visibilidad en QR de un producto o crear/asociar una adición; el sistema MUST rechazar el intento
  de un rol sin ese permiso.
- **FR-014**: El sistema MUST rechazar, al momento de enviar un pedido desde el menú QR, cualquier
  adición que ya no esté asociada al producto al que el comensal la agregó, informando al comensal
  y sin bloquear el resto del pedido (mismo patrón que spec 128, US2).
- **FR-015**: El sistema MUST conservar sin alteración los pedidos y ventas ya confirmados que
  incluyan adiciones configuradas con el mecanismo anterior (grupo de opciones por variante); esta
  spec no reescribe historial.
- **FR-016**: El sistema MUST rechazar que una adición se asocie a sí misma como una de sus propias
  adiciones disponibles.
- **FR-017**: El precio de una adición MUST ser siempre su precio de catálogo, sin importar a qué
  producto esté asociada ni si se vende como línea independiente o como adición de otro producto;
  ningún producto puede definir un recargo propio distinto para la misma adición.
- **FR-018**: Al agregar una adición ya asociada a un producto, el comensal (en el menú QR) y
  quien atiende (en el pedido manual) MUST poder elegir cuántas unidades de esa adición agregar a
  esa línea (cantidad libre), preservando la capacidad que hoy ofrece el modo "Por cantidad" de
  los grupos de opciones (spec 065) — no se trata solo de agregarla o no agregarla.

### Key Entities *(include if feature involves data)*

- **Producto marcado como adición**: un producto del catálogo (con su propio precio, receta de
  insumos y, opcionalmente, variantes) que además funciona como adición ofrecible dentro de otros
  productos. No es una entidad nueva — es un producto con un indicador adicional.
- **Asociación producto–adición**: relación a nivel de producto (no de variante) que declara qué
  adiciones puede ofrecer un producto. Reemplaza, para adiciones, al enlace que hoy existe entre
  variante y grupo de opciones. Solo declara la relación (qué adición está disponible para qué
  producto); no guarda un precio propio — el precio siempre es el de catálogo de la adición
  (FR-017).
- **Asociación variante–grupo de opciones (sabores)**: sin cambios respecto a hoy — sigue siendo
  el enlace existente entre una variante y el grupo de opciones (sabores) que ofrece, con su
  propio mínimo/máximo de selección y consumo de insumo por variante.
- **Visibilidad en menú QR (producto)**: indicador por producto, independiente del estado
  activo/inactivo, que determina si aparece como ítem propio en el menú QR. Por defecto es visible
  para un producto regular y oculto para un producto marcado como adición.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Configurar una adición para un producto con múltiples variantes toma una sola
  acción de configuración (no una por variante).
- **SC-002**: El 100% de las adiciones del catálogo pueden agregarse a un pedido manual como línea
  independiente, con su propio precio y cantidad.
- **SC-003**: El 0% de las adiciones aparece como resultado o tarjeta de producto independiente al
  buscar o navegar en el menú QR.
- **SC-004**: El 100% de los productos que tenían adiciones asociadas antes de este cambio siguen
  ofreciendo esas adiciones al personalizarse en el menú QR, sin intervención del comensal.
- **SC-005**: El administrador puede cambiar la visibilidad en QR de cualquier producto en menos
  de dos acciones, y el cambio se refleja en el menú QR público sin necesidad de otros ajustes.

## Assumptions

- Dado que hoy no existe una forma confiable de distinguir automáticamente, entre los grupos de
  opciones existentes, cuáles representan adiciones y cuáles representan sabores, esta spec no
  asume una migración automática de datos: el negocio deberá recrear manualmente, como productos-
  adición asociados a cada producto, las adiciones que hoy tiene configuradas vía grupos de
  opciones. El detalle de esa transición (incluida cualquier ayuda de migración que se decida
  construir) se define en la fase de planificación técnica, no en esta spec.
- Cuando una adición se ofrece como adición de otro producto (no como línea suelta), el cálculo de
  su precio sigue la regla ya vigente para adiciones en modo "Por cantidad" (spec 117): el total
  de la adición no se multiplica por la cantidad del producto principal de la línea. Esta spec no
  reabre esa fórmula.
- Una adición puede tener sus propias variantes y su propia receta de insumos, igual que cualquier
  producto; esta spec no restringe esa capacidad.
- El indicador de visibilidad en QR de un producto es independiente del estado activo/inactivo del
  producto (mismo criterio que ya aplica a categorías en spec 128).
- Esta spec no cubre la posibilidad de que una adición, a su vez, tenga sus propias adiciones
  asociadas (adición de una adición); de ser necesario, se abordará en una spec futura.
