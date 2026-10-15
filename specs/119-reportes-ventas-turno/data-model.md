# Data Model — Fase 1: Reportes operativos por turno de caja

**Spec**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md) · **Research**: [research.md](./research.md) D1–D16

**Actualizado 2026-10-15 (ampliación US6)**: el desglose congelado pasa de columnas `JSONB` a
**filas** en dos tablas hijas (D9); el modelo de lectura se resuelve con consultas en lote (D10);
se añaden dos índices sobre `cash_shifts` (D13) y las revisiones de migración B y C (D14). El
contrato HTTP no cambia.

Convención del repositorio: identificadores de código (tablas, columnas) en inglés; comentarios y
mensajes de negocio en español de Colombia (Principio XIII) — igual que `CashShift`,
`CashMovement` y `CashCountDenomination` ya existentes.

## 1. Entidades existentes que se leen (sin cambios de esquema)

### 1.1 `tenant.cash_shifts` → **Turno de caja**

| Columna | Tipo | Se usa para | Notas verificadas |
|---|---|---|---|
| `id` | UUID | Identificar el turno; FK de `shift_sales_reports` | — |
| `cash_register_id` | UUID | Filtro opcional por caja (FR-010) | FK → `cash_registers.id` |
| `status` | `varchar(10)` | `open` → cálculo en vivo (US4); `closed` → leer snapshot si existe (D2/D8) | `open`\|`closed` |
| `opened_at` | `timestamp` (naive UTC) | Fecha operativa del turno (FR-005/FR-006) | Se convierte a la zona del tenant con `resolve_timezone`/`local_day_bounds_utc` (`app/core/timezone.py`) — mismo mecanismo que ya usa `reports/service.py` |
| `closed_at` | `timestamp` nulable | Mostrar fin del turno en el reporte | `NULL` mientras `status='open'` |

Sin columnas nuevas en esta tabla — el snapshot vive en su propia tabla (research.md D2). **US6**
añade dos índices (sección 4, revisión C): `cash_shifts (opened_at)` y
`cash_shifts (cash_register_id, opened_at)`, para las búsquedas "turnos por fecha de apertura" sin y
con filtro de caja. Los índices existentes (`idx_open_shift_per_register`, el de `cash_register_id`)
no se tocan.

### 1.2 `tenant.cash_registers` → **Caja registradora**

Sin cambios. `name`, `active`; filtro opcional de los reportes (FR-010/FR-011).

### 1.3 `tenant.sales` → **Venta** (fuente de verdad del reporte)

| Columna | Se usa para | Notas verificadas |
|---|---|---|
| `cash_shift_id` | Vínculo autoritativo venta↔turno (RN1/RN2) | `NOT NULL`; fijado por `build_sale` en el instante del cobro (research.md D3) — **ya correcto, sin cambios** |
| `status` | Filtrar solo `'paid'` | Mismo filtro que `reconcile()` (`cash/service.py:119-122`) |
| `total` | Ventas totales del turno (FR-004) | — |
| `sold_at` | **No se usa** para atribuir al turno | Se usa solo como metadato de ordenamiento si la UI lo necesita; la atribución es siempre por `cash_shift_id`, nunca por fecha de `sold_at` (RN2) |

### 1.4 `tenant.sale_items` → **Línea de venta**

`product_variant_id`, `quantity`, `line_total` — mismas columnas que ya usa
`reports/service.py::products_report` (`JOIN sale_items → sales`, `GROUP BY product_variant_id`).
Reutilizadas tal cual, acotadas por `sales.cash_shift_id` en vez de por rango de fechas.

**Índices que ya respaldan estas lecturas (US6, research.md D13)**: `sales (cash_shift_id)` y
`sale_items (sale_id)`. **No se crea ningún índice nuevo** sobre estas dos tablas: la medición con
186 turnos sin snapshot dio ≈ 150 ms con ellos, y el costo de escritura recae en el camino caliente
del cobro. Su nombre varía por entorno (`ix__sales__cash_shift_id` en migraciones,
`ix_tenant_sales_cash_shift_id` en la base de desarrollo): se identifican por columnas, nunca por
nombre.

### 1.5 `tenant.product_variants` / `tenant.products` / `tenant.categories`

Sin cambios — mismo join que `categories_report` (`sale_items → product_variants → products →
categories`). Un producto o categoría eliminado tras la venta sigue identificable por el nombre
que se congela en las filas del snapshot (FR-013, Assumptions de `spec.md`), no por una relectura
en vivo del catálogo vigente.

