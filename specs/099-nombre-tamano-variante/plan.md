# Implementation Plan: Nombre comercial propio para los tamaños de un producto

**Branch**: `099-nombre-tamano-variante` | **Date**: 2026-10-06 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/099-nombre-tamano-variante/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

El backend agrega una columna puramente aditiva, `product_variants.name` (0-60 caracteres,
normalizada, nunca `null`), y una propiedad calculada de solo lectura `display_name` (`name` si no
está vacío, si no `presentation.name`, si ninguno está disponible `"Tamaño"` + advertencia). Esa
columna y esa propiedad se exponen en las respuestas de guardado de producto/variante y en el menú
público (`display_name`), reemplazando a `presentation_name` solo en los puntos donde el frontend
pinta lo que ve el comensal (menú, carrito, resumen de checkout) — `presentation_name` se conserva
intacto para compatibilidad hacia atrás. El formulario "Tamaños del producto" gana el campo "Nombre
(opcional)" junto a la presentación de cada fila, con el mismo patrón de validación en vivo que ya
usa esa pantalla. El texto de línea persistido en pedidos/ventas y las pantallas de Órdenes/Ventas
no se tocan (research.md D11) — fuera del alcance que el negocio declaró.

## Technical Context

**Language/Version**: Backend: Python 3.14 (FastAPI). Frontend: TypeScript ~5.9 (Angular 21)

**Primary Dependencies**: Backend: FastAPI, SQLAlchemy, Alembic, Pydantic (sin dependencias
nuevas). Frontend: Angular, RxJS, `@tanstack/angular-query-experimental` (sin dependencias nuevas)

**Storage**: PostgreSQL 16, schema-per-tenant. Un cambio de esquema aditivo: `product_variants`
gana `name VARCHAR(60) NOT NULL DEFAULT ''` (data-model.md), vía una migración Alembic reversible
por schema de tenant

**Testing**: Backend: `unittest` (`app/characterization_tests/`, convención real del repo — no
existe un directorio separado para tests de funcionalidad nueva, research.md D12). Frontend: Vitest
(componentes/servicios) — ambos ya configurados

**Target Platform**: Backend: servidor Linux (API). Frontend: SPA de navegador — tanto el panel del
tenant (Administrador, formulario de productos) como el menú QR público (comensal)

**Project Type**: Aplicación web (backend + frontend en dos repos separados: `pos-backend`,
`pos-heladeria`; este repo, `pos-specs`, solo contiene la documentación)

**Performance Goals**: Ninguno nuevo más allá del ya exigido hoy (FR-018, Escenario 17): el número
de consultas del menú público no puede crecer con la cantidad de variantes. Ya se cumple hoy
(`ProductVariant.presentation` es `lazy="joined"`, el router de menú usa `selectinload` sobre
productos/variantes en una sola consulta); `display_name` se calcula en Python sobre datos ya
cargados, sin consulta adicional. `variant_display_names()` (texto de condición de promociones)
sigue siendo una sola consulta por llamada al menú, solo con una columna más en su proyección
(research.md D10)

**Constraints**: `presentation_id` sigue siendo obligatorio y la única fuente estructural del
tamaño (no se reabre la spec 084); `presentation_name` no se retira de ninguna respuesta
(Escenario 15); el texto persistido en pedidos/ventas (`format_item_description`) y las pantallas
de Órdenes/Ventas no se modifican (research.md D11); la validación de nombre duplicado (FR-008)
solo considera variantes activas y es insensible a mayúsculas (Clarificaciones, sesión 2026-10-06)

**Scale/Scope**: Una columna nueva en una tabla ya existente, una propiedad calculada, dos campos
nuevos en tres esquemas de respuesta y uno de entrada (backend), una celda nueva en una grilla de
formulario ya existente y un cambio de origen de dato en dos mapeos del frontend — ningún módulo,
tabla, endpoint ni pantalla nueva

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Evaluación |
|---|---|
| I. Nace de un spec | ✅ `specs/099-nombre-tamano-variante/spec.md`, 4 historias de usuario y 19 requisitos funcionales, sin `NEEDS CLARIFICATION` pendiente (resuelto en `/speckit-clarify`, sesión 2026-10-06) |
| II. Comportamiento existente protegido | ✅ El único comportamiento que cambia es aditivo y opt-in: una variante sin `name` se comporta exactamente igual que hoy (Escenario 1, 3). `presentation_id`/`presentation_name` no cambian de significado. No aplica entrada en `registro-de-anomalias.md`: no se modifica ninguna decisión de negocio previa, se agrega una nueva (research.md, "Contexto histórico") |
| III. Characterization tests protegen lo heredado | ✅ Ningún test `"CONGELA comportamiento actual:"` se toca. `test_variant_sin_nombre_migration.py` (spec 084) no se modifica — su migración y su columna `name` histórica (ya eliminada) no tienen relación con la columna `name` nueva de esta spec, que nace después de que esa columna fue retirada |
| IV. Los nuevos specs pueden introducir comportamiento nuevo | ✅ Esta spec introduce comportamiento de negocio genuinamente nuevo (nombre comercial por variante), autorizado explícitamente por el dueño del producto el 2026-10-06 |
| V. Nueva funcionalidad antes que refactor oportunista | ✅ No se toca `format_item_description`, `orders/checkout.py` ni `sales/service.py` (research.md D11) aunque también leen el nombre de una variante — fuera del alcance declarado. No se crea un directorio `app/tests/` nuevo para los tests de esta spec (research.md D12): se sigue la convención real del repo |
| VI. Evolución incremental | ✅ Cuatro historias de usuario, cada una independientemente verificable (quickstart.md); el cambio de esquema es un único paso aditivo, sin mezclarse con ninguna refactorización no relacionada |
| VII. Compatibilidad con datos históricos | ✅ Ningún pedido, venta ni factura se modifica, recalcula ni cambia su representación (Escenario 12; research.md D11 excluye explícitamente el texto persistido de pedidos) |
| VIII. Evolución del modelo de datos | ✅ `data-model.md` documenta columna nueva, tipo, nulabilidad, default, migración aditiva y su `downgrade` reversible (Escenario 18) |
| IX. Dependencias nuevas | N/A — no se agrega ninguna dependencia de terceros, ni en backend ni en frontend |
| X. Verificación obligatoria | ✅ `quickstart.md` cubre las 4 historias y los 18 escenarios de aceptación; `tasks.md` (siguiente comando) debe incluir el test de la migración (mismo patrón que `test_variant_sin_nombre_migration.py`), el test de `display_name` (incluida la advertencia de log del Escenario 16) y el test de duplicado insensible a mayúsculas sobre variantes activas |
| XI. Decisiones de negocio frente a decisiones técnicas | ✅ La decisión de negocio (permitir un nombre comercial opcional) está en el spec, solicitada directamente por el dueño del producto; las decisiones de este plan (D1-D12) son todas técnicas, derivadas de esa decisión de negocio ya tomada |
| XII. Trazabilidad | ✅ research.md y los contratos referencian los FR/escenarios de spec.md por número; la migración cita la spec en su docstring (mismo patrón que las migraciones previas de este módulo) |
| XIII. Español de Colombia | ✅ Todos los artefactos de esta funcionalidad están en español; los campos nuevos de la API usan inglés técnico (`name`, `display_name`) como ya hace el resto del catálogo de este backend (`presentation_name`, `category_id`, etc.) |
| XIV. Convención de ramas Git | Pendiente al iniciar la implementación: crear `feat/099-variant-display-name` (o equivalente) antes de tocar código en `pos-backend`/`pos-heladeria`, conforme a `<tipo>/<numero_spec>-<nombre_spec>` |
| XV. Política de commits | Pendiente al iniciar la implementación: commits solo bajo pedido explícito del usuario, atómicos, en inglés, sin marca de IA |

