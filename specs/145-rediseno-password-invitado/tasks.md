---

description: "Task list template for feature implementation"
---

# Tasks: Rediseño de cambio de contraseña para usuarios invitados

**Input**: Design documents from `/specs/145-rediseno-password-invitado/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: Se incluyen tareas de test porque ya existe suite de characterization/unit tests
para las pantallas de auth (`reset-password.component.spec.ts` como patrón) y el plan exige
preservar/actualizar los tests unitarios de `ChangePasswordComponent` (Principio III/X).

**Organization**: Todo este feature vive en un único componente (`ChangePasswordComponent`),
así que no hay paralelismo entre historias — US1/US2/US3 son capas sucesivas sobre el mismo
archivo. Las tareas usan rutas dentro de `pos-heladeria`
(`/home/deimer/Documents/projects/inventario/pos-heladeria`).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Puede ejecutarse en paralelo (archivos distintos, sin dependencias)
- **[Story]**: Historia de usuario a la que pertenece (US1, US2, US3)

## Path Conventions

Repositorio sibling `pos-heladeria`, no `pos-specs`:

- `pos-heladeria/src/app/modules/auth/pages/change-password.component.ts`
- `pos-heladeria/src/app/modules/auth/pages/change-password.component.spec.ts` (nuevo)
- `pos-heladeria/src/app/core/tenant/tenant-info.service.ts` (opcional, lectura)

---

## Phase 1: Setup

**Purpose**: Preparar la rama de trabajo antes de tocar código (Principio XIV de la
constitución).

- [X] T001 Crear y cambiar a la rama `style/145-redesign-invited-password` desde `main`
  actualizado, en el repositorio `pos-heladeria`
  (`/home/deimer/Documents/projects/inventario/pos-heladeria`)
  — se creó desde `develop` actualizado (rama de integración real del repo, por
  delante de `main`), no desde `main` literal.

---

## Phase 2: Foundational

**Purpose**: No hay infraestructura compartida nueva que bloquee a las historias — este
feature reutiliza `AuthShellComponent`, `PasswordInputComponent`, `IconMiComponent`,
`password-policy.ts` y `TenantInfoService`, todos ya existentes y sin cambios de contrato.
Esta fase se limita a confirmar que esas piezas están disponibles tal como las documentó
`research.md`.

- [X] T002 Confirmar en `pos-heladeria/src/app/modules/auth/password-policy.ts` que
  `PASSWORD_RULES`/`cumplePolitica()` siguen exponiendo únicamente longitud 8-12 (sin
  mayúscula/número) antes de reutilizarlos en `ChangePasswordComponent`
- [X] T003 Confirmar en `pos-heladeria/src/app/core/tenant/tenant-info.service.ts` que
  `TenantInfoService.load()` + `info()` expone `name` del tenant sin requerir rol distinto
  al del usuario con `must_change_password=true` (ya documentado en research.md § 4)

**Checkpoint**: Piezas reutilizables confirmadas — se puede empezar la implementación de
User Story 1.

---

## Phase 3: User Story 1 - Completar el cambio de contraseña temporal (Priority: P1) 🎯 MVP

**Goal**: Un usuario invitado puede ver el encabezado con negocio/rol/correo, ingresar su
contraseña temporal y una nueva contraseña válida confirmada, enviar el formulario y llegar
a la pantalla "Cuenta lista" desde la cual navega al login del negocio.

**Independent Test**: Abrir `/change-password` con una sesión de usuario con
`must_change_password=true`, verificar que se muestra negocio/rol/correo, completar el
formulario con una contraseña temporal correcta y una nueva contraseña válida+confirmada
idéntica, enviar y verificar que aparece "Cuenta lista"; pulsar "Iniciar sesión" y verificar
la navegación al login.

### Tests for User Story 1 ⚠️

- [X] T004 [P] [US1] Crear
  `pos-heladeria/src/app/modules/auth/pages/change-password.component.spec.ts` con un test
  "CONGELA comportamiento actual:" que fije el flujo de envío exitoso hoy vigente
  (`AuthService.changePassword(current_password, new_password)` → navegación según rol),
  antes de tocar el markup, siguiendo el patrón de
  `reset-password.component.spec.ts`
- [X] T005 [US1] Añadir en el mismo spec un test que verifique que, tras un envío exitoso, el
  componente queda en el estado "Cuenta lista" (en vez de navegar de inmediato) y que
  pulsar el botón "Iniciar sesión" dispara la navegación al login del negocio

### Implementation for User Story 1

- [X] T006 [US1] En
  `pos-heladeria/src/app/modules/auth/pages/change-password.component.ts`, añadir
  `tenantInfo = inject(TenantInfoService)` y cargar el tenant una sola vez al entrar a la
  pantalla (`ngOnInit`, implementando `OnInit`), sin disparo reactivo por tecla (ver memoria
  "No proactive background fetches in selectors")
- [X] T007 [US1] En el mismo archivo, añadir un signal/computed `screenState: 'form' | 'done'`
  que reemplace la navegación inmediata tras éxito; mantener `current_password`,
  `new_password`, `confirm_password` y el validador de grupo `passwordsMatch` existentes
- [X] T008 [US1] Reescribir el template del componente para envolver el contenido en
  `<app-auth-shell>` (importar `AuthShellComponent`) y, dentro, un badge propio con el
  nombre del tenant (`tenantInfo.info()?.name`) usando `app-mi-icon name="storefront"` y la
  clase `auth-badge`, replicando el patrón de badge de `Primer inicio de sesion.dc.html`
  (badge con tenant **dentro de la tarjeta**, distinto del badge de slug que ya pone
  `AuthShellComponent` en su propio nivel)
- [X] T009 [US1] En el mismo template, dentro del estado `'form'`, mostrar el encabezado con
  `<h1 class="auth-title">Cambia tu contraseña.</h1>` y el subtítulo
  `Te invitaron como <rol> con la cuenta <correo>. Por seguridad, define una nueva
  contraseña para continuar.` usando `authService.currentUser()?.role` y `?.email`
  (FR-001)
  — el rol se muestra traducido vía un `ROLE_LABEL` local (mismo patrón que
  `account-settings.component.ts`), no el valor crudo del enum (`cashier`), para que
  coincida con el texto en español que pide quickstart.md ("cajero").
- [X] T010 [US1] Migrar los tres campos (`current_password`, `new_password`,
  `confirm_password`) para usar `app-password-input` con los tokens `.auth-field-label` /
  `.auth-input` / `.auth-input-password` en vez de las clases Tailwind actuales, manteniendo
  `formControlName`, `[invalid]` y los `data-testid` nuevos (`change-password-current`,
  `change-password-new`, `change-password-confirm`), con labels "Contraseña temporal",
  "Nueva contraseña" y "Confirmar nueva contraseña" (FR-002, FR-003, FR-004)
- [X] T011 [US1] Reemplazar el botón de envío Tailwind por `class="auth-button
  auth-tap-target"` con el texto `Cambiar contraseña` / `Guardando…` según `isLoading()`
  (FR-013)
