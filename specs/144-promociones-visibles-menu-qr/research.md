# Research: Visibilidad de promociones en el menú QR

No quedó ninguna "NEEDS CLARIFICATION" en el Technical Context del plan — el spec ya resolvió
las ambigüedades funcionales en su sesión de clarificación, y el patrón técnico a seguir ya
existe en el código para `Categoria`/`Producto`. Este documento consolida las decisiones de
*cómo* implementar, no *qué* implementar (eso ya lo fija `spec.md`).

## 1. Dónde y cómo agregar el campo de visibilidad en QR a `Promotion`

- **Decision**: agregar `visible_en_qr: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default="true")` en `app/models/promotion.py`, en la clase `Promotion` (tabla `tenant.promotions`), siguiendo exactamente el patrón de `app/models/product.py:92-99` y `app/models/category.py:24`.
- **Rationale**: es el mismo patrón ya validado dos veces en producción (specs 128 y 129); reutilizarlo minimiza riesgo y mantiene consistencia de modelo de datos entre `Producto`, `Categoria` y `Promoción`.
- **Alternatives considered**: columna nullable sin default (rechazada: rompería FR-002, que exige visible por defecto al crear); campo a nivel de `PromotionRule` en vez de `Promotion` (rechazada explícitamente en el spec — Assumptions — porque todas las reglas de una promoción comparten vigencia y estado).

## 2. Migración

- **Decision**: nueva revisión Alembic `144_promotions_visible_en_qr`, usando el decorador `@for_each_tenant_schema` y el guard `_has_table` ya usados en `cfa621f5b865_128_categories_visible_en_qr.py` y `43e57b9da5d9_129_adiciones_nivel_producto.py`: `ADD COLUMN visible_en_qr BOOLEAN NOT NULL DEFAULT true` por cada schema de tenant, con `downgrade` que la elimina.
- **Rationale**: todas las tablas de negocio viven en schemas por-tenant; una migración "plana" sobre `public` no alcanzaría los datos reales. Este es el único mecanismo de migración por-tenant que el proyecto usa.
- **Alternatives considered**: ninguna — es el único patrón de migración por-tenant existente en el repo.

## 3. Cómo evaluar "al menos un producto/variante alcanzable por QR" para una promoción

- **Decision**: para cada `Promotion`, recorrer `rules → PromotionVariant.product_variant_id → ProductVariant → Product → Category` y considerar la promoción "alcanzable por QR" si existe al menos una fila donde `ProductVariant.active`, `Product.active`, `Product.visible_en_qr`, `Category.active` y `Category.visible_en_qr` son todos verdaderos — la misma conjunción que ya aplica `_build_menu` (`app/api/v1/menu/router.py`) para decidir qué productos entrega el menú QR firmado. Implementarlo como una función nueva en `app/api/v1/promotions/service.py` (junto a `active_variant_set_rules`), reutilizando el patrón de join ya usado en `_guard_variant_overlap`/`_guard_product_overlap` (líneas 618, 674) para resolver productos a partir de reglas.
- **Rationale**: evaluar "alcanzable" a nivel de promoción completa (no por regla) es exactamente lo que pide FR-004 y la clarificación de la sesión 2026-10-29. Reutilizar la misma conjunción de banderas que ya usa el menú evita que ambos lugares del código diverjan sobre qué significa "visible en QR" para un producto.
- **Alternatives considered**: evaluar alcanzabilidad por regla individual y filtrar reglas del detalle público (rechazada explícitamente por la clarificación del spec — se muestra la promoción completa o no se muestra).

## 4. Dónde filtrar la pestaña/listado de promociones del menú QR

