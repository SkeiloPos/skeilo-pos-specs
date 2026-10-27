# Feature Specification: Soporte de zonas horarias por tenant sin desfases (deuda técnica de fechas)

**Feature Branch**: `138-soporte-zona-horaria-tenant`

**Created**: 2026-10-25

**Status**: Draft

**Input**: User description: "Soporte de zonas horarias por tenant sin desfases (deuda técnica de fechas). Hoy el POS funciona bien porque servidor, tenants y navegadores están en Bogotá (UTC-5). Vamos a tener clientes en otras zonas (Ciudad de México, Madrid, Tokio). Cada negocio debe ver, filtrar, reportar e imprimir sus fechas en SU zona horaria, sin desfases, y las reglas que dependen de la hora (promociones, «hoy», rechazos del día) deben evaluarse en la zona del negocio. Corrección de comportamiento existente y deuda técnica, no una funcionalidad nueva; no duplica lo resuelto por las specs 022, 023, 030 y 127. Solicitada por el equipo de desarrollo el 2026-10-25."

> **Naturaleza de esta spec**: corrección de comportamiento existente y deuda técnica (Principios II y III de la
> constitución). Las evidencias a nivel de código (archivos, líneas, esquemas) que originan cada requisito están en
> [`hallazgos.md`](./hallazgos.md) para que la planificación las confirme; esta spec describe solo el comportamiento
> esperado. Las anomalías se registran en
> [`registro-de-anomalías`](../000-reconocimiento/registro-de-anomalias.md) como **A-147**, **A-148** y **A-149**.

## Alcance y relación con specs previas

Las specs [022](../022-correccion-zona-horaria-menu-carrito/spec.md),
[023](../023-correccion-zona-horaria-pos-staff/spec.md),
[030](../030-correccion-fechas-zona-horaria/spec.md) y [127](../127-fix-zona-horaria-promociones/spec.md) crearon el
mecanismo central: zona horaria configurable por tenant, cálculo único de los límites del día de negocio, serialización
de instantes con offset UTC explícito y presentación de fechas en la zona del tenant. **Esta spec no vuelve a diseñar
ese mecanismo**: cierra los lugares que quedaron sin usarlo y lo blinda con pruebas y verificaciones automáticas.

**Convención vigente que se conserva**: todo instante se guarda en UTC; la zona del tenant se aplica solo al filtrar,
agrupar y mostrar. **Excepción por diseño**: los campos de promociones que son hora de pared local (inicio y fin de
vigencia, hora de inicio y hora de fin de la ventana diaria).

**Fuera de alcance**: cambiar el tipo de las columnas de fecha, migrar o recalcular datos históricos, pantalla de
autoservicio para cambiar la zona de un tenant ya creado, y el sitio de aterrizaje (`skeilo-pos-landing`).

## Clarifications

### Session 2026-10-25

