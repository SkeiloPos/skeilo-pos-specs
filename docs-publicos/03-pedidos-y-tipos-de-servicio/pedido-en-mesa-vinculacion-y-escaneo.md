---
title: "Pedido en mesa: vinculación y escaneo"
description: "Cómo un comensal se vincula a su mesa escaneando el código QR y cómo el pedido llega en tiempo real al personal."
---

# Pedido en mesa: vinculación y escaneo

En una heladería o un local de granizados con mesas físicas, cada mesa tiene su propio código QR
impreso. Cuando un comensal lo escanea, SkeiloPOS lo vincula automáticamente a esa mesa —sin que
el mesero tenga que acercarse a tomar el pedido en papel ni en una tablet propia— y deja que
arme y envíe su pedido desde su propio teléfono. El pedido nuevo llega de inmediato al personal,
sin importar en qué pantalla del sistema esté trabajando en ese momento.

## Roles que pueden usar esta función

- **Cliente QR**: escanea el código de la mesa, se identifica con un nombre, navega el menú y
  envía su pedido desde su teléfono.
- **Cajero/Staff**: recibe la notificación del pedido nuevo en tiempo real, sin importar la
  sección del sistema en la que esté trabajando, y lo atiende desde la Terminal de Mesas.

## Flujo paso a paso

1. El negocio coloca el código QR único de la mesa, impreso físicamente sobre ella.
2. El comensal escanea el código con la cámara de su teléfono y abre el menú de la mesa.
3. Si es el primer comensal en escanear esa mesa, el sistema abre una sesión nueva para ella y la
   marca como "ocupada" de inmediato en el panel del Cajero/Staff.
4. Si ya hay otros comensales con sesión activa en esa misma mesa, el nuevo comensal se une a esa
   sesión ya existente — nunca se crea una segunda sesión para la misma mesa.
5. El comensal escribe su nombre para identificarse ante cocina y caja. Si ese nombre ya lo está
   usando otro comensal de la misma mesa, el sistema le agrega automáticamente un número entre
   paréntesis (por ejemplo, "Ana (2)") solo para distinguirlo en pantalla, sin alterar el nombre
   que escribió.
6. El comensal navega el menú: ve el precio ya con el descuento de cualquier promoción vigente
   aplicada, y ve qué productos u opciones (sabores, toppings) están disponibles en ese momento.
7. El comensal arma su carrito agregando productos, cantidades y opciones, y puede editarlo
   libremente mientras no lo haya enviado.
8. El comensal envía su pedido. Dependiendo del método de pago elegido, el pedido puede quedar a
   la espera de que el cajero confirme el pago antes de aparecer para cocina (ver
   [Pagos por confirmar](../04-pago-y-checkout/pagos-por-confirmar.md)).
9. En cuanto el pedido queda registrado, llega de inmediato al Cajero/Staff, con aviso visual y
   sonoro en la aplicación, sin importar en qué sección del sistema esté trabajando en ese
   momento (Ventas, Inventario, Reportes, etc.).
10. Si el Cajero/Staff tiene la pestaña del sistema sin foco o el navegador minimizado, también
    recibe una notificación push del navegador equivalente, para no perderse el pedido.
11. El comensal, por su parte, ve en tiempo real el estado de su propio pedido y la confirmación
    de su pago, sin tener que recargar la página ni preguntar en caja.

## Reglas de negocio y límites

- El código QR de una mesa no tiene fecha de vencimiento: sigue funcionando indefinidamente. La
  única forma de invalidarlo es rotar la clave de seguridad de todo el sistema, lo que invalidaría
  los códigos de todas las mesas del negocio a la vez, no solo el de una mesa en particular
  (verificado en spec 007, regla `RN-CART-24`).
- Un comensal que escanea el QR de una mesa con una sesión ya activa se une a esa misma sesión;
  nunca se abre una segunda sesión para la misma mesa (spec 007, `RN-CART-01`).
- La mesa pasa a estado "ocupada" apenas el primer comensal escanea el código; los comensales que
  se unen después a la misma sesión no repiten ese cambio de estado (spec 007, `RN-CART-03`).
- La sesión de un comensal tiene una ventana de 240 minutos (4 horas) de inactividad: si no realiza
  ninguna acción real (pedir, cancelar, editar) dentro de ese tiempo, la siguiente acción con su
  sesión pide volver a escanear el código. Esa ventana se renueva con cada acción real, pero el
  acceso del comensal tiene además un tope absoluto de 1.440 minutos (24 horas) desde que abrió su
  sesión, sin importar cuánta actividad haya tenido entre medio (spec 007, `RN-CART-17`,
  `RN-CART-19`, `RN-CART-20`).
- Un pedido nuevo generado desde el menú QR de una mesa llega al Cajero/Staff conectado en
  condiciones normales de red en menos de 5 segundos, con indicador visual y aviso sonoro en la
  aplicación; si su pestaña no tiene el foco, también llega como notificación push del navegador
  (spec 077, requisitos `FR-001` a `FR-004` y criterio de éxito `SC-002`/`SC-003`).
- El comensal anónimo recibe en tiempo real el estado de su propio pedido y la confirmación de su
  pago, limitado estrictamente a su propia sesión — nunca ve actualizaciones de pedidos ajenos de
  la misma mesa (spec 077, `FR-005`).
- Al momento de enviar el pedido, el sistema hace una verificación preventiva de disponibilidad,
  pero no reserva ni bloquea inventario todavía; ese descuento real solo ocurre cuando cocina
  confirma el pedido, por lo que en horas de mucha demanda un producto visto como disponible puede
  terminar rechazándose al confirmarlo (spec 007, `RN-CART-09`).

## Diferenciador de mercado

En un punto de venta tradicional de heladería, el mesero debe acercarse físicamente a cada mesa
para tomar el pedido en papel o en una tablet propia, y varios comensales de la misma mesa
terminan mezclados en una sola cuenta difícil de separar después. En SkeiloPOS, cada comensal pide
desde su propio teléfono apenas se sienta, sin que el personal tenga que intervenir, y varias
personas de la misma mesa pueden pedir de forma independiente sin fragmentar la cuenta en
registros sueltos.

Además, la notificación de un pedido nuevo llega al Cajero/Staff sin importar en qué pantalla del
sistema esté trabajando, y hasta como notificación push si no tiene la pestaña abierta en ese
momento. En un POS tradicional, un pedido nuevo solo se nota si alguien está mirando activamente la
pantalla de mesas, o si el mesero avisa en persona — con el riesgo real de que un pedido pase
inadvertido durante varios minutos en una hora de mucho movimiento.

---

> **Verificado contra**: specs 007-menu-carrito-qr, 009-cocina-consolidacion-y-mesas-fisicas,
> 077-notificaciones-tiempo-real — 2026-10-08.
