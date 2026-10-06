---
description: "Lista de tareas de implementación — spec 095"
---

# Tasks: Rediseño unificado de inicio de sesión y recuperación de contraseña

**Input**: Documentos de diseño de `/specs/095-rediseno-login-recuperacion/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: **sí se generan.** No es una elección de estilo: el Principio X los exige para el
comportamiento nuevo, y R17 encontró que `forgot-password` y `reset-password` **no tienen
ningún test hoy**, de modo que son el único sitio donde FR-020 a FR-034 se pueden verificar.

**Organización**: por historia de usuario, para que cada una se implemente y se pruebe sola.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: se puede ejecutar en paralelo (archivo distinto, sin dependencias pendientes)
- **[Story]**: a qué historia pertenece (US1, US2, US3, US4)
- Cada tarea lleva su ruta exacta

## Path Conventions

Dos repositorios hermanos, y **solo uno se toca**:

- `pos-specs/` — este repositorio, rama `main`. Aquí viven la spec y el registro de anomalías.
- `pos-heladeria/` — el frontend Angular, rama **`style/095-auth-screens-redesign`**. Aquí va
  todo el código.
- `pos-backend/` — **no se toca** (FR-044). Su `git status` tiene que quedar limpio.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: dejar la rama creada y la línea base medida antes de tocar nada

- [X] T001 Crear y cambiar a la rama `style/095-auth-screens-redesign` en `pos-heladeria/`, partiendo de `develop` (Principio XIV; hoy el repositorio está en `develop`)
- [X] T002 Medir la línea base de la suite con `cd pos-heladeria && git stash && npm test 2>&1 | tail -30 && git stash pop` y anotar el conteo de fallos preexistentes para compararlo en T061 (quickstart.md §0 — la suite arrastra fallos ajenos a autenticación)
- [X] T003 [P] Añadir a `/etc/hosts` los hosts de prueba `negocioa.localhost`, `negociob.localhost`, `admin.localhost`, `www.localhost` e `inventado.localhost` según quickstart.md §0 (sin ellos no se puede validar ninguna etiqueta: `localhost` pelado es `UNRECOGNIZED` a propósito)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: la puerta documental G1, la configuración, el activo, el componente compartido y el
cascarón del que cuelgan las tres pantallas

**⚠️ CRITICAL**: ninguna historia puede empezar hasta que esta fase esté completa. T004 a T007
son **bloqueantes por constitución**, no por conveniencia: el Principio II exige registrar todo
cambio de comportamiento existente **antes** de implementarlo.

### Puerta G1 — Registro de anomalías (bloquea escribir código)

Las cuatro entradas van en el **mismo archivo**, así que son secuenciales. El último código
usado es A-107 (verificado), de modo que la numeración arranca en A-108.

- [X] T004 Escribir la entrada **A-108** en `pos-specs/specs/000-reconocimiento/registro-de-anomalias.md`: el `403` de cuenta desactivada deja de distinguirse del `401` y ambos se muestran como "Credenciales inválidas" — clasificación DECISIÓN, origen FR-012/SC-003/R7, con la evidencia de `pos-backend/app/api/v1/auth/routes.py:164,188,193`
- [X] T005 Escribir la entrada **A-109** en `pos-specs/specs/000-reconocimiento/registro-de-anomalias.md`: los dos textos de la spec 091 cambian — "Acceso Super Admin" → "Administración de la plataforma" (D8) y "Esta dirección no corresponde a ningún acceso" → "No encontramos este negocio" (D7) — clasificación DECISIÓN, origen R16
- [X] T006 Escribir la entrada **A-110** en `pos-specs/specs/000-reconocimiento/registro-de-anomalias.md`: el éxito del cambio de contraseña deja de quedarse en su pantalla y pasa a `/login` con el aviso, y el aviso de host no reconocido se extiende a `/forgot-password` y `/reset-password` — clasificación DECISIÓN, origen FR-031/FR-009/R6/R12
- [X] T007 Escribir la entrada **A-111** en `pos-specs/specs/000-reconocimiento/registro-de-anomalias.md`: **HALLAZGO** — el enlace de recuperación se resuelve solo por el hash del token, sin mirar el host, así que FR-037 no se puede cumplir sin modificar dos endpoints, que FR-044 prohíbe; clasificación HALLAZGO, origen R18, con la evidencia de `pos-backend/app/api/v1/auth/routes.py:68-94,302,317` y la recomendación del plan (aceptar la limitación). **Deja abierta la puerta G2**

### Configuración y activos

- [X] T008 [P] Añadir el campo `readonly publicSiteUrl: string` con su comentario a `pos-heladeria/src/app/core/tenant/app-environment.interface.ts` (R14; FR-003, FR-009)
- [X] T009 Fijar `publicSiteUrl: 'https://skeilopos.com'` en `pos-heladeria/src/environments/environment.ts` y en `pos-heladeria/src/environments/environment.development.ts` — **el mismo valor en los dos a propósito**: derivarlo de `rootDomain` daría `http://localhost/privacidad` en desarrollo (R14) (depende de T008)
- [X] T010 [P] Convertir la vista previa del mockup (`~/Escritorio/SkeiloPOS App diseñada/uploads/pasted-1791030235876-0.png`, 1365×828, 140 KB; `cwebp` ya está instalado) a WebP y publicarla en `pos-heladeria/public/images/auth-preview.webp` con un presupuesto de **≤ 80 KB** (R2; referencia: `dashboard-main.webp` pesa 58 KB a 1599×1199)

### Componentes compartidos

