# Contrato — Reporte operativo de ventas por turno

**Spec**: [../spec.md](../spec.md) · **Data model**: [../data-model.md](../data-model.md) §2-3

Todos los endpoints de este contrato son **nuevos**, bajo el prefijo `/cash` ya existente. Ninguno
modifica `app/api/v1/reports/*`. Autenticación: `require_tenant_admin` (mismo nivel que
`GET /cash/shifts` histórico y que `/reports/*` — la spec describe esta pantalla como de
"administradores y dueños").

## `GET /cash/shifts/{shift_id}/sales-report`

Reporte operativo de **un** turno puntual (US1, US4, US5).

**Query**: ninguno — el turno ya fija el alcance.

**Respuesta 200** (`ShiftSalesReportResponse`):

```jsonc
{
  "shift_id": "uuid",
  "cash_register_id": "uuid",
  "cash_register_name": "Caja 1",
  "status": "open" | "closed",
  "is_live": true,              // true si status="open", o si status="closed" sin snapshot (D8)
  "opened_at": "2026-10-12T17:00:00-05:00",
  "closed_at": "2026-10-13T02:00:00-05:00" | null,
  "total_sales": "450000.00",
  "order_count": 18,
  "avg_ticket": "25000.00",
  "top_products": [
    { "product_variant_id": "uuid", "name": "Helado 1/2L Chocolate", "units": 12, "revenue": "180000.00" }
  ],
  "categories": [
    { "category_id": "uuid", "category_name": "Helados", "units": 34, "revenue": "510000.00" }
  ],
  "active_orders_count": 2 | null   // solo relevante/no-null cuando status="open" (FR-012)
}
```

**Errores**:
- `404` — `shift_id` no existe en el tenant autenticado (mismo criterio que `GET /cash/shifts/{id}`).
- Aislamiento multi-tenant: resuelto automáticamente por `schema_translate_map` (ningún `shift_id`
  de otro tenant es visible, ni siquiera para devolver `404` distinguible — mismo comportamiento
  que el resto de `/cash/*`).

**Turno sin ventas (US5)**: `total_sales="0.00"`, `order_count=0`, `avg_ticket="0.00"`,
`top_products=[]`, `categories=[]` — nunca un error ni una división por cero.

## `GET /cash/reports/current`

Reporte agregado del/de los turno(s) **actualmente abiertos** (US4, FR-012).

**Query**: `cash_register_id?` (UUID, opcional).

- **Con `cash_register_id`**: si esa caja tiene un turno abierto, devuelve su reporte (mismo shape
  que `sales-report` de ese turno); si no tiene turno abierto, `404` "La caja no tiene un turno
  abierto" (mismo mensaje que `GET /cash/shifts/current`).
- **Sin `cash_register_id`**: agrega en tiempo real **todos** los turnos `open` del tenant
  (puede ser cero, uno o varios). Con cero turnos abiertos: `200` con todos los totales en cero
  (no `404` — "no hay turno abierto en ninguna caja" es un estado válido del reporte, no un
  error, a diferencia de pedir explícitamente una caja sin turno).

**Respuesta 200** (`PeriodSalesReportResponse`, ver forma completa más abajo en este contrato) con
`period="current_shift"`.

**Contador de pedidos activos (FR-012)**: esta respuesta **no** incluye `active_orders_count`
(`PeriodSalesReportResponse` no tiene ese campo). Para mostrar el contador en "Turno actual", el
cliente consulta `GET /cash/active-orders` y usa la longitud de la lista (dos llamadas; así el
contrato de los endpoints de período no cambia con US6). El contador es el de **todo el tenant**,
con el mismo alcance que el bloqueo de cierre (FR-007, research.md D1), también cuando se filtra por
`cash_register_id`. El campo `active_orders_count` solo existe en `ShiftSalesReportResponse`
(`GET /cash/shifts/{shift_id}/sales-report`, turno individual abierto).

## `GET /cash/reports/period`

