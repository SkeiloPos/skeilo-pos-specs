# Data Model — Fase 1: Desglose Económico y Datos de Entrega en el Detalle de Orden

**Spec**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md) · **Research**: [research.md](./research.md)

> **Esta spec no modifica el modelo de datos persistido.** Cero entidades nuevas, cero
> columnas nuevas, cero relaciones nuevas, cero migraciones, cero relleno retroactivo y
> cero escrituras. El Principio VIII no aplica por ausencia de cambio: no hay estrategia de
> migración que declarar porque no hay migración, y la estrategia de rollback de la parte de
> backend es revertir el despliegue (el contrato es puramente aditivo, §4).
>
> Lo que sí hay es un **modelo de lectura**: un objeto derivado que el servidor arma en el
> momento de la consulta a partir de columnas que ya existen. Este documento lo define y
> traza cada campo hasta su origen.

---

## 1. Entidades persistidas que se leen (ninguna cambia)

### 1.1 `tenant.customer_orders` → **Pedido**

| Columna | Tipo | Se usa para | Notas verificadas |
|---|---|---|---|
| `id` | UUID | Identificar el pedido | — |
| `order_type` | `varchar(10)` nulable | Encabezado (FR-012) y existencia del bloque de entrega (FR-015) | Nulable sin relleno retroactivo: los pedidos históricos sin clasificar muestran "Sin especificar" (D13) |
| `dining_table_id` | UUID nulable | Encabezado: la mesa manda sobre el tipo (D13) | — |
| `status` | `varchar(12)` | Etiqueta de estado (FR-014), supresión del aviso de FR-023 en cancelados (D7) y exclusión del cancelado de `factura_agrupada` (D2) | `recibida\|abierta\|bloqueada\|pagada\|cancelada` |
| `customer_name` | `varchar(255)` nulable | Etiqueta "Cliente" (FR-013) y receptor del bloque de entrega (FR-015, Q1) | — |
| `notes` | `varchar(500)` nulable | Notas del pedido y referencias de entrega (FR-015, Q1) | Un solo campo con dos usos: consecuencia aceptada en Q1 |
| `delivery_address` | `varchar(255)` nulable | Bloque de entrega | Solo diligenciado en `DELIVERY` |
| `delivery_phone` | `varchar(30)` nulable | Bloque de entrega | Ídem |
| `delivery_fee` | `numeric(12,2)` nulable | Fila Envío (FR-007) | `NULL` se lee como `0` para el condicionado de la fila; nunca se pinta como "$ 0" |
| `discount` | `numeric(12,2)` NOT NULL | FR-011 (campo crudo) y desglose propio del pedido (D4) | Nace `0`; se fija en el cobro |
| `applied_promotions` | `jsonb` NOT NULL | FR-011 (campo crudo) y etiqueta de la fila de descuento (D6) | Nace `'[]'`; **una entrada por regla**, no por promoción |
| `table_session_id` | UUID nulable | Detección de `factura_agrupada` (D2) | — |

### 1.2 `tenant.order_items` → **Línea de pedido**

| Columna / propiedad | Tipo | Se usa para | Notas verificadas |
|---|---|---|---|
| `quantity` | `integer` | Cantidad por línea (FR-001) | Siempre > 0 |
| `unit_price` | `numeric(12,2)` | Precio unitario **de lista** (FR-001, FR-004) | Congelado al confirmar; existe en todo pedido del histórico |
| `addons_total` | `numeric(12,2)` | Adicionales cobrados una vez por línea (FR-003, FR-004) | `0` en toda línea anterior a spec 089 y en las de la terminal POS |
| `line_total` *(propiedad, no columna)* | `Decimal` | Importe de la línea (FR-002) y sumando del Subtotal (FR-005) | `unit_price × quantity + addons_total` — el auxiliar único (`app/models/order_item.py:87-91`) |
| `estado_cocina` | `varchar(15)` | Marca de anulado y exclusión de las sumas (FR-019, FR-019a) | `anulado` es el valor que excluye |
| `discounted_unit_price` | `numeric(12,2)` nulable | **No se usa** (Q5) | Se deja intacta; la pantalla la ignora |
| `discounted_line_total` | `numeric(12,2)` nulable | **No se usa** (Q5) | Ídem |
| `combo_id` | UUID nulable | **No se usa** por el desglose | Las líneas de combo suman como cualquier otra (Edge Case) |