- [X] T011 [P] En `pos-heladeria/src/app/shared/password-input/password-input.component.ts`: quitar el `tabindex="-1"` del botón de visibilidad (línea 46) y añadir un método público `focus()` que delegue en un `viewChild` del `<input>` interno — dos cambios mínimos y aditivos que arreglan un incumplimiento de WCAG 2.1.1 en las 5 pantallas que usan el componente (R8, R9; FR-040, FR-013)
- [X] T011a [P] Verificar en `pos-heladeria/src/app/shared/password-input/password-input.component.ts` que el botón de visibilidad anuncia **la acción que ejecutará**, no solo su estado: `aria-pressed` comunica estado, y FR-016 pide la acción. Si el nombre accesible actual no la expresa, añadir `[attr.aria-label]` alternando "Mostrar contraseña" / "Ocultar contraseña", con su aserción en el spec del componente (FR-016, A4)
- [X] T012 [P] Crear `pos-heladeria/src/app/core/auth/auth-notice.service.spec.ts`: el aviso se fija con `set()`, se lee con `consume()` **una sola vez**, y una segunda lectura devuelve vacío (R12; FR-031)
- [X] T013 Crear `pos-heladeria/src/app/core/auth/auth-notice.service.ts` como signal en memoria con `set(notice)` / `consume()`, con el único valor `'password-updated'` — nada en la URL, para que el aviso no se pueda fabricar desde fuera (R12, data-model.md §5) (depende de T012)

### Estilos y cascarón

- [X] T014 Añadir en `pos-heladeria/src/styles.css` la regla del fondo del panel de marca —`background-image: url('/images/auth-preview.webp')`— **dentro** de un `@media (min-width: 1024px)`, nunca como `<img>`: un estilo que no aplica no se solicita, y eso es lo único que cumple FR-005 sin JavaScript (R2) (depende de T010)
- [X] T015 Crear `pos-heladeria/src/app/modules/auth/components/auth-shell.component.spec.ts` cubriendo las garantías C1 a C8 del contrato: orden fijo de la columna izquierda (FR-002), etiqueta `storefront` + slug sin transformar en `TENANT`, "Administración de la plataforma" en `SUPER_ADMIN`, con `UNRECOGNIZED` ni etiqueta ni contenido proyectado y **cero** peticiones, pie con `new Date().getFullYear()` y enlace de privacidad — con un doble de `TenantContextService` para los tres contextos, como hace `login.component.spec.ts`
- [X] T016 Crear `pos-heladeria/src/app/modules/auth/components/auth-shell.component.ts` (standalone, `OnPush`, selector `app-auth-shell`): rejilla de dos columnas desde 1024 px, logotipo `[data-testid="auth-brand-logo"]`, etiqueta `[data-testid="auth-context-badge"]` derivada de `TenantContextService` (íconos `storefront` y `admin_panel_settings` del `ICON_CATALOG`, con `max-w-[16rem] truncate` y el slug completo en `title`), `<ng-content>` para la pantalla, y la rama `UNRECOGNIZED` que renderiza `[data-testid="unrecognized-host"]` y **no proyecta** el contenido. **El cascarón lee el contexto, no lo clasifica** (FR-010), y **no emite ninguna petición** (R5, R6) (depende de T015)
- [X] T017 Completar `pos-heladeria/src/app/modules/auth/components/auth-shell.component.ts` con el pie `[data-testid="auth-footer"]` ("© {año} SkeiloPOS" + "Política de privacidad" → `{publicSiteUrl}/privacidad`) y el panel `[data-testid="auth-brand-panel"]` con el lema "Tu negocio. Más rápido." y su texto de apoyo **como texto HTML real, no imagen** (FR-003, FR-004, FR-042) (depende de T009, T014, T016)

**Checkpoint**: el cascarón se prueba solo, en los tres contextos de host. Las tres historias pueden arrancar.

---

## Phase 3: User Story 1 - Entrar al sistema desde el subdominio del negocio (Priority: P1) 🎯 MVP

**Goal**: la pantalla de entrada de todos los días, dentro del cascarón, con un único mensaje de
fallo, el foco donde debe estar y un control inerte que no miente.

**Independent Test**: abrir el subdominio de un tenant, enviar credenciales válidas y llegar a la
pantalla de destino con la presentación nueva — sin tocar el flujo de recuperación.

### Tests for User Story 1 ⚠️

> Escribir estos tests **antes** de la implementación y comprobar que fallan.

- [X] T018 [US1] Actualizar en `pos-heladeria/src/app/modules/auth/pages/login.component.spec.ts` **exactamente dos** expectativas de la spec 091 (líneas 64-103): "Acceso Super Admin" → "Administración de la plataforma" y "Esta dirección no corresponde a ningún acceso" → "No encontramos este negocio". **Las aserciones de "sin formulario" y "sin llamada al API" quedan intactas** — es lo que esos tests protegen de verdad (R16, A-109)
- [X] T019 [US1] Ampliar `pos-heladeria/src/app/modules/auth/pages/login.component.spec.ts` con los comportamientos L1 a L10 del contrato: campos vacíos → error por campo y **cero** peticiones; `401` **y** `403` → el mismo literal "Credenciales inválidas"; tras el rechazo contraseña vacía y enfocada con el correo conservado; una sola petición aunque se pulse varias veces; destino previo, `ROLE_HOME` y contraseña temporal intactos; el cuerpo del `POST` es **exactamente** `{ email, password }` con la casilla marcada; y las aserciones de accesibilidad A1 y A5 (cada campo con su `<label for>`, error en `role="alert"`, aviso en `role="status"`)
- [X] T019a [US1] Añadir a `pos-heladeria/src/app/modules/auth/pages/login.component.spec.ts` el comportamiento **L11**: con los dos campos rellenados por el navegador sin eventos de teclado —`input.value` fijado y `dispatchEvent(new Event('input'))`—, el botón de envío queda **habilitado** y la validación **no** marca los campos como vacíos (edge case "Autocompletado del navegador al cargar"). Añadir la fila L11 a `contracts/auth-shell-contract.md` §2
- [X] T020 [P] [US1] Añadir en `pos-heladeria/src/app/core/services/auth.service.spec.ts` el test del mapeo del login: tanto `401` como `403` producen "Credenciales inválidas", y `extractError()` **no cambia** para `changePassword`, `forgotPassword` ni `resetPassword`

