# Implementation Plan: Vigencia de promociones en la hora local del tenant

**Branch**: `fix/127-promotions-tenant-timezone` | **Date**: 2026-10-18 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/127-fix-zona-horaria-promociones/spec.md`

## Summary

Dos defectos relacionados, confirmados por investigación directa del código (`research.md`):
(1) el frontend calcula "hoy" con la fecha **UTC** (`new Date().toISOString()`) al guardar
`starts_at` sin fecha explícita, desplazando la vigencia un día entero después de las ~7pm
hora de Bogotá; (2) el motor de vigencia del backend (`promotions/service.py`) nunca recibe
el `Tenant` ya resuelto por cada router, así que siempre cae al respaldo global
`settings.TENANT_TIMEZONE` en vez de la columna `timezone` del tenant propietario de cada
promoción. El enfoque técnico es mínimo y quirúrgico en ambos repos: en el frontend,
reemplazar el cómputo de fecha por `businessToday(tz)` (utilidad ya existente, spec 030) en
los dos sitios donde se calcula; en el backend, extender con un parámetro `tenant` opcional
(mismo patrón que ya tiene `_tz()`) las cuatro funciones del motor de vigencia y enhebrar el
`Tenant` que cada uno de los seis sitios de evaluación (menú, carrito, cobro) **ya tiene
resuelto en su propio router/contexto** — ninguno exige una consulta nueva. Sin
dependencias nuevas, sin migraciones, sin cambios de contrato de API observable.

## Technical Context

**Language/Version**: Backend: Python 3.11 (FastAPI + SQLAlchemy). Frontend: TypeScript
~5.9 / Angular ^21.1 (standalone components, signals).

**Primary Dependencies**: Ninguna nueva (Principio IX). Backend: se reutiliza
`resolve_timezone(tenant)` (`app/core/timezone.py`, spec 030), ya usado por
`orders/service.py`/`sales/service.py`. Frontend: se reutiliza `businessToday(timezone)`
(`shared/date-format.util.ts`, spec 030) y `TenantInfoService.info()?.timezone`
(`core/tenant/tenant-info.service.ts`), mismo patrón ya usado por `reports.service.ts`.
`Intl.DateTimeFormat` con `timeZone` es el enfoque ya establecido en el proyecto;
`date-fns-tz`/`luxon`/`moment`/`dayjs` no están en `package.json` y no se justifican aquí.

**Storage**: PostgreSQL 16, schema-per-tenant — sin migraciones, sin cambios de esquema. La
columna `Tenant.timezone` (spec 030) ya existe con `server_default='America/Bogota'`.

**Testing**: Backend: `./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`
(en particular `test_promotions_service.py`, `test_promotions_rules_admin.py`) más el script
de CI dedicado `python -m app.scripts.test_promotions_rules` (protección específica del
cruce de medianoche/A-57, research.md Decisión 4) — ambos deben seguir en verde. Se agregan
tests nuevos, con un `Tenant` de zona horaria distinta a `America/Bogota` explícito, donde la
cobertura actual no distinga "vigente según el tenant" de "vigente según el valor global"
(hoy coinciden siempre, por eso el defecto es invisible). Frontend:
`ng test --watch=false --include='src/app/modules/promotions/**/*.spec.ts'` — confirmar en
verde y agregar un test de regresión para `starts_at` usando `businessToday`/zona horaria
simulada, citando esta spec.

**Target Platform**: API web (FastAPI) + aplicación web POS (Angular) — ambos ya en
producción.

**Project Type**: Web application (frontend Angular + backend FastAPI ya existentes). Esta
spec es una **corrección de defecto** (Principio IV: no introduce comportamiento de negocio
nuevo, corrige uno ya definido — spec 030/040/063 — que no se estaba cumpliendo).

**Performance Goals**: N/A — sin cambio de complejidad algorítmica; pasar un parámetro
adicional (`tenant`) ya resuelto en memoria no agrega ninguna consulta nueva (FastAPI cachea
la dependencia `Depends(get_tenant)` por request; `ctx.tenant` ya viaja en `SessionContext`/
contexto QR).

**Constraints**: No modificar `_in_time_window()` ni la atribución de día por cruce de
medianoche (A-57) dentro de `_valid_now()` — su **lógica** se conserva íntegra (Principio
III); solo ganan un parámetro `tenant` adicional. No tocar `PROMOTION_TRANSITIONS` ni ningún
estado de promoción. No migrar ni recalcular promociones ya guardadas con `starts_at`
desplazado (Assumptions de `spec.md`): se corrigen manualmente, volviendo a guardarlas.

**Scale/Scope**: Backend: 4 funciones extendidas con un parámetro opcional
(`promotions/service.py`) + 6 sitios de llamada reales actualizados para pasarlo
(`menu/router.py` ×3, `cart/service.py` ×2, `orders/checkout.py` ×6 funciones de servicio,
cada una recibiendo el `tenant` que su router ya tiene). Frontend: 2 sitios corregidos
(`promotions-page.component.ts`, `promotion.service.ts`). Cero migraciones, cero endpoints
nuevos, cero dependencias nuevas.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principio I (nace de un spec)**: ✅ `specs/127-fix-zona-horaria-promociones/spec.md`
  existe, pasó el checklist de calidad (16/16) y una sesión de `/speckit-clarify` (acotó el
  alcance a US1+US2, excluyó explícitamente un tercer hallazgo no relacionado con zona
  horaria).
- **Principio II (comportamiento existente protegido / decisión de negocio registrada)**:
  ✅ N/A para decisión de negocio — esta spec no cambia ninguna regla de negocio ya
  decidida; corrige la implementación de una regla **ya vigente** (spec 030: "la vigencia se
  evalúa en hora local del tenant") que el motor de promociones nunca llegó a cumplir del
  todo (nunca recibía el tenant). No hace falta ninguna entrada nueva en
  `registro-de-anomalias.md`: no hay ningún comportamiento *intencional* que se esté
  retirando, solo un defecto de implementación que se corrige para cumplir una decisión ya
  tomada en spec 030.
- **Principio III (characterization tests)**: ✅ identificados y protegidos explícitamente
  (research.md, Decisión 4): `app/scripts/test_promotions_rules.py` (script de CI, cruce de
  medianoche/A-57) y los tests pytest de `test_promotions_rules_admin.py`/
  `test_promotions_service.py` que ejercitan el mismo motor — ninguno cambia de cuerpo, solo
  deben seguir pasando sin modificación.
- **Principio IV (los specs pueden introducir comportamiento nuevo)**: N/A — esta spec no
  introduce comportamiento de negocio nuevo; corrige un defecto de implementación frente a
  una regla ya especificada (spec 030, FR-002: "la vigencia se evalúa en hora local real del
  tenant").
- **Principio V/VI (sin refactor oportunista, cambio incremental)**: ✅ el alcance se limita
  exactamente a enhebrar un parámetro `tenant` ya resuelto en cada llamador real (research.md,
  Decisión 3) y a corregir el cómputo de fecha en el frontend — no se toca
  `tenant-date.pipe.ts` (duplicación preexistente de `DEFAULT_TIMEZONE`, fuera de alcance,
  research.md Decisión 1) ni ninguna otra área no relacionada.
- **Principio VII (datos históricos)**: ✅ sin riesgo — esta corrección solo cambia cómo se
  evalúa la vigencia *hacia adelante*; no recalcula ninguna venta, factura ni promoción ya
  aplicada en el pasado.
- **Principio VIII (evolución del modelo de datos)**: ✅ N/A — ningún campo, columna ni
  migración nueva; `Tenant.timezone` ya existe (spec 030).
- **Principio IX (dependencias nuevas)**: ✅ ninguna — se reutilizan `resolve_timezone()` y
  `businessToday()`, ya existentes y ya usados en otros módulos del mismo proyecto.
- **Principio X (verificación obligatoria)**: se cubre con las suites de characterization
  tests y el script de CI dedicado ya existentes (sin modificación), más tests nuevos que
  distingan explícitamente "zona horaria del tenant" de "zona horaria global" — único caso
  hoy invisible porque ambas coinciden por casualidad para los tenants existentes.
- **Principio XI (decisiones de negocio vs técnicas)**: ✅ puramente técnica — ninguna regla
  de negocio cambia (una promoción sigue significando exactamente lo mismo); solo se corrige
  la fidelidad con la que el sistema la evalúa.
- **Principio XII (trazabilidad)**: ✅ cadena completa: Necesidad (incidente en producción,
  `spec.md` Input) → Spec 127 → Investigación (research.md, dos causas raíz citadas con
  file:line) → Plan (este documento) → Implementación → Tests → Verificación.
- **Principio XIV (rama Git)**: se crea `fix/127-promotions-tenant-timezone` en **ambos**
  repositorios (único caso de esta spec con cambios reales en los dos: frontend para FR-001,
  backend para FR-002/FR-003), partiendo de `develop` en cada uno.
- **Principio XV (commits)**: solo bajo pedido explícito del usuario, en unidades lógicas
  separadas por repo/capa (p. ej. "fix frontend starts_at" aparte de "fix backend tenant
  timezone threading"), en inglés, sin marcas de autoría de IA.

**Resultado**: PASA. Sin violaciones que requieran justificación en Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/127-fix-zona-horaria-promociones/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output — causas raíz exactas (file:line) y decisión de enfoque
├── data-model.md         # Phase 1 output — Promoción/Tenant, sin campos nuevos
├── quickstart.md         # Phase 1 output — 5 escenarios de validación manual + verificación automatizada
└── checklists/
    └── requirements.md  # Spec quality checklist (/speckit-specify command)
```

