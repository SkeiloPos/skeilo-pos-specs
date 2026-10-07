---

description: "Task list template for feature implementation"
---

# Tasks: Caché y deduplicación de peticiones en TenantInfoService y PlanSummaryService

**Input**: Design documents from `/specs/101-cache-peticiones-tenant-plan/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/load-contract.md](./contracts/load-contract.md),
[quickstart.md](./quickstart.md)

**Tests**: Incluidos explícitamente — `spec.md` describe la "Prueba independiente" de cada historia
como tests unitarios directos, `research.md` Decisión 6 fija las convenciones (Vitest, sin
TDD estricto) y `quickstart.md` § 1-2 exige los comandos `ng test` como verificación principal
(FR-008 excluye deliberadamente cualquier cambio visible en componentes).

**Organization**: Tareas agrupadas por historia de usuario para permitir implementación y prueba
independiente de cada una.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Puede ejecutarse en paralelo (archivos distintos, sin dependencias no resueltas)
- **[Story]**: Historia de usuario a la que pertenece la tarea (US1, US2)
- Rutas de archivo relativas a `pos-specs/` (repo hermano `../pos-heladeria/`), tal como en
  `plan.md` § Project Structure

## Path Conventions

Un solo repositorio frontend ya existente (`pos-heladeria`), sin cambios en `pos-backend`. Todas
las rutas de código son relativas a `pos-specs/` (`../pos-heladeria/...`), igual que en `plan.md`.

---

## Phase 1: Setup

**Purpose**: Preparar la rama de trabajo en el repositorio de código antes de tocar cualquier
archivo (Constitution XIV).

- [X] T001 Crear y cambiar a la rama `feat/101-tenant-plan-request-cache` desde `main` actualizado
  en `../pos-heladeria` (`git checkout main && git pull && git checkout -b
  feat/101-tenant-plan-request-cache`); no requiere `pos-backend` (plan.md § Constitution Check,
  Principio XIV).

**Checkpoint**: Rama lista — ningún archivo de código se modifica antes de este punto.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: El helper reutilizable `createCachedLoader()` del que dependen **ambas** historias de
usuario (research.md Decisión 2) y su contrato (contracts/load-contract.md). Ninguna historia puede
empezar hasta que esta fase esté completa.

**⚠️ CRITICAL**: Ningún trabajo de Historia 1 o Historia 2 puede empezar hasta terminar esta fase.

- [X] T002 Implementar `createCachedLoader<T>(hasData: () => boolean, run: () => Promise<T>)` en
  `../pos-heladeria/src/app/shared/cached-loader.util.ts`: función de fábrica que devuelve
  `{ load(options?: { force?: boolean }): Promise<void> }`; mantiene un campo cerrado `pending:
  Promise<void> | null`; implementa los 4 casos de `contracts/load-contract.md` — (1) cache-hit
  (`!force && hasData()`) resuelve sin invocar `run()`; (2) unión a petición en curso (`!force &&
  !hasData() && pending`) devuelve la misma referencia de `pending` sin invocar `run()` de nuevo;
  (3) forzado (`force === true`) invoca `run()` incondicionalmente y reasigna `pending` de forma
  síncrona a la nueva `Promise` antes de que responda; (4) al terminar cualquier petición (éxito o
  error), solo limpia `pending` a `null` si `pending` sigue siendo exactamente esa misma referencia
  (`if (pending === request) pending = null`), nunca cancela ni interfiere con una petición que la
  reemplazó (research.md Decisiones 1-3; data-model.md § Estado interno nuevo).
- [X] T003 Crear `../pos-heladeria/src/app/shared/cached-loader.util.spec.ts` con tests puramente
  funcionales (sin `TestBed`, con `vi.fn()` y `Promise`s controladas manualmente, research.md
  Decisión 6) que cubran los 4 Casos de `contracts/load-contract.md`: cache-hit no invoca `run`;
  dos `load()` casi simultáneas con `hasData()` en `false` devuelven la misma `Promise` y `run` se
  invoca una sola vez; `load({ force: true })` invoca `run` sin importar `hasData()`/`pending`; un
  `force` que llega mientras ya hay una petición normal en curso dispara una segunda invocación de
  `run` independiente y la petición vieja, al terminar después, no borra la referencia de la nueva
  (depende de T002).

**Checkpoint**: Helper completo y verificado de forma aislada — ambas historias de usuario pueden
empezar.

---

## Phase 3: User Story 1 - Servir desde caché y deduplicar peticiones concurrentes (Priority: P1) 🎯 MVP

**Goal**: `load()` de `TenantInfoService` y `PlanSummaryService` resuelve de inmediato sin HTTP
cuando ya hay datos en memoria, y las llamadas concurrentes a una petición en curso se unen a ella
en vez de disparar una segunda (FR-001, FR-002, FR-006, FR-007, FR-011).

**Independent Test**: tests unitarios directos sobre ambos servicios (quickstart.md § 1): llamar
`load()` una vez confirma una petición HTTP; llamar de nuevo con datos ya en memoria confirma cero
peticiones nuevas; dos llamadas casi simultáneas antes de responder confirman una sola petición
HTTP y ambos llamadores resolviendo con el mismo resultado.

### Implementation for User Story 1

- [X] T004 [P] [US1] Modificar `../pos-heladeria/src/app/core/tenant/tenant-info.service.ts`:
  extraer el cuerpo actual de `load()` (líneas 79-89) a un método privado `fetchAndStore(): Promise<void>`
  idéntico al `load()` actual (mismo `loading`/`error`/`try`/`catch`/`finally`); instanciar
  `createCachedLoader(() => this.info() !== null, () => this.fetchAndStore())` como campo privado
  (p. ej. `private readonly cachedLoad = createCachedLoader(...)`); reemplazar `load()` público por
  `load(options?: { force?: boolean }): Promise<void> { return this.cachedLoad.load(options); }`.
  No modificar `hydrate()`, `update()`, `uploadLogo()` ni `extractError()` (FR-009).
- [X] T005 [P] [US1] Modificar `../pos-heladeria/src/app/modules/plan/services/plan-summary.service.ts`:
  extraer el cuerpo actual de `load()` (líneas 31-41) a un método privado `fetchAndStore(): Promise<void>`
  idéntico al `load()` actual; instanciar `createCachedLoader(() => this.summary() !== null, () =>
  this.fetchAndStore())` como campo privado; reemplazar `load()` público por `load(options?: {
  force?: boolean }): Promise<void> { return this.cachedLoad.load(options); }`. No modificar
  `hydrate()`, `fetch()` ni `extractError()` (FR-009, FR-010); `fetch()` sigue llamando
  `this.http.get(...)` directo, sin pasar por `fetchAndStore()` ni el caché.

### Tests for User Story 1

- [X] T006 [P] [US1] Ampliar `../pos-heladeria/src/app/core/tenant/tenant-info.service.spec.ts` con
  casos de Historia 1 (depende de T004): `load()` con `info()` ya no-nulo no dispara ninguna
  petición (`http.expectNone(TENANT)` o equivalente, Acceptance Scenario 1); dos llamadas a
  `load()` lanzadas antes de resolver la primera resultan en exactamente un `http.expectOne(TENANT)`
  y ambas `Promise`s devueltas resuelven (Acceptance Scenario 2); tras un `load()` que termina en
  error (`req.flush(..., { status: 500, ... })`), una llamada posterior sin forzar sí dispara un
  nuevo `http.expectOne(TENANT)` (Acceptance Scenario 3); verificar que `loading()` y `error()` no
  cambian de valor en ningún instante de los casos de cache-hit y de unión a petición en curso
  (FR-011). No modificar los tests ya existentes de `uploadLogo`, `update` ni `hydrate`.
- [X] T007 [P] [US1] Ampliar
  `../pos-heladeria/src/app/modules/plan/services/plan-summary.service.spec.ts` con los mismos
  casos de Historia 1 que T006, adaptados a `PlanSummaryService`/`summary()`/`PLAN` (depende de
  T005): cache-hit sin petición, deduplicación de llamadas concurrentes con una sola
  `http.expectOne(PLAN)`, reintento tras error, y `loading()`/`error()` sin cambios en cache-hit o
  unión (FR-011).

**Checkpoint**: Historia 1 completamente funcional y verificable de forma independiente en ambos
servicios (SC-001, SC-002).

---

## Phase 4: User Story 2 - Forzar una recarga explícita que ignora el caché (Priority: P2)

**Goal**: `load({ force: true })` ignora el caché y garantiza una petición HTTP real, reemplazando
de forma segura cualquier petición en vuelo como referencia vigente, y deja el caché actualizado
tras un éxito (FR-003, FR-004, FR-005).

**Nota de alcance**: esta historia no agrega código de producción nuevo. El soporte de `force` ya
quedó resuelto por T002 (el helper acepta `options?.force` desde su primera versión) y por T004/T005
(el `load()` de ambos servicios ya reenvía `options` completo al helper) — no existe una versión
intermedia de `load()` que solo soporte caché/deduplicación sin `force`. Esta fase agrega
exclusivamente la cobertura de tests que verifica ese contrato ya construido (Clarification 1 de
spec.md: "force queda disponible como capacidad pública ... verificada con tests unitarios
directos").

**Independent Test**: tests unitarios directos sobre ambos servicios (quickstart.md § 2): con datos
ya cacheados, `load({ force: true })` dispara una petición HTTP real; tras esa petición, `load()`
sin forzar sirve el nuevo valor desde caché sin disparar otra.

### Tests for User Story 2

- [X] T008 [P] [US2] Ampliar `../pos-heladeria/src/app/core/tenant/tenant-info.service.spec.ts` con
  casos de Historia 2 (depende de T004, T006): con `info()` ya cacheado, `load({ force: true })`
  dispara un `http.expectOne(TENANT)` real (Acceptance Scenario 1); tras responder exitosamente,
  `info()` queda con la respuesta nueva (Acceptance Scenario 2); una llamada posterior a `load()`
  sin forzar no dispara una petición adicional (Acceptance Scenario 3); un `load({ force: true })`
  lanzado mientras ya hay un `load()` normal en curso (sin responder aún) dispara un segundo
  `http.expectOne(TENANT)` independiente del primero, y al resolver el primero (la petición vieja)
  después del segundo, no deja `info()` en un estado roto ni interfiere con la petición nueva
  (contracts/load-contract.md Caso 4, Edge Case de spec.md).
- [X] T009 [P] [US2] Ampliar
  `../pos-heladeria/src/app/modules/plan/services/plan-summary.service.spec.ts` con los mismos
  casos de Historia 2 que T008, adaptados a `PlanSummaryService`/`summary()`/`PLAN` (depende de
  T005, T007).

**Checkpoint**: Historias 1 y 2 funcionan de forma independiente en ambos servicios (SC-001 a
SC-004 verificados por tests).

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Verificación final de no-regresión y recorrido manual, según `quickstart.md`.

- [X] T010 Ejecutar la suite completa del frontend (`cd ../pos-heladeria && ng test`) y confirmar
  que no aparecen fallos nuevos más allá de la línea base ya conocida de fallos preexistentes (ver
  memoria `reference_pos_suite_frontend_fallos_preexistentes` — siempre los mismos ~6 archivos,
  ajenos a `TenantInfoService`/`PlanSummaryService`/`cached-loader.util.ts`); no ejecutar frontend y
  backend completos en paralelo (contención infla fallos).
- [X] T011 Ejecutar el recorrido manual de `quickstart.md` § 3 en el navegador: iniciar sesión,
  abrir la pestaña Network filtrada por Fetch/XHR, navegar entre "Ventas"/"Inventario"/"Mi plan"
  varias veces seguidas tras el bootstrap inicial, y confirmar que no aparece ninguna petición
  nueva `GET /tenant` ni `GET /plan` en ningún momento de esa navegación (Historia 1 con llamadores
  reales).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Sin dependencias — puede empezar de inmediato.
- **Foundational (Phase 2)**: Depende de Setup (T001) — BLOQUEA ambas historias de usuario.
- **User Story 1 (Phase 3)**: Depende de Foundational (T002, T003) completo.
- **User Story 2 (Phase 4)**: Depende de Foundational (T002) y de la implementación de Historia 1
  (T004, T005) — no agrega código propio, solo tests sobre el `load()` ya construido en Historia 1.
- **Polish (Phase 5)**: Depende de que Historias 1 y 2 estén completas (T004-T009).

### Dependencias dentro de cada fase

- T003 depende de T002 (los tests del helper importan su implementación).
- T004 y T005 son independientes entre sí (archivos distintos) pero ambos dependen de T002.
- T006 depende de T004 (mismo servicio); T007 depende de T005 (mismo servicio). T006 y T007 son
  independientes entre sí.
- T008 depende de T004 y T006 (mismo archivo de spec, se añade a continuación de los casos de
  Historia 1); T009 depende de T005 y T007. T008 y T009 son independientes entre sí.

### Parallel Opportunities

- T004 (`tenant-info.service.ts`) y T005 (`plan-summary.service.ts`) en paralelo — archivos
  distintos, ambos solo dependen de T002.
- T006 (`tenant-info.service.spec.ts`) y T007 (`plan-summary.service.spec.ts`) en paralelo, una vez
  terminados T004 y T005 respectivamente.
- T008 y T009 en paralelo, una vez terminados T006 y T007 respectivamente.

---

## Parallel Example: User Story 1

```bash
# Una vez completado T002 (helper), lanzar juntas las dos modificaciones de servicio:
Task: "Modificar tenant-info.service.ts para delegar en createCachedLoader"
Task: "Modificar plan-summary.service.ts para delegar en createCachedLoader"

