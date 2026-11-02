# Feature Specification: Disponibilidad de productos en tiempo real (agotado ↔ disponible)

**Feature Branch**: `148-disponibilidad-productos-tiempo-real`

**Created**: 2026-11-02

**Status**: Draft

**Input**: User description: "Implementar sincronización en tiempo real para la disponibilidad de productos (agotado ↔ disponible) tanto en el menú QR como en las interfaces de orden manual (Terminal de Mesas, caja, domicilios). El objetivo es permitir que los comensales y meseros detecten al instante los cambios de stock sin necesidad de recargar la página, preservando el contenido del carrito de compras y evitando retrasos operativos en horas pico. Reglas: propagación multicanal (RN-1), backend como fuente de verdad (RN-2), preservación del carrito ante agotamiento (RN-3), aislamiento absoluto entre tenants (RN-4) y agotamiento automático por inventario con el mismo evento que el marcado manual (RN-5). Seis escenarios de aceptación: reflejo del agotado sin recargar, reflejo del regreso a disponible, agotamiento de un producto presente en el carrito, condición de carrera con 409 Conflict, pérdida y recuperación de la conexión en vivo, y aislamiento de eventos entre tenants."

## Clarifications

### Session 2026-11-02

- Q: ¿Cómo debe funcionar el agotamiento por inventario (RN-5), dado que el «Agotado» manual es una marca persistida (spec 093, FR-012: «sin dependencia de inventario») y el agotado por stock hoy se calcula en vivo? → A: **Estado derivado**. Cuando un movimiento de inventario deja un producto u opción sin poder pedirse (o lo repone), se emite la misma notificación en tiempo real que el marcado manual. La marca manual no se toca y 093 FR-012 se mantiene.
- Q: ¿Qué superficies entran en el alcance? → A: Las cuatro: el **menú QR** del comensal, la **Terminal de nueva orden** (mesa, para llevar, domicilio y la página de orden manual), el **catálogo para agregar ítems a una orden existente** y la **Carta del menú** de Cajero/Administrador.
- Q: ¿El comensal del menú QR recibe el mismo tratamiento de carrito que la mesera (línea resaltada «Agotado», opción de quitarla y envío bloqueado)? → A: **Sí, mismo comportamiento en ambos canales.** La línea afectada vuelve a la normalidad por sí sola si el producto vuelve a estar disponible.
- Q: ¿El rechazo 409 con la lista de agotados (ID y nombre) cubre solo el agotado manual o también el agotado por inventario? → A: **Ambas causas unificadas.** Cualquier producto no pedible, ya sea por marca manual o por falta de insumos, sale en un único 409 con la lista de productos afectados.
- Q: Cuando un movimiento de inventario deja sin existencias solo una presentación (p. ej. «16 oz») o una opción (p. ej. el sabor «mora») de un producto que sigue teniendo otras disponibles, ¿el aviso en vivo y la marca del carrito llegan hasta ese nivel? → A: **Sí, nivel completo.** El aviso identifica producto, presentación u opción: el producto sigue pedible, ese elemento aparece «Agotado» y solo se marca la línea del carrito que lo usa. La marca manual de la spec 093 sigue siendo solo por producto.
- Q: Si un producto del carrito se agota mientras el comensal del menú QR está en los pasos de pago (método, efectivo o transferencia), ¿qué debe ver y qué puede hacer ahí? → A: **Se queda en el paso de pago sin perder lo ya llenado.** La línea afectada se marca «Agotado» en el resumen del pedido de esos pasos, aparece la alerta, «Confirmar pedido» queda bloqueado y se ofrece un botón «Volver al carrito» para quitarla. El sistema no lo mueve de paso por su cuenta.
- Q: Cuando el comensal quita la línea agotada estando en el paso de pago y el total baja, ¿qué pasa con el comprobante que ya subió y con el monto en efectivo de un pago mixto? → A: **Se conservan el método y el comprobante.** Se avisa del nuevo total («El total cambió a $X»); solo si en un pago mixto el efectivo deja de ser menor al nuevo total se le pide corregir ese monto (lo que invalida el comprobante por la regla vigente de la spec 130). El cajero compara comprobante y total al revisar el pago, como hoy.
- Q: Cuando una línea del carrito pide más unidades de las que alcanza el inventario (p. ej. 5 granizados con insumo para 3), pero el producto sigue pudiéndose pedir en cantidad 1, ¿cómo se trata esa línea al enviar? → A: **Igual que un agotado.** El 409 unificado la lista, la línea se marca «Agotado» y la persona debe quitarla (y puede volver a agregar la cantidad que alcance). No hay aviso en vivo para este caso: el producto sigue pedible en cantidad 1.
- Q: ¿Cuántos segundos debe llevar caída la conexión en vivo antes de mostrar el indicador «Sin actualización en vivo»? → A: **5 segundos continuos.** Un corte menor a 5 segundos que se recupera no muestra el indicador.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - El cambio de disponibilidad se ve en todas las pantallas abiertas sin recargar (Priority: P1)

