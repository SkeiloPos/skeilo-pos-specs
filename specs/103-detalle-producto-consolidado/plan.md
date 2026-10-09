# Implementation Plan: Consolidar receta y grupos de opciones en el detalle de producto (sin peticiones por tamaño)

**Branch**: `103-detalle-producto-consolidado` | **Date**: 2026-10-08 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/103-detalle-producto-consolidado/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Optimización de rendimiento de un endpoint ya existente, a diferencia de la spec 102 (100%
frontend), esta spec **sí toca `pos-backend`**. `GET /products/{id}` gana un tipo de respuesta
nuevo por variante, `VariantDetailResponse` (extiende `VariantResponse` sin tocarlo, D1), con
`recipe`/`option_groups` embebidos — poblados con una consulta de carga ansiosa (`selectinload`,
mismo patrón que ya usa `GET /menu`, D2) en vez de N peticiones perezosas. La receta se oculta
para el rol Cajero dentro del propio servicio (D3), preservando sin reabrir la regla ya vigente de
la spec 093 (FR-018): el Cajero puede ver "Carta del menú → detalle de producto" (que comparte
este mismo endpoint) pero nunca ha podido ver costos/receta. En el frontend,
`ProductService.getProductDraft()` deja de disparar el fetch paralelo por variante que introdujo
la spec 102 (Historia 2) y consume los datos ya embebidos (D4); como consecuencia directa, el
control de "Reintentar" por tamaño de esa misma historia queda sin ningún escenario donde
dispararse y se retira (D5, FR-009 de esta spec).

## Technical Context

**Language/Version**: Backend: Python 3.14/FastAPI, SQLAlchemy (ORM). Frontend: TypeScript ~5.9
(Angular 21). A diferencia de la spec 102, esta spec modifica **ambos** repos

**Primary Dependencies**: SQLAlchemy `selectinload` (ya en uso, `menu/router.py:109-114` — mismo
patrón, sin dependencias nuevas), Pydantic (ya en uso), Angular/RxJS (ya en uso) — cero
dependencias nuevas en ningún repo

**Storage**: PostgreSQL 16, schema-per-tenant. Sin cambios de esquema: ni tablas, ni columnas, ni
migraciones — solo cambia la estrategia de carga (`selectinload` vs. `lazy="select"` por defecto)
y la forma de la respuesta HTTP

**Testing**: Backend: characterization tests / pytest (`app/characterization_tests`, venv del
proyecto — ver memoria del proyecto sobre cómo correrlos). Frontend: Vitest (ya configurado),
extiende `product.service.spec.ts` y `product-form.component.spec.ts`

**Target Platform**: SPA de navegador, panel del tenant — alcanza tanto a Administrador (formulario
de edición) como a Cajero (vista de solo lectura "Carta del menú → detalle de producto"), ambos ya
consumidores del mismo endpoint hoy. El menú QR público (`GET /menu`) no se toca

**Project Type**: Aplicación web, backend + frontend en repos separados (`pos-backend`,
`pos-heladeria`). Esta spec toca **ambos**, a diferencia de la 102

**Performance Goals**: cero peticiones HTTP adicionales de receta/grupos de opciones por tamaño al
abrir el formulario de edición (SC-001); número total de peticiones constante sin importar cuántos
tamaños tenga el producto (SC-002, pasa de `2 + 2N` a `2`)

**Constraints**: `recipe`/`option_groups` embebidos DEBEN tener exactamente la misma forma que ya
devuelven `GET /variants/{id}/recipe`/`GET /variants/{id}/option-groups` (FR-005, reutilizando los
mismos tipos Pydantic, D1). El Cajero NUNCA debe recibir receta en la respuesta, sin importar
desde qué pantalla la pida (FR-003, preserva spec 093 FR-018). Los endpoints independientes por
variante NO se eliminan: siguen sirviendo la recarga puntual de una sola variante (FR-006)

