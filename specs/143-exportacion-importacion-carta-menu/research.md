# Research: Exportación e importación masiva de la carta en Excel

No hay `NEEDS CLARIFICATION` en el Technical Context del plan — las cuatro preguntas que quedaron
abiertas tras `/speckit-specify` (naturaleza del código de referencia, política ante filas
ausentes, imports concurrentes, permisos) ya están resueltas en las Clarifications del spec. Lo
que queda aquí son las decisiones de diseño que el plan necesitaba para adaptar el patrón ya
validado por la spec 109 (inventario) a un archivo de 4 hojas relacionadas en vez de una sola
tabla.

## D1 — El import no reutiliza `ProductService`: opera sobre los modelos directamente

**Decisión**: la validación/aplicación de cada fila (en `app/api/v1/products/import_.py`) trabaja
directamente con `Product`, `ProductVariant`, `RecipeItem` y `ProductTopping` vía SQLAlchemy, sin
pasar por `ProductService.create_product`/`update_product`/`update_product_recipe`.

**Rationale**: `ProductService` guarda un producto **reemplazando por completo** su conjunto de
variantes/receta/grupos de opciones en cada operación de guardado desde la UI (research de
`catalog/service.py`: `_save_variant_entry`/`_assign_display_orders` recorren una lista completa
nueva, no un delta). Ese comportamiento es exactamente lo que FR-005a prohíbe para el import: una
presentación, ítem de receta o adición ausente del archivo **no debe eliminarse ni desactivarse**.
Reutilizar `ProductService` tal como está violaría FR-005a en la primera fila importada; adaptarlo
para aceptar un modo "solo agregar/actualizar" mezclaría dos semánticas de guardado distintas en el
mismo servicio que hoy sirve al formulario de producto. El mismo criterio ya aplicó en la spec 109:
el import de inventario no reutiliza `InventoryService.update_item` genérico, tiene su propio
`resolve_or_create_by_code`.

**Alternatives considered**:
- *Agregar un parámetro `merge_only: bool` a `ProductService`*: rechazada — introduce una rama de
  comportamiento condicional dentro de un servicio ya usado por el formulario interactivo, para un
  caso de uso (import por lote) que tiene requisitos de transaccionalidad distintos (commit por
  fila, no por producto completo); more simple mantenerlo separado (Principio V, Principio IX: sin
  necesidad no se complica lo existente).

## D2 — Mismo conjunto de endpoints que inventario, sin cancelación explícita

**Decisión**: se replican los 4 endpoints de inventario que el spec sí exige (exportar, subir
archivo, consultar job vigente, consultar job por id, descargar reporte de errores). No se agrega
un endpoint de cancelación explícita (`POST /items/import/{id}/cancel` en inventario) porque
ningún requisito funcional ni edge case de esta spec lo pide — el único control de concurrencia
exigido es FR-012a (bloquear un segundo import mientras uno está en curso), no permitir que el
administrador interrumpa el suyo a voluntad.

**Rationale**: Principio V (sin refactors/funcionalidad no solicitada) y Principio IX (no
complicar sin necesidad) — agregar cancelación sería copiar una pieza de la spec 109 que esta spec
no pidió. Si en el futuro se necesita, se agrega como su propia spec/tarea, igual que la
cancelación de inventario fue una extensión posterior y no parte del alcance original de la 109.

**Alternatives considered**:
- *Copiar el endpoint de cancelación "por si acaso"*: rechazada — es exactamente el tipo de
  funcionalidad no pedida por ningún FR/edge case que el Principio V prohíbe agregar de forma
  oportunista.

## D3 — El identificador "código de producto": mismo patrón que `InventoryItem.code` (spec 109)

**Decisión**: `Product` gana una columna `code: str`, única por tenant, generada automáticamente
como secuencial con cero a la izquierda (`"0001"`, `"0002"`, ...) cuando no se especifica, editable
por un administrador — exactamente el mismo diseño que `InventoryItem.code` (spec 109, D3).

