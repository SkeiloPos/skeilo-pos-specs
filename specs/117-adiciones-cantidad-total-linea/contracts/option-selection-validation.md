# Contrato — Topes de grupo "Por cantidad" escalados por cantidad de producto (D2, D8)

**Afecta a**: todo endpoint que valida una selección de opciones contra los topes de un grupo
`selection_mode = 'cantidad'` (`max_quantity_per_option`, `max_total_quantity`, spec 065 `FR-008`).

## Cambio de firma (interno, no HTTP)

```python
# Antes
def validate_option_selection(db: Session, variant: ProductVariant, options: Sequence[ChosenOption]) -> None: ...
def load_valid_options(db: Session, ..., variant: ProductVariant | None = None) -> list[ChosenOption]: ...

# Después
def validate_option_selection(
    db: Session, variant: ProductVariant, options: Sequence[ChosenOption], quantity: int = 1,
) -> None: ...
def load_valid_options(db: Session, ..., variant: ProductVariant | None = None, quantity: int = 1) -> list[ChosenOption]: ...
```

`quantity` es la cantidad de producto de la línea que se está creando o editando. El valor por
defecto `1` reproduce el tope fijo de hoy para cualquier llamador que no la pase (solo tests
aislados de la función; ningún camino de producción queda en ese caso — ver tabla abajo).

## Regla de validación

Para un grupo `selection_mode = 'cantidad'`:

```
tope_por_opción_escalado = group.max_quantity_per_option × quantity   (si está configurado)
tope_total_escalado      = group.max_total_quantity × quantity         (si está configurado)
```

Un grupo sin ningún tope configurado (`FR-008` de spec 065, ambos opcionales) sigue sin ningún
ajuste automático por este motivo — único límite posible: stock disponible (spec 003, sin
cambios).

## Endpoints afectados (mismo contrato HTTP; cambia el resultado de la validación)

| Endpoint | Call-site que pasa `quantity` |
|---|---|
| `POST /cart/items` | `cart/service.py::add_item` — `data.quantity` |
| `PATCH /cart/items/{id}` | `cart/service.py::update_item` — `new_qty` (cantidad resultante tras el PATCH) |
| `POST /orders` | `orders/service.py::create_order` — `line.quantity` |
| `GET /orders/{id}/draft-preview` (o equivalente) | `orders/checkout.py::compute_draft_preview` — `item.quantity` |
| `POST /sales/checkout` | `sales/service.py::checkout` — `line.quantity` |
| `POST /orders/{id}/items` | `orders/consolidation.py::add_item_to_order` — `data.quantity` |

**Respuesta de error sin cambio de forma**: sigue siendo `HTTPException(422, ...)` con el mismo
mensaje descriptivo ya existente, solo que ahora compara contra el tope escalado. Una selección
que hoy se rechaza (ej. 3 unidades de una opción con tope fijo 2) puede pasar a aceptarse si la
cantidad de producto de la línea la hace caber en el tope escalado (ej. cantidad de producto 2 ⇒
tope escalado 4 ≥ 3) — es el comportamiento que pide `FR-004`, autorizado explícitamente por la
spec; no afecta ninguna línea ya creada (Principio VII).

## Ejemplo (Historia 3, Escenario 1)

Grupo "toppings" con `max_quantity_per_option = 1`. Línea con cantidad de producto 2 y 2 unidades
de "gomitas" (dentro del tope escalado 1×2=2, válido al crearla). El cajero reduce la cantidad de
producto a 1 ⇒ nuevo tope escalado 1×1=1 < 2 ya elegidas ⇒ dispara el ajuste automático de
[cart-item-auto-adjust.md](./cart-item-auto-adjust.md), no un 422 (la validación con tope escalado
solo bloquea una selección **nueva** que exceda el tope; una reducción sobre una línea ya válida se
resuelve ajustando, nunca rechazando una operación que el cajero ya confirmó).
