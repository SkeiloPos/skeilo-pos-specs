# Investigación — Spec 117

**Fecha**: 2026-10-13 · **Spec**: [spec.md](./spec.md)

Toda decisión de esta fase se contrastó contra el código real de `pos-backend` y
`pos-heladeria` (ambos en `develop`, árbol limpio), no contra una lectura de las specs
065/089 en abstracto.

## D1 — Reutilizar `per_line` (spec 089) para grupos "Por cantidad", en todo canal

**Hallazgo clave**: el mecanismo que esta spec necesita **ya existe** desde la spec 089, pero
atado al eje equivocado. `catalog_engine/core.py` (`compute_unit_price`, `compute_addons_total`,
`line_total`) y `catalog_engine/consumption.py::plan_line_consumption` ya implementan exactamente
la fórmula de `FR-002`/`FR-007` (adición no multiplicada por cantidad de producto) para toda
`ChosenOption` con `per_line = True`. Hoy esa marca solo se activa en `cart/service.py` (Menú QR),
y solo para opciones de grupos con `pricing_type = 'con_recargo'` (spec 089, research D1), bajo la
bandera `QR_ADDONS_PER_LINE` — es decir, está atada a `pricing_type` (spec 063) y al canal QR, no a
`selection_mode` (spec 065).

**Decisión**: `per_line` pasa a activarse por la unión de dos condiciones independientes:

```
per_line = (existe_regla_089: canal == carrito_QR AND group.pricing_type == 'con_recargo'
            AND settings.QR_ADDONS_PER_LINE)
           OR (regla_nueva_117: group.selection_mode == 'cantidad')
```

La regla de 089 no se toca (ningún grupo "conteo" cambia de resultado por esta spec, `FR-013`). La
regla nueva se evalúa en **todo** canal que construye `ChosenOption` con opciones ya validadas:
`cart/service.py` (`add_item`, `update_item`), `orders/consolidation.py::add_item_to_order`
(mesero), `orders/service.py::create_order` (alta directa de comanda), `sales/service.py::checkout`
(venta de mostrador) y `orders/kitchen.py` (reemplazo al anular un ítem). Estos 4 últimos hoy
llaman `compute_line_price` "folded" (sin separar `unit_price`/`addons_total`); pasan a llamar
`compute_unit_price` + `compute_addons_total` por separado, igual que ya hace `cart/service.py`.

**Por qué no tocar `catalog_engine/core.py` ni `consumption.py`**: ya implementan la fórmula
correcta para `per_line = True`. Tocarlos sería reimplementar algo que ya existe y ya tiene
characterization tests — el cambio real está en **quién** recibe la marca `True`, no en qué hace
el motor con ella.

**Alternativas descartadas**:
- Añadir un campo nuevo (`is_quantity_total` o similar) en paralelo a `per_line`: duplicaría el
  mismo booleano con otro nombre y obligaría a tocar `core.py`/`consumption.py` para que miren dos
  campos en vez de uno — exactamente el refactor innecesario que el Principio V prohíbe.
- Derivar `per_line` de `pricing_type` en vez de `selection_mode`: ya es lo que hace hoy la regla
  089, y es precisamente la confusión de ejes que esta spec corrige (ver `spec.md` encabezado:
  "reabre, exclusivamente para grupos... en modo Por cantidad").

## D2 — Escalar los topes del grupo por la cantidad de producto (FR-004)

`validate_option_selection(db, variant, options)`
(`app/catalog_engine/pricing.py:105-107`) valida hoy `max_quantity_per_option` y
`max_total_quantity` como topes **fijos**, sin conocer la cantidad de producto de la línea. Su
única llamadora, `load_valid_options`, sí puede recibirla porque los 6 call-sites que la invocan
(`cart/service.py::add_item` y `::update_item`, `orders/service.py::create_order`,
`orders/checkout.py::compute_draft_preview`, `sales/service.py::checkout`,
`orders/consolidation.py::add_item_to_order`) ya tienen la cantidad de producto en el mismo scope
(es el mismo valor que usan para `compute_line_price`/`line_total`).

**Decisión**: `validate_option_selection` y `load_valid_options` ganan un parámetro
`quantity: int = 1`. Dentro de la función, para un grupo con `selection_mode == 'cantidad'`, ambos
topes se comparan ya multiplicados: `max_quantity_per_option_escalado = max_quantity_per_option ×
quantity` y `max_total_quantity_escalado = max_total_quantity × quantity`. El valor por defecto
`1` hace que todo llamador que no pase `quantity` explícitamente conserve el comportamiento actual
(tope fijo) — relevante solo para los tests que invocan la función aislada, no para ningún camino
de producción (los 6 call-sites sí pasan la cantidad real).

