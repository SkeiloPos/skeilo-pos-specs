---

description: "Task list for feature implementation"
---

# Tasks: Ventas en Efectivo por Valor Neto en el Resumen de Caja

**Input**: Design documents from `/specs/108-ventas-efectivo-neto-caja/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/api.md,
quickstart.md (todos presentes)

**Tests**: incluidas de forma liviana — un script autoejecutable
`pos-backend/app/scripts/test_cash_net_sales.py` (sin pytest en este repo, mismo patrón que la
spec 107), más la regresión obligatoria de la suite de characterization y de las specs Vitest de
`cash-register`, que esta spec promete no romper.

**Organization**: tareas agrupadas por historia de usuario (spec.md).

## Path Conventions

`../pos-backend/app/...` (FastAPI) y `../pos-heladeria/src/app/...` (Angular) — dos repositorios
en producción, ambos sobre la rama `develop`. `pos-specs/` es este repositorio (rama
`fix/108-ventas-efectivo-neto-caja`), donde viven la spec y el registro de anomalías.

---

## Phase 1: Setup

### Puerta G1 — Registro de anomalías (bloquea escribir código, Principio II)

- [X] T001 Escribir la entrada **A-122** en
  `pos-specs/specs/000-reconocimiento/registro-de-anomalias.md`: la tarjeta "Ventas Efectivo" del
  resumen de caja deja de mostrar el efectivo bruto recibido en mano y pasa a mostrar el valor neto
  facturado en efectivo, y el texto del banner "Efectivo esperado en caja" deja de mencionar
  "cambio entregado" como término de la fórmula — clasificación DECISIÓN, origen FR-001/FR-002/
  FR-005 de esta spec, con la evidencia de
  `pos-backend/app/api/v1/cash/service.py` (líneas ≈156-168, fila `cash` de `sales_by_method`) y
  `pos-heladeria/src/app/modules/cash-register/components/cash-dashboard.component.ts:42` (texto
  del banner). Aclarar explícitamente que el valor de `expected`/Efectivo Esperado NO cambia
  (research.md D3) — es un cambio de qué se muestra, no de cuánto da el arqueo.

### Ramas (Principio XIV)

- [X] T002 [P] Crear la rama `fix/108-ventas-efectivo-neto-caja` en `../pos-backend`, a partir de
  `develop`.
- [X] T003 [P] Crear la rama `fix/108-ventas-efectivo-neto-caja` en `../pos-heladeria`, a partir de
  `develop`.

---

## Phase 2: Foundational

*Ninguna — no hay infraestructura compartida que las tres historias necesiten antes de empezar
(Principio VI: cambio de una sola clase, sin modelo de datos ni arquitectura nueva). Cada historia
toca archivos distintos y es independientemente implementable tras el Phase 1.*

---

## Phase 3: User Story 1 — Ver el valor neto real en la tarjeta Ventas Efectivo (Priority: P1) 🎯 MVP

**Goal**: la tarjeta "Ventas Efectivo" del resumen de caja muestra la suma de los valores netos de
las facturas cobradas en efectivo, no el efectivo bruto recibido en mano.

**Independent Test**: turno con Factura 25 = $17.000 (pago exacto) y Factura 23 = $28.000
recibiendo $31.000 ($3.000 de cambio) → la tarjeta "Ventas Efectivo" muestra $45.000, no $48.000.

### Implementación para User Story 1

- [X] T004 [US1] En `../pos-backend/app/api/v1/cash/service.py`, función `reconcile()`: la fila de
  `sales_by_method` cuyo `method_type == "cash"` pasa a reportar `total = ventas_efectivo` (el
  valor neto ya calculado unas líneas más abajo) en vez del bruto `by_type["cash"]` — mover el
  cálculo de `ventas_efectivo`/`change_total` antes de construir `sales_by_method`, o sobreescribir
  la fila `cash` después de calcularlo; sin tocar `count` ni ninguna otra fila. `expected` y
  `difference` no cambian (research.md D1/D3).
- [X] T005 [P] [US1] En `../pos-backend/app/api/v1/cash/schemas.py`, actualizar los comentarios de
  `SalesByMethod`/`ReconciliationResponse` (líneas ≈100-104): ya no hace falta aclarar que las
  filas de `sales_by_method` son "brutas" — la fila `cash` ahora coincide con `ventas_efectivo`.
- [X] T006 [US1] Crear `../pos-backend/app/scripts/test_cash_net_sales.py` (mismo patrón que
  `test_purchase_presentation.py` de la spec 107) con los casos 1, 2, 4 y 5 de `quickstart.md` §1:
  turno con dos facturas en efectivo (una con cambio, una exacta) → `sales_by_method[cash].total
  == 45000`; turno sin ventas en efectivo → `== 0`; invariante
  `sales_by_method[cash].total == ventas_efectivo == cash_sales`; venta exacta sin cambio no
  cambia respecto al comportamiento anterior (depende de T004). Incluyó también el caso 3 de T010
  (ver nota ahí) — no requiere Postgres real: corre sobre el harness SQLite-en-memoria de
  `orders_fixtures.py`, con la tabla `cash_movements` añadida al vuelo.
- [X] T007 [US1] Correr `./env/bin/python -m app.scripts.test_cash_net_sales` (5/5 OK) y
  `./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'` en
  `../pos-backend`; **1477 OK, 0 fallas** (el baseline de referencia era 1290 el 2026-10-03; el
  repositorio creció con las specs 106/107 desde entonces, y sigue sin ninguna falla atribuible a
  este hotfix).
