# Data Model: Pago antes de cocina para pedidos de mesa (QR) con módulo de cocina activo

**Feature**: 153-cobro-previo-cocina-qr | **Fecha**: 2026-11-05

Este ajuste **no introduce entidades, campos ni migraciones nuevas**. Reutiliza por
completo el modelo de datos ya existente de `orders` (specs 146-151) y el flag de módulo de
plan "cocina" (spec 149). Lo que cambia es **cuándo** cada campo existente transiciona de
valor, no su forma.

## Entidades reutilizadas

### Order (pedido)

Campos relevantes para este ajuste (ya existentes, sin cambios de esquema):

| Campo | Tipo | Rol en este ajuste |
|---|---|---|
| `payment_status` | enum (`PENDING`/`PAID`/…) | Condición que habilita el envío a cocina (`FR-001`, `FR-002`). Pasa a `PAID` mediante `_charge_session`/`pay_order`, sin cambios en su mecanismo de transición. |
| `kitchen_status` | enum nullable (`NULL`/`SIN_PREPARAR`/`EN_PROGRESO`/`LISTO`) | Hoy solo se fija manualmente vía `send_to_kitchen`. Este ajuste hace que, para pedidos de mesa con el módulo de Cocina activo, la transición `NULL → SIN_PREPARAR` ocurra automáticamente al completarse el pago, en vez de requerir una acción manual separada. |
| `dining_table_id` | FK nullable | Discrimina qué pedidos están en alcance (solo pedidos de mesa, `FR-009`); los pedidos de mostrador/domicilio (`dining_table_id IS NULL`) no se tocan. |
| `status` | enum (`pendiente`/`entregada`/`cancelada`/…) | Pasa a `entregada` mediante `deliver_order`; este ajuste añade una precondición a esa transición (ver guard de `deliver_order` abajo) pero no cambia los valores posibles del campo. |
| `sent_to_kitchen_at` | timestamp nullable | Se sigue fijando como hoy, dentro de `send_to_kitchen`, solo que ahora ese fijado puede ocurrir como efecto del cobro en vez de solo por acción manual. |

### Estado de cocina del tenant (módulo de plan)

Sin cambios. Se sigue consultando con el mismo mecanismo que ya usan el tablero de Cocina
(spec 149) y las reglas de entrega existentes (`has_module_access`/`cocinaAccess`). Este
ajuste no introduce un flag nuevo: reutiliza exactamente el mismo que spec 151 ya usa para
`canDeliverOrder`.

### OrderPaymentAttempt (cuenta dividida)

Sin cambios de esquema. Se usa únicamente para **leer** si todos los pedidos de una sesión
de mesa ya alcanzaron `payment_status=='PAID'` antes de disparar el envío a cocina de cada
uno (ver `research.md`, punto 4). No se añade ningún campo de "porcentaje pagado"; el
chequeo por pedido individual (`PAID` o no) ya es suficiente.

## Transiciones de estado afectadas

### Antes de este ajuste (pedido de mesa por QR, módulo de Cocina activo)

```text
[creado, pendiente, no pagado]
        │ (cajero intenta cobrar)
        ▼
[ensureReadyToCharge detecta ítems "pendiente" de entrega]
        │ (confirma "Entregar y cobrar")
        ▼
[deliver_order sin guard]  +  [cobro]
        │
        ▼
[status=entregada, payment_status=PAID, kitchen_status=NULL]  ← nunca llega a cocina
```

### Después de este ajuste, módulo de Cocina activo (FR-001 a FR-005)

```text
[creado, pendiente, no pagado, kitchen_status=NULL]
        │ (cajero cobra — única acción, sin diálogo de entrega)
        ▼
[payment_status=PAID]
        │ (si 100% de la sesión/cuenta dividida ya está pagado)
        ▼
[kitchen_status=SIN_PREPARAR, sent_to_kitchen_at=now]   ← visible en tablero de Cocina
        │ (personal de cocina avanza el tablero)
        ▼
[kitchen_status=EN_PROGRESO] → [kitchen_status=LISTO]
        │ (solo ahora se habilita "Entregar", en frontend y backend)
        ▼
[status=entregada]
```

### Después de este ajuste, módulo de Cocina inactivo (FR-006, sin cambios)

```text
[creado, pendiente, no pagado]
        │ (cajero cobra de inmediato, sin esperar nada)
        ▼
[payment_status=PAID]  — kitchen_status no aplica (módulo inactivo)
        │ (independiente del cobro, cuando cada ítem se marca entregado)
        ▼
[status=entregada]
```

## Validaciones nuevas (sin cambio de esquema)

- **`_charge_session`/`_assert_closable`**: deja de exigir que todos los ítems estén
  entregados antes de cobrar una mesa **cuando el tenant tiene el módulo de Cocina
  activo**. Cuando el módulo está inactivo, la validación actual se mantiene intacta
  (FR-006).
- **`deliver_order`**: añade la precondición `kitchen_status=='LISTO'` cuando el tenant
  tiene el módulo de Cocina activo y el pedido tiene `dining_table_id` (FR-004). Sin el
  módulo activo, no se añade ninguna precondición nueva.
- **Envío automático a cocina**: nueva invocación de la lógica de `send_to_kitchen` desde
  el flujo de cobro de sesión, condicionada a `payment_status=='PAID'` del pedido y módulo
  de Cocina activo del tenant (FR-001, FR-002). No es un campo nuevo, es una nueva llamada
  a una transición de estado ya existente.