No se genera `contracts/`: esta spec no introduce ni modifica ningún endpoint de API, su
forma de entrada/salida, ni ningún contrato externo — los mismos seis endpoints/funciones ya
existentes pasan a evaluar vigencia con la zona horaria correcta, sin cambiar su firma
pública HTTP.

### Source Code (repository root)

```text
pos-backend/
└── app/
    ├── api/v1/promotions/service.py   # _tz/local_now/_valid_now/active_variant_set_rules/
    │                                   # evaluate_variant_sets — se les agrega `tenant`
    │                                   # opcional (research.md, Decisión 2)
    ├── api/v1/menu/router.py          # public_menu, public_menu_promotions,
    │                                   # menu_by_signed_qr, _build_menu,
    │                                   # _build_menu_promotions — pasan el tenant ya
    │                                   # resuelto (Depends(get_tenant) / ctx.tenant)
    ├── api/v1/cart/service.py         # serialize_cart, submit_cart — reciben `tenant`
    │                                   # desde SessionContext (ctx.tenant, ya existente)
    ├── api/v1/orders/checkout.py      # auto_discount, refresh_order_item_discounts,
    │                                   # compute_checkout_preview, compute_draft_preview,
    │                                   # pay_order, checkout_and_send — reciben `tenant`
    │                                   # desde sus routers (ya inyectado, orders/router.py)
    └── characterization_tests/
        ├── test_promotions_service.py        # se confirma en verde, sin modificar
        └── test_promotions_rules_admin.py    # se confirma en verde, sin modificar
    └── scripts/
        └── test_promotions_rules.py          # script de CI dedicado a A-57/medianoche —
                                                # se confirma en verde, sin modificar

pos-heladeria/
└── src/app/
    ├── modules/promotions/
    │   ├── pages/promotions-page.component.ts     # continueToConfigure(): starts_at con
    │   │                                            # businessToday(tz) en vez de
    │   │                                            # new Date().toISOString()
    │   └── services/promotion.service.ts           # constructor del payload: mismo cambio
    └── shared/date-format.util.ts                   # businessToday() — se lee, no se toca
```

**Structure Decision**: corrección dividida en dos capas independientes, una por repositorio
(frontend para FR-001, backend para FR-002/FR-003), cada una con su propia rama
`fix/127-promotions-tenant-timezone` (Principio XIV) y, si se piden commits, su propia unidad
lógica (Principio XV). Ningún archivo de `pos-backend` fuera de `promotions/`, `menu/`,
`cart/` y `orders/checkout.py` se modifica; ningún archivo de `pos-heladeria` fuera de
`modules/promotions/` se modifica.

## Complexity Tracking

*No aplica — el Constitution Check no reporta violaciones.*
