# Feature Specification: Rediseño de cambio de contraseña para usuarios invitados

**Feature Branch**: `145-rediseno-password-invitado`

**Created**: 2026-10-30

**Status**: Draft

**Input**: User description: "necesito que rediseñes la pagina del cambio de contraseña para usuarios invitados cuando un administrador o superadmin invita a un usuario por primera vez y este va a iniciar sesion, vas a implementar el diseño que se encuentra en 'desing/Primer inicio de sesion.dc.html', si tienes alguna duda me preguntas, deberas ser fiel al diseño que estoy especificando"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Completar el cambio de contraseña temporal (Priority: P1)

Un usuario recién invitado por un administrador o superadmin (por ejemplo, un cajero) llega a la página de primer inicio de sesión, ingresa la contraseña temporal recibida en su invitación, define una nueva contraseña que cumple los requisitos de seguridad, la confirma y continúa hacia el inicio de sesión del negocio.

**Why this priority**: Es el flujo esencial sin el cual un usuario invitado no puede activar su cuenta ni acceder al sistema. Sin esto, la invitación no tiene valor.

**Independent Test**: Se puede probar completamente abriendo la página con una invitación válida, ingresando la contraseña temporal correcta y una nueva contraseña que cumpla todas las reglas, confirmándola igual, y verificando que se muestra la pantalla de "Cuenta lista" con acceso al login.

**Acceptance Scenarios**:

1. **Given** un usuario invitado con una contraseña temporal válida, **When** ingresa correctamente la contraseña temporal, una nueva contraseña que cumple todos los requisitos y la confirma de forma idéntica, **Then** el sistema guarda la nueva contraseña, elimina la condición de "debe cambiar contraseña" y muestra la pantalla de confirmación "Cuenta lista".
2. **Given** la pantalla de confirmación "Cuenta lista" visible tras un cambio exitoso, **When** el usuario pulsa "Iniciar sesión", **Then** es dirigido a la página de inicio de sesión del negocio.

---

### User Story 2 - Recibir retroalimentación en tiempo real sobre los requisitos de la contraseña (Priority: P2)

Mientras el usuario invitado escribe su nueva contraseña, ve de inmediato cuáles requisitos de seguridad ya cumple y cuáles le faltan, sin tener que enviar el formulario para descubrirlo.

**Why this priority**: Reduce intentos fallidos y frustración, pero el usuario podría de todas formas completar el cambio por ensayo y error aunque esta retroalimentación no existiera; por eso es secundaria respecto al flujo base.

**Independent Test**: Se puede probar escribiendo progresivamente distintos valores en el campo de nueva contraseña y verificando que cada requisito (longitud, mayúscula, número, distinta a la temporal) cambia su estado visual de pendiente a cumplido de forma independiente y en tiempo real.

**Acceptance Scenarios**:

1. **Given** el campo de nueva contraseña vacío, **When** el usuario escribe una contraseña de 10 caracteres distinta a la temporal, **Then** los dos requisitos se muestran marcados como cumplidos antes de enviar el formulario.
2. **Given** una nueva contraseña parcialmente válida, **When** el usuario corrige el texto para cumplir el requisito pendiente, **Then** solo el estado de ese requisito cambia a "cumplido", sin afectar el estado del otro.

---

### User Story 3 - Entender y corregir errores del formulario (Priority: P3)

Cuando el usuario invitado comete un error (contraseña temporal incorrecta o vacía, nueva contraseña que no cumple los requisitos, o confirmación que no coincide), recibe un mensaje claro que le permite corregirlo sin perder lo que ya escribió.

**Why this priority**: Mejora la experiencia de recuperación ante errores, pero es un refinamiento sobre los dos flujos anteriores, que ya cubren el valor principal de la funcionalidad.

**Independent Test**: Se puede probar enviando el formulario con la contraseña temporal vacía, luego con una nueva contraseña que no cumple los requisitos, y luego con una confirmación distinta a la nueva contraseña, verificando en cada caso que aparece un mensaje de error específico y el formulario permanece visible con los datos ingresados.

**Acceptance Scenarios**:

1. **Given** el campo de contraseña temporal vacío, **When** el usuario envía el formulario, **Then** se muestra un mensaje indicando que debe escribir la contraseña temporal de su invitación y el envío no se completa.
2. **Given** una nueva contraseña que no cumple todos los requisitos, **When** el usuario envía el formulario, **Then** se muestra un mensaje indicando que la nueva contraseña no cumple todos los requisitos y el envío no se completa.
3. **Given** una nueva contraseña válida y una confirmación distinta, **When** el usuario envía el formulario, **Then** se muestra un mensaje indicando que las contraseñas no coinciden y el envío no se completa.

---

### Edge Cases

