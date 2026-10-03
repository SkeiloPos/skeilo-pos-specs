# Contrato: Navegación y rutas del frontend para "Carta del menú" (Cajero)

**Spec**: [../spec.md](../spec.md) | **Research**: [../research.md](../research.md) (D11)

Lista autoritativa de qué cambia en los tres puntos del frontend que controlan acceso
por rol, siguiendo el mismo formato que `specs/075-rol-mesero/contracts/
frontend-route-access.md`.

## `NAV_ITEMS` (`src/app/core/config/navigation.config.ts`)

| Ítem | Grupo | Roles hoy | Roles después |
|---|---|---|---|
| Carta del menú | CATÁLOGO | `[ADMIN]` | `[ADMIN, CASHIER]` |
| Categorías | CATÁLOGO | `[ADMIN]` | sin cambio |
| Presentaciones | CATÁLOGO | `[ADMIN]` | sin cambio |
| Promociones | CATÁLOGO | `[ADMIN]` | sin cambio |
| (todos los demás) | — | sin cambio | sin cambio |

Con esto, el Cajero ve la sección "CATÁLOGO" con exactamente una opción (escenario 1):
los otros tres ítems del mismo grupo siguen sin listar `CASHIER`, así que
`sidebar.component.ts` los sigue ocultando sin ningún cambio ahí.

## `dashboardRoutes` — `roleGuard([...])` (`src/app/modules/dashboard/routes.ts`)

| Ruta | Roles hoy | Roles después |
|---|---|---|
| `products` (listado, hoy `ProductsPageComponent`) | `[ADMIN]` | `[ADMIN, CASHIER]` |
| `products/new` | `[ADMIN]` | sin cambio (sigue exclusivo de Admin — el Cajero nunca ve ni alcanza esta ruta) |
| `products/:id` (formulario de edición) | `[ADMIN]` | sin cambio (sigue exclusivo de Admin, research.md D11 — la navegación de Admin al hacer clic en una fila no cambia) |
| `products/:id/detalle` (**nueva**, vista de solo lectura) | no existe | `[ADMIN, CASHIER]` |

## Dentro de `ProductsPageComponent` (misma pantalla, acción admin-only adentro)

Mismo patrón que ya usa `cash-session.store.ts:136` para Caja:

```ts
readonly isAdmin = computed(() => this.auth.currentUser()?.role === UserRole.ADMIN);
```

| Elemento de la pantalla | Visible para |
|---|---|
| Listado, búsqueda por nombre, filtro Todos/Disponibles/Agotados | `ADMIN` y `CASHIER` |
| Interruptor "Agotado" por fila | `ADMIN` y `CASHIER` (ambos llaman al mismo `PATCH /products/{id}/availability`, ver `products-api.md`) |
| Botón "Nuevo producto" | solo `isAdmin()` |
| Acciones de editar / activar-desactivar (`active`) | solo `isAdmin()` |
| Destino del clic en una fila / "Ver detalle" | `ADMIN` → `products/:id` (formulario, sin cambio); `CASHIER` → `products/:id/detalle` (nuevo, solo lectura) |

Ningún mensaje de error de permisos se muestra al Cajero en esta pantalla (escenario 2):
como el propio componente oculta los elementos que no le corresponden (en vez de
mostrarlos y fallar al usarlos), no hay ninguna acción visible para el Cajero que pueda
disparar un 403.

## `ROLE_DEFAULT_ROUTES` (`src/app/core/guards/role.guard.ts`)

Sin cambios — el destino por defecto de Cajero sigue siendo el mismo de hoy; esta spec
solo agrega acceso a una ruta adicional, no cambia el destino post-login de ningún rol.
