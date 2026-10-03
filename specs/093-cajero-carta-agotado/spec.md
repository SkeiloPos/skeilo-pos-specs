# Feature Specification: Carta del menú para Cajero con estado Agotado

**Feature Branch**: `093-cajero-carta-agotado`

**Created**: 2026-10-03

**Status**: Draft

**Input**: User description: "Como cajero de un tenant, quiero consultar la carta del menú, ver el detalle de cada producto y marcarlo como agotado o disponible, para evitar que se tomen pedidos de productos que ya no tenemos, sin depender del administrador."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Consultar la carta y marcar productos como agotados (Priority: P1)

Un cajero inicia sesión y encuentra una nueva opción "Carta del menú" en una sección "CATÁLOGO" de su menú lateral. Allí ve, en solo lectura, el listado completo de productos del tenant (nombre, categoría, preparación, estado y disponibilidad), puede buscar por nombre y filtrar por Todos, Disponibles o Agotados, y puede abrir el detalle de cualquier producto para ver su información completa (sin costos, recetas ni inventario). Desde el listado o desde el detalle, el cajero puede activar o desactivar un interruptor "Agotado" para marcar que un producto ya no está disponible, sin necesidad de pedírselo al administrador. Un producto inactivo no puede marcarse como agotado.

**Why this priority**: Es la capacidad mínima que resuelve el problema central descrito: que el cajero pueda actuar por sí mismo cuando se acaba un producto, sin depender del administrador. Sin esto no existe ninguna de las demás funcionalidades.

**Independent Test**: Puede probarse completamente iniciando sesión como Cajero, entrando a "Carta del menú", buscando/filtrando productos, abriendo el detalle de uno y alternando su interruptor "Agotado", verificando que el cambio se refleje con la etiqueta correspondiente y quede registrado con usuario y hora.

**Acceptance Scenarios**:

1. **Given** inicio sesión con rol Cajero, **When** se carga el panel, **Then** veo la sección "CATÁLOGO" con una única opción "Carta del menú" y no veo Categorías, Presentaciones ni Promociones.
2. **Given** estoy en "Carta del menú" con rol Cajero, **When** reviso el listado, **Then** veo nombre, categoría, preparación, estado y disponibilidad de cada producto, puedo buscar por nombre y filtrar por Todos/Disponibles/Agotados, no veo "Nuevo producto" ni acciones de editar o desactivar, y no aparece ningún mensaje de error de permisos.
3. **Given** "Fresa boom" está activo y disponible, **When** activo el interruptor "Agotado" en su fila, **Then** el producto se muestra con la etiqueta "Agotado" y "desde hace unos segundos", veo la confirmación "Fresa boom marcado como agotado", y el cambio queda guardado con mi usuario y la hora.
4. **Given** "Fresa boom" está marcado como agotado, **When** desactivo el interruptor "Agotado", **Then** el producto vuelve a estar disponible y la etiqueta desaparece.
5. **Given** estoy en "Carta del menú", **When** hago clic en una fila o en "Ver detalle", **Then** veo en solo lectura imagen, nombre, descripción, categoría, tipo de preparación, presentaciones con sus precios, estado y disponibilidad; puedo marcar o desmarcar el producto como agotado desde esa vista; y no veo costos, recetas ni datos de inventario.
6. **Given** un producto está inactivo, **When** lo veo en el listado, **Then** aparece con estado "Inactivo" y el interruptor "Agotado" está deshabilitado.
7. **Given** soy Administrador del tenant, **When** estoy en "Carta del menú", **Then** mantengo todas mis acciones actuales y además puedo marcar productos como agotados con el mismo interruptor.

---

### User Story 2 - Evitar pedidos de productos agotados (Priority: P2)

Cuando un producto queda marcado como agotado, ese estado debe reflejarse de inmediato en todos los lugares donde se arman pedidos nuevos: la Terminal de mesas que usa el personal y el menú QR que usan los comensales. El producto sigue siendo visible, pero no se puede agregar a un pedido nuevo. Si un comensal ya tenía el producto en su carrito antes de que se marcara como agotado, al intentar confirmar el pedido el sistema lo rechaza señalando el producto agotado, sin crear ninguna orden y conservando el resto del carrito. Los pedidos que ya existían antes de marcar el producto como agotado no se ven afectados.

**Why this priority**: Es el efecto que realmente entrega el valor de negocio ("evitar que se tomen pedidos de productos que ya no tenemos"). Depende de que el estado Agotado exista (User Story 1), pero es la razón de ser de la funcionalidad.

