# Feature Specification: Consolidar receta y grupos de opciones en el detalle de producto (sin peticiones por tamaño)

**Feature Branch**: `103-detalle-producto-consolidado`

**Created**: 2026-10-08

**Status**: Draft

**Naturaleza de esta spec**: **optimización de rendimiento de un endpoint ya existente**, no la
corrección de un defecto de negocio. Es el seguimiento directo que la spec
[102](../102-fix-formulario-producto-catalogos/spec.md) dejó registrado en su sección
Clarifications (sesión 2026-10-08): al señalar que las peticiones separadas de variantes,
receta y grupos de opciones del formulario de edición de producto generan latencia innecesaria, el
dueño/desarrollador del proyecto confirmó que esta idea se aborda como spec de seguimiento
independiente, no reabriendo la 102 ya implementada. A diferencia de la 102 (100% frontend), esta
spec **sí requiere cambios de backend**: consolidar en una sola respuesta del endpoint de detalle
de producto datos que hoy se obtienen con peticiones adicionales por cada tamaño.

**Autorización de negocio (Principio I de la
[Constitución](../../.specify/memory/constitution.md))**: reportado directamente por el
dueño/desarrollador del proyecto el 2026-10-08, con evidencia de red (ver Input) mostrando
peticiones repetidas de `variants`/`recipe`/`option-groups` al abrir el formulario de edición de
un producto. No reabre ninguna regla de negocio sobre qué insumos, grupos de opciones o
presentaciones son válidos para un producto, ni sobre cómo se guarda: el alcance es exclusivamente
cómo se **recupera** esa información ya existente. **Importante** (ver Causa raíz): esta spec
**preserva explícitamente**, sin reabrirla, la regla de negocio ya protegida por la spec 093
(FR-018: ningún rol Cajero puede ver costos/receta/inventario) — no aplica entrada en
`registro-de-anomalias.md` porque ningún comportamiento ya decidido cambia, solo se le da
continuidad dentro del nuevo mecanismo de carga.

**Input**: User description (verbatim, resumen): "Quiero optimizar estas llamadas para precargar
el formulario de edición: esos endpoints generan latencia; esa información debería venir en el
endpoint de detalle del producto y precargarse en el formulario." Adjuntó una captura del panel de
red del navegador mostrando, al abrir la edición del producto
`11932962-99de-4c8d-81d0-ecf1a3def228`, una petición a `GET
/api/v1/products/{id}/variants` seguida de múltiples peticiones repetidas a `recipe` y
`option-groups` (una por cada tamaño del producto).

**Causa raíz (confirmada leyendo el código real de `pos-backend` y `pos-heladeria`)**:

- El formulario de edición de producto ya dispara, desde la spec 102 (Historia 2), las peticiones
  de receta y grupos de opciones de **todas** las variantes **en paralelo** entre sí — ya no son
  secuenciales — pero siguen siendo **N peticiones adicionales independientes** (dos por cada
  tamaño activo: `GET /variants/{id}/recipe` y `GET /variants/{id}/option-groups`,
  `pos-heladeria/src/app/modules/products/services/product.service.ts`, métodos privados
  `fetchVariantRecipeRaw`/`fetchVariantOptionGroupsRaw`), disparadas después de recibir la
  respuesta de `GET /products/{id}` y de `GET /products/{id}/variants`. Un producto con más tamaños
  sigue abriendo más conexiones de red (aunque ya no más tiempo secuencial), lo que el reporte
  original señala como latencia evitable.
- El endpoint que ya trae el detalle del producto (`GET /products/{id}`,
  `pos-backend/app/api/v1/products/router.py:52-66`, función `get_product()`) **ya incluye**
  `variants[]` con precio, presentación y nombre (`ProductDetailResponse`,
  `pos-backend/app/api/v1/products/schemas.py:114-120`, construido por
  `ProductService.to_detail_response()`, `products/service.py:85-97`) — pero **a propósito** no
  incluye receta ni grupos de opciones: el comentario del propio esquema cita explícitamente
  "FR-018 exige que ninguna pantalla de la carta exponga costos/receta/inventario" (spec 093).
