# Research: Registro Automático de Inventario al Generar Compra Sugerida

Todas las "NEEDS CLARIFICATION" del Technical Context se resuelven aquí inspeccionando el
código real de `pos-backend`/`pos-heladeria` y la sesión de clarificación del propio spec
(2026-11-21). No queda ninguna pendiente.

## D1: Punto de inserción — extender `_build_purchase_order`, no `receive_purchase`

- **Decision**: la recepción automática se implementa añadiendo un parámetro
  `receive_immediately: bool = False` a `_build_purchase_order()`
  (`app/api/v1/inventory/service.py:425-454`), la variante no-commiteadora que
  `generate_suggested_purchases()` ya usa para construir cada `Purchase`+`PurchaseItem[]` por
  proveedor dentro de una única transacción (spec 158, research.md D5). Cuando es `True`, tras
  resolver cada línea con `_resolve_purchase_line(..., update_supplier_cost=False)`, por cada
  `PurchaseItem` se ejecutan los mismos tres pasos que ya usa `create_purchase()`
  (`service.py:280-322`) para su alta directa: `purchase_item.received_quantity =
  purchase_item.quantity`, `record_movement(db, item.id, type="in",
  quantity=purchase_item.quantity_base, reason=reasons.COMPRA,
  reference_type=reasons.REF_PURCHASE, reference_id=purchase.id, user_id=user_id)` e
  `item.unit_cost = purchase_item.cost_base`; al final del bucle, `purchase.status =
  "received"` (en vez de `"draft"`). `generate_suggested_purchases()` pasa
  `receive_immediately=True`; `create_purchase_order()`/`update_purchase_order()` (creación
  manual de órdenes, fuera de esta pantalla) siguen llamando con el default `False`
  (comportamiento idéntico, cero cambios observables, FR-011).
- **Rationale**: `create_purchase()` ya resuelve exactamente el problema de "crear una compra
  y darla por recibida por completo en el mismo commit" — es el flujo de "alta directa" que
  usa hoy `POST /inventory/purchases` cuando no se pasa por el estado `draft`. Reutilizar esos
  tres pasos dentro de `_build_purchase_order()` evita duplicar la lógica de conversión de
  unidades (`_resolve_purchase_line`, ya resuelve `quantity_base`/`cost_base` sea por
  presentación de proveedor o por unidad de compra directa, specs 106/107/134) y reutiliza
  `record_movement()` (`app/inventory_engine/stock.py:54`), la única función que escribe
  `InventoryMovement` y aumenta `InventoryItem.current_stock` de forma atómica (bloqueo de
  fila) en todo el proyecto. Como `_build_purchase_order()` ya construye N órdenes dentro de
  la transacción de `generate_suggested_purchases()` sin comitear nada hasta el final, aplicar
  la recepción ahí preserva la atomicidad del lote completo (FR-004) sin tocar el punto de
  commit/rollback que ya existe.
- **Alternatives considered**:
  - Llamar a `receive_purchase()` (`service.py:511-578`) justo después de crear cada orden —
    rechazada: esa función espera una `Purchase` ya comiteada y re-deriva la cantidad recibida
    desde `presentation_quantity`/`relation.effective_conversion_factor` del request de
    recepción, no desde el `quantity_base`/`cost_base` que `_resolve_purchase_line` ya resolvió
    al construir la línea; además comitea/rollbackea su propia transacción, rompiendo la
    atomicidad de todo el lote (el mismo motivo por el que spec 158 (research.md D5) ya
    rechazó encadenar `create_purchase_order()` una vez por proveedor).
  - Duplicar los tres pasos de recepción en una función nueva y separada en vez de
    extender `_build_purchase_order()` con un flag — rechazada: repite ~5 líneas ya probadas
    por `create_purchase()`, con el mismo riesgo de divergencia futura que spec 158 ya evitó
    parametrizando en lugar de duplicar (`update_supplier_cost`).

## D2: `SupplierItem.last_cost` sigue sin tocarse en este flujo

- **Decision**: `generate_suggested_purchases()` sigue llamando a `_build_purchase_order(...,
  update_supplier_cost=False)` (sin cambios respecto a spec 158); el nuevo
  `receive_immediately=True` solo actualiza `InventoryItem.unit_cost` (el costo del insumo),
  nunca `SupplierItem.last_cost` (el precio de referencia del proveedor).
- **Rationale**: el spec (FR-008) exige actualizar "el costo o precio de referencia de cada
  insumo... de forma consistente con el comportamiento ya existente cuando una orden de compra
  se recibe o se da de alta directamente" — y ese comportamiento existente
  (`create_purchase()`/`receive_purchase()`) **tampoco** toca `SupplierItem.last_cost` al
  recibir (esa actualización solo ocurre en `_resolve_purchase_line` vía
  `apply_purchase_cost()`, y solo cuando `update_supplier_cost=True`, es decir, al **capturar**
  la línea con el precio real del proveedor, no al recibirla). Mantener
  `update_supplier_cost=False` aquí es exactamente FR-008 aplicado, no un cambio nuevo: spec
  158 (FR-007) ya decidió que el precio editado en pantalla de compra sugerida no debe
  persistir como costo de referencia del proveedor, y ese comportamiento no está en el alcance
  de este spec para cambiarlo.
