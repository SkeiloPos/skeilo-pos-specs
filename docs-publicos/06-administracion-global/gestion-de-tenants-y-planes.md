---
title: "Gestión de tenants y planes de suscripción"
description: "Cómo el Super Admin da de alta un negocio nuevo en la plataforma y le asigna el plan de suscripción que define sus límites y accesos."
---

# Gestión de tenants y planes de suscripción

SkeiloPOS opera como una plataforma multi-negocio: cada heladería, granizados o local de
gastronomía rápida que se suma al sistema es un negocio independiente (un "tenant"), con sus
propios datos, mesas, usuarios y configuración, pero administrado desde un único panel central de
plataforma. Esta función resuelve dos problemas de negocio conectados entre sí: cómo se da de alta
un negocio nuevo en la plataforma, y cómo se decide —de forma administrativa, sin que medie ningún
cobro automático— qué puede hacer cada negocio según el plan de suscripción que tiene asignado
(cuántas mesas, cajas, usuarios, productos o métodos de pago puede tener activos, y si tiene
acceso a módulos como inventario, compras o promociones).

## Roles que pueden usar esta función

- **Super Admin**: es el único rol que puede crear negocios nuevos, crear y editar planes de
  suscripción, y asignar, cambiar o renovar el plan vigente de cualquier negocio. Toda la gestión
  descrita en el flujo paso a paso de este artículo la realiza este rol, desde el panel
  administrativo de la plataforma.
- **Administrador de Tenant**: no gestiona planes ni los asigna, pero puede consultar en cualquier
  momento, desde su propio panel, cuál es el plan vigente de su negocio, cuánto ha consumido de
  cada límite y la fecha de vencimiento de su ciclo actual (o si su plan no vence nunca). No puede
  cambiar ninguno de esos valores por su cuenta.

## Flujo paso a paso

1. El Super Admin inicia sesión en el panel administrativo de la plataforma y abre la sección de
   planes de suscripción.
2. Antes de poder crear un negocio nuevo, debe existir al menos un plan ya definido. Si no existe
   ninguno adecuado, el Super Admin crea uno indicando su nombre, una descripción opcional, el
   límite de cada recurso que gobierna (mesas, cajas, usuarios, productos y métodos de pago
   activos simultáneamente —cualquiera de ellos puede marcarse como "ilimitado"—), si el plan
   incluye acceso a los módulos de inventario, compras y promociones, y, de forma opcional, un
   precio de referencia mensual y/o uno anual.
3. El Super Admin abre la sección de gestión de negocios y comienza el alta de uno nuevo,
   diligenciando el nombre del negocio, el subdominio único con el que ese negocio accederá al
   sistema, y los datos de la cuenta de su primer administrador (correo y nombre completo).
4. Como parte del mismo formulario de alta, el Super Admin elige obligatoriamente uno de los
   planes existentes y el ciclo de facturación de esa asignación inicial: mensual, anual, o "sin
   vencimiento" si ese negocio no debe bloquearse nunca automáticamente por tiempo. El formulario
   no permite completar la creación del negocio sin esta elección.
5. Al confirmar, el sistema crea en una sola operación el negocio, su propio espacio de datos y la
   cuenta de su administrador; desde ese momento el negocio queda disponible, ya conectado al
   catálogo de métodos de pago de la plataforma, listo para que su Administrador de Tenant active
   los métodos que use (ver "Catálogos globales y subdominios reservados").
6. Si el ciclo elegido fue mensual o anual, el sistema calcula de inmediato la fecha de vencimiento
   de esa asignación (un mes o un año después del momento de la asignación). Si se elige "sin
   vencimiento", ese negocio nunca se bloqueará automáticamente por tiempo.
7. Desde el primer momento, el negocio nuevo opera bajo las reglas del plan asignado: puede crear
   mesas, cajas, usuarios, productos y métodos de pago activos hasta el límite configurado (o sin
   tope si el plan los marca como "ilimitado"), y en su navegación solo aparecen los módulos de
   inventario, compras y promociones que el plan incluya.
8. En cualquier momento posterior, el Super Admin puede volver a la gestión de negocios para
   cambiar el plan vigente de uno de ellos (por ejemplo, subirlo de un plan "Básico" a uno "Pro")
   o renovar su ciclo de facturación actual; el cambio rige de inmediato, sin que el Administrador
   de Tenant deba cerrar sesión ni esperar ningún proceso adicional.
9. Si el Super Admin edita un límite o un acceso de un plan que ya tiene negocios asignados, el
   cambio se aplica de inmediato a todos ellos, sin necesidad de repetir la operación negocio por
   negocio.
10. El Administrador de Tenant, desde su propio panel, puede abrir en cualquier momento la pantalla
    de su plan y ver, por ejemplo, "4 de 5" mesas usadas, el estado de cada acceso de módulo, y la
    fecha de vencimiento de su ciclo actual (o un indicador de "sin vencimiento"), sin necesidad de
    contactar a soporte.

