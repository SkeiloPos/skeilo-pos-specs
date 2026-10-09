# Feature Specification: Gestión de la relación proveedor–insumo

**Feature Branch**: `106-relacion-proveedor-insumo`

**Created**: 2026-10-09

**Status**: Draft

**Input**: User description: "Como administrador de la heladería, quiero registrar qué
proveedores me venden cada insumo, en qué presentación y cuántas unidades base trae esa
presentación, para comprar a varios proveedores sin duplicar insumos y saber a quién pedirle
cada uno." Incluye reglas de negocio RN-16 (un solo preferido activo por insumo) y RN-17
("Compra ocasional" no se vincula ni es preferido), unicidad por (proveedor, insumo,
presentación), y `factor_conversion > 0`. El upsert automático al recibir una compra (RN-15)
queda explícitamente fuera de esta spec y pertenece a HU-05.

## Clarifications

### Session 2026-10-09

- Q: ¿El atributo `es_sistema` del proveedor y el registro semilla "Compra ocasional" deben
  construirse dentro de esta misma spec, o deben salir como una spec previa independiente de la
  que esta dependa? → A: Opción A — se incluyen dentro de esta spec (FR-019 tal cual); no se abre
  una spec previa ni se asume que ya existen en otro lugar.
- Q: ¿El factor de conversión debe aceptar decimales, o solo números enteros? → A: Opción A —
  acepta decimales, hasta 3 posiciones decimales, consistente con el resto de cantidades de
  inventario del sistema (insumos y líneas de compra).
- Q: Cuando el costo por unidad base no es exacto, ¿con cuántos decimales se muestra en la
  equivalencia? → A: Opción A — 2 decimales con redondeo estándar, consistente con el resto de
  valores monetarios del sistema.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Vincular un proveedor a un insumo con presentación y factor (Priority: P1)

Un administrador que está viendo el detalle de un insumo (p. ej. "Almendras") agrega un
proveedor que se lo vende, indicando en qué presentación lo compra (p. ej. "Bolsa x 500 g"),
cuántas unidades base trae esa presentación (el factor de conversión) y, si lo conoce, el
último costo pagado. El mismo insumo puede tener varios proveedores vinculados, cada uno con
su propia presentación y factor, sin que eso cree insumos duplicados ni confunda cuál
presentación corresponde a cuál proveedor.

**Why this priority**: es la operación fundacional de toda la funcionalidad — sin poder crear
la relación, ninguna otra historia (marcar preferido, verla desde el proveedor, desactivarla)
tiene sobre qué operar.

**Independent Test**: se puede probar por completo abriendo el detalle de un insumo existente,
agregando un proveedor con presentación y factor en su pestaña "Proveedores", y verificando que
la relación queda activa sin tocar ninguna otra pantalla.

**Acceptance Scenarios**:

1. **Given** que estoy en la pestaña "Proveedores" del insumo "Almendras" (unidad base "g"),
   **When** agrego "Distribuidora Norte" con presentación "Bolsa x 500 g", factor 500 y último
   costo 8000, **Then** se crea la relación activa, `fecha_ultimo_costo` queda con la fecha y
   hora actuales, la fila muestra "1 Bolsa x 500 g = 500 g · $16/g", y la relación aparece
   también en la pestaña "Insumos que vende" de "Distribuidora Norte".
2. **Given** que "Almendras" ya está vinculada a "Distribuidora Norte" con "Bolsa x 500 g",
   **When** vinculo "Agro Sur" con "Bolsa x 140 g" y factor 140, **Then** el insumo tiene dos
   relaciones activas y no se crea ningún insumo nuevo.
3. **When** intento guardar una relación con factor 0 o negativo, **Then** el sistema la
   rechaza y muestra un mensaje equivalente a "El factor debe ser mayor que 0: indica cuántos g
   trae 1 presentación" (la unidad mostrada es la unidad base del insumo).
4. **Given** que existe "Distribuidora Norte" – "Almendras" – "Bolsa x 500 g", **When** intento
   crear "Distribuidora Norte" – "Almendras" – "bolsa x 500 g " (mismas palabras, distinta
   capitalización y espacios), **Then** el sistema la rechaza como duplicada y me ofrece editar
   la existente en su lugar.
