# Fase 1 — Data Model: Instrucciones de Pago del Menú QR por Modalidad del Plan

Ver decisiones técnicas en [research.md](./research.md), en particular la Decisión 2 (forma de
la columna), la Decisión 3 (por qué no se expone en `GET /plan`) y la Decisión 4 (cómo llega al
comensal sin pasar por un endpoint consultable por el tenant).

## Entidades

### `Plan` (modificada — esquema `shared`, tabla `plans`, ya existente desde spec 033)

Gana una característica nueva, de forma distinta a los `*_access` booleanos existentes
(`inventario_access`/`promociones_access`/`cocina_access`, spec 033/141/149): no es un *gate*
de módulo, es una selección excluyente de dos valores con nombre propio.

| Campo | Tipo | Notas |
|---|---|---|
| **`modalidad_pago_qr`** | `String(30)`, `NOT NULL`, `CheckConstraint IN ('PAY_AFTER_RECEIVING', 'PAY_BEFORE_RECEIVING')`, default `'PAY_AFTER_RECEIVING'`, `server_default='PAY_AFTER_RECEIVING'` | Nueva. Determina la instrucción de pago que ve el comensal en el menú QR tras enviar su orden (FR-001/FR-006/FR-007/FR-008). `PAY_AFTER_RECEIVING` = comportamiento actual del sistema (FR-002, Assumptions). No existe un tercer valor "no configurado": todo plan, nuevo o existente, siempre tiene exactamente uno de los dos (FR-002). |

**Reglas**:
- Editar `modalidad_pago_qr` de un plan aplica de inmediato a todos los tenants con ese
  `plan_id`, en la próxima orden que envíen desde el menú QR (FR-003/FR-014) — no hay caché,
  se calcula en cada `POST /cart/submit`/`GET /cart/orders` (research.md Decisión 4).
- No editable ni consultable desde ningún rol de administración del tenant (FR-004) — ver
  research.md Decisión 3: por eso esta columna **no** aparece en `ModuleAccess`/
  `PlanSummaryResponse` (`app/api/v1/plan/schemas.py`), a diferencia de
  `inventario_access`/`promociones_access`/`cocina_access`, que sí viajan en `GET /plan`.
- Solo editable desde los endpoints de Super Admin ya existentes
  (`app/api/v1/super_admin/plans_router.py`), igual que el resto de características de `Plan`.
- No hay borrado de la columna salvo una migración de reversión explícita.

### `OrderResponse` (modificada — schema de API, `app/api/v1/orders/schemas.py`, sin tabla propia)

Campo nuevo, **computado** (no una columna de `CustomerOrder`), poblado únicamente por los
endpoints del comensal anónimo en `app/api/v1/cart/router.py` (research.md Decisión 4):

| Campo | Tipo | Notas |
|---|---|---|
| **`qr_payment_instruction_mode`** | `Literal["PAY_AFTER_RECEIVING", "PAY_BEFORE_RECEIVING"] \| None`, default `None` | Nuevo. Reflejo, al momento de la respuesta, de `Plan.modalidad_pago_qr` del plan vigente del tenant propietario de la orden (FR-005). Asignado como atributo transitorio sobre el objeto ORM antes de serializar — mismo patrón que `paid`/`pending_balance` (`orders/router.py:73-77`, spec 029/123). Queda en `None` en toda respuesta de `OrderResponse` que no pase por `cart/router.py` (POS, caja, cocina, terminal de mesas — FR-013), porque ningún otro router lo asigna. |

**Reglas**:
- Nunca se persiste: no es una columna de `CustomerOrder`; cada lectura lo recalcula desde el
  plan vigente (FR-014 — un cambio de plan surte efecto en la próxima lectura, nunca de forma
  retroactiva sobre un valor ya grabado, porque no hay valor grabado).
- Calculado por `get_qr_payment_instruction_mode(db, tenant) -> str`
  (`app/api/v1/plan/service.py`, función nueva), usando únicamente `tenant.plan_id` del tenant
  propietario de la sesión del comensal (`ctx.tenant`), nunca el de otro tenant (FR-005).

## Catálogo cerrado de dos valores (sin tabla propia)

