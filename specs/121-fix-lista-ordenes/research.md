# Research: Correcciones visuales y funcionales de la lista de Órdenes

**Spec**: [spec.md](spec.md)

Esta feature no tiene incógnitas de "qué tecnología usar" — ambos repos (`pos-backend`, `pos-heladeria`) ya están en producción con stack fijo. La investigación aquí es de **código existente**: para cada una de las 4 historias, dónde vive hoy el defecto y qué restricción ya protegida por el sistema (tests de characterization, contratos D3/D15 de spec 094/120) condiciona la corrección.

## 1. Total en la tarjeta (US1, FR-001/FR-002)

**Hallazgo**: `GET /orders` (rama paginada, `pos-backend/app/api/v1/orders/router.py:638-697`) sirve la pantalla "Órdenes" con `OrderResponse.billing = None` **a propósito** (spec 094, research.md D3; comentario en `router.py:66-71` y `schemas.py:309-314`): calcular el desglose completo (`build_billing_summary`) por fila haría una consulta `Sale`/sesión por orden — un N+1 sobre hasta 100 pedidos por página. Ese presupuesto está protegido por un test de characterization:

- `pos-backend/app/characterization_tests/test_orders_pagination.py::TestOrdersListModoPaginado::test_guardia_de_trabajo_acotado_numero_de_sentencias_constante` — sembra 5 y luego 25 órdenes, cuenta las sentencias SQL ejecutadas por `GET /orders?page=1&size=20` y exige que el conteo **no crezca con el tamaño del lote**. No exige que el conteo se mantenga igual al de hoy — solo que sea constante respecto a N.

La Clarification de la sesión 2026-10-16 ("A": el total debe ser el valor final exacto, no una aproximación) descarta sumar `unit_price × quantity` en el frontend. La corrección correcta es en el backend, y debe respetar la misma disciplina de "una query en bloque para toda la página" que ya usan `paid_order_ids`/`staff_user_names` (`service.py:335-360`, llamadas desde `_decorate_orders`, `router.py:627-635`) — **no** reabrir el N+1 que `build_billing_summary` evita a propósito.

**Decisión**: añadir un campo nuevo y ligero `OrderResponse.total: Decimal | None` — **no** poblar `billing` en el listado (eso preservaría intacto el contrato D3/D15 y el test de characterization que lo exige null ahí). `total` replica la misma fórmula de 3 ramas que `build_billing_summary` (`service.py:227-318`: `factura_propia` lee `Sale.total`; `factura_agrupada` y `sin_factura` derivan de `suma_de_lineas ± descuento + domicilio`, con `max(total, 0)`), pero resuelta con **como máximo 2 consultas adicionales en bloque para toda la página**, no por fila:

1. Una consulta `Sale` por lote: `SELECT customer_order_id, total FROM sales WHERE customer_order_id IN (:ids)` (mismo patrón que `paid_order_ids`) → cubre el caso `factura_propia` sin tocar `_venta_propia` por fila.
2. Para las órdenes sin `Sale` propia: los `items` de la página **ya vienen precargados** (`selectinload(CustomerOrder.items)` en `list_orders_query`, `service.py:440-448`) — sumar `line_total` de los no anulados es aritmética en memoria, cero consultas extra. Solo falta saber si la *sesión* de mesa ya tiene alguna venta (caso `factura_agrupada`): una segunda consulta en bloque `SELECT DISTINCT table_session_id FROM sales WHERE table_session_id IN (:session_ids)` (mismo patrón que `_sesion_tiene_venta`, pero en bloque) resuelve esa rama para toda la página de una vez.

Con esto el conteo de sentencias sigue siendo **constante respecto a N** (dos consultas fijas más, no una por fila), así que el guardia de `test_guardia_de_trabajo_acotado_numero_de_sentencias_constante` sigue pasando sin tocarlo.

