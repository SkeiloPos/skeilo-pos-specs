---

description: "Tareas de la spec 094 — desglose económico y datos de entrega en el Detalle de Orden"
---

# Tasks: Desglose Económico y Datos de Entrega en el Detalle de Orden

**Input**: Documentos de diseño de `/specs/094-detalle-orden-desglose-entrega/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md) (D1–D18), [data-model.md](./data-model.md), [contracts/order-detail-api.md](./contracts/order-detail-api.md), [contracts/order-detail-screen.md](./contracts/order-detail-screen.md), [quickstart.md](./quickstart.md)

**Tests**: **sí se piden** (Principio X; plan.md → *Testing*; contrato de API → *Garantías*). Backend: `unittest` sobre SQLite en memoria, invocando las funciones de endpoint como funciones Python (patrón de `test_orders_pagination.py`). Frontend: Vitest 4 + `TestBed` vía `npm test`. Cada prueba se escribe **antes** de su implementación y debe fallar primero. Lo que un test no puede medir —el tiempo de respuesta de SC-001, la igualdad con el módulo de Ventas en vivo (SC-002), los 20 pedidos del histórico (SC-004) y el aislamiento entre dos tenants reales (SC-006)— se verifica a mano y se registra; **no** se simula con un test verde que no prueba nada (research.md D17).

**Organización**: por historia de usuario de [spec.md](./spec.md), en el orden de prioridad del plan: US1 (P1) → US2 (P1) → US3 (P2) → US4 (P3). Cada historia es un incremento entregable por separado.

## Formato: `[ID] [P?] [Story] Descripción`

- **[P]**: se puede ejecutar en paralelo (archivo distinto, sin dependencia de una tarea sin terminar)
- **[Story]**: historia de usuario (US1–US4)
- Abreviaturas de ruta: `BE/` = `../pos-backend/app/` · `FE/` = `../pos-heladeria/src/app/` · `SPEC/` = esta carpeta (`pos-specs/specs/094-detalle-orden-desglose-entrega/`)

## Notas de gobernanza

- **Dos repositorios cambian**: `pos-backend` (aditivo: tres campos en `OrderResponse` y el armador del desglose) y `pos-heladeria` (la pantalla, más dos archivos compartidos tocados de forma aditiva). **Cero migraciones, cero columnas, cero escrituras, cero dependencias nuevas** (research.md D18, data-model.md §6).
- **Ramas (Principio XIV)**: `feat/094-order-detail-billing-breakdown` en **los dos** repositorios, creada **desde `develop`** (hoy los dos están en `develop`) y **antes** de tocar código. La spec vive en `pos-specs`, rama `main`.
- **Decisiones de negocio ya tomadas**: Q1–Q8 de la spec, registradas como **A-104 a A-107** en `specs/000-reconocimiento/registro-de-anomalias.md`. No se reabren aquí.
- **Tres puntos pendientes de confirmación del negocio** (plan.md → *Constitution Check*, research.md): **D5** es una **compuerta** que bloquea el resumen (T008); **D2** y **D7** se plantean temprano (T007) y se resuelven antes de cerrar US1 (T027), porque cada uno se materializa cambiando un literal o una condición.
- **Cambios de comportamiento existente, los tres exigidos por la spec**: la etiqueta "Comensal" → "Cliente" (FR-013, US4), el encabezado "Mesa"/"Mostrador" → tipo de pedido (FR-012, D13) y los tres campos nuevos de `OrderResponse`. El cuarto archivo compartido tocado, `bill-summary.component.ts`, cambia con un **input aditivo con valor por defecto**: las cuatro pantallas que ya lo consumen no cambian ni un píxel (D10, Principio II).
- **Characterization tests (Principio III)**: ningún test `"CONGELA comportamiento actual:"` se modifica. Los de `test_orders_checkout.py` y `test_table_sessions_service.py` que congelan cómo se escriben `customer_order_id`, `discount` y `applied_promotions` en el cobro son el contrato del que D2 y D4 derivan la lectura: se apoyan en ellos, no se tocan.
- **Hallazgo del reconocimiento de esta sesión, útil y no anotado en `research.md`**: el frontend **ya tiene** el auxiliar del importe de lista por línea, `lineTotalGross(item)` en `FE/modules/tables/interfaces/dining.interface.ts`, que lee `line_total` y cae a `unit_price × quantity + addons_total` cuando el backend es anterior. Es exactamente lo que FR-002/FR-003 piden y lo que la decisión de diseño 1 de la spec manda reusar: **no se escribe ningún cálculo de importe de línea nuevo** (T025).
- **Segundo hallazgo**: `BE/characterization_tests/orders_fixtures.py` **no tiene armador de `Sale`** (los tests la construyen a mano). Los tests de esta spec necesitan sembrar ventas con `customer_order_id` y con `table_session_id`, así que el armador se añade una vez (T009) en vez de repetir el `Sale(...)` crudo en cada caso.
- **Convenciones de código del repo que se siguen**: `@Input()` con decorador (el proyecto no usa inputs de señal), `standalone: true`, comentarios y nombres de test en español de Colombia (Principio XIII), identificadores de API en la mezcla ya establecida (`billing`, `state`, `sin_factura`, `sin_detalle_de_precios`).
- **Commits (Principio XV)**: solo cuando el usuario lo pida; pequeños, en inglés, Conventional Commits, **sin ninguna marca de autoría de IA**. Agrupación sugerida en T052.
- **Fuera de alcance, por decisión y no por olvido**: calcular `billing` en el listado de pedidos (D3), extraer el portapapeles a un servicio compartido (D11), mostrar `tax`/`tip` (D5), usar `discounted_unit_price`/`discounted_line_total` (Q5), diferenciar contenido por rol (RN-007) y separar la nota de cocina de las referencias de entrega (Q1).

---

## Phase 1: Setup

**Propósito**: ramas, archivo de notas, líneas base de las dos suites, datos de prueba y planteamiento temprano de las decisiones de negocio.

- [X] T001 Crear en `../pos-backend` la rama `feat/094-order-detail-billing-breakdown` **desde `develop`** y confirmar con `git status` que el árbol queda limpio (Principio XIV; va **antes** de cualquier cambio de código)
- [X] T002 [P] Crear en `../pos-heladeria` la rama `feat/094-order-detail-billing-breakdown` **desde `develop`** y confirmar árbol limpio con `git status`
- [X] T003 [P] Crear `SPEC/implementation-notes.md` (archivo NUEVO, en español de Colombia) con las secciones "Decisiones", "Compuerta de datos (D5)", "Verificación automática", "Verificación manual", "Aislamiento (SC-006)" y "Limitaciones"; anotar en "Decisiones" que D2 y D7 quedan planteadas en T007 y que D5 es una compuerta que bloquea el resumen
- [X] T004 [P] Medir la **línea base** de la suite de frontend: con la rama de T002 recién creada y sin cambios, ejecutar `npm test` en `../pos-heladeria` y anotar en `SPEC/implementation-notes.md` → "Verificación automática" el número exacto de fallos y los archivos que fallan. La suite arrastra fallos preexistentes ajenos a esta spec; sin esta línea base es imposible saber si un rojo posterior es nuevo (quickstart.md §0)
- [X] T005 [P] Medir la línea base de la suite de backend: `env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'` en `../pos-backend` y anotar el conteo en `SPEC/implementation-notes.md`
- [X] T006 [P] Preparar en la base de datos de desarrollo los **diez** pedidos de `SPEC/quickstart.md` §0 (mesa cobrado 2 × $ 8.000; con una promoción; para llevar; domicilio completo con envío $ 3.000; domicilio con solo dirección y teléfono, envío $ 0; abierto con promoción vigente; mesa cobrado en cuenta unificada con otro pedido; cancelado; tres líneas con una anulada; uno con adicional por línea del Menú QR y uno con combo), marcando todo lo creado con el prefijo `[094-test]`; anotar sus `id` en `SPEC/implementation-notes.md` → "Verificación manual" para poder repetir los recorridos sin volver a buscarlos
- [X] T007 [P] Plantear al dueño de la spec los cuatro puntos de confirmación —**D2** y **D7** de `SPEC/research.md`, más **D2-bis** y la **etiqueta de la fila de envío**— y anotar cada pregunta con su fecha en `SPEC/implementation-notes.md` → "Decisiones": (a) **D2** — el texto literal de FR-024a dice "se cobró junto con otros en una cuenta unificada", que es exacto para el cierre unificado e **impreciso** para el cierre dividido (un pedido repartido en varias facturas); ¿se acepta el mismo texto en los dos casos, como fijó Q8? (b) **D7** — ¿se suprime el aviso de FR-023 en un pedido **cancelado**, donde prometer que "el total aún puede cambiar" es afirmar algo falso? (c) **D2-bis** — un pedido **cancelado** dentro de una mesa que después se cobró no entró en ninguna factura: se confirma que no se le muestra el aviso de cuenta unificada (se trata como `sin_factura`, G4b); y (d) **etiqueta de la fila de envío** — la spec llama al concepto "Envío" y la pantalla la rotula **"Domicilio"**, la palabra que ya usan las cuatro superficies de cobro vía el default de `BillSummaryComponent`; se confirma que el producto quiere una sola palabra para esa fila y que es "Domicilio" (si prefiere "Envío", el cambio es pasar `[deliveryFeeLabel]="'Envío'"` en T026 y asertarlo en T022, sin tocar las otras cuatro pantallas). **No bloquean** US2 ni US4. Cuándo se necesita cada respuesta: (c) antes de **T018** (es una condición del servidor), (a), (b) y (d) antes de **T026/T027**

