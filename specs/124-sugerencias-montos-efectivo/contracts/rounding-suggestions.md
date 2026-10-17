# Contrato: `roundingSuggestions` y su integración en los dos componentes de cobro

Esta spec no agrega ni modifica ningún endpoint de `pos-backend`. El único "contrato" que expone
es el de una función pura de `pos-heladeria` y cómo la consumen los dos componentes existentes.

## Función pura

```ts
function roundingSuggestions(
  saldoPendiente: number,
  denominations: number[] = ROUNDING_DENOMINATIONS_BY_CURRENCY.COP,
): number[]
```

**Precondiciones**:
- `saldoPendiente > 0`. Si es `<= 0`, el llamador no debe invocar la función (Edge Cases de
  spec.md: saldo $0 no muestra sugerencias).
- `denominations` no vacío, valores positivos.

**Postcondiciones**:
- Arreglo de enteros `>= saldoPendiente`, ascendente, sin duplicados, longitud
  `<= denominations.length`.
- Determinística y sin efectos secundarios (no lee señales, no muta nada).

**Casos de ejemplo** (de spec.md, Acceptance Scenarios — denominaciones COP por defecto):

| `saldoPendiente` | Resultado |
|---|---|
| 22000 | `[24000, 30000, 40000, 50000, 100000]` |
| 47500 | `[48000, 50000, 60000, 100000]` |
| 12000 | `[16000, 20000, 50000, 100000]` |
| 100000 | `[100000, 104000]` |

## Integración en `PaymentInputComponent` (FR-001, FR-005, FR-008, FR-009, FR-010, FR-012)

- Por cada línea `i` donde `isCash(line.methodId)` es verdadero y
  `pendingBalanceExcluding(draft, i, total, methods) > 0`: renderizar hasta 5 botones con
  `roundingSuggestions(pendingBalanceExcluding(draft, i, total, methods))`.
- Click en un botón de valor `v`: `setAmount(i, v)` (ya existe, sin cambios de firma).
- Si `v === saldoPendiente` de esa línea, el botón se etiqueta "Exacto"; si no,
  `formatMoney(v)`.
- Si el método de la línea no es efectivo: no renderizar ningún botón (ya es el caso hoy, al no
  entrar en esta rama).
- `setMethod(index, methodId)` (cambio de comportamiento, `A-135`): cuando
  `isCash(methodId)`, **no** precargar `amount` (queda en `0`/vacío); para cualquier otro
  método, sin cambios respecto al código actual.

## Integración en `PaymentAttemptReviewPanelComponent` (FR-013)

- Mientras `attempt.is_cash` y `checkoutPreview()` tenga valor: renderizar hasta 5 botones con
  `roundingSuggestions(Number(checkoutPreview()!.total))`, debajo o junto al
  `<app-money-input>` de "Monto recibido".
- Click en un botón de valor `v`: `this.amountReceived = v` (mismo efecto que escribirlo a mano;
  dispara el mismo recálculo de `cashChangePreview()` ya existente).
- Sin cambios en `confirmCash()`, en la inicialización de `amountReceived` (ya nace `null`), ni en
  el bloque "Cambio" ya existente.

## Fuera de este contrato

- No se renombra ningún rótulo visual existente ("Cambio", "Faltan $X por asignar.") — ver
  research.md D2/D3.
- No se agrega ningún endpoint, esquema Pydantic ni columna en `pos-backend`.
