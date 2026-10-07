# Fase 1 — Data Model: Caché y deduplicación de peticiones en TenantInfoService y PlanSummaryService

Ver decisiones técnicas en [research.md](./research.md). Esta funcionalidad **no introduce ninguna
entidad persistida, columna, ni migración** (Constitution Check, Principio VIII: N/A) — no hay base
de datos involucrada en ningún punto. Lo único que existe es estado **en memoria del navegador**,
con el alcance de vida de la propia pestaña. Este documento describe esa forma de estado interna, no
un modelo de datos de dominio.

## Estado interno nuevo: la petición vigente (`pending`)

Corresponde a la "referencia a la petición en curso" que describe el Input original de spec.md.
Vive por completo dentro del objeto que devuelve `createCachedLoader()` — no es un signal de
Angular, no es observable públicamente, y no se expone en ninguna interfaz pública de
`TenantInfoService` ni `PlanSummaryService`.

| Campo | Tipo | Notas |
|---|---|---|
| `pending` | `Promise<void> \| null` | `null` cuando no hay ninguna petición HTTP real en curso. Mientras hay una, apunta exactamente a la `Promise` que `run()` devolvió para **esa** petición (research.md Decisión 3) |

**Reglas**:
- Se fija a una nueva `Promise` en el instante en que `run()` se invoca — nunca antes (no hay un
  estado "a punto de empezar" intermedio).
- Se limpia a `null` únicamente cuando la petición cuya referencia sigue guardada en `pending`
  termina (éxito o error) **y** nadie la reemplazó mientras tanto; si una llamada con
  `force: true` llegó en el medio, `pending` ya apunta a la petición nueva y la limpieza de la
  petición vieja no hace nada (research.md Decisión 3).
- No tiene relación con `loading`/`error` — esos signals siguen existiendo exactamente como hoy,
  gestionados por `run()`, no por este campo (research.md Decisión 4).
- No se persiste en ningún lado ni sobrevive a un recargo completo de la página — al recargar el
  navegador, cada servicio vuelve a instanciarse desde cero y `pending` nace en `null`.

## Estado reutilizado sin modificar su forma

Ninguno de estos dos signals cambia de tipo ni de forma por esta funcionalidad — se listan solo
porque son lo que `hasData()` consulta (research.md Decisión 5) y lo que determina, hoy mismo, si
hay "datos cacheados":

- **`TenantInfoService.info`** — `signal<TenantInfo | null>(null)` (ya existente,
  `tenant-info.service.ts:53`). `hasData()` ≡ `this.info() !== null`.
- **`PlanSummaryService.summary`** — `signal<PlanSummary | null>(null)` (ya existente,
  `plan-summary.service.ts:15`). `hasData()` ≡ `this.summary() !== null`.

Ambos ya se pueblan hoy por dos caminos — `load()` (petición HTTP real) y `hydrate()` (arranque
agregado del panel, spec 100) — y esta funcionalidad no agrega un tercero ni cambia cuáles existen;
solo cambia cuándo `load()` decide disparar o no la petición HTTP según lo que esos signals ya
contienen.

## El helper: forma de `createCachedLoader()`, no una entidad con estado propio expuesto

`createCachedLoader(hasData, run)` (`src/app/shared/cached-loader.util.ts`, research.md Decisión 2)
es una función de fábrica, no una clase con estado público. Devuelve un único objeto con un método:

```text
{ load(options?: { force?: boolean }): Promise<void> }
```

El campo `pending` descrito arriba vive como variable cerrada (closure) dentro de la llamada a
`createCachedLoader()` — cada servicio que la invoca obtiene su propia instancia independiente, con
su propio `pending` privado; no hay un `pending` compartido entre `TenantInfoService` y
`PlanSummaryService`, ni entre dos instancias futuras del mismo helper si otro servicio lo adopta
más adelante. El contrato completo del método `load()` que expone se documenta en
[contracts/load-contract.md](./contracts/load-contract.md).
