# Contrato — `GET /api/v1/orders/{order_id}` con desglose de facturación

**Spec**: [../spec.md](../spec.md) · **Plan**: [../plan.md](../plan.md) · **Research**: [../research.md](../research.md) · **Modelo**: [../data-model.md](../data-model.md)

Contrato de la **adición** que esta spec hace a la respuesta de consulta de un pedido.
Todo lo que ya devolvía el endpoint sigue igual: este documento describe solo lo nuevo y las
garantías que se pueden verificar sobre ello.

- **Método y ruta**: `GET /api/v1/orders/{order_id}` — sin cambios.
- **Autenticación**: sesión de staff (`get_current_user`) — sin cambios. Alcanzable por
  Administrador, Cajero y Mesero, igual que hoy (RN-007).
- **Aislamiento**: el pedido se resuelve en el esquema del tenant de la sesión. Un
  identificador de otro tenant responde `404` (FR-025, §5).

---

## 1. Campos añadidos a `OrderResponse`

```jsonc
{
  // … todos los campos actuales, sin cambios …

  // FR-011 — valores crudos persistidos en el pedido.
  "discount": "4000.00",
  "applied_promotions": [
    { "promotion_id": "7b1e…", "name": "2 x $12.000", "amount": "4000.00" }
  ],

  // FR-024b — desglose ya resuelto por el servidor. Solo en este endpoint.
  "billing": {
    "state": "factura_propia",
    "source": "factura",
    "subtotal": "28000.00",
    "discount": "4000.00",
    "discount_label": "2 x $12.000",
    "delivery_fee": "0.00",
    "total": "24000.00",
    "promotions": [
      { "promotion_id": "7b1e…", "name": "2 x $12.000", "amount": "4000.00" }
    ],
    "sin_detalle_de_precios": false
  }
}
```

### Tipos

| Campo | Tipo | Nulable | Regla |
|---|---|---|---|
| `discount` | `Decimal` (string en JSON) | No | ≥ 0 |
| `applied_promotions` | `AppliedPromotionOut[]` | No | Puede ir vacío |
| `billing` | `OrderBillingSummary` | **Sí** | `null` en `GET /orders` (listado) |
| `billing.state` | `"sin_factura" \| "factura_propia" \| "factura_agrupada"` | No | — |
| `billing.source` | `"pedido" \| "factura"` | No | `"factura"` solo si `state = "factura_propia"` |
| `billing.subtotal` | `Decimal` | No | ≥ 0 |
| `billing.discount` | `Decimal` | No | ≥ 0; `0` si `state = "sin_factura"` |
| `billing.discount_label` | `string` | Sí | `null` ⇒ la UI usa la etiqueta "Descuento" |
| `billing.delivery_fee` | `Decimal` | No | ≥ 0 |
| `billing.total` | `Decimal` | No | ≥ 0 |
| `billing.promotions` | `AppliedPromotionOut[]` | No | Puede ir vacío |
| `billing.sin_detalle_de_precios` | `bool` | No | — |

`AppliedPromotionOut`: `{ promotion_id: UUID \| null, name: string \| null, amount: Decimal }`.
`rule_id` del JSONB **no se publica**.

---

## 2. Garantías (lo que verifican los tests de contrato)

| # | Garantía | Requisito |
|---|---|---|
| G1 | `billing.subtotal == Σ item.line_total` de los ítems con `estado_cocina != "anulado"`, cuando `source = "pedido"` | FR-005, FR-019, SC-007 |
| G2 | `billing.total == billing.subtotal − billing.discount + billing.delivery_fee` y `>= 0`, **con `source = "pedido"` siempre; con `source = "factura"` mientras `tax = tip = 0`** (medido antes de implementar, D5; si dejara de cumplirse manda el total de la factura, FR-024) | FR-008, FR-024 |
| G3 | `state = "factura_propia"` ⇒ los cuatro importes son los de la `Sale` cuyo `customer_order_id` es este pedido | FR-024 |
| G4 | `state = "factura_agrupada"` ⇒ `source = "pedido"` | FR-024a |
| G4b | Un pedido `status = "cancelada"` **sin** venta propia ⇒ `state = "sin_factura"`, aunque su `table_session` tenga ventas | FR-024a, RN-005 |
| G5 | `state = "sin_factura"` ⇒ `discount == 0`, `discount_label == null`, `promotions == []` | FR-023 |
| G6 | `sin_detalle_de_precios == true` ⇔ hay ≥ 1 ítem no anulado y Σ de sus `line_total` es `0` | FR-018 |
| G7 | `discount_label` es el nombre de la única promoción con `amount > 0` tras agrupar por `promotion_id`; `null` con cero o con dos o más | FR-009, FR-010 |
| G8 | Ningún importe depende del catálogo ni de las promociones vigentes al consultar | RN-001, FR-022 |
| G9 | El número de sentencias SQL por petición es constante, independiente del número de ítems | — (guardia de N+1, mismo patrón que `test_orders_pagination.py`) |

