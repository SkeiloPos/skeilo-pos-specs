---

description: "Task list for feature implementation"
---

# Tasks: Nombre comercial propio para los tamaños de un producto

**Input**: Design documents from `/specs/099-nombre-tamano-variante/`
**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: incluidos — el plan y los contratos ya comprometen ficheros de test concretos
(Principio X, Verificación Obligatoria).

**Organización**: cuatro historias de usuario. US1 (comensal ve el nombre) y US2 (administrador
gestiona el nombre) son ambas P1 — complementarias, no una prerrequisito funcional de la otra,
pero comparten la base de Foundational (columna, migración, propiedad `display_name`). US3 (P2,
compatibilidad/migración) y US4 (P3, renombrar presentación) son mayormente verificación de un
comportamiento que Foundational/US1/US2 ya dejan correcto por diseño.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: se puede hacer en paralelo (archivo distinto, sin dependencia de una tarea sin terminar)
- **[Story]**: US1, US2, US3, US4

---

## Phase 1: Setup

- [X] T001 [P] Confirmar línea base en `pos-backend`: `cd ../pos-backend && ./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'` pasa en verde (memoria del proyecto: 1290 OK al 2026-10-03; úsese como referencia, no como número exacto esperado si ya cambió desde la spec 098) — confirmado: 1323 OK (2026-10-06)
- [X] T002 [P] Confirmar línea base en `pos-heladeria`: `npx ng test --watch=false` reproduce el mismo conjunto de fallos preexistentes ya documentado (19 pruebas en 6 archivos no relacionados: `app.spec`, `auth.service`, `menu.service`, `tenant.service`, `pos-checkout-panel`, `pos-order-panel`) — comparar por archivo, no por conteo literal — confirmado: mismos 6 archivos, 10 pruebas (2026-10-06)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: la columna `name`, su migración y la propiedad calculada `display_name` son la base
de la que dependen las cuatro historias ([data-model.md](./data-model.md), research.md D1/D2/D6).

**⚠️ CRITICAL**: ninguna historia puede verificarse de verdad sin esto.

- [X] T003 [P] Escribir tests en `pos-backend/app/characterization_tests/test_variant_display_name.py` (nuevo archivo): (a) la migración `e7d8c9b0a1f2_099_nombre_tamano_variante` deja `name=''` en toda variante existente sin tocar `presentation_id`/`price`/`display_order` (mismo patrón `importlib` que `test_variant_sin_nombre_migration.py`); (b) la propiedad `display_name` devuelve `name` si no está vacío, si no `presentation.name`, y si ninguno está disponible devuelve `"Tamaño"` registrando una advertencia con el id de la variante (usar `self.assertLogs(...)`, Escenario 16) — deben fallar antes de implementar (no existe el archivo de migración ni la columna) — hecho: confirmado `ImportError` antes de implementar. Nota de implementación: dado que la convención real del repo (research.md D12, confirmado al implementar) **no** escribe tests SQLite dedicados para migraciones puramente aditivas sin lógica de transformación (solo las que mueven/reescriben datos, como `test_variant_sin_nombre_migration.py`, llevan ese test — la aditiva equivalente de la spec 084, `a9f7d0310f6b`, no tiene uno), el archivo cubre en su lugar la forma de la columna a nivel de modelo ORM (que es lo que la migración también produce) más las 22 pruebas de `display_name`/normalización/duplicados/Historia 4 de abajo
- [X] T004 Crear `pos-backend/alembic/versions/e7d8c9b0a1f2_099_nombre_tamano_variante.py`: `upgrade()`/`downgrade()` aditivos y reversibles por schema de tenant, mismo patrón `@for_each_tenant_schema` + guardas `_has_table`/`_has_column` que `a9f7d0310f6b_084_variante_presentacion.py`; `down_revision = '2d50957395dc'` (cabecera actual); `op.add_column('product_variants', sa.Column('name', sa.String(60), nullable=False, server_default=''), schema=schema)` / `op.drop_column(...)` (data-model.md, research.md D6) — depende de T003 — hecho
- [X] T005 En `pos-backend/app/models/product_variant.py`: agregar `name: Mapped[str] = mapped_column(String(60), nullable=False, default="", server_default="")` (el `default` de Python además del `server_default`, mismo patrón que el campo `price` existente, para que una instancia recién creada sin flush también vea `""`) junto a los demás campos, y la propiedad `display_name` (con `logging.getLogger(__name__)` a nivel de módulo) debajo de `presentation_name` — depende de T004 — hecho
- [X] T006 Ejecutar T003, confirmar que ahora pasa; reejecutar toda la suite de `pos-backend` (comando de T001) y confirmar que sigue en la misma línea base (sin regresiones) — depende de T005 — hecho: 22/22 nuevos en verde; suite completa 1345 OK (1323 previos + 22 nuevos), sin regresiones. Se actualizaron además dos pruebas preexistentes de la spec 084 en `test_products_variant_presentation.py` (`SchemaSinNombreTests`) que afirmaban la ausencia total de `name` — ya no aplica (ver research.md, "Contexto histórico"); no son characterization tests `"CONGELA comportamiento actual:"`, así que su actualización no requiere una decisión de negocio aparte (Principio III)

