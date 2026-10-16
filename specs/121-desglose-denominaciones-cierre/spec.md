# Feature Specification: Desglose por denominación en el arqueo de cierre de caja

**Feature Branch**: `121-desglose-denominaciones-cierre`

**Created**: 2026-10-15

**Status**: Draft

**Input**: User description: "Persistir el desglose físico por denominación (billetes y monedas)
ingresado por el cajero durante el arqueo de caja al momento de cerrar el turno, y reflejarlo en
el reporte de cierre (pantalla, impresión y exportación), para que los administradores puedan
auditar la caja, investigar descuadres y verificar el efectivo físico entregado sin depender
únicamente del monto total. El frontend envía únicamente el arreglo `{ denominación, cantidad }`
y el backend calcula de forma autoritativa el subtotal, el efectivo contado y la diferencia. El
backend expone un catálogo oficial de denominaciones por tenant (COP por defecto). Cada línea se
guarda como snapshot inmutable (valor y tipo `billete`/`moneda`, sin FK al catálogo) y solo se
guardan las líneas con cantidad mayor a cero. Una vez cerrado el turno el desglose no se puede
editar, sobrescribir ni eliminar. Los turnos históricos sin desglose muestran «No se registró
desglose para este turno»."

## Contexto y comportamiento actual

**Esta funcionalidad completa y endurece algo que ya existe a medias; no parte de cero.** A
diferencia del resto de esta spec (que describe el comportamiento deseado en términos de
negocio), esta sección sí nombra archivos y mecanismos del código actual: es la evidencia que
sustenta, conforme al Principio II de la constitución, qué comportamiento existente cambia y cuál
se conserva. Hoy el sistema ya hace lo siguiente:

- **Persiste un desglose rudimentario.** La tabla `cash_count_denominations`
  (`pos-backend/app/models/cash_count_denomination.py`) guarda, por turno, el valor de la
  denominación y la cantidad. No guarda el **tipo** (billete o moneda), acepta cantidad `0` y
  tiene una clave foránea al turno con borrado en cascada.
- **El cierre acepta el total desde el cliente.** El cierre de turno
  (`pos-backend/app/api/v1/cash/router.py`, `close_shift`) recibe `counted_amount`,
  `denominations` y `close_note`. Si llegan denominaciones, el servidor calcula
  `Σ(denominación × cantidad)` e ignora `counted_amount`; si no llegan, usa `counted_amount` tal
  cual; y si no llega ninguno, cierra el turno con el efectivo contado vacío (`RN-CASH-09`,
  anomalía A-20, hoy mitigada solo por la pantalla).
- **El frontend lleva la lista fija y calcula el total.** El store del arqueo
  (`pos-heladeria/.../cash-register/services/cash-session.store.ts`) tiene la lista fija
  `DENOMS` de once valores COP, calcula en el navegador el total contado y envía
  `counted_amount` junto con las líneas con cantidad mayor que `0` (`confirmarArqueoYCerrar`
  ya descarta las de cantidad `0` con `.filter((d) => d.quantity > 0)`).
- **El reporte ya recibe el desglose pero no lo muestra.** El reporte consolidado del turno
  (`GET /cash/shifts/{id}/report`) ya devuelve las denominaciones (valor y cantidad), pero
  `cash-report.component.ts` no las pinta y el botón «Imprimir / Exportar reporte» solo invoca
  la impresión del navegador (`window.print()`, specs 087/089/090).
- **Ya hay protecciones que esta spec conserva.** Un turno cerrado responde `409` si se intenta
  cerrar de nuevo (`RN-CASH-11`); la diferencia distinta de cero exige observación (`RN-CASH-10`);
  el cierre se bloquea con pedidos activos sin cobrar (spec 119, A-129).
- **El tenant no tiene noción de moneda ni de catálogo de denominaciones.**
- **El turno no registra quién lo cerró.** `cash_shifts.user_id`/`user_name` son del usuario que
  **abrió** el turno; el cierre acepta a cualquier usuario autenticado, que puede ser distinto
  del de apertura, y hoy no queda rastro de quién confirmó el conteo.

### Decisiones de negocio que cambian comportamiento existente

Conforme al Principio II y al Flujo de Trabajo de la constitución, estas decisiones deben quedar
registradas en `specs/000-reconocimiento/registro-de-anomalias.md` (siguiente número libre tras
A-129) **antes** de implementar. Todas fueron tomadas por el solicitante de esta spec en la
sesión de clarificación del 2026-10-15.

| ID | Comportamiento que cambia | Hoy | Desde esta spec | Funcionalidades afectadas |
|----|---------------------------|-----|-----------------|---------------------------|
| D-1 | Quién calcula el efectivo contado | El cliente puede enviarlo (`counted_amount`), y sin desglose se usa tal cual | Solo el servidor lo calcula a partir del desglose; un valor monetario enviado por el cliente se rechaza | Cierre de turno, arqueo (modal), `RN-CASH-09`, anomalía A-20 |
| D-2 | Cierre sin conteo | Permitido: el turno se cierra con el contado vacío | Ya no existe: una lista vacía significa contado $0 (caja vacía) y, si hay esperado, exige observación. Es un contrato de la API; la pantalla conserva su bloqueo con todo en cero | Cierre de turno, reportes de cierre |
| D-3 | Líneas con cantidad cero | Se guardan | No se guardan; las ya guardadas se descartan en la migración | Persistencia del arqueo, migración de datos |
| D-4 | Tipo de la denominación | No se registra | Cada línea registra si es billete o moneda | Persistencia, reporte, migración de datos |
| D-5 | Quién cerró el turno | No queda rastro: `user_id`/`user_name` son de quien abrió | Se registra el usuario autenticado que confirma el conteo (FR-029) y el reporte lo muestra como «Contado por» | Cierre de turno, reporte de cierre |
| D-6 | Campo de observación del arqueo | Solo visible cuando la estimación muestra diferencia | Siempre visible (opcional si cuadra, obligatorio si no) (FR-025) | Modal de arqueo |

