# Data Model: Rediseño de cambio de contraseña para usuarios invitados

Este feature no introduce entidades de dominio nuevas, campos de base de datos nuevos, ni
migraciones. Es una redefinición del estado de UI de una pantalla ya existente que consume
datos ya expuestos por `pos-backend`. Lo que sigue documenta el **estado de presentación**
(view-model) del componente, derivado de las entidades reales descritas en `spec.md` § Key
Entities, y de dónde sale cada dato.

## Entidades de negocio (existentes, sin cambios)

### Invitación de usuario (`UserInvitation`)
Fuente: `pos-backend/app/core/models.py:217-275` (sin cambios).
- `tenant_id`, `email`, `name?`, `role_id`, `password_hash` (de la contraseña temporal),
  `status` (`pending|consumed|cancelled`), `sent_at`, `consumed_at`, `cancelled_at`.
- Se consume (pasa a `status="consumed"`) dentro de `POST /auth/login`
  (`_consume_invitation_if_valid`, `pos-backend/app/api/v1/auth/routes.py:121-157`), creando
  el `User` correspondiente con `must_change_password=True`. Este flujo no cambia.

### Cuenta de usuario (`User`)
Fuente: `pos-backend/app/core/models.py` (sin cambios).
- Campos relevantes para esta pantalla: `email`, `role` (vía relación), `must_change_password`
  (`models.py:149`), `tenant_name` (propiedad, `models.py:180-182`), `tokens_valid_after`
  (`models.py:154`, usado para invalidar sesiones tras el cambio exitoso).
- `must_change_password` pasa de `True` a `False` dentro de `POST /auth/change-password`
  (`pos-backend/app/api/v1/auth/routes.py:397-404`) — sin cambios.

### Política de contraseña
Fuente: server-side `ChangePasswordRequest` (`pos-backend/app/api/v1/auth/schemas.py:9-13`) y
client-side `pos-heladeria/src/app/modules/auth/password-policy.ts` (sin cambios de reglas):
- `PASSWORD_MIN_LENGTH = 8`, `PASSWORD_MAX_LENGTH = 12`.
- Regla adicional no modelada en `password-policy.ts` (porque depende de la contraseña
  temporal, que el cliente sí conoce en este flujo a diferencia de reset-password): la nueva
  contraseña debe ser distinta a la temporal ingresada en el mismo formulario. Se modela en
  el view-model de la pantalla (ver abajo), no en la fuente compartida.

## View-model de la pantalla (`ChangePasswordComponent`, nuevo/reorganizado)

Estado interno que reemplaza al estado Tailwind actual, inspirado en el diseño de
referencia pero ajustado a las reglas reales:

| Campo | Tipo | Origen | Notas |
|---|---|---|---|
| `tenantName` | `string \| null` | `GET /tenant` → `TenantInfoService` | Se carga una vez al entrar a la pantalla (`ngOnInit`/efecto de carga), no de forma reactiva ante cada tecla — ver memoria de preferencias: solo fetch en carga de pantalla, nunca en un efecto reactivo disparado por input del usuario. |
| `role` | `string` | `AuthService.currentUser()?.role` | Ya disponible, sin red adicional. |
| `email` | `string` | `AuthService.currentUser()?.email` | Ya disponible, sin red adicional. |
| `form` | `FormGroup` | Reactive Forms | Campos `current_password`, `new_password`, `confirm_password`; validador de grupo `passwordsMatch` (existente) + validador `new_password` construido sobre `cumplePolitica` + regla "distinta a la temporal" comparando contra `current_password` en vivo. |
| `ruleStates` | `computed signal` | Deriva de `PASSWORD_RULES` + valor en vivo de `new_password` y `current_password` | Igual patrón que `reset-password.component.ts:244-255`, con la regla extra "Distinta a la temporal" evaluada contra `current_password`. |
| `errorMessage` | `signal<string \| null>` | Validaciones client-side (vacío, requisitos, no coincide) o respuesta de backend (`extractError()`) | Un único mensaje visible a la vez, igual que hoy; el texto varía según el caso (User Story 3). |
| `done` | `signal<boolen>` | Se activa tras una respuesta exitosa de `authService.changePassword()` | Controla el cambio de estado "formulario" → "Cuenta lista" dentro del mismo componente. |
| `showTemp` / `showNew` / `showConfirm` | `signal<boolean>` cada uno | Toggle independiente de cada `PasswordInputComponent` | Ya existe en `PasswordInputComponent`; se preserva su independencia (Edge Case del spec). |

### Reglas de checklist mostradas (ajustadas a lo real, ver research.md § 3)

1. "Entre 8 y 12 caracteres" — `new_password.length >= 8 && new_password.length <= 12`.
2. "Distinta a la contraseña temporal" — `new_password.length > 0 && new_password !== current_password`.

No se incluyen reglas de mayúscula ni número (el diseño de referencia las trae como ejemplo,
pero el backend no las exige; ver research.md § 3 y spec.md § Assumptions).

## Transiciones de estado de la pantalla

```
[Formulario visible]
  --(submit con current_password vacío)--> [Formulario visible, error: "temporal vacía"]
  --(submit con new_password que no cumple reglas)--> [Formulario visible, error: "requisitos"]
  --(submit con confirm_password != new_password)--> [Formulario visible, error: "no coinciden"]
  --(submit válido, backend rechaza current_password)--> [Formulario visible, error genérico de backend]
  --(submit válido, backend acepta)--> [Pantalla "Cuenta lista"]

[Pantalla "Cuenta lista"]
  --(click "Iniciar sesión")--> navega a la página de login del negocio (comportamiento de redirección ya existente, sin cambios)
```

No hay persistencia de este view-model fuera del ciclo de vida del componente; no se
introduce ningún almacenamiento local ni caché nuevo.
