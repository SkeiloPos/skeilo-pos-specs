# Fase 1 — Data Model: Rediseño del Menú QR, pago mixto y bloqueo de salida

Ver decisiones técnicas en [research.md](./research.md). Describe entidades, campos y
validaciones — no el DDL completo (pertenece a la implementación/`/speckit-tasks`).

## Entidades

### `OrderPaymentAttempt` (modificada — esquema `tenant`, tabla `order_payment_attempts`)

Columnas nuevas, todas nullable (compatibles con filas existentes sin backfill: `NULL` en todas
para cualquier intento no mixto, pasado o futuro).

| Campo | Tipo | Notas |
|---|---|---|
| `cash_amount` | `Numeric(12,2)`, NULL | Monto en efectivo del pago mixto. `NULL` ⇔ el intento no es mixto. |
| `transfer_amount` | `Numeric(12,2)`, NULL | Resto a transferir, calculado y persistido al crear el intento (`total - cash_amount`). `NULL` ⇔ no es mixto. |
| `transfer_method_id` | UUID FK → `tenant.payment_methods.id`, NULL | Método de transferencia real (ej. Nequi) elegido por el comensal para el resto (FR-005). `NULL` ⇔ no es mixto. Datos de cuenta/QR a mostrar (FR-007) se leen de `transfer_method_id.payment_info`, no de `payment_method_id.payment_info` (ese apunta al método "Pago mixto" del catálogo, sin cuenta propia). |
| `cash_confirmed_at` | `DateTime`, NULL | Cuándo el cajero confirmó el cobro de la porción en efectivo (research.md Decisión 4). `NULL` hasta que se cobra; siempre `NULL` en intentos no mixtos (su confirmación de efectivo sigue usando `status` como hoy, sin cambios). |

**Reglas nuevas**:
- Mixto ⇔ `cash_amount IS NOT NULL` (invariante — los tres campos nuevos se escriben/leen juntos).
- `0 < cash_amount < (total del pedido en el momento del envío)` (FR-006), validado por la capa de
  aplicación en `submit_cart`, no por `CheckConstraint` (el total vive en `CustomerOrder`, no en
  esta fila).
- `transfer_amount = total - cash_amount` en el momento de creación; no se recalcula después.
- `status` (`pendiente|confirmado|rechazado`, sin cambio de tipo) representa, en un intento mixto,
  exclusivamente la verificación de la porción por transferencia (mismo mecanismo que hoy:
  `receipt_file_url` + `approve_payment_attempt`/`reject_payment_attempt`).
- "Pago mixto completamente confirmado" = `status = 'confirmado' AND cash_confirmed_at IS NOT NULL`.
  "Pago mixto pendiente" (para FR-009, bloqueo de salida) = lo contrario de esa expresión.
- `idx_pending_payment_attempt_per_order` (único parcial, `status='pendiente'`, FR-015a de spec
  024) **no cambia** — un pago mixto sigue siendo una sola fila, así que sigue cumpliendo el
  invariante de "a lo sumo un intento `pendiente` por orden".
- `receipt_file_url`, `amount_received`, `change_amount`, `rejection_reason` conservan su
  significado actual sin cambios; en un intento mixto, `receipt_file_url` es el comprobante de la
  porción por transferencia (`transfer_amount`), y `amount_received`/`change_amount` no se usan
  (el monto en efectivo del pago mixto es `cash_amount`, no `amount_received` — ese campo sigue
  siendo exclusivo del flujo 100% efectivo donde el cajero cuenta el dinero físico y calcula
  cambio; el pago mixto no calcula cambio, ver edge cases de `spec.md`).

### `PaymentMethodCatalog` (modificada — esquema `shared`, tabla `payment_method_catalog`, spec 032)

| Campo | Cambio |
|---|---|
| `type` | `CHECK` ampliado de `'cash'|'card'|'transfer'|'other'` a `'cash'|'card'|'transfer'|'other'|'mixed'` (migración de constraint, sin backfill de filas existentes). |

**Regla nueva (FR-004)**: el Super Admin puede crear una fila `type='mixed'` ("Pago mixto") en el
catálogo igual que cualquier otra — sin restricción a ese nivel. La restricción vive en la
activación por tenant (siguiente entidad).

### `PaymentMethod` (modificada — esquema `tenant`, tabla `payment_methods`, spec 032)

Sin columnas nuevas. Regla nueva de activación (FR-004, aplicada en el servicio que atiende la
activación de un método de catálogo para el tenant, spec 032):

```
Activar catalog_id cuyo catalog.type == 'mixed'
  SOLO SI el tenant ya tiene, entre sus PaymentMethod activos:
    - al menos uno con type == 'cash', Y
    - al menos uno con type == 'transfer'
  (si no, se rechaza la activación con el motivo correspondiente)
```

