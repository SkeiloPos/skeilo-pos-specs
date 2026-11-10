# Contrato: Cobro de un subconjunto de pedidos de una sesión de mesa

Extiende los endpoints existentes de `pos-backend/app/api/v1/table_sessions/`
(`router.py`, `service.py`, `schemas.py`). No reemplaza ningún contrato previo —
cuando no se envía `order_ids`, el comportamiento es exactamente el actual
(cobra todos los pedidos facturables de la sesión).

## 1. `GET /table-sessions/{table_session_id}/bill`

**Nuevo query param opcional**: `order_ids: list[UUID] | None`.

- Sin `order_ids`: comportamiento actual, sin cambios (cuenta de todos los pedidos
  facturables de la sesión).
- Con `order_ids`: la cuenta (`total`, `split`, `order_ids` de la respuesta) se
  calcula únicamente sobre los pedidos indicados.
- Si algún id en `order_ids` no pertenece a la sesión, o no está actualmente
  facturable (cancelado, ya `PAID`, o ya tiene una `Sale` emitida): `409 Conflict`
  con body:
  ```json
  {
    "error": "Algunos pedidos seleccionados no se pueden cobrar.",
    "order_ids": ["<uuid-invalido-1>", "<uuid-invalido-2>"]
  }
  ```
- `pending_balance` de la respuesta no cambia de semántica (sigue siendo sobre
  toda la sesión, como hoy — es un concepto distinto, FR fuera de alcance de esta
  feature).

## 2. `POST /table-sessions/{table_session_id}/charge`

**Nuevo campo opcional en el body** (`CloseSessionIn` o esquema derivado usado solo
por este endpoint): `order_ids: list[UUID] | None`.

- Sin `order_ids` (u omitido/`null`): comportamiento actual sin cambios — cobra
  todos los pedidos facturables de la sesión en una transacción (User Story 2,
  caso "cobrar todo lo pendiente").
- Con `order_ids` (1 o más): cobra únicamente esos pedidos (User Story 1 si es 1
  solo id; User Story 2 si son varios). Comportamiento:
  - Valida que cada id pertenezca a la sesión y esté facturable (misma regla que
    en `/bill`); si no, `409 Conflict` con el mismo formato de error.
  - Si la lista resultante queda vacía tras filtrar: `409 Conflict`,
    `"La sesión no tiene pedidos que cobrar"` (mensaje ya existente, reutilizado).
  - `_assert_closable` se evalúa **solo** sobre los pedidos seleccionados — un
    pedido no seleccionado en estado `'pendiente'` o con ítems en curso de cocina
    NO bloquea el cobro del pedido seleccionado.
  - Se crea 1 `Sale` (`billing_mode='unified'`) o 1 `Sale` por comensal
    (`billing_mode='split'`) cubriendo solo los pedidos seleccionados — misma
    lógica de `_close_unified`/`_close_split` ya existente, sin cambios internos.
  - Solo los pedidos seleccionados quedan con `payment_status='PAID'`; los demás
    pedidos de la sesión no se modifican.
  - La sesión y la mesa permanecen `active`/`ocupada` — igual que hoy, `/charge`
    nunca libera la mesa.

## 3. `POST /table-sessions/{table_session_id}/close`

**Sin cambios.** Este endpoint NO acepta `order_ids`: siempre cobra todos los
pedidos facturables de la sesión y libera la mesa en la misma transacción
(decisión D2 de `research.md`). Para cobrar parcialmente y liberar después, el
flujo es: `POST /charge` (con `order_ids` del subconjunto) una o más veces, y
`POST /release` cuando todos los pedidos de la sesión ya estén `PAID`.

## 4. `POST /table-sessions/{table_session_id}/release`

**Sin cambios.** Sigue exigiendo que el 100% de los pedidos de la sesión estén
`payment_status='PAID'` (o cancelados) antes de liberar la mesa — ya es el
comportamiento vigente desde spec 147 y satisface FR-005/FR-006 sin modificación.

## 5. `POST /orders/{order_id}/cancel`

**Sin cambios.** Ya cancela un pedido individual sin afectar a los demás pedidos
de la misma sesión — satisface FR-008 con el comportamiento existente.
