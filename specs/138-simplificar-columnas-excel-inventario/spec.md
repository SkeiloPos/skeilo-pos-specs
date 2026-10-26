# Feature Specification: Simplificar columnas de proveedor en Excel de inventario y vincular unidad a unidades de medida reales

**Feature Branch**: `138-simplificar-columnas-excel-inventario`

**Created**: 2026-10-26

**Status**: Draft

**Input**: User description: "cuando se importa y exporta los datos del inventario, se incluyen
tres columnas que llena la ciertos campos en la base de datos, presentacion, factor de
conversion, y ultimo costo, debido a la ultima implementacion de las unidades de medida, quiero
remover esas columnas del excel, porque no tiene sentido, que se modifiquen, eso lo hace el
administrador en su respectivo modulo, lo que si quiero, es que en la unidad que tiene cada uno de
los producto, esta se siga relacionando con las unidades de medida existentes, y si no existen
entonces las crea en la tabla."

## Aclaraciones previas (resueltas antes de escribir esta spec)

Antes de redactar, se resolvieron 2 decisiones con el solicitante (no quedan como
`[NEEDS CLARIFICATION]`):

1. **Unidad de medida nueva creada por una fila de importación**: cuando el texto de unidad de
   una fila no coincide con ninguna unidad de medida existente del negocio, se crea como grupo
   propio nuevo, siendo ella misma la unidad base de ese grupo (factor 1) — ver FR-006 y Edge
   Cases.
2. **Fila de actualización con unidad distinta a la del insumo existente**: la columna unidad
   **solo se usa al crear un insumo nuevo**; en una fila que actualiza un insumo ya existente, el
   valor de unidad se ignora aunque venga distinto al que el insumo tiene hoy — ver FR-007.

**Correcciones post-implementación (2026-10-26)**:

1. Una primera redacción de esta spec (y su implementación inicial) removió por error también la
   columna `Proveedor preferido` -- el pedido original del solicitante (ver "Input" arriba) solo
   menciona presentación, factor de conversión y último costo. El solicitante confirmó que el
   nombre del proveedor preferido SÍ debe seguir exportándose e importándose; se corrigió
   FR-001/FR-002/FR-004 y se agregó FR-010.
2. Segunda corrección: el solicitante aclaró que, si el proveedor nombrado en esa columna no
   existe todavía, SÍ debe crearse (mismo criterio ya vigente para proveedores desde antes de
   esta spec) — no solo vincular uno ya existente. Como la plantilla ya no trae presentación ni
   factor de conversión, la relación proveedor-insumo que se crea en ese caso queda con esos dos
   campos en `NULL` (el solicitante aceptó explícitamente este estado intermedio, a completar
   desde el módulo de proveedores o a resolver en una spec futura) — ver FR-011/FR-012 y
   `data-model.md` (requiere volver nullable `supplier_items.presentation`/`conversion_factor`,
   migración `c5815ab62693`).

## Relación con specs existentes

Esta spec modifica el contrato de columnas y dos reglas de negocio de la plantilla única de
exportación/importación de inventario definida en la spec 109
(`109-inventario-excel-masivo`), a raíz de la formalización de las unidades de medida como
entidad propia (grupo, unidad base, factor de conversión) introducida por la spec 137
(`137-rediseno-ajustes`). No reemplaza la spec 109: todos sus requisitos siguen vigentes salvo los
puntos que esta spec ajusta explícitamente (columnas de proveedor preferido y comportamiento de
la columna unidad al actualizar).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Exportar e importar sin presentación, factor de conversión ni último costo del proveedor preferido (Priority: P1)

Como administrador, quiero que el archivo de Excel de inventario ya no incluya las columnas de
presentación, factor de conversión y último costo pagado al proveedor preferido, porque esos
datos los administro exclusivamente desde el módulo de proveedores y no tiene sentido que alguien
pueda alterarlos de forma masiva ni accidental desde una hoja de cálculo de inventario. La columna
con el nombre del proveedor preferido en sí **se conserva** -- ver FR-010/FR-011/FR-012: a
diferencia de los otros tres campos, sí quiero poder ver e importar cuál es el proveedor
preferido de cada insumo, y que el proveedor se cree si no existe todavía (igual que ya sucede
hoy desde antes de esta spec).

**Why this priority**: es el cambio que el administrador pidió explícitamente — hoy esas tres
columnas generan confusión y riesgo de modificar por error datos que pertenecen a otro módulo.

