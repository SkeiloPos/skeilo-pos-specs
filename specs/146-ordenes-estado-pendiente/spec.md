# Feature Specification: Estado inicial PENDIENTE para órdenes e ítems, sin traducción en frontend

**Feature Branch**: `146-ordenes-estado-pendiente`

**Created**: 2026-11-01

**Status**: Draft

**Input**: User description: "Como cajero o encargado de barra quiero que una orden y sus ítems nazcan en estado PENDIENTE y que el sistema muestre exactamente el estado guardado, para no tomar decisiones con información contradictoria entre la pantalla y la base de datos. Toda orden nueva (QR, caja, domicilio) se crea en PENDIENTE y payment_status=UNPAID salvo pago confirmado en el mismo acto de creación; sus ítems nacen en PENDIENTE; el estado RECIBIDA deja de existir y las órdenes históricas se migran a su equivalente; el frontend no traduce ni infiere estados, muestra el valor que entrega la API."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Toda orden nueva nace en PENDIENTE sin importar el canal (Priority: P1)

Como cajero, encargado de barra, comensal (vía QR) o domiciliario, cuando se crea una orden nueva con uno o más ítems, espero que la orden y cada uno de sus ítems queden guardados con estado "PENDIENTE", y que el estado de pago sea "UNPAID" a menos que el pago se confirme en el mismo acto de creación. Esto evita que distintos canales de creación produzcan estados iniciales distintos o inconsistentes entre sí.

**Why this priority**: Es la base de confianza del flujo operativo: si el estado inicial varía según el canal (QR, caja, domicilio), cocina y caja no pueden confiar en un criterio único para saber qué pedidos atender primero. Sin esto, el resto de la funcionalidad (visualización correcta en Terminal de Mesas) carece de sentido.

**Independent Test**: Se puede probar creando una orden desde cada canal (QR, caja, domicilio) con varios ítems y verificando en la base de datos y en la respuesta de la API que la orden queda en "PENDIENTE"/"UNPAID" y todos los ítems en "PENDIENTE".

**Acceptance Scenarios**:

1. **Given** un comensal, cajero o domiciliario crea una orden con 3 ítems, **When** la orden se guarda, **Then** la orden queda en estado "PENDIENTE" con estado de pago "UNPAID", los 3 ítems quedan en estado "PENDIENTE", y la Terminal de Mesas muestra "Pendiente" para la orden.
2. **Given** una orden se crea y el pago se confirma en el mismo acto de creación (por ejemplo, venta de mostrador pagada de inmediato), **When** la orden se guarda, **Then** el estado de la orden es "PENDIENTE" y el estado de pago refleja el pago confirmado (no queda forzado a "UNPAID").
3. **Given** una orden nueva con ítems, **When** se consulta el detalle recién creado, **Then** ningún ítem aparece en un estado distinto de "PENDIENTE".

---

### User Story 2 - Eliminación del estado RECIBIDA y migración de órdenes históricas (Priority: P1)

Como responsable de la operación, quiero que el estado "RECIBIDA" deje de existir en el sistema y que todas las órdenes históricas que lo tenían queden migradas a su equivalente ("PENDIENTE"), para que no haya dos nombres distintos representando el mismo significado operativo y para que ningún reporte, filtro o pantalla pueda seguir mostrando un estado obsoleto.

**Why this priority**: Mientras exista ambigüedad entre "RECIBIDA" y "PENDIENTE", persiste exactamente el problema que la funcionalidad busca resolver: información contradictoria entre pantalla y base de datos, y entre distintas órdenes que en la práctica significan lo mismo pero se etiquetan distinto según su antigüedad.

**Independent Test**: Se puede probar ejecutando la migración sobre una base con órdenes en estado "RECIBIDA" en varios esquemas (tenants) y verificando que, tras la migración, no queda ningún registro con el valor "RECIBIDA" en ningún esquema, y que esas órdenes ahora aparecen como "PENDIENTE" en la API y en la Terminal de Mesas.

**Acceptance Scenarios**:

1. **Given** existen órdenes con estado "RECIBIDA" en los esquemas de todos los tenants, **When** se ejecuta la migración, **Then** esas órdenes quedan en "PENDIENTE" y no queda ningún registro con el valor "RECIBIDA" en ningún esquema.
2. **Given** la migración ya se ejecutó, **When** se intenta crear o actualizar una orden con el valor "RECIBIDA", **Then** el sistema rechaza ese valor porque ya no es un estado válido.
3. **Given** un tenant que no tenía ninguna orden en estado "RECIBIDA", **When** se ejecuta la migración, **Then** sus órdenes y datos no sufren ningún cambio distinto a la eliminación del valor "RECIBIDA" del catálogo de estados.

---

### User Story 3 - El frontend muestra el estado crudo entregado por la API, sin traducir ni inferir (Priority: P2)

