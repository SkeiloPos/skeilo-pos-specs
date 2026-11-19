# Feature Specification: Autogestión de suscripciones y pago de la membresía por link de pago (Wompi)

**Feature Branch**: `161-suscripcion-pago-wompi`

**Created**: 2026-11-17

**Status**: Draft

**Input**: User description: "Módulo de autogestión de suscripciones y membresías para los tenants de SkeiloPOS (alcance 100% Backend). Los administradores de cada tenant pagan su plan mensual mediante un link de pago único generado a demanda vía Wompi (Colombia), sin almacenar tarjetas ni gestionar métodos recurrentes. Se mantiene un historial auditado de transacciones y se aplican automáticamente: alerta previa (2 días antes del vencimiento, solo a los ADMIN), período de gracia de 5 días en el que todo opera normal, bloqueo total de los módulos al agotarse la gracia (el login nunca se bloquea) y recálculo inteligente de las fechas de vigencia según el momento en que se aprueba el pago."

## Clarifications

### Session 2026-11-17

- Q: Hoy el bloqueo por plan vencido solo se aplica al crear recursos limitados y al entrar a los módulos que dependen del plan (inventario, promociones, cocina); ventas, órdenes, caja, menú QR, catálogo y reportes no se bloquean. ¿Qué alcance tiene el "bloqueo total" y qué sigue disponible cuando el tenant está bloqueado? → A: El bloqueo pasa a ser total: toda operación del tenant se rechaza con acceso denegado, incluido el comensal que escanea el QR (menú y carrito públicos). Siguen disponibles únicamente: inicio de sesión, renovación y cierre de sesión, consulta de la sesión propia, arranque de la aplicación, consulta del plan, las operaciones de suscripción (link e historial) y las notificaciones. El rechazo lleva un código estable (`subscription_blocked`) que lo distingue del rechazo por "módulo fuera del plan" y de cualquier otro acceso denegado.
- Q: Las notificaciones actuales son del tenant completo y las ve cualquier rol del personal. ¿Cómo se logra que las alertas de suscripción las vean solo los ADMIN? → A: Se agrega a los eventos de notificación una audiencia por rol, aplicada en el listado, en el canal en tiempo real y en el aviso push. Los eventos existentes siguen dirigidos a todo el personal sin cambios.
- Q: ¿Cómo se genera el link de pago de Wompi? → A: Con el Web Checkout de Wompi: una dirección de pago firmada con el secreto de integridad, con referencia propia (generada por el sistema, única y determinista) y vencimiento propio. No se hace ninguna llamada a un servicio externo para generarlo. La dirección de retorno se arma por tenant con su subdominio.
- Q: ¿Qué pasa con los tenants de ciclo anual, sin vencimiento o con un plan sin precio mensual? → A: Solo se cobra el ciclo mensual, al precio mensual del plan. Un tenant sin vencimiento, con ciclo anual o con un plan sin precio mensual no puede pedir link (conflicto controlado); esos casos los gestiona el Super Admin. La renovación manual del Super Admin convive con este flujo y no se modifica.
- Q: ¿Se pueden pagar meses por adelantado? → A: No. Hay un único período abierto: con el ciclo en curso ya pagado (estado "activa") no se genera otro link; el siguiente link se habilita en "por vencer", "en gracia" o "bloqueada". Nunca se acumulan meses adelantados.
- Q: ¿Los 2 días de alerta y los 5 de gracia son calendario del tenant o exactos? → A: Exactos, contados desde la fecha de vencimiento: 48 horas antes para la alerta y 120 horas después para el fin de la gracia. La zona horaria del tenant solo decide cuándo se evalúan y emiten las alertas.
- Q: ¿Cómo se traducen los estados de Wompi y qué pasa con los casos límite? → A: "Aprobada" pasa a aprobado; "Rechazada" y "Error" pasan a rechazado; una "Anulación" posterior a una aprobación se registra sin revertir fechas (la resuelve soporte a mano); una aprobación que llega sobre un pago ya marcado como expirado se aplica igual (el dinero ya entró). El link pendiente vive 24 horas.
- Q: ¿Qué pasa con los tenants que ya están vencidos cuando se active esta funcionalidad? → A: Reciben la gracia completa de 5 días contada desde el despliegue (una sola vez), para no bloquearlos de golpe.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Conocer el estado de la suscripción del tenant (Priority: P1)

Cualquier usuario autenticado de un tenant puede consultar en qué estado está la suscripción de su negocio: **activa**, **por vencer**, **en gracia** o **bloqueada**, cuántos días restan y hasta qué fecha puede pagar antes del bloqueo. Un tenant sin fecha de vencimiento siempre aparece como activa.

**Why this priority**: Es la base de todo lo demás: el bloqueo, las alertas y la aceptación o rechazo de un link dependen de calcular el estado correcto y de forma única.

**Independent Test**: Con tenants de prueba cuya fecha de vencimiento esté en cada tramo (más de 48 h antes, justo dentro de las 48 h, recién vencido, a punto de cumplir 120 h, ya pasadas 120 h, sin vencimiento), consultar el plan y comprobar el estado, los días restantes y la fecha límite de pago en cada uno.

