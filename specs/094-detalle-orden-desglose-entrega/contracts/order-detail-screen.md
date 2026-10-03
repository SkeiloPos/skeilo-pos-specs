# Contrato — Pantalla "Detalle de Orden" (`/dashboard/orders/:id`)

**Spec**: [../spec.md](../spec.md) · **Plan**: [../plan.md](../plan.md) · **Research**: [../research.md](../research.md)

Contrato de presentación: qué se pinta, con qué texto exacto y bajo qué condición. Es una
**sola pantalla** compartida por Administrador, Cajero y Mesero, con contenido idéntico para
los tres (RN-007, Q4). La ruta y su `roleGuard([ADMIN, CASHIER, MESERO])` no cambian.

Componente: `src/app/modules/orders/pages/order-detail.component.ts`.
Fuente de datos: `GET /orders/{id}` ([order-detail-api.md](./order-detail-api.md)).

---

## 1. Encabezado

| Zona | Hoy | Con esta spec |
|---|---|---|
| Rótulo superior | `Mesa` siempre | `Mesa` si el pedido tiene mesa; `Tipo de pedido` si no |
| Valor | Nombre de la mesa, o `Mostrador` | Mesa (`Mesa 4` / `Mesa 4 · Terraza`) si hay `dining_table_id`; si no, `orderTypeLabel(order_type)` → `Para llevar`, `Domicilio` o `Sin especificar` |
| Estado | Igual | Igual, incluido `Cancelada` (FR-014) |
| Etiqueta del nombre | `Comensal` | **`Cliente`** (FR-013) |

La palabra "Comensal" no debe quedar en ninguna parte de la pantalla (SC-005). La palabra
"Mostrador" desaparece del encabezado: era el síntoma del problema 3 de la spec (D13).

---

## 2. Lista de ítems

Cada línea añade, a lo que ya muestra (cantidad, variante, opciones, nota):

| Elemento | Regla | Requisito |
|---|---|---|
| Precio unitario | `unit_price` formateado, **siempre de lista** | FR-001, FR-004 |
| Importe de la línea | `line_total` formateado = `unit_price × quantity + addons_total` | FR-002, FR-003 |
| Adicionales por línea | Cuando `addons_total > 0`, se muestra el monto o se indica que el importe lo incluye, para que `unitario × cantidad` no parezca contradecir el importe | FR-004 |
| Ítem anulado | Distintivo "Anulado" **en lugar** del importe; la línea sigue visible | FR-019a, D9 |

**Nunca** se muestra `discounted_unit_price` ni `discounted_line_total` (Q5): el descuento
vive solo en la fila del resumen.

Cuando `billing.sin_detalle_de_precios` es `true`, los importes por línea **se omiten** (no
se pintan en `$ 0`) y aparece el aviso de §4 (FR-018).

---

## 3. Bloque de resumen

Se pinta con `BillSummaryComponent` (D10), siempre que `billing` venga en la respuesta, en
todos los tipos de pedido y todos los estados.

| Fila | Condición | Valor | Etiqueta |
|---|---|---|---|
| Subtotal | Siempre | `billing.subtotal` | `Subtotal` |
| Descuento | `billing.discount > 0` (FR-006, RN-004) | `− billing.discount` | `billing.discount_label` o `Descuento` (FR-009, FR-010) |
| Envío | `billing.delivery_fee > 0` (FR-007, RN-004) | `billing.delivery_fee` | `Domicilio` — el default de `deliveryFeeLabel`, la misma palabra que las cuatro pantallas de cobro; la spec llama al concepto "Envío" y no se pasa ningún input para renombrarlo |
| Total | Siempre | `billing.total` | `Total` |

Formato de todos los importes: `formatMoney` → `$ 14.000` (FR-021, RN-002). Ningún importe
se calcula en el componente: los cuatro llegan resueltos (FR-024b, D1).

Si `billing` viene ausente o `null`, **el bloque entero no se renderiza** y tampoco los
importes por línea (D15). El resto de la pantalla funciona igual.

---

## 4. Avisos (textos literales, no parafraseables)

| Aviso | Texto exacto | Condición |
|---|---|---|
| Factura agrupada | `Este pedido se cobró junto con otros en una cuenta unificada; el total facturado está en Ventas` | `billing.state === 'factura_agrupada'` (FR-024a, Q8) |
| Pedido sin cobrar | `El descuento se calcula al cobrar; este total aún puede cambiar` | `billing.state === 'sin_factura'` **y** el pedido no está cancelado (FR-023, Q8, D7) |
| Sin detalle de precios | `Esta orden no tiene el detalle de precios por ítem` | `billing.sin_detalle_de_precios === true` (FR-018, Q6) |

Los tres son excluyentes entre sí por construcción salvo el tercero, que puede acompañar a
cualquiera de los dos primeros.

---

## 5. Bloque "Datos de entrega"

**Se renderiza si y solo si** `order_type === 'DELIVERY'` (FR-015, D14).

| Campo visible | Origen (Q1) | Se omite si |
|---|---|---|
| Cliente | `order.customer_name` | Vacío o solo espacios |
| Teléfono | `order.delivery_phone` | Ídem |
| Dirección | `order.delivery_address` | Ídem |
| Notas | `order.notes` | Ídem |

Un campo omitido no deja etiqueta huérfana, línea en blanco, guion ni la palabra "null"
(FR-020, RN-003). El bloque se muestra aunque falten campos (FR-015a).

### Acción "Copiar datos"

- Vive junto al encabezado del bloque (FR-016).
- Copia **texto plano**, un campo por línea con su etiqueta, en el orden Cliente, Teléfono,
  Dirección, Notas; omitiendo los vacíos (D12). Sin importes ni identificador del pedido.

```text
Cliente: María Gómez
Teléfono: 3001234567
Dirección: Cra 12 #34-56, Apto 201
Notas: Portería azul, timbre 201
```

- Éxito → toast `Datos de envío copiados al portapapeles` (texto literal de FR-017).
- Fallo del portapapeles → toast de error `No se pudieron copiar los datos`; la pantalla
  sigue operativa y los datos siguen visibles y seleccionables a mano (US2 §5).
- Sin ningún campo diligenciado, la acción se deshabilita (no hay nada que copiar).

La misma función construye la tarjeta y el texto: un campo que se ve es un campo que se
copia, y al revés.

---

## 6. Lo que la pantalla NO hace

- **No** calcula ni ajusta ningún importe: no suma líneas, no resta descuentos, no decide
  entre factura y pedido (FR-024b, RN-001).
- **No** consume `order.discount` ni `order.applied_promotions` (los publica FR-011 para
  otros consumidores): su única fuente es `billing` (D16).
- **No** condiciona nada por rol (RN-007).
- **No** escribe: ni al abrir ni al copiar (Impacto sobre Datos Existentes).
- **No** inventa valores por defecto: lo ausente no se pinta (RN-003, RN-005).

---

## 7. Cambio en `BillSummaryComponent` (aditivo)

```ts
@Input() discountLabel = 'Descuento';   // nuevo, con valor por defecto
```

Se usa como etiqueta de la fila de descuento. Las cuatro pantallas que ya consumen el
componente (`pos-checkout-panel`, `payment-attempt-review-panel`, `manual-order-page`,
`session-bill-panel`) no pasan el input y conservan su texto y su markup exactos
(Principio II, D10).
