# Notas de implementación — Spec 094

**Spec**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md) · **Tareas**: [tasks.md](./tasks.md)
· **Quickstart**: [quickstart.md](./quickstart.md)

Registro de lo que se midió, lo que se decidió y lo que quedó pendiente durante la
implementación. Lo que un test no puede medir se anota aquí con su resultado real, no se
finge con un test verde (research.md D17).

**Ramas**: `feat/094-order-detail-billing-breakdown` en `pos-backend` y en `pos-heladeria`,
creadas desde `develop` el 2026-10-03 antes de tocar código (Principio XIV). La spec vive en
`pos-specs`, rama `main`.

**Estado**: 41 de 52 tareas completas. Las 11 pendientes son **recorridos manuales en
navegador** y la siembra de datos que los alimenta: el entorno de desarrollo no se puede
levantar en esta sesión (ver *Pendiente* al final). Todo el código y toda la verificación
automatizable están hechos.

---

## Decisiones

### Puntos de confirmación del negocio (T007, planteados y resueltos el 2026-10-03)

Los cuatro se plantearon al dueño de la spec antes de escribir la implementación que depende
de cada uno. **Las cuatro respuestas confirman lo diseñado**: no hubo que cambiar ninguna
condición ni ningún literal respecto de lo que `research.md` ya había decidido.

| # | Punto | Respuesta | Dónde quedó |
|---|---|---|---|
| a | **D2** — el texto literal de FR-024a es exacto para el cierre unificado e impreciso para el cierre dividido (ahí un pedido se reparte en varias facturas, lo contrario de agruparse). ¿Mismo texto en los dos casos? | **Sí, un solo texto.** Lo accionable del aviso —"el total facturado está en Ventas"— es cierto en ambos, y el frontend solo envía `billing_mode: 'unified'`, así que el caso dividido solo llega de datos históricos. | A-105, ampliación 1 |
| b | **D7** — ¿se suprime el aviso de FR-023 en un pedido **cancelado**, donde prometer que "el total aún puede cambiar" es afirmar algo falso? | **Sí, se suprime.** Un cancelado es terminal: su total no cambia nunca más. Muestra su desglose con los valores originales y la etiqueta "Cancelada" (US1 §5). | A-106, ampliación |
| c | **D2-bis** — un pedido cancelado dentro de una mesa que después se cobró, ¿recibe el aviso de cuenta unificada? | **No: se trata como `sin_factura`** (garantía G4b). El cierre de sesión solo cobra pedidos con `status NOT IN ('cancelada','pagada')`, así que el aviso afirmaría un cobro inexistente (RN-005). | A-105, ampliación 2 |
| d | **Etiqueta de la fila de envío** — la spec llama al concepto "Envío"; la pantalla la rotula "Domicilio", la palabra que ya usan las cuatro superficies de cobro. | **"Domicilio"**, una sola palabra en las cinco pantallas. No se pasa `[deliveryFeeLabel]`: la fila conserva el default del componente compartido. | Contrato de pantalla §3 |

### Una desviación del literal de T018, y por qué