**Acceptance Scenarios**:

1. **Given** un tenant cuyo vencimiento está a más de 48 horas, **When** cualquier usuario consulta el plan, **Then** el estado es "activa".
2. **Given** un tenant cuyo vencimiento está dentro de las próximas 48 horas, **When** se consulta el plan, **Then** el estado es "por vencer".
3. **Given** un tenant cuyo vencimiento ya pasó hace menos de 120 horas, **When** se consulta el plan, **Then** el estado es "en gracia" y se informa la fecha límite de pago (vencimiento + 120 horas).
4. **Given** un tenant cuyo vencimiento pasó hace 120 horas o más, **When** se consulta el plan, **Then** el estado es "bloqueada".
5. **Given** un tenant sin fecha de vencimiento, **When** se consulta el plan, **Then** el estado es siempre "activa", sin días restantes ni fecha límite.

---

### User Story 2 - Operar sin interrupciones durante la gracia y bloqueo total al agotarse (Priority: P1)

Mientras el tenant está en gracia, todos los módulos funcionan con normalidad. Cuando la gracia se agota sin un pago aprobado, toda operación del tenant (personal y comensales por QR) se rechaza con acceso denegado, salvo las pocas operaciones necesarias para iniciar sesión, ver el estado del plan y pagar. El inicio de sesión nunca se bloquea.

**Why this priority**: Es la consecuencia de negocio de no pagar. Sin ella la suscripción no tiene fuerza; con ella mal hecha, un tenant al día podría quedar bloqueado o uno moroso seguiría vendiendo.

**Independent Test**: Con un tenant en gracia ejecutar operaciones de ventas, caja, órdenes, catálogo y módulos del plan y comprobar que funcionan; avanzar el reloj hasta pasar la gracia y comprobar que las mismas operaciones, y la carta pública por QR, responden acceso denegado con el código `subscription_blocked`, mientras que el inicio de sesión y la consulta del plan siguen funcionando.

**Acceptance Scenarios**:

1. **Given** un tenant en gracia, **When** su personal opera en ventas, caja, órdenes, catálogo, reportes o módulos dependientes del plan, **Then** todo funciona sin restricciones adicionales.
2. **Given** un tenant bloqueado, **When** su personal intenta cualquier operación de negocio, **Then** recibe acceso denegado con el código estable `subscription_blocked`.
3. **Given** un tenant bloqueado, **When** un comensal abre la carta pública por QR o intenta enviar un carrito, **Then** recibe acceso denegado con el mismo código.
4. **Given** un tenant bloqueado, **When** un usuario inicia sesión, renueva o cierra su sesión, consulta su sesión propia, arranca la aplicación, consulta el plan, usa las operaciones de suscripción o lee sus notificaciones, **Then** esas operaciones funcionan normalmente.
5. **Given** un tenant bloqueado que acaba de recibir un pago aprobado, **When** su personal repite una operación bloqueada en la solicitud siguiente, **Then** funciona sin tener que volver a iniciar sesión.
6. **Given** uno o varios tenants bloqueados, **When** el Super Admin usa su panel, se consulta la verificación de salud del servicio o llega un aviso de Wompi, **Then** esas operaciones de plataforma funcionan normalmente, porque nunca dependen de la suscripción de un tenant.

---

### User Story 3 - El ADMIN genera un link de pago para renovar (Priority: P1)

Un usuario ADMIN del tenant presiona "Pagar ahora" y el sistema le entrega un link de pago de Wompi por el valor del plan mensual. Si ya tenía un link pendiente que no ha expirado, se le entrega el mismo. Los demás roles no pueden generar links.

**Why this priority**: Sin un link no hay cobro; es la entrada del flujo de ingresos de la suscripción.

**Independent Test**: Con un tenant por vencer iniciar sesión como ADMIN, pedir el link y comprobar el monto, la expiración y que una segunda petición devuelve el mismo link; repetir como cajero (acceso denegado) y con un tenant en cada estado y en cada caso no cobrable.

**Acceptance Scenarios**:

1. **Given** un tenant "por vencer", "en gracia" o "bloqueada" y un ADMIN, **When** solicita el link de pago, **Then** recibe una dirección de pago por el precio mensual de su plan, con referencia única y vencimiento de 24 horas.
2. **Given** un ADMIN que ya solicitó un link y este sigue vigente (no expirado, no pagado), **When** vuelve a solicitarlo, **Then** recibe el mismo link, sin crear otro registro de pago.
3. **Given** un link pendiente que ya expiró, **When** el ADMIN solicita uno nuevo, **Then** el anterior queda marcado como expirado y se crea un link nuevo.
4. **Given** un usuario sin rol ADMIN (cajero, mesero, cocina), **When** solicita el link, **Then** recibe acceso denegado.
5. **Given** un tenant "activa" (ciclo en curso ya pagado), **When** el ADMIN solicita un link, **Then** recibe un conflicto controlado que explica que no hay un pago pendiente en este momento.
6. **Given** un tenant sin vencimiento, con ciclo anual o con un plan sin precio mensual, **When** el ADMIN solicita un link, **Then** recibe un conflicto controlado que explica que su renovación la gestiona la plataforma.
7. **Given** que las credenciales de Wompi no están configuradas en el entorno, **When** el ADMIN solicita un link, **Then** recibe un error claro de servicio no disponible (nunca un error interno genérico) y no se deja ningún pago pendiente.
8. **Given** dos ADMIN que solicitan el link al mismo tiempo, **When** ambas peticiones se procesan, **Then** existe un único pago pendiente y ambos reciben el mismo link.

