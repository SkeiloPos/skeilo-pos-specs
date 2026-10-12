# Data Model: Ventas en Efectivo por Valor Neto en el Resumen de Caja

**Sin cambios de modelo de datos.** No se agregan entidades, columnas ni migraciones
(Principio VIII no aplica). Este hotfix solo corrige qué valor ya existente se expone en un campo
de respuesta ya existente — ver `research.md` D1 y D3.

## Entidades involucradas (sin cambios de esquema)

### Turno de caja (`CashShift`)
Sin cambios. Sigue siendo el periodo de apertura/cierre que agrupa ventas y movimientos de un
cajero. `opening_amount` y los campos de arqueo (`counted_amount`) no se tocan.

### Venta (`Sale`)
Sin cambios. `Sale.amount` (o el campo equivalente del monto facturado) y `Sale.change_given`
(cambio entregado al cliente) ya existen y ya son la fuente correcta; este hotfix no agrega ni
modifica columnas — solo cambia cómo se agregan al construir la respuesta del arqueo.

### Movimiento de caja (`CashMovement`)
Sin cambios. Los montos de `ingreso`/`egreso`/`retiro` no participan en esta corrección.

## Contrato de datos derivado: `SalesByMethod` (DTO de respuesta, sin cambios de forma)

El esquema Pydantic `SalesByMethod` (`pos-backend/app/api/v1/cash/schemas.py`) no gana ni pierde
campos. Cambia únicamente la **semántica** del campo `total` cuando `method_type == "cash"`:

| Campo | Antes del hotfix | Después del hotfix |
|---|---|---|
| `total` (fila `method_type="cash"`) | Efectivo bruto recibido en mano (suma de lo cobrado, sin descontar cambio) | Valor neto facturado en efectivo (bruto − cambio entregado) — idéntico a `ReconciliationResponse.ventas_efectivo` |
| `total` (filas `card`/`transfer`/otros) | Sin cambio — no existe concepto de cambio para estos métodos, bruto y neto ya coinciden | Sin cambio |
| `count` (todas las filas) | Sin cambio — cantidad de ventas del método, no se recalcula | Sin cambio |

`ReconciliationResponse.ventas_efectivo`, `.expected`, `.difference` y `.cambio_entregado` no
cambian de valor para ningún turno (ver `research.md` D3) — solo deja de haber una fila
(`sales_by_method[cash].total`) cuyo valor no coincidía con el resto del contrato.

## Validaciones / invariantes

- **Invariante preservado**: para cualquier turno, `sum(sales_by_method[i].total para cash) ==
  ventas_efectivo == cash_sales` (el alias deprecado). Antes del hotfix esta igualdad ya se
  cumplía a nivel de `ventas_efectivo`/`cash_sales` entre sí, pero no entre `sales_by_method` y el
  resto — después del hotfix se cumple también ahí.
- **Invariante preservado**: `expected == opening_amount + ventas_efectivo + ingresos - egresos -
  retiros`, sin el término `cambio_entregado` — esto ya era así antes del hotfix (D3); el hotfix
  no lo cambia, solo deja de sugerir lo contrario en el texto del banner.
