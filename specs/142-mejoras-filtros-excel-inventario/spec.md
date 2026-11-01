# Feature Specification: Filtro buscable de proveedor, exportación filtrada y vinculación de unidades de compra por Excel

**Feature Branch**: `142-mejoras-filtros-excel-inventario`

**Created**: 2026-10-28

**Status**: Draft

**Input**: User description: "necesito hacer algunos ajustes en el inventario, el primer ajuste
es que el filtro de provedores que se encuentra en el listado de insumos, es una lista pero no
permite buscar entre sus opciones, segundo, al exportar el inventario, este exporta todos, los
registros, pero quisiera tener la opcion de filtrar los registros que quiero exportar ya sea por
proveedor o tipo de insumo, y obiamente tener tambien la opcion de exportar todos los registros
del inventario, y tercero, actualmente la unidad que viene en el archivo de excel, este sea crea
si no viene, pero quisiera tambien que a traves del archivo de excel pueda definir a que grupo
pertenece la unidad base y pues asociar esa unidad base con el grupo, y tambien definir la
relacion de la unidad que se compra ese producto con el provedor y su factor de conversion,
obviamente debes analizar que esas unidades de compra en relacion con el provedor por lo tambien
aplica el mismo principio se debe relacionar con el grupo y si existe la unidad definir la
relacion y si no crearla con el proveedor, si hay alguna duda me preguntas"

**Contexto**: Esta spec cubre tres ajustes independientes a la pestaña "Insumos" del módulo de
Inventario y a su flujo de exportación/importación por Excel. El filtro de proveedor por lista
(no buscable) y la exportación sin filtros fueron introducidos por la spec
[133](../133-busqueda-filtro-inventario/spec.md). La plantilla de Excel, su columna de unidad y la
columna de proveedor preferido vienen de las specs [109](../109-inventario-excel-masivo/spec.md) y
[139](../139-simplificar-columnas-excel-inventario/spec.md). El modelo de unidades de medida
(grupo, unidad base, factor de conversión hacia la base) viene de la spec
[137](../137-rediseno-ajustes/spec.md) y su uso en compras de la spec
[135](../135-conversion-unidades-compra/spec.md). La relación proveedor-insumo (`presentation`,
`conversion_factor` por relación) viene de la spec
[106](../106-relacion-proveedor-insumo/spec.md).

## Clarifications

### Session 2026-10-28

- Q: El tercer ajuste pide que, al importar por Excel, la "unidad que se compra" a un proveedor
  (hoy el campo libre `presentation` de la relación proveedor-insumo, sin relación con el modelo
  de grupos/unidades de medida) pase a comportarse igual que la unidad base: perteneciente a un
  grupo, reutilizable si ya existe con ese nombre en el grupo, y creada en ese grupo si no existe.
  Esto reabre una decisión explícita de la spec 139 (que removió `presentation`/`conversion_factor`
  del Excel para que solo se editaran desde el módulo de proveedores). ¿Cómo debe quedar esa
  relación? → A: La unidad de compra pasa a ser una Unidad de Medida real del mismo grupo que la
  unidad base del insumo (reutilizando su factor si ya existe en el grupo, o creándola con el
  factor de la fila si no existe); esa Unidad de Medida queda como la unidad de compra de la
  relación proveedor-insumo preferida, sustituyendo el uso del campo libre `presentation` para las
  relaciones creadas o emparejadas por esta vía.
- Q: Si una fila que crea un insumo nuevo llena las columnas de unidad de compra y/o factor de
  conversión del proveedor preferido (Historia 3) pero deja vacía la columna del proveedor
  preferido mismo, sin relación proveedor-insumo a la cual asociar esos datos, ¿qué debe pasar?
  → A: La fila se reporta como fallida, por dato de unidad de compra sin proveedor al que
  asociarlo, sin crear el insumo ni ninguna unidad o relación para esa fila.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Buscar dentro del filtro de proveedor en Insumos (Priority: P1)

Un administrador de inventario abre el filtro de proveedor en la pestaña "Insumos" y, en lugar de
desplazarse por una lista larga de proveedores para encontrar el que necesita, escribe parte del
nombre del proveedor y ve solo las opciones que coinciden, igual que ya puede hacerlo en otros
selectores de la aplicación (por ejemplo, al elegir un insumo en la pestaña "Movimientos" de este
mismo módulo).