---

### User Story 4 - El pago aprobado renueva la suscripción de forma automática (Priority: P1)

Cuando Wompi avisa que el pago fue aprobado, el sistema registra el pago, extiende la vigencia según el momento del pago y desbloquea el tenant al instante. Si Wompi avisa que fue rechazado, el pago queda registrado como rechazado y las fechas no cambian. El aviso es público, se verifica con una firma y puede llegar repetido sin efectos duplicados.

**Why this priority**: Cierra el ciclo de cobro: sin esta confirmación automática, soporte tendría que renovar a mano cada pago.

**Independent Test**: Simular avisos de Wompi con firma válida (aprobado, rechazado, repetido, con firma alterada, con referencia desconocida, con monto distinto) sobre tenants en cada estado y comprobar las fechas resultantes y el desbloqueo.

**Acceptance Scenarios**:

1. **Given** un pago pendiente de un tenant "por vencer" o "en gracia", **When** llega un aviso de aprobación válido, **Then** el pago pasa a aprobado con su fecha de pago, la nueva vigencia comienza en el vencimiento anterior y termina un mes después, y el estado pasa a "activa".
2. **Given** un pago pendiente de un tenant "bloqueada", **When** llega un aviso de aprobación válido, **Then** la nueva vigencia comienza en la fecha del pago y termina un mes después, y el tenant queda desbloqueado de inmediato.
3. **Given** un pago ya aprobado, **When** el mismo aviso llega de nuevo, **Then** no se vuelve a extender la vigencia ni se crea ningún otro registro; la respuesta es exitosa para que Wompi no reintente.
4. **Given** un aviso con firma inválida o ausente, **When** llega, **Then** se rechaza con un error de solicitud/autenticación y no se modifica ningún dato.
5. **Given** un pago pendiente, **When** llega un aviso de rechazo o de error, **Then** el pago queda como rechazado, las fechas no cambian y el ADMIN puede solicitar un link nuevo.
6. **Given** un pago aprobado, **When** llega una anulación posterior, **Then** el pago queda registrado como anulado sin revertir las fechas.
7. **Given** un pago que ya expiró, **When** llega una aprobación válida para él, **Then** se aplica igual (el dinero ya entró).
8. **Given** una aprobación con firma válida cuya referencia no corresponde a ningún pago, **When** llega, **Then** no tiene efecto sobre ningún tenant y queda constancia para revisión, sin provocar reintentos indefinidos.

---

### User Story 5 - Los ADMIN reciben alertas de vencimiento, gracia y bloqueo (Priority: P2)

El sistema avisa dentro de la aplicación, y solo a los usuarios ADMIN del tenant, tres momentos: 48 horas antes del vencimiento, cuando inicia la gracia y cuando se bloquea. Cada aviso se emite una sola vez por ciclo de vencimiento. Los demás roles no ven estos avisos.

**Why this priority**: Reduce la mora y las sorpresas, pero el cobro y el bloqueo funcionan sin ellas; por eso es P2.

**Independent Test**: Con un tenant por vencer ejecutar la evaluación periódica varias veces y comprobar que se genera un solo aviso, que lo ven los ADMIN y no un cajero; avanzar el reloj por cada hito y repetir.

**Acceptance Scenarios**:

1. **Given** un tenant que entra en las últimas 48 horas antes de su vencimiento, **When** corre la evaluación periódica, **Then** se genera un aviso "por vencer" visible solo para los ADMIN.
2. **Given** un tenant que acaba de vencer, **When** corre la evaluación, **Then** se genera un aviso "inició la gracia" con la fecha límite de pago.
3. **Given** un tenant que agotó la gracia, **When** corre la evaluación, **Then** se genera un aviso "bloqueado" que el ADMIN puede leer aunque el resto del sistema esté bloqueado.
4. **Given** que la evaluación se ejecuta muchas veces, o simultáneamente en varias instancias, **When** el estado del tenant no cambia, **Then** no se duplica ningún aviso.
5. **Given** un tenant que pagó y comenzó un nuevo ciclo de vencimiento, **When** se acerca el nuevo vencimiento, **Then** vuelven a generarse sus tres avisos para ese nuevo ciclo.
6. **Given** una notificación de suscripción, **When** un cajero, mesero o personal de cocina lista sus notificaciones o recibe avisos en tiempo real o push, **Then** no recibe ni ve esa notificación; las demás notificaciones (pedidos, pagos) siguen llegando a todo el personal como antes.
7. **Given** un tenant que cruzó el umbral de "por vencer" a las 23:00 hora local, **When** corre la evaluación periódica, **Then** el aviso no se emite hasta que la hora local entre en la ventana diurna.

---

