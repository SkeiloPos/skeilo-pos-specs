# Implementation Plan: Caché y deduplicación de peticiones en TenantInfoService y PlanSummaryService

**Branch**: `101-cache-peticiones-tenant-plan` | **Date**: 2026-10-07 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/101-cache-peticiones-tenant-plan/spec.md`

## Summary

Hoy `TenantInfoService.load()` (`pos-heladeria/src/app/core/tenant/tenant-info.service.ts:79-89`) y
`PlanSummaryService.load()` (`pos-heladeria/src/app/modules/plan/services/plan-summary.service.ts:31-41`)
disparan siempre una petición HTTP nueva (`GET /tenant`, `GET /plan`), sin importar si el servicio
ya tiene datos en memoria o si ya hay otra llamada idéntica en curso — cada uno de sus 4 llamadores
actuales (`sales-page.component.ts`, `inventory-page.component.ts`, `plan-summary-page.component.ts`,
`tenant-info.component.ts`) compensa esto hoy con su propia comprobación ad-hoc antes de llamar.
Esta funcionalidad blinda ambos servicios en su propio `load()`: si el signal de datos ya tiene un
valor no nulo, resuelve de inmediato sin tocar el backend; si ya hay una petición en curso, las
llamadas concurrentes se unen a esa misma referencia en vez de disparar una segunda; y `load()` gana
la firma `load(options?: { force?: boolean })`, donde `force: true` ignora el caché, reemplaza
cualquier petición en vuelo como la referencia vigente para llamadores futuros, y garantiza una
petición HTTP real. La lógica se extrae a un helper nuevo y reutilizable
(`createCachedLoader`, `src/app/shared/cached-loader.util.ts`) que ambos servicios instancian de
forma idéntica, para que FR-007 (comportamiento idéntico en ambos) se cumpla por construcción y para
que, tal como pide el ticket original, el mismo patrón quede disponible para futuros servicios
`providedIn: 'root'`. Ningún componente llamador, `hydrate()`, `fetch()` ni `plan-module.guard.ts`
cambian (FR-008/FR-009/FR-010, Clarifications 1 y 2).

## Technical Context

**Language/Version**: TypeScript 5.9 / Angular 21 (standalone components, signals) — un solo
repositorio frontend, sin cambios en `pos-backend`.

**Primary Dependencies**: Ninguna nueva. Reutiliza `HttpClient` + `firstValueFrom` (RxJS), ya usados
por ambos servicios; el helper nuevo (`createCachedLoader`) no depende de RxJS ni de ninguna
librería externa, solo de `Promise` nativo.

**Storage**: N/A — no hay persistencia ni base de datos involucrada; el "caché" es el propio signal
de estado en memoria del navegador (`info`/`summary`), vigente solo durante la vida de la pestaña.

**Testing**: Vitest vía `ng test` (builder `@angular/build:unit-test` de Angular 21, no
Karma/Jasmine), `TestBed` + `provideHttpClient()`/`provideHttpClientTesting()` +
`HttpTestingController`, mismo patrón que ya usan `tenant-info.service.spec.ts` y
`plan-summary.service.spec.ts`.

**Target Platform**: Navegador (frontend Angular de `pos-heladeria`, ya en producción).

**Project Type**: Frontend de un solo repositorio ya existente, sin cambios de alto nivel ni en
`pos-backend`.

**Performance Goals**: No es una funcionalidad de throughput — el objetivo es reducir a cero las
peticiones HTTP redundantes de `load()` sin forzado cuando ya hay datos en memoria (SC-001) y a
exactamente una las peticiones concurrentes que coinciden mientras otra ya está en curso (SC-002),
para ambos servicios.

**Constraints**: No debe alterar el ciclo de vida de `DashboardLayoutComponent` ni de ningún otro
componente llamador existente (FR-008); no debe alterar `hydrate()` (FR-009); `fetch()` de
`PlanSummaryService` y `plan-module.guard.ts` quedan fuera de alcance, sin cambios (FR-010); un
cache-hit o una unión a una petición en curso no deben tocar los signals `loading` ni `error`
(FR-011); sin TTL — el caché es válido indefinidamente hasta un `force` exitoso o un recargo completo
de página (Assumptions de spec.md).

**Scale/Scope**: 1 helper nuevo (`createCachedLoader`, `src/app/shared/cached-loader.util.ts`) + 2
servicios existentes modificados únicamente en su método `load()` (`TenantInfoService`,
`PlanSummaryService`). Sin endpoints nuevos, sin entidades persistidas, sin dependencias de
terceros, sin componentes modificados.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Evaluado contra `.specify/memory/constitution.md` v4.0.0 (fase de Evolución Funcional):

- **I. Nace de un spec** ✅ — `specs/101-cache-peticiones-tenant-plan/spec.md`, con
  `## Clarifications` resolviendo las 3 ambigüedades del ticket original (alcance de `force`, el
  `fetch()`/guard fuera de alcance, y el comportamiento de `loading`/`error`).
- **II. Comportamiento existente protegido** ✅ — el único efecto observable sobre comportamiento
  existente es que `load()` deja de disparar peticiones redundantes cuando ya hay datos o una
  petición en curso; el dato final que termina en cada signal y lo que cada componente renderiza no
  cambia (misma respuesta, mismas reglas de negocio de `GET /tenant`/`GET /plan`) — no hay ninguna
  regla de negocio que cambie, solo cuántas veces se pide el mismo dato por red, así que no aplica
  registrar nada en `registro-de-anomalias.md`.