- Q: ¿Qué etiqueta de zona llevan los correos que muestran hora (FR-011) y qué zona usan los usuarios sin tenant (p. ej. Super Admin)? → A: Un tenant cuya zona es Bogotá conserva exactamente «(hora de Colombia)» (comportamiento protegido por pruebas de caracterización, FR-013). Cualquier otra zona de la lista del selector usa su nombre en español, por ejemplo «(hora de Ciudad de México)». Una zona válida que no esté en esa lista muestra solo el desfase, por ejemplo «(UTC−3)». Los usuarios sin tenant usan Bogotá.
- Q: FR-013 y CA-8 dicen que Bogotá «no cambia», pero corregir el cálculo de «hoy» en el segundo rechazo (C), el día usado en el nombre del archivo de exportación de inventario (E) y los instantes sin offset (D) sí cambia lo que recibe y ve un tenant de Bogotá. ¿Son excepciones? → A: Sí. FR-013 aplica a todo lo demás; las excepciones explícitas son (1) el día de negocio entre las 19:00 y las 24:00 (C y el nombre del archivo de inventario, A-147) y (2) los instantes sin offset (D, A-148), registradas como decisiones en el registro de anomalías. Quien decide: equipo de desarrollo, 2026-10-25, **pendiente de ratificación con el negocio**.
- Q: ¿El alcance es la lista cerrada de hallazgos A–G o también cualquier otro caso de la misma clase? → A: A–G más una auditoría de la misma clase durante la planificación (FR-015). Lo que se encuentre y **no** cambie el comportamiento de un tenant de Bogotá se corrige; lo que sí lo cambie se consulta antes de tocarlo.
- Q: ¿Se puede cambiar la zona de un tenant existente desde una pantalla? → A: No. La zona se elige al crear el tenant; los cambios posteriores siguen siendo una operación de soporte (script), con la consecuencia documentada de que el historial se reinterpreta en la nueva zona (FR-016).
- Q: ¿Cómo se elige la zona al crear el tenant desde Super Admin? → A: Desde una lista curada con nombres en español, de selección obligatoria y sin valor preseleccionado (nadie queda en Bogotá por olvido). Por cualquier otro camino (script, API) el valor por defecto sigue siendo `America/Bogota`, y toda zona se valida contra la base IANA en cualquier camino.
- Q: En el panel de Super Admin, ¿en qué zona horaria debe mostrarse la fecha de vencimiento del plan de cada tenant, si el Super Admin no pertenece a ningún tenant? → A: En la zona del propio tenant de cada fila: la lista de tenants entrega la zona de cada uno y el vencimiento se muestra en ella, de modo que el Super Admin y el negocio ven el mismo día. Las pantallas del Super Admin sin tenant asociado usan el respaldo compartido (Bogotá).
- Q: ¿Las suites de pruebas deben ejecutarse también con la zona horaria del sistema forzada a una distinta de las zonas de los tenants de prueba, para detectar código que dependa de la zona de la máquina? → A: Sí, en backend y frontend: las pruebas de fechas se ejecutan con la zona del sistema forzada a una zona sin relación con los tenants de prueba (p. ej. Tokio) y también en UTC.
- Q: Si en la planificación se descubre que la base de producción NO corre en UTC (o que algún tenant existente tiene una zona inválida), ¿cómo debe proceder el trabajo? → A: Se pausa solo lo que dependa de esa suposición (FR-004/FR-005 en producción), se informa al solicitante y la corrección de datos se trata en una spec aparte con su estrategia de migración y rollback (Principios VII y VIII); el resto de la spec continúa.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Un negocio en otra zona ve todo en su hora (Priority: P1)

Un negocio con sede en Ciudad de México, Madrid o Tokio usa el POS y espera que cada fecha y hora —en pantalla, en el
ticket impreso, en los reportes y en los correos— sea la de su ciudad, sin importar la zona en la que esté configurado el
equipo del cajero ni el servidor.

**Why this priority**: es el objetivo del cambio. Sin esto, el primer cliente fuera de Bogotá vería horas
desplazadas en el ticket, la terminal y las gráficas, y no podría confiar en los reportes.

**Independent Test**: poner un tenant de prueba en Ciudad de México, hacer una venta a las 17:30 locales y revisar la
hora en cada pantalla, con el navegador configurado en una zona distinta.

**Acceptance Scenarios**:

1. **Given** un tenant en Ciudad de México y una venta a las 17:30 locales, **When** se consulta Ventas, Órdenes, Caja, Inventario, el ticket impreso, la terminal, la gráfica por hora, las notificaciones y las invitaciones, **Then** todas muestran 17:30 del mismo día.
2. **Given** un cajero con el equipo configurado en una zona distinta a la del negocio, **When** abre la terminal, **Then** ve el reloj, la fecha y el turno (Mañana/Tarde/Noche) del negocio, no los del equipo.
3. **Given** un comensal que consulta su pedido desde un dispositivo en otra zona, **When** ve la hora de su pedido, **Then** ve la hora del negocio.
4. **Given** una venta a las 19:30 de Bogotá del 25/10/2026 (guardada como 2026-10-26 00:30 UTC), **When** se consulta en cualquier pantalla o reporte, **Then** se muestra 25/10/2026 19:30 y cuenta como «hoy 25/10»; la fecha UTC (26/10) nunca decide el día de negocio.
5. **Given** un tenant en Ciudad de México, **When** recibe el correo de contraseña cambiada, **Then** la hora del correo es la local y la etiqueta es «(hora de Ciudad de México)»; un tenant de Bogotá sigue viendo «(hora de Colombia)».
6. **Given** un instante que la API entrega como «2026-10-25T17:00:00+00:00», **When** el negocio lo ve, **Then** se muestra 12:00 en Bogotá y 11:00 en Ciudad de México, nunca 5 h de error por interpretarlo como hora local del navegador.
7. **Given** un Super Admin que consulta la lista de tenants con un tenant de Tokio cuyo plan vence el 2026-11-01 a las 16:00 UTC (01:00 del 02/11 en Tokio), **When** ve el vencimiento de ese tenant, **Then** ve 02/11/2026 —el mismo día que ve el propio negocio en su pantalla de plan—, sin importar la zona del navegador del Super Admin.

