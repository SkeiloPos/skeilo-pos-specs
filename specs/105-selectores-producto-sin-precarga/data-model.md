# Data Model: Quitar la precarga de catálogos completos en los selectores del formulario de producto

**Spec**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md) · **Research**: [research.md](./research.md)

Esta corrección no agrega entidades de dominio ni cambia el modelo de datos de backend (FR-009,
`research.md`). Las entidades de negocio ya existentes se describen aquí solo para dejar explícito
qué campos consume cada selector y de qué respuesta provienen — el cambio real es de **dónde** se
obtiene cada campo (detalle de producto / búsqueda remota) en vez de la precarga completa, y el
estado local nuevo que cada selector mantiene en el frontend para recordar el nombre de un valor
recién elegido (Decisión D1 de `research.md`).

## Entidades de dominio (ya existentes, sin cambios de esquema)

### Categoría

| Campo | Origen tras esta corrección |
|---|---|
| `id` | `GET /products/{id}` → `category_id` (valor ya guardado) **o** selección hecha en la sesión actual vía `searchActiveCategories` |
| `name` | `GET /products/{id}` → `category_name` (valor ya guardado, spec 097) **o** la etiqueta ya devuelta por `searchActiveCategories` para una selección nueva (Decisión D1) |

### Presentación (por tamaño/variante)

| Campo | Origen tras esta corrección |
|---|---|
| `id` | `GET /products/{id}` → `variants[].presentation_id` (valor ya guardado, spec 103) **o** selección nueva vía `searchActivePresentations` |
| `name` | `GET /products/{id}` → `variants[].presentation_name` (valor ya guardado) **o** la etiqueta ya devuelta por `searchActivePresentations` para una selección nueva |

### Insumo (Inventory Item) — en una fila de receta o de consumo de opción

| Campo | Origen tras esta corrección |
|---|---|
| `id` | `GET /products/{id}` → `recipe[].inventory_item_id` / detalle de consumo de opción (valor ya guardado) **o** selección nueva vía `searchActiveItems` |
| `name`, `unit_measure_id` | Resueltos por `InventoryService.resolveMissingItems()` (ya existente, spec 102) para cualquier id que no esté en `resolvedExtraItems` — ahora el único camino, no un respaldo de `allItems()` |

Ninguna de las tres entidades cambia sus campos, validaciones ni reglas de negocio (quién puede
crearlas, qué significa "activo"). Ver spec 105, sección "Key Entities".

## Estado local nuevo del formulario (frontend, sin persistencia de backend)

Este estado existe únicamente dentro del componente de formulario mientras está abierto; no se
guarda en ningún almacenamiento del navegador ni se envía al backend como tal (solo los ids
finales viajan al guardar el producto, igual que hoy — FR-009).

### Selector de categoría / presentación

- **Antes de esta corrección**: el nombre del valor seleccionado se leía exclusivamente de
  `draft().category_name` / `draft().presentationName` (campos que ya existían en el draft
  cargado del detalle del producto).
- **Después de esta corrección**: esos mismos campos del draft pasan a actualizarse también al
  elegir un valor nuevo por búsqueda (antes solo se actualizaba el id) — ver Decisión D1. No se
  introduce ninguna estructura de datos nueva: se reutiliza el campo que ya existía.

### Selector de insumos (`resolvedExtraItems`, `InventoryService`)

- **Antes de esta corrección**: `resolvedExtraItems` (signal, ya existente desde spec 102) se
  poblaba una sola vez al abrir el formulario, con los insumos de la receta/consumo ya guardados
  que no estaban en `allItems()`.
- **Después de esta corrección**: además de esa resolución inicial (que ahora cubre el 100% de los
  insumos de la receta, no solo los que quedaban fuera de la página 100), `resolvedExtraItems`
  también gana una entrada cada vez que el Administrador elige un insumo nuevo por búsqueda
  durante la sesión de edición (Decisión D1) — mismo signal, mismo mecanismo, un punto de entrada
  adicional.

## Transiciones de estado relevantes

```text
Formulario cerrado
   │
   ▼
Abrir formulario (crear) ──────────────▶ Selectores vacíos, sin precarga (FR-004)
   │
Abrir formulario (editar) ─────────────▶ category_name/presentationName/insumos ya resueltos
   │                                     desde GET /products/{id} (FR-003), sin precarga (FR-002)
   ▼
Usuario escribe en un selector ────────▶ Se ejecuta la búsqueda remota correspondiente (FR-005)
   │
Usuario elige un resultado ────────────▶ Se fija el id (igual que hoy) y, además, el nombre
                                          correspondiente (category_name/presentationName/
                                          resolvedExtraItems) desde el propio resultado de
                                          búsqueda, sin petición adicional (Decisión D1)
```

No hay estrategia de migración ni de rollback de datos que documentar (Principio VIII de la
Constitución): no se modifica ningún esquema de base de datos, tabla ni campo persistido.
