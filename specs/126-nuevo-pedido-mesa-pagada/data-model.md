# Data Model: Nuevo Pedido en Mesa con Cuenta Pagada

No se introduce ninguna entidad, campo ni migración nueva (plan.md, Constitution Check, Principio
VIII). Este documento formaliza, para la Regla 2 de la revisión de dominio ("separar el estado
de la mesa, del pedido y del pago"), cómo esos tres conceptos ya existen como ejes
**independientes** en el modelo actual — sin introducir ningún estado almacenado nuevo.

## Mesa (Table)

| Campo | Valores | Qué representa |
|---|---|---|
| `status` (backend, `TableStatus`) | `libre` \| `ocupada` \| `reservada` | Si hay una sesión de servicio abierta sobre la mesa. No depende de ningún pedido individual. |
| `deriveTableStatus(orders, tableStatus)` (frontend, **derivado, no persistido**) | `por_confirmar` \| `pago_pendiente` \| `en_preparacion` \| `listo` \| `ocupada` \| `reservada` \| `libre` | Insignia visual de la grilla — se calcula a partir de los pedidos vivos de la mesa en cada render, nunca se guarda. |

**No existe, ni se introduce, un estado "pendiente de liberar" propio de la mesa.** La condición
que bloquea "Liberar Mesa" (`has_billable_orders`/`has_pending_balance`) vive en los **pedidos**
de la sesión, no en un campo de la mesa — una mesa sigue siendo `'ocupada'` sin importar cuántas
cuentas sin resolver tenga.

## Pedido (CustomerOrder / DiningOrder)

| Eje | Campo | Valores | Independiente de |
|---|---|---|---|
| Operativo (pedido) | `status` (backend `OrderStatus`) | `recibida` \| `abierta` \| `bloqueada` \| `pagada` \| `cancelada` | el estado financiero (ver abajo) y el estado de cocina |
| Operativo (cocina, por ítem) | `estado_cocina` (`KitchenStatus`) | `pendiente` \| `en_preparacion` \| `listo` \| `anulado` | el estado del pedido completo — un pedido `'pagada'` puede tener ítems todavía `en_preparacion` |
| Identidad dentro de la mesa | `table_order_number` (spec 087) | entero, estable dentro del turno de caja | — |

## Estado financiero del pedido/cuenta — **siempre derivado, nunca almacenado**

| Señal | Cómo se calcula | Significa |
|---|---|---|
| `paid` (computado) | existe una `Sale` para el pedido | el pedido ya se cobró/facturó, sin importar su `status` ni su cocina |
| `pending_balance` (computado, spec 123) | suma de adiciones agregadas después de facturar, sin cobrar | saldo por cobrar sobre un pedido **ya pagado** |

Regla 2 exige explícitamente no confundir el estado operativo con el financiero ("un pedido
entregado puede continuar pendiente de pago"): un pedido `pagada`/`paid=true` con ítems
`en_preparacion` está financieramente resuelto y operativamente en curso al mismo tiempo — ambos
ejes son reales simultáneamente, no hay contradicción porque nunca fueron el mismo campo.

**No se introduce** ningún estado almacenado "pendiente de pago" / "parcialmente pagado" /
"pagado": calcularlo cada vez desde `paid` + `pending_balance` es precisamente lo que evita la
inconsistencia entre estado guardado y movimientos reales que la propia Regla 2 señala como
riesgo.

## Sesión de mesa (TableSession)

Agrupa todos los pedidos de una mesa durante una visita. Determina la pertenencia de un pedido
nuevo: **todo pedido creado mientras la sesión está `active` pertenece a esa misma sesión**
(`table_session_id`); no hay ningún criterio adicional de "¿es la misma ronda?" — la sesión, no
el pedido, es la unidad de "visita". Permanece `active` sin importar cuántos pedidos se hayan
pagado o cuántas cuentas sin resolver tenga en paralelo (A-138). Solo "Liberar Mesa"
(`release_paid_session`/`close_session`) la cierra; la siguiente visita abre una sesión nueva
(spec 010).

```text
Sesión de mesa: active ──[Liberar Mesa, sin pedidos/saldo sin resolver]──> closed
                  │
                  ├─ Pedido 1 (independiente, propia cuenta/saldo/factura)
                  ├─ Pedido 2 (independiente, propia cuenta/saldo/factura) ─ puede crearse
                  │             en cualquier momento mientras la sesión esté active (A-138),
                  │             sin tocar el estado/saldo del Pedido 1
                  └─ Pedido N …
```

## Cuenta (Account)

Cada pedido ya tiene su propia cuenta de cobro — su propia `Sale`/factura, su propio
`pending_balance`, su propio ciclo. Varias cuentas de la misma mesa pueden quedar sin resolver en
paralelo (A-138); **ninguna operación las fusiona automática ni explícitamente** (FR-002, FR-010)
— se cobran siempre por separado, cada una generando su propia factura, sin importar el orden.

## Invariantes (no nuevos — ya exigidos por el código existente, confirmados en research.md)

- Una sesión de mesa `active` nunca se cierra con algún pedido `recibida`/sin `Sale`/con
  `pending_balance > 0` (`release_paid_session`, `_assert_closable`).
- Crear un pedido vía `POST /orders` con el mismo `client_request_id` que una petición anterior
  no crea un segundo registro (dedup, `orders/service.py:617-619`) — protege contra reintentos de
  red duplicando un pedido.
- El cobro de un pedido individual y el cierre/liberación de una sesión toman bloqueo de fila
  (`with_for_update`) sobre sus propios recursos — una liberación en curso y un cobro en curso
  sobre la misma mesa nunca leen un estado a medio escribir (research.md, Decisión de
  concurrencia).
