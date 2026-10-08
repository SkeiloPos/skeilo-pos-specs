---

description: "Task list for feature implementation"
---

# Tasks: Consolidar receta y grupos de opciones en el detalle de producto (sin peticiones por tamaño)

**Input**: Design documents from `/specs/103-detalle-producto-consolidado/`
**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: incluidos — el plan y el contrato ya comprometen ficheros de test concretos (Principio
X, Verificación Obligatoria).

**Organización**: una sola historia de usuario (US1, P1), pero a diferencia de las specs 097/098/102
(100% frontend) esta spec toca **ambos repos**. La Fase 2 (Foundational) es el trabajo de backend
(`pos-backend`): sin él, el frontend no tiene nada nuevo que consumir. US1 (Fase 3) es
exclusivamente frontend (`pos-heladeria`): consumir los datos embebidos y retirar el código que
queda inalcanzable como consecuencia directa (research.md D5, spec FR-009).

**Hallazgo importante al investigar** (ver research.md): el test
`app/characterization_tests/test_product_detail_variants.py::test_detalle_no_expone_receta_ni_grupos_de_opciones`
ya existe y hoy afirma exactamente lo **contrario** de lo que esta spec pide (que `GET
/products/{id}` nunca exponga receta/grupos). No lleva el prefijo `"CONGELA comportamiento
actual:"` (no es un characterization test protegido por el Principio III), así que puede
actualizarse como cualquier test ordinario — pero su reemplazo debe seguir demostrando la mitad de
FR-018 que sí sigue vigente (Cajero nunca ve receta), no solo borrarse.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: se puede hacer en paralelo (archivo distinto, sin dependencia de una tarea sin terminar)
- **[Story]**: US1

---

## Phase 1: Setup

- [X] T001 Confirmar línea base en **ambos** repos (a diferencia de la spec 102, esta sí toca
  backend): `cd ../pos-backend && ./env/bin/python -m unittest discover -s
  app/characterization_tests -p 'test_*.py'` (venv del proyecto, no el `python` de Anaconda —
  ver memoria del proyecto) y `cd ../pos-heladeria && npx ng test --watch=false` (comparar por
  conjunto de archivos con fallos preexistentes, no por conteo literal). Confirmado 2026-10-08:
  backend 1474 OK (un primer intento mostró 1 error de colisión de número de mesa aleatorio,
  no relacionado y no reproducible en una segunda corrida — línea base real: 1474 OK, 0 fallos);
  frontend 10 fallos en los mismos 6 archivos preexistentes (1569 OK), misma línea base que las
  specs 097/098/102

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: ampliar `GET /products/{id}` para que incluya `recipe`/`option_groups` por variante,
con carga ansiosa (research.md D2) y ocultos para el rol Cajero (D3). Es prerrequisito de US1: el
frontend no tiene nada nuevo que consumir hasta que esto exista.

**⚠️ CRITICAL**: ninguna tarea de US1 puede verificarse de verdad sin esto.

- [X] T002 [P] Reescribir `pos-backend/app/characterization_tests/test_product_detail_variants.py`:
  actualizar las llamadas a `self.service.to_detail_response(product)` para pasar también un
  `user` (nuevo parámetro, ver T006) en `test_detalle_incluye_presentaciones_activas_con_precio`
  (usar un usuario Admin — sin cambio de comportamiento esperado para ese test); **reemplazar**
  `test_detalle_no_expone_receta_ni_grupos_de_opciones` por dos tests nuevos usando
  `fx.make_tenant`/`fx.make_role`/`fx.make_user` (mismo patrón que
  `test_products_cashier_forbidden.py`) y `fx.make_inventory_item`/`fx.make_recipe_item`/
  `fx.make_option_group`/`fx.link_variant_group` (ya reexportados por
  `product_availability_fixtures.py`) para dar a una variante un insumo fijo y un grupo de
  opciones: (a) pedido por un usuario Admin, `detail.variants[0].recipe` y `.option_groups` vienen
  poblados con el contenido esperado; (b) pedido por un usuario con rol `"CASHIER"`,
  `detail.variants[0].recipe == []` pero `.option_groups` sigue poblado — debe fallar antes de
  implementar (hoy `to_detail_response` no acepta `user` y `VariantResponse` no tiene esos campos)
