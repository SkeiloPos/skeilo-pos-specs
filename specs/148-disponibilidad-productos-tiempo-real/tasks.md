---

description: "Task list for: Disponibilidad de productos en tiempo real (agotado ↔ disponible)"
---

# Tasks: Disponibilidad de productos en tiempo real (agotado ↔ disponible)

**Input**: Design documents from `/specs/148-disponibilidad-productos-tiempo-real/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/ (4 archivos), quickstart.md (todos presentes)

**Repos involved**: `../pos-backend` (FastAPI/SQLAlchemy, SQLite en memoria para la suite), `../pos-heladeria` (Angular/signals, specs con `ng test`), `pos-specs` (este repo: anomalías y documentación)

**Tests**: Incluidos. El modelo de pruebas del proyecto es de *characterization tests* (backend, `app/characterization_tests/`) y specs del frontend, exigidos por los Principios III y X y por `quickstart.md`. Cada tarea de implementación que es pequeña lleva su spec en la misma tarea; las piezas transversales tienen tarea de prueba aparte.

**Organization**: Tareas agrupadas por historia de usuario. Las historias US1–US4 son P1; US5–US6 son P2.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Se puede hacer en paralelo con las tareas hermanas de su grupo (archivos distintos, mismos prerrequisitos ya cumplidos)
- **[Story]**: US1 (cambio visible sin recargar) · US2 (carrito se conserva) · US3 (409 como última defensa) · US4 (aislamiento entre negocios) · US5 (recuperación de la conexión) · US6 (agotado por inventario)
- Las rutas llevan el prefijo del repo: `pos-backend/…`, `pos-heladeria/src/app/…`, `specs/…`
- Los commits **solo se hacen si el usuario los pide** (Principio XV): pequeños, por unidad lógica y por repo, en inglés
- La suite del frontend se compara **por nombre de prueba** contra la línea base de T004 (hay fallos preexistentes en 7 archivos); **nunca** correr las suites completas de frontend y backend en paralelo

---

## Phase 1: Setup

**Purpose**: Ramas, decisión de negocio registrada y línea base de las suites.

- [ ] T001 [P] Crear la rama `feat/148-product-availability-realtime` en `pos-backend` desde `develop` actualizado (`git pull --ff-only`), Principio XIV. El repo tiene hoy una migración sin seguimiento ajena a esta spec (`alembic/versions/f2d755c229e8_fusionar_cabezas_de_inventario_y_.py`): no tocarla ni incluirla en ningún commit
- [ ] T002 [P] Crear la rama `feat/148-product-availability-realtime` en `pos-heladeria` desde `develop` actualizado (`git pull --ff-only`)
- [ ] T003 Registrar en `specs/000-reconocimiento/registro-de-anomalias.md` (Principio II) las dos decisiones de negocio de `research.md` D17, **antes de tocar cualquier código**: (a) *rechazo por agotado unificado*: los caminos de inventario pasan de 400 a 409 con lista `agotados[]`; los 409 que ya existían (adiciones y toppings «Stock insuficiente», carrito QR) cambian su texto `error` al formato de FR-024 conservando `insumo`, `disponible`, `requerido` y `contexto`; y `POST /orders` hace un chequeo preventivo de inventario al crear el pedido (hoy aparece recién al cobrar, H7); (b) *el menú marca agotado por receta*: una presentación, un producto o una adición (`MenuToppingResponse.available`) cuyo insumo de receta no alcanza deja de mostrarse disponible (hoy el menú solo mira opciones y grupos obligatorios, H3). Hacer `git fetch` justo antes y tomar los **siguientes números libres** (el último hoy es A-152 y el A-150 está duplicado entre las specs 141 y 146); seguir el formato de A-150…A-152, citar las Clarifications del 2026-11-02 de `spec.md`, las funcionalidades afectadas y los tests que cambian (T076). Dejar los números asignados anotados bajo esta tarea. **Bloquea todas las tareas de código (T005 en adelante)**
- [ ] T004 Medir la línea base de ambas suites, una después de la otra: backend `cd pos-backend && ./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'` y frontend `cd pos-heladeria && ng test --watch=false`. Registrar en `specs/148-disponibilidad-productos-tiempo-real/checklists/baseline-suites.md` los totales y los **nombres** de las pruebas que fallan. Es la referencia de T107 y T108

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Lo que usan todas las historias: el motor único de «pedibilidad», el evento y las lecturas de reconciliación en el backend; el modelo, el registro del evento SSE, las funciones puras y el sincronizador en el frontend.

**⚠️ CRITICAL**: Ninguna historia empieza antes de terminar esta fase. T003 debe estar hecha antes de T005.

### Backend: motor de pedibilidad (research D3)

- [ ] T005 Escribir **primero**, en `pos-backend/app/characterization_tests/test_availability_engine.py` (archivo nuevo), la prueba de equivalencia que **congela el cálculo actual** (Principio V, research D3): con un catálogo de prueba (reutilizar `product_availability_fixtures.py`; insumos con stock suficiente, justo e insuficiente; una opción ligada a un insumo inactivo; un grupo con `quantity_per_option` por tamaño; un grupo obligatorio `min_select>0` modo `conteo` sin ninguna opción disponible) fijar como **valores literales** los `available` de opciones, presentaciones y productos que hoy devuelve `GET /menu` (`public_menu`/`_build_menu` en `pos-backend/app/api/v1/menu/router.py`). El catálogo de esta prueba **no** incluye una receta con stock insuficiente (ese caso es comportamiento nuevo y se prueba en T010). Debe pasar en verde contra el código **sin modificar**
- [ ] T006 Crear `pos-backend/app/catalog_engine/availability.py` con las dataclasses `ProductAvailability(sold_out, available)`, `VariantAvailability(product_id, available)`, `CatalogAvailability(products, variants, options)` y `compute_availability(db, *, stock: dict[UUID, Decimal] | None = None, scope_item_ids: Iterable[UUID] | None = None, scope_product_ids: Iterable[UUID] | None = None) -> CatalogAvailability`. Reglas (data-model §Disponibilidad): **opción** = la lógica de `_option_availability` (`menu/router.py:41`) **movida sin cambios**; **presentación activa** = ¬(algún `RecipeItem` con stock < cantidad, solo si `Product.tracks_inventory`) ∧ ¬(algún grupo obligatorio `min_select>0` modo `conteo` sin ninguna opción disponible — regla actual, no corregir el caso `min_select>1`); **producto** `available` = alguna presentación activa pedible; `sold_out = not Product.available`, independiente del inventario. Considera solo productos, presentaciones y opciones **activos**. `stock` sobrescribe `InventoryItem.current_stock` por id (lo usa el gancho de T098); `scope_item_ids` limita el cálculo a lo que depende de esos insumos (recetas, opciones y presentaciones que los usan por cualquier vía); `scope_product_ids` lo limita a esos productos (lo usa la publicación manual de T028). Número **constante** de consultas SQL, sin N+1. Depende de T005
- [ ] T007 En `pos-backend/app/catalog_engine/availability.py` agregar `diff_availability(before: CatalogAvailability, after: CatalogAvailability) -> list[dict]`: devuelve, con la forma de `changes[]` de `contracts/availability-event.md` (`kind`, `id`, `product_id` en `variant`, `sold_out`+`available` en `product`, `available` en `variant`/`option`), **solo** los elementos cuyo estado «pedible» cambió (FR-009). En producto compara el `available` derivado (la marca manual no cambia por inventario, FR-011) y toma `sold_out` del `after`. Un elemento presente en un solo lado se ignora
- [ ] T008 Reexportar `compute_availability`, `diff_availability` y los tipos en `pos-backend/app/catalog_engine/__init__.py` (actualizar el docstring que enumera los símbolos públicos). Correr `catalog_engine_equivalence_gate.py` e `inventory_engine_equivalence_gate.py` (en `pos-backend/app/characterization_tests/`) para confirmar que el paquete no cambió de comportamiento
- [ ] T009 En `pos-backend/app/api/v1/menu/router.py` hacer que `_build_menu` consuma `compute_availability` en lugar de `_option_availability` (eliminar esa función del router) y que `MenuToppingResponse.available` sea `active ∧ marca manual ∧ pedible (presentación principal)` con el mismo motor (FR-017, data-model §Disponibilidad). El único cambio visible intencional es la receta (anomalía de T003). Correr T005 (debe seguir en verde), `test_menu_router.py` y `test_menu_sold_out.py`
- [ ] T010 Completar `pos-backend/app/characterization_tests/test_availability_engine.py` con las pruebas del comportamiento nuevo: presentación con insumo de receta sin stock ⇒ presentación `available=false`, y producto `available=false` solo si era su única presentación; `tracks_inventory=false` ignora la receta; insumo compartido por varias presentaciones/opciones; sobrescritura `stock=`; `scope_item_ids`/`scope_product_ids` dan el mismo estado que el cálculo completo para esos elementos; `sold_out` no cambia con el inventario; `diff_availability` ⇒ vacío si el stock baja 10→9, un elemento si cruza a 0, y reaparece al reponer; el número de consultas SQL es **el mismo** con 5 y con 50 productos (contador con `event.listens_for(engine, "before_cursor_execute")`). Depende de T009

### Backend: evento y lecturas de reconciliación (research D1, D2, D8)