### Implementation for User Story 1

- [X] T021 [US1] En `pos-heladeria/src/app/core/services/auth.service.ts`, mapear en el camino de `login()` tanto el `401` como el `403` al literal "Credenciales inválidas", **sin tocar `extractError()`**, que comparten los otros tres flujos y donde ese texto no tendría sentido (R7; FR-012, SC-003)
- [X] T022 [US1] Reescribir la plantilla de `pos-heladeria/src/app/modules/auth/pages/login.component.ts` para envolverla en `<app-auth-shell>`, eliminando su layout de dos columnas y su panel decorativo propios, con los literales del contrato de textos ("Bienvenido de nuevo.", "Inicia sesión para acceder a tu cuenta.", "Correo electrónico", "Iniciar sesión", "Ingresando…") y los `data-testid` del contrato §2 (`login-email`, `login-password`, `login-forgot-link`, `login-submit`, `login-error`), con `autocomplete="email"` y `autocomplete="current-password"` (FR-011, FR-011a, FR-017, FR-038). **Conservar** al reescribir: la validación de obligatoriedad sin petición (FR-014), el destino previo y el `ROLE_HOME` (FR-018, FR-019) y la rama de contraseña temporal — T019 y T020 los protegen con tests, pero la plantilla se reescribe entera
- [X] T023 [US1] Añadir en `pos-heladeria/src/app/modules/auth/pages/login.component.ts` la casilla `[data-testid="login-keep-session"]` con su `<label for>` y el texto **"Mantener sesión iniciada"**: estado local y nada más — no entra en ningún `FormGroup` que se serialice, no viaja al servidor, no persiste nada y su texto no menciona contraseñas (FR-019a a FR-019e, D3a)
- [X] T024 [US1] Implementar FR-013 en `pos-heladeria/src/app/modules/auth/pages/login.component.ts`: en la rama de error de `submit()`, `form.controls.password.reset('')`, dejar `email` intacto y mover el foco al campo con un `viewChild` sobre el `app-password-input` llamando al `focus()` que T011 añadió (R8)
- [X] T025 [US1] Garantizar en `pos-heladeria/src/app/modules/auth/pages/login.component.ts` que mientras la petición está en curso el botón queda deshabilitado con indicador de progreso visible y **no sale una segunda petición** aunque se pulse varias veces (FR-015, SC-009)
- [X] T025a [US1] Manejar el fallo de red en `pos-heladeria/src/app/modules/auth/pages/login.component.ts`: el botón sale del estado de carga, aparece "No pudimos procesar la solicitud. Intenta de nuevo." en `[data-testid="login-error"]` y se puede reintentar, sin dejar el formulario bloqueado de forma permanente — mismo literal que T032, que ya está en el contrato de textos (edge case "Pérdida de conexión durante el envío")
- [X] T026 [US1] Consumir `AuthNoticeService` al montar `pos-heladeria/src/app/modules/auth/pages/login.component.ts` y renderizar "Contraseña actualizada" en `[data-testid="login-notice"]` dentro de una región `role="status"`, dejando el aviso vacío tras leerlo para que una recarga **no** lo repita (FR-031, FR-041, R12)

**Checkpoint**: la Historia 1 funciona y se prueba sola. Es el MVP: si esto está bien, nadie deja de trabajar.

---

## Phase 4: User Story 2 - Recuperar el acceso cuando olvidé la contraseña (Priority: P2)

**Goal**: pedir el enlace con un mensaje que no revela si la cuenta existe, y un bloqueo de
reenvío que ni se alarga ni se elude.

**Independent Test**: pedir un enlace desde la pantalla de solicitud y verificar el mensaje
genérico, la cuenta regresiva y el mensaje de límite excedido — sin ejecutar el cambio de
contraseña.

### Tests for User Story 2 ⚠️

- [X] T027 [P] [US2] Crear `pos-heladeria/src/app/modules/auth/pages/forgot-password.component.spec.ts` (**hoy no existe**, R17) con los comportamientos F1 a F8: el mismo mensaje genérico exista o no la cuenta; tras aceptar, reenvío bloqueado 60 s con cuenta regresiva visible; con la clave de `sessionStorage` ya puesta, al montar sigue bloqueado por lo que falte; con un instante de vencimiento ya pasado, habilitado; `429` → el literal de demasiados intentos; fallo de red → el botón sale del estado de carga; "Volver a iniciar sesión" como ruta **relativa**; y con `UNRECOGNIZED` ni formulario ni petición

### Implementation for User Story 2

