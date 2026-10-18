---

description: "Tareas de la spec 128 — visibilidad de categorías en el menú QR (US1 admin+filtro, US2 revalidación de carrito, US3 tiempo real opcional)"
---

# Tasks: Visibilidad de categorías en el menú QR

**Input**: Documentos de diseño de `/specs/128-categoria-visible-menu-qr/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/categorias-visibilidad-qr.md](./contracts/categorias-visibilidad-qr.md),
[quickstart.md](./quickstart.md)

**Tests**: Se incluyen tests nuevos en cada historia (siguiendo el patrón de characterization
tests ya establecido en este repo — llamar directamente a los handlers del router/servicio,
no tests de integración HTTP completos).

**Organización**: Tres historias de usuario. US1 (P1) y US2 (P2) son independientes entre sí
una vez completada la Fase Foundational (pueden probarse fijando `visible_en_qr` directo en
BD/fixture, sin necesitar la UI de administración de la otra). US3 (P3) es una mejora opcional
que depende solo de Foundational, pero conviene implementarla después de US1 porque toca la
misma función (`update_category`) que US1 ya modifica.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: puede ejecutarse en paralelo (archivo distinto, repo distinto, o verificación de
  solo lectura sin dependencia de una tarea sin terminar)
- **[Story]**: US1, US2, US3 — mapea a las Historias 1-3 de `spec.md`
- Cada tarea incluye la ruta exacta del archivo

## Path Conventions

- `../pos-backend/...` — API FastAPI
- `../pos-heladeria/...` — SPA Angular (TypeScript)
- Sin prefijo — archivo dentro de este repo (`pos-specs`)

---

## Phase 1: Setup

**Propósito**: preparar las ramas de trabajo (una por repositorio, Principio XIV) y registrar
la línea base de ambas suites antes de tocar código.

- [X] T001 Crear la rama `feat/128-categoria-visible-menu-qr` desde `develop` en
      `../pos-backend` (Principio XIV).
- [X] T002 Crear la rama `feat/128-categoria-visible-menu-qr` desde `develop` en
      `../pos-heladeria` (Principio XIV).
- [X] T003 [P] Confirmar árbol de trabajo limpio en `../pos-heladeria` y `../pos-backend` antes
      de empezar.
- [X] T004 [P] Ejecutar en `../pos-backend`, como línea base:
      `./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'`. —
      1769 tests, OK.
- [X] T005 [P] Ejecutar en `../pos-heladeria`, como línea base:
      `npx ng test --watch=false --include='src/app/modules/categories/**/*.spec.ts'` y
      `--include='src/app/modules/tables/pages/public-menu.component.spec.ts'` (si existe). —
      4 archivos, 68 passed, 0 failed.

**Checkpoint**: ramas creadas, línea base de ambas suites registrada.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Propósito**: la columna `visible_en_qr` y su paso básico por el modelo/schema/endpoint —
sin ninguna regla de negocio todavía (ni restricción de rol, ni guarda de categoría inactiva,
ni filtro del menú QR, ni revalidación de carrito). Tanto US1 como US2 necesitan que la
columna exista y que el PATCH pueda leer/escribir el campo antes de poder construir sus reglas
encima.

**⚠️ CRITICAL**: ninguna historia de usuario puede empezar hasta que esta fase esté completa.

- [X] T006 En `../pos-backend`, crear la migración de Alembic
      `categories.visible_en_qr` (`boolean NOT NULL DEFAULT true`), siguiendo exactamente el
      patrón de `alembic/versions/94144eaa60b5_categories_display_order.py`:
      `@for_each_tenant_schema`, `_has_table(schema, "categories")` como guarda,
      `op.add_column("categories", sa.Column("visible_en_qr", sa.Boolean(), nullable=False,
      server_default=sa.true()), schema=schema)` — sin backfill (research.md, Decisión 1).
- [X] T007 En `../pos-backend/app/models/category.py`: agregar
      `visible_en_qr: Mapped[bool] = mapped_column(Boolean, default=True)` junto a `active`.
- [X] T008 [P] En `../pos-backend/app/api/v1/categories/schemas.py`: agregar
      `visible_en_qr: bool | None = Field(None, description="Visibilidad específica en el
      menú QR, independiente de `active`.")` a `CategoryUpdate`, y
      `visible_en_qr: bool = Field(...)` (obligatorio en la respuesta) a `CategoryResponse`.
