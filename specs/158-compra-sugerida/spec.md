# Feature Specification: Compra Sugerida de Insumos

**Feature Branch**: `[158-compra-sugerida]`

**Created**: 2026-11-15

**Status**: Draft

**Input**: User description: "Como administrador del tenant, quiero una opción \"generar compra sugerida\" para ver en una sola pantalla los insumos que están en el mínimo o por debajo, con su proveedor preferido, y ajustar cantidades y generar las órdenes de compra por proveedor en un solo paso."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ver el sugerido de insumos bajo mínimo (Priority: P1)

Como administrador del tenant, al abrir la compra sugerida quiero ver en una sola pantalla
todos los insumos activos de mi comercio y sucursal cuyo stock está en el mínimo o por
debajo (incluyendo stock negativo), cada uno con su proveedor preferido, la unidad de
compra, el precio, la cantidad sugerida y la equivalencia en unidad de inventario, para
saber de inmediato qué necesito reponer sin tener que buscar insumo por insumo.

**Why this priority**: Sin esta visibilidad consolidada no existe la funcionalidad; es el
punto de entrada de todo el flujo y ya aporta valor por sí sola (saber qué comprar), aunque
el usuario no generara ninguna orden.

**Independent Test**: Se puede probar abriendo la pantalla de compra sugerida con un
conjunto de insumos conocido (algunos bajo mínimo con proveedor, uno bajo mínimo sin
proveedor, y verificando el caso sin insumos bajo mínimo) y comprobando que el listado, las
marcas iniciales, los avisos y los contadores de resumen se muestran correctamente, sin
necesidad de llegar a generar ninguna orden.

**Acceptance Scenarios**:

1. **Given** ALMENDRAS tiene stock 10 g, mínimo 500 g y proveedor preferido AGRO SUR con
   presentación "Bolsa x 500 g" a $8.000, **When** el administrador abre el sugerido de
   compra, **Then** ve a ALMENDRAS marcado, con AGRO SUR como proveedor, cantidad 1,
   la equivalencia "= 500 g al inventario" y subtotal $8.000.
2. **Given** AGUA BOLSA X 300 ML no tiene proveedor configurado, **When** el administrador
   abre el sugerido, **Then** la fila aparece desmarcada, con el aviso "Sin proveedor
   configurado. Elige uno.", el selector de unidad deshabilitado y el subtotal vacío, y la
   fila no se puede marcar hasta elegir proveedor, unidad y un precio mayor a 0.
3. **Given** ningún insumo del comercio y sucursal tiene stock menor o igual al mínimo,
   **When** el administrador abre el sugerido, **Then** ve el mensaje "No hay insumos bajo
   mínimo" y el botón de generar órdenes está deshabilitado.

---

### User Story 2 - Generar órdenes de compra agrupadas por proveedor (Priority: P1)

Como administrador del tenant, quiero generar en un solo paso una orden de compra en
borrador por cada proveedor distinto entre los insumos que dejé seleccionados, para no
tener que crear cada orden manualmente insumo por insumo.

**Why this priority**: Es el resultado final que justifica la pantalla completa: convertir
la visibilidad de insumos bajo mínimo en órdenes de compra accionables. Sin esta capacidad
la pantalla sería solo un reporte de solo lectura.

**Independent Test**: Con varios insumos ya seleccionados y repartidos entre distintos
proveedores (incluyendo un caso con datos inválidos y un caso de fallo simulado al crear
una orden), se puede probar presionando "Generar órdenes de compra" y verificando que se
crean (o no se crean, según el caso) las órdenes esperadas, todo sin depender de la lógica
de ajuste de cantidades de la Historia 3.

**Acceptance Scenarios**:

1. **Given** el administrador tiene 3 insumos seleccionados de 3 proveedores distintos,
   **When** presiona "Generar órdenes de compra", **Then** se crean 3 órdenes en estado
   borrador, una por proveedor, cada una con sus insumos, cantidades y precios, y el
   administrador ve la confirmación con un enlace a cada orden creada.
2. **Given** un insumo seleccionado tiene precio 0 o cantidad menor a 1, **When** el
   administrador presiona "Generar órdenes de compra", **Then** no se crea ninguna orden y
   la fila con el error queda resaltada junto con su mensaje de error.
3. **Given** el administrador tiene insumos seleccionados de varios proveedores y ocurre un
   error al crear una de las órdenes, **When** se ejecuta la generación, **Then** no se
   crea ninguna orden, se muestra un mensaje de error, y los ajustes que el administrador
   había hecho en pantalla se conservan.

---

### User Story 3 - Ajustar cantidad y proveedor antes de generar (Priority: P2)

Como administrador del tenant, quiero poder ajustar la cantidad sugerida de cada insumo y
cambiar su proveedor por una alternativa antes de generar las órdenes, para adaptar la
compra a lo que realmente necesito y a las condiciones del proveedor que prefiera en ese
momento.