- [X] T028 [US2] Reescribir `pos-heladeria/src/app/modules/auth/pages/forgot-password.component.ts` envolviéndola en `<app-auth-shell>` —deja de ser una tarjeta centrada sin etiqueta, sin pie y sin marca— con sus dos estados mutuamente excluyentes (formulario y confirmación), los literales del contrato ("Restablece tu contraseña.", "Enviar enlace", "Revisa tu correo.") y los `data-testid` del contrato §3 (`forgot-email`, `forgot-submit`, `forgot-back-link`, `forgot-error`, `forgot-sent`, `forgot-resend`), con `<label for>` y `autocomplete="email"` (FR-001, FR-002, FR-038)
- [X] T029 [US2] Redactar el mensaje de confirmación de `pos-heladeria/src/app/modules/auth/pages/forgot-password.component.ts` en **forma condicional** y dentro de `role="status"`: "Si existe una cuenta con {correo}, enviamos un enlace para crear una contraseña nueva. El enlace caduca en 30 minutos." — el indicativo del mockup ("Enviamos un enlace a…") afirma que la cuenta existe y rompe FR-020 y SC-003
- [X] T030 [US2] Implementar el bloqueo de reenvío en `pos-heladeria/src/app/modules/auth/pages/forgot-password.component.ts`: al aceptarse la solicitud, escribir `Date.now() + 60_000` en `sessionStorage` bajo `skeilo.auth.resend-lock-until`; mostrar `Math.ceil((until - Date.now()) / 1000)` con un `setInterval` de 1 s **que solo repinta**; releer la clave al montar. **Dos marcas de reloj, nunca un contador de ticks**: así ni se alarga con la pestaña en segundo plano ni se reinicia al recargar. Si `sessionStorage` falla o trae basura, se trata como "sin bloqueo" (R10; FR-021, FR-022)
- [X] T031 [US2] Mapear el `429` en `pos-heladeria/src/app/modules/auth/pages/forgot-password.component.ts` al literal propio "Hiciste demasiados intentos. Vuelve a intentarlo más tarde.", **sin repetir el `detail` del backend y sin citar ninguna ventana de tiempo** — el límite es configurable y el texto tiene que seguir siendo verdad si cambia (R11, D5; FR-023)
- [X] T032 [US2] Manejar el fallo de red en `pos-heladeria/src/app/modules/auth/pages/forgot-password.component.ts`: el botón sale del estado de carga, aparece "No pudimos procesar la solicitud. Intenta de nuevo." y se puede reintentar, sin dejar el formulario bloqueado (edge case F6)
- [X] T033 [US2] Cablear "Volver a iniciar sesión" en los dos estados de `pos-heladeria/src/app/modules/auth/pages/forgot-password.component.ts` con `routerLink="/login"` **relativo, nunca un host absoluto**, para que se quede en el subdominio actual (FR-025, F7)

**Checkpoint**: Historias 1 y 2 funcionan, cada una por su lado.

---

## Phase 5: User Story 3 - Crear una contraseña nueva desde el enlace recibido (Priority: P2)

**Goal**: la lista de requisitos y el validador salen del mismo módulo —o terminan discrepando—,
los cuatro motivos de enlace inválido colapsan en uno, y el éxito aterriza en `/login`.

**Independent Test**: abrir la pantalla con un enlace válido, crear una contraseña que cumpla la
política, confirmar que se llega al inicio de sesión con el aviso; y repetir con un enlace
vencido o ya usado.

### Tests for User Story 3 ⚠️

- [X] T034 [P] [US3] Crear `pos-heladeria/src/app/modules/auth/password-policy.spec.ts` con el invariante que hace útil al módulo: **la lista y el validador no pueden discrepar** — `form.valid` ⟺ todas las reglas de `PASSWORD_RULES` cumplidas sobre el campo de contraseña nueva; más que la regla del máximo existe, y que ninguna regla exige mayúsculas, números ni símbolos (data-model.md §2)
- [X] T035 [P] [US3] Crear `pos-heladeria/src/app/modules/auth/pages/reset-password.component.spec.ts` (**hoy no existe**, R17) con los comportamientos N1 a N9: enlace vigente → formulario y el enlace **no se consume**; sin `token` en la URL → estado no válido **sin** petición; vencido/usado/invalidado/inexistente → **un único** mensaje; política incumplida y confirmación distinta → error y **cero** peticiones; éxito → `AuthNotice` fijado y navegación a `/login`; al escribir, cada regla actualiza su estado con ícono **y** texto (A8); y con `UNRECOGNIZED`, **sin** llamar a la validación del token

### Implementation for User Story 3

