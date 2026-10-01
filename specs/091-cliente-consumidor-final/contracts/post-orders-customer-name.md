# Contrato: `POST /orders` — `customer_name` por defecto en Mesa y Para llevar (canal POS)

Cubre FR-006, FR-007 (US1 escenario 4). Enmienda puntual al contrato de A-88 (spec 087) sobre el
mismo endpoint — no se tocan `OrderCreate` ni ningún otro campo del body.

## Regla (reemplaza la validación de A-88 solo para este caso)

En `POST /orders`, si `order_type` es `DINE_IN` o `TAKEAWAY`:

| `channel` | `customer_name` recibido | Resultado |
|---|---|---|
| `POS` | vacío, ausente o solo espacios | **201** — se crea el pedido con `customer_name = "Consumidor final"` (antes: `422`) |
| `POS` | un texto no vacío (recortado) | **201** — se guarda tal cual, sin cambios |
| `WHATSAPP` / `API` | vacío, ausente o solo espacios | **422** `"El nombre del cliente es obligatorio."` — **sin cambios** (A-88 sigue vigente para estos canales) |
| `QR_MENU` (con `participant_id`) | cualquiera | **sin cambios** — se completa desde `participant.display_label`/`display_name` antes de esta regla; nunca llega vacío |

`DELIVERY` **no cambia** en ningún canal: sigue exigiendo `customer_name`, `delivery_address` y
`delivery_fee` (spec 056, FR-007), validado antes de llegar a esta regla.

## Ejemplos

**Antes** (A-88, hoy en `develop`):
```
POST /orders
{ "channel": "POS", "order_type": "DINE_IN", "dining_table_id": "...", "items": [...] }
→ 422 { "detail": "El nombre del cliente es obligatorio." }
```

**Después de esta spec**:
```
POST /orders
{ "channel": "POS", "order_type": "DINE_IN", "dining_table_id": "...", "items": [...] }
→ 201 { ..., "customer_name": "Consumidor final", ... }
```

**Sin cambios** (otro canal):
```
POST /orders
{ "channel": "WHATSAPP", "order_type": "TAKEAWAY", "items": [...] }
→ 422 { "detail": "El nombre del cliente es obligatorio." }
```

**Sin cambios** (nombre explícito en cualquier canal):
```
POST /orders
{ "channel": "POS", "order_type": "TAKEAWAY", "customer_name": "María Pérez", "items": [...] }
→ 201 { ..., "customer_name": "María Pérez", ... }
```

## Errores (sin cambios respecto a A-88)

| Código | Caso |
|---|---|
| 422 | `DINE_IN`/`TAKEAWAY` sin nombre fuera del canal `POS`; `DELIVERY` sin nombre/dirección/valor; cualquier otro `422` ya existente del endpoint. |
| 400 | Combinación canal × tipo de orden inválida (sin cambios, research.md hechos verificados). |

## Compatibilidad

- No es un cambio de contrato incompatible para ningún consumidor que ya mande `customer_name`
  (sigue aceptándose igual). Es incompatible únicamente para un consumidor que **dependía** de
  recibir `422` ante un `DINE_IN`/`TAKEAWAY` sin nombre **desde el canal `POS`** — comportamiento
  que esta spec cambia a propósito (A-99).
- `OrderCreate`/`OrderResponse` (`orders/schemas.py`) no cambian de forma: `customer_name` sigue
  `str | None`.