**Scale/Scope**: Backend: `products/router.py`, `products/schemas.py`, `products/service.py` (+
tests). Frontend: `product.service.ts` (`getProductDraft()`, retiro de `retryVariant()`),
`product-form.component.ts` (retiro de `retryVariantLoad()` y su control de plantilla),
`product.interface.ts` (retiro de `VariantDraft.loadError`). Cero endpoints nuevos (se amplía uno
existente), cero migraciones, cero tablas nuevas

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Evaluación |
|---|---|
| I. Nace de un spec | ✅ `specs/103-detalle-producto-consolidado/spec.md`, 1 historia de usuario, 9 FR y 4 SC cerrados, sin `NEEDS CLARIFICATION` pendiente; seguimiento registrado explícitamente en la sesión Clarifications de la spec 102 |
| II. Comportamiento existente protegido | ✅ Los campos nuevos de `GET /products/{id}` son aditivos (no rompen a quien ya lee ese endpoint). El único comportamiento visible que desaparece — el control de "Reintentar" por tamaño de la spec 102 — está explícitamente autorizado por esta misma spec (FR-009) como consecuencia técnica directa de volver atómica la carga, no una decisión de negocio nueva; no aplica entrada en `registro-de-anomalias.md`. FR-003/D3 preservan, sin reabrir, la regla ya vigente de la spec 093 (FR-018) |
| III. Characterization tests protegen lo heredado | Pendiente de confirmar al iniciar `tasks.md`: verificar si existe algún test `"CONGELA comportamiento actual:"` sobre `GET /products/{id}` o `to_detail_response`; de existir, no se toca sin la autorización que esta spec ya documenta (FR-001/FR-003) |
| IV. Los nuevos specs pueden introducir comportamiento nuevo | N/A — esta spec no introduce comportamiento de negocio nuevo, optimiza cómo se recupera información ya existente |
| V. Nueva funcionalidad antes que refactor oportunista | ✅ El retiro de `loadError`/`retryVariantLoad()`/`retryVariant()` (D5) es consecuencia directa de D4, no una limpieza no relacionada — código que queda inalcanzable por el cambio mismo, no un refactor aparte. No se generaliza `get_or_404` para un segundo caso hipotético (D2, alternativa rechazada) |
| VI. Evolución incremental | ✅ Una sola historia de usuario, acotada a un endpoint ya existente; no mezcla con cambios de otras pantallas |
| VII. Compatibilidad con datos históricos | N/A — no se toca facturación ni datos históricos |
| VIII. Evolución del modelo de datos | N/A — sin cambios de esquema; `data-model.md` documenta solo la forma de la respuesta HTTP (`VariantDetailResponse`) y la estrategia de consulta, no entidades persistidas |
| IX. Dependencias nuevas | N/A — `selectinload` ya está en uso en el mismo repo (`menu/router.py`); ninguna dependencia nueva en ningún repo |
| X. Verificación obligatoria | ✅ `quickstart.md` cubre los 7 escenarios de aceptación; `tasks.md` debe incluir tests de: forma de `VariantDetailResponse` para Admin y para Cajero (`recipe` vacío solo para Cajero, `option_groups` poblado para ambos), ausencia de N+1 (una sola consulta adicional por relación, no una por variante), `product.service.spec.ts` (consumo de datos embebidos, cero peticiones por variante), `product-form.component.spec.ts` (ausencia del control de reintento por tamaño) |
| XI. Decisiones de negocio frente a decisiones técnicas | ✅ FR-003 es la continuidad de una decisión de negocio ya tomada (spec 093, FR-018), documentada como tal, no reabierta; FR-009 es una decisión técnica explícita (consecuencia de D4), no enterrada en el código |
| XII. Trazabilidad | ✅ research.md y el contrato citan los FR de spec.md por número; data-model.md referencia research.md por decisión (D1-D5) |
| XIII. Español de Colombia | ✅ Todos los artefactos de esta funcionalidad están en español; identificadores de código nuevos (`VariantDetailResponse`, `get_detail_or_404`) usan inglés técnico, consistente con el resto del código de ambos repos |
| XIV. Convención de ramas Git | Pendiente al iniciar la implementación: crear `perf/103-detalle-producto-consolidado` en **ambos** repos (`pos-backend` y `pos-heladeria`) antes de tocar código, conforme a `<tipo>/<numero_spec>-<nombre_spec>` — `perf` como tipo Conventional Commits equivalente, dado que es una optimización de rendimiento, no un `fix` ni un `feat` de negocio |
| XV. Política de commits | Pendiente al iniciar la implementación: commits solo bajo pedido explícito del usuario, atómicos, en inglés, sin marca de IA |

**Resultado**: sin violaciones. No se requiere la tabla de Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/103-detalle-producto-consolidado/
├── plan.md                               # This file (/speckit-plan command output)
├── research.md                           # Phase 0 output (/speckit-plan command)
├── data-model.md                         # Phase 1 output (/speckit-plan command)
├── quickstart.md                         # Phase 1 output (/speckit-plan command)
├── contracts/
│   └── products-detail-embedded.md       # Phase 1 output (/speckit-plan command)
├── checklists/
│   └── requirements.md
└── tasks.md                              # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

Este repo (`pos-specs`) solo contiene la documentación de la funcionalidad. El código vive en los
repos hermanos `pos-backend` y `pos-heladeria` (ya existentes) — no se crea ninguna carpeta ni
proyecto nuevo:

```text
../pos-backend/
├── app/api/v1/products/
│   ├── schemas.py                        # + VariantDetailResponse (D1); ProductDetailResponse.
│   │                                     #   variants: list[VariantResponse] → list[VariantDetailResponse]
│   ├── service.py                        # + get_detail_or_404() con selectinload (D2);
│   │                                     #   to_detail_response() puebla recipe/option_groups
│   │                                     #   según rol (D3)
│   ├── router.py                         # get_product(): pasa el user actual a to_detail_response
│   │                                     #   para que pueda decidir por rol (D3)
│   └── (tests characterization/unitarios existentes, extendidos)
│
../pos-heladeria/
├── src/app/modules/products/services/
│   └── product.service.ts                # getProductDraft(): consume recipe/option_groups
│                                         #   embebidos (D4); retira retryVariant() (D5)
├── src/app/modules/products/interfaces/
│   └── product.interface.ts              # retira VariantDraft.loadError (D5)
└── src/app/modules/products/pages/
    └── product-form.component.ts         # retira retryVariantLoad() y su control de
                                          #   "Reintentar" por tamaño (D5)
```

**Structure Decision**: Aplicación web con backend y frontend en repos separados (patrón ya
establecido por el resto de `pos-specs`). Esta optimización no introduce ningún módulo, tabla ni
pantalla nueva — amplía un endpoint ya existente y simplifica el consumo que ya hacía el
formulario de producto desde la spec 102, incluyendo el retiro explícito de código que queda
inalcanzable como consecuencia directa (D5).

## Complexity Tracking

*Sin violaciones de la Constitution Check — tabla no aplica.*