**Checkpoint**: la columna existe, se migra sola y `display_name` se calcula correctamente —
verificable por separado con el test de T003, antes de tocar ninguna API ni pantalla.

---

## Phase 3: User Story 1 - El comensal ve el nombre comercial del tamaño, no uno vacío (Priority: P1) 🎯 MVP

**Goal**: el menú público (detalle, carrito, resumen de checkout) muestra `display_name` en vez de
`presentation_name`, incluida la insignia de condición de promociones ([contracts/product-variants-api.md](./contracts/product-variants-api.md), research.md D7/D8/D10).

**Independent Test**: con una variante cuyo `name` se fija directamente en la base/fixture de
prueba (sin pasar por el formulario — eso es US2), abrir el detalle del producto en el menú público
y verificar que muestra ese nombre; la variante sin `name` sigue mostrando la presentación.

### Tests for User Story 1

- [X] T007 [P] [US1] Escribir test en `pos-backend/app/characterization_tests/test_variant_display_name.py`: `GET /menu` (o el helper de `_build_menu` que ejercite el router) devuelve `display_name` por variante y conserva `presentation_name` sin cambios — debe fallar antes de implementar — hecho; usó `cart_fixtures.new_session()` (no `fixtures.new_session()`) porque `_build_menu` necesita el agregado `bool_or` (Postgres) que solo ese módulo registra como shim de SQLite
- [X] T008 [P] [US1] Escribir test en `pos-backend/app/characterization_tests/test_variant_display_name.py`: `variant_display_names()` resuelve el nombre propio de la variante antes que el de su presentación, en una sola consulta (sin N+1) — debe fallar antes de implementar — hecho
- [X] T009 [P] [US1] Escribir test en `pos-heladeria/src/app/core/services/menu.service.spec.ts`: un fixture de `MenuVariantResponse` con `display_name: "Para compartir"` y `presentation_name: "Grande 16 onz"` distintos debe mapear `MenuVariant.name = "Para compartir"`; otro con `display_name` ausente (backend viejo) debe caer a `presentation_name` — debe fallar antes de implementar — hecho; se agregó también el caso HTML del Escenario 13 en el mismo bloque
- [X] T010 [P] [US1] Escribir test en `pos-heladeria/src/app/modules/tables/services/diner.service.spec.ts`: mismo caso que T009, verificando el encadenamiento `v['display_name'] ?? v['presentation_name'] ?? v['name']` — debe fallar antes de implementar — hecho

### Implementation for User Story 1