## Clarifications

### Session 2026-10-15

- Q: ¿Cómo debe comportarse el cierre frente a `counted_amount` y al cierre sin conteo? → A:
  contrato estricto. Si el cierre trae `counted_amount` (o cualquier valor monetario calculado)
  se rechaza con `422`. Una lista vacía es válida y significa efectivo contado $0 (caja vacía):
  no persiste líneas y, si el esperado es mayor a cero, exige observación por el descuadre. Se
  elimina la ruta de «monto único» de `RN-CASH-09`.
- Q: ¿Qué alcance tiene el «catálogo dinámico por tenant»? → A: solo lectura. Cada tenant
  (nuevos y existentes) recibe el catálogo COP por defecto y el backend lo expone; el frontend
  deja de tener la lista fija. No hay pantalla de administración del catálogo en esta spec.
- Q: ¿Qué se hace con las filas de `cash_count_denominations` que ya existen? → A: migrarlas
  deduciendo el tipo desde el catálogo COP por defecto y descartando las filas con cantidad `0`
  (por `RN-05`, no aportan información). Los turnos que conservan filas muestran su desglose;
  solo los que no tienen ninguna muestran el mensaje de `RN-07`.
- Q: ¿Qué se entiende por «exportar» el reporte? → A: se mantiene la impresión del navegador
  (que ya permite guardar como PDF). La tabla del desglose entra al diseño de impresión
  existente; no se agrega descarga de archivo desde el servidor.
- Q: ¿Qué pasa con el total y la diferencia «en vivo» del modal de arqueo? → A: se conservan
  como **vista previa informativa**, marcada como estimado. Los valores oficiales son los que
  calcula el servidor al cerrar y el reporte siempre muestra esos; si difieren, prevalece el
  servidor.
- Q: ¿Qué hacer si la petición trae la misma denominación dos veces? → A: se rechaza con `422`
  indicando la denominación repetida; el turno sigue abierto.
- Q: Si el catálogo de denominaciones no se puede cargar al abrir el arqueo (falla de red, error
  del servidor o catálogo vacío), ¿qué debe hacer el modal? → A: bloquear la confirmación del
  cierre, mostrar un mensaje de error claro con «Reintentar» y no permitir cerrar hasta que el
  catálogo cargue (aplica también si llega vacío). No hay lista de respaldo en el frontend ni
  cierre como caja vacía por esta vía.
- Q: Cuando el cajero deja todas las cantidades en cero, ¿el modal de arqueo debe permitirle
  confirmar el cierre como «caja vacía»? → A: no. Se conserva el comportamiento actual: con todas
  las cantidades en cero el botón de confirmar permanece deshabilitado. La «caja vacía = $0» es
  un contrato del servidor (lista vacía), ejercible solo por API; la pantalla no la ofrece.
  Limitación aceptada: un turno con efectivo esperado $0 no se puede cerrar desde la pantalla.
- Q: Durante el despliegue, un cajero con la pantalla de la versión anterior abierta seguirá
  enviando el total contado y recibirá `422` al cerrar; ¿cómo se maneja esa ventana? → A: sin
  tolerancia en el servidor. Backend y frontend se despliegan de forma coordinada, y el `422` por
  valor monetario enviado trae un mensaje en español que indica recargar la aplicación; el turno
  sigue abierto.
- Q: ¿El sistema debe registrar y mostrar en el reporte qué usuario confirmó el conteo y cerró el
  turno, o basta con mostrar al cajero que lo abrió? → A: registrarlo. Al cerrar, el servidor
  guarda el usuario autenticado que confirma el conteo (id y nombre como snapshot, igual que el
  usuario de apertura) y el reporte lo muestra en «Desglose del conteo» como «Contado por». Los
  turnos históricos, que no lo tienen, no muestran esa línea.
- Q: Si la pantalla estimaba que el arqueo cuadraba pero el servidor calcula una diferencia
  distinta de cero (p. ej., entró una venta en efectivo desde otro terminal con el modal abierto),
  ¿cómo puede el cajero escribir la observación obligatoria? → A: el campo de observación está
  siempre visible en el modal (opcional si la estimación cuadra, obligatorio si no); ante el
  `422` por observación faltante el modal sigue abierto, con el campo disponible y el mensaje del
  servidor. No se recarga el esperado automáticamente.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - El cajero cierra el turno con su conteo por denominación y el servidor calcula los totales (Priority: P1)

Al terminar la jornada, el cajero abre el arqueo, ingresa cuántos billetes y monedas de cada
denominación tiene en el cajón y confirma el cierre. El sistema guarda ese desglose, calcula por
su cuenta el efectivo contado y la diferencia contra el efectivo esperado, y deja el turno
cerrado. El cajero ya no puede influir en el total: solo declara cantidades.

**Why this priority**: es el corazón de la funcionalidad. Sin esto no hay desglose confiable que
auditar; hoy el total que decide el resultado del turno puede venir del navegador.

**Independent Test**: se puede probar cerrando un turno con efectivo esperado de $115.000 y
enviando 1 billete de $100.000, 1 de $10.000 y 1 de $5.000, y verificando las líneas guardadas,
el efectivo contado y la diferencia calculados por el servidor.