- [X] T036 [P] [US3] Crear `pos-heladeria/src/app/modules/auth/password-policy.ts` exportando `PASSWORD_MIN_LENGTH = 8`, `PASSWORD_MAX_LENGTH = 12` y `PASSWORD_RULES` con las dos reglas de la política vigente ("Mínimo 8 caracteres" / `v.length >= 8` y "Máximo 12 caracteres" / `v.length <= 12`). **No incluye "distinta de la actual"**: el cliente no conoce la contraseña actual y fingir que la comprueba sería mentir sobre el estado de un requisito (R13; FR-029, FR-033, D4)
- [X] T037 [US3] Reescribir `pos-heladeria/src/app/modules/auth/pages/reset-password.component.ts` envolviéndola en `<app-auth-shell>` con sus tres estados (verificando, formulario, enlace no válido), los literales del contrato ("Crea tu nueva contraseña.", "Nueva contraseña", "Confirmar contraseña", "Guardar contraseña", "Guardando…") y los `data-testid` del contrato §4 (`reset-new-password`, `reset-confirm-password`, `reset-policy-list`, `reset-submit`, `reset-error`, `reset-invalid`, `reset-request-new`), con `<label for>`, `autocomplete="new-password"` en los dos campos y su propio control de visibilidad cada uno (FR-026, FR-017, FR-038). **Conservar** al reescribir: la validación de obligatoriedad sin petición y el comportamiento de la confirmación — la plantilla se reescribe entera
- [X] T038 [US3] Renderizar la lista de requisitos en `pos-heladeria/src/app/modules/auth/pages/reset-password.component.ts` desde `PASSWORD_RULES`, dentro de un contenedor `aria-live="polite"`, con **ícono + etiqueta + sufijo para lectores** por ítem: `check`/`circle` del `ICON_CATALOG` y "(cumplido)"/"(pendiente)" — **nunca solo color** (FR-027, FR-028)
- [X] T039 [US3] Derivar los validadores del formulario de `pos-heladeria/src/app/modules/auth/pages/reset-password.component.ts` de las mismas `PASSWORD_RULES`, sustituyendo la validación 8–12 escrita a mano de hoy (línea 156), para que la fuente sea una sola (R13; FR-029)
- [X] T040 [US3] Colapsar en `pos-heladeria/src/app/modules/auth/pages/reset-password.component.ts` los cuatro motivos de enlace no vigente (vencido, usado, invalidado, inexistente) en **un solo** texto "Este enlace ya no es válido" con el botón "Solicitar un enlace nuevo", retirando los tres textos distintos de hoy (líneas 26-30). El `reason` se sigue leyendo como dato de diagnóstico, pero ya no se traduce a texto visible, y con el enlace no vigente **no existe `<form>` en el DOM** (FR-032)
- [X] T041 [US3] Evitar en `pos-heladeria/src/app/modules/auth/pages/reset-password.component.ts` la petición de validación en dos casos: cuando el contexto es `UNRECOGNIZED` (R6, N9) y cuando la URL no trae `?token=` (N2) — hoy la pantalla dispararía la validación sin cabecera `X-Tenant-Host` en un host no reconocido
- [X] T042 [US3] Cambiar el éxito de `pos-heladeria/src/app/modules/auth/pages/reset-password.component.ts`: fijar el aviso en `AuthNoticeService` y navegar a `/login`, **eliminando el estado `'done'`** que hoy deja al usuario en la pantalla de reset con un enlace (líneas 62-80) (FR-031, R12, A-110)
- [X] T043 [US3] Validar en `pos-heladeria/src/app/modules/auth/pages/reset-password.component.ts` que la confirmación coincide, mostrando "Las contraseñas no coinciden" en `role="alert"` y **sin emitir la petición de cambio** (FR-030)
- [X] T044 [US3] Mostrar en `pos-heladeria/src/app/modules/auth/pages/reset-password.component.ts` el error que devuelve el servidor cuando la contraseña nueva es igual a la actual, sin inventar un texto propio ni evaluarlo en el cliente (FR-033, N6)
- [X] T044a [US3] Manejar el fallo de red en `pos-heladeria/src/app/modules/auth/pages/reset-password.component.ts`, tanto en la validación del enlace al cargar como en el envío del cambio: el botón sale del estado de carga, aparece "No pudimos procesar la solicitud. Intenta de nuevo." y se puede reintentar; un fallo de red al validar **no** se confunde con "Este enlace ya no es válido", que es un estado distinto (edge case, FR-032)

**Checkpoint**: las tres historias funcionan de forma independiente.

---

## Phase 6: User Story 4 - Usar las pantallas de autenticación en cualquier dispositivo (Priority: P3)

**Goal**: el formulario ocupa el ancho en el celular del negocio, la imagen decorativa no se
descarga donde no se ve, y todo se alcanza con el teclado.

**Independent Test**: redimensionar cada una de las tres pantallas entre 360 px y escritorio, y
auditar la carga de recursos y la accesibilidad por teclado.

> Esta historia es **casi toda verificación**, y eso es deliberado: lo que le falta al rediseño
> en este plano no son líneas de código, sino comprobar que las decisiones estructurales de las
> fases anteriores (el fondo tras la media query, el orden del DOM) se comportan como se diseñó.

### Implementation for User Story 4

- [X] T045 [US4] Asegurar en `pos-heladeria/src/styles.css` el alto efectivo **≥ 44 × 44 px** de los controles interactivos de autenticación (botones, enlaces de acción, casilla y botón del ojo) y un indicador de foco visible con `focus-visible` —**nunca `outline: none` sin reemplazo**— (FR-039, FR-043, A3, A7)

### Verificación de User Story 4

- [X] T046 [P] [US4] Abrir las tres pantallas a 1023 px con la pestaña Red filtrada por `Img` y la caché deshabilitada, y confirmar que **`auth-preview.webp` no aparece en la lista de peticiones** y el panel no se muestra (quickstart.md §6.2; FR-005, SC-007)
- [X] T047 [P] [US4] Barrer las tres pantallas de 360 px a 1920 px y confirmar cero desplazamiento horizontal, con formulario y pie completos y alcanzables en todo el rango (quickstart.md §6.3-6.4; FR-006, SC-006)
- [X] T048 [P] [US4] Renombrar temporalmente `pos-heladeria/public/images/auth-preview.webp`, recargar a 1280 px y confirmar que el panel conserva color y texto, sin hueco roto ni layout partido (quickstart.md §6.5, edge case)
- [X] T049 [P] [US4] Recorrer cada una de las tres pantallas **solo con Tab**, confirmando que el orden sigue el orden visual, que cada elemento muestra foco visible y que todo se puede activar —incluido el ojo de la contraseña, con Tab y Enter— (quickstart.md §6.6, §3.8; FR-039, FR-040, SC-004, R9)
- [ ] T050 [P] [US4] Recorrer las tres pantallas con lector de pantalla, confirmando que cada campo anuncia su etiqueta y que errores y estados se anuncian al aparecer (quickstart.md §6.7; FR-038, FR-041)
- [X] T051 [P] [US4] Medir en el inspector el alto efectivo de botones, enlaces de acción, casilla y ojo en las tres pantallas (quickstart.md §6.8; FR-043)
- [ ] T052 [P] [US4] Cambiar la fecha del sistema al 1 de enero siguiente, recargar y confirmar que el pie muestra el año nuevo (quickstart.md §6.9; FR-003, edge case)