**Checkpoint**: ramas creadas, notas abiertas, líneas base medidas, datos de prueba sembrados y D2/D7 planteadas. Recién entonces se escribe código.

---

## Phase 2: Foundational (prerrequisitos bloqueantes)

**Propósito**: la compuerta de datos, los tipos del contrato en los dos lados y el input del componente compartido. **Bloquea US1 y US3** (las dos historias que consumen `billing`). **US2 y US4 no dependen de esta fase** y pueden empezar en paralelo o entregarse antes (plan.md → Principio VI).

- [X] T008 ⛔ **Compuerta D5 — bloquea todo el resumen.** Ejecutar la consulta de `SPEC/quickstart.md` §1 —la que recorre **todos** los esquemas de `shared.tenants` con `\gexec`, porque `tenant` es un alias de `schema_translate_map` y no un esquema real— y anotar el resultado literal, esquema por esquema, en `SPEC/implementation-notes.md` → "Compuerta de datos (D5)". **Si devuelve `0` en todos** (lo esperado: el impuesto está deprecado y ninguna pantalla envía propina) ⇒ seguir. **Si devuelve más de `0` en cualquier esquema** ⇒ **parar**: con `tax` o `tip` > 0 la fórmula `Subtotal − Descuento + Envío = Total` no se cumple para esas filas y SC-007 no se puede garantizar; qué mostrar en esos pedidos es una decisión de negocio **nueva** que se registra como anomalía en `specs/000-reconocimiento/registro-de-anomalias.md` antes de implementar el resumen
- [X] T009 [P] Añadir a `BE/characterization_tests/orders_fixtures.py` el armador `make_sale(db, *, order=None, table_session=None, **kw) -> Sale` (hoy **no existe**: los tests construyen `Sale(...)` a mano), con `kw.setdefault` para `cash_shift_id` (creando el turno con `make_cash_shift` si no se pasa), `user_id`, `status="paid"`, `subtotal`, `discount`, `delivery_fee`, `total` y `applied_promotions=[]`, y asignando `customer_order_id`/`table_session_id` solo cuando se pasen `order`/`table_session` — para poder sembrar los tres casos de D2 (venta propia, venta de la sesión sin pedido, ninguna) sin repetir el constructor crudo en cada test
- [X] T010 [P] Añadir a `BE/api/v1/orders/schemas.py` los dos esquemas nuevos y los tres campos de `OrderResponse` (líneas 211–250), con comentarios que citen el FR que los obliga: `AppliedPromotionOut` (`promotion_id: UUID | None`, `name: str | None`, `amount: Decimal`; **sin** `rule_id`, que no se publica) y `OrderBillingSummary` (`state: Literal["sin_factura","factura_propia","factura_agrupada"]`, `source: Literal["pedido","factura"]`, `subtotal`, `discount`, `discount_label: str | None`, `delivery_fee`, `total`, `promotions: list[AppliedPromotionOut]`, `sin_detalle_de_precios: bool`); y en `OrderResponse`: `discount: Decimal = Decimal("0")`, `applied_promotions: list[AppliedPromotionOut] = Field(default_factory=list)` (FR-011, D16) y `billing: OrderBillingSummary | None = None` (D3: solo lo rellena el detalle). Tipos y nulabilidad exactos en `SPEC/contracts/order-detail-api.md` §1
- [X] T011 [P] Añadir a `FE/modules/tables/interfaces/dining.interface.ts` las dos interfaces nuevas y los tres campos **opcionales** de `DiningOrder` (líneas 256–286), siguiendo la convención del archivo de importes como `string`: `AppliedPromotion { promotion_id?: string | null; name?: string | null; amount: string }`, `OrderBilling { state: 'sin_factura' | 'factura_propia' | 'factura_agrupada'; source: 'pedido' | 'factura'; subtotal: string; discount: string; discount_label?: string | null; delivery_fee: string; total: string; promotions?: AppliedPromotion[]; sin_detalle_de_precios: boolean }` y, en `DiningOrder`: `discount?: string`, `applied_promotions?: AppliedPromotion[]`, `billing?: OrderBilling | null`. Los tres **opcionales** para que un frontend nuevo contra un backend anterior compile y no pinte el resumen (D15, data-model.md §5); comentar que la pantalla consume **solo** `billing` (D16)
- [X] T012 [P] Escribir en `FE/modules/tables/components/bill-summary.component.spec.ts` (AMPLIAR el existente, 26 líneas) dos casos del input nuevo: (a) **sin** pasar `discountLabel` y con `discount = 4000`, la fila sigue diciendo exactamente **"Descuento"** —el valor por defecto que protege a las cuatro pantallas consumidoras (Principio II, D10)—; (b) con `discountLabel = '2 x $12.000'` y `discount = 4000`, la fila dice `2 x $12.000` y el importe sigue apareciendo como `− $ 4.000`. El caso (a) debe pasar y el (b) fallar (el input no existe)
- [X] T013 Añadir a `FE/modules/tables/components/bill-summary.component.ts` el input **aditivo** `@Input() discountLabel = 'Descuento';` junto a los demás (líneas 67–76) y usarlo en la plantilla en lugar del literal `<span>Descuento</span>` de la línea 30, **sin** tocar la condición `@if (discount > 0)` (que ya es literalmente FR-006 / RN-004) ni ninguna otra fila; hace pasar T012
- [X] T014 [P] Confirmar con `grep -rn "discountLabel" ../pos-heladeria/src/app/` que **ninguna** de las cuatro pantallas que ya consumen el componente (`pos-checkout-panel`, `payment-attempt-review-panel`, `manual-order-page`, `session-bill-panel`) pasa el input nuevo, de modo que conservan su texto y su markup exactos; anotar el resultado en `SPEC/implementation-notes.md`