Como mesera, cajero o comensal con el catálogo abierto, quiero que cuando alguien marque un producto como «Agotado» (o lo vuelva a poner disponible) mi pantalla lo refleje sola, en pocos segundos, sin tener que recargar la página. Así dejo de tomar pedidos de productos que ya no hay y recupero rápido los que volvieron, sin que el comensal ni yo descubramos el problema recién al enviar el pedido.

**Why this priority**: Es el valor central de la funcionalidad. Hoy el agotado (spec 093) solo se ve al recargar o al volver a abrir la pantalla; en hora pico eso se traduce en pedidos rechazados y clientes frustrados. Las demás historias dependen de que este reflejo exista.

**Independent Test**: Con el menú QR de un comensal y la Terminal de una mesera abiertos en el mismo negocio, un Cajero marca «Granizado de mora» como agotado desde la Carta del menú; se cronometra el tiempo hasta que ambas pantallas muestran «Agotado» y deshabilitan la selección, sin ninguna recarga. Luego se repite al revés (volver a disponible).

**Acceptance Scenarios**:

1. **Given** la mesera tiene abierto el catálogo de orden manual y un comensal tiene abierto el menú QR del mismo negocio, **When** un usuario autorizado marca «Granizado de mora» como agotado, **Then** en ambas vistas el producto aparece como «Agotado» en menos de 3 segundos, su selección queda deshabilitada y ninguna de las dos vistas requiere recargar la página.
2. **Given** «Granizado de mora» está marcado como agotado, **When** un usuario autorizado lo cambia a disponible, **Then** en todas las vistas abiertas del negocio el producto vuelve a habilitarse para agregarse al carrito en menos de 3 segundos y sin recargas.
3. **Given** un segundo cajero tiene abierta la Carta del menú, **When** el primer cajero marca un producto como agotado, **Then** el interruptor y la etiqueta «Agotado» del segundo cajero se actualizan sin recargar.
4. **Given** la mesera está agregando productos a una orden existente desde el catálogo lateral, **When** un producto del catálogo se agota, **Then** ese producto aparece como «Agotado» y no puede agregarse, sin cerrar ni recargar el catálogo.
5. **Given** un usuario con la pantalla abierta y la conexión estable, **When** se marcan y desmarcan varias veces seguidas el mismo producto, **Then** la pantalla termina mostrando el estado de la última acción confirmada, nunca uno anterior.

---

### User Story 2 - El carrito se conserva cuando un producto se agota, y solo se señala lo afectado (Priority: P1)

Como mesera con un pedido a medio armar (o comensal con su carrito del menú QR), quiero que si un producto de mi carrito se agota no pierda lo demás: la línea afectada debe resaltarse como «Agotado» con una opción clara para quitarla, el resto del carrito debe quedar intacto y el envío debe esperar a que resuelva el producto agotado.

**Why this priority**: Vaciar o rehacer el carrito en hora pico es el peor efecto práctico del agotamiento (RN-3). Sin esto, el reflejo en pantalla de la historia 1 se vuelve un problema nuevo en lugar de una ayuda.

**Independent Test**: Armar un carrito con 2 «Granizado de mora» y 1 «Paleta de coco», marcar el granizado como agotado desde otra sesión y verificar que solo esa línea queda resaltada, que la paleta sigue igual, que el envío queda bloqueado, y que al quitar la línea el envío se habilita con lo restante. Repetir con el carrito del menú QR.

**Acceptance Scenarios**:

1. **Given** la mesera tiene en su carrito activo 2 unidades de «Granizado de mora» y 1 de «Paleta de coco», **When** «Granizado de mora» pasa a estado agotado, **Then** la línea de «Granizado de mora» se resalta visualmente como «Agotado» con la opción explícita de eliminarla, la línea de «Paleta de coco» se conserva intacta y el botón de envío del pedido queda deshabilitado temporalmente.
2. **Given** la línea de «Granizado de mora» está marcada como agotada, **When** la mesera la elimina, **Then** el carrito conserva el resto de líneas con sus cantidades, opciones y notas, y el botón de envío se vuelve a habilitar.
3. **Given** la línea de «Granizado de mora» está marcada como agotada y el envío bloqueado, **When** el producto vuelve a estar disponible, **Then** la marca «Agotado» desaparece sola de la línea, la línea queda como estaba antes y el botón de envío se vuelve a habilitar sin que la mesera haga nada.
4. **Given** un comensal tiene «Granizado de mora» en el carrito del menú QR, **When** el producto se agota, **Then** su línea se resalta como «Agotado» con la opción de quitarla, el resto del carrito queda intacto y «Confirmar pedido» queda bloqueado hasta que la quite o el producto vuelva a estar disponible.
5. **Given** el carrito tiene dos productos distintos y ambos se agotan, **When** la mesera mira el carrito, **Then** ambas líneas aparecen marcadas y el envío sigue bloqueado hasta resolver las dos.
6. **Given** una línea del carrito incluye una adición (topping), una opción (sabor) o una presentación, y ese elemento se agota, **When** se actualiza la pantalla, **Then** la línea que lo contiene queda marcada como afectada, indicando cuál es el elemento agotado, y el resto del carrito no cambia (incluidas otras líneas del mismo producto con otra presentación u opción disponible).
7. **Given** un comensal del menú QR está en el paso de transferencia con su comprobante ya subido, **When** un producto de su carrito se agota, **Then** permanece en ese paso con lo ya llenado, la línea aparece marcada «Agotado» en el resumen del pedido, «Confirmar pedido» queda bloqueado y un botón «Volver al carrito» le permite quitar la línea.
8. **Given** el comensal del escenario anterior quita la línea agotada y el total baja, **When** vuelve al paso de pago, **Then** se le avisa «El total cambió a $X», el método y el comprobante se conservan, y solo si en un pago mixto el efectivo ya no es menor al nuevo total se le pide corregir ese monto.

