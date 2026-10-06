# Feature Specification: Corrección — los selectores de insumo (receta, opciones, compras, movimientos de inventario) no encuentran insumos existentes fuera de los primeros 100

**Feature Branch**: `098-selector-insumos-receta`

**Created**: 2026-10-06

**Status**: Draft

**Naturaleza de esta spec**: **spec de corrección**, no una funcionalidad nueva desde cero. Igual
que las specs [072](../072-fix-deteccion-turno-caja/spec.md) y
[097](../097-categoria-nombre-productos/spec.md) — esta última es, de hecho, el mismo patrón de
defecto (una pantalla carga una sola página de hasta 100 registros y filtra en el cliente, en vez
de buscar en el servidor) — esta spec cita nombres de archivo, función y línea del código actual
(`pos-backend`/`pos-heladeria`) porque son el contrato observable que se está corrigiendo, no una
fuga de detalles de implementación. Es un defecto latente de recuperación de datos, no una
decisión de negocio nueva: un selector de insumos deja de encontrar un insumo real solo cuando el
tenant supera el límite de una sola página, algo que nunca fue una regla de negocio deliberada. No
aplica una nueva entrada en `registro-de-anomalias.md`: restaura el comportamiento pretendido
(permitir seleccionar cualquier insumo activo existente), no cambia ninguna regla de negocio ya
decidida sobre qué insumos pueden usarse en una receta, una opción o una compra.

**Alcance ampliado (confirmado al planear, 2026-10-06)**: el reporte original solo describe el
selector de "Insumos fijos" de la receta de producto, pero la causa raíz —el método compartido
`InventoryService.allItems()`/`loadAllItems()` en el frontend— respalda **otros cuatro
selectores/lookups de insumo** que presentan el mismo defecto por la misma razón. Resolución de
negocio (dueño/desarrollador del proyecto, al planear esta spec): corregir la causa raíz
compartida, no solo el síntoma reportado, para no dejar el mismo defecto esperando a ser
reportado de nuevo en otra pantalla. Los cinco puntos afectados son:

1. Selector de "Insumos fijos" de la receta de una variante de producto (el reportado).
2. Selector de insumo al editar una opción de un grupo de opciones (consumo de inventario por
   opción).
3. Selector de insumo en el formulario de registrar una Compra.
4. Selector de insumo del tab "Movimientos" dentro de Inventario.
5. Lookup interno de nombre/unidad de un insumo ya guardado en una fila existente (receta, opción,
   compra) — este punto es un síntoma **cosmético** del mismo defecto (ver Edge Cases y
   Assumptions): no bloquea ninguna acción, solo puede mostrar una etiqueta vacía para un insumo
   ya asociado que quedó fuera de la primera página; queda fuera del alcance de esta corrección y
   se documenta como posible seguimiento futuro independiente.

**Autorización de negocio (Principio I y Principio II de la
[Constitución](../../.specify/memory/constitution.md))**: reportado directamente como bug de
producción el 2026-10-05 por el dueño/desarrollador del proyecto, con pasos de reproducción,
evidencia de red y causa probable documentados en el reporte original. No reabre ninguna regla de
negocio sobre qué insumos pueden fijarse en una receta ni sobre los permisos de Administrador: el
fix es exclusivamente sobre **cómo encuentra el selector un insumo que ya existe**, no sobre qué
insumos son válidos en una receta ni sobre el contrato de `GET /inventory/items`, que permanece
intacto para quienes ya lo usan hoy (pantalla de Inventario → Insumos).

**Input**: User description (verbatim, reporte de bug): "El selector de insumos de la receta no
muestra insumos existentes del inventario ('Sin resultados')... Al configurar la receta de un
producto con 'Maneja inventario' activo, el selector de 'Insumos fijos' responde 'Sin resultados'
para un insumo que existe, está activo y aparece en Inventario... Causa probable: el selector carga
una lista limitada a 100 registros y filtra en el cliente... Solución propuesta: selector de
insumos con búsqueda en el servidor: `GET /inventory/items?search=&active=true&page=1&size=20`,
aplicando las mismas reglas de búsqueda que usa Inventario."

**Causa raíz (confirmada leyendo el código real)**:

- Los cinco puntos listados arriba leen sus opciones (o resuelven su etiqueta) desde
  `InventoryService.allItems()`, un `computed()` (`inventory.service.ts:139-141`) respaldado por
  una única petición `GET /inventory/items?size=100` (sin `search`, sin `active`, sin avanzar de
  página — `inventory.service.ts:129-137`), disparada una sola vez por pantalla mediante
  `loadAllItems()` (`inventory.service.ts:182-185`) cuando `allItems().length === 0`:
  - Receta: `product-form.component.ts:548-549` (opciones del selector) y `:847` (carga).
  - Opciones: `option-groups/components/option-form.component.ts:128-129` (opciones del selector)
    y `:157-158` (carga, con comentario explícito sobre el límite de la primera página).
  - Compras: `inventory/components/purchase-form.component.ts:150-156` (opciones del selector) y
    `:173` (carga).
  - Movimientos de Inventario: `inventory/pages/inventory-page.component.ts:434-435` (opciones del
    selector); la carga ocurre en `:443` (`ngOnInit`).
  - Lookup de nombre/unidad para filas ya guardadas: mismos cuatro archivos, vía
    `buildUnitLookup(this.inventoryService.allItems(), …)` o un `Map` construido sobre
    `allItems()` (p. ej. `inventory-page.component.ts:431`).
- El texto que el usuario escribe (p. ej. "MOZARELA") se filtra **enteramente en el cliente**,
  dentro del componente genérico `searchable-select.component.ts:104-107` (`filteredOptions()`),
  que hace `includes()` sobre el array de hasta 100 opciones ya cargado — nunca reenvía el texto al
  servidor. Este componente (`app-searchable-select`) también se usa para selectores que no son de
  insumo (p. ej. selector de mesa en `tables/pages/manual-order-page.component.ts`), así que su
  filtrado client-side por defecto no es, en sí mismo, el defecto — el defecto es que los cinco
  puntos de insumo lo alimentan con una lista incompleta.
- Consecuencia: en un tenant cuyo insumo buscado no cae dentro de esa primera página de 100 (según
  el orden que devuelve el backend), cualquiera de los cuatro selectores (receta, opciones,
  compras, movimientos) siempre responde "Sin resultados", aunque el insumo exista, esté activo y
  tenga stock — exactamente el caso reportado con "QUESO MOZARELA BLOQUE X 2500 GRAMOS" en la
  receta, y reproducible de igual forma en los otros tres.
- El backend (`inventory/router.py:37-54` y `inventory/service.py:24-43`) **ya soporta** búsqueda
  server-side (`search`, filtro `ilike` sobre el nombre), filtro `active`, y paginación (`page`,
  `size`, con tope `le=100`) — exactamente lo que pide la pantalla de Inventario → Insumos
  (`inventory-page.component.ts:464-468`, debounce de 300ms + `setItemsSearch()`). El backend no
  necesita cambios: el defecto es 100% de frontend, en cinco puntos que no reutilizan esa búsqueda
  ya existente.
- Detalle adicional no reportado originalmente: como `allItems()` tampoco envía `active=true`, los
  cuatro selectores también pueden ofrecer insumos **inactivos** dentro de esos primeros 100 — un
  segundo síntoma del mismo defecto (no buscan en el servidor con los mismos filtros que usa
  Inventario).

## Clarifications

### Session 2026-10-06

- Q: ¿Qué debe mostrar el selector de "Insumos fijos" cuando la búsqueda al servidor falla por un
  error de red o del servidor (no porque no haya coincidencias)? → A: Mostrar un mensaje de error
  distinto de "Sin resultados", con opción de reintentar.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Encontrar y agregar cualquier insumo activo existente a la receta de un producto (Priority: P1)

Un Administrador que edita la receta ("Insumos fijos") de un producto con "Maneja inventario"
activo escribe parte del nombre de un insumo que existe y está activo en Inventario, y el selector
lo encuentra y lo muestra como opción seleccionable — sin importar cuántos insumos tenga el tenant
ni en qué posición quede ese insumo dentro del catálogo completo.

**Why this priority**: es la única historia de esta spec y la que resuelve directamente el defecto
reportado: hoy, en tenants con más de 100 insumos, algunos insumos reales quedan permanentemente
inalcanzables desde el selector de receta, lo que bloquea la configuración de esa receta y deja el
producto vendiéndose sin descontar inventario para ese insumo. Es **P1** porque afecta
directamente la integridad del inventario y el costeo de producto, no solo la experiencia de uso.

