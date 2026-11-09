# Feature Specification: Fusión de las hojas Productos y Presentaciones/precios en el Excel de la carta

**Feature Branch**: `155-fusion-hojas-productos-precios-excel`

**Created**: 2026-11-09

**Status**: Draft

**Input**: User description: "Fusionar las hojas 'Productos' y 'Presentaciones y precios' del Excel de exportación/importación masiva de la carta (spec 143) en una sola hoja 'Productos y precios', para que el usuario no tenga que navegar entre dos hojas guiándose por código/nombre para asignar precios. Las hojas 'Receta' y 'Adiciones' quedan exactamente igual que en la spec 143. El archivo pasa de 4 hojas a 3. Reglas acordadas: (1) si las columnas de producto difieren entre filas del mismo código, esas filas fallan por inconsistencia; (2) toda fila debe traer presentación y precio completos, un producto sin ninguna presentación configurada no se puede crear/actualizar por esta vía; (3) corte directo de formato, el archivo de 4 hojas de la spec 143 deja de ser válido para reimportar; (4) Receta y Adiciones no cambian; (5) todo lo demás de la spec 143 (permisos, job asíncrono, validación fila por fila con commit independiente, reporte de errores, buscar-o-crear case-insensitive, código de producto persistente/editable, reintento sin duplicar, bloqueo de una importación en curso por negocio) se mantiene igual."

## Clarifications

### Session 2026-11-09

- Q: ¿Qué debe hacer el sistema si dos o más filas de la hoja fusionada comparten el mismo código de producto pero tienen valores distintos en las columnas de producto (nombre, categoría, flags, etc.)? → A: Marcar como error todas las filas afectadas por esa inconsistencia, sin aplicar ninguna de ellas.
- Q: ¿Debe la hoja fusionada admitir representar un producto que todavía no tiene ninguna presentación/precio configurado? → A: No; toda fila debe traer presentación y precio completos. Un producto sin presentaciones no se puede crear ni actualizar por esta vía hasta que el archivo le defina al menos una.
- Q: ¿El sistema debe seguir aceptando para reimportar un archivo exportado con el formato anterior de 4 hojas (spec 143)? → A: No; corte directo. Un archivo con el formato anterior ya no es válido y el usuario debe volver a exportar con el nuevo formato de 3 hojas.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Asignar precios sin cambiar de hoja (Priority: P1)

Un administrador del restaurante exporta la carta a Excel para actualizar precios. En lugar de ubicar cada producto en la hoja "Productos" y luego buscar su código en la hoja "Presentaciones y precios" para editar el precio correspondiente, ve en una sola hoja el nombre, la categoría y el precio de cada presentación, y puede editar el precio directamente en esa misma fila.

**Why this priority**: Es el problema concreto que reportó el usuario y la razón de ser de este feature: la navegación entre dos hojas guiándose por código/nombre es el principal punto de fricción al mantener la carta por Excel.

**Independent Test**: Puede probarse exportando la carta de un negocio con varios productos y presentaciones, y verificando que el archivo descargado trae una sola hoja con los datos de producto y de presentación/precio combinados en la misma fila, sin necesidad de que la importación de esa hoja esté funcionando todavía.

**Acceptance Scenarios**:

1. **Given** una carta con productos que tienen una o varias presentaciones con precio, **When** el administrador exporta la carta, **Then** recibe un archivo con una hoja "Productos y precios" donde cada fila corresponde a una presentación y contiene tanto los datos del producto como los de esa presentación (incluido el precio), sin necesidad de consultar otra hoja.
2. **Given** un producto con tres presentaciones distintas, **When** se exporta la carta, **Then** aparecen tres filas para ese producto en la hoja fusionada, cada una con los mismos datos de producto repetidos y los datos propios de su presentación.

---

### User Story 2 - Editar precios masivamente desde la hoja fusionada (Priority: P2)

El administrador edita el precio de varias presentaciones directamente en la hoja fusionada y reimporta el archivo para aplicar los cambios de una sola vez.

**Why this priority**: Es el valor principal del feature (ahorro de tiempo real al editar precios), pero depende de que el formato fusionado de exportación (US1) ya exista.

**Independent Test**: Puede probarse tomando un archivo exportado con el nuevo formato, modificando el precio en varias filas y reimportando, verificando que los precios se actualizan sin afectar el resto de los datos del producto ni de otras presentaciones.

**Acceptance Scenarios**:

1. **Given** un archivo con una fila de una presentación existente con el precio modificado, **When** se importa el archivo, **Then** el precio de esa presentación se actualiza y el resto de los datos de ese producto y de sus otras presentaciones permanecen sin cambios.
2. **Given** un archivo con una fila cuyo código de producto no existe en el sistema, **When** se importa el archivo, **Then** el sistema crea el producto nuevo junto con la presentación y el precio indicados en esa misma fila.
3. **Given** un archivo con varias filas que comparten el mismo código de producto y los mismos valores en las columnas de producto, **When** se importa el archivo, **Then** el producto se crea o actualiza una sola vez con esos datos y se crea o actualiza una presentación por cada fila.