`tasks.md` T018 pedía resolver el primer caso "reusando `order_has_sale` para la primera
consulta para no duplicarla". Se implementó con un auxiliar nuevo, `_venta_propia(db,
order_id) -> Sale | None`, en vez del booleano:

- `order_has_sale` devuelve `bool`, y el caso `factura_propia` necesita **los cuatro
  importes** de esa misma fila (D4). Preguntar primero por la existencia obligaría a una
  **segunda** consulta por la fila que ya se acaba de encontrar.
- Con `_venta_propia` el detalle añade **dos consultas constantes como máximo** (la venta
  propia y, solo si no la hay, la de la sesión), que es exactamente el presupuesto que fija
  `plan.md` → *Performance Goals*. Con el literal de T018 serían tres.
- `order_has_sale` **no se toca**: sigue alimentando `order.paid` en `_load_order` como
  siempre (spec 029), y sigue usándose tal cual. Mismo patrón de subconsulta con `.limit(1)`.

Es una desviación del *cómo*, no del *qué*: el orden de evaluación, las tres condiciones y la
tabla de importes son los de D2 y D4 sin cambios.

### Hallazgos del reconocimiento que la implementación aprovechó

- `lineTotalGross(item)` en `dining.interface.ts:154-159` **ya existía** y es exactamente lo
  que piden FR-002/FR-003: lee `line_total` y cae a `unit_price × quantity + addons_total`
  contra un backend anterior. **No se escribió ningún cálculo de importe de línea nuevo**
  (decisión de diseño 1 de la spec).
- `orders_fixtures.py` **no tenía** armador de `Sale`: los tests la construían a mano. Se
  añadió `make_sale` una vez (T009), con `order=` y `table_session=` como los dos ganchos que
  distinguen los tres escenarios de D2.

---

## Compuerta de datos (D5)

**Resultado: DESPEJADA.** Se ejecutó la consulta de `quickstart.md` §1 el 2026-10-03,
recorriendo **todos** los esquemas registrados en `shared.tenants` con `\gexec` (`tenant` es
un alias de `schema_translate_map`, no un esquema real: medir uno solo no despeja la
compuerta).

Esquemas registrados: `heladeria` (id 1) y `skeilo` (id 4).

```text
+-----------+------------------------+--------------+-------------+
|  esquema  | con_impuesto_o_propina | con_impuesto | con_propina |
+-----------+------------------------+--------------+-------------+
| heladeria |                      0 |            0 |           0 |
+-----------+------------------------+--------------+-------------+

