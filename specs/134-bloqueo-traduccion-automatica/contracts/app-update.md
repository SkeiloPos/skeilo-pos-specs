# Contrato: actualización de versión y momento seguro

**Cubre**: FR-018, FR-019, FR-020 · **Historia**: US4 · **Decisión**: [research.md](../research.md) 6

Ubicación (en `../pos-heladeria/src/app/core/update/`): `app-update.service.ts`,
`update-gate.service.ts`, `inflight-requests.interceptor.ts`.

## `UpdateGateService` (raíz)

```text
beginRequest(): void / endRequest(): void          // contador de escrituras en vuelo
registerBlocker(name: string, active: () => boolean): () => void   // devuelve el "retirar"
isSafeMoment(): boolean                            // M1–M6
```

`isSafeMoment()` es `true` solo si se cumplen **todas** (M1–M6 de [research.md](../research.md), Decisión 6):

| # | Condición |
|---|---|
| M1 | `!PageIntegrityService.altered()` |
| M2 | contador de escrituras en vuelo = 0 |
| M3 | ningún `.fixed.inset-0` con `getClientRects().length > 0` |
| M4 | ningún `.ng-dirty` en el documento |
| M5 | `document.activeElement` no es un `input`/`textarea`/`[contenteditable]` con valor |
| M6 | ningún predicado registrado con `registerBlocker` devuelve `true` |

Registro único hoy: `pos-terminal-draft` → `PosTerminalStore.hasDraft()` (cubre Terminal y orden
manual). Todo acceso al DOM va protegido (`try/catch`, `typeof document`).

## `AppUpdateService` (raíz, iniciado por `provideAppInitializer`)

| Comportamiento | Contrato |
|---|---|
| Desactivado | si `!swUpdate.isEnabled` (desarrollo): no hace nada |
| Comprobación al arrancar | tras `navigator.serviceWorker.ready` (espera acotada a 60 s: el registro es `registerWhenStable:30000`) → `checkForUpdate()` |
| Comprobación al volver a primer plano | en `visibilitychange` a visible → `checkForUpdate()`; mínimo 60 s entre comprobaciones |
| Detección | `versionUpdates` filtrado a `VERSION_READY` ⇒ `pending = true`; `unrecoverable` ⇒ `pending = true` |
| Aplicación | con `pending`: cada 15 s y al volver a primer plano, si `isSafeMoment()` → `activateUpdate()` → recarga (`inject(RELOAD_PAGE)()`, que en producción ejecuta `location.reload()`) |
| Guardián anti-bucle | antes de recargar escribe `sessionStorage['pos.update.autoReloadAt'] = Date.now()`; si existe una marca de < 120 s, **no** recarga (try/catch: sin almacenamiento ⇒ sin marca) |
| Errores | `checkForUpdate()`/`activateUpdate()` que fallen se registran con `console.warn` y se reintentan en el siguiente ciclo; nunca lanzan |

`reloadNow()` (lo usa el botón "Recargar" del aviso): si hay `pending`, `activateUpdate()` primero;
siempre termina en `RELOAD_PAGE` (`core/reload-page.ts`). Es la única ruta de recarga iniciada por una persona.

## Conservación (FR-020)

La recarga conserva sesión y lo confirmado por el mismo mecanismo que "Recargar" del aviso (token
del comensal en `localStorage`, carrito/pedidos en el servidor, `checkoutHydrationGuard`, tokens del
personal). Lo único que la recarga descarta es lo que M3–M6 ya impiden descartar.

## `inflightRequestsInterceptor`

```text
si !req.url.startsWith(environment.apiBaseUrl) || método es GET/HEAD/OPTIONS → next(req)
en otro caso: gate.beginRequest(); return next(req).pipe(finalize(() => gate.endRequest()))
```

Se registra en `withInterceptors([pageIntegrityInterceptor, inflightRequestsInterceptor, authTokenInterceptor])`.
(El rechazado por `pageIntegrityInterceptor` nunca llega a contarse.)

## Límite conocido del primer despliegue

Las pestañas abiertas **antes** de publicar este arreglo no contienen `AppUpdateService` y no
pueden actualizarse solas: requieren una recarga manual una única vez. Es paso de despliegue
(quickstart, "Despliegue"), no código.

## Pruebas (`app-update.service.spec.ts`, `update-gate.service.spec.ts`, con `SwUpdate` simulado)

| Prueba |
|---|
| `isEnabled=false` ⇒ ni comprueba ni recarga |
| Se comprueba al arrancar (tras `ready`) y al volver a primer plano, no más de una vez por 60 s |
| `VERSION_READY` con momento seguro ⇒ `activateUpdate()` + recarga; **por cada** condición M1–M6 activa ⇒ no recarga y reintenta |
| Un envío/pago en vuelo (POST sin completar) retiene la recarga hasta que termina |
| Alteración activa + versión pendiente ⇒ no recarga solo (prioridad del aviso) |
| Marca `autoReloadAt` reciente ⇒ no recarga; `sessionStorage` que lanza ⇒ se comporta como sin marca |
| `registerBlocker` + `hasDraft()` verdadero ⇒ retiene; el "retirar" devuelto lo quita |
