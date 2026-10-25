# Quickstart: Métodos distintos en pago mixto e ingresos de caja por método de pago

**Spec**: [spec.md](./spec.md) | **Contracts**: [contracts/api.md](./contracts/api.md) |
**Data model**: [data-model.md](./data-model.md)

## Prerrequisitos

- Backend: venv de `pos-backend` activo (`source env/bin/activate`), Postgres local disponible
  (ver memoria de sesión `how-to-run-sibling-repo-tests`), migraciones al día
  (`alembic upgrade head`, incluida la nueva revisión `135_cash_movement_payment_method`).
- Un tenant de prueba con al menos 2 métodos de pago activos, uno de ellos `is_cash=True`
  (p. ej. "Efectivo" + "Nequi").
- Frontend: `pos-heladeria` corriendo contra ese backend (`ng serve`), sesión de cajero
  autenticada, un turno de caja abierto.

## US1 — Rechazar método repetido en pago mixto de pedido

### Backend (script de verificación, extiende el existente)

```bash
cd ../pos-backend && source env/bin/activate
python -m app.scripts.test_mixed_payment_checkout
```

Caso nuevo a agregar a ese script (o a `app/characterization_tests/` como test formal):

1. Construir `PayIn` con 2 líneas, ambas con el mismo `payment_method_id` (Nequi), sumando el
   total exacto del pedido.
2. Llamar `checkout.pay_order(...)`.
3. **Esperado**: `HTTPException(422)` con el nombre del método repetido en el mensaje; `0` filas
   `Payment` creadas; el pedido permanece `"pendiente"`/sin cobrar.
4. Repetir con 3 líneas donde 2 de las 3 repiten método (la 3ª distinta) — mismo resultado de
   rechazo (FR-003, aplica sin importar cuántas líneas tenga el cobro).
5. Control: 2 líneas con métodos distintos (Efectivo + Nequi) sumando el total exacto → `200`,
   2 filas `Payment`, pedido `"pagada"` (sin regresión).

### Frontend (manual, Terminal POS)

1. Abrir el panel "Cobrar pedido" de un pedido con total conocido.
2. Elegir "Nequi" en la primera línea, pulsar "Agregar otro método".
3. **Esperado**: el `<select>` de la segunda línea ya no ofrece "Nequi" como opción (filtrado,
   ver data-model.md). Elegir cualquier otro método → "Cobrar" se habilita cuando la suma sea
   exacta (sin cambio respecto a hoy).
4. Si de todos modos se fuerza (DevTools o API directa) un cobro con 2 líneas de Nequi → `422` del
   backend, panel conserva las líneas ingresadas para reintentar (mismo comportamiento de FR-009
   de spec 112 ante cualquier error del servidor).

## US2 — Ingreso de caja en un método distinto a efectivo

### Backend

```python
# dentro de with_db(schema) as db, con un turno abierto `shift` y método `nequi`
body = CashMovementIn(kind="ingreso", category="Aporte turno",
                       lines=[{"payment_method_id": nequi.id, "amount": 50000}])
movimientos = add_movement(shift.id, body, db, cashier)  # o la función de servicio equivalente
```

**Esperado**: 1 fila `CashMovement` con `payment_method_id = nequi.id`, `group_id = None`.
`reconcile(db, shift)["ingresos"]` **no** cambia (sigue sin incluir este movimiento).
`reconcile(db, shift)["ingresos_by_method"]` incluye una fila para Nequi con `total=50000`.

### Frontend (manual)

1. Abrir el modal "Registrar movimiento" → tipo "Ingreso".
2. **Esperado**: aparece un selector de método de pago (poblado con los métodos activos del
   tenant, mismo catálogo que el panel de cobro) que hoy no existe.
3. Elegir "Nequi", monto $50.000, descripción "Préstamo", confirmar.
4. **Esperado**: el movimiento queda en el historial del turno con método "Nequi"; el resumen de
   caja del turno (banner de efectivo esperado) **no cambia** tras este movimiento.
5. Cerrar el turno y abrir el reporte de arqueo: el desglose por método muestra Nequi con el
   ingreso registrado junto al total de ventas en Nequi de ese turno (FR-008).
6. Control: repetir con método "Efectivo" → comportamiento idéntico al actual (sí incrementa el
   efectivo esperado, FR-009, sin regresión).

## US3 — Ingreso mixto de caja en dos métodos

### Backend

```python
body = CashMovementIn(kind="ingreso", category="Aporte turno", lines=[
    {"payment_method_id": efectivo.id, "amount": 20000},
    {"payment_method_id": nequi.id, "amount": 30000},
])
filas = add_movement(shift.id, body, db, cashier)
```

**Esperado**: 2 filas `CashMovement`, mismo `group_id` en ambas, `payment_method_id` distintos.
`reconcile(db, shift)["ingresos"]` aumenta en `20000` (solo la porción efectivo).
`reconcile(db, shift)["ingresos_by_method"]` muestra Nequi con `total += 30000`.

Caso de rechazo: mismas 2 líneas pero con `payment_method_id` igual en ambas (p. ej. Efectivo +
Efectivo) → `422`, ninguna fila creada (FR-006). Caso de rechazo: 3 líneas → `422` de Pydantic
(`max_length=2`), antes de llegar al endpoint.

### Frontend (manual)

1. En el modal "Registrar movimiento" con tipo "Ingreso", tras elegir el primer método, pulsar
   "Agregar otro método" (visible solo si el tenant tiene ≥ 2 métodos activos — FR-013).
2. Elegir un segundo método distinto al primero (el `<select>` lo filtra, igual que en US1),
   monto de esa línea, confirmar.
3. **Esperado**: el historial del turno muestra las 2 líneas agrupables visualmente (mismo
   `group_id`/misma hora/misma descripción, FR-011); el efectivo esperado solo sube por la
   porción en efectivo de las 2 líneas.
4. Si el tenant solo tiene 1 método activo: "Agregar otro método" no aparece o está deshabilitado
   (edge case de la spec, FR-013) — no hay forma de forzar una segunda línea sin un método
   distinto real disponible.

## Verificación de no regresión (ambos repos)

```bash
cd ../pos-backend && source env/bin/activate
python -m unittest discover -s app/characterization_tests -p 'test_*.py'
python -m app.scripts.test_mixed_payment_checkout
python -m app.scripts.test_split_blindaje
python -m app.scripts.test_cash_net_sales   # si existe; confirma que FR-009/expected no cambia de fórmula
```

```bash
cd ../pos-heladeria
ng test --include='**/payment-draft.util.spec.ts' --include='**/cash-movement-modal*.spec.ts'
```

Frontend: comparar diff de archivos afectados contra el baseline conocido, no el conteo total de
la suite (memoria de sesión `how-to-run-sibling-repo-tests` — el baseline completo es flaky).