---

### User Story 2 - Las promociones se evalúan en la zona del tenant en todos los caminos de cobro (Priority: P1)

Una promoción de «happy hour» de 18:00 a 20:00 debe aplicarse o no según la hora de pared del negocio que cobra, por
cualquier camino: venta directa, cobro de mesa, mesas fusionadas, aprobación de un pago QR, vista previa y menú público.

**Why this priority**: es dinero. Hoy ocho caminos evalúan la vigencia con la zona global (Bogotá), así que un negocio
de Ciudad de México recibiría el descuento una hora antes de tiempo.

**Independent Test**: promoción 18:00–20:00 en un tenant de Ciudad de México y una venta a las 17:30 locales, ejecutada
por cada camino de cobro.

**Acceptance Scenarios**:

1. **Given** una promoción 18:00–20:00 en un tenant de Ciudad de México y un cobro a las 17:30 locales, **When** se cobra por venta directa, por cobro de mesa, por mesas fusionadas o por aprobación de un pago QR, **Then** no se aplica el descuento en ninguno.
2. **Given** la misma promoción en un tenant de Bogotá y un cobro a las 18:30 locales, **When** se cobra por cualquiera de esos caminos, **Then** el descuento se aplica.
3. **Given** un instante 2026-10-25 23:30 UTC y una promoción de 18:00 a 20:00, **When** se evalúa en cada zona, **Then** Bogotá (18:30) aplica, Ciudad de México (17:30) no aplica y Madrid (00:30 del 26/10) no aplica.
4. **Given** que la vista previa del carrito, el menú público y el cobro evalúan el mismo instante para el mismo tenant, **When** se comparan, **Then** coinciden en qué promociones están vigentes.

---

### User Story 3 - El día de negocio es el día local (Priority: P1)

«Hoy», «segundo rechazo del día» y cualquier agrupación por día usan siempre la fecha local del tenant, nunca la fecha
UTC.

**Why this priority**: es un defecto que **ya afecta a Bogotá**: entre las 19:00 y las 24:00 locales el sistema usa el
día siguiente y el aviso de «segundo rechazo del día» de la mesa no se registra.

**Independent Test**: dos rechazos de pago de la misma mesa en la noche de un tenant de Bogotá; y una operación entre
las 00:00 y las 02:00 locales en un tenant al este de UTC.

**Acceptance Scenarios**:

1. **Given** un tenant en Bogotá y dos rechazos de pago de la misma mesa, uno a las 20:00 y otro a las 21:00, **When** se registra el segundo, **Then** queda la marca de revisión.
2. **Given** un tenant al este de UTC (p. ej. Madrid) y una operación entre las 00:00 y las 02:00 locales (cuando el día UTC todavía es el anterior), **When** se calcula «hoy», **Then** es el día local.
3. **Given** un turno de caja que cruza la medianoche local, **When** se atribuyen sus ventas, **Then** siguen atribuyéndose al día de apertura y la atribución sigue definida por el vínculo con el turno, no por la hora.

---

### User Story 4 - Lo guardado no depende de la configuración del servidor de base de datos (Priority: P1)

Si cambia la zona de la sesión del motor de base de datos (por un contenedor, un servicio gestionado o una herramienta
de soporte), los instantes ya guardados y los nuevos siguen siendo los mismos instantes en UTC.

**Why this priority**: hoy todo funciona solo porque el contenedor arranca en UTC. Un cambio de infraestructura
corrompería silenciosamente las horas de todas las operaciones nuevas.