### User Story 6 - Consultar el historial de pagos de suscripción (Priority: P2)

El ADMIN de un tenant ve el historial de los pagos de suscripción de su propio negocio, del más reciente al más antiguo y paginado. El Super Admin ve el historial de cualquier tenant para soporte y auditoría.

**Why this priority**: Da trazabilidad y permite resolver reclamos, pero no es necesario para cobrar ni para bloquear.

**Independent Test**: Con pagos de dos tenants, consultar el historial como ADMIN de cada uno y comprobar que solo ve los propios, ordenados y paginados; consultar como Super Admin el de cada tenant; consultar como cajero (acceso denegado).

**Acceptance Scenarios**:

1. **Given** un tenant con varios pagos, **When** su ADMIN consulta el historial, **Then** recibe los pagos de ese tenant, del más reciente al más antiguo, en páginas.
2. **Given** pagos de otro tenant, **When** el ADMIN consulta su historial, **Then** no aparece ninguno de ellos.
3. **Given** un usuario no ADMIN, **When** consulta el historial, **Then** recibe acceso denegado.
4. **Given** el Super Admin, **When** consulta el historial de un tenant cualquiera, **Then** ve todos sus pagos con estado, monto, referencia, quién lo solicitó y fechas de período y de pago.

---

### User Story 7 - Activar la funcionalidad sin bloquear de golpe a los tenants ya vencidos (Priority: P2)

Al poner en marcha la funcionalidad, los tenants que ya tienen la fecha de vencimiento pasada reciben la gracia completa de 5 días contada desde el despliegue, en lugar de quedar bloqueados de inmediato por la nueva regla.

**Why this priority**: Protege la operación de negocios reales en el momento del cambio; se ejecuta una sola vez.

**Independent Test**: Con tenants vencidos hace más de 5 días, vencidos hace pocas horas y vigentes, activar la funcionalidad y comprobar que ninguno queda bloqueado en el arranque, que los vencidos disponen de 5 días completos y que los vigentes no cambian.

**Acceptance Scenarios**:

1. **Given** un tenant vencido hace más de 5 días antes del despliegue, **When** se activa la funcionalidad, **Then** queda "en gracia" con la fecha límite de pago a 5 días del despliegue.
2. **Given** un tenant vigente o sin vencimiento, **When** se activa la funcionalidad, **Then** sus fechas no cambian.
3. **Given** que el procedimiento se ejecuta una segunda vez, **When** termina, **Then** no vuelve a extender la gracia de nadie.

---

### Edge Cases

- **Aviso duplicado o fuera de orden**: Wompi puede reenviar el mismo aviso o enviar un rechazo después de una aprobación; el resultado final del pago nunca retrocede de aprobado a rechazado.
- **Monto o moneda distintos**: un aviso cuyo monto o moneda no coincide con el pago registrado no se aplica ni mueve fechas; queda constancia para revisión de soporte.
- **Referencia desconocida con firma válida**: se ignora sin efecto y sin una respuesta de error que dispare reintentos indefinidos.
- **Super Admin cambia el plan o el ciclo con un link pendiente**: al aprobarse, si el tenant sigue con ciclo mensual y vencimiento, se aplica la regla de recálculo con las fechas vigentes en ese momento; si dejó de tener ciclo mensual con vencimiento, el pago queda aprobado pero no altera fechas y soporte lo resuelve.
- **Renovación manual del Super Admin con un link pendiente**: el link sigue vigente hasta expirar; si se aprueba, se aplica igual (el dinero ya entró).
- **Un link generado en un estado y pagado en otro**: las fechas de la nueva vigencia se calculan siempre con el momento real de aprobación, no con el momento en que se creó el link.
- **Fin de mes**: el cálculo de "un mes" sigue la regla ya existente del sistema (con sus ajustes de fin de mes); se acepta la deriva de fechas en vencimientos que caen en día 29, 30 o 31.
- **Tenant sin usuarios ADMIN activos**: el aviso se registra igualmente; queda disponible cuando exista un ADMIN.
- **Evaluación periódica detenida varios días**: al reanudarse emite únicamente el aviso correspondiente al estado vigente que aún no se haya enviado en ese ciclo (no avisa "vence en 2 días" a un tenant que ya está bloqueado).
- **Conexión en tiempo real del personal con el tenant bloqueado**: sigue disponible para que el ADMIN reciba el aviso de bloqueo en vivo.
- **Pago aprobado al mismo tiempo que se cumple la gracia**: la decisión de qué fórmula de recálculo aplica se toma con el estado vigente en el instante de procesar la aprobación, de forma consistente y sin ventanas intermedias.
- **Credenciales de Wompi rotadas o ausentes**: ausencia de credenciales de generación impide crear links (error claro); ausencia del secreto de eventos hace que todo aviso se rechace por firma inválida.

## Requirements *(mandatory)*

### Functional Requirements

**Estado de la suscripción y plazos**