**Checkpoint**: la compuerta de datos está medida, el contrato existe como tipos en los dos lados y el componente compartido ya acepta la etiqueta de la promoción sin cambiar para nadie más. US1 y US3 pueden empezar.

---

## Phase 3: User Story 1 — Verificar el cobro de un pedido sin salir de la pantalla (Priority: P1) 🎯 MVP

**Goal**: el Detalle de Orden muestra, por cada línea, cantidad, precio unitario y el importe **de lista**; y debajo un resumen con Subtotal, Descuento (si hubo), Envío (si hubo) y Total, con el aviso que corresponda a cada caso de facturación. El encabezado identifica el tipo de pedido.

**Independent Test**: abrir el detalle de un pedido de mesa ya cobrado con dos unidades de un producto y verificar que los importes por línea y el Total coinciden con lo que se cobró, sin tocar el módulo de Ventas (`SPEC/quickstart.md` §3, filas 1 y 7).

### Tests for User Story 1 — backend (archivo NUEVO, secuencial: un solo archivo)

- [X] T015 [US1] Crear `BE/characterization_tests/test_orders_billing_summary.py` con los casos de las garantías **G1–G5** del contrato, invocando `orders_router.get_order(order_id=..., db=db, _=fx.make_user_double())` como función Python (patrón de `test_orders_pagination.py`) y sembrando con `fx.make_customer_order`, `fx.make_order_item` y el `make_sale` de T009: **G3** venta con `customer_order_id` del pedido ⇒ `state == "factura_propia"`, `source == "factura"` y los cuatro importes son los de la `Sale` (no los del pedido: sembrar una `Sale` con importes **distintos** de la suma de líneas para que el test distinga de verdad la fuente); **G4** venta con el `table_session_id` del pedido pero **sin** `customer_order_id` ⇒ `state == "factura_agrupada"` y `source == "pedido"`; **G4b** el mismo escenario con el pedido en `status: "cancelada"` ⇒ `state == "sin_factura"` (nunca se cobró: el aviso de FR-024a afirmaría un cobro inexistente, D2); **G5** sin ninguna venta ⇒ `state == "sin_factura"`, `discount == 0`, `discount_label is None`, `promotions == []`; **G1** con `source == "pedido"`, `subtotal == Σ line_total` de los ítems con `estado_cocina != "anulado"`, con un caso que incluya un ítem anulado y otro con `addons_total > 0` (FR-003: `unit_price × quantity` a secas subcobraría); **G2** `total == subtotal − discount + delivery_fee` y `>= 0` en los tres estados. Nombres de test en español de Colombia — debe fallar (`billing` llega `None`)
- [X] T016 [US1] Añadir a `BE/characterization_tests/test_orders_billing_summary.py` los casos **G6–G8** y los casos límite de `SPEC/contracts/order-detail-api.md` §4: **G6** `sin_detalle_de_precios` es `True` ⇔ hay ≥ 1 ítem no anulado **y** la suma de sus `line_total` es `0`, con los tres contra-casos que FR-018 exige por separado (pedido normal sin descuento ⇒ `False`; **todas** las líneas anuladas ⇒ `False` con `subtotal == 0`; pedido **sin** líneas ⇒ `False`); **G7** `discount_label` es el `name` de la única promoción con `amount > 0` tras agrupar por `promotion_id`, con los cuatro casos de D6 (una promoción ⇒ su nombre; **dos reglas de la misma** promoción ⇒ el nombre de esa promoción, no `None`; dos promociones distintas ⇒ `None`; entradas con `amount = 0` ⇒ ignoradas al elegir la etiqueta); **G8** sembrar un cambio de precio en el catálogo y en las promociones vigentes después de crear el pedido y verificar que **ningún** importe de `billing` cambia (RN-001, FR-022); más `delivery_fee` en `NULL` ⇒ se publica `"0.00"` — debe fallar
- [X] T017 [US1] Añadir a `BE/characterization_tests/test_orders_billing_summary.py` la **guardia G9** y la verificación de D3: (a) contar las sentencias SQL de una petición de detalle con el `event.listen(..., "before_cursor_execute")` del patrón de `test_orders_pagination.py:262-288` y comprobar que el número **no crece** al pasar de 1 a 10 ítems en el pedido (un N+1 al resolver el estado de facturación lo haría); (b) que `orders_router.list_orders(...)` devuelve `billing is None` en todos los ítems de la página, y que su propia guardia de trabajo acotado sigue en verde — el listado no gana ni una consulta (D3). **Esta tarea es una guardia y empieza en verde por construcción**: en cuanto T010 añade `billing` con `None` por defecto, las dos aserciones pasan sin implementación. Su valor no es fallar ahora, sino ponerse roja si T018/T019 introducen el N+1 o si el listado empieza a calcular `billing`, así que se ejecuta **antes y después** de T019 y se anota el conteo de referencia en `SPEC/implementation-notes.md` (misma excepción razonada que T044)

### Implementation for User Story 1 — backend

