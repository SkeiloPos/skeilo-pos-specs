# Research: Rediseño de cambio de contraseña para usuarios invitados

## 1. ¿Dónde vive hoy esta pantalla y cómo funciona?

**Decisión**: El rediseño se aplica sobre `ChangePasswordComponent`
(`pos-heladeria/src/app/modules/auth/pages/change-password.component.ts`), la pantalla ya
existente que atiende la ruta `change-password`.

**Rationale**: Es el componente real que hoy renderiza este flujo, protegido por
`passwordChangeGuard` (redirige aquí cuando `user.mustChangePassword` es verdadero, aplicado
sobre `/dashboard` y `/super-admin`) y por `changePasswordPageGuard` (saca de esta ruta a
quien ya no necesita cambiar su contraseña, o a `/login` si no hay usuario). No existe otra
pantalla candidata ni duplicada.

**Alternatives considered**: Crear un componente nuevo en paralelo — descartado porque
duplicaría rutas, guards y lógica de envío sin ninguna ventaja; la constitución (Principio
V) exige evitar refactors/duplicaciones no justificadas por la spec.

## 2. ¿Cómo se envía el cambio de contraseña al backend?

**Decisión**: Se mantiene sin cambios el flujo actual: `ChangePasswordComponent.submit()` →
`AuthService.changePassword(current_password, new_password)`
(`pos-heladeria/src/app/core/services/auth.service.ts:104-125`) → `AuthApiService.changePassword()`
(`pos-heladeria/src/app/core/auth/auth-api.service.ts:48-50`) → `POST /auth/change-password`
(`pos-backend/app/api/v1/auth/routes.py:379-409`). Tras un cambio exitoso, `AuthService`
vuelve a iniciar sesión con la nueva contraseña para refrescar los tokens, porque
`must_change_password` viaja en claims de JWT que quedarían obsoletos si no se renuevan.

**Rationale**: Es el contrato funcional vigente y protegido (Principio II); el spec no pide
cambiar el backend, solo la experiencia visual.

**Alternatives considered**: Ninguna — cambiar este contrato está fuera de alcance según
`spec.md` § Assumptions.

## 3. ¿Cuáles son las reglas reales de validación de la nueva contraseña?

**Decisión**: Las dos únicas reglas vigentes son:
- Longitud entre 8 y 12 caracteres.
- Distinta a la contraseña temporal/actual.