- [ ] T011 En `pos-backend/app/core/events.py` agregar la constante `AVAILABILITY_EVENT_MAX_CHANGES = 200` y `availability_changed(tenant_id: int, changes: list[dict], *, refresh: bool = False) -> str | None`, que publica `{changes, refresh}` con `channels=[CH_STAFF, menu_channel(tenant_id)]` (modelarlo sobre `menu_updated`, ~línea 359). Si `len(changes)` supera el tope publica `changes=[]` y `refresh=True`. No cambiar `app/api/v1/realtime/auth.py` (D2). Nunca lanza
- [ ] T012 En `pos-backend/app/core/events.py` agregar `latest_version(tenant_id: int) -> int | None`: `version_of(` id de la última entrada de `stream_key(tenant_id)` `)` (p. ej. `XREVRANGE … COUNT 1`); `None` si el stream está vacío o Redis no responde; nunca lanza (contrato snapshot, campo `as_of`)
- [ ] T013 [P] Crear `pos-backend/app/characterization_tests/test_availability_events.py` (patrón de `test_menu_realtime.py`) con las pruebas de forma: `availability_changed` publica en `staff` **y** `menu:{tenant}`; el payload solo trae `type`/`changes`/`refresh` y, por cambio, únicamente las claves del contrato (sin existencias, cantidades, costos, insumos ni nombres de empleados — FR-007); sobre el tope ⇒ `changes=[]` + `refresh=True`; `latest_version` devuelve `None` si Redis falla. Depende de T011, T012
- [ ] T014 [P] En `pos-backend/app/api/v1/menu/schemas.py` agregar `AvailabilityProductState {id, sold_out, available}`, `AvailabilityVariantState {id, product_id, available}`, `AvailabilityOptionState {id, available}` y `AvailabilitySnapshot {as_of: int | None, products, variants, options}` según `contracts/availability-snapshot-api.md`
- [ ] T015 En `pos-backend/app/api/v1/menu/router.py` agregar `GET /menu/availability` (tenant por cabecera, igual que `GET /menu`): lee `as_of = events.latest_version(tenant.id)` **antes** de calcular y devuelve el estado del motor para todo el catálogo activo, sin filtro de QR, incluidas las adiciones que existen como producto. Extraer un helper compartido `_availability_snapshot(db, tenant, *, only_visible_en_qr)`. Depende de T006, T012, T014
- [ ] T016 En `pos-backend/app/api/v1/menu/router.py` agregar `GET /menu/qr-token/{token}/availability`: valida el token firmado igual que `menu_by_signed_qr` (el tenant y la mesa salen del token, FR-031), conserva el rate limit `menu_qr` y usa el helper de T015 con `only_visible_en_qr=True` (mismos filtros que `_build_menu(only_visible_en_qr=True)`: no devuelve ids de productos o categorías ocultos). Depende de T015
- [ ] T017 [P] Crear `pos-backend/app/characterization_tests/test_availability_snapshot.py`: presentación con insumo de receta en 0 ⇒ `available:false` y su producto `available:false` si era la única, sin tocar la marca manual; la versión del comensal no incluye un producto con `visible_en_qr=false`; equivalencia: `available`/`sold_out` del snapshot coinciden con los de `GET /menu` para el mismo catálogo; `as_of` es `null` si Redis falla y la respuesta sigue siendo 200; token inválido o vencido se rechaza igual que `GET /menu/qr-token/{token}`. Depende de T016

### Frontend: núcleo (research D9, D10, D13)

- [ ] T018 [P] Crear `pos-heladeria/src/app/core/availability/availability.model.ts`: `AvailabilityChange` (`kind: 'product' | 'variant' | 'option'`, `id`, `product_id?`, `sold_out?`, `available`), `AvailabilitySnapshot` (`as_of`, `products`, `variants`, `options`), `SoldOutItem {id, tipo, nombre, producto_id, motivo}` y `SoldOutConflict {error, productos_agotados, agotados}` (formas de `contracts/`)
- [ ] T019 [P] En `pos-heladeria/src/app/core/realtime/realtime-event.model.ts` agregar `AvailabilityChangedEvent extends RealtimeBase` (`type: 'availability.changed'`, `changes`, `refresh`) y sumarlo a la unión `RealtimeEvent`
- [ ] T020 En `pos-heladeria/src/app/core/realtime/sse-client.ts` agregar `'availability.changed'` a `KNOWN_EVENT_TYPES`, con un comentario que explique la trampa (sin el registro `EventSource` descarta el frame en silencio; mismo caso que `notification.created`). **No** agregar aún `menu.updated` (va en T105, commit propio). Depende de T019
- [ ] T021 [P] Crear `pos-heladeria/src/app/core/realtime/known-event-types.spec.ts` (test guardia, research D13): un `Record<RealtimeEventType, true>` exhaustivo (si alguien agrega un tipo a la unión sin listarlo, **no compila**) comparado contra `KNOWN_EVENT_TYPES`. Declarar `menu.updated` como excepción conocida y comentada (T105 la retira). Depende de T020
- [ ] T022 Crear `pos-heladeria/src/app/core/availability/availability.util.ts` con funciones puras, genéricas sobre el tipo estructural mínimo del menú (`products[].{id, sold_out?, available?, variants[].{id, available?}, option_groups[].options[].{id, available?}, toppings?[].{id, available?}}`) para servir tanto a `MenuService` como al menú del comensal: `isProductSoldOut(p) = p.sold_out || p.available === false` (FR-012); `applyChanges(categories, changes)` e `applySnapshot(categories, snapshot)` **inmutables** (misma referencia si nada cambió); una adición (topping) comparte el id de su producto, así que un cambio `product` también parcha `toppings[].available = ¬sold_out ∧ available`; `shouldApply(key, v, lastV, snapshotAsOf)` = `v > (lastV[key] ?? 0) ∧ v > (snapshotAsOf ?? 0)` (FR-006, D9). El snapshot **reemplaza** el estado de lo que trae y no toca lo que no trae. Depende de T018
- [ ] T023 [P] Crear `pos-heladeria/src/app/core/availability/availability.util.spec.ts`: parche de producto (`sold_out` y `available`), presentación, opción y adición por id de producto; inmutabilidad y referencias intactas; ráfaga marcar/desmarcar/marcar con eventos llegando desordenados termina en el último `v`; el snapshot reemplaza, un elemento ausente no se toca, y descarta eventos con `v <= as_of`. Depende de T022
- [ ] T024 Crear `pos-heladeria/src/app/core/availability/availability-sync.service.ts` (`providedIn: 'root'`): interfaz `AvailabilityTarget { applyAvailability(changes); applyAvailabilitySnapshot(snapshot) }`; `registerTarget(target): () => void` (admite varios destinos a la vez); `start(fetchSnapshot: () => Promise<AvailabilitySnapshot>)` idempotente, que se suscribe con `RealtimeService.on('availability.changed', …)` y aplica la guardia de `shouldApply` con `lastV`/`snapshotAsOf`; `stop()` que desuscribe y limpia el estado; `applyLocal(changes)` que aplica a todos los destinos sin guardia (lo usa el manejo del 409 de US3); `reconcile(): Promise<boolean>` con **una sola consulta en vuelo** (las llamadas simultáneas comparten la promesa) que llama a `fetchSnapshot`, fija `snapshotAsOf = as_of`, limpia `lastV` y entrega el snapshot a los destinos; un evento con `refresh: true` dispara `reconcile()`; signal `resyncPending` (true desde que se necesita reconciliar hasta que una consulta tiene éxito). No hace nada si no se llamó a `start`. Depende de T018, T019, T022
- [ ] T025 [P] Crear `pos-heladeria/src/app/core/availability/availability-sync.service.spec.ts`: aplica un evento a todos los destinos registrados; descarta un evento con `v` menor o igual al ya aplicado o al `as_of`; `refresh:true` dispara una consulta; dos `reconcile()` simultáneos hacen **una** petición; `stop()` deja de entregar eventos; `applyLocal` no consulta ni usa `v`. Depende de T024
- [ ] T026 En `pos-heladeria/src/app/core/services/menu.service.ts` hacer que `MenuService` implemente `AvailabilityTarget`: `applyAvailability(changes)` y `applyAvailabilitySnapshot(snapshot)` actualizan el signal `categories` con las funciones de T022, más `loadAvailability(): Promise<AvailabilitySnapshot>` (`GET /menu/availability`). Depende de T022, T024
- [ ] T027 [P] Ampliar `pos-heladeria/src/app/core/services/menu.service.spec.ts`: el parche cambia `categories` sin recargar el menú, `loadAvailability` llama al endpoint correcto y el snapshot se aplica. Depende de T026

**Checkpoint**: motor, evento, snapshot y sincronizador listos y probados; ninguna superficie cambia todavía. El backend sigue siendo retrocompatible (el evento es ignorado por clientes viejos).

---

## Phase 3: User Story 1 - El cambio de disponibilidad se ve en todas las pantallas abiertas sin recargar (Priority: P1) 🎯 MVP

**Goal**: Cuando un Cajero o Administrador marca o desmarca «Agotado», el menú QR, la Terminal (mesa, para llevar, domicilio y orden manual), el catálogo para agregar ítems a una orden existente y la Carta del menú lo reflejan en menos de 3 s sin recargar, y terminan en el estado de la última acción confirmada.

**Independent Test**: Con el menú QR de un comensal, la Terminal de una mesera y la Carta de un segundo cajero abiertos en el mismo negocio, marcar «Granizado de mora» como agotado y cronometrar hasta que las tres pantallas lo muestren; repetir al revés (quickstart Escenarios 1–3).

### Backend: publicar la marca manual (research D5)

- [ ] T028 [US1] En `pos-backend/app/api/v1/products/router.py`, en `set_product_availability`: agregar `tenant: Tenant = Depends(get_tenant)` (hoy el endpoint no lo recibe); leer `previous = service.get_or_404(db, id).available` **antes** de llamar a `service.set_availability`; **después** de que el servicio hizo `db.commit()`, si `previous != product.available`, calcular `compute_availability(db, scope_product_ids=[id])` y publicar `events.availability_changed(tenant.id, [{"kind": "product", "id": …, "sold_out": not product.available, "available": <derivado>}])`. Llevar **ambos** campos (D5). El 403 (rol), el 404 y el 409 de producto inactivo ocurren antes del commit y no publican. No cambiar `ProductService.set_availability` ni su respuesta (FR-033). Depende de T006, T011
- [ ] T029 [US1] En `pos-backend/app/characterization_tests/test_availability_events.py` agregar las pruebas de la publicación manual, parchando `events.publish`: marcar agotado ⇒ **un** evento con el estado del producto y los dos campos; desmarcar ⇒ un evento; repetir el mismo valor ⇒ ninguno; usuario sin permiso (403) ⇒ ninguno; producto inactivo (409) ⇒ ninguno; al momento de publicar el cambio ya está confirmado (FR-004: la sesión no tiene transacción pendiente); si `publish` falla el cambio queda guardado y la respuesta sigue siendo 200 (FR-005). Depende de T028