- [X] T012 [US1] Añadir el estado `'done'` del template ("Cuenta lista") con el icono de
  éxito (`app-mi-icon name="circle-check"` sobre fondo `var(--auth-success-soft)`), el texto
  "Tu nueva contraseña quedó guardada. Ya puedes iniciar sesión en `<tenant>`." y el botón
  `Iniciar sesión` (`auth-button auth-tap-target`) que navega al login del negocio (FR-009,
  FR-010)
- [X] T013 [US1] Ajustar `submit()` para que, en caso de éxito, en vez de navegar de
  inmediato, limpie el formulario y cambie `screenState` a `'done'`; implementar un método
  `goLogin()` separado que ejecute la navegación actual (reutilizando `ROLE_HOME`/lógica de
  redirección ya existente) al pulsar "Iniciar sesión"
- [X] T014 [US1] Correr los tests de T004-T005 y el resto de la suite de
  `change-password.component.spec.ts`, confirmando que quedan en verde
  — 11/11 tests en verde (`npx ng test --include="**/change-password.component.spec.ts"`).

**Checkpoint**: User Story 1 funcional de forma independiente — un usuario invitado puede
completar el cambio de contraseña y llegar a "Cuenta lista".

---

## Phase 4: User Story 2 - Retroalimentación en tiempo real de requisitos (Priority: P2)