- [X] T008 [US1] Verificado por lectura de código (sin navegador disponible en este entorno para
  `ng serve`): `CashSessionStore.mapVentasPorMetodo` (`cash-session.store.ts:39-46`) solo convierte
  `sales_by_method` tal cual llega del backend, sin lógica propia — confirma research.md D1: la
  tarjeta "Ventas Efectivo" del dashboard queda neta sin ningún cambio de código en el frontend.

**Checkpoint**: la tarjeta "Ventas Efectivo" es correcta de forma independiente — US1 es
desplegable por sí sola, aunque el banner (US2) todavía diga "− cambio entregado".

---

## Phase 4: User Story 2 — Fórmula de Efectivo Esperado sin "doble resta" del cambio (Priority: P1)

**Goal**: el texto del banner deja de mencionar "cambio entregado" como término de la fórmula, sin
que el valor numérico de Efectivo Esperado cambie.

**Independent Test**: con el turno de ejemplo (Fondo inicial $100.000, Ventas efectivo neto
$45.000, sin ingresos/egresos/retiros), el banner muestra $145.000 y el texto ya no incluye la
palabra "cambio".

### Implementación para User Story 2

- [X] T009 [US2] En `../pos-heladeria/src/app/modules/cash-register/components/cash-dashboard.component.ts`
  (línea ≈42), cambiar el texto del banner de "Fondo inicial + ventas en efectivo − cambio
  entregado + ingresos − egresos − retiros" a "Fondo inicial + ventas en efectivo + ingresos −
  egresos − retiros".
- [X] T010 [P] [US2] Añadir a `../pos-backend/app/scripts/test_cash_net_sales.py` el caso 3 de
  `quickstart.md` §1: con el turno de T006 (`opening_amount=100000`, sin ingresos/egresos/retiros)
  `expected == 145000`, idéntico al valor que daba el cálculo antes de este hotfix para el mismo
  turno (research.md D3, FR-003). Ya quedó incluido en `test_expected_no_cambia_respecto_al_hotfix`
  al escribir T006 — no hizo falta una segunda pasada.
- [X] T011 [US2] Corrido `npx ng test --watch=false --include='src/app/modules/cash-register/**/*.spec.ts'`
  en `../pos-heladeria`: **6 archivos / 24 tests, todos en verde** — ningún spec de `cash-register`
  asertaba el texto viejo del banner.
- [ ] T012 [US2] Verificación manual (`ng serve`): **pendiente** — este entorno no tiene
  navegador/GUI disponible. El cambio es un literal de plantilla de una sola línea (T009), sin
  lógica involucrada; queda para una revisión visual humana antes de mergear.

**Checkpoint**: US1 + US2 juntas ya dejan el resumen de caja (vista en pantalla) matemáticamente
transparente: tarjeta neta y fórmula sin el término de cambio.

---

## Phase 5: User Story 3 — Cambio Entregado como dato informativo secundario (Priority: P2)

**Goal**: el Cambio Entregado sigue visible, pero deja de posicionarse como si fuera un término
operativo de la fórmula — ni en el dashboard (ya correcto) ni en el reporte de cierre impreso
(research.md D2).

**Independent Test**: turno con cambio entregado > $0 → la tarjeta/fila "Cambio entregado" sigue
visible con su valor correcto, tanto en pantalla como en el reporte impreso, sin aparecer como
resta dentro de la secuencia que termina en "Efectivo esperado".

### Implementación para User Story 3

- [X] T013 [US3] En `../pos-heladeria/src/app/modules/cash-register/components/cash-report.component.ts`
  (líneas ≈27-34), sacar la fila "Cambio entregado" de la tabla secuencial "Resumen financiero"
  (hoy aparece con "−" entre las filas de Ventas y la fila Ingresos) y mostrarla como dato
  informativo aparte — mismo tratamiento que ya tiene la tarjeta equivalente en
  `cash-dashboard.component.ts` (visible solo cuando `ind.cambioEntregado > 0`, sin signo "−" ni
  posición dentro de la suma). Implementado como un párrafo aparte, debajo de la tabla y antes de
  "Arqueo de caja": "Cambio entregado (informativo): {{ monto }}".
- [X] T014 [P] [US3] Confirmado (lectura de código, sin cambios) que
  `cash-dashboard.component.ts` ya trata "Cambio entregado" como tarjeta informativa aparte desde
  antes de este hotfix — cumple FR-004 sin tarea adicional ahí.
