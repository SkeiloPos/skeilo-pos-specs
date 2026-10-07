# Feature Specification: Caché y deduplicación de peticiones en TenantInfoService y PlanSummaryService

**Feature Branch**: `101-cache-peticiones-tenant-plan`

**Created**: 2026-10-07

**Status**: Draft

**Input**: User description: "Evitar recargas redundantes y peticiones duplicadas en los servicios
core del shell (`TenantInfoService` y `PlanSummaryService`). El objetivo es prevenir deuda técnica
latente: evitar que futuros cambios en el árbol de componentes (o en el ciclo de vida del
enrutador) disparen múltiples llamadas simultáneas o innecesarias al backend sin ser detectadas en
code review. Prioridad: P3 (Prevención / Estabilidad arquitectónica). Usuarios: el equipo de
desarrollo se beneficia de una arquitectura resiliente donde los servicios gestionan su propio
caché e in-flight status de forma segura; el usuario final se beneficia indirectamente en ahorro de
ancho de banda y renderizados más consistentes. Requisitos técnicos citados en el ticket original:
modificar `load()` en `tenant-info.service.ts` y `plan-summary.service.ts` para que, si el
Signal/estado interno ya contiene datos, resuelva de inmediato sin disparar una petición HTTP; que
el servicio guarde una referencia a la petición en curso (Promesa u Observable multicasteado) y, si
llega otra llamada mientras hay una pendiente, retorne esa misma referencia en vez de disparar una
segunda llamada en paralelo; y que la firma se amplíe a `load(options?: { force?: boolean })`, de
modo que `force: true` ignore el caché, sobrescriba cualquier petición en vuelo si aplica, y
dispare siempre una petición HTTP real. Reglas de negocio: el patrón no debe alterar el ciclo de
vida actual de `DashboardLayoutComponent`, solo blindar a los servicios; tras una recarga forzada
exitosa, el caché y los Signals deben quedar actualizados para que las llamadas estándar siguientes
vuelvan a servirse desde caché; este patrón sienta el estándar para otros servicios
`providedIn: 'root'` que requieran esta optimización en el futuro."

## Clarifications

### Session 2026-10-07

- Q: El Escenario 3 del ticket describe `load({force:true})` disparándose justo después de guardar
  Ajustes del negocio, pero la sección de reglas de negocio dice que el patrón "no debe alterar el
  ciclo de vida actual de `DashboardLayoutComponent`, solo blindar a los servicios". Hoy, tras
  guardar en Ajustes (`tenant-info.component.ts`), `update()`/`uploadLogo()` ya refrescan el signal
  directamente desde la respuesta del propio PATCH — no existe ningún punto real que llame hoy a
  `load({force:true})`. ¿El spec debe conectar `force` en algún llamador real, o solo construirlo
  como capacidad del servicio? → A: Alcance limitado a los dos servicios. No se modifica ningún
  componente llamador; `force` queda disponible como capacidad pública de ambos servicios,
  verificada con tests unitarios directos. El Escenario 3 se interpreta como contrato del servicio,
  no como un cambio funcional visible hoy en producción.
- Q: El objetivo menciona explícitamente evitar llamadas duplicadas también por "cambios... en el
  ciclo de vida del enrutador". `PlanSummaryService` tiene además un método `fetch()` que usa
  `plan-module.guard.ts` para resolver la ruta del módulo de plan: hace su propio `GET /plan`
  directo, sin pasar por `load()`, el caché ni el signal, en cada activación de esa ruta. ¿Ese
  `fetch()`/el guard debe quedar cubierto por el nuevo caché, o queda fuera de alcance? → A: Fuera
  de alcance. `fetch()` y `plan-module.guard.ts` quedan tal cual, sin pasar por el nuevo caché; el
  spec se limita estrictamente a los métodos `load()` de `TenantInfoService` y `PlanSummaryService`.
- Q: Cuando `load()` resuelve desde caché o se une a una petición ya en curso, ¿debe tocar los
  signals `loading` y `error`, o dejarlos exactamente como estaban? Esto es observable hoy: `plan-
  summary-page.component.ts` muestra un spinner leyendo `planSummaryService.loading()`, y
  `tenant-info.component.ts` muestra un banner de error leyendo `tenantInfo.error()`. → A: Un
  cache-hit o una llamada que se une a una petición en curso NO tocan `loading` ni `error` en
  absoluto; esos signals solo se gestionan alrededor de la única petición HTTP real en curso. Un
  `error` de un `force` fallido anterior puede quedar visible hasta la siguiente petición HTTP real.

