# Data Model: Exportación e Importación Masiva de Inventario en Excel

## `inventory_items` — columna nueva

| Campo | Tipo | Regla |
|---|---|---|
| `code` | `String(20)` | `NOT NULL`, única por tenant (índice único, mismo patrón que `name`). Generada automáticamente (secuencial con cero a la izquierda, ver research.md D3) cuando no se especifica; editable por el administrador. |

**Backfill (Principio VIII)**: todo insumo existente recibe un `code` en la misma migración que
agrega la columna — no queda ningún insumo con `code` nulo después de aplicarla. Orden de
asignación: alfabético por `name` (mismo orden que ya usa `list_all_items_for_export`), para que
el backfill sea determinístico y repetible en cualquier ambiente.

**Estrategia de migración**: 1) agregar la columna como `NULL`; 2) backfillear con un secuencial
por tenant (`ROW_NUMBER() OVER (ORDER BY name)`, formateado a 4 dígitos); 3) alterar a `NOT NULL`;
4) agregar el índice único. Las 4 operaciones corren en la misma migración, dentro del mismo
`@for_each_tenant_schema` (no hay una ventana intermedia donde la columna exista sin backfillear
en un esquema y sí en otro, porque cada esquema se procesa de punta a punda antes de pasar al
siguiente).

**Estrategia de rollback**: quitar el índice único y la columna — no hay pérdida de datos de
negocio al revertir, porque `code` no reemplaza ni deriva de ningún campo existente (`name` sigue
siendo el campo con el que el resto del sistema ya identifica un insumo hoy).

## `inventory_import_jobs` — tabla nueva

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID (PK) | |
| `status` | `String(20)` | `procesando` \| `finalizado` \| `interrumpido` (research.md D5) |
| `file_name` | `String(255)` | nombre original del archivo subido, para mostrarlo en el resumen |
| `started_by_user_id` | UUID | referencia blanda a `shared.users.id`, igual patrón que `CashShift.user_id` |
| `started_at` | `DateTime` | |
| `finished_at` | `DateTime`, nullable | se llena al terminar (finalizado o interrumpido) |
| `total_rows` | `int` | filas de datos del archivo (sin contar encabezado) |
| `created_count` | `int`, default 0 | |
| `updated_count` | `int`, default 0 | |
| `failed_count` | `int`, default 0 | |
| `errors` | `JSONB`, default `[]` | lista de `{fila, codigo, motivo}` — a la escala acordada (≈500 filas) no justifica una tabla hija aparte |

**Reglas**:
- A lo sumo una fila con `status = 'procesando'` por tenant que no haya superado el tiempo límite
  de vencimiento (research.md D5) — se valida en el endpoint antes de encolar, no con una
  restricción de base de datos (el vencimiento es una regla de tiempo, no de unicidad pura).
- `errors` solo tiene contenido cuando `failed_count > 0` (FR-012); con `failed_count = 0` queda
  como lista vacía, y el frontend no ofrece la descarga (Historia 4, escenario 3).
- Esta tabla no tiene relación de borrado en cascada con `inventory_items`: un job ya finalizado
  es un registro histórico de lo que pasó en ese momento, no una vista en vivo del inventario.

**Sin historial permanente**: el spec (Assumptions) no exige conservar jobs antiguos
indefinidamente; esta tabla puede acumular filas sin una política de purga explícita en esta fase
(no es un requisito de la spec, y no bloquea ninguna historia).

## Plantilla de columnas (compartida por export e import)

Definida en un solo lugar (research.md D6), en este orden:

| # | Columna | Origen/destino | Tipo esperado |
|---|---|---|---|
| 1 | Código | `inventory_items.code` | texto, vacío = "asignar uno nuevo" al crear |
| 2 | Nombre | `inventory_items.name` | texto, obligatorio |
| 3 | Tipo | `inventory_items.type` (`Materia prima` \| `Empacado`, mismas etiquetas que pantalla) | texto, uno de los dos valores |
| 4 | Unidad | `unit_measures.abbreviation`, resuelta por abreviatura ya existente del tenant, o creada si no existe (research.md D7) | texto, obligatorio; se compara y se guarda en MAYÚSCULA |
| 5 | Stock | `inventory_items.current_stock` | numérico, ≥ 0 |
| 6 | Mínimo | `inventory_items.min_stock` | numérico, ≥ 0 |
| 7 | Costo | `inventory_items.unit_cost` | numérico, ≥ 0 |
| 8 | Proveedor preferido | `suppliers.name` (vía la relación preferida, spec 106), resuelto por nombre existente o creado si no existe (research.md D7) | texto, opcional; se compara y se guarda en MAYÚSCULA |
| 9 | Presentación | `supplier_items.presentation` (de la relación preferida) | texto, obligatorio si la columna 8 trae un proveedor |
| 10 | Factor de conversión | `supplier_items.conversion_factor` | numérico > 0, obligatorio si la columna 8 trae un proveedor |
| 11 | Último costo | `supplier_items.last_cost` | numérico ≥ 0, opcional aunque haya proveedor |

**Nota**: "Estado" (calculado: `Bajo mínimo` / `OK`) queda fuera de esta plantilla — es derivado,
no editable (spec.md, Assumptions). Un administrador que lo necesite sigue viéndolo en la pantalla
de Inventario, fuera de este archivo.

## Reglas de validación del import (por fila, FR-006)

- **Código** (columna 1): si coincide con un insumo existente del tenant → actualiza (FR-007); si
  no coincide con ninguno → crea un insumo nuevo con ese código; si viene vacío → crea un insumo
  nuevo con un código asignado automáticamente (igual que un alta sin código desde la ficha).
  Duplicado dentro del mismo archivo → fila fallida (Edge case del spec).
- **Nombre, Tipo, Unidad** (columnas 2-4): obligatorios. **Unidad** se resuelve sin distinguir
  mayúsculas/minúsculas contra las abreviaturas ya existentes del tenant; si ninguna coincide, se
  **consolida creando una unidad nueva** con ese texto en MAYÚSCULA (research.md D7) — ya no es
  motivo de fila fallida. Sigue siendo fallida si hay más de una unidad existente que coincida
  ignorando mayúsculas (dato ambiguo que el administrador debe resolver a mano).
- **Stock, Mínimo, Costo** (columnas 5-7): deben ser numéricos y ≥ 0; texto no numérico → fila
  fallida con el campo señalado.
- **Proveedor preferido / Presentación / Factor / Último costo** (columnas 8-11): si la columna 8
  viene vacía, las columnas 9-11 se ignoran (el insumo no tiene o conserva el proveedor preferido
  que ya tenía — Edge case del spec). Si trae un nombre, se resuelve sin distinguir mayúsculas
  contra los proveedores ya existentes; si ninguno coincide, se **consolida creando un proveedor
  nuevo** con ese texto en MAYÚSCULA (research.md D7); si coincide con uno existente pero
  inactivo, se reactiva en vez de crear un duplicado. Sigue siendo fallida si faltan Presentación
  o Factor cuando sí hay proveedor, si el Factor no es > 0, si hay más de un proveedor existente
  que coincida ignorando mayúsculas, o si el proveedor resuelto es el proveedor de sistema
  ("Compra ocasional", RN-17 de spec 106 — nunca se le puede vincular una presentación). Cuando la
  fila es válida, se resuelve/crea la relación proveedor-insumo igual que ya hace
  `supplier_items.create_or_reactivate` (spec 106) y se marca como preferida si no lo era.

Cada fila se valida y se aplica de forma independiente (commit propio) — ninguna fila espera a
que termine el archivo completo (FR-006, FR-015).