**Rationale**: la Clarification del spec ya decidió "campo persistente, autogenerado por el
sistema y visible/editable en la UI administrativa del producto" — es el mismo contrato que
`InventoryItem.code` ya cumple hoy en producción. Reutilizar el mismo diseño (en vez de inventar
uno distinto, p. ej. UUID corto o prefijo por categoría) evita que el negocio tenga que aprender
dos convenciones de "código" diferentes entre inventario y carta.

**Alternatives considered**: las mismas que D3 de la spec 109 (UUID visible, prefijo+secuencial) —
rechazadas por la misma razón: no aportan nada funcional sobre un secuencial simple editable, y
romperían la consistencia con el único precedente que el negocio ya conoce.

## D4 — Orden de procesamiento de hojas: Productos → Presentaciones y precios → Receta → Adiciones

**Decisión**: la tarea Celery procesa las 4 hojas en ese orden fijo (ya explícito en FR-007), cada
una completa antes de pasar a la siguiente, dentro de la misma ejecución. Una fila de
Presentaciones puede referenciar un producto creado por una fila anterior de la hoja Productos del
mismo archivo; una fila de Receta puede referenciar una presentación creada por una fila anterior
de la hoja Presentaciones del mismo archivo; una fila de Adiciones puede referenciar un producto
creado en la hoja Productos del mismo archivo.

**Rationale**: es el requisito explícito de FR-007. Procesar las hojas en paralelo o en el orden en
que aparecen físicamente en el archivo (que un usuario podría reordenar al editarlo a mano)
rompería esa garantía — fijar el orden en el código, sin depender del orden físico de las hojas en
el `.xlsx`, es lo que hace posible que el archivo sea editable con hojas reordenadas sin que eso
cambie el resultado.

**Alternatives considered**:
- *Resolver referencias "hacia adelante" con una segunda pasada*: rechazada — más compleja que
  simplemente fijar el orden de procesamiento, sin necesidad real (el spec ya define un único orden
  de dependencia, no un grafo arbitrario).

## D5 — Resolución "buscar o crear" por nombre: Categoría y Presentación, sin normalizar a mayúscula

**Decisión**: al importar la hoja Productos, la columna Categoría se resuelve por nombre
insensible a mayúsculas/minúsculas contra `categories.name` del tenant; si no hay coincidencia, se
crea una categoría nueva **con el texto exactamente como viene en el archivo** (sin forzar
mayúscula), con sus demás campos en el valor por defecto del modelo (`active=true`,
`visible_en_qr=true`, `display_order` = siguiente disponible). Al importar la hoja Presentaciones y
precios, la columna Presentación se resuelve de la misma forma contra `presentations.name` del
tenant (mismo criterio ya declarado en las Assumptions del spec para este catálogo). Si la búsqueda
insensible a mayúsculas encuentra más de una coincidencia, la fila falla (dato ambiguo preexistente
que el administrador debe resolver a mano) — mismo criterio que D7 de la spec 109. Si encuentra una
coincidencia inactiva, se reactiva en vez de crear un duplicado.

