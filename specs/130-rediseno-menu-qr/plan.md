# Implementation Plan: Rediseño visual del Menú QR con pago mixto y bloqueo de salida con pago pendiente

**Branch**: `feat/130-rediseno-menu-qr` | **Date**: 2026-10-20 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/130-rediseno-menu-qr/spec.md`

## Summary

Restylar las ocho pantallas del Menú QR del comensal con la apariencia del diseño de referencia
(`design/Bienvenida QR v1.dc.html`) sin alterar ningún comportamiento vigente, salvo dos cambios
de regla de negocio pedidos explícitamente por el negocio: (1) permitir "Pago mixto" (efectivo +
transferencia) como método de pago del comensal, habilitable por el tenant en su catálogo (spec
032) solo si ya tiene efectivo y transferencia activos; y (2) bloquear la acción "Salir" cuando el
comensal tiene un pedido propio con pago no confirmado. Los toppings ya se renderizan como
checkboxes funcionalmente (`product-select.component.ts`) — esa parte del alcance es puramente
visual. El pago mixto exige extender `OrderPaymentAttempt` con el desglose efectivo/transferencia
y una confirmación de dos partes (research.md Decisiones 3-4), lo que a su vez extiende el gate de
despacho a cocina y los dos endpoints de confirmación del cajero sin cambiar su firma. El bloqueo
de salida cambia el contrato hoy infalible de `POST /cart/leave` — único punto de todo este plan
que requiere una decisión de negocio registrada en `registro-de-anomalias.md` antes de
implementarse (Principio II), ya respaldada por la Historia 3 y las Clarificaciones Q1/Q2 de
`spec.md`.

## Technical Context

**Language/Version**: Backend: Python 3.11 (FastAPI + SQLAlchemy). Frontend: TypeScript ~5.9 /
Angular ^21.1 (standalone components, signals).

**Primary Dependencies**: Ninguna nueva (Principio IX). Se reutiliza en su totalidad: el motor de
grupos de opciones (spec 004), el patrón de intento de pago y comprobante por transferencia (spec
024/025), el catálogo de métodos de pago por tenant (spec 032), la vista de pasos del checkout y
su persistencia de progreso en `localStorage` (spec 034), y el precedente de mapeo de íconos
Lucide → set interno ya sentado en spec 034.

**Storage**: PostgreSQL 16, schema-per-tenant. Dos migraciones: `shared.payment_method_catalog`
(ampliar `CHECK` de `type` con `'mixed'`) y `tenant.order_payment_attempts`
(`@for_each_tenant_schema`: `cash_amount`, `transfer_amount`, `transfer_method_id`,
`cash_confirmed_at`, las cuatro `NULL` por defecto, sin backfill — ver data-model.md).

**Testing**: Backend: `./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`
— baseline en verde antes y después, más tests nuevos para: validación de `cash_amount`/
`transfer_method_id` en `submit_cart` (`test_cart_service.py` o similar), el gate extendido de
`_confirm_order_impl` para intentos mixtos (`app/api/v1/orders/checkout.py`), la validación de
activación de "Pago mixto" por tenant (spec 032), y el nuevo `409` de `POST /cart/leave`
(`leave_session`). Frontend: `npx ng test --watch=false --include='src/app/modules/tables/**/*.spec.ts'`
— comparar contra la baseline de fallos preexistentes ya documentada (memoria del proyecto), más
specs nuevos para el paso de monto en efectivo del pago mixto, la invalidación del comprobante al
cambiar ese monto, y el nuevo diálogo de bloqueo de salida.

**Target Platform**: API web (FastAPI) + Menú QR público (mismo frontend Angular de
`pos-heladeria`, ruta pública) — ambos ya en producción.

**Project Type**: Web application (frontend Angular + backend FastAPI ya existentes).

**Performance Goals**: N/A — el rediseño visual no cambia el perfil de carga de datos; el pago
mixto agrega cuatro columnas nullable a una fila ya consultada por pedido, sin joins nuevos en el
camino de lectura caliente (listados de "Mis pedidos"); el bloqueo de salida agrega una consulta
puntual (una orden por participante, ya indexada por `participant_id`) a una acción de baja
frecuencia.

**Constraints**: No reestructurar `public-menu.component.ts` en subcomponentes como parte de este
rediseño (research.md Decisión 1 — sería refactorización no relacionada, Principio V). No
modificar `toggleOption()` ni ninguna regla del motor de grupos de opciones (spec 004) — Historia 4
es solo CSS/plantilla. No permitir dos intentos de pago simultáneos por orden — el pago mixto se
modela como una sola fila extendida de `OrderPaymentAttempt`, preservando
`idx_pending_payment_attempt_per_order` sin cambios (research.md Decisión 3). No construir la UI
de Terminal de Mesas para que el cajero confirme cada porción de un pago mixto — solo el contrato
de backend (research.md Decisión 4); esa UI es seguimiento de spec 112, fuera de alcance aquí. No
implementar el cambio de `POST /cart/leave` sin que exista antes la entrada correspondiente en
`registro-de-anomalias.md` (Principio II).

**Scale/Scope**: Backend: 2 migraciones, 4 columnas nuevas en 1 modelo, 1 `CHECK` ampliado en otro,
1 esquema de request extendido (`SubmitCartIn`), 1 validación nueva en la activación de métodos de
pago por tenant, 1 gate extendido (`_confirm_order_impl`), 2 endpoints de confirmación con
comportamiento condicional sin cambio de firma, 1 validación nueva + 1 excepción nueva en
`leave_session`. Frontend: restyle de 8 pantallas sobre componentes ya existentes (sin dividirlos),
1 paso nuevo en el flujo de checkout (monto en efectivo del pago mixto + invalidación de
comprobante), 1 diálogo nuevo (bloqueo de salida, reemplaza el `confirm()` nativo), 1 extensión de
`CheckoutProgressStore`/`diner.service.ts` para los campos nuevos.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principio I (nace de un spec)**: ✅ `specs/130-rediseno-menu-qr/spec.md` existe, con 6
  clarificaciones ya resueltas y requisitos funcionales completos (FR-001 a FR-012).
- **Principio II (comportamiento existente protegido / decisión de negocio registrada)**: ⚠️
  requiere una acción explícita antes de implementar — `POST /cart/leave` deja de ser infalible
  (research.md Decisión 7). La decisión de negocio ya está en `spec.md` (Historia 3,
  Clarificaciones Q1/Q2), pero **no basta por sí sola**: debe quedar también registrada en
  `specs/000-reconocimiento/registro-de-anomalias.md` con quién y cuándo, antes de tocar
  `leave_session`. El resto de esta spec (rediseño visual, pago mixto, toppings) es comportamiento
  **nuevo** que no reemplaza nada existente, así que no requiere entrada en ese registro
  (Principio IV).
- **Principio III (characterization tests)**: a revisar en `/speckit-tasks` antes de tocar código:
  cualquier test `"CONGELA comportamiento actual:"` sobre `leave_session`/`POST /cart/leave` que
  asuma "nunca falla" debe actualizarse citando esta spec y la entrada del registro de anomalías;
  cualquiera sobre `_confirm_order_impl`/`confirm_cash_payment_attempt`/`approve_payment_attempt`
  que no contemple un intento mixto sigue pasando sin cambios (el nuevo comportamiento es
  condicional a `cash_amount IS NOT NULL`, que no existía antes).
- **Principio IV (los specs pueden introducir comportamiento nuevo)**: ✅ aplica a "Pago mixto"
  (FR-004 a FR-008) y al bloqueo de salida (FR-009 a FR-012) — ninguno corrige un defecto, ambos
  son alcance nuevo pedido por el negocio.
- **Principio V/VI (sin refactor oportunista, cambio incremental)**: ✅ el rediseño visual se aplica
  in situ sobre los componentes existentes (research.md Decisión 1), sin dividirlos; el pago mixto
  se modela extendiendo una fila existente, no una tabla nueva (research.md Decisión 3); la UI de
  confirmación de cajero para pagos mixtos se deja explícitamente fuera de alcance (seguimiento de
  spec 112) para no mezclar una funcionalidad de staff no pedida dentro de un rediseño del Menú QR.
- **Principio VII (datos históricos)**: ✅ sin riesgo — ninguna `Sale`/factura ya emitida se toca;
  el pago mixto solo aplica a pedidos nuevos del comensal vía `submit_cart`; el bloqueo de salida no
  modifica ningún pedido, solo rechaza una acción de sesión.
- **Principio VIII (evolución del modelo de datos)**: ✅ cuatro columnas nullable sin backfill y un
  `CHECK` ampliado — ambas migraciones con rollback trivial (`DROP COLUMN` / revertir el `CHECK`,
  data-model.md § Migraciones).
- **Principio IX (dependencias nuevas)**: ✅ ninguna.
- **Principio X (verificación obligatoria)**: ver Testing arriba — characterization tests
  existentes en verde + tests nuevos por cada punto de FR-004 a FR-012, más los criterios de
  aceptación de `spec.md` cubiertos en `quickstart.md`.
- **Principio XI (decisiones de negocio vs técnicas)**: ✅ FR-004/FR-005/FR-006/FR-009/FR-010 son
  decisiones de negocio ya tomadas en `spec.md`, citadas tal cual; el modelado de
  `OrderPaymentAttempt` extendido, el gate de dos confirmaciones, y la estructura de componentes
  del rediseño son decisiones técnicas de este plan, documentadas con alternativa considerada en
  `research.md`.
- **Principio XII (trazabilidad)**: ✅ cadena completa: Necesidad (pedido del usuario, citado en
  `spec.md` § Input) → Spec 130 (con 6 clarificaciones) → Investigación (`research.md`, 9
  decisiones) → Plan (este documento) → Implementación → Tests → Verificación
  (`quickstart.md`).
- **Principio XIV (rama Git)**: se crea `feat/130-rediseno-menu-qr` en **ambos** repositorios
  (backend para el modelo/migraciones/endpoints, frontend para el rediseño y el flujo de pago
  mixto), partiendo de `develop` en cada uno.
- **Principio XV (commits)**: solo bajo pedido explícito del usuario, en unidades lógicas
  separadas por repo/capa (ej. migración aparte de validación aparte de endpoint), en inglés, sin
  marcas de autoría de IA.

**Resultado**: PASA, con una condición explícita antes de implementar (no antes de planear): la
entrada en `registro-de-anomalias.md` para el cambio de contrato de `POST /cart/leave` (Principio
II). Sin otras violaciones que requieran justificación en Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/130-rediseno-menu-qr/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output — 9 decisiones técnicas
├── data-model.md        # Phase 1 output — OrderPaymentAttempt extendido, PaymentMethodCatalog.type='mixed'
├── contracts/
│   ├── pago-mixto-comensal.md   # POST /cart/submit extendido, confirm-cash/approve condicionales, activación en catálogo
│   └── bloqueo-salida.md        # POST /cart/leave (nuevo 409), contrato del diálogo de bloqueo en frontend
├── quickstart.md         # Phase 1 output — 5 escenarios de validación manual + verificación automatizada
└── checklists/
    └── requirements.md  # Spec quality checklist (si existe, de /speckit-specify)
```

