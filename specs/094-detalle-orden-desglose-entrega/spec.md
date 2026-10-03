# Feature Specification: Desglose Económico y Datos de Entrega en el Detalle de Orden

**Feature Branch**: la spec vive en la carpeta `specs/094-detalle-orden-desglose-entrega/` de `pos-specs`, rama `main`. Las ramas de código de `pos-backend` y `pos-heladeria` siguen el Principio XIV y se definen en `tasks.md`

**Created**: 2026-10-03

**Status**: Ready for planning

**Numeración**: esta spec es la **094** por decisión explícita del solicitante: la 093 está siendo trabajada por otra persona y no se toca desde aquí.

**Input**: User description: "Enriquecer el modal/vista 'Detalle de Orden' en los roles de Administración y Caja para que muestre el desglose económico exacto de cada ítem, totales, descuentos, costo de envío y la información de despacho para órdenes a domicilio. El objetivo es permitir la verificación de cobros y el despacho rápido sin necesidad de navegar al módulo de Ventas ni consultar sistemas externos."

## Usuarios

- **Administrador de Tenant**: necesita auditoría completa e histórica de los valores con que se cobró un pedido, sin salir del módulo de Órdenes.
- **Cajero / Operador de POS**: necesita validar el cobro y leer los datos de entrega de forma inmediata para despachar el pedido con un mensajero o una plataforma de entrega.
- **Mesero** *(alcanzado sin ser solicitado — registrado como **A-107**, decisión tomada en Q4)*: hoy entra a la misma pantalla con los mismos permisos de lectura. No se le quita ni se le añade acceso en esta spec, y **verá todo lo que esta spec añade**, incluido el desglose monetario. Esto está **decidido, no pendiente** (Q4): el mesero ya ve importes y totales en la terminal de mesas, a la que entra con los mismos permisos, así que el desglose no le expone información nueva. Ocultarle el dinero queda en *Fuera de Alcance* y exigiría su propia spec.

## Problema

El Detalle de Orden muestra hoy, para cada ítem, únicamente **cantidad, nombre de la variante, opciones elegidas y la nota del ítem**. No muestra **ni un solo importe**: ni precio unitario, ni subtotal de línea, ni subtotal del pedido, ni descuento, ni costo de envío, ni total.

Las consecuencias concretas:

1. **Verificar un cobro exige salir de la pantalla.** Para saber por cuánto se cobró un pedido hay que ir al módulo de Ventas y emparejar la factura a mano. En una disputa con el cliente ("me cobraron mal"), eso es lento justo cuando se necesita rapidez.
2. **Despachar un domicilio exige consultar otra pantalla.** El Detalle de Orden no muestra dirección, teléfono ni referencias de entrega; esos datos sí se ven en la terminal de mesas, pero esa es la pantalla de cobro, no la de consulta. Y no hay forma de copiarlos: hoy se transcriben a mano al chat del mensajero, con el riesgo de equivocarse en un dígito del teléfono o en el número de la casa.
3. **La pantalla no distingue el tipo de pedido.** El encabezado dice "Mesa" siempre; para un pedido para llevar o a domicilio muestra "Mostrador", que no es ni el tipo ni la mesa.
4. **La etiqueta "Comensal" no corresponde.** El mismo campo identifica al comensal de una mesa, al cliente de mostrador y al receptor de un domicilio. "Comensal" solo es correcto en el primero de los tres casos.

## Clarifications

### Session 2026-10-03

Las preguntas nacieron del reconocimiento del código y de los datos reales; ninguna tenía un valor por defecto defendible sin decisión de negocio. Todas quedaron resueltas en la misma sesión y registradas como decisiones de negocio en `specs/000-reconocimiento/registro-de-anomalias.md`: **A-104** (Q1), **A-105** (Q2), **A-106** (Q3) y **A-107** (Q4, que pasa de hallazgo abierto a decisión tomada).