- [X] T003 Agregar, en el mismo archivo de T002, un test con un producto de **3 variantes
  activas**, cada una con su propio insumo fijo y grupo de opciones distintos, pedido por un
  usuario Admin: confirma que las 3 variantes (no solo la primera) traen su `recipe`/
  `option_groups` propios y correctos — guarda contra un error de carga ansiosa que solo
  materialice la primera variante de la lista — debe fallar antes de implementar (depende del
  mismo cambio de T002, mismo archivo, no paralelizable con T002)

### Implementation for Foundational

- [X] T004 Agregar `VariantDetailResponse(VariantResponse)` en
  `pos-backend/app/api/v1/products/schemas.py`: `recipe: list[RecipeItemResponse] =
  Field(default_factory=list)`, `option_groups: list[VariantOptionGroupResponse] =
  Field(default_factory=list)` (ambos tipos ya existen en `catalog/schemas.py`, sin cambios);
  cambiar `ProductDetailResponse.variants` de `list[VariantResponse]` a
  `list[VariantDetailResponse]` — depende de T002, T003
- [X] T005 En `pos-backend/app/api/v1/products/service.py`: agregar un método nuevo (p. ej.
  `get_detail_or_404`) que reemplace, solo para este camino, el `db.get()` de `get_or_404` por
  `select(Product).where(Product.id == id).options(selectinload(Product.variants).
  selectinload(ProductVariant.recipe_items), selectinload(Product.variants).
  selectinload(ProductVariant.option_groups))` (mismo patrón que ya usa `menu/router.py:109-114`);
  cambiar la firma de `to_detail_response(product)` a `to_detail_response(product, user)` y
  construir cada `VariantDetailResponse` poblando `recipe` solo si `user.role.name != "CASHIER"`
  (si no, `[]`) y `option_groups` siempre, reutilizando el mismo mapeo que ya usa
  `to_save_response` (`RecipeItemResponse.model_validate(r) for r in v.recipe_items`,
  `VariantOptionGroupResponse.model_validate(g) for g in v.option_groups`) — depende de T004
- [X] T006 En `pos-backend/app/api/v1/products/router.py`, actualizar el handler `get_product`
  para usar `get_detail_or_404` (T005) y pasar el `user` ya resuelto por `get_current_user` a
  `to_detail_response(product, user)` — depende de T005
- [X] T007 Ejecutar T002 y T003, confirmar que ahora pasan; reejecutar la suite de
  `pos-backend` (comando de T001) y confirmar que sigue en la misma línea base — depende de
  T004, T005, T006. Confirmado 2026-10-08: 4/4 tests en verde en
  `test_product_detail_variants.py`; suite completa 1476 OK (1474→1476, neto +2: se agregaron 3
  tests nuevos y se reemplazó 1 que afirmaba el comportamiento contrario)

**Checkpoint**: `GET /products/{id}` ya devuelve receta y grupos de opciones embebidos, con el
resguardo de rol correcto. US1 solo necesita consumirlo.

---

## Phase 3: User Story 1 - Abrir el formulario de edición no dispara peticiones adicionales por cada tamaño (Priority: P1) 🎯 MVP

**Goal**: el formulario de edición de producto consume la receta y los grupos de opciones ya
embebidos en la respuesta de detalle, sin disparar ninguna petición adicional por tamaño; el
control de "Reintentar" por tamaño (spec 102) se retira por quedar sin escenario (FR-009).

**Independent Test**: con las herramientas de red del navegador abiertas, abrir el formulario de
edición de un producto con 5 o más tamaños y verificar que no se dispara ninguna petición a los
endpoints de receta o grupos de opciones por tamaño (quickstart.md, Escenarios 1 y 2).

### Tests for User Story 1