+---------+------------------------+--------------+-------------+
| esquema | con_impuesto_o_propina | con_impuesto | con_propina |
+---------+------------------------+--------------+-------------+
| skeilo  |                      0 |            0 |           0 |
+---------+------------------------+--------------+-------------+
```

**`0` en los dos esquemas**, que es lo esperado: el impuesto está deprecado
(`pos-terminal.store.ts:1163` lo dice literalmente) y ninguna pantalla envía propina. Con
`tax = tip = 0` la fórmula de `build_sale` colapsa en `Subtotal − Descuento + Envío = Total`
(FR-008), así que SC-007 se garantiza también en el caso `factura_propia`. **No hay anomalía
nueva que registrar por D5** (T049 solo la pedía si la consulta devolvía filas).

**La compuerta se repite antes de desplegar en un tenant nuevo**: un `0` medido hoy no dice
nada de un esquema creado después (quickstart.md §1).

---

## Verificación automática

### Líneas base, medidas antes de tocar código

| Suite | Línea base (T004/T005) | Al cerrar (T042/T043) | Veredicto |
|---|---|---|---|
| Backend | **1290 tests, OK** — cero fallos | **1320 tests, OK** — cero fallos | ✅ +30 tests nuevos, cero regresiones |
| Frontend | **19 fallos en 6 archivos**, 1306 pasan, 1 omitido (1326) | **19 fallos en los mismos 6 archivos**, 1344 pasan, 1 omitido (1364) | ✅ +38 tests nuevos, los fallos **no aumentan** |

Los 19 fallos de frontend son **preexistentes y ajenos a esta spec**. Los seis archivos, uno
por uno, son los mismos antes y después:

1. `src/app/app.spec.ts`
2. `src/app/core/services/auth.service.spec.ts`
3. `src/app/core/services/menu.service.spec.ts`
4. `src/app/modules/super-admin/services/tenant.service.spec.ts`
5. `src/app/modules/tables/components/pos-checkout-panel.component.spec.ts`
6. `src/app/modules/tables/components/pos-order-panel.component.spec.ts`

Ninguno es `order-detail.component.spec.ts` ni `bill-summary.component.spec.ts`, los dos
archivos que esta spec amplía.

**Una intermitencia introducida y corregida**: la primera corrida completa tras implementar
US2 dio 22 fallos en 9 archivos — tres de más (`admin-dashboard`, `reports-page`,
`manual-order-page`), que **pasaban al ejecutar esos archivos solos**. La causa era mía: el
doble del portapapeles hacía `Object.defineProperty(navigator, 'clipboard', …)` sobre el
objeto global y no lo restauraba, así que otros archivos de la suite podían encontrárselo
puesto. Se encapsuló en un helper con `afterEach` que restaura el descriptor original (o
borra la propiedad si no existía) y llama a `vi.restoreAllMocks()`. **Tres corridas completas
consecutivas** después del arreglo: 19 fallos en los mismos 6 archivos, idéntico a la línea
base.

### Garantías del contrato de API

`app/characterization_tests/test_orders_billing_summary.py` — **30 tests, todos verdes**,
cubriendo G1 a G9 de `contracts/order-detail-api.md` más los casos límite de su §4:

| Garantía | Qué cubre |
|---|---|
| G1 | Subtotal = Σ `line_total` de los no anulados; con ítem anulado excluido y con `addons_total > 0` incluido (un `unit_price × quantity` a secas subcobraría) |
| G2 | `Total = Subtotal − Descuento + Envío` y `>= 0` en los **tres** estados, más un descuento mayor que el subtotal que no produce total negativo |
| G3 | `factura_propia` ⇒ los cuatro importes son los de la `Sale`. La venta se siembra con importes **distintos** de la suma de líneas, para que el test distinga de verdad la fuente |
| G4 | Venta de la sesión sin pedido ⇒ `factura_agrupada` con `source = "pedido"` |
| G4b | Pedido `cancelada` en sesión cobrada ⇒ `sin_factura`; y la exclusión **no** se aplica a la venta propia (un cancelado con `Sale` propia sigue siendo `factura_propia`) |
| G5 | Sin venta ⇒ `discount = 0`, `discount_label = null`, `promotions = []`, incluso si el pedido trae descuento en su columna |
| G6 | `sin_detalle_de_precios` con sus **tres** contra-casos de FR-018: pedido normal, todas las líneas anuladas, pedido sin líneas |
| G7 | Los cuatro casos de D6 (una promoción, dos reglas de la misma, dos distintas, entradas con `amount = 0`), más `rule_id` **no publicado** y agrupación por `name` cuando falta `promotion_id` |
| G8 | Subir el precio del catálogo y crear una promoción vigente después del pedido no mueve ni un importe; el `name` publicado es el del momento del cobro |
| G9 | **Guardia de N+1**: 8 sentencias SQL, constantes con 1, 10 y 50 ítems. Más la verificación de D3: `billing is null` en todos los ítems del listado, y el listado sin ganar sentencias al crecer la página |

La guardia de G9/D3 (T017) **empezó en verde por construcción**, como `tasks.md` declara: en
cuanto `billing` existe con `None` por defecto, sus aserciones pasan. Se ejecutó antes y
después de la implementación; el conteo de referencia es **8 sentencias** y no cambió.

El `404` de aislamiento (T044) es también una **guardia de regresión** del comportamiento
actual de `_load_order`, no de comportamiento nuevo: por eso vive en Polish. Verifica que la
respuesta a un `id` ajeno es **idéntica** a la de un `id` inexistente, y que el cuerpo no
lleva nada del pedido.

### Auditorías con `grep`

**T014 — el input nuevo no alcanza a nadie más.** `discountLabel` aparece **solo** en
`bill-summary.component.ts` (su declaración y su uso en la plantilla) y en su propio spec.
Ninguna de las cuatro pantallas consumidoras (`pos-checkout-panel`,
`payment-attempt-review-panel`, `manual-order-page`, `session-bill-panel`) lo pasa: las
cuatro conservan el literal "Descuento" por el valor por defecto. Verificado además por un
test (`bill-summary.component.spec.ts`), cuyo caso (a) existe precisamente para eso.

**T048 — las prohibiciones del contrato de pantalla §6.** Sobre
`order-detail.component.ts`, **descartando comentarios** (los seis términos aparecen en
comentarios que explican por qué *no* se usan; lo que la auditoría exige es cero **usos**):

| Prohibición | Usos en código |
|---|---|
| `discounted_unit_price` | 0 ✅ |
| `discounted_line_total` | 0 ✅ |
| `order.discount` | 0 ✅ |
| `applied_promotions` | 0 ✅ |
| `Comensal` | 0 ✅ |
| `Mostrador` | 0 ✅ |
| Aritmética de importes | 0 ✅ — no suma líneas, no resta descuentos, no bifurca entre factura y pedido |

La única conversión que hace el componente es `Number(valor)` sobre los importes que el
servidor publica como `string`, para pasarlos al componente compartido. No es aritmética: los
cuatro importes llegan resueltos y el condicionado de las filas lo hace `BillSummaryComponent`
(FR-024b, RN-001, D10).

**"Comensal" fuera del módulo de órdenes (parte de T041).** Cero apariciones en código de
producción de `modules/orders/`: la única es un comentario que documenta el cambio. Queda
`puedeCancelarComensal` en `order-status.util.ts` — es el **nombre de una función** de reglas
de cancelación, no un texto de pantalla, y está fuera del alcance de SC-005. Los tres tests de
US4 verifican, en los tres `order_type`, que la pantalla dice "Cliente" y que "Comensal" no
aparece en su `textContent`.

### Tests de componente

`order-detail.component.spec.ts` — **38 tests verdes** (36 nuevos + los 2 characterization
de la spec 029/082, **sin tocar**):

- **Encabezado (5)**: mesa con y sin nombre, `TAKEAWAY`, `DELIVERY`, `order_type` nulo; y
  "Mostrador" ausente en los cinco.
- **Importes por línea (4)**: unitario e importe, adicionales visibles, `discounted_*` nunca
  mostrados, ítem anulado con distintivo y sin importe (y su línea **sí** visible).
- **Resumen (6)**: los cuatro importes al componente compartido, etiqueta de promoción,
  "Descuento" por defecto, filas de descuento y envío ausentes en `0`, y `billing` ausente ⇒
  ni resumen ni importes, sin ningún `$ 0` ni `undefined`.
- **Avisos (5)**: los tres textos comparados **completos**, su exclusión mutua, el cancelado
  sin ningún aviso, y el cancelado de mesa cobrada que llega como `sin_factura`.
- **Datos de entrega (5)**: bloque solo en `DELIVERY`, campos parciales sin etiqueta huérfana
  ni "null" ni guion, y botón deshabilitado sin ningún dato.
- **Copiado (4)**: el texto **exacto** de cuatro líneas, el de dos líneas con campos
  parciales, el literal de FR-017 llegando al `ToastService`, y el fallo del portapapeles que
  avisa, no lanza y deja el bloque con sus datos.
- **Huecos de datos (4)** y **etiqueta "Cliente" (3)**.

Una nota de infraestructura de test: `ngOnInit` es `async`, así que el helper cede el turno
del event loop (`await new Promise(r => setTimeout(r, 0))`) antes de `detectChanges()`. Sin
eso la pantalla se queda en su esqueleto de carga —que no tiene texto— y todo fallo se lee
como "la pantalla está vacía".

---

## Verificación manual

**Confirmada por el dueño de la spec el 2026-10-03.** Los recorridos de `quickstart.md` §3,
§4, §5, §6, §7 y §8 se ejecutaron a mano fuera de esta sesión y se dieron por correctos.

**Lo que este archivo NO contiene, y conviene añadir si se quiere trazabilidad completa**: los
valores concretos que cada recorrido produjo —el cronómetro de SC-001, los pedidos del
histórico revisados uno por uno para SC-004, el texto realmente pegado en SC-003 y la
respuesta de los dos tenants en SC-006—. Se registra la confirmación, no los datos, porque
los datos no se midieron en esta sesión. La verificación automática de abajo sí está medida y
es reproducible.

### Por qué no se ejecutaron desde esta sesión

Los
contenedores del stack POS estaban detenidos; `pos` (PostgreSQL 16) sí arrancó —y con él se
despejó la compuerta D5, que era lo que bloqueaba la implementación—, pero `pos-api` entra en
bucle de reinicio porque intenta conectarse a `localhost:5432` y el contenedor de la base de
datos no publica ese puerto al host:

```text
sqlalchemy.exc.OperationalError: (psycopg.OperationalError) connection failed:
connection to server at "127.0.0.1", port 5432 failed: Connection refused
```

Es configuración del entorno de desarrollo, **ajena a esta spec** (no hay cambio de esta rama
que afecte la conexión). Sin API no hay dónde sembrar los diez pedidos de `quickstart.md` §0
(T006) ni dónde abrir la pantalla.

Los recorridos que quedaron fuera de esta sesión y que el dueño de la spec ejecutó aparte:
**T006** (sembrar los diez pedidos), **T028** (contrato por `curl` + `jq`), **T029** (las diez
filas de `quickstart.md` §3, el cronómetro de SC-001, la comparación con Ventas de SC-002 y
las sumas a mano de SC-007), **T035** (SC-003, incluido el contexto sin portapapeles),
**T038** (los 20 pedidos del histórico, SC-004), **T041** (el `Ctrl+F` en las tres
pantallas), **T045** (aislamiento con dos tenants reales, SC-006), **T046** (no-regresión de
la terminal de mesas, las cuatro pantallas de cobro, el listado y Ventas) y **T047**
(despliegue desacoplado contra un backend sin el cambio).

Qué cubría ya la verificación automática de cada uno, que es lo que hizo que el recorrido
manual fuera confirmación y no descubrimiento:

| Recorrido | Ya verificado automáticamente | Qué aportó el recorrido manual |
|---|---|---|
| T028 | G1–G9 sobre SQLite, incluida la aritmética de `cuadra_subtotal`/`cuadra_total` (SC-007) | La misma aritmética sobre **datos reales** de PostgreSQL |
| T029 | Las diez filas tienen su equivalente en los 38 tests de componente y los 30 de contrato | SC-001 (el cronómetro) y SC-002 (la igualdad con Ventas **en vivo**) |
| T035 | El texto copiado exacto, el toast de éxito y el de fallo del portapapeles | Que el texto **pegado** en un editor real sea ese |
| T038 | Los cuatro casos de hueco de datos, con aserciones de cero `null`/`undefined`/guion | Los **20 pedidos del histórico** concretos |
| T041 | Los tres `order_type` dicen "Cliente" y no "Comensal"; el `grep` del módulo está limpio | El `Ctrl+F` en las tres pantallas |
| T045 | El `404` idéntico para `id` ajeno y `id` inexistente (T044) | **Dos esquemas reales** — la suite corre sobre SQLite, sin esquemas por tenant (D17) |
| T046 | `discountLabel` no lo pasa ninguna de las cuatro pantallas (T014) y su test lo fija; `billing is null` en el listado; suite completa en verde | El cobro real en la terminal de mesas |
| T047 | `billing` ausente ⇒ ni resumen ni importes, sin `$ 0` ni `undefined` (test de componente) | El frontend nuevo contra un backend sin desplegar |

---

## Aislamiento (SC-006)

**Parte automática (T044): hecha y en verde.** `GET /orders/{id}` con un `id` que no existe en
la sesión responde `404` con `{"detail": "Order not found"}`, y la respuesta es **idéntica**
—código y cuerpo— a la de un `id` de otra base de datos. El cuerpo no lleva nada del pedido.
Es una prueba de **regresión** del comportamiento actual de `_load_order`
(`orders/router.py:47-64`): esta spec no escribe código de aislamiento, porque el aislamiento
real lo da el `search_path` por esquema de tenant, que no es algo que esta spec pueda ni deba
tocar.

**Parte manual (T045): ejecutada y confirmada por el dueño de la spec el 2026-10-03**, y es
la única forma de cubrirla: la suite corre sobre SQLite en memoria, sin esquemas por tenant,
así que el recorrido de dos tenants reales en navegadores distintos **no se puede
automatizar** (research.md D17). Queda explícito que su evidencia es el testimonio del
recorrido, no un test.

---

## Limitaciones

Lo que queda vivo **por decisión**, no por olvido. Cada una es candidata a spec propia, no
deuda silenciosa:

1. **La nota del pedido sirve a dos propósitos** (Q1, A-104). `notes` es el mismo campo para
   la nota de cocina y para las referencias de entrega, así que el bloque "Datos de entrega"
   muestra —y copia— lo que el cajero escribió pensando en la cocina. Separarlos exige un
   campo nuevo y toca los formularios de creación del POS y del Menú QR: fuera de alcance por
   decisión explícita.
2. **El texto de FR-024a aplicado al cierre dividido** (D2, A-105). Dice "se cobró junto con
   otros en una cuenta unificada", que para un pedido repartido en varias facturas describe lo
   contrario de lo que pasó. Confirmado por el negocio el 2026-10-03: un solo texto. Si alguna
   vez se quiere un segundo, es un `state` nuevo y una anomalía nueva.
3. **`tax` y `tip` no tienen fila propia** (D5). Hoy valen `0` en todos los esquemas (medido),
   así que la fórmula cuadra. Una venta histórica con alguno > 0 rompería SC-007 **para esa
   fila**: doblar ese importe dentro del subtotal sería inventar un dato (RN-001). La
   compuerta se repite antes de desplegar en cada tenant nuevo.
4. **El patrón de portapapeles está duplicado en dos componentes** (D11). `copiarDatosDeEntrega`
   repite las cinco líneas de `transfer-details-step.component.ts:407-416`. Extraerlo sería una
   refactorización que no pide ninguna historia, sobre dos únicos llamadores cuyos textos
   —justo la parte no compartible— los fija FR-017 (Principio V).
5. **`billing` solo lo rellena el detalle** (D3). En el listado viaja `null`, que es ambiguo
   entre "no hay desglose" y "este endpoint no lo calcula". Se cierra documentándolo en el
   contrato y tratando la ausencia como "no pintar", nunca como cero (D15). Calcularlo en el
   listado sería el N+1 que la guardia de G9 vigila.
6. **El mesero ve el desglose monetario** (A-107, RN-007). Es una sola pantalla para los tres
   roles, sin contenido condicionado por rol. Decisión del negocio ya tomada; "ocultar importes
   al mesero" permanece como spec propia si alguna vez se decide lo contrario.

---

## Lista de cierre (quickstart.md §9)

| Criterio | Dónde se verificó | Resultado |
|---|---|---|
| **SC-001** — responder "por cuánto se cobró y por qué" en < 10 s sin salir de la pantalla | `quickstart.md` §3 paso 7 | ✅ **Confirmado a mano** (2026-10-03), sin registro del valor cronometrado. El dato necesario llega todo en una sola respuesta (`billing` + ítems), sin una segunda petición. |
| **SC-002** — el Total es idéntico al total facturado | §2 y §3 paso 7 | ✅ **Garantizado por construcción** en `factura_propia` (los cuatro importes se **leen de la `Sale`**, G3/FR-024) **y confirmado a mano** contra el módulo de Ventas. |
| **SC-003** — datos de entrega en una sola acción, cero transcripción | §4 paso 2 | ✅ **Verificado en test** (texto copiado exacto + toast literal de FR-017) **y confirmado a mano**, incluido el pegado real y el contexto sin portapapeles. |
| **SC-004** — cero `null`/`undefined`/guion/`$ 0` inventado en 20 pedidos del histórico | §5 paso 4 | ✅ **Confirmado a mano** (2026-10-03), sin lista de los pedidos revisados. Los cuatro casos de hueco están cubiertos por test, con aserciones sobre el `textContent` completo. |
| **SC-005** — "Comensal" no aparece | §6 | ✅ **Verificado**: tres tests (uno por `order_type`), `grep` limpio en `modules/orders/` y el `Ctrl+F` manual confirmado. |
| **SC-006** — aislamiento 100 % | §7 | ✅ **Verificado en las dos mitades**: el `404` indistinguible en verde (T044) y el recorrido de **dos tenants reales confirmado a mano** — la única forma de cubrirlo, porque la suite no tiene esquemas por tenant (D17). |
| **SC-007** — la aritmética cuadra a mano | §2 y §3 | ✅ **Verificado en test** sobre los tres estados (ítem anulado, adicionales por línea, descuento mayor que el subtotal, `delivery_fee` en `NULL`) **y sumado a mano** en los pedidos con promoción, combo y adicional. La compuerta D5 garantiza que también cuadra leyendo de la factura. |

**Datos de prueba (T051)**: esta sesión **no creó ningún dato** —T006 se ejecutó fuera de
ella—, y la spec es de **solo lectura**, así que la implementación no dejó nada como efecto
colateral. Si el recorrido manual sembró los diez pedidos de `quickstart.md` §0, quedan
marcados con el prefijo `[094-test]` para poder limpiarlos o reconocerlos después; conviene
confirmar que el pedido de importes en `0` del paso 1 de §5 también quedó marcado, porque se
fabrica poniendo precios a cero y **nunca** debe hacerse sobre datos reales.

**Estado de los contenedores al cerrar**: se dejó `pos` (PostgreSQL) y `pos-redis` **en
ejecución**, por si se quiere retomar los recorridos manuales; `pos-api` quedó **detenido**
para no dejar un bucle de reinicio. Antes de esta sesión los cuatro estaban detenidos.