### Frontend: arranque del sincronizador

- [ ] T030 [P] [US1] En `pos-heladeria/src/app/modules/dashboard/layout/dashboard-layout.component.ts`, junto a `this.realtime.connectStaff()` (~línea 202): inyectar `AvailabilitySyncService` y `MenuService`, llamar `registerTarget(menuService)` y `start(() => menuService.loadAvailability())`; en `ngOnDestroy`, junto a `disconnect()`, llamar `stop()` y la función de baja del destino. Antes de seguir, confirmar en `pos-heladeria/src/app/app.routes.ts` que la Terminal y la orden manual cuelgan de este layout; si alguna ruta queda fuera, arrancar el sincronizador también ahí. Depende de T024, T026
- [ ] T031 [P] [US1] En `pos-heladeria/src/app/modules/tables/services/diner.service.ts` agregar `getAvailability(token: string): Promise<AvailabilitySnapshot>` (`GET /menu/qr-token/{token}/availability`), siguiendo el patrón de `resolveByToken` y su manejo de sesión vencida. Depende de T018
- [ ] T032 [US1] En `pos-heladeria/src/app/modules/tables/pages/diner-shell.component.ts`, en el `effect` que ya llama `connectDiner(token)`: arrancar `AvailabilitySyncService.start(() => dinerService.getAvailability(token))` y llamar `stop()` cuando el token desaparece y en `ngOnDestroy` (la sincronización del comensal **no** puede depender de `PublicMenuComponent`, que se destruye al navegar al checkout — H9). Crear `pos-heladeria/src/app/modules/tables/pages/diner-shell.component.spec.ts` (no existe): arranca con token, se detiene sin token y al destruirse, y usa el endpoint firmado del comensal, **nunca** `GET /menu/availability`. Depende de T024, T031

### Frontend: superficies

- [ ] T033 [US1] En `pos-heladeria/src/app/modules/tables/pages/public-menu.component.ts`: registrar un `AvailabilityTarget` que parche su signal `categories` con `applyChanges`/`applySnapshot` mientras el componente exista (alta en `ngOnInit`, baja en `ngOnDestroy`); en **todas** las plantillas de tarjeta (grilla y resultados del buscador; hoy ~líneas 592 y 598) usar `isProductSoldOut(product)` en lugar de `product.sold_out` para deshabilitar y para la etiqueta «Agotado» (misma etiqueta y mismo comportamiento para marca manual e inventario, FR-012; con `aria-disabled`, sin depender solo del color). Depende de T022, T024, T032
- [ ] T034 [US1] En `pos-heladeria/src/app/modules/tables/pages/public-menu.component.ts` y `pos-heladeria/src/app/modules/tables/components/product-select.component.ts`: el selector abierto sobre un producto que se agota debe seguir el menú vivo — pasar a `app-product-select` un `computed` que resuelva el producto por id contra `categories()` (con la copia de `selectedProduct()` como respaldo) y, si `isProductSoldOut(product)`, deshabilitar «Agregar» con una nota «Producto agotado». Antes de editar, leer cómo `ProductSelectComponent` reacciona al cambio de su `@Input() product` (`ngOnChanges`/`ngOnInit`) para **no reiniciar** lo que la persona ya eligió (FR-020). Depende de T033
- [ ] T035 [US1] Las tarjetas del catálogo de la Terminal hoy **no** miran `sold_out` (verificado: `manual-order-page.component.ts` no lo referencia). En `pos-heladeria/src/app/modules/tables/pages/manual-order-page.component.ts` (tarjeta ~línea 210, `store.openConfig(p, …)`): si `isProductSoldOut(p)` la tarjeta queda deshabilitada (`disabled`, `aria-disabled="true"`), con la etiqueta «Agotado», sin abrir el selector; aplicar a las pestañas por categoría, «Todos» y «Promociones». Además, en `pos-heladeria/src/app/modules/tables/services/pos-terminal.store.ts`, hacer que `openConfig` no abra el selector para un producto agotado (defensa para cualquier otro llamador). Cubre mesa, para llevar, domicilio y la página de orden manual, que comparten esta pantalla y el store (FR-003 b)
- [ ] T036 [US1] En `pos-heladeria/src/app/modules/tables/services/pos-terminal.store.ts` exponer `configuringProductLive` (`computed` que resuelve `configuringProduct()` por id contra `categories()`) y usarlo en `manual-order-page.component.ts` (~línea 856, `app-product-select-pos`) y en `pos-heladeria/src/app/modules/tables/components/product-select-pos.component.ts` deshabilitar «Agregar» con la nota «Producto agotado» cuando `isProductSoldOut(product)`; mismo cuidado que T034 con `ngOnChanges`. Depende de T035
- [ ] T037 [US1] En `pos-heladeria/src/app/modules/tables/components/pos-catalog-drawer.component.ts` (~líneas 92 y 96) reemplazar `p.sold_out` por `isProductSoldOut(p)` para deshabilitar la tarjeta y mostrar «Agotado», y usar `configuringProductLive` para el selector. El drawer recibe el parche porque lee `store.categories()` (que es `MenuService.categories`); el catálogo no se cierra ni se recarga (US1.4). Depende de T036
- [ ] T038 [P] [US1] En `pos-heladeria/src/app/modules/products/services/product.service.ts` agregar `refreshOne(id): Promise<void>` (`GET /products/{id}`) que reemplaza solo esa fila en la lista que ya mantiene el servicio (con `available_changed_by_name`/`available_changed_at`); ampliar `product.service.spec.ts`
- [ ] T039 [US1] En `pos-heladeria/src/app/modules/products/pages/products-page.component.ts` (Carta del menú) registrar un `AvailabilityTarget` en `ngOnInit`/`ngOnDestroy`: para un cambio `kind:'product'` cuya `sold_out` difiera de `!row.available` de una fila **de la página visible**, llamar `productService.refreshOne(id)` (así el nombre de quien cambió y la hora llegan sin ponerlos en un evento que también oye el comensal, D15); un cambio que solo trae el `available` derivado por inventario **no** toca el interruptor manual (US6.5); el snapshot recarga la página actual con `loadProducts(page, size)`. Nada fuera de la página (está paginada, spec 079). Depende de T024, T038
- [ ] T040 [P] [US1] Ampliar `pos-heladeria/src/app/modules/tables/pages/public-menu.component.spec.ts`: un cambio `product sold_out` deshabilita la tarjeta sin recargar; un cambio `available:false` (inventario) la deshabilita igual (FR-012); el selector abierto deshabilita «Agregar» al agotarse el producto sin perder lo elegido; volver a disponible lo rehabilita
- [ ] T041 [P] [US1] Ampliar `pos-heladeria/src/app/modules/tables/pages/manual-order-page.component.spec.ts` y `pos-terminal.store.spec.ts`: la tarjeta de un producto agotado queda deshabilitada y no abre el selector en las pestañas categoría/Todos/Promociones; `openConfig` lo ignora; `configuringProductLive` sigue el menú patchado
- [ ] T042 [P] [US1] Ampliar `pos-heladeria/src/app/modules/tables/components/pos-catalog-drawer.component.spec.ts`: la tarjeta pasa a «Agotado» y se deshabilita con el catálogo abierto, por marca manual y por `available:false`
- [ ] T043 [P] [US1] Ampliar `pos-heladeria/src/app/modules/products/pages/products-page.component.spec.ts`: un cambio manual de una fila visible llama `refreshOne`; uno de una fila fuera de la página no hace nada; un cambio solo de inventario no toca el interruptor; el snapshot recarga la página actual
- [ ] T044 [US1] Verificación manual, quickstart **Escenarios 1, 2 y 3** (prerrequisitos y datos de prueba en `quickstart.md`): cronometrar 5 veces la propagación del agotado y del regreso a disponible hacia la Terminal, el menú QR, el drawer y la Carta de un segundo cajero; confirmar < 3 s sin recargar y la ráfaga de 6 cambios terminando en el último estado (con `v` crecientes en `redis-cli XRANGE events:tenant:<id> - +`)

**Checkpoint**: US1 funciona y se prueba sola. Las líneas del carrito todavía no se marcan (US2) y el inventario todavía no avisa (US6).

---

## Phase 4: User Story 2 - El carrito se conserva cuando un producto se agota, y solo se señala lo afectado (Priority: P1)

**Goal**: Si un producto, presentación, opción o adición de un carrito sin enviar se agota, solo esa línea se resalta como «Agotado» con la opción de quitarla, el resto del carrito queda intacto, el envío se bloquea y todo se normaliza solo si el elemento vuelve. Igual en la Terminal y en el menú QR (incluidos los pasos de pago).

**Independent Test**: Armar un carrito con 2 «Granizado de mora» y 1 «Paleta de coco», agotar el granizado desde otra sesión y verificar que solo esa línea queda resaltada, que la paleta sigue igual, que el envío está bloqueado y que al quitar la línea se habilita con lo restante; repetir con el menú QR y con el paso de transferencia (quickstart Escenarios 4–6).

**Depends on**: US1 (el parche del menú en vivo).

### Funciones puras (data-model §Línea afectada)

