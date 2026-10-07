# Fase 0 — Research: Carga agregada (bootstrap) del panel de staff

**Spec**: [spec.md](spec.md)

Las 3 ambigüedades de negocio del ticket original ya quedaron resueltas en `spec.md` →
`## Clarifications` (comportamiento ante fallo total, degradación parcial granular, y contenido
del bloque de notificaciones). Este documento no tiene por tanto ningún `NEEDS CLARIFICATION` de
negocio pendiente — todo lo que sigue son decisiones técnicas de implementación, derivadas de leer
el código actual de ambos repositorios.

## 1. Ruta y verbo del endpoint agregador

**Decisión**: `GET /api/v1/bootstrap`, router nuevo `app/api/v1/bootstrap/router.py`, montado en
`app/main.py` con el mismo prefijo `/api/v1` que el resto (`app/main.py:160-166`).

**Rationale**: sigue exactamente la convención ya vigente de un router por recurso bajo
`app/api/v1/<recurso>/` (`tenant/`, `plan/`, `notifications/`, `realtime/`). `GET` porque es una
lectura idempotente sin efecto secundario, igual que sus 3 fuentes — no crea ni modifica ningún
dato (spec.md, Key Entities: "No introduce datos nuevos ni persistentes").

**Alternativas consideradas**: `/dashboard/bootstrap` (descartada — no hay precedente de agrupar
rutas por pantalla de frontend en vez de por recurso de dominio); `POST /bootstrap` (descartada —
no hay body de entrada ni intención de escritura que justifique `POST`).

## 2. Resolver el usuario autenticado sin exigir que el tenant exista

**Hallazgo**: hoy `get_tenant(request)` (`app/core/db.py:190-211`) lee `X-Tenant-Host`, busca
`Tenant.host == host` y **lanza `HTTPException(404)`** si no hay fila — es la dependencia de la
que depende `get_current_user` (y por tanto, indirectamente, `/tenant`, `/plan` y
`/notifications`). No existe ninguna fila `Tenant` con `host='admin'` (`_seed_shared_data` en
`app/core/db.py` solo siembra `roles` y el usuario Super Admin, nunca un `Tenant`) — por lo que
hoy, cuando un Super Admin abre el mismo `DashboardLayoutComponent` (reutilizado por
`super-admin/routes.ts:7`), las 3 llamadas a `/tenant`, `/plan` y `/notifications` ya fallan con
`404` y ese error se traga en silencio en cada uno de los 3 servicios frontend (try/catch mudo).

Por otro lado, `get_authenticated_user` y `get_current_super_admin`
(`app/core/dependencies.py:273-335`) resuelven al usuario contra el schema `shared` vía
`get_shared_db`, **sin pasar por `get_tenant`** — es el mecanismo que ya usan hoy los endpoints de
`/super-admin/...`.

**Decisión**: el endpoint usa `get_authenticated_user` para resolver "quién hace la petición" (sea
staff de un tenant o Super Admin) y una dependencia nueva, `get_optional_tenant`, que reutiliza la
misma consulta de `get_tenant` pero **retorna `None` en lugar de levantar `404`** cuando el host no
resuelve a ningún `Tenant`. Para evitar duplicar la consulta, se extrae el `SELECT` de
`get_tenant` a un helper privado del que ambas dependencias se sirven (`get_tenant` sigue
levantando `404` para todo el resto de la API, sin cambios de comportamiento ahí — Principio II).

**Rationale**: expresar la tolerancia de Super Admin como un tipo `Optional[Tenant]` en la firma de
la dependencia es más legible y más seguro que capturar la `HTTPException(404)` de `get_tenant`
dentro del propio bootstrap (mezclar control de flujo HTTP entre dependencias). FR-007 exige un
`200` explícito con bloques `null`, no un error — por lo que el flujo normal del endpoint no debe
pasar nunca por una excepción en el caso de Super Admin.