`modalidad_pago_qr` y `qr_payment_instruction_mode` comparten el mismo catálogo cerrado,
constante en ambos lados (backend `CheckConstraint`/`Literal`, frontend `type` TypeScript):

```
"PAY_AFTER_RECEIVING"   # el comensal recibe su pedido y luego paga (default, comportamiento actual)
"PAY_BEFORE_RECEIVING"  # el comensal debe acercarse a caja a pagar antes de recibir su pedido
```

No hay una tabla de catálogo nueva (a diferencia de `PaymentMethodCatalog`): son solo dos
valores fijos, definidos por este spec, sin necesidad de administración dinámica.

## Relaciones

Sin cambios de relación — `modalidad_pago_qr` es una columna más de `shared.plans`, misma
relación 1-a-N con `shared.tenants` ya descrita en data-model.md de spec 033.
`qr_payment_instruction_mode` no es una relación: es un valor computado sobre `OrderResponse` a
partir de esa misma relación `Tenant.plan_id → Plan`.

## Transiciones de estado

### Asignación/edición de la modalidad en un plan

```
Super Admin crea/edita un Plan
        │
        ▼
  envía modalidad_pago_qr = PAY_AFTER_RECEIVING | PAY_BEFORE_RECEIVING
  (u lo omite al crear → PAY_AFTER_RECEIVING, FR-002)
        │
        ▼
  Plan.modalidad_pago_qr persistido
        │
        ▼
  Próxima orden que un comensal de un tenant con ese plan envíe o consulte
  desde el menú QR (POST /cart/submit, GET /cart/orders) refleja la
  modalidad nueva en OrderResponse.qr_payment_instruction_mode
        │
        ▼
  confirmation-step.component.ts elige el texto exacto según
  (qr_payment_instruction_mode, forma de current_payment_attempt)
```

### Combinación modalidad + método de pago → mensaje exacto (FR-007/FR-008)

| `modalidad_pago_qr` | Método de pago | Mensaje |
|---|---|---|
| PAY_AFTER_RECEIVING | Efectivo (`is_cash`) | "Te llevaremos tu pedido a la mesa. Paga al recibirlo." |
| PAY_AFTER_RECEIVING | Transferencia/Nequi | "Muestra el comprobante de tu banco al cajero cuando recibas tu pedido." |
| PAY_AFTER_RECEIVING | Mixto (`cash_amount` y `transfer_amount` presentes) | "Al recibir tu pedido, muestra el comprobante de la transferencia al cajero. El efectivo lo pagas al recibirlo." |
| PAY_BEFORE_RECEIVING | Efectivo | "Dirígete a la caja para realizar el pago. ¡Llevaremos tu pedido hasta tu mesa!" |
| PAY_BEFORE_RECEIVING | Transferencia/Nequi | "Acércate a la caja y muestra el comprobante de tu transferencia para validar el pago. ¡Llevaremos tu pedido hasta tu mesa!" |
| PAY_BEFORE_RECEIVING | Mixto | "Acércate a la caja, presenta el comprobante de tu transferencia por Nequi y realiza el pago restante en efectivo. ¡Llevaremos tu pedido hasta tu mesa!" |

Un método de pago fuera de este catálogo (efectivo/transferencia/mixto) no dispara ninguna
instrucción (FR-009, Edge Cases) — `qrPaymentInstructionMessage` devuelve `null` y el template
no renderiza el bloque de instrucción en ese caso, igual que hoy no lo hace para un método sin
`current_payment_attempt`.

## Migración de datos

Una sola migración Alembic, encadenada sobre el head actual (`019b97e8a107`):
`op.add_column` + `op.create_check_constraint` (research.md Decisión 7). Sin backfill: el
`server_default='PAY_AFTER_RECEIVING'` resuelve el valor de todo plan ya existente,
reproduciendo exactamente el comportamiento actual (Assumptions del spec, research.md Decisión
8 — no requiere entrada en `registro-de-anomalias.md`). `downgrade()`: `drop_constraint` (con
el nombre completo `ck_plans_modalidad_pago_qr`, memory del proyecto sobre este gotcha) antes de
`drop_column`.
