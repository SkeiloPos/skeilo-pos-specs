# Contrato — Ajuste automático de adiciones al reducir cantidad de producto (D3, D4, D5)

**Endpoint**: `PATCH /cart/items/{id}` (`cart/service.py::update_item`) — único camino de backend
donde puede reducirse la cantidad de producto de una línea que ya tiene adiciones "Por cantidad"
elegidas (ver `research.md` D3; Terminal POS y el modal de selección resuelven el caso
equivalente enteramente en el frontend, sin pasar por este endpoint, con el mismo criterio D4).

## Request — sin cambio de forma

```json
PATCH /cart/items/{id}
{ "quantity": 1 }
```

(`options` puede omitirse — es exactamente el caso que hoy no revalida nada, research.md D3).

## Response — campo nuevo aditivo

```jsonc
{
  "id": "...",
  "product_variant_id": "...",
  "quantity": 1,
  "unit_price": "18000.00",
  "addons_total": "1000.00",
  "line_total": "19000.00",
  "options": [
    { "id": "...", "option_id": "<gomitas>", "quantity": 1, "per_line": true }
  ],
  "adjusted_options": [
    {
      "option_id": "<gomitas>",
      "option_name": "Gomitas",
      "previous_quantity": 2,
      "new_quantity": 1
    }
  ]
}
```

- `adjusted_options` es `[]` en toda respuesta donde no hubo ajuste automático (la inmensa
  mayoría de los `PATCH`) — es aditivo y no rompe a ningún cliente que lo ignore.
- Solo aparece poblado en la respuesta del `PATCH` que **disparó** el ajuste. `GET /cart` y
  cualquier `PATCH` posterior no lo repiten — las cantidades ya ajustadas se leen de
  `options[].quantity`, que es el estado real y definitivo.
- `options[].quantity` refleja siempre el valor **después** del ajuste (`new_quantity`), nunca el
  valor que el cajero/comensal tenía antes de reducir la cantidad de producto.

## Algoritmo (D4)

1. Calcular los topes escalados con la **nueva** `quantity` (ver
   [option-selection-validation.md](./option-selection-validation.md)).
2. Para cada opción de un grupo `selection_mode = 'cantidad'` cuya `quantity` propia exceda su
   `max_quantity_per_option` escalado: reducirla hasta ese tope.
3. Si, tras el paso 2, la suma de cantidades del grupo sigue excediendo `max_total_quantity`
   escalado: ordenar las opciones del grupo por `Option.name` descendente **sobre su forma
   normalizada (`casefold`/`toLocaleLowerCase('es-CO')`, ver research.md D4)**, con desempate por
   `option_id`, y reducir de una unidad a la vez la primera opción de ese orden —pasando a la
   siguiente solo cuando la anterior llega a `0` o la suma ya cumple el tope— hasta satisfacerlo.
4. Cada reducción efectiva (cantidad final ≠ cantidad previa) se agrega a `adjusted_options`.
5. Recalcular `unit_price`/`addons_total`/`line_total` con las cantidades ya ajustadas (mismo
   cálculo de [line-pricing-per-line-cantidad.md](./line-pricing-per-line-cantidad.md)).

Un grupo sin ningún tope configurado nunca entra en este algoritmo (no hay nada que ajustar por
este motivo — `FR-008` de spec 065 sigue vigente sin cambios).

## Ejemplo (Historia 3, Escenario 2 — dos adiciones en conflicto)

Grupo "toppings", `max_total_quantity = 2`, línea con cantidad de producto 2 ⇒ tope vigente al
crearla: `2×2=4`. Adiciones elegidas: "Gomitas" ×2 + "Chocolate" ×1 (suma 3, dentro de 4). El
cajero reduce la cantidad de producto a 1 ⇒ nuevo tope `2×1=2` < 3 ⇒ orden alfabético descendente
= `["Gomitas", "Chocolate"]` ⇒ se reduce "Gomitas" de 2 a 1 (suma pasa a 2) ⇒ cumple el tope, no
se toca "Chocolate". Respuesta: `adjusted_options: [{"option_name": "Gomitas", "previous_quantity":
2, "new_quantity": 1}]`.
