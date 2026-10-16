# Data Model: Correcciones visuales y funcionales de la lista de Órdenes

**Spec**: [spec.md](spec.md) · **Research**: [research.md](research.md)

No hay entidades de base de datos nuevas ni migraciones — ningún campo se persiste. Todo lo descrito aquí es forma de **respuesta** (backend) o **estado de UI derivado** (frontend), coherente con las decisiones de research.md.

## 1. `OrderResponse.total` (nuevo campo, backend)

Extiende `OrderResponse` (`pos-backend/app/api/v1/orders/schemas.py`), el modelo que ya sirve tanto `GET /orders` como `GET /orders/{id}`.

| Campo | Tipo | Presencia | Descripción |
|---|---|---|---|
| `total` | `Decimal \| None` | Nuevo | Monto final de la orden (mismo valor y misma fórmula de 3 ramas que `billing.total`: lee `Sale.total` cuando la orden tiene factura propia; si no, `suma_de_líneas no anuladas − descuento + domicilio`, nunca negativo). |

**Reglas de población** (quién lo calcula y cuándo):

- **Detalle** (`GET /orders/{id}`, `_load_order`): siempre poblado, derivado de `billing.total` ya calculado (cero costo adicional).
- **Listado paginado** (`GET /orders?page=&size=`, la pantalla "Órdenes" de esta spec): siempre poblado, mediante las dos consultas en bloque descritas en research.md §1 — nunca una consulta por fila.
- **Listado sin paginar** (`GET /orders` sin `page`/`size`, consumido por Terminal de Mesas/Dashboard): se queda `None`, igual que `billing` hoy — esa rama está fuera del alcance de esta spec (research.md §1, Principio III).

**No es un campo nuevo de negocio**: es la misma cifra que `billing.total` ya calcula para el detalle; `total` solo la hace disponible también donde `billing` permanece `null` a propósito (el listado), sin alterar ese contrato ya protegido (D3/D15 de spec 094/120).

**Compatibilidad**: campo aditivo y opcional (`None` por defecto) — ningún consumidor existente de `OrderResponse` se rompe por su ausencia o presencia.

## 2. `DiningOrder.total` (nuevo campo, frontend)

Extiende la interfaz `DiningOrder` (`pos-heladeria/src/app/modules/tables/interfaces/dining.interface.ts`), espejo de `OrderResponse`.

| Campo | Tipo | Descripción |
|---|---|---|
| `total` | `string \| null` *(opcional)* | Igual que los demás importes `Decimal` del contrato (`billing.total`, `OrderBilling.delivery_fee`, etc.), serializados como texto. Opcional para tolerar una ventana de despliegue donde el frontend nuevo todavía hable con un backend sin este campo. |

## 3. Fecha vigente del filtro (estado de UI, frontend)

No es una entidad persistida — es el estado ya existente en `OrdersListService` (`dateFrom`/`dateTo`, signals) y en `OrderDateFilterComponent`. El cambio de research.md §2 no añade campos: convierte la propiedad `value` del componente hijo de `@Input()` corriente a signal de entrada (`input()`), para que el texto mostrado (`label`) se recalcule correctamente cuando el valor cambia. No hay nuevo estado, solo una fuente de verdad reactiva donde antes no la había.

## 4. Rango de paginación (estado derivado, frontend)

No es una entidad nueva: se deriva, sin llamada adicional al backend, de los signals que `OrdersListService` ya expone:

| Derivado | Fórmula | Fuente |
|---|---|---|
| Inicio del rango visible | `(page() - 1) * size() + 1` | `OrdersListService.page()`, `.size()` |
| Fin del rango visible | `min(page() * size(), total())` | `OrdersListService.page()`, `.size()`, `.total()` |

El nuevo paginador propio de la pantalla "Órdenes" (research.md §3) consume estos mismos tres signals — ya existentes, sin cambios en `OrdersListService` ni en el contrato de `GET /orders` (que ya devuelve `page`, `size`, `total`, `pages` vía `Page[T]`, `app/core/pagination.py`).

## 5. Badges de estado (sin cambio de datos)

No hay cambio de modelo: `orderStatusClass`/`orderStatusLabel` (`order-status.util.ts`) siguen devolviendo las mismas combinaciones `label`/`classes` por estado. El ajuste de research.md §4 es puramente de presentación (CSS/clases), no de datos.