Fuente server-side: `ChangePasswordRequest` en `pos-backend/app/api/v1/auth/schemas.py:9-13`
(`min_length=8, max_length=12` para `new_password`) y la comparación de igualdad contra el
hash actual en `pos-backend/app/api/v1/auth/routes.py:391-395` ("La nueva contraseña debe ser
distinta de la actual"). No existe ninguna regla de mayúscula, número o símbolo en el
backend (confirmado por búsqueda exhaustiva en `schemas.py` y `routes.py`: solo hay
restricciones de longitud y las dos comparaciones de igualdad).

Fuente client-side reutilizable: `pos-heladeria/src/app/modules/auth/password-policy.ts`
(`PASSWORD_MIN_LENGTH = 8`, `PASSWORD_MAX_LENGTH = 12`, `PASSWORD_RULES`, `cumplePolitica()`),
ya usada como única fuente de verdad por `reset-password.component.ts`.

**Rationale**: El diseño de referencia (`desing/Primer inicio de sesion.dc.html`) incluye
"Una letra mayúscula" y "Un número" como ejemplo de checklist, pero el backend no las exige.
Mostrarlas como requisito prometería una validación que el sistema no aplica — se decidió
con el usuario (ver spec.md § Assumptions) ajustar el checklist visual a únicamente las dos
reglas reales.

**Alternatives considered**:
- Mostrar las 4 reglas del diseño de referencia tal cual → descartado: induciría a error al
  usuario (podría creer que necesita mayúscula/número cuando no es cierto) y violaría el
  requisito de fidelidad real al comportamiento del sistema, no solo al pixel del diseño.
- Añadir las reglas de mayúscula/número al backend para que el diseño sea 100% literal →
  descartado: sería un cambio de comportamiento de negocio no solicitado por el spec y
  fuera de su alcance declarado (Principio V, Principio II — requeriría decisión de negocio
  explícita que no existe).

## 4. ¿Cómo mostrar el nombre del negocio (tenant), el rol y el correo invitado?

**Decisión**: Rol y correo ya están disponibles en el `currentUser()` expuesto por
`AuthService` tras el login con contraseña temporal (`user_data.role`, `user_data.email`
en la respuesta de `POST /auth/login`, `pos-backend/app/api/v1/auth/routes.py:220-228`). El
nombre del negocio se obtiene llamando al endpoint ya existente `GET /tenant`
(`pos-backend/app/api/v1/tenant/router.py:23-35`), que solo requiere `get_current_user` (sin
restricción de rol ni de `must_change_password`) y ya es consumido en el frontend por
`TenantInfoService` (`pos-heladeria/src/app/core/tenant/tenant-info.service.ts:9-60`, expone
entre otros el campo `name`).

**Rationale**: La investigación confirmó que el backend **no enforce** `must_change_password`
a nivel de servidor (ningún dependency en `pos-backend/app/core/dependencies.py` lo verifica);
el único gate es client-side vía guards de Angular. Esto significa que, con el access token
que el usuario ya recibe en la respuesta de login (aunque deba cambiar su contraseña), el
frontend puede llamar `GET /tenant` sin ningún cambio de backend. Esto cumple el requisito
FR-001 del spec ("mostrar tenant, rol y correo") **sin tocar `pos-backend`**, manteniendo el
cambio contenido a una sola clase (Principio VI).

**Alternatives considered**:
- Añadir `tenant_name` a la respuesta de `POST /auth/login` y `POST /auth/refresh-token`
  (el campo ya existe como propiedad de modelo, `User.tenant_name` en
  `pos-backend/app/core/models.py:180-182`, pero nunca se serializa en esas respuestas) →
  descartado por ahora: es viable y de bajo riesgo, pero introduciría un cambio de backend
  no estrictamente necesario cuando `GET /tenant` ya resuelve el mismo dato sin tocar un
  endpoint de autenticación compartido por todos los flujos de login. Se deja documentado
  aquí como alternativa de respaldo si en la fase de implementación se detecta que la
  llamada adicional a `GET /tenant` introduce una complejidad o latencia perceptible
  inaceptable; de recurrir a ella, requeriría registrar la justificación técnica
  correspondiente antes de modificar el backend.

## 5. ¿Qué patrón visual/estructural reutilizar para la fidelidad al diseño?

**Decisión**: Migrar `ChangePasswordComponent` del markup Tailwind ad-hoc actual (fondo
degradado morado, tarjeta blanca, emoji 🔒) al mismo patrón ya usado por
`login`/`reset-password.component.ts`:
- `AuthShellComponent` para el layout de dos columnas (formulario + panel promocional),
  badge de negocio y pie con copyright + enlace a política de privacidad.
- Tokens `.auth-*` de `pos-heladeria/src/styles.css:100-210` (`.auth-title`, `.auth-subtitle`,
  `.auth-field-label`, `.auth-input`, `.auth-button`, `.auth-alert-error`, `.auth-badge`) en
  vez de clases Tailwind sueltas.
- `PasswordInputComponent` para los tres campos (ya se usa hoy, se mantiene).
- El checklist en tiempo real (`ruleStates` computed signal + `<ul aria-live="polite">`)
  tal como está implementado en `reset-password.component.ts:141-164, 244-258`, mapeando los
  `PASSWORD_RULES` de la fuente única de verdad en vez de las 4 reglas estáticas del HTML de
  referencia (ver punto 3).
- Pantalla de confirmación "Cuenta lista" como un segundo estado del mismo componente
  (`isDone`/`done` en el diseño de referencia), sin crear una ruta/componente separado.

**Rationale**: Reutilizar el shell y los tokens ya validados visualmente en otras pantallas
de auth garantiza consistencia entre pantallas (login, reset-password, change-password) y
evita reinventar estilos; además es exactamente el patrón que el diseño de referencia
describe (layout de dos columnas, panel promocional, badge, footer). Reutilizar el checklist
de `reset-password.component.ts` evita que el checklist y el validador del formulario puedan
divergir (ambos derivan de `cumplePolitica()`), accesibilidad incluida (estado nunca
dependiente solo del color, sufijo `sr-only` "(cumplido)"/"(pendiente)").

**Alternatives considered**:
- Mantener el look Tailwind actual y solo ajustar colores → descartado: no cumpliría FR-013
  (fidelidad al diseño de referencia: tipografía, estructura de dos columnas, panel
  promocional) ni la consistencia visual que ya exhiben las demás pantallas de auth.
- Construir un checklist nuevo específico para esta pantalla → descartado: duplicaría lógica
  ya resuelta y probada en `reset-password.component.ts`, violando Principio V.

## 6. Mensajes de error específicos por caso (User Story 3)

**Decisión**: Mantener la distinción de errores ya cubierta por las validaciones de
formulario reactivo del lado cliente (contraseña temporal vacía, nueva contraseña que no
cumple requisitos, confirmación que no coincide — todas evaluables sin red) y, para el
rechazo del servidor (contraseña temporal incorrecta), mostrar el mensaje genérico que ya
retorna `AuthService.changePassword()` vía `extractError()`, sin revelar información
sensible, igual que hoy.

**Rationale**: El spec (Edge Cases) exige explícitamente que el rechazo del servidor use "un
mensaje de error genérico sin revelar información sensible" — eso ya es lo que hace el
backend (`"Current password is incorrect"` sin detalles adicionales) y lo que propaga
`extractError()` hoy. Los tres casos de error 100% client-side (temporal vacía, requisitos
no cumplidos, confirmación no coincide) sí deben mostrar mensajes específicos y distintos
entre sí, que es exactamente lo que ya hace `submit()` en el diseño de referencia
(tres `set({err: ...})` distintos) y lo que debe replicar la nueva lógica de envío del
componente Angular.

**Alternatives considered**: Pedir al backend mensajes más específicos para el caso de
contraseña temporal incorrecta → descartado explícitamente por el propio spec (edge case:
"mensaje de error genérico sin revelar información sensible").

## Resumen de NEEDS CLARIFICATION resueltos

No quedó ningún `NEEDS CLARIFICATION` pendiente: las dos decisiones que el spec dejaba
abiertas al diseño técnico (qué hacer con las reglas de mayúscula/número del diseño de
referencia, y cómo obtener el nombre del negocio) ya estaban resueltas explícitamente en
`spec.md` § Assumptions y se documentan aquí con su respaldo en código.