### 1.3 `tenant.sales` → **Factura (Venta)**

Solo se **lee**, y solo cuando cubre exactamente este pedido (FR-024).

| Columna | Se usa para | Notas verificadas |
|---|---|---|
| `customer_order_id` | Detectar `factura_propia` (D2) | Indexada; la ponen los cuatro caminos de cobro por pedido y el cierre unificado de un solo pedido |
| `table_session_id` | Detectar `factura_agrupada` (D2) | Indexada |
| `subtotal` | Subtotal mostrado | Σ `line_total` **de lista** de las líneas cobrables (`builder.py:183-196`) |
| `discount` | Fila de descuento | Agregado; el desglose por promoción vive en `applied_promotions` |
| `delivery_fee` | Fila de envío | Copiado del pedido al facturar |
| `total` | Total mostrado | `subtotal − discount + tax + tip + delivery_fee` (`builder.py:100-117`) |
| `applied_promotions` | Etiqueta de la fila de descuento | Mismo formato que el del pedido |
| `tax`, `tip` | **No se leen ni se muestran** | Siempre `0` en los caminos vigentes; riesgo residual medido en D5 |

### 1.4 `tenant.order_item_options` → **Opción elegida**

Sin cambios de uso: la pantalla ya las pinta. `per_line` solo documenta por qué
`addons_total` existe; el desglose no la consulta.

---

## 2. Modelo de lectura: `OrderBillingSummary`

Objeto derivado, armado en cada consulta del detalle. **No se persiste, no se cachea y no
tiene identidad.** Es la materialización de la decisión de diseño 8 de la spec: la pantalla
recibe un desglose ya decidido más la señal de qué caso es.

| Campo | Tipo | Siempre presente | Significado |
|---|---|---|---|
| `state` | `"sin_factura" \| "factura_propia" \| "factura_agrupada"` | Sí | Cuál de los tres casos es (FR-024b) |
| `source` | `"pedido" \| "factura"` | Sí | De dónde salieron los importes. `factura` solo con `state = factura_propia` |
| `subtotal` | `Decimal` ≥ 0 | Sí | Suma de los importes **de lista** de las líneas no anuladas, o el de la factura |
| `discount` | `Decimal` ≥ 0 | Sí | `0` cuando `state = sin_factura` (FR-023) |
| `discount_label` | `str \| null` | No | Nombre de la promoción, o `null` cuando se debe usar "Descuento" (D6) |
| `delivery_fee` | `Decimal` ≥ 0 | Sí | `0` cuando el pedido no es a domicilio |
| `total` | `Decimal` ≥ 0 | Sí | `subtotal − discount + delivery_fee`, o el total de la factura |
| `promotions` | `AppliedPromotionOut[]` | Sí (puede ir vacía) | Snapshot de las promociones que aportaron al descuento |
| `sin_detalle_de_precios` | `bool` | Sí | Condición exacta de FR-018 (D8) |

### `AppliedPromotionOut`

| Campo | Tipo | Notas |
|---|---|---|
| `promotion_id` | `UUID \| null` | Nulable por lectura tolerante del JSONB histórico |
| `name` | `str \| null` | El nombre **del momento del cobro**; nunca se consulta la promoción vigente |
| `amount` | `Decimal` | Aporte agregado de esa regla al descuento |

`rule_id` existe en el JSONB y **no se publica**: no aporta nada a esta pantalla y
publicarlo expone un detalle interno del motor de promociones.

---

## 3. Reglas de derivación (invariantes verificables)

Las siguientes se cumplen para cualquier pedido y son la base de los tests de contrato:

1. **R1 — Subtotal = Σ líneas visibles cobrables.**
   `billing.subtotal == Σ item.line_total` para los ítems con `estado_cocina != 'anulado'`
   cuando `source = "pedido"`. Con `source = "factura"` la igualdad la garantiza
   `build_sale`, que acumuló ese mismo subtotal con el mismo filtro al facturar
   (FR-005, FR-019, SC-007).
