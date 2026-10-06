# Research: Corrección — el nombre de categoría de un producto no depende de la paginación de `GET /categories`

## D1 — Cómo traer `category_name` sin una segunda consulta ni N+1

**Decisión**: en `ProductService.list_query` (`app/api/v1/products/service.py:58-72`), agregar
`.options(joinedload(Product.category))` al `select(Product)` existente. `Product.category` ya es
una relación `many-to-one` declarada (`app/models/product.py:22`,
`relationship(back_populates="products")`), así que `joinedload` emite un único `LEFT OUTER JOIN`
contra `categories` dentro de la misma consulta — sin una segunda consulta por producto (sin N+1)
y sin duplicar filas (la relación es `many-to-one`: cada producto se une con, a lo sumo, una fila
de categoría).

**Rationale**:
- Es el `JOIN en el propio query de productos` que pide la spec (notas técnicas), usando el
  mecanismo idiomático de SQLAlchemy para resolver una relación ya existente, no uno nuevo.
- `app/core/pagination.py::paginate()` ejecuta `stmt.offset(...).limit(...)` y lee el resultado con
  `.scalars().all()` (línea 30). `joinedload` no cambia la "forma" de lo que `.scalars()` devuelve
  (sigue siendo una lista de `Product`), así que `paginate()` no necesita ningún cambio.
- El conteo total (`select(func.count()).select_from(stmt.order_by(None).subquery())`, línea
  26-28) sigue siendo correcto: envolver la consulta con el `JOIN` en una subconsulta y contar sus
  filas no altera el total, porque la relación es `many-to-one` (ninguna fila de producto se
  multiplica).
- No se necesita `.unique()` sobre el resultado (como sí exige SQLAlchemy 2.x para un `joinedload`
  sobre una relación de colección): `Product.category` es escalar, no una lista.

**Alternatives considered**:
- **Seleccionar `Category.name` como columna adicional** (`select(Product, Category.name)`) y
  reconstruir la respuesta a mano. Rechazada: `paginate()` usa `.scalars().all()`, que descarta
  cualquier columna más allá de la primera entidad seleccionada — habría que reescribir
  `paginate()` para un caso multi-columna genérico, lo que afectaría a todos los demás endpoints
  paginados del proyecto (categorías, promociones, etc.) para resolver un problema de un solo
  endpoint. Viola el Principio V (no refactor oportunista más allá de lo necesario).
- **Desnormalizar `category_name` como columna física en `products`**, sincronizada por trigger o
  por código al editar una categoría. Rechazada: exige migración, lógica de sincronización nueva, y
  el propio criterio de aceptación 3 del spec ("el nuevo nombre aparece de inmediato") se cumple
  gratis con un dato resuelto en cada lectura — desnormalizar introduce exactamente el riesgo de
  desactualización que el criterio busca evitar.

## D2 — Dónde vive la resolución `category_id` → nombre: propiedad en el modelo ORM

**Decisión**: agregar una propiedad de solo lectura en `app/models/product.py`:

```python
@property
def category_name(self) -> str | None:
    return self.category.name if self.category else None
```

**Rationale**: `ProductResponse` usa `model_config = ConfigDict(from_attributes=True)` y se
construye con `ProductResponse.model_validate(product)` (ya así hoy, `service.py:83`,
`:320`) — Pydantic en modo `from_attributes` resuelve cada campo con `getattr(product,
<campo>)`. Una propiedad Python en el modelo ORM es exactamente lo que ese mecanismo espera, sin
tocar ninguna de las funciones que construyen las respuestas (`to_detail_response`,
`to_save_response`, ni el `return` directo de `list_products`/`get_product` en el router). El
`None` defensivo (en vez de asumir que `self.category` siempre existe) cubre el único caso en que
la relación podría no resolverse: una fila con `category_id` apuntando a una categoría que no
existe en una base de datos de test sin aplicación de FK (ver nota de memoria sobre
`characterization_tests`, que corren contra SQLite en memoria sin `FOR UPDATE` ni FK reales); en
producción, con la FK real de PostgreSQL, `category_id` es `NOT NULL` y siempre referencia una
categoría existente, así que `category_name` nunca es `None` ahí.

**Alternatives considered**:
- **Resolver `category_name` a mano dentro de cada función de respuesta** (`to_detail_response`,
  `to_save_response`, y el handler de `list_products`), repitiendo `product.category.name if
  product.category else None` en cada punto. Rechazada: tres copias del mismo cálculo donde una
  propiedad en el modelo lo centraliza una sola vez, y automáticamente alcanza también
  `create_product`/`update_product` (que devuelven `ProductSaveResponse`, también heredera de
  `ProductResponse`) sin tocarlos.
