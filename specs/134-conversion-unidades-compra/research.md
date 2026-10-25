# Research: Compra de Insumos con Conversión a Unidad Base

**Spec**: `specs/134-conversion-unidades-compra/spec.md` | **Fecha**: 2026-10-24

Este documento resuelve las decisiones técnicas necesarias para implementar la spec,
apoyándose en hallazgos concretos del código de `pos-backend`. No hay "NEEDS
CLARIFICATION" pendientes en la sección de Contexto Técnico del plan: todas las
decisiones de esta sección cierran huecos de implementación, no decisiones de negocio
(esas ya están resueltas en la sección "Clarifications" de la spec).

## D1. El "grupo de medida" se modela como columna, no como tabla nueva

**Hallazgo**: `app/core/units.py` ya contiene una función `convert(quantity, from_unit,
to_unit)` que hace duck-typing sobre `from_unit.dimension` y `from_unit.factor_to_base`
(y lo mismo en `to_unit`). Es código muerto hoy: `app/models/unit_measure.py` no declara
esas columnas, y `app/characterization_tests/test_core_units.py` congela exactamente eso
como RN-CAT-41 (hallazgo crítico documentado en `pos-specs/specs/000-reconocimiento`).
`convert()` fue escrita para una `UnitMeasure` con un atributo `dimension` **plano**
(string), no para una relación a una tabla de grupos.

**Decisión**: "Grupo de medida" se implementa como una columna `dimension: str` en
`unit_measures` (no como una entidad/tabla nueva). Dos unidades son del mismo grupo si
`dimension` coincide (comparación exacta, sensible a mayúsculas: el admin que crea una
unidad escribe el nombre del grupo igual que ya escribe `name`/`abbreviation`, sin
catálogo cerrado de grupos). El aislamiento por negocio (FR-017) ya lo da gratis el
esquema `tenant` por tenant (arquitectura schema-per-tenant): no hace falta `tenant_id`
en ninguna tabla nueva.

**Alternativas consideradas**: tabla `measure_groups` con FK desde `unit_measures`.
Rechazada por Principio V/VI de la constitución (evitar entidades nuevas no
estrictamente necesarias) y porque el código ya existente (`convert()`, los
characterization tests) fue escrito explícitamente contra el modelo de columna plana —
usar una tabla sería remar contra ese diseño ya congelado como intención futura.

## D2. Activar `convert()` resolviendo RN-CAT-41

**Decisión**: añadir a `unit_measures`: `dimension: str NOT NULL` y `factor_to_base:
Numeric(18,6) NOT NULL DEFAULT 1`. Esto convierte el `AttributeError` congelado en
`test_rn_cat_41_unit_measure_real_no_tiene_dimension_attributeerror` en comportamiento
obsoleto: ese characterization test deja de reflejar la realidad y se actualiza en el
mismo cambio (Principio III: el spec que autoriza el cambio es esta spec 134; se cita
aquí y en el commit que lo toca). El resto de `ConvertWithDuckTypedUnitsTests` sigue
pasando sin tocarse: siguen usando objetos `SimpleNamespace`, no el modelo real.

**Migración**: todo `UnitMeasure` existente no tiene hoy ningún concepto de grupo; se
backfillea con `dimension = 'general'` (un único grupo histórico) y `factor_to_base = 1`
para no romper ninguna relación existente insumo↔unidad. Es aditivo y reversible
(rollback: drop columns).

## D3. `unidad base del insumo` ya existe; no se toca `InventoryItem`

`InventoryItem.unit_measure_id` ya es la unidad base del insumo (FR-001 ya está
satisfecho estructuralmente). Lo único que falta es la regla FR-002 (no se puede
cambiar una vez hay movimientos), que se implementa como validación en el handler de
`PATCH /inventory/items/{id}` (`router.py`): si `body.unit_measure_id` viene y difiere
del actual, y existe al menos un `InventoryMovement` para ese insumo → 409.

## D4. Precisión de 6 decimales: ensanchar columnas, no solo añadir nuevas

