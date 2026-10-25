---

description: "Lista de tareas de la spec 134: bloqueo de la traducción automática y aviso de página alterada"
---

# Tasks: Bloqueo de la Traducción Automática del Navegador y Aviso de Página Alterada

**Input**: Documentos de diseño en `/specs/134-bloqueo-traduccion-automatica/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: INCLUIDAS. El plan exige una spec (`*.spec.ts`, Vitest vía `ng test`) junto a cada archivo de código nuevo, un caso por fila del catálogo de acciones protegidas y la comparación por archivo de la suite completa (Principio X). Las pruebas de cada historia se escriben **antes** de su implementación y deben fallar primero.

**Organization**: Tareas agrupadas por historia de usuario (US1–US5), siguiendo los cuatro incrementos del plan: Incremento 1 = US1 (incluye el ícono, FR-006), Incremento 2 = US2 y US3, Incremento 3 = US4, Incremento 4 = US5.

## Format: `[ID] [P?] [Story] Descripción`

- **[P]**: se puede ejecutar en paralelo (archivos distintos, sin dependencia de tareas incompletas)
- **[Story]**: historia a la que pertenece (US1…US5); Setup, Foundational y Polish no llevan etiqueta
- Todas las rutas son desde la raíz de `pos-specs` (el código vive en el repo hermano `../pos-heladeria`; `../pos-backend` **no se toca**)

## Path Conventions

- **Aplicación web de dos repos hermanos**: este cambio es íntegro del frontend `../pos-heladeria/src/…`
- Código nuevo bajo `../pos-heladeria/src/app/core/integrity/` y `../pos-heladeria/src/app/core/update/`, cada archivo con su `*.spec.ts` al lado (patrón de `core/auth`)
- Comando de pruebas: `cd ../pos-heladeria && npx ng test --watch=false --include='<glob>'`
- La suite completa de `pos-heladeria` se corre **sola**, nunca en paralelo con la del backend (la contención infla los fallos)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Rama, gate de gobernanza y línea base de la suite antes de tocar código

- [X] T001 Crear la rama `fix/134-block-browser-translation` en `../pos-heladeria` desde `develop` (Principio XIV) y comprobar con `git -C ../pos-heladeria branch --show-current`; `../pos-backend` no se toca, no lleva rama. No commitear nada sin pedido explícito del usuario (Principio XV)
- [X] T002 [P] Comprobar en `specs/000-reconocimiento/registro-de-anomalias.md` (entrada A-145, ~línea 5109) que las tres decisiones de comportamiento de la spec 134 están registradas con quién (Leonardo Gómez) y cuándo (2026-10-24); es el gate del Principio II antes de implementar
- [X] T003 [P] Registrar la línea base de la suite de `../pos-heladeria` sin cambios: correr `npx ng test --watch=false` sola y guardar la lista **por archivo** de specs que ya fallan en `specs/134-bloqueo-traduccion-automatica/baseline-suite.md` (referencia para la comparación de T083)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Invariantes de las que dependen las señales de detección y el no-regresión. Si alguna falla, el diseño de las fases siguientes cambia

**⚠️ CRITICAL**: Ninguna historia empieza antes de cerrar estas dos tareas

- [X] T004 Verificar en `../pos-heladeria` los tres invariantes del diseño y anotar el resultado en `specs/134-bloqueo-traduccion-automatica/baseline-suite.md`: (a) `grep -rn '<font' src/ public/` vacío (S3 supone que la app no usa `<font>`); (b) `grep -rnE 'hyphens|:lang\(' src/ public/` sin coincidencias (`lang="es"` no cambia maquetación ni impresión); (c) `grep -rnE 'status\s*===?\s*423' src/` vacío (nadie interpreta el `423` que usará el bloqueo)
- [X] T005 Cruzar el escáner con los tests protegidos: `python3 specs/134-bloqueo-traduccion-automatica/tools/scan-loose-text.py ../pos-heladeria/src/app` debe arrojar `TOTAL bloques con texto suelto: 55 en 21 archivos`, y `grep -rln "CONGELA comportamiento actual" ../pos-heladeria/src` (hoy `review-step.component.spec.ts`; el otro está en `checkout-order-summary`) **no** debe coincidir con ningún archivo de la lista del escáner (Principio III: esos tests no se tocan)

**Checkpoint**: Base lista — US1 y US2 pueden empezar (son independientes entre sí)

---

## Phase 3: User Story 1 - El comensal pide y paga sin que el navegador traduzca la página (Priority: P1) 🎯 MVP

**Goal**: Declarar español y bloquear la traducción automática en todo el documento (menú QR, checkout, panel, super-admin, login y recuperación), incluidas las capas que se montan fuera de `app-root`, con un único cambio atómico (FR-001 a FR-005; FR-002 obliga a entregar idioma y bloqueo juntos), y marcar como no traducible el componente de íconos con texto (FR-006).

**Independent Test**: Con el idioma del sistema en inglés, abrir el menú QR: el navegador no ofrece traducir, un intento manual no cambia el texto, y el flujo producto → carrito → envío → pago termina con el mismo total en pantalla y en el pedido.

### Tests for User Story 1 (escribir primero; debe fallar antes de implementar) ⚠️

- [X] T030 [P] [US1] Añadir a `../pos-heladeria/src/app/shared/icon-mi/icon-mi.component.spec.ts` un caso que verifique que el `<span class="material-icons-outlined">` renderiza `translate="no"` y la clase `notranslate`, conservando `aria-hidden`/`role`/`aria-label`, `font-size` y el texto de la ligadura (sin cambio visual ni de accesibilidad)

### Implementation for User Story 1

- [X] T006 [US1] Editar `../pos-heladeria/src/index.html` en un único cambio (FR-002: idioma y bloqueo nunca por separado): `<html lang="en">` → `<html lang="es" translate="no" class="notranslate">` y añadir `<meta name="google" content="notranslate">` en `<head>`. No tocar el script inline del tema (spec 116), no añadir `Content-Language` ni escribir `lang`/`translate` desde TypeScript (contracts/document-declaration.md)
- [X] T032 [US1] Editar el `<span class="material-icons-outlined">` de `../pos-heladeria/src/app/shared/icon-mi/icon-mi.component.ts`: añadir `translate="no"` y la clase `notranslate`, sin tocar nada más (es el único punto de render de los 147 usos; `app-icon` y `app-icon-lucide` son SVG y no cambian); correr `npx ng test --watch=false --include='src/app/shared/icon-mi/*.spec.ts'` en `../pos-heladeria`: en verde
- [X] T007 [US1] Verificar V1 (quickstart): con `ng serve`, `curl -s http://heladeria.localhost:4200/ | grep -Ei 'lang=|translate|notranslate'` y luego `cd ../pos-heladeria && npx ng build` y repetir sobre `dist/frontend/browser/index.html`; ambos deben contener `<html lang="es" translate="no" class="notranslate">` y el meta `google/notranslate` (solo construir, no servir el build: apuntaría a la API de producción)
- [X] T008 [US1] Verificar en vivo en Chrome, sin simulador, el total de extremo a extremo (US1 escenario 3, FR-023, SC-002): producto de $ 12.000 con adición de $ 3.000, cantidad 3 → el botón dice "Agregar $ 45.000" y el pedido enviado (revisión → método de pago → envío → "Mis pedidos") queda por $ 45.000. Backend de desarrollo con `uvicorn` nativo (ver quickstart, Prerrequisitos)
- [X] T009 [P] [US1] Verificar V9 (quickstart): vista previa de impresión del reporte de caja en `develop` y en la rama nueva; debe ser idéntica (el idioma declarado no altera impresión ni formato de números/fechas)