---

### User Story 3 - Detectar datos de producto inconsistentes entre filas (Priority: P3)

El administrador edita por error el nombre o la categoría de un producto solo en una de sus filas (dejando las demás presentaciones del mismo producto con el valor anterior) y al importar el sistema le avisa claramente del error en lugar de aplicar un valor al azar.

**Why this priority**: Es una protección necesaria dado que ahora los datos de producto se repiten en varias filas, pero el feature ya entrega valor sin este flujo de detección si el administrador es cuidadoso al editar; se prioriza después porque depende de que la fusión de hojas (US1 y US2) ya esté funcionando.

**Independent Test**: Puede probarse armando un archivo donde dos filas del mismo código de producto difieran en una columna de producto (por ejemplo, el nombre) y verificando que ambas filas se reportan como error, mientras que filas de otros productos sin ese problema se aplican con normalidad.

**Acceptance Scenarios**:

1. **Given** un archivo con dos filas del mismo código de producto que difieren en el nombre, la categoría o algún otro dato de producto, **When** se importa el archivo, **Then** todas las filas de ese código se marcan como error indicando la inconsistencia, y ninguna de ellas se aplica.
2. **Given** un archivo con esas filas corregidas para que los datos de producto coincidan en todas, **When** se reimporta, **Then** el producto y sus presentaciones se aplican correctamente.

---

### Edge Cases

- ¿Qué pasa si una fila de la hoja fusionada trae los datos de producto completos pero deja vacía la presentación o el precio? → La fila se marca como error: toda fila debe traer presentación y precio completos.
- ¿Qué pasa si un producto ya existente en el sistema no tiene todavía ninguna presentación configurada y el administrador quiere crearle una por esta vía? → Debe incluir al menos una fila completa (producto + presentación + precio) para ese código; no es posible crear o actualizar un producto sin presentación a través de este archivo.
- ¿Qué pasa si dentro del mismo archivo hay dos filas del mismo código de producto con los mismos datos de producto pero presentaciones distintas? → Es el caso normal de un producto con varias presentaciones; cada fila crea o actualiza su propia presentación bajo el mismo producto.
- ¿Qué pasa si dentro del mismo archivo hay dos filas del mismo código de producto con datos de producto distintos (por ejemplo, nombre o categoría diferentes)? → Todas las filas de ese código se marcan como error por inconsistencia, sin aplicar ninguna.
- ¿Qué pasa si se intenta importar un archivo exportado con el formato anterior de 4 hojas (spec 143)? → El sistema rechaza la importación completa indicando que la estructura del archivo no corresponde al formato esperado (3 hojas), igual que ya ocurre hoy ante hojas o encabezados que no coinciden.
- ¿Qué pasa con una fila de "Receta" o "Adiciones" que referencia un código de producto creado en la misma hoja fusionada? → Se resuelve igual que antes: la hoja de productos y precios se procesa completa primero, y sus filas aplicadas quedan disponibles para que Receta y Adiciones las referencien, sin cambios respecto a la spec 143.
- ¿Qué pasa si una fila de precio contiene un valor negativo o no numérico, o el orden no es un entero válido? → La fila se marca como error de validación, igual que en la spec 143.
- ¿Qué pasa si se exporta un producto que en el sistema no tiene ninguna presentación? → Queda fuera del alcance de este feature resolver cómo se representa ese caso en la exportación; ver Assumptions.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST exportar la carta de productos a un archivo Excel con 3 hojas: "Productos y precios", "Receta" y "Adiciones" (en vez de las 4 hojas de la spec 143).
- **FR-002**: La hoja "Productos y precios" MUST tener una fila por cada presentación/variante de producto, incluyendo en cada fila tanto los campos de producto (código, nombre, categoría, tipo de preparación, descripción, activo, disponible, rastrea inventario, es adición, visible en menú QR) como los campos de esa presentación (presentación, SKU, nombre comercial, precio, orden, activo de la presentación).
- **FR-003**: El sistema MUST mantener sin cambios el contenido, columnas y reglas de validación de las hojas "Receta" y "Adiciones" respecto a la spec 143.
- **FR-004**: Al importar la hoja "Productos y precios", el sistema MUST exigir que cada fila traiga completos tanto los datos de producto como la presentación y el precio; una fila que omita la presentación o el precio MUST marcarse como error.
- **FR-005**: Al importar, si dos o más filas comparten el mismo código de producto, el sistema MUST validar que los valores de todas las columnas de producto (nombre, categoría, tipo de preparación, descripción y los 5 flags booleanos) sean idénticos entre esas filas; si alguna difiere, todas las filas de ese código MUST marcarse como error indicando la inconsistencia, y ninguna de ellas se aplica.
- **FR-006**: Cuando las filas de un mismo código de producto son consistentes entre sí, el sistema MUST crear o actualizar el producto una sola vez a partir de esos datos, y crear o actualizar una presentación por cada fila, igual que si fueran filas independientes de la hoja "Presentaciones y precios" de la spec 143.
- **FR-007**: El sistema MUST procesar las hojas en el orden de dependencia Productos y precios → Receta → Adiciones, de modo que una fila dependiente pueda referenciar un producto o presentación creados en una fila anterior de la hoja "Productos y precios" del mismo archivo.
- **FR-008**: El sistema MUST rechazar la importación completa, antes de aplicar cualquier fila, si el archivo no corresponde a la estructura esperada de 3 hojas (incluyendo un archivo exportado con el formato anterior de 4 hojas de la spec 143), igual que ya ocurre hoy ante hojas o encabezados que no coinciden.
- **FR-009**: El sistema MUST mantener, adaptados a las 3 hojas, todos los demás comportamientos ya definidos en la spec 143: permiso administrativo único para exportar e importar, procesamiento asíncrono con seguimiento de progreso, validación y aplicación fila por fila con commit independiente (de forma que el error de una fila no impida la aplicación de las demás filas válidas), resolución "buscar o crear" case-insensitive para categoría y presentación, código de producto persistente/autogenerado/editable como identificador de referencia cruzada, reporte de errores descargable que identifique hoja/fila/motivo, reintento de una importación corregida sin duplicar lo ya aplicado, y bloqueo de más de una importación de carta en curso por negocio.
- **FR-010**: El sistema MUST excluir de esta exportación/importación los sabores (grupos de opciones y opciones) y las imágenes de producto, igual que en la spec 143.

