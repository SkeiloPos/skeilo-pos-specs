# Research: Sugerencias de Montos para Pago en Efectivo

## D1 — Las denominaciones de redondeo se implementan como constante en el frontend, no como catálogo del backend

**Decisión**: una constante nueva en `pos-heladeria` (p. ej. `ROUNDING_DENOMINATIONS_BY_CURRENCY: Record<string, number[]>`, con una sola entrada hoy: `{ COP: [8000, 10000, 20000, 50000, 100000] }`), no un endpoint nuevo de `pos-backend` ni una tabla nueva.

**Razón**: FR-004 exige que las denominaciones "se configuren según la moneda del tenant", pero
hoy **ningún tenant tiene un campo de moneda** (`grep -n "currency" app/models/tenant*.py` no
devuelve nada en `pos-backend`) — todos operan en pesos colombianos (spec 073, Assumptions, ya
confirmado en el spec de esta funcionalidad). Crear un endpoint o una tabla para una dimensión
("moneda del tenant") que no existe en ningún otro lugar del sistema sería anticipar
infraestructura sin un caso de uso real (Principio IX: toda dependencia/infraestructura nueva se
justifica por un problema real que resuelve). Modelar la constante como un mapa por código de
moneda (en vez de un arreglo plano) sí satisface la letra de FR-004 ("configurarse según la
moneda") al nivel de código: el día que exista un tenant en otra moneda, se agrega una entrada al
mapa sin tocar la lógica de `roundingSuggestions()`.

**Alternativas consideradas**:
- Exponer `GET /tenants/me/rounding-denominations` en `pos-backend` — rechazada: ningún otro
  endpoint expone "moneda del tenant" hoy; habría que inventar ese concepto solo para esta spec,
  mezclando una funcionalidad nueva con una base de datos que no existe (fuera del alcance de
  FR-001 a FR-013).
- Derivar las denominaciones del catálogo de arqueo de caja (`denomination_catalog.py`, spec
  121) — **descartada explícitamente en la sesión de `/speckit-clarify`** de spec.md: ese catálogo
  sirve para contar efectivo físico y, de usarse aquí, metería denominaciones no deseadas (p. ej.
  monedas, o $2.000/$20.000) en las sugerencias de redondeo, que siguen una lista propia y más
  corta (8.000/10.000/20.000/50.000/100.000).

## D2 — El rótulo visual sigue siendo "Cambio", no "Vuelto"

**Decisión**: los nuevos botones de sugerencia alimentan el campo "Con cuánto paga" / "Monto
recibido" ya existente; el bloque que muestra el resultado sigue rotulado **"Cambio"** (como hoy,
en ambos componentes), no "Vuelto".

**Razón**: `spec.md` usa "Vuelto: $[monto]" como lenguaje de negocio heredado literalmente del
escenario Gherkin que escribió quien pidió la funcionalidad — pero la implementación real
(`payment-input.component.ts:90-95`, `payment-attempt-review-panel.component.ts:137-153`) ya
muestra ese mismo dato bajo el rótulo "Cambio". Renombrar la etiqueta visual de "Cambio" a
"Vuelto" sería una refactorización de copy no relacionada con el valor de esta spec (botones de
sugerencia) y violaría el Principio V (ninguna funcionalidad nueva se usa como excusa para un
cambio no solicitado). FR-006 se satisface mostrando el mismo dato (el cambio calculado) en el
mismo bloque ya existente, con su rótulo actual.

**Alternativas consideradas**: renombrar "Cambio" → "Vuelto" en los dos componentes — rechazada
por lo anterior; además introduciría inconsistencia terminológica con el resto de la Terminal
(recibos, reportes de cierre de caja) que también dicen "Cambio"/"cambio entregado" (spec 108).

## D3 — El mensaje de monto insuficiente sigue siendo "Faltan $[monto] por asignar.", no "para cubrir la cuenta."

**Decisión**: cuando el monto registrado en efectivo no alcanza el saldo pendiente de la línea,
el mensaje visible sigue siendo el que ya calcula `paymentIssue()`
(`payment-draft.util.ts:166-167`): **"Faltan $[monto] por asignar."** — no se introduce un
mensaje nuevo "Faltan $[monto] para cubrir la cuenta." en `PaymentInputComponent`.

