# Contrato: peticiones de red que deja de disparar el formulario de producto

**Spec**: [../spec.md](../spec.md) (FR-001, FR-002) · **Research**: [../research.md](../research.md)

Este no es un contrato de interfaz nueva, sino la confirmación explícita — para que
`/speckit-tasks` y la implementación tengan un criterio verificable sin ambigüedad — de qué
peticiones HTTP deja de disparar la apertura del formulario de crear/editar producto, y cuáles
siguen exactamente igual.

## Se eliminan (disparadas hoy desde `product-form.component.ts`, `ngOnInit`)

| Petición | Disparada hoy por | Se elimina la llamada en |
|---|---|---|
| `GET /categories?size=100` | `categoryService.loadAllCategories()` | `product-form.component.ts`, `ngOnInit()` |
| `GET /items?size=100` | `inventoryService.loadAllItems()` | `product-form.component.ts`, `ngOnInit()` |
| `GET /presentations?size=100` | `presentationService.loadAllPresentations()` | `product-form.component.ts`, `ngOnInit()` |

Ninguna de las tres deja de existir como capacidad del servicio (`category.service.ts`,
`inventory.service.ts`, `presentation.service.ts` no cambian) — solo dejan de ser invocadas desde
este punto de entrada. Otras pantallas las siguen invocando desde su propio `ngOnInit`/constructor
(ver `research.md`, "Otros consumidores").

## No cambian

| Petición | Uso |
|---|---|
| `GET /products/{id}` | Detalle del producto al editar — ya incluye `category_name`, `presentation_name` por variante, receta y grupos de opciones (spec 097, 103). Fuente de FR-003. |
| `GET /categories?search={texto}&active=true` (vía `searchActiveCategories`) | Búsqueda remota del selector de categoría (spec 102) — FR-005. |
| `GET /items?search={texto}&active=true` (vía `searchActiveItems`) | Búsqueda remota del selector de insumos (spec 098/102) — FR-005. |
| `GET /presentations?search={texto}&active=true` (vía `searchActivePresentations`) | Búsqueda remota del selector de presentación (spec 102) — FR-005. |
| `GET /items/{id}` (vía `resolveMissingItems`) | Resolución puntual del nombre de un insumo no conocido localmente — ahora el único camino para insumos de receta/consumo (ver `data-model.md`). |

## Caso límite documentado: `hasFreePresentations` (Decisión D2 de `research.md`)

La verificación de "¿queda alguna presentación activa libre?" deja de usar
`GET /presentations?size=100` y pasa a reutilizar `searchActivePresentations('')` (mismo mecanismo
de búsqueda remota ya contado arriba, con texto vacío), disparada de forma perezosa en vez de
dentro del `ngOnInit()` del formulario. No es una petición nueva de catálogo completo: reutiliza un
endpoint que esta misma spec ya mantiene vigente para la búsqueda.

## Criterio de verificación (para `quickstart.md` y los tests de la implementación)

Con el panel de red del navegador abierto, al abrir el formulario de crear o editar un producto:

1. **DEBE** aparecer una única petición `GET /products/{id}` (solo al editar).
2. **NO DEBE** aparecer ninguna petición a `GET /categories`, `GET /items` ni
   `GET /presentations` sin parámetro `search` (es decir, ninguna con `size=100` ni equivalente de
   página completa).
3. Al escribir en cualquiera de los tres selectores, **DEBE** aparecer la petición
   correspondiente con `search={texto escrito}`.
