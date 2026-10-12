# Tasks: Cobro de pedido con múltiples métodos de pago

**Input**: Design documents from `/specs/112-fix-cobro-pago-mixto/`
**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/api.md](./contracts/api.md), [quickstart.md](./quickstart.md)

**Tests**: incluidos — el Principio X de la [Constitución](../../.specify/memory/constitution.md)
exige verificación obligatoria, y la convención del repositorio (characterization tests + scripts
en `pos-backend`, specs Vitest en `pos-heladeria`) ya cubre cada spec anterior de esta forma.

**Organización**: por historia de usuario (spec.md). Casi todo el trabajo real vive en
`pos-heladeria` (`payment-draft.util.ts` + `PaymentInputComponent`); `pos-backend` solo gana un
tope de validación — ver `research.md` D1.

## Path Conventions

Repositorios hermanos, fuera de `pos-specs` (rutas relativas a `pos-specs/`):
- `../pos-backend/app/...` (FastAPI)
- `../pos-heladeria/src/app/...` (Angular)

---

## Phase 1: Setup

**Purpose**: crear las ramas de trabajo en ambos repos de código antes de tocar nada (Principio
XIV de la Constitución) — `pos-specs` ya trabaja en su propia rama `112-fix-cobro-pago-mixto`.

- [X] T001 Crear la rama `fix/112-mixed-payment-checkout` en `../pos-backend` desde `develop` (Principio XIV)
- [X] T002 Crear la rama `fix/112-mixed-payment-checkout` en `../pos-heladeria` desde `develop` (Principio XIV)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: el tope de 3 líneas en el servidor y el tipo/funciones puras generalizadas del
borrador de pago — todas las historias de usuario dependen de esto.

**⚠️ CRITICAL**: ninguna historia de usuario puede empezar hasta que esta fase esté completa.

- [X] T003 [P] Añadir `max_length=3` a `PayIn.payments` y `CheckoutAndSendIn.payments` en `../pos-backend/app/api/v1/orders/schemas.py` (research.md D7)
- [X] T004 [P] Añadir `max_length=3` a `SaleCreate.payments` en `../pos-backend/app/api/v1/sales/schemas.py` (research.md D7)
- [X] T005 [P] Crear `../pos-backend/app/scripts/test_mixed_payment_checkout.py` (mismo patrón que `test_cash_net_sales.py`, spec 108) con un primer caso: 4 líneas de pago rechazadas con 422 en `POST /orders/{id}/pay` (depende de T003) — 7 pruebas, todas en verde
- [X] T006 Reemplazar la interfaz `PaymentDraft` de una sola línea por `PaymentLineDraft { methodId, amount, reference }` y `PaymentDraft = PaymentLineDraft[]` en `../pos-heladeria/src/app/modules/tables/services/payment-draft.util.ts` (data-model.md, generaliza spec 046) — **desviación del diseño original**: un solo campo `amount` por línea (no `assigned`/`receivedCash` separados) resultó suficiente y evita invalidar retroactivamente una línea ya fijada cuando una línea en efectivo posterior sobrepaga (ver data-model.md "Orden de captura"); `data-model.md` actualizado para reflejarlo
- [X] T007 Implementar `emptyPaymentDraft()` (devuelve `[emptyLine]`, 1 elemento), `assignedOf`/`assignedTotal(draft,total,methods)`, `missingAmount(draft,total,methods)`, `changeDue(draft,i,total,methods)` y `paymentLines(draft, methods)` en `payment-draft.util.ts` (depende de T006)
- [X] T008 Implementar `paymentIssue(draft, total, methods)` con el orden de prioridad (método/monto vacío → línea no efectivo supera lo que las líneas ANTERIORES ya asignaron → "Faltan $X por asignar") en `payment-draft.util.ts` — la rama "Sobran" se descartó por quedar matemáticamente inalcanzable dado el chequeo anterior (demostrado en data-model.md), no se deja como código muerto
- [X] T009 [P] Reescribir `../pos-heladeria/src/app/modules/tables/services/payment-draft.util.spec.ts` para las funciones de N líneas, retirando las aserciones de spec 046 que exigían un único método (citado `A-124`) — 20 tests, todos en verde

**Checkpoint**: tipos, funciones puras y tope de servidor listos — las historias de usuario pueden empezar.

---

## Phase 3: User Story 1 - Cobrar un pedido repartiendo el pago entre varios métodos (Priority: P1) 🎯 MVP

