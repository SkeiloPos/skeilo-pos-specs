# Implementation Plan: Bloqueo de la Traducción Automática del Navegador y Aviso de Página Alterada

**Branch**: `fix/134-block-browser-translation` (a crear en `pos-heladeria` desde `develop` antes de tocar código, Principio XIV) | **Date**: 2026-10-24 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/134-bloqueo-traduccion-automatica/spec.md`

## Summary

La traducción automática del navegador reemplaza cada nodo de texto de la página por una copia y
deja el original desconectado; Angular sigue escribiendo en el nodo huérfano, así que la pantalla
queda desfasada **sin ningún error** (cantidades, totales, contadores, textos de botones). El plan
ataca el problema en tres capas, todas en el frontend `pos-heladeria` (el backend no cambia):

1. **Prevenir** (US1/US3): `src/index.html` declara `lang="es"`, `translate="no"` (en `<html>`, para
   heredarse a overlays) y `<meta name="google" content="notranslate">` en un único cambio atómico
   (FR-002); el único componente de íconos con texto (`app-mi-icon`, 147 usos) se marca
   `translate="no"`.
2. **Detectar y proteger** (US2/US3): un `PageIntegrityService` detecta la alteración por marcas
   (clase `translated-*`, `lang`, `<font>`, atributos de Microsoft Translator) **y por un canario
   estructural** (el nodo de texto que la app escribió en un elemento oculto deja de estar
   conectado), más los errores de DOM atribuibles; no depende de capturar errores porque el caso
   dominante no tiene ninguno. Un banner raíz no descartable ofrece "Recargar", y un interceptor
   HTTP con un catálogo de 14 acciones protegidas (por endpoint, no por botón) rechaza el envío del
   pedido, el pago y sus equivalentes del POS hasta recargar.
3. **Llegar a las pestañas largas** (US4): `AppUpdateService` (`SwUpdate`) comprueba versión al
   arrancar y al volver a primer plano y la aplica recargando solo en un "momento seguro" genérico
   (sin escrituras en vuelo, overlays, controles sucios, campo con foco ni borrador sin enviar).

Además (US5), las 55 ramas `@if/@else` con texto suelto (21 plantillas) pasan a `<span>` propios y
las etiquetas alternantes con valor (p. ej. "Agregar · total") usan `[textContent]` para reflejar
siempre el estado real.

## Technical Context

**Language/Version**: TypeScript ~5.9, Angular 21.2 (standalone, signals, **zoneless**), Tailwind 4

**Primary Dependencies**: `@angular/service-worker` (`SwUpdate`, ya instalado y usado para `SwPush`), `@angular/common/http` (interceptores funcionales), `MutationObserver`/`sessionStorage` nativos — **ninguna dependencia nueva** (Principio IX)

**Storage**: N/A en servidor. Estado transitorio en señales; una sola clave `sessionStorage` (`pos.update.autoReloadAt`, guardián anti-bucle)

**Testing**: Vitest vía `ng test` (jsdom) — specs nuevas por módulo + `HttpTestingController` para el interceptor (patrón de `auth-token.interceptor.spec.ts`); verificación en vivo con Chrome + traductor simulado ([tools/simulate-translation.js](./tools/simulate-translation.js)); escáner de plantillas ([tools/scan-loose-text.py](./tools/scan-loose-text.py)); verificación en dispositivos reales **diferida** (traducción real, Safari iOS, Samsung Internet, Edge, actualización con dos despliegues)

**Target Platform**: navegadores mínimos Chrome Android, Safari iOS, Chrome y Edge de escritorio, Samsung Internet (Firefox: solo red de seguridad)

**Project Type**: Web application (frontend `pos-heladeria`; `pos-backend` sin cambios)

**Performance Goals**: aviso en < 3 s tras la alteración (SC-003, peor caso de sondeo ≈ 1,5 s); sin observadores `subtree` sobre `body`; evaluación periódica solo con la pestaña visible

**Constraints**: cero falsos positivos en uso normal (FR-008) y cero cambios visibles sin traductor (FR-022); la app **nunca** recarga sola por una alteración (FR-017); idioma declarado y bloqueo viajan juntos (FR-002); el valor enviado al servidor sale siempre del estado de la app (FR-023, sin cambios)

**Scale/Scope**: 14 acciones protegidas catalogadas ([contracts/protected-actions.md](./contracts/protected-actions.md)); 55 bloques con texto suelto en 21 plantillas; 1 componente de íconos con texto (147 usos); 10 archivos de código nuevos (cada uno con su spec, salvo el catálogo y el token de recarga, que se prueban a través de sus consumidores) y ~25 editados

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I (nace de un spec)**: PASA — spec 134 creada y clarificada antes de este plan.
- **II (comportamiento existente protegido)**: PASA — los tres cambios de comportamiento de la spec
  (con la página alterada, "Enviar pedido", el pago y los equivalentes del POS quedan bloqueados;
  la app puede recargarse sola en un momento seguro al detectar versión nueva; el comensal que no
  lee español ya no puede traducir el menú) se **registran como A-145** en
  `specs/000-reconocimiento/registro-de-anomalias.md` con quién (Leonardo Gómez) y cuándo
  (2026-10-24), **antes** de implementar. Sin traductor nada cambia para el usuario (FR-022).
- **III (characterization tests)**: PASA — los dos únicos `CONGELA` del frontend
  (`checkout-order-summary.component.ts`, `review-step.component.spec.ts`) están en archivos que
  este cambio no toca (no figuran en el escáner de texto suelto).
- **V (sin refactors oportunistas)**: PASA con límite — las 21 plantillas se editan **solo** para
  envolver texto suelto (FR-021, explícito en la spec); no se reformatea, renombra ni se reescriben
  las ~917 interpolaciones. `app-mi-icon` recibe un atributo, no se migra.
- **VI (evolución incremental)**: PASA — cuatro incrementos verificables y ordenables (declaración
  → integridad/protección → actualización → etiquetas); solo el primero es obligatorio por FR-002
  y cada uno se prueba por separado. No mezcla migraciones de datos ni cambios de arquitectura.
- **VII (datos históricos)**: N/A — ninguna factura ni importe histórico se lee o reescribe; el
  bloqueo rechaza peticiones nuevas antes de enviarlas.
- **VIII (modelo de datos)**: N/A — sin tablas, columnas ni migraciones; el estado es transitorio
  del navegador (ver [data-model.md](./data-model.md)). Rollback = revertir el despliegue del frontend.
- **IX (dependencias nuevas)**: PASA — ninguna.
- **X (verificación obligatoria)**: PASA — specs unitarias por módulo, verificación en vivo con
  traductor simulado, escáner en 0 y lista explícita de verificaciones manuales diferidas
  ([quickstart.md](./quickstart.md)).
- **XI (decisión de negocio vs. técnica)**: PASA — la frontera de las acciones protegidas es una
  decisión de negocio señalada para confirmar (no bloquea); el diseño técnico (canario, interceptor,
  `SwUpdate`) se justifica en [research.md](./research.md).
- **XII (trazabilidad)**: PASA — tabla FR → decisión → código → prueba más abajo.
- **XIII (español de Colombia)**: PASA — artefactos y comentarios en español; commits y ramas en inglés.
- **XIV (rama antes de tocar código)**: Pendiente al iniciar la implementación — `fix/134-block-browser-translation`
  en `pos-heladeria` desde `develop` (su rama actual). `pos-backend` no se toca: sin rama.
- **XV (commits)**: PASA — ninguno sin pedido explícito; unidades pequeñas por incremento.

**Re-evaluación tras el diseño (Fase 1)**: sin violaciones nuevas. Las decisiones de diseño no
introducen dependencias, datos persistentes ni cambios de backend. Sin `Complexity Tracking`.

## Project Structure

### Documentation (this feature)

```text
specs/134-bloqueo-traduccion-automatica/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   ├── document-declaration.md
│   ├── page-integrity.md
│   ├── protected-actions.md
│   ├── app-update.md
│   └── alternating-labels.md
├── tools/               # Herramientas de verificación (no son código del producto)
│   ├── scan-loose-text.py
│   └── simulate-translation.js
├── checklists/requirements.md
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
# Aplicación web existente; este cambio vive solo en el frontend (repo hermano)
../pos-heladeria/
├── src/
│   ├── index.html                                   # lang="es" translate="no" notranslate + meta google (Incremento 1)
│   └── app/
│       ├── app.config.ts                            # registra interceptores, ErrorHandler e initializers
│       ├── app.html / app.ts                        # monta <app-page-integrity-banner /> fuera del router-outlet
│       ├── core/
│       │   ├── integrity/                           # NUEVO (Incremento 2)
│       │   │   ├── integrity-signals.ts             # S1–S6: funciones puras
│       │   │   ├── page-integrity.service.ts        # estado, observadores, histéresis, reload()
│       │   │   ├── integrity-error-handler.ts       # ErrorHandler que reporta S6
│       │   │   ├── protected-actions.ts             # catálogo PROTECTED_ACTIONS
│       │   │   ├── page-integrity.interceptor.ts    # rechaza acciones protegidas (HTTP 423)
│       │   │   └── page-integrity-banner.component.ts   # aviso + canario
│       │   ├── reload-page.ts                       # NUEVO (Incremento 2): token RELOAD_PAGE, único punto de recarga y sustituible en pruebas
│       │   └── update/                              # NUEVO (Incremento 3)
│       │       ├── update-gate.service.ts           # momento seguro M1–M6, bloqueadores, contador
│       │       ├── inflight-requests.interceptor.ts # cuenta escrituras en vuelo
│       │       └── app-update.service.ts            # SwUpdate: comprobar, esperar, activar, recargar
│       ├── shared/icon-mi/icon-mi.component.ts      # translate="no" + notranslate (Incremento 1)
│       └── modules/
│           ├── tables/services/pos-terminal.store.ts    # registerBlocker('pos-terminal-draft', hasDraft)
│           └── …                                    # 21 plantillas con texto suelto, nivel A/B (Incremento 4):
│               # products (form, detalle), inventory, promotions, tables (public-menu, manual-order,
│               # product-select, product-select-pos, pos-catalog-drawer, table-sessions, pos-order-panel,
│               # pos-checkout-panel, payment-attempt-review-panel, checkout/transfer-details-step),
│               # auth (login, forgot-password), cash-register (arqueo), plan, option-groups (2), dashboard (admin)
└── (cada archivo nuevo con su *.spec.ts junto a él, como el resto del repo)

