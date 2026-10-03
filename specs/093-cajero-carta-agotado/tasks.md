---

description: "Task list template for feature implementation"
---

# Tasks: Carta del menú para Cajero con estado Agotado

**Input**: Design documents from `/specs/093-cajero-carta-agotado/`
**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: Incluidos — la Constitución del proyecto (Principio X, Verificación
Obligatoria) exige tests de la nueva funcionalidad además de los criterios de
aceptación del spec; `plan.md` ya se comprometió a incluirlos en esta fase.

**Organization**: Las tareas están agrupadas por historia de usuario (spec.md) para
poder implementar y probar cada una de forma independiente.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Puede ejecutarse en paralelo (archivo distinto, sin dependencias pendientes)
- **[Story]**: A qué historia de usuario pertenece (US1, US2, US3)
- Cada tarea incluye la ruta exacta del archivo

## Path Conventions

Dos repos hermanos (sin carpeta nueva en ninguno, ver `plan.md` § Project Structure):
- Backend: `../pos-backend/app/...`, `../pos-backend/alembic/...`
- Frontend: `../pos-heladeria/src/app/...`

---

## Phase 1: Setup

**Purpose**: Preparar las ramas de trabajo antes de tocar código (Constitución,
Principio XIV — crear la rama antes de modificar nada, nunca después).

- [X] T001 Crear la rama `feat/093-cashier-menu-sold-out` en `pos-backend`, partiendo de la rama actual
- [X] T002 [P] Crear la rama `feat/093-cashier-menu-sold-out` en `pos-heladeria`, partiendo de la rama actual

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Infraestructura que las tres historias de usuario necesitan antes de
poder implementarse.

**⚠️ CRITICAL**: Ninguna historia de usuario puede empezar hasta cerrar esta fase.

- [X] T003 Agregar columnas `available_changed_at: Mapped[Optional[datetime]]` y `available_changed_by_name: Mapped[Optional[str]]` (ambas nullable, sin FK) a la clase `Product` en `../pos-backend/app/models/product.py` (data-model.md)
- [X] T004 Crear la migración de Alembic que agrega esas dos columnas a `tenant.products` en cada schema de tenant (up) y las elimina (down), siguiendo el mecanismo `for_each_tenant_schema` ya usado por el repo, en `../pos-backend/alembic/versions/<nueva>_product_availability_audit_columns.py` (depende de T003)
- [X] T005 [P] Agregar la dependencia `require_tenant_admin_or_cashier` (403 si `user.role.name` no es `"ADMIN"` ni `"CASHIER"`) en `../pos-backend/app/core/dependencies.py` (research.md D1/D2)
- [X] T006 [P] Agregar el schema `ProductAvailabilityUpdate` (`{"available": bool}`) en `../pos-backend/app/api/v1/products/schemas.py` (research.md D3)

**Checkpoint**: Fundamento listo — las historias de usuario pueden empezar.

---

## Phase 3: User Story 1 - Consultar la carta y marcar productos como agotados (Priority: P1) 🎯 MVP

**Goal**: El Cajero ve "Carta del menú" en solo lectura (listado + detalle) y puede
marcar/desmarcar cualquier producto activo como "Agotado"; el Administrador conserva
todas sus acciones actuales y usa el mismo interruptor.

**Independent Test**: Iniciar sesión como Cajero, entrar a "Carta del menú", buscar/
filtrar, abrir el detalle de un producto y alternar su interruptor "Agotado",
verificando la etiqueta, el toast de confirmación y que queda registrado con usuario y
hora; repetir el toggle como Administrador y confirmar que conserva sus demás acciones.

### Tests for User Story 1 ⚠️

