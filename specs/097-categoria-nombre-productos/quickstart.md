# Quickstart: Corrección — el nombre de categoría de un producto no depende de la paginación de `GET /categories`

Valida los 4 escenarios de aceptación de `spec.md` (Historia de Usuario 1). Requiere el backend
(`pos-backend`) corriendo con una base de datos de prueba y el frontend (`pos-heladeria`) apuntando
a él.

## Prerrequisitos

- `pos-backend` corriendo localmente (ver su propio README) con un tenant de prueba autenticado
  como Administrador o Cajero.
- Acceso a la API para crear categorías/productos de prueba (o un script/fixture que siembre >100
  categorías activas).

## Escenario 1 — más de 100 categorías activas, ningún producto con "—"

1. Sembrar 105 categorías activas en el tenant de prueba (nombres distintos).
2. Crear al menos un producto cuya categoría quede fuera de las primeras 100 por orden alfabético
   (p. ej. una categoría cuyo nombre empiece por una letra tardía).
3. `GET /products?page=1&size=20` (o abrir "Carta del menú" en `pos-heladeria`).
4. **Esperado**: el producto del paso 2 muestra el nombre real de su categoría — nunca "—" — tanto
   en la respuesta JSON (`category_name`) como en la columna "Categoría" de la pantalla.

## Escenario 2 — `GET /products` sin UI, `category_name` sin segunda llamada

1. `curl` (o cliente HTTP equivalente) contra `GET /products` con un token válido, sin llamar a
   `GET /categories` en absoluto.
2. **Esperado**: cada ítem de `items[]` trae `category_name` junto a `category_id`, con el nombre
   real de la categoría — ver `contracts/products-api.md`.

## Escenario 3 — renombrar una categoría, el cambio se ve de inmediato

1. Anotar el `category_name` actual de un producto vía `GET /products/{id}`.
2. `PATCH /categories/{id}` cambiando `name` a un valor distinto.
3. Repetir `GET /products/{id}` (o recargar "Carta del menú").
4. **Esperado**: `category_name` refleja el nuevo nombre inmediatamente, sin ningún retraso ni
   necesidad de limpiar caché alguna.

## Escenario 4 — tenants con 100 categorías o menos no cambian de comportamiento

1. En un tenant con, por ejemplo, 12 categorías activas (el caso típico hoy), abrir "Carta del
   menú".
2. **Esperado**: sigue mostrando el nombre real de cada categoría, igual que antes de este fix —
   ningún cambio visible para el caso que ya funcionaba.

## Lo que este quickstart no cubre (fuera de alcance, ver spec.md)

- La vista de detalle de producto (`product-detail-page.component.ts`) no muestra la categoría en
  absoluto, con o sin este fix — es una omisión preexistente de la spec 093 (FR-017), independiente
  de esta corrección (ver spec.md, FR-003).
- `GET /categories` y las pantallas que lo consumen (selector de categoría del formulario de
  producto, filtro de promociones, pantalla de Categorías) no cambian — no hace falta revalidarlas
  para esta spec.
