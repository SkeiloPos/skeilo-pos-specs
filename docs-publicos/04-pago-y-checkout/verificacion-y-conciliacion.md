---
title: "Verificación y conciliación de caja"
description: "Cómo se calcula el efectivo esperado durante el turno y cómo se concilia al cerrarlo (arqueo de caja)."
---

# Verificación y conciliación de caja

Al final de cada turno, un negocio necesita saber si el efectivo que hay en el cajón corresponde
exactamente a lo que debería haber según las ventas y los movimientos manuales del día. SkeiloPOS
calcula ese efectivo esperado en tiempo real durante todo el turno y, al cerrarlo, deja un reporte
fijo que sirve como registro confiable para la gestoría o el dueño del negocio.

## Roles que pueden usar esta función

- **Cajero/Staff**: abre y cierra turnos de caja, registra movimientos manuales y hace arqueos
  parciales o el arqueo de cierre.
- **Administrador de Tenant**: consulta el historial de turnos cerrados para auditoría, con la
  certeza de que los números de un turno ya cerrado no cambian con el tiempo.

## Flujo paso a paso

1. El Cajero/Staff abre un turno de caja al empezar su jornada, declarando el fondo inicial en
   efectivo. El sistema no permite abrir un segundo turno en la misma caja registradora si ya hay
   uno abierto.
2. Durante el turno, el sistema calcula en tiempo real cuánto efectivo debería haber en el cajón:
   suma el fondo inicial, el efectivo de las ventas ya pagadas (sin contar las anuladas, y ya
   restando el cambio entregado) y los movimientos manuales de ingreso, y resta los egresos y
   retiros manuales.
3. El Cajero/Staff puede registrar en cualquier momento un movimiento manual de efectivo —ingreso,
   egreso o retiro—, por ejemplo para traer cambio o retirar dinero por seguridad a mitad de
   jornada. El monto siempre se registra en positivo; el tipo de movimiento es lo que determina si
   suma o resta.
4. En cualquier momento del turno, el Cajero/Staff puede hacer un arqueo parcial: contar el
   efectivo físico del cajón sin cerrar el turno, para verificar que todo cuadra hasta ese
   momento. Si hay una diferencia distinta de cero entre lo contado y lo esperado, el sistema
   exige escribir una observación explicando esa diferencia antes de aceptar el arqueo.
5. Al cerrar el turno, el Cajero/Staff reporta el conteo físico final del cajón, ya sea billete por
   billete (denominación por denominación) o como un monto único.
6. Si el monto contado no coincide exactamente con el esperado, el sistema vuelve a exigir una
   observación obligatoria antes de permitir el cierre; si coincide, la observación es opcional.
7. Al confirmar el cierre, el sistema calcula y deja fijo para siempre el monto esperado y la
   diferencia de ese turno. Si más adelante se anula una venta que participó en ese cálculo, el
   efecto de esa anulación se refleja aparte, en una vista de ajustes vinculada al turno original
   — nunca sobrescribiendo el cierre ya hecho.
8. El Cajero/Staff o el Administrador de Tenant pueden imprimir o exportar el reporte del cierre,
   tanto en el momento de cerrar como después desde el historial de turnos: un documento con los
   totales por método de pago, los movimientos y el resultado del arqueo, legible en pantalla, en
   papel o en PDF.
9. El Administrador de Tenant puede consultar el historial de turnos cerrados en cualquier momento
   para auditoría o para la gestoría, con la seguridad de que los números de un turno ya cerrado
   no van a cambiar.

## Reglas de negocio y límites

- Una caja registradora solo puede tener un turno abierto a la vez; un segundo intento de
  apertura se rechaza (spec 006, regla `RN-CASH-01`).
- El efectivo esperado se calcula siempre a partir de las ventas y los pagos reales ya
  registrados, nunca de un registro aparte, y excluye las ventas anuladas (spec 006,
  `RN-CASH-02`).
- Solo los pagos en efectivo afectan el efectivo esperado del cajón; los pagos con tarjeta o
  transferencia se reportan en el desglose, pero no suman ni restan ese monto (spec 006,
  `RN-CASH-03`).
- El efectivo esperado por ventas se calcula neto del cambio entregado al cliente (spec 006,
  `RN-CASH-04`).
- La fórmula completa del efectivo esperado al cierre es: fondo inicial + ventas en efectivo
  (netas de cambio) + ingresos manuales − egresos manuales − retiros manuales (spec 006,
  `RN-CASH-05`).
- El desglose de ventas por método de pago muestra todos los métodos de pago activos del negocio,
  incluso los que no tuvieron ninguna venta ese turno (en cero); el efectivo aparece siempre
  primero, y el resto en orden alfabético (spec 006, `RN-CASH-07`, `RN-CASH-08`).
- Un turno ya cerrado no puede volver a cerrarse ni modificarse (spec 006, `RN-CASH-11`).
- Los movimientos manuales de efectivo solo pueden registrarse mientras el turno está abierto; el
  monto siempre debe ser positivo, y es el tipo de movimiento el que determina si suma o resta
  (spec 006, `RN-CASH-12`, `RN-CASH-14`).
- Un arqueo parcial con diferencia distinta de cero exige una observación obligatoria, exactamente
  igual que el cierre real (spec 006, `RN-CASH-13`).
- El monto esperado y la diferencia de un turno ya cerrado quedan fijos para siempre: si una venta
  de ese turno se anula después, el efecto se ve en una vista de ajustes separada, vinculada al
  turno original, nunca modificando el cierre ya hecho (spec 006, `RN-CASH-17`).
- El reporte de cierre de caja se imprime completo y legible —texto oscuro sobre fondo claro—, sin
  hojas en blanco, tanto recién cerrado el turno como al reabrirlo después desde el historial
  (spec 090, requisitos `FR-001` a `FR-005`).

## Diferenciador de mercado

En un punto de venta tradicional, el arqueo de caja suele hacerse en una hoja de cálculo o un
cuaderno aparte que el cajero llena a mano al final del día, sumando ventas y movimientos por su
cuenta. En SkeiloPOS, el sistema calcula el efectivo esperado en tiempo real durante todo el
turno, cruzando automáticamente ventas, pagos y movimientos manuales, sin que nadie tenga que
sumarlo a mano.

Además, un turno cerrado queda fijo como un hecho contable inmutable para siempre, incluso si
después se anula una venta que participó en el cálculo original. Un POS tradicional, o una
planilla manual, normalmente recalcularía ese cierre de forma retroactiva, lo que puede hacer que
una auditoría posterior encuentre un número de caja distinto del que el cajero realmente vio y
aceptó el día del cierre.

---

> **Verificado contra**: specs 006-turnos-caja-arqueo, 090-fix-cash-report-print-blank —
> 2026-10-08.
