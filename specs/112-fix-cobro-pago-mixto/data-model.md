# Data Model: Cobro de pedido con múltiples métodos de pago

Ninguna entidad persistida es nueva (ver `research.md` D1) — este documento describe (a) las
entidades persistidas que ya existen y se reutilizan sin cambio de esquema, y (b) el modelo de
**borrador en memoria** del frontend, que sí es nuevo (generaliza `PaymentDraft` de 1 a N líneas).

## Entidades persistidas (sin cambios de esquema)

### `Payment` (`pos-backend/app/models/payment.py`, tabla `tenant.payments`)

| Campo | Tipo | Significado en pago mixto |
|---|---|---|
| `sale_id` | FK → `sales.id` | Agrupa todas las líneas de un mismo cobro atómico |
| `payment_method_id` | FK → `payment_methods.id` | El método de esta línea (RN3: puede repetirse entre líneas) |
| `amount` | `Numeric(12,2)`, `> 0` | Monto asignado (no efectivo) o monto recibido (efectivo) — ver `research.md` D3 |
| `reference` | `str \| None` | Referencia opcional (RN5/FR-011), ya existe para cualquier método no solo transferencia |
| `paid_at` | `DateTime`, `server_default=now()` | Momento de confirmación de esta línea (FR-012, "cuándo") |

**Quién confirmó** (FR-012): no vive en `Payment` — es `Sale.user_id`/`Sale.user_name`, compartido
por todas las líneas de un mismo cobro, porque las líneas de un mismo `Payment` nacen todas en la
misma transacción de `build_sale`, ejecutada por un único cajero autenticado. No se necesita una
columna nueva.

**Invariante que ya aplica `build_sale`** (sin cambio): `Σ Payment.amount (no efectivo) ≤ Sale.total`
y `Σ Payment.amount (todas) ≥ Sale.total`; `Sale.change_given = Σ Payment.amount − Sale.total`.

### `Sale` (`pos-backend/app/models/sale.py`)

Sin cambios. `payments: Mapped[List["Payment"]]` ya es la relación 1:N que este fix necesita.
`paid_amount` y `change_given` siguen siendo agregados a nivel de venta (no por línea) y ya
alimentan el arqueo neto (spec 108).

### `PaymentMethod` (tenant) / `PaymentMethodCatalog` (shared)

Sin cambios (spec 032). `is_cash: bool` es el único dato que la UI necesita para decidir si una
línea admite vuelto (RN2).

## Contrato de entrada al backend (único cambio de esquema: un tope)

`PaymentIn` (`pos-backend/app/api/v1/sales/schemas.py:116-119`) sin cambios:

```python
class PaymentIn(BaseModel):
    payment_method_id: UUID
    amount: Decimal = Field(..., gt=0, max_digits=12, decimal_places=2)
    reference: str | None = Field(None, max_length=255)
```

Las tres listas que lo envuelven ganan `max_length=3` (antes solo `min_length=1`):

- `PayIn.payments` (`orders/schemas.py:385`)
- `CheckoutAndSendIn.payments` (`orders/schemas.py:404`)
- `SaleCreate.payments` (`sales/schemas.py:131`)

## Modelo de borrador del frontend (nuevo — generaliza `PaymentDraft`)

**Nota de implementación** (reemplaza el diseño de dos campos por línea que este documento
proponía originalmente): un solo número por línea, igual que antes de esta spec, resultó
suficiente y evita el problema de qué pasa cuando una línea en efectivo cambia "después" de que
otra línea ya fue validada (ver más abajo). "Lo asignado" de una línea en efectivo no es un campo
propio — se **deriva** del número tecleado con `assignedOf`.

Reemplaza `pos-heladeria/src/app/modules/tables/services/payment-draft.util.ts:13-16`
(`PaymentDraft` de una sola línea) por una lista de hasta 3 líneas:

```ts
export interface PaymentLineDraft {
  methodId: string;
  /** No efectivo: el monto asignado. Efectivo: "con cuánto paga" el
   *  cliente -- puede superar lo que esa línea necesitaba cubrir; el
   *  exceso es el vuelto (RN2), no una porción adicional cubierta. */
  amount: number;
  reference: string | null;
}

export type PaymentDraft = PaymentLineDraft[]; // 1 a 3 elementos
```

**Funciones puras derivadas** (reemplazan/generalizan las de hoy en `payment-draft.util.ts`):