- [X] T015 [US3] Corrido `npx ng test --watch=false --include='src/app/modules/cash-register/**/*.spec.ts'`
  en `../pos-heladeria` tras T013: **6 archivos / 24 tests, todos en verde**, sin regresión.
  Verificación manual del reporte impreso: **pendiente** (sin navegador/GUI en este entorno) —
  el cambio de T013 es estructural de plantilla (mover un `@if` fuera de una `<tr>`), de bajo
  riesgo, pero amerita una mirada visual humana antes de mergear, igual que T012.

**Checkpoint**: las tres historias completas — el resumen de caja (pantalla e impreso) es
consistente en los dos lugares donde se muestra.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [ ] T016 Ejecutar `quickstart.md` completo de punta a punta: **parcial** — los 5 puntos del
  script backend (T007), la regresión de characterization (T007) y las specs Vitest de
  `cash-register` (T011/T015) ya están en verde; los 5 pasos manuales del frontend (`ng serve`)
  siguen pendientes de este entorno sin navegador — mismo bloqueo que T012/T015.
- [X] T017 [P] Verificado sobre 2 turnos distintos (uno con cambio en `test_tarjeta_muestra_neto_no_bruto`/
  `test_expected_no_cambia_respecto_al_hotfix`, uno sin ventas en efectivo en
  `test_sin_ventas_efectivo_muestra_cero`, y un tercero en
  `test_invariante_sales_by_method_igual_a_ventas_efectivo`) el invariante de `data-model.md`:
  `sales_by_method[cash].total == ventas_efectivo == cash_sales`.
- [X] T018 Confirmado por lectura de código: los 4 puntos donde `pos-backend` expone el arqueo
  (`cash/router.py:112,136,154` y `cash/service.py:87`) llaman `reconcile()` sin ningún snapshot
  persistido de por medio — un turno cerrado antes de este hotfix se recalcula igual que uno
  abierto hoy, así que se ve con la nueva interpretación al reconsultarlo (Assumptions de
  `spec.md`).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias — puede empezar de inmediato. T001 (registro de
  anomalías) **bloquea** toda implementación de código (Puerta G1, Principio II); T002/T003
  (ramas) bloquean tocar código en cada repo respectivo (Principio XIV).
- **Foundational (Phase 2)**: vacía — no bloquea nada.
- **User Stories (Phase 3-5)**: todas dependen de Phase 1 completa (T001-T003). Entre ellas:
  - US1 (T004-T008) es la base técnica: US2 y US3 tocan archivos distintos y no dependen del código
    de US1 para compilar, pero su valor de negocio completo (banner y tarjeta consistentes) solo se
    aprecia con US1 ya aplicada — se recomienda implementarlas en orden P1 → P1 → P2 como abajo.
  - US2 (T009-T012) no depende de US1 en código, solo en secuencia recomendada.
  - US3 (T013-T015) no depende de US1 ni de US2 en código.
- **Polish (Phase 6)**: depende de que las tres historias deseadas estén completas.

### Parallel Opportunities

- T002 y T003 en paralelo (repos distintos).
- T005 en paralelo con T004 (archivos distintos, aunque T005 documenta el resultado de T004 —
  puede escribirse antes y verificarse después).
- T010 en paralelo con T009 (archivos distintos: script backend vs. plantilla frontend).
- T014 en paralelo con T013 (T014 es solo lectura/confirmación, sin tocar archivos).
- T016 y T017 en paralelo entre sí al final.

---

## Parallel Example: User Story 1

```bash
# T004 y T005 tocan archivos distintos del mismo módulo backend:
Task: "Ajustar reconcile() en ../pos-backend/app/api/v1/cash/service.py"
Task: "Actualizar comentarios en ../pos-backend/app/api/v1/cash/schemas.py"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Completar Phase 1 (incluye la Puerta G1 — sin la entrada A-122 no se puede avanzar).
2. Completar Phase 3 (User Story 1): la tarjeta "Ventas Efectivo" ya muestra el neto.
3. **Detenerse y validar**: correr T007/T008 de forma independiente.
4. Esto ya resuelve la causa raíz de la confusión reportada por el usuario, aunque el banner (US2)
   todavía no esté actualizado.

### Incremental Delivery

1. Setup (Phase 1) → Puerta G1 cerrada, ramas creadas.
2. User Story 1 → tarjeta neta → validar independientemente (MVP).
3. User Story 2 → texto del banner corregido → validar independientemente.
4. User Story 3 → "Cambio entregado" reposicionado como informativo → validar independientemente.
5. Polish → `quickstart.md` de punta a punta.

## Notes

- Por ser un hotfix de un solo incremento (Principio VI), no se espera trabajo en paralelo por
  varios desarrolladores — el orden sugerido arriba (P1 → P1 → P2) es también el orden de
  implementación recomendado para un solo desarrollador.
- Los commits se hacen solo bajo pedido explícito del usuario, en unidades pequeñas y lógicas (p.
  ej. uno por fase o por archivo tocado), en inglés, sin ninguna marca de autoría de IA
  (Principio XV) — esto aplica a los commits dentro de `pos-backend` y `pos-heladeria`, no a este
  repositorio de specs.
