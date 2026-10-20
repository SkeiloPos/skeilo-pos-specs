# Contrato: Bloqueo de "Salir" con pago pendiente (FR-009 a FR-012)

## `POST /cart/leave`

**Cambio de contrato** (research.md Decisión 7): deja de ser infalible. Requiere entrada previa
en `specs/000-reconocimiento/registro-de-anomalias.md` (Principio II) antes de implementarse.

**Request**: sin cambios (`x-session-token` header).

**Response — éxito (sin pedidos propios con pago pendiente)**: `200`, sin cambios — cierra la
sesión del participante y libera la mesa si corresponde (`RN-CART-15`, sin alterar esa regla,
FR-012).

**Response — bloqueado (NUEVO)**: `409 Conflict`.

```json
{
  "error": "pago_pendiente",
  "message": "Tienes un pago pendiente. Para salir, dirígete a la caja. Si no deseas llevar tu pedido, indícalo allí."
}
```

La sesión del participante **permanece activa** — no se marca `closed`, no se invalida el acceso
(FR-010). El cuerpo exacto del error se confirma en `/speckit-tasks` contra el patrón de errores ya
usado por otros `409` del mismo router (`app/api/v1/cart/router.py`).

**Criterio de "pago pendiente" (evaluado solo sobre pedidos propios del participante que invoca,
FR-009/FR-011, Clarificación Q2)**:

```
EXISTS (
  SELECT 1 FROM customer_orders o
  JOIN order_payment_attempts a ON a.order_id = o.id   -- el más reciente (current_payment_attempt)
  WHERE o.participant_id = :participant_id
    AND o.status <> 'cancelada'
    AND NOT (
      (a.cash_amount IS NULL AND a.status = 'confirmado')                                    -- efectivo o transferencia puros, ya confirmados
      OR (a.cash_amount IS NOT NULL AND a.status = 'confirmado' AND a.cash_confirmed_at IS NOT NULL)  -- mixto, ambas partes confirmadas
    )
)
```

**Llamadores a inventariar en `/speckit-tasks`** (research.md Decisión 7): cualquier otro punto
del backend o del frontend que invoque `leave_session`/`POST /cart/leave` asumiendo hoy que nunca
falla debe revisarse contra este nuevo `409`.

## Frontend — `public-menu.component.ts::confirmExit()`/`exit()`

No es un contrato HTTP, pero fija el comportamiento esperado del cliente (research.md Decisión 8):

1. Si los pedidos ya cargados del comensal (pestaña "Mis pedidos") incluyen alguno propio, no
   cancelado, con pago no confirmado (mismo criterio de arriba, evaluado client-side sobre datos ya
   en memoria) → se muestra el diálogo de bloqueo sin llamar al backend.
2. En caso contrario, se llama `POST /cart/leave`:
   - `200` → se ejecuta el cierre real (`exit()`), pantalla de despedida.
   - `409` → se muestra el mismo diálogo de bloqueo (ya no se traga el error en silencio).
   - Cualquier otro error de red → comportamiento best-effort actual (no bloquea al comensal por un
     problema de conectividad ajeno al pago).

**Diálogo de bloqueo**: título "Tienes un pago pendiente.", cuerpo fijo (ver mensaje del `409`
arriba), un único botón "Entendido" (sin acción de reintento ni bypass) — igual al estado
`exitBlock` del diseño de referencia.
