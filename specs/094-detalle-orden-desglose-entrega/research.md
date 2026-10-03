# Research — Fase 0: Desglose Económico y Datos de Entrega en el Detalle de Orden

**Spec**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md) · **Fecha**: 2026-10-03

Este documento resuelve las incógnitas técnicas del plan. La spec ya cerró sus ocho
preguntas de negocio (Q1–Q8, registradas como A-104 a A-107); aquí no se reabre ninguna.
Lo que se decide son los **mecanismos**: dónde vive cada cálculo, de qué columna sale cada
importe y qué se reusa del código existente.

Cada decisión cita el requisito que la obliga y los archivos verificados en el
reconocimiento de código de esta sesión.

---

## D1 — El desglose lo resuelve el servidor y viaja en la respuesta del pedido

**Decisión**: `GET /orders/{id}` gana un objeto anidado `billing` con el desglose ya
decidido (origen, estado de facturación, subtotal, descuento, envío, total y promociones).
La pantalla pinta lo que recibe; no elige entre factura y pedido, no suma y no resta.

**Razón**: lo exige FR-024b de forma literal ("Esa distinción MUST resolverse en el
servidor y viajar en la respuesta de consulta del pedido") y lo repite la decisión de
diseño 8 de la spec. Además es lo único compatible con RN-001: cualquier aritmética en el
navegador es un recálculo, y un recálculo en una pantalla de auditoría es una segunda
fuente de verdad.

**Alternativas consideradas**:

- *Bifurcar en el navegador* (`if (order.paid) … else …`): descartada por FR-024b y RN-001.
  Además el navegador no puede saber si la factura agrupa varios pedidos sin una consulta
  propia al módulo de Ventas.
- *Endpoint nuevo `GET /orders/{id}/billing`*: descartada. La pantalla ya hace una
  petición por el pedido; un segundo viaje añade un estado de carga parcial, duplica el
  manejo de 404 y no aporta nada — el desglose no se consume sin el pedido.
- *Leer el desglose desde el módulo de Ventas en el frontend* (`GET /sales?order_id=`):
  descartada. Expone el módulo de Ventas a una pantalla que no lo necesita y deja al
  navegador decidiendo la bifurcación que FR-024b prohíbe.

---

## D2 — Cómo se distinguen los tres casos de facturación

**Decisión**: una sola regla, evaluada en el servidor, en este orden:

| Orden de evaluación | Condición | `billing.state` |
|---|---|---|
| 1 | Existe una `Sale` con `customer_order_id = order.id` | `factura_propia` |
| 2 | No la hay, el pedido **no está `cancelada`**, tiene `table_session_id` y existe alguna `Sale` con ese mismo `table_session_id` | `factura_agrupada` |
| 3 | Ninguna de las tres anteriores | `sin_factura` |

**Razón**: es exactamente cómo los caminos de cobro escriben hoy la relación, verificado en
código:

- `app/api/v1/orders/checkout.py:504,712,1191,1371` — los cuatro caminos de cobro **por
  pedido** (mostrador, `checkout-and-send`, aprobación de pago QR, confirmación de efectivo)
  construyen la venta con `customer_order_id=order.id`. Caso 1.
- `app/api/v1/table_sessions/service.py:734` — el cierre unificado pone
  `customer_order_id=orders[0].id if len(orders) == 1 else None`. Es decir: una mesa con un
  solo pedido cae en el caso 1 (y su desglose se lee de la factura, que es lo que quiere
  Q2); con dos o más pedidos la venta **no cuelga de ninguno** y cae en el caso 2.
- `app/api/v1/table_sessions/service.py:832-847` — el cierre dividido (`split`) crea una
  venta por comensal, **ninguna** con `customer_order_id`. También cae en el caso 2, que es
  el tratamiento correcto: el total del pedido tampoco es el total de ninguna factura.
- `app/api/v1/table_sessions/service.py:180,314` — **por qué la regla 2 excluye los
  cancelados**: el cierre de sesión solo cobra los pedidos con
  `status NOT IN ('cancelada','pagada')` (`:180`) y solo a esos les pone `status = "pagada"`
  (`:314`). Un pedido cancelado antes del cierre **se queda en la sesión** con su
  `table_session_id` intacto y sin haberse cobrado nunca. Sin la exclusión, la regla 2 lo
  clasificaría `factura_agrupada` y la pantalla le mostraría el literal de FR-024a —"Este
  pedido **se cobró** junto con otros…"— afirmando un cobro que no existió, exactamente el
  tipo de promesa que RN-005 prohíbe. Un cancelado sin cobro cae entonces en `sin_factura`,
  donde D7 ya suprime el otro aviso: el resultado es el desglose con sus valores originales
  y la etiqueta "Cancelada", que es literalmente lo que pide US1 §5.
- La exclusión **no se aplica a la regla 1**: un pedido `cancelada` con `Sale` propia es
  posible en datos históricos (el camino que el hotfix #4 de la spec 029 cerró,
  `checkout.py:826`) y ahí la factura sí cubre ese pedido, así que FR-024 sigue mandando.

**Costo**: dos consultas `SELECT … LIMIT 1` adicionales en el detalle, la primera de las
cuales ya existe (`service.order_has_sale`, que alimenta `order.paid`). No hay índice que
crear: `sales.customer_order_id` y `sales.table_session_id` ya están indexados
(`app/models/sale.py:41,31`).

**Consecuencia registrada**: el texto literal de FR-024a ("Este pedido se cobró junto con
otros en una cuenta unificada…") es exacto para el cierre unificado de varios pedidos, y
**impreciso** para el cierre dividido, donde lo que ocurrió es lo contrario: un pedido
repartido en varias facturas. Se usa el mismo texto en los dos casos porque Q8 lo fijó así
y porque lo accionable del aviso —"el total facturado está en Ventas"— es cierto en ambos.
Queda anotado como punto a confirmar con el negocio en `tasks.md`; si el negocio quiere un
segundo texto, es una decisión nueva (anomalía nueva) y un `state` nuevo, no un rediseño.
Atenuante verificado: el frontend actual solo envía `billing_mode: 'unified'`
(`session-bill-panel.component.ts:291`), así que el caso dividido solo puede venir de datos
históricos o de un llamador directo de la API.

---

## D3 — `billing` solo lo rellena el detalle, no el listado

**Decisión**: `OrderResponse.billing` es opcional y lo asigna únicamente `_load_order`
(`GET /orders/{id}`). En `GET /orders` viaja como `null`.

**Razón**: el listado serializa hasta 100 pedidos por página y ya tiene una guardia de
trabajo acotado por petición en sus tests (`test_orders_pagination.py`, "atrapa un N+1 al
asignar `paid`/`staff_user_name` en bloque"). Calcular el estado de facturación por fila
sería justo el N+1 que esa guardia vigila. El listado tampoco lo necesita: esta spec
declara explícitamente que no lo toca.

**Alternativa considerada**: resolverlo en bloque en `_decorate_orders`, como ya se hace
con `paid_order_ids`. Descartada por Principio V: el listado no lo pide ninguna historia de
esta spec, y añadirlo cambia el contrato y el `ETag` de una pantalla fuera de alcance.

**Riesgo asumido y cómo se cierra**: un `null` ambiguo ("no hay desglose" vs "este endpoint
no lo calcula"). Se cierra en el contrato, documentando que `billing` solo lo rellena el
detalle, y en la pantalla, que trata la ausencia como "no pintar el resumen" (D15) — nunca
como ceros.

---

## D4 — De qué columna sale cada importe, caso por caso

**Decisión**:

| Caso | `subtotal` | `discount` | `delivery_fee` | `total` | `promotions` |
|---|---|---|---|---|---|
| `factura_propia` | `sales.subtotal` | `sales.discount` | `sales.delivery_fee` | `sales.total` | `sales.applied_promotions` |
| `factura_agrupada` | Σ `line_total` de los ítems no anulados | `customer_orders.discount` | `customer_orders.delivery_fee` | `subtotal − discount + delivery_fee` | `customer_orders.applied_promotions` |
| `sin_factura` | Σ `line_total` de los ítems no anulados | `0` (fijo) | `customer_orders.delivery_fee` | `subtotal + delivery_fee` | `[]` |

**Razón**:

- **`factura_propia`** lo manda FR-024: leer de la factura es lo que garantiza la igualdad
  exacta del criterio 10 *por construcción*. Verificado que la aritmética encaja con FR-008:
  `build_sale` calcula `total = subtotal − discount + tax + tip + delivery_fee`
  (`app/api/v1/sales/builder.py:100-117,199`) y acumula `subtotal` como Σ `line_total`
  **de lista** de las líneas cobrables (`builder.py:183-196`), con el descuento aparte. Es
  exactamente la forma que Q5 fijó para la pantalla.
- **`factura_agrupada`** lo manda FR-024a: "el desglose **propio del pedido**". En la
  práctica `customer_orders.discount` vale `0` en este caso (el cierre unificado lo pone a
  `0` cuando hay varios pedidos, `table_sessions/service.py:740`, y el dividido no toca el
  pedido), así que la fila de descuento no aparece por RN-004. La fórmula se escribe
  completa igual, para no depender de esa coincidencia.
- **`sin_factura`** lo manda FR-023: `Total = Subtotal + Envío`, sin descuento y sin
  consultar el motor de cobro.

**Σ `line_total` se toma del auxiliar que ya existe**: `OrderItem.line_total`
(`app/models/order_item.py:87-91`), que es `unit_price × quantity + addons_total`. Es la
decisión de diseño 1 de la spec y lo que exige FR-003: calcular `unit_price × quantity` a
secas subcobraría los adicionales por línea del Menú QR. Se filtra
`estado_cocina != 'anulado'` (FR-019), el mismo filtro que `checkout.order_sale_lines`
(`checkout.py:277`) aplica al facturar — por eso Σ de lo visible coincide con el subtotal de
la factura.

---

## D5 — Impuesto y propina de la factura: no se muestran, y hoy valen siempre 0

**Decisión**: `billing` no publica `tax` ni `tip` y la pantalla no pinta filas para ellos
(están fuera de alcance por Assumptions). Los cuatro importes se leen de la factura **tal
cual** cuando el caso es `factura_propia`, sin doblar `tax`/`tip` dentro de ningún otro.

**Razón**: `sales.tax` y `sales.tip` existen en el modelo, pero ningún camino de escritura
vigente los pone distintos de cero: `pos-terminal.store.ts:1163` lo dice literalmente
("Impuestos deprecado: se guarda/calcula siempre en 0"), `tenant-info.component.ts:281-282`
envía ceros, y ninguna pantalla envía propina. Con `tax = tip = 0`, la fórmula de
`build_sale` colapsa exactamente en `Subtotal − Descuento + Envío = Total`, que es FR-008.

**Riesgo residual y cómo se cierra**: una venta histórica con `tax` o `tip` > 0 rompería
SC-007 para ese pedido (las tres filas visibles no sumarían el Total mostrado). Doblar ese
importe dentro del subtotal sería inventar un dato y lo prohíbe RN-001. La salida es
**medir antes de implementar**: `quickstart.md` §1 incluye la consulta que cuenta
`sales WHERE tax > 0 OR tip > 0` **en todos los esquemas de `shared.tenants`** (`tenant` es
un alias de `schema_translate_map`, no un esquema real, así que medir uno solo no despeja la
compuerta). Si devuelve cero en todos —lo esperado— no hay nada que decidir. Si devuelve
filas, es una decisión de negocio nueva (qué mostrar en esos pedidos) y se registra como
anomalía antes de tocar la pantalla. El desempate de requisitos, si el caso apareciera, ya
lo fija FR-024: manda el total de la factura.

---

## D6 — Etiqueta de la fila de descuento con una lista que viene por regla, no por promoción

**Decisión**: para elegir la etiqueta de la fila de descuento se parte de
`applied_promotions`, se descartan las entradas con `amount <= 0`, y se agrupan las
restantes por `promotion_id` (y por `name` cuando `promotion_id` falta). Si queda **una
sola** promoción distinta, la etiqueta es su `name`; si quedan dos o más, o ninguna, la
etiqueta es `"Descuento"`.

**Razón**: FR-009 y FR-010 hablan de promociones, pero el snapshot guardado tiene **una
entrada por regla**, no por promoción: `applied_to_dicts` produce
`[{promotion_id, rule_id, name, amount}]` y `AppliedPromotion` documenta `amount` como "el
descuento agregado de ESTA regla" (`app/api/v1/promotions/service.py:126-131,314-323`). Una
sola promoción con dos reglas dejaría dos entradas; contar entradas en vez de promociones
pintaría "Descuento" donde FR-009 exige el nombre. Agrupar por `promotion_id` es la lectura
correcta de "más de una promoción".

**Dónde se calcula**: en el servidor, junto al resto de `billing` (D1). La pantalla recibe
`billing.discount_label` ya resuelto y la lista `billing.promotions` por si alguna vista
futura la necesita.

**Alternativa considerada**: repartir el agregado entre promociones y pintar una fila por
cada una. La descarta la propia FR-010 ("repartirlo entre promociones para pintar una fila
por cada una sería recalcular").

---

## D7 — Un pedido cancelado no muestra el aviso "el descuento se calcula al cobrar"

**Decisión**: el aviso literal de FR-023 se muestra cuando `billing.state = 'sin_factura'`
**y** el pedido no está en `cancelada`. Un pedido cancelado sin factura muestra su desglose
(FR-014) y ningún aviso.

**Razón**: FR-023 habla de un pedido "aún no cobrado" y su texto promete un cobro futuro
("este total **aún puede cambiar**"). Un pedido cancelado es terminal: nunca se va a cobrar
y su total no va a cambiar nunca más. Mostrarle ese aviso sería afirmar algo falso en la
pantalla cuyo valor, según la propia spec, es que lo que muestra no cambia. US1 §5, que es
el escenario del pedido cancelado, pide el desglose y la etiqueta "Cancelada", y no menciona
ningún aviso.

**Estado**: es una regla de presentación que la spec no enuncia, derivada de su intención.
Queda como **punto de confirmación del negocio** en `tasks.md`, no como deuda silenciosa. Si
el negocio prefiere mostrarlo igual, el cambio es quitar una condición de una plantilla.

---

## D8 — La condición del aviso de FR-018 también se calcula en el servidor

**Decisión**: `billing` publica `sin_detalle_de_precios: bool`, verdadero cuando el pedido
tiene **al menos un ítem no anulado** y la **suma de los `line_total` de esos ítems es 0**.
Es la condición literal de Q6/FR-018, sin nada añadido.

**Razón**: una sola fuente para la misma aritmética (D4 ya suma los mismos ítems en el
servidor) y una condición verificable en el contrato, no en la plantilla. Las tres
precisiones de FR-018 salen gratis de la definición: no se dispara por ausencia de descuento
(no interviene), no se dispara con todas las líneas anuladas (no hay ítem no anulado), y no
se dispara sin líneas (ídem).

**Alternativa considerada**: calcularlo en el navegador desde `items`. Se puede, pero deja
la condición del aviso fuera de los tests de contrato y abre la puerta a que la pantalla y
el servidor discrepen sobre qué ítems cuentan.

---

## D9 — Los ítems anulados se marcan con la etiqueta que ya existe, y sin importe

**Decisión**: un ítem con `estado_cocina = 'anulado'` se pinta en la lista con el distintivo
que ya produce `kitchenStatusLabel('anulado')` → "Anulado"
(`order-status.util.ts:85-98`), y **en lugar** de su importe. No se muestra un importe
tachado.

**Razón**: FR-019a admite las dos formas ("sin importe, o con el importe tachado y señalado
como excluido"). Se elige la primera porque un número tachado sigue leyéndose como dinero al
ojear la columna y porque la suma visual que SC-007 pide verificar a mano es más limpia sin
cifras que no suman. La etiqueta se reusa en vez de inventar una nueva: ya es la del KDS y
la de la terminal de mesas, con su color propio.

---

## D10 — El resumen reusa `BillSummaryComponent`, que gana un input aditivo

**Decisión**: el bloque de resumen se pinta con el componente compartido
`app/modules/tables/components/bill-summary.component.ts`, al que se le añade un input
**opcional** `discountLabel` (por defecto `'Descuento'`) para poder mostrar el nombre de la
promoción que exige FR-009.

**Razón**: ese componente ya es la fuente única de las filas Subtotal/Descuento/Domicilio/
Total y del formato `$ 17.000`, y ya resolvió la duplicación en cuatro pantallas
(`pos-checkout-panel`, `payment-attempt-review-panel`, `manual-order-page`,
`session-bill-panel`). Pintar un quinto desglose a mano en el Detalle de Orden sería
reintroducir exactamente el problema que ese componente cerró, y pondría en riesgo RN-002.
Además ya condiciona las filas de descuento y envío a `> 0`, que es literalmente RN-004 /
FR-006 / FR-007: esas dos reglas se cumplen por reuso, no por código nuevo.

El input es **aditivo y con valor por defecto**: las cuatro pantallas que ya lo consumen no
cambian de comportamiento ni de markup (Principio II).

**Alternativa considerada**: pintar el resumen dentro de `order-detail.component.ts`.
Descartada: duplica formato y condicionado de filas, y la próxima vez que cambie el formato
monetario habrá cinco sitios que tocar en vez de uno.

---

## D11 — El copiado reusa el patrón probado, sin extraerlo a un servicio

**Decisión**: `copiarDatosDeEntrega()` en el componente del detalle, con el mismo patrón que
`transfer-details-step.component.ts:407-416`: `await navigator.clipboard.writeText(texto)`
dentro de un `try`, `toast.success(...)` en el camino feliz, `toast.error(...)` en el
`catch`. Se usa el `ToastService` ya existente (`app/shared/feedback/toast.service.ts`). **No**
se extrae a un helper compartido.

**Razón**: la decisión de diseño 3 de la spec pide reusar el patrón y el servicio de
notificaciones, y eso es lo que se hace. Extraerlo sería una refactorización no pedida por
ninguna historia (Principio V) sobre dos únicos llamadores con mensajes distintos: la parte
compartible son cinco líneas, y la no compartible son justo los textos que FR-017 fija.

**Textos**: éxito, el literal de FR-017 → `"Datos de envío copiados al portapapeles"`;
fallo, un aviso legible propio de esta pantalla → `"No se pudieron copiar los datos"`. El
fallo cubre el Edge Case de portapapeles no disponible: los datos siguen en pantalla y
seleccionables, porque el bloque no se oculta ni se bloquea en ningún momento (US2 §5).

---

## D12 — Forma exacta del texto copiado

**Decisión**: texto plano, una línea por campo diligenciado, con etiqueta, separador `": "`,
y en el orden que fija Assumptions: Cliente, Teléfono, Dirección, Notas. Los campos vacíos
—nulos, cadena vacía o solo espacios— **no producen línea**. Sin importes, sin identificador
del pedido, sin líneas en blanco y sin guiones de relleno.

```text
Cliente: María Gómez
Teléfono: 3001234567
Dirección: Cra 12 #34-56, Apto 201
Notas: Portería azul, timbre 201
```

**Razón**: FR-016 (un campo por línea con su etiqueta), FR-020 y RN-003 (lo vacío no se
pinta, ni en pantalla ni en el texto copiado), y Assumptions (orden y contenido). US2 §4 lo
verifica directamente: con solo dirección y teléfono, el texto tiene exactamente dos líneas.

**Detalle de implementación**: se construye filtrando una lista de pares
`[etiqueta, valor]` por `valor?.trim()` y uniendo con `\n`. Es la misma función que alimenta
la tarjeta visible, de modo que no puedan divergir (un campo que se ve es un campo que se
copia).

---

## D13 — El encabezado: mesa cuando hay mesa, tipo cuando no la hay

**Decisión**: `encabezado()` devuelve la etiqueta de mesa actual
(`Mesa 4` / `Mesa 4 · Terraza`) cuando el pedido tiene `dining_table_id`; si no, devuelve
`orderTypeLabel(order.order_type)` — "Para llevar", "Domicilio" o "Sin especificar" para un
pedido histórico sin clasificar. El rótulo de encima deja de decir "Mesa" siempre: dice
"Mesa" cuando hay mesa y "Tipo de pedido" cuando no.

**Razón**: FR-012 pide identificar el tipo, y la decisión de diseño 4 pide tomar las
etiquetas del artefacto que ya usan los filtros del listado: `orderTypeLabel`
(`order-status.util.ts:66-69`), que además ya resuelve el caso del `order_type` nulo sin
inventar nada. La palabra "Mostrador", que hoy aparece para todo pedido sin mesa
(`order-detail.component.ts:139`), desaparece: es justamente el problema 3 de la spec.

**Por qué `dining_table_id` y no `order_type === 'DINE_IN'`**: hay pedidos históricos con
mesa y `order_type` nulo (la columna nació nulable y sin relleno retroactivo,
`customer_order.py:55-58`). Preguntar por la mesa muestra la mesa en esos pedidos; preguntar
por el tipo los mandaría a "Sin especificar" teniendo la mesa delante.

---

## D14 — El bloque de entrega depende del tipo, no de que los campos estén llenos

**Decisión**: el bloque "Datos de entrega" se renderiza si y solo si
`order_type === 'DELIVERY'`. Dentro, cada uno de los cuatro campos se renderiza solo si
tiene valor.

**Razón**: FR-015 ("únicamente en pedidos a domicilio") y FR-015a / FR-020 (un domicilio al
que le falte un campo sigue mostrando los demás). Son dos condiciones distintas y no se
mezclan: el bloque es del tipo de pedido, los campos son de los datos. Un domicilio sin
ningún dato diligenciado muestra el bloque con el botón de copiar deshabilitado, que es más
honesto que esconder que el pedido es un domicilio.

---

## D15 — Lectura tolerante: `billing` ausente no significa cero

**Decisión**: si la respuesta no trae `billing` (backend anterior al despliegue), la
pantalla **no pinta el bloque de resumen ni los importes por línea**. No pinta ceros, no
calcula nada en su lugar y el resto de la pantalla (ítems, encabezado, datos de entrega)
funciona igual.

**Razón**: es la sección "Decisiones de Compatibilidad" de la spec palabra por palabra
("ausencia de dato se trata como 'no mostrar', nunca como cero"; "Sin recálculo como
respaldo"). También protege el despliegue desacoplado: el frontend puede salir antes que el
backend sin pintar datos falsos ni romperse.

---

## D16 — FR-011 se cumple publicando además los dos campos crudos del pedido

**Decisión**: `OrderResponse` gana, además de `billing`, los dos campos planos que FR-011
nombra: `discount` (el agregado congelado en el cobro) y `applied_promotions` (la lista con
nombre y monto). La pantalla **no los consume**: su única fuente es `billing`.

**Razón**: FR-011 es literal ("El sistema MUST exponer el descuento guardado del pedido y la
lista de promociones aplicadas (nombre y monto) en la respuesta de consulta de un pedido") y
habla del dato **del pedido**, que no siempre coincide con el que se muestra (cuando manda
la factura, D4). Cumplirlo con `billing` sería cumplir otra cosa. El costo es nulo: las dos
son columnas ya cargadas en el mismo `SELECT` (`customer_order.py:84-91`), sin consulta
extra.

**Regla que acompaña la decisión, para no crear dos fuentes de verdad**: la pantalla lee
`billing` y nada más. Queda escrito en el contrato y verificado en un test de componente.

---

## D17 — El aislamiento se prueba, no se construye

**Decisión**: no se escribe código de aislamiento. Se añaden dos verificaciones:

1. **Automática**: `GET /orders/{id}` con un identificador que no existe en el esquema de la
   sesión responde `404 "Order not found"` y un cuerpo que no revela nada del pedido. Es el
   comportamiento actual de `_load_order` (`orders/router.py:47-64`) y queda congelado.
2. **Manual**: recorrido de dos tenants en `quickstart.md`, tomando el identificador de un
   pedido real del tenant A y pidiéndolo autenticado como el tenant B, por interfaz y por
   API (SC-006).

**Razón**: la decisión de diseño 6 de la spec y FR-025 ("se verifica como **prueba de
regresión** del aislamiento ya existente"). El aislamiento real lo da el `search_path` por
esquema de tenant, que no es algo que esta spec pueda ni deba tocar. La prueba automática no
puede abarcar dos esquemas: la suite corre sobre SQLite en memoria
(`app/characterization_tests/orders_fixtures.py`), sin esquemas por tenant — por eso la
parte de dos tenants es manual y explícita, no un test que finge cubrirla.

---

## D18 — Nada de esto necesita una dependencia nueva ni una migración

**Decisión**: cero dependencias nuevas (Principio IX satisfecho por ausencia) y cero
cambios de esquema (Principio VIII no aplica).

**Verificado**: los cuatro orígenes de datos ya existen —`order_items.unit_price`,
`addons_total` y el auxiliar `line_total`; `customer_orders.discount`,
`applied_promotions`, `delivery_fee`, `delivery_address`, `delivery_phone`, `customer_name`
y `notes`; `sales.subtotal/discount/delivery_fee/total/applied_promotions`— y los dos
utilitarios de frontend también (`formatMoney`, `orderTypeLabel`, `kitchenStatusLabel`,
`BillSummaryComponent`, `ToastService`). El portapapeles es API nativa del navegador, ya
usada en producción en el checkout del comensal.

---

## Resumen de incógnitas resueltas

| Incógnita de Technical Context | Resuelta en |
|---|---|
| Dónde se decide entre factura y pedido | D1, D2 |
| Qué columna alimenta cada importe | D4 |
| Qué hacer con `tax`/`tip` de la factura | D5 |
| Cómo se etiqueta la fila de descuento | D6 |
| Qué dispara cada aviso | D2 (agrupada), D7 (sin cobrar), D8 (sin detalle) |
| Cómo se marcan los ítems anulados | D9 |
| Qué se reusa y qué se escribe nuevo en el frontend | D10, D11, D13 |
| Forma del texto copiado | D12 |
| Comportamiento ante respuesta antigua | D15 |
| Alcance de la verificación de aislamiento | D17 |

**Puntos que necesitan confirmación del negocio antes de cerrar la implementación** (van a
`tasks.md` como tareas explícitas, no como supuestos):

- **D2** — el texto de FR-024a aplicado al cierre dividido.
- **D5** — qué mostrar si la consulta encuentra ventas históricas con `tax`/`tip` > 0.
- **D7** — el aviso de FR-023 suprimido en pedidos cancelados.