- [ ] T045 [US2] En `pos-heladeria/src/app/core/availability/availability.util.ts` agregar: `AvailabilityIndex` (productos con nombre y `sold_out`/`available`, presentaciones con producto y nombre, opciones y adiciones), `buildAvailabilityIndex(categories)`, `applyChangesToIndex(index, changes)`, `applySnapshotToIndex(index, snapshot)`, `affectedElement(line: {variantId, optionIds, toppingIds}, index, quantityConflict: boolean): string | null` y `soldOutMessage(labels: string[])`. `affectedElement` resuelve **por id contra el índice vivo** (no contra copias) en este orden: producto agotado → su nombre; presentación agotada → «Producto · presentación»; opción/sabor/salsa elegida agotada → su nombre; adición agotada → su nombre; línea marcada por cantidad → «No alcanza para esa cantidad»; otra línea del mismo producto con otra presentación u opción disponible **no** se marca (FR-017). `soldOutMessage` produce exactamente el formato de FR-024 («Se agotó: X. Quítalo para continuar» / «Se agotaron: A, B. Quítalos para continuar»). Depende de T022
- [ ] T046 [P] [US2] Ampliar `pos-heladeria/src/app/core/availability/availability.util.spec.ts` con casos de producto, presentación, opción, adición y cantidad; que el índice cambie solo con `applyChangesToIndex`; que la marca se retire sola al volver el elemento (FR-016); que otra presentación disponible del mismo producto no se marque; y los dos textos de `soldOutMessage`

### Terminal (mesa, para llevar, domicilio, orden manual)

- [ ] T047 [US2] En `pos-heladeria/src/app/modules/tables/services/pos-terminal.store.ts`: `availabilityIndex = computed(() => buildAvailabilityIndex(this.categories()))`; un `computed` `affectedDraftKeys` sobre `draftLines()` usando `affectedElement` para las líneas `kind:'product'` (variante, opciones y `toppings` elegidos, resueltos **por id**, no por las copias de `DraftLine` — H11); `hasAffectedLines`; `quantityConflicts = signal<ReadonlySet<string>>(new Set())` de claves de línea, que se limpia para una clave al llamar `removeDraft(key)` o al cambiar su cantidad; en `cartView()` agregar a las filas de borrador un campo opcional `soldOut: string | null` (las filas ya guardadas no se tocan). `createManualOrderFromDraft()` y `saveOrder()` retornan `false` con un mensaje de `soldOutMessage` **sin llamar al servidor** mientras `hasAffectedLines()` sea verdadero (defensa; la interfaz ya deshabilita). Nadie escribe en `draftLines` por una disponibilidad: el carrito nunca se vacía ni se reinicia (FR-014, FR-018). Las líneas `kind:'combo'` no se derivan (ver Notas). Depende de T045
- [ ] T048 [P] [US2] En `pos-heladeria/src/app/modules/tables/pages/manual-order-page.component.ts` (filas del carrito de borrador y botón «Crear pedido», ~líneas 824–842 y `submitDisabled` ~931): resaltar la fila con `soldOut` («Agotado: <elemento>») con un botón «Quitar» que llama `store.removeDraft(key)`, mostrar una alerta `role="alert"` con `soldOutMessage(...)` y deshabilitar «Crear pedido» mientras `store.hasAffectedLines()`. Localizar la plantilla de la fila por `store.cartView()`. Depende de T047
- [ ] T049 [P] [US2] En `pos-heladeria/src/app/modules/tables/components/pos-order-panel.component.ts` (filas del borrador y botón «Guardar pedido», ~línea 449): el mismo resaltado, «Quitar» y alerta, y «Guardar pedido» deshabilitado mientras `store.hasAffectedLines()`. Depende de T047
- [ ] T050 [P] [US2] Ampliar `pos-heladeria/src/app/modules/tables/services/pos-terminal.store.spec.ts`, `pos-heladeria/src/app/modules/tables/pages/manual-order-page.component.spec.ts` y `pos-heladeria/src/app/modules/tables/components/pos-order-panel.component.spec.ts`: 2 granizados + 1 paleta, agotar el granizado ⇒ solo esa fila marcada, la paleta intacta, envío bloqueado; volver a disponible ⇒ la marca y el bloqueo desaparecen solos; dos productos agotados ⇒ dos marcas; quitar una ⇒ el resto conserva cantidades, opciones y notas; agotar solo el sabor «mora» ⇒ la línea que lo contiene indica «mora» y otra línea del mismo producto con otro sabor no se marca; `draftLines` no se modifica por ningún evento. Depende de T047–T049

### Menú QR y pasos de pago

- [ ] T051 [US2] En `pos-heladeria/src/app/modules/tables/services/dining-cart.service.ts`: signal `availability` con el `AvailabilityIndex`, construido en `indexMenu(categories)` (que ya llaman `public-menu.component.ts` y `checkout-hydration.guard.ts`, así que también se hidrata al aterrizar directo en el checkout); `DiningCartService` implementa `AvailabilityTarget` (parche incremental del índice); `affectedLines = computed(...)` sobre `lines()` usando `productVariantId`, `optionKey.split(',')` y `toppingSelections[].toppingProductId`; `quantityConflicts` por id de línea (se limpia al quitar o cambiar la cantidad); `hasAffectedLines`. No tocar `CheckoutProgressStore`. Depende de T045
- [ ] T052 [P] [US2] Ampliar `pos-heladeria/src/app/modules/tables/services/dining-cart.service.spec.ts`: el índice se hidrata con `indexMenu`; un cambio marca solo la línea afectada; vuelve a disponible ⇒ sin marca; presentación u opción agotada ⇒ solo la línea que la contiene; el carrito del servidor (`lines()`) no cambia. Depende de T051
- [ ] T053 [US2] En `pos-heladeria/src/app/modules/tables/pages/diner-shell.component.ts` registrar `DiningCartService` como destino del sincronizador al arrancarlo y darlo de baja al detenerlo. Depende de T032, T051
- [ ] T054 [US2] En `pos-heladeria/src/app/modules/tables/components/cart.component.ts` (carrito del comensal): resaltar la línea afectada («Agotado: <elemento>») con un botón «Quitar» que llama a `DiningCartService.remove(itemId)`, mostrar la alerta `role="alert"` y deshabilitar «Revisar pedido» (~línea 153) mientras `cart.hasAffectedLines()`; el resto de las líneas no cambia. Ampliar `cart.component.spec.ts`. Depende de T051
- [ ] T055 [US2] En `pos-heladeria/src/app/modules/tables/pages/public-menu.component.ts` abrir el carrito al llegar con el query param `carrito=abierto` (usar el mecanismo de apertura del carrito que ya tenga el componente) y quitar el parámetro de la URL con `replaceUrl`; es el destino del botón «Volver al carrito». Ampliar `public-menu.component.spec.ts`. Depende de T033
- [ ] T056 [US2] Crear `pos-heladeria/src/app/modules/tables/pages/checkout/sold-out-cart-alert.component.ts` (standalone, con su `.spec.ts`): muestra, si `cart.hasAffectedLines()`, la alerta `role="alert"` con `soldOutMessage(...)` y un botón «Volver al carrito» que navega a `/menu/t/:token` con `queryParams: { carrito: 'abierto' }`. No cambia de paso por su cuenta (FR-019). Es compartido porque `payment-method-step` y `cash-amount-step` **no** muestran hoy el resumen del pedido. Depende de T051, T055
- [ ] T057 [US2] En `pos-heladeria/src/app/modules/tables/pages/checkout/checkout-order-summary.component.ts` (usado por `review-step` y `transfer-details-step`; la lista es `@Input() lines`) marcar cada línea afectada con «Agotado: <elemento>» a partir de `cart.affectedLines()`. Ampliar `checkout-order-summary.component.spec.ts`. Depende de T051
- [ ] T058 [P] [US2] En `pos-heladeria/src/app/modules/tables/pages/checkout/payment-method-step.component.ts`: incluir `<app-sold-out-cart-alert>` y bloquear la acción de confirmar/enviar mientras `cart.hasAffectedLines()`, conservando el método elegido. Depende de T056
- [ ] T059 [P] [US2] En `pos-heladeria/src/app/modules/tables/pages/checkout/cash-amount-step.component.ts`: la alerta compartida y el bloqueo del botón de continuar (~línea 89), sin perder el monto ya escrito. Depende de T056
- [ ] T060 [P] [US2] En `pos-heladeria/src/app/modules/tables/pages/checkout/transfer-details-step.component.ts`: la alerta compartida y el bloqueo del botón de envío (~línea 185), sin perder el comprobante ya subido. Depende de T056, T057
- [ ] T061 [P] [US2] En `pos-heladeria/src/app/modules/tables/pages/checkout/review-step.component.ts`: la alerta compartida y el bloqueo del botón de confirmar (~línea 49). Depende de T056, T057
- [ ] T062 [US2] Aviso de total y pago mixto (FR-019, research D14). En `pos-heladeria/src/app/modules/tables/services/dining-cart.service.ts` agregar `checkoutTotalSeen = signal<number | null>(null)` (en memoria, se limpia con `clear()` y al terminar el checkout); `checkout-order-summary.component.ts` y los pasos `transfer-details-step.component.ts`, `review-step.component.ts`, `cash-amount-step.component.ts` y `payment-method-step.component.ts` (carpeta `pos-heladeria/src/app/modules/tables/pages/checkout/`) emiten, con `role="status"`, «El total cambió a $X» (mismo formateo de moneda que ya usan) cuando `checkoutTotalSeen()` es distinto del `total()` actual y luego lo actualizan. En los pasos de efectivo/transferencia de un pago mixto: si `CheckoutProgressStore.read()?.cash_amount` es mayor o igual al nuevo `total()`, mostrar «El efectivo ya cubre el total; corrige el monto» con un enlace al paso `cash` y bloquear la confirmación. **No** reimplementar la invalidación del comprobante: `CheckoutProgressStore.write({ cash_amount })` ya limpia `receipt_file_url` cuando el monto cambia (regla de la spec 130). El método y el comprobante se conservan en el resto de los casos; no se valida el monto del comprobante contra el nuevo total (Edge Case). Depende de T057–T061
- [ ] T063 [US2] Ampliar los specs de los pasos en `pos-heladeria/src/app/modules/tables/pages/checkout/`: `cash-amount-step.component.spec.ts`, `transfer-details-step.component.spec.ts`, `review-step.component.spec.ts` (y crear `payment-method-step.component.spec.ts` si no existe): permanece en el paso con lo ya llenado (método, monto, comprobante); la línea aparece marcada; la acción de confirmar está bloqueada; «Volver al carrito» navega al menú con el carrito abierto; tras quitar la línea y bajar el total aparece «El total cambió a $X» y el método y el comprobante siguen; en pago mixto con efectivo ≥ nuevo total se pide corregir el monto. Depende de T062
- [ ] T064 [US2] Verificación manual, quickstart **Escenarios 4, 5 y 6**: carrito de la Terminal en mesa, para llevar, domicilio y orden manual (incluido el caso del sabor «mora»); carrito del menú QR; y los pasos de pago del QR hasta el de transferencia (método, comprobante y monto intactos, «Volver al carrito», aviso de total, corrección del efectivo en pago mixto)

