# Data Model: Validación de saldo inicial mayor a cero al abrir caja

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)

Esta spec no crea ninguna entidad ni columna nueva. Acota un valor ya existente
(`CashShift.opening_amount`) en tres capas (base de datos, schema de request, formulario); no hay
transiciones de estado nuevas ni relaciones nuevas.

## Entidad modificada: `CashShift` (tabla `cash_shifts`, esquema `tenant`)

**Archivo**: `../pos-backend/app/models/cash_shift.py`

| Campo | Tipo | Cambio |
|---|---|---|
| `opening_amount` | `Numeric(12, 2)`, `nullable=False`, `default=0`, `server_default="0"` | Sin cambio de tipo/nulabilidad/default — solo cambia la restricción que lo acota (ver abajo). El `0` que queda como default de columna es inofensivo: ningún `INSERT` real llega a depender de él, porque `open_shift()` siempre envía `opening_amount` explícito y, tras D1, lo rechaza con 422 antes de construir el `CashShift` si es `<= 0`. |

**Restricción modificada**:

| Nombre | Antes | Después |
|---|---|---|
| `ck_cash_shift_opening_positive` | `CHECK (opening_amount >= 0)` | `CHECK (opening_amount > 0)` |

**Compatibilidad con datos existentes (Principio VII)**: ningún turno ya creado (abierto o
cerrado), incluido cualquiera con `opening_amount = 0`, se recalcula, se reescribe ni cambia su
representación histórica. La restricción nueva se agrega con `NOT VALID` (ver
"Estrategia de migración"), que por diseño de PostgreSQL omite validar las filas ya existentes en
la tabla — solo se aplica a partir de la primera fila nueva que PostgreSQL evalúe contra ella.

**Estrategia de migración**: migración Alembic nueva (`alembic/versions/607ff811ddff_113_cash_shift_opening_amount_positive.py`),
aplicada sobre cada esquema de tenant ya existente con el patrón
`app/scripts/tenant.py::for_each_tenant_schema` (mismo patrón usado por
`alembic/versions/c7e2b91a4d35_084_variante_sin_nombre.py` y otras migraciones por-esquema de este
proyecto), con un guard `_has_table(schema, "cash_shifts")` (el esquema de scratch `tenant_default`
no tiene las tablas base creadas):

**Corrección sobre lo investigado en research.md D2**: el nombre real del constraint en la base de
datos **no** es `ck_cash_shift_opening_positive` (el nombre corto pasado a
`CheckConstraint(name=...)` en el modelo) — `app/core/models.py` define una convención de nombres
(`'ck': 'ck__%(table_name)s__%(constraint_name)s'`) que SQLAlchemy aplica al crear la tabla, así que
el nombre real, verificado contra los esquemas `heladeria`/`skeilo`/`tenantlocal`, es
`ck__cash_shifts__ck_cash_shift_opening_positive`. La migración usa ese nombre real; el modelo
(`cash_shift.py`) no necesita ningún cambio adicional porque `CheckConstraint(name=...)` sigue
recibiendo el nombre corto — es SQLAlchemy quien aplica la convención automáticamente.

```python
def _upgrade_schema(schema: str) -> None:
    op.execute(text(
        f'ALTER TABLE "{schema}".cash_shifts '
        f'DROP CONSTRAINT ck__cash_shifts__ck_cash_shift_opening_positive'
    ))
    op.execute(text(
        f'ALTER TABLE "{schema}".cash_shifts '
        f'ADD CONSTRAINT ck__cash_shifts__ck_cash_shift_opening_positive '
        f'CHECK (opening_amount > 0) NOT VALID'
    ))
```

El modelo (`app/models/cash_shift.py:44`) se actualiza en el mismo cambio a
`CheckConstraint("opening_amount > 0", name="ck_cash_shift_opening_positive")`, de forma que
cualquier tenant aprovisionado después de este cambio (vía `get_tenant_specific_metadata()
.create_all(...)`, `app/core/db.py:100` — crea el esquema desde los modelos actuales, no
reproduciendo el historial completo de Alembic) nazca ya con la restricción `> 0`, sin depender de
que la migración se le aplique.

