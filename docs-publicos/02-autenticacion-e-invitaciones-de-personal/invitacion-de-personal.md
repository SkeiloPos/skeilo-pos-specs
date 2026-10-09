---
title: "Invitación de personal"
description: "Cómo un administrador de negocio invita a un cajero o colaborador nuevo, con su nombre, correo y rol, sin inventar contraseñas."
---

# Invitación de personal

Un Administrador de Tenant da de alta a su personal nuevo —cajeros, meseros u otros
administradores— exclusivamente por invitación: escribe el nombre completo, el correo y el rol de
la persona, y el sistema se encarga de generar una contraseña temporal y enviársela por correo
junto con la dirección de ingreso del negocio. En ningún momento el administrador ve, elige ni
comparte esa contraseña: la persona invitada la recibe directamente en su correo y la cambia por
una propia en su primer ingreso.

## Roles que pueden usar esta función

- **Administrador de Tenant**: es el único rol que puede invitar personal nuevo a su negocio; un
  Cajero/Staff no ve el botón para invitar.

## Flujo paso a paso

1. El Administrador de Tenant abre la página "Usuarios" de su negocio y pulsa "Agregar usuario"
   (o "Invitar usuario").
2. Completa el campo "Nombre completo" de la persona, su correo electrónico, y selecciona su rol
   (por ejemplo, cajero o administrador).
3. Pulsa enviar. El sistema crea una invitación pendiente con esos datos y, de inmediato, envía un
   correo a la persona invitada con la marca de SkeiloPOS, un saludo por su nombre, la dirección de
   ingreso de ese negocio, su usuario (su propio correo) y una contraseña temporal —generada
   automáticamente por el sistema, que nadie más llega a ver.
4. Si el envío del correo falla por cualquier motivo, la invitación no queda creada: el
   administrador ve un mensaje de error explícito y puede intentarlo de nuevo, sin que quede una
   invitación "a medias" sin forma de usarse.
5. Mientras la invitación está pendiente, aparece en la página "Usuarios" junto a las cuentas
   activas, mostrando su correo, su rol y la fecha en que se envió, claramente diferenciada de una
   cuenta ya activa.
6. La persona invitada abre el enlace de ingreso de su correo y entra por primera vez con su correo
   y la contraseña temporal recibida. El sistema la obliga a definir su propia contraseña antes de
   dejarla usar cualquier otra función, y en ese momento su cuenta queda activa, con el nombre
   completo que el administrador capturó al invitarla y el rol asignado.
7. Si el administrador necesita corregir un correo mal escrito o la persona perdió el correo con la
   contraseña temporal, puede reenviar la invitación: el sistema genera una contraseña temporal
   nueva, invalida la anterior de inmediato, y envía un correo nuevo con los mismos datos.
8. El administrador también puede cancelar una invitación pendiente en cualquier momento; al
   hacerlo, la contraseña temporal deja de servir de inmediato y la invitación deja de aparecer
   como pendiente.

## Reglas de negocio y límites

- El campo "Nombre completo" es obligatorio, debe tener entre 2 y 100 caracteres (una vez
  recortados los espacios de los extremos), solo acepta letras del alfabeto latino —incluidas
  tildes, ñ y letras como ü, ë, ç, ø— además de espacios, apóstrofes y guiones, y debe contener al
  menos dos letras (verificado en `specs/091-admin-subdominio-nombre-completo/spec.md`, FR-014, y
  en la validación real vigente del sistema).
- La contraseña temporal nunca se muestra en pantalla, no aparece en ninguna respuesta del sistema
  ni queda registrada en ningún lugar accesible para el administrador que invita; la única forma
  de conocerla es el correo que recibe la persona invitada (verificado en
  `specs/037-invitacion-usuarios-tenant/spec.md`, FR-006).
- No se puede invitar un correo que ya corresponde a un usuario del mismo negocio, esté activo o
  desactivado, ni un correo que ya tiene una invitación pendiente en ese mismo negocio; en ambos
  casos el sistema muestra un error explícito y no envía ningún correo (verificado en
  `specs/037-invitacion-usuarios-tenant/spec.md`, FR-015).
- El mismo correo puede tener invitaciones o cuentas completamente independientes en negocios
  distintos; invitar a alguien en un negocio nunca afecta su cuenta en otro (verificado en
  `specs/037-invitacion-usuarios-tenant/spec.md`, FR-014).
- Si el envío del correo de invitación falla, el sistema no deja creada la invitación: la operación
  completa se revierte, para que nunca quede una invitación pendiente sin ninguna forma de usarse
  (verificado en `specs/037-invitacion-usuarios-tenant/spec.md`, FR-012, y en el comportamiento real
  vigente del sistema).
- El correo de invitación saluda a la persona por su nombre completo cuando la invitación lo tiene,
  y con un saludo genérico cuando no lo tiene, pero nunca muestra el correo electrónico de la
  persona como si fuera su nombre (verificado en
  `specs/091-admin-subdominio-nombre-completo/spec.md`, FR-019, FR-022, y
  `specs/096-correos-transaccionales/spec.md`, D11/FR-058).
- Al reenviar una invitación, la contraseña temporal anterior deja de funcionar de inmediato y solo
  la más reciente permite el primer ingreso (verificado en
  `specs/037-invitacion-usuarios-tenant/spec.md`, FR-010).

## Diferenciador de mercado

A diferencia de muchos sistemas POS tradicionales, donde el propio dueño o administrador define a
mano la contraseña de cada empleado nuevo —y por lo tanto la conoce, y suele reutilizarla entre
varios empleados por comodidad—, en SkeiloPOS el administrador nunca ve ni elige la contraseña de
nadie: el sistema la genera automáticamente y solo la persona invitada la recibe, directamente en
su propio correo.

---

> **Verificado contra**: `specs/037-invitacion-usuarios-tenant/spec.md`,
> `specs/091-admin-subdominio-nombre-completo/spec.md`,
> `specs/096-correos-transaccionales/spec.md` — 2026-10-08.