**Independent Test**: en un tenant con más de 100 insumos activos, abrir la edición de un producto
con "Maneja inventario" activo, ir a "Insumos fijos", escribir en el selector el nombre (o parte
del nombre) de un insumo que exista fuera de los primeros 100 alfabéticos/por orden de creación, y
verificar que aparece como opción y puede agregarse con su unidad correcta.

**Acceptance Scenarios**:

1. **Given** un insumo activo existe en Inventario con un nombre que contiene "MOZARELA", **When**
   escribo "MOZARELA" (o "MOZAR") en el selector de "Insumos fijos" de un producto, **Then** el
   insumo aparece en la lista de resultados y puedo seleccionarlo.
2. **Given** selecciono un insumo desde el selector de "Insumos fijos", **When** lo agrego a la
   receta, **Then** se agrega con su unidad de medida correcta (p. ej. "Gr"), igual que hoy ocurre
   cuando el insumo sí cae dentro de la lista cargada.
3. **Given** un tenant tiene más de 100 insumos activos, **When** busco por texto cualquier insumo
   existente y activo, sin importar su posición en el catálogo completo, **Then** el selector lo
   encuentra siempre, no solo cuando cae dentro de una primera página arbitraria.
4. **Given** un insumo está inactivo en Inventario, **When** lo busco en el selector de "Insumos
   fijos", **Then** no aparece como opción — igual que Inventario → Insumos no lo muestra por
   defecto al estar inactivo.
5. **Given** un tenant tiene 100 insumos activos o menos (el caso que hoy ya funciona), **When**
   busco cualquiera de ellos en el selector de "Insumos fijos", **Then** el comportamiento visible
   no cambia: sigo encontrándolo y agregándolo con normalidad.
6. **Given** el texto escrito no coincide con ningún insumo activo, **When** reviso el selector,
   **Then** muestra "Sin resultados" — ese mensaje se reserva para la ausencia real de coincidencias,
   no para insumos que existen pero no fueron cargados.

---

### User Story 2 - Encontrar cualquier insumo activo desde los demás selectores que comparten el mismo defecto (Priority: P2)

Un Administrador que edita una opción de un grupo de opciones, registra una Compra, o registra un
movimiento manual de inventario, busca un insumo por texto en el selector correspondiente y lo
encuentra sin importar cuántos insumos tenga el tenant — el mismo comportamiento corregido para
"Insumos fijos" en la Historia 1, aplicado a los otros tres puntos que comparten la misma causa
raíz.

**Why this priority**: es **P2** (no P1) porque, a diferencia de la receta, estos tres puntos no
estaban reportados como bug de producción al momento de escribir esta spec; se agregan porque
comparten exactamente la misma causa raíz y dejarlos sin corregir garantiza que el mismo síntoma
se reporte de nuevo, solo en otra pantalla. Resolución de negocio: corregirlos junto con la
Historia 1 en la misma spec, no como specs separadas, porque el cambio técnico es el mismo cambio
de causa raíz compartida (ver Alcance ampliado).

**Independent Test**: en un tenant con más de 100 insumos activos, para cada uno de los tres
puntos (editar una opción de grupo de opciones, registrar una Compra, registrar un movimiento
manual de inventario), buscar por texto un insumo que exista fuera de los primeros 100 y verificar
que aparece y puede seleccionarse.

**Acceptance Scenarios**:

1. **Given** edito una opción de un grupo de opciones con "Maneja inventario" habilitado, **When**
   busco por texto un insumo activo que exista fuera de los primeros 100, **Then** el selector lo
   encuentra y permite asociarlo a la opción.
2. **Given** registro una Compra, **When** busco por texto un insumo activo que exista fuera de
   los primeros 100, **Then** el selector lo encuentra y permite agregarlo como línea de la
   compra.
3. **Given** registro un movimiento manual desde el tab "Movimientos" de Inventario, **When**
   busco por texto un insumo activo que exista fuera de los primeros 100, **Then** el selector lo
   encuentra y permite seleccionarlo.

---

### Edge Cases

