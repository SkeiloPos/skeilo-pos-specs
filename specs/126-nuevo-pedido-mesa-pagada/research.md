# Research: Nuevo Pedido en Mesa con Cuenta Pagada (replanificado tras A-138)

No quedan `[NEEDS CLARIFICATION]` en `spec.md` (dos sesiones de `/speckit-clarify`, 6 preguntas
resueltas). El trabajo de esta fase es distinto del habitual: en vez de resolver incógnitas
técnicas para una funcionalidad nueva, se **verifica, FR por FR, si el comportamiento ya exigido
por `spec.md` ya está cubierto por tests existentes**, y se decide dónde hace falta un test de
regresión nuevo (sin tocar ningún archivo de producción) para dejar trazabilidad explícita hacia
A-138.

## Decisión 1: FR-001 (CTA siempre habilitado, sin condición de saldo) — cobertura parcial, se agrega un test

**Decision**: la cobertura actual es sólida pero no 100% explícita para el caso exacto de
A-138. Dos tests ya existentes lo acercan:
- `table-sessions.component.spec.ts`, "el CTA solo se deshabilita por falta de mesa libre en la
  pestaña 'mesas' (FR-007, FR-012)" (spec 078/087): prueba que, **sin ninguna mesa
  seleccionada**, el único motivo de deshabilitación es la falta de mesa libre.
- `table-sessions.component.spec.ts`, línea ~427, "bugfix: el CTA '+ Crear pedido nuevo' de la
  sub-barra sigue visible con una mesa/pedido seleccionado": prueba que el CTA se **renderiza**
  con una mesa seleccionada que tiene un pedido `'recibida'` (sin pagar) — pero no verifica
  explícitamente `.disabled === false`.

Ninguno de los dos cubre, en una sola aserción, "mesa seleccionada + pedido con
`pending_balance > 0` ⇒ CTA habilitado". Se agrega un test nuevo en
`pos-terminal.store.spec.ts` y/o `table-sessions.component.spec.ts` que lo haga explícito, citando
A-138, para que una futura reintroducción accidental de A-137 falle un test con un mensaje que
apunte directamente a la decisión de negocio que lo prohíbe.

**Rationale**: Principio III exige que un comportamiento ya decidido no se pueda revertir en
silencio. Sin un test que lo nombre explícitamente, alguien podría reintroducir la condición de
saldo pendiente sin darse cuenta de que ya se decidió (dos veces) lo contrario.

**Alternatives considered**: no agregar nada, confiando en la cobertura indirecta ya existente —
rechazada: esa cobertura prueba "se renderiza" y "se deshabilita solo sin mesa libre" por
separado, pero nunca junta ambas condiciones (mesa con saldo pendiente + habilitado) en una sola
aserción verificable.

## Decisión 2: FR-002 (crear un pedido no modifica el estado de los pedidos existentes) — sin test nuevo

**Decision**: no se agrega ningún test nuevo para este FR.

**Rationale**: no existe, en todo el código de `manual-order-page.component.ts`/
`pos-terminal.store.ts`, ninguna ruta que lea o escriba un pedido *distinto* del que se está
creando al confirmar un pedido nuevo — `confirm()` solo arma un `POST /orders` con las líneas del
carrito en memoria (`draftLines()`); no hay ningún parámetro ni lógica que referencie otros
pedidos de la mesa. El riesgo que FR-002 describe no tiene ninguna vía de ocurrir en el código
actual, así que un test no protegería contra una regresión plausible — sería un test que nunca
podría fallar salvo que se escribiera código completamente nuevo para violarlo (lo cual a su vez
necesitaría pasar por esta misma spec).

**Alternatives considered**: un test de integración que cree dos pedidos y compare `pending_balance`
del primero antes/después — descartado como ruido: no ejercita ninguna lógica real de "fusión",
porque esa lógica no existe.

## Decisión 3: FR-003/004/005/006/007/008 (navegación, independencia, pestañas, cocina, draft no persistido) — cobertura ya existente, sin test nuevo

