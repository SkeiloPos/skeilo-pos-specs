# Contrato: `GET /orders` (extendido)

**Spec**: [../spec.md](../spec.md) · **Data model**: [../data-model.md](../data-model.md)

Extiende el endpoint ya existente y en producción `GET /api/v1/orders`. **No es un endpoint nuevo**: todos los parámetros añadidos son opcionales y retrocompatibles — cualquier cliente que no los envíe (Terminal de Mesas, Dashboard, etc.) sigue recibiendo exactamente la misma respuesta que hoy.

## Request

```
GET /api/v1/orders
```

| Parámetro | Tipo | Requerido | Descripción |
|---|---|---|---|
| `status` | `recibida\|abierta\|bloqueada\|pagada\|cancelada` | No | *(ya existente)* Filtra por estado de la orden. |
| `order_type` | `DINE_IN\|TAKEAWAY\|DELIVERY` | No | *(ya existente)* Filtra por tipo de atención. |
| `active_sessions_only` | boolean | No | *(ya existente, sin cambios)* |
| `page` | integer ≥ 1 | No | *(ya existente)* |
| `size` | integer, 1–100 | No | *(ya existente)* |
| `date_from` | date (`YYYY-MM-DD`) | No | **Nuevo.** Filtra `created_at >= date_from` (inclusive, hora local del tenant al inicio del día). |
| `date_to` | date (`YYYY-MM-DD`) | No | **Nuevo.** Filtra `created_at <= date_to` (inclusive, hora local del tenant al final del día). |
| `q` | string | No | **Nuevo.** Coincidencia parcial, insensible a mayúsculas, contra `customer_name` **o** la representación en texto de `id`. Cadena vacía o solo espacios ⇒ se ignora (equivale a no enviarlo). |

Todos los parámetros se combinan con AND entre sí.

## Response

Sin cambios de forma: `200 OK` con `Page[OrderResponse]`, igual que hoy:

```jsonc
{
  "items": [ /* OrderResponse[], mismos campos que hoy */ ],
  "total": 0,
  "page": 1,
  "size": 20,
  "pages": 0
}
```

## Casos de error

Sin cambios respecto al endpoint actual. `date_from`/`date_to` con formato inválido ⇒ `422 Unprocessable Entity` (validación estándar de FastAPI/Pydantic para el tipo `date`), igual que ya ocurre hoy con `page`/`size` fuera de rango.

## Ejemplos

Buscar "Deimer" en las órdenes de hoy, solo en mesa, página 1 de 8:

```
GET /api/v1/orders?order_type=DINE_IN&date_from=2026-10-15&date_to=2026-10-15&q=Deimer&page=1&size=8
```

Ver todas las órdenes canceladas del mes (sin búsqueda):

```
GET /api/v1/orders?status=cancelada&date_from=2026-10-01&date_to=2026-10-31&page=1&size=20
```

Llamador existente que no conoce los parámetros nuevos (comportamiento sin cambios):

```
GET /api/v1/orders?page=1&size=20
```