**Acceptance Scenarios**:

1. **Given** un turno abierto en «Caja 1» con efectivo esperado de $115.000, **When** el cajero
   ingresa 1 billete de $100.000, 1 de $10.000 y 1 de $5.000 y confirma el arqueo, **Then** el
   sistema guarda exactamente 3 líneas de desglose, calcula un efectivo contado de $115.000 y una
   diferencia de $0, y deja el turno cerrado.
2. **Given** ese mismo turno con efectivo esperado de $115.000, **When** el cajero ingresa 1
   billete de $100.000 y 1 de $10.000, escribe la observación obligatoria y confirma, **Then** el
   servidor calcula un efectivo contado de $110.000 y una diferencia de -$5.000 (faltante), y
   cierra el turno con la observación registrada.
3. **Given** la misma situación del escenario anterior, **When** el cajero confirma **sin**
   escribir observación, **Then** el sistema rechaza el cierre con `422` y el turno sigue abierto
   (se conserva `RN-CASH-10`).
4. **Given** una petición de cierre con cantidades en `0` para algunas denominaciones, **When**
   el servidor la procesa, **Then** acepta la petición pero **no** guarda las líneas con cantidad
   cero (`RN-05`).
5. **Given** una petición de cierre enviada al servidor con la lista vacía (o sin ninguna línea
   con cantidad mayor a cero) y con observación, **When** el servidor la procesa, **Then**
   registra efectivo contado $0, no guarda líneas y calcula la diferencia como el negativo del
   efectivo esperado. (Este camino es del contrato de la API; la pantalla no lo ofrece, ver User
   Story 3, escenario 7.)
6. **Given** cualquier cierre, **When** el cliente envía un valor de total, efectivo contado,
   diferencia o subtotal (por ejemplo `counted_amount`), **Then** el sistema lo rechaza con `422`
   y el turno sigue abierto (ver User Story 2).

---

### User Story 2 - El servidor rechaza cualquier conteo inválido sin cerrar el turno ni guardar nada (Priority: P1)

Si la petición de cierre contiene una denominación que el negocio no maneja, una cantidad
imposible, una denominación repetida o un total calculado por el cliente, el sistema la rechaza
por completo: el turno queda abierto y no se guarda ni una sola línea, de modo que el cajero
puede corregir y reintentar.

**Why this priority**: es la garantía de integridad del desglose. Sin ella, un cliente
manipulado o un error de pantalla podría dejar un conteo imposible grabado para siempre en un
turno cerrado.

**Independent Test**: se puede probar enviando cierres con una denominación fuera del catálogo,
con una cantidad negativa, con una cantidad decimal, con una denominación repetida y con un
`counted_amount`, y verificando en cada caso `422`, turno abierto y cero líneas guardadas.

**Acceptance Scenarios**:

1. **Given** una petición de cierre que incluye una denominación no registrada para el tenant
   (por ejemplo $3.000), **When** el servidor la procesa, **Then** responde `422` indicando cuál
   es la denominación inválida, el turno permanece abierto y no se guarda ningún registro.
2. **Given** una petición que incluye una cantidad negativa o un número no entero, **When** el
   servidor la procesa, **Then** la rechaza con `422` y el turno permanece abierto.
3. **Given** una petición que trae la misma denominación dos veces, **When** el servidor la
   procesa, **Then** la rechaza con `422` indicando la denominación repetida y el turno sigue
   abierto.
4. **Given** una petición que trae un valor monetario calculado por el cliente (efectivo
   contado, total, diferencia o subtotal), **When** el servidor la procesa, **Then** la rechaza
   con `422`, con un mensaje en español que indica recargar la aplicación (caso típico: pantalla
   de la versión anterior abierta durante el despliegue), y el turno sigue abierto.
5. **Given** una petición con varias líneas válidas y una sola inválida, **When** el servidor la
   procesa, **Then** no se guarda ninguna de las líneas válidas (todo o nada).
6. **Given** que el turno ya tiene pedidos activos sin cobrar, **When** se intenta cerrar,
   **Then** se mantiene el bloqueo `409` de la spec 119, sin cambios.

---

### User Story 3 - El arqueo se arma desde el catálogo de denominaciones del negocio (Priority: P1)

Cuando el cajero abre el arqueo, la pantalla muestra una fila por cada denominación que el
negocio maneja, tomada del catálogo del tenant (por defecto, pesos colombianos: billetes de
$100.000, $50.000, $20.000, $10.000, $5.000 y $2.000; monedas de $1.000, $500, $200, $100 y
$50), de mayor a menor. El cajero teclea cantidades; la pantalla le muestra un total y una
diferencia estimados, y al confirmar envía solo denominación y cantidad.

**Why this priority**: el catálogo es lo que le da al servidor una lista oficial contra la cual
validar (User Story 2) y al frontend una lista que ya no está fija en el código.

**Independent Test**: se puede probar abriendo el arqueo en un tenant con el catálogo por defecto
y verificando que se muestran las once denominaciones con su tipo, que el total estimado se
actualiza al teclear, y que lo que se envía al cerrar contiene solo denominación y cantidad de
las líneas con cantidad mayor a cero.

**Acceptance Scenarios**:

1. **Given** un tenant con el catálogo por defecto, **When** el cajero abre el arqueo, **Then**
   ve las 11 denominaciones, ordenadas de mayor a menor, identificadas como billete o moneda.
2. **Given** que el cajero teclea cantidades, **When** cambia cualquiera, **Then** el total y la
   diferencia estimados se actualizan al instante y aparecen rotulados como estimado.
