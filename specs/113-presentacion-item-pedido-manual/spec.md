# Feature Specification: Mostrar presentación elegida en la línea del ítem de la orden manual

**Feature Branch**: `113-presentacion-item-pedido-manual`

**Created**: 2026-10-12

**Status**: Draft

**Input**: User description: "cuando agrego un producto al carrito desde una orden manual, en el detalle del pedido, no esta mostrando la presentacion de granizado escogido en la linea del item, quiero que lo agregues tambien"

## Clarifications

### Session 2026-10-12

- Q: Más allá del carrito donde se arma una orden nueva ("Nueva orden"), ¿debe mostrarse también la presentación elegida al agregar productos a una orden que ya fue creada (por ejemplo, agregar ítems a una mesa con pedido ya enviado)? → A: También en órdenes ya creadas, siempre que esa vista reutilice el mismo componente de línea de ítem que el carrito de orden nueva.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ver la presentación elegida al agregar un producto a la orden manual (Priority: P1)

Un cajero o mesero está creando una orden manual (mesa, para llevar o domicilio) desde la terminal del POS. Selecciona un producto que requiere elegir una presentación obligatoria (por ejemplo, un granizado con tamaños 8 oz, 12 oz, 16 oz), elige una de las opciones y lo agrega al carrito. Al revisar el detalle del pedido, necesita poder identificar de inmediato qué presentación quedó registrada para ese ítem, sin tener que abrir el editor del producto.

**Why this priority**: Sin esta información visible, el cajero no puede verificar ni comunicar al cliente o a cocina/barra qué presentación se va a preparar, lo que genera errores de despacho y reclamos. Es el problema concreto reportado y bloquea la confianza en el flujo de creación de órdenes manuales.

**Independent Test**: Puede probarse agregando al carrito de una orden manual un producto con presentaciones (p. ej. un granizado), y verificando que la línea del ítem en el panel "Nueva orden" / detalle del pedido muestre el nombre de la presentación seleccionada junto al producto.

**Acceptance Scenarios**:

1. **Given** un producto con presentaciones obligatorias (8 oz, 12 oz, 16 oz) y el cajero elige "12 oz", **When** el producto se agrega al carrito de la orden manual, **Then** la línea del ítem en el detalle del pedido muestra el nombre del producto junto con el texto de la presentación elegida ("12 oz").
2. **Given** un ítem ya agregado al carrito con una presentación visible en su línea, **When** el cajero edita el ítem y cambia la presentación a otra opción (p. ej. de "12 oz" a "16 oz"), **Then** la línea del ítem se actualiza para mostrar la nueva presentación elegida.
3. **Given** un producto que no tiene presentaciones configuradas (producto simple), **When** se agrega al carrito de la orden manual, **Then** la línea del ítem se muestra igual que hoy, sin ningún texto de presentación ni espacio vacío.
4. **Given** el mismo producto agregado dos veces con presentaciones distintas (p. ej. "8 oz" y "12 oz"), **When** se revisa el detalle del pedido, **Then** cada presentación aparece como una línea de ítem independiente, cada una mostrando su propia presentación.
5. **Given** una orden que ya fue creada y enviada (por ejemplo, una mesa con pedido abierto), **When** el mesero agrega un nuevo producto con presentación a esa orden existente, **Then** la línea del nuevo ítem en el detalle de esa orden muestra también la presentación elegida, igual que en el carrito de una orden nueva.

---

### Edge Cases

- ¿Qué pasa si el producto tiene presentación obligatoria pero, por algún motivo, el ítem del carrito no tiene una presentación registrada (dato faltante)? El sistema no debe mostrar texto roto ni "undefined"; debe omitir el texto de presentación en ese caso.
- ¿Cómo se muestra el nombre de la presentación cuando es largo? Debe mostrarse de forma legible dentro de la línea del ítem sin romper el diseño del panel (truncando o ajustando el texto según sea necesario), siguiendo el mismo tratamiento visual que ya usa el panel para nombres de producto largos.
- Si el ítem tiene además adicionales/toppings o instrucciones especiales, la presentación debe distinguirse claramente del producto y no confundirse con esos otros datos.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema DEBE mostrar el nombre de la presentación seleccionada junto al nombre del producto en la línea del ítem, dentro del detalle/panel de la orden manual que se está creando.
- **FR-002**: El sistema DEBE aplicar esta visualización a todos los tipos de orden manual soportados por la terminal (mesa, para llevar, domicilio).
- **FR-003**: Cuando el producto agregado no tiene presentaciones configuradas, el sistema NO DEBE mostrar ningún texto de presentación ni dejar espacios vacíos en la línea del ítem.
- **FR-004**: Si el usuario edita un ítem ya agregado y cambia la presentación seleccionada, el sistema DEBE actualizar el texto de presentación mostrado en la línea del ítem para reflejar la nueva selección.
- **FR-005**: Cuando el mismo producto se agrega con presentaciones distintas, el sistema DEBE listarlas como líneas de ítem independientes, cada una mostrando su propia presentación.
- **FR-006**: El sistema DEBE mostrar el texto de la presentación de forma legible (sin truncarse de manera que resulte ilegible ni romper el diseño del panel) incluso cuando el nombre de la presentación sea largo.
- **FR-007**: El sistema DEBE mostrar también la presentación elegida en la línea del ítem cuando se agregan productos a una orden que ya fue creada previamente (por ejemplo, al agregar ítems a una mesa con pedido ya enviado), siempre que esa vista reutilice el mismo componente de línea de ítem que el carrito de orden nueva.

### Key Entities

- **Ítem del pedido (línea del carrito)**: Representa un producto agregado a una orden manual; ya almacena la presentación/variante elegida al momento de agregarse (el precio mostrado ya refleja esa elección), pero actualmente esa presentación no se muestra como texto en la línea del ítem.
- **Presentación (variante del producto)**: Opción de tamaño o formato de un producto (por ejemplo, "8 oz", "12 oz", "16 oz") que el cliente elige de forma obligatoria u opcional antes de agregar el producto al carrito.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100% de los ítems agregados al carrito de una orden manual con una presentación seleccionada muestran el nombre de esa presentación visible en su línea, sin necesidad de abrir el editor del ítem.
- **SC-002**: El cajero puede verificar la presentación de cualquier ítem del pedido con un solo vistazo al panel de la orden, reduciendo a cero los clics necesarios para confirmar ese dato antes de crear el pedido.
- **SC-003**: Los productos sin presentaciones configuradas no sufren ningún cambio visual ni de comportamiento en su línea de ítem tras esta mejora.

## Assumptions

- El alcance de esta mejora es toda vista de línea de ítem que reutilice el mismo componente que el carrito de orden nueva ("Nueva orden") dentro de la terminal del POS, incluyendo el detalle de órdenes ya creadas al agregarles productos; no incluye vistas con formato propio y distinto, como comanda de cocina, tickets impresos o el resumen de "mis pedidos" del cliente.
- La información de la presentación elegida ya se captura y se persiste correctamente al agregar el producto al carrito (se evidencia porque el precio mostrado corresponde a la presentación elegida); el problema reportado es únicamente de visualización/presentación en la línea del ítem, no de captura o cálculo de precio.
- El formato de visualización sugerido es "Nombre del producto — Presentación" o una segunda línea secundaria bajo el nombre del producto, siguiendo el patrón visual ya usado en el sistema para mostrar atributos secundarios de un ítem (por ejemplo, adicionales o notas).