- [X] T018 [US1] Añadir a `BE/api/v1/orders/service.py` la función `build_billing_summary(db, order) -> OrderBillingSummary` y sus auxiliares privados, junto a `order_has_sale` (línea 81) y siguiendo su mismo patrón de subconsulta con `.limit(1)`: (a) resolver el `state` en el orden exacto de la tabla de D2 —`Sale.customer_order_id == order.id` ⇒ `factura_propia`; si no, `order.status != "cancelada"` **y** `order.table_session_id` no nulo **y** existe `Sale.table_session_id == order.table_session_id` ⇒ `factura_agrupada`; si no, `sin_factura`— (la condición del cancelado es G4b: un pedido cancelado nunca entró en una factura, así que el aviso de FR-024a afirmaría un cobro inexistente; **no** se aplica a la primera regla, donde la factura sí cubre el pedido), reusando `order_has_sale` para la primera consulta para no duplicarla; (b) llenar los importes **según la tabla de D4**, leyendo de la `Sale` solo en `factura_propia` (y **sin** sumar `tax` ni `tip`, D5) y, en los otros dos, sumando `item.line_total` (la propiedad de `BE/models/order_item.py:87-91`, **no** un cálculo nuevo) de los ítems con `estado_cocina != "anulado"` (FR-019); (c) calcular `discount_label` agrupando `applied_promotions` por `promotion_id` tras descartar las entradas con `amount <= 0`, y devolver el `name` solo si queda **una** promoción distinta (D6); (d) calcular `sin_detalle_de_precios` con la condición literal de FR-018 (D8); (e) garantizar `total >= 0` (FR-008). Comentarios en español de Colombia citando FR-024/FR-024a/FR-024b y las decisiones D2, D4, D6 y D8; hace pasar T015 y T016
- [X] T019 [US1] En `BE/api/v1/orders/router.py`, dentro de `_load_order` (líneas 48–64) y **solo ahí**, asignar `order.billing = service.build_billing_summary(db, order)` junto a las asignaciones de `paid` y `staff_user_name` que ya viven ahí; **no** tocar `_decorate_orders` (línea 615) ni `list_orders`, para que el listado siga devolviendo `billing: null` sin una consulta más (D3). Verificar que los nueve llamadores de `_load_order` que devuelven la orden tras una escritura siguen respondiendo igual, ahora con el campo nuevo; hace pasar T017

### Tests for User Story 1 — frontend (un solo archivo, secuencial)

- [X] T020 [US1] Ampliar `FE/modules/orders/pages/order-detail.component.spec.ts` (66 líneas) con el **encabezado** (D13): con `dining_table_id` resuelto a una mesa, el rótulo dice `Mesa` y el valor `Mesa 4` (o `Mesa 4 · Terraza` con nombre); con `dining_table_id: null` y `order_type: 'TAKEAWAY'`, el rótulo dice `Tipo de pedido` y el valor `Para llevar`; con `'DELIVERY'` ⇒ `Domicilio`; con `order_type: null` ⇒ `Sin especificar`; y la palabra **"Mostrador" ya no aparece** en ninguno de los cuatro casos — debe fallar
- [X] T021 [US1] Ampliar `FE/modules/orders/pages/order-detail.component.spec.ts` con los **importes por línea**: con un ítem de `quantity: 2`, `unit_price: '8000'` y `line_total: '16000'`, el render contiene `$ 8.000` y `$ 16.000`; con `addons_total: '2000'`, el importe mostrado es el `line_total` completo y el monto de adicionales queda visible o indicado (FR-004); un ítem con `discounted_unit_price`/`discounted_line_total` poblados **no** muestra ninguno de los dos valores (Q5, contrato de pantalla §2); un ítem con `estado_cocina: 'anulado'` **sigue visible**, muestra el distintivo `Anulado` y **ningún** importe (FR-019a, D9) — debe fallar
- [X] T022 [US1] Ampliar `FE/modules/orders/pages/order-detail.component.spec.ts` con el **bloque de resumen**: con `billing` de `state: 'factura_propia'`, subtotal `28000`, discount `4000`, `discount_label: '2 x $12.000'`, delivery_fee `0` y total `24000`, el `app-bill-summary` recibe los cuatro valores y la fila de descuento dice `2 x $12.000`; con `discount_label: null` y `discount > 0`, dice `Descuento` (FR-009); con `discount: '0'`, **no** hay fila de descuento; con `delivery_fee: '3000'`, la fila de envío aparece rotulada exactamente `Domicilio` (el default del componente, FR-005/FR-007); y con `delivery_fee: '0'`, **no** hay fila de envío (FR-006, FR-007, RN-004); y con `billing` **ausente** en la respuesta, **ni el resumen ni los importes por línea** se renderizan, sin pintar ningún `$ 0` ni `undefined`, y el resto de la pantalla sigue funcionando (D15) — debe fallar
- [X] T023 [US1] Ampliar `FE/modules/orders/pages/order-detail.component.spec.ts` con los **tres avisos literales** del contrato de pantalla §4, comparando el texto **exacto** (no un fragmento): `state: 'factura_agrupada'` ⇒ `Este pedido se cobró junto con otros en una cuenta unificada; el total facturado está en Ventas`; `state: 'sin_factura'` con `status: 'abierta'` ⇒ `El descuento se calcula al cobrar; este total aún puede cambiar`; `state: 'sin_factura'` con `status: 'cancelada'` ⇒ **ninguno** de los dos avisos, y el desglose sí se muestra con la etiqueta `Cancelada` (D7, US1 §5); un pedido `cancelada` cuya mesa se cerró con factura llega del servidor como `sin_factura` (G4b) y por tanto tampoco muestra el aviso de cuenta unificada; `state: 'factura_propia'` ⇒ ningún aviso — debe fallar

### Implementation for User Story 1 — frontend