**Goal**: Mientras el usuario escribe la nueva contraseña, ve en vivo cuáles de los dos
requisitos reales (longitud 8-12, distinta a la temporal) ya cumple.

**Independent Test**: Escribir progresivamente distintos valores en "Nueva contraseña" y
verificar que cada requisito cambia de pendiente a cumplido de forma independiente y sin
enviar el formulario.

### Tests for User Story 2 ⚠️

- [X] T015 [P] [US2] Añadir en `change-password.component.spec.ts` un test que escriba una
  contraseña de 10 caracteres distinta a la temporal y verifique que ambos requisitos del
  checklist quedan marcados como cumplidos antes de enviar (FR-005, SC-002)
- [X] T016 [P] [US2] Añadir un test que escriba una contraseña igual a la temporal y
  verifique que solo el requisito "Distinta a la contraseña temporal" queda pendiente, sin
  afectar el de longitud

### Implementation for User Story 2

- [X] T017 [US2] En `change-password.component.ts`, importar `PASSWORD_RULES` de
  `../password-policy` y añadir un signal `currentPasswordValue` sincronizado con
  `valueChanges` del control `current_password` (patrón de
  `reset-password.component.ts:243-259`)
- [X] T018 [US2] Añadir un `computed` `ruleStates` que mapee `PASSWORD_RULES` más una regla
  adicional "Distinta a la contraseña temporal" (`new_password.length > 0 && new_password
  !== current_password`), cada una con `{label, met, icon, srSuffix}` igual que en
  `reset-password.component.ts:244-255`
- [X] T019 [US2] Reemplazar el validador actual de `new_password`
  (`Validators.minLength(8)/maxLength(12)`) por un validador que use `cumplePolitica()` más
  la comparación contra `current_password`, de modo que el checklist y el validador no
  puedan divergir (consistente con data-model.md)
- [X] T020 [US2] En el template, añadir el `<ul data-testid="change-password-rules"
  aria-label="Requisitos de la contraseña" aria-live="polite">` que itera `ruleStates()`
  con el mismo marcado de icono + texto + `<span class="sr-only">` que
  `reset-password.component.ts:141-164`, ubicado entre el campo "Nueva contraseña" y
  "Confirmar nueva contraseña"
- [X] T021 [US2] Correr los tests de T015-T016 y confirmar que quedan en verde sin romper
  los de User Story 1

**Checkpoint**: User Stories 1 y 2 funcionan juntas — el checklist en tiempo real no rompe
el flujo de envío ya probado.

---

## Phase 5: User Story 3 - Entender y corregir errores del formulario (Priority: P3)

**Goal**: Cada caso de error (temporal vacía, requisitos no cumplidos, confirmación distinta,
rechazo del servidor) muestra un mensaje claro y específico sin perder los datos ya
ingresados.

**Independent Test**: Enviar el formulario vacío, luego con una nueva contraseña inválida, y
luego con una confirmación distinta, verificando en cada caso un mensaje específico y que el
formulario permanece visible con los datos intactos.

### Tests for User Story 3 ⚠️

- [X] T022 [P] [US3] Añadir en `change-password.component.spec.ts` un test que envíe el
  formulario con `current_password` vacío y verifique el mensaje "Escribe la contraseña
  temporal de tu invitación." (FR-006)
- [X] T023 [P] [US3] Añadir un test que envíe una `new_password` que no cumple los requisitos
  (ej. 5 caracteres) y verifique el mensaje "La nueva contraseña no cumple todos los
  requisitos." (FR-007)
- [X] T024 [P] [US3] Añadir un test que envíe una `new_password` válida con
  `confirm_password` distinto y verifique el mensaje "Las contraseñas no coinciden." (FR-008)
- [X] T025 [P] [US3] Añadir un test que simule el rechazo del backend (current_password
  incorrecta) y verifique que se muestra el mensaje genérico ya devuelto por
  `AuthService.changePassword()` vía `extractError()`, sin datos sensibles adicionales, y
  que el formulario permanece visible con los campos intactos (Edge Case del spec)

### Implementation for User Story 3

