# Research: Búsqueda por Nombre o Código y Filtro por Proveedor en Inventario

## D1 — Cómo extender la búsqueda para incluir `code`

**Decisión**: Ampliar la condición de búsqueda en `list_items_query()`
(`pos-backend/app/api/v1/inventory/service.py:63-82`) de:

```python
if search:
    stmt = stmt.where(InventoryItem.name.ilike(f"%{search}%"))
```

a un `OR` entre `name` y `code`:

```python
from sqlalchemy import or_

if search:
    stmt = stmt.where(
        or_(
            InventoryItem.name.ilike(f"%{search}%"),
            InventoryItem.code.ilike(f"%{search}%"),
        )
    )
```

**Rationale**: Es el cambio mínimo que satisface FR-001/FR-002/FR-003 sin alterar el
comportamiento actual de búsqueda por nombre (FR-010): toda fila que hoy coincide por `name`
sigue coincidiendo, porque la condición original queda intacta dentro del `OR`. No requiere
tocar el router ni el contrato de la query param `search` (sigue siendo un solo string).

**Alternatives considered**:
- Dos query params separados (`search_name`, `search_code`): rechazado — contradice
  explícitamente el pedido del usuario ("buscar los registros ya sea por nombre o codigo" con
  un solo campo) y la spec (FR-003: "no exige que ambos coincidan", un solo texto).
- Full-text search (`tsvector`/`to_tsquery`): rechazado — resuelve coincidencia por palabras,
  no por subcadena/frase exacta, y la spec ya aclaró en Clarifications que la coincidencia
  debe ser de frase exacta/subcadena, igual al comportamiento actual. Sería además una
  dependencia/migración nueva no justificada a esta escala (500–5,000 insumos).

## D2 — Cómo filtrar insumos por proveedor

**Decisión**: Agregar un query param opcional `supplier_id: UUID | None` al endpoint
`GET /inventory/items` y, en `list_items_query()`, cuando venga presente, filtrar con una
subconsulta `EXISTS`/`IN` contra `SupplierItem`:

```python
from sqlalchemy import exists

if supplier_id is not None:
    stmt = stmt.where(
        exists().where(
            SupplierItem.inventory_item_id == InventoryItem.id,
            SupplierItem.supplier_id == supplier_id,
            SupplierItem.active.is_(True),
        )
    )
```

**Rationale**: Reutiliza exactamente la misma condición (`supplier_id` + `active = true`) que
ya usa `list_for_supplier()` (`app/api/v1/inventory/supplier_items.py:262-273`) para el caso
inverso (insumos de un proveedor visto desde el detalle del proveedor), cumpliendo FR-004/FR-005
sin introducir un segundo criterio de "relación activa" divergente. Un `EXISTS` evita duplicar
filas de `InventoryItem` si en el futuro un insumo tuviera más de una relación activa con el
mismo proveedor (no debería ocurrir por el índice único de combo, pero `EXISTS` es correcto por
construcción sin depender de esa garantía).

**Alternatives considered**:
- `JOIN` directo con `SupplierItem` + `DISTINCT`: rechazado — funcionalmente equivalente pero
  requiere `DISTINCT` para evitar duplicados y no sigue el estilo actual de `list_items_query`
  (solo `.where()` sobre `InventoryItem`, sin joins). `EXISTS` es más simple y no cambia el
  patrón de la función.
- Selección múltiple de proveedores (`supplier_ids: list[UUID]`): fuera de alcance — la spec
  (Assumptions) fija el filtro de proveedor como selección única, igual a los filtros de tipo y
  estado ya existentes.

## D3 — Índices para optimizar la búsqueda combinada (SC-003)

**Decisión**:
1. **Búsqueda por texto (`name`/`code`)**: no se agrega índice nuevo. Ambas columnas ya tienen
   un índice único btree (`ix__inventory_items__name`, `ux__inventory_items__code`), pero un
   patrón `ILIKE '%texto%'` no puede usar un btree estándar (solo sirve para `LIKE 'prefijo%'`).
   Esta limitación ya existe hoy para la búsqueda por nombre y no es una regresión introducida
   por esta spec. A la escala confirmada en Clarifications (500–5,000 insumos por tenant), un
   `seq scan` filtrado por dos `ILIKE` sobre una tabla de ese tamaño responde en milisegundos
   en PostgreSQL — muy por debajo del umbral de 1 segundo de SC-003 — por lo que no se justifica
   agregar `pg_trgm`/GIN (una dependencia de extensión de PostgreSQL nueva, Principio IX) para
   un problema que a esta escala no existe.