- [X] T011 [US1] Agregar `display_name: str` a `MenuVariantResponse` en `pos-backend/app/api/v1/menu/schemas.py:64-89` (junto a `presentation_name`, sin quitarlo) y pasar `display_name=v.display_name` en la construcción de `pos-backend/app/api/v1/menu/router.py:191-196` — depende de T007 — hecho
- [X] T012 [US1] En `pos-backend/app/api/v1/promotions/service.py:459-482`, agregar `ProductVariant.name` a la proyección de `variant_display_names()` y aplicar la precedencia `name → presentation.name → product.name` (mismo `select()` de una sola consulta, sin cargar objetos ORM) — depende de T008 — hecho
- [X] T013 [US1] En `pos-heladeria/src/app/core/services/menu.service.ts`: agregar `display_name?: string` a la interfaz local `MenuVariantResponse` (línea 33-44) y cambiar el mapeo de `toCategory()` (línea ~138-139) a `name: v.display_name ?? v.presentation_name` — depende de T009 — hecho
- [X] T014 [US1] En `pos-heladeria/src/app/modules/tables/services/diner.service.ts`, cambiar `mapCategory()` (línea ~393-398) a `name: (v['display_name'] ?? v['presentation_name'] ?? v['name']) as string` — depende de T010 — hecho
- [X] T015 [US1] Confirmar (sin cambio de código esperado) que ningún lugar donde se pinte `MenuVariant.name`/`display_name` usa `[innerHTML]` en vez de interpolación `{{ }}` — si T009/T010 no lo cubrieron, añadir un caso con `name = "<b>x</b>"` a sus fixtures y verificar que el texto se renderiza escapado (Escenario 13) — depende de T013, T014 — hecho: confirmado por `grep`, el único `innerHTML` en el árbol de `tables`/`products` es introspección de un test (`product-form.component.spec.ts:631`), no un binding de plantilla
- [X] T016 [US1] Ejecutar T007-T010, confirmar que ahora pasan; reejecutar ambas suites completas (comandos de T001/T002) y confirmar que siguen en la misma línea base — depende de T011-T015 — hecho: backend 1349 OK; frontend 1494 pasan/10 fallan en los mismos 6 archivos de siempre (sin regresión, +4 tests nuevos sobre la línea base)

**Checkpoint**: Historia de Usuario 1 funciona de punta a punta — `quickstart.md` Historia 1
verificable (detalle, carrito, resumen de checkout, HTML escapado).

---

## Phase 4: User Story 2 - El administrador le pone, cambia o quita el nombre a un tamaño desde el formulario (Priority: P1) 🎯 MVP

**Goal**: "Tamaños del producto" gana el campo "Nombre (opcional)", con normalización, límite de
60 caracteres y rechazo de nombre duplicado dentro del producto
([contracts/variant-name-rules.md](./contracts/variant-name-rules.md),
[contracts/product-variants-api.md](./contracts/product-variants-api.md), research.md D3-D5/D9).

**Independent Test**: desde "Tamaños del producto", escribir un nombre, guardarlo y verificar que
persiste y se refleja en `GET /products/{id}` (`name`/`display_name`); borrar ese nombre y guardar
vuelve a mostrar la presentación; un nombre de 61 caracteres o repetido dentro del mismo producto
se rechaza sin guardar.

### Tests for User Story 2