**Independent Test**: puede probarse exportando el inventario y confirmando que el archivo
resultante ya no trae las columnas de presentación, factor de conversión ni último costo del
proveedor preferido (pero sí su nombre), y que importar ese mismo archivo (editado o no) no
requiere ni acepta esas tres columnas.

**Acceptance Scenarios**:

1. **Given** el administrador solicita la exportación de inventario, **When** el sistema genera
   el archivo, **Then** el archivo no incluye columnas de presentación, factor de conversión ni
   último costo pagado al proveedor preferido, pero sí incluye el nombre del proveedor preferido
   (en blanco si el insumo no tiene uno asignado).
2. **Given** un archivo de importación que sí incluye alguna de esas tres columnas (por ejemplo,
   un archivo exportado antes de este cambio), **When** se sube para importar, **Then** el
   sistema ignora esas columnas sin rechazar el archivo por tenerlas de más, y procesa el resto de
   columnas con normalidad.
3. **Given** los datos de presentación, factor de conversión o último costo del proveedor
   preferido de un insumo, **When** se importa cualquier archivo de inventario, **Then** esos
   datos nunca se crean, modifican ni eliminan como resultado de la importación — solo son
   editables desde el módulo de proveedores.
4. **Given** un insumo con una relación proveedor-insumo activa ya creada desde el módulo de
   proveedores (con su presentación y factor ya definidos) que hoy no es la preferida, **When**
   se importa una fila que actualiza ese insumo con el nombre de ese proveedor en la columna
   Proveedor preferido, **Then** esa relación queda marcada como la preferida del insumo, sin
   crear ni modificar su presentación/factor/último costo.
5. **Given** una fila con un nombre en la columna Proveedor preferido que no coincide con ningún
   proveedor existente, **When** se procesa, **Then** el sistema crea el proveedor (igual que ya
   hace hoy con nombres de proveedor desconocidos en otros flujos) y crea una relación
   proveedor-insumo nueva marcada como preferida, con presentación y factor de conversión en
   blanco (la plantilla ya no los trae) -- a completar después desde el módulo de proveedores.
6. **Given** una fila con un nombre en la columna Proveedor preferido que coincide, sin distinguir
   mayúsculas/minúsculas, con más de un proveedor existente, o cuyo proveedor resuelto tiene más
   de una relación activa con este insumo, **When** se procesa, **Then** la fila se reporta como
   fallida por ambigüedad; el resto de campos de esa fila tampoco se aplica.

---

### User Story 2 - La unidad del producto se vincula a una unidad de medida real al crear un insumo nuevo (Priority: P1)

Como administrador, cuando importo insumos nuevos quiero poder seguir indicando la unidad de cada
uno en la columna correspondiente, y que el sistema la vincule a una unidad de medida ya existente
del negocio (comparando sin distinguir mayúsculas/minúsculas) o, si no existe ninguna con ese
nombre, la cree automáticamente en la tabla de unidades de medida, para no tener que ir primero a
Ajustes a crear manualmente cada unidad antes de poder importar mis insumos.

**Why this priority**: junto con la Historia 1 es el núcleo del cambio solicitado — sin esto, la
columna unidad dejaría de tener efecto útil al crear insumos nuevos por Excel.

**Independent Test**: puede probarse importando un archivo con insumos nuevos cuyas unidades
incluyen nombres que ya existen como unidades de medida del negocio y nombres que no existen
todavía, y verificando que los insumos quedan creados con la unidad correcta vinculada, y que las
unidades nuevas aparecen en la tabla de unidades de medida del negocio (visibles luego en
Ajustes) sin duplicar las que ya existían por una diferencia de mayúsculas/minúsculas.

**Acceptance Scenarios**:

1. **Given** el negocio ya tiene la unidad de medida "KG" (grupo "Masa"), **When** se importa un
   insumo nuevo con la unidad escrita como "kg", **Then** el insumo queda creado usando la unidad
   de medida "KG" existente, sin crear una unidad duplicada.
2. **Given** el negocio no tiene ninguna unidad de medida llamada "Galón", **When** se importa un
   insumo nuevo con unidad "Galón", **Then** el sistema crea una unidad de medida nueva llamada
   "Galón", en su propio grupo nuevo, marcada como la unidad base de ese grupo (factor de
   conversión 1), y el insumo queda creado usando esa unidad.