**Checkpoint**: US1 y US2 funcionan juntas; el carrito nunca se vacía por un agotado.

---

## Phase 5: User Story 3 - El servidor sigue siendo la última línea de defensa: condición de carrera con 409 (Priority: P1)

**Goal**: Un pedido con al menos un elemento no pedible (marca manual, falta de insumos, o cantidad que supera lo que alcanza) se rechaza con **un** 409 que lista todos los afectados (id, tipo, nombre, motivo), sin crear nada, y el cliente conserva el carrito y marca solo las líneas afectadas.

**Independent Test**: Con una pantalla que aún no recibió el aviso, enviar un pedido con un producto recién agotado y verificar (a) ninguna orden creada, (b) 409 con `agotados[]`, (c) carrito conservado con solo las líneas afectadas marcadas (quickstart Escenarios 7–8).

**Depends on**: Foundational (motor). La parte del cliente depende de US2 (líneas afectadas y `quantityConflicts`).

### Backend: 409 unificado (research D6, D7; `contracts/sold-out-conflict.md`)

- [ ] T065 [US3] En `pos-backend/app/catalog_engine/availability.py` agregar `SoldOutItem(id, tipo, nombre, producto_id, motivo)` y `sold_out_conflict(items, *, legacy: dict | None = None) -> HTTPException(409)` que arma `detail` con `error` (formato FR-024: «Se agotó: X. Quítalo para continuar» / «Se agotaron: A, B. Quítalos para continuar»), `productos_agotados` (lista de **nombres**), `agotados[]` y las claves heredadas de `legacy` (FR-023). Reglas: lista completa, sin duplicados, orden estable (producto → presentación → opción, luego por nombre); el nombre de una presentación u opción va junto a su producto («Granizado de mora · 16 oz», con `display_name` de la variante, spec 099); cuando el rechazo es de **un solo** elemento por inventario incluye `producto` e `insumo` (forma del antiguo `sold_out_detail`). Depende de T006
- [ ] T066 [US3] En `pos-backend/app/catalog_engine/availability.py` agregar `OrderableLine(variant_id, quantity, options: Sequence[ChosenOption], topping_product_ids)` y `ensure_orderable(db, lines, *, toppings_inventory: bool = True, extra_context=None)`: **antes de mutar nada** reúne (1) productos con marca manual (`motivo: manual`), (2) presentaciones, opciones y adiciones no pedibles según `compute_availability(scope_product_ids=…)` (`motivo: inventario`), y (3) por cada insumo cuyo stock no alcanza para el **consumo agregado** de todas las líneas (`required_consumption`, ya existente), todas las líneas que lo consumen (`motivo: cantidad`, con el `id` de su presentación; D7). Si hay alguno levanta `sold_out_conflict(...)`. Para el carrito QR conserva `insumo`, `disponible`, `requerido` y `contexto` cuando el rechazo es de un solo elemento por inventario o cantidad (los lee `DinerService.stockConflict`). `ensure_orderable` NO consulta el módulo `inventario` por su cuenta (research D19): cada punto de entrada pasa `toppings_inventory` igual que hoy decide si valida el stock de adiciones y toppings; con `False` se omite solo ese chequeo de stock (la marca manual `sold_out` de una adición sigue aplicando) y la receta y las opciones de la línea no cambian. Depende de T065
- [ ] T067 [US3] En el mismo archivo agregar `stock_error_to_conflict(db, exc: InsufficientStockError, variant_id) -> HTTPException(409)` para el guardia final (conserva `producto`/`insumo` del `sold_out_detail` actual), y en `pos-backend/app/catalog_engine/pricing.py` hacer que `ensure_product_available`/`ensure_products_available` deleguen en `sold_out_conflict` (mismo 409 que hoy, ahora con `agotados[]`). `check_availability` **no** se modifica (lo usan también los pagos complementarios, fuera del contrato). Depende de T066
- [ ] T068 [US3] Crear `pos-backend/app/characterization_tests/test_sold_out_conflict.py` con las pruebas del constructor y de `ensure_orderable`: forma exacta del `detail` del contrato; nombre «Producto · presentación»; texto singular y plural; lista completa sin duplicados; los tres motivos (`manual`, `inventario`, `cantidad` con 5 pedidos y stock para 3); claves heredadas presentes. Depende de T067

### Backend: puntos de entrada (todos validan antes de mutar)

- [ ] T069 [P] [US3] En `pos-backend/app/api/v1/orders/service.py`, en `create_order`: reemplazar `ensure_products_available` por `ensure_orderable` **antes de crear la orden o cualquier ítem** (chequeo preventivo de inventario nuevo, H7; es el rechazo de la Terminal). Depende de T067
- [ ] T070 [P] [US3] En `pos-backend/app/api/v1/orders/consolidation.py`, en `add_item_to_order`: reemplazar `ensure_product_available(variant)` (~línea 242) por `ensure_orderable(..., toppings_inventory=inventario_activo)` y el `check_availability` de adiciones (~líneas 290–291, hoy dentro de `if inventario_activo and topping_consumption`) por esa misma llamada, **conservando** la condición `inventario_activo` (`has_module_access(db, tenant, "inventario")`, ~línea 248): sin el módulo no se valida el stock de adiciones ni de toppings; el guardia final del descuento (`InsufficientStockError`) se convierte con `stock_error_to_conflict`. Depende de T067
- [ ] T071 [P] [US3] En `pos-backend/app/api/v1/orders/consumption.py` (`deduct_order_items_naming_product`, ~líneas 109–112, y la verificación de adiciones ~línea 178) y `pos-backend/app/api/v1/orders/checkout.py` (`_deduct_and_open`): convertir el 400 de `sold_out_detail` en el 409 de `stock_error_to_conflict`, conservando el `rollback` total que hoy hace cada ruta. Cubre `checkout-and-send`, `confirm`, `payment-attempts/{id}/approve` y `confirm-cash`. Depende de T067
- [ ] T072 [P] [US3] En `pos-backend/app/api/v1/orders/kitchen.py` (anulación con reemplazo, `void_item`) y `pos-backend/app/api/v1/orders/toppings.py` (`check_availability` ~líneas 116 y 174, adiciones): mismo 409 unificado, sin cambiar el estado de la línea. En `toppings.py` (~líneas 115 y 173) y en `pos-backend/app/api/v1/orders/additions.py` (vía `check_addition_availability`, `consumption.py` ~169, que cambia en T071) la llamada sigue dentro de `if has_module_access(db, tenant, "inventario")`: cambia solo el 409 que se lanza, no la condición; `additions.py` se revisa en esta tarea aunque el cambio de código viva en `consumption.py`. Depende de T067
- [ ] T073 [P] [US3] En `pos-backend/app/api/v1/cart/service.py`: `add_item` (~líneas 426–441), `update_item` (~560–600) y `submit_cart` (~955–1018) usan `ensure_orderable` y conservan las claves del carrito QR (`insumo`, `disponible`, `requerido`, `contexto`). **No** tocar el 409 `productos_no_disponibles` de la spec 128 (que limpia el carrito) ni el de adición desasociada de la spec 129. Depende de T067
- [ ] T074 [US3] Ampliar `pos-backend/app/characterization_tests/test_sold_out_conflict.py` con **un test por punto de entrada de pedidos** (`POST /orders`, `POST /orders/{id}/items`, `checkout-and-send`, `confirm`/`approve`/`confirm-cash`, anulación con reemplazo, adiciones y toppings): (a) status 409, (b) `agotados[]` con `id`/`tipo`/`nombre`/`motivo` correctos, (c) claves heredadas presentes, (d) cero filas nuevas en `customer_orders`, `order_items` e `inventory_movements`, (e) dos productos agotados a la vez, (f) caso `cantidad`. Incluir el caso de un producto agotado **por falta de insumo** (misma forma que el manual) y que la sincronización nunca reemplaza la validación (US3.5). (g) Sin el módulo `inventario` en el plan, una adición o topping con insumo en 0 NO se rechaza (en `consolidation`, `toppings` y `additions`), y con el módulo sí devuelve el 409 unificado; el test existente `test_stock_insuficiente_sin_modulo_de_inventario_no_rechaza` debe seguir en verde SIN editarse. Depende de T069–T072
- [ ] T075 [US3] Ampliar `pos-backend/app/characterization_tests/test_sold_out_conflict.py` con los puntos de entrada del **carrito QR** (`POST /cart/items`, `PATCH /cart/items/{id}`, `POST /cart/submit`): mismos puntos (a)–(f), más las claves `insumo`/`disponible`/`requerido`/`contexto` y que el carrito queda intacto. Depende de T073
- [ ] T076 [US3] Actualizar de forma **explícita** los tests que hoy congelan el comportamiento reemplazado, citando en un comentario la decisión y los números de anomalía de T003 (Principio III), cada uno en el mismo commit que el cambio de código que lo provoca: `pos-backend/app/characterization_tests/test_orders_checkout.py` (~líneas 577–585 y ~984–1001: `confirm_order` y `checkout_and_send`, 400 → 409), `test_orders_payment_gate.py` (~líneas 452–467, `confirm_cash`: 400 → 409, conservando que el intento queda `pendiente` y que no hay movimientos), `test_orders_service.py` (~líneas 1033–1054: `sold_out_detail` ⇒ 409 conservando `producto`/`insumo`) y `test_orders_additions.py` (~líneas 220–222: el `error` deja de ser «Stock insuficiente» y gana `agotados[]`; `insumo` se conserva). Correr toda la suite de `pos-backend` y confirmar que **solo** cambian estas pruebas; `test_cart_sold_out.py`, `test_orders_sold_out.py`, `test_menu_router.py`, `test_menu_sold_out.py` deben seguir en verde, y `test_sales_complementary_payment.py:148` y `test_inventory_stock.py` **no** se tocan (pagos complementarios y motor de stock fuera del contrato). Se editan únicamente las pruebas que afirmen el 400 o el texto «Stock insuficiente» que esta spec reemplaza, y cada una cita en un comentario las anomalías de T003. Cualquier otra prueba que falle es una regresión, no un test a editar. Si aparece una más que afirme ese 400 o ese texto, se agrega a esta lista en el mismo commit. Depende de T069–T073

