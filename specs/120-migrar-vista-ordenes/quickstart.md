# Quickstart: Migrar vista del módulo de Órdenes al nuevo diseño

**Spec**: [spec.md](./spec.md) · **Contrato**: [contracts/orders-list-api.md](./contracts/orders-list-api.md)

Guía para validar manualmente, de punta a punta, que la vista migrada cumple los escenarios de aceptación del spec.

## Prerrequisitos

- `pos-backend` corriendo localmente con la rama de esta feature (API extendida, ver `contracts/orders-list-api.md`) y al menos un tenant con órdenes de distintos tipos (`DINE_IN`, `TAKEAWAY`, `DELIVERY`), estados (`recibida`, `abierta`, `pagada`, `cancelada`) y fechas (hoy, ayer, un día anterior).
- `pos-heladeria` corriendo localmente con la rama de esta feature, apuntando a ese backend.
- Un usuario de sesión con rol `ADMIN`, `CASHIER` o `MESERO` (los mismos ya autorizados hoy para `/dashboard/orders`).

## Puesta en marcha

```bash
# Backend
cd ../pos-backend && <comando habitual de arranque del proyecto>

# Frontend
cd ../pos-heladeria && npm start
```

Entrar a `http://localhost:<puerto>/dashboard/orders`.

## Escenarios a validar (trazados a los Acceptance Scenarios del spec)

1. **Lista con tarjetas (US1-1)**: la pantalla muestra las órdenes de hoy como tarjetas, cada una con cliente, código de orden, hora, cantidad de ítems, ubicación/tipo, estado de pago y estado.
2. **Búsqueda (US1-2)**: escribir el nombre de un cliente conocido de otra página de resultados en el buscador y confirmar que aparece sin necesidad de paginar manualmente hasta encontrarlo; el conteo de resultados se actualiza.
3. **Filtros combinados (US1-3)**: elegir un estado y un tipo a la vez; confirmar que solo quedan órdenes que cumplen ambos.
4. **Filtro de fecha (US1-4)**: abrir el selector de fecha, elegir "Ayer"; confirmar que solo se listan órdenes de ese día y que no es posible seleccionar una fecha futura en el calendario.
5. **Estado vacío (US1-5)**: combinar filtros que no coincidan con ninguna orden (p. ej. un tipo + una fecha sin datos); confirmar el mensaje de "Sin órdenes".
6. **Paginación (US1-6)**: con más órdenes que el tamaño de página, cambiar el tamaño de página y navegar; confirmar que el rango mostrado ("X–Y de Z") es correcto, incluida la última página parcial.
7. **Detalle en mesa (US2-1)**: abrir una orden `DINE_IN`; confirmar los bloques de información de la orden (tipo, mesa, hora), cliente e información de factura (código, fecha/hora, método y estado de pago), sin bloque de domicilio.
8. **Detalle a domicilio (US2-2)**: abrir una orden `DELIVERY`; confirmar que además aparece el bloque de domicilio (teléfono, dirección).
9. **Ítems y totales (US2-3)**: confirmar que cada ítem muestra cantidad, precio unitario y subtotal, y que el desglose de totales (subtotal, domicilio si aplica, descuento, total, pagado) es consistente con lo ya calculado hoy por el sistema (sin inventar cifras).
10. **Volver conservando filtros (US2-4)**: desde la lista, aplicar un filtro, abrir una orden, volver con "Volver a órdenes"; confirmar que el filtro sigue aplicado.
11. **Omisión de datos ausentes (US2-5)**: abrir una orden sin identificación de cliente o sin pago aún registrado; confirmar que esas filas no aparecen (ni vacías, ni con guion, ni con "$0").
12. **Nueva orden (US3-1)**: presionar "Nueva orden" desde la lista; confirmar que lleva al flujo existente de creación de pedido manual.

## Validación del contrato de API (opcional, directa al backend)

```bash
curl -s "http://localhost:8000/api/v1/orders?date_from=$(date +%F)&date_to=$(date +%F)&q=<nombre-de-cliente-de-prueba>" \
  -H "Authorization: Bearer <token>" | jq '.total, .items | length'
```

Confirmar que `total` refleja todas las coincidencias del día (no solo las de una página), y que una llamada sin `date_from`/`date_to`/`q` sigue devolviendo exactamente lo mismo que antes de esta feature.