- **`hybrid_property` de SQLAlchemy** (permite usarla también en queries SQL, no solo en Python).
  Rechazada por innecesaria: nada en este fix necesita filtrar o calcular `category_name` dentro de
  una cláusula `WHERE`/`ORDER BY` — una `@property` simple basta y es más legible.

## D3 — Dónde se declara el campo nuevo en los esquemas de respuesta

**Decisión**: agregar `category_name: str | None = None` en `ProductResponse`
(`app/api/v1/products/schemas.py:84-104`), la clase base de la que heredan `ProductListResponse`,
`ProductDetailResponse` y `ProductSaveResponse`.

**Rationale**: las cuatro respuestas de producto (`GET /products`, `GET /products/{id}`,
`POST`/`PATCH`/`PUT /products`, `PATCH /products/{id}/availability`) ya heredan de
`ProductResponse`; declarar el campo una sola vez en la base lo propaga a las cuatro sin tocar cada
subclase, igual que ya pasa con `category_id`, `available_changed_at`, etc.

**Alternatives considered**:
- Agregarlo solo en `ProductListResponse` (la respuesta de `GET /products`, que es el único
  endpoint que el frontend necesita corregir hoy). Rechazada: deja `GET /products/{id}` (detalle) y
  las respuestas de guardado sin el dato, obligando a quien consuma esos otros endpoints a volver a
  depender de `GET /categories` para resolver el nombre — justo el problema que esta spec corrige.
  El criterio de aceptación 2 del spec pide el campo en "cada ítem" de `GET /products`
  explícitamente, pero no hay ninguna razón para que el detalle quede peor servido que el listado.

## D4 — Por qué `str | None` y no `str`

**Decisión**: `category_name: str | None = None`, no `category_name: str`.

**Rationale**: aunque `Product.category_id` es `NOT NULL` con FK real en PostgreSQL (así que en
producción el valor nunca es `None`), los `characterization_tests` del backend corren contra
SQLite en memoria sin aplicación de llaves foráneas (ver nota de memoria del proyecto); un fixture
de test que construya un `Product` sin sembrar su `Category` correspondiente no debe hacer que la
serialización de la respuesta falle con un error 500 por un campo `None` donde Pydantic esperaba
`str`. Mantener el campo opcional es la postura defensiva mínima, consistente con el resto de
`ProductResponse` (`description`, `image_url`, `available_changed_at` ya son opcionales).

**Alternatives considered**: `category_name: str` (obligatorio, sin default). Rechazada por el
riesgo de romper fixtures de test existentes que no siembran una `Category` real — contradice la
guía ya registrada en memoria de este proyecto de preferir un campo opcional con default seguro en
vez de forzar la corrección de cada fixture existente cuando el comportamiento real no lo exige.

## D5 — Frontend: eliminar `categoryMap`/`categoryName()`, enlazar `product.category_name`

**Decisión**:
1. `src/app/modules/products/interfaces/product.interface.ts` — agregar `category_name: string |
   null` a la interfaz `Product` (heredada automáticamente por `ProductDetail extends Product`).
2. `src/app/modules/products/services/product.service.ts` — agregar `category_name: string | null`
   a la interfaz local `ProductResponse` (el tipo "crudo" del backend, línea 57-72) y mapearlo en
   `toProduct()` (línea 675-691): `category_name: p.category_name ?? null`.
3. `src/app/modules/products/pages/products-page.component.ts` — eliminar el `computed` `
   categoryMap` (líneas 313-319), el método `categoryName()` (líneas 348-350), la inyección de
   `CategoryService` (línea 297) y la llamada `this.categoryService.loadAllCategories()` dentro de
   `ngOnInit` (líneas 323-325, que ya queda muerta sin `categoryMap` leyéndola); en la plantilla,
   reemplazar `{{ categoryName(product.category_id) }}` por `{{ product.category_name ?? '—' }}`.

**Rationale**: es exactamente el cambio que pide la spec (notas técnicas) y el que elimina la causa
raíz en el cliente — dejar de depender de una lista de categorías cargada aparte y acotada a 100.
El `?? '—'` se conserva solo como guarda defensiva de UI (mismo patrón que ya usa `categoryName()`
hoy) para datos incompletos de fixtures de test; contra el backend corregido (D1-D4) nunca se
alcanza, porque `category_name` siempre llega resuelto.

**Alternatives considered**:
- Dejar `CategoryService`/`categoryMap` como repaldo ("fallback") cuando `category_name` venga
  vacío. Rechazada: reintroduce la dependencia que la spec pide eliminar explícitamente ("sin
  depender de una lista de categorías cargada aparte en el cliente") y mantiene viva la causa raíz
  para cualquier caso donde el backend aún no la resuelva bien — contradice el propio objetivo de
  la corrección.