- **FR-001**: El sistema MUST derivar el estado de la suscripción de cada tenant a partir de su fecha de vencimiento, con estos tramos exactos (UTC): "activa" (faltan más de 48 horas, o no hay vencimiento), "por vencer" (faltan 48 horas o menos y aún no vence), "en gracia" (venció hace menos de 120 horas) y "bloqueada" (venció hace 120 horas o más).
- **FR-002**: El sistema MUST calcular la fecha límite de pago como la fecha de vencimiento más 120 horas, y los días restantes como el número de días enteros (redondeado hacia arriba) que faltan hasta el vencimiento mientras no ha vencido, hasta la fecha límite de pago durante la gracia, y cero cuando está bloqueada.
- **FR-003**: Un tenant sin fecha de vencimiento MUST estar siempre en estado "activa", sin días restantes ni fecha límite.
- **FR-004**: La consulta del plan del tenant MUST exponer el estado de suscripción, los días restantes y la fecha límite de pago, a cualquier usuario autenticado del tenant, y MUST conservar el campo `vencido` existente; `vencido` pasa a significar "bloqueada" (verdadero únicamente al agotarse la gracia), de modo que los módulos que el frontend oculta cuando `vencido` es verdadero no se oculten durante la gracia.

**Acceso durante la gracia y bloqueo total**

- **FR-005**: Durante el estado "en gracia" el sistema MUST permitir todas las operaciones del tenant sin ninguna restricción adicional, incluidos los límites de recursos y los módulos dependientes del plan.
- **FR-006**: En estado "bloqueada" el sistema MUST rechazar con acceso denegado toda operación del tenant, tanto del personal como del comensal que usa el menú y el carrito públicos por QR, salvo las operaciones exentas de FR-008.
- **FR-007**: El rechazo por suscripción bloqueada MUST incluir el código estable `subscription_blocked` y un mensaje claro, distinguibles del rechazo por módulo fuera del plan y de cualquier otro acceso denegado.
- **FR-008**: En estado "bloqueada" MUST seguir disponible: inicio de sesión, renovación y cierre de sesión, consulta de la sesión propia, arranque de la aplicación, consulta del plan, las operaciones de suscripción (solicitar link e historial), las notificaciones y la conexión en tiempo real del personal. Las operaciones de plataforma (panel Super Admin, verificación de salud del servicio y el aviso de Wompi) MUST estar siempre exentas del bloqueo por suscripción.
- **FR-009**: El bloqueo y el desbloqueo MUST tener efecto inmediato: la solicitud siguiente a un pago aprobado funciona sin que el usuario deba iniciar sesión de nuevo, y el estado nunca depende de datos almacenados en memoria o en sesión que puedan quedar obsoletos.
- **FR-010**: El inicio de sesión MUST NOT bloquearse nunca por el estado de la suscripción.

**Link de pago**

- **FR-011**: Solo un usuario con rol ADMIN del tenant MUST poder solicitar el link de pago; cualquier otro rol recibe acceso denegado.
- **FR-012**: El sistema MUST permitir solicitar el link en los estados "por vencer", "en gracia" y "bloqueada". En estado "activa" MUST responder con un conflicto controlado (no se permiten pagos por adelantado ni acumular meses).
- **FR-013**: El sistema MUST responder con un conflicto controlado, sin crear ningún pago, cuando el tenant no tiene fecha de vencimiento, tiene ciclo anual, o su plan no tiene precio mensual definido.
- **FR-014**: El monto del link MUST ser el precio mensual del plan vigente del tenant, en pesos colombianos, como total a cobrar (sin impuestos adicionales), expresado a Wompi en centavos.
- **FR-015**: Cada link MUST tener una referencia única generada por el sistema, una vigencia de 24 horas, una firma de integridad calculada con el secreto de integridad de Wompi y una dirección de retorno armada con el subdominio del tenant. El sistema MUST NOT llamar a ningún servicio externo para generarlo y MUST NOT almacenar datos de tarjetas ni métodos de pago recurrentes.
- **FR-016**: Si el tenant ya tiene un pago pendiente cuyo link no ha expirado, el sistema MUST devolver ese mismo link sin crear un registro nuevo. Un link pendiente expirado MUST marcarse como expirado y generarse uno nuevo. Dos solicitudes simultáneas MUST resultar en un único pago pendiente.
- **FR-017**: Si faltan las credenciales de generación del link en la configuración del entorno, el sistema MUST responder con un error claro de servicio no disponible, nunca con un error interno genérico, y MUST NOT dejar un pago pendiente. Los secretos y llaves de Wompi MUST NOT aparecer en respuestas, notificaciones ni registros de la aplicación.
- **FR-018**: Al generar un link el sistema MUST registrar el pago con el tenant, el plan, el ciclo, el monto, la referencia, la dirección y la vigencia del link, el usuario que lo solicitó y el estado "pendiente".

**Confirmación del pago**