- **Q1 (alcance)**: el bloque "Datos de entrega" pide cuatro campos, pero el pedido solo guarda dos de ellos como datos propios de entrega (dirección y teléfono). No existe ningún campo de "nombre de quien recibe" distinto del nombre del cliente, ni ningún campo de "referencias o notas de entrega" distinto de la nota general del pedido. → **A: reusar lo que ya existe.** El receptor es el **nombre del cliente** del pedido y las referencias son la **nota general del pedido**. Cero migración, cero cambio en el formulario de creación de domicilios: esta spec se implementa en la pantalla y en la respuesta de consulta. **Consecuencia aceptada**: la nota del pedido tiene hoy un solo uso para dos propósitos, así que una nota dirigida a cocina ("sin cuchara") aparecerá bajo la etiqueta de referencias de entrega. Separarlas es un cambio de alcance con su propia spec (ver *Fuera de Alcance*).
- **Q2 (alcance / corrección)**: el criterio "el Total coincide exactamente con el total de la factura" no siempre es cumplible. Cuando se cierra una mesa con varios pedidos en cuenta unificada se emite **una sola factura que cubre todos los pedidos**, el descuento se registra en la factura y **cada pedido queda con descuento `0`**. → **A: factura 1:1 manda; si la factura agrupa, aviso.** Cuando existe una factura que cubre **solo** este pedido, el desglose se lee **de la factura** — así la igualdad exacta del criterio 10 queda garantizada por construcción, no por coincidencia de dos cálculos. Cuando la factura agrupa varios pedidos, se muestra el desglose propio del pedido **más un aviso** de que la factura agrupa varios pedidos, de modo que la pantalla no promete una igualdad que no puede sostener.
- **Q3 (UX / corrección)**: en un pedido aún no cobrado el descuento por promoción todavía no existe como dato guardado — se fija en el instante del cobro. Mostrar solo lo guardado implica que un pedido abierto con promoción vigente muestre un Total **mayor** que el que se le va a cobrar. → **A: sin fila de descuento, con aviso.** El pedido sin cobrar muestra `Total = Subtotal + Envío`, sin fila de descuento, y un aviso de que el descuento se fija al cobrar. Se descartó traer el descuento vigente del motor de cobro aunque se marcara como estimado: introduciría una segunda fuente de verdad en la misma pantalla según el estado del pedido, y un importe que puede cambiar entre dos consultas, en la pantalla cuyo valor es precisamente que lo que muestra no cambia. El total autoritativo del cobro en curso ya lo da la terminal de mesas, que es la pantalla de cobro.
- **Q4 (alcance / diseño de pantalla)**: ¿el mesero sigue viendo el mismo Detalle de Orden con los importes incluidos, o hay que ocultarle el dinero? Era la única decisión abierta de la spec (**A-107**) y no se podía dejar para después: ocultar importes por rol convierte un artefacto único en una pantalla con contenido condicionado, lo que cambia el diseño, el backend y los tests. → **A: una sola pantalla para los tres roles; el mesero ve el desglose completo.** El fundamento es que no hay exposición nueva: el mesero entra a la terminal de mesas con los mismos permisos con que entra al Detalle de Orden, y la terminal de mesas **ya le muestra importes y totales** (verificado en el reconocimiento, A-107). Queda confirmado RN-007 y A-107 pasa a cerrada. Ocultar el dinero al mesero sigue en *Fuera de Alcance*.
- **Q5 (corrección / aritmética visible)**: ¿el importe de una línea con descuento se muestra ya descontado o con el precio de lista? Tal como estaba escrito, el spec se contradecía: FR-002 pedía el importe ya descontado, FR-005 definía el Subtotal como la suma de los importes de las líneas, y FR-024 manda leer el desglose de la factura — cuyo `subtotal` es el **de lista** (la suma de los `line_total` sin descuento), con el descuento en un campo aparte. El resultado era una pantalla donde sumar las líneas no da el Subtotal mostrado y el descuento se resta dos veces. Agravante: el descuento por línea es una foto del momento de **confirmar** y el agregado del pedido una foto del momento de **cobrar**; no tienen por qué coincidir. → **A: las líneas muestran el precio y el importe de lista; el descuento vive solo en la fila del resumen.** Así `Σ líneas = Subtotal` y `Subtotal − Descuento + Envío = Total` cuadran en pantalla, y el Subtotal coincide con el de la factura por construcción, con una sola fuente de descuento. **Consecuencia**: esta pantalla **no usa** las columnas de descuento por línea; el nombre de la promoción sigue visible en la fila de descuento del resumen.
- **Q6 (testabilidad / alcance del caso legacy)**: ¿qué condición exacta dispara el aviso "Esta orden no tiene el detalle de precios por ítem"? FR-018 declaraba que la condición era un requisito pero no la enunciaba, así que no era testeable; y el modelo de datos indica que el caso casi no existe, porque el precio unitario y la cantidad de una línea **siempre** existen, desde el primer pedido del histórico. No hay pedido sin precio unitario: lo más que puede haber es un pedido cuyas líneas quedaron todas en `$ 0`. → **A: el aviso aparece cuando el pedido tiene al menos una línea no anulada y la suma de sus importes de lista es `$ 0`.** Es la única condición que el modelo puede producir de verdad, es una sola comparación y no se dispara en los pedidos normales. Se descartó marcar línea por línea (el aviso es del pedido, no de la línea) y se descartó retirar FR-018 (el estado es improbable, no imposible, y RN-005 exige decirlo cuando ocurra).
- **Q7 (UX / aritmética visible)**: ¿los ítems anulados se muestran o se ocultan? El spec decía que "mostrarlo o no es decisión de presentación" y la dejaba sin tomar, pero no es neutral: si se ocultan, sumar las líneas visibles cuadra con el Subtotal; si se muestran con importe, no cuadra. → **A: se muestran, marcados como anulados y sin importe cobrable.** Mantiene intacta la aritmética fijada en Q5 (FR-005, SC-007) y conserva la trazabilidad de la anulación, que es justo lo que audita un administrador. Se descartó ocultarlos (el detalle dejaría de contar que hubo una anulación, y un pedido con todo anulado se vería vacío) y un bloque aparte (más superficie de pantalla sin ganancia de información).
- **Q8 (testabilidad / redacción)**: ¿con qué texto exacto aparecen el aviso de factura agrupada (FR-024a) y el aviso de pedido sin cobrar (FR-023)? Eran los dos únicos mensajes de la pantalla sin redacción fijada, mientras FR-017 y FR-018 sí traen el texto literal; los escenarios US1 §8 y §9 verificaban "un aviso" sin poder comprobar cuál. → **A: textos literales fijados.** Factura agrupada: **"Este pedido se cobró junto con otros en una cuenta unificada; el total facturado está en Ventas"**. Pedido sin cobrar: **"El descuento se calcula al cobrar; este total aún puede cambiar"**. Dicen qué pasó y qué hacer, en el registro llano del resto de la pantalla, sin usar "factura agrupada" (que no es lenguaje de caja); el primero remite a Ventas, que sigue siendo la fuente de la factura.

### Hallazgos del reconocimiento (contexto, no decisiones)

Estos hechos ya están verificados en el código y en el modelo de datos. No son decisiones pendientes: son el terreno sobre el que se construye.