- **Decision**: modificar `_build_menu_promotions(db, now, tenant)` en `app/api/v1/menu/router.py` para que, antes de construir cada `MenuPromotionAnnouncement`, descarte las promociones con `visible_en_qr=False` o sin ningún producto alcanzable (según el punto 3). El resultado (lista vacía o no) ya es consumido por `menu_by_signed_qr()` bajo la clave `"promotions"` del response. En frontend, `public-menu.component.ts` debe pasar de mostrar el botón "Promociones" sin condición (líneas 311-323, comentario explícito de la spec 081 que esta feature reemplaza) a condicionarlo a `promotions.length > 0` (el mismo arreglo que ya llega en `ResolvedMenu.promotions`).
- **Rationale**: `_build_menu_promotions` es el único productor de la lista de promociones que el menú QR firmado consume; filtrarlo ahí cubre FR-003, FR-004, FR-005 y FR-006 con un solo cambio de backend. La llamada sin filtrar en `public_menu()` (catálogo no firmado, staff) se deja intacta — no debe aplicarse ningún filtro de visibilidad ahí, igual que ya ocurre hoy con `only_visible_en_qr` para productos/categorías (FR-007).
- **Alternatives considered**: agregar un flag `only_visible_en_qr` a `_build_menu_promotions` como existe en `_build_menu` para productos/categorías (considerada equivalente y aceptable; se prefiere filtrar siempre dentro de la función porque, a diferencia de `_build_menu`, `_build_menu_promotions` solo tiene un llamador — `menu_by_signed_qr` — por lo que el flag no aportaría flexibilidad real; documentarlo aquí para que la fase de tasks pueda optar por el flag si prefiere máxima simetría con el patrón de productos).

## 5. Dónde excluir el descuento de promociones ocultas en pedidos enviados por QR (FR-008)

- **Decision**: el seam común a `cart/service.py` (`serialize_cart`, `submit_cart`) y `orders/checkout.py` (`auto_discount`, `refresh_order_item_discounts`) es `service.active_variant_set_rules()` / `promotions.evaluate_variant_sets()`. Threadear un parámetro (p. ej. `channel: str | None` o `exclude_hidden_in_qr: bool`) hacia `active_variant_set_rules()` para que, cuando el origen sea QR (carrito de comensal, o `CustomerOrder.channel == 'QR_MENU'`), excluya las reglas de promociones con `visible_en_qr=False`.
- **Rationale**: es el único punto donde ambos flujos (preview de carrito y cálculo definitivo al cobrar) convergen; modificarlo ahí garantiza que el carrito y el pedido final sean consistentes entre sí sin duplicar lógica. El canal `POS` (pedidos manuales) nunca pasa por el carrito de comensal y, cuando pase por `checkout.py`, no debe excluir nada — por eso el parámetro debe ser explícito y no un default global.
- **Alternatives considered**: filtrar en `_cart_promo_lines`/`promo_lines_for` antes de llamar al motor (rechazada: duplicaría la condición de "oculta en QR" en dos sitios en vez de uno; el motor ya es el punto único de verdad para qué reglas aplican).

## 6. Permisos sobre el nuevo control de visibilidad

- **Decision**: no se crea un endpoint nuevo — se extiende el `PromotionUpdate` (schema) existente con `visible_en_qr: bool | None = None`, consumido por el mismo `PATCH /promotions/{id}` ya protegido por `Depends(require_tenant_admin)` y `Depends(require_module_access("promociones"))` a nivel de router. Se agrega `visible_en_qr` al payload de `record_audit(...)` ya presente en ese endpoint.
- **Rationale**: es exactamente el mecanismo que pide FR-009/FR-010 (control disponible sin importar el estado de la promoción, restringido a quien ya administra promociones) sin introducir una ruta ni una dependencia de permisos nueva.
- **Alternatives considered**: endpoint dedicado `PATCH /promotions/{id}/visibility` (rechazado: innecesario, ya existe un PATCH de escalares genérico; añadiría una ruta más a mantener sin beneficio funcional).

## 7. Frontend: dónde añadir el control

- **Decision**: añadir `visible_en_qr` a `PromotionScalars`/`Promotion`/`PromotionUpdatePayload` en `promotion.interface.ts`; añadir un método `toggleVisibleQr(id, current)` en `promotion.service.ts` que haga `PATCH` con `{ visible_en_qr: !current }` e invalide la query de promociones (mismo patrón que `category.service.ts:198-210`); añadir el switch correspondiente en `promotions-page.component.ts`, visible sin importar el estado de la promoción (FR-010 / acceptance scenario 3 de US2).
- **Rationale**: replica al pixel el patrón ya usado para `Categoria`, minimizando el riesgo de introducir un comportamiento de UI inconsistente con el resto del sistema.
- **Alternatives considered**: ninguna — es la única convención de toggle de visibilidad QR que existe en el frontend.
