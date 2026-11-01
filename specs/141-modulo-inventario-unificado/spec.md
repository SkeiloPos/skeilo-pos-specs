# Feature Specification: Módulo Inventario unificado (Inventario + Proveedores + Compras) en el control de acceso por plan

**Feature Branch**: `141-modulo-inventario-unificado`

**Created**: 2026-10-31

**Status**: Draft

**Input**: User description: "Implementar un sistema de control de acceso estricto basado en módulos del plan, agrupando bajo el módulo «Inventario» las secciones de Inventario, Proveedores y Compras. Los tenants solo deben ver y operar lo contemplado en su contrato; activar un módulo en un plan habilita todas sus funcionalidades (acceso todo o nada); la validación es autoritaria en el servidor y la interfaz solo es un espejo visual; si un tenant pierde el módulo, sus datos se conservan pero quedan inaccesibles hasta que lo recupere; el módulo «Compras» deja de existir como módulo independiente y los planes que lo tenían activo pasan a tener «Inventario» activo. Seis escenarios de aceptación: plan con Inventario ve todo; plan sin Inventario oculta todo (incluido el encabezado de sección); URL directa a Proveedores bloqueada con aviso y redirección al inicio; API responde 403 con código `MODULE_NOT_IN_PLAN` y módulo `inventario`; revocación del módulo con sesión activa; migración limpia del antiguo módulo Compras."

## Aclaraciones previas (resueltas antes de escribir esta spec)

### Session 2026-10-31

- Q: «Compras» no es hoy un ítem del menú lateral (es una pestaña dentro de la pantalla Inventario más la vista «Nueva compra»; el Escenario 1 espera verlo como opción de menú). ¿Cómo se resuelve? → A: **Sigue como pestaña de Inventario.** No se crea un ítem de menú ni una pantalla nueva. El Escenario 1 se lee así: el menú muestra «Inventario» y «Proveedores», y «Compras» queda accesible dentro de Inventario. Esta spec no agrega pantallas.
- Q: Los planes que hoy tienen Inventario activo y Compras inactivo ganarán Proveedores y Compras sin haberlos contratado (consecuencia de que el módulo sea indivisible; la migración del Escenario 6 solo cubre el caso inverso). ¿Qué se hace con ellos? → A: **Se acepta tal cual.** Quedan con el módulo Inventario completo, sin listado ni revisión adicional.
- Q: Escenario 5: ¿qué debe ver quien tiene la pantalla abierta cuando le quitan el módulo y su siguiente petición recibe 403? → A: **Aviso + vuelta al inicio + menú actualizado en el acto**, sin necesidad de recargar la aplicación.
- Q: El código `MODULE_NOT_IN_PLAN` y el aviso «no está incluida en tu plan», ¿aplican solo a Inventario o a todos los módulos del plan? → A: **A todos los módulos** (mecanismo único). Promociones adopta el mismo código de error y el mismo aviso, sin cambios en sus reglas de negocio.
- Q: Cuando varias peticiones de un mismo usuario reciben `MODULE_NOT_IN_PLAN` casi al mismo tiempo (p. ej., la pantalla de Inventario pide varias listas a la vez), ¿cuántos avisos y redirecciones debe ver? → A: **Uno solo.** El primer rechazo muestra el aviso y lleva al inicio; los rechazos que lleguen mientras se atiende esa misma pérdida no repiten aviso ni redirección.
- Q: Cuando el Super Admin edita un plan ya asignado a varios negocios y le quita «Inventario», ¿el panel debe pedir confirmación antes de guardar? → A: **Sí, confirmación simple con texto fijo** («Los negocios con este plan perderán Inventario, Proveedores y Compras de inmediato»), sin conteo de negocios, solo al pasar «Inventario» de activo a inactivo.

### Enmienda posterior a `/speckit-analyze` (2026-10-31)

