# Implementation Plan: Adiciones configuradas a nivel de producto y vendibles como línea independiente

**Branch**: `129-adiciones-nivel-producto` | **Date**: 2026-10-19 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/129-adiciones-nivel-producto/spec.md`

## Summary

Una adición (topping) deja de configurarse por variante dentro de un grupo de opciones y se
convierte en un producto normal del catálogo marcado con un indicador (`is_topping`); su
disponibilidad para otro producto se declara una sola vez, a nivel de producto, en una tabla
puente nueva (`product_toppings`) que aplica automáticamente a todas las variantes. Como es un
producto, puede venderse como línea independiente del pedido manual sin ningún cambio de esquema
(reutiliza `product_variant_id` en `cart_items`/`order_items`, igual que cualquier producto). Para
seguir ofreciéndola **adjunta** a otra línea (ej. "+ Gomitas" en un Granizado) se agregan dos
tablas espejo nuevas (`cart_item_toppings`/`order_item_toppings`), paralelas a
`cart_item_options`/`order_item_options` pero referenciando la variante de la adición en vez de
una `Option`. Los grupos de opciones existentes (`OptionGroup`/`Option`) no se tocan a nivel de
esquema ni de asociación a variante — siguen funcionando exactamente igual, tanto para sabores
(uso que continúa) como para cualquier adición ya configurada con el mecanismo anterior, que el
negocio migrará manualmente según su propio ritmo (ver Assumptions de spec.md). El menú QR gana
`Product.visible_en_qr` (mismo patrón que `Category.visible_en_qr`, spec 128), con un default
calculado (no de columna) que nace en `false` cuando `is_topping=true` y en `true` en caso
contrario; la respuesta de `GET /menu` gana, por producto, la lista de adiciones disponibles
(desde `product_toppings`) para alimentar el selector de personalización.

## Technical Context

**Language/Version**: Python 3.11 (FastAPI, pos-backend) · TypeScript / Angular (pos-heladeria)

**Primary Dependencies**: FastAPI, SQLAlchemy 2.x (ORM declarativo con `Mapped`), Alembic
(migraciones), Pydantic v2 (schemas) en `pos-backend`; Angular standalone components, Angular
Signals, `@tanstack/angular-query-experimental` en `pos-heladeria`. Ninguna dependencia nueva.

**Storage**: PostgreSQL 16, esquema por tenant (`tenant.*`). Tablas nuevas: `product_toppings`,
`cart_item_toppings`, `order_item_toppings`. Columna nueva: `products.is_topping`,
`products.visible_en_qr`.

**Testing**: `pos-backend`: `./env/bin/python -m unittest discover -s app/characterization_tests
-p 'test_*.py'` (ver [[how-to-run-sibling-repo-tests]]). `pos-heladeria`: `npx ng test --watch=false
--include='<archivo>.spec.ts'` por archivo tocado (nunca confiar en el delta de la suite
completa — ver la misma nota de memoria).

**Target Platform**: servicio web (API Linux + SPA Angular), mismo despliegue existente.

**Project Type**: web (backend `pos-backend` + frontend `pos-heladeria`, repos ya existentes).

**Performance Goals**: sin objetivo nuevo — mismo orden de magnitud que el resto del catálogo
(listados paginados, menú QR servido en dos–tres queries por carga, igual que hoy).

**Constraints**: Principio VII de la constitución (inmutabilidad de pedidos/ventas ya
confirmados) — ninguna migración reescribe `order_item_options`/`sale_items` existentes.
Principio VI (evolución incremental) — las cuatro historias de usuario del spec se implementan
como unidades verificables por separado (ver Project Structure / tasks.md).

**Scale/Scope**: cambio acotado a los módulos de catálogo (`products`, `catalog`, `menu`) y al
carrito/pedido (`cart`, `orders`) en `pos-backend`; a los módulos `products`, `tables` (panel de
pedido manual, menú QR del comensal) en `pos-heladeria`. No toca facturación, caja ni reportes.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Cumplimiento |
|---|---|
| I. Nace de un spec | ✅ `spec.md` aprobado, con decisión de modelado explícita y 3 clarificaciones registradas. |
| II. Comportamiento existente protegido | ✅ Los grupos de opciones para sabores no cambian (revertido FR-005 tras el hallazgo de `VariantOptionGroup` durante este plan — ver research.md D1). Las adiciones ya configuradas con el mecanismo anterior siguen funcionando sin migración forzada (spec.md, Assumptions). |
| III. Characterization tests | ⚠️ A verificar en `/speckit-tasks`/implementación: ningún test `"CONGELA comportamiento actual:"` sobre `option_groups`/`variant_option_groups`/menú debe tocarse, salvo el que verifique explícitamente el nuevo filtro `visible_en_qr` por producto (mismo patrón que el que ya existe para categoría, spec 128). |
| IV. Nuevo comportamiento vía spec | ✅ Toda regla nueva (FR-001 a FR-018) está en spec.md. |
| V. Sin refactors oportunistas | ✅ No se toca `OptionGroup`/`Option`/`VariantOptionGroup` más que para dejarlos documentalmente "reservados a sabores"; ninguna limpieza no solicitada. |
| VI. Evolución incremental | ✅ US1 (asociación producto→adición) y US4 (visibilidad QR por producto) son independientes entre sí y de US2 (línea suelta, que no requiere esquema nuevo); US3 (selector en QR) depende de US1. `/speckit-tasks` debe mantener esa separación en fases propias. |
| VII. Compatibilidad histórica | ✅ `order_item_options`/`sale_items` no se migran ni se reescriben; las tablas nuevas son aditivas. |
| VIII. Evolución del modelo de datos | ✅ Ver data-model.md: columnas/tablas nuevas, defaults, compatibilidad y estrategia de rollback (DROP de tablas/columnas aditivas, sin pérdida de datos históricos). |
| IX. Dependencias nuevas | ✅ N/A — ninguna dependencia nueva. |

**Resultado**: PASA. Sin violaciones que requieran `Complexity Tracking`.

## Project Structure

### Documentation (this feature)

```text
specs/129-adiciones-nivel-producto/
├── plan.md              # Este archivo
├── research.md          # Fase 0
├── data-model.md         # Fase 1
├── quickstart.md         # Fase 1
├── contracts/            # Fase 1
│   ├── products-api.md
│   ├── menu-api.md
│   └── manual-order-api.md
└── tasks.md              # Fase 2 (/speckit-tasks, no este comando)
```

### Source Code (repository root)

```text
../pos-backend/app/
├── models/
│   ├── product.py                 # + is_topping, visible_en_qr
│   ├── product_topping.py         # NUEVO: tabla puente product_toppings
│   ├── cart_item.py                # + CartItemTopping (nueva clase, misma archivo)
│   └── order_item.py               # + OrderItemTopping (nueva clase, mismo archivo)
├── api/v1/
│   ├── products/
│   │   ├── schemas.py              # + is_topping, visible_en_qr, topping_ids en Create/Update/Response
│   │   ├── service.py              # validar auto-asociación (FR-016), default visible_en_qr
│   │   └── router.py               # sin endpoints nuevos; mismos verbos, payload ampliado
│   ├── menu/
│   │   ├── router.py                # filtro visible_en_qr por producto; adiciones disponibles por producto
│   │   └── schemas.py               # MenuProductResponse.toppings: list[MenuToppingResponse]
│   └── cart|orders (servicios existentes)
│       └── service.py               # agregar/quitar una adición adjunta a una línea (US3); línea
│                                      # suelta de adición NO necesita cambios (ya es un producto más)
├── catalog_engine/
│   └── (sin cambios de firma; se invoca load_recipe/plan_line_consumption también para la
│      variante de la adición adjunta, con la cantidad elegida, reusando lo ya existente)
└── alembic/versions/
    └── <nueva revisión>: products.is_topping/visible_en_qr, product_toppings,
        cart_item_toppings, order_item_toppings

