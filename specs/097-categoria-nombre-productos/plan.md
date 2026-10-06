# Implementation Plan: Corrección — el nombre de categoría de un producto no depende de la paginación de `GET /categories`

**Branch**: `097-categoria-nombre-productos` | **Date**: 2026-10-06 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/097-categoria-nombre-productos/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

El backend debe resolver `category_name` dentro de la propia consulta de productos (un `JOIN`
contra `Category` en `ProductService.list_query`, más el mismo dato disponible en el detalle de un
producto) y exponerlo en `ProductResponse` junto a `category_id`; el frontend debe dejar de
resolver ese nombre contra una lista de categorías cargada aparte (`categoryMap`/`categoryName()`
en `products-page.component.ts`, alimentada por `CategoryService.allCategories()`, topada a 100
por `GET /categories?size=100`) y enlazar directamente `product.category_name`. `GET /categories`
y quienes lo consumen hoy (selector del formulario de producto, filtro de promociones, pantalla de
Categorías) no se tocan.

## Technical Context

**Language/Version**: Backend: Python 3.14 (FastAPI). Frontend: TypeScript ~5.9 (Angular 21)

**Primary Dependencies**: Backend: FastAPI, SQLAlchemy, Pydantic (sin dependencias nuevas —
`sqlalchemy.orm.joinedload` ya está disponible en el proyecto). Frontend: Angular, RxJS,
`@tanstack/angular-query-experimental` (sin dependencias nuevas)

**Storage**: PostgreSQL 16, schema-per-tenant. Sin cambios de esquema: no se agrega ninguna
columna ni migración — `category_name` es un dato derivado, resuelto en cada lectura a partir de
la relación `Product.category` ya existente (`app/models/product.py:22`)

**Testing**: Backend: `unittest` (`app/characterization_tests/`, convención del repo). Frontend:
Vitest (componentes/servicios) — ambos ya configurados

**Target Platform**: Backend: servidor Linux (API). Frontend: SPA de navegador, panel del tenant
(Administrador/Cajero) — el menú QR público no se toca, no consume `ProductResponse`

**Project Type**: Aplicación web (backend + frontend en dos repos separados: `pos-backend`,
`pos-heladeria`; este repo, `pos-specs`, solo contiene la documentación)

**Performance Goals**: Ninguno nuevo. El fix reemplaza cero consultas adicionales por cero: hoy el
nombre se resuelve en el cliente contra una lista ya cargada; con el fix se resuelve en el servidor
con un único `JOIN` adicional dentro de la misma consulta paginada de productos (sin N+1: ver
research.md D1)

**Constraints**: `GET /categories` (incluida su paginación con tope de 100, `size: int = Query(20,
ge=1, le=100)`, `app/api/v1/categories/router.py:53`) NO MUST cambiar (FR-005); no se modifica el
menú QR ni ningún endpoint fuera de `GET /products`/`GET /products/{id}`; no se introduce ninguna
columna nueva ni migración