## Reglas de negocio y límites

- Un negocio nuevo no puede crearse sin elegir explícitamente uno de los planes ya existentes; no
  existe ningún plan asignado por defecto, ni siquiera de forma transitoria (spec
  033-planes-suscripcion-tenant, verificado también contra el modelo de datos real: la referencia
  al plan de un negocio es obligatoria desde su creación).
- Junto con el plan, la elección del ciclo de facturación (mensual o anual) también es
  obligatoria, salvo que se elija explícitamente "sin vencimiento"; si el Super Admin intenta usar
  un ciclo para el que el plan elegido no tiene un precio de referencia definido, el sistema
  rechaza esa combinación hasta que se eligió un ciclo con precio definido en ese plan (spec
  033-planes-suscripcion-tenant).
- Un plan puede definir hasta ocho características: cinco límites numéricos (mesas, cajas,
  usuarios, productos y métodos de pago activos simultáneamente) y tres accesos de módulo
  (inventario, compras, promociones). Cualquier característica que el Super Admin no configure
  explícitamente se trata, por defecto, como bloqueada: límite en cero o acceso denegado, según el
  tipo (spec 033-planes-suscripcion-tenant; verificado también contra el modelo de datos real,
  donde cada límite sin configurar queda en cero y cada acceso de módulo sin configurar queda en
  "no").
- Un límite numérico puede marcarse como "ilimitado"; en ese caso, ese recurso específico nunca
  vuelve a bloquear al negocio, sin importar cuántos registros cree (spec
  033-planes-suscripcion-tenant).
- El nombre de un plan es un texto corto y único en toda la plataforma (no pueden existir dos
  planes con el mismo nombre); la descripción es siempre opcional (spec
  033-planes-suscripcion-tenant, verificado contra el modelo de datos real).
- Si el Super Admin cambia un negocio a un plan con un límite numérico menor al que ya tiene en
  uso (por ejemplo, 8 mesas creadas y el nuevo plan permite 5), los recursos que ya existen se
  conservan sin cambios; el negocio solo queda bloqueado para crear recursos nuevos de ese tipo
  hasta que vuelva a estar por debajo del nuevo límite (spec 033-planes-suscripcion-tenant).
- Si el Super Admin le retira a un negocio el acceso a un módulo que ya tenía datos cargados
  (inventario, compras o promociones), ese módulo queda completamente inaccesible —ni siquiera en
  modo de solo consulta— hasta que se le reasigne el acceso; los datos ya cargados no se eliminan
  (spec 033-planes-suscripcion-tenant).
- Cuando la fecha de vencimiento de la asignación de un negocio se cumple sin que el Super Admin
  la renueve, el sistema bloquea automáticamente, desde ese momento, la creación de recursos
  nuevos y el acceso a los módulos del plan, con el mismo mecanismo y el mismo tipo de aviso que
  un límite alcanzado; ningún dato existente se borra por este motivo (spec
  033-planes-suscripcion-tenant).
- Renovar la asignación de un negocio (con el mismo plan o con otro) reinicia de inmediato el
  período de vigencia y levanta, sin ninguna acción adicional, cualquier bloqueo por vencimiento
  que estuviera activo (spec 033-planes-suscripcion-tenant).
- Un plan no puede eliminarse mientras tenga al menos un negocio asignado; el Super Admin debe
  reasignar primero esos negocios a otro plan (spec 033-planes-suscripcion-tenant).
- El alta de un negocio nuevo no solo crea el registro administrativo: también deja su espacio de
  datos propio completamente listo para operar, incluida su conexión con el catálogo de métodos de
  pago compartido de la plataforma, sin pasos manuales adicionales por parte del Super Admin
  (comportamiento verificado en producción y consolidado en las correcciones registradas en specs
  069-fix-creacion-tenant y 070-fix-metadata-tenant-fk).

## Diferenciador de mercado

Un punto de venta tradicional del sector heladerías/granizados suele venderse como una licencia
fija por sucursal o por caja, sin ningún mecanismo propio para escalonar comercialmente el acceso
a funciones según lo que cada negocio necesita; cualquier ajuste de ese tipo normalmente implica
una negociación aparte, fuera del propio sistema. SkeiloPOS resuelve esto con planes de
suscripción administrados centralmente, donde subir o cambiar el plan de un negocio —y con ello
sus límites de mesas, cajas, usuarios, productos y métodos de pago, además del acceso a módulos
completos como inventario o promociones— rige de inmediato para ese negocio, sin reinstalar nada,
sin visita técnica y sin que el Administrador de Tenant tenga que cerrar sesión.

---

> **Verificado contra**: specs 033-planes-suscripcion-tenant, 069-fix-creacion-tenant,
> 070-fix-metadata-tenant-fk (spec.md, plan.md y data-model.md de cada una), y el modelo de datos
> real del plan de suscripción en el sistema de SkeiloPOS — 2026-10-08.