- [X] T007 [P] [US1] Test: `PATCH /products/{id}/availability` como `CASHIER` pone `available=false`, responde 200, y dejó una fila en `AuditLog` (`action="availability_changed"`) con el usuario; `available_changed_at`/`available_changed_by_name` quedan en el producto — en `../pos-backend/app/characterization_tests/test_product_availability_toggle.py`
- [X] T008 [P] [US1] Test: `PATCH /products/{id}/availability` sobre un producto con `active=False` → 409, sin modificar `available` — mismo archivo
- [X] T009 [P] [US1] Test: `PATCH /products/{id}/availability` como `MESERO` (u otro rol no autorizado) → 403, nada se modifica — mismo archivo
- [X] T010 [P] [US1] Test: `GET /products/{id}` incluye `variants` (solo las `active=true`, con `id`/`sku`/`price`/`active`/`presentation_id`/`presentation_name`) y **no** incluye receta ni grupos de opciones — en `../pos-backend/app/characterization_tests/test_product_detail_variants.py`

### Implementation for User Story 1

- [X] T011 [US1] Implementar `ProductService.set_availability(db, tenant, id, available, user)` en `../pos-backend/app/api/v1/products/service.py`: 404 si no existe en el tenant, 409 si `active=False`, si no actualiza `available` + `available_changed_at` (ahora) + `available_changed_by_name` (nombre del usuario) con un único `UPDATE` sin bloqueo (research.md D10), y llama a `record_audit(db, action="availability_changed", entity="product", entity_id=product.id, user=user, payload={"available": ..., "previous": ...})` (depende de T003, T006)
- [X] T012 [US1] Agregar la ruta `PATCH /products/{id}/availability` en `../pos-backend/app/api/v1/products/router.py`, protegida por `require_tenant_admin_or_cashier`, delegando en `ProductService.set_availability` (depende de T005, T011)
- [X] T013 [US1] Extender `ProductResponse` con `available_changed_at: datetime | None` y `available_changed_by_name: str | None` en `../pos-backend/app/api/v1/products/schemas.py` (depende de T003)
- [X] T014 [US1] Extender `ProductDetailResponse` con `variants: list[VariantResponse]` (solo activas, sin receta ni grupos de opciones) y armar esa lista en `ProductService.get_or_404`/un nuevo `to_detail_response()` en `../pos-backend/app/api/v1/products/service.py` + `schemas.py` (depende de T013)
- [X] T015 [P] [US1] Agregar `UserRole.CASHIER` al arreglo `roles` del `NavItem` "Carta del menú" en `../pos-heladeria/src/app/core/config/navigation.config.ts` (contracts/frontend-route-access.md)
- [X] T016 [P] [US1] Agregar `UserRole.CASHIER` al `roleGuard` de la ruta `products` y crear la ruta nueva `products/:id/detalle` con `roleGuard([UserRole.ADMIN, UserRole.CASHIER])` en `../pos-heladeria/src/app/modules/dashboard/routes.ts`
- [X] T017 [US1] Agregar `isAdmin = computed(() => auth.currentUser()?.role === UserRole.ADMIN)` en `ProductsPageComponent`; ocultar "Nuevo producto" y las acciones de editar/desactivar cuando `!isAdmin()`; el clic en una fila / "Ver detalle" navega a `/dashboard/products/:id` si es Admin y a `/dashboard/products/:id/detalle` si es Cajero — en `../pos-heladeria/src/app/modules/products/pages/products-page.component.ts` (depende de T016). También: filtro Todos/Disponibles/Agotados (FR-006, nuevo query param `available` en `GET /products` — gap detectado durante la implementación, agregado a `products/router.py`+`service.py`) e interruptor "Agotado" deshabilitado cuando `!product.active` (escenario 10)
- [X] T018 [US1] Cambiar `ProductService.toggleAvailable()` para llamar a `PATCH /products/{id}/availability` (en vez del PATCH completo de producto); agregar `available_changed_at`/`available_changed_by_name` a la interfaz `Product`/`ProductResponse` — en `../pos-heladeria/src/app/modules/products/services/product.service.ts` y `../pos-heladeria/src/app/modules/products/interfaces/product.interface.ts` (depende de T012, T013)
- [X] T019 [P] [US1] Crear el pipe `relative-time.pipe.ts` ("hace unos segundos" / "hace N minutos" / "hace N horas", con fallback a fecha absoluta vía `TenantDatePipe` pasado cierto umbral) en `../pos-heladeria/src/app/shared/relative-time.pipe.ts` (research.md D13)
- [X] T020 [US1] Crear `ProductDetailPageComponent` de solo lectura (imagen, nombre, descripción, categoría, tipo de preparación, presentaciones con precio, estado, disponibilidad, interruptor "Agotado"; sin costo/receta/inventario) en `../pos-heladeria/src/app/modules/products/pages/product-detail-page.component.ts` (depende de T014, T018, T019)
- [X] T021 [P] [US1] Test de componente: `products-page.component.spec.ts` — Admin ve "Nuevo producto"/editar/desactivar y navega al formulario de edición; Cajero no los ve, navega al detalle de solo lectura, y ambos pueden usar el interruptor "Agotado" sin ver ningún error de permisos
- [X] T022 [P] [US1] Test de componente: `product-detail-page.component.spec.ts` — renderiza los campos de solo lectura, el interruptor funciona, y no se renderiza costo/receta/inventario

