# Quickstart: Correcciones visuales y funcionales de la lista de Órdenes

**Spec**: [spec.md](spec.md) · **Contrato**: [contracts/orders-total-field.md](contracts/orders-total-field.md)

Guía de validación manual end-to-end para las 4 historias de usuario. No sustituye los tests automatizados (characterization del backend + specs de Angular); es la forma de comprobar, en la app real, que cada corrección se ve y se comporta como el spec exige.

## Prerrequisitos

- `pos-backend` corriendo localmente contra PostgreSQL (ver memoria del proyecto: `DATABASE_URL` ya apunta a `localhost:5432`, tenant `heladeria` ya sembrado).
- `pos-heladeria` corriendo localmente (`ng serve` o equivalente) apuntando a ese backend.
- Un usuario de staff con sesión iniciada, y al menos un tenant con:
  - Una orden **pagada con factura propia** (mostrador o QR ya cobrado), con descuento o domicilio aplicado si es posible (para ejercitar la fórmula completa del total).
  - Más de una página de órdenes del día (suficientes para que el paginador tenga más de una página con el tamaño por página más pequeño disponible).

## 1. Total en la tarjeta (US1)

1. Abrir el módulo de Órdenes.
2. Verificar que **cada tarjeta** de la lista muestra un monto total.
3. Abrir el detalle de una orden con descuento o domicilio aplicado y anotar su total.
4. Volver a la lista y comparar: el total de la tarjeta de esa misma orden **debe coincidir exactamente** con el del detalle (contrato: [`orders-total-field.md`](contracts/orders-total-field.md)).
5. Crear o localizar una orden recién creada sin ítems todavía: su tarjeta debe mostrar `$0`, no un espacio en blanco ni un guion.

**Verificación de red (opcional, DevTools)**: en la respuesta de `GET /orders?page=...`, cada elemento de `items` debe traer `total` poblado (no `null`); `billing` debe seguir viajando `null` en esa misma respuesta (no se esperan cambios ahí).

## 2. Filtro de fecha (US2)

1. Con el filtro de fecha mostrando "Hoy", abrir el calendario y elegir un día pasado (no "Ayer").
2. Cerrar el calendario (clic afuera) sin tocar nada más: el campo del filtro debe mostrar esa fecha elegida (p. ej. "14 oct 2026"), **no** "Hoy".
3. Esperar a que la lista recargue con los resultados de esa fecha: el campo debe seguir mostrando la misma fecha (no debe "saltar" de vuelta a "Hoy").
4. Volver a abrir el calendario y presionar el atajo "Hoy": el campo debe volver a mostrar "Hoy" y la lista debe mostrar las órdenes del día actual.
5. Repetir el paso 1 usando el atajo "Ayer" en vez del calendario: mismo resultado esperado.

## 3. Paginador (US3)

1. Con más órdenes del día que las que caben en una página, verificar que al pie de la lista aparece un paginador con: selector de cantidad por página, el rango visible y el total ("X–Y de Z"), y controles de anterior/siguiente.
2. Cambiar la cantidad de órdenes por página: el rango mostrado y las tarjetas deben actualizarse de forma consistente.
3. Navegar a la página siguiente y luego a la anterior: el rango avanza/retrocede correctamente; el control "anterior" se deshabilita en la página 1 y "siguiente" en la última página.
4. Si el total de resultados no es múltiplo del tamaño de página, verificar que la última página muestra el rango correcto (p. ej. "9–10 de 10", no "9–12 de 10").
5. Confirmar que **otras pantallas** que usan paginación (p. ej. Ventas, Inventario, Productos) siguen mostrando su paginador de siempre, sin cambios visuales (este paginador es exclusivo de Órdenes — ver [research.md §3](research.md#3-paginador-ausente-en-el-diseño-esperado-us3-fr-005fr-006)).

## 4. Badges redondeados (US4)

1. En cualquier tarjeta de la lista, comparar visualmente la etiqueta de estado de pago ("Pagado"/"Pendiente") y la etiqueta de estado de la orden (p. ej. "Pagada", "Preparando") contra el diseño de referencia: ambas deben verse como píldoras de esquinas completamente redondeadas.
2. Repetir la comparación con un estado de texto más largo (p. ej. "En preparación" o "Por confirmar"): debe conservar la forma de píldora, sin aplanarse en un rectángulo de esquinas apenas curvas.

## 5. Regresión (SC-005)

Antes de dar por cerrada la spec, confirmar que lo que ya funcionaba sigue funcionando:

- Filtros de estado, tipo y búsqueda, solos y combinados entre sí y con el filtro de fecha.
- Clic en una tarjeta → abre el detalle de esa orden.
- Botón "Volver a órdenes" desde el detalle → regresa a la lista con los mismos filtros que tenía antes.
- Botón "Nueva orden" → lleva al flujo de creación manual existente.
