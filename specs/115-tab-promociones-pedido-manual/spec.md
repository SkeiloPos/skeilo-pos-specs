# Feature Specification: Pestaña dedicada de Promociones en el catálogo de la orden manual

**Feature Branch**: `115-tab-promociones-pedido-manual`

**Created**: 2026-10-12

**Status**: Draft

**Input**: User description: "con la implementacion actual para crear pedidos manual, los productos con promociones aparecen mesclados con el catalogo general, quisiera que incluyeras una categoria para mostrar unicamente los productos en promocion y siguieras las mismas reglas que aplican hoy en dia la forma de agregar esos productos al carrito en el menu qr a la orden manual, si tienes alguna duda me precuntas"

## Clarifications

### Session 2026-10-12

- Q: En el menú QR, la pestaña "Promociones" se selecciona automáticamente al entrar si hay promociones vigentes. En la orden manual, ¿quieres ese mismo comportamiento automático, o que el personal siga viendo "Todos" por defecto y entre a "Promociones" solo cuando la seleccione? → A: Mantener "Todos" seleccionado por defecto, igual que hoy; el personal entra a "Promociones" únicamente cuando la selecciona. No se replica la autoselección del menú QR, porque el personal ya conoce el catálogo y suele buscar productos específicos, a diferencia del comensal al que se busca orientar.
- Q: El catálogo de la orden manual tiene un buscador de productos ("Buscar producto, sabor o código"). Si el personal encuentra ahí un producto en promoción sin pasar por la pestaña "Promociones", ¿debe agregarse en pasos de la cantidad mínima de la regla (igual que desde "Promociones"), o de una unidad a la vez (igual que desde una categoría normal)? → A: Una unidad a la vez. Igual que en el menú QR, el incremento forzado por cantidad mínima es exclusivo de la pestaña "Promociones"; encontrar el producto por el buscador (o por su categoría normal) sigue agregando de a una unidad, sin pasos forzados.
- Q: El catálogo de "+ Agregar producto" a un pedido ya existente es una pantalla distinta del catálogo de "crear pedido nuevo" — ¿la pestaña "Promociones" y el paso de cantidad deben replicarse ahí también? → A: Sí, ampliar el alcance para que ambas pantallas se comporten idénticamente; es la misma necesidad de negocio (encontrar y agregar promociones correctamente) sin importar si el pedido es nuevo o ya existe.
- Q: Al probar la pestaña "Promociones", una línea con promoción de precio de paquete ("2 x $15.000") no mostraba ninguna insignia en el carrito y el resumen del pedido mostraba una fila "Descuento" genérica sin explicación — ¿qué debe mostrarse ahí? → A: Ocultar la fila "Descuento" del resumen de la orden en borrador; mantener "Subtotal" tal como está hoy. El "TOTAL ORDEN" sigue reflejando el descuento ya resuelto por el backend, sin cambio de cálculo — solo cambia qué fila se muestra. Además, la línea del producto en el carrito debe mostrar la misma insignia/tachado/"Ahorras $X" que ya muestra el modal de selección, también para promociones de paquete (`min_qty > 1`), no solo para descuentos simples. Registrado como decisión de negocio A-125 en `specs/000-reconocimiento/registro-de-anomalias.md` (modifica un comportamiento introducido por la spec 073; ambas partes — ocultar "Descuento" y arreglar la insignia por línea — quedaron implementadas en la misma sesión).
- Q: El control +/- de una línea ya agregada al pedido avanzaba en pasos de la cantidad mínima de su promoción (igual que en el menú QR) — al revisarlo en un entorno real, ¿debe seguir así? → A: No. Ese control debe avanzar siempre de una unidad en una, sin importar si la línea tiene promoción vigente o cuál sea su cantidad mínima — el personal necesita control manual total sobre la cantidad ya puesta en el pedido, a diferencia del comensal del menú QR, a quien sí conviene seguir orientando/protegiendo de un error de cantidad ahí. El primer agregado desde "Promociones" sigue entrando directamente con la cantidad mínima de la regla (eso no cambia). Registrado como decisión de negocio A-126 en `specs/000-reconocimiento/registro-de-anomalias.md` — revierte parcialmente FR-004/FR-006 tal como se habían especificado inicialmente.
- Q: Tras ocultar la fila "Descuento" (A-125), "Subtotal" seguía mostrando el importe bruto ($16.000) mientras la línea del producto y "TOTAL ORDEN" ya mostraban el importe con descuento ($15.000) — dos cifras distintas para la misma mercancía. ¿Debe "Subtotal" mostrarse también neto? → A: Sí. "Subtotal" debe reflejar el mismo importe con descuento que ya muestra la línea del producto y "TOTAL ORDEN" — sin descuento de domicilio todavía, pero ya neto de la promoción. Registrado como decisión de negocio A-127 en `specs/000-reconocimiento/registro-de-anomalias.md`.
- Q: Un ítem ya persistido en un pedido pero aún "Pendiente" (sin cobrar) seguía mostrándose a precio de lista completo, sin ninguna insignia, aunque su variante tuviera una promoción de paquete vigente en el catálogo — ¿debe mostrar el mismo tratamiento que ya tiene una línea de borrador? → A: Sí. Mientras el backend no congele el descuento real (recién al cobrar), la línea "Pendiente" debe estimar la misma insignia/tachado/"Ahorras $X" con la promoción vigente del catálogo, igual que ya hace la línea de borrador. Registrado como decisión de negocio A-128 en `specs/000-reconocimiento/registro-de-anomalias.md`.
- Q: La insignia resultante (esquema rojo, "2 x $15.000 Promoción", con una píldora verde aparte "Ahorras $X") no coincidía con el formato que ya muestra el modal de selección de producto para la misma promoción — ¿cuál debe prevalecer? → A: El panel del pedido debe reproducir el mismo formato del modal: insignia indigo con solo la condición (sin la palabra "Promoción"), precio tachado y precio con descuento juntos en la misma línea, sin ninguna píldora "Ahorras" aparte. Registrado como decisión de negocio A-129 en `specs/000-reconocimiento/registro-de-anomalias.md`.
- Q: El subtítulo "{{ qty }} × $precio" de esa misma línea seguía mostrando el precio de lista (2 × $8.000 = $16.000), que no cuadraba con el importe neto mostrado arriba ($15.000) — ¿debe corregirse? → A: Sí, debe mostrar el precio neto por unidad (2 × $7.500), para que cuadre con el importe con descuento de la misma línea. Registrado como decisión de negocio A-130. Además, el panel de cobro (pantalla de "Facturar a nombre de", antes de "Cobrar") tenía el mismo problema de la fila "Descuento"/Subtotal bruto que A-125/A-127 ya habían corregido en el resumen de la orden en borrador — se aplica la misma corrección ahí, registrada como A-131.
- Q: "Cuenta de la mesa" ("Ya pagado") tenía el mismo problema de la fila "Descuento"/Subtotal bruto — ¿se corrige igual? → A: Sí, mismo tratamiento, y de paso en el otro resumen de la misma pantalla ("Total a cobrar"/"Subtotal mesa"), por estar en el mismo archivo y pantalla — dejarlos inconsistentes entre sí habría sido peor. Registrado como decisión de negocio A-132. No se tocan otras pantallas no mostradas (`payment-attempt-review-panel`, `orders/pages/order-detail.component.ts`, esta última con su propia decisión ya establecida, A-106/spec 094).
- Q: Con una cantidad que no completa un paquete exacto (ajustada libremente desde A-126), A-130 mostraba un precio por unidad promediado ("3 × $7.667") que no corresponde a ningún precio real cobrado — ¿se corrige el cálculo o se quita? → A: Se quita por completo con promoción (no se muestra ningún "{{ qty }} × ..." en ese caso); sin promoción sigue mostrándose igual que siempre. Revierte A-130. Registrado como decisión de negocio A-133.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Encontrar todos los productos en promoción sin revisar categoría por categoría (Priority: P1)

