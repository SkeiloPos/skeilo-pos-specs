# Implementation Plan: Desglose por denominación en el arqueo de cierre de caja

**Branch**: `121-desglose-denominaciones-cierre` (specs) · código en `feat/121-denomination-breakdown` (por repo) | **Date**: 2026-10-15 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/121-desglose-denominaciones-cierre/spec.md`

## Summary

La spec **completa y endurece** algo que ya existe a medias, no parte de cero. El código actual ya
guarda un desglose rudimentario (`cash_count_denominations`: valor y cantidad, sin tipo, con
cantidad `0`), el cierre acepta el total contado desde el navegador, y el reporte ya recibe las
denominaciones pero no las pinta. Se verificó contra el código y la BD de desarrollo
([research.md](./research.md), H1–H10); una premisa de la spec resultó inexacta (el frontend ya
filtra las líneas en cero) sin afectar el diseño.

Se entrega en **cinco bloques verificables** (Principios V y VI), cada uno en commits pequeños y
separados cuando el usuario los pida:

1. **Decisiones y rama**: registrar A-130 a A-134 (D-1 a D-6) y crear las ramas de código.
2. **Datos** (`pos-backend`): modelo `DenominationCatalog`, columna `kind`, columnas `closed_by_*`,
   una revisión de Alembic reversible con compuerta FR-028 y siembra de los tenants nuevos en
   `tenant_create()`. **Sin cambio de comportamiento** en la API.
3. **Contrato del cierre** (`pos-backend`, cambio de comportamiento D-1/D-2): el servidor calcula
   todo, rechaza totales del cliente con `422` en español, valida catálogo/duplicados/desborde,
   `SELECT … FOR UPDATE` contra cierres simultáneos, registra quién cerró; `GET /cash/denominations`
   y reporte con `kind` + `subtotal`. Se adaptan las 27 llamadas `ShiftClose()` de las pruebas y el
   script `e2e_qr_flow.py`, que cerraban «sin conteo» o con `counted_amount`.
4. **Pantalla** (`pos-heladeria`): el modal construye sus filas desde el catálogo (con error +
   «Reintentar»), total/diferencia como «estimado», observación siempre visible y envío sin
   `counted_amount`; el reporte gana «Desglose del conteo» + «Contado por» e imprime sin cortar filas.
5. **Verificación** en PostgreSQL real (concurrencia, migración ida y vuelta, tenant nuevo) y
   recorrido manual ([quickstart.md](./quickstart.md)).

## Technical Context

**Language/Version**: Backend Python 3.14 (`pos-backend/env`) · Frontend TypeScript 5.9 / Angular 21

**Primary Dependencies**: Backend FastAPI, Pydantic v2, SQLAlchemy 2.0.50, Alembic 1.18.4.
Frontend Angular 21 (señales, componentes standalone, `HttpClient`), Tailwind 4, Vitest.
**Ninguna dependencia nueva** (Principio IX; [research.md](./research.md) R10).

**Storage**: PostgreSQL 16, *schema-per-tenant*. Los tenants nuevos nacen de `create_all`; los
existentes por Alembic con `@for_each_tenant_schema`. Una tabla nueva (`denomination_catalog`),
una columna nueva en `cash_count_denominations` (`kind`) y dos en `cash_shifts` (`closed_by_*`)
— [data-model.md](./data-model.md).

**Testing**: Backend `unittest` sobre SQLite en memoria (`app/characterization_tests/`, invocando
el router como función, patrón de `test_cash_close_active_orders.py`), más verificación contra
PostgreSQL real para lo que SQLite no demuestra (concurrencia con `FOR UPDATE`, `tenant_create`,
migración). Frontend Vitest (`ng test`), suite con 7 archivos de fallos preexistentes ya conocidos.

**Target Platform**: Web (SPA Angular) + API REST FastAPI, despliegue **coordinado** de
`pos-backend` y `pos-heladeria` (sin ventana de compatibilidad, decisión de la spec).

**Project Type**: Aplicación web con dos repositorios independientes (`pos-backend`, `pos-heladeria`)
más este repositorio de specs.

**Performance Goals**: Sin objetivos nuevos. El cierre añade **una** consulta de catálogo (11 filas)
y un `FOR UPDATE` puntual a una consulta que ya existía; el reporte lee las mismas filas con dos
columnas más. Vigilar el presupuesto de consultas de `test_cash_report_query_budget`
([research.md](./research.md) R11).

**Constraints**: Atomicidad total del cierre (todo o nada, una sola transacción); cero cambios en
montos históricos (SC-004); nombres de restricciones idénticos entre modelo y migración; el cliente
no puede influir en ningún total; errores del cierre como cadena en español legible por
`CashService.extractError`.

**Scale/Scope**: Catálogo de 11 filas por tenant; un cierre por turno (≈ 1–3 turnos/día/caja);
reporte con ≤ 11 filas de desglose. Archivos tocados: ≈ 8 de producción en backend, ≈ 6 en
frontend, ≈ 12 de pruebas.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Constitución v4.0.0. Resultado: **sin violaciones**; una condición previa a implementar (II).

| Principio | Evaluación | Estado |
|-----------|-----------|--------|
| **I.** Nace de un spec | `spec.md` con 11 clarificaciones y checklist 16/16 | ✅ |
| **II.** Comportamiento existente protegido | Los 6 cambios (D-1 a D-6) están en la tabla de la spec con «Hoy / Desde esta spec / Afectados». **Condición**: registrar A-130 a A-134 en `registro-de-anomalias.md` **antes** de implementar (tarea inicial); D-5 y D-6 (el usuario que cierra, FR-029, y la observación siempre visible, FR-025) van en A-134 ([research.md](./research.md) R12) | ✅ con condición |
| **III.** Characterization tests | Ninguna de las 4 suites de caja que se adaptan contiene tests `CONGELA comportamiento actual:` (verificado con `grep`); son pruebas de la spec 119. La spec **autoriza** la adaptación mínima, con D-1/D-2 citada en cada commit. La intención de cada prueba no cambia | ✅ |
| **IV.** Nuevos specs pueden cambiar comportamiento | Es exactamente el caso: D-1/D-2 | ✅ |
| **V.** Sin refactorizaciones oportunistas | Solo se toca `close_shift`, su esquema, el reporte y el modal/reporte de caja. **No** se corrige el «Cajero:» del reporte (muestra al usuario actual, no a quien abrió; [research.md](./research.md), hallazgo adicional) ni se renombra `cash_count_denominations`. Lógica nueva en módulo propio (`denominations.py`), como hizo la spec 119 con `active_orders.py` | ✅ |
| **VI.** Evolución incremental | Cinco bloques; datos (2) y comportamiento (3) en incrementos y commits **separados** y verificables por separado. Se **despliegan juntos**: `kind` queda `NOT NULL` y el `close_shift` actual no lo informa (ver tasks.md, Fase 2) | ✅ |
| **VII.** Datos históricos inmutables | La migración no toca `counted_amount`, `close_note`, diferencia ni esperado de ningún turno; las facturas no se tocan. Verificado con huella `md5` antes/después (quickstart 0.3 y 2) | ✅ |
| **VIII.** Evolución del modelo de datos | [data-model.md](./data-model.md): entidades/campos nuevos, sin valores por defecto salvo sembrado, compatibilidad, migración paso a paso, `downgrade` sin pérdida de líneas conservadas, respaldo operativo previo y compuerta FR-028 | ✅ |
| **IX.** Dependencias nuevas | Ninguna | ✅ |
| **X.** Verificación obligatoria | Pruebas nuevas + adaptadas + línea base + PostgreSQL real + recorrido manual ([quickstart.md](./quickstart.md)) | ✅ |
| **XI.** Decisión de negocio vs. técnica | Negocio (qué): D-1 a D-6, ya decididas por el solicitante. Técnico (cómo): catálogo en tabla, `extra="allow"`, `FOR UPDATE`, respaldo operativo — todas en [research.md](./research.md), ninguna altera una regla de negocio | ✅ |
| **XII.** Trazabilidad | Necesidad → spec → D-1..D-4 → plan/research → tareas → pruebas → quickstart; cada contrato cita FR/US | ✅ |
| **XIII.** Español de Colombia | Todos los artefactos y mensajes de error de usuario en español; **commits y ramas en inglés** | ✅ |
| **XIV.** Ramas | `feat/121-denomination-breakdown` en cada repo, desde `develop` (rama actual de ambos), **antes** de tocar código | ✅ (a ejecutar) |
| **XV.** Commits | Solo a pedido explícito del usuario; commits pequeños por bloque; inglés, Conventional Commits | ✅ (a ejecutar) |

### Re-evaluación posterior al diseño (Fase 1)

Sin cambios en el resultado. El diseño no introdujo dependencias, no tocó datos de facturación, y la
única decisión que podría rozar V (nuevo módulo `denominations.py`, tabla nueva) se justifica por
el contrato de la spec, no por limpieza. **Dos riesgos para vigilar** (no son violaciones):
(1) `tenant_create()` no es cubrible en SQLite → verificación en PostgreSQL (R2);
(2) `test_cash_report_query_budget` podría pedir ajuste de presupuesto → solo con cifra medida (R11).

## Project Structure

### Documentation (this feature)

```text
specs/121-desglose-denominaciones-cierre/
├── spec.md                       # Especificación (ya existe)
├── plan.md                       # Este archivo (/speckit-plan)
├── research.md                   # Fase 0: verificación contra el código + decisiones R1–R12
├── data-model.md                 # Fase 1: tabla nueva, columnas nuevas, migración, reversión
├── quickstart.md                 # Fase 1: validación de extremo a extremo
├── quickstart-preflight.sql      # Compuerta FR-028, solo lectura (validada en dev)
├── checklists/requirements.md    # Checklist de calidad de la spec (ya existe)
├── contracts/
│   ├── close-shift-api.md        # POST /cash/shifts/{id}/close (contrato estricto)
│   ├── denomination-catalog-api.md   # GET /cash/denominations (nuevo)
│   └── shift-report-api.md       # GET /cash/shifts/{id}/report (aditivo) + presentación
└── tasks.md                      # Fase 2 (/speckit-tasks — NO lo crea este comando)
```

### Source Code (repository root: `skeilo/`)

Tres repositorios independientes; solo se listan los archivos tocados.

```text
pos-backend/                                  (rama feat/121-denomination-breakdown)
├── alembic/versions/
│   └── <rev>_121_denomination_breakdown.py   # NUEVO: down_revision cd3e314a79b8
├── app/
│   ├── core/db.py                            # tenant_create(): sembrar catálogo tras create_all
│   ├── models/
│   │   ├── __init__.py                       # registrar DenominationCatalog
│   │   ├── denomination_catalog.py           # NUEVO: modelo + DEFAULT_COP_DENOMINATIONS + seed
│   │   ├── cash_count_denomination.py        # + kind, CHECK quantity > 0, CHECK kind
│   │   └── cash_shift.py                     # + closed_by_user_id / closed_by_user_name
│   ├── api/v1/cash/
│   │   ├── denominations.py                  # NUEVO: reject_client_totals, resolve_count_lines, catálogo
│   │   ├── schemas.py                        # ShiftClose/DenominationIn (extra=allow), CountLineOut,
│   │   │                                     #   DenominationCatalogItem, ShiftResponse + closed_by_*
│   │   ├── service.py                        # get_shift_for_update (FOR UPDATE)
│   │   └── router.py                         # close_shift reordenado; GET /denominations; report
│   ├── scripts/e2e_qr_flow.py                # cierre con denominations + close_note (D-1)
│   └── characterization_tests/
│       ├── test_cash_close_denominations.py          # NUEVO: contrato del cierre (US1, US2, US6)
│       ├── test_cash_denomination_catalog.py         # NUEVO: catálogo + siembra
│       ├── test_cash_report_denominations.py         # NUEVO: reporte (US4, US5)
│       ├── test_migrate_denomination_breakdown.py    # NUEVO: migración (tipo, ceros, compuerta)
│       └── test_cash_close_active_orders.py, test_cash_report_query_budget.py,
│           test_cash_report_batch_identity.py, test_cash_shift_sales_report.py   # 27 ShiftClose() adaptados