2. **R2 — Total = Subtotal − Descuento + Envío**, y nunca negativo (FR-008).
3. **R3 — Sin factura ⇒ sin descuento.** `state = "sin_factura"` ⇒ `discount == 0` y
   `promotions == []` (FR-023).
4. **R4 — Factura agrupada ⇒ el origen es el pedido.** `state = "factura_agrupada"` ⇒
   `source == "pedido"` (FR-024a: no se presenta el total del pedido como el facturado).
   **R4b** — un pedido `cancelada` sin venta propia nunca es `factura_agrupada`, aunque su
   sesión tenga ventas: no se cobró, y el aviso de FR-024a afirmaría que sí (D2, RN-005).
5. **R5 — El aviso de falta de detalle es excluyente con un subtotal real.**
   `sin_detalle_de_precios == True` ⇔ hay ≥ 1 ítem no anulado **y** la suma de sus
   `line_total` es `0` (FR-018, D8).
6. **R6 — Etiqueta de descuento.** `discount_label` es el `name` de la única promoción con
   `amount > 0` tras agrupar por `promotion_id`; en cualquier otro caso es `null`
   (FR-009, FR-010, D6).
7. **R7 — Ningún importe se recalcula contra el catálogo ni contra las promociones
   vigentes.** Todas las entradas de las reglas anteriores son columnas congeladas
   (RN-001, FR-022).

---

## 4. Impacto sobre el contrato de la API

Todo es **aditivo**. Ningún campo se renombra, se retira ni cambia de tipo.

| Esquema | Cambio | Dónde se rellena |
|---|---|---|
| `OrderResponse` | `+ discount: Decimal` | Siempre (columna ya cargada) |
| `OrderResponse` | `+ applied_promotions: AppliedPromotionOut[]` | Siempre (columna ya cargada) |
| `OrderResponse` | `+ billing: OrderBillingSummary \| null` | **Solo** en `GET /orders/{id}`; `null` en el listado (D3) |

Consecuencias sobre consumidores existentes, verificadas:

- `GET /orders` (listado paginado, con `ETag`): el cuerpo gana tres claves, dos con valor y
  una en `null`. El `ETag` cambia una vez al desplegar, que es su comportamiento normal ante
  cualquier cambio de cuerpo. Ninguna pantalla pierde datos ni cambia de comportamiento.
- Terminal de mesas, KDS y panel de cobro consumen `OrderResponse` y **ignoran claves
  desconocidas** (interfaces TypeScript estructurales): no se tocan.

### Rollback

Revertir el despliegue del backend devuelve el contrato anterior. El frontend desplegado
contra un backend revertido deja de pintar el resumen (D15) y sigue funcionando: no hay
estado persistido que deshacer ni dato que reparar, porque esta spec no escribe nada.

---

## 5. Modelo de vista del frontend (`DiningOrder`)

La interfaz existente gana los mismos tres campos, todos **opcionales**, para que un cliente
nuevo contra un backend anterior compile y funcione (D15):

```ts
discount?: string;                         // importes como string, igual que el resto
applied_promotions?: AppliedPromotion[];
billing?: OrderBilling | null;             // ausente/null ⇒ no se pinta el resumen
```

La pantalla **no consume** `discount` ni `applied_promotions` (D16): su única fuente es
`billing`. Los importes llegan como `string` por la convención ya establecida en
`DiningOrderItem` (`unit_price: string`, `line_total?: string`) y se convierten con `Number`
en el punto de pintado, igual que hoy.

---

## 6. Lo que explícitamente NO cambia

- Ninguna columna de `order_items`, `customer_orders`, `sales` o `invoices`.
- `discounted_unit_price` / `discounted_line_total`: siguen escribiéndose igual en el cobro
  y simplemente no se leen en esta pantalla (Q5).
- Ningún formulario de creación (POS ni Menú QR): el bloque de entrega no tiene datos
  propios (Q1, FR-015a).
- Ninguna factura emitida, ni en importe ni en representación (Principio VII).