- **FR-019**: El sistema MUST ofrecer una operación pública de recepción de avisos de Wompi que verifique la firma del aviso con el secreto de eventos; si la firma falta o es inválida MUST rechazar el aviso sin modificar ningún dato.
- **FR-020**: El sistema MUST identificar el tenant a partir de la referencia del aviso (el aviso no llega por el subdominio del tenant) y MUST procesar cada referencia de forma idempotente: un aviso repetido no extiende la vigencia dos veces ni crea registros adicionales.
- **FR-021**: El sistema MUST traducir los estados de Wompi así: aprobada → aprobado; rechazada y error → rechazado; anulación → anulado.
- **FR-022**: Ante una aprobación, el sistema MUST registrar la fecha de pago y el período cubierto, y MUST recalcular la vigencia del tenant: si el pago se aprueba antes del vencimiento o durante la gracia, el nuevo vencimiento es el vencimiento anterior más un mes y el inicio del período es el vencimiento anterior; si se aprueba con el tenant bloqueado, el nuevo vencimiento es la fecha de pago más un mes y el inicio del período es la fecha de pago.
- **FR-023**: Ante una aprobación, el registro del pago y el cambio de vigencia del tenant MUST ocurrir de forma atómica (o ambos o ninguno) y el desbloqueo MUST ser inmediato (FR-009).
- **FR-024**: Ante un rechazo o error, el sistema MUST marcar el pago como rechazado sin alterar las fechas del tenant. Ante una anulación posterior a una aprobación, MUST registrarla sin revertir fechas. Un resultado aprobado MUST NOT retroceder a rechazado por un aviso tardío.
- **FR-025**: Una aprobación que llegue para un pago marcado como expirado MUST aplicarse igual, con la misma regla de FR-022.
- **FR-026**: Un aviso cuyo monto o moneda no coincida con el pago registrado MUST NOT aplicarse ni mover fechas; un aviso con referencia desconocida MUST ignorarse sin efecto; en ambos casos MUST quedar constancia para revisión y la respuesta MUST evitar reintentos indefinidos del proveedor.
- **FR-027**: Si al aprobarse el pago el tenant ya no tiene ciclo mensual con vencimiento, el pago MUST quedar aprobado sin alterar fechas, dejando constancia para que soporte lo resuelva.

**Alertas**

- **FR-028**: El sistema MUST generar tres avisos dentro de la aplicación por ciclo de vencimiento: "por vencer" (al entrar en las últimas 48 horas), "inició la gracia" (al vencer, con la fecha límite de pago) y "bloqueado" (al agotarse la gracia); ninguno bloquea la operación.
- **FR-029**: Cada aviso MUST emitirse una sola vez por ciclo de vencimiento y por tenant, aunque la evaluación periódica se ejecute muchas veces o en varias instancias a la vez; un nuevo ciclo (tras un pago aprobado) reinicia los tres avisos.
- **FR-030**: La evaluación periódica MUST considerar la zona horaria de cada tenant únicamente para decidir **cuándo se emite** el aviso: solo se emite mientras la hora local del tenant esté dentro de una ventana diurna configurable (por defecto de 8:00 a 20:00); fuera de ella se espera a la siguiente evaluación. Los tramos exactos de FR-001 no cambian, así que un aviso puede salir hasta ~12 horas después de su umbral.
- **FR-031**: Los avisos de suscripción MUST estar dirigidos solo a usuarios con rol ADMIN del tenant: el sistema MUST agregar a los eventos de notificación una audiencia por rol y aplicarla en el listado de notificaciones, en el canal en tiempo real y en el aviso push. Los eventos existentes MUST seguir dirigiéndose a todo el personal, sin cambios de comportamiento.
- **FR-032**: Tras reanudarse una evaluación detenida, el sistema MUST emitir únicamente el aviso del estado vigente que aún no se haya enviado en ese ciclo.

**Historial**

- **FR-033**: El ADMIN MUST poder consultar el historial de pagos de suscripción de su propio tenant, paginado y ordenado del más reciente al más antiguo, con aislamiento estricto: nunca ve pagos de otro tenant. Los demás roles reciben acceso denegado.
- **FR-034**: El Super Admin MUST poder consultar el historial de pagos de cualquier tenant, con los mismos datos y orden.
- **FR-035**: El historial MUST mostrar por pago: estado, monto, ciclo, referencia, quién lo solicitó, fechas del período cubierto, fecha de pago y fechas de creación y actualización; MUST NOT exponer firmas ni secretos de la pasarela.

**Datos, compatibilidad y despliegue**

- **FR-036**: El sistema MUST guardar los pagos de suscripción en una entidad nueva, compartida entre tenants, con referencia de pasarela única y los campos descritos en Key Entities. Es una tabla nueva: no modifica ni reinterpreta datos existentes y su reversión consiste en eliminarla.
- **FR-037**: El campo de audiencia de los eventos de notificación MUST ser opcional y su ausencia MUST significar "todo el personal", de modo que las notificaciones existentes conserven su comportamiento sin migrar datos; su reversión consiste en retirar ese campo.
- **FR-038**: Al activar la funcionalidad, los tenants con vencimiento ya pasado MUST recibir la gracia completa de 5 días contada desde el despliegue, mediante un procedimiento de una sola vez e idempotente; los tenants vigentes o sin vencimiento MUST permanecer sin cambios.
- **FR-039**: La renovación manual del Super Admin (asignación de plan y ciclo con reinicio de fechas) MUST seguir funcionando sin cambios y convivir con este flujo.
- **FR-040**: Los pagos de suscripción MUST NOT modificar, reemitir ni recalcular ninguna factura de venta ya emitida (Principio VII de la constitución); son una entidad distinta de las facturas de los comensales.

