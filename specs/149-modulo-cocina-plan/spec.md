# Feature Specification: Módulo "Cocina" en el catálogo de módulos por plan

**Feature Branch**: `149-modulo-cocina-plan`

**Created**: 2026-11-04

**Status**: Draft

**Input**: User description: "Como super admin, quiero incluir el módulo 'Cocina' en la configuración de un plan, para que solo los tenants suscritos a ese plan accedan al flujo de cocina."

> **Nota de alcance**: esta spec extiende el catálogo de módulos gobernados por plan
> ya establecido en la spec 033 (Planes de Suscripción por Tenant) —donde un módulo
> de acceso booleano (hoy Inventario, Compras, Promociones) "desaparece de la
> navegación y no se puede ni siquiera consultar" cuando el plan vigente de un
> tenant no lo incluye (spec 033, FR-008/FR-009)— añadiendo "Cocina" como un nuevo
> módulo de ese mismo catálogo, con el mismo patrón de validación en backend y
> ocultamiento en frontend. No introduce el flujo de cocina en sí (tablero,
> `kitchen_status`, botón "Enviar a cocina"): asume que esas piezas ya existen y
> solo las somete al gating por plan.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - El Super Admin incluye "Cocina" en un plan (Priority: P1)

Como Super Admin, quiero marcar el módulo "Cocina" como incluido o no incluido al
crear o editar un plan, con el mismo control que ya uso para Inventario, para
poder comercializar el flujo de cocina como una característica diferenciada por
plan.

**Why this priority**: Es el punto de entrada de toda la funcionalidad — sin esta
pieza no existe ningún plan que incluya o excluya "Cocina", y nada de lo demás
puede probarse.

**Independent Test**: El Super Admin abre la pantalla de edición de un plan,
verifica que "Cocina" aparece en la lista de módulos disponibles junto a
Inventario, Compras y Promociones, la marca como incluida en un plan y como no
incluida en otro, y guarda ambos cambios exitosamente.

**Acceptance Scenarios**:

1. **Given** el Super Admin está creando o editando un plan, **When** abre la
   sección de módulos del plan, **Then** "Cocina" aparece como una opción más del
   catálogo de módulos, con el mismo control on/off que Inventario.
2. **Given** un plan no define explícitamente el módulo "Cocina", **When** se
   evalúa el acceso de un tenant en ese plan, **Then** el módulo se trata por
   defecto como no incluido (mismo criterio de spec 033, FR-002).
3. **Given** el Super Admin marcó "Cocina" como incluida en un plan y guardó el
   cambio, **When** un tenant está suscrito a ese plan, **Then** el tenant obtiene
   acceso al flujo de cocina sin pasos adicionales.

---

### User Story 2 - El tenant con el módulo activo ve y usa el flujo de cocina (Priority: P1)

Como usuario autorizado de un tenant cuyo plan incluye "Cocina", quiero ver el
ítem "Cocina" en el menú, acceder al tablero de cocina y usar el botón "Enviar a
cocina" en las órdenes, igual que ya puedo hacerlo hoy sin el gating.

**Why this priority**: Es el escenario positivo explícito del pedido — confirma
que añadir el gating no rompe ni degrada el flujo de cocina para quien sí tiene
el módulo.

**Independent Test**: Con un tenant suscrito a un plan que incluye "Cocina", un
usuario autorizado inicia sesión y verifica que el ítem "Cocina" aparece en el
menú, que puede navegar al tablero y que el botón "Enviar a cocina" funciona en
una orden normal.

**Acceptance Scenarios**:

1. **Given** el tenant tiene un plan que incluye el módulo "Cocina", **When** un
   usuario autorizado inicia sesión en el POS, **Then** ve el ítem "Cocina" en el
   menú y puede acceder a la ruta del tablero de cocina.
2. **Given** el tenant tiene el módulo "Cocina" activo, **When** el usuario
   trabaja con una orden, **Then** el botón "Enviar a cocina" está disponible y
   funciona con normalidad.

---

### User Story 3 - El tenant sin el módulo no ve ni puede acceder al flujo de cocina (Priority: P1)