- [X] T024 [US1] En `FE/modules/orders/pages/order-detail.component.ts`, reemplazar `tableLabel()` (líneas 138–142) por `encabezado()`: devuelve la etiqueta de la mesa cuando `order.dining_table_id` no es nulo (misma resolución contra `tableService.tables()` que hoy) y, si no, `orderTypeLabel(order.order_type)` importado de `../order-status.util` (línea 8 ya importa de ese módulo); añadir `rotuloEncabezado()` que devuelve `'Mesa'` u `'Tipo de pedido'` según el mismo criterio, y usarlo en la línea 50 de la plantilla en lugar del literal `Mesa`. Se pregunta por `dining_table_id` y **no** por `order_type === 'DINE_IN'` porque hay pedidos históricos con mesa y `order_type` nulo (D13); hace pasar T020
- [X] T025 [US1] En `FE/modules/orders/pages/order-detail.component.ts`, añadir los importes por línea dentro del `@for` de ítems (líneas 83–100): importar `MoneyPipe` de `FE/shared/money.pipe.ts` y añadirlo a `imports` (línea 15), importar `lineTotalGross` de `../../tables/interfaces/dining.interface` —**el auxiliar que ya existe**, que lee `line_total` y cae a `unit_price × quantity + addons_total`: no se escribe ningún cálculo de importe nuevo (decisión de diseño 1, FR-002, FR-003)— y pintar `unit_price` y el importe de la línea con `| money`; cuando `addons_total > 0`, mostrar el monto de adicionales para que `unitario × cantidad` no parezca contradecir el importe (FR-004); y para un ítem con `estado_cocina === 'anulado'`, pintar `kitchenStatusLabel('anulado')` con `kitchenStatusClass` (importados de `../order-status.util`) **en lugar** del importe, manteniendo la línea visible (FR-019a, D9). **Nunca** leer `discounted_unit_price` ni `discounted_line_total` (Q5); hace pasar T021
- [X] T026 [US1] En `FE/modules/orders/pages/order-detail.component.ts`, pintar el bloque de resumen con el componente compartido: importar `BillSummaryComponent` de `../../tables/components/bill-summary.component` y añadirlo a `imports`, y renderizarlo tras la lista de ítems **solo si** `order()!.billing` viene en la respuesta (D15), pasando `[subtotal]`, `[discount]`, `[deliveryFee]`, `[total]` convertidos con `Number` (convención del archivo) y `[discountLabel]` con `billing.discount_label ?? 'Descuento'`. **No** se pasa `[deliveryFeeLabel]`: la fila de envío conserva a propósito su default `Domicilio`, la misma palabra de las cuatro pantallas de cobro (FR-005, FR-007). El componente **no calcula nada**: los cuatro importes llegan resueltos del servidor, y el condicionado de las filas de descuento y envío ya lo hace él (FR-006, FR-007, D10); hace pasar la parte de resumen de T022
- [X] T027 [US1] En `FE/modules/orders/pages/order-detail.component.ts`, añadir los **tres avisos** con los textos literales del contrato de pantalla §4, como constantes del archivo para que no se puedan parafrasear al editar la plantilla: el de factura agrupada cuando `billing.state === 'factura_agrupada'`; el de pedido sin cobrar cuando `billing.state === 'sin_factura'` **y** `order.status !== 'cancelada'` (D7 — aplicar aquí la respuesta de T007: si el negocio prefiere mostrarlo igual, se quita esa segunda condición); y el de falta de detalle cuando `billing.sin_detalle_de_precios === true`. Los dos primeros son excluyentes entre sí; el tercero puede acompañar a cualquiera; hace pasar T023

### Verification for User Story 1

- [X] T028 [US1] Recorrer `SPEC/quickstart.md` §2 con `curl` + `jq` sobre los pedidos de T006: los tres `state` esperados, `billing: null` en el listado, y los dos `cuadra_subtotal` / `cuadra_total` en `true` en **todos** los pedidos de la lista de prerrequisitos (G1, G2, SC-007); pegar las salidas en `SPEC/implementation-notes.md` → "Verificación automática"
- [X] T029 [US1] Recorrer `SPEC/quickstart.md` §3 (las diez filas de la tabla) en el navegador y registrar en `SPEC/implementation-notes.md` → "Verificación manual": el resultado de cada fila, el cronómetro de **SC-001** (< 10 s para responder "por cuánto se cobró y por qué" **sin** abrir otra pantalla, medido sobre la fila 7), la comparación con el módulo de Ventas de la fila 7 (**SC-002**, abriendo Ventas en otra pestaña) y la suma a mano de **SC-007** en los pedidos con promoción, con ítem anulado, con adicional por línea y con combo

**Checkpoint**: US1 completa y entregable sola. El cajero ya responde "por cuánto se cobró esto y por qué" sin ir a Ventas, que es el motivo de ser de la spec.

---

## Phase 4: User Story 2 — Despachar un domicilio copiando los datos de entrega (Priority: P1)

**Goal**: en un pedido a domicilio, un bloque "Datos de entrega" con los cuatro campos y una acción "Copiar datos" que deja en el portapapeles un texto plano listo para pegar en el chat del mensajero.

**Independent Test**: abrir el detalle de un domicilio diligenciado, pulsar "Copiar datos" y pegar en cualquier editor: aparece el texto formateado y la pantalla mostró la confirmación (`SPEC/quickstart.md` §4). **No depende del backend ni de la Fase 2**: los cuatro campos ya viajan en la respuesta actual, así que esta historia se puede entregar antes que US1 si conviene.

### Tests for User Story 2

- [X] T030 [US2] Ampliar `FE/modules/orders/pages/order-detail.component.spec.ts` con el **bloque de entrega** (D14): con `order_type: 'DELIVERY'` y los cuatro campos poblados, el bloque `Datos de entrega` aparece con sus cuatro etiquetas y valores; con `'TAKEAWAY'` y con `'DINE_IN'`, el bloque **no** aparece (FR-015); con `'DELIVERY'` y solo `delivery_address` + `delivery_phone`, el bloque aparece con esas dos filas y **sin** etiqueta huérfana, línea en blanco, guion de relleno ni la palabra `null` para las otras dos (FR-015a, FR-020, RN-003); con `'DELIVERY'` y los cuatro campos vacíos, el bloque aparece y el botón de copiar está **deshabilitado** — debe fallar
- [X] T031 [US2] Ampliar `FE/modules/orders/pages/order-detail.component.spec.ts` con el **copiado** (D11, D12): sustituyendo `navigator.clipboard.writeText` por un doble de Vitest, pulsar el botón y verificar que el texto recibido es **exactamente** `Cliente: …\nTeléfono: …\nDirección: …\nNotas: …`, en ese orden, sin importes ni identificador del pedido; con solo dirección y teléfono, el texto tiene **exactamente dos líneas** (US2 §4); tras el éxito, el `ToastService` recibe el literal `Datos de envío copiados al portapapeles` (FR-017); con el doble rechazando la promesa (portapapeles no disponible), el toast de error recibe `No se pudieron copiar los datos`, no se lanza ninguna excepción al llamador y el bloque **sigue renderizado** con sus datos (US2 §5) — debe fallar

### Implementation for User Story 2

- [X] T032 [US2] En `FE/modules/orders/pages/order-detail.component.ts`, añadir `camposDeEntrega()`: devuelve la lista de pares `[etiqueta, valor]` en el orden `Cliente`, `Teléfono`, `Dirección`, `Notas` (orígenes de Q1: `customer_name`, `delivery_phone`, `delivery_address`, `notes`), filtrando los vacíos con `valor?.trim()`. Es **una sola** función para la tarjeta visible y para el texto copiado, de modo que no puedan divergir: un campo que se ve es un campo que se copia (D12); hace pasar la parte de omisión de T030
- [X] T033 [US2] En `FE/modules/orders/pages/order-detail.component.ts`, renderizar el bloque `Datos de entrega` **si y solo si** `order()!.order_type === 'DELIVERY'` (D14 — la condición es del tipo de pedido, no de que los campos estén llenos), recorriendo `camposDeEntrega()` con `@for`, con el botón `Copiar datos` junto al encabezado del bloque (FR-016) y `[disabled]="camposDeEntrega().length === 0"`; hace pasar T030
- [X] T034 [US2] En `FE/modules/orders/pages/order-detail.component.ts`, añadir `copiarDatosDeEntrega()` con el patrón ya probado en `FE/modules/tables/pages/checkout/transfer-details-step.component.ts:407-416`: construir el texto uniendo `camposDeEntrega()` con `": "` y `"\n"`, `await navigator.clipboard.writeText(texto)` dentro de un `try`, `toast.success('Datos de envío copiados al portapapeles')` en el camino feliz y `toast.error('No se pudieron copiar los datos')` en el `catch`, inyectando el `ToastService` de `FE/shared/feedback/toast.service.ts`. **No** extraer el patrón a un helper compartido (D11, Principio V); hace pasar T031

