# Implementation Plan: Instrucciones de Pago del Menú QR por Modalidad del Plan

**Branch**: `154-instrucciones-pago-menu-qr` | **Date**: 2026-11-06 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/154-instrucciones-pago-menu-qr/spec.md`

## Summary

El Super Admin debe poder definir, por plan, si los comensales del menú QR de un tenant ven la
instrucción de pago "después de recibir" (comportamiento actual) o "antes de recibir" (acercarse
a caja), y esa modalidad debe reflejarse únicamente en la pantalla de confirmación del menú QR,
sin que ningún rol de administración del tenant pueda verla ni cambiarla, sin tocar POS, caja,
cocina ni terminal de mesas (research.md, data-model.md).

El enfoque técnico (research.md, Decisiones 2-6): se agrega `Plan.modalidad_pago_qr`
(`String(30)` + `CheckConstraint`, no un booleano ni un `ENUM` nativo — mismo estilo que
`PaymentMethodCatalog.type`), administrable solo desde los endpoints de Super Admin ya
existentes (`plans_router.py`), **sin** exponerla en `GET /plan` (`PlanSummaryResponse`) —
exponerla ahí violaría literalmente FR-004 ("ningún rol de administración del tenant puede
consultarla"), a diferencia del patrón de `inventario_access`/`promociones_access`/
`cocina_access` que spec 149 sí expuso ahí. El valor llega al comensal anónimo ya computado,
como un campo nuevo `qr_payment_instruction_mode` en `OrderResponse`, poblado únicamente por
`cart/router.py` (`POST /cart/submit`, `GET /cart/orders`) con el mismo patrón que ya usan
`paid`/`pending_balance` (atributo transitorio asignado antes de serializar) — nunca persistido,
siempre recalculado desde el plan vigente del tenant (FR-014). El frontend reemplaza los tres
literales hardcodeados de `confirmation-step.component.ts` por una función pura nueva en
`order-status.util.ts` que resuelve las seis combinaciones (modalidad × método de pago) de
FR-007/FR-008.

## Technical Context

**Language/Version**: Backend — Python 3.14 (venv `pos-backend/env`). Frontend — TypeScript
5.9.2 (Angular 21.1.x, standalone components + signals).

**Primary Dependencies**: Ninguna dependencia nueva en ningún repositorio. Backend reutiliza
`app.api.v1.plan.service` (se le agrega `get_qr_payment_instruction_mode`, junto a
`build_plan_summary` que ya existe ahí) y el patrón de atributo transitorio ya usado por
`orders/router.py` (`order.paid = ...`, `order.pending_balance = ...`) para
`qr_payment_instruction_mode`. Frontend reutiliza `order-status.util.ts` (ya alberga
`orderStatusLabel`/`orderStatusClass`, mismo patrón de función pura consumida por
`confirmation-step.component.ts`).

**Storage**: PostgreSQL 16, schema-per-tenant. Una columna nueva:
`shared.plans.modalidad_pago_qr` (`String(30) NOT NULL`, `CheckConstraint` de dos valores,
`server_default='PAY_AFTER_RECEIVING'`). Sin tabla nueva, sin backfill (data-model.md, Migración
de datos) — a diferencia de spec 141, esta columna no fusiona ni migra ningún dato existente.

**Testing**: Backend — `unittest` vía `python -m unittest discover -s app/characterization_tests
-p 'test_*.py'` (local Postgres disponible pero no necesario, `fixtures.py` usa SQLite en
memoria — memory del proyecto). Se extiende `test_super_admin_plans.py`/`test_plan_summary.py` y
el fichero que cubre `POST /cart/submit`/`GET /cart/orders` (nombre exacto a confirmar antes de
implementar — ver quickstart.md). Frontend — `ng test` (Karma/Jasmine), spec nuevo
`confirmation-step.component.spec.ts` (no existía antes de esta spec) + extensión de
`order-status.util.spec.ts`; baseline de la suite completa conocida como flaky/no determinista,
se compara por archivo afectado (memory del proyecto).

**Target Platform**: Linux server (API `pos-backend`) + navegador móvil (menú QR público,
`pos-heladeria`, sin autenticación de staff) + panel de Super Admin (mismo frontend, autenticado).

**Project Type**: Web application (backend FastAPI + frontend Angular, repos sibling de
`pos-specs`).

**Performance Goals**: Ninguno nuevo — un `db.get(Plan, tenant.plan_id)` más por request de
`POST /cart/submit`/`GET /cart/orders`, mismo costo que el que ya hace `build_plan_summary` para
`GET /plan`; sin `JOIN` ni consulta en bucle.

**Constraints**:
- FR-004 es una restricción de **diseño de API**, no solo de UI: `modalidad_pago_qr` no puede
  viajar en ninguna respuesta que un rol de administración del tenant pueda invocar
  (`GET /plan` y cualquier endpoint derivado) — research.md Decisión 3.
- FR-013: el campo nuevo de `OrderResponse` debe quedar en `null` en toda respuesta que no pase
  por `cart/router.py` — ningún router de POS/caja/cocina/terminal de mesas lo asigna
  (data-model.md).
- FR-014: el valor nunca se persiste en la orden; se recalcula en cada respuesta desde el plan
  vigente del tenant (research.md Decisión 4) — ninguna migración de datos sobre
  `CustomerOrder`.
- Esta spec se limita a la pantalla de confirmación del menú QR
  (`confirmation-step.component.ts`); los copys parecidos de `public-menu.component.ts` (paso de
  selección de método de pago, antes de enviar el pedido) quedan fuera de alcance — no los
  menciona el spec y tocarlos sería una refactorización no solicitada (Principio V/VI,
  research.md Decisión 1).

**Scale/Scope**: 1 columna nueva (`shared.plans.modalidad_pago_qr`), 1 migración Alembic, 3
schemas Pydantic modificados (`PlanCreate`/`PlanUpdate`/`PlanResponse`, Super Admin), 1 función
nueva en `plan/service.py`, 1 campo nuevo en `orders/schemas.py` (`OrderResponse`), 2 líneas
nuevas en `cart/router.py` (asignación del atributo en `submit_cart`/`my_orders`), 1 control de
formulario nuevo en `plan-form.component.ts` (radio/select, no checkbox), 1 interfaz TypeScript
modificada (`DiningOrder`), 1 función pura nueva en `order-status.util.ts`, 1 componente
modificado (`confirmation-step.component.ts`, reemplaza 3 literales por 1 llamada). Cero
endpoints nuevos, cero tablas nuevas, cero cambios en `GET /plan`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Evaluación | Estado |
|---|---|---|
| **I. Las Nuevas Funcionalidades Nacen de un Spec** | `spec.md` existe, aprobado, con 3 historias (2×P1, 1×P2) y 14 FRs, clarificado en sesión 2026-11-06. Este plan implementa el alcance completo del spec, sin reducirlo (a diferencia de spec 149). | PASS |
| **II. El Comportamiento Existente Sigue Protegido** | El default `PAY_AFTER_RECEIVING` reproduce exactamente el comportamiento actual para todo plan existente (Assumptions del spec) — ningún tenant ve un mensaje distinto hasta que el Super Admin cambie explícitamente un plan. No requiere entrada en `registro-de-anomalias.md` (research.md Decisión 8), mismo criterio que spec 149 aplicó a `cocina_access`. | PASS |
| **III. Los Characterization Tests Protegen el Comportamiento Heredado** | Ningún test `"CONGELA comportamiento actual:"` asume que `Plan` carece de `modalidad_pago_qr` ni que `OrderResponse` carece de `qr_payment_instruction_mode` (confirmado por inspección en research.md) — ninguno se modifica, solo se extiende. | PASS |
| **IV. Los Nuevos Specs Pueden Introducir Nuevo Comportamiento** | El comportamiento nuevo (modalidad por plan, mensaje nuevo para PAY_BEFORE_RECEIVING) está definido íntegramente en `spec.md` (FR-007/FR-008); el criterio de éxito es conformidad con ese contrato, no equivalencia con el pasado. | PASS |
| **V. Nuevas Funcionalidades Antes que Refactorizaciones Oportunistas** | Los copys parecidos de `public-menu.component.ts` quedan explícitamente fuera de alcance (research.md Decisión 1) — no se tocan junto con esta funcionalidad. | PASS |
| **VI. Evolución Incremental** | Una sola unidad verificable: columna de plan + cómputo en `OrderResponse` + frontend de confirmación. No mezcla con ningún cambio de arquitectura, migración de datos de órdenes existentes, ni refactor de `public-menu.component.ts`. | PASS |
| **VII. Compatibilidad con Datos Históricos** | Ninguna `Sale`/`Payment`/`Invoice` se toca; `CustomerOrder` no gana columna ni se recalcula — el campo nuevo es puramente de respuesta, nunca persistido (data-model.md). | PASS |
| **VIII. Evolución del Modelo de Datos** | Ver data-model.md: una columna nueva (`modalidad_pago_qr`, `String(30) NOT NULL` + `CheckConstraint`, default `'PAY_AFTER_RECEIVING'`), sin backfill necesario, con estrategia de rollback explícita (`drop_constraint` antes de `drop_column`, research.md Decisión 7, citando el gotcha de nombrado ya registrado en memory del proyecto). | PASS |
| **IX. Dependencias Nuevas Permitidas con Justificación** | No aplica — cero dependencias nuevas. | N/A |
| **X. Verificación Obligatoria** | quickstart.md traduce las 3 historias completas (US1 Super Admin, US2 comensal × 6 combinaciones, US3 propagación inmediata) a pasos ejecutables en ambos repos, incluida la verificación de migración en ambas direcciones. | PASS |
| **XI. Decisiones de Negocio Frente a Decisiones Técnicas** | Dos decisiones técnicas quedaron explícitas y correctamente distinguidas de decisiones de negocio ya tomadas en el spec: (a) forma de la columna (`String`+`CheckConstraint`, no booleano ni `ENUM`) — decisión técnica, justificada en research.md Decisión 2 sin alterar ningún FR; (b) no exponer el campo en `GET /plan` — decisión técnica derivada directamente de la palabra "consulte" en FR-004 (decisión de negocio ya escrita en el spec), no una decisión de negocio nueva de este plan. | PASS |
| **XII. Trazabilidad** | Cadena completa: `spec.md` (Necesidad+Spec, clarificado 2026-11-06) → este `plan.md`/`research.md` (Decisión técnica) → `data-model.md`/`contracts/` (Fase 1) → `tasks.md` (Fase 2, no generada por este comando) → implementación → tests nuevos → `quickstart.md` (Verificación). | PASS |
| **XIII. Todo en Español de Colombia** | Este plan y todos sus artefactos (research.md, data-model.md, contracts/, quickstart.md) se escriben en español de Colombia, igual que `spec.md`. | PASS |

Sin violaciones que requieran Complexity Tracking.

**Re-chequeo post-diseño (Fase 1)**: `research.md`, `data-model.md` y `contracts/` no
introdujeron ninguna entidad, dependencia ni decisión que contradiga la tabla anterior. La
decisión de no exponer `modalidad_pago_qr` en `GET /plan` (Decisión 3) queda documentada en
`contracts/plan-qr-payment-instruction.md` como una sección explícita ("sin cambios"), por
trazabilidad frente a quien compare este contrato con el de spec 149. Gates siguen en PASS.

## Project Structure

### Documentation (this feature)

```text
specs/154-instrucciones-pago-menu-qr/
├── plan.md              # Este fichero (/speckit-plan)
├── research.md          # Fase 0 (/speckit-plan) — decisiones técnicas
├── data-model.md         # Fase 1 (/speckit-plan) — columna nueva + campo computado
├── quickstart.md         # Fase 1 (/speckit-plan) — validación ejecutable de las 3 historias
├── contracts/            # Fase 1 (/speckit-plan)
│   └── plan-qr-payment-instruction.md
└── tasks.md              # Fase 2 (/speckit-tasks — NO se crea en este comando)
```

### Source Code (repositorios sibling de `pos-specs`)

Esta spec vive en `pos-specs`, pero el código que describe está en `../pos-backend` y
`../pos-heladeria` (Constitución §Alcance). Rutas relativas a la raíz de cada repo.

```text
# pos-backend
app/
├── models/
│   └── plan.py                        # MODIFICADO — Plan gana modalidad_pago_qr
│                                         (String(30), NOT NULL, CheckConstraint de dos
│                                         valores, default/server_default
│                                         'PAY_AFTER_RECEIVING'), junto a las columnas
│                                         existentes (líneas ~41-43 actuales)
├── api/v1/
│   ├── super_admin/
│   │   └── schemas.py                 # MODIFICADO — PlanCreate.modalidad_pago_qr:
│   │                                     Literal[...] = "PAY_AFTER_RECEIVING",
│   │                                     PlanUpdate.modalidad_pago_qr: Optional[Literal[...]]
│   │                                     = None, PlanResponse.modalidad_pago_qr: Literal[...]
│   │                                     (mismas líneas que inventario_access/
│   │                                     promociones_access/cocina_access, ~143/165/186)
│   ├── plan/
│   │   └── service.py                 # MODIFICADO — nueva función
│   │                                     get_qr_payment_instruction_mode(db, tenant) -> str,
│   │                                     junto a build_plan_summary; ModuleAccess/
│   │                                     PlanSummaryResponse (plan/schemas.py) NO se tocan
│   │                                     (research.md Decisión 3)
│   ├── orders/
│   │   └── schemas.py                 # MODIFICADO — OrderResponse gana
│   │                                     qr_payment_instruction_mode:
│   │                                     Literal["PAY_AFTER_RECEIVING",
│   │                                     "PAY_BEFORE_RECEIVING"] | None = None, junto a
│   │                                     paid/pending_balance (líneas ~327-338 actuales)
│   └── cart/
│       └── router.py                  # MODIFICADO — submit_cart y my_orders asignan
│                                         order.qr_payment_instruction_mode =
│                                         plan_service.get_qr_payment_instruction_mode(
│                                         ctx.db, ctx.tenant) sobre cada CustomerOrder antes
│                                         de serializar (mismo patrón que orders/router.py:
│                                         73-77 para paid/pending_balance)
├── characterization_tests/
│   ├── test_super_admin_plans.py      # MODIFICADO — casos nuevos para modalidad_pago_qr
│   │                                     (crear con/sin el campo, 422 por valor fuera de
│   │                                     catálogo, editar/reemplazar)
│   ├── test_plan_summary.py           # MODIFICADO — caso nuevo: GET /plan NO contiene
│   │                                     modalidad_pago_qr ni clave equivalente
│   └── {fichero que cubra POST /cart/submit / GET /cart/orders}
│                                       # MODIFICADO (nombre exacto a confirmar antes de
│                                         implementar) — qr_payment_instruction_mode refleja
│                                         el plan vigente del tenant, en null para endpoints de
│                                         staff
└── alembic/versions/
    └── {rev}_154_plans_add_modalidad_pago_qr.py  # NUEVO — agrega
                                                       shared.plans.modalidad_pago_qr +
                                                       CheckConstraint
                                                       ck_plans_modalidad_pago_qr, encadenada
                                                       sobre el head actual (019b97e8a107);
                                                       downgrade() hace drop_constraint antes
                                                       de drop_column (research.md Decisión 7)