pos-heladeria/                                (rama feat/121-denomination-breakdown)
└── src/app/modules/cash-register/
    ├── interfaces/
    │   ├── cash.interface.ts                 # CatalogDenomination, CountLine, ShiftClosePayload sin counted_amount,
    │   │                                     #   CashShift + closed_by_user_*, ShiftReport.denominations
    │   └── cash-session.interface.ts         # Denomination + kind; DesgloseRow
    ├── services/
    │   ├── cash.service.ts                   # getDenominations()
    │   ├── cash-session.store.ts             # sin DENOMS; catálogo/estado; desgloseView; payload nuevo
    │   ├── cash.service.spec.ts              # adaptado + getDenominations
    │   └── cash-session.store.spec.ts        # adaptado + catálogo/observación/payload
    └── components/
        ├── cash-arqueo-modal.component.ts    # filas del catálogo, error+Reintentar, «estimado», observación fija
        ├── cash-arqueo-modal.component.spec.ts
        ├── cash-report.component.ts          # «Desglose del conteo», «Contado por», estilos de impresión
        └── cash-report.component.spec.ts

pos-specs/
└── specs/000-reconocimiento/registro-de-anomalias.md   # A-130..A-134 (A-129: anotar «resuelto por 121»; A-20 / RN-CASH-09: «superada»)
```

**Structure Decision**: aplicación web de dos repositorios (backend FastAPI + frontend Angular),
más el repositorio de specs. No se crea ningún módulo de frontend ni paquete nuevo: todo vive en el
módulo `cash-register` y en `app/api/v1/cash/`. El único archivo de producción nuevo del backend
fuera del modelo y la migración es `denominations.py`, que sigue el precedente de `active_orders.py`
(spec 119) para no engordar `router.py`.

## Orden de trabajo sugerido para `/speckit-tasks`

Para que cada incremento sea verificable por separado (Principio VI) y desplegable en orden (datos y contrato del cierre juntos):

1. **Registro** (`pos-specs`): A-130..A-134; crear ramas de código.
2. **Datos (sin cambio de comportamiento de la API)**: modelos + migración + siembra en `tenant_create` +
   pruebas de migración. Verificar con quickstart §1–§2 y §6. *No desplegar sola*: con `kind NOT NULL`
   sin valor por defecto, el `close_shift` actual fallaría al insertar un desglose; se despliega junto con el bloque 3.
3. **Backend, contrato**: `denominations.py`, `close_shift`, `GET /denominations`, reporte,
   `closed_by_*`, y adaptar las pruebas existentes **en el mismo commit que cambia el contrato**
   (de lo contrario la suite queda en rojo entre commits). Verificar quickstart §3–§5.
4. **Frontend**: interfaces/servicio → store → modal → reporte → pruebas. Verificar §7–§8.
5. **Cierre**: regresión completa (§9), anotar A-129 «resuelto por 121», actualizar el checklist.

Backend y frontend se **despliegan de forma coordinada** (el `422` por `counted_amount` es el
mecanismo de la ventana de despliegue; decisión de la spec).

## Complexity Tracking

> No hay violaciones de la constitución que justificar. Se anota por transparencia la única
> complejidad añadida que no está literalmente en la spec:

| Elemento | Por qué hace falta | Alternativa más simple descartada porque |
|----------|--------------------|------------------------------------------|
| `FOR UPDATE` + captura de `IntegrityError` → `409` en el cierre | FR-019 / SC-006 exigen exactamente un cierre ganador y ningún `500` | Confiar solo en el índice único dejaría pasar un `500` al perdedor y no serializa el cálculo del arqueo |
| Tabla `denomination_catalog` (en vez de constante en código) | FR-009/FR-012: «catálogo por tenant, sembrado»; la spec futura de administración lo ampliará | Una constante no es «por tenant» y obligaría a migrar a tabla después |
| Siembra extra en `tenant_create()` | Sin ella los tenants nuevos no podrían cerrar turnos desde la pantalla (FR-013) | Sembrar solo en la migración repite el hueco ya existente con «Compra ocasional» (spec 106) |
