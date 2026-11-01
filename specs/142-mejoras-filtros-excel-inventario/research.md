# Research: Filtro buscable de proveedor, exportación filtrada y vinculación de unidades de compra por Excel

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

El spec no deja ninguna sección marcada `NEEDS CLARIFICATION` (las dos dudas de negocio ya se
resolvieron en "Clarifications"). Esta investigación documenta las decisiones técnicas de
implementación, apoyadas en el código real de `pos-backend`/`pos-heladeria` y en los planes/
data-models de las specs 106, 133, 137, 139 y 140.

## D1 — Filtro de proveedor buscable: reutilizar `app-searchable-select` en modo local

**Decisión**: reemplazar el `<select>` nativo de proveedor en `inventory-page.component.ts`
(líneas 208-218) por `<app-searchable-select>`
(`pos-heladeria/src/app/shared/searchable-select/searchable-select.component.ts`), en **modo
local** (pasando `[options]` ya resueltas, sin el input `search`), siguiendo exactamente el mismo
patrón que `movementItemOptions()` (línea 889) usa para el selector de insumo de "Movimientos".

**Justificación**: el componente ya existe, ya implementa `ControlValueAccessor` (reemplazo
directo de un `<select>` vía `[ngModel]`), ya normaliza texto sin distinguir mayúsculas/minúsculas
(`normalizeText()`) y ya tiene un modo local diseñado para listas ya cargadas en memoria — que es
exactamente el caso de `suppliersService.suppliers()` (se carga completa una sola vez vía
`loadSuppliers()`, sin paginar, misma escala que la lista de proveedores del propio filtro de
Historia 2). No hay necesidad de su modo remoto (`search`, spec 098): el catálogo de proveedores
de una PyME no justifica paginar la búsqueda del propio selector, igual que no se paginó para el
selector de insumos de "Movimientos".

**Alternativas consideradas**:
- Agregar búsqueda ad hoc al `<select>` nativo (un `<input>` adicional que filtra opciones a
  mano): rechazada — duplicaría lógica que `app-searchable-select` ya centraliza (normalización,
  "sin coincidencias", opción "Todos"), violando el Principio V (no reinventar un patrón ya
  resuelto en el propio repo).
- Modo remoto de `app-searchable-select`: rechazada por ahora — no hay un endpoint de búsqueda de
  proveedores paginado hoy, y crearlo sería alcance fuera de lo pedido por Historia 1 (FR-001 solo
  exige filtrar un catálogo ya cargado).

## D2 — Mantener "Todos los proveedores" como opción explícita del selector

**Decisión**: la opción "Todos los proveedores" (valor `null`/vacío para `supplier_id`) se modela
como una entrada más de `options` (p. ej. `{id: null, label: 'Todos los proveedores'}`), no como
un elemento fuera del componente — así queda sujeta al mismo filtrado por texto que el resto
(FR-002: debe seguir visible con texto de búsqueda vacío) sin lógica especial.

**Alternativas consideradas**: renderizar "Todos los proveedores" como un botón/enlace separado
fuera de `app-searchable-select`: rechazada — complica el `ControlValueAccessor` existente
(`[ngModel]`) sin necesidad, cuando incluirla como opción normal ya cumple FR-002 sin código
adicional.

## D3 — Exportación filtrada: reutilizar `list_items_query()` en vez de una consulta nueva

**Decisión**: `GET /inventory/items/export` deja de usar `service.list_all_items_for_export(db)`
y en su lugar ejecuta `service.list_items_query(type_=type_, supplier_id=supplier_id)` (la misma
función que ya usa `GET /inventory/items`, spec 133) sin aplicar paginación, dejando `active=None`
y `search=None`/`low_stock=None` siempre fijos para exportar activos e inactivos sin buscador ni
filtro de stock bajo, igual que hace hoy `list_all_items_for_export`.

