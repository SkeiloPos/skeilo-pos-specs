# Research: Cobro de pedido con múltiples métodos de pago

Ninguna de las preguntas abiertas de la spec exige `[NEEDS CLARIFICATION]` (ver checklist de
calidad, 0 marcadores). Este documento resuelve las decisiones de diseño que la spec deja a
criterio técnico, a partir de leer el código real de `pos-backend` y `pos-heladeria` (no se asume
nada sobre el estado del sistema).

## D1 — El backend ya soporta N pagos por venta; la restricción vivía solo en el frontend

**Decisión**: no tocar el modelo de datos (`Payment`/`Sale`) ni la lógica de `build_sale`
(`pos-backend/app/api/v1/sales/builder.py:120-247`). Reutilizarlos tal cual.

**Evidencia**:
- `Payment` es 1:N respecto a `Sale` desde spec 011 (`app/models/payment.py:80-103`,
  `app/models/sale.py:112-114`: `Sale.payments: Mapped[List["Payment"]]`).
- `PayIn.payments: list[PaymentIn] = Field(..., min_length=1)` (`app/api/v1/orders/schemas.py:385`)
  ya es una lista, sin tope superior.
- `build_sale` ya crea una fila `Payment` por cada línea (`builder.py:208-213`), ya valida
  `Σ amount ≥ total` (línea 217-221) y ya valida que `Σ pagos no-efectivo ≤ total` (línea 226-231,
  comentario explícito: "el vuelto solo sale del efectivo").
- `reconcile` (`app/api/v1/cash/service.py:106-190`) ya agrupa por `PaymentMethod` sin importar
  cuántas filas `Payment` tenga cada venta, y ya neta el cambio entregado a prorrata de las filas
  tipo `cash` (ajuste de spec 108).
- El recibo (`pos-heladeria/src/app/modules/tables/services/receipt.util.ts:97-100`) ya mapea
  `sale.payments` como lista, no como un único valor.

**Alternativas consideradas**: ninguna — introducir un modelo paralelo o un campo nuevo habría
duplicado algo que ya existe y funciona, violando el Principio V (sin refactors/estructuras
nuevas no necesarias).

## D2 — "Suma exacta" (RN1) es una validación de cliente, no del servidor

**Decisión**: la UI valida que `Σ montos asignados == total` antes de habilitar "Cobrar"
(FR-002/FR-003). El servidor conserva su validación actual, más laxa (`paid >= total`), sin
endurecerla a `==`.

**Por qué**: el servidor no distingue "monto asignado" de "monto recibido" — solo tiene
`Payment.amount`, y para la línea en efectivo ese campo ya representa hoy "cuánto entregó el
cliente" (de ahí que `change_given = paid - total` salga correcto sin un campo adicional). Si el
servidor exigiera `paid == total` rompería el cálculo de vuelto que ya usa el mostrador y la mesa
hoy con un único método. La regla de negocio "no se puede cobrar si falta o sobra" (RN1) se aplica
sobre los **montos asignados** (lo que cada línea *debería* cubrir), un concepto que solo existe en
el borrador del cliente antes de enviarlo — ver `data-model.md`.

**Alternativas consideradas**: añadir un campo `assigned_amount` separado de `amount` en
`PaymentIn`/`Payment` para que el servidor también pueda validar la suma exacta de forma
independiente. Rechazada por ahora: duplica en el servidor una validación que la UI ya hace de
forma suficiente para el flujo de caja (un solo punto de entrada, el panel de cobro), y agregar una
columna nueva a `Payment` es un cambio de modelo de datos (Principio VIII) no justificado por la
spec, que no pide persistir el monto "asignado" por separado del recibido — si en el futuro se
necesita auditar esa distinción, se puede abrir como spec propia.

## D3 — Mapeo de "monto asignado" y "con cuánto paga" al único campo `amount` del backend