- [X] T017 [P] [US2] Escribir tests en `pos-backend/app/characterization_tests/test_variant_display_name.py` para `normalize_variant_name()`: los 10 vectores de [contracts/variant-name-rules.md](./contracts/variant-name-rules.md) (ausente/`null` → `''`, solo espacios → `''`, recorte + colapso de espacios internos, 60 caracteres límite OK, 61 caracteres rechazado, HTML se guarda tal cual) — deben fallar antes de implementar — hecho
- [X] T018 [P] [US2] Escribir test en `pos-backend/app/characterization_tests/test_variant_display_name.py`: guardar una variante (vía el guardado consolidado de producto) con `name` válido persiste ese valor y `VariantResponse`/`VariantSaveOut` exponen `name` y `display_name`; una petición sin `name` o con `name: null` se guarda como `''` sin error (Escenario 14) — debe fallar antes de implementar — hecho
- [X] T019 [P] [US2] Escribir tests en `pos-backend/app/characterization_tests/test_variant_display_name.py`: dos variantes activas del mismo producto que resolverían al mismo `display_name` (nombre repetido, o nombre que coincide con la presentación de otra sin nombre) son rechazadas con 409 y `"Ya existe un tamaño con ese nombre en este producto"`, insensible a mayúsculas; una variante **desactivada** con esa misma etiqueta NO bloquea el guardado (Clarificación, sesión 2026-10-06) — deben fallar antes de implementar — hecho
- [X] T020 [P] [US2] Crear `pos-heladeria/src/app/shared/validators/variant-name.validator.spec.ts` (nuevo, mismo patrón que `full-name.validator.spec.ts`): los mismos 10 vectores de T017 contra `normalizeVariantName()` — debe fallar antes de implementar (el validador no existe) — hecho (implementado junto con T029 — función pura sin estado previo que "arreglar", no había un paso intermedio en rojo útil más allá del `ImportError` inicial)
- [X] T021 [P] [US2] Escribir tests en `pos-heladeria/src/app/modules/products/pages/product-form.component.spec.ts`: cada fila de "Tamaños del producto" tiene el campo "Nombre (opcional)"; el placeholder dice `Se mostrará: <presentación>` o `Se mostrará la presentación` según corresponda (Escenario 7); escribir 61 caracteres bloquea `canSave()` y muestra "El nombre admite hasta 60 caracteres" (Escenario 8) — deben fallar antes de implementar — hecho; también se actualizaron dos pruebas preexistentes de la spec 084 que afirmaban la ausencia total de un campo/columna "Nombre" (`'la tabla de tamaños no tiene columna ni campo "Nombre"'` y `'el guardado envía presentation_id y ningún name...'`) — no llevan ningún marcador de test protegido, así que se actualizaron igual que su contraparte en el backend
- [X] T022 [P] [US2] Escribir test en `pos-heladeria/src/app/modules/products/services/product.service.spec.ts`: el mapeo de `VariantDraft` hacia el payload de guardado y de la respuesta hacia `VariantDraft` incluyen `name` en ambas direcciones — debe fallar antes de implementar — hecho; además se corrigieron dos aserciones `toEqual` preexistentes del payload de guardado que no contemplaban el campo `name` nuevo

### Implementation for User Story 2

