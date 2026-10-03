# Data Model: Carta del menú para Cajero con estado Agotado

**Spec**: [spec.md](./spec.md) | **Research**: [research.md](./research.md)

## Resumen

Esta funcionalidad **no introduce ninguna entidad nueva**. Extiende la entidad `Product`
ya existente (`app/models/product.py`, schema `tenant`), que ya tiene el campo booleano
`available` desde antes de esta spec (ver research.md, hallazgo de partida). Lo que se
agrega es: (1) dos columnas de trazabilidad sobre esa misma fila, y (2) el uso, por
primera vez, de la tabla genérica `AuditLog` ya existente para este tipo de cambio.

## Entidad: `Product` (`tenant.products`)

### Campos existentes relevantes (sin cambios)

| Campo | Tipo | Significado |
|---|---|---|
| `active` | `bool` | Alta/baja de catálogo (gestionado solo por Administrador). Independiente de `available` — **no se modifica su comportamiento**. |
| `available` | `bool`, default `True` | **Es** el flag "Agotado" de esta spec (`available=False` ⇔ "Agotado"). Ya existía; hasta esta spec solo se usaba para ocultar el producto del menú QR (ver research.md D6) y solo lo podía cambiar el Administrador vía el PATCH completo de producto. |

### Campos nuevos

| Campo | Tipo | Nullable | Default | Significado |
|---|---|---|---|---|
| `available_changed_at` | `DateTime` (UTC naive, convención `app/core/timezone.py`) | Sí | `NULL` | Instante del último cambio de `available` hecho a través del nuevo interruptor dedicado (D3). `NULL` = nunca se ha tocado desde que existe esta columna (incluye todo producto creado antes de esta spec). |
| `available_changed_by_name` | `String(150)` | Sí | `NULL` | Nombre del usuario (Cajero o Administrador) que hizo el último cambio — snapshot de texto, **no** una FK dura a `shared.users.id` (mismo patrón que `AuditLog.user_name`, porque `users` vive en el schema `shared` y `products` en el schema `tenant`: una FK entre schemas no es el patrón de este proyecto). |

No se agrega `available_changed_by_id` como columna propia: el identificador duro del
usuario que hizo el cambio ya queda en el `payload`/`user_id` de la fila de `AuditLog`
correspondiente (ver abajo) — la columna en `Product` solo necesita resolver, sin join,
"quién" para mostrarlo en pantalla, no para integridad referencial.

### Compatibilidad con datos existentes (Principio VIII)

- Todo producto ya existente recibe `available_changed_at = NULL`,
  `available_changed_by_name = NULL` al migrar — no se infiere retroactivamente quién
  marcó el `available` actual de un producto ya existente, porque no hay ese dato en
  ningún lado del sistema hoy. La interfaz debe tratar `NULL` como "sin información de
  cuándo/quién" (no debe imprimir "hace unos segundos" ni una fecha falsa sobre un
  producto que nunca pasó por el interruptor nuevo).
- `available` en sí no cambia de tipo, default ni semántica — ningún producto existente
  cambia de valor por esta migración.

### Migración (Alembic)

- **Up**: `ALTER TABLE tenant.products ADD COLUMN available_changed_at timestamp NULL;
  ALTER TABLE tenant.products ADD COLUMN available_changed_by_name varchar(150) NULL;`
  aplicado a cada schema de tenant existente (mismo mecanismo que el resto de columnas
  `tenant`-scoped de este repo, ver `app/scripts/tenant.py::for_each_tenant_schema`,
  usado por ejemplo en la migración de `notificaciones` citada en research.md).
- **Down**: `DROP COLUMN` de ambas columnas, en cada schema de tenant — sin pérdida de
  información de negocio irreversible más allá de la propia trazabilidad que esta spec
  introduce (no hay FK entrante a estas columnas, no hay otra tabla que dependa de
  ellas).
- No aplica ninguna migración de datos (`UPDATE`) más allá de los defaults `NULL` de
  arriba.

## Reutilización: `AuditLog` (`tenant.audit_logs`, sin cambios de esquema)

Cada cambio exitoso de disponibilidad a través del nuevo endpoint (ver
`contracts/products-availability-api.md`) agrega una fila:

| Campo | Valor para este caso |
|---|---|
| `action` | `"availability_changed"` |
| `entity` | `"product"` |
| `entity_id` | id del producto |
| `user_id` / `user_name` | el Cajero o Administrador que hizo el cambio |
| `payload` (JSONB) | `{"available": <nuevo_valor>, "previous": <valor_anterior>}` |
| `at` | `server_default=func.now()` (ya existente en la tabla) |

Esta tabla ya existe (`app/models/audit_log.py`) y ya se usa para `promotions` — no
requiere ningún cambio de esquema, solo un nuevo call site de `record_audit()`
(`app/core/audit.py`).

## Respuesta del menú (`MenuProductResponse`, `app/api/v1/menu/schemas.py`)

| Campo | Estado | Significado |
|---|---|---|
| `available` | **Sin cambios** | "Pedible dado el stock de las opciones obligatorias de sus presentaciones" (characterization-protegido, `test_menu_router.py`). No es el flag de esta spec. |
| `sold_out` | **Nuevo** | `not Product.available` — el flag manual "Agotado" de esta spec. Es el campo que Terminal de mesas y menú QR consultan para atenuar la tarjeta, mostrar la etiqueta "Agotado" y deshabilitar agregar al pedido (research.md D6). |

## Matriz de estados: `active` × `available` (independencia, regla de negocio)

| `active` | `available` | Listado Cajero/Admin | Interruptor "Agotado" | Visible en menú QR / Terminal | Se puede pedir |
|---|---|---|---|---|---|
| `True` | `True` | "Activo" / "Disponible" | habilitado, apagado | Sí | Sí |
| `True` | `False` | "Activo" / "Agotado" | habilitado, encendido | Sí, atenuado + etiqueta "Agotado" | No |
| `False` | `True` | "Inactivo" / "Disponible" | **deshabilitado** (no se puede tocar) | No (ya excluido por `Product.active.is_(True)`, sin cambios) | No |
| `False` | `False` | "Inactivo" / "Agotado" | **deshabilitado** (no se puede tocar; el valor se conserva tal cual quedó) | No | No |

Esta tabla es la especificación operativa de FR-010/FR-011/escenario 10: desactivar un
producto nunca toca `available`, y mientras `active=False` el interruptor queda
congelado en el valor que tenía (no se puede ni marcar ni desmarcar desde ahí).

## Entidades no modificadas, explícitamente

- **`ProductVariant`/presentaciones**: sin cambios de esquema. Se exponen en el nuevo
  detalle de producto solo vía el shape `VariantResponse` ya existente (id, sku, price,
  active, presentation_id, presentation_name) — sin receta ni grupos de opciones (ver
  research.md D9).
- **`Cart`/`CartItem`/`CustomerOrder`/`OrderItem`**: sin cambios de esquema. La
  validación nueva (research.md D7) es solo lógica de servicio sobre datos ya existentes
  (`variant.product.available`); ningún pedido ya creado se recalcula ni se migra
  (FR-023).
- **`Role`**: sin cambios — se reutiliza el rol `CASHIER` ya existente, sin agregar
  ninguna fila nueva a `shared.roles` (a diferencia de la spec 075, que sí agregó
  `MESERO`).