**Decision**: estos FR describen comportamiento ya propio de las specs que lo construyeron
(045/052/087/049), con sus propias suites de test ya existentes y sin relación con A-137/A-138 —
nunca estuvieron en riesgo de cambiar durante la primera sesión de clarificación, y no cambian
ahora. No se agrega ningún test nuevo citando spec 126 para ellos: harían doble contabilidad de
una cobertura que ya existe y ya se referencia a sus specs de origen.

**Rationale**: Principio V/VI (incremental, sin refactor/test oportunista) — duplicar tests ya
existentes bajo una cita distinta no añade protección real, solo mantenimiento.

**Alternatives considered**: ninguna — es la aplicación directa del principio de incrementalidad.

## Decisión 4: FR-009 ("Liberar Mesa" como único punto de control) — cobertura ya existente, sin test nuevo

**Decision**: `has_billable_orders`/`has_pending_balance`/`release_paid_session` ya tienen
cobertura de characterization tests en `test_table_sessions_service.py` y
`test_table_sessions_router.py` (spec 123, Historia 5). Esta spec no modifica esa lógica —
confirmarla en verde **sin tocarla** es la verificación suficiente (ver plan.md, Constitution
Check, Principio X).

**Rationale**: igual que Decisión 3 — comportamiento ajeno al alcance real de esta spec
(restringir/no-restringir la creación), nunca estuvo en juego.

**Alternatives considered**: ninguna.

## Decisión 5: FR-010 (sin acción de "consolidar cuentas") — no aplica test automatizado, se confirma por inspección

**Decision**: es la ausencia de una funcionalidad, no un comportamiento que un test pueda
ejercitar significativamente — no existe, en ningún componente de `pos-heladeria`, ningún botón,
ruta ni llamada a API que combine el cobro o la factura de dos pedidos distintos en una sola
operación (confirmado por inspección de `pos-checkout-panel.component.ts`,
`session-bill-panel.component.ts` y `table_sessions/service.py::close_session` durante esta
sesión — `BillingMode.UNIFIED` combina solo los pedidos **todavía no facturados** de la sesión
activa en un único cobro, nunca un pedido ya con `Sale` emitida). Un test que afirmara "no existe
el botón X" sería frágil (acoplado al DOM, no a una regla de negocio) y de bajo valor.

**Rationale**: Principio X exige verificación proporcional al riesgo real, no cobertura
automatizada de cada enunciado negativo de una spec.

**Alternatives considered**: test de snapshot del DOM del panel de cobro buscando ausencia de un
botón "Consolidar" — rechazado, frágil y de bajo valor explicado arriba.

## Decisión 6: FR-011 (anular pedido = único procedimiento de excepción) — cobertura ya existente, sin test nuevo

**Decision**: `cancel_order` ya tiene characterization tests (`test_orders_checkout.py`,
`test_orders_kitchen.py`, `test_order_audit_log.py`). Se confirmó además, por búsqueda directa en
`pos-backend/app/api/v1/table_sessions/` y `orders/` (`grep` de `forzar`/`force_release`/
`write_off`/`condonar`), que **no existe ningún mecanismo de liberación forzada** hoy — la
ausencia que FR-011 exige ya es un hecho del código, no algo por construir ni por testear
negativamente (mismo razonamiento que Decisión 5).

**Rationale**: igual que Decisión 5.

**Alternatives considered**: ninguna.

## Decisión 7: Alcance final de tareas

**Decision**: el único artefacto de código de esta spec es **un test de regresión nuevo**
(Decisión 1), en `pos-heladeria` (frontend), sin ningún cambio de producción en ningún
repositorio. Se ejecutan además, sin modificarlas, las suites completas de characterization
tests de `pos-backend` y de `ng test` en `pos-heladeria` para confirmar que nada se rompió.

**Rationale**: es la conclusión directa de las Decisiones 1-6 — prácticamente todo el
comportamiento exigido por `spec.md` ya está construido y ya probado; el valor que agrega esta
spec es la trazabilidad hacia A-138, no código nuevo.

**Alternatives considered**: no agregar ningún test y cerrar la spec como "pura documentación" —
considerada, pero rechazada: un test nuevo citando A-138 es el costo mínimo para que Principio
III tenga algo concreto que proteger si alguien intenta reintroducir A-137 sin pasar por una
nueva decisión de negocio.