**Independent Test**: ejecutar la misma operación con la sesión de la base de datos en UTC y en America/Bogota, y
comparar lo almacenado.

**Acceptance Scenarios**:

1. **Given** la sesión de la base de datos en una zona distinta de UTC, **When** se guarda cualquier fecha (explícita o por defecto), **Then** el valor almacenado es el mismo instante en UTC.
2. **Given** el instante 2026-10-25 17:00 UTC, **When** se guarda, **Then** queda almacenado como 17:00 sin importar la zona de la sesión (hoy, con la sesión en Bogotá, queda como 12:00).
3. **Given** cualquier parte del backend que escriba un instante, **When** se revisa cómo lo escribe, **Then** lo hace de una sola forma.

---

### User Story 5 - La zona se define al crear el tenant y siempre es válida (Priority: P2)

El Super Admin elige la zona horaria del negocio al darlo de alta. Un valor que no sea una zona IANA válida se rechaza
siempre, por cualquier camino, y nunca se guarda.

**Why this priority**: sin esto, los tenants nuevos nacen en Bogotá aunque estén en otro país, y la zona solo se
corrige después, por soporte. Es P2 porque el mecanismo ya existe y puede operarse manualmente mientras tanto.

**Independent Test**: crear un tenant desde Super Admin eligiendo una zona; intentar guardar una zona inválida por la
pantalla, por el script de soporte y directamente en la base de datos.

**Acceptance Scenarios**:

1. **Given** el formulario de alta de tenant, **When** el Super Admin lo abre, **Then** el campo de zona horaria no tiene valor preseleccionado, ofrece una lista curada con nombres en español y no permite guardar sin elegir una.
2. **Given** un tenant creado con la zona «Ciudad de México», **When** se consulta cualquier fecha del tenant, **Then** se muestra en esa zona.
3. **Given** un valor que no es una zona IANA, **When** se intenta guardar por la pantalla, por el script de soporte o directamente en la base de datos, **Then** se rechaza y nunca se persiste.
4. **Given** un tenant creado por un camino que no indica zona (script o API), **When** se guarda, **Then** su zona es America/Bogota.

---

### User Story 6 - Red de seguridad de pruebas (Priority: P2)

El equipo de desarrollo y soporte tiene pruebas y una verificación automática que impiden reintroducir estos defectos.

**Why this priority**: hoy solo 4 archivos de pruebas usan una zona distinta de Bogotá, así que casi nada protege el
comportamiento multi-zona. Es P2 porque no cambia lo que ve el usuario, pero evita que la deuda vuelva.

**Independent Test**: introducir a propósito un campo de fecha sin offset en una respuesta de la API y comprobar que una
prueba falla.

**Acceptance Scenarios**:

1. **Given** una respuesta de la API que declara un instante sin offset fuera de la lista de excepciones, **When** corre la suite, **Then** falla indicando el campo.
2. **Given** las pruebas de zona horaria, **When** corren, **Then** se ejecutan con tres zonas de tenant: Bogotá, Ciudad de México y Madrid.
3. **Given** las suites de pruebas de fechas del backend y del frontend, **When** se ejecutan con la zona del sistema forzada a una zona sin relación con los tenants de prueba (p. ej. Tokio) y también en UTC, **Then** pasan igual que con la zona de la máquina de desarrollo; una prueba que solo pasa con el sistema en Bogotá se considera defectuosa.
4. **Given** los casos de borde (día de 25 y de 23 horas, medianoche inexistente de Santiago, 00:00–02:00 al este de UTC), **When** corre la suite, **Then** cada uno tiene una prueba que lo cubre.

---

### Edge Cases

