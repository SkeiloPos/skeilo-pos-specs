# Research: Métodos distintos en pago mixto e ingresos de caja por método de pago

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

## Decisión 1 — Dónde se valida "métodos distintos" en el pago mixto de pedido (US1)

**Decisión**: agregar la validación en los dos puntos que ya concentran, respectivamente, toda
escritura de pago y todo borrador de pago:

- **Backend**: dentro de `build_sale` (`pos-backend/app/api/v1/sales/builder.py:120-229`), justo
  antes/durante el bucle que crea las filas `Payment` (líneas ~215-223). Es el único lugar por el
  que pasan las 4 formas de cobrar (mostrador, cierre unificado, cierre dividido, `pay_order`
  legacy) — el propio docstring de `build_sale` explica que centralizar ahí fue la lección de un
  bug anterior ("hacerlo en cada [ruta] garantizaba que alguna se quedara fuera"). Si
  `len({p.payment_method_id for p in payments}) != len(payments)`, se rechaza con `422` y un
  mensaje que nombra el método repetido (FR-002), antes de crear ninguna fila `Payment` (ni
  tocar inventario ni facturar).
- **Frontend**: dentro de `paymentIssue()`
  (`pos-heladeria/src/app/modules/tables/services/payment-draft.util.ts:172-195`), que ya es la
  función única de validación del borrador (mensaje mostrado y botón "Cobrar" deshabilitado,
  mismo patrón que las reglas RN1-RN2 de spec 112).

**Rationale**: evita duplicar la regla en las 3 rutas de schema (`PayIn`, `CheckoutAndSendIn`,
`SaleCreate`) o en un `field_validator` por schema — un helper compartido invocado desde
`build_sale` basta porque es el único call site real de negocio (los schemas ya delegan toda
regla de negocio, no solo de forma, a `build_sale`: ver `max_length=3`, que sí vive en el schema
porque es forma, no negocio). Mantiene la misma asimetría que ya usa el proyecto: reglas de forma
(cardinalidad, tipos) en Pydantic; reglas de negocio (sumas, duplicados, saldo) en el builder.

**Alternativas consideradas**:
- **`field_validator` en cada uno de los 3 schemas de lista** (`PayIn.payments`,
  `CheckoutAndSendIn.payments`, `SaleCreate.payments`): descartada como único mecanismo — tendría
  que repetirse 3 veces (o extraerse a una función compartida de todos modos), y no cubre el caso
  en que `build_sale` se invoca desde código interno sin pasar por un endpoint HTTP (p. ej.
  `settle_pending_balance` de spec 123). Se descarta como *reemplazo* de la validación en
  `build_sale`, pero no hay objeción a añadirla además como defensa en profundidad si
  `/speckit-tasks` lo considera barato — no es necesaria para cumplir FR-001/FR-002/FR-003.
- **`CheckConstraint`/índice único a nivel de base de datos sobre `(sale_id, payment_method_id)`**:
  descartada — spec 112 (RN3/FR-005, revertido por A-146) permitía explícitamente que una venta
  tuviera 2 líneas del mismo método; un índice único histórico violaría datos ya existentes antes
  de esta spec. Igual que A-124/data-model.md de spec 112, la regla de "forma de las líneas" se
  mantiene en la capa de aplicación, no en la base de datos — consistente con que `build_sale` ya
  es, desde antes de esta spec, donde viven las invariantes de suma exacta y tope de 3 líneas.

**Impacto en el selector del frontend (edge case 4 de la spec)**: además de rechazar en
`paymentIssue()`, `PaymentInputComponent` (líneas ~66-76, `@for (m of methods; track m.id)`) deja
de listar, en el `<select>` de cada línea, los métodos ya elegidos en otra línea del mismo
borrador (salvo el propio de esa línea) — así el cajero no llega a seleccionar un método repetido
en el camino feliz, y `paymentIssue()` sigue siendo la red de seguridad si de todos modos ocurriera
(por ejemplo, al eliminar y reordenar líneas).

## Decisión 2 — A-146: registro de la reversión de A-124/FR-005 (Principio II)

Ver `registro-de-anomalias.md`, entrada `A-146` (ya registrada en esta misma Fase 0, antes de
cualquier tarea de implementación, siguiendo el mismo patrón que spec 132/A-144). No se repite el
contenido aquí; este research.md solo referencia la entrada como evidencia de que el gate del
Constitution Check de Principio II está satisfecho.

## Decisión 3 — No crear una entidad "Evento de ingreso" separada (US2/US3)

