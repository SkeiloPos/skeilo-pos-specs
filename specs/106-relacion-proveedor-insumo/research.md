# Research: Gestión de la relación proveedor–insumo

Todas las "unknowns" del Technical Context del plan se resolvieron por inspección directa del
código de `pos-backend`/`pos-heladeria` (no quedó ningún `NEEDS CLARIFICATION` abierto), así que
este documento registra **decisiones de diseño**, no incertidumbre de tecnología.

## D1 — Dónde vive la lógica nueva en el backend

**Decision**: la lógica de negocio de `SupplierItem` (crear/reactivar, candado de preferido,
exclusión de proveedor de sistema, bloqueo del factor usado-en-compra) va en un archivo nuevo
`app/api/v1/inventory/supplier_items.py`, importado por `router.py`, que solo agrega las rutas
(`@router.get/post/patch`) y delega.

**Rationale**: `app/api/v1/inventory/` ya es **un solo router** (`router.py`) que importa
funciones de archivos hermanos para mantener cada pieza de dominio separada sin crear un router
nuevo — `stock.py` es una fachada del motor de inventario (specs 018), `export.py` concentra la
construcción del Excel. La relación proveedor-insumo es un sub-recurso tanto de `/inventory/items`
como de `/inventory/suppliers`, ambos ya servidos por este mismo router; seguir el patrón
existente evita crear un segundo router para un dominio que ya vive aquí (Principio V: sin
refactors oportunistas).

**Alternatives considered**: (a) un router nuevo bajo `/supplier-items` — rechazado, fragmenta un
dominio que el propio código ya trata como una sola unidad (`inventory`); (b) meter la lógica
directamente en `service.py` — rechazado, `service.py` ya es largo y mezclar la lógica nueva ahí
dificulta ubicarla; un archivo propio (como ya hacen `stock.py`/`export.py`) la mantiene legible.

## D2 — Mutex del preferido (RN-16)

**Decision**: antes de desmarcar el preferido anterior y marcar el nuevo, se bloquea la fila del
`InventoryItem` padre con `SELECT ... FOR UPDATE`, reutilizando literalmente el helper
`lock_items` de `app/inventory_engine/stock.py` (ya usado por `record_movement`/
`apply_adjustment`). Orden dentro de la transacción: (1) `lock_items(db, [inventory_item_id])`,
(2) `UPDATE supplier_items SET preferred=false WHERE inventory_item_id=... AND preferred`, (3)
`UPDATE supplier_items SET preferred=true WHERE id=<relation_id>`, (4) `commit`.

