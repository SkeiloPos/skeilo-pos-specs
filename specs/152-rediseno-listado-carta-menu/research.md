# Research: Rediseño del listado de la Carta del menú

**Feature**: `152-rediseno-listado-carta-menu` | **Date**: 2026-11-05

No quedaron `NEEDS CLARIFICATION` en el Technical Context del plan: las tres preguntas
abiertas (precio por producto, filtro por categoría, alcance del rediseño de tarjetas)
ya fueron resueltas en la sesión de clarificación del spec (2026-11-05). Este documento
registra las decisiones técnicas necesarias para implementar esas respuestas.

## D1 — Punto de quiebre tarjetas ↔ tabla

**Decisión**: usar el breakpoint `lg` de Tailwind (1024px), igual al que ya separa
columnas en la tabla actual (`hidden md:table-cell` para "Categoría"). La vista de
tarjetas se renderiza para `< 1024px` (incluye el rango 768–1023px de tablet, según
Edge Case del spec) y la tabla para `≥ 1024px`.

**Alternativa considerada**: introducir un breakpoint `JS` (media query en el
componente) para alternar entre dos plantillas completamente distintas. Se descarta:
Tailwind ya resuelve el cambio de layout en CSS puro (`hidden lg:block` / `lg:hidden`),
sin necesidad de lógica de resize en TypeScript, y cumple FR-009 (no perder filtros ni
paginación) de forma trivial porque ambas vistas leen el mismo estado del
`ProductService` — no hay remount del componente al cruzar el breakpoint.

## D2 — Cómputo del precio resumido sin N+1

**Decisión**: en `ProductService.list_query` (backend), agregar un `subquery`
correlacionado sobre `product_variants` que devuelva, por producto, el precio mínimo
entre sus variantes **activas** con `price > 0` y la cantidad de esas variantes. Se
expone como columnas adicionales del mismo `Select` (vía `.add_columns(...)` o un
`selectinload` + propiedad calculada en Python sobre `product.variants` ya cargadas).

Dado que el tamaño de página está acotado (`size <= 100`, default 20), la opción más
simple y suficientemente performante es `selectinload(Product.variants)` (una sola
consulta adicional para TODO el lote, no una por fila) y calcular en Python:

- 0 variantes con `price > 0` → `price_display = None` (el frontend muestra "Sin
  precio").
- 1 variante con `price > 0` → `price_display = ese precio`, `price_from = False`.
- ≥2 variantes con `price > 0` → `price_display = min(precios)`, `price_from = True`
  (el frontend antepone "Desde").

**Alternativa considerada**: persistir un campo `Product.price_display` recalculado en
cada guardado de variante. Se descarta (Principio VI/VIII): agrega un campo derivado
que puede desincronizarse si una variante se desactiva o cambia de precio por otra vía,
y no hay necesidad de rendimiento que lo justifique al tamaño de página actual.

**Formato ya existente a reutilizar**: el propio archivo de diseño calcula el string de
precio en el cliente (`f(mu[0][1])`, con "Desde " + el precio formateado) — se sigue el
mismo patrón: el backend entrega el valor numérico (`Decimal`) y el flag `price_from`;
el frontend formatea con el pipe de dinero ya usado en el módulo (`MoneyPipe`,
visto en `product-select.component.ts`), igual que el resto de precios de la app.

## D3 — Filtro por categoría: parámetro y combinación con filtros existentes

**Decisión**: añadir `category_id: UUID | None` como query param de
`GET /products`, aplicado como `Product.category_id == category_id` en
`list_query`, en la misma función que ya combina `active`, `available`, `search` e
`is_topping` con AND implícito. No reemplaza ningún filtro existente — se agrega al
mismo WHERE encadenado.

**Alternativa considerada**: filtrar por nombre de categoría (`category_name`) en vez
de `category_id`. Se descarta: nombres no son únicos de forma garantizada a nivel de
dominio frente a un id, y el frontend ya tiene acceso a `GET /categories` (paginado)
para poblar el selector con `{id, name}`, igual que categorías se seleccionan hoy en el
formulario de producto.

## D4 — Recorte de campos de `ProductListResponse` (FR-008)

**Decisión**: `ProductListResponse` deja de ser un alias vacío de `ProductResponse`
(`class ProductListResponse(ProductResponse): pass`) y pasa a declarar explícitamente
solo los campos que alguna de las dos vistas (tarjeta o tabla) despliega:

`id, code` *(nota: `code` no se despliega hoy ni en la tabla actual ni en el diseño de
referencia — se excluye)*, `category_id, category_name, name, image_url,
preparation_type, active, available, available_changed_at,
available_changed_by_name` *(se mantiene: aunque hoy la UI solo muestra
`available_changed_at` vía `RelativeTimePipe`, no hay uso confirmado de
`available_changed_by_name` en el listado — se excluye también, ver más abajo)*,
`created_at, updated_at` (la tabla de referencia agrega columnas "Creación" y
"Actualización" que no existían en el diseño anterior), `price_display, price_from`
(nuevos).

Se excluyen de `ProductListResponse` (quedan solo en `ProductDetailResponse`, que no se
toca): `description` *(la tabla de referencia no muestra descripción debajo del
nombre — ver contrato; si el frontend la necesitara para la tarjeta se reincorpora en
Fase de implementación revisando el diseño con más detalle, no en este research)*,
`tracks_inventory`, `is_topping`, `visible_en_qr`, `available_changed_by_name`.

**Validación de que no rompe otro consumidor**: el único otro consumidor de
`GET /products` identificado en el código (`product.service.ts:searchActiveToppingProducts`,
usado por el picker de "Adiciones disponibles", spec 129) solo lee `id` y `name` de cada
item — no se ve afectado por el recorte.

**Alternativa considerada**: crear un endpoint nuevo `GET /products/summary` separado
del existente. Se descarta (Principio V/VI): `GET /products` ya es el único punto de
listado paginado de la Carta del menú; duplicarlo fragmentaría el filtrado/paginación
existente sin necesidad, cuando ajustar su `response_model` basta.

## D5 — Reutilización de componentes UI existentes

**Decisión**: la tarjeta de producto se extrae a un componente standalone propio
(`ProductListCardComponent`) en vez de inlinearla en el `@for` del template de
`ProductsPageComponent`, siguiendo el patrón ya usado en el módulo
(`LiveStatusIndicatorComponent`, `ProductImportModalComponent` como sub-componentes
standalone de la misma página). El marcador "Sin imagen" reutiliza `app-mi-icon` con
`name="image-off"` — mismo ícono que ya usa la fila de tabla actual
(`products-page.component.ts:191`) y que aparece en el diseño de referencia
(`name="image-off"`, línea 1245 de la plantilla).

**Alternativa considerada**: usar `@if` por breakpoint dentro de la misma plantilla sin
extraer componente. Se descarta por legibilidad: el `@for` tendría que duplicar la
estructura tarjeta/fila dentro del mismo bloque, dificultando mantener FR-001 (fidelidad
visual) y FR-002 (tabla intacta) por separado.
