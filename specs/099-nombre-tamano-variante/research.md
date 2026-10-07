# Research: Nombre comercial propio para los tamaños de un producto

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

Investigación hecha leyendo el código real de `pos-backend` y `pos-heladeria` (no se asume nada
sobre el modelo actual). Cada decisión cita archivo y línea del estado **antes** de esta spec.

## Contexto histórico importante (por qué esto no reabre la spec 084)

`ProductVariant` **ya tuvo** una columna `name` de texto libre, y era la clave de unicidad dentro
de un producto (`uq__product_variants__product_id__name`). La spec 084 (A-79) la **eliminó**
deliberadamente — migración `c7e2b91a4d35_084_variante_sin_nombre.py` — porque el nombre de una
variante debía ser siempre el de una `Presentation` del catálogo (spec 083), no texto libre sin
normalizar. Hoy `ProductVariant` no tiene columna `name`; su nombre es
`presentation_name = self.presentation.name` (`app/models/product_variant.py:51-53`), con
`presentation_id` obligatorio y `lazy="joined"`.

Esta spec **no revierte esa decisión**: no se vuelve a usar `name` como clave estructural de la
variante ni se toca `presentation_id`/`presentation_name`. Se agrega una columna `name` **distinta
en propósito**: un alias comercial, opcional, puramente cosmético, que convive con
`presentation_id` como fuente estructural. El catálogo de `Presentation` sigue siendo la única
fuente de verdad para inventario, promociones y reglas de negocio; `name` solo cambia **qué texto
ve el comensal**. Por eso no aplica una entrada nueva en `registro-de-anomalias.md`: no cambia
ningún comportamiento ya decidido por la spec 084, lo complementa.

## Decisiones

### D1 — Dónde vive el nombre propio

**Decisión**: columna nueva `ProductVariant.name` (`VARCHAR(60) NOT NULL DEFAULT ''`), no en
`Presentation`.