**Checkpoint**: US1 entregable por sí sola — previene el problema de raíz en un solo archivo

---

## Phase 4: User Story 2 - Si la página igual es alterada, la persona se entera y queda protegida (Priority: P1)

**Goal**: Detectar la alteración sin depender de errores (marcas + canario estructural), mostrar un aviso no descartable con "Recargar" y rechazar el envío del pedido y el pago del comensal mientras la página esté alterada, sin cancelar ni duplicar lo que ya está en vuelo (FR-007 a FR-017, FR-023).

**Independent Test**: Alterar los textos con el traductor simulado ([tools/simulate-translation.js](./tools/simulate-translation.js)): el aviso aparece en < 3 s sin tocar nada, "Enviar pedido" y el pago se rechazan con explicación sin llegar a la red, y "Recargar" devuelve al comensal a su mesa con pedidos y totales intactos.

### Tests for User Story 2 (escribir primero; deben fallar antes de implementar) ⚠️

- [X] T010 [P] [US2] Crear `../pos-heladeria/src/app/core/integrity/integrity-signals.spec.ts` con las funciones puras: S1 (`translated-ltr` / `translated-rtl` dispara; cualquier otra clase en `<html>` no), S2 (`lang="en"` dispara; `es`, `es-CO`, `ES` no), S3 (un `<font>` dispara), S4 (`_msttexthash` o `_msthash` dispara), S5 (canario íntegro no dispara; nodo de texto reemplazado, texto cambiado o elemento desconectado sí), S6 (`DOMException` `NotFoundError` con `removeChild` o `insertBefore` sí; `TypeError`, `HttpErrorResponse` 0/401/404/409/500, `Error('network')` y `DOMException` de otro nombre no)
- [X] T011 [P] [US2] Crear `../pos-heladeria/src/app/core/integrity/page-integrity.service.spec.ts` (temporizadores simulados): arranque con `<html class="translated-ltr">` o `lang="en"` ⇒ `altered` ya en la primera evaluación; histéresis (1 evaluación limpia ⇒ sigue `altered`, 2 ⇒ `intact`, `latched` ⇒ nunca vuelve); sondeo cada 1500 ms solo con `visibilityState === 'visible'`; reevaluación en `visibilitychange` (a visible) y `pageshow`; sin `MutationObserver` solo funciona el sondeo y no lanza; `notifyBlocked(label)` fija `blockedNotice` y se limpia al volver a `intact`; el servicio **nunca** llama a `RELOAD_PAGE` por sí solo (FR-017; las pruebas proveen `{ provide: RELOAD_PAGE, useValue: spy }`); recorrido sin traductor con errores de red/validación ⇒ 0 avisos (FR-008)
- [X] T012 [P] [US2] Crear `../pos-heladeria/src/app/core/integrity/integrity-error-handler.spec.ts`: pasa el error a `reportDomError` y sigue llamando al `console.error` por defecto de Angular (no traga ni transforma); solo un `DOMException` `NotFoundError` de `removeChild`/`insertBefore` activa S6 (latched); `TypeError`, `HttpErrorResponse` 401/404/409/500 y `Error('network')` no activan nada
- [X] T013 [P] [US2] Crear `../pos-heladeria/src/app/core/integrity/page-integrity.interceptor.spec.ts` con `HttpTestingController` (patrón de `../pos-heladeria/src/app/core/auth/auth-token.interceptor.spec.ts`) y el estado de integridad simulado, parametrizado **por fila del catálogo** (aquí QR-1 y QR-2): alterada ⇒ rechazo con `status 423`, `error.detail` en español con el `label` y `error.code === 'page_altered'`, y la petición **no** llega al `HttpTestingController`; íntegra ⇒ pasa; las "evaluadas y no protegidas" del menú QR (`/cart/items…`, `/cart/sessions`, `/cart/leave`, `/cart/orders/{id}/cancel`) pasan siempre; ruta con query (`?x=1`) e id distinto coincide; URL ajena a `environment.apiBaseUrl` nunca se toca; una petición enviada **antes** de alterarse completa su respuesta sin interferencia (FR-014); `notifyBlocked` recibe el `label` correcto
- [X] T014 [P] [US2] Crear `../pos-heladeria/src/app/core/integrity/page-integrity-banner.component.spec.ts`: oculto con la página íntegra; visible alterada con `role="alert"`, texto principal "La página fue alterada por el navegador", sin control de cierre y sin descartarse con Escape ni clic fuera; botón "Recargar" enfocado al aparecer y que invoca `reload()`; la línea "No se pudo {etiqueta}: la página está alterada. Recarga para continuar." aparece solo si `blockedNotice()` tiene valor; el canario `[data-integrity-canary]` está **siempre** presente (también íntegra) con `CANARY_TEXT` y se registra con `registerCanary`

### Implementation for User Story 2