Como cajero, mesero o encargado de cocina que observa la Terminal de Mesas o el detalle de un pedido, quiero que la pantalla muestre exactamente el estado que la API reporta, sin que el frontend decida un valor "parecido" o "por defecto" cuando no reconoce el estado recibido, para poder confiar en que lo que veo en pantalla es lo que realmente hay guardado.

**Why this priority**: Es la garantía de la consistencia pantalla-base de datos a futuro: aunque hoy se resuelvan los estados existentes, cualquier estado nuevo o no contemplado debe ser visible como tal, en vez de ocultarse detrás de una inferencia que podría ser incorrecta (como mostrar "En preparación" cuando en realidad es otra cosa).

**Independent Test**: Se puede probar simulando que la API devuelve un valor de estado no mapeado por el frontend y verificando que la pantalla de detalle del pedido muestra ese valor crudo (no un estado por defecto) y que se registra un error en la consola del navegador.

**Acceptance Scenarios**:

1. **Given** la API devuelve un estado que el frontend no tiene mapeado, **When** se renderiza el detalle del pedido, **Then** se muestra el valor crudo del estado y se registra un error en consola, y no se muestra un estado por defecto como "En preparación".
2. **Given** la API devuelve un estado conocido y mapeado (p. ej. "PENDIENTE"), **When** se renderiza cualquier pantalla que muestre el estado de la orden o de un ítem, **Then** la etiqueta mostrada corresponde exactamente a ese estado, sin inferencias adicionales basadas en otros campos (como el estado de pago).

---

### Edge Cases

- ¿Qué ocurre si una orden se crea sin ítems (si el canal lo permite)? La orden debe quedar igualmente en "PENDIENTE"/"UNPAID"; no hay ítems que validar.
- ¿Qué ocurre si durante la migración una orden tiene ítems en estado "RECIBIDA" pero la orden "padre" ya estaba en otro estado? La migración debe actualizar ítems y órdenes de forma consistente según su propio valor, sin asumir que el estado del ítem sigue al de la orden.
- ¿Qué ocurre si dos tenants comparten el mismo esquema de base de datos o uno de los esquemas no sigue la convención esperada? La migración debe identificar explícitamente cada esquema de tenant y no asumir que solo existe el esquema `public`.
- ¿Qué ocurre si el pago se confirma en el mismo acto de creación pero solo de forma parcial (pago mixto o parcial)? El estado de la orden sigue siendo "PENDIENTE"; el estado de pago refleja la situación real de pago (no se fuerza a "UNPAID" si ya hay pago registrado, ni se marca como completamente pagado si el pago fue parcial).
- ¿Qué ocurre si el frontend recibe un estado válido para la orden pero no reconocido para un ítem (o viceversa)? El mismo principio aplica de forma independiente a cada entidad: se muestra el valor crudo recibido para esa entidad específica.
- ¿Qué pasa con las vistas, reportes o filtros guardados (por ejemplo, un filtro de "RECIBIDA" guardado previamente por un usuario) una vez el estado deja de existir? Deben dejar de ofrecer esa opción y, si existía un filtro activo con ese valor, debe comportarse como si no hubiera resultados para ese valor obsoleto o reencauzarse al equivalente "PENDIENTE".

## Clarifications

### Session 2026-11-01