---

### User Story 3 - El servidor sigue siendo la última línea de defensa: condición de carrera con 409 (Priority: P1)

Como mesera que envía un pedido justo cuando un producto acaba de agotarse (antes de que le llegue el aviso a mi pantalla), quiero que el sistema rechace el pedido sin crear nada, me diga exactamente qué productos se agotaron y me deje corregir el carrito sin perderlo.

**Why this priority**: El aviso en tiempo real siempre puede llegar tarde o no llegar (RN-2). La validación del servidor es la garantía real de que no se venden productos agotados; la experiencia de recuperación decide si ese rechazo es un incidente o un trámite de segundos.

**Independent Test**: Con una pantalla que aún no recibió el aviso, enviar un pedido que incluye un producto recién agotado y verificar que (a) no se crea ninguna orden, (b) la respuesta es un 409 con la lista de agotados (ID y nombre), y (c) el carrito se conserva con solo las líneas afectadas marcadas y el mensaje esperado.

**Acceptance Scenarios**:

1. **Given** la mesera envía una orden que contiene «Granizado de mora», que se agotó milisegundos antes de que su pantalla recibiera el aviso, **When** el servidor valida la orden, **Then** responde con un código 409 Conflict que adjunta la lista detallada de los productos agotados (identificador y nombre), y no crea ninguna orden, ni siquiera parcial.
2. **Given** el servidor rechazó la orden con un 409, **When** la pantalla procesa la respuesta, **Then** conserva el carrito completo, marca únicamente las líneas afectadas y muestra una alerta clara del tipo «Se agotó: Granizado de mora. Quítalo para continuar».
3. **Given** el pedido contiene dos productos agotados al mismo tiempo, **When** el servidor responde 409, **Then** la respuesta lista ambos, la pantalla marca ambas líneas y la alerta nombra ambos (por ejemplo «Se agotaron: Granizado de mora, Paleta de coco. Quítalos para continuar»).
4. **Given** un producto está agotado porque le faltan insumos en inventario (no porque alguien lo marcó a mano), **When** se intenta enviar un pedido que lo contiene, **Then** el servidor responde con el mismo 409 y el mismo tipo de lista que para el agotado manual.
5. **Given** la pantalla de la mesera está totalmente al día con el estado de disponibilidad, **When** intenta forzar el envío de un pedido con un producto agotado (por ejemplo, desde una pantalla desactualizada o una petición directa), **Then** el servidor lo rechaza igual: la sincronización del cliente nunca reemplaza la validación del servidor.
6. **Given** una línea pide 5 unidades de un producto cuyo inventario alcanza para 3, **When** se envía el pedido, **Then** el servidor responde con el mismo 409 listando ese producto, no crea ninguna orden, la pantalla marca la línea como «Agotado» con la opción de quitarla y el carrito se conserva; la persona puede volver a agregar una cantidad que alcance.

---

### User Story 4 - Aislamiento estricto entre negocios (Priority: P1)

Como dueño de un negocio, necesito la garantía de que lo que pasa con la disponibilidad de mis productos no se filtra ni se recibe en ninguna pantalla de otro negocio, y que mis clientes no ven eventos que no les corresponden.

**Why this priority**: Es una condición de seguridad y confianza multi-tenant (RN-4). Una fuga entre negocios es un incidente grave aunque la funcionalidad "funcione".

**Independent Test**: Con sesiones y catálogos abiertos de dos negocios distintos, marcar un producto como agotado en uno y verificar, observando todos los canales de suscripción del otro, que no llega ningún aviso.

**Acceptance Scenarios**:

