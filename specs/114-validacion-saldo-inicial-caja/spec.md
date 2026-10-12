# Feature Specification: Validación de saldo inicial mayor a cero al abrir caja

**Feature Branch**: `114-validacion-saldo-inicial-caja`

**Created**: 2026-10-12

**Status**: Draft

**Input**: User description: "Añadir una validación estricta en el formulario de apertura de
caja (turno) para impedir que los cajeros o administradores inicien operaciones con un saldo
inicial (base de efectivo) en 0 o negativo. El objetivo es garantizar la precisión en los
arqueos de caja y evitar discrepancias operativas al momento de calcular el efectivo disponible
al cierre del turno. Debe validarse tanto en frontend como en backend; el backend debe rechazar
con HTTP 422 cuando el saldo inicial sea 0 o negativo."

## Contexto y comportamiento actual

**Esta funcionalidad cambia un comportamiento existente, no corrige un vacío.** A diferencia del
resto de esta spec (que describe el comportamiento deseado en términos de negocio, sin detalles
de implementación), esta sección sí nombra archivos y mecanismos concretos del código actual —
es la evidencia que sustenta, conforme al Principio II de la constitución del proyecto, que el
valor cero es hoy un comportamiento permitido a propósito y no un vacío accidental. Hoy el
sistema permite explícitamente abrir un turno con saldo inicial en `0`:

- El backend (`pos-backend/app/api/v1/cash/schemas.py`) valida el saldo inicial con
  `Field(0, ge=0, ...)` — `ge=0` acepta cero a propósito, y `0` es el valor por defecto.
- La tabla `cash_shifts` tiene un `CheckConstraint("opening_amount >= 0", ...)` — a nivel de
  base de datos, cero también es un valor válido hoy.
- El frontend (`pos-heladeria`, componente `cash-open.component.ts`) solo deshabilita el botón
  "Abrir caja y comenzar turno" cuando no se ha seleccionado una caja; el campo del saldo
  inicial (`app-money-input`) inicia en `0` y no tiene ninguna validación propia hoy.

Por lo anterior, conforme al Principio II de la constitución del proyecto (el comportamiento
existente sigue protegido salvo decisión de negocio explícita), este cambio debe quedar
registrado como una decisión de negocio en
`specs/000-reconocimiento/registro-de-anomalias.md` antes de implementarse, señalando que se
pasa de permitir `opening_amount >= 0` a exigir `opening_amount > 0`, aplicando únicamente hacia
adelante (ver Assumptions).

## Clarifications

### Session 2026-10-12

- Q: ¿El mensaje de validación del saldo inicial debe aparecer desde que se carga la pantalla
  (porque el campo ya está en `0` por defecto), o solo después de que el usuario interactúe con
  el campo (lo toque y pierda el foco)? → A: debe aparecer de inmediato, desde la carga de la
  pantalla, mientras el saldo sea `0` o esté vacío, sin esperar ninguna interacción del usuario
  con el campo.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - El cajero no puede abrir turno con saldo inicial en cero o vacío (Priority: P1)

Un cajero llega a la pantalla de apertura de caja. Si deja el campo del saldo inicial en su
valor por defecto (cero) o lo vacía, el sistema le impide continuar y le explica, en el propio
formulario, que necesita declarar una base de efectivo real antes de abrir el turno.

**Why this priority**: es el escenario más frecuente — el campo inicia en cero y un cajero
apurado podría presionar "Abrir caja" sin fijarse en ese valor. Sin esta guarda, el turno queda
abierto con una base que no refleja el efectivo real entregado, invalidando el arqueo de cierre
desde el origen.

**Independent Test**: se puede probar abriendo la pantalla de apertura, seleccionando una caja
sin modificar el saldo inicial (queda en `0`), e intentando presionar "Abrir caja y comenzar
turno".

**Acceptance Scenarios**:

1. **Given** que acabo de llegar a la pantalla "Abrir caja" con una caja seleccionada y el saldo
   inicial en `0` (valor por defecto, sin haber tocado todavía el campo), **When** observo la
   pantalla, **Then** el campo ya muestra, de inmediato y sin esperar ninguna interacción mía,
   el mensaje "El saldo inicial debe ser mayor a cero para abrir la caja" debajo del campo, y el
   botón "Abrir caja y comenzar turno" está deshabilitado, de modo que si intento presionarlo no
   se envía ninguna petición al servidor.
2. **Given** que estoy en esa misma pantalla, **When** borro por completo el contenido del campo
   de saldo inicial (queda vacío), **Then** el sistema trata ese estado igual que el cero: botón
   deshabilitado y mismo mensaje de validación.
3. **Given** que el campo muestra el mensaje de error por estar en cero, **When** ingreso un
   valor mayor a cero, **Then** el mensaje desaparece y el botón se habilita inmediatamente
   (siempre que también haya una caja seleccionada), sin necesidad de recargar la pantalla.

---