3. **Given** una fila de importación que crea un insumo nuevo sin ningún valor en la columna
   unidad, **When** se procesa, **Then** la fila se reporta como fallida por campo obligatorio
   faltante, igual que hoy para cualquier otro campo requerido vacío.

---

### User Story 3 - La unidad de una fila de actualización no cambia la unidad del insumo existente (Priority: P2)

Como administrador, cuando actualizo insumos ya existentes mediante Excel (por ejemplo para
cambiar precio o stock), quiero que el valor de la columna unidad no altere la unidad base que el
insumo ya tiene asignada, para evitar que un cambio accidental de texto en esa columna rompa cómo
se interpretan el stock y el costo ya acumulados de ese insumo.

**Why this priority**: protege la integridad de insumos existentes frente a ediciones masivas;
depende de que la Historia 2 ya defina cómo se usa la columna unidad al crear.

**Independent Test**: puede probarse actualizando, mediante importación, un insumo existente con
un valor de unidad distinto al que tiene hoy, y verificando que el insumo conserva su unidad
original sin cambios, mientras que el resto de los campos de la fila (precio, stock, etc.) sí se
actualizan con normalidad.

**Acceptance Scenarios**:

1. **Given** un insumo existente cuya unidad es "g", **When** se importa una fila que lo
   actualiza (coincide por código) con la columna unidad en blanco, **Then** el insumo conserva su
   unidad "g" sin cambios, y el resto de campos de la fila se actualiza con normalidad.
2. **Given** un insumo existente cuya unidad es "g", **When** se importa una fila que lo
   actualiza con la columna unidad en "KG", **Then** el insumo conserva su unidad "g" (el valor
   "KG" de la fila se ignora para ese campo), y el resto de campos de la fila sí se actualiza.
3. **Given** una fila que actualiza un insumo existente con un valor de unidad que no existe
   todavía como unidad de medida, **When** se procesa, **Then** no se crea ninguna unidad de
   medida nueva por esa fila (solo se ignora el valor), a diferencia de lo que ocurre al crear un
   insumo nuevo (Historia 2).

---

### Edge Cases

- Un archivo exportado antes de este cambio (con las tres columnas de presentación/factor/último
  costo todavía presentes) se puede seguir importando sin error de estructura; esas tres columnas
  simplemente se ignoran — no se trata como un archivo inválido.
- Nombre de unidad con espacios extra o mezcla de mayúsculas/minúsculas (" Kg ", "kG"): se
  normaliza igual que el resto de comparaciones de texto del sistema antes de comparar contra las
  unidades de medida existentes, para no crear duplicados por diferencias de formato.
- Dos unidades de medida existentes que, sin distinguir mayúsculas/minúsculas, coinciden con el
  mismo texto de la columna unidad (dato ambiguo ya existente en el negocio): la fila se reporta
  como fallida, igual que el criterio ya vigente para unidades y proveedores en la spec 109
  (FR-006a).
- Una unidad de medida nueva creada automáticamente por importación (en su propio grupo, como
  base) queda disponible de inmediato en Ajustes y en el selector de unidades de compra (spec
  135), exactamente igual que una creada manualmente por el administrador.
- La presentación, factor de conversión y último costo de cualquier relación proveedor-insumo de
  un insumo no se ven afectados por la importación ni la exportación; siguen administrándose y
  visibles únicamente desde el módulo de proveedores. Cuál de las relaciones activas es la
  preferida sí puede cambiar por importación (FR-010), pero nunca sus datos propios.
- Una fila que actualiza un insumo existente con la columna Proveedor preferido vacía no cambia
  cuál es la relación preferida actual (no la borra ni la desmarca) -- mismo criterio que la
  columna Unidad al actualizar (Historia 3).
- Un proveedor nombrado en la columna Proveedor preferido que ya existe pero está inactivo se
  reactiva en vez de crear uno duplicado -- mismo criterio ya vigente para proveedores desde
  antes de esta spec.
- Una relación proveedor-insumo creada por FR-012 (presentación/factor en blanco) no se puede usar
  todavía en una compra (spec 106/107) hasta que el administrador le asigne presentación y factor
  de conversión desde el módulo de proveedores.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: La plantilla única de exportación/importación de inventario (spec 109) MUST dejar
  de incluir las columnas de presentación, factor de conversión y último costo pagado del
  proveedor preferido del insumo. La columna con el nombre del proveedor preferido MUST
  conservarse (FR-010/FR-011).
