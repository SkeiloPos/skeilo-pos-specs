---
title: "Catálogos globales y subdominios reservados"
description: "Cómo el Super Admin administra el catálogo central de métodos de pago y protege los nombres de subdominio reservados para la propia plataforma."
---

# Catálogos globales y subdominios reservados

Algunos datos y nombres no le pertenecen a ningún negocio individual, sino a la plataforma
SkeiloPOS como un todo, y deben administrarse en un único lugar para que todos los negocios los
usen de forma consistente. Esta función cubre dos piezas de esa administración centralizada: el
catálogo de métodos de pago (qué tipos de método existen y qué datos pide cada uno, para que
cualquier negocio los active sin inventar su propia integración desde cero) y la lista de nombres
de subdominio reservados para uso interno de la plataforma (para que ningún negocio, al
registrarse, pueda tomar accidental o intencionalmente un nombre que la propia infraestructura de
SkeiloPOS ya necesita para sí misma).

## Roles que pueden usar esta función

- **Super Admin**: es el único rol que puede administrar el catálogo de métodos de pago (crear,
  editar, activar o desactivar un método a nivel de toda la plataforma) y la lista de nombres de
  subdominio reservados. Esta administración vive exclusivamente en el panel administrativo de la
  plataforma, separado de cualquier negocio.

Ningún otro rol —ni Administrador de Tenant, ni Cajero/Staff, ni Cliente QR— tiene acceso a esta
administración. Un Administrador de Tenant sí puede, desde el panel de su propio negocio, ver el
catálogo de métodos de pago ya activos en la plataforma y activar los que use (esa activación es
una función distinta, documentada en el módulo de Pago y Checkout); lo que no puede hacer, bajo
ninguna circunstancia, es crear un método nuevo fuera del catálogo, editar el catálogo central, ni
administrar la lista de subdominios reservados. Si alguien intenta llegar a esta administración
sin la cuenta de Super Admin —por ejemplo, entrando desde el subdominio de un negocio normal, o
con una cuenta de negocio válida pero sin ese rol de plataforma—, el sistema rechaza el intento
con el mismo tipo de mensaje genérico que usa para cualquier acceso no autorizado, sin indicar si
el dato solicitado existe o no. Esta función simplemente no es accesible desde un negocio normal,
ni por la pantalla ni enviando una solicitud directa.

## Flujo paso a paso

1. El Super Admin inicia sesión en el panel administrativo de la plataforma y abre la sección del
   catálogo de métodos de pago.
2. Para dar de alta un método nuevo (por ejemplo, una billetera digital adicional), el Super Admin
   indica su nombre comercial y define qué campos de integración necesitará cada negocio para
   activarlo —por ejemplo, un número de celular, un número de cuenta, o una imagen de código
   QR—, marcando cuáles de esos campos son obligatorios, cuáles opcionales, y el formato esperado
   de cada uno (por ejemplo, que un número de celular deba tener una cantidad exacta de dígitos).
3. Al guardar, el método queda registrado en el catálogo único de la plataforma con estado activo,
   disponible de inmediato para que cualquier negocio lo active desde su propio panel.
4. El Super Admin puede editar en cualquier momento el nombre o los campos de integración de un
   método ya existente; el cambio rige para las activaciones futuras, sin invalidar las
   configuraciones que algún negocio ya hubiera completado antes del cambio.
5. El Super Admin puede desactivar un método a nivel de toda la plataforma. Desde ese momento,
   ningún negocio nuevo puede activarlo, y los negocios que ya lo tenían activo dejan de verlo
   disponible para cobros nuevos, sin que esto afecte de ninguna forma las ventas que ya se
   registraron con ese método en el pasado.
6. De forma independiente, el Super Admin administra la lista cerrada de nombres de subdominio
   reservados para uso interno de la plataforma. Cuando alguien intenta registrar un negocio nuevo
   usando uno de esos nombres como su propio subdominio, el sistema rechaza la operación de
   inmediato, indicando que ese nombre está reservado, y no llega a crear el negocio.
7. Ese bloqueo aplica sin importar si el nombre se escribe en mayúsculas, minúsculas o con espacios
   de más alrededor, y aplica igual si el intento llega desde el formulario de alta en pantalla o
   desde una solicitud enviada directamente al sistema, sin pasar por la pantalla.
8. El propio panel administrativo de la plataforma vive en un subdominio dedicado, completamente
   aislado del de cualquier negocio: una cuenta de negocio no puede iniciar sesión ahí, y la
   cuenta de Super Admin no puede iniciar sesión en el subdominio de ningún negocio existente ni
   en ninguna dirección que la plataforma no reconozca como propia.