- [X] T015 [US2] Crear `../pos-heladeria/src/app/core/integrity/integrity-signals.ts`: tipo `IntegritySignalId` (`'html-class' | 'html-lang' | 'font-wrapper' | 'ms-translator-attr' | 'canary' | 'dom-error'`), constante `CANARY_TEXT = 'Contenido de la aplicación'` y funciones puras S1–S6 con las comprobaciones **exactas** de contracts/page-integrity.md (ninguna es "algo cambió en el DOM"); toda lectura del DOM dentro de `try/catch` y protegida contra `document` indefinido
- [X] T016 [US2] Crear `../pos-heladeria/src/app/core/integrity/page-integrity.service.ts` (raíz): señales `altered`, `reasons`, `blockedNotice`; `start()` evalúa de inmediato; `MutationObserver` sobre `<html>` (`attributes`: `class`, `lang`, `translate`; **sin `subtree`**) y sobre el canario (`childList`, `characterData`, `subtree`); sondeo de 1500 ms reutilizando `startVisibleInterval` de `../pos-heladeria/src/app/core/realtime/visible-interval.ts` (solo con la pestaña visible, ejecuta al volver a primer plano), más `pageshow`; histéresis de 2 evaluaciones y `latched` para S6; `notifyBlocked`, `reportDomError`, `registerCanary`; `reload()` que invoca `inject(RELOAD_PAGE)()`: crear antes `../pos-heladeria/src/app/core/reload-page.ts` con `export const RELOAD_PAGE = new InjectionToken<() => void>('RELOAD_PAGE', { providedIn: 'root', factory: () => { const doc = inject(DOCUMENT); return () => doc.defaultView?.location.reload(); } })`, único punto de recarga de la app y sustituible en pruebas sin recargar jsdom. Nunca lanza. Depende de T015
- [X] T017 [US2] Crear `../pos-heladeria/src/app/core/integrity/integrity-error-handler.ts` (`IntegrityAwareErrorHandler extends ErrorHandler`): primero `PageIntegrityService.reportDomError(err)` y después `super.handleError(err)`. Depende de T016
- [X] T018 [P] [US2] Crear `../pos-heladeria/src/app/core/integrity/protected-actions.ts` con el tipo `ProtectedAction` (`id`, `method`, `path: RegExp` anclada y relativa a `environment.apiBaseUrl` sin query, `label`), el catálogo `PROTECTED_ACTIONS` con **solo** las filas del menú QR — QR-1 `POST ^/cart/submit$` "enviar el pedido" y QR-2 `POST ^/cart/orders/[^/]+/payment-attempts$` "pagar el pedido" (las filas P-* las añade T033) — y un helper `findProtectedAction(method, url)` que ignora la query
- [X] T019 [US2] Crear `../pos-heladeria/src/app/core/integrity/page-integrity.interceptor.ts` (`pageIntegrityInterceptor`, `HttpInterceptorFn`): fuera de `apiBaseUrl` o con la página íntegra ⇒ `next(req)`; alterada y coincide con una fila ⇒ `notifyBlocked(label)` y `throwError(() => new HttpErrorResponse({ status: 423, statusText: 'Page Altered', url, error: { detail: 'No se pudo {label}: la página fue alterada por el navegador. Recarga para continuar.', code: 'page_altered' } }))`; en otro caso ⇒ `next(req)` (contracts/protected-actions.md). Depende de T016, T018
- [X] T020 [US2] Crear `../pos-heladeria/src/app/core/integrity/page-integrity-banner.component.ts` (`app-page-integrity-banner`, standalone, `OnPush`) según contracts/page-integrity.md: barra `fixed inset-x-0 top-0 z-[100] print:hidden`, `role="alert"`, copy exacto del contrato, sin botón de cerrar, botón "Recargar" → `reload()` con foco al aparecer, y canario `<span class="sr-only" aria-hidden="true" data-integrity-canary>` **fuera** del `@if` registrado con `registerCanary` en `afterNextRender`. Cada texto en su propio elemento (`<p>`, `<span>`): ningún texto suelto dentro de bloques `@if` (el banner cumple FR-021). Depende de T016
- [X] T021 [US2] Registrar en `../pos-heladeria/src/app/app.config.ts`: `provideAppInitializer(() => inject(PageIntegrityService).start())` (antes del primer pintado, FR-007), `{ provide: ErrorHandler, useClass: IntegrityAwareErrorHandler }` y `pageIntegrityInterceptor` **antes** de `authTokenInterceptor` en `withInterceptors([...])` (el rechazo ocurre sin tocar tokens). Depende de T016, T017, T019
- [X] T022 [US2] Montar `<app-page-integrity-banner />` en `../pos-heladeria/src/app/app.html` **fuera** del bloque `@if (authService.isLoading()) … @else { <router-outlet /> }` (debe verse también mientras carga la sesión y en todas las rutas del alcance) e importarlo en el arreglo `imports` de `../pos-heladeria/src/app/app.ts`; `../pos-heladeria/src/app/app.spec.ts` debe seguir en verde. Depende de T020
- [X] T023 [US2] Comprobar que el `423` llega legible a la pantalla del comensal: leer `call()` y `extractError` en `../pos-heladeria/src/app/modules/tables/services/diner.service.ts` y `../pos-heladeria/src/app/modules/tables/services/dining-session.service.ts` y confirmar que un `HttpErrorResponse` con `status: 423` y `error.detail` (cadena) produce ese mensaje; añadir el caso al `diner.service.spec.ts` y al `dining-session.service.spec.ts` existentes si no está cubierto
- [X] T024 [US2] Ejecutar `cd ../pos-heladeria && npx ng test --watch=false --include='src/app/core/integrity/**/*.spec.ts'` y `--include='src/app/app.spec.ts'` más los specs de T023: todo en verde

### Verificación en vivo de User Story 2 (Chrome + traductor simulado)

- [X] T025 [US2] V2 (quickstart): abrir `/menu/t/<token>` y el modal de un producto; `__sim.translate()` ⇒ la barra "La página fue alterada por el navegador" con "Recargar" aparece en **< 3 s** sin tocar nada más (SC-003, FR-007); recargar la página ya traducida ⇒ el aviso aparece al arrancar (US2 escenario 4)
- [X] T026 [US2] V3 (quickstart): con el aviso visible llenar el carrito y pulsar "Enviar pedido" y luego pagar ⇒ ambas acciones se rechazan sin que la pestaña Network muestre peticiones a `/cart/submit` ni `/payment-attempts`, y aparece "No se pudo enviar el pedido: la página está alterada…" (SC-004, FR-012, FR-013); un envío ya en curso al detectar la alteración termina sin cancelarse ni duplicarse (US2 escenario 6)
- [X] T027 [US2] V5 (quickstart, en `http://heladeria.localhost:4200/menu/t/<token>` y `/checkout`): con pedidos ya enviados y carrito confirmado, pulsar "Recargar" ⇒ vuelve al mismo paso, "Mis pedidos" conserva los pedidos con **los mismos totales** y el carrito conserva lo confirmado (SC-005, FR-015); lo no confirmado del modal se pierde (FR-016); tras recargar con el traductor aún activo el aviso reaparece y la app no recarga sola (FR-017)
- [X] T028 [US2] V6 (quickstart, rutas `/menu/t/<token>`, `/checkout` y `/dashboard/*` en `http://heladeria.localhost:4200`): sin simulador, recorrer menú QR, checkout y las pantallas principales del panel provocando errores normales (DevTools → Offline, una validación de formulario, un 4xx) ⇒ el aviso **nunca** aparece y la consola no muestra errores nuevos atribuibles a la feature (SC-006, FR-008)
- [X] T029 [US2] V10 (quickstart): `__sim.translate()` ⇒ aviso; `__sim.revert()` ⇒ el aviso desaparece en ~3 s y se desbloquean las acciones (FR-010); con `__sim.translate({ markers: false, tag: 'span' })` (sin ninguna marca conocida) el aviso también aparece, detectado solo por el canario

**Checkpoint**: US1 y US2 funcionan cada una por separado; juntas son la entrega recomendada (ambas P1)

---

## Phase 5: User Story 3 - El personal usa el panel y las pantallas de acceso sin traducción (Priority: P2)

**Goal**: Cubrir el panel del personal: bloqueo de las acciones de cobro/creación de pedido/dinero del POS con la página alterada (FR-012), incluida la revisión de "Pagos por confirmar" del cajero. El bloqueo preventivo del documento (login, recuperación, panel, super-admin) y el ícono sin traducir (FR-006) ya los entrega US1; el banner raíz ya lo entrega US2.

