# Contrato: consulta de reconciliación de disponibilidad

**Spec**: [../spec.md](../spec.md) (FR-026 a FR-028, US5) | **Research**: [../research.md](../research.md) (D3, D8, D9)

Dos lecturas **ligeras** que devuelven solo el estado de disponibilidad del catálogo (sin precios,
imágenes, promociones ni grupos). Son «la consulta completa de la disponibilidad del catálogo» que
el cliente ejecuta al reconectar, al recibir `resync`/`refresh`, al volver de segundo plano y tras
un 409 por agotado.

## Endpoints

| Método y ruta | Quién | Tenant | Auth |
|---|---|---|---|
| `GET /menu/availability` | Personal (Terminal, orden manual, drawer, Carta) | cabecera `x-tenant-host` (como `GET /menu`) | misma que `GET /menu` (pública por tenant) |
| `GET /menu/qr-token/{token}/availability` | Comensal | **firmado dentro del token** (como `GET /menu/qr-token/{token}`) | token firmado + rate limit `menu_qr` |

El del comensal aplica los **mismos filtros** que `_build_menu(only_visible_en_qr=True)`
(categoría activa y visible en QR, producto activo y visible en QR): no devuelve ids de productos
ocultos. El del personal aplica `_build_menu` sin filtro de QR (catálogo completo activo).

> `GET /menu` ya es público por tenant (decisión previa); este endpoint no abre información nueva:
> es un subconjunto de campos que `GET /menu` ya devuelve (`sold_out`, `available`).

## Respuesta `200`

```json
{
  "as_of": 1762099200000123,
  "products": [ { "id": "8f1c…", "sold_out": false, "available": true } ],
  "variants": [ { "id": "2b7e…", "product_id": "8f1c…", "available": false } ],
  "options":  [ { "id": "c41a…", "available": true } ]
}
```

| Campo | Tipo | Notas |
|---|---|---|
| `as_of` | `int \| null` | `version_of(último id del stream del tenant)` leída **antes** de calcular. `null` si Redis no responde. |
| `products[]` | `{id, sold_out, available}` | Mismo significado que en `availability.changed`. Incluye las **adiciones** que existen como producto. |
| `variants[]` | `{id, product_id, available}` | Solo presentaciones activas. |
| `options[]` | `{id, available}` | Solo opciones activas de grupos activos. |

Sin paginación: el catálogo de un negocio cabe en una respuesta (cientos de elementos). Sin datos
internos (FR-007).

## Semántica en el cliente

1. Antes de aplicar: `snapshotAsOf = as_of`; se limpia `lastV`.
2. **Reemplaza** el estado de disponibilidad de todo elemento presente en la respuesta. Un elemento
   del menú local **ausente** en la respuesta (se desactivó o se ocultó) no se toca aquí: eso es
   alta/baja de catálogo y lo cubre `menu.updated` / recarga de menú (fuera de alcance, spec).
3. Las líneas de carrito se recalculan solas (son `computed`, ver data-model.md).
4. Retira el indicador «Sin actualización en vivo» si la causa era la desconexión.
5. Si la consulta falla: el indicador sigue visible y se reintenta con backoff (`liveLost` no se
   apaga hasta una consulta exitosa o hasta que el stream vuelva a `open` y sea exitosa).

## Rendimiento y límites

- Número **constante** de consultas SQL (recetas, stock, opciones+insumo, enlaces variante-grupo,
  productos/variantes activos). Sin N+1.
- Presupuesto: ≤ 100 ms p95 con 300 productos.
- El del comensal respeta el rate limit `menu_qr` por IP y por mesa ya existente.
- Idempotente y sin efectos secundarios.

## Pruebas del contrato

- Una presentación con insumo de receta en 0 aparece `available: false` y su producto
  `available: false` si era la única; la marca manual no cambia.
- La versión del comensal no incluye un producto con `visible_en_qr = false`.
- Equivalencia: para un catálogo de prueba, los `available`/`sold_out` del snapshot coinciden con los
  de `GET /menu` (misma fuente: el motor).
- `as_of` es `null` si Redis no responde y la respuesta sigue siendo `200`.
