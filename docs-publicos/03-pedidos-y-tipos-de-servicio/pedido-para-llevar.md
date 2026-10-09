---
title: "Pedido para llevar"
description: "Cómo el Cajero/Staff registra un pedido para llevar sin asociarlo a ninguna mesa."
---

# Pedido para llevar

No todo cliente de una heladería o un local de granizados se sienta a consumir en el lugar: muchos
piden en el mostrador y se llevan su pedido. SkeiloPOS permite registrar ese tipo de pedido desde
la misma pantalla de creación manual que ya usa el Cajero/Staff para los pedidos en mesa, sin
obligar a elegir ninguna mesa ni a improvisar un registro distinto.

## Roles que pueden usar esta función

- **Cajero/Staff**: crea, arma y confirma el pedido para llevar desde la Terminal de Mesas.

## Flujo paso a paso

1. El Cajero/Staff abre la pantalla de creación de pedido manual, ya sea con el botón fijo "Crear
   nueva orden" del panel de mostrador de la Terminal de Mesas, o con la tecla F3.
2. En el panel de tipo de pedido, selecciona la opción "Para Llevar", junto a "En Mesa" y
   "Domicilio".
3. El sistema no exige seleccionar ninguna mesa para este tipo de pedido.
4. El campo "Cliente" aparece ya diligenciado con "Consumidor final", en modo de solo lectura, con
   la opción de editarlo si el cajero quiere escribir el nombre real de quien pide.
5. El cajero arma el pedido con el catálogo de productos, igual que para un pedido en mesa.
6. El cajero confirma y envía el pedido. Queda registrado sin mesa asociada, con el nombre de
   cliente que se veía en pantalla en ese momento (el valor por defecto, o el que el cajero haya
   escrito).
7. El pedido sigue el mismo flujo de cocina, cobro y facturación que cualquier otro pedido tomado
   directamente por el personal.

## Reglas de negocio y límites

- Si el cajero no edita el campo "Cliente", el pedido queda facturado a nombre de "Consumidor
  final" (spec 055, requisito `FR-010`).
- Todo pedido para llevar queda clasificado con el tipo de pedido "Para llevar" (`TAKEAWAY`) y el
  canal de origen "punto de venta" (`POS`), lo que permite filtrar reportes por este tipo de
  pedido más adelante (spec 055, `FR-003`, `FR-011`, `FR-015`).
- El sistema valida que la combinación de canal y tipo de pedido tenga sentido en la operación
  real del negocio — por ejemplo, impide registrar como "se consume en el establecimiento" un
  pedido que llegó por un canal que nunca corresponde a consumo en el local. Esta validación rige
  para todos los canales del sistema, aunque hoy el Cajero/Staff solo trabaja con el canal "punto
  de venta" (spec 055, `FR-006`).
- El canal y el tipo de pedido de una orden no se pueden modificar una vez creada (spec 055,
  Assumptions).
- El cajero llega al formulario de pedido manual con la mesa ya seleccionada si había una, o con
  la primera mesa libre disponible si no la había; si ninguna mesa libre existe, el botón fijo de
  "Crear nueva orden" queda deshabilitado en vez de llevar a un destino inválido — aunque, al
  tratarse de un pedido "Para Llevar", esa mesa preseleccionada no se usa ni se le exige al cajero
  mantenerla (spec 045, requisitos `FR-002` a `FR-004`, `FR-007`).

## Diferenciador de mercado

En un punto de venta tradicional, un pedido para llevar suele ser solo una anotación manual en el
ticket, o ni siquiera se distingue de un consumo en el local. En SkeiloPOS, cada pedido queda
clasificado con su propio tipo de pedido y su propio canal de origen desde el momento en que se
crea, lo que permite más adelante filtrar y contar cuántos pedidos fueron para llevar frente a los
de mesa o domicilio, sin tener que revisar ticket por ticket.

Además, el sistema valida automáticamente que la combinación de canal y tipo de pedido tenga
sentido en la operación real del negocio — algo que una caja registradora simple o un cuaderno de
pedidos de un POS tradicional no puede garantizar, porque ni siquiera modela esa relación.

---

> **Verificado contra**: specs 045-simplificacion-terminal-mesas, 055-canal-tipo-orden — 2026-10-08.