- **No es un modal: es una pantalla completa, y es una sola.** El Detalle de Orden vive en la ruta `orders/:id` del dashboard y la comparten los tres roles con el mismo componente. No hay una versión "de Administración" y otra "de Caja" que haya que enriquecer por separado: hay **una** pantalla, y enriquecerla la enriquece para todos.
- **El desglose histórico por ítem YA está guardado y YA llega al navegador.** Cada línea del pedido persiste `unit_price` (precio unitario congelado al confirmar), `addons_total` (adicionales cobrados una vez por línea), `line_total` (total de lista de la línea) y, cuando una promoción aplicó, `discounted_unit_price` / `discounted_line_total` (el precio ya con descuento, congelado al confirmar). La respuesta del pedido ya expone los cinco campos. **Esta spec no necesita guardar ningún dato monetario nuevo por ítem: necesita mostrar lo que ya está guardado.** Resuelta Q5, de los cinco la pantalla **usa tres** (`unit_price`, `addons_total`, `line_total`): los dos de descuento por línea no se muestran, porque el descuento vive solo en la fila del resumen.
- **El descuento y el nombre de la promoción también están guardados, pero a nivel de pedido y no se exponen.** El pedido persiste el monto agregado del descuento y la lista de promociones aplicadas con su nombre y su monto, ambos congelados en el cobro. **Ninguno de los dos viaja hoy en la respuesta de la orden**: ese es el hueco real de datos de esta spec — un hueco de **publicación**, no de persistencia.
- **El costo de envío ya está guardado y ya viaja** en la respuesta del pedido, congelado desde la creación del domicilio.
- **Una factura no siempre corresponde a un pedido.** En los caminos de cobro por pedido (mostrador, aprobación de un pago QR) la factura cuelga del pedido y el descuento se graba en el pedido. Pero al cerrar una mesa con **varios** pedidos en cuenta unificada se emite una sola factura que **no cuelga de ningún pedido** y cada pedido queda con descuento `0`, aunque sí conserve la lista de promociones de la sesión. Esto es lo que hace que el criterio 10 del brief no sea universalmente cumplible (resuelto en Q2).
- **El formato de moneda pedido ya es el formato único del producto.** Existe un formateador compartido que produce exactamente `$ 14.000` (sin decimales, punto de miles, espacio tras el símbolo) y una tubería de plantilla que lo aplica. El requisito de formato se cumple **usando lo que ya existe**, no definiendo un formato nuevo.
- **La etiqueta "Comensal" aparece una sola vez en la pantalla.** El listado de órdenes no la usa. La sustitución por "Cliente" es un cambio de una línea, no un barrido.
- **Ya existe precedente de copiado al portapapeles en el producto**, con su toast de éxito y su manejo de fallo, introducido para copiar los datos bancarios del checkout del comensal. Esta spec reusa ese patrón y su servicio de notificaciones; no inventa uno.
- **Ya existen las etiquetas "Para llevar" y "Domicilio"** como valores de presentación del tipo de pedido, usadas por los filtros del listado de órdenes.
- **El aislamiento entre tenants ya está garantizado por arquitectura**: los pedidos viven en el esquema del tenant resuelto por la sesión, y pedir un identificador que no está en ese esquema devuelve "no encontrado". El requisito de aislamiento de esta spec es una **prueba de regresión**, no una funcionalidad por construir.
- **Hay pedidos legacy sin desglose por ítem.** Las columnas de descuento por línea nacieron sin relleno retroactivo: en los pedidos anteriores llegan vacías. El precio unitario y la cantidad, en cambio, existen desde siempre. Es decir: el caso "orden antigua sin desglose" es más estrecho de lo que el brief supone (ver *Edge Cases*).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Verificar el cobro de un pedido sin salir de la pantalla (Priority: P1)

Como cajero o administrador, abro el Detalle de Orden y veo, para cada producto, su cantidad, su precio unitario y el importe de la línea; y debajo un resumen con el subtotal, el descuento aplicado (si hubo), el costo de envío (si hubo) y el total. Con eso respondo "¿por cuánto se cobró esto y por qué?" sin ir a Ventas.

**Why this priority**: es el motivo de ser de la spec. Entregada sola, ya elimina el salto a Ventas para el 100 % de los pedidos y resuelve 9 de los 14 criterios del brief. Todo lo demás es mejora sobre esta base.

**Independent Test**: abrir el detalle de un pedido de mesa ya cobrado con dos unidades de un producto y verificar que los importes por línea y el total mostrados coinciden con lo que se cobró, sin tocar el módulo de Ventas.

**Acceptance Scenarios**:

1. **Given** un pedido de mesa pagado con 2 × "Fresa boom · Pequeño 8 onz" a $ 8.000 y sin promoción, **When** abro su detalle, **Then** la línea muestra cantidad 2, precio unitario $ 8.000 e importe $ 16.000, y el resumen muestra Subtotal $ 16.000 y Total $ 16.000, **sin** fila de descuento y **sin** fila de envío.
2. **Given** un pedido cuyo subtotal fue $ 28.000 con un descuento de $ 4.000 proveniente de la promoción "2 x $12.000", **When** abro su detalle, **Then** el resumen muestra Subtotal $ 28.000, una fila "2 x $12.000 − $ 4.000" y Total $ 24.000, **y** las líneas muestran sus importes **de lista**, cuya suma es exactamente el Subtotal $ 28.000 — ninguna línea aparece ya descontada.
3. **Given** un pedido con descuento de $ 2.000 cuya promoción no dejó nombre registrado, **When** abro su detalle, **Then** la fila se muestra como "Descuento − $ 2.000".
4. **Given** un pedido creado cuando "Fresa boom" costaba $ 8.000 y el producto hoy cuesta $ 9.000, **When** abro su detalle, **Then** el precio unitario sigue siendo $ 8.000 y el total sigue siendo el de entonces.
5. **Given** un pedido en estado "Cancelada", **When** abro su detalle, **Then** veo el desglose con los valores originales **y** la etiqueta "Cancelada" — el desglose no se oculta ni se pone en cero.
6. **Given** un pedido para llevar, **When** abro su detalle, **Then** el encabezado dice "Para llevar" en lugar de una mesa, y no aparece el bloque "Datos de entrega".
7. **Given** un pedido con una factura que cubre solo ese pedido y cuyo total es $ 14.000, **When** abro su detalle, **Then** el Total muestra $ 14.000, exactamente el mismo valor que la factura en el módulo de Ventas.
8. **Given** un pedido cobrado dentro de una cuenta unificada de mesa junto con otros pedidos, **When** abro su detalle, **Then** veo el desglose propio del pedido **y** el aviso "Este pedido se cobró junto con otros en una cuenta unificada; el total facturado está en Ventas" — la pantalla no presenta ese Total como el total facturado.
9. **Given** un pedido todavía abierto, al que una promoción vigente le bajará el precio al cobrar, **When** abro su detalle, **Then** veo Subtotal y Total sin fila de descuento, **y** el aviso "El descuento se calcula al cobrar; este total aún puede cambiar".
10. **Given** un pedido de tres líneas en el que una fue anulada, **When** abro su detalle, **Then** veo las tres líneas —la anulada marcada como tal y sin importe cobrable— y el Subtotal es exactamente la suma de las dos líneas cobradas, sin la anulada.

