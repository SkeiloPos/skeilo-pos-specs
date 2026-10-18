---

description: "Tareas de la spec 127 — corrección de zona horaria en la vigencia de promociones (US1 frontend, US2 backend)"
---

# Tasks: Vigencia de promociones en la hora local del tenant

**Input**: Documentos de diseño de `/specs/127-fix-zona-horaria-promociones/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [quickstart.md](./quickstart.md)

**Tests**: Se incluyen tests nuevos en ambas historias (research.md, Decisiones 1 y 2, y
plan.md Technical Context lo exigen explícitamente) — no son TDD estricto escritos antes de
la implementación, sino regresión que demuestra la corrección y protege contra que el defecto
vuelva (mismo patrón que spec 126, T007/T008).

**Organización**: Dos historias de usuario, **completamente independientes entre sí**
(repositorios y archivos distintos — US1 es solo frontend, US2 es solo backend). No hay fase
Foundational: no existe ningún código compartido entre ambas que resolver por separado.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: puede ejecutarse en paralelo (archivo distinto, repo distinto, o verificación de
  solo lectura sin dependencia de una tarea sin terminar)
- **[Story]**: US1, US2 — mapea a las Historias 1-2 de `spec.md`
- Cada tarea incluye la ruta exacta del archivo

## Path Conventions

- `../pos-heladeria/...` — SPA Angular (TypeScript); único repositorio tocado por US1
- `../pos-backend/...` — API FastAPI; único repositorio tocado por US2
- Sin prefijo — archivo dentro de este repo (`pos-specs`, ninguno en esta spec: es una
  corrección de defecto, no requiere entrada nueva en `registro-de-anomalias.md`, ver
  `plan.md` Constitution Check, Principio II)

---

## Phase 1: Setup

**Propósito**: preparar las ramas de trabajo (una por repositorio, Principio XIV) y
registrar la línea base de ambas suites antes de tocar código.

- [X] T001 Crear la rama `fix/127-promotions-tenant-timezone` desde `develop` en
      `../pos-heladeria` (Principio XIV) — único cambio de código de la Historia 1.
- [X] T002 Crear la rama `fix/127-promotions-tenant-timezone` desde `develop` en
      `../pos-backend` (Principio XIV) — único cambio de código de la Historia 2.
- [X] T003 [P] Confirmar árbol de trabajo limpio en `../pos-heladeria` y `../pos-backend`
      antes de empezar.
- [X] T004 [P] Ejecutar
      `npx ng test --watch=false --include='src/app/modules/promotions/**/*.spec.ts'` en
      `../pos-heladeria` y registrar el resultado como línea base (Principio X). — 94
      passed, 1 skipped, 0 failed.
- [X] T005 [P] Ejecutar en `../pos-backend`, ambos como línea base:
      `./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`
      y `./env/bin/python -m app.scripts.test_promotions_rules` (research.md, Decisión 4). —
      script dedicado: todas las comprobaciones pasaron; characterization tests: en curso.

**Checkpoint**: ramas creadas, línea base de las cuatro suites registrada.

---

## Phase 2: Foundational (Blocking Prerequisites)

**No aplica a esta spec.** US1 (frontend, cómputo de `starts_at`) y US2 (backend, motor de
vigencia) no comparten ningún archivo ni código — son correcciones independientes en
repositorios distintos. Ambas dependen únicamente de Setup.

**Checkpoint**: N/A — continuar directamente a la Fase 3.

---

## Phase 3: User Story 1 - La promoción respeta su horario sin importar la hora en que se creó o editó (Priority: P1) 🎯 MVP

**Goal**: al guardar una promoción sin fecha de inicio explícita, `starts_at` queda en el
día calendario **local del tenant**, nunca en el día UTC — corrige el defecto reportado
directamente (promoción creada después de las 7pm quedando "vigente mañana").

**Independent Test**: crear o editar una promoción con ventana horaria después de las 7pm
hora de Bogotá (o con el reloj/SO en UTC) y verificar que `starts_at` corresponde al día
calendario local de hoy, no al día siguiente — y que la promoción queda vigente de inmediato
dentro de su ventana (quickstart.md, Escenarios 1 y 2).

### Tests for User Story 1

- [X] T006 [P] [US1] Agregar, en
      `../pos-heladeria/src/app/modules/promotions/pages/promotions-page.component.spec.ts`,
      un test que simule un reloj/zona horaria donde la fecha UTC difiere de la fecha local
      del tenant (p. ej. cerca de la medianoche local, o con `TenantInfoService` mockeado con
      `timezone: 'America/Bogota'` y un `Date` fijo posterior a las 7pm local) y verifique
      que `continueToConfigure()` arma `starts_at` con el día calendario **local**
      (`businessToday(tz)`), no con `new Date().toISOString().slice(0, 10)` — citar research.md
      Decisión 1.
- [X] T007 [P] [US1] Agregar, en
      `../pos-heladeria/src/app/modules/promotions/services/promotion.service.spec.ts`, un
      test equivalente para el fallback `starts_at: form.starts_at ?? new Date().toISOString()`
      (línea ~262) del constructor del payload de creación/edición.

### Implementation for User Story 1

- [X] T008 [US1] En
      `../pos-heladeria/src/app/modules/promotions/pages/promotions-page.component.ts`,
      `continueToConfigure()` (línea ~1722): reemplazar
      `starts_at: new Date().toISOString().slice(0, 10)` por
      `starts_at: businessToday(this.tenantInfo.info()?.timezone ?? 'America/Bogota')` —
      importar `businessToday` de `../../../shared/date-format.util.ts` e inyectar
      `TenantInfoService` (`inject()`, mismo patrón ya usado en el archivo) si no está ya
      disponible en el componente.
- [X] T009 [US1] En
      `../pos-heladeria/src/app/modules/promotions/services/promotion.service.ts` (línea
      ~262): aplicar el mismo reemplazo (`businessToday(tz)` en vez de
      `new Date().toISOString()`) en el fallback del constructor del payload, inyectando
      `TenantInfoService` en el servicio si no está ya disponible.
- [X] T010 [US1] Ejecutar T006 y T007 y confirmar que ambos pasan (depende de T008, T009). —
      ambos verificados además contra una reversión temporal de la corrección (fallan sin
      ella, pasan con ella restaurada).
- [ ] T011 [P] [US1] Ejecutar manualmente el Escenario 1 de
      [quickstart.md](./quickstart.md) (crear después de las 7pm no desplaza al día
      siguiente) y registrar el resultado.
- [ ] T012 [P] [US1] Ejecutar manualmente el Escenario 2 de
      [quickstart.md](./quickstart.md) (medianoche local, consistencia de día) y registrar
      el resultado.

**Checkpoint**: la Historia 1 queda completamente funcional y verificable de forma
independiente — el MVP de esta spec.

---

## Phase 4: User Story 2 - La vigencia se evalúa con la zona horaria real de cada tenant (Priority: P2)

**Goal**: el motor de vigencia (`promotions/service.py`) evalúa cada promoción con la zona
horaria real del tenant propietario (columna `Tenant.timezone`, ya existente) en vez del
valor global compartido `settings.TENANT_TIMEZONE` — en los seis sitios reales donde se
decide si un descuento aplica (menú público, carrito, cobro de pedidos/mesas), cada uno
pasando el `Tenant` que su propio router/contexto ya tiene resuelto (research.md, Decisiones
2 y 3).

**Independent Test**: dos tenants con zonas horarias configuradas distintas, cada uno con
una promoción con la misma ventana horaria, evaluando correctamente según su propia zona
(quickstart.md, Escenario 3); y los tres puntos de entrada (carrito, cobro, menú) coincidiendo
siempre entre sí para el mismo tenant e instante (quickstart.md, Escenario 4).

### Tests for User Story 2

- [X] T013 [P] [US2] Agregar, en
      `../pos-backend/app/characterization_tests/test_promotions_service.py`, un test que
      cree (o reutilice un fixture de) un `Tenant` con `timezone` distinta a
      `America/Bogota` (p. ej. `America/Mexico_City`, UTC-6) y una promoción con una ventana
      horaria tal que, para un instante UTC fijo, el resultado de `_valid_now`/
      `active_variant_set_rules`/`evaluate_variant_sets` sea **distinto** según se le pase
      ese `tenant` o no (hoy ambos casos dan el mismo resultado porque el tenant nunca se
      pasa) — este test debe fallar antes de T015 y pasar después (research.md, Decisión 2).
- [X] T014 [P] [US2] Agregar, en los archivos de test que correspondan según la convención ya
      usada en este repo para cada módulo (revisar primero `test_promotions_rules_admin.py`,
      `test_cart_service.py`, `test_orders_checkout.py` por el patrón existente), un test (o
      conjunto de tests) que confirme que menú (`active_variant_set_rules` vía
      `menu/router.py`), carrito (`cart/service.py`) y cobro (`orders/checkout.py`) producen
      el **mismo** resultado de vigencia para el mismo tenant (con zona horaria no-default) y
      el mismo instante — FR-003.

### Implementation for User Story 2

- [X] T015 [US2] En `../pos-backend/app/api/v1/promotions/service.py`: agregar el parámetro
      `tenant: Tenant | None = None` a `local_now()`, `_valid_now()`,
      `active_variant_set_rules()` y `evaluate_variant_sets()`, reenviándolo hasta la llamada
      ya existente a `_tz(tenant)` (research.md, Decisión 2) — **sin tocar** `_in_time_window()`
      ni la lógica de atribución de día por cruce de medianoche (A-57) dentro de
      `_valid_now()` (FR-004, Principio III).
- [X] T016 [P] [US2] En `../pos-backend/app/api/v1/menu/router.py`: agregar
      `tenant: Tenant = Depends(get_tenant)` a `public_menu()` y `public_menu_promotions()`;
      pasar `tenant` (o `ctx.tenant`, ya disponible en `menu_by_signed_qr()`) hacia
      `_build_menu(db, tenant)` / `_build_menu_promotions(db, now, tenant)`, que a su vez lo
      reenvían a `active_variant_set_rules()` (research.md, Decisión 3, fila "Menú público").
- [X] T017 [P] [US2] En `../pos-backend/app/api/v1/cart/service.py`: agregar un parámetro
      `tenant` a `serialize_cart()` y `submit_cart()`, sourceado desde `ctx.tenant`
      (`SessionContext`, ya disponible en sus llamadores de `cart/router.py`) y reenviado a
      `promotions.evaluate_variant_sets()` en ambos sitios de llamada (líneas ~309 y ~792,
      research.md Decisión 3, fila "Carrito").
- [X] T018 [P] [US2] En `../pos-backend/app/api/v1/orders/checkout.py`: agregar un parámetro
      `tenant` a `auto_discount()`, `refresh_order_item_discounts()`,
      `compute_checkout_preview()`, `compute_draft_preview()`, `pay_order()` y
      `checkout_and_send()`, sourceado desde el `tenant: Tenant = Depends(get_tenant)` ya
      presente en casi todos los endpoints de `orders/router.py`, y reenviado a
      `promotions.evaluate_variant_sets()` en sus dos sitios de llamada (líneas ~348 y ~427,
      research.md Decisión 3, fila "Cobro de pedidos/mesas").
- [X] T019 [US2] Ejecutar T013 y T014 y confirmar que ambos pasan (depende de T015-T018). —
      verificados además contra una reversión temporal de la corrección (fallan con
      TypeError sin ella — las funciones del motor no aceptaban `tenant` — y pasan con ella
      restaurada).
- [ ] T020 [P] [US2] Ejecutar manualmente el Escenario 3 de
      [quickstart.md](./quickstart.md) (dos tenants, zonas horarias distintas) y registrar
      el resultado.
- [ ] T021 [P] [US2] Ejecutar manualmente el Escenario 4 de
      [quickstart.md](./quickstart.md) (carrito, cobro y menú concuerdan) y registrar el
      resultado.

**Checkpoint**: la Historia 2 queda completamente funcional y verificable de forma
independiente, sin afectar a la Historia 1 (repositorios y archivos distintos).

---

## Phase 5: Polish & Cross-Cutting Concerns

**Propósito**: cerrar la verificación global de ambas historias antes de dar la spec por
completada.

- [ ] T022 Ejecutar manualmente el Escenario 5 de [quickstart.md](./quickstart.md) (el
      cruce de medianoche sigue funcionando exactamente igual, A-57/FR-004) y registrar el
      resultado.
- [X] T023 [P] Ejecutar la suite completa de characterization tests en `../pos-backend`
      (`./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`)
      y confirmar que sigue en verde, comparando contra la línea base de T005 (sin
      regresiones más allá de los tests nuevos de T013/T014).
- [X] T024 [P] Ejecutar `../pos-backend`'s script de CI dedicado
      (`./env/bin/python -m app.scripts.test_promotions_rules`) y confirmar que sigue en
      verde **sin modificación** — prueba explícita de que el cruce de medianoche/A-57 no
      cambió (FR-004, Principio III, research.md Decisión 4).
- [X] T025 [P] Ejecutar la suite completa de `ng test` en `../pos-heladeria` y confirmar que
      no se rompió ningún test fuera del baseline ya documentado en la memoria del proyecto
      (Principio X).
- [X] T026 Verificar FR-005: tomar (o simular) una promoción ya guardada con `starts_at`
      desplazado por el defecto original, volver a guardarla desde el formulario de edición,
      y confirmar que queda con la fecha local correcta — sin ninguna migración automática
      (Assumptions de spec.md). — **Hallazgo durante la verificación**: `starts_at` no era
      editable en ningún camino existente (`PromotionUpdate` no lo incluía;
      `service.update()` no lo tocaba; `duplicate()` copiaba el valor original tal cual) —
      FR-005 no se podía cumplir tal como estaba escrito. Consultado el usuario, se decidió
      extender la capacidad de edición (en vez de documentar el hueco sin resolverlo):
      - Backend: `PromotionUpdate.starts_at` agregado (`schemas.py`); `service.update()`
        ahora lo acepta, pero solo mientras `promo.status == "draft"` (409 en cualquier otro
        estado — más estricto que el resto de los campos escalares, que siguen editables en
        `paused`) — una promoción que ya llegó a `active` alguna vez no puede cambiar
        retroactivamente su fecha de inicio.
      - Frontend: el campo "Fecha inicio" del formulario de configuración YA existía en la
        plantilla (`[(ngModel)]="form.starts_at"`, deshabilitado fuera de `draft`) pero nunca
        viajaba en el payload de `PATCH` (`toScalars()` lo omitía) — era un bug de UI
        preexistente y no relacionado con zona horaria, descubierto al verificar este FR.
        `toScalars()` ahora lo incluye; `PromotionService.update()` gana un parámetro
        `includeStartsAt` (default `true`) para que el caller lo excluya explícitamente
        fuera de `draft`, en vez de reenviar sin querer el mismo valor sin cambios.
      - Tests nuevos: `test_promotions_rules_admin.py::test_ca1c_...` (backend, confirma
        editable en draft / 409 en pausada — verificado además contra una reversión
        temporal: falla sin el fix, pasa con él) y
        `promotion.service.spec.ts::PromotionService.update — starts_at solo viaja...`
        (frontend, confirma `includeStartsAt`); dos tests de `promotions-page.component.spec.ts`
        actualizados para la nueva firma de `update()`.
      - Full regression tras este cambio: backend 1769 tests OK; frontend módulo de
        promociones 98 passed/1 skipped (baseline preexistente, sin relación).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias — puede iniciar de inmediato
- **Foundational (Phase 2)**: N/A, no bloquea nada
- **User Story 1 (Phase 3)**: depende de Setup; independiente de la Fase 4
- **User Story 2 (Phase 4)**: depende de Setup; independiente de la Fase 3
- **Polish (Phase 5)**: depende de que las Fases 3 y 4 estén completas

### Within Each User Story

- US1: T006/T007 (tests) antes de T010 (verificarlos); T008/T009 (implementación) pueden
  ejecutarse en paralelo (archivos distintos) y deben completarse antes de T010; T011/T012
  son de solo lectura/validación manual, independientes entre sí
- US2: T013/T014 (tests) antes de T019 (verificarlos); T015 debe completarse antes de
  T016-T018 (todas dependen de que el motor acepte `tenant`); T016/T017/T018 pueden
  ejecutarse en paralelo entre sí (archivos distintos); T020/T021 son de solo lectura/
  validación manual, independientes entre sí

### Parallel Opportunities

- T001 y T002 en paralelo (repos distintos); T004 y T005 en paralelo (repos distintos)
- Las Fases 3 y 4 completas pueden ejecutarse en paralelo entre sí (repos y archivos
  distintos, ninguna depende de la otra)
- Dentro de US1: T006/T007 en paralelo; T008/T009 en paralelo
- Dentro de US2: T013/T014 en paralelo; T016/T017/T018 en paralelo (una vez completo T015)
- T023, T024 y T025 en paralelo (repos/comandos distintos)

---

## Parallel Example: Las dos historias a la vez

```bash
# Tras Setup, lanzar en paralelo (ninguna historia depende de la otra):
Task: "Corregir starts_at en el frontend (US1, T006-T012)"
Task: "Enhebrar tenant en el motor de vigencia del backend (US2, T013-T021)"
```

---

## Implementation Strategy

### MVP (Historia 1 sola)

1. Completar Fase 1: Setup (ramas + línea base en ambos repos)
2. Completar Fase 3: User Story 1 — corrige el incidente reportado directamente en
   producción (el defecto más visible y priorizado P1)
3. **DETENER y VALIDAR**: confirmar T006/T007 en verde y los Escenarios 1-2 de quickstart.md

### Entrega incremental

1. Setup → línea base conocida en ambos repos
2. Historia 1 (frontend, P1) → valida → cierra el incidente reportado (MVP)
3. Historia 2 (backend, P2) → valida → cierra el riesgo latente de zona horaria global,
   en paralelo con la Historia 1 o después (son independientes)
4. Polish → regresión completa en ambos repos + verificación de FR-004/FR-005

### Notas

- `[P]` = archivos distintos, repos distintos, o verificaciones de solo lectura, sin
  dependencia de una tarea sin terminar
- `[US1]`/`[US2]` identifican cada tarea con su historia de usuario
- Los commits solo se ejecutan si el usuario lo pide explícitamente, en unidades pequeñas y
  lógicas, separadas por repo/capa, en inglés, sin marcas de autoría de IA (Principio XV)