# pos-heladeria
src/app/modules/
├── super-admin/
│   ├── interfaces/
│   │   └── plan.interface.ts          # MODIFICADO — Plan.modalidad_pago_qr:
│   │                                     'PAY_AFTER_RECEIVING' | 'PAY_BEFORE_RECEIVING',
│   │                                     PlanCreatePayload.modalidad_pago_qr?: ...
│   └── components/
│       └── plan-form.component.ts     # MODIFICADO — control nuevo tipo radio/select de
│                                         dos opciones ("Pago después de recibir"/"Pago antes
│                                         de recibir") para modalidad_pago_qr, independiente
│                                         de los checkboxes de módulo existentes (research.md
│                                         Decisión 6)
└── tables/
    ├── interfaces/
    │   └── dining.interface.ts        # MODIFICADO — DiningOrder.qr_payment_instruction_mode?:
    │                                     'PAY_AFTER_RECEIVING' | 'PAY_BEFORE_RECEIVING' | null
    ├── order-status.util.ts           # MODIFICADO — función pura nueva
    │                                     qrPaymentInstructionMessage(mode, attempt) que
    │                                     resuelve las 6 combinaciones de FR-007/FR-008, junto
    │                                     a orderStatusLabel/orderStatusClass
    ├── order-status.util.spec.ts      # MODIFICADO — casos nuevos para las 6 combinaciones +
    │                                     el caso mode=null/método fuera de catálogo
    └── pages/checkout/
        ├── confirmation-step.component.ts       # MODIFICADO — los 3 literales de las
        │                                           líneas 82-83/117/126 se reemplazan por 1
        │                                           llamada a qrPaymentInstructionMessage
        │                                           (research.md Decisión 5)
        └── confirmation-step.component.spec.ts  # NUEVO — no existía spec dedicado para este
                                                     componente; cubre las 6 combinaciones +
                                                     el caso sin instrucción
```

**Structure Decision**: cada archivo tocado extiende un patrón ya existente en este codebase —
`modalidad_pago_qr` sigue el estilo `String`+`CheckConstraint` de `PaymentMethodCatalog.type`
(no el patrón `*_access` booleano de spec 149, porque no es un *gate* de módulo); el cómputo en
`OrderResponse` sigue el patrón de atributo transitorio ya usado por `paid`/`pending_balance`.
Ningún directorio, router ni componente nuevo se crea en ningún repositorio, salvo el spec de
test nuevo para `confirmation-step.component.ts` (que no tenía uno).

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

Sin violaciones — tabla vacía.