**Independent Test**: Puede probarse marcando un producto como agotado y verificando, de forma independiente, que (a) no se puede agregar desde la Terminal de mesas, (b) no se puede agregar desde el menú QR, (c) un carrito armado antes del cambio es rechazado al confirmar sin crear la orden, y (d) un pedido pendiente previo con ese producto sigue su flujo normal sin alteraciones.

**Acceptance Scenarios**:

1. **Given** "Fresa boom" está agotado, **When** busco productos en "Nueva orden" (Terminal de mesas), **Then** el producto aparece atenuado con la etiqueta "Agotado" y el botón de agregar al carrito está deshabilitado.
2. **Given** "Fresa boom" está agotado, **When** un comensal abre el menú QR, **Then** ve el producto con la etiqueta "Agotado" y no puede agregarlo al carrito.
3. **Given** un comensal tiene "Fresa boom" en el carrito y un cajero lo marca como agotado, **When** el comensal confirma el pedido, **Then** el sistema rechaza el pedido con un mensaje que nombra el producto agotado, no se crea ninguna orden, y el resto del carrito se conserva.
4. **Given** existe un pedido pendiente que contiene "Fresa boom", **When** el producto se marca como agotado, **Then** el pedido conserva el producto y su flujo normal sin cambios.

---

### User Story 3 - Garantías de seguridad, aislamiento y consistencia (Priority: P3)

Independientemente de la interfaz, el sistema debe hacer cumplir por sí mismo (no solo en la pantalla) las reglas de permisos, de datos visibles y de aislamiento entre tenants, y debe comportarse de forma predecible ante fallas de red o cambios simultáneos sobre el mismo producto.

**Why this priority**: Es una capa de robustez y seguridad que protege el valor entregado por las historias 1 y 2 frente a usos indebidos, fallas de red o condiciones de carrera, pero el sistema ya es funcionalmente útil sin que estos casos estén cubiertos de forma explícita en la interfaz (aunque sí deben cumplirse igual).

**Independent Test**: Puede probarse enviando peticiones directas (sin pasar por la interfaz) para crear/editar/desactivar un producto como Cajero y verificando el rechazo, consultando el detalle de un producto como Cajero y verificando qué datos trae la respuesta, simulando una falla de red al marcar un producto, enviando dos cambios de estado casi simultáneos, e intentando acceder a un producto de otro tenant.

**Acceptance Scenarios**:

1. **Given** soy Cajero, **When** envío directamente una petición para crear, editar o desactivar un producto, **Then** recibo 403 y no se modifica nada.
2. **Given** soy Cajero, **When** consulto un producto por la API, **Then** la respuesta no incluye costo, receta ni datos de inventario.
3. **Given** activo el interruptor "Agotado", **When** la petición falla, **Then** el interruptor vuelve a su estado anterior y veo un mensaje de error indicando que no se pudo guardar.
4. **Given** dos cajeros marcan el mismo producto casi al mismo tiempo, **When** ambas peticiones se procesan, **Then** el estado final corresponde a la última petición recibida y no queda en un estado inconsistente.
5. **Given** soy Cajero del tenant A, **When** intento consultar o modificar un producto del tenant B, **Then** recibo 404.

---

### Edge Cases

- ¿Qué pasa si un producto está inactivo? El interruptor "Agotado" aparece deshabilitado y el estado se muestra como "Inactivo"; no se puede marcar como agotado mientras esté inactivo.
- ¿Qué pasa si se desactiva un producto que ya estaba marcado como agotado? La marca de agotado se conserva sin cambios; "Agotado" y "Activo" son independientes.
- ¿Qué pasa si falla la conexión justo al guardar el cambio de estado? El interruptor regresa visualmente a su valor anterior y se informa que el cambio no se pudo guardar.
- ¿Qué pasa si dos usuarios (cajeros y/o administrador) cambian el estado del mismo producto casi al mismo tiempo? Gana la última petición procesada por el servidor; no debe quedar un estado mixto o corrupto.
- ¿Qué pasa si un comensal confirma un pedido que incluye un producto recién marcado como agotado? El pedido completo se rechaza (no se crea una orden parcial), se identifica el producto agotado en el mensaje, y el carrito del comensal se conserva para que pueda ajustarlo.
- ¿Qué pasa con pedidos que ya existían antes de marcar un producto como agotado? No se tocan ni se recalculan; siguen su flujo normal hasta el final.
- ¿Qué pasa si un Cajero intenta operar sobre un producto de otro tenant (por URL directa o API)? El sistema responde como si el producto no existiera (404), sin distinguir si el producto existe en otro tenant.
- ¿Qué pasa si un Cajero intenta crear, editar o desactivar un producto directamente contra la API, sin usar la interfaz? La petición se rechaza (403) y no se modifica ningún dato.

