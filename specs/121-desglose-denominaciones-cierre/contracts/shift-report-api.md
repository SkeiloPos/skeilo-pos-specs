# Contrato — Reporte de cierre con «Desglose del conteo»

**Spec**: [../spec.md](../spec.md) (FR-020 a FR-024, US4–US5) · **Data model**: [../data-model.md](../data-model.md) §2–3 ·
**Research**: [../research.md](../research.md) R6, R7, R9

Endpoint existente. Cambio **aditivo**: ningún campo se elimina ni cambia de tipo.

## `GET /api/v1/cash/shifts/{shift_id}/report`

Autenticación y permisos: **sin cambios** (`get_current_user`; el histórico sigue siendo solo para
administradores en su propio endpoint de listado).

### Cambios en la respuesta `ShiftReportResponse`

```jsonc
{
  "shift": {
    "id": "uuid", "user_name": "Ana",                       // quien ABRIÓ
    "counted_amount": "115000.00", "close_note": null,
    "closed_by_user_id": "uuid", "closed_by_user_name": "Luis"   // NUEVO (null en históricos)
    // …resto sin cambios
  },
  "reconciliation": { /* sin cambios */ },
  "movements": [ /* sin cambios */ ],
  "denominations": [                                        // ANTES: [{denomination, quantity}]
    { "denomination": "100000.00", "kind": "billete", "quantity": 1, "subtotal": "100000.00" },
    { "denomination": "10000.00",  "kind": "billete", "quantity": 1, "subtotal": "10000.00" },
    { "denomination": "5000.00",   "kind": "billete", "quantity": 1, "subtotal": "5000.00" }
  ],
  "close_note": null
}
```

| Campo de `denominations[]` | Tipo | Origen |
|----------------------------|------|--------|
| `denomination` | cadena decimal | Columna persistida |
| `kind` | `"billete"` \| `"moneda"` | Columna persistida (snapshot) |
| `quantity` | entero `> 0` | Columna persistida |
| `subtotal` | cadena decimal | **Derivado** en la lectura: `denomination × quantity` (no se almacena) |

Orden: `denomination` de **mayor a menor**. Solo aparecen las líneas persistidas (cantidad > 0).

### Invariantes (verificables)

1. **FR-021**: para todo turno cerrado con líneas, `Σ denominations[].subtotal == shift.counted_amount`.
2. **FR-022**: turno cerrado sin líneas → `denominations: []` y `counted_amount` intacto. La pantalla
   muestra el texto exacto «No se registró desglose para este turno».
3. **US5**: turno cerrado antes de esta spec → `closed_by_user_id/name` son `null` y la pantalla
   **omite** la línea «Contado por» sin marcador ni error; si tenía líneas, ahora traen `kind`.
4. **US4-6**: `closed_by_user_name` es el nombre **al momento del cierre**; renombrar o desactivar
   al usuario después no lo cambia.
5. **Turno abierto**: `denominations: []`, `closed_by_*: null` (el reporte de un turno abierto no se
   muestra al usuario, pero el endpoint no falla).

## Contrato de presentación (pantalla e impresión)

Sección «Desglose del conteo» en `cash-report.component.ts`, entre «Arqueo de caja» y «Movimientos»:

| Elemento | Regla |
|----------|-------|
| Línea «Contado por: {closed_by_user_name}» | Solo si el valor existe |
| Tabla *Denominación · Tipo · Cantidad · Subtotal* | Solo si hay líneas; tipo como «Billete»/«Moneda»; importes con `store.fmt` (`$ 100.000`) |
| Fila final «Total» | Suma de los subtotales mostrados (debe igualar «Efectivo contado») |
| Mensaje «No se registró desglose para este turno» | Solo si no hay líneas |
| Impresión (`window.print()`) | La tabla o el mensaje entran en el documento; filas con `break-inside: avoid` y encabezado repetible; los botones siguen con `print:hidden` |

La misma sección se ve en el reporte inmediato al cerrar (cajero) y en el abierto desde el
histórico (administrador) (FR-023); el resaltado de faltante/sobrante de la diferencia no cambia.
