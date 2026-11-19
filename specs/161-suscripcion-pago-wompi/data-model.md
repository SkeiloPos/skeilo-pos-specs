# Data Model: Autogestión de suscripciones y pago de la membresía por link de pago (Wompi)

**Spec**: [spec.md](./spec.md) | **Research**: [research.md](./research.md) | **Fecha**: 2026-11-17

Principio VIII: este documento fija entidades y campos nuevos, valores por defecto, compatibilidad con datos existentes, estrategia de migración y de reversión. Los cambios son **solo aditivos**: una tabla nueva y una columna nullable nueva. No se modifica ni reinterpreta ningún dato existente (salvo el procedimiento de una sola vez de la sección 5, que es un cambio de datos aparte y explícito).

## 1. Resumen de cambios

| Objeto | Esquema | Cambio |
|---|---|---|
| `subscription_payments` | `shared` | **Tabla nueva** |
| `notification_events.audience_role` | `tenant` (cada esquema de tenant y `tenant_default`) | **Columna nueva**, `NULL` |
| `ux__notification_events__subscription_once` | `tenant` | **Índice único parcial nuevo** |
| `tenants.plan_vence_en` | `shared` | Sin cambio de esquema. Sí lo cambia, una sola vez, el script de la sección 5. |
| `tenants`, `plans`, `users`, facturas | — | Sin cambios |

## 2. Entidad nueva: `shared.subscription_payments` (Pago de suscripción)

Un registro por intento de cobro de una mensualidad. Es del esquema `shared` porque el webhook de Wompi llega sin tenant y debe poder localizar el pago por su referencia.

| Columna | Tipo | Nulo | Por defecto | Notas |
|---|---|---|---|---|
| `id` | `UUID` | No | `uuid4` | PK (`UUIDPrimaryKeyMixin`) |
| `tenant_id` | `Integer` | No | — | FK → `shared.tenants.id`. Nunca llega como parámetro del cliente. |
| `plan_id` | `UUID` | No | — | FK → `shared.plans.id`. El plan vigente al pedir el link. |
| `ciclo_facturacion` | `String(10)` | No | `'mensual'` | Siempre `mensual` en esta spec. |
| `amount` | `Numeric(12,2)` | No | — | Copia de `plan.precio_mensual` en el momento del link (COP). Inmutable después. |
| `status` | `String(20)` | No | `'pending'` | Ver CHECK y transiciones abajo. |
| `gateway` | `String(20)` | No | `'wompi'` | Deja la puerta abierta a otra pasarela. |
| `gateway_reference` | `String(64)` | No | — | `SKP-<uuid hex>`. **Única.** |
| `gateway_transaction_id` | `String(64)` | Sí | `NULL` | Id de la transacción en Wompi; se llena con el evento. |
| `payment_link_url` | `String(2048)` | No | — | URL del Web Checkout ya firmada. |
| `payment_link_expires_at` | `DateTime` | No | — | UTC naive. `creación + 24 h`. |
| `requested_by_user_id` | `UUID` | Sí | — | FK → `shared.users.id`, `ON DELETE SET NULL` (spec 159 permite borrar usuarios; el pago debe sobrevivir). |
| `period_start` | `DateTime` | Sí | `NULL` | Se llena **al aprobar**. |
| `period_end` | `DateTime` | Sí | `NULL` | Se llena **al aprobar**. |
| `paid_at` | `DateTime` | Sí | `NULL` | Instante de procesar la aprobación. |
| `created_at` | `DateTime` | No | `now()` | `TimestampMixin` |
| `updated_at` | `DateTime` | Sí | `onupdate now()` | `TimestampMixin` |

Todas las fechas son UTC naive, como el resto del esquema compartido (`utc_now_naive`).

**Restricciones e índices** (nombres según la `convention` del proyecto):

| Nombre | Definición |
|---|---|
| `pk__subscription_payments` | PK sobre `id` |
| `uq__subscription_payments__gateway_reference` | `UNIQUE (gateway_reference)` |
| `ck__subscription_payments__status` | `CHECK (status IN ('pending','approved','rejected','expired','voided'))` |
| `ck__subscription_payments__amount_positive` | `CHECK (amount > 0)` |
| `ix__subscription_payments__tenant_id__created_at` | `(tenant_id, created_at)` — alimenta el historial paginado (`ORDER BY created_at DESC` recorre el B-tree al revés) |
| `ux__subscription_payments__tenant_id__pending` | `UNIQUE (tenant_id) WHERE status = 'pending'` — a lo sumo un pago pendiente por tenant (FR-016) |
| `ux__subscription_payments__gateway_transaction_id` | `UNIQUE (gateway_transaction_id) WHERE gateway_transaction_id IS NOT NULL` — una transacción de Wompi no aplica a dos pagos |