- FR-014 se amplía de las superficies *visibles* a toda **carga de fondo** de un endpoint del módulo (hallazgos H1 y H2 de research.md), y se añade US3.6.
- Se añade FR-023 y US2.7 (importación/exportación de productos, hallazgo H3), **condicionados** a la ratificación del dueño (A-153). Si no se ratifica, se retiran junto con la decisión de negocio 4.

## Alcance y relación con specs previas

**Qué cambia**: el catálogo de módulos que un Super Admin puede asignar a un plan pasa de tres (Inventario, Compras, Promociones) a dos (**Inventario** y **Promociones**). «Inventario» pasa a ser la unidad comercial indivisible que cubre Inventario, Proveedores y Compras.

**Estado actual verificado en el código** (el motivo de que esta spec exista):

- Proveedores está protegido en el servidor (comparte el grupo de endpoints de Inventario), pero **no** en la interfaz: su ítem de menú y sus rutas se muestran aunque el plan no incluya Inventario.
- Compras exige hoy **dos** condiciones a la vez: Inventario y un indicador propio de «Compras» (decisión 6 de la spec 033). Esta spec **reemplaza** esa decisión.
- Las respuestas 403 por módulo no incluido son texto plano, sin código de error ni módulo requerido. La redirección de una ruta bloqueada vuelve al inicio **sin ningún aviso**.
- El panel de inicio del tenant pide la lista de «Stock bajo» al cargar, sin comprobar el plan, por lo que un tenant sin Inventario dispara una petición que termina en 403 (hoy el error se guarda en silencio; con el aviso de esta spec sería visible).

**Impacto sobre funcionalidad existente**: ventas, catálogo, pedidos, cobro y menú QR del comensal **no se bloquean** sin el módulo (siguen funcionando, sin descontar stock y sin campos de receta, como definen las specs 062, 064 y 123). Unidades de medida, grupos de unidades y reportes de stock siguen gobernados por Inventario, como hoy.

**Impacto sobre datos existentes**: los datos de inventario, proveedores y compras no se tocan. Solo se modifican los **planes** (atributos de acceso a módulos) mediante la migración del Escenario 6.

**Decisiones de negocio que toma esta spec** (se registran en el registro de anomalías al aprobarse, Constitución II y XI):

1. Inventario, Proveedores y Compras son un único módulo indivisible; «Compras» deja de ser un módulo configurable (reemplaza la decisión 6 de la spec 033).
2. Los planes con Inventario activo y Compras inactivo pasan a incluir Proveedores y Compras.
3. Todos los módulos del plan comparten el mismo código de error, el mismo aviso y la misma conducta ante una sesión activa.
4. *(Condicionada a la ratificación del dueño, A-153)* La importación y exportación de productos (spec 143) respeta el módulo Inventario a nivel de campo, igual que el formulario de producto (spec 064).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - El Super Admin gestiona un único módulo «Inventario» y los planes existentes migran sin perder nada (Priority: P1)

Como Super Admin, al crear o editar un plan veo un solo interruptor «Inventario» (que incluye Proveedores y Compras) en vez de dos módulos separados, y los planes que ya existían quedan coherentes sin que yo tenga que revisarlos uno por uno.

**Why this priority**: es la base comercial de todo lo demás. Sin ella el plan sigue expresando una distinción (Inventario vs. Compras) que el resto del sistema deja de respetar, y los tenants con «Compras» activo podrían perder acceso.

**Independent Test**: con planes de prueba en cada combinación de Inventario/Compras, ejecutar la migración y comprobar el estado resultante de cada uno, y abrir el panel de planes para confirmar que ya no ofrece «Compras».

**Acceptance Scenarios**:

1. **Given** un plan con «Compras» activo e «Inventario» inactivo, **When** se ejecuta la migración, **Then** el plan queda con «Inventario» activo.
2. **Given** un plan con ambos activos, **When** se ejecuta la migración, **Then** queda con «Inventario» activo y nada más cambia.
3. **Given** un plan con «Inventario» activo y «Compras» inactivo, **When** se ejecuta la migración, **Then** queda con «Inventario» activo (ahora incluye Proveedores y Compras, decisión aceptada).
4. **Given** un plan sin ninguno de los dos, **When** se ejecuta la migración, **Then** queda sin acceso a Inventario, igual que antes.
5. **Given** la migración ya ejecutada, **When** se ejecuta de nuevo, **Then** el resultado es idéntico (no produce más cambios).
6. **Given** el panel de administración global, **When** el Super Admin crea o edita un plan, **Then** ve «Inventario» como único control (indicando que incluye Proveedores y Compras) y «Compras» no aparece en ninguna pantalla ni listado de planes.
7. **Given** cualquier tenant, **When** consulta «Mi plan», **Then** la lista de módulos no incluye «Compras».
8. **Given** un plan con «Inventario» activo, **When** el Super Admin lo edita, desmarca «Inventario» y guarda, **Then** el panel muestra una confirmación con el texto «Los negocios con este plan perderán Inventario, Proveedores y Compras de inmediato»; si cancela, el plan queda sin cambios; si confirma, se guarda.
9. **Given** un plan con «Inventario» activo, **When** el Super Admin lo edita sin desmarcar «Inventario» (o crea un plan nuevo), **Then** se guarda sin mostrar esa confirmación.

---

### User Story 2 - El servidor rechaza toda operación del módulo cuando el plan no lo incluye (Priority: P1)

Como dueño del producto, necesito que el servidor sea la única autoridad: aunque alguien llame directamente a la API sin pasar por la interfaz, no puede leer ni modificar nada de Inventario, Proveedores ni Compras si su plan no incluye el módulo.

**Why this priority**: es la garantía de seguridad y de cumplimiento del contrato comercial. La interfaz puede ocultarse o saltarse; el servidor no.

**Independent Test**: con un tenant cuyo plan no incluye Inventario, recorrer **todos** los endpoints del módulo (insumos, movimientos, importación y exportación, proveedores y sus insumos, compras y órdenes de compra, unidades de medida y reportes de stock) con un usuario autenticado y comprobar que todos responden 403 con el código y el módulo requerido, sin tocar datos.

**Acceptance Scenarios**:

1. **Given** un tenant sin el módulo Inventario, **When** se envía una solicitud autenticada a cualquier endpoint de inventario, proveedores o compras, **Then** la API responde **403** con el código de error `MODULE_NOT_IN_PLAN` y el módulo requerido `inventario`.
2. **Given** esa misma respuesta, **When** se revisa la base de datos, **Then** no se ejecutó ninguna lectura ni modificación de datos del negocio.
3. **Given** un tenant cuyo plan sí incluye Inventario, **When** se envía cualquiera de esas solicitudes, **Then** se procesan con normalidad, incluidas las de Proveedores y Compras (que ya no exigen un indicador propio).
4. **Given** un tenant sin el módulo Promociones, **When** se llama a un endpoint de promociones, **Then** responde 403 con `MODULE_NOT_IN_PLAN` y el módulo requerido `promociones`.
5. **Given** un tenant cuyo plan **venció**, **When** se llama a cualquier endpoint de un módulo, **Then** responde con el rechazo propio de plan vencido (spec 033), distinto de `MODULE_NOT_IN_PLAN`.
6. **Given** un usuario con un rol que ya no tenía permiso sobre esa funcionalidad, **When** el plan sí incluye el módulo, **Then** se sigue rechazando por rol, como hoy.
7. **Given** un tenant sin Inventario, **When** importa un libro de productos con filas de «Receta» o con «Rastrea inventario = Sí», **Then** esas filas se rechazan por fila con «Tu plan actual no incluye el módulo de inventario.» y el resto se procesa; la exportación no trae la hoja «Receta» ni esa columna *(solo si A-153 se ratifica; ver FR-023)*.

---

### User Story 3 - El menú y las pantallas muestran solo lo que el plan incluye (Priority: P1)