**Goal**: el cajero puede agregar hasta 3 líneas de pago, asignarles montos, y cobrar solo cuando
la suma coincide exactamente con el total — quedan N pagos registrados juntos.

**Independent Test**: abrir el panel de un pedido con total conocido, asignar Efectivo +
Transferencia sumando el total, pulsar "Cobrar" y verificar 2 pagos persistidos que suman el total.

### Implementation for User Story 1

- [X] T010 [US1] Extender el template de `PaymentInputComponent` para renderizar un bloque por cada `PaymentLineDraft` (selector de método + importe) en `../pos-heladeria/src/app/modules/tables/components/payment-input.component.ts` (depende de Foundational)
- [X] T011 [US1] Añadir botón "Agregar otro método" que agrega una línea precargada con el saldo pendiente (`total − assignedTotal`), deshabilitado al llegar a 3 líneas (RN3/FR-004), en `payment-input.component.ts` (depende de T010)
- [X] T012 [US1] Añadir control "Eliminar línea" por línea (oculto si solo queda 1) que la quita y recalcula el saldo pendiente de inmediato (FR-010), en `payment-input.component.ts` (depende de T010)
- [X] T013 [US1] Mostrar el mensaje de `paymentIssue()` y deshabilitar "Cobrar" en consecuencia, igual que el binding actual de una sola línea, en `payment-input.component.ts` (depende de T008, T011, T012)
- [X] T014 [US1] [P] Actualizar `../pos-heladeria/src/app/modules/tables/components/payment-input.component.spec.ts`: agregar línea, eliminar línea, suma exacta habilita "Cobrar", tope de 3 líneas — retirando las aserciones de spec 046/057 (citado `A-124`); también se actualizaron `pos-checkout-panel.component.spec.ts` y `session-bill-panel.component.spec.ts`, los otros dos call sites de `<app-payment-input>`, que no estaban listados aparte en este plan
- [X] T015 [US1] [P] En `../pos-backend/app/scripts/test_mixed_payment_checkout.py`: `build_sale` con 2 `PaymentIn` (efectivo + transferencia) crea 2 filas `Payment` que suman el total, repetido para `order_type` Mesa/Para llevar/Domicilio (depende de T005)

**Checkpoint**: pago mixto funciona de punta a punta para los tres tipos de pedido.

---

## Phase 4: User Story 2 - Cobrar con un solo método sin pasos adicionales (Priority: P1)

**Goal**: el camino de un único método no gana pasos ni fricción respecto al comportamiento actual.

**Independent Test**: elegir un método sin pulsar "Agregar otro método"; el importe se precarga con
el total y "Cobrar" registra un único pago, con el mismo número de pasos que antes del cambio.

### Implementation for User Story 2

- [X] T016 [US2] Confirmar que `emptyPaymentDraft()` (T007) y el `ngOnChanges` de `PaymentInputComponent` siguen partiendo de exactamente 1 línea vacía precargada con el total al elegir método, sin ningún paso nuevo — verificado con tests nuevos en `payment-input.component.spec.ts` ("parte de una sola línea...", "eligiendo un único método..."), sin requerir ajuste de código
- [X] T017 [US2] [P] Test de regresión ya cubierto por las pruebas existentes de `../pos-heladeria/src/app/modules/tables/components/pos-checkout-panel.component.spec.ts` (p. ej. "FR-005: $8.000 en efectivo → sin faltante..."), actualizadas para el nuevo diseño sin tocar su intención original
- [X] T018 [US2] [P] Test de regresión en `../pos-backend/app/scripts/test_mixed_payment_checkout.py::test_un_solo_pago_sigue_creando_una_fila`: un cobro con una sola línea de pago sigue creando exactamente 1 fila `Payment`

**Checkpoint**: el flujo de un solo método queda verificado sin regresiones (SC-003).

---

## Phase 5: User Story 3 - Calcular el vuelto solo sobre la porción en efectivo (Priority: P2)

**Goal**: solo la línea en efectivo admite "con cuánto paga" > asignado, y el vuelto/cierre de caja
se calculan sobre esa porción neta, no sobre lo recibido.

**Independent Test**: pago mixto con Transferencia + Efectivo; escribir en "Con cuánto paga" de la
línea de efectivo un monto mayor al asignado; ver "Cambio: $X"; el cierre de caja registra el neto.

### Implementation for User Story 3