Esta regla no se evalúa de nuevo después de activado: si el tenant luego desactiva su único
efectivo o su única transferencia, "Pago mixto" sigue activo (fuera de alcance, edge case de
`spec.md`).

### `CustomerOrder` (sin columnas nuevas)

Expone el desglose de pago mixto a través de `current_payment_attempt` (propiedad ya existente,
`app/models/customer_order.py`) — no se duplica el desglose en la orden misma. La confirmación o
cancelación de la orden sigue usando `status` sin cambios (Principio VII — ninguna venta/factura
ya emitida se recalcula).

### `SessionParticipant` (sin columnas nuevas)

Sin cambio de esquema. Cambia el **contrato** de la operación de salida — ver "Transiciones" abajo
y research.md Decisión 7 (requiere entrada en `registro-de-anomalias.md` antes de implementar).

## Relaciones

```
tenant.order_payment_attempts (0..1 mixto) ──> tenant.payment_methods   [payment_method_id, = "Pago mixto"]
tenant.order_payment_attempts (0..1 mixto) ──> tenant.payment_methods   [transfer_method_id, = método real, ej. Nequi]
shared.payment_method_catalog [type='mixed'] ──< (0..N) tenant.payment_methods  [sin cambio de forma, spec 032]
```

Un intento mixto referencia **dos** `PaymentMethod` distintos del mismo tenant: el método "Pago
mixto" (identifica el intento como mixto a nivel de reporte/UI) y el método de transferencia real
elegido para el resto (de donde se leen los datos de cuenta/QR a mostrar).

## Transiciones de estado

### `OrderPaymentAttempt` — pago mixto (nuevo, superpuesto al ciclo ya existente)

```
[creado por submit_cart]
  status='pendiente', cash_confirmed_at=NULL
      │                                   │
      │ cajero: confirm-cash               │ cajero: approve (comprobante OK)
      ▼                                   ▼
cash_confirmed_at=<ahora>            status='confirmado'
      │                                   │
      └──────────────┬────────────────────┘
                      ▼ (cuando AMBAS ocurrieron, en cualquier orden)
      status='confirmado' AND cash_confirmed_at IS NOT NULL
                 → pago mixto completo → la orden puede avanzar a cocina
                   (gate extendido de _confirm_order_impl, research.md Decisión 4)

Camino de rechazo: cajero: reject (comprobante) → status='rechazado' → el comensal
debe volver a intentar según las reglas ya vigentes de spec 024/025 (sin cambios).
```

### `SessionParticipant` — "Salir" (`POST /cart/leave`)

```
[participante activo, sin pedido propio con pago pendiente]
        │ POST /cart/leave
        ▼
   sesión cerrada (200) — comportamiento sin cambios

[participante activo, CON al menos un pedido propio no cancelado
 cuyo pago no está completamente confirmado]
        │ POST /cart/leave
        ▼
   409 Conflict, sesión sigue activa (FR-009/FR-010) — comportamiento NUEVO,
   requiere decisión de negocio registrada antes de implementar
   (research.md Decisión 7, Principio II)
```

## Disponibilidad de "Pago mixto" para el comensal (vista derivada, no una tabla)

```
"Pago mixto" aparece en GET /cart/payment-methods del comensal SOLO SI:
  PaymentMethod.active = true AND PaymentMethod.is_complete = true
  AND catalog.type = 'mixed'
  (mismas reglas de disponibilidad ya vigentes para cualquier otro método, spec 032 — ninguna
  regla adicional: si el tenant lo desactivó o su fila quedó incompleta, no aparece, igual que
  cualquier otro método)
```

## Migraciones (resumen — DDL completo en `/speckit-tasks`)

1. `shared.payment_method_catalog`: alterar `CHECK` de `type` para incluir `'mixed'`.
2. `tenant.order_payment_attempts` (`@for_each_tenant_schema`): agregar `cash_amount`
   (`Numeric(12,2)`, NULL), `transfer_amount` (`Numeric(12,2)`, NULL), `transfer_method_id`
   (`UUID`, FK, NULL), `cash_confirmed_at` (`DateTime`, NULL). Sin backfill — todas `NULL` en
   filas existentes, que siguen siendo intentos no mixtos.
3. Sin migración de datos existentes en `tenant.payment_methods` ni `shared.payment_method_catalog`
   más allá del `CHECK` del punto 1 (ninguna fila existente usa `type='mixed'` todavía).
4. Rollback: `DROP COLUMN` de las cuatro columnas del punto 2 y revertir el `CHECK` del punto 1 —
   trivial, sin pérdida de información salvo la del propio pago mixto (Principio VIII).