**Why this priority**: Es el ajuste más simple y de menor riesgo de los tres, mejora de inmediato
la usabilidad del filtro ya existente (spec 133) sin depender de ningún otro cambio de esta spec.

**Independent Test**: Puede probarse abriendo el filtro de proveedor con varios proveedores
registrados, escribiendo parte del nombre de uno de ellos y verificando que solo esa opción (y
las que coincidan parcialmente) queda visible para seleccionar.

**Acceptance Scenarios**:

1. **Given** la pestaña "Insumos" con varios proveedores registrados, **When** el usuario abre el
   filtro de proveedor y escribe texto que coincide parcialmente con el nombre de uno de ellos,
   **Then** la lista de opciones mostradas se reduce a los proveedores cuyo nombre coincide,
   sin distinguir mayúsculas/minúsculas.
2. **Given** el filtro de proveedor abierto con texto de búsqueda escrito, **When** el usuario
   borra el texto, **Then** vuelven a verse todos los proveedores disponibles, incluyendo la
   opción "Todos los proveedores".
3. **Given** un texto de búsqueda que no coincide con ningún proveedor, **When** el usuario lo
   escribe en el filtro, **Then** el filtro no muestra ninguna opción seleccionable y no rompe la
   pantalla.
4. **Given** el usuario selecciona un proveedor desde el filtro ya buscado, **When** se aplica la
   selección, **Then** el listado de insumos se filtra exactamente igual que hoy con el filtro no
   buscable (mismo comportamiento ya definido por la spec 133).

---

### User Story 2 - Elegir qué exportar del inventario (Priority: P2)

Un administrador que necesita enviarle a un proveedor específico, o revisar solo un tipo de
insumo, un listado parcial del inventario, hoy solo puede exportar el archivo completo y filtrar
manualmente después en una hoja de cálculo. Quiere poder elegir, antes de generar el archivo, si
exporta todos los insumos o solo los que coinciden con un proveedor y/o un tipo de insumo.

**Why this priority**: Depende de que ya exista el catálogo de proveedores y tipos de insumo (ya
existen), es independiente de los otros dos ajustes, y tiene menor urgencia que la Historia 1
porque la exportación completa ya es usable hoy, solo menos cómoda.

**Independent Test**: Puede probarse exportando el inventario tres veces: una sin ningún filtro
(debe traer todos los insumos, igual que hoy), una filtrando solo por proveedor, y una filtrando
solo por tipo de insumo, verificando en cada caso que el archivo generado contiene exactamente el
subconjunto esperado de insumos.

**Acceptance Scenarios**:

1. **Given** el administrador inicia la exportación de inventario sin seleccionar ningún filtro,
   **When** se genera el archivo, **Then** contiene todos los insumos del negocio, igual que el
   comportamiento actual.
2. **Given** el administrador selecciona un proveedor específico antes de exportar, **When** se
   genera el archivo, **Then** contiene únicamente los insumos que tienen una relación activa con
   ese proveedor, usando el mismo criterio de coincidencia que el filtro de proveedor de la
   Historia 1.
3. **Given** el administrador selecciona un tipo de insumo específico (materia prima o empacado)
   antes de exportar, **When** se genera el archivo, **Then** contiene únicamente los insumos de
   ese tipo.
4. **Given** el administrador selecciona a la vez un proveedor y un tipo de insumo antes de
   exportar, **When** se genera el archivo, **Then** contiene únicamente los insumos que cumplen
   ambas condiciones (intersección, no unión).
5. **Given** un proveedor y/o tipo de insumo seleccionados para exportar que no coinciden con
   ningún insumo, **When** se genera el archivo, **Then** el archivo se genera igual, con la
   plantilla de columnas pero sin filas de datos (no se trata como error).

---

### User Story 3 - Definir el grupo de la unidad base y la unidad de compra por proveedor desde el Excel (Priority: P3)

Un administrador que da de alta insumos nuevos por Excel quiere, en la misma importación, indicar
a qué grupo de medida pertenece la unidad base del insumo (por ejemplo, que "g" pertenece al grupo
"Masa" junto con "KG" y "LB"), en vez de que cada unidad nueva quede siempre en su propio grupo
aislado como ocurre hoy. Además, quiere poder indicar en qué unidad le compra el insumo a su
proveedor preferido y el factor de conversión de esa unidad hacia la unidad base, para no tener
que completar esos datos manualmente desde el módulo de proveedores después de cada importación
masiva.