## Requirements *(mandatory)*

### Functional Requirements

**Acceso y navegación**

- **FR-001**: El sistema MUST mostrar al rol Cajero una sección "CATÁLOGO" en el menú lateral con una única opción, "Carta del menú".
- **FR-002**: El sistema MUST ocultar al rol Cajero las opciones de Categorías, Presentaciones y Promociones.
- **FR-003**: El sistema MUST permitir al rol Administrador conservar el acceso a todas sus opciones actuales de catálogo, sin reducir ninguna.

**Listado de la carta (solo lectura para Cajero)**

- **FR-004**: El sistema MUST mostrar, para cada producto en "Carta del menú", al menos: nombre, categoría, tipo de preparación, estado (Activo/Inactivo) y disponibilidad (Disponible/Agotado).
- **FR-005**: El sistema MUST permitir buscar productos por nombre dentro de "Carta del menú".
- **FR-006**: El sistema MUST permitir filtrar el listado por "Todos", "Disponibles" y "Agotados".
- **FR-007**: El sistema MUST ocultar al rol Cajero cualquier acción de creación ("Nuevo producto"), edición o desactivación de productos en "Carta del menú".
- **FR-008**: El sistema MUST permitir al rol Cajero navegar y usar "Carta del menú" sin mostrar mensajes de error de permisos.

**Estado Agotado**

- **FR-009**: El sistema MUST permitir a los roles Cajero y Administrador marcar y desmarcar un producto como "Agotado" mediante un interruptor, tanto desde el listado como desde el detalle del producto.
- **FR-010**: El sistema MUST tratar "Agotado" como un atributo independiente de "Activo": un producto puede estar activo y agotado a la vez, y cambiar su estado Activo/Inactivo no MUST alterar su marca de Agotado.
- **FR-011**: El sistema MUST impedir marcar como "Agotado" un producto que está inactivo, deshabilitando el interruptor correspondiente mientras el producto permanezca inactivo.
- **FR-012**: El sistema MUST mantener el estado "Agotado" de un producto hasta que un Cajero o un Administrador lo quite explícitamente (sin expiración automática ni dependencia de inventario).
- **FR-013**: El sistema MUST registrar, en cada cambio de estado "Agotado", qué usuario lo realizó y en qué momento, y MUST reflejar ese momento en la interfaz (p. ej. "desde hace unos segundos").
- **FR-014**: El sistema MUST mostrar una confirmación al usuario tras marcar o desmarcar un producto como agotado (p. ej. "Fresa boom marcado como agotado").
- **FR-015**: El sistema MUST revertir visualmente el interruptor a su estado previo y MUST mostrar un mensaje de error cuando la petición para cambiar el estado "Agotado" falle.
- **FR-016**: Cuando dos peticiones de cambio de estado "Agotado" sobre el mismo producto se procesen en cercanía temporal, el sistema MUST dejar como resultado final el de la última petición recibida y MUST evitar que el producto quede en un estado inconsistente.

**Detalle de producto**

- **FR-017**: El sistema MUST mostrar, en la vista de detalle de un producto para el rol Cajero, al menos: imagen, nombre, descripción, categoría, tipo de preparación, presentaciones con sus precios, estado y disponibilidad, todo en solo lectura salvo el interruptor de "Agotado".
- **FR-018**: El sistema MUST ocultar al rol Cajero, en cualquier pantalla de la carta (listado y detalle), los costos, las recetas y los datos de inventario de los productos.

**Efecto del estado Agotado en la operación**

- **FR-019**: El sistema MUST seguir mostrando un producto agotado en la Terminal de mesas y en el menú QR, pero marcado con la etiqueta "Agotado" y visualmente atenuado o diferenciado.
- **FR-020**: El sistema MUST deshabilitar la acción de agregar al pedido/carrito para un producto marcado como agotado, tanto en la Terminal de mesas como en el menú QR.
- **FR-021**: El sistema MUST validar la disponibilidad de cada producto al momento de confirmar un pedido, y MUST rechazar la confirmación completa (sin crear ninguna orden) si el pedido incluye uno o más productos marcados como agotados, identificando en el mensaje el o los productos agotados.
- **FR-022**: El sistema MUST conservar el contenido del carrito del comensal tras un rechazo por producto agotado, de modo que pueda ajustarlo y reintentar sin perder el resto de los productos.
- **FR-023**: El sistema MUST dejar sin cambios los pedidos ya creados cuando un producto incluido en ellos se marque posteriormente como agotado; dichos pedidos MUST continuar su flujo normal.

