# Data Model: Migrar vista del módulo de Órdenes al nuevo diseño

**Spec**: [spec.md](./spec.md) · **Research**: [research.md](./research.md)

No se crean entidades nuevas ni se modifica el esquema de base de datos (Principio VIII: N/A, sin migración). Este documento describe las entidades ya existentes tal como las consume la vista migrada, y los valores de solo-presentación que se derivan de ellas.

## Entidades existentes (sin cambios de esquema)

### Orden (`CustomerOrder` / `DiningOrder`)

Ya existente (`pos-backend: app/models/customer_order.py`; `pos-heladeria: DiningOrder` en `dining.interface.ts`). Campos relevantes para esta vista:

| Campo | Tipo | Uso en la vista migrada |
|---|---|---|
| `id` | UUID | Base del código corto de presentación (ver "Valores derivados") y de la búsqueda `q`. |
| `customer_name` | string \| null | Nombre del cliente en tarjeta y detalle; búsqueda `q`. Ausente ⇒ se omite la fila (FR-016), nunca "Cliente sin nombre" salvo el criterio ya establecido en spec 087/094 para el encabezado de detalle. |
| `order_type` | `'DINE_IN' \| 'TAKEAWAY' \| 'DELIVERY' \| null` | Filtro de tipo (FR-003); determina si se muestra el bloque de domicilio (FR-013). |
| `status` | `DiningOrderStatus` (`recibida\|abierta\|bloqueada\|pagada\|cancelada`) | Filtro y badge de estado (FR-002, FR-011), sin cambios de significado (research.md §4). |
| `paid` | boolean | Junto con `status`, determina el badge de "Estado de pago" (`displayOrderStatus`, ya existente). |
| `dining_table_id` | UUID \| null | Determina la "ubicación" (mesa) en el bloque de información de la orden (FR-012). |
| `delivery_address` / `delivery_phone` | string \| null | Bloque de datos de domicilio (FR-013), sin cambios. |
| `created_at` | timestamp | Hora en tarjeta/detalle; base del nuevo filtro `date_from`/`date_to` (research.md §1). |
| `items` | `DiningOrderItem[]` | Resumen de ítems del detalle (FR-014), sin cambios de estructura. |
| `billing` | `OrderBilling \| null` | Desglose de totales (FR-015), sin cambios de estructura ni de reglas (`muestraImportes()`, avisos existentes). |
| `invoice_reference` *(nuevo)* | string \| null | **Corrección post-implementación** (reportada por el negocio): campo "Referencia" de factura (FR-012). `GET /orders/{id}` lo resuelve contra la `Sale`/`Invoice` real de la orden (`app/api/v1/orders/service.py::invoice_and_payment_info`), mismo formato que `InvoiceResponse.full_number` (`prefix + número relleno a 6 dígitos`, p. ej. `"A-000004"`). `null` si la orden todavía no tiene `Sale`/`Invoice` — nunca inventado. **Solo lo rellena el detalle**, igual que `billing` (D3); en el listado no viaja. |
| `payment_method_name` *(nuevo)* | string \| null | **Corrección post-implementación**: nombre real del método de pago, leído de `Sale.payments` — a diferencia de `current_payment_attempt` (que solo existe para pedidos cobrados por QR; los cobrados por mostrador nunca crean un intento de pago y antes dejaban esta fila siempre vacía). `null` si la orden no tiene `Sale` todavía. Solo en el detalle. |

Los dos campos nuevos (`invoice_reference`, `payment_method_name`) son la única adición de esquema de respuesta de esta feature — se agregaron tras el primer despliegue al descubrir que el código corto derivado del `id` (ver abajo) no era una "Referencia" de factura real, y que `current_payment_attempt` no cubre el camino de cobro por mostrador. No requieren migración: se resuelven en el servidor a partir de relaciones ya existentes (`Sale.invoice`, `Sale.payments` → `PaymentMethod`).

## Nuevos parámetros de consulta (backend, aditivos)

`GET /orders` (`pos-backend: app/api/v1/orders/router.py`) — parámetros opcionales nuevos, combinables con AND entre sí y con `status`/`order_type` ya existentes:

| Parámetro | Tipo | Semántica |
|---|---|---|
| `date_from` | `date \| null` | Filtra `created_at >= date_from` (inclusive), misma semántica que `GET /sales`. |
| `date_to` | `date \| null` | Filtra `created_at <= date_to` (inclusive, fin de día), misma semántica que `GET /sales`. |
| `q` | `str \| null` | Coincidencia parcial, insensible a mayúsculas, contra `customer_name` **o** `id::text` (research.md §2). |

Sin cambios en la forma de la respuesta: sigue siendo `Page[OrderResponse]` (misma paginación, mismos campos por orden).

## Valores derivados de solo presentación (frontend, no persistidos)

### Código corto de orden

```
displayCode(order): string
  = '#' + order.id.replace('-', '').slice(-6).toUpperCase()
```

Usado en: tarjeta de la lista (FR-001), encabezado del detalle (FR-011). Debe coincidir con el criterio de búsqueda `q` del backend (research.md §2): buscar el código mostrado debe encontrar la orden.

**Corrección**: el campo "Referencia" de factura del bloque "Información de factura" (FR-012) **ya no usa este código** como fuente principal — usa `invoice_reference` (ver arriba) cuando la orden ya tiene una factura real, y cae a este código corto solo como respaldo mientras la orden no se ha cobrado (para no dejar la fila vacía). El encabezado del detalle y la tarjeta de la lista siguen mostrando siempre el código corto (es el identificador estable de la orden, distinto de su factura).

### Ubicación mostrada

```
locationLabel(order):
  si order.dining_table_id existe → nombre/zona de la mesa (ya resuelto hoy por TableService)
  si no, y order.order_type !== 'DELIVERY' → 'Mostrador'
  si order.order_type === 'DELIVERY' → (no se muestra; se reemplaza por el bloque de domicilio, FR-013)
```

Mismo criterio que ya usa hoy `orders-page.component.ts` (`tableLabel()`), extendido al detalle para que ambas pantallas sean consistentes (spec, Assumptions).

### Estado de pago (badge)

Reutiliza `displayOrderStatus(order)` + `paid` ya existentes (`order-status.util.ts`): `Pagado` si `paid === true`, `Pendiente` en otro caso (salvo `cancelada`, que se muestra como tal). Sin cambios de lógica, solo de estilo visual del badge.

### Método de pago (detalle, condicional)

Se muestra únicamente cuando la orden ya tiene un pago/venta asociada que exponga el método (dato ya resuelto por el backend en la información de pago de la orden); si no existe, la fila se omite (FR-016) — no se agrega ninguna consulta nueva para resolverlo, se usa lo que la orden ya trae hoy.

## Filtro de órdenes (estado de UI, no persistido)

Estado combinado que determina qué se lista — vive en `OrdersListService` (frontend), análogo a `SalesService`:

| Campo | Tipo | Valor por defecto |
|---|---|---|
| `status` | `OrdersStatusFilter` (ya existente) | `''` (Todos) |
| `orderType` | `OrdersTypeFilter` (ya existente) | `''` (Todos) |
| `search` (nuevo) | `string` | `''` |
| `dateFrom` (nuevo) | `string` (ISO date) | fecha de hoy (spec, Assumptions) |
| `dateTo` (nuevo) | `string` (ISO date) | fecha de hoy (filtro de un solo día por defecto; `dateFrom === dateTo`) |
| `page` / `size` | `number` (ya existentes) | `1` / `20` |

Cambiar cualquier filtro vuelve a la página 1, igual que el comportamiento ya existente de `setStatus`/`setOrderType`.