**Rationale**: el Input del spec declara el criterio general ("resolución 'buscar o crear'
case-insensitive para entidades referenciadas por nombre al crear") y las Assumptions ya lo aplican
explícitamente a Presentación; Categoría es la única otra entidad de la hoja Productos referenciada
por nombre (no por código), así que se le aplica el mismo criterio por consistencia. La diferencia
deliberada con D7 de la spec 109 (que normaliza unidad/proveedor a MAYÚSCULA) es que **Categoría y
Presentación son datos visibles para el comensal** (nombre de categoría y de presentación/tamaño en
el menú y en el Menú QR) — forzar mayúscula cambiaría silenciosamente una etiqueta que el negocio ya
decidió mostrar con una capitalización específica (p. ej. "Postres", "Mediano"). Unidad de medida y
proveedor (spec 109) son datos de back-office, nunca mostrados al cliente final, por eso sí se
normalizan ahí sin ese riesgo.

**Alternatives considered**:
- *Normalizar a mayúscula igual que inventario*: rechazada por la razón de arriba — cambiaría
  presentación visible al cliente sin que el spec lo pida.
- *Fallar la fila si la categoría o la presentación no existen (no crear)*: rechazada — el Input
  del spec pide expresamente el criterio "buscar o crear" para entidades por nombre; tratarlas como
  error contradiría ese criterio general y haría el flujo de alta de producto nuevo con categoría
  nueva mucho más fricción de lo que el patrón de inventario ya resolvió para unidad/proveedor.

## D6 — Insumo (Receta) y producto-adición (Adiciones): resolución estricta, nunca "crear"

**Decisión**: a diferencia de Categoría/Presentación (D5), el insumo referenciado en la hoja Receta
se resuelve **solo si ya existe** en el inventario del tenant (por nombre o código, FR-008); si no
existe, la fila falla. El producto referenciado como adición en la hoja Adiciones se resuelve
**solo por código** contra productos ya existentes (creados en esta misma importación por la hoja
Productos, o ya existentes antes); si el código no existe, o existe pero `is_topping=false`, o es
el mismo código que el producto que lo ofrece, la fila falla (FR-009, edge cases).

**Rationale**: son exactamente las reglas que el spec ya fija explícitamente (FR-008, FR-009, y los
edge cases de insumo/adición inexistente) — a diferencia de Categoría/Presentación, donde el spec
no fija una regla propia y aplica el criterio general de "buscar o crear". Las Assumptions del
spec además aclaran explícitamente que esta funcionalidad "no crea insumos nuevos (se reutiliza el
flujo de importación de inventario ya existente para eso)".

**Alternatives considered**: ninguna — el spec ya decide esto explícitamente, no hay ambigüedad que
resolver en el plan.

## D7 — Un import de carta a la vez por tenant: misma estrategia de vencimiento que inventario (D5, spec 109)

**Decisión**: antes de encolar una tarea nueva, el endpoint consulta si existe una fila en
`product_import_jobs` con estado `procesando` para ese tenant (FR-012a). Si existe y lleva menos de
un tiempo límite razonable (mismo valor ya usado por inventario, `IMPORT_JOB_TIMEOUT`), se rechaza
la nueva importación. Si ya superó ese tiempo, se considera abandonada y se permite la nueva,
dejando la anterior marcada como `interrumpido`.

**Rationale**: es exactamente D5 de la spec 109, aplicada sin cambios al nuevo dominio — mismo
problema (un worker caído deja una fila `procesando` para siempre sin este vencimiento), misma
solución ya probada en producción. No hay ninguna razón específica de la carta para diseñar un
mecanismo distinto.

**Alternatives considered**: las mismas que D5 de la spec 109 (heartbeat explícito del worker) —
rechazadas por la misma razón (complejidad innecesaria para un caso límite poco frecuente).

## D8 — Export y import comparten la misma definición de columnas por hoja, en un solo lugar

**Decisión**: la lista de columnas de cada una de las 4 hojas (nombre de cabecera, orden, de dónde
sale/a dónde va cada una) vive en un solo lugar en `app/api/v1/products/schemas.py`
(`PRODUCT_TEMPLATE_HEADERS`, `VARIANT_TEMPLATE_HEADERS`, `RECIPE_TEMPLATE_HEADERS`,
`TOPPING_TEMPLATE_HEADERS`), y tanto `export.py` como `import_.py` las importan — ninguno repite su
propia lista literal.

**Rationale**: mismo razonamiento que D6 de la spec 109 — es el requisito central de la Historia 1
(FR-001/FR-002): la única forma de garantizar que export e import nunca se desincronicen (en
cualquiera de las 4 hojas) es que no existan dos definiciones de la misma plantilla.

**Alternatives considered**: ninguna — cualquier alternativa (listas de cabeceras mantenidas "a
mano" en sincronía, para cada una de las 4 hojas) es exactamente el problema que esta decisión
evita.