**Hallazgo**: `inventory_items.current_stock`/`unit_cost` son `Numeric(12,3)`/`(12,2)`.
Si `PurchaseItem.quantity_base`/`cost_base` (nuevas, 6 decimales por la clarificación de
la spec) alimentan `record_movement()` y el costo del insumo, pero `current_stock`/
`unit_cost` solo admiten 3/2 decimales, se pierde exactamente la precisión que SC-001
exige no perder (un factor con muchos decimales, p. ej. 453,592 para LB→g, puede producir
cantidades base con más de 3 decimales significativos en acumulaciones sucesivas).

**Decisión**: ensanchar `inventory_items.current_stock` → `Numeric(18,6)`,
`inventory_items.unit_cost` → `Numeric(18,6)`, e `inventory_movements.quantity` →
`Numeric(18,6)`. Es una migración segura: ensanchar precisión/escala nunca trunca datos
existentes (Principio VIII: compatible con datos existentes, rollback = volver a la
escala anterior porque ningún valor histórico excede `Numeric(12,3)`).

## D5. Columnas nuevas en `PurchaseItem`, sin tocar el flujo de `supplier_item_id` (spec 106/107)

**Hallazgo**: `_resolve_purchase_line` (`app/api/v1/inventory/service.py`) ya tiene una
rama para `supplier_item_id` (presentación de proveedor, spec 106/107) que calcula
`quantity`/`unit_cost` ya convertidos a unidad base del insumo, y otra rama "directa" en
la que `quantity`/`unit_cost` ya SON la unidad base (porque no hay conversión). Esta spec
134 generaliza la conversión para **cualquier** unidad del mismo grupo de medida del
insumo, no solo las presentaciones pactadas con un proveedor concreto. Las dos rutas son
conceptualmente distintas (una u otra, nunca ambas) y la ruta `supplier_item_id` queda
congelada tal cual (Principio II/III): esta spec no la modifica.

**Decisión**: añadir a `PurchaseItem`:
- `unit_measure_id` (FK `unit_measures.id`, NOT NULL tras backfill): unidad en la que se
  capturó la línea. Para líneas con `supplier_item_id`, se guarda la unidad base del
  insumo (la conversión ya la gobierna `SupplierItem.conversion_factor`, no esta spec).
- `conversion_factor_applied` (`Numeric(18,6)`, NOT NULL, default 1): factor resuelto en
  servidor al confirmar (FR-008), congelado para siempre (FR-010).
- `quantity_base` (`Numeric(18,6)`, NOT NULL): cantidad en unidad base del insumo.
- `cost_base` (`Numeric(18,6)`, NOT NULL): costo unitario en unidad base del insumo.

Las columnas existentes `quantity`/`unit_cost` **no cambian de significado**: siguen
siendo "lo que se capturó" (cantidad/costo originales, FR-009). Para las dos rutas que ya
existían hoy (directa y `supplier_item_id`), eso ya coincide con la unidad base, así que
`quantity_base = quantity` y `cost_base = unit_cost` para esas dos rutas — comportamiento
idéntico al actual, solo con nombres explícitos. Solo la ruta nueva (un
`unit_measure_id` distinto de la unidad base del insumo) hace que `quantity_base` y
`cost_base` difieran de `quantity`/`unit_cost`.

`record_movement()` y la actualización de `item.unit_cost` en `create_purchase` /
`receive_purchase` pasan a leer `quantity_base`/`cost_base` en vez de `quantity`/
`unit_cost` — sin cambio observable para las rutas existentes, porque hoy son iguales.

**FR-021 (backfill)**: para toda fila `PurchaseItem` anterior a esta spec,
`unit_measure_id = <unit_measure_id del InventoryItem de esa línea>`,
`conversion_factor_applied = 1`, `quantity_base = quantity`, `cost_base = unit_cost`. El
stock existente no se recalcula ni se toca (ya está correcto).

## D6. "Costo promedio" sigue siendo el comportamiento actual (sobrescritura simple)

