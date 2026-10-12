# Contrato de API: arqueo de caja (ventas en efectivo por valor neto)

No hay endpoints nuevos ni cambios de ruta — se corrige la semántica de un campo ya existente en
las respuestas de los 2 endpoints que exponen `ReconciliationResponse` en
`pos-backend/app/api/v1/cash/router.py`:

- `GET /cash/shifts/{shift_id}/reconciliation`
- `POST /cash/shifts/{shift_id}/close` (y cualquier otro endpoint que embeba
  `ShiftReportResponse.reconciliation`, p. ej. el historial de turnos cerrados)

## Cambio de contrato

Dentro de `sales_by_method` (lista, una fila por método de pago activo), la fila cuyo
`method_type == "cash"`:

- **Antes**: `total` = suma bruta de lo cobrado en efectivo (incluye el dinero que luego se
  devolvió como cambio).
- **Después**: `total` = valor neto facturado en efectivo = `total_bruto − cambio_entregado` —
  idéntico al valor ya presente en `ventas_efectivo` (y su alias `cash_sales`).

Ningún otro campo de `ReconciliationResponse` cambia de valor: `ventas_efectivo`,
`ventas_tarjeta`, `ventas_transferencia`, `cambio_entregado`, `ingresos`, `egresos`, `retiros`,
`expected`, `counted_amount`, `difference`, `cash_sales` se calculan exactamente igual que antes
(ver `research.md` D1/D3). Los demás tipos de método (`card`, `transfer`, cualquier otro activo sin
ventas) tampoco cambian: nunca tuvieron cambio entregado, así que su bruto y su neto ya eran el
mismo número.

## Ejemplo (el mismo del pedido original)

Turno con dos facturas pagadas en efectivo: Factura 25 por $17.000 (pago exacto) y Factura 23 por
$28.000 recibiendo $31.000 en mano ($3.000 de cambio).

```json
// Antes del hotfix
{
  "sales_by_method": [
    { "method_type": "cash", "total": 48000, "count": 2 }
  ],
  "ventas_efectivo": 45000,
  "cambio_entregado": 3000,
  "expected": 145000
}

// Después del hotfix
{
  "sales_by_method": [
    { "method_type": "cash", "total": 45000, "count": 2 }
  ],
  "ventas_efectivo": 45000,
  "cambio_entregado": 3000,
  "expected": 145000
}
```

`expected` (145.000, asumiendo `opening_amount=100000`, sin ingresos/egresos/retiros) no cambia
entre ambos casos — solo `sales_by_method[0].total` deja de estar desalineado con
`ventas_efectivo`.

## Errores

Ninguno nuevo — este hotfix no introduce validaciones ni casos de error adicionales.
