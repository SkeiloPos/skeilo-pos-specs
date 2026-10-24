# Feature Specification: Búsqueda por Nombre o Código y Filtro por Proveedor en Inventario

**Feature Branch**: `133-busqueda-filtro-inventario`

**Created**: 2026-10-23

**Status**: Draft

**Input**: User description: "necesito que implementes la funcionalidad en el inventario, para
buscar los registros ya sea por nombre o codigo, y para filtrar tambien los registros por el
proveedor, ten en cuenta los indices para optimizar las busquedas, si tienes dudas en cuanto
backend o ui me consultas"

**Contexto**: Esta spec cubre la pestaña "Insumos" del módulo de Inventario. Hoy el buscador de
esa pantalla solo compara contra el nombre del insumo; esta spec amplía esa búsqueda para que
también compare contra el código del insumo, y agrega un nuevo filtro por proveedor junto a los
filtros existentes de tipo de insumo y estado (activo/inactivo), definidos en la
[spec 085](../085-mejora-visibilidad-filtros-inventario/spec.md). La relación proveedor-insumo ya
existe (ver [spec 106](../106-relacion-proveedor-insumo/spec.md)): un insumo puede estar vinculado
a varios proveedores. Las pestañas "Compras" y "Movimientos" de Inventario no tienen esta barra
de búsqueda/filtros y quedan fuera de alcance.

## Clarifications

### Session 2026-10-23

- Q: About how many insumos should the system be designed to handle in the inventory catalog, at realistic scale? → A: 500 – 5,000 insumos (typical SMB catalog)
- Q: When the user types multiple words into the search box (e.g. "arroz blanco"), should matching require the exact phrase or all words in any order? → A: Exact phrase/substring match only (current behavior)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Buscar un insumo por nombre o por código (Priority: P1)

Un administrador de inventario recuerda el código de un insumo (por ejemplo, el impreso en una
etiqueta o factura) pero no su nombre exacto, o viceversa. Escribe lo que recuerda en el buscador
de la pestaña "Insumos" y espera encontrar el insumo sin tener que saber de antemano si lo que
escribió es el nombre o el código.

**Why this priority**: Es la funcionalidad explícitamente solicitada con mayor impacto directo:
hoy buscar por código no devuelve resultados, obligando a desplazarse manualmente por toda la
lista.

**Independent Test**: Puede probarse de forma aislada escribiendo un código conocido en el
buscador y verificando que el insumo correspondiente aparece en los resultados, sin necesidad del
filtro por proveedor.

**Acceptance Scenarios**:

1. **Given** la pestaña "Insumos" con varios insumos registrados, **When** el usuario escribe en
   el buscador un texto que coincide parcialmente con el **código** de un insumo, **Then** ese
   insumo aparece en los resultados.
2. **Given** la misma pantalla, **When** el usuario escribe un texto que coincide parcialmente con
   el **nombre** de un insumo, **Then** ese insumo aparece en los resultados (comportamiento que ya
   existe y no debe romperse).
3. **Given** un texto de búsqueda que coincide parcialmente tanto con el nombre de un insumo A
   como con el código de un insumo B (distintos insumos), **When** se ejecuta la búsqueda,
   **Then** ambos insumos (A y B) aparecen en los resultados.
4. **Given** un texto de búsqueda que no coincide con ningún nombre ni código, **When** se ejecuta
   la búsqueda, **Then** la lista de resultados queda vacía con un mensaje indicando que no se
   encontraron insumos.

---

### User Story 2 - Filtrar insumos por proveedor (Priority: P2)

Un administrador de inventario necesita ver únicamente los insumos que compra a un proveedor
específico, por ejemplo para preparar un pedido o revisar qué le vende ese proveedor.

**Why this priority**: Es la segunda funcionalidad explícitamente solicitada; depende del catálogo
de proveedores y de la relación proveedor-insumo ya existente, pero es independiente de la mejora
de búsqueda de la Historia 1.