**Why this priority**: Es el ajuste más complejo y el que más depende de los otros módulos ya
existentes de unidades de medida (spec 137) y compras (spec 135); aporta valor por sí solo pero
es razonable entregarlo después de los dos ajustes más simples.

**Independent Test**: Puede probarse importando un archivo con insumos nuevos que incluyen una
columna de grupo para la unidad base y columnas de unidad de compra/factor para el proveedor
preferido, y verificando que: (a) la unidad base queda en el grupo indicado (creándolo si no
existía), y (b) la relación con el proveedor preferido queda con la unidad de compra y el factor
indicados, usando una Unidad de Medida real del mismo grupo que la base.

**Acceptance Scenarios**:

1. **Given** el negocio no tiene ningún grupo llamado "Masa", **When** se importa un insumo nuevo
   con unidad base "g" y grupo "Masa", **Then** se crea el grupo "Masa", se crea la unidad "g"
   dentro de ese grupo marcada como su unidad base (factor 1), y el insumo queda creado con esa
   unidad.
2. **Given** el negocio ya tiene el grupo "Masa" con la unidad base "g" ya definida, **When** se
   importa otro insumo nuevo con unidad base "g" y grupo "Masa", **Then** el insumo se vincula a
   la unidad "g" ya existente de ese grupo, sin crear un grupo ni una unidad duplicados.
3. **Given** una fila crea un insumo nuevo con una columna de grupo vacía, **When** se procesa,
   **Then** se aplica el comportamiento actual (spec 139 FR-006): la unidad se crea en su propio
   grupo nuevo como base, sin fallar la fila por esto.
4. **Given** una fila crea un insumo nuevo cuya unidad base ya existe con ese nombre pero en un
   grupo distinto al indicado en la columna de grupo, **When** se procesa, **Then** la fila se
   reporta como fallida por ambigüedad de grupo, sin crear ni modificar nada para ese insumo.
5. **Given** una fila indica una unidad de compra para el proveedor preferido (por ejemplo "KG")
   y un factor de conversión hacia la unidad base del insumo (por ejemplo 1000 para una base en
   "g"), y esa unidad "KG" ya existe en el grupo "Masa" de la unidad base con factor 1000,
   **When** se procesa, **Then** la relación con el proveedor preferido queda con "KG" como
   unidad de compra, reutilizando su factor existente (1000), sin crear una unidad duplicada ni
   sobrescribir el factor ya definido para "KG" en ese grupo.
6. **Given** la misma fila del escenario anterior pero con un factor distinto al ya definido para
   "KG" en el grupo (por ejemplo 900 en vez de 1000), **When** se procesa, **Then** la fila se
   reporta como fallida por conflicto de factor, sin modificar el factor ya vigente de "KG" (el
   factor de una unidad de medida es compartido por todo el negocio, no se redefine por fila).
7. **Given** una fila indica una unidad de compra que no existe todavía en el grupo de la unidad
   base del insumo (por ejemplo "Bulto" en el grupo "Masa") junto con un factor de conversión,
   **When** se procesa, **Then** se crea la unidad "Bulto" dentro de ese grupo con el factor
   indicado, y la relación con el proveedor preferido queda usando "Bulto" como unidad de compra.
8. **Given** una fila indica una unidad de compra sin indicar ningún factor de conversión, y esa
   unidad no existe todavía en el grupo de la unidad base, **When** se procesa, **Then** la fila
   se reporta como fallida por dato obligatorio faltante (no se puede crear la unidad sin factor).
9. **Given** una fila actualiza un insumo existente (coincide por código) e incluye columnas de
   grupo y/o unidad de compra con valores distintos a los ya vigentes, **When** se procesa,
   **Then** esas columnas se ignoran para ese insumo (mismo criterio ya vigente para la columna
   de unidad al actualizar, spec 139 FR-007); el resto de la fila se actualiza con normalidad.
10. **Given** una fila crea un insumo nuevo sin ningún valor en las columnas de unidad de compra
    ni factor, **When** se procesa, **Then** el insumo se crea igual sin unidad de compra para el
    proveedor preferido (dato opcional, a diferencia de la unidad base que sigue siendo
    obligatoria).
11. **Given** una fila crea un insumo nuevo con valor en la columna de unidad de compra y/o
    factor de conversión, pero sin ningún proveedor preferido indicado en esa fila, **When** se
    procesa, **Then** la fila se reporta como fallida por dato de unidad de compra sin proveedor
    al que asociarlo, sin crear el insumo ni ninguna unidad o relación para esa fila.

