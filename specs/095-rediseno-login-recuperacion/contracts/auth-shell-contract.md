# Contrato — Cascarón de autenticación y las tres pantallas

**Spec**: [../spec.md](../spec.md) | **Research**: [../research.md](../research.md) | **Fecha**: 2026-10-05

Esta spec **no expone ninguna interfaz nueva hacia otros sistemas**: no hay endpoint, ni evento,
ni comando. Su contrato es el de la interfaz de usuario, que es lo que otros artefactos (tests,
tareas, auditorías) van a verificar. Por eso este documento fija tres cosas:

1. El **contrato del componente** `AuthShellComponent`, que las tres pantallas consumen.
2. La **estructura observable** de cada pantalla: estados, controles, `data-testid` y atributos
   de accesibilidad.
3. Lo que **no cambia** del contrato HTTP, para que quede verificable que FR-044 se cumplió.

Los textos literales no están aquí: viven en [auth-copy-contract.md](./auth-copy-contract.md),
porque son el artefacto que más se revisa y conviene poder leerlo de un tirón.

---

## 1. `AuthShellComponent`

**Ubicación**: `pos-heladeria/src/app/modules/auth/components/auth-shell.component.ts`
**Selector**: `app-auth-shell` · **Standalone**, `ChangeDetectionStrategy.OnPush`

### Entradas

| Input | Tipo | Por defecto | Para qué |
|---|---|---|---|
| *(ninguno obligatorio)* | | | El cascarón no recibe el contexto: lo lee de `TenantContextService` (FR-010) |

El cascarón **no tiene inputs de contenido**: el contenido se proyecta.

### Proyección de contenido

| Ranura | Selector | Contenido |
|---|---|---|
| principal | *(por defecto)* | el formulario o el estado propio de cada pantalla |

### Lo que el cascarón garantiza

| # | Garantía | Requisito |
|---|---|---|
| C1 | Rejilla de dos columnas desde 1024 px: formulario a la izquierda, marca a la derecha | FR-001, US4-1 |
| C2 | Orden fijo en la columna izquierda: logotipo → etiqueta de contexto → contenido proyectado → pie | FR-002 |
| C3 | Por debajo de 1024 px: una sola columna, panel de marca ausente del layout y **su imagen sin descargar** | FR-005, SC-007 |
| C4 | Ningún desplazamiento horizontal desde 360 px | FR-006, SC-006 |
| C5 | La etiqueta de contexto se pinta con su texto definitivo en el primer render, sin estado de carga | FR-007c, SC-011 |
| C6 | Con `UNRECOGNIZED`: se renderiza el aviso y **no se proyecta** el contenido | FR-009, R6 |
| C7 | El pie muestra el año de `new Date().getFullYear()` y el enlace de privacidad | FR-003, FR-003a |
| C8 | Ninguna petición al API sale del cascarón, en ningún contexto | FR-007a, SC-011, SC-012 |

### Estructura observable

```
app-auth-shell
├─ [data-testid="auth-brand-logo"]        <img src="/logo.svg" alt="SkeiloPOS">
├─ [data-testid="auth-context-badge"]     etiqueta de contexto        (ausente si UNRECOGNIZED)
├─ [data-testid="unrecognized-host"]      aviso + enlace a publicSiteUrl   (solo si UNRECOGNIZED)
├─ <ng-content>                           contenido de la pantalla    (ausente si UNRECOGNIZED)
├─ [data-testid="auth-footer"]            "© {año} SkeiloPOS" + enlace "Política de privacidad"
└─ [data-testid="auth-brand-panel"]       lema + texto de apoyo; vista previa como background-image
```

`data-testid="unrecognized-host"` **se conserva tal cual** del código actual: es el gancho que
usan los tests de la spec 091 y mantenerlo evita romperlos por el nombre mientras se cambia su
texto (R16).

### Etiqueta de contexto

