# Contrato: estado de orden e ítem en las respuestas de la API

**Feature**: [spec.md](../spec.md) · **Plan**: [plan.md](../plan.md) · **Data model**: [data-model.md](../data-model.md)

Este documento describe el contrato observable por el frontend (y por cualquier consumidor
externo de la API de `pos-backend`) para los campos de estado de orden y de ítem. No es una
definición OpenAPI exhaustiva — documenta exactamente los campos y valores que cambian con
esta funcionalidad, que son los que el frontend debe consumir sin traducir ni inferir
(FR-008/FR-009).

## Orden (`CustomerOrder`), campos relevantes

| Campo | Tipo | Valores válidos (post-feature) | Notas de contrato |
|---|---|---|---|
| `status` | string | `pendiente` \| `abierta` \| `bloqueada` \| `pagada` \| `cancelada` | `recibida` deja de ser válido. Toda orden nueva se crea con `status = "pendiente"`, sin excepción por canal (`qr`, `caja`/mostrador, `domicilio`). |
| `payment_status` | string | `UNPAID` \| `PAID` \| `PARTIAL` | Campo nuevo. `UNPAID` por defecto al crear; `PAID`/`PARTIAL` solo si el pago se confirma en el mismo acto de creación. Independiente de `status`. |

## Ítem de orden (`OrderItem`), campos relevantes

| Campo | Tipo | Valores válidos | Notas de contrato |
|---|---|---|---|
| `estado_cocina` | string | `pendiente` \| `en_preparacion` \| `listo` \| `anulado` | Sin cambios de catálogo. Todo ítem nuevo nace en `pendiente`, ya hoy — este contrato lo fija explícitamente como invariante verificado por esta funcionalidad. |

## Obligaciones del consumidor (frontend)

1. **No traducir por inferencia de otros campos.** El valor mostrado para el estado de una
   orden es siempre `status` tal cual llega; el valor mostrado para un ítem es siempre
   `estado_cocina` tal cual llega. Ningún otro campo (`payment_status`, `channel`, el estado de
   otros ítems) puede sustituir el valor mostrado para esa entidad específica.
2. **Lista estática de estados conocidos, no un endpoint.** El frontend mantiene su propia
   lista (`KNOWN_ORDER_STATUSES`, `KNOWN_KITCHEN_STATUSES`) que debe actualizarse manualmente
   cada vez que el catálogo autoritativo del backend cambie (este mismo contrato es la
   referencia a sincronizar).
3. **Valor no reconocido → mostrar crudo + loguear error.** Si la API devuelve un valor de
   `status` o `estado_cocina` que no está en la lista estática conocida, el frontend:
   - muestra ese valor crudo en pantalla (nunca un estado por defecto como "En preparación"),
   - registra un error en la consola del navegador identificando el campo y el valor no
     reconocido.
4. **Agregados de UI (p. ej. estado de ocupación de una mesa) no son "el estado de la orden".**
   Cualquier vista que combine `status`/`payment_status`/`estado_cocina` de varias órdenes o
   ítems para producir un indicador agregado (como la tarjeta de mesa en la Terminal de Mesas)
   debe presentarse como una categoría distinta (ocupación de mesa), nunca como sustituto del
   `status` de una orden o `estado_cocina` de un ítem específico en una vista que muestre esa
   orden/ítem individualmente.

## Ejemplo de respuesta (orden recién creada, caja, sin pago inmediato)

```json
{
  "id": 1234,
  "channel": "COUNTER",
  "status": "pendiente",
  "payment_status": "UNPAID",
  "items": [
    { "id": 1, "product_id": 55, "estado_cocina": "pendiente" }
  ]
}
```

## Ejemplo de respuesta (orden de mostrador pagada de inmediato)

```json
{
  "id": 1235,
  "channel": "COUNTER",
  "status": "pendiente",
  "payment_status": "PAID",
  "items": [
    { "id": 2, "product_id": 56, "estado_cocina": "pendiente" }
  ]
}
```

## Fuera de contrato

- No se expone un endpoint de catálogo dinámico de estados (decisión explícita, FR-010).
- `OrderPaymentAttempt.status` (flujo de comprobante de transferencia QR) no se modifica ni se
  consolida con `payment_status`; son conceptos relacionados pero distintos.