---

### User Story 2 - Despachar un domicilio copiando los datos de entrega (Priority: P1)

Como cajero, abro el detalle de un pedido a domicilio, veo un bloque "Datos de entrega" con los datos del receptor y, con un clic en "Copiar datos", obtengo en el portapapeles un texto plano listo para pegar en el chat del mensajero o en la plataforma de entrega.

**Why this priority**: es P1 y no P2 porque resuelve un problema distinto al de la Historia 1 (despachar, no auditar) y porque es donde está el error humano hoy: transcribir a mano un teléfono o una dirección. Es independientemente desplegable: entregada sola, ya quita la transcripción manual aunque los importes sigan sin mostrarse.

**Independent Test**: abrir el detalle de un domicilio con los datos de entrega diligenciados, pulsar "Copiar datos" y pegar el contenido en cualquier editor de texto: debe aparecer el texto formateado con los datos del pedido, y la pantalla debe haber mostrado la confirmación.

**Acceptance Scenarios**:

1. **Given** un pedido a domicilio con receptor, teléfono, dirección, referencias y envío de $ 3.000, **When** abro su detalle, **Then** el encabezado dice "Domicilio", veo el bloque "Datos de entrega" con los cuatro campos, y el resumen muestra la fila de envío —rotulada "Domicilio", igual que en las pantallas de cobro— con $ 3.000, incluida en el Total.
2. **Given** ese mismo pedido, **When** pulso "Copiar datos", **Then** el portapapeles contiene el texto plano con nombre, teléfono, dirección y referencias, y aparece el mensaje "Datos de envío copiados al portapapeles".
3. **Given** un pedido a domicilio con envío en $ 0 y sin referencias, **When** abro su detalle, **Then** no aparece la fila de envío ni el campo de referencias, y el resto de los datos se muestra con normalidad.
4. **Given** un pedido a domicilio donde solo se registraron dirección y teléfono, **When** pulso "Copiar datos", **Then** el texto copiado contiene **solo** esas dos líneas — sin líneas vacías, sin la palabra "null" y sin guiones de relleno.
5. **Given** un navegador o contexto donde el portapapeles no está disponible, **When** pulso "Copiar datos", **Then** la pantalla me informa que no se pudo copiar y los datos siguen visibles y seleccionables a mano — la pantalla no se rompe ni se queda sin respuesta.

---

### User Story 3 - Leer el pedido sin tropezar con huecos de datos (Priority: P2)

Como administrador que audita pedidos viejos, abro cualquier pedido del histórico y la pantalla me dice con claridad qué información tiene y qué información no tiene, en vez de mostrarme ceros, guiones o "undefined".

**Why this priority**: no habilita una tarea nueva, pero sin esto la Historia 1 pierde su valor en el histórico: un "$ 0" inventado en un pedido viejo es peor que no mostrar nada, porque parece un dato.

**Independent Test**: abrir un pedido cuyas líneas no anuladas sumen $ 0 y verificar que se muestra el total disponible junto al aviso correspondiente, sin ningún importe inventado; y abrir un pedido corriente sin promoción y verificar que el aviso **no** aparece.

**Acceptance Scenarios**:

1. **Given** un pedido con líneas no anuladas cuya suma de importes de lista es $ 0, **When** abro su detalle, **Then** veo el Total y el aviso "Esta orden no tiene el detalle de precios por ítem", sin ceros ni importes inventados por línea.
2. **Given** un pedido corriente sin ninguna promoción aplicada (y por tanto sin descuento por línea), **When** abro su detalle, **Then** veo el desglose completo y **no** aparece el aviso "Esta orden no tiene el detalle de precios por ítem".
3. **Given** un pedido cuyas líneas están todas anuladas, **When** abro su detalle, **Then** veo las líneas marcadas como anuladas y sin importe cobrable, con Subtotal y Total en $ 0 **sin** el aviso de falta de detalle — el $ 0 es el valor real, no un hueco de datos, y la lista no aparece vacía.
4. **Given** cualquier pedido con campos opcionales vacíos (sin notas, sin referencias, sin nombre de cliente), **When** abro su detalle, **Then** esos campos **no se renderizan** — en ninguna parte de la pantalla aparece "null", "undefined" ni un guion de relleno.

---

### User Story 4 - Llamar al cliente "Cliente" (Priority: P3)

Como usuario de cualquiera de los tres roles, veo el nombre de la persona del pedido bajo la etiqueta "Cliente", que es correcta para los tres tipos de pedido, en vez de "Comensal", que solo es correcta en los de mesa.

**Why this priority**: es el cambio de menor esfuerzo y menor riesgo de toda la spec, y no bloquea nada. Va aparte porque es un cambio de lenguaje de producto, no de información: merece quedar registrado como decisión y no esconderse dentro de otra historia.

**Independent Test**: abrir el detalle de un pedido de mesa, uno para llevar y uno a domicilio, y verificar que en los tres la etiqueta dice "Cliente".

**Acceptance Scenarios**:

1. **Given** un pedido de cualquier tipo, **When** abro su detalle, **Then** el nombre de la persona aparece identificado con la etiqueta "Cliente" y en ninguna parte de la pantalla aparece la palabra "Comensal".

---

### Edge Cases