- ¿Qué pasa si el usuario escribe un texto muy corto (1-2 caracteres)? El selector debe seguir
  buscando y devolver todos los insumos activos cuyo nombre contenga ese texto, igual que hoy hace
  Inventario → Insumos con el mismo texto.
- ¿Qué pasa si hay insumos duplicados o con nombres muy similares (p. ej. dos variantes de
  "MOZARELA")? Todos los que coincidan con el texto buscado y estén activos deben aparecer como
  opciones distintas, resueltos de forma independiente.
- ¿Qué pasa mientras la búsqueda está en curso (latencia de red)? El selector debe indicar que está
  cargando y no debe mostrar "Sin resultados" de forma prematura antes de recibir la respuesta del
  servidor.
- ¿Qué pasa si la búsqueda falla por un error de red o del servidor (no por ausencia de
  coincidencias)? El selector debe mostrar un mensaje de error distinto de "Sin resultados", con
  opción de reintentar — nunca debe confundirse un error transitorio con la ausencia real del
  insumo.
- ¿Qué pasa si el usuario borra el texto de búsqueda? El selector vuelve a mostrar un conjunto de
  insumos activos (p. ej. los primeros según el orden por defecto), igual que el estado inicial de
  Inventario → Insumos antes de escribir nada.
- ¿Qué pasa con un insumo que ya estaba agregado a una receta, opción o compra antes de esta
  corrección, pero que no se podía *buscar* para agregar uno nuevo? Esta corrección no afecta
  insumos ya guardados en una fila existente — solo corrige la capacidad de *encontrar y agregar*
  insumos nuevos desde el selector.
- ¿Qué pasa si una fila ya guardada (receta, opción, compra) referencia un insumo que queda fuera
  de la caché local de nombres/unidades? Puede mostrar una etiqueta vacía o incompleta para ese
  insumo ya asociado — es un defecto cosmético preexistente, distinto del que bloquea agregar
  insumos nuevos, y queda **fuera de alcance** de esta corrección (ver Alcance ampliado y
  Assumptions).

## Requirements *(mandatory)*

### Functional Requirements

*Los siguientes requisitos aplican a los cuatro selectores de insumo identificados en "Alcance
ampliado": el de "Insumos fijos" de la receta, el de edición de una opción de grupo de opciones,
el del formulario de Compras, y el del tab "Movimientos" de Inventario.*

- **FR-001**: Cada selector de insumo DEBE encontrar cualquier insumo activo cuyo nombre contenga
  (total o parcialmente, sin distinguir mayúsculas/minúsculas ni tildes) el texto escrito por el
  usuario, sin importar cuántos insumos tenga el tenant en total ni la posición del insumo dentro
  del catálogo completo.
- **FR-002**: Cada selector de insumo DEBE aplicar las mismas reglas de búsqueda por texto que ya
  usa la pantalla de Inventario → Insumos, de forma que un insumo encontrable en Inventario con un
  texto dado sea igualmente encontrable en cualquiera de estos selectores con ese mismo texto.
- **FR-003**: Cada selector de insumo DEBE excluir los insumos inactivos de los resultados
  de búsqueda, igual que Inventario → Insumos los excluye por defecto.
- **FR-004**: El sistema DEBE permitir agregar/asociar (según el contexto: receta, opción, línea
  de compra o movimiento) cualquier insumo activo encontrado por el selector, preservando su
  unidad de medida real, sin perder ninguna capacidad que exista hoy para los insumos que ya eran
  encontrables.
- **FR-005**: Cada selector de insumo DEBE mostrar el mensaje de "sin resultados" únicamente
  cuando, en efecto, ningún insumo activo coincide con el texto buscado — nunca como consecuencia
  de un límite de carga que excluya insumos que sí coinciden, ni como consecuencia de un error de
  red o del servidor.
- **FR-006**: Cuando la búsqueda de insumos falle por un error de red o del servidor, el selector
  DEBE mostrar un mensaje de error distinto del mensaje de "sin resultados" y DEBE permitir
  reintentar la búsqueda.
- **FR-007**: Esta corrección NO DEBE cambiar el comportamiento observable para tenants cuyos
  insumos activos ya eran todos encontrables antes de la corrección (p. ej. tenants con pocos
  insumos): deben seguir pudiendo buscar y agregar/asociar insumos con el mismo resultado que hoy,
  en los cuatro selectores afectados.
