# Feature Specification: Exportación e importación masiva de la carta de productos vía Excel

**Feature Branch**: `143-exportacion-importacion-carta-menu`

**Created**: 2026-10-29

**Status**: Draft

**Input**: User description: "Exportación e importación masiva de la carta de productos vía Excel, con alcance limitado a: Productos, Presentaciones y precios, Receta y Adiciones. Fuera de alcance: sabores/grupos de opciones e imágenes de producto. Seguir el patrón ya implementado para inventario (specs 086, 109, 139, 142): exportación a .xlsx, importación asíncrona con seguimiento de job, validación y aplicación fila por fila con commit independiente, reporte de errores descargable, resolución 'buscar o crear' case-insensitive para entidades referenciadas por nombre al crear. El archivo tiene varias hojas (Productos, Presentaciones y precios, Receta, Adiciones) relacionadas por un código de producto."

## Clarifications

### Session 2026-10-29

- Q: ¿El "código de producto" que sirve de referencia cruzada entre hojas del Excel debe ser un campo nuevo y persistente del producto (visible/editable en la UI administrativa), o es un valor generado solo para el archivo exportado sin guardarse como campo propio del producto? → A: Campo persistente, autogenerado por el sistema y visible/editable en la UI administrativa del producto.
- Q: Cuando se reimporta un archivo y, para un producto incluido, la hoja de Presentaciones/Receta/Adiciones ya no trae una fila que antes sí existía para ese producto, ¿el sistema debe eliminar/desactivar esa fila faltante, o dejarla intacta porque la importación solo crea y actualiza? → A: Nunca eliminar por omisión; la importación únicamente crea y actualiza. Quitar una presentación, ítem de receta o adición existente requiere una acción explícita fuera de este flujo (p. ej. desde la UI).
- Q: ¿Debe el sistema impedir que un negocio tenga dos importaciones de carta en curso al mismo tiempo, o puede permitir varias en paralelo? → A: Bloquear; solo se permite una importación de carta en curso a la vez por negocio, igual que el patrón ya usado en la importación de inventario.
- Q: ¿El permiso requerido para exportar/importar la carta debe ser único para ambas acciones, o deben existir permisos separados para exportar e importar? → A: Un solo permiso administrativo habilita ambas acciones (exportar e importar), igual que el patrón ya usado en inventario.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Exportar la carta completa a Excel (Priority: P1)

Un administrador del restaurante quiere obtener en un solo archivo Excel todos los productos de la carta, con sus presentaciones y precios, su receta (insumos que consume) y sus adiciones configuradas, para revisarlos, editarlos en bloque fuera del sistema o compartirlos con otra persona (por ejemplo, quien calcula costos).

**Why this priority**: Es el requisito base: sin poder ver la carta exportada en un formato editable, no hay forma de preparar ni validar un archivo de importación. Además entrega valor por sí sola (respaldo/auditoría de la carta) incluso si la importación no estuviera disponible todavía.

**Independent Test**: Puede probarse exportando la carta de un negocio con productos, variantes, receta y adiciones ya configurados, y verificando que el archivo descargado contiene toda esa información distribuida en las hojas correspondientes, sin necesidad de que la importación exista.

**Acceptance Scenarios**:

1. **Given** una carta con productos, presentaciones/precios, receta y adiciones configurados, **When** el administrador solicita la exportación, **Then** recibe un archivo Excel con una hoja por cada tipo de dato (Productos, Presentaciones y precios, Receta, Adiciones) y cada fila refleja fielmente lo configurado en el sistema.
2. **Given** un producto sin receta ni adiciones configuradas, **When** se exporta la carta, **Then** ese producto aparece en la hoja de Productos y en la de Presentaciones y precios, y simplemente no genera filas en las hojas de Receta ni Adiciones.
3. **Given** una carta sin ningún producto, **When** se exporta, **Then** el sistema entrega un archivo válido con las hojas y encabezados esperados, sin filas de datos.

---

### User Story 2 - Importar cambios masivos a la carta desde Excel (Priority: P2)

Un administrador edita el archivo exportado anteriormente (o uno nuevo basado en el mismo formato) — cambia precios, agrega productos nuevos, ajusta la receta o añade adiciones — y lo vuelve a cargar al sistema para aplicar todos los cambios de una sola vez, en lugar de editar producto por producto desde la interfaz.

