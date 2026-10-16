# Contrato: `total` en `OrderResponse` (campo nuevo)

**Spec**: [../spec.md](../spec.md) · **Data model**: [../data-model.md](../data-model.md) · **Research**: [../research.md](../research.md)

Extiende el modelo de respuesta `OrderResponse`, ya usado por `GET /api/v1/orders` (ambas ramas) y `GET /api/v1/orders/{id}`. **No es un endpoint nuevo** ni cambia ningún parámetro de request — es un campo adicional en la respuesta, retrocompatible: cualquier cliente que no lo lea sigue funcionando exactamente igual que hoy.

## Campo

| Campo | Tipo | Descripción |
|---|---|---|
| `total` | `Decimal \| null` | Monto final de la orden (subtotal de líneas no anuladas, menos descuento, más domicilio cuando aplica, nunca negativo; o el total de la `Sale` cuando la orden ya tiene factura propia — misma fórmula que `billing.total`). |

## Dónde viaja poblado y dónde viaja `null`

| Ruta | `total` |
|---|---|
| `GET /orders/{id}` (detalle) | **Siempre poblado.** Igual a `billing.total`. |
| `GET /orders?page=&size=...` (listado paginado — pantalla "Órdenes") | **Siempre poblado**, resuelto en bloque para toda la página (research.md §1) — nunca una consulta por fila. |
| `GET /orders` (sin `page` ni `size` — Terminal de Mesas / Dashboard) | **`null`**, sin cambios respecto a hoy. Esta rama está fuera del alcance de esta spec. |
| `POST /orders`, y demás endpoints que devuelven `OrderResponse` vía `_load_order` (checkout, confirmar pago, cancelar, etc.) | **Siempre poblado** (misma ruta que el detalle, `_load_order`). |

`null` en `total` significa "este endpoint no lo calculó para esta orden" — igual criterio que `billing`/`invoice_reference` hoy (D15): nunca se sustituye por `0` cuando no se calculó.

## Ejemplo — listado paginado

```
GET /api/v1/orders?page=1&size=20
```

```jsonc
{
  "items": [
    {
      "id": "4f2e2b7e-...",
      "customer_name": "Deimer Hernandez",
      "status": "pagada",
      "paid": true,
      "total": "29000.00",
      "billing": null,            // sin cambios (D3): el desglose completo sigue sin calcularse aquí
      "invoice_reference": null,  // sin cambios: tampoco se resuelve en el listado
      "...": "..."
    }
  ],
  "total": 7,
  "page": 1,
  "size": 4,
  "pages": 2
}
```

(Nota: el `"total": 7` de más afuera es el conteo de resultados de `Page[T]`, ya existente — no confundir con `items[].total`, el campo nuevo de esta spec.)

## Ejemplo — detalle

```
GET /api/v1/orders/4f2e2b7e-...
```

```jsonc
{
  "id": "4f2e2b7e-...",
  "total": "29000.00",
  "billing": {
    "state": "factura_propia",
    "source": "factura",
    "subtotal": "29000.00",
    "discount": "0.00",
    "delivery_fee": "0.00",
    "total": "29000.00",
    "...": "..."
  },
  "...": "..."
}
```

`items[].total` siempre coincide con `items[].billing.total` cuando ambos están presentes (mismo origen de datos, misma fórmula).

## Casos de error

Sin cambios respecto al endpoint actual — este contrato no añade parámetros de request ni nuevos códigos de estado.
