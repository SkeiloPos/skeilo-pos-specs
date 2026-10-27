# Feature Specification: Vista dedicada para registrar una compra

**Feature Branch**: `140-vista-nueva-compra`

**Created**: 2026-10-26

**Status**: Draft

**Input**: User description: "implementa la vista y el diseño que aparece en design/SkeiloPOS App - Nueva compra.dc.html actualmente para crear una compra se muestra en un modal, con la migracion se debe ser en una nueva vista, y el diseño se debe mostrar exactamente igual al mockup estilo y funcionalidad, si hay alguna funcionalidad diferente o que no existe hoy, me preguntas al seleccion, la busqueda de insumos se realiza en todo el inventario, se puede buscar por codigo o nombre y se seleccionar el respectivo proveedor en el selector"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Registrar una compra ya recibida (Priority: P1)

Como dueño/administrador del negocio, cuando llegan insumos que ya pagué y recibí, quiero registrar esa compra en una vista dedicada (no en una ventana emergente) para que el stock se actualice de inmediato y quede constancia del gasto.

**Why this priority**: Es el flujo más frecuente (compra directa) y el que hoy existe como modal; migrarlo primero da valor inmediato sin romper la operación diaria.

**Independent Test**: Desde Inventario se entra a la nueva vista "Nueva compra", se buscan insumos por código o nombre, se elige proveedor, se completan cantidades y precios, se presiona "Registrar compra" y el stock de cada insumo sube en la cantidad base equivalente.

**Acceptance Scenarios**:

1. **Given** estoy en Inventario, **When** elijo crear una compra, **Then** navego a una vista propia (con su propia URL/ruta) y no a una ventana modal superpuesta.
2. **Given** estoy en la vista de nueva compra, **When** escribo parte del código o del nombre de un insumo en el buscador, **Then** veo una lista de insumos activos de todo el inventario que coinciden, cada uno con su código, nombre y unidad base.
3. **Given** veo resultados de búsqueda, **When** selecciono uno, **Then** se agrega como una línea nueva de la compra (si el proveedor elegido tiene una presentación preferida para ese insumo, se precarga esa unidad de compra y su último costo) y el insumo deja de aparecer en nuevas búsquedas mientras ya esté en la lista.
4. **Given** tengo líneas agregadas sin proveedor todavía, **When** elijo un proveedor en el selector, **Then** cada línea cuya combinación insumo+presentación coincide con una relación activa de ese proveedor actualiza su unidad de compra y costo sugerido; las líneas sin coincidencia conservan lo que ya tenían.
5. **Given** tengo al menos una línea con cantidad mayor a cero, **When** presiono "Registrar compra", **Then** la compra se guarda como recibida, el stock de cada insumo sube según la cantidad convertida a su unidad base, y veo un mensaje de éxito.
6. **Given** acabo de registrar una compra, **When** se confirma el guardado, **Then** vuelvo a Inventario y no puedo volver a registrar la misma compra por error (reintentar no debe duplicar el movimiento de stock).

---

### User Story 2 - Crear una orden de compra pendiente (Priority: P2)

Como administrador, cuando hago un pedido a un proveedor que todavía no ha llegado, quiero dejar constancia del pedido sin que el stock suba todavía, para luego recibirlo (total o parcialmente) cuando llegue.

**Why this priority**: Ya existe hoy como una alternativa dentro del mismo modal (checkbox "Crear como orden de compra"); se conserva como una acción explícita y distinta dentro de la nueva vista.

**Independent Test**: Se completa la misma vista de nueva compra y se presiona "Crear orden de compra" en lugar de "Registrar compra"; el stock no cambia y la orden aparece como pendiente de recepción en el listado de compras existente.

**Acceptance Scenarios**:

1. **Given** completé proveedor y al menos una línea válida (insumo y cantidad mayor a cero), **When** presiono "Crear orden de compra", **Then** se guarda como pendiente, el stock no cambia, y puedo encontrarla luego en el listado de compras para recibirla (total o parcialmente) con el flujo de recepción que ya existe.
2. **Given** no agregué ninguna línea válida, **When** intento crear la orden, **Then** veo un mensaje de validación y la orden no se crea.

---

### User Story 3 - Guardar un borrador incompleto para continuar después (Priority: P3)

Como administrador que está a mitad de capturar una compra larga (muchos insumos) y debo atender otra cosa, quiero guardar lo que ya llevo sin perderlo, aunque todavía falten datos, para continuarlo más tarde sin afectar el stock.