El detalle (`GET /orders/{id}`, `_load_order`) ya calcula `billing` completo; ahí `order.total` se deriva gratis de `order.billing.total` (ninguna consulta extra), así que el mismo valor sale tanto en la tarjeta como al abrir el detalle (FR-002, US1 escenario 2).

La rama **sin paginar** de `GET /orders` (Terminal de Mesas / Dashboard, `router.py:673-676`, `service.list_orders`) está explícitamente fuera del alcance de spec 120 y de esta corrección ("`list_orders()` no se toca", comentario en `service.py:428-429`) — `total` se queda `None` ahí, igual que `billing` hoy; ningún consumidor de esa rama lo necesita.

**Alternativas consideradas**:
- *Calcular el total en el frontend sumando `line_total` de los ítems ya presentes en el listado*: descartada por la Clarification — ignora descuento y domicilio para `factura_propia`/`factura_agrupada`, mostraría un número distinto al del detalle.
- *Poblar `billing` completo también en el listado*: descartada — reabriría exactamente el N+1 que D3 evitó a propósito (una consulta de `Sale` por fila vía `_venta_propia`, más otra de sesión vía `_sesion_tiene_venta`), y violaría el contrato ya congelado "`billing` es `null` en el listado" que otros tests de characterization verifican.

## 2. Filtro de fecha no refleja la selección (US2, FR-003/FR-004)

**Hallazgo**: `pos-heladeria/src/app/modules/orders/components/order-date-filter.component.ts`. El control recibe la fecha vigente por `@Input() value = ''` (propiedad de clase normal, no signal) y la usa dentro de `readonly label = computed(() => { const value = this.value || this.today(); ... })` (líneas 148, 167-173). `computed()` de Angular Signals solo reacciona a **lecturas de signals** dentro de su función; `this.value` es una propiedad de instancia corriente, así que `computed()` no tiene forma de saber que cambió y el valor de `label()` queda fijado para siempre al resultado del primer cálculo (que, en el primer render, es `"Hoy"` porque `value` todavía no ha llegado). El componente padre sí actualiza correctamente `OrdersListService.dateFrom`/`dateTo` (`setDate`, `orders-list.service.ts:125-129`) y pasa el valor nuevo por `[value]="svc.dateFrom()"` (`orders-page.component.ts:122`) — Angular reasigna la propiedad `value` del hijo en cada cambio, pero eso no reevalúa un `computed()` que nunca la leyó como signal.

**Decisión**: convertir `value` de `@Input() value = ''` a una signal de entrada (`value = input('')`, API estándar de Angular desde la v17, ya disponible en Angular 21 — `package.json` fija `^21.1.0`). `computed()` pasa entonces a depender de una lectura de signal real y se reevalúa en cada cambio del padre, sin necesidad de `ngOnChanges` para este propósito (se conserva `ngOnChanges`/o se reemplaza por un `effect()` solo para sincronizar `viewIso`, que sí necesita un efecto explícito al abrir el calendario). Mismo patrón que ya usan otros componentes signal-based del proyecto.

**Alternativas consideradas**:
- *Forzar el recómputo manualmente en `ngOnChanges` (p. ej. un signal interno que se vuelve a `set()` ahí)*: funcionaría, pero añade un signal redundante solo para espejar lo que un `input()` ya resuelve de forma nativa — más código para el mismo resultado.
- *Dejar `label` como método normal (no `computed()`) invocado desde la plantilla*: evita el bug (se recalcula en cada ciclo de detección de cambios), pero pierde la memoización y es la razón por la que probablemente se usó `computed()` en primer lugar; no es el patrón ya establecido en los demás componentes signal-based del módulo.

## 3. Paginador ausente en el diseño esperado (US3, FR-005/FR-006)

**Hallazgo**: `orders-page.component.ts:189-197` ya usa `<app-pagination-bar>` (`pos-heladeria/src/app/shared/pagination/pagination-bar.component.ts`), que sí pagina (`Por página`, `Página X de Y`, botones de texto "Anterior"/"Siguiente") pero **no** muestra el rango de resultados visibles ("X–Y de Z") que pide el diseño de referencia y que ya estaba definido como requisito en spec 120 (FR-008: "indicando el rango visible y el total"). Ese componente es compartido: lo consumen además `presentations`, `products`, `sales`, `promotions`, `categories`, `tables` e `inventory` (9 consumidores en total, confirmado por búsqueda en `src/app/modules/**`).