**Checkpoint**: User Story 1 completamente funcional y verificable de forma
independiente.

---

## Phase 4: User Story 2 - Evitar pedidos de productos agotados (Priority: P2)

**Goal**: Un producto marcado "Agotado" sigue visible (atenuado) en la Terminal de
mesas y el menú QR, pero no se puede agregar a un pedido nuevo; un carrito armado antes
del cambio se rechaza al confirmar sin crear ninguna orden; los pedidos ya existentes no
se alteran.

**Independent Test**: Marcar un producto como agotado y verificar, por separado, que
(a) aparece atenuado y sin poder agregarse en la Terminal de mesas, (b) igual en el menú
QR, (c) un carrito armado antes del cambio es rechazado al confirmar, nombrando el
producto, sin crear la orden, y (d) un pedido pendiente previo con ese producto sigue su
flujo normal.

### Tests for User Story 2 ⚠️

- [X] T023 [P] [US2] Test: `GET /menu` y `GET /menu/qr-token/{token}` siguen devolviendo un producto con `available=false` (ya no se oculta), con el campo nuevo `sold_out=true`; el campo existente `available` (pedible por stock) no cambia de significado — en `../pos-backend/app/characterization_tests/test_menu_sold_out.py` (verificado explícitamente: `test_menu_router.py` sigue en verde sin tocarlo)
- [X] T024 [P] [US2] Test: `POST /cart/items` y `PATCH /cart/items/{id}` con una variante cuyo producto está agotado → 409 nombrando el producto — en `../pos-backend/app/characterization_tests/test_cart_sold_out.py`
- [X] T025 [P] [US2] Test: `POST /cart/submit` con uno o más ítems agotados en el carrito → 409 listando **todos** los productos agotados, no se crea ninguna orden, el carrito se conserva intacto — mismo archivo
- [X] T026 [P] [US2] Test: `POST /orders/{order_id}/items` con una variante agotada → 409 — en `../pos-backend/app/characterization_tests/test_orders_sold_out.py`
- [X] T027 [P] [US2] Test: `POST /orders` (pedido manual) con uno o más ítems agotados → 409 listando todos — mismo archivo
- [X] T028 [P] [US2] Test: un pedido creado **antes** de marcar un producto como agotado no se modifica ni se revalida al consultarlo/avanzar su flujo después del cambio — mismo archivo

### Implementation for User Story 2

