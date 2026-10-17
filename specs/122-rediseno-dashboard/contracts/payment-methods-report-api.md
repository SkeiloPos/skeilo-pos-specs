# Contrato: `GET /api/v1/cash/reports/payment-methods` (nuevo)

**Spec**: [../spec.md](../spec.md) · **Data model**: [../data-model.md](../data-model.md) · **Research**: [../research.md](../research.md)

Endpoint nuevo, mismo prefijo y misma protección (`require_tenant_admin`) que la familia ya existente `GET /cash/reports/current` y `GET /cash/reports/period`. No reemplaza ni modifica ninguno de los dos.

## Request

```
GET /api/v1/cash/reports/payment-methods
```

| Parámetro | Tipo | Requerido | Descripción |
|---|---|---|---|
| `period` | `shift\|current_shift\|day\|week\|month\|range` | Sí | Mismo selector de período que ya usa el reporte operativo. |
| `shift_id` | UUID | Solo si `period=shift` | Turno específico (igual que `GET /cash/shifts/{id}/sales-report`). |
| `date` | date (`YYYY-MM-DD`) | No | Día de referencia para `day`/`week`/`month` (por defecto, hoy en la zona del tenant). |
| `date_from` / `date_to` | date | Obligatorios si `period=range` | Límites inclusivos del rango. |
| `cash_register_id` | UUID | No | Filtra por caja (igual semántica que los endpoints existentes). |

Reglas de validación: idénticas a `GET /cash/reports/period` (422 si `period=range` sin `date_from`/`date_to`, o `date_from > date_to`; 404 si `cash_register_id` no existe); 422 si `period=shift` sin `shift_id`, o si `shift_id` no existe.

## Response

`200 OK` con la lista de filas bucketed:

```jsonc
{
  "bucket_unit": "day",
  "rows": [
    {
      "bucket_start": "2026-10-13T05:00:00Z",
      "payment_method_id": "b1f2...",
      "payment_method_name": "Efectivo",
      "amount": "182000.00"
    },
    {
      "bucket_start": "2026-10-13T05:00:00Z",
      "payment_method_id": "c3a4...",
      "payment_method_name": "Nequi",
      "amount": "95500.00"
    }
    // ...una fila por (bucket, método) con pagos > 0; sin ceros rellenados
  ]
}
```

`bucket_unit` es el mismo para toda la respuesta, resuelto a partir de `period` (research.md §6):

| `period` | `bucket_unit` |
|---|---|
| `shift`, `current_shift`, `day` | `hour` |
| `week` | `day` |
| `month` | `week` |
| `range` | `day` |

Sin pagos en el período: `200 OK` con `rows: []` (nunca `404`, mismo criterio que el resto de la familia de reportes con cero resultados).

## Casos de error

| Código | Causa |
|---|---|
| `422` | `period=range` sin `date_from`/`date_to`, o `date_from > date_to`; `period=shift` sin `shift_id`. |
| `404` | `cash_register_id` no existe; `shift_id` no existe. |
| `401`/`403` | Sin sesión, o sesión sin rol de administrador del tenant (`require_tenant_admin`). |

## Ejemplos

Ingresos por método de pago de la semana que contiene el 13 de octubre de 2026 (bucket diario):

```
GET /api/v1/cash/reports/payment-methods?period=week&date=2026-10-13
```

Ingresos del turno actualmente abierto de la caja Principal (bucket por hora):

```
GET /api/v1/cash/reports/payment-methods?period=current_shift&cash_register_id=<uuid-caja-principal>
```