---

### Edge Cases

- Proveedor con nombre que coincide parcialmente con el texto de búsqueda del filtro de la
  Historia 1 en más de una posición o varios proveedores con nombres muy similares: todos los que
  coincidan parcialmente se muestran, sin límite de resultados adicional al ya existente en el
  selector.
- Exportar con el filtro de proveedor de la Historia 2 apuntando a un proveedor inactivo: se
  exportan los insumos con relación activa con ese proveedor igual que hoy filtra el listado,
  independientemente del estado del proveedor.
- Un insumo con múltiples relaciones a proveedores (spec 106) exportado con un filtro de
  proveedor que coincide con uno de ellos (no el preferido): el insumo aparece en el archivo
  igual que aparece hoy en el listado filtrado por proveedor, sin alterar cuál es su proveedor
  preferido.
- Grupo indicado en la columna de grupo (Historia 3) que coincide, sin distinguir
  mayúsculas/minúsculas, con un grupo ya existente pero escrito con diferencias de formato
  (espacios extra, mayúsculas): se normaliza igual que el resto de comparaciones de texto del
  sistema, sin crear un grupo duplicado.
- Unidad de compra indicada para el proveedor preferido cuyo nombre coincide, sin distinguir
  mayúsculas/minúsculas, con una unidad ya existente en el negocio pero en un **grupo distinto**
  al de la unidad base del insumo: la fila se reporta como fallida, igual que el criterio de
  ambigüedad de grupo ya aplicado a la unidad base (escenario 4 de la Historia 3).
- Insumo nuevo sin ninguna relación previa con el proveedor preferido indicado: la relación se
  crea igual que ya lo hace la spec 139 (FR-012), pero ahora con la unidad de compra y el factor
  resueltos como Unidad de Medida en vez de quedar en blanco.
- Insumo existente que ya tenía una relación con el proveedor preferido usando el campo libre
  `presentation` (creada antes de esta spec, por el módulo de proveedores): esa relación no se
  toca por una fila que actualiza el insumo (criterio de "ignorar en actualización", escenario 9);
  solo una fila que *crea* un insumo nuevo puede fijar la unidad de compra inicial.

## Requirements *(mandatory)*

### Functional Requirements

**Filtro buscable de proveedor (Historia 1)**

- **FR-001**: El filtro de proveedor en la pestaña "Insumos" MUST permitir al usuario escribir
  texto libre para reducir las opciones de proveedor mostradas, mediante coincidencia parcial sin
  distinguir mayúsculas/minúsculas contra el nombre del proveedor.
