# Contrato — Bloqueo de cierre por pedidos activos

**Spec**: [../spec.md](../spec.md) · **Data model**: [../data-model.md](../data-model.md) §1.6 ·
**Research**: [../research.md](../research.md) D1

Alcance de "pedido activo" en todo este contrato: **tenant-wide**, no filtrado por caja/turno (ver
research.md D1) — `CustomerOrder.status IN ('recibida', 'abierta', 'bloqueada')`.

## `GET /cash/active-orders`

Lista los pedidos activos del tenant que bloquearían cualquier intento de cierre en este momento
(US3, US4-conteo). Autenticación: `get_current_user` (mismo nivel que `close_shift` — cualquier
cajero autenticado, no solo admin, porque es quien ejecuta el cierre).

**Query**: ninguno.

**Respuesta 200** (`list[ActiveOrderSummary]`):

```jsonc
[
  {
    "id": "uuid",
    "order_type": "DINE_IN" | "TAKEAWAY" | "DELIVERY" | null,
    "status": "recibida" | "abierta" | "bloqueada",
    "dining_table_id": "uuid" | null,
    "table_number": 4 | null,
    "customer_name": "Juan Pérez" | null,
    "created_at": "2026-10-13T01:40:00-05:00"
  }
]
```

`[]` cuando no hay ningún pedido activo — respuesta válida, no un estado especial.

## `POST /cash/shifts/{shift_id}/close` — cambio de comportamiento

**Sin cambio de schema de request ni de éxito** (`ShiftClose` → `ShiftResponse`, igual que hoy).

**Nuevo**: antes de calcular el arqueo (inserción exacta: entre la verificación de
`status != "closed"` y el cálculo de `counted`, `app/api/v1/cash/router.py:105-107`), el sistema
ejecuta la misma consulta que `GET /cash/active-orders`. Si devuelve al menos un pedido:

**Respuesta 409** (nueva forma de error, antes este código no existía para este endpoint):

```jsonc
{
  "detail": "No se puede cerrar el turno: hay 2 pedidos activos sin cobrar.",
  "active_orders": [ /* mismo shape que GET /cash/active-orders */ ]
}
```

El cierre **no** continúa — no se calcula arqueo, no se persiste `close_note`, no se escribe
`shift_sales_reports`. El turno permanece `open` exactamente como antes del intento.

**Comportamiento sin cambios cuando no hay pedidos activos**: el resto de `close_shift` (RN-CASH-09
a RN-CASH-11, `specs/006-turnos-caja-arqueo`) corre exactamente igual que hoy — denominaciones,
`close_note` obligatoria si la diferencia no cuadra, etc. — y, al completarse con éxito, además
calcula y persiste la fila de `shift_sales_reports` (ver
[shift-sales-report-api.md](./shift-sales-report-api.md), data-model.md §2) dentro de la misma
transacción.

## Re-evaluación en cada intento (edge case de `spec.md`)

`GET /cash/active-orders` y la validación interna de `close_shift` ejecutan la **misma consulta
en el momento de la llamada**, sin caché ni lista memorizada de un intento anterior. Si un pedido
que bloqueaba el cierre se cobra o se anula entre dos intentos (por el mismo cajero o por otro
usuario), el segundo intento de cierre ya no lo incluye — sin necesidad de refrescar manualmente
ningún estado del cliente más allá de volver a llamar al endpoint.

## Cómo se obtiene el resultado (US6, FR-023)

El resultado visible no cambia (contador, lista y su orden); cambia el costo:

- El **contador** de pedidos activos —el que acompaña al reporte de un turno abierto
  (`active_orders_count`, FR-012) y el que decide el bloqueo de `close_shift` (FR-007)— se obtiene
  con un conteo en la base de datos, sin traer las filas.
- La **lista completa** (`GET /cash/active-orders` y el cuerpo `active_orders` del 409) solo se
  consulta cuando hay que mostrarla: `close_shift` cuenta primero y, únicamente si el contador es
  mayor que cero, trae la lista. Si entre el conteo y la lista el pedido se cobró o se anuló, el
  cierre continúa con el estado vigente.
- Ambas consultas usan el índice parcial que ya existe sobre `customer_orders`
  (`idx_active_order_per_participant`); no se crea ninguno nuevo (research.md D12).
- Sin coordinación con la creación de pedidos (mejor esfuerzo): un pedido creado entre el conteo y
  el guardado del cierre no lo impide, y bloquea el cierre del turno siguiente (Edge Cases y SC-002).

## Qué NO expone este contrato

- Ninguna acción de "cobrar" ni "anular" nueva — `ActiveOrderSummary.id` es el mismo `id` de
  `CustomerOrder` que ya consumen las pantallas de Mesas/Para llevar/Domicilios existentes; la UI
  navega hacia esas pantallas ya existentes para resolver cada pedido (FR-008: solo esas dos
  acciones, ninguna nueva).
- Ninguna acción de "transferir pedido a otro turno" (explícitamente descartada en Clarifications
  de `spec.md`).
