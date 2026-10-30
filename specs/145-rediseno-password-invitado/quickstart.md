# Quickstart: Validar el rediseño de cambio de contraseña para invitados

Esta guía valida de forma manual y automática que el rediseño cumple los criterios de
aceptación de `spec.md`, usando el entorno local de `pos-backend` + `pos-heladeria`.

## Prerrequisitos

- `pos-backend` corriendo localmente con Postgres disponible (ver memoria del proyecto:
  "How to run sibling-repo tests" para el comando del venv y la confirmación de que hay
  Postgres local disponible).
- `pos-heladeria` corriendo localmente (`ng serve` o equivalente del proyecto) apuntando al
  backend local.
- Un tenant de prueba existente y un usuario administrador o superadmin con sesión activa
  para poder invitar.

## Preparar una invitación de prueba

1. Como admin/superadmin del tenant de prueba, crear una invitación para un rol como
   "cajero" (`POST /invitations`, ver `pos-backend/app/api/v1/invitations/router.py:81-168`).
2. Capturar la contraseña temporal generada (llega por correo vía
   `construir_correo_invitacion`; en entorno local revisar el servicio de correo o el log
   configurado para desarrollo).

## Escenario 1 — Completar el cambio de contraseña (User Story 1, P1)

1. Abrir la URL de login del tenant e iniciar sesión con el correo invitado y la
   contraseña temporal.
2. Verificar que redirige automáticamente a `/change-password`
   (`passwordChangeGuard`, dado que `must_change_password=true`).
3. Verificar que la pantalla muestra: nombre del negocio (vía `GET /tenant`), rol asignado
   (ej. "cajero") y el correo de la cuenta invitada (FR-001).
4. Ingresar la contraseña temporal correcta, una nueva contraseña entre 8 y 12 caracteres
   distinta a la temporal, y confirmarla de forma idéntica.
5. Enviar el formulario.
6. **Resultado esperado**: la pantalla cambia a la confirmación "Cuenta lista" (FR-009); al
   pulsar "Iniciar sesión" (FR-010), navega a la página de login del negocio.
7. Verificar en backend que `must_change_password` del usuario quedó en `false` y que el
   login previo con contraseña temporal ya no funciona (hash actualizado) — comportamiento
   ya existente, no debe haber cambiado.

## Escenario 2 — Checklist en tiempo real (User Story 2, P2)

1. Repetir pasos 1-2 del Escenario 1 para llegar al formulario.
2. En el campo "Nueva contraseña", escribir progresivamente:
   - Una contraseña de 10 caracteres distinta a la temporal → verificar que **ambos**
     requisitos ("Entre 8 y 12 caracteres" y "Distinta a la contraseña temporal") se marcan
     como cumplidos antes de enviar el formulario (FR-005, SC-002).
   - Borrar y escribir una contraseña igual a la temporal → verificar que solo el requisito
     "Distinta a la contraseña temporal" cambia a pendiente, sin afectar el de longitud.
3. Verificar que el checklist **no** muestra requisitos de mayúscula ni número (ajuste
   confirmado respecto al diseño de referencia, ver research.md § 3).
4. Verificar accesibilidad: cada ítem del checklist comunica su estado también por texto
   (no solo color), vía el sufijo visualmente oculto "(cumplido)"/"(pendiente)".

## Escenario 3 — Errores del formulario (User Story 3, P3)

1. Enviar el formulario con la contraseña temporal vacía → verificar mensaje específico
   indicando que debe escribir la contraseña temporal de su invitación (FR-006); el
   formulario permanece visible con los demás campos intactos.
2. Ingresar una nueva contraseña que no cumple los requisitos (p. ej. 5 caracteres) y
   enviar → verificar mensaje específico de requisitos no cumplidos (FR-007).
3. Ingresar una nueva contraseña válida y una confirmación distinta, y enviar → verificar
   mensaje específico de "las contraseñas no coinciden" (FR-008).
4. Ingresar una contraseña temporal incorrecta (que no corresponde a la invitación real) y
   el resto de campos válidos, y enviar → verificar que el backend rechaza la solicitud y
   se muestra un mensaje de error genérico, sin detalles sensibles, con el formulario aún
   disponible para reintentar (Edge Case del spec).

## Escenario 4 — Responsive (Edge Case / SC-004)

1. Reducir el ancho del navegador por debajo del breakpoint móvil (ver `@media
   (max-width:900px)` del diseño de referencia).
2. Verificar que el panel promocional lateral desaparece y el formulario ocupa todo el
   ancho, sin perder ningún campo, checklist ni mensaje (FR-011).
3. Repetir el Escenario 1 completo en este ancho angosto para confirmar que la
   funcionalidad no se pierde.

## Escenario 5 — Visibilidad independiente de contraseñas (Edge Case)

1. En el formulario, alternar mostrar/ocultar en el campo de contraseña temporal.
2. Verificar que los otros dos campos (nueva contraseña, confirmación) no cambian su
   estado de visibilidad.
3. Repetir para cada uno de los otros dos campos de forma independiente.

## Verificación automatizada

- Ejecutar los tests unitarios de `pos-heladeria` para `change-password.component.ts` (y,
  si se tocó, `reset-password.component.ts`/`password-policy.ts`) con el runner del
  proyecto (`@angular/build:unit-test`).
- Confirmar que los characterization tests existentes de `pos-backend` relacionados con
  `POST /auth/change-password`, `POST /auth/login` (consumo de invitación) y `GET /tenant`
  siguen en verde sin modificaciones (este feature no debe requerir tocarlos).
- Ver memoria del proyecto "How to run sibling-repo tests" para los comandos exactos del
  venv de `pos-backend` y la advertencia de que el baseline del frontend es flaky/no
  determinista: comparar por archivo de test afectado, no por el conteo total de la suite.

## Pie de página (FR-012)

Verificar en cualquiera de los escenarios anteriores que el pie de la pantalla muestra el
aviso de derechos de autor del producto y un enlace a la política de privacidad, igual que
en `login`/`reset-password`.