| Contexto | Contenido de `[data-testid="auth-context-badge"]` | Atributos |
|---|---|---|
| `TENANT` | ícono `store` + `tenantSlug()` sin transformar | `title` con el slug completo; `max-w` + `truncate` |
| `SUPER_ADMIN` | ícono genérico + "Administración de la plataforma" | — |
| `UNRECOGNIZED` | el elemento **no existe** | — |

### Panel de marca

| Elemento | Forma |
|---|---|
| Lema y texto de apoyo | **texto HTML real**, no imagen (FR-004, FR-042) |
| Vista previa | `background-image` de `/images/auth-preview.webp` declarada dentro de `@media (min-width: 1024px)` |
| Tamaño del activo | ≤ 80 KB |
| Si el activo falla | el panel conserva color y texto; sin hueco roto (*edge case* de la spec) |

---

## 2. Pantalla de inicio de sesión (`/login`)

### Controles

| Control | `data-testid` | Tipo | `autocomplete` | Requisito |
|---|---|---|---|---|
| Correo electrónico | `login-email` | `input[type=email]` con `<label for>` | `email` | FR-011, FR-011a, FR-017, FR-038 |
| Contraseña | `login-password` | `app-password-input` con `<label for>` | `current-password` | FR-011, FR-017, FR-038 |
| Ver/ocultar contraseña | — | `button` **enfocable** con `aria-label` + `aria-pressed` | — | FR-016, FR-040 |
| Mantener sesión iniciada | `login-keep-session` | `input[type=checkbox]` con `<label for>` | — | FR-019a |
| ¿Olvidaste tu contraseña? | `login-forgot-link` | `a[routerLink="/forgot-password"]` | — | FR-011 |
| Iniciar sesión | `login-submit` | `button[type=submit]` | — | FR-011 |
| Aviso de contraseña actualizada | `login-notice` | región `role="status"` | — | FR-031, FR-041 |
| Error | `login-error` | región `role="alert"` | — | FR-012, FR-041 |

### Comportamiento

| # | Dado | Entonces | Requisito |
|---|---|---|---|
| L1 | Campos obligatorios vacíos al enviar | error por campo, **cero** peticiones | FR-014 |
| L2 | Credenciales rechazadas (`401` **o** `403`) | un único texto "Credenciales inválidas" | FR-012, SC-003, R7 |
| L3 | Tras el rechazo | contraseña vacía y **enfocada**; correo conservado | FR-013 |
| L4 | Petición en curso | botón deshabilitado + indicador de progreso; **una sola** petición aunque se pulse varias veces | FR-015, SC-009 |
| L5 | Éxito con destino previo | se navega a ese destino | FR-018 |
| L6 | Éxito sin destino previo | se navega a la pantalla inicial del rol (`ROLE_HOME`, intacto) | FR-018, FR-019 |
| L7 | Éxito con contraseña temporal | se navega a `/change-password` (comportamiento existente, intacto) | — |
| L8 | Marcar "Mantener sesión iniciada" | el cuerpo de la petición es **exactamente** `{ email, password }` | FR-019c |
| L9 | Marcar "Mantener sesión iniciada" | la vida de la sesión es idéntica; nada de contraseña queda en el navegador | FR-019b, FR-019d, SC-013 |
| L10 | Contexto `UNRECOGNIZED` | sin formulario y sin petición, aunque se invoque `submit()` | FR-009 |

**El control inerte, por contrato**: no participa en ningún `FormGroup` que se serialice hacia
el API, no se lee en `AuthService`, no se persiste, y su etiqueta no menciona contraseñas
(FR-019e). Es un `checkbox` con estado local y nada más.

---

## 3. Pantalla de solicitud de enlace (`/forgot-password`)

Dos estados mutuamente excluyentes: **formulario** y **confirmación de envío**.

### Estado formulario

