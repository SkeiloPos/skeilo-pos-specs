# Contract: API de promociones y menú QR — visibilidad en QR

Describe únicamente los cambios de contrato sobre endpoints ya existentes. Ningún endpoint
nuevo se introduce.

## 1. `PATCH /promotions/{promotion_id}` (admin)

Endpoint existente (`app/api/v1/promotions/router.py`, `update_promotion`), protegido por
`require_module_access("promociones")` + `Depends(require_tenant_admin)`.

**Request body** (`PromotionUpdate`) — campo nuevo, opcional:

```json
{
  "visible_en_qr": true
}
```

- Tipo: `boolean | null`. Si se omite o es `null`, no cambia el valor actual.
- Disponible sin importar el `status` de la promoción (`draft`/`active`/`paused`/`finished`).
- Permisos: igual que el resto de campos de `PromotionUpdate` — solo roles con permiso de
  administrar promociones; cualquier otro rol recibe `403` (FR-009).

**Response** (`PromotionResponse`) — campo nuevo, siempre presente:

```json
{
  "id": "uuid",
  "name": "string",
  "...": "...",
  "visible_en_qr": true
}
```

## 2. `GET /promotions` (admin, listado)

**Response** — cada elemento de la lista (`PromotionResponse`) incluye `visible_en_qr` para
que la pantalla de administración pueda mostrar el indicador por fila (FR-010).

## 3. `GET /menu/qr-token/{token}` (comensal, menú QR firmado)

Endpoint existente (`app/api/v1/menu/router.py`, `menu_by_signed_qr`). **No cambia su forma**
(sigue devolviendo `table`, `business`, `menu`, `promotions`), pero cambia el *contenido* de
`promotions`:

- `promotions: MenuPromotionAnnouncement[]` ahora **excluye** cualquier promoción con
  `visible_en_qr=false` o sin ningún producto/variante alcanzable por QR (FR-003, FR-004).
- Cuando ninguna promoción cumple el predicado de FR-005, `promotions` es `[]` — el frontend
  usa esto para decidir si muestra la pestaña "Promociones" (contrato implícito ya existente
  en el shape del response; antes el frontend ignoraba este caso, ver FR-005/FR-006).
- Cuando una promoción sí se anuncia, se incluyen **todas** sus reglas (`rules[]`) sin
  filtrar — nunca una promoción con un subconjunto de sus reglas ocultas.

## 4. `GET /menu` (catálogo no firmado / staff — "Nuevo pedido" en caja o mesa)

**Sin cambios de contrato.** No se aplica ningún filtro de `visible_en_qr` a promociones en
este camino — la disponibilidad y aplicación de promociones en pedidos manuales permanece
idéntica (FR-007).

## 5. Carrito / pedido del comensal (`cart/service.py`, canal `QR_MENU`)

**Sin cambios de forma de response.** Cambia el *cálculo*: ninguna línea de descuento
originada por una promoción con `visible_en_qr=false` se incluye en `evaluate_variant_sets`
cuando el origen es el carrito/pedido de un comensal por QR (FR-008). El total del pedido
refleja el precio sin ese descuento, sin bloquear el resto del pedido.

## 6. Checkout de pedidos manuales (`orders/checkout.py`, canal `POS`)

**Sin cambios de contrato ni de cálculo.** La exclusión de FR-008 no aplica a pedidos con
`CustomerOrder.channel == 'POS'`.