3. **Given** que el cajero confirma el cierre, **When** el servidor responde, **Then** la pantalla
   muestra los valores oficiales calculados por el servidor, no los estimados.
4. **Given** que el catálogo cambió entre que se abrió el arqueo y se confirmó el cierre, **When**
   el servidor rechaza una denominación, **Then** el modal sigue abierto, indica cuál denominación
   ya no es válida y permite corregir.
5. **Given** cualquier tenant, existente o nuevo, **When** consulta el catálogo, **Then** obtiene
   el catálogo por defecto sin que nadie haya tenido que configurarlo.
6. **Given** que el catálogo no se puede cargar al abrir el arqueo (falla de red, error del
   servidor o respuesta vacía), **When** el cajero ve el modal, **Then** el botón de confirmar el
   cierre está deshabilitado, se muestra un mensaje de error con la acción «Reintentar», y el
   cierre solo se habilita cuando el catálogo carga con al menos una denominación; el turno
   permanece abierto y no se envía ninguna petición de cierre.
7. **Given** el modal de arqueo con todas las cantidades en cero, **When** el cajero lo mira,
   **Then** el botón de confirmar el cierre permanece deshabilitado (comportamiento actual que se
   conserva) y se habilita al ingresar al menos una cantidad mayor a cero.
8. **Given** que la estimación del modal cuadra (diferencia $0) y el cajero confirma sin
   observación, pero el servidor calcula una diferencia distinta de cero porque el esperado
   cambió con el modal abierto, **When** el servidor responde `422` por observación faltante,
   **Then** el modal permanece abierto, conserva las cantidades tecleadas, muestra el mensaje del
   servidor y deja visible el campo de observación (que ya estaba disponible) para que el cajero
   la escriba y reintente.

---

### User Story 4 - El reporte de cierre muestra «Desglose del conteo» (Priority: P2)

El administrador abre el reporte de un turno cerrado (desde el histórico) y, además del resumen
financiero y el arqueo, ve la sección «Desglose del conteo» con una tabla de *Denominación*,
*Tipo*, *Cantidad* y *Subtotal*, cuya suma coincide con el efectivo contado. El cajero ve lo
mismo en el reporte que aparece inmediatamente después de cerrar su turno.

**Why this priority**: es el valor de auditoría que motiva la spec, pero depende de que el
desglose exista (User Stories 1 a 3). Sin él, el administrador solo ve un total.

**Independent Test**: se puede probar cerrando el turno de la User Story 1, abriendo su reporte y
comparando la tabla con las líneas ingresadas y la suma de subtotales con el efectivo contado.

**Acceptance Scenarios**:

1. **Given** el turno cerrado del escenario 1 de la User Story 1, **When** el administrador abre
   su reporte, **Then** ve la sección «Desglose del conteo» con exactamente estas tres filas de
   detalle:

   | Denominación | Tipo    | Cantidad | Subtotal  |
   |--------------|---------|----------|-----------|
   | $100.000     | Billete | 1        | $100.000  |
   | $10.000      | Billete | 1        | $10.000   |
   | $5.000       | Billete | 1        | $5.000    |

   seguidas de una fila de total de $115.000, y la suma de los subtotales coincide exactamente
   con el «Efectivo contado» ($115.000).
2. **Given** el turno con faltante del escenario 2 de la User Story 1, **When** el administrador
   abre su reporte, **Then** ve el desglose junto con la diferencia de -$5.000 resaltada como
   faltante.
3. **Given** un turno cerrado con desglose, **When** el cajero que lo cerró ve el reporte
   inmediatamente después del cierre, **Then** ve la misma tabla que vería el administrador
   después.
4. **Given** un turno cerrado con efectivo contado $0 (caja vacía) y por tanto sin líneas,
   **When** se abre su reporte, **Then** muestra el mensaje «No se registró desglose para este
   turno».
5. **Given** un turno abierto por la cajera «Ana» y cerrado por el usuario «Luis», **When** el
   administrador abre su reporte, **Then** la sección «Desglose del conteo» muestra
   «Contado por: Luis». (El encabezado «Cajero:» del reporte queda fuera de alcance de esta spec:
   hoy muestra al usuario que consulta el reporte, no a quien abrió el turno —hallazgo adicional
   de `research.md`—, y esta spec no lo modifica.)
6. **Given** que el usuario «Luis» fue desactivado o cambió de nombre después del cierre,
   **When** se abre el reporte, **Then** sigue mostrando el nombre que tenía al cerrar.

---

### User Story 5 - Los turnos cerrados antes de esta funcionalidad siguen siendo consultables (Priority: P2)

Los turnos que se cerraron antes de que existiera esta funcionalidad siguen mostrando su efectivo
contado y su diferencia tal como estaban. Si ya tenían líneas de desglose guardadas, ahora se ven
con su tipo; si no tenían ninguna, el bloque de desglose muestra un mensaje claro en lugar de
quedar vacío o dar error.

**Why this priority**: protege el histórico (Principio VII). Sin una regla explícita, el reporte
de un turno antiguo podría mostrar una tabla vacía engañosa o fallar.

**Independent Test**: se puede probar abriendo el reporte de un turno cerrado sin líneas
(mensaje) y el de uno cerrado con líneas previas (tabla con tipo) y comparando el efectivo
contado y la diferencia contra los valores previos a la migración.

**Acceptance Scenarios**:

1. **Given** un turno cerrado antes de la funcionalidad **sin** filas de desglose, **When** el
   administrador abre su reporte, **Then** ve el efectivo contado y la diferencia registrados y el
   bloque de desglose muestra «No se registró desglose para este turno».
