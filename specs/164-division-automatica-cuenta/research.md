# Phase 0 Research: División automática de cuenta por ítem

No quedaron `NEEDS CLARIFICATION` en el Technical Context del plan — las cuatro preguntas de
negocio ya fueron resueltas en las Clarifications del spec. Esta fase documenta las decisiones
técnicas necesarias para implementar el comportamiento ya aprobado, basadas en la investigación
del código existente de `pos-backend` y `pos-heladeria`.

## 1. Dónde vive hoy el guard de "orden sin pago registrado"

- **Decisión**: Las tres operaciones nuevas (split, move, split-to-new) reutilizan
  `order_has_sale(db, order_id)` (`pos-backend/app/api/v1/orders/service.py`, línea ~95) como
  única fuente de verdad para "¿esta orden ya tiene un pago registrado?", aplicado a **todas**
  las órdenes involucradas (origen y, cuando aplica, destino).
- **Rationale**: Es la misma función que ya usan `move_order`/`merge_orders`
  (`tables_advanced.py`) y `pay_order`/`checkout_and_send` (`checkout.py`) para la misma
  pregunta; reutilizarla evita una segunda fuente de verdad sobre qué significa "pagada" y
  hereda su defensa contra el bug histórico documentado en su docstring (payment_status=PAID
  sin `customer_order_id` seteado en ventas multi-orden).
- **Alternativas consideradas**: Reimplementar el check leyendo solo `payment_status`. Rechazado
  porque ignoraría el fallback vía `Sale.customer_order_id` que `order_has_sale` ya implementa
  para cubrir el caso edge documentado.

## 2. Cómo representar "mover una cantidad parcial de una línea"

- **Decisión**: No se modela como una operación atómica distinta a nivel de dato. Mover/asignar
  cantidad parcial de un `OrderItem` se implementa como: (a) decrementar `quantity` en la línea
  de origen (o eliminarla si queda en 0), y (b) o bien incrementar `quantity` en una línea
  compatible existente en el destino (ver punto 3) o insertar un `OrderItem` nuevo en el destino
  con la cantidad movida, copiando `product_variant_id`, `unit_price`,
  `discounted_unit_price`/`discounted_line_total` (prorrateado a la cantidad movida),
  `estado_cocina`, y las filas hijas `OrderItemOption`/`OrderItemTopping` asociadas (duplicadas,
  no reasignadas, porque pertenecen a una línea específica).
- **Rationale**: `OrderItem` no tiene un campo de "cantidad reservada/fraccionable"; el modelo ya
  soporta múltiples líneas del mismo producto en una orden (no hay unicidad por
  producto+variante), así que fraccionar una línea en dos (una por orden) es una operación
  puramente de filas, consistente con cómo ya se crean líneas nuevas en `consolidation.py`
  (`add_item_to_order`).
- **Alternativas consideradas**: Agregar un campo `moved_from_item_id`/historial de movimientos.
  Rechazado por ahora — el spec no pide trazabilidad de qué línea viene de cuál movimiento
  (Assumptions: "no se requiere acción explícita de deshacer división"), y agregarlo sería una
  ampliación de alcance no solicitada (Principio V/VI).

## 3. Criterio de fusión de líneas en la orden destino

- **Decisión**: Dos líneas se consideran "la misma línea" para efectos de fusión si coinciden
  exactamente en `product_variant_id`, `unit_price` (o `discounted_unit_price` cuando aplica
  promoción) y `estado_cocina`. Si coinciden, se suma `quantity` a la línea existente en el
  destino. Si no coinciden en `estado_cocina` (aunque coincidan en producto/variante/precio), se
  crea una línea independiente — exactamente como lo exige la Clarification de sesión
  2026-11-21 ("si el estado de entrega difiere, quedan como líneas independientes").
- **Rationale**: Replica el criterio de clarification del spec de forma literal, usando los
  campos que ya existen en `OrderItem` sin necesidad de un campo nuevo de "clave de fusión".