- [X] T009 En `../pos-backend/app/api/v1/categories/router.py::update_category`: agregar
      `if body.visible_en_qr is not None: category.visible_en_qr = body.visible_en_qr` junto
      a los demás campos escalares — **sin ningún chequeo de rol ni de estado todavía** (eso
      llega en US1, T015, para que el guardado básico del campo quede separado de sus reglas
      de negocio).

**Checkpoint**: la columna existe, se puede leer y escribir por PATCH, sin ninguna regla de
negocio todavía — listo para construir US1 y US2 en paralelo.

---

## Phase 3: User Story 1 - El administrador oculta o muestra una categoría del menú QR (Priority: P1) 🎯 MVP

**Goal**: el administrador puede ocultar/mostrar una categoría específicamente en el menú QR
(respetando que esté activa, sin alterar su posición), restringido a su rol, y el menú QR (y
su buscador) respeta ese estado sin afectar el catálogo del personal.

**Independent Test**: ocultar una categoría activa desde la pantalla de administración,
recargar el menú QR público y confirmar que la categoría y sus productos ya no aparecen,
mientras que un "Nuevo pedido" desde caja o mesa sigue mostrándolos sin cambios (quickstart.md,
Escenarios 1-5).

### Tests for User Story 1

- [X] T010 [P] [US1] Crear
      `../pos-backend/app/characterization_tests/test_category_qr_visibility.py`, llamando
      directamente a `update_category(id, body, db, user)` (mismo patrón que
      `test_categories_presentations.py`), con casos: (a) un `user` con
      `role.name == "ADMIN"` (p. ej. `SimpleNamespace(role=SimpleNamespace(name="ADMIN"))`)
      puede cambiar `visible_en_qr` de una categoría activa; (b) un `user` con
      `role.name == "CASHIER"` recibe `HTTPException` 403 al intentar cambiar `visible_en_qr`;
      (c) ese mismo usuario Cajero SÍ puede seguir cambiando `name`/`display_order` en la
      misma llamada (confirma que la restricción es solo sobre `visible_en_qr`, research.md
      Decisión 3); (d) intentar cambiar `visible_en_qr` de una categoría con `active=False`
      lanza `HTTPException` 422, con un mensaje que indique que hay que activarla primero
      (FR-006).
- [X] T011 [P] [US1] Agregar, en
      `../pos-backend/app/characterization_tests/test_menu_router.py`, un test que confirme
      que `_build_menu` excluye una categoría con `active=True, visible_en_qr=False` (y sus
      productos), y la vuelve a incluir cuando `visible_en_qr=True` — además, confirmar que
      su `display_order` no cambia al ocultarla/mostrarla (FR-004).
- [X] T012 [P] [US1] Agregar, en
      `../pos-heladeria/src/app/modules/categories/pages/categories-page.component.spec.ts`,
      tests para: la columna "Menú QR" se renderiza con el estado correcto; el toggle llama al
      servicio; para una categoría inactiva, la acción de visibilidad en QR aparece
      deshabilitada con el texto de ayuda "Activa la categoría para controlar su visibilidad
      en QR"; el filtro "Todas" incluye la opción "Ocultas en QR".
- [X] T013 [P] [US1] Agregar, en
      `../pos-heladeria/src/app/modules/categories/services/category.service.spec.ts`, un
      test para el nuevo método `toggleVisibleQr()` (mismo patrón que el test ya existente de
      `toggleActive()`).

### Implementation for User Story 1

- [X] T014 [US1] En `../pos-backend/app/api/v1/categories/router.py::update_category`:
      agregar, antes de aplicar `visible_en_qr` (depende de T009), la guarda de rol (`user:
      User = Depends(get_current_user)` ya presente — 403 si `body.visible_en_qr is not None
      and (not user.role or user.role.name != "ADMIN")`) y la guarda de estado (422 si
      `body.visible_en_qr is not None and not category.active`), siguiendo exactamente el
      alcance de research.md Decisión 3 (no agregar `require_tenant_admin` como dependencia
      de todo el endpoint).
- [X] T015 [US1] En `../pos-backend/app/api/v1/menu/router.py::_build_menu`: cambiar
      `Category.active.is_(True)` por
      `Category.active.is_(True), Category.visible_en_qr.is_(True)` en el `.where(...)` de la
      consulta de categorías (research.md, Decisión 4).
- [X] T016 [P] [US1] En
      `../pos-heladeria/src/app/modules/categories/interfaces/category.interface.ts`:
      agregar `visible_en_qr: boolean` a la interfaz `Category`.