**Checkpoint**: las cuatro historias entregadas.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: la limpieza, el recorrido manual completo, la auditoría y las dos puertas de cierre

- [X] T053 [P] Eliminar `pos-heladeria/public/images/login-panel.svg` y confirmar con `grep -rn "login-panel" pos-heladeria/src pos-heladeria/public` que nada lo referencia — no es una vista previa del sistema, es un adorno, y no sirve para FR-004 (R2, quickstart.md §10.6)
- [X] T053a [P] Confirmar que los dos destinos públicos que enlazan las pantallas responden: `curl -sSI https://skeilopos.com/privacidad` y `curl -sSI https://skeilopos.com/` devuelven 200 y no una redirección a un 404. Es la verificación directa de FR-003a, que esta spec enlaza pero no crea (FR-003, FR-003a, FR-009)
- [X] T054 Recorrer quickstart.md §2 completo (2.1 a 2.8) con las URLs de subdominio reales: insignia, pestaña Red sin peticiones antes de enviar, los tres contextos de host, el aviso extendido a las otras dos pantallas, el subdominio inventado que **sí** muestra formulario (D12), y la etiqueta sin retoques con un slug compuesto y uno larguísimo (FR-001 a FR-010, SC-011, SC-012)
- [ ] T055 Recorrer quickstart.md §3 completo (3.1 a 3.15), incluido **3.3 con la cuenta desactivada**, que es donde se verifica el hallazgo R7: el mensaje tiene que ser idéntico carácter por carácter al de la contraseña mala y al del correo inexistente, y **nunca** "User account is inactive". Incluye **3.10**, el cronómetro de SC-001 (FR-012, SC-001, SC-003, SC-008, SC-009, SC-013)
- [ ] T056 Recorrer quickstart.md §4 completo (4.1 a 4.9), incluidos **4.5 (recargar con 40 s pendientes)** y **4.6 (pestaña en segundo plano 70 s)**, que son los dos que distinguen un bloqueo bien hecho de uno que solo lo parece (FR-020 a FR-025)
- [ ] T057 Recorrer quickstart.md §5 completo (5.1 a 5.15), incluidos **5.14 (el enlace no se consumió al validar)** y **5.9 (el aviso no reaparece al recargar `/login`)**. **5.11 y 5.12 cierran SC-010** en sus tres cláusulas vigentes tras D13 (vencido, usado, invalidado); recorrer §4 y §5 de punta a punta sin intervención de un administrador es lo que cierra SC-002 (FR-026 a FR-034, SC-002, SC-010, R12)
- [ ] T058 [P] Recorrer quickstart.md §7: aislamiento por negocio en login y en solicitud de enlace, y recuperación del super administrador desde `admin.localhost` (FR-035, FR-036)
- [X] T059 Ejecutar quickstart.md §8 y **escribir el resultado observado en la entrada A-111** de `pos-specs/specs/000-reconocimiento/registro-de-anomalias.md`: abrir un enlace de `negocioa` desde `negociob` y desde `admin` y documentar que valida y permite fijar la contraseña. **No es un fallo de esta implementación** — es el hallazgo R18, y lo que se entrega es la evidencia, no el arreglo (depende de T007)
- [X] T060 [P] Auditar con Lighthouse → Accessibility las tres pantallas, en escritorio y a 390 px, incluyendo los estados que suelen fallar: el error de login visible, la lista de requisitos con un ítem cumplido y otro pendiente, y el control de reenvío deshabilitado con su cuenta regresiva. Criterio de cierre: **ningún** incumplimiento de contraste ni de etiquetado de campos (quickstart.md §9; FR-042, SC-005)
- [X] T061 Ejecutar `cd pos-heladeria && npm test && npm run build` y confirmar que el conteo de fallos es **igual o menor** que la línea base de T002 — la suite arrastra fallos preexistentes ajenos a autenticación, así que el criterio es "ni uno más", no "cero" (quickstart.md §10.1, Principio X)
- [ ] T061a [P] Correr **una vez** los characterization tests de autenticación del backend —`cd pos-backend && env/bin/python -m pytest tests/.../test_auth_forgot_password.py tests/.../test_auth_reset_password.py tests/.../test_auth_login_platform_isolation.py`— y anotar que pasan en verde. FR-045 exige que "sigan pasando", no que se asuma que no pueden verse afectados; correrlos cuesta un minuto y convierte la asunción en evidencia (FR-045, Principios III y X)
- [X] T062 [P] Confirmar que `cd pos-backend && git status` está **limpio**: ni un archivo tocado. Es la verificación directa de FR-044 (quickstart.md §10.4)
- [X] T063 [P] Comprobar que las tres pantallas fuera de alcance que usan `app-password-input` —`change-password.component.ts`, `account-settings.component.ts` y `admin-user-form.component.ts`— siguen funcionando, ahora con el ojo alcanzable por teclado (quickstart.md §10.3; R9, Principio V)
- [X] T064 **Puerta G2 — CERRADA por D13** — Asentar en la entrada A-111 de `pos-specs/specs/000-reconocimiento/registro-de-anomalias.md` la decisión de D13 (aceptar la limitación; Leonardo Gómez, 2026-10-05) y cambiar su clasificación de HALLAZGO a HALLAZGO + DECISIÓN, añadiendo el resultado observado en T059. Verificar que FR-037, FR-036, SC-010 y el edge case del subdominio en `spec.md` ya reflejan D13 (depende de T059)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Fase 1)**: sin dependencias
- **Foundational (Fase 2)**: depende de Setup. **BLOQUEA todas las historias.** Dentro de ella,
  T004-T007 bloquean por constitución todo lo demás
