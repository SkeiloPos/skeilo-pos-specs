# Contrato: API de productos — interruptor "Agotado" y detalle de solo lectura

**Spec**: [../spec.md](../spec.md) | **Research**: [../research.md](../research.md) (D3, D4, D5, D9, D10)
**Data model**: [../data-model.md](../data-model.md)

## `PATCH /products/{id}/availability` (nuevo)

Único endpoint que el frontend usa para el interruptor "Agotado", para Admin y Cajero
por igual (research.md D3/D11).

**Autorización**: `require_tenant_admin_or_cashier` (`ADMIN` o `CASHIER`; cualquier otro
rol → 403).

**Request body**:
```json
{ "available": false }
```

**Respuesta 200**:
```json
{
  "id": "…",
  "available": false,
  "available_changed_at": "2026-10-03T15:04:00Z",
  "available_changed_by_name": "Laura Gómez"
}
```
(forma mínima; en la práctica puede devolver el `ProductResponse` completo ya actualizado,
para que el frontend no necesite una lectura adicional — ver tabla de `ProductResponse`
más abajo, que ya incluye estos dos campos nuevos).

**Errores**:

| Código | Cuándo | Cuerpo |
|---|---|---|
| 403 | El usuario autenticado no es `ADMIN` ni `CASHIER` | — |
| 404 | El producto no existe en el tenant del usuario (incluye productos de otro tenant, FR-026) | — |
| 409 | `product.active is False` (FR-011/escenario 10) | `{"error": "No se puede cambiar la disponibilidad de un producto inactivo"}` |
| 422 | `available` ausente o de tipo incorrecto | validación estándar de Pydantic |

**Efectos al responder 200**:
1. `Product.available` queda en el valor pedido.
2. `Product.available_changed_at` = ahora (servidor), `available_changed_by_name` =
   nombre del usuario autenticado.
3. Se agrega una fila a `AuditLog` (`action="availability_changed"`, `entity="product"`,
   ver data-model.md).
4. Last-write-wins sin bloqueo (research.md D10) — dos peticiones casi simultáneas
   dejan como resultado final la que el servidor procesó al final, sin estado
   intermedio inconsistente (FR-016/escenario 14).

## `GET /products` y `GET /products/{id}` — campos nuevos en la respuesta

`ProductResponse` (base de `ProductListResponse`/`ProductDetailResponse`) gana dos
campos de solo lectura, visibles para cualquier rol con acceso al endpoint (Admin,
Cajero):

| Campo | Tipo | Ejemplo |
|---|---|---|
| `available_changed_at` | `datetime \| null` | `"2026-10-03T15:04:00Z"` |
| `available_changed_by_name` | `string \| null` | `"Laura Gómez"` |

`null` en ambos significa "nunca se tocó el interruptor dedicado desde que existe esta
columna" (incluye todo producto creado antes de esta spec) — el frontend no debe mostrar
"hace unos segundos" ni ninguna fecha en ese caso (data-model.md, Compatibilidad).

## `GET /products/{id}` — `ProductDetailResponse` gana `variants`

Antes de esta spec, `ProductDetailResponse` era idéntico a `ProductResponse` (sin
presentaciones). Pasa a incluir:

```json
{
  "...": "...campos de ProductResponse sin cambios...",
  "variants": [
    {
      "id": "…",
      "product_id": "…",
      "sku": "COPA-1L",
      "price": "18000.00",
      "active": true,
      "presentation_id": "…",
      "presentation_name": "1 litro"
    }
  ]
}
```

- Solo variantes con `active=true`.
- Shape = `VariantResponse` ya existente (`app/api/v1/catalog/schemas.py`) — **sin**
  `recipe` ni `option_groups` (esos campos no existen en este shape; son exclusivos de
  `VariantSaveOut`, usado únicamente por `POST`/`PATCH /products`).
- No requiere ninguna llamada adicional del frontend para pintar el detalle de solo
  lectura del escenario 9 (imagen, nombre, descripción, categoría, preparación,
  presentaciones con precio, estado, disponibilidad).
- No cambia el comportamiento del formulario de edición de Admin, que sigue obteniendo
  sus presentaciones por `GET /variants?product_id=...` (sin cambios, research.md D9).

## `GET /variants/{variant_id}/recipe` — restringido para `CASHIER`

**Autorización**: pasa de "cualquier autenticado" a excluir explícitamente
`role.name == "CASHIER"` (403). Sin cambio para `ADMIN`. `MESERO` sigue bloqueado por su
propio mecanismo de default-deny, sin relación con este cambio.

**Respuesta 403 para Cajero**:
```json
{ "detail": "No autorizado para consultar la receta de este producto" }
```

Esto cubre el escenario 12 (consultar un producto por API como Cajero no debe traer
costo, receta ni datos de inventario) para el único endpoint de este router que sí
exponía datos de receta (`inventory_item_id`, `quantity`).