- **FR-002**: La exportación MUST generar el archivo sin esas tres columnas, para todos los
  insumos del negocio, independientemente de si tienen o no proveedor preferido asignado; la
  columna del nombre del proveedor preferido MUST seguir exportándose, en blanco si el insumo no
  tiene uno asignado.
- **FR-003**: La importación MUST seguir aceptando archivos que incluyan esas tres columnas (por
  ejemplo, archivos exportados antes de este cambio) sin rechazarlos por estructura; su contenido,
  si está presente, MUST ser ignorado.
- **FR-004**: La importación y la exportación de inventario MUST NOT modificar ni eliminar la
  presentación, el factor de conversión ni el último costo de ninguna relación proveedor-insumo
  **ya existente**, bajo ninguna circunstancia; esos tres datos solo son editables desde el módulo
  de proveedores (specs 106/107). La única excepción a "nunca crear" es la relación nueva que
  FR-012 crea con esos dos campos (presentación y factor) en blanco, cuando no existía ninguna.
- **FR-005**: La columna unidad del insumo MUST mantenerse en la plantilla de
  exportación/importación, tal como existe hoy.
- **FR-006**: Al crear un insumo nuevo por importación, el sistema MUST vincular el valor de la
  columna unidad a una unidad de medida existente del negocio cuyo nombre coincida sin distinguir
  mayúsculas/minúsculas; si ninguna unidad de medida existente coincide, MUST crear una unidad de
  medida nueva con ese nombre, en un grupo nuevo propio, marcada como la unidad base de ese grupo
  (factor de conversión 1 hacia sí misma).
- **FR-007**: Al actualizar un insumo existente por importación (fila cuyo código coincide con un
  insumo ya registrado), el sistema MUST ignorar el valor de la columna unidad para efectos de
  cambiar la unidad del insumo — la unidad base del insumo existente MUST permanecer sin cambios
  sin importar qué valor traiga esa columna en la fila, incluso si coincide con una unidad de
  medida distinta a la actual. El resto de campos de la fila sigue actualizándose con normalidad.
- **FR-008**: Cuando dos o más unidades de medida existentes del negocio coinciden, sin distinguir
  mayúsculas/minúsculas, con el valor de la columna unidad de una fila que crea un insumo nuevo,
  el sistema MUST reportar esa fila como fallida en vez de elegir una de forma arbitraria (mismo
  criterio que FR-006a de la spec 109).
- **FR-009**: Una fila que crea un insumo nuevo con la columna unidad vacía MUST reportarse como
  fallida por campo obligatorio faltante, igual que cualquier otro campo requerido vacío.
- **FR-010**: Cuando la columna Proveedor preferido de una fila trae un nombre que coincide, sin
  distinguir mayúsculas/minúsculas, con exactamente un proveedor existente que tiene exactamente
  una relación proveedor-insumo activa con ese insumo (módulo de proveedores, spec 106/107), la
  importación MUST marcar esa relación como la preferida del insumo, sin crear ni modificar su
  presentación, factor de conversión ni último costo. Una columna Proveedor preferido vacía MUST
  dejar sin cambios cuál es la relación preferida actual del insumo (no la borra ni la desmarca).
- **FR-011**: Cuando la columna Proveedor preferido de una fila trae un nombre que coincide, sin
  distinguir mayúsculas/minúsculas, con **más de un** proveedor existente, o con un proveedor cuya
  relación activa con ese insumo es también ambigua (más de una), la fila MUST reportarse como
  fallida, sin crear ni modificar nada; el resto de campos de esa fila tampoco MUST aplicarse.
- **FR-012**: Cuando la columna Proveedor preferido de una fila trae un nombre que no coincide con
  ningún proveedor existente, o que coincide con exactamente un proveedor existente que no tiene
  ninguna relación activa con ese insumo, la importación MUST crear el proveedor si no existía
  (mismo criterio de consolidación ya vigente para proveedores: normalizado en mayúscula,
  reactivando uno inactivo que coincida en vez de duplicarlo) y MUST crear una relación
  proveedor-insumo nueva marcada como preferida, con `presentation` y `conversion_factor` en
  blanco/`NULL` -- la plantilla ya no trae esos dos datos. Esos dos campos quedan pendientes de
  completarse desde el módulo de proveedores (estado intermedio aceptado explícitamente).

### Key Entities *(include if feature involves data)*