- [X] T029 [US2] Quitar `Product.available.is_(True)` del `WHERE` de `_build_menu()`; agregar `sold_out: bool` a `MenuProductResponse` calculado como `not product.available` — en `../pos-backend/app/api/v1/menu/router.py` y `../pos-backend/app/api/v1/menu/schemas.py` (depende de T023)
- [X] T030 [US2] Agregar el chequeo `if not variant.product.available: raise HTTPException(409, {"error": ..., "producto": nombre})` en `add_item`/`update_item` — en `../pos-backend/app/api/v1/cart/service.py` (depende de T024). Implementado como `ensure_product_available()`, nuevo helper compartido en `app/catalog_engine/pricing.py` (reexportado vía `catalog_engine/__init__.py` y `catalog/line_pricing.py`, research.md D7 "alternativa preferida")
- [X] T031 [US2] Agregar en `submit_cart` el barrido de todos los ítems del carrito antes de crear la orden: si hay uno o más agotados, `HTTPException(409, {"error": ..., "productos_agotados": [...]})` y no crear nada — en `../pos-backend/app/api/v1/cart/service.py` (depende de T030, mismo archivo — secuencial; depende también de T025). Implementado como `ensure_products_available()`, mismo helper compartido
- [X] T032 [P] [US2] Agregar el mismo chequeo single-item en `add_item_to_order` — en `../pos-backend/app/api/v1/orders/consolidation.py` (depende de T026)
- [X] T033 [P] [US2] Agregar el mismo chequeo multi-item (listando todos los agotados) en `create_order` — en `../pos-backend/app/api/v1/orders/service.py` (depende de T027). Requirió refactor mínimo: resolver todas las variantes del pedido ANTES de crear cualquier `OrderItem`, para poder nombrar todos los agotados de una sola vez en vez de abortar en el primero
- [X] T034 [P] [US2] Agregar `sold_out: boolean` a la interfaz del producto de menú (`MenuProduct`) en `../pos-heladeria/src/app/modules/products/interfaces/product.interface.ts` (depende de T029). Mapeado en los dos lugares que construyen `MenuProduct` desde JSON crudo: `core/services/menu.service.ts` (Terminal de mesas) y `modules/tables/services/diner.service.ts` (menú QR, mapeo propio sin tipos compartidos — gap detectado durante la implementación)
- [X] T035 [P] [US2] Atenuar la tarjeta, mostrar la etiqueta "Agotado" y deshabilitar abrir/agregar cuando `product.sold_out` — en `../pos-heladeria/src/app/modules/tables/components/pos-catalog-drawer.component.ts` (depende de T034)
- [X] T036 [P] [US2] Mismo tratamiento en `../pos-heladeria/src/app/modules/tables/pages/public-menu.component.ts` (depende de T034)
- [X] T037 [P] [US2] Tests de componente para ambas grillas (tarjeta atenuada, etiqueta, clic/agregar deshabilitado) en sus respectivos `.spec.ts`. `MenuProduct.sold_out` se declaró opcional (no obligó a actualizar los fixtures de `MenuProduct` ya existentes en el resto del repo, gap detectado al correr la suite completa)

**Checkpoint**: User Story 1 y 2 funcionan de forma independiente.

---

## Phase 5: User Story 3 - Garantías de seguridad, aislamiento y consistencia (Priority: P3)

**Goal**: El sistema hace cumplir por sí mismo (no solo en pantalla) los permisos, los
datos visibles por API y el aislamiento entre tenants, y se comporta de forma
predecible ante fallas de red o cambios simultáneos.

**Independent Test**: Enviar peticiones directas (sin pasar por la interfaz) para
crear/editar/desactivar un producto como Cajero y verificar el 403; consultar la receta
de una variante como Cajero y verificar el 403; simular una falla de red al marcar un
producto; enviar dos cambios de estado casi simultáneos; intentar acceder a un producto
de otro tenant.

### Tests for User Story 3 ⚠️