| Control | `data-testid` | Requisito |
|---|---|---|
| Correo electrónico (`<label for>`, `autocomplete="email"`) | `forgot-email` | FR-038, FR-017 |
| Enviar enlace | `forgot-submit` | US2-1 |
| Volver a iniciar sesión | `forgot-back-link` | FR-025 |
| Error (`role="alert"`) | `forgot-error` | FR-023, FR-041 |

### Estado confirmación

| Elemento | `data-testid` | Requisito |
|---|---|---|
| Mensaje genérico, con caducidad de 30 minutos (`role="status"`) | `forgot-sent` | FR-020, FR-041 |
| Reenviar enlace (con cuenta regresiva en su texto) | `forgot-resend` | FR-021 |
| Volver a iniciar sesión | `forgot-back-link` | FR-025 |

### Comportamiento

| # | Dado | Entonces | Requisito |
|---|---|---|---|
| F1 | Cualquier correo, exista o no la cuenta | **el mismo** mensaje genérico; el estado no depende de la respuesta más allá del código HTTP | FR-020, SC-003 |
| F2 | Solicitud aceptada | se pasa a confirmación y el reenvío queda deshabilitado 60 s con cuenta regresiva visible | FR-021 |
| F3 | Recarga durante el bloqueo | sigue bloqueado por el tiempo que falte | FR-022 |
| F4 | Pestaña en segundo plano más de 60 s | al volver, el reenvío está habilitado (no se alargó) | FR-022 |
| F5 | Respuesta `429` | mensaje de demasiados intentos, sin revelar existencia de cuenta | FR-023, R11 |
| F6 | Fallo de red | el botón sale del estado de carga y se puede reintentar | *edge case* |
| F7 | "Volver a iniciar sesión" desde cualquiera de los dos estados | se navega a `/login` del mismo subdominio (ruta relativa, nunca host absoluto) | FR-025 |
| F8 | Contexto `UNRECOGNIZED` | aviso del cascarón, sin formulario y sin petición | FR-009, R6 |

---

## 4. Pantalla de contraseña nueva (`/reset-password?token=…`)

Tres estados: **verificando**, **formulario**, **enlace no válido**. El cuarto estado de hoy
(`done`) **desaparece**: el éxito navega a `/login` con el aviso (FR-031, R12).

### Estado formulario

| Control | `data-testid` | `autocomplete` | Requisito |
|---|---|---|---|
| Nueva contraseña (`<label for>`, con su propio ojo) | `reset-new-password` | `new-password` | FR-026, FR-017, FR-038 |
| Confirmar contraseña (`<label for>`, con su propio ojo) | `reset-confirm-password` | `new-password` | FR-026, FR-038 |
| Lista de requisitos (`aria-live="polite"`) | `reset-policy-list` | — | FR-027, FR-028 |
| Guardar contraseña | `reset-submit` | — | US3-1 |
| Error (`role="alert"`) | `reset-error` | — | FR-030, FR-041 |

Cada ítem de la lista expone: ícono (`check` / `circle`), etiqueta de la regla, y sufijo para
lectores de pantalla (`(cumplido)` / `(pendiente)`) — **nunca solo color** (FR-028).

### Estado enlace no válido

| Elemento | `data-testid` | Requisito |
|---|---|---|
| Mensaje "Este enlace ya no es válido" | `reset-invalid` | FR-032 |
| Botón "Solicitar un enlace nuevo" → `/forgot-password` | `reset-request-new` | FR-032 |
| **Ningún** `<form>` en el DOM | — | FR-032 |

### Comportamiento