Como administrador de un negocio, cuando abro la aplicación veo únicamente las opciones que mi plan me permite usar, sin bloques vacíos ni alertas que no puedo atender.

**Why this priority**: es lo que el cliente ve todos los días; mostrar opciones a las que no puede entrar genera confusión y llamadas a soporte.

**Independent Test**: iniciar sesión en dos tenants (uno con el módulo y otro sin él) y comparar menú, panel de inicio, Ajustes, Reportes y pantalla de Inventario.

**Acceptance Scenarios**:

1. **Given** el tenant «springfieldgranizados» con un plan que incluye Inventario y un administrador con sesión iniciada, **When** despliega el menú, **Then** ve dentro de la sección «Inventario» las opciones «Inventario» y «Proveedores», y dentro de la pantalla de Inventario la pestaña «Compras» y la vista de nueva compra; puede entrar a cada una y operar sin errores de permisos.
2. **Given** un tenant cuyo plan no incluye Inventario, **When** abre el menú, **Then** no aparecen «Inventario» ni «Proveedores», y el **encabezado de sección «Inventario» desaparece** (no queda un bloque vacío).
3. **Given** ese mismo tenant, **When** abre el panel de inicio, **Then** no aparece la tarjeta «Stock bajo» y no se genera ninguna petición al servidor que termine en rechazo.
4. **Given** ese mismo tenant, **When** abre Ajustes, Reportes y los formularios de productos y adiciones, **Then** no ve la pestaña «Unidades de medida», el bloque de insumos con stock bajo ni los campos de receta/stock (conducta que ya existe y se conserva).
5. **Given** un tenant con el módulo, **When** el administrador abre la pestaña «Compras» de Inventario, **Then** aparece siempre (ya no depende de un indicador propio de Compras).
6. **Given** un tenant sin Inventario o sin Promociones, **When** abre la Terminal de mesas, el formulario de producto o los grupos de opciones, **Then** cargan completos, sin peticiones a endpoints del módulo ausente y sin ningún aviso.

---

### User Story 4 - Entrar por URL directa a una pantalla no incluida en el plan (Priority: P2)

Como usuario de un negocio sin el módulo, si abro un enlace guardado o escribo la dirección de una pantalla que mi plan no incluye, el sistema me lo dice con claridad en vez de dejarme en una pantalla en blanco o en un error técnico.

**Why this priority**: cubre el caso de marcadores, enlaces compartidos y navegación manual; es menos frecuente que el uso normal del menú y por eso no es P1.

**Independent Test**: sin el módulo, navegar manualmente a la ruta de Proveedores (y a las demás rutas del módulo) y verificar bloqueo, aviso y redirección.

**Acceptance Scenarios**:

1. **Given** un tenant sin Inventario, **When** el usuario navega por URL directa a la ruta de Proveedores, **Then** la pantalla no carga, el sistema lo lleva al inicio y muestra el aviso **«Esta funcionalidad no está incluida en tu plan»**.
2. **Given** ese tenant, **When** navega por URL directa a Inventario, al detalle de un insumo, al detalle de un proveedor o a la vista de nueva compra, **Then** ocurre exactamente lo mismo.
3. **Given** un tenant sin Promociones, **When** navega por URL directa a Promociones, **Then** ocurre lo mismo (hoy redirige sin mostrar aviso).
4. **Given** un tenant con plan vencido, **When** navega a una pantalla de un módulo, **Then** se conserva la conducta actual de plan vencido (vuelta al inicio) y no se muestra el aviso de «no incluida».
5. **Given** un tenant con el módulo, **When** navega por URL directa a esas rutas, **Then** cargan con normalidad.

---

### User Story 5 - Un tenant pierde el módulo mientras tiene la sesión abierta (Priority: P2)

Como administrador que está trabajando en Proveedores cuando el Super Admin cambia mi plan a uno sin Inventario, quiero que el sistema me lo comunique de forma clara y me saque de esa pantalla, sin que mis datos desaparezcan.