### Frontend: manejo del 409 (FR-018, FR-024)

- [ ] T077 [US3] En `pos-heladeria/src/app/core/availability/availability.util.ts` agregar `parseSoldOutConflict(err: unknown): SoldOutConflict | null` (lee `HttpErrorResponse.error.detail`; devuelve `null` si no trae `agotados[]`, incluido el 409 `productos_no_disponibles` de la spec 128, que sigue su camino) y `changesFromConflict(conflict, categories): AvailabilityChange[]` (solo los `motivo` `manual`/`inventario`; los de `cantidad` **no** marcan el producto como agotado en el catálogo porque sigue pedible en cantidad 1). Ampliar `availability.util.spec.ts`. Depende de T045
- [ ] T078 [US3] En `pos-heladeria/src/app/modules/tables/services/pos-terminal.store.ts`: en los `catch` de `createManualOrderFromDraft` (~línea 1950) y `saveOrder` (~línea 2466) llamar `parseSoldOutConflict`; si hay conflicto: `availabilitySync.applyLocal(changesFromConflict(...))`, agregar a `quantityConflicts` las claves de las líneas con `motivo:'cantidad'`, fijar `error` con `conflict.error` (el texto de FR-024) y lanzar `void availabilitySync.reconcile()`. **No** tocar `draftLines`. En `saveOrder` las líneas anteriores a la rechazada ya quedaron guardadas (comportamiento existente por línea: `savedKeys`); no cambiarlo. Depende de T047, T077
- [ ] T079 [US3] En `pos-heladeria/src/app/modules/tables/services/dining-cart.service.ts` agregar `applyConflict(conflict)` (mismo tratamiento: `applyLocal` hacia todos los destinos, `quantityConflicts` para `cantidad`, `reconcile()`), sin tocar las líneas del carrito del servidor. Depende de T051, T077
- [ ] T080 [US3] Usar `applyConflict` en los envíos del comensal: `pos-heladeria/src/app/modules/tables/pages/public-menu.component.ts` (los `catch` donde ya se llama `stockConflict`, ~líneas 1007 y 1819, probando `parseSoldOutConflict` **primero**), `pages/checkout/payment-method-step.component.ts` (~línea 121) y `pages/checkout/transfer-details-step.component.ts` (~línea 323): ante un 409 con `agotados[]` la persona **se queda en el paso**, con el método, monto y comprobante intactos (`CheckoutProgressStore` no se toca), la línea marcada y la alerta; «Volver al carrito» ofrece quitarla. Depende de T056, T079
- [ ] T081 [US3] Specs del manejo del 409: en `pos-heladeria/src/app/modules/tables/services/pos-terminal.store.spec.ts` (conflicto manual, inventario y cantidad: el carrito se conserva, solo se marcan las líneas afectadas, el `error` es el de FR-024, el envío sigue bloqueado), `pos-heladeria/src/app/modules/tables/services/dining-cart.service.spec.ts` (`applyConflict`), y en los specs de los pasos de `pos-heladeria/src/app/modules/tables/pages/checkout/` (el 409 en transferencia mantiene el paso, el comprobante y el método). Incluir que el 409 `productos_no_disponibles` de la 128 **no** pasa por este camino. Depende de T078–T080
- [ ] T082 [US3] Verificación manual, quickstart **Escenarios 7 y 8**: dejar la ventana de la mesera desactualizada (bloqueando `/realtime/stream` en DevTools), agotar el producto desde otra sesión y enviar; confirmar 409 con `agotados[]`, ninguna orden nueva (`SELECT count(*) FROM customer_orders` igual que antes), carrito conservado y alerta con el texto de FR-024; repetir con dos productos, con un agotado por falta de insumo, con Redis detenido (SC-007) y con 5 pedidos sobre insumo para 3

**Checkpoint**: US1–US3 completas. El sistema nunca vende un agotado aunque el aviso no llegue.

---

## Phase 6: User Story 4 - Aislamiento estricto entre negocios (Priority: P1)

**Goal**: Los avisos de disponibilidad de un negocio solo llegan a las vistas de ese negocio, y el comensal nunca recibe los avisos internos del personal.

**Independent Test**: Con catálogos abiertos de dos negocios, agotar un producto en uno y verificar que ningún canal del otro recibe nada (quickstart Escenario 9).

**Nota**: el aislamiento sale **por construcción** de reutilizar el stream existente por tenant y de no tocar `app/api/v1/realtime/auth.py` (research D2, H1); esta fase lo **demuestra** con pruebas y no agrega código de producción.

- [ ] T083 [US4] En `pos-backend/app/characterization_tests/test_availability_events.py` agregar las pruebas de aislamiento (patrón de `test_menu_realtime.py`): publicar para el negocio A no agrega ninguna entrada al stream del negocio B; un suscriptor con canales `{session:x, menu:A}` recibe `availability.changed` y **nunca** un evento publicado solo en `staff`; un suscriptor `{staff}` de A lo recibe; el payload lleva solo ids (UUID distintos por negocio) aunque ambos tengan un producto con el mismo nombre, y no incluye nada que permita referenciar productos de otro negocio. Verificar además que el conjunto de canales que obtiene un comensal y uno del personal no cambió respecto de antes de esta spec (FR-030 a FR-032). Depende de T011
- [ ] T084 [US4] Verificación manual, quickstart **Escenario 9**: crear el segundo negocio B (alta de tenant / Super Admin), abrir un menú QR y una Terminal en B y agotar «Granizado de mora» en A; confirmar que ninguna ventana ni canal de B cambia, que `events:tenant:<idB>` no gana entradas, que el producto homónimo de B sigue disponible y que en DevTools el stream del comensal de A solo muestra `availability.changed` y los eventos de su mesa

**Checkpoint**: aislamiento comprobado en pruebas automáticas y con dos negocios reales.

---

## Phase 7: User Story 5 - Recuperación tras perder la conexión en vivo (Priority: P2)

**Goal**: Cuando la vista pierde la conexión en vivo durante 5 s continuos muestra «Sin actualización en vivo» sin bloquear nada, y al volver la conexión (o la pestaña) se pone al día sola, incluidas las líneas del carrito.

**Independent Test**: Cortar la conexión de una vista, cambiar la disponibilidad de varios productos, restablecerla y verificar que catálogo y carrito se actualizan solos y que el indicador aparece y desaparece (quickstart Escenario 10).

**Depends on**: Foundational (snapshot y `reconcile`) y US1 (superficies donde montar el indicador).

- [ ] T085 [US5] En `pos-heladeria/src/app/core/availability/availability-sync.service.ts` agregar los disparadores de reconciliación (`contracts/frontend-surfaces.md`): `RealtimeService.on('reconnected', …)` y `on('resync', …)` ⇒ `reconcile()`; `document.visibilitychange` ⇒ al volver a `visible`, `reconcile()` si la pestaña estuvo oculta más de `HIDDEN_RECONCILE_MS = 10_000` (constante nombrada, D12) o `realtime.status() !== 'open'`; marcar `resyncPending` al detectar la necesidad; si `reconcile()` falla, reintentar con backoff (1 s, 2 s, 4 s… tope 30 s) mientras esté iniciado; `stop()` quita el listener y los temporizadores. Depende de T024
- [ ] T086 [P] [US5] Ampliar `pos-heladeria/src/app/core/availability/availability-sync.service.spec.ts` con fake timers: `reconnected` y `resync` reconcilian; volver de segundo plano antes de 10 s con la conexión abierta no reconcilia, y después de 10 s o con la conexión caída sí; un fallo de la consulta reintenta con backoff y `resyncPending` sigue en `true` hasta que una tiene éxito. Depende de T085
- [ ] T087 [US5] Crear `pos-heladeria/src/app/core/availability/live-status.service.ts` (`providedIn: 'root'`): constante `LIVE_LOST_DELAY_MS = 5000`; observa `RealtimeService.status`; cuando deja de ser `open` arranca el temporizador y, si vence, `liveLost = true`; si vuelve a `open` antes de los 5 s lo cancela (un microcorte no parpadea, FR-025, US5.6); `liveLost` se apaga solo cuando el estado es `open` **y** `AvailabilitySyncService.resyncPending()` es `false` (es decir, tras una reconciliación exitosa). Con su `live-status.service.spec.ts` (fake timers): corte de 4 s ⇒ nunca visible; corte de 5 s ⇒ visible; vuelve la conexión pero la consulta falla ⇒ sigue visible; consulta exitosa ⇒ desaparece. Depende de T085
- [ ] T088 [P] [US5] Crear `pos-heladeria/src/app/core/availability/live-status-indicator.component.ts` (standalone, con su spec): texto fijo «Sin actualización en vivo», `role="status"` y `aria-live="polite"`, discreto (un indicador pequeño en línea, sin modal, sin banner que bloquee ni desplace el contenido, sin `pointer-events` sobre nada) y visible solo con `liveLost()`. Depende de T087
- [ ] T089 [P] [US5] Montar `<app-live-status-indicator>` en el menú QR y los pasos de pago, en la plantilla de `pos-heladeria/src/app/modules/tables/pages/diner-shell.component.ts`. Depende de T088
- [ ] T090 [P] [US5] Montarlo en la cabecera de la Terminal, `pos-heladeria/src/app/modules/tables/components/pos-terminal-header.component.ts` (ya lee `realtimeStatus`; reutilizar esa señal, no abrir otra conexión). Depende de T088
- [ ] T091 [P] [US5] Montarlo en la cabecera de `pos-heladeria/src/app/modules/tables/pages/manual-order-page.component.ts`. Depende de T088
- [ ] T092 [P] [US5] Montarlo en el encabezado de `pos-heladeria/src/app/modules/tables/components/pos-catalog-drawer.component.ts`. Depende de T088
- [ ] T093 [P] [US5] Montarlo en el encabezado de `pos-heladeria/src/app/modules/products/pages/products-page.component.ts` (Carta del menú). Depende de T088
- [ ] T094 [US5] Pruebas de «se pone al día solo» (US5.3): en `pos-heladeria/src/app/modules/tables/services/pos-terminal.store.spec.ts` y `pos-heladeria/src/app/modules/tables/services/dining-cart.service.spec.ts`, aplicar un `applyAvailabilitySnapshot` que agota un producto presente en el carrito ⇒ la línea queda marcada y el envío bloqueado, igual que si el aviso hubiera llegado en vivo; operar sin conexión (agregar, enviar) no queda deshabilitado por el indicador (FR-029). Depende de T047, T051, T085
- [ ] T095 [US5] Verificación manual, quickstart **Escenario 10**: poner la red en «Offline» (el indicador aparece a los 5 s y un corte menor no lo muestra), cambiar varios productos desde otra ventana, restablecer y confirmar la puesta al día de catálogo y carrito; enviar un producto agotado mientras se está desactualizada ⇒ 409; pestaña en segundo plano ~30 s con cambios ⇒ se actualiza al volver; forzar un `resync` reduciendo `REALTIME_STREAM_MAXLEN` en local

