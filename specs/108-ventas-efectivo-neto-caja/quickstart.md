# Quickstart: validar Ventas en Efectivo por valor neto en el resumen de caja

Asume que `data-model.md`/`contracts/api.md` ya están aplicados.

## Prerrequisitos

- `pos-backend`: un tenant con un turno de caja abierto (`CashShift`) y al menos un método de pago
  activo de tipo `cash`. No requiere Postgres real — basta la suite de characterization (SQLite en
  memoria) para la regresión, y el script dedicado puede correr contra el mismo fixture.
- No hay migraciones que aplicar (sin cambios de modelo de datos).

## 1. Backend — script autoejecutable

```bash
cd ../pos-backend
./env/bin/python -m app.scripts.test_cash_net_sales
```

Debe cubrir, como mínimo (mapeado a los Acceptance Scenarios del spec):

1. Turno con Factura 25 = $17.000 (pago exacto, sin cambio) y Factura 23 = $28.000 recibiendo
   $31.000 en mano ($3.000 de cambio) → `sales_by_method[cash].total == 45000`, no `48000`
   (Historia 1, escenario 1).
2. Turno sin ninguna venta en efectivo → `sales_by_method[cash].total == 0`, sin error (Historia
   1, escenario 2).
3. Con el turno del punto 1 (`opening_amount = 100000`, sin ingresos/egresos/retiros) →
   `expected == 145000`, idéntico al valor que daba el cálculo antes del hotfix para el mismo
   turno (Historia 2, escenario 2; `research.md` D3).
4. Para el mismo turno, `sales_by_method[cash].total == ventas_efectivo == cash_sales == 45000`
   (invariante de `data-model.md`).
5. Un turno con venta en efectivo por monto exacto (sin cambio): el valor neto y el bruto
   coinciden, `sales_by_method[cash].total` no cambia respecto al comportamiento anterior (Edge
   case del spec).

## 2. Backend — regresión obligatoria

```bash
./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'
```

Debe seguir en 1290 OK (baseline 2026-10-03) o superior — ningún test `CONGELA comportamiento
actual:` cubre este cálculo (`research.md`, Constitution Check Principio III), así que no debería
haber ninguna falla nueva atribuible a este hotfix.

## 3. Frontend — specs Vitest + uso manual

```bash
cd ../pos-heladeria
npx ng test --watch=false --include='src/app/modules/cash-register/**/*.spec.ts'
```

Debe seguir en verde — la baseline general de 19 fallas en 6 archivos (spec 084) no incluye
ningún archivo de `cash-register`.

Uso manual (`ng serve`):

1. Abrir el resumen de caja de un turno con ventas en efectivo y cambio entregado → la tarjeta
   "Ventas Efectivo" muestra el valor neto (ej. $45.000), no el bruto recibido en mano.
2. El banner "Efectivo esperado en caja" muestra el texto "Fondo inicial + ventas en efectivo +
   ingresos − egresos − retiros", sin la palabra "cambio".
3. La tarjeta "Cambio entregado" sigue visible con su valor correcto cuando es mayor a $0, pero ya
   no se posiciona como si fuera un término de la fórmula.
4. Cerrar el turno y abrir el reporte de cierre impreso → la fila "Ventas efectivo" de la tabla
   también muestra el valor neto, "Efectivo esperado" no cambia respecto al valor que ya mostraba
   antes del hotfix, y "Cambio entregado" aparece como dato informativo aparte de la tabla
   secuencial (no como una fila con "−" entre Ventas e Ingresos).
5. Abrir el historial de un turno ya cerrado **antes** de este hotfix → al reconsultarlo, también
   se ve con la nueva interpretación (el arqueo se recalcula en el momento de la consulta, no hay
   snapshot persistido que migrar).

## Criterio de éxito

Los 5 puntos del script backend pasan, la suite de characterization sigue en verde sin fallas
nuevas, las specs de `cash-register` siguen en verde, y los 5 pasos manuales del frontend se
comportan como se describe — en particular, ningún paso cambia el número final de "Efectivo
esperado" respecto al que el sistema ya mostraba antes del hotfix.