**Independent Test**: Entrar al panel con el idioma del sistema en inglés: no se ofrece traducción y los íconos se ven como íconos; con la página alterada (simulador), cobrar en la Terminal, aprobar/confirmar en "Pagos por confirmar", registrar un movimiento y abrir/cerrar turno de caja se rechazan con explicación.

**Depende de US2** (T031, T033 amplían los archivos creados por T013, T018, T019). El ícono (T030, T032) se entrega en US1.

### Tests for User Story 3 (escribir primero) ⚠️

- [X] T031 [P] [US3] Ampliar `../pos-heladeria/src/app/core/integrity/page-integrity.interceptor.spec.ts` con **una prueba por fila** P-1 a P-12 (alterada ⇒ 423 con su `label`, sin llegar a la red; íntegra ⇒ pasa) y con las rutas del panel "evaluadas y no protegidas" que deben pasar siempre aun alterada: `POST /orders/draft-preview`, `GET …/checkout-preview`, `POST /orders/{id}/confirm|ready|start-preparation`, `POST /orders/{id}/move`, `POST /orders/merge`, `PATCH /orders/items/{id}/kitchen`, `POST /orders/{id}/cancel`, `POST /orders/items/{id}/void|additions|toppings` y sus `PATCH`/`DELETE`, `POST /orders/payment-attempts/{id}/reject`, `POST /table-sessions/{id}/release`, `POST /cash/registers`; comprobar que `POST /orders/{id}/items` (P-2) coincide pero `POST /orders/items/{id}/void` no

### Implementation for User Story 3

- [X] T033 [US3] Añadir a `../pos-heladeria/src/app/core/integrity/protected-actions.ts` las filas P-1 a P-12 de contracts/protected-actions.md, con la ruta anclada y relativa a `apiBaseUrl`: P-1 `POST ^/orders$` "crear el pedido"; P-2 `POST ^/orders/[^/]+/items$` "agregar productos al pedido"; P-3 `POST ^/orders/[^/]+/checkout-and-send$` "cobrar el pedido"; P-4 `POST ^/orders/[^/]+/complementary-payment$` "cobrar el saldo pendiente"; P-5 `POST ^/orders/payment-attempts/[^/]+/approve$` "aprobar el pago"; P-6 `…/confirm-cash$` "confirmar el pago en efectivo"; P-7 `…/adjust-split$` "reajustar el pago"; P-8 `POST ^/table-sessions/[^/]+/close$` "cobrar y cerrar la cuenta de la mesa"; P-9 `POST ^/sales$` "cobrar la venta"; P-10 `POST ^/cash/shifts/open$` "abrir el turno de caja"; P-11 `POST ^/cash/shifts/[^/]+/movements$` "registrar el movimiento de caja"; P-12 `POST ^/cash/shifts/[^/]+/close$` "cerrar el turno de caja". Antes de cerrar, cotejar cada ruta con su llamador real: `../pos-heladeria/src/app/modules/tables/services/dining-session.service.ts` (líneas ~66, 79, 204, 234, 262, 276, 345), `table-session.service.ts` (~54), `../pos-heladeria/src/app/modules/sales/services/sales.service.ts` y `../pos-heladeria/src/app/modules/cash-register/services/cash.service.ts` (~107, 125, 143). Depende de T018, T031
- [X] T034 [US3] Comprobar que las superficies de cobro del panel muestran el motivo del `423` y, si alguna lo descarta, que el banner (`blockedNotice`) sigue explicándolo: leer el manejo de error de `PosCheckoutPanelComponent` (`../pos-heladeria/src/app/modules/tables/components/pos-checkout-panel.component.ts`), `PaymentAttemptReviewPanelComponent` (`…/payment-attempt-review-panel.component.ts`, la superficie "Pagos por confirmar" que las specs de cobro suelen olvidar), `SessionBillPanelComponent` (`…/session-bill-panel.component.ts`), el armado de orden manual y `../pos-heladeria/src/app/modules/cash-register/services/cash-session.store.ts`; dejar constancia del hallazgo en `specs/134-bloqueo-traduccion-automatica/baseline-suite.md` (sin cambiar código de negocio salvo que una superficie quede sin ninguna explicación visible)
- [X] T035 [US3] Ejecutar `npx ng test --watch=false --include='src/app/core/integrity/**/*.spec.ts'` en `../pos-heladeria`: en verde

### Verificación en vivo de User Story 3

- [X] T036 [US3] V4 (quickstart), con sesión del personal: en `/dashboard/admin` (tarjeta "Estadísticas de ventas"), Terminal de Mesas (filtro "Todas · N" y título del encabezado) y modal de producto del POS, `__sim.translate()` ⇒ aviso en **< 3 s** en cada una (SC-003); con el aviso intentar cobrar en la Terminal, aprobar y confirmar en "Pagos por confirmar", cobrar y cerrar la cuenta de la mesa, registrar un movimiento y abrir/cerrar turno de caja ⇒ todo rechazado con explicación visible y 0 operaciones en curso canceladas o duplicadas (SC-004); el aviso también aparece en login, recuperación de contraseña y `/super-admin`
- [X] T037 [P] [US3] V11 (quickstart): recorrer el menú lateral y las acciones del panel con `__sim.translate()` ⇒ los íconos siguen siendo íconos y no palabras (SC-009, FR-006)
- [ ] T038 [P] [US3] Confirmar con el dueño del producto (Leonardo Gómez) la frontera del catálogo de acciones protegidas —se incluyó P-2 "agregar productos a un pedido existente" y se dejaron fuera anulaciones, adiciones y rechazos—. Ya está decidido (opción A, 2026-10-24) que `POST /orders/{id}/confirm` (descuenta inventario, no mueve dinero), `move` y `merge` quedan fuera. Es una decisión de negocio que **no bloquea** el trabajo: mover una ruta es editar una fila de `PROTECTED_ACTIONS` y su prueba. Anotar la respuesta en `specs/134-bloqueo-traduccion-automatica/contracts/protected-actions.md`

**Checkpoint**: US1, US2 y US3 funcionan de forma independiente

---

## Phase 6: User Story 4 - El arreglo llega solo a las pestañas que llevan días abiertas (Priority: P2)

**Goal**: Comprobar versión nueva al arrancar y al volver a primer plano y aplicarla recargando solo en un "momento seguro" genérico (sin escrituras en vuelo, overlays, controles sucios, campo con foco ni borrador sin enviar), sin recargar nunca por una alteración (FR-018 a FR-020).

**Independent Test**: Con dos despliegues sucesivos, una pestaña con la versión anterior pasa a la nueva en ≤ 5 min tras volver a primer plano y nunca durante un modal, un envío o un pago. (Automatizable en unitarias con `SwUpdate` simulado; la prueba real queda diferida: D4.)

**Depende de US2** (`PageIntegrityService.altered()` para M1, ruta de recarga compartida y orden de interceptores en `app.config.ts`).