### 1.6 `tenant.customer_orders` → **Pedido** (para el bloqueo de cierre, FR-007)

| Columna | Se usa para | Notas verificadas |
|---|---|---|
| `status` | Determinar "activo" | `IN ('recibida', 'abierta', 'bloqueada')` = activo (research.md D1); `pagada`\|`cancelada` = no bloquea |
| `order_type` | Mostrar el canal en la lista de bloqueo (FR-008) | `DINE_IN`\|`TAKEAWAY`\|`DELIVERY`\|`NULL` (pedidos previos a spec 055) |
| `dining_table_id` | Mostrar la mesa en la lista de bloqueo, si aplica | nulable |
| `customer_name` | Mostrar el cliente en la lista de bloqueo (`TAKEAWAY`/`DELIVERY`) | nulable |
| `created_at` | Ordenar la lista de bloqueo (más antiguo primero) | — |
| `cash_shift_id` | **No se usa** para el bloqueo (research.md D1) | Solo numeración de `DINE_IN` (spec 087); se ignora deliberadamente aquí |

**Nota de alcance**: el filtro de "activo" no distingue `DINE_IN`/`TAKEAWAY`/`DELIVERY` (edge
case de `spec.md`) ni considera `order_type IS NULL` como excepción — un pedido histórico sin
clasificar que siga en estado no terminal también cuenta como activo.

**Índice que lo respalda (US6, FR-021/FR-023, research.md D12)**: `idx_active_order_per_participant`
(único parcial, spec 025, `WHERE status <> ALL ('pagada','cancelada')`) — el planificador de
PostgreSQL lo usa para el predicado `status IN ('recibida','abierta','bloqueada')`; con 1.000.000 de
pedidos históricos el conteo tarda 0,02 ms. **No se crea índice nuevo**; la contingencia (índice
parcial dedicado) está documentada en research.md D12.

## 2. Entidades nuevas del snapshot: cabecera + dos tablas hijas

El snapshot de un turno son **tres tablas** (research.md D9): la cabecera con los totales y dos
tablas hijas con el desglose completo, una fila por producto y una por categoría. Las tres se
escriben **una sola vez**, en la misma transacción de `close_shift`.

### 2.1 `ShiftSalesReport` — cabecera (`app/models/shift_sales_report.py`, tabla `shift_sales_reports`, schema `tenant`)

| Columna | Tipo | Regla |
|---|---|---|
| `id` | `UUID PK` | — |
| `cash_shift_id` | `UUID NOT NULL, FK → cash_shifts.id, ondelete="CASCADE", UNIQUE` | Relación 1:1 — a lo sumo un snapshot por turno. **La existencia de esta fila es el discriminador** de "este turno tiene snapshot" (research.md D9) |
| `total_sales` | `Numeric(12,2) NOT NULL` | Suma de `Sale.total` del turno (FR-004) |
| `order_count` | `Integer NOT NULL` | Cantidad de `Sale` `status='paid'` del turno |
| `avg_ticket` | `Numeric(12,2) NOT NULL` | `total_sales / order_count`, o `0` si `order_count=0` (FR-014) — se persiste explícito, no se deriva en cada lectura, para que FR-013 congele también este valor tal cual |
| `computed_at` | `DateTime NOT NULL, server_default=now()` | Instante del cierre en que se calculó — informativo, no participa en ninguna regla |

**US6**: esta tabla **pierde** las columnas `products_breakdown` y `categories_breakdown` (`JSONB`)
que creó la revisión A; su contenido pasa a las tablas 2.2 y 2.3 (revisión B).

**Constraints e índices** (sin cambios respecto a la revisión A):
- `UniqueConstraint("cash_shift_id", name="ux__shift_sales_reports__cash_shift_id")`.
- `CheckConstraint("total_sales >= 0")`, `CheckConstraint("order_count >= 0")`,
  `CheckConstraint("avg_ticket >= 0")`.

### 2.2 `ShiftSalesReportProduct` — desglose por producto (tabla `shift_sales_report_products`, schema `tenant`)

Una fila por `product_variant_id` con al menos una unidad vendida en el turno (FR-013/FR-017).

