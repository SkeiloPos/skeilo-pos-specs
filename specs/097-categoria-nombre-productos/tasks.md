---

description: "Task list for feature implementation"
---

# Tasks: Corrección — el nombre de categoría de un producto no depende de la paginación de `GET /categories`

**Input**: Design documents from `/specs/097-categoria-nombre-productos/`
**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: incluidos — el plan y los contratos ya comprometen ficheros de test concretos
(Principio X, Verificación Obligatoria).

**Organización**: una sola historia de usuario (US1, P1). El cambio de servidor (`pos-backend`:
propiedad `category_name`, `JOIN` en `list_query`, campo nuevo en `ProductResponse`) es la base de
la que depende todo lo demás — vive en Foundational, junto con su test de characterization. US1
cubre exclusivamente el consumo en `pos-heladeria` (quitar `categoryMap`/`categoryName()`, enlazar
`product.category_name`).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: se puede hacer en paralelo (archivo distinto, sin dependencia de una tarea sin terminar)
- **[Story]**: US1

---

## Phase 1: Setup

- [X] T001 [P] Confirmar línea base en `pos-backend`: `cd ../pos-backend && ./env/bin/python -m unittest discover -s app/characterization_tests -p 'test_*.py'` pasa en verde (memoria del proyecto: 1290 OK al 2026-10-03; úsese como referencia, no como número exacto esperado si ya cambió)
- [X] T002 [P] Confirmar línea base en `pos-heladeria`: `npx ng test --watch=false` reproduce el mismo conjunto de fallos preexistentes ya documentado (19 pruebas en 6 archivos no relacionados: `app.spec`, `auth.service`, `menu.service`, `tenant.service`, `pos-checkout-panel`, `pos-order-panel`) — comparar por archivo, no por conteo literal

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: resolver `category_name` en el servidor — es la base de la que depende US1; sin
esto, el frontend no tiene ningún dato nuevo que consumir ([contracts/products-api.md](./contracts/products-api.md), research.md D1-D4).

**⚠️ CRITICAL**: ninguna parte de US1 puede verificarse de verdad sin esto.

- [X] T003 [P] Escribir test en `pos-backend/app/characterization_tests/test_products_service.py` (o archivo de characterization equivalente de `products`): sembrar >100 categorías activas y un producto cuya categoría quede fuera de las primeras 100 por orden alfabético; llamar `ProductService().list_query(...)` paginado (vía `paginate()`) y verificar que el `Product` devuelto permite resolver `category_name` igual al `name` real de su categoría, sin ninguna consulta adicional a `GET /categories` — debe fallar antes de implementar (data-model.md, research.md D1)
- [X] T004 Agregar la propiedad `category_name` en `pos-backend/app/models/product.py` (tras la relación `category` en línea 22): `@property def category_name(self) -> str | None: return self.category.name if self.category else None` (research.md D2) — depende de T003
- [X] T005 Agregar `.options(joinedload(Product.category))` al `select(Product)` de `ProductService.list_query` en `pos-backend/app/api/v1/products/service.py:58-72` (importar `joinedload` de `sqlalchemy.orm`) — resuelve el `JOIN` sin N+1 (research.md D1) — depende de T004
- [X] T006 Agregar `category_name: str | None = None` a `ProductResponse` en `pos-backend/app/api/v1/products/schemas.py:84-104` (justo debajo de `category_id`) — se propaga automáticamente a `ProductListResponse`, `ProductDetailResponse` y `ProductSaveResponse` (research.md D3/D4) — depende de T004
- [X] T007 Ejecutar T003 y confirmar que ahora pasa; reejecutar toda la suite de `pos-backend` (comando de T001) y confirmar que sigue en la misma línea base (sin regresiones) — depende de T005, T006

**Checkpoint**: `GET /products` y `GET /products/{id}` ya devuelven `category_name` resuelto sin
depender de `GET /categories`, verificable por separado contra la API (escenario 2 de
`quickstart.md`).

---

## Phase 3: User Story 1 - Ver el nombre real de la categoría de cada producto, sin importar cuántas categorías tenga el tenant (Priority: P1) 🎯 MVP

**Goal**: "Carta del menú" (listado) deja de depender de `categoryMap`/`CategoryService` y
muestra, para cada producto, el `category_name` que ya llega resuelto en `GET /products`
(Foundational).

**Independent Test**: en un tenant con más de 100 categorías activas, abrir "Carta del menú" y
verificar que ningún producto muestra "—"; por separado, consumir `GET /products` sin UI y
verificar `category_name` en la respuesta (ya cubierto por Foundational/T003).

### Tests for User Story 1

- [X] T008 [P] [US1] Actualizar/añadir tests en `pos-heladeria/src/app/modules/products/pages/products-page.component.spec.ts`: un fixture de producto con `category_name` poblado debe pintarse en la columna "Categoría" sin invocar `CategoryService.loadAllCategories()`/`allCategories()` — deben fallar antes de implementar
- [X] T009 [P] [US1] Actualizar los fixtures de `ProductResponse`/`Product` en `pos-heladeria/src/app/modules/products/services/product.service.spec.ts` para incluir `category_name` y verificar que `toProduct()` lo mapea tal cual (`p.category_name ?? null`) — deben fallar antes de implementar

### Implementation for User Story 1