**Ambos topes se escalan, no solo el "por opción"**: `FR-004` y "Key Entities" solo nombran
expresamente `max_quantity_per_option`, pero el Escenario de Aceptación 2 de la Historia 3 ("una
línea con dos adiciones distintas... sobre un límite total del grupo que, tras reducir la cantidad
de producto, queda por debajo de esa suma") únicamente tiene sentido si `max_total_quantity`
también se escala — si no lo hiciera, reducir la cantidad de producto nunca podría dejar a la suma
de adiciones "por debajo" de un límite total que no cambió. Se resuelve escalando los dos topes de
la misma manera; no es una decisión de negocio distinta de la ya tomada en `FR-004` (ambos
expresan "cuánto permite el grupo por cada unidad de producto de la línea"), y la propia sección
"Assumptions" de la spec deja explícitamente este nivel de detalle a la fase de planeación.

**Consecuencia sobre comportamiento ya congelado**: hoy, crear una línea con cantidad de producto 2
y una adición "cantidad" de valor 3 contra un tope fijo de 2 es rechazada (422). Tras esta spec,
pasa (tope escalado 2×2=4 ≥ 3) — es exactamente el comportamiento que pide la Historia 1 y que
`FR-004` autoriza explícitamente. Los characterization tests que congelan el tope **sin escalar**
(`test_catalog_option_groups_selection_mode.py`) se actualizan citando la decisión de negocio
correspondiente (ver sección final de este documento).

## D3 — Dónde existe realmente "reducir la cantidad de producto de una línea existente"

Antes de diseñar el ajuste automático (Historia 3) se verificó, por código, **en qué canal es
posible hoy** reducir la cantidad de una línea que ya tiene adiciones elegidas:

- **`cart/service.py::update_item`** (`app/api/v1/cart/service.py:426-475`, carrito QR del
  comensal, antes de enviar a cocina): `CartItemUpdate.quantity` y `.options` son independientes.
  Si el PATCH solo trae `quantity` (sin `options`), el código actual (líneas 441-446) **no
  revalida las opciones en absoluto** — ni siquiera contra el tope fijo de hoy. Este es
  exactamente el hueco que la Historia 3 cierra. `dining-cart.service.ts::setQuantity` (frontend)
  ya llama a este mismo endpoint enviando solo `quantity`.
- **Terminal POS / pedido manual** (`pos-terminal.store.ts::incDraft`/`decDraft`): operan
  exclusivamente sobre `draftLines` (señal en memoria del navegador); una línea ya enviada no
  expone esos controles (`pos-order-panel.component.ts` los oculta fuera de `kind === 'draft'`).
  No hay ninguna petición al backend hasta `saveOrder()`. El ajuste de la Historia 3 en este canal
  es **enteramente responsabilidad del frontend**, antes de que la línea exista en el backend.
- **Modal de selección (`product-select.component.ts`)**: la cantidad de producto y la selección
  de adiciones conviven en la misma pantalla, antes de agregar al carrito — también 100%
  frontend.
- **No existe ningún endpoint para cambiar la `quantity` de un `OrderItem` ya enviado a cocina**
  (confirmado revisando `orders/service.py`, `orders/kitchen.py`, `orders/consolidation.py`,
  `table_sessions/service.py` y el router completo): el único `PATCH` sobre un ítem
  (`/items/{item_id}/kitchen`) solo mueve su estado de preparación, nunca la cantidad.

**Decisión de alcance**: la Historia 3 se implementa en exactamente dos lugares, consistentes con
dónde el sistema permite hoy reducir la cantidad de una línea con adiciones ya elegidas:
1. Backend: `cart/service.py::update_item`, cuando el PATCH trae `quantity` (con o sin `options`).
2. Frontend: `product-select.component.ts` (modal, antes de agregar) y
   `pos-terminal.store.ts::decDraft` (línea draft de Terminal/pedido manual) — puramente
   client-side, replicando el mismo criterio (D4) sin tocar el backend.

## D4 — Criterio determinista de reducción cuando compiten varias adiciones (FR-006)

La propia spec (sección "Assumptions") deja este criterio a la fase de planeación: no es una
decisión de negocio, solo exige que sea determinista y reproducible.

**Decisión**: orden alfabético **descendente** por el nombre de la opción (`Option.name`), con
`option_id` como desempate final ante nombres idénticos. Se reduce de una unidad a la vez la
primera opción de ese orden — respetando primero su propio tope individual escalado (D2) y
after eso el tope total escalado del grupo — y solo se avanza a la siguiente opción del orden
cuando la anterior llega a 0 o ya no hace falta seguir reduciendo.

**Alternativas consideradas y descartadas**:
- *Orden de inserción/fila* (`id` de `CartItemOption`/`OrderItemOption`): ambas tablas usan
  `UUIDPrimaryKeyMixin` (`uuid.uuid4()`, aleatorio) — no refleja ningún orden de creación ni de
  modificación; usarlo como criterio sería tan arbitrario como no tener criterio.
- *Marca de tiempo de última modificación*: exigiría añadir una columna nueva (`updated_at`) solo
  para resolver un criterio que la spec explícitamente clasifica como técnico y sin efecto de
  negocio — abrir una migración de Alembic para esto sería una complejidad injustificada
  (Principio VI: no mezclar una migración de esquema con una corrección de comportamiento que no
  la necesita).
- *Reducción proporcional* entre las adiciones en conflicto: introduce redondeo no especificado
  por la spec (¿hacia arriba, hacia abajo, a la opción con más unidades?) y una cantidad resultante
  menos predecible para el cajero que "se reduce una adición completa a la vez".

El criterio elegido es una función pura de datos de catálogo que ya existen (`Option.name`), sin
ningún cambio de esquema, y totalmente reproducible entre backend (Python) y frontend (TypeScript)
porque ambos pueden ordenar por el mismo campo.

**Precisión de comparación (añadido en remediación de /speckit-analyze)**: el orden alfabético
descendente se calcula sobre `Option.name` normalizado, nunca por comparación binaria cruda de
código de punto/unidad UTF-16 (que trataría mayúsculas y minúsculas como alfabetos distintos).
Backend compara con `name.casefold()`; frontend replica con `name.toLocaleLowerCase('es-CO')`.
Ambos ordenan la cadena ya normalizada con comparación binaria simple (no `localeCompare` con
opciones de colation, para evitar que una configuración regional distinta del entorno de
ejecución produzca un orden distinto entre backend y frontend) — garantiza el mismo resultado en
ambos lados para cualquier nombre de opción, incluidos los acentos propios del español de
Colombia.

## D5 — Cómo informar el ajuste automático al frontend (FR-005)

No existe en el repositorio ningún esquema genérico de aviso/advertencia (`warning`, `notice`,
`adjusted`: ninguna coincidencia en `cart/schemas.py` ni `orders/schemas.py`). El precedente más
cercano es `OrderBillingSummary.sin_detalle_de_precios` (spec 094,
`app/api/v1/orders/schemas.py:259`): un campo estructurado, calculado en servidor, agregado a una
respuesta ya existente — el backend decide **cuándo** se dispara, el frontend decide **cómo**
mostrarlo (que es justo lo que esta spec deja fuera de alcance: "definir el diseño visual concreto
del aviso").

**Decisión**: `CartItemResponse` (`app/api/v1/cart/schemas.py`) gana
`adjusted_options: list[AdjustedOptionOut] = []`, con `option_id`, `option_name`,
`previous_quantity`, `new_quantity` por cada opción que `update_item` tuvo que reducir. Se puebla
**únicamente** en la respuesta del `PATCH /cart/items/{id}` que disparó el ajuste — nunca en
`GET /cart` ni en respuestas de otros endpoints, porque el ajuste ya ocurrió al escribir y no debe
"reaparecer" en cada lectura posterior. Ver [contracts/cart-item-auto-adjust.md](./contracts/cart-item-auto-adjust.md).

## D6 — Frontend: derivar "por línea" desde `selection_mode`, no desde una bandera por canal

Hoy `ProductSelectComponent` recibe `@Input() addonsPerLine` como bandera fija que cada página pasa
distinto: la Terminal y el pedido manual la omiten (⇒ `false`, todas las opciones dentro de
`unitPrice`, multiplicadas por cantidad); el Menú QR la fija en `true` (todas por línea). Es la
misma confusión de ejes que D1 corrige en el backend (atada al canal, no al modo del grupo).

**Decisión**: `ProductSelectComponent.lineTotal()` deja de recibir `addonsPerLine` como entrada
única y en su lugar decide **por cada opción elegida**, mirando `chosenOption.option.option_group
.selection_mode` (ya disponible en el catálogo que el componente ya consulta): `'conteo'` sigue
sumando dentro de la base multiplicada por cantidad; `'cantidad'` se suma aparte, sin multiplicar
— reproduciendo en el cliente exactamente la condición D1. Mismo cambio en
`PosTerminalStore.addDraftFromSelection()`/`cartView()`: en vez de fijar siempre
`addonsTotal: 0` y meter todo en `unitPrice`, separa por `selection_mode` de cada opción.

El `@Input() addonsPerLine` no se elimina de inmediato (lo sigue usando spec 089 para su propio
eje `pricing_type`/canal QR, D1 no lo toca): se **añade** la lógica nueva en paralelo, evaluando
ambas condiciones con el mismo OR que D1 usa en backend.

## D7 — Inventario (FR-007): sin cambios de código, solo de verificación

`plan_line_consumption` (`app/catalog_engine/consumption.py:140`) ya lee el mismo `per_line` que
D1 extiende: `per_unit × chosen.quantity` cuando `per_line = True` (sin `× cantidad de producto`).
En cuanto D1 se implementa, toda adición "cantidad" deja de multiplicarse por la cantidad de
producto en el descuento de inventario **sin tocar `consumption.py`**. Se confirma con un test de
characterization nuevo (`test_catalog_consumption_plan.py`), no con código nuevo — evita
reimplementar una fórmula que ya existe y ya está probada para `per_line = True`.

## D8 — Registro de la decisión de negocio (Principio II)

Esta spec reabre explícitamente `RN-CAT-01` (spec 002) solo para grupos "Por cantidad" (spec 065),
con la decisión de negocio ya documentada en el propio `spec.md` (sesión de Clarifications,
2026-10-13). Falta solo el registro formal en
`specs/000-reconocimiento/registro-de-anomalias.md`, que es trabajo de implementación (como ya
ocurrió con A-94/95/96/97 de la spec 089): la primera tarea de `tasks.md` registrará la próxima
entrada disponible (confirmar el número vigente con
`grep -oE "^### A-[0-9]+" specs/000-reconocimiento/registro-de-anomalias.md | sort -t- -k2 -n | tail -1`
al momento de ejecutar la tarea, no ahora) citando: qué cambia (el eje de escalado de
`RN-CAT-01` para grupos "cantidad"), por qué (reporte del negocio: "2 granizados + 1 gomitas cobra
2 gomitas"), quién y cuándo (sesión de Clarifications de esta spec, 2026-10-13), y qué
funcionalidades se ven afectadas (pricing de línea, topes de grupo, consumo de inventario,
comanda — nunca "conteo" ni facturas ya emitidas).

## Tests de characterization afectados (a actualizar citando la decisión anterior)

- `app/characterization_tests/test_catalog_line_pricing.py` — casos con `selection_mode='cantidad'`
  y `per_line` derivado de ella (hoy solo cubre el eje `pricing_type`/canal QR de la spec 089).
- `app/characterization_tests/test_catalog_consumption_plan.py` — adición "cantidad" descuenta
  `per_unit × cantidad_opción`, no `× cantidad_producto × cantidad_opción`.
- `app/characterization_tests/test_catalog_option_groups_quantity.py` — los dos tests que hoy
  congelan explícitamente la multiplicación por cantidad de producto
  (`test_precio_de_linea_multiplica_extra_price_por_cantidad`,
  `test_cobrar_una_venta_de_mostrador_completa_descuenta_el_total_multiplicado`,
  `test_confirmar_una_orden_completa_descuenta_el_total_multiplicado`) documentaban el **bug**
  que esta spec corrige — se actualizan para congelar el nuevo comportamiento, citando la
  decisión de negocio (D8), nunca en silencio (Principio III).
- `app/characterization_tests/test_catalog_option_groups_selection_mode.py` — topes fijos pasan a
  escalados (D2).
- `app/characterization_tests/test_cart_service.py`, `test_orders_consolidation.py`,
  `test_orders_service.py` — call-sites que pasan de `compute_line_price` "folded" a
  `compute_unit_price`/`compute_addons_total` separados (D1).
- Frontend: `product-select.component.spec.ts`, `pos-terminal.store.spec.ts`,
  `dining-cart.service.spec.ts` — nuevos casos para `selection_mode='cantidad'` fuera del canal QR.