Los dos índices parciales se declaran con `postgresql_where` y `sqlite_where`, para que las suites de SQLite los apliquen igual.

### 2.1 Estados y transiciones

| Estado | Significado | Terminal |
|---|---|---|
| `pending` | Link emitido, sin resultado todavía | No |
| `approved` | Wompi aprobó; las fechas del tenant ya se aplicaron | Casi (solo puede pasar a `voided`) |
| `rejected` | Wompi respondió `DECLINED` o `ERROR` | No (un reintento aprobado lo promueve) |
| `expired` | Pasaron las 24 h sin resultado | No (una aprobación tardía lo promueve) |
| `voided` | Anulación posterior a una aprobación | Sí |

| Desde → Hacia | Disparador | Efecto sobre el tenant |
|---|---|---|
| `pending → approved` | Evento `APPROVED` válido | Recalcula fechas (sección 2.2) |
| `expired → approved` | `APPROVED` tardío | Igual, el dinero ya entró |
| `rejected → approved` | `APPROVED` de un reintento | Igual |
| `pending → rejected` | `DECLINED` o `ERROR` | Ninguno |
| `pending → expired` | `payment_link_expires_at` vencido (job o nueva solicitud) | Ninguno |
| `approved → voided` | `VOIDED` | **Ninguno** (no revierte fechas; lo resuelve soporte) |
| `approved → *` (otro) | Cualquier evento distinto de `VOIDED` | Se ignora |

Cualquier transición no listada se ignora y deja constancia en el registro; un estado `approved` jamás retrocede a `rejected` ni a `expired`.

### 2.2 Reglas de validación y de cálculo

- `amount` se copia de `plan.precio_mensual` y debe ser `> 0`; si el plan no tiene precio mensual no se crea el pago (FR-013).
- `amount_in_cents = int(amount * 100)`, con `Decimal`.
- `gateway_reference = "SKP-" + id.hex`, calculada a partir del `id` antes del `INSERT`.
- Al aprobar (dentro de la transacción del webhook, con `now = utc_now_naive()`):
  - Si `tenant.ciclo_facturacion != 'mensual'` o `tenant.plan_vence_en IS NULL` → `status = approved`, `paid_at = now`; `period_start`, `period_end` y las fechas del tenant **no** cambian.
  - Si el estado del tenant es `bloqueada` → `period_start = now`, `period_end = calculate_plan_vencimiento(now, 'mensual')`.
  - En otro caso → `period_start = tenant.plan_vence_en`, `period_end = calculate_plan_vencimiento(period_start, 'mensual')`.
  - Cuando hay período, el tenant queda con `plan_iniciado_en = period_start` y `plan_vence_en = period_end`.

### 2.3 Relaciones

```
shared.tenants 1 ───< N shared.subscription_payments >─── 1 shared.plans
                                    │
                                    └── N : 0..1 shared.users   (requested_by_user_id, SET NULL)
```

No hay relación con `invoices` ni con ninguna tabla del esquema `tenant`: un pago de suscripción no es una factura de venta (FR-040, Principio VII).

## 3. Cambio en `tenant.notification_events` (Audiencia de la notificación)

| Columna | Tipo | Nulo | Por defecto | Notas |
|---|---|---|---|---|
| `audience_role` | `String(20)` | Sí | `NULL` | Nombre de rol destinatario (`ADMIN`). `NULL` = todo el personal. |

- **Compatibilidad**: toda fila existente queda con `NULL`, que significa "todo el personal": ningún evento actual cambia de comportamiento y no hace falta backfill.
- **Índice único parcial** `ux__notification_events__subscription_once`: `UNIQUE (event_type, related_entity_id) WHERE event_type LIKE 'subscription.%'`. Garantiza un aviso por tipo y ciclo.
- **Tipos de evento nuevos** (valores de `event_type`, que ya es un `String(50)` libre): `subscription.expiring`, `subscription.grace_started`, `subscription.blocked`. `related_entity_type = 'subscription'`; `related_entity_id = uuid5(ns, "<event_type>|<plan_vence_en ISO>")`.
- **`payload`** (JSONB, ya existente): `{"plan_vence_en": <ISO>, "fecha_limite_pago": <ISO>, "dias_restantes": <int>}`.
- **Un rol por evento** basta hoy; si en el futuro hiciera falta más de un rol, la columna se reemplaza por una lista sin tocar a los consumidores, que solo la comparan.

## 4. Entidad derivada (no se almacena): Estado de suscripción

