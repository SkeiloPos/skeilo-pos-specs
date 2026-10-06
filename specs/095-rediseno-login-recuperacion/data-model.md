# Data Model — Fase 1: Rediseño unificado de inicio de sesión y recuperación de contraseña

**Spec**: [spec.md](./spec.md) | **Research**: [research.md](./research.md) | **Fecha**: 2026-10-05

## 0. Lo primero, porque cambia cómo se lee este documento

**Esta spec no tiene modelo de datos persistido.** No hay entidades nuevas, ni campos nuevos,
ni relaciones nuevas, ni valores por defecto nuevos, ni migración, ni rollback de datos. El
Principio VIII (Evolución del Modelo de Datos) **no aplica** porque no hay evolución de modelo
que especificar: FR-044 deja el servidor exactamente como está y la totalidad del trabajo
ocurre en `pos-heladeria`.

Lo que sí hay son **cuatro estructuras de cliente** —tres nuevas y una existente que se
reutiliza— y **un estado efímero en el navegador** (60 segundos en `sessionStorage`). Eso es lo
que este documento modela. Las entidades que la spec nombra en _Key Entities_ se mapean así:

| _Key Entity_ de la spec | Dónde vive | Sección |
|---|---|---|
| Contexto del acceso | `TenantContext` — **ya existe**, spec 091 | §1 |
| Política de contraseñas | `PASSWORD_RULES` — nueva, derivada de spec 031 FR-019 | §2 |
| Bloqueo de reenvío | `ResendLock` — nueva, sobre `sessionStorage` | §3 |
| Enlace de recuperación | `ResetLinkState` — estado derivado del servidor | §4 |
| *(no está en la spec, lo exige FR-031)* | `AuthNotice` — aviso de un solo uso entre rutas | §5 |

---

## 1. Contexto del acceso — `TenantContext` (existente, no cambia)

Definido en `pos-heladeria/src/app/core/tenant/tenant-context.model.ts`. Es una unión
discriminada, así que los estados inválidos no se pueden representar: un `TENANT` siempre trae
`slug` y los otros dos nunca lo traen.

```
TenantContext =
  | { kind: 'SUPER_ADMIN';            hostname: string }
  | { kind: 'TENANT';  slug: string;  hostname: string }
  | { kind: 'UNRECOGNIZED';           hostname: string }
```

**Ciclo de vida**: lo fija **una sola vez** el inicializador de arranque
(`provideTenantInitializer()`), de forma síncrona y sin ninguna petición;
`TenantContextService.initialize()` lanza si se llama dos veces. Esa propiedad es la que hace
cumplir FR-007a (sin consultar al servidor) y FR-007c (sin estado de carga ni cambio
posterior) **por construcción**: cuando la primera plantilla se evalúa, el valor ya es
definitivo.

**Proyección a la etiqueta de contexto** (FR-007, FR-007d, FR-008, FR-009; derivada en el
cascarón, ver R5):

| `kind` | Texto de la etiqueta | Ícono | Formulario |
|---|---|---|---|
| `TENANT` | `slug`, **sin transformar** | `store` (genérico) | sí |
| `SUPER_ADMIN` | `"Administración de la plataforma"` | `shield` o equivalente genérico | sí |
| `UNRECOGNIZED` | *(ninguna)* | — | **no**, y sin peticiones |

**Invariantes verificables**:
- `etiqueta(TENANT) === context.slug` carácter por carácter — ni `titlecase`, ni guiones
  reemplazados, ni recortes (FR-007). El truncado visual es CSS (`truncate` + `title`), de modo
  que el valor del DOM sigue siendo el slug completo.
- `etiqueta(SUPER_ADMIN)` no contiene ningún slug de negocio (FR-008).
- Con `UNRECOGNIZED` no existe ningún `<form>` en el documento y **ninguna** petición sale
  hacia `apiBaseUrl` (FR-009), en las tres pantallas (R6).

**Fuente única** (FR-010): la clasificación del host la hace el resolvedor de la spec 091. Esta
spec **lee** `isTenant()` / `isSuperAdmin()` / `isUnrecognized()` / `tenantSlug()` y no
introduce ninguna segunda lectura de `window.location`.

---

## 2. Política de contraseñas — `PASSWORD_RULES` (nueva, una sola fuente)

Nueva en `pos-heladeria/src/app/modules/auth/password-policy.ts`. Modela la política vigente de
la spec 031 (FR-019) y es la **única** fuente de la que salen los validadores del formulario y
la lista visible (R13).

```
PasswordRule = {
  readonly label: string;              // texto visible, p. ej. "Mínimo 8 caracteres"
  readonly test: (v: string) => boolean;
}

PASSWORD_RULES: readonly PasswordRule[]
PASSWORD_MIN_LENGTH = 8
PASSWORD_MAX_LENGTH = 12
```

