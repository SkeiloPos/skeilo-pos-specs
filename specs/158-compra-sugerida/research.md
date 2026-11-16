# Research: Compra Sugerida de Insumos

Todas las "NEEDS CLARIFICATION" del Technical Context ya estaban resueltas por la sesión de
clarificación del propio spec (2026-11-15) o se resuelven aquí inspeccionando el código real
de `pos-backend`/`pos-heladeria`. No queda ninguna pendiente.

## D1: "Comercio y sucursal" se resuelve como filtrado por esquema de tenant, sin concepto de sucursal

- **Decision**: FR-001/FR-014 ("filtrar por el comercio y la sucursal del usuario") se
  implementan filtrando únicamente por el esquema de tenant actual (`get_tenant`/`get_db`,
  igual que el resto del router `inventory`). No se introduce ningún campo ni tabla de
  "sucursal".
- **Rationale**: se buscó en todo `pos-backend` (`grep -rli "sucursal\|branch" app --include="*.py"`,
  excluyendo characterization tests) y no existe ningún modelo, columna ni tabla de sucursal
  en ningún módulo, incluido `inventory`. El esquema-por-tenant (`schema: "tenant"`) ya es la
  única partición multi-negocio que existe hoy; cada tenant/esquema es, en la práctica, "un
  comercio" sin sub-división por sucursal. Introducir una sucursal real sería una
  funcionalidad de otro spec, no algo que esta pantalla pueda asumir que ya existe.
- **Alternatives considered**: tratar "sucursal" como un campo nuevo en `InventoryItem` o
  `Purchase` — rechazado porque el spec (sección Assumptions) declara que el modelo de
  insumo/proveedor "ya existe" y esta funcionalidad "solo lo usa"; crear esa columna sería
  una funcionalidad de inventario multi-sucursal no pedida ni alcanzable en este spec.

## D2: El "permiso de compras" (FR-014) reusa exactamente los guards existentes de compras

- **Decision**: el endpoint de generación usa `require_tenant_admin` (backend,
  `app/core/dependencies.py`) + `require_module_access("inventario")` (ya aplicado a nivel de
  router); la ruta de la pantalla en el frontend usa `roleGuard([UserRole.ADMIN])` +
  `planModuleGuard('inventario')`. El endpoint de **lectura** (listar lo sugerido) usa
  `get_current_user` sin más (mismo criterio que `GET /items/low-stock` y `GET /purchases`,
  que son de solo lectura y no exigen admin).
- **Rationale**: no existe ningún permiso granular llamado "compras" en el sistema de roles
  — los endpoints de mutación de compras ya existentes (`create_purchase`,
  `create_purchase_order`, `receive_purchase`, `void_purchase`) usan exactamente
  `require_tenant_admin`, y sus rutas gemelas en el frontend (`inventario/compras/nueva`)
  usan exactamente `roleGuard([UserRole.ADMIN])` + `planModuleGuard('inventario')`. El spec
  asume (sección Assumptions) que "el permiso compras... ya existe"; en el código real ese
  permiso es, hoy, "ser admin del tenant con el módulo inventario habilitado en su plan" —
  no hay una entidad de permiso más fina que inventar.
- **Alternatives considered**: crear un rol/permiso "compras" nuevo y distinto de
  `ADMIN` — fuera de alcance: el spec no pide un sistema de permisos nuevo (sección
  Assumptions lo excluye explícitamente) y ningún endpoint de compras existente lo tiene hoy.

## D3: Endpoint de lectura dedicado, no una extensión de `/items/low-stock`

- **Decision**: nuevo `GET /inventory/purchases/suggested` (paginado, `Page[...]`, mismo
  patrón que `/items` y `/purchases`) en vez de ensanchar `LowStockResponse`/`/items/low-stock`.