**Why this priority**: Es una mejora de productividad sobre el flujo actual (hoy, si cierras el modal, se pierde todo lo capturado); no es indispensable para el valor principal de la migración, pero evita retrabajo en compras con muchas líneas.

**Independent Test**: Con datos parciales (por ejemplo, proveedor elegido pero una línea sin precio todavía), se presiona "Guardar borrador"; la vista permite guardar sin exigir que todas las líneas estén completas, el stock no cambia, y al volver a entrar se puede continuar con lo guardado.

**Acceptance Scenarios**:

1. **Given** tengo datos incompletos (p. ej. una línea sin costo), **When** presiono "Guardar borrador", **Then** se guarda sin validar que todas las líneas estén completas, el stock no cambia, y veo un mensaje de confirmación.
2. **Given** hay un borrador guardado previamente, **When** vuelvo a la sección de compras, **Then** puedo identificarlo y reabrirlo para continuar editándolo.

---

### Edge Cases

- Buscar un insumo que ya está en la lista de líneas: no debe volver a aparecer en los resultados de búsqueda (para evitar líneas duplicadas del mismo insumo).
- Buscar un texto que no coincide con ningún insumo activo: se muestra un mensaje de "ningún insumo coincide", no un listado vacío sin explicación.
- Cambiar el proveedor cuando ya hay líneas sin ninguna relación configurada para el nuevo proveedor: la línea conserva su unidad de compra y costo actuales en vez de quedar vacía.
- Intentar "Registrar compra" o "Crear orden de compra" sin ninguna línea con cantidad mayor a cero: se bloquea con un mensaje, igual que hoy.
- Pérdida de conexión o error del servidor al guardar: se muestra el error y los datos capturados permanecen en la vista (no se pierden ni se navega fuera).
- Salir de la vista con "Cancelar" o con el botón de volver sin haber guardado: se descarta lo capturado (salvo que el usuario haya usado "Guardar borrador" antes de salir).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST reemplazar la ventana modal actual de "Nueva compra" por una vista propia dentro del módulo de Inventario, con su propia navegación (botón "Volver al inventario") en lugar de superponerse como ventana emergente.
- **FR-002**: La vista MUST reproducir la composición visual del mockup de referencia: encabezado con etiqueta de sección, título y texto de ayuda; buscador de insumos; selector de proveedor; tabla de líneas de compra; resumen de totales; y acciones al final.
- **FR-003**: El buscador de insumos MUST buscar sobre todos los insumos activos del inventario (no limitado a los de un proveedor), coincidiendo tanto por código como por nombre.
- **FR-004**: Los resultados de búsqueda MUST mostrar código, nombre y unidad base de cada insumo, y MUST excluir insumos que ya están agregados como línea de la compra actual.
- **FR-005**: El sistema MUST permitir agregar un insumo de los resultados como una nueva línea de la compra con una sola acción (clic o Enter sobre el primer resultado).
- **FR-006**: El selector de proveedor MUST aplicar a toda la compra (un solo proveedor por compra) y MUST incluir una opción para compra sin proveedor fijo ("compra ocasional"), igual que hoy.
- **FR-007**: Al elegir o cambiar el proveedor, el sistema MUST intentar precargar, para cada línea ya agregada, la unidad de compra (presentación del proveedor o equivalencia genérica) y el costo sugerido según la relación proveedor-insumo activa que corresponda, sin borrar los datos de las líneas que no tengan una relación coincidente.
- **FR-008**: Cada línea de la compra MUST mostrar: código, nombre del insumo (con aviso de stock bajo cuando corresponda), selector de unidad de compra con su equivalencia a la unidad base, precio por unidad de compra, cantidad (con controles de incremento/decremento y mínimo de 1), subtotal calculado, y una acción para quitar la línea.
- **FR-009**: El sistema MUST calcular y mostrar el total de líneas y el total monetario de la compra en tiempo real a medida que se edita.
- **FR-010**: La vista MUST conservar el campo de número/referencia de factura (opcional para el usuario), MUST precargarlo automáticamente con un valor generado al abrir la vista, y MUST permitir que el usuario lo edite antes de guardar.
- **FR-011**: El sistema MUST ofrecer tres acciones de guardado distintas y claramente diferenciadas: "Registrar compra" (compra ya recibida, sube stock de inmediato), "Crear orden de compra" (pedido pendiente, no sube stock, queda disponible para recepción posterior) y "Guardar borrador" (captura incompleta, no sube stock, se conserva para continuar luego).
- **FR-012**: "Registrar compra" y "Crear orden de compra" MUST exigir al menos una línea con insumo y cantidad mayor a cero antes de guardar, mostrando un mensaje de validación si no se cumple.
- **FR-013**: "Guardar borrador" MUST permitir guardar aunque haya líneas incompletas, sin aplicar las validaciones de las otras dos acciones.
- **FR-014**: El sistema MUST reutilizar los mecanismos ya existentes de registro de compra recibida, creación de orden de compra y recepción posterior (parcial o total), sin duplicar ni reemplazar esa lógica de negocio.
- **FR-015**: El sistema MUST evitar que un reintento de guardado (por ejemplo, doble clic o reenvío tras un error) duplique el movimiento de inventario de una misma compra.
- **FR-016**: El sistema MUST mostrar un mensaje de éxito acorde a la acción ejecutada ("Registrar compra", "Crear orden de compra" o "Guardar borrador") y, salvo para "Guardar borrador", MUST devolver al usuario a Inventario tras guardar.
- **FR-017**: Los borradores guardados con "Guardar borrador" MUST quedar identificables y accesibles para que el usuario pueda reabrirlos y continuar editándolos más tarde.