- **US1 (Fase 3)**, **US2 (Fase 4)**, **US3 (Fase 5)**: dependen solo de la Fase 2; entre sí son
  independientes
- **US4 (Fase 6)**: depende de que las tres pantallas estén dentro del cascarón (T022, T028, T037)
- **Polish (Fase 7)**: depende de todo lo anterior

### User Story Dependencies

- **US1 (P1)**: arranca tras la Fase 2. Sin dependencias de otras historias
- **US2 (P2)**: arranca tras la Fase 2. Independiente de US1 y US3
- **US3 (P2)**: arranca tras la Fase 2. Fija el aviso que US1 lee, pero **el acoplamiento está
  resuelto**: `AuthNoticeService` se entrega en la Fase 2 (T013), de modo que US1 y US3 se
  implementan y se prueban por separado
- **US4 (P3)**: necesita las tres pantallas migradas al cascarón

### Dependencias concretas dentro de las fases

| Tarea | Depende de | Por qué |
|---|---|---|
| T009 | T008 | el campo tiene que existir en la interfaz antes de darle valor |
| T013 | T012 | tests antes que implementación |
| T014 | T010 | la regla CSS referencia el activo |
| T016 | T015 | tests antes que implementación |
| T017 | T009, T014, T016 | el pie usa `publicSiteUrl` y el panel usa la regla del fondo |
| T022, T028, T037 | T017 | las tres pantallas envuelven el cascarón terminado |
| T021 | T020 | tests antes que implementación; además los dos tocan el mismo par de archivos hermanos |
| T024 | T011 | usa el `focus()` que esa tarea añade |
| T025a | T022 | toca la rama de error de `login.component.ts`, que T022 reescribe |
| T044a | T037 | toca los dos estados de `reset-password.component.ts` |
| T026 | T013 | consume `AuthNoticeService` |
| T038, T039 | T036 | las dos leen `PASSWORD_RULES` |
| T042 | T013 | fija `AuthNoticeService` |
| T059 | T007 | escribe dentro de la entrada A-111 |
| T064 | T059 | la decisión necesita la evidencia observada |

### Within Each User Story

- Los tests se escriben **antes** y tienen que fallar
- Módulos antes que componentes (T036 antes que T038/T039)
- Estructura antes que comportamiento (T022 antes que T024/T025/T026)
- Una historia se cierra antes de pasar a la siguiente prioridad

### Parallel Opportunities

- **Fase 2**: T008, T010, T011 y T012 son cuatro archivos distintos sin relación → en paralelo.
  Lo que **no** se paraleliza son T004 a T007: las cuatro entradas van en el mismo archivo
- **Fase 3**: T020 (spec del servicio) corre en paralelo con T018/T019/T019a (spec del
  componente); **T021 va después de T020**, y es paralelo a todo lo de `login.component.ts`
- **Fase 5**: T034 y T035 en paralelo; T036 en paralelo con lo que no sea `reset-password`
- **Fase 6**: las siete verificaciones (T046 a T052) son independientes entre sí
- **Fase 7**: T053, T058, T060, T062 y T063 no se pisan
- **Entre historias**: con equipo, US1, US2 y US3 avanzan a la vez en cuanto cierra la Fase 2 —
  cada una vive en su propio archivo de pantalla

**Lo que nunca va en paralelo**: dentro de US1, las tareas T022 a T026 tocan todas
`login.component.ts`; dentro de US2, T028 a T033 tocan todas `forgot-password.component.ts`;
dentro de US3, T037 a T044 tocan todas `reset-password.component.ts`. Son secuenciales por
construcción, y marcarlas `[P]` sería una invitación a perder trabajo en un conflicto.

---

## Parallel Example: Fase 2

```bash
# Cuatro archivos sin relación entre sí, a la vez:
Task: "Añadir publicSiteUrl a app-environment.interface.ts"               # T008
Task: "Convertir y publicar auth-preview.webp ≤ 80 KB"                    # T010
Task: "Quitar tabindex=-1 y añadir focus() en password-input.component"   # T011
Task: "Crear auth-notice.service.spec.ts"                                 # T012
```

## Parallel Example: tres historias a la vez

```bash
# En cuanto el cascarón (T017) está listo:
Dev A: T018 → T026   # Historia 1, login.component.ts
Dev B: T027 → T033   # Historia 2, forgot-password.component.ts
Dev C: T034 → T044   # Historia 3, reset-password.component.ts + password-policy.ts
```

---

## Implementation Strategy

### MVP First (solo Historia 1)

1. Fase 1: Setup — la rama y la línea base
2. Fase 2: Foundational — **crítica**, y su primer tramo (T004-T007) es una puerta de
   constitución, no una formalidad
3. Fase 3: Historia 1
4. **PARAR Y VALIDAR**: quickstart.md §3 completo, con la cuenta desactivada incluida
5. Desplegar o demostrar si está listo

