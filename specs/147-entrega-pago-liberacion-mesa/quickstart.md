# Quickstart: validación de Ciclo de Vida Simplificado del Pedido y Control Manual de Mesas

Guía de validación extremo a extremo, no de implementación. Cada escenario cita el
Acceptance Scenario del spec que prueba.

## Prerrequisitos

- Backend (`pos-backend`): venv activado, Postgres local disponible (ver memoria de sesión
  "How to run sibling-repo tests"), migración de este spec aplicada sobre al menos un
  esquema de tenant de prueba.
- Frontend (`pos-heladeria`): `ng serve` o equivalente, apuntando al backend anterior.
- Datos: al menos una mesa (`dining_tables`) con QR activo, y un usuario cajero/staff
  autenticado.

## Escenario 1 — Entregar un pedido completo con un clic (Historia 1)

1. Crear un pedido (cualquier canal: QR, mostrador, mesa, domicilio) con 6 ítems.
   **Verificar**: `status == 'pendiente'`, `payment_status == 'UNPAID'`, los 6 ítems en
   `'pendiente'`.
2. Presionar "Entregar" una sola vez.
   **Verificar**: `status == 'entregada'`, los 6 ítems en `'entregado'`,
   `payment_status` sigue `'UNPAID'`. No existe en la UI ninguna acción de entrega por
   ítem individual.
3. Disparar dos solicitudes de entrega casi simultáneas sobre la misma orden (doble clic o
   dos pestañas/sesiones).
   **Verificar**: ambas responden éxito; `status` cambió una sola vez; no hay un segundo
   evento de cambio de estado duplicado en el stream SSE.
4. Crear una orden y cancelarla (ver Escenario 4), luego intentar "Entregar".
   **Verificar**: rechazo explícito, el estado permanece `'cancelada'`.

## Escenario 2 — Pago independiente del estado del pedido (Historia 2)

1. Con la orden del Escenario 1 ya `'entregada'` y `payment_status == 'UNPAID'`, registrar
   el cobro.
   **Verificar**: `payment_status` pasa a `'PAID'`; `status` permanece `'entregada'`
   (cobrar no cambia el pedido, entregar no cambia el pago).
2. Ver el detalle del pedido y la tarjeta de su mesa en la Terminal.
   **Verificar**: ambos indicadores (`status`, `payment_status`) se muestran por separado y
   de forma visualmente distinguible.
3. Con la orden `'entregada'`+`'UNPAID'`, consultar el filtro "Entregadas sin cobrar".
   **Verificar**: la orden aparece; tras cobrar (paso 1), repetir la consulta — la orden ya
   no aparece.
4. Crear un pedido QR, confirmar su pago desde caja antes de entregarlo, luego presionar
   "Entregar".
   **Verificar**: queda `'entregada'`+`'PAID'` en el mismo paso; el comensal ve la
   actualización en su propia vista QR en tiempo real, sin recargar.

## Escenario 3 — Liberación manual de mesa (Historia 3)

1. Ocupar una mesa, generar una sola orden, entregarla y cobrarla (queda `'entregada'`+
   `'PAID'`, es decir, cerrada).
   **Verificar**: la mesa sigue `'ocupada'`; el comensal puede crear una nueva orden en la
   misma visita.
2. Con todas las órdenes de la mesa cerradas o canceladas, presionar "Liberar mesa".
   **Verificar**: la mesa pasa a `'libre'`; la sesión de mesa se cierra.
3. Repetir el paso 1 pero sin cobrar (orden `'entregada'`+`'UNPAID'`), y presionar "Liberar
   mesa".
   **Verificar**: rechazo explícito; la respuesta lista esa orden abierta para que el
   cajero la cobre o cancele.
4. Dejar una mesa ocupada sin actividad por varias horas (o adelantar el reloj en un entorno
   de prueba).
   **Verificar**: la mesa sigue `'ocupada'` indefinidamente; la Terminal muestra el tiempo
   ocupado como dato informativo; ningún proceso automático la libera.

## Escenario 4 — Cancelar un pedido entregado sin cobrar (Historia 4)

1. Llevar una orden de domicilio a `'entregada'`+`'UNPAID'`; cancelarla con motivo
   "Cliente no contestó".
   **Verificar**: `status == 'cancelada'`, ítems `'cancelado'`, motivo registrado en
   `order_cancel_logs`, ningún movimiento de caja generado.
2. Repetir con una orden `'entregada'`+`'UNPAID'` pero sin indicar motivo.
   **Verificar**: rechazo explícito, "el motivo es obligatorio".
3. Repetir con una orden `'entregada'`+`'PAID'`.
   **Verificar**: rechazo explícito, "requiere proceso de reembolso, fuera de alcance".
4. Sobre la orden ya `'cancelada'` del paso 1, intentar entregarla o cobrarla.
   **Verificar**: ambas acciones rechazadas como transición inválida; ningún estado cambia.

## Verificación de la migración de datos (SC-007)

Sobre una copia de datos previa a la migración (o un esquema de tenant de prueba con filas
en los estados antiguos: `abierta`, `bloqueada`, `pagada`, `PARTIAL`, `en_preparacion`,
`listo`, `anulado`):

1. Aplicar la migración.
2. Ejecutar el `SELECT` de control descrito en `data-model.md` ("Verificación
   post-migración") sobre `customer_orders` y `order_items`.
   **Verificar**: `count(*) == 0` en ambos casos — ningún registro fuera del conjunto final
   de estados.
3. Elegir una fila que antes era `status='bloqueada'` con un ítem que antes era
   `estado_cocina='pendiente'`.
   **Verificar**: tras la migración, `status == 'entregada'` y ese ítem quedó forzado a
   `'entregado'` (FR-023 in fine), no en `'pendiente'`.

## Regresión a vigilar

- Characterization tests existentes sobre `orders`/`table_sessions`/`checkout` que citen
  `abierta`, `bloqueada`, `pagada`, `PARTIAL`, `en_preparacion`, `listo` o `anulado` — deben
  actualizarse explícitamente citando este spec (Principio III), nunca quedar en rojo sin
  decisión, ni editarse en silencio.
- Frontend: `order-status.util.ts` (`KNOWN_ORDER_STATUSES`, clases de color) y
  `dining.interface.ts` (`DiningOrderStatus`, `KitchenStatus`, `OrderPaymentStatus`) deben
  reflejar exactamente los nuevos conjuntos de valores — un valor viejo que quede en la
  lista de "conocidos" no rompe nada visiblemente, pero contradice FR-013 si el backend ya
  no puede emitirlo nunca.