| # | Dado | Entonces | Requisito |
|---|---|---|---|
| N1 | Carga con enlace vigente | se renderiza el formulario y el enlace **no se consume** | FR-034 |
| N2 | Carga sin `token` en la URL | estado "no válido", **sin** petición | *edge case* |
| N3 | Carga con enlace vencido / usado / invalidado / inexistente | un único mensaje "Este enlace ya no es válido" para los cuatro | FR-032 |
| N4 | Contraseña que no cumple la política | error y **cero** peticiones | FR-029, US3-5 |
| N5 | Confirmación distinta | error de no coincidencia y **cero** peticiones | FR-030 |
| N6 | Contraseña igual a la actual | se muestra el error que devuelve el servidor; la contraseña no cambia | FR-033, US3-7 |
| N7 | Cambio exitoso | se navega a `/login` y allí aparece "Contraseña actualizada" | FR-031 |
| N8 | Al escribir en "Nueva contraseña" | cada regla actualiza su estado y el cambio se anuncia | FR-027, FR-028 |
| N9 | Contexto `UNRECOGNIZED` | aviso del cascarón, **sin** llamar a la validación del token | FR-009, R6 |

---

## 5. Accesibilidad, como contrato verificable

| # | Regla | Dónde se comprueba | Requisito |
|---|---|---|---|
| A1 | Todo campo tiene `<label for>` apuntando al `id` de su control | test unitario por pantalla | FR-038 |
| A2 | El orden del DOM es el orden visual; no se usa `tabindex` positivo en ninguna parte | test + revisión | FR-039 |
| A3 | Todo control enfocable muestra indicador de foco visible (`focus-visible`, nunca `outline:none` sin reemplazo) | auditoría | FR-039 |
| A4 | Todo control se activa con teclado — incluido el ojo de la contraseña, que deja de tener `tabindex="-1"` | test + recorrido manual | FR-040, R9 |
| A5 | Errores en `role="alert"`; estados y avisos en `role="status"` con `aria-live` | test unitario | FR-041 |
| A6 | Contraste AA en texto, bordes de campo y textos de ayuda | auditoría Lighthouse | FR-042, SC-005 |
| A7 | Área de activación ≥ 44 × 44 px en controles interactivos | revisión de estilos | FR-043 |
| A8 | El estado de los requisitos no se comunica solo por color | test unitario | FR-028 |

---

## 6. Contrato HTTP: lo que **no** cambia (FR-044)

Verificable por diferencia: ninguno de estos artefactos de `pos-backend` se toca.

| Endpoint | Método | Petición | Respuesta |
|---|---|---|---|
| `/api/v1/auth/login` | POST | `{ email, password }` | `{ message, access_token, refresh_token, user }` |
| `/api/v1/auth/forgot-password` | POST | `{ email }` | mensaje genérico (igual exista o no la cuenta) |
| `/api/v1/auth/reset-password/validate` | GET | `?token=…` | `200 { valid: true }` \| `400/404 { valid: false, reason }` |
| `/api/v1/auth/reset-password` | POST | `{ token, new_password }` | 2xx \| error |

**Cabeceras**: `X-Tenant-Host` la sigue añadiendo el interceptor existente a todas las
peticiones hacia `apiBaseUrl`, incluidas las no autenticadas de este flujo. No se añade,
elimina ni modifica ninguna cabecera.

**Códigos que la interfaz interpreta** (mapeo nuevo, servidor intacto):

| Endpoint | Código | Lo que muestra la pantalla |
|---|---|---|
| login | `401` | "Credenciales inválidas" |
| login | `403` | "Credenciales inválidas" ← **cambio**: hoy muestra "User account is inactive" (R7) |
| forgot-password | `429` | mensaje de demasiados intentos (literal propio de la pantalla, R11) |
| reset-password/validate | `400`, `404` | "Este enlace ya no es válido" (los cuatro motivos colapsan, FR-032) |

**⚠️ Límite conocido del contrato**: `…/validate` y `…/reset-password` resuelven el token **solo
por su hash**, sin mirar el tenant ni `X-Tenant-Host`. Por eso **FR-037 no es verificable contra
este contrato** y queda como hallazgo pendiente de decisión — ver **R18** de research y la
entrada A-111 del registro de anomalías.