### Incremental Delivery

1. Setup + Foundational → el cascarón se prueba solo, en los tres contextos de host
2. + Historia 1 → la pantalla de entrada rediseñada, con el fallo de login ya indistinguible (MVP)
3. + Historia 2 → la solicitud de enlace, con su bloqueo de reenvío
4. + Historia 3 → la contraseña nueva, con su lista accesible
5. + Historia 4 → el barrido responsive y de accesibilidad
6. + Polish → recorrido completo, auditoría y las dos puertas

Cada paso añade valor sin romper el anterior, y cada uno es un commit pequeño: cascarón, login,
solicitud, contraseña nueva, componente compartido, configuración, activos.

---

## Estado de cierre (2026-10-05) — 63 de 70 tareas

Las **7 tareas abiertas son todas de verificación manual**, y cada una está bloqueada por algo que no
se puede fabricar desde la implementación. Ninguna bloquea el código, que está entregado y en verde.

| Tarea | Qué falta | Por qué no se pudo ejecutar |
|---|---|---|
| **T050** | Recorrido con lector de pantalla real | Hace falta NVDA/VoiceOver con una persona escuchando. Lo que sí está: el árbol de accesibilidad se inspeccionó (cada campo anuncia su etiqueta, el ojo anuncia su acción, errores en `role="alert"` y avisos en `role="status"`) y Lighthouse da **100** en las tres pantallas |
| **T052** | Cambiar la fecha del sistema al 1 de enero siguiente | Cambia el reloj de la máquina del usuario. El pie usa `new Date().getFullYear()` y su test lo fija contra el año calculado, no contra un literal |
| **T055** | quickstart §3 completo | **3.3 (cuenta desactivada) es el que importa**: el `403` solo se dispara con la contraseña **correcta** de una cuenta desactivada, y esa contraseña no está disponible. Existe la cuenta (`rgomezllamas@gmail.com`, negocio `heladeria`, `active = f`). Con contraseña incorrecta el servidor responde `401`, no `403`, así que el camino no se alcanza. Verificado en vivo: 3.1, 3.2, 3.4, 3.7, 3.8, 3.14, 3.15. Falta además 3.6 (los cuatro roles) y 3.10 (cronómetro de SC-001) |
| **T056** | quickstart §4 completo | 4.6 (pestaña 70 s en segundo plano) y 4.7 (cuarta solicitud contra el límite de 3/900 s) necesitan esperas reales. Verificado en vivo: 4.1, 4.2, 4.4, 4.8, 4.9, y el test F4 cubre el salto de reloj de 4.6 |
| **T057** | quickstart §5 completo | Consumir un enlace **cambiaría la contraseña real** de una cuenta del entorno de desarrollo. Verificado en vivo sin consumirlo: el formulario con un enlace vigente (5.1), la lista de requisitos (5.2, 5.3) y el estado de enlace no válido (5.11, 5.12). Los 24 tests de `reset-password.component.spec.ts` cubren el resto |
| **T058** | quickstart §7, aislamiento por negocio | Hace falta una cuenta válida de un segundo negocio para probar que sus credenciales fallan en otro. Hoy el entorno solo tiene credenciales utilizables de `heladeria` |
| **T061a** | Characterization tests de autenticación del backend | **`pytest` no está instalado en `pos-backend/env` ni declarado en `requirements.txt`**. Instalarlo es añadir una dependencia a un repositorio que esta spec prometió no tocar (FR-044, Principio IX), así que es decisión del usuario. Lo que sí quedó probado: `git status` de `pos-backend` tiene **cero** cambios (T062), de modo que esos tests no pueden haberse visto afectados |

**Puertas**: G1 cerrada (A-108 a A-111 escritas antes del código). **G2 cerrada** — T059 se ejecutó y
su resultado observado quedó asentado en A-111.

**Anomalía nueva encontrada al implementar**: **A-112**. FR-018 ("llevar al destino que intentaba
abrir") describía comportamiento que **no existía**: `authGuard` redirigía a `/login` sin guardar la
ruta. Se implementó con `returnUrl`, restringido a rutas internas para no abrir un *open redirect*.

---

## Notes

- **Nada de esto toca `pos-backend`.** Si una tarea parece pedirlo, la tarea está mal leída:
  FR-044 es inviolable y T062 lo verifica.
- **T004 a T007 van primero de verdad.** El Principio II no pide registrar el cambio *alguna
  vez*, sino **antes** de implementarlo. Son cuatro entradas en un archivo, media hora de
  trabajo, y sin ellas el resto de la fase no debería arrancar.
- **La spec no se puede declarar completa sin G2** (T064), aunque el 95 % del trabajo no la
  espere: FR-037 no añade ni quita una línea de frontend.
- **Dos textos y solo dos** cambian en `login.component.spec.ts` (T018). Si al terminar hay un
  tercero modificado, algo se rompió que no debía.
- **Línea base, siempre.** `npm test` en `pos-heladeria` arrastra fallos preexistentes ajenos a
  autenticación. Atribuir uno de ellos a este cambio cuesta medio día de búsqueda inútil.
- **Commits**: pequeños, en inglés, Conventional Commits, sin marcas de asistencia de IA, en
  `style/095-auth-screens-redesign` — y **solo cuando el usuario los pida** (Principios XIV, XV).
- **Íconos**: el `ICON_CATALOG` real expone `storefront`, `admin_panel_settings`, `check` y
  `circle`; no existen `store` ni `shield`. R5 de research.md ya está corregido con esos nombres.