- **Pedido a domicilio con datos de entrega parciales** (solo dirección y teléfono): los campos vacíos se omiten **tanto en la tarjeta como en el texto copiado**, sin dejar líneas en blanco ni etiquetas huérfanas.
- **Portapapeles no disponible** (navegador antiguo, contexto no seguro, permiso denegado): la acción falla con un aviso legible y la pantalla sigue operativa; los datos permanecen visibles para copiarlos a mano.
- **Pedido legacy sin desglose por línea**: el caso real es **mucho** más estrecho de lo que el brief supone. La cantidad y el precio unitario existen en todos los pedidos; lo que falta en el histórico es el **descuento por línea**. El aviso "Esta orden no tiene el detalle de precios por ítem" se reserva para el único caso que el modelo puede producir: un pedido con líneas no anuladas cuya suma de importes de lista es `$ 0` (Q6). **No** se dispara por la ausencia de descuento, ni con todas las líneas anuladas, ni sin líneas. Ver FR-018.
- **Pedido con varias promociones aplicadas a la vez**: el descuento guardado es un agregado y la lista de promociones puede traer más de una entrada. Ver FR-010.
- **Pedido con ítems anulados**: un ítem anulado no se cobra. El desglose no puede sumarlo al subtotal ni al total, **y sí se muestra**, marcado como anulado y sin importe cobrable (Q7), para que la suma de lo visible cuadre con el Subtotal y la anulación quede trazable. Ver FR-019 y FR-019a.
- **Pedido de mesa cobrado dentro de una cuenta unificada con otros pedidos**: la factura cubre varios pedidos y el descuento no quedó en este pedido (quedó en `0`). Se muestra el desglose propio del pedido más el aviso de que la factura agrupa varios pedidos, y el Total del pedido **no** se presenta como el total facturado (FR-024a).
- **Pedido cancelado dentro de una mesa que luego se cobró**: el pedido conserva su vínculo con la sesión pero nunca entró en ninguna factura. Se muestra su desglose con los valores originales y la etiqueta "Cancelada", **sin** el aviso de cuenta unificada y **sin** el aviso de pedido sin cobrar (FR-024a, FR-023).
- **Pedido aún no cobrado con promoción vigente**: el descuento todavía no está guardado. Se muestra `Subtotal + Envío` sin fila de descuento, con el aviso de que el descuento se fija al cobrar (FR-023).
- **Pedido con combos**: las líneas de un combo comparten el combo que las originó y su ahorro no se registra como descuento por línea. El desglose debe sumar sus importes como cualquier otra línea, sin presentar un descuento por línea que no existe.

## Requirements *(mandatory)*

### Functional Requirements

**A. Desglose por línea**

- **FR-001**: El sistema MUST mostrar, en cada línea de producto del Detalle de Orden, la **cantidad**, el **precio unitario guardado** y el **importe de la línea**.
- **FR-002**: El importe de la línea MUST ser el importe **de lista** de la línea (`precio unitario guardado × cantidad + adicionales por línea`), tenga o no la línea un descuento guardado. El descuento MUST NOT aplicarse en la línea: vive únicamente en la fila de descuento del resumen (Q5). Rationale: así la suma de las líneas visibles es exactamente el Subtotal mostrado, que es también el subtotal de la factura, y el descuento tiene una sola fuente en la pantalla.
- **FR-003**: El importe de la línea MUST incluir los adicionales que se cobran una vez por línea. Calcularlo como `precio unitario × cantidad` a secas está prohibido: subcobraría los adicionales de las líneas del Menú QR.
- **FR-004**: El precio unitario mostrado en la línea MUST ser el **de lista**; el sistema MUST NOT mostrar en la línea el precio unitario con descuento guardado (Q5). Cuando la línea tenga adicionales cobrados una vez por línea, el sistema MUST dejar visible ese monto o indicar que el importe lo incluye, de modo que la multiplicación que el usuario hace mentalmente (`unitario × cantidad`) no parezca contradecir el importe mostrado.

**B. Bloque de resumen financiero**

- **FR-005**: El sistema MUST mostrar un bloque de resumen con el **Subtotal** (suma de los importes de lista de las líneas, FR-002), el **Descuento**, el **Envío** —rotulado "Domicilio" en pantalla, la etiqueta que ya usan las demás superficies de cobro— y el **Total**. La suma de los importes de línea visibles MUST ser exactamente igual al Subtotal mostrado.
- **FR-006**: El sistema MUST mostrar la fila de **Descuento solo si el descuento es mayor que $ 0**.
- **FR-007**: El sistema MUST mostrar la fila de **Envío (rotulada "Domicilio") solo si el costo de envío es mayor que $ 0**.
- **FR-008**: El Total MUST ser `Subtotal − Descuento + Envío`, nunca negativo.
- **FR-009**: La fila de descuento MUST mostrar el **nombre de la promoción** que lo originó, con el importe en negativo; y MUST usar la etiqueta "Descuento" cuando no haya nombre registrado.
- **FR-010**: Cuando el descuento provenga de **más de una promoción**, el sistema MUST mostrar una sola fila de descuento con el agregado, etiquetada con el nombre de la promoción cuando hay exactamente una, y con la etiqueta "Descuento" cuando hay varias. Rationale: el importe guardado es un agregado; repartirlo entre promociones para pintar una fila por cada una sería recalcular.
- **FR-011**: El sistema MUST exponer el descuento guardado del pedido y la lista de promociones aplicadas (nombre y monto) en la respuesta de consulta de un pedido. Hoy ambos están persistidos pero no viajan: es el único dato que esta spec necesita publicar.

**C. Encabezado y etiquetado**

- **FR-012**: El encabezado del detalle MUST identificar el **tipo de pedido**: la mesa cuando es de mesa, "Para llevar" cuando es para llevar y "Domicilio" cuando es a domicilio.
- **FR-013**: El sistema MUST sustituir la etiqueta "Comensal" por **"Cliente"** en toda la interfaz del Detalle de Orden.
- **FR-014**: El sistema MUST conservar el estado del pedido visible en el encabezado, incluido el estado "Cancelada", junto al desglose con los valores originales.