- [X] T023 [US2] Crear `pos-backend/app/core/variant_name.py`: `normalize_variant_name(value: str | None) -> str` según [contracts/variant-name-rules.md](./contracts/variant-name-rules.md) (mismo patrón que `person_name.py`) — depende de T017 — hecho
- [X] T024 [US2] En `pos-backend/app/api/v1/catalog/schemas.py`, agregar `name` a `VariantCreate`, `VariantUpdate` y `VariantSaveIn`, con un `@field_validator("name", mode="before")` que llame a `normalize_variant_name` y propague su `ValueError` — depende de T023 — hecho, con dos ajustes descubiertos al implementar: (1) `VariantCreate`/`VariantSaveIn` usan `Field(None, validate_default=True)`, no un `= None` simple — sin `validate_default=True` Pydantic nunca corre el validador cuando el campo se omite del payload, y el `None` del default llegaba intacto hasta la base (`NOT NULL constraint failed`); (2) `VariantUpdate.name` seguida mantiene `None` = "sin cambio" (como `price`/`active`/`presentation_id` en esa misma clase, que es un PATCH parcial) en vez de normalizar a `''` — para ese endpoint standalone, borrar el nombre requiere enviar `""` explícito, no `null`; `VariantSaveIn`/`VariantCreate` sí siguen FR-012 al pie de la letra porque son de reemplazo total, no PATCH parcial
- [X] T025 [US2] En `pos-backend/app/api/v1/catalog/schemas.py`, agregar `name: str` y `display_name: str` a `VariantResponse` (`from_attributes=True` ya los toma de las propiedades del modelo); `VariantSaveOut` los hereda, salvo en `products/service.py::to_save_response`, que los construye a mano (kwargs explícitos) y necesitó la misma adición ahí — depende de T024 — hecho
- [X] T026 [US2] En `pos-backend/app/api/v1/catalog/service.py`, agregar `display_name_duplicado(db, product_id, display_name, *, exclude_id=None)` (solo variantes `active=True`, comparación `.lower()`) y `_raise_display_name_conflict(index)` — mismo patrón 409 que `_ensure_sku_unique`, **sin** `variant_id` en el `detail` (research.md D5) — depende de T019 — hecho
- [X] T027 [US2] En `_save_variant_entry`, tras `_resolve_presentation`: calcular el `display_name` de esta entrada (`entry.name` normalizado o `presentation.name`), llamar a `display_name_duplicado`/`_raise_display_name_conflict` (solo si la entrada queda activa), y asignar `variant.name = entry.name` tanto al crear como al actualizar — depende de T026, T025 — hecho; además se aplicó el mismo chequeo en los endpoints standalone `create_variant`/`update_variant` de `catalog/router.py`, que no pasan por `_save_variant_entry`
- [X] T028 [US2] Ejecutar T017-T019, confirmar que ahora pasan; reejecutar toda la suite de `pos-backend` y confirmar sin regresiones — depende de T023-T027 — hecho: 1345 OK (ver nota de T006)
- [X] T029 [US2] Crear `pos-heladeria/src/app/shared/validators/variant-name.validator.ts`: `normalizeVariantName()`, réplica exacta del algoritmo de T023 — depende de T020 — hecho (sin el wrapper `ValidatorFn` de `full-name.validator.ts`: este formulario no usa Reactive Forms, es `[ngModel]`/señales, así que la función pura basta)
- [X] T030 [US2] Agregar `name?: string` a `VariantDraft`/`VariantSavePayload` (`product.interface.ts`) y mapearlo en ambas direcciones en `product.service.ts` — depende de T022, T029 — hecho; descubierto al implementar: `getProductDraft` lee en realidad de un `Variant[]` intermedio (`toVariant()`, no el `VariantResponse` crudo), que también necesitó `name`/`display_name` nuevos en su propia interfaz
- [X] T031 [US2] En `pos-heladeria/src/app/modules/products/pages/product-form.component.ts`: ampliar la grilla de "Tamaños del producto" con una celda "Nombre (opcional)" ligada a `setVariantField(v.localId, 'name', $event)`; agregar `variantNamePlaceholder(v)` para el placeholder dinámico; agregar el `computed` `variantNameError()` (longitud + duplicado insensible a mayúsculas) y restarlo de `canSave()` — depende de T030, T021 — hecho
- [X] T032 [US2] Ejecutar T020-T022, confirmar que ahora pasan; reejecutar toda la suite de `pos-heladeria` y confirmar sin regresiones — depende de T029-T031 — hecho: 1513 pasan/10 fallan en los mismos 6 archivos de siempre (sin regresión, +19 tests nuevos)

**Checkpoint**: Historia de Usuario 2 funciona de punta a punta — `quickstart.md` Historia 2
verificable (campo, placeholder, límite, duplicado, borrar nombre, API sin el campo).

---

## Phase 5: User Story 3 - Los datos y los clientes existentes no se rompen con el cambio (Priority: P2)

**Goal**: confirmar que la migración, la API y los pedidos ya existentes se comportan exactamente
como `spec.md` exige, sin que haga falta ningún código nuevo más allá de Foundational/US1/US2
(research.md D11).

**Independent Test**: ejecutar la migración sobre datos existentes y el downgrade; consumir
`GET /menu` ignorando `display_name` como haría un frontend viejo; abrir un pedido anterior al
cambio en Órdenes/Ventas.

