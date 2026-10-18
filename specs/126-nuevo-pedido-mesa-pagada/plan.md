# Implementation Plan: Nuevo Pedido en Mesa con Cuenta Pagada

**Branch**: `126-nuevo-pedido-mesa-pagada` | **Date**: 2026-10-17 (replanificado tras segunda
sesión de `/speckit-clarify`) | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/126-nuevo-pedido-mesa-pagada/spec.md`

**Nota sobre el plan anterior**: este documento **reemplaza por completo** el `plan.md` generado
antes de la segunda sesión de `/speckit-clarify`, que planificaba la implementación de A-137 (el
bloqueo de "+ Crear pedido nuevo" con saldo pendiente). A-137 fue revertida por A-138 el mismo
día, antes de que ninguna tarea de ese plan llegara a ejecutarse (`pos-heladeria` y `pos-backend`
siguen limpios en `develop`, sin ningún cambio). Este plan parte de la versión actual de
`spec.md`, posterior a A-138.

## Summary

Tras la reversión de A-137, **todas** las reglas de negocio que describe `spec.md` (FR-001 a
FR-011) ya están implementadas y ya se comportan como se documenta — ninguna requiere código de
producción nuevo en `pos-backend` ni en `pos-heladeria`. Esta spec queda, por completo, como
**documentación formal y verificación de regresión** de un modelo de negocio que ya existe
(multi-pedido sin bloqueo por mesa, cada cuenta independiente y cobrable por separado,
"Liberar Mesa" como único punto de control, sin consolidación de cuentas, anulación como único
procedimiento de excepción). El enfoque técnico de este plan es, por tanto, exclusivamente de
**verificación**: confirmar con tests ya existentes (y un pequeño conjunto de tests nuevos, solo
de regresión, sin tocar ningún archivo de producción) que cada FR se sostiene hoy, y dejar
trazabilidad explícita hacia A-138 para que un cambio futuro que lo contradiga tenga que pasar
por una decisión de negocio citada (Principio II/III), no por un olvido.

## Technical Context

**Language/Version**: Backend: Python 3.11 (FastAPI + SQLAlchemy) — sin cambios de código.
Frontend: TypeScript ~5.9 / Angular ^21 (standalone components, signals) — sin cambios de
producción; posibles tests nuevos en Jasmine/Karma (Vitest runner, `ng test`).

**Primary Dependencies**: Ninguna nueva (Principio IX). Se leen, sin modificarlos:
`newOrderTableId()` (`pos-terminal.store.ts:793`), `has_billable_orders`/`has_pending_balance`/
`compute_bill` (`table_sessions/service.py`), `cancel_order` (`orders/checkout.py`),
`client_request_id` (`orders/service.py:617-619`).

**Storage**: PostgreSQL 16, schema-per-tenant — sin migraciones, sin cambios de esquema.

**Testing**: Backend: `./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`
— confirmar en verde **sin modificación** (`test_table_sessions_service.py`,
`test_table_sessions_router.py`, `test_orders_checkout.py`, `test_orders_kitchen.py` ya cubren
`has_billable_orders`/`has_pending_balance`/`release_paid_session`/`cancel_order`). Frontend:
`ng test` — confirmar en verde el test ya existente
`table-sessions.component.spec.ts`: "el CTA solo se deshabilita por falta de mesa libre en la
pestaña 'mesas' (FR-007, FR-012)" (spec 078/087) y el test "bugfix: el CTA '+ Crear pedido nuevo'
de la sub-barra sigue visible con una mesa/pedido seleccionado" (línea ~427) — ambos ya protegen
FR-001. Se añaden tests nuevos, solo de regresión, donde la cobertura actual no sea 100%
explícita para una mesa con saldo pendiente (no solo "sin pedido").

**Target Platform**: Aplicación web POS (staff), Terminal de Mesas.

**Project Type**: Web application (frontend Angular + backend FastAPI ya existentes) — esta spec
es **de solo verificación**, sin cambios de producción en ninguno de los dos repositorios.

**Performance Goals**: N/A — no hay código de producción nuevo.

**Constraints**: No modificar `newOrderTableId()`, `has_billable_orders`, `has_pending_balance`,
`compute_bill`, `cancel_order` ni `client_request_id` (Principio V/VI — ya hacen exactamente lo
que FR-001 a FR-011 exigen; tocarlos sería refactor sin necesidad). No introducir ninguna acción
de "consolidar cuentas" ni de "liberación forzada" (FR-010/FR-011 — decisiones negativas
explícitas de Clarifications).

**Scale/Scope**: Cero archivos de producción tocados. Verificación sobre 2 suites de tests ya
existentes (backend y frontend) más, como mucho, 2-3 tests nuevos de regresión en
`pos-terminal.store.spec.ts`/`table-sessions.component.spec.ts` citando A-138, si la Fase 0
(research.md) encuentra algún FR sin cobertura explícita hoy.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principio I (nace de un spec)**: ✅ `specs/126-nuevo-pedido-mesa-pagada/spec.md` existe,
  pasó el checklist de calidad (16/16) y dos sesiones de `/speckit-clarify` (6 preguntas en
  total).
- **Principio II (comportamiento existente protegido / decisión de negocio registrada)**: ✅ el
  único comportamiento que esta spec tocaba (la restricción de A-137) fue revertido por
  [A-138](../000-reconocimiento/registro-de-anomalias.md#a-138--decisión-de-negocio--spec-126-se-revierte-a-137-crear-pedido-nuevo-vuelve-a-estar-disponible-con-saldo-pendiente)
  antes de implementarse — A-137 se conserva íntegra como registro histórico (nunca se reescribe
  una decisión ya registrada), y A-138 documenta explícitamente quién/cuándo/por qué. El resto de
  FR-001 a FR-011 son confirmaciones de comportamiento ya vigente, no cambios — no requieren
  ninguna entrada adicional.
- **Principio III (characterization tests)**: ✅ no se identificó ningún test
  `"CONGELA comportamiento actual:"` sobre `newOrderTableId()`/el CTA — es comportamiento
  introducido por spec 087 (reciente), con sus propios tests ya existentes (no protegidos, pero
  tampoco se tocan: A-137 nunca llegó a modificarlos, según su propia entrada de reversión).
- **Principio IV (los specs pueden introducir comportamiento nuevo)**: N/A — esta spec no
  introduce ningún comportamiento nuevo; confirma el ya existente.
- **Principio V/VI (sin refactor oportunista, cambio incremental)**: ✅ el alcance se limita a
  verificación; cero archivos de producción en el plan de tareas.
- **Principio VII (datos históricos)**: ✅ reforzado por esta spec, no en riesgo — FR-010
  (sin consolidación) existe precisamente para no abrir una vía de alterar retroactivamente
  facturas/pagos ya registrados.
- **Principio VIII (evolución del modelo de datos)**: ✅ N/A — ningún campo, columna ni
  migración.
- **Principio IX (dependencias nuevas)**: ✅ ninguna.
- **Principio X (verificación obligatoria)**: se cubre ejecutando las suites de test ya
  existentes de ambos repositorios (backend y frontend) sin modificación, más los tests de
  regresión nuevos que identifique research.md — es la combinación mínima que exige el
  principio para una spec sin funcionalidad nueva.
- **Principio XII (trazabilidad)**: ✅ la cadena completa queda documentada: Necesidad (HU
  original) → Spec → Decisión (A-137) → Decisión revertida (A-138) → Verificación (este plan) —
  sin salto de "Implementación" porque no la hay.
- **Principio XIV (rama Git)**: si research.md confirma que hacen falta tests nuevos, se crean en
  una rama `chore/126-verify-new-order-pending-balance` en `pos-heladeria` (único repo con
  cambios, y solo de test). Si research.md concluye que la cobertura actual ya es suficiente, no
  se abre ninguna rama de implementación — la spec se cierra sin tocar código.
- **Principio XV (commits)**: si se agregan tests, se commitean solo bajo pedido explícito del
  usuario, en una unidad lógica, en inglés, sin marcas de autoría de IA.

**Resultado**: PASA. Sin violaciones que requieran justificación en Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/126-nuevo-pedido-mesa-pagada/
├── plan.md              # This file (/speckit-plan command output) — reemplaza al anterior
├── research.md          # Phase 0 output — verificación de cobertura FR-001 a FR-011
├── data-model.md        # Phase 1 output — formaliza Mesa/Pedido/Estado financiero/Sesión/Cuenta
├── quickstart.md        # Phase 1 output — validación manual de que nada se rompió
└── checklists/
    └── requirements.md  # Spec quality checklist (/speckit-specify command)
```