### Tests for User Story 4 (escribir primero) ⚠️

- [X] T039 [P] [US4] Crear `../pos-heladeria/src/app/core/update/update-gate.service.spec.ts`: `isSafeMoment()` es `true` solo si se cumplen **todas** M1–M6 y, por **cada** condición activa por separado, es `false` (M1 página alterada; M2 escritura en vuelo; M3 un `.fixed.inset-0` con `getClientRects().length > 0`; M4 un `.ng-dirty`; M5 `input`/`textarea`/`[contenteditable]` con foco y valor; M6 un bloqueador activo); `registerBlocker` + predicado verdadero retiene y el "retirar" devuelto lo quita; **dos registros con el mismo nombre** (Terminal y orden manual usan instancias distintas del store) coexisten y retirar uno no quita el otro; el acceso al DOM no lanza sin `document`
- [X] T040 [P] [US4] Crear `../pos-heladeria/src/app/core/update/inflight-requests.interceptor.spec.ts`: POST/PUT/PATCH/DELETE a `apiBaseUrl` suben el contador mientras están en vuelo y lo bajan en `finalize` (también con error); GET/HEAD/OPTIONS y URLs ajenas no lo tocan; no modifica la petición
- [X] T041 [P] [US4] Crear `../pos-heladeria/src/app/core/update/app-update.service.spec.ts` con `SwUpdate` simulado: `isEnabled=false` ⇒ ni comprueba ni recarga; comprueba al arrancar (tras `ready`) y al volver a primer plano, **no más de una vez por 60 s**; `VERSION_READY` o `unrecoverable` con momento seguro ⇒ `activateUpdate()` + recarga; por cada M1–M6 activa ⇒ no recarga y reintenta a los 15 s; un POST sin completar retiene la recarga hasta que termina; alteración activa + versión pendiente ⇒ no recarga solo; marca `pos.update.autoReloadAt` de < 120 s ⇒ no recarga y un `sessionStorage` que lanza se comporta como sin marca; `checkForUpdate()`/`activateUpdate()` que fallan se registran con `console.warn` sin lanzar; `reloadNow()` con `pending` llama `activateUpdate()` antes de recargar y sin `pending` recarga directo; toda recarga se observa con `{ provide: RELOAD_PAGE, useValue: spy }` para afirmar «recarga / no recarga»
- [X] T042 [P] [US4] Ampliar `../pos-heladeria/src/app/modules/tables/services/pos-terminal.store.spec.ts`: al construirse registra el bloqueador `pos-terminal-draft` cuyo predicado sigue a `hasDraft()` (borrador con líneas ⇒ verdadero; vacío ⇒ falso) y lo retira al destruirse el store

### Implementation for User Story 4

- [X] T043 [US4] Crear `../pos-heladeria/src/app/core/update/update-gate.service.ts` (raíz): `beginRequest()`/`endRequest()` (contador), `registerBlocker(name, active)` que devuelve el "retirar" y usa una **clave interna única por registro** (no solo el nombre, para tolerar dos instancias del store), e `isSafeMoment()` con M1–M6 de contracts/app-update.md; todo acceso al DOM con `try/catch` y `typeof document`. Depende de T016
- [X] T044 [P] [US4] Crear `../pos-heladeria/src/app/core/update/inflight-requests.interceptor.ts` (`inflightRequestsInterceptor`): para escrituras a `apiBaseUrl`, `gate.beginRequest()` y `next(req).pipe(finalize(() => gate.endRequest()))`; el resto pasa sin cambios. Depende de T043
- [X] T045 [US4] Crear `../pos-heladeria/src/app/core/update/app-update.service.ts` (raíz): inactivo si `!swUpdate.isEnabled`; tras `navigator.serviceWorker.ready` (espera acotada a 60 s: el registro es `registerWhenStable:30000`) llama `checkForUpdate()` y lo repite en `visibilitychange` a visible con mínimo 60 s entre comprobaciones; `versionUpdates` filtrado a `VERSION_READY` y `unrecoverable` dejan `pending = true`; con `pending`, cada 15 s y al volver a primer plano, si `isSafeMoment()` ⇒ guardián anti-bucle (`sessionStorage['pos.update.autoReloadAt']`, < 120 s no recarga, todo en `try/catch`) ⇒ `activateUpdate()` ⇒ `inject(RELOAD_PAGE)()`; errores con `console.warn` y reintento en el siguiente ciclo; `reloadNow()` es la única ruta de recarga iniciada por una persona y termina en `RELOAD_PAGE`. Depende de T043
- [X] T046 [US4] Hacer que `PageIntegrityService.reload()` de `../pos-heladeria/src/app/core/integrity/page-integrity.service.ts` delegue en `AppUpdateService.reloadNow()` (que activa la versión pendiente, si la hay, y termina en `RELOAD_PAGE`), resolviendo `AppUpdateService` de forma **perezosa con `Injector`** dentro de `reload()` para no crear la dependencia circular `PageIntegrityService → AppUpdateService → UpdateGateService → PageIntegrityService`; ampliar `page-integrity.service.spec.ts` con el caso "versión pendiente ⇒ se activa antes de recargar". Depende de T045
- [X] T047 [US4] Registrar el bloqueador de borrador en `../pos-heladeria/src/app/modules/tables/services/pos-terminal.store.ts`: en el constructor (~línea 347) `registerBlocker('pos-terminal-draft', () => this.hasDraft())` (`hasDraft` en ~línea 1353) y retirarlo con `DestroyRef`; sin otro cambio al store. Cubre también la orden manual, que usa su propia instancia. Depende de T043
- [X] T048 [US4] Registrar en `../pos-heladeria/src/app/app.config.ts`: `inflightRequestsInterceptor` en `withInterceptors([pageIntegrityInterceptor, inflightRequestsInterceptor, authTokenInterceptor])` (el rechazado por integridad nunca llega a contarse) y `provideAppInitializer(() => inject(AppUpdateService).start())`; no tocar `provideServiceWorker` ni `ngsw-config.json`. Depende de T044, T045
- [X] T049 [US4] Ejecutar `npx ng test --watch=false --include='src/app/core/update/**/*.spec.ts'`, `--include='src/app/core/integrity/**/*.spec.ts'` y `--include='src/app/modules/tables/services/pos-terminal.store.spec.ts'` en `../pos-heladeria`: en verde

### Verificación en vivo de User Story 4

- [X] T050 [US4] V8 (quickstart): en reposo, en cada pantalla principal (menú QR, pasos del checkout, `/dashboard`, Terminal de Mesas, Órdenes, Mesas, Caja, Inventario, Reportes, Ajustes, login) ejecutar en consola `[...document.querySelectorAll('.fixed.inset-0')].filter(e=>e.getClientRects().length)` y `document.querySelectorAll('.ng-dirty').length`; deben dar `[]` y `0`. Si alguna pantalla no los cumple, la actualización nunca se aplicaría ahí: corregir el predicado de M3/M4 o registrar la excepción en `update-gate.service.ts` y anotarlo en `specs/134-bloqueo-traduccion-automatica/baseline-suite.md`

