# Research: Trazabilidad de kardex en la importación masiva de Excel de inventario

Todas las "NEEDS CLARIFICATION" del Technical Context se resuelven aquí inspeccionando el
código real de `pos-backend`/`pos-heladeria`. No queda ninguna pendiente.

## D1: Punto de inserción — `validar_y_aplicar_fila()`, no `resolve_or_create_by_code()`

- **Decision**: el cambio se hace íntegramente dentro de `validar_y_aplicar_fila()`
  (`app/api/v1/inventory/import_.py:394-439`): se deja de incluir `current_stock` en el
  diccionario `campos` que se pasa a `resolve_or_create_by_code()`
  (`app/api/v1/inventory/service.py:124-160`), y el movimiento de stock se aplica por
  separado, después de que esa función resuelve el resto de los campos (`name`, `type`,
  `min_stock`, `unit_cost`, `unit_measure_id`).
- **Rationale**: `resolve_or_create_by_code()` es un *upsert genérico por código* —
  "si `code` coincide, actualiza con `fields`; si no, crea" — sin ninguna noción de kardex,
  stock inicial ni motivos. Su docstring afirma que la usa tanto el alta manual (`router.py`)
  como la importación masiva (`import_.py`), pero una búsqueda de todos sus llamadores
  (`grep -rn resolve_or_create_by_code app/`) confirma que **hoy solo la llama
  `import_.py:433`** — el alta manual (`POST /inventory/items`, `router.py:270`) construye su
  propio `InventoryItem(current_stock=body.current_stock, ...)` directo, sin pasar por esta
  función. Aun así, modificar `resolve_or_create_by_code()` para que "nunca escriba
  `current_stock`" la convertiría en una función con una regla de negocio específica de
  import incrustada en un módulo de propósito general, arriesgando que un futuro caller
  (p. ej. un alta manual que decida reutilizarla) herede silenciosamente ese comportamiento
  sin pedirlo. Mantener la exclusión de `current_stock` en el propio `campos` que construye
  `validar_y_aplicar_fila()` — la función que ya es, desde spec 109, la dueña exclusiva de
  decidir qué le pasa a cada fila — es el cambio más acotado posible (Principio V).
- **Alternatives considered**:
  - Modificar `resolve_or_create_by_code()` para que excluya `current_stock` internamente —
    rechazada por lo anterior: acopla una regla de negocio de import a una función genérica
    de upsert, sin beneficio (ya que import es su único caller real hoy).
  - Envolver `resolve_or_create_by_code()` con un wrapper nuevo en `import_.py` — rechazada:
    una función de una sola responsabilidad (quitar una clave de un dict antes de llamar) no
    necesita su propia función; inline en `validar_y_aplicar_fila()` es más simple.

## D2: Motivo y referencia nuevos — extender `app/core/inventory_reasons.py`