1. **Given** existen sesiones activas y catálogos abiertos para los negocios «springfieldgranizados» y «heladerialeonardo», **When** «springfieldgranizados» marca un producto como agotado, **Then** ninguna vista ni canal de suscripción perteneciente a «heladerialeonardo» recibe ese aviso.
2. **Given** ambos negocios tienen productos con el mismo nombre (por ejemplo «Granizado de mora»), **When** uno de ellos lo marca como agotado, **Then** el producto homónimo del otro negocio sigue disponible y su pantalla no cambia.
3. **Given** un comensal con el menú QR abierto, **When** ocurren cambios de disponibilidad en su negocio, **Then** recibe únicamente avisos de disponibilidad del menú de su negocio y nunca los avisos internos del personal (como el estado de las mesas o los pagos de otros).

---

### User Story 5 - Recuperación tras perder la conexión en vivo (Priority: P2)

Como mesera o comensal cuya pantalla perdió un momento la conexión en vivo (señal débil, cambio de red, pantalla en reposo), quiero saber discretamente que ya no estoy recibiendo actualizaciones, y que al volver la conexión mi catálogo se ponga al día solo, incluyendo lo que cambió mientras no estuve.

**Why this priority**: Sin esto, un corte breve deja el catálogo desfasado en silencio, justo el problema que la funcionalidad quiere eliminar. Es menos prioritario que las historias 1-4 porque la validación del servidor (historia 3) protege la operación mientras tanto.

**Independent Test**: Cortar la conexión en vivo de una vista, cambiar la disponibilidad de varios productos mientras está cortada, restablecerla y verificar que el catálogo y el carrito se actualizan solos y que el indicador aparece al cortar y desaparece al restablecer.

**Acceptance Scenarios**:

1. **Given** la vista de catálogo pierde temporalmente la conexión de eventos en vivo, **When** el sistema detecta la pérdida, **Then** se muestra un indicador discreto «Sin actualización en vivo» que no bloquea ni estorba el uso del catálogo.
2. **Given** la conexión estuvo caída y durante ese lapso cambió la disponibilidad de varios productos, **When** la conexión se restablece, **Then** la vista consulta automáticamente la disponibilidad completa del catálogo, actualiza los productos que cambiaron durante la desconexión y retira el indicador «Sin actualización en vivo».
3. **Given** la vista estuvo desconectada y un producto de su carrito se agotó durante ese lapso, **When** la conexión se restablece, **Then** la línea de ese producto queda marcada como «Agotado» y el envío bloqueado, igual que si el aviso hubiera llegado en vivo.
4. **Given** la vista está desconectada, **When** la mesera o el comensal sigue operando (agregando productos, enviando), **Then** puede hacerlo normalmente, y si envía un producto que se agotó el servidor lo rechaza como en la historia 3.
5. **Given** el servidor le indica a la vista que se perdieron avisos y que debe ponerse al día (porque estuvo desconectada más tiempo del que se puede reponer), **When** la vista recibe esa indicación, **Then** hace la misma consulta completa del catálogo que al reconectar.
6. **Given** un microcorte de conexión de menos de 5 segundos que se recupera, **When** ocurre, **Then** el indicador «Sin actualización en vivo» no aparece.

---

### User Story 6 - El agotamiento por inventario avisa igual que el marcado manual (Priority: P2)

Como cajero o comensal, quiero que cuando un producto deje de poder pedirse porque se acabaron sus insumos (por ejemplo, se vendió la última porción y el stock llegó a cero), todas las pantallas lo muestren agotado de inmediato, igual que si alguien lo hubiera marcado a mano, y que vuelva a mostrarse disponible cuando se reponga el insumo.

**Why this priority**: Completa el objetivo de negocio (que nadie descubra el agotado al enviar el pedido) para los negocios que manejan inventario. Es P2 porque la historia 1 ya cubre el caso manual y la historia 3 protege el envío en cualquier caso; esta historia lleva el aviso al caso automático.

**Independent Test**: En un negocio con inventario, consumir con un pedido (o ajustar manualmente) el último insumo de un producto y verificar que las pantallas abiertas lo muestran agotado en menos de 3 segundos; reponer el insumo y verificar que vuelve a habilitarse.

**Acceptance Scenarios**:

1. **Given** «Granizado de mora» maneja inventario y le queda insumo para una sola preparación, **When** una venta o un ajuste de inventario deja el insumo en cero, **Then** las vistas abiertas del negocio muestran el producto como «Agotado» en menos de 3 segundos, con la misma presentación que el agotado manual.
2. **Given** «Granizado de mora» está agotado por falta de insumo, **When** una compra o un ajuste de inventario repone el insumo, **Then** las vistas abiertas lo muestran disponible de nuevo en menos de 3 segundos.
3. **Given** un insumo compartido por varios productos, presentaciones u opciones llega a cero, **When** se actualizan las vistas, **Then** todos los elementos que dependían de ese insumo aparecen agotados.
4. **Given** un producto está marcado como agotado a mano y además tiene insumo suficiente, **When** cambia el inventario, **Then** el producto sigue agotado: la marca manual no se levanta por el inventario (spec 093, FR-012).
5. **Given** un producto no está marcado a mano pero no tiene insumo, **When** el cajero lo consulta en la Carta del menú, **Then** su marca manual sigue indicando «disponible» y el sistema no la modifica, aunque las pantallas de pedido lo muestren como agotado.
6. **Given** un movimiento de inventario que no cambia si un producto se puede pedir o no (por ejemplo, el stock baja de 10 a 9), **When** ocurre, **Then** no se emite ningún aviso de disponibilidad.
7. **Given** «Granizado de mora» se vende en «12 oz» y «16 oz», y el insumo de «16 oz» llega a cero mientras el de «12 oz» no, **When** se actualizan las vistas, **Then** «16 oz» aparece «Agotado» y no se puede elegir, «12 oz» sigue seleccionable y el producto no se muestra agotado. Lo mismo aplica a un sabor u otra opción de un grupo.