- Q: How should the system stop "RECIBIDA" from ever being stored again after the migration — by enforcing it at the database layer, or only in application code? → A: DB-level constraint/enum (Recommended) — the database itself rejects "RECIBIDA" for orders and items in every tenant schema.
- Q: Should the frontend fetch the catalog of valid order/item states from the API at runtime, or keep its own static list of "known" states in frontend code? → A: Static list in frontend code (Recommended) — a hardcoded list mirroring the backend catalog, used only to detect and log unmapped values; no new API endpoint.
- Q: How should the RECIBIDA-to-PENDIENTE migration across all tenant schemas be executed — as an automatic schema migration run during deployment, or as a separately triggered/manual script? → A: Automatic deployment migration (Recommended) — runs as part of the standard schema-migration tooling during deployment, iterating over all tenant schemas plus public.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema DEBE crear toda orden nueva, sin importar el canal de origen (QR, caja, domicilio u otro canal existente o futuro), con estado "PENDIENTE".
- **FR-002**: El sistema DEBE crear toda orden nueva con estado de pago "UNPAID", salvo que el pago se confirme en el mismo acto de creación de la orden, en cuyo caso el estado de pago DEBE reflejar la condición real de ese pago (pagado o parcialmente pagado).
- **FR-003**: El sistema DEBE crear todos los ítems de una orden nueva en estado "PENDIENTE", independientemente del estado de la orden a la que pertenecen.
- **FR-004**: El sistema DEBE eliminar el estado "RECIBIDA" como valor válido para órdenes e ítems, en todos los esquemas de tenant y en el esquema público.
- **FR-005**: El sistema DEBE migrar toda orden e ítem existente que tenga el estado "RECIBIDA" hacia el estado "PENDIENTE", sin pérdida de ningún otro dato de la orden o del ítem. Esta migración DEBE ejecutarse de forma automática como parte del mecanismo estándar de migración de esquema (p. ej. Alembic) durante el despliegue, recorriendo todos los esquemas de tenant y el esquema público, sin requerir un paso manual u operativo separado.
- **FR-006**: El sistema DEBE garantizar que, tras ejecutar la migración, no quede ningún registro de orden ni de ítem con el valor "RECIBIDA" en ningún esquema de ningún tenant.
- **FR-007**: El sistema DEBE rechazar, después de la migración, cualquier intento de crear o actualizar una orden o ítem con el valor "RECIBIDA", mediante una restricción a nivel de base de datos (tipo enum o constraint) en cada esquema de tenant y en el esquema público, de forma que la base de datos misma rechace el valor incluso si una futura ruta de código o una escritura directa lo intentara.
- **FR-008**: El frontend DEBE mostrar en toda pantalla que presente el estado de una orden o de un ítem (incluida la Terminal de Mesas y el detalle del pedido) exactamente el valor de estado entregado por la API, sin traducirlo a otro término ni inferirlo a partir de otros campos (como el estado de pago).
- **FR-009**: El frontend DEBE mostrar el valor crudo del estado cuando la API devuelva un estado que el frontend no tenga mapeado, y DEBE registrar un error en la consola en ese caso, sin sustituir ese valor por un estado por defecto (como "En preparación").
- **FR-010**: El sistema DEBE mantener disponible un catálogo único y autoritativo de los estados válidos de orden e ítem en el backend. El frontend DEBE mantener una lista propia de estados conocidos que refleje ese catálogo, usada únicamente para detectar y registrar en consola los estados no mapeados (ver FR-009); esta lista no se expone como un endpoint dinámico de catálogo, por lo que debe actualizarse manualmente cada vez que el catálogo autoritativo cambie.

### Key Entities

- **Orden**: Representa un pedido creado por cualquier canal (QR, caja, domicilio). Atributos relevantes a esta funcionalidad: estado (ej. "PENDIENTE"), estado de pago (ej. "UNPAID", pagado, parcialmente pagado), canal de origen, ítems asociados.
- **Ítem de orden**: Representa cada producto o línea dentro de una orden. Atributo relevante: estado propio (ej. "PENDIENTE"), independiente del estado de la orden que lo contiene.
- **Tenant / esquema**: Representa cada negocio/cliente del sistema, cada uno con su propio conjunto de datos (incluyendo órdenes e ítems) aislado en su propio esquema de base de datos. La migración de estados debe cubrir a todos ellos.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100% de las órdenes nuevas creadas desde cualquier canal (QR, caja, domicilio) quedan registradas con estado "PENDIENTE" y, salvo pago confirmado en la creación, con estado de pago "UNPAID".
- **SC-002**: El 100% de los ítems de órdenes nuevas quedan registrados con estado "PENDIENTE" al momento de la creación.
- **SC-003**: Después de ejecutar la migración, el 0% de las órdenes e ítems en cualquier esquema (de cualquier tenant) conserva el valor "RECIBIDA".
- **SC-004**: El 100% de las pantallas que muestran el estado de una orden o ítem presentan el mismo valor que devuelve la API, verificado comparando la respuesta de la API contra lo renderizado en pantalla, sin discrepancias por traducción o inferencia.
- **SC-005**: Ante un estado no reconocido devuelto por la API, el 100% de las veces el frontend muestra ese valor crudo en pantalla y deja constancia de un error en consola, en lugar de mostrar un estado por defecto.

## Assumptions

- "PENDIENTE" ya existe como estado válido de orden e ítem antes de esta funcionalidad; lo que cambia es que se convierte en el único estado inicial posible (reemplazando a "RECIBIDA") y en el estado que todos los canales deben usar al crear.
- El "acto de creación" de una orden incluye los casos donde el pago se confirma de inmediato (por ejemplo, venta de mostrador pagada en el momento), por lo que el estado de pago inicial puede ser distinto de "UNPAID" en esos casos, pero el estado de la orden en sí siempre es "PENDIENTE".
- La Terminal de Mesas y el detalle del pedido son las pantallas de referencia mencionadas en los criterios de aceptación; se asume que cualquier otra pantalla del sistema que muestre el estado de una orden o ítem (reportes, listados, notificaciones) debe seguir el mismo principio de no traducir ni inferir, por consistencia con el objetivo de la funcionalidad.
- Se asume que "todos los esquemas de tenant" se refiere al conjunto de esquemas de base de datos gestionados actualmente por el sistema multi-tenant, y que existe una forma de enumerarlos de manera confiable para que la migración los recorra a todos.
- Se asume que ya existe una noción de "pago confirmado en el mismo acto de creación" reconocible por el sistema (por ejemplo, un pago que se registra como parte de la misma operación de creación de la orden), sin necesidad de definir aquí un nuevo mecanismo para detectarlo.