- [X] T019 [US3] En `payment-input.component.ts`: el importe es editable en toda línea (decisión documentada en data-model.md: se retiró el bloqueo de spec 057 para no efectivo, porque ahora hace falta poder editarlo para armar un pago mixto); mostrar "Cambio: $[changeDue]" por línea de efectivo cuando `> 0` (depende de T010, T007)
- [X] T020 [US3] Verificado: el mensaje de `paymentIssue()` para una línea no efectivo que supera el saldo pendiente usa el nombre real del método (`methodName()`) en `payment-draft.util.ts` (FR-007)
- [X] T021 [US3] [P] Test en `payment-draft.util.spec.ts` ("el sobrepago en efectivo se devuelve como vuelto sin afectar la validación") y `payment-input.component.spec.ts` ("muestra el cambio solo en la línea de efectivo..."): el vuelto se calcula aislado por línea de efectivo, sin afectar ni verse afectado por las demás líneas
- [X] T022 [US3] [P] Extender `../pos-backend/app/scripts/test_cash_net_sales.py::test_pago_mixto_neta_el_cambio_solo_en_la_fila_cash` con un caso de venta con 2 pagos (transferencia exacta $6.000 + efectivo recibiendo $10.000 para $8.000 asignados) y verificar que `sales_by_method` para `cash` refleja $8.000 (neto), no $10.000

**Checkpoint**: el vuelto y el neteo de caja quedan verificados para pago mixto (FR-006/FR-008).

---

## Phase 6: User Story 4 - Ver el desglose por método en el cierre de caja y el comprobante (Priority: P2)

**Goal**: comprobante y cierre de caja muestran el desglose por método para cobros de 2-3 líneas
— sin cambios de código esperados (research.md D1), solo cobertura de verificación nueva.

**Independent Test**: cobrar un pedido con pago mixto; el comprobante y el cierre de caja del turno
muestran los montos por método, sumando el total cobrado.

### Implementation for User Story 4

- [X] T023 [US4] [P] Nuevo/extendido spec en `../pos-heladeria/src/app/modules/tables/services/receipt.util.spec.ts`: una venta con 2 `payments` renderiza una fila por método en el comprobante, y `saleToReceipt` convierte las N líneas de `sale.payments` 1:1 (confirma D1, sin cambio de código)
- [X] T024 [US4] [P] Extender `../pos-backend/app/scripts/test_cash_net_sales.py::test_varias_ventas_con_pago_mixto_suman_correctamente_por_metodo`: dos ventas del mismo turno, cada una con 2 líneas de pago, `sales_by_method` suma correctamente por método a través de ambas (13.000 efectivo, 10.000 transferencia)

**Checkpoint**: FR-019/FR-020 verificados sin necesidad de cambios de código.

---

## Phase 7: User Story 5 - Mantener el momento correcto de cobro en Domicilio y la liberación de Mesa (Priority: P3)

**Goal**: no regresión — Domicilio sigue "Sin cobrar" hasta el pago (sin importar su estado
operativo) y Mesa sigue liberándose al cobrar, ahora también con pago mixto (research.md D6).

**Independent Test**: Domicilio sin pago registrado sigue "Sin cobrar" y fuera del cierre de caja;
Mesa cobrada con pago mixto libera la mesa y baja el contador de "Ocupadas".

### Implementation for User Story 5

- [X] T025 [US5] [P] Test de regresión en `../pos-backend/app/characterization_tests/test_orders_service.py::test_order_has_sale_false_en_delivery_sin_sale_sin_importar_el_avance_de_cocina`: un pedido de Domicilio sin `Sale` asociada sigue sin pago sin importar el avance de `estado_cocina` de sus ítems
- [X] T026 [US5] [P] En `../pos-backend/app/scripts/test_mixed_payment_checkout.py::test_release_table_tras_pago_mixto`: `release_table` sigue funcionando tras cobrar un pedido de Mesa con 2 líneas de pago
- [X] T027 [US5] [P] Revisado `pos-terminal.store.spec.ts`: `deriveTableStatus`/`tableCounts` ya son funciones puras que solo miran `table.status` y el estado de los pedidos -- nunca cuántas líneas de pago tuvo el cobro -- y ya están cubiertas con `[]`/`'libre'` → `'libre'` y con el conteo de "Ocupadas". No se agrega un test redundante que repita esos mismos casos con una etiqueta de "pago mixto": la garantía real de que la mesa se libera tras un cobro mixto es la de T026 (`release_table`, que es quien decide `table.status` en el backend), no una función de derivación de UI que no sabe que el pago fue mixto

**Checkpoint**: FR-017/FR-018/SC-004/SC-005 verificados sin cambios de código en estos puntos.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: cierre de la spec — ejecución completa de las suites y de la guía de validación
manual, y cierre del registro de la decisión de negocio.