Un cajero o mesero está creando o editando un pedido manual y quiere ver rápidamente qué productos tienen una promoción vigente en este momento, sin tener que revisar el catálogo categoría por categoría buscando la insignia de promoción en cada tarjeta.

**Why this priority**: Es el problema reportado: hoy los productos en promoción aparecen mezclados con el resto del catálogo en la orden manual, obligando al personal a revisarlos uno por uno. Sin esta vista, el resto de la funcionalidad (agregar respetando las reglas) no tiene un lugar propio donde aplicarse de forma consistente.

**Independent Test**: Puede probarse abriendo el catálogo de la orden manual con al menos una promoción vigente sobre productos de distintas categorías, seleccionando la nueva opción "Promociones" en la navegación del catálogo, y verificando que se listan únicamente los productos con al menos una variante cubierta por una promoción vigente, sin importar su categoría original.

**Acceptance Scenarios**:

1. **Given** el catálogo de la orden manual tiene productos en varias categorías y solo algunos de ellos tienen una promoción vigente, **When** el personal selecciona la opción "Promociones" en la navegación del catálogo, **Then** el listado muestra únicamente esos productos, independientemente de su categoría.
2. **Given** el personal está viendo la pestaña "Promociones", **When** revisa cualquiera de las tarjetas listadas, **Then** puede ver la condición de la promoción (tipo de descuento y cantidad mínima) igual que la vería en la tarjeta del producto dentro de su categoría original.
3. **Given** ninguna promoción está vigente en este momento, **When** el personal selecciona "Promociones", **Then** el sistema le indica claramente que no hay promociones activas, en lugar de mostrar una lista vacía sin explicación.
4. **Given** el personal abre el catálogo de la orden manual (sin haber seleccionado "Promociones" todavía), **When** la pantalla carga, **Then** se mantiene seleccionada la pestaña "Todos" (o la categoría que ya estuviera activa), igual que el comportamiento actual, sin autoseleccionar "Promociones" aunque haya promociones vigentes.