Como usuario de un tenant cuyo plan no incluye "Cocina", no quiero ver el ítem de
menú, el botón "Enviar a cocina" ni poder entrar al tablero —y el flujo de
creación, confirmación y pago de órdenes debe seguir funcionando exactamente
igual que hoy, sin ninguna dependencia del módulo de cocina.

**Why this priority**: Es la otra mitad simétrica del gating y la que protege a
la mayoría de tenants actuales (sin el módulo) de cualquier regresión en su
flujo de órdenes y pagos, que es el núcleo del negocio.

**Independent Test**: Con un tenant en un plan sin "Cocina", un usuario navega
el POS y verifica que no aparece el ítem de menú ni el botón "Enviar a cocina",
que la URL del tablero no es accesible, y que puede crear, confirmar y pagar una
orden de principio a fin sin ningún cambio visible.

**Acceptance Scenarios**:

1. **Given** el plan del tenant no incluye el módulo "Cocina", **When** un
   usuario navega al POS, **Then** no ve el ítem "Cocina" en el menú ni el botón
   "Enviar a cocina" en ninguna orden.
2. **Given** el plan del tenant no incluye el módulo "Cocina", **When** el
   usuario intenta entrar directamente (URL, marcador, enlace guardado) a la
   ruta del tablero de cocina, **Then** el sistema le niega el acceso con el
   mismo mecanismo y destino ya usados para el resto de módulos no incluidos
   (spec 033, FR-008/FR-009).
3. **Given** el plan del tenant no incluye el módulo "Cocina", **When** el
   usuario crea, confirma y paga una orden, **Then** todo el flujo se comporta
   exactamente igual que antes de que existiera el módulo "Cocina" — sin pasos,
   mensajes ni restricciones nuevas.

---

### User Story 4 - El backend rechaza cualquier acceso directo sin el módulo (Priority: P1)

Como responsable de la integridad del sistema, quiero que todo endpoint del
flujo de cocina valide el módulo del tenant en el backend, para que ocultar
elementos en el frontend no sea la única barrera y nadie pueda invocar la API de
cocina solo porque conoce la URL del endpoint.

**Why this priority**: Es el requisito de seguridad explícito del pedido (RN-3)
— sin esta validación, el ocultamiento visual del frontend sería una protección
cosmética y no una restricción real de acceso.

**Independent Test**: Con un tenant sin el módulo "Cocina", se invoca cualquier
endpoint del flujo de cocina directamente (sin pasar por la interfaz) y se
verifica que la respuesta es un rechazo explícito, no un error genérico ni una
respuesta exitosa.

**Acceptance Scenarios**:

1. **Given** el plan del tenant no incluye el módulo "Cocina", **When** se
   invoca cualquier endpoint de cocina, **Then** el backend responde con un
   rechazo de acceso (HTTP 403) e indica mediante un código identificable que la
   causa es el módulo no habilitado.
2. **Given** el plan del tenant sí incluye el módulo "Cocina", **When** se
   invoca cualquier endpoint de cocina, **Then** la solicitud se procesa con
   normalidad, sin ninguna restricción adicional introducida por esta validación.

---

### User Story 5 - Desactivación del módulo con pedidos en curso en cocina (Priority: P2)

Como Super Admin que cambia el plan de un tenant (downgrade o cambio de plan) y
le retira el módulo "Cocina" mientras tiene órdenes con estado de cocina en
curso, quiero que el tablero deje de estar accesible sin que eso bloquee el
cierre normal de esas órdenes, para que el negocio del tenant no se detenga por
un cambio de plan.

**Why this priority**: Es un caso de transición menos frecuente que los
escenarios de acceso cotidiano (Historias 1 a 4), pero crítico para no dejar
órdenes "atrapadas" sin poder cerrarse — es la garantía de que el gating nunca
interrumpe el flujo de pagos, que es la prioridad de negocio más alta del
sistema.