Reporte agregado por día, semana, mes o rango personalizado (US2, FR-005/FR-006/FR-017).

**Query**:
- `period`: `"day" | "week" | "month" | "range"` (obligatorio).
- `date` (`YYYY-MM-DD`, requerido si `period="day"`): día de referencia, en fecha de negocio del
  tenant.
- `date_from`/`date_to` (`YYYY-MM-DD`, requeridos si `period="range"`).
- `cash_register_id?` (UUID, opcional) — si se omite, agrega todas las cajas del tenant.

Para `period="week"`, el rango cubre la semana calendario (lunes a domingo) a la que pertenece
`date` — o la semana actual en fecha de negocio del tenant si no se pasa `date`. Para
`period="month"`, el rango cubre del día 1 al último día del mes calendario de `date` — o el mes
actual si no se pasa `date`. `date` es opcional para `week`/`month` (research.md D4, confirmado con
el usuario 2026-10-15: semana/mes **calendario**, no ventana móvil).

**Respuesta 200** (`PeriodSalesReportResponse`):

```jsonc
{
  "period": "day" | "week" | "month" | "range" | "current_shift",
  "date_from": "2026-10-13",
  "date_to": "2026-10-13",
  "cash_register_id": "uuid" | null,
  "shift_ids": ["uuid", "uuid"],
  "is_live": false,
  "total_sales": "450000.00",
  "order_count": 18,
  "avg_ticket": "25000.00",
  "top_products": [ /* top-10 recombinado, ver data-model.md §3 */ ],
  "categories": [ /* desglose completo recombinado */ ]
}
```

**Errores**:
- `422` — falta `date_from`/`date_to` con `period="range"`, o `date_from > date_to`.
- `404` — `cash_register_id` no existe en el tenant.

**Aislamiento por caja (FR-011/SC-004)**: con `cash_register_id` fijado, ningún turno de otra caja
participa en la suma — verificado reutilizando el mismo filtro `cash_register_id` que ya aplica
`GET /cash/shifts` histórico sobre `cash_shifts`.

## Orden determinista y presupuesto de consultas (US6)

**Sin cambio de forma**: ningún campo, tipo ni código de error de los tres endpoints cambia con US6.
Las dos garantías siguientes son de comportamiento observable y de costo.

**Orden determinista (FR-022)** — aplica igual a `top_products` y `categories` de los tres
endpoints (turno, "turno actual" y período):
1. `revenue` descendente;
2. en empate, nombre ascendente (`name` / `category_name`);
3. en empate de nombre, identificador ascendente (`product_variant_id` / `category_id`; el
   `category_id` nulo —"Sin categoría"— va al final).

Los mismos datos devuelven siempre el mismo orden. Es la **única** diferencia posible frente a la
implementación anterior, y solo ante empates exactos de ingreso (antes dependía del orden en que se
recorrían los turnos). El nombre mostrado de cada producto/categoría no cambia: el del turno más
antiguo del período en que aparece (dentro de un turno, el mayor valor de su descripción).

**Presupuesto de consultas (FR-018)** — el reporte de un turno, de "turno actual" o de un período
ejecuta un número **fijo** de consultas para armar las métricas (turnos, totales, productos,
categorías), independiente de cuántos turnos incluye y de cuántos están con snapshot, abiertos o
cerrados sin snapshot (D8). No existe tope de días para `period="range"`.

## Reutilización explícita de patrones existentes

- El join `Sale → SaleItem → ProductVariant → Product → Category` y el manejo de categoría nula
  ("Sin categoría") son idénticos a `app/api/v1/reports/service.py::products_report`/
  `categories_report` — solo cambia el filtro (`cash_shift_id IN (...)` en vez de rango de
  `sold_at`).
- La resolución de zona horaria (`resolve_timezone`, `local_day_bounds_utc`,
  `app/core/timezone.py`) es la misma que ya usa `reports/service.py` para "hoy" en fecha de
  negocio del tenant — se aplica aquí sobre `CashShift.opened_at` en vez de `Sale.sold_at`.
