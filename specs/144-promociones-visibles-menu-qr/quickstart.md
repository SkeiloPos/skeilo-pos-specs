# Quickstart: Visibilidad de promociones en el menú QR

Guía de validación manual end-to-end tras implementar las tareas de esta feature. No
sustituye los tests automatizados (ver data-model.md y contracts/promotions-api.md para el
detalle de qué debe cumplirse).

## Prerrequisitos

- Backend (`pos-backend`) corriendo con migraciones aplicadas, incluida la nueva
  `144_promotions_visible_en_qr` (`alembic upgrade head`).
- Frontend (`pos-heladeria`) corriendo contra ese backend.
- Un tenant con al menos: 1 categoría y 1 producto/variante visibles en QR, y una promoción
  existente que aplique sobre ese producto.
- Un token de menú QR firmado válido para una mesa de ese tenant (o el flujo habitual de
  escanear/abrir el menú QR de una mesa).
- Un usuario con permiso de administrar promociones, y uno sin ese permiso.

## Escenario A — US1: la pestaña se oculta sin promociones ofrecibles

1. En administración, pausa o deja vencer **todas** las promociones del tenant (o verifica
   que ninguna esté `active` y vigente en este momento).
2. Abre el menú QR de una mesa (`GET /menu/qr-token/{token}`).
   - **Esperado**: la respuesta trae `promotions: []`; la pestaña "Promociones" no aparece
     entre las pestañas del menú.
3. Activa una promoción vigente, visible en QR, con al menos un producto alcanzable por QR.
4. Recarga el menú QR.
   - **Esperado**: `promotions` trae esa promoción; la pestaña "Promociones" aparece y, al
     seleccionarla, muestra el detalle completo de esa promoción.

## Escenario B — US2: ocultar una promoción solo del menú QR

1. En administración de promociones, con una promoción `active` y vigente, actívale el
   control "No mostrar en menú QR" (`PATCH /promotions/{id}` con `visible_en_qr: false`).
   - **Esperado**: `200`, el indicador de la fila cambia a "oculta en QR".
2. Recarga el menú QR de una mesa.
   - **Esperado**: esa promoción ya no aparece en `promotions`, y si era la única vigente,
     la pestaña "Promociones" desaparece (cubre también el Escenario A).
3. Desde caja o mesa, inicia "Nuevo pedido" manual con un producto que califica para esa
   promoción.
   - **Esperado**: la promoción se sigue ofreciendo y aplicando con normalidad — sin cambios
     frente al comportamiento antes de esta feature (FR-007).
4. Vuelve a marcar la promoción como visible en QR (`visible_en_qr: true`).
   - **Esperado**: reaparece en el menú QR (si sigue vigente) sin pérdida de configuración
     (reglas, vigencia, estado intactos).
5. Repite el paso 1 con un usuario **sin** permiso de administrar promociones (vía UI y vía
   llamada directa al endpoint).
   - **Esperado**: la UI no muestra el control; la llamada directa devuelve `403`.
6. Abre la pantalla de edición de una promoción `finished`/`paused`/`draft`.
   - **Esperado**: el control de visibilidad en QR sigue visible y editable, aunque no tenga
     efecto observable en el menú QR hasta que la promoción vuelva a estar vigente.

## Escenario C — US3: no se aplica el descuento de una promoción recién ocultada

1. Desde el menú QR, agrega al carrito un producto que califica para una promoción
   actualmente visible en QR y vigente. Confirma en `GET /cart` que el descuento aparece.
2. Desde administración, oculta esa promoción del menú QR (`visible_en_qr: false`), sin
   tocar el carrito del comensal.
3. Envía el pedido del comensal (`submit_cart` / equivalente de "enviar pedido").
   - **Esperado**: el pedido se acepta; el total refleja el precio normal del producto, sin
     el descuento de la promoción oculta; el resto del pedido no se bloquea.
4. Verifica, por contraste, que un pedido **manual** (canal `POS`) creado en el mismo
   instante, con el mismo producto, sigue aplicando el descuento de esa promoción con
   normalidad.

## Edge cases a verificar

- Promoción visible en QR cuyo único producto alcanzable está, a su vez, oculto en QR (por
  producto o por categoría): no debe contar como vigente para el comensal ni aparecer en el
  listado (FR-004, edge case 1 del spec).
- Promoción visible en QR pero fuera de su ventana horaria/días configurados: no cuenta como
  vigente para efectos de la pestaña ni del listado (edge case 2 del spec).

## Dónde mirar si algo falla

- Filtro de listado/pestaña: `_build_menu_promotions` en
  `pos-backend/app/api/v1/menu/router.py`.
- Cálculo de descuentos: `active_variant_set_rules()` /
  `promotions.evaluate_variant_sets()` en `pos-backend/app/api/v1/promotions/service.py`,
  consumido desde `cart/service.py` y `orders/checkout.py`.
- Toggle de administración: `promotion.service.ts` / `promotions-page.component.ts` en
  `pos-heladeria`.