**Independent Test**: Con un tenant que tiene órdenes en estado de cocina
"EN_PROGRESO", se le retira el módulo "Cocina" (downgrade o cambio de plan) y se
verifica que el tablero deja de estar accesible mientras esas órdenes se pueden
seguir cerrando por el flujo normal de órdenes y pagos.

**Acceptance Scenarios**:

1. **Given** el tenant tiene pedidos con estado de cocina "EN_PROGRESO", **When**
   el plan del tenant pierde el módulo "Cocina", **Then** el tablero de cocina
   deja de estar accesible de inmediato, con el mismo mecanismo de denegación de
   las Historias 3 y 4.
2. **Given** el tenant perdió el módulo "Cocina" con órdenes en curso, **When**
   esas órdenes avanzan por el flujo normal de confirmación, entrega y pago,
   **Then** se cierran con normalidad, sin que el estado de cocina las bloquee ni
   las condicione.
3. **Given** el tenant perdió el módulo "Cocina" con órdenes que tenían un
   `kitchen_status` asignado, **When** el sistema procesa esas órdenes, **Then**
   el valor de `kitchen_status` se conserva sin borrarse (como dato histórico),
   pero el sistema lo ignora para cualquier decisión de flujo o visualización
   mientras el módulo no esté activo — mismo criterio de no pérdida de datos que
   spec 033, FR-012.
4. **Given** al tenant se le reasigna el módulo "Cocina" después de haberlo
   perdido, **When** vuelve a acceder al tablero, **Then** el tablero vuelve a
   estar disponible con normalidad.

---

### Edge Cases

- Un tenant tiene el módulo "Cocina" incluido en su plan pero su plan vigente
  está vencido o en mora: se aplica el mismo mecanismo ya definido en spec 033
  para planes vencidos (no es un caso nuevo de esta spec).
- Dos usuarios del mismo tenant acceden simultáneamente al tablero de cocina
  justo en el momento en que el Super Admin retira el módulo: el sistema debe
  negar el acceso a cualquier solicitud nueva desde ese momento, sin garantizar
  el cierre inmediato de una sesión de tablero ya abierta en el navegador
  (consistente con el mismo criterio ya aceptado para Inventario en spec 033).
- Una orden queda con `kitchen_status` "EN_PROGRESO" de forma permanente (nunca
  se cierra) después de perder el módulo: no es un caso distinto — la orden
  sigue su flujo normal de órdenes y pagos independientemente del valor de
  `kitchen_status`, que esta spec define como ignorado mientras el módulo no
  esté activo.
- Un tenant nunca tuvo el módulo "Cocina" activo: no ve el ítem de menú ni el
  botón desde el primer momento, igual que cualquier tenant sin el módulo
  (mismo comportamiento por defecto de FR-002/FR-004).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST incluir "Cocina" como un módulo más del catálogo de
  módulos gobernados por plan (acceso booleano), con el mismo patrón de
  configuración ya usado para Inventario, Compras y Promociones (spec 033).
- **FR-002**: El sistema MUST permitir al Super Admin marcar "Cocina" como
  incluida o no incluida al crear o editar un plan, con el mismo control que el
  resto de módulos del catálogo.
- **FR-003**: Cuando un plan no define explícitamente el módulo "Cocina", el
  sistema MUST tratarlo por defecto como no incluido (mismo criterio que spec
  033, FR-002).
- **FR-004**: El sistema MUST validar, en el backend y en cada solicitud a un
  endpoint del flujo de cocina, que el plan vigente del tenant incluya el módulo
  "Cocina" antes de procesar la solicitud.
- **FR-005**: Cuando el plan vigente de un tenant no incluye el módulo "Cocina",
  el backend MUST rechazar la solicitud a cualquier endpoint de cocina con
  código de respuesta HTTP 403 y un código de error identificable
  `MODULE_NOT_ENABLED`.
- **FR-006**: El frontend MUST ocultar, para un tenant sin el módulo "Cocina", el
  ítem "Cocina" del menú de navegación y el botón "Enviar a cocina" en toda
  pantalla de órdenes, sin afectar ningún otro elemento de esas pantallas.