**Why this priority**: es un caso real pero poco frecuente (cambio de plan en caliente); la protección de fondo ya la da la historia 2, esta historia solo cuida la experiencia y la integridad de los datos.

**Independent Test**: con una sesión abierta en Proveedores, cambiar el plan del tenant a uno sin Inventario y ejecutar cualquier acción en la pantalla; después volver a asignar el plan con el módulo y verificar que los datos siguen allí.

**Acceptance Scenarios**:

1. **Given** un tenant con el módulo y un usuario con la pantalla de Proveedores abierta, **When** el Super Admin cambia el plan a uno sin Inventario y el usuario realiza su siguiente acción sobre Proveedores, **Then** recibe 403 `MODULE_NOT_IN_PLAN`, la aplicación muestra «Esta funcionalidad no está incluida en tu plan», lo lleva al inicio y el menú ya no muestra el módulo, **sin recargar**.
2. **Given** el mismo usuario que recarga la aplicación, **When** vuelve a entrar, **Then** el menú tampoco muestra las opciones del módulo.
3. **Given** el plan sin Inventario, **When** se revisa la base de datos, **Then** los insumos, movimientos, proveedores, vínculos insumo-proveedor, compras y órdenes de compra históricos siguen intactos.
4. **Given** que el Super Admin vuelve a asignar un plan con Inventario, **When** el administrador entra de nuevo al módulo, **Then** todos esos datos reaparecen íntegros.
5. **Given** que el cambio de plan ocurrió, **When** el usuario hace la siguiente petición al módulo, **Then** se rechaza en esa misma petición (no hay un retardo en el que aún se permita la operación).
6. **Given** una pantalla del módulo que lanza varias peticiones a la vez (p. ej., Inventario), **When** el plan ya no incluye el módulo y varias de esas peticiones reciben `MODULE_NOT_IN_PLAN`, **Then** el usuario ve **un solo** aviso «Esta funcionalidad no está incluida en tu plan» y una sola redirección al inicio.

### Edge Cases

- **Peticiones automáticas de fondo** (no iniciadas por el usuario): la conducta de aviso y redirección de FR-016 no debe dispararse por ellas. Por eso ninguna carga de fondo del módulo puede lanzarse cuando el plan no lo incluye (FR-014), y cuando el estado del plan aún no se conoce no debe asumirse «sin módulo».
- **Plan vencido**: tiene precedencia propia (spec 033, FR-019). Su 403 y su aviso no cambian y no usan el código `MODULE_NOT_IN_PLAN`.
- **Ventas, pedidos y cobro sin el módulo**: siguen funcionando exactamente como hoy. No se descuenta stock y no se exigen recetas. Perder el módulo nunca debe impedir vender.
- **Compra en borrador u orden de compra pendiente** al perder el módulo: se conserva tal cual; no se puede recibir, editar ni anular hasta recuperar el módulo.
- **Importación de inventario en curso** al perder el módulo: no se interrumpe; su resultado queda inaccesible hasta recuperar el módulo. No se puede iniciar una importación nueva.
- **Recuperar el módulo**: el stock refleja el último estado registrado; no se concilian ventas hechas mientras no había módulo (no se descontaron entonces y no se descuentan después).
- **Planes de cada combinación** (Compras sí/no × Inventario sí/no) al migrar: ver historia 1; ningún plan pierde acceso a algo que tenía.
- **Cambio de plan con varias pestañas o dispositivos abiertos**: cada uno se corrige con su siguiente petición al módulo; ninguno conserva acceso.
- **Rutas públicas del comensal (menú QR)**: no pertenecen a ningún módulo del plan y no se ven afectadas.
- **Consumidores que leían el indicador de «Compras»** en el resumen del plan o en la administración de planes: reciben un cambio incompatible documentado (ver Assumptions).
- **Reversión de la migración**: no es posible distinguir después a los planes que tenían Inventario sin Compras; la estrategia de reversión debe declararlo (FR-021).