- **Alternatives considered**: pasar `update_supplier_cost=True` ahora que la orden nace
  recibida — rechazada: cambiaría un comportamiento de spec 158 (FR-007) sin que este spec lo
  pida ni lo autorice; el spec 163 solo habla de "costo de referencia del insumo" (FR-008), no
  del precio de referencia del proveedor.

## D3: Anulación — reusar `void_purchase` sin modificarlo

- **Decision**: `void_purchase()` (`service.py:603-627`) se reutiliza exactamente igual para
  anular una orden generada por esta vía; no requiere ningún cambio.
- **Rationale**: `void_purchase()` ya es agnóstico a *cómo* se dio de alta el stock de una
  compra — revierte, para cada `PurchaseItem`, exactamente su `quantity_base` congelado
  (`record_movement(..., type="out", reason=reasons.AJUSTE,
  reference_type=reasons.REF_PURCHASE_VOID, ...)`) y marca `voided_at`/`voided_by`, sin mirar
  `status` ni cómo se llegó a él. Una `Purchase` creada por `create_purchase()` (alta directa)
  ya se anula hoy con esta misma función; una creada por la nueva
  `generate_suggested_purchases(receive_immediately=True)` queda en el mismo estado
  observable (`status="received"`, `PurchaseItem.quantity_base`/`cost_base` resueltos), así que
  no hay ninguna rama nueva que cubrir (FR-009).
- **Alternatives considered**: ninguna — no hay una decisión real que tomar aquí, solo
  confirmar que el mecanismo ya cubre el caso nuevo sin cambios (research, no implementación).

## D4: Frontend — quitar insumos repuestos de la lista invalidando la query, no filtrando en memoria

- **Decision**: FR-011a se resuelve inyectando `QueryClient`
  (`@tanstack/angular-query-experimental`) en `SuggestedPurchaseService` y llamando
  `queryClient.invalidateQueries({ queryKey: ['suggested-purchases'] })` justo después de que
  `generate()` resuelve con éxito — mismo patrón que ya usa
  `presentations/services/presentation.service.ts` (`service.py:125/141/157` del lado
  Angular) tras sus propias mutaciones. La invalidación dispara un refetch de la página actual
  contra `GET /inventory/purchases/suggested`, que ya filtra por
  `current_stock <= min_stock` — como el stock de los insumos generados subió en el mismo
  commit de `generate()`, el refetch los excluye solo, sin lógica nueva de filtrado en el
  cliente.
- **Rationale**: evita mantener dos fuentes de verdad de "qué insumos siguen bajo mínimo" (la
  que ya calcula el backend vs. una réplica en el `historyMap` del componente); reusa
  exactamente el mecanismo de invalidación de caché que el proyecto ya usa para refrescar
  listados paginados tras una mutación (`injectPagedQuery` ya soporta esto por construcción,
  al ser un `injectQuery` de TanStack Query).
- **Alternatives considered**: quitar manualmente del `historyMap`/filtrar `service.lines()`
  en el componente los `inventory_item_id` que acaban de generarse — rechazada: duplicaría el
  criterio "sigue bajo mínimo" en el cliente (frágil si el insumo tenía más déficit del que
  cubrió la compra, caso no cubierto por el spec) en vez de confiar en el mismo query que ya
  decide eso en el servidor; además no corrige la página si el usuario no estaba en la primera
  página al generar.

## D5: Estado "recibida" en la confirmación — reusar el mapeo de etiquetas ya existente

- **Decision**: la confirmación de `suggested-purchase-page.component.ts` (FR-010) muestra la
  etiqueta de estado de cada `Purchase` devuelta reusando el mismo criterio de
  `statusLabel(p)`/clases de color que ya usa `inventory-page.component.ts`
  (`p.status === 'received' → 'Recibida'`, líneas ~1090-1100), en vez de inventar una etiqueta
  nueva solo para esta pantalla.
- **Rationale**: `PurchaseStatus` (`inventory.interface.ts:72`) ya incluye `'received'` y el
  backend ya lo devuelve sin cambios de contrato (`PurchaseResponse.status`); solo falta
  mostrarlo en esta pantalla, que hoy no lo hace porque toda `Purchase` que generaba era
  siempre `draft`.
- **Alternatives considered**: no mostrar el estado, solo el enlace a la orden (como hoy) —
  rechazada: FR-010 pide explícitamente mostrar que la orden quedó en "recibida" en la propia
  confirmación.