- **FR-007**: El sistema MUST impedir el acceso a la ruta del tablero de cocina
  para un tenant sin el módulo "Cocina", incluso mediante navegación directa por
  URL, con el mismo mecanismo y destino ya usados para el resto de módulos no
  incluidos (spec 033, FR-008/FR-009).
- **FR-008**: El flujo de creación, confirmación y pago de órdenes MUST
  comportarse de forma idéntica para un tenant sin el módulo "Cocina", sin
  ningún paso, validación o mensaje adicional derivado de la existencia del
  flujo de cocina.
- **FR-009**: Cuando el plan de un tenant pierde el módulo "Cocina" (por
  downgrade o cambio de plan) mientras existen órdenes con `kitchen_status`
  distinto de su estado final, el sistema MUST volver el tablero de cocina
  completamente inaccesible para ese tenant, sin bloquear el flujo normal de
  cierre de esas órdenes.
- **FR-010**: El sistema MUST conservar el valor de `kitchen_status` de las
  órdenes existentes cuando un tenant pierde el módulo "Cocina" — no se borra —
  pero MUST ignorarlo para cualquier decisión de flujo o visualización mientras
  el módulo no esté activo para ese tenant.
- **FR-011**: El sistema MUST restaurar el acceso completo al tablero de cocina
  (incluyendo la información histórica conservada) cuando se reasigna el módulo
  "Cocina" al plan vigente del tenant, sin ninguna acción manual adicional.

### Key Entities *(include if feature involves data)*

- **Plan**: Conjunto de características —incluyendo el nuevo módulo booleano
  "Cocina"— que determina qué puede usar un tenant. Ya existente (spec 033);
  esta spec solo añade "Cocina" a su catálogo de módulos.
- **Orden**: Registro del flujo de ventas que incluye el atributo
  `kitchen_status`, usado por el flujo de cocina para rastrear el progreso de
  preparación de una orden. Ya existente; esta spec no cambia su ciclo de vida,
  solo define que ese atributo se ignora cuando el módulo "Cocina" no está
  activo para el tenant.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100% de los tenants sin el módulo "Cocina" en su plan completan
  el flujo de creación, confirmación y pago de una orden sin ver ningún elemento
  relacionado con cocina ni experimentar ningún cambio de comportamiento
  respecto al sistema sin este módulo.
- **SC-002**: El 100% de las solicitudes directas a un endpoint del flujo de
  cocina desde un tenant sin el módulo son rechazadas con HTTP 403 y el código
  `MODULE_NOT_ENABLED`, sin excepción.
- **SC-003**: Un tenant que recibe el módulo "Cocina" en su plan puede ver el
  ítem de menú y acceder al tablero sin ninguna acción manual adicional, en el
  mismo inicio de sesión posterior al cambio de plan.
- **SC-004**: Ningún pedido pierde su historial de `kitchen_status` al
  desactivarse el módulo "Cocina" para su tenant, verificable consultando el
  dato después de la desactivación.

## Assumptions

- El flujo de cocina (tablero, botón "Enviar a cocina", atributo
  `kitchen_status` y sus endpoints) ya existe en el sistema; esta spec solo
  añade el gating por plan sobre piezas existentes, no diseña el flujo de
  cocina en sí.
- El mecanismo de validación de módulos por plan, el código de error
  `MODULE_NOT_ENABLED` como patrón de respuesta 403, y el destino de redirección
  para rutas no accesibles siguen el mismo diseño ya establecido en spec 033
  para Inventario, Compras y Promociones — no se introduce un mecanismo nuevo
  ni distinto solo para Cocina.
- Los valores posibles de `kitchen_status` (incluyendo "EN_PROGRESO") y su
  significado de negocio ya están definidos por el flujo de cocina existente;
  esta spec no los modifica, solo especifica que se ignoran cuando el módulo no
  está activo.
- "Usuario autorizado" se refiere a cualquier rol del tenant que ya tiene
  permiso para usar el flujo de órdenes y cocina hoy (p. ej. mesero, cajero,
  Tenant Admin) — esta spec no introduce ni modifica roles o permisos internos
  del tenant, solo el gating por plan a nivel de tenant.