- Ese mismo endpoint (`GET /products/{id}`) es compartido hoy por **dos consumidores
  distintos** del panel de administración: el formulario de edición de producto (solo
  Administrador, `ProductFormComponent` vía `ProductService.getProductDraft()`,
  `product.service.ts:507-520`) y la pantalla de solo lectura "Carta del menú → detalle de
  producto" (alcanzable también por **Cajero**, `product-detail-page.component.ts`, vía
  `ProductService.getProductDetail()`, `product.service.ts:252-265`) — **no** el menú público del
  comensal, que es un endpoint completamente distinto (`GET /menu`,
  `pos-backend/app/api/v1/menu/router.py`, sin autenticación, que nunca serializa receta ni costo
  de insumos: `menu/schemas.py:10-38` documenta explícitamente que "el comensal es anónimo y no
  debe ver ni los insumos ni las existencias").
- El propio backend ya protege la receta con una regla de autorización más estricta que la del
  detalle de producto: `GET /variants/{id}/recipe` (`pos-backend/app/api/v1/catalog/router.py:189-203`)
  exige `Depends(forbid_cashier)` (el Cajero recibe 403), mientras que `GET /products/{id}` solo
  exige `Depends(get_current_user)` (cualquier usuario autenticado del tenant, **incluido
  Cajero**, `products/router.py:61-66`). Consolidar receta y grupos de opciones dentro de `GET
  /products/{id}` **sin preservar esa distinción de rol** filtraría datos de costo/receta a
  Cajero a través de la pantalla "Carta del menú → detalle de producto" — algo que la spec 093 ya
  decidió explícitamente que no debe ocurrir.
- Ni `Product.variants` ni `ProductVariant.recipe_items`/`.option_groups`
  (`pos-backend/app/models/product.py:77-81`, `app/models/product_variant.py:88-96`) tienen hoy
  precarga (`lazy="select"` por defecto) en la ruta de consulta de `GET /products/{id}`
  (`app/core/crud.py:9-14`, un `db.get()` plano) — a diferencia de `GET /menu`, que sí precarga
  explícitamente con `selectinload` encadenados (`menu/router.py:109-114`) precisamente para
  evitar este mismo patrón N+1 en su propio endpoint. El patrón para resolverlo ya existe en el
  código, solo no se aplica todavía a `GET /products/{id}`.
- Ningún otro punto del frontend llama a `GET /variants/{id}/recipe` ni `GET
  /variants/{id}/option-groups` de forma masiva: los únicos consumidores restantes son
  `restoreVariant()` y `retryVariantLoad()` (`product-form.component.ts`), que piden la receta y
  los grupos de **una sola variante** puntual (reintento tras un fallo parcial, o al restaurar un
  tamaño desactivado) — no el conjunto completo del producto.

---

## Clarifications

### Session 2026-10-08

- Q: Tras ver en el panel de red del navegador que abrir el formulario de edición seguía
  disparando `GET /products/{id}/variants` además de `GET /products/{id}` (ya con receta/grupos
  de opciones embebidos), el dueño/desarrollador del proyecto pidió explícitamente quitar esa
  petición: la consideraba innecesaria porque "esa información ya está disponible en la
  información del producto". ¿Esa petición cubre algo que `GET /products/{id}` no trae? → A: Sí
  — las variantes **desactivadas** (necesarias para la lista de "restaurar un tamaño"), que
  `GET /products/{id}` nunca ha incluido (solo trae las activas, FR-018 de la spec 093 vía
  `to_detail_response`). Se resuelve agregando un campo nuevo `deactivated` a la misma respuesta
  de `GET /products/{id}` (reutilizando `product.variants`, ya precargado — sin consulta nueva),
  en vez de eliminar la petición sin más y perder la función de restaurar un tamaño desactivado.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Abrir el formulario de edición no dispara peticiones adicionales por cada tamaño (Priority: P1)

Un Administrador que abre el formulario de edición de un producto ve la receta y los grupos de
opciones de todos sus tamaños ya disponibles, sin que el navegador tenga que esperar peticiones de
red adicionales (una por cada tamaño) después de recibir el detalle del producto.

**Why this priority**: es la única historia de esta spec y resuelve directamente la latencia
reportada: hoy, un producto con más tamaños sigue abriendo más conexiones de red aunque ya se
disparen en paralelo (spec 102). Consolidar esa información en una sola respuesta elimina esas
peticiones adicionales por completo, no solo su efecto secuencial.

**Independent Test**: con las herramientas de red del navegador abiertas, abrir el formulario de
edición de un producto con 5 o más tamaños y verificar que, tras la petición de detalle del
producto, no se dispara ninguna petición adicional a los endpoints de receta o grupos de opciones
por tamaño; el formulario muestra la misma información de receta y grupos que mostraba antes.

**Acceptance Scenarios**:

1. **Given** un producto con 5 tamaños, cada uno con su propia receta y grupos de opciones,
   **When** un Administrador abre su formulario de edición, **Then** la petición que trae el
   detalle del producto ya incluye la receta y los grupos de opciones de los 5 tamaños, sin
   peticiones de red adicionales por tamaño.
2. **Given** la misma situación anterior, **When** reviso la receta y los grupos de opciones
   mostrados en el formulario para cada tamaño, **Then** el contenido es idéntico al que se
   mostraba antes de esta optimización (mismos insumos, cantidades y grupos).
3. **Given** un tamaño no tiene ningún insumo fijo ni grupo de opciones configurado, **When** abro
   el formulario de edición, **Then** ese tamaño se muestra con su receta y sus grupos vacíos,
   igual que hoy.
4. **Given** un usuario con rol Cajero abre la pantalla de solo lectura "Carta del menú → detalle
   de producto" (que comparte el mismo endpoint de detalle), **When** se recibe la respuesta,
   **Then** esa respuesta NO incluye receta de ningún tamaño — igual que hoy el Cajero no puede
   consultarla por ningún otro medio (spec 093, FR-018).
5. **Given** un Administrador abre el formulario de edición de un producto con un tamaño
   desactivado, **When** se recibe el detalle del producto, **Then** ese tamaño ya aparece en la
   lista de "desactivados" (restaurables) sin necesitar una petición aparte — ver Clarifications,
   2026-10-08.
6. **Given** un Administrador restaura un tamaño previamente desactivado, **When** usa esa acción
   puntual, **Then** sigue funcionando exactamente igual que hoy: pide la receta y los grupos de
   opciones de solo esa variante (no viajaron en la respuesta consolidada, solo su presentación y
   precio — ver Edge Cases).
7. **Given** la petición de detalle del producto falla por completo (error de red o del
   servidor), **When** el Administrador reintenta, **Then** el control de reintento que ve es el
   de "abrir/recargar el formulario" (la petición única de detalle), no un control por cada
   tamaño — el reintento por tamaño que introdujo la spec 102 (Historia 2) para una carga
   parcialmente fallida deja de tener un escenario donde mostrarse, porque la carga deja de ser
   parcial (ver FR-009).

---

### Edge Cases

- ¿Qué pasa con un producto con muchos tamaños (p. ej. 20)? La respuesta del detalle de producto
  crece proporcionalmente, pero sigue siendo una sola petición en vez de hasta 40 adicionales.
- ¿Qué pasa si falla la consulta del detalle completo del producto (p. ej. error de red o del
  servidor)? El formulario debe comportarse igual que hoy ante ese mismo fallo (no hay una
  petición "parcial" de la que degradar: antes también dependía de que el detalle del producto
  cargara primero).
- ¿Qué pasa con el control de "Reintentar" por tamaño que la spec 102 (Historia 2) agregó para
  una receta/grupos de opciones que fallaran en algunos tamaños mientras otros cargaban bien? Dejó
  de tener un escenario donde aparecer: con esta optimización, la receta y los grupos de opciones
  de todos los tamaños llegan en la misma petición que el resto del detalle del producto, así que
  ya no existe un fallo que afecte a un tamaño sin afectar a los demás (ver FR-009). El control de
  reintento que sí sigue existiendo es el de restaurar un tamaño desactivado (Historia única,
  Escenario 5), que no cambia.
- ¿Qué pasa con las variantes desactivadas de un producto? Viajan en la misma respuesta de
  detalle (campo aparte, ver Clarifications 2026-10-08), pero sin receta ni grupos de opciones
  embebidos — esos datos solo se piden si el Administrador decide restaurar esa variante puntual.
- ¿Qué pasa si un usuario con rol Cajero abre el formulario de edición directamente (si su
  permiso se lo permitiera en el futuro)? Fuera de alcance de esta spec: hoy el formulario de
  edición ya es exclusivo de Administrador por permisos de la aplicación, sin cambios aquí.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El endpoint de detalle de producto DEBE incluir, para cada tamaño (variante) activo
  del producto, su receta (insumos fijos) y sus grupos de opciones, dentro de la misma respuesta
  que ya trae el resto del detalle del producto.
- **FR-002**: El formulario de edición de producto DEBE usar los datos de receta y grupos de
  opciones ya incluidos en la respuesta de detalle del producto, sin disparar ninguna petición
  adicional por tamaño para obtenerlos.
- **FR-003**: El endpoint de detalle de producto NO DEBE incluir la receta de ningún tamaño en la
  respuesta cuando quien la solicita tiene rol Cajero — preserva, sin modificarla, la regla de
  negocio ya vigente (spec 093, FR-018) de que ningún dato de costo/receta/inventario se expone a
  ese rol.
- **FR-004**: Esta optimización NO DEBE cambiar los datos que hoy se muestran en "Carta del menú →
  detalle de producto" (la pantalla de solo lectura) para ningún rol, ni introducir ahí
  información que antes no se mostraba.
- **FR-005**: El contenido de la receta y los grupos de opciones incluidos en la respuesta
  consolidada DEBE ser exactamente el mismo (mismos campos, mismos valores) que ya devuelven hoy
  los endpoints independientes de receta y de grupos de opciones por variante.
- **FR-006**: El sistema DEBE seguir permitiendo recargar la receta y los grupos de opciones de
  **una sola** variante puntual (reintento tras un fallo parcial, restaurar un tamaño
  desactivado) sin necesitar volver a pedir el detalle completo del producto.
- **FR-007**: Esta optimización NO DEBE cambiar la forma en que se guarda el producto: crear y
  editar un producto siguen guardando toda la información en una sola petición, sin cambios en
  ese contrato.
- **FR-008**: El sistema NO DEBE requerir ningún cambio en qué insumos, grupos de opciones o
  presentaciones son válidos para un producto: el alcance es exclusivamente cómo se recupera esa
  información ya existente, no qué información existe.
- **FR-009**: El control de "Reintentar" por tamaño que la spec 102 (Historia 2) agregó para una
  carga inicial que podía fallar en algunos tamaños mientras otros cargaban bien DEBE retirarse de
  la carga inicial del formulario: esta optimización hace que esa carga sea una sola petición
  atómica (todo el detalle del producto, con receta y grupos de opciones de todos los tamaños,
  falla o llega completo), así que ya no existe el escenario de fallo parcial que ese control
  atendía. El control de reintento que restaura un tamaño desactivado no se ve afectado.
- **FR-010** *(agregado 2026-10-08, ver Clarifications)*: El endpoint de detalle de producto DEBE
  incluir también los tamaños desactivados del producto (sin receta ni grupos de opciones), dentro
  de la misma respuesta, para que el formulario de edición no necesite ninguna petición aparte
  solo para listarlos.
- **FR-011** *(agregado 2026-10-08)*: El formulario de edición de producto NO DEBE disparar
  ninguna petición adicional (ni para variantes activas ni para desactivadas) después de recibir
  el detalle del producto, salvo la recarga puntual de una sola variante al restaurarla (FR-006).

### Key Entities *(include if feature involves data)*

- **Producto / Variante (tamaño)**: ya existen; esta spec no cambia su modelo de datos, solo cómo
  se recupera la receta y los grupos de opciones de cada variante junto con el resto del detalle
  del producto.
- **Receta de producto / Insumo fijo, Grupo de opciones**: ya existen (ver spec 102); esta spec no
  cambia su contenido ni sus reglas de negocio, solo el punto de la respuesta HTTP donde viajan.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Abrir el formulario de edición de un producto, sin importar cuántos tamaños tenga,
  dispara cero peticiones de red adicionales de receta o grupos de opciones por tamaño después de
  recibir el detalle del producto.
- **SC-002**: El número total de peticiones de red necesarias para dejar el formulario de edición
  listo para usarse no aumenta con el número de tamaños del producto (se mantiene constante).
- **SC-003**: El 100% de la información de receta y grupos de opciones mostrada en el formulario
  de edición después de esta optimización coincide exactamente con la que se mostraba antes.
- **SC-004**: El 0% de las respuestas de red recibidas por un usuario con rol Cajero contiene datos
  de receta o costo de insumos, verificado tanto en el formulario de edición (si se diera el caso)
  como en "Carta del menú → detalle de producto".

## Assumptions

- Se asume que la distinción de qué datos recibe cada rol se resuelve del lado del servidor según
  el rol de quien hace la petición (el mismo mecanismo que ya usa `GET
  /variants/{id}/recipe` con `forbid_cashier`), no ocultando el campo solo en el frontend — así
  un usuario Cajero nunca recibe ese dato en la respuesta HTTP, ni siquiera inspeccionando las
  herramientas de red del navegador.
- Se asume que "incluir la receta y los grupos de opciones en la misma respuesta" no implica
  eliminar los endpoints independientes por variante (`GET /variants/{id}/recipe`, `GET
  /variants/{id}/option-groups`): siguen existiendo para la recarga puntual de una sola variante
  (FR-006) y para cualquier otro consumidor que no sea el detalle completo del producto.
- Se asume que esta optimización no necesita aplicarse a la lista paginada de productos (`GET
  /products`), que no muestra receta ni grupos de opciones y no tiene el mismo patrón de
  peticiones adicionales por variante.
- Se asume que el volumen típico de tamaños por producto (unas pocas unidades, rara vez más de
  10-15) hace que incluir receta y grupos de opciones en la respuesta de detalle no represente un
  problema de tamaño de payload que deba resolverse en esta spec.