---

### User Story 2 - Agregar al pedido respetando las unidades mínimas de la promoción (Priority: P1)

El personal encuentra un producto en la pestaña "Promociones" con una regla de "precio de paquete" (por ejemplo, "2 x $17.000") y quiere agregarlo al pedido sin tener que calcular manualmente cuántas unidades necesita para que el descuento aplique. Una vez en el pedido, el personal debe poder ajustar la cantidad libremente, de una unidad en una, igual que cualquier otra línea.

**Why this priority**: Es la segunda parte explícita de la solicitud: que el primer agregado desde "Promociones" ya entre con la cantidad correcta para que el descuento aplique, sin que el personal tenga que calcularla. Resolverlo es tan crítico como poder encontrar el producto (User Story 1); de lo contrario, encontrar el producto en su propia pestaña no evita que el personal agregue una cantidad que no alcanza el mínimo. El control manual de la cantidad una vez agregada (A-126) es intencionalmente distinto al menú QR: el personal necesita ajustarla libremente, no quedar atado a saltos de a varias unidades.

**Independent Test**: Puede probarse agregando, desde la pestaña "Promociones" del catálogo de la orden manual, un producto cuya única variante elegible está cubierta por una regla de precio de paquete con cantidad mínima 2, y verificando que la línea del pedido queda en cantidad 2 (no en 1); y que, una vez en el pedido, el control +/- de esa línea avanza de una unidad en una.

**Acceptance Scenarios**:

1. **Given** un producto en la pestaña "Promociones" tiene una regla de precio de paquete "2 x $17.000" sobre su única variante, **When** el personal lo agrega al pedido por primera vez, **Then** la línea del pedido queda con cantidad 2, no con cantidad 1.
2. **Given** ese mismo producto ya está en el pedido con cantidad 2, **When** el personal presiona el control para aumentar la cantidad, **Then** la cantidad pasa a 3 (una unidad más), igual que cualquier otra línea del pedido (A-126).
3. **Given** ese mismo producto está en el pedido con cantidad 2, **When** el personal presiona el control para disminuir la cantidad, **Then** la cantidad pasa a 1 — no se retira del pedido ni salta a 0 (A-126); esa unidad simplemente deja de calificar para el precio de paquete, lo que el backend resuelve igual que ya resuelve cualquier cantidad que no complete el mínimo.
4. **Given** ese mismo producto está en el pedido con cantidad 1, **When** el personal presiona una vez más el control para disminuir la cantidad, **Then** la línea se retira por completo del pedido (al llegar a 0), igual que cualquier otra línea.
5. **Given** un producto en la pestaña "Promociones" tiene una regla vigente con cantidad mínima 1 (de cualquier tipo), **When** el personal lo agrega al pedido, **Then** se agrega una unidad a la vez, igual que el comportamiento actual, porque una sola unidad ya cumple el mínimo.