- [ ] T008 [P] [US1] Actualizar `pos-heladeria/src/app/modules/products/services/product.service.spec.ts`:
  con una respuesta de `GET /products/{id}` cuyas `variants[]` ya incluyen `recipe`/
  `option_groups` (mock de 3+ variantes, cada una con su propio contenido), `getProductDraft()`
  mapea ese contenido directamente a cada `VariantDraft` **sin** disparar ninguna petición a `GET
  /variants/{id}/recipe` ni `GET /variants/{id}/option-groups` para esas variantes — la única
  petición adicional sigue siendo `GET /products/{id}/variants` (sin filtro), para las
  desactivadas — debe fallar antes de implementar (hoy siempre dispara esas peticiones por
  variante)
- [X] T009 [P] [US1] Actualizar `pos-heladeria/src/app/modules/products/pages/product-form.component.spec.ts`:
  (a) retirar o adaptar los tests de la spec 102 que dependían de `loadError`/
  `retryVariantLoad()`/`retryVariant()` (la carga en paralelo que fallaba por variante ya no
  existe, research.md D5); (b) agregar un test que confirme que, incluso si se simula un error en
  la respuesta de `GET /products/{id}`, el formulario no contiene ningún control de texto
  "Reintentar" a nivel de un tamaño individual — debe fallar antes de implementar. **Nota**:
  también se actualizó el helper compartido `createEdit()` (usado por decenas de tests) y 3 tests
  independientes de la Historia 1/D4 de la spec 102 que flusheaban `GET /products/{id}` sin
  `variants[]` -- todos necesitaban el nuevo campo embebido para no romperse con el cambio de
  T011
- [X] T010 [US1] Confirmar (sin cambios esperados) que las pruebas existentes de `restoreVariant()`
  en el mismo archivo de T009 siguen disparando `GET /variants/{id}/recipe` y `GET
  /variants/{id}/option-groups` para una sola variante al restaurar un tamaño desactivado — guarda
  de regresión de FR-006, no requiere cambios de código. Confirmado: siguen en verde sin
  modificaciones

### Implementation for User Story 1

- [X] T011 [US1] En `pos-heladeria/src/app/modules/products/services/product.service.ts`: extender
  la interfaz interna del `VariantResponse` crudo del backend con `recipe`/`option_groups`
  (mismas formas que ya usan `fetchVariantRecipeRaw`/`fetchVariantOptionGroupsRaw`); reescribir
  `getProductDraft()` para construir cada `VariantDraft` (de una variante activa) leyendo
  `recipe`/`option_groups` directamente de la respuesta de `GET /products/{id}`, eliminando el
  bloque `Promise.allSettled(activeVariants.map(...))` que disparaba las peticiones por variante
  (research.md D4); `loadVariants()` y la separación de variantes desactivadas NO cambian — depende
  de T008. **Evolucionó (ver T019, research.md D6, 2026-10-08)**: tras completarse esta tarea se
  pidió además retirar la llamada a `GET /products/{id}/variants` que `getProductDraft()` seguía
  haciendo solo para las desactivadas — la afirmación "NO cambian" de este enunciado quedó
  superada; ver T019 para el cambio real aplicado
- [X] T012 [US1] En el mismo archivo, eliminar `ProductService.retryVariant()` (research.md D5:
  sin `loadError`, queda sin ningún llamador) — depende de T011
- [X] T013 [US1] Eliminar el campo `VariantDraft.loadError` de
  `pos-heladeria/src/app/modules/products/interfaces/product.interface.ts` — depende de T011
- [X] T014 [US1] En `pos-heladeria/src/app/modules/products/pages/product-form.component.ts`,
  eliminar `retryVariantLoad()` y el bloque `@if (v.loadError)` de la plantilla (el control
  "Reintentar" por tamaño) — depende de T012, T013