**D. Bloque "Datos de entrega" (solo domicilios)**

- **FR-015**: El sistema MUST mostrar un bloque "Datos de entrega" **únicamente en pedidos a domicilio**, con cuatro campos tomados de datos ya existentes (Q1): **nombre de quien recibe** = nombre del cliente del pedido, **teléfono** = teléfono de entrega, **dirección** = dirección de entrega, **referencias o notas de entrega** = nota general del pedido.
- **FR-015a**: El bloque "Datos de entrega" MUST NOT exigir ni crear campos de datos nuevos: los cuatro se leen de lo ya persistido. Un pedido a domicilio al que le falte alguno de los cuatro MUST seguir mostrando los demás (FR-020).
- **FR-016**: El sistema MUST ofrecer una acción "Copiar datos" junto al encabezado del bloque "Datos de entrega" que copie al portapapeles un texto plano legible con los campos diligenciados, un campo por línea, con su etiqueta.
- **FR-017**: Tras un copiado exitoso el sistema MUST mostrar la confirmación **"Datos de envío copiados al portapapeles"**; y ante un fallo del portapapeles MUST mostrar un aviso de error legible sin dejar la pantalla inoperante.

**E. Integridad de lo mostrado**

- **FR-018**: El sistema MUST mostrar el Total junto al aviso **"Esta orden no tiene el detalle de precios por ítem"** cuando, y solo cuando, el pedido tenga **al menos una línea no anulada** y la **suma de los importes de lista de esas líneas sea $ 0** (Q6). En ese caso MUST omitir los importes por línea y MUST NOT inventar precios en $ 0. Precisiones de la condición, todas verificables:
  - El aviso MUST NOT aparecer por la ausencia de descuento por línea, que es el caso normal de la mayoría de los pedidos.
  - El aviso MUST NOT aparecer en un pedido cuyas líneas estén **todas anuladas**: ahí el Subtotal es $ 0 legítimamente (FR-019) y el dato no falta.
  - El aviso MUST NOT aparecer en un pedido sin ninguna línea.
- **FR-019**: El subtotal y el total MUST excluir los ítems anulados: un ítem anulado no se cobra.
- **FR-019a**: Los ítems anulados MUST seguir visibles en la lista de productos, marcados de forma inequívoca como anulados y **sin importe cobrable** (sin importe, o con el importe tachado y señalado como excluido), de modo que la suma de los importes visibles siga siendo exactamente el Subtotal (FR-005, SC-007) y la anulación quede trazable para quien audita (Q7). El sistema MUST NOT ocultarlos ni MUST NOT incluirlos en ninguna suma.
- **FR-020**: El sistema MUST NOT renderizar los campos opcionales vacíos, y MUST NOT mostrar nunca "null", "undefined" ni un guion de relleno en su lugar.
- **FR-021**: Todos los importes MUST usar el formato monetario único del producto: pesos colombianos, sin decimales, punto como separador de miles, espacio tras el símbolo (`$ 14.000`).
- **FR-022**: Los importes mostrados MUST ser los **guardados** con el pedido y MUST NOT recalcularse contra el catálogo de precios vigente ni contra las promociones vigentes al momento de la consulta.
- **FR-023**: En un pedido **aún no cobrado**, el sistema MUST mostrar `Total = Subtotal + Envío` **sin fila de descuento**, acompañado del aviso literal **"El descuento se calcula al cobrar; este total aún puede cambiar"** (Q3, texto fijado en Q8). El sistema MUST NOT consultar el descuento vigente del motor de cobro para esta pantalla, ni siquiera marcándolo como estimado.
- **FR-024**: Cuando exista una factura que cubra **solo este pedido**, el desglose mostrado (subtotal, descuento, envío y total) MUST leerse **de esa factura**, de modo que el Total coincida exactamente con el del módulo de Ventas por construcción (Q2). **Desempate con FR-008**: si esa factura tuviera impuesto o propina distintos de cero, prevalece FR-024 —el Total mostrado es el de la factura— y FR-008 se entiende como invariante del desglose **propio del pedido**, no de la factura. Hoy ningún camino de escritura produce ese caso; medirlo es requisito previo a implementar el resumen, y si aparece, qué se muestra en esos pedidos es una decisión de negocio nueva que se registra antes de tocar la pantalla.
- **FR-024a**: Cuando la factura del pedido **agrupe varios pedidos** (cuenta unificada de mesa), el sistema MUST mostrar el desglose propio del pedido **y** el aviso literal **"Este pedido se cobró junto con otros en una cuenta unificada; el total facturado está en Ventas"** (texto fijado en Q8). En ese caso el sistema MUST NOT presentar el Total del pedido como el total facturado. Este aviso MUST NOT aparecer en un pedido **cancelado** que no se cobró, aunque su mesa se haya cerrado con factura: ese pedido no entró en ninguna factura y decir que "se cobró junto con otros" sería afirmar algo falso (RN-005).
- **FR-024b**: El sistema MUST ser capaz de distinguir los tres casos de un pedido —sin factura, con factura propia, con factura que agrupa varios pedidos— para elegir entre FR-023, FR-024 y FR-024a. Esa distinción MUST resolverse en el servidor y viajar en la respuesta de consulta del pedido: deducirla en el navegador exigiría recalcular, que es lo que RN-001 prohíbe.

**F. Aislamiento**

- **FR-025**: Un usuario MUST poder consultar únicamente los pedidos de su propio tenant; un intento de acceso cruzado, por interfaz o por API, MUST responder "no encontrado" (HTTP 404) y MUST NOT revelar la existencia del pedido. Este requisito se verifica como **prueba de regresión** del aislamiento ya existente.

### Key Entities