### Source Code (repository root)

```text
pos-backend/
└── app/
    ├── models/
    │   ├── order_payment_attempt.py         # + cash_amount, transfer_amount, transfer_method_id, cash_confirmed_at
    │   └── payment_method_catalog.py        # CHECK de `type` + 'mixed'
    ├── alembic/versions/
    │   ├── <nueva>_order_payment_attempt_split.py     # @for_each_tenant_schema
    │   └── <nueva>_payment_method_catalog_type_mixed.py
    ├── api/v1/
    │   ├── cart/
    │   │   ├── schemas.py                    # SubmitCartIn: + cash_amount, transfer_method_id
    │   │   ├── service.py                    # submit_cart(): validación FR-005/FR-006; leave_session(): nueva validación de pago pendiente + excepción
    │   │   └── router.py                     # leave(): traduce la excepción nueva a 409
    │   ├── orders/
    │   │   ├── checkout.py                   # _confirm_order_impl(): gate extendido; confirm_cash_payment_attempt()/approve_payment_attempt(): comportamiento condicional sobre intento mixto
    │   │   └── schemas.py                    # PaymentAttemptResponse: + cash_amount, transfer_amount, cash_confirmed_at (FR-008)
    │   └── payment_methods/ (spec 032)       # validación de activación: 'mixed' exige cash+transfer activos (FR-004) — ruta exacta a confirmar en /speckit-tasks
    └── characterization_tests/               # tests nuevos descritos en Testing arriba

pos-heladeria/
└── src/app/modules/tables/
    ├── pages/
    │   ├── public-menu.component.ts          # restyle in situ; confirmExit()/exit(): nuevo flujo de bloqueo (research.md Decisión 8); despedida: localizar y restylar su rama inline
    │   └── checkout/
    │       ├── payment-method-step.component.ts     # + opción "Pago mixto"; nuevo paso intermedio de monto en efectivo
    │       ├── transfer-details-step.component.ts   # muestra "+ {monto} en efectivo al recibir" cuando aplica (FR-007)
    │       ├── confirmation-step.component.ts        # desglose de pago mixto (FR-008)
    │       └── checkout-progress.store.ts             # + cash_amount, transfer_method_id; invalidación de receipt_file_url al cambiar cash_amount
    ├── components/
    │   ├── product-select.component.ts        # restyle de checkboxes (sin tocar toggleOption())
    │   └── cart-item-options.component.ts      # restyle de solo lectura
    └── services/diner.service.ts               # leave(): ya no traga el 409; submitCart(): + cash_amount/transfer_method_id
```

**Structure Decision**: cambios en ambos repositorios, cada uno con su propia rama
`feat/130-rediseno-menu-qr` (Principio XIV). El rediseño visual se aplica in situ sobre los
componentes listados, sin reestructurarlos (research.md Decisión 1). El pago mixto se entrega como
una extensión de datos (una fila, cuatro columnas nuevas) más un paso nuevo en un flujo ya
existente, no como subsistema aparte. El bloqueo de salida se mantiene como el único punto del
plan que depende de una acción de gobernanza previa (entrada en `registro-de-anomalias.md`) antes
de tocar código — identificable y pospuesto sin bloquear el resto si fuera necesario (Principio
VI).

## Complexity Tracking

*No aplica — el Constitution Check no reporta violaciones que requieran justificación. La única
condición (registro de anomalías para `POST /cart/leave`) es un paso de gobernanza, no una
excepción a un principio.*