| Campo | Tipo | Regla |
|---|---|---|
| `subscription_state` | `activa \| por_vencer \| en_gracia \| bloqueada` | Tabla de `research.md` Decisión 4 |
| `dias_restantes` | `int \| null` | `ceil((objetivo − now)/1 día)`; `0` si bloqueada; `null` sin vencimiento |
| `fecha_limite_pago` | `datetime \| null` | `plan_vence_en + 120 h`; `null` sin vencimiento |
| `vencido` (ya existente) | `bool` | `subscription_state == 'bloqueada'` |

Entradas: `tenants.plan_vence_en` y `now` (UTC). Sin vencimiento (`NULL`) siempre es `activa`.

## 5. Procedimiento de datos de una sola vez (D8)

Separado del DDL (Principio VI). `app/scripts/grant_subscription_grace.py`:

| Aspecto | Detalle |
|---|---|
| Entrada | `--cutoff <ISO-UTC>` (obligatorio), `--apply` (sin él, solo informa) |
| Efecto | `UPDATE shared.tenants SET plan_vence_en = :cutoff WHERE plan_vence_en IS NOT NULL AND plan_vence_en < :cutoff` |
| No toca | `plan_iniciado_en`, `ciclo_facturacion`, `plan_id`, tenants vigentes o sin vencimiento |
| Idempotencia | Repetir con el mismo `cutoff` no encuentra filas (`plan_vence_en` ya es `= cutoff`) |
| Rastro | Imprime y registra por tenant: id, nombre, valor anterior, valor nuevo |
| Reversión | Con el rastro, se restaura cada `plan_vence_en` anterior a mano; no hay otro dato derivado |

Efecto de negocio: el tenant vencido queda "en gracia" con 120 h por delante, y su próxima mensualidad se calcula desde `cutoff` (RN-7). Se pierde el valor histórico del vencimiento anterior (conservado solo en el rastro), decisión justificada en `research.md` Decisión 13.

## 6. Estrategia de migración y reversión (Principio VIII)

**Dos revisiones de Alembic** (solo DDL, una clase de cambio cada una), encadenadas tras la última migración de la spec 162: `8d09a031cba3 → … → b1c9f4e7a3d2 → e0230fd88635` (tabla `shared.subscription_payments`) `→ a65d3ff9da49` (`audience_role` y su índice en cada esquema de tenant). Ver `research.md` Decisión 14 para el procedimiento tras el pull y los dos archivos locales sin versionar.

`upgrade`:
1. `shared.subscription_payments` con sus restricciones e índices (`create_table`, esquema `shared`; omitir si ya existe).
2. Con `@for_each_tenant_schema` (`tenant_default` + cada esquema de tenant): `ALTER TABLE <schema>.notification_events ADD COLUMN IF NOT EXISTS audience_role VARCHAR(20)` y `CREATE UNIQUE INDEX IF NOT EXISTS ux__notification_events__subscription_once …`.

`downgrade` (orden inverso, con guardas):
1. Por esquema de tenant: borrar las filas con `audience_role` (los avisos de suscripción, transitorios y regenerables), quitar el índice y quitar la columna. Se borran **dentro del propio `downgrade`** para que, al desaparecer la columna, esos avisos del ADMIN no pasen a verse para todo el personal.
2. Eliminar `shared.subscription_payments`.

| Riesgo | Mitigación |
|---|---|
| Pérdida de datos al revertir | Solo se pierden los pagos de suscripción y los avisos con audiencia creados desde el despliegue; ningún dato previo se toca. |
| Tabla nueva ya poblada al revertir | Exportar `subscription_payments` antes del `downgrade` (sentencia en `quickstart.md`). |
| Notificaciones de suscripción ya emitidas al revertir | Tras quitar la columna, esas filas pasarían a verse para todo el personal; antes de revertir se borran las filas con `event_type LIKE 'subscription.%'`. |
| Bases nuevas | `initialize_database()` crea las tablas compartidas desde los modelos y estampa el head; un tenant nuevo hereda `audience_role` de los modelos, sin pasos extra. |
| Doble cabeza | Verificar `alembic heads` y `alembic current` antes y después. |

## 7. Compatibilidad con datos y funciones existentes

- **Facturas**: sin cambios (FR-040, Principio VII).
- **Notificaciones existentes** (`order.created`, `payment.completed`): `audience_role = NULL`, mismo canal `staff` de siempre.
- **Super Admin**: la asignación manual de plan y ciclo (`PATCH /super-admin/tenants/{id}/plan`) sigue reiniciando fechas como hoy; no consulta `subscription_payments`.
- **`GET /plan`**: campos nuevos aditivos; `vencido` cambia de significado solo en el tramo de gracia (`research.md` Decisión 6).
- **Respuestas de error**: se agrega el 403 `subscription_blocked` para todo tenant bloqueado; hoy solo bloqueaban unas pocas rutas con un 403 sin `code`.