- [X] T010 [P] [US1] Agregar `category_name: string | null` a la interfaz `Product` en `pos-heladeria/src/app/modules/products/interfaces/product.interface.ts` (línea ~31-49) — depende de T009
- [X] T011 [US1] Agregar `category_name: string | null` a la interfaz local `ProductResponse` (línea ~57-72) y mapearlo en `toProduct()` (línea ~675-691) en `pos-heladeria/src/app/modules/products/services/product.service.ts` — depende de T010
- [X] T012 [US1] En `pos-heladeria/src/app/modules/products/pages/products-page.component.ts`: quitar el `computed` `categoryMap` (líneas 313-319), el método `categoryName()` (líneas 348-350), la inyección `private readonly categoryService = inject(CategoryService)` (línea 297) y la llamada `this.categoryService.loadAllCategories()` dentro de `ngOnInit` (líneas 323-325); en la plantilla, reemplazar `{{ categoryName(product.category_id) }}` (línea ~175) por `{{ product.category_name ?? '—' }}` — depende de T011
- [X] T013 [US1] Ejecutar T008 y T009 y confirmar que ahora pasan; reejecutar toda la suite de `pos-heladeria` (comando de T002) y confirmar que sigue en la misma línea base (sin regresiones, incluido ningún import roto por la eliminación de `CategoryService` en este componente) — depende de T012

**Checkpoint**: Historia de Usuario 1 funciona de punta a punta — `quickstart.md` escenarios 1-4
verificables.

---

## Phase 4: Polish & Cross-Cutting Concerns

- [X] T014 Ejecutado contra `pos-backend` (`fastapi dev`, ya corriendo en `:8000`) y Postgres real: se provisionó un tenant desechable (`spec097_check`), se sembraron 105 categorías activas + 1 producto en la última por orden alfabético, y se verificaron en vivo por HTTP los escenarios 1 ("Categoria 104" resuelta sin estar en una página de 100), 2 (`category_name` presente en `GET /products` sin tocar `GET /categories`) y 3 (`PATCH /categories/{id}` + `GET /products/{id}` refleja el nuevo nombre de inmediato); además se confirmó que `GET /categories?size=101` sigue devolviendo 422 (FR-005 intacto). El tenant desechable se eliminó por completo al terminar (schema + filas de `shared`), sin tocar los tenants reales (`heladeria`, `heladeria3`). El escenario 4 (≤100 categorías) no se re-verificó en vivo por ser el caso ya cubierto por los 1320 tests preexistentes que nunca siembran >100 categorías. En `pos-heladeria` (`ng serve`/vite, ya corriendo en `:4200`) se confirmó que el build sigue sirviendo 200 tras los cambios (sin errores de compilación por quitar `CategoryService`); no se logró una captura de pantalla real del DOM por no haber navegador headless instalable en este entorno (sin Playwright browser ni `chromium-cli`) ni credenciales de login disponibles — el renderizado exacto (`product.category_name ?? '—'` en la columna Categoría) ya lo prueban los tests de componente de T008, ejecutados contra el mismo shape de JSON que el backend real acaba de confirmar en vivo

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias — ambas tareas en paralelo.
- **Foundational (Phase 2)**: depende de Setup — BLOQUEA User Story 1 (el frontend no tiene nada
  nuevo que consumir sin esto).
- **User Story 1 (Phase 3)**: depende de Foundational completo (T003-T007).
- **Polish (Phase 4)**: depende de User Story 1 completo.

### Dentro de cada fase

- Tests (T003, T008, T009) se escriben y deben fallar antes de implementar.
- Modelo (T004) antes de la consulta (T005) y antes del esquema (T006), porque ambos leen la
  propiedad que T004 agrega.
- Interfaz de dominio (T010) antes del servicio que la usa (T011), antes del componente que
  consume el servicio (T012).

### Parallel Opportunities

- T001 y T002 (Setup) en paralelo.
- T008 y T009 (tests de US1, archivos distintos) en paralelo.
- T010 puede empezar en paralelo con T008/T009 (son archivos distintos sin dependencia directa),
  pero T011 sí depende de T010.

---

## Parallel Example: Foundational

```bash
# T003 (test) se escribe primero y en solitario; T004-T006 quedan secuenciales porque
# los tres tocan la cadena modelo → query → esquema sobre el mismo flujo de datos.
Task: "Escribir test de characterization para category_name en list_query paginado"
```

## Parallel Example: User Story 1

```bash
# Tests de US1 en paralelo (archivos distintos):
Task: "Actualizar tests de products-page.component.spec.ts para category_name"
Task: "Actualizar tests de product.service.spec.ts para category_name"
```

---

## Implementation Strategy

### MVP (única historia de esta spec)

1. Completar Phase 1: Setup (línea base de ambos repos).
2. Completar Phase 2: Foundational (CRÍTICO — bloquea User Story 1).
3. Completar Phase 3: User Story 1.
4. **DETENER y VALIDAR**: correr `quickstart.md` completo.
5. Avisar al usuario antes de cualquier commit (Principio XV — nunca por iniciativa propia) y antes
   de crear la rama `fix/097-product-category-name` en `pos-backend`/`pos-heladeria` si aún no
   existe (Principio XIV).

## Notes

- [P] = archivos distintos, sin dependencias entre sí.
- [US1] mapea la tarea a la única historia de usuario de esta spec.
- Verificar que los tests fallan antes de implementar.
- No commitear salvo pedido explícito del usuario (Principio XV); cuando se commitee, en commits
  pequeños y enfocados, en inglés, sin ninguna marca de IA.
- Evitar: tareas vagas, conflictos de archivo simultáneos, tocar `GET /categories` o la vista de
  detalle de producto (fuera de alcance, ver spec.md FR-003/FR-005).
