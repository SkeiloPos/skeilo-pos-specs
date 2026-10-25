# Contrato: integridad de la página (detección, estado y aviso)

**Cubre**: FR-007 a FR-011, FR-013, FR-015, FR-017 · **Historias**: US2, US3 · **Decisiones**: [research.md](../research.md) 3 y 5

Ubicación (en `../pos-heladeria/src/app/core/integrity/`): `integrity-signals.ts`,
`page-integrity.service.ts`, `integrity-error-handler.ts`, `page-integrity-banner.component.ts`.

## `PageIntegrityService` (raíz)

```text
altered: Signal<boolean>            // true ⇔ status === 'altered'
reasons: Signal<IntegritySignalId[]>
blockedNotice: Signal<string | null>
notifyBlocked(label: string): void  // lo llama el interceptor al rechazar una acción
reportDomError(err: unknown): void  // lo llama el ErrorHandler; ignora todo lo que no sea S6
registerCanary(el: HTMLElement): void   // lo llama el banner al montarse
reload(): Promise<void>             // lo usa el botón "Recargar"
```

- Se inicia con `provideAppInitializer` (antes del primer pintado) y **evalúa de inmediato** (FR-007:
  alteración previa a la carga).
- No lanza nunca: toda lectura del DOM va protegida; si `MutationObserver` no existe (entorno de
  pruebas), solo funciona el sondeo.
- `reload()`: si `AppUpdateService` tiene una versión pendiente la activa primero; después
  `inject(RELOAD_PAGE)()` (token de `core/reload-page.ts`: `location.reload()` en producción, sustituible en pruebas). **Nunca se invoca sin una acción de la persona** (FR-017).

## Señales

Un cambio a "alterada" ocurre si **al menos una** está activa. Las comprobaciones son exactas, no
"algo cambió".

| Id | Señal | Comprobación exacta | Latched |
|---|---|---|---|
| S1 `html-class` | clase de traductor en `<html>` | `documentElement.classList.contains('translated-ltr') \|\| …('translated-rtl')` | no |
| S2 `html-lang` | idioma declarado cambiado | `lang !== '' && !/^es(-|$)/i.test(lang)` (un `lang` ausente o vacío **no** dispara: ningún traductor lo deja vacío, y el documento de las pruebas no declara idioma) | no |
| S3 `font-wrapper` | envoltorio de traductor | `document.getElementsByTagName('font').length > 0` | no |
| S4 `ms-translator-attr` | marcas de Microsoft Translator | `document.querySelector('[_msttexthash],[_msthash]') !== null` | no |
| S5 `canary` | contenido de la app reescrito | el canario registrado existe y `!(textNode.isConnected && textNode.parentNode === el && textNode.nodeValue === CANARY_TEXT)` (o `!el.isConnected`) | no |
| S6 `dom-error` | error de DOM atribuible | `err instanceof DOMException && err.name === 'NotFoundError' && /removeChild\|insertBefore/.test(err.message)` | **sí** |

- El canario no se evalúa hasta que el banner se registre; S1–S4 y S6 funcionan desde el arranque.
- La app **no usa** `<font>` en ninguna plantilla (hoy `grep` limpio); si algún día se añadiera,
  S3 lo detectaría como falso positivo: el `grep '<font' src/` de la revisión de cada cambio
  protege ese invariante (resultado esperado: vacío).
- Ningún error de red, validación, `4xx/5xx` o excepción genérica activa S6 (FR-008).

## Cuándo se evalúa

| Disparador | Qué evalúa |
|---|---|
| Arranque (initializer) | todas las señales disponibles |
| `MutationObserver` en `<html>` (`attributes`: `class`, `lang`, `translate`; sin `subtree`) | S1, S2 |
| `MutationObserver` en el canario (`childList`, `characterData`, `subtree`) | S5 |
| `setInterval` de 1500 ms, **solo con `document.visibilityState === 'visible'`** | todas |
| `visibilitychange` (a visible) y `pageshow` | todas |
| `reportDomError` | S6 (y reevalúa) |

Peor caso de detección ≈ 1,5 s (< 3 s, SC-003). **No** hay observadores de `subtree` sobre `body`.

## Histéresis (FR-010)