## Requirements *(mandatory)*

### Functional Requirements

**Catálogo de módulos y regla de acceso**

- **FR-001**: El catálogo de módulos que un plan puede incluir MUST contener exactamente «Inventario» y «Promociones». «Compras» MUST dejar de existir como módulo configurable independiente.
- **FR-002**: Cada funcionalidad del sistema (pantalla, acción o endpoint) MUST pertenecer a un único módulo.
- **FR-003**: El módulo «Inventario» MUST agrupar de forma indivisible: insumos (alta, edición, ajustes, movimientos/kardex, importación y exportación), proveedores y sus insumos asociados, compras y órdenes de compra (crear, editar, recibir, anular, eliminar), unidades de medida y sus grupos, y reportes de stock. Los últimos dos ya dependen hoy de Inventario y se conservan sin cambios.
- **FR-004**: Si el plan vigente del tenant incluye el módulo, el tenant MUST acceder a **todas** sus funcionalidades; si no lo incluye, MUST ser denegado a **todas** (sin acceso parcial, sin excepciones por pantalla).

**Autoridad del servidor**

- **FR-005**: El servidor MUST validar el acceso al módulo en **cada** petición autenticada a una funcionalidad del módulo, usando el plan vigente en ese instante, de modo que un cambio de plan surta efecto desde la siguiente petición.
- **FR-006**: Cuando el módulo no está en el plan, el servidor MUST responder **HTTP 403** con el código de error `MODULE_NOT_IN_PLAN` y el módulo requerido (`inventario`, `promociones`), y MUST NOT leer ni modificar ningún dato del negocio para atender esa petición.
- **FR-007**: La respuesta de FR-006 MUST seguir incluyendo un mensaje legible en el campo de texto de error que los clientes ya leen hoy, de modo que ningún consumidor existente deje de mostrar un mensaje.
- **FR-008**: El mismo mecanismo, código de error y formato MUST aplicarse a todos los módulos del plan (Inventario y Promociones).
- **FR-009**: Un plan vencido MUST conservar su rechazo y mensaje propios (spec 033), distintos de `MODULE_NOT_IN_PLAN`.
- **FR-010**: La restricción por rol MUST mantenerse tal como está hoy; el control por módulo se suma a ella y se aplica igual a todos los roles autenticados del tenant.
- **FR-011**: Ventas, catálogo, pedidos, cobro y menú QR MUST seguir funcionando sin el módulo Inventario, sin descontar stock ni exigir campos de receta.

**Interfaz como espejo del plan**

- **FR-012**: El menú MUST ocultar «Inventario» y «Proveedores» cuando el plan no incluye el módulo, y MUST ocultar el encabezado de sección «Inventario» cuando queda sin opciones visibles.
- **FR-013**: «Compras» MUST permanecer como pestaña de la pantalla Inventario y como vista de nueva compra, visibles si y solo si el plan incluye Inventario. No se crea un ítem de menú ni una pantalla nueva.
- **FR-014**: Toda superficie que muestre información del módulo fuera de sus pantallas (tarjeta «Stock bajo» del panel de inicio, pestaña «Unidades de medida» de Ajustes, bloque de insumos con stock bajo de Reportes, campos de receta/stock de productos y adiciones) MUST ocultarse sin el módulo. Además, **ninguna carga de fondo de un endpoint de un módulo** MUST lanzarse cuando el plan no lo incluye, aunque no muestre nada: la carga de promociones activas de la Terminal de mesas (Promociones) y la de unidades de medida e insumos en los formularios de producto, grupos de opciones y adición (Inventario). Esas pantallas MUST seguir funcionando sin el módulo (FR-011). Mientras el plan es desconocido, la interfaz no asume «sin módulo» para mostrar y difiere la carga hasta conocerlo. Esto es indispensable por la interacción con FR-016: una petición automática de fondo rechazada con `MODULE_NOT_IN_PLAN` (hoy la del «Stock bajo» al cargar el panel de inicio) dispararía el aviso y la redirección sin que el usuario haya hecho nada.
- **FR-015**: Al intentar abrir por URL directa una pantalla de un módulo no incluido en el plan (incluidos Proveedores y su detalle, Inventario y su detalle, nueva compra, Unidades de medida y Promociones), el sistema MUST bloquear la carga, llevar al usuario al inicio y mostrar **«Esta funcionalidad no está incluida en tu plan»**.
- **FR-016**: Cuando una acción de un usuario con sesión activa recibe `MODULE_NOT_IN_PLAN`, la aplicación MUST mostrar ese mismo aviso, llevar al inicio y actualizar la información del plan para que el menú deje de mostrar el módulo **sin recargar la aplicación**. Si varias peticiones reciben el rechazo a la vez o en sucesión por la misma pérdida de módulo, la aplicación MUST mostrar **un solo aviso** y hacer **una sola redirección**: los rechazos que lleguen mientras se completan la redirección y la actualización del plan no los repiten.
- **FR-017**: Si el plan está vencido, la interfaz MUST conservar su conducta actual (vuelta al inicio) y MUST NOT mostrar el aviso de «no incluida en tu plan».

