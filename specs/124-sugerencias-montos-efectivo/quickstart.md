# Quickstart: Validar las sugerencias de montos para pago en efectivo

Guía para comprobar manualmente que la funcionalidad cumple spec.md una vez implementada. No
requiere ningún cambio de `pos-backend` ni migraciones (ver plan.md, Summary).

## Prerrequisitos

- `pos-heladeria` corriendo localmente contra un tenant con un turno de caja abierto (requisito
  ya existente de la Terminal, no de esta spec).
- Un pedido de mesa, manual o a domicilio con total conocido (p. ej. $22.000), y opcionalmente un
  pedido de comensal por QR con pago en efectivo declarado, para probar "Pagos por confirmar".

## Validar tests automáticos primero

```bash
cd ../pos-heladeria
npx ng test --watch=false --include='src/app/modules/tables/services/payment-draft.util.spec.ts'
npx ng test --watch=false --include='src/app/modules/tables/components/payment-input.component.spec.ts'
npx ng test --watch=false --include='src/app/modules/tables/components/payment-attempt-review-panel.component.spec.ts'
```

Todos en verde (comparar contra el baseline fijado en research.md D6, no contra la suite
completa).

## Escenario 1 — Seleccionar un monto sugerido (User Story 1, FR-001/FR-005/FR-006/FR-010)

1. Abrir el cobro de un pedido con total $22.000, elegir método "Efectivo".
2. Verificar: el campo "Con cuánto paga" aparece **vacío** (no $22.000) y se ven los botones
   "$24.000", "$30.000", "$40.000", "$50.000", "$100.000".
3. Tocar "$50.000". Verificar: el campo muestra $50.000, el bloque "Cambio" muestra $28.000, y
   "Cobrar" se habilita.

## Escenario 2 — Pago combinado con efectivo (User Story 2, FR-009)

1. En ese mismo pedido ($22.000), registrar una línea de $10.000 por un método distinto a
   efectivo (p. ej. Nequi) con "Agregar otro método".
2. Agregar una segunda línea y elegir "Efectivo".
3. Verificar: las sugerencias son "$16.000", "$20.000", "$50.000", "$100.000" (sobre el saldo
   pendiente de $12.000, no sobre $22.000).
4. Eliminar la línea de Nequi. Verificar: las sugerencias de la línea de efectivo se recalculan
   de inmediato sobre $22.000.

## Escenario 3 — Monto manual insuficiente (User Story 3, FR-007)

1. En una línea de efectivo con saldo pendiente $22.000, escribir a mano $20.000.
2. Verificar: aparece "Faltan $2.000 por asignar." y "Cobrar" permanece deshabilitado.
3. Corregir a $25.000 (o tocar una sugerencia que cubra el saldo). Verificar: el mensaje
   desaparece, se ve el "Cambio" correspondiente y "Cobrar" se habilita.

## Escenario 4 — Sin sugerencias para otros métodos (User Story 4, FR-008)

1. Elegir "Bancolombia" (o cualquier método no efectivo) como método de una línea.
2. Verificar: no aparece ningún botón de sugerencia para esa línea.

## Escenario 5 — "Pagos por confirmar" (User Story 5, FR-013)

1. Con un pedido de comensal por QR que declaró pago en efectivo, abrir "Pagos por confirmar".
2. Verificar: se ven hasta 5 botones de sugerencia calculados sobre el total del pedido, y el
   campo "Monto recibido" aparece vacío.
3. Tocar una sugerencia. Verificar: el campo se llena con ese valor y "Confirmar efectivo" se
   habilita si el valor cubre el total (ver el bloque "Cambio" ya existente).

## Casos borde a revisar

- Saldo pendiente $0 en una línea (ya cubierta por otras): no debe verse ni el campo ni las
  sugerencias para esa línea.
- Saldo pendiente exactamente $100.000: solo deben verse 2 botones, "Exacto" ($100.000) y
  "$104.000" (ver data-model.md, tabla de ejemplos, y contracts/rounding-suggestions.md).