- **Rationale**: `/items/low-stock` ya tiene un consumidor real y angosto — la tarjeta "Stock
  bajo" del dashboard (`admin-dashboard.component.ts`/`.spec.ts`), que solo necesita
  `id/name/current_stock/min_stock` sin proveedor ni paginar. Ensanchar esa respuesta con
  proveedor/unidad/precio/cantidad sugerida/equivalencia rompería el contrato que ese
  consumidor ya tiene y no está en el alcance de este spec. Un endpoint separado evita tocar
  comportamiento existente (Principio II) y permite que el nuevo responda ya paginado
  (FR-020) y ordenado por déficit descendente (clarificación 3), cosas que `/items/low-stock`
  no hace (devuelve `list[...]` completo, sin paginación, ordenado por nombre).
- **Alternatives considered**: añadir query params opcionales a `/items/low-stock` que
  activen el modo "con proveedor" — rechazado porque mezclaría dos contratos de respuesta
  distintos bajo el mismo endpoint/response_model, más difícil de mantener que dos rutas
  claras con responsabilidades distintas (mismo criterio que ya separa `/items` de
  `/items/low-stock` hoy).

## D4: Precarga de proveedor preferido/alternos reusa `supplier_items.py`, no una query nueva desde cero

- **Decision**: el endpoint de lectura reusa `supplier_items.preferred_relations_by_item()`
  (ya trae proveedor preferido + presentación efectiva + factor efectivo + último costo, en
  un solo query por lote) como base, extendido con `unit_measure_id`/abreviatura de unidad
  necesarios para el selector (FR-002/FR-004). Los proveedores **alternos** de una fila
  (FR-004) no se precargan en bloque: se piden al abrir el selector de proveedor de esa fila
  puntual, vía el endpoint ya existente `GET /inventory/items/{item_id}/suppliers`
  (`supplier_items.list_for_item`), el mismo que ya usa cualquier otra pantalla de
  proveedor-insumo.
- **Rationale**: evita una consulta N+1 nueva y evita duplicar la lógica de "factor/
  presentación efectivos" (`SupplierItem.effective_presentation`/`effective_conversion_factor`)
  que `preferred_relations_by_item` y `list_for_item` ya encapsulan. No precargar alternos de
  las ~100 filas de golpe respeta la regla de este proyecto de no hacer fetches reactivos de
  fondo en selectores — solo se pide al usuario abrir el selector de una fila concreta
  ([[no-proactive-background-fetches-in-selectors]]).
- **Alternatives considered**: devolver los alternos de cada fila embebidos en la respuesta
  paginada de lo sugerido — rechazado: con ~100 filas visibles tras paginar, traer también
  todos sus proveedores alternos de una sola vez es trabajo de red/servidor que la gran
  mayoría de filas no va a usar (el usuario normalmente no cambia de proveedor en cada fila).

## D5: Generación multi-proveedor transaccional — refactor acotado de `service.py`

- **Decision**: extraer de `create_purchase_order()` una variante interna que (a) no comitea
  (el llamador decide cuándo cerrar la transacción) y (b) acepta un flag
  `update_supplier_cost: bool = True` que, en `_resolve_purchase_line`, controla si se llama
  a `supplier_items.apply_purchase_cost()`. `create_purchase`/`create_purchase_order`
  existentes siguen llamando con el default `True` (comportamiento idéntico, cero cambios
  observables). El nuevo `generate_suggested_purchases()`: agrupa las líneas recibidas por
  `supplier_id` (vía el `supplier_id` de cada `SupplierItem` referenciado), construye una
  `Purchase`+`PurchaseItem[]` en `draft` por grupo con la variante no-commiteadora y
  `update_supplier_cost=False`, y hace un único `db.commit()`/`db.rollback()` al final para
  todas las órdenes del lote.
- **Rationale**: ver Complexity Tracking en plan.md — es la única forma de cumplir FR-009
  (todo o nada entre N proveedores) y FR-007 (precio editado no toca `last_cost`) sin
  duplicar ~70 líneas de lógica de conversión/validación ya probada por los characterization
  tests de compras. El refactor es aditivo (nuevo parámetro con default que preserva el
  comportamiento actual) — no requiere tocar ningún test `"CONGELA comportamiento actual:"`.
