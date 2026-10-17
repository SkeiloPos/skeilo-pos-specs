# Data Model: Rediseño del módulo Dashboard según el prototipo

**Spec**: [spec.md](spec.md) · **Research**: [research.md](research.md)

No hay migraciones de base de datos — ningún campo nuevo se persiste. Todo lo de aquí es forma de **respuesta** (backend) o **estado derivado de UI** (frontend), construido sobre datos y tablas que ya existen (`Payment`, `Sale`, `CashShift`, `PaymentMethod`, `User`, `InventoryItem`).

## 1. `user_data` (sesión/JWT) — campo nuevo, backend

Extiende el diccionario que arman `POST /auth/login` y `POST /auth/refresh` (`app/api/v1/auth/routes.py`), sin pasar por ningún schema Pydantic (es un `dict` crudo que se firma como claims y se devuelve tal cual en el body de login).

| Campo | Tipo | Presencia | Descripción |
|---|---|---|---|
| `name` | `str` | Nuevo, siempre presente (`User.name` es `NOT NULL`) | Nombre real del usuario autenticado, leído de `User.name`. |

**Compatibilidad**: un JWT ya emitido antes de este cambio no trae `name` — el frontend lo trata como ausente (ver §2) y degrada al nombre derivado del correo, sin error.

## 2. `BackendUser` / `User` (frontend)

| Interfaz | Campo | Cambio |
|---|---|---|
| `BackendUser` (`core/auth/auth.models.ts`) | `name?: string` | Nuevo, opcional (compat con JWT antiguo) |
| `User` (`core/interfaces/user.interface.ts`) | `name?: string` | Ya existía; solo se actualiza el comentario que decía "el backend no lo devuelve" |

`buildUserFromBackend` pasa de `name: displayNameFromEmail(backend.email)` a `name: backend.name || displayNameFromEmail(backend.email)`.

## 3. `GET /cash/reports/payment-methods` — endpoint nuevo, backend

Response shape (envoltorio + lista de filas bucketed), protegido por `require_tenant_admin`, misma familia que `/cash/reports/current` y `/cash/reports/period`.

| Campo | Tipo | Descripción |
|---|---|---|
| `bucket_unit` | `"hour" \| "day" \| "week"` | Unidad de tiempo de **toda** la respuesta — un solo valor, no se repite por fila. |
| `rows` | `list[{bucket_start, payment_method_id, payment_method_name, amount}]` | Una fila por `(bucket, método)` con pagos > 0. |

Campos de cada fila de `rows`:

| Campo | Tipo | Descripción |
|---|---|---|
| `bucket_start` | `datetime` (UTC) | Inicio del intervalo (hora/día/semana, según `bucket_unit`). |
| `payment_method_id` | `UUID` | Método de pago. |
| `payment_method_name` | `str` | Nombre del método (snapshot al momento de la consulta — ver Key Entities). |
| `amount` | `Decimal` | Suma de `Payment.amount` de ese método en ese bucket. |

Cero filas para un bucket/método sin pagos (no se rellenan con `amount: 0`; el frontend decide si completar huecos para que el gráfico tenga todas las barras).

### Request

Mismos parámetros que `/cash/reports/current` + `/cash/reports/period`, unificados (research.md §6):

| Parámetro | Tipo | Requerido | Descripción |
|---|---|---|---|
| `period` | `shift\|current_shift\|day\|week\|month\|range` | Sí | Igual semántica que el selector de período ya existente. |
| `shift_id` | UUID | Solo si `period=shift` | Turno específico. |
| `date` | date | No (day/week/month) | Día de referencia. |
| `date_from`/`date_to` | date | Obligatorios si `period=range` | Límites del rango. |
| `cash_register_id` | UUID | No | Filtra por caja. |

## 4. Entidades internas de la consulta (no expuestas, solo cálculo)

- **Turno en alcance**: igual selector que `aggregate_shifts` ya usa (`CashShift` filtrado por `shift_selector`/`period_selector`/`open_shifts_selector` según `period`) — determina qué `Sale`/`Payment` entran en la agregación.
- **Bucket**: `date_trunc('hour'|'day'|'week', Payment.paid_at en zona del tenant)`, unidad elegida por el `period` resuelto (research.md §6: hora para turno/día, día para semana, semana para mes, día para rango).

## 5. KPI del reporte operativo (frontend, sin cambio de forma de datos)

No es una entidad nueva — es una vista de 4 campos ya existentes, ensamblada en el componente:

| KPI | Fuente | Texto secundario |
|---|---|---|
| Ventas | `PeriodSalesReport.total_sales` | "Total del período" |
| Órdenes | `PeriodSalesReport.order_count` | "Total del período" |
| Ticket promedio | `PeriodSalesReport.avg_ticket` | "Por orden" |
| Órdenes activas | `activeOrdersCount()` (ya calculado) | "En cocina" |

## 6. Serie de tendencia reciente (frontend, consume `GET /reports/sales` ya existente)

| Campo | Fuente |
|---|---|
| Ventas por día | `by_day[].total` (`GET /reports/sales`, RF-059) |
| Órdenes por día | `by_day[].count` |
| Ticket promedio por día | `by_day[].total / by_day[].count` (derivado en frontend) |

## 7. `LowStockItem` (ya existente, sin cambios)

`InventoryService.lowStockItems: LowStockItem[]` (`{id, name, current_stock, min_stock}`) — consumido tal cual, ya poblado por `loadLowStock()`.
