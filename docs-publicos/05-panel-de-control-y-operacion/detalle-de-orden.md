---
title: "Detalle de Orden"
description: "Cómo auditar el cobro exacto de cualquier pedido —importes, descuentos y envío— y despachar un domicilio sin salir de la pantalla."
---

# Detalle de Orden

Cuando hay que resolver "¿por cuánto se cobró este pedido y por qué?" o despachar un domicilio con
un mensajero, buscar la respuesta en el módulo de Ventas o transcribir a mano los datos de entrega
es lento justo cuando se necesita rapidez. El Detalle de Orden resuelve ambos problemas en una sola
pantalla de consulta: muestra el desglose económico completo de cualquier pedido (cantidad, precio
unitario, descuento por promoción, costo de envío y total) con los valores exactos con los que se
cobró, y, en los pedidos a domicilio, los datos de entrega listos para copiar y enviar al
mensajero.

Es una pantalla de solo lectura: desde aquí no se cobra, no se edita ningún importe ni se reimprime
nada. Su valor es permitir verificar y despachar sin saltar a otra pantalla ni a otro sistema, en
menos de 10 segundos desde que se abre.

## Roles que pueden usar esta función

- **Cajero/Staff**
- **Administrador de Tenant**

Ambos roles ven exactamente el mismo contenido en esta pantalla, incluidos todos los importes: no
hay ningún dato económico que el Administrador de Tenant vea y el Cajero/Staff no vea, ni
viceversa. Es una decisión de diseño explícita y no un descuido: la razón es que el Cajero/Staff ya
tiene acceso a los mismos importes y totales desde la pantalla de cobro en mesa que usa para
cerrar cuentas, así que mostrarle el desglose aquí no le expone ninguna información nueva que no
pudiera ver ya por otro camino.

## Flujo paso a paso

1. Desde el listado de Órdenes, el usuario abre el detalle de cualquier pedido, sin importar su
   estado (recibido, en curso, pagado o cancelado).
2. El sistema muestra en el encabezado el tipo de pedido —la mesa cuando es de mesa, "Para llevar"
   o "Domicilio"— y su estado actual; un pedido cancelado conserva su desglose con los valores
   originales junto a la etiqueta "Cancelada", en vez de ocultarlo o mostrarlo en cero.
3. Debajo, el sistema lista cada producto del pedido con su cantidad, su precio unitario y el
   importe de esa línea (ya incluye los adicionales cobrados por esa línea, por ejemplo los
   toppings de un domicilio pedido por Menú QR). Si algún producto fue anulado, aparece marcado
   como tal, sin un importe cobrable, para que quede trazable que se anuló sin alterar el total.
4. El sistema muestra un resumen con el Subtotal (la suma de los importes de los productos), el
   Descuento —solo si es mayor a $ 0, con el nombre de la promoción que lo originó—, el Envío
   "Domicilio" —solo si es mayor a $ 0— y el Total.
5. Si el pedido es a domicilio, el sistema muestra un bloque "Datos de entrega" con el nombre de
   quien recibe, el teléfono, la dirección y las referencias de entrega que estén diligenciados
   (los que falten simplemente no aparecen, sin espacios vacíos). Con un clic en "Copiar datos", el
   usuario lleva ese texto al portapapeles para pegarlo directamente en el chat del mensajero, y el
   sistema confirma el copiado con un mensaje.
6. Si el pedido todavía no se ha cobrado, el sistema muestra el Total como Subtotal más Envío, sin
   fila de descuento, junto con un aviso de que el descuento se calculará en el momento de cobrar y
   de que ese total puede cambiar.
7. Si el pedido se cobró como parte de una cuenta de mesa unificada (varias comandas cobradas juntas
   en una sola factura), el sistema muestra el desglose propio de ese pedido junto con un aviso de
   que el total facturado real está en el módulo de Ventas, para no dar la impresión de que el
   total mostrado aquí es el de la factura conjunta.
8. Si el pedido es un caso histórico que no guardó el desglose por producto, el sistema muestra el
   total disponible junto con un aviso de que esa orden no tiene el detalle de precios por producto,
   en vez de inventar importes en cero.

## Reglas de negocio y límites