---

### User Story 3 - Las categorías normales del catálogo no cambian su comportamiento (Priority: P2)

El personal que navega el catálogo de la orden manual por categoría (como hace hoy) y agrega un producto que también tiene una promoción, sin haber pasado por la pestaña "Promociones", espera que agregarlo funcione exactamente igual que hoy.

**Why this priority**: Protege el comportamiento existente en el resto del catálogo mientras se introduce la nueva pestaña, evitando que la nueva regla de cantidad se filtre a flujos que el personal ya conoce y que no fueron parte de la solicitud.

**Independent Test**: Puede probarse agregando al pedido, desde la categoría original de un producto (no desde "Promociones"), un producto con una regla de precio de paquete de cantidad mínima 2, y verificando que se agrega de a una unidad como hoy.

**Acceptance Scenarios**:

1. **Given** un producto con una regla de precio de paquete de cantidad mínima 2 está visible en su categoría original, **When** el personal lo agrega al pedido desde esa categoría (no desde "Promociones"), **Then** se agrega una unidad, igual que el comportamiento actual del catálogo de la orden manual.

---

### Edge Cases

- ¿Qué pasa si una promoción deja de estar vigente (por vencimiento de fecha, horario o cambio de estado) mientras el personal tiene la pestaña "Promociones" abierta o productos de esa promoción ya agregados al pedido en curso? El sistema sigue las mismas reglas de vigencia y recálculo ya existentes para el resto del catálogo y del pedido; esta funcionalidad no introduce una regla de vigencia distinta.
- ¿Qué pasa si un producto tiene varias variantes y solo algunas están cubiertas por una regla vigente? El producto aparece en "Promociones", y el incremento por cantidad mínima aplica únicamente a la variante (y opciones, si el producto las requiere) que efectivamente está cubierta por la regla; otras variantes del mismo producto se agregan de forma normal.
- ¿Qué pasa si el personal ya tenía el producto en el pedido con una cantidad que no es múltiplo de la cantidad mínima (por haberlo agregado antes desde su categoría) y luego interactúa con ese mismo producto desde la pestaña "Promociones"? El control de cantidad en la vista "Promociones" ajusta la cantidad al múltiplo de la cantidad mínima más cercano hacia arriba antes de seguir incrementando o decrementando en pasos de esa cantidad mínima.
- ¿Qué pasa si la regla vigente que cubre un producto también cubre otros productos o variantes distintas combinables entre sí (por ejemplo, "2 entre Mediana y Pequeña")? Dentro de la pestaña "Promociones", el incremento por cantidad mínima se aplica sumando únicamente unidades del mismo producto en esa tarjeta; combinar productos distintos del mismo grupo para completar el mínimo queda fuera del alcance de esta pestaña y sigue disponible agregando cada producto desde su categoría original, sin cambio de comportamiento ahí.
- ¿Qué pasa si el personal encuentra un producto en promoción a través del buscador del catálogo, sin pasar por la pestaña "Promociones"? Se agrega de a una unidad, igual que desde una categoría normal; el incremento forzado por cantidad mínima (FR-004) es exclusivo de la pestaña "Promociones" y no se activa por haber encontrado el producto mediante el buscador.
- ¿Qué pasa si el personal usa la pestaña "Promociones" para agregar productos a un pedido que ya fue creado (no solo al borrador de uno nuevo)? Aplican exactamente las mismas reglas de esta especificación (filtro, paso de cantidad, estado vacío, pestaña no autoseleccionada), sin importar el tipo de pedido (mesa, para llevar o domicilio) ni que la pantalla de "+ Agregar producto" sea distinta a la de crear un pedido nuevo.
- ¿Qué pasa si no hay promociones vigentes cuando el personal abre el catálogo? La pestaña "Promociones" sigue visible en la navegación, pero indica explícitamente que no hay promociones activas en este momento; la pestaña seleccionada por defecto sigue siendo "Todos" (o la categoría ya activa), sin cambio.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El catálogo de productos de la orden manual MUST incluir una nueva opción "Promociones" en su navegación, junto a "Todos" y las categorías existentes.
- **FR-002**: Al seleccionar "Promociones", el sistema MUST mostrar únicamente los productos que tengan al menos una variante cubierta por una regla de promoción vigente en ese momento, sin importar a qué categoría pertenezcan.
- **FR-003**: Las tarjetas de producto mostradas en "Promociones" MUST conservar la misma información de condición de la promoción (tipo de descuento y cantidad mínima) que ya se muestra hoy en la tarjeta del producto dentro de su categoría original.
- **FR-004**: Cuando el personal agrega AL PEDIDO POR PRIMERA VEZ un producto desde la pestaña "Promociones" cuya variante elegible está cubierta por una regla vigente con cantidad mínima mayor a 1, el sistema MUST agregarlo directamente con una cantidad igual a esa cantidad mínima (por ejemplo, 2 unidades para una regla "2 x $17.000"), no con 1 unidad, sin importar si la regla es de tipo porcentaje o precio de paquete.
- **FR-005**: Cuando la regla vigente que cubre la variante tiene cantidad mínima igual a 1, el sistema MUST agregar el producto de a una unidad, igual que el comportamiento actual.
- **FR-006**: Una vez que un producto ya está en el pedido (sin importar desde dónde se agregó ni si tiene una promoción vigente), el control de cantidad (+/-) de esa línea MUST incrementar o decrementar siempre de una unidad en una, retirando la línea del pedido por completo únicamente cuando la cantidad llega a 0 — igual que cualquier otra línea. A diferencia del menú QR (donde ese mismo control sí sigue el paso de la regla), el personal de la orden manual necesita control manual total sobre la cantidad ya puesta en el pedido (decisión de negocio A-126).
- **FR-007**: Navegar por una categoría existente o "Todos" (fuera de "Promociones") MUST seguir mostrando los productos correspondientes sin filtrar por si tienen o no promoción vigente, igual que hoy.
- **FR-008**: Agregar al pedido un producto desde una categoría existente, "Todos", o desde el buscador del catálogo (cualquier punto de entrada distinto de la pestaña "Promociones") MUST conservar el comportamiento actual de cantidad libre, unidad por unidad, sin el incremento por cantidad mínima definido en FR-004.
- **FR-009**: Cuando un producto tiene varias variantes y solo algunas están cubiertas por una regla vigente, el incremento por cantidad mínima (FR-004) MUST aplicar únicamente a la combinación de variante (y opciones, si aplica) efectivamente cubierta por esa regla.
- **FR-010**: Si la cantidad ya presente en el pedido para un producto no es múltiplo de la cantidad mínima de su regla vigente (por haberse agregado antes desde una categoría normal o "Todos"), el control de cantidad en la vista "Promociones" MUST ajustarla al múltiplo de la cantidad mínima más cercano hacia arriba antes de seguir incrementando o decrementando en esos pasos.
- **FR-011**: Cuando la regla vigente que cubre un producto también cubre otros productos o variantes distintas combinables entre sí, el incremento por cantidad mínima definido en FR-004 MUST aplicarse sumando únicamente unidades del mismo producto en esa tarjeta; el sistema MUST NOT forzar ni bloquear la combinación de productos distintos del mismo grupo para completar el mínimo dentro de la pestaña "Promociones" — esa combinación sigue disponible agregando cada producto desde su categoría original.
- **FR-012**: Cuando ninguna promoción está vigente al momento en que el personal selecciona la pestaña "Promociones", el sistema MUST mostrarla igualmente en la navegación, pero indicando que no hay promociones activas en este momento, en lugar de una lista vacía sin explicación.
- **FR-013**: Al abrir el catálogo de la orden manual, el sistema MUST mantener seleccionada la pestaña "Todos" (o la categoría que ya estuviera activa) por defecto, sin autoseleccionar "Promociones" aunque existan promociones vigentes; el personal selecciona "Promociones" manualmente cuando lo necesite.
- **FR-014**: Las reglas de FR-001 a FR-013 MUST aplicar por igual en los dos puntos donde el personal agrega productos a un pedido manual: el catálogo usado para **crear un pedido nuevo** y el catálogo usado para **agregar productos a un pedido ya existente** (el panel "+ Agregar producto" de una mesa, un pedido para llevar o un domicilio ya creado) — aunque sean dos pantallas distintas, deben comportarse de forma idéntica frente a "Promociones".