# Una vez completadas esas dos, lanzar juntos sus tests de Historia 1:
Task: "Ampliar tenant-info.service.spec.ts con casos de Historia 1"
Task: "Ampliar plan-summary.service.spec.ts con casos de Historia 1"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Completar Phase 1: Setup (T001).
2. Completar Phase 2: Foundational (T002, T003) — bloquea todo lo demás.
3. Completar Phase 3: User Story 1 (T004-T007).
4. **DETENER y VALIDAR**: correr `ng test --include='**/tenant-info.service.spec.ts'` y
   `--include='**/plan-summary.service.spec.ts'`; confirmar SC-001 y SC-002.

### Incremental Delivery

1. Setup + Foundational → helper listo y verificado de forma aislada.
2. Añadir Historia 1 → probar de forma independiente → MVP (caché + deduplicación en ambos
   servicios).
3. Añadir Historia 2 → probar de forma independiente → capacidad de forzado verificada, sin
   llamadores reales todavía (Clarification 1).
4. Polish → suite completa + recorrido manual de `quickstart.md`.

### Notes

- `[P]` = archivos distintos, sin dependencias no resueltas dentro de esa misma fase.
- `[Story]` mapea cada tarea a su historia de usuario para trazabilidad.
- No hay tareas de commit explícitas en esta lista: según la convención de commits del proyecto
  (commits pequeños, en inglés, sin atribución de IA, solo cuando el usuario lo pida), conviene
  commitear tras cada tarea o grupo lógico (p. ej. T002+T003 juntos, T004+T006 juntos, T005+T007
  juntos, T008+T009 juntos).
- Verificar que los tests fallan antes de implementar no aplica aquí (TDD no fue solicitado,
  research.md Decisión 6) — el orden Implementación → Tests dentro de cada historia es el elegido.
