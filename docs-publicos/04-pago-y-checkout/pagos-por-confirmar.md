---
title: "Pagos por confirmar"
description: "La pantalla donde el Cajero/Staff revisa, aprueba o rechaza cada pago de un pedido por QR antes de que avance a cocina."
---

# Pagos por confirmar

"Pagos por confirmar" es la pantalla donde el Cajero/Staff verifica de verdad que el dinero de un
pedido por QR llegó —o que el efectivo fue recibido— antes de que ese pedido se prepare y se
sirva. Sin este paso, un negocio quedaría expuesto a servir pedidos no pagados o respaldados por
un comprobante inválido.

## Roles que pueden usar esta función

- **Cajero/Staff**: es el único rol que confirma pagos en efectivo y que aprueba o rechaza
  comprobantes de transferencia desde esta pantalla.

## Flujo paso a paso

1. El pedido solo aparece en "Pagos por confirmar" una vez el comensal completó su paso de pago:
   confirmó que pagará en efectivo, o subió el comprobante de su transferencia. Nunca aparece
   antes, porque el pedido mismo no se crea para el personal hasta ese momento.
2. El Cajero/Staff abre la Terminal de Mesas y ve el aviso de "Pagos por confirmar" en la mesa
   correspondiente, o en el listado global de pagos pendientes.
3. Si el pago es en **efectivo**: el cajero espera a que el comensal pague físicamente, registra
   el monto recibido y pulsa "Confirmar efectivo"; el sistema calcula el cambio de forma
   automática.
4. Si el pago es por **transferencia** y el comensal ya subió un comprobante: el cajero lo revisa
   y pulsa "Aprobar" si es válido, o "Rechazar" indicando un motivo si no lo es. Este rechazo deja
   el pedido pendiente para que el comensal reintente con un comprobante distinto, sin perder los
   productos que ya había seleccionado.
5. Si el pago sigue en efectivo sin confirmar, o es una transferencia que todavía no tiene
   comprobante subido, el cajero puede en cambio pulsar "Rechazar pedido": esta acción cancela el
   pedido completo —no solo el intento de pago— y exige un motivo obligatorio antes de poder
   confirmar.
6. El motivo de un rechazo de comprobante queda registrado en el historial de la orden, visible
   para el Cajero/Staff y para el Administrador de Tenant; el comensal solo ve que su comprobante
   fue rechazado, sin ver el detalle del motivo.
7. En cuanto el cajero confirma el efectivo o aprueba el comprobante, el pedido queda disponible
   de inmediato en el panel de la mesa, con sus productos, sin que el cajero tenga que volver a
   seleccionar la tarjeta de la mesa para verlo.
8. Mientras el pago siga pendiente o haya sido rechazado, el pedido no puede enviarse a cocina.

## Reglas de negocio y límites

- Un pedido que llega a "Pagos por confirmar" ya tiene su primer intento de pago creado: nunca
  llega a esperar a que el comensal decida con qué pagar (spec 025, criterio `SC-001`).
- Ningún comensal puede iniciar un segundo intento de pago (cambiar de método o subir otro
  comprobante) mientras el primero siga pendiente de revisión; solo puede hacerlo después de que
  el cajero rechace explícitamente el anterior (spec 024, requisito `FR-015a`).
- El motivo de rechazo de un comprobante es obligatorio, y queda en el historial visible para el
  cajero y el Administrador de Tenant, pero no se le muestra al comensal (spec 024, requisito
  `FR-014`).
- Rechazar un pedido con efectivo pendiente o con transferencia sin comprobante aún cancela el
  pedido completo y exige un motivo — distinto del rechazo de un comprobante ya subido, que solo
  invita a reintentar (spec 044, requisitos `FR-001` a `FR-005`).
- El monto recibido en efectivo debe ser igual o mayor al total del pedido; el sistema no permite
  confirmar el pago con un monto menor (spec 024, requisito `FR-010a`).
- Dos decisiones casi simultáneas sobre el mismo intento de pago —dos cajeros, o un doble clic—
  nunca producen dos confirmaciones contradictorias: solo la primera que llegue al sistema tiene
  efecto (spec 024, requisito `FR-018`).
- Si la mesa tiene a la vez un pago pendiente y un pedido ya pagado o activo, el sistema muestra
  ambos en pestañas separadas, para que el cajero no pierda el acceso a ninguno de los dos (spec
  048, requisito `FR-001`).
- Antes de transferir, el comensal ve en su propia pantalla el total exacto a pagar y el detalle
  completo de su pedido (productos, adicionales y el ahorro si hay una promoción vigente), lo que
  reduce el riesgo de que el comprobante que sube no coincida con lo que realmente debe (spec 092,
  requisitos `FR-001`, `FR-005`).

## Diferenciador de mercado

En un punto de venta tradicional, una transferencia suele declararse "pagada" de palabra, sin
ninguna evidencia que quede registrada en el sistema. En SkeiloPOS, todo pago por transferencia
exige un comprobante que el Cajero/Staff aprueba o rechaza explícitamente con motivo, y el pedido
no puede avanzar a cocina sin esa confirmación.

Además, el negocio nunca se queda con un pedido "atascado" sin salida: si el pago no debe seguir
—el comensal se fue, faltó un insumo—, el cajero rechaza el pedido completo con un motivo desde el
mismo panel, en lugar de tener que anular factura y tickets por separado como suele exigir un
flujo de "pedido ya tomado" en un POS tradicional.

---

> **Verificado contra**: specs 024-pagos-ordenes-mesa, 025-revision-pago-antes-envio,
> 092-resumen-pedido-transferencia, 044-rechazo-pedido-pago-pendiente,
> 048-pestanas-pago-pendiente-pedido — 2026-10-08.