**Justificación**: `list_items_query()` (`app/api/v1/inventory/service.py:68-101`) ya implementa
exactamente el criterio de coincidencia de proveedor (`EXISTS` sobre `SupplierItem.active=true`,
FR-006) y de tipo (`InventoryItem.type == type_`, FR-007) que Historia 2 pide reusar — son
literalmente los mismos parámetros `type_`/`supplier_id` que ya recibe el endpoint de listado.
Construir una consulta nueva en paralelo duplicaría ese criterio y correría el riesgo de que
ambos diverjan con el tiempo (viola el Principio V).

**Alternativas consideradas**:
- Filtrar en Python después de traer todos los insumos (`list_all_items_for_export()` +
  filtro en memoria): rechazada — ineficiente sin necesidad or, y duplica el criterio de
  coincidencia en vez de reutilizar el ya probado por los characterization tests de la spec 133.
- Mantener `list_all_items_for_export()` como función separada que delega internamente en
  `list_items_query()`: considerada viable pero innecesaria — el router puede llamar
  `list_items_query()` directamente; `list_all_items_for_export()` se retira si al revisar su uso
  (`grep`) no queda ninguna otra llamada activa fuera del propio endpoint de export.

## D4 — Contrato de query params del export: `supplier_id` + `type_`, ambos opcionales

**Decisión**: `GET /inventory/items/export` gana dos query params opcionales,
`supplier_id: UUID | None` y `type_: InventoryItemType | None` (mismos nombres y tipos que ya usa
`GET /inventory/items`, para consistencia de API). Sin ninguno de los dos, exporta todo (FR-005).
Con ambos, se aplican como intersección (`AND`, ya es el comportamiento de `list_items_query` al
encadenar `.where()`, FR-004).

**Alternativas consideradas**: un body JSON en un `POST /inventory/items/export` en vez de query
params en el `GET` existente: rechazada — cambiaría el método HTTP de un endpoint ya usado por el
frontend (`exportItems()` día de hoy hace `GET` y descarga el `Blob` de la respuesta), rompiendo
sin necesidad un contrato que ya funciona; los query params opcionales son no disruptivos (un
cliente que no los envía obtiene el comportamiento actual, FR-005).

## D5 — Columna "Grupo" en el Excel: nombre explícito, resuelto igual que `UnitMeasureGroup.name`

**Decisión**: nueva columna `Grupo`, opcional, después de `Unidad` en la plantilla. Al crear un
insumo nuevo:
- Vacía → comportamiento actual de la spec 139 (`_resolve_unit` crea un grupo propio nuevo con el
  texto de la unidad como nombre) — FR-011.
- Con texto → se normaliza igual que el resto de comparaciones de texto del sistema (mayúsculas,
  espacios recortados) y se busca un `UnitMeasureGroup` existente por `name` sin distinguir
  mayúsculas/minúsculas (mismo criterio que `ensure_unique_ci` ya usa para `UnitMeasure.name` en
  `unit_measure_groups/router.py`); si existe, se reutiliza; si no, se crea un `UnitMeasureGroup`
  nuevo con ese nombre exacto (normalizado) — FR-010.

**Justificación**: `UnitMeasureGroup` ya es la única fuente de verdad del agrupamiento desde la
spec 140 (que eliminó el espejo `UnitMeasure.dimension`); reutilizar su campo `name` (único en
todo el tenant, `ensure_unique`) es el mismo mecanismo que ya usa `create_unit_measure_group` del
módulo de Ajustes — no hace falta ninguna tabla ni columna nueva.

**Alternativas consideradas**: una columna que reciba el **id** del grupo en vez de su nombre:
rechazada — el usuario que llena el Excel no conoce ni puede buscar ids de grupo desde una hoja de
cálculo; el nombre es el mismo dato visible que ya usa en Ajustes.

## D6 — Ambigüedad de unidad base contra grupo distinto: falla explícita, sin fusionar grupos

**Decisión** (FR-012, Edge Case de la Historia 3): si el nombre de la unidad base de la fila ya
existe en el negocio (por `abbreviation`, igual que hoy valida `_resolve_unit`) pero en un grupo
distinto al indicado por la columna `Grupo`, la fila falla por ambigüedad — no se reasigna la
unidad existente a otro grupo ni se crea una unidad "duplicada" con el mismo nombre en el grupo
indicado.

