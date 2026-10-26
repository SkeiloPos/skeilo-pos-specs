# Data Model: Métodos distintos en pago mixto e ingresos de caja por método de pago

**Spec**: [spec.md](./spec.md) | **Research**: [research.md](./research.md)

## US1 — Pago mixto de pedido (sin cambios de esquema)

### `Payment` (`pos-backend/app/models/payment.py`, tabla `tenant.payments`)

Sin cambios de columnas. Se refuerza una invariante nueva de **aplicación** (no de base de datos,
ver research.md D1):

| Campo | Tipo | Cambio en spec 136 |
|---|---|---|
| `sale_id` | FK → `sales.id` | Sin cambio. |
| `payment_method_id` | FK → `payment_methods.id` | **Nueva invariante**: dentro del conjunto de `Payment` creados por un mismo `build_sale` (mismo `sale_id`), no puede repetirse entre dos filas. Antes (spec 112/A-124) sí podía repetirse. |
| `amount` | `Numeric(12,2)`, `> 0` | Sin cambio. |
| `reference` | `str \| None` | Sin cambio. |
| `paid_at` | `DateTime` | Sin cambio. |

**Invariante nueva** (aplicada en `build_sale`, no en constraint de base de datos — motivo en
research.md D1): dado el conjunto `payments` recibido por una sola invocación de `build_sale`,
`len({p.payment_method_id for p in payments}) == len(payments)`. Viola → `422` antes de crear
ninguna fila `Payment`, con el nombre del método repetido en el mensaje (FR-002).

**Sin cambio**: `PaymentIn` (`app/api/v1/sales/schemas.py`), las 3 listas que lo envuelven
(`SaleCreate.payments`, `PayIn.payments`, `CheckoutAndSendIn.payments`, todas `max_length=3`
desde spec 112) y `PaymentMethod` (`is_cash`/`type`, sin cambios).

### Modelo de borrador del frontend (`PaymentDraft`, sin cambio de forma)

`PaymentLineDraft`/`PaymentDraft` (`payment-draft.util.ts`) no ganan campos. `paymentIssue()` gana
una validación nueva, intercalada en su orden de prioridad existente (antes de la validación de
saldo pendiente, para que un método repetido no se confunda con un problema de montos):

| Orden | Condición | Mensaje |
|---|---|---|
| 1 | Alguna línea sin método | "Elige el método de pago." *(sin cambio)* |
| 2 | Alguna línea con `amount <= 0` | "Escribe el importe del pago." *(sin cambio)* |
| **3 (nuevo)** | Dos o más líneas con el mismo `methodId` | **"[Método] no puede usarse en más de una línea."** (FR-002) |
| 4 | Línea no efectivo que excede el saldo pendiente | mensaje existente *(sin cambio, desplazado)* |
| 5 | `missingAmount > 0` | "Faltan $[monto] por asignar." *(sin cambio)* |

`PaymentInputComponent` (`payment-input.component.ts`): el `<select>` de cada línea
(`@for (m of methods; track m.id)`) filtra los métodos ya elegidos en **otra** línea del mismo
`draft()` (conserva el propio de la línea actual en la lista, para no deseleccionarlo al abrir el
`<select>`). No es la única defensa — `paymentIssue()` sigue rechazando aunque el filtro fallara.

## US2/US3 — Ingresos de caja por método de pago (cambio de esquema en `cash_movements`)

### `CashMovement` (`pos-backend/app/models/cash_movement.py`, tabla `tenant.cash_movements`)

| Campo | Tipo | Estado | Uso en spec 136 |
|---|---|---|---|
| `cash_shift_id` | FK → `cash_shifts.id` | Sin cambio | — |
| `kind` | `String(20)`, `CheckConstraint IN ('ingreso','egreso','retiro')` | Sin cambio | Determina si `payment_method_id` puede ser distinto de efectivo (solo `'ingreso'`, FR-004/FR-012). |
| `category` | `String(100) \| None` | Sin cambio | Compartida por las 1-2 líneas de un mismo evento (ver más abajo). |
| `amount` | `Numeric(12,2)`, `> 0` | Sin cambio | Monto de **esta línea** (no del evento completo). |
| `description` | `String(255) \| None` | Sin cambio | Compartida por las 1-2 líneas de un mismo evento. |
| **`payment_method_id`** | `UUID`, FK → `tenant.payment_methods.id` | **NUEVO**, `NOT NULL` tras backfill | El método de esta línea. `egreso`/`retiro`: siempre el método `is_cash=True` del tenant (forzado por el endpoint, FR-012). `ingreso`: cualquier método activo del tenant (FR-004). |
| **`group_id`** | `UUID`, nullable | **NUEVO** | `NULL` para toda fila de `egreso`/`retiro` y para un `ingreso` de una sola línea. Compartido por las 2 filas de un mismo evento de `ingreso` mixto (FR-011). |
| `user_id` / `user_name` | — | Sin cambio | — |
| `occurred_at` | `DateTime` | Sin cambio | Las 2 filas de un evento mixto comparten el mismo instante (`server_default=func.now()` evaluado en la misma transacción; en la práctica difieren en microsegundos, irrelevante para FR-011, que exige *poder identificar* el grupo — para eso está `group_id`, no `occurred_at`). |

**Invariantes nuevas (aplicación, no base de datos)**:
- `kind='ingreso'` con 2 líneas del mismo evento (`group_id` compartido) → sus
  `payment_method_id` deben ser distintos entre sí (FR-006). Viola → `422` antes de crear
  cualquiera de las 2 filas.
