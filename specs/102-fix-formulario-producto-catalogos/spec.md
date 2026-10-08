# Feature Specification: Corrección y mejora de rendimiento del formulario de crear/editar producto (receta, tamaños y catálogos)

**Feature Branch**: `102-fix-formulario-producto-catalogos`

**Created**: 2026-10-07

**Status**: Draft

**Naturaleza de esta spec**: **spec de corrección y mejora de rendimiento**, no una funcionalidad
nueva desde cero — sigue el mismo patrón que las specs
[072](../072-fix-deteccion-turno-caja/spec.md),
[097](../097-categoria-nombre-productos/spec.md) y
[098](../098-selector-insumos-receta/spec.md). Esta spec cita nombres de archivo, función y línea
del código actual (`pos-heladeria`) porque son el contrato observable que se está corrigiendo, no
una fuga de detalles de implementación. El punto 1 (ver abajo) es, en concreto, el seguimiento
cosmético que la spec 098 dejó explícitamente fuera de alcance en su FR-009 ("la visualización del
nombre/unidad de un insumo ya asociado a una fila existente... puede abordarse como una spec de
corrección independiente si el negocio lo decide más adelante") — esta spec es esa decisión. Los
puntos 2, 3 y 4 son defectos y mejoras adicionales reportados junto con el punto 1, acotados
exclusivamente al formulario de crear/editar producto. No aplica una nueva entrada en
`registro-de-anomalias.md`: ninguno de los cuatro puntos reabre una regla de negocio ya decidida
sobre qué insumos, categorías o presentaciones son válidos para un producto, ni sobre cómo se
guarda — solo corrige cómo se **carga y se muestra** esa información en el formulario.

**Autorización de negocio (Principio I y Principio II de la
[Constitución](../../.specify/memory/constitution.md))**: reportado directamente por el
dueño/desarrollador del proyecto el 2026-10-07, con los cuatro problemas descritos, causa probable
y prioridad relativa ya definidas en el reporte original. No reabre ninguna regla de negocio sobre
qué insumos/categorías/presentaciones pueden asociarse a un producto: el alcance es exclusivamente
la carga y visualización en el formulario, no la forma en que se guarda (crear/editar sigue
guardando todo en una sola petición, sin cambios).

**Input**: User description (verbatim, resumen): "necesito corregir un bug y mejorar el
rendimiento del formulario de crear/editar producto. Son cuatro problemas: (1) el insumo
seleccionado en 'Insumos fijos' a veces se muestra con el texto genérico 'Insumo…' en vez de su
nombre real, cuando el insumo no está entre los primeros insumos que trae el selector por defecto
(tenants con más de 100 insumos activos); (2) abrir el formulario para editar un producto con
varios tamaños tarda más mientras más tamaños tiene, porque la receta y los grupos de opciones de
cada tamaño se cargan uno a la vez en vez de todos al mismo tiempo; (3) los selectores de insumos,
categorías y presentaciones solo permiten elegir entre los primeros 100 registros activos del
catálogo, sin tope fijo de cantidad; (4) si otra persona crea una categoría, un insumo o una
presentación nueva mientras el formulario ya está abierto en otra sesión, esa novedad no aparece
hasta que se recarga la página completa. Prioridad sugerida: 1, 2, 3, 4. No se requiere cambiar la
forma en que se guarda el producto; el alcance es solo la carga y visualización en el formulario."

**Causa raíz (confirmada leyendo el código real de `pos-heladeria`)**:

- **Punto 1 (bug visual del insumo)**: el selector de "Insumos fijos" de cada fila de receta
  (`modules/products/pages/product-form.component.ts:335-337`) recibe sus opciones desde
  `inventoryOptions()` (`:564-566`), construido únicamente a partir de
  `InventoryService.allItems()` — la misma página fija de hasta 100 insumos documentada en la spec
  098. El componente genérico `app-searchable-select`
  (`shared/searchable-select/searchable-select.component.ts:118-120`) resuelve la etiqueta visible
  así: `this.options.find((o) => o.id === this.value())?.label ?? ''`, y su plantilla (línea 46)
  hace `{{ selectedLabel() || placeholder }}`. Si el `inventory_item_id` ya guardado no está dentro
  de las opciones cargadas, `selectedLabel()` devuelve cadena vacía y el botón cae al placeholder
  literal `"Insumo…"`, aunque la fila sí tenga un id real y una cantidad guardada correcta. El mismo
  mecanismo (`unitLookup` en `:559-561`, construido con `buildUnitLookup(this.inventoryService.allItems(), ...)` de
  `modules/inventory/services/unit-lookup.ts:24-47`) también deja en blanco el nombre/unidad del
  insumo dentro del desglose de consumo de una opción (`groupBreakdown()` → `lookup.nameOf(...)` en
  `:830`), dentro del mismo formulario.
- **Punto 2 (carga secuencial de tamaños)**: `ProductService.getProductDraft`
  (`modules/products/services/product.service.ts:445-494`) usa un `for...of` con `await`
  (`:453-469`) que recorre las variantes activas una por una. Dentro de cada variante, receta y
  grupos de opciones sí se piden en paralelo (`Promise.all([this.getVariantRecipe(v.id),
  this.getVariantOptionGroups(v.id)])`), pero la variante 2 no empieza sus dos peticiones hasta que
  la variante 1 termina las suyas — el tiempo total escala linealmente con el número de tamaños.
  Invocado desde `ProductFormComponent.ngOnInit` (`:920`).
- **Punto 3 (tope fijo de 100 en tres catálogos)**: el fix de búsqueda server-side de la spec 098
  (`InventoryService.searchActiveItems()`, `inventory.service.ts:193-197`) **ya existe pero solo se
  usa en la búsqueda remota de la fila de receta** (`product-form.component.ts:574-577`) — el
  selector base (`inventoryOptions()`) sigue alimentado por `allItems()`/`allItemsQuery`
  (`inventory.service.ts:133-140`, `GET /items?size=100`, sin `search`). Los selectores de
  categoría y presentación nunca tuvieron un fix equivalente: `CategoryService.allQuery`
  (`modules/categories/services/category.service.ts:47-52`, `GET ?size=100`) y
  `PresentationService.allQuery` (`modules/presentations/services/presentation.service.ts:46-51`,
  `GET ?size=100`) no tienen parámetro `search` en ningún punto del servicio, y alimentan
  directamente el selector de categoría (`product-form.component.ts:142`) y el de presentación
  (`presentationOptionsFor()`, `:589-603`).
- **Punto 4 (sin refresco en segundo plano)**: los tres catálogos se cargan una sola vez por sesión
  de la pestaña, con guarda de "si ya tiene datos no vuelvas a pedir"
  (`product-form.component.ts:906-916`: `allCategories().length === 0 ? loadAllCategories() :
  null`, igual para `allItems()`/`loadAllItems()` y `allPresentations()`/`loadAllPresentations()`).
  Cada `loadX()` solo activa una vez una bandera (`wantsAll`) que habilita la query
  (`inventory.service.ts:182-185`, patrón análogo en categorías y presentaciones); no existe
  `setInterval`, listener de `visibilitychange`/`focus`, ni websocket en ninguno de los tres
  servicios. Dentro de la misma pestaña, crear un registro desde el propio módulo (p. ej. crear una
  categoría) sí invalida la query (`queryKey: ['categories']` cubre a `allQuery`) y se refleja; entre
  pestañas/sesiones distintas no hay ninguna señal de invalidación — el registro nuevo es invisible
  hasta recargar toda la aplicación.

---

## Clarifications

### Session 2026-10-08

- Q: Spec 102 ya está implementada y la Historia 2 eligió explícitamente una corrección 100%
  frontend (research.md D2 rechazó un endpoint de backend combinado por quedar fuera de alcance).
  Al señalar que un `JOIN` del lado del backend sería más eficiente que peticiones separadas de
  variantes/receta/grupos de opciones, ¿ese cambio entra a esta misma spec o se registra como una
  spec de seguimiento aparte? → A: Se registra como candidato para una spec de seguimiento
  independiente; esta spec (102) no se reabre ni cambia su alcance ya implementado.
- Q: Tras ver en el panel de red del navegador que el sondeo periódico de la Historia 4 repite
  las peticiones a `categories`/`items`/`presentations` cada 2 minutos, el dueño/desarrollador del
  proyecto pidió explícitamente eliminar ese sondeo: prefiere que el usuario recargue la página
  manualmente para ver catálogos nuevos de otra sesión, en vez de mantener una conexión de
  sondeo abierta de fondo. → A: Se retira la Historia 4 completa (sondeo en segundo plano) de
  esta spec. FR-012/FR-013/FR-014 y SC-004 quedan sin vigencia; el formulario vuelve a depender
  de una recarga manual para ver catálogos creados por otra sesión, igual que antes de esta
  spec. No aplica entrada en `registro-de-anomalias.md`: es una decisión tomada por el propio
  dueño/desarrollador del proyecto sobre una funcionalidad de esta misma spec, no la reapertura
  de una regla de negocio de otra spec.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - El insumo ya guardado en la receta siempre muestra su nombre real (Priority: P1)

Un Administrador que abre para editar un producto con "Maneja inventario" activo y una receta
("Insumos fijos") ya guardada ve, para cada insumo fijo, su nombre real y su cantidad guardada —
nunca el texto genérico "Insumo…" — sin importar en qué posición del catálogo completo de insumos
del tenant esté ese insumo ni cuántos insumos activos tenga el tenant. Lo mismo aplica al desglose
de consumo de insumo que muestra una opción de un grupo de opciones dentro del mismo formulario.

**Why this priority**: es el defecto que ya está afectando producción y el seguimiento directo que
la spec 098 dejó pendiente (su FR-009). Es **P1** porque, aunque la cantidad guardada es correcta,
el Administrador no puede confirmar qué insumo real está fijado en la receta ni auditar el costeo
del producto sin adivinar o volver a abrir Inventario para cruzar el id, lo que afecta la confianza
operativa en un dato de costeo ya guardado.

**Independent Test**: en un tenant con más de 100 insumos activos, crear o guardar una receta con
un insumo que quede fuera de la primera página de 100 (por el orden en que los devuelve el
backend), reabrir el formulario de edición de ese producto y verificar que el selector de "Insumos
fijos" muestra el nombre real de ese insumo, no "Insumo…".

**Acceptance Scenarios**:

1. **Given** un producto tiene una receta guardada con un insumo que no está entre los primeros 100
   insumos activos del tenant, **When** abro el formulario de edición de ese producto, **Then** el
   selector de "Insumos fijos" muestra el nombre real de ese insumo, con su cantidad guardada.
2. **Given** la misma situación anterior, **When** reviso el desglose de consumo de insumo de una
   opción de grupo de opciones que referencia ese mismo insumo, **Then** también se muestra el
   nombre y unidad real del insumo, no un valor vacío.
3. **Given** un insumo fijo de la receta sí está entre los primeros insumos cargados por defecto (el
   caso que hoy ya funciona), **When** abro el formulario de edición, **Then** el comportamiento
   visible no cambia: sigo viendo su nombre real con normalidad.
4. **Given** un insumo referenciado por una receta guardada fue desactivado después de guardarse,
   **When** abro el formulario de edición, **Then** el selector sigue mostrando su nombre real (para
   no perder trazabilidad de lo ya guardado), aunque ese insumo ya no aparezca como opción
   seleccionable para agregarse de nuevo.

---

### User Story 2 - Abrir un producto con varios tamaños no se vuelve más lento mientras más tamaños tiene (Priority: P2)

Un Administrador que abre para editar un producto con varios tamaños (variantes) espera que el
formulario quede listo para usarse en un tiempo que no depende de cuántos tamaños tenga ese
producto, porque la receta y los grupos de opciones de todos los tamaños se cargan en simultáneo.

**Why this priority**: es **P2** porque degrada la experiencia de edición (y el tiempo que un
Administrador pasa esperando) en productos con muchos tamaños, pero no bloquea ni corrompe ningún
dato — a diferencia del punto 1, es un problema de rendimiento perceptible, no de integridad de
datos ya guardados.

**Independent Test**: medir el tiempo entre abrir el formulario de edición y que la receta/grupos
de opciones de todos los tamaños estén visibles, para un producto con 2 tamaños y para uno con 8-10
tamaños; verificar que el tiempo no crece de forma proporcional al número de tamaños.

**Acceptance Scenarios**:

1. **Given** un producto tiene 8 tamaños activos, cada uno con su propia receta y grupos de
   opciones, **When** abro el formulario de edición, **Then** las peticiones de receta y grupos de
   opciones de los 8 tamaños se disparan al mismo tiempo, no una tras otra.
2. **Given** la misma situación anterior, **When** comparo el tiempo total de carga contra el de un
   producto con solo 2 tamaños, **Then** el tiempo no escala linealmente con el número de tamaños.
3. **Given** uno de los tamaños falla al cargar su receta o sus grupos de opciones (error de red),
   **When** reviso el formulario, **Then** los demás tamaños que sí cargaron correctamente quedan
   disponibles para usarse, y el tamaño que falló muestra un error puntual con opción de reintentar,
   sin bloquear el resto del formulario.

---

### User Story 3 - Encontrar y elegir cualquier insumo, categoría o presentación activa, sin tope fijo (Priority: P3)

Un Administrador que crea o edita un producto en un tenant con más de 100 insumos, más de 100
categorías o más de 100 presentaciones activas puede escribir en el selector correspondiente y
encontrar y elegir cualquier registro activo existente, sin importar en qué posición del catálogo
completo esté ni cuántos registros tenga el tenant en total — con el mismo comportamiento de
búsqueda en los tres selectores.

**Why this priority**: es **P3** porque, a diferencia del punto 1, no hay evidencia de que ya esté
bloqueando producción (el reporte dice que ya existe una búsqueda remota para insumos), pero limita
la capacidad de crear/editar productos correctamente en tenants con catálogos grandes de insumos,
categorías o presentaciones.

**Independent Test**: en un tenant con más de 100 insumos, más de 100 categorías y más de 100
presentaciones activas, abrir el formulario de producto y, para cada uno de los tres selectores,
buscar por texto un registro que exista fuera de los primeros 100 y verificar que aparece y puede
seleccionarse.

**Acceptance Scenarios**:

1. **Given** un tenant tiene más de 100 insumos activos, **When** escribo en el selector de
   "Insumos fijos" el nombre (o parte del nombre) de un insumo que exista fuera de los primeros 100,
   **Then** el selector lo encuentra y permite seleccionarlo.
2. **Given** un tenant tiene más de 100 categorías activas, **When** escribo en el selector de
   categoría el nombre de una categoría que exista fuera de las primeras 100, **Then** el selector
   la encuentra y permite seleccionarla.
3. **Given** un tenant tiene más de 100 presentaciones activas, **When** escribo en el selector de
   presentación el nombre de una presentación que exista fuera de las primeras 100, **Then** el
   selector la encuentra y permite seleccionarla.
4. **Given** un tenant tiene 100 o menos registros activos en alguno de los tres catálogos (el caso
   que hoy ya funciona), **When** busco cualquiera de ellos en su selector, **Then** el
   comportamiento visible no cambia.
5. **Given** un insumo, categoría o presentación está inactivo, **When** lo busco en su selector
   correspondiente, **Then** no aparece como opción para seleccionarse de nuevo.

---

### User Story 4 - Ver catálogos razonablemente actualizados sin recargar toda la aplicación (Priority: P4) — RETIRADA (ver Clarifications, 2026-10-08)

**Esta historia se implementó y luego se retiró explícitamente**, a pedido directo del
dueño/desarrollador del proyecto tras observar el sondeo periódico en el panel de red del
navegador: prefiere que el usuario recargue la página manualmente en vez de mantener un sondeo de
fondo. El texto original de la historia queda abajo como registro de lo que se intentó y por qué
ya no aplica — FR-012/FR-013/FR-014 y SC-004 (más abajo) están marcados de la misma forma.

Un Administrador que mantiene abierto el formulario de producto mientras otra persona crea, en otra
sesión del navegador, una categoría, un insumo o una presentación nueva, puede encontrar esa
novedad en el selector correspondiente dentro de un tiempo razonable, sin necesitar recargar
manualmente toda la aplicación.

**Why this priority**: es **P4** porque es la mejora de menor urgencia relativa de las cuatro: el
Administrador siempre tiene como alternativa recargar la página, y el escenario (dos sesiones
editando catálogos al mismo tiempo que un formulario de producto permanece abierto) es menos
frecuente que los otros tres.

**Independent Test**: con el formulario de producto abierto en una sesión, crear desde otra sesión
una categoría, un insumo y una presentación nuevos; verificar que cada uno aparece como opción
buscable en su selector correspondiente en la primera sesión sin recargar la página completa.

**Acceptance Scenarios**:

1. **Given** el formulario de producto está abierto, **When** otra sesión crea una categoría activa
   nueva, **Then** esa categoría aparece como opción en el selector de categoría de la primera
   sesión dentro de un tiempo razonable, sin recargar la página.
2. **Given** la misma situación, **When** otra sesión crea un insumo o una presentación activos
   nuevos, **Then** cada uno aparece como opción en su selector correspondiente bajo la misma
   condición.
3. **Given** el catálogo se actualiza en segundo plano mientras el Administrador ya tiene una
   selección hecha en una fila del formulario (p. ej. un insumo ya elegido en una fila de receta),
   **When** ocurre la actualización, **Then** la selección ya hecha no se pierde ni se deselecciona.
4. **Given** el Administrador tiene un selector desplegado (dropdown abierto) justo cuando ocurre la
   actualización en segundo plano, **When** ocurre la actualización, **Then** el dropdown no se
   cierra de forma abrupta ni se interrumpe el texto que el Administrador está escribiendo.

---

### Edge Cases

- ¿Qué pasa si un producto no tiene ningún tamaño con receta ni grupos de opciones? La carga en
  paralelo (Historia 2) no tiene efecto observable: el formulario abre con normalidad, igual que
  hoy.
- ¿Qué pasa si el usuario escribe un texto muy corto (1-2 caracteres) en cualquiera de los tres
  selectores de la Historia 3? El selector debe seguir buscando y devolver todos los registros
  activos cuyo nombre contenga ese texto, igual que hoy hace Inventario → Insumos.
- ¿Qué pasa mientras una búsqueda está en curso en cualquiera de los tres selectores? El selector
  debe indicar que está cargando y no debe mostrar "Sin resultados" de forma prematura.
- ¿Qué pasa si falla por red la carga inicial de alguno de los tres catálogos al abrir el
  formulario? Debe mostrarse un error distinto de "sin resultados", con opción de reintentar, sin
  bloquear la posibilidad de seguir editando los demás campos del formulario.
- ¿Qué pasa si dos insumos, categorías o presentaciones tienen nombres muy similares? Todos los que
  coincidan con el texto buscado y estén activos deben aparecer como opciones distintas.
- ¿Qué pasa con una receta o un detalle de opción guardados **antes** de esta corrección, cuyo
  insumo ya estaba mostrando el placeholder "Insumo…"? Al reabrir el formulario después de aplicada
  esta corrección, debe mostrar el nombre real sin necesitar ninguna migración de datos: el id
  guardado ya es correcto, solo cambia cómo se resuelve su nombre para mostrarlo.

## Requirements *(mandatory)*

### Functional Requirements

**Historia 1 — nombre real de insumos ya guardados**

- **FR-001**: El formulario de producto DEBE mostrar el nombre real de cualquier insumo ya asociado
  a la receta ("Insumos fijos") de una variante, sin importar la posición de ese insumo dentro del
  catálogo completo de insumos del tenant ni la cantidad total de insumos activos del tenant.
- **FR-002**: El formulario de producto DEBE mostrar el nombre y unidad reales de cualquier insumo
  ya asociado al detalle de consumo de una opción de un grupo de opciones, bajo la misma condición
  de FR-001.
- **FR-003**: La resolución del nombre real de un insumo ya guardado en una fila de receta o de
  consumo de opción NO DEBE depender de que ese insumo esté incluido en la lista inicial cargada por
  el selector correspondiente.
- **FR-004**: Un insumo referenciado por una receta o un detalle de opción guardados, que haya sido
  desactivado después de guardarse, DEBE seguir mostrando su nombre real al reabrir el formulario,
  aunque ya no sea seleccionable como opción nueva.

**Historia 2 — carga en paralelo de tamaños**

- **FR-005**: Al abrir el formulario de edición de un producto con más de un tamaño activo, el
  sistema DEBE iniciar la carga de la receta y los grupos de opciones de **todos** los tamaños del
  producto de forma simultánea, no secuencial (tamaño por tamaño).
- **FR-006**: El tiempo que tarda el formulario de edición en quedar listo para usarse NO DEBE
  escalar de forma proporcional al número de tamaños del producto.
- **FR-007**: Si la carga de la receta o los grupos de opciones de un tamaño específico falla, los
  demás tamaños que sí cargaron correctamente DEBEN quedar disponibles para usarse en el formulario,
  sin bloquearse por el tamaño que falló.

**Historia 3 — sin tope fijo en los tres selectores**

- **FR-008**: Cada uno de los tres selectores del formulario de producto (insumos, categorías,
  presentaciones) DEBE permitir encontrar y seleccionar cualquier registro activo del tenant
  mediante búsqueda por texto parcial del nombre, sin un tope fijo de cantidad de registros
  cargados.
- **FR-009**: Los tres selectores DEBEN aplicar un comportamiento de búsqueda consistente entre sí:
  mismo mecanismo (búsqueda en el servidor), insensible a mayúsculas/minúsculas y tildes, excluyendo
  siempre los registros inactivos.
- **FR-010**: Esta corrección NO DEBE cambiar el comportamiento observable para tenants cuyos
  catálogos de insumos, categorías o presentaciones ya eran completamente encontrables antes de la
  corrección (p. ej. 100 registros activos o menos en cada catálogo).
- **FR-011**: El sistema NO DEBE requerir que el usuario conozca o adivine la posición de un
  insumo, categoría o presentación en un listado interno para poder encontrarlo en el formulario de
  producto.

**Historia 4 — catálogos actualizados sin recarga manual (RETIRADA, ver Clarifications 2026-10-08)**

- **FR-012** *(retirado)*: El sistema DEBE reflejar, en los selectores de categoría, insumo y
  presentación del formulario de producto, los registros activos creados por otra sesión mientras
  el formulario permanece abierto, sin requerir recargar toda la aplicación.
- **FR-013** *(retirado)*: La actualización de catálogos en segundo plano (FR-012) NO DEBE
  deseleccionar ni alterar una selección ya hecha por el usuario en una fila del formulario.
- **FR-014** *(retirado)*: La actualización de catálogos en segundo plano (FR-012) NO DEBE cerrar
  de forma abrupta un selector que el usuario tenga desplegado, ni interrumpir el texto que esté
  escribiendo en ese momento.

**Alcance general**

- **FR-015**: Ninguno de los cuatro puntos anteriores DEBE cambiar la forma en que se guarda el
  producto: crear y editar un producto siguen guardando toda la información en una sola petición,
  sin cambios en ese contrato.

### Key Entities *(include if feature involves data)*

- **Producto / Variante (tamaño)**: un producto puede tener una o más variantes activas ("tamaños"),
  cada una con su propia receta y sus propios grupos de opciones. Esta corrección no cambia su
  modelo de datos.
- **Receta de producto / Insumo fijo**: asociación entre una variante con "Maneja inventario"
  activo y uno o más insumos con una cantidad y unidad. Ya existe; esta corrección solo cambia cómo
  se resuelve y muestra el nombre del insumo asociado.
- **Grupo de opciones / Opción**: una opción puede asociar opcionalmente un insumo y una cantidad
  que descuenta al elegirse; su desglose de consumo se muestra dentro del formulario de producto.
- **Insumo (Inventory Item), Categoría, Presentación**: catálogos del tenant que el formulario de
  producto consume como opciones de selección. Ya existen y no cambian su modelo de datos; esta
  corrección solo cambia cómo se cargan, buscan y refrescan dentro del formulario de producto.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100% de los insumos ya guardados en una receta o en un detalle de consumo de
  opción se muestran con su nombre real (nunca el placeholder genérico) al reabrir el formulario de
  edición de producto, verificado en al menos un tenant con más de 100 insumos activos.
- **SC-002**: El tiempo que tarda el formulario de edición en quedar listo para usarse para un
  producto con 8 o más tamaños no supera, de forma significativa, el tiempo que tarda para un
  producto con 2 tamaños (en vez de escalar linealmente con el número de tamaños).
- **SC-003**: El 100% de los insumos, categorías y presentaciones activas de un tenant son
  encontrables desde su selector correspondiente en el formulario de producto, mediante búsqueda por
  texto parcial, sin importar el tamaño del catálogo.
- **SC-004** *(retirado, ver Clarifications 2026-10-08)*: Un registro (categoría, insumo o
  presentación) creado en otra sesión mientras el formulario de producto permanece abierto
  aparece como opción buscable en la sesión que ya tenía el formulario abierto, dentro de un
  tiempo razonable (del orden de minutos), sin recargar la página.
- **SC-005**: Ningún Administrador necesita crear un registro duplicado de insumo, categoría o
  presentación como solución alterna por no poder encontrar uno ya existente desde el formulario de
  producto.

## Assumptions

- *(Retirado, ver Clarifications 2026-10-08)* Se asumía que "razonablemente actualizado" (Historia
  4) significaba un registro nuevo apareciendo en los selectores dentro de un plazo corto mediante
  sondeo periódico. Tras implementarse y observarse en producción, el dueño/desarrollador del
  proyecto pidió retirarlo: el formulario depende de una recarga manual de la página para ver
  catálogos creados por otra sesión, igual que antes de esta spec.
- Se asume que el mecanismo de búsqueda server-side para categorías y presentaciones (Historia 3)
  reutiliza el mismo patrón ya definido para insumos por la spec 098 (`InventoryService.searchActiveItems()`),
  sin introducir un mecanismo de búsqueda nuevo o distinto, y que ese mismo patrón se termina de
  aplicar también al selector base de insumos del formulario de producto (hoy solo lo usa la
  búsqueda remota de la fila de receta, no el selector base — ver Causa raíz).
- Se asume que el alcance del bug visual (Historia 1) se limita a los insumos mostrados dentro del
  formulario de producto (receta de "Insumos fijos" y desglose de consumo de insumo por opción). Si
  existiera un defecto cosmético análogo en los selectores de categoría o presentación (por
  compartir el mismo componente genérico `app-searchable-select`), no fue reportado con ese síntoma
  y queda fuera de alcance de esta corrección; puede abordarse como seguimiento independiente si se
  reporta.
- Se asume que esta corrección no necesita migrar ni corregir filas ya guardadas: los ids guardados
  en recetas y detalles de opción ya son correctos hoy; solo cambia cómo se resuelve su nombre para
  mostrarlo (FR-003), sin requerir ningún script de corrección de datos.
- Se asume que la carga en paralelo de tamaños (Historia 2) no cambia el orden en que se muestran
  los tamaños en el formulario, solo el momento en que se disparan sus peticiones de datos.
- Se asume que esta corrección no incluye los demás puntos de selector de insumo fuera del
  formulario de producto que la spec 098 ya cubre por separado (compras, movimientos de inventario,
  edición de una opción desde su propio formulario): el alcance de esta spec es exclusivamente lo
  que se carga y se muestra dentro del formulario de crear/editar producto.
- Se confirma (Clarifications, 2026-10-08) que la Historia 2 de esta spec, ya implementada, queda
  tal como se construyó: variantes/receta/grupos de opciones se cargan vía peticiones de frontend
  en paralelo, no vía un endpoint de backend combinado. La idea de que el backend devuelva esa
  información ya relacionada (p. ej. un `JOIN` en `GET /products/{id}`) queda registrada como
  candidata para una spec de seguimiento independiente — no reabre ni modifica el alcance ya
  implementado de esta spec.
