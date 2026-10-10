# Research: comprar en la presentación real, no en la unidad base

Sin `NEEDS CLARIFICATION` abiertos (la única clarificación de la spec se resolvió en
`/speckit-clarify`). Este documento registra decisiones de diseño, todas confirmadas leyendo el
código real de `pos-backend`/`pos-heladeria`.

## D1 — Snapshot del texto de la presentación, no solo una referencia (hallazgo nuevo)

**Decision**: `PurchaseItem` guarda `presentation_label: str | NULL`, una **copia** del texto de
`SupplierItem.presentation` en el momento de la compra — además de `supplier_item_id` (ya
existe desde spec 106, FK en vivo a la relación).

**Rationale**: la propia spec 106 (sección Assumptions) deja explícito que el *texto* de una
presentación (a diferencia de su factor, bloqueado por FR-014) **no** queda bloqueado después de
usarse en una compra — un administrador puede editar "Bolsa x 500 g" a "Bolsa Grande" después. Si
el historial de una compra vieja solo guardara `supplier_item_id` y resolviera el texto por un
join en vivo, una edición posterior cambiaría silenciosamente cómo se ve una compra ya cerrada —
exactamente el tipo de alteración retroactiva que el Principio VII de la constitución prohíbe
para datos históricos. Guardar una copia del texto en el momento de la compra es lo mínimo para
que "qué compré" no cambie después de comprarlo.

**Alternatives considered**: solo `supplier_item_id` con resolución en vivo — rechazado, por la
razón de arriba; duplicar también el factor de conversión usado — rechazado, es derivable
siempre (`quantity ÷ presentation_quantity`) y guardarlo aparte solo agregaría una forma más de
que los dos números queden inconsistentes entre sí sin que nada lo detecte.

## D2 — Validación "exactamente un modo" a nivel de esquema, no de servicio

**Decision**: `PurchaseItemIn` valida con un `model_validator` de Pydantic (no en
`service.py`) que **o bien** viene `quantity` (camino directo, como hoy) **o bien** viene
`supplier_item_id` + `presentation_quantity` (camino nuevo) — nunca ambos, nunca ninguno.

**Rationale**: a diferencia del mensaje dinámico de factor inválido de la spec 106 (que necesita
el insumo cargado de la base de datos para nombrar su unidad, y por eso vive en el servicio),
"¿vino `quantity` o vino `supplier_item_id`?" es una pregunta que solo depende de la forma del
propio request — no necesita ninguna consulta. Resolverlo en el esquema significa que FastAPI ya
responde 422 antes de que el servicio llegue a tocar la base de datos, con el mismo mecanismo
estándar que cualquier otro error de validación del request.

**Alternatives considered**: validarlo en `service.py` junto con el resto de las reglas de
negocio — rechazado, mezclaría una validación de forma (no de negocio) con las que sí necesitan
la base de datos, sin ninguna ventaja a cambio.

## D3 — Dónde y cuándo se aplica RN-15 (último costo del proveedor)

**Decision**: `supplier_items.apply_purchase_cost(db, relation, cost_per_presentation)` (función
nueva, pública, sin `commit()` propio — mismo patrón que `_apply_preferred_swap` de la spec 106,
que confía en que el llamador cierre la transacción) se invoca en **dos** momentos: al registrar
una compra directa, y al **crear** una orden de compra — nunca al recibirla.

**Rationale**: RN-INV-22 (protegida) ya establece que el costo pactado al crear una orden no
cambia al recibirla — el "último costo" del proveedor, en términos de negocio, se fija cuando se
**pacta** el precio, no cuando la mercancía físicamente llega. Actualizar `last_cost_at` en cada
recepción parcial de una misma orden haría que la fecha de "último costo" avanzara varios días
después sin que el precio realmente haya cambiado, dando una fecha falsa a quien consulte la
pestaña "Proveedores".

**Alternatives considered**: actualizar en cada recepción — rechazado, por la razón de arriba;
actualizar solo al recibir por completo — rechazado, no resuelve el problema (el precio sigue
siendo el pactado al crear, no el de la última recepción) y además una orden puede no completarse
nunca.

## D4 — El factor de conversión de la recepción se recupera del `PurchaseItem`, nunca del request

**Decision**: `receive_purchase` ignora cualquier factor que pudiera llegar por el request de
recepción — si el `PurchaseItem` que se está recibiendo tiene `supplier_item_id`, el factor para
convertir `presentation_quantity` (lo recibido) a unidad base se lee de
`SupplierItem.conversion_factor` **en ese momento**, el mismo registro que ya quedó fijado al
crear la orden.

**Rationale**: aunque hoy la spec 106 permite que el factor de una relación se edite mientras no
se haya usado en ninguna compra, **la propia orden que se está recibiendo ya cuenta como ese uso**
desde el momento en que se creó — así que FR-014 (spec 106) ya bloquea cualquier edición del
factor antes de que pueda llegar una recepción con un factor distinto. Este diseño no necesita
una guarda adicional: simplemente nunca lee un factor que el cliente proponga, solo el que ya está
fijado en la base de datos.

**Alternatives considered**: que el request de recepción repita el factor pactado, para
validarlo contra el guardado — rechazado, es información redundante que el cliente no necesita
enviar ni el servidor necesita comparar, dado que FR-014 ya hace imposible que el factor guardado
cambie después de la primera compra.

## D5 — Reutilizar el selector de presentación del frontend sin un endpoint nuevo

**Decision**: `purchase-form.component.ts` resuelve las presentaciones disponibles para una
línea llamando a `SupplierItemsService.listForItem(itemId, false)` (ya existente, spec 106) y
filtrando en el cliente por el `supplier_id` ya elegido para toda la compra — sin ningún endpoint
de lectura nuevo.

**Rationale**: `PurchaseCreate.supplier_id` ya es un solo proveedor para **toda** la compra (no
por línea) — confirmado leyendo `schemas.py` — así que no hace falta que el backend filtre nada
por proveedor: el frontend ya sabe cuál es, y la lista de relaciones de un insumo rara vez supera
unas pocas filas (no amerita paginación ni un endpoint dedicado).

**Alternatives considered**: un endpoint nuevo `GET /inventory/items/{id}/suppliers?supplier_id=`
— rechazado, añadiría un parámetro de filtro a un endpoint que ya devuelve pocas filas, sin
ningún beneficio de rendimiento real.
