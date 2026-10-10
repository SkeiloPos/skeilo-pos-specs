# Análisis: conversión de unidades entre compra e inventario

**Alcance de este documento**: análisis y propuesta, **sin cambios de código**. Explica por qué
hoy, al registrar una compra, el usuario tiene que calcular a mano cuántas unidades base
representa lo que compró (p. ej. "compré 1 libra de azúcar, pero el insumo está en gramos"), qué
partes del sistema dependen de ese comportamiento, y tres estrategias para resolverlo — una de
ellas requiere evolucionar el modelo de datos, y se presenta como propuesta, no como decisión
tomada.

## 1. Resumen ejecutivo

| Pregunta | Respuesta corta |
|---|---|
| ¿Por qué pasa esto? | `PurchaseItem.quantity`/`unit_cost` siempre se interpretan en la **unidad base** del insumo (`InventoryItem.unit_measure_id`) — no existe ningún campo, en backend ni frontend, para indicar "en qué compré esto" ni un factor de conversión en el momento de la compra. |
| ¿Es un bug? | No — es el diseño original (`fn_add_inventory_on_purchase`, ver encabezado de `service.py`), nunca pensado para capturar la presentación de compra. |
| ¿Ya existe algo que ayude? | **Sí, parcialmente.** La spec [106](specs/106-relacion-proveedor-insumo/spec.md), ya implementada, creó exactamente el campo que falta — `SupplierItem.conversion_factor` ("cuántas unidades base trae 1 presentación") — pero **lo dejó explícitamente sin conectar a las compras**. La propia spec 106 lo documenta como trabajo pendiente ("HU-05", RN-15) y hasta agregó, vacía, la columna `purchase_items.supplier_item_id` para que ese enlace fuera posible sin otra migración. |
| ¿Hace falta tocar el modelo de datos? | Depende de la estrategia (sección 4). La Estrategia A casi no lo necesita (reutiliza spec 106). Las Estrategias B y C sí agregan columnas nuevas. |

## 2. Cómo funciona hoy (confirmado leyendo el código, no por inferencia)

```
┌──────────────────┐        unit_measure_id         ┌──────────────┐
│  InventoryItem    │ ─────────────────────────────► │ UnitMeasure   │
│  (insumo)         │                                 │ name          │
│  current_stock     │  ambos en la MISMA unidad       │ abbreviation  │
│  unit_cost         │  (current_stock, unit_cost)     │ active        │
│  min_stock         │                                 │  (sin dimensión
└────────▲──────────┘                                 │   ni factor — ver
         │ record_movement(quantity, type="in")       │   nota A-31 abajo)
         │ quantity SIEMPRE en unidad base             └──────────────┘
         │ (app/inventory_engine/stock.py)
         │
┌────────┴──────────────────────────────────────────┐
│  PurchaseItem                                        │
│  quantity       ← SIEMPRE unidad base (g, ml, ud…)   │
│  unit_cost      ← SIEMPRE costo por unidad base       │
│  received_quantity                                    │
│  supplier_item_id  ← existe desde spec 106, NULL      │
│                      siempre, ningún flujo la llena   │
└────────▲──────────────────────────────────────────┘
         │ POST /inventory/purchases            (alta directa, recibida de inmediato)
         │ POST /inventory/purchases/order       (draft, sin stock)
         │ POST /inventory/purchases/{id}/receive (recepción parcial/total)
         │ los 3 flujos en app/api/v1/inventory/service.py — los 3 toman
         │ `quantity`/`unit_cost` tal cual llegan del request, sin convertir nada
         │
┌────────┴──────────────────────────────────────────┐
│  Formulario de compra (pos-heladeria)                │
│  purchase-form.component.ts                          │
│  Campo "Cantidad": <input type="number">              │
│    — SIN unidad visible, SIN pista de en qué va       │
│    — el usuario debe saber que ahí va en gramos        │
│    y haber calculado 1 libra = 453.592 g por su cuenta  │
└──────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  SupplierItem (spec 106, YA IMPLEMENTADO, sin conectar)    │
│  supplier_id + inventory_item_id + presentation (texto      │
│  libre, ej. "Bolsa x 500 g") + conversion_factor (decimal,   │
│  "cuántas unidades base trae 1 presentación") + last_cost     │
│                                                                │
│  Es EXACTAMENTE el dato que falta para resolver el problema,  │
│  pero hoy solo se gestiona manualmente desde las pestañas       │
│  "Proveedores"/"Insumos que vende" — ningún endpoint de compra   │
│  lo lee ni lo escribe todavía.                                    │
└─────────────────────────────────────────────────────────────────┘
```