**Why this priority**: Mejora la precisión y utilidad de la compra sugerida sobre la
Historia 1, pero el flujo ya es viable (aunque menos flexible) generando las órdenes con
los valores por defecto que trae cada insumo.

**Independent Test**: Con un insumo preseleccionado y al menos un proveedor alternativo
configurado, se puede probar subiendo o bajando la cantidad y cambiando el proveedor,
verificando que el subtotal, la equivalencia de unidades y los contadores de resumen
(insumos seleccionados, proveedores, órdenes a generar y total estimado) se recalculan de
inmediato, sin necesidad de llegar a generar ninguna orden.

**Acceptance Scenarios**:

1. **Given** ALMENDRAS está en cantidad 1 a $8.000, **When** el administrador sube la
   cantidad a 6, **Then** el subtotal pasa a $48.000, la equivalencia cambia a "= 3.000 g
   al inventario" y el total estimado de la compra se actualiza.
2. **Given** ALMENDRAS tiene un proveedor alternativo configurado, **When** el
   administrador lo selecciona, **Then** se cargan la unidad de compra y el precio de ese
   proveedor alternativo, la cantidad se conserva, y el subtotal, el contador de
   proveedores y el contador de órdenes a generar se actualizan.

---

### Edge Cases

- ¿Qué pasa si un insumo bajo mínimo tiene configurado un proveedor preferido pero sin
  precio o sin unidad de compra asignada? Se trata igual que "sin proveedor configurado"
  para efectos de selección inicial: abre desmarcado con el aviso correspondiente hasta que
  se complete precio, unidad y proveedor válidos.
- ¿Qué pasa si el stock de un insumo cambia (por ejemplo, por una recepción de mercancía en
  otra pestaña) mientras el administrador tiene la pantalla de sugerido abierta? La pantalla
  no se actualiza en tiempo real; el servidor vuelve a validar existencia, proveedor, precio
  y cantidad en el momento de generar las órdenes, y rechaza la operación completa si algo
  ya no es válido.
- ¿Qué pasa si el administrador reintenta la generación tras un error de red sin saber si la
  petición anterior se procesó? El endpoint reconoce la misma clave de idempotencia y no
  duplica las órdenes ya creadas con esa clave.
- ¿Qué pasa si el administrador escribe manualmente una cantidad menor a 1 o no numérica?
  La interfaz la corrige o la rechaza antes de permitir marcar el insumo como listo para
  generar, y en todo caso el servidor la vuelve a validar al generar.
- ¿Qué pasa si dos insumos seleccionados comparten el mismo proveedor? Ambos se agrupan en
  la misma orden de compra en borrador para ese proveedor, no en órdenes separadas.
- ¿Qué pasa si el usuario no tiene permiso de compras? No puede acceder a la pantalla de
  compra sugerida ni a sus datos.
- ¿Qué pasa si dos administradores generan órdenes al mismo tiempo sobre el mismo insumo
  desde sesiones distintas? Cada generación se valida de forma independiente contra sus
  propias reglas de negocio (proveedor, unidad, precio y cantidad); el sistema no detecta ni
  rechaza conflictos entre sesiones concurrentes de distintos usuarios.

## Clarifications

### Session 2026-11-15

- Q: ¿Cómo debe comportarse la pantalla cuando hay muchos insumos bajo mínimo (por ejemplo, más de 50 o 100 filas) en una sucursal: paginar/virtualizar la lista o mostrarlos todos sin límite? → A: Paginación o scroll virtualizado.
- Q: ¿Con cuántos decimales se deben redondear la equivalencia en unidad de inventario y los montos (subtotal, total estimado) que muestra la pantalla de compra sugerida? → A: Los montos (subtotal de fila y total estimado) se redondean a 2 decimales; la equivalencia en unidad de inventario se muestra con la precisión que ya usa el sistema de insumos/unidades existente, sin una regla de redondeo nueva.
- Q: ¿En qué orden deben aparecer por defecto las filas de insumos bajo mínimo al abrir la pantalla de compra sugerida? → A: Por déficit (stock actual menos stock mínimo) descendente, mostrando primero los casos más críticos.
- Q: Si dos administradores abren la compra sugerida al mismo tiempo y ambos seleccionan el mismo insumo para generar órdenes con proveedores distintos (o el mismo), ¿el sistema debe permitir que ambas generaciones creen sus órdenes de forma independiente, o debe detectar el conflicto y rechazar la segunda? → A: Permitir ambas generaciones de forma independiente; no se valida conflicto entre sesiones concurrentes de distintos usuarios, cada generación solo se valida contra sus propias reglas de negocio (FR-011/FR-012).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST listar, en una sola pantalla, todos los insumos activos del
  comercio y la sucursal del usuario cuyo stock actual sea menor o igual a su stock mínimo,
  incluyendo los insumos con stock negativo, ordenados por defecto de mayor a menor déficit
  (stock mínimo menos stock actual), mostrando primero los casos más críticos.
