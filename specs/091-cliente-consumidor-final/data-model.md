# Data Model: Cliente "Consumidor final" por defecto en Mesa y Para llevar

**Sin cambios de esquema.** Ninguna tabla, columna, constraint ni índice se crea, modifica o
elimina; **no hay migración Alembic**. `CustomerOrder.customer_name` ya es `String(255) NULLABLE`
(`app/models/customer_order.py:50`) y así se queda — lo que cambia es **qué valor recibe** cuando
el cajero no escribe ninguno para un pedido de Mesa o Para llevar desde la Terminal, y quién lo
decide (validación de `orders/service.py::create_order` en vez de un rechazo).

## Campo afectado: `CustomerOrder.customer_name`

| Aspecto | Antes de esta spec (A-88, spec 087) | Después de esta spec (A-99) |
|---|---|---|
| `DINE_IN`/`TAKEAWAY`, canal `POS`, sin nombre | `422 "El nombre del cliente es obligatorio."` — no se crea el pedido | Se crea; `customer_name = "Consumidor final"` |
| `DINE_IN`/`TAKEAWAY`, canal `WHATSAPP`/`API`, sin nombre | `422` (igual) | **Sin cambio** — sigue `422` |
| `DINE_IN`, canal `QR_MENU` (vía `participant_id`) | Se completa desde `participant.display_label`/`display_name`, nunca vacío | **Sin cambio** |
| `DELIVERY`, cualquier canal, sin nombre (o sin dirección o sin valor) | `422 "Un pedido a domicilio requiere..."` | **Sin cambio** |
| Pedidos ya creados (cualquier fecha anterior al despliegue) | `customer_name` tal como se guardó (`null`, vacío o un texto) | **Sin cambio** — no hay paso de datos ni corrección retroactiva |

No hay una nueva entidad "valor por defecto": es una constante de texto (`"Consumidor final"`,
research.md D1/D7), no una fila de catálogo ni una configuración por tenant.

## Estado de interfaz (frontend): el campo "Cliente" de `ManualOrderPageComponent`

No es una entidad persistida, pero como esta spec depende de una regla de presentación con varios
estados posibles, se documenta aquí para que `tasks.md` tenga una única referencia de las
transiciones válidas (research.md D2/D3):

| Pestaña activa | Contenido del campo | Transición |
|---|---|---|
| Mesa / Para llevar | vacío o solo espacios | → se muestra `"Consumidor final"` |
| Mesa / Para llevar | `"Consumidor final"` (sin editar) | se mantiene |
| Mesa / Para llevar | un nombre propio | se mantiene, se conserva al cambiar de pestaña |
| Domicilio | exactamente `"Consumidor final"` (recortado) | → se vacía (vuelve al placeholder) |
| Domicilio | un nombre propio, o ya vacío | se mantiene |
| (cualquiera) | al abrir "Nueva orden" de cero | el campo se reinicia a vacío y luego sigue la fila que corresponda según la pestaña inicial (D3) |

Invariante: el campo nunca muestra `"Consumidor final"` en la pestaña Domicilio como contenido
real (solo su placeholder original, sin cambios). Esto es lo que impide que ese texto llegue por
accidente como nombre de una entrega.
