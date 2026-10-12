---

description: "Task list for feature implementation"
---

# Tasks: Validación de saldo inicial mayor a cero al abrir caja

**Input**: Design documents from `/specs/114-validacion-saldo-inicial-caja/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/post-shifts-open.md,
contracts/cash-open-form.md, quickstart.md (todos presentes)

**Tests**: incluidas de forma liviana, siguiendo la convención ya establecida en este repo (specs
107/108) — un script autoejecutable `pos-backend/app/scripts/test_cash_opening_amount.py` (sin
pytest en este repo), un archivo de spec de componente nuevo
`cash-open.component.spec.ts` (no existía antes de esta spec) y extensiones a
`cash-session.store.spec.ts`, más la regresión obligatoria de la suite de characterization y de
las specs Vitest de `cash-register`, que esta spec promete no romper (Principio III).

**Organization**: tareas agrupadas por historia de usuario (spec.md).

## Path Conventions

`../pos-backend/app/...` (FastAPI) y `../pos-heladeria/src/app/...` (Angular) — dos repositorios
en producción, ambos sobre la rama `develop`. `pos-specs/` es este repositorio (rama `main`), donde
viven la spec y el registro de anomalías (ya actualizado con A-125, ver research.md D5 — sin tarea
pendiente aquí).

---

## Phase 1: Setup

### Ramas (Principio XIV)

- [X] T001 [P] Crear la rama `fix/113-validacion-saldo-inicial-caja` en `../pos-backend`, a partir
  de `develop`.
- [X] T002 [P] Crear la rama `fix/113-validacion-saldo-inicial-caja` en `../pos-heladeria`, a
  partir de `develop`.

---

## Phase 2: Foundational

*Ninguna — no hay infraestructura compartida que las tres historias necesiten antes de empezar
(Principio VI: cambio de una sola clase — acotar un valor existente — sin modelo de datos nuevo ni
arquitectura nueva). User Story 1 (frontend) y User Story 2 (backend) tocan archivos de repos
distintos y son independientemente implementables tras el Phase 1. La actualización de fixtures
(research.md D4) es un prerrequisito técnico interno de User Story 2 (bloquea su propio
`CheckConstraint`, no a las demás historias) y se agrupa ahí, no aquí.*

---

## Phase 3: User Story 2 — El backend rechaza la apertura de turno si el saldo inicial no es
estrictamente mayor a cero (Priority: P1) 🎯 MVP (garantía real)

**Goal**: el endpoint `POST /cash/shifts/open` responde `422` con un mensaje explícito cuando
`opening_amount` es `0`, negativo o se omite, sin crear ningún `CashShift`; y la base de datos
rechaza cualquier intento de insertar un turno con `opening_amount <= 0` fuera del endpoint, como
defensa en profundidad — sin afectar ningún turno histórico.

**Independent Test**: invocar el endpoint directamente (sin pasar por el formulario) con
`opening_amount=0` y, por separado, con un valor negativo, verificando en ambos casos que el
servidor responde `422` y que no se crea el turno; y, por separado, un `INSERT` directo con
`opening_amount <= 0` falla por el `CheckConstraint` de base de datos.

### Implementación para User Story 2

- [X] T003 [US2] En `../pos-backend/app/api/v1/cash/schemas.py:32`, quitar `ge=0` del `Field` de
  `ShiftOpen.opening_amount`: de `Field(0, ge=0, max_digits=12, decimal_places=2)` a
  `Field(0, max_digits=12, decimal_places=2)` (research.md D1 — necesario para que tanto `0` como
  los negativos lleguen al router y reciban el mismo mensaje explícito, en vez del envelope
  genérico de validación de Pydantic).
- [X] T004 [US2] En `../pos-backend/app/api/v1/cash/router.py`, función `open_shift()` (línea
  ≈68-85), agregar al comienzo, antes de construir el `CashShift`:
  ```python
  if body.opening_amount <= 0:
      raise HTTPException(
          status.HTTP_422_UNPROCESSABLE_ENTITY,
          "El saldo inicial es obligatorio y debe ser mayor a cero",
      )
  ```
  mismo patrón que `close_shift()` ya usa para "la observación es obligatoria" (FR-004/FR-005/
  FR-006; depende de T003 para que el valor negativo llegue hasta aquí).
- [X] T005 [P] [US2] En `../pos-backend/app/characterization_tests/cart_fixtures.py:406`, cambiar
  `kw.setdefault("opening_amount", Decimal("0"))` a
  `kw.setdefault("opening_amount", Decimal("100000"))` (research.md D4 — prerrequisito técnico de
  T007, no afecta ninguna aserción existente).
- [X] T006 [P] [US2] En `../pos-backend/app/characterization_tests/orders_fixtures.py:421`, mismo
  cambio que T005: `Decimal("0")` → `Decimal("100000")`.
- [X] T007 [P] [US2] En `../pos-backend/app/characterization_tests/table_sessions_fixtures.py:366`,
  mismo cambio que T005: `Decimal("0")` → `Decimal("100000")`.
- [X] T008 [US2] En `../pos-backend/app/models/cash_shift.py:44`, endurecer el `CheckConstraint`
  del modelo: `CheckConstraint("opening_amount >= 0", name="ck_cash_shift_opening_positive")` →
  `CheckConstraint("opening_amount > 0", name="ck_cash_shift_opening_positive")` (depende de
  T005-T007 ya aplicados, para que ningún characterization test rompa al insertar contra una base
  de datos real — research.md D4/D2).
- [X] T009 [US2] Crear la migración Alembic nueva en `../pos-backend/alembic/versions/` (mismo
  patrón por-esquema que `c7e2b91a4d35_084_variante_sin_nombre.py`, usando
  `app/scripts/tenant.py::for_each_tenant_schema`), con:
  - `upgrade()` por esquema: `ALTER TABLE "{schema}".cash_shifts DROP CONSTRAINT
    ck_cash_shift_opening_positive` + `ADD CONSTRAINT ck_cash_shift_opening_positive CHECK
    (opening_amount > 0) NOT VALID` (sin escanear filas existentes — FR-007/Principio VII).
  - `downgrade()` por esquema: mismo `DROP CONSTRAINT` + `ADD CONSTRAINT ... CHECK
    (opening_amount >= 0)` (sin `NOT VALID`, revierte exactamente al estado anterior).
  Ver data-model.md "Estrategia de migración"/"Estrategia de rollback" para el código completo
  (depende de T008). **Nota de implementación**: el nombre real del constraint en la base de
  datos es `ck__cash_shifts__ck_cash_shift_opening_positive` (convención de nombres de
  `app/core/models.py`), no `ck_cash_shift_opening_positive` — corregido en la migración y en
  data-model.md tras verificar contra los esquemas reales. Verificado en vivo: `alembic upgrade
  head` / `downgrade -1` / `upgrade head` aplican y revierten correctamente en los tres esquemas
  tenant existentes (`heladeria`, `skeilo`, `tenantlocal`), con guard `_has_table` para el esquema
  de scratch `tenant_default` (sin tablas base).
- [X] T010 [US2] Crear `../pos-backend/app/scripts/test_cash_opening_amount.py` (mismo patrón que
  `test_cash_net_sales.py`, spec 108 — script autoejecutable, sin pytest), cubriendo los casos 1-6
  de `contracts/post-shifts-open.md`:
  1. `opening_amount=0`, caja sin turno abierto → `422`, mensaje explícito, ningún `CashShift`
     creado.
  2. `opening_amount=-50000` → `422`, mismo mensaje, ningún `CashShift` creado.
  3. Request sin `opening_amount` en el cuerpo (cae en el default `0`) → mismo resultado que el
     caso 1.
  4. `opening_amount=50000` → `201`, `CashShift` creado con `opening_amount=50000`.
  5. `opening_amount=0.01` (válido pero mínimo) → `201` — confirma que el límite es estrictamente
     `> 0`, sin piso de negocio adicional.
  6. `INSERT`/`UPDATE` directo sobre `cash_shifts` con `opening_amount <= 0`, fuera del endpoint
     (vía `CashShift(...)` + `db.commit()`) → falla por el `CheckConstraint`
     `ck_cash_shift_opening_positive` (depende de T008; requiere una base de datos real, no el
     harness SQLite en memoria de `orders_fixtures.py`, porque SQLite no valida `CheckConstraint`
     de la misma forma — usar el mismo patrón de fixtures con Postgres que ya usa
     `test_purchase_presentation.py`, spec 107, si aplica en este repo, o documentar el caso como
     verificación manual contra Postgres si el harness actual no lo soporta).
- [X] T011 [US2] Agregar a `../pos-backend/app/scripts/test_cash_opening_amount.py` el caso 7 de
  `contracts/post-shifts-open.md`: insertar directamente un `CashShift` histórico con
  `opening_amount=0` (simulando un turno previo al despliegue) y verificar que, tras aplicar la
  migración de T009 (`NOT VALID`), esa fila sigue existiendo sin modificarse y la migración no
  falla (FR-007).
- [X] T012 [US2] Correr `./env/bin/python -m app.scripts.test_cash_opening_amount` (7/7 OK
  esperado) y `./env/bin/python -m unittest discover -s app/characterization_tests -p
  'test_*.py'` en `../pos-backend`, confirmando que ningún characterization test existente se
  rompe (depende de T003-T011). **Verificado**: 7/7 OK (incluido el caso 6 contra PostgreSQL
  real, no el harness SQLite) y 1492/1492 characterization tests en verde.

**Checkpoint**: la garantía real ya existe de forma independiente — ningún cliente HTTP, sea el
formulario o una integración directa, puede crear un turno con `opening_amount <= 0` — US2 es
desplegable por sí sola, aunque el formulario (US1) todavía no muestre ningún mensaje.

---

## Phase 4: User Story 1 — El cajero no puede abrir turno con saldo inicial en cero o vacío
(Priority: P1)

**Goal**: la pantalla de apertura de caja deshabilita el botón "Abrir caja y comenzar turno" y
muestra el mensaje "El saldo inicial debe ser mayor a cero para abrir la caja" debajo del campo,
de inmediato desde la carga de la pantalla, mientras el saldo inicial sea `0` o esté vacío —
sin esperar ninguna interacción del usuario con el campo.

**Independent Test**: abrir la pantalla de apertura, seleccionar una caja sin modificar el saldo
inicial (queda en `0`), e intentar presionar "Abrir caja y comenzar turno": el botón está
deshabilitado y no sale ninguna petición de red.

### Implementación para User Story 1

- [X] T013 [US1] En
  `../pos-heladeria/src/app/modules/cash-register/services/cash-session.store.ts`, agregar el
  `computed` nuevo (mismo patrón que `movimientoDisabled`/`arqueoDisabled`, líneas ≈195/227):
  ```ts
  readonly aperturaDisabled = computed(
    () => this.isSubmitting() || !this.selectedRegisterId() || this.openingAmount() <= 0,
  );
  ```
  (no requiere ningún signal ni estado nuevo — `openingAmount` ya existe y ya colapsa "vacío" a
  `0`, research.md D3).
- [X] T014 [US1] En
  `../pos-heladeria/src/app/modules/cash-register/components/cash-open.component.ts`:
  - cambiar `[disabled]` del botón "Abrir caja y comenzar turno" de
    `store.isSubmitting() || !store.selectedRegisterId()` a `store.aperturaDisabled()`.
  - agregar `[invalid]="store.openingAmount() <= 0"` a `<app-money-input>`.
  - agregar debajo el párrafo condicional (mismo patrón que
    `change-password.component.ts:71-74`):
    ```html
    @if (store.openingAmount() <= 0) {
      <p class="text-red-500 text-xs mt-1">El saldo inicial debe ser mayor a cero para abrir la caja</p>
    }
    ```
    (depende de T013).
- [X] T015 [P] [US1] Extender
  `../pos-heladeria/src/app/modules/cash-register/services/cash-session.store.spec.ts` con los
  casos de `contracts/cash-open-form.md`:
  1. `openingAmount()` en `0` (valor inicial, sin interacción) → `aperturaDisabled()` es `true`.
  2. Tras `openingAmount.set(0)` luego de haber tenido otro valor (simula borrar el campo) →
     `aperturaDisabled()` sigue `true`.
  3. `openingAmount.set(50000)` con caja seleccionada → `aperturaDisabled()` es `false`.
  5. `openingAmount.set(50000)` sin caja seleccionada (`selectedRegisterId` vacío) →
     `aperturaDisabled()` sigue `true` (la condición existente no se relaja).
  (depende de T013).
- [X] T016 [US1] Crear
  `../pos-heladeria/src/app/modules/cash-register/components/cash-open.component.spec.ts` (archivo
  nuevo — no existe hoy), con los casos 1-2 de `contracts/cash-open-form.md`:
  1. Render inicial con una caja seleccionada, sin tocar el campo de saldo → el párrafo del
     mensaje es visible en el DOM y el botón tiene el atributo `disabled`.
  2. Tras escribir y luego borrar el campo de saldo (vía el `(ngModelChange)` del
     `app-money-input`) → mismo resultado que el caso 1.
  (depende de T014).
- [X] T017 [US1] Correr `npx ng test --watch=false
  --include='src/app/modules/cash-register/**/*.spec.ts'` en `../pos-heladeria`, confirmando que
  ningún spec existente de `cash-register` se rompe y que los casos nuevos de T015/T016 pasan
  (depende de T013-T016). **Verificado**: 7 archivos / 30 tests, todos en verde.

**Checkpoint**: el camino de UI ya existe de forma independiente — ningún clic en el botón
deshabilitado dispara una petición mientras el saldo sea `0` o esté vacío (SC-001) — US1 es
desplegable por sí sola, en conjunto con la garantía real de US2.

---

## Phase 5: User Story 3 — Apertura exitosa con un saldo inicial válido (Priority: P2)

**Goal**: confirmar que la nueva restricción no introduce fricción adicional al camino feliz —
un cajero que ingresa un saldo inicial mayor a cero abre el turno con normalidad, exactamente
como ocurre hoy.

**Independent Test**: seleccionar una caja, ingresar un monto mayor a cero (p. ej. `50000`) y
presionar "Abrir caja y comenzar turno" → el turno se abre y se navega a la terminal de
ventas/mesas, sin fricción adicional.

### Implementación para User Story 3

- [X] T018 [US3] Agregar a
  `../pos-heladeria/src/app/modules/cash-register/components/cash-open.component.spec.ts`
  (creado en T016) el caso 4 de `contracts/cash-open-form.md`: caja seleccionada + saldo inicial
  válido (`50000`) + clic en "Abrir caja y comenzar turno" → se invoca `store.abrirCaja()` (spy),
  confirmando que el botón ya habilitado efectivamente dispara la apertura (depende de T016).
- [X] T019 [US3] Confirmar (lectura de
  `../pos-heladeria/src/app/modules/cash-register/services/cash-session.store.ts:442-457`,
  `abrirCaja()`) que la lógica interna no cambió más allá de ser ahora físicamente imposible
  invocarla con `openingAmount() <= 0` desde el botón — sigue llamando
  `this.api.openShift(regId, Number(this.openingAmount()) || 0)` igual que hoy (contracts/
  cash-open-form.md, "Qué NO cambia"; sin tarea de código, solo verificación).
- [X] T020 [US3] Confirmar que los casos 4 y 5 de `contracts/post-shifts-open.md`
  (`opening_amount=50000` → `201`; `opening_amount=0.01` → `201`) ya quedaron cubiertos en
  `../pos-backend/app/scripts/test_cash_opening_amount.py` (T010) — si al revisar el script
  creado en US2 falta alguno de los dos, añadirlo aquí (depende de T010).
- [X] T021 [US3] Correr de nuevo `npx ng test --watch=false
  --include='src/app/modules/cash-register/**/*.spec.ts'` en `../pos-heladeria` tras T018,
  confirmando que la suite completa de `cash-register` sigue en verde (depende de T018).
  **Verificado**: 7 archivos / 31 tests, todos en verde.
- [ ] T022 [US3] Verificación manual (`ng serve` + backend nativo con `uvicorn`): seleccionar una
  caja, ingresar `50000`, hacer clic en "Abrir caja y comenzar turno" → el turno se abre y navega
  a la terminal de ventas/mesas (quickstart.md Escenario 3, pasos 3-4) — queda pendiente si el
  entorno de ejecución no tiene navegador/GUI disponible.

**Checkpoint**: las tres historias completas — el camino feliz sigue intacto (US3), sobre la base
de la guarda de UI (US1) y la garantía real del servidor (US2).

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T023 Ejecutar `quickstart.md` completo de punta a punta: los Escenarios 4-8 (backend, vía
  `curl` o el script de T010/T011) y el Escenario 1-3 (frontend, vía `ng serve`) — marcar como
  pendiente cualquier paso manual si el entorno no tiene navegador/GUI disponible (depende de
  T012, T022).

  **Resultado**: Escenarios 4-8 (backend) verificados — equivalentes exactos cubiertos por
  `test_cash_opening_amount.py` (T010/T011, 7/7 OK: cero, negativo, omitido, válido, mínimo
  0.01, `CheckConstraint` vía INSERT directo, turno histórico no afectado por la migración) más
  la suite completa de characterization tests (1492/1492 OK). Escenarios 1-3 (frontend,
  navegador) **pendientes**: no se dispone de credenciales de un usuario cajero/admin del tenant
  de desarrollo para iniciar sesión real en `ng serve` (puerto 4200, ya corriendo) — igual que
  T022.
- [X] T024 [P] Confirmar, releyendo `../pos-backend/app/characterization_tests/test_cash_
  timezone.py` (líneas 25 y 36), que sigue sin verse afectado por T003/T008 — construye un
  `ShiftResponse` vía `model_construct()`, sin pasar por `ShiftOpen` ni por la base de datos
  (research.md D4; verificación de lectura, sin cambio de código esperado).
- [X] T025 Revisar y corregir que ningún otro endpoint o script del módulo de caja construya o
  solicite un `CashShift` con `opening_amount` en `0` que ahora violaría el `CheckConstraint` de
  T008 o sería rechazado por el router de T004 (grep `opening_amount` en `../pos-backend/app`,
  fuera de `characterization_tests/` y de `open_shift()` — más amplio que solo `grep CashShift(`,
  porque algunos sitios llaman al endpoint en vez de construir el modelo directamente). Ya se
  identificaron 4 sitios concretos que requieren este cambio (research.md D4 solo cubrió
  `app/characterization_tests/`, no el resto de `app/scripts/`):
  - `app/scripts/test_split_blindaje.py:92-94`: `CashShift(..., opening_amount=Decimal("0"), ...)`
    → cambiar a un valor positivo (p. ej. `Decimal("100000")`).
  - `app/scripts/test_facturacion.py:76-78`: mismo cambio que el anterior.
  - `app/scripts/test_cash_net_sales.py:144`: `make_cash_shift(db, opening_amount=Decimal("0"))`
    dentro de `test_venta_exacta_sin_cambio_no_cambia()` — este override explícito no se corrige
    con el cambio de default de T005-T007; cambiar el argumento a un valor positivo (el test no
    hace ninguna aserción sobre `opening_amount`, solo sobre el total de la venta).
  - `app/scripts/e2e_qr_flow.py:298`: `api("POST", "/api/v1/cash/shifts/open", json={
    "cash_register_id": reg["id"], "opening_amount": "0.00"})` — tras T004 este request recibirá
    `422` en vez de `201`; cambiar el valor a uno positivo (p. ej. `"50000.00"`) para que el flujo
    e2e siga abriendo el turno con normalidad.
  Correr los 4 scripts modificados tras aplicar T008/T009, confirmando que ya no fallan (depende
  de T008, T009).

  **Resultado**: los 4 cambios de `opening_amount` son correctos y necesarios — confirmado
  revirtiendo temporalmente (`git stash`) y viendo que, sin ellos, `test_split_blindaje.py` falla
  exactamente en el `INSERT` de `cash_shifts` por el `CheckConstraint` de T008 (la migración ya
  está aplicada contra la base de datos real). Con el cambio aplicado:
  - `test_facturacion.py`: TODO OK (11/11 verificaciones).
  - `test_cash_net_sales.py`: 5/5 pruebas pasaron.
  - `test_split_blindaje.py` y `e2e_qr_flow.py`: **bloqueados por un bug preexistente, no
    relacionado con esta spec** — ambos crean un `ProductVariant` sin `presentation_id`, columna
    que la spec 084 (anterior a esta) volvió `NOT NULL`; el fallo ocurre en el `INSERT` de
    `product_variants`, antes de llegar siquiera a la línea de `opening_amount` que corregí. El
    mismo patrón (`ProductVariant(...)` sin `presentation_id`) aparece en al menos 5 scripts más
    de `app/scripts/` (`test_cancel_inventory.py`, `test_receta_obligatoria.py`,
    `test_variant_option_groups.py`, entre otros) — es un problema preexistente y amplio, fuera
    del alcance de "cambio acotado a una sola clase" de esta spec (Principio V/VI). No se corrige
    aquí; queda para registrar aparte si el usuario lo pide.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias — puede empezar de inmediato. T001/T002 (ramas) bloquean
  tocar código en cada repo respectivo (Principio XIV). La decisión de negocio (A-125) ya está
  registrada desde la sesión de planificación — no hay Puerta G1 pendiente aquí (a diferencia de
  la spec 108).
- **Foundational (Phase 2)**: vacía — no bloquea nada.
- **User Stories (Phase 3-5)**: todas dependen de Phase 1 completa (T001-T002).
  - **US2** (T003-T012, backend): no depende de US1 ni de US3 en código — es la garantía real y
    puede desplegarse sola.
  - **US1** (T013-T017, frontend): no depende de US2 en código (es un `computed` puro sobre un
    signal ya existente) — solo depende de Phase 1.
  - **US3** (T018-T022): depende de T016 (archivo `cash-open.component.spec.ts` creado en US1) y
    de T010 (script backend creado en US2) — es la confirmación de que ambas guardas conviven sin
    fricción en el camino feliz, por eso se implementa último aunque su prioridad (P2) sea menor.
- **Polish (Phase 6)**: depende de que las tres historias estén completas.

### Parallel Opportunities

- T001 y T002 en paralelo (repos distintos).
- T005, T006 y T007 en paralelo entre sí (archivos distintos, mismo cambio).
- US2 (Phase 3) y US1 (Phase 4) en paralelo entre sí tras Phase 1 (repos y archivos distintos, sin
  dependencia de código entre ellas) — solo US3 debe esperar a que ambas terminen.
- T015 en paralelo con T014 (archivos distintos: store vs. componente), aunque T015 depende del
  `computed` de T013 para tener sentido.
- T024 en paralelo con cualquier otra tarea de Polish (solo lectura, sin tocar archivos).

---

## Parallel Example: User Story 2

```bash
# T005, T006 y T007 tocan archivos distintos, mismo cambio de fixture:
Task: "Actualizar default de opening_amount en cart_fixtures.py"
Task: "Actualizar default de opening_amount en orders_fixtures.py"
Task: "Actualizar default de opening_amount en table_sessions_fixtures.py"
```

---

## Implementation Strategy

### MVP First (User Story 2 Only)

1. Completar Phase 1 (ramas en ambos repos).
2. Completar Phase 3 (User Story 2): el servidor ya rechaza cualquier intento de abrir turno con
   `opening_amount <= 0`, sin importar el origen de la petición.
3. **Detenerse y validar**: correr T012 de forma independiente.
4. Esto ya cierra la garantía real exigida por la spec, aunque el formulario (US1) todavía no
   muestre ningún mensaje al cajero — un cajero apurado seguiría viendo el error genérico del
   servidor en vez de la guía en pantalla.

### Incremental Delivery

1. Setup (Phase 1) → ramas creadas en ambos repos.
2. User Story 2 → el backend rechaza `opening_amount <= 0` en las tres capas (schema, router,
   `CheckConstraint`) → validar independientemente (MVP técnico).
3. User Story 1 → el formulario guía al cajero antes de que la petición siquiera se envíe →
   validar independientemente (MVP de experiencia).
4. User Story 3 → confirmar que el camino feliz sigue sin fricción → validar independientemente.
5. Polish → `quickstart.md` de punta a punta.

### Parallel Team Strategy

Con dos desarrolladores: uno completa US2 (backend) mientras el otro completa US1 (frontend) en
paralelo tras Phase 1, dado que no comparten código ni archivos; ambos convergen en US3 para la
verificación conjunta del camino feliz.

## Notes

- Por ser un cambio acotado a una sola clase (Principio VI), no se espera trabajo en paralelo
  extenso — el orden sugerido arriba (US2 → US1 → US3) prioriza primero la garantía real
  (servidor) sobre la guía de UI, aunque ambas son P1; un solo desarrollador puede alternar entre
  ambas sin bloqueo real, dado que no comparten archivos.
- Los commits se hacen solo bajo pedido explícito del usuario, en unidades pequeñas y lógicas
  (p. ej. uno para schema+router del backend, otro para la migración, otro para los fixtures de
  test, otro para el store+componente del frontend), en inglés, sin ninguna marca de autoría de IA
  (Principio XV) — esto aplica a los commits dentro de `pos-backend` y `pos-heladeria`, no a este
  repositorio de specs.
- T010/T011 (script de test backend) asumen el mismo harness que `test_cash_net_sales.py` —
  revisar si el caso 6 (`CheckConstraint` vía `INSERT` directo) requiere una base de datos
  Postgres real en vez del harness SQLite en memoria; si el repo no tiene ese harness disponible
  hoy, documentarlo como verificación manual contra un esquema de prueba en Postgres.