- [X] T017 [US1] En
      `../pos-heladeria/src/app/modules/categories/services/category.service.ts`: agregar
      `toggleVisibleQr(id: string, current: boolean): Promise<void>`, mismo patrón que
      `toggleActive()` (líneas ~161-168: `PATCH` con `{ visible_en_qr: !current }`).
- [X] T018 [US1] En
      `../pos-heladeria/src/app/modules/categories/pages/categories-page.component.ts`:
      agregar la columna "Menú QR" a la tabla (junto a "Estado", líneas ~86-91), con su
      pill/toggle siguiendo el mismo patrón visual que `active` (líneas ~112-145), llamando a
      `onToggleQr(cat)` → `categoryService.toggleVisibleQr(...)`; el control queda
      deshabilitado con el texto de ayuda de FR-006 cuando `!cat.active`.
- [X] T019 [US1] En el mismo archivo: agregar la opción "Ocultas en QR" al selector de filtro
      ya existente (líneas ~38-46, hoy `Todas`/`Activas`/`Inactivas`) — FR-011.
- [X] T020 [US1] En el mismo archivo: al cambiar la visibilidad en QR, mostrar un toast corto
      (p. ej. "Con licor oculta del menú QR") con la opción "Deshacer" que vuelve a llamar
      `toggleVisibleQr()` con el valor anterior — sin modal de confirmación (FR-010; revisar
      el servicio de toasts ya usado en otras pantallas de administración para seguir el mismo
      patrón de "Deshacer" si ya existe uno).
- [X] T021 [US1] Ejecutar T010-T013 y confirmar que todos pasan (depende de T014-T020). —
      backend: 18/18 OK (incluye los 4 de rol/estado y los 3 del filtro de menú);
      frontend: 17/17 OK (módulo `categories` completo). Verificado además con TDD real:
      los 5 casos nuevos fallaban exactamente como se esperaba antes de T014/T015, y pasan
      tras implementarlos.
- [ ] T022 [P] [US1] Ejecutar manualmente los Escenarios 1 a 5 de
      [quickstart.md](./quickstart.md) y registrar el resultado de cada uno.

**Checkpoint**: la Historia 1 queda completamente funcional y verificable de forma
independiente — el MVP de esta spec.

---

## Phase 4: User Story 2 - El pedido de un comensal se corrige si algo de su carrito dejó de estar disponible en QR (Priority: P2)

**Goal**: si un comensal tiene en el carrito un producto cuya categoría se ocultó del menú QR
mientras tanto, el envío del pedido lo rechaza específicamente, lo quita del carrito y se lo
informa — sin perder la posibilidad de reintentar con el resto.

**Independent Test**: agregar al carrito un producto de una categoría, ocultar esa categoría
del menú QR (fijando `visible_en_qr=False` directo si la UI de US1 no está lista aún), enviar
el pedido y confirmar el rechazo + limpieza del carrito (quickstart.md, Escenario 6).

### Tests for User Story 2

- [X] T023 [P] [US2] Agregar, en `../pos-backend/app/characterization_tests/test_cart_service.py`
      (mismo archivo que ya cubre la revalidación de agotados de spec 093), un test que: arme
      un carrito con un producto cuya categoría tiene `visible_en_qr=True`, cambie la
      categoría a `visible_en_qr=False` (o `active=False`), llame `submit_cart`, y confirme
      que (a) lanza `HTTPException` 409 nombrando el producto, (b) no se creó ninguna
      `CustomerOrder`, y (c) la fila de `CartItem` correspondiente ya no existe en el carrito
      después de la llamada (research.md, Decisión 5) — a diferencia del caso de agotados
      (spec 093), donde el carrito no se toca.

### Implementation for User Story 2

- [X] T024 [US2] En `../pos-backend/app/api/v1/cart/service.py::submit_cart`: junto a
      `ensure_products_available(...)` (líneas ~764-769), agregar la revalidación de
      categoría — para cada ítem del carrito, resolver `product.category` y comprobar
      `active AND visible_en_qr`; si alguno falla, eliminar esas filas de `CartItem` (`db.delete`)
      y lanzar `HTTPException(409, detail={"error": "Algunos productos ya no están
      disponibles y se quitaron de tu carrito", "productos_no_disponibles": [...]})` **antes**
      de crear la orden, sin dejar que la función siga (contracts/categorias-visibilidad-qr.md
      §3).