| Columna | Tipo | Regla |
|---|---|---|
| `id` | `UUID PK` | — |
| `cash_shift_id` | `UUID NOT NULL, FK → cash_shifts.id, ondelete="CASCADE"` | Turno al que pertenece el desglose |
| `product_variant_id` | `UUID NOT NULL` | **Sin FK** a `product_variants`: un producto eliminado después sigue en el reporte histórico (Assumptions de la spec) |
| `name` | `String(255) NOT NULL` | Nombre congelado = `MAX(SaleItem.description)` del turno (FR-022) |
| `units` | `Integer NOT NULL` | Suma de `SaleItem.quantity` |
| `revenue` | `Numeric(14,2) NOT NULL` | Suma de `SaleItem.line_total` |

**Constraints**: `UniqueConstraint("cash_shift_id", "product_variant_id",
name="ux__shift_sales_report_products__shift_variant")` — su índice, con `cash_shift_id` como primera
columna, es también el que respalda la lectura por turno (no hace falta otro); `CheckConstraint`
de `units >= 0` y `revenue >= 0`.

### 2.3 `ShiftSalesReportCategory` — desglose por categoría (tabla `shift_sales_report_categories`, schema `tenant`)

Una fila por categoría con ventas en el turno.

| Columna | Tipo | Regla |
|---|---|---|
| `id` | `UUID PK` | — |
| `cash_shift_id` | `UUID NOT NULL, FK → cash_shifts.id, ondelete="CASCADE"` | Turno al que pertenece |
| `category_id` | `UUID NULL` | **Sin FK** a `categories`. `NULL` ⇒ "Sin categoría" (rama defensiva: `Product.category_id` es `NOT NULL` hoy) |
| `category_name` | `String(255) NOT NULL` | Nombre congelado; `"Sin categoría"` cuando `category_id` es `NULL` |
| `units` | `Integer NOT NULL` | Suma de `SaleItem.quantity` |
| `revenue` | `Numeric(14,2) NOT NULL` | Suma de `SaleItem.line_total` |

**Constraints e índices**: índice `ix__shift_sales_report_categories__cash_shift_id` sobre
`cash_shift_id` (creado con la tabla); `CheckConstraint` de `units >= 0` y `revenue >= 0`. No hay
`UNIQUE (cash_shift_id, category_id)`: `NULL` no cuenta como igual en PostgreSQL, y la unicidad por
turno la garantiza la propia agrupación al escribir.

### 2.4 Reglas comunes

**Inmutabilidad (FR-013/SC-003)**: ninguna ruta de código distinta a la creación dentro de
`close_shift` escribe en estas tablas. No existe ningún `UPDATE` planificado — ni siquiera si una
venta del turno se anula después. Revertir una anulación equivocada, si el negocio lo necesitara,
es responsabilidad de otra vista (fuera de alcance, igual que la "vista de ajustes" que
`specs/006-turnos-caja-arqueo` deja pendiente para el arqueo de efectivo).

**Escritura al cerrar**: cabecera + una inserción masiva por tabla hija (no una sentencia por fila),
de modo que el número de sentencias no dependa de cuántos productos se vendieron (research.md D15).

**Orden**: el orden de persistencia no importa — el top-N y el ordenamiento (FR-022) se calculan en
la lectura, nunca al escribir. `revenue` se entrega por la API como string decimal, igual que antes
(mismo patrón del resto de la API para `Numeric`).

**Huérfanas**: unas filas hijas sin cabecera (no ocurre en operación normal) se **ignoran**: toda
lectura une siempre con la cabecera.

## 3. Modelo de lectura (no persistido): agregación por período

Objeto derivado, armado en cada consulta de turno / "turno actual" / "día" / "semana" / "mes" /
"rango" (FR-005/FR-006/FR-017). **No se persiste, no se cachea.** Con US6 se construye con
**cuatro consultas fijas, sea cual sea el número de turnos** (FR-018, research.md D10). Todas
comparten el mismo *selector de turnos* — condiciones sobre `cash_shifts` — y distinguen dos
conjuntos por la **existencia de la fila de cabecera** (sección 2.1):

- **Con snapshot** (turno `closed` con cabecera): se leen sus filas congeladas (2.2 / 2.3).
- **En vivo** (turno `open`, o `closed` **sin** cabecera — D8, anteriores a esta spec): se calcula
  `sales (paid) → sale_items` agrupado por (turno, variante) o (turno, categoría), en la misma
  consulta (FR-020), nunca turno por turno.