2. **Given** un turno cerrado antes de la funcionalidad **con** filas de desglose guardadas,
   **When** el administrador abre su reporte, **Then** ve la tabla de desglose con el tipo
   completado a partir del catálogo por defecto, mostrando solo las líneas con cantidad mayor a
   cero.
3. **Given** cualquier turno cerrado antes de la funcionalidad, **When** se compara antes y
   después de la migración, **Then** su efectivo contado, su diferencia y su observación son
   idénticos.
4. **Given** un turno cerrado antes de la funcionalidad, **When** el administrador abre su
   reporte, **Then** la sección no muestra la línea «Contado por» (el dato no existe) y no
   aparece ningún error ni marcador vacío en su lugar.

---

### User Story 6 - El desglose es inmutable y el reporte impreso lo incluye (Priority: P2)

Una vez cerrado el turno, nadie puede modificar, sobrescribir ni eliminar el desglose, ni
cerrando de nuevo el turno. Y cuando el usuario imprime o guarda como PDF el reporte de cierre,
la tabla del desglose aparece en el documento.

**Why this priority**: la inmutabilidad es lo que hace auditable el desglose, y el documento
impreso es el entregable que circula fuera del sistema (gestoría, archivo físico).

**Independent Test**: se puede probar reenviando el cierre de un turno ya cerrado y verificando
`409` con el desglose intacto; y usando «Imprimir / Exportar reporte» sobre un turno con
desglose, revisando la vista previa de impresión.

**Acceptance Scenarios**:

1. **Given** un turno ya cerrado con su desglose guardado, **When** se envía una nueva petición
   de cierre para el mismo turno, **Then** el sistema responde `409` y el desglose, el efectivo
   contado y la diferencia originales no sufren ninguna modificación.
2. **Given** un turno cerrado, **When** se revisa cualquier acción disponible en el sistema,
   **Then** ninguna permite editar, reemplazar ni eliminar las líneas del desglose.
3. **Given** un turno cerrado que contiene su desglose, **When** el usuario selecciona
   «Imprimir / Exportar reporte», **Then** el documento generado (impresión o PDF del navegador)
   incluye la tabla estructurada con el desglose por denominación.
4. **Given** un turno cerrado sin desglose, **When** el usuario imprime el reporte, **Then** el
   documento incluye el mensaje «No se registró desglose para este turno» en lugar de la tabla.
5. **Given** dos solicitudes de cierre casi simultáneas para el mismo turno (por ejemplo, un
   doble clic), **When** el servidor las procesa, **Then** una cierra el turno y la otra recibe
   `409`, sin líneas duplicadas ni error interno.

---

### Edge Cases

- **Caja vacía.** La lista vacía (o con todas las cantidades en `0`) es un cierre válido con
  efectivo contado $0: no guarda líneas, la diferencia es el negativo del esperado y exige
  observación si el esperado es mayor a cero. El reporte de ese turno muestra el mensaje de
  «No se registró desglose para este turno», porque es literalmente cierto. Este cierre solo es
  posible por API: el modal de arqueo conserva su bloqueo con todas las cantidades en cero
  (FR-025), por lo que un turno con efectivo esperado $0 no se puede cerrar desde la pantalla
  (limitación aceptada).
- **Cantidades enormes.** Una cantidad que haría que el efectivo contado exceda el monto máximo
  que el sistema puede representar se rechaza con `422`, no con un error interno.
- **Misma denominación con valor equivalente.** `10000` y `10000.00` son la misma denominación
  y, si llegan ambas, cuentan como duplicada.
- **Una denominación repetida con cantidad `0` en una de las dos líneas.** Se rechaza como
  duplicada; la regla no depende de la cantidad.
- **Cierre de un turno ya cerrado con contenido inválido.** No se define qué respuesta tiene
  precedencia entre `409` y `422`; lo único exigido es que el turno y su desglose queden intactos.
- **Cambio futuro del catálogo.** Un turno cerrado conserva el valor y el tipo que tenían sus
  líneas al cierre aunque el catálogo cambie después (por eso el snapshot no depende del
  catálogo).
- **Tenant sin catálogo.** No debe ocurrir (el sembrado cubre a tenants existentes y nuevos); si
  ocurriera, en el servidor cualquier línea se rechazaría como denominación inválida y la caja
  vacía seguiría siendo cerrable por API; en la pantalla, en cambio, el arqueo no permite cerrar
  mientras el catálogo llegue vacío (FR-013).
- **Catálogo no disponible al abrir el arqueo.** Una falla de red o del servidor al consultar el
  catálogo no se trata como caja vacía: el cierre queda bloqueado con mensaje de error y
  «Reintentar» (FR-013), de modo que un fallo transitorio nunca registra un efectivo contado de
  $0.
- **Migración con denominaciones desconocidas.** Si existen filas históricas con un valor que no
  está en el catálogo por defecto, la migración no las descarta en silencio: se detectan y se
  resuelven con el negocio antes de migrar (ver Assumptions).
- **Estimado vs. oficial.** Si el total estimado de la pantalla difiere del oficial del servidor,
  prevalece el del servidor y el reporte solo muestra el oficial. La causa típica es que el
  efectivo esperado cambió con el modal abierto (una venta en efectivo o un movimiento desde otro
  terminal): la pantalla no lo recarga automáticamente, y si la diferencia oficial exige una
  observación que la estimación no anticipó, el servidor responde `422` y el modal, con el campo
  de observación siempre visible (FR-025), deja al cajero escribirla y reintentar.
