# Contrato: Plantilla Excel de Inventario (export/import) — actualización

**Spec**: [spec.md](../spec.md) | **Reemplaza parcialmente**: el contrato de columnas de la spec
139 (`139-simplificar-columnas-excel-inventario/contracts/plantilla-excel-inventario.md`). Todo
lo no mencionado aquí (upsert por código, validación de tipo/stock/costo, manejo de errores por
fila, job asíncrono de importación, formatos legados de 8 y 11 columnas) sigue vigente tal como lo
dejó esa spec.

Endpoints involucrados (sin cambio de ruta ni de método):
- `GET /inventory/items/export` → genera el archivo (este contrato de columnas + **nuevo**:
  acepta `supplier_id`/`type_` opcionales, ver sección "Filtros de exportación").
- `POST /inventory/items/import` → sube un archivo para importar (este contrato, lado lectura).
- `GET /inventory/items/import/{job_id}/errors` → reporte de errores (sin cambios).

## Encabezados de exportación (orden exacto, formato vigente tras esta spec)

```text
Código | Nombre | Tipo | Unidad | Grupo | Stock | Mínimo | Costo | Proveedor preferido |
Unidad de compra | Factor de conversión (compra)
```

10 columnas. Todo insumo se exporta con su `Grupo` (el `name` del `UnitMeasureGroup` de su unidad
base); `Unidad de compra`/`Factor de conversión (compra)` se exportan solo si el insumo tiene un
proveedor preferido cuya relación está en modo `unit_measure_id` (spec 140) — en blanco si no
tiene proveedor preferido, o si la relación preferida está en modo legado
(`presentation`/`conversion_factor`, p. ej. una relación editada manualmente desde el módulo de
proveedores con texto libre en vez de una unidad real).

## Encabezados aceptados en importación

El sistema MUST aceptar como estructuralmente válidos los siguientes formatos de encabezado:

1. **Formato vigente** (10 columnas): igual a la tabla de exportación arriba.
2. **Formato spec 139** (8 columnas):

```text
Código | Nombre | Tipo | Unidad | Stock | Mínimo | Costo | Proveedor preferido
```

3. **Formato legado spec 109** (11 columnas):

```text
Código | Nombre | Tipo | Unidad | Stock | Mínimo | Costo | Proveedor preferido | Presentación |
Factor de conversión | Último costo
```

En los formatos 2 y 3, las columnas `Grupo`, `Unidad de compra` y `Factor de conversión (compra)`
simplemente no existen en el archivo: toda fila que crea un insumo nuevo se comporta como si esas
tres columnas vinieran vacías (ver tablas siguientes). En el formato 3, además, las 3 columnas
finales (`Presentación`, `Factor de conversión`, `Último costo`) se leen pero su contenido se
descarta sin procesar (sin cambio respecto a la spec 139). Cualquier otro conjunto de encabezados
(columnas faltantes, de más, o fuera de orden, fuera de estas tres formas) sigue siendo rechazado
por error de estructura.

## Columna Unidad + columna nueva Grupo — comportamiento al crear un insumo nuevo

| Entrada (Unidad / Grupo) | Resultado |
|---|---|
| Unidad no coincide con ninguna existente / Grupo vacío | Se crea un `UnitMeasureGroup` nuevo (nombre = texto de la unidad) + una `UnitMeasure` nueva ahí (`is_base=True`, `factor_to_base=1`) — comportamiento sin cambio de la spec 139 (FR-011). |
| Unidad no coincide con ninguna existente / Grupo con texto, no existe todavía | Se crea el `UnitMeasureGroup` con el nombre indicado + la `UnitMeasure` nueva dentro de ese grupo, `is_base=True`, `factor_to_base=1` (FR-010, Acceptance Scenario 1). |
| Unidad no coincide con ninguna existente / Grupo con texto, ya existe | La `UnitMeasure` nueva se crea dentro del grupo ya existente, `is_base=True` *solo si ese grupo todavía no tiene una unidad base* — si ya la tiene, ver siguiente fila (ambigüedad de base duplicada, tratado igual que FR-012 porque dos unidades `is_base=True` en el mismo grupo violaría la restricción de la spec 137). |
| Unidad coincide (case-insensitive) con exactamente una `UnitMeasure` activa, y esa unidad está en el grupo indicado (o Grupo viene vacío) | Insumo creado usando esa unidad existente — sin cambio (FR-010 Acceptance Scenario 2). |
| Unidad coincide con exactamente una `UnitMeasure` activa, pero en un grupo **distinto** al indicado por Grupo | Fila fallida por ambigüedad de grupo, sin crear ni modificar nada (FR-012, Acceptance Scenario 4). |
| Unidad coincide con **más de una** `UnitMeasure` activa (ambigüedad entre grupos) | Fila fallida — sin cambio de la spec 139/140. |
| Columna Unidad vacía | Fila fallida por campo obligatorio faltante — sin cambio (FR-009 de la spec 139). |