| # | Consulta | Resultado |
|---|---|---|
| 1 | Turnos del selector, con `LEFT JOIN` a la cabecera | `shift_ids` (orden `opened_at, id`) e `is_live` |
| 2 | Totales: suma de cabeceras `UNION ALL` suma/cuenta de `Sale` pagadas de los turnos sin cabecera | `total_sales`, `order_count` |
| 3 | Productos: filas de snapshot `UNION ALL` cálculo en vivo → nombre, suma, orden y `LIMIT` | `top_products` (N = 10) |
| 4 | Categorías: igual que la 3, sin `LIMIT` | `categories` |

La recombinación (FR-017) y el recorte al top-N (FR-019) ocurren dentro de la base de datos: nunca
se suman top-N ya recortados ni se acumula el desglose de cada turno en memoria del servidor.
`avg_ticket` se calcula **en Python** a partir de los totales (research.md D11).

**Reglas de la consulta (FR-022, research.md D11)**:
- *Nombre mostrado*: el de la fila del turno más antiguo por `(opened_at, id del turno)` en que
  aparece la variante (o la categoría).
- *Orden de productos*: `revenue DESC, name ASC, product_variant_id ASC`.
- *Orden de categorías*: `revenue DESC, category_name ASC, category_id ASC NULLS LAST`.

| Campo | Tipo | Significado |
|---|---|---|
| `period` | `"shift" \| "current_shift" \| "day" \| "week" \| "month" \| "range"` | Qué selector originó el reporte |
| `cash_register_id` | `UUID \| null` | Filtro aplicado, o `null` si agregado entre cajas |
| `shift_ids` | `UUID[]` | Turnos incluidos (auditoría/depuración, no exigido por ningún FR) |
| `is_live` | `bool` | `true` si al menos un turno incluido **no tiene cabecera de snapshot** (está `open`, o es un turno D8): parte del cálculo no es snapshot |
| `total_sales` | `Decimal` | Suma de todos los turnos incluidos |
| `order_count` | `int` | Suma de todos los turnos incluidos |
| `avg_ticket` | `Decimal` | `total_sales / order_count`, `0` si `order_count=0` |
| `top_products` | `ProductRow[]` | Top-N (10, research.md D5) del desglose de productos recombinado |
| `categories` | `CategoryRow[]` | Desglose de categorías recombinado completo (sin recorte — la spec no pide top-N de categorías, solo de productos) |

**Contador de pedidos activos (FR-012)**: el modelo de lectura del período **no** lleva
`active_orders_count`. En un turno individual abierto el contador viaja en
`ShiftSalesReportResponse.active_orders_count` ([contracts/shift-sales-report-api.md](./contracts/shift-sales-report-api.md)); en "Turno actual" (agregado) el
cliente lo obtiene de `GET /cash/active-orders` (longitud de la lista). En ambos casos cuenta los
pedidos activos de **todo el tenant** (research.md D1, FR-007), no solo los de la caja filtrada.

## 4. Migraciones (tres revisiones, todas vía `@for_each_tenant_schema`)

Cada revisión declara su estrategia de compatibilidad y de rollback (Principio VIII). Detalle y SQL
de referencia validado en research.md D14.

**Tenants nuevos y existentes**: el alta de un tenant crea sus tablas con `create_all` a partir de
los modelos (`app/core/db.py`), no con Alembic. Un tenant creado tras este cambio nace por tanto en
la **forma final** (secciones 2.1–2.3, más los índices declarados en `CashShift`). Las revisiones A, B
y C solo migran los tenants ya existentes, y deben ser **idempotentes frente a una forma ya final**.
Los nombres de índice del modelo y de la Rev. C son idénticos.

### Revisión A — `2009eabd2e82_119_shift_sales_reports` (existente; solo se le añade una guarda)

Crea `shift_sales_reports` con las columnas `JSONB`. **Ya está aplicada en la base local de
desarrollo** (tablas vacías) y su archivo aún no está versionado. **Guarda de idempotencia (único
cambio)**: tras la comprobación de `cash_shifts`, `if _has_table(schema, "shift_sales_reports"):
return` — un tenant ya en forma final (creado por `create_all`) conserva su tabla sin las columnas
`JSONB`, y sin esta guarda `create_table` fallaría y bloquearía `upgrade head` antes de B y C
(research.md D14 §2). Sin backfill: ningún turno
cerrado antes del despliegue recibe una fila retroactiva (research.md D8) — recalcular contra el
estado histórico exacto del cierre original no es confiable (ventas anuladas después, catálogo
cambiado), y la spec no lo exige (SC-003 solo protege turnos cerrados **después** de que exista el
snapshot). `downgrade`: `drop_table`.

