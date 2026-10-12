# Data Model: Corrección — Mesa ocupada sin pedido no se puede liberar

No se introducen entidades nuevas ni se modifica el esquema de backend. Las entidades relevantes
(`Mesa`/`Table`, `Sesión de Mesa`/`TableSession`, `Pedido`/`DiningOrder`) ya existen y no cambian
sus campos ni relaciones. Lo único que cambia es un **estado derivado de interfaz** (no persistido)
que decide qué renderiza la terminal de mesas.

## Estado derivado: `centralState` (frontend, `pos-terminal.store.ts`)

| Valor actual | Condición actual | Problema |
|---|---|---|
| `'validar-pago'` | hay al menos un pedido QR por confirmar | sin cambios |
| `'mesa-libre'` | `tableOrders(tableId).length === 0 && !hasDraft()` | **colapsa dos casos distintos**: mesa realmente libre, y mesa `status === 'ocupada'` sin pedidos vivos |
| `'pedido'` | hay pedidos vivos o un draft | sin cambios |

| Valor corregido | Condición corregida | Resultado en UI |
|---|---|---|
| `'validar-pago'` | igual que hoy | sin cambios |
| `'mesa-libre'` | `tableOrders(tableId).length === 0 && !hasDraft() && table.status !== 'ocupada'` | sin panel de detalle (comportamiento actual para mesas realmente libres) |
| **`'ocupada-sin-pedido'`** (nuevo) | `tableOrders(tableId).length === 0 && !hasDraft() && table.status === 'ocupada'` | panel de detalle visible, única acción: "Liberar Mesa" |
| `'pedido'` | igual que hoy | sin cambios |

**Validación**: el criterio `table.status === 'ocupada'` es el mismo que ya usa
`deriveTableStatus()` (`pos-terminal.store.ts:256`) para la insignia de la grilla — no se inventa
un criterio nuevo, se reutiliza el existente para que ambas señales (insignia de grilla y panel de
detalle) queden consistentes entre sí.

**Transiciones relevantes** (no son transiciones de entidad persistida, son del estado derivado
anterior):

```text
'ocupada-sin-pedido' --[cajero confirma pedido nuevo]--> 'pedido'
'ocupada-sin-pedido' --[cajero presiona "Liberar Mesa"]--> (sesión cerrada, mesa pasa a libre
                                                             en backend) --> 'mesa-libre'
```

## Entidades existentes consultadas (sin modificación)

- **Mesa (`Table`)**: campo `status: TableStatus` (`'libre' | 'ocupada' | 'reservada' |
  'pendiente_pago'`, `table.interface.ts:3`) — ya existe, solo se lee desde un punto donde antes no
  se consultaba.
- **Sesión de Mesa (`TableSession`)**: sin cambios; el endpoint de liberación
  (`release_paid_session`) ya opera correctamente sobre sesiones sin pedidos.
- **Pedido (`DiningOrder`)**: sin cambios; `tableOrders()` sigue filtrando pedidos no cancelados
  igual que hoy.