**Resultado**: sin violaciones. No se requiere la tabla de Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/099-nombre-tamano-variante/
├── plan.md                              # This file (/speckit-plan command output)
├── research.md                          # Phase 0 output (/speckit-plan command)
├── data-model.md                        # Phase 1 output (/speckit-plan command)
├── quickstart.md                        # Phase 1 output (/speckit-plan command)
├── contracts/
│   ├── variant-name-rules.md            # Phase 1 output (/speckit-plan command)
│   └── product-variants-api.md          # Phase 1 output (/speckit-plan command)
├── checklists/
│   └── requirements.md
└── tasks.md                             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

Este repo (`pos-specs`) solo contiene la documentación de la funcionalidad. El código vive en dos
repos hermanos, ya existentes — no se crea ninguna carpeta ni proyecto nuevo:

```text
../pos-backend/
├── app/models/
│   └── product_variant.py           # + columna `name`, + propiedad `display_name` (D1/D2)
├── app/core/
│   └── variant_name.py              # nuevo: normalize_variant_name() (D3/D4)
├── app/api/v1/catalog/
│   ├── schemas.py                   # VariantCreate/VariantUpdate/VariantSaveIn: + name;
│   │                                 # VariantResponse/VariantSaveOut: + name, + display_name (D7)
│   └── service.py                   # _save_variant_entry: aplica name (D4); nueva
│                                     # display_name_duplicado()/_raise_display_name_conflict() (D5)
├── app/api/v1/products/schemas.py   # VariantSaveOut hereda de VariantResponse: sin cambio propio
├── app/api/v1/menu/
│   ├── schemas.py                   # MenuVariantResponse: + display_name (D7)
│   └── router.py                    # construcción de MenuVariantResponse: + display_name=v.display_name (D7)
├── app/api/v1/promotions/service.py # variant_display_names(): + ProductVariant.name en la proyección (D10)
└── app/characterization_tests/
    └── test_variant_display_name.py # nuevo: name/display_name, duplicado insensible a mayúsculas
                                      # solo entre activas, advertencia del Escenario 16, migración

../pos-backend/alembic/versions/
└── e7d8c9b0a1f2_099_nombre_tamano_variante.py  # aditiva y reversible (D6)

../pos-heladeria/
├── src/app/shared/validators/
│   └── variant-name.validator.ts    # nuevo: normalizeVariantName(), mismo patrón que full-name.validator.ts (D3)
├── src/app/modules/products/
│   ├── interfaces/product.interface.ts   # VariantDraft: + name; VariantSaveIn/VariantResponse (TS): + name/display_name
│   ├── services/product.service.ts       # mapeo hacia/desde VariantDraft: + name
│   └── pages/product-form.component.ts   # grilla "Tamaños del producto": + celda "Nombre (opcional)",
│                                          # placeholder dinámico, validación de longitud en canSave() (D9)
├── src/app/core/services/menu.service.ts       # toCategory(): name: v.display_name (antes v.presentation_name) (D8)
└── src/app/modules/tables/services/diner.service.ts  # mapCategory(): name: v.display_name ?? v.presentation_name ?? v.name (D8)
```

**Structure Decision**: Aplicación web con backend y frontend en repos separados (patrón ya
establecido por el resto de `pos-specs`). Esta funcionalidad no introduce ningún módulo, router,
tabla ni pantalla nueva — modifica seis archivos ya existentes en el backend (más una migración y
un módulo de normalización nuevos, ambos triviales) y cinco en el frontend (más un validador
nuevo, mismo patrón que uno ya existente).

## Complexity Tracking

*Sin violaciones de la Constitution Check — tabla no aplica.*