**API y seguridad**

- **FR-024**: El sistema MUST rechazar con un error de permisos (403) cualquier intento del rol Cajero de crear, editar o desactivar un producto directamente por API, sin aplicar ningún cambio.
- **FR-025**: El sistema MUST excluir costo, receta y datos de inventario de cualquier respuesta de API de producto consultada por el rol Cajero.
- **FR-026**: El sistema MUST aplicar aislamiento por tenant en todas las operaciones de la carta y del estado Agotado, respondiendo con 404 cuando un usuario intente consultar o modificar un producto que no pertenece a su propio tenant.

### Key Entities *(include if feature involves data)*

- **Producto**: Ítem de la carta de un tenant. Atributos relevantes para esta funcionalidad: nombre, descripción, imagen, categoría, tipo de preparación, presentaciones con precio, estado Activo/Inactivo (gestionado por Administrador), y un nuevo estado Agotado/Disponible independiente del anterior. No expone costo, receta ni datos de inventario al rol Cajero.
- **Registro de cambio de disponibilidad**: Traza de cada vez que el estado Agotado de un producto cambia; incluye el producto afectado, el usuario que hizo el cambio, el nuevo valor y el momento en que ocurrió.
- **Usuario (Cajero / Administrador)**: Persona autenticada en el tenant. El Cajero tiene acceso de solo lectura a la carta más la capacidad de cambiar el estado Agotado; el Administrador conserva además la gestión completa de productos.
- **Carrito / Pedido**: Conjunto de productos seleccionados por un comensal o por el personal antes de confirmarse como orden. Se valida contra el estado Agotado de sus productos únicamente en el momento de confirmación; los pedidos ya confirmados no se revalidan.
- **Tenant**: Organización dueña del catálogo; delimita qué productos, usuarios y pedidos son visibles y modificables entre sí.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un cajero puede marcar un producto como agotado (o volver a marcarlo disponible) en menos de 10 segundos desde "Carta del menú", sin intervención del administrador.
- **SC-002**: El 100% de los intentos de confirmar un pedido que incluya un producto marcado como agotado son rechazados antes de crear la orden, identificando el producto en el mensaje.
- **SC-003**: El 100% de los productos marcados como agotados se muestran de forma consistente (atenuados y con la etiqueta "Agotado") tanto en la Terminal de mesas como en el menú QR.
- **SC-004**: El 100% de las pantallas de la carta accesibles al rol Cajero (listado y detalle) omiten costos, recetas y datos de inventario.
- **SC-005**: El 100% de los cambios de estado Agotado quedan asociados a un usuario y una marca de tiempo verificable.
- **SC-006**: El 100% de los intentos de un Cajero de crear, editar o desactivar un producto, o de acceder a un producto de otro tenant, son bloqueados por el sistema (403 o 404 según el caso) sin aplicar ningún cambio.

## Assumptions

- Esta funcionalidad amplía los roles Cajero y Administrador; no modifica el acceso ni el comportamiento de otros roles existentes (por ejemplo, Mesero), que quedan fuera de este alcance salvo que se indique lo contrario en otro spec.
- "Carta del menú" para el Cajero usa el mismo catálogo de productos, categorías, tipos de preparación y presentaciones ya administrados por el Administrador; no se introduce un catálogo paralelo.
- El registro de quién y cuándo cambió el estado Agotado se usa con fines de trazabilidad/auditoría y para mostrar el texto relativo ("desde hace unos segundos"); este spec no requiere una pantalla dedicada de historial de cambios.
- El menú QR no requiere actualización en tiempo real: un comensal que ya tenga el menú cargado puede no ver el cambio de estado hasta recargar, pero la validación al confirmar el pedido (User Story 2) es la garantía real contra pedidos de productos agotados, según lo excluido explícitamente en el alcance.
- El agotado se maneja a nivel de producto completo, no por presentación individual, conforme a lo excluido explícitamente en el alcance.
- El estado Agotado no se restablece automáticamente ni se deriva de niveles de inventario; solo cambia por acción explícita de un Cajero o un Administrador, conforme a lo excluido explícitamente en el alcance.