- **FR-002**: El sistema MUST mostrar, para cada insumo listado, su stock actual, su stock
  mínimo, el proveedor preferido (si existe), la unidad de compra y el precio de ese
  proveedor, la cantidad a comprar, la equivalencia de esa cantidad en unidad de inventario,
  y el subtotal resultante.
- **FR-003**: El sistema MUST abrir cada insumo con cantidad sugerida de 1 en su unidad de
  compra, y MUST permitir al usuario ajustar esa cantidad mediante controles de incremento o
  decremento o escribiéndola directamente, sin permitir valores menores a 1.
- **FR-004**: El sistema MUST preseleccionar el proveedor preferido de cada insumo junto con
  su unidad de compra y su precio vigente, y MUST permitir cambiar a un proveedor
  alternativo configurado para ese insumo, cargando la unidad de compra y el precio de ese
  proveedor alternativo y conservando la cantidad ya ingresada.
- **FR-005**: El sistema MUST marcar como seleccionados, al abrir la pantalla, únicamente
  los insumos que ya tienen un proveedor con unidad de compra y precio mayor a 0; los
  insumos sin esos datos completos MUST abrir desmarcados.
- **FR-006**: El sistema MUST impedir marcar un insumo para generar orden mientras no tenga
  asignado un proveedor, una unidad de compra y un precio mayor a 0, y MUST mostrar el aviso
  "Sin proveedor configurado. Elige uno." en esos casos, dejando el selector de unidad
  deshabilitado y el subtotal vacío.
- **FR-007**: El sistema MUST permitir editar el precio de un insumo dentro de la pantalla
  de compra sugerida sin que ese cambio modifique el precio guardado del proveedor; el
  cambio MUST aplicar únicamente a la orden que se está generando.
- **FR-008**: El sistema MUST agrupar los insumos seleccionados por proveedor y, al
  confirmar la generación, MUST crear exactamente una orden de compra en estado borrador por
  cada proveedor distinto presente entre los insumos seleccionados, con sus insumos,
  cantidades y precios correspondientes.
- **FR-009**: El sistema MUST ejecutar la creación de todas las órdenes de una misma
  generación dentro de una sola transacción: si falla la creación de alguna orden, el
  sistema MUST no crear ninguna de las órdenes de esa generación.
- **FR-010**: El sistema MUST deshabilitar el botón de generar mientras la solicitud está en
  curso y MUST aceptar una clave de idempotencia en la solicitud de generación, de forma que
  reenvíos con la misma clave no produzcan órdenes duplicadas.
- **FR-011**: El sistema MUST recalcular en el servidor, al momento de generar, los
  subtotales de cada línea y el total de cada orden, y MUST validar de nuevo que cada insumo
  seleccionado tenga proveedor, unidad y precio mayor a 0, y cantidad mayor o igual a 1, sin
  confiar en los valores enviados desde la pantalla.
- **FR-012**: El sistema MUST rechazar la generación completa (sin crear ninguna orden)
  cuando algún insumo seleccionado tenga, en el momento de generar, precio 0 o cantidad
  menor a 1, y MUST señalar la fila con el error y su mensaje correspondiente.
- **FR-013**: El sistema MUST no modificar el inventario al generar las órdenes de compra;
  el stock de los insumos solo MUST cambiar cuando la orden de compra correspondiente sea
  recibida.
- **FR-014**: El sistema MUST filtrar toda consulta y operación de esta funcionalidad por el
  comercio y la sucursal del usuario autenticado, y MUST restringir el acceso a la pantalla
  y a sus acciones a los roles que tengan permiso de compras.
- **FR-015**: El sistema MUST mostrar, para cada fila, la conversión de la unidad de compra
  seleccionada a la unidad de inventario del insumo y el costo resultante por unidad de
  inventario, usando la misma precisión que el sistema de insumos/unidades ya emplea para
  esa conversión, sin aplicar una regla de redondeo adicional.
- **FR-016**: El sistema MUST mostrar y actualizar, ante cada cambio en la pantalla, un
  resumen con el número de insumos seleccionados, el número de proveedores distintos entre
  los seleccionados, el número de órdenes que se generarían, y el total estimado de la
  compra, redondeando el subtotal de cada fila y el total estimado a 2 decimales.
- **FR-017**: El sistema MUST mostrar el mensaje "No hay insumos bajo mínimo" y mantener
  deshabilitado el botón de generar cuando ningún insumo activo del comercio y sucursal
  tenga stock menor o igual a su mínimo.