**Why this priority**: Es el valor principal del feature (ahorro de tiempo en mantenimiento masivo de la carta), pero depende de que el formato de exportación (US1) ya exista y esté validado.

**Independent Test**: Puede probarse tomando un archivo exportado, modificando algunas filas (precio, nueva fila de producto, nueva fila de receta) y cargándolo, y verificando que los cambios se reflejan en la carta del sistema sin afectar lo que no se tocó.

**Acceptance Scenarios**:

1. **Given** un archivo con una fila de un producto existente con el precio modificado, **When** se importa el archivo, **Then** el precio de esa presentación se actualiza en el sistema y el resto de los datos del producto permanecen sin cambios.
2. **Given** un archivo con una fila de producto con un código que no existe en el sistema, **When** se importa el archivo, **Then** el sistema crea el producto nuevo con los datos indicados.
3. **Given** un archivo con una fila de receta que referencia un insumo inexistente en el inventario, **When** se importa el archivo, **Then** esa fila específica se marca como error, sin afectar la aplicación de las demás filas válidas del archivo.
4. **Given** un archivo con una fila de adición que referencia como "producto adición" un producto que no está marcado como adición, **When** se importa el archivo, **Then** esa fila se marca como error con un motivo claro, y el resto del archivo se sigue procesando.
5. **Given** una importación en curso sobre un archivo con varios cientos de filas, **When** el administrador consulta el estado, **Then** puede ver cuántas filas se han procesado, cuántas se crearon, cuántas se actualizaron y cuántas fallaron, antes de que termine el proceso completo.
6. **Given** una importación que finalizó con algunas filas en error, **When** el administrador lo solicita, **Then** puede descargar un reporte de errores que identifica la fila, la hoja y el motivo de cada falla.

---

### User Story 3 - Corregir y reintentar una importación con errores (Priority: P3)

Después de una importación con filas en error, el administrador corrige el archivo original (usando el reporte de errores como guía) y lo vuelve a cargar, sin duplicar ni afectar las filas que ya se aplicaron correctamente en el intento anterior.

**Why this priority**: Mejora la experiencia de corrección de errores, pero el feature ya es útil sin este flujo de reintento explícito (el administrador podría simplemente volver a exportar y reeditar). Se prioriza después porque depende de que la identificación por código de producto (US1 y US2) ya esté funcionando de forma confiable.

**Independent Test**: Puede probarse realizando una importación con algunas filas inválidas, corrigiendo únicamente esas filas en el archivo y reimportando, verificando que las filas ya aplicadas no se dupliquen ni se alteren y solo se corrijan las que fallaron.

**Acceptance Scenarios**:

1. **Given** una importación previa donde algunas filas de productos se crearon correctamente y otras fallaron, **When** se reimporta el mismo archivo con las filas corregidas, **Then** los productos ya creados no se duplican (se identifican por su código) y las filas corregidas se aplican correctamente.

---

### Edge Cases

