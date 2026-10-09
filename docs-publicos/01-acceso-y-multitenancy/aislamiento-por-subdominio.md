---
title: "Aislamiento por subdominio"
description: "Cómo cada negocio tiene su propia dirección en SkeiloPOS y cómo se protege el acceso de administración de la plataforma."
---

# Aislamiento por subdominio

Cada heladería, granizados o negocio de gastronomía rápida que usa SkeiloPOS opera en su propia
dirección exclusiva dentro del dominio `skeilopos.com` —por ejemplo, `granizadosdelsol.skeilopos.com`—
y nunca comparte pantallas, sesiones ni datos con ningún otro negocio registrado en la plataforma.
Esta separación es la base de todo lo demás: antes de que alguien escriba una sola credencial, el
sistema ya sabe, solo por la dirección que se abrió, a cuál negocio pertenece la pantalla que va a
ver.

Por encima de los negocios existe una única dirección distinta, reservada para el equipo de
SkeiloPOS: `admin.skeilopos.com`, desde donde se administra la plataforma completa (planes,
negocios, catálogos globales). Esa dirección y un pequeño grupo de identificadores adicionales
quedan permanentemente protegidos para que ningún negocio pueda registrarse con ellos ni
confundirse con la administración de la plataforma.

## Roles que pueden usar esta función

- **Super Admin**: accede exclusivamente desde `admin.skeilopos.com`; nunca desde la dirección de
  un negocio.
- **Administrador de Tenant**: accede exclusivamente desde la dirección de su propio negocio.
- **Cajero/Staff**: accede exclusivamente desde la dirección del negocio donde trabaja.
- **Cliente QR**: llega a la dirección de un negocio al escanear el código QR de su mesa; el
  aislamiento por dirección aplica igual, aunque no inicia sesión con correo y contraseña.

## Flujo paso a paso

1. Al registrarse en SkeiloPOS, cada negocio recibe un identificador de subdominio propio (su
   "slug"), que a partir de ese momento forma su dirección exclusiva —por ejemplo,
   `granizadosdelsol.skeilopos.com`.
2. Cuando alguien abre esa dirección —un administrador, un cajero, o un cliente que escaneó el
   código QR de una mesa—, el sistema reconoce el identificador tal como aparece en la dirección y
   lo usa para decidir qué negocio corresponde a la pantalla, sin consultar al servidor y sin
   exponer ningún dato del negocio (nombre comercial, logotipo, plan) antes de que la persona
   inicie sesión.
3. Si la dirección abierta es la de administración de la plataforma (`admin.skeilopos.com`), el
   sistema muestra en su lugar la pantalla de administración global, reservada para el equipo de
   SkeiloPOS, y nunca busca ni acepta ahí una cuenta de negocio.
4. Si la dirección no corresponde a ningún negocio registrado, al dominio de administración, ni es
   el dominio raíz (`skeilopos.com`, que sirve el sitio público de SkeiloPOS), el sistema muestra
   el aviso "No encontramos este negocio" con un enlace al sitio principal, sin mostrar ningún
   formulario y sin hacer ninguna consulta al servidor.
5. Al dar de alta un negocio nuevo, si la persona que lo registra intenta usar como identificador
   una de las palabras reservadas de la plataforma, el sistema bloquea el registro e indica que es
   una palabra reservada, sin importar mayúsculas, minúsculas o espacios alrededor del texto
   escrito.
6. Una sesión abierta en la dirección de un negocio nunca da acceso a otro negocio ni a la
   administración global de la plataforma, y una sesión de administración global nunca da acceso a
   la pantalla ni a los datos de un negocio.

## Reglas de negocio y límites

- Las palabras reservadas que ningún negocio puede usar como identificador de subdominio son
  exactamente: `www`, `app`, `admin`, `assets`, `api` y `docs` (verificado en
  `specs/091-admin-subdominio-nombre-completo/spec.md`, FR-008/FR-009, y en el comportamiento real
  del sistema).
- El dominio raíz `skeilopos.com` no ofrece ningún inicio de sesión —ni de negocio ni de
  plataforma—; sirve la página pública de SkeiloPOS (verificado en
  `specs/091-admin-subdominio-nombre-completo/spec.md`, FR-006).
- El tipo de dirección (negocio, administración de la plataforma, o ninguna de las dos) se reconoce
  por completo sin consultar al servidor, por lo que la pantalla correspondiente aparece de
  inmediato, sin un estado de carga intermedio (verificado en
  `specs/095-rediseno-login-recuperacion/spec.md`, FR-007a/FR-007c).
- Un identificador con forma válida que no está en la lista de reservados, pero que tampoco
  corresponde a ningún negocio registrado, se trata hoy como un negocio válido: la pantalla de
  inicio de sesión se muestra con normalidad y solo al intentar entrar se informa "Credenciales
  inválidas", sin confirmar ni negar si ese negocio existe. Es una limitación conocida y aceptada
  del sistema (verificado en `specs/095-rediseno-login-recuperacion/spec.md`, D12/FR-009a).
- Una sesión de administración de la plataforma y una sesión de un negocio son completamente
  independientes entre sí: ninguna de las dos funciona fuera de su propio ámbito (verificado en
  `specs/091-admin-subdominio-nombre-completo/spec.md`, FR-007).

## Diferenciador de mercado

Muchos sistemas POS tradicionales para heladerías y negocios de comida rápida operan con una sola
base de datos compartida entre locales o franquicias, donde cualquier persona con acceso técnico
(o un simple cambio de usuario) puede terminar viendo pedidos, cifras o personal de otro local.
SkeiloPOS, en cambio, aísla cada negocio en su propia dirección exclusiva, de modo que ningún dato
de un negocio es accesible, ni siquiera por error de navegación, desde la dirección de otro.

Además, muchos POS de punto único mezclan en una sola pantalla de acceso tanto la operación del
negocio como la administración del proveedor del software —a veces detrás de un simple "modo
soporte" o un usuario técnico oculto—. SkeiloPOS separa físicamente la administración de la
plataforma, en `admin.skeilopos.com`, de la dirección de cada negocio, de modo que ni un error de
configuración ni un empleado del negocio pueden llegar accidentalmente a las herramientas de
administración global de SkeiloPOS.

---

> **Verificado contra**: `specs/091-admin-subdominio-nombre-completo/spec.md`,
> `specs/095-rediseno-login-recuperacion/spec.md` — 2026-10-08.
