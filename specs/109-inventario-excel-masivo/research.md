# Research: Exportación e Importación Masiva de Inventario en Excel

No hay `NEEDS CLARIFICATION` en el Technical Context del plan — las dos preguntas que quedaban
abiertas tras `/speckit-clarify` (escala, interrupción a mitad de proceso) ya están resueltas en
el spec. Lo que queda aquí son las decisiones de diseño que el plan necesitaba para no inventar
infraestructura nueva donde ya existe una equivalente.

## D1 — Mecanismo de segundo plano: reutilizar Celery, no introducir nada nuevo

**Decisión**: el import corre en una tarea Celery nueva (`import_inventory_task`), despachada
desde el endpoint `POST /items/import` después de validar la estructura del archivo (FR-005,
síncrono). Celery ya está configurado en el proyecto (`app/celery_task.py`, `broker_url`/
`result_backend` sobre el mismo Redis que ya corre) — hoy solo lo usa `send_email_task`.

**Rationale**: Principio IX exige justificar cualquier dependencia nueva y preferir lo que ya
existe. El ticket original pedía BullMQ (Node) — no aplica a este stack Python. Celery ya cubre
exactamente lo que FR-009 pide (encolar y responder sin bloquear), sin añadir ni un paquete nuevo
ni un segundo broker.

**Alternatives considered**:
- *FastAPI `BackgroundTasks`*: rechazada — corre en el mismo proceso/worker que atiende requests;
  un import de varias filas con validaciones por fila competiría por el mismo event loop que el
  resto de la aplicación, justo lo que FR-009 quiere evitar.
- *APScheduler* (ya usado para el barrido de sesiones): rechazada — está pensado para tareas
  periódicas programadas, no para encolar un trabajo puntual disparado por el usuario.

## D2 — Dónde vive el resultado del import: una tabla propia, no el result backend de Celery

**Decisión**: se crea `inventory_import_jobs` (una fila por import, en el esquema del tenant) con
su estado y, al finalizar, los conteos y el detalle de filas fallidas (ver `data-model.md`). La
tarea Celery escribe en esta tabla a medida que procesa, no depende de que alguien llame
`AsyncResult.get()` después.

**Rationale**: aunque Celery ya tiene un `result_backend` (Redis) configurado, apoyarse en él para
esto tiene tres problemas concretos para esta spec: (1) `result_expires` tiene un TTL — el
resultado puede desaparecer antes de que el administrador vuelva a mirar (Historia 3, escenario
2: "cierra y vuelve a abrir... encuentra el resultado"); (2) no es consultable "¿hay un import en
curso para este tenant?" sin guardar el id de la tarea en otro lado — y FR-010 necesita
exactamente esa consulta; (3) el resto del sistema ya persiste todo su estado de negocio en
Postgres por tenant (`CashShift`, `OrderPaymentAttempt`, etc.) — depender del backend de Celery
para esto sería el único lugar que rompe ese patrón.

**Alternatives considered**:
- *Solo Celery `AsyncResult`, guardando el task_id en el navegador (localStorage)*: rechazada —
  no sobrevive un cambio de dispositivo/navegador, y no resuelve la consulta "¿hay uno en curso?"
  de FR-010 sin otro mecanismo encima.

## D3 — El identificador "código": columna nueva, generada automáticamente, editable

**Decisión**: `InventoryItem` gana una columna `code: str`, única por tenant (mismo patrón de
restricción que ya tiene `name`, sin un `tenant_id` explícito porque el esquema ya separa cada
tenant). Se genera automáticamente como un número secuencial con cero a la izquierda (`"0001"`,
`"0002"`, ...) cuando no se especifica uno — tanto en el backfill de insumos existentes (FR-003)
como al crear un insumo nuevo sin indicarlo. El administrador puede sobreescribirlo con un valor
propio, siempre que sea único.

**Rationale**: resuelve la pregunta ya decidida con el usuario en `/speckit-specify` (agregar un
campo nuevo en vez de usar el UUID o el nombre). Un secuencial simple no necesita infraestructura
nueva (no hace falta una secuencia de Postgres dedicada: a la escala acordada, ≈500 filas,
`MAX(code numérico) + 1` por tenant es suficiente y no es una ruta caliente de concurrencia como sí
lo es, por ejemplo, el consecutivo de facturación).

**Alternatives considered**:
- *UUID visible como código*: ya descartada en el spec (ilegible para edición manual).
- *Prefijo + secuencial (ej. `"INS-0001"`)*: rechazada por ahora — no aporta nada funcional sobre
  un secuencial simple y alarga cada celda sin necesidad; el administrador que quiera un esquema
  propio ya puede sobreescribirlo.

## D4 — Datos del proveedor preferido en la plantilla: un helper batch nuevo, no un join ad-hoc

**Decisión**: se agrega a `supplier_items.py` un helper batch (análogo a
`attach_preferred_supplier_names`, spec 106) que trae presentación, factor de conversión y último
costo pagado de la relación preferida de cada insumo, en una sola consulta para todo el lote.
`export.py` lo usa para llenar las columnas nuevas; igual helper puede alimentar el detalle de
insumo si en el futuro se decide mostrar esos datos ahí (fuera de alcance de esta spec, pero sin
que el diseño lo impida).

**Rationale**: `attach_preferred_supplier_names` ya resuelve exactamente este problema para el
nombre del proveedor — repetir el mismo patrón para los 3 campos adicionales es consistente y
evita N+1 consultas (una por insumo) al exportar hasta 500 filas.