- ¿Qué pasa si la contraseña temporal ingresada no corresponde a la invitación real (rechazo del servidor)? Debe mostrarse un mensaje de error genérico sin revelar información sensible, y el formulario debe permanecer disponible para reintentar.
- ¿Qué pasa si el usuario intenta usar la misma contraseña temporal como nueva contraseña? Debe bloquearse antes del envío, marcando el requisito "distinta a la temporal" como pendiente, igual que lo valida hoy el sistema.
- ¿Qué pasa si el enlace de invitación ya fue usado previamente (la cuenta ya no requiere cambio de contraseña)? El acceso a esta página debe comportarse según la validación de invitación ya existente en el sistema (fuera del alcance visual de este rediseño).
- ¿Qué pasa en pantallas angostas (menú móvil)? El panel visual promocional del lado derecho se oculta y el formulario ocupa todo el ancho disponible, conservando todos los campos y mensajes.
- ¿Qué pasa si el usuario alterna visibilidad de la contraseña en cualquiera de los tres campos? Cada campo controla su propia visibilidad de forma independiente, sin afectar a los demás.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: La página MUST mostrar el nombre del negocio (tenant) al que fue invitado el usuario, el rol asignado (ej. cajero, admin) y el correo de la cuenta invitada.
- **FR-002**: La página MUST presentar un campo para la contraseña temporal recibida en la invitación, con opción de mostrar u ocultar su contenido.
- **FR-003**: La página MUST presentar un campo para la nueva contraseña (entre 8 y 12 caracteres) con opción de mostrar u ocultar su contenido.
- **FR-004**: La página MUST presentar un campo de confirmación de la nueva contraseña, con opción de mostrar u ocultar su contenido.
- **FR-005**: La página MUST mostrar en tiempo real el estado de cumplimiento de cada requisito de la nueva contraseña definido por las reglas vigentes del sistema: longitud entre 8 y 12 caracteres, y ser distinta a la contraseña temporal.
- **FR-006**: El sistema MUST impedir el envío del formulario y mostrar un mensaje de error cuando la contraseña temporal esté vacía.
- **FR-007**: El sistema MUST impedir el envío del formulario y mostrar un mensaje de error cuando la nueva contraseña no cumpla todos los requisitos definidos.
- **FR-008**: El sistema MUST impedir el envío del formulario y mostrar un mensaje de error cuando la confirmación no coincida exactamente con la nueva contraseña.
- **FR-009**: Al completarse exitosamente el cambio, el sistema MUST reemplazar el formulario por una pantalla de confirmación que indique que la cuenta está lista para iniciar sesión.
- **FR-010**: La pantalla de confirmación MUST ofrecer una acción para dirigir al usuario a la página de inicio de sesión del negocio.
- **FR-011**: La página MUST ocultar el panel visual promocional y ajustar el formulario a ancho completo en pantallas angostas (dispositivos móviles), sin perder ningún campo ni mensaje del formulario.
- **FR-012**: La página MUST incluir en el pie el aviso de derechos de autor del producto y un enlace a la política de privacidad.
- **FR-013**: El diseño visual (tipografía, colores, espaciados, iconografía, estructura de dos columnas con panel promocional) MUST corresponder fielmente al diseño de referencia aportado para esta funcionalidad.

### Key Entities *(include if feature involves data)*

- **Invitación de usuario**: Representa la invitación emitida por un administrador o superadmin a un nuevo usuario; incluye el correo invitado, el rol asignado y el negocio (tenant) al que pertenece.
- **Cuenta de usuario**: Cuenta asociada a la invitación, con una contraseña temporal inicial y una condición de "debe cambiar contraseña" que se desactiva al completar el cambio exitosamente.
- **Política de contraseña**: Conjunto de reglas vigentes en el sistema que debe cumplir la nueva contraseña (longitud entre 8 y 12 caracteres, diferencia respecto a la temporal).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un usuario invitado puede completar el cambio de contraseña y llegar a la pantalla de confirmación en menos de 1 minuto desde que abre la página.
- **SC-002**: El 100% de las violaciones a los requisitos de contraseña (longitud entre 8 y 12 caracteres, diferencia con la temporal) se reflejan visualmente antes de intentar enviar el formulario.
- **SC-003**: Al menos el 95% de los usuarios invitados completan el cambio de contraseña en su primer intento de envío sin necesitar ayuda externa.
- **SC-004**: La página se usa correctamente tanto en pantallas de escritorio como en pantallas angostas de dispositivos móviles, sin pérdida de funcionalidad ni contenido ilegible.

## Assumptions

- Este rediseño aplica exclusivamente a la página de cambio de contraseña obligatorio que ve un usuario invitado en su primer inicio de sesión; no cubre el flujo de cambio de contraseña de un usuario ya autenticado ni un flujo de "recuperar contraseña olvidada".
- Las reglas de validación de contraseña que exige esta página son únicamente las vigentes hoy en el sistema (longitud entre 8 y 12 caracteres y distinta a la contraseña temporal); no se exige mayúscula ni número, aunque el diseño visual de referencia los mostraba como ejemplo. El checklist visual se ajusta a estas dos reglas reales para no prometer validaciones que el backend no aplica. Decisión confirmada con el usuario.
- El comportamiento de backend existente (verificación de la contraseña temporal/actual contra el hash almacenado, mensajes de error específicos por tipo de fallo, limpieza de la condición "debe cambiar contraseña" al completar el cambio, invalidación de sesiones previas) se conserva sin cambios funcionales; este trabajo es una actualización visual y de experiencia de usuario fiel al diseño de referencia, dentro de las reglas reales del sistema.
- El nombre del negocio (tenant) no se muestra actualmente en esta página; mostrarlo requiere que el backend exponga ese dato al cargar la página, como parte de este rediseño.
- El manejo de invitaciones inválidas, expiradas o ya utilizadas antes de llegar a este formulario está fuera del alcance de este rediseño y se rige por la validación de invitaciones ya existente.
- El límite máximo de 12 caracteres para la nueva contraseña se mantiene tal como está definido en el diseño de referencia y coincide con la regla vigente del sistema.
- Tras un cambio exitoso, la acción "Iniciar sesión" reutiliza el comportamiento de redirección ya existente en el sistema (reautenticación y envío a la pantalla principal según el rol del usuario), sin cambios funcionales respecto al flujo actual.