- **Pedido**: lo que se consulta. Aporta el tipo (mesa / para llevar / domicilio), el estado, el nombre del cliente, la nota, el costo de envío, la dirección y el teléfono de entrega, el **descuento agregado congelado en el cobro** y la **lista de promociones aplicadas** (nombre y monto de cada una).
- **Línea de pedido**: un producto cobrado. Aporta cantidad, precio unitario congelado, total de adicionales por línea, importe de lista de la línea y, cuando una promoción aplicó, precio unitario e importe ya descontados — todos congelados al confirmar el pedido.
- **Promoción aplicada**: entrada del histórico del pedido, con el nombre con que la promoción se llamaba **en el momento del cobro** y el monto que aportó al descuento. Es la fuente de la etiqueta de la fila de descuento; no se consulta la promoción vigente.
- **Factura (Venta)**: el documento del cobro, con su propio subtotal, descuento, costo de envío y total. Cuando cubre **solo este pedido** es la **fuente** del desglose mostrado (FR-024); cuando **agrupa varios pedidos** no se usa como fuente y solo origina el aviso de FR-024a.

## Reglas de Negocio

- **RN-001 — Inmutabilidad histórica**: los importes mostrados son los guardados al crear/cobrar el pedido. Nunca se recalculan con el catálogo ni con las promociones vigentes.
- **RN-002 — Formato monetario único**: COP, sin decimales, punto de miles, espacio tras el símbolo. Es el formato que ya usa el producto; esta spec no introduce otro.
- **RN-003 — Limpieza de nulos**: lo que está vacío no se pinta. Queda prohibido "null", "undefined" y el guion de relleno, tanto en pantalla como en el texto copiado.
- **RN-004 — Condicionamiento de filas**: la fila de descuento existe solo si el descuento es > $ 0; la de envío, solo si el envío es > $ 0.
- **RN-005 — Honestidad sobre huecos**: ante un dato que no existe, el sistema lo dice. No rellena con ceros.
- **RN-006 — Aislamiento multitenant**: ningún usuario alcanza un pedido de otro tenant; el cruce responde "no encontrado".
- **RN-007 — Una sola pantalla, tres roles**: el Detalle de Orden es un único artefacto compartido por Administración, Caja y Mesero, y los tres ven exactamente el mismo contenido, importes incluidos (decidido en Q4). Cualquier diferencia de contenido por rol sería una funcionalidad nueva y necesita su propia spec.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un cajero responde "¿por cuánto se cobró este pedido y por qué?" **sin abandonar el Detalle de Orden**, en menos de 10 segundos desde que abre la pantalla. Hoy ese recorrido exige al menos dos pantallas adicionales.
- **SC-002**: El 100 % de los pedidos con importes guardados muestran un Total que coincide con el total facturado, verificado sobre una muestra que incluya al menos un pedido de mesa, uno para llevar y uno a domicilio con envío.
- **SC-003**: Un cajero entrega los datos de entrega completos a un mensajero **con una sola acción** y **cero transcripción manual**, frente a los cuatro campos que hoy se copian a mano.
- **SC-004**: En una revisión de 20 pedidos del histórico (incluidos los anteriores al desglose por línea y los de datos parciales), **cero** pantallas muestran "null", "undefined", un guion de relleno o un importe en $ 0 inventado.
- **SC-005**: La palabra "Comensal" no aparece en ninguna parte del Detalle de Orden.
- **SC-006**: Un intento de consulta cruzada entre tenants responde "no encontrado" en el 100 % de los casos probados, por interfaz y por API.
- **SC-007**: En el 100 % de los pedidos con importes guardados, sumar a mano los importes de línea visibles da exactamente el Subtotal mostrado, y `Subtotal − Descuento + Envío` da exactamente el Total mostrado — verificado sobre una muestra que incluya al menos un pedido con descuento por promoción, uno con adicionales por línea y uno con combo.

## Trazabilidad de los criterios de aceptación del brief

| Escenario del brief | Dónde queda | Estado |
|---|---|---|
| 1 — Orden de mesa sin descuento | US1 §1, FR-001/FR-005 | Cubierto |
| 2 — Orden con descuento y promoción | US1 §2, FR-006/FR-009 | Cubierto; las líneas van a precio de lista y el descuento solo en el resumen (Q5) |
| 3 — Descuento sin nombre | US1 §3, FR-009 | Cubierto |
| 4 — Orden para llevar | US1 §6, FR-012/FR-015 | Cubierto |
| 5 — Domicilio completo | US2 §1, FR-007/FR-015 | Cubierto, con los 4 campos resueltos por Q1 |
| 6 — Domicilio sin envío ni referencias | US2 §3, FR-007/FR-020 | Cubierto |
| 7 — Precios históricos | US1 §4, FR-022 | Cubierto |
| 8 — Orden previa/legacy | US3 §1–§3, FR-018 | Cubierto, con la condición exacta del aviso fijada en Q6 |
| 9 — Orden cancelada | US1 §5, FR-014 | Cubierto |
| 10 — Consistencia con Ventas | FR-024, FR-024a, FR-024b | Cubierto por construcción cuando la factura es 1:1; con aviso explícito cuando agrupa varios pedidos (Q2) |
| 11 — Etiqueta Cliente | US4 §1, FR-013 | Cubierto |
| 12 — Aislamiento entre tenants | FR-025, SC-006 | Cubierto como regresión |
| 13 — Formato de moneda | FR-021, RN-002 | Cubierto con el formateador existente |
| 14 — Copiar datos de envío | US2 §2, FR-016/FR-017 | Cubierto |

## Impacto sobre Funcionalidades Existentes

