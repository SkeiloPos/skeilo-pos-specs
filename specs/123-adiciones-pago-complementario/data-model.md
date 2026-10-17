# Modelo de Datos — Spec 123

**Spec**: [spec.md](./spec.md) · **Investigación**: [research.md](./research.md)

Dos migraciones Alembic additivas. Ninguna reescribe, recalcula ni cambia el significado de una
fila existente (Principio VII); ambas son reversibles con `DROP COLUMN` sin pérdida de datos de
negocio, porque son columnas nuevas que no reemplazan ninguna existente.

## 1. `order_item_options` — columnas nuevas

Tabla existente (modelo `OrderItemOption`, `app/models/order_item.py`, L104-134). Columnas nuevas:

| Columna | Tipo | Null | Default | Significado |
|---|---|---|---|---|
| `added_after_sale` | `boolean` | NO | `false` | `true` si, al insertarse esta fila, el pedido ya tenía al menos una `Sale` con `status='paid'`. Se fija una sola vez al crear la fila; nunca se recalcula después. |
| `complementary_sale_id` | `uuid` | SÍ | `NULL` | FK a `sales.id`. Se llena exactamente una vez, al cobrarse con éxito el pago complementario que cubre esta adición (ver `sales.kind` abajo). `NULL` mientras el saldo sigue pendiente. |

**Compatibilidad con filas existentes**: toda fila `OrderItemOption` creada antes de esta
funcionalidad recibe `added_after_sale=false` y `complementary_sale_id=NULL` por el `DEFAULT` de la
migración — exactamente el comportamiento que ya tenían (nunca formaron parte de un saldo
pendiente, porque el concepto no existía). Ningún query ni reporte que lea `OrderItemOption` sin
filtrar por estas columnas nuevas ve ningún cambio.

**Invariante de aplicación** (no de base de datos, mismo criterio que `D3` de `research.md`):
`complementary_sale_id IS NOT NULL` ⇒ `added_after_sale = true`. Una adición cubierta por un pago
complementario necesariamente nació después de una `Sale` ya emitida — se valida en
`settle_pending_balance`, no con un CHECK de SQL.

**Saldo pendiente del pedido (valor calculado, no columna)**:

```sql
SELECT COALESCE(SUM(o.extra_price * oio.quantity), 0)
FROM order_item_options oio
JOIN order_items oi ON oi.id = oio.order_item_id
JOIN options o ON o.id = oio.option_id
WHERE oi.order_id = :order_id
  AND oi.estado_cocina <> 'anulado'
  AND oio.added_after_sale = true
  AND oio.complementary_sale_id IS NULL
```

(Expresión ilustrativa — `Option.extra_price` confirmado contra `app/models/option.py`;
`OrderItemOption` no tiene columna de precio propia, el precio siempre se lee de la opción vía
`option_id`. El cálculo real vive en Python junto a `has_billable_orders`, no como vista SQL.)

## 2. `sales` — columna nueva

Tabla existente (modelo `Sale`, `app/models/sale.py`, L17-128).

| Columna | Tipo | Null | Default | Significado |
|---|---|---|---|---|
| `kind` | `varchar` | NO | `'original'` | `CHECK (kind IN ('original', 'complementario'))`. Distingue la venta/factura que se cobró en el flujo normal (`'original'`) de la que liquida un saldo pendiente generado por adiciones post-hoc (`'complementario'`). |

**Compatibilidad con filas existentes**: toda `Sale` emitida antes de esta funcionalidad recibe
`kind='original'` por el `DEFAULT` — es exactamente lo que era (la única clase de venta que existía
hasta ahora). Ningún reporte que agrupe por `Sale` sin filtrar por `kind` cambia de resultado (ej.
`reconcile`, que agrupa por `cash_shift_id` sin importar `kind` — una `Sale` complementaria se
contabiliza en el turno igual que cualquier otra, consistente con FR-013).

**Relación con el pedido**: se reutiliza la columna ya existente `customer_order_id` (sin cambios)
— una `Sale` con `kind='complementario'` tiene el mismo `customer_order_id` que la `Sale` original
que facturó el pedido. No se agrega ninguna relación `Sale → Sale`; ambas se relacionan
transitivamente a través del pedido, nunca entre sí directamente (consistente con FR-011: la
factura complementaria nunca "referencia" ni "reemplaza" a la original, solo comparte el pedido).

**Multiplicidad**: un mismo `customer_order_id` puede tener, con esta spec, más de una `Sale` con
`kind='original'`... **no** — seguirá teniendo como máximo una `Sale` `kind='original'` (sin
cambios al flujo de cobro normal) pero puede tener **cero o varias** `Sale` con
`kind='complementario'` a lo largo del tiempo, una por cada ciclo de saldo pendiente liquidado
(FR-022). Esta multiplicidad es exactamente lo nuevo que esta spec introduce al modelo.

## 3. Entidades conceptuales (sin tabla propia)

- **Saldo pendiente del pedido**: ver fórmula de la sección 1. Vive por `order_id`, se recalcula en
  cada lectura, nunca se persiste. Cuando es `0`, el pedido no bloquea "Liberar Mesa" (FR-016) y no
  muestra la acción "Cobrar saldo" (FR-006c).
- **Pago complementario**: no es una entidad de datos nueva — es el acto de llamar `build_sale(...,
  kind='complementario')` sobre el conjunto de `OrderItemOption` pendientes de un pedido. Su
  "existencia" se observa a través de la `Sale` que produce.

## Resumen de migración

```text
Revision: add_order_item_addition_tracking_and_sale_kind
Up:
  ALTER TABLE order_item_options
    ADD COLUMN added_after_sale boolean NOT NULL DEFAULT false,
    ADD COLUMN complementary_sale_id uuid NULL REFERENCES sales(id);
  ALTER TABLE sales
    ADD COLUMN kind varchar NOT NULL DEFAULT 'original'
      CONSTRAINT ck_sales_kind CHECK (kind IN ('original', 'complementario'));
Down:
  ALTER TABLE sales DROP CONSTRAINT ck_sales_kind, DROP COLUMN kind;
  ALTER TABLE order_item_options
    DROP COLUMN complementary_sale_id,
    DROP COLUMN added_after_sale;
```

Ejecuta sobre cada esquema de tenant (esquema-por-tenant, `pos-backend` ya tiene el runner de
migraciones multi-tenant existente — no se agrega infraestructura de migración nueva).
