# Research: Bloqueo de la Traducción Automática y Aviso de Página Alterada

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Fecha**: 2026-10-24

Todas las referencias de código son a `../pos-heladeria` (rama base `develop`). El backend
(`pos-backend`) **no se toca**. Ninguna decisión depende de que un traductor real esté disponible
en el entorno de desarrollo (no se puede disparar desde automatización); lo que solo se puede
confirmar con traducción real queda marcado como **verificación manual diferida** (ver
[quickstart.md](./quickstart.md), sección "Diferidas").

## Hechos verificados en esta fase

| Hecho | Cómo se verificó |
|---|---|
| La app es **zoneless** (sin `zone.js`); los cambios de señales programan la detección de cambios solos, así que un `MutationObserver`/`setInterval` puede escribir señales sin disparar ciclos innecesarios | `grep zone.js` en `angular.json`, `package.json`, `src/` → vacío; `shift-sales-report-card.component.spec.ts` lo confirma ("sin zone.js no hay `whenStable`") |
| `src/index.html` es la **única** plantilla de documento (no hay SSR ni prerender; `index.csr.html` en `ngsw-config.json` es una entrada heredada que no existe en el build) | `angular.json` (`@angular/build:application`, sin `ssr`/`prerender`); `src/` solo contiene `index.html` |
| `<html lang="en">` hoy; no existe `translate=`, `notranslate` ni `<font` en ninguna plantilla | `grep` sobre `src/` y `public/` |
| Tres sistemas de íconos: `app-icon` (SVG inline, inmune), `app-icon-lucide` (SVG, inmune) y **`app-mi-icon`** (ligadura de fuente = **texto traducible**), este último con **147 usos** pero **un único punto de render** (`shared/icon-mi/icon-mi.component.ts`, `<span class="material-icons-outlined">{{ ligature }}</span>`) | lectura del componente + `grep` de `material-icons-outlined` (solo ese componente y sus specs) |
| El Service Worker se registra como `push-sw.js` (envuelve `ngsw-worker.js`) con `registerWhenStable:30000`; **nadie usa `SwUpdate`** (solo `SwPush`) | `app.config.ts`, `grep SwUpdate src/` |
| Los modales son divs ad hoc `fixed inset-0` en **35 archivos**; solo 3 archivos usan `role="dialog"`/`aria-modal` → no se puede detectar "modal abierto" por rol ARIA | `grep` en `src/app` |
| Hay un único `HttpInterceptorFn` (`authTokenInterceptor`, patrón: filtra por `environment.apiBaseUrl` y por ruta) registrado en `provideHttpClient(withInterceptors([...]))` | `app.config.ts`, `core/auth/auth-token.interceptor.ts` |
| Los mensajes de error de los servicios (`extractError` de `DiningSessionService`, `DinerService`, etc.) leen `HttpErrorResponse.error.detail` como cadena; solo el comensal trata el `401` (→ sesión caducada) y `429`. Ningún código ramifica por `423` | lectura de `diner.service.ts`, `dining-session.service.ts`; `grep status === 423` → vacío |
| El borrador de la Terminal y de la orden manual vive **solo en memoria** (`PosTerminalStore.draftLines`/`hasDraft`, sin `localStorage`), y la orden manual usa su propia instancia del store | `pos-terminal.store.ts:418,1353`; sin `localStorage` en el store |
| El escáner de la fase de plan encuentra **55 bloques en 21 archivos** con texto suelto (la spec habla de 47: distinta metodología, la spec dice "al menos") | `tools/scan-loose-text.py` |
| Chromium documenta `<meta name="google" content="notranslate">` como la forma de desactivar la oferta de traducción | [Chromium Translate design doc](https://www.chromium.org/developers/design-documents/translate/) |
| La combinación `lang` + elemento canario es una técnica ya usada para detectar traducción del lado del cliente | paquete [`detect-translation`](https://github.com/ClaudiuCeia/detect-translation) (documentación) |

**No se pudo confirmar con fuente en esta fase** (conocimiento previo; se confirma en la
verificación manual diferida): que Chrome/Edge respeten `translate="no"` en `<html>` heredado a
overlays; que Chrome añada `class="translated-ltr|rtl"` y cambie `lang` en `<html>`; que Edge deje
atributos `_msttexthash`/`_msthash`; el soporte en Safari iOS y Samsung Internet. **El diseño de
detección no depende de ninguna de esas marcas**: el canario estructural (Decisión 3) detecta el
mecanismo real (el nodo de texto original queda desconectado), que es lo que se midió en la
reproducción.

---

## Decisión 1 — Declarar `lang="es"` y bloquear la traducción en un solo punto: `src/index.html`

**Decisión**: en `src/index.html`, el elemento raíz pasa a `<html lang="es" translate="no" class="notranslate">`
y se añade `<meta name="google" content="notranslate">` en `<head>`. Es un único archivo y un único
cambio, así que FR-002 (idioma declarado *junto con* el bloqueo) se cumple por construcción: no hay
forma de desplegar lo uno sin lo otro.

**Razón**:
- `translate="no"` en `<html>` se hereda a todo el documento, **incluidos los diálogos y capas
  superpuestas** que Angular/CDK monta en `<body>` fuera de `app-root` (FR-003). Ponerlo solo en
  `app-root` o en el layout dejaría fuera esas capas.
- `class="notranslate"` es la convención de Google que respetan además los servicios que no
  implementan la herencia del atributo.
- El meta `google/notranslate` es lo único confirmado por fuente: desactiva la oferta de Chrome y
  hace que el intento manual indique que no se puede traducir (FR-004, FR-005).
- `lang="es"` corrige la declaración errónea actual (`en`), que puede hoy provocar ofertas de
  traducción en teléfonos en español (Assumption de la spec, no verificado).
- El script inline del tema (spec 116) escribe `document.documentElement.dataset.theme`; no toca
  `class` ni `lang`, así que no hay conflicto.

**Alternativas descartadas**:
- Solo `lang="es"`: aumentaría las ofertas de traducción en teléfonos en inglés (lo prohíbe FR-002).
- `translate="no"` solo en `app-root`: no cubre overlays en `<body>`.
- `Content-Language` por cabecera HTTP: es configuración de Vercel/Cloudflare fuera del repo y no
  aporta sobre el meta + atributo.
- Declarar el idioma desde Angular (`DOCUMENT.documentElement.lang = 'es'`): llega tarde (después
  del primer pintado), y el navegador decide la oferta al cargar.

## Decisión 2 — Íconos: `translate="no"` explícito en el único componente de ligaduras

**Decisión**: `IconMiComponent` marca su `<span class="material-icons-outlined">` con
`translate="no"` y la clase `notranslate`. Los otros dos sistemas (`app-icon`, `app-icon-lucide`)
son SVG y no se tocan.

**Razón**: FR-006/SC-009. Aunque la herencia desde `<html>` ya debería cubrirlo, el texto de la
ligadura (`shopping_cart`, `delete`…) es exactamente lo que un traductor convierte en palabras; un
traductor que no implemente la herencia seguiría rompiéndolo. Es un único punto con 147 usos: costo
mínimo, cobertura total.

**Alternativa descartada**: tocar los 147 usos o cambiar la fuente a SVG: refactor fuera de alcance
(Principio V).

## Decisión 3 — Detección: marcas conocidas + canario estructural + error de DOM atribuible

**Contexto**: la reproducción demostró que el fallo dominante es **silencioso** (0 excepciones): el
traductor reemplaza cada nodo de texto por `<font>` y deja el original desconectado; Angular sigue
escribiendo en el nodo desconectado. Un aviso basado en capturar errores no se dispararía.

**Decisión**: `PageIntegrityService` evalúa un conjunto cerrado de señales; el estado es
**"alterada" si al menos una está activa**:

| # | Señal | Qué detecta | Tipo |
|---|---|---|---|
| S1 | `<html>` con clase `translated-ltr` o `translated-rtl` | Google Translate / Chrome | marca |
| S2 | `<html lang>` distinto de `es`/`es-*` | cualquier traductor que cambie el idioma declarado | marca |
| S3 | algún elemento `<font>` en el documento | envoltorio que insertan los traductores de Google (la app no usa `<font>`) | marca |
| S4 | algún elemento con atributo `_msttexthash` o `_msthash` | Microsoft Translator (Edge) | marca |
| S5 | **canario**: el nodo de texto que la app escribió en un elemento oculto ya no está conectado a su elemento, o su texto cambió | cualquier traductor que **reemplace o reescriba** el contenido, sin depender de marcas | estructural |
| S6 | error de DOM atribuible (`NotFoundError` de `removeChild`/`insertBefore`) llegado al `ErrorHandler` (FR-011) | la app intentó quitar/insertar un nodo cuyo padre fue cambiado por fuera | error (latched) |

**Razón**:
- S1–S4 son baratas y explícitas, pero son marcas **conocidas, no garantizadas** (no confirmadas
  con fuente, y un traductor nuevo puede no dejarlas).
- S5 detecta el **mecanismo** medido en la reproducción, no una marca: si el traductor reemplaza el
  nodo de texto del canario (o lo reescribe), `isConnected`/`nodeValue` lo delatan. El canario es un
  `<span>` visualmente oculto con `aria-hidden="true"` y una frase corta en español que **la propia
  app renderiza una sola vez** (nadie más lo toca ni Angular lo reescribe), así que no puede dar
  falsos positivos por errores de la app. Comparte el destino del resto del texto: con
  `translate="no"` respetado, no se traduce nada y el canario queda íntegro; con un traductor que
  lo ignora, el canario cae junto con el resto.
- S6 cubre FR-011: el único caso donde el error SÍ ocurre. Es **latched** (no se auto-limpia: el
  DOM quedó inconsistente) y se acota por tipo+mensaje de `DOMException` para que ningún error de
  red/validación/4xx/5xx lo dispare (FR-008).
- **Falsos positivos (FR-008, cero)**: ninguna señal es "algo cambió en el DOM". Gestores de
  contraseñas, correctores y bloqueadores no añaden `<font>`, no cambian `lang` ni tocan el canario.
  S1/S2 se leen solo de `<html>` con una comprobación exacta (no "cualquier clase nueva").

**Cómo se evalúa (sin observar todo el DOM)**:
- `MutationObserver` sobre `<html>` solo para atributos `class`/`lang`/`translate` (sin `subtree`),
  y sobre el canario (`childList`, `characterData`, `subtree` de ese `<span>`): disparan una
  evaluación inmediata y son prácticamente gratis.
- Una evaluación completa cada 1,5 s **solo con la pestaña visible**, más una al volver a primer
  plano (`visibilitychange`) y al `pageshow`: cubre S3/S4 (que requieren recorrer el documento) y es
  la red de seguridad para cualquier observador perdido. El peor caso de detección es ~1,5 s < 3 s
  (SC-003).
- Se **descartó** observar `childList`+`subtree` en todo `body`: en una app que re-renderiza tablas,
  gráficos y polling continuamente, procesar cada registro de mutación cuesta más que el sondeo de
  1,5 s y no mejora la latencia exigida.
- Arranque (FR-007, "antes de que la app termine de cargar"): el servicio se inicia con
  `provideAppInitializer` (antes del primer pintado) y evalúa de inmediato; S1/S2 ya se ven en ese
  momento. El canario se suma cuando el banner se monta.

**Histéresis (FR-010)**: pasar a "alterada" es inmediato; volver a "íntegra" exige que las señales
no latched estén apagadas en **dos evaluaciones consecutivas** (~3 s) para no parpadear mientras el
traductor está revirtiendo. Si el canario sigue roto tras revertir (nodos huérfanos), el aviso se
mantiene hasta recargar (caso explícito de la spec).

**Alternativas descartadas**:
- Detectar solo por errores (premisa del brief): descartada por la evidencia (0 errores en el caso
  dominante).
- Solo marcas (S1–S4): frágil ante traductores sin marcas (Safari/Samsung/extensiones).
- Sonda dinámica (cambiar un valor interpolado y comprobar que la pantalla lo refleja): detecta lo
  mismo que el canario estructural pero obliga a ciclos de detección de cambios periódicos; más
  complejidad sin ganancia.
- Heurística de "texto cambió en muchos nodos": riesgo de falsos positivos con extensiones.

## Decisión 4 — Protección de acciones: un interceptor HTTP con catálogo, no botones deshabilitados

**Decisión**: un `HttpInterceptorFn` (`pageIntegrityInterceptor`) rechaza **antes de enviar** toda
petición del catálogo de acciones protegidas ([contracts/protected-actions.md](./contracts/protected-actions.md))
mientras el estado sea "alterada". El rechazo es un `HttpErrorResponse` con
`status: 423`, `error: { detail: <mensaje en español>, code: 'page_altered' }`: el `extractError`
que ya usa cada pantalla lo muestra sin código nuevo en ellas. Además notifica al banner
(`notifyBlocked(etiqueta)`) que muestra, con `role="alert"`, "No se pudo {acción}: la página está
alterada. Recarga para continuar.", aunque la pantalla de origen no mostrara su propio error.

**Razón**:
- **Es la única forma de que ninguna superficie "se olvide"** (la memoria del proyecto documenta que
  las specs de cobro olvidan sistemáticamente "Pagos por confirmar"): el catálogo es por endpoint,
  una lista finita y revisable, no por botón (~15 sitios en 8 componentes).
- Cumple FR-013 sin botones deshabilitados mudos: la acción **se puede intentar** y el rechazo
  explica por qué y qué hacer; el banner, siempre visible, lo respalda.
- Cumple FR-014: solo afecta peticiones **que aún no salieron**; las ya enviadas siguen su curso
  (sin cancelar ni duplicar). El rechazo ocurre antes de cualquier efecto en servidor.
- `423` (Locked) no lo ramifica ningún código existente (a diferencia de 401/409/422/429), por lo
  que ningún flujo lo reinterpreta ("sesión caducada", "versión desactualizada"…).

**Riesgo residual (documentado, aceptado)**: una operación de la Terminal con dos peticiones
seguidas (`POST /orders` → `checkout-and-send`) podría detectarse alterada entre ambas; la segunda
se rechaza y queda un pedido retenido (`hold_for_payment`, sin cocina ni inventario, estado que el
sistema ya soporta). Es una ventana de microtareas, no cancela ni duplica dinero.

**Alternativas descartadas**:
- Directiva/`[disabled]` por botón: ~15 sitios que mantener; un botón nuevo o una superficie
  olvidada queda sin proteger (el modo de fallo conocido del proyecto); además dejaría botones
  deshabilitados sin explicación propia (FR-013).
- Guardia en cada store/servicio: mismos sitios que la directiva, otro lugar.
- Bloquear todos los `POST/PUT/PATCH/DELETE`: rompe `leave`, cierre de sesión, cancelaciones y
  edición de catálogo, que no son del alcance de FR-012.

## Decisión 5 — El aviso: un componente raíz, no descartable, por encima de todo

**Decisión**: `PageIntegrityBannerComponent` se monta **una vez en `app.html`**, fuera del
`<router-outlet>`, así cubre menú QR, checkout, `/dashboard`, `/super-admin`, login, recuperación y
cambio de contraseña (FR-003 de alcance). Es una barra `fixed` superior con `z-index` por encima del
diálogo de confirmación (`z-[90]`) y de los modales (`z-50`), `role="alert"`, `print:hidden`, sin
botón de cerrar, y un único botón **"Recargar"**. Copy exacto en
[contracts/page-integrity.md](./contracts/page-integrity.md). El texto del banner vive en elementos
propios (nunca texto suelto en un bloque `@if`), de modo que el propio banner cumple FR-021.

**"Recargar" (FR-015/FR-017)**: recarga la dirección actual (`location.reload()`); si el Service
Worker ya descargó una versión nueva, la activa primero para que la recarga entre ya en la versión
nueva. Es siempre una acción de la persona: **el sistema nunca recarga solo por una alteración**
(si el navegador vuelve a traducir tras recargar, el aviso reaparece y la persona decide; sin
bucle).

**Conservación tras recargar (FR-015/FR-016, SC-005)**: no se construye persistencia nueva. El token
del comensal vive en `localStorage` (`pos.diner.session_token`), el carrito y los pedidos enviados
están en el servidor, y `checkoutHydrationGuard` (spec 034) devuelve al paso correcto del checkout;
la sesión del personal vive en `TokenStorageService`. Lo no confirmado (modal de producto abierto)
se pierde, como acepta la spec.

## Decisión 6 — Actualización de versión: `SwUpdate` mínimo, con "momento seguro" genérico

**Decisión**: `AppUpdateService` (raíz, iniciado por `provideAppInitializer`) hace:
1. Si `SwUpdate.isEnabled` es falso (desarrollo), no hace nada.
2. Cuando el Service Worker está activo (`navigator.serviceWorker.ready`, con tope de espera, porque
   el registro es `registerWhenStable:30000`) llama a `checkForUpdate()`; lo repite cada vez que la
   pestaña vuelve a primer plano (FR-018), con un mínimo de 60 s entre comprobaciones.
3. Escucha `versionUpdates` (`VERSION_READY`) y `unrecoverable`: ambos dejan una actualización
   **pendiente**.
4. Con una pendiente, evalúa el **momento seguro** cada 15 s y al volver a primer plano y, cuando
   se cumple, hace `activateUpdate()` y recarga (FR-019). Aplicarla con la pestaña oculta es
   válido: nadie ve la recarga y las condiciones M1–M6 siguen protegiendo lo que importa.

**Momento seguro (lista definitiva que pide el plan)**. Es seguro solo si se cumple **todo**:

| # | Condición | Cómo se evalúa | Cubre (FR-019) |
|---|---|---|---|
| M1 | la página **no** está alterada | `PageIntegrityService.altered()` | prioridad del aviso; evita bucle traducción↔recarga |
| M2 | **ninguna** petición de escritura en vuelo (POST/PUT/PATCH/DELETE) | contador del interceptor `inflightRequestsInterceptor` | "envío o pago en curso" (y cualquier otra escritura) |
| M3 | **ningún** overlay visible: elemento `.fixed.inset-0` con `getClientRects().length > 0` | consulta al DOM | "modal de selección de producto abierto" (QR y POS) y todo modal/telón/cajón |
| M4 | **ningún** control Angular sucio: `.ng-dirty` en el documento | consulta al DOM | "formularios con datos sin guardar" |
| M5 | **ningún** campo de texto con foco y valor | `document.activeElement` | quien está escribiendo en un campo sin formulario Angular |
| M6 | **ningún** bloqueador registrado activo | `UpdateGateService.registerBlocker(name, predicate)` | borrador sin enviar de la Terminal y de la orden manual (`PosTerminalStore.hasDraft()`), que **solo vive en memoria** |

**Razón**: M2–M5 son genéricos (cero cambios en las ~35 pantallas con modal); solo el borrador de la
Terminal necesita registro explícito (M6) porque no es un formulario ni un overlay. Es conservador:
ante la duda espera, nunca recarga. Verificación obligatoria (quickstart V8): en reposo, ninguna
pantalla principal debe coincidir con M3/M4, o la actualización nunca se aplicaría ahí.

**Guardián anti-bucle**: antes de recargar por versión se escribe `pos.update.autoReloadAt`
(`sessionStorage`); si hay una marca de menos de 2 min no se vuelve a recargar solo (un despliegue
roto que siempre reporte "versión nueva" no puede dejar la pestaña recargando).

**Plazo (SC-008)**: se mantiene 5 min. Peor caso razonable: comprobación al volver a primer plano
(inmediata) + descarga (segundos) + espera del siguiente ciclo de 15 s. El plazo solo se incumple si
la persona permanece indefinidamente en un estado no seguro, que es exactamente lo que se quiere.

**Limitación del primer despliegue (hallazgo importante)**: las pestañas **ya abiertas** cuando se
publique este arreglo ejecutan el JavaScript anterior, que **no contiene** `AppUpdateService`; no
pueden actualizarse solas. Los terminales POS con pestañas de días necesitan **una recarga manual**
(p. ej. al cierre de turno) tras el primer despliegue; a partir de esa versión se actualizan solos.
Se anota en el plan como paso de despliegue y en el resumen al dueño; no se resuelve desde el
Service Worker (forzar `client.navigate` desde `push-sw.js` interrumpiría operaciones, contra FR-019).

**Alternativas descartadas**:
- `navigationRequestStrategy: freshness` en `ngsw-config.json`: serviría el `index.html` nuevo en
  cada navegación, pero (a) no resuelve el caso real —una pestaña que lleva días abierta **no
  navega**, así que la estrategia nunca se aplica— y (b) cambia el comportamiento de carga de toda
  la app (red primero en cada navegación) por un problema que `SwUpdate` resuelve de forma acotada.
- Recargar al detectar la versión sin condiciones: puede ocurrir con un cobro en curso.
- Un `<dialog>`/aviso "hay una versión nueva, recarga": pasa la responsabilidad a un terminal
  desatendido.
- Reintentar `checkForUpdate()` por temporizador fijo: la spec pide al arrancar y al volver a primer
  plano; un temporizador extra no la mejora.

## Decisión 7 — Etiquetas que alternan: `<span>` por rama y, si llevan un valor, `[textContent]`

**Contexto**: cuando un `@if/@else` contiene texto suelto, Angular solo conoce los nodos que él
creó; el traductor envuelve ese texto en `<font>` y, al cambiar de rama, el texto de la rama
anterior no se quita ("Enviando pedido… Enviar pedido Enviar pedido"). Si el texto vive dentro de un
elemento propio de cada rama, Angular quita el elemento completo.

**Decisión (dos niveles, ambos con el escáner como criterio)**:
- **Nivel A — todos los bloques que arroja `tools/scan-loose-text.py` (55 en 21 archivos hoy)**:
  el texto suelto de cada rama pasa a un `<span>` propio de esa rama. Cambio mecánico, sin efecto
  visual (`<span>` en línea ≡ texto en línea; en un contenedor flex, un nodo de texto anónimo y un
  `<span>` son ambos un único ítem). Criterio de cierre: el escáner arroja **0**.
- **Nivel B — etiquetas alternantes que además incluyen un valor dinámico** (p. ej.
  "Agregar · $ 45.000" en `product-select` y `product-select-pos`, "Reenviar enlace en N s"): el
  `<span>` usa `[textContent]="etiqueta()"` con una señal/`computed` que arma la cadena. Un binding
  `textContent` **reemplaza todos los hijos del elemento** cada vez que cambia el valor, así que
  aunque el traductor haya envuelto el contenido en `<font>`, la pantalla vuelve a mostrar el valor
  real. Solo con Nivel A, un `{{ total }}` dentro de la misma rama seguiría desfasado (la rama no
  cambia al subir la cantidad), y US5/escenario 2 exige "solo el texto del estado actual".

**Razón de alcance**: FR-021/SC-007. **No** se reescriben las ~917 interpolaciones: para ellas la
garantía es el aviso + el bloqueo (US2), como dice la spec ("no sustituye al bloqueo ni al aviso").
La lista exacta de nivel B se fija al implementar a partir del escáner con el criterio "alterna
entre textos **y** incluye un valor".

**Alternativas descartadas**: `translate="no"` por etiqueta (redundante con `<html>`); reemplazar todo
con `[textContent]` (cambio masivo, Principio VI); `@for` con `track` por valor para forzar la
recreación (truco opaco).

## Decisión 8 — Registro de decisiones de negocio (Principio II)

Las tres decisiones de comportamiento que cambian (bloqueo de acciones con página alterada;
recarga automática en momento seguro; el comensal que no lee español ya no puede traducir el menú)
se registran como **A-145** en `specs/000-reconocimiento/registro-de-anomalias.md` **durante esta
fase**, antes de implementar (se hizo al cerrar el plan). Quién: Leonardo Gómez (dueño del
producto). Cuándo: 2026-10-24. No hay tests `CONGELA comportamiento actual:` en las pantallas que se
tocan (los dos del frontend están en `checkout-order-summary` y `review-step`, que no cambian).

## Decisión 9 — Pruebas y verificación

- **Unitarias (Vitest/jsdom, automáticas)**: señales puras (`integrity-signals`), servicio de
  integridad (histéresis, latched, canario, arranque ya alterado), interceptor (cada fila del
  catálogo se rechaza alterada y pasa íntegra; las "evaluadas y no protegidas" pasan siempre; las
  ya enviadas no se tocan), `ErrorHandler` (solo `DOMException` `NotFoundError` de
  `removeChild`/`insertBefore`), banner (a11y, copy, no descartable), `AppUpdateService` con
  `SwUpdate` simulado (cada condición del momento seguro, guardián anti-bucle, prioridad de la
  alteración), `IconMiComponent` (`translate="no"`), y por cada plantilla modificada su spec
  existente debe seguir pasando.
- **En vivo (automatizable, Chrome de escritorio)**: traductor simulado ([tools/simulate-translation.js](./tools/simulate-translation.js))
  sobre menú QR, checkout y panel (quickstart V2–V7).
- **Diferida (manual, dispositivos reales)**: traducción real en Chrome Android, Safari iOS, Chrome
  y Edge de escritorio y Samsung Internet; Firefox solo red de seguridad; actualización de versión
  con dos despliegues sucesivos (el Service Worker está deshabilitado en `ng serve`, y un build de
  producción local apuntaría a la API de producción: `environment.ts`).

## Resumen de decisiones abiertas

Ninguna `NEEDS CLARIFICATION` queda sin resolver. Un punto de **negocio** a confirmar con el dueño,
sin bloquear el plan: la frontera del conjunto de acciones protegidas
([contracts/protected-actions.md](./contracts/protected-actions.md)) — se incluyó "agregar productos a
un pedido existente" (armado de la Terminal) y se dejaron fuera las anulaciones/adiciones/rechazos;
mover cualquiera de ellas es editar una fila del catálogo.
