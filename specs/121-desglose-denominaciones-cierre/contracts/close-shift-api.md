# Contrato — Cierre de turno con desglose por denominación

**Spec**: [../spec.md](../spec.md) · **Data model**: [../data-model.md](../data-model.md) §4–5 ·
**Research**: [../research.md](../research.md) R4, R5, R6

Endpoint existente, **contrato de petición estricto** (decisiones D-1/D-2). Cambia el cuerpo
aceptado y los rechazos; la respuesta de éxito solo gana dos campos opcionales.

## `POST /api/v1/cash/shifts/{shift_id}/close`

Autenticación: `get_current_user` (sin cambios — cualquier usuario autenticado; el rol MESERO sigue
bloqueado por su lista *default-deny*).

### Cuerpo de la petición

```jsonc
{
  "denominations": [                       // opcional; por defecto []
    { "denomination": 100000, "quantity": 1 },
    { "denomination": 10000,  "quantity": 1 },
    { "denomination": 5000,   "quantity": 1 }
  ],
  "close_note": "Faltan $5.000 del cambio de la mañana"   // opcional; obligatoria si la diferencia ≠ 0
}
```

| Campo | Tipo | Reglas |
|-------|------|--------|
| `denominations[].denomination` | decimal (`≤ 12` dígitos, `2` decimales), `> 0` | Debe existir en el catálogo del tenant; no puede repetirse (`10000` ≡ `10000.00`) |
| `denominations[].quantity` | entero `≥ 0` | `0` se acepta pero **no se persiste** (FR-015) |
| `close_note` | cadena `≤ 500`, opcional | Obligatoria y no vacía si el servidor calcula diferencia ≠ 0 (`RN-CASH-10`) |

**El cliente NO envía** tipo, subtotal, total, efectivo contado ni diferencia: los calcula el
servidor (FR-001). `denominations` vacía (o con todo en `0`) = efectivo contado **$0** (D-2).

**Campos prohibidos** (rechazo `422`, ver abajo), con valor no nulo: en el cuerpo `counted_amount`,
`total`, `difference`, `subtotal`; dentro de cada línea `subtotal`, `total`. Cualquier otra clave
desconocida se ignora, como hoy.

### Orden de evaluación

| # | Verificación | Falla con |
|---|--------------|-----------|
| 1 | Sin valores monetarios del cliente | `422` |
| 2 | Turno existe (se lee con `SELECT … FOR UPDATE`) | `404` `Shift not found` |
| 3 | Turno no está cerrado | `409` `El turno ya está cerrado` |
| 4 | Sin pedidos activos sin cobrar (spec 119, **sin cambios**) | `409` con `active_orders` |
| 5 | Denominaciones: sin repetidas → todas en catálogo → total ≤ máximo | `422` |
| 6 | Si la diferencia calculada ≠ 0: `close_note` no vacía (`RN-CASH-10`, **sin cambios**) | `422` |
| 7 | Persistir líneas (cantidad > 0), cerrar turno, snapshot spec 119, **un solo `commit`** | — |

Cualquier fallo en 1–6 deja el turno `open` y **no escribe nada** (FR-007).

### Respuesta `200` — `ShiftResponse`

```jsonc
{
  "id": "uuid", "cash_register_id": "uuid",
  "user_id": "uuid", "user_name": "Ana",                  // quien ABRIÓ (sin cambios)
  "opening_amount": "50000.00",
  "opened_at": "…", "closed_at": "…",
  "counted_amount": "115000.00",                          // Σ subtotales, calculado por el servidor
  "status": "closed",
  "close_note": null,
  "closed_by_user_id": "uuid",                            // NUEVO — null en turnos históricos
  "closed_by_user_name": "Luis"                           // NUEVO — snapshot del nombre al cerrar
}
```

`closed_by_*` lo toma el servidor de la sesión autenticada; puede diferir de `user_id`/`user_name`.

### Rechazos `422`

El `detail` es **una cadena en español** (excepto los errores estructurales de Pydantic, que
conservan el formato por defecto de FastAPI: `detail` como lista). La pantalla muestra `detail`
tal cual.

| Causa | `detail` (texto de referencia) |
|-------|--------------------------------|
| Valor monetario del cliente (FR-002) | `La aplicación está desactualizada: el total contado ahora lo calcula el servidor. Recarga la página e intenta cerrar el turno de nuevo.` |
| Denominación repetida (FR-006) | `La denominación $10.000 está repetida en el conteo.` |
| Denominación fuera del catálogo (FR-004) | `La denominación $3.000 no está registrada para este negocio.` |
| Efectivo contado excede el máximo | `El efectivo contado excede el monto máximo permitido ($9.999.999.999,99).` |
| Diferencia sin observación (sin cambios) | `El arqueo no cuadra: la observación (close_note) es obligatoria` |
| Cantidad negativa / no entera / decimal mal formado (FR-005) | Pydantic estándar (`detail` lista; `loc` apunta a `denominations.N.quantity`) |

### Otros códigos

| Código | Cuándo |
|--------|--------|
| `409` | Turno ya cerrado, o pedidos activos (cuerpo plano con `active_orders`, spec 119), o cierre simultáneo perdido (FR-019) |
| `404` | El turno no existe |

### Ejemplos (de los escenarios de la spec)

**Cuadre exacto** — esperado `$115.000`; líneas `100000×1`, `10000×1`, `5000×1` → `200`,
`counted_amount = "115000.00"`, 3 filas en `cash_count_denominations` (US1-1).

**Faltante con observación** — mismo esperado; `100000×1`, `10000×1`, `close_note="…"` → `200`,
`counted_amount = "110000.00"`, diferencia `-5000.00` en el reporte (US1-2). Sin `close_note` → `422`
(US1-3) y el turno sigue abierto.

**Caja vacía por API** — `{"denominations": [], "close_note": "Caja vacía"}` → `200`,
`counted_amount = "0.00"`, ninguna fila de desglose (US1-5).

**Cuerpo de la versión anterior** — `{"counted_amount": 95000, "denominations": […]}` → `422` con el
texto de «Recarga la página» y turno abierto (US2-4).

## Idempotencia y concurrencia

No es idempotente: el segundo intento sobre un turno cerrado responde `409` sin tocar el desglose
(FR-018). Con dos cierres simultáneos, el `SELECT … FOR UPDATE` serializa: uno cierra y el otro
espera y recibe `409`; si aun así se llegara a violar el índice único `(cash_shift_id, denomination)`,
el `IntegrityError` se traduce a `409`, nunca a `500` (FR-019, SC-006).
