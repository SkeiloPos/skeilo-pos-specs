# Implementation Plan: Visibilidad de promociones en el menú QR

**Branch**: `144-promociones-visibles-menu-qr` | **Date**: 2026-10-29 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/144-promociones-visibles-menu-qr/spec.md`

## Summary

Hoy el menú QR siempre muestra la pestaña "Promociones" (decisión original de la spec 081,
FR-001), y toda promoción `active` y vigente se anuncia ahí sin ningún control de
visibilidad independiente — a diferencia de `Producto` y `Categoria`, que ya tienen un campo
`visible_en_qr`. Esta feature añade ese mismo campo a `Promoción`, usa la combinación
(vigente ∧ `visible_en_qr=true` ∧ al menos un producto/variante alcanzable por QR) para
decidir qué promociones se anuncian y si la pestaña aparece, y excluye el descuento de
cualquier promoción oculta en QR al calcular pedidos que el comensal envía por su cuenta —
sin afectar en nada la disponibilidad ni el cálculo de descuentos en pedidos manuales
(caja/mesa, canal `POS`).

El enfoque técnico replica exactamente el patrón ya establecido para `Categoria`/`Producto`
(columna booleana con `server_default=true`, migración Alembic por-tenant, PATCH admin-only,
filtro que solo aplica en el camino del comensal firmado por QR) en tres puntos del backend
(modelo/migración, `_build_menu_promotions`, el motor de promociones que consumen
`cart/service.py` y `orders/checkout.py`) y dos puntos del frontend (interfaz/servicio de
`Promotion` y el toggle en la pantalla de administración de promociones).

## Technical Context

**Language/Version**: Python 3.11 (FastAPI) en `pos-backend`; TypeScript/Angular en
`pos-heladeria`.

**Primary Dependencies**: FastAPI, SQLAlchemy 2.x, Alembic, Pydantic (backend); Angular,
TanStack Query (`queryClient`) para invalidación de caché (frontend).

**Storage**: PostgreSQL 16, schema-per-tenant (`tenant.promotions`, `tenant.promotion_rules`,
`tenant.promotion_variants`).

**Testing**: pytest + characterization tests (`app/characterization_tests/`) en backend; no
se identificó un runner de tests frontend ejecutado activamente en este flujo — se valida
manualmente vía quickstart.md, siguiendo el mismo patrón que las specs 128/129 ya cerradas.

**Target Platform**: servidor Linux (API); navegador web, incluido el menú QR servido a
dispositivos móviles del comensal (frontend).

**Project Type**: aplicación web con dos repositorios hermanos (backend + frontend).

**Performance Goals**: sin objetivo nuevo explícito; el filtro añadido reutiliza
consultas/joins ya existentes (`active_variant_set_rules`, resolución de reglas→variantes) sin
introducir N+1 nuevas — ver research.md.

**Constraints**: el cambio no puede alterar en ningún caso la disponibilidad ni el cálculo de
descuentos de promociones en el canal `POS` (pedidos manuales de caja/mesa); debe ser
puramente additivo a nivel de esquema (columna nueva con default, sin tocar datos
existentes).

**Scale/Scope**: multi-tenant (schema-per-tenant); cambio acotado a 1 entidad (`Promotion`) y
a los caminos de lectura/cálculo que ya existen para el canal QR — no introduce entidades
nuevas.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principio I (nace de un spec)** — PASS. `spec.md` ya existe, aprobado, con
  clarificación registrada (sesión 2026-10-29).
- **Principio II (comportamiento existente protegido)** — PASS con nota. Esta feature
  **revierte explícitamente** una decisión previa documentada en la spec 081 (FR-001: la
  pestaña "Promociones" del menú QR es "siempre visible, incluso sin promociones vigentes" —
  ver comentario en `public-menu.component.ts` líneas 311-323). El propio `spec.md` de esta
  feature (sección "Input" + "Clarifications") registra que quien pidió el cambio es el
  responsable del negocio directamente en esta conversación, con el qué/por qué ya
  explícitos en los Functional Requirements (FR-005/FR-006). Este plan trata ese texto como
  el registro de la decisión de negocio exigido por el Principio II; no se requiere una
  entrada adicional en `specs/000-reconocimiento/registro-de-anomalias.md` porque ese
  registro está cerrado y acotado a la fase de reconocimiento (ronda 3, 2026-08-16), no a
  decisiones de negocio de specs posteriores — pero se señala aquí por transparencia, dado
  que modifica un FR de una spec anterior.
- **Principio III (characterization tests)** — PASS. No se identificaron characterization
  tests con prefijo `"CONGELA comportamiento actual:"` sobre "la pestaña de promociones
  siempre visible"; si la fase de tasks encuentra alguno, debe actualizarse citando esta
  spec, no silenciosamente.
- **Principio V/VI (sin refactors oportunistas, evolución incremental)** — PASS. El alcance
  se limita a: 1 columna nueva, 1 migración, 1 campo en schemas/service/router de
  promociones, el filtro en `_build_menu_promotions`, la exclusión en el motor de
  descuentos para canal QR, y el toggle equivalente en frontend — sin tocar el resto del
  módulo de promociones.
- **Principio VII (datos históricos)** — PASS. No se recalculan pedidos ni facturas ya
  emitidas; el cambio solo afecta pedidos nuevos y carritos aún no enviados (ver Assumptions
  del spec).
- **Principio VIII (evolución del modelo de datos)** — ver `data-model.md`: columna nueva
  `visible_en_qr` en `promotions`, `NOT NULL DEFAULT true`, migración por-tenant siguiendo el
  patrón exacto de `cfa621f5b865_128_categories_visible_en_qr.py` /
  `43e57b9da5d9_129_adiciones_nivel_producto.py`, con `downgrade` que elimina la columna.
- **Principio IX (dependencias nuevas)** — PASS. No se introduce ninguna dependencia nueva.
- **Principio X (verificación)** — pendiente de Phase 2 (`/speckit-tasks`): tests de
  característica para FR-001..FR-010 y, si existen, characterization tests afectados.
- **Principio XIV/XV (ramas/commits)** — a aplicar durante implementación, no durante este
  plan.

No se registran violaciones que requieran `Complexity Tracking`.

## Project Structure

### Documentation (this feature)

```text
specs/144-promociones-visibles-menu-qr/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   └── promotions-api.md
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
# Option 2: Web application (backend + frontend, dos repos hermanos)
../pos-backend/
├── app/
│   ├── models/
│   │   └── promotion.py                     # + columna visible_en_qr en Promotion
│   ├── api/v1/promotions/
│   │   ├── schemas.py                        # + visible_en_qr en PromotionUpdate/Response
│   │   ├── service.py                        # + toggle, serialize_promotion, cálculo de
│   │   │                                      #   "al menos un producto/variante alcanzable"
│   │   └── router.py                          # endpoint admin-only ya existente (PATCH /{id})
│   ├── api/v1/menu/
│   │   └── router.py                          # _build_menu_promotions: filtra por
│   │                                          #   visible_en_qr + alcanzabilidad
│   ├── api/v1/cart/
│   │   └── service.py                        # exclusión de promos ocultas al canal QR
│   └── api/v1/orders/
│       └── checkout.py                        # idem, en auto_discount/refresh_order_item_discounts
└── alembic/versions/
    └── <nuevo>_144_promotions_visible_en_qr.py

../pos-heladeria/
└── src/app/modules/promotions/
    ├── interfaces/promotion.interface.ts       # + visible_en_qr en Promotion/PromotionScalars
    ├── services/promotion.service.ts           # + payload/método de toggle
    └── pages/promotions-page.component.ts       # + control de visibilidad en QR por fila
```

**Structure Decision**: aplicación web con dos repositorios hermanos (Opción 2). Todo el
trabajo de esta feature vive dentro de módulos ya existentes en ambos repos (`promotions`,
`menu`, `cart`, `orders` en backend; `promotions` en frontend) — no se crean módulos nuevos.

## Complexity Tracking

> Sin violaciones de la Constitución que requieran justificación.