### Key Entities

- **Producto en promoción**: producto del catálogo que tiene al menos una variante cubierta por una regla de promoción vigente (según el estado, fechas, días y horario ya definidos para las promociones existentes); es el criterio que determina qué aparece en la pestaña "Promociones" tanto en el menú QR como en la orden manual.
- **Pestaña "Promociones" (orden manual)**: nueva opción de navegación del catálogo de la orden manual que filtra los productos mostrados a únicamente los que están en promoción, en lugar de agruparlos por categoría o mostrar el catálogo completo.
- **Cantidad mínima de la regla**: valor ya existente en cada regla de promoción (definido en la administración de promociones) que esta funcionalidad usa como el paso de incremento/decremento al agregar el producto desde la pestaña "Promociones", igual que ya ocurre en el menú QR.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El personal puede ver todos los productos con promoción vigente del catálogo de la orden manual con una sola selección en la navegación, sin necesidad de revisar cada categoría.
- **SC-002**: El 100% de las líneas del pedido creadas desde la pestaña "Promociones" para reglas con cantidad mínima mayor a 1 quedan, **al momento de agregarse por primera vez**, en una cantidad que es múltiplo exacto de esa cantidad mínima. (Después de ese momento, el personal puede ajustarla libremente de una unidad en una — A-126 — así que la cantidad puede dejar de ser múltiplo más adelante, intencionalmente.)
- **SC-003**: El comportamiento de agregar productos desde categorías existentes o "Todos" (fuera de "Promociones") no presenta ninguna regresión frente al existente antes de esta funcionalidad.
- **SC-004**: El filtro de la pestaña "Promociones" y la cantidad con la que se agrega un producto por primera vez son idénticos, caso por caso, a las reglas ya validadas en la pestaña "Promociones" del menú QR. El control +/- de una línea ya agregada es la única divergencia intencional entre ambos canales (A-126): en la orden manual siempre avanza de una unidad en una; en el menú QR sigue avanzando en pasos de la cantidad mínima.