- **Decision**: agregar dos constantes nuevas junto a las seis/cinco ya existentes:
  `IMPORTACION_MASIVA = "importacion_masiva"` (motivo) y `REF_IMPORT_JOB = "import_job"`
  (referencia), e incluir `IMPORTACION_MASIVA` en `ENTRADA_REASONS` (nunca en
  `SALIDA_REASONS`), consistente con FR-007 ("restringido a movimientos `in`/`ajuste`, nunca
  `out`").
- **Rationale**: es exactamente el mismo patrón que ya usan `COMPRA`/`REF_PURCHASE` — un
  motivo nuevo para un movimiento `in`/`ajuste`, y una referencia nueva (tipo + id) que apunta
  a la entidad que originó el movimiento (`InventoryImportJob`, spec 109), sin requerir
  `CheckConstraint` en BD (`inventory_movements.reason`/`reference_type` son texto libre por
  diseño, RN-INV-12). `ENTRADA_REASONS`/`SALIDA_REASONS` no son una constraint de BD —son
  "para validar en la capa de API cuando el motivo lo elige el usuario" (docstring del
  módulo); el motivo de esta spec lo fija el sistema, no un usuario a través del endpoint de
  ajuste manual (`POST /inventory/items/{id}/adjust`), pero se agrega igual a
  `ENTRADA_REASONS` porque FR-007 exige explícitamente que el catálogo completo refleje la
  restricción de dirección, y porque el characterization test
  (`test_core_inventory_reasons.py`) ya verifica el contenido exacto de ambas tuplas.
- **Alternatives considered**:
  - Reutilizar el motivo `AJUSTE` ya existente en vez de crear `IMPORTACION_MASIVA` —
    rechazada explícitamente por la decisión de negocio A-165 ("eligiendo el motivo nuevo
    para distinguir en reportes el origen de estos movimientos").
  - Usar un `reference_type` genérico ya existente (p. ej. reutilizar `REF_PURCHASE`) —
    rechazada: el origen real es un `InventoryImportJob`, no una `Purchase`; mezclar ambos
    tipos de origen bajo la misma etiqueta rompería la agregación por origen que el propio
    módulo dice perseguir ("movimientos agregables por motivo/origen en reportes").

## D3: `apply_adjustment()` necesita `reference_type`/`reference_id`

- **Decision**: extender `apply_adjustment()` (`app/inventory_engine/stock.py:109-139`) con
  dos parámetros opcionales nuevos, `reference_type: Optional[str] = None` y
  `reference_id: Optional[UUID] = None`, que se pasan directo al `InventoryMovement`
  construido (igual que ya hace `record_movement()` con los mismos nombres de parámetro).
  Todos los callers existentes (p. ej. `POST /inventory/items/{id}/adjust`) siguen sin pasar
  estos parámetros y por tanto no cambian su comportamiento observable (ambos quedan `None`,
  como ya ocurre hoy).
- **Rationale**: FR-004 exige que el ajuste generado por esta spec quede "referenciado al job
  de importación", y hoy `apply_adjustment()` no tiene forma de llevar esa referencia —
  `record_movement()` sí la tiene desde que existe (usada por `COMPRA`/`REF_PURCHASE`,
  spec 005/163), pero el ajuste manual (`AJUSTE`) nunca necesitó una hasta ahora porque no
  tenía un origen distinto del propio usuario. Espejar la firma de `record_movement()` es la
  extensión mínima y más consistente con el resto del motor de stock (ver Complexity
  Tracking en plan.md).
- **Alternatives considered**: ver tabla de Complexity Tracking en plan.md (asignar los
  campos a mano sobre el `InventoryMovement` ya creado, fuera de la función) — rechazada por
  duplicar responsabilidad que la función ya tiene para `record_movement()`.

## D4: Rechazo de fila cuando el ajuste dejaría stock negativo (US3/FR-006)

- **Decision**: no se agrega ninguna validación nueva de "stock resultante negativo" en
  `import_.py` — se reutiliza la que `apply_adjustment()` ya ejecuta
  (`stock.py:124-128`: calcula `new_stock` y lanza `InsufficientStockError` si es negativo,
  sin aceptar `allow_negative` como sí hace `record_movement()`). `validar_y_aplicar_fila()`
  envuelve la llamada en el mismo patrón `try/except HTTPException` que ya usa para
  `_apply_preferred_supplier()` (`import_.py:387-391`), convirtiendo la excepción en el
  `{ok: False, motivo: str(detail)}` que el resto de la función ya sabe reportar como fila
  fallida.
- **Rationale**: `InsufficientStockError` es una `HTTPException` (`app/core/exceptions.py:12`),
  no una `ValueError` — el `except ValueError` que ya envuelve todo el cuerpo de
  `validar_y_aplicar_fila()` (línea 437) no la captura por sí solo; hace falta agregar
  `except HTTPException` (o ampliar a `except (ValueError, HTTPException)`) exactamente como
  ya se hizo para `_apply_preferred_supplier()`. Esto evita reimplementar la regla de "nunca
  negativo" en dos lugares: la única fuente de verdad sigue siendo `apply_adjustment()`
  (spec 005), igual que exige Principio V (sin refactors/duplicación).
- **Alternatives considered**: calcular el stock resultante en `import_.py` antes de llamar
  a `apply_adjustment()` y rechazar la fila sin llamarla — rechazada: duplicaría la misma
  comprobación (`new_stock < 0`) que `apply_adjustment()` ya hace bajo el lock de fila
  (`with_for_update()`), introduciendo una ventana de carrera entre la comprobación manual y
  el lock real si dos filas de dos jobs concurrentes tocaran el mismo insumo.

## D5: Creación — stock inicial vía `record_movement`, no vía el constructor

- **Decision**: cuando `code` no coincide con ningún insumo existente (`creado=True`), el
  `InventoryItem` se sigue creando con `resolve_or_create_by_code()`, pero **sin**
  `current_stock` en `campos` (nace con el default `0` del modelo); inmediatamente después,
  si el valor de Stock de la fila es mayor a `0`, se llama
  `record_movement(db, item.id, type="in", quantity=stock, reason=reasons.IMPORTACION_MASIVA,
  reference_type=reasons.REF_IMPORT_JOB, reference_id=job.id)`. Si Stock es `0`, no se llama
  nada (FR-002).
- **Rationale**: evita el doble-conteo que resultaría de fijar `current_stock=stock` en el
  constructor **y además** sumarle `stock` vía `record_movement` — la única fuente de verdad
  del valor final de `current_stock` pasa a ser siempre `record_movement`/`apply_adjustment`,
  nunca un valor inicial del constructor combinado con un movimiento. Como el valor de Stock
  en el Excel ya se valida como no-negativo en `_parse_decimal()` (`import_.py:128-129`,
  validación preexistente de spec 109, sin cambios), la creación nunca puede producir un
  ajuste negativo — solo aplica la regla "sin movimiento si es cero" (FR-002), no la regla de
  rechazo por negativo (esa es exclusiva de la actualización, D4/D6).
- **Alternatives considered**: mantener `current_stock=stock` en el constructor y llamar a
  `record_movement` solo para "dejar rastro" sin que afecte el stock — no es posible:
  `record_movement()` siempre suma/resta a `current_stock` como parte de su contrato
  (spec 005); no existe un modo "solo bitácora" y crearlo violaría Principio V.

## D6: Actualización — delta entre Stock del Excel y `current_stock` previo

- **Decision**: antes de llamar a `resolve_or_create_by_code()`, se captura
  `stock_antes = existente.current_stock` del insumo ya resuelto por código
  (`import_.py:420-422`, ya existente). `campos` sigue sin incluir `current_stock`. Tras
  `resolve_or_create_by_code()`, se calcula `delta = stock - stock_antes`; si `delta != 0`, se
  llama `apply_adjustment(db, item.id, signed_delta=delta, reason=reasons.IMPORTACION_MASIVA,
  reference_type=reasons.REF_IMPORT_JOB, reference_id=job.id)` (D3). Si `delta == 0`, no se
  llama nada (FR-005).
- **Rationale**: implementa FR-003/FR-004 literalmente — "la diferencia entre el valor de
  Stock de la fila del Excel y el stock actual del insumo en el momento de procesar esa
  fila" es exactamente `stock - stock_antes`, leído justo antes de aplicar cualquier cambio a
  ese insumo en esta fila (coherente con el procesamiento fila-a-fila, cada una con su propio
  commit, ya vigente en spec 109 — D del Edge Case "reintento de importación interrumpida" del
  spec: si el ajuste ya se aplicó en un intento anterior, `stock_antes` en el reintento ya
  refleja ese ajuste, y `delta` vuelve a ser `0`).
- **Alternatives considered**: ninguna — es la lectura directa de FR-003/FR-004, ya acotada
  por D1 (dónde se inserta) y D3/D4 (cómo se aplica y se rechaza).

## D7: Costo — sin cambios (FR-009)

- **Decision**: `unit_cost` permanece en `campos` exactamente como hoy (sobrescritura directa,
  tanto en creación como en actualización); no se agrega ningún movimiento ni validación
  nueva relacionada con costo.
- **Rationale**: FR-009 lo fija explícitamente, y es el mismo patrón que spec 163 ya usa en
  `_build_purchase_order()` (`item.unit_cost = purchase_item.cost_base`, asignación directa,
  fuera de `record_movement`) — el costo es un atributo del insumo, no una cantidad de stock,
  y por tanto nunca pasa por el mecanismo de movimientos en ningún flujo del sistema.
- **Alternatives considered**: ninguna — explícitamente fuera de alcance por el propio spec.

## D8: Frontend (`pos-heladeria`) — sin cambios

- **Decision**: no se modifica ningún archivo de `pos-heladeria`.
- **Rationale**: la tabla de historial de movimientos
  (`src/app/modules/inventory/pages/inventory-page.component.ts`, pestaña "movements") ya
  renderiza `m.type` y `m.reason` como texto crudo (`{{ m.reason || '—' }}`), sin ningún
  diccionario de etiquetas que traducir — confirmado por búsqueda exhaustiva en el módulo
  `inventory` (el único `reasonLabel()` que existe en ese módulo mapea un enum no relacionado,
  `SuggestedPurchaseLineErrorReason`, de la pantalla de compra sugerida). El valor nuevo
  `"importacion_masiva"` aparecerá tal cual en la columna "Motivo"; `reference_type`/
  `reference_id` ya existen en la interfaz `InventoryMovement` del frontend pero no se
  renderizan hoy, así que agregar `"import_job"` no requiere ningún cambio para evitar un
  valor roto o sin mapear.
- **Alternatives considered**: agregar una etiqueta legible ("Importación masiva de Excel")
  para el nuevo motivo — fuera de alcance de este spec (sería una mejora de UX nueva, no una
  corrección de la laguna de trazabilidad que esta spec cierra); se puede proponer como spec
  independiente si el negocio lo pide.

## D9: Verificación — extender los dos archivos de test existentes, sin crear ninguno nuevo

- **Decision**: (a) `app/characterization_tests/test_core_inventory_reasons.py` se actualiza
  —prefijo `CONGELA`, protegido por Principio III— para reflejar siete motivos canónicos y el
  nuevo `REF_IMPORT_JOB`, citando A-165 en el commit; (b)
  `app/scripts/test_inventory_bulk_excel.py` (ya corre contra Postgres real, ya crea/limpia
  un `InventoryImportJob` de prueba) se extiende con casos nuevos para cada Acceptance
  Scenario de los tres User Stories del spec.
- **Rationale**: no hay pytest en este repo (confirmado: no existe `pytest.ini`/configuración
  de pytest ni `conftest.py`); el proyecto usa `unittest` sobre SQLite en memoria para
  comportamiento unitario/de catálogo, y scripts ejecutables contra Postgres real para flujos
  de integración que dependen de constraints que SQLite no reproduce fielmente (el propio
  docstring de `test_inventory_bulk_excel.py` ya documenta por qué necesita Postgres real:
  spec 109, constraint `group_id NOT NULL`). El nuevo comportamiento de esta spec (creación de
  `InventoryMovement`, lectura de `current_stock` bajo lock, rechazo por `InsufficientStockError`)
  es exactamente del tipo de integración que ese script ya cubre para el resto del flujo de
  import — extenderlo es más consistente que introducir un framework de test nuevo.
- **Alternatives considered**: escribir un characterization test nuevo con SQLite para los
  casos de esta spec — rechazada: el motor de stock (`record_movement`/`apply_adjustment`) ya
  tiene su propio characterization test (`test_inventory_stock.py`); lo que esta spec agrega
  no es comportamiento nuevo de ese motor, sino un caller nuevo que lo invoca desde el import,
  y ese caller ya se verifica end-to-end en el script de Postgres real.
