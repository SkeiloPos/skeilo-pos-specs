# Implementation Plan: Rediseño del listado de la Carta del menú

**Branch**: `feat/152-menu-list-redesign` | **Date**: 2026-11-05 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/152-rediseno-listado-carta-menu/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Rediseñar el listado del módulo "Carta del menú" (`pos-heladeria`, `ProductsPageComponent`)
replicando la disposición visual del archivo de referencia
`design/SkeiloPOS App - Carta del menu offline.html`: tarjetas en móvil/tablet
(< 1024px) y tabla en escritorio (≥ 1024px), ambas mostrando imagen (o marcador "Sin
imagen"), nombre, categoría, precio resumido y estado activo/disponible. Se añade un
filtro por categoría (server-side, combinable con los filtros existentes) y un precio
resumido por producto ("$X" si tiene una sola variante con precio, "Desde $X" si tiene
varias, "Sin precio" si ninguna variante tiene precio configurado). El endpoint
`GET /products` (`pos-backend`) se amplía con `category_id` como filtro y con el precio
resumido en la respuesta, y se recorta de `ProductListResponse` cualquier campo que
ninguna de las dos vistas (tarjeta/tabla) despliega, conforme a FR-008.

## Technical Context

**Language/Version**: Python 3.12 (FastAPI) en `pos-backend`; TypeScript 5 / Angular 21
(standalone components, signals) en `pos-heladeria`.

**Primary Dependencies**: FastAPI + SQLAlchemy 2.x + `fastapi-pagination` (`Page[...]`,
`paginate`) en backend; Angular standalone components + Tailwind CSS v4 en frontend
(mismo patrón de `ProductsPageComponent` y de `app-mi-icon` ya usado en el módulo).

**Storage**: PostgreSQL 16, schema-per-tenant (`tenant.products`, `tenant.product_variants`,
`tenant.categories`). No se crean tablas nuevas; no hay migración de esquema (no se agrega
columna persistida — el precio resumido se calcula en consulta, ver research.md D2).

**Testing**: `pytest` (characterization tests + tests nuevos) en `pos-backend`
(`app/characterization_tests/`); `ng test` (Jasmine/Karma) en `pos-heladeria`.

**Target Platform**: Web responsive (navegador), consumido desde móvil, tablet y
escritorio dentro del dashboard administrativo del POS.

**Project Type**: Web application (backend API + frontend Angular), dos repositorios
independientes (`pos-backend`, `pos-heladeria`), según Alcance de la constitución.

**Performance Goals**: Sin regresión sobre el tiempo de respuesta actual de
`GET /products` paginado (tamaño de página ≤ 100); el cálculo del precio resumido debe
evitar N+1 por producto (una sola consulta adicional agregada, no una por fila — ver
research.md D2).

**Constraints**: El payload del listado no debe transportar campos no desplegados en
ninguna de las dos vistas (FR-008/SC-004). El diseño de tarjetas debe coincidir
visualmente con el archivo de referencia (FR-001/SC-005). La paginación y los filtros
existentes deben sobrevivir al cambio de tarjetas↔tabla por redimensionado (FR-009).

**Scale/Scope**: Un módulo existente (listado de productos), sin nuevas entidades de
datos; cambios acotados a: 1 endpoint existente (`GET /products`), 1 schema de respuesta,
1 componente de página Angular (+ sub-componentes de tarjeta/filtro si aplica).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principio I (nace de un spec)**: ✅ `specs/152-rediseno-listado-carta-menu/spec.md`
  existe, aprobado, con clarificaciones registradas (sesión 2026-11-05).
- **Principio II (comportamiento existente protegido)**: ✅ El cambio de comportamiento
  (nuevo campo de precio y filtro `category_id` en `GET /products`) fue confirmado con el
  usuario antes de continuar (ver sección Assumptions del spec); no hay otra regla de
  negocio existente que se altere — roles, permisos y acciones por producto se preservan
  (FR-011).
- **Principio III (characterization tests)**: ✅ No hay tests `"CONGELA comportamiento
  actual:"` sobre la forma exacta de `ProductListResponse`; los tests existentes que
  verifican el payload de `GET /products` (si los hay) se actualizan explícitamente en la
  Fase de implementación, citando esta spec.
- **Principio V (sin refactors oportunistas)**: ✅ El plan no toca `ProductDetailResponse`,
  el formulario de producto, ni el flujo de importación/exportación — solo el listado.
- **Principio VI (evolución incremental)**: ✅ Unidad única: listado de la Carta del menú
  (backend: 1 endpoint ampliado; frontend: 1 página rediseñada). No mezcla migración de
  datos (no la hay) con cambio de UI.
- **Principio VIII (evolución del modelo de datos)**: ✅ N/A — no hay cambio de esquema;
  el precio resumido se calcula en consulta (research.md D2), no se persiste.
- **Principio XIV/XV (ramas y commits)**: se crea la rama `feat/152-menu-list-redesign`
  antes de tocar código en cualquiera de los dos repositorios; los commits solo se hacen a
  pedido explícito del usuario, en inglés, sin marca de IA.

Sin violaciones que requieran justificación en Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/152-rediseno-listado-carta-menu/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   └── get-products.md
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
# pos-backend (API)
app/
├── api/v1/products/
│   ├── router.py          # GET /products: + query param category_id
│   ├── schemas.py         # ProductListResponse: + price_display/price_from, - campos no usados en el listado
│   └── service.py         # list_query: + filtro category_id, + cálculo de precio resumido
├── models/
│   └── product.py         # sin cambios de esquema
└── characterization_tests/
    └── test_product_list_pricing_and_category_filter.py  # nuevo

# pos-heladeria (frontend)
src/app/modules/products/
├── pages/
│   └── products-page.component.ts   # template: tarjetas (< lg) + tabla (≥ lg), filtro de categoría
├── components/
│   └── product-list-card.component.ts   # nuevo: tarjeta de producto (reutilizada en móvil/tablet)
├── services/
│   └── product.service.ts           # loadProducts: + categoryId; interfaz Product: + price_display/price_from
└── interfaces/
    └── product.interface.ts         # + campos de precio resumido
```

**Structure Decision**: Web application de dos repositorios ya existente (Opción 2 del
template, adaptada a los nombres reales `pos-backend`/`pos-heladeria`). No se crea
ningún proyecto ni directorio nuevo de alto nivel — el feature vive dentro del módulo
`products` ya existente en ambos repos.

## Complexity Tracking

> No aplica — el Constitution Check no registró violaciones.
