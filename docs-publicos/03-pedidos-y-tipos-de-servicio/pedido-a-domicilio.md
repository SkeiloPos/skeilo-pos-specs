---
title: "Pedido a domicilio"
description: "Cómo capturar los datos de entrega de un domicilio y copiarlos de un clic para despachar con un mensajero."
---

# Pedido a domicilio

Cuando una heladería o un local de granizados entrega pedidos a domicilio, necesita registrar
quién recibe, a dónde, y cuánto cuesta el envío — y después tener esos datos a la mano para
pasárselos a un mensajero sin transcribir nada a mano. SkeiloPOS habilita este tipo de pedido en
la misma pantalla de creación manual que ya usa el Cajero/Staff, con sus propios campos de
entrega.

## Roles que pueden usar esta función

- **Cajero/Staff**: crea el pedido de domicilio con sus datos de entrega y, al momento de
  despachar, copia esos datos para enviarlos al mensajero.

## Flujo paso a paso

1. El Cajero/Staff abre la pantalla de creación de pedido manual (botón fijo "Crear nueva orden"
   o tecla F3 desde la Terminal de Mesas).
2. En el panel de tipo de pedido, selecciona "Domicilio". El sistema no exige seleccionar ninguna
   mesa para este tipo de pedido.
3. A diferencia de "En Mesa" o "Para Llevar" (donde el campo "Cliente" ya trae "Consumidor final"),
   para "Domicilio" el campo "Cliente" aparece vacío y es obligatorio: el cajero debe escribir el
   nombre real de quien recibe el pedido.
4. El cajero completa el campo "Dirección" (obligatorio) y, si lo tiene, el campo "Teléfono"
   (opcional).
5. El cajero escribe el "Valor del domicilio" (obligatorio, un número no negativo). Ese valor se
   suma de inmediato al total que se ve en pantalla, junto al subtotal de los productos.
6. El cajero arma el pedido con el catálogo de productos, igual que en cualquier otro tipo de
   pedido.
7. Si intenta confirmar sin haber diligenciado el nombre del cliente, la dirección o el valor del
   domicilio, el sistema bloquea el envío e indica con claridad cuál de esos campos falta.
8. Al confirmar, el pedido se guarda con tipo de pedido "Domicilio", sin mesa asociada, y con el
   nombre del cliente, la dirección, el teléfono (si se diligenció) y el valor del domicilio
   ingresados en pantalla.
9. El valor del domicilio queda incluido en el total final de la venta/factura que se genera al
   cobrar ese pedido.
10. Al momento de despachar, el cajero abre el Detalle de la Orden y usa la acción "Copiar datos"
    junto al bloque "Datos de entrega": el sistema copia al portapapeles, en texto plano, un
    renglón por cada dato diligenciado —nombre, teléfono, dirección y las notas del pedido como
    referencia de entrega— listo para pegar en el chat del mensajero o de la plataforma de
    entrega, sin transcribir nada a mano. Un aviso breve confirma que la copia se hizo con éxito.

## Reglas de negocio y límites

- El nombre del cliente, la dirección y el valor del domicilio son obligatorios; el teléfono es
  opcional (spec 056, requisitos `FR-003` a `FR-008`).
- El campo "Valor del domicilio" no tiene ningún valor por defecto: un domicilio sin costo exige
  escribir "0" explícitamente, en vez de dejarlo vacío (spec 056, Edge Cases).
- El valor del domicilio se suma tanto al total que se ve en pantalla al crear el pedido como al
  total final de la factura que se genera al cobrarlo; no afecta el total de ningún pedido en mesa
  o para llevar (spec 056, requisitos `FR-009`, `FR-011`, `FR-012`).
- La acción "Copiar datos" solo incluye los campos que sí están diligenciados: nunca deja líneas
  en blanco, la palabra "null" ni guiones de relleno en el texto copiado (spec 094, requisitos
  `FR-016`, `FR-017`, `FR-020`).
- Si el navegador o el dispositivo no permite acceder al portapapeles, el sistema avisa que no se
  pudo copiar y los datos siguen visibles en pantalla para copiarlos a mano — la pantalla sigue
  funcionando con normalidad (spec 060, requisito `FR-008`, mismo mecanismo de aviso que ya usa el
  comensal al copiar sus datos de pago en el checkout).
- Una vez confirmado, el nombre del cliente, la dirección, el teléfono y el valor del domicilio de
  un pedido a domicilio no se pueden editar (spec 056, Assumptions).

## Diferenciador de mercado

En un punto de venta tradicional, los datos de un domicilio suelen anotarse a mano en un papel o
dictarse por teléfono al mensajero, con el riesgo real de transcribir mal un número de la
dirección o del celular. En SkeiloPOS, el cajero copia todos los datos de entrega con un solo
clic, en un texto ya formateado y listo para pegar en el chat del mensajero, sin volver a
escribirlos.

Además, el valor del domicilio queda integrado al total de la orden y de la factura desde el
primer momento, en vez de cobrarse aparte o llevarse en una cuenta separada como suele ocurrir en
un negocio donde el domicilio no está modelado como parte del pedido mismo.

---

> **Verificado contra**: specs 056-domicilio-orden-manual, 060-copiar-cuenta-descargar-qr,
> 094-detalle-orden-desglose-entrega — 2026-10-08.