Los datos para calcular el rango ya están disponibles sin ningún cambio de API: `OrdersListService` expone `page()`, `size()` y `total()` como signals (`orders-list.service.ts:29-30,63`); el rango es aritmética pura (`inicio = (page-1)*size + 1`, `fin = min(page*size, total)`), igual que ya hace el propio `Page` del backend (`app/core/pagination.py`) para `pages`.

**Decisión** (según Clarification de la sesión 2026-10-16, "B"): construir un paginador **propio de esta pantalla** (nuevo componente en `pos-heladeria/src/app/modules/orders/components/`, mismo patrón de carpeta que `order-date-filter.component.ts`), que replique el diseño de referencia (selector de cantidad, rango "X–Y de Z", controles con chevrons) consumiendo los mismos signals que hoy recibe `<app-pagination-bar>`. El componente compartido `PaginationBarComponent` y sus otros 8 consumidores **no se tocan**.

**Alternativas consideradas**:
- *Extender `PaginationBarComponent` con el rango y el estilo del diseño*: resuelto por la Clarification como descartado — cambiaría el aspecto de 8 pantallas no pedidas en este spec, violando el Principio VI de la constitución (evitar cambios que mezclen alcance no relacionado) y el Principio II (comportamiento existente protegido salvo decisión explícita).

## 4. Badges sin esquinas completamente redondeadas (US4, FR-007)

**Hallazgo**: en el código actual (`orders-page.component.ts:173-176,180-184`), **ambas** etiquetas de la tarjeta (estado de pago y estado de la orden) ya usan la utilidad `rounded-full` de Tailwind v4 (`pos-heladeria` usa `tailwindcss@^4.1.12` vía `@tailwindcss/postcss`, sin `tailwind.config.js` — configuración por CSS en `src/styles.css`). No se encontró ninguna regla en `src/styles.css` que redefina `.rounded-full` ni un selector de mayor especificidad sobre `span`/`.badge` que compita con esa utilidad; las únicas reglas `border-radius` de ese archivo pertenecen a `.auth-theme` (pantallas de autenticación, sin relación).

**Implicación para la implementación**: no se puede confirmar desde el código fuente por qué el usuario ve esquinas apenas curvas — las dos hipótesis más probables son (a) el build que el usuario probó es anterior al commit de migración (`d58ab08`) y no refleja `rounded-full` todavía, o (b) un problema de renderizado específico de la combinación `px-2.5 py-1` + `text-[11px]`/`text-xs` en ciertos navegadores/zoom que hace el óvalo menos perceptible sin que sea, técnicamente, un rectángulo de esquinas parciales. La tarea de implementación debe **primero reproducir visualmente el defecto contra el build actual de `main`** (no asumir la causa) antes de tocar las clases; si reproduce, el arreglo más probable es forzar un `border-radius` explícito (p. ej. `9999px` inline o una utilidad equivalente) en vez de depender de que `rounded-full` se purgue/genere correctamente, para blindar el resultado independientemente de la causa real.

## Resumen de impacto por repositorio

| Repo | Cambia | No cambia |
|---|---|---|
| `pos-backend` | `OrderResponse.total` (nuevo campo, poblado en detalle y en la rama paginada de `GET /orders`) | Esquema de BD (sin migración), rama sin paginar de `GET /orders`, `billing` (sigue `null` en el listado), cualquier factura ya emitida |
| `pos-heladeria` | Tarjeta de orden (total + badges), `order-date-filter.component.ts` (signal input), nuevo paginador propio de Órdenes | `PaginationBarComponent` compartido y sus otros 8 consumidores, filtros de estado/tipo/búsqueda, navegación al detalle |