---

## User Scenarios & Testing *(mandatory)*

### Historia de Usuario 1 - Servir desde caché y deduplicar peticiones concurrentes (Priority: P1)

Hoy, cada llamada a `load()` en `TenantInfoService` o `PlanSummaryService` dispara siempre una
petición HTTP nueva, sin importar si el servicio ya tiene datos en memoria o si ya hay otra petición
idéntica en curso. Con esta funcionalidad, cuando el servicio ya tiene datos cacheados, `load()`
resuelve de inmediato sin tocar el backend; y cuando ya hay una petición pendiente, cualquier otra
llamada concurrente espera el resultado de esa misma petición en lugar de disparar una duplicada.
Esto blinda al equipo de desarrollo frente a futuros cambios en el árbol de componentes o en el
ciclo de vida del enrutador que, sin querer, multipliquen llamadas simultáneas o innecesarias al
backend.

**Por qué esta prioridad**: es el comportamiento que previene el problema central del ticket —
peticiones duplicadas o innecesarias— y el que protege contra la deuda técnica latente que motiva
todo el pedido; sin esto no hay nada que blindar.

**Prueba independiente**: puede probarse de forma aislada con tests unitarios sobre
`TenantInfoService` y `PlanSummaryService`: llamar a `load()` una vez, confirmar que llega una
petición HTTP; llamar de nuevo con datos ya en memoria y confirmar que no llega una segunda
petición; y disparar dos llamadas a `load()` casi simultáneas antes de que la primera responda,
confirmando que solo viaja una petición HTTP al backend y que ambos llamadores reciben el mismo
resultado.

**Acceptance Scenarios**:

1. **Given** que `TenantInfoService` (o `PlanSummaryService`) ya tiene datos en memoria —ya sea
   porque una carga previa fue exitosa o porque se hidrató vía `hydrate()` desde el arranque
   agregado del panel—, **When** un componente llama a `load()` sin el parámetro de forzado,
   **Then** el servicio retorna los datos cacheados de inmediato y NO dispara ninguna petición HTTP
   nueva.
2. **Given** que un `load()` inicial está en curso y el servidor aún no ha respondido, **When** otro
   componente llama a `load()` en ese mismo instante, **Then** no se dispara una segunda petición
   HTTP en paralelo; ambos llamadores quedan a la espera del resultado de la misma petición en
   curso.
3. **Given** que la petición en curso de `load()` termina en error, **When** un componente vuelve a
   llamar a `load()` sin forzado después de ese error, **Then** el servicio dispara una nueva
   petición HTTP (el intento fallido no cuenta como "datos cacheados" ni bloquea reintentos
   posteriores).

---

### Historia de Usuario 2 - Forzar una recarga explícita que ignora el caché (Priority: P2)

El servicio debe poder ignorar deliberadamente su caché cuando algo externo al propio servicio sabe
que los datos cambiaron (por ejemplo, tras guardar cambios de negocio en Ajustes) y necesita
garantizar una petición real al backend en ese momento, sin dejar el caché en un estado
inconsistente después.

**Por qué esta prioridad**: es el mecanismo de escape del caché introducido por la Historia 1; sin
él, cualquier futura necesidad legítima de refrescar datos quedaría bloqueada por el propio
blindaje. Es P2 porque hoy no existe ningún llamador real que lo necesite (ver Clarifications), así
que su valor es preventivo/arquitectónico, no un cambio visible de inmediato.

**Prueba independiente**: puede probarse con tests unitarios directos sobre el servicio: con datos
ya cacheados, llamar a `load({force: true})` y confirmar que sí dispara una petición HTTP real;
tras esa petición, llamar a `load()` sin forzado y confirmar que el nuevo valor se sirve desde caché
sin disparar otra petición.

**Acceptance Scenarios**:

1. **Given** que los datos ya están cacheados, **When** se llama a `load({force: true})`,
   **Then** el servicio ignora el caché y dispara obligatoriamente una nueva petición HTTP real al
   backend, sin importar que ya existieran datos en memoria.