**Alternativas consideradas**: capturar el `404` de `get_tenant` con un `try/except` dentro del
handler del bootstrap (descartada — frágil, acopla el bootstrap a los detalles internos de cómo
`get_tenant` señaliza "no encontrado"); crear una fila `Tenant` ficticia con `host='admin'`
(descartada de plano — cambiaría el modelo de datos sin que la spec lo autorice, Principio VIII,
y tendría efectos colaterales en cualquier otro endpoint que haga `Depends(get_tenant)` para rutas
de plataforma).

## 3. Degradación granular por bloque (FR-006)

**Decisión**: cada uno de los 3 bloques (`tenant`, `plan`, `notifications`) se calcula dentro de su
propio `try/except` independiente, en `app/api/v1/bootstrap/service.py::build_bootstrap()`. Un
fallo en uno nunca interrumpe a los otros dos; el bloque que falla queda `None` y los demás se
entregan completos, siempre con `200`.

**Rationale**: ya es el patrón que usa `app/api/v1/plan/service.py::build_plan_summary(db, tenant)`
— router delgado, función de servicio pura que recibe `db`/`tenant` ya resueltos. Extender ese
mismo patrón a 3 fuentes con 3 `try/except` independientes es lo mínimo necesario para FR-006, sin
introducir infraestructura de resiliencia nueva (sin circuit breaker, sin librería adicional —
Principio IX).

**Alternativas consideradas**: una única transacción/`try` que envuelva las 3 consultas
(descartada — es exactamente lo que FR-006 prohíbe: un fallo de `notifications` no puede tumbar
`tenant`/`plan`).

## 4. Forma del payload — reutilizar los schemas existentes tal cual

**Decisión**: `BootstrapResponse` (nuevo, `app/api/v1/bootstrap/schemas.py`) con 3 campos
opcionales que anidan, sin modificar, los schemas ya existentes:

```python
class BootstrapResponse(BaseModel):
    tenant: Optional[TenantInfoResponse] = None
    plan: Optional[PlanSummaryResponse] = None
    notifications: Optional[NotificationListResponse] = None
```

**Rationale**: la Assumption explícita de spec.md dice que "el contenido y el formato de cada
bloque ... es equivalente al que hoy entregan sus peticiones individuales". Anidar los mismos
schemas Pydantic ya existentes (`TenantInfoResponse` de `tenant/schemas.py:6-21`,
`PlanSummaryResponse` de `plan/schemas.py:19-30`, `NotificationListResponse` de
`notifications/schemas.py:9-30`) garantiza esa equivalencia por construcción — cualquier cambio
futuro a esos schemas se refleja automáticamente en el bootstrap, sin mantenimiento duplicado.

**Alternativas consideradas**: un `BootstrapResponse` plano con todos los campos al mismo nivel
(descartada — rompería la equivalencia 1:1 con cada endpoint individual y obligaría a sincronizar
a mano dos definiciones del mismo bloque).

## 5. Bloque `notifications` — misma página/tamaño que la primera carga actual

**Decisión**: el bloque `notifications` del bootstrap consulta exactamente `page=1, size=20` — los
mismos parámetros que `NotificationCenterService.bootstrap()` ya usa hoy en su primera carga
(`notification-center.service.ts:78-80`, cuando no hay `lastSeenId` persistido).

**Rationale**: FR-008 exige "la misma lista de notificaciones recientes que hoy entrega la primera
carga" — replicar esos mismos parámetros es la única forma de garantizar equivalencia exacta sin
inventar un nuevo criterio de "recientes".

**Nota fuera de alcance**: el modo `after_id` de recuperación tras reconexión
(`notifications-api.md § GET /notifications`) no participa del bootstrap — sigue siendo responsabilidad de
`NotificationCenterService.recoverMissed()`, sin cambios (FR-009).

## 6. Super Admin y el bloque `notifications`

**Decisión**: cuando `get_optional_tenant` resuelve `None` (Super Admin, o cualquier host que no
mapee a un tenant), el bootstrap retorna los 3 bloques en `None` — no solo `tenant`/`plan` — sin
intentar ninguna consulta contra un schema de tenant que no existe.