**Justificación**: `UnitMeasure.name` es único en todo el tenant desde la spec 140 (no por
grupo) — crear una segunda unidad con el mismo nombre violaría esa restricción de base de datos
(`ux_unit_measures_name_ci`); y mover la unidad existente a otro grupo es una operación destructiva
sobre un insumo/compra que ya podría estar usándola, fuera del alcance de una importación
(afectaría FR-016 de la spec 137: "eliminar/mover unidad en uso" requiere validación explícita que
una fila de Excel no puede decidir por sí sola). Fallar la fila y dejar que el administrador
resuelva la ambigüedad manualmente es la opción segura, igual criterio que ya usa `_resolve_unit`
hoy para abreviaturas repetidas en distinto grupo (desde que la spec 140 dejó de exigir
`abbreviation` única).

## D7 — Unidad de compra del proveedor preferido: reutilizar el modo `unit_measure_id` de la spec 140

**Decisión**: las columnas nuevas `Unidad de compra` y `Factor de conversión (compra)` (ambas
opcionales, solo tienen efecto junto con `Proveedor preferido` al crear un insumo nuevo) resuelven
una `UnitMeasure` perteneciente al **mismo grupo** que la unidad base ya resuelta del insumo
(`item.unit_measure.group_id`), y esa unidad se asigna a `SupplierItem.unit_measure_id` —
exactamente el mismo modo que la spec 140 introdujo para el formulario de proveedores
(`_resolve_unit_for_item()` en `supplier_items.py`), nunca el modo legado
`presentation`/`conversion_factor` (texto libre).

Algoritmo de `_resolve_purchase_unit(db, group_id, nombre_unidad, factor)` (nuevo en
`import_.py`, análogo a `_resolve_unit` pero acotado a un grupo):
1. Buscar `UnitMeasure` activa con `group_id` = el de la unidad base e `abbreviation` o `name`
   coincidiendo sin distinguir mayúsculas/minúsculas con `nombre_unidad`.
2. Si hay coincidencia en ese grupo:
   - Si `factor` viene vacío → se reutiliza la unidad encontrada con su `factor_to_base` ya
     vigente (Acceptance Scenario 5 de la Historia 3).
   - Si `factor` viene y coincide con el `factor_to_base` ya vigente → se reutiliza igual
     (Acceptance Scenario 5).
   - Si `factor` viene y **no** coincide → fila fallida por conflicto de factor, sin modificar
     nada (FR-016, Acceptance Scenario 6).
3. Si hay coincidencia por nombre/abreviatura en un **grupo distinto** → fila fallida por
   ambigüedad de grupo (FR-017, mismo criterio que D6 para la unidad base).
4. Si no hay ninguna coincidencia:
   - Si `factor` viene → se crea una `UnitMeasure` nueva en ese grupo (`is_base=False`,
     `factor_to_base=factor`), mismo patrón que `add_unit_to_group()`
     (`unit_measure_groups/router.py:114`) — FR-018 inverso (Acceptance Scenario 7).
   - Si `factor` no viene → fila fallida por dato obligatorio faltante (FR-018, Acceptance
     Scenario 8).

La relación `SupplierItem` creada por `_apply_preferred_supplier()` pasa de
`presentation=None, conversion_factor=None` a `unit_measure_id=<resuelto>` cuando la fila trae
unidad de compra; si no la trae, sigue creándose con ambos campos en `None` (FR-020, sin cambio).