**Verificación y gobernanza**

- **FR-041**: Toda la funcionalidad MUST poder verificarse sin una cuenta de Wompi, con firmas de integridad y de eventos calculadas en las pruebas automáticas; la prueba real contra el entorno de pruebas de Wompi MUST quedar registrada como tarea explícita pendiente hasta que exista la cuenta y sus credenciales.
- **FR-042**: La funcionalidad MUST NOT introducir dependencias nuevas de terceros: la firma y la verificación usan la biblioteca estándar (Principio IX).
- **FR-043**: Antes de implementar, cada cambio sobre comportamiento existente listado abajo MUST quedar registrado en el registro de anomalías con quién decidió y cuándo (Principio II). Las pruebas existentes de expiración de plan (spec 033) y de notificaciones (spec 077) MUST seguir pasando; solo se modifican las que choquen con el nuevo plazo de gracia, citando esta decisión en el mismo commit (Principio III).

### Cambios sobre comportamiento existente (Principio II)

| Comportamiento actual | Nuevo comportamiento | Decisión |
|---|---|---|
| Al pasar `plan_vence_en` el tenant se bloquea de inmediato. | Hay 5 días de gracia con todo operativo; el bloqueo llega a las 120 h. | Usuario, 2026-11-17 |
| El bloqueo por vencimiento solo alcanza la creación de recursos limitados y los módulos dependientes del plan. | Bloqueo total de toda operación del tenant (incluido el comensal por QR), con `subscription_blocked`. | Usuario, 2026-11-17 |
| `vencido` es verdadero desde que pasa `plan_vence_en`. | `vencido` es verdadero solo al agotarse la gracia (equivale a "bloqueada"). Derivado de la regla de gracia; el frontend no requiere cambios para respetarla. | Derivado de la decisión de gracia (confirmar en revisión) |
| Las notificaciones son del tenant completo y las ve todo el personal. | Los eventos admiten una audiencia por rol; los de suscripción solo para ADMIN. Los demás no cambian. | Usuario, 2026-11-17 |

### Contratos de interfaz acordados

Nombres de rutas y campos fijados en el requerimiento original; el resto del diseño se resuelve en el plan.

| Operación | Quién | Resumen |
|---|---|---|
| `GET /plan` (existente) | Cualquier usuario autenticado del tenant | Agrega estado de suscripción, días restantes y fecha límite de pago; conserva `vencido`. |
| `POST /plan/subscription/payment-link` | ADMIN del tenant | Entrega el link de pago pendiente vigente o crea uno. |
| `GET /plan/subscription/payments` | ADMIN del tenant | Historial paginado de pagos de su tenant, orden descendente. |
| `GET /super-admin/tenants/{id}/subscription-payments` | Super Admin | Historial de pagos de un tenant. |
| `POST /webhooks/wompi` | Público, verificado por firma | Recibe los avisos de Wompi. |
| Notificaciones (existentes) | Personal del tenant | Agregan los tipos de aviso de suscripción: por vencer, inició la gracia, bloqueado. |

### Key Entities *(include if feature involves data)*

- **Suscripción del tenant** (ya existente en el tenant): plan vigente, ciclo, fecha de inicio y fecha de vencimiento. Esta spec no agrega campos aquí; deriva de ellos el estado y los plazos.
- **Pago de suscripción** (nueva): identificador; tenant; plan; ciclo; monto; estado (pendiente, aprobado, rechazado, expirado, anulado); pasarela; referencia de pasarela única; identificador de la transacción en la pasarela (opcional, se llena con el aviso y no puede repetirse en dos pagos); dirección del link y su vencimiento; usuario que lo solicitó; inicio y fin del período cubierto (se llenan al aprobarse); fecha de pago; fechas de creación y actualización.
- **Link de pago**: dirección de Wompi firmada y de un solo cargo; vive 24 horas; está respaldado por un único pago pendiente.
- **Aviso de suscripción** (extiende las notificaciones existentes): tipo (por vencer, inició la gracia, bloqueado), ciclo de vencimiento al que pertenece y audiencia por rol.
- **Estado de suscripción**: valor derivado (activa, por vencer, en gracia, bloqueada); no se almacena.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: En el 100 % de los casos de borde del cálculo (justo antes y después de 48 h antes del vencimiento, en el instante del vencimiento, a 119 h 59 min y a 120 h después, y sin vencimiento) el estado informado es el correcto.
- **SC-002**: Con un tenant en gracia, 0 operaciones del personal o de los comensales son rechazadas por motivos de suscripción.
- **SC-003**: Con un tenant bloqueado, el 100 % de las operaciones no exentas (personal y QR) se rechazan con el código `subscription_blocked`, y el 100 % de las exentas (inicio de sesión, plan, suscripción, notificaciones) siguen funcionando.
- **SC-004**: Tras un pago aprobado, el tenant opera con normalidad en la solicitud siguiente, sin volver a iniciar sesión, en el 100 % de los casos.
- **SC-005**: Un mismo aviso de aprobación entregado cinco veces extiende la vigencia exactamente un mes, el 100 % de las veces.
- **SC-006**: El 100 % de los avisos con firma ausente o alterada se rechazan sin ningún cambio de datos.
- **SC-007**: Un ADMIN obtiene su link de pago en menos de 2 segundos en el 95 % de las solicitudes, y dos solicitudes simultáneas nunca producen más de un pago pendiente.
- **SC-008**: Cada tenant recibe como máximo un aviso de cada tipo por ciclo de vencimiento, aunque la evaluación periódica corra 100 veces o en varias instancias a la vez.
- **SC-009**: 0 usuarios con rol distinto de ADMIN ven un aviso de suscripción (en listado, en tiempo real o push), y el 100 % de las notificaciones de pedidos y pagos siguen llegando a todo el personal como antes.
- **SC-010**: 0 pagos de otro tenant aparecen en el historial de un ADMIN, en el 100 % de las pruebas de aislamiento.
- **SC-011**: Al activar la funcionalidad, 0 tenants quedan bloqueados en el arranque y el 100 % de los que estaban vencidos disponen de 5 días completos de gracia.
- **SC-012**: El 100 % de las pruebas automáticas existentes de planes y de notificaciones siguen en verde, salvo las que cambian por el plazo de gracia, que se actualizan citando esta decisión.