**Scale/Scope**: Alcance mínimo: un campo de solo lectura nuevo en una respuesta ya existente,
resuelto con una relación ORM ya existente; en el frontend, eliminar un mapa derivado y su función
auxiliar, y una línea de binding en una plantilla — ningún módulo, tabla, endpoint ni pantalla
nueva

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Evaluación |
|---|---|
| I. Nace de un spec | ✅ `specs/097-categoria-nombre-productos/spec.md`, con 4 escenarios de aceptación y requisitos cerrados, sin `NEEDS CLARIFICATION` pendiente |
| II. Comportamiento existente protegido | ✅ El único comportamiento que cambia (cómo se resuelve el nombre de categoría) es el defecto mismo que esta spec corrige, documentado como tal en la "Autorización de negocio" del spec — no es una decisión de negocio nueva, así que no aplica entrada en `registro-de-anomalias.md`. `GET /categories` y todo lo que depende de él (selector de categoría, filtro de promociones, pantalla de Categorías) queda explícitamente sin tocar (FR-005) |
| III. Characterization tests protegen lo heredado | ✅ Ningún test `"CONGELA comportamiento actual:"` se toca; `research.md` D1 verifica que ningún test existente fija `list_query` a devolver exactamente las columnas de hoy sin `category_name` |
| IV. Los nuevos specs pueden introducir comportamiento nuevo | N/A — esta spec no introduce comportamiento de negocio nuevo, corrige uno existente para que cumpla lo que ya se pretendía (ver spec, "Naturaleza de esta spec") |
| V. Nueva funcionalidad antes que refactor oportunista | ✅ No se generaliza `paginate()` para soportar columnas extra en ningún otro endpoint paginado (research.md D1, alternativa rechazada); no se toca la vista de detalle de producto para agregarle la categoría que la spec 093 (FR-017) dejó de mostrar — es una omisión preexistente distinta, fuera de alcance de esta corrección (spec, FR-003) |
| VI. Evolución incremental | ✅ Una sola historia de usuario, independiente y acotada; no se mezcla con ninguna otra funcionalidad |
| VII. Compatibilidad con datos históricos | N/A — no se toca ninguna factura, venta ni pedido; `category_name` es un dato de catálogo derivado, sin relación con el histórico de ventas |
| VIII. Evolución del modelo de datos | N/A — sin cambios de esquema (ver Storage arriba); no aplica `data-model.md` de migración, solo de contrato de respuesta |
| IX. Dependencias nuevas | N/A — no se agrega ninguna dependencia de terceros |
| X. Verificación obligatoria | ✅ `quickstart.md` cubre los 4 escenarios de aceptación; `tasks.md` (siguiente comando) debe incluir un test de characterization backend que siembre >100 categorías y verifique `category_name` en la página final, más los tests de frontend que hoy cubren `categoryMap`/`categoryName()` |
| XI. Decisiones de negocio frente a decisiones técnicas | ✅ No hay decisión de negocio nueva que registrar; las decisiones de esta spec son todas técnicas (research.md D1-D5) |
| XII. Trazabilidad | ✅ research.md y los contratos referencian los FR/escenarios de spec.md por número |
| XIII. Español de Colombia | ✅ Todos los artefactos de esta funcionalidad están en español; el campo nuevo de la API usa inglés técnico (`category_name`) como ya hace el resto del catálogo de este backend (`category_id`, `available_changed_at`, etc.) |
| XIV. Convención de ramas Git | Pendiente al iniciar la implementación: crear `fix/097-product-category-name` (o equivalente) antes de tocar código en `pos-backend`/`pos-heladeria`, conforme a `<tipo>/<numero_spec>-<nombre_spec>` |
| XV. Política de commits | Pendiente al iniciar la implementación: commits solo bajo pedido explícito del usuario, atómicos, en inglés, sin marca de IA |

**Resultado**: sin violaciones. No se requiere la tabla de Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/097-categoria-nombre-productos/
├── plan.md                          # This file (/speckit-plan command output)
├── research.md                      # Phase 0 output (/speckit-plan command)
├── data-model.md                    # Phase 1 output (/speckit-plan command)
├── quickstart.md                    # Phase 1 output (/speckit-plan command)
├── contracts/
│   └── products-api.md              # Phase 1 output (/speckit-plan command)
├── checklists/
│   └── requirements.md
└── tasks.md                         # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

Este repo (`pos-specs`) solo contiene la documentación de la funcionalidad. El código vive en dos
repos hermanos, ya existentes — no se crea ninguna carpeta ni proyecto nuevo:

```text
../pos-backend/
├── app/models/
│   └── product.py                   # + propiedad `category_name` (lee `self.category.name`, D2)
├── app/api/v1/products/
│   ├── service.py                   # list_query(): + joinedload(Product.category) (JOIN, D1)
│   └── schemas.py                   # ProductResponse: + category_name: str | None (D3/D4)
└── app/characterization_tests/
    └── test_products_service.py     # (o archivo equivalente) — test nuevo: >100 categorías, category_name presente en la página final sin segunda consulta

../pos-heladeria/
├── src/app/modules/products/
│   ├── interfaces/product.interface.ts   # Product: + category_name (D5)
│   ├── services/product.service.ts       # ProductResponse (raw) + toProduct(): mapea category_name (D5)
│   └── pages/products-page.component.ts  # quita categoryMap/categoryName()/CategoryService; enlaza product.category_name (D5)
└── (specs de Vitest ya existentes de products-page.component que cubren la columna Categoría)
```

**Structure Decision**: Aplicación web con backend y frontend en repos separados (patrón ya
establecido por el resto de `pos-specs`). Esta corrección no introduce ningún módulo, router,
tabla ni pantalla nueva — modifica tres archivos ya existentes en el backend (un campo derivado,
un `JOIN` y su exposición en la respuesta) y tres en el frontend (el tipo, el mapeo del servicio y
la plantilla/lógica de la página de listado).

## Complexity Tracking

*Sin violaciones de la Constitution Check — tabla no aplica.*