**Rationale**: dos variantes de **productos distintos** pueden compartir la misma `Presentation`
("Grande 16 onz") y querer nombres comerciales distintos ("Para compartir" en un producto, "Family
size" en otro) — el nombre es una propiedad de la variante, no de la presentación reutilizable.

**Alternativas consideradas**: agregar el campo a `Presentation` (rechazada: forzaría que todas las
variantes que usan esa presentación compartan el mismo alias, y violaría el catálogo reutilizable
que la spec 083 estableció a propósito).

### D2 — Cálculo de `display_name`

**Decisión**: propiedad de solo lectura en `ProductVariant` (no persistida):
`name` si no está vacío; si no, `presentation.name`; si ninguno está disponible, `"Tamaño"` +
`logging.getLogger(__name__).warning(...)` con el id de la variante.

**Rationale**: mismo patrón que la propiedad `presentation_name` ya existente (`product_variant.py:
51-53`) — un único punto de verdad reutilizado por el router de menú, el formador de condiciones de
promoción y cualquier serializador futuro, en vez de repetir la regla `name or presentation_name or
"Tamaño"` en cada capa (que es exactamente el tipo de divergencia que un defecto como el de la spec
097 demuestra que ocurre si se duplica).

**Alternativas consideradas**: calcularlo en cada esquema Pydantic de respuesta por separado
(rechazada: cada superficie — menú, formulario, promociones — tendría su propia copia de la regla
y de su `except`); calcularlo en el frontend a partir de `name`/`presentation_name` por separado
(rechazada: el frontend ya no tendría forma de saber si el backend quiso decir "sin nombre propio"
o "presentación no disponible", y el registro de advertencia del Escenario 16 requiere acceso al
log del servidor).

### D3 — Normalización del nombre (trim + colapso de espacios + límite de 60)

**Decisión**: función pura nueva `normalize_variant_name(value: str | None) -> str` en
`app/core/variant_name.py` (backend) y su réplica `normalizeVariantName` en
`src/app/shared/validators/variant-name.validator.ts` (frontend) — mismo patrón dual que
`app/core/person_name.py` / `shared/validators/full-name.validator.ts` (spec 091). Algoritmo y
mensajes exactos en [contracts/variant-name-rules.md](./contracts/variant-name-rules.md).

**Rationale**: la validación de longitud y el mensaje de error deben verse igual si el formulario
los detecta en vivo o si el backend los rechaza al guardar — una sola definición evita que ambas
implementaciones diverjan, como ya hace el proyecto para el nombre completo.

**Alternativas consideradas**: confiar solo en `model_config = ConfigDict(str_strip_whitespace=True)`
(ya usado por `VariantCreate`/`VariantUpdate`/`VariantSaveIn`, `app/api/v1/catalog/schemas.py:10,20,
112`) — rechazada: solo recorta los extremos, no colapsa espacios internos repetidos (Escenario 5).

### D4 — Dónde se valida la longitud y se calcula el `''` final

**Decisión**: `normalize_variant_name` recibe el valor **tal como llega** (ausente/`null` → `''`),
valida que no supere 60 caracteres **antes** de recortar/colapsar (consistente con el Escenario 8,
que prueba el límite con 61 caracteres simples), y devuelve siempre el texto ya recortado y
colapsado — nunca `None`.

**Alternativas consideradas**: validar la longitud después de normalizar (rechazada: cambiaría qué
entradas de más de 60 caracteres se aceptan si tienen espacios repetidos que se colapsan por debajo
del límite — el negocio no pidió ese matiz y el escenario de aceptación no lo distingue).

### D5 — Validación de nombre duplicado dentro del producto (FR-008)

**Decisión**: nueva función `display_name_duplicado(db, product_id, display_name, *,
exclude_id=None)` en `app/api/v1/catalog/service.py`, que solo mira variantes **activas** del
producto (Clarificación — sesión 2026-10-06, pregunta 1) y compara `display_name` con
`func.lower()`/`.lower()` en Python (Clarificación, pregunta 2). Se llama dentro de
`_save_variant_entry` (`catalog/service.py:277-338`), justo después de `_resolve_presentation`
(ya tiene `presentation.name` resuelto para calcular el `display_name` de esta entrada) y antes de
crear/actualizar la fila. El conflicto se señaliza con `HTTPException(409, detail={"error": "Ya
existe un tamaño con ese nombre en este producto", "variant_index": index})`.

**Rationale**: mismo patrón ya establecido para "SKU repetido" (`_ensure_sku_unique`,
`catalog/service.py:163-174`) — 409 con `error` + `variant_index`, **sin** `variant_id`. Omitir
`variant_id` a propósito: el frontend (`product.service.ts`, función `toNameConflict`) solo activa
el flujo de "presentación en uso / restaurar variante desactivada" cuando el 409 **sí** trae
`variant_id` (ese flujo es exclusivo del conflicto de `presentation_id`, que no aplica aquí). Con
`variant_id` ausente, el error cae en la rama genérica de `extractError`, que ya muestra
`detail.error` tal cual — sin tocar ningún componente de UI nuevo.

**Alternativas consideradas**: reusar `_raise_presentation_conflict` con un mensaje distinto
(rechazada: esa función asume un conflicto de `presentation_id` y dispara el flujo de "reactivar
variante desactivada" que no aplica a un nombre repetido); un `UNIQUE` de base de datos sobre
`display_name` (rechazada: `display_name` es calculado — depende de `Presentation.name`, que puede
cambiar — y la comparación es insensible a mayúsculas; un índice funcional de ese tipo es más
frágil que la validación ya usada en el resto del módulo para reglas equivalentes).

### D6 — Migración (aditiva y reversible)

**Decisión**: una sola revisión Alembic, `e7d8c9b0a1f2_099_nombre_tamano_variante.py`
(`down_revision = '2d50957395dc'`, cabecera actual), con el mismo patrón que
`a9f7d0310f6b_084_variante_presentacion.py` (`@for_each_tenant_schema`, guardas `_has_table`/
`_has_column`): `upgrade` agrega `product_variants.name VARCHAR(60) NOT NULL DEFAULT ''` (Postgres
rellena `''` en cada fila existente en el mismo `ADD COLUMN`, sin `UPDATE` aparte);
`downgrade` hace `DROP COLUMN`.

**Rationale**: `DEFAULT ''` en el mismo `ADD COLUMN ... NOT NULL` satisface el Escenario 1
(ninguna fila existente queda en `NULL` ni requiere un paso de backfill separado) y el Escenario 18
(revertir es un único `DROP COLUMN`, sin pérdida de presentaciones, precios ni pedidos porque la
columna nunca los toca).

**Alternativas consideradas**: agregar la columna como `nullable=True` y hacer backfill con un
`UPDATE` aparte (rechazada: dos pasos donde uno basta, y además violaría FR-003 — nunca `NULL` —
si algo falla entre ambos pasos).

### D7 — Exposición en las respuestas de la API

**Decisión**: `VariantResponse`, `VariantSaveOut` (`app/api/v1/products/schemas.py`,
`app/api/v1/catalog/schemas.py:29-39`) y `MenuVariantResponse` (`app/api/v1/menu/schemas.py:64-89`)
ganan `name: str` (donde corresponda, el valor crudo guardado) y `display_name: str` (el
calculado). `presentation_name` **se mantiene sin cambios** en las tres. El router de menú
(`app/api/v1/menu/router.py:191-196`) pasa `display_name=v.display_name` además de
`presentation_name=v.presentation_name`.

**Rationale**: Escenario 15 (compatibilidad con frontend en caché) exige que los campos que ya
existen sigan significando lo mismo — `display_name` se agrega, nada se quita ni se renombra.

### D8 — El frontend usa `display_name`, no `presentation_name`, para lo que el comensal ve

**Decisión**: los dos puntos donde el cliente hoy arma el modelo `MenuVariant.name` —
`menu.service.ts:139` (`name: v.presentation_name`) y `diner.service.ts:398` (`name:
(v['presentation_name'] ?? v['name'])`) — pasan a leer `display_name` primero, con el mismo
encadenamiento defensivo que `diner.service.ts` ya usa hoy: `v.display_name ?? v.presentation_name
?? v.name`. La interfaz `MenuVariant` (`product.interface.ts:466`) no cambia de forma — su campo
`name` ya es "lo que se muestra"; solo cambia de dónde se llena.

**Rationale**: `MenuVariant.name` ya es, por diseño, el campo que el carrito y el resumen de
checkout pintan (Escenario 11) — no hace falta un campo nuevo en esa interfaz, solo cambiar su
origen. El encadenamiento con `??` reproduce el mismo criterio de compatibilidad hacia atrás que
`diner.service.ts` ya aplicaba para el salto spec 084 → spec 066.

### D9 — Formulario "Tamaños del producto"

**Decisión**: nueva celda "Nombre (opcional)" en la grilla de cada fila
(`product-form.component.ts:180-227`), junto a la de Presentación — se amplía
`grid-cols-[28px_28px_1fr_140px_88px]` a `grid-cols-[28px_28px_1fr_1fr_140px_88px]`. `VariantDraft`
(`product.interface.ts:348-363`) gana `name: string`. El placeholder dinámico (FR-010) se calcula
con una función pura `variantNamePlaceholder(v: VariantDraft): string` que devuelve `Se mostrará:
${v.presentationName}` si ya hay presentación elegida, o `Se mostrará la presentación` si no. El
límite de 60 caracteres se valida en vivo con `normalizeVariantName` (D3) dentro de `canSave()`
(`product-form.component.ts:631-645`), mismo criterio que ya usa esa función para bloquear el botón
antes de intentar guardar.

**Rationale**: reutiliza el patrón ya establecido por la columna de Precio (`setVariantField`,
`product-form.component.ts:1153`) — no hace falta un control nuevo, solo una entrada de texto más
conectada al mismo helper.

### D10 — `variant_display_names()` (texto de condición de promociones en el menú público)

**Decisión**: `app/api/v1/promotions/service.py:459-482` agrega `ProductVariant.name` a su
proyección (ya hace un único `select()` con `Presentation.name`/`Product.name`, sin cargar objetos
ORM) y aplica la misma precedencia que FR-004 (`name` → `presentation.name`) antes de caer al
nombre del producto que esa función ya contempla.

**Rationale**: esta función alimenta el texto de condición de promociones que el router de menú
(`menu/router.py:92-94,191-196,241`) muestra en el propio menú público — es la misma superficie que
FR-006 cubre (Escenario 11: coherencia en todo el recorrido del comensal). Dejarla leyendo solo
`presentation_name` mostraría "2x1 en Grande 16 onz" en la insignia de promoción mientras el resto
de la pantalla dice "Para compartir", justo la inconsistencia que la spec busca evitar. El cambio
no agrega una consulta: se amplía la proyección de la que ya existe (research.md D-12 de la spec
066 exige que siga siendo una sola llamada, no una por regla).

**Alternativas consideradas**: dejar `variant_display_names()` sin tocar (rechazada por la
inconsistencia visible arriba); resolverla con un objeto ORM completo por variante (rechazada:
reintroduce el N+1 que el docstring de la función ya advierte evitar).

### D11 — Lo que **no** se toca (fuera de alcance, a propósito)

**Decisión**: `format_item_description()` (`app/catalog_engine/core.py:93-108`, usada por
`orders/checkout.py:286,441` y `sales/service.py:318` para el texto de línea que se **persiste** en
un pedido/venta al finalizar el pago) sigue usando `presentation_name`, tanto para pedidos nuevos
como antiguos. Las pantallas de Órdenes y Ventas no cambian.

**Rationale**: el alcance que el negocio declaró ("Incluye: ... su uso en el menú público (detalle,
carrito y resumen de checkout)") se lee como las pantallas que el comensal ve **antes** de pagar —
el resumen de checkout es una pantalla del frontend que lee cart+menú ya cargados
(`checkout-order-summary.component.ts`), no el texto que el backend persiste en el pedido al
confirmarlo. El Escenario 12 ("pedidos anteriores... sin modificaciones") y la ausencia de Órdenes/
Ventas en el "Incluye" confirman que el registro operativo del pedido —pasado o nuevo— es un asunto
distinto. Extender el alias comercial al texto persistido de pedidos es una decisión de negocio
nueva (Principio XI), no autorizada por esta spec; necesitaría su propia spec si el negocio lo
pide.

### D12 — Dónde viven los tests de esta funcionalidad

**Decisión**: `app/characterization_tests/test_variant_display_name.py` — el backend no tiene otro
directorio de tests (`app/characterization_tests/` ya alberga tests de funcionalidad nueva, no solo
de congelamiento: `test_product_variant_reorder.py`, `test_variant_sin_nombre_migration.py`). La
migración se prueba igual que `test_variant_sin_nombre_migration.py`: cargar el módulo de la
revisión con `importlib` y ejercitar `upgrade`/`downgrade` sobre SQLite en memoria.

**Rationale**: seguir la convención real del repo (Principio V — no crear una estructura nueva sin
necesidad) en vez de inventar un directorio `app/tests/` que no existe hoy.