5. **Given** que existe la relación inactiva "Agro Sur" – "Almendras" – "Bolsa x 140 g",
   **When** la agrego de nuevo con los mismos datos, **Then** el sistema reactiva la relación
   existente en lugar de crear una nueva.
6. **Given** que la relación "Bolsa x 500 g" aparece en al menos una línea de compra, **When**
   intento cambiar su factor, **Then** el sistema lo rechaza y sugiere crear una presentación
   nueva en su lugar.

---

### User Story 2 - Marcar un proveedor como preferido de un insumo (Priority: P1)

Entre los varios proveedores vinculados a un mismo insumo, un administrador marca uno como el
preferido — el que normalmente se usaría al reponer ese insumo. Solo puede haber un preferido
activo a la vez por insumo; marcar uno nuevo desmarca automáticamente al anterior.

**Why this priority**: sin un preferido claro, el administrador no tiene forma de saber "a
quién le pido esto primero" cuando varios proveedores venden el mismo insumo — es el segundo
pilar de valor de la funcionalidad, junto con la vinculación misma.

**Independent Test**: se puede probar con un insumo que ya tiene al menos dos proveedores
vinculados, marcando uno como preferido, marcando el otro después, y verificando en cada paso
cuál queda marcado.

**Acceptance Scenarios**:

1. **Given** que "Distribuidora Norte" es el preferido de "Almendras", **When** marco como
   preferida la relación con "Agro Sur", **Then** "Agro Sur" queda como preferido,
   "Distribuidora Norte" deja de serlo, y existe exactamente una relación preferida activa para
   "Almendras" (incluso si dos administradores intentan marcar proveedores distintos como
   preferidos del mismo insumo al mismo tiempo).
2. **When** intento marcar como preferida una relación que está inactiva, **Then** el sistema
   lo rechaza — solo una relación activa puede ser la preferida de un insumo.
3. **When** busco proveedores para vincular a "Almendras" o para marcar como preferido,
   **Then** "Compra ocasional" (el proveedor de sistema) no aparece en el selector, y si la API
   recibe de todos modos una relación o una marca de preferido con un proveedor `es_sistema =
   true`, responde con un error de validación (422) sin aplicar el cambio.

---

### User Story 3 - Ver y gestionar las relaciones desde el detalle del proveedor (Priority: P2)

Un administrador que está viendo el detalle de un proveedor (p. ej. "Distribuidora Norte")
consulta, en su pestaña "Insumos que vende", todos los insumos que ese proveedor le surte, con
su presentación, factor y si es el preferido — y puede crear, editar o desactivar esas mismas
relaciones desde ahí, sin tener que ir una por una al detalle de cada insumo.

**Why this priority**: es la misma relación de las historias 1 y 2 vista "del otro lado" — no
agrega una regla de negocio nueva, pero es necesaria para que el flujo de trabajo real
("¿qué le compro a este proveedor?") sea completo; por eso va después de las historias que
definen las reglas, no antes.

**Independent Test**: se puede probar abriendo el detalle de un proveedor con al menos una
relación activa y verificando que la pestaña "Insumos que vende" la muestra, y que crear o
editar una relación desde ahí produce el mismo resultado que hacerlo desde el insumo.

**Acceptance Scenarios**:

1. **Given** que "Distribuidora Norte" tiene una relación activa con "Almendras", **When** abro
   la pestaña "Insumos que vende" de "Distribuidora Norte", **Then** veo esa relación con su
   presentación, factor, equivalencia y marca de preferido, igual que se ve desde la pestaña
   "Proveedores" del insumo.
2. **Given** cualquier cambio hecho a una relación desde la pestaña del proveedor (crear,
   editar, desactivar, marcar preferido), **When** reviso la pestaña "Proveedores" del insumo
   correspondiente, **Then** el cambio ya está reflejado, sin pasos adicionales.

---

### User Story 4 - Desactivar una relación proveedor-insumo (Priority: P2)

Un administrador deja de comprarle un insumo a un proveedor determinado (dejó de surtirlo,
subió mucho el precio, etc.) y desactiva esa relación en vez de borrarla, conservando el
historial de lo que ya se compró con ella.

