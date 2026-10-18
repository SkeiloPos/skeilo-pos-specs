# Feature Specification: Vigencia de promociones en la hora local del tenant

**Feature Branch**: `127-fix-zona-horaria-promociones`

**Created**: 2026-10-18

**Status**: Draft

**Input**: User description: "En producción, configuré una promoción de lunes a jueves de 5pm a 12am y a las 7pm (dentro de la ventana) la promoción ya aparecía como expirada/no vigente. Investigar si las promociones se crean y se validan en base a la zona horaria del tenant."

## Clarifications

### Session 2026-10-18

- Q: El análisis técnico encontró tres problemas relacionados en el flujo de vigencia de promociones: (1) el frontend calcula "hoy" con la fecha UTC en vez de la fecha local al guardar `starts_at` — coincide exactamente con el incidente reportado; (2) el motor de vigencia nunca usa la zona horaria real de cada tenant, sino un valor global compartido por toda la instalación — hoy invisible porque coincide con el default, pero es un riesgo latente; (3) se puede activar una promoción sin haber guardado su horario/días, quedando corriendo 24/7 sin aviso. ¿Cuál(es) entran en el alcance de esta corrección? → A: (1) y (2). (3) queda fuera de esta spec — es un problema de integridad de datos/UX distinto al de zona horaria.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - La promoción respeta su horario sin importar la hora en que se creó o editó (Priority: P1)

Quien administra las promociones configura una ventana de días/horas (por ejemplo, lunes a jueves de 5pm a 12am) y espera que la promoción esté activa durante exactamente esa ventana, sin importar a qué hora del día la creó, la editó o la activó.

**Why this priority**: Es el defecto reportado directamente por el negocio — una promoción vigente dejó de aplicar a mitad de su propia ventana horaria, lo que genera desconfianza en el módulo completo de promociones y puede traducirse en descuentos no aplicados a clientes que sí calificaban.

**Independent Test**: Puede probarse creando o editando una promoción con ventana horaria después de las 7pm (hora de Colombia) y verificando que su fecha de inicio de vigencia corresponde al día del calendario local en que se guardó, no al día siguiente.

**Acceptance Scenarios**:

1. **Given** una promoción activa con ventana "lunes a jueves, 5pm a 12am", **When** se consulta su vigencia en cualquier momento dentro de esa ventana el mismo día de creación, **Then** la promoción se evalúa como vigente, sin importar si se creó, editó o activó después de las 7pm hora local.
2. **Given** el formulario de creación o edición de una promoción, **When** se guarda sin indicar explícitamente una fecha de inicio, **Then** la fecha de inicio registrada corresponde al día calendario local del tenant en el momento de guardar, no al día calendario en UTC.
3. **Given** una promoción guardada cerca de la medianoche local (por ejemplo, entre 11:55pm y 12:05am), **When** se evalúa su vigencia inmediatamente después de guardarla, **Then** el día de calendario usado es consistente con el reloj local del tenant en todo el flujo (creación, evaluación y visualización).

---

### User Story 2 - La vigencia se evalúa con la zona horaria real de cada tenant (Priority: P2)

El motor que decide si una promoción está vigente ahora debe usar la zona horaria configurada para ese tenant específico, no un valor compartido por toda la instalación, para que el comportamiento sea correcto incluso si en el futuro conviven tenants en distintas zonas horarias.

**Why this priority**: Hoy es invisible porque el valor global coincide con la zona horaria real de los tenants existentes, pero es un defecto latente: cualquier tenant cuya zona horaria configurada difiera del valor global evaluaría mal sus promociones sin ningún error visible.

**Independent Test**: Puede probarse configurando dos tenants con zonas horarias distintas, cada uno con una promoción con la misma ventana horaria, y verificando que cada uno evalúa su propia vigencia según su propia zona horaria configurada, no según un valor compartido.

**Acceptance Scenarios**:

1. **Given** dos tenants con zonas horarias configuradas distintas, **When** cada uno evalúa, en el mismo instante real, una promoción con la misma ventana horaria, **Then** cada resultado de vigencia corresponde a la hora local de su propio tenant.
2. **Given** un tenant con su zona horaria correctamente configurada, **When** se evalúa la vigencia de una promoción desde el carrito, desde el cobro de un pedido o mesa, y desde el menú público, **Then** los tres puntos de entrada arrojan el mismo resultado de vigencia para el mismo instante, usando la zona horaria de ese tenant.