### User Story 2 - El backend rechaza la apertura de turno si el saldo inicial no es estrictamente mayor a cero (Priority: P1)

Un cliente HTTP (la aplicación web u otro integrador que use directamente la API) envía una
solicitud para abrir turno con un saldo inicial igual a cero o negativo. El servidor rechaza la
solicitud sin crear ningún turno, sin importar si la petición vino del formulario normal o de
una llamada directa a la API.

**Why this priority**: es la garantía real — ninguna validación de interfaz es suficiente por sí
sola si el servidor sigue aceptando el valor inválido ante una petición directa. Esta es la
regla que efectivamente impide que el dato inválido llegue a la base de datos.

**Independent Test**: se puede probar invocando el endpoint de apertura de turno directamente
(sin pasar por el formulario) con `opening_amount=0` y, por separado, con un valor negativo,
verificando en ambos casos que no se crea el turno.

**Acceptance Scenarios**:

1. **Given** una caja registradora sin turno abierto, **When** se solicita abrir turno con un
   saldo inicial igual a `0`, **Then** el servidor responde `422 Unprocessable Entity` indicando
   que el saldo inicial es obligatorio y debe ser mayor a cero, y no se crea ningún registro de
   turno.
2. **Given** esa misma caja, **When** se solicita abrir turno con un saldo inicial negativo
   (p. ej. `-50000`), **Then** el servidor responde `422 Unprocessable Entity` con el mismo
   criterio, y no se crea ningún registro de turno.
3. **Given** esa misma caja, **When** se solicita abrir turno con un saldo inicial estrictamente
   mayor a cero, **Then** el servidor crea el turno normalmente, sin cambios respecto al
   comportamiento actual para valores válidos.

---

### User Story 3 - Apertura exitosa con un saldo inicial válido (Priority: P2)

Un cajero ingresa un saldo inicial mayor a cero y abre el turno con normalidad, sin que la nueva
validación interfiera con el flujo habitual.

**Why this priority**: confirma que la nueva restricción no introduce fricción adicional al
camino feliz, que es el que ocurre en la inmensa mayoría de las aperturas de caja del día a día.

**Independent Test**: se puede probar seleccionando una caja, ingresando un monto mayor a cero
(p. ej. `50000`) y presionando "Abrir caja y comenzar turno".

**Acceptance Scenarios**:

1. **Given** una caja seleccionada y un saldo inicial válido mayor a cero, **When** presiono
   "Abrir caja y comenzar turno", **Then** el sistema procesa la solicitud, abre el turno con esa
   base de efectivo y me lleva a la terminal de ventas/mesas, exactamente como ocurre hoy para
   valores positivos.

---

### Edge Cases

- **Campo vacío vs. campo en cero**: ambos se tratan de forma idéntica en el frontend — ninguno
  de los dos habilita el botón de apertura (User Story 1, escenario 2).
- **Signo negativo en el campo del formulario**: el campo de saldo inicial (`app-money-input`)
  ya descarta cualquier carácter que no sea un dígito o una coma decimal mientras el usuario
  escribe, así que hoy es físicamente imposible teclear un valor negativo en ese campo. Esta
  spec no modifica ese comportamiento del campo; el rechazo de valores negativos se garantiza
  exclusivamente a nivel de backend (User Story 2, escenario 2), que sigue siendo la única vía
  por la que un valor negativo podría llegar a intentarse (por ejemplo, desde una integración
  distinta al frontend actual).
- **Turnos que ya están abiertos hoy con saldo inicial en cero** (si existieran): esta validación
  aplica únicamente a partir del momento en que se despliega — no se recalculan, no se cierran
  forzosamente ni se modifican turnos ya abiertos con anterioridad (ver Assumptions).
- **Decimales en el saldo inicial**: el campo del formulario ya limita la entrada a pesos
  enteros (sin centavos) en esta pantalla; esta spec no cambia esa configuración ni agrega una
  restricción adicional de enteros a nivel de backend — solo agrega la exigencia de que el
  valor sea estrictamente mayor a cero, manteniendo el soporte de decimales que el backend ya
  tiene para otros consumidores.
- **Petición que omite el campo del saldo inicial por completo** (sin enviarlo en el cuerpo de
  la solicitud): se trata igual que enviarlo en `0`, dado que el comportamiento actual usa `0`
  como valor por defecto cuando el campo no se envía.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema NO DEBE permitir que se abra un turno de caja con un saldo inicial
  (`opening_amount`) menor o igual a cero.
- **FR-002**: El formulario de apertura de caja DEBE deshabilitar el botón "Abrir caja y
  comenzar turno" mientras el saldo inicial sea cero, esté vacío o sea inválido, además de la
  condición ya existente de tener una caja seleccionada.
- **FR-003**: El formulario de apertura de caja DEBE mostrar, debajo del campo de saldo inicial,
  el mensaje "El saldo inicial debe ser mayor a cero para abrir la caja" cuando el valor sea
  cero o esté vacío — incluyendo de inmediato al cargar la pantalla, dado que el campo inicia en
  `0` por defecto, sin esperar a que el usuario toque el campo ni intente enviar el formulario —,
  y DEBE ocultar ese mensaje en cuanto el valor ingresado sea válido.
