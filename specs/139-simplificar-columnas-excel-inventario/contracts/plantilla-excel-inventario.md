# Contrato: Plantilla Excel de Inventario (export/import)

**Spec**: [spec.md](../spec.md) | **Reemplaza parcialmente**: el contrato de columnas de la spec
109 (`109-inventario-excel-masivo`). Todo lo no mencionado aquí (upsert por código, validación de
tipo/stock/costo, manejo de errores por fila, job asíncrono de importación) sigue vigente tal
como lo define la spec 109.

Endpoints involucrados (sin cambio de ruta ni de método — ver
`app/api/v1/inventory/router.py`):
- `GET /inventory/items/export` → genera el archivo (este contrato).
- `POST /inventory/items/import` → sube un archivo para importar (este contrato, lado lectura).
- `GET /inventory/items/import/{job_id}/errors` → reporte de errores (sin cambios).

## Encabezados de exportación (orden exacto)

```text
Código | Nombre | Tipo | Unidad | Stock | Mínimo | Costo | Proveedor preferido
```

8 columnas. Ninguna fila incluye presentación, factor de conversión ni último costo del
proveedor preferido, independientemente de si el insumo tiene o no un proveedor preferido
asignado (FR-002); la columna con el **nombre** del proveedor preferido sí se exporta (en blanco
si el insumo no tiene uno asignado).

## Encabezados aceptados en importación

El sistema MUST aceptar como estructuralmente válidos ambos formatos de encabezado:

1. **Formato nuevo** (8 columnas): igual a la tabla de exportación arriba.
2. **Formato legado** (11 columnas, archivos exportados antes de esta spec):

```text
Código | Nombre | Tipo | Unidad | Stock | Mínimo | Costo | Proveedor preferido | Presentación | Factor de conversión | Último costo
```

En el formato legado, las 3 columnas finales (Presentación, Factor de conversión, Último costo)
se leen del archivo pero su contenido se descarta sin procesar: no se usan para crear, modificar
ni eliminar ninguna relación proveedor-insumo (FR-003, FR-004). La columna Proveedor preferido,
en cambio, sí se procesa en ambos formatos (ver sección siguiente). Cualquier otro conjunto de
encabezados (columnas faltantes, de más fuera de las 3 legadas, o fuera de orden) sigue siendo
rechazado por error de estructura, igual que hoy.

## Columna Unidad — comportamiento por tipo de fila

La columna Unidad contiene la **abreviatura** de la unidad de medida (mismo valor que hoy;
FR-005 no cambia qué se exporta en esta columna).

### Fila que crea un insumo nuevo (código no coincide con ningún insumo existente)

| Entrada | Resultado |
|---|---|
| Texto coincide (sin distinguir mayúsculas/minúsculas) con exactamente una `UnitMeasure.abbreviation` activa | Insumo creado usando esa unidad existente |
| Texto no coincide con ninguna `UnitMeasure.abbreviation` activa | Se crea una `UnitMeasureGroup` nueva + una `UnitMeasure` nueva en ese grupo (`is_base=True`, `factor_to_base=1`), y el insumo se crea usando esa unidad nueva |
| Texto coincide con **más de una** `UnitMeasure.abbreviation` activa (ambigüedad) | Fila reportada como fallida (FR-008) |
| Columna vacía | Fila reportada como fallida por campo obligatorio faltante (FR-009) |

### Fila que actualiza un insumo existente (código coincide con un insumo ya registrado)

| Entrada | Resultado |
|---|---|
| Cualquier valor (vacío, igual al actual, distinto al actual, texto inexistente) | Se ignora completamente para este campo; la unidad del insumo existente permanece sin cambios. No se crea ninguna `UnitMeasure` ni `UnitMeasureGroup` nueva por esta fila (FR-007). El resto de columnas de la fila se procesa con normalidad. |

## Columna Proveedor preferido — comportamiento en importación

Presente en ambos formatos de encabezado (nuevo y legado). Contiene el **nombre** del proveedor;
nunca su presentación, factor de conversión ni último costo (esos tres datos están fuera de
alcance en ambos formatos, ver sección siguiente).

| Entrada | Resultado |
|---|---|
| Columna vacía | No se toca nada: la relación preferida actual del insumo (si existe) permanece sin cambios. |
| Coincide (sin distinguir mayúsculas/minúsculas) con el nombre de un proveedor existente que tiene **exactamente una** relación proveedor-insumo **activa** con este insumo | Esa relación queda marcada como la preferida del insumo (FR-010). No se crea ni modifica su `presentation`/`conversion_factor`/`last_cost`. |
| No coincide con ningún proveedor existente | Se crea el `Supplier` (mismo ajuste que ya aplica a proveedores desde antes de esta spec: nombre normalizado en mayúscula, `is_system=False`), y se crea una relación proveedor-insumo nueva marcada como preferida con `presentation=NULL` y `conversion_factor=NULL` -- la plantilla ya no trae esos dos datos (FR-012). Estado intermedio aceptado explícitamente por el solicitante hasta que una spec futura decida cómo completarlos. |
| Coincide con un proveedor existente que NO tiene ninguna relación activa con este insumo | Igual que la fila anterior: se crea la relación nueva (sin crear el proveedor, que ya existía) con `presentation=NULL`/`conversion_factor=NULL`, marcada preferida (FR-012). |
| Coincide, sin distinguir mayúsculas/minúsculas, con **más de un** proveedor existente, o el proveedor resuelto tiene **más de una** relación activa con este insumo (ambigüedad) | Fila reportada como fallida (FR-011); no se crea ni modifica nada, y el resto de campos de la fila tampoco se aplica. |

Un proveedor existente pero inactivo que coincida se reactiva en vez de duplicarse (mismo
criterio que ya aplicaba a proveedores antes de esta spec). Este comportamiento aplica igual al
crear un insumo nuevo: la columna Proveedor preferido se resuelve después de que el insumo ya
quedó creado, así que puede crear tanto el proveedor como su primera relación con ese insumo
nuevo.

## Datos de presentación/factor/último costo — invariante

La exportación y la importación de inventario nunca modifican ni eliminan `presentation`,
`conversion_factor` ni `last_cost` de una relación proveedor-insumo **ya existente** (FR-004);
esos tres datos solo se editan desde los endpoints del módulo de proveedores (specs 106/107). La
única excepción a "nunca crean" es la relación nueva que FR-012 crea con esos dos campos en
`NULL` cuando no existía ninguna -- ver tabla arriba. La marca `preferred` sí puede cambiar por
importación en ambos casos (relación existente o nueva).
