# Contrato: Permisos de backend para el rol Cajero (`CASHIER`) sobre el catálogo

**Spec**: [../spec.md](../spec.md) | **Research**: [../research.md](../research.md) (D1, D2, D3, D8)

Este documento es la lista autoritativa de qué cambia (y qué no) en los permisos del
backend. Es un contrato **por diferencia**, igual que el de la spec 075: todo lo que no
aparece como "cambia" sigue exactamente igual que hoy para los tres roles existentes
(`ADMIN`, `CASHIER`, `MESERO`).

## Qué gana el Cajero

| Método | Ruta | Antes | Después |
|---|---|---|---|
| GET | `/products` | Ya permitido (`get_current_user`, sin filtro de rol) | Sin cambio — el Cajero ya podía listar productos por API; lo nuevo es que el frontend ahora le muestra esta pantalla (ver `frontend-route-access.md`) |
| GET | `/products/{id}` | Ya permitido | Sin cambio de permiso; **cambia la forma de la respuesta** para todos los roles (ver `products-api.md`) |
| **PATCH** | **`/products/{id}/availability`** (nuevo endpoint) | No existe | **Permitido** para `ADMIN` y `CASHIER` (`require_tenant_admin_or_cashier`, nueva dependencia) |

## Qué NO gana el Cajero (se mantiene bloqueado, FR-024)

| Método | Ruta | Dependencia | Cambia? |
|---|---|---|---|
| POST | `/products` | `require_tenant_admin` | No — sigue exclusivo de Admin |
| PATCH / PUT | `/products/{id}` (edición completa) | `require_tenant_admin` | No — sigue exclusivo de Admin. El Cajero solo gana el endpoint angosto de arriba, nunca este |
| DELETE | `/products/{id}` | `require_tenant_admin` | No — sigue exclusivo de Admin |
| Todo endpoint de `categories`, `presentations`, `promotions` | — | `require_tenant_admin` (o equivalente) | No — fuera del alcance de esta spec por completo |

## Qué pierde el Cajero (restricción nueva, FR-025 / escenario 12)

| Método | Ruta | Antes | Después |
|---|---|---|---|
| GET | `/variants/{variant_id}/recipe` | Cualquier usuario autenticado (`get_current_user`) | **Bloqueado para `CASHIER`** (403) — Admin conserva acceso sin cambios |

## Qué se mantiene sin cambios, explícitamente (para evitar una regresión)

| Método | Ruta | Por qué se deja igual |
|---|---|---|
| GET | `/variants/{variant_id}/option-groups` | El Cajero ya lo usa hoy, vía la Terminal de mesas, para ofrecer opciones/adicionales al armar un pedido manual (research.md D8). Bloquearlo rompería una funcionalidad ya protegida por el Principio II. La spec no pide ocultar "grupos de opciones", solo "costos, recetas ni datos de inventario". |
| Todas las rutas de `orders`/`table_sessions`/`cart` que el Cajero ya usa hoy | — | Sin cambio de permiso — solo ganan una validación de negocio nueva (ver `menu-and-orders.md`), no un cambio de quién puede llamarlas. |
| El rol `MESERO` | — | Sin cambio — su default-deny (`_MESERO_ALLOWED_ROUTES`) no se toca; `MESERO` sigue sin acceso a `/products*` ni a `/variants/*` por no estar en esa lista. |

## Aislamiento por tenant (FR-026 / escenario 16)

Sin cambios de código: todo endpoint de `products`/`variants`/`menu`/`cart`/`orders` ya
resuelve el tenant por `get_tenant`/`get_db` (schema-per-tenant) y toda consulta ya está
acotada a ese schema — un id de otro tenant simplemente no existe en el schema resuelto,
por lo que ya produce 404 hoy. Este contrato lo deja constancia, no introduce ningún
mecanismo nuevo.
