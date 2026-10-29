---

description: "Task list template for feature implementation"
---

# Tasks: Visibilidad de promociones en el menú QR

**Input**: Design documents from `/specs/144-promociones-visibles-menu-qr/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/promotions-api.md, quickstart.md (todos presentes)

**Repos**: `../pos-backend/` (FastAPI) y `../pos-heladeria/` (Angular), hermanos de este repo de specs.

**Tests**: Principio X del plan deja pendiente, para esta fase, tests de característica para FR-001..FR-010; se incluyen como tareas explícitas (characterization tests backend, specs de componente en frontend) además de la validación manual de `quickstart.md`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Puede ejecutarse en paralelo (archivo distinto, sin dependencia de una tarea sin terminar)
- **[Story]**: US1 / US2 / US3, según spec.md

---

## Phase 1: Foundational (Blocking Prerequisites)

**Purpose**: la columna `visible_en_qr` debe existir en `tenant.promotions` antes de que cualquier historia pueda leerla o escribirla.

**⚠️ CRITICAL**: ninguna historia de usuario puede empezar hasta cerrar esta fase.

- [X] T001 Agregar columna `visible_en_qr: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default="true")` a la clase `Promotion` en `../pos-backend/app/models/promotion.py` (clase `Promotion`, tras `closed_by_refactor_at`, línea ~80), siguiendo el patrón exacto de `app/models/product.py:92-99` / `app/models/category.py:24`.
- [X] T002 Crear migración Alembic `144_promotions_visible_en_qr` en `../pos-backend/alembic/versions/`: copiar la estructura de `cfa621f5b865_128_categories_visible_en_qr.py` (decorador `@for_each_tenant_schema`, guard `_has_table`), con `upgrade()` → `ADD COLUMN visible_en_qr BOOLEAN NOT NULL DEFAULT true` sobre `promotions` por cada schema de tenant, y `downgrade()` → `drop_column("promotions", "visible_en_qr", schema=schema)`. Fijar `down_revision` a la revisión `head` actual del repo.

**Checkpoint**: la columna existe y toda promoción (nueva o existente) tiene `visible_en_qr = true` por defecto — las historias de usuario pueden empezar.

---

## Phase 2: User Story 1 - La pestaña de promociones se oculta cuando no hay nada que anunciar (Priority: P1) 🎯 MVP

**Goal**: el menú QR firmado solo muestra la pestaña/sección "Promociones" cuando existe, en ese instante, al menos una promoción vigente + visible en QR + con algún producto/variante alcanzable por QR (FR-004, FR-005, FR-006).

**Independent Test**: pausar/dejar vencer todas las promociones del tenant, recargar el menú QR y confirmar `promotions: []` y pestaña ausente; activar una vigente y alcanzable y confirmar que reaparece.

- [X] T003 [P] [US1] Agregar una función de alcanzabilidad (p. ej. `_reachable_by_qr(db: Session, promo: Promotion) -> bool`) en `../pos-backend/app/api/v1/promotions/service.py`, junto a `active_variant_set_rules` (línea ~177): verdadera si existe al menos una fila `Promotion.rules → PromotionVariant.product_variant_id → ProductVariant(active=true) → Product(active=true, visible_en_qr=true) → Category(active=true, visible_en_qr=true)` para la promoción completa (no por regla — clarificación de la sesión 2026-10-29). Reutilizar el patrón de joins de `_guard_variant_overlap`/`_guard_product_overlap` (líneas 618, 674).
- [X] T004 [US1] Modificar `_build_menu_promotions(db, now, tenant)` en `../pos-backend/app/api/v1/menu/router.py` (líneas 298-349) para descartar, antes de construir cada `MenuPromotionAnnouncement`, toda `Promotion` con `visible_en_qr=False` o sin `_reachable_by_qr(db, promo)` (T003) — de forma que el resultado sea `[]` cuando ninguna promoción cumple vigencia + visible + alcanzable (FR-003, FR-004, FR-005, FR-006). No tocar `_build_menu` ni `public_menu_promotions`/`public_menu` (FR-007: el catálogo sin firmar de staff no filtra). Depende de T001-T003.
- [X] T005 [P] [US1] En `../pos-heladeria/src/app/modules/tables/pages/public-menu.component.ts`, condicionar el botón "Promociones" (líneas ~310-323) a `promotionAnnouncements().length > 0`, retirando el comentario de la spec 081 ("siempre visible, incluso sin promociones vigentes"). Revisar el flujo de `ngOnInit`/`categories.set(...)` (líneas ~1136-1150) y `activeCategory`/`emptyCatalogMessage` para que, si la pestaña queda oculta mientras estaba seleccionada (p. ej. tras un refresco que vacía `promotionAnnouncements`), la vista caiga a la primera categoría en vez de quedar en un estado sin pestaña resaltada.
- [X] T006 [US1] Actualizar/agregar casos en `../pos-heladeria/src/app/modules/tables/pages/public-menu.component.spec.ts`: el botón "Promociones" no debe existir en el DOM cuando `promotions` resuelve vacío, y debe existir cuando trae al menos un anuncio (mismo estilo que el test FR-008 existente, línea ~729, que verifica el mensaje vacío invocando `selectCategory()` directamente). Depende de T005.
- [X] T007 [US1] Agregar un test backend (en `../pos-backend/app/characterization_tests/test_menu_router.py` o un módulo nuevo si el alcance no encaja) que, vía `menu_by_signed_qr`/`_build_menu_promotions`, verifique: (a) `promotions == []` cuando ninguna promoción está vigente; (b) `promotions == []` cuando la única promoción vigente tiene todos sus productos ocultos en QR (edge case de spec.md); (c) `promotions` no vacío cuando hay al menos una promoción vigente, visible y alcanzable. Si existe algún characterization test con prefijo `"CONGELA comportamiento actual:"` que asuma la pestaña siempre visible, actualizarlo citando esta spec (Principio III). Depende de T004.

**Checkpoint**: US1 es funcional y comprobable de forma independiente (incluso con `visible_en_qr` siempre `true`, el filtro de vigencia + alcanzabilidad ya oculta la pestaña sin promociones elegibles).

---

## Phase 3: User Story 2 - El administrador decide si una promoción se ofrece por QR (Priority: P1)

**Goal**: un control por promoción (`visible_en_qr`), editable sin importar su estado, que la excluye del menú QR sin afectar su disponibilidad en pedidos manuales (caja/mesa).

**Independent Test**: marcar una promoción activa y vigente como "No mostrar en menú QR", recargar el menú QR y confirmar que desaparece (y que la pestaña desaparece si era la única); confirmar que "Nuevo pedido" manual sigue ofreciéndola igual.

- [X] T008 [P] [US2] Agregar `visible_en_qr: bool | None = None` a `PromotionUpdate` en `../pos-backend/app/api/v1/promotions/schemas.py` (clase en líneas 168-191).
- [X] T009 [US2] Agregar `visible_en_qr: bool` a `PromotionResponse` en `../pos-backend/app/api/v1/promotions/schemas.py` (clase desde línea 242) y poblarlo en `serialize_promotion()` en `../pos-backend/app/api/v1/promotions/service.py` (líneas 1047-1072): agregar `"visible_en_qr": promo.visible_en_qr` al dict devuelto. Esto cubre tanto `PATCH /promotions/{id}` como `GET /promotions` (mismo serializador, FR-010).
- [X] T010 [US2] En `update()` (`../pos-backend/app/api/v1/promotions/service.py`, líneas 855-895): el guard actual `if promo.status == "active": raise 409` bloquea *cualquier* campo mientras la promoción está activa — pero FR-001/FR-010 exigen que `visible_en_qr` siga editable en cualquier estado, incluido `active` (US2, acceptance scenario 1: "una promoción está activa y vigente... el administrador la marca como No mostrar en menú QR"). Cambiar el guard para que solo dispare si `data.model_fields_set - {"visible_en_qr"}` no está vacío (es decir, si se está tocando algún otro campo escalar además de/en vez de `visible_en_qr`), y agregar `visible_en_qr` al bucle de asignación de campos (líneas 881-887) sin pasar por esa restricción de estado.
- [X] T011 [US2] Test backend: con una promoción vigente, visible y alcanzable (setup de T007), marcarla `visible_en_qr=false` vía `service.update`/`PATCH` y verificar que `_build_menu_promotions` deja de incluirla (y que vuelve a aparecer al poner `visible_en_qr=true`), aislando este caso del de vigencia/alcanzabilidad de T007 — en `../pos-backend/app/characterization_tests/test_promotions_service.py` o el módulo de T007.
- [X] T012 [P] [US2] Test backend de permisos: `PATCH /promotions/{id}` con `{"visible_en_qr": false}` desde un rol sin acceso al módulo `promociones` devuelve `403` — en `../pos-backend/app/characterization_tests/test_promotions_router.py`, reutilizando el patrón de test de permiso ya existente en ese archivo para otros campos de `PromotionUpdate`.
- [X] T013 [P] [US2] Agregar `visible_en_qr: boolean` a la interfaz `Promotion` (líneas 59-73) en `../pos-heladeria/src/app/modules/promotions/interfaces/promotion.interface.ts`, y un tipo de payload de toggle (p. ej. `PromotionVisibilityPayload = { visible_en_qr: boolean }`, separado de `PromotionScalars`/`PromotionUpdatePayload` porque `visible_en_qr` no se edita desde el formulario de escalares).
- [X] T014 [US2] Agregar `toggleVisibleQr(id: string, current: boolean): Promise<void>` a `../pos-heladeria/src/app/modules/promotions/services/promotion.service.ts`: `PATCH ${baseUrl}/${id}` con `{ visible_en_qr: !current }`, invalidando la query `['promotions']` tras éxito — mismo patrón que `category.service.ts` `toggleVisibleQr` (líneas ~195-210). Depende de T013.
- [X] T015 [US2] En `../pos-heladeria/src/app/modules/promotions/pages/promotions-page.component.ts`, agregar una columna "Visible en QR": nuevo `<th>` tras la columna "Estado" (línea ~292) y un `<td>` con switch accesible (`role="switch"`, mismo estilo que `categories-page.component.ts` líneas 126-152) tras el `<td>` de estado (línea ~310), que llama `svc.toggleVisibleQr(p.id, p.visible_en_qr)` — habilitado sin importar `p.status` (FR-010, acceptance scenario 3 de US2). Depende de T014.
- [X] T016 [US2] Actualizar/agregar casos en `../pos-heladeria/src/app/modules/promotions/pages/promotions-page.component.spec.ts`: accionar el switch llama a `toggleVisibleQr`; el indicador refleja `p.visible_en_qr`; el control permanece visible y habilitado para promociones `draft`/`paused`/`finished` (no solo `active`). Depende de T015.

**Checkpoint**: el administrador puede ocultar/mostrar cualquier promoción en QR sin tocar su estado; el menú QR y el listado admin lo reflejan; "Nuevo pedido" manual (`GET /menu` sin firmar) sigue sin filtrar — no se tocó `_build_menu`/`public_menu` (FR-007).

---

## Phase 4: User Story 3 - Una promoción oculta en QR no se cuenta como descuento ofrecido al comensal (Priority: P2)

**Goal**: ningún pedido enviado por su cuenta por un comensal desde el menú QR (canal `QR_MENU`) aplica el descuento de una promoción oculta en QR, aunque el producto ya estuviera en el carrito antes de ocultarla; los pedidos manuales (canal `POS`) no se ven afectados.

**Independent Test**: agregar al carrito un producto con promoción visible y vigente, ocultar esa promoción, enviar el pedido del comensal y confirmar que se cobra sin el descuento; confirmar en paralelo que un pedido manual con el mismo producto sigue aplicando el descuento.

- [X] T017 [P] [US3] Agregar el parámetro `exclude_hidden_in_qr: bool = False` a `active_variant_set_rules()` en `../pos-backend/app/api/v1/promotions/service.py` (líneas 147-176): cuando sea `True`, además del filtro de vigencia ya existente, descartar toda `PromotionRule` cuya `r.promotion.visible_en_qr` sea `False`.
- [X] T018 [US3] Threadear el mismo parámetro `exclude_hidden_in_qr: bool = False` a través de `evaluate_variant_sets()` (líneas 235-258 en adelante) hasta su llamada interna a `active_variant_set_rules()`. Depende de T017.
- [X] T019 [US3] En `../pos-backend/app/api/v1/cart/service.py`, pasar `exclude_hidden_in_qr=True` en las dos llamadas a `promotions.evaluate_variant_sets()` (`serialize_cart`, línea ~363; creación de pedido dentro de `submit_cart`, línea ~1048) — el carrito del comensal es siempre canal `QR_MENU`. Depende de T018.
- [X] T020 [US3] En `../pos-backend/app/api/v1/orders/checkout.py`:
  - (a) Hacer que `refresh_order_item_discounts(db, order, tenant)` (líneas 412-440) derive internamente `exclude_hidden_in_qr=(order.channel == "QR_MENU")` a partir de su propio argumento `order` antes de llamar a `evaluate_variant_sets` — sin tocar ningún llamador externo (`kitchen.py`, `additions.py`, `toppings.py`, `consolidation.py`, `orders/service.py` siguen llamando `refresh_order_item_discounts(db, order)` sin cambios).
  - (b) En cada llamada a `auto_discount()` dentro de este mismo archivo que ya tenga un objeto `order` en alcance (`compute_checkout_preview` ~línea 466, `pay_order` ~línea 562, `checkout_and_send` ~línea 784, las confirmaciones de intento de pago ~líneas 1307/1657/1810), pasar `exclude_hidden_in_qr=(order.channel == "QR_MENU")` a través de `auto_discount()` (líneas 342-353) hacia `evaluate_variant_sets()`.
  - Dejar `compute_draft_preview` (~línea 527, sin `order` — borrador manual, "nunca canal QR" según su propio comentario) y cualquier llamador fuera de este archivo (`orders/tables_advanced.py`, `orders/service.py`) con el valor por defecto `False` — son flujos exclusivamente `POS`.
  - Depende de T018.
- [X] T021 [US3] Agregar un test backend que someta un carrito `QR_MENU` con un producto que califica para una promoción visible y vigente, oculte esa promoción (`visible_en_qr=false`) sin tocar el carrito, envíe el pedido y confirme que el total no incluye el descuento; y que un pedido `POS` equivalente, creado en el mismo instante, sí lo sigue aplicando — en `../pos-backend/app/characterization_tests/test_cart_service.py` y/o `test_orders_checkout.py`. Depende de T019, T020.

**Checkpoint**: las tres historias de usuario entregan valor comprobable por separado; FR-001 a FR-010 quedan cubiertos.

---

## Phase 5: Polish & Cross-Cutting Concerns

- [X] T022 [P] Ejecutar `quickstart.md` completo (Escenarios A, B, C y los edge cases listados) contra un tenant real con backend+frontend corriendo, incluida la migración `144_promotions_visible_en_qr` aplicada (`alembic upgrade head`).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Foundational (Phase 1)**: sin dependencias — bloquea a US1, US2 y US3.
- **US1 (Phase 2)**: depende de Phase 1. No depende de US2 ni US3.
- **US2 (Phase 3)**: depende de Phase 1. Reutiliza el filtro de `_build_menu_promotions` que T004 (US1) ya deja filtrando por `visible_en_qr` — en la práctica, T009/T010 (US2) son más fáciles de verificar end-to-end si T004 ya corrió, pero el contrato de T004 ("si `visible_en_qr=False`, se excluye") ya está completo desde US1 y no requiere cambios nuevos en Phase 2 para que US2 funcione.
- **US3 (Phase 4)**: depende de Phase 1 (columna) y, para su test de aceptación completo (T021), de que US2 (T008/T010) permita marcar `visible_en_qr=false` desde algún lado — en la práctica alcanza con escribir la columna directo en la prueba si US2 no ha corrido aún.
- **Polish (Phase 5)**: depende de que al menos US1+US2 (el alcance mínimo pedido) estén completas; idealmente también US3.

### Dentro de cada historia

- US1: T003 → T004 → T007; T005 → T006 (frontend, en paralelo con el backend T003/T004).
- US2: T008 → T009 → T010 → T011; T012 en paralelo a T011; T013 → T014 → T015 → T016.
- US3: T017 → T018 → T019 y T018 → T020 (T019/T020 pueden ir en paralelo entre sí una vez T018 cierra) → T021.

### Parallel Opportunities

- T003 (backend) y T005 (frontend) de US1 — archivos distintos, sin dependencia mutua.
- T008 y T012 de US2 — archivos distintos.
- T013 de US2 — interfaz frontend, en paralelo con cualquier tarea backend de US2.
- T017 de US3 puede empezar en paralelo con el cierre de US2, ya que solo depende de Phase 1.
- T022 (quickstart) es la única tarea de Polish y no compite con nada más.

---

## Parallel Example: User Story 1

```bash
# En paralelo:
Task: "T003 — _reachable_by_qr() en pos-backend/app/api/v1/promotions/service.py"
Task: "T005 — condicionar el botón Promociones en pos-heladeria public-menu.component.ts"
```

---

## Implementation Strategy

### MVP First (US1 + US2, ambas P1)

1. Completar Phase 1 (Foundational) — columna + migración.
2. Completar Phase 2 (US1) — pestaña se oculta sin promociones ofrecibles.
3. Completar Phase 3 (US2) — control de administración por promoción.
4. **Validar** con Escenarios A y B de `quickstart.md`.
5. US1 + US2 ya satisfacen el pedido explícito del usuario (ver spec.md, Input).

### Incremental Delivery

1. Foundational → listo para construir.
2. US1 → demo: el menú QR deja de mostrar una pestaña vacía.
3. US2 → demo: toggle de administración, replica el patrón de `Categoria`/`Producto`.
4. US3 (P2) → cierra el borde de carrito-ya-armado-antes-de-ocultar, protegiendo a US2 de quedar rota por una ventana de tiempo.
5. Polish → validación manual completa con `quickstart.md`.

### Notas

- Ningún endpoint nuevo (contracts/promotions-api.md): todo el cambio de API vive en `PromotionUpdate`/`PromotionResponse` (PATCH/GET ya existentes) y en el *contenido* de `GET /menu/qr-token/{token}`.
- `GET /menu` (catálogo sin firmar, staff/"Nuevo pedido") y `compute_draft_preview` (borrador manual) permanecen sin tocar — ahí vive la garantía de FR-007.
- El bug de contorno más delicado es T010: sin ese cambio, ocultar una promoción `active` desde la administración devolvería 409 en vez de aplicar el cambio — rompería el acceptance scenario 1 de US2 (la primera forma que explícitamente pidió el usuario: "sin tener que pausarla ni desactivarla").