- [X] T025 [US2] En el frontend donde ya se maneja el error de envío del carrito (revisar
      `showCartError`/manejo de errores de `submit_cart` en
      `../pos-heladeria/src/app/modules/tables/pages/public-menu.component.ts`): agregar el
      caso de este nuevo 409 mostrando el mensaje "Algunos productos ya no están disponibles y
      se quitaron de tu carrito", y refrescar la vista del carrito (ya quedó limpio en el
      backend, solo falta reflejarlo).
- [X] T026 [US2] Ejecutar T023 y confirmar que pasa (depende de T024). — 4/4 OK; además
      `test_cart_sold_out.py`/`test_cart_service.py`/`test_cart_router.py` completos (78
      tests) siguen en verde, sin regresión sobre el camino de agotados ya existente.
- [ ] T027 [P] [US2] Ejecutar manualmente el Escenario 6 de [quickstart.md](./quickstart.md) y
      registrar el resultado.

**Checkpoint**: la Historia 2 queda completamente funcional y verificable de forma
independiente, sin depender de que la UI de administración de US1 esté terminada.

---

## Phase 5: User Story 3 - El menú QR ya abierto se actualiza sin que el comensal recargue (Priority: P3, opcional)

**Goal**: un comensal con el menú QR ya abierto ve aparecer/desaparecer una categoría sin
recargar, cuando el administrador cambia su visibilidad en QR.

**Independent Test**: abrir el menú QR en un dispositivo, cambiar la visibilidad de una
categoría desde administración sin recargar la pantalla del comensal, y confirmar que se
actualiza sola (quickstart.md, Escenario 8).

**Nota**: a diferencia de US1/US2, esta historia depende de infraestructura que hoy no existe
(research.md, Decisión 6) — un canal SSE nuevo para comensales, distinto del `session_channel`
por mesa. FR-008 (recarga manual) ya queda cubierto por US1/T015 sin esta historia; US3 es una
mejora SHOULD, no una condición para cerrar la spec (Principio VI).

### Tests for User Story 3

- [X] T028 [P] [US3] Agregar, en `../pos-backend/app/characterization_tests/` (archivo nuevo
      o el que ya cubra `app/core/events.py`), un test que confirme que `publish(tenant_id,
      type="menu.updated", channels=[<canal nuevo>])` llega a un suscriptor comensal
      (`kind="diner"`) sin necesitar que coincida su `table_session_id` — a diferencia de
      `session_channel`, que sí lo exige.

### Implementation for User Story 3

- [X] T029 [US3] En `../pos-backend/app/core/events.py`: agregar una función de canal nueva
      (p. ej. `menu_channel(tenant_id: int) -> str`) y el wrapper de evento `menu_updated(tenant_id)`
      que publica `type="menu.updated"` en ese canal, siguiendo el mismo patrón "evento
      delgado, publicar después del commit" que el resto del catálogo (contracts/categorias-visibilidad-qr.md §4).
- [X] T030 [US3] En `../pos-backend/app/api/v1/realtime/auth.py::_validate_diner_sync`:
      agregar el canal nuevo al `channels=frozenset({...})` del `Subscriber` de cada
      comensal, junto a su `session_channel` existente (línea ~61) — todo comensal lo recibe,
      sin importar su mesa.
- [X] T031 [US3] En `../pos-backend/app/api/v1/categories/router.py::update_category`:
      después de `db.commit()` (depende de T014/US1, mismo archivo/función — ejecutar en
      secuencia, no en paralelo con esa tarea), si `visible_en_qr` cambió, llamar al wrapper
      de evento de T029.
- [X] T032 [US3] En
      `../pos-heladeria/src/app/modules/tables/pages/public-menu.component.ts::connectRealtime`:
      agregar un listener para `menu.updated` (mismo patrón que los demás `this.realtime.on(...)`,
      líneas ~1559-1581) que vuelva a pedir el menú (`categories`) completo — hoy ningún
      listener existente lo hace, todos refrescan solo "Mis pedidos".
- [X] T033 [US3] Ejecutar T028 y confirmar que pasa (depende de T029-T031).
- [ ] T034 [P] [US3] Ejecutar manualmente el Escenario 8 de [quickstart.md](./quickstart.md) y
      registrar el resultado.

**Checkpoint**: las tres historias quedan verificadas de forma independiente.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Propósito**: cerrar la verificación global de las historias implementadas antes de dar la
spec por completada.