**Conservación de datos**

- **FR-018**: Perder el módulo MUST NOT borrar, modificar ni invalidar datos de inventario, movimientos, proveedores, vínculos insumo-proveedor, compras ni órdenes de compra; recuperar el módulo MUST devolver el acceso a todos esos datos íntegros.

**Administración de planes y migración**

- **FR-019**: El panel de administración global MUST ofrecer «Inventario» como único control de acceso del módulo, indicando que incluye Proveedores y Compras, y MUST dejar de ofrecer «Compras» al crear, editar, listar o consultar un plan. La vista «Mi plan» del tenant MUST dejar de listar «Compras». Al editar un plan cuyo «Inventario» pasa de activo a inactivo, el panel MUST pedir confirmación antes de guardar, con el texto fijo «Los negocios con este plan perderán Inventario, Proveedores y Compras de inmediato» (sin conteo de negocios); cancelar MUST dejar el plan sin cambios.
- **FR-020**: Una migración MUST dejar «Inventario» activo en todo plan que tuviera «Compras» activo. Los planes con «Inventario» activo y «Compras» inactivo MUST quedar con «Inventario» activo (con acceso a Proveedores y Compras). Los planes sin ninguno de los dos MUST permanecer sin acceso. Ningún plan MUST perder acceso a algo que tenía. La migración MUST NOT alterar límites numéricos, precios, ciclos, vencimientos ni la asignación de plan de ningún tenant.
- **FR-021**: La migración MUST ser idempotente y reversible. La estrategia de reversión MUST declarar explícitamente qué información previa recupera y cuál no (en particular, que no puede distinguir a los planes que tenían Inventario sin Compras) (Constitución VIII).
- **FR-022**: La retirada de «Compras» de las respuestas del resumen de plan y de la administración de planes MUST documentarse como cambio incompatible, sin período de transición.

**Superficies de campo (condicionado a la ratificación de A-153)**

- **FR-023**: Si el plan no incluye Inventario, la importación de productos MUST rechazar por fila las filas de «Productos» con «Rastrea inventario = Sí» y todas las de «Receta», con el mensaje «Tu plan actual no incluye el módulo de inventario.», y MUST procesar el resto del archivo; la exportación de productos MUST omitir la hoja «Receta» y la columna «Rastrea inventario». Con el módulo, la conducta no cambia. Si el dueño no ratifica A-153, este requisito se retira y la spec se cierra sin él.

### Key Entities