../pos-backend/    # sin cambios
```

**Structure Decision**: aplicación web existente de dos repos hermanos; el cambio es íntegro del
frontend. Se crean dos carpetas con responsabilidad única bajo `core/` (`integrity/`, `update/`),
siguiendo el patrón de `core/auth` y `core/realtime` (servicios + interceptor + specs juntos). Las
ediciones a módulos de negocio se limitan a: un registro de bloqueador en el store de la Terminal,
un atributo en `IconMiComponent` y el envoltorio de texto de FR-021.

## Incrementos de entrega (orden y dependencias)

| # | Incremento | Historias / FR | Depende de | Entregable independiente |
|---|---|---|---|---|
| 1 | Declaración del documento + ícono `translate="no"` | US1, US3 (parcial) · FR-001–006 | — | Sí: previene el problema de raíz; `index.html` es atómico (FR-002) |
| 2 | Integridad de la página: detección, aviso, interceptor de acciones, `ErrorHandler` | US2, US3 · FR-007–017, FR-023 | — (usa 1 para probar el bloqueo "puro") | Sí: red de seguridad |
| 3 | Actualización de versión + momento seguro | US4 · FR-018–020 | 2 (M1 usa `altered()`; `reloadNow()` comparte la ruta de recarga) | Sí |
| 4 | Etiquetas alternantes (nivel A/B) | US5 · FR-021, FR-022 | — | Sí: defensa adicional |

`/speckit-tasks` ordena las tareas por incremento y por historia; no se mezclan en un mismo commit.

## Trazabilidad (Necesidad → Spec → Decisión → Implementación → Prueba)

| FR | Decisión | Implementación | Prueba / verificación |
|---|---|---|---|
| FR-001, 002, 003, 004, 005 | Decisión 1 | `index.html` | `index.html` en el build (V1); D1 diferida |
| FR-006 | Decisión 2 | `IconMiComponent` | `icon-mi.component.spec.ts`; V11 |
| FR-007, 008 | Decisión 3 | `integrity-signals.ts`, `PageIntegrityService` | specs de señales/servicio; V2, V6 |
| FR-009, 013, 015 | Decisión 5 | `PageIntegrityBannerComponent` | spec del banner; V2, V3, V5 |
| FR-010 | Decisión 3 (histéresis) | `PageIntegrityService` | spec de histéresis; V10 |
| FR-011 | Decisión 3 (S6) | `IntegrityAwareErrorHandler` | `integrity-error-handler.spec.ts` |
| FR-012, 014, 023 | Decisión 4 | `protected-actions.ts`, `pageIntegrityInterceptor` | `page-integrity.interceptor.spec.ts` (una prueba por fila); V3, V4 |
| FR-016, 017 | Decisión 5 | `reload()` solo por acción de la persona | spec del servicio/banner (no llama a `reload` solo); V5 |
| FR-018, 019, 020 | Decisión 6 | `AppUpdateService`, `UpdateGateService`, `inflightRequestsInterceptor` | specs con `SwUpdate` simulado; V8; D4 diferida |
| FR-021, 022 | Decisión 7 | 21 plantillas (nivel A/B) | escáner en 0 (V7); specs existentes; specs de etiquetas |
| SC-001 | Decisión 1 | — | D1 diferida |
| SC-008 | Decisión 6 | plazo de 5 min conservado | D4 diferida |

## Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| Falso positivo de una señal (aviso sin traductor) | Comprobaciones exactas (no "algo cambió"); canario que solo la propia app escribe; V6 y specs de "recorrido sin traductor"; si en dispositivos reales (D2) una extensión común lo dispara, se retira esa señal sin tocar el resto |
| `.fixed.inset-0` / `.ng-dirty` presentes en reposo ⇒ la actualización nunca se aplica en esa pantalla | V8 lo comprueba en cada pantalla principal; fallo conservador (espera, no recarga) |
| Pestañas abiertas antes del primer despliegue no se actualizan solas | Paso de operación documentado: una recarga manual única (quickstart, Despliegue) |
| Algún llamador interpreta el `423` | `grep status` sin coincidencias hoy; la prueba del interceptor + el recorrido V3/V4 lo cubren; el `423` es único en el frontend |
| Edición de 21 plantillas rompe layout | Cambio mecánico (`<span>` en línea ≡ texto); specs existentes de cada archivo + escáner + V7; sin cambios de clases ni lógica |
| El soporte de `translate="no"` en Safari iOS / Samsung Internet no está confirmado | La red de seguridad (US2) es independiente del bloqueo; D1/D2 lo confirman |
| Operación de dos peticiones (`POST /orders` → `checkout-and-send`) cortada por una alteración entre ambas | Ventana de microtareas; el resultado es un pedido retenido (`hold_for_payment`), estado ya soportado; se documenta en research (Decisión 4) |

## Desvíos respecto del diseño (registrados al implementar, 2026-10-24)

Ninguno cambia un requisito (FR) ni un criterio de éxito (SC); precisan el diseño donde la
implementación encontró un caso que el plan no preveía.

| # | Desvío | Dónde | Por qué |
|---|---|---|---|
| 1 | S2 no dispara con `lang` ausente o vacío | [contracts/page-integrity.md](./contracts/page-integrity.md) | Ningún traductor deja el atributo vacío (escribe el idioma destino) y un documento sin idioma declarado —el de las pruebas— no está "alterado". Con la comprobación literal habría un falso positivo en cualquier entorno sin `lang` |
| 2 | Los observadores no cuentan para la histéresis | idem, "Histéresis" | Con la regla literal, las "dos evaluaciones limpias consecutivas" podían caer en el mismo milisegundo (observador + sondeo) y FR-010 no habría servido. Un observador sube a "alterada" al instante; solo el arranque, el sondeo, `visibilitychange` y `pageshow` cuentan para volver a "íntegra" |
| 3 | El escáner de texto suelto se refinó: **55/21 → 49/19** | [contracts/alternating-labels.md](./contracts/alternating-labels.md), `tools/scan-loose-text.py` | Contaba como texto las declaraciones `@let` y no entendía un `@else if` con paréntesis anidados. `pos-order-panel` y `pos-checkout-panel` no necesitaron edición (T076/T077) |
| 4 | Nivel B: **6 etiquetas** en vez de las 3 mínimas | idem, "Lista final" | Además de `product-select`, `product-select-pos` y "Reenviar enlace en N s": el mensaje de catálogo vacío del menú QR y del POS (siguen lo escrito en el buscador) y el aviso del picker de presentaciones (sigue los productos elegidos). Cada una con su caso en el spec hermano |
| 5 | El aviso pone el título y "Recargar" en la misma fila | [contracts/page-integrity.md](./contracts/page-integrity.md) | Medido en un teléfono de 420 px: el aviso fijo tapaba la primera opción de pago ("Efectivo"). En una fila ocupa ~40 px menos y deja de taparla; sigue siendo fijo y no descartable (FR-009) |
| 6 | El canario lleva `print:hidden` | idem | Su texto aparecía en el texto extraíble del PDF de impresión (V9); invisible en pantalla, ya no sale al imprimir |
| 7 | `AppUpdateService` no aplica en el acto al llegar `VERSION_READY` | [contracts/app-update.md](./contracts/app-update.md) | Sigue el contrato al pie de la letra: intenta aplicar en el siguiente ciclo de 15 s o al volver a primer plano. Tras iniciar la recarga pone `pending = false` para no recargar dos veces |
| 8 | `PageIntegrityService` resuelve `AppUpdateService` de forma perezosa (`Injector`) | `page-integrity.service.ts` | Hay un ciclo de importación entre módulos (`page-integrity` → `app-update` → `update-gate` → `page-integrity`) que solo es inocuo porque nada se usa al evaluar el módulo; la inyección perezosa evita además el ciclo de DI. Si falla el Service Worker, "Recargar" igual recarga |
| 9 | El helper de pruebas `simulateTranslation` expone `refresh()` | `src/app/testing/simulate-translation.ts` | Un traductor real sigue traduciendo lo que se pinta después; con una sola pasada las pruebas de FR-021 **pasaban con la plantilla vieja** (comprobado por mutación). Con `refresh()` fallan con la plantilla vieja y pasan con la nueva |
| 10 | Cobertura en vivo de las acciones protegidas | [baseline-suite.md](./baseline-suite.md) | Verificadas en vivo: QR-1, P-1, P-2, P-3, P-5, P-6, P-10, P-11, P-12. **Solo por pruebas unitarias** (una por fila): QR-2, P-4, P-7, P-8, P-9 — sin llamador de UI alcanzable en el tenant de pruebas (P-7, P-9 no tienen) o dependen de un pedido de mesero ya en cocina (P-8) |

### Trazabilidad verificada (T086)

Los **23 FR** y los **9 SC** de la spec tienen al menos una tarea y una verificación en
[tasks.md](./tasks.md) y están en la tabla de trazabilidad de arriba. `tasks.md` cita por su número 18 de
los 23 FR; los otros cinco se cubren por rango o por el contrato: FR-003 y FR-004/FR-005 (declaración en
`<html>` y bloqueo de las capas fuera de `app-root`, T006–T007), FR-009 (aviso no descartable, T014/T020),
FR-011 (error de DOM atribuible, T012/T017) y FR-019 (momento seguro, T039–T050). Invariantes de cierre
(T084): ningún `<font>` en plantillas ni código de la app, ningún `hyphens`/`:lang()`, ningún llamador
interpreta el `423`, el escáner arroja 0 y el build de producción conserva `lang="es" translate="no"
class="notranslate"` y el meta `google/notranslate`. El *bundle* inicial pasó de 842,59 kB a 855,59 kB
(+13 kB; el aviso por exceder el presupuesto de 500 kB ya existía).

## Complexity Tracking

*Sin violaciones de la Constitution Check que requieran justificación.*