**Rationale**: es exactamente la nota técnica original del enunciado ("el índice parcial no puede
ser DEFERRABLE... si se invierte el orden, salta la violación") y coincide con un patrón ya
probado en el propio repositorio (`lock_items`), así que no hace falta inventar nada nuevo —
bloquear el insumo (no la relación) es lo que serializa a dos administradores marcando
proveedores distintos como preferidos al mismo tiempo (Historia 2, escenario 1).

**Alternatives considered**: (a) `SELECT ... FOR UPDATE` directamente sobre las filas de
`supplier_items` del insumo — rechazado, no evita que dos transacciones concurrentes inserten
cada una su propio "preferido" sin verse (el candado tiene que estar en algo que ambas toquen
antes de decidir, el insumo); (b) usar únicamente el índice parcial sin candado explícito,
confiando en que la segunda transacción falle y reintente — rechazado, el enunciado exige que el
swap sea atómico y visible como "la anterior deja de serlo", no un 409 que el cliente deba
reintentar a ciegas.

## D3 — Unicidad insensible a mayúsculas/espacios (FR-003)

**Decision**: índice único por expresión sobre `(supplier_id, inventory_item_id,
lower(trim(presentation)))`, vía `op.create_index(..., unique=True)` con una columna de expresión
(`sa.text("lower(trim(presentation))")`), no una `UniqueConstraint` sobre la columna cruda.

**Rationale**: una `UniqueConstraint` solo compara el valor exacto almacenado; "Bolsa x 500 g" y
"bolsa x 500 g " deben colisionar como la misma presentación (FR-003/FR-004), lo que solo un
índice por expresión garantiza a nivel de base de datos (y no solo en el servicio, que podría
saltarse por una vía de escritura distinta).

**Alternatives considered**: (a) normalizar `presentation` a minúsculas antes de guardar y mostrar
siempre así — rechazado, pierde la capitalización que el administrador escribió ("Bolsa x 500 g"
se mostraría "bolsa x 500 g"), degradando la UX sin necesidad; (b) validar la unicidad solo en el
servicio con una consulta `lower(trim(...))` antes de insertar, sin índice — rechazado, dos
inserciones concurrentes con la misma presentación normalizada podrían colarse ambas entre la
consulta y el insert (condición de carrera clásica) sin un índice que la bloquee a nivel de motor.

## D4 — Índice parcial `ux_preferido`, no diferible

**Decision**: `op.create_index("ux__supplier_items__preferred", "supplier_items",
["inventory_item_id"], unique=True, postgresql_where=text("preferred AND active"))`. No se declara
`DEFERRABLE` (los índices de Postgres no lo admiten, solo las constraints) — el orden transaccional
de D2 es lo único que evita violarlo a mitad del swap.

**Rationale**: es la base de datos, no el servicio, la que garantiza RN-16 incluso si algún código
futuro olvida pasar por `supplier_items.py` — mismo patrón ya usado en el repositorio
(`postgresql_where=text("status = 'pendiente'")` en `order_payment_attempts`, spec de intentos de
pago) para "a lo sumo una fila activa de cierto tipo por padre".

**Alternatives considered**: ninguna — es la única forma correcta en Postgres de expresar "a lo
sumo una preferida activa por insumo" sin un `CheckConstraint` (que no puede ver otras filas) ni
un trigger a medida (innecesariamente más complejo que un índice parcial estándar).

## D5 — `Supplier.is_system` y el seed "Compra ocasional" (FR-012/FR-013/FR-019)

**Decision**: migración Alembic decorada con `@for_each_tenant_schema` (mismo mecanismo que
`f03274730367_presentations_y_reglas_por_presentacion.py`) que (1) agrega
`suppliers.is_system BOOLEAN NOT NULL DEFAULT false`, y (2) inserta, de forma idempotente, un
proveedor `name='Compra ocasional', is_system=true, active=true` por esquema de tenant —
`INSERT ... WHERE NOT EXISTS (SELECT 1 FROM {schema}.suppliers WHERE is_system)`.

**Rationale**: el runner de migraciones del proyecto ya ejecuta `upgrade(schema)` una vez por
cada esquema de tenant (confirmado en el archivo citado), que es exactamente lo que se necesita
para que todo tenant existente **y** todo tenant nuevo (que corre todas las migraciones al
crearse) termine con su propio "Compra ocasional" sin ningún script manual adicional.

**Alternatives considered**: (a) sembrarlo con un script independiente (`app/scripts/seed_*.py`,
como `seed_super_admin.py`) ejecutado a mano — rechazado, un tenant nuevo quedaría sin el
proveedor de sistema hasta que alguien se acuerde de correr el script; la migración lo deja
garantizado por construcción.

## D6 — Cómo FR-014 detecta "ya se usó en una compra"

**Decision**: se agrega `purchase_items.supplier_item_id UUID NULL REFERENCES
supplier_items.id` en la misma migración de D5. Ningún flujo actual de compras (alta directa,
orden, recepción) la puebla todavía — HU-05 (upsert automático al recibir una compra) es quien la
llenará. El guard de FR-014 en `supplier_items.py` simplemente comprueba
`EXISTS (SELECT 1 FROM purchase_items WHERE supplier_item_id = :id)` antes de permitir editar
`conversion_factor`.

**Rationale**: así documentado explícitamente en la spec (sección Assumptions, "el bloqueo de
edición del factor... se especifica como regla de negocio desde ya, aunque el enlace... todavía
no existe"). Agregar la columna ahora, vacía, es lo mínimo necesario para que el guard sea
real e inspeccionable (y para que `test_supplier_items.py` lo pruebe insertando directamente una
fila de `purchase_items` que apunte a la relación) sin forzar a esta spec a construir también el
flujo de compras que la llena.

**Alternatives considered**: (a) no agregar la columna y dejar FR-014 sin forma de verificarse
hasta HU-05 — rechazado, el propio spec exige los Acceptance Scenarios de esta historia
(Historia 1, escenario 6) verificables ahora, no "cuando exista HU-05"; (b) una tabla puente
separada `supplier_item_usages` en vez de una columna en `purchase_items` — rechazado, es más
estructura de la que HU-05 necesita: una columna nullable en la tabla que ya registra líneas de
compra es el lugar natural y es lo que esa futura spec va a popular directamente.

## D7 — Diseño de los endpoints REST

**Decision**: ver `contracts/api.md` para el detalle completo. Resumen: dos `GET` simétricos
(`/inventory/items/{item_id}/suppliers`, `/inventory/suppliers/{supplier_id}/items}`), un único
`POST` de alta (en cualquiera de las dos rutas, mismo cuerpo con el id del otro lado) que hace
alta-o-reactivación según exista o no la combinación inactiva (FR-004/FR-005), y un único `PATCH
/inventory/supplier-items/{relation_id}` para editar presentación/factor/último costo, marcar
preferido y activar/desactivar — sin rutas de acción separadas (`/prefer`, `/deactivate`).

**Rationale**: replica el patrón ya establecido por `PATCH /inventory/suppliers/{id}` (un único
endpoint de actualización parcial con un campo `active: bool | None`, visto en
`SupplierUpdate`) en vez de inventar un estilo de API nuevo para este sub-recurso.

**Alternatives considered**: endpoints de acción dedicados (`POST .../prefer`,
`POST .../deactivate`) — rechazado, ningún otro recurso del proyecto los usa para este tipo de
cambio de estado; un `PATCH` genérico es consistente y más simple de mantener.

## D8 — Pestañas en el frontend (corregido durante la implementación)

**Decision (revisada)**: sin componente nuevo. `InventoryPageComponent` ya tiene, desde antes de
esta spec, una barra de pestañas armada a mano (`tab = signal<Tab>('items')` + un `<div
class="flex gap-1 border-b ...">` con un `<button>` por pestaña, clase condicional
`border-indigo-600 text-indigo-600` vs `border-transparent text-gray-500`) — el grep de Fase 0
("sin resultados para `mat-tab-group` ni `TabsComponent`") encontró que no hay un *componente*
reutilizable, pero pasó por alto que sí hay un *patrón* ya repetido. Las dos páginas de detalle
nuevas (`InventoryItemDetailPageComponent`, `SupplierDetailPageComponent`) replican ese mismo
bloque en línea en vez de extraer una abstracción nueva.

**Rationale**: Principio V (sin refactors oportunistas) — introducir un componente genérico
`<app-tabs>` cuando el propio código ya resuelve "una barra de pestañas" de forma consistente,
aunque sin un componente dedicado, sería una abstracción no pedida por esta spec. Cada página
nueva hoy solo necesita una pestaña (no hay todavía una segunda pestaña que mostrar), así que ni
siquiera hace falta la lógica de cambio de pestaña — el botón queda fijo en estado activo, listo
para que una spec futura agregue el `signal`/`@if` de contenido si agrega una segunda pestaña.

**Alternatives considered**: (a) el componente `<app-tabs>` original de este documento —
descartado al descubrir el patrón inline ya existente, que hace innecesaria la abstracción; (b)
Angular Material solo para `mat-tab-group` — descartado por lo mismo que antes (Principio IX).

## D9 — Estrategia de verificación

**Decision**: backend — script autoejecutable `app/scripts/test_supplier_items.py` (patrón de
`test_cancel_inventory.py`) contra un tenant real, que es el único lugar donde se puede probar de
verdad el candado `SELECT ... FOR UPDATE` de D2 y el índice parcial de D4 (la suite de
characterization corre contra SQLite en memoria, donde `FOR UPDATE` es un no-op — ver memoria de
sesión "cómo correr los tests de los repos hermanos"). Frontend — specs Vitest para
`supplier-item-form.component`, `inventory-item-detail-page.component` y
`supplier-detail-page.component`, siguiendo el patrón ya documentado de `tick`/`flushActivePromotions`
para los componentes que usan `injectPagedQuery`.

**Rationale**: verificar RN-16 (un único preferido) de forma creíble exige un Postgres real con
bloqueo de filas de verdad, no una suite donde ese bloqueo es un no-op; replicar el patrón de
scripts ya usado para otras reglas de concurrencia del propio módulo de inventario
(`test_cancel_inventory.py`) es la forma más directa de lograrlo sin introducir un framework de
test nuevo.

**Alternatives considered**: confiar solo en la suite de characterization sobre SQLite —
rechazado, daría una falsa sensación de cobertura sobre la regla más delicada de todo el spec
(RN-16) sin probar realmente el mecanismo que la sostiene.