**Decisión**: extender `CashMovement` (`pos-backend/app/models/cash_movement.py`) con dos columnas
— `payment_method_id` (FK a `tenant.payment_methods`, `NOT NULL` tras backfill) y `group_id`
(`UUID`, nullable) — en vez de introducir una tabla/entidad padre "evento de ingreso" con hijos
"línea de ingreso". Un ingreso de una sola línea sigue siendo exactamente 1 fila `CashMovement`
(sin cambio de cardinalidad); un ingreso mixto de 2 líneas es 2 filas `CashMovement` que comparten
el mismo `group_id` (generado por el backend al crear ambas filas en la misma transacción).
Egreso y retiro (FR-012, fuera de alcance) siguen siendo siempre 1 fila, con `payment_method_id`
forzado al método cuyo `is_cash=True` del tenant y `group_id` siempre `NULL`.

**Rationale**: es el mismo patrón que ya usa el proyecto para "pago mixto" (`Payment` 1:N por
`Sale`, sin una entidad "Cobro" separada — el `sale_id` ya agrupa) — aquí no hay un "turno" que
agrupe de forma natural como `Sale` agrupa a `Payment`, así que `group_id` cumple ese rol mínimo
sin crear una tabla nueva solo para una relación 1:2. `FR-011` ("identificar que dos líneas
pertenecen al mismo evento") queda satisfecho con `group_id` compartido — no exige una tabla
padre, solo "poder identificar". Una tabla nueva (`cash_income_events` + `cash_income_lines`)
sería un cambio de forma mayor para una relación que nunca excede 2 filas y no necesita estado
propio (no se "cierra" ni se "aprueba" un evento de ingreso; cada línea es autónoma salvo por
compartir el link).

**Alternativas consideradas**:
- **Tabla `cash_income_events` (padre) + `cash_movements` con FK al evento**: descartada — exige
  una migración de los datos existentes (todo `CashMovement` histórico tendría que ganar un evento
  padre 1:1), introduce una tabla cuyo único propósito es agrupar como máximo 2 filas, y no aporta
  nada que `group_id` no resuelva ya para FR-011. Se preferiría solo si el negocio pidiera un
  estado o atributos propios del "evento" (no los pide: categoría/descripción ya son por línea,
  comparten los mismos valores en spec 135 por construcción del formulario, ver data-model.md).
- **Un solo `CashMovement` con dos columnas de monto/método (`amount_1`/`method_1`/`amount_2`/
  `method_2`)**: descartada — es el mismo patrón que `OrderPaymentAttempt.cash_amount`/
  `transfer_amount` (spec 130), pero ese patrón ya demostró ser menos extensible (spec 132 lo
  describe como limitado a exactamente 2 métodos fijos); replicarlo aquí cerraría la puerta si el
  negocio pidiera en el futuro una 3ª línea de ingreso (no lo pide esta spec, pero el modelo de
  filas por línea ya es el que usa `Payment`, consistente entre ambas capacidades del mismo spec).

## Decisión 4 — Backfill de `payment_method_id` en filas históricas de `cash_movements`

**Decisión**: la migración Alembic agrega `payment_method_id` como nullable, la rellena para cada
fila existente con el `id` del `PaymentMethod` del mismo tenant cuyo `is_cash=True` (hoy único por
tenant, ver `app/models/payment.py`), y luego la vuelve `NOT NULL`. Si un tenant no tuviera ningún
`PaymentMethod` con `is_cash=True` (no debería ocurrir — el catálogo de spec 032 siempre siembra
uno al aprovisionar el tenant), la migración falla de forma explícita en ese tenant en vez de
dejar una fila con método nulo o inventado.

**Rationale**: todo `CashMovement` registrado antes de esta spec era, por la limitación que esta
misma spec resuelve, necesariamente efectivo — asignarle el método "Efectivo" del mismo tenant no
reinterpreta ningún hecho de negocio (Principio VII: el **dato** se completa, la **decisión** ya
tomada en su momento — "este ingreso fue en efectivo" — no cambia).

**Estrategia de rollback**: `downgrade()` elimina ambas columnas (`payment_method_id`, `group_id`).
No hay pérdida de información irreversible porque ninguna columna existente se transforma ni se
elimina — el rollback solo retira la metadata nueva, dejando `cash_movements` exactamente como
estaba antes de esta spec.

## Decisión 5 — `reconcile()`: separar ingreso-efectivo de ingreso-otros-métodos

**Decisión**: en `pos-backend/app/api/v1/cash/service.py::reconcile`, la consulta de movimientos
manuales (hoy `group_by(CashMovement.kind)`, líneas ~196-206) pasa a unir con `PaymentMethod` y
agrupar también por `PaymentMethod.is_cash`:

```python
select(CashMovement.kind, PaymentMethod.is_cash, func.coalesce(func.sum(CashMovement.amount), 0))
.join(PaymentMethod, PaymentMethod.id == CashMovement.payment_method_id)
.where(CashMovement.cash_shift_id == shift.id)
.group_by(CashMovement.kind, PaymentMethod.is_cash)
```

`ingresos` (el término que entra en `expected`, FR-007) se calcula solo con
`kind='ingreso' AND is_cash=True` — la fórmula de `expected` (`opening_amount + ventas_efectivo +
ingresos - egresos - retiros`) no cambia de forma, solo la fuente de `ingresos` se vuelve más
estricta. `egresos`/`retiros` no cambian (siempre `is_cash=True` por FR-012). Una segunda consulta,
agrupada por `(payment_method_id, kind='ingreso')` para los métodos con `is_cash=False`, alimenta
un nuevo campo de respuesta `ingresos_by_method: list[SalesByMethod]` (reutiliza el DTO
`SalesByMethod` ya existente — mismos campos `method_id/method_name/method_type/total/count`) que
el reporte de arqueo muestra junto a `sales_by_method` (FR-008: "junto con el total de ventas de
ese mismo método").

**Rationale**: se descartó sumar los ingresos no-efectivo directamente dentro de
`sales_by_method[method].total` (fusionar con las ventas) porque `count` en `SalesByMethod` hoy
significa "número de ventas de ese método" — mezclarlo con "número de ingresos manuales" le
cambiaría el significado a un campo que otras pantallas (comprobante, spec 112 FR-020) ya
consumen asumiendo que es solo-ventas. Un campo paralelo (`ingresos_by_method`) preserva ese
contrato y cumple FR-008 literalmente ("el desglose... muestra, para cada método, el total de
ingresos... junto con el total de ventas") con dos números explícitos en vez de uno fusionado.

**Alternativas consideradas**:
- **Agregar `ingreso_total` como columna nueva dentro de `SalesByMethod`**: muy cercana a la
  decisión tomada; se descartó solo porque reutilizar el DTO completo como una lista aparte
  (`ingresos_by_method`) evita tocar el modelo que ya consume el comprobante de spec 112 y el
  reporte de spec 119, reduciendo el radio de cambio a `cash/schemas.py` y `cash/service.py`
  únicamente.

## Decisión 6 — Forma del contrato de `POST /cash/shifts/{id}/movements` (US2/US3)

**Decisión**: `CashMovementIn` mantiene `amount: Decimal | None` (antes requerido, ahora
opcional) para no romper compatibilidad con cualquier llamador existente que ya envíe
`{kind, amount, category, description}` — ese payload sigue siendo válido y se interpreta como
"una sola línea en efectivo" (comportamiento idéntico al actual, FR-009). Se agrega
`lines: list[CashMovementLineIn] | None` (1 o 2 elementos, cada uno
`{payment_method_id, amount}`), exclusivo con `amount`. Reglas de validación (en el endpoint, no
solo en el schema, siguiendo el mismo patrón que `build_sale`):

- `kind in ('egreso', 'retiro')` → exige `amount`, rechaza `lines` (siguen cash-only, FR-012); el
  backend asigna `payment_method_id` = método `is_cash=True` del tenant automáticamente, sin que
  el cliente lo envíe (no hay selector de método en egreso/retiro, por diseño — el frontend no
  cambia su formulario para esos dos tipos).
- `kind == 'ingreso'` con `amount` (sin `lines`) → 1 fila, método efectivo forzado (compatibilidad,
  FR-009).
- `kind == 'ingreso'` con `lines` (1 o 2) → 1 o 2 filas que comparten `group_id` (generado) cuando
  son 2; se rechaza con `422` si ambas líneas repiten `payment_method_id` (FR-006, mismo mensaje
  que FR-002 de US1) o si alguna referencia un método inactivo del tenant.
- Respuesta: el endpoint pasa de `response_model=CashMovementResponse` a
  `response_model=list[CashMovementResponse]` (1 o 2 elementos) — es un cambio de contrato
  intencional porque el frontend de esta misma spec es quien lo consume; no afecta a
  `GET /cash/shifts/{id}/movements` (`list_movements`), que ya devolvía una lista y simplemente
  gana el campo `payment_method_id`/`group_id` por fila.

**Rationale**: preservar el payload `{amount}` evita que esta spec se convierta, sin necesidad,
en una migración obligatoria de todo caller existente del endpoint de movimientos (no se
identificó ninguno fuera del propio modal de `pos-heladeria`, pero el principio de mínima
superficie de ruptura — Principio V/VI, "evolución incremental" — favorece la opción que no
rompe nada por accidente). El cambio de forma de la respuesta es aceptable porque ambos lados
(backend y frontend) se entregan juntos en esta spec.