- [X] T015 [US1] Ejecutar T008 y T009, confirmar que ahora pasan (y que T010 sigue en verde);
  reejecutar toda la suite de `pos-heladeria` y confirmar que sigue en la misma línea base —
  depende de T011, T012, T013, T014. Confirmado 2026-10-08: product.service.spec.ts 25/25,
  product-form.component.spec.ts 56/56; suite completa en línea base (10 fallos, mismos 6
  archivos preexistentes; 1569→1568, neto -1 por la consolidación de tests de ambos archivos)

**Checkpoint**: Historia de Usuario 1 funciona de punta a punta — quickstart.md Escenarios 1, 2, 3,
5 y 6 verificables.

---

## Phase 4: Polish & Cross-Cutting Concerns

- [X] T016 Ejecutar manualmente (o con un script de siembra) `quickstart.md` completo contra
  `pos-backend`/`pos-heladeria` corriendo en local, en particular el Escenario 4 (Cajero nunca
  recibe receta, revisado en el panel de red del navegador) y el Escenario 7 (API directa con
  `curl`). Si el entorno no tiene PostgreSQL local ni navegador disponible (misma limitación
  documentada para las specs 098/102), apoyarse en la evidencia de T002/T003 (backend) y
  T008/T009 (frontend) como verificación parcial, más `npx ng build --configuration=production` y
  una verificación de que `pos-backend` importa sin errores (`./env/bin/python -c "from
  app.api.v1.products import router"` o equivalente). **Verificación parcial** (2026-10-08): sin
  PostgreSQL/navegador en este entorno. `npx ng build --configuration=production` compiló sin
  errores (mismos warnings preexistentes de budget/`qrcode`); `./env/bin/python -c "from
  app.api.v1.products import router"` importó sin errores; los Escenarios 1-6 ya quedan
  demostrados por T002/T003 (backend, incluido el resguardo de rol) y T008/T009 (frontend, cero
  peticiones por variante). Queda pendiente, si se desea cerrar en vivo, levantar un Postgres
  desechable (ver memoria del proyecto)
- [X] T017 Confirmar que `GET /menu` (`pos-backend/app/api/v1/menu/router.py`) no recibió ningún
  cambio (`git diff --stat`) y que su suite de characterization tests sigue en verde — esta spec
  no toca el menú público del comensal. Confirmado: `git diff --stat` sobre `app/api/v1/menu/` no
  muestra cambios; suite completa 1476 OK incluye sus tests
- [X] T018 Confirmar que `GET /variants/{id}/recipe` y `GET /variants/{id}/option-groups`
  (`pos-backend/app/api/v1/catalog/router.py:189-222`) no recibieron ningún cambio (`git diff
  --stat`), y que `restoreVariant()` sigue siendo su único consumidor restante en
  `pos-heladeria` (`grep` de ambos endpoints en `src/app`). Confirmado: `git diff --stat` sobre
  `app/api/v1/catalog/` no muestra cambios; único consumidor restante confirmado por `grep`

---

## Ajuste posterior (research.md D6, 2026-10-08)

Tras completarse T001-T018 y validar el quickstart, el dueño/desarrollador del proyecto observó en
el panel de red del navegador que `GET /products/{id}/variants` seguía disparándose al abrir el
formulario (para las desactivadas, T011) y pidió retirarla por considerarla redundante con el
detalle ya embebido. Investigar confirmó que ese endpoint sí cubría algo que el detalle no traía
(las desactivadas) — la solución fue agregar ese dato al propio detalle, no perder la función de
restaurar un tamaño.