- `kind IN ('egreso', 'retiro')` → `payment_method_id` siempre el método `is_cash=True` del
  tenant; `group_id` siempre `NULL` (FR-012 — el endpoint no acepta `lines` para estos `kind`).
- Un evento de `ingreso` tiene como máximo 2 filas con el mismo `group_id` (FR-005) — aplicado al
  construir la request (`lines` con `max_length=2` en el schema), no con una consulta de conteo.

**Transiciones**: ninguna — `CashMovement` no tiene estado propio (se crea y queda inmutable,
igual que `Payment`). No hay edición de un ingreso ya guardado en el alcance de esta spec (el
edge case de "editar un ingreso ya guardado" de la spec se interpreta, para `CashMovement`, igual
que para `Payment`: no existe hoy un endpoint de edición de movimientos, así que no hay
comportamiento que adaptar).

### `PaymentMethod` (sin cambios de esquema)

Reutilizado tal cual (`is_cash: bool`, `active: bool`, `type: str`). `is_cash` sigue siendo el
único discriminador de "cuál método usar cuando `kind` fuerza efectivo" (egreso/retiro) y de
"cuáles ingresos cuentan para `expected`" (FR-007).

### `ReconciliationResponse` (`pos-backend/app/api/v1/cash/schemas.py`, cambio de forma)

| Campo | Estado | Cambio en spec 136 |
|---|---|---|
| `ingresos` | Sin cambio de nombre/tipo | **Cambia qué suma**: antes, todo `CashMovement` con `kind='ingreso'`; ahora, solo los que tengan `payment_method_id` de un método `is_cash=True` (FR-007). Sigue siendo el único término de ingresos que entra en `expected`. |
| `egresos` / `retiros` | Sin cambio | Siempre `is_cash=True` por construcción (FR-012), la fórmula no cambia de resultado. |
| `expected` | Sin cambio de fórmula | `opening_amount + ventas_efectivo + ingresos - egresos - retiros` — literalmente la misma expresión; solo cambia la fuente de `ingresos` arriba. |
| `sales_by_method` | Sin cambio de forma | Sigue siendo solo ventas (`Payment`/`Sale`), no se mezcla con ingresos — ver research.md D5. |
| **`ingresos_by_method`** | **NUEVO**, `list[SalesByMethod]` (DTO reutilizado) | Una fila por método de pago con `is_cash=False` que tuvo al menos un `CashMovement` de `kind='ingreso'` en el turno (sin ceros rellenados — a diferencia de `sales_by_method`, que sí rellena en cero todo método activo; aquí no aplica porque "0 ingresos en Nequi" no es información que el arqueo necesite resaltar, a diferencia de "0 ventas en Tarjeta"). `total` = suma de montos; `count` = número de líneas. (FR-008) |

### `CashMovementIn` (`pos-backend/app/api/v1/cash/schemas.py`, cambio de forma, compatible)

```python
class CashMovementLineIn(BaseModel):
    payment_method_id: UUID
    amount: Decimal = Field(..., gt=0, max_digits=12, decimal_places=2)

class CashMovementIn(BaseModel):
    kind: CashMovementKind
    category: str = Field(..., min_length=1, max_length=100)
    description: str | None = Field(None, max_length=255)
    # Compatibilidad (FR-009): una sola línea en efectivo, forma actual sin cambios.
    amount: Decimal | None = Field(None, gt=0, max_digits=12, decimal_places=2)
    # Nuevo (FR-004/FR-005): 1-2 líneas con método explícito, solo para kind='ingreso'.
    lines: list[CashMovementLineIn] | None = Field(None, min_length=1, max_length=2)
```

Validación en el endpoint (`add_movement`, no solo en el schema, mismo patrón que `build_sale`):
exactamente uno de `amount`/`lines` presente; `kind != 'ingreso'` rechaza `lines`; `kind ==
'ingreso'` con `lines` de 2 elementos rechaza `payment_method_id` repetido (FR-006).

### `CashMovementResponse` (cambio de forma, aditivo)

Gana `payment_method_id: UUID` y `group_id: UUID | None`. El endpoint
`POST /cash/shifts/{id}/movements` pasa de devolver un objeto a devolver
`list[CashMovementResponse]` (1 o 2 elementos) — ver research.md D6 y contracts/api.md.

## Cambios de esquema (migración Alembic)

Una sola revisión nueva, `<hash>_135_cash_movement_payment_method.py`:

1. **Agregar** `payment_method_id` (`UUID`, FK → `tenant.payment_methods.id`, nullable
   inicialmente) a `tenant.cash_movements`.
2. **Backfill**: para cada tenant, `UPDATE tenant.cash_movements SET payment_method_id =
   (SELECT id FROM tenant.payment_methods WHERE is_cash = true LIMIT 1) WHERE payment_method_id
   IS NULL` (research.md D4).
3. **Alterar** `payment_method_id` a `NOT NULL` tras el backfill.
4. **Agregar** `group_id` (`UUID`, nullable, sin backfill — todo lo histórico queda `NULL`, que es
   el valor correcto para "no es parte de un ingreso mixto").
5. Índice sobre `payment_method_id` (patrón ya usado en `cash_shift_id`, útil para la nueva
   consulta agrupada de `reconcile()`).

**Compatibilidad con datos existentes**: ver research.md D4 — el backfill asigna el método
efectivo del propio tenant, consistente con que todo movimiento histórico era, por la limitación
que esta spec resuelve, necesariamente efectivo.

**Estrategia de rollback**: `downgrade()` elimina `payment_method_id` y `group_id` (y su índice).
No hay pérdida de datos irreversible: ninguna columna preexistente se modifica ni se elimina.