### Verification for User Story 2

- [X] T035 [US2] Recorrer `SPEC/quickstart.md` §4 (pasos 1–5) en el navegador, incluido el paso 5 en un contexto **sin portapapeles disponible** (abrir la app por `http://` en LAN, no `localhost`), y registrar en `SPEC/implementation-notes.md` → "Verificación manual" el texto realmente pegado en los pasos 2 y 4 y el comportamiento tras el fallo del paso 5 (**SC-003**: una sola acción, cero transcripción manual)

**Checkpoint**: US1 y US2 funcionan de forma independiente. El cajero ya despacha un domicilio sin transcribir un teléfono a mano.

---

## Phase 5: User Story 3 — Leer el pedido sin tropezar con huecos de datos (Priority: P2)

**Goal**: la pantalla dice con claridad qué información no tiene, en vez de mostrar ceros, guiones o "undefined".

**Independent Test**: abrir un pedido cuyas líneas no anuladas sumen $ 0 y verificar que se muestra el Total junto al aviso correspondiente, sin ningún importe inventado; y abrir un pedido corriente sin promoción y verificar que el aviso **no** aparece (`SPEC/quickstart.md` §5).

**Nota**: la mitad de backend de esta historia ya la cubren T016 (garantía G6, con sus tres contra-casos) y T018 (el cálculo de `sin_detalle_de_precios`), porque la condición de FR-018 se resuelve en el servidor (D8). Lo que falta aquí es la **presentación** de ese estado y la auditoría de nulos de toda la pantalla.

### Tests for User Story 3

- [X] T036 [US3] Ampliar `FE/modules/orders/pages/order-detail.component.spec.ts`: con `billing.sin_detalle_de_precios: true`, el render contiene el Total, el aviso literal `Esta orden no tiene el detalle de precios por ítem` y **ningún** importe por línea —tampoco en `$ 0`— (US3 §1); con `false` en un pedido corriente, el aviso **no** aparece y los importes por línea sí (US3 §2); con **todas** las líneas en `estado_cocina: 'anulado'`, `subtotal` y `total` en `'0'` y `sin_detalle_de_precios: false`, se ven las líneas marcadas como anuladas, el resumen dice `$ 0` y el aviso **no** aparece —el `$ 0` es el valor real, no un hueco— y la lista **no** queda vacía (US3 §3); y con `customer_name: null`, `notes: null`, `delivery_address: null` y un ítem sin `notes` ni `options`, el `textContent` completo de la pantalla **no** contiene `null`, `undefined` ni un guion de relleno en ninguna parte (US3 §4, FR-020, RN-003) — debe fallar
- [X] T037 [US3] En `FE/modules/orders/pages/order-detail.component.ts`, condicionar los importes por línea de T025 a `!order()!.billing?.sin_detalle_de_precios` (los importes **se omiten**, no se pintan en `$ 0`, FR-018) manteniendo visible el resumen con su Total; y auditar las demás ramas de la plantilla para que ningún campo opcional vacío se renderice —revisar en particular los bloques de `notes` (líneas 72–78), `customer_name` (línea 61) y `optionLabels()` (que ya devuelve `''` cuando no hay opciones)— sin introducir ningún valor por defecto ni guion (RN-003, RN-005); hace pasar T036

### Verification for User Story 3

- [X] T038 [US3] Recorrer `SPEC/quickstart.md` §5 (pasos 1–4) y registrar en `SPEC/implementation-notes.md` → "Verificación manual" el recorrido de los **20 pedidos del histórico** (**SC-004**: cero `null`, cero `undefined`, cero guiones de relleno y cero `$ 0` inventados), nombrando los pedidos revisados. Para fabricar el caso del paso 1, poner a `0` el `unit_price` y el `addons_total` de las líneas de un pedido marcado `[094-test]` — **nunca** en datos reales

**Checkpoint**: el histórico se lee sin datos falsos. Las tres historias de contenido están completas.

---

## Phase 6: User Story 4 — Llamar al cliente "Cliente" (Priority: P3)

**Goal**: el nombre de la persona del pedido aparece bajo la etiqueta "Cliente", correcta para los tres tipos de pedido.

**Independent Test**: abrir un pedido de mesa, uno para llevar y uno a domicilio y verificar que en los tres la etiqueta dice "Cliente" (`SPEC/quickstart.md` §6). **No depende del backend ni de la Fase 2**: es un cambio de una línea y se puede entregar en cualquier momento.

### Tests for User Story 4

- [X] T039 [US4] Ampliar `FE/modules/orders/pages/order-detail.component.spec.ts` con un caso que verifique, en los tres `order_type`, que el `textContent` de la pantalla contiene la etiqueta `Cliente` y **no** contiene la palabra `Comensal` en ninguna parte (FR-013, SC-005) — debe fallar

### Implementation for User Story 4

- [X] T040 [US4] En `FE/modules/orders/pages/order-detail.component.ts`, sustituir el literal `Comensal` de la línea 61 por `Cliente`. Es un cambio de **una línea**: la etiqueta aparece una sola vez en la pantalla y el listado de órdenes no la usa (hallazgo del reconocimiento), así que no hay barrido que hacer; hace pasar T039

### Verification for User Story 4

- [X] T041 [US4] Recorrer `SPEC/quickstart.md` §6: abrir un pedido de mesa, uno para llevar y uno a domicilio y buscar "Comensal" con `Ctrl+F` en los tres ⇒ cero resultados; confirmar además con `grep -rn "Comensal" ../pos-heladeria/src/app/modules/orders/` que no queda en el módulo (**SC-005**) y anotarlo en `SPEC/implementation-notes.md`

**Checkpoint**: las cuatro historias completas.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Propósito**: suites completas, aislamiento, no-regresión fuera de la pantalla y cierre documental.

