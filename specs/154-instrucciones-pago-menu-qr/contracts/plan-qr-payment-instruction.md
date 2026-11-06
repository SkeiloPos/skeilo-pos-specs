# Contrato: Modalidad de pago del menú QR en el catálogo de un plan

Extiende los contratos ya existentes de spec 033/149 (`POST /super-admin/plans`,
`PATCH /super-admin/plans/{id}`) agregando un campo nuevo a cada payload — no crea ningún
endpoint nuevo de Super Admin. A diferencia de spec 149, este campo **deliberadamente no** se
agrega al contrato de `GET /plan` (ver research.md Decisión 3) — ver la sección dedicada más
abajo.

## `POST /super-admin/plans` / `PATCH /super-admin/plans/{id}` (modificados)

**Request** (`PlanCreate`/`PlanUpdate`) gana `modalidad_pago_qr`:

```json
{
  "name": "Pro",
  "modalidad_pago_qr": "PAY_BEFORE_RECEIVING"
}
```

- `PlanCreate.modalidad_pago_qr: Literal["PAY_AFTER_RECEIVING", "PAY_BEFORE_RECEIVING"] =
  "PAY_AFTER_RECEIVING"` — omitido al crear se guarda como `PAY_AFTER_RECEIVING`
  (comportamiento actual, FR-002).
- `PlanUpdate.modalidad_pago_qr: Optional[Literal["PAY_AFTER_RECEIVING",
  "PAY_BEFORE_RECEIVING"]] = None` — omitido no modifica el valor vigente del plan (mismo
  patrón `exclude_unset` que el resto de campos de `PlanUpdate`).
- Un valor fuera del catálogo (p. ej. `"OTRO"`) responde `422` de validación Pydantic antes de
  llegar a la base de datos — el `CheckConstraint` de la columna es la segunda línea de defensa,
  no la única (FR-001/FR-002).

## `GET /super-admin/plans` / respuesta de `POST`/`PATCH` (modificados)

**Response** (`PlanResponse`) gana `modalidad_pago_qr`, siempre presente (nunca `null`, siempre
uno de los dos valores):

```json
{
  "id": "uuid",
  "name": "Pro",
  "modalidad_pago_qr": "PAY_BEFORE_RECEIVING",
  "...": "..."
}
```

**Errores**: sin cambios respecto al contrato de spec 033 más allá del `422` de valor fuera de
catálogo descrito arriba.

## `GET /plan` (sin cambios — explícitamente no modificado)

A diferencia del contrato equivalente de spec 149 (`cocina_access` sí se agregó a `ModuleAccess`),
este spec **no** toca `PlanSummaryResponse`/`ModuleAccess`. Cualquier usuario del tenant que
llame `GET /plan` sigue recibiendo exactamente la misma forma de respuesta que antes de esta
spec — ninguna clave nueva, ni `modalidad_pago_qr` ni un alias de ese valor. Esto es intencional
(research.md Decisión 3): FR-004 prohíbe que cualquier rol de administración del tenant
**consulte** esta modalidad, y `GET /plan` es accesible a cualquier usuario autenticado del
tenant.

## `POST /cart/submit` / `GET /cart/orders` (modificados — comensal anónimo, `OrderResponse`)

**Response** (`OrderResponse`) gana `qr_payment_instruction_mode`, computado por
`cart/router.py` a partir del plan vigente del tenant propietario de la orden — nunca enviado
por el cliente, nunca presente en el `request` de estos endpoints:

```json
{
  "id": "uuid",
  "status": "pendiente",
  "qr_payment_instruction_mode": "PAY_BEFORE_RECEIVING",
  "current_payment_attempt": {
    "is_cash": true,
    "...": "..."
  },
  "...": "..."
}
```

- Presente y con uno de los dos valores del catálogo en toda respuesta de estos dos endpoints
  (comensal anónimo, FR-006).
- `null` en cualquier otra respuesta de `OrderResponse` (POS, caja, cocina, terminal de mesas —
  `app/api/v1/orders/router.py` y afines) porque ningún otro router lo asigna (FR-013) —
  compatible con cualquier cliente que ya ignore campos desconocidos del schema.
- Nunca se persiste junto con la orden; se recalcula en cada respuesta a partir del plan vigente
  del tenant (FR-014) — ver research.md Decisión 4.

**Errores**: sin cambios — este campo no introduce ninguna validación de entrada nueva (es
puramente de salida).

## Mapeo `(qr_payment_instruction_mode, método de pago)` → texto (frontend, sin endpoint propio)

No es un contrato de API: es la función pura `qrPaymentInstructionMessage` en
`order-status.util.ts` (frontend), consumida solo por `confirmation-step.component.ts`. Su
tabla de verdad completa está en [data-model.md](../data-model.md), sección "Combinación
modalidad + método de pago → mensaje exacto". Un método de pago fuera de efectivo/transferencia/
mixto, o un `qr_payment_instruction_mode` nulo (orden servida antes del despliegue de este
campo), devuelve `null` y la sección de instrucción no se renderiza — nunca un mensaje
incorrecto ni una excepción (FR-009, research.md Decisión 5).

## Sin contrato de enforcement

Esta modalidad no gatea ningún endpoint ni bloquea ninguna acción (FR-010/FR-011/FR-012):
afecta únicamente qué texto se muestra. No hay, por tanto, ningún `403`/`MODULE_NOT_IN_PLAN`
asociado a este contrato — a diferencia del catálogo de módulos (`PLAN_MODULES`), esta columna
no vive ahí (research.md Decisión 2).
