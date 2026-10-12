# Contrato: `POST /cash/shifts/open` (apertura de turno) — cambios

**Endpoint existente**: `POST /cash/shifts/open`
(`../pos-backend/app/api/v1/cash/router.py:68-85`, `open_shift()`). Esta spec no cambia su
propósito (abrir un turno para una caja registradora); endurece la validación de
`opening_amount` para cumplir FR-001/FR-004/FR-005/FR-006.

## Request — campo modificado

| Campo | Tipo | Antes | Después |
|---|---|---|---|
| `opening_amount` | `Decimal` | `Field(0, ge=0, max_digits=12, decimal_places=2)` — acepta `0` y lo usa como valor por defecto si se omite | `Field(0, max_digits=12, decimal_places=2)` — sigue aceptando que se omita (cae en `0`), pero ya no impone ningún mínimo a nivel de Pydantic; el mínimo de negocio (`> 0`) se valida explícitamente en el router (ver "Comportamiento"). |

Resto de campos de `ShiftOpen` (`cash_register_id`): sin cambios.

## Comportamiento

- **`opening_amount > 0`**: sin cambios respecto al comportamiento actual — se crea el turno
  normalmente (`201 Created`, cuerpo `ShiftResponse`), dirigiendo al cajero a la terminal de
  ventas/mesas (FR-009).
- **`opening_amount == 0`** (incluyendo el caso en que el campo se omite del cuerpo de la
  solicitud, que hoy cae en el default `0` — ver spec.md, Edge Cases): el servidor responde
  `422 Unprocessable Entity` con el mensaje "El saldo inicial es obligatorio y debe ser mayor a
  cero" (texto exacto sujeto a research.md D1), **sin crear ningún `CashShift`**.
- **`opening_amount < 0`** (p. ej. `-50000`, solo alcanzable desde un cliente distinto al
  formulario actual, dado que `app-money-input` ya descarta el signo negativo al teclear): mismo
  resultado que el caso `== 0` — `422` con el mismo mensaje, sin crear ningún `CashShift`
  (User Story 2, escenario 2: "el mismo criterio").
- **Caja sin turno abierto previo, con `cash_register_id` inexistente**: sin cambios — sigue
  respondiendo `404` (`get_or_404`), antes de llegar a evaluar `opening_amount`.
- **Caja que ya tiene un turno abierto**: sin cambios — sigue respondiendo `409 Conflict`
  (`IntegrityError` del índice único parcial `idx_open_shift_per_register`). El orden entre esta
  validación y la de `opening_amount` no importa para esta spec: ambas impiden crear el turno: si
  ambas condiciones se cumplen a la vez (saldo inválido Y caja con turno abierto), basta con que el
  servidor responda con cualquiera de los dos códigos de error (`422` o `409`) — la spec no exige
  un orden de precedencia entre ellos, solo que el turno nunca se cree en ningún caso inválido.

## Response

Sin cambios de forma en el camino feliz: sigue devolviendo el `CashShift` completo
(`ShiftResponse`) con `201 Created`. El único cambio observable es la respuesta de error: antes,
`opening_amount` negativo generaba el envelope genérico de validación
(`"Los datos enviados no son válidos."`, `app/core/error_response.py::envelope_from_validation_error`)
y `opening_amount = 0` ni siquiera era un error; después, ambos casos devuelven el mismo `422` con
mensaje explícito, construido por `envelope_from_http_exception` (porque ahora se lanza como
`HTTPException`, no como `RequestValidationError`).

## Compatibilidad

- **No retrocompatible a propósito** para el caso `opening_amount <= 0`: una integración externa
  que hoy dependa de poder abrir un turno sin enviar `opening_amount` (o enviándolo en `0`) empieza
  a recibir `422` donde antes recibía `201`. Este es exactamente el cambio de comportamiento que
  motiva [A-125](../../000-reconocimiento/registro-de-anomalias.md) — intencional, no un efecto
  secundario.
- **Retrocompatible para `opening_amount > 0`**: ningún cliente que ya enviara un saldo inicial
  real y positivo nota cambio alguno (FR-009, SC-003).
- No afecta ningún `CashShift` ya creado (Principio VII): el cambio solo rige hacia adelante,
  desde el momento del despliegue (FR-007).

## Casos de prueba de referencia (para `/speckit-tasks`)

1. `POST /cash/shifts/open` con `opening_amount: 0`, caja sin turno abierto → `422`, mensaje
   indica que el saldo inicial es obligatorio y mayor a cero, ningún `CashShift` creado
   (User Story 2, escenario 1).
2. Mismo request con `opening_amount: -50000` → `422`, mismo mensaje, ningún `CashShift` creado
   (User Story 2, escenario 2).
3. Mismo request **omitiendo** `opening_amount` del cuerpo → `422` (cae en el default `0`, mismo
   tratamiento que el caso 1; spec.md, Edge Cases).
4. Mismo request con `opening_amount: 50000` → `201`, `CashShift` creado con
   `opening_amount = 50000`, sin cambios respecto al comportamiento actual (User Story 3,
   escenario 1).
5. Mismo request con `opening_amount: 0.01` (válido pero mínimo) → `201` — confirma que el límite
   es estrictamente `> 0`, no un piso de negocio mayor (spec.md, Assumptions: "no introduce un
   monto mínimo de negocio adicional").
6. Intento directo de `INSERT`/`UPDATE` sobre `cash_shifts` con `opening_amount <= 0` fuera del
   endpoint (p. ej. vía `CashShift(...)` + `db.commit()` en un test) → falla por el
   `CheckConstraint` de base de datos (`ck_cash_shift_opening_positive`), como defensa en
   profundidad independiente del endpoint (ver `data-model.md`).
7. Un `CashShift` histórico ya existente con `opening_amount = 0` (insertado antes de esta spec,
   simulado en el test insertando directamente y luego aplicando la migración, o verificando que
   la migración no falla si existe tal fila) → la migración de esta spec se aplica sin error
   (`NOT VALID`) y esa fila sigue existiendo sin modificarse (FR-007).