2. **Filtro por proveedor**: se agrega un índice compuesto nuevo
   `ix__supplier_items__supplier_id_active` sobre `tenant.supplier_items(supplier_id, active)`.
   Hoy solo existe `ix__supplier_items__supplier_id` (una sola columna); el índice compuesto
   permite que PostgreSQL resuelva `WHERE supplier_id = X AND active = true` leyendo
   directamente las filas que cumplen ambas condiciones, en vez de filtrar `active` después de
   leer todas las filas de ese `supplier_id`. Dado que un proveedor puede llegar a tener decenas
   de insumos vinculados (activos e inactivos acumulados en el tiempo), esto evita que el
   `EXISTS` de D2 dependa de un filtro en memoria.

**Rationale**: El pedido explícito del usuario fue "ten en cuenta los indices para optimizar
las busquedas" — D3 documenta esa decisión explícitamente en vez de dejarla implícita, tal como
exige la nota final de Assumptions en spec.md ("El diseño técnico de los índices... se define
en la fase de planificación técnica").

**Alternatives considered**:
- Índice `pg_trgm`/GIN sobre `name`/`code` para soportar `ILIKE '%texto%'` eficientemente:
  rechazado para esta spec por sobre-ingeniería a la escala confirmada (500–5,000 insumos); se
  deja documentado aquí como opción futura si el catálogo de algún tenant creciera muy por
  encima de esa escala.
- No agregar ningún índice nuevo (reutilizar solo `ix__supplier_items__supplier_id`):
  rechazado — es la opción más simple pero no "tiene en cuenta los índices" como pidió
  explícitamente el usuario, y el costo de un índice compuesto adicional en una tabla de este
  tamaño es despreciable frente al beneficio.

## D4 — Frontend: estado del nuevo filtro de proveedor

**Decisión**: Agregar en `inventory.service.ts` una señal `itemsSupplierId` (mismo patrón que
`itemsType`/`itemsActive`), un setter `setItemsSupplierId(value)` que hace
`this.itemsSupplierId.set(value); this.loadItems(1);`, e incluir `itemsSupplierId` en el
`queryKey` de `injectPagedQuery` junto a los demás filtros. En `fetchItemsPage`, agregar
`supplier_id` a los `HttpParams` solo cuando el valor no sea `null`/vacío. En
`inventory-page.component.ts`, agregar un `<select>` de proveedor junto a los de tipo/estado,
poblado con `suppliersService.suppliers` (ya cargado en `ngOnInit`), con una opción "Todos los
proveedores" para limpiar el filtro (FR-009), y un `onSupplierFilterChange` que llama al nuevo
setter.

**Rationale**: Replica exactamente el patrón ya validado para tipo/estado (reset de paginación
a página 1 vía FR-007, recarga reactiva vía TanStack Query), minimizando el riesgo de
inconsistencia entre filtros y evitando introducir un patrón nuevo de estado para un control que
es funcionalmente idéntico a los que ya existen en esa misma barra.

**Alternatives considered**: Ninguna — no hay ambigüedad de diseño aquí, el patrón existente ya
resuelve el problema sin modificaciones.

## D5 — Combinación de criterios (intersección)

**Decisión**: Todos los filtros (`search` sobre `name`/`code`, `type`, `active`,
`supplier_id`) se combinan con `AND` entre sí (cada `.where()` adicional sobre el mismo
`Select` ya es una conjunción), excepto la condición interna `name OR code` dentro del criterio
de búsqueda (D1), que es una disyunción solo entre esas dos columnas para el mismo texto.

**Rationale**: Es exactamente lo que exige FR-006/FR-003 y las Historias 3 de la spec:
intersección entre criterios distintos, unión solo entre nombre y código para el mismo texto de
búsqueda. SQLAlchemy ya construye esto naturalmente encadenando `.where()`; no se requiere
lógica adicional.

**Alternatives considered**: N/A — es el comportamiento por defecto de encadenar `.where()` en
SQLAlchemy, no una decisión de diseño con alternativas reales.
