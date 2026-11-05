# Contrato: `GET /products` (listado de la Carta del menú)

**Feature**: `152-rediseno-listado-carta-menu` | Endpoint existente, ampliado.

## Request

```
GET /products?page={int}&size={int}
            &active={bool}&available={bool}
            &search={string}&is_topping={bool}
            &category_id={uuid}            ← NUEVO
```

Todos los parámetros son opcionales salvo `page`/`size` (con default `page=1`,
`size=20`, igual que hoy). `category_id`, si se envía, se combina con AND a cualquier
otro filtro presente (FR-004) — no reemplaza `search`, `active` ni `available`.

Autenticación: Bearer token, cualquier rol autenticado (sin cambio — `get_current_user`,
igual que hoy; Admin y Cajero comparten el listado, spec 093).

## Response — `200 OK`

`Page[ProductListResponse]` (misma envoltura de paginación de `fastapi-pagination` que
ya usa el endpoint: `items`, `total`, `page`, `size`, `pages`).

```jsonc
{
  "items": [
    {
      "id": "b3f1c9a0-...",
      "category_id": "a1e2d3c4-...",
      "category_name": "Helados",     // null => el cliente muestra "Sin categoría"
      "name": "Copa de helado",
      "image_url": "https://.../copa.jpg", // null => el cliente muestra "Sin imagen"
      "preparation_type": "prepared",
      "active": true,
      "available": true,
      "available_changed_at": null,
      "created_at": "2026-10-01T10:00:00Z",
      "updated_at": "2026-10-20T15:30:00Z",
      "price_display": "9000.00",     // Decimal serializado; null => "Sin precio"
      "price_from": true              // true => el cliente antepone "Desde"
    }
  ],
  "total": 42,
  "page": 1,
  "size": 20,
  "pages": 3
}
```

### Campos retirados de la respuesta respecto al `ProductResponse` completo

`code`, `description`, `tracks_inventory`, `is_topping`, `visible_en_qr`,
`available_changed_by_name` — ver data-model.md ("Campos excluidos") y research.md D4
para la justificación (FR-008/SC-004). Siguen disponibles en `GET /products/{id}`
(`ProductDetailResponse`), sin cambios.

### Casos de `price_display` / `price_from`

| Variantes activas con `price > 0` | `price_display` | `price_from` | Texto en cliente |
|---|---|---|---|
| 0 | `null` | `false` | "Sin precio" |
| 1 | ese precio | `false` | "$12.000" |
| ≥2 | el mínimo | `true` | "Desde $9.000" |

## Compatibilidad hacia atrás

- Ningún parámetro ni campo existente cambia de tipo o de semántica.
- `category_id` ausente ⇒ comportamiento idéntico al actual (sin filtrar por
  categoría).
- El único otro consumidor conocido de este endpoint
  (`pos-heladeria/.../product.service.ts:searchActiveToppingProducts`, picker de
  "Adiciones disponibles") solo lee `id`/`name` de cada item — no se ve afectado por el
  recorte de campos.

## Errores

Sin cambios respecto al endpoint actual: `401` si no autenticado/token inválido. Un
`category_id` que no corresponda a ninguna categoría existente no es un error — el
filtro simplemente no encuentra coincidencias (mismo criterio que `search` hoy), igual
al Edge Case "categoría sin productos coincidentes" del spec (mensaje de "sin
resultados" lo decide el cliente, no un 404 del servidor).