2. **Given** que una recarga forzada se resuelve exitosamente, **When** la respuesta llega,
   **Then** los datos cacheados y el signal correspondiente quedan actualizados con esa respuesta.
3. **Given** que el caché ya quedó actualizado por una recarga forzada exitosa, **When** un
   componente llama a `load()` sin forzado después de eso, **Then** el servicio sirve el nuevo valor
   desde caché sin disparar una petición adicional.

---

### Edge Cases

- `hydrate()` sigue sin disparar peticiones HTTP y sigue pudiendo fijar el signal directamente en
  cualquier momento, sin importar si hay una petición de `load()` en curso; esta funcionalidad no
  modifica su comportamiento.
- El método `fetch()` de `PlanSummaryService` y `plan-module.guard.ts` (que lo usa para resolver la
  ruta del módulo de plan) no pasan por el caché ni la deduplicación descritos aquí; siguen
  disparando su propio `GET /plan` en cada activación de esa ruta, sin cambios (ver Clarifications).
- Esta funcionalidad no modifica el ciclo de vida de `DashboardLayoutComponent` ni de ningún otro
  componente que hoy llama a `load()` de estos dos servicios (`sales-page.component.ts`,
  `inventory-page.component.ts`, `plan-summary-page.component.ts`,
  `tenant-info.component.ts`); las comprobaciones que esos componentes ya hacen hoy antes de llamar
  a `load()` (por ejemplo, verificar si el signal ya tiene datos) se vuelven redundantes pero
  inofensivas, ya que el propio servicio evita la petición duplicada de todas formas.
- Si una recarga forzada se solapa con una petición normal que ya estaba en curso, ambas peticiones
  HTTP se completan de forma independiente; el signal queda con el resultado de la que termine más
  tarde, igual que el comportamiento actual del sistema cuando dos peticiones a estos servicios se
  solapan hoy.
- Si una recarga forzada (`load({force:true})`) termina en error mientras ya existían datos
  cacheados válidos de una carga anterior, el signal `error` queda con el mensaje de ese fallo y los
  datos cacheados previos se siguen sirviendo sin cambios. Como las llamadas a `load()` sin forzado
  posteriores resuelven desde caché sin tocar `error` (ver FR-011), ese mensaje de error permanece
  visible hasta la siguiente petición HTTP real (otro `force`, o un `load()` sin forzado si en algún
  momento el caché deja de ser válido); ninguna llamada cacheada lo limpia por sí sola.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Cuando `load()` se invoca sin el parámetro de forzado y el servicio ya tiene datos en
  memoria (por una carga previa exitosa o por `hydrate()`), el sistema DEBE resolver de inmediato
  con esos datos cacheados, sin disparar ninguna petición HTTP nueva.
- **FR-002**: Cuando `load()` se invoca sin el parámetro de forzado mientras ya existe una petición
  de carga en curso (iniciada por una llamada previa a `load()`), el sistema DEBE retornar al
  llamador el resultado de esa misma petición en curso, sin disparar una segunda petición HTTP en
  paralelo.
- **FR-003**: El sistema DEBE exponer en `load()` un parámetro opcional de forzado
  (`{ force: true }`) que, al usarse, ignore cualquier dato cacheado y dispare siempre una petición
  HTTP real al backend, sin importar si ya hay datos en memoria.
- **FR-004**: Cuando se invoca `load({ force: true })` mientras ya existe una petición en curso
  (forzada o no), el sistema DEBE iniciar una nueva petición HTTP real; a partir de ese instante,
  las llamadas a `load()` posteriores DEBEN quedar referenciando esa nueva petición forzada en
  curso en lugar de la anterior.
- **FR-005**: Una vez que una petición disparada por `load({ force: true })` se resuelve
  exitosamente, el sistema DEBE actualizar los datos cacheados y el signal correspondiente con la
  respuesta recibida, de forma que las siguientes llamadas a `load()` sin forzado vuelvan a servirse
  desde caché con ese nuevo valor.
- **FR-006**: Si la petición en curso (forzada o no) termina en error, el sistema DEBE dejar los
  datos cacheados sin marcarlos como "cargados exitosamente", de modo que una siguiente llamada a
  `load()` sin forzado dispare una nueva petición en lugar de quedar bloqueada indefinidamente por
  el intento fallido.