**Justificación**: el modelo y las reglas de "misma pertenencia de grupo" y "factor compartido por
toda unidad" ya existen y están probadas desde la spec 140 (`_resolve_unit_for_item` en
`supplier_items.py` aplica la misma restricción de grupo para el flujo manual desde Ajustes/
Proveedores); Historia 3 solo necesita una vía de entrada equivalente desde el import, sin inventar
reglas nuevas ni tocar el modelo. Esto también resuelve de forma natural la clarificación de la
sesión 2026-10-28 ("la unidad de compra pasa a ser una Unidad de Medida real del mismo grupo...
sustituyendo el uso del campo libre `presentation`") sin ningún cambio de esquema.

**Alternativas consideradas**:
- Seguir usando el modo legado (`presentation`/`conversion_factor` como texto libre) pero
  poblándolo desde el Excel: rechazada explícitamente por la clarificación del spec — reabre una
  decisión ya tomada por la spec 139 de no exponer esos dos campos libres desde Excel, y no
  resolvería el pedido original del usuario de "vincular esa unidad base con el grupo" de forma
  real.
- Crear la `UnitMeasure` de compra siempre en un grupo propio nuevo (como hace `_resolve_unit` con
  la unidad base cuando no hay grupo indicado): rechazada — contradice explícitamente la
  clarificación ("esa Unidad de Medida... del mismo grupo que la unidad base del insumo") y el
  principio de conversión de la spec 137/140 (dos unidades convertibles solo si están en el mismo
  grupo); una unidad de compra en su propio grupo no podría expresar ningún factor hacia la base.

## D8 — Orden y nombres de las columnas nuevas en la plantilla

**Decisión**: la plantilla pasa de 8 a 10 columnas:

```text
Código | Nombre | Tipo | Unidad | Grupo | Stock | Mínimo | Costo | Proveedor preferido |
Unidad de compra | Factor de conversión (compra)
```

`Grupo` se ubica inmediatamente después de `Unidad` (misma relación conceptual: define a qué
grupo pertenece la unidad de la columna anterior). `Unidad de compra`/`Factor de conversión
(compra)` se ubican al final, después de `Proveedor preferido` (mismo orden conceptual que tenía
el formato legado de la spec 109/139 antes de que se retiraran `Presentación`/`Factor de
conversión`/`Último costo`, evitando reintroducir el nombre `Factor de conversión` a secas para no
confundirlo con el factor de la unidad base).

**Compatibilidad**: `validar_estructura()` sigue aceptando el formato de 8 columnas (spec 139) y
el legado de 11 columnas (spec 109) como estructuralmente válidos además del nuevo de 10 — un
archivo exportado antes de esta spec sigue siendo importable sin cambios (Principio II). El nuevo
formato de 10 columnas se suma como una tercera forma válida, no reemplaza a las anteriores.

**Alternativas consideradas**: insertar `Grupo` antes de `Unidad`: rechazada por orden de lectura
menos natural (uno normalmente piensa primero en la unidad y luego en a qué grupo pertenece, no al
revés) y porque no hay ninguna razón funcional para anteponerla.

## Resumen de impacto por archivo (confirmado por exploración de código)

| Archivo | Cambio |
|---|---|
| `pos-heladeria/.../inventory-page.component.ts` | H1: `<select>` → `<app-searchable-select>` para proveedor. H2: UI de selección de filtros antes de exportar. |
| `pos-heladeria/.../inventory.service.ts` | H2: `exportItems()` acepta `supplierId`/`type_` opcionales como query params. |
| `pos-backend/.../inventory/router.py` | H2: `export_items()` acepta `supplier_id`/`type_` opcionales. |
| `pos-backend/.../inventory/service.py` | H2: reusa `list_items_query()` desde el export; retira `list_all_items_for_export()` si queda sin otro uso. |
| `pos-backend/.../inventory/schemas.py` | H3: `INVENTORY_TEMPLATE_HEADERS` gana `Grupo`, `Unidad de compra`, `Factor de conversión (compra)`. |
| `pos-backend/.../inventory/export.py` | H3: escribe las 2-3 columnas nuevas por fila. |
| `pos-backend/.../inventory/import_.py` | H3: `_resolve_unit` acepta grupo explícito; nueva `_resolve_purchase_unit`; `_apply_preferred_supplier` usa `unit_measure_id`. |
| `pos-backend/characterization_tests/test_inventory_export.py` | H2 y H3: actualizar suites de columnas/filtros/relación preferida. |
| `pos-backend/app/scripts/test_inventory_bulk_excel.py` | H3: nuevos escenarios contra Postgres real. |
