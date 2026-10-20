# Quickstart — Validación de la spec 130

Guía de validación manual/automatizada. Para el detalle de contrato ver
[contracts/pago-mixto-comensal.md](./contracts/pago-mixto-comensal.md) y
[contracts/bloqueo-salida.md](./contracts/bloqueo-salida.md); para el modelo de datos,
[data-model.md](./data-model.md).

## Prerrequisitos

- `pos-backend` corriendo contra PostgreSQL local (ver memoria del proyecto: `localhost:5432`,
  `DATABASE_URL` de `.env`), migraciones de esta spec aplicadas (catálogo `type='mixed'`, columnas
  nuevas de `order_payment_attempts`).
- `pos-heladeria` corriendo (`ng serve` o equivalente) contra ese backend.
- Un tenant de prueba con: efectivo activo, al menos un método de transferencia activo (ej. Nequi),
  y "Pago mixto" habilitado en su catálogo (FR-004).
- Una mesa con su QR/enlace de sesión vigente.

## Escenario 1 — Rediseño visual sin cambio de comportamiento (Historia 1, SC-001)

1. Abrir el enlace de la mesa, completar bienvenida con un nombre.
2. Recorrer: menú (categorías, búsqueda, banner de promociones) → detalle de un producto con
   presentaciones y un grupo de opciones obligatorio → carrito → pestaña "Mis pedidos".
3. **Verificar**: la apariencia coincide con `design/Bienvenida QR v1.dc.html`; precios,
   promociones aplicadas, validaciones de grupos de opciones (mínimos/máximos/inventario) y
   mensajes de error son idénticos a los que produce hoy la versión sin rediseñar (comparar contra
   el comportamiento documentado en specs 007/004/025/032/034/128).
4. Recargar la página a mitad de la revisión y pago: el progreso se recupera igual que hoy (spec
   034), con la apariencia nueva.

## Escenario 2 — Pago mixto de punta a punta (Historia 2, SC-002)

1. Armar un carrito y llegar a "¿Cómo vas a pagar?".
2. Elegir "Pago mixto". Ingresar un monto en efectivo menor al total.
   - **Verificar FR-006**: ingresar un monto igual o mayor al total bloquea continuar, con mensaje
     orientando a elegir "Efectivo".
   - **Verificar FR-006 (edge case $0)**: ingresar `0` se trata como si se hubiera elegido
     transferencia directamente.
3. Si el tenant tiene más de un método de transferencia activo, elegir cuál recibe el resto
   (FR-005). Si tiene solo uno, el sistema lo usa sin preguntar.
4. Ver los datos de la transferencia (cuenta y/o QR) por el resto, etiquetados "más {monto} en
   efectivo al recibir el pedido" (FR-007). Subir el comprobante.
   - **Verificar Clarificación Q6**: volver al paso anterior y cambiar el monto en efectivo →
     el comprobante ya subido se invalida y hay que volver a cargarlo antes de poder enviar.
5. Enviar el pedido. **Verificar FR-008**: la confirmación y "Mis pedidos" muestran el desglose
   (efectivo pendiente al recibir + transferencia en verificación).
6. (Backend/Terminal) Confirmar la porción en efectivo (`confirm-cash`) y luego aprobar el
   comprobante (`approve`), en cualquier orden. **Verificar**: la orden solo avanza a cocina
   cuando **ambas** confirmaciones existen (research.md Decisión 4).

## Escenario 3 — Activación de "Pago mixto" en el catálogo del tenant (FR-004)

1. En un tenant sin transferencia activa, intentar activar "Pago mixto" → rechazado.
2. Activar un método de transferencia, reintentar → sigue rechazado si falta efectivo activo.
3. Con efectivo y transferencia ya activos, activar "Pago mixto" → aceptado; aparece en
   `GET /cart/payment-methods` del Menú QR de ese tenant.

## Escenario 4 — Bloqueo de "Salir" con pago pendiente (Historia 3, SC-003)

1. Enviar un pedido en efectivo (sin confirmar el cobro en caja). Pulsar "Salir".
   - **Verificar**: aparece el aviso de pago pendiente; la sesión sigue activa (recargar la página
     con el mismo enlace y confirmar que el comensal sigue "adentro", no en la pantalla de
     bienvenida).
2. (Backend/Terminal) Confirmar el cobro en caja de ese pedido. Pulsar "Salir" de nuevo.
   - **Verificar**: ahora se permite salir con normalidad, pantalla de despedida.
3. Repetir 1-2 con un pedido 100% por transferencia (bloquea mientras el comprobante esté en
   verificación; permite salir una vez aprobado) — cubre la inconsistencia corregida por
   Clarificación Q1 frente al diseño de referencia.
4. Repetir con un pedido de pago mixto: bloquea si falta **cualquiera** de las dos confirmaciones;
   permite salir solo cuando ambas existen.
5. Con dos comensales en la misma mesa (Ana y Luis): Luis envía un pedido en efectivo sin cobrar;
   Ana no tiene pedidos propios. **Verificar Clarificación Q2**: Ana puede salir con normalidad;
   Luis queda bloqueado. La mesa sigue `ocupada` mientras Luis no cumpla `RN-CART-15` (FR-012).
6. Un comensal sin ningún pedido enviado (solo carrito) pulsa "Salir" → se permite con normalidad.

## Escenario 5 — Toppings como checkbox, mismo comportamiento (Historia 4, SC-004)

1. Abrir el detalle de un producto con un grupo de opciones obligatorio (mínimo/máximo definidos).
2. Intentar continuar sin cumplir la regla → se bloquea con el mismo mensaje de siempre, sobre el
   nuevo estilo visual de checkbox.
3. Seleccionar una combinación válida de toppings, agregar al carrito, enviar el pedido.
   **Verificar**: el carrito, la revisión y "Mis pedidos" muestran exactamente la misma
   información de toppings que mostraban antes del rediseño — solo cambia el estilo.

## Verificación automatizada

- **Backend**: `cd ../pos-backend && ./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`
  — confirmar baseline en verde antes de empezar, y de nuevo al final (sin regresiones no
  autorizadas, Principio III/X). Tests nuevos esperados: validación de `cash_amount`/
  `transfer_method_id` en `submit_cart`, el gate extendido de `_confirm_order_impl` para intentos
  mixtos, la validación de activación de "Pago mixto" en el catálogo por tenant, y el nuevo `409`
  de `POST /cart/leave`.
- **Frontend**: `npx ng test --watch=false --include='src/app/modules/tables/**/*.spec.ts'` (y el
  módulo de administración de métodos de pago si aplica) — comparar contra la baseline de
  fallos preexistentes documentada en la memoria del proyecto antes de atribuir cualquier fallo
  nuevo a esta spec.