- [X] T019 Agregar `deactivated: list[VariantResponse]` a `ProductDetailResponse`
  (`pos-backend/app/api/v1/products/schemas.py`), poblado en `to_detail_response()`
  (`pos-backend/app/api/v1/products/service.py`) con `[v for v in product.variants if not
  v.active]` — reutiliza la misma relación `product.variants` que T005 ya precarga, cero
  consultas nuevas. En `pos-heladeria/src/app/modules/products/services/product.service.ts`,
  `getProductDraft()` deja de llamar a `GET /products/{id}/variants`: construye `draft.deactivated`
  directamente de `raw.deactivated`. `loadVariants()`/`loadDeactivated()` no se eliminan — siguen
  disponibles para otros puntos del formulario (p. ej. tras un conflicto de nombre al guardar); el
  flujo de restaurar una variante (`ProductFormComponent.restoreVariant()`, vía
  `service.getVariantRecipe()`/`service.getVariantOptionGroups()`) no cambia — depende de T005,
  T011. Confirmado 2026-10-08: `test_product_detail_variants.py` ampliado con un test que verifica
  que las desactivadas llegan en `deactivated` sin pedirlas por separado (suite backend completa en
  verde); `product.service.spec.ts` y `product-form.component.spec.ts` actualizados (ya no
  flushean una petición separada a `/variants` en sus mocks de `getProductDraft()`), suite
  frontend en la misma línea base que T015; `npx ng build --configuration=production` compiló sin
  errores

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias.
- **Foundational (Phase 2)**: depende de Setup — BLOQUEA User Story 1 (el frontend no tiene nada
  nuevo que consumir sin el backend ampliado).
- **User Story 1 (Phase 3)**: depende de Foundational completo (T002-T007).
- **Polish (Phase 4)**: depende de que Foundational y US1 estén completos.

### Dentro de cada fase

- T002 y T003 (Foundational) comparten archivo — T003 no es paralelo a T002.
- T004 (schema) antes de T005 (servicio, usa el tipo nuevo) antes de T006 (router, usa el método
  nuevo del servicio).
- T011 (servicio) antes de T012 (elimina método del mismo servicio) y antes de T013/T014 (el
  componente deja de usar `loadError`/`retryVariantLoad` solo después de que el servicio ya no
  los necesite).

### Parallel Opportunities

- T008 y T009 (US1, archivos distintos) en paralelo entre sí una vez completada Foundational.
- T013 (interfaz) puede hacerse en paralelo con T012 (mismo servicio, archivo distinto) — ambas
  dependen de T011, no entre sí.

---

## Parallel Example: User Story 1

```bash
# T008 y T009 son archivos distintos sin dependencia entre sí:
Task: "Test de getProductDraft() con datos embebidos en product.service.spec.ts"
Task: "Test de ausencia del control 'Reintentar' en product-form.component.spec.ts"
```

---

## Implementation Strategy

### MVP First (única historia)

1. Completar Phase 1: Setup.
2. Completar Phase 2: Foundational (CRÍTICO — bloquea la única historia de esta spec).
3. Completar Phase 3: User Story 1.
4. **DETENER y VALIDAR**: correr quickstart.md completo.
5. Esta spec se entrega como una sola unidad: no hay historias adicionales que escalonar.

### Parallel Team Strategy

Con dos desarrolladores: uno completa Foundational (backend) mientras el otro prepara los tests de
US1 (T008/T009, que pueden escribirse contra el contrato ya documentado en
`contracts/products-detail-embedded.md` sin esperar a que el backend estéListo); la
implementación de US1 (T011-T014) sí espera a que Foundational esté completo.

## Notes

- [P] = archivos distintos, sin dependencias entre sí.
- [US1] mapea la tarea a la única historia de usuario de esta spec.
- Verificar que los tests fallan antes de implementar.
- No commitear salvo pedido explícito del usuario (Principio XV); cuando se commitee, en commits
  pequeños y enfocados, en inglés, sin ninguna marca de IA. Crear la rama
  `perf/103-detalle-producto-consolidado` en **ambos** repos (`pos-backend` y `pos-heladeria`)
  antes de tocar código (Principio XIV).
- Evitar: tareas vagas, conflictos de archivo simultáneos, tocar `VariantResponse` directamente
  (research.md D1 — usar `VariantDetailResponse`, un tipo nuevo), tocar `GET /menu` o su
  `selectinload` propio, tocar `GET /variants/{id}/recipe`/`GET /variants/{id}/option-groups` (se
  mantienen intactos para `restoreVariant()`, FR-006), dejar `loadError`/`retryVariantLoad()`/
  `retryVariant()` inertes en vez de retirarlos (research.md D5), cambiar la forma en que se
  guarda el producto (FR-007).
