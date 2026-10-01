# Contrato de interfaz: campo "Cliente" en "Nueva orden" (Terminal de mesas)

Cubre FR-001 a FR-005, FR-008 a FR-011 (US1, US2, US3). Aplica a
`pos-heladeria/src/app/modules/tables/pages/manual-order-page.component.ts` y a
`customerName`/`setOrderTypeTab()` de `pos-terminal.store.ts`. No toca el menú QR ni ninguna
pantalla fuera de "Nueva orden".

## Estado y transiciones (una sola señal `customerName`, research.md D2/D3)

### Al abrir "Nueva orden" (`ngOnInit`)

1. **Antes** de leer `tableId`/`tipo` de la ruta: `customerName` se reinicia a `''`.
2. Se procesan `tableId`/`tipo` como hoy (`selectTable()`, y `setOrderTypeTab()` si hay
   `?tipo=para-llevar|domicilio` — cada uno ya dispara la regla de pestaña del punto siguiente).
3. **Al final**, siempre — haya habido o no un cambio de pestaña en el paso 2 — se aplica
   explícitamente la regla de pestaña (punto siguiente) sobre la pestaña vigente en ese momento
   (`'mesas'` por defecto, u otra si el paso 2 la cambió). **Este paso es obligatorio**: la ruta de
   Mesa (`mesas-sesiones/:tableId/orden-manual`, sin `?tipo=`) nunca pasa por `setOrderTypeTab()`,
   así que sin esta llamada explícita el campo quedaría vacío en vez de `"Consumidor final"` para
   ese camino — el más común de los tres (research.md D3).

### Regla de pestaña (se evalúa al abrir la pantalla y en cada `setOrderTypeTab()`)

| Pestaña destino | Condición sobre el valor actual (recortado) | Resultado |
|---|---|---|
| `mesas` / `para-llevar` | vacío | → `"Consumidor final"` |
| `mesas` / `para-llevar` | no vacío (default u otro nombre) | sin cambio |
| `domicilios` | exactamente `"Consumidor final"` | → `''` |
| `domicilios` | cualquier otro valor (incluido vacío) | sin cambio |

### Al enfocar el campo en `mesas`/`para-llevar` (FR-003)

El contenido del `<input>` queda seleccionado por completo (`HTMLInputElement.select()`),
independientemente de si muestra el valor por defecto o un nombre ya escrito. Sin cambios en
Domicilio.

### Al presionar "Crear pedido"

| Pestaña | Validación de "Cliente" |
|---|---|
| `mesas` / `para-llevar` | ninguna — el botón **no** se deshabilita por este campo; un valor vacío/solo espacios se envía tal cual (lo resuelve el backend, ver [post-orders-customer-name.md](./post-orders-customer-name.md)) |
| `domicilios` | **sin cambios** — sigue exigiendo nombre, dirección y valor del domicilio; botón deshabilitado y mensaje inline si falta |

### Tras crear el pedido

El pedido se crea con el valor visible en ese momento (recortado; vacío ⇒ lo resuelve el
backend). La pantalla navega fuera de "Nueva orden"; la próxima vez que se abra para otro pedido,
aplica el reinicio del primer punto — el campo **no** conserva el nombre del pedido recién creado.

## Lo que no cambia

- Las etiquetas de cada pestaña ("Cliente" en Mesa, "Cliente / Para llevar" en Para llevar,
  "Nombre cliente" en Domicilio) y el placeholder de Domicilio (`"Ej: Juan Pérez"`).
- El campo "Teléfono", "Dirección de entrega" y "Valor del domicilio" de la pestaña Domicilio.
- Cualquier pantalla que **muestre** (no cree) un pedido ya existente: detalle de pedido, tarjeta
  de la Terminal, Órdenes, Ventas — siguen leyendo `customer_name` tal como está guardado.
