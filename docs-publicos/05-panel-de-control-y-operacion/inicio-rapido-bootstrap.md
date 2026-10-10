---
title: "Inicio rápido del panel"
description: "Por qué el panel queda listo para operar más rápido al iniciar sesión, incluso con una conexión lenta o inestable."
---

# Inicio rápido del panel

Al iniciar sesión, el panel necesita traer del servidor la información del negocio, el estado del
plan de suscripción y las notificaciones recientes antes de quedar listo para usarse. SkeiloPOS
reúne esa información en una sola carga coordinada en lugar de pedirla en varias idas y vueltas
independientes al servidor, para que el panel quede operativo más rápido al iniciar el turno —algo
especialmente notorio cuando el local depende de una conexión lenta o inestable, por ejemplo un
plan de datos móvil de respaldo.

El beneficio es exclusivamente de velocidad al arrancar: la información que trae esta carga inicial
es la misma que el panel ya mostraba antes, y cualquier actualización puntual posterior (por
ejemplo, editar un dato del negocio en Ajustes) sigue funcionando igual que siempre, sin pasar de
nuevo por esta carga inicial.

## Roles que pueden usar esta función

- **Cajero/Staff**
- **Administrador de Tenant**

Esta función ocurre automáticamente para cualquiera de los dos roles al iniciar sesión en el panel
de un negocio; no requiere ninguna acción manual ni configuración de su parte, y su comportamiento
es idéntico para ambos.

## Flujo paso a paso

1. El usuario, Cajero/Staff o Administrador de Tenant, inicia sesión con sus credenciales.
2. Al entrar al panel, el sistema reúne en una sola carga coordinada la información del negocio,
   el estado del plan de suscripción vigente y las notificaciones recientes, en lugar de pedir cada
   una por separado.
3. El panel queda operativo en cuanto esa carga responde, mostrando la información del negocio, el
   plan vigente y el listado completo de notificaciones recientes (no solo un número de pendientes).
4. Si esa carga inicial falla por completo —por ejemplo, por un corte momentáneo de conexión—, el
   panel sigue siendo utilizable: se muestra con los valores vacíos que ya usa hoy en ese caso, sin
   pantalla en blanco ni bloqueo, y sin reintentar automáticamente dentro de ese mismo ingreso. Si
   el usuario recarga la página, el sistema vuelve a intentar la carga desde cero.
5. Si solo una parte de esa información —negocio, plan o notificaciones— no responde mientras las
   otras dos sí, el panel muestra con normalidad las partes que llegaron bien y deja vacía
   únicamente la que falló, sin bloquear el ingreso completo por un solo dato faltante.
6. Un usuario Super Admin que ingresa sin un negocio ni un plan asociados completa este mismo
   arranque sin error, con las secciones de negocio y plan vacías porque no le corresponden.
7. Una vez que el panel ya está operativo, cualquier actualización puntual posterior —por ejemplo,
   tras editar un dato del negocio en Ajustes— se refresca de forma individual, sin repetir esta
   carga inicial completa.
8. Durante el resto del turno, si distintas partes del panel necesitan la misma información del
   negocio o del plan casi al mismo tiempo, el sistema evita consultarla dos veces al servidor y
   evita volver a pedirla si ya la tiene disponible desde el arranque, manteniendo el panel
   respondiendo con la misma rapidez más allá del momento de iniciar sesión.

## Reglas de negocio y límites

- La carga inicial del panel reúne en una sola operación la información del negocio, el plan de
  suscripción vigente y las notificaciones recientes, que antes se pedían por separado —
  verificado en spec 100-bootstrap-dashboard-staff (FR-001, FR-002).
- Si esa carga falla por completo, el panel se muestra con los valores vacíos que ya usa hoy, sin
  bloquear al usuario y sin reintentar automáticamente dentro del mismo ingreso — verificado en
  spec 100-bootstrap-dashboard-staff (FR-005).
- Si solo una de las tres partes de esa carga falla, las otras dos se entregan completas y
  únicamente la parte fallida queda vacía — verificado en
  spec 100-bootstrap-dashboard-staff (FR-006).
- Un usuario Super Admin sin negocio ni plan asociados completa este arranque sin error, con las
  secciones de negocio y plan vacías — verificado en spec 100-bootstrap-dashboard-staff
  (FR-007).
- Las notificaciones que trae esta carga inicial son el listado reciente completo, no únicamente
  un número de notificaciones pendientes — verificado en
  spec 100-bootstrap-dashboard-staff (FR-008).
- Las actualizaciones puntuales posteriores al inicio (por ejemplo, tras editar en Ajustes) siguen
  haciéndose de forma individual, sin pasar de nuevo por la carga inicial — verificado en
  spec 100-bootstrap-dashboard-staff (FR-003).
- El aviso en tiempo real del panel no depende de esta carga inicial: se solicita aparte, justo
  antes de activarse, y sigue funcionando igual sin importar si la carga inicial tuvo éxito, se
  completó parcialmente o falló — verificado en spec 100-bootstrap-dashboard-staff
  (FR-004, FR-009).
- Durante el resto de la sesión, si la información del negocio o del plan ya está disponible, el
  sistema la reutiliza sin volver a consultarla al servidor; si dos partes del panel la solicitan
  casi al mismo tiempo, solo se hace una consulta real y ambas reciben el mismo resultado —
  verificado en spec 101-cache-peticiones-tenant-plan (FR-001, FR-002).
- Esa información no tiene un tiempo de expiración fijo: se considera válida mientras dure la
  sesión abierta en el navegador, hasta que algo la actualice explícitamente o el usuario recargue
  la página por completo — verificado en spec 101-cache-peticiones-tenant-plan
  (Assumptions).

## Diferenciador de mercado

En un punto de venta tradicional del sector heladerías/granizados, el panel de administración
suele disparar varias peticiones independientes al servidor apenas se inicia sesión, y una
conexión lenta o inestable puede dejar partes del panel cargando o en blanco durante varios
segundos. SkeiloPOS reúne esa información en un solo arranque coordinado y sigue siendo utilizable
incluso si una parte de esa información no responde a tiempo, acortando el tiempo real que un
cajero o un administrador espera para empezar a operar al abrir su turno.

---

> **Verificado contra**: spec 100-bootstrap-dashboard-staff,
> spec 101-cache-peticiones-tenant-plan — 2026-10-08.