**Checkpoint**: US1–US4 funcionan de forma independiente; la prueba real de dos despliegues queda en D4

---

## Phase 7: User Story 5 - Las etiquetas que cambian de estado nunca muestran textos acumulados (Priority: P3)

**Goal**: Que cada botón o etiqueta que alterna textos muestre solo el texto del estado actual aun con la página alterada: nivel A (todo bloque con texto suelto pasa a `<span>` propio de su rama) y nivel B (etiquetas con valor usan `[textContent]`), sin ningún cambio visible sin traductor (FR-021, FR-022).

**Independent Test**: Con la alteración simulada, alternar varias veces "Enviar pedido", "Agregar" (QR y POS), "Iniciar sesión" y "Reenviar enlace en N s": cada una muestra solo el texto del estado actual; el escáner arroja `TOTAL bloques con texto suelto: 0`.

**Criterio de cierre de cada tarea por archivo**: correr `python3 specs/134-bloqueo-traduccion-automatica/tools/scan-loose-text.py ../pos-heladeria/src/app` y repetir hasta que ese archivo ya no aparezca; el spec hermano existente debe pasar **sin modificar sus aserciones**. Solo se envuelve texto: ni clases, ni lógica, ni las ~917 interpolaciones restantes (Principio V). Un ícono junto al texto (`<app-mi-icon …/> Ingresando…`) se queda fuera del `<span>`.

### Tests for User Story 5 (escribir primero) ⚠️

- [X] T051 [US5] Crear el helper de pruebas `../pos-heladeria/src/app/testing/simulate-translation.ts`: port mínimo de [tools/simulate-translation.js](./tools/simulate-translation.js) para jsdom (`simulateTranslation(root)` envuelve cada nodo de texto en `<font><font>` y deja el original desconectado; `revert()` lo restaura). Solo para specs: no se importa desde código de producción ni usa globales de Vitest
- [X] T052 [P] [US5] Añadir a `../pos-heladeria/src/app/modules/tables/pages/checkout/transfer-details-step.component.spec.ts` un caso con `simulateTranslation`: alternar `submitting` entre "Enviando pedido…" y "Enviar pedido" N veces deja **solo** el texto del estado actual (0 apariciones de "Enviar pedido Enviar pedido"); las aserciones existentes no se modifican
- [X] T053 [P] [US5] Añadir a `../pos-heladeria/src/app/modules/auth/pages/login.component.spec.ts` el mismo caso para "Iniciar sesión" ↔ "Ingresando…" (el ícono de carga permanece)
- [X] T054 [P] [US5] Añadir a `../pos-heladeria/src/app/modules/auth/pages/forgot-password.component.spec.ts` el caso de "Reenviar enlace en N s" ↔ "Reenviar enlace" (nivel B): con los nodos envueltos, avanzar el contador de segundos muestra el N real y al llegar a 0 solo "Reenviar enlace"
- [X] T055 [P] [US5] Añadir a `../pos-heladeria/src/app/modules/tables/components/product-select.component.spec.ts` el caso de nivel B: con los nodos envueltos, pasar de cantidad 1 a 3 muestra el total nuevo en el botón, y alternar entre la etiqueta de lo que falta ("Elige una presentación"…) y "Agregar" + total muestra solo el estado actual
- [X] T056 [P] [US5] Crear `../pos-heladeria/src/app/modules/tables/components/product-select-pos.component.spec.ts` (este componente no tiene spec; usar como guía la preparación de `product-select.component.spec.ts`) con el mismo caso de nivel B del botón "Agregar" del POS

### Implementation for User Story 5 — nivel A/B por archivo (21 archivos, 55 bloques)

Las tres primeras tareas tocan archivos con etiquetas de **nivel B**; ver contracts/alternating-labels.md. En `product-select` y `product-select-pos` el botón hoy es `@if (blockingLabel(); as falta) { {{ falta }} } @else { <span>{{ initialSelection ? 'Guardar cambios' : 'Agregar' }}</span> <punto/> <span>{{ lineTotal() | money }}</span> }`: `{{ falta }}` pasa a `<span [textContent]="falta">` y los dos `<span>` con interpolación pasan a `[textContent]` (el pipe `money` se conserva literal).

- [X] T057 [P] [US5] Nivel A+B en `../pos-heladeria/src/app/modules/tables/components/product-select.component.ts` (4 bloques; el botón confirmar en ~líneas 483-490): `[textContent]` para la etiqueta que falta, la etiqueta "Agregar"/"Guardar cambios" y el total; el escáner ya no lista el archivo; sin aserciones de `product-select.component.spec.ts` modificadas
- [X] T058 [P] [US5] Nivel A+B en `../pos-heladeria/src/app/modules/tables/components/product-select-pos.component.ts` (2 bloques; el botón confirmar en ~líneas 349-356), igual que T057
- [X] T059 [P] [US5] Nivel A+B en `../pos-heladeria/src/app/modules/auth/pages/forgot-password.component.ts` (2 bloques): "Reenviar enlace en {{ remainingSeconds() }} s" ↔ "Reenviar enlace" (~líneas 82-86) usando `[textContent]` con un `computed` que arma la cadena
- [X] T060 [P] [US5] Nivel A en `../pos-heladeria/src/app/modules/tables/pages/checkout/transfer-details-step.component.ts` (2 bloques; "Enviando pedido…" / "Enviar pedido" en ~líneas 188-192)
- [X] T061 [P] [US5] Nivel A en `../pos-heladeria/src/app/modules/auth/pages/login.component.ts` (2 bloques; "Ingresando…" / "Iniciar sesión" en ~líneas 142-148, con el ícono `app-mi-icon` fuera del `<span>`)
- [X] T062 [P] [US5] Nivel A en `../pos-heladeria/src/app/modules/tables/pages/public-menu.component.ts` (4 bloques)
- [X] T063 [P] [US5] Nivel A en `../pos-heladeria/src/app/modules/products/pages/product-form.component.ts` (7 bloques)
- [X] T064 [P] [US5] Nivel A en `../pos-heladeria/src/app/modules/inventory/pages/inventory-page.component.ts` (4 bloques)
- [X] T065 [P] [US5] Nivel A en `../pos-heladeria/src/app/modules/promotions/pages/promotions-page.component.ts` (4 bloques)
- [X] T066 [P] [US5] Nivel A en `../pos-heladeria/src/app/modules/tables/pages/manual-order-page.component.ts` (4 bloques)
- [X] T067 [P] [US5] Nivel A en `../pos-heladeria/src/app/modules/products/pages/product-detail-page.component.ts` (3 bloques)
- [X] T068 [P] [US5] Nivel A en `../pos-heladeria/src/app/modules/tables/components/pos-catalog-drawer.component.ts` (3 bloques)
- [X] T069 [P] [US5] Nivel A en `../pos-heladeria/src/app/modules/tables/pages/table-sessions.component.ts` (3 bloques)
- [X] T070 [P] [US5] Nivel A en `../pos-heladeria/src/app/modules/cash-register/components/cash-arqueo-modal.component.ts` (2 bloques)
- [X] T071 [P] [US5] Nivel A en `../pos-heladeria/src/app/modules/option-groups/pages/option-groups-page.component.ts` (2 bloques; sin spec propio: verificar con el escáner y V7)
- [X] T072 [P] [US5] Nivel A en `../pos-heladeria/src/app/modules/plan/pages/plan-summary-page.component.ts` (2 bloques; sin spec propio: verificar con el escáner y V7)
- [X] T073 [P] [US5] Nivel A en `../pos-heladeria/src/app/modules/dashboard/pages/admin-dashboard.component.ts` (1 bloque)
- [X] T074 [P] [US5] Nivel A en `../pos-heladeria/src/app/modules/option-groups/components/option-form.component.ts` (1 bloque)
- [X] T075 [P] [US5] Nivel A en `../pos-heladeria/src/app/modules/tables/components/payment-attempt-review-panel.component.ts` (1 bloque)
- [X] T076 [P] [US5] Nivel A en `../pos-heladeria/src/app/modules/tables/components/pos-checkout-panel.component.ts` (1 bloque)
- [X] T077 [P] [US5] Nivel A en `../pos-heladeria/src/app/modules/tables/components/pos-order-panel.component.ts` (1 bloque)