---

### Edge Cases

- ¿Qué pasa si un tenant no tiene zona horaria configurada? Debe seguir existiendo un valor por defecto razonable, usado únicamente como respaldo, no como comportamiento normal para tenants ya configurados.
- ¿Qué pasa con promociones que ya quedaron guardadas en producción con una fecha de inicio/fin desplazada por este defecto? No se corrigen automáticamente; quedan tal como están hasta que alguien las edite manualmente desde el formulario.
- ¿Qué pasa con una ventana horaria que cruza la medianoche (ej. 5pm a 12am) combinada con el cambio de zona horaria? El comportamiento ya validado para el cruce de medianoche no debe alterarse.
- ¿Qué pasa si el reloj del navegador del punto de venta tiene una zona horaria distinta a la del tenant? El resultado que determina si el descuento se aplica al cobrar es el que calcula el servidor con la zona horaria del tenant, no el reloj del navegador.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Al crear o editar una promoción sin que la persona indique explícitamente una fecha de inicio, el sistema MUST registrar como fecha de inicio el día calendario local del tenant en el momento de guardar, no el día calendario resultante de convertir la hora a UTC.
- **FR-002**: El sistema MUST evaluar si una promoción está vigente ahora (estado, rango de fechas, días de la semana permitidos y ventana horaria) usando la zona horaria real configurada para el tenant propietario de esa promoción, en vez de un único valor compartido por toda la instalación.
- **FR-003**: Todos los puntos donde se evalúa la vigencia de una promoción para decidir si aplica un descuento (carrito, cobro de pedidos, cobro de mesas/cuentas, vista pública del menú) MUST producir el mismo resultado de vigencia entre sí para el mismo instante y el mismo tenant.
- **FR-004**: El soporte ya existente para ventanas horarias que cruzan la medianoche (p. ej. 5pm a 12am) MUST seguir funcionando igual que hoy; esta corrección no MUST cambiar ese comportamiento.
- **FR-005**: Las promociones ya existentes MUST seguir funcionando sin que la persona administradora tenga que reconfigurarlas, salvo aquellas cuya fecha de inicio/fin ya haya quedado registrada incorrectamente por el defecto de FR-001 antes de esta corrección — esas MUST poder corregirse simplemente volviendo a guardarlas desde el formulario de edición.

### Key Entities

- **Promoción**: su vigencia depende de una fecha de inicio/fin opcional, un conjunto de días de la semana permitidos y una ventana horaria diaria opcional (que puede cruzar la medianoche). Toda esa vigencia se interpreta en la hora local del tenant propietario, nunca en UTC ni en la hora de otro tenant.
- **Tenant**: cada uno tiene su propia zona horaria configurada, que debe ser la única fuente usada para decidir "qué día y qué hora es ahora" al evaluar sus propias promociones.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Una promoción con ventana horaria configurada permanece aplicable durante el 100% de esa ventana el día en que se crea o edita, sin importar la hora del día en que esa acción ocurrió.
- **SC-002**: Dos tenants con zonas horarias configuradas distintas obtienen, cada uno, un resultado de vigencia correcto para sus propias promociones, sin que la configuración de uno afecte al otro.
- **SC-003**: El carrito, el cobro de pedidos/mesas y el menú público coinciden siempre en si una promoción está vigente o no para el mismo instante, dentro del mismo tenant.
- **SC-004**: Las pruebas de caracterización existentes sobre cruce de medianoche y filtrado por día de la semana del motor de promociones siguen pasando sin modificarse.

## Assumptions

- El reloj del servidor sigue funcionando en UTC internamente; esta corrección es de interpretación/zona horaria al leer y guardar fechas, no de sincronización de reloj.
- No se requiere una migración automática que recalcule promociones ya guardadas con fechas desplazadas por este defecto; se asume corrección manual caso por caso si se detectan.
- La zona horaria de cada tenant (columna ya existente en el tenant) ya está correctamente configurada hoy; esta spec no cubre una pantalla para que el tenant la edite.
- El valor global de zona horaria usado hoy como único criterio se conserva únicamente como respaldo para el caso sin tenant resuelto, no como comportamiento normal una vez aplicada esta corrección.