No se genera `contracts/`: esta spec no introduce ni modifica ningún endpoint de API ni contrato
externo — confirma comportamiento de endpoints ya existentes y ya documentados por sus propias
specs (087, 123, 010, 052).

### Source Code (repository root)

```text
pos-backend/            # Sin cambios. Se leen (sin modificar) para verificación:
                         #   app/api/v1/table_sessions/service.py (has_billable_orders,
                         #     has_pending_balance, compute_bill, release_paid_session)
                         #   app/api/v1/orders/checkout.py (cancel_order, with_for_update)
                         #   app/api/v1/orders/service.py (client_request_id, dedup de creación)

pos-heladeria/
└── src/app/modules/tables/
    ├── services/
    │   └── pos-terminal.store.ts          # newOrderTableId() (línea 793) — se lee, no se toca;
    │                                       # posible test nuevo de regresión, sin cambio de código
    ├── pages/
    │   └── table-sessions.component.ts    # CTA "+ Crear pedido nuevo" — se lee, no se toca;
    │                                       # test ya existente (línea ~427, ~859) cubre FR-001
    └── components/
        └── pos-checkout-panel.component.ts # rama "Pedido de mostrador" del mismo CTA — se lee,
                                             # no se toca
```

**Structure Decision**: ningún archivo de producción se modifica en ninguno de los dos
repositorios. El único trabajo posible (a determinar en research.md) son tests de regresión
nuevos, sin tocar código de producción.

## Complexity Tracking

*No aplica — el Constitution Check no reporta violaciones.*