- ¿Qué pasa si una fila de "Presentaciones y precios" referencia un código de producto que no aparece en la hoja Productos del mismo archivo (ni existe ya en el sistema)? → La fila debe marcarse como error explicando que el producto referenciado no existe.
- ¿Qué pasa si dentro del mismo archivo hay dos filas de producto con el mismo código? → Ambas filas deben marcarse como error (igual que el patrón ya usado para códigos duplicados en inventario).
- ¿Qué pasa si una fila de "Adiciones" referencia como producto-adición el mismo código del producto que la ofrece? → Debe marcarse como error (un producto no puede ser adición de sí mismo).
- ¿Qué pasa si se intenta usar como "producto adición" un producto que existe pero no está marcado como adición? → La fila falla indicando que el producto referenciado no está habilitado como adición.
- ¿Qué pasa si una fila de "Receta" referencia una combinación producto+presentación que no existe (ni en el archivo ni en el sistema)? → La fila se marca como error.
- ¿Qué pasa si se interrumpe la importación a mitad de proceso (por ejemplo, se cancela)? → Las filas ya aplicadas antes de la interrupción permanecen aplicadas; las filas restantes no se procesan y el estado del proceso refleja que fue interrumpido.
- ¿Qué pasa si el archivo tiene hojas faltantes, renombradas o con columnas en un orden distinto al esperado? → El sistema debe rechazar el archivo completo antes de procesar ninguna fila, indicando qué hoja o estructura no coincide con el formato esperado.
- ¿Qué pasa si una fila de precio contiene un valor negativo o no numérico? → La fila se marca como error de validación, sin afectar otras filas.
- ¿Qué pasa si se importa un archivo que solo contiene algunas de las hojas (por ejemplo, solo Productos, sin Receta ni Adiciones)? → Es un caso válido: solo se procesan las hojas presentes.
- ¿Qué pasa si un producto ya tenía presentaciones, ítems de receta o adiciones configurados y el archivo reimportado ya no incluye alguna de esas filas? → Esas filas no se eliminan ni desactivan automáticamente; la importación solo crea y actualiza, nunca elimina por omisión.
- ¿Qué pasa si el administrador intenta iniciar una nueva importación de carta mientras ya hay una en curso para el mismo negocio? → El sistema rechaza el intento e indica que ya hay una importación de carta en curso.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST permitir exportar la carta de productos a un archivo Excel con hojas separadas para Productos, Presentaciones y precios, Receta y Adiciones.
- **FR-002**: Cada hoja exportada MUST incluir todos los campos relevantes de su entidad (Productos: código, nombre, categoría, tipo de preparación, descripción, flags de activo/disponible/rastrea inventario/es adición/visible en QR; Presentaciones y precios: código de producto, presentación, SKU, nombre comercial, precio, orden, activo; Receta: código de producto, presentación, insumo, cantidad; Adiciones: código de producto, código de producto-adición).
- **FR-003**: El sistema MUST asignar o reutilizar un código único por producto que sirva como identificador de referencia cruzada entre las hojas del archivo. Este código MUST ser un campo persistente del producto, autogenerado por el sistema al crearse, visible en la administración de la carta y editable manualmente por un administrador si lo requiere.
- **FR-004**: El sistema MUST permitir importar un archivo Excel con el mismo formato de la exportación para crear o actualizar productos, presentaciones/precios, receta y adiciones.
- **FR-005**: Al importar, el sistema MUST interpretar una fila con un código de producto ya existente como una actualización de ese producto, y una fila con un código nuevo como la creación de un producto nuevo.
- **FR-005a**: La importación MUST ser estrictamente de creación/actualización: si una presentación, ítem de receta o adición existía previamente para un producto y su fila ya no aparece en el archivo importado, el sistema MUST dejarla intacta (no eliminarla ni desactivarla automáticamente por su ausencia en el archivo).
- **FR-006**: El sistema MUST validar y aplicar cada fila de forma independiente, de manera que el error de una fila no impida la aplicación de las demás filas válidas del archivo.
- **FR-007**: El sistema MUST procesar las hojas en el orden de dependencia Productos → Presentaciones y precios → Receta → Adiciones, de modo que una fila dependiente pueda referenciar una fila creada en el mismo archivo en una hoja anterior.
- **FR-008**: Al importar una fila de Receta, el sistema MUST resolver el insumo referenciado contra el inventario existente (por nombre o código) y marcar la fila como error si el insumo no existe.
- **FR-009**: Al importar una fila de Adiciones, el sistema MUST validar que el producto referenciado como adición exista y esté marcado como producto-adición, y que no sea el mismo producto que lo ofrece; en caso contrario, la fila se marca como error.
- **FR-010**: El sistema MUST rechazar la importación completa antes de aplicar cualquier fila si la estructura general del archivo (hojas esperadas, encabezados de columnas) no corresponde al formato esperado.
- **FR-011**: El sistema MUST detectar códigos de producto duplicados dentro del mismo archivo de importación y marcar como error todas las filas afectadas por esa duplicidad.
- **FR-012**: El sistema MUST permitir consultar el progreso de una importación en curso, incluyendo el total de filas, cuántas se han creado, actualizado y fallado hasta el momento.
- **FR-012a**: El sistema MUST impedir que un mismo negocio tenga más de una importación de carta en curso simultáneamente; si ya hay una en proceso, un intento de iniciar otra MUST ser rechazado indicando que ya existe una importación en curso.
- **FR-013**: El sistema MUST generar, al finalizar una importación, un reporte descargable de errores que identifique la hoja, la fila y el motivo de cada fila fallida.
- **FR-014**: El sistema MUST permitir reintentar una importación con un archivo corregido sin duplicar los productos, presentaciones, recetas o adiciones ya aplicados en un intento anterior, usando el código de producto como identificador estable.
- **FR-015**: El sistema MUST excluir de esta exportación/importación los sabores (grupos de opciones y opciones) y las imágenes de producto, por quedar fuera del alcance de esta funcionalidad.
- **FR-016**: Solo los usuarios con permisos administrativos sobre la carta de productos MUST poder exportar o importar este archivo. Este MUST ser un único permiso que habilite ambas acciones (exportar e importar), sin distinción entre ellas.