**Checkpoint**: las vistas se recuperan solas de una desconexión.

---

## Phase 8: User Story 6 - El agotamiento por inventario avisa igual que el marcado manual (Priority: P2)

**Goal**: Cuando un movimiento de inventario deja un producto, una presentación u opción sin poder pedirse (o lo repone), todas las pantallas abiertas lo muestran (o lo rehabilitan) en menos de 3 s con el mismo aviso que el marcado manual, sin tocar la marca manual y sin avisar de movimientos que no cambian el estado.

**Independent Test**: En un negocio con inventario, llevar a 0 el insumo de una presentación y verificar que las pantallas la muestran «Agotada» en < 3 s; reponer y verificar que vuelve (quickstart Escenario 11).

**Depends on**: Foundational (motor y evento). La parte visible en pantalla ya existe tras US1.

- [ ] T096 [US6] En `pos-backend/app/inventory_engine/stock.py`, en `record_movement` y `apply_adjustment`, registrar `db.info["availability_stock"][item_id] = (stock_inicial, stock_final)` mediante un helper `_track_stock(db, item_id, initial, final)`: el inicial **solo la primera vez** que se toca ese insumo en la transacción, el final en cada movimiento. Registrar inmediatamente antes de `item.current_stock = new_stock` (líneas ~78 y ~113), es decir **después** de la verificación de stock insuficiente, de modo que un movimiento rechazado no deja rastro. Ningún otro cambio de comportamiento (research D4)
- [ ] T097 [P] [US6] En `pos-backend/app/core/db.py`, en `with_db`, agregar una línea que guarde `db.info["tenant_schema"] = tenant_schema` al crear la sesión (H5: las sesiones no conocen el id del tenant)
- [ ] T098 [US6] Crear `pos-backend/app/core/availability_hooks.py` con `install_availability_hooks()` (idempotente, con bandera de módulo) que registra sobre `sqlalchemy.orm.Session`: `before_commit` ⇒ si `session.info.get("availability_stock")` tiene insumos, calcula `compute_availability(session, stock=<iniciales>, scope_item_ids=<ids>)` y lo mismo con `stock=<finales>` y guarda `diff_availability(antes, después)` en `session.info["availability_pending"]`, con cualquier excepción capturada y registrada en el log (el aviso nunca impide el commit, FR-005); `after_commit` ⇒ si hay cambios, resuelve `tenant_id` (`session.info.get("tenant_id")` y, si falta, por `session.info["tenant_schema"]` con una consulta cacheada con `lru_cache` y una sesión corta, FR-031), publica **un solo** `events.availability_changed(tenant_id, changes)` y limpia ambas claves, todo dentro de `try/except` (nunca lanza); `after_rollback` ⇒ limpia ambas claves (FR-004: nunca se anuncia lo que no ocurrió). Sin movimientos de stock en la sesión los tres oyentes retornan de inmediato. **No modifica `Product.available`** (FR-011). Depende de T007, T011, T096, T097
- [ ] T099 [US6] Instalar el gancho **explícitamente**, nunca al importar (para que ninguna suite existente cambie ni hable con Redis): en `pos-backend/app/main.py`, en el `lifespan` junto al arranque de `event_bus` (~línea 68), llamar `install_availability_hooks()`; en `pos-backend/app/celery_task.py` conectarlo a la señal `worker_process_init` de Celery para que lo instale solo el proceso del worker. Depende de T098
- [ ] T100 [US6] Crear `pos-backend/app/characterization_tests/test_availability_hooks.py` (instalando el gancho en la prueba y parchando `events.publish`/`availability_changed`; fijando `db.info["tenant_id"]` en SQLite): commit con un movimiento que cruza a 0 ⇒ **un** evento con la presentación y el producto afectados; reponer ⇒ un evento de regreso; stock 10 → 9 ⇒ ninguno (US6.6); una venta que baja y repone el mismo insumo en la misma transacción ⇒ ninguno; insumo compartido por varios productos/presentaciones/opciones ⇒ **un** evento con todos (FR-010); rollback ⇒ ninguno; commit sin movimientos ⇒ ninguno y sin consultas extra; más de `AVAILABILITY_EVENT_MAX_CHANGES` ⇒ `refresh:true`; si el cálculo o la publicación fallan el commit se completa igual; `Product.available` no cambia en ningún caso; el gancho publica después del commit. Depende de T098
- [ ] T101 [US6] En `test_availability_hooks.py` agregar el test guardia estático (research D4, riesgo): recorrer `pos-backend/app` (excluyendo `app/scripts/`, `characterization_tests/` y `inventory_engine/stock.py`) y fallar si aparece una asignación de atributo a `current_stock` (`.current_stock =` o `+=`/`-=`); hoy solo existen las dos de `stock.py`, y los usos como argumento de constructor (`InventoryItem(current_stock=…)`, p. ej. `api/v1/inventory/import_.py:426`) crean insumos nuevos sin dependientes y no cuentan. Así un movimiento futuro que evite `record_movement`/`apply_adjustment` rompe la suite en vez de dejar de avisar. Depende de T096
- [ ] T102 [P] [US6] En `pos-backend/app/characterization_tests/test_menu_sold_out.py` (o `test_menu_router.py`) agregar: `GET /menu` muestra la presentación con insumo de receta en 0 como `available:false` y el producto `available:false` solo si era la única (US6.1/US6.7); un producto marcado a mano con insumo suficiente sigue `sold_out:true` tras mover el inventario (US6.4); un producto sin marca y sin insumo conserva `Product.available = True` en la base de datos antes y después de los movimientos y de los commits con el gancho (US6.5, FR-011). Depende de T009
- [ ] T103 [P] [US6] Pruebas del cliente para el nivel presentación/opción (US6.7, FR-017): en `pos-heladeria/src/app/modules/tables/components/product-select.component.spec.ts` y `product-select-pos.component.spec.ts`, un cambio `kind:'variant'` deja esa presentación «Agotada» y no seleccionable mientras el producto sigue seleccionable y las otras presentaciones también; un cambio `kind:'option'` agota esa opción; en `pos-heladeria/src/app/modules/products/pages/products-page.component.spec.ts`, un cambio que solo trae el `available` derivado (sin diferencia en `sold_out`) **no** llama `refreshOne`. Depende de T039
- [ ] T104 [US6] Verificación manual, quickstart **Escenario 11** (pasos 1–10): presentación «16 oz» a una sola preparación y venderla; reponer; opción «mora»; todas las presentaciones; insumo compartido (una sola entrada en `XRANGE` con varios `changes`); marca manual con insumo suficiente; insumo en 0 con marca manual «disponible» (el interruptor de la Carta no cambia); movimiento 10 → 9 (ninguna entrada nueva)

**Checkpoint**: las seis historias funcionan juntas.

---

## Phase 9: Polish & Cross-Cutting Concerns

- [ ] T105 **[Requiere confirmación del usuario antes de empezar]** Registrar `'menu.updated'` en `KNOWN_EVENT_TYPES` de `pos-heladeria/src/app/core/realtime/sse-client.ts` y retirar la excepción de `known-event-types.spec.ts` (research D13, hallazgo H8): hoy el evento de la spec 128 llega pero `EventSource` lo descarta, así que el refresco en vivo de categorías ocultas **no funciona en producción**; registrarlo lo activa por primera vez, que es la intención documentada de la 128 pero un cambio observable. Va en **commit propio y reversible**. Si el usuario prefiere no hacerlo, dejar la excepción documentada en el test guardia y cerrar la tarea sin cambios
- [ ] T106 Verificación manual, quickstart **Escenario 12** (regresión de la spec 128): con el menú QR abierto, ocultar una categoría en QR y confirmar que el menú del comensal se actualiza solo (solo aplica si T105 se hizo)
- [ ] T107 Regresión completa del backend (`pos-backend`, `./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`) y comparación con `checklists/baseline-suites.md`: ninguna prueba nueva en rojo y solo cambian las de T076. Ejecutar **después** de T108 o antes, nunca al mismo tiempo
- [ ] T108 Regresión completa del frontend (`pos-heladeria`, `ng test --watch=false` más los `--include` de `quickstart.md`) comparando **por nombre de prueba** con `checklists/baseline-suites.md`: ningún fallo nuevo respecto de la línea base
- [ ] T109 Medir los presupuestos técnicos de `quickstart.md`: latencia de propagación p99 < 3 s con 20 muestras (SC-001); gancho de sesión ≤ 50 ms p95 con 300 productos; snapshot `GET /menu/availability` ≤ 100 ms p95 (`curl -w '%{time_total}'`); volumen de eventos proporcional a transacciones y no a elementos (`XLEN` antes y después de una hora simulada). Registrar los números en `quickstart.md`
- [ ] T110 [P] Revisar `docs-publicos/` y `srs/` (en la raíz de `pos-specs`): si describen el interruptor «Agotado» (spec 093), el menú QR o la Terminal, actualizar para reflejar el aviso en vivo, el agotado por inventario, el 409 con lista y el indicador «Sin actualización en vivo»; si no los describen, no agregar nada
- [ ] T111 Cierre: restablecer las marcas manuales y las existencias de los insumos de prueba (`quickstart.md` §Limpieza; esta spec no crea datos propios); anotar el orden de despliegue para quien lo ejecute — **backend primero** (aditivo: el evento es ignorado por clientes viejos y el 409 conserva todas las claves previas) y después el frontend, con una recarga manual única de las pestañas ya abiertas (mismo caso que la spec 134); marcar en `plan.md` y `spec.md` el estado de implementación