**Hallazgo**: a pesar de que los comentarios y la spec hablan de "costo promedio",
`create_purchase`/`receive_purchase` hoy simplemente **sobrescriben**
`item.unit_cost = purchase_item.unit_cost` en cada compra — no hay media ponderada.

**Decisión**: no se introduce una media ponderada nueva (eso sería una funcionalidad no
pedida por esta spec, Principio V). FR-007 se satisface sobrescribiendo
`item.unit_cost = purchase_item.cost_base` — mismo comportamiento de hoy, ahora
alimentado por el valor correctamente convertido en vez de asumir que `unit_cost` ya
estaba en unidad base.

## D7. Selector de unidades válidas (FR-003) y validación en servidor (FR-004)

**Decisión**: `GET /unit-measures` gana un query param `dimension` (filtra por grupo,
además del `active` que ya existe). El selector de unidad de una línea de compra pide
`GET /unit-measures?dimension=<dimension del insumo>&active=true`. En el servidor,
`_resolve_purchase_line` valida la línea reutilizando `convert()`: si
`chosen_unit.dimension != item.unit_measure.dimension`, `convert()` ya lanza 422 con el
mensaje de incompatibilidad (RN-CAT-40) — no se duplica esa lógica.

## D8. Bandera "conversión de unidades activa/desactivada" (FR-016)

**Hallazgo**: la spec asume en "Assumptions" que esta bandera "ya existe o se gestiona
por fuera de esta especificación". No es así: no existe ningún campo así en `Tenant`
(`app/core/models.py`) ni en ninguna tabla de configuración del tenant. No hay negocio
nuevo que decidir aquí — FR-016 ya está aprobado en la spec; solo falta el lugar donde
se guarda ese valor para que FR-016 sea implementable.

**Decisión**: añadir `Tenant.unit_conversion_enabled: bool NOT NULL DEFAULT true`
(esquema `shared`, junto a las demás banderas de configuración del tenant como
`receipt_message`/`invoice_prefix`). `true` por defecto preserva el comportamiento para
todo tenant existente (ningún tenant pierde la capacidad que ya tendría al llegar esta
spec). Cuando es `false`, `_resolve_purchase_line` rechaza con 422 cualquier
`unit_measure_id` que no sea el `unit_measure_id` propio del insumo.

## D9. Anulación de compras confirmadas (US3, FR-012/FR-013) — funcionalidad nueva

**Hallazgo**: no existe ningún endpoint de anulación de compras hoy. `Purchase.status`
(`draft`/`partial`/`received`) gobierna la recepción, no la anulación.

**Decisión**: añadir `Purchase.voided_at: datetime | None` y `Purchase.voided_by: UUID |
None` (no se reutiliza/ensancha el `CheckConstraint` de `status`, que es ortogonal a
"anulada"). Nuevo endpoint `POST /inventory/purchases/{id}/void`:
- 409 si `voided_at` ya está puesto (FR-013, rechaza doble anulación).
- Por cada `PurchaseItem` de la compra, `record_movement(type="out", quantity=
  pi.quantity_base, reason=AJUSTE, reference_type=REF_PURCHASE_VOID, reference_id=
  purchase.id)` — resta exactamente la cantidad base guardada en la línea, nunca
  recalculada con el factor vigente (FR-012; `quantity_base` es inmutable por D5).
- Usa el mismo `record_movement()` con `with_for_update()` que ya da la atomicidad de
  FR-020 — no hace falta mecanismo nuevo de bloqueo.

Nuevo valor de referencia `REF_PURCHASE_VOID` en `app/core/inventory_reasons.py`, junto a
`REF_ORDER_VOID` que ya existe con el mismo patrón.

## D10. Historial de cambios de factor + autorización de admin (FR-011/FR-011a)

