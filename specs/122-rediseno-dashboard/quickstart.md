# Quickstart: Rediseño del módulo Dashboard según el prototipo

**Spec**: [spec.md](spec.md) · **Contratos**: [contracts/payment-methods-report-api.md](contracts/payment-methods-report-api.md), [contracts/session-name-claim.md](contracts/session-name-claim.md)

Guía de validación manual end-to-end para las 5 historias de usuario. Complementa, no sustituye, los tests automatizados.

## Prerrequisitos

- `pos-backend` corriendo localmente contra PostgreSQL (memoria del proyecto: `DATABASE_URL` ya apunta a `localhost:5432`, tenant `heladeria` sembrado).
- `pos-heladeria` corriendo localmente apuntando a ese backend.
- Un usuario de staff con `User.name` configurado (para ver el saludo con nombre real) y permisos de administrador del tenant.
- Datos de un turno con ventas en al menos 2 métodos de pago distintos (uno en efectivo, uno en otro método), para ejercitar "Ingresos por método de pago".
- Al menos un insumo con `current_stock <= min_stock` en Inventario, para ver "Stock bajo".

## 1. Saludo, accesos rápidos e indicadores (US1)

1. Cerrar sesión y volver a iniciarla con el usuario que tiene `name` configurado.
2. Entrar al Dashboard: el saludo debe decir "Buenos días"/"Buenas tardes"/"Buenas noches" según la hora real, seguido del nombre real del usuario (no un nombre derivado del correo) y el subtítulo "Esto es lo que pasa hoy en tu negocio.".
3. Verificar que los accesos rápidos (Terminal de mesas, Ventas, Gestión de caja, Carta del menú, Mesas) aparecen inmediatamente debajo del saludo, antes del reporte operativo.
4. Verificar la fila de 4 indicadores (Ventas, Órdenes, Ticket promedio, Órdenes activas) con el selector de período ya existente; cambiar de período y confirmar que los 4 se actualizan.
5. Confirmar que las tarjetas "Usuarios"/"Productos" y la lista "Órdenes recientes" siguen presentes en algún punto de la página (FR-009).

## 2. Tendencia reciente (US2)

1. En el panel "Estadísticas de ventas", confirmar que aparece el total de "Ventas" en grande con un gráfico de barras día a día.
2. Pasar el cursor sobre una barra: debe aparecer su fecha y su valor exacto (tooltip de Chart.js).
3. Alternar a "Órdenes" y a "Ticket promedio": el total grande y el gráfico deben cambiar a esa métrica.
4. Cambiar el período del reporte operativo (Historia 1) y confirmar que este panel **no** cambia — son independientes (research.md §3).

## 3. Más vendidos y ventas por categoría (US3)

1. En "Más vendidos", alternar entre "cantidad" e "ingresos": el orden y las barras deben recalcularse.
2. Confirmar que "Ventas por categoría" muestra el reparto con porcentaje de participación por categoría.

## 4. Ingresos por método de pago (US4)

1. Con el período en "Turno actual", confirmar que la sección muestra el total por método de pago y un gráfico con barras por hora.
2. Cambiar el período a "Semana": el gráfico debe recalcularse con barras por día.
3. Cambiar el período a "Mes": el gráfico debe recalcularse con barras por semana.
4. Desactivar un método de pago en los filtros/chips: debe desaparecer del total y del gráfico, dejando los demás visibles.
5. **Verificación de red (opcional, DevTools)**: confirmar que `GET /cash/reports/payment-methods?period=...` devuelve `bucket_unit` acorde al período (contracts/payment-methods-report-api.md) y que un pago dividido entre dos métodos aparece correctamente repartido (no duplicado ni atribuido a un solo método).

## 5. Stock bajo (US5)

1. Confirmar que la sección "Stock bajo" lista los insumos con `current_stock <= min_stock`, con su cantidad restante.
2. Presionar "Ver inventario": debe llevar al módulo de Inventario.
3. Llevar todos los insumos por encima de su mínimo y recargar: la sección debe indicar que no hay alertas, sin mostrar una lista vacía confusa.

## 6. Regresión (SC-005)

- El selector de período del reporte operativo sigue funcionando igual que antes (día/semana/mes/turno/rango).
- Los accesos rápidos siguen navegando a los mismos módulos.
- Las tarjetas "Usuarios"/"Productos" y "Órdenes recientes" siguen mostrando los mismos datos y enlaces que antes del rediseño.
- Un usuario con un token emitido **antes** de este cambio (sesión vieja, sin refrescar) sigue pudiendo usar el Dashboard; el saludo usa el nombre derivado del correo hasta su próximo login/refresh (contracts/session-name-claim.md).