---

### Edge Cases

- **Pedidos ya creados**: los pedidos que ya existían antes de que el producto se agotara no se ven afectados (spec 093); solo cambia lo que está en un carrito sin enviar o lo que se intente agregar.
- **Producto inactivo**: dar de baja un producto (activo/inactivo) no es un cambio de disponibilidad de esta funcionalidad y queda fuera de alcance; el interruptor «Agotado» sigue deshabilitado para productos inactivos (spec 093).
- **Aviso perdido o tardío**: si el aviso nunca llega o llega después del intento de envío, la validación del servidor y el 409 cubren el caso; el sistema no depende del aviso para ser correcto.
- **Cambios en ráfaga sobre el mismo producto**: se marca y desmarca varias veces en segundos; la pantalla debe terminar en el estado confirmado más reciente, aun si los avisos llegan en otro orden.
- **Pestaña en segundo plano o dispositivo en reposo**: al volver a primer plano, la vista debe ponerse al día (mismo comportamiento que al reconectar).
- **Falla del canal en vivo al cambiar la disponibilidad**: el cambio de disponibilidad se guarda igual y no se revierte; las vistas se ponen al día cuando recuperan la conexión o la siguiente vez que consultan el catálogo.
- **Carrito vacío tras quitar la línea afectada**: si la línea agotada era la única, el carrito queda vacío por decisión explícita de quien la quitó, no por el sistema, y se muestra el estado normal de carrito vacío.
- **Producto que se agota y vuelve a estar disponible antes de que se actúe**: la marca de la línea desaparece sola y el carrito queda como estaba.
- **Cantidad mayor a lo que alcanza el inventario**: el producto sigue pedible en cantidad 1, por lo que no hay aviso en vivo ni marca anticipada; solo el envío lo detecta (409 unificado, FR-022) y la línea se trata como agotada.
- **Comprobante de un total que cambió**: esta funcionalidad no agrega validación automática del monto del comprobante; si el total baja tras quitar una línea agotada, el cajero compara comprobante y total al revisar el pago, como hoy.
- **Varias terminales de la misma mesera o del mismo negocio**: todas reciben el aviso; ninguna debe depender de que otra lo haya recibido.
- **Comensal con sesión de mesa vencida o inválida**: no recibe avisos en vivo (no se suscribe) y, si intenta operar, recibe el tratamiento habitual de sesión expirada, no un error de disponibilidad.
- **Usuario sin permiso**: solo Cajero y Administrador pueden cambiar la disponibilidad (spec 093); un intento de otro rol se rechaza como hoy y no produce ningún aviso.
- **Negocios sin módulo de inventario o productos que no manejan inventario**: el agotado por inventario no aplica; solo se sincroniza el agotado manual.
- **Promociones que incluyen un producto agotado**: la línea del producto agotado es la afectada y se maneja igual que cualquier otra línea; esta funcionalidad no cambia las reglas de promociones.

## Requirements *(mandatory)*

### Functional Requirements

**Propagación en tiempo real (RN-1)**

- **FR-001**: El sistema DEBE notificar en tiempo real a todas las vistas abiertas del mismo negocio cada vez que cambie la disponibilidad de un producto o de una de sus presentaciones u opciones, sea por marcado manual (solo a nivel de producto, «Agotado» ↔ disponible) o por inventario (FR-008).
- **FR-002**: El sistema DEBE reflejar el cambio en las vistas abiertas sin que la persona recargue la página, mostrando el producto como «Agotado» y deshabilitando su selección (o volviéndolo a habilitar), en menos de 3 segundos con conexión estable.
- **FR-003**: Las superficies dentro del alcance DEBEN ser: (a) el menú QR del comensal, (b) la Terminal de nueva orden en todas sus modalidades (mesa, para llevar, domicilio y la página de orden manual), (c) el catálogo para agregar ítems a una orden existente y (d) la Carta del menú de Cajero y Administrador.
- **FR-004**: El sistema DEBE emitir el aviso solo después de que el cambio de disponibilidad quedó confirmado, de modo que nunca se anuncie un cambio que no ocurrió.
- **FR-005**: La falla del canal en vivo NO DEBE impedir ni revertir el cambio de disponibilidad; el cambio se guarda igual y las vistas se ponen al día al recuperar la conexión.
- **FR-006**: Cuando varios cambios sobre el mismo producto lleguen en rápida sucesión, la vista DEBE terminar mostrando el estado del último cambio confirmado y NO DEBE quedar en un estado anterior por la llegada desordenada de avisos.
- **FR-007**: El aviso enviado a las vistas NO DEBE incluir información interna del negocio como cantidades de inventario, costos ni nombres de insumos; solo lo necesario para identificar el producto —y, cuando aplique, la presentación u opción— y su nueva disponibilidad.

