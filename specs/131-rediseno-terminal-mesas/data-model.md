# Data Model: Rediseño visual de la Terminal de Mesas

Este spec **no introduce ni modifica entidades de datos** (ver "Key Entities" en
`spec.md`): reutiliza exactamente las mismas entidades que `PosTerminalStore` ya expone hoy
(Mesa, Sesión de mesa, Pedido, Línea de pedido, Cuenta de mesa/Bill, Intento de pago, Turno
de caja). Este documento no es un modelo de datos nuevo — es el **mapeo entre componente
Angular existente, su estado de origen en `PosTerminalStore`, y la sección del mockup de
referencia** que define su nuevo aspecto, para que la fase de tareas (`/speckit-tasks`) sepa
exactamente qué plantilla tocar por cada requisito funcional.

## Vista principal (grilla)

| Componente Angular | Estado de origen (`PosTerminalStore`) | Sección del mockup | Requisitos |
|---|---|---|---|
| `table-sessions.component.ts` (host) | — (compone los demás) | `isTerminal` | FR-001..006, FR-018, FR-019 |
| `pos-terminal-header.component.ts` | turno/caja/conexión (vía servicios inyectados por el store: `CashService`, `RealtimeService`, `TenantInfoService`) | cabecera de `isTerminal` | FR-001 |
| `pos-tables-panel.component.ts` | `tables`, `orders`, `orderTypeTab`, `filter`, `search`, `pendingOrders` | grilla de tarjetas + pestañas Mesas/Domicilios/Para llevar + buscador + filtro de estado, dentro de `isTerminal` | FR-002, FR-003, FR-004, FR-006 |
| `order-summary-card.component.ts` | cada `Table`/`DiningOrder` individual (estado, resumen de ítems, tiempo transcurrido, total) | tarjeta individual de la grilla | FR-004 |
| Botón "Crear pedido nuevo" (dentro de `pos-tables-panel` o header, según implementación actual) | `newOrderTableId`, `orderTypeTab` | botón de acción en sub-barra de `isTerminal` | FR-005, FR-022b (se oculta condicionalmente dentro del detalle de mesa) |

## Detalle de pedido (mesa, domicilio, para llevar)

| Componente Angular | Estado de origen (`PosTerminalStore`) | Sección del mockup | Requisitos |
|---|---|---|---|
| `pos-order-panel.component.ts` | `selectedTable`, `selectedOrder`, `orderTabs`, `draftLines`, `centralPanelTab`, `effectiveCentralView` | `tDetOn`/`tcOn` (cabecera + líneas) | FR-007, FR-008, FR-011, FR-024 |
| Bloque de pestañas "Pedido N" / "Nueva cuenta" (dentro de `pos-order-panel`) | `orderTabs`, acción equivalente a "+ Crear pedido nuevo" (spec 087) | bloque `accOn` ("Cuentas": Cuenta A/B + "Nueva cuenta") | FR-022, FR-022b |
| `pos-catalog-drawer.component.ts` + `cart.component.ts` + `cart-item-options.component.ts` + `product-select.component.ts` | `catalogOpen`, `catalogCategoryId`, `catalogSearchText`, `configuringProduct`, `draftLines` | catálogo embebido "Agregar producto" referenciado desde `tDetOn` | FR-009, FR-023 |
| Línea de pedido individual (dentro de `pos-order-panel`) | cada item de `selectedOrder.items` (`estado_cocina`, variante, opciones, nota, precio, promoción) | lista de líneas dentro de `tDetOn` | FR-008 (sin "Agregar adición"/badge "Modificada", FR-023) |
| Fila de dirección/teléfono/valor domicilio (dentro de `pos-order-panel`) | `deliveryAddress`, `deliveryPhone`, `deliveryFee` | fila compacta bajo la cabecera en `tDetOn` para pedidos sin mesa | FR-024 |

## Cobro

| Componente Angular | Estado de origen (`PosTerminalStore`) | Sección del mockup | Requisitos |
|---|---|---|---|
| `pos-checkout-panel.component.ts` + `bill-summary.component.ts` + `session-bill-panel.component.ts` | `subtotal`, `selectedOrderTotal`, `billingCustomerName`, `paymentMethodsAvailable`, `checkoutSubmitting` | panel de cobro dentro de `isTerminal`/`tDetOn` | FR-012, FR-013, FR-015, FR-017 |
| `payment-input.component.ts` | líneas de pago combinado (hasta 3 métodos) | selector de método(s) de pago | FR-013 |
| `payment-attempt-review-panel.component.ts` | intento de pago QR pendiente (`channel === 'QR_MENU'`, estado por confirmar) | `tdQrOn` (efectivo), `tdQ2On` (transferencia), `tdQ3On` (mixto — depende del spec 130) | FR-014, FR-014a, FR-014b, FR-014c |
| Botones "Imprimir Factura" / "Liberar Mesa" (dentro de `pos-checkout-panel`) | `lastSale`, `lastReceipts`, `setTableStatus` | acciones finales de `tDetOn` una vez sin cobro pendiente | FR-016 |

## Responsive

No corresponde a entidades de datos sino a comportamiento de layout: columnas de
`table-sessions.component.ts` (grilla ↔ detalle+cobro) según ancho de pantalla, con una
única región de scroll por columna (FR-018, FR-019) — ver `research.md` punto 6 y
`quickstart.md` para el guion de validación en los tres anchos de referencia.

## Nota sobre iconografía

El reemplazo de `app-mi-icon` (Material) por el set de iconos estilo `lucide` del mockup
(ver `research.md` punto 3) afecta a los mismos componentes listados arriba — no es una
entidad de datos, pero se documenta aquí porque cualquier tarea que toque la plantilla de
uno de estos componentes debe incluir también ese reemplazo puntual, no como un ítem
separado.