---

## Cobertura de requisitos

| Requisito | Tareas |
|---|---|
| FR-001, FR-002 | T011, T028, T098, T030, T033, T035, T037, T039, T044 |
| FR-003 (cuatro superficies) | T033, T035–T037, T039 |
| FR-004, FR-005 | T011, T028, T029, T098, T100 |
| FR-006 | T022, T023, T024, T025 |
| FR-007 | T011, T013 |
| FR-008, FR-009, FR-010 | T006, T007, T009, T010, T098, T100 |
| FR-011 | T006, T098, T100, T102 |
| FR-012 | T022, T033, T035, T037, T040 |
| FR-013 a FR-018 | T045–T054 |
| FR-019 | T055–T063 |
| FR-020 | T033–T037 |
| FR-021, FR-022, FR-023 | T065–T075 |
| FR-024 | T045, T065, T077–T082 |
| FR-025 | T087, T088, T089–T093 |
| FR-026, FR-027, FR-028 | T015, T016, T024, T085, T086 |
| FR-029 | T088, T094, T095 |
| FR-030, FR-031, FR-032 | T016, T083, T084, T098 |
| FR-033 | T028, T029 |
| SC-001 | T044, T109 |
| SC-002 | T050, T052, T064 |
| SC-003 | T074, T075, T082 |
| SC-004 | T083, T084 |
| SC-005 | T086, T087, T094, T095 |
| SC-006 | T100, T104 |
| SC-007 | T082 |

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias. T003 (anomalías) **bloquea todo el código**.
- **Foundational (Phase 2)**: depende de Setup. **Bloquea** todas las historias.
- **User Stories (Phase 3–8)**: dependen de Foundational. Prioridad P1 → P2.
- **Polish (Phase 9)**: depende de las historias deseadas. T105 necesita confirmación del usuario.

### User Story Dependencies

- **US1 (P1)**: tras Foundational. Sin dependencias de otras historias. **MVP.**
- **US2 (P1)**: tras US1 (necesita el menú parchado en vivo para que la línea se marque sola).
- **US3 (P1)**: la parte de backend (T065–T076) solo depende de Foundational y puede hacerse en paralelo con US1/US2; la del cliente (T077–T081) depende de US2.
- **US4 (P1)**: solo pruebas; depende de T011. Puede hacerse en cualquier momento tras Foundational.
- **US5 (P2)**: tras Foundational y US1 (superficies donde montar el indicador).
- **US6 (P2)**: el backend (T096–T102) solo depende de Foundational; lo que se ve en pantalla ya existe tras US1.

### Within Each User Story

- Pruebas de equivalencia/congelamiento **antes** de mover código (T005 → T006).
- Motor → evento/publicación → superficies.
- Funciones puras → store/servicio → componentes → specs → verificación manual.
- El backend se despliega retrocompatible tras cada fase (evento ignorado por clientes viejos; 409 aditivo).

### Parallel Opportunities

- T001 ∥ T002.
- Foundational: el bloque backend (T005–T017) y el bloque frontend (T018–T027) son independientes entre sí. Dentro: T013 ∥ T014; T018 ∥ T019.
- US1: T030 ∥ T031; T038 en paralelo con T033–T037; T040–T043 son specs de archivos distintos.
- US2: T048 ∥ T049; T058 ∥ T059 ∥ T060 ∥ T061 (cuatro pasos).
- US3: T069 ∥ T070 ∥ T071 ∥ T072 ∥ T073 (cinco archivos distintos tras T067).
- US5: T089 ∥ T090 ∥ T091 ∥ T092 ∥ T093 (cinco montajes).
- US3-backend ∥ US6-backend ∥ US4 pueden avanzar a la vez con US1/US2-frontend si hay más de una persona.

---

## Parallel Example: Foundational (frontend ∥ backend)

```bash
# Dos personas, dos repos, sin tocar los mismos archivos:
Persona A (pos-backend):  T005 → T006 → T007 → T008 → T009 → T010,  T011 → T012 → T013/T014 → T015 → T016 → T017
Persona B (pos-heladeria): T018/T019 → T020 → T021,  T022 → T023,  T024 → T025,  T026 → T027
```

## Parallel Example: User Story 3 (puntos de entrada)

```bash
# Tras T067, cinco archivos distintos a la vez:
Task: "create_order → ensure_orderable en pos-backend/app/api/v1/orders/service.py"            (T069)
Task: "add_item_to_order en pos-backend/app/api/v1/orders/consolidation.py"                    (T070)
Task: "guardia final en orders/consumption.py y orders/checkout.py"                            (T071)
Task: "kitchen.py y toppings.py"                                                               (T072)
Task: "add_item/update_item/submit_cart en pos-backend/app/api/v1/cart/service.py"            (T073)
```

---

## Implementation Strategy

### MVP First (User Story 1 only)

1. Phase 1: Setup (incluida la anomalía de T003)
2. Phase 2: Foundational (motor + evento + snapshot + sincronizador)
3. Phase 3: US1
4. **PARAR y VALIDAR**: quickstart Escenarios 1–3 con la Terminal, el QR y la Carta
5. Desplegar si está listo (backend primero)

El MVP deja el carrito sin marcar (US2) y el inventario sin avisar (US6), pero **el servidor ya rechaza lo agotado** con el 409 existente, así que no hay regresión de seguridad operativa.

### Incremental Delivery

1. Setup + Foundational → base lista (backend retrocompatible)
2. + US1 → el agotado manual se ve sin recargar (MVP)
3. + US2 → el carrito reacciona sin perderse
4. + US3 → 409 unificado con lista (cambio de comportamiento autorizado en T003)
5. + US4 → aislamiento demostrado
6. + US5 → recuperación de la conexión
7. + US6 → agotado por inventario
8. Polish → regresión, presupuestos, `menu.updated` (con confirmación)

Equivalencia con las fases del plan: F0 = Setup · F1 = Foundational (backend) · F2 = T028–T029 y US6 (T096–T102) · F3 = US3 backend · F4 = Foundational (frontend) + US5 núcleo · F5 = superficies de US1/US2/US3-cliente · F6 = Polish.

### Parallel Team Strategy

Con dos desarrolladores: uno en `pos-backend` (Foundational backend → US3 backend → US6 backend) y otro en `pos-heladeria` (Foundational frontend → US1 → US2 → US3 cliente → US5). US4 son pruebas y se reparten.

---

## Notes

- **[P]** = archivos distintos, sin dependencia de una tarea incompleta del mismo grupo.
- Cada historia es completable y verificable por sí sola (con las dependencias indicadas arriba).
- Verificar que las pruebas de congelamiento (T005) pasen **antes** de mover el cálculo y que los tests de T076 se editen citando la anomalía; nunca editar un test para «hacerlo pasar» sin la decisión registrada (Principio III).
- No cambiar `app/api/v1/realtime/auth.py`, `CheckoutProgressStore`, `Product.available` por efecto del inventario, ni los 409 de las specs 128 (`productos_no_disponibles`) y 129 (adición desasociada).
- **Hallazgos al generar las tareas** (no estaban explícitos en el plan):
  1. Las tarjetas del catálogo de la Terminal (`manual-order-page.component.ts`) hoy **no** pintan ni bloquean el agotado; el plan lo daba por cubierto porque solo cita el QR y el drawer. Se agrega en T035.
  2. `payment-method-step` y `cash-amount-step` **no** muestran `CheckoutOrderSummaryComponent` (solo `review-step` y `transfer-details-step`), así que FR-019 se cumple con una alerta compartida (T056) además de la marca en el resumen donde existe (T057).
  3. `set_product_availability` no recibe el `Tenant` (T028) y el servicio no devuelve el valor previo; se lee antes de llamarlo.
  4. `saveOrder` envía las líneas una por una a un pedido existente; un 409 a mitad deja guardadas las anteriores (comportamiento existente, T078). La garantía «no se crea nada, ni parcial» aplica por petición.
  5. **Brecha conocida**: las líneas `kind:'combo'` de la Terminal no se derivan en el cliente (sus componentes no se resuelven contra el índice). El servidor igual las rechaza con el 409 y la alerta se muestra, pero la línea no queda marcada. Si el dueño lo necesita, es una tarea adicional.
  6. El texto de `error` del 409 pasa a ser el de FR-024 en todos los puntos de entrada del contrato (también donde hoy decía «Stock insuficiente»); por eso T076 incluye `test_orders_additions.py`. Los pagos complementarios (`sales/complementary.py`) no están en el contrato y conservan su comportamiento.
- Commits solo a pedido del usuario, pequeños y por repo; el registro de `menu.updated` (T105) y la actualización de los tests protegidos (T076) van cada uno en su propio commit.