**Alternatives considered**:
- *Extender `attach_preferred_supplier_names` para que también traiga estos 3 campos*: considerada
  y preferible solo si el llamador del detalle de insumo también necesitara esos campos hoy — no
  los necesita (su `InventoryItemResponse` solo expone `preferred_supplier_name`), así que
  mezclarlos ahí sería cambiar un contrato de respuesta que esta spec no toca. Un helper nuevo,
  usado solo por `export.py`, mantiene ese contrato intacto.

## D5 — Un import a la vez por tenant: consulta a la tabla propia, con vencimiento por tiempo

**Decisión**: antes de encolar una tarea nueva, el endpoint consulta si existe una fila en
`inventory_import_jobs` con estado "procesando" para ese tenant. Si existe y lleva menos de un
tiempo límite razonable (ej. 30 minutos — muy por encima de lo que toma procesar ≈500 filas), se
rechaza la nueva importación (FR-010). Si existe pero ya superó ese tiempo límite, se considera
abandonada (el worker murió sin actualizar su estado) y se permite la nueva importación, dejando
la anterior marcada como interrumpida.

**Rationale**: FR-015 (Clarifications) ya estableció que una interrupción a mitad de camino no
revierte nada y el administrador puede reintentar resubiendo el archivo — pero sin este
vencimiento, una fila que se quedó "procesando" por una caída del worker bloquearía FR-010 para
siempre, porque nada la marcaría como terminada. Un tiempo límite simple resuelve esto sin
necesitar un mecanismo de heartbeat/salud del worker, que ninguna otra parte de esta spec
necesita.

**Alternatives considered**:
- *Heartbeat explícito del worker (actualiza un `updated_at` cada N segundos mientras procesa)*:
  rechazada por ahora — añade una pieza de sincronización nueva para un caso límite poco
  frecuente (el worker cayéndose a mitad de un archivo de ≈500 filas que toma segundos); un
  vencimiento fijo es suficiente y más simple (Principio IX).

## D6 — Export y import comparten la misma definición de columnas, en un solo lugar

**Decisión**: la lista de columnas (nombre de cabecera, orden, de dónde sale/a dónde va cada una)
vive en un solo lugar en `schemas.py`, y tanto `export.py` como `import_.py` la importan — ninguno
de los dos la repite con su propia lista literal.

**Rationale**: es literalmente el requisito central de la Historia 1 (FR-001) — la única forma de
garantizar que export e import nunca se desincronicen es que no existan dos definiciones de la
misma plantilla.

**Alternatives considered**: ninguna — cualquier alternativa (dos listas de cabeceras mantenidas
"a mano" en sincronía) es exactamente el problema que esta spec existe para resolver.

## D7 — Unidad/Proveedor que no existen: se consolidan (crean), no fallan la fila

**Decisión** (ajuste pedido por el usuario tras probar la primera versión): una fila cuya columna
Unidad o Proveedor preferido no coincide con ningún registro existente del tenant ya **no se
reporta como fallida** — se consolida creando el registro que falte. La búsqueda es siempre
insensible a mayúsculas/minúsculas (`UPPER(...)`), y lo que se crea se guarda siempre en
MAYÚSCULA, sin importar cómo venía escrito en el Excel. Si la búsqueda insensible a mayúsculas
encuentra un proveedor existente pero inactivo, se reactiva en vez de crear un duplicado
(`Supplier.name` no tiene restricción de unicidad en el modelo, así que sin este cuidado se
acumularían filas repetidas con el mismo nombre en distinto estado). Sigue siendo una fila fallida
si la búsqueda insensible a mayúsculas encuentra **más de una** coincidencia (dato ambiguo
preexistente que el administrador debe resolver a mano, no algo que el import deba decidir por
su cuenta).

**Rationale**: el primer diseño (data-model.md original) trataba "la unidad/proveedor no existe"
como un error de datos a corregir manualmente antes de reimportar — consistente con un import que
solo actualiza, pero en la práctica vuelve mucho más fricción el caso común de agregar insumos
con una unidad o un proveedor nuevo que todavía no se ha dado de alta por separado. El usuario
probó la primera versión y pidió explícitamente que se consolidara en vez de fallar. La
normalización a mayúscula evita que "kg", "Kg" y "KG" terminen como tres unidades distintas
creadas por error de tipeo entre archivos distintos — exactamente el problema que "consolidar"
busca resolver.

**Alternatives considered**:
- *Mantener la falla, pero con un mensaje más claro*: rechazada — es literalmente lo contrario de
  lo que el usuario pidió (consolidar, no seguir fallando).
- *Case-sensitive estricto (que "kg" y "KG" sean dos unidades distintas)*: rechazada — el usuario
  pidió explícitamente lo opuesto: comparar y guardar siempre en mayúscula.
- *Crear siempre, sin buscar coincidencia insensible a mayúsculas primero*: rechazada — crearía un
  duplicado cada vez que el Excel trajera una variación de caso de algo que ya existe,
  exactamente el problema que la normalización evita.

**Impacto en el contrato documentado**: esto reemplaza, en `data-model.md` → "Reglas de
validación del import", las dos reglas que antes decían "si no existe, fila fallida" para Unidad
y Proveedor preferido. No se registra como entrada nueva en
`specs/000-reconocimiento/registro-de-anomalias.md` porque no es un cambio sobre un comportamiento
ya enviado a producción — es un ajuste dentro de la primera implementación de esta misma spec 109,
antes de que exista ningún release con el comportamiento anterior.