**Why this priority**: completa el ciclo de vida de la relación; depende de que ya existan
relaciones activas (Historia 1) y de que el sistema sepa cuál es la preferida (Historia 2) para
poder advertir correctamente al desactivarla.

**Independent Test**: se puede probar desactivando una relación activa (preferida o no) y
verificando su nuevo estado y el aviso mostrado, sin depender de las otras historias más allá
de tener datos de partida.

**Acceptance Scenarios**:

1. **Given** que "Agro Sur" es el preferido de "Almendras", **When** desactivo esa relación,
   **Then** la relación queda inactiva y no preferida, y la interfaz avisa "Sin proveedor
   preferido: no se incluirá en órdenes sugeridas".
2. **Given** una relación activa que no es la preferida del insumo, **When** la desactivo,
   **Then** queda inactiva sin mostrar el aviso de "sin preferido" (el insumo conserva su
   preferido actual sin cambios).

---

### Edge Cases

- Aislamiento entre tenants: dado que el tenant "Heladería B" tiene una relación con id 77,
  cuando desde "Heladería A" se consulta, edita o desactiva la relación 77, la API responde 404
  — nunca revela que la relación existe en otro tenant.
- Un mismo proveedor puede tener varias relaciones activas con el mismo insumo, siempre que
  cada una use una presentación distinta (la unicidad es por `proveedor + insumo +
  presentación`, no por `proveedor + insumo`).
- Si se crea una relación sin indicar último costo, queda activa sin costo ni
  `fecha_ultimo_costo` hasta que se registre uno manualmente o mediante una compra futura.
- Si se desactiva la única relación activa de un insumo, el insumo queda sin ningún proveedor
  vinculado activo; si esa relación era la preferida, aplica el mismo aviso de "sin preferido"
  de la Historia 4.
- Las relaciones inactivas quedan ocultas por defecto en ambas pestañas; existe una opción
  explícita para mostrarlas.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema DEBE permitir crear una relación proveedor-insumo activa, indicando
  presentación (texto libre), factor de conversión y, opcionalmente, último costo, desde la
  pestaña "Proveedores" del detalle de un insumo o desde la pestaña "Insumos que vende" del
  detalle de un proveedor.
- **FR-002**: El factor de conversión DEBE ser estrictamente mayor que cero y DEBE admitir
  decimales (hasta 3 posiciones decimales, consistente con el resto de cantidades de inventario
  del sistema); un valor igual o menor a cero DEBE rechazarse mostrando un mensaje que explique
  su significado en términos de la unidad base del insumo (p. ej. "El factor debe ser mayor que
  0: indica cuántos g trae 1 presentación").
- **FR-003**: La combinación (proveedor, insumo, presentación) DEBE ser única entre todas las
  relaciones del tenant (activas e inactivas), comparando el texto de la presentación sin
  distinguir mayúsculas/minúsculas ni espacios al inicio o al final.
- **FR-004**: Si se intenta crear una relación cuya combinación (proveedor, insumo,
  presentación) ya existe **activa**, el sistema DEBE rechazarla como duplicada y ofrecer editar
  la relación existente en su lugar.
- **FR-005**: Si se intenta crear una relación cuya combinación (proveedor, insumo,
  presentación) ya existe pero **inactiva**, el sistema DEBE reactivarla en lugar de crear una
  fila nueva.
- **FR-006**: Cada vez que se registra o actualiza el último costo de una relación, el sistema
  DEBE fijar automáticamente `fecha_ultimo_costo` con la fecha y hora actuales.
- **FR-007**: El sistema DEBE mostrar, para cada relación con último costo registrado, su
  equivalencia legible en el formato "1 [presentación] = [factor] [unidad base] · $[costo ÷
  factor]/[unidad base]", con el costo por unidad base redondeado a 2 decimales (consistente con
  el resto de valores monetarios del sistema).
- **FR-008**: Un insumo DEBE tener, entre sus relaciones activas, como máximo una marcada como
  preferida en todo momento.
- **FR-009**: Al marcar una relación activa como preferida, el sistema DEBE desmarcar, en la
  misma operación, cualquier otra relación preferida previa del mismo insumo — incluso ante
  solicitudes concurrentes, de forma que nunca quede más de una preferida activa.
