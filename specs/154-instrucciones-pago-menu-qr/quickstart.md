# Quickstart: validar Instrucciones de Pago del Menú QR por Modalidad del Plan

Guía de ejecución para comprobar la implementación de esta fase. No repite firmas ya
detalladas en [data-model.md](./data-model.md) y
[contracts/plan-qr-payment-instruction.md](./contracts/plan-qr-payment-instruction.md).

**Prerequisitos**: entorno virtual de `pos-backend` (venv `env`, ver memory del proyecto —
local Postgres disponible pero no necesario para estos tests, `fixtures.py` usa SQLite en
memoria), ejecutado desde la raíz de `../pos-backend` (sibling de este repo `pos-specs`); Node/
Angular CLI para `pos-heladeria`.

```bash
cd ../pos-backend
source env/bin/activate
```

## Paso 0 — Confirmar la línea base antes de tocar código

```bash
python -m unittest discover -s app/characterization_tests -p 'test_*.py' -v
```

**Resultado esperado**: todo en verde. Ningún `"CONGELA comportamiento actual:"` existente
asume que `Plan` carece de `modalidad_pago_qr` ni que `OrderResponse` carece de
`qr_payment_instruction_mode` — ninguno se modifica (Principio III).

## US1 — El Super Admin define la modalidad de pago del plan

Fichero modificado: `app/characterization_tests/test_super_admin_plans.py` (se extiende, mismo
patrón que los casos de `cocina_access` de spec 149).

1. `POST /super-admin/plans` con `modalidad_pago_qr="PAY_BEFORE_RECEIVING"` (autenticado como
   super admin) → `201`, `modalidad_pago_qr` persistido tal cual en la respuesta.
2. `POST /super-admin/plans` sin enviar `modalidad_pago_qr` → `201`,
   `modalidad_pago_qr: "PAY_AFTER_RECEIVING"` (FR-002, default = comportamiento actual).
3. `POST /super-admin/plans` con `modalidad_pago_qr="OTRO"` → `422` (fuera del catálogo
   cerrado, FR-001/FR-002).
4. `PATCH /super-admin/plans/{id}` con `modalidad_pago_qr="PAY_AFTER_RECEIVING"` sobre un plan
   que lo tenía en `PAY_BEFORE_RECEIVING` → `200`, reemplaza por completo el valor anterior
   (Acceptance Scenario 2 del spec — nunca coexisten ambos).
5. `GET /plan` (como ADMIN de un tenant con ese plan) → la respuesta **no** contiene
   `modalidad_pago_qr` ni ninguna clave equivalente, en ningún nivel del JSON (Acceptance
   Scenario 3 del spec; research.md Decisión 3, contracts, sección "`GET /plan` — sin cambios").

```bash
python -m unittest app.characterization_tests.test_super_admin_plans -v
python -m unittest app.characterization_tests.test_plan_summary -v
```

## US2 — El comensal ve la instrucción correcta según la modalidad del plan de su tenant

Fichero nuevo o extendido: `app/characterization_tests/test_cart_submit.py` (o el que ya cubra
`POST /cart/submit`/`GET /cart/orders` — confirmar nombre exacto por búsqueda antes de
implementar).

Backend — para cada combinación de `Plan.modalidad_pago_qr` (`PAY_AFTER_RECEIVING`/
`PAY_BEFORE_RECEIVING`) y método de pago (efectivo/transferencia/mixto), con un tenant
suscrito a ese plan:

1. `POST /cart/submit` → `201`, `qr_payment_instruction_mode` en la respuesta coincide con
   `Plan.modalidad_pago_qr` del tenant (FR-006).
2. `GET /cart/orders` (misma sesión) → el mismo pedido trae el mismo
   `qr_payment_instruction_mode` (consistencia entre ambos endpoints).
3. Un `OrderResponse` devuelto por un endpoint de staff (p. ej. `GET /orders` del POS) para la
   misma orden → `qr_payment_instruction_mode: null` (FR-013 — el campo existe en el schema
   pero nadie fuera de `cart/router.py` lo asigna).

```bash
python -m unittest app.characterization_tests.test_cart_submit -v
```

Frontend — `confirmation-step.component.spec.ts` (nuevo, no existía spec dedicado para este
componente antes de esta spec):

