# Research: Migrar vista del módulo de Órdenes al nuevo diseño

**Spec**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md)

Este documento resuelve las decisiones técnicas necesarias para pasar del spec al diseño (Fase 1), dado que la migración de vista requiere además una extensión aditiva del backend (ver Complexity Tracking en `plan.md`).

## 1. Cómo filtrar por fecha y buscar por cliente/orden sobre todo el negocio

**Decisión**: Extender `GET /orders` (`pos-backend`, `app/api/v1/orders/router.py` + `service.py`) con tres parámetros opcionales nuevos: `date_from: date | None`, `date_to: date | None` (filtran sobre `created_at`, inclusive) y `q: str | None` (búsqueda de texto). Todos se combinan con AND entre sí y con los filtros ya existentes (`status`, `order_type`, `page`, `size`).

**Rationale**: `GET /sales` (`app/api/v1/sales/router.py:130-148`) ya resuelve exactamente este mismo problema — fecha inicial/final inclusive sobre una columna de timestamp, más un criterio de búsqueda (`invoice_reference`) — para un listado paginado del mismo estilo. Replicar ese patrón exacto en Órdenes:
- No introduce ninguna dependencia nueva (Principio IX).
- No requiere migración de esquema (Principio VIII): ambos filtros leen columnas ya existentes (`created_at`, `customer_name`, `id`).
- Es aditivo y retrocompatible: cualquier llamador que no envíe los parámetros nuevos (Terminal de Mesas, Dashboard, u otros) sigue recibiendo exactamente la misma respuesta que hoy.

**Alternativas consideradas**:
- *Filtrar solo en el cliente sobre la página ya cargada*: rechazada explícitamente por el usuario — dejaría la búsqueda y el filtro de fecha funcionando solo dentro de los ≤100 registros de la página visible, no sobre el día/los datos completos, incumpliendo la paridad funcional pedida.
- *Cargar todas las órdenes sin paginar y filtrar/paginar en memoria en el frontend*: rechazada — no escala más allá del límite de `size` (100) del backend y reintroduce exactamente el mismo problema a mayor escala de datos.
- *Construir un endpoint de búsqueda separado (`/orders/search`)*: rechazada — innecesaria duplicación de lógica de filtrado/paginación cuando extender el endpoint existente basta y ya es el patrón establecido por Ventas.

## 2. Qué compara la búsqueda `q`

**Decisión**: `q` hace *match* insensible a mayúsculas/minúsculas contra `customer_name` (`ILIKE '%q%'`) **o** contra la representación en texto del identificador de la orden (`id::text ILIKE '%q%'`), igual que el código corto que se muestra en la UI (ver punto 3) es un derivado directo de ese mismo `id`.

**Rationale**: cubre los dos casos que el spec pide ("buscar por nombre de cliente o por número/identificador de orden", FR-004) sin introducir una columna nueva ni un índice de búsqueda de texto completo, innecesario para el volumen actual (decenas de órdenes por día, mismo orden de magnitud que Ventas).

**Alternativas consideradas**:
- *Usar `table_order_number` para la búsqueda por "número de orden"*: rechazada como único criterio — ese campo es `null` para TAKEAWAY/DELIVERY y para órdenes previas a la spec 087 (`dining.interface.ts:318-320`), así que la mitad de los tipos de orden quedarían sin forma de buscarse por número.
- *Búsqueda de texto completo (full-text search / trigram)*: rechazada por sobredimensionada para el volumen y el caso de uso actual (coincidencia parcial simple ya resuelve el 100% de los escenarios de aceptación del spec).

## 3. Qué "número/identificador de orden" mostrar en tarjeta, detalle y referencia de factura

**Decisión**: Derivar un código corto, puramente de presentación (no persistido), a partir del `id` (UUID) de la orden: los últimos 6 caracteres hexadecimales del UUID, en mayúsculas, prefijados con `#` (p. ej. `#4F2A91`). Se calcula igual en todos los lugares donde el spec pide mostrar el identificador de la orden (tarjeta de lista, encabezado del detalle, campo "Referencia" de factura — FR-001, FR-011, FR-012) y es exactamente lo que matchea la búsqueda `q` del punto 2.

**Rationale**: el diseño de referencia muestra un número de orden corto tipo ticket (`#0097`) para *todo* tipo de orden, pero el sistema actual no tiene una columna de numeración secuencial universal — `table_order_number` (spec 087) solo existe para pedidos en mesa. Generar el código desde el propio `id` ya existente:
- No requiere ninguna migración de datos ni columna nueva (Principio VIII).
- Funciona igual para los tres tipos de orden (`DINE_IN`, `TAKEAWAY`, `DELIVERY`), a diferencia de `table_order_number`.
- Es estable en el tiempo (el `id` no cambia), aunque no es tan corto/memorable como un contador secuencial.