- [X] T038 [P] [US3] Test: `GET /variants/{variant_id}/recipe` como `CASHIER` → 403; como `ADMIN` → 200 sin cambios — en `../pos-backend/app/characterization_tests/test_recipe_role_restriction.py`
- [X] T039 [P] [US3] Test de regresión: `POST`/`PATCH`/`PUT`/`DELETE /products(/{id})` como `CASHIER` → 403, nada se modifica (deja constancia explícita de la garantía que pide la spec sobre comportamiento ya existente) — en `../pos-backend/app/characterization_tests/test_products_cashier_forbidden.py`
- [X] T040 [P] [US3] Test: `GET`/`PATCH /products/{id}/availability` sobre un producto de otro tenant → 404 — implementado en `../pos-backend/app/characterization_tests/test_product_availability_toggle.py::test_producto_de_otro_tenant_responde_404` (US1)
- [X] T041 [P] [US3] Test: dos llamadas sucesivas a `PATCH /products/{id}/availability` con valores distintos (`true` luego `false`) dejan como resultado final el de la última procesada, sin estado intermedio inconsistente — implementado en `../pos-backend/app/characterization_tests/test_product_availability_toggle.py::test_dos_cambios_sucesivos_dejan_el_ultimo_valor` (US1)

### Implementation for User Story 3

- [X] T042 [US3] Bloquear `role.name == "CASHIER"` (403) en `GET /variants/{variant_id}/recipe`, sin afectar a `ADMIN` ni al default-deny ya existente de `MESERO` — en `../pos-backend/app/api/v1/catalog/router.py` (depende de T038). Nueva dependencia `forbid_cashier` en `../pos-backend/app/core/dependencies.py`
- [X] T043 [US3] Confirmar/ajustar que un fallo del `PATCH /products/{id}/availability` deja la fila sin cambios visuales (el patrón no-optimista ya existente: `isSubmitting → await → invalidar query` solo corre en éxito) y muestra un toast de error — en `../pos-heladeria/src/app/modules/products/services/product.service.ts` y `products-page.component.ts`. Ya lo satisfacía el patrón existente (`run()`) sin cambios de código; de paso se corrigió el texto de confirmación de éxito para que coincida exactamente con el escenario 3 ("Fresa boom marcado como agotado", antes `"Fresa boom" marcado agotado`) en `products-page.component.ts` y `product-detail-page.component.ts`
- [X] T044 [P] [US3] Test de componente: una falla simulada del PATCH deja el interruptor en su valor previo y muestra el toast de error (escenario 13)

**Checkpoint**: Las tres historias de usuario funcionan de forma independiente.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T045 [P] Ejecutar `quickstart.md` de punta a punta sobre un tenant local (ambos roles, ambos repos) y dejar constancia del resultado en `specs/093-cajero-carta-agotado/implementation-notes.md`. **Parcial**: este entorno no tiene PostgreSQL/Docker (solo Redis) — no se pudo levantar un tenant real para el recorrido manual de punta a punta; queda documentado como pendiente explícito en `implementation-notes.md`, con lo que sí se verificó (cobertura automatizada de los 16 escenarios) y lo que falta
- [X] T046 Ejecutar la suite completa de characterization tests del backend (`python -m unittest discover app/characterization_tests` en `pos-backend`) y confirmar que no hay regresiones más allá de las autorizadas por A-104. **1290/1290 OK**, sin tocar ningún test `"CONGELA comportamiento actual:"` existente
- [X] T047 [P] Ejecutar las suites de Vitest/Playwright del frontend y confirmar que no hay regresiones. `ng build` limpio; `ng test --no-watch` con el mismo baseline de 19 fallas pre-existentes en 6 archivos no relacionados (confirmado contra `develop` limpio vía `git stash -u`) — memoria `how-to-run-sibling-repo-tests` actualizada con este baseline y con los hallazgos de timing de TanStack Query en tests. Playwright no se ejecutó (requiere un backend real corriendo, ver T045)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias — puede iniciar de inmediato
- **Foundational (Phase 2)**: depende de Setup — bloquea las tres historias de usuario
- **User Stories (Phase 3-5)**: todas dependen de Foundational
  - US1 y US2 son independientes entre sí (ninguna necesita que la otra esté terminada para probarse)
  - US3 reutiliza el endpoint de US1 (`PATCH /products/{id}/availability`) para sus tests de concurrencia (T041) y tenant (T040), así que esas dos tareas puntuales solo pueden correr después de T012 — el resto de US3 (T038/T039/T042/T043/T044) es independiente de US1/US2
