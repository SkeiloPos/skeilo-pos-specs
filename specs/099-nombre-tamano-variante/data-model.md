# Data Model: Nombre comercial propio para los tamaños de un producto

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)

Un único cambio de esquema, aditivo y reversible (research.md D1/D6). Todo lo demás de esta spec
es lógica calculada (D2) y presentación.

## Cambio de esquema

### `tenant.product_variants` — columna nueva

| Campo | Tipo | Nulo | Default | Comentario |
|---|---|---|---|---|
| `name` | `VARCHAR(60)` | **No** | `''` | Nombre comercial propio de la variante, ya recortado y con espacios internos colapsados (D3). `''` en toda variante que no tenga nombre propio — nunca `NULL` (FR-003). |

- **Sin índice** y **sin restricción `UNIQUE` en base de datos**: la unicidad de FR-008 es sobre
  `display_name` (calculado, insensible a mayúsculas, solo entre variantes activas), no sobre
  `name` crudo — se valida en la capa de servicio (research.md D5), igual que ya se valida hoy el
  SKU repetido.
- **Sin `CHECK` de formato en la base**: el límite de 60 caracteres lo fija el tipo de columna; la
  normalización (recorte + colapso de espacios) vive en la aplicación
  (`app/core/variant_name.py`, D3) y se aplica antes de persistir — mismo criterio que
  `person_name.py` (spec 091).
- El modelo ORM añade `name: Mapped[str] = mapped_column(String(60), nullable=False,
  server_default="")`.

### Migración

- Archivo nuevo en `pos-backend/alembic/versions/`, `down_revision = '2d50957395dc'` (cabecera
  actual), `e7d8c9b0a1f2_099_nombre_tamano_variante.py` (research.md D6).
- `upgrade()` (por schema de tenant, con el mismo patrón `@for_each_tenant_schema` que
  `a9f7d0310f6b_084_variante_presentacion.py`): `op.add_column('product_variants',
  sa.Column('name', sa.String(60), nullable=False, server_default=''), schema=schema)`.
- `downgrade()`: `op.drop_column('product_variants', 'name', schema=schema)`.
- **Backfill implícito**: Postgres aplica `DEFAULT ''` a cada fila existente dentro del mismo
  `ADD COLUMN NOT NULL` — no hay un `UPDATE` separado que pueda dejar filas a medio migrar.
  Ninguna presentación, precio, orden (`display_order`) ni pedido se toca (Escenario 1).
- **Rollback**: `downgrade` elimina la columna sin tocar `presentation_id`, `price`,
  `display_order` ni ninguna tabla de pedidos — el código anterior a esta spec nunca leyó `name`
  (no existía), así que funciona sin cambios una vez revertida (Escenario 18).
- **Tenant schemas**: la tabla vive en `tenant` (una por negocio); la migración se aplica una vez
  por cada schema existente, igual que las migraciones aditivas previas de este módulo.
- **Orden de despliegue**: la migración va **antes** que el backend nuevo (el modelo ORM nuevo
  selecciona la columna).

## Entidades (visión funcional)

### Variante de producto (`ProductVariant`) — ampliada

| Atributo | Cambio | Reglas |
|---|---|---|
| `name` | **nuevo**, persistido | Opcional (`''` por defecto); 0-60 caracteres tras normalizar (D3); nunca `null` (FR-003). |
| `display_name` | **nuevo**, calculado — no persistido | `name` si no es `''`; si no, `presentation.name`; si ninguno está disponible, `"Tamaño"` + advertencia registrada con el `id` de la variante (FR-005, research.md D2). |
| `presentation_id`, `presentation_name`, `price`, `display_order`, `active`, `sku` | sin cambio | `presentation_id` sigue siendo obligatorio y la única fuente estructural del tamaño (research.md, "Contexto histórico"). |

**Regla de unicidad nueva (FR-008, sin columna ni índice — ver arriba)**: dentro de un mismo
producto, el `display_name` de dos variantes **activas** nunca puede coincidir (comparación
insensible a mayúsculas, tras normalizar). Una variante desactivada no participa en esta
comparación — su etiqueta queda libre para reutilizarse mientras permanezca desactivada
(Clarificación, sesión 2026-10-06).

**Sin transiciones de estado nuevas**: `active` ya existe (soft-delete) y esta spec no le agrega
ningún estado ni lo usa para nada distinto de excluir del chequeo de duplicados.

### Presentación (`Presentation`) — sin cambio de esquema

Sigue siendo el catálogo reutilizable de nombres de tamaño (`tenant.presentations.name`, único,
obligatorio). Esta spec no le agrega ni le quita ningún atributo; sigue siendo la fuente de
`display_name` para cualquier variante con `name = ''` (FR-016: renombrar una presentación cambia
de inmediato el `display_name` de toda variante sin nombre propio que la use).

## Reglas de validación (resumen; la definición completa y los vectores de prueba están en
[contracts/variant-name-rules.md](./contracts/variant-name-rules.md))

| Dato | Regla | Dónde se aplica | Error |
|---|---|---|---|
| `name` | ausente/`null` → `''` → recortar extremos → colapsar espacios internos → si > 60 caracteres (medidos antes de recortar), rechazar | servidor (siempre) y formulario (en vivo) | 422 "El nombre admite hasta 60 caracteres" |
| `display_name` duplicado | insensible a mayúsculas, solo entre variantes **activas** del mismo producto | servidor, al guardar el árbol de variantes (`_save_variant_entry`) | 409 "Ya existe un tamaño con ese nombre en este producto" |
| Contenido HTML/script en `name` | se escapa al mostrarse (interpolación de Angular, nunca `[innerHTML]`) | formulario y menú público | N/A — no es un error de guardado, es una garantía de representación (FR-011) |

## Modelos de presentación (frontend, sin persistencia propia)

- `VariantDraft` (`product.interface.ts:348-363`): añade `name: string` (valor crudo tal como lo
  escribe el administrador, sin normalizar hasta enviarlo).
- `VariantSaveIn`/`VariantResponse` (interfaces TS que reflejan el payload/respuesta del backend):
  añaden `name: string`; `VariantResponse`/`VariantSaveOut`/`MenuVariantResponse` añaden además
  `display_name: string`, sin quitar `presentation_name` (research.md D7).
- `MenuVariant` (`product.interface.ts:466`): **sin cambio de forma** — su campo `name` ya
  representa "lo que se muestra"; solo cambia su origen (`display_name` en vez de
  `presentation_name`, research.md D8).
- `variantNamePlaceholder(v: VariantDraft): string`: función pura nueva (research.md D9) — `Se
  mostrará: ${v.presentationName}` o `Se mostrará la presentación`.