### Verificación de User Story 5

- [X] T078 [US5] Ejecutar `python3 specs/134-bloqueo-traduccion-automatica/tools/scan-loose-text.py ../pos-heladeria/src/app` ⇒ debe imprimir `TOTAL bloques con texto suelto: 0`
- [X] T079 [US5] Revisar la salida de los 55 bloques originales con el criterio de nivel B ("alterna entre textos **y** una de sus ramas lleva un valor: precio, cantidad, segundos") y dejar escrita la lista final de etiquetas de nivel B en `specs/134-bloqueo-traduccion-automatica/contracts/alternating-labels.md`; si aparece otra además de las tres mínimas (`product-select`, `product-select-pos`, "Reenviar enlace en N s"), convertirla y cubrirla con su caso en el spec hermano
- [X] T080 [US5] Ejecutar en `../pos-heladeria` los specs hermanos de los archivos tocados (`npx ng test --watch=false --include='src/app/modules/**/<archivo>.spec.ts'` por cada uno de T057–T077 que tenga spec, más los casos nuevos de T052–T056): en verde y **sin aserciones existentes modificadas** (`git diff` de esos specs solo agrega casos)
- [X] T081 [US5] V7 (quickstart): con `__sim.translate()` alternar varias veces "Enviar pedido", "Agregar" (menú QR y POS) y "Reenviar enlace en N s" ⇒ cada etiqueta muestra **solo** el texto del estado actual (nunca "Enviar pedido Enviar pedido") y "Agregar · $ …" sigue el total real (SC-007, FR-021); sin simulador el DOM visible es idéntico al de `develop` (FR-022)

**Checkpoint**: Todas las historias funcionan de forma independiente

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Regresión global, cierre de verificación y pendientes explícitos

- [X] T082 Correr juntas todas las specs nuevas y las tocadas: `cd ../pos-heladeria && npx ng test --watch=false --include='src/app/core/integrity/**/*.spec.ts' --include='src/app/core/update/**/*.spec.ts' --include='src/app/shared/icon-mi/*.spec.ts' --include='src/app/modules/tables/services/pos-terminal.store.spec.ts'`: en verde
- [X] T083 Suite completa de `../pos-heladeria` **sola** (nunca en paralelo con la del backend) y comparación **por archivo** contra `specs/134-bloqueo-traduccion-automatica/baseline-suite.md` (T003): ningún archivo pasa de verde a rojo; los fallos preexistentes se reportan como tales, sin atribuirlos a esta feature (SC-006)
- [X] T084 `cd ../pos-heladeria && npx ng build` termina sin errores y se repiten los invariantes de T004 (`grep -rn '<font' src/ public/` vacío; sin `hyphens`/`:lang(`) y el escáner en 0
- [X] T085 Repetir V6 (cero falsos positivos) con todo implementado, ahora que existen el contador de peticiones, el `ErrorHandler` y las etiquetas nuevas: recorrido completo del menú QR, checkout y panel con extensiones habituales no relacionadas con traducción ⇒ el aviso aparece 0 veces y la consola sin errores nuevos (SC-006, FR-008, FR-022)
- [X] T086 [P] Confirmar la trazabilidad FR → decisión → código → prueba de la tabla de [plan.md](./plan.md): cada FR tiene al menos una tarea y una verificación en este archivo; anotar cualquier desvío (por ejemplo la lista final de nivel B de T079) en `plan.md` o `research.md`

### Verificación manual diferida (dispositivos reales — no automatizable aquí)

No se declaran cumplidas sin ejecutarlas; quedan como pendientes explícitos de la spec (quickstart, "Diferidas"):

- [ ] T087 D1 ([quickstart.md](./quickstart.md), "Diferidas") — Con el idioma del sistema en inglés: sin oferta de traducir en menú QR, panel e inicio de sesión, y el intento manual deja el texto sin cambios o el navegador indica que no se puede traducir (SC-001); incluir que la tarjeta "Estadísticas de ventas" muestre cifras distintas por métrica (US3 escenario 3). Dispositivos: Chrome Android, Safari iOS, Chrome y Edge de escritorio, Samsung Internet
- [ ] T088 D2 — Traducción **real** forzada (extensión que ignora el bloqueo) en Chrome/Edge reales y Firefox (solo red de seguridad): el aviso aparece y protege; confirmar qué marcas deja (`translated-*`, `<font>`, `_msttexthash`) y si el canario basta; si una extensión común dispara un falso positivo, retirar esa señal sin tocar el resto
- [ ] T089 D3 ([quickstart.md](./quickstart.md), "Diferidas") — Idioma del teléfono del caso reportado (inglés vs. español) con la declaración nueva, en el teléfono del reporte
- [ ] T090 D4 — Actualización de versión con **dos despliegues sucesivos** en un entorno con Service Worker activo (en `ng serve` está deshabilitado y un build local apuntaría a la API de producción): pestaña con la versión vieja pasa a la nueva en ≤ 5 min tras volver a primer plano, nunca durante un modal, un envío ni un pago (SC-008)
- [ ] T091 D5 — Con lector de pantalla en Chrome: el aviso se anuncia (`role="alert"`) y "Recargar" recibe el foco; ejecutar además Lighthouse de accesibilidad sobre la página con el aviso visible *(Avance 2026-10-24: Lighthouse de accesibilidad sobre el login con el aviso visible = **100** en escritorio y en móvil; el contenedor es `role="alert"` con `aria-live="assertive"` y "Recargar" recibe el foco. **Falta solo el lector de pantalla real**, por eso no se marca.)*

### Despliegue