- **Plan**: nivel de suscripción que define a qué módulos tiene acceso un tenant (además de límites y vigencia, que no cambian). Pasa de tres atributos de acceso a módulo a dos: Inventario y Promociones.
- **Módulo**: unidad comercial contratada en el plan. Un módulo agrupa funcionalidades de forma indivisible; una funcionalidad pertenece a un único módulo.
- **Funcionalidad**: pantalla, acción o endpoint gobernado por un módulo. Para Inventario: insumos y su kardex, importación/exportación, proveedores y sus insumos, compras y órdenes de compra, unidades de medida y grupos, reportes de stock.
- **Tenant**: negocio cliente con un plan asignado y vigente; su acceso a cada módulo se deriva siempre del plan vigente en ese momento.
- **Datos del módulo Inventario**: insumos, movimientos, proveedores, vínculos insumo-proveedor, compras, órdenes de compra e importaciones. Se conservan íntegros aunque el tenant pierda el módulo.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100 % de las funcionalidades del módulo Inventario (verificado recorriendo el inventario completo de endpoints) rechaza a un tenant sin el módulo con 403 y `MODULE_NOT_IN_PLAN`, con 0 lecturas o modificaciones de datos del negocio.
- **SC-002**: El 100 % de las funcionalidades del módulo funciona sin errores de permiso para un tenant que lo tiene, incluidas Proveedores y Compras sin ningún indicador adicional.
- **SC-003**: Tras un cambio de plan, la siguiente petición del usuario al módulo ya se rechaza (0 peticiones permitidas después del cambio) y el menú se corrige sin recargar la aplicación, con un único aviso visible aunque varias peticiones sean rechazadas a la vez.
- **SC-004**: Un tenant sin el módulo ve 0 opciones de menú del módulo, 0 encabezados de sección vacíos y 0 elementos de interfaz (tarjetas, pestañas, campos) que dependan del módulo y 0 peticiones de fondo a endpoints del módulo.
- **SC-005**: El 100 % de las rutas de pantalla de módulos no incluidos muestra el aviso «Esta funcionalidad no está incluida en tu plan» al entrar por URL directa.
- **SC-006**: Tras la migración, el 100 % de los planes que tenían «Compras» activo queda con «Inventario» activo; 0 planes pierden acceso; el recuento de insumos, movimientos, proveedores, compras y órdenes de compra es idéntico antes y después.
- **SC-007**: El Super Admin configura el acceso a Inventario, Proveedores y Compras con **una** acción (un solo control) en lugar de dos.

## Assumptions

- Las restricciones por rol (solo administrador en estas pantallas) no cambian; «Administrador de Tenant / Staff» se entiende como el conjunto de usuarios del tenant que hoy tienen acceso a estas pantallas.
- Las funcionalidades que hoy dependen de Inventario fuera de sus pantallas (unidades de medida y grupos, reportes de stock, campos de receta/stock en productos y adiciones) se conservan bajo el módulo; esta spec no cambia lo que hacen, solo garantiza que el control sea coherente.
- Una importación de inventario ya iniciada al perder el módulo no se cancela; su resultado simplemente queda inaccesible hasta recuperar el módulo.
- Al recuperar el módulo no se concilia el stock con las ventas ocurridas mientras no estaba activo.
- No existen consumidores externos (fuera de los repositorios del sistema) que dependan del indicador de «Compras» del plan; el consumidor interno (panel de administración, vista «Mi plan», menú y guardas de ruta) se actualiza en esta misma spec.
- La estrategia técnica de la migración (conservar o eliminar físicamente el atributo de «Compras», forma de la reversión) se decide en el plan, respetando FR-020 y FR-021.
- El tenant «springfieldgranizados» se usa como caso de verificación del Escenario 1, tal como lo plantea la descripción original.
- Esta spec no incluye cambios a cobros, facturación de planes ni precios; no agrega pantallas nuevas ni ítems de menú nuevos (la confirmación de FR-019 es un diálogo dentro del formulario de plan existente, no una pantalla).
- La confirmación de FR-019 se limita a quitar «Inventario» al **editar un plan**; no aplica a crear planes, a reasignar el plan de un solo negocio ni a quitar «Promociones» (cuya edición de plan conserva su conducta actual).