### Revisión B — forma del dato (US6, **transaccional**)

`down_revision = '2009eabd2e82'`.

**Upgrade**, por esquema (omitiendo los que no tienen `cash_shifts`, como la Rev. A):
1. Crear `shift_sales_report_products` y `shift_sales_report_categories` (secciones 2.2 / 2.3) con
   sus constraints e índices — **solo si aún no existen** (tenant ya en forma final).
2. **Rellenar** ambas tablas desde las columnas `JSONB` de las cabeceras existentes (si las hay) —
   **solo si esas columnas todavía existen**.
3. Eliminar `products_breakdown` y `categories_breakdown` de `shift_sales_reports` — **solo si
   todavía existen**.

**Downgrade**: volver a crear las dos columnas `JSONB` (`NOT NULL`), **reconstruirlas desde las
filas** (`jsonb_agg(jsonb_build_object(...))`, mismo formato que escribía la Rev. A) y luego borrar
las tablas hijas. **Sin pérdida** (validado: JSONB restaurado idéntico, incluida una categoría con
`category_id` nulo).

**Compatibilidad**: ninguna fila de `cash_shifts`, `sales`, `sale_items`, `customer_orders` ni
`cash_registers` cambia de significado ni de valor. Las tablas hijas nacen vacías (o con lo
rellenado desde la Rev. A) y se pueblan hacia adelante, un turno a la vez, en cada cierre.

### Revisión C — índices (US6, **no transaccional**)

`down_revision` = Revisión B. Dentro de `op.get_context().autocommit_block()`, por esquema, **sin
bloquear escrituras** sobre ventas, turnos ni pedidos (FR-021):

| Índice | Definición |
|---|---|
| `ix__cash_shifts__opened_at` | `cash_shifts (opened_at)` |
| `ix__cash_shifts__register_opened_at` | `cash_shifts (cash_register_id, opened_at)` |

Cada uno: (1) consulta de catálogo `pg_index.indisvalid` y, si existe **inválido**, `DROP INDEX
CONCURRENTLY IF EXISTS`; (2) `CREATE INDEX CONCURRENTLY IF NOT EXISTS`. Por eso se puede
**ejecutar de nuevo** sin fallar y se **repara** un índice interrumpido (FR-021). **Downgrade**:
`DROP INDEX CONCURRENTLY IF EXISTS` de ambos. No toca datos; ningún otro índice cambia.

> Alembic no actualiza `alembic_version` hasta que la revisión termina; si la Rev. C se interrumpe a
> la mitad, los índices ya construidos permanecen y el reintento los reconoce como válidos.

## 5. Cambio de contrato HTTP

Ningún endpoint existente cambia de forma. `POST /cash/shifts/{id}/close` gana una validación
previa (puede responder `409` con un cuerpo nuevo cuando antes no lo hacía) pero su schema de
éxito (`ShiftResponse`) no cambia. **US6 no cambia ningún contrato**: respuestas, campos y tipos de
los endpoints de reporte son los mismos; la única diferencia observable es el orden en empates
exactos de ingreso (FR-022). Los campos de respuesta nuevos viven exclusivamente en los
endpoints nuevos — ver [contracts/shift-sales-report-api.md](./contracts/shift-sales-report-api.md)
y [contracts/active-orders-close-gate-api.md](./contracts/active-orders-close-gate-api.md).

## 6. Frontend: interfaces nuevas, sin cambio de las existentes

`DiningOrder`/`Sale`/`CashShift` (interfaces TypeScript ya existentes en
`pos-heladeria/src/app/modules/tables/interfaces/dining.interface.ts` y
`cash-register/interfaces/cash.interface.ts`) no se modifican. Se agregan interfaces nuevas
(`ShiftSalesReport`, `PeriodSalesReport`, `ActiveOrderSummary`, `ProductBreakdownRow`,
`CategoryBreakdownRow`) en el nuevo `dashboard/interfaces/shift-reports.interface.ts` (consumidas por
`dashboard/services/shift-reports.service.ts`), con la misma forma que la sección 3 de este documento — ningún campo
nuevo se agrega a un modelo ya consumido por otra pantalla.