- [ ] T092 Antes de publicar `pos-heladeria` (un solo artefacto: idioma y bloqueo viajan juntos en `index.html`, FR-002; sin despliegue de backend): avisar al dueño del **paso obligatorio de operación** — las pestañas ya abiertas antes del primer despliegue ejecutan el código anterior, que no sabe actualizarse solo, y necesitan una **recarga manual única** (p. ej. al cierre de turno); desde esa versión se actualizan solas en un momento seguro
- [ ] T093 Tras el despliegue, repetir V1 contra producción (`curl -s https://<dominio>/ | grep -Ei 'lang=|translate|notranslate'`) y dejar D4 para el siguiente despliegue

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias — empieza de inmediato
- **Foundational (Phase 2)**: depende de Setup; **bloquea** todas las historias
- **User Stories (Phase 3+)**: dependen de Foundational
  - **US1** y **US2** son independientes entre sí y pueden ir en paralelo (ambas P1)
  - **US3** depende de **US2** (amplía `protected-actions.ts`, el interceptor y su spec); solo su parte del ícono (T030, T032) es independiente
  - **US4** depende de **US2** (`altered()` para M1, ruta de recarga compartida, orden de interceptores en `app.config.ts`)
  - **US5** es independiente de las demás; el plan la deja al final por prioridad (P3)
- **Polish (Phase 8)**: depende de las historias que se quieran entregar; la suite completa y el build (T083, T084) van al final

### Within Each User Story

- Las pruebas de la historia se escriben primero y deben fallar antes de implementar
- Funciones puras → servicio → interceptor/`ErrorHandler`/componente → registro en `app.config.ts`/`app.html` → verificación en vivo
- Historia completa antes de pasar a la siguiente prioridad
- **Archivos compartidos** (no marcar [P] entre sí): `app.config.ts` (T021, T048), `protected-actions.ts` (T018, T033), `page-integrity.interceptor.spec.ts` (T013, T031), `page-integrity.service.ts` (T016, T046), `baseline-suite.md` (T003, T004, T034, T050)

### Mapa de dependencias entre tareas clave

```text
T015 ─▶ T016 ─▶ T017 ─┐
              ├─▶ T019 ◀─ T018 ─┤
              └─▶ T020 ─────────┴▶ T021 / T022 ─▶ T024 ─▶ T025…T029   (US2)
T018, T019, T013 ─▶ T031, T033 ─▶ T035 ─▶ T036                          (US3)
T016 ─▶ T043 ─▶ T044 ─┐
              ├─▶ T045 ─▶ T046 ┤
              └─▶ T047 ────────┴▶ T048 ─▶ T049 ─▶ T050                 (US4)
T051 ─▶ T052…T056 ─▶ T057…T077 ─▶ T078 ─▶ T079 ─▶ T080 ─▶ T081          (US5)
```

### Parallel Opportunities

- **Setup/Foundational**: T002 y T003 en paralelo tras T001
- **US2**: las cinco specs T010–T014 en paralelo; T018 en paralelo con T015–T017
- **US3**: T030 y T031 en paralelo; T037 y T038 en paralelo
- **US4**: las cuatro specs T039–T042 en paralelo; T044 en paralelo con T045 y T047
- **US5**: las specs T052–T056 y **las 21 ediciones de plantilla T057–T077** son de archivos distintos y van en paralelo (cada una con su criterio de cierre por archivo)
- **Entre historias**: con más de una persona, US1 + US2 en paralelo; luego US3, US4 y US5 en paralelo

---

## Parallel Example: User Story 2

```bash
# Escribir juntas las pruebas de US2 (archivos distintos):
Task: "T010 integrity-signals.spec.ts en ../pos-heladeria/src/app/core/integrity/"
Task: "T011 page-integrity.service.spec.ts en ../pos-heladeria/src/app/core/integrity/"
Task: "T012 integrity-error-handler.spec.ts en ../pos-heladeria/src/app/core/integrity/"
Task: "T013 page-integrity.interceptor.spec.ts en ../pos-heladeria/src/app/core/integrity/"
Task: "T014 page-integrity-banner.component.spec.ts en ../pos-heladeria/src/app/core/integrity/"

# Con T015–T017 en curso, el catálogo no depende de ellas:
Task: "T018 protected-actions.ts en ../pos-heladeria/src/app/core/integrity/"
```

## Parallel Example: User Story 5

```bash
# Las 21 plantillas son archivos distintos; cada una se cierra con el escáner:
Task: "T057 product-select.component.ts (nivel A+B)"
Task: "T058 product-select-pos.component.ts (nivel A+B)"
Task: "T060 transfer-details-step.component.ts (nivel A)"
Task: "T061 login.component.ts (nivel A)"
# … T062–T077 (resto de archivos de la lista del escáner)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1: Setup (rama, gate A-145, línea base)
2. Phase 2: Foundational (invariantes)
3. Phase 3: US1 — un solo archivo (`index.html`), entregable por sí solo y previene el problema de raíz
4. **DETENERSE Y VALIDAR**: T007 (V1) y T008 (total de extremo a extremo)
5. Desplegar/mostrar si se quiere; la entrega **recomendada** es US1 + US2 juntas (ambas P1: prevención + red de seguridad)

### Incremental Delivery

1. Setup + Foundational → base lista
2. **Incremento 1** = US1 (incluye el ícono, FR-006) → probar → desplegar (MVP)
3. **Incremento 2** = US2, luego US3 (catálogo del panel) → probar → desplegar
4. **Incremento 3** = US4 → probar → desplegar (recordar T092: recarga manual única de las pestañas ya abiertas)
5. **Incremento 4** = US5 → escáner en 0 → desplegar
6. Cada incremento va en commits separados y pequeños, solo cuando el usuario lo pida (Principios VI y XV); no se mezclan en un mismo commit

### Parallel Team Strategy

1. El equipo cierra Setup + Foundational junto
2. Luego: A) US1 (rápida) y B) US2 en paralelo
3. Después: A) US3, B) US4, C) US5 (las 21 plantillas se reparten por módulo)
4. Cada historia se completa y se verifica por separado

---

## Notes

- [P] = archivos distintos, sin dependencia de tareas incompletas
- [Story] mapea la tarea a su historia para trazabilidad (Principio XII)
- El backend no cambia; el bloqueo rechaza peticiones nuevas **antes** de enviarlas (Principio VII: ninguna factura ni importe histórico se lee o reescribe) y no hay migraciones (Principio VIII: N/A, rollback = revertir el despliegue del frontend)
- Ninguna dependencia nueva (Principio IX)
- Los tests `CONGELA comportamiento actual:` (`review-step.component.spec.ts`, `checkout-order-summary`) no se tocan (Principio III)
- Ediciones de plantilla (US5): solo envolver texto; sin reformatear, renombrar ni reescribir interpolaciones (Principio V)
- Verificar que las pruebas fallan antes de implementar y detenerse en cada checkpoint para validar la historia por separado
- Comentarios, specs y documentación en español de Colombia; ramas y commits en inglés, sin marcas de autoría de IA (Principios XIII y XV)