- **FR-007**: El sistema DEBE aplicar el comportamiento descrito en FR-001 a FR-006 de forma
  idéntica tanto en `TenantInfoService` como en `PlanSummaryService`.
- **FR-008**: Esta funcionalidad NO DEBE modificar el ciclo de vida actual de
  `DashboardLayoutComponent` ni de ningún otro componente que hoy llama a `load()` de estos dos
  servicios; el endurecimiento se limita exclusivamente al comportamiento interno de ambos
  servicios.
- **FR-009**: Esta funcionalidad NO DEBE alterar el comportamiento de `hydrate()` en ninguno de los
  dos servicios: sigue fijando el signal directamente sin disparar peticiones HTTP, sin importar si
  hay una petición de `load()` en curso.
- **FR-010**: El método `fetch()` de `PlanSummaryService` y `plan-module.guard.ts` quedan fuera de
  alcance de esta funcionalidad; esta spec no modifica su comportamiento de petición directa sin
  caché.
- **FR-011**: Cuando `load()` resuelve de inmediato desde datos cacheados (FR-001) o retorna el
  resultado de una petición ya en curso iniciada por otra llamada (FR-002), el sistema NO DEBE
  modificar los signals `loading` ni `error` de ese servicio. Ambos signals se gestionan
  exclusivamente alrededor de la única petición HTTP real que efectivamente se dispara (quien la
  inició); una llamada que resuelve sin disparar esa petición no los toca.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El número de peticiones HTTP nuevas disparadas por llamadas a `load()` sin forzado,
  cuando el servicio ya tiene datos en memoria, se reduce a cero en el 100% de los casos, para
  ambos servicios.
- **SC-002**: Cuando varias llamadas a `load()` sin forzado coinciden mientras ya hay una petición
  en curso, el número de peticiones HTTP reales disparadas en esa ventana se mantiene en una sola,
  en el 100% de los casos, para ambos servicios.
- **SC-003**: El 100% de las llamadas a `load({ force: true })` resultan en al menos una petición
  HTTP real al backend, sin importar el estado previo del caché.
- **SC-004**: Tras una recarga forzada exitosa, el 100% de las llamadas posteriores a `load()` sin
  forzado se sirven desde el nuevo valor cacheado sin disparar una petición adicional, hasta la
  siguiente recarga forzada o hasta que la aplicación se reinicie en el navegador.

## Assumptions

- El alcance se limita a `load()` en `TenantInfoService` y `PlanSummaryService`; no se modifica
  ningún componente llamador existente (`sales-page.component.ts`, `inventory-page.component.ts`,
  `plan-summary-page.component.ts`, `tenant-info.component.ts`) ni `DashboardLayoutComponent`. La
  capacidad de forzado (`force: true`) queda disponible para uso futuro y se verifica mediante
  tests unitarios directos sobre los servicios (Clarification 1).
- El método `fetch()` de `PlanSummaryService` y `plan-module.guard.ts` quedan fuera de alcance:
  siguen disparando su propio `GET /plan` en cada activación de ruta, sin pasar por el nuevo caché
  (Clarification 2).
- La validez del caché se determina únicamente por si el signal de datos ya contiene un valor no
  nulo producto de una carga exitosa (vía `load()` o vía `hydrate()`); un intento fallido no cuenta
  como "cargado" y no bloquea reintentos posteriores.
- No se introduce ningún mecanismo de expiración por tiempo (TTL): el caché permanece válido
  indefinidamente durante la vida de la aplicación en el navegador, hasta que ocurra una recarga
  forzada explícita o la página se recargue por completo.
- Cuando una petición forzada se solapa con una petición normal ya en curso, ambas peticiones HTTP
  se completan de forma independiente (no se cancela la petición ya enviada); el signal queda con
  el resultado de la que termine más tarde, igual que el comportamiento actual del sistema cuando
  dos peticiones a estos servicios se solapan hoy. Esta spec no introduce un mecanismo de
  secuenciación o descarte de respuestas obsoletas.
- El mecanismo de implementación concreto (por ejemplo, si se guarda una Promise, un Observable
  multicasteado, o si se extrae un helper/clase base reutilizable para futuros servicios
  `providedIn: 'root'`) es una decisión técnica que se define en la fase de planeación; esta spec
  solo exige el comportamiento observable descrito en los Criterios de Aceptación.