- **Día de 25 horas** (Madrid, 25/10/2026, fin del horario de verano): el día va de 2026-10-24 22:00 UTC a 2026-10-25 23:00 UTC; el 24/10 dura 24 horas.
- **Día de 23 horas** (Madrid, inicio del horario de verano, 29/03/2026).
- **Medianoche inexistente** (Santiago, 06/09/2026): las 00:00 locales no existen y el día empieza a las 04:00 UTC. Hoy funciona; debe quedar una prueba que lo proteja.
- **Hora repetida al terminar el horario de verano**: los instantes se distinguen porque se guardan en UTC; la vigencia de promociones se evalúa por hora de pared, así que una promoción que cubra la hora repetida aplica en las dos pasadas. Queda documentado.
- **Operaciones entre las 00:00 y las 02:00 locales** en zonas al este de UTC: el día UTC es el anterior; el día de negocio es el local.
- **Turno que cruza la medianoche local**: se atribuye al día de apertura (sin cambio).
- **Cambio de zona de un tenant que ya tiene datos**: el historial se reinterpreta en la nueva zona (los instantes no cambian, sí su presentación y los límites de día). Solo lo hace soporte, por script (FR-016).
- **Zona inválida escrita directamente en la base de datos**: se rechaza; nunca queda persistida.
- **Dispositivo del cajero con la zona del sistema distinta a la del negocio**: manda la zona del negocio.
- **Comensal QR con su dispositivo en una zona distinta a la del negocio**: ve la hora del negocio.
- **Usuario sin tenant** (p. ej. Super Admin) que recibe un correo con hora: se usa Bogotá y la etiqueta «(hora de Colombia)».
- **Super Admin que consulta datos de tenants de varias zonas** (lista de tenants): cada fila se muestra en la zona de su propio tenant, nunca en la del navegador del Super Admin; lo que no describe a un tenant concreto usa el respaldo compartido (Bogotá).
- **Tenant con una zona válida que no está en la lista del selector** (asignada por soporte): todo funciona; solo la etiqueta de los correos cae al desfase («(UTC−3)»).
- **Promociones ya guardadas con hora de pared local**: no se tocan; siguen siendo la excepción documentada (FR-002).
- **Datos históricos**: no se migran ni se recalculan (Principio VII).
- **La verificación de la planificación contradice una suposición** (base de producción fuera de UTC, o un tenant existente con zona inválida): se pausa solo lo que depende de esa suposición, se informa al solicitante y la corrección de datos va en una spec aparte; el resto continúa.

## Requirements *(mandatory)*

### Functional Requirements

**Contrato de fechas de la API**

- **FR-001**: Todo instante que devuelve la API MUST llevar offset UTC explícito. Ningún campo de respuesta entrega un instante sin offset.
- **FR-002**: Los campos de hora de pared local de promociones (inicio y fin de vigencia, hora de inicio y fin de la ventana diaria) MUST mantenerse como están y quedar documentados como la **única** excepción a FR-001.
- **FR-003**: Una verificación automática MUST fallar cuando un esquema de respuesta declare un instante sin offset que no esté en la lista de excepciones, indicando el campo.

**Almacenamiento**

- **FR-004**: La plataforma MUST guardar todo instante en UTC sin depender de la zona de la sesión de la base de datos, incluidos los valores por defecto de fecha generados por la propia base.
- **FR-005**: Todo el backend MUST escribir los instantes en columnas sin zona de una sola forma (UTC).

**Reglas que dependen de la hora**

- **FR-006**: La vigencia de promociones MUST evaluarse con la zona del tenant dueño de la operación en **todos** los caminos (venta directa, cobro de mesa, mesas fusionadas, aprobación de pagos QR, vista previa del carrito y menú público). La zona global de respaldo solo aplica si de verdad no hay tenant.
- **FR-007**: «Hoy» y el día de negocio MUST ser siempre la fecha local del tenant, incluido el cálculo del «segundo rechazo del día» de una mesa (spec 132, FR-020).

**Presentación en el frontend**

- **FR-008**: Todo instante que el frontend muestra MUST pasar por un único mecanismo de presentación que usa la zona del tenant, con **una sola** zona de respaldo compartida (hoy repetida en varios archivos). Cubre, como mínimo: ticket impreso, reloj/fecha/turno de la terminal, hora de los pedidos de la terminal, hora de los pedidos del comensal, etiqueta del turno, ejes de la gráfica por hora/día/semana, notificaciones, plan, tenants e invitaciones. En el panel de Super Admin, que no pertenece a ningún tenant, los instantes que describen a un tenant (p. ej. el vencimiento del plan en la lista de tenants) MUST mostrarse en la zona de **ese** tenant —la lista de tenants entrega la zona de cada uno—; las pantallas del Super Admin sin tenant asociado usan la zona de respaldo compartida.
- **FR-009**: «Hoy», los rangos de fechas, las etiquetas de los ejes, los nombres de archivo exportados y la evaluación visual de promociones en el frontend MUST usar la zona del tenant, no la del navegador ni la UTC.

