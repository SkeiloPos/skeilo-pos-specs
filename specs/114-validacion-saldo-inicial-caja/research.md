# Research: Validación de saldo inicial mayor a cero al abrir caja

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

No quedó ningún `NEEDS CLARIFICATION` en el Technical Context del plan: toda la información
necesaria se obtuvo investigando el código actual de `pos-backend` y `pos-heladeria` (citado en
`spec.md` → "Contexto y comportamiento actual") y verificando, además, cómo el proyecto ya resuelve
problemas estructuralmente idénticos (mensajes de error explícitos en español, migraciones
schema-per-tenant, fixtures de characterization tests). La decisión de negocio en sí ya está
cerrada (`spec.md` → Clarifications, FR-008) y registrada como
[A-125](../000-reconocimiento/registro-de-anomalias.md) — este documento resuelve únicamente el
*cómo* técnico.

## D1 — Mecanismo para que el backend responda `422` con el mensaje explícito exigido (FR-004/FR-005/FR-006)

**Decision**: no usar una restricción de Pydantic (`gt=0`) en `ShiftOpen.opening_amount`
(`app/api/v1/cash/schemas.py:32`, hoy `Field(0, ge=0, max_digits=12, decimal_places=2)`). En su
lugar, se quita el límite inferior del `Field` (queda `Field(0, max_digits=12, decimal_places=2)`,
sin `ge=0` ni `gt=0`) y se agrega una validación explícita al comienzo de `open_shift()`
(`app/api/v1/cash/router.py:69`), antes de construir el `CashShift`:

```python
if body.opening_amount <= 0:
    raise HTTPException(
        status.HTTP_422_UNPROCESSABLE_ENTITY,
        "El saldo inicial es obligatorio y debe ser mayor a cero",
    )
```

