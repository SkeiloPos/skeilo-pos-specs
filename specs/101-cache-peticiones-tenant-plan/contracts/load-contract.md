# Contrato: `load(options?: { force?: boolean }): Promise<void>`

**Spec**: [../spec.md](../spec.md) | **Data model**: [../data-model.md](../data-model.md) |
**Research**: [../research.md](../research.md) §§ 1-5

No es un contrato de red (no hay endpoint nuevo ni cambia la forma de `GET /tenant`/`GET /plan`):
es el contrato de comportamiento del método público `load()` que `TenantInfoService` y
`PlanSummaryService` exponen hoy, y que esta funcionalidad amplía con deduplicación, caché y
forzado. Es, también, el contrato que expone el helper nuevo
`createCachedLoader(hasData, run)` (`src/app/shared/cached-loader.util.ts`) para cualquier futuro
servicio `providedIn: 'root'` que lo adopte — ambos servicios lo cumplen por construcción, al
delegar en la misma instancia del helper (research.md Decisión 2).

## Firma

```ts
load(options?: { force?: boolean }): Promise<void>
```

- `options` es opcional; omitirlo equivale a `{ force: false }`.
- El valor resuelto de la `Promise` sigue siendo `void` — ningún llamador recibe el dato en sí
  desde `load()` (igual que hoy); el dato se lee de los signals públicos (`info()`/`summary()`)
  después de que la `Promise` resuelve.
- La `Promise` **nunca rechaza** (`reject`) por un fallo de la petición HTTP — igual que hoy, un
  error de red o del backend se refleja en el signal `error` del servicio, no como excepción al
  llamador de `load()`.

## Precondiciones y postcondiciones por caso

### Caso 1 — Cache-hit (`force` ausente o `false`, `hasData()` ya es `true`)

- **Precondición**: el signal de datos del servicio (`info()`/`summary()`) no es `null`.
- **Comportamiento**: `load()` resuelve de inmediato (en el siguiente microtask), **sin** invocar
  `run()` — ninguna petición HTTP nueva.
- **Postcondición**: `loading` y `error` quedan exactamente como estaban antes de la llamada
  (FR-001, FR-011). El signal de datos no cambia (nadie lo tocó).

### Caso 2 — Unión a una petición en curso (`force` ausente o `false`, `hasData()` es `false`, ya hay una petición vigente)

- **Precondición**: el signal de datos es `null` (o, da igual su valor: ver nota) **y** el campo
  interno `pending` ya apunta a una `Promise` de una llamada anterior que todavía no resolvió.
  - *Nota*: en la práctica este caso solo es alcanzable con `hasData()` en `false`, porque si ya
    hubiera datos el Caso 1 habría resuelto primero sin siquiera mirar `pending` — el orden de
    evaluación es: primero caché, después deduplicación (ver Caso 4 para la combinación con
    `force`).
- **Comportamiento**: `load()` devuelve **la misma referencia** de `Promise` que ya está en
  `pending` — no crea una `Promise` nueva, no invoca `run()` una segunda vez.
- **Postcondición**: cuando esa `Promise` compartida resuelve, todos los llamadores que se unieron
  a ella resuelven en el mismo instante, con el mismo resultado final en los signals (FR-002,
  FR-011 — ninguno de los llamadores unidos tocó `loading`/`error` por su cuenta).

### Caso 3 — Forzado (`force: true`), sin importar el estado previo del caché

- **Precondición**: ninguna — aplica siempre que `options?.force === true`, exista o no `hasData()`
  ya en `true`, exista o no una petición vigente en `pending`.
- **Comportamiento**: se invoca `run()` incondicionalmente, generando una petición HTTP real nueva.
  El campo `pending` se reasigna de inmediato (de forma síncrona, antes de que esa petición
  responda) a la `Promise` de esta nueva llamada a `run()` (FR-003, FR-004).
- **Postcondición (éxito)**: el signal de datos y el caché quedan actualizados con la respuesta; la
  siguiente llamada a `load()` sin forzar vuelve a resolver por el Caso 1 (FR-005).
- **Postcondición (error)**: el signal de datos **no** se marca como "cargado" por este intento — si
  ya había un valor cacheado de antes, ese valor previo se sigue sirviendo sin cambios; si no había
  ninguno, `hasData()` sigue en `false` y la siguiente llamada sin forzar dispara una petición real
  en lugar de quedar bloqueada (FR-006).

### Caso 4 — Forzado que se solapa con una petición ya en curso (normal o forzada)

- **Precondición**: `options?.force === true` **y** `pending` ya apunta a la `Promise` de una
  petición anterior (iniciada por un `load()` normal o por un `force` previo) que todavía no
  resolvió.
- **Comportamiento**: igual que el Caso 3 — se dispara una petición nueva de inmediato; la petición
  anterior **no se cancela** y sigue corriendo de forma independiente. `pending` pasa a apuntar a
  la petición nueva; cualquier `load()` que llegue después de este punto (forzado o no) queda
  referenciando la petición nueva, nunca la vieja (FR-004).
- **Postcondición**: ambas peticiones terminan de forma independiente; el signal de datos queda con
  el resultado de la que resuelva **al final**, sea la vieja o la nueva — no hay secuenciación ni
  descarte de respuestas obsoletas (Edge Case de spec.md, research.md Decisión 3). Cuando cada una
  termina, su propio bloque de limpieza solo vacía `pending` si `pending` sigue siendo exactamente
  su propia referencia — por eso la petición vieja, al terminar después de haber sido reemplazada,
  no borra la referencia de la petición nueva que aún podría estar en curso.

## Garantías que el helper exige de `hasData`/`run` (contrato de quien instancia `createCachedLoader`)

Para que las garantías anteriores se cumplan, cada servicio que instancie el helper debe proveer:

- **`hasData: () => boolean`** — sin efectos secundarios, debe reflejar en todo momento si el
  signal de datos del servicio ya tiene un valor no nulo producto de una carga exitosa (`load()` o
  `hydrate()`); nunca debe lanzar.
- **`run: () => Promise<void>`** — es responsable completa de: marcar `loading`/`error` alrededor
  de su propia petición HTTP real, actualizar el signal de datos en éxito, y dejar el signal de
  datos sin marcar como "cargado" en caso de error (sin relanzar la excepción fuera de la
  `Promise` que devuelve — debe resolver siempre, nunca rechazar, igual que el `load()` actual de
  ambos servicios hoy maneja su propio `try/catch`).

El helper en sí **no** valida estas garantías en tiempo de ejecución — son un contrato de uso, no
una validación defensiva (no hay entrada externa/no confiable involucrada; ambos lados del contrato
son código propio del mismo repositorio).

## Compatibilidad

Cambio de firma aditivo y retrocompatible: todo llamador existente que invoca `load()` sin
argumentos (los 4 sitios listados en `plan.md` → Project Structure) sigue compilando y
comportándose, para ese llamador, igual que si `force` fuera `false` — la única diferencia visible
es que deja de disparar peticiones redundantes que antes sí disparaba (FR-001/FR-002), nunca una
petición que antes no disparaba. Ningún llamador necesita actualizarse para adoptar este contrato
(FR-008).