**Agotado por inventario (RN-5)**

- **FR-008**: El sistema DEBE tratar como cambio de disponibilidad, con el mismo aviso que el marcado manual, el momento en que un movimiento de inventario deja un producto, una de sus presentaciones o una de sus opciones (sabor, salsa, adición) sin poder pedirse (no hay existencias suficientes para preparar al menos una unidad) o lo vuelve a dejar pedible. Si solo se agota una presentación u opción, el producto sigue pedible y el aviso identifica el elemento agotado; un producto con todas sus presentaciones agotadas se considera agotado.
- **FR-009**: El sistema DEBE emitir el aviso por inventario únicamente cuando un producto, una presentación o una opción cambia entre «se puede pedir» y «no se puede pedir», y NO DEBE emitirlo por movimientos que no alteran ese estado.
- **FR-010**: Cuando un solo movimiento de inventario afecte a varios productos, presentaciones u opciones (por ejemplo, un insumo compartido), el sistema DEBE notificar el cambio de todos los elementos afectados.
- **FR-011**: El agotado por inventario DEBE ser un estado derivado: el sistema NO DEBE modificar la marca manual de «Agotado» de ningún producto por efecto del inventario. Un producto marcado a mano sigue agotado aunque haya insumo, y un producto con insumo agotado se muestra agotado aunque su marca manual indique disponible (spec 093, FR-012 se mantiene).
- **FR-012**: Las pantallas DEBEN presentar el producto agotado por inventario y el agotado a mano con la misma etiqueta «Agotado» y el mismo comportamiento de selección deshabilitada.

**Preservación del carrito (RN-3)**

- **FR-013**: Cuando un producto presente en un carrito sin enviar (borrador de la Terminal o carrito del menú QR) pasa a estar agotado, el sistema DEBE resaltar su línea como «Agotado» y ofrecer una opción explícita para eliminarla.
- **FR-014**: El sistema DEBE conservar intactas todas las líneas no afectadas, con sus cantidades, opciones, adiciones y notas.
- **FR-015**: El sistema DEBE deshabilitar el envío del pedido (Terminal) y la confirmación del pedido (menú QR) mientras exista al menos una línea marcada como agotada, y DEBE habilitarlo de nuevo cuando todas hayan sido quitadas o hayan vuelto a estar disponibles.
- **FR-016**: Si un producto marcado en una línea vuelve a estar disponible, el sistema DEBE retirar la marca de esa línea por sí solo, dejando la línea como estaba.
- **FR-017**: Cuando la presentación, una opción (sabor, salsa) o una adición (topping) elegida en una línea se agota, el sistema DEBE tratar esa línea como afectada e indicar cuál elemento es el agotado; las demás líneas, incluidas las del mismo producto con otra presentación u opción disponible, NO DEBEN cambiar.
- **FR-018**: Ni la llegada de un aviso en tiempo real ni un rechazo del servidor por producto agotado DEBEN vaciar o reiniciar el carrito. Solo la persona puede quitar líneas.
- **FR-019**: El comportamiento de carrito de FR-013 a FR-018 DEBE ser el mismo en la Terminal y en el menú QR. En el menú QR, cuando una línea queda afectada mientras el comensal está en los pasos de pago (método, efectivo o transferencia), el comensal DEBE permanecer en ese paso sin perder lo ya llenado (método elegido, monto, comprobante); la línea afectada DEBE marcarse «Agotado» en el resumen del pedido de esos pasos, DEBE mostrarse la alerta, la confirmación DEBE quedar bloqueada y DEBE ofrecerse un botón «Volver al carrito» para quitarla. El sistema NO DEBE moverlo de paso por su cuenta. Si al quitar la línea el total baja, DEBEN conservarse el método y el comprobante ya subido, y el sistema DEBE avisar el nuevo total («El total cambió a $X»); solo si en un pago mixto el monto en efectivo deja de ser menor al nuevo total, DEBE pedir que lo corrija (lo que invalida el comprobante según la regla vigente de la spec 130).
- **FR-020**: El sistema DEBE impedir agregar al carrito (o a una orden existente) un producto, presentación u opción que esté agotado, mostrando su selección deshabilitada.

**Servidor como fuente de verdad (RN-2) y rechazo con 409**