- **Pedidos activos sin cobrar.** El bloqueo de cierre de la spec 119 sigue aplicando antes de
  contar nada; esta spec no lo modifica.

## Requirements *(mandatory)*

### Functional Requirements

**Contrato del cierre (cálculo autoritativo en el servidor)**

- **FR-001**: El cierre de turno MUST recibir el conteo físico únicamente como una lista de
  pares *denominación* y *cantidad* (más la observación, como hoy). El servidor MUST calcular el
  subtotal de cada línea (`denominación × cantidad`), el efectivo contado (suma de subtotales) y
  la diferencia (`efectivo contado − efectivo esperado`) (`RN-01`, `RN-02`).
- **FR-002**: El cierre MUST rechazar con `422` cualquier petición que traiga valores monetarios
  calculados por el cliente (efectivo contado, total, diferencia o subtotal), dejando el turno
  abierto y sin persistir nada (`RN-02`, decisión D-1). El mensaje del `422` MUST estar en
  español e indicar que la aplicación está desactualizada y debe recargarse; el servidor no
  tolera temporalmente el campo (sin ventana de compatibilidad con la versión anterior).
- **FR-003**: Una lista vacía, o cuyas líneas tengan todas cantidad `0`, MUST interpretarse como
  efectivo contado $0 (caja vacía): no persiste líneas y calcula la diferencia como el negativo
  del esperado (decisión D-2). El sistema NO MUST permitir ya un cierre «sin conteo» que deje el
  efectivo contado vacío. Este camino es del contrato de la API: la pantalla de arqueo no lo
  ofrece (FR-025).
- **FR-004**: El servidor MUST rechazar con `422` toda denominación que no esté en el catálogo
  del tenant, indicando cuál es (`RN-03`).
- **FR-005**: El servidor MUST rechazar con `422` toda cantidad negativa o no entera (`RN-03`).
- **FR-006**: El servidor MUST rechazar con `422` una petición que traiga la misma denominación
  más de una vez, indicando cuál se repite.
- **FR-007**: Ante cualquier rechazo, el cierre MUST ser atómico: el turno permanece abierto y
  no se persiste ningún registro (ni líneas, ni efectivo contado, ni observación).
- **FR-008**: Se MUST conservar sin cambios la regla de que una diferencia distinta de cero exige
  una observación no vacía (`RN-CASH-10`) y el bloqueo de cierre con pedidos activos sin cobrar
  (spec 119).

**Catálogo de denominaciones por tenant**

- **FR-009**: Cada tenant MUST contar con un catálogo de denominaciones permitidas, donde cada
  entrada tiene un valor y un tipo (`billete` o `moneda`). El catálogo por defecto es el de pesos
  colombianos: billetes de $100.000, $50.000, $20.000, $10.000, $5.000 y $2.000; monedas de
  $1.000, $500, $200, $100 y $50 (`RN-03`).
- **FR-010**: El valor de una denominación MUST identificarla de forma única dentro del catálogo
  de un tenant; el cliente no envía el tipo, el servidor lo toma del catálogo.
- **FR-011**: El sistema MUST exponer el catálogo en modo lectura a los usuarios que operan la
  caja, ordenado de mayor a menor valor.
- **FR-012**: El catálogo por defecto MUST estar disponible para todos los tenants existentes y
  para los que se creen después, sin configuración manual. La administración del catálogo
  (crear, editar, activar o desactivar) queda fuera de esta spec.
- **FR-013**: El arqueo MUST construir sus filas a partir del catálogo del tenant y dejar de
  depender de una lista fija en el frontend. Si el catálogo no puede cargarse o llega vacío, el
  arqueo MUST impedir la confirmación del cierre, informar el error con una acción «Reintentar» y
  no ofrecer ninguna lista de respaldo ni cierre como caja vacía hasta que el catálogo cargue.

**Persistencia e inmutabilidad**

- **FR-014**: Por cada línea con cantidad mayor a cero, el sistema MUST persistir un snapshot
  con el valor nominal, el tipo y la cantidad, sin ninguna dependencia del catálogo, de modo que
  cambios posteriores del catálogo no alteren turnos cerrados (`RN-04`).
- **FR-015**: El sistema MUST persistir únicamente las líneas con cantidad mayor a cero
  (`RN-05`, decisión D-3).
- **FR-016**: El cierre del turno, el efectivo contado, la diferencia, la observación, el
  desglose y el usuario que cierra (FR-029) MUST confirmarse como una sola operación: o quedan
  todos guardados o ninguno.
- **FR-017**: Una vez cerrado el turno, el desglose y el usuario que cierra MUST ser inmutables:
  ninguna función del sistema puede editarlos, sobrescribirlos ni eliminarlos (`RN-06`).
- **FR-018**: Un intento de cerrar un turno ya cerrado MUST responder `409` sin alterar el
  desglose, el efectivo contado ni la diferencia originales (`RN-06`, `RN-CASH-11`).
- **FR-019**: Ante solicitudes de cierre simultáneas para el mismo turno, exactamente una MUST
  cerrarlo y las demás MUST recibir `409`, sin líneas duplicadas ni error interno (relacionado
  con A-17, ya registrada en la spec 006).
- **FR-029**: Al cerrar un turno con éxito, el sistema MUST registrar el usuario autenticado que
  confirma el conteo (identificador y nombre como snapshot, igual que el usuario de apertura). El
  dato lo toma el servidor de la sesión; el cliente no lo envía. Puede ser distinto del usuario
  que abrió el turno. Un rechazo (`422`, `409`) no registra nada.

