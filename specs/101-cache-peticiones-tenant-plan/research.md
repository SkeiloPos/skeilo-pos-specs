# Fase 0 — Research: Caché y deduplicación de peticiones en TenantInfoService y PlanSummaryService

**Spec**: [spec.md](spec.md)

Las 3 ambigüedades de negocio del ticket original ya quedaron resueltas en `spec.md` →
`## Clarifications` (alcance de `force`, el `fetch()`/`plan-module.guard.ts` fuera de alcance, y el
comportamiento de `loading`/`error` ante cache-hit o deduplicación). Este documento no tiene por
tanto ningún `NEEDS CLARIFICATION` de negocio pendiente — todo lo que sigue son decisiones técnicas
de implementación, tal como lo deja explícito la última Assumption de spec.md ("el mecanismo de
implementación concreto ... es una decisión técnica que se define en la fase de planeación").

## 1. Mecanismo de caché/deduplicación: `Promise` nativa, no un Observable multicasteado

**Decisión**: rastrear la petición en curso como un campo privado `Promise<void> | null`, sin
introducir ningún operador de RxJS nuevo (ni `shareReplay`, ni `Subject`).

**Rationale**: ambos métodos `load()` ya son `async` y usan `firstValueFrom(this.http.get(...))`
exclusivamente — consumen el `HttpClient` como Promise desde el primer carácter del método, nunca
como Observable suscribible por el llamador. Envolver la petición en un Observable multicasteado
(`shareReplay(1)`) obligaría a cambiar esa forma de consumo en los dos servicios y en sus 4
llamadores actuales para seguir funcionando igual, lo que contradice FR-008 (no alterar a los
llamadores). Una `Promise` que se guarda y se devuelve tal cual a quien llega mientras está pendiente
reproduce exactamente "varias llamadas esperan el mismo resultado" sin tocar la forma pública del
método (sigue siendo `Promise<void>`) ni requerir RxJS adicional.

**Alternativas consideradas**: Observable con `shareReplay({ bufferSize: 1, refCount: false })`
(descartada — cambia el contrato interno de consumo sin necesidad, y además `refCount: false`
dejaría la suscripción "viva" para siempre de una forma menos explícita que un campo que se limpia a
mano); un `Subject` propio que emita cuando la petición termina (descartada — resolver lo mismo con
más piezas que una simple `Promise` referenciada).

## 2. Extraer un helper compartido (`createCachedLoader`) en vez de duplicar la lógica en cada servicio

**Decisión**: la lógica de caché/deduplicación/`force` se extrae una sola vez a una función de
fábrica nueva, `createCachedLoader()`, en `src/app/shared/cached-loader.util.ts`. Cada servicio la
instancia con 2 funciones: `hasData` (cómo saber si ya hay datos válidos) y `run` (cómo disparar la
petición HTTP real y actualizar sus propios signals). `load(options)` de cada servicio delega
directamente en esa instancia.

**Rationale**: FR-007 exige que el comportamiento sea idéntico en ambos servicios. Una sola
implementación compartida garantiza esa igualdad por construcción (hay un solo lugar donde puede
haber un bug de caché/deduplicación, no dos copias que puedan divergir con el tiempo) en vez de
depender de que dos implementaciones separadas se mantengan sincronizadas a mano. Además, es
exactamente lo que pide el ticket original: "este patrón sienta el estándar para otros servicios
`providedIn: 'root'` que requieran esta optimización en el futuro" — con el helper ya extraído, un
futuro servicio solo necesita instanciarlo con su propio `hasData`/`run`, sin volver a escribir la
lógica de caché desde cero.

**Alternativas consideradas**: duplicar las ~15 líneas de lógica directamente dentro de cada
`load()` (descartada — funciona para 2 servicios, pero no "sienta el estándar" pedido y arriesga que
una futura corrección se aplique a un `load()` y se olvide en el otro); una clase base abstracta de
la que ambos servicios hereden (descartada — `TenantInfoService` y `PlanSummaryService` no comparten
ninguna otra responsabilidad entre sí más allá de este patrón de `load()`; forzar herencia entre
ambos, o introducir una tercera clase base de la que ambos pasen a heredar, acopla más de lo que
estas 15 líneas de lógica necesitan — una función de composición simple, no herencia, es coherente
con que el resto de los servicios de este proyecto son clases independientes que componen
funciones/signals, no jerarquías de herencia).

## 3. Identidad de la petición en curso: comparar la referencia de la `Promise`, no un booleano

**Decisión**: el campo que rastrea "la petición vigente" guarda la propia `Promise<void>` devuelta
por `run()` (no un `boolean` tipo `isLoading`). Al terminar, cada petición solo limpia ese campo si
sigue siendo exactamente la misma referencia que ella misma guardó al empezar
(`if (pending === request) pending = null`).

**Rationale**: es lo que permite que `load({ force: true })` reemplace de forma segura "cuál
petición es la vigente para llamadores futuros" (FR-004) sin cancelar ni interferir con una petición
normal que ya estaba en curso: al llegar el `force`, se dispara una nueva petición y el campo pasa a
apuntar a esa nueva referencia inmediatamente — la petición anterior sigue corriendo de forma
completamente independiente (nadie la cancela), y cuando termina, su propio bloque de limpieza nota
que el campo ya no es "su" referencia y no hace nada. Esto reproduce exactamente el Edge Case de
spec.md: "ambas peticiones HTTP se completan de forma independiente; el signal queda con el
resultado de la que termine más tarde" — sin necesidad de ningún mecanismo de secuenciación o
descarte de respuestas obsoletas (que las Assumptions de spec.md explícitamente no piden). Un
booleano no podría distinguir "mi petición sigue siendo la vigente" de "ya me reemplazó otra" al
momento de decidir si limpiar el campo.

**Alternativas consideradas**: un `boolean` simple (`isLoading`) que se pone en `false` al terminar
cualquier petición, sin importar cuál (descartada — con un `force` solapado, la petición vieja
terminaría borrando el estado "en curso" de la petición nueva que todavía no respondió, rompiendo
FR-004); un contador de versión (`requestId: number`) en vez de comparar la `Promise` en sí
(descartada por equivalente pero más indirecta — comparar la referencia de la `Promise` ya resuelve
lo mismo sin necesitar una variable adicional).

## 4. `loading`/`error` viven exclusivamente dentro de `run()`, nunca dentro del helper

**Decisión**: `createCachedLoader()` no conoce ni toca ningún signal de `loading`/`error` — esos
signals se gestionan por completo dentro de la función `run()` que cada servicio le pasa (la misma
función que hoy ya hace `this.loading.set(true)` / `this.error.set(null)` antes de la petición y
`this.loading.set(false)` en su `finally`). El helper solo decide **si** se llama a `run()` o no.

**Rationale**: implementa directamente FR-011 / Clarification 3 — un cache-hit o una unión a una
petición en curso nunca deben tocar `loading` ni `error`, precisamente porque en esos casos
`run()` nunca se invoca: no hay ninguna rama del helper que necesite "no tocar" esos signals a
propósito, porque ni siquiera tiene una referencia a ellos.

**Alternativas consideradas**: que el helper reciba `setLoading`/`setError` como parámetros
adicionales y los gestione él mismo alrededor de `run()` (descartada — funcionaría, pero dispersa la
responsabilidad de "qué pasa alrededor de la petición real" entre el helper y el servicio sin
necesidad; dejarlo todo dentro de `run()`, que ya existe hoy con esa forma exacta en ambos
servicios, es el cambio mínimo).

## 5. Qué cuenta como "dato en caché": el signal de datos ya existente, sin un flag adicional

**Decisión**: `hasData()` para cada servicio es simplemente `() => this.info() !== null` (o
`() => this.summary() !== null`) — el mismo signal que ya existe y que `hydrate()` ya puebla hoy. No
se agrega ningún campo nuevo tipo `loaded: boolean`.

**Rationale**: coincide exactamente con la Assumption de spec.md ("la validez del caché se
determina únicamente por si el signal de datos ya contiene un valor no nulo producto de una carga
exitosa — vía `load()` o vía `hydrate()`"). Usar el signal ya existente, en vez de un flag paralelo,
evita una segunda fuente de verdad que podría desincronizarse del signal real (p. ej. si algo deja
`loaded = true` pero el signal volviera a `null` por algún motivo) y hace que `hydrate()` participe
del caché gratis, sin que esta funcionalidad necesite tocarlo (FR-009): en cuanto `hydrate()` fija el
signal, `hasData()` ya es `true` para la siguiente llamada a `load()`.

**Alternativas consideradas**: un campo `loaded: boolean` separado que `load()` marque en `true`
tras el primer éxito (descartada — duplica lo que el signal de datos ya expresa, y exigiría que
`hydrate()` también lo marcara para que el caché lo reconociera, tocando un método que FR-009
prohíbe modificar).

## 6. Convenciones de testing a seguir

**Confirmado** (sin hallazgo nuevo — ya establecido por specs previas de este mismo repositorio,
p. ej. `100-bootstrap-dashboard-staff/research.md` § 10): el frontend usa Vitest a través del
builder `@angular/build:unit-test` de Angular 21 (no Karma/Jasmine); los tests de servicios usan
`TestBed` + `provideHttpClient()`/`provideHttpClientTesting()` + `HttpTestingController`, exactamente
el patrón que ya siguen `tenant-info.service.spec.ts` y `plan-summary.service.spec.ts`. El helper
nuevo (`cached-loader.util.ts`) no depende de Angular ni de HTTP, así que su propio spec
(`cached-loader.util.spec.ts`) se prueba de forma puramente funcional — sin `TestBed`, con
`Promise`/`vi.fn()` o equivalentes para simular `hasData`/`run`.

**Decisión**: los tests nuevos de esta funcionalidad siguen esas convenciones reales — un spec
nuevo para el helper (`cached-loader.util.spec.ts`, prefijo normal, comportamiento nuevo) y la
ampliación de los 2 specs de servicio ya existentes con los casos de las Historias 1 y 2, sin
modificar ninguno de los tests ya existentes en esos archivos (`uploadLogo`, `update`, `hydrate`),
que no se ven afectados por este cambio.