### Fila que actualiza un insumo existente

Sin cambio respecto a la spec 139 (FR-013): el valor de `Unidad` y de la nueva columna `Grupo` se
ignora por completo; no se crea ni modifica ninguna `UnitMeasure`/`UnitMeasureGroup`; el resto de
columnas de la fila se procesa con normalidad.

## Columna Proveedor preferido + columnas nuevas Unidad de compra / Factor de conversión (compra)

Comportamiento base de `Proveedor preferido` (resolver/crear el proveedor, marcar la relación
preferida) sin cambio respecto a la spec 139. Lo nuevo aplica solo cuando esa misma fila **crea**
un insumo nuevo (FR-021: al actualizar, estas tres columnas se ignoran igual que ya se ignoraba
`Unidad`):

| Entrada (Proveedor preferido / Unidad de compra / Factor) | Resultado |
|---|---|
| Proveedor preferido vacío, Unidad de compra y/o Factor con valor | Fila fallida por dato de unidad de compra sin proveedor al que asociarlo; no se crea el insumo ni ninguna unidad o relación (FR-020a, Acceptance Scenario 11 de la Historia 3). |
| Proveedor preferido con valor, Unidad de compra y Factor ambos vacíos | Comportamiento sin cambio de la spec 139: se crea/empareja la relación preferida con `unit_measure_id=NULL` (campo opcional, FR-020, Acceptance Scenario 10). |
| Proveedor preferido con valor, Unidad de compra coincide (case-insensitive) con una `UnitMeasure` ya existente **en el mismo grupo** que la unidad base del insumo, Factor vacío o igual al `factor_to_base` ya vigente de esa unidad | La relación preferida (nueva o emparejada) queda con `unit_measure_id` = esa unidad; no se crea ni modifica ninguna `UnitMeasure` (FR-015/FR-019, Acceptance Scenario 5). |
| Proveedor preferido con valor, Unidad de compra coincide en el mismo grupo, Factor con valor **distinto** al ya vigente | Fila fallida por conflicto de factor; no se modifica el factor ya vigente de esa unidad (FR-016, Acceptance Scenario 6). |
| Proveedor preferido con valor, Unidad de compra coincide por nombre/abreviatura pero en un grupo **distinto** al de la unidad base | Fila fallida por ambigüedad de grupo (FR-017). |
| Proveedor preferido con valor, Unidad de compra no coincide con ninguna unidad del grupo de la base, Factor con valor | Se crea una `UnitMeasure` nueva dentro de ese mismo grupo (`is_base=False`, `factor_to_base`=el de la fila), y la relación preferida queda con `unit_measure_id` = esa unidad nueva (FR-015, Acceptance Scenario 7). |
| Proveedor preferido con valor, Unidad de compra no coincide con ninguna unidad del grupo, Factor vacío | Fila fallida por dato obligatorio faltante (FR-018, Acceptance Scenario 8). |

## Filtros de exportación (`GET /inventory/items/export`)

Query params nuevos, ambos opcionales e independientes entre sí:

| Param | Tipo | Efecto |
|---|---|---|
| `supplier_id` | UUID | Solo insumos con al menos una relación `SupplierItem.active=true` con ese proveedor (mismo criterio que `GET /inventory/items?supplier_id=`, spec 133). |
| `type_` | `raw_material` \| `packaged` | Solo insumos de ese tipo (mismo criterio que `GET /inventory/items?type_=`). |

Sin ninguno de los dos: se exportan todos los insumos del tenant (activos e inactivos), igual que
el comportamiento anterior a esta spec (FR-005). Con ambos: intersección, no unión (FR-004). Si la
combinación no coincide con ningún insumo, el archivo se genera igual, con los encabezados pero
sin filas de datos (FR-008) — no es un error.

## Datos de presentación/factor/último costo (modo legado) — invariante sin cambio

Igual que la spec 139: la exportación y la importación nunca modifican `presentation`,
`conversion_factor` ni `last_cost` de una relación proveedor-insumo **ya existente**; esos datos,
en modo legado, solo se editan desde los endpoints del módulo de proveedores. Esta spec agrega una
vía adicional de creación (modo `unit_measure_id`, ver tabla de arriba) que tampoco modifica nunca
una relación ya existente — solo aplica al crear la relación por primera vez, junto con el insumo
nuevo (FR-021).
