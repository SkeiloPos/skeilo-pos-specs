# Contrato — Bloqueo de "Liberar Mesa" con saldo pendiente

**FR cubiertos**: FR-016.

## `POST /table-sessions/{id}/release` (extensión additiva)

Endpoint ya existente (`table_sessions/service.py::release_paid_session`), el único cableado al
botón "Liberar Mesa" del frontend actual (`pos-checkout-panel.component.ts` → `pos-terminal.
store.ts::releaseTable()` → `table-session.service.ts::release()`).

### Cambio

Nueva guarda, inmediatamente después del chequeo existente `has_billable_orders`:

```text
1. ts.status != "active"              → 409 (sin cambios)
2. has_billable_orders(db, ts.id)     → 409 "Todavía hay algo por cobrar en esta mesa;
                                          cóbralo antes de liberarla." (sin cambios)
3. has_pending_balance(db, ts.id)     → 409 "Hay un saldo pendiente por cobrar"   ← NUEVO
4. _assert_closable(db, orders)       → 409 ítems en curso en cocina (sin cambios)
```

`has_pending_balance` recorre las órdenes de la sesión y suma el saldo pendiente de cada una
(`data-model.md` §1) — función hermana de `has_billable_orders`, mismo archivo, mismo patrón.

### Efecto

Una vez el saldo pendiente llega a `0` (cobrado íntegramente vía
`complementary-payment.md`), un segundo intento de liberar la mesa pasa esta guarda sin bloqueo,
sin necesidad de ninguna acción adicional del cajero.

### Fuera de alcance de este contrato

El endpoint legado `checkout.release_table` (`POST /tables/{table_id}/release`) no está cableado
en el frontend actual y no gana esta guarda en esta spec (research.md D5) — queda documentado como
deuda conocida si ese camino se reactiva.

### Errores

| Código | Caso |
|---|---|
| 409 | saldo pendiente > 0 — mensaje exacto "Hay un saldo pendiente por cobrar" |
