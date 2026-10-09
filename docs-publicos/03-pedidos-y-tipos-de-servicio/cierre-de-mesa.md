---
title: "Cierre de mesa"
description: "Cómo cobrar y liberar una mesa, dividir el pago entre comensales y qué hacer si queda un pago pendiente de confirmar."
---

# Cierre de mesa

Cerrar una mesa es el momento en que el Cajero/Staff cobra todo lo consumido por los comensales
que se sentaron en ella, registra la venta y deja la mesa libre para el siguiente grupo. En una
heladería con mesas físicas, este es el punto donde se concreta el dinero real: un error aquí
significa cobrar de más, cobrar de menos, o dejar una mesa ocupada sin necesidad.

Este artículo cubre el cierre normal (cuenta completa o dividida entre comensales) y, con el mismo
nivel de detalle, qué hacer cuando la mesa tiene un pago que todavía no se ha confirmado — el caso
que más bloquea a un cajero si no sabe cómo resolverlo.

## Roles que pueden usar esta función

- **Cajero/Staff**: es el único rol que cierra mesas, revisa pagos pendientes, divide cuentas y
  libera mesas desde la Terminal de Mesas.

## Flujo paso a paso

1. El Cajero/Staff abre la Terminal de Mesas y selecciona la mesa que quiere cobrar.
2. **Si la mesa tiene un pago pendiente de confirmar** (un comensal eligió efectivo y todavía no
   se le ha recibido el dinero, o eligió transferencia y su comprobante está sin revisar), el
   panel central muestra el bloque "Pagos por confirmar" en lugar del pedido. Si además esa misma
   mesa ya tiene otro pedido pagado o activo, aparecen dos pestañas: "Pagos por confirmar" (la que
   se abre primero, por ser la más urgente) y "Pedido de la mesa" — el cajero puede alternar entre
   ellas sin perder ninguna de las dos.
3. **El sistema no permite cerrar una mesa mientras tenga algún pago pendiente de confirmar.** Hay
   que resolver cada pago pendiente antes de poder cobrar, así:
   - Si el pago es en **efectivo**: una vez el comensal entrega el dinero físicamente, el cajero
     registra el monto recibido y pulsa "Confirmar efectivo"; el sistema calcula el cambio
     automáticamente.
   - Si el pago es por **transferencia** y el comensal **ya subió un comprobante**: el cajero lo
     revisa y pulsa "Aprobar" si es válido, o "Rechazar" si no lo es (indicando el motivo). Este
     "Rechazar" no cancela el pedido: solo invita al comensal a volver a intentar con otro
     comprobante, sin perder los productos que ya había elegido.
   - Si el pedido **no debe seguir adelante** —el comensal se fue sin pagar, faltó un insumo,
     cualquier otro motivo operativo— y el pago sigue en efectivo sin confirmar, o es una
     transferencia que **todavía no tiene comprobante subido**, el cajero puede en cambio pulsar
     "Rechazar pedido". A diferencia del "Rechazar" del punto anterior, esta acción cancela el
     pedido **completo** (no solo el intento de pago) y exige escribir un motivo obligatorio antes
     de poder confirmar — el sistema no deja continuar con el motivo vacío.
4. Al confirmar el efectivo, aprobar el comprobante, o rechazar el pedido completo, la pantalla se
   actualiza de inmediato: si ya no queda ningún otro pago pendiente de esa mesa, las pestañas
   desaparecen y el panel muestra directamente el pedido, sin que el cajero tenga que volver a
   tocar la tarjeta de la mesa para que aparezca.
5. Si quedan más pagos pendientes de otros comensales de la misma mesa, se repite el paso 3 para
   cada uno hasta resolverlos todos.
6. Con todos los pagos resueltos, el sistema también exige que no quede ningún pedido sin
   confirmar por cocina, ni ningún producto todavía "pendiente" o "en preparación": si algo sigue
   en ese estado, hay que esperar a que cocina lo termine, o anularlo desde el panel de cocina,
   antes de poder cerrar la mesa.
7. El cajero elige cómo cobrar: la cuenta completa en un solo pago, o dividida entre los
   comensales.
8. Si divide la cuenta, asigna cada producto (o cada unidad de un producto, si cocina ya lo
   terminó) a un comensal concreto. No existe un botón de "dividir en partes iguales": el reparto
   siempre es producto por producto o unidad por unidad, y la suma de lo asignado debe coincidir
   exactamente con la cantidad original del producto.