- **FR-010**: Solo una relación **activa** puede marcarse como preferida; el intento de marcar
  como preferida una relación inactiva DEBE rechazarse.
- **FR-011**: Al desactivar una relación que está marcada como preferida, el sistema DEBE
  dejarla inactiva y quitarle la marca de preferida en la misma operación, y la interfaz DEBE
  advertir que el insumo queda sin proveedor preferido para órdenes sugeridas.
- **FR-012**: El selector de proveedores para vincular (crear relación o marcar preferido) NO
  DEBE ofrecer ningún proveedor marcado como "de sistema" (p. ej. el proveedor genérico "Compra
  ocasional", reservado para compras sin proveedor identificado); en el listado general de
  proveedores, el proveedor de sistema se muestra sin enlace a su pestaña "Insumos que vende"
  (no tiene una que mostrar).
- **FR-013**: Si una solicitud de creación de relación o de marca de preferido llega con un
  proveedor "de sistema" (`es_sistema = true`), el sistema DEBE rechazarla con un error de
  validación, independientemente de si pasó o no por el selector de la interfaz.
- **FR-014**: Una vez que una relación ha sido referenciada por al menos una línea de compra, el
  sistema NO DEBE permitir modificar su factor de conversión; DEBE rechazar el intento y sugerir
  crear una presentación nueva en su lugar.
- **FR-015**: Toda relación proveedor-insumo DEBE pertenecer a un único tenant. Cualquier
  intento de consultar, editar o desactivar una relación que pertenezca a otro tenant DEBE
  responder como si la relación no existiera.
- **FR-016**: Una relación creada, editada, marcada como preferida o desactivada desde la
  pestaña "Proveedores" del insumo DEBE reflejarse de inmediato en la pestaña "Insumos que
  vende" del proveedor correspondiente, y viceversa, sin pasos adicionales.
- **FR-017**: Las relaciones inactivas DEBEN estar ocultas por defecto en ambas pestañas, con
  una opción explícita para mostrarlas.
- **FR-018**: La etiqueta del campo de factor de conversión DEBE mostrar dinámicamente la
  unidad base del insumo seleccionado, y la equivalencia resultante DEBE recalcularse en vivo
  mientras se edita el formulario, antes de guardar.
- **FR-019**: Esta spec DEBE introducir, como parte de su propio alcance (no de una spec
  separada), el atributo que distingue a un proveedor "de sistema" (`es_sistema`) de un
  proveedor normal, y el registro semilla del proveedor genérico "Compra ocasional" marcado con
  ese atributo — son prerrequisito directo de FR-012 y FR-013 (decisión confirmada en
  Clarifications, Sesión 2026-10-09).

### Key Entities *(include if feature involves data)*

- **Insumo**: ya existe en el sistema. Atributos relevantes a esta spec: nombre genérico y
  unidad base (en la que se expresan el stock y el factor de conversión de sus relaciones). Esta
  spec no modifica su modelo.
- **Proveedor**: ya existe en el sistema. Atributos relevantes a esta spec: nombre, y un nuevo
  atributo `es_sistema` que identifica al proveedor genérico reservado "Compra ocasional"
  (FR-019); un proveedor `es_sistema = true` nunca participa en relaciones proveedor-insumo.
- **Relación Proveedor-Insumo**: entidad N:M nueva de esta spec, que vincula un proveedor con un
  insumo. Atributos: proveedor, insumo, presentación (texto libre, p. ej. "Bolsa x 500 g"),
  factor de conversión (decimal > 0, hasta 3 posiciones decimales; unidades base que trae una
  presentación), último costo pagado (opcional), `fecha_ultimo_costo` (se recalcula
  automáticamente al registrar o actualizar el costo), si está activa, y si es la preferida del
  insumo (como máximo una activa por insumo).
  Es la entidad donde vive la presentación y el factor — el insumo solo guarda su unidad base.
  (Nota: estos son nombres de negocio en español; los identificadores de código en inglés
  correspondientes están en `data-model.md`.)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un administrador puede vincular un nuevo proveedor a un insumo existente, con
  presentación y factor, sin crear ningún insumo ni proveedor duplicado, en menos de 1 minuto.
- **SC-002**: El 100% de los intentos de guardar un factor de conversión igual o menor a cero es
  rechazado con un mensaje que explica qué representa el factor para ese insumo.
- **SC-003**: En todo momento, el 100% de los insumos con al menos una relación activa tiene
  como máximo un proveedor preferido — verificable consultando sus relaciones en cualquier
  momento, incluso tras marcas de preferido concurrentes.
- **SC-004**: El 100% de los intentos de vincular o preferir al proveedor de sistema es
  rechazado, tanto desde la interfaz (no aparece en el selector) como desde una solicitud
  directa que lo intente de todas formas.
- **SC-005**: El 100% de los intentos de consultar, editar o desactivar una relación que
  pertenece a otro tenant recibe una respuesta equivalente a "no encontrado", sin filtrar
  información de su existencia.
- **SC-006**: Un administrador puede responder, para cualquier insumo, "¿a qué proveedores se
  lo puedo pedir y en qué presentación?" consultando únicamente el detalle de ese insumo, sin
  necesitar abrir el detalle de cada proveedor por separado.
- **SC-007** (ver FR-014): El 100% de los intentos de cambiar el factor de una relación ya
  usada en al menos una compra es rechazado, sugiriendo crear una presentación nueva en su
  lugar.

## Out of Scope

- **El alta o actualización automática de relaciones proveedor-insumo al registrar una compra**
  (upsert automático, RN-15) — pertenece a HU-05. Esta spec únicamente expone la gestión manual
  y las validaciones (unicidad, preferido único por insumo, exclusión del proveedor de sistema)
  que HU-05 DEBE reutilizar en el servicio, no solo en el selector de su propia interfaz.
- **El cálculo o uso de órdenes de compra sugeridas** (RN-23) a partir del proveedor preferido —
  esta spec solo garantiza que exista como máximo un preferido activo por insumo; qué se hace
  con esa información pertenece a otra funcionalidad.
- **La creación o edición de insumos y proveedores en sí mismos** (nombre, unidad base, datos de
  contacto, etc.) — esta spec solo cubre la relación entre ambos, que ya deben existir de
  antemano.
- **El promedio ponderado o cualquier otra forma de calcular costo distinta a "último costo
  registrado"** — fuera de alcance; esta spec solo almacena y muestra el último costo capturado
  manualmente en la relación.

## Assumptions

- **El proveedor de sistema "Compra ocasional" y el atributo `es_sistema` no existen todavía en
  el catálogo de proveedores** (hoy el modelo de proveedor no distingue proveedores de sistema de
  proveedores normales). Confirmado en Clarifications (Sesión 2026-10-09): se introducen dentro
  de esta misma spec (FR-019), no como una spec previa independiente ni asumiendo que ya existen.
- **Unicidad de presentación insensible a mayúsculas y espacios**: dado que los propios
  criterios de aceptación exigen que "Bolsa x 500 g" y "bolsa x 500 g " cuenten como la misma
  presentación, esta spec especifica la comparación normalizada (minúsculas, sin espacios al
  inicio/final) como parte del contrato funcional, no como un detalle de implementación
  opcional.
- **El bloqueo de edición del factor tras su uso en compras (FR-014) se especifica como regla
  de negocio desde ya**: esta spec agrega la columna vacía que sostiene el enlace entre una
  línea de compra y esta relación (sin poblarla desde ningún flujo propio); HU-05 es quien la
  puebla al implementar el upsert automático (RN-15) — queda lista para que HU-05 la reutilice
  sin reabrir la pregunta de si el factor debe protegerse.
- **El texto de la presentación y el proveedor de una relación no quedan explícitamente
  bloqueados tras su uso en compras** (a diferencia del factor) — esta spec no extiende esa
  protección más allá de lo que piden los criterios de aceptación; ampliarla requeriría una
  decisión de negocio futura.
- **Permisos**: esta spec asume que gestionar relaciones proveedor-insumo requiere el mismo
  nivel de permiso que el resto de la administración de inventario (administrador o rol
  equivalente con permiso de gestión de inventario), consistente con el resto del sistema.
- **Último costo opcional al crear**: si no se indica al crear la relación, esta queda activa
  sin costo ni `fecha_ultimo_costo` hasta que se registre uno manualmente o mediante una compra
  futura (HU-05).