**Decisión**: nueva tabla `unit_measure_factor_changes` (esquema `tenant`): `id`,
`unit_measure_id` (FK), `old_factor`, `new_factor`, `changed_by` (UUID, referencia
blanda a `shared.users.id`, mismo patrón que `Purchase.user_id`), `changed_at`. En
`PATCH /unit-measures/{id}`, si el body trae `factor_to_base` y difiere del actual:
- Exige `require_tenant_admin` (ya existe en `app/core/dependencies.py`, usado hoy por
  `app/api/v1/users/router.py`) — 403 para cualquier otro rol. Los demás campos
  (`name`, `abbreviation`, `active`) del mismo endpoint **no** adquieren esta
  restricción: solo el cambio de factor la requiere (FR-011a es específico sobre eso).
- Inserta una fila en `unit_measure_factor_changes` con el valor viejo/nuevo.

## D11. Cantidad/costo > 0 en la nueva ruta de conversión (FR-015, edge case de costo)

**Decisión**: `quantity` y `unit_cost` de una línea con `unit_measure_id` (la ruta nueva)
se validan `> 0` en el schema Pydantic (`Field(gt=0)`), igual que ya exige
`presentation_quantity` en la ruta de spec 107. **No** se endurece la validación de la
ruta directa pre-existente (`unit_cost: Decimal = Field(0, ge=0, ...)`, que hoy permite
costo 0): esta spec no pide ese cambio para compras que no usan el selector de unidad
nuevo, y tocarlo sería una modificación de comportamiento existente no autorizada
explícitamente por esta spec (Principio II) — si el negocio quiere ese endurecimiento
también para la ruta sin conversión, es una decisión de negocio a registrar aparte.

## D12. Frontend: dónde entra la UI

**Hallazgo**: `purchase-form.component.ts` (Angular) ya tiene un patrón idéntico para
presentaciones de proveedor (`presentationsFor`, `selectedPresentation`, vista previa de
equivalencia en texto). `unit-measure.service.ts` ya existe y alimenta el selector de
unidad en varias pantallas. `tenant-info.component.ts` (`modules/settings`) es la
pantalla de configuración del tenant existente, lugar natural para el toggle de FR-016.

**Decisión**: añadir, en cada fila de `purchase-form.component.ts`, un segundo selector
de unidad (poblado con `GET /unit-measures?dimension=...`) que coexiste con (pero es
mutuamente excluyente de) el selector de presentación de proveedor ya existente — mismo
patrón visual de vista previa de equivalencia (FR-014) ya usado para presentaciones. El
toggle de `unit_conversion_enabled` se añade a `tenant-info.component.ts` junto a los
demás ajustes del negocio.

## Resumen de Contexto Técnico

- **Language/Version**: Python 3.11 (FastAPI) backend; TypeScript/Angular standalone
  components frontend — igual que el resto del proyecto, sin dependencias nuevas.
- **Primary Dependencies**: FastAPI, SQLAlchemy, Alembic, Pydantic v2 (backend);
  Angular, RxJS/Signals (frontend) — ninguna dependencia nueva requerida.
- **Storage**: PostgreSQL 16, schema-per-tenant (`tenant` para datos de negocio,
  `shared` para `tenants`/`users`).
- **Testing**: `pytest`/`unittest` (characterization tests + tests de la funcionalidad)
  en backend; suite existente del frontend (ver nota de memoria: baseline es flaky,
  comparar por archivo, no por conteo total).
- **Target Platform**: Linux server (API), navegador (Angular SPA).
- **Project Type**: Web application (backend + frontend, dos repos).
- **Performance Goals**: sin metas nuevas; reutiliza el motor de stock ya existente
  (`with_for_update`), sin añadir N+1 ni locks adicionales.
- **Constraints**: 6 decimales de precisión para cantidad/costo en unidad base
  (clarificación de la spec); ningún recálculo retroactivo de facturas o compras ya
  confirmadas (Principio VII); aislamiento estricto por tenant (Principio existente,
  FR-017).
- **Scale/Scope**: cambio acotado a los módulos de inventario/compras/catálogo de
  unidades; no toca ventas, caja, ni facturación.