**Rationale**: la Assumption de spec.md dice que, para Super Admin, "el bloque de notificaciones
... conserva el mismo comportamiento que tiene hoy la carga individual de notificaciones para ese
rol". Hoy ese comportamiento es: `GET /notifications` también depende de `get_tenant` (ver
`notifications-api.md`: "tenant resuelto por `Depends(get_tenant)`"), así que también falla con
`404` y también se traga en silencio. `None` en el bootstrap reproduce ese mismo resultado
observable (lista vacía para el usuario) sin ejecutar una consulta contra un `schema_translate_map`
que no tiene a dónde apuntar.

## 7. Frontend — método `hydrate()` nuevo, en paralelo a los métodos existentes

**Decisión**: `TenantInfoService`, `PlanSummaryService` y `NotificationCenterService` ganan cada
uno un método público `hydrate(valor | null): void` que fija su signal de estado directamente, sin
disparar ningún `HttpClient`. Sus métodos existentes (`load()` en los dos primeros, `bootstrap()`
privado + `recoverMissed()` en el tercero) quedan intactos y siguen siendo el camino para los
refrescos puntuales (FR-003: p. ej. tras editar en "Ajustes") y para la recuperación tras
reconexión (FR-009).

**Rationale**: el ticket original pide explícitamente refactorizar estos mismos 2 archivos
(`dashboard-layout.component.ts:124-131` en el ticket original, que corresponde en realidad al
`ngOnInit` real en líneas 110-118 — ver nota abajo; y `notification-center.service.ts:71-88`) "para
consumirlo". Agregar un método de hidratación en paralelo, en vez de reemplazar `load()`, es lo
mínimo que cumple FR-002 sin arriesgar FR-003/FR-009 (Principio V — sin refactorizar más de lo que
la funcionalidad exige).

**Nota de precisión sobre el ticket original**: el rango de líneas citado para `ngOnInit`
(124-131) correspondía, al momento de esta investigación, al `constructor()` del componente (que
solo suscribe `Router.events` para cerrar el sidebar en navegación, sin relación con el bootstrap).
El `ngOnInit()` real que dispara `tenantInfo.load()`/`planSummaryService.load()`/
`realtime.connectStaff()` está en las líneas **110-118**. Se documenta aquí para que la
implementación no busque en el lugar equivocado; no cambia ningún requisito funcional.

**Alternativas consideradas**: que `load()` acepte un parámetro opcional con datos precargados
(descartada — mezclaría dos responsabilidades, "traer del servidor" y "recibir datos ya traídos",
en una sola firma, menos legible que un método separado con un nombre que deja clara la intención).

## 8. Condición de carrera en `NotificationCenterService` — guarda de una sola ejecución

**Hallazgo**: `NotificationCenterService` es `providedIn: 'root'` y dispara su `bootstrap()`
privado desde el propio constructor, en cuanto algo lo inyecta por primera vez — hoy eso ocurre
vía `HeaderComponent` (`inject(NotificationCenterService)` en el mismo shell). El orden exacto en
que Angular construye `HeaderComponent` respecto a cuándo el nuevo `BootstrapService` termina de
resolver la petición HTTP **no está garantizado por este cambio** — es un detalle de
instanciación/renderizado de Angular, no algo que esta funcionalidad controle.

**Decisión**: agregar una guarda booleana (`initialized`, o nombre equivalente) compartida entre el
`bootstrap()` privado existente y el nuevo `hydrate()` público: el primero que se ejecuta — sea el
propio arranque automático vía DI, o la hidratación con el bloque recibido del agregador — marca la
guarda y gana; el otro se vuelve no-operativo. Así, sin importar el orden real de instanciación, la
petición individual de notificaciones nunca se dispara dos veces ni compite con los datos ya
recibidos por el bootstrap.

**Rationale**: es la forma más acotada de eliminar la condición de carrera sin tocar el mecanismo
de auto-arranque por DI en sí (que otros puntos de entrada del sistema podrían depender de él hoy,
fuera del alcance de esta spec — Principio V). Verificar empíricamente el orden real de
instanciación en el navegador queda como paso de `quickstart.md`, no como supuesto de este
documento.