- [ ] T028 Ejecutar manualmente los 8 escenarios de `quickstart.md` contra `pos-backend` + `pos-heladeria` corriendo localmente — pendiente: requiere levantar ambos servidores y un tenant de prueba con métodos de pago reales, fuera del alcance de esta sesión no interactiva; los 7+7 casos de los scripts nuevos y los specs de Angular ya ejercitan la misma lógica de extremo a extremo (sin UI real)
- [X] T029 Corrido `cd ../pos-backend && ./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`: 1490 OK (1489 antes de esta spec + el test nuevo de Domicilio/T025), sin regresiones
- [X] T030 Corrido `cd ../pos-heladeria && npx ng test --watch=false` (suite completa, no solo `tables/`): mismos 6 archivos / 10 tests de la baseline conocida (`app.spec`, `auth.service`, `menu.service`, `tenant.service`, `pos-checkout-panel` T032, `pos-order-panel` ×2) — 1622 OK (1620 + los 2 tests nuevos de `receipt.util.spec.ts`), sin regresiones
- [ ] T031 Al mergear, actualizar el "Estado" de `A-124` en `../pos-specs/specs/000-reconocimiento/registro-de-anomalias.md` de "REGISTRADA, pendiente de plan técnico" a "IMPLEMENTADA", citando las PRs de `pos-backend`/`pos-heladeria` (Principio II) — pendiente: solo puede hacerse una vez existan PRs reales abiertas/mergeadas

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias — ramas de ambos repos, puede empezar de inmediato
- **Foundational (Phase 2)**: depende de Setup — BLOQUEA todas las historias de usuario
- **User Stories (Phase 3-7)**: todas dependen de Foundational; pueden avanzar en paralelo o en
  orden de prioridad (US1 → US2 → US3 → US4 → US5); US2-US5 son principalmente verificación de
  no-regresión y no tienen dependencia de código entre sí ni con US1 más allá de Foundational
- **Polish (Phase 8)**: depende de que las historias que se vayan a entregar estén completas

### Within Each User Story

- US1: T010-T013 (componente) antes de T014 (su propio test); T015 es independiente (backend)
- US3 depende de que T007/T010 (Foundational/US1) ya existan, pero no de que US1 esté "cerrado"
- US4/US5 son casi enteramente verificación: pueden ejecutarse en cualquier momento después de
  Foundational, incluso en paralelo con US1-US3, porque confirman comportamiento que **no cambia**

### Parallel Opportunities

- T003, T004, T005 (Foundational, backend) en paralelo entre sí
- T009 (Foundational) después de T006-T008 (secuenciales, mismo archivo)
- T014, T015 (US1) en paralelo (archivos distintos: frontend spec vs. script backend)
- Las fases 4 a 7 completas (US2-US5) pueden trabajarse en paralelo entre sí y respecto a la fase 3
  (US1), una vez cerrada Foundational — ningún archivo se comparte entre ellas salvo los specs que
  ya tocó Foundational

---

## Parallel Example: Foundational + User Story 1

```bash
# Backend, en paralelo (Foundational):
Task: "Añadir max_length=3 a PayIn.payments y CheckoutAndSendIn.payments en ../pos-backend/app/api/v1/orders/schemas.py"
Task: "Añadir max_length=3 a SaleCreate.payments en ../pos-backend/app/api/v1/sales/schemas.py"

# Una vez cerrado Foundational, en paralelo (US1):
Task: "Actualizar payment-input.component.spec.ts para N líneas"
Task: "Agregar caso de 2 pagos en test_mixed_payment_checkout.py"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Completar Phase 1 (ramas) y Phase 2 (tope de servidor + `payment-draft.util.ts` generalizado)
2. Completar Phase 3 (User Story 1) — pago mixto de punta a punta en los tres tipos de pedido
3. **Validar de forma independiente** con el Escenario 1 de `quickstart.md`
4. Esto ya resuelve el problema reportado (cierre de caja con datos falsos)

### Incremental Delivery

1. Setup + Foundational → base lista
2. US1 → pago mixto funcional → demo (MVP)
3. US2 → confirma que el caso frecuente (un solo método) no perdió velocidad
4. US3 → vuelto correcto en pago mixto, caja neta
5. US4/US5 → verificación de que nada más se rompió (comprobante, cierre de caja, Domicilio, Mesa)
6. Polish → suites completas + cierre del registro de la decisión de negocio (`A-124`)