1. Dado un `order` con `qr_payment_instruction_mode: 'PAY_AFTER_RECEIVING'` y
   `current_payment_attempt.is_cash: true` → el componente renderiza exactamente "Te
   llevaremos tu pedido a la mesa. Paga al recibirlo." (Acceptance Scenario 1 de US2).
2. Mismo modo, transferencia (`is_cash: false`, sin `cash_amount`) → "Muestra el comprobante de
   tu banco al cajero cuando recibas tu pedido." (Acceptance Scenario 2, sin mencionar "Nequi"
   explícitamente).
3. Mismo modo, mixto (`cash_amount` y `transfer_amount` presentes) → "Al recibir tu pedido,
   muestra el comprobante de la transferencia al cajero. El efectivo lo pagas al recibirlo."
   (Acceptance Scenario 3).
4. `qr_payment_instruction_mode: 'PAY_BEFORE_RECEIVING'`, efectivo/transferencia/mixto → los
   tres mensajes nuevos exactos de FR-008 (Acceptance Scenarios 4-6).
5. `qr_payment_instruction_mode: null` (orden servida antes del despliegue de este campo) → no
   se renderiza ninguna instrucción, sin error (research.md Decisión 5).

```bash
cd ../pos-heladeria
ng test --include='**/confirmation-step.component.spec.ts'
ng test --include='**/order-status.util.spec.ts'
```

**Nota sobre la baseline del frontend** (memory del proyecto): la suite completa de `ng test`
es conocida como flaky/no determinista — comparar por archivo afectado, no por conteo total.

## US3 — El cambio de modalidad se refleja de inmediato en los tenants del plan

Reutiliza los mismos characterization tests de US2, ejecutados dos veces sobre el mismo tenant
con un `PATCH /super-admin/plans/{id}` de por medio:

1. Dos tenants suscritos al mismo plan en `PAY_AFTER_RECEIVING` → ambos reciben
   `qr_payment_instruction_mode: "PAY_AFTER_RECEIVING"` en `POST /cart/submit`.
2. `PATCH /super-admin/plans/{id}` cambia ese plan a `PAY_BEFORE_RECEIVING`.
3. Un nuevo `POST /cart/submit` de cada uno de los dos tenants → ambos reciben
   `"PAY_BEFORE_RECEIVING"`, sin ninguna acción propia de los tenants (Acceptance Scenario 1).
4. Un tenant de un plan distinto, no tocado por el `PATCH` anterior → sigue recibiendo el valor
   de su propio plan, sin cambios (Acceptance Scenario 2, FR-005).
5. El pedido creado en el paso 1 (antes del `PATCH`), al volver a consultarse vía
   `GET /cart/orders` **después** del `PATCH`, refleja la modalidad **nueva** del plan — porque
   el campo se recalcula en cada lectura, nunca se persiste (research.md Decisión 4). Esto es
   consistente con Acceptance Scenario 3 del spec ("la instrucción ya mostrada... no se altera
   retroactivamente"): lo que no cambia es lo que el comensal **ya vio en pantalla**, no un
   valor grabado en la orden — el spec no pide inmutabilidad de un campo persistido porque
   ninguno existe.

## Verificación de migración

```bash
cd ../pos-backend
alembic upgrade head
```

**Resultado esperado**: `shared.plans` gana la columna `modalidad_pago_qr`
(`varchar(30) NOT NULL DEFAULT 'PAY_AFTER_RECEIVING'`, con `CheckConstraint`
`ck_plans_modalidad_pago_qr`); todo plan existente queda con `modalidad_pago_qr =
'PAY_AFTER_RECEIVING'` sin ninguna acción manual — ningún tenant ve cambio de comportamiento
observable hasta que el Super Admin cambie explícitamente algún plan (Principio II).

```bash
alembic downgrade -1
```

**Resultado esperado**: `drop_constraint` seguido de `drop_column`, sin error — confirma que el
orden de reversión (constraint antes que columna) es correcto.

## Cierre

El spec se considera completo cuando: los 5 pasos de US1, los 3+5 de US2 (backend + frontend) y
los 5 de US3 pasan; `alembic upgrade head`/`downgrade -1` son limpios en ambas direcciones; y
ningún characterization test existente quedó en rojo (Principio X, cadena de verificación del
Principio XII).