**Reporte de cierre, impresión y exportación**

- **FR-020**: El reporte de cierre MUST incluir la sección «Desglose del conteo» con una tabla de
  *Denominación*, *Tipo*, *Cantidad* y *Subtotal*, ordenada de mayor a menor denominación,
  mostrando solo las líneas persistidas (`RN-07`). La sección MUST mostrar además la línea
  «Contado por» con el nombre del usuario que cerró el turno (FR-029); en los turnos cerrados
  antes de esta funcionalidad, que no lo tienen, esa línea se omite sin mensaje de error.
- **FR-021**: La suma de los subtotales mostrados MUST coincidir exactamente con el «Efectivo
  contado» del reporte; la tabla MUST cerrar con una fila de total que lo evidencie.
- **FR-022**: Cuando un turno cerrado no tenga líneas de desglose, el bloque MUST mostrar
  exactamente el mensaje «No se registró desglose para este turno», y el reporte MUST seguir
  mostrando el efectivo contado y la diferencia registrados (`RN-07`).
- **FR-023**: El desglose MUST mostrarse tanto en el reporte que ve el cajero al cerrar su turno
  como en el que consulta el administrador desde el histórico; el resaltado del faltante o
  sobrante de la diferencia se conserva.
- **FR-024**: La impresión del reporte («Imprimir / Exportar reporte», incluida la opción de
  guardar como PDF del navegador) MUST incluir la tabla del desglose, o el mensaje de
  FR-022 cuando no exista desglose (decisión de alcance: no se agrega descarga de archivo desde
  el servidor).

**Arqueo en pantalla**

- **FR-025**: El modal de arqueo MUST conservar el total y la diferencia «en vivo» únicamente
  como vista previa, rotulada como estimado; al confirmar MUST enviar solo denominación y
  cantidad de las líneas con cantidad mayor a cero, y tras la respuesta MUST mostrar los valores
  oficiales del servidor (`RN-01`). El modal MUST mantener deshabilitada la confirmación del
  cierre mientras todas las cantidades estén en cero (comportamiento actual, que se conserva).
  El campo de observación MUST estar siempre visible (opcional mientras la estimación cuadre,
  obligatorio cuando no) para que, si el servidor calcula una diferencia distinta de cero que la
  estimación no anticipó, el cajero pueda escribirla sin cerrar el modal.
- **FR-026**: Ante un rechazo `422` por una denominación inválida, el modal MUST permanecer
  abierto, indicar cuál denominación fue rechazada y permitir corregir y reintentar.

**Migración de datos existentes**

- **FR-027**: La migración MUST completar el tipo de las filas de desglose ya guardadas
  deduciéndolo del catálogo por defecto y MUST descartar las filas con cantidad `0` (decisiones
  D-3 y D-4); no MUST alterar el efectivo contado, la diferencia ni la observación de ningún
  turno.
- **FR-028**: Antes de migrar, el equipo MUST verificar si existen filas con un valor fuera del
  catálogo por defecto; si existieran, MUST resolverse con el negocio y no descartarse en
  silencio.

### Key Entities *(include if feature involves data)*

- **Denominación del catálogo**: entrada del catálogo de un tenant. Atributos: valor nominal y
  tipo (billete o moneda). El valor es único dentro del tenant. Solo se lee en esta spec.
- **Línea de desglose del conteo** *(snapshot)*: pertenece a un turno cerrado. Atributos: valor
  nominal, tipo y cantidad, copiados al momento del cierre; el subtotal es `valor × cantidad`.
  No referencia al catálogo; solo existe si la cantidad es mayor a cero; no se modifica después.
- **Turno de caja** *(existente)*: conserva efectivo contado, diferencia y observación; ahora el
  efectivo contado siempre proviene de las líneas de desglose calculadas por el servidor. Gana el
  usuario que cerró el turno (identificador y nombre como snapshot, ambos opcionales: vacíos en
  turnos abiertos y en turnos históricos).
- **Reporte de cierre** *(existente)*: gana la sección «Desglose del conteo» con la tabla o el
  mensaje de turno sin desglose, y la línea «Contado por» cuando el dato existe.

### Compatibilidad con datos existentes, migración y reversión (Principio VIII)

- **Campos nuevos**: el tipo de cada línea de desglose (obligatorio en filas nuevas), el
  catálogo de denominaciones por tenant, sembrado con los once valores COP, y en el turno el
  usuario que lo cerró (identificador y nombre, ambos opcionales y sin valor por defecto).
- **Datos existentes**: las filas con cantidad mayor a cero conservan valor y cantidad y reciben
  su tipo deducido del catálogo por defecto; las filas con cantidad `0` se descartan por no
  aportar información; ningún monto de ningún turno cambia (FR-027, SC-004). Los turnos ya
  cerrados quedan con el usuario que cerró vacío: no se infiere ni se rellena con el de apertura,
  porque no hay evidencia de quién los cerró.
- **Estrategia de migración**: un único paso reversible en el esquema de cada tenant, precedido
  de la verificación de FR-028 y de un respaldo de la tabla de desglose.
- **Reversión**: se puede volver al esquema anterior sin perder valor ni cantidad de las líneas
  conservadas; las filas con cantidad `0` descartadas se restauran solo desde el respaldo, y la
  pérdida es aceptada porque no contienen información. Al revertir también se pierde el usuario
  que cerró los turnos cerrados después de esta funcionalidad (dato nuevo sin equivalente en el
  esquema anterior); esa pérdida es aceptada.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: En el 100 % de los cierres con desglose válido, la suma de los subtotales
  guardados coincide exactamente con el efectivo contado del turno, y se guardan exactamente
  tantas líneas como denominaciones con cantidad mayor a cero (verificable con los escenarios 1
  y 2 de la User Story 1).