**Zona del tenant**

- **FR-010**: La zona del tenant MUST capturarse al crearlo desde Super Admin mediante una lista curada con nombres en español, de selección obligatoria y sin valor preseleccionado. Por los demás caminos (script, API) el valor por defecto sigue siendo America/Bogota. Toda zona MUST validarse contra la base IANA en cualquier camino de escritura, **incluida la base de datos**, y un valor inválido nunca se persiste.
- **FR-011**: Los correos que muestran hora MUST usar la zona del tenant: un tenant de Bogotá conserva «(hora de Colombia)»; otra zona de la lista usa su nombre en español; una zona válida fuera de la lista muestra el desfase; un usuario sin tenant usa Bogotá.
- **FR-016**: Cambiar la zona de un tenant ya creado MUST seguir siendo una operación de soporte (script), documentada, que advierte que el historial se reinterpreta en la nueva zona. No se agrega pantalla de edición.

**Calidad y no regresión**

- **FR-012**: Las pruebas de fechas MUST ejecutarse con tres zonas de tenant (Bogotá, Ciudad de México, Madrid) e incluir el borde de día y el cambio de horario. Además, las suites de pruebas de fechas del backend y del frontend MUST ejecutarse con la zona del sistema forzada a una zona sin relación con los tenants de prueba (p. ej. Tokio) y también en UTC, de modo que ningún resultado dependa de la zona de la máquina que las corre.
- **FR-013**: Un tenant en Bogotá MUST seguir viendo exactamente los mismos valores antes y después, **con dos excepciones explícitas**: (a) el día de negocio entre las 19:00 y las 24:00 locales —la marca de «segundo rechazo del día» y el día que lleva el nombre del archivo de exportación de inventario— (FR-007, FR-009, A-147) y (b) la corrección del error de 5 h en los instantes sin offset (FR-001, A-148). No se migran ni se alteran datos históricos.
- **FR-014**: Las anomalías correspondientes MUST registrarse en el registro de anomalías: **A-147** (día de negocio: segundo rechazo y nombre del export de inventario), **A-148** (instantes sin offset) y **A-149** (deuda residual de zona horaria sin cambio de comportamiento para Bogotá).
- **FR-015**: Durante la planificación MUST hacerse una auditoría de la misma clase (instantes tratados con la zona del servidor, UTC o del navegador). Cada hallazgo adicional que **no** cambie el comportamiento de un tenant de Bogotá se corrige dentro de esta spec; el que sí lo cambie se consulta al solicitante antes de tocarlo.

### Key Entities

