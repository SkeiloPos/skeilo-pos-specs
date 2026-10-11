# Contrato: navegación tras crear un pedido (frontend)

> **Reescrito durante la implementación** (ver `tasks.md`, Fase 3, nota de "Hallazgo clave"): el
> diseño original de este documento asumía una ruta nueva, `/dashboard/orders/:id`
> (`OrderDetailComponent`). Al implementar se confirmó que ese componente es de solo lectura, sin
> ningún panel "Cobrar pedido" — el panel real con ese nombre literal
> (`pos-checkout-panel.component.ts:224`), el estado por ítem "Pendiente"
> (`kitchenStatusLabel`, `order-status.util.ts:86`) y el encabezado por tipo
> (`pos-order-panel.component.ts:430-444`) viven **en la terminal misma**
> (`/dashboard/mesas-sesiones`), mostrados en el sitio cuando hay un pedido seleccionado. Este
> documento describe el contrato real que se implementó.

Define el contrato de query params entre `ManualOrderPageComponent` y `TableSessionsComponent` en
`pos-heladeria`, necesario para cumplir FR-001, FR-002, FR-007, FR-008 y FR-010.

Los nombres de los query params (`pestana`, `mesa`, `pedido`) se escriben en español, siguiendo la
convención ya establecida en este mismo código para parámetros de navegación de intención de UI
(`table-sessions.component.ts:373,400` y `manual-order-page.component.ts:889` ya usan `tipo`, no
`type`).

## 1. De "Nueva orden" de vuelta a la terminal

Tras una creación exitosa, `ManualOrderPageComponent.confirm()`
(`manual-order-page.component.ts:978-994`) navega a:

```
/dashboard/mesas-sesiones?pestana=<pestana>&pedido=<id>[&mesa=<tableId>]
```

- `pestana` — uno de `mesas` | `para-llevar` | `domicilios`, calculado a partir del tipo de pedido
  creado.
- `pedido` — ID del pedido recién creado (ya disponible en `store.selectedOrderId()` tras
  `createManualOrderFromDraft()`, ver `research.md` punto 2 — el store ya lo seteaba antes de
  esta spec, solo faltaba leerlo).
- `mesa` — **solo presente cuando `pestana=mesas`**: el `dining_table_id` de la mesa
  (`store.selectedTableId()`). Para Para llevar/Domicilio no hay mesa, así que no se envía.

| Tipo de pedido creado | `pestana` | `mesa` |
|---|---|---|
| Mesa | `mesas` | sí (tableId) |
| Para llevar | `para-llevar` | no |
| Domicilio | `domicilios` | no |

## 2. En la terminal: seleccionar lo correcto al cargar

`TableSessionsComponent.ngOnInit()` lee los tres query params (`ActivatedRoute.snapshot.queryParamMap`)
y, antes de mostrar la grilla:

1. Si `pestana` es uno de los tres valores válidos → `store.setOrderTypeTab(pestana)`.
2. Si `mesa` está presente → `store.selectTable(mesa)` (ya existente; selecciona la mesa y
   auto-selecciona su primer pedido activo) y, si además llega `pedido`, `store.selectOrder(pedido)`
   justo después, para fijar exactamente ese pedido (no "el primero que encuentre" — relevante si
   la mesa tuviera más de un pedido activo).
3. Si **no** hay `mesa` pero sí `pedido` → `store.selectStandaloneOrder(pedido)` (método ya
   existente, pensado exactamente para pedidos de Para llevar/Domicilio sin mesa — también carga
   los datos de cobro que necesita el panel "Cobrar pedido").
4. Si no llega ningún query param (p. ej. se entra a la terminal por cualquier otro camino): sin
   cambios — `orderTypeTab` queda en su valor por defecto (`'mesas'`) y no se selecciona nada
   (FR-010).

Ninguno de estos tres métodos (`selectTable`, `selectOrder`, `selectStandaloneOrder`) es nuevo — ya
existían para cuando el cajero selecciona una mesa/pedido a mano desde la grilla; esta spec solo
los invoca también desde `ngOnInit()` cuando los query params los traen.

## 3. Qué muestra la terminal una vez seleccionado (ya existente, sin cambios)

Con el pedido/mesa seleccionados, `TableSessionsComponent` ya renderizaba (sin tocar nada de esto):

- `pos-order-panel.component.ts` — encabezado (`headerTitle()`: "Mesa {N}" / "Domicilio" / "Para
  llevar") + estado (`headerStatusText()`: `'en preparación'` mientras algún ítem no está
  `'listo'`, `'pago pendiente'` / `'listo para cobrar'` según corresponda) + cada ítem con su
  estado (`kitchenStatusLabel('pendiente')` = "Pendiente").
- `pos-checkout-panel.component.ts` — título "Cobrar pedido" (línea 224) con el total a cobrar.

Estos textos satisfacen la intención de FR-007/FR-009 (un pedido recién creado con estado visible
y el total a cobrar a la vista) con el vocabulario ya establecido de la terminal, sin introducir
un segundo formato de encabezado ("Pedido · Mesa N") que solo aplicara al llegar desde creación —
eso habría significado dos textos distintos para el mismo panel según de dónde se venga,
inconsistente y fuera del alcance de esta corrección (Principio V/VI).

## Casos de prueba de referencia (para `/speckit-tasks`)

1. Crear pedido Mesa → vuelve a `/dashboard/mesas-sesiones?pestana=mesas&mesa=t1&pedido=o3` → la
   terminal abre en "Mesas" con esa mesa y ese pedido seleccionados.
2. Crear pedido Para llevar → `?pestana=para-llevar&pedido=o1` → terminal en "Para llevar" con ese
   pedido seleccionado (`selectStandaloneOrder`).
3. Crear pedido Domicilio → `?pestana=domicilios&pedido=o2` → análogo, `selectedTableId` en `null`.
4. Entrar a `/dashboard/mesas-sesiones` sin ningún query param (p. ej. desde el menú de
   navegación) → sin cambios: pestaña "Mesas", nada seleccionado (FR-010).
5. Recargar el navegador en `/dashboard/mesas-sesiones?pestana=para-llevar&pedido=o1` → la terminal
   vuelve a seleccionar lo mismo (SC-005) porque todo el estado necesario vive en la URL, no en
   memoria del store.
