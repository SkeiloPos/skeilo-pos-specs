# Contrato — Reagrupación, etiquetas e iconografía del sidebar de tenant

**Spec**: [../spec.md](../spec.md) (FR-001 a FR-003) | **Research**:
[../research.md](../research.md) R2, R9

Este contrato fija, ítem por ítem, lo que `app-tenant-sidebar` debe pintar. Es la verificación
concreta de FR-002/FR-003: cualquier implementación que produzca exactamente esta tabla cumple
esos dos requisitos; cualquier desviación (un ítem en el grupo equivocado, una etiqueta distinta,
un ícono distinto) es una regresión contra este contrato.

**Invariante de FR-005/FR-006** (no negociable): la columna *Ruta*, *Roles* y *moduleKey* de esta
tabla son **las que ya existen hoy** en `NAV_ITEMS`
(`src/app/core/config/navigation.config.ts`) — ninguna fila es nueva, ninguna se elimina. Lo
único que esta tabla define es la columna *Grupo nuevo*, *Etiqueta nueva* e *Ícono nuevo*
(`frame.group`, `frame.label`, `frame.icon` de [../data-model.md](../data-model.md) §4).

| Ruta | Roles (sin cambio) | moduleKey (sin cambio) | Grupo nuevo | Etiqueta nueva | Ícono nuevo (`app-icon`) | Etiqueta/ícono legados (referencia) |
|---|---|---|---|---|---|---|
| `/dashboard/admin` | ADMIN | — | Inicio | Dashboard | `layout-dashboard` | "Dashboard" / `dashboard` |
| `/dashboard/ventas` | ADMIN, CASHIER | — | Operación | Ventas | `shopping-cart` | "Ventas" / `sales` |
| `/dashboard/orders` | ADMIN, CASHIER, MESERO | — | Operación | Órdenes | `receipt` | "Órdenes" / `orders` |
| `/dashboard/mesas` | ADMIN | — | Operación | Mesas | `layout-grid` | "Mesas" / `tables` |
| `/dashboard/mesas-sesiones` | ADMIN, CASHIER, MESERO | — | Operación | Terminal de Mesas | `qr-code` | "Terminal de mesas" / `sessions` |
| `/dashboard/products` | ADMIN, CASHIER | — | Catálogo | Carta del Menú | `book-open` | "Carta del menú" / `products` |
| `/dashboard/categories` | ADMIN | — | Catálogo | Categorías | `tags` | "Categorías" / `categories` |
| `/dashboard/presentations` | ADMIN | — | Catálogo | Presentaciones | `cup-soda` | "Presentaciones" / `presentations` |
| `/dashboard/promotions` | ADMIN | `promociones` | Catálogo | Promociones | `percent` | "Promociones" / `promotions` |
| `/dashboard/inventario` | ADMIN | `inventario` | Inventario | Inventario | `package` | "Inventario" / `inventory` |
| `/dashboard/proveedores` | ADMIN | — | Inventario | Proveedores | `truck` | "Proveedores" / `suppliers` |
| `/dashboard/caja` | ADMIN, CASHIER | — | Control | **Cajas** | `banknote` | "Caja" / `cash` |
| `/dashboard/reports` | ADMIN | — | Control | Reportes | `chart-column` | "Reportes" / `reports` |
| `/dashboard/users` | ADMIN | — | Administración | Usuarios | `users` | "Usuarios" / `users` |
| `/dashboard/ajustes` | ADMIN | — | Administración | Ajustes | `settings` | "Ajustes" / `settings` |

**Orden de los grupos** (de arriba hacia abajo en el sidebar): Inicio, Operación, Catálogo,
Inventario, Control, Administración (`TENANT_FRAME_GROUP_ORDER`,
[../data-model.md](../data-model.md) §4). Un grupo sin ningún ítem visible para el rol/plan
actual **no se renderiza** (FR-016) — se reutiliza el mismo filtro que `groupedItems()` ya hace
hoy en `SidebarComponent` (`.filter(g => g.items.length > 0)`), solo que contra
`TENANT_FRAME_GROUP_ORDER` en vez de `NAV_GROUP_ORDER`.

**Íconos del navbar** (controles, no ítems de navegación — FR-003):

| Control | Ícono (`app-icon`) |
|---|---|
| Abrir/cerrar menú (hamburguesa) | `menu` |
| Notificaciones | `bell` |
| Alternar tema — tema actual claro | `moon` (lo que se vería al activar oscuro) |
| Alternar tema — tema actual oscuro | `sun` |
| Flecha del menú de usuario | `chevron-down` (ya existe en `app-icon`) |
| "Cambiar contraseña" en el menú de usuario | `key-round` |
| "Mi plan" en el menú de usuario | `badge-check` |
| "Cerrar sesión" en el menú de usuario | `log-out` |

**Lo que esta tabla no cubre**: `SUPER_ADMIN_NAV_ITEMS` (grupo `PLATAFORMA`) — fuera de alcance,
sin cambios (research R1). El contenido interno de cada pantalla (tablas, botones de cada
módulo) — sigue usando `app-mi-icon`/Material Icons, sin cambios (Assumptions de la spec).