### Key Entities *(include if feature involves data)*

- **Producto**: Igual que en la spec 143 (código de referencia, nombre, categoría, tipo de preparación, descripción, flags de activo/disponible/rastrea inventario/es adición/visible en QR). En la hoja fusionada, sus datos aparecen repetidos en cada fila de presentación que le corresponde.
- **Presentación y precio**: Igual que en la spec 143 (presentación, SKU, nombre comercial, precio, orden, activo), ahora en la misma fila que los datos del producto al que pertenece en vez de en una hoja separada.
- **Receta (ítem de receta)** y **Adición**: Sin cambios respecto a la spec 143.
- **Reporte de errores de importación**: Sin cambios respecto a la spec 143, salvo que el nombre de hoja reportado para los errores de producto o presentación ahora es "Productos y precios" en vez de "Productos" o "Presentaciones y precios" por separado.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un administrador puede identificar y editar el precio de cualquier presentación de un producto sin necesidad de consultar o navegar a otra hoja del archivo.
- **SC-002**: El tiempo que toma a un administrador actualizar los precios de decenas de presentaciones usando el archivo exportado se reduce frente al flujo de dos hojas separadas de la spec 143, al eliminar por completo el paso de buscar el código de producto en una segunda hoja.
- **SC-003**: Al importar un archivo con filas de un mismo código de producto que tienen datos de producto inconsistentes entre sí, el 100% de esas filas se reportan como error, y el resto de filas válidas del archivo se aplica sin verse afectado.
- **SC-004**: Un archivo exportado con el formato anterior de 4 hojas (spec 143) es rechazado íntegramente al intentar reimportarlo, con un mensaje que indica que la estructura del archivo no corresponde al formato esperado.
- **SC-005**: Reimportar sin cambios un archivo recién exportado con el nuevo formato no genera productos, presentaciones, recetas ni adiciones duplicadas.

## Assumptions

- Esta spec reemplaza, para la hoja de productos, el formato de exportación/importación definido en la spec 143; no modifica el código ya implementado de esa spec como tal, sino que se construye como una evolución del mismo feature.
- Un producto que en el sistema no tiene todavía ninguna presentación configurada queda, por ahora, fuera de lo que esta vía de exportación/importación puede representar o gestionar: para efectos de este feature se asume que todo producto relevante para exportar/editar por Excel tiene al menos una presentación con precio. Resolver cómo tratar en la exportación un producto sin presentaciones (si los hay en el sistema) se deja como una decisión de implementación menor, no como un requisito de negocio de esta spec.
- Se mantiene el resto de supuestos ya documentados en la spec 143 (el catálogo de presentaciones se resuelve por nombre igual que categorías/unidades/proveedores en el import de inventario; la actualización de un producto o presentación existente reemplaza los valores de los campos presentes en el archivo para esa fila; los insumos de la hoja Receta deben existir previamente en el inventario).
- El corte directo de formato implica que, al desplegar este feature, los usuarios deben volver a exportar la carta para obtener un archivo válido para reimportar; no se requiere mantener compatibilidad con archivos ya exportados bajo la spec 143.
