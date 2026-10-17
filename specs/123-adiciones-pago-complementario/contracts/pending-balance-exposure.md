# Contrato — Exponer el saldo pendiente en la cuenta de la mesa

**FR cubiertos**: FR-006c, FR-015.

## `GET /table-sessions/{id}/bill` (extensión additiva)

Endpoint ya existente (`table_sessions/service.py::compute_bill`), única implementación de "cuánto
se le debe cobrar a esta mesa" con uso real confirmado en frontend (ver `research.md` D6; las otras
dos implementaciones fragmentadas, documentadas en
`specs/000-reconocimiento/contradiccion-06-cuenta-a-cobrar-tres-implementaciones.md`, no se tocan
en esta spec).

### Cambio

Se agrega un campo nuevo, de solo lectura, al final de la respuesta existente — ningún campo
actual cambia de tipo ni de significado:

```jsonc
{
  // ...campos existentes sin cambios...
  "pending_balance": "2000.00"   // suma del saldo pendiente (data-model.md §1) de todas las
                                   // órdenes de la sesión; "0.00" si no hay ninguno
}
```

### Consumo en frontend

`pos-checkout-panel.component.ts` muestra el bloque "Saldo pendiente: $X" y la acción "Cobrar
saldo" únicamente cuando `pending_balance > 0`, en el mismo bloque post-cobro donde ya están
"Imprimir Factura" y "Liberar Mesa" (research.md D8).

### Compatibilidad

Campo aditivo — ningún consumidor existente de este endpoint que no lea `pending_balance` ve algún
cambio de comportamiento.
