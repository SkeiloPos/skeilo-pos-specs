# Data Model: Pago por transferencia y pago mixto sin subida de comprobante

**Spec**: [spec.md](./spec.md) | **Research**: [research.md](./research.md)

No se crean entidades nuevas. Se reutilizan y ajustan los modelos existentes de
`pos-backend` descritos abajo. Todos los cambios de esquema son de *constraint*, no de
columnas nuevas (ver research.md, Decisiones 2 y 4-7).

## Entidades reutilizadas

### `OrderPaymentAttempt` (`app/models/order_payment_attempt.py`, tabla `tenant.order_payment_attempts`)

Es la entidad **Pago** del spec. Ya existente desde spec 024 (base) y spec 130 (pago mixto).

| Campo | Tipo | Uso en spec 132 |
|---|---|---|
| `order_id` | FK → `customer_orders` | Sin cambio. |
| `payment_method_id` | FK → `payment_methods` | Sin cambio en significado; ahora también puede ser reescrito por `adjust-split` al convertir el método declarado (FR-013). |
| `status` | `pendiente` \| `confirmado` \| `rechazado` | Sin cambio de valores. `confirmado` ya no depende de que `receipt_file_url` esté presente (Decisión 1). |
| `amount_received` / `change_amount` | Numeric, solo efectivo | Sin cambio. |
| `receipt_file_url` | String, opcional | **Cambia quién lo escribe**: antes el comensal (vía presign+upload desde el QR), ahora exclusivamente el cajero al confirmar (FR-012). Nunca bloquea la confirmación si es `NULL`. |
| `cash_amount` / `transfer_amount` / `transfer_method_id` | Numeric/FK, pago mixto (spec 130) | Mutables por el cajero vía `adjust-split` (FR-013) mientras `status == 'pendiente'`; inmutables una vez `confirmado`/`rechazado`. |
| `cash_confirmed_at` | DateTime, opcional | Sin cambio de significado. |
| `rejection_reason` | String | **Se restringe** a un conjunto cerrado de 5 valores (FR-015): `cliente_no_muestra_app`, `monto_no_coincide`, `transferencia_no_completada`, `cliente_se_niega_a_mostrar`, `comprobante_sospechoso`. Validado en la API (`Enum`) y en la base de datos (nuevo `CheckConstraint`). |
| `resolved_by_user_id` / `resolved_at` | Sin cambio. |
| `version` | Sin cambio (lock optimista ya existente). |
| `created_at` | Sin cambio. |

**Invariantes (sin cambio de modelo, reforzados por lógica de aplicación)**:
- A lo sumo un intento `pendiente` por orden (índice único parcial ya existente).
- La suma de montos esperados de los pagos activos de una orden es igual al total del pedido
  (FR-022) — validado en `adjust-split` y en la creación de intentos mixtos (ya validado desde
  spec 130).

**Transiciones de estado relevantes para este spec**:

```
pendiente ──(approve, sin receipt_file_url obligatorio)──> confirmado
pendiente ──(reject, motivo del conjunto cerrado)────────> rechazado
rechazado ──(nuevo intento de transferencia, máx. 1 vez)─> pendiente (nuevo registro)
rechazado ──(ajuste a efectivo total + confirm-cash)─────> confirmado (nuevo registro o el mismo, según adjust-split)
rechazado ──(cancelación del pedido por impago)──────────> anulado (vía cancel_order existente)
pendiente ──(adjust-split: reajuste de la división)──────> pendiente (mismos valores de status, cash_amount/transfer_amount actualizados)
```

### `PaymentMethod` (`app/models/payment.py`)

Sin cambios. `is_cash` sigue siendo el discriminador de qué endpoint de confirmación aplica
(`approve` vs `confirm-cash`); `adjust-split` puede reasignar `payment_method_id`/
`transfer_method_id` a otro `PaymentMethod` existente del mismo tenant.

### `AuditLog` (`app/models/audit_log.py`, tabla `tenant.audit_logs`)

Es la entidad **Evento de pago** del spec (historial de auditoría, solo de inserción).
Reutilizada sin cambios de esquema (Decisión 3). Nuevos valores de `action` para este spec:

| `action` | `entity` | `entity_id` | `payload` (campos relevantes) |
|---|---|---|---|
| `payment_attempt.confirmed` | `order_payment_attempts` | id del intento | `{receipt_hash?, cash_amount, transfer_amount}` |
| `payment_attempt.rejected` | `order_payment_attempts` | id del intento | `{motivo, receipt_hash?}` |
| `payment_attempt.split_adjusted` | `order_payment_attempts` | id del intento | `{cash_amount_antes, transfer_amount_antes, cash_amount_despues, transfer_amount_despues}` |
| `order.cancel.loss` *(ya existente)* | `customer_orders` | id del pedido | se reutiliza tal cual; `motivo` distingue impago (`"impago_transferencia_rechazada"`) de una cancelación ordinaria |
| `payment.table_repeat_rejection` | `dining_tables` | id de la mesa | `{order_id, rejection_count_today}` |

Actor (`user_id`/`user_name`) y hora (`at`, `server_default=func.now()`) ya forman parte del
modelo — cubren "el cajero y la hora" exigido por FR-014/FR-019 sin campos adicionales.

### `CustomerOrder` (sin cambios de esquema)

El spec lo extiende solo **conceptualmente** (estado de pago derivado, Key Entities del spec):
pendiente de pago mientras tenga intentos sin resolver, pagado cuando todos los activos están
`confirmado`. Esto ya es exactamente el comportamiento de `_confirm_order_impl`/
`approve_payment_attempt`/`confirm_cash_payment_attempt` existentes; no requiere una columna
de estado de pago derivada porque se calcula a partir de `order.payment_attempts` en tiempo de
consulta (patrón ya usado por `current_payment_attempt`).

### `OrderCancelLog` (sin cambios de esquema)

Reutilizado tal cual para registrar la cancelación por impago (FR-018) con su `motivo`
distintivo.

## Cambios de esquema (migración Alembic)

Una sola revisión nueva, `<hash>_132_rejection_reason_enum.py`:

1. **Agregar** `CheckConstraint` sobre `tenant.order_payment_attempts.rejection_reason`
   restringiéndolo a los 5 valores del conjunto cerrado (Decisión 2), solo cuando
   `status = 'rechazado'` (coexiste con el `CheckConstraint` ya existente que exige
   `rejection_reason IS NOT NULL` en ese mismo caso).
2. **Sin** cambios de columnas, índices nuevos, ni tablas nuevas.

**Compatibilidad con datos existentes**: los `rejection_reason` ya persistidos como texto
libre (de rechazos anteriores a este spec, si existieran) deben auditarse antes de aplicar el
`CheckConstraint`; si hay valores fuera del conjunto cerrado, la migración los normaliza a
`comprobante_sospechoso` (motivo catch-all más conservador) en la misma transacción de la
migración, dejando constancia en el mensaje de la revisión — no se reinterpretan
retroactivamente los hechos de ese rechazo (Principio VII: solo se normaliza el *dato*, no se
cambia la decisión de negocio ya tomada en su momento).

**Estrategia de rollback**: `downgrade()` elimina el `CheckConstraint` agregado; no hay
pérdida de datos porque no se eliminan columnas ni se transforman valores de forma
irreversible (la normalización de valores fuera de rango, si ocurre, es el único paso con
efecto de datos, y es idempotente de re-ejecutar).