**Independent Test**: Puede probarse de forma aislada seleccionando un proveedor en el nuevo
filtro y verificando que solo aparecen los insumos vinculados a ese proveedor, con el buscador de
texto vacío.

**Acceptance Scenarios**:

1. **Given** la pestaña "Insumos" con un selector de proveedor junto a los filtros existentes,
   **When** el usuario selecciona un proveedor específico, **Then** la lista muestra únicamente
   los insumos vinculados a ese proveedor.
2. **Given** un proveedor seleccionado en el filtro, **When** ese proveedor no tiene ningún insumo
   vinculado, **Then** la lista de resultados queda vacía con un mensaje indicando que no se
   encontraron insumos.
3. **Given** un filtro de proveedor activo, **When** el usuario lo limpia (vuelve a "Todos los
   proveedores"), **Then** la lista vuelve a mostrar insumos de todos los proveedores (sujeta a los
   demás filtros/búsqueda activos).

---

### User Story 3 - Combinar búsqueda y filtros existentes (Priority: P3)

Un administrador de inventario quiere acotar aún más sus resultados usando la búsqueda por
nombre/código junto con el filtro de proveedor y los filtros ya existentes de tipo de insumo y
estado (activo/inactivo), todos al mismo tiempo.

**Why this priority**: Es un refinamiento de valor incremental sobre las Historias 1 y 2; el
sistema ya es útil sin esta combinación, pero la combinación evita que el usuario tenga que hacer
varias búsquedas por separado.

**Independent Test**: Puede probarse de forma aislada activando el buscador de texto, el filtro de
proveedor y el filtro de tipo/estado simultáneamente, y verificando que los resultados cumplen
todos los criterios a la vez (intersección, no unión).

**Acceptance Scenarios**:

1. **Given** un texto de búsqueda y un proveedor seleccionados simultáneamente, **When** se
   ejecuta la búsqueda, **Then** solo aparecen insumos que cumplen ambos criterios (coinciden con
   el texto Y están vinculados al proveedor seleccionado).
2. **Given** búsqueda, filtro de proveedor, filtro de tipo y filtro de estado activos a la vez,
   **When** se ejecuta la búsqueda, **Then** los resultados cumplen los cuatro criterios
   simultáneamente.

---

### Edge Cases

- ¿Qué pasa si el usuario escribe un texto muy corto (por ejemplo, una sola letra)? El sistema
  debe seguir devolviendo todas las coincidencias parciales por nombre o código, igual que hoy
  ocurre con la búsqueda por nombre.
- ¿Qué pasa si un insumo está vinculado a un proveedor pero esa relación proveedor-insumo está
  marcada como inactiva? El filtro por ese proveedor no debe mostrar ese insumo (ver Assumptions).
- ¿Qué pasa si se selecciona un proveedor que luego es eliminado o desactivado del catálogo? El
  filtro debe dejar de ofrecer ese proveedor como opción y, si estaba seleccionado, debe
  comportarse como si no hubiera filtro de proveedor activo (mostrar todos).
- ¿Qué pasa si el catálogo de insumos crece a varios miles de registros? La búsqueda combinada por
  nombre/código y el filtro por proveedor deben seguir respondiendo con rapidez (ver Success
  Criteria), sin degradar el resto de la pantalla.
- ¿Qué pasa si el usuario pagina los resultados y luego cambia la búsqueda o el filtro de
  proveedor? La paginación debe volver a la primera página para evitar mostrar una página vacía o
  inconsistente con el nuevo criterio.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST permitir buscar insumos escribiendo un texto que se compare, de
  forma parcial e insensible a mayúsculas/minúsculas, contra el **nombre** del insumo.
- **FR-002**: El sistema MUST permitir que el mismo texto de búsqueda se compare también, de forma
  parcial e insensible a mayúsculas/minúsculas, contra el **código** del insumo.
- **FR-003**: El sistema MUST devolver en los resultados todo insumo cuyo nombre O código
  coincida parcialmente con el texto ingresado (no exige que ambos coincidan).
