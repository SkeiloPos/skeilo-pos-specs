# Quickstart: validar Cobro de pedido con múltiples métodos de pago

Guía de validación manual/automática de extremo a extremo, una vez implementado. No incluye código
de implementación — ver `data-model.md` y `contracts/api.md` para el detalle de lo que cada paso
ejercita.

## Prerrequisitos

- `pos-backend` corriendo contra PostgreSQL local (`DATABASE_URL` de `.env`, ver memoria de
  sesión "cómo correr los tests de los repos hermanos" — hay servidor local en `:5432`).
- `pos-heladeria` (`npx ng serve`) apuntando a ese backend.
- Un tenant con al menos 2 métodos de pago activos y disponibles: uno `is_cash=true` (Efectivo) y
  uno de tipo `transfer` (p. ej. "Transferencia Nequi") — spec 032, `GET /sales/payment-methods?available=true`.
- Un turno de caja abierto (`CashShift.status = 'open'`).

## Escenario 1 — Pago mixto en los tres tipos de pedido (Historia 1, Esquema de escenario)

Para cada tipo (Mesa, Para llevar, Domicilio):

1. Crear/abrir un pedido con un total conocido (si es Domicilio, incluir costo de envío para
   ejercitar también el Escenario 2 de la spec).
2. Abrir el panel "Cobrar pedido". Elegir "Efectivo", verificar que la línea se precarga con el
   total completo (FR-014).
3. Pulsar "Agregar otro método". Verificar que aparece una segunda línea precargada con el saldo
   pendiente (RN3, escenario "Pago mixto... camino feliz").
4. En la segunda línea, elegir "Transferencia" y ajustar el monto si corresponde.
5. Verificar que "Cobrar" se habilita solo cuando `Σ asignado == total` (probar primero con un
   monto que falte → "Faltan $[monto] por asignar" y botón deshabilitado).
6. Pulsar "Cobrar". Verificar: pedido en estado "Pagado"; `GET` del pedido/venta muestra 2 filas en
   `payments` cuya suma es el total; comprobante muestra el desglose por método (Historia 4).

**Verificación automatizada equivalente**: nuevo test en `pos-backend/app/scripts/` (mismo patrón
que `test_cash_net_sales.py`, spec 108) que llama `build_sale` con 2 `PaymentIn` (efectivo +
transferencia) y verifica 2 filas `Payment` persistidas sumando el total, para los tres `order_type`.

## Escenario 2 — Domicilio: el total incluye el envío

1. Crear un pedido Domicilio con productos por $14.000 y envío de $3.000 (total $17.000).
2. Asignar Efectivo $10.000 + Transferencia $4.000 (suma $14.000, falta el envío).
3. Verificar "Faltan $3.000 por asignar" y "Cobrar" deshabilitado.
4. Completar a $17.000 y verificar que cobra correctamente.

## Escenario 3 — Mesa: pago mixto libera la mesa

1. Cobrar un pedido de Mesa con Efectivo + Transferencia (Escenario 1).
2. Volver a la pestaña "Mesas" de la terminal. Verificar que la mesa aparece "Libre" y que el
   contador de "Ocupadas" bajó en 1 (RN12/FR-018; en backend, `release_table` ya no depende de
   ningún campo de método único — ver `research.md`).

## Escenario 4 — Domicilio despachado sigue "Sin cobrar"

1. Llevar un pedido de Domicilio a su estado operativo más avanzado sin registrar ningún pago.
2. Verificar que aparece "Sin cobrar" en la pestaña de Domicilios y que el cierre de caja del
   turno no incluye su monto (FR-017; ya satisfecho por diseño — `research.md` D6).

## Escenario 5 — Vuelto solo sobre la porción en efectivo

1. Con un pedido de total $14.000, asignar Transferencia $6.000 y Efectivo $8.000.
2. En la línea de Efectivo, escribir "Con cuánto paga": $10.000.
3. Verificar "Cambio: $2.000" (solo sobre esa línea).
4. Cobrar. Abrir el cierre de caja del turno: verificar que la fila de Efectivo del turno
   incrementó en $8.000 (neto), no en $10.000 (FR-008; `reconcile` ya neta el cambio — spec 108).

**Verificación automatizada equivalente**: extender el script de arqueo neto (spec 108) con un caso
de venta con 2 `Payment` (uno efectivo con `amount` > su "asignado" implícito, uno transferencia) y
verificar que `sales_by_method` para `cash` refleja el neto.

## Escenario 6 — Validaciones de montos (suma insuficiente, transferencia excede saldo, eliminar línea)

1. Asignar Efectivo $8.000 + Transferencia $4.000 (total $14.000) → "Faltan $2.000 por asignar",
   "Cobrar" deshabilitado.
2. Reiniciar; asignar Efectivo $8.000, luego Transferencia $9.000 → error "La transferencia no
   puede superar el saldo pendiente ($6.000)", "Cobrar" deshabilitado.
3. Con 2 líneas ya asignadas, eliminar la de Transferencia → ver "Faltan $6.000 por asignar"
   recalculado de inmediato.

## Escenario 7 — Un solo método sigue igual de rápido (Historia 2)

1. Abrir el panel, elegir "Efectivo" sin agregar otro método.
2. Verificar que la línea se precarga con el total y que "Cobrar" registra un único pago — mismo
   número de pasos que antes del cambio (SC-003).

## Escenario 8 — Falla del servidor no deja pagos parciales

1. Asignar Efectivo $8.000 + Transferencia $6.000. Provocar un error del servidor al cobrar
   (p. ej. turno cerrado entre la carga del panel y el clic, o un método inactivo).
2. Verificar: el pedido sigue "Sin cobrar"; no quedó ninguna fila `Payment` para ese pedido; las
   dos líneas siguen visibles en el panel para reintentar sin volver a escribirlas (FR-009).

## Suites a correr antes de cerrar la implementación

```bash
# pos-backend (baseline 2026-10-03: 1290 OK)
cd ../pos-backend && ./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'
./env/bin/python app/scripts/test_<nombre_del_script_nuevo_de_esta_spec>.py

# pos-heladeria (comparar contra la baseline de 19 fallos/6 archivos no relacionados)
cd ../pos-heladeria && npx ng test --watch=false --include='src/app/modules/tables/**/*.spec.ts'
```
