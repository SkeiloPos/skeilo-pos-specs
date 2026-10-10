---
title: "Métodos de pago"
description: "Cómo funcionan el efectivo y la transferencia, y el catálogo de métodos de pago que cada negocio activa y configura."
---

# Métodos de pago

SkeiloPOS no limita a un negocio a una lista fija de integraciones técnicas con bancos o
billeteras digitales. En su lugar, mantiene un catálogo de métodos de pago administrado de forma
centralizada, y cada heladería o local de granizados activa, dentro de ese catálogo, los métodos
que realmente usa (efectivo y cualquier método de transferencia: Nequi, Bancolombia, Daviplata,
Tumypay, o cualquier otro que el negocio reciba), completando sus propios datos — número de
cuenta, celular o código QR — sin depender de que SkeiloPOS integre cada pasarela una por una.

Si un negocio cambia de billetera digital o empieza a aceptar una nueva, no espera un desarrollo
a la medida: solo da de alta ese método con sus propios datos.

## Roles que pueden usar esta función

- **Cliente QR**: elige con qué método pagar, ve los datos necesarios para transferir (o paga en
  efectivo) y sube el comprobante cuando corresponde.
- **Cajero/Staff**: en la pantalla de cobro ve únicamente el nombre del método elegido (nunca los
  datos de cuenta, celular o QR, que son de uso administrativo), registra el monto recibido en
  efectivo y participa en la verificación de cualquier transferencia.

## Flujo paso a paso

1. El Cliente QR llega al paso de pago de su pedido y ve únicamente los métodos de pago que su
   negocio tiene activos y completamente configurados en ese momento — nunca uno que esté
   desactivado.
2. Si elige "Efectivo", el pedido queda registrado con el pago pendiente de que el Cajero/Staff lo
   confirme en caja; no se le pide ningún dato adicional.
3. Si elige un método de transferencia (por ejemplo Nequi, Bancolombia, o cualquier otro que el
   negocio tenga activo, como Tumypay), el sistema le muestra los datos de pago configurados para
   ese método específico: número de cuenta, celular y/o código QR, según lo que ese método tenga
   definido.
4. Junto a cualquier dato de texto (como el número de cuenta o celular), el Cliente QR ve un ícono
   de copiar que lo lleva al portapapeles con un solo toque, y junto al código QR, una opción para
   descargarlo como imagen a su dispositivo — cada acción confirma su éxito con un aviso breve que
   desaparece solo.
5. El Cliente QR transfiere desde su banco o billetera y vuelve a la aplicación para subir el
   comprobante de su transferencia (un único archivo).
6. El pedido queda registrado para el Cajero/Staff solo una vez el pago quedó resuelto: se confirmó
   la elección de efectivo, o se subió el comprobante de la transferencia con éxito.
7. El Cajero/Staff revisa el comprobante o confirma el efectivo recibido desde el panel
   "Pagos por confirmar" (ver [Pagos por confirmar](pagos-por-confirmar.md) para el detalle
   completo de esa revisión).
8. Al confirmar un pago en efectivo, el Cajero/Staff registra el monto recibido y el sistema
   calcula el cambio automáticamente, restando el total del pedido al monto recibido.
9. Solo cuando el pago queda confirmado (efectivo registrado, o comprobante aprobado) el pedido
   puede avanzar a cocina; mientras esté pendiente o haya sido rechazado, no avanza.

## Reglas de negocio y límites

- El catálogo de métodos de pago lo administra de forma centralizada SkeiloPOS; cada negocio solo
  activa los métodos de ese catálogo y completa sus propios datos de integración — no puede crear
  un método por fuera de ese catálogo (spec 032, requisitos `FR-001`, `FR-007`, `FR-011`).
- Métodos como Nequi, Bancolombia, Daviplata o Tumypay son ejemplos de métodos de transferencia que
  un negocio puede dar de alta en ese catálogo; ninguno de ellos tiene hoy una integración técnica
  propia (API o conciliación automática con el banco) — todos se verifican de la misma manera
  manual: el cliente sube un comprobante y el Cajero/Staff lo aprueba o rechaza (spec 032, sección
  Out of Scope; spec 024, requisito `FR-013`).
- Un método activado con campos de integración incompletos (por ejemplo, Nequi sin el número de
  celular diligenciado) no aparece como opción en la pantalla de cobro hasta que el negocio lo
  complete (spec 032, requisitos `FR-009`, `FR-012`).
- El Cajero/Staff solo ve el nombre del método de pago en la pantalla de cobro; los datos de
  integración configurados (cuenta, celular, QR) son de uso administrativo y no se le muestran
  (spec 032, requisito `FR-012a`).
- Un negocio siempre debe tener al menos un método de pago activo; el sistema no permite
  desactivar el último que queda (spec 024, requisito `FR-003`).
- El monto recibido en efectivo no puede ser menor al total del pedido; el sistema no permite
  confirmar el pago hasta que sea igual o mayor (spec 024, requisito `FR-010a`).
- El cambio (vuelto) solo se calcula sobre pagos en efectivo (spec 024, requisito `FR-010`).
- Mientras un intento de pago siga pendiente de revisión, el comensal no puede iniciar otro
  (cambiar de método o subir otro comprobante); solo puede hacerlo una vez el cajero rechace
  explícitamente el anterior (spec 024, requisito `FR-015a`).
- Si el Cajero/Staff rechaza un comprobante ya subido, el pedido no se cancela: el comensal puede
  volver a intentar con un comprobante distinto, sin perder los productos que ya había elegido
  (spec 024, requisito `FR-015`).
- El valor copiado al portapapeles coincide exactamente con el valor mostrado en pantalla, y la
  imagen descargada del QR es la misma que se muestra, sin alterarla (spec 060, requisitos
  `FR-003`, Assumptions).

## Diferenciador de mercado

En un punto de venta tradicional, agregar una nueva billetera digital o cambiar de cuenta bancaria
suele requerir soporte técnico o una actualización del sistema que integre esa opción
específica. En SkeiloPOS, cualquier negocio da de alta un método de transferencia nuevo —sea
Nequi, Bancolombia, Daviplata, Tumypay o cualquier otro que empiece a usar— completando sus propios
datos en un catálogo ya existente, sin depender de que exista una integración técnica particular
para ese método.

Además, el comensal copia el número de cuenta y descarga el código QR con un solo toque, en vez de
la práctica habitual en un POS tradicional de tomar una captura de pantalla o transcribir el
número a mano al abrir la aplicación de su banco — lo que reduce el riesgo de transferir a un
número mal copiado.

---

> **Verificado contra**: specs 032-catalogo-metodos-pago, 024-pagos-ordenes-mesa,
> 060-copiar-cuenta-descargar-qr — 2026-10-08.
