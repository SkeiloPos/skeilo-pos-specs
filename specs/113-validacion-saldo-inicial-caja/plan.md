# Implementation Plan: Validación de saldo inicial mayor a cero al abrir caja

**Branch**: `113-validacion-saldo-inicial-caja` | **Date**: 2026-10-12 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/113-validacion-saldo-inicial-caja/spec.md`

## Summary

Hoy el sistema permite **explícitamente** abrir un turno de caja con saldo inicial
(`opening_amount`) en `0`, en tres capas: el schema `ShiftOpen` del backend
(`Field(0, ge=0, ...)`), el `CheckConstraint("opening_amount >= 0", ...)` de la tabla
`cash_shifts`, y el formulario de apertura de `pos-heladeria`, que no valida ese campo más allá de
exigir una caja seleccionada. Esta spec endurece la regla a `opening_amount > 0`, estrictamente
mayor a cero, en las mismas tres capas: el formulario muestra un mensaje bajo el campo y
deshabilita "Abrir caja y comenzar turno" desde la carga de la pantalla (sin esperar interacción,
por Clarification de la sesión 2026-10-12) mientras el saldo sea `0` o esté vacío; el endpoint
`POST /cash/shifts/open` responde `422` con un mensaje explícito en español (mismo patrón que
`close_shift()` ya usa para "la observación es obligatoria") en vez del envelope genérico de
validación, porque la restricción de negocio se mueve del `Field` de Pydantic a un chequeo
explícito en el router (ver research.md D1); y el `CheckConstraint` de base de datos se endurece a
`> 0`, agregado con `NOT VALID` en PostgreSQL para no afectar ningún turno histórico (Principio
VII). El cambio de comportamiento ya quedó registrado como decisión de negocio
—[A-125](../000-reconocimiento/registro-de-anomalias.md)— confirmada por el dueño del producto
durante esta misma sesión de planificación, conforme exige el Principio II de la constitución y la
propia spec (FR-008).

## Technical Context

**Language/Version**: Python 3.14 (`pos-backend`, vía `./env/bin/python`) + TypeScript 5.x /
Angular (standalone components, signals) en `pos-heladeria`.

**Primary Dependencies**: FastAPI + Pydantic v2 + SQLAlchemy 2.0 + Alembic (`pos-backend`, módulo
`app/api/v1/cash/`); Angular Forms (`ngModel`) + `MoneyInputComponent` ya existente
(`pos-heladeria`, `shared/money-input/`) — ninguna dependencia nueva (Principio IX): todo el
cambio reutiliza mecanismos ya presentes en ambos repos (el patrón de `HTTPException` explícito de
`close_shift()`, el `computed` de deshabilitado de `arqueoDisabled`/`movimientoDisabled`, el patrón
`[invalid]` + párrafo condicional de `change-password.component.ts`).

**Storage**: PostgreSQL 16, un esquema por tenant. Se endurece un `CheckConstraint` ya existente en
`tenant.cash_shifts` (`ck_cash_shift_opening_positive`, de `>= 0` a `> 0`); sin columnas, tablas ni
índices nuevos (ver [data-model.md](./data-model.md)).

**Testing**: `pos-backend` —
`cd ../pos-backend && ./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`
más un script nuevo en `app/scripts/` (mismo patrón que `test_cash_net_sales.py`, spec 108) para los
casos de `opening_amount <= 0`/`> 0` contra el endpoint y el `CheckConstraint`. `pos-heladeria` —
`npx ng test --watch=false --include='src/app/modules/cash-register/**/*.spec.ts'` (Vitest); la
suite completa del frontend tiene fallos preexistentes conocidos, siempre en los mismos archivos
y no relacionados con `cash-register` — comparar por archivo, no por conteo total, antes de
atribuir cualquier falla nueva a este cambio.

**Target Platform**: aplicación web de terminal POS (navegador de escritorio) sobre backend Linux,
corrido nativo con `uvicorn` (no en Docker — ver nota de entorno del proyecto: el `.env` apunta a
hosts `localhost`).

**Project Type**: aplicación web existente con frontend (`pos-heladeria`) y backend (`pos-backend`)
en repos independientes, ambos en producción.

**Performance Goals**: sin metas nuevas — un chequeo aritmético adicional (`<= 0`) antes de un
`INSERT` que ya ocurría; sin impacto medible.

**Constraints**: no debe alterar ningún turno de caja histórico, abierto o cerrado, incluidos los
que tengan `opening_amount = 0` (Principio VII, FR-007) — la migración usa `NOT VALID`
precisamente para eso (ver [data-model.md](./data-model.md)); el mensaje de error del backend debe
seguir el patrón de mensajes explícitos ya usado en el módulo de caja, no el envelope genérico de
validación (Assumptions de spec.md, FR-005); sin dependencias nuevas (Principio IX).

**Scale/Scope**: cambio acotado a 1 schema + 1 router + 1 modelo + 1 migración + 3 fixtures de test
en `pos-backend`, y 1 store + 1 componente en `pos-heladeria`; no afecta volumen de datos ni
concurrencia de forma material.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Evaluación |
|---|---|
| I. Nace de un spec | PASS — `specs/113-validacion-saldo-inicial-caja/spec.md` |
| II. Comportamiento existente protegido | PASS — la propia spec documenta en "Contexto y comportamiento actual" que `opening_amount >= 0` es hoy intencional en las tres capas, y exige (FR-008) registrar el cambio como decisión de negocio antes de implementar. **Ya registrada** como [A-125](../000-reconocimiento/registro-de-anomalias.md), confirmada explícitamente por el dueño del producto durante esta sesión de `/speckit-plan`, antes de continuar con el diseño — mismo precedente que [A-124](../000-reconocimiento/registro-de-anomalias.md) (spec 112) |
| III. Characterization tests | PASS — se verificó (`grep` sobre `app/characterization_tests/`) que ningún test `CONGELA comportamiento actual:` protege que `opening_amount = 0` sea aceptado. `test_cash_timezone.py` usa `0` solo como relleno vía `ShiftResponse.model_construct()` (no pasa por `ShiftOpen` ni por la base de datos) y no se ve afectado. Las tres copias de `make_cash_shift()` (`cart_fixtures.py`, `orders_fixtures.py`, `table_sessions_fixtures.py`) cambian su valor por defecto de `0` a uno positivo — es un ajuste de infraestructura de pruebas, no la modificación de un comportamiento protegido (ningún test hace una aserción sobre ese valor específico; ver research.md D4) |
| IV. Nuevos specs introducen comportamiento nuevo | PASS — exactamente este caso: la spec define el nuevo límite y su razón de negocio |
| V. Sin refactors oportunistas | PASS — se toca solo la validación de `opening_amount` en sus tres capas; no se reorganiza `router.py`, `service.py` ni el resto de `cash-session.store.ts` más allá del `computed` nuevo |
| VI. Evolución incremental | PASS — una sola clase de cambio (acotar un valor ya existente en frontend + backend + base de datos), sin mezclar con arquitectura, modelo de datos nuevo ni otra funcionalidad; no requiere Complexity Tracking |
| VII. Datos históricos | PASS — ningún turno ya creado se recalcula, se reescribe ni se bloquea; la migración usa `NOT VALID` exactamente para garantizarlo (ver data-model.md) |
| VIII. Evolución del modelo de datos | PASS — documentado en [data-model.md](./data-model.md): sin columnas nuevas, solo un `CheckConstraint` endurecido, con estrategia de migración (`NOT VALID`, por-esquema) y de rollback (`DROP`/`ADD` de vuelta a `>= 0`) |
| IX. Dependencias nuevas | PASS — cero |
| X. Verificación obligatoria | PASS, ver [quickstart.md](./quickstart.md) — tests nuevos en `pos-backend` (endpoint + `CheckConstraint`) y en `pos-heladeria` (store + componente), más los characterization tests existentes sin regresión (fixtures ajustadas, D4) |
| XI. Negocio vs técnico | PASS — la decisión de negocio (exigir `> 0`, sin monto mínimo adicional) está en la spec y en A-125; este plan solo decide el *cómo* (dónde vive cada validación, cómo migrar el `CheckConstraint` sin tocar históricos) |
| XII. Trazabilidad | PASS — Necesidad (arqueos de cierre inválidos por saldo inicial no declarado) → spec 113 → decisión de negocio A-125 → este plan → `tasks.md` → implementación → tests nuevos + characterization tests sin regresión |
| XIII. Español de Colombia | Aplicado en este documento y en el resto de artefactos de esta fase |
| XIV. Rama Git | Pendiente de implementación: crear `fix/113-validacion-saldo-inicial-caja` (o nombre equivalente en inglés) en `pos-backend` y en `pos-heladeria` antes de tocar su código — ambos repos trabajan sobre `develop`, no `main` |
| XV. Commits | Pendiente de implementación: solo bajo pedido explícito del usuario, en inglés, sin marca de autoría de IA, en unidades pequeñas (p. ej. un commit para el schema+router del backend, otro para la migración, otro para los fixtures de test, otro para el store+componente del frontend) |

**Re-chequeo post-diseño (Fase 1)**: sin cambios — `data-model.md` y `contracts/` confirman que no
se introduce ninguna columna, tabla, endpoint ni dependencia nueva respecto a lo evaluado arriba;
el único artefacto de datos modificado es el `CheckConstraint` ya existente, con su migración y
rollback documentados (Principio VIII). El Constitution Check sigue en verde sin excepciones que
requieran la tabla de Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/113-validacion-saldo-inicial-caja/
├── plan.md               # Este archivo
├── research.md           # Fase 0 — decisiones D1-D5
├── data-model.md         # Fase 1 — CashShift.opening_amount, CheckConstraint, fixtures
├── quickstart.md         # Fase 1 — guía de validación manual + automatizada
├── contracts/
│   ├── post-shifts-open.md     # Contrato del endpoint POST /cash/shifts/open
│   └── cash-open-form.md       # Contrato del formulario "Abrir caja" (frontend)
└── tasks.md               # Fase 2 (/speckit-tasks) — no se crea en este comando
```