- **Plantilla de Inventario** (spec 109): pierde las columnas de presentación, factor de
  conversión y último costo del proveedor preferido; conserva la columna del nombre del proveedor
  preferido y la columna unidad, ambas con el comportamiento definido aquí.
- **Unidad de Medida** (spec 137): entidad ya existente (nombre, abreviatura, grupo, si es la
  unidad base del grupo, factor de conversión hacia la base); esta funcionalidad la usa como
  destino de vinculación o creación automática desde la columna unidad del Excel, sin cambiar su
  modelo.
- **Insumo de Inventario**: su atributo unidad (ya existente) pasa a vincularse siempre con un
  registro real de Unidad de Medida al crearse por importación; al actualizarse por importación,
  ese atributo no se modifica a través de este flujo.
- **Proveedor** (spec 106): si el nombre de la columna Proveedor preferido no coincide con ninguno
  existente, se crea (mismo criterio de consolidación ya vigente desde antes de esta spec) — ver
  FR-012.
- **Relación Proveedor-Insumo** (spec 106/107): su presentación, factor de conversión y último
  costo nunca se modifican ni se eliminan por la exportación/importación de inventario de una
  relación ya existente (FR-004); cuál relación activa es la preferida de un insumo sí puede
  cambiar por importación, vinculando por nombre de proveedor a una relación existente (FR-010) o
  creando una nueva con presentación/factor en `NULL` si no existía ninguna (FR-012).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100% de los archivos exportados después de este cambio carecen de las columnas
  de presentación, factor de conversión y último costo del proveedor preferido, pero sí incluyen
  el nombre del proveedor preferido de cada insumo.
- **SC-002**: El 100% de las importaciones, sin excepción, dejan intacta la presentación, el
  factor de conversión y el último costo de cualquier relación proveedor-insumo que ya existía
  antes de la importación, sin importar el contenido del archivo subido.
- **SC-003**: Un administrador puede crear insumos nuevos por Excel usando nombres de unidad que
  todavía no existen en el negocio, sin tener que crearlas manualmente antes en Ajustes, y
  encontrarlas luego ya disponibles para usarse en compras (spec 135).
- **SC-004**: Ninguna actualización masiva de insumos existentes vía Excel cambia por accidente la
  unidad base de un insumo, verificable en el 100% de los casos donde la columna unidad de la fila
  difiere de la unidad actual del insumo.
- **SC-005**: Un administrador puede indicar, en la columna Proveedor preferido, un proveedor que
  todavía no existe en el negocio, y encontrarlo luego ya creado en el módulo de proveedores, con
  una relación marcada como preferida para ese insumo, sin tener que crear ninguno de los dos
  manualmente antes de importar.

## Assumptions

- Esta spec no reabre ni modifica las reglas ya vigentes de la spec 109 para los demás campos
  (código, nombre, tipo, stock, stock mínimo, costo) ni su mecanismo de upsert por código; solo
  ajusta el conjunto de columnas y el tratamiento específico de la columna unidad.
- El criterio de comparación sin distinguir mayúsculas/minúsculas y de consolidación de texto para
  la columna unidad sigue el mismo patrón ya establecido por la spec 109 (FR-006a) para unidades y
  proveedores, adaptado a que la unidad de medida ahora es una entidad estructurada (grupo, base,
  factor) en vez de texto libre, según la spec 137.
- Una unidad de medida creada automáticamente por importación, al quedar en su propio grupo como
  base con factor 1, puede reorganizarse después manualmente por el administrador desde Ajustes
  (por ejemplo, moviéndola a un grupo existente) si corresponde a una conversión real con otras
  unidades — esa reorganización posterior queda fuera del alcance de esta funcionalidad.
- No se requiere una migración de datos para archivos o integraciones externas que todavía
  generen las tres columnas removidas; FR-003 ya cubre la compatibilidad hacia atrás necesaria.
- FR-012 SÍ requiere una migración de esquema (a diferencia del resto de esta spec, que no cambia
  modelos): `supplier_items.presentation` y `supplier_items.conversion_factor` dejan de ser
  `NOT NULL`, porque una relación creada por esta vía no tiene esos datos todavía. Esto es un
  estado intermedio aceptado explícitamente por el solicitante; cómo completar esos datos (o si
  se exige hacerlo antes de permitir ciertas acciones) queda fuera de esta spec y puede abordarse
  en una spec futura.