**Alternativas consideradas**: eliminar el auto-arranque del constructor y exigir que el shell
siempre llame explícitamente a `hydrate()`/`bootstrap()` (descartada por ahora — ampliaría el
cambio a cualquier otro punto de entrada que hoy dependa de ese auto-arranque vía DI, fuera del
alcance acotado por esta spec; queda anotada como posible mejora futura, no como parte de esta
funcionalidad).

**Corrección durante la implementación**: la premisa de esta decisión — que el orden entre el
auto-arranque y `hydrate()` "no está garantizado" — resultó ser incorrecta. `HeaderComponent` (y,
tras esta spec, también `BootstrapService`) inyectan `NotificationCenterService` como campo de
clase; Angular construye los componentes de forma síncrona, de padre a hijo, así que ese
auto-arranque corre **siempre** antes de que `ngOnInit()` del shell llegue a pedir `GET
/bootstrap` — JavaScript es de un solo hilo y la construcción de la clase (incluida la llamada
síncrona a `bootstrap()` desde el constructor) termina antes de que cualquier código externo
pueda llamar a `hydrate()`. El resultado, de implementarse tal cual esta decisión lo describe, es
que el auto-arranque gana **siempre** (no "a veces"), `GET /notifications` se sigue disparando por
separado en todas las cargas, y SC-001 no se cumple para ese bloque (seguirían viéndose 2
peticiones — `bootstrap` + `notifications` — en vez de 1).

Se verificó que `NotificationCenterService` no tiene ningún consumidor fuera de este mismo shell
(`HeaderComponent` + el nuevo `BootstrapService`), así que la alternativa antes descartada ya no
aplica: no hay ningún otro punto de entrada al que "ampliar el cambio". Decisión revisada (con
aprobación explícita del usuario durante `/speckit-implement`, dado que esto excede el alcance que
este documento había fijado): se retira la llamada incondicional a `bootstrap()` desde el
constructor. La recuperación por `lastSeenId` (RF-008) se conserva como código del constructor —
sigue siendo una petición propia e independiente, ya que el agregador no ofrece el modo
`after_id` (§5) — pero la carga común (sesión nueva, sin `lastSeenId`) llega ahora **solo** vía
`hydrate()`, sin ninguna petición `GET /notifications` de respaldo. El método privado `bootstrap()`
se elimina (ya no lo llama nadie); su rama "recuperación por `lastSeenId`" pasó al constructor y su
rama "primera carga" la cubre `hydrate()`.

## 9. Ticket de tiempo real — sin cambios

**Decisión**: `RealtimeService.connectStaff()` (llamada en `dashboard-layout.component.ts:116`)
sigue invocándose exactamente igual, fuera de — y sin relación con — la llamada al nuevo
`BootstrapService`.

**Rationale**: FR-004 lo excluye explícitamente del agregador, y ya es una petición de un solo uso
e independiente (`POST /realtime/ticket`, consumida una vez para abrir el stream SSE) — no hay
nada que mover ni envolver.

## 10. Convenciones de testing a seguir

**Hallazgo** (corrige un supuesto razonable pero incorrecto): el backend **no usa `pytest`** —
usa `unittest` estándar, con descubrimiento manual
(`python -m unittest discover -s app/characterization_tests -p 'test_*.py' -v`, README.md:207),
llamando las funciones de los routers directamente en Python (sin `TestClient`/HTTP). El frontend
**no usa Karma/Jasmine** — `angular.json` configura el builder `@angular/build:unit-test` de
Angular 21 y `package.json` trae `vitest`, es decir, corre sobre Vitest; los specs siguen usando
`TestBed` + `provideHttpClientTesting`/`HttpTestingController` (patrón estándar de Angular,
independiente del runner).

**Decisión**: los tests nuevos de esta funcionalidad siguen esas convenciones reales — backend:
`app/characterization_tests/test_bootstrap.py` (prefijo normal, no
`"CONGELA comportamiento actual:"`, porque es comportamiento **nuevo**, no heredado — mismo
criterio que ya usó la spec 077 para sus tests nuevos); frontend:
`bootstrap.service.spec.ts` nuevo + actualización de los specs existentes de
`tenant-info.service`, `plan-summary.service` y `notification-center.service` para cubrir
`hydrate()`.