- **FR-002**: El filtro MUST conservar la opción de no filtrar por proveedor ("Todos los
  proveedores") visible y seleccionable incluso con texto de búsqueda vacío.
- **FR-003**: El comportamiento de filtrado del listado de insumos al seleccionar un proveedor
  desde este filtro buscable MUST ser idéntico al ya definido por la spec 133.

**Exportación filtrada de inventario (Historia 2)**

- **FR-004**: La acción de exportar inventario MUST permitir al usuario elegir, antes de generar
  el archivo, entre exportar todos los insumos o exportar solo los que coincidan con un filtro de
  proveedor, un filtro de tipo de insumo, o ambos a la vez (intersección).
- **FR-005**: Cuando no se selecciona ningún filtro para exportar, el sistema MUST generar el
  archivo con todos los insumos del negocio, igual que el comportamiento actual.
- **FR-006**: El criterio de coincidencia del filtro de proveedor al exportar MUST ser el mismo ya
  usado para filtrar el listado de insumos por proveedor (relación activa).
- **FR-007**: El criterio de coincidencia del filtro de tipo de insumo al exportar MUST ser el
  mismo ya usado para filtrar el listado de insumos por tipo (materia prima / empacado).
- **FR-008**: Un filtro de exportación que no coincide con ningún insumo MUST generar un archivo
  válido con la plantilla de columnas pero sin filas de datos, no un error.

**Grupo de unidad base y unidad de compra por proveedor vía Excel (Historia 3)**

- **FR-009**: Al crear un insumo nuevo por importación, el sistema MUST permitir indicar, en una
  columna nueva, el nombre del grupo de medida al que pertenece la unidad base del insumo.
- **FR-010**: Si el grupo indicado ya existe (comparación sin distinguir mayúsculas/minúsculas,
  normalizando espacios), la unidad base del insumo MUST crearse o vincularse dentro de ese grupo
  existente. Si el grupo no existe todavía, el sistema MUST crearlo con ese nombre y la unidad
  base del insumo queda como su unidad base (factor 1), igual que el criterio ya vigente para la
  creación de grupo implícito (spec 139 FR-006), pero ahora con el nombre indicado en vez de un
  nombre generado.
- **FR-011**: Una columna de grupo vacía en una fila que crea un insumo nuevo MUST conservar el
  comportamiento actual (spec 139 FR-006): la unidad se crea en su propio grupo nuevo como base.
- **FR-012**: Si el nombre de unidad base de la fila ya existe en el negocio pero en un grupo
  distinto al indicado por la columna de grupo, la fila MUST reportarse como fallida por
  ambigüedad, sin crear ni modificar nada para ese insumo.
- **FR-013**: Al actualizar un insumo existente por importación, el sistema MUST ignorar el valor
  de la columna de grupo para efectos de cambiar el grupo o la unidad base del insumo existente,
  con el mismo criterio ya vigente para la columna de unidad (spec 139 FR-007).
- **FR-014**: Al crear un insumo nuevo por importación con un proveedor preferido indicado (spec
  139 FR-012), el sistema MUST permitir indicar opcionalmente, en columnas nuevas, la unidad en
  que ese proveedor le vende el insumo y el factor de conversión de esa unidad hacia la unidad
  base del insumo.
- **FR-015**: La unidad de compra indicada MUST resolverse como una Unidad de Medida real
  perteneciente al mismo grupo que la unidad base del insumo, siguiendo el mismo principio que la
  unidad base (FR-010): si ya existe una unidad con ese nombre en ese grupo, se reutiliza su
  factor de conversión ya definido; si no existe, se crea en ese grupo con el factor indicado en
  la fila.
- **FR-016**: Si la unidad de compra indicada ya existe en el grupo de la unidad base pero con un
  factor de conversión distinto al indicado en la fila, la fila MUST reportarse como fallida por
  conflicto de factor, sin modificar el factor ya vigente de esa unidad (el factor de una unidad
  de medida es compartido por todo el negocio).
- **FR-017**: Si la unidad de compra indicada coincide, sin distinguir mayúsculas/minúsculas, con
  una unidad existente en un grupo distinto al de la unidad base del insumo, la fila MUST
  reportarse como fallida por ambigüedad de grupo, sin crear ni modificar nada.
- **FR-018**: Si se indica una unidad de compra nueva (que no existe todavía en el grupo) sin
  indicar su factor de conversión, la fila MUST reportarse como fallida por dato obligatorio
  faltante.
- **FR-019**: Cuando la unidad de compra y su factor se resuelven correctamente para una fila que
  crea un insumo nuevo con proveedor preferido, la relación proveedor-insumo creada o emparejada
  (spec 139 FR-012) MUST quedar con esa Unidad de Medida como su unidad de compra, en vez de
  quedar con presentación y factor en blanco.
- **FR-020**: Dejar vacías las columnas de unidad de compra y factor en una fila que crea un
  insumo nuevo MUST seguir permitiendo crear el insumo y, si aplica, su relación con el proveedor
  preferido, sin unidad de compra asociada (dato opcional).
- **FR-020a**: Si una fila que crea un insumo nuevo indica un valor en la columna de unidad de
  compra y/o de factor de conversión del proveedor preferido pero no indica ningún proveedor
  preferido en esa misma fila, el sistema MUST reportar la fila como fallida por dato de unidad
  de compra sin proveedor al que asociarlo, sin crear el insumo ni ninguna unidad o relación para
  esa fila.
- **FR-021**: Al actualizar un insumo existente por importación, el sistema MUST ignorar las
  columnas de unidad de compra y factor para efectos de modificar una relación proveedor-insumo ya
  existente, con el mismo criterio de "no tocar lo ya existente" ya vigente (spec 139 FR-004):
  esos datos solo se fijan al crear el insumo y su relación de proveedor preferido por primera vez.

### Key Entities *(include if feature involves data)*

- **Proveedor**: ya existente; esta funcionalidad lo usa como criterio de búsqueda textual
  (Historia 1) y de filtro de exportación (Historia 2), sin cambios a su modelo.
- **Insumo de Inventario**: ya existente; se filtra por tipo al exportar (Historia 2) y su unidad
  base pasa a poder vincularse a un grupo indicado explícitamente al crearse por importación
  (Historia 3), en vez de siempre un grupo propio nuevo.
- **Grupo de Unidad de Medida** (spec 137): ya existente; esta funcionalidad lo usa como destino
  de vinculación o creación explícita desde una columna de Excel, en vez de crearse siempre de
  forma implícita con un nombre generado.
- **Unidad de Medida** (spec 137): ya existente (nombre, grupo, si es la base del grupo, factor
  de conversión hacia la base); esta funcionalidad la usa también como la unidad de compra de una
  relación proveedor-insumo creada por importación, en vez de solo como unidad base del insumo.
- **Relación Proveedor-Insumo** (spec 106): su unidad de compra, al crearse por esta vía, pasa a
  ser una Unidad de Medida real del grupo de la unidad base, en vez de quedar con el campo libre
  `presentation` en blanco (spec 139 FR-012). Las relaciones ya existentes, o las actualizadas sin
  crear un insumo nuevo, no se modifican por esta funcionalidad.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un administrador puede encontrar y seleccionar un proveedor en el filtro de
  Insumos escribiendo parte de su nombre, sin tener que desplazarse manualmente por la lista
  completa, en el 100% de los casos con al menos un proveedor coincidente.
- **SC-002**: Un administrador puede generar un archivo de exportación que contenga únicamente
  los insumos de un proveedor y/o tipo de insumo específico, sin tener que filtrar manualmente el
  archivo completo después de exportarlo.
- **SC-003**: Exportar sin seleccionar ningún filtro sigue produciendo el mismo resultado que hoy
  (el inventario completo), sin regresión para quienes no usan los nuevos filtros.
- **SC-004**: Un administrador puede crear insumos nuevos por Excel especificando a qué grupo de
  medida pertenece cada unidad base, y encontrar luego ese grupo y esa unidad ya organizados
  correctamente en Ajustes, sin tener que reorganizarlos manualmente después de importar.
- **SC-005**: Un administrador puede crear insumos nuevos por Excel con su proveedor preferido ya
  configurado con unidad de compra y factor de conversión, sin tener que completar esos dos datos
  manualmente desde el módulo de proveedores después de cada importación masiva.
- **SC-006**: El 100% de las filas que indiquen un factor de conversión en conflicto con el ya
  vigente para una unidad de compra existente se reportan como fallidas en vez de sobrescribir
  silenciosamente ese factor compartido.

## Assumptions

- El criterio de coincidencia parcial y sin distinguir mayúsculas/minúsculas del filtro buscable
  de proveedor (Historia 1) sigue el mismo patrón ya usado por otros selectores buscables de la
  aplicación (por ejemplo, el selector de insumo de la pestaña "Movimientos" de este mismo
  módulo), sin imponer un mínimo de caracteres para empezar a filtrar.
- Los filtros de exportación (Historia 2) son independientes de los filtros aplicados en ese
  momento al listado visible de Insumos: el usuario los elige explícitamente al exportar, con
  "todos los registros" como opción por defecto si no elige ninguno, preservando el comportamiento
  actual para quien no interactúa con el nuevo selector de filtros de exportación.
- El filtro de tipo de insumo para exportar usa las mismas dos categorías ya existentes en todo el
  sistema (materia prima / empacado); esta spec no introduce una taxonomía de tipos nueva.
- La columna de grupo (Historia 3) es opcional: una fila sin esa columna o con ella vacía sigue
  funcionando exactamente igual que hoy (spec 139), creando un grupo propio nuevo para la unidad
  base. Esta spec no obliga a los administradores a empezar a usar la columna de grupo.
- Las columnas de unidad de compra y factor de conversión del proveedor preferido (Historia 3) son
  opcionales y solo tienen efecto al crear un insumo nuevo; esta spec no reabre la prohibición ya
  vigente (spec 139 FR-004) de modificar por importación una relación proveedor-insumo que ya
  existía antes del archivo que se está importando.
- El factor de conversión de una Unidad de Medida es un dato compartido por todo el negocio
  (ya definido así por la spec 137/135): dos filas, o dos proveedores distintos, que nombren la
  misma unidad de compra dentro del mismo grupo deben coincidir en el factor, o la fila se rechaza
  (FR-016), en vez de permitir que cada proveedor tenga su propio factor para "la misma" unidad.
- Requiere acceso a las entidades ya existentes de Proveedor, Insumo, Grupo de Unidad de Medida,
  Unidad de Medida y Relación Proveedor-Insumo (specs 106, 109, 133, 135, 137, 139); no introduce
  entidades nuevas.
