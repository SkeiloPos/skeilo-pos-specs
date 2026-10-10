---
title: "Recuperación de contraseña"
description: "El procedimiento para recuperar el acceso cuando se olvida la contraseña, con el tiempo de vigencia del enlace y el límite de intentos."
---

# Recuperación de contraseña

Cuando una persona olvida su contraseña, SkeiloPOS le permite recuperar el acceso a su cuenta por
sí misma, sin depender de que un administrador o el soporte de SkeiloPOS intervenga manualmente. El
procedimiento pide únicamente el correo de la cuenta, envía un enlace de un solo uso al correo
registrado, y deja que la persona elija una contraseña nueva —todo desde la misma pantalla de
inicio de sesión de su negocio.

## Roles que pueden usar esta función

- **Administrador de Tenant**: puede recuperar su propia contraseña desde la dirección de inicio
  de sesión de su propio negocio.
- **Cajero/Staff**: puede recuperar su propia contraseña desde la dirección de inicio de sesión del
  negocio donde trabaja.

> **Nota**: la recuperación de contraseña de una cuenta de Super Admin (plataforma) no está
> disponible por este procedimiento de autoservicio; se gestiona por un canal interno de
> SkeiloPOS, distinto del descrito aquí.

## Flujo paso a paso

1. Desde la pantalla de inicio de sesión de su negocio, la persona pulsa el enlace "¿Olvidaste tu
   contraseña?".
2. Llega a una pantalla con el título "Restablece tu contraseña.", un único campo para su correo
   electrónico y el botón "Enviar enlace".
3. Escribe su correo y pulsa "Enviar enlace". Exista o no una cuenta con ese correo en ese negocio,
   ve siempre el mismo mensaje: que si la cuenta existe se envió un enlace al correo registrado,
   que revise su bandeja de entrada y la carpeta de spam, y que el enlace caduca en 30 minutos. El
   sistema nunca confirma ni niega si ese correo tiene cuenta en el negocio.
4. Si la cuenta existe y está activa, recibe en pocos minutos un correo con un botón para
   restablecer la contraseña y el enlace completo en texto, por si su cliente de correo no muestra
   el botón.
5. Tras enviar la solicitud, el botón para reenviar el enlace queda deshabilitado durante 60
   segundos, mostrando una cuenta regresiva, como protección adicional para no agotar sus intentos
   disponibles por pulsaciones repetidas.
6. Abre el enlace recibido antes de que venza su vigencia. Si todavía es válido, ve una pantalla con
   los campos "Nueva contraseña" y "Confirmar contraseña", junto con la lista de requisitos que su
   contraseña nueva debe cumplir.
7. Escribe la contraseña nueva dos veces de forma idéntica y pulsa "Guardar contraseña". Si cumple
   todos los requisitos y coincide con la confirmación, el cambio se aplica, todas sus sesiones
   activas anteriores se cierran, y es enviado al inicio de sesión con el mensaje "Contraseña
   actualizada", donde ya puede entrar con la contraseña nueva.
8. Si el enlace ya venció, ya fue usado, o quedó invalidado porque pidió uno más reciente, la
   pantalla muestra "Este enlace ya no es válido" con un botón para solicitar uno nuevo, sin
   mostrar los campos de contraseña.

## Reglas de negocio y límites

- La contraseña nueva debe tener entre 8 y 12 caracteres, sin exigir una combinación obligatoria de
  mayúsculas, números ni símbolos (verificado en `specs/031-recuperacion-cambio-contrasena/spec.md`,
  FR-019, y en la validación real vigente del sistema: longitud mínima 8, máxima 12 caracteres).
- El enlace de recuperación es de un solo uso y caduca exactamente a los 30 minutos de haberse
  emitido, no desde que se abre el correo (verificado en
  `specs/031-recuperacion-cambio-contrasena/spec.md`, FR-004/FR-011, y en la configuración real
  vigente del sistema: 30 minutos).
- Pedir un enlace nuevo invalida de inmediato cualquier enlace anterior de esa misma cuenta que
  todavía estuviera vigente; solo el último enlace recibido funciona (verificado en
  `specs/031-recuperacion-cambio-contrasena/spec.md`, FR-005).
- El sistema permite, como máximo, 3 solicitudes de enlace por cuenta (correo) dentro de cada
  negocio, en una ventana de 900 segundos (15 minutos); al superar ese límite, la solicitud se
  bloquea con el mensaje "Has pedido demasiados enlaces. Vuelve a intentarlo en unos minutos.", sin
  enviar correo (verificado en `specs/031-recuperacion-cambio-contrasena/spec.md`, FR-010, y en la
  configuración real vigente del sistema: 3 solicitudes por 900 segundos).
- La contraseña nueva no puede ser igual a la contraseña actual de la cuenta (verificado en
  `specs/031-recuperacion-cambio-contrasena/spec.md`, FR-021).
- Al completar el cambio con éxito, se cierran todas las sesiones activas anteriores de la cuenta,
  en cualquier dispositivo donde estuvieran abiertas (verificado en
  `specs/031-recuperacion-cambio-contrasena/spec.md`, FR-009).
- La respuesta de la solicitud de enlace es idéntica exista o no una cuenta con ese correo en ese
  negocio, para no revelar qué correos están registrados (verificado en
  `specs/031-recuperacion-cambio-contrasena/spec.md`, FR-003, y
  `specs/095-rediseno-login-recuperacion/spec.md`).
- Un enlace de recuperación se resuelve solo por su propio código, sin atarse al negocio desde el
  que se abre: si se abre desde la dirección de otro negocio, o desde la de administración de la
  plataforma, sigue siendo válido y permite fijar la contraseña de la cuenta para la que se emitió
  (nunca la de otra cuenta). Es una limitación conocida y aceptada del sistema (verificado en
  `specs/095-rediseno-login-recuperacion/spec.md`, D13/FR-037).

## Diferenciador de mercado

Muchos sistemas POS tradicionales de heladería y comida rápida no ofrecen una recuperación propia:
cuando alguien olvida su contraseña, depende de que un técnico de soporte la restablezca
manualmente, a veces compartiendo una clave temporal por teléfono o WhatsApp —un procedimiento
lento y con el riesgo de que esa clave quede en manos de un tercero—. En SkeiloPOS, cualquier
cajero o administrador recupera su propio acceso en minutos, por correo, sin que nadie más conozca
ni manipule su contraseña.

Además, a diferencia de sistemas que confirman por el mensaje en pantalla si un correo está o no
registrado —lo que permite a cualquiera "listar" las cuentas reales de un negocio con solo probar
direcciones—, SkeiloPOS muestra siempre la misma respuesta exista o no la cuenta detrás del correo
ingresado, protegiendo la lista de personal del negocio frente a terceros.

---

> **Verificado contra**: `specs/031-recuperacion-cambio-contrasena/spec.md`,
> `specs/095-rediseno-login-recuperacion/spec.md`, `specs/096-correos-transaccionales/spec.md` —
> 2026-10-08.