- **FR-021**: El sistema DEBE mantener la validación de disponibilidad del servidor en todos los puntos donde se agrega, edita o confirma un producto en un pedido, independientemente de lo que la pantalla del cliente muestre.
- **FR-022**: Cuando un pedido incluya uno o más productos agotados (por marca manual o por falta de insumos), el sistema DEBE rechazarlo con una respuesta 409 Conflict que incluya la lista completa de los elementos agotados (productos, presentaciones u opciones), cada uno con su identificador y un nombre legible que, para una presentación u opción, la nombre junto con su producto (por ejemplo «Granizado de mora · 16 oz»), y NO DEBE crear ninguna orden, ni siquiera parcial. También DEBE listarse, con el mismo tratamiento, la línea cuya cantidad pedida supera lo que alcanza el inventario aunque haya para una sola unidad.
- **FR-023**: La respuesta 409 DEBE conservar el mensaje legible y los datos que los clientes actuales ya consumen, además de agregar la lista detallada, de modo que ningún cliente existente deje de interpretarla.
- **FR-024**: Ante un 409 por producto agotado, la pantalla DEBE conservar el carrito completo, marcar únicamente las líneas afectadas y mostrar una alerta clara con el formato «Se agotó: <elemento>. Quítalo para continuar» (en plural, «Se agotaron: <elemento 1>, <elemento 2>. Quítalos para continuar»), donde cada elemento es el producto, presentación u opción agotado.

**Conexión en vivo (Escenario 5)**

- **FR-025**: La vista DEBE mostrar un indicador discreto «Sin actualización en vivo» mientras haya perdido la conexión de eventos en vivo, sin bloquear el uso del catálogo ni del carrito, y sin parpadear por microcortes: el indicador DEBE aparecer solo cuando la conexión lleva caída 5 segundos continuos o más.
- **FR-026**: Al restablecerse la conexión, la vista DEBE consultar automáticamente la disponibilidad completa del catálogo, actualizar los productos y las líneas del carrito que cambiaron durante la desconexión y retirar el indicador.
- **FR-027**: Cuando el sistema le indique a la vista que se perdieron avisos y debe ponerse al día, la vista DEBE ejecutar la misma consulta completa de FR-026.
- **FR-028**: Cuando una pestaña o dispositivo vuelva de segundo plano o reposo, la vista DEBE verificar que está al día con el mismo mecanismo de FR-026 si pudo haber perdido avisos.
- **FR-029**: La pérdida de la conexión en vivo NO DEBE impedir operar: la persona puede seguir armando y enviando pedidos, y la validación del servidor (FR-021 a FR-024) actúa como garantía.

**Aislamiento entre negocios (RN-4)**

- **FR-030**: El sistema DEBE entregar los avisos de disponibilidad de un negocio exclusivamente a las vistas de ese mismo negocio; ninguna sesión, vista o canal de suscripción de otro negocio DEBE recibirlos.
- **FR-031**: El sistema DEBE derivar a qué negocio pertenece cada vista a partir de su sesión autenticada, nunca de un dato que la vista pueda elegir libremente.
- **FR-032**: Un comensal DEBE recibir únicamente los avisos de disponibilidad del menú de su negocio y NO DEBE recibir los avisos internos del personal (estado de mesas, pagos, notificaciones u otros pedidos).

**Autorización**

- **FR-033**: Solo los usuarios autorizados por la spec 093 (Cajero y Administrador) DEBEN poder marcar o desmarcar un producto como agotado; esta funcionalidad no cambia quién puede hacerlo ni la trazabilidad de quién y cuándo lo hizo.

### Impacto sobre funcionalidades y datos existentes

- **Cambio de comportamiento existente (decisión de negocio ya tomada en Clarifications)**: hoy el rechazo por falta de insumos al crear una orden responde con un error 400 que nombra un solo producto y el insumo faltante (incluida la falta por una cantidad pedida mayor a las existencias), mientras que el rechazo por marca manual responde 409 con una lista de solo nombres. Esta spec unifica ambos en un 409 con lista de identificador y nombre (FR-022). Por el Principio II de la constitución, este cambio DEBE registrarse en el registro de anomalías antes de implementarse, y los tests que hoy congelan el 400 por inventario DEBEN actualizarse de forma explícita citando esa decisión (Principio III).
- **Spec 093**: se mantiene tal cual el interruptor «Agotado» manual, sus permisos, su trazabilidad y su independencia del inventario (FR-012 de 093). Esta spec solo agrega que el cambio se vea sin recargar y que el carrito reaccione.
- **Spec 128**: el menú QR ya se actualiza solo cuando una categoría cambia de visibilidad; el aviso de disponibilidad convive con ese comportamiento y no lo altera.
- **Datos históricos**: ningún pedido ya creado, factura emitida ni registro histórico se modifica. No se recalcula nada retroactivamente (Principio VII).

### Key Entities *(include if feature involves data)*