| Regla | `label` | `test` |
|---|---|---|
| 1 | `"Mínimo 8 caracteres"` | `v.length >= 8` |
| 2 | `"Máximo 12 caracteres"` | `v.length <= 12` |

**Estado derivado por regla** (lo consume la lista de FR-027/FR-028):

| Campo | Valor | Para qué |
|---|---|---|
| `met` | `rule.test(value)` | decide ícono y texto |
| `icon` | `met ? 'check' : 'circle'` | FR-028: señal no cromática |
| `srSuffix` | `met ? '(cumplido)' : '(pendiente)'` | FR-028: anuncio a ayudas técnicas |

**Invariantes verificables**:
- **La lista y el validador no pueden discrepar**: `form.valid` ⟺ todas las reglas de
  `PASSWORD_RULES` cumplidas (sobre el campo de contraseña nueva, ignorando la confirmación).
  Es un test, no una convención.
- La regla 2 **existe y se muestra**: D4 de la spec obliga a mostrar el máximo que el mockup
  omite, porque sin él un rechazo a los 13 caracteres es inexplicable.
- `PASSWORD_RULES` **no** contiene "distinta de la actual" (FR-033): el cliente no conoce la
  contraseña actual y no puede evaluarla; ese requisito lo comprueba el servidor al enviar y
  llega como error de respuesta.
- Ninguna regla exige mayúsculas, números ni símbolos (FR-029, D4 de la spec).

**Compatibilidad**: la política no cambia. Si en el futuro el servidor endurece la política,
este módulo es el único punto que hay que mover, y mover solo él mantiene lista y validación
sincronizadas.

---

## 3. Bloqueo de reenvío — `ResendLock` (nueva, efímera en el navegador)

Único estado que esta spec escribe fuera de la memoria del componente.

| Propiedad | Valor |
|---|---|
| Medio | `sessionStorage` |
| Clave | `skeilo.auth.resend-lock-until` |
| Valor | instante de vencimiento en milisegundos epoch, como texto decimal |
| Duración | 60 000 ms desde la solicitud aceptada (FR-021) |
| Alcance | la pestaña; se borra al cerrarla |
| Datos personales | **ninguno** — un número, nunca el correo (R10) |

**Estado derivado que ve la pantalla**:

```
remainingSeconds = max(0, ceil((until - Date.now()) / 1000))
blocked          = remainingSeconds > 0
```

**Transiciones**:

| Desde | Evento | Hacia |
|---|---|---|
| sin bloqueo | solicitud aceptada (2xx) | `until = Date.now() + 60000`, escrito en `sessionStorage` |
| bloqueado | cada segundo (repintado) | mismo `until`, `remainingSeconds` menor |
| bloqueado | recarga de la pantalla | se relee `until`; sigue bloqueado por lo que falte (FR-022) |
| bloqueado | `remainingSeconds === 0` | control habilitado; la clave puede quedar o borrarse, da igual |
| cualquiera | respuesta `429` del servidor | el bloqueo **no** se reinicia: el mensaje de FR-023 es independiente |

**Invariantes verificables**:
- El cálculo usa **dos marcas de reloj**, nunca un contador decrementado por tick: una pestaña
  en segundo plano 70 s vuelve con el control **habilitado**, no con 55 s pendientes (FR-022).
- Recargar durante el bloqueo **no** lo reinicia a 60 (FR-022).
- Si `sessionStorage` no está disponible o trae basura, se trata como "sin bloqueo" y la
  pantalla funciona igual: el bloqueo es una ayuda de interfaz, y el límite real es el del
  servidor (FR-024, 3 solicitudes / 900 s por negocio y cuenta).

**Lo que este estado explícitamente no es**: un control de seguridad. D6 y FR-024 de la spec lo
subordinan al límite del servidor, que sigue aplicándose sin cambios.

---

## 4. Enlace de recuperación — `ResetLinkState` (estado del servidor, solo se consume)

La entidad persistida (`PasswordResetToken` en `pos-backend`) **no cambia**. La pantalla solo
observa el estado que el servidor le reporta y decide qué renderiza.

| Estado observado | Cómo llega | Qué se renderiza |
|---|---|---|
| vigente | `200 { valid: true }` | el formulario de contraseña nueva (FR-026) |
| vencido | `400 { valid: false, reason: 'expired' }` | "Este enlace ya no es válido" + "Solicitar un enlace nuevo" (FR-032) |
| ya usado | `400 { … reason: 'used' }` | ídem |
| invalidado por una solicitud posterior | `400 { … reason: 'invalid' }` | ídem |
| inexistente | `404 { … reason: 'invalid' }` | ídem |
| **sin parámetro `token` en la URL** | no se emite petición | ídem (*edge case* de la spec) |
| host no reconocido | **no se emite petición** (R6) | aviso de FR-009 |