**Alternativas consideradas**:
- *Agregar una columna de numeración secuencial global (`order_number`)*: rechazada para esta migración — es un cambio de modelo de datos con su propia migración/estrategia de rollback (Principio VIII) y mezclaría una clase de cambio distinta (dato nuevo persistido) dentro de una feature que el usuario acotó como "migrar la vista" (Principio VI); queda anotada como posible spec futura si el negocio la pide explícitamente.
- *Usar `table_order_number` y dejar sin número visible a TAKEAWAY/DELIVERY*: rechazada — deja el nuevo diseño incompleto para 2 de los 3 tipos de orden.

## 4. Mapeo de estados/tipos del diseño de referencia a los datos reales

**Decisión**: Reutilizar tal cual las etiquetas y colores ya definidos en `order-status.util.ts` (`Por confirmar`/`Abierta`/`Bloqueada`/`Pagada`/`Cancelada` para el estado de la orden; `En mesa`/`Para llevar`/`Domicilio` para el tipo; `Pagado`/`Pendiente` derivado de `displayOrderStatus` + `paid` para el badge de estado de pago), aplicando únicamente el tratamiento visual nuevo (color/ícono/forma de badge) que trae el diseño.

**Rationale**: el diseño de referencia usa nombres de un flujo de progreso de cocina (`Nuevo`/`Preparando`/`Listo`/`Completado`/`Cancelado`) que no existen como campo agregado a nivel de orden en el sistema real — existen por ítem (`KitchenStatus`), no por orden. Inventar un estado agregado nuevo sería una decisión de negocio no pedida (Principio XI) y un cambio de comportamiento no autorizado (Principio II). Ya resuelto como supuesto explícito en `spec.md` (Assumptions).

**Alternativas consideradas**: construir un estado derivado "progreso de cocina" por orden (agregando los `KitchenStatus` de sus ítems) — rechazada por quedar fuera del pedido explícito del usuario ("solo migrar la vista") y por introducir una regla de negocio nueva no especificada.

## 5. Selector de fecha con calendario

**Decisión**: Construir un componente de calendario nuevo, acotado al módulo `orders` (`src/app/modules/orders/components/`), que reproduce la interacción del diseño: botón con la fecha elegida, atajos "Hoy"/"Ayer", navegación mes a mes, y bloqueo de fechas futuras.

**Rationale**: el usuario eligió explícitamente paridad visual completa con el diseño de referencia, que muestra un selector de calendario combinado, no dos campos de fecha sueltos. No se introduce ninguna dependencia nueva: es HTML/Tailwind + lógica de fechas con `Date` nativo, igual que el resto del frontend.

**Alternativas consideradas**: reutilizar el patrón de `sales-page.component.ts` (dos `<input type="date">` para "Desde"/"Hasta") — rechazada para *esta* feature por no coincidir con el diseño pedido, aunque es una alternativa más simple y 100% válida si en el futuro se prioriza consistencia sobre paridad visual. No se extrae el componente nuevo a `shared/` todavía: no hay un segundo consumidor hoy (evitar abstracción prematura); se reconsidera si Ventas u otro módulo pide el mismo calendario más adelante.

## 6. Ítems del detalle dentro del nuevo layout tipo tabla

**Decisión**: Conservar el bloque condicional ya existente en `order-detail.component.ts` (cantidad, nombre de variante, opciones, notas, badge de "Anulado", importe por línea condicionado a `muestraImportes()`), re-estilizado visualmente para parecerse a las columnas del diseño (PRODUCTO / CANTIDAD / PRECIO UNIT. / SUBTOTAL), sin convertirlo en un `<table>` HTML literal.

**Rationale**: la lógica actual ya resuelve correctamente casos que la tabla simple del diseño no contempla (ítems anulados, adicionales, notas de cocina — FR-014 del spec exige preservarlos). Forzar un `<table>` de 4 columnas puras perdería esas filas condicionales o las complicaría innecesariamente; el resultado visual (columnas alineadas) se logra igual con un grid/flex, que es como ya está construido.

**Alternativas consideradas**: adoptar el `<table>` literal del diseño y mover notas/adicionales/anulado a una fila secundaria — rechazada por mayor riesgo de regresión visual/semántica sobre un bloque que spec 094 ya dejó cuidadosamente especificado (ver comentarios en `order-detail.component.ts`), sin beneficio funcional adicional.

## 7. Verificación

**Decisión**: Backend — extender la suite de tests existente de `app/api/v1/orders` (pytest) con casos para `date_from`, `date_to` y `q`, combinados entre sí y con `status`/`order_type`. Frontend — extender `orders-list.service.spec.ts`, `orders-page.component.spec.ts` y `order-detail.component.spec.ts` (Vitest) con los nuevos escenarios de aceptación del spec (búsqueda, fecha, grid, bloques agrupados, "Nueva orden", omisión de datos ausentes).

**Rationale**: sigue el patrón de verificación ya establecido en ambos repositorios (Principio X) sin introducir un framework de testing nuevo.