- **Tenant**: negocio dueño de las operaciones; tiene una zona horaria IANA válida (por defecto America/Bogota) que define su día de negocio, la vigencia de sus promociones y cómo se muestran sus fechas.
- **Instante**: momento absoluto de un hecho (venta, pago, cierre, envío de invitación). Se guarda en UTC y se entrega con offset UTC explícito.
- **Día de negocio**: ventana [00:00 local, 00:00 local del día siguiente) del tenant, convertida a UTC; puede durar 23, 24 o 25 horas.
- **Hora de pared local de una promoción**: inicio/fin de vigencia y ventana diaria; es la excepción por diseño y se interpreta siempre en la zona del tenant.
- **Intento de pago rechazado**: hecho que, al repetirse el mismo día local para la misma mesa, deja una marca de revisión.
- **Lista de excepciones**: lista explícita y documentada de campos que pueden viajar sin offset (hoy, solo los de hora de pared local de promociones).
- **Lista curada de zonas**: zonas ofrecidas en el alta de tenant, con nombre en español; cubre al menos Bogotá, Ciudad de México, Lima, Santiago, Buenos Aires, Madrid y Tokio y puede ampliarse sin cambiar la validación IANA.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Para un tenant de prueba en Ciudad de México, una venta de las 17:30 locales se ve como 17:30 del mismo día en el 100 % de las pantallas, reportes, ticket impreso y correos listados en FR-008 y FR-011, con el navegador del cajero configurado en una zona distinta.
- **SC-002**: La gráfica de ingresos por hora de ese tenant muestra el 100 % de sus ejes en hora local.
- **SC-003**: La promoción 18:00–20:00 no se aplica a las 17:30 locales de Ciudad de México en ninguno de los cuatro caminos de cobro, y sí se aplica a las 18:30 locales de Bogotá (0 aplicaciones indebidas en las tres zonas de prueba).
- **SC-004**: En un tenant de Bogotá, dos rechazos de pago de la misma mesa entre las 19:00 y las 24:00 dejan la marca de revisión el 100 % de las veces.
- **SC-005**: «Producto agotado desde hace X» y «Enviada el…» muestran la hora real, sin los 5 h de diferencia que hoy se ven en Bogotá.
- **SC-006**: Con la sesión de la base de datos en cualquier otra zona, los valores guardados son idénticos en el 100 % de las operaciones comparadas.
- **SC-007**: El 100 % de los intentos de guardar una zona inválida (pantalla, script, base de datos) son rechazados; el alta de un tenant desde Super Admin se completa eligiendo la zona en el mismo formulario, sin pasos adicionales.
- **SC-008**: La suite de pruebas pasa con las tres zonas de tenant y con la zona del sistema forzada a Tokio y a UTC (backend y frontend), y falla en el 100 % de los casos en que se agrega un campo de fecha sin offset a un esquema de respuesta declarado con `response_model`. Las respuestas `dict`/`JSONResponse` sin `response_model` quedan fuera de la verificación automática y se auditaron a mano (contracts/instantes-api.md §4).
- **SC-009**: Un tenant de Bogotá muestra exactamente los mismos valores antes y después, salvo las dos excepciones documentadas (A-147 y A-148).
- **SC-010**: Ningún correo de un tenant fuera de Colombia contiene la etiqueta «Colombia».

## Assumptions

- **Repositorios en alcance**: `pos-backend`, `pos-heladeria` y `pos-specs` (incluidos `docs-publicos` y `srs` donde describan horas). `skeilo-pos-landing` queda fuera.
- **Consumidores de la API**: el único consumidor de los campos que pasan a llevar offset es `pos-heladeria`. Si la planificación encuentra otro, se consulta.
- **Zonas de prueba**: Bogotá, Ciudad de México y Madrid (con horario de verano, para cubrir el día de 25 y de 23 horas). Santiago y Tokio entran como pruebas puntuales (medianoche inexistente y ventana 00:00–02:00).
- **Producción en UTC**: se asume que la base de producción hoy corre en UTC (el contenedor arranca en UTC) y se verifica en la planificación. Por eso los datos históricos son correctos y no se migran. **Si la verificación contradice la suposición**, se pausa solo lo que depende de ella (FR-004 y FR-005 en producción), se informa al solicitante y la corrección de datos se trata en una spec aparte con su propia estrategia de migración y rollback; el resto de esta spec continúa.
- **Columnas**: no se cambia el tipo de ninguna columna de fecha. FR-005 unifica solo cómo se escribe en las columnas sin zona.
- **Zonas existentes**: se asume que la zona de todos los tenants existentes ya es válida; la planificación lo verifica antes de endurecer la validación en la base de datos. Si algún tenant tiene una zona inválida, no se endurece la validación en la base de datos hasta que se resuelva por la misma vía que el punto anterior (informar al solicitante y tratar la corrección en una spec aparte).
- **México** no usa horario de verano desde 2022; Ciudad de México es UTC−6 todo el año.
- **Lista curada**: la lista inicial de zonas del selector se cierra en la planificación; ampliarla no requiere cambiar la validación.
- **Decisión de negocio**: la solicitud proviene del equipo de desarrollo (2026-10-25) y las excepciones de FR-013 quedan **pendientes de ratificación con el negocio**; se citan así en el registro de anomalías.
- **Despliegue**: backend y frontend se publican en un orden que no deje una ventana con horas desplazadas; el orden se define en la planificación.
- **Dependencias**: este trabajo reutiliza el mecanismo central de las specs 022, 023, 030 y 127; no lo reemplaza.