## Assumptions

- Se reutiliza sin cambios el criterio y la información de vigencia, tipo de regla y cantidad mínima ya definidos por el modelo de promociones existente; esta funcionalidad no modifica el motor de cálculo de descuentos, solo agrega una vista de navegación filtrada y una regla de cantidad al agregar por primera vez desde esa vista.
- A diferencia del menú QR, el control +/- de una línea ya agregada al pedido NO replica el paso de la cantidad mínima de la promoción — siempre avanza de una unidad en una, incluso si esa línea está en promoción (decisión de negocio A-126, ver Clarifications). Solo el primer agregado desde "Promociones" entra con la cantidad mínima de la regla.
- A diferencia del menú QR, la pestaña "Promociones" de la orden manual no se selecciona automáticamente por defecto (ver Clarifications); el personal siempre debe seleccionarla de forma explícita, dado que ya conoce el catálogo y normalmente busca productos puntuales en lugar de requerir que se le oriente hacia las promociones.
- El cálculo final del descuento al cobrar el pedido sigue siendo resuelto de forma autoritativa por el sistema al momento del cobro, igual que hoy; esta funcionalidad solo determina qué se muestra en el catálogo y en qué pasos de cantidad se agrega, no cómo se calcula el descuento final.
- La pestaña "Promociones" se ubica junto a "Todos" y las categorías existentes en la navegación del catálogo de la orden manual (no las reemplaza), y permanece visible aunque no haya promociones vigentes en el momento (FR-012).
- Si un producto requiere selección de variante u opciones antes de agregarse (como ya ocurre hoy), esa selección ocurre igual desde la pestaña "Promociones"; el incremento por cantidad mínima se aplica después de esa selección, sobre la combinación específica cubierta por la regla vigente.
- No está en el alcance de esta funcionalidad: cambiar cómo se crean o administran las promociones, ni el motor que calcula los descuentos (ya cubiertos por especificaciones anteriores); tampoco cambiar el orden o diseño visual de las tarjetas de producto, más allá de mostrarlas dentro de esta nueva vista filtrada.
- Cuando una regla vigente cubre varios productos o variantes combinables entre sí, esta funcionalidad no ofrece dentro de la pestaña "Promociones" una forma de combinarlos para completar la cantidad mínima compartida; esa combinación sigue funcionando como hoy, agregando cada producto desde su categoría original (FR-011).