- [X] T042 Ejecutar la suite **entera** de backend (`env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'` en `../pos-backend`) y confirmarla en verde contra la línea base de T005; anotar el conteo final en `SPEC/implementation-notes.md` → "Verificación automática"
- [X] T043 Ejecutar `npm test` completo en `../pos-heladeria` y confirmar que los fallos **no aumentan** respecto a la línea base de T004, nombrando uno por uno los que quedan y por qué son preexistentes; anotarlo en `SPEC/implementation-notes.md`
- [X] T044 [P] Añadir a `BE/characterization_tests/test_orders_billing_summary.py` la verificación **automática** de aislamiento de D17: `get_order` con un `order_id` que no existe responde `404` con `{"detail": "Order not found"}` y un cuerpo que no revela nada del pedido, **idéntico** al de un pedido de otro esquema. Es una prueba de **regresión** del comportamiento actual de `_load_order` (`router.py:47-64`), no de comportamiento nuevo: por eso se escribe aquí y no antes de una implementación que no existe (FR-025, RN-006)
- [X] T045 [P] Recorrer `SPEC/quickstart.md` §7 (los cuatro pasos) con **dos tenants reales** en navegadores distintos y registrar en `SPEC/implementation-notes.md` → "Aislamiento (SC-006)" que el acceso cruzado responde "no encontrado" por interfaz y por API, y que la respuesta del paso 3 es **idéntica** a la del paso 4 (id inexistente). La suite corre sobre SQLite sin esquemas por tenant, así que esta parte **no se puede automatizar** y queda explícita en vez de fingida (D17)
- [X] T046 [P] No-regresión de `SPEC/quickstart.md` §8: abrir una mesa con pedidos y cobrar normalmente en la **terminal de mesas** ⇒ totales y flujo idénticos; revisar que la fila de descuento sigue diciendo "Descuento" en las **cuatro** pantallas que consumen `BillSummaryComponent` (`pos-checkout-panel`, `payment-attempt-review-panel`, `manual-order-page`, `session-bill-panel`); el **listado de Órdenes** con su paginación, filtros y columnas sin cambios y con `billing` en `null`; el **módulo de Ventas** sin cambios
- [X] T047 [P] Verificar el **despliegue desacoplado** (D15, quickstart.md §8): apuntar el frontend nuevo a un backend sin el cambio desplegado (o interceptar la respuesta quitando `billing`) y confirmar que el Detalle de Orden carga, muestra ítems, encabezado y datos de entrega, y **no** pinta el bloque de resumen ni importes por línea, sin ningún `$ 0` ni `undefined`
- [X] T048 [P] Auditoría de las prohibiciones del contrato de pantalla §6 con `grep` sobre `../pos-heladeria/src/app/modules/orders/pages/order-detail.component.ts`: **cero** apariciones de `discounted_unit_price` y `discounted_line_total` (Q5), **cero** de `order.discount` y `order.applied_promotions` —la pantalla lee **solo** `billing` (D16)—, **cero** de `Comensal` y `Mostrador`, y ninguna aritmética de importes en el componente (no suma líneas, no resta descuentos, no bifurca entre factura y pedido: FR-024b, RN-001); anotar los resultados en `SPEC/implementation-notes.md`
- [X] T049 [P] Registrar en `specs/000-reconocimiento/registro-de-anomalias.md` el desenlace de los puntos de confirmación: la respuesta del negocio a **D2**, **D2-bis** (pedido cancelado en mesa cobrada) y **D7** de T007 (como ampliación de A-105 y A-106 si confirman lo diseñado, o como anomalía nueva si deciden otra cosa) y, **solo si** T008 encontró ventas con `tax`/`tip` > 0, la anomalía nueva de **D5** con lo que se decidió mostrar en esos pedidos
- [X] T050 Cerrar `SPEC/implementation-notes.md` con la lista de cierre de `SPEC/quickstart.md` §9 (SC-001 a SC-007, cada uno con dónde se verificó y con qué resultado real) y añadir la sección "Limitaciones" con lo que queda vivo por decisión: la nota del pedido sirviendo a dos propósitos (Q1), el texto de FR-024a aplicado al cierre dividido (D2), `tax`/`tip` sin fila propia (D5) y el patrón de portapapeles duplicado en dos componentes (D11) — cada uno candidato a spec propia, no deuda silenciosa
- [X] T051 [P] Limpiar o dejar marcados con `[094-test]` los datos creados para la verificación en la base de datos de desarrollo (los diez pedidos de T006 y el pedido de importes en `0` de T038), según `SPEC/quickstart.md` §9
- [X] T052 **Solo si el usuario lo pide** (Principio XV): confirmar en commits pequeños, en inglés, Conventional Commits y **sin ninguna marca de autoría de IA**, con esta agrupación sugerida — en `pos-backend`: (1) `test` armador `make_sale` en los fixtures; (2) `feat` esquemas `AppliedPromotionOut` y `OrderBillingSummary` + tres campos de `OrderResponse`; (3) `feat` `build_billing_summary` en el servicio; (4) `feat` el detalle asigna `billing` en `_load_order`; (5) `test` garantías G1–G9 y el 404 de aislamiento. En `pos-heladeria`: (6) `feat` input `discountLabel` del resumen compartido + su spec; (7) `feat` interfaces `OrderBilling` y `AppliedPromotion`; (8) `feat` encabezado por tipo de pedido e importes por línea (US1); (9) `feat` bloque de resumen y los tres avisos (US1); (10) `feat` datos de entrega y copiado (US2); (11) `fix` omisión de importes sin detalle y auditoría de nulos (US3); (12) `feat` etiqueta "Cliente" (US4). En `pos-specs`: (13) `docs` tasks, notas de implementación y el registro de anomalías

---

## Dependencies & Execution Order

### Dependencias de fase

- **Fase 1 (Setup)**: sin dependencias — empieza de inmediato. T001 y T002 (ramas) van **antes** de cualquier cambio de código (Principio XIV).
- **Fase 2 (Foundational)**: depende de T001 y T002. **T008 es una compuerta**: si encuentra ventas con `tax`/`tip` > 0, el resumen no se implementa hasta que el negocio decida. **Bloquea US1 y US3**; **no** bloquea US2 ni US4.
- **Fase 3 (US1)**: depende de la Fase 2 completa. Dentro de ella, el backend (T015–T019) y el frontend (T020–T027) pueden ir en paralelo con dos personas, porque el frontend se prueba contra respuestas simuladas en el `HttpTestingController`; T028 y T029 necesitan los dos lados desplegados.
- **Fase 4 (US2)**: depende **solo** de T002 y de que exista el archivo de notas. Técnicamente podría ir primero, pero **comparte archivo** con US1 (`order-detail.component.ts` y su spec), así que con un solo desarrollador va después de US1 para no resolver conflictos consigo mismo.
- **Fase 5 (US3)**: depende de T025 y T026 (hay que tener importes por línea para poder omitirlos) y de T018 (el servidor debe calcular `sin_detalle_de_precios`).
- **Fase 6 (US4)**: depende solo de T002. Es el cambio de menor riesgo de la spec y se puede entregar en cualquier momento.
- **Fase 7 (Polish)**: depende de todas las fases que se decidan entregar. T049 depende de la respuesta de T007 (y de T008 si encontró filas).

