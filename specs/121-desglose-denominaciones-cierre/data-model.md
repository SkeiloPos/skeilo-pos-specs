# Modelo de datos — Desglose por denominación en el arqueo de cierre de caja

**Spec**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md) · **Investigación**: [research.md](./research.md)

Principio VIII: este documento declara entidades y campos nuevos, valores por defecto,
compatibilidad con datos existentes, migración y reversión. Todo vive en el **esquema de cada
tenant** (`schema-per-tenant`; en los modelos, `schema="tenant"` se traduce al esquema real).

## 1. Entidad nueva: `denomination_catalog` (Denominación del catálogo)

Modelo `DenominationCatalog` en `app/models/denomination_catalog.py`. Solo lectura en esta spec.

| Columna | Tipo | Nulo | Notas |
|---------|------|------|-------|
| `id` | `UUID` PK | no | `UUIDPrimaryKeyMixin` |
| `denomination` | `Numeric(12,2)` | no | Valor nominal. **Único** por tenant |
| `kind` | `String(10)` | no | `'billete'` \| `'moneda'` |

**Restricciones** (nombres según `convention` de `app/core/models.py`, todos ≤ 63 caracteres):

| Tipo | Definición | Nombre resultante |
|------|-----------|-------------------|
| Único | `UNIQUE (denomination)` | `uq__denomination_catalog__denomination` |
| CHECK | `denomination > 0` | `ck__denomination_catalog__ck_denomination_value_positive` (56) |
| CHECK | `kind IN ('billete','moneda')` | `ck__denomination_catalog__ck_denomination_kind` (46) |

**Sembrado** (`DEFAULT_COP_DENOMINATIONS`, 11 filas, FR-009):

| Tipo | Valores |
|------|---------|
| `billete` | 100000, 50000, 20000, 10000, 5000, 2000 |
| `moneda` | 1000, 500, 200, 100, 50 |

No hay `active`, `currency` ni `display_order`: el orden es siempre `denomination DESC`, y la
moneda y la administración quedan para una spec futura (FR-012, Assumptions de la spec).

**Valores por defecto / compatibilidad**: tabla nueva; no afecta a ninguna fila existente.

## 2. Entidad modificada: `cash_count_denominations` (Línea de desglose, snapshot)

Modelo existente `CashCountDenomination` (`app/models/cash_count_denomination.py`).

| Columna | Antes | Después |
|---------|-------|---------|
| `id`, `cash_shift_id`, `denomination`, `quantity` | — | **sin cambio** de tipo ni de nulidad |
| `kind` | no existía | **nueva**: `String(10)`, `NOT NULL`, sin valor por defecto |

| Restricción | Antes | Después |
|-------------|-------|---------|
| `ck_cash_count_quantity_positive` | `quantity >= 0` | **`quantity > 0`** (FR-015 como garantía de base de datos) |
| `ck_cash_count_kind` | — | **nueva**: `kind IN ('billete','moneda')` → `ck__cash_count_denominations__ck_cash_count_kind` (48) |
| `ck_cash_count_denomination_positive` | `denomination > 0` | sin cambio (su nombre ya está truncado con hash; no se toca) |
| `uq__cash_count_denominations__cash_shift_id__denomination` | único `(cash_shift_id, denomination)` | sin cambio (respaldo de FR-006/FR-019) |
| FK `cash_shift_id → cash_shifts.id ON DELETE CASCADE` | — | sin cambio |

**Es un snapshot (FR-014)**: copia `denomination`, `kind` y `quantity` al cierre. **No hay clave
foránea a `denomination_catalog`**; un cambio futuro del catálogo no altera turnos cerrados.
El **subtotal no se almacena**: se deriva (`denomination × quantity`) en la lectura, para que no
pueda divergir del valor y la cantidad.

## 3. Entidad modificada: `cash_shifts` (Turno de caja)

Modelo existente `CashShift` (`app/models/cash_shift.py`).

| Columna nueva | Tipo | Nulo | Notas |
|---------------|------|------|-------|
| `closed_by_user_id` | `UUID` | **sí** | Referencia blanda a `shared.users.id` (sin FK entre esquemas), como `user_id` |
| `closed_by_user_name` | `String(255)` | **sí** | Snapshot del nombre al cerrar, como `user_name` |

Sin valor por defecto: `NULL` en turnos abiertos y en **todos** los turnos históricos (la spec
prohíbe inferirlos del usuario de apertura). `counted_amount`, `close_note`, `closed_at` y `status`
**no cambian de forma**; sí cambia su origen: `counted_amount` ahora siempre proviene de las
líneas de desglose calculadas por el servidor (D-1).

## 4. Reglas de validación (aplicadas por el servidor al cerrar)