9. El cajero registra el pago (o los pagos, si la cuenta se dividió). Si es en efectivo, anota el
   monto recibido y el sistema calcula el cambio automáticamente.
10. Al confirmar, el sistema registra la venta (o una venta por cada bloque, si se dividió), marca
    los pedidos como pagados, cierra a los comensales de esa sesión y libera la mesa — todo en una
    sola operación: si algo falla a mitad de camino, no queda ningún cobro a medias.
11. El cajero puede imprimir o reimprimir la factura desde el mismo panel, antes o después de
    liberar la mesa.

## Reglas de negocio y límites

- El sistema no permite cerrar una mesa mientras tenga un pedido sin confirmar por cocina, o con
  algún producto todavía "pendiente" o "en preparación" (spec 010, regla `RN-MESA-04`).
- No existe ninguna división automática "a partes iguales": repartir la cuenta exige asignar
  explícitamente cada producto o cada unidad a un comensal, y la suma de lo repartido debe cuadrar
  exactamente con la cantidad original del producto (spec 010, `RN-MESA-05`, `RN-MESA-06`).
- Solo se puede repartir por unidades un producto que cocina ya haya terminado; mientras esté en
  preparación, solo puede asignarse completo a un único comensal, nunca partido entre varios (spec
  010, `RN-MESA-07`).
- Un producto anulado no se puede asignar a ningún comensal, porque no se cobra (spec 010,
  `RN-MESA-08`).
- El vuelto (cambio) solo puede salir de un pago en efectivo; si el excedente viene de un medio
  electrónico, el sistema lo rechaza en vez de calcular un vuelto sobre ese pago (spec 010,
  `RN-MESA-21`).
- El cobro completo de la mesa (las ventas, el paso de los pedidos a pagados, el cierre de los
  comensales y la liberación de la mesa) ocurre en una sola operación: si cualquier paso falla, no
  queda ningún cobro a medias registrado (spec 010, `RN-MESA-22`).
- Rechazar un pedido con pago en efectivo pendiente, o con transferencia sin comprobante todavía
  subido, cancela el pedido completo y exige un motivo obligatorio — a diferencia de rechazar un
  comprobante ya subido, que solo invita al comensal a reintentar (spec 044, requisitos `FR-001` a
  `FR-005`).
- En cuanto el cajero confirma un pago en efectivo o aprueba un comprobante, el pedido se muestra
  de inmediato en el panel de la mesa, sin que el cajero tenga que volver a seleccionar la tarjeta
  (spec 044, `FR-006`).
- Si la mesa tiene a la vez un pago pendiente de confirmar y un pedido ya pagado o activo, el
  sistema muestra ambos en pestañas separadas, con "Pagos por confirmar" abierta por defecto (spec
  048, `FR-001`, `FR-004`).
- El cálculo de adicionales con recargo (por ejemplo, un topping extra) cobra exactamente la
  cantidad que el comensal eligió en el carrito, sin multiplicarla por la cantidad de productos de
  esa línea (spec 089, `FR-001`).

## Diferenciador de mercado

En un punto de venta tradicional, dividir una cuenta entre varios comensales suele significar
repartir el total a ciegas entre todos por igual, sin importar lo que cada uno realmente consumió.
En SkeiloPOS, el reparto siempre es producto por producto o unidad por unidad, así que cada
comensal paga exactamente lo que pidió, nunca un promedio.

Además, en un POS tradicional una transferencia suele marcarse como "pagada" de palabra, sin
ninguna evidencia que quede registrada, y un pedido que ya no debe seguir normalmente exige anular
factura y tickets por separado. En SkeiloPOS, todo pago por transferencia queda respaldado por un
comprobante que el cajero aprueba o rechaza con motivo, y si el pedido ya no debe seguir, el cajero
lo rechaza por completo en el mismo panel, con un solo motivo obligatorio — nunca se queda
"pendiente de revisión" sin ninguna salida.

Para el caso de un pago QR por transferencia pendiente de confirmar, el detalle completo de esa
revisión (aprobar, rechazar, y qué ve el comensal en cada caso) está en
[Pagos por confirmar](../04-pago-y-checkout/pagos-por-confirmar.md).

---

> **Verificado contra**: specs 010-sesion-mesa-reparto-cierre-barrido,
> 044-rechazo-pedido-pago-pendiente, 048-pestanas-pago-pendiente-pedido,
> 089-fix-adicionales-cierre-mesa-caja-pos — 2026-10-08.