- **III. Characterization tests** ✅ (verificado en Phase 0) — ningún test
  `"CONGELA comportamiento actual:"` referencia `TenantInfoService`, `PlanSummaryService`,
  `plan-module.guard.ts` ni ninguno de los 4 componentes llamadores (son characterization tests de
  backend en `pos-backend/app/characterization_tests/`, que no cubren código de frontend).
- **IV. Nuevo comportamiento vía spec** ✅ — la firma `load(options?: { force?: boolean })` y las
  reglas de caché/deduplicación son comportamiento nuevo, definido por FR-001 a FR-011.
- **V. Sin refactorizaciones oportunistas** ✅ — el único archivo nuevo (`cached-loader.util.ts`) es
  la implementación misma de la funcionalidad pedida (el ticket original pide explícitamente que el
  mecanismo "siente el estándar para otros servicios"), no una refactorización ajena; no se toca
  ningún componente llamador, ni `hydrate()`, ni `fetch()`, ni el guard (FR-008/009/010).
- **VI. Evolución incremental** ✅ — una sola unidad verificable: un helper + su adopción idéntica en
  2 servicios, sin migraciones, sin cambios de arquitectura adicionales, sin tocar el backend.
- **VII. Compatibilidad con datos históricos** — N/A, no hay facturas ni datos históricos
  involucrados.
- **VIII. Evolución del modelo de datos** — N/A, no se agrega ninguna entidad persistida ni
  migración (ver `data-model.md`).
- **IX. Dependencias nuevas** — N/A, no se agrega ninguna dependencia de terceros; el helper nuevo
  usa solo `Promise` nativo (ver research.md Decisión 1).
- **X. Verificación obligatoria** ✅ (a completar en implementación) — tests nuevos del helper
  (`cached-loader.util.spec.ts`) + tests nuevos en `tenant-info.service.spec.ts` y
  `plan-summary.service.spec.ts` cubriendo las Historias 1 y 2 + recorrido de `quickstart.md`.
- **XI. Negocio vs técnico** ✅ — las 3 ambigüedades ya quedaron resueltas como decisiones de negocio
  en `## Clarifications` de spec.md; este plan solo fija el mecanismo técnico (research.md).
- **XII. Trazabilidad** ✅ — spec.md → este plan.md → tasks.md (siguiente comando) → implementación →
  tests → quickstart.md.
- **XIII. Español de Colombia** ✅ — todos los artefactos de esta fase (este plan, research.md,
  data-model.md, contracts/, quickstart.md) en español de Colombia; nombres de archivos/código y
  rama en inglés.
- **XIV. Estrategia de ramas** — no aplica todavía: esta fase solo escribe en `pos-specs` (rama
  `101-cache-peticiones-tenant-plan` de este mismo repo). Al iniciar la implementación en
  `pos-heladeria`, corresponde crear una rama nueva en inglés, p. ej.
  `feat/101-tenant-plan-request-cache`, antes de tocar código.
- **XV. Política de commits** — no aplica en esta fase (no se genera código todavía); se recuerda
  para la fase de implementación: commits pequeños, en inglés, sin atribución de IA, solo cuando el
  usuario lo pida explícitamente.

**Resultado**: sin violaciones. No se requiere la tabla de Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/101-cache-peticiones-tenant-plan/
├── plan.md              # Este archivo
├── research.md          # Fase 0
├── data-model.md        # Fase 1
├── quickstart.md        # Fase 1
└── contracts/
    └── load-contract.md # Fase 1
```

### Source Code (un solo repositorio hermano, fuera de `pos-specs`)

```text
../pos-heladeria/src/app/shared/cached-loader.util.ts        # nuevo — createCachedLoader()
../pos-heladeria/src/app/shared/cached-loader.util.spec.ts   # nuevo — tests directos del helper

../pos-heladeria/src/app/core/tenant/tenant-info.service.ts                      # load() + fetchAndStore() privado
../pos-heladeria/src/app/core/tenant/tenant-info.service.spec.ts                 # + casos de Historias 1 y 2

../pos-heladeria/src/app/modules/plan/services/plan-summary.service.ts          # load() + fetchAndStore() privado
../pos-heladeria/src/app/modules/plan/services/plan-summary.service.spec.ts     # + casos de Historias 1 y 2
```

Sin cambios en ningún otro archivo: ni componentes llamadores
(`sales-page.component.ts`, `inventory-page.component.ts`, `plan-summary-page.component.ts`,
`tenant-info.component.ts`, `dashboard-layout.component.ts`), ni `plan-module.guard.ts`, ni
`bootstrap.service.ts` (spec 100), ni ningún archivo de `pos-backend`.

**Structure Decision**: Frontend de un solo repositorio ya existente y en producción
(`pos-heladeria`), sin tocar `pos-backend`, según el alcance fijado por la constitución del
proyecto. El helper nuevo se ubica en `src/app/shared/`, siguiendo exactamente la convención de
nombre ya vigente para utilidades puras (`*.util.ts`: `api-error.util.ts`, `slug.util.ts`,
`date-format.util.ts`) en vez de crear una carpeta nueva — es una función reutilizable sin estado de
Angular propio (no es un servicio `providedIn: 'root'`, no se inyecta), consistente con que los
otros archivos de esa carpeta tampoco lo son.

## Complexity Tracking

*Sin violaciones de la Constitution Check — tabla no aplica.*