**Decisión**: para una línea no efectivo, `PaymentIn.amount` = monto asignado (son el mismo
valor, porque RN2 impide que una línea no efectivo exceda el saldo pendiente). Para la línea en
efectivo, `PaymentIn.amount` = "con cuánto paga" el cliente (monto recibido), que es igual al
monto asignado cuando el cajero no escribe nada distinto (edge case ya cubierto en el spec).

**Por qué**: es exactamente la semántica que ya tiene el campo `amount` hoy en el flujo de un solo
método (`payment-input.component.ts`, el input "Con cuánto paga" para efectivo manda directamente
`amount`; para no-efectivo el input está deshabilitado y fijo en el total). Generalizar a N líneas
no cambia esa semántica, solo permite que la línea en efectivo sea una de varias.

## D4 — Vuelto y validación "no superar el saldo pendiente" por línea, no solo de forma global

**Decisión**: el "saldo pendiente" contra el que se valida una línea no efectivo (RN2, FR-007) es
`total − Σ (montos asignados de las demás líneas ya definidas)`, evaluado en el momento en que el
cajero escribe o cambia esa línea — no un chequeo final único. El vuelto (RN2/FR-006) se calcula
por línea de efectivo: `max(0, recibido − asignado)` de esa línea.

**Alternativas consideradas**: validar solo al pulsar "Cobrar" (un único chequeo global). Rechazada
porque los escenarios de aceptación (p. ej. "Una transferencia supera el saldo pendiente") esperan
el error en el momento de escribir el monto, no al confirmar — igual que ya hace
`paymentIssue()` hoy para el caso de un único método.

## D5 — Dos o más líneas en efectivo (caso no cubierto por los escenarios)

**Decisión**: permitirlo (RN3 solo limita el número total de líneas a 3 y permite repetir
método), con el vuelto calculado independientemente por cada línea de efectivo. El backend no
necesita saberlo: sigue sumando `Σ amount` y restando `total` para `change_given`, sin importar
cuántas de esas líneas sean efectivo.

**Por qué**: ningún escenario lo prohíbe ni lo ejercita explícitamente, y restringir "una sola
línea de efectivo" introduciría una regla que la spec no pide (violaría el Principio V — no
agregar restricciones no solicitadas). Se documenta aquí como la interpretación elegida por si
surge en implementación.

## D6 — No existe un estado "Despachado" en el código; US5/FR-017 ya está satisfecho por diseño

**Decisión**: no crear ningún estado nuevo. Verificado que el repositorio no tiene ningún valor de
enum "despachado"/"DISPATCHED" en `CustomerOrder.status` ni en `OrderItem.estado_cocina`
(`grep` sin resultados en `pos-backend` y `pos-heladeria`). El estado de cobro
(`CustomerOrder.status`/`OrderResponse.paid`, calculado por la existencia de una `Sale`) y el
estado operativo (`OrderItem.estado_cocina`) ya son dos ejes independientes por diseño
(`pos-heladeria/src/app/modules/orders/order-status.util.ts:7-13`). Un pedido de Domicilio puede
estar en cualquier estado operativo sin que exista una `Sale` asociada, y por lo tanto seguir
"Sin cobrar" — eso es exactamente lo que pide FR-017, y ya ocurre sin cambios.

**Riesgo**: si el negocio en realidad tiene en mente un estado "Despachado" que todavía no existe
como campo explícito (p. ej. lo infiere de otro dato, como la hora de entrega), esta spec no lo
está creando — si llegara a necesitarse, es alcance de una spec aparte.

## D7 — Dónde imponer el tope de 3 líneas

**Decisión**: en la UI (deshabilitar "Agregar otro método" al llegar a 3) **y** en el servidor
(`Field(..., min_length=1, max_length=3)` en `PaymentIn.payments` de `PayIn`, `CheckoutAndSendIn` y
`SaleCreate` — las tres rutas de cobro que comparten `build_sale`). Defensa en profundidad barata
(una palabra por schema) contra un cliente que no sea el panel de cobro oficial (p. ej. un script,
u otro frontend futuro).