- **Disponibilidad**: el estado «se puede pedir / no se puede pedir» que ve una persona, a tres niveles: producto, presentación y opción (sabor, salsa o adición). Combina la marca manual «Agotado» (solo a nivel de producto; persistida, con quién y cuándo, spec 093) y el estado derivado por inventario (a cualquiera de los tres niveles, calculado a partir de las existencias de insumos). Si cualquiera de las dos indica que no se puede pedir, el elemento se muestra «Agotado»; un producto con todas sus presentaciones agotadas se muestra agotado.
- **Aviso de disponibilidad**: notificación breve que dice qué producto —y, si aplica, qué presentación u opción— cambió y a qué estado, dirigida solo a las vistas del negocio dueño del producto. No lleva datos internos (existencias, costos, insumos).
- **Línea de carrito afectada**: línea de un carrito sin enviar cuyo producto, presentación elegida, opción elegida o adición está agotado. Se marca visualmente, se puede quitar, bloquea el envío y se normaliza sola si el producto vuelve a estar disponible.
- **Rechazo por agotado**: respuesta del servidor (409) a un intento de enviar o modificar un pedido con productos no pedibles; incluye la lista de productos afectados con identificador y nombre.
- **Estado de la conexión en vivo**: indicador, por vista, de si está recibiendo avisos («Sin actualización en vivo» cuando no).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Con conexión estable y carga normal, al menos el 99% de los cambios de disponibilidad (manuales o por inventario) se reflejan en todas las vistas abiertas del negocio en menos de 3 segundos, sin ninguna recarga manual.
- **SC-002**: En el 100% de los casos en que un producto de un carrito sin enviar se agota, el resto de las líneas del carrito se conserva sin cambios; ningún agotamiento ni rechazo vacía el carrito.
- **SC-003**: El 100% de los intentos de enviar un pedido con al menos un producto agotado (por marca manual o por falta de insumos) es rechazado sin crear ninguna orden, y la respuesta nombra todos los elementos agotados (productos, presentaciones u opciones) con su identificador y nombre.
- **SC-004**: En pruebas con dos negocios activos al mismo tiempo, el 0% de los avisos de disponibilidad de un negocio llega a vistas o canales del otro.
- **SC-005**: Tras restablecerse una conexión en vivo caída, el 100% de las vistas queda sincronizada con la disponibilidad actual del catálogo y retira el indicador «Sin actualización en vivo» sin intervención de la persona.
- **SC-006**: El 100% de las transiciones de «se puede pedir» ↔ «no se puede pedir» causadas por movimientos de inventario se refleja en las vistas abiertas, y los movimientos que no cambian ese estado generan 0 avisos.
- **SC-007**: Con el aviso en vivo inoperante (conexión caída), el sistema sigue rechazando el 100% de los envíos con productos agotados; el servidor nunca depende de que el cliente esté sincronizado.

## Assumptions

- «Caja» y «domicilios» del requerimiento original se entienden como modalidades de la Terminal de nueva orden (mesa, para llevar y domicilio) y la página de orden manual; no existe una pantalla de «caja» distinta que arme pedidos desde el catálogo.
- «Usuario autorizado» para cambiar la disponibilidad es el que ya define la spec 093 (Cajero y Administrador); no se crean permisos nuevos.
- El sistema ya cuenta con un canal de avisos en vivo por negocio, con reconexión y reposición de avisos perdidos, que hoy usan las notificaciones al personal (spec 077), la confirmación de pago (spec 125) y la visibilidad de categorías en el menú QR (spec 128). Esta spec lo extiende a la disponibilidad de productos y no define una tecnología nueva.
- El carrito de la Terminal vive en la pantalla de la mesera hasta que se envía; el del menú QR se conserva del lado del servidor. Ambos reciben el mismo tratamiento visual y de bloqueo (aclarado en Clarifications).
- Las adiciones (toppings) son productos con su propia disponibilidad; una adición agotada afecta la línea que la contiene.
- El agotado por inventario solo aplica a los productos que manejan inventario en negocios con el módulo habilitado; para el resto, solo existe el agotado manual.
- Un producto, presentación u opción no pedible por inventario es aquel cuyas existencias no alcanzan para preparar al menos una unidad (el caso «llegó a cero» del requerimiento es el ejemplo típico).
- El umbral de 3 segundos se mide con conexión estable y carga normal; no se define un objetivo para conexiones degradadas más allá de la recuperación de FR-026.
- El indicador «Sin actualización en vivo» aparece en toda vista con catálogo abierto (menú QR y superficies de la Terminal); solo se muestra tras 5 segundos continuos sin conexión, para evitar parpadeos.
- Pasar un producto de activo a inactivo, editar sus precios o cambiar su categoría quedan fuera de alcance; solo se sincroniza la disponibilidad (agotado ↔ disponible).
- El texto exacto de las alertas sigue el formato indicado en los escenarios («Se agotó: …. Quítalo para continuar»); ajustes de redacción menores no alteran la spec.