- [X] T033 [P] [US3] Ampliar `pos-backend/app/characterization_tests/test_variant_display_name.py` con el caso de reversibilidad (Escenario 18): aplicar `upgrade()` y luego `downgrade()` del módulo de T004 sobre SQLite en memoria, confirmar que la columna `name` ya no existe y que `presentation_id`/`price`/`display_order` siguen intactos — depende de T006 — **ajustado al implementar**: igual que `a9f7d0310f6b_084_variante_presentacion.py` (la migración aditiva comparable), `upgrade`/`downgrade` quedan decorados con `@for_each_tenant_schema`, que exige `CREATE SCHEMA`/`shared.tenants` reales — sintaxis que SQLite no soporta y que ninguna migración puramente aditiva de este repo prueba por esa vía (ninguna tiene un test dedicado, a diferencia de las que sí mueven datos, como `c7e2b91a4d35`). Verificado en su lugar: `alembic heads` confirma una sola cabecera (`e7d8c9b0a1f2`) encadenada correctamente a `2d50957395dc`, y el módulo importa sin error con `DATABASE_URL` de relleno; la forma de la columna que produce la migración ya está cubierta por `ColumnaNameTests` (mismo tipo/nulabilidad que el modelo ORM declara). No hay Postgres disponible en este entorno para una verificación en vivo de `upgrade`/`downgrade` — pendiente para el despliegue real, documentado en quickstart.md
- [X] T034 [P] [US3] Escribir/ejecutar un test de compatibilidad (`pos-backend/app/characterization_tests/test_variant_display_name.py` o uno de menú existente): una respuesta de `GET /menu` que un consumidor solo lee por `presentation_name` (ignorando `display_name` por completo) sigue teniendo ese campo con el mismo significado y sin error — Escenario 15 — depende de T016 — hecho: ya cubierto por `MenuPublicoDisplayNameTests` (Foundational/US1), que verifica `presentation_name` sin cambios en ambos casos (con y sin nombre propio); confirmado además en el frontend por el test "cae a `presentation_name` si `display_name` viene ausente" de `menu.service.spec.ts` y el equivalente de `diner.service.spec.ts`
- [X] T035 [US3] Confirmar, por inspección (sin cambio de código), que `format_item_description`, `orders/checkout.py`, `sales/service.py` y las pantallas de Órdenes/Ventas de `pos-heladeria` siguen sin referenciar `name`/`display_name` tras T001-T034 — depende de T033, T034 — hecho: `git diff --stat develop..feat/099-variant-display-name` sobre esos archivos/carpetas (ambos repos) no muestra ningún cambio

**Checkpoint**: Historia de Usuario 3 verificada — `quickstart.md` Historia 3 completa.

---

## Phase 6: User Story 4 - Renombrar una presentación no toca los nombres propios ya puestos (Priority: P3)

**Goal**: confirmar que el diseño de `display_name` (Foundational, D2 — calculado en cada lectura,
nunca persistido) ya resuelve este caso sin necesitar código adicional.

**Independent Test**: con una variante sin nombre propio y otra con nombre propio usando la misma
presentación, renombrar la presentación y verificar que solo la primera cambia.

- [X] T036 [P] [US4] Escribir test en `pos-backend/app/characterization_tests/test_variant_display_name.py`: dos variantes del mismo producto, una sin `name` propio y otra con `name` propio (cada una con su propia `Presentation`); tras renombrar la presentación de la primera (sin tocar las variantes), la primera resuelve el nuevo `display_name` y la segunda conserva el suyo sin cambios — este test debe **pasar sin ningún cambio de código** adicional al de Foundational, porque `display_name` nunca se persiste — hecho: `RenombrarPresentacionNoTocaNombrePropioTests`, verde desde que se escribió (ver nota de T037)
- [X] T037 [US4] Confirmar T036 en verde y documentar en el propio test que valida el diseño de Foundational (D2), no una implementación nueva — depende de T036 — hecho: pasó en el primer run de la suite completa de T003/T006 (26→22 tests en ese momento), sin requerir ningún cambio de código adicional — confirma que D2 (propiedad calculada, no persistida) ya cubre este caso por diseño

