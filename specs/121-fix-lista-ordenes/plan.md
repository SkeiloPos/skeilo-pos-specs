# Implementation Plan: Correcciones visuales y funcionales de la lista de Órdenes

**Branch**: `121-fix-lista-ordenes` | **Date**: 2026-10-16 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/121-fix-lista-ordenes/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Cuatro correcciones, independientemente verificables, sobre la lista de Órdenes migrada en spec 120: (1) el total de cada orden no se muestra en su tarjeta — requiere un campo nuevo `total` en `OrderResponse`, poblado en el detalle y en la rama paginada de `GET /orders` con dos consultas en bloque (no por fila), preservando intacto el contrato ya protegido de que `billing` sigue `null` en el listado (D3/D15); (2) el texto del filtro de fecha queda congelado en "Hoy" tras elegir otro día porque el `computed()` que lo calcula lee una propiedad `@Input()` corriente en vez de una signal — se corrige convirtiendo esa entrada a `input()`; (3) falta el rango "X–Y de Z" del paginador del diseño de referencia — se añade un paginador propio de la pantalla "Órdenes" (no se toca el componente compartido que usan otras 8 pantallas, por decisión explícita de la Clarification); (4) las etiquetas de estado no se ven como píldoras completamente redondeadas — el código ya usa `rounded-full` en ambas, así que la implementación debe primero reproducir el defecto contra `main` antes de asumir la causa.

## Technical Context

**Language/Version**: TypeScript 5.x sobre Angular 21 (`pos-heladeria`, frontend) · Python 3.14 sobre FastAPI 0.136 (`pos-backend`, backend)

**Primary Dependencies**: Angular standalone components + Signals (`input()`, `computed()`), Tailwind CSS v4 (`@tailwindcss/postcss`, sin `tailwind.config.js`), `@tanstack/angular-query-experimental` (`injectPagedQuery`) — frontend. FastAPI, SQLAlchemy 2.x, Pydantic v2 — backend.

**Storage**: PostgreSQL 16, schema-per-tenant (sin migraciones: `total` es un campo de respuesta computado, no una columna nueva).

**Testing**: `pos-backend`: `./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'` (characterization tests; el guardia relevante es `test_orders_pagination.py::test_guardia_de_trabajo_acotado_numero_de_sentencias_constante`). `pos-heladeria`: `npx ng test --watch=false [--include=...]` (Vitest vía `@angular/build:unit-test`).

**Target Platform**: Web — mismo navegador/responsive (escritorio y tablet/móvil) que ya sirve la pantalla "Órdenes" de spec 120.

**Project Type**: Web (frontend `pos-heladeria` + backend `pos-backend`, dos repos hermanos de `pos-specs`).

**Performance Goals**: El número de sentencias SQL que ejecuta `GET /orders?page=&size=` debe seguir siendo **constante respecto al tamaño de la página** (no crecer con N) — mismo presupuesto que ya exige `test_guardia_de_trabajo_acotado_numero_de_sentencias_constante`; esta spec añade como máximo 2 consultas fijas adicionales (research.md §1), nunca una por fila.

**Constraints**: No modificar `PaginationBarComponent` (compartido con otras 8 pantallas) — Clarification de sesión 2026-10-16. No poblar `billing` en el listado (contrato D3/D15 ya protegido). No alterar la rama sin paginar de `GET /orders` (Terminal/Dashboard). Ninguna factura ya emitida se recalcula ni se re-representa (Principio VII) — `total` solo *lee* `Sale.total` o deriva de columnas ya existentes del pedido, nunca escribe.