**Razón**: ese segundo texto viene de la spec 073 (anterior a la spec 112, que reescribió
`payment-draft.util.ts` para soportar pago mixto). El código actual ya no usa esa frase — se
verificó leyendo `payment-draft.util.ts` íntegro: la única función que compone el mensaje de
faltante es `paymentIssue()`, y compone exactamente `` `Faltan ${formatMoney(missing)} por
asignar.` ``. El enunciado original de spec 124 volvió a citar el texto de la spec 073 (ya
obsoleto) sin saberlo. FR-007 se satisface con el mensaje que el sistema ya produce hoy; no es un
cambio de comportamiento (el mensaje no cambia, solo la hipótesis inicial del spec sobre cuál
era el texto vigente).

En `PaymentAttemptReviewPanelComponent` ("Pagos por confirmar") no existe hoy ningún mensaje de
texto equivalente a "Faltan $X": el componente solo muestra el bloque "Cambio" en rojo con el
valor negativo (p. ej. "-$2.000") cuando el monto no alcanza, y deshabilita "Confirmar efectivo".
FR-007/FR-013 se satisfacen igual con ese mismo patrón visual ya existente (rojo + deshabilitado),
sin agregarle un mensaje de texto que hoy no tiene — agregar uno sería, de nuevo, una
refactorización de UI no relacionada con el valor de esta spec (sugerencias con un toque).

**Alternativas consideradas**: introducir el texto "para cubrir la cuenta" o un mensaje de texto
nuevo en el panel QR — rechazadas por lo anterior.

## D4 — "Exacto" es una etiqueta condicional del botón, no un campo de datos separado

**Decisión**: `roundingSuggestions(saldoPendiente, denominaciones)` devuelve una lista de números
(los redondeos deduplicados, ordenados ascendente, máximo 5 — uno por denominación). La etiqueta
"Exacto" (FR-012) es una decisión de **presentación** en el componente: al renderizar cada botón,
si su valor es igual a `saldoPendiente`, el componente muestra el texto "Exacto" en vez del monto
formateado; en cualquier otro botón muestra `formatMoney(valor)`.

**Razón**: mantiene la función pura simple (entrada: dos números/arreglo; salida: arreglo de
números) y fácil de testear por tabla (los ejemplos recalculados en spec.md, Acceptance
Scenarios), sin mezclar lógica de presentación (qué texto mostrar) con lógica de cálculo (qué
valores son válidos).

## D5 — En "Pagos por confirmar" el saldo pendiente es siempre el total del pedido

**Decisión**: para `PaymentAttemptReviewPanelComponent` (FR-013), las sugerencias se calculan
sobre `checkoutPreview().total` (el mismo total autoritativo que ya usa `cashChangePreview()`),
nunca sobre un saldo parcial — ese panel no tiene hoy ningún concepto de pago mixto ni de líneas
múltiples (confirmado leyendo el componente completo: un único `amountReceived`, un único
`PaymentAttempt` `pendiente` a la vez).

**Razón**: FR-001/FR-009 hablan de "saldo pendiente de la línea", que en esta superficie
simplemente coincide siempre con el total del pedido — no hay nada más que restar.

## D6 — Alcance de pruebas y baseline

**Decisión**: solo se ejecuta/actualiza la suite de `pos-heladeria`, módulo `tables`:
`npx ng test --watch=false --include='src/app/modules/tables/**/*.spec.ts'`. No se toca
`pos-backend` (sin cambios de código ahí, no aplica correr su suite de characterization tests).

**Razón**: el Summary ya establece que esta spec es puramente de frontend. Antes de implementar,
se vuelve a correr en aislado `payment-input.component.spec.ts`,
`payment-attempt-review-panel.component.spec.ts` y `payment-draft.util.spec.ts` para fijar su
conteo de fallas pre-existente (si alguno), siguiendo la lección ya registrada de que el conteo
de fallas de la suite **completa** no es determinista (cross-file TestBed/DI bleed) — solo el
conteo por archivo aislado es un baseline confiable.