### Key Entities *(include if feature involves data)*

- **Producto**: Representa un plato o artículo de la carta. Atributos relevantes para esta funcionalidad: código de referencia (campo persistente, autogenerado al crear el producto, visible y editable por un administrador en la UI), nombre, categoría, tipo de preparación, descripción, y los indicadores de activo, disponible, si rastrea inventario, si es una adición ofrecible y si es visible en el menú QR.
- **Presentación y precio**: Representa una variante vendible de un producto (por ejemplo, un tamaño), con su propio precio, identificador comercial opcional, orden de aparición y estado activo. Se relaciona con un único producto y con una presentación del catálogo general de presentaciones.
- **Receta (ítem de receta)**: Representa qué insumo de inventario y en qué cantidad consume una presentación específica de un producto al prepararse o venderse.
- **Adición**: Representa la relación entre un producto y otro producto habilitado como adición, indicando que este último puede ofrecerse como extra del primero.
- **Reporte de errores de importación**: Representa el detalle de las filas que no pudieron aplicarse durante una importación, con la hoja, número de fila y motivo del error.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un administrador puede exportar la carta completa de productos (hasta varios cientos de productos con sus presentaciones, receta y adiciones) en un único archivo en menos de 30 segundos.
- **SC-002**: Un administrador puede editar precios de decenas de presentaciones a la vez y aplicarlos todos mediante una sola importación, en lugar de editarlos uno por uno, reduciendo el tiempo de actualización masiva de precios en al menos 80% frente a la edición manual producto por producto.
- **SC-003**: Al importar un archivo con errores parciales, el 100% de las filas válidas se aplican correctamente aunque existan filas inválidas en el mismo archivo.
- **SC-004**: El reporte de errores permite a un administrador identificar y corregir la causa de una fila fallida sin necesidad de soporte técnico, en el 90% de los casos.
- **SC-005**: Reimportar un archivo previamente corregido no genera productos, presentaciones, recetas ni adiciones duplicadas.

## Assumptions

- Se sigue el mismo patrón ya validado para la exportación/importación masiva de inventario (procesamiento asíncrono con seguimiento de progreso, validación fila por fila con aplicación independiente, resolución "buscar o crear" para referencias por nombre al crear, reporte de errores descargable), adaptado a un archivo de varias hojas relacionadas en lugar de una sola tabla.
- El código de producto usado como identificador de referencia cruzada entre hojas es un dato administrativo, no visible para el cliente final en el menú.
- Los insumos de inventario referenciados en la hoja de Receta deben existir previamente en el inventario; esta funcionalidad no crea insumos nuevos (se reutiliza el flujo de importación de inventario ya existente para eso).
- Los sabores (grupos de opciones y sus opciones) y las imágenes de producto quedan explícitamente fuera de alcance de esta funcionalidad y podrán abordarse en una iteración posterior.
- El catálogo de presentaciones (nombres como "Pequeño", "Mediano", "Grande") puede resolverse por nombre de forma similar a como se resuelven unidades o proveedores en el import de inventario, creando la presentación si no existe aún en el catálogo global.
- La actualización de un producto existente mediante importación reemplaza los valores de los campos presentes en el archivo para ese producto, presentación, receta o adición, siguiendo el mismo criterio ya usado en el import de inventario para filas de actualización.