---

## 3. Los tres casos, con ejemplo

### 3.1 `factura_propia` — la factura cubre solo este pedido

**Cuándo**: existe `Sale.customer_order_id = order.id`. Lo producen los cuatro caminos de
cobro por pedido (mostrador, `checkout-and-send`, aprobación de pago QR, confirmación de
efectivo) y el cierre de una mesa con **un solo** pedido.

```jsonc
"billing": {
  "state": "factura_propia", "source": "factura",
  "subtotal": "14000.00", "discount": "0.00", "discount_label": null,
  "delivery_fee": "0.00", "total": "14000.00",
  "promotions": [], "sin_detalle_de_precios": false
}
```

La UI muestra el desglose sin avisos. `total` es, por construcción, el mismo valor que el
módulo de Ventas (criterio 10 del brief).

### 3.2 `factura_agrupada` — la factura cubre varios pedidos

**Cuándo**: no hay venta propia, el pedido **no está cancelado**, y pertenece a una
`table_session` que sí tiene ventas. Cubre tanto el cierre unificado de varios pedidos como
el cierre dividido por comensal. Un pedido cancelado de esa misma sesión nunca se cobró, así
que cae en `sin_factura` (§3.3) y no recibe el aviso de FR-024a.

```jsonc
"billing": {
  "state": "factura_agrupada", "source": "pedido",
  "subtotal": "16000.00", "discount": "0.00", "discount_label": null,
  "delivery_fee": "0.00", "total": "16000.00",
  "promotions": [], "sin_detalle_de_precios": false
}
```

La UI muestra el desglose **y** el aviso literal de FR-024a.

### 3.3 `sin_factura` — el pedido todavía no se cobró

```jsonc
"billing": {
  "state": "sin_factura", "source": "pedido",
  "subtotal": "16000.00", "discount": "0.00", "discount_label": null,
  "delivery_fee": "3000.00", "total": "19000.00",
  "promotions": [], "sin_detalle_de_precios": false
}
```

La UI muestra `Subtotal + Envío`, sin fila de descuento, y el aviso literal de FR-023 —
salvo que el pedido esté cancelado (D7).

---

## 4. Casos límite del contrato

| Situación | Respuesta |
|---|---|
| Pedido sin ítems | `subtotal = 0`, `total = delivery_fee`, `sin_detalle_de_precios = false` |
| Todos los ítems anulados | `subtotal = 0`, `total = delivery_fee`, `sin_detalle_de_precios = false` (el `0` es real, FR-018) |
| Pedido `cancelada` en una sesión que sí tiene ventas | `state = "sin_factura"`, `source = "pedido"`; ningún aviso (D7 suprime el de FR-023) |
| Ítems no anulados que suman `0` | `sin_detalle_de_precios = true` |
| `delivery_fee` en `NULL` | Se publica `"0.00"`; la UI no pinta la fila (RN-004) |
| `applied_promotions` con dos entradas de la **misma** promoción (dos reglas) | `discount_label` = el nombre de esa promoción (D6) |
| `applied_promotions` con entradas de `amount = 0` | Se ignoran para elegir la etiqueta |
| Venta histórica con `tax` o `tip` > 0 | Los cuatro importes se publican tal cual; G2 no se garantiza para esa fila — medido antes de implementar (D5) |

---

## 5. Errores (sin cambios)

| Situación | Código | Cuerpo |
|---|---|---|
| El pedido no existe en el esquema del tenant de la sesión | `404` | `{"detail": "Order not found"}` |
| `order_id` no es un UUID | `422` | Error de validación estándar de FastAPI |
| Sin sesión válida | `401` | Estándar |

El `404` es el mismo para "no existe" y para "existe en otro tenant": no revela la
existencia del pedido (FR-025, RN-006).

---

## 6. Compatibilidad

- **Aditivo**: ningún campo se renombra, retira ni cambia de tipo.
- **Un cliente antiguo** ignora las claves nuevas y se comporta igual.
- **Un cliente nuevo contra un backend antiguo** recibe `billing` ausente y no pinta el
  resumen (D15) — no pinta ceros.
- El `ETag` de `GET /orders` cambia una vez al desplegar, por el cuerpo nuevo.