**Causa raíz, en una frase**: el modelo de compras nunca tuvo un concepto de "presentación de
compra" propio — asumió que siempre se compra y se mide en la misma unidad — y cuando la spec 106
finalmente introdujo ese concepto (`SupplierItem.conversion_factor`), lo hizo a propósito solo
para la *relación* proveedor-insumo, dejando su conexión con el *registro de la compra* como
trabajo futuro explícito (`research.md` de la spec 106, Decisión D6: *"ningún flujo actual de
compras la puebla todavía — HU-05 es quien la llenará"*).

### Nota relacionada: hay un segundo mecanismo de conversión, ya documentado como incompleto

La spec de characterization [005](specs/005-kardex-compras-conversion/spec.md) (FR-024/FR-025,
anomalía A-31) documentó que `app/core/units.py::convert()` es **código muerto**: asume que
`UnitMeasure` tiene columnas `dimension` y `factor_to_base` que **no existen** en el modelo real
(`UnitMeasure` solo tiene `name`/`abbreviation`/`active`) — confirmado de nuevo en este análisis,
el archivo sigue intacto y sin un solo import en todo el repositorio. Es una migración "Fase 1"
que nunca se completó, pensada para convertir entre **unidades de la misma dimensión** (p. ej.
litros↔onzas, o kg↔g↔libras), no para presentaciones de empaque. Es un mecanismo *distinto* del de
`SupplierItem`, y relevante para este análisis porque la Estrategia B (sección 4) es, en esencia,
completar esa migración abandonada.

## 3. Dependencias — qué invariantes no se pueden romper

| Componente | Qué asume hoy | Por qué importa |
|---|---|---|
| `record_movement` (kardex, `app/inventory_engine/stock.py`) | Recibe `quantity` siempre en unidad base, siempre positiva | Es el único punto de mutación de `current_stock` (invariante protegido, spec 005 US1) — cualquier estrategia **debe** seguir entregándole la cantidad ya convertida, nunca la cantidad "tal cual la escribió el usuario" |
| `InventoryItem.unit_cost` | Se sobrescribe con el `unit_cost` del `PurchaseItem` tal cual llega — hoy eso *ya* es "costo por unidad base" porque `quantity` también lo es | Si se permite capturar costo *por presentación* (p. ej. costo de 1 bolsa), hay que dividir por el factor **antes** de escribir aquí, o `unit_cost` deja de significar lo que el resto del sistema (reportes, FR-007 de spec 106) espera |
| `Purchase.total` | Suma `quantity × unit_cost` de cada línea, ambos ya en unidad base | Si el usuario captura en presentación, `total` debe calcularse con los valores *originales* (cantidad de presentaciones × costo de la presentación), no con los derivados — para no acumular error de redondeo |
| RN-INV-22 (spec 005, protegida) | "El costo aplicado en una recepción DEBE ser el pactado en la orden al crearla" | Si una orden se crea en una presentación con un factor, la recepción debe aplicar el mismo factor — no puede "reconvertir" con un factor distinto al momento de recibir |
| RN-INV-23 (spec 005, protegida) | Cantidad > 0 y costo ≥ 0, consistente en los 3 flujos (directa/orden/recepción) | Cualquier campo nuevo (cantidad en presentación, factor) debe validarse igual en los 3 flujos, no solo en el de alta directa |
| `SupplierItem.active`/`preferred`/`conversion_factor` (spec 106) | Ya validado: factor > 0, inmutable tras uso en una compra (FR-014), proveedor de sistema excluido (FR-012/013) | Cualquier estrategia que reutilice `SupplierItem` hereda estas reglas gratis — ya están implementadas y probadas; no reinventarlas |
| RN-17 ("Compra ocasional" no se vincula) | El proveedor de sistema nunca tiene una fila en `supplier_items` | Una compra registrada contra "Compra ocasional" **nunca** podrá tener un `supplier_item_id` — cualquier estrategia necesita un camino que no dependa de esa relación para ese caso |
| Frontend `purchase-form.component.ts` | Un solo campo "Cantidad", sin unidad visible | Es la superficie de UX que hay que rediseñar en cualquiera de las 3 estrategias — hoy ni siquiera muestra la unidad base como referencia |
| Reportes (`reports/service.py`, "insumos por reponer") | Leen `current_stock`/`min_stock`/`unit_cost` ya en unidad base | Ninguna estrategia los afecta directamente, siempre que `record_movement` siga recibiendo unidad base ya convertida |

## 4. Tres estrategias

### Estrategia A — Terminar de conectar `SupplierItem` a las compras (completar HU-05)

**Idea**: cuando se registra una línea de compra, si hay un proveedor elegido, el formulario
ofrece las presentaciones ya guardadas (`SupplierItem` activas) para ese proveedor+insumo. El
usuario elige la presentación (p. ej. "Libra", factor 453.592), escribe **cuántas presentaciones**
compró (p. ej. "1") y el costo (de la presentación o total, a definir) — el backend calcula
`quantity_base = cantidad_presentaciones × conversion_factor` antes de llamar a
`record_movement`, y guarda tanto el valor base (para el kardex, sin romper nada existente) como
el valor y la unidad originalmente capturados (para trazabilidad y para que la compra "diga la
verdad" de lo que pasó).

**Cambios de modelo de datos** (mínimos, extiende lo que ya existe):
- `PurchaseItem` += `quantity_in_presentation: Decimal | NULL` (lo que el usuario escribió, en la
  presentación elegida; `NULL` si se compró directamente en unidad base, como hoy).
- `PurchaseItem.supplier_item_id` (ya existe desde spec 106, hoy sin usar) pasa a poblarse de
  verdad — es la pieza que faltaba conectar.
- `PurchaseItemIn`/`PurchaseLineForm` (schemas/frontend) += `supplier_item_id?` y
  `quantity_in_presentation?`.
- Implementa RN-15 (el upsert automático de `SupplierItem.last_cost` al recibir una compra) que
  la spec 106 dejó pendiente — se resuelve "gratis" junto con esto.

**Pros**: reutiliza al 100% las validaciones ya construidas y probadas en spec 106 (factor > 0,
inmutable tras uso, exclusión del proveedor de sistema, unicidad de presentación); es la migración
más pequeña de las tres; cierra un hueco ya documentado (HU-05) en vez de abrir uno nuevo.

**Contras**: solo funciona si el admin **ya registró** esa presentación en la relación
proveedor-insumo (pestaña "Proveedores") antes de intentar comprar así — para una compra puntual
en una presentación nueva, obliga a crear la relación primero. No resuelve nada para "Compra
ocasional" (RN-17: ese proveedor nunca tiene `SupplierItem`), que seguiría obligando al cálculo
manual.

### Estrategia B — Completar la conversión de unidades real en `UnitMeasure` (terminar A-31)

**Idea**: en vez de una presentación atada a un proveedor, cualquier insumo puede comprarse en
**cualquier unidad de medida de la misma dimensión** que su unidad base (si el insumo está en
gramos, se puede comprar en kg, libras, onzas — cualquier unidad de masa del catálogo). Esto es,
literalmente, completar la migración "Fase 1" que la spec 005 ya documentó como abandonada
(anomalía A-31): agregar `dimension` y `factor_to_base` reales a `UnitMeasure`, y usar
`app/core/units.py::convert()` (hoy código muerto) para la conversión.

**Cambios de modelo de datos** (más grandes, nuevos):
- `UnitMeasure` += `dimension: str` (p. ej. `"masa"`, `"volumen"`, `"unidad"`) y
  `factor_to_base: Decimal` (cuánto vale 1 unidad de esta, en la unidad canónica de su dimensión).
  Requiere sembrar estos valores para TODAS las unidades existentes (migración de datos, no solo
  de esquema).
- `PurchaseItem` += `purchase_unit_measure_id: UUID | NULL` (en qué unidad se compró) y
  `purchase_quantity: Decimal | NULL` (cuánto, en esa unidad).
- `PurchaseItemIn`/`PurchaseLineForm` += `unit_measure_id?` (por defecto, la unidad base del
  insumo, igual que hoy) y la cantidad se interpreta en esa unidad.

**Pros**: resuelve el problema para **cualquier** compra, incluida "Compra ocasional" — no
depende de que exista una relación proveedor-insumo; es genérico y reutilizable (sirve también
para casos fuera de compras, si algún día se necesitan, como el caso ya documentado del
"granizado" litros↔onzas de la propia spec 005); cierra formalmente la anomalía A-31.

**Contras**: migración más invasiva (columnas nuevas + sembrado de datos en una tabla que hoy no
los tiene, con riesgo de que algún `UnitMeasure` quede con una dimensión ambigua o mal
clasificada); no captura el concepto de "presentación" con nombre propio (una bolsa, una caja de
24) — solo conversión entre unidades, no "paquetes"; requiere decidir y validar la dimensión de
cada unidad del catálogo actual, trabajo de datos no trivial si el catálogo ya tiene unidades
ambiguas o mal nombradas.

### Estrategia C — Las dos anteriores combinadas, cada una para su caso

**Idea**: ofrecer ambos mecanismos en el formulario de compra, sin forzar uno sobre el otro:

1. Si hay un proveedor elegido y existen presentaciones guardadas (`SupplierItem`) para ese
   proveedor+insumo → se ofrecen esas presentaciones primero (Estrategia A) — es el camino
   "normal" para proveedores recurrentes, y ya trae el último costo precargado.
2. Si no hay ninguna presentación guardada, o el proveedor es "Compra ocasional" → se cae a elegir
   cualquier unidad compatible del catálogo general (Estrategia B) — cubre el caso puntual/ad-hoc
   sin obligar a crear una relación proveedor-insumo primero.

**Cambios de modelo de datos**: la unión de A y B (ambas columnas nuevas en `PurchaseItem`, ambos
campos nuevos en los schemas, más `UnitMeasure.dimension`/`factor_to_base`).

**Pros**: es la única de las tres que cubre el 100% de los casos reales descritos en el propio
enunciado de negocio (RN-15 vía relación guardada, RN-17 vía "Compra ocasional" sin relación);
cada mecanismo resuelve el problema para el que fue diseñado, sin forzar al otro a cubrir un caso
que no le corresponde.

**Contras**: es la de más trabajo (dos migraciones, dos flujos de UI, dos conjuntos de reglas que
mantener); el formulario de compra necesita comunicar con claridad cuál de los dos modos está
activo en cada línea, para no confundir al usuario sobre qué significa el número que está
escribiendo.

### Tabla comparativa

| | A — Conecta `SupplierItem` | B — Completa `UnitMeasure` (A-31) | C — Ambas |
|---|---|---|---|
| Tamaño de la migración | Pequeña | Mediana-grande (+ sembrado de datos) | Grande |
| Resuelve "Compra ocasional" (RN-17) | No | Sí | Sí |
| Reutiliza trabajo ya hecho (spec 106) | Sí, al 100% | Parcialmente (ninguna validación nueva) | Sí |
| Cierra una anomalía ya documentada | — | A-31 (spec 005) | A-31 (spec 005) |
| Requiere que el admin configure algo antes de comprar así | Sí (la presentación) | No | Solo para el camino 1 |
| Esfuerzo relativo | Bajo | Medio-alto | Alto |

## 5. Preguntas abiertas (necesito tu decisión antes de convertir esto en spec)

1. **¿Las dos rutas de "Compra ocasional" y "proveedor con relación guardada" son ambas
   necesarias para ti**, o en la práctica casi siempre compras a un proveedor con el que ya tienes
   la relación proveedor-insumo armada (en cuyo caso la Estrategia A sola podría bastar, más
   simple y rápida de construir)?
2. **¿El costo se debe capturar por presentación completa** (p. ej. "esta bolsa de 500 g me costó
   $8.000") **o por unidad de compra** (p. ej. "esta libra me costó $X")? Cambia qué campo exacto
   se le pide al usuario y cómo se deriva `unit_cost`/`total`.
3. Si avanzamos con la Estrategia B o C: **¿quieres que yo proponga la `dimension` de cada unidad
   ya existente en tu catálogo** (a partir de su nombre/abreviatura), o prefieres revisarlas y
   clasificarlas tú mismo antes de que toque el esquema — dado que es sembrado de datos, no solo
   de esquema, y un error ahí convertiría cantidades mal silenciosamente?

Cuando tengas una dirección, lo llevamos a `/speckit-specify` como una spec nueva (sería la 107) —
este documento ya te da el contexto completo para esa conversación sin que yo tenga que
re-investigar el código.
