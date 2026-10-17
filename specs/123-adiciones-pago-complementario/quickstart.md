# Quickstart — Validación de Spec 123

**Spec**: [spec.md](./spec.md) · **Contratos**: [contracts/](./contracts/) · **Modelo**:
[data-model.md](./data-model.md)

Guía de validación end-to-end — no de implementación. Cada escenario referencia el FR que prueba.

## Prerrequisitos

- `pos-backend`: entorno con venv activo, migraciones aplicadas sobre un esquema de tenant de
  prueba (`alembic upgrade head`, incluida la migración de esta spec — ver `data-model.md`).
- Tenant de prueba con: un turno de caja abierto, al menos un producto con un grupo de opciones
  que tenga insumo con stock, y un segundo tenant (o el mismo con el plan temporalmente ajustado)
  **sin** el módulo de inventario habilitado, para el escenario de gating (FR-021).
- `pos-heladeria`: Terminal POS corriendo contra ese backend, con una mesa con un pedido activo.

## Backend — tests automatizados

```bash
cd ../pos-backend
python -m unittest discover -s app/characterization_tests -p 'test_*.py'
```

Deben pasar, sin modificaciones, todos los tests existentes de `test_orders_kitchen.py`,
`test_orders_checkout.py`, `test_cart_service.py` (dominio greenfield, confirmado en
`research.md`), y los nuevos de `test_orders_additions.py` /
`test_sales_complementary_payment.py` /las ampliaciones de `test_table_sessions_service.py` y
`test_plan_module_access.py`.

## Frontend — tests automatizados

```bash
cd ../pos-heladeria
npx ng test --watch=false
```

Deben pasar los `.spec.ts` existentes y los nuevos de `pos-order-panel.component.spec.ts`,
`pos-checkout-panel.component.spec.ts`, `pos-terminal.store.spec.ts`,
`table-session.service.spec.ts`.

## Escenario 1 — Agregar adición a un pedido sin pagar (Historia 1, FR-001/004/005)

1. Abrir un pedido de mesa con una línea "Pendiente" sin adiciones.
2. Cajero: "Agregar adición" en esa línea → elegir una opción con precio conocido, cantidad 1,
   confirmar.
3. **Esperado**: la línea muestra la adición; el total del pedido sube exactamente por el precio
   de la adición; no aparece ningún "saldo pendiente"; si el tenant tiene el módulo de inventario
   habilitado, el insumo de la adición ya se descontó del stock en este paso (no al cobrar) y el
   insumo de la receta base del producto no cambió (`/speckit-analyze` G1/research.md D9).
4. Cobrar el pedido normalmente.
5. **Esperado**: el monto exigido es el total recalculado (incluida la adición).

## Escenario 2 — Agregar adición a un pedido ya pagado (Historia 2, FR-006/007)

1. Repetir el pedido del Escenario 1, pero cobrarlo **antes** de agregar la adición.
2. Cajero: "Agregar adición" en la misma línea (sigue "Pendiente"), elegir la opción, confirmar.
3. **Esperado**: la línea muestra la adición y su subtotal sube; el panel de cuenta muestra "Saldo
   pendiente: $[precio de la adición]"; aparece "Cobrar saldo".
4. Consultar la factura original ya emitida.
5. **Esperado**: su monto, líneas y representación son exactamente las de antes del paso 2
   (Principio VII).

## Escenario 3 — Cobrar el saldo pendiente (Historia 3, FR-010/011/012/013/014)

1. Continuar desde el Escenario 2. Cajero: "Cobrar saldo" → pagar en efectivo el monto exacto.
2. **Esperado**: se genera una factura independiente por ese monto, vinculada al pedido original;
   el insumo de la adición queda descontado del inventario; el pedido vuelve a mostrarse sin saldo
   pendiente.
3. Repetir: agregar una segunda adición al mismo pedido (otra línea, también "Pendiente") y cobrar
   de nuevo.
4. **Esperado** (FR-022): se genera una **segunda** factura complementaria, independiente de la
   primera y de la original — ninguna de las anteriores se modifica.

## Escenario 4 — Cobro complementario atómico con stock insuficiente (FR-020/021)

1. En un tenant **con** módulo de inventario habilitado: generar saldo pendiente con dos adiciones
   de insumos distintos sobre el mismo pedido ya pagado.
2. Antes de cobrar, bajar manualmente el stock de uno de los dos insumos por debajo de lo
   requerido.
3. Cajero: "Cobrar saldo".
4. **Esperado**: el sistema rechaza el cobro completo con "Stock insuficiente de [insumo]"; no se
   genera ninguna factura complementaria; el saldo pendiente sigue intacto; el insumo con stock
   suficiente tampoco se descuenta (todo o nada).
5. Repetir el mismo flujo completo (Escenarios 2-3) en un tenant **sin** el módulo de inventario
   habilitado, con el mismo insumo agotado.
6. **Esperado**: el cobro complementario se completa sin ningún chequeo ni descuento de stock
   (FR-021).

## Escenario 5 — Restricciones de estado y stock al agregar (Historia 4, FR-002/003/008/009)

1. Marcar una línea como "Listo". Cajero: revisar sus acciones.
2. **Esperado**: "Agregar adición" no está disponible; texto de ayuda "Producto ya preparado:
   agrega un producto nuevo".
3. En una línea "Pendiente", intentar agregar una adición cuyo insumo no tiene stock suficiente
   (tenant con módulo de inventario habilitado).
4. **Esperado**: rechazo con "Stock insuficiente de [insumo]"; la línea y el total del pedido
   quedan exactamente como antes del intento.

## Escenario 6 — Bloqueo de "Liberar Mesa" (Historia 5, FR-016)

1. Con un pedido en saldo pendiente (Escenario 2), cajero: "Liberar Mesa".
2. **Esperado**: rechazo con "Hay un saldo pendiente por cobrar".
3. Cobrar el saldo pendiente íntegramente (Escenario 3) y repetir "Liberar Mesa".
4. **Esperado**: la mesa se libera sin bloqueo.

## Escenario 7 — Tiempo real (Historia 6, FR-017)

1. Abrir la Terminal POS en dos sesiones de navegador distintas sobre la misma mesa/pedido.
2. En la sesión A, agregar una adición a una línea "Pendiente".
3. **Esperado**: la sesión B refleja la línea marcada como "Modificada" con la adición, sin
   recargar manualmente, en cuestión de segundos.