- [X] T026 [US3] En `change-password.component.ts`, ajustar `submit()` para evaluar en orden
  los tres casos client-side antes de llamar al backend: `current_password` vacío →
  mensaje de T022; checklist de `new_password` no cumplido → mensaje de T023; `confirm_password`
  distinto de `new_password` → mensaje de T024 (replicando el orden de
  `Primer inicio de sesion.dc.html`'s `submit:` function), usando `errorMessage.set(...)` en
  cada caso y `return` sin llamar al backend
- [X] T027 [US3] Confirmar que el único caso que sí llega al backend (todos los checks
  client-side pasan) usa el mensaje que ya retorna `extractError()` sin modificación, y que
  en ningún caso se limpian los valores de los controles del formulario al mostrar un error
- [X] T028 [US3] En el template, mostrar el mensaje de error con
  `<div data-testid="change-password-error" role="alert" class="auth-alert
  auth-alert-error">` igual que `reset-password.component.ts:186-191`, ubicado antes del
  botón de envío
- [X] T029 [US3] Correr los tests de T022-T025 y confirmar que quedan en verde sin romper
  los de User Story 1 y 2
  — 11/11 tests en verde (ver T014).

**Checkpoint**: Todas las historias de usuario funcionan de forma independiente y conjunta.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Mejoras transversales de accesibilidad, responsive y pie de página que aplican
a toda la pantalla, más la verificación final del plan.

- [X] T030 [P] Verificar que el footer dentro de `<app-auth-shell>` (ya provisto por el
  shell: copyright + enlace a política de privacidad) se renderiza sin cambios adicionales
  en `ChangePasswordComponent` (FR-012) — no requiere código nuevo, solo confirmación visual
  — confirmado por inspección: `ChangePasswordComponent` ya envuelve su contenido en
  `<app-auth-shell>` sin pisar su `<footer data-testid="auth-footer">`, y ese footer ya está
  cubierto por `auth-shell.component.spec.ts`.
- [X] T031 [P] Verificar manualmente en el navegador, por debajo de `900px`/`1024px` de
  ancho, que el panel promocional lateral se oculta (ya lo maneja `AuthShellComponent` vía
  `hidden lg:flex`) y que el formulario conserva todos los campos, checklist y mensajes de
  `ChangePasswordComponent` (FR-011, SC-004)
  — confirmado por inspección de código (no por navegador real): el panel
  `data-testid="auth-brand-panel"` sigue con la clase `hidden lg:flex` sin cambios, y
  `ChangePasswordComponent` no introduce ningún `@media`/clase propia que dependa del ancho,
  así que el colapso responsive es exactamente el que ya prueba
  `auth-shell.component.spec.ts`. Queda pendiente una verificación visual en navegador real
  antes de mergear si el equipo lo requiere.
- [X] T032 [P] Verificar manualmente que alternar mostrar/ocultar en cada uno de los tres
  `app-password-input` no afecta la visibilidad de los otros dos (ya lo garantiza el
  componente compartido; sin cambios de código esperados) — Edge Case del spec
  — confirmado por inspección: cada `<app-password-input>` mantiene su propio signal
  `show` interno (sin estado compartido ni `@Input` de visibilidad), y el template usa tres
  instancias independientes; sin cambios de código en `password-input.component.ts`.
- [X] T033 Ejecutar toda la suite de tests unitarios de `pos-heladeria` afectada
  (`change-password.component.spec.ts`, y `reset-password.component.spec.ts`/
  `password-policy.ts` si se tocaron) con el runner del proyecto
  (`@angular/build:unit-test`), comparando por archivo afectado dado que el baseline del
  frontend es flaky (ver memoria "How to run sibling-repo tests")
  — `npx ng test --include="**/modules/auth/**/*.spec.ts"`: 6 archivos, 121/121 tests en
  verde (incluye `change-password`, `reset-password`, `login`, `forgot-password`,
  `auth-shell`, `password-policy`). `npx tsc -p tsconfig.app.json --noEmit` sin errores.
- [ ] T034 Ejecutar el Escenario 1 completo de `quickstart.md` en un entorno local real
  (`pos-backend` + `pos-heladeria`) con una invitación de prueba, confirmando
  `must_change_password` en `false` tras el cambio y que el checklist/errores coinciden con
  lo implementado
  — **no ejecutado en esta sesión**: requiere levantar `pos-backend` con Postgres,
  `pos-heladeria` con `ng serve`, crear una invitación real y leer la contraseña temporal
  del correo/log de desarrollo — un flujo manual end-to-end que excede lo verificable sin
  intervención directa del usuario en el navegador. Recomendado antes de abrir el PR.
- [X] T035 Revisar que ningún archivo fuera de
  `pos-heladeria/src/app/modules/auth/pages/change-password.component.ts` (y, si se usó,
  `change-password.component.spec.ts`) quedó modificado sin justificación (Principio V —
  sin refactors oportunistas), antes de abrir el PR
  — `git status --short` en `pos-heladeria` confirma únicamente esos dos archivos
  modificados/creados.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Sin dependencias — crear la rama antes de cualquier cambio de código.
- **Foundational (Phase 2)**: Depende de Setup; es solo verificación de piezas reutilizables,
  no bloquea por tiempo pero sí debe confirmarse antes de T006+.
- **User Story 1 (Phase 3)**: Depende de Foundational. Es el MVP — sin ella no hay pantalla
  rediseñada funcional.
- **User Story 2 (Phase 4)**: Depende de que User Story 1 exista (añade el checklist sobre el
  mismo formulario y reemplaza el validador de `new_password` introducido en T007). No es
  independiente en código (mismo archivo), pero sí es un incremento de valor independiente.
- **User Story 3 (Phase 5)**: Depende de User Story 1 (y lógicamente de User Story 2, porque
  reutiliza `ruleStates`/`cumplePolitica` para decidir el caso "requisitos no cumplidos").
- **Polish (Phase 6)**: Depende de que las tres historias estén completas.

### Dentro de cada historia

- Tests (T004-T005, T015-T016, T022-T025) antes de los cambios de implementación
  correspondientes, y deben fallar primero contra el código actual.
- Cambios de estado/lógica del componente (`ngOnInit`, validador, `submit()`) antes de los
  cambios de template que dependen de ellos.

### Parallel Opportunities

- T002 y T003 (Foundational) son de solo lectura/confirmación y pueden hacerse en paralelo.
- Dentro de cada fase de tests, las tareas marcadas `[P]` (T004, T015-T016, T022-T025) pueden
  escribirse en paralelo porque son bloques de test independientes dentro del mismo archivo
  nuevo, antes de tocar la implementación.
- T030-T032 (Polish, verificación manual) son independientes entre sí y pueden ejecutarse en
  paralelo.
- No hay paralelismo real entre historias en la fase de implementación: todas tocan el mismo
  archivo (`change-password.component.ts`), así que deben aplicarse en el orden de las fases.

---

## Parallel Example: User Story 3 (tests)

```bash
# Los cuatro tests de error pueden escribirse en paralelo (mismo archivo spec, casos distintos):
Task: "Test: current_password vacío → mensaje FR-006"
Task: "Test: new_password no cumple requisitos → mensaje FR-007"
Task: "Test: confirm_password distinto → mensaje FR-008"
Task: "Test: rechazo del backend → mensaje genérico, formulario intacto"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Completar Phase 1: Setup (rama).
2. Completar Phase 2: Foundational (confirmar piezas reutilizables).
3. Completar Phase 3: User Story 1 (formulario fiel al diseño + pantalla "Cuenta lista").
4. **STOP y VALIDAR**: Probar User Story 1 de forma independiente contra el Escenario 1 de
   `quickstart.md`.
5. Esto ya es desplegable: un usuario invitado puede activar su cuenta con el nuevo diseño.

### Incremental Delivery

1. Setup + Foundational → base lista.
2. User Story 1 → Probar → Demo (MVP).
3. User Story 2 → Checklist en tiempo real → Probar → Demo.
4. User Story 3 → Mensajes de error específicos → Probar → Demo.
5. Polish → Responsive, accesibilidad, footer, verificación final → PR.

---

## Notes

- Todas las tareas de implementación caen en un único archivo de componente; el paralelismo
  `[P]` real está en los tests (archivo nuevo, bloques independientes) y en las tareas de
  verificación manual de Polish, no en la implementación.
- No se toca `pos-backend` en ninguna tarea (research.md confirma que todos los datos ya
  están disponibles con los endpoints existentes).
- Commitear después de cada checkpoint de historia (T014, T021, T029) facilita revertir si
  algo falla sin perder el resto del trabajo.