**Scale/Scope**: 4 historias de usuario, 1 campo de respuesta nuevo (sin migración), 1 componente Angular nuevo (paginador propio de Órdenes), cambios acotados a `pos-backend/app/api/v1/orders/` y `pos-heladeria/src/app/modules/orders/`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Evaluación |
|---|---|
| I. Nace de un spec | ✅ `specs/121-fix-lista-ordenes/spec.md`, con Clarifications resueltas antes de este plan. |
| II. Comportamiento existente protegido | ✅ Explícitamente delimitado: `billing` sigue `null` en el listado; la rama sin paginar de `GET /orders` no cambia; `PaginationBarComponent` y sus otros 8 consumidores no cambian; filtros de estado/tipo/búsqueda/fecha y navegación al detalle no cambian (FR-008, SC-005). El único comportamiento nuevo (campo `total` disponible en el listado) es aditivo, no una redefinición de algo ya en producción. |
| III. Characterization tests protegidos | ✅ `test_guardia_de_trabajo_acotado_numero_de_sentencias_constante` sigue pasando por diseño (consultas en bloque, no por fila — research.md §1). Ningún test con prefijo `"CONGELA comportamiento actual:"` necesita tocarse: esta feature no cambia ningún comportamiento que esos tests fijen. |
| IV. Nuevo comportamiento vía spec | ✅ El campo `total` y el nuevo paginador son comportamiento nuevo definido por este spec, no una reinterpretación retroactiva. |
| V. No mezclar refactor oportunista | ✅ Las 4 correcciones son las ya reportadas por el negocio sobre la vista recién migrada (spec 120); no se toca nada fuera de ese alcance (p. ej. no se migra `PaginationBarComponent` "ya que se está ahí"). |
| VI. Evolución incremental | ✅ 4 historias independientemente testeables (spec.md), cada una verificable por separado; no se mezcla cambio de arquitectura ni migración de datos con esta corrección visual/de datos puntual. |
| VII. Compatibilidad con datos históricos | ✅ `total` es de solo lectura: lee `Sale.total` ya emitido o deriva de columnas existentes del pedido (`discount`, `delivery_fee`, `line_total` de sus ítems) — no recalcula ni reemite ninguna factura. |
| VIII. Evolución del modelo de datos | ✅ N/A — sin columnas nuevas, sin migración, sin estrategia de rollback que declarar (data-model.md). |
| IX. Dependencias nuevas | ✅ N/A — ninguna dependencia nueva; todo con las librerías ya presentes en ambos repos. |
| X. Verificación obligatoria | ✅ Planificado: characterization tests existentes + nuevos tests de `total`/filtro de fecha/paginador + criterios de aceptación del spec (quickstart.md). |
| XI. Negocio vs. técnico | ✅ El spec ya registra como decisión de negocio (Clarifications) que el total debe ser exacto (no aproximado) y que el paginador no debe tocar el componente compartido — ambas con implicación de alcance, ya resueltas antes de este plan. |
| XII. Trazabilidad | ✅ Cadena completa: Reporte del negocio (prompt de `/speckit-specify`) → spec 121 → Clarifications → este plan → (pendiente) tasks/implementación/tests. |
| XIII. Español de Colombia | ✅ Todos los artefactos de esta fase (spec, research, data-model, contratos, quickstart) en español de Colombia; nombres de rama/commits quedan para la fase de implementación, en inglés (Principios XIV/XV). |

**Gate (pre-Phase 0)**: PASA. No hay violaciones que registrar en Complexity Tracking.

**Gate (post-Phase 1, re-chequeado tras research.md/data-model.md/contracts/)**: PASA sin cambios. El diseño final (campo `total` de solo lectura con consultas en bloque, paginador propio de Órdenes, `input()` signal en el filtro de fecha) no introdujo ninguna dependencia, columna de base de datos, ni modificación de contrato protegido (`billing` sigue `null` en el listado; `PaginationBarComponent` y la rama sin paginar de `GET /orders` siguen intactos) más allá de lo ya evaluado arriba.

## Project Structure

### Documentation (this feature)

```text
specs/121-fix-lista-ordenes/
├── plan.md                        # This file (/speckit-plan command output)
├── research.md                    # Phase 0 output (/speckit-plan command)
├── data-model.md                  # Phase 1 output (/speckit-plan command)
├── quickstart.md                  # Phase 1 output (/speckit-plan command)
├── contracts/
│   └── orders-total-field.md      # Phase 1 output (/speckit-plan command)
├── checklists/
│   └── requirements.md            # /speckit-specify + /speckit-clarify output
└── tasks.md                       # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

Dos repos hermanos de `pos-specs`, ya en producción — ninguna reestructuración de carpetas, solo archivos nuevos/modificados dentro de la organización por módulo ya existente.

```text
../pos-backend/
├── app/
│   └── api/v1/orders/
│       ├── router.py              # list_orders: poblar `total` solo en la rama paginada, con una llamada aparte de _decorate_orders (que sigue sirviendo, sin cambios, también a la rama sin paginar)
│       ├── service.py             # nueva función en bloque para `total` (mismo patrón que paid_order_ids)
│       └── schemas.py             # OrderResponse.total (nuevo campo)
└── app/characterization_tests/
    └── test_orders_pagination.py  # test nuevo: `total` presente y constante en nº de sentencias

../pos-heladeria/
└── src/app/modules/orders/
    ├── pages/
    │   └── orders-page.component.ts        # tarjeta: total + badges; usa el nuevo paginador
    ├── components/
    │   ├── order-date-filter.component.ts  # value: @Input() → input() (signal)
    │   └── orders-pagination.component.ts  # NUEVO: paginador propio de esta pantalla
    └── (sin cambios en orders-list.service.ts: page/size/total ya existen como signals)
```

**Structure Decision**: Cambio acotado dentro de la organización por módulo que ya existe en ambos repos (`app/api/v1/orders/` en el backend, `src/app/modules/orders/` en el frontend) — mismo patrón que usó spec 120 para migrar esta misma pantalla. No se crea ningún módulo, carpeta de nivel superior ni dependencia nueva; el único archivo nuevo es el componente de paginación propio de Órdenes (`orders-pagination.component.ts`), consecuencia directa de la Clarification que descarta tocar el `PaginationBarComponent` compartido.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No aplica — el Constitution Check no registró violaciones. No se añade ninguna dependencia, proyecto, capa de abstracción ni columna de base de datos nueva.