- **Polish (Phase 6)**: depende de que las historias que se vayan a entregar estén completas

### User Story Dependencies

- **User Story 1 (P1)**: puede empezar tras Foundational — sin dependencia de otras historias
- **User Story 2 (P2)**: puede empezar tras Foundational — no depende de US1 en código (usa `Product.available`, que ya existe desde antes de esta spec), aunque probarla manualmente es más natural teniendo ya el interruptor de US1 para marcar productos
- **User Story 3 (P3)**: puede empezar tras Foundational; T040/T041 reutilizan el endpoint de US1 (ver arriba)

### Within Each User Story

- Tests antes que implementación (deben fallar primero)
- Modelos/esquemas antes que servicios; servicios antes que endpoints; backend antes que frontend dentro de cada historia (el frontend consume el endpoint ya implementado)

### Parallel Opportunities

- T001/T002 (ramas de los dos repos)
- T005/T006 dentro de Foundational
- Todos los tests `[P]` de una misma historia (archivos nuevos, independientes entre sí)
- T015/T016 (archivos de frontend distintos); T032/T033 (archivos de backend distintos); T035/T036 (componentes distintos)
- T045/T047 en Polish

---

## Parallel Example: User Story 1

```bash
# Tests de User Story 1, en paralelo:
Task: "PATCH /products/{id}/availability como CASHIER → 200 + AuditLog en test_product_availability_toggle.py"
Task: "PATCH /products/{id}/availability sobre producto inactivo → 409 en test_product_availability_toggle.py"
Task: "PATCH /products/{id}/availability como MESERO → 403 en test_product_availability_toggle.py"
Task: "GET /products/{id} incluye variants sin receta en test_product_detail_variants.py"

# Frontend de User Story 1, en paralelo:
Task: "Agregar CASHIER al NavItem 'Carta del menú' en navigation.config.ts"
Task: "Agregar CASHIER al roleGuard de 'products' + nueva ruta 'products/:id/detalle' en routes.ts"
```

---

## Implementation Strategy

### MVP First (User Story 1 solamente)

1. Completar Phase 1: Setup
2. Completar Phase 2: Foundational (crítico — bloquea todo lo demás)
3. Completar Phase 3: User Story 1
4. **Detenerse y validar**: probar User Story 1 de forma independiente (quickstart.md, Historia 1)
5. Entregar/demostrar si está listo — ya resuelve "el cajero no depende del administrador para marcar un producto agotado", aunque todavía sin efecto sobre pedidos

### Incremental Delivery

1. Setup + Foundational → fundamento listo
2. + User Story 1 → probar independientemente → MVP
3. + User Story 2 → probar independientemente → ahora el "Agotado" realmente bloquea pedidos (valor de negocio completo)
4. + User Story 3 → probar independientemente → garantías de seguridad/consistencia reforzadas
5. Cada historia agrega valor sin romper la anterior

---

## Notes

- `[P]` = archivo distinto, sin dependencias pendientes dentro de la misma fase
- La etiqueta `[Story]` mapea cada tarea a su historia de usuario para trazabilidad (Constitución, Principio XII)
- Verificar que los tests fallan antes de implementar
- Antes de tocar código: crear la rama (T001/T002, Principio XIV); los commits solo se hacen cuando el usuario lo pide explícitamente, en unidades pequeñas y lógicas (Principio XV) — esta lista de tareas no asume ningún commit automático
- El cambio de comportamiento de US2 (dejar de ocultar productos agotados en el menú) ya está registrado como decisión de negocio en `specs/000-reconocimiento/registro-de-anomalias.md` (A-104) — no requiere ninguna tarea adicional de registro, solo implementarlo como está documentado