### Key Entities *(include if feature involves data)*

- **Compra (Purchase)**: Registro de una compra de insumos a un proveedor (o sin proveedor fijo). Tiene un estado que distingue si ya subió el stock (recibida), si está pendiente de recepción (orden) o si es un borrador incompleto. Incluye número/referencia de factura, proveedor, fecha y el total.
- **Línea de compra (Purchase line)**: Un insumo dentro de una compra, con su unidad de compra (presentación del proveedor o conversión genérica), cantidad, precio por unidad de compra y subtotal.
- **Insumo (Inventory item)**: Producto del inventario que puede comprarse; tiene código, nombre, unidad base y stock actual.
- **Relación proveedor-insumo**: Presentación de compra preferida y costo más reciente que un proveedor ofrece para un insumo determinado; se usa para precargar unidad de compra y costo al elegir proveedor.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un usuario puede completar y registrar una compra de 5 insumos en menos de 2 minutos desde que entra a la nueva vista.
- **SC-002**: El 100% de las compras registradas como "recibidas" reflejan el stock actualizado de cada insumo inmediatamente después de guardar.
- **SC-003**: El 0% de los reintentos de guardado (por error de red o doble clic) generan una duplicación del movimiento de stock.
- **SC-004**: Las órdenes de compra y los borradores creados desde la nueva vista nunca modifican el stock disponible hasta que se reciben explícitamente.
- **SC-005**: La vista de nueva compra reproduce visualmente la composición y el orden de los elementos del mockup de referencia (encabezado, buscador, proveedor, tabla de líneas, totales y acciones) sin elementos faltantes ni fuera de lugar.

## Assumptions

- La búsqueda de insumos y el selector de proveedor funcionan como lo describió el usuario: búsqueda global por código o nombre en todo el inventario, y un único proveedor seleccionable por compra (igual que hoy); esto coincide con lo mostrado en el mockup, así que no se marca como duda.
- "Crear orden de compra" reutiliza el mismo mecanismo de "orden pendiente, sin alta de stock" que ya existe hoy (el que hoy se activa con el checkbox "Crear como orden de compra"); no se introduce un estado nuevo en el sistema para esto.
- "Guardar borrador" reutiliza ese mismo mecanismo de "sin alta de stock", pero sin las validaciones de líneas completas que sí aplican a "Registrar compra" y "Crear orden de compra"; no se asume una tabla ni un estado de datos distinto a los que ya diferencian "recibida" de "pendiente" en el sistema, salvo que el guardado deba aceptar líneas incompletas.
- La selección de la unidad de compra por línea puede presentarse en la nueva vista como un único selector combinado (presentaciones del proveedor + conversiones genéricas de unidad), igual que en el mockup, aunque hoy se muestren como dos selectores separados; esto es un cambio de presentación visual, no de datos ni de reglas de negocio.
- El listado y la recepción (total o parcial) de órdenes de compra, así como la anulación de compras ya recibidas, siguen funcionando donde ya existen hoy; esta migración no rediseña esas pantallas, solo la creación de una compra nueva.
- La vista de "Sugerido de compra" (generación masiva de órdenes a partir de insumos bajo stock mínimo) que aparece en el mismo mockup queda fuera del alcance de esta migración; se migra únicamente la creación manual de una compra ("Nueva compra").