### Source Code (sibling repositories, fuera de `pos-specs`)

```text
../pos-backend/
├── app/api/v1/cash/
│   ├── schemas.py          # ShiftOpen.opening_amount (línea 32): se retira `ge=0` del Field
│   └── router.py           # open_shift() (línea 68-85): agrega el chequeo explícito
│                            #   `if body.opening_amount <= 0: raise HTTPException(422, "...")`
│                            #   antes de construir el CashShift (mismo patrón que close_shift()
│                            #   usa para "la observación es obligatoria", líneas 111-117)
├── app/models/
│   └── cash_shift.py        # CheckConstraint (línea 44): "opening_amount >= 0" → "> 0"
├── app/characterization_tests/
│   ├── cart_fixtures.py            # make_cash_shift() (línea 406): default 0 → positivo
│   ├── orders_fixtures.py          # make_cash_shift() (línea 421): default 0 → positivo
│   └── table_sessions_fixtures.py  # make_cash_shift() (línea 366): default 0 → positivo
├── app/scripts/
│   └── test_cash_opening_amount.py # script nuevo, mismo patrón que test_cash_net_sales.py
│                                    #   (spec 108) — casos de contracts/post-shifts-open.md
└── alembic/versions/
    └── <rev>_113_cash_shift_opening_amount_positive.py  # migración por-esquema (NOT VALID),
                                                            #   ver data-model.md

../pos-heladeria/
└── src/app/modules/cash-register/
    ├── services/
    │   ├── cash-session.store.ts         # agrega el computed `aperturaDisabled`
    │   └── cash-session.store.spec.ts    # se extiende con los casos nuevos
    └── components/
        └── cash-open.component.ts        # usa `store.aperturaDisabled()` en el botón,
                                            #   agrega [invalid] al money-input y el párrafo
                                            #   condicional del mensaje (sin componente nuevo:
                                            #   no existe cash-open.component.spec.ts hoy — se
                                            #   crea como parte de esta implementación)
```

**Structure Decision**: aplicación web ya existente con frontend (`pos-heladeria`) y backend
(`pos-backend`) en repos independientes, ambos en producción (Alcance del Proyecto,
Constitución). Esta spec no introduce módulos ni proyectos nuevos: modifica archivos ya existentes
en las rutas listadas arriba, añadiendo únicamente una migración Alembic en el backend y un
archivo de test nuevo (`cash-open.component.spec.ts`, inexistente hasta ahora) en el frontend.

## Complexity Tracking

*No aplica — el Constitution Check no registró violaciones que requieran justificación.*
