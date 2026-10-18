# Implementation Plan: Visibilidad de categorías en el menú QR

**Branch**: `feat/128-categoria-visible-menu-qr` | **Date**: 2026-10-18 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/128-categoria-visible-menu-qr/spec.md`

## Summary

Agregar un atributo `visible_en_qr` a `Category` (por defecto visible, independiente de
`active`) que el administrador controla desde la misma pantalla de Categorías, y que el menú QR
público (y su buscador, que filtra en cliente sobre esos mismos datos) respeta sin afectar en
nada al catálogo del personal, la creación de pedidos manuales ni los reportes. El enfoque es
mínimo en los tres puntos que ya existen y hacen casi todo el trabajo: una condición más en el
`where()` del menú QR, un campo más en el PATCH de categorías ya existente (con una
restricción de rol nueva, acotada solo a ese campo — hoy el endpoint no restringe ningún otro
campo por rol), y una revalidación nueva en el envío del carrito que seguirá el mismo patrón ya
usado para productos agotados (spec 093), extendida para además limpiar el carrito. La
actualización en vivo de un menú QR ya abierto (US3) es la única pieza que no es una extensión
de algo existente — requiere un canal de tiempo real nuevo para comensales — y por eso queda
como mejora de prioridad P3 (SHOULD), no como condición para dar la spec por completa.

## Technical Context

**Language/Version**: Backend: Python 3.11 (FastAPI + SQLAlchemy). Frontend: TypeScript ~5.9 /
Angular ^21.1 (standalone components, signals).

**Primary Dependencies**: Ninguna nueva (Principio IX). Se reutilizan: el patrón de migración
por tenant ya usado por `display_order` (`@for_each_tenant_schema`), el patrón de revalidación
de disponibilidad en `submit_cart` (spec 093, `ensure_products_available`), el patrón de
columna/toggle de `active` en la UI de administración de categorías
(`category.service.ts::toggleActive`), y la infraestructura de eventos SSE ya existente
(`app/core/events.py`/`app/api/v1/realtime/`) para la parte opcional de US3.

**Storage**: PostgreSQL 16, schema-per-tenant. Una migración nueva: `categories.visible_en_qr`
(`boolean NOT NULL DEFAULT true`), sin backfill de datos (research.md, Decisión 1).

**Testing**: Backend: `./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`
— confirmar en verde sin modificación, más tests nuevos para: el filtro del menú QR
(`test_menu_router.py`), la revalidación del carrito al enviar (`test_cart_service.py`, mismo
archivo que ya cubre spec 093), la restricción de rol acotada al campo nuevo
(`categories/router.py`, archivo de test a determinar en `/speckit-tasks` — no hay uno
dedicado hoy, confirmado que el router no tiene ninguno propio de permisos). Frontend:
`ng test --watch=false --include='src/app/modules/categories/**/*.spec.ts'` más los tests del
menú QR que correspondan.

**Target Platform**: API web (FastAPI) + aplicación web POS (Angular) + menú público QR
(mismo frontend Angular, ruta pública) — todos ya en producción.

**Project Type**: Web application (frontend Angular + backend FastAPI ya existentes).

**Performance Goals**: N/A — un `where()` adicional sobre una columna indexable no cambia el
perfil de rendimiento del menú QR; la revalidación del carrito opera sobre el mismo conjunto de
ítems que ya recorre `ensure_products_available`.

**Constraints**: No introducir ningún endpoint nuevo para la administración de categorías
(reutilizar `PATCH /categories/{id}`, research.md Decisión 2). No restringir por rol ningún
campo del PATCH que no sea `visible_en_qr` (research.md Decisión 3 — evita un cambio de
comportamiento existente no autorizado por esta spec, Principio II). No tocar
`_build_menu_promotions` (fuera de alcance, research.md Decisión 4). No inventar una ruta de
"orden parcial" en `submit_cart` — el envío sigue siendo todo-o-nada, solo se suma la limpieza
automática del carrito (research.md Decisión 5).

**Scale/Scope**: Backend: 1 migración, 1 columna de modelo, 2 campos de schema
(`CategoryUpdate`/`CategoryResponse`), 1 condición de filtro (`menu/router.py`), 1 revalidación
nueva en `cart/service.py`, 1 chequeo de rol acotado en `categories/router.py`. Frontend: 1
columna nueva + 1 toggle + 1 opción de filtro en la pantalla de Categorías, 1 método nuevo en
`category.service.ts`, 1 interfaz actualizada. US3 (opcional, P3): 1 canal SSE nuevo para
comensales + 1 evento nuevo + 1 listener nuevo en `public-menu.component.ts` que hoy no existe
en absoluto (research.md, Decisión 6) — se trata como incremento aparte, no bloquea el resto.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principio I (nace de un spec)**: ✅ `specs/128-categoria-visible-menu-qr/spec.md` existe,
  pasó el checklist de calidad (16/16) sin necesitar ninguna sesión de `/speckit-clarify` (el
  brief original ya traía reglas de negocio y escenarios completos).
- **Principio II (comportamiento existente protegido / decisión de negocio registrada)**: ✅
  con una decisión explícita documentada en research.md (Decisión 3): el único comportamiento
  existente que esta spec podría haber tocado — que hoy cualquier usuario autenticado puede
  editar cualquier campo de una categoría, sin restricción de rol — se deja **intacto** para
  todos los campos que no sean `visible_en_qr`. La restricción nueva de FR-005 aplica
  exclusivamente sobre un campo que no existía antes de esta spec, así que no hay ningún
  comportamiento previo que proteger ni ninguna decisión de negocio que registrar en
  `registro-de-anomalias.md` — no se amplía la restricción al resto del endpoint sin que una
  spec futura lo pida explícitamente.
- **Principio III (characterization tests)**: no se identificó ningún test
  `"CONGELA comportamiento actual:"` sobre `_build_menu`, `update_category` o `submit_cart`
  cuyo resultado cambie por esta spec en un caso que ya cubrieran — se confirmará en Phase 2
  (tasks) revisando `test_menu_router.py`/`test_cart_service.py`/categorías antes de tocar
  nada, y cualquiera que sí dependa del comportamiento viejo se actualiza citando esta spec.
- **Principio IV (los specs pueden introducir comportamiento nuevo)**: ✅ aplica — `
  visible_en_qr`, su restricción de rol, y la revalidación del carrito son comportamiento
  nuevo definido por esta spec, no una corrección de un defecto.
- **Principio V/VI (sin refactor oportunista, cambio incremental)**: ✅ el alcance se limita
  exactamente a los puntos listados en Constraints arriba; US3 se separa aparte precisamente
  para no mezclar una pieza de infraestructura nueva (canal SSE de comensal) con el resto, que
  son cambios incrementales sobre código ya existente.
- **Principio VII (datos históricos)**: ✅ sin riesgo — los pedidos QR ya enviados quedan
  explícitamente fuera del alcance de la revalidación (FR-007 solo aplica a pedidos nuevos,
  Edge Cases de `spec.md`); ningún reporte ni venta histórica se recalcula.
- **Principio VIII (evolución del modelo de datos)**: ✅ una columna nueva, booleana, con
  valor por defecto y sin migración de datos existentes más allá del default — estrategia de
  rollback trivial (`DROP COLUMN`, sin pérdida de información que no sea la propia bandera).
- **Principio IX (dependencias nuevas)**: ✅ ninguna.
- **Principio X (verificación obligatoria)**: se cubre con las suites de characterization
  tests ya existentes (confirmando que no se rompen) más los tests nuevos listados en Testing,
  uno por cada punto de la lista de Scope arriba.
- **Principio XI (decisiones de negocio vs técnicas)**: ✅ FR-005 (solo ADMIN) y FR-001/FR-002
  (criterio de visibilidad) son decisiones de negocio ya tomadas en `spec.md`, citadas tal
  cual; el resto (migración por tenant, patrón de revalidación, canal SSE) son decisiones
  técnicas de este plan, documentadas en research.md con su alternativa considerada.
- **Principio XII (trazabilidad)**: ✅ cadena completa: Necesidad (brief del usuario) → Spec
  128 → Investigación (research.md, con los dos hallazgos reales: cardinalidad
  producto-categoría y ausencia de restricción de rol) → Plan (este documento) →
  Implementación → Tests → Verificación.
- **Principio XIV (rama Git)**: se crea `feat/128-categoria-visible-menu-qr` en **ambos**
  repositorios (backend para el modelo/migración/endpoints, frontend para la UI de
  administración), partiendo de `develop` en cada uno.
- **Principio XV (commits)**: solo bajo pedido explícito del usuario, en unidades lógicas
  separadas por repo/capa, en inglés, sin marcas de autoría de IA.

**Resultado**: PASA. Sin violaciones que requieran justificación en Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/128-categoria-visible-menu-qr/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output — 8 decisiones técnicas, dos hallazgos reales
├── data-model.md         # Phase 1 output — Category.visible_en_qr y su relación con active/display_order
├── contracts/
│   └── categorias-visibilidad-qr.md  # PATCH /categories/{id}, GET /menu, submit_cart, evento SSE opcional
├── quickstart.md         # Phase 1 output — 8 escenarios de validación manual + verificación automatizada
└── checklists/
    └── requirements.md  # Spec quality checklist (/speckit-specify command)
```