## Reglas de negocio y límites

- Cada método del catálogo define, de forma independiente, qué campos de integración necesita un
  negocio para activarlo, cuáles son obligatorios y cuáles opcionales, y el formato esperado de
  cada uno (por ejemplo, numérico con una longitud exacta); un método sin requisitos adicionales
  (como el pago en efectivo) puede definirse sin ningún campo (spec 032-catalogo-metodos-pago).
- El Super Admin no puede eliminar permanentemente un método del catálogo una vez creado, solo
  activarlo o desactivarlo; esto evita invalidar las ventas históricas que ya lo usaron o las
  configuraciones que algún negocio ya hubiera completado (spec 032-catalogo-metodos-pago).
- Cuando el Super Admin desactiva un método a nivel de plataforma, los negocios que lo tenían
  activo dejan de verlo disponible para cobros nuevos de inmediato, pero conservan los datos de
  integración que ya habían capturado, por si el Super Admin lo reactiva más adelante (spec
  032-catalogo-metodos-pago).
- El historial de ventas conserva siempre el método de pago exactamente como se registró al
  momento del cobro, sin importar cambios posteriores al catálogo (edición o desactivación) o a la
  configuración de un negocio en particular (spec 032-catalogo-metodos-pago).
- Un negocio solo puede activar métodos que ya existan en el catálogo administrado por el Super
  Admin; no existe ninguna forma de registrar un método de pago propio por fuera de ese catálogo
  (spec 032-catalogo-metodos-pago).
- Existe una lista cerrada y centralizada de nombres de subdominio reservados para uso interno de
  la propia plataforma (de forma ilustrativa, el panel administrativo de la plataforma usa uno de
  esos nombres reservados para sí mismo); ningún negocio puede registrarse usando alguno de esos
  nombres como su propio subdominio, y esa comparación ignora mayúsculas/minúsculas y espacios
  alrededor del texto escrito (spec 091-admin-subdominio-nombre-completo, verificado también
  contra la validación real que aplica el sistema al dar de alta un negocio).
- Esa misma validación de nombre reservado aplica tanto en la pantalla de alta de un negocio como
  en el sistema que la procesa; no puede evitarse enviando la solicitud de alta directamente al
  sistema sin pasar por la pantalla (spec 091-admin-subdominio-nombre-completo).
- El acceso al panel administrativo de la plataforma está aislado en ambos sentidos: una cuenta de
  negocio que intente entrar ahí es rechazada, y una cuenta de Super Admin que intente entrar al
  subdominio de un negocio existente, o a cualquier dirección que la plataforma no reconozca como
  propia o como de un negocio registrado, también es rechazada; en ambos casos, con un mensaje
  genérico que no permite distinguir si la cuenta contraria existe o no (spec
  091-admin-subdominio-nombre-completo).
- Cuando una operación de esta administración falla por un dato inexistente o una condición no
  autorizada, la respuesta siempre es un mensaje claro y específico a esa causa, sin exponer
  jamás información técnica interna (como fragmentos de la base de datos o trazas del sistema) ni
  confirmar la existencia de datos de otro negocio (spec 068-manejo-excepciones-super-admin).

## Diferenciador de mercado

En un punto de venta tradicional del sector heladerías/granizados, cada instalación suele
configurar sus propios métodos de pago de forma aislada, sin ningún catálogo centralizado que
defina qué datos debe pedir cada uno ni que garantice consistencia entre sucursales o clientes
distintos; cualquier método nuevo se improvisa localmente. SkeiloPOS centraliza ese catálogo a
nivel de toda la plataforma, de modo que un negocio nuevo activa métodos ya definidos y
consistentes en vez de configurar integraciones propias desde cero, y un cambio del Super Admin
(por ejemplo, agregar un campo nuevo a un método) queda disponible para cualquier negocio sin
trabajo adicional de su parte. De la misma forma, la protección automática de nombres reservados
evita, desde el propio formulario de alta, que un negocio nuevo intente tomar un nombre que la
infraestructura de la plataforma ya necesita para sí misma —un riesgo que, en un sistema instalado
de forma independiente por cada negocio, ni siquiera llega a existir, pero que una plataforma
multi-negocio como SkeiloPOS debe prevenir activamente.

---

> **Verificado contra**: specs 032-catalogo-metodos-pago, 091-admin-subdominio-nombre-completo,
> 068-manejo-excepciones-super-admin (spec.md y data-model.md de cada una), y el código real de
> validación de subdominios reservados y de respuesta de errores del módulo de plataforma —
> 2026-10-08.