**Rationale**:
- Se verificó (`app/core/error_response.py:84`, `envelope_from_validation_error`) que **cualquier**
  error que Pydantic detecte vía `Field`/`RequestValidationError` se reempaqueta con el mensaje
  genérico `"Los datos enviados no son válidos."` — exactamente lo que la spec prohíbe en su propia
  sección de Assumptions ("el mensaje devuelto en el 422 sigue el mismo patrón que usan hoy otros
  endpoints del módulo de caja... no el formato de error genérico de validación").
- El propio módulo de caja ya resuelve este mismo problema así: `close_shift()`
  (`app/api/v1/cash/router.py:96-117`) valida con un `Field` laxo (`counted_amount` opcional, sin
  mínimo de negocio) y hace el chequeo real ("el arqueo no cuadra: la observación es obligatoria")
  con un `raise HTTPException(422, "<mensaje explícito>")` directo en el router. FR-005 pide
  replicar exactamente ese patrón, no inventar uno nuevo.
- Quitar el límite del `Field` (en vez de solo bajarlo a `gt=0`, que seguiría generando el 422
  genérico de Pydantic para `0` y valores negativos) es necesario para que **tanto** `0` **como**
  cualquier valor negativo lleguen al router y reciban el mismo mensaje explícito — la spec exige
  "el mismo criterio" para ambos casos (User Story 2, escenario 2).

**Alternativas consideradas**:
- **`Field(..., gt=0, ...)`**: descartada — dispara el 422 genérico de Pydantic
  (`"Los datos enviados no son válidos."`), no el mensaje de FR-005, y además pierde el valor por
  defecto `0` del campo (que ya no es relevante una vez el frontend siempre envía un valor, pero
  convertiría cualquier petición que omita el campo en un error de "campo requerido" distinto, en
  vez de caer en el mismo chequeo con el mismo mensaje que exige FR-006 para "sin importar el
  origen de la solicitud").
- **Un `field_validator` de Pydantic que levante `ValueError`**: descartada por la misma razón que
  `Field(gt=0)` — `ValueError` dentro de un validador de Pydantic se convierte en
  `RequestValidationError`, que pasa por el mismo `envelope_from_validation_error` y pierde el
  mensaje explícito.
- **Dejar el `Field` tal cual (`ge=0`) y solo agregar el chequeo del router para capturar `== 0`,
  confiando en que Pydantic rechace los negativos con su propio 422**: descartada porque entonces
  el caso "negativo" y el caso "cero" devolverían mensajes distintos (uno genérico, uno explícito),
  violando "el mismo criterio" de la Acceptance Scenario 2 de User Story 2.

## D2 — Si el `CheckConstraint` de base de datos debe endurecerse, y cómo sin tocar turnos históricos (FR-001, FR-007, Principio VII/VIII)

**Decision**: endurecer `CheckConstraint("opening_amount >= 0", name="ck_cash_shift_opening_positive")`
(`app/models/cash_shift.py:44`) a `CheckConstraint("opening_amount > 0", ...)`, aplicado en dos
frentes:

1. **Modelo** (`cash_shift.py`): el `CheckConstraint` del modelo se actualiza a `> 0`. Esto ya
   alcanza automáticamente a cualquier tenant nuevo que se aprovisione después de este cambio,
   porque `app/core/db.py:100` (`get_tenant_specific_metadata().create_all(...)`) crea el esquema
   de un tenant nuevo directamente desde los modelos actuales, no reproduciendo el historial de
   migraciones de Alembic.
2. **Migración Alembic** (tenants existentes): una migración nueva que, recorriendo cada esquema
   de tenant ya existente (patrón `app/scripts/tenant.py::for_each_tenant_schema`, ya usado por
   otras migraciones de este tipo, p. ej. `alembic/versions/c7e2b91a4d35_084_variante_sin_nombre.py`),
   hace `DROP CONSTRAINT ck_cash_shift_opening_positive` + `ADD CONSTRAINT
   ck_cash_shift_opening_positive CHECK (opening_amount > 0) NOT VALID` sobre `cash_shifts`.

**Rationale**:
- `NOT VALID` (sintaxis propia de PostgreSQL) crea la restricción **sin** escanear ni rechazar las
  filas ya existentes en la tabla — exactamente lo que exige FR-007/Principio VII: ningún turno ya
  abierto o cerrado con `opening_amount = 0` se toca, se recalcula ni bloquea la migración. A partir
  de que la restricción existe, PostgreSQL sí la aplica a **toda fila nueva** (`INSERT`) y a
  cualquier `UPDATE` que tocara esa columna — que es justo el efecto hacia adelante que pide FR-001.
  `opening_amount` nunca se actualiza tras la creación del turno (ni `close_shift()` ni ningún otro
  endpoint lo modifica), así que no hay ningún `UPDATE` existente que la nueva restricción pudiera
  romper de forma inesperada.
- Es defensa en profundidad consistente con el resto del módulo: `DenominationIn.denomination` y
  `CashMovementIn.amount` ya exigen `gt=0` a nivel de Pydantic, pero ninguna columna de dinero de
  este módulo depende *solo* de la capa de API — la tabla ya tenía su propio `CheckConstraint` desde
  antes de esta spec, así que dejarlo en `>= 0` tras este cambio sería inconsistente con que la
  propia spec documenta ese `CheckConstraint` como evidencia del comportamiento que cambia.
- Se descartó revisar manualmente si existen hoy turnos con `opening_amount = 0` en producción:
  es irrelevante para la decisión — `NOT VALID` hace que el resultado sea seguro exista o no ese
  dato, sin necesitar arqueología de datos previa (a diferencia de A-32 en
  `registro-de-anomalias.md`, que sí la requería por otra razón).

**Alternativas consideradas**:
- **No tocar el `CheckConstraint` de base de datos, dejar solo la validación del endpoint**:
  descartada — deja una vía (cualquier proceso que inserte directamente en `cash_shifts` sin pasar
  por `open_shift()`, como un script de datos o una migración futura mal escrita) sin ninguna
  protección, cuando el proyecto ya tiene la convención de proteger columnas de dinero también a
  nivel de base de datos en esta misma tabla.
- **`ADD CONSTRAINT ... CHECK (...)` sin `NOT VALID` (validación completa inmediata)**: descartada
  porque si existiera aunque sea un solo turno histórico con `opening_amount = 0` en cualquier
  tenant, la migración fallaría con un error de integridad y bloquearía el despliegue — un riesgo
  innecesario frente a `NOT VALID`, que logra la misma protección hacia adelante sin ese riesgo.
- **`VALIDATE CONSTRAINT` inmediato después del `NOT VALID`**: descartado por ahora (puede hacerse
  después, como paso de mantenimiento opcional, sin afectar la corrección funcional) — validar
  escanea toda la tabla y solo mejora el plan de consultas del optimizador; no es necesario para
  que la restricción proteja los `INSERT` nuevos, que es el único efecto que esta spec requiere.

## D3 — Dónde vive la validación del frontend y cómo reutiliza lo ya existente (FR-002/FR-003)

**Decision**: agregar un `computed` nuevo en `CashSessionStore`
(`pos-heladeria/src/app/modules/cash-register/services/cash-session.store.ts`), siguiendo el mismo
patrón que los `computed` de deshabilitado ya existentes (`movimientoDisabled`, `arqueoDisabled`):

```ts
readonly aperturaDisabled = computed(
  () => this.isSubmitting() || !this.selectedRegisterId() || this.openingAmount() <= 0,
);
```

`CashOpenComponent` (`components/cash-open.component.ts`) usa `store.aperturaDisabled()` en el
`[disabled]` del botón "Abrir caja y comenzar turno" (hoy solo `!store.selectedRegisterId()`), pasa
`[invalid]="store.openingAmount() <= 0"` a `<app-money-input>`, y agrega debajo el mensaje
condicional:

```html
@if (store.openingAmount() <= 0) {
  <p class="text-red-500 text-xs mt-1">El saldo inicial debe ser mayor a cero para abrir la caja</p>
}
```

**Rationale**:
- No requiere ningún campo ni estado nuevo: `openingAmount` (`cash-session.store.ts:101`) ya es un
  `signal<number>` que arranca en `0` y ya colapsa "vacío" a `0` en el punto donde
  `CashOpenComponent` lo actualiza (`(ngModelChange)="store.openingAmount.set($event ?? 0)"`,
  `cash-open.component.ts:83` — `MoneyInputComponent` emite `number | null`, y `null` ya se
  normaliza a `0` ahí mismo). Esto significa que la Clarification de la spec ("el campo vacío se
  trata igual que cero") ya ocurre hoy, sin ningún cambio adicional — solo falta *reaccionar* a ese
  `0`, que es exactamente lo que hace `aperturaDisabled`.
- Como `openingAmount()` vale `0` desde el primer render (antes de cualquier interacción), el
  `computed` y el `@if` del mensaje ya son verdaderos de inmediato al cargar la pantalla — cumple la
  Clarification de la sesión 2026-10-12 sin necesitar un flag de "tocado"/`touched` ni escuchar
  ningún evento de foco/blur.
- El par `[invalid]` en el input + `<p class="text-red-500 text-xs mt-1">` debajo es el patrón ya
  establecido en este mismo proyecto para mensajes de validación en línea bajo un campo de
  formulario (`pos-heladeria/src/app/modules/auth/pages/change-password.component.ts:71-74,88-91`,
  con `app-password-input` en vez de `app-money-input`, pero el mismo contrato `[invalid]` +
  `<p>` condicional). Reutilizarlo evita introducir un segundo estilo de mensaje de error solo para
  esta pantalla.
- `MoneyInputComponent` (`shared/money-input/money-input.component.ts:57,79-83`) ya acepta
  `@Input() invalid` y ya lo traduce en un borde rojo (`border-red-400`) cuando es `true` — no
  requiere ningún cambio en el componente compartido, solo pasarle el valor correcto desde
  `cash-open.component.ts`.

**Alternativas consideradas**:
- **Validación basada en Angular Reactive Forms (`FormControl` + `Validators.min(0.01)`)**:
  descartada — `CashOpenComponent` usa `ngModel`/signals, no `FormGroup`, y el resto de la pantalla
  de apertura (selección de caja, creación de caja) tampoco usa formularios reactivos; introducirlos
  solo para este campo sería una migración de patrón no pedida por la spec (Principio V).
  Un `computed` sobre el signal existente logra el mismo resultado con menos cambio.
- **Marcar el campo como inválido solo después de que el usuario lo toque (`touched`)**: descartada
  explícitamente por la Clarification de la sesión 2026-10-12 — el mensaje debe aparecer desde la
  carga de la pantalla, sin esperar ninguna interacción.

## D4 — Impacto sobre fixtures/tests existentes que usan `opening_amount=0` (Principio III)

**Decision**: actualizar el valor por defecto de `opening_amount` en las tres copias de
`make_cash_shift()` (`app/characterization_tests/cart_fixtures.py:406`,
`orders_fixtures.py:421`, `table_sessions_fixtures.py:366`) de `Decimal("0")` a un valor positivo
(p. ej. `Decimal("100000")`), como parte de la implementación de esta spec.

**Rationale**:
- Se verificó (`grep -rn "opening_amount" app/characterization_tests/`) que, fuera de esas tres
  líneas `kw.setdefault(...)`, el único otro uso de `opening_amount=0` en todo
  `app/characterization_tests/` es `test_cash_timezone.py` (líneas 25 y 36), que construye un
  `ShiftResponse` de Pydantic con `model_construct()` — nunca pasa por `ShiftOpen`, por
  `open_shift()` ni por la base de datos, así que ni el cambio de D1 ni el de D2 lo afectan.
- Ningún test en el repositorio hace una aserción sobre el valor de `opening_amount` de un turno
  creado por `make_cash_shift()` (se buscó explícitamente: ninguna ocurrencia de `opening_amount`
  fuera de los `setdefault` y de `test_cash_timezone.py`) — esas tres fixtures solo necesitan *un*
  turno abierto para que otros módulos (carrito, pedidos, sesiones de mesa) tengan contra qué
  numerar/facturar; el valor específico del fondo inicial es irrelevante para lo que esos tests
  verifican. Por eso este cambio es de infraestructura de pruebas, no una modificación de un
  characterization test protegido por el Principio III (no hay ningún comportamiento heredado que
  este cambio esté "ajustando para que pase").
- Sin este ajuste, aplicar D2 (el `CheckConstraint > 0`) haría que **cualquier** test que use
  `make_cash_shift()` con su valor por defecto falle al insertar en una base de datos real
  (`IntegrityError`) — por eso este punto es un prerrequisito técnico de D2, no un efecto
  secundario opcional.

**Alternativas consideradas**:
- **Dejar las fixtures en `0` y exigir que cada test que las use pase `opening_amount=` explícito**:
  descartada — obligaría a tocar cada llamador existente de `make_cash_shift()` en los tres
  archivos, un cambio mucho más amplio que simplemente corregir el valor por defecto del propio
  fixture, sin ningún beneficio adicional (ningún test depende de que el valor sea `0`).

## D5 — Registro de la decisión de negocio (FR-008, Principio II)

**Decision**: ya resuelto antes de este documento — la decisión quedó registrada como
[A-125](../000-reconocimiento/registro-de-anomalias.md) durante la sesión de `/speckit-plan`
(confirmada explícitamente por el dueño del producto), siguiendo el mismo precedente que
[A-124](../000-reconocimiento/registro-de-anomalias.md) (spec 112). Se documenta aquí únicamente
para que la cadena de trazabilidad (Principio XII) quede completa junto a las decisiones D1-D4: no
queda ningún paso de FR-008 pendiente para `tasks.md`.