- **SC-002**: El 100 % de las peticiones de cierre con una denominación fuera del catálogo, una
  cantidad negativa o decimal, una denominación repetida o un valor monetario enviado por el
  cliente se rechazan, dejan el turno abierto y no guardan ninguna línea.
- **SC-003**: Un administrador puede responder «cuántos billetes de una denominación entregó el
  cajero en un turno» en menos de 30 segundos desde el histórico, sin calcular nada a mano.
- **SC-004**: El 100 % de los turnos cerrados antes de esta funcionalidad se siguen abriendo sin
  error; los que tenían líneas las muestran con su tipo, los demás muestran el mensaje, y la
  comparación antes/después de la migración arroja 0 diferencias en efectivo contado,
  diferencia y observación.
- **SC-005**: En el 100 % de los turnos cerrados, la vista previa de impresión del reporte
  incluye la tabla del desglose (o el mensaje de turno sin desglose), sin filas cortadas entre
  páginas.
- **SC-006**: Tras N reintentos de cierre sobre un turno ya cerrado, incluidos reintentos
  simultáneos, el desglose guardado es idéntico al original y no se genera ninguna línea nueva.
- **SC-007**: El cajero completa el arqueo y el cierre en el mismo número de pasos que hoy; la
  vista previa estimada y el valor oficial coinciden en el 100 % de los cierres con datos
  válidos en los que el efectivo esperado no cambia entre la apertura del modal y la
  confirmación. Cuando sí cambia, prevalece el valor del servidor y el cajero puede completar el
  cierre sin salir del modal (User Story 3, escenario 8).
- **SC-008**: En el 100 % de los turnos cerrados después de esta funcionalidad, el reporte
  identifica por nombre al usuario que confirmó el conteo, incluso cuando es distinto del que
  abrió el turno; en el 100 % de los turnos históricos la línea se omite sin errores.

## Assumptions

- Esta spec **no** agrega: administración del catálogo (crear, editar, activar o desactivar
  denominaciones), monedas distintas de COP, descarga de archivo (PDF o Excel) generado por el
  servidor, desglose en arqueos parciales a mitad de turno, la vista de ajustes de la spec 006
  ni desglose para métodos de pago distintos de efectivo.
- El catálogo es de solo lectura y por tenant; como no existe una noción de moneda en el tenant,
  todos reciben COP por defecto. Una futura spec podrá agregar moneda y administración.
- Cualquier usuario autenticado que hoy puede cerrar el turno puede consultar el catálogo; el
  histórico de cierres sigue siendo solo para administradores, como hoy, y el cajero ve el
  desglose en el reporte posterior a su propio cierre.
- El valor de cada denominación es único en el catálogo, por lo que el cliente solo necesita
  enviar valor y cantidad. Un negocio que quisiera manejar un billete y una moneda del mismo
  valor requeriría un cambio futuro del contrato.
- El tipo de las filas históricas se deduce sin ambigüedad del catálogo COP por defecto, porque
  ningún valor del catálogo es a la vez billete y moneda.
- El frontend histórico solo permitía las once denominaciones fijas; por eso se espera que la
  verificación de FR-028 no encuentre filas fuera del catálogo. Si las encuentra, la migración
  se detiene hasta resolverlas con el negocio.
- La fila de total de la tabla (FR-021) y la fila de «caja vacía» con el mensaje de FR-022 son
  decisiones de presentación tomadas por esta spec para que el desglose sea verificable a simple
  vista.
- **Impacto en pruebas existentes (Principio III).** El contrato estricto de D-1 y D-2 afecta
  pruebas que hoy cierran turnos sin conteo: 27 usos de `ShiftClose()` en las pruebas de
  caracterización de caja (`test_cash_close_active_orders.py`, `test_cash_report_query_budget.py`,
  `test_cash_report_batch_identity.py`, `test_cash_shift_sales_report.py`), el script
  `e2e_qr_flow.py` (que cierra con `counted_amount`) y las pruebas del frontend de caja
  (`cash.service.spec.ts`, `cash-session.store.spec.ts`, `cash-arqueo-modal.component.spec.ts`,
  `cash-report.component.spec.ts`). Esta spec **autoriza** adaptarlas al nuevo contrato (por
  ejemplo, cerrando con una observación o con un desglose válido) con el cambio mínimo
  indispensable: la intención de cada prueba (bloqueo por pedidos activos, snapshot del reporte
  de ventas, presupuesto de consultas) no cambia, y cada modificación cita la decisión D-1/D-2
  en el mismo commit.
- **Despliegue coordinado.** `pos-backend` y `pos-heladeria` se despliegan de forma coordinada;
  no hay ventana de compatibilidad en el servidor con la versión anterior del frontend (que envía
  el total contado). Un cajero con la pantalla anterior abierta durante el despliegue recibe el
  `422` de FR-002 y debe recargar; el conteo tecleado en esa pantalla se pierde (costo aceptado).
  El script `e2e_qr_flow.py` se actualiza junto con el contrato (ver Impacto en pruebas).
- Los cambios de comportamiento D-1 a D-6 deben registrarse en
  `specs/000-reconocimiento/registro-de-anomalias.md` antes de implementar (Principio II); la
  implementación en `pos-backend` y `pos-heladeria` sigue el Principio XIV (rama nueva
  `<tipo>/121-<nombre>` antes de tocar código).