../pos-heladeria/src/app/modules/
├── products/
│   ├── pages/product-form.component.ts   # checkbox "Es una adición"; selector "Adiciones
│   │                                       # disponibles" (multi-select de productos is_topping=true);
│   │                                       # toggle "Visible en menú QR"
│   └── interfaces/product.interface.ts    # + isTopping, visibleEnQr, toppingIds
├── tables/
│   ├── pages/manual-order-page.component.ts     # ninguna lógica nueva: la búsqueda de catálogo ya
│   │                                              # lista cualquier producto activo, incluida una adición
│   ├── components/pos-order-panel.component.ts  # selector de "Adiciones disponibles" al agregar/editar
│   │                                              # una línea (análogo al de grupos de opciones existente)
│   └── pages/public-menu.component.ts            # mismo selector, lado comensal (US3)
└── categories/... (sin cambios; ya tiene su propio patrón visible_en_qr, spec 128, que este
    feature replica a nivel de producto sin modificarlo)
```

**Structure Decision**: cambio dentro de los dos repos y módulos ya existentes
(`products`/`menu`/`tables` en ambos repos); no se crea ningún módulo ni proyecto nuevo. Las
tablas nuevas son aditivas y viven junto a sus pares existentes (`cart_item.py`, `order_item.py`)
en vez de en un archivo separado, siguiendo la convención ya usada por `CartItemOption`/
`OrderItemOption` en el mismo módulo que `CartItem`/`OrderItem`.

## Complexity Tracking

*Sin violaciones — tabla omitida.*
