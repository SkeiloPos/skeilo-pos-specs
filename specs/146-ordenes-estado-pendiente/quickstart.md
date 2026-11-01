# Quickstart: validar Estado inicial PENDIENTE para órdenes e ítems

**Feature**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md) · **Contrato**: [contracts/order-status-contract.md](./contracts/order-status-contract.md)

Guía de validación manual/semi-manual end-to-end, una vez implementada la funcionalidad. No
sustituye los characterization tests ni los tests de la nueva funcionalidad que generará
`/speckit-tasks` — es la comprobación de que el comportamiento funciona de punta a punta.

## Prerrequisitos

- `pos-backend`: entorno local con Postgres 16 disponible (ver memoria del proyecto: "local
  Postgres IS available"), venv del proyecto activo, `alembic upgrade head` corrido contra una
  base con datos de prueba que incluya al menos una orden en `status = 'recibida'` en más de un
  esquema de tenant (crear un tenant de prueba si no existe uno con datos).
- `pos-heladeria`: entorno local corriendo contra ese mismo backend.

## Escenario 1 — Toda orden nueva nace en PENDIENTE (User Story 1, P1)

1. Crear una orden por cada canal (QR, caja/mostrador, domicilio) con 2-3 ítems cada una, sin
   confirmar pago en la creación.
2. Para cada orden creada, verificar vía API (`GET` del detalle de la orden) que:
   - `status == "pendiente"`
   - `payment_status == "UNPAID"`
   - todos los ítems tienen `estado_cocina == "pendiente"`
3. Repetir el paso 1 para una venta de mostrador pagada de inmediato (caja). Verificar que
   `status == "pendiente"` igual, pero `payment_status == "PAID"` (o `"PARTIAL"` si se simula un
   pago mixto).
4. Abrir la Terminal de Mesas y confirmar que la orden aparece etiquetada como "Pendiente"
   (valor crudo, sin traducción a otro término).

**Resultado esperado**: SC-001, SC-002 satisfechos — 100% de las órdenes/ítems nuevos en
`pendiente`/`UNPAID` salvo pago confirmado en creación.

## Escenario 2 — Migración y eliminación de `recibida` (User Story 2, P1)

1. Antes de la migración (en un snapshot/branch de base de datos de prueba), confirmar que
   existen filas con `status = 'recibida'` en al menos dos esquemas de tenant distintos.
2. Correr `alembic upgrade head`.
3. Verificar, por cada esquema (incluido `tenant_default`):
   - `SELECT count(*) FROM customer_order WHERE status = 'recibida'` devuelve `0`.
   - Las órdenes que antes tenían `'recibida'` ahora tienen `status = 'pendiente'`, con el resto
     de sus columnas (ítems, montos, canal) sin cambios.
4. Intentar un `UPDATE customer_order SET status = 'recibida' WHERE id = <alguna_orden>`
   directamente en SQL. Verificar que la base de datos lo rechaza por el `CHECK constraint`
   (FR-007).
5. En un tenant sin ninguna orden `'recibida'` previa, confirmar que ningún otro dato cambió
   tras la migración salvo la definición del `CHECK constraint`.

**Resultado esperado**: SC-003 satisfecho — 0% de registros con `'recibida'` tras la migración,
en cualquier esquema.

## Escenario 3 — Frontend muestra el valor crudo, sin traducir ni inferir (User Story 3, P2)

1. Con la API ya migrada, abrir el detalle de un pedido en estado `pendiente` y verificar que
   la etiqueta mostrada corresponde exactamente a ese valor (ver contrato para la etiqueta
   esperada), sin inferencia basada en `payment_status`.
2. Simular (mock de red o interceptor temporal) que la API devuelve un `status` no mapeado por
   el frontend (p. ej. `"en_revision"`). Verificar que:
   - la pantalla muestra ese valor crudo (`"en_revision"`), no un estado por defecto como "En
     preparación".
   - se registra un error en la consola del navegador.
3. Verificar que una orden con `payment_status = "PAID"` pero `status = "pendiente"` se sigue
   mostrando como "Pendiente" (no como "Pagada") en todas las pantallas que muestran estado de
   orden — confirma que se eliminó la inferencia por `order.paid`.
4. En el panel de mesas, verificar que la tarjeta de una orden individual muestra su `status`
   crudo, y que únicamente el indicador agregado de ocupación de la mesa (no el de una orden
   específica) puede seguir mostrando una categoría sintética distinta.

**Resultado esperado**: SC-004, SC-005 satisfechos.

## Verificación automatizada mínima esperada (referencia para `/speckit-tasks`)

- Backend: characterization tests actualizados/nuevos en `app/characterization_tests/` para
  creación (todo canal → `pendiente`/`UNPAID` salvo pago inmediato), migración (idempotencia,
  cobertura multi-esquema, rechazo de `'recibida'` tras migrar), y el invariante ya existente de
  ítems en `pendiente`.
- Frontend: specs unitarios en `order-status.util.spec.ts` (detección de no-mapeado +
  `console.error`, eliminación de `displayOrderStatus`) y actualización de fixtures `'recibida'`
  → `'pendiente'` en los specs listados en `research.md` sección 8.
