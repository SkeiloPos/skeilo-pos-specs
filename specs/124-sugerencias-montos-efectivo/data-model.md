# Data Model: Sugerencias de Montos para Pago en Efectivo

Sin cambios de esquema de base de datos ni de contrato de API (ver plan.md, Summary). Lo que
sigue son los tipos/estructuras en memoria del frontend (`pos-heladeria`) que esta spec agrega o
reutiliza.

## 1. Denominaciones de redondeo (nuevo, constante)

Corresponde a la entidad "Denominaciones de redondeo del tenant" de spec.md (Key Entities).

```ts
type CurrencyCode = 'COP'; // hoy el único valor real; ver research.md D1

const ROUNDING_DENOMINATIONS_BY_CURRENCY: Record<CurrencyCode, number[]> = {
  COP: [8000, 10000, 20000, 50000, 100000],
};
```

**Reglas de validación**:
- Los valores están en pesos enteros (sin decimales, igual que el resto del sistema).
- Están ordenados ascendente (no es un requisito funcional per se, pero simplifica la
  implementación de `roundingSuggestions` y el orden final que exige FR-003).
- No hay UI de administración para esta lista (Assumptions de spec.md); cambiarla es un cambio de
  código, no de configuración en caliente.

## 2. Sugerencia de monto (derivado, no persistido)

No es una entidad nueva de dominio: es el resultado puro de una función, recalculado en cada
render. Corresponde a "Línea de pago en efectivo → sugerencias" en spec.md.

```ts
/**
 * FR-001 a FR-004: hasta 5 montos, uno por denominación configurada, redondeando
 * `saldoPendiente` hacia arriba a cada denominación, sin duplicados, orden ascendente.
 * El "monto exacto" NO se agrega como candidato aparte (Clarifications, sesión 2026-10-17).
 */
function roundingSuggestions(saldoPendiente: number, denominations: number[]): number[] {
  const values = denominations.map((d) => Math.ceil(saldoPendiente / d) * d);
  return Array.from(new Set(values)).sort((a, b) => a - b);
}
```

**Reglas de validación / invariantes**:
- `saldoPendiente <= 0` ⇒ no se llama a `roundingSuggestions` (FR-001, Edge Cases: saldo $0 no
  muestra sugerencias ni campo).
- El resultado nunca tiene más elementos que `denominations.length` (hoy, 5) — FR-003.
- Cada elemento del resultado es `>= saldoPendiente` (consecuencia de `Math.ceil`); si alguno es
  `=== saldoPendiente`, ese botón se etiqueta "Exacto" en la capa de presentación (FR-012,
  research.md D4), no en el dato mismo.

**Transiciones**: ninguna — es un valor derivado puro, recalculado cada vez que cambia
`saldoPendiente` (al agregar/editar/eliminar otra línea de pago, FR-009) o el método de la línea
(FR-008, deja de calcularse si el método no es Efectivo).

## 3. Línea de pago (existente, spec 112 — sin campos nuevos)

```ts
// pos-heladeria/src/app/modules/tables/services/payment-draft.util.ts (ya existe)
interface PaymentLineDraft {
  methodId: string;
  amount: number; // "Con cuánto paga" (efectivo) o "Importe" (otros métodos)
  reference: string | null;
}
```

Esta spec no agrega campos a `PaymentLineDraft`. Lo único que cambia es **cómo se inicializa**
`amount` en `PaymentInputComponent.setMethod()` cuando `isCash(methodId)` es verdadero: pasa de
precargarse con `total`/saldo pendiente a quedar en `0`/vacío (FR-010, decisión `A-135`). Para
cualquier método no efectivo, `setMethod()` no cambia.

**Saldo pendiente de una línea** (ya existente, sin cambios): `pendingBalanceExcluding(draft,
index, total, methods)` en `payment-draft.util.ts` — es el valor que se pasa como
`saldoPendiente` a `roundingSuggestions()` para la línea en curso.

## 4. Monto recibido en "Pagos por confirmar" (existente, spec 073/028 — sin campos nuevos)

```ts
// PaymentAttemptReviewPanelComponent (ya existe)
amountReceived: number | null = null;
```

Sin cambios de inicialización (ya nace `null`/vacío hoy — ver research.md D5). El saldo pendiente
que se le pasa a `roundingSuggestions()` en esta superficie es siempre
`checkoutPreview()!.total` (FR-013).

## Resumen de relaciones

```
PaymentInputComponent / PaymentAttemptReviewPanelComponent
        │ saldoPendiente (número)
        ▼
roundingSuggestions(saldoPendiente, ROUNDING_DENOMINATIONS_BY_CURRENCY['COP'])
        │ number[] (≤ 5, ascendente, sin duplicados)
        ▼
Botones de sugerencia (presentación: "Exacto" si coincide con saldoPendiente, si no `formatMoney(valor)`)
        │ click
        ▼
line.amount / amountReceived = valor tocado
        │
        ▼
Cambio / "Faltan $X por asignar." (ya existente, sin cambios de cálculo)
```