## Assumptions

- Esta spec cubre únicamente el backend (`pos-backend`) y sus documentos en `pos-specs`; no toca `pos-heladeria` ni la landing. El botón "Pagar ahora", la pantalla de bloqueo y la presentación de alertas quedan para una spec de frontend posterior.
- Hoy no existe cuenta de Wompi ni credenciales. La funcionalidad se construye y verifica con pruebas automáticas que calculan las firmas; la prueba real contra el entorno de pruebas de Wompi es una tarea pendiente explícita hasta que se cree la cuenta. Mientras tanto la generación del link responde con servicio no disponible (FR-017).
- Los secretos y llaves de Wompi (llave pública, secreto de integridad, secreto de eventos, direcciones base del checkout y de retorno) se configuran por entorno; no se almacenan en la base de datos.
- La moneda es el peso colombiano; el precio mensual del plan es el total a cobrar, sin impuestos adicionales ni descuentos.
- El cálculo de "un mes" reutiliza la regla ya existente del sistema; se acepta la deriva de fin de mes.
- La dirección de retorno tras el pago es `https://{subdominio-del-tenant}.<dominio>/...`; la página de destino la define la spec de frontend, y mientras no exista, el retorno cae en la página principal del tenant.
- El webhook de Wompi no llega por el subdominio del tenant: el tenant se resuelve desde la referencia del pago. Una aprobación no genera notificación (solo existen los tres avisos de FR-028), así que el webhook trabaja únicamente sobre los datos compartidos; las notificaciones, que viven en el esquema de cada tenant, las emite solo la evaluación periódica al recorrer los tenants.
- La conexión en tiempo real del personal queda exenta del bloqueo aunque no figuraba en la lista acordada de rutas exentas: es el canal por el que el ADMIN recibe en vivo el aviso de bloqueo (FR-031), y sin ella ese aviso solo se vería al recargar. Se deja como supuesto a confirmar en revisión.
- La ventana diurna de emisión de avisos (8:00 a 20:00 hora local) es una decisión del plan para dar contenido a FR-030; es configurable (con `0` y `24` se desactiva) y debe confirmarse con el negocio.
- La evaluación periódica de alertas reutiliza el planificador existente, con bloqueo entre instancias, igual que los demás trabajos periódicos del sistema.
- `dias_restantes` se define como lo indica FR-002; si el equipo de frontend necesita otra convención, se ajusta en la spec de frontend sin cambiar el contrato de fechas.
- Fuera de alcance: cobro anual o por adelantado, tarjetas guardadas y cobros recurrentes, reembolsos automáticos, facturación electrónica de la propia suscripción, avisos por correo o mensajería, y la gestión del Super Admin de tenants con ciclo anual o sin vencimiento (que sigue como hoy).
- Las dos migraciones de esta spec se encadenan tras las de la spec 162 (documentos legales) para dejar una sola cabeza de Alembic; el procedimiento para aplicarlas sobre una base existente (incluido el caso de la base de desarrollo estampada en un archivo de fusión local) está en `research.md` Decisión 14. La migración de la spec 162 `b1c9f4e7a3d2` borra una columna propia de esa spec y viaja en el mismo `upgrade`.
- La aceptación de los documentos legales de la plataforma por el ADMIN (`/legal/platform-acceptance`, spec 162) queda exenta del bloqueo, igual que el inicio de sesión: es un requisito de la plataforma, no una operación del negocio, y bloquearla podría dejar al ADMIN de un tenant bloqueado atrapado antes de llegar a pagar. El resto de `/legal` (perfil y documento legal del tenant) sí se bloquea. Decisión tomada al integrar con la spec 162, pendiente de confirmación.
- Este alcance se apoya en specs previas: planes y suscripciones de tenant (033), notificaciones (077), aislamiento del panel de plataforma (091), zonas horarias por tenant (138) y gestión global de usuarios (159).