- **Alternatives considered**: ver tabla de Complexity Tracking en plan.md.

## D6: Idempotencia — tabla nueva, porque no existe un mecanismo genérico reusable

- **Decision**: tabla nueva `purchase_generation_requests` (esquema `tenant`) con
  `idempotency_key` único + los IDs de las compras creadas en esa generación. Ver
  data-model.md.
- **Rationale**: se buscó "idempoten" en todo `pos-backend`; todos los usos existentes son
  idempotencia *por construcción de datos* (p. ej. `invoices/service.py::issue_for_sale`
  devuelve la factura existente si ya hay una con ese `sale_id` único — no hay clave de
  cliente involucrada) o guardas de versión optimista contra doble clic
  (`orders/checkout.py`), no un mecanismo genérico de "guarda esta clave enviada por el
  cliente y, si se repite, devuelve el mismo resultado sin volver a ejecutar". Generar hasta
  5 órdenes en un lote no tiene una columna única natural equivalente a `sale_id` en la que
  apoyarse, así que se necesita una clave explícita.
- **Alternatives considered**: deduplicar comparando el contenido de la solicitud (mismas
  líneas/cantidades/precios) en vez de una clave explícita — rechazado: el spec (FR-010,
  Assumptions) ya fija que la clave la genera y envía el cliente; comparar contenido además
  es ambiguo si el usuario reintenta tras editar algo a propósito entre el primer intento
  fallido y el reintento.

## D7: Paginación servidor, no virtual-scroll nuevo en el frontend

- **Decision**: FR-020 se resuelve con el mismo patrón `page`/`size` + `Page<T>` +
  `injectPagedQuery` que ya usan `/inventory/items` y `/inventory/purchases` en el frontend,
  no con `cdk-virtual-scroll` ni `mat-paginator`.
- **Rationale**: se buscó `ScrollingModule|ndk-virtual-scroll|CdkVirtualScroll|mat-paginator`
  en todo `pos-heladeria/src/app` y no hay ningún uso — introducir virtual-scroll sería la
  primera vez en el proyecto, con su propia curva de integración con signals/OnPush. El
  patrón de paginación de servidor que ya existe resuelve literalmente lo que pide FR-020
  ("paginar o virtualizar... sin renderizar sin límite") sin dependencia ni patrón nuevo, y
  ya sabe preservar selección entre páginas si el estado de selección se guarda por
  `inventory_item_id` en un `Map`/`Set` en el componente (no en el array de la página
  actual) — que es como ya se maneja la selección en pantallas de líneas similares.
- **Alternatives considered**: `cdk-virtual-scroll` — más fluido para scroll infinito, pero
  no sigue ningún patrón ya validado en este proyecto y el spec acepta "paginación **o**
  scroll virtualizado" como equivalentes (clarificación 1), así que no hay ninguna razón de
  negocio para pagar el costo de introducirlo por primera vez aquí.

## D8: Componente de pantalla — mismo patrón que `purchase-view.component.ts`

- **Decision**: `suggested-purchase-page.component.ts` standalone, `OnPush`, señales
  (`signal`/`computed`), `FormsModule` (`ngModel`) para los inputs de cantidad/precio por
  fila, reusando `MoneyInputComponent`, `IconMiComponent`, `ToastService` y los servicios
  `SuppliersService`/`SupplierItemsService`/`UnitMeasureService` ya existentes.
- **Rationale**: `purchase-view.component.ts` (spec 140) ya resuelve un problema casi
  idéntico (líneas editables con cantidad/precio/presentación, resumen que se recalcula,
  confirmación y manejo de error) con este mismo stack — no hay ninguna señal de que el
  proyecto use Reactive Forms ni NgRx en pantallas de este tipo.
- **Alternatives considered**: Reactive Forms (`FormGroup`/`FormArray`) para las filas —
  rechazado por inconsistencia con el patrón ya establecido en la pantalla más parecida del
  mismo módulo, sin ninguna necesidad funcional (validación cruzada compleja) que lo exija.