| Función hoy (1 línea) | Función generalizada (N líneas) | Regla |
|---|---|---|
| `paymentLines(draft)` | `paymentLines(draft, methods)` | Por línea: `amount = line.amount` tal cual (D3) |
| `paidAmount(draft)` | `assignedOf(draft, i, total, methods)` por línea + `assignedTotal(draft, total, methods)` | Ver "Orden de captura" abajo |
| `changeDue(draft, total)` | `changeDue(draft, i, total, methods)` (por línea) | `max(0, line.amount − assignedOf(draft, i, total, methods))`, solo si `isCash` |
| `nonCashAmount(draft, methods)` | retirada — reemplazada por el chequeo por línea de `paymentIssue` (RN2) | — |
| `missingAmount(draft, total)` | `missingAmount(draft, total, methods)` | `total − assignedTotal(...)` |
| `paymentIssue(draft, total, methods)` | `paymentIssue(draft, total, methods)` | Ver tabla de validaciones abajo |

### Orden de captura: por qué `assignedOf` solo mira hacia atrás

Lo "asignado" de una línea en efectivo es `min(line.amount, total − Σ assignedOf de las líneas
ANTERIORES en el array)` -- nunca mira las líneas posteriores. Es la pieza central del diseño, y
no es arbitraria: `draft` solo crece por el final (`addLine` hace `push`, nunca inserta ni
reordena), así que el índice en el array ya es el orden real en que el cajero capturó cada línea.

La alternativa obvia -- "lo asignado de una línea en efectivo es lo que falta considerando TODAS
las demás líneas, sin importar el orden" -- se probó y falla el Acceptance Scenario de la
Historia 3: con Transferencia $6.000 fijada primero y Efectivo asignado $8.000 después, escribir
$10.000 en "Con cuánto paga" de la línea de efectivo **no debe** reabrir la validación de la
transferencia (que ya era válida). Mirar solo hacia atrás logra justo eso, sin recursión circular
entre líneas (cada `assignedOf` de una línea en efectivo solo llama a `assignedOf` de índices
estrictamente menores, así que termina). Mirar hacia adelante también habría creado una
dependencia circular real entre una línea en efectivo y una no efectivo posterior.

Con este orden, se puede demostrar que `assignedTotal(draft, total, methods)` nunca supera
`total` una vez que `paymentIssue` no reporta ningún problema (cada línea en efectivo se capa a
sí misma contra lo que ya reclamaron las anteriores, y toda línea no efectivo que excedería ese
mismo límite queda rechazada antes de llegar al cálculo de "falta por asignar"). Por eso
`missingAmount` nunca es negativo en ese punto: RN1 ("ni falta ni sobra") queda cubierta sin
necesitar un mensaje de "sobra" aparte -- se eliminó esa rama de `paymentIssue` por quedar
inalcanzable, en vez de dejar código muerto.

### Validaciones (`paymentIssue`, generalizado)

En orden de prioridad (la primera que aplique es la que se muestra, igual que hoy):

1. Alguna línea sin método elegido → mensaje existente ("Elige el método de pago.").
2. Alguna línea con `amount <= 0` → mensaje existente ("Escribe el importe del pago.").
3. Una línea no efectivo cuyo `amount` excede lo que las líneas ANTERIORES ya tienen asignado
   (`pendingBalanceExcluding`) → **"[Método] no puede superar el saldo pendiente ($[saldo])"**
   (RN2/FR-007; el nombre real del método sustituye "La transferencia" del escenario literal).
4. `missingAmount(draft, total, methods) > 0` → **"Faltan $[monto] por asignar"** (RN1/FR-003).
5. Ninguna de las anteriores → `null` (habilita "Cobrar").

### Transiciones de estado del borrador (todo en memoria, nada persistido hasta "Cobrar")

- **Elegir método en la primera línea de un cobro nuevo** (sin otra línea, sin monto tecleado) →
  se precarga con el total completo (FR-014, caso de un solo método). Elegir método en una línea
  ya precargada por `addLine` no le toca el monto.
- **Agregar otro método** → `push` de una nueva `PaymentLineDraft` precargada con
  `total − assignedTotal(draft, total, methods)` (el saldo pendiente real, no la simple resta de
  montos tecleados -- importa si alguna línea anterior en efectivo está sobrepagando),
  bloqueado si `draft.length === 3` (FR-004).
- **Eliminar línea** → `filter`, nunca deja el borrador vacío; recalcula `missingAmount`/
  `paymentIssue` de inmediato porque son puramente derivados de `draft()` (FR-010).
- **Cambiar el total del pedido** (`ngOnChanges`, igual que hoy) → reset completo del borrador a
  una línea vacía, igual que el comportamiento actual de `PaymentInputComponent.ngOnChanges`.
- **Fallo del servidor al cobrar** → el borrador NO se toca (FR-009); es responsabilidad de
  `PosCheckoutPanelComponent`, que hoy ya no limpia `paymentDraft` en el camino de error (solo
  `store.error()` se puebla) — se preserva ese comportamiento sin cambiarlo.