- **FR-008**: El sistema NO DEBE requerir que el usuario conozca o adivine la posición de un
  insumo en un listado interno para poder encontrarlo en cualquiera de los cuatro selectores
  afectados.
- **FR-009**: La visualización del nombre/unidad de un insumo ya asociado a una fila existente
  (receta, opción o compra guardada antes de esta corrección) NO ES PARTE de esta corrección: el
  alcance se limita a la capacidad de *buscar y agregar/asociar* insumos nuevos desde los cuatro
  selectores (ver Edge Cases).

### Key Entities *(include if feature involves data)*

- **Insumo (Inventory Item)**: ítem del inventario de un tenant; tiene nombre, unidad de medida,
  estado activo/inactivo y stock. Ya existe y no cambia su modelo de datos con esta corrección.
- **Receta de producto / Insumo fijo**: asociación entre una variante de producto con "Maneja
  inventario" activo y uno o más insumos con una cantidad y unidad.
- **Opción de grupo de opciones**: puede asociar opcionalmente un insumo y una cantidad que
  descuenta al elegirse.
- **Línea de Compra**: asocia un insumo, una cantidad y un costo unitario dentro de una compra.
- **Movimiento de inventario**: asocia un insumo a un ajuste manual de stock. Para los cuatro, esta
  corrección no cambia qué asociaciones son válidas, solo cómo se encuentra el insumo para crearla.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100% de los insumos activos de un tenant son encontrables desde cada uno de los
  cuatro selectores afectados (receta, opciones, compras, movimientos) usando una búsqueda por
  texto parcial de su nombre, sin importar el tamaño del catálogo de insumos del tenant.
- **SC-002**: Cero insumos activos existentes quedan permanentemente inalcanzables desde alguno de
  los cuatro selectores por efecto de un límite de carga inicial, verificado en al menos un tenant
  con más de 100 insumos activos.
- **SC-003**: Un Administrador puede completar la configuración de una receta, una opción, una
  compra o un movimiento con cualquier insumo activo que exista, sin recurrir a crear un insumo
  duplicado como solución alterna.
- **SC-004**: El comportamiento de búsqueda de cada uno de los cuatro selectores coincide con el
  de Inventario → Insumos para el mismo texto de búsqueda, en el 100% de los casos probados.

## Assumptions

- Se asume que "buscar en el servidor" significa reutilizar el mismo endpoint y las mismas reglas
  de búsqueda, filtrado por activos y paginación que ya usa Inventario → Insumos, sin introducir un
  mecanismo de búsqueda nuevo o distinto.
- Se asume que el límite de resultados por página que use el selector (p. ej. una página pequeña
  con posibilidad de seguir escribiendo para refinar) es un detalle de experiencia de usuario, no
  una restricción de negocio: cualquier tamaño de página es válido siempre que el usuario pueda
  encontrar cualquier insumo activo escribiendo un texto suficientemente específico.
- Se asume que esta corrección no necesita migrar ni corregir filas ya guardadas (receta, opción,
  compra): insumos ya asociados antes de esta corrección no se ven afectados, solo la capacidad de
  *agregar/asociar* insumos nuevos desde cada selector.
- Se asume que el defecto adicional detectado (los selectores podían ofrecer insumos inactivos
  dentro de los primeros 100) se corrige como parte de la misma historia, ya que ambos síntomas
  comparten la misma causa raíz (no reutilizar la búsqueda server-side con filtro `active` que ya
  existe).
- Se asume que la resolución de nombre/unidad para insumos ya asociados a una fila existente
  (quinto punto del "Alcance ampliado") es un defecto cosmético separado, de menor severidad, que
  no bloquea ninguna acción y que queda fuera de alcance de esta corrección (FR-009) — puede
  abordarse como una spec de corrección independiente si el negocio lo decide más adelante.
- Se asume que el selector genérico (`app-searchable-select`) usado también por selectores que no
  son de insumo (p. ej. selección de mesa) no cambia su comportamiento de filtrado por defecto:
  cualquier mecanismo de búsqueda en servidor que requiera esta corrección se implementa como un
  modo adicional/opcional de ese componente compartido, o de forma que no afecte a sus demás
  consumidores (FR-007).