- **FR-018**: El sistema MUST mostrar una confirmación al finalizar la generación exitosa,
  con un enlace a cada una de las órdenes de compra creadas.
- **FR-019**: Cuando la generación falla, el sistema MUST mostrar un mensaje de error y MUST
  conservar en pantalla la selección, las cantidades, los proveedores y los precios que el
  usuario había ajustado.
- **FR-020**: El sistema MUST paginar o virtualizar el listado de insumos bajo mínimo cuando
  el número de filas supere un umbral que mantenga la pantalla responsiva, en lugar de
  renderizar sin límite todas las filas; esta paginación o virtualización MUST conservar la
  selección, las cantidades, los proveedores y los precios ajustados de las filas que ya no
  estén visibles en pantalla.

### Key Entities

- **Insumo**: materia prima o producto de inventario del comercio y sucursal, con stock
  actual, stock mínimo, unidad de inventario y estado activo/inactivo. Es la entidad cuyo
  nivel de stock dispara su aparición en la compra sugerida.
- **Proveedor**: tercero que suministra insumos. Cada insumo puede tener uno o varios
  proveedores asociados, uno de ellos marcado como preferido.
- **Relación Insumo-Proveedor**: vínculo entre un insumo y un proveedor que define la unidad
  de compra, el precio vigente en esa unidad, y si ese proveedor es el preferido para ese
  insumo. Determina los valores con los que cada fila del sugerido abre precargada.
- **Línea de Compra Sugerida**: representación en pantalla de un insumo bajo mínimo junto
  con el estado elegido por el usuario (seleccionado o no, proveedor elegido, cantidad,
  precio editado para esa generación). Es transitoria: existe solo mientras el usuario
  trabaja en la pantalla, hasta que genera las órdenes o la abandona.
- **Orden de Compra**: documento en estado borrador que agrupa una o más líneas de compra
  de un único proveedor, con sus cantidades, precios y el total. Se crea una por proveedor
  en cada generación exitosa; no afecta el inventario hasta que se reciba.
- **Línea de Orden de Compra**: insumo, cantidad en unidad de compra, precio y subtotal
  dentro de una orden de compra ya creada.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un administrador puede identificar todos los insumos bajo mínimo de su
  sucursal, con su proveedor y cantidad sugerida, sin realizar ninguna búsqueda manual por
  insumo.
- **SC-002**: Un administrador puede generar, en una sola acción, las órdenes de compra
  correspondientes a todos los insumos bajo mínimo que decide reponer, en menos de 2 minutos
  desde que abre la pantalla, para un conjunto de hasta 20 insumos y 5 proveedores distintos.
- **SC-003**: El 100% de las generaciones donde algún insumo seleccionado queda sin precio
  válido o cantidad válida terminan sin crear ninguna orden, y el usuario identifica de
  inmediato cuál fila causó el rechazo.
- **SC-004**: El 100% de las generaciones donde ocurre un error al crear alguna de las
  órdenes del grupo terminan sin crear ninguna orden parcial, preservando todos los ajustes
  que el usuario tenía en pantalla.
- **SC-005**: Reenviar la misma solicitud de generación (por ejemplo, por doble clic o
  reintento tras un error de red) nunca produce órdenes de compra duplicadas.
- **SC-006**: Cada cambio de cantidad, proveedor o precio en pantalla se refleja en el
  subtotal de la fila y en los contadores de resumen (insumos seleccionados, proveedores,
  órdenes a generar, total estimado) de forma inmediata, sin recargar la pantalla.

## Assumptions

- La relación insumo-proveedor (proveedor preferido, alternativos, unidad de compra, precio
  y la conversión a unidad de inventario) ya existe como funcionalidad del sistema y es el
  origen de los datos que esta pantalla consume; esta funcionalidad no crea ni modifica esa
  relación, solo la usa y permite editar el precio de forma puntual para la orden generada.
- El concepto de "stock mínimo" por insumo ya existe en el sistema y no es parte del alcance
  de esta funcionalidad definirlo o configurarlo.
- El permiso "compras" referido en las reglas de negocio corresponde al sistema de roles y
  permisos ya existente del producto; esta funcionalidad no introduce un nuevo tipo de
  permiso, solo lo consume para restringir el acceso.
- La clave de idempotencia de la solicitud de generación la genera y envía el cliente (por
  ejemplo, un identificador único por intento de envío); el servidor la usa para reconocer
  reintentos y evitar duplicar órdenes.
- El estado "borrador" de una orden de compra ya existe como parte del ciclo de vida de las
  órdenes de compra (creación → borrador → recepción); esta funcionalidad solo produce
  órdenes en ese estado inicial y no define el resto del ciclo de vida.
- Cuando dos o más insumos seleccionados comparten proveedor, todos se agrupan en una sola
  orden de compra para ese proveedor dentro de la misma generación.