**Estrategia de rollback**: la función `downgrade()` de la misma migración revierte exactamente el
cambio, también por-esquema:

```python
def _downgrade_schema(schema: str) -> None:
    op.execute(text(
        f'ALTER TABLE "{schema}".cash_shifts '
        f'DROP CONSTRAINT ck__cash_shifts__ck_cash_shift_opening_positive'
    ))
    op.execute(text(
        f'ALTER TABLE "{schema}".cash_shifts '
        f'ADD CONSTRAINT ck__cash_shifts__ck_cash_shift_opening_positive '
        f'CHECK (opening_amount >= 0)'
    ))
```

Sin pérdida de información: ningún dato se backfillea ni se transforma en ningún sentido: la
columna y sus valores no cambian, solo la restricción que PostgreSQL evalúa sobre los `INSERT`
futuros.

**Relaciones**: ninguna. `opening_amount` no se referencia desde otra tabla.

## Esquema de request modificado: `ShiftOpen`

**Archivo**: `../pos-backend/app/api/v1/cash/schemas.py:30-32`

| Campo | Antes | Después |
|---|---|---|
| `opening_amount` | `Decimal = Field(0, ge=0, max_digits=12, decimal_places=2)` | `Decimal = Field(0, max_digits=12, decimal_places=2)` (se retira `ge=0`) |

El límite de negocio (`> 0`) deja de vivir en el `Field` de Pydantic y pasa a una validación
explícita en el router (`open_shift()`, `app/api/v1/cash/router.py:69`), para poder devolver el
mensaje exigido por FR-005 en vez del envelope genérico de validación — ver
[contracts/post-shifts-open.md](./contracts/post-shifts-open.md) para el contrato completo del
endpoint y [research.md](./research.md) D1 para la justificación de por qué no se usa `gt=0`
directamente en el `Field`.

## Formulario modificado (frontend, no persistido): apertura de turno

**Archivos**: `../pos-heladeria/src/app/modules/cash-register/services/cash-session.store.ts`,
`../pos-heladeria/src/app/modules/cash-register/components/cash-open.component.ts`

No es una entidad de datos — es estado de UI ya existente (`CashSessionStore.openingAmount`,
`signal<number>`) al que se agrega un `computed` derivado:

| Derivado | Definición | Uso |
|---|---|---|
| `aperturaDisabled` *(nuevo)* | `isSubmitting() \|\| !selectedRegisterId() \|\| openingAmount() <= 0` | `[disabled]` del botón "Abrir caja y comenzar turno" en `cash-open.component.ts` (antes solo `isSubmitting() \|\| !selectedRegisterId()`). |

El mensaje de error en línea y el borde rojo del campo (`[invalid]="store.openingAmount() <= 0"`
sobre `<app-money-input>`) se derivan directamente de `openingAmount() <= 0` en la plantilla, sin
necesitar un `computed` propio — ver
[contracts/cash-open-form.md](./contracts/cash-open-form.md) para el contrato completo del
formulario.

## Datos de prueba (test infra, no entidad de producto)

**Archivos**: `../pos-backend/app/characterization_tests/cart_fixtures.py:406`,
`orders_fixtures.py:421`, `table_sessions_fixtures.py:366`

Las tres copias de `make_cash_shift(db, register=None, **kw)` cambian su valor por defecto:

| Antes | Después |
|---|---|
| `kw.setdefault("opening_amount", Decimal("0"))` | `kw.setdefault("opening_amount", Decimal("100000"))` |

Justificación completa (por qué este cambio no reabre ningún characterization test protegido por
el Principio III) en [research.md](./research.md) D4.

## Transiciones de estado

Esta spec **no introduce** ninguna transición de estado nueva sobre `CashShift`. El ciclo de vida
(`'open'` → `'closed'`, vía `open_shift()`/`close_shift()`) no cambia; solo se acota el rango válido
de un atributo que ya existía desde antes de esta spec, y únicamente en el momento de creación
(`opening_amount` nunca se actualiza después de abierto el turno).