- [ ] T035 Ejecutar manualmente el Escenario 7 de [quickstart.md](./quickstart.md) (pedidos QR
      ya enviados antes de ocultar la categoría no se ven afectados) y registrar el resultado.
- [X] T036 [P] Ejecutar la suite completa de characterization tests en `../pos-backend` y
      confirmar que sigue en verde, comparando contra la línea base de T004.
- [X] T037 [P] Ejecutar la suite completa de `ng test` en `../pos-heladeria` y confirmar que no
      se rompió ningún test fuera del baseline ya documentado en la memoria del proyecto.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias — puede iniciar de inmediato
- **Foundational (Phase 2)**: depende de Setup — BLOQUEA las tres historias
- **User Story 1 (Phase 3)**: depende de Foundational; independiente de la Fase 4
- **User Story 2 (Phase 4)**: depende de Foundational; independiente de la Fase 3
- **User Story 3 (Phase 5)**: depende de Foundational; su T031 depende además de que T014
  (US1) esté completa, por tocar la misma función
- **Polish (Phase 6)**: depende de que las historias que se vayan a entregar estén completas

### Within Each User Story

- US1: T010-T013 (tests) antes de T021 (verificarlos); T014/T015 (backend) y T016-T020
  (frontend) pueden ejecutarse en paralelo entre sí (archivos distintos); T016 antes de
  T017/T018 (la interfaz debe existir antes de usarla)
- US2: T023 (test) antes de T026 (verificarlo); T024 (backend) y T025 (frontend) pueden
  ejecutarse en paralelo
- US3: T028 (test) antes de T033 (verificarlo); T029 antes de T030/T031; T031 depende de T014
  (US1, mismo archivo); T032 (frontend) en paralelo con el resto del backend de esta historia

### Parallel Opportunities

- T001/T002 en paralelo (repos distintos); T004/T005 en paralelo (repos distintos)
- Tras Foundational, las Fases 3 y 4 (US1, US2) pueden ejecutarse en paralelo por completo
- Dentro de US1: T010/T011/T012/T013 en paralelo; T014/T015 (backend) en paralelo con
  T016-T020 (frontend)
- Dentro de US2: T023 en paralelo con el resto hasta que haya que verificarlo; T024/T025 en
  paralelo
- T036/T037 en paralelo (repos distintos)

---

## Parallel Example: US1 y US2 a la vez

```bash
# Tras Foundational, lanzar en paralelo (ninguna historia depende de la otra):
Task: "Ocultar/mostrar categoría del menú QR, con rol y filtro (US1, T010-T022)"
Task: "Revalidar el carrito del comensal al enviar (US2, T023-T027)"
```

---

## Implementation Strategy

### MVP (Historia 1 sola)

1. Completar Fase 1: Setup (ramas + línea base en ambos repos)
2. Completar Fase 2: Foundational (columna + paso básico por el PATCH)
3. Completar Fase 3: User Story 1 — ya entrega el resultado de negocio completo: un comensal
   que recarga el menú QR después del cambio ya no ve la categoría oculta
4. **DETENER y VALIDAR**: confirmar T010-T013 en verde y los Escenarios 1-5 de quickstart.md

### Entrega incremental

1. Setup + Foundational → columna lista en ambos repos
2. Historia 1 (P1) → valida → cierra el resultado de negocio principal (MVP)
3. Historia 2 (P2) → valida → cierra la ventana de carritos con productos ya ocultos, en
   paralelo con la Historia 1 o después (son independientes)
4. Historia 3 (P3, opcional) → valida → mejora de experiencia, puede posponerse sin que la spec
   quede incompleta (FR-008 ya está cubierto sin ella)
5. Polish → regresión completa en ambos repos

### Notas

- `[P]` = archivos distintos, repos distintos, o verificaciones de solo lectura, sin
  dependencia de una tarea sin terminar
- `[US1]`/`[US2]`/`[US3]` identifican cada tarea con su historia de usuario
- Esta spec no requiere ninguna entrada nueva en `registro-de-anomalias.md` (research.md,
  Decisión 3 / plan.md, Constitution Check Principio II): la restricción de rol nueva aplica
  solo a un campo que no existía antes, no cambia comportamiento previo de nadie
- Los commits solo se ejecutan si el usuario lo pide explícitamente, en unidades pequeñas y
  lógicas, separadas por repo/capa, en inglés, sin marcas de autoría de IA (Principio XV)