- **FR-004**: El sistema MUST permitir filtrar la lista de insumos seleccionando un proveedor
  específico de entre los proveedores activos del catálogo.
- **FR-005**: Cuando hay un proveedor seleccionado en el filtro, el sistema MUST mostrar
  únicamente insumos que tengan una relación activa con ese proveedor.
- **FR-006**: El sistema MUST permitir combinar el filtro de proveedor con el texto de búsqueda y
  con los filtros existentes de tipo de insumo y estado (activo/inactivo), aplicando todos los
  criterios seleccionados a la vez (intersección).
- **FR-007**: El sistema MUST reiniciar la paginación a la primera página cada vez que cambia el
  texto de búsqueda o cualquier filtro (proveedor, tipo, estado).
- **FR-008**: El sistema MUST mostrar un mensaje claro de "sin resultados" cuando la combinación de
  búsqueda y filtros no encuentra ningún insumo.
- **FR-009**: El sistema MUST permitir limpiar el filtro de proveedor de forma independiente de
  los demás filtros y de la búsqueda de texto.
- **FR-010**: El sistema MUST mantener el comportamiento actual de búsqueda por nombre sin
  regresiones (toda búsqueda que hoy encuentra un insumo por nombre debe seguir encontrándolo).

### Key Entities *(include if feature involves data)*

- **Insumo**: Registro del inventario que se busca y filtra en esta pantalla. Atributos
  relevantes para esta spec: nombre y código (ambos ya existentes y únicos por insumo).
- **Proveedor**: Entidad del catálogo de proveedores que puede vincularse a uno o varios insumos.
  Se usa como criterio de filtro.
- **Relación Proveedor–Insumo**: Vínculo (ya existente, definido en spec 106) entre un proveedor y
  un insumo, que puede estar activo o inactivo; determina qué insumos aparecen al filtrar por un
  proveedor dado.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un usuario que conoce únicamente el código de un insumo puede encontrarlo con una
  sola búsqueda, sin necesidad de conocer o adivinar su nombre.
- **SC-002**: Al filtrar por un proveedor específico, el 100% de los insumos mostrados están
  efectivamente vinculados (relación activa) a ese proveedor, y ningún insumo vinculado a ese
  proveedor queda fuera de los resultados.
- **SC-003**: La búsqueda combinada por nombre/código y el filtro por proveedor devuelven
  resultados en menos de 1 segundo percibido por el usuario, para catálogos de hasta 5,000
  insumos (escala típica de PyME).
- **SC-004**: Cero regresiones: toda búsqueda o filtro que funcionaba antes de esta funcionalidad
  (búsqueda por nombre, filtro por tipo, filtro por estado) sigue funcionando igual después.

## Assumptions

- La búsqueda por nombre o código es "contiene" (coincidencia parcial de subcadena/frase exacta)
  e insensible a mayúsculas/minúsculas en ambos campos, igual al comportamiento actual de la
  búsqueda por nombre. Si el usuario escribe varias palabras, se busca esa frase exacta tal cual
  (no se exige que cada palabra individual aparezca en cualquier orden).
- El filtro por proveedor solo considera relaciones proveedor-insumo **activas**; relaciones
  inactivas no hacen que un insumo aparezca al filtrar por ese proveedor.
- El selector de proveedor lista los proveedores activos del catálogo general (no solo los que ya
  tienen algún insumo vinculado), igual al patrón de otros selectores de proveedor ya existentes
  en el sistema.
- El filtro de proveedor es de selección única (un proveedor a la vez), siguiendo el mismo patrón
  de los filtros de tipo de insumo y estado ya existentes en esta pantalla; selección múltiple de
  proveedores queda fuera de alcance de esta spec.
- El alcance se limita a la pestaña "Insumos" del módulo de Inventario; las pestañas "Compras" y
  "Movimientos" no se modifican.
- El diseño técnico de los índices de base de datos necesarios para que la búsqueda combinada y el
  filtro por proveedor respondan con rapidez (SC-003) se define en la fase de planificación técnica
  (`plan.md`), no en esta especificación de negocio.