**Checkpoint**: Historia de Usuario 4 verificada — `quickstart.md` Historia 4 completa.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [X] T038 [P] Ejecutar `quickstart.md` completo de punta a punta (Historias 1-4 + Escenario 16) contra `pos-backend`/`pos-heladeria` corriendo localmente — **cubierto por la suite automatizada, no por una sesión manual en navegador**: no hay servidor/navegador interactivo disponible en este entorno (misma limitación que la spec 097, T014). Cada escenario de `quickstart.md` tiene un test equivalente en `test_variant_display_name.py` (backend) o en los `*.spec.ts` tocados (frontend); las 1350 pruebas de `pos-backend` y las 1513 de `pos-heladeria` (sin regresión sobre la línea base de T001/T002) son la evidencia de que pasan
- [X] T039 [P] Verificar el Escenario 17 (FR-018): sembrar un tenant con 40 productos × 3 variantes, confirmar que el número de consultas SQL de `GET /menu` no crece respecto a la línea base, y que el mismo endpoint consultado desde el subdominio de otro tenant no devuelve nada de estos datos — hecho: `RendimientoMenuPublicoTests` (nuevo) cuenta las consultas SQL con `sqlalchemy.event` y confirma el mismo número con 2×1 variantes que con 40×3 (120 variantes). El aislamiento por tenant no se verifica con un test nuevo: es la arquitectura de esquema-por-tenant ya existente (`with_db`/`schema_translate_map`), que esta spec no toca en absoluto — ningún código nuevo de la spec 099 participa en la resolución de qué tenant responde
- [X] T040 Avisar al usuario antes de cualquier commit (Principio XV — nunca por iniciativa propia) y antes de crear la rama `feat/099-variant-display-name` en `pos-backend`/`pos-heladeria` si aún no existe (Principio XIV) — hecho: la rama `feat/099-variant-display-name` se creó en ambos repos al iniciar la implementación (confirmado con el usuario antes de empezar, ver "Alcance de implementación"); ningún commit se ha hecho en ninguno de los dos repos — pendiente del pedido explícito del usuario

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias — ambas tareas en paralelo.
- **Foundational (Phase 2)**: depende de Setup — BLOQUEA las cuatro historias.
- **User Story 1 (Phase 3)** y **User Story 2 (Phase 4)**: ambas dependen solo de Foundational
  completo; son independientes entre sí (pueden avanzar en paralelo, incluso por personas
  distintas).
- **User Story 3 (Phase 5)**: depende de Foundational; sus tareas T034/T035 además dependen de que
  US1 esté completa (verifica la respuesta de `GET /menu` que US1 modifica).
- **User Story 4 (Phase 6)**: depende solo de Foundational (ejercita `display_name` directamente
  sobre el modelo, sin pasar por US1/US2).
- **Polish (Phase 7)**: depende de que las cuatro historias estén completas.

### Dentro de cada fase

- Tests se escriben y deben fallar antes de implementar (excepto T036/T037, que validan un
  comportamiento que Foundational ya debe dejar correcto por diseño).
- Backend: módulo de normalización (T023) antes de los esquemas (T024), antes del servicio
  (T026-T027). Modelo/migración (T004-T005) antes de cualquier esquema o router que lea
  `display_name` (T011, T025).
- Frontend: validador (T029) antes de la interfaz de dominio (T030), antes del componente que la
  consume (T031) — mismo orden que ya siguió la spec 097 para `category_name`.

### Parallel Opportunities

- T001/T002 (Setup) en paralelo.
- T007-T010 (tests de US1, archivos distintos) en paralelo; T011-T012 (backend) pueden ir en
  paralelo con T013-T014 (frontend) una vez sus respectivos tests existen.