- **Alternativas consideradas**: Fusionar también cuando el precio difiere (p. ej. por un
  descuento aplicado después). Rechazado explícitamente por el spec: la Clarification dice
  "mismo producto/variante/**precio**" como condición de fusión.

## 4. Cómo se crea la orden nueva en split / split-to-new

- **Decisión**: Reutilizar la misma construcción de `CustomerOrder` que usa `create_order`/
  `submit_cart` para los campos no relacionados con ítems: mismo `table_session_id`,
  `dining_table_id`, `channel`, `order_type`, `cash_shift_id`, y un `table_order_number` nuevo
  obtenido con la misma lógica de numeración por turno de caja ya usada en esas rutas (spec 087).
  `participant_id` de la orden nueva queda `NULL` (ítem-level ya trae su propio
  `participant_id`, que se preserva al mover/copiar la línea).
- **Rationale**: Evita introducir una segunda forma de numerar/crear órdenes; la nueva orden debe
  ser indistinguible — para el resto del sistema (cobro, facturación, KDS) — de una orden creada
  por el flujo normal.
- **Alternativas consideradas**: Crear las órdenes nuevas con `status` fijo `pendiente`.
  Rechazado — las líneas movidas conservan su `estado_cocina` individual (confirmado por el
  spec), por lo que el `status` de la orden resultante se deriva de sus líneas igual que ya lo
  hace el resto del sistema (una orden con todas las líneas `entregado` ya se considera
  `entregada`), sin lógica especial nueva.

## 5. Necesidad de migración de base de datos

- **Decisión**: No se requiere ninguna migración de Alembic. Las tres operaciones nuevas son
  transformaciones sobre filas de `customer_orders`/`order_items` con los campos que ya existen
  hoy; no se agrega columna, tabla ni constraint nuevo.
- **Rationale**: Confirmado en la investigación del modelo de datos (`data-model.md`): todos los
  campos necesarios (`quantity`, `unit_price`, `estado_cocina`, `participant_id`,
  `product_variant_id`, `table_session_id`, `payment_status`) ya existen en `OrderItem`/
  `CustomerOrder`.

## 6. Capa donde vive la lógica nueva en el backend

- **Decisión**: Nuevo módulo `app/api/v1/orders/item_transfer.py` con tres funciones
  (`split_order`, `move_item`, `split_item_to_new_order`), siguiendo el mismo patrón de
  `tables_advanced.py` (función de servicio pura + transacción explícita + endpoint delgado en
  `router.py` que solo valida entrada y llama al servicio).
- **Rationale**: Mantiene la separación router/servicio ya establecida en el módulo `orders`;
  un archivo nuevo (en vez de ampliar `tables_advanced.py`) mantiene cada archivo enfocado en una
  unidad de cambio coherente (Principio VI) dado que esta es una familia de operaciones distinta
  (ítem, no orden) aunque conceptualmente hermana.

## 7. Capa donde vive la UI nueva en el frontend

- **Decisión**: Extender `pos-order-panel.component.ts` (botón "Dividir cuenta" por pestaña de
  orden + acción por fila de ítem) y `pos-terminal.store.ts` (estado/acciones), con nuevos
  métodos en `table.service.ts` para las tres llamadas HTTP, siguiendo el patrón ya usado para
  `mergeOrders()`.
- **Rationale**: Es el mismo archivo donde ya vive el botón "Nueva cuenta" (línea 283-291) y los
  botones por ítem ("Anular"); agregar ahí mantiene la UI de la terminal de mesas en un solo
  lugar cohesivo, sin crear un componente nuevo para una funcionalidad que extiende la vista
  existente.
- **Alternativas consideradas**: Un modal/componente separado para "elegir orden destino al
  mover un ítem". Se deja abierto como detalle de implementación de UI (fase de tasks), no como
  decisión arquitectónica de este research — cualquiera de las dos opciones es compatible con la
  estructura aquí definida.