- `intact → altered`: inmediato (también desde un observador).
- `altered → intact`: solo si **dos evaluaciones consecutivas** dan 0 señales activas y no hay
  `latched`. Entonces se limpia `blockedNotice`. **Solo cuentan** las evaluaciones del arranque, del sondeo,
  de `visibilitychange` y de `pageshow`: las que disparan los observadores pueden subir a "alterada" al
  instante, pero no adelantan la vuelta a "íntegra" (si no, las dos evaluaciones limpias caerían en el
  mismo milisegundo y la histéresis no serviría).

## `ErrorHandler` — `IntegrityAwareErrorHandler`

Extiende el comportamiento por defecto de Angular (sigue llamando a `console.error`) y, antes,
pasa el error a `PageIntegrityService.reportDomError`. Registrado como `{ provide: ErrorHandler,
useClass: IntegrityAwareErrorHandler }` en `app.config.ts`. No traga ni transforma errores.

## `PageIntegrityBannerComponent`

Se monta **una vez**, en `app.html`, después del `<router-outlet>` (cubre todas las rutas del
alcance). Selector `app-page-integrity-banner`, `OnPush`.

| Aspecto | Contrato |
|---|---|
| Visibilidad | solo cuando `altered()`; no tiene botón de cerrar ni se descarta con Escape/clic fuera (FR-009) |
| Posición | `fixed inset-x-0 top-0`, `z-[100]` (por encima de `z-[90]` del diálogo de confirmación y de `z-50` de los modales), `print:hidden` |
| ARIA | contenedor `role="alert"` (`aria-live="assertive"`); el botón "Recargar" recibe el foco al aparecer |
| Texto principal | **"La página fue alterada por el navegador"** |
| Texto de apoyo | "Parece que el navegador o una extensión (por ejemplo, la traducción automática) cambió lo que ves. Puede no coincidir con tu pedido, por eso enviar el pedido y pagar están bloqueados. Recarga para continuar: lo que ya enviaste no se pierde." |
| Línea de acción bloqueada | si `blockedNotice()`: "No se pudo {etiqueta}: la página está alterada. Recarga para continuar." |
| Botón | **"Recargar"** → `integrity.reload()` |
| Estructura | cada texto en su propio elemento (`<p>`, `<span>`); **ningún texto suelto dentro de bloques `@if`** (cumple FR-021 el propio banner); la línea de acción bloqueada se pinta con `[textContent]`. El título y "Recargar" van **en la misma fila** (el aviso es fijo y tapa lo que hay debajo: así ocupa lo menos posible en un teléfono) |
| Canario | `<span class="sr-only print:hidden" aria-hidden="true" data-integrity-canary>` siempre presente (no dentro del `@if`), con el texto `CANARY_TEXT` = "Contenido de la aplicación"; se registra con `registerCanary` en `afterNextRender` |

Mientras el aviso está visible, "lo demás de la pantalla puede seguir visible, con datos
posiblemente desfasados" (Assumption de la spec): el aviso y el bloqueo son la garantía.

## Recuperación tras "Recargar" (FR-015/FR-016, SC-005)

No hay persistencia nueva. Reutiliza: token del comensal en `localStorage`
(`pos.diner.session_token`), carrito y pedidos enviados en el servidor, `checkoutHydrationGuard`
(spec 034) para volver al paso correcto, y los tokens del personal en `TokenStorageService`. Lo no
confirmado (modal de producto abierto) se pierde.

## Pruebas

| Prueba | Tipo |
|---|---|
| Cada señal S1–S5 por separado ⇒ `altered`; sin señales ⇒ `intact` | unitaria (`integrity-signals.spec.ts`, `page-integrity.service.spec.ts`) |
| Arranque con `<html class="translated-ltr">` o `lang="en"` ⇒ `altered` en la primera evaluación | unitaria |
| Histéresis: 1 evaluación limpia ⇒ sigue `altered`; 2 ⇒ `intact`; `latched` ⇒ nunca | unitaria |
| `reportDomError`: `NotFoundError`+`removeChild`/`insertBefore` ⇒ S6; `TypeError`, `HttpErrorResponse` 401/404/409/500, `Error('network')` ⇒ ignora | unitaria (`integrity-error-handler.spec.ts`) |
| Sin traductor, recorrido con interacciones normales y errores de red ⇒ 0 avisos | unitaria + en vivo (quickstart V6) |
| Banner: oculto íntegro; visible alterado con `role="alert"`, sin control de cierre, botón "Recargar" enfocado; `blockedNotice` se muestra | unitaria (`page-integrity-banner.component.spec.ts`) |
| Traductor simulado ⇒ aviso < 3 s en cada pantalla de SC-003 | en vivo (quickstart V2–V4) |