- **Detalle de Orden**: cambia su contenido (importes, encabezado, bloque de entrega) y una etiqueta. No cambian su ruta, sus permisos ni su forma de cargarse.
- **Respuesta de consulta de un pedido**: gana dos campos (descuento y promociones aplicadas). Es una **adición**; ninguna pantalla que ya la consume pierde datos ni cambia de comportamiento.
- **Listado de Órdenes**: no cambia. Esta spec no toca la lista ni sus filtros.
- **Terminal de mesas / panel de cobro**: no cambia. Sigue siendo la pantalla autoritativa del cobro en curso; esta spec añade una pantalla de **consulta**, no un segundo lugar donde cobrar.
- **Módulo de Ventas**: no cambia. Deja de ser el único lugar donde ver cuánto se cobró un pedido, pero sigue siendo la fuente de la factura.
- **Rol Mesero**: gana visibilidad del desglose monetario por estar en la misma pantalla, por decisión explícita (Q4). No gana ni pierde acceso: la ruta y su `roleGuard` no cambian, y la terminal de mesas ya le mostraba importes (ver *Usuarios*).

## Impacto sobre Datos Existentes

- **Ninguna migración, de ningún tipo.** Resuelta Q1 reusando el nombre del cliente y la nota del pedido, esta spec **no añade ni modifica ninguna columna**. Todos los datos que muestra ya están persistidos.
- **Ningún relleno retroactivo.** Los pedidos históricos sin descuento por línea se quedan como están; la pantalla los lee tal cual.
- **Ninguna escritura.** La pantalla es de solo lectura: ningún pedido cambia por abrir su detalle ni por copiar sus datos de entrega.

## Decisiones de Compatibilidad

- **Lectura tolerante**: la pantalla debe funcionar frente a pedidos que no traigan los campos nuevos (respuesta de un backend anterior, o pedido histórico): ausencia de dato se trata como "no mostrar", nunca como cero.
- **Adición, no cambio de forma**: los campos que se publican se añaden a la respuesta existente del pedido. No se renombra ni se retira ninguno.
- **Sin recálculo como respaldo**: ante la ausencia de un importe guardado, la respuesta es el aviso de FR-018 — **no** calcular el importe con el catálogo vigente. Un respaldo así convertiría la pantalla de auditoría en una fuente de datos falsos, que es exactamente lo que RN-001 prohíbe.

## Assumptions

- La pantalla es de **solo lectura**: no se edita ningún importe, ni se cobra, ni se reimprime desde aquí.
- El bloque de resumen se muestra en **todos** los tipos de pedido y en todos los estados; solo las filas de descuento y envío son condicionales.
- El texto copiado al portapapeles es **texto plano**, un campo por línea con su etiqueta, en el orden: Cliente, Teléfono, Dirección, Notas — los mismos cuatro orígenes de FR-015. No incluye importes ni el identificador del pedido: su destino es el chat de un mensajero.
- Los tres roles ven exactamente el mismo contenido (RN-007).
- No hay impuestos ni propina que mostrar en el desglose del pedido: el pedido no los modela. Queda explícitamente fuera de alcance.
- "Modal" en el brief se interpreta como la vista de Detalle de Orden ya existente: no se construye un diálogo nuevo ni se cambia la navegación.

## Fuera de Alcance

- Modelar impuestos, propina o recargos en el pedido.
- Editar importes, descuentos o datos de entrega desde el Detalle de Orden.
- Imprimir o exportar el detalle (ya existen superficies de impresión con su propia spec).
- Enviar los datos de entrega directamente a una plataforma de mensajería o integrarse con una: esta spec copia texto al portapapeles, nada más.
- Cambiar el listado de Órdenes, sus columnas o sus filtros.
- Diferenciar el contenido visible por rol, incluido ocultar importes al mesero.
- Relleno retroactivo de descuentos por línea en pedidos históricos.
- **Separar la nota de cocina de las referencias de entrega** en campos distintos del pedido. Resuelta Q1 reusando la nota general, la consecuencia aceptada es que una nota dirigida a cocina aparezca bajo las referencias de entrega. Darle a la entrega su propio campo exige tocar el formulario de creación de domicilios en POS y en Menú QR, y es su propia spec.
- Añadir un campo propio de "nombre de quien recibe" distinto del nombre del cliente.
- Rastrear el histórico de cambios de un pedido (quién cambió qué y cuándo): eso es auditoría de eventos, no desglose económico.

## Decisiones de Diseño Ya Confirmadas *(entrada para la fase de plan, no requisitos)*

Nacen del reconocimiento; se registran para que la fase de plan no las vuelva a investigar:

1. **El desglose por línea se arma con los campos ya guardados y con el auxiliar que ya existe** para el importe de lista de la línea (`unit_price × quantity + addons_total`). No se escribe un cálculo nuevo de importe de línea: duplicarlo es exactamente cómo se vuelven a filtrar los adicionales que ya costaron una corrección. Resuelta Q5, las columnas de **descuento por línea no se usan** en esta pantalla.
2. **El formato monetario se obtiene del formateador compartido y su tubería de plantilla.** No se escribe un formato nuevo.
3. **El copiado reusa el patrón ya probado en el checkout del comensal** (intento de escritura al portapapeles, toast de éxito, toast de error en el fallo) y el servicio de notificaciones ya existente.
4. **Las etiquetas "Para llevar" y "Domicilio" se toman del artefacto de presentación del tipo de pedido ya existente**, el mismo que usan los filtros del listado.
5. **El trabajo de backend es publicar tres cosas** en la respuesta de consulta del pedido, todas ya persistidas o derivables en el servidor: el **descuento agregado** del pedido, la **lista de promociones aplicadas** (nombre y monto) y el **estado de facturación** que FR-024b necesita (sin factura / factura propia / factura que agrupa varios pedidos, con el desglose de la factura cuando es propia). Todo lo demás ya viaja. **No se crea ninguna columna.**
6. **El aislamiento no se construye: se prueba.** La verificación es una prueba de regresión, no una funcionalidad.
7. **El bloque de entrega no tiene datos propios**: lee el nombre del cliente, el teléfono y la dirección de entrega, y la nota del pedido (Q1). Ningún formulario de creación cambia.
8. **La elección entre leer la factura y leer el pedido es del servidor** (FR-024b). La pantalla recibe un desglose ya decidido más la señal de qué caso es; no implementa la bifurcación en el navegador.
