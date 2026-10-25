# Contrato: etiquetas que alternan estados

**Cubre**: FR-021, FR-022 · **Historia**: US5 · **Decisión**: [research.md](../research.md) 7

## Regla de conversión

El criterio de cierre lo da el escáner: `python3 specs/134-bloqueo-traduccion-automatica/tools/scan-loose-text.py ../pos-heladeria/src/app`
(hoy: **55 bloques en 21 archivos**; la spec cita 47 por otra metodología —"al menos"—). Tras el
arreglo debe imprimir `TOTAL bloques con texto suelto: 0`.

### Nivel A — todo bloque con texto suelto

Cada rama del control de flujo envuelve su texto en un `<span>` propio. Cuando la rama cambia,
Angular quita el `<span>` completo y no queda texto de la rama anterior, aunque el traductor haya
envuelto su contenido en `<font>`.

```text
Antes:   <button>@if (enviando()) { Enviando pedido… } @else { Enviar pedido }</button>
Después: <button>@if (enviando()) { <span>Enviando pedido…</span> } @else { <span>Enviar pedido</span> }</button>
```

### Nivel B — etiqueta alternante que además incluye un valor dinámico

El `<span>` se alimenta con `[textContent]` de una señal/`computed` que arma la cadena completa.
Cada cambio del valor **reemplaza todos los hijos** del `<span>`, de modo que la pantalla siempre
vuelve a mostrar el valor real del estado.

```text
Antes:   @if (falta()) { {{ falta() }} } @else { Agregar · {{ total() | money }} }
Después: <span [textContent]="etiquetaAgregar()"></span>      // computed: falta() ?? `Agregar · ${money(total())}`
```

Criterio de selección del nivel B: la etiqueta alterna entre textos **y** una de sus ramas lleva un
valor (precio, cantidad, segundos). Mínimo: "Agregar · total" de `product-select` (QR) y
`product-select-pos` (POS), y "Reenviar enlace en N s". La lista final se fija al implementar con
el escáner; el resto de las ~917 interpolaciones **no** se reescribe (las cubre el aviso).

## Invariantes (FR-022 / no regresión)

- Sin traductor, el DOM visible es idéntico: mismo texto, mismo orden, mismo formato (los pipes y
  los separadores `·` se conservan literalmente).
- No cambian estilos, clases ni lógica de los componentes; solo se envuelve texto y, en el nivel B,
  se mueve la concatenación a un `computed` equivalente.
- Un botón con icono + texto (`<app-mi-icon/> …`) conserva el icono fuera del `<span>`.
- Las pruebas existentes de cada plantilla tocada siguen pasando sin modificarse; si una aserción
  depende de `textContent` exacto del botón, el `<span>` no la altera.

## Pruebas

| Prueba | Tipo |
|---|---|
| Por cada componente nombrado en la spec (botón "Enviar pedido", "Agregar" QR y POS, "Iniciar sesión", "Reenviar enlace en N s"): con el traductor simulado aplicado, alternar el estado N veces deja **solo** el texto del estado actual (0 apariciones de "Enviar pedido Enviar pedido") | unitaria con envoltura simulada de nodos de texto |
| Nivel B: cambiar el valor (cantidad 1→3) con los nodos envueltos muestra el total nuevo | unitaria |
| Sin traductor: mismas aserciones de texto que antes de la conversión | specs existentes |
| Escáner arroja 0 | verificación (quickstart V7) |

## Lista final (resultado de la implementación, 2026-10-24)

Criterio aplicado a cada bloque que arrojó el escáner: **nivel B** si la etiqueta *alterna entre textos y
una de sus ramas lleva un valor que cambia mientras la persona interactúa* (precio, cantidad, segundos,
lo que escribe en un buscador, cuántos productos eligió); **nivel A** en cualquier otro caso.

### Nivel B — `[textContent]` (6 etiquetas; cada una con su caso en el spec hermano)

| Etiqueta | Archivo | Qué sigue | Caso de prueba |
|---|---|---|---|
| "Agregar · total" / lo que falta (menú QR) | `product-select.component.ts` | cantidad, presentación | `product-select.component.spec.ts` |
| "Agregar · total" / lo que falta (POS) | `product-select-pos.component.ts` | cantidad, presentación | `product-select-pos.component.spec.ts` (nuevo) |
| "Reenviar enlace en N s" ↔ "Reenviar enlace" | `forgot-password.component.ts` (`resendLabel`) | segundos restantes | `forgot-password.component.spec.ts` |
| Catálogo vacío del menú QR | `public-menu.component.ts` (`emptyCatalogMessage`) | lo escrito en el buscador | `public-menu.component.spec.ts` |
| Catálogo vacío del POS | `pos-catalog-drawer.component.ts` (`emptyMessage`) | lo escrito en el buscador | `pos-catalog-drawer.component.spec.ts` |
| Aviso del picker de presentaciones | `promotions-page.component.ts` (`pickerMatchMessage`) | productos elegidos y coincidentes | `promotions-page.component.spec.ts` |

### Nivel A — `<span>` por rama (todo lo demás)

Los otros 43 bloques reales (49 menos los 6 de nivel B que se resolvieron con `[textContent]`). No se
subieron a nivel B por no cumplir el criterio: alternan por estado de datos que no cambia con la
interacción (p. ej. "Ilimitado" ↔ "N de M" en el plan, "Pendiente: …" en una compra, la insignia de
descuento de una presentación) o no alternan (`@if` de una sola rama como "· N pedido(s) activo(s)" del
dashboard). Para esos, como para las ~917 interpolaciones restantes, la garantía es el aviso + el bloqueo
de acciones (US2).

### Falsos positivos del escáner (6 de los 55 bloques originales, 2 archivos enteros)

El primer conteo ("55 bloques en 21 archivos") incluía **falsos positivos**: las declaraciones
`@let x = …;` (no pintan texto) y un `@else if (…)` con paréntesis anidados a más de dos niveles. Se
refinó `tools/scan-loose-text.py` para ignorarlos. Medido sobre el código original (`develop`): la
herramienta original da **55 bloques en 21 archivos**; la refinada, **49 bloques en 19 archivos**.
`pos-order-panel.component.ts` y `pos-checkout-panel.component.ts` solo tenían falsos positivos y no
necesitaron edición (T076 y T077 sin cambios de plantilla); `manual-order-page`, `public-menu`,
`product-detail-page` y `product-form` tenían uno cada uno además de sus bloques reales.