- El importe de cada línea de producto es siempre el de lista (precio unitario multiplicado por la
  cantidad, más los adicionales de esa línea); el descuento nunca se resta ahí, solo en la fila de
  Descuento del resumen, de modo que sumar a mano los importes visibles siempre da exactamente el
  Subtotal mostrado — verificado en spec 094-detalle-orden-desglose-entrega (FR-002,
  FR-004, FR-005, Q5).
- La fila de Descuento solo aparece cuando el descuento es mayor a $ 0, y muestra el nombre de la
  promoción que lo originó; si no quedó un nombre registrado, o si el descuento proviene de más de
  una promoción a la vez, se muestra con la etiqueta genérica "Descuento" — verificado en
  spec 094-detalle-orden-desglose-entrega (FR-006, FR-009, FR-010).
- La fila de Envío, rotulada "Domicilio", solo aparece cuando el costo de envío es mayor a $ 0 —
  verificado en spec 094-detalle-orden-desglose-entrega (FR-007).
- El Total se calcula como Subtotal menos Descuento más Envío, y nunca puede quedar en un valor
  negativo — verificado en spec 094-detalle-orden-desglose-entrega (FR-008).
- Cuando el descuento viene de una promoción de tipo porcentaje aplicada a un producto con
  adicionales (toppings) seleccionados, el descuento mostrado ya refleja que esos adicionales se
  cobraron completos, sin descuento: el porcentaje solo se aplicó sobre el precio base del
  producto — verificado en spec 083-presentaciones-y-promociones (FR-027) y
  spec 094-detalle-orden-desglose-entrega (FR-002 a FR-004).
- Todos los importes mostrados son los que se guardaron con el pedido o con su cobro: nunca se
  recalculan contra el catálogo de precios ni contra las promociones vigentes en el momento de
  abrir la pantalla, así el precio del producto haya cambiado desde entonces — verificado en
  spec 094-detalle-orden-desglose-entrega (RN-001, FR-022).
- Cuando existe una factura que cubre únicamente ese pedido, el Total mostrado coincide
  exactamente con el total de esa factura en el módulo de Ventas — verificado en
  spec 094-detalle-orden-desglose-entrega (FR-024).
- Cuando el pedido se cobró dentro de una cuenta unificada de mesa junto con otros pedidos, la
  pantalla avisa explícitamente que el total facturado real está en Ventas, en lugar de presentar
  el total propio del pedido como si fuera ese total — verificado en
  spec 094-detalle-orden-desglose-entrega (FR-024a).
- Los productos anulados permanecen visibles en la lista, marcados como tales y sin importe
  cobrable, en vez de ocultarse: así la suma de lo visible sigue coincidiendo con el Subtotal y la
  anulación queda trazable para quien audita — verificado en
  spec 094-detalle-orden-desglose-entrega (FR-019, FR-019a).
- El bloque "Datos de entrega" solo aparece en pedidos a domicilio, y únicamente muestra los campos
  que sí están diligenciados; nunca aparece un espacio vacío ni un texto de relleno en su lugar —
  verificado en spec 094-detalle-orden-desglose-entrega (FR-015, FR-020).
- Todos los montos se presentan en pesos colombianos, sin decimales, con punto como separador de
  miles y un espacio después del símbolo (por ejemplo, $ 14.000) — verificado en
  spec 094-detalle-orden-desglose-entrega (FR-021, RN-002).
- Cajero/Staff y Administrador de Tenant ven exactamente el mismo contenido en esta pantalla,
  importes incluidos: no existe ninguna diferencia de información económica entre ambos roles —
  verificado en spec 094-detalle-orden-desglose-entrega (RN-007).

## Diferenciador de mercado

En un punto de venta tradicional del sector heladerías/granizados, verificar por cuánto se cobró
un pedido antiguo suele exigir buscarlo en el módulo de ventas o pedir la factura impresa, y
enviarle a un mensajero los datos de un domicilio significa transcribirlos a mano desde otra
pantalla, con el riesgo de equivocar un dígito del teléfono o de la dirección. SkeiloPOS resuelve
ambas cosas en la misma pantalla de consulta del pedido: el desglose económico queda congelado tal
como se cobró —inmune a cambios posteriores de precio o de promoción— y los datos de entrega se
copian al portapapeles con una sola acción, lista para pegar en el chat del domiciliario.

---

> **Verificado contra**: spec 094-detalle-orden-desglose-entrega (spec.md y data-model.md) y
> spec 083-presentaciones-y-promociones (spec.md) — 2026-10-08.