**Decisión de presentación**: los cuatro estados no vigentes colapsan en **un solo mensaje**,
"Este enlace ya no es válido", como fija FR-032. Hoy el componente muestra tres textos
distintos según `reason` (`reset-password.component.ts:26-30`); la spec pide uno. El `reason`
se sigue leyendo, pero ya no se traduce a texto visible — se conserva solo como dato de
diagnóstico. No se pierde nada que el usuario pueda accionar: la acción es la misma en los
cuatro casos.

**Invariantes verificables**:
- La validación de carga **no consume** el enlace (FR-034): el `GET …/validate` no tiene efecto
  secundario (verificado en `routes.py:302-314`), de modo que el usuario puede escribir su
  contraseña y enviarla con el mismo enlace.
- Con el enlace no vigente **no existe** el formulario en el DOM (FR-032), no solo está oculto.
- ⚠️ **Lo que no se puede afirmar**: que un enlace abierto en el subdominio de otro negocio sea
  inválido (FR-037). El token se resuelve solo por su hash, sin mirar el host — ver **R18** de
  research. Queda como hallazgo pendiente de decisión, no como invariante.

---

## 5. Aviso entre rutas — `AuthNotice` (nueva, un solo uso)

Lo exige FR-031: el éxito del cambio de contraseña debe aparecer **en el inicio de sesión**, no
en la pantalla de reset.

```
AuthNotice = 'password-updated'     // hoy, un único valor
```

| Propiedad | Comportamiento |
|---|---|
| Dónde vive | `AuthNoticeService` (`core/auth/auth-notice.service.ts`), signal en memoria |
| Quién lo fija | `reset-password` tras un cambio exitoso, antes de navegar a `/login` |
| Quién lo lee | `login` al montarse, una sola vez |
| Tras leerse | queda vacío: una recarga de `/login` **no** repite el aviso |
| Si se entra a `/login` directo | no hay aviso; nada se muestra |
| En la URL | **nada**: no se puede fabricar desde fuera (R12) |

**Presentación**: texto `"Contraseña actualizada"` (FR-031) dentro de una región
`role="status"` para que se anuncie al aparecer (FR-041).

---

## 6. Configuración — un campo nuevo en `AppEnvironment`

| Campo | Tipo | `environment.ts` | `environment.development.ts` | Para qué |
|---|---|---|---|---|
| `publicSiteUrl` | `string` | `https://skeilopos.com` | `https://skeilopos.com` | FR-003 (Política de privacidad) y FR-009 (enlace al sitio principal) |

Mismo valor en los dos entornos **a propósito**: el sitio público es el mismo se ejecute la
aplicación donde se ejecute, y derivarlo de `rootDomain` daría `http://localhost/privacidad` en
desarrollo (R14). La interfaz `AppEnvironment` existe precisamente para que los dos ficheros no
deriven, así que el campo se añade allí como `readonly`.

**Verificado**: `skeilo-pos-landing/src/pages/privacidad.astro` y la portada existen — FR-003a
se cumple enlazando, sin crear páginas nuevas.

---

## 7. Lo que explícitamente no cambia

| | |
|---|---|
| Esquema de base de datos | nada: ni tabla, ni columna, ni índice, ni valor por defecto |
| Migraciones | ninguna, por lo anterior |
| Endpoints | ninguno nuevo ni modificado (FR-044) |
| Contratos de petición/respuesta | `LoginRequest`, `ForgotPasswordRequest`, `ResetPasswordRequest`, `ValidateResetTokenResponse`: idénticos |
| Vida de los tokens de sesión | acceso 1 día, refresco 7 días — el control "Mantener sesión iniciada" **no** los toca (FR-019b) |
| Parámetros enviados al autenticar | solo `email` y `password`; el control inerte **no** se envía (FR-019c) |
| Lo que se guarda del usuario en el navegador | tokens, como hoy; **ninguna** contraseña ni dato derivado (FR-019d) |
| Política de contraseñas | 8 a 12, sin combinaciones obligatorias (FR-029) |
| Límite de solicitudes | 3 por 900 s, por negocio y cuenta (FR-024) |
| Garantías del enlace | un solo uso, 30 minutos, cierra sesiones, distinta de la actual (FR-033) |
| Aislamiento por negocio en la solicitud de enlace | ya correcto: `User.tenant_id == tenant.id` (FR-035, FR-036) |
| Roles y destinos tras iniciar sesión | `ROLE_HOME` intacto (FR-018, FR-019) |

**Rollback**: revertir los commits de `pos-heladeria`. No hay dato que deshacer; lo único que
puede quedar escrito es la clave de `sessionStorage` del bloqueo de reenvío, que caduca al
cerrar la pestaña y que ninguna versión anterior lee.