| Regla | Origen | Dónde se aplica | Respuesta |
|-------|--------|-----------------|-----------|
| Sin valores monetarios del cliente (`counted_amount`, `total`, `difference`, `subtotal`) | FR-002, D-1 | `reject_client_totals`, antes de leer el turno | `422`, cadena en español: recargar |
| Denominación repetida (valor numérico igual: `10000` = `10000.00`) | FR-006 | `resolve_count_lines` | `422` indicando la denominación |
| Denominación fuera del catálogo del tenant | FR-004 | `resolve_count_lines` | `422` indicando la denominación |
| Cantidad negativa o no entera | FR-005 | Pydantic (`ge=0`, `int`) | `422` (formato FastAPI) |
| Σ subtotales > 9 999 999 999,99 | Edge case «cantidades enormes» | `resolve_count_lines` | `422` en español |
| Lista vacía / todas en `0` | FR-003, D-2 | `close_shift` | Válido: contado `0`; sin líneas |
| Diferencia ≠ 0 ⇒ observación no vacía | FR-008, `RN-CASH-10` | `close_shift` | `422` (sin cambios) |
| Pedidos activos sin cobrar | FR-008, spec 119 | `close_shift` | `409` (sin cambios) |
| Turno ya cerrado | FR-018, `RN-CASH-11` | `close_shift` (con `FOR UPDATE`) | `409` (sin cambios) |

Ante **cualquier** rechazo no se persiste nada (FR-007): no hay `commit` hasta el final.

## 5. Transiciones de estado

Sin cambios en el ciclo del turno: `open → closed`, irreversible. Lo que cambia es **qué se escribe
en esa única transición**, todo dentro de la misma transacción (FR-016):

```text
open ── close_shift ─▶ closed
        escribe, en un solo commit:
          · cash_count_denominations   (una fila por línea con cantidad > 0, con kind)
          · cash_shifts.counted_amount (Σ subtotales; 0 si no hay líneas)
          · cash_shifts.close_note, closed_at, status
          · cash_shifts.closed_by_user_id / closed_by_user_name
          · shift_sales_reports        (snapshot de la spec 119, sin cambios)
```

Una vez en `closed` no existe ningún camino de escritura sobre las líneas ni sobre `closed_by_*`
(FR-017): no hay endpoints de edición/borrado y el reenvío del cierre responde `409`.

## 6. Migración (una sola revisión de Alembic)

`down_revision = 'cd3e314a79b8'` (único *head*). Por cada esquema de `shared.tenants`
(`@for_each_tenant_schema`, con la guarda `_has_table(schema, "cash_shifts")`), **en una
transacción**:

| # | Paso | Idempotencia |
|---|------|--------------|
| 1 | Crear `denomination_catalog` y sembrar los 11 valores | `IF NOT EXISTS` / `ON CONFLICT DO NOTHING` |
| 2 | **Compuerta FR-028**: si hay filas con `denomination` fuera del catálogo → `RAISE` (aborta la migración con esquema y valores) | — |
| 3 | `ADD COLUMN kind` (nulo) → `UPDATE … FROM denomination_catalog` → `SET NOT NULL` → `CHECK kind` | se omite si la columna ya existe (tenant nacido de `create_all`) |
| 4 | `DELETE … WHERE quantity = 0` (D-3); reemplazar `CHECK quantity >= 0` por `quantity > 0` | `DROP CONSTRAINT IF EXISTS`; el `DELETE` es no-op si ya no hay ceros |
| 5 | `ADD COLUMN closed_by_user_id`, `closed_by_user_name` | se omite si ya existen |

**Compatibilidad con datos existentes (SC-004)**: ningún paso lee ni escribe `counted_amount`,
`close_note`, la diferencia ni el esperado. Las filas con cantidad > 0 conservan valor y cantidad;
solo ganan `kind`. Los turnos sin filas siguen sin ellas (el reporte muestra el mensaje de FR-022).

**Estado medido en desarrollo (2026-10-15)**: `heladeria` — 35 filas, 0 con cantidad `0`, 0 fuera
del catálogo, 10 turnos con desglose y 2 cerrados sin desglose; `skeilo` y `tenantlocal` — vacíos.

**Respaldo previo (operativo, no parte de la migración)**: `pg_dump --table=<esquema>.cash_count_denominations`
por esquema, antes de ejecutar (quickstart, paso 1).

**Reversión (`downgrade`)** en orden inverso: quitar `closed_by_*` → restaurar
`CHECK quantity >= 0` → quitar `CHECK kind` y la columna `kind` → borrar `denomination_catalog`.
No pierde valor ni cantidad de ninguna línea conservada. **Se pierden** (aceptado en la spec): el
`kind`, `closed_by_*`, y —solo restaurables desde el respaldo— las filas con cantidad `0` que se
descartaron al subir.

**Divergencia `create_all` vs. Alembic**: los tenants nuevos nacen de `create_all` con la forma
final (incluida la tabla del catálogo y las columnas nuevas), por lo que la migración debe ser
tolerante a esquemas ya en forma final y **los nombres de restricciones del modelo y de la
migración deben ser idénticos**.
