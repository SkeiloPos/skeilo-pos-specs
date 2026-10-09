---
title: "Inicio de sesión"
description: "Cómo cada persona entra a SkeiloPOS con su correo y contraseña, y qué pasa cuando las credenciales no son correctas."
---

# Inicio de sesión

El inicio de sesión es la puerta de entrada diaria a SkeiloPOS: desde ahí, cada administrador o
cajero de un negocio, y cada Super Admin de la plataforma, entra con su propio correo y contraseña
a la pantalla que le corresponde según su rol. La pantalla muestra siempre la marca de SkeiloPOS
junto con una etiqueta que indica claramente en qué contexto se está entrando —el identificador del
negocio, o "Administración de la plataforma"—, para que la persona reconozca de inmediato que está
en la puerta correcta.

## Roles que pueden usar esta función

- **Administrador de Tenant**: inicia sesión exclusivamente desde la dirección de su propio
  negocio y llega al panel de administración de ese negocio.
- **Cajero/Staff**: inicia sesión exclusivamente desde la dirección del negocio donde trabaja y
  llega a la pantalla de operación que le corresponde.
- **Super Admin**: inicia sesión exclusivamente desde `admin.skeilopos.com` y llega al panel de
  administración global de la plataforma; ninguna cuenta de negocio puede entrar por esa dirección,
  y el Super Admin no puede entrar por la dirección de ningún negocio.

## Flujo paso a paso

1. La persona abre la dirección de inicio de sesión que le corresponde (la de su negocio, o la de
   administración de la plataforma si es Super Admin) y ve de inmediato la marca de SkeiloPOS, la
   etiqueta de contexto, el campo "Correo electrónico", el campo de contraseña, el control
   "Mantener sesión iniciada", el enlace "¿Olvidaste tu contraseña?" y el botón "Iniciar sesión".
2. Escribe su correo electrónico y su contraseña; puede alternar la visibilidad de la contraseña
   con el control correspondiente, y su gestor de contraseñas puede ofrecerle autocompletar ambos
   campos.
3. Pulsa "Iniciar sesión". Mientras el sistema verifica las credenciales, el botón queda
   deshabilitado y muestra un indicador de progreso, de modo que pulsarlo varias veces no genera
   más de un intento.
4. Si el correo y la contraseña corresponden a una cuenta activa de ese mismo negocio (o de la
   plataforma, según la dirección usada), el sistema lo deja entrar y lo lleva a la pantalla de
   destino que intentaba abrir, o a la pantalla inicial de su rol si no venía de ninguna.
5. Si las credenciales no corresponden a ninguna cuenta activa de ese ámbito —ya sea porque el
   correo no existe, la contraseña es incorrecta o la cuenta está desactivada—, el sistema muestra
   siempre el mismo mensaje "Credenciales inválidas", vacía el campo de contraseña y le da el foco,
   conservando lo que escribió en el campo de correo.
6. Si deja algún campo obligatorio vacío e intenta enviar el formulario, el sistema señala el campo
   faltante y no llega a intentar la autenticación.
7. Si no recuerda su contraseña, puede pulsar "¿Olvidaste tu contraseña?" para pasar al
   procedimiento de recuperación (ver [Recuperación de contraseña](recuperacion-de-contrasena.md)
   en este mismo módulo).

## Reglas de negocio y límites

- La identificación de la cuenta es exclusivamente el correo electrónico; el sistema no ofrece ni
  reconoce un nombre de usuario alternativo (verificado en
  `specs/095-rediseno-login-recuperacion/spec.md`, FR-011a).
- Un intento fallido siempre muestra el mismo mensaje "Credenciales inválidas", sin distinguir si
  el correo no existe, la contraseña es incorrecta o la cuenta está desactivada, para no revelar
  esa información a quien intenta entrar (verificado en
  `specs/095-rediseno-login-recuperacion/spec.md`, FR-012).
- El control "Mantener sesión iniciada" está presente en la pantalla, pero hoy no tiene ningún
  efecto real: una sesión iniciada con ese control marcado dura exactamente lo mismo que una
  iniciada sin marcarlo, y el sistema nunca guarda la contraseña en el navegador en ninguno de los
  dos casos (verificado en `specs/095-rediseno-login-recuperacion/spec.md`, FR-019a a FR-019e).
- Una sesión iniciada da acceso por 1 día sin volver a pedir credenciales, y el sistema puede
  renovarla automáticamente, mientras la persona sigue activa, hasta por 7 días adicionales
  (verificado en el comportamiento vigente de SkeiloPOS y descrito en
  `specs/095-rediseno-login-recuperacion/spec.md`).
- Un Super Admin solo puede iniciar sesión desde `admin.skeilopos.com`; una cuenta de negocio solo
  puede hacerlo desde la dirección de su propio negocio. Cualquier combinación cruzada —una cuenta
  de negocio intentando entrar por la administración de la plataforma, o un Super Admin intentando
  entrar por la dirección de un negocio— se rechaza con el mismo mensaje genérico de credenciales
  inválidas (verificado en `specs/091-admin-subdominio-nombre-completo/spec.md`, FR-002 a FR-005).

## Diferenciador de mercado

Muchos sistemas POS de mostrador tradicionales identifican a cada empleado con un PIN numérico
corto, compartido o visible en el propio mostrador, que cualquier persona puede ver por encima del
hombro o adivinar en pocos intentos. SkeiloPOS exige correo electrónico y contraseña propios para
cada persona, de modo que cada acceso queda atado a una identidad individual y no a un código corto
compartido por todo el equipo.

Muchos de esos mismos sistemas, además, muestran mensajes distintos para "ese usuario no existe" y
para "la contraseña es incorrecta", lo que permite a cualquiera con acceso a la pantalla ir probando
correos para averiguar cuáles están registrados. SkeiloPOS muestra siempre el mismo mensaje
genérico ante cualquier intento fallido, sin revelar si la cuenta existe.

---

> **Verificado contra**: `specs/095-rediseno-login-recuperacion/spec.md` — 2026-10-08.