### Dependencias entre historias

- **US1 (P1)**: independiente. Entrega valor sola y resuelve 9 de los 14 criterios del brief; es la única que toca el backend.
- **US2 (P1)**: independiente de US1 y del backend — los cuatro campos de entrega ya viajan en la respuesta actual. Entregada sola, ya quita la transcripción manual aunque los importes sigan sin mostrarse.
- **US3 (P2)**: **depende de US1**. No añade una tarea nueva: protege el valor de US1 en el histórico. Sin importes por línea no hay nada que omitir.
- **US4 (P3)**: independiente de todo. Una línea de plantilla y su test.

### Dentro de cada historia

- Los tests se escriben **primero** y deben fallar antes de implementar. Hay **dos** excepciones razonadas, las dos guardias de regresión: T017 (conteo constante de SQL y `billing: null` en el listado, verde desde T010 por construcción) y T044 (el `404` de aislamiento, comportamiento ya existente, D17, y por eso vive en Polish). Una guardia que empieza en verde es legítima si está declarada como tal y se vuelve a ejecutar después de la implementación; lo que no es legítimo es un test de comportamiento nuevo que pasa de entrada.
- Backend antes de frontend en la ruta de datos; esquemas antes del servicio; servicio antes del router.
- En el frontend: la función que compone los datos antes de la plantilla que los pinta (T032 antes de T033), y la plantilla antes de la verificación manual.

### Oportunidades de paralelismo

- Fase 1: T002 ∥ T003 ∥ T004 ∥ T005 ∥ T006 ∥ T007 tras T001.
- Fase 2: T009 ∥ T010 ∥ T011 ∥ T012 (cuatro archivos distintos, dos repositorios); T013 depende de T012 y T014 de T013. T008 va primero: es la compuerta.
- Fase 3: con dos personas, el bloque de backend (T015→T019) y el de frontend (T020→T027) en paralelo; dentro de cada bloque las tareas son secuenciales porque comparten archivo.
- Fase 7: T044 ∥ T045 ∥ T046 ∥ T047 ∥ T048 ∥ T051.
- Con varios desarrolladores: tras la Fase 1, una persona puede tomar US2 y US4 completas (frontend puro, sin dependencia de la Fase 2) mientras otra hace la compuerta, la Fase 2 y US1.

---

## Parallel Example: Fase 2 (Foundational)

```bash
# Tras la compuerta T008, cuatro archivos distintos en dos repositorios:
Tarea: "T009 armador make_sale en BE/characterization_tests/orders_fixtures.py"
Tarea: "T010 esquemas OrderBillingSummary y AppliedPromotionOut en BE/api/v1/orders/schemas.py"
Tarea: "T011 interfaces OrderBilling y AppliedPromotion en FE/modules/tables/interfaces/dining.interface.ts"
Tarea: "T012 tests del input discountLabel en FE/modules/tables/components/bill-summary.component.spec.ts"
```

## Parallel Example: Fase 3 (US1) con dos desarrolladores

```bash
# Dos cadenas independientes que se juntan en la verificación:
Cadena A (backend):  T015 → T016 → T017 → T018 → T019
Cadena B (frontend): T020 → T021 → T022 → T023 → T024 → T025 → T026 → T027
Juntas en:           T028 (contrato por curl) y T029 (recorrido de las diez filas)
```

---

## Implementation Strategy

### MVP primero (solo US1)

1. Fase 1 (Setup) — ramas, notas, líneas base y datos de prueba.
2. Fase 2 (Foundational) — **la compuerta T008 va primero**; luego los tipos y el input compartido.
3. Fase 3 (US1) — desglose por línea, resumen, avisos y encabezado.
4. **PARAR Y VALIDAR**: `SPEC/quickstart.md` §2 y §3. El cajero ya responde "por cuánto se cobró y por qué" sin salir de la pantalla.
5. Desplegable aquí: elimina el salto a Ventas para el 100 % de los pedidos y resuelve 9 de los 14 criterios del brief, sin haber tocado el bloque de entrega ni la etiqueta.

### Entrega incremental

1. Setup + Foundational → base lista y compuerta pasada.
2. + US1 → validar → desplegar (**MVP**). El backend y el frontend se pueden desplegar en cualquier orden: el contrato es aditivo y la pantalla tolera su ausencia (D15).
3. + US2 → validar → desplegar (el cajero despacha un domicilio con una sola acción).
4. + US3 → recorrer los 20 pedidos del histórico → desplegar con SC-004 registrado.
5. + US4 → desplegar (una línea).
6. Fase 7 → aislamiento, no-regresión, cierre documental y limpieza de datos de prueba.

Cada incremento suma valor sin romper el anterior, y ninguno exige desplegar los dos repositorios a la vez.

### Si hay que recortar alcance

- **US4 es la primera candidata a posponer** por valor, pero cuesta una línea: posponerla no ahorra nada y deja SC-005 sin cumplir. Recortarla es peor negocio que hacerla.
- **US3 no se puede recortar**: sin ella, US1 pinta importes sin decir cuándo faltan, que es exactamente el `$ 0` inventado que RN-005 prohíbe. Es la red de seguridad de US1 en el histórico, no un adorno.
- **US2 sí es separable por completo**: no comparte ni backend ni datos con las demás. Si el tiempo aprieta, se entrega en una segunda tanda sin tocar nada de lo ya desplegado.
- **Lo que no se puede recortar nunca**: la compuerta T008 y el recorrido de aislamiento T045. El primero evita publicar una aritmética que no cuadra; el segundo es el único sitio donde SC-006 se verifica de verdad, porque la suite automática no puede abarcar dos esquemas.

---

## Notes

- `[P]` = archivos distintos, sin dependencia pendiente.
- `[Story]` mapea cada tarea a su historia para trazabilidad (Principio XII).
- Los tests se verifican **en rojo** antes de implementar; un test que pasa de entrada no está probando lo que cree. Las dos guardias declaradas (T017, T044) son la excepción: prueban que algo **no** cambie, así que su verde inicial es el punto de referencia.
- Los **cuatro textos literales** de la pantalla (FR-017, FR-018, FR-023, FR-024a) no son parafraseables: los tests los comparan completos, no por fragmento, justamente para que una edición descuidada de la plantilla los rompa en rojo.
- Ninguna tarea crea una columna, una migración, una dependencia o una escritura. Si alguna parece necesitarlo, es señal de que se salió del alcance (research.md D18).
- La pantalla **no calcula**: si en algún momento aparece una suma de importes en `order-detail.component.ts`, es una violación de FR-024b y RN-001, no una optimización. T048 lo vigila con `grep`.
- Evitar: calcular `billing` en el listado (D3, N+1 que la guardia de T017 atrapa), leer `discounted_*` por línea (Q5), ocultar los ítems anulados (Q7), deducir el caso de facturación en el navegador (FR-024b), y rellenar con ceros lo que falta (RN-005).