- T017-T022 (tests de US2, archivos distintos) en paralelo.
- US1 (Phase 3) y US2 (Phase 4) completas pueden avanzar en paralelo entre sí tras el Checkpoint de
  Foundational.
- T033/T034 (US3) y T036 (US4) en paralelo entre sí.

---

## Parallel Example: Foundational

```bash
# T003 se escribe en solitario (un único archivo nuevo); T004-T005 quedan secuenciales porque
# ambos construyen la misma cadena migración → columna → propiedad.
Task: "Escribir tests de migración y de display_name en test_variant_display_name.py"
```

## Parallel Example: User Story 1

```bash
# Tests de US1 en paralelo (archivos distintos):
Task: "Test backend: GET /menu expone display_name (menu/router.py)"
Task: "Test backend: variant_display_names() usa display_name (promotions/service.py)"
Task: "Test frontend: menu.service.ts mapea display_name a MenuVariant.name"
Task: "Test frontend: diner.service.ts mapea display_name a MenuVariant.name"
```

## Parallel Example: User Story 2

```bash
# Tests de US2 en paralelo (archivos distintos):
Task: "Test backend: normalize_variant_name() (vectores del contrato)"
Task: "Test backend: guardar variante con name persiste name/display_name"
Task: "Test backend: display_name duplicado entre activas, insensible a mayúsculas"
Task: "Test frontend: normalizeVariantName() (mismos vectores)"
Task: "Test frontend: campo 'Nombre (opcional)', placeholder, límite de 60"
Task: "Test frontend: product.service.ts mapea name ida y vuelta"
```

---

## Implementation Strategy

### MVP (User Story 1 + User Story 2 — ambas P1)

1. Completar Phase 1: Setup (línea base de ambos repos).
2. Completar Phase 2: Foundational (CRÍTICO — bloquea las cuatro historias).
3. Completar Phase 3 (US1) y Phase 4 (US2) — en paralelo si hay capacidad, o US1 primero si se
   prefiere ver el efecto en el menú público antes de construir el formulario.
4. **DETENER y VALIDAR**: correr `quickstart.md` Historias 1 y 2.
5. Avisar al usuario antes de cualquier commit (Principio XV) y antes de crear la rama
   `feat/099-variant-display-name` si aún no existe (Principio XIV).

### Incremental Delivery

1. Setup + Foundational → base lista.
2. US1 → validar independientemente → demo (ya se ve el efecto en el menú público, con datos
   sembrados directamente).
3. US2 → validar independientemente → el administrador ya puede producir ese dato desde la
   pantalla real.
4. US3 → validar migración/compatibilidad (puede correrse tan pronto Foundational está lista; sus
   dos últimas tareas esperan a US1).
5. US4 → validar que renombrar una presentación no rompe nada (prueba de diseño, no de
   implementación nueva).
6. Polish → `quickstart.md` completo + verificación de rendimiento/aislamiento (Escenario 17).

## Notes

- [P] = archivos distintos, sin dependencias entre sí.
- [US1]/[US2]/[US3]/[US4] mapean cada tarea a su historia de usuario.
- Verificar que los tests fallan antes de implementar (excepto T036/T037, ver arriba).
- No commitear salvo pedido explícito del usuario (Principio XV); cuando se commitee, en commits
  pequeños y enfocados, en inglés, sin ninguna marca de IA.
- Evitar: tocar `format_item_description`, `orders/checkout.py`, `sales/service.py` o cualquier
  pantalla de Órdenes/Ventas (fuera de alcance, research.md D11); reabrir la columna `name` que la
  spec 084 eliminó como clave estructural (esta spec agrega una columna distinta, puramente
  cosmética); hacer `name`/`display_name` campos **obligatorios** en interfaces TS muy usadas
  (`MenuVariant`, `VariantDraft`) — deben quedar opcionales con default seguro, para no romper
  fixtures de tests no relacionados (memoria del proyecto).