- **FR-004**: El endpoint que abre un turno de caja DEBE rechazar con `422 Unprocessable Entity`
  cualquier solicitud cuyo saldo inicial sea igual o menor a cero, sin crear ningún turno ni
  registro asociado.
- **FR-005**: El mensaje de error devuelto por el backend ante un saldo inicial inválido DEBE
  indicar explícitamente que el saldo inicial es obligatorio y debe ser mayor a cero.
- **FR-006**: La validación del backend (FR-004) DEBE aplicarse sin importar el origen de la
  solicitud — tanto si proviene del formulario normal como de cualquier otro cliente que llame
  directamente al endpoint.
- **FR-007**: La validación NO DEBE aplicarse retroactivamente: los turnos que ya estén abiertos
  o cerrados antes de desplegar este cambio, incluidos los que tengan `opening_amount` en cero,
  NO DEBEN modificarse, bloquearse ni forzarse a cerrar como consecuencia de esta funcionalidad.
- **FR-008**: El cambio de comportamiento descrito en FR-001/FR-004 (de permitir `opening_amount
  >= 0` a exigir `opening_amount > 0`) DEBE quedar registrado como decisión de negocio en
  `specs/000-reconocimiento/registro-de-anomalias.md`, conforme al Principio II de la
  constitución del proyecto, antes de implementarse.
- **FR-009**: Para un saldo inicial estrictamente mayor a cero, el sistema DEBE comportarse
  exactamente igual que hoy: el turno se abre con normalidad y el usuario es dirigido a la
  terminal de ventas/mesas.

### Key Entities *(include if feature involves data)*

- **CashShift (turno de caja)**: entidad ya existente. Esta spec acota su atributo
  `opening_amount` (saldo/fondo inicial en efectivo con el que se abre el turno) a valores
  estrictamente mayores a cero desde el momento de este cambio en adelante; el resto de sus
  atributos (caja asociada, cajero, estado, conteo de cierre, etc.) no se ve afectado.
- **CashRegister (caja registradora)**: entidad ya existente, referenciada aquí únicamente como
  precondición para abrir un turno; esta spec no modifica su comportamiento.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100% de los intentos de abrir un turno con saldo inicial igual a cero o vacío,
  desde el formulario, quedan bloqueados antes de enviar cualquier solicitud al servidor.
- **SC-002**: El 100% de las solicitudes directas al servidor para abrir un turno con saldo
  inicial igual o menor a cero son rechazadas con `422`, sin excepción, y ningún turno queda
  creado en esos casos.
- **SC-003**: El 100% de las aperturas de turno con saldo inicial válido (mayor a cero) se
  completan sin fricción adicional ni cambio perceptible respecto al flujo actual.
- **SC-004**: Cero turnos nuevos quedan registrados en el sistema con `opening_amount <= 0`
  desde el momento en que esta funcionalidad se despliega.

## Assumptions

- **Alcance acotado a la validación de "mayor a cero"**: esta spec únicamente agrega la
  exigencia de que el saldo inicial sea estrictamente positivo. No introduce un monto mínimo de
  negocio adicional (p. ej. un piso en pesos) más allá de excluir el cero y los negativos, ni
  cambia el tipo de dato existente para exigir enteros sin decimales — el backend conserva el
  soporte de decimales que ya tiene hoy, aunque el formulario de apertura ya limita la entrada a
  pesos enteros en esta pantalla específica.
- **Aplicación únicamente hacia adelante**: la validación rige para las aperturas de turno
  creadas a partir del despliegue de este cambio. Los turnos ya abiertos o cerrados con
  anterioridad, incluidos los que tengan `opening_amount` en cero (si existieran), no se tocan
  ni se migran retroactivamente como parte de esta spec.
- **El campo del formulario sigue sin aceptar el signo negativo**: el componente de saldo
  inicial ya impide físicamente escribir un valor negativo (filtra cualquier carácter que no sea
  dígito o coma mientras el usuario teclea). Esta spec no modifica esa restricción del
  componente; el rechazo de valores negativos queda garantizado por la validación del backend
  (FR-004), que es la que efectivamente puede recibir un valor negativo desde un cliente
  distinto al formulario actual.
- **Mensaje de error del backend**: el mensaje devuelto en el `422` sigue el mismo patrón que
  usan hoy otros endpoints del módulo de caja (mensajes explícitos en español, no el formato de
  error genérico de validación), para mantener consistencia con el resto de la API de caja.
- **Requiere decisión de negocio registrada**: dado que el comportamiento actual permite `0`
  explícitamente (no es un vacío ni un descuido), este cambio se trata como una decisión de
  negocio que debe registrarse en el registro de anomalías antes de implementarse (FR-008),
  conforme al Principio II de la constitución del proyecto.
