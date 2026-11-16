# Quickstart: Validar Compra Sugerida de Insumos

Guía para comprobar manualmente los tres escenarios de aceptación principales del spec,
una vez implementado. No sustituye los tests automatizados (characterization tests del
backend + specs de Angular del frontend) — es la verificación de extremo a extremo.

## Prerrequisitos

- `pos-backend` corriendo contra PostgreSQL local (ver memoria de este proyecto: servidor en
  `localhost:5432`, `DATABASE_URL` de `pos-backend/.env`) con las migraciones al día,
  incluida la nueva `purchase_generation_requests`:
  ```bash
  cd ../pos-backend && ./env/bin/python -m alembic upgrade head
  ```
- `pos-heladeria` corriendo contra ese mismo backend (`npm start`/`ng serve`).
- Un tenant con el módulo `inventario` habilitado en su plan, y un usuario `ADMIN` de ese
  tenant.
- Datos mínimos (vía la propia pantalla de inventario/proveedores, o seed existente):
  - Insumo **ALMENDRAS**: `current_stock=10 g`, `min_stock=500 g`; proveedor preferido
    **AGRO SUR** con presentación "Bolsa x 500 g" a $8.000.
  - Insumo **AGUA BOLSA X 300 ML**: bajo mínimo, **sin** `SupplierItem` preferido activo.
  - Un proveedor alternativo configurado para ALMENDRAS (para el escenario de la Historia 3).

## Escenario 1 — Ver el sugerido (Historia 1, P1)

1. Ir a `inventario/compra-sugerida` como el usuario admin.
2. Verificar que ALMENDRAS aparece marcada, con AGRO SUR, cantidad `1`, equivalencia
   "= 500 g al inventario" y subtotal `$8.000` (acceptance scenario 1).
3. Verificar que AGUA BOLSA X 300 ML aparece desmarcada, con el aviso "Sin proveedor
   configurado. Elige uno.", el selector de unidad deshabilitado y subtotal vacío, y que no
   se puede marcar (acceptance scenario 2).
4. Dejar sin insumos bajo mínimo (ajustar stock por encima del mínimo en todos) y recargar:
   debe verse "No hay insumos bajo mínimo" y el botón de generar deshabilitado (acceptance
   scenario 3).
5. **Verificación de contrato**: `curl` autenticado a
   `GET /inventory/purchases/suggested?page=1&size=20` debe traer las mismas filas que la
   pantalla, ordenadas por déficit descendente.

## Escenario 2 — Generar órdenes agrupadas por proveedor (Historia 2, P1)

1. Con al menos 3 insumos marcados de 3 proveedores distintos, pulsar "Generar órdenes de
   compra".
2. Verificar que se crean exactamente 3 `Purchase` en `draft` (una por proveedor), cada una
   con sus insumos/cantidades/precios, y que la pantalla muestra la confirmación con enlace a
   cada una (acceptance scenario 1). Confirmar en la base de datos: `SELECT supplier_id, status FROM tenant.purchases ORDER BY purchased_at DESC LIMIT 5;`.
3. Forzar una línea inválida (precio `0` o cantidad `< 1` editando a mano) y volver a
   generar: verificar que no se crea ninguna orden nueva y que la fila con el error queda
   resaltada con su mensaje (acceptance scenario 2).
4. Simular un fallo de servidor en la creación de una de las órdenes del lote (p. ej.
   desactivando temporalmente el `SupplierItem` de una de las líneas entre que se abrió la
   pantalla y se generó): verificar que no queda ninguna orden parcial creada y que los
   ajustes en pantalla se conservan (acceptance scenario 3).
5. Reenviar la misma solicitud de generación (doble clic, o repetir la llamada con la misma
   `idempotency_key` capturada en la pestaña de red): verificar que no se duplican órdenes —
   debe devolver las mismas `Purchase` ya creadas (SC-005). Confirmar:
   `SELECT COUNT(*) FROM tenant.purchase_generation_requests WHERE idempotency_key = '<key>';`
   debe ser `1`.

## Escenario 3 — Ajustar cantidad y proveedor antes de generar (Historia 3, P2)

1. Con ALMENDRAS en cantidad `1` a `$8.000`, subir la cantidad a `6`: verificar que el
   subtotal pasa a `$48.000`, la equivalencia cambia a "= 3.000 g al inventario" y el total
   estimado del resumen se actualiza, todo sin recargar la pantalla (acceptance scenario 1).
2. Abrir el selector de proveedor de ALMENDRAS y elegir el proveedor alternativo
   configurado: verificar que se cargan la unidad de compra y el precio de ese proveedor, la
   cantidad se conserva, y que el subtotal, el contador de proveedores y el contador de
   órdenes a generar se actualizan (acceptance scenario 2). Verificar en la pestaña de red
   que este paso dispara `GET /inventory/items/{id}/suppliers` solo al abrir el selector, no
   antes.

## Qué NO verifica este quickstart

- No prueba paginación con 50+ filas bajo mínimo ni concurrencia entre dos sesiones distintas
  (edge cases cubiertos por los characterization tests y tests de integración del backend,
  no por una pasada manual).
- No prueba que `SupplierItem.last_cost` permanece sin cambios tras editar el precio en
  pantalla (FR-007) — eso se verifica con
  `SELECT last_cost FROM tenant.supplier_items WHERE id = '<supplier_item_id>';` antes y
  después de generar, comparando que no cambió aunque el precio de la línea generada sí
  haya sido distinto.