### Source Code (repository root)

```text
pos-backend/
└── app/
    ├── models/category.py                  # + visible_en_qr: Mapped[bool]
    ├── alembic/versions/<nueva>_categories_visible_en_qr.py  # @for_each_tenant_schema, sin backfill
    ├── api/v1/categories/
    │   ├── schemas.py                       # CategoryUpdate/CategoryResponse + visible_en_qr
    │   └── router.py                        # update_category(): chequeo de rol acotado al campo (FR-005/FR-006)
    ├── api/v1/menu/router.py                # _build_menu(): + Category.visible_en_qr.is_(True)
    ├── api/v1/cart/service.py               # submit_cart(): nueva revalidación + limpieza de carrito (FR-007)
    ├── core/events.py                       # (US3, opcional) evento menu.updated + canal nuevo de comensal
    └── api/v1/realtime/auth.py              # (US3, opcional) Subscriber de comensal gana el canal nuevo

pos-heladeria/
└── src/app/modules/
    ├── categories/
    │   ├── pages/categories-page.component.ts        # columna "Menú QR" + toggle + filtro "Ocultas en QR"
    │   ├── services/category.service.ts               # toggleVisibleQr(), mismo patrón que toggleActive()
    │   └── interfaces/category.interface.ts            # + visible_en_qr
    └── tables/pages/public-menu.component.ts            # (US3, opcional) listener menu.updated + re-fetch
```

**Structure Decision**: cambios divididos en dos capas por repositorio, cada una con su propia
rama `feat/128-categoria-visible-menu-qr` (Principio XIV). US3 (canal SSE + listener del menú
QR) se mantiene identificable como bloque aparte en ambos repos para poder entregarse — o
posponerse — sin afectar al resto (Principio VI).

## Complexity Tracking

*No aplica — el Constitution Check no reporta violaciones.*
